"""Layer 0 — site analysis (first-pass scope of spec §3/§6).

Computes smoothed slope/aspect, relative elevation (30/100/300 m), water distance,
connected flood screen (+1/+3/+5 source-m converted with the vertical scale),
drainage corridor reservations, buildability by use, route and water access cost
fields (8-neighbour least cost, edge cost l(1+8g^2)), and farmland relationship.
Deferred: flow accumulation, sun, viewsheds, automatic 진산/안산.
"""
from __future__ import annotations

import math

import numpy as np
from scipy import ndimage
from shapely.geometry import Point, Polygon
import shapely

from . import geometry as G
from . import raster as Rr
from . import routing as Rt
from .model import SiteInput, diag


class SiteAnalysis:
    pass


def _poly_union(geoms):
    gs = [g for g in geoms if g is not None and not g.is_empty]
    if not gs:
        return Polygon()
    return G.polygonal(shapely.union_all(gs, grid_size=G.GRID))


def analyze(inp: SiteInput, rules) -> SiteAnalysis:
    A = SiteAnalysis()
    A.inp = inp
    A.rules = rules
    A.diagnostics = list(inp.diagnostics)
    from .contract import region_profile
    A.region_profile = region_profile(inp, rules)
    full = inp.grid
    cell = full.cell
    terr = inp.territory
    preferred, allowed = terr["preferred"], terr["allowed"]

    # ---------------- full-grid fields (halo) ----------------
    h_raw = inp.height
    h_s = Rr.gaussian(h_raw, rules.p("site.smooth_sigma_m"), cell)
    cov = inp.coverage
    water = inp.water_mask & cov
    A.full_grid = full

    # nearest water surface W(x) and distance d
    exempt = inp.flood_exempt if inp.flood_exempt is not None else np.zeros(full.shape, bool)
    known = water & np.isfinite(inp.water_surface) & ~exempt
    if known.any():
        dist_px, (ij, ii) = ndimage.distance_transform_edt(~known, return_indices=True)
        Wn = inp.water_surface[ij, ii]
        wdist = dist_px * cell
    else:
        Wn = np.full(full.shape, np.nan)
        wdist = np.full(full.shape, np.inf)
        A.diagnostics.append(diag("no_mapped_water", "warning", "L0",
                                  "no water surface elevations in window; flood/water fields unknown"))
    unknown_w = water & ~np.isfinite(inp.water_surface)
    if unknown_w.any():
        A.diagnostics.append(diag("water_surface_missing", "warning", "L0",
                                  "water cells without surface elevation", cells=int(unknown_w.sum())))
    # inconsistency: terrain above the water surface on water cells
    tol = rules.p("water.surface_tolerance_m")
    if known.any():
        above = known & (h_raw - inp.water_surface > tol)
        below = known & (inp.water_surface - h_raw > 3 * tol)
        if above.any() or below.any():
            A.diagnostics.append(diag(
                "water_surface_inconsistent", "warning", "L0",
                "mapped water surface disagrees with terrain (terrain above surface or deeply incised)",
                cells_terrain_above=int(above.sum()), cells_incised=int(below.sum()),
                frac=round(float((above | below).sum() / max(1, known.sum())), 3)))

    vs = inp.vertical_scale
    floods = {}
    reach = rules.p("flood.max_reach_m")
    unit_scale = vs if rules.p("flood.stage_units") == "source_m" else 1.0
    A.flood_unit_scale = unit_scale
    for off in rules.p("flood.stage_offsets"):
        dg = off * unit_scale
        m = ((h_raw <= Wn + dg) & np.isfinite(Wn) & (wdist <= reach)) | (water & ~exempt)
        lab, n = Rr.label(m)
        keep = np.unique(lab[water & ~exempt])
        keep = keep[keep > 0]
        floods[off] = np.isin(lab, keep) & cov
    ex_off = rules.p("flood.exclusion_offset")
    A.stages = sorted(floods)
    A.stage_ex = ex_off
    states = rules.p("water.stage_states")
    A.stage_states = states
    A.stage_names = {st["offset"]: st["key"] for st in states}
    scr = sorted(st["offset"] for st in states if st.get("screen"))
    exs = [st["offset"] for st in states if st.get("exclusion")]
    if scr != A.stages or exs != [ex_off]:
        raise ValueError("flood.stage_offsets / exclusion_offset disagree with water.stage_states")
    A.stage_units = rules.p("flood.stage_units")
    flood_ex = floods[ex_off]
    Hsrc = (h_raw - Wn) / unit_scale
    Rh = rules.p("flood.R_height_m")
    R = np.exp(-wdist / rules.p("flood.R_bank_decay_m")) * np.clip(1 - Hsrc / Rh, 0, 1)
    R = np.where(np.isfinite(R), R, 0.0)
    R = np.maximum(flood_ex.astype(float), R)
    A.flood_exempt = exempt

    # drainage corridors: channel half-width + margin each side
    margin = rules.p("drainage.corridor_margin_m")
    channels = []
    for f in inp.water_features:
        if f.centerline is not None and f.kind in ("river", "stream"):
            channels.append({"id": f.id, "line": f.centerline, "width": float(f.width_m), "kind": f.kind,
                             "freshwater": f.freshwater})
    drain_geoms = [c["line"].buffer(c["width"] / 2 + margin, cap_style="flat") for c in channels]
    drain_poly = _poly_union(drain_geoms)

    # ---------------- work window ----------------
    wm = max(rules.p("site.planning_margin_m"), rules.p("routing.window_margin_m"))
    xmin, zmin, xmax, zmax = allowed.bounds
    win, sl = full.sub(xmin - wm, zmin - wm, xmax + wm, zmax + wm)
    A.win, A.sl = win, sl
    if (xmin - wm < full.bounds()[0] or zmin - wm < full.bounds()[1] or
            xmax + wm > full.bounds()[2] or zmax + wm > full.bounds()[3]):
        A.diagnostics.append(diag("window_clipped", "info", "L0", "work window clipped by data extent"))
    A.h_raw = h_raw[sl]
    A.h = h_s[sl]
    slope, aspect, _ = Rr.slope_aspect(h_s, cell)
    A.slope = slope[sl]
    A.aspect = aspect[sl]
    A.tpi = {}
    for r in rules.p("site.tpi_radii_m"):
        A.tpi[r] = (h_s - Rr.disk_mean(h_s, cov, r, cell))[sl]
    mn, mx = Rr.disk_minmax(h_s, rules.p("site.relief_radius_m"), cell)
    A.relief = (mx - mn)[sl]
    hw = A.h
    A.pct = (np.argsort(np.argsort(hw.ravel(), kind="stable"), kind="stable").reshape(hw.shape)
             / max(1, hw.size - 1))
    A.water = water[sl]
    A.fresh = (inp.water_fresh & water)[sl]
    A.wsurf = Wn[sl]
    A.wdist = wdist[sl]
    A.floods = {k: v[sl] for k, v in floods.items()}
    A.flood_ex = flood_ex[sl]
    A.R = R[sl]
    A.cov = cov[sl]
    A.channels = channels
    A.drain_poly = drain_poly
    A.drain = Rr.rasterize(win, drain_poly)
    A.farmland = (inp.farmland[sl] if inp.farmland is not None else np.zeros(win.shape, bool)) & ~A.water

    # ---------------- protection & locks ----------------
    farm_poly = Rr.mask_to_polygon(win, A.farmland)
    farm_out = G.polygonal(farm_poly.difference(preferred)) if not farm_poly.is_empty else Polygon()
    neigh = _poly_union([n["geom"] for n in inp.neighbours])
    prot_vec = terr.get("protected", Polygon())
    A.protected_poly = _poly_union([prot_vec, farm_out, neigh])
    A.neigh_poly = neigh
    A.farm_poly = farm_poly
    A.farm_displaced = G.polygonal(farm_poly.intersection(preferred)) if not farm_poly.is_empty else Polygon()
    A.lock_poly = _poly_union([l["geom"] for l in inp.locks if l.get("hard", True)])     # shape locks
    A.anchor_poly = _poly_union([l["geom"] for l in inp.locks if not l.get("hard", True)])  # point locks
    A.protected = Rr.rasterize(win, A.protected_poly)
    A.locks = Rr.rasterize(win, A.lock_poly)
    A.anchor_mask = Rr.rasterize(win, A.anchor_poly)
    A.water_poly = Rr.mask_to_polygon(win, A.water)

    # ---------------- buildability ----------------
    base_ex = A.water | A.flood_ex | A.drain | ~A.cov
    A.house_ok = (A.slope <= rules.p("slope.housing_max_deg")) & ~base_ex
    A.house_pref = A.house_ok & (A.slope <= rules.p("slope.housing_pref_deg"))
    A.civic_ok = (A.slope <= rules.p("slope.civic_max_deg")) & ~base_ex
    A.civic_pref = A.civic_ok & (A.slope <= rules.p("slope.civic_pref_deg"))
    occ_ex = A.protected | A.locks
    A.house_poly = Rr.mask_to_polygon(win, A.house_ok & ~occ_ex)
    # civic reserves must not cover a story spot either (point locks)
    A.civic_poly = Rr.mask_to_polygon(win, A.civic_ok & ~occ_ex & ~A.anchor_mask)
    A.flood_polys = {k: Rr.mask_to_polygon(win, v & ~A.water) for k, v in A.floods.items()}

    # ---------------- routing fields ----------------
    road_geoms = [r.line.buffer(max(1.0, r.width_m / 2 + 1.0), cap_style="flat") for r in inp.roads]
    A.road_poly = _poly_union(road_geoms)
    A.road_mask = Rr.rasterize(win, A.road_poly)
    on_water = A.road_mask & A.water
    A.existing_crossings = []
    A.bridge_mask = np.zeros(win.shape, bool)
    if on_water.any():
        lab, n = Rr.label(on_water)
        for k in range(1, n + 1):
            jj, ii = np.nonzero(lab == k)
            x, z = win.xz(float(ii.mean()), float(jj.mean()))
            match = None
            for c in inp.crossings:
                if math.hypot(c["xz"][0] - x, c["xz"][1] - z) < 60:
                    match = c
            A.existing_crossings.append({"xz": [G.r2(x), G.r2(z)], "cells": int(len(jj)),
                                         "type": match["type"] if match else "unmapped",
                                         "id": match["id"] if match else f"crossing-{k:02d}"})
            if match is None:
                A.diagnostics.append(diag("unmapped_route_crossing", "warning", "L0",
                                          "route crosses water without a mapped crossing record; treated as impassable",
                                          xz=[G.r2(x), G.r2(z)]))
            else:
                A.bridge_mask |= lab == k  # typed, mapped crossing footprint
    A.passable = A.cov & (~A.water | A.bridge_mask)
    k = rules.p("routing.grade_cost_k")
    A.graph8 = Rt.build_graph(win, A.h, A.passable, radius=1, grade_k=k)
    road_cells = np.flatnonzero(A.road_mask & A.passable)
    A.neigh_mask = Rr.rasterize(win, A.neigh_poly)
    A.route_cost, A.route_pred = Rt.dijkstra(A.graph8, road_cells)
    A.route_cost = A.route_cost.reshape(win.shape)
    bank = ndimage.binary_dilation(A.fresh, structure=np.ones((3, 3), bool)) & ~A.water & A.cov
    A.bank = bank
    A.water_cost, _ = Rt.dijkstra(A.graph8, np.flatnonzero(bank))
    A.water_cost = A.water_cost.reshape(win.shape)

    from .locks import site_conflicts
    A.diagnostics += site_conflicts(inp, A)
    # movement & livelihood layer (audit K9) — read by the frame for its approaches
    from . import livelihood
    A.full_h = h_s
    A.movement = livelihood.build(inp, A, rules)

    # ---------------- summary & probes ----------------
    pm = Rr.rasterize(win, preferred)
    A.pref_mask = pm
    cx, cz = preferred.centroid.x, preferred.centroid.y
    cell_a = cell * cell
    farm_near = {}
    for r in rules.p("agriculture.radii_m"):
        disk = Rr.rasterize(win, Point(cx, cz).buffer(r, 64))
        farm_near[str(r)] = round(float((disk & A.farmland).sum() * cell_a), 1)
    pa = max(1, int(pm.sum()))

    def frac(m):
        return round(float((m & pm).sum() / pa), 4)

    wc = A.water_cost[pm]
    rc = A.route_cost[pm]
    A.summary = {
        "preferred_area_m2": round(preferred.area, 1),
        "allowed_area_m2": round(allowed.area, 1),
        "slope_deg": {"median": round(float(np.median(A.slope[pm])), 2), "p90": round(float(np.percentile(A.slope[pm], 90)), 2)},
        "relief_m": round(float(A.h[pm].max() - A.h[pm].min()), 2),
        "tpi300_m": {"min": round(float(np.nanmin(A.tpi[300][pm])), 2), "max": round(float(np.nanmax(A.tpi[300][pm])), 2)},
        "frac_flood": {str(k): frac(v) for k, v in A.floods.items()},
        "frac_water": frac(A.water),
        "frac_drainage": frac(A.drain),
        "frac_housing_buildable": frac(A.house_ok & ~occ_ex),
        "frac_civic_buildable": frac(A.civic_ok & ~occ_ex),
        "water_access_cost_m": {"median": _fin(np.median(wc)) if wc.size else None, "min": _fin(wc.min()) if wc.size else None},
        "route_access_cost_m": {"median": _fin(np.median(rc)) if rc.size else None},
        "farmland_within_m2": farm_near,
        "farmland_displaced_m2": round(A.farm_displaced.area, 1),
        "vertical_scale": inp.vertical_scale,
        "existing_crossings": A.existing_crossings,
    }
    # site score S_T (informational; spec §2 weights, all terms in [0,1])
    w = rules.data["objectives"]["site_score"]
    lim = rules.p("water_access.limit_m")
    tgt = rules.p("water_access.target_m")
    Wterm = 0.0 if not wc.size or not np.isfinite(np.median(wc)) else float(np.clip((lim - np.median(wc)) / (lim - tgt), 0, 1))
    Aterm = 0.0 if not rc.size or not np.isfinite(np.median(rc)) else float(np.clip(1 - np.median(rc) / 600.0, 0, 1))
    terms = {"B": frac(A.house_ok & ~occ_ex), "F": 1 - frac(A.flood_ex), "W": round(Wterm, 4), "A": round(Aterm, 4),
             "K": round(min(1.0, farm_near[str(rules.p("agriculture.radii_m")[-1])] / 400000.0), 4),
             "P": 0.5 if not inp.axes else 0.75, "D": round(float(np.clip(np.nanmedian(A.tpi[100][pm]) / 20 + 0.5, 0, 1)), 4)}
    A.summary["site_score"] = {"terms": terms, "S": round(sum(w[k]["value"] * terms[k] for k in terms), 4),
                               "note": "P neutral/0.75 with supplied axes (진산/안산 detection deferred); D = TPI100 proxy"}
    return A


def _fin(v):
    v = float(v)
    return round(v, 1) if np.isfinite(v) else None


def auto_family(A: SiteAnalysis, rules) -> tuple[str, dict]:
    """Choose wall family from terrain statistics of the allocation (spec: confirm terrain)."""
    m = rules.mapping()["family_auto"]
    pm = A.pref_mask
    med_slope = float(np.median(A.slope[pm]))
    relief = float(A.h[pm].max() - A.h[pm].min())
    tpi300max = float(np.nanmax(A.tpi[300][ndimage.binary_dilation(pm, iterations=40)]))
    stats = {"median_slope_deg": round(med_slope, 2), "relief_m": round(relief, 2), "tpi300_max_m": round(tpi300max, 2)}
    if med_slope >= m["mountain_min_slope_deg"]["value"]:
        return "mountain", stats
    if relief <= m["plain_max_relief_m"]["value"] and tpi300max < m["hill_min_tpi300_m"]["value"]:
        return "plain", stats
    if relief <= m["plain_max_relief_m"]["value"]:
        return "plain", stats
    return "plain_hill", stats
