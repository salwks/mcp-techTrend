"""Layer 2 — settlement frame (spec 2회차 §3).

enumerate candidate boundaries per family → place civic envelopes (site every 10 m,
bearing every 15° + supplied axes, beam search) → gates from route-approach clusters
→ typed water passages → primary corridors (8-neighbour, ≤10 % grade per edge,
7.2 m reservation) → water-supply reservation → capacity re-solve (Layer 1) →
hard validation → rank, keep 8 alternatives.
"""
from __future__ import annotations

import itertools
import math

import numpy as np
import shapely
from scipy import ndimage
from shapely.geometry import LineString, MultiPolygon, Point, Polygon, box

from . import geometry as G
from . import program as P
from . import raster as Rr
from . import routing as Rt
from .model import diag
from .rules import val


# ====================================================================== context
class Ctx:
    def __init__(self, A, L1, rules, family):
        self.A, self.L1, self.rules, self.family = A, L1, rules, family
        self.inp = A.inp
        t = A.inp.territory
        self.allowed = G.polygonal(shapely.set_precision(t["allowed"], G.GRID))
        self.preferred = G.polygonal(shapely.set_precision(t["preferred"], G.GRID))
        # protection forbids occupation, not enclosure: boundaries may take in protected farmland
        # (no reserves or capacity there), but never another settlement's allocation
        self.region = G.polygonal(self.allowed.difference(A.neigh_poly, grid_size=G.GRID)) \
            if not A.neigh_poly.is_empty else self.allowed
        # locks are not subtracted: a frame may enclose story spots; the wall may not cross them
        self.profile = L1["profile"]
        self.insts = L1["insts"]
        from .livelihood import frame_roads
        self.roads = frame_roads(A.inp, A)   # approaches come from the movement layer (K9)
        self.bundles = L1["bundles"]
        self.axes = list(A.inp.axes)
        self.walled = family != "unwalled"
        ap = rules.p("routing.mountain.applies_to")
        self.road_class = "mountain" if (family in ap["families"] or L1["program"]["profile"] in ap["profiles"]) else "primary"
        if self.road_class == "mountain":
            self.rc = {"radius": rules.p("routing.mountain.radius_cells"), "cap": rules.p("routing.mountain.edge_grade"),
                       "sub_cap": rules.p("routing.mountain.local_max_grade"), "limit": rules.p("routing.mountain.max_grade"),
                       "measure": "sustained_smoothed_centreline"}
            corr_w = rules.p("routing.mountain.width_m")
        else:
            self.rc = {"radius": 1, "cap": rules.p("routing.primary_max_grade"), "sub_cap": None,
                       "limit": rules.p("routing.primary_max_grade"), "measure": "per_segment"}
            corr_w = rules.p("routing.corridor_width_m")
        self.corr_width = corr_w
        self.corr_half = corr_w / 2
        self.corr_cells = int(math.ceil(self.corr_half / A.win.cell))
        # small channels (culvert-crossable) vs rivers needing bridges
        thr = rules.p("water_passage.sluice_min_width_m")
        small = [c["line"].buffer(c["width"] / 2 + 0.5, cap_style="flat") for c in A.channels if c["width"] < thr]
        self.small_channel = (Rr.rasterize(A.win, G.polygonal(shapely.union_all(small))) & A.water) if small \
            else np.zeros(A.win.shape, bool)


def access_graph(ctx, grid, h, pas):
    """Road graph of the frame's access class (primary ≤10 % per segment, or mountain)."""
    rc = ctx.rc
    return Rt.build_graph(grid, h, pas, radius=rc["radius"], grade_k=ctx.rules.p("routing.grade_cost_k"),
                          grade_cap=rc["cap"], sub_cap=rc["sub_cap"])


def measure_grade(ctx, grid, h, pts):
    """(grade used for the limit, detail dict)."""
    if ctx.rc["measure"] == "per_segment":
        _, _, gm = Rt.grade_profile(grid, h, pts)
        return gm, {"measure": "per_segment"}
    R = ctx.rules
    sus, loc, _, _, _ = Rt.sustained_grade(grid, h, pts, R.p("routing.mountain.window_m"), R.p("routing.mountain.smooth_m"))
    return sus, {"measure": "sustained_smoothed_centreline", "local_max": round(loc, 4),
                 "switchbacks": Rt.count_switchbacks(pts, R.p("routing.mountain.switchback_turn_deg"))}


