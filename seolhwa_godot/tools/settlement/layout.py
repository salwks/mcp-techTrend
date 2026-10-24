"""WP5 — Layers 3–5 orchestration: districts → streets & water network → blocks & shared-edge
parcels → one planar subdivision, records, checks and metrics (`layout.json`, settlement-layout/1).

Order (spec 00/19): terrain·water → movement·livelihood → settlement functions (L0–2) →
**streets·parcels·yards (this layer)** → buildings·boundaries (WP6/WP8).
Locks are immutable faces. Failures are reported as revision requests; nothing is silently
dropped, moved or shrunk (TOOL-03).
"""
from __future__ import annotations

import math

import numpy as np
import shapely
from shapely.geometry import LineString, Point, Polygon, shape

from . import contract as Ct
from . import districts as D
from . import geometry as G
from . import parcels as PA
from . import raster as Rr
from . import routing as Rt
from . import streets as ST
from . import subdivision as SB
from . import waternet as WN
from .layout_ctx import Ctx, union

SCHEMA = "settlement-layout/1"
PUBLIC = ("street", "plaza", "cul_de_sac", "lane_access")
REASON_PRIORITY = ["lock_shape", "town_wall", "water_setback", "civic_envelope", "civic_forecourt", "program_plaza",
                   "rear_access_demand", "easement", "rear_split", "street_edge", "frontage_normal", "frontage_depth", "hamlet_extent",
                   "territory_edge", "protected_field_edge", "block_residual"]


def skip_record(plan, reason):
    return {"schema": SCHEMA, "id": plan["id"], "status": "skipped", "reason": reason, "checks": [], "geometry": {}}


