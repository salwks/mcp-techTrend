"""Automatic `allowed` planning envelopes from region data (coordinator decision 2026-10-23).

No hand edits. `preferred` stays the existing allocation.
- 읍치/market (settlement_kind eupchi|market): preferred (wall interior / core) plus expansion
  into adjacent expandable land, grown ring by ring (2 m) until the usable area reaches the
  tier's minimum required area (all-compact civic bundle + forecourts + residential minimum,
  plus an overhead for corridors/water/fragments), capped at `envelope.eupchi_max_expand_m`.
- villages: land around the core within a walking cost W ∈ [150, 250] m, capped so that usable
  area does not exceed the program maximum (max households); W is reduced below 150 if even
  150 m exceeds the cap.
Expandable land excludes water, farmland (protected), road corridors and other places.
"""
from __future__ import annotations

import math

import numpy as np
import shapely
from scipy import ndimage
from shapely.geometry import Polygon

from . import geometry as G
from . import program as P
from . import raster as Rr
from . import routing as Rt
from .model import diag
from .rules import val


def _masks(inp, rules, sl, grid):
    h = inp.height[sl]
    hs = Rr.gaussian(h, rules.p("site.smooth_sigma_m"), grid.cell)
    slope, _, _ = Rr.slope_aspect(hs, grid.cell)
    water = inp.water_mask[sl]
    farm = inp.farmland[sl] if inp.farmland is not None else np.zeros(grid.shape, bool)
    m = rules.p("envelope.road_corridor_margin_m")
    roads = [r.line.buffer(r.width_m / 2 + m, cap_style="flat") for r in inp.roads]
    road = Rr.rasterize(grid, G.polygonal(shapely.union_all(roads))) if roads else np.zeros(grid.shape, bool)
    neigh = Rr.rasterize(grid, G.polygonal(shapely.union_all([n["geom"] for n in inp.neighbours]))) \
        if inp.neighbours else np.zeros(grid.shape, bool)
    cov = inp.coverage[sl]
    expandable = cov & ~water & ~farm & ~road & ~neigh
    # occupiable = same exclusions as Layer 0/1: connected flood envelope, drainage reserve, locks
    flood = _flood_ex(inp, rules, sl, h, water)
    dm = rules.p("drainage.corridor_margin_m")
    chans = [f.centerline.buffer(f.width_m / 2 + dm, cap_style="flat") for f in inp.water_features
             if f.centerline is not None and f.kind in ("river", "stream")]
    drain = Rr.rasterize(grid, G.polygonal(shapely.union_all(chans))) if chans else np.zeros(grid.shape, bool)
    locks = Rr.rasterize(grid, G.polygonal(shapely.union_all([l["geom"] for l in inp.locks]))) if inp.locks \
        else np.zeros(grid.shape, bool)
    usable = expandable & (slope <= rules.p("slope.housing_max_deg")) & ~flood & ~drain & ~locks
    return hs, expandable, usable


def _flood_ex(inp, rules, sl, h, water):
    """Connected exclusion envelope (same rule as site.analyze, computed on this window)."""
    surf = inp.water_surface[sl]
    exempt = inp.flood_exempt[sl] if inp.flood_exempt is not None else np.zeros(h.shape, bool)
    known = water & np.isfinite(surf) & ~exempt
    if not known.any():
        return np.zeros(h.shape, bool)
    dist_px, (jj, ii) = ndimage.distance_transform_edt(~known, return_indices=True)
    Wn = surf[jj, ii]
    unit = inp.vertical_scale if rules.p("flood.stage_units") == "source_m" else 1.0
    m = ((h <= Wn + rules.p("flood.exclusion_offset") * unit) & (dist_px * inp.grid.cell <= rules.p("flood.max_reach_m"))) \
        | (water & ~exempt)
    lab, _ = Rr.label(m)
    keep = np.unique(lab[water & ~exempt])
    keep = keep[keep > 0]
    return np.isin(lab, keep)


def required_area(profile, rules):
    insts = P.institutions(profile, rules)
    civ = 0.0
    for r in insts:
        if r["inside_wall"]:
            v = r["variants"]["compact"]
            civ += v["area_m2"] + v["entrance_clearance_m"] * v["width_m"] * 0.6
    a = P.parcel_areas(profile, rules)
    n = val(profile["residential_min_households"])
    cnt = P.largest_remainder(val(profile["class_shares"]), n, P.CLASS_ORDER)
    res = sum(cnt[c] * a[c] for c in P.CLASS_ORDER) / (1 - rules.p("program.f_lanes") - rules.p("program.f_open"))
    return (civ + res) * (1 + rules.p("envelope.overhead"))


def max_area(profile, rules):
    insts = P.institutions(profile, rules)
    civ = sum(r["variants"]["full"]["area_m2"] + r["variants"]["full"]["entrance_clearance_m"] * r["variants"]["full"]["width_m"] * 0.6
              for r in insts if r["inside_wall"])
    a = P.parcel_areas(profile, rules)
    n = val(profile["max_households"])
    cnt = P.largest_remainder(val(profile["class_shares"]), n, P.CLASS_ORDER)
    res = sum(cnt[c] * a[c] for c in P.CLASS_ORDER) / (1 - rules.p("program.f_lanes") - rules.p("program.f_open"))
    return (civ + res) * (1 + rules.p("envelope.overhead"))


