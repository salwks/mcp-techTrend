"""WP4 terrain data layer (spec 16 GEO-01/02/04, 01 NAT-01/02, audit 20 WP4).

Order (spec 19 §1.1): terrain (ridge network · catchments · rock body) → water → movement.

Coarse analysis (``terrain.analysis_cell_m``, block mean of the smoothed 2 m height, whole
input window incl. halo):
  * priority-flood with epsilon (mapped water burned, sea = outlet, closed depressions deeper
    than ``terrain.max_fill_depth_m`` kept as internal sinks), D8 steepest descent, upslope area;
  * DEM drainage lines (upslope area ≥ ``terrain.channel_area_m2``) split into reaches at
    confluences; a catchment = all cells draining to one reach (or to one outlet);
  * ridges = shared boundaries of two catchments that are NOT upstream/downstream of each other
    (those boundaries cross valleys); ``main`` when the two drain to different outlets, ``spur``
    (지능선) otherwise, ``flat_divide`` when the divide has no relief;
  * saddles (안부) = interior low points of a ridge with a rise on both sides; mapped passes are
    matched, never moved;
  * landform per cell: plain / valley_floor / foot_slope / slope / ridge / saddle / summit / water,
    from slope, HAND (height above nearest drainage), relief and distance to the floor.

Fine ground classes (2 m work window): cliff / rock_exposure / talus / bar_gravel / alluvium /
soil_mantled from game-height slope, convexity, landuse rock/bar classes, HAND and the
cliff → debris run-out. The region rock type is recorded but is never a classification input
(spec 16 §2.1: one rock type does not mean one form).

Habitat placeholders: landuse components with a management type (WP10 fills the unknowns).
Nothing here moves or edits given data.
"""
from __future__ import annotations

import heapq
import math

import numpy as np
import shapely
from scipy import ndimage
from shapely.geometry import LineString, Point, Polygon

from . import contract as C
from . import geometry as G
from . import raster as Rr
from .raster import Grid

LANDFORMS = ["unknown", "plain", "valley_floor", "foot_slope", "slope", "ridge", "saddle", "summit", "water"]
LF = {k: n for n, k in enumerate(LANDFORMS)}
GROUND = ["none", "soil_mantled", "alluvium", "bar_gravel", "talus", "rock_exposure", "cliff", "water"]
GC = {k: n for n, k in enumerate(GROUND)}
EXPOSURE = {"cliff": "exposed_rock", "rock_exposure": "exposed_rock", "talus": "debris", "bar_gravel": "loose_sediment",
            "alluvium": "sediment_mantled", "soil_mantled": "soil_mantled", "water": "submerged"}
OFFS = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
CLASSIFY_INPUTS = ["slope_deg(source landscape: game remap undone)", "tpi30_m", "landuse rock/bar class", "hand_m", "cliff run-out (D8)",
                   "coarse landform"]


class Terrain:
    pass


def scope_of(inp):
    return inp.region if not inp.meta.get("fixture") else f"SYNTHETIC.{inp.id}"


def _xzid(x, z, step=10):
    return f"x{int(round(x / step) * step)}_z{int(round(z / step) * step)}"


def _uniq(ids, base):
    k, out = 1, base
    while out in ids:
        k += 1
        out = f"{base}.{k}"
    ids.add(out)
    return out


