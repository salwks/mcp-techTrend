"""Assemble the settlement-plan/1 record (shared geometry store, stable ids, chainage openings)."""
from __future__ import annotations

import hashlib
import math

import numpy as np
import shapely
from shapely.geometry import LineString, Point, Polygon

from . import GENERATOR_VERSION
from . import geometry as G
from . import program as P
from . import raster as Rr
from . import routing as Rt
from .model import diag


class GeomStore:
    """Geometry store keyed by content hash; semantic record ids live in the records."""

    def __init__(self):
        self.items = {}

    def add(self, geom) -> str | None:
        if geom is None or geom.is_empty:
            return None
        gj = G.to_geojson(geom)
        h = hashlib.sha1(G.canonical_json(gj).encode()).hexdigest()
        gid = f"g-{h[:12]}"
        if gid in self.items and self.items[gid] != gj:
            raise RuntimeError(f"geometry id collision {gid}")
        self.items[gid] = gj
        return gid


def _xz(p):
    return [G.r2(p[0]), G.r2(p[1])]


def _norm_interval(s0, s1, L):
    a, b = s0 % L, s1 % L
    return [round(a, 2), round(b, 2)], b < a


def corridor_network(ev, store, sub, h, rules, walled):
    """Split shortest-path-tree corridors at explicit nodes → nodes + links."""
    nodes, links = {}, []
    node_of_cell = {}
    gates = {g["seq"]: g for g in ev.get("gates", [])}
    sockets = ev.get("sockets", {})
    for k, c in sorted(sockets.items()):
        nid = f"n-civic-{k}"
        nodes[nid] = {"id": nid, "kind": "civic_entrance", "civic": k, "xz": _xz(sub.xz(c))}
        node_of_cell[c] = nid
    for j, c in enumerate(ev.get("junctions", [])):
        nid = f"n-junction-{j + 1:02d}"
        nodes[nid] = {"id": nid, "kind": "junction", "xz": _xz(sub.xz(c))}
        node_of_cell.setdefault(c, nid)
    seen = {}
    for corr in ev.get("corridors", []):
        cells = corr["cells"]
        if not cells:
            continue
        if corr["kind"] == "gate":
            g = gates[corr["ref"]]
            gid_ = f"n-gate-{corr['ref']:02d}" if walled else f"n-entrance-{corr['ref']:02d}"
            nodes[gid_] = {"id": gid_, "kind": "gate" if walled else "route_entrance", "xz": _xz(g["center"]),
                           "opening": f"gate-{corr['ref']:02d}" if walled else None}
            start_node = gid_
            start_pt = g["center"] if walled else None
        else:
            start_node = node_of_cell.get(cells[0])
            if start_node is None:
                start_node = f"n-civic-{corr['ref']}"
            start_pt = None
        # break points
        idx = [0] + [i for i, c in enumerate(cells) if i > 0 and c in node_of_cell] + [len(cells) - 1]
        idx = sorted(set(idx))
        prev_node = start_node
        for a, b in zip(idx, idx[1:]):
            seg = cells[a:b + 1]
            end_node = node_of_cell.get(seg[-1])
            if end_node is None:
                end_node = f"n-end-{len(nodes) + 1:02d}"
                nodes[end_node] = {"id": end_node, "kind": "end", "xz": _xz(sub.xz(seg[-1]))}
                node_of_cell[seg[-1]] = end_node
            key = (min(prev_node, end_node), max(prev_node, end_node), len(seg))
            pts = Rt.cells_to_xz(sub.grid, seg)
            if a == 0 and start_pt is not None:
                pts = [tuple(start_pt)] + pts
            if key in seen:
                prev_node = end_node
                continue
            line = LineString(pts) if len(pts) > 1 else LineString([pts[0], pts[0]])
            simp = line.simplify(1.0)
            ss, ys, gm = Rt.grade_profile(sub.grid, h, list(simp.coords))
            if gm > rules.p("routing.primary_max_grade") + 1e-6:
                simp = line
                ss, ys, gm = Rt.grade_profile(sub.grid, h, list(line.coords))
            lid = f"pc-{len(links) + 1:02d}"
            seen[key] = lid
            links.append({"id": lid, "nodes": [prev_node, end_node], "centerline": store.add(simp),
                          "width_m": rules.p("routing.corridor_width_m"), "hierarchy": "primary",
                          "grade_max": round(gm, 4), "length_m": round(simp.length, 2),
                          "profile": {"step_m": 2.0, "chainage": [round(v, 2) for v in ss],
                                      "y": [round(v, 2) for v in ys]},
                          "role": corr["kind"], "culvert_cells": corr.get("culvert_cells", 0),
                          "_line": simp})
            prev_node = end_node
    return nodes, links