def auto(inp, rules):
    """Set inp.territory['allowed'] to an automatic envelope; return a record."""
    pref = inp.territory["preferred"]
    profile = rules.profile(inp.tier)
    kind = profile["settlement_kind"]
    reach = max(rules.p("envelope.eupchi_max_expand_m"), max(rules.p("envelope.village_walk_m"))) + 60
    xmin, zmin, xmax, zmax = pref.bounds
    grid, sl = inp.grid.sub(xmin - reach, zmin - reach, xmax + reach, zmax + reach)
    hs, expandable, usable = _masks(inp, rules, sl, grid)
    pm = Rr.rasterize(grid, pref)
    cell_a = grid.cell ** 2
    rec = {"kind": kind}
    if kind in ("eupchi", "market", "fortress"):
        need = required_area(profile, rules)
        env = pm.copy()
        step = 0
        maxit = int(rules.p("envelope.eupchi_max_expand_m") / grid.cell)
        st = np.ones((3, 3), bool)
        have = float((env & usable).sum() * cell_a)
        while have < need and step < maxit:
            grow = ndimage.binary_dilation(env, structure=st) & expandable
            grow |= env
            if grow.sum() == env.sum():
                break
            env = grow
            step += 1
            have = float((env & usable).sum() * cell_a)
        rec.update({"rule": "eupchi_expansion", "required_usable_m2": round(need, 1), "usable_m2": round(have, 1),
                    "expanded_m": step * grid.cell, "reached_requirement": have >= need})
        if have < need:
            inp.diagnostics.append(diag("envelope_short", "warning", "L1",
                                        "adjacent expandable land ran out before the tier minimum area",
                                        required_m2=round(need, 1), usable_m2=round(have, 1)))
    else:
        cap = max_area(profile, rules)
        g = Rt.build_graph(grid, hs, expandable | pm, radius=1, grade_k=rules.p("routing.grade_cost_k"))
        d, _ = Rt.dijkstra(g, np.flatnonzero(pm))
        d = d.reshape(grid.shape)
        lo, hi = rules.p("envelope.village_walk_m")
        wmin = rules.p("envelope.village_walk_min_m")
        W, feasible = None, False
        w = float(hi)
        while w >= wmin - 1e-9:  # largest walk (5 m steps) whose usable area fits the cap
            if float(((((d <= w) & (expandable | pm)) | pm) & usable).sum()) * cell_a <= cap:
                W, feasible = w, True
                break
            w -= 5.0
        if W is None:
            W = float(wmin)
        env = ((d <= W) & (expandable | pm)) | pm
        if not feasible:
            inp.diagnostics.append(diag("envelope_cap_infeasible", "warning", "L1",
                                        "even the minimum walk (or the existing allocation alone) exceeds the program maximum",
                                        walk_m=W, cap_m2=round(cap, 1)))
        rec.update({"rule": "village_walk", "walk_m": W, "walk_in_range": lo <= W <= hi, "cap_feasible": feasible,
                    "cap_usable_m2": round(cap, 1), "max_households": val(profile["max_households"])})
    poly = Rr.mask_to_polygon(grid, env)
    poly = G.polygonal(shapely.union_all([poly, pref]))
    poly = G.largest(poly) if poly.geom_type == "MultiPolygon" else poly  # interior rings kept (excluded land)
    final = Rr.rasterize(grid, poly)
    rec["area_m2"] = round(poly.area, 1)
    rec["usable_m2"] = round(float((final & usable).sum() * cell_a), 1)  # measured on the final geometry
    inp.territory["allowed"] = poly
    inp.territory["sources"]["allowed"] = f"auto_envelope:{rec['rule']}"
    inp.territory["auto_envelope"] = rec
    inp.diagnostics.append(diag("auto_envelope", "info", "L1", f"allowed = automatic {rec['rule']} envelope", **rec))
    return rec


def impact(inp, base_plan, prop_plan):
    """Impact report for the proposed envelope (audit K2: a site change is a proposal with
    consequences, never a silent success)."""
    pref = inp.territory["preferred"]
    allowed = inp.territory["allowed"]
    added = G.polygonal(allowed.difference(pref))
    rec = dict(inp.territory.get("auto_envelope") or {})
    out = {"kind": "site_change:auto_envelope", "status": "proposed", "requires_owner_approval": True,
           "rule": rec.get("rule"), "envelope": rec,
           "added_area_m2": round(added.area, 1), "allowed_area_m2": round(allowed.area, 1),
           "preferred_area_m2": round(pref.area, 1)}
    lu = inp.meta.get("landuse")
    if lu is not None and not added.is_empty:
        m = Rr.rasterize(inp.grid, added)
        names = inp.meta.get("landuse_classes", {})
        cell_a = inp.grid.cell ** 2
        vals, cnt = np.unique(lu[m], return_counts=True)
        out["added_landuse_m2"] = {f"{int(v)}:{names.get(int(v), '?')}": round(float(c) * cell_a, 1)
                                   for v, c in zip(vals, cnt) if v != 255}
        if inp.farmland is not None:
            out["farmland_consumed_m2"] = round(float((m & inp.farmland).sum()) * cell_a, 1)
        out["water_consumed_m2"] = round(float((m & inp.water_mask).sum()) * cell_a, 1)
    near = []
    for n in inp.neighbours:
        dd = n["geom"].distance(added) if not added.is_empty else n["geom"].distance(pref)
        near.append((round(dd, 1), n["id"]))
    near.sort()
    out["nearest_neighbours"] = [{"id": i, "distance_m": d} for d, i in near[:5]]
    out["neighbours_within_50m"] = [i for d, i in near if d <= 50.0]
    out["routes_touched"] = sorted({r.id for r in inp.roads if not added.is_empty and r.line.intersects(added)})
    out["baseline"] = {"status": base_plan["status"], "households": base_plan["program"]["households"]["represented"]}
    out["proposed"] = {"status": prop_plan["status"], "households": prop_plan["program"]["households"]["represented"]}
    return out
