"""논·밭 필지 생성기 — landuse의 논(2)·밭(3) 칸을 진짜 필지 다각형으로 나눈다(docs/reports/parcels.md).

1) 구획(블록): 논·밭 마스크(4m)를 부드러운 거리장으로 바꾸고 길·하천·마을·숲 가장자리에서 띄운다(경계 = 필지 바깥 테두리).
   큰 들은 보로노이 구역(논 110m·밭 90m 안팎)으로 나눠 구역마다 방향을 정한다. 구역 사이는 1.2m 두렁길(풀).
2) 나누기: 평지는 가까운 길·하천 방향에 맞춘 거의 직사각형 필지, 경사지 논은 등고선을 따라 휘는 좁은 다랑이(경사가 급할수록 좁게),
   경사지 밭은 등고선 따라 긴 띠. 필지 = 구역 틀(t: 길이 방향, v: 가로)의 칸을 구획 거리장으로 잘라 낸 다각형.
3) 바닥 높이: 평지 논은 땅보다 0.3m 낮게(둑·길보다 0.3~0.55m 아래), 다랑이는 깎고 메운 평균 높이 → 줄마다 계단.
   밭은 땅을 그대로 따른다(이랑은 엔진이 만든다).
4) 이웃: 변마다 이웃 필지 번호(-1 = 구획 바깥) — 엔진이 둑(같은 높이: 반쪽 둑 둘, 계단: 위 필지가 둑 + 둑 비탈/석축) · 테두리를 만든다.
5) 물꼬: 논마다 위(물 들어오는) 이웃과 맞닿은 변 가운데.
6) 상태: 기후대(climate.png)별 논(물 댄 모·자라는 벼·누렇게 익은 벼·그루터기)·밭 작물. 엔진이 --farmseason으로 덮어쓸 수 있다.

출력(region_data/<id>/ 또는 노정 폴더):
  parcels.bin  — 'PRCL' v1: P float32[n,12] (cx, cz, floor, kind 0논/1밭, level, state, crop, ang(t축 각), style 비트(1 석축·2 현무암 돌담), vstart, vcount, slope)
                 V float32[nv,3] (x, z, 이 꼭짓점→다음 꼭짓점 변의 이웃 필지 번호 또는 -1), I float32[ni,4] 물꼬 (x, z, 위 바닥, 아래 바닥),
                 C int32[nc,4] 64m 칸 색인 (ci, cj, 시작, 개수) — 필지는 중심 칸 순서로 정렬
  farm.png     — 필지 합집합 부호 거리(높이맵과 같은 2m 격자, 8비트: 128 + d·16, 안쪽 음수) — 지형 셰이더가 필지 아래 땅을 내린다
  parcels.json — 요약·메타
실행: python3 tools/region/parcels.py [권역 id | 데이터 폴더 …] [--all] [--routes] [--png]
"""
import json, math, os, struct, sys, time
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.spatial import cKDTree

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
DATA = os.path.join(ROOT, "region_data")
T0 = time.time()
def say(*a): print(f"[{time.time() - T0:6.1f}s]", *a, flush=True)

PADDY, FIELD = 2, 3
GAP = 0.6           # 구획 경계에서 필지까지(m) — 논·밭 사이, 구역 사이 1.2m 두렁길
ROAD_MARGIN = 1.6   # 길 반폭 + 이만큼은 길섶
RIVER_MARGIN = 2.2
ROAD_DIR_R = 110.0
DITCH_W = 0.8       # 길 따라 논 가장자리 도랑 폭  # 이 안의 길 방향에 평지 필지를 맞춘다
CHUNK = 64.0
ZONES = ["south", "central", "north", "alpine", "coast"]
# 논 상태: 0 물 댄 모, 1 자라는 벼, 2 익은 벼, 3 그루터기 / 기후대별 비율(늦여름 기준 — 남쪽은 푸르고 북쪽은 벌써 익거나 거둠)
PADDY_STATE = {"south": [0.22, 0.6, 0.18, 0.0], "central": [0.1, 0.5, 0.35, 0.05], "north": [0.0, 0.15, 0.5, 0.35],
               "alpine": [0.0, 0.2, 0.45, 0.35], "coast": [0.15, 0.55, 0.3, 0.0]}
# 밭 작물: 0 콩, 1 조, 2 보리, 3 배추, 4 고추, 5 묵정(맨흙)
FIELD_CROP = {"south": [0.3, 0.15, 0.05, 0.15, 0.25, 0.1], "central": [0.3, 0.25, 0.05, 0.15, 0.15, 0.1],
              "north": [0.25, 0.4, 0.15, 0.1, 0.0, 0.1], "alpine": [0.2, 0.45, 0.2, 0.05, 0.0, 0.1],
              "coast": [0.2, 0.35, 0.3, 0.05, 0.0, 0.1]}


# ---------------------------------------------------------------------------
# 읽기
# ---------------------------------------------------------------------------
def space_file(d):
    for f in ("region.json", "route.json"):
        if os.path.exists(os.path.join(d, f)): return os.path.join(d, f)
    return None