def build(plan, inp, A, layer, rules, reg=None, scope=None):
    fr = plan.get("frame")
    if fr is None:
        return skip_record(plan, "no frame (Layer 2 produced no candidate)")
    mode = "plan"
    if plan["status"] not in ("valid", "proposed"):
        if not fr.get("households"):
            return skip_record(plan, f"plan status {plan['status']} with no households")
        mode = "diagnostic_only"
    C = Ctx(plan, inp, A, layer, rules, reg, scope)
    R = rules
    # ---------------------------------------------------------------- water (effective geometry first)
    C.channels_rec = WN.channels(C)
    C.buildable = G.polygonal(A.house_poly)
    # ---------------------------------------------------------------- Layer 3
    dist = D.build(C)
    C.districts_rec = dist["districts"]
    hh = dist["households"]
    demand = [shape(C.store.items[d["geometry"]]) for d in dist["districts"] if d["households"] > 0]
    # ---------------------------------------------------------------- street domain & obstacles
    if C.walled:
        C.street_domain = C.territory
    else:
        free = G.polygonal(C.allowed.difference(union([A.protected_poly, A.neigh_poly])))
        C.street_domain = G.polygonal(union([C.territory, free.intersection(C.territory.buffer(60.0))]))
    C.obstacles = union([C.g(c["envelope"]) for c in fr["civic_reserves"]] + [l["geom"] for l in inp.locks]
                        + [A.protected_poly])
    C.bridge_cells = lambda sub: WN.bridge_cells(C, sub)
    # ---------------------------------------------------------------- Layer 4 streets
    pre = _hamlet_links(C) + _route_links(C)
    if getattr(C, "hamlets", []):
        C.street_domain = G.polygonal(union([C.street_domain] + [h["poly"] for h in C.hamlets]))
        demand = demand + [h["poly"] for h in C.hamlets]
    net, sinfo = ST.build(C, demand, pre)
    C.net = net
    obligations = sinfo["obligations"]
    activity = []
    # water-working access (fishing / boat households) and laundry
    liv = {h["livelihood"] for h in hh}
    if liv & {"fishing", "salt_or_boat"}:
        obligations.append(_landing(C, net, activity))
    lau = WN.laundry(C, net)
    for s in lau:
        q = s.pop("_pt")
        if s["network_distance_m"] > 2.0:
            ok = _connect_point(C, net, q, "lane" if C.urban else "gosat", "laundry_access")
            s["access_added"] = ok
        activity.append(s)
    obligations += getattr(C, "hamlet_obligations", [])
    ST.classify_inherited(C, net)
    # ---------------------------------------------------------------- faces before parcels
    plazas = ST.plazas(C)
    corr_polys = []
    ends = {}
    for l in net.links:
        for c in (l["line"].coords[0], l["line"].coords[-1]):
            k = (round(c[0], 1), round(c[1], 1))
            ends.setdefault(k, []).append(l)
    for l in net.links:
        # flat ends; joints get a disc of the widest incident street (dead ends stay square)
        corr_polys.append(l["line"].buffer(l["width_m"] / 2, quad_segs=4, cap_style="flat", join_style="round"))
        C.reason(corr_polys[-1].boundary, "street_edge", l.get("source") or l["_id"])
    for k, ls in sorted(ends.items()):
        if len(ls) >= 2:
            w = max(x["width_m"] for x in ls)
            disc = Point(k).buffer(w / 2, quad_segs=4)
            corr_polys.append(disc)
            C.reason(disc.boundary, "street_edge", "junction")
    res = C.g((fr.get("primary_corridors") or {}).get("reservation"))
    if res is not None and not res.is_empty:
        corr_polys.append(res)
        C.reason(res.boundary, "street_edge", "layer2_reservation")
    street_space = union(corr_polys)
    hamlet_polys = [h["poly"] for h in getattr(C, "hamlets", [])]
    if C.walled:
        domain = union([C.territory] + hamlet_polys)
        outside = G.polygonal(street_space.difference(C.territory))
        conn = G.polygonal(outside.intersection(union([h.buffer(200) for h in hamlet_polys]))) if hamlet_polys else Polygon()
        domain = union([domain, conn])
        C.reason(C.g(fr["wall"]["ring"]), "town_wall", fr["wall"].get("stable_id"))
    else:
        domain = union([C.territory, street_space.intersection(C.street_domain)] + hamlet_polys)
        C.reason(C.territory.boundary, "territory_edge", fr.get("stable_id"))
    domain = G.polygonal(domain)
    C.reason(domain.boundary, "territory_edge", "domain")
    fixed = []
    locks = [(l["id"], l["geom"]) for l in inp.locks if l["geom"].intersects(domain)]
    for lid, g in locks:
        C.reason(g.boundary, "lock_shape", lid)
    fixed += [("lock", lid, g) for lid, g in locks]
    wet = G.polygonal(union([C.effective_wet, A.water_poly]))
    margin = G.polygonal(C.water_block.difference(wet)) if not C.water_block.is_empty else Polygon()
    if not wet.is_empty:
        C.reason(wet.boundary, "water_setback", "wet")
        fixed.append(("water", "watercourse", wet))
    if not A.protected_poly.is_empty:
        C.reason(A.protected_poly.boundary, "protected_field_edge", "protected")
        fixed.append(("field_protected", "protected_field", A.protected_poly))
    for c in fr["civic_reserves"]:
        if c["key"] == "market":
            continue
        e = C.g(c["envelope"])
        C.reason(e.boundary, "civic_envelope", c.get("stable_id", c["id"]))
        fixed.append(("civic", c.get("stable_id", c["id"]), e))
    for p in plazas:
        C.reason(p["_g"].boundary, "civic_forecourt" if p["program"] == "civic_forecourt" else "program_plaza", p["of"])
        fixed.append(("plaza", p["id"], p["_g"]))
    fixed.append(("street", "street_space", street_space))
    if not margin.is_empty:
        # drainage reserve + bank setback: never occupied; streets may pass (circulation, culverts)
        C.reason(margin.boundary, "water_setback", "margin")
        fixed.append(("water_margin", "water_margin", margin))
    remaining = domain
    face_geoms = []
    for kind, fid, g in fixed:
        piece = G.polygonal(remaining.intersection(g))
        remaining = G.polygonal(remaining.difference(piece))
        for k, prt in enumerate(G.parts(piece)):
            if prt.area < 1e-4:
                continue
            face_geoms.append({"kind": kind, "of": fid, "geom": prt})
    blocks = []
    residual_faces = []
    for k, b in enumerate(G.parts(remaining)):
        if b.area < 4.0:
            residual_faces.append(b)
            continue
        hm = None
        for h in getattr(C, "hamlets", []):
            if h["poly"].intersection(b).area > 0.5 * b.area:
                hm = h["id"]
        cen = b.representative_point()
        bid = C.claim("block", key=None, xz=[G.r2(cen.x), G.r2(cen.y)], tol=10.0, content=G.to_geojson(b))
        blocks.append(PA.Block(bid, b, hm))
    blocks.sort(key=lambda b: b.id)
    # ---------------------------------------------------------------- Layer 5 parcels
    link_index = [{"line": l["line"], "hierarchy": l["hierarchy"], "width_m": l["width_m"]} for l in net.links]
    public = union([street_space] + [p["_g"] for p in plazas])
    P5 = PA.build(C, blocks, public, link_index, hh)
    # access additions become street links (connected to the parent centreline)
    for acc in P5["access_added"]:
        st = Point(acc["line"].coords[0])
        q = net.split_at(min(net.lines(), key=lambda l: l.distance(st)).interpolate(
            min(net.lines(), key=lambda l: l.distance(st)).project(st)))
        line = LineString([(q.x, q.y)] + list(acc["line"].coords))
        net.add(line, acc["hierarchy"], acc["width_m"], purpose="rear_access_demand", generation=3,
                bends=[], serves=[acc["block"]], access_id=acc["id"])
    C.domain_total = domain
    fin = ST.finalize(C, net)
    crossings = WN.crossings(C, fin, sinfo["bridge_candidates"])
    drains = WN.drains(C, fin)
    # ---------------------------------------------------------------- faces → subdivision
    faces = []
    nstreet = 0
    link_lines = [l["line"] for l in net.links]
    ltree = shapely.STRtree(link_lines) if link_lines else None
    for f in face_geoms:
        if f["kind"] == "street" and ltree is not None:
            hit = [link_lines[int(i)] for i in ltree.query(f["geom"], predicate="intersects")]
            if not any(h.intersection(f["geom"]).length >= 0.5 for h in hit):
                # corridor fragment cut off by water / reserves with no street line in it → verge
                f["kind"] = "verge"
    for f in face_geoms:
        if f["kind"] == "street":
            nstreet += 1
            fid = f"face:{C.scope}:street:{nstreet:03d}"
        else:
            fid = f"face:{C.scope}:{f['kind']}:{f['of']}"
            if any(x["id"] == fid for x in faces):
                fid += f":{sum(1 for x in faces if x['id'].startswith(fid)) + 1}"
        faces.append({"id": fid, "kind": f["kind"], "of": f["of"], "geom": f["geom"], "public": f["kind"] in ("street", "plaza")})
    for acc in P5["access_added"]:
        for k, prt in enumerate(G.parts(acc["corridor"])):
            faces.append({"id": f"face:{C.scope}:{acc['hierarchy']}:{acc['id']}:{k + 1}", "kind": acc["hierarchy"],
                          "of": acc["id"], "geom": prt, "public": True})
    for e in P5["easements"]:
        faces.append({"id": f"face:{C.scope}:easement:{e['id']}", "kind": "easement", "of": e["id"], "geom": e["poly"],
                      "public": False})
    parcels = []
    for blk in P5["blocks"]:
        # classified residual where the lots leave a gap (never an unclassified hole)
        lotu = union([l["poly"] for l in blk.lots] + [e["poly"] for e in P5["easements"] if e["block"] == blk.id])
        gap = G.polygonal(blk.poly.difference(lotu)) if not lotu.is_empty else blk.poly
        for gp in G.parts(gap):
            if gp.area < 1e-3:
                continue
            blk.lots.append({"poly": gp, "role": "residual", "use": "residual_nonbuildable", "group": None, "eligible": False,
                             "run": None, "s": None, "hierarchy": None, "width": None, "depth": None,
                             "district": None, "hamlet": blk.hamlet, "buildable_m2": 0.0, "residual": True})
        for lot in blk.lots:
            lp = G.polygonal(lot["poly"].intersection(blk.poly))
            for k, prt in enumerate(G.parts(lp)):
                if prt.area < 1e-3:
                    continue
                rp = prt.representative_point()
                pid = C.claim("parcel", key=None, xz=[G.r2(rp.x), G.r2(rp.y)], tol=3.0, content=G.to_geojson(prt))
                lot2 = dict(lot)
                lot2["poly"] = prt
                lot2["pid"] = pid
                if k > 0:
                    lot2["household"] = None
                    lot2["use"] = "residual_nonbuildable"
                parcels.append((blk, lot2))
                faces.append({"id": pid, "kind": "parcel", "of": blk.id, "geom": prt, "public": False, "use": lot2.get("use")})
    for k, rf in enumerate(residual_faces):
        faces.append({"id": f"face:{C.scope}:residual:{k + 1:03d}", "kind": "residual", "of": None, "geom": rf, "public": False})
    sub = SB.build(C, faces, domain)
    # ---------------------------------------------------------------- records
    rec = {"schema": SCHEMA, "id": plan["id"], "mode": mode, "status": None,
           "units": "world_m", "scope": C.scope,
           "scale": {"factor": C.factor, "rules_hold": "historical (measured) dimensions", "applied_once": True,
                     "source": "RegionProfile.scale_policy.building.factor"},
           "plan": {"status": plan["status"], "frame": fr.get("stable_id", fr["id"]),
                    "households": plan["program"]["households"]["represented"]},
           "districts": {k: v for k, v in dist.items() if k != "households"},
           "households": [{k: v for k, v in h.items() if not k.startswith("_")} for h in hh]}
    face_of = {f["id"]: f for f in faces}
    edge_lines = {e["id"]: e["_line"] for e in sub["edges"]}
    pmap = {}
    out_parcels = []
    for blk, lot in parcels:
        out_parcels.append(_parcel_record(C, blk, lot, sub))
        pmap[lot["pid"]] = out_parcels[-1]
    hmap = {}
    for p in out_parcels:
        if p.get("household"):
            hmap[p["household"]] = p["id"]
    for h in rec["households"]:
        h["parcel"] = hmap.get(h["id"])
    rec["streets"] = {"nodes": fin["nodes"], "links": fin["links"], "planarity": fin["planarity"],
                      "plazas": [{k: v for k, v in p.items() if not k.startswith("_")} for p in plazas],
                      "obligations": obligations,
                      "access_revisions": [{"id": a["id"], "block": a["block"], "hierarchy": a["hierarchy"], "length_m": a["length_m"],
                                            "width_m": round(a["width_m"], 2), "through": a["through"],
                                            "corridor": C.add(a["corridor"]), "reason": "rear_access_demand"}
                                           for a in P5["access_added"]],
                      "wall_access_strip": {"reserved": R.p("layout.streets.wall_access_strip_m") > 0,
                                            "note": "no forced perimeter ring road (L3-8 §2)"}}
    rec["water"] = {"channels": C.channels_rec, "crossings": crossings, "drains": drains,
                    "wall_passages": WN.wall_passages(C),
                    "bridge_candidates": [{"reach": b["reach"], "station": b["station"], "span_m": b["span_m"],
                                           "structure": b["structure"], "line": C.add(b["line"])}
                                          for b in sinfo["bridge_candidates"]][:200],
                    "decisions": {"wet_width": "carved heightfield section for planning; mapped width kept as attribute (coordinator 2026-10-25)",
                                  "ford": "mapped fords carry a riffle section ≤0.4 m at 평수 (coordinator 2026-10-25); pools/runs keep design depth"}}
    rec["blocks"] = [{"id": b.id, "geometry": C.add(b.poly), "area_m2": round(b.poly.area, 1), "hamlet": b.hamlet,
                      "access_revisions": b.revisions} for b in P5["blocks"]]
    rec["parcels"] = out_parcels
    eadj = {}
    for e in sub["edges"]:
        if e["length_m"] >= 0.9:
            for a, b in ((e["left_face"], e["right_face"]), (e["right_face"], e["left_face"])):
                eadj.setdefault(a, set()).add(b)
    for p in out_parcels:
        if (p.get("access") or {}).get("kind") == "easement":
            touching = sorted(x for x in eadj.get(p["id"], ()) if ":easement:" in x)
            p["access"]["easement_faces"] = touching
    rec["easements"] = [{"id": e["id"], "geometry": C.add(e["poly"]), "width_m": e["width_m"], "purpose": e["purpose"],
                         "beneficiaries": sorted(x for x in eadj.get(f"face:{C.scope}:easement:{e['id']}", ()) if x.startswith("parcel:")),
                         "entrances": e["entrances"], "note": e["note"]} for e in P5["easements"]]
    rec["activity_sites"] = activity + dist.get("open_ground_sites", []) + _market_states(C, plazas, fin)
    # subdivision edges with attributes
    edges = _edge_records(C, sub, face_of, pmap)
    rec["subdivision"] = {"vertices": sub["vertices"], "edges": edges,
                          "faces": [_face_record(C, f, sub) for f in faces],
                          "diagnostics": sub["diagnostics"],
                          "conventions": {"left": "face on the left walking start→end in (x, z) math sense",
                                          "ring": "signed edges e+ (along) / e- (reversed)",
                                          "grid_m": G.GRID}}
    rec["metrics"] = _metrics(C, rec, fin)
    rec["revision_requests"] = C.revision_requests
    rec["diagnostics"] = C.diagnostics
    rec["geometry"] = dict(sorted(C.store.items.items()))
    # checks
    from . import layout_checks as LC
    rec["checks"] = LC.run(C, rec, sub, faces, edge_lines, domain)
    hard_fail = [c["id"] for c in rec["checks"] if c["kind"] in ("invariant", "hard") and c["pass"] is False]
    rec["status"] = ("diagnostic_only" if mode == "diagnostic_only" else
                     ("complete" if not hard_fail else "incomplete"))
    rec["status_reason"] = hard_fail or None
    rec["summary"] = _summary(rec)
    return rec


