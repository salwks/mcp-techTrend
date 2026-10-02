"""토지이용(계약서 §5 인덱스, 4m 격자) + 입지 규칙 마을 후보.
명세서 §24: 산 → 마을 → 밭 → 논 → 하천. 계곡 바닥 평지·하천가 = 논, 완만한 산록 = 밭, 급경사 = 바위, 나머지 숲."""
import math
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
import common as C

G = C.LU_CELL
FOREST, GRASS, PADDY, FIELD, ROAD, WATER, VILLAGE, ROCK, SAND, BAMBOO = range(10)

def hash01(i, j, seed=1):
    v = np.sin(i * 12.9898 + j * 78.233 + seed * 37.719) * 43758.5453
    return v - np.floor(v)

def river_fields(rivers, shape, G=G):
    """격자(기본 4m): 하천 중심선까지 거리(게임 m), 그 점의 수면 y, 반폭, 등급."""
    Hh, Ww = shape
    surf = np.full(shape, np.nan); hw = np.zeros(shape); gr = np.zeros(shape, np.int8)
    for r in sorted(rivers, key=lambda r: "DCB".index(r["grade"])):
        p = np.array(r["points"])
        seg = np.hypot(*np.diff(p[:, :2], axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
        t = np.arange(0, s[-1], G / 2)
        x = np.interp(t, s, p[:, 0]); z = np.interp(t, s, p[:, 1]); y = np.interp(t, s, p[:, 2])
        i, j = C.xz_to_ij(x, z, G); i = np.clip(np.round(i).astype(int), 0, Ww - 1); j = np.clip(np.round(j).astype(int), 0, Hh - 1)
        surf[j, i] = y; hw[j, i] = r["width_m"] / 2; gr[j, i] = "DCB".index(r["grade"]) + 1
    has = ~np.isnan(surf)
    d, (nj, ni) = ndimage.distance_transform_edt(~has, return_indices=True)
    return d * G, surf[nj, ni], hw[nj, ni], gr[nj, ni]

AREA = {"L": 45000.0, "M": 14000.0, "S": 5000.0}
AREA_ID = {"namwon_eup": 85000.0,      # 성 안 정방형은 별도(전부 마을 터) + 성 밖 85,000m²
           "inwol_yeok": 16000.0, "inwol_jang": 18000.0, "unbong_jang": 12000.0, "namwon_jang": 9000.0, "namwon_hyanggyo": 3000.0}

def village_area(s):
    if s["id"] in AREA_ID: return AREA_ID[s["id"]]
    if s["type"] == "주막": return 1200.0
    if s.get("auto"): return 4500.0
    return AREA.get(s.get("size", "S"), 5000.0)

def classify(y4, rivers, roads, settlements_fixed, seed=3, n_auto=14):
    Hh, Ww = y4.shape
    gz, gx = np.gradient(y4, G)
    slope = np.hypot(gx, gz)                          # tan, 실제와 같음
    dr, rs, rhw, rgr = river_fields(rivers, y4.shape)
    hand = (y4 - rs) / C.K                            # 하천 수면 위 높이(실제 m)
    dist_real = dr / C.K
    jj, ii = np.mgrid[0:Hh, 0:Ww]
    nz = hash01(ii // 6, jj // 6, seed)
    lu = np.full(y4.shape, FOREST, np.uint8)
    sl_s = ndimage.uniform_filter(slope, 5)
    paddy = (sl_s < 0.05) & (hand < 10) & (dist_real < 2500) & (rgr > 0)
    paddy |= (sl_s < 0.045) & (hand < 30)              # 운봉 고원 같은 넓은 분지 바닥
    paddy = ndimage.binary_opening(paddy, iterations=2)
    paddy = ndimage.binary_closing(paddy, iterations=2)
    near_paddy = ndimage.distance_transform_edt(~paddy) * G / C.K
    field = (~paddy) & (sl_s < 0.18) & (hand < 45) & (near_paddy < 110 + 140 * nz)
    lu[field] = FIELD; lu[paddy] = PADDY
    # 하천가 초지·모래톱
    water = dr <= rhw
    bankz = (~water) & (dr <= rhw + np.where(rgr == 3, 7.0, np.where(rgr == 2, 3.0, 1.0)))
    lu[bankz & (slope < 0.15)] = GRASS
    lu[bankz & (rgr == 3) & (slope < 0.08) & (nz < 0.75)] = SAND
    lu[bankz & (rgr == 2) & (slope < 0.06) & (nz < 0.35)] = SAND
    lu[(slope > 0.85) | ((slope > 0.7) & (nz < 0.3))] = ROCK
    # 자동 마을 후보: 산기슭(경사 3~12%), 아래로 논, 남·동향 선호, 간격
    autos = []
    cand = (sl_s > 0.03) & (sl_s < 0.13) & (hand > 3) & (hand < 45) & (near_paddy < 120) & (near_paddy > 8)
    cand &= ndimage.binary_erosion(~paddy, iterations=4)
    aspect_s = np.clip(gz / (slope + 1e-6), -1, 1)    # +z(남) 쪽으로 내려가면 양수 → 남향
    paddy_amt = ndimage.uniform_filter(paddy.astype(float), 61)
    score = np.where(cand, 0.6 + 0.6 * aspect_s + 2.0 * paddy_amt + 0.3 * nz, -9)
    taken = [(s["x"], s["z"]) for s in settlements_fixed]
    order = np.argsort(-score, axis=None)
    xs, zs = C.ij_to_xz(ii, jj, G)
    for idx in order[:200000]:
        if score.flat[idx] < 0.9 or len(autos) >= n_auto: break
        x, z = float(xs.flat[idx]), float(zs.flat[idx])
        if abs(x) > 4250 or abs(z) > 2020: continue
        if all(math.hypot(x - a, z - b) > 450 for a, b in taken):
            taken.append((x, z)); autos.append((x, z))
    # ── 마을 터: 원 대신 '길을 따라 늘어서고 산기슭에 기대는' 모양으로 키운다(명세 §24 배산임수)
    rd = Image.new("L", (Ww, Hh), 0); dd = ImageDraw.Draw(rd)
    for r in roads:
        p = np.array(r["points"]); i, j = C.xz_to_ij(p[:, 0], p[:, 1], G)
        dd.line(list(zip(i.tolist(), j.tolist())), fill=255, width=max(1, int(round(r["width_m"] / G))))
    road_m = np.asarray(rd) > 0
    d_road = ndimage.distance_transform_edt(~road_m) * G
    excl = water | (dr <= rhw + 5)
    vm = np.zeros(lu.shape, bool)
    shapes = {}
    for s in list(settlements_fixed) + [dict(id=f"auto_village_{n:02d}", x=x, z=z, type="마을", size="S", auto=True) for n, (x, z) in enumerate(autos)]:
        if s["type"] in ("성황당", "사찰"): continue
        target = village_area(s)
        core = s.get("core")                                   # 남원: 성 안 정방형(게임 좌표 x0,z0,x1,z1)
        req = math.sqrt(target / math.pi)
        rmax = max(70.0, 2.6 * req) + (110 if core else 0)
        ci, cj = C.xz_to_ij(s["x"], s["z"], G); R = int(rmax / G) + 2
        j0, j1, i0, i1 = max(int(cj) - R, 0), min(int(cj) + R + 1, Hh), max(int(ci) - R, 0), min(int(ci) + R + 1, Ww)
        sx, sz = xs[j0:j1, i0:i1], zs[j0:j1, i0:i1]
        if core:
            x0, z0, x1, z1 = core
            dx = np.maximum(np.maximum(x0 - sx, sx - x1), 0); dz = np.maximum(np.maximum(z0 - sz, sz - z1), 0)
            dc = np.hypot(dx, dz); inside_core = (dx == 0) & (dz == 0)
        else:
            dc = np.hypot(sx - s["x"], sz - s["z"]); inside_core = np.zeros(sx.shape, bool)
        sl_ = sl_s[j0:j1, i0:i1]; hd = hand[j0:j1, i0:i1]
        sc = (dc / max(req, 20.0)) * 0.9 + np.minimum(d_road[j0:j1, i0:i1], 90) / 28.0 \
             + 3.0 * (sl_ > 0.28) + 0.5 * ((sl_ < 0.02) & (hd < 6)) - 0.45 * ((sl_ > 0.03) & (sl_ < 0.18)) + 0.25 * nz[j0:j1, i0:i1]
        sc[excl[j0:j1, i0:i1] | (dc > rmax)] = 99
        sc[inside_core] = -99
        n_px = int(target / (G * G)) + int(inside_core.sum())
        order_ = np.argsort(sc, axis=None)[:n_px]
        m = np.zeros(sc.shape, bool); m.flat[order_] = True
        m &= sc < 50
        m = ndimage.binary_closing(m, iterations=2) & ~excl[j0:j1, i0:i1]
        m = ndimage.binary_opening(m, iterations=1) | (m & inside_core)
        lab_, n_ = ndimage.label(m)
        if n_ > 1:   # 중심(또는 core)에 닿은 덩어리 + 큰 덩어리만
            sizes_ = ndimage.sum(np.ones_like(m), lab_, range(1, n_ + 1))
            keep = [k + 1 for k in range(n_) if sizes_[k] >= 0.12 * sizes_.max()]
            m = np.isin(lab_, keep)
        vm[j0:j1, i0:i1] |= m
        if m.any():
            jj_, ii_ = np.nonzero(m)
            ex, ez = sx[jj_, ii_], sz[jj_, ii_]
            shapes[s["id"]] = dict(area_m2=round(float(m.sum() * G * G)), extent_m=round(float(np.hypot(ex - s["x"], ez - s["z"]).max()), 1),
                                   bbox=[round(float(ex.min()), 1), round(float(ez.min()), 1), round(float(ex.max()), 1), round(float(ez.max()), 1)])
    # 대숲: 마을 둘레 20m 안, 마을보다 높은 쪽(산 쪽) — 배산
    ring = ndimage.binary_dilation(vm, iterations=int(20 / G)) & ~vm
    vill_h = ndimage.grey_dilation(np.where(vm, y4, -1e9), size=int(40 / G))
    bm = ring & (y4 > vill_h - 0.3) & (nz < 0.55) & (slope < 0.5)
    lu[bm & ((lu == FOREST) | (lu == FIELD))] = BAMBOO
    lu[vm & ~water] = VILLAGE
    # 길
    lu[road_m & ~water] = ROAD
    lu[water] = WATER
    info = dict(slope=slope, hand=hand, dr=dr, rhw=rhw, shapes=shapes)
    return lu, autos, info