class Grid:
    """2m(높이) 격자의 배열 하나 + 쌍선형 표본."""
    def __init__(self, a, x0, z0, cell):
        self.a = a; self.x0 = x0; self.z0 = z0; self.cell = cell
        self.h, self.w = a.shape
    def at(self, x, z):
        fi = np.clip((np.asarray(x, float) - self.x0) / self.cell, 0, self.w - 1.001)
        fj = np.clip((np.asarray(z, float) - self.z0) / self.cell, 0, self.h - 1.001)
        i0 = fi.astype(int); j0 = fj.astype(int); u = fi - i0; v = fj - j0
        a = self.a
        return (a[j0, i0] * (1 - u) * (1 - v) + a[j0, i0 + 1] * u * (1 - v) + a[j0 + 1, i0] * (1 - u) * v + a[j0 + 1, i0 + 1] * u * v)

def load_space(d):
    rj = json.load(open(space_file(d), encoding="utf-8"))
    hm = rj["height"]
    im = Image.open(os.path.join(d, hm.get("file", "height.png")))
    raw = np.array(im).astype(np.float64)
    vmax = 65535.0 if raw.max() > 255 or im.mode.startswith("I") else 255.0
    H = (hm["y_min"] + raw / vmax * (hm["y_max"] - hm["y_min"])).astype(np.float32)
    lm = rj.get("landuse", {})
    lu = np.array(Image.open(os.path.join(d, lm.get("file", "landuse.png")))).astype(np.uint8) & 127
    lx0 = float(lm.get("x0", hm["x0"])); lz0 = float(lm.get("z0", hm["z0"]))
    lcell = float(lm.get("cell", hm["cell"] * (H.shape[1] - 1) / max(1, lu.shape[1] - 1)))
    cl = None
    cm = rj.get("climate")
    if isinstance(cm, dict) and os.path.exists(os.path.join(d, cm.get("file", "climate.png"))):
        cl = (np.array(Image.open(os.path.join(d, cm.get("file", "climate.png")))).astype(np.uint8),
              float(cm.get("x0", lx0)), float(cm.get("z0", lz0)), float(cm.get("cell", lcell)))
    return rj, Grid(H, float(hm["x0"]), float(hm["z0"]), float(hm["cell"])), (lu, lx0, lz0, lcell), cl


# ---------------------------------------------------------------------------
# 거리장
# ---------------------------------------------------------------------------
def kind_sdf(lu, lx0, lz0, lcell, kind, G):
    """토지이용 kind 마스크의 부드러운 부호 거리(m, 밖 +) — 2m 격자. 4m 계단을 가우스로 둥글게."""
    m = lu == kind
    if not m.any(): return None
    din = ndimage.distance_transform_edt(m) * lcell - lcell * 0.5
    dout = ndimage.distance_transform_edt(~m) * lcell - lcell * 0.5
    s4 = np.where(m, -din, dout).astype(np.float32)
    s4 = ndimage.gaussian_filter(s4, 1.0)
    xs = G.x0 + np.arange(G.w) * G.cell; zs = G.z0 + np.arange(G.h) * G.cell
    fi = np.clip((xs - lx0) / lcell, 0, lu.shape[1] - 1.001); fj = np.clip((zs - lz0) / lcell, 0, lu.shape[0] - 1.001)
    s2 = ndimage.map_coordinates(s4, np.meshgrid(fj, fi, indexing="ij"), order=1).astype(np.float32)
    return ndimage.gaussian_filter(s2, 1.2)

def line_clear(G, lines, reach=6.0):
    """폴리라인들의 '비워 둘 거리' 장: max(반폭+여유 − 거리). lines = [(pts Nx2, 반폭+여유)]. 바깥은 −reach."""
    out = np.full((G.h, G.w), -reach, np.float32)
    for pts, R in lines:
        pts = np.asarray(pts, float)[:, :2]
        for q in range(len(pts) - 1):
            a = pts[q]; b = pts[q + 1]
            RR = R + reach
            i0 = max(int((min(a[0], b[0]) - RR - G.x0) / G.cell), 0); i1 = min(int((max(a[0], b[0]) + RR - G.x0) / G.cell) + 2, G.w)
            j0 = max(int((min(a[1], b[1]) - RR - G.z0) / G.cell), 0); j1 = min(int((max(a[1], b[1]) + RR - G.z0) / G.cell) + 2, G.h)
            if i0 >= i1 or j0 >= j1: continue
            X = G.x0 + np.arange(i0, i1) * G.cell; Z = G.z0 + np.arange(j0, j1) * G.cell
            px = X[None, :] - a[0]; pz = Z[:, None] - a[1]
            ab = b - a; l2 = max(float(ab @ ab), 1e-9)
            t = np.clip((px * ab[0] + pz * ab[1]) / l2, 0, 1)
            d = np.hypot(px - t * ab[0], pz - t * ab[1])
            np.maximum(out[j0:j1, i0:i1], (R - d).astype(np.float32), out=out[j0:j1, i0:i1])
    return out


# ---------------------------------------------------------------------------
# 다각형
# ---------------------------------------------------------------------------
def area(P):
    x = P[:, 0]; z = P[:, 1]
    return 0.5 * float(np.dot(x, np.roll(z, -1)) - np.dot(np.roll(x, -1), z))

