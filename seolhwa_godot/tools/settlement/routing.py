"""Grid least-cost routing (scipy.sparse.csgraph Dijkstra == A* with zero heuristic).

Edge cost c = l * (1 + k * g^2) with g the grade between the edge endpoints on the
smoothed terrain. No corner cutting: every cell the edge segment touches must be
passable. Optional hard grade cap is checked on sub-samples along the edge.
"""
from __future__ import annotations

import math
from functools import lru_cache

import numpy as np
from scipy import ndimage
from scipy.sparse import csr_matrix
from scipy.sparse.csgraph import dijkstra as _dijkstra

from .raster import Grid


@lru_cache(maxsize=None)
def offsets(radius: int) -> tuple:
    """Directed primitive offsets (di, dj) with max(|di|,|dj|) <= radius."""
    out = []
    for dj in range(-radius, radius + 1):
        for di in range(-radius, radius + 1):
            if (di, dj) == (0, 0):
                continue
            if math.gcd(abs(di), abs(dj)) != 1:
                continue
            out.append((di, dj))
    out.sort(key=lambda o: (abs(o[0]) + abs(o[1]), o[1], o[0]))
    return tuple(out)


@lru_cache(maxsize=None)
def supercover(di: int, dj: int) -> tuple:
    """Relative cells touched by the segment (0,0)->(di,dj), excluding the endpoints."""
    cells = set()
    n = 64 * max(abs(di), abs(dj))
    e = 1e-7
    for k in range(1, n):
        t = k / n
        px, pz = t * di, t * dj
        for ex in (-e, e):
            for ez in (-e, e):
                cells.add((math.floor(px + 0.5 + ex), math.floor(pz + 0.5 + ez)))
    cells.discard((0, 0))
    cells.discard((di, dj))
    return tuple(sorted(cells))


def build_graph(grid: Grid, height: np.ndarray, passable: np.ndarray, *, radius: int = 1,
                grade_k: float = 8.0, grade_cap: float | None = None, sub_cap: float | None = None,
                cost_mult: np.ndarray | None = None) -> csr_matrix:
    nz, nx = grid.shape
    N = nz * nx
    idx = np.arange(N, dtype=np.int64).reshape(nz, nx)
    srcs, dsts, ws = [], [], []
    for di, dj in offsets(radius):
        # source window so that target is inside
        j0, j1 = max(0, -dj), nz - max(0, dj)
        i0, i1 = max(0, -di), nx - max(0, di)
        if j1 <= j0 or i1 <= i0:
            continue
        ok = passable[j0:j1, i0:i1] & passable[j0 + dj:j1 + dj, i0 + di:i1 + di]
        for ci, cj in supercover(di, dj):
            ok &= passable[j0 + cj:j1 + cj, i0 + ci:i1 + ci]
        if not ok.any():
            continue
        l = grid.cell * math.hypot(di, dj)
        ha = height[j0:j1, i0:i1]
        hb = height[j0 + dj:j1 + dj, i0 + di:i1 + di]
        g = np.abs(hb - ha) / l
        if grade_cap is not None:
            nsub = max(1, int(math.ceil(math.hypot(di, dj))))
            if nsub > 1:
                jj, ii = np.nonzero(ok)
                jj = jj + j0
                ii = ii + i0
                prev = height[jj, ii]
                gmax = np.zeros(jj.shape)
                for k in range(1, nsub + 1):
                    t = k / nsub
                    cur = ndimage.map_coordinates(height, [jj + t * dj, ii + t * di], order=1,
                                                  mode="nearest")
                    gmax = np.maximum(gmax, np.abs(cur - prev) / (l / nsub))
                    prev = cur
                sub_ok = gmax <= (grade_cap if sub_cap is None else sub_cap) + 1e-9
                ok[jj[~sub_ok] - j0, ii[~sub_ok] - i0] = False
            ok &= g <= grade_cap + 1e-9
        w = l * (1.0 + grade_k * g * g)
        if cost_mult is not None:
            w = w * 0.5 * (cost_mult[j0:j1, i0:i1] + cost_mult[j0 + dj:j1 + dj, i0 + di:i1 + di])
        s = idx[j0:j1, i0:i1][ok]
        d = idx[j0 + dj:j1 + dj, i0 + di:i1 + di][ok]
        srcs.append(s)
        dsts.append(d)
        ws.append(w[ok])
    if not srcs:
        return csr_matrix((N, N))
    s = np.concatenate(srcs)
    d = np.concatenate(dsts)
    w = np.concatenate(ws)
    return csr_matrix((w, (s, d)), shape=(N, N))


def dijkstra(graph: csr_matrix, sources, limit: float = np.inf):
    sources = np.unique(np.asarray(sources, dtype=np.int64))
    if sources.size == 0:
        n = graph.shape[0]
        return np.full(n, np.inf), np.full(n, -9999, dtype=np.int64)
    dist, pred, _src = _dijkstra(graph, directed=True, indices=sources,
                                 return_predecessors=True, min_only=True, limit=limit)
    return dist, pred