# ======================================================================== helpers
def _connect_point(C, net, pt, hier, purpose):
    gr, pas = C.graph_fn(hier)
    sub = C.street_sub
    g = sub.grid
    src = np.flatnonzero(C.net_mask() & pas)
    if not src.size:
        return False
    tgt = Rr.rasterize(g, pt.buffer(4.0)) & pas
    if not tgt.any():
        return False
    dist, pred = Rt.dijkstra(gr, src)
    tc = np.flatnonzero(tgt)
    tc = tc[np.isfinite(dist[tc])]
    if not tc.size:
        return False
    t = int(tc[np.argmin(dist[tc])])
    return bool(C.add_path(Rt.path_cells(pred, t), hier, purpose, 2))


def _landing(C, net, activity):
    """Water-working access for fishing / boat households (waterside villages)."""
    A = C.A
    water = union([C.effective_wet, A.water_poly])
    ob = {"kind": "water_work_access", "added": False}
    if water.is_empty:
        ob["reason"] = "no water body in the window"
        return ob
    netu = union(net.lines())
    edge = water.boundary
    p = edge.interpolate(edge.project(netu.centroid))
    q = Point(p.x, p.y)
    ok = _connect_point(C, net, q, "gosat" if not C.urban else "lane", "water_work_access")
    ob.update({"added": ok, "xz": [G.r2(q.x), G.r2(q.y)]})
    sid = C.claim("activity", key="landing", content=[G.r2(q.x), G.r2(q.y)])
    activity.append({"id": sid, "activity": "landing_or_fishing_access", "users": ["fishing / boat households"],
                     "xz": [G.r2(q.x), G.r2(q.y)], "spaces": {}, "state": "normal",
                     "states": "per WaterReach stage (WP4 stage_impacts)", "status": "proposed", "hypothesis": True})
    return ob


