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

def river_fields(rivers, shape):
    """4m 격자: 하천 중심선까지 거리(게임 m), 그 점의 수면 y, 반폭, 등급."""
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
    vill = Image.new("L", (Ww, Hh), 0); dv = ImageDraw.Draw(vill)
    bam = Image.new("L", (Ww, Hh), 0); dbm = ImageDraw.Draw(bam)
    def stamp(x, z, r):
        i, j = C.xz_to_ij(x, z, G); rr = r / G
        dv.ellipse([i - rr, j - rr, i + rr, j + rr], fill=255)
        # 대숲: 마을 뒤(북쪽, 카메라 반대) 반원띠
        dbm.pieslice([i - rr * 1.5, j - rr * 1.5, i + rr * 1.5, j + rr * 1.5], 200, 340, fill=255)
    for s in settlements_fixed:
        if s["type"] in ("성황당",): continue
        stamp(s["x"], s["z"], s["radius_m"])
    for x, z in autos: stamp(x, z, 32)
    vm = np.asarray(vill) > 0; bm = (np.asarray(bam) > 0) & ~vm & (nz < 0.55) & (slope < 0.5)
    lu[bm & (lu == FOREST) | bm & (lu == FIELD)] = BAMBOO
    lu[vm & ~water] = VILLAGE
    # 길
    rd = Image.new("L", (Ww, Hh), 0); dd = ImageDraw.Draw(rd)
    for r in roads:
        p = np.array(r["points"]); i, j = C.xz_to_ij(p[:, 0], p[:, 1], G)
        dd.line(list(zip(i.tolist(), j.tolist())), fill=255, width=max(1, int(round(r["width_m"] / G))))
    lu[(np.asarray(rd) > 0) & ~water] = ROAD
    lu[water] = WATER
    info = dict(slope=slope, hand=hand, dr=dr, rhw=rhw)
    return lu, autos, info