def path_cells(pred: np.ndarray, target: int) -> list[int]:
    out = []
    t = int(target)
    guard = pred.size + 1
    while t >= 0 and guard > 0:
        out.append(t)
        t = int(pred[t])
        guard -= 1
    out.reverse()
    return out


def cells_to_xz(grid: Grid, cells: list[int]) -> list[tuple[float, float]]:
    nx = grid.nx
    return [(grid.x0 + (c % nx) * grid.cell, grid.z0 + (c // nx) * grid.cell) for c in cells]


def flat_index(grid: Grid, i: int, j: int) -> int:
    return j * grid.nx + i


def path_length(pts) -> float:
    return float(sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts, pts[1:])))


def grade_profile(grid: Grid, height: np.ndarray, pts, step: float = 2.0):
    """Sample a polyline every `step` m; return (chainage, y, max grade between samples)."""
    from .raster import bilinear
    if len(pts) < 2:
        return [0.0], [float(bilinear(grid, height, pts[0][0], pts[0][1])[0])] if pts else [], 0.0
    # subdivide every segment separately (vertex-aligned, as the routing graph checks it)
    xs, zs, ss = [pts[0][0]], [pts[0][1]], [0.0]
    for a, b in zip(pts, pts[1:]):
        seg = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(math.ceil(seg / step - 1e-9)))
        for k in range(1, n + 1):
            t = k / n
            xs.append(a[0] + t * (b[0] - a[0]))
            zs.append(a[1] + t * (b[1] - a[1]))
            ss.append(ss[-1] + seg / n)
    n = len(ss) - 1
    ys = bilinear(grid, height, xs, zs)
    gmax = 0.0
    for k in range(n):
        ds = ss[k + 1] - ss[k]
        if ds > 1e-9:
            gmax = max(gmax, abs(ys[k + 1] - ys[k]) / ds)
    return ss, [float(v) for v in ys], float(gmax)


def sustained_grade(grid: Grid, height: np.ndarray, pts, window: float = 10.0, smooth: float = 3.0, step: float = 1.0):
    """Grade along a smoothed centreline: resample every `step` m, moving-average the
    plan position over ±`smooth` m, then the max |Δy|/Δs over any `window` m stretch.
    Returns (sustained_max, local_max, smoothed_points, chainage, heights)."""
    from shapely.geometry import LineString
    from .raster import bilinear
    if len(pts) < 2:
        return 0.0, 0.0, list(pts), [0.0], []
    line = LineString(pts)
    L = line.length
    n = max(2, int(math.ceil(L / step)) + 1)
    ss = np.linspace(0, L, n)
    xy = np.array([line.interpolate(v).coords[0] for v in ss])
    k = max(0, int(round(smooth / step)))
    if k > 0 and n > 2 * k + 1:
        ker = np.ones(2 * k + 1) / (2 * k + 1)
        sm = xy.copy()
        for c in (0, 1):
            pad = np.concatenate([np.full(k, xy[0, c]), xy[:, c], np.full(k, xy[-1, c])])
            sm[:, c] = np.convolve(pad, ker, mode="valid")
        sm[0], sm[-1] = xy[0], xy[-1]
        xy = sm
    if k > 0 and n > 2 * k + 1:
        seg = np.hypot(np.diff(xy[:, 0]), np.diff(xy[:, 1]))
        s2 = np.concatenate([[0.0], np.cumsum(seg)])
    else:
        s2 = ss  # chainage along the path itself (hairpin corners do not shorten it)
        seg = np.diff(s2)
    ys = bilinear(grid, height, xy[:, 0], xy[:, 1])
    local = float(np.max(np.abs(np.diff(ys)) / np.maximum(seg, 1e-9))) if seg.size else 0.0
    s2 = np.asarray(s2, float)
    ys = np.asarray(ys, float)
    if s2[-1] <= window:
        sus = abs(ys[-1] - ys[0]) / max(s2[-1], 1e-9)
    else:
        st_ = s2[s2 <= s2[-1] - window]
        yend = np.interp(st_ + window, s2, ys)  # exact window end point
        ystart = np.interp(st_, s2, ys)
        sus = float(np.max(np.abs(yend - ystart)) / window)
    return float(sus), local, [tuple(p) for p in xy], [float(v) for v in s2], [float(v) for v in ys]


def count_switchbacks(pts, turn_deg: float = 120.0, min_leg: float = 4.0) -> int:
    """Hairpins: heading changes beyond turn_deg between successive legs (simplified line)."""
    from shapely.geometry import LineString
    if len(pts) < 3:
        return 0
    q = list(LineString(pts).simplify(1.5).coords)
    legs = [(b[0] - a[0], b[1] - a[1]) for a, b in zip(q, q[1:]) if math.hypot(b[0] - a[0], b[1] - a[1]) >= min_leg]
    n = 0
    for u, v in zip(legs, legs[1:]):
        c = (u[0] * v[0] + u[1] * v[1]) / (math.hypot(*u) * math.hypot(*v))
        if math.degrees(math.acos(max(-1.0, min(1.0, c)))) > turn_deg:
            n += 1
    return n