def _route_links(C):
    """Unwalled settlements: mapped routes through / beside the clusters are existing streets
    (kept as given — width from data, never regenerated)."""
    if C.walled:
        return []
    out = []
    zone = C.territory.buffer(60.0)
    for r in sorted(C.inp.roads, key=lambda r: r.id):
        seg = r.line.intersection(zone)
        for g in getattr(seg, "geoms", [seg]):
            if g.geom_type == "LineString" and g.length >= 10.0:
                out.append({"line": LineString([(G.r2(x), G.r2(z)) for x, z in g.coords]), "hierarchy": "route",
                            "width_m": float(r.width_m), "purpose": "existing_route", "generation": 0, "bends": [],
                            "serves": [], "source": r.id, "note": "mapped route (WP3 Route) used as an existing street"})
    return out


def _hamlet_links(C):
    """Outside-wall hamlets: the mapped route through the hamlet is its first street; otherwise a
    field-edge connector from the route network (never through protected farmland or water)."""
    A = C.A
    pre, obs = [], []
    for h in getattr(C, "hamlets", []):
        win = A.win
        i, j = win.ij(*h["anchor"])
        rc = float(A.route_cost[j, i]) if win.inside(i, j) else math.inf
        if rc <= 6.0:
            best = None
            for r in C.inp.roads:
                seg = r.line.intersection(h["poly"].buffer(30.0).difference(C.territory.buffer(3.0)))
                for g in getattr(seg, "geoms", [seg]):
                    if g.geom_type == "LineString" and (best is None or g.length > best[0]):
                        best = (g.length, g, r)
            if best is not None:
                _, g, r = best
                pre.append({"line": LineString([(G.r2(x), G.r2(z)) for x, z in g.coords]), "hierarchy": "route",
                            "width_m": float(r.width_m), "purpose": "existing_route",
                            "generation": 0, "bends": [], "serves": [h["id"]], "source": r.id,
                            "note": "mapped route segment used as the hamlet street (not a new road)"})
                obs.append({"kind": "hamlet_access", "target": h["id"], "added": True, "via": f"route {r.id}"})
                continue
        free = A.cov & A.passable & ~A.protected & ~A.locks & ~A.water & ~A.anchor_mask
        gr = Rt.build_graph(win, A.h, free, radius=1, grade_k=C.R.p("routing.grade_cost_k"))
        src = np.flatnonzero(A.road_mask & free)
        c = j * win.nx + i
        if not src.size:
            obs.append({"kind": "hamlet_access", "target": h["id"], "added": False, "reason": "no route cells"})
            continue
        dist, pred = Rt.dijkstra(gr, src)
        if not np.isfinite(dist[c]):
            obs.append({"kind": "hamlet_access", "target": h["id"], "added": False,
                        "reason": "only through protected farmland or water"})
            continue
        pts = Rt.cells_to_xz(win, Rt.path_cells(pred, c))
        if len(pts) < 2:
            continue
        line = LineString(pts).simplify(C.R.p("layout.streets.simplify_m"))
        w = ST.width_world(C, "gosat")
        pre.append({"line": line, "hierarchy": "gosat", "width_m": w, "purpose": "hamlet_connector", "generation": 1,
                    "bends": [], "serves": [h["id"]], "note": "field-edge path from the route network"})
        h["poly"] = G.polygonal(union([h["poly"], line.buffer(w / 2).intersection(h["poly"].buffer(40))]))
        obs.append({"kind": "hamlet_access", "target": h["id"], "added": True, "length_m": round(line.length, 1)})
    C.hamlet_obligations = obs
    return pre