def simplify(P, tol=0.02):
    """거의 한 줄인 꼭짓점 지우기."""
    P = list(map(tuple, P))
    changed = True
    while changed and len(P) > 3:
        changed = False
        for k in range(len(P)):
            a = np.array(P[k - 1]); b = np.array(P[k]); c = np.array(P[(k + 1) % len(P)])
            ac = c - a; L = math.hypot(*ac)
            if L < 1e-6 or abs((b[0] - a[0]) * ac[1] - (b[1] - a[1]) * ac[0]) / L < tol or math.hypot(*(b - a)) < 0.05:
                del P[k]; changed = True; break
    return np.array(P)

def clip_implicit(P, F, step=1.0):
    """다각형 P를 F(x,z) ≤ 0 쪽으로 자른다. 나갔다 들어오면 조각마다 현(弦)으로 닫는다. → [다각형]"""
    pts = []
    n = len(P)
    for k in range(n):
        a = P[k]; b = P[(k + 1) % n]
        m = max(1, int(math.ceil(math.hypot(*(b - a)) / step)))
        for q in range(m): pts.append(a + (b - a) * (q / m))
    pts = np.array(pts)
    f = F(pts[:, 0], pts[:, 1])
    ins = f <= 0
    if ins.all(): return [P]
    if not ins.any(): return []
    k0 = int(np.argmax(~ins))     # 바깥 점에서 시작
    pts = np.roll(pts, -k0, axis=0); f = np.roll(f, -k0); ins = np.roll(ins, -k0)
    N = len(pts)
    def cross(i, j):
        a = pts[i]; b = pts[j]; fa = f[i]; fb = f[j]
        lo, hi = (a, b) if fa <= 0 else (b, a)     # lo 안, hi 밖
        for _ in range(4):
            mid = (lo + hi) * 0.5
            if F(np.array([mid[0]]), np.array([mid[1]]))[0] <= 0: lo = mid
            else: hi = mid
        return (lo + hi) * 0.5
    runs = []; cur = None
    for i in range(N):
        j = (i + 1) % N
        if ins[i] and cur is not None: cur.append(pts[i])
        if ins[i] != ins[j]:
            c = cross(i, j)
            if not ins[i]: cur = [c]
            else:
                cur.append(c); runs.append(np.array(cur)); cur = None
    return [r for r in runs if len(r) >= 3]


