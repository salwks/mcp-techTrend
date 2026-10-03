"""북쪽 대표 도시 배치 공용 도우미 — tools/placement/hubs.py(placement-east, 2026-10-03 22:33 판)의 공용 도우미를 옮겨 온 것.

hubs.py는 다른 에이전트가 고치는 중이라 import하지 않고 복사했다(경주·강릉·제주 전용 부분은 뺐다).
북쪽 생성기 north.py가 쓴다. 계약서 §8. 결정적(장소별 고정 seed).
"""
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
os.environ.setdefault("EAST_TMP", os.path.join(HERE, ".north_tmp"))
import east_terrain as ET  # noqa: E402
import east_place as EP  # noqa: E402
EP.DEFAULT_RULES["xmin"] = -1e9
from east_place import Placer, Local, Rect, bkey, l2w, ry_along, ry_cross, clamp_ry, wrap_half  # noqa: E402
import east_village as EV  # noqa: E402
import east as E  # noqa: E402
import town_profile as PR  # noqa: E402
import north_profiles as NP  # noqa: E402
from east_terrain import polyline_at, polyline_len, polyline_project  # noqa: E402
import numpy as np  # noqa: E402

P = E.P
ROOT = ET.ROOT


# ================================================================ 속도(2026-10-04 §8): 결과는 그대로, 계산만 빠르게
# east_*.py는 다른 생성기도 쓰므로 파일은 고치지 않고, 북쪽 생성기 프로세스 안에서만 갈아 끼운다.
# 모두 원래 식과 같은 순서·같은 자료형(높이는 float32)으로 셈 → 같은 값(무작위 점 비교·배치 결과 비교로 확인, 보고서 §8).
def _sub_dist(A, B, P_):
    """east_place.Local._dist와 같은 식(선분 일부만)."""
    AB = B - A
    L2 = (AB ** 2).sum(1)
    L2[L2 == 0] = 1e-9
    AP = P_[:, None, :] - A[None, :, :]
    t = np.clip((AP * AB[None]).sum(2) / L2[None], 0, 1)
    C = A[None] + AB[None] * t[..., None]
    d = np.sqrt(((C - P_[:, None, :]) ** 2).sum(2))
    return d, C


def _local_min(self, which, P_, adj):
    """점마다 min_k(d_k − adj_k)와 그 선분 번호(전체 기준) — 가지치기:
    lb_k = (점 묶음 상자 ↔ 선분 상자 거리) − adj_k ≤ 모든 점의 d_k − adj_k. 가장 작은 lb의 선분 k0로 U = max_p(v_p,k0)를 잡으면
    lb_k > U인 선분은 어느 점의 최솟값도 될 수 없다. 남은 선분만 원래 식으로 센다(번호순이라 첫 최소 번호도 같다)."""
    A, B, W, I = getattr(self, which)
    c = self.__dict__.setdefault("_nb_box", {})
    if which not in c:
        c[which] = (np.minimum(A[:, 0], B[:, 0]), np.maximum(A[:, 0], B[:, 0]), np.minimum(A[:, 1], B[:, 1]), np.maximum(A[:, 1], B[:, 1]))
    sx0, sx1, sz0, sz1 = c[which]
    qx0, qx1 = P_[:, 0].min(), P_[:, 0].max()
    qz0, qz1 = P_[:, 1].min(), P_[:, 1].max()
    dx = np.maximum(np.maximum(sx0 - qx1, qx0 - sx1), 0.0)
    dz = np.maximum(np.maximum(sz0 - qz1, qz0 - sz1), 0.0)
    lb = np.hypot(dx, dz) - adj
    k0 = int(np.argmin(lb))
    d0, _ = _sub_dist(A[k0:k0 + 1], B[k0:k0 + 1], P_)
    U = float((d0[:, 0] - adj[k0]).max())
    idx = np.nonzero(lb <= U + 1e-6)[0]
    d, _ = _sub_dist(A[idx], B[idx], P_)
    v = d - adj[idx][None]
    k = v.argmin(1)
    return v[np.arange(len(P_)), k], idx[k]


def _adj(self, which, kind):
    c = self.__dict__.setdefault("_nb_adj", {})
    key = (which, kind)
    if key not in c:
        W = getattr(self, which)[2]
        c[key] = np.maximum(W / 2, 2.6) if kind == "river" else (W / 2 if kind == "road" else np.zeros(len(W)))
    return c[key]


def _river_clear(self, pts):
    P_ = np.asarray(pts, float)
    if len(self.rv[0]) == 0:
        return np.full(len(P_), 1e9)
    return _local_min(self, "rv", P_, _adj(self, "rv", "river"))[0]


def _road_clear(self, pts):
    P_ = np.asarray(pts, float)
    if len(self.rd[0]) == 0:
        return np.full(len(P_), 1e9)
    return _local_min(self, "rd", P_, _adj(self, "rd", "road"))[0]