def _cat(C, f):
    if f is None:
        return "exterior"
    k = f["kind"]
    if k in ("street", "cul_de_sac", "lane"):
        return "street"
    if k == "plaza":
        return "plaza"
    if k == "parcel":
        u = f.get("use") or ""
        if u == "residential":
            return "residential"
        if u in ("hill", "open_ground", "residual_nonbuildable", "field") or u.startswith("residual"):
            return "nonbuilt"
        return "garden"
    if k in ("water", "water_margin"):
        return "water"
    if k == "lock":
        return "lock"
    if k == "civic":
        return "civic"
    if k == "field_protected":
        return "nonbuilt"
    if k == "easement":
        return "easement"
    return "nonbuilt"


def _closures(C, a, b):
    table = C.R.p("layout.edges.closures")
    for x in (a, b):
        if x == "water":
            return table["any|water"]
        if x == "town_wall":
            return table["any|town_wall"]
        if x == "lock":
            return table["any|lock"]
    for k in (f"{a}|{b}", f"{b}|{a}"):
        if k in table:
            return table[k]
    if "easement" in (a, b):
        return ["free_wall", "fence", "open"]
    return table["default"]


PURPOSE = {frozenset(["street", "residential"]): "street_frontage", frozenset(["residential"]): "party_boundary",
           frozenset(["residential", "garden"]): "rear_or_side_boundary", frozenset(["garden"]): "garden_boundary",
           frozenset(["street"]): "street_internal", frozenset(["street", "plaza"]): "plaza_edge",
           frozenset(["street", "garden"]): "street_frontage_garden", frozenset(["street", "civic"]): "civic_front",
           frozenset(["residential", "civic"]): "civic_boundary", frozenset(["residential", "nonbuilt"]): "land_limit",
           frozenset(["garden", "nonbuilt"]): "land_limit", frozenset(["street", "nonbuilt"]): "street_edge_open_land",
           frozenset(["street", "easement"]): "easement_entrance"}