# ---------------------------------------------------------------------------
# 본체
# ---------------------------------------------------------------------------
def make_parcels(d, png=False, seed=1870):
    rj, G, (lu, lx0, lz0, lcell), cl = load_space(d)
    rid = rj.get("region_id") or rj.get("route_id") or os.path.basename(d.rstrip("/"))
    rng = np.random.default_rng(abs(hash(rid)) % (2 ** 31) if False else seed + sum(map(ord, rid)))
    jeju = rid.startswith("JJ")
    say(rid, "격자", G.w, "x", G.h, "landuse", lu.shape, "논", int((lu == PADDY).sum()), "밭", int((lu == FIELD).sum()))
    Hs = Grid(ndimage.gaussian_filter(G.a, 2.0), G.x0, G.z0, G.cell)
    gz, gx = np.gradient(ndimage.gaussian_filter(G.a, 6.0), G.cell)   # 경사 판정은 넓게(12m) 고른 땅으로 — DEM 잔물결 무시
    SL = Grid(np.hypot(gx, gz).astype(np.float32), G.x0, G.z0, G.cell)
    # 길·하천 비우기
    roads = [r for r in rj.get("roads", []) if len(r.get("points", [])) >= 2]
    rl = [(r["points"], float(r.get("width_m", 3.0)) * 0.5 + (0.4 if r.get("class") == "대로" else 0.0) + ROAD_MARGIN) for r in roads]
    rv = [(r["points"], 0.59 * max(float(r.get("width_m", 5.0)), 5.2) + RIVER_MARGIN) for r in rj.get("rivers", []) if len(r.get("points", [])) >= 2 and r.get("render", True) is not False]
    road_clear = line_clear(G, rl); river_clear = line_clear(G, rv)
    clear = np.maximum(road_clear, river_clear)
    say("길", len(rl), "하천", len(rv), "비우기 완료")
    # 길 방향 찾기(평지 필지 축)
    segs = []
    seg_r = []; n_road_segs = 0
    for li, (pts, R) in enumerate(rl + rv):
        p = np.asarray(pts, float)[:, :2]
        for q in range(len(p) - 1):
            if np.hypot(*(p[q + 1] - p[q])) > 0.5:
                segs.append((p[q], p[q + 1])); seg_r.append(R)
                if li < len(rl): n_road_segs += 1
    seg_mid = np.array([(a + b) * 0.5 for a, b in segs]) if segs else np.zeros((0, 2))
    seg_tree = cKDTree(seg_mid) if len(seg_mid) else None

    def zone_at(x, z):
        if cl is None: return "south" if not jeju else "coast"
        a, cx0, cz0, cc = cl
        i = int(np.clip(round((x - cx0) / cc), 0, a.shape[1] - 1)); j = int(np.clip(round((z - cz0) / cc), 0, a.shape[0] - 1))
        c = int(a[j, i]); return ZONES[c] if c < len(ZONES) else "south"

    parcels = []   # dict
    for kind in (PADDY, FIELD):
        sdf = kind_sdf(lu, lx0, lz0, lcell, kind, G)
        if sdf is None: continue
        # 논은 길에서 1m 더 띄운다(그 자리에 길 따라 도랑)
        C = np.maximum(sdf + GAP, np.maximum(road_clear + (DITCH_W + 0.2 if kind == PADDY else 0.0), river_clear))
        Cg = Grid(C, G.x0, G.z0, G.cell)
        jj, ii = np.nonzero(C <= 0)
        if len(ii) < 20: continue
        fx = G.x0 + ii * G.cell; fz = G.z0 + jj * G.cell
        S = 110.0 if kind == PADDY else 90.0
        # 보로노이 씨앗: 흔든 격자, 농지 가까운 것만
        gxs = np.arange(fx.min() - S, fx.max() + S, S); gzs = np.arange(fz.min() - S, fz.max() + S, S)
        sx, sz = np.meshgrid(gxs, gzs)
        seeds = np.c_[sx.ravel() + rng.uniform(-0.38, 0.38, sx.size) * S, sz.ravel() + rng.uniform(-0.38, 0.38, sz.size) * S]
        ptree = cKDTree(np.c_[fx, fz])
        dd, _ = ptree.query(seeds)
        seeds = seeds[dd < S * 0.6]
        stree = cKDTree(seeds)
        _, own = stree.query(np.c_[fx, fz])
        say("논" if kind == PADDY else "밭", "농지 칸", len(ii), "구역", len(seeds))
        for si in range(len(seeds)):
            sel = own == si
            if sel.sum() < 12: continue
            px = fx[sel]; pz = fz[sel]
            o = np.array([px.mean(), pz.mean()])
            # 이웃 씨앗 이등분선(구역 테두리 GAP)
            _, nb = stree.query(seeds[si], k=min(12, len(seeds)))
            nb = [j for j in np.atleast_1d(nb) if j != si]
            U = []; M = []
            for j in nb:
                u = seeds[j] - seeds[si]; L = np.hypot(*u)
                if L < 1e-6: continue
                U.append(u / L); M.append((seeds[j] + seeds[si]) * 0.5)
            U = np.array(U); M = np.array(M)
            def F(x, z, U=U, M=M, Cg=Cg):
                v = Cg.at(x, z)
                v = np.maximum(v, np.maximum(np.maximum(G.x0 + 8 - x, x - (G.x0 + (G.w - 1) * G.cell - 8)),
                                             np.maximum(G.z0 + 8 - z, z - (G.z0 + (G.h - 1) * G.cell - 8))))
                if len(U):
                    b = (x[:, None] - M[None, :, 0]) * U[None, :, 0] + (z[:, None] - M[None, :, 1]) * U[None, :, 1]
                    v = np.maximum(v, b.max(axis=1) + GAP)
                return v
            slope = float(np.median(SL.at(px, pz)))
            gxm = float(np.mean(ndimage.map_coordinates(gx, [(pz - G.z0) / G.cell, (px - G.x0) / G.cell], order=1)))
            gzm = float(np.mean(ndimage.map_coordinates(gz, [(pz - G.z0) / G.cell, (px - G.x0) / G.cell], order=1)))
            contour = slope > (0.022 if kind == PADDY else 0.04)
            terraced = kind == FIELD and contour and slope > 0.08 and not jeju   # 산비탈 계단밭
            T = None
            if contour and math.hypot(gxm, gzm) > 1e-4:
                T = np.array([-gzm, gxm]) / math.hypot(gxm, gzm)
            elif seg_tree is not None:
                dq, k = seg_tree.query(o)
                if dq < ROAD_DIR_R:
                    a, b = segs[k]; T = (b - a) / np.hypot(*(b - a))
            if T is None:
                if math.hypot(gxm, gzm) > 0.004: T = np.array([-gzm, gxm]) / math.hypot(gxm, gzm)
                else:
                    ang = rng.uniform(0, math.pi); T = np.array([math.cos(ang), math.sin(ang)])
            N = np.array([-T[1], T[0]])
            tv = np.c_[(px - o[0]) * T[0] + (pz - o[1]) * T[1], (px - o[0]) * N[0] + (pz - o[1]) * N[1]]
            tmin, tmax = tv[:, 0].min() - 4, tv[:, 0].max() + 4
            vmin, vmax = tv[:, 1].min() - 4, tv[:, 1].max() + 4
            # 등고선 휨 c(t): 기준 등고선(구역 중심 높이)이 t마다 v 어디를 지나는지
            tg = np.arange(tmin - 2, tmax + 4, 2.0)
            cg = np.zeros_like(tg)
            if contour:
                href = float(Hs.at(o[0], o[1]))
                vs = np.arange(vmin - 8, vmax + 8, 1.0)
                TT, VV = np.meshgrid(tg, vs, indexing="ij")
                hh = Hs.at(o[0] + TT * T[0] + VV * N[0], o[1] + TT * T[1] + VV * N[1]) - href
                prev = 0.0
                order = np.argsort(np.abs(tg))   # 가운데서 바깥으로
                got = np.full(len(tg), np.nan)
                for q in order:
                    r = hh[q]
                    sc = np.nonzero(np.sign(r[:-1]) != np.sign(r[1:]))[0]
                    if len(sc):
                        roots = vs[sc] + r[sc] / (r[sc] - r[sc + 1] + 1e-12) * 1.0
                        nbq = got[max(q - 1, 0)] if q > 0 and not np.isnan(got[max(q - 1, 0)]) else (got[min(q + 1, len(tg) - 1)] if q + 1 < len(tg) and not np.isnan(got[q + 1]) else 0.0)
                        got[q] = roots[np.argmin(np.abs(roots - nbq))]
                ok = ~np.isnan(got)
                if ok.sum() >= 2:
                    cg = np.interp(tg, tg[ok], got[ok])
                    cg = ndimage.uniform_filter1d(cg, 5, mode="nearest")
                    for q in range(1, len(cg)):    # 기울기 제한(필지가 겹치지 않게)
                        cg[q] = np.clip(cg[q], cg[q - 1] - 1.4, cg[q - 1] + 1.4)
                    cg -= np.interp(0.0, tg, cg)
            def W2(t, v, o=o, T=T, N=N, tg=tg, cg=cg):
                c = np.interp(t, tg, cg)
                vv = v + c
                return np.c_[o[0] + t * T[0] + vv * N[0], o[1] + t * T[1] + vv * N[1]]
            # 크기(게임용으로 약간 줄임): 평지 논 9~13 × 18~30m, 다랑이 너비 = 경사에 맞춰(급할수록 좁게), 밭 10~15 × 16~34m
            if kind == PADDY:
                # 다랑이: 줄마다 0.3~0.6m씩 내려가게(완만하면 넓고 급하면 좁게)
                Wb = float(np.clip(0.45 / max(slope, 1e-3), 3.2, 12.0)) if contour else rng.uniform(9.0, 13.0)
                Lb = (rng.uniform(10, 20) if slope > 0.06 else rng.uniform(14, 26)) if contour else rng.uniform(18, 30)
            elif terraced:
                Wb = float(np.clip(0.9 / max(slope, 1e-3), 4.0, 9.0)); Lb = rng.uniform(12, 26)
            else:
                Wb = float(np.clip(1.5 / max(slope, 1e-3), 6.0, 13.0)) if contour else rng.uniform(10, 15)
                Lb = rng.uniform(16, 34)
            # 석축(막돌 쌓은 둑): 비탈이 급한 다랑이·계단밭(지리산 산골 축대), 제주 비탈 밭
            stone = (kind == PADDY and contour and slope > 0.04) or (terraced and slope > 0.10)
            style = (1 if stone or (jeju and contour) else 0) | (2 if jeju and kind == FIELD else 0) | (4 if terraced else 0)
            v = vmin - rng.uniform(0, Wb); row = 0
            while v < vmax:
                w = Wb * rng.uniform(0.85, 1.15)
                va, vb = v, v + w
                t = tmin - rng.uniform(0, Lb)
                while t < tmax:
                    L = Lb * rng.uniform(0.7, 1.3)
                    ta, tb = t, t + L
                    if contour:
                        tt = np.r_[ta, tg[(tg > ta + 0.3) & (tg < tb - 0.3)], tb]
                    else:
                        tt = np.array([ta, tb])
                    poly = np.r_[W2(tt, np.full(len(tt), va)), W2(tt[::-1], np.full(len(tt), vb))]
                    for piece in clip_implicit(poly, F):
                        piece = simplify(piece)
                        if len(piece) < 3: continue
                        A = area(piece)
                        if A < 0: piece = piece[::-1]; A = -A
                        per = float(np.sum(np.hypot(*(np.roll(piece, -1, axis=0) - piece).T)))
                        if A < (30.0 if kind == PADDY else 40.0) or A / per < 0.8: continue
                        cxz = piece.mean(axis=0)
                        parcels.append(dict(poly=piece, kind=0 if kind == PADDY else 1, district=(kind, si), row=row,
                                            ang=math.atan2(T[1], T[0]), contour=contour or terraced, terraced=terraced, slope=slope, style=style, zone=zone_at(*cxz), area=A))
                    t = tb
                v = vb; row += 1
        say("논" if kind == PADDY else "밭", "필지 누적", len(parcels))
    if not parcels:
        return rj, G, [], []
    # -----------------------------------------------------------------------
    # 이웃·바닥 높이: 구역마다 0.25m 래스터
    # -----------------------------------------------------------------------
    R = 0.25
    by_d = {}
    for k, p in enumerate(parcels): by_d.setdefault(p["district"], []).append(k)
    for key, ks in by_d.items():
        allp = np.concatenate([parcels[k]["poly"] for k in ks])
        bx0, bz0 = allp.min(axis=0) - 2; bx1, bz1 = allp.max(axis=0) + 2
        Wd = int((bx1 - bx0) / R) + 1; Hd = int((bz1 - bz0) / R) + 1
        img = Image.new("I", (Wd, Hd), 0); dr = ImageDraw.Draw(img)
        for k in ks:
            q = parcels[k]["poly"]
            dr.polygon([((x - bx0) / R, (z - bz0) / R) for x, z in q], fill=k + 1)
        lab = np.array(img, dtype=np.int64)
        def look(x, z):
            i = np.clip(((np.asarray(x) - bx0) / R).astype(int), 0, Wd - 1); j = np.clip(((np.asarray(z) - bz0) / R).astype(int), 0, Hd - 1)
            return lab[j, i] - 1
        # 바닥 높이 통계
        jj, ii = np.nonzero(lab)
        hv = G.at(bx0 + (ii + 0.5) * R, bz0 + (jj + 0.5) * R)
        lv = lab[jj, ii] - 1
        order = np.argsort(lv, kind="stable"); lv = lv[order]; hv = hv[order]
        starts = np.searchsorted(lv, ks); ends = np.searchsorted(lv, ks, side="right")
        for k, s0, s1 in zip(ks, starts, ends):
            p = parcels[k]
            h = hv[s0:s1] if s1 > s0 else G.at(*p["poly"].mean(axis=0).reshape(2, 1))
            p["hmean"] = float(np.mean(h)); p["hmed"] = float(np.median(h)); p["hmin"] = float(np.min(h)); p["hmax"] = float(np.max(h))
            if p["kind"] == 0:
                p["floor"] = (p["hmean"] - 0.18) if p["contour"] else (p["hmed"] - 0.3)
            elif p.get("terraced"):
                p["floor"] = p["hmean"]
            else:
                p["floor"] = p["hmean"]
        # 이웃 변(T자 꼭짓점에서 쪼갬)
        for k in ks:
            p = parcels[k]; P = p["poly"]; n = len(P)
            newP = []; nbs = []
            for e in range(n):
                a = P[e]; b = P[(e + 1) % n]
                d = b - a; L = math.hypot(*d)
                out = np.array([d[1], -d[0]]) / max(L, 1e-9)    # 반시계 다각형의 바깥
                m = max(2, int(math.ceil(L / 0.7)))
                fr = (np.arange(m) + 0.5) / m
                lbl = look(a[0] + d[0] * fr + out[0] * 0.35, a[1] + d[1] * fr + out[1] * 0.35)
                cuts = [0.0]
                if len(set(lbl.tolist())) > 1:
                    cands = []
                    for q in set(lbl.tolist()):
                        if q < 0: continue
                        for v in parcels[q]["poly"]:
                            w = v - a; s = (w @ d) / (L * L)
                            if 0.02 < s < 0.98 and abs(w[0] * d[1] - w[1] * d[0]) / L < 0.06: cands.append(float(s))
                    # 이웃 없는 구간 경계(꼭짓점이 없을 때): 표본 사이 가운데
                    for q in range(m - 1):
                        if lbl[q] != lbl[q + 1] and not any(fr[q] - 0.02 <= c <= fr[q + 1] + 0.02 for c in cands):
                            cands.append(float((fr[q] + fr[q + 1]) * 0.5))
                    cuts += sorted(set(round(c, 4) for c in cands))
                cuts.append(1.0)
                for c0, c1 in zip(cuts[:-1], cuts[1:]):
                    if c1 - c0 < 1e-3: continue
                    newP.append(a + d * c0)
                    mid = (c0 + c1) * 0.5
                    nbs.append(int(look(a[0] + d[0] * mid + out[0] * 0.35, a[1] + d[1] * mid + out[1] * 0.35)))
            p["poly"] = np.array(newP); p["nb"] = nbs
    # 다랑이 바닥 정리: 같은 줄 이웃끼리 4cm 안이면 같게(물높이가 맞게)
    # 상태·작물
    for p in parcels:
        z = p["zone"]
        if p["kind"] == 0:
            pr = np.array(PADDY_STATE.get(z, PADDY_STATE["south"])); p["state"] = int(rng.choice(4, p=pr / pr.sum())); p["crop"] = 0
        else:
            pr = np.array(FIELD_CROP.get(z, FIELD_CROP["south"])); p["crop"] = int(rng.choice(6, p=pr / pr.sum())); p["state"] = 0
    # 구역(이웃 논)끼리 상태를 비슷하게: 구역 안 다수 상태로 70%
    by_dist_state = {}
    for p in parcels:
        if p["kind"] == 0: by_dist_state.setdefault(p["district"], []).append(p)
    for ps in by_dist_state.values():
        vals = np.bincount([q["state"] for q in ps], minlength=4); top = int(np.argmax(vals))
        for q in ps:
            if rng.random() < 0.6: q["state"] = top
    # 물꼬: 위(높거나 같은) 이웃과 맞닿은 가장 긴 변의 가운데
    inlets = []; seen = set()
    for k, p in enumerate(parcels):
        if p["kind"] != 0: continue
        best = None
        P = p["poly"]; n = len(P)
        for e in range(n):
            q = p["nb"][e]
            if q < 0 or parcels[q]["kind"] != 0: continue
            if parcels[q]["floor"] < p["floor"] - 0.02: continue
            L = math.hypot(*(P[(e + 1) % n] - P[e]))
            if L < 2.0: continue
            score = parcels[q]["floor"] * 10 + L * 0.01
            if best is None or score > best[0]: best = (score, e, q)
        if best is None: continue
        _, e, q = best
        if (q, k) in seen or (k, q) in seen: continue
        seen.add((k, q))
        a = P[e]; b = P[(e + 1) % n]; m = (a + b) * 0.5 + (b - a) * rng.uniform(-0.25, 0.25)
        inlets.append([float(m[0]), float(m[1]), parcels[q]["floor"], p["floor"]])
    # 도랑: 길과 나란한(25° 안) 논의 구획 바깥 변 — 이웃 번호 -2(엔진이 둑 바깥에 도랑을 판다)
    nd = 0
    if seg_tree is not None:
        for p in parcels:
            if p["kind"] != 0: continue
            P = p["poly"]; n = len(P)
            for e in range(n):
                if p["nb"][e] != -1: continue
                a = P[e]; b = P[(e + 1) % n]; d = b - a; L = math.hypot(*d)
                if L < 3.0: continue
                m = (a + b) * 0.5
                for k in np.atleast_1d(seg_tree.query(m, k=4)[1]):
                    if k >= len(segs) or k >= n_road_segs: continue
                    sa, sb = segs[k]; sd_ = sb - sa; sl = math.hypot(*sd_)
                    t = np.clip(((m - sa) @ sd_) / (sl * sl), 0, 1); dist = math.hypot(*(m - sa - sd_ * t))
                    if dist < seg_r[k] + DITCH_W + 2.5 and abs((d @ sd_) / (L * sl)) > 0.9:
                        p["nb"][e] = -2; nd += 1; break
    say("도랑 변", nd)
    say("필지", len(parcels), "논", sum(1 for p in parcels if p["kind"] == 0), "밭", sum(1 for p in parcels if p["kind"] == 1), "물꼬", len(inlets))
    return rj, G, parcels, inlets


