"""Automated checks (spec §5) + a JSON-schema subset validator for the outputs."""
from __future__ import annotations

import json
import math
import os
import re

import numpy as np
import shapely
from shapely.geometry import LineString, Point, shape

from . import geometry as G
from . import program as P
from . import raster as Rr
from . import routing as Rt
from .rules import val

SCHEMA_DIR = os.path.join(os.path.dirname(__file__), "schemas")


# ---------------------------------------------------------------- mini JSON schema
def schema_errors(obj, schema, path="$", root=None):
    root = root or schema
    errs = []
    if "$ref" in schema:
        ref = schema["$ref"].split("/")[-1]
        return schema_errors(obj, root["$defs"][ref], path, root)
    t = schema.get("type")
    if t:
        types = t if isinstance(t, list) else [t]
        ok = False
        for ty in types:
            if ty == "object" and isinstance(obj, dict): ok = True
            elif ty == "array" and isinstance(obj, list): ok = True
            elif ty == "string" and isinstance(obj, str): ok = True
            elif ty == "number" and isinstance(obj, (int, float)) and not isinstance(obj, bool): ok = True
            elif ty == "integer" and isinstance(obj, int) and not isinstance(obj, bool): ok = True
            elif ty == "boolean" and isinstance(obj, bool): ok = True
            elif ty == "null" and obj is None: ok = True
        if not ok:
            return [f"{path}: expected {t}, got {type(obj).__name__}"]
    if "enum" in schema and obj not in schema["enum"]:
        errs.append(f"{path}: {obj!r} not in {schema['enum']}")
    if "pattern" in schema and isinstance(obj, str) and not re.match(schema["pattern"], obj):
        errs.append(f"{path}: {obj!r} !~ {schema['pattern']}")
    if isinstance(obj, dict):
        for k in schema.get("required", []):
            if k not in obj:
                errs.append(f"{path}: missing {k}")
        for k, sub in schema.get("properties", {}).items():
            if k in obj:
                errs.extend(schema_errors(obj[k], sub, f"{path}.{k}", root))
        ap = schema.get("additionalProperties")
        if isinstance(ap, dict):
            for k, v in obj.items():
                if k not in schema.get("properties", {}):
                    errs.extend(schema_errors(v, ap, f"{path}.{k}", root))
    if isinstance(obj, list) and "items" in schema:
        for i, v in enumerate(obj):
            errs.extend(schema_errors(v, schema["items"], f"{path}[{i}]", root))
    if isinstance(obj, (int, float)) and not isinstance(obj, bool):
        if "minimum" in schema and obj < schema["minimum"]:
            errs.append(f"{path}: {obj} < {schema['minimum']}")
        if "maximum" in schema and obj > schema["maximum"]:
            errs.append(f"{path}: {obj} > {schema['maximum']}")
    return errs