def build(inp, A, family, fam_info, L1, F, rules, dependencies):
    store = GeomStore()
    R = rules
    plan = {"schema": "settlement-plan/1", "id": inp.id, "name": inp.name, "region": inp.region}
    plan["provenance"] = {
        "generator": GENERATOR_VERSION, "rules_hash": R.hash, "input_hashes": dict(sorted(inp.provenance.get("input_hashes", {}).items())),
        "dependencies": dependencies, "seed": inp.seed, "tier": inp.tier, "family": family, "family_selection": fam_info,
        "vertical": inp.provenance.get("vertical"), "coordinates": {"units": "world_m", "north_xz": [0, -1],
                                                                      "grid_m": G.GRID, "ring_orientation": "ccw_xz_math_start_north"},
        "height_window_px": inp.provenance.get("height_window_px"),
    }
    terr = inp.territory
    plan["territory"] = {
        "preferred": store.add(terr["preferred"]), "allowed": store.add(terr["allowed"]),
        "protected": store.add(A.protected_poly), "frame_permitted": store.add(F["ctx"].region),
        "sources": terr.get("sources", {}), "disagreements": terr.get("disagreements", []),
        "permissions": {"expansion": terr["allowed"].difference(terr["preferred"]).area > 0.5,
                        "farmland_conversion": "inside preferred only (counted as displacement)",
                        "water": "no occupation; enclosure allowed with typed passages"},
        "areas_m2": {"preferred": round(terr["preferred"].area, 1), "allowed": round(terr["allowed"].area, 1)},
    }
    plan["locks"] = [{"id": l["id"], "geometry": store.add(l["geom"])} for l in inp.locks]
    # ---------------- site
    plan["site"] = {"fields": "site-fields.npz", "features": "site.geojson", "summary": A.summary,
                    "water_features": [{"id": f.id, "kind": f.kind, "freshwater": f.freshwater, "width_m": f.width_m,
                                        "centerline": store.add(f.centerline) if f.centerline is not None else None}
                                       for f in inp.water_features],
                    "drainage_reserve": store.add(A.drain_poly),
                    "flood_screen": {str(k): store.add(v) for k, v in A.flood_polys.items()},
                    "axes": inp.axes,
                    "deferred": ["flow_accumulation", "sun", "viewshed", "auto_jinsan_ansan", "earthworks"]}
    diags = list(A.diagnostics) + list(L1["diagnostics"]) + list(F["diagnostics"])
    # ---------------- frame
    ranked = F["ranked"]
    chosen = ranked[0] if ranked else None
    shown = chosen
    if shown is None:
        cands = [e for e in F["evaluated"] if "poly" in e]
        cands.sort(key=lambda e: (-(e.get("objective") or {}).get("score", -1), e.get("stable_id", "")))
        shown = cands[0] if cands else None
    status = "valid" if chosen else ("no_candidate_found" if not F["evaluated"] else "failed")
    reason = None
    if chosen is None and F["evaluated"]:
        codes = {}
        for e in F["evaluated"]:
            for c in e["constraints"]:
                if c["severity"] == "error":
                    codes[c["code"]] = codes.get(c["code"], 0) + 1
        reason = max(sorted(codes), key=lambda k: codes[k]) if codes else "unknown"
        if reason in ("civic_fit_failed", "insufficient_capacity"):
            status = "insufficient_capacity"
    plan["status"] = status
    plan["status_reason"] = reason
    frame_rec, extras = None, {"shown": shown, "valid": chosen is not None}
    if shown is not None:
        frame_rec, extras2 = frame_record(shown, store, A, F, R, inp)
        extras.update(extras2)
    plan["frame"] = frame_rec
    # ---------------- program (final from frame, or allocation estimate)
    prof = L1["profile"]
    if shown is not None and shown.get("households") and "ledger" in shown:
        prog = P.program_record(inp.tier, prof, L1["insts"], shown["bundle"], shown["households"], R, inp.historical_households)
        T, entries, comps, frags, residual, comps_eff = shown["ledger"]
        prog["area_ledger"] = P.ledger_record(T, entries, residual, R, comps_eff)
        prog["area_ledger"]["component_geometry"] = [store.add(p) for p, _ in comps]
        prog["bundle"] = {"name": shown["bundle"]["name"], "area_m2": shown["bundle"]["area_m2"],
                          "tried": shown.get("bundles_tried", [])}
        prog["basis"] = "frame" + ("" if chosen else " (rejected candidate, for diagnosis)")
    else:
        prog = dict(L1["program"])
        prog["area_ledger"] = L1["ledger"]
        prog["basis"] = "allocation_estimate"
    prog["allocation_estimate"] = {"households": L1["program"]["households"]["represented"],
                                   "bundle": L1["program"]["bundle"]["name"], "ledger": L1["ledger"],
                                   "estimates": L1["program"].get("estimates")}
    plan["program"] = prog
    # ---------------- alternatives
    alts = []
    for rank, e in enumerate(ranked):
        alts.append({"rank": rank + 1, "id": e["stable_id"], "family": e["family"], "params": _clean(e["params"]),
                     "territory": store.add(e["poly"]), "objective": e["objective"],
                     "households": e["households"]["N"], "gates": len(e.get("gates", [])),
                     "bundle": e["bundle"]["name"]})
    plan["alternatives"] = alts
    plan["candidates"] = {"generated": F["generated"], "evaluated": len(F["evaluated"]),
                          "rejections": _rejections(F["evaluated"])}
    plan["diagnostics"] = diags
    plan["revision_requests"] = []
    if status != "valid":
        plan["revision_requests"].append({"id": "rr-01", "target": "L1/territory",
                                          "request": "enlarge allowed envelope, lower tier, or relax civic envelopes",
                                          "reason": reason or status})
    plan["geometry"] = dict(sorted(store.items.items()))
    return plan, extras, store


