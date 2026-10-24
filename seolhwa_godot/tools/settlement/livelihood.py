"""WP3 / audit K9: the "movement and livelihood" input layer, between terrain·water and
settlement function (spec order: 지형·물 → 이동과 생업 → 정착 기능 → …).

Routes become contract Route records with per-mode passability (foot / pack horse / cart; the
limits are provisional test values, audit K5) measured on the existing route lines; the
settlement frame reads its approaches from this layer, not from raw region roads. Livelihood
records cultivation, forest and water-work land around the allocation. Nothing here invents
new routes or fields: it describes the given data so later layers can depend on it.
"""
from __future__ import annotations

import math

import numpy as np
from shapely.geometry import Point

from . import contract as C
from . import raster as Rr
from . import routing as Rt

PURPOSE_BY_CLASS = {"대로": "inter-town trunk", "중로": "town link", "소로": "local path"}


def build(inp, A, rules, store=None) -> dict:
    modes = rules.p("movement.mode_limits")
    routes = []
    T = getattr(A, "terrain", None)
    W = getattr(A, "waterlayer", None)
    for r in inp.roads:  # given data, canonical order
        pts = list(r.line.coords)
        sus, loc, _, _, _ = Rt.sustained_grade(inp.grid, A.full_h, pts, rules.p("routing.mountain.window_m"), 0.0)
        wp4 = route_support(inp, A, r, rules, T, W) if T is not None else None
        mlist = []
        for m in ("foot", "pack_horse", "cart"):
            lim = modes[m]
            reasons = [] if sus <= lim else [f"sustained grade {sus:.3f} > {lim}"]
            if wp4 and wp4["cliff_traversal_m"] > 0:
                reasons.append(f"crosses cliff cells over {wp4['cliff_traversal_m']} m")
            mlist.append({"mode": m, "passable": not reasons, "limit": lim, "status": "proposed",
                          "measured_sustained_grade": round(sus, 4), "reasons": reasons})
        lp = {"sustained_grade_10m": round(sus, 4), "local_max_grade": round(loc, 4),
              "length_m": round(r.line.length, 1)}
        if wp4:
            lp.update(wp4["long_profile"])
        body = {"purpose": PURPOSE_BY_CLASS.get(r.klass, "route"), "class": r.klass, "name": r.name,
                "nodes": [f"end:{r.id}:0", f"end:{r.id}:1"], "modes": mlist,
                "width_section": {"width_m": r.width_m, "status": "proposed",
                                  "sections": wp4["sections"] if wp4 else None},
                "long_profile": lp,
                "support_drainage": wp4["support_drainage"] if wp4 else [],
                "divide_crossings": wp4["divide_crossings"] if wp4 else [],
                "catchments_at_ends": wp4["catchments_at_ends"] if wp4 else None,
                "cliff_traversal_m": wp4["cliff_traversal_m"] if wp4 else None,
                "centerline": store.add(r.line) if store is not None else None,
                "source_id": r.id}
        scope = inp.region if not inp.meta.get("fixture") else f"SYNTHETIC.{inp.id}"
        body["meta"] = C.meta(f"route:{scope}:{r.id}".replace("#", "_"), status="proposed",
                              sources=[f"region_data/{inp.region}/region.json#roads"] if not inp.meta.get("fixture") else ["fixture"],
                              content={k: v for k, v in body.items() if k != "centerline"})
        routes.append(body)
    pref = inp.territory["preferred"]
    c = pref.centroid
    cell_a = A.win.cell ** 2
    X, Z = np.meshgrid(A.win.xs(), A.win.zs())
    lv = {}
    lu = inp.meta.get("landuse")
    for rad in rules.p("agriculture.radii_m"):
        disk = (X - c.x) ** 2 + (Z - c.y) ** 2 <= rad * rad
        rec = {"farmland_m2": round(float((disk & A.farmland).sum()) * cell_a, 1)}
        if lu is not None:
            luw = lu[A.sl]
            rec["paddy_m2"] = round(float((disk & (luw == 2)).sum()) * cell_a, 1)
            rec["field_m2"] = round(float((disk & (luw == 3)).sum()) * cell_a, 1)
            rec["forest_m2"] = round(float((disk & np.isin(luw, (0, 9))).sum()) * cell_a, 1)
        rec["freshwater_bank_cells"] = int((disk & A.bank).sum())
        lv[str(rad)] = rec
    layer = {"order": ["terrain_water", "movement_livelihood", "settlement_function", "frame"],
             "routes": routes, "crossings": A.existing_crossings,
             "livelihood": {"within_m": lv, "irrigation": None, "irrigation_missing_reason": "no irrigation data (WP4/C06)",
                            "forest_use": None, "forest_use_missing_reason": "management type unknown (WP10)",
                            "status": "proposed"}}
    return layer


