"""WP5 checks. Kinds:
* invariant — structural (schema, references, twin edges, coverage, no overlaps, households at most
  once, V18). Only these gate the plan (`WP5.layer`).
* hard — L3-8 hard acceptance on generated data (access, every household placed, locks, wall
  openings, connected streets, typed crossings, drain outlets). A failure makes the layout
  `incomplete` and is listed with revision requests; it does not hide the plan.
* finding — V-number data checks (V28, V40 partial, V43, V46, V48 partial, V49, V70, V33 data
  part, PUB-04). Applicability is explicit; nothing here is an in-game test.
"""
from __future__ import annotations

import math

import numpy as np
import shapely
from shapely.geometry import LineString, Point, shape

from . import contract as Ct
from . import geometry as G
from . import subdivision as SB


def _c(cid, ok, detail, kind="finding", applicable=True):
    return {"id": cid, "pass": (bool(ok) if applicable else None), "applicable": applicable, "kind": kind, "detail": detail}


def run(C, rec, sub, faces, edge_lines, domain):
    out = []
    fmap = {f["id"]: f for f in faces}
    # ------------------------------------------------------------------ invariants
    from .validate import load_schema, schema_errors
    errs = []
    try:
        sch = load_schema("settlement-layout.schema.json")
        errs = schema_errors({k: v for k, v in rec.items() if k != "checks"}, sch)
    except FileNotFoundError:
        errs = ["schema file missing"]
    ids = {}
    dup = []
    for sec, lst in (("district", rec["districts"]["districts"]), ("region", rec["districts"]["regions"]),
                     ("street", rec["streets"]["links"]), ("node", rec["streets"]["nodes"]), ("parcel", rec["parcels"]),
                     ("edge", rec["subdivision"]["edges"]), ("household", rec["households"])):
        for o in lst:
            if o["id"] in ids:
                dup.append(o["id"])
            ids[o["id"]] = sec
    fids_seen = [f["id"] for f in rec["subdivision"]["faces"]]
    dup += sorted({x for x in fids_seen if fids_seen.count(x) > 1})
    geo = rec["geometry"]
    bad_ref = []

    def walk(o, path="$"):
        if isinstance(o, dict):
            for k, v in o.items():
                if k == "geometry" and path == "$":
                    continue
                walk(v, f"{path}.{k}")
        elif isinstance(o, list):
            for v in o:
                walk(v, path)
        elif isinstance(o, str) and o.startswith("g-") and len(o) == 14 and o not in geo:
            bad_ref.append(o)
    walk({k: v for k, v in rec.items() if k != "checks"})
    face_ids = {f["id"] for f in rec["subdivision"]["faces"]}
    bad_face = [e["id"] for e in rec["subdivision"]["edges"]
                if (e["left_face"] not in face_ids and e["left_face"] not in ("exterior", "unclassified"))
                or (e["right_face"] not in face_ids and e["right_face"] not in ("exterior", "unclassified"))]
    # twin edges: each edge used once by its left face (+) and once by its right face (−)
    use = {}
    for f in rec["subdivision"]["faces"]:
        for ring in f["rings"]:
            for h in ring:
                use.setdefault(h, []).append(f["id"])
    twin_bad = []
    for e in rec["subdivision"]["edges"]:
        for side, sgn in (("left_face", "+"), ("right_face", "-")):
            fid = e[side]
            if fid in ("exterior",):
                continue
            got = use.get(e["id"] + sgn, [])
            if got != [fid]:
                twin_bad.append(e["id"] + sgn)
    # ring geometry reproduces the face area (exact shared edges)
    area_bad = []
    snapped = {}
    for p_, fid in zip(sub["_polys"], sub["_piece_face"]):
        snapped[fid] = snapped.get(fid, 0.0) + p_.area
    for f in faces:
        a = SB.signed_ring_area(sub, f["id"], edge_lines)
        ref = snapped.get(f["id"], 0.0)
        # rings rebuilt from the shared edges must reproduce the (grid-snapped) face exactly
        if abs(abs(a) - ref) > 0.01 + 1e-6 * ref:
            area_bad.append({"face": f["id"], "ring_area": round(a, 3), "face_area_snapped": round(ref, 3),
                             "face_area_float": round(f["geom"].area, 3)})
    diag = rec["subdivision"]["diagnostics"]
    tot = sum(f["geom"].area for f in faces)
    cover = abs(tot - domain.area)
    unclassified = sum(1 for e in rec["subdivision"]["edges"] if "unclassified" in (e["left_face"], e["right_face"]))
    hh_seen = {}
    for p in rec["parcels"]:
        for h_ in ([p["household"]] if p.get("household") else []) + list(p.get("co_households") or []):
            hh_seen[h_] = hh_seen.get(h_, 0) + 1
    multi = sorted(h for h, n in hh_seen.items() if n > 1)
    v18 = Ct.v18_violations({k: v for k, v in rec.items() if k != "checks"})
    inv_ok = (not errs and not dup and not bad_ref and not bad_face and not twin_bad and not area_bad and not multi and not v18
              and diag["unassigned_pieces"] == 0 and unclassified == 0 and cover <= max(1.0, 1e-5 * domain.area))
    out.append(_c("WP5.layer", inv_ok, {
        "schema_errors": errs[:5], "duplicate_ids": dup[:5], "dangling_geometry": bad_ref[:5], "dangling_faces": bad_face[:5],
        "twin_edge_violations": twin_bad[:5], "ring_area_mismatch": area_bad[:5], "household_multi_assigned": multi[:5],
        "v18": v18[:5], "coverage_gap_m2": round(cover, 3), "unassigned_pieces": diag["unassigned_pieces"],
        "unclassified_edges": unclassified, "polygonize": {k: diag[k] for k in ("polygonize_cuts", "polygonize_dangles",
                                                                                 "polygonize_invalid_rings", "snapping_slivers")}},
        kind="invariant"))
    out.append(_c("L5.twin_edges", not twin_bad and not area_bad,
                  {"edges": len(rec["subdivision"]["edges"]), "violations": len(twin_bad), "ring_area_mismatch": len(area_bad),
                   "examples": area_bad[:3]}, kind="hard"))
    # ------------------------------------------------------------------ access graph (public faces + street links)
    adj = {}
    for e in rec["subdivision"]["edges"]:
        if e["length_m"] < 0.9:
            continue
        a, b = e["left_face"], e["right_face"]
        adj.setdefault(a, set()).add(b)
        adj.setdefault(b, set()).add(a)
    soft_locks = {l["id"] for l in C.inp.locks if not l.get("hard", True)}
    # point story anchors are spots in public space (events happen on them): walkable, never moved
    public = {f["id"] for f in faces if f.get("public") or (f["kind"] == "lock" and f["of"] in soft_locks)}
    # street faces connected through links (bridges/culverts keep the street graph connected over water)
    links = rec["streets"]["links"]
    lgeom = {l["id"]: shape(rec["geometry"][l["centerline"]]) for l in links}
    face_geoms = {f["id"]: f["geom"] for f in faces if f["id"] in public}
    tree = shapely.STRtree(list(face_geoms.values())) if face_geoms else None
    fids = list(face_geoms)
    parent = {f: f for f in public}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def unite(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)
    for a in public:
        for b in adj.get(a, ()):
            if b in public:
                unite(a, b)
    unsupported = {x.get("street") for x in rec["water"]["crossings"] if x.get("origin") in ("new_street_crossing", "layer2_corridor_crossing", "mapped_route") and not x.get("structure_supported")}
    if tree is not None:
        for lid, lg in lgeom.items():
            if lid in unsupported:
                continue
            hit = [fids[int(i)] for i in tree.query(lg, predicate="intersects")]
            for a, b in zip(hit, hit[1:]):
                unite(a, b)
    # roots: faces containing gate / entrance nodes
    roots = set()
    gate_nodes = [n for n in rec["streets"]["nodes"] if n["kind"] in ("gate", "route_entrance")]
    for n in gate_nodes:
        p = Point(n["xz"])
        for fid in fids:
            if face_geoms[fid].distance(p) < 1.0:
                roots.add(find(fid))
    # faces touching a mapped route (unwalled entrances, outside-wall hamlets) are roots too
    rl = [r.line for r in C.inp.roads]
    for fid in fids:
        if fmap[fid]["kind"] in ("street", "cul_de_sac", "lane") and any(face_geoms[fid].distance(l) < 2.0 for l in rl):
            roots.add(find(fid))
    # the street network itself may leave the planning domain (mapped routes between clusters):
    # a public face is reached when it carries a link of a link-graph component that holds a gate,
    # an entrance or a mapped route
    import networkx as nx
    lg_ = nx.Graph()
    for l in links:
        if l["id"] in unsupported:
            continue
        lg_.add_edge(l["nodes"][0], l["nodes"][1], id=l["id"])
    root_nodes = {n["id"] for n in gate_nodes} | {x for l in links if l["hierarchy"] == "route" for x in l["nodes"]}
    good_links = set()
    for comp in nx.connected_components(lg_):
        if comp & root_nodes:
            good_links |= {d_["id"] for a_, b_, d_ in lg_.subgraph(comp).edges(data=True)}
    if tree is not None:
        for lid in good_links:
            for i in tree.query(lgeom[lid], predicate="intersects"):
                fid = fids[int(i)]
                if lgeom[lid].intersection(face_geoms[fid]).length >= 0.5:
                    roots.add(find(fid))
    reach_pub = {f for f in public if find(f) in roots}
    # ------------------------------------------------------------------ V46 — occupied parcels accessible
    occ = [p for p in rec["parcels"] if p["use"] == "residential"]
    ease_ok = set()
    for e in rec["easements"]:
        fe = f"face:{C.scope}:easement:{e['id']}"
        if any(b in reach_pub for b in adj.get(fe, ())):
            ease_ok.add(fe)
    bad = []
    for p in occ:
        nb = adj.get(p["id"], set())
        if not (nb & reach_pub) and not (nb & ease_ok):
            bad.append(p["id"])
    cyc = _cyclomatic(rec)
    out.append(_c("V46", not bad and bool(occ), {"occupied": len(occ), "inaccessible": len(bad), "examples": bad[:5],
                                                "network": cyc, "rule": "every occupied parcel shares ≥0.9 m with a public face connected to a gate/entrance (or holds an easement)"},
                  applicable=bool(occ)))
    out.append(_c("L5.access", not bad, {"inaccessible": len(bad)}, kind="hard", applicable=bool(occ)))
    # streets connected
    disconnected = sorted(f for f in public if f not in reach_pub and fmap[f]["kind"] in ("street", "cul_de_sac", "lane"))
    out.append(_c("L4.connected", not disconnected and bool(roots),
                  {"public_faces": len(public), "unreached_street_faces": disconnected[:5], "roots": len(roots)}, kind="hard"))
    # ------------------------------------------------------------------ households
    unplaced = [h["id"] for h in rec["households"] if not h.get("parcel")]
    out.append(_c("L5.households_once", not unplaced and not multi,
                  {"programmed": len(rec["households"]), "unplaced": len(unplaced), "multi": len(multi)}, kind="hard"))
    # ------------------------------------------------------------------ locks preserved (immutable faces)
    lk = []
    import shapely as _sh
    lf = [x["geom"] for x in faces if x["kind"] == "lock"]
    locked = len(lf)
    if lf:
        lu = _sh.union_all(lf)
        want = _sh.union_all([l["geom"] for l in C.inp.locks]).intersection(domain)
        if abs(lu.area - want.area) > 0.05 or lu.symmetric_difference(want).area > 0.05:
            lk.append("lock_union_changed")
        for x in faces:
            if x["kind"] in ("parcel", "street", "civic", "cul_de_sac", "lane", "easement") and x["geom"].intersection(want).area > 0.05:
                lk.append(x["id"])
    out.append(_c("L5.locks", not lk, {"lock_faces": locked, "altered": lk[:5], "policy": "locks are immutable faces; never moved"},
                  kind="hard", applicable=locked > 0))
    # ------------------------------------------------------------------ wall openings preserved
    if C.walled:
        ring = C.g(C.fr["wall"]["ring"])
        crossing_bad = []
        for l in links:
            if l["hierarchy"] == "primary":
                continue
            lg = lgeom[l["id"]]
            if lg.crosses(ring):
                crossing_bad.append(l["id"])
        new_open = [e["id"] for e in rec["subdivision"]["edges"] if e["purpose"] == "domain_edge" and C.walled
                    and ring.distance(Point(shape(rec["geometry"][e["geometry"]]).interpolate(0.5, normalized=True))) < 0.2]
        out.append(_c("L4.wall_openings", not crossing_bad,
                      {"streets_crossing_wall": crossing_bad[:5], "layer2_openings": len(C.fr["openings"])}, kind="hard"))
    # ------------------------------------------------------------------ crossings & drains
    unsup = [x["id"] for x in rec["water"]["crossings"] if x.get("origin") in ("new_street_crossing", "layer2_corridor_crossing", "mapped_route") and not x.get("structure_supported")]
    out.append(_c("L4.typed_crossings", not unsup, {"crossings": len(rec["water"]["crossings"]), "unsupported": unsup[:5]}, kind="hard"))
    no_out = [d["id"] for d in rec["water"]["drains"] if d["terminal"]["kind"] == "none"]
    wall_need = [d["id"] for d in rec["water"]["drains"] if d["terminal"]["kind"] == "wall_outlet_needed"]
    flat = [d["id"] for d in rec["water"]["drains"] if not d["min_fall_ok"]]
    out.append(_c("L4.drain_outlets", not no_out, {"drains": len(rec["water"]["drains"]), "without_outlet": len(no_out),
                                                   "via_wall_outlet_contracted_to_WP6": len(wall_need),
                                                   "flat_runs_need_grading": len(flat), "examples": no_out[:5],
                                                   "policy": "no outlet is manufactured; a missing outlet is a revision request"}, kind="hard"))
    # ------------------------------------------------------------------ V28 shared well
    wells = [f["id"] for f in faces if f["kind"] == "plaza" and "water-supply" in str(f["of"])]
    well_pub = [w for w in wells if w in reach_pub]
    out.append(_c("V28", bool(well_pub) and not bad,
                  {"wells": wells, "well_on_public_network": bool(well_pub), "households_reaching_by_public_faces": len(occ) - len(bad),
                   "rule": "well reached from every occupied parcel through public faces only (no private interior)"},
                  applicable=bool(wells)))
    # ------------------------------------------------------------------ V43 no unexplained curves / steps / bearings
    unexplained_edges = [e["id"] for e in rec["subdivision"]["edges"] if e["geometry_reason"] == "unclassified"]
    unexplained_bends = [(l["id"], b["xz"]) for l in links for b in l.get("bends", []) if not b.get("reason")]
    inherited = sum(1 for l in links if l["hierarchy"] == "primary" for b in l.get("bends", []) if b["reason"] == "planned_axis_grid_path")
    axes_set = [p["id"] for p in rec["parcels"] if p.get("axes") is not None]
    out.append(_c("V43", not unexplained_edges and not unexplained_bends and not axes_set,
                  {"edges_without_reason": len(unexplained_edges), "examples": unexplained_edges[:5],
                   "street_bends_without_reason": len(unexplained_bends), "parcel_bearings_confirmed": len(axes_set),
                   "level_steps_confirmed": 0, "random_perturbation": "none in the generator",
                   "layer2_grid_path_bends_recorded": inherited,
                   "reasons": _count([e["geometry_reason"].split(":")[0] for e in rec["subdivision"]["edges"]])}))
    # ------------------------------------------------------------------ V48 (data part)
    lc = [e for e in rec["subdivision"]["edges"] if e["level_change"]]
    lc_bad = [e["id"] for e in lc if "retaining_wall" not in e["allowed_closures"] and e["purpose"] not in ("gate_opening", "water_passage")]
    out.append(_c("V48", not lc_bad, {"edges_with_level_change": len(lc), "without_retaining_option": lc_bad[:5],
                                      "partial": "both ground levels recorded and retaining offered; support, drainage and wall section are WP6/WP8"},
                  applicable=bool(lc)))
    # ------------------------------------------------------------------ V49 water through the settlement
    chans = [c for c in rec["water"]["channels"] if c["effective_wet"]["geometry"]]
    inside = []
    for c in chans:
        g = shape(rec["geometry"][c["effective_wet"]["geometry"]])
        if g.intersects(domain):
            inside.append(c["reach"])
    passages_ok = True
    if C.walled and chans:
        ring = C.g(C.fr["wall"]["ring"])
        crossing_wall = []
        for c in chans:
            g = shape(rec["geometry"][c["effective_wet"]["geometry"]])
            if g.intersects(ring) and g.intersection(ring).length > 1.0:
                crossing_wall.append(c["feature"])
        wp = {p["channel"] for p in rec["water"]["wall_passages"]}
        missing = sorted(set(crossing_wall) - wp)
        passages_ok = not missing
    else:
        missing = []
    out.append(_c("V49", not unsup and passages_ok and not no_out,
                  {"channels_in_domain": inside, "street_crossings_typed": not unsup, "wall_passages_missing": missing,
                   "drains_without_outlet": len(no_out),
                   "rule": "inflow/outflow kept through crossings; street crossings typed; wall crossings via 수구; drains reach an outlet"},
                  applicable=bool(inside) or bool(rec["water"]["drains"])))
    # ------------------------------------------------------------------ V70 open ground states
    og = [s for s in rec["activity_sites"] if s.get("activity") == "open_ground_use"]
    v70 = all(any(st["key"] == "drill" for st in s["states"]) and all(not st.get("permanent_geometry", False) for st in s["states"])
              for s in og)
    out.append(_c("V70", v70, {"sites": len(og), "rule": "event occupation is a state of the same open ground; no permanent props"},
                  applicable=bool(og)))
    # ------------------------------------------------------------------ V33 (data part) market states
    mk = [s for s in rec["activity_sites"] if s.get("activity") == "market"]
    out.append(_c("V33.data", all(s["clear_corridor_ok"] for s in mk), {"sites": len(mk),
                  "partial": "stall band vs clear corridor only; stall layout data blocked (20 §6)"}, applicable=bool(mk)))
    # ------------------------------------------------------------------ V40 partial
    out.append(_c("V40", None, {"note": "compound-internal combinations are Layer 6 (WP8); L3–5 keeps districts as role + mix so a mix change re-runs only Layer 5"},
                  applicable=False))
    # ------------------------------------------------------------------ PUB-04 / V06 component
    p4 = rec["districts"]["pub04"]
    out.append(_c("PUB-04", p4["pass"], p4, applicable=C.walled))
    # quotas
    alloc = rec["districts"]["allocation"]
    out.append(_c("L3.quotas", all(a["within_tolerance"] for a in alloc), {"components": [
        {"component": a["component"], "within": a["within_tolerance"], "error_cells": a["quota_error_cells"]} for a in alloc]}))
    out.append(_c("L4.planar", rec["streets"]["planarity"]["pass"], rec["streets"]["planarity"], kind="hard"))
    # V14 (rewritten, design review #6): the builder completes an adaptation while preserving locks and ids
    ad = rec.get("adaptation")
    lk_ok = next((c["pass"] for c in out if c["id"] == "L5.locks"), None) is not False
    out.append(_c("V14", lk_ok and (ad is None or bool(ad.get("result"))),
                  {"adapted": ad is not None, "applied": (ad or {}).get("applied"), "locks_preserved": lk_ok,
                   "rule": "a site that does not fit the standard solve is adapted (benches, platforms, terraces, clusters, compact forms), locks immutable"},
                  applicable=True))
    # treated surface: raised platforms clear of the design water state
    ts = rec.get("site_treatment_summary") or {}
    out.append(_c("L5.treatments", not ts.get("flooded_after_treatment"), ts, kind="hard", applicable=bool(ts.get("treatments"))))
    return out


def _count(xs):
    out = {}
    for x in xs:
        out[x] = out.get(x, 0) + 1
    return dict(sorted(out.items()))


def _cyclomatic(rec):
    n = len(rec["streets"]["nodes"])
    m = len(rec["streets"]["links"])
    # connected components of the link graph
    par = {x["id"]: x["id"] for x in rec["streets"]["nodes"]}

    def f(x):
        while par[x] != x:
            par[x] = par[par[x]]
            x = par[x]
        return x
    for l in rec["streets"]["links"]:
        a, b = l["nodes"]
        ra, rb = f(a), f(b)
        if ra != rb:
            par[ra] = rb
    k = len({f(x) for x in par})
    mu = m - n + k
    return {"nodes": n, "links": m, "components": k, "independent_loops": mu, "form": "tree (branching)" if mu == 0 else "with loops"}