def _edge_records(C, sub, face_of, pmap):
    R, A = C.R, C.A
    items = [(g, r, s) for g, r, s in C.reason_lines]
    geoms = [g for g, _, _ in items]
    tree = shapely.STRtree(geoms) if geoms else None
    lvl = R.p("layout.edges.level_change_m")
    ring = C.g(C.fr["wall"]["ring"]) if C.walled else None
    openings = C.fr.get("openings", []) if C.walled else []
    out = []
    for e in sub["edges"]:
        line = e["_line"]
        mid = line.interpolate(0.5, normalized=True)
        reason, source = "unclassified", None
        if tree is not None:
            hits = tree.query(mid, predicate="dwithin", distance=0.08)
            best = None
            for h in hits:
                g, r, s = items[int(h)]
                base = r.split(":")[0]
                pr = REASON_PRIORITY.index(base) if base in REASON_PRIORITY else 99
                if best is None or (pr, str(s)) < best[0]:
                    best = ((pr, str(s)), r, s)
            if best is not None:
                reason, source = best[1], best[2]
        fl, fr_ = face_of.get(e["left_face"]), face_of.get(e["right_face"])
        ca, cb = _cat(C, fl), _cat(C, fr_)
        purpose = None
        extra = {}
        if C.walled and "exterior" in (ca, cb) and ring is not None and ring.distance(mid) < 0.2:
            s = ring.project(mid)
            op = next((o for o in openings if _in_iv(s, o["chainage"], ring.length)), None)
            if op is not None:
                purpose = "gate_opening" if op["type"] == "gate" else "water_passage"
                extra["opening"] = op.get("stable_id", op["id"])
                clos = ["layer2_opening"]
            else:
                ca = "town_wall" if ca == "exterior" else ca
                cb = "town_wall" if cb == "exterior" else cb
                purpose = "town_wall_inner"
                clos = _closures(C, ca, cb)
        else:
            clos = _closures(C, ca, cb)
        if purpose is None:
            purpose = PURPOSE.get(frozenset([ca, cb]), f"{ca}|{cb}")
            if "water" in (ca, cb):
                purpose = "water_edge"
            elif "lock" in (ca, cb):
                purpose = "lock_boundary"
            elif "exterior" in (ca, cb):
                purpose = "domain_edge"
        # ground on both sides (level change → retaining candidate, resolved in WP6/WP8)
        a, b = line.coords[0], line.coords[-1]
        dx, dz = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dz) or 1.0
        ylft = float(C.height([mid.x - dz / n * 1.5], [mid.y + dx / n * 1.5])[0])
        yrgt = float(C.height([mid.x + dz / n * 1.5], [mid.y - dx / n * 1.5])[0])
        dy = abs(ylft - yrgt)
        clos = list(clos)
        level = {"left_y": round(ylft, 2), "right_y": round(yrgt, 2), "difference_m": round(dy, 2),
                 "basis": "smoothed terrain 1.5 m either side (pre-grading)", "status": "proposed"}
        if dy > lvl and "retaining_wall" not in clos and purpose not in ("gate_opening", "water_passage"):
            clos.append("retaining_wall")
        rec = {"id": e["id"], "geometry": C.add(line), "nodes": e["nodes"], "left_face": e["left_face"],
               "right_face": e["right_face"], "length_m": e["length_m"], "adjacency": [ca, cb], "purpose": purpose,
               "geometry_reason": reason, "reason_source": source, "allowed_closures": clos, "implementation": None,
               "implementation_note": "chosen in WP6 (one of allowed_closures); shared edge → one owner",
               "level": level, "level_change": dy > lvl}
        rec.update(extra)
        out.append(rec)
    return out


def _in_iv(s, iv, L):
    a, b = iv
    return a <= s <= b if a <= b else (s >= a or s <= b)