class Sub:
    """A sub-window of the analysis window, for per-candidate graphs."""

    def __init__(self, A, bounds, margin):
        xmin, zmin, xmax, zmax = bounds
        g, sl = A.win.sub(xmin - margin, zmin - margin, xmax + margin, zmax + margin)
        self.grid, self.sl = g, sl

    def a(self, arr):
        return arr[self.sl]

    def cell_of(self, x, z):
        i, j = self.grid.ij(x, z)
        i = min(max(i, 0), self.grid.nx - 1)
        j = min(max(j, 0), self.grid.nz - 1)
        return j * self.grid.nx + i

    def xz(self, c):
        return self.grid.xz(c % self.grid.nx, c // self.grid.nx)


def nearest_true(mask, grid, x, z, max_m):
    """Flat index of the nearest True cell within max_m of (x,z), or None."""
    i, j = grid.ij(x, z)
    r = int(math.ceil(max_m / grid.cell))
    j0, j1 = max(0, j - r), min(grid.nz, j + r + 1)
    i0, i1 = max(0, i - r), min(grid.nx, i + r + 1)
    sub = mask[j0:j1, i0:i1]
    if not sub.any():
        return None
    jj, ii = np.nonzero(sub)
    jj = jj + j0
    ii = ii + i0
    d = (ii - i) ** 2 + (jj - j) ** 2
    k = np.lexsort((ii, jj, d))[0]
    if d[k] * grid.cell ** 2 > max_m ** 2:
        return None
    return int(jj[k] * grid.nx + ii[k])


# ====================================================================== generators
def gen_plain(ctx: Ctx) -> list[dict]:
    A, R = ctx.A, ctx.rules
    region = ctx.region
    if region.is_empty:
        return []
    usable = G.polygonal(region.intersection(A.house_poly, grid_size=G.GRID))
    base = usable if not usable.is_empty else region
    c = base.centroid
    lat = R.p("frame.plain.center_lattice_m")
    centers = [(c.x + dx * lat, c.y + dz * lat) for dz in (-1, 0, 1) for dx in (-1, 0, 1)]
    step_b = R.p("frame.plain.bearing_step_deg")
    bearings = sorted({round(b, 3) for b in np.arange(0, 180, step_b)} |
                      {round(a["bearing"] % 180, 3) for a in ctx.axes})
    step = R.p("frame.plain.size_step_m")
    xmin, zmin, xmax, zmax = region.bounds
    ext = math.hypot(xmax - xmin, zmax - zmin)
    amin, amax = R.p("frame.plain.aspect_min"), R.p("frame.plain.aspect_max")
    sizes = []
    w = 6 * step
    while w <= ext:
        d = w * amin
        while d <= w * amax + 1e-9:
            sizes.append((w, round(d / step) * step))
            d += step
        w += step
    sizes = sorted(set(sizes))
    chf = R.p("frame.plain.chamfer_frac")
    cands = []
    for (cx, cz) in centers:
        for b in bearings:
            for (w, d) in sizes:
                for ch in (0.0, chf):
                    cands.append((cx, cz, w, d, b, ch))
    if not cands:
        return []
    polys = [G.oriented_rect(cx, cz, w, d, b, chamfer=ch * min(w, d)) for (cx, cz, w, d, b, ch) in cands]
    arr = np.array(polys, dtype=object)
    shapely.prepare(region)
    inside = shapely.contains(region, arr)
    idx = np.nonzero(inside)[0]
    if idx.size == 0:
        return []
    ua = shapely.area(shapely.intersection(arr[idx], usable)) if not usable.is_empty else np.zeros(idx.size)
    order = sorted(range(idx.size), key=lambda k: (-round(float(ua[k]), 1), round(polys[idx[k]].length, 1),
                                                   cands[idx[k]]))
    top = R.p("frame.plain.prefilter_top")
    picked = []
    for k in order:
        p = polys[idx[k]]
        if any(G.iou(p, q["poly"]) > R.p("frame.dedupe_iou") for q in picked):
            continue
        cx, cz, w, d, b, ch = cands[idx[k]]
        picked.append({"poly": p, "params": {"center": [G.r2(cx), G.r2(cz)], "width": w, "depth": d,
                                             "bearing": b, "chamfered": ch > 0}})
        if len(picked) >= top:
            break
    out = []
    for c in picked:
        q, moves = vertex_optimize(ctx, c["poly"], region, usable)
        c["params"]["vertex_moves"] = moves
        out.append({"family": "plain", "poly": q, "params": c["params"], "seed_poly": c["poly"]})
    return out


def _vo_objective(p, usable, flood, lam=2.0, mu=0.5):
    return p.intersection(usable).area - lam * p.length - mu * (p.intersection(flood).area if not flood.is_empty else 0)


def vertex_optimize(ctx, poly, region, usable):
    """Fixed-order 2 m vertex moves that improve the objective while staying valid."""
    R = ctx.rules
    stepm = R.p("frame.plain.vertex_step_m")
    flood = ctx.A.flood_polys[R.p("flood.exclusion_offset")]
    pts = [list(c) for c in list(poly.exterior.coords)[:-1]]
    lam, mu = R.p("frame.vertex_perimeter_weight"), R.p("frame.vertex_flood_weight")
    best = _vo_objective(poly, usable, flood, lam, mu)
    dirs = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    moves = 0
    shapely.prepare(region)
    for _ in range(R.p("frame.plain.vertex_passes")):
        improved = False
        for i in range(len(pts)):
            cand_best = None
            for dx, dz in dirs:
                n = math.hypot(dx, dz)
                q = [p[:] for p in pts]
                q[i] = [pts[i][0] + stepm * dx / n, pts[i][1] + stepm * dz / n]
                pg = Polygon(q)
                if not pg.is_valid or not region.contains(pg):
                    continue
                f = _vo_objective(pg, usable, flood, lam, mu)
                if f > best + 1e-6 and (cand_best is None or f > cand_best[0] + 1e-9):
                    cand_best = (f, q)
            if cand_best:
                best, pts = cand_best[0], cand_best[1]
                moves += 1
                improved = True
        if not improved:
            break
    return Polygon(pts), moves


def _chaikin(coords, it=2):
    pts = list(coords)[:-1]
    for _ in range(it):
        out = []
        n = len(pts)
        for i in range(n):
            a, b = pts[i], pts[(i + 1) % n]
            out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
            out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
        pts = out
    return pts + [pts[0]]


def _smooth(p, r, tol):
    """Open/close by r, fill holes, simplify, then Chaikin corner cutting so contour-derived
    rings (평산성 rear arcs, 산성 ridges) are tangent-continuous instead of notched."""
    q = p.buffer(r, join_style="round").buffer(-2 * r, join_style="round").buffer(r, join_style="round")
    q = G.polygonal(q)
    q = G.largest(q)
    if q.is_empty:
        return q
    q = Polygon(q.exterior.coords)  # fill holes
    q = G.simplify_ring_polygon(q, tol)
    c = Polygon(_chaikin(q.exterior.coords))
    if c.is_valid and not c.is_empty:
        q = G.simplify_ring_polygon(c, 0.5)
    return q


def _seed(ctx):
    A = ctx.A
    civ = G.polygonal(ctx.region.intersection(A.civic_poly, grid_size=G.GRID))
    if civ.is_empty:
        civ = ctx.region
    big = G.largest(civ)
    p = big.representative_point() if not big.contains(big.centroid) else big.centroid
    return p.x, p.y


def _rear_bearing(ctx, sx, sz):
    if ctx.axes:
        return (ctx.axes[0]["bearing"] + 180.0) % 360.0, "supplied_axis"
    A = ctx.A
    hs = float(Rr.bilinear(A.win, A.h, sx, sz)[0])
    X, Z = np.meshgrid(A.win.xs(), A.win.zs())
    m = (A.h > hs + 10) & ((X - sx) ** 2 + (Z - sz) ** 2 < 400 ** 2)
    if not m.any():
        return 0.0, "default_north"
    return G.bearing_of(float(X[m].mean() - sx), float(Z[m].mean() - sz)), "uphill_mass"


def _wedge(x, z, bearing, half, r=2000):
    pts = [(x, z)]
    for k in range(-8, 9):
        b = bearing + half * k / 8
        dx, dz = G.bearing_vec(b)
        pts.append((x + r * dx, z + r * dz))
    return Polygon(pts)


def gen_plain_hill(ctx: Ctx) -> list[dict]:
    A, R = ctx.A, ctx.rules
    sx, sz = _seed(ctx)
    rear, rear_src = _rear_bearing(ctx, sx, sz)
    hs = float(Rr.bilinear(A.win, A.h, sx, sz)[0])
    step = R.p("frame.level_step_m")
    n = R.p("frame.level_count")
    wedge = Rr.rasterize(A.win, _wedge(sx, sz, rear, R.p("frame.rear_sector_half_deg")))
    regm = Rr.rasterize(A.win, ctx.region)
    si, sj = A.win.ij(sx, sz)
    out = []
    seen = []
    for a in range(1, n + 1):
        hl = hs + a * step
        for b in (2, 4, 6, 8):
            hh = hl + b * step
            m = ((A.h <= hl) | ((A.h <= hh) & wedge)) & regm
            lab, _ = Rr.label(m)
            k = lab[sj, si]
            if k == 0:
                continue
            comp = ndimage.binary_fill_holes(lab == k)
            if any((comp & s).sum() / max(1, (comp | s).sum()) > R.p("frame.dedupe_iou") for s in seen):
                continue
            seen.append(comp)
            poly = Rr.mask_to_polygon(A.win, comp)
            poly = _smooth(poly, R.p("frame.smooth_m"), R.p("frame.simplify_m"))
            poly = G.largest(G.polygonal(poly.intersection(ctx.region, grid_size=G.GRID)))
            if poly.is_empty or not poly.contains(Point(sx, sz)):
                continue
            # 평산성 must actually take in the rear hill: enclosed rear ground rises ≥ min_rear_rise
            inside = Rr.rasterize(A.win, poly) & wedge
            rise = float(A.h[inside].max() - hs) if inside.any() else 0.0
            if rise < R.p("frame.plain_hill.min_rear_rise_m"):
                continue
            out.append({"family": "plain_hill", "poly": Polygon(poly.exterior.coords),
                        "params": {"seed": [G.r2(sx), G.r2(sz)], "h_low": round(hl, 2), "h_high": round(hh, 2),
                                   "rear_bearing": round(rear, 1), "rear_source": rear_src,
                                   "rear_rise_m": round(rise, 2)}})
    return out


def gen_mountain(ctx: Ctx) -> list[dict]:
    A, R = ctx.A, ctx.rules
    regm = Rr.rasterize(A.win, ctx.region)
    if not regm.any():
        return []
    step = R.p("frame.level_step_m")
    hmin, hmax = float(A.h[regm].min()), float(A.h[regm].max())
    civ_cells = A.civic_ok & ~A.protected & ~A.locks
    insts = [r for r in ctx.insts if r["inside_wall"]]
    min_civ = max((r["variants"]["compact"]["area_m2"] for r in insts), default=0.0)
    cell_a = A.win.cell ** 2
    out, seen = [], []
    lev = hmin + step
    while lev < hmax:
        m = (A.h >= lev) & regm
        lab, nlab = Rr.label(m)
        for k in range(1, nlab + 1):
            comp = lab == k
            filled = ndimage.binary_fill_holes(comp)
            holes = filled & ~comp
            if filled.sum() * cell_a < R.p("frame.unwalled.min_cluster_m2"):
                continue
            if (filled & civ_cells).sum() * cell_a < min_civ:
                continue
            water_in = (filled & (A.fresh | A.bank)).any()
            if not water_in:
                continue
            if any((filled & s).sum() / max(1, (filled | s).sum()) > R.p("frame.dedupe_iou") for s in seen):
                continue
            seen.append(filled)
            poly = Rr.mask_to_polygon(A.win, filled)
            poly = _smooth(poly, R.p("frame.smooth_m"), R.p("frame.simplify_m"))
            poly = G.largest(G.polygonal(poly.intersection(ctx.region, grid_size=G.GRID)))
            if poly.is_empty:
                continue
            out.append({"family": "mountain", "poly": Polygon(poly.exterior.coords),
                        "params": {"level": round(lev, 2), "kind": "ridge_cycle" if holes.any() else "hilltop",
                                   "component_cells": int(comp.sum())}})
        lev += step
    # larger, more enclosing rings first (bounded search)
    out.sort(key=lambda c: (-round(c["poly"].area, 0), c["params"]["level"]))
    return out


def gen_unwalled(ctx: Ctx) -> list[dict]:
    A, R = ctx.A, ctx.rules
    regm = Rr.rasterize(A.win, ctx.region)
    base = A.house_ok & regm & ~A.protected & ~A.locks
    rc = A.route_cost
    fallback = not np.isfinite(rc[regm]).any()
    if fallback:
        c = ctx.region.centroid
        g8 = A.graph8
        d, _ = Rt.dijkstra(g8, [A.win.ij(c.x, c.y)[1] * A.win.nx + A.win.ij(c.x, c.y)[0]])
        rc = d.reshape(A.win.shape)
    out = []
    seen = []
    for g in list(R.p("frame.unwalled.growth_m")) + [None]:
        m = base & (rc <= g) if g is not None else base.copy()
        lab, n = Rr.label(m)
        keep = np.zeros_like(m)
        clusters = 0
        for k in range(1, n + 1):
            comp = lab == k
            if comp.sum() * A.win.cell ** 2 >= R.p("frame.unwalled.min_cluster_m2"):
                keep |= comp
                clusters += 1
        if not keep.any():
            continue
        if any((keep & s).sum() / max(1, (keep | s).sum()) > R.p("frame.dedupe_iou") for s in seen):
            continue
        seen.append(keep)
        poly = Rr.mask_to_polygon(A.win, keep)
        poly = G.polygonal(poly.intersection(ctx.region))
        poly = G.polygonal(shapely.union_all([q for q in G.parts(poly)
                                              if q.area >= R.p("frame.unwalled.min_cluster_m2")]))
        if poly.is_empty:
            continue
        out.append({"family": "unwalled", "poly": poly,
                    "params": {"growth_cost_m": g, "clusters": clusters, "seed": "route_field" if not fallback else "centroid_fallback"}})
    return out


GENERATORS = {"plain": gen_plain, "plain_hill": gen_plain_hill, "mountain": gen_mountain, "unwalled": gen_unwalled}


# ====================================================================== civic placement
def _rect_coords(X, Z, w, d, b, off=0.0, wfrac=1.0, dlen=None):
    """Vectorized oriented rectangles (n,5,2); centre shifted `off` along the bearing."""
    fx, fz = G.bearing_vec(b)
    rx, rz = -fz, fx
    hw = w * wfrac / 2
    hd = (d if dlen is None else dlen) / 2
    cx = X + fx * off
    cz = Z + fz * off
    loc = [(-hw, hd), (hw, hd), (hw, -hd), (-hw, -hd), (-hw, hd)]
    out = np.empty((X.size, 5, 2))
    for k, (u, v) in enumerate(loc):
        out[:, k, 0] = cx + u * rx + v * fx
        out[:, k, 1] = cz + u * rz + v * fz
    return out


def civic_place(ctx: Ctx, frame_poly, bundle, approach_pts, comp=None):
    """Beam search over institutions (largest first) on a 10 m lattice × 15° bearings."""
    A, R = ctx.A, ctx.rules
    inner = frame_poly.buffer(-R.p("frame.wall_inner_reserve_m")) if ctx.walled else frame_poly
    region = G.polygonal(G.polygonal(inner).intersection(ctx.A.civic_poly, grid_size=G.GRID))
    walk = G.polygonal(G.polygonal(inner).difference(A.water_poly, grid_size=G.GRID))
    if region.is_empty:
        return None, {"failed": "no_civic_land"}
    step = R.p("civic.site_step_m")
    xmin, zmin, xmax, zmax = region.bounds
    xs = np.arange(math.floor(xmin / step) * step, xmax + step, step)
    zs = np.arange(math.floor(zmin / step) * step, zmax + step, step)
    X, Z = np.meshgrid(xs, zs)
    X, Z = X.ravel(), Z.ravel()
    shapely.prepare(region)
    ins = shapely.contains_xy(region, X, Z)
    X, Z = X[ins], Z[ins]
    lim = R.p("civic.site_limit")
    if X.size > lim:
        sel = np.linspace(0, X.size - 1, lim).round().astype(int)
        X, Z = X[sel], Z[sel]
    if X.size == 0:
        return None, {"failed": "no_civic_sites"}
    bstep = R.p("civic.bearing_step_deg")
    bearings = sorted({float(b) for b in np.arange(0, 360, bstep)} | {float(a["bearing"]) % 360 for a in ctx.axes})
    shapely.prepare(walk)
    spacing = R.p("civic.spacing_m")
    maxrel = R.p("civic.max_relief_m")
    keys = list(bundle["variants"])
    recs = {r["key"]: r for r in ctx.insts}
    order = sorted(keys, key=lambda k: (k == "market", -recs[k]["variants"][bundle["variants"][k]]["area_m2"], k))
    axis_b = ctx.axes[0]["bearing"] if ctx.axes else None
    apx = np.array(approach_pts) if approach_pts else None
    u = np.linspace(-0.45, 0.45, 5)
    UU, VV = [a for a in u for c in u], [c for a in u for c in u]
    beam = [{"placed": [], "score": 0.0}]
    for key in order:
        env = recs[key]["variants"][bundle["variants"][key]]
        w, d, clr = env["width_m"], env["depth_m"], env["entrance_clearance_m"]
        rows = []  # (score, x, z, b, relief, label, rect, strip)
        for b in bearings:
            rc = _rect_coords(X, Z, w, d, b)
            rects = shapely.polygons(rc)
            ok = shapely.contains(region, rects)
            if not ok.any():
                continue
            sc = _rect_coords(X, Z, w, d, b, off=d / 2 + clr / 2, wfrac=0.6, dlen=clr)
            strips = shapely.polygons(sc)
            ok &= shapely.contains(walk, strips)
            if not ok.any():
                continue
            xs_, zs_ = X[ok], Z[ok]
            rk_, sk_ = rects[ok], strips[ok]
            fx, fz = G.bearing_vec(b)
            if comp is not None:
                lab, sgrid, good = comp[:3]
                sx_ = xs_ + fx * (d / 2 + clr / 2)
                sz_ = zs_ + fz * (d / 2 + clr / 2)
                ii = np.clip(np.round((sx_ - sgrid.x0) / sgrid.cell).astype(int), 0, sgrid.nx - 1)
                jj = np.clip(np.round((sz_ - sgrid.z0) / sgrid.cell).astype(int), 0, sgrid.nz - 1)
                labs_all = lab[jj, ii]
                okc = np.isin(labs_all, good)
                xs_, zs_ = xs_[okc], zs_[okc]
                rk_, sk_ = rk_[okc], sk_[okc]
                labs_ = labs_all[okc]
                if xs_.size == 0:
                    continue
            rx, rz = -fz, fx
            px = xs_[:, None] + np.array(UU)[None, :] * w * rx + np.array(VV)[None, :] * d * fx
            pz = zs_[:, None] + np.array(UU)[None, :] * w * rz + np.array(VV)[None, :] * d * fz
            hs = Rr.bilinear(A.win, A.h, px.ravel(), pz.ravel()).reshape(px.shape)
            ss = Rr.bilinear(A.win, A.slope, px.ravel(), pz.ravel()).reshape(px.shape)
            relief = hs.max(axis=1) - hs.min(axis=1)
            s_rel = np.where(relief <= maxrel, 1.0, np.clip(1.0 - (relief - maxrel) / 8.0, 0, 1))
            s_pref = (ss <= R.p("slope.civic_pref_deg")).mean(axis=1)
            s_axis = 0.5 if axis_b is None else max(0.0, 1 - G.angle_diff(b, axis_b) / 90.0)
            hb = Rr.bilinear(A.win, A.h, xs_ - fx * (d / 2 + 25), zs_ - fz * (d / 2 + 25))
            s_rear = np.clip((hb - hs.mean(axis=1)) / 5.0 + 0.5, 0, 1)
            if apx is not None:
                dd = np.min(np.hypot(apx[None, :, 0] - xs_[:, None], apx[None, :, 1] - zs_[:, None]), axis=1)
                s_acc = np.clip(1 - dd / 600.0, 0, 1)
            else:
                s_acc = np.full(xs_.shape, 0.5)
            if key == "market":
                s = 0.6 * s_acc + 0.2 * s_rel + 0.2 * s_pref
            elif key in ("gaeksa", "community"):
                tp = Rr.bilinear(A.win, A.tpi[100], xs_, zs_)
                s_prom = np.clip(tp / 10 + 0.5, 0, 1)
                s = 0.25 * s_rel + 0.15 * s_pref + 0.2 * s_axis + 0.15 * s_rear + 0.1 * s_prom + 0.15 * s_acc
            else:
                s = 0.3 * s_rel + 0.2 * s_pref + 0.2 * s_axis + 0.15 * s_rear + 0.15 * s_acc
            if comp is None:
                labs_ = np.full(xs_.size, -1)
            for k in range(xs_.size):
                rows.append((round(float(s[k]), 6), float(xs_[k]), float(zs_[k]), b, float(relief[k]), int(labs_[k]),
                             rk_[k], sk_[k]))
        if not rows:
            return None, {"failed": f"no_fit:{key}:{bundle['variants'][key]}"}
        rows.sort(key=lambda t: (-t[0], t[1], t[2], t[3]))
        RR = np.array([r[6] for r in rows], dtype=object)
        RS = np.array([r[7] for r in rows], dtype=object)
        RL = np.array([r[5] for r in rows])
        nb = []
        per_state = R.p("civic.per_state")
        sep = R.p("civic.diversity_m")
        for st in beam:
            if st["placed"]:
                occ_r = shapely.union_all([p["rect"].buffer(spacing) for p in st["placed"]] +
                                          [p["strip"].buffer(spacing) for p in st["placed"]])
                occ_s = shapely.union_all([p["rect"].buffer(spacing) for p in st["placed"]] + [p["strip"] for p in st["placed"]])
                shapely.prepare(occ_r)
                shapely.prepare(occ_s)
                free = ~(shapely.intersects(occ_r, RR) | shapely.intersects(occ_s, RS)) & (RL == st["placed"][0]["label"])
            else:
                free = np.ones(len(rows), bool)
            taken = 0
            took = []
            check = comp[3] if (st["placed"] and comp is not None and len(comp) > 3) else None
            for ri in np.nonzero(free)[0]:
                (s, x, z, b, relief, lb, rect, strip) = rows[ri]
                if any(math.hypot(x - tx, z - tz) < sep for tx, tz in took):
                    continue
                if check is not None:
                    cand = {"key": key, "xz": (x, z), "bearing": b, "rect": rect, "strip": strip, "env": env}
                    if not check(st["placed"] + [cand]):
                        continue  # some entrance (incl. this one) no longer reachable by the access class
                rel = 0.0
                if st["placed"]:
                    anchor = st["placed"][0]
                    dd = math.hypot(anchor["xz"][0] - x, anchor["xz"][1] - z)
                    if key == "dongheon":
                        rel = 1.0 if 40 <= dd <= 160 else max(0.0, 1 - abs(dd - 100) / 200)
                    elif key != "market":
                        rel = max(0.0, 1 - dd / 250)
                    else:
                        rel = 0.5
                nb.append({"placed": st["placed"] + [{"key": key, "variant": bundle["variants"][key],
                                                       "xz": (x, z), "bearing": b, "rect": rect, "strip": strip,
                                                       "relief": relief, "score": s, "env": env, "label": lb}],
                           "score": st["score"] + s + 0.3 * rel})
                taken += 1
                took.append((x, z))
                if taken >= per_state:
                    break
        if not nb:
            return None, {"failed": f"no_room:{key}:{bundle['variants'][key]}"}
        nb.sort(key=lambda st: (-round(st["score"], 6),
                                [(p["xz"][0], p["xz"][1], p["bearing"]) for p in st["placed"]]))
        beam = nb[:R.p("civic.beam_width")]
    return [st["placed"] for st in beam], {"failed": None, "sites": int(X.size), "bearings": len(bearings)}



# ====================================================================== gates & corridors
def corridor_passable(ctx, sub, interior, civic, forecourts=None):
    """Centre-line cells whose full 7.2 m reservation stays clear of water, protection,
    locks and civic envelopes (all dilated by the corridor half-width)."""
    A = ctx.A
    st = np.ones((3, 3), bool)
    k = ctx.corr_cells
    ero = ndimage.binary_erosion(interior, structure=st, iterations=k)
    water_block = sub.a(A.water) & ~sub.a(ctx.small_channel)
    hard = water_block | sub.a(A.protected) | sub.a(A.locks)
    hard = ndimage.binary_dilation(hard, structure=st, iterations=k) if hard.any() else hard
    small_ok = ndimage.binary_dilation(sub.a(ctx.small_channel), structure=st, iterations=k) & ~ndimage.binary_dilation(
        water_block & ~sub.a(ctx.small_channel), structure=st, iterations=k) if sub.a(ctx.small_channel).any() else None
    if small_ok is not None:
        hard &= ~(small_ok & ~sub.a(A.protected) & ~sub.a(A.locks))
    obst = ndimage.binary_dilation(civic, structure=st, iterations=k) if civic.any() else civic
    if forecourts is not None:
        obst &= ~forecourts
    return ero & sub.a(A.cov) & ~hard & ~obst


def tree_network(sub, pred, gate_cells, socket_cells):
    """Corridor tree from shortest-path predecessors → nodes + links (explicit junctions)."""
    paths = {}
    child_count = {}
    for gid, c in gate_cells.items():
        p = Rt.path_cells(pred, c)
        paths[gid] = p
        for a, b in zip(p, p[1:]):
            child_count.setdefault(a, set()).add(b)
    used = set()
    for p in paths.values():
        used.update(p)
    junction = {c for c, ch in child_count.items() if len(ch) >= 2}
    return paths, junction


def solve_gates(ctx, sub, frame_poly, ring, interior, inner_cost, inner_pred, passages):
    """Route approaches → clusters → gate chainages (enumerated assignments)."""
    A, R = ctx.A, ctx.rules
    L = ring.length
    stepm = R.p("gates.sample_step_m")
    ns = max(8, int(L // stepm))
    ss = [L * k / ns for k in range(ns)]
    pts = [ring.interpolate(s) for s in ss]
    gw = R.p("gates.width_m")
    # outside graph: connectors run outside the wall
    outside_pass = sub.a(A.passable) & ~ndimage.binary_erosion(interior, iterations=1)
    # new approach connectors are roads too: same 8-neighbour ≤10 % rule as primary corridors
    gout = access_graph(ctx, sub.grid, sub.a(A.h), outside_pass)
    # inner cost at sample: min over nearby passable inner cells
    inner_c = []
    inner_cell = []
    ic = inner_cost.reshape(sub.grid.shape)
    fin = np.isfinite(ic)
    hsub = sub.a(A.h)
    gmax = ctx.rc["cap"]
    for p in pts:
        c = nearest_true(fin, sub.grid, p.x, p.y, ctx.corr_half + 6.0)
        if c is not None:
            cx, cz = sub.xz(c)
            dd = math.hypot(cx - p.x, cz - p.y)
            hp = float(Rr.bilinear(sub.grid, hsub, p.x, p.y)[0])
            if dd > 1e-6 and abs(hp - float(hsub.ravel()[c])) / dd > gmax:
                c = None  # gate stub (wall line → first corridor cell) would exceed the grade limit
        inner_cell.append(c)
        inner_c.append(float(inner_cost[c]) if c is not None else math.inf)
    blocked = []
    for k, s in enumerate(ss):
        bad = any(G.interval_overlap((s - gw / 2, s + gw / 2), iv, L) > 0 for iv in passages)
        blocked.append(bad)
    # approaches
    cen = frame_poly.centroid
    approaches = []
    lim = R.p("gates.approach_limit_m")
    for road in ctx.roads:
        xs = G.line_crossings(road.line, ring)
        for n_, (x, z) in enumerate(xs):
            approaches.append({"road_id": road.id, "kind": "crossing", "xz": (x, z), "seq": n_,
                               "weight": 2.0 if road.klass in ("대로",) else 1.0})
        if not xs:
            d = road.line.distance(frame_poly)
            if d <= lim:
                from shapely.ops import nearest_points
                pa, _ = nearest_points(road.line, frame_poly)
                approaches.append({"road_id": road.id, "kind": "nearby", "xz": (pa.x, pa.y), "seq": 0,
                                   "weight": 1.0})
    # route-network access under the same connector rule (≤10 %, no unbridged water)
    road_src = np.flatnonzero(sub.a(A.road_mask) & outside_pass)
    road_d, road_pred = Rt.dijkstra(gout, road_src)
    if not approaches:
        rc = road_d
        best = None
        for k, p in enumerate(pts):
            c = sub.cell_of(p.x, p.y)
            v = rc[c]
            if np.isfinite(v) and (best is None or v < best[0]):
                best = (float(v), p.x, p.y)
        if best:
            approaches.append({"road_id": None, "kind": "route_field", "xz": (best[1], best[2]), "seq": 0, "weight": 1.0})
    for a in approaches:
        a["bearing"] = G.bearing_of(a["xz"][0] - cen.x, a["xz"][1] - cen.y)
    approaches.sort(key=lambda a: (a["bearing"], a["road_id"] or "", a["seq"]))
    # cluster by bearing (circular)
    clusters = []
    cb = R.p("gates.cluster_bearing_deg")
    for a in approaches:
        if clusters and G.angle_diff(a["bearing"], clusters[-1][-1]["bearing"]) <= cb:
            clusters[-1].append(a)
        else:
            clusters.append([a])
    if len(clusters) > 1 and G.angle_diff(clusters[0][0]["bearing"], clusters[-1][-1]["bearing"]) <= cb:
        clusters[0] = clusters[-1] + clusters[0]
        clusters.pop()
    while len(clusters) > R.p("gates.max"):
        best = None
        for i in range(len(clusters)):
            j = (i + 1) % len(clusters)
            dd = G.angle_diff(clusters[i][-1]["bearing"], clusters[j][0]["bearing"])
            if best is None or dd < best[0]:
                best = (dd, i, j)
        _, i, j = best
        clusters[i] = clusters[i] + clusters[j]
        clusters.pop(j)
    # connector costs per approach
    conn = []
    for a in approaches:
        c0 = sub.cell_of(*a["xz"])
        d, pr = Rt.dijkstra(gout, [c0])
        a["_dist"], a["_pred"] = d, pr
    sample_cells = [sub.cell_of(p.x, p.y) for p in pts]
    per_cluster = []
    for cl in clusters:
        opts = []
        for k in range(ns):
            if blocked[k] or not math.isfinite(inner_c[k]):
                continue
            cc = sum(a["weight"] * float(a["_dist"][sample_cells[k]]) for a in cl)
            if not math.isfinite(cc):
                continue
            Rk = float(Rr.bilinear(A.win, A.R, pts[k].x, pts[k].y)[0])
            cost = cc + sum(a["weight"] for a in cl) * inner_c[k] + 200.0 * Rk
            opts.append((cost, k))
        opts.sort()
        per_cluster.append(opts[:R.p("gates.candidates_per_cluster")])
    minsp = R.p("gates.min_spacing_m")
    best = None
    feas_clusters = [i for i, o in enumerate(per_cluster) if o]
    if feas_clusters:
        for combo in itertools.product(*[per_cluster[i] for i in feas_clusters]):
            ks = [k for _, k in combo]
            okc = True
            for i in range(len(ks)):
                for j in range(i + 1, len(ks)):
                    dd = abs(ss[ks[i]] - ss[ks[j]])
                    if min(dd, L - dd) < minsp:
                        okc = False
            if not okc:
                continue
            tot = sum(c for c, _ in combo)
            key = (round(tot, 4), tuple(ks))
            if best is None or key < best[0]:
                best = (key, ks)
    gates = []
    unserved_clusters = [i for i, o in enumerate(per_cluster) if not o]
    if best:
        for ci, k in zip(feas_clusters, best[1]):
            gates.append({"k": k, "cluster": ci, "approaches": clusters[ci], "kind": "route_approach"})
    # minimum gate count (preference)
    while ctx.walled and len(gates) < R.p("gates.min"):
        rc = road_d
        cand = []
        for k in range(ns):
            if blocked[k] or not math.isfinite(inner_c[k]) or not np.isfinite(rc[sample_cells[k]]):
                continue
            if any(min(abs(ss[k] - ss[g["k"]]), L - abs(ss[k] - ss[g["k"]])) < max(minsp, L / 4) for g in gates):
                continue
            cand.append((float(rc[sample_cells[k]]) + inner_c[k], k))
        if not cand:
            break
        cand.sort()
        k = cand[0][1]
        gates.append({"k": k, "cluster": None, "approaches": [], "kind": "added_minimum",
                      "road_connector": Rt.path_cells(road_pred, sample_cells[k])})
    return {"gates": gates, "ss": ss, "pts": pts, "inner_cell": inner_cell, "approaches": approaches,
            "clusters": clusters, "unserved_clusters": unserved_clusters, "gout": gout, "L": L,
            "sample_cells": sample_cells}


def water_passages(ctx, ring):
    """Typed openings where channels/water cross the wall ring; reject open-water spans."""
    A, R = ctx.A, ctx.rules
    L = ring.length
    m = R.p("water_passage.margin_m")
    out, problems = [], []
    covered = []
    for ch in A.channels:
        for (x, z) in G.line_crossings(ch["line"], ring):
            s = G.chainage(ring, x, z)
            w = ch["width"]
            if w > R.p("water_passage.max_span_m"):
                problems.append(diag("water_span_exceeded", "error", "L2", "channel wider than max wall span",
                                     channel=ch["id"], width_m=w))
                continue
            half = w / 2 + m
            out.append({"type": "water_passage", "subtype": "sluice_gate_수문" if w >= R.p("water_passage.sluice_min_width_m") else "culvert_수구",
                        "channel_id": ch["id"], "s": (s - half, s + half), "center": (x, z), "width_m": round(2 * half, 2)})
            covered.append(Point(x, z).buffer(half + 1.0))
    # other water touched by the ring (lakes, sea, unmapped channels)
    if not A.water_poly.is_empty:
        inter = ring.intersection(A.water_poly)
        segs = [g for g in getattr(inter, "geoms", [inter]) if not g.is_empty and g.length > 0]
        for g in segs:
            if any(c.contains(g) or c.intersection(g).length > 0.8 * g.length for c in covered):
                continue
            if g.length <= 6.0:
                c = g.centroid
                s = G.chainage(ring, c.x, c.y)
                out.append({"type": "water_passage", "subtype": "culvert_수구", "channel_id": None,
                            "s": (s - g.length / 2 - m, s + g.length / 2 + m), "center": (c.x, c.y),
                            "width_m": round(g.length + 2 * m, 2), "note": "unmapped water cells"})
            else:
                problems.append(diag("wall_through_open_water", "error", "L2", "wall runs through open water",
                                     length_m=round(g.length, 1)))
    out.sort(key=lambda o: o["s"][0] % L)
    return out, problems


def water_supply(ctx, sub, interior, socket_cost, frame_poly, reserved_union):
    A, R = ctx.A, ctx.rules
    lim = R.p("water_access.limit_m")
    size = R.p("water_access.reservation_m")
    bank = sub.a(A.bank) & interior & ~sub.a(A.flood_ex)
    sc = socket_cost.reshape(sub.grid.shape)
    if bank.any():
        cand = np.where(bank & np.isfinite(sc), sc, np.inf)
        k = int(np.argmin(cand))
        if np.isfinite(cand.ravel()[k]) and cand.ravel()[k] <= lim:
            x, z = sub.xz(k)
            g = box(x - size / 2, z - size / 2, x + size / 2, z + size / 2)
            g = G.polygonal(g.intersection(frame_poly).difference(A.water_poly))
            return {"kind": "bank_access", "xz": (x, z), "cost_m": round(float(cand.ravel()[k]), 1),
                    "geom": g, "freshwater_uncertainty": "surface water; potability unknown"}
    # well: usable housing cell close to civic socket, outside reserves
    hok = sub.a(A.house_ok) & interior & ~sub.a(A.protected) & ~sub.a(A.locks) & ~sub.a(A.anchor_mask)
    if not reserved_union.is_empty:
        hok &= ~Rr.rasterize(sub.grid, reserved_union.buffer(size / 2))
    cand = np.where(hok & np.isfinite(sc), sc, np.inf)
    k = int(np.argmin(cand))
    if not np.isfinite(cand.ravel()[k]):
        return None
    x, z = sub.xz(k)
    g = G.polygonal(box(x - size / 2, z - size / 2, x + size / 2, z + size / 2).intersection(frame_poly))
    ext = None
    wc = sub.a(A.water_cost).ravel()[k]
    return {"kind": "well", "xz": (x, z), "cost_m": round(float(cand.ravel()[k]), 1), "geom": g,
            "nearest_surface_water_cost_m": (round(float(wc), 1) if np.isfinite(wc) else None),
            "freshwater_uncertainty": "groundwater availability unknown (no data)"}


# ====================================================================== evaluation
FRAME_LEVEL = {"blocked_access", "water_crossing_required", "untyped_route_crossing", "no_water_supply"}


def evaluate(ctx: Ctx, cand: dict, idx: int) -> dict:
    A, R = ctx.A, ctx.rules
    poly = G.polygonal(shapely.set_precision(cand["poly"], G.GRID))
    ev = {"family": cand["family"], "params": cand["params"], "index": idx, "constraints": [], "valid": False}
    if poly.is_empty:
        ev["constraints"].append(diag("empty_frame", "error", "L2", "candidate boundary empty"))
        return ev
    if ctx.walled:
        poly = G.largest(poly)
        poly = Polygon(poly.exterior.coords)
        poly = G.canon_polygon(poly)
    ev["poly"] = poly
    cons = ev["constraints"]
    # zero intrusion up to the geometry grid: snapping moves an edge by ≤ grid/2
    tol = R.p("acceptance.intrusion_m2") + poly.length * G.GRID / 2
    ev["precision_tolerance_m2"] = round(tol, 3)
    # ---- permission checks
    outside = poly.difference(ctx.allowed).area
    if outside > tol:
        cons.append(diag("outside_allowed", "error", "L2", "frame leaves allowed territory", area_m2=round(outside, 2)))
    nb = poly.intersection(A.neigh_poly).area if not A.neigh_poly.is_empty else 0.0
    if nb > tol:
        cons.append(diag("neighbour_enclosed", "error", "L2", "frame takes in a neighbouring settlement allocation",
                         area_m2=round(nb, 2)))
    if not A.protected_poly.is_empty:
        ev["protected_enclosed_m2"] = round(poly.intersection(A.protected_poly).area, 1)
    if ctx.inp.locks:
        bnd = poly.boundary
        hit = sorted(l["id"] for l in ctx.inp.locks if bnd.intersects(l["geom"]))
        if hit:
            cons.append(diag("lock_conflict", "error", "L2", "frame boundary crosses locked story spots (locks are never moved)",
                             locks=hit))
    if ctx.walled:
        ring = G.canon_ring(poly)
        if not ring.is_simple or not poly.is_valid:
            cons.append(diag("ring_not_simple", "error", "L2", "wall ring not a simple closed cycle"))
        ev["ring"] = ring
    if any(c["severity"] == "error" for c in cons):
        return ev
    sub = Sub(A, poly.bounds, R.p("routing.window_margin_m"))
    interior = Rr.rasterize(sub.grid, poly)
    # ---- water passages
    passages, wprob = (water_passages(ctx, ev["ring"]) if ctx.walled else ([], []))
    cons.extend(wprob)
    if wprob:
        return ev
    # ---- approach points for civic scoring
    appr = []
    for road in ctx.roads:
        if road.line.distance(poly) <= R.p("gates.approach_limit_m"):
            for (x, z) in (G.line_crossings(road.line, ev["ring"]) if ctx.walled else []):
                appr.append((x, z))
            if not appr or not ctx.walled:
                from shapely.ops import nearest_points
                pa, _ = nearest_points(road.line, poly)
                appr.append((pa.x, pa.y))
    # ---- bundles, largest first
    comp = _corridor_components(ctx, sub, interior, poly, appr) + (_reach_fn(ctx, poly),)
    tried, failed_prefixes = [], []
    nmin = val(ctx.profile["residential_min_households"])
    tries = R.p("civic.bundle_tries")
    recs = {r["key"]: r for r in ctx.insts}
    result = None
    first_fail = None
    forced_last = False
    for b in ctx.bundles:
        if (len(tried) >= tries or forced_last) and b is not ctx.bundles[-1]:
            continue
        items = set(b["variants"].items())
        if any(fp <= items for fp in failed_prefixes):
            continue  # same placement prefix failed before (placement order is deterministic)
        states, info = civic_place(ctx, poly, b, appr, comp)
        tried.append({"bundle": b["name"], "result": info.get("failed") or "placed"})
        if states is None:
            f = info["failed"]
            if f.startswith("no_fit:") or f.startswith("no_room:"):
                _, k, v = f.split(":")
                if f.startswith("no_fit:"):
                    failed_prefixes.append(frozenset({(k, v)}))
                else:
                    order = sorted(b["variants"], key=lambda q: (q == "market", -recs[q]["variants"][b["variants"][q]]["area_m2"], q))
                    pre = order[:order.index(k) + 1]
                    failed_prefixes.append(frozenset((q, b["variants"][q]) for q in pre))
            first_fail = first_fail or f
            continue
        for si, placed in enumerate(states):
            r = _complete(ctx, ev, sub, interior, poly, b, placed, passages)
            r["beam_state"] = si
            codes = {c["code"] for c in r["constraints"] if c["severity"] == "error"}
            # only civic-layout failures justify trying another beam state
            if r["status"] == "ok" or not codes <= {"civic_disconnected", "civic_entrance_blocked", "corridor_grade"}:
                break
        tried[-1]["result"] = r["status"]
        frame_level = {c["code"] for c in r["constraints"] if c["severity"] == "error"} & FRAME_LEVEL
        if frame_level:
            result = r
            last = ctx.bundles[-1]
            if b is last or any(t["bundle"] == last["name"] for t in tried):
                break
            forced_last = True  # civic layout changes gates: try the smallest bundle before giving up
            continue
        if r["status"] == "ok" and r.get("households", {"N": 0})["N"] >= nmin:
            result = r
            break
        if result is None or (r["status"] == "ok" and (result["status"] != "ok" or r["households"]["N"] > result.get("households", {"N": -1})["N"])):
            result = r
    ev["bundles_tried"] = tried
    if result is None:
        cons.append(diag("civic_fit_failed", "error", "L2", "no civic bundle fits this frame", first_failure=first_fail))
        return ev
    ev.update({k: v for k, v in result.items() if k != "constraints"})
    cons.extend(result["constraints"])
    if result["status"] == "ok" and result.get("households", {"N": 0})["N"] < nmin:
        cons.append(diag("insufficient_capacity", "error", "L2", "households below profile residential minimum",
                         households=result["households"]["N"], minimum=nmin))
    ev["valid"] = not any(c["severity"] == "error" for c in cons)
    if "ledger" in ev:
        ev["objective"] = objective(ctx, ev)
    return ev


def _walk_reach(ctx, sub, poly, corr_poly, gates_out, civic_union):
    """Land reachable on foot from the corridor network within residential.access_max_m
    (8-neighbour walking cost, no water/protected/civic crossing) — replaces Euclidean distance."""
    A, R = ctx.A, ctx.rules
    if corr_poly is None or corr_poly.is_empty:
        return Polygon()
    walk = Rr.rasterize(sub.grid, poly) & sub.a(A.cov) & ~(sub.a(A.water) & ~sub.a(ctx.small_channel)) & ~sub.a(A.protected)
    walk &= ~Rr.rasterize(sub.grid, civic_union)
    src_m = Rr.rasterize(sub.grid, corr_poly) & walk
    if not src_m.any():
        return Polygon()
    g = Rt.build_graph(sub.grid, sub.a(A.h), walk, radius=1, grade_k=R.p("routing.grade_cost_k"))
    d, _ = Rt.dijkstra(g, np.flatnonzero(src_m), limit=R.p("residential.access_max_m"))
    reach = np.isfinite(d.reshape(sub.grid.shape))
    return Rr.mask_to_polygon(sub.grid, reach)


def _reach_fn(ctx, poly):
    """Factory: for a partial civic placement, cells reachable by the access-class corridor
    graph from the first entrance, with placed envelopes as obstacles (cached)."""
    A = ctx.A
    subp = Sub(A, poly.bounds, 12.0)
    inter = Rr.rasterize(subp.grid, poly)
    cache = {}

    def fn(placed):
        key = tuple((p["key"], p["xz"], p["bearing"]) for p in placed)
        if key in cache:
            return cache[key]
        civ = Rr.rasterize(subp.grid, shapely.union_all([p["rect"] for p in placed]))
        fore = Rr.rasterize(subp.grid, shapely.union_all([p["strip"] for p in placed])) & ~civ
        pas = corridor_passable(ctx, subp, inter, civ, fore)
        socks = []
        for p in placed:
            sx, sz = G.front_point(p["xz"][0], p["xz"][1], p["env"]["depth_m"], p["bearing"], p["env"]["entrance_clearance_m"] / 2)
            c = nearest_true(pas, subp.grid, sx, sz, max(6.0, p["env"]["entrance_clearance_m"] + 4))
            if c is None:
                cache[key] = False
                return False
            socks.append(c)
        pas2 = pas.copy()
        for c in socks:
            pas2.ravel()[c] = True
        g = access_graph(ctx, subp.grid, subp.a(A.h), pas2)
        dd, _ = Rt.dijkstra(g, [socks[0]])
        res = bool(all(np.isfinite(dd[c]) for c in socks))
        cache[key] = res
        return res
    return fn


def unwalled_connectors(ctx, sub):
    """Land an unwalled settlement's access lanes may cross to reach the route network: any
    passable, non-protected, non-locked ground (a lane is circulation, not occupation), plus
    mapped crossings — never open water."""
    A = ctx.A
    wet = sub.a(A.water) & ~sub.a(ctx.small_channel) & ~sub.a(A.bridge_mask)
    return sub.a(A.cov) & sub.a(A.passable) & ~wet & ~sub.a(A.protected) & ~sub.a(A.locks)


def _corridor_components(ctx, sub, interior, poly, appr=None):
    """Connected components of the ≤10 % corridor graph inside the frame; civic entrances
    must share one component that also reaches the boundary (gate side) or a route."""
    from scipy.sparse.csgraph import connected_components
    A, R = ctx.A, ctx.rules
    pas = corridor_passable(ctx, sub, interior, np.zeros(sub.grid.shape, bool))
    if not ctx.walled:
        pas = pas | unwalled_connectors(ctx, sub)
    g = access_graph(ctx, sub.grid, sub.a(A.h), pas)
    n, lab = connected_components(g, directed=False)
    lab = lab.reshape(sub.grid.shape)
    lab = np.where(pas, lab, -1)
    # components touching the boundary band (walled) or the route network (unwalled)
    if ctx.walled:
        band = interior & ~ndimage.binary_erosion(interior, iterations=ctx.corr_cells + 4)
    else:
        band = ndimage.binary_dilation(sub.a(A.road_mask), iterations=ctx.corr_cells + 4)
    if appr:
        # prefer the components whose boundary band faces the route approaches (gates go there)
        X, Z = np.meshgrid(sub.grid.xs(), sub.grid.zs())
        near = np.zeros(sub.grid.shape, bool)
        for (ax, az) in appr:
            near |= (X - ax) ** 2 + (Z - az) ** 2 <= ctx.rules.p("gates.approach_band_m") ** 2
        band = band & near  # strict: no component facing an approach → no civic site
    touch = np.unique(lab[band & pas])
    touch = touch[touch >= 0]
    if touch.size == 0:
        return (lab, sub.grid, np.array([-2]))
    sizes = np.bincount(lab[pas].ravel(), minlength=n)
    good = touch[sizes[touch] >= 0.25 * sizes[touch].max()]
    return (lab, sub.grid, np.sort(good))


def _complete(ctx, ev, sub, interior, poly, bundle, placed, passages):
    A, R = ctx.A, ctx.rules
    cons = []
    civic_union = shapely.union_all([p["rect"] for p in placed])
    civic_mask = Rr.rasterize(sub.grid, civic_union)
    fore_mask = Rr.rasterize(sub.grid, shapely.union_all([p["strip"] for p in placed])) & ~civic_mask
    pas = corridor_passable(ctx, sub, interior, civic_mask, fore_mask)
    if not ctx.walled:
        extra = unwalled_connectors(ctx, sub)
        extra &= ~(ndimage.binary_dilation(civic_mask, iterations=ctx.corr_cells) & ~fore_mask)
        pas = pas | extra
    sockets = {}
    for p in placed:
        sx, sz = G.front_point(p["xz"][0], p["xz"][1], p["env"]["depth_m"], p["bearing"], p["env"]["entrance_clearance_m"] / 2)
        c = nearest_true(pas, sub.grid, sx, sz, max(6.0, p["env"]["entrance_clearance_m"] + 4))
        if c is not None:
            cx_, cz_ = sub.xz(c)
            seg = LineString([(sx, sz), (cx_, cz_)]) if (cx_, cz_) != (sx, sz) else None
            walk_ok = G.polygonal(poly).buffer(0.01)
            leaves = ctx.walled and not walk_ok.contains(seg) if seg is not None else False
            if seg is not None and (seg.intersects(civic_union.buffer(-0.05)) or leaves
                                    or seg.intersects(A.water_poly)):
                c = None
        if c is None:
            cons.append(diag("civic_entrance_blocked", "error", "L2", "civic entrance not on corridor land", civic=p["key"]))
            continue
        sockets[p["key"]] = c
        pas.ravel()[c] = True
    gcorr = access_graph(ctx, sub.grid, sub.a(A.h), pas)
    main_key = placed[0]["key"]
    if main_key not in sockets:
        return {"status": "fail", "constraints": cons, "bundle": bundle, "placed": placed}
    dist, pred = Rt.dijkstra(gcorr, list(sockets.values()))
    # civic sockets mutually connected
    d0, p0 = Rt.dijkstra(gcorr, [sockets[main_key]])
    links = []
    for k, c in sockets.items():
        if k == main_key:
            continue
        if not np.isfinite(d0[c]):
            cons.append(diag("civic_disconnected", "error", "L2", "civic entrances not connected by a ≤10% corridor",
                             civic=k))
        else:
            links.append(("civic_link", k, Rt.path_cells(p0, c)))
    gates_out = []
    reroutes = []
    if ctx.walled:
        gs = solve_gates(ctx, sub, poly, ev["ring"], interior, dist, pred, [o["s"] for o in passages])
        if not gs["gates"]:
            code, msg = _no_gate_reason(ctx, sub, interior, gs)
            cons.append(diag(code, "error", "L2", msg, approaches=len(gs["approaches"])))
        for ci in gs["unserved_clusters"]:
            cons.append(diag("approach_unserved", "warning", "L2", "route-approach cluster has no feasible gate",
                             roads=sorted({a["road_id"] or "-" for a in gs["clusters"][ci]})))
        L = gs["L"]
        gw = R.p("gates.width_m")
        for n_, g in enumerate(sorted(gs["gates"], key=lambda g: gs["ss"][g["k"]])):
            k = g["k"]
            p = gs["pts"][k]
            ic = gs["inner_cell"][k]
            path = Rt.path_cells(pred, ic)  # from socket to gate-side inner cell
            path = list(reversed(path))     # gate → socket
            con_paths = []
            if g.get("road_connector"):
                con_paths.append({"road_id": None, "kind": "route_network", "cells": g["road_connector"]})
            for a in g["approaches"]:
                if a["kind"] != "crossing":
                    cp = Rt.path_cells(a["_pred"], gs["sample_cells"][k])
                    con_paths.append({"road_id": a["road_id"], "kind": a["kind"], "cells": cp})
            gates_out.append({"seq": n_ + 1, "s": (gs["ss"][k] - gw / 2, gs["ss"][k] + gw / 2), "center": (p.x, p.y),
                              "kind": g["kind"], "roads": sorted({a["road_id"] for a in g["approaches"] if a["road_id"]}),
                              "corridor_cells": path, "connectors": con_paths, "chain_s": gs["ss"][k]})
        # every road/wall crossing → gate or explicit reroute
        for a in gs["approaches"]:
            if a["kind"] != "crossing":
                continue
            s = G.chainage(ev["ring"], *a["xz"])
            served = [g for g in gates_out if min(abs(s - g["chain_s"]), L - abs(s - g["chain_s"])) <= R.p("gates.serve_tolerance_m")]
            if served:
                a["served_by"] = served[0]["seq"]
                continue
            best = None
            for g in gates_out:
                c = gs["sample_cells"][gs["ss"].index(g["chain_s"])]
                v = float(a["_dist"][c])
                if math.isfinite(v) and (best is None or v < best[0]):
                    best = (v, g, c)
            if best is None:
                cons.append(diag("untyped_route_crossing", "error", "L2", "route crosses the wall with no gate or feasible reroute",
                                 road=a["road_id"], xz=[G.r2(a["xz"][0]), G.r2(a["xz"][1])]))
            else:
                reroutes.append({"road_id": a["road_id"], "crossing_xz": a["xz"], "gate_seq": best[1]["seq"],
                                 "cells": Rt.path_cells(a["_pred"], best[2]), "cost_m": round(best[0], 1)})
                a["served_by"] = f"reroute→gate{best[1]['seq']}"
        if len(gates_out) < R.p("gates.min") and gates_out:
            cons.append(diag("fewer_than_min_gates", "warning", "L2", "fewer gates than the preferred minimum",
                             gates=len(gates_out)))
        ev["approaches"] = [{"road_id": a["road_id"], "kind": a["kind"], "xz": a["xz"], "bearing": a["bearing"],
                             "served_by": a.get("served_by")} for a in gs["approaches"]]
    else:
        # unwalled: connect route network to civic place(s); entrances where corridors leave roads
        road_cells = np.flatnonzero(sub.a(A.road_mask) & pas)
        if road_cells.size == 0:
            cons.append(diag("blocked_access", "error", "L2", "no route reaches the settlement territory"))
        else:
            for k, c in sockets.items():
                dr, prr = Rt.dijkstra(gcorr, road_cells)
                if not np.isfinite(dr[c]):
                    cons.append(diag("blocked_access", "error", "L2", "civic place not reachable from a route with ≤10% corridors",
                                     civic=k))
                    continue
                path = Rt.path_cells(prr, c)
                gates_out.append({"seq": len(gates_out) + 1, "s": None, "center": sub.xz(path[0]),
                                  "kind": "entrance", "roads": [], "corridor_cells": path, "connectors": [],
                                  "chain_s": None})
            # every cluster must be reachable from the route network
            dr, _ = Rt.dijkstra(gcorr, road_cells)
            drm = dr.reshape(sub.grid.shape)
            for n_, cpoly in enumerate(G.parts(poly)):
                cm = Rr.rasterize(sub.grid, cpoly)
                if not np.isfinite(drm[cm]).any():
                    cons.append(diag("cluster_inaccessible", "warning", "L2", "cluster not reachable by ≤10% corridor; excluded from capacity",
                                     cluster=n_ + 1, area_m2=round(cpoly.area, 1)))
        ev["approaches"] = []
    # ---- corridor geometry (tree with explicit junctions)
    corridors = []
    all_paths = [("gate", g["seq"], g["corridor_cells"]) for g in gates_out] + links
    for kind, ref, cells in all_paths:
        if len(cells) < 1:
            continue
        pts = Rt.cells_to_xz(sub.grid, cells)
        if kind == "gate" and ctx.walled:
            gc = next(g for g in gates_out if g["seq"] == ref)["center"]
            pts = [gc] + pts
        line_raw = LineString(pts) if len(pts) > 1 else LineString([pts[0], pts[0]])
        simp = line_raw.simplify(1.0)
        gmax_s, det_s = measure_grade(ctx, sub.grid, sub.a(A.h), list(simp.coords))
        gmax_r, det_r = measure_grade(ctx, sub.grid, sub.a(A.h), pts)
        if gmax_s <= ctx.rc["limit"] + 1e-6:
            geom, gm, det = simp, gmax_s, det_s
        else:
            geom, gm, det = line_raw, gmax_r, det_r
        culverts = int(sum(1 for c in cells if sub.a(ctx.small_channel).ravel()[c]))
        corridors.append({"kind": kind, "ref": ref, "line": geom, "grade_max": gm, "length_m": geom.length,
                          "cells": cells, "culvert_cells": culverts, "grade_detail": det})
        if gm > ctx.rc["limit"] + 1e-6:
            cons.append(diag("corridor_grade", "error", "L2", f"{ctx.road_class} corridor exceeds grade limit",
                             corridor=f"{kind}-{ref}", grade=round(gm, 4), measure=det["measure"]))
    corr_poly = G.polygonal(shapely.union_all([c["line"].buffer(ctx.corr_half, cap_style="round") for c in corridors],
                                              grid_size=G.GRID)) if corridors else Polygon()
    corr_poly = G.polygonal(corr_poly.intersection(poly, grid_size=G.GRID)) if not corr_poly.is_empty else corr_poly
    # junction nodes from the shortest-path tree
    counts = {}
    for c in corridors:
        for a in c["cells"]:
            counts[a] = counts.get(a, 0) + 1
    junctions = set()
    for c in corridors:
        cs = c["cells"]
        for a, b in zip(cs, cs[1:]):
            if counts.get(a, 0) != counts.get(b, 0) and min(counts[a], counts[b]) >= 1:
                junctions.add(a if counts[a] > counts[b] else b)
    sock_cells = set(sockets.values())
    junctions = sorted(j for j in junctions if j not in sock_cells)
    # ---- water supply
    reserved = shapely.union_all([civic_union] + ([corr_poly] if not corr_poly.is_empty else []))
    ws = water_supply(ctx, sub, interior, dist, poly, reserved)
    if ws is None:
        cons.append(diag("no_water_supply", "error", "L2", "no water-supply reservation possible"))
    elif ws["cost_m"] > R.p("water_access.limit_m"):
        cons.append(diag("water_access_far", "warning", "L2", "water supply beyond screening limit", cost_m=ws["cost_m"]))
    # ---- capacity re-solve with placed reserves
    reserves = [("civic_reserve", shapely.union_all([p["rect"] for p in placed])),
                ("civic_forecourt", shapely.union_all([p["strip"] for p in placed])),
                ("primary_corridor", corr_poly)]
    if ws is not None:
        reserves.append(("water_supply", ws["geom"]))
    access_geom = _walk_reach(ctx, sub, poly, corr_poly, gates_out, civic_union)
    T, entries, comps, frags, residual = P.partition(poly, A, reserves, access_geom, R)
    fl, fo = R.p("program.f_lanes"), R.p("program.f_open")
    comps_eff = [(f"c{i + 1:02d}", p.area * (1 - fl - fo)) for i, (p, _) in enumerate(comps)]
    hh = P.solve_households(comps_eff, ctx.profile, R)
    if hh["search"]["exhausted"] and sum(e for _, e in comps_eff) > 0:
        cons.append(diag("capacity_search_exhausted", "warning", "L2", "no integer packing found"))
    status = "ok" if not any(c["severity"] == "error" for c in cons) else "fail"
    return {"status": status, "constraints": cons, "bundle": bundle, "placed": placed, "sockets": sockets,
            "sub": sub, "gates": gates_out, "reroutes": reroutes, "passages": passages, "corridors": corridors,
            "corridor_poly": corr_poly, "junctions": junctions, "water_supply": ws, "households": hh,
            "ledger": (T, entries, comps, frags, residual, comps_eff)}


def _no_gate_reason(ctx, sub, interior, gs):
    """Name the blocking constraint: unbridged water vs terrain grade."""
    A, R = ctx.A, ctx.rules
    if not gs["approaches"]:
        return "blocked_access", "no route approaches the frame"
    wet = sub.a(A.cov) & ~ndimage.binary_erosion(interior, iterations=1)
    g = access_graph(ctx, sub.grid, sub.a(A.h), wet)
    for a in gs["approaches"]:
        d, _ = Rt.dijkstra(g, [sub.cell_of(*a["xz"])])
        if any(np.isfinite(d[c]) and not np.isfinite(a["_dist"][c]) for c in gs["sample_cells"]):
            return ("water_crossing_required",
                    "gates are reachable only by crossing unbridged water (no mapped crossing; Layer 4 bridge needed)")
    return "blocked_access", "no gate position connects an external route to civic access with ≤10% corridors"


def objective(ctx, ev):
    R = ctx.rules
    w = {k: R.objective_weight(k) for k in ("civic_fit", "access", "compactness", "terrain_economy", "axis", "capacity")}
    placed = ev.get("placed") or []
    full_area = sum(r["variants"]["full"]["area_m2"] for r in ctx.insts if r["inside_wall"])
    b_area = ev["bundle"]["area_m2"] if ev.get("bundle") else 0.0
    civic = 0.0
    if placed:
        civic = 0.5 * (sum(p["score"] for p in placed) / len(placed)) + 0.5 * (b_area / full_area if full_area else 1.0)
    lo, hi = R.objective_range("access_cost_per_gate")
    gates = ev.get("gates") or []
    costs = [c["length_m"] * (1 + R.p("routing.grade_cost_k") * c["grade_max"] ** 2)
             + R.p("routing.mountain.switchback_cost_m") * c.get("grade_detail", {}).get("switchbacks", 0)
             for c in ev.get("corridors", []) if c["kind"] == "gate"]
    acc = 1 - np.clip((np.mean(costs) - lo) / (hi - lo), 0, 1) if costs else 0.0
    lo, hi = R.objective_range("compactness_iq")
    poly = ev["poly"]
    iq = G.isoperimetric(G.largest(poly))
    comp = float(np.clip((iq - lo) / (hi - lo), 0, 1))
    T, entries = ev["ledger"][0], ev["ledger"][1]
    unb = sum(e["area_m2"] for e in entries if e["category"] in ("unbuildable_slope", "unusable_fragment", "flood_exclusion"))
    lo, hi = R.objective_range("unbuildable_fraction")
    terr = 1 - float(np.clip((unb / max(T.area, 1) - lo) / (hi - lo), 0, 1))
    if ctx.axes and placed:
        lo, hi = R.objective_range("axis_deg")
        ax = 1 - float(np.clip((G.angle_diff(placed[0]["bearing"], ctx.axes[0]["bearing"]) - lo) / (hi - lo), 0, 1))
    else:
        ax = 0.5
    N = ev["households"]["N"] if ev.get("households") else 0
    cap = min(1.0, N / max(1, ctx.capacity_target))
    terms = {"civic_fit": round(float(civic), 4), "access": round(float(acc), 4), "compactness": round(comp, 4),
             "terrain_economy": round(terr, 4), "axis": round(ax, 4), "capacity": round(cap, 4)}
    return {"terms": terms, "score": round(sum(w[k] * terms[k] for k in terms) / sum(w.values()), 6),
            "capacity_target": ctx.capacity_target,
            "notes": {"axis": "neutral 0.5 without supplied axis evidence",
                      "capacity": "households fitted / L1 estimate over the allowed envelope; weights renormalized"}}


# ====================================================================== driver
def solve(A, L1, rules, family):
    ctx = Ctx(A, L1, rules, family)
    ctx.capacity_target = P.standalone(A, rules, L1["program"]["profile"], territory="allowed")["program"]["households"]["represented"]
    gen = GENERATORS[family]
    cands = gen(ctx)
    diags = []
    if not cands:
        diags.append(diag("no_candidate_found", "error", "L2", f"{family} generator produced no candidate boundary "
                          "(bounded search; not a proof of infeasibility)"))
        return {"ctx": ctx, "evaluated": [], "ranked": [], "diagnostics": diags, "generated": 0}
    lim = rules.p("frame.eval_limit")
    evaluated = []
    for i, c in enumerate(cands[:lim]):
        evaluated.append(evaluate(ctx, c, i))
    valid = [e for e in evaluated if e["valid"]]
    for e in evaluated:
        e["stable_id"] = G.stable_id("frame", e["poly"]) if "poly" in e else f"frame-none-{e['index']}"
    valid.sort(key=lambda e: (-e["objective"]["score"], e["stable_id"]))
    # seed-derived variation (TOOL-04): among alternatives within the tie epsilon of the best,
    # order by hash(seed, alternative id) — results depend on seed only where the rules are indifferent
    if valid:
        import hashlib
        eps = rules.p("frame.seed_tie_epsilon")
        top = valid[0]["objective"]["score"]
        tie = [e for e in valid if top - e["objective"]["score"] <= eps]
        rest = [e for e in valid if top - e["objective"]["score"] > eps]
        tie.sort(key=lambda e: hashlib.sha1(f"{A.inp.seed}:{e['stable_id']}".encode()).hexdigest())
        valid = tie + rest
    ranked = []
    for e in valid:
        if any(G.iou(e["poly"], r["poly"]) > rules.p("frame.dedupe_iou") for r in ranked):
            continue
        ranked.append(e)
        if len(ranked) >= rules.p("frame.alternatives"):
            break
    if not ranked:
        counts = {}
        for e in evaluated:
            for c in e["constraints"]:
                if c["severity"] == "error":
                    counts[c["code"]] = counts.get(c["code"], 0) + 1
        diags.append(diag("no_valid_frame", "error", "L2", "all evaluated candidates violate hard constraints",
                          candidates=len(evaluated), generated=len(cands), failures=dict(sorted(counts.items()))))
    return {"ctx": ctx, "evaluated": evaluated, "ranked": ranked, "diagnostics": diags, "generated": len(cands)}