def _nearest(self, which, kind, x, z):
    A, B, W, I = getattr(self, which)
    if len(A) == 0:
        return None
    P_ = np.array([[x, z]], float)
    _, k = _local_min(self, which, P_, _adj(self, which, kind))
    k = int(k[0])
    d, C = _sub_dist(A[k:k + 1], B[k:k + 1], P_)
    ab = B[k] - A[k]
    L = float(np.hypot(*ab)) or 1.0
    dist = float(d[0, 0] - W[k] / 2) if kind == "road" else float(d[0, 0])
    return dist, float(W[k]), I[k], (ab[0] / L, ab[1] / L), (float(C[0, 0, 0]), float(C[0, 0, 1]))


def _local_init(self, T, cx, cz, R):
    """east_place.Local.__init__와 같은 값 — 길 1m 표본만 배열로."""
    self.T = T
    self.rv = self._filter(T._river_segs, cx, cz, R + 150)
    self.rd = self._filter(T._road_segs, cx, cz, R + 150)
    A, B, W, I = self.rd
    parts = []
    for p, q in zip(A, B):
        n = max(1, int(np.hypot(*(q - p))))
        k = np.arange(n + 1, dtype=float)[:, None]
        parts.append(p + (q - p) * k / n)
    self.road_pts = np.concatenate(parts) if parts else np.zeros((0, 2))
    pts = []
    for r in T.rivers:
        for p in r["points"]:
            if abs(p[0] - cx) < R + 150 and abs(p[1] - cz) < R + 150:
                pts.append((p[0], p[1], p[2], r["id"]))
    self.rpts = pts


_ORIG_LOCAL = {k: getattr(EP.Local, k) for k in ("river_clear", "road_clear", "nearest_road", "nearest_river")}
EP.Local.__init__ = _local_init
EP.Local.river_clear = _river_clear
EP.Local.road_clear = _road_clear
EP.Local.nearest_road = lambda self, x, z: _nearest(self, "rd", "road", x, z)
EP.Local.nearest_river = lambda self, x, z: _nearest(self, "rv", "none", x, z)


def heights(T, pts, f32=True):
    """T.height를 점 여러 개에 — 같은 식. T.height는 x가 파이썬 float이면 float32로, numpy float이면 float64로 셈한다
    (float32 스칼라 × 파이썬 float = float32) — f32로 그 차이까지 따라 한다."""
    h = T.hm
    P_ = np.asarray(pts, float).reshape(-1, 2)
    fx = (P_[:, 0] - h["x0"]) / h["cell"]; fz = (P_[:, 1] - h["z0"]) / h["cell"]
    i = np.minimum(np.maximum(np.floor(fx).astype(int), 0), h["w"] - 2)
    j = np.minimum(np.maximum(np.floor(fz).astype(int), 0), h["h"] - 2)
    tx = fx - i; tz = fz - j
    H = T.H
    if f32:
        a, b = (1 - tx).astype(np.float32), tx.astype(np.float32)
        c, e = (1 - tz).astype(np.float32), tz.astype(np.float32)
    else:
        a, b, c, e = 1 - tx, tx, 1 - tz, tz
    return ((H[j, i] * a + H[j, i + 1] * b) * c + (H[j + 1, i] * a + H[j + 1, i + 1] * b) * e).astype(np.float64)


def landuses(T, pts):
    l = T.lm
    P_ = np.asarray(pts, float).reshape(-1, 2)
    i = np.minimum(np.maximum(np.rint((P_[:, 0] - l["x0"]) / l["cell"]).astype(int), 0), l["w"] - 1)
    j = np.minimum(np.maximum(np.rint((P_[:, 1] - l["z0"]) / l["cell"]).astype(int), 0), l["h"] - 1)
    return T.L[j, i]


def rect_samples(r, step=2.0):
    """Rect.samples와 같은 점·같은 순서(배열)."""
    nx = max(2, int(math.ceil(2 * r.hx / step)) + 1)
    nz = max(2, int(math.ceil(2 * r.hz / step)) + 1)
    a = -r.hx + 2 * r.hx * np.arange(nx) / (nx - 1)
    b = -r.hz + 2 * r.hz * np.arange(nz) / (nz - 1)
    A_, B_ = np.repeat(a, nz), np.tile(b, nx)
    return np.stack([r.cx + r.ux * A_ + r.vx * B_, r.cz + r.uz * A_ + r.vz * B_], 1)


_ORIG_MASK = EV._mask_frac


def _mask_frac_fast(T, x, z, ry, box, lu_ok=(6,)):
    smp = rect_samples(Rect(x, z, ry, box), 3.0)
    lm = T.lm
    i = np.rint((smp[:, 0] - lm["x0"]) / lm["cell"]).astype(int); j = np.rint((smp[:, 1] - lm["z0"]) / lm["cell"]).astype(int)
    m = (j >= 0) & (j < T.L.shape[0]) & (i >= 0) & (i < T.L.shape[1])
    n = int(np.isin(T.L[j[m], i[m]], lu_ok).sum())
    return n / len(smp)


EV._mask_frac = _mask_frac_fast