def _face_record(C, f, sub):
    ring = next((x["rings"] for x in sub["faces"] if x["id"] == f["id"]), [])
    return {"id": f["id"], "kind": f["kind"], "of": f.get("of"), "public": f.get("public", False),
            "use": f.get("use"), "area_m2": round(f["geom"].area, 2), "geometry": C.add(f["geom"]), "rings": ring}


def _parcel_record(C, blk, lot, sub):
    p = lot["poly"]
    pid = lot["pid"]
    use = lot.get("use") or "garden"
    rp = p.representative_point()
    zones = {"lot": C.add(p)}
    if lot.get("garden_poly") is not None and not lot["garden_poly"].is_empty:
        zones["rear_garden"] = C.add(G.polygonal(lot["garden_poly"].intersection(p)))
    bd = lot.get("buildable")
    buildable = C.add(G.polygonal(bd.intersection(p))) if bd is not None and not bd.is_empty else None
    front = None
    if lot.get("run") is not None and lot.get("width"):
        front = {"street_hierarchy": lot["hierarchy"], "width_m": round(lot["width"], 2),
                 "measured_on": "street boundary (not centreline)", "run": lot["run"]}
    access = lot.get("access") or {"kind": "street_frontage" if front else "see subdivision adjacency"}
    body = {"id": pid, "use": use, "role": lot.get("role"), "block": blk.id, "district": lot.get("district"),
            "hamlet": lot.get("hamlet"), "group": lot.get("group"), "household": lot.get("household"),
            "area_m2": round(p.area, 1), "frontage": front,
            "depth_m": round(lot["depth"], 2) if lot.get("depth") else None,
            "zones": zones, "access": access, "yards": None,
            "yards_missing_reason": "courts and yards are solved in Layer 6 (WP8)",
            "buildable": buildable, "buildable_m2": round(lot.get("buildable_m2") or 0.0, 1),
            "axes": None, "axes_missing_reason": "orientation is decided in Layer 6 with south as a weighted preference (K6); not confirmed here",
            "rear_garden": bool(lot.get("rear_garden")), "garden_depth_exceeded": bool(lot.get("garden_depth_exceeded")),
            "rear_garden_m2": round(G.polygonal(lot["garden_poly"].intersection(p)).area, 1) if lot.get("garden_poly") is not None else 0.0,
            "residual": bool(lot.get("residual")), "vacant_reason": lot.get("vacant_reason"),
            "xz": [G.r2(rp.x), G.r2(rp.y)]}
    body["meta"] = Ct.meta(pid, status="proposed", rules_hash=C.R.hash, content={k: v for k, v in body.items() if k != "id"})
    return body


def _market_states(C, plazas, fin):
    R = C.R
    out = []
    clear = R.p("layout.market.clear_corridor_m")
    for p in plazas:
        if p["program"] != "market":
            continue
        g = p["_g"]
        # minimum width of the square (inscribed): stalls take the rim, the clear corridor stays open
        minw = 2 * _inradius(g)
        stall_band = max(0.0, (minw - clear) / 2)
        sid = C.claim("activity", key=f"market:{p['of']}", content=p["geometry"])
        out.append({"id": sid, "activity": "market", "users": ["traders", "buyers"], "plaza": p["id"],
                    "spaces": {"square": p["geometry"]}, "state": "peacetime",
                    "states": [{"key": "peacetime", "occupation": "clear square; through travel"},
                               {"key": "market_day", "occupation": f"temporary stalls on the rim, band ≤ {stall_band:.1f} m",
                                "clear_corridor_m": clear, "permanent_geometry": False}],
                    "clear_corridor_ok": minw >= clear, "square_min_width_m": round(minw, 2),
                    "status": "proposed", "hypothesis": True,
                    "basis": "BLD-05 / 08: market-day occupation is a comparison state (V33 data part); stall layout data blocked"})
    return out


def _inradius(g):
    lo, hi = 0.0, 200.0
    for _ in range(30):
        m = (lo + hi) / 2
        if g.buffer(-m).is_empty:
            hi = m
        else:
            lo = m
    return lo