def _rejections(evaluated):
    out = {}
    for e in evaluated:
        for c in e["constraints"]:
            if c["severity"] == "error":
                out[c["code"]] = out.get(c["code"], 0) + 1
    return dict(sorted(out.items()))


def _clean(o):
    if isinstance(o, dict):
        return {k: _clean(v) for k, v in o.items()}
    if isinstance(o, (list, tuple)):
        return [_clean(v) for v in o]
    if isinstance(o, (np.integer,)):
        return int(o)
    if isinstance(o, (np.floating, float)):
        return round(float(o), 4)
    return o


def frame_record(ev, store, A, F, R, inp):
    ctx = F["ctx"]
    walled = ctx.walled
    poly = ev["poly"]
    rec = {"id": ev["stable_id"], "family": ev["family"], "params": _clean(ev["params"]), "valid": ev["valid"],
           "territory": store.add(poly), "area_m2": round(poly.area, 1),
           "precision_tolerance_m2": ev.get("precision_tolerance_m2"),
           "constraints": ev["constraints"], "objective": ev.get("objective")}
    extras = {}
    if walled and "ring" in ev:
        ring = ev["ring"]
        L = ring.length
        rec["wall"] = {"id": "wall-01", "ring": store.add(ring), "length_m": round(L, 2), "closed": True,
                       "orientation": "ccw_xz_math", "chainage_origin": _xz(ring.coords[0])}
        openings = []
        for g in ev.get("gates", []):
            iv, wraps = _norm_interval(g["s"][0], g["s"][1], L)
            openings.append({"id": f"gate-{g['seq']:02d}", "type": "gate", "subtype": g["kind"], "chainage": iv,
                             "wraps": wraps, "center": _xz(g["center"]), "width_m": R.p("gates.width_m"),
                             "routes": g["roads"]})
        for n_, w in enumerate(ev.get("passages", [])):
            iv, wraps = _norm_interval(w["s"][0], w["s"][1], L)
            openings.append({"id": f"water-{n_ + 1:02d}", "type": "water_passage", "subtype": w["subtype"],
                             "chainage": iv, "wraps": wraps, "center": _xz(w["center"]), "width_m": w["width_m"],
                             "channel": w["channel_id"]})
        openings.sort(key=lambda o: (o["chainage"][0], o["id"]))
        rec["openings"] = openings
    else:
        rec["wall"] = None
        rec["openings"] = []
        rec["clusters"] = [store.add(p) for p in G.parts(poly)]
    civ = []
    for n_, p in enumerate(ev.get("placed", []) or []):
        env = p["env"]
        sx, sz = G.front_point(p["xz"][0], p["xz"][1], env["depth_m"], p["bearing"], env["entrance_clearance_m"] / 2)
        civ.append({"id": f"civic-{p['key']}", "order": n_ + 1, "key": p["key"],
                    "name": next(r["name"] for r in ctx.insts if r["key"] == p["key"]), "variant": p["variant"],
                    "envelope": store.add(p["rect"]), "forecourt": store.add(p["strip"]),
                    "entrance_socket": _xz((sx, sz)), "bearing_deg": round(p["bearing"], 2),
                    "width_m": env["width_m"], "depth_m": env["depth_m"], "area_m2": env["area_m2"],
                    "court_min_m2": env["court_min_m2"], "contents": env["contents"],
                    "relief_m": round(p["relief"], 2),
                    "terrace_required": p["relief"] > R.p("civic.max_relief_m")})
    rec["civic_reserves"] = civ
    sub = ev.get("sub")
    rec["primary_corridors"] = {"nodes": [], "links": [], "reservation": None}
    rec["reroutes"], rec["connectors"] = [], []
    if sub is not None:
        nodes, links = corridor_network(ev, store, sub, sub.a(A.h), R, walled)
        extras["corridor_lines"] = [l.pop("_line") for l in links]
        rec["primary_corridors"] = {"nodes": [nodes[k] for k in sorted(nodes)], "links": links,
                                    "reservation": store.add(ev.get("corridor_poly"))}
        rr = []
        for n_, r in enumerate(ev.get("reroutes", [])):
            pts = Rt.cells_to_xz(sub.grid, r["cells"])
            line = LineString(pts) if len(pts) > 1 else None
            rr.append({"id": f"reroute-{n_ + 1:02d}", "route": r["road_id"], "crossing": _xz(r["crossing_xz"]),
                       "to_opening": f"gate-{r['gate_seq']:02d}", "path": store.add(line) if line else None,
                       "cost_m": r["cost_m"]})
        rec["reroutes"] = rr
        cons = []
        for g in ev.get("gates", []):
            for c in g["connectors"]:
                pts = Rt.cells_to_xz(sub.grid, c["cells"])
                if len(pts) > 1:
                    cons.append({"route": c["road_id"], "kind": c["kind"], "to_opening": f"gate-{g['seq']:02d}",
                                 "path": store.add(LineString(pts).simplify(1.0))})
        rec["connectors"] = cons
    ws = ev.get("water_supply")
    rec["water_access"] = [] if not ws else [{
        "id": "water-supply-01", "kind": ws["kind"], "xz": _xz(ws["xz"]), "reservation": store.add(ws["geom"]),
        "walking_cost_m": ws["cost_m"], "uncertainty": ws["freshwater_uncertainty"],
        "nearest_surface_water_cost_m": ws.get("nearest_surface_water_cost_m")}]
    rec["approaches"] = [{"route": a["road_id"], "kind": a["kind"], "xz": _xz(a["xz"]), "bearing_deg": round(a["bearing"], 1),
                          "served_by": a["served_by"] if isinstance(a.get("served_by"), str) or a.get("served_by") is None
                          else f"gate-{a['served_by']:02d}"} for a in ev.get("approaches", [])]
    contracts = []
    main = rec["civic_reserves"][0]["id"] if rec["civic_reserves"] else None
    for o in rec["openings"]:
        if o["type"] == "gate":
            contracts.append({"id": f"ac-{o['id']}", "from": o["routes"] or ["route_network"], "via": o["id"],
                              "to": main, "mode": "primary_corridor"})
    rec["access_contracts"] = contracts
    rec["households"] = ev["households"]["N"] if ev.get("households") else None
    return rec, extras