def frame_roads(inp, A):
    """Roads the frame approaches from = the movement layer's routes. Existing routes are given
    facts and are all kept, whatever their per-mode passability (recorded, not used to drop)."""
    keep = {r["source_id"] for r in A.movement["routes"]}
    return [r for r in inp.roads if r.id in keep]


def route_support(inp, A, r, rules, T, W):
    """WP4: long profile (chainage, ascent), cross sections with support / cut, drainage contacts
    and divide crossings of one given route (spec 16 GEO-03: 절취면·통행면·지지부·배수 접점).
    Support is recorded as a candidate where the downhill side falls away, never forced."""
    from shapely.geometry import LineString, Point
    import shapely
    from . import geometry as G
    from .terrain import catchment_at, GC
    line = r.line
    L = line.length
    step = rules.p("routes.station_step_m")
    ss = np.linspace(0, L, max(2, int(math.ceil(L / step)) + 1))
    xy = shapely.get_coordinates(shapely.line_interpolate_point(line, ss))
    y = Rr.bilinear(inp.grid, A.full_h, xy[:, 0], xy[:, 1])
    dy = np.diff(y)
    t = np.gradient(xy, axis=0)
    n = np.hypot(t[:, 0], t[:, 1]); n[n == 0] = 1
    t = t / n[:, None]
    left = np.stack([t[:, 1], -t[:, 0]], axis=1)
    hw = r.width_m / 2
    sd = rules.p("routes.side_sample_m")

    def at(off):
        return Rr.bilinear(inp.grid, A.full_h, xy[:, 0] + left[:, 0] * off, xy[:, 1] + left[:, 1] * off)
    yl_e, yr_e = at(hw), at(-hw)
    yl_o, yr_o = at(hw + 3.0), at(-hw - 3.0)
    yl_s, yr_s = at(hw + sd), at(-hw - sd)
    cross = (yl_s - yr_s) / (2 * hw + 2 * sd)
    cs = rules.p("routes.cross_slope")
    sup_g, cut_g = rules.p("routes.support_drop_grade"), rules.p("routes.cut_rise_grade")
    rows = []
    for q in range(len(ss)):
        ac = abs(float(cross[q]))
        sec = "flat" if ac < cs["flat"] else ("steep_sidehill" if ac > cs["steep"] else "sidehill")
        up_left = yl_s[q] >= yr_s[q]
        down_drop = ((yr_e[q] - yr_o[q]) if up_left else (yl_e[q] - yl_o[q])) / 3.0
        up_rise = ((yl_o[q] - yl_e[q]) if up_left else (yr_o[q] - yr_e[q])) / 3.0
        support = "retaining_candidate" if down_drop > sup_g else "natural_slope"
        cut = "cut_face" if up_rise > cut_g else "none"
        rows.append((sec, support, cut, "left" if up_left else "right"))
    sections = []
    for q, row in enumerate(rows):
        s0 = float(ss[q])
        if sections and sections[-1]["_k"] == row:
            sections[-1]["chainage"][1] = round(s0, 1)
            continue
        if sections:
            sections[-1]["chainage"][1] = round(s0, 1)
        sections.append({"_k": row, "chainage": [round(s0, 1), round(s0, 1)], "section": row[0], "valley_side_support": row[1],
                         "hill_side": row[2], "uphill": row[3], "status": "proposed"})
    for x in sections:
        x.pop("_k")
    contacts = []
    # drainage lines (DEM) crossing the route, not mapped water
    gc = T.gc
    acc = T.acc.reshape(T.hc.shape)
    thr = rules.p("routes.drainage_area_m2")
    prev = False
    waterm = T.water
    for q in range(len(ss)):
        i, j = gc.ij(xy[q, 0], xy[q, 1])
        if not gc.inside(i, j):
            prev = False
            continue
        on = bool(acc[j, i] >= thr and not waterm[j, i])
        if on and not prev:
            contacts.append({"kind": "drainage_crossing", "chainage": round(float(ss[q]), 1), "xz": [G.r2(xy[q, 0]), G.r2(xy[q, 1])],
                             "upslope_area_m2": round(float(acc[j, i]), 1), "treatment": None,
                             "treatment_candidates": ["ford", "stepping_stones", "culvert"],
                             "missing_reason": "no mapped crossing; the treatment needs a source or a decision",
                             "status": "proposed"})
        prev = on
    if W is not None:
        for c in W.crossings:
            if c.get("route") == r.id:
                contacts.append({"kind": "mapped_crossing", "crossing": c["id"], "class": c["class"],
                                 "chainage": round(float(line.project(Point(c["xz"]))), 1), "status": "proposed"})
        for c in W.candidates:
            if line.distance(Point(c["xz"])) < 2 * r.width_m + 2:
                contacts.append({"kind": "unmapped_water_crossing", "candidate": c["id"],
                                 "chainage": round(float(line.project(Point(c["xz"]))), 1), "status": "proposed"})
    # sag points (water collects on the road)
    sag = rules.p("routes.sag_depth_m")
    k = max(1, int(round(30.0 / step)))
    for q in range(1, len(ss) - 1):
        a, b = max(0, q - k), min(len(ss), q + k + 1)
        if y[q] == y[a:b].min() and min(y[a:q].max(), y[q + 1:b].max()) - y[q] >= sag:
            contacts.append({"kind": "low_point", "chainage": round(float(ss[q]), 1), "xz": [G.r2(xy[q, 0]), G.r2(xy[q, 1])],
                             "depth_m": round(float(min(y[a:q].max(), y[q + 1:b].max()) - y[q]), 2), "status": "proposed"})
    # wet ground: route close above drainage
    wet = rules.p("routes.wet_hand_m")
    hand = np.nan_to_num(T.hand, nan=1e9)
    onv = T.on_drainage
    run = None
    for q in range(len(ss)):
        i, j = gc.ij(xy[q, 0], xy[q, 1])
        w_ = gc.inside(i, j) and onv[j, i] and hand[j, i] <= wet
        if w_ and run is None:
            run = [float(ss[q]), float(ss[q])]
        elif w_:
            run[1] = float(ss[q])
        elif run is not None:
            contacts.append({"kind": "wet_ground", "chainage": [round(run[0], 1), round(run[1], 1)], "status": "proposed"})
            run = None
    if run is not None:
        contacts.append({"kind": "wet_ground", "chainage": [round(run[0], 1), round(run[1], 1)], "status": "proposed"})
    contacts.sort(key=lambda c: (c["chainage"][0] if isinstance(c["chainage"], list) else c["chainage"], c["kind"]))
    # divide crossings (V64)
    dv = []
    gb = inp.grid.bounds()
    match = rules.p("routes.saddle_match_m")
    for rg in T.ridges:
        if rg["kind"] not in ("main", "spur"):
            continue
        inter = line.intersection(rg["line"])
        for p in [g for g in getattr(inter, "geoms", [inter]) if g.geom_type == "Point"]:
            best = None
            for sd_ in T.saddles:
                if sd_.get("ridge") != rg["n"]:
                    continue
                d = math.hypot(sd_["xz"][0] - p.x, sd_["xz"][1] - p.y)
                if d <= match and (best is None or d < best[0]):
                    best = (d, sd_)
            dv.append({"ridge": rg["id"], "ridge_kind": rg["kind"], "xz": [G.r2(p.x), G.r2(p.y)],
                       "chainage": round(float(line.project(p)), 1),
                       "saddle": best[1]["id"] if best else None,
                       "saddle_distance_m": round(best[0], 1) if best else None,
                       "at_window_edge": bool(min(p.x - gb[0], p.y - gb[1], gb[2] - p.x, gb[3] - p.y) < 3 * gc.cell)})
    # cliff traversal (window only)
    cliff_m = 0.0
    g = getattr(T, "ground", None)
    if g is not None:
        npt = max(2, int(L / A.win.cell))
        pp = shapely.get_coordinates(shapely.line_interpolate_point(line, np.linspace(0, L, npt)))
        ii = np.round((pp[:, 0] - A.win.x0) / A.win.cell).astype(int)
        jj = np.round((pp[:, 1] - A.win.z0) / A.win.cell).astype(int)
        ok = (ii >= 0) & (ii < A.win.nx) & (jj >= 0) & (jj < A.win.nz)
        cliff_m = float((g[jj[ok], ii[ok]] == GC["cliff"]).sum()) * L / npt
    # catchment at each end: first labelled cell walking inward (window-edge cells are fringe)
    ends = []
    for rev in (False, True):
        lab = None
        for q in (range(len(ss) - 1, -1, -1) if rev else range(len(ss))):
            l_ = catchment_at(T, xy[q, 0], xy[q, 1])
            if l_ in T.catch_ids:
                lab = T.catch_ids[l_]
                break
            if abs(ss[q] - (ss[-1] if rev else 0.0)) > 0.25 * L:
                break
        ends.append(lab)
    return {"long_profile": {"station_step_m": step, "chainage": [round(float(v), 1) for v in ss],
                             "y": [round(float(v), 2) for v in y],
                             "ascent_m": round(float(np.clip(dy, 0, None).sum()), 2),
                             "descent_m": round(float(-np.clip(dy, None, 0).sum()), 2),
                             "max_station_grade": round(float(np.max(np.abs(dy) / np.maximum(np.diff(ss), 1e-9))) if dy.size else 0.0, 4)},
            "sections": sections, "support_drainage": contacts, "divide_crossings": dv,
            "catchments_at_ends": ends, "cliff_traversal_m": round(cliff_m, 1)}