class NorthPlacer(Placer):
    """east_place.Placer + 32m 버킷 공간 해시(겹침 검사가 항목 수에 비례하지 않게 — 한양은 수천 개)."""
    prefix = "nb"
    B = 32.0

    def __init__(self, *a, **k):
        super().__init__(*a, **k)
        self.buckets = {}
        self._nidx = 0
        self.urban = []           # 도시 땅 사각형(placement urban)
        self.lane_local = {}      # 골목 id → (틀, xa, xb, z) — lane_rows가 돌린 틀에서 집을 줄 세운다

    def _index(self):
        while self._nidx < len(self.rects):
            o, _ = self.rects[self._nidx]
            r = math.hypot(o.hx, o.hz)
            for bx in range(int(math.floor((o.cx - r) / self.B)), int(math.floor((o.cx + r) / self.B)) + 1):
                for bz in range(int(math.floor((o.cz - r) / self.B)), int(math.floor((o.cz + r) / self.B)) + 1):
                    self.buckets.setdefault((bx, bz), []).append(self._nidx)
            self._nidx += 1

    def near_rects(self, x, z, r):
        self._index()
        seen = set()
        out = []
        for bx in range(int(math.floor((x - r) / self.B)), int(math.floor((x + r) / self.B)) + 1):
            for bz in range(int(math.floor((z - r) / self.B)), int(math.floor((z + r) / self.B)) + 1):
                for i in self.buckets.get((bx, bz), ()):
                    if i not in seen:
                        seen.add(i)
                        out.append(self.rects[i])
        return out

    def check(self, L, pieces, x, z, ry, rules, ignore_overlap=False):
        """east_place.Placer.check와 같은 판정(같은 순서): 표본 점을 배열로 한 번에, 겹침은 가까운 버킷만."""
        R = dict(EP.DEFAULT_RULES)
        R.update(rules or {})
        allpts = []
        rects = []
        lu_bad = np.asarray(R["lu_bad"], int) if len(R["lu_bad"]) else np.zeros(0, int)
        bigs = []
        for kit, params, lx, lz, lry, fl in pieces:
            wx, wz = l2w(x, z, ry, lx, lz)
            bb = self.aabb(kit, params, fl)
            rect = Rect(wx, wz, ry + lry, bb)
            rects.append((rect, fl))
            if fl.get("tree") and self.in_cam_corridor(L, wx, wz, fl.get("tree_dx", 5.0)):
                return False, 0, "cam_corridor"
            if fl.get("nocheck") or fl.get("inner"):
                continue
            pts = rect_samples(rect, 2.0)
            if fl.get("ground", True):
                allpts.append(pts)
            if pts[:, 0].min() < R["xmin"]:
                return False, 0, "xmin"
            rc = L.river_clear(pts)
            if rc.min() < fl.get("river_min", R["river_min"]):
                return False, 0, "river"
            if "river_max" in fl and rc.min() > fl["river_max"]:
                return False, 0, "river_far"
            dc = L.road_clear(pts)
            if dc.min() < fl.get("road_min", R["road_min"]):
                return False, 0, "road"
            lus = landuses(self.T, pts)
            bad = int(np.isin(lus, lu_bad).sum()) / len(lus)
            if bad > R["lu_bad_frac"] or (fl.get("no_water", True) and bool((lus == 5).any())):
                return False, 0, "landuse"
            bigs.append(Rect(wx, wz, ry + lry, bb, fl.get("margin", R["margin"])))
        if allpts:
            hs = heights(self.T, np.concatenate(allpts), f32=not isinstance(x, np.generic))
            drop = float(hs.max() - hs.min())
            if drop > R["max_drop"]:
                return False, drop, "drop"
        else:
            drop = 0.0
        if not ignore_overlap:
            for big in bigs:
                rr = math.hypot(big.hx, big.hz) + 2.0
                for o, _ in self.near_rects(big.cx, big.cz, rr):
                    if big.overlaps(o):
                        return False, 0, "overlap"
        return True, drop, rects

    def new_id(self, grp, kind):
        k = (grp, kind)
        self.counter[k] = self.counter.get(k, 0) + 1
        return f"{self.prefix}_{grp}_{kind}_{self.counter[k]:02d}"


class CStyle(PR.Style):
    def __init__(self, sid, prof):
        roof = dict(prof.get("roof") or {"choga": 1.0})
        plan = PR.PLAN_BY_CLIMATE.get(prof.get("climate", "central"), "giyeok")
        super().__init__(sid, roof, prof.get("wall", "todam"), prof.get("layout", "rows"), plan, prof.get("archetype", "plain"))
        self.culture = prof.get("culture")
        self.climate = prof.get("climate")
        self.district = prof.get("district")


def style(T, rid, sid):
    s = next((x for x in T.region["settlements"] if x["id"] == sid), {"id": sid})
    return CStyle(sid, NP.profile_for(rid, s))


def style_of(rid, prof_key, **over):
    base = dict(NP.PROFILES[rid].get(prof_key) or NP.AUTO[rid])
    base.update(over)
    return CStyle(prof_key, base)