def site_geojson(inp, A, store=None):
    feats = []

    def add(kind, geom, **props):
        if geom is None or geom.is_empty:
            return
        feats.append({"type": "Feature", "properties": dict(kind=kind, **props), "geometry": G.to_geojson(geom)})
    add("water", A.water_poly)
    for k, v in A.flood_polys.items():
        add("flood_screen", v, offset_source_m=k, offset_game_m=round(k * inp.vertical_scale, 3))
    add("drainage_reserve", A.drain_poly)
    add("protected", A.protected_poly)
    add("farmland", A.farm_poly)
    add("farmland_displaced", A.farm_displaced)
    add("usable_housing", A.house_poly, rule="slope<=15deg, no water/flood+3/drainage/protected/locks")
    add("usable_civic", A.civic_poly, rule="slope<=10deg, same exclusions")
    add("routes", shapely.union_all([r.line for r in inp.roads]) if inp.roads else None)
    return {"type": "FeatureCollection", "features": feats}


def site_fields(A):
    return {"height_smoothed": A.h.astype(np.float32), "slope_deg": A.slope.astype(np.float32),
            "aspect_deg": np.nan_to_num(A.aspect, nan=-1).astype(np.float32),
            "tpi30": A.tpi[30].astype(np.float32), "tpi100": A.tpi[100].astype(np.float32),
            "tpi300": A.tpi[300].astype(np.float32), "flood_R": A.R.astype(np.float32),
            "water_distance_m": np.where(np.isfinite(A.wdist), A.wdist, -1).astype(np.float32),
            "route_cost_m": np.where(np.isfinite(A.route_cost), A.route_cost, -1).astype(np.float32),
            "water_cost_m": np.where(np.isfinite(A.water_cost), A.water_cost, -1).astype(np.float32),
            "flood1": A.floods[1], "flood3": A.floods[3], "flood5": A.floods[5],
            "usable_housing": A.house_ok, "usable_civic": A.civic_ok,
            "origin_cell": np.array([A.win.x0, A.win.z0, A.win.cell], dtype=np.float64)}