def write(d, rj, G, parcels, inlets, png=False):
    # 64m 칸 순서로 정렬 → 번호 다시 매기기
    key = [(int(math.floor(p["poly"][:, 1].mean() / CHUNK)), int(math.floor(p["poly"][:, 0].mean() / CHUNK))) for p in parcels]
    order = sorted(range(len(parcels)), key=lambda k: key[k])
    remap = {old: new for new, old in enumerate(order)}
    Prow = []; V = []; Cidx = []
    for new, old in enumerate(order):
        p = parcels[old]; cj, ci = key[old]
        if not Cidx or Cidx[-1][0] != ci or Cidx[-1][1] != cj: Cidx.append([ci, cj, new, 0])
        Cidx[-1][3] += 1
        P = p["poly"]; c = P.mean(axis=0)
        Prow.append([c[0], c[1], p["floor"], p["kind"], p["row"], p["state"], p["crop"], p["ang"], p["style"], len(V), len(P), p["slope"]])
        for v, nb in zip(P, p["nb"]):
            V.append([v[0], v[1], remap[nb] if nb >= 0 else nb])
    Pa = np.array(Prow, np.float32).reshape(-1, 12); Va = np.array(V, np.float32).reshape(-1, 3)
    Ia = np.array(inlets, np.float32).reshape(-1, 4); Ca = np.array(Cidx, np.int32).reshape(-1, 4)
    with open(os.path.join(d, "parcels.bin"), "wb") as f:
        f.write(b"PRCL"); f.write(struct.pack("<5I", 1, len(Pa), len(Va), len(Ia), len(Ca)))
        f.write(Pa.tobytes()); f.write(Va.tobytes()); f.write(Ia.tobytes()); f.write(Ca.tobytes())
    # 합집합 부호 거리(2m 격자)
    sd = np.full((G.h, G.w), 8.0, np.float32)
    REACH = 8.0
    polys = [p["poly"] for p in parcels]
    for p in parcels:
        P = p["poly"]; n = len(P)
        for e in range(n):
            if p["nb"][e] == -2:
                a = P[e]; b = P[(e + 1) % n]; dv = (b - a) / max(np.hypot(*(b - a)), 1e-9); out = np.array([dv[1], -dv[0]])
                polys.append(np.array([a, b, b + out * DITCH_W, a + out * DITCH_W]))
    for P in polys:
        i0 = max(int((P[:, 0].min() - REACH - G.x0) / G.cell), 0); i1 = min(int((P[:, 0].max() + REACH - G.x0) / G.cell) + 2, G.w)
        j0 = max(int((P[:, 1].min() - REACH - G.z0) / G.cell), 0); j1 = min(int((P[:, 1].max() + REACH - G.z0) / G.cell) + 2, G.h)
        X, Z = np.meshgrid(G.x0 + np.arange(i0, i1) * G.cell, G.z0 + np.arange(j0, j1) * G.cell)
        x = X.ravel(); z = Z.ravel()
        A = P; B = np.roll(P, -1, axis=0); D = B - A
        px = x[:, None] - A[None, :, 0]; pz = z[:, None] - A[None, :, 1]
        l2 = np.maximum((D ** 2).sum(1), 1e-9)
        t = np.clip((px * D[None, :, 0] + pz * D[None, :, 1]) / l2[None], 0, 1)
        dist = np.hypot(px - t * D[None, :, 0], pz - t * D[None, :, 1]).min(axis=1)
        # 짝홀 안팎
        za = A[None, :, 1]; zb = B[None, :, 1]
        cond = (za > z[:, None]) != (zb > z[:, None])
        xi = A[None, :, 0] + (z[:, None] - za) * D[None, :, 0] / np.where(np.abs(D[None, :, 1]) < 1e-12, 1e-12, D[None, :, 1])
        inside = (np.sum(cond & (x[:, None] < xi), axis=1) % 2) == 1
        s = np.where(inside, -dist, dist).reshape(X.shape).astype(np.float32)
        np.minimum(sd[j0:j1, i0:i1], s, out=sd[j0:j1, i0:i1])
    q = np.clip(np.round(128 + sd * 16), 0, 255).astype(np.uint8)
    Image.fromarray(q, "L").save(os.path.join(d, "farm.png"))
    meta = dict(version=1, parcels=len(Pa), vertices=len(Va), inlets=len(Ia), chunks=len(Ca), chunk_m=CHUNK,
                paddy=int((Pa[:, 3] == 0).sum()), field=int((Pa[:, 3] == 1).sum()),
                farm_png=dict(file="farm.png", x0=G.x0, z0=G.z0, cell=G.cell, w=G.w, h=G.h, encode="v = 128 + 부호 거리(m)·16, 필지 안 음수"),
                params=dict(gap=GAP, road_margin=ROAD_MARGIN, river_margin=RIVER_MARGIN),
                states="논 state: 0 물 댄 모, 1 자라는 벼, 2 익은 벼, 3 그루터기 / 밭 crop: 0 콩, 1 조, 2 보리, 3 배추, 4 고추, 5 묵정",
                note="tools/region/parcels.py가 만든다. 형식은 이 파일 맨 위 설명과 docs/reports/parcels.md")
    json.dump(meta, open(os.path.join(d, "parcels.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    say("쓰기", os.path.join(d, "parcels.bin"), os.path.getsize(os.path.join(d, "parcels.bin")) // 1024, "KB")
    if png: preview(d, G, parcels)

def preview(d, G, parcels, box=None):
    """미리보기 PNG(필지 테두리) — shots/region/parcels/<id>_plan.png"""
    allp = np.concatenate([p["poly"] for p in parcels])
    x0, z0 = allp.min(axis=0); x1, z1 = allp.max(axis=0)
    if box: x0, z0, x1, z1 = box
    s = min(4096 / (x1 - x0), 4096 / (z1 - z0), 2.0)
    img = Image.new("RGB", (int((x1 - x0) * s) + 1, int((z1 - z0) * s) + 1), (60, 70, 50)); dr = ImageDraw.Draw(img)
    for p in parcels:
        P = p["poly"]
        if P[:, 0].max() < x0 or P[:, 0].min() > x1 or P[:, 1].max() < z0 or P[:, 1].min() > z1: continue
        if p["kind"] == 0:
            f = p["floor"]; c = int(80 + (f * 13) % 120)
            col = (90, c, 200) if p["state"] == 0 else ((110, 170, 70) if p["state"] == 1 else ((210, 180, 70) if p["state"] == 2 else (150, 120, 80)))
        else: col = (170, 140, 90)
        dr.polygon([((x - x0) * s, (z - z0) * s) for x, z in P], fill=col, outline=(30, 30, 20))
    out = os.path.join(ROOT, "shots", "region", "parcels"); os.makedirs(out, exist_ok=True)
    nm = os.path.basename(d.rstrip("/"))
    img.save(os.path.join(out, nm + ("_plan_box.png" if box else "_plan.png")))

def read_bin(d):
    """parcels.bin → 미리보기용 dict 목록"""
    b = open(os.path.join(d, "parcels.bin"), "rb").read()
    _, n, nv, ni, nc = struct.unpack("<5I", b[4:24]); o = 24
    P = np.frombuffer(b, np.float32, n * 12, o).reshape(n, 12); o += n * 48
    V = np.frombuffer(b, np.float32, nv * 3, o).reshape(nv, 3)
    out = []
    for r in P:
        vs = V[int(r[9]):int(r[9]) + int(r[10])]
        out.append(dict(poly=vs[:, :2].astype(float), nb=vs[:, 2].astype(int).tolist(), floor=float(r[2]), kind=int(r[3]), state=int(r[5]), crop=int(r[6])))
    return out

def run(d, png=False):
    d = os.path.abspath(d)
    rj, G, parcels, inlets = make_parcels(d, png)
    if not parcels:
        for f in ("parcels.bin", "farm.png", "parcels.json"):
            if os.path.exists(os.path.join(d, f)): os.remove(os.path.join(d, f))
        say(d, "논밭 없음"); return 0
    write(d, rj, G, parcels, inlets, png)
    return len(parcels)

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    png = "--png" in sys.argv
    dirs = []
    if "--all" in sys.argv:
        dirs += [os.path.join(DATA, r) for r in sorted(os.listdir(DATA)) if space_file(os.path.join(DATA, r))]
    if "--routes" in sys.argv:
        rd = os.path.join(DATA, "routes")
        dirs += [os.path.join(rd, r) for r in sorted(os.listdir(rd)) if space_file(os.path.join(rd, r))]
    for a in args:
        dirs.append(a if os.path.isdir(a) else os.path.join(DATA, a))
    if not dirs: dirs = [os.path.join(DATA, "JL_NAMWON_UNBONG")]
    box = None
    for a in sys.argv[1:]:
        if a.startswith("--box="): box = [float(v) for v in a[6:].split(",")]
    for d in dirs:
        if box:
            preview(d, None, read_bin(d), box)
        else:
            run(d, png)

if __name__ == "__main__":
    main()