# ---------------------------------------------------------------- coarse grid
def coarse(full: Grid, arr, f, how="mean", valid=None):
    nz, nx = full.shape
    nzc, nxc = -(-nz // f), -(-nx // f)
    pad = ((0, nzc * f - nz), (0, nxc * f - nx))
    if how == "mean":
        a = np.pad(arr.astype(np.float64), pad, mode="edge")
        if valid is not None:
            v = np.pad(valid.astype(np.float64), pad, mode="constant")
            num = (a * v).reshape(nzc, f, nxc, f).sum(axis=(1, 3))
            den = v.reshape(nzc, f, nxc, f).sum(axis=(1, 3))
            with np.errstate(invalid="ignore", divide="ignore"):
                m = num / den
            return np.where(den > 0, m, np.nan)
        return a.reshape(nzc, f, nxc, f).mean(axis=(1, 3))
    a = np.pad(arr.astype(np.float64), pad, mode="constant")
    return a.reshape(nzc, f, nxc, f).mean(axis=(1, 3))  # fraction


def _priority_flood(z, valid, seeds, eps):
    nz, nx = z.shape
    N = nz * nx
    zf = z.ravel().tolist()
    vf = valid.ravel().tolist()
    filled = [math.inf] * N
    closed = bytearray(N)
    heap = []
    for c in np.flatnonzero(seeds.ravel()).tolist():
        closed[c] = 1
        filled[c] = zf[c]
        heap.append((zf[c], c))
    heapq.heapify(heap)
    while heap:
        e, c = heapq.heappop(heap)
        j, i = divmod(c, nx)
        for dj, di in OFFS:
            jj, ii = j + dj, i + di
            if 0 <= jj < nz and 0 <= ii < nx:
                n = jj * nx + ii
                if not closed[n] and vf[n]:
                    closed[n] = 1
                    v = zf[n]
                    if v < e + eps:
                        v = e + eps
                    filled[n] = v
                    heapq.heappush(heap, (v, n))
    out = np.array(filled).reshape(nz, nx)
    out[~valid] = np.nan
    return out


def _receivers(F, valid, seeds, cellc):
    nz, nx = F.shape
    Fp = np.pad(np.where(valid, F, np.inf), 1, constant_values=np.inf)
    best = np.zeros(F.shape)
    rec = np.full(F.shape, -1, dtype=np.int64)
    J, I = np.mgrid[0:nz, 0:nx]
    for dj, di in OFFS:
        nb = Fp[1 + dj:1 + dj + nz, 1 + di:1 + di + nx]
        d = cellc * (math.sqrt(2) if dj and di else 1.0)
        with np.errstate(invalid="ignore"):
            drop = (F - nb) / d
        better = valid & np.isfinite(drop) & (drop > best + 1e-15)
        best = np.where(better, drop, best)
        rec = np.where(better, (J + dj) * nx + (I + di), rec)
    rec[seeds | ~valid] = -1
    return rec.ravel()


def _seeds(valid, sea):
    edge = np.zeros(valid.shape, bool)
    edge[0, :] = edge[-1, :] = edge[:, 0] = edge[:, -1] = True
    near_invalid = ndimage.binary_dilation(~valid, structure=np.ones((3, 3), bool)) & valid
    return valid & (edge | near_invalid | sea)


# ---------------------------------------------------------------- main
def build(inp, A, rules) -> Terrain:
    T = Terrain()
    full = inp.grid
    cell = full.cell
    f = max(1, int(round(rules.p("terrain.analysis_cell_m") / cell)))
    cellc = f * cell
    T.f, T.cellc = f, cellc
    T.gc = Grid(full.x0 + (f - 1) * cell / 2, full.z0 + (f - 1) * cell / 2, cellc, -(-full.nx // f), -(-full.nz // f))
    cov = inp.coverage
    hc = coarse(full, A.full_h, f, valid=cov)
    valid = coarse(full, cov, f, how="frac") >= 0.5
    valid &= np.isfinite(hc)
    hc = np.where(valid, hc, 0.0)
    exempt = inp.flood_exempt if inp.flood_exempt is not None else np.zeros(full.shape, bool)
    water = inp.water_mask & cov
    wf = coarse(full, water & ~exempt, f, how="frac")
    sea = (coarse(full, water & ~inp.water_fresh, f, how="frac") >= 0.5) & valid
    wburn = (wf > 0) & valid & ~sea
    T.hc, T.valid, T.sea, T.water = hc, valid, sea, (wf >= 0.25) & valid
    z = hc - rules.p("terrain.burn_m") * wburn
    seeds = _seeds(valid, sea)
    eps = rules.p("terrain.fill_eps_m")
    F1 = _priority_flood(z, valid, seeds, eps)
    depth = np.where(valid, F1 - z, 0.0)
    lab, n = Rr.label(depth > 0.01)
    sinks = np.zeros(valid.shape, bool)
    maxd = rules.p("terrain.max_fill_depth_m")
    if n:
        mx = ndimage.maximum(depth, lab, index=np.arange(1, n + 1))
        for k in np.nonzero(np.asarray(mx) > maxd)[0] + 1:
            idx = np.flatnonzero((lab == k).ravel())
            c = idx[int(np.argmin(z.ravel()[idx]))]
            sinks.flat[c] = True
    seeds2 = seeds | sinks
    F = _priority_flood(z, valid, seeds2, eps) if sinks.any() else F1
    T.sinks = sinks
    rec = _receivers(F, valid, seeds2, cellc)
    N = rec.size
    area = (cellc * cellc) * valid.ravel().astype(np.float64)
    order_dn = np.argsort(-np.nan_to_num(F.ravel(), nan=-np.inf), kind="stable")
    acc = area.copy().tolist()
    recl = rec.tolist()
    for c in order_dn.tolist():
        r = recl[c]
        if r >= 0:
            acc[r] += acc[c]
    acc = np.array(acc)
    chan = valid.ravel() & ~sea.ravel() & ((acc >= rules.p("terrain.channel_area_m2")) | wburn.ravel())
    # reaches on the drainage network (split at confluences)
    donors = {}
    for c in np.flatnonzero(chan).tolist():
        r = recl[c]
        if r >= 0 and chan[r]:
            donors.setdefault(r, []).append(c)
    reach = np.zeros(N, dtype=np.int64)
    nreach = 0
    for c in order_dn.tolist():
        if not chan[c]:
            continue
        d = donors.get(c, [])
        if len(d) == 1:
            reach[c] = reach[d[0]]
        else:
            nreach += 1
            reach[c] = nreach
    # one mapped water body (connected burned cells) = one drainage unit for catchments
    wl, nw = Rr.label(wburn)
    wlf = wl.ravel()
    remap = {}
    for k in range(1, nw + 1):
        rs = sorted(set(reach[(wlf == k) & chan].tolist()) - {0})
        for r_ in rs:
            remap[r_] = rs[0]
    if remap:
        reach = np.array([remap.get(int(r_), int(r_)) for r_ in reach.tolist()], dtype=np.int64)
    reach_down = {}
    for c in np.flatnonzero(chan).tolist():
        r = recl[c]
        if r >= 0 and chan[r] and reach[r] != reach[c]:
            reach_down.setdefault(int(reach[c]), int(reach[r]))
    # base (first drainage cell downstream), outlet (seed), HAND
    order_up = order_dn[::-1]
    base = np.arange(N)
    outlet = np.arange(N)
    basel, outl = base.tolist(), outlet.tolist()
    chl = chan.tolist()
    for c in order_up.tolist():
        r = recl[c]
        if r >= 0:
            outl[c] = outl[r]
            if not chl[c]:
                basel[c] = basel[r]
    base, outlet = np.array(basel), np.array(outl)
    hand = (hc.ravel() - hc.ravel()[base]).reshape(hc.shape)
    hand[~valid] = np.nan
    # catchment labels: drainage reach; hillslope cells that reach an outlet without a drainage
    # line (divergent slopes to the window edge / sea / a sink) are grouped by connectivity so
    # parallel slope strips do not invent divides between themselves
    vfl = valid.ravel()
    onch = chan[base]
    labc = np.zeros(N, dtype=np.int64)
    labc[onch & vfl] = reach[base[onch & vfl]]
    strip = (~onch & vfl).reshape(hc.shape)
    sl_, ns = Rr.label(strip)
    ids_used = sorted(set(labc[labc > 0].tolist()))
    dense = {r_: k + 1 for k, r_ in enumerate(ids_used)}
    labc = np.array([dense.get(int(v), 0) for v in labc.tolist()], dtype=np.int64)
    reach_down = {dense[a_]: dense[b_] for a_, b_ in reach_down.items() if a_ in dense and b_ in dense}
    nreach = len(dense)
    slf = sl_.ravel()
    labc[slf > 0] = nreach + slf[slf > 0]
    nl = nreach + ns
    cmin = rules.p("terrain.catchment_min_m2")
    areas = np.bincount(labc, weights=area, minlength=nl + 1)
    fringe = {l for l in range(nreach + 1, nl + 1) if areas[l] < cmin}
    lab2 = labc.copy()
    if fringe:
        lab2[np.isin(labc, sorted(fringe))] = 0
    lab2[~vfl] = 0
    # outlet key per label: the seed of a drainage chain, or the slope group itself
    okey = {}
    for l in range(1, nl + 1):
        if l in fringe:
            continue
        cells = np.flatnonzero(labc == l)
        if not cells.size:
            continue
        okey[l] = ("seed", int(outlet[cells[0]])) if l <= nreach else ("slope_group", l)
    seed_lab = {}
    T.rec, T.acc, T.chan, T.reach, T.reach_down = rec, acc, chan, reach, reach_down
    T.base, T.outlet, T.hand = base, outlet, hand
    T.on_drainage = (chan[base] & vfl).reshape(hc.shape)
    T.catch = lab2.reshape(hc.shape)
    T.nreach, T.seed_lab = nreach, seed_lab
    T.final_outlet = okey
    T.outlet_cell = {l: (int(outlet[np.flatnonzero(labc == l)[0]]) if l <= nreach else None) for l in okey}
    slope_c, _, _ = Rr.slope_aspect(hc, cellc)
    T.slope_c = np.where(valid, slope_c, np.nan)
    T.tpi300 = np.where(valid, hc - Rr.disk_mean(hc, valid, 300, cellc), 0.0)
    _ridges(T, inp, rules)
    _assign_ids(T, inp)
    _landform(T, rules)
    _ground(T, inp, A, rules)
    return T


def _assign_ids(T, inp):
    """Deterministic ids from position (identity registry for terrain objects is WP5+)."""
    scope = scope_of(inp)
    gc = T.gc
    T.catch_polys, T.catch_ids = {}, {}
    used = set()
    for l in sorted(set(np.unique(T.catch).tolist()) - {0}):
        poly = Rr.mask_to_polygon(gc, T.catch == l).simplify(gc.cell / 2)
        c = poly.representative_point()
        T.catch_polys[l] = poly
        T.catch_ids[l] = _uniq(used, f"catchment:{scope}:{_xzid(c.x, c.y)}")
    used = set()
    for r in T.ridges:
        c = r["line"].interpolate(0.5, normalized=True)
        r["id"] = _uniq(used, f"ridge:{scope}:{r['kind']}:{_xzid(c.x, c.y)}")
    used = set()
    for s in T.saddles:
        s["id"] = _uniq(used, f"saddle:{scope}:{_xzid(*s['xz'])}")


def _ancestors(T, l):
    seen = []
    while l in T.reach_down:
        l = T.reach_down[l]
        if l in seen:
            break
        seen.append(l)
    return set(seen)


def _ridges(T, inp, rules):
    lab = T.catch
    gc = T.gc
    pairs = set()
    for a, b in ((lab[:, :-1], lab[:, 1:]), (lab[:-1, :], lab[1:, :])):
        m = (a > 0) & (b > 0) & (a != b)
        for x, y in zip(a[m].tolist(), b[m].tolist()):
            pairs.add((min(x, y), max(x, y)))
    polys = {}
    for l in sorted({p for pr in pairs for p in pr}):
        polys[l] = Rr.mask_to_polygon(gc, lab == l)
    anc = {l: _ancestors(T, l) for l in polys}
    step = rules.p("terrain.saddle_sample_m")
    rise_min = rules.p("terrain.saddle_min_rise_m")
    tpi_min = rules.p("terrain.ridge_min_tpi_m")
    ridges, saddles = [], []
    for a, b in sorted(pairs):
        if a in anc.get(b, set()) or b in anc.get(a, set()):
            continue  # upstream/downstream catchments: their boundary crosses a valley, not a ridge
        inter = polys[a].boundary.intersection(polys[b].boundary)
        lines = [g for g in getattr(inter, "geoms", [inter]) if g.geom_type in ("LineString", "MultiLineString")]
        if not lines:
            continue
        merged = shapely.line_merge(shapely.union_all(lines))
        parts = [g for g in getattr(merged, "geoms", [merged]) if g.geom_type == "LineString" and g.length >= 3 * gc.cell]
        kind = "main" if T.final_outlet.get(a) != T.final_outlet.get(b) else "spur"
        for part in parts:
            L = part.length
            ss = np.linspace(0, L, max(3, int(math.ceil(L / step)) + 1))
            xy = shapely.get_coordinates(shapely.line_interpolate_point(part, ss))
            ys = Rr.bilinear(gc, T.hc, xy[:, 0], xy[:, 1])
            tp = Rr.bilinear(gc, T.tpi300, xy[:, 0], xy[:, 1])
            k_ = kind if float(np.mean(tp)) >= tpi_min else "flat_divide"
            rid = len(ridges) + 1
            simp = part.simplify(gc.cell / 2)
            rec = {"n": rid, "kind": k_, "between": [a, b], "line": simp, "length_m": round(L, 1),
                   "crest_max_y": round(float(ys.max()), 2), "crest_min_y": round(float(ys.min()), 2),
                   "mean_tpi300_m": round(float(np.mean(tp)), 2), "saddles": []}
            if k_ != "flat_divide" and len(ys) >= 3:
                cands = []
                for k in range(1, len(ys) - 1):
                    if ys[k] <= ys[k - 1] and ys[k] < ys[k + 1] or (ys[k] < ys[k - 1] and ys[k] <= ys[k + 1]):
                        rl = float(ys[:k].max() - ys[k])
                        rr = float(ys[k + 1:].max() - ys[k])
                        if min(rl, rr) >= rise_min:
                            cands.append((float(ys[k]), k, rl, rr))
                cands.sort()
                keep = []
                for y, k, rl, rr in cands:
                    if all(abs(ss[k] - ss[k2]) > 2 * rules.p("terrain.saddle_radius_m") for _, k2, _, _ in keep):
                        keep.append((y, k, rl, rr))
                # a saddle also falls away across the ridge on both sides (else it is a flank point)
                d_ = 2 * gc.cell
                tang = np.gradient(xy, axis=0)
                keep2 = []
                for y, k, rl, rr in keep:
                    tx, tz = tang[k]
                    nrm = math.hypot(tx, tz) or 1.0
                    px, pz = -tz / nrm, tx / nrm
                    side = Rr.bilinear(gc, T.hc, [xy[k, 0] + px * d_, xy[k, 0] - px * d_], [xy[k, 1] + pz * d_, xy[k, 1] - pz * d_])
                    if float(side.max()) < y:
                        keep2.append((y, k, rl, rr))
                for y, k, rl, rr in sorted(keep2, key=lambda t: t[1]):
                    saddles.append({"n": len(saddles) + 1, "xz": [G.r2(xy[k, 0]), G.r2(xy[k, 1])], "y": round(y, 2),
                                    "ridge": rid, "between": [a, b], "rise_m": [round(rl, 2), round(rr, 2)],
                                    "ridge_kind": k_, "mapped": None})
                    rec["saddles"].append(len(saddles))
            ridges.append(rec)
    # summits
    r = max(1, int(round(rules.p("terrain.summit_radius_m") / gc.cell)))
    mx = ndimage.maximum_filter(np.where(T.valid, T.hc, -np.inf), footprint=Rr.disk_kernel(r * gc.cell, gc.cell).astype(bool))
    pk = T.valid & (T.hc >= mx) & (T.tpi300 >= rules.p("terrain.summit_min_tpi_m"))
    summits = []
    jj, ii = np.nonzero(pk)
    for j, i in sorted(zip(jj.tolist(), ii.tolist())):
        x, z = gc.xz(i, j)
        if all(math.hypot(x - s["xz"][0], z - s["xz"][1]) > r * gc.cell for s in summits):
            summits.append({"n": len(summits) + 1, "xz": [G.r2(x), G.r2(z)], "y": round(float(T.hc[j, i]), 2),
                            "tpi300_m": round(float(T.tpi300[j, i]), 2)})
    # mapped passes (region.json passes): matched, never moved
    match = rules.p("routes.saddle_match_m")
    for p in inp.meta.get("passes", []) or []:
        best = None
        for s in saddles:
            d = math.hypot(s["xz"][0] - p["xz"][0], s["xz"][1] - p["xz"][1])
            if d <= match and (best is None or d < best[0]):
                best = (d, s)
        rec = {"id": p.get("id"), "name": p.get("name"), "xz": p["xz"], "y": p.get("y"), "confidence": p.get("confidence"),
               "source": p.get("source")}
        if best:
            best[1]["mapped"] = dict(rec, distance_m=round(best[0], 1))
        else:
            saddles.append({"n": len(saddles) + 1, "xz": [G.r2(p["xz"][0]), G.r2(p["xz"][1])], "y": p.get("y"),
                            "ridge": None, "between": None, "rise_m": None, "ridge_kind": None,
                            "mapped": dict(rec, distance_m=None), "derived": False})
    T.ridges, T.saddles, T.summits = ridges, saddles, summits


def _landform(T, rules):
    gc = T.gc
    vf = rules.p("terrain.valley_floor")
    pl = rules.p("terrain.plain")
    fs = rules.p("terrain.foot_slope")
    s, hand, valid = T.slope_c, np.nan_to_num(T.hand, nan=1e9), T.valid
    mn, mx = Rr.disk_minmax(T.hc, pl["relief_radius_m"], gc.cell)
    relief = mx - mn
    code = np.full(T.hc.shape, LF["slope"], dtype=np.int8)
    valley = (s <= vf["max_slope_deg"]) & (hand <= vf["max_hand_m"]) & T.on_drainage
    plain = (s <= pl["max_slope_deg"]) & (relief <= pl["max_relief_m"]) & ~valley
    floor = valley | plain
    dist = ndimage.distance_transform_edt(~floor) * gc.cell
    foot = (s <= fs["max_slope_deg"]) & (hand <= fs["max_hand_m"]) & (dist <= fs["max_dist_m"]) & (T.tpi300 < 0) & ~floor
    code[plain] = LF["plain"]
    code[valley] = LF["valley_floor"]
    code[foot] = LF["foot_slope"]
    rl = [r["line"] for r in T.ridges if r["kind"] in ("main", "spur")]
    if rl:
        band = Rr.rasterize(gc, shapely.union_all([l.buffer(rules.p("terrain.ridge_band_m")) for l in rl]))
        code[band] = LF["ridge"]
    sr = rules.p("terrain.saddle_radius_m")
    for sd in T.saddles:
        if sd.get("ridge") is not None:
            code[Rr.rasterize(gc, Point(*sd["xz"]).buffer(sr, 16))] = LF["saddle"]
    for sm in T.summits:
        code[Rr.rasterize(gc, Point(*sm["xz"]).buffer(max(gc.cell * 1.5, 20.0), 16))] = LF["summit"]
    code[T.water] = LF["water"]
    code[~valid] = LF["unknown"]
    T.landform = code


def landform_at(T, x, z):
    i, j = T.gc.ij(x, z)
    if not T.gc.inside(i, j):
        return "unknown"
    return LANDFORMS[int(T.landform[j, i])]


def catchment_at(T, x, z):
    i, j = T.gc.ij(x, z)
    if not T.gc.inside(i, j):
        return 0
    return int(T.catch[j, i])


def to_window(T, A, arr):
    """Nearest coarse value for every 2 m work-window cell."""
    win = A.win
    xs, zs = win.xs(), win.zs()
    ii = np.clip(np.floor((xs - T.gc.x0) / T.gc.cell + 0.5).astype(int), 0, T.gc.nx - 1)
    jj = np.clip(np.floor((zs - T.gc.z0) / T.gc.cell + 0.5).astype(int), 0, T.gc.nz - 1)
    return arr[np.ix_(jj, ii)]


def _d8_window(h):
    nz, nx = h.shape
    hp = np.pad(h, 1, constant_values=np.inf)
    best = np.zeros(h.shape)
    rec = np.full(h.shape, -1, dtype=np.int64)
    J, I = np.mgrid[0:nz, 0:nx]
    for dj, di in OFFS:
        nb = hp[1 + dj:1 + dj + nz, 1 + di:1 + di + nx]
        d = math.sqrt(2) if dj and di else 1.0
        drop = (h - nb) / d
        better = drop > best + 1e-12
        best = np.where(better, drop, best)
        rec = np.where(better, (J + dj) * nx + (I + di), rec)
    return rec.ravel()


def _ground(T, inp, A, rules):
    win = A.win
    cell = win.cell
    slope_game, _, _ = Rr.slope_aspect(A.h_raw, cell)
    # classify on the source-landscape slope: undo the game's vertical remap (heights are
    # already remapped; horizontal and pre-remap vertical share the factor K, so the pre-remap
    # slope is the real one). Fixtures / regions without a remap: factor 1.
    remap = (inp.provenance.get("vertical") or {}).get("remap")
    fac = np.ones(win.shape)
    if remap:
        src, dst = remap["src"], remap["dst"]
        for k in range(len(dst) - 1):
            m_ = (A.h_raw >= dst[k]) & (A.h_raw <= dst[k + 1])
            fac[m_] = (dst[k + 1] - dst[k]) / (src[k + 1] - src[k])
    slope_raw = np.degrees(np.arctan(np.tan(np.radians(slope_game)) / fac))
    T.slope_basis = "source slope (game height remap undone)" if remap else "game slope (no remap)"
    tpi30 = np.nan_to_num(A.tpi[30], nan=0.0)
    lu = inp.meta.get("landuse")
    luw = lu[A.sl] if lu is not None else None
    cls = rules.p("ground.landuse_classes")
    rock_lu = (luw == cls["rock"]) if luw is not None else np.zeros(win.shape, bool)
    bar_lu = (luw == cls["bar"]) if luw is not None else np.zeros(win.shape, bool)
    hand_w = to_window(T, A, np.nan_to_num(T.hand, nan=1e9))
    lf_w = to_window(T, A, T.landform)
    water = A.water
    cliff = ((slope_raw >= rules.p("ground.cliff_min_deg")) | (rock_lu & (slope_raw >= rules.p("ground.cliff_rock_min_deg")))) & ~water & A.cov
    rockx = (rock_lu | ((slope_raw >= rules.p("ground.rock_exposure_min_deg")) & (tpi30 > rules.p("ground.rock_convex_tpi_m")))) & ~cliff & ~water & A.cov
    # cliff → debris run-out along steepest descent (supply → accumulation, GEO-04)
    clab, nclif = Rr.label(cliff)
    rec = _d8_window(A.h_raw)
    steps = int(round(rules.p("ground.talus_runout_m") / cell))
    src = np.zeros(win.nx * win.nz, dtype=np.int64)
    pos = np.flatnonzero(cliff.ravel())
    lab0 = clab.ravel()[pos]
    for _ in range(steps):
        nxt = rec[pos]
        ok = nxt >= 0
        pos, lab0 = nxt[ok], lab0[ok]
        if not pos.size:
            break
        cur = src[pos]
        upd = (cur == 0) | (lab0 < cur)
        src[pos[upd]] = lab0[upd]
    src = src.reshape(win.shape)
    ts = rules.p("ground.talus_slope_deg")
    talus = (src > 0) & (slope_raw >= ts[0]) & (slope_raw <= ts[1]) & ~cliff & ~water & A.cov & (tpi30 <= rules.p("ground.rock_convex_tpi_m"))
    al = rules.p("ground.alluvium")
    alluv = (np.isin(lf_w, [LF["valley_floor"], LF["plain"], LF["water"]]) & (hand_w <= al["max_hand_m"])
             & (A.slope <= al["max_slope_deg"]) & ~water & A.cov)
    code = np.full(win.shape, GC["soil_mantled"], dtype=np.int8)
    code[alluv] = GC["alluvium"]
    code[bar_lu & ~water] = GC["bar_gravel"]
    code[talus] = GC["talus"]
    code[rockx] = GC["rock_exposure"]
    code[cliff] = GC["cliff"]
    code[water] = GC["water"]
    code[~A.cov] = GC["none"]
    T.ground, T.cliff_lab, T.talus_src, T.slope_raw = code, clab, src, slope_raw


# ---------------------------------------------------------------- records
def records(T, inp, A, rules, store, profile_natural):
    """TerrainPatch / HabitatPatch / ridge / saddle / catchment records for the layer file."""
    scope = scope_of(inp)
    gc = T.gc
    rh = rules.hash
    srcs = ["fixture"] if inp.meta.get("fixture") else [f"region_data/{inp.region}/height.png", f"region_data/{inp.region}/landuse.png"]
    rock = (profile_natural or {}).get("rock_candidates")
    rock_type = {"candidates": rock["value"] if rock else None, "grade": rock["grade"] if rock else "U",
                 "status": rock["status"] if rock else "unknown", "sources": rock["sources"] if rock else [],
                 "used_for_classification": False,
                 "note": "recorded only — form is decided from relief/slope/exposure/drainage (spec 16 GEO-01)"}
    struct = C.measure(None, "deg", missing_reason="no joint/bedding orientation data (G01 legend not collated)")
    # catchments
    catch = []
    cell_a = gc.cell ** 2
    edge = np.zeros(T.catch.shape, bool)
    edge[0, :] = edge[-1, :] = edge[:, 0] = edge[:, -1] = True
    for l in sorted(T.catch_ids):
        m = T.catch == l
        poly = T.catch_polys[l]
        o = T.outlet_cell.get(l)
        oj, oi = divmod(o, gc.nx) if o is not None else (None, None)
        body = {"id": T.catch_ids[l], "drains_to": ("drainage_line" if l <= T.nreach else "hillslope_group"),
                "downstream": T.catch_ids.get(T.reach_down.get(l)), "area_m2": round(float(m.sum()) * cell_a, 1),
                "truncated_by_window": bool((m & edge).any()),
                "outlet_xz": [G.r2(gc.xz(oi, oj)[0]), G.r2(gc.xz(oi, oj)[1])] if o is not None else None,
                "outlet_kind": (("sea" if T.sea.flat[o] else "sink" if T.sinks.flat[o] else "window_edge") if o is not None
                                else "several (divergent slope to edge/sea/sink without a drainage line)"),
                "geometry": store.add(poly)}
        body["meta"] = C.meta(body["id"], status="proposed", sources=srcs, rules_hash=rh, content=body)
        catch.append(body)
    ids_c = dict(T.catch_ids)
    ridges = []
    sad_ids = {s["n"]: s["id"] for s in T.saddles}
    for r in T.ridges:
        body = {"id": r["id"], "kind": r["kind"], "between": [ids_c.get(x) for x in r["between"]],
                "line": store.add(r["line"]), "length_m": r["length_m"], "crest_max_y": r["crest_max_y"],
                "crest_min_y": r["crest_min_y"], "mean_tpi300_m": r["mean_tpi300_m"],
                "saddles": [sad_ids[k] for k in r["saddles"]]}
        body["meta"] = C.meta(r["id"], status="proposed", sources=srcs, rules_hash=rh, content=body)
        ridges.append(body)
    rid_of = {r["n"]: r["id"] for r in T.ridges}
    saddles = []
    for s in T.saddles:
        body = {"id": s["id"], "xz": s["xz"], "y": s["y"], "ridge": rid_of.get(s["ridge"]),
                "between": [ids_c.get(x) for x in s["between"]] if s["between"] else None,
                "rise_m": s["rise_m"], "ridge_kind": s["ridge_kind"], "derived": s.get("derived", True),
                "mapped_pass": s["mapped"]}
        st, hyp = ("proposed", False)
        src = list(srcs)
        if s["mapped"]:
            ev, hyp_ = C.status_of(s["mapped"].get("confidence"))
            s["mapped"]["evidence_status"] = ev
            src = [f"region_data/{inp.region}/region.json#passes:{s['mapped']['id']}"] + list(s["mapped"].get("source") or [])
            if not s.get("derived", True):
                st, hyp = ev, hyp_  # a mapped pass record (not generated): status from its source confidence
        body["meta"] = C.meta(s["id"], status=st, sources=src, rules_hash=rh, content=body, hypothesis=hyp)
        saddles.append(body)
    summits = [{"id": f"summit:{scope}:{_xzid(*sm['xz'])}", **{k: v for k, v in sm.items() if k != 'n'}} for sm in T.summits]
    # landform patches (coarse)
    patches = []
    used = set()
    pmin = rules.p("terrain.patch_min_m2")
    win_box = shapely.box(*A.win.bounds())
    gfr = _ground_fractions_fn(T, A)
    for name in LANDFORMS[1:]:
        lab, n = Rr.label(T.landform == LF[name])
        if not n:
            continue
        sizes = np.bincount(lab.ravel(), minlength=n + 1) * cell_a
        for k in range(1, n + 1):
            if sizes[k] < pmin:
                continue
            m = lab == k
            poly = Rr.mask_to_polygon(gc, m).simplify(gc.cell / 2)
            c = poly.representative_point()
            pid = _uniq(used, f"terrain:{scope}:{name}:{_xzid(c.x, c.y)}")
            fr = gfr(poly) if poly.intersects(win_box) else None
            body = {"kind": "landform", "landform": name, "original": store.add(poly), "modified": None,
                    "change_reason": "none (no earthworks in this layer; reverse effects are WP5+)",
                    "area_m2": round(float(sizes[k]), 1),
                    "rock_body": {"ground_fractions": fr, "missing_reason": None if fr else "outside the 2 m work window"},
                    "rock_type": rock_type, "structure_dir": struct,
                    "exposure": (max(fr, key=lambda q: fr[q]) if fr else None),
                    "catchments": sorted({ids_c[x] for x in np.unique(T.catch[m]).tolist() if x in ids_c}),
                    "inputs": ["slope_deg(coarse)", "hand_m", "relief_m", "tpi300_m", "distance_to_floor_m", "ridge/saddle/summit"]}
            if fr:
                body["exposure"] = EXPOSURE.get(max(fr, key=lambda q: fr[q]), "unknown")
            body["meta"] = C.meta(pid, status="proposed", sources=srcs, rules_hash=rh, content=body)
            patches.append(body)
    # ground patches (fine): cliffs, rock exposures, talus, bars, alluvium
    gmin = rules.p("ground.patch_min_m2")
    cell_w = A.win.cell ** 2
    for name in ("cliff", "rock_exposure", "talus", "bar_gravel", "alluvium"):
        lab, n = Rr.label(T.ground == GC[name])
        if not n:
            continue
        sizes = np.bincount(lab.ravel(), minlength=n + 1) * cell_w
        for k in range(1, n + 1):
            if sizes[k] < gmin[name]:
                continue
            m = lab == k
            poly = Rr.mask_to_polygon(A.win, m)
            c = poly.representative_point()
            pid = _uniq(used, f"terrain:{scope}:{name}:{_xzid(c.x, c.y, 2)}")
            rb = {"class": name, "inputs": CLASSIFY_INPUTS}
            if name == "cliff":
                rb.update(_cliff_contacts(T, A, m))
                rb["heightfield_representable"] = False
                rb["interior"] = {"value": None, "missing_reason": "no cave/overhang data; not an explorable interior"}
            if name == "talus":
                sup = np.unique(T.talus_src[m])
                rb["supply_cliffs"] = sorted(int(x) for x in sup if x > 0)
            body = {"kind": "ground", "landform": landform_at(T, c.x, c.y), "original": store.add(poly), "modified": None,
                    "change_reason": "none", "area_m2": round(float(sizes[k]), 1), "rock_body": rb,
                    "rock_type": rock_type, "structure_dir": struct, "exposure": EXPOSURE[name],
                    "catchments": [ids_c[catchment_at(T, c.x, c.y)]] if catchment_at(T, c.x, c.y) in ids_c else []}
            if name == "cliff":
                body["_cliff_label"] = int(np.max(T.cliff_lab[m]))
            body["meta"] = C.meta(pid, status="proposed", sources=srcs, rules_hash=rh,
                                  content={k: v for k, v in body.items() if not k.startswith("_")})
            patches.append(body)
    # cliff label → patch id for talus supply links
    cl2id = {p["_cliff_label"]: p["meta"]["stable_id"] for p in patches if "_cliff_label" in p}
    for p in patches:
        p.pop("_cliff_label", None)
        rb = p["rock_body"]
        if "supply_cliffs" in rb:
            rb["supply_cliffs"] = sorted({cl2id.get(x, f"cliff_below_patch_min:{x}") for x in rb["supply_cliffs"]})
            p["meta"]["revision"] = C.revision({k: v for k, v in p.items() if k != "meta"})
    habitats = _habitats(T, inp, A, rules, store, ids_c, scope, srcs, profile_natural)
    counts = {g: int((T.ground == GC[g]).sum()) for g in GROUND[1:]}
    summary = {
        "analysis_cell_m": gc.cell, "catchments": len(catch), "ridges": {k: sum(1 for r in ridges if r["kind"] == k) for k in ("main", "spur", "flat_divide")},
        "saddles": len(saddles), "mapped_passes_matched": sum(1 for s in saddles if s["mapped_pass"] and s["derived"]),
        "mapped_passes_unmatched": sum(1 for s in saddles if s["mapped_pass"] and not s["derived"]),
        "summits": len(summits), "internal_sinks": int(T.sinks.sum()),
        "landform_area_m2": {k: round(float((T.landform == LF[k]).sum()) * cell_a, 1) for k in LANDFORMS[1:]},
        "ground_area_m2": {k: round(v * cell_w, 1) for k, v in counts.items()},
        "patches": {"landform": sum(1 for p in patches if p["kind"] == "landform"), "ground": sum(1 for p in patches if p["kind"] == "ground")},
        "habitats": len(habitats),
    }
    return {"catchments": catch, "ridges": ridges, "saddles": saddles, "summits": summits, "patches": patches,
            "habitats": habitats, "summary": summary, "_catch_ids": ids_c}


def _ground_fractions_fn(T, A):
    def fr(poly):
        m = Rr.rasterize(A.win, poly) & A.cov
        n = int(m.sum())
        if n == 0:
            return None
        cnt = np.bincount(T.ground[m].astype(int), minlength=len(GROUND))
        return {GROUND[k]: round(float(cnt[k]) / n, 4) for k in range(1, len(GROUND)) if cnt[k]}
    return fr


def _cliff_contacts(T, A, m):
    ring = ndimage.binary_dilation(m, structure=np.ones((3, 3), bool), iterations=2) & ~m
    h = A.h_raw
    hm = float(np.mean(h[m]))
    top = ring & (h > hm)
    bot = ring & (h <= hm)

    def dom(mask):
        if not mask.any():
            return None
        cnt = np.bincount(T.ground[mask].astype(int), minlength=len(GROUND))
        cnt[GC["cliff"]] = 0
        k = int(np.argmax(cnt))
        return GROUND[k] if cnt[k] else "cliff_only"
    return {"top_contact": dom(top), "bottom_contact": dom(bot),
            "height_m": round(float(h[m].max() - h[m].min()), 2)}


def _habitats(T, inp, A, rules, store, ids_c, scope, srcs, prof):
    lu = inp.meta.get("landuse")
    mg = rules.p("habitat.landuse_management")
    pmin = rules.p("habitat.patch_min_m2")
    cell_a = A.win.cell ** 2
    out = []
    used = set()
    fm = (prof or {}).get("forest.management")
    note = (prof or {}).get("forest.notes")
    if lu is None:
        groups = [("cultivated", A.farmland, "cultivated_yard")] if A.farmland.any() else []
        cls_name = {"cultivated": "fixture farmland"}
    else:
        luw = lu[A.sl]
        names = inp.meta.get("landuse_classes", {})
        groups = [(str(k), luw == k, mg[str(k)]) for k in sorted(int(x) for x in mg)]
        cls_name = {str(k): names.get(k, str(k)) for k in sorted(int(x) for x in mg)}
    for key, mask, man in groups:
        lab, n = Rr.label(mask & A.cov & ~A.water)
        if not n:
            continue
        sizes = np.bincount(lab.ravel(), minlength=n + 1) * cell_a
        for k in range(1, n + 1):
            if sizes[k] < pmin:
                continue
            m = lab == k
            poly = Rr.mask_to_polygon(A.win, m)
            c = poly.representative_point()
            cats = sorted({ids_c[x] for x in np.unique(to_window(T, A, T.catch)[m]).tolist() if x in ids_c})
            known = man != "unknown"
            body = {"community": {"landuse": cls_name.get(key, key), "species": None,
                                  "missing_reason": "species/composition not sourced (21 forest rows U; spec 18 SURF-07)"},
                    "management": man,
                    "management_basis": ("landuse class (cultivation/yard follows from current use)" if known else
                                         "unknown — management type needs a source (WP10)"),
                    "management_candidates": ["natural", "protected", "village_grove", "use_forest", "abandoned"] if not known else [],
                    "region_forest_management": fm, "region_forest_notes": note,
                    "soil": None, "moisture": None, "season": None,
                    "geometry": store.add(poly), "area_m2": round(float(sizes[k]), 1), "catchments": cats}
            hid = _uniq(used, f"habitat:{scope}:{key}:{_xzid(c.x, c.y, 2)}")
            body["meta"] = C.meta(hid, status="proposed" if known else "unknown", sources=srcs, rules_hash=rules.hash,
                                  content=body)
            out.append(body)
    return out


def fields(T, A):
    """Arrays for terrain-fields.npz (coarse + window)."""
    return {"coarse_origin_cell": np.array([T.gc.x0, T.gc.z0, T.gc.cell], dtype=np.float64),
            "coarse_height": T.hc.astype(np.float32), "coarse_filled_valid": T.valid,
            "coarse_upslope_area_m2": T.acc.reshape(T.hc.shape).astype(np.float32),
            "coarse_drainage": T.chan.reshape(T.hc.shape), "coarse_catchment": T.catch.astype(np.int32),
            "coarse_hand_m": np.nan_to_num(T.hand, nan=-1).astype(np.float32),
            "coarse_landform": T.landform, "window_origin_cell": np.array([A.win.x0, A.win.z0, A.win.cell], dtype=np.float64),
            "window_ground": T.ground}