# ================================================================ 공용 도우미 (hubs.py에서 옮김)
def wall_pieces(pts, closed, gaps, seed, h=2.2, seg=12.0):
    """kit/landmark/_common.gd wall_pieces() 옮김(namwon.py와 같음)."""
    out = []
    n = len(pts)
    m = n if closed else n - 1
    k = 0
    for i in range(m):
        a = pts[i]; b = pts[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        dx, dz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        cuts = []
        for g in gaps:
            t = (g[0] - a[0]) * dx + (g[1] - a[1]) * dz
            off = abs((g[0] - a[0]) * dz - (g[1] - a[1]) * dx)
            if off < 1.0 and 0 < t < L:
                cuts.append((t - g[2], t + g[2]))
        cuts.sort()
        spans = []
        s0 = 0.0
        for c in cuts:
            if c[0] > s0 + 0.3:
                spans.append((s0, c[0]))
            s0 = c[1]
        if L > s0 + 0.3:
            spans.append((s0, L))
        for (p0, p1) in spans:
            sl = p1 - p0
            ns = max(1, math.ceil(sl / seg))
            for j in range(ns):
                t0 = p0 + sl * j / ns; t1 = p0 + sl * (j + 1) / ns
                out.append({"params": {"seed": seed + k, "length": round(t1 - t0 + 0.25, 2), "height": h},
                            "x": a[0] + dx * (t0 + t1) / 2, "z": a[1] + dz * (t0 + t1) / 2, "ry": -math.atan2(dz, dx)})
                k += 1
    return out


def court(seed, x0, x1, z0, z1, gaps, h=2.2, kit="landmark/gwana_wall", sides=(True, True, True, True)):
    """담 둘레(로컬 좌표) 조각들 + 담 안 reserve. sides = (북, 동, 남, 서)."""
    pcs = []
    corners = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    for i, on in enumerate(sides):
        if not on:
            continue
        a, b = corners[i], corners[(i + 1) % 4]
        for w in wall_pieces([a, b], False, gaps, seed + i * 10, h):
            ln = w["params"]["length"]
            pcs.append(P(kit, w["params"], w["x"], w["z"], w["ry"], cat="wall", kind="wall", aabb=[-ln / 2, ln / 2, -0.55, 0.55],
                         margin=0.1, flatten=False, nocheck=True))
    pcs.append(P("reserve", {}, reserve=True, aabb=[x0, x1, z0, z1], margin=0.0))
    return pcs


def put(pl, pcs, x, z, ry, g, gc, R=0.0, rules=None, seed=1, n=400, force=True, road_pref=(0.5, 40.0)):
    """정해진 자리(가까이 R 안에서 찾기 → 안 되면 그 자리에 강제)."""
    T = pl.T
    L = Local(T, x, z, max(R, 40) + 100)
    if R > 0:
        r = pl.place_search(L, pcs, x, z, R, g, gc, random.Random(seed), rules, ry_fixed=ry, n=n, road_pref=road_pref,
                            north_bias=0.0, pref=(x, z))
        if r:
            return r
    return pl.place_fixed(L, pcs, x, z, ry, g, gc, rules, force=force)


def search(pl, pcs, x, z, R, g, gc, seed, rules=None, face="road", n=400, road_pref=(1.0, 8.0), ry=None):
    L = Local(pl.T, x, z, R + 100)
    return pl.place_search(L, pcs, x, z, R, g, gc, random.Random(seed), rules or {"max_drop": 3.0}, face=face, n=n,
                           road_pref=road_pref, ry_fixed=ry)


def lmk(T, lid):
    return next(l for l in T.region["landmarks"] if l["id"] == lid)


def stl(T, sid):
    return next(s for s in T.region["settlements"] if s["id"] == sid)


def rect_cells(T, x0, z0, x1, z1, lu=(6,)):
    lm = T.lm
    i0 = int((x0 - lm["x0"]) / lm["cell"]); i1 = int((x1 - lm["x0"]) / lm["cell"]) + 1
    j0 = int((z0 - lm["z0"]) / lm["cell"]); j1 = int((z1 - lm["z0"]) / lm["cell"]) + 1
    sub = T.L[j0:j1, i0:i1]
    jj, ii = np.nonzero(np.isin(sub, lu))
    return np.stack([lm["x0"] + (ii + i0) * lm["cell"], lm["z0"] + (jj + j0) * lm["cell"]], 1).astype(float)


def seonghwang(pl, x, z, g, gc, seed, R=24, dangjip=False, rules=None):
    """고개·어귀 성황당: 돌무더기 + 신목(느티)."""
    shp = {"seed": seed, "tree": False}
    if dangjip:
        shp["dangjip"] = True
    anc = pl.bounds.get(bkey("village/seonghwangdang", shp), {}).get("anchors", {}).get("tree", [0, 0, -1.2])
    pcs = [P("village/seonghwangdang", shp, cat="shrine", kind="seonghwangdang", label="성황당", road_min=0.8),
           P("nature/big_tree", {"seed": seed + 1, "variant": "zelkova", "h": 8.0, "spread": 5.0}, anc[0], anc[2], cat="prop",
             kind="sinmok", aabb=[-1.2, 1.2, -1.2, 1.2], flatten=False, nocheck=True, tree=True)]
    L = Local(pl.T, x, z, R + 80)
    r = pl.place_search(L, pcs, x, z - 6, R, g, gc, random.Random(seed), rules or {"max_drop": 3.0}, road_pref=(0.8, 7.0),
                        pref=(x, z - 6), north_bias=0.0)
    if not r:
        r = pl.place_search(L, pcs[:1], x, z, R, g, gc, random.Random(seed + 1), rules or {"max_drop": 3.5}, road_pref=(0.8, 9.0))
    return r


def jumak_c(seed, cul):
    """주막 — 문화권 집 모양으로(탐라 돌집·관동 너와), 나머지는 village/jumak."""
    if cul == "tamna":
        return [P("culture/tamna/stone_house", {"seed": seed, "kind": "an"}, 0.0, -1.5, cat="jumak", kind="jumak", label="주막",
                  aabb=[-6.2, 6.2, -5.4, 2.4], margin=0.6),
                P("village/props", {"seed": seed, "kind": "pyeongsang"}, -2.4, 3.6, cat="prop", kind="pyeongsang", flatten=False,
                  margin=0.3, road_min=0.4),
                P("village/props", {"seed": seed + 1, "kind": "yongsu"}, 4.8, 3.2, cat="prop", kind="yongsu", flatten=False, margin=0.2,
                  road_min=0.3),
                P("village/props", {"seed": seed + 2, "kind": "gamasot"}, 1.4, 3.6, cat="prop", kind="gamasot", flatten=False,
                  margin=0.2, road_min=0.4)]
    if cul == "gwandong_mt":
        return [P("village/neowa_house", {"seed": seed, "plan": "il"}, 0.0, -1.5, cat="jumak", kind="jumak", label="주막",
                  aabb=[-4.8, 4.8, -5.0, 2.2], margin=0.6),
                P("village/props", {"seed": seed, "kind": "pyeongsang"}, -2.2, 3.4, cat="prop", kind="pyeongsang", flatten=False,
                  margin=0.3, road_min=0.4),
                P("village/props", {"seed": seed + 1, "kind": "yongsu"}, 4.2, 3.0, cat="prop", kind="yongsu", flatten=False, margin=0.2,
                  road_min=0.3),
                P("village/firewood", {"seed": seed, "style": "stack"}, -5.8, 0.6, cat="prop", flatten=False, margin=0.3)]
    return [P("village/jumak", {"seed": seed}, cat="jumak", kind="jumak", label="주막")]


def bulteok(seed):
    """해녀 불턱 — 바닷가 현무암 둥근 담(옷 갈아입고 불 쬐는 자리)."""
    pts = []
    for k in range(9):
        a = math.pi * 0.15 + k / 8 * math.pi * 1.7
        pts.append([round(math.cos(a) * 2.6, 2), round(math.sin(a) * 2.2, 2)])
    return [P("culture/tamna/doldam", {"seed": seed, "points": pts, "h": 1.1, "lite": False}, cat="prop", kind="bulteok",
              label="불턱", aabb=[-3.2, 3.2, -2.8, 2.8], margin=0.4, flatten=False, river_min=0.0)]


def mulbtong(seed):
    """용천수 물통 — 돌담으로 둘러친 샘(남탕·여탕) + 빨래터."""
    pts_a = [[-4.0, 1.6], [-4.0, -2.0], [-0.3, -2.0], [-0.3, 1.6]]
    pts_b = [[0.3, 1.6], [0.3, -2.0], [4.0, -2.0], [4.0, 1.6]]
    return [P("culture/tamna/doldam", {"seed": seed, "points": pts_a, "h": 1.4, "lite": False}, cat="prop", kind="mulbtong",
              label="용천수 물통", aabb=[-4.4, 4.4, -2.4, 2.2], margin=0.4, flatten=True, river_min=0.0),
            P("culture/tamna/doldam", {"seed": seed + 1, "points": pts_b, "h": 1.4, "lite": False}, cat="prop", kind="mulbtong",
              inner=True, flatten=False),
            P("village/ppallaeteo", {"seed": seed}, -2.1, 0.0, cat="prop", kind="ppallaeteo", inner=True, flatten=False),
            P("village/well", {"seed": seed, "roof": False}, 2.1, -0.2, cat="prop", kind="spring", inner=True, flatten=False)]


def boats(pl, x, z, g, gc, seed, n=3, R=40):
    """물가 배: 가까운 물(하천·바다) 가장자리에 나룻배 n척(원점 = 수면, 로더가 y를 수면으로)."""
    T = pl.T
    lm = T.lm
    got = 0
    rng = random.Random(seed)
    cand = []
    for _ in range(600):
        a = rng.uniform(0, 2 * math.pi); r = R * math.sqrt(rng.uniform(0, 1))
        px, pz = x + r * math.cos(a), z + r * math.sin(a)
        if T.landuse(px, pz) != 5:
            continue
        # 물 가장자리 4~9m 안(뭍 칸이 가까운 곳)
        near = any(T.landuse(px + dx, pz + dz) != 5 for dx, dz in [(6, 0), (-6, 0), (0, 6), (0, -6)])
        if near:
            cand.append((math.hypot(px - x, pz - z), px, pz))
    cand.sort()
    placed = []
    for _, px, pz in cand:
        if got >= n:
            break
        if any(math.hypot(px - qx, pz - qz) < 7 for qx, qz in placed):
            continue
        ry = rng.uniform(-0.5, 0.5)
        pl.commit([P("village/narutbae", {"seed": seed + got}, cat="bridge", kind="narutbae", flatten=False, nocheck=True, clear_veg=False,
                     y=0.0 if T.region.get("sea") and T.height(px, pz) < 0.2 else None)], px, pz, ry, g, gc)
        placed.append((px, pz)); got += 1
    return got


def warehouses(pl, x, z, g, gc, seed, n=3, cul=None, R=40):
    """포구 객주·창고(§26): 헛간(창고) 줄 + 가가."""
    out = 0
    for k in range(n):
        if cul == "tamna":
            pcs = [P("culture/chae", {"seed": seed + k, "l": 9.0, "d": 4.4, "bays": "bkkb", "roof": "tti", "wall": "basalt", "F": 0.3,
                                      "rope": 0.55, "rise_k": 0.42}, cat="house", kind="changgo", label="객주 창고")]
        else:
            pcs = [P("village/heotgan", {"seed": seed + k, "w": 6.0, "d": 4.0, "walls": "three"}, cat="house", kind="changgo",
                     label="객주 창고")]
        if search(pl, pcs, x, z, R, g, gc, seed + k * 7, {"max_drop": 2.4, "river_min": 0.5}, road_pref=(0.8, 10.0)):
            out += 1
    return out


def bridges(pl, T, gc_map=None):
    """권역 도강점 전부: 돌다리·섶다리·징검다리(여울은 디딤돌), 나루는 나룻배 + 횃대(§25 나머지는 장소별)."""
    done = []
    for c in T.region["crossings"]:
        kit = E.crossing_kit(T, c)
        if any(math.hypot(c["x"] - d[0], c["z"] - d[1]) < 9 for d in done):
            continue
        L = Local(T, c["x"], c["z"], 40)
        if c["type"] == "나루":
            boats(pl, c["x"], c["z"], "나루", "naru", 600 + len(done), n=2, R=30)
            done.append((c["x"], c["z"]))
            continue
        if not kit:
            continue
        rd = T.road(c["road_id"])
        s, _ = polyline_project(rd["points"], c["x"], c["z"])
        x1, z1, _ = polyline_at(rd["points"], max(0, s - 6))
        x2, z2, _ = polyline_at(rd["points"], s + 6)
        dx, dz = x2 - x1, z2 - z1
        n = math.hypot(dx, dz) or 1
        dx, dz = dx / n, dz / n
        wy = L.water_y(c["x"], c["z"], c["river_id"])
        nr = L.nearest_river(c["x"], c["z"])
        rdx, rdz = nr[3] if nr else (1, 0)
        nx, nz = -rdz, rdx
        if nx * dx + nz * dz < 0:
            nx, nz = -nx, -nz
        jg = kit == "village/jingeom"
        base = math.atan2(nz, nx)
        road_a = math.atan2(dz, dx)
        best = None
        cands = [road_a, base] + [base + math.radians(d_) for d_ in range(-60, 61, 15)]
        for k, ang in enumerate(cands):
            ddx, ddz = math.cos(ang), math.sin(ang)
            tA, tB, y, step = E.fit_span(T, L, c["x"], c["z"], ddx, ddz, wy, jg)
            score = step * 4 + (tB - tA) * 0.08 + (0 if k == 0 else 0.15)
            if best is None or score < best[0]:
                best = (score, ddx, ddz, tA, tB, y, step)
        _, dx, dz, tA, tB, y, step = best
        ln = round(min(max(tB - tA, 4.0), 38.0), 1)
        tm = (tA + tB) / 2
        bx, bz = c["x"] + dx * tm, c["z"] + dz * tm
        if jg:
            params = {"seed": 21 + len(done), "len": ln}
        elif kit == "village/seop_bridge":
            params = {"seed": 31 + len(done), "len": ln, "spans": max(3, int(ln / 2.6))}
        else:
            params = {"seed": 41 + len(done), "len": ln, "hw": 1.3}
        label = {"village/seop_bridge": "섶다리", "village/stone_bridge": "돌다리", "village/jingeom": "징검다리"}[kit]
        pl.commit([P(kit, params, cat="bridge", kind=kit.split("/")[-1], flatten=False, nocheck=True, y=round(y, 2), label=label,
                     id=f"{pl.prefix}_br_{c['id']}")], bx, bz, ry_cross(dx, dz), "다리·징검다리(도강점)", "br")
        done.append((c["x"], c["z"]))


def gate_c(pl, T, road, s, g, gc, seed, cul, sotdae=True):
    """마을 어귀: 영남·관동은 장승(+솟대), 탐라는 방사탑 둘(길 양쪽)."""
    L = Local(T, *polyline_at(T.road(road)["points"], s)[:2], 60)
    if cul != "tamna":
        return E.gate_props(pl, T, L, road, s, g, gc, random.Random(seed), sotdae=sotdae, quiet=True)
    pts = T.road(road)["points"]
    w = T.road(road)["width_m"]
    for ds in [0, 4, -4, 8, -8, 12, -12, 16, -16]:
        x, z, d = polyline_at(pts, s + ds)
        nx, nz = -d[1], d[0]
        off = w / 2 + 2.8
        a = [P("landmark/jj_bangsatap", {"seed": seed}, cat="prop", kind="bangsatap", label="방사탑", margin=0.3, road_min=0.3)]
        b = [P("landmark/jj_bangsatap", {"seed": seed + 1}, cat="prop", kind="bangsatap", margin=0.3, road_min=0.3)]
        if pl.check(L, a, x + nx * off, z + nz * off, 0.0, {"max_drop": 2.0})[0] and pl.check(L, b, x - nx * off, z - nz * off, 0.0, {"max_drop": 2.0})[0]:
            return pl.commit(a, x + nx * off, z + nz * off, 0.0, g, gc) + pl.commit(b, x - nx * off, z - nz * off, 0.0, g, gc)
    return []


def village_c(pl, T, rid, sid, g, gc, mix, seed, road=None, toward=None, limit=999, square=True, wells=1, street=None,
              center=None, max_drop=2.6, extra_ids=(), cells=None):
    """문화권 마을: east.village2(짜임·어귀·마당·우물) + 성격표 문화권 집. 탐라 어귀는 방사탑."""
    st = style(T, rid, sid)
    if st.culture == "tamna" and road and toward:
        s_ = stl(T, sid)
        e = E.entrance(T, road, s_["x"], s_["z"], min(70, s_.get("radius_m", 40)), toward)
        if e:
            gate_c(pl, T, road, e[1], g, gc, seed, "tamna")
        road_, toward_ = None, None
    else:
        road_, toward_ = road, toward
    return E.village2(pl, T, sid, g, gc, mix, seed, road=road_, toward=toward_, square=square, wells=wells, limit=limit, style=st,
                      street=street, center=center, max_drop=max_drop, extra_ids=extra_ids, cells=cells, stats=pl.stats_)


def tree(variant, seed, lx=0.0, lz=0.0, **kw):
    p = {"seed": seed, "variant": variant}
    p.update(kw)
    return P("nature/big_tree", p, lx, lz, cat="prop", kind="tree_" + variant, aabb=[-1.2, 1.2, -1.2, 1.2], flatten=False,
             margin=0.6, river_min=1.0, tree=True)


def scatter_props(pl, x, z, R, g, gc, seed, kit, params_fn, n, rules=None, face="none", aabb=None):
    got = 0
    for k in range(n * 3):
        if got >= n:
            break
        pcs = [P(kit, params_fn(k), cat="prop", kind=kit.split("/")[-1], flatten=False, margin=0.5, aabb=aabb, nocheck=False)]
        if search(pl, pcs, x, z, R, g, gc, seed + k * 13, rules or {"max_drop": 4.0}, face=face, n=80):
            got += 1
    return got


def ritual(pl, T, kit, params, fp, x, z, g, gc, seed, label, R=60):
    """읍치 제의 시설: 사직단(서)·여단(북)·성황사(진산 기슭) — 원칙 방향의 가설 자리 근처에서 찾는다."""
    pcs = [P(kit, params, cat="landmark", kind=kit.split("/")[1], label=label, footprint=fp, road_min=0.3)]
    if kit.endswith("seonghwangsa"):
        anc = pl.bounds.get(bkey(kit, params), {}).get("anchors", {}).get("tree")
        if anc:
            pcs.append(P("nature/big_tree", {"seed": seed + 1, "variant": "zelkova"}, anc[0], anc[2], cat="prop", kind="sinmok",
                         aabb=[-1.2, 1.2, -1.2, 1.2], flatten=False, nocheck=True))
    L = Local(T, x, z, R + 100)
    r = pl.place_search(L, pcs, x, z, R, g, gc, random.Random(seed), {"max_drop": 3.5, "lu_bad": (5, 6, 7)}, n=600,
                        road_pref=(0.5, 60.0), north_bias=0.0, ry_fixed=0.0, pref=(x, z))
    if r:
        r[0]["_label"] = label
    return r


# ================================================================ 읍성(성벽 둘레)
def eupseong(pl, T, cx, cz, hx, hz, gates, wall_kit, wall_thick, gate_fn, g, gc, seed, corner=True, chi=True, gate_w=18.0,
             river_gap=True):
    """방형(직사각) 읍성: 네 변 성벽 조각 + 성문 + 모서리 + 치. gates = {"S": name, ...}.
    하천이 성벽 선을 지나면 그 자리는 수구(水口)로 비운다."""
    side = {"S": (0.0, hx, hz), "E": (math.pi / 2, hz, hx), "N": (math.pi, hx, hz), "W": (-math.pi / 2, hz, hx)}
    Lw = Local(T, cx, cz, max(hx, hz) + 60)
    n_wall = 0
    for sd, (ry, half_a, half_o) in side.items():
        zc = half_o - wall_thick / 2
        if sd in gates:
            gx, gz = l2w(cx, cz, ry, 0.0, zc)
            pl.commit([P(*gate_fn(sd, gates[sd]), cat="landmark", kind="seongmun", label=gates[sd], flatten=False, nocheck=True,
                         id=f"{pl.prefix}_eupseong_gate_{sd}")], gx, gz, ry, g, gc)
            # 문 안·밖 광장
            for lz, w_, d_ in ((zc - wall_thick / 2 - 7.0, 16.0, 12.0), (zc + wall_thick / 2 + 7.0, 18.0, 12.0)):
                qx, qz = l2w(cx, cz, ry, 0.0, lz)
                pl.commit([P("reserve", {}, reserve=True, aabb=[-w_ / 2, w_ / 2, -d_ / 2, d_ / 2])], qx, qz, ry, g, gc)
        if corner:
            ux, uz = l2w(cx, cz, ry, half_a - wall_thick / 2, zc)
            if wall_kit == "landmark/seong_wall":
                pl.commit([P("landmark/seong_corner", {"seed": seed}, cat="wall", kind="corner", flatten=False, nocheck=True)], ux, uz, ry,
                          g, gc)
        g0, g1 = -half_a + wall_thick, half_a - (0.0 if wall_kit != "landmark/seong_wall" else wall_thick)
        if wall_kit != "landmark/seong_wall":
            g0, g1 = -half_a, half_a
        cuts = []
        if sd in gates:
            cuts.append((-gate_w / 2, gate_w / 2))
        # 수구: 하천이 지나는 자리
        if river_gap:
            u = g0
            while u < g1:
                wx, wz = l2w(cx, cz, ry, u, zc)
                if Lw.river_clear([(wx, wz)])[0] < 0.5:
                    cuts.append((u - 2.5, u + 2.5))
                u += 1.0
        cuts.sort()
        merged = []
        for c in cuts:
            if merged and c[0] <= merged[-1][1] + 1.0:
                merged[-1] = (merged[-1][0], max(merged[-1][1], c[1]))
            else:
                merged.append(c)
        spans = []
        s0 = g0
        for c in merged:
            if c[0] - s0 > 1.0:
                spans.append((s0, c[0]))
            s0 = max(s0, c[1])
        if g1 - s0 > 1.0:
            spans.append((s0, g1))
        for (a, b) in spans:
            L_ = b - a
            nseg = max(1, math.ceil(L_ / 20.0))
            for i in range(nseg):
                s_a = a + L_ * i / nseg; s_b = a + L_ * (i + 1) / nseg
                ln = round(s_b - s_a + (0.0 if wall_kit == "landmark/seong_wall" else 0.3), 2)
                wx, wz = l2w(cx, cz, ry, (s_a + s_b) / 2, zc)
                pl.commit([P(wall_kit, {"seed": seed + n_wall, "length": ln}, cat="wall", kind="seong_wall", flatten=False,
                             nocheck=True, aabb=[-ln / 2, ln / 2, -wall_thick / 2, wall_thick / 2 + 0.4])], wx, wz, ry, g, gc)
                n_wall += 1
        if chi:
            for u in (-half_a / 2, half_a / 2):
                if abs(u) < gate_w and sd in gates:
                    continue
                wx, wz = l2w(cx, cz, ry, u, half_o)
                if Lw.river_clear([(wx, wz)])[0] < 3.0:
                    continue
                pl.commit([P("landmark/seong_chi", {"seed": seed + 90, "width": 8, "depth": 6}, cat="wall", kind="chi", flatten=False,
                             nocheck=True)], wx, wz, ry, g, gc)
        # 성벽 안 순성로(3m)·밖 해자 자리(8m)는 집을 들이지 않는다
        for lz, d_ in ((zc - wall_thick / 2 - 1.5, 3.0), (zc + wall_thick / 2 + 4.0, 8.0)):
            qx, qz = l2w(cx, cz, ry, 0.0, lz)
            pl.commit([P("reserve", {}, reserve=True, aabb=[-half_a, half_a, -d_ / 2, d_ / 2])], qx, qz, ry, g, gc)
    return n_wall


def nearest_road_id(T, s):
    best = None
    for rd in T.roads:
        for p in rd["points"]:
            d = math.hypot(p[0] - s["x"], p[1] - s["z"])
            if best is None or d < best[0]:
                best = (d, rd["id"])
    return best[1] if best and best[0] < 80 else None


def sea_spot(T, x, z, R=260):
    """(x,z) 둘레에서 가장 가까운 바닷가 물 칸(물 가장자리 3~10m 안)."""
    best = None
    for r in range(0, int(R), 4):
        for k in range(max(8, r // 2)):
            a = k / max(8, r // 2) * 2 * math.pi
            px, pz = x + r * math.cos(a), z + r * math.sin(a)
            if T.landuse(px, pz) == 5 and T.height(px, pz) < -0.3:
                if any(T.landuse(px + dx, pz + dz) != 5 for dx, dz in [(10, 0), (-10, 0), (0, 10), (0, -10)]):
                    return px, pz
                if best is None:
                    best = (px, pz)
    return best or (x, z)


def load_catalog_fp():
    fp = E.load_catalog_fp()
    try:
        c = json.load(open(os.path.join(ROOT, "kit/culture/catalog.json"), encoding="utf-8"))
        for it in c.get("models", []):
            if it.get("footprint"):
                fp["culture/" + it["name"]] = tuple(it["footprint"])
    except Exception:
        pass
    return fp


def count_buildings(pl):
    from collections import Counter
    c = Counter()
    for it in pl.items:
        if it["_cat"] in ("house", "civic", "landmark", "jumak", "market", "shrine") and it["kit"] not in ("reserve",):
            if it["kit"] in ("village/jwapan",) or it["kit"].startswith("nature/"):
                continue
            c[it["group"]] += 1
    return c