def _metrics(C, rec, fin):
    R = C.R
    hr = R.p("layout.streets.hierarchy")
    rng = {k: (C.wl(v["width_hist_m"][0]), C.wl(v["width_hist_m"][1])) for k, v in hr.items()}
    tot = ok = 0.0
    for l in rec["streets"]["links"]:
        h = l["hierarchy"]
        if h == "primary":
            continue
        lo, hi = rng.get(h, (0, 1e9))
        tot += l["length_m"]
        if lo - 1e-6 <= l["width_m"] <= hi + 1e-6:
            ok += l["length_m"]
    roles = R.p("layout.parcels.roles")
    per_role = {}
    for p in rec["parcels"]:
        if p["use"] != "residential" or p["role"] not in roles:
            continue
        r = per_role.setdefault(p["role"], {"frontage": [], "area": [], "area_house_part": []})
        if p["frontage"]:
            r["frontage"].append(p["frontage"]["width_m"])
        r["area"].append(p["area_m2"])
        r["area_house_part"].append(p["area_m2"] - (p.get("rear_garden_m2") or 0.0))
    stats = {}
    for role, v in sorted(per_role.items()):
        rr = roles[role]
        tgt_f = (C.wl(rr["frontage"][0]), C.wl(rr["frontage"][1]))
        tgt_a = (C.wa(rr["area"][0]), C.wa(rr["area"][1]))
        stats[role] = {"n": len(v["area"]), "frontage": _dist(v["frontage"], tgt_f), "area": _dist(v["area"], tgt_a),
                       "area_without_rear_garden": _dist(v["area_house_part"], tgt_a),
                       "judged": len(v["area"]) >= 3,
                       "note": "area includes rear gardens merged behind the lot (narrow deep lots with gardens behind)"}
    # secondary spacing along primaries (junction chainage of secondary branches)
    prim = [shape(C.store.items[l["centerline"]]) for l in rec["streets"]["links"] if l["hierarchy"] == "primary"]
    nodes = {n["id"]: n for n in rec["streets"]["nodes"]}
    jx = []
    for l in rec["streets"]["links"]:
        if l["hierarchy"] != "secondary":
            continue
        for nid in l["nodes"]:
            n = nodes[nid]
            if n["degree"] >= 3:
                jx.append(Point(n["xz"]))
    gaps = []
    for pl in prim:
        ss = sorted(pl.project(p) for p in jx if pl.distance(p) < 1.0)
        gaps += [b - a for a, b in zip(ss, ss[1:]) if b - a > 1.0]
    cul = [l["length_m"] for l in rec["streets"]["links"] if l["hierarchy"] == "cul_de_sac"]
    res = [p for p in rec["parcels"] if p["use"] == "residential"]
    occupied = sum(1 for p in res if p.get("household"))
    T = C.territory.area
    return {"street_width_compliance": {"by_length": round(ok / tot, 4) if tot else None, "length_m": round(tot, 1),
                                        "note": "new streets take the rules default width (inside the range by construction); primary corridors are recorded Layer-2 exceptions"},
            "parcels_by_role": stats,
            "secondary_spacing_m": {"gaps": [round(g, 1) for g in sorted(gaps)], "median": _med(gaps),
                                    "target": [C.wl(x) for x in hr["secondary"]["spacing_hist_m"]],
                                    "judged": len(gaps) >= 3},
            "cul_de_sac_length_m": {"max": max(cul) if cul else None, "limit": C.wl(hr["cul_de_sac"]["length_hist_max_m"]),
                                    "n": len(cul)},
            "households": {"programmed": len(rec["households"]), "on_parcels": occupied},
            "density_households_per_ha": round(occupied / (T / 10000.0), 2) if T else None,
            "deferred": ["roof coverage 35–50 % / 22–32 % and frontage enclosure 85–100 % are Layer 6–7 checks (WP8/WP6)"]}


def _med(v):
    v = sorted(v)
    if not v:
        return None
    n = len(v)
    return round(v[n // 2] if n % 2 else (v[n // 2 - 1] + v[n // 2]) / 2, 2)


def _dist(v, tgt):
    v = sorted(v)
    if not v:
        return {"n": 0}
    q = lambda f: v[min(len(v) - 1, int(f * (len(v) - 1) + 0.5))]
    med = _med(v)
    tmid = math.sqrt(tgt[0] * tgt[1])
    within = abs(med - tmid) / tmid <= 0.15 if med else False
    iqr = (q(0.25), q(0.75))
    overlap = iqr[1] >= tgt[0] and iqr[0] <= tgt[1]
    return {"n": len(v), "median": med, "iqr": [round(iqr[0], 2), round(iqr[1], 2)], "target_range": [round(tgt[0], 2), round(tgt[1], 2)],
            "target_mid": round(tmid, 2), "median_within_15pct": bool(within), "iqr_overlaps_target": bool(overlap)}


def _summary(rec):
    res = [p for p in rec["parcels"] if p["use"] == "residential"]
    hier = {}
    for l in rec["streets"]["links"]:
        hier[l["hierarchy"]] = hier.get(l["hierarchy"], 0) + 1
    uses = {}
    for p in rec["parcels"]:
        uses[p["use"]] = uses.get(p["use"], 0) + 1
    return {"districts": len(rec["districts"]["districts"]), "regions": len(rec["districts"]["regions"]),
            "streets_by_hierarchy": dict(sorted(hier.items())), "parcels_by_use": dict(sorted(uses.items())),
            "households": len(rec["households"]), "households_on_parcels": sum(1 for p in res if p.get("household")),
            "edges": len(rec["subdivision"]["edges"]), "faces": len(rec["subdivision"]["faces"]),
            "crossings": len(rec["water"]["crossings"]), "drains": len(rec["water"]["drains"]),
            "revision_requests": len(rec["revision_requests"])}