def load_schema(name):
    with open(os.path.join(SCHEMA_DIR, name), encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------- checks
def _chk(out, cid, layer, ok, detail=None, applicable=True):
    out.append({"id": cid, "layer": layer, "pass": bool(ok) if applicable else None,
                "applicable": applicable, "detail": detail})


def geom(plan, gid):
    return shape(plan["geometry"][gid]) if gid else None


def run(plan, inp, A, L1, F, rules):
    out = []
    R = rules
    # ---------------- L0
    h = inp.height
    fin = bool(np.isfinite(h).all())
    if inp.meta.get("fixture"):
        rng = (float(h.min()), float(h.max()))
        _chk(out, "L0.decode", "L0", fin, {"range": [round(rng[0], 3), round(rng[1], 3)], "source": "synthetic formula"})
    else:
        rec = inp.provenance
        import json as _j
        _chk(out, "L0.decode", "L0", fin, {"range": [round(float(h.min()), 3), round(float(h.max()), 3)],
                                           "note": "decoded once; height.remap not reapplied",
                                           "vertical": rec.get("vertical")})
    g = A.win
    full = inp.grid
    di = (g.x0 - full.x0) / full.cell
    dj = (g.z0 - full.z0) / full.cell
    _chk(out, "L0.alignment", "L0", abs(di - round(di)) < 1e-9 and abs(dj - round(dj)) < 1e-9 and g.cell == full.cell,
         {"window_origin": [g.x0, g.z0], "cell": g.cell, "convention": "cell centre = x0 + i*cell"})
    w_ok = True
    det = {}
    for f in inp.water_features:
        if f.area is not None and not f.area.is_empty:
            n = int(Rr.rasterize(full, f.area).sum())
            det[f.id] = n
            w_ok &= n > 0
    st = A.stages
    mono = all(bool((A.floods[a] <= A.floods[b]).all()) for a, b in zip(st, st[1:]))
    touch = True
    lab, n = Rr.label(A.floods[A.stage_ex])
    if n:
        edge = np.zeros(lab.shape, bool)
        edge[0, :] = edge[-1, :] = edge[:, 0] = edge[:, -1] = True
        # springs are not sources; components may continue to water outside the window
        ids = set(np.unique(lab[A.water & A.floods[A.stage_ex]]).tolist()) | set(np.unique(lab[edge]).tolist())
        touch = set(range(1, n + 1)) <= ids | {0}  # components may connect to water outside the window
    _chk(out, "L0.water", "L0", w_ok and mono and touch,
         {"feature_cells": det, "flood_monotonic": mono, "flood_components_touch_water": bool(touch)})
    if inp.meta.get("fixture"):
        probes = _probes(inp, A)
        _chk(out, "L0.probes", "L0", all(p["pass"] for p in probes), probes)
    else:
        _chk(out, "L0.probes", "L0", None, "synthetic probes only", applicable=False)
    # ---------------- L1
    prog = plan["program"]
    res = [prog["area_ledger"]["residual_m2"], prog["allocation_estimate"]["ledger"]["residual_m2"]]
    lim = R.p("acceptance.ledger_residual_m2")
    _chk(out, "L1.ledger", "L1", all(abs(r) <= lim for r in res), {"residuals_m2": res, "limit": lim})
    shares = val(L1["profile"]["class_shares"])
    N = prog["households"]["represented"]
    tot = sum(shares.values())
    err = max((abs(prog["households"]["by_class"][c] - N * shares[c] / tot) for c in shares), default=0.0)
    _chk(out, "L1.rounding", "L1", err < R.p("acceptance.class_rounding_error"), {"max_error": round(err, 4)})
    med = val(L1["profile"]["parcel_median_m2"])
    pa = prog["households"]["parcel_area_m2"]
    s1 = all(abs(pa[c] - med[c] * R.p("world.area_scale")) < 1e-6 for c in med)
    s2 = all(abs(i["envelope"]["area_m2"] - i["envelope"]["hist_area_m2"] * R.p("world.area_scale")) < 0.05
             for i in prog["institutions"])
    rp = plan.get("region_profile") or {}
    bf = ((rp.get("scale_policy") or {}).get("building") or {}).get("factor")
    s3 = bf is not None and abs(bf * bf - R.p("world.area_scale")) < 1e-9 and abs(prog["scale"]["length"] - bf) < 1e-12
    _chk(out, "L1.scale_once", "L1", s1 and s2 and s3 and prog["scale"]["scale_applied"],
         {"parcel_areas": s1, "institution_areas": s2, "single_record_in_region_profile": s3, "factor": bf})
    # ---------------- L2
    fr = plan.get("frame")
    applicable = fr is not None
    l2_start = len(out)
    if not applicable:
        for cid in ("L2.ring", "L2.crossings", "L2.openings", "L2.containment", "L2.intrusion", "L2.corridors"):
            _chk(out, cid, "L2", None, "no frame", applicable=False)
    else:
        poly = geom(plan, fr["territory"])
        tol = R.p("acceptance.intrusion_m2") + poly.length * G.GRID / 2
        walled = fr["wall"] is not None
        if walled:
            ring = geom(plan, fr["wall"]["ring"])
            closed = ring.is_closed and ring.is_simple
            from shapely.geometry import Polygon as _P
            pr = _P(ring.coords)
            ccw = pr.exterior.is_ccw
            start_north = abs(ring.coords[0][1] - min(c[1] for c in ring.coords)) < 1e-6
            _chk(out, "L2.ring", "L2", closed and pr.is_valid and ccw and start_north,
                 {"simple_closed": closed, "ccw": ccw, "start_north": start_north, "length_m": fr["wall"]["length_m"]})
            # crossings: roads → gate/reroute; channels → passages
            L = fr["wall"]["length_m"]
            bad = []
            for a in fr["approaches"]:
                if a["kind"] == "crossing" and not a["served_by"]:
                    bad.append(a)
            ch_bad = []
            passes = [o for o in fr["openings"] if o["type"] == "water_passage"]
            for f in inp.water_features:
                if f.centerline is None:
                    continue
                for (x, z) in G.line_crossings(f.centerline, ring):
                    s = G.chainage(ring, x, z)
                    if not any(G.interval_overlap((s - 0.1, s + 0.1), tuple(o["chainage"]) if not o["wraps"] else (o["chainage"][0], o["chainage"][1] + L), L) > 0 for o in passes):
                        ch_bad.append({"channel": f.id, "s": round(s, 1)})
            _chk(out, "L2.crossings", "L2", not bad and not ch_bad,
                 {"untyped_route_crossings": len(bad), "untyped_channel_crossings": ch_bad,
                  "gates": sum(1 for o in fr["openings"] if o["type"] == "gate"), "water_passages": len(passes),
                  "reroutes": len(fr.get("reroutes", []))})
            ivs = [(o["id"], (o["chainage"][0], o["chainage"][1] + (L if o["wraps"] else 0))) for o in fr["openings"]]
            ov = []
            for i in range(len(ivs)):
                for j in range(i + 1, len(ivs)):
                    if G.interval_overlap(ivs[i][1], ivs[j][1], L) > 1e-6:
                        ov.append([ivs[i][0], ivs[j][0]])
            inrange = all(0 <= o["chainage"][0] < L + 1e-6 and 0 <= o["chainage"][1] <= L + 1e-6 for o in fr["openings"])
            _chk(out, "L2.openings", "L2", not ov and inrange, {"overlaps": ov, "count": len(ivs)})
        else:
            _chk(out, "L2.ring", "L2", None, "unwalled", applicable=False)
            _chk(out, "L2.crossings", "L2", None, "unwalled (no wall)", applicable=False)
            _chk(out, "L2.openings", "L2", None, "unwalled", applicable=False)
        allowed = geom(plan, plan["territory"]["allowed"])
        prot = geom(plan, plan["territory"]["protected"])
        outside = poly.difference(allowed).area
        civ = [geom(plan, c["envelope"]) for c in fr["civic_reserves"]]
        civ_out = sum(c.difference(poly).area for c in civ)
        res_geoms = civ + [geom(plan, w["reservation"]) for w in fr["water_access"] if w["reservation"]]
        corr = geom(plan, fr["primary_corridors"]["reservation"]) if fr.get("primary_corridors") and fr["primary_corridors"]["reservation"] else None
        if corr is not None:
            res_geoms.append(corr)
        corr_out = corr.difference(poly).area if corr is not None else 0.0
        _chk(out, "L2.containment", "L2", outside <= tol and civ_out <= tol and corr_out <= tol,
             {"frame_outside_allowed_m2": round(outside, 3), "civic_outside_frame_m2": round(civ_out, 3),
              "corridor_outside_frame_m2": round(corr_out, 3), "tolerance_m2": round(tol, 3)})
        def ltol(g, other):
            # local precision tolerance: serialized vertices move ≤ grid/2 along the shared boundary only
            near = g.boundary.intersection(other.boundary.buffer(G.GRID)).length
            return R.p("acceptance.intrusion_m2") + near * G.GRID / 2
        intr = 0.0
        excess = []
        if prot is not None:
            for g in res_geoms:
                if g is None:
                    continue
                a_ = g.intersection(prot).area
                intr += a_
                if a_ > ltol(g, prot):
                    excess.append(round(a_, 3))
        neigh = A.neigh_poly
        nb = poly.intersection(neigh).area if not neigh.is_empty else 0.0
        if nb > ltol(poly, neigh) if not neigh.is_empty else False:
            excess.append(("neighbour", round(nb, 3)))
        lock_i = 0.0
        if not A.lock_poly.is_empty:
            lock_i = sum(g.intersection(A.lock_poly).area for g in res_geoms if g is not None)
        _chk(out, "L2.intrusion", "L2", not excess and lock_i <= R.p("acceptance.intrusion_m2") + 1e-6,
             {"reserves_on_protected_m2": round(intr, 3), "excess": excess, "locks_m2": round(lock_i, 3),
              "neighbour_enclosed_m2": round(nb, 3), "rule": "zero up to local grid tolerance on shared boundaries"})
        pc = fr.get("primary_corridors")
        if pc:
            import networkx as nx  # small vector graph (spec: NetworkX only for small graphs)
            gx = nx.Graph()
            gx.add_nodes_from(sorted(n["id"] for n in pc["nodes"]))
            gx.add_edges_from(tuple(l["nodes"]) for l in pc["links"])
            req = sorted(n["id"] for n in pc["nodes"] if n["kind"] in ("gate", "civic_entrance", "route_entrance"))
            comps = [c for c in nx.connected_components(gx) if c & set(req)]
            roots = list(range(len(comps)))
            connected = len(roots) <= 1
            gmax = 0.0
            lim = R.p("routing.primary_max_grade")
            # continuous gate→entrance paths (windows cross link junctions), then the split links
            for l in list(pc.get("paths", [])) + list(pc["links"]):
                line = geom(plan, l["centerline"])
                if l.get("grade_measure", {}).get("measure") == "sustained_smoothed_centreline":
                    gm = Rt.sustained_grade(A.win, A.h, list(line.coords), R.p("routing.mountain.window_m"),
                                            R.p("routing.mountain.smooth_m"))[0]
                    lim = R.p("routing.mountain.max_grade")
                else:
                    _, _, gm = Rt.grade_profile(A.win, A.h, list(line.coords))
                gmax = max(gmax, gm)
            gate_nodes = sum(1 for n in pc["nodes"] if n["kind"] in ("gate", "route_entrance"))
            _chk(out, "L2.corridors", "L2", connected and gmax <= lim + 1e-6 and gate_nodes >= 1,
                 {"connected": connected, "grade_max_recomputed": round(gmax, 4), "limit": lim,
                  "road_class": pc.get("road_class"), "links": len(pc["links"]),
                  "access_nodes": gate_nodes})
        else:
            _chk(out, "L2.corridors", "L2", False, "no corridors")
    if plan["status"] != "valid":
        # invariants are enforced on accepted frames; for a rejected diagnostic candidate keep the result
        for c in out[l2_start:]:
            if c["applicable"]:
                c["detail"] = {"rejected_candidate_result": c["pass"], "detail": c["detail"]}
                c["pass"], c["applicable"] = None, False
    # ---------------- refs & schema
    refs = set()

    def walk(o):
        if isinstance(o, dict):
            for k, v in o.items():
                if k != "geometry":
                    walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
        elif isinstance(o, str) and re.fullmatch(r"g-[0-9a-f]{12}", o):
            refs.add(o)
    walk(plan)
    missing = sorted(refs - set(plan["geometry"]))
    _chk(out, "plan.geometry_refs", "plan", not missing, {"refs": len(refs), "missing": missing})
    errs = schema_errors(json.loads(json.dumps(plan)), load_schema("settlement-plan.schema.json"))
    _chk(out, "plan.schema", "plan", not errs, errs[:10])
    return out


def _probes(inp, A):
    from . import fixtures as Fx
    out = []
    pts = {"syn_terrace": [(0, 0), (0, 200), (-300, -200)], "syn_basin": [(0, -200), (0, 0)],
           "syn_ridge": [(180, 0), (0, 0)], "syn_estuary": [(-160, 0), (100, 100)],
           "syn_basin_sanseong": [(0, -200)], "fail_blocked_access": [(0, 100)],
           "fail_impossible_civic": [(0, 70)], "fail_water_crossing": [(0, 0)]}
    fn = {"syn_terrace": Fx.terrace_height, "syn_basin": Fx.basin_height, "syn_ridge": Fx.ridge_height,
          "syn_estuary": Fx.estuary_height, "syn_basin_sanseong": Fx.basin_height,
          "fail_impossible_civic": Fx.terrace_height, "fail_water_crossing": Fx.terrace_height}
    f = fn.get(inp.id)
    for (x, z) in pts.get(inp.id, []):
        i, j = inp.grid.ij(x, z)
        hv = float(inp.height[j, i])
        rec = {"xz": [x, z], "y": round(hv, 4)}
        ok = True
        if f is not None:
            exp = float(f(np.array([[x]], float), np.array([[z]], float))[0, 0])
            rec["expected"] = round(exp, 4)
            ok = abs(hv - exp) < 1e-6
        # analytic slope check on the smooth terrace
        if inp.id == "syn_terrace" and (x, z) == (0, 200):
            si, sj = A.win.ij(x, z)
            sl = float(A.slope[sj, si])
            exp_s = math.degrees(math.atan(0.004 + 5 / 12 * (1 - math.tanh((z + 80) / 12) ** 2)))
            rec["slope_deg"] = round(sl, 4)
            rec["slope_expected_deg"] = round(exp_s, 4)
            ok &= abs(sl - exp_s) < 0.05
        rec["pass"] = bool(ok)
        out.append(rec)
    return out
