#!/usr/bin/env python3
"""임시 권역 데이터(terrain-engine 개발용) — 진짜 데이터(region_data/JL_NAMWON_UNBONG, terrain-data 담당)가
생기기 전까지 엔진을 만들고 시험하려고, 계약서 §5와 **같은 형식**으로 절차 생성한 산·강·들을 만든다.

    python3 scripts/region/tools/make_tmp_region.py [out_dir=shots/region/tmp_data]

실제 지리를 흉내만 낸다(남원 분지 서쪽 낮음, 여원재 고개, 운봉 고원, 동남쪽 지리산 높음, 요천·람천).
좌표는 계약서 §1 투영(K=0.30)으로 실제 경위도에서 계산한 게임 좌표.
"""
import json, math, os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import zoom, gaussian_filter, distance_transform_edt

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "../../../shots/region/tmp_data")
os.makedirs(OUT, exist_ok=True)

K = 0.30
LAT0, LON0 = 35.4175, 127.50
def geo(lat, lon):
    return ((lon - LON0) * math.cos(math.radians(LAT0)) * 111320 * K, -(lat - LAT0) * 110574 * K)

CELL = 2.0
X0, X1, Z0, Z1 = -4352.0, 4352.0, -2112.0, 2112.0
W = int((X1 - X0) / CELL) + 1
H = int((Z1 - Z0) / CELL) + 1
xs = X0 + np.arange(W) * CELL
zs = Z0 + np.arange(H) * CELL
XX, ZZ = np.meshgrid(xs, zs)
rng = np.random.default_rng(7)

def noise(scale_m, amp, oct=4):
    """값 잡음 fbm(넘파이): 격자 난수를 확대해 쌓는다."""
    out = np.zeros((H, W), np.float32)
    a, s = amp, scale_m
    for _ in range(oct):
        gw, gh = int(W * CELL / s) + 3, int(H * CELL / s) + 3
        g = rng.random((gh, gw)).astype(np.float32) * 2 - 1
        z = zoom(g, (H / gh * 1.0, W / gw * 1.0), order=3)[:H, :W]
        out += z * a
        a *= 0.5; s /= 2.03
    return out

# ---- 장소(실제 경위도 → 게임 좌표) ----
P = {
    "namwon": geo(35.410, 127.385), "gwanghallu": geo(35.4035, 127.3805), "yeowonjae": geo(35.435, 127.462),
    "unbong": geo(35.433, 127.535), "hwangsan": geo(35.455, 127.556), "inwol": geo(35.453, 127.588),
    "silsangsa": geo(35.3965, 127.610), "jiri": geo(35.36, 127.62),
}

def gauss(c, r):
    return np.exp(-((XX - c[0]) ** 2 + (ZZ - c[1]) ** 2) / (2 * r * r))

# 실제 고도(m)로 만든 뒤 y = (고도-60)·K
elev = 120 + noise(1800, 120, 5)
# 서쪽 남원 분지(낮음), 운봉 고원(450m), 동남 지리산(1400m+), 북쪽 산줄기
elev += 300 * (1 / (1 + np.exp(-(XX + 1500) / 300)))           # 동쪽으로 갈수록 고원
elev -= 60 * gauss(P["namwon"], 1400)
plateau = gauss(P["unbong"], 1300) + 0.8 * gauss(P["inwol"], 900)
elev = elev * (1 - 0.6 * np.clip(plateau, 0, 1)) + 440 * np.clip(plateau, 0, 1) * 0.6
mount = np.clip(noise(900, 1.0, 5) * 0.5 + 0.5, 0, 1)
ridge_mask = np.clip(1 - plateau * 1.3, 0, 1) * np.clip(1 - gauss(P["namwon"], 1500) * 1.4, 0, 1)
elev += 520 * mount ** 1.6 * ridge_mask
elev += 1300 * gauss(P["jiri"], 1500) * (0.7 + 0.6 * mount)        # 지리산 서북 능선
# 여원재: 남원 분지와 운봉 고원 사이 고개(안부)
yw = P["yeowonjae"]
elev = elev * (1 - 0.5 * gauss(yw, 260)) + 470 * 0.5 * gauss(yw, 260)
# 산다운 주름: 산지일수록 능선형(ridged) 잡음을 세게
valley = np.clip(gauss(P["namwon"], 1500) * 1.5 + plateau * 1.6 + 1.2 * gauss(yw, 300) * 0, 0, 1)
mtn = np.clip((elev - 220) / 500, 0, 1) * (1 - valley)
rg = 1 - np.abs(noise(700, 1.0, 5))
elev += 420 * rg ** 2 * mtn
# 골짜기 바닥(분지·고원)은 평평하게
floor_k = valley
elev = elev * (1 - floor_k) + gaussian_filter(elev, 40) * floor_k
elev += noise(120, 6, 3) * (0.3 + mtn)
elev = gaussian_filter(elev, 2)

# ---- 하천(상류→하류) ----
rivers_src = [
    {"id": "yocheon", "name": "요천", "grade": "B", "width_m": 14.0, "flows_to": "seomjingang",
     "pts": [geo(35.475, 127.430), geo(35.455, 127.415), geo(35.432, 127.400), geo(35.414, 127.388),
             geo(35.400, 127.378), geo(35.388, 127.360), geo(35.372, 127.343)]},
    {"id": "ramcheon", "name": "람천", "grade": "C", "width_m": 10.0, "flows_to": "imcheon",
     "pts": [geo(35.425, 127.515), geo(35.440, 127.545), geo(35.452, 127.575), geo(35.448, 127.600),
             geo(35.425, 127.612), geo(35.402, 127.607), geo(35.380, 127.625), geo(35.358, 127.640)]},
    {"id": "gwangchi", "name": "광치천(가칭)", "grade": "D", "width_m": 5.0, "flows_to": "yocheon",
     "pts": [geo(35.440, 127.455), geo(35.428, 127.432), geo(35.420, 127.410), geo(35.416, 127.392)]},
]

def densify(pts, step=6.0):
    out = []
    for a, b in zip(pts[:-1], pts[1:]):
        n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / step))
        for i in range(n):
            t = i / n
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    out.append(pts[-1])
    # 살짝 굽이치게
    o = np.array(out)
    d = np.gradient(o, axis=0); nrm = np.stack([-d[:, 1], d[:, 0]], 1)
    nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-9
    s = np.cumsum(np.r_[0, np.linalg.norm(np.diff(o, axis=0), axis=1)])
    o += nrm * (np.sin(s / 90.0) * 14 + np.sin(s / 37.0 + 1.3) * 5)[:, None]
    return o

def sample(arr, x, z):
    i = np.clip(((x - X0) / CELL).astype(int), 0, W - 1); j = np.clip(((z - Z0) / CELL).astype(int), 0, H - 1)
    return arr[j, i]

ygame = (elev - 60) * K
rivers = []
river_mask = np.zeros((H, W), bool)
carve = np.full((H, W), np.inf, np.float32)
bank = np.full((H, W), np.inf, np.float32)
for r in rivers_src:
    o = densify(r["pts"])
    g = sample(gaussian_filter(ygame, 20), o[:, 0], o[:, 1])
    # 수면은 하류로 갈수록 낮아지기만(단조) + 지면보다 2m 아래
    ws = np.minimum.accumulate(g - 2.0)
    pts = [[round(float(x), 1), round(float(z), 1), round(float(y), 2)] for (x, z), y in zip(o, ws)]
    rivers.append({"id": r["id"], "name": r["name"], "grade": r["grade"], "width_m": r["width_m"],
                   "points": pts[::2] + ([pts[-1]] if len(pts) % 2 == 0 else []), "flows_to": r["flows_to"]})
    # 래스터: 강 중심선 거리장
    m = np.zeros((H, W), bool)
    ii = np.clip(((o[:, 0] - X0) / CELL).round().astype(int), 0, W - 1)
    jj = np.clip(((o[:, 1] - Z0) / CELL).round().astype(int), 0, H - 1)
    m[jj, ii] = True
    dist, (ni, nj) = distance_transform_edt(~m, return_indices=True)
    dist *= CELL
    wy = np.full((H, W), np.nan, np.float32)
    wy[jj, ii] = ws
    wsurf = wy[ni, nj]
    hw = r["width_m"] / 2
    bed = wsurf - (0.6 + 0.9 * np.clip(1 - dist / hw, 0, 1))      # 물 깊이 0.6~1.5m
    inner = dist < hw
    # 둑: 강폭의 3배까지 수면 위 0.4m 쪽으로 부드럽게
    band = dist < hw * 4 + 20
    t = np.clip((dist - hw) / (hw * 3 + 20), 0, 1)
    tt = t * t * (3 - 2 * t)
    target = np.where(inner, bed, (wsurf + 0.5) * (1 - tt) + ygame * tt)
    ygame = np.where(band, np.minimum(ygame, target) if True else target, ygame)
    ygame = np.where(inner, bed, ygame)
    river_mask |= inner
    bank = np.minimum(bank, np.where(band, dist - hw, np.inf))

# ---- 길 ----
roads_src = [
    {"id": "daero", "name": "통영별로(남원-운봉-함양)", "class": "대로", "width_m": 4.0,
     "pts": [P["namwon"], geo(35.418, 127.410), geo(35.428, 127.440), P["yeowonjae"], geo(35.432, 127.495), P["unbong"],
             geo(35.445, 127.560), P["inwol"], geo(35.462, 127.630), geo(35.470, 127.658)]},
    {"id": "sil", "name": "인월-실상사 길", "class": "지선", "width_m": 3.0,
     "pts": [P["inwol"], geo(35.435, 127.603), geo(35.412, 127.604), P["silsangsa"]]},
    {"id": "jeonju", "name": "남원-전주 길", "class": "대로", "width_m": 4.0,
     "pts": [P["namwon"], geo(35.430, 127.383), geo(35.455, 127.395), geo(35.480, 127.400)]},
]
roads = []
road_d = np.full((H, W), np.inf, np.float32)
for r in roads_src:
    o = densify(r["pts"], 4.0)
    roads.append({"id": r["id"], "name": r["name"], "class": r["class"], "width_m": r["width_m"],
                  "points": [[round(float(x), 1), round(float(z), 1)] for x, z in o[::4]]})
    m = np.zeros((H, W), bool)
    ii = np.clip(((o[:, 0] - X0) / CELL).round().astype(int), 0, W - 1)
    jj = np.clip(((o[:, 1] - Z0) / CELL).round().astype(int), 0, H - 1)
    m[jj, ii] = True
    d = distance_transform_edt(~m) * CELL
    road_d = np.minimum(road_d, d - r["width_m"] / 2)
    # 길바닥 고르게(가로 경사 완만)
    sm = gaussian_filter(ygame, 4)
    k = np.clip(1 - (d - r["width_m"] / 2) / 6, 0, 1) * (~river_mask)
    ygame = ygame * (1 - k) + sm * k

# ---- 토지이용 ----
gy, gx = np.gradient(ygame, CELL)
slope = np.hypot(gx, gy)
low = gaussian_filter(ygame, 60)
rel = ygame - low
lu = np.zeros((H, W), np.uint8)                                   # 0 숲
lu[((slope < 0.12) & (rel < 4)) | ((slope < 0.25) & (rel < -4))] = 1            # 1 풀밭
flat = (slope < 0.07) & (bank < 900) & (rel < 3)
lu[flat] = 2                                                       # 2 논
fieldm = (slope < 0.16) & (slope >= 0.05) & (bank < 1200) & (noise(160, 1.0, 2) > -0.1)
lu[fieldm & (lu != 2)] = 3                                         # 3 밭
lu[slope > 0.95] = 7                                               # 7 바위·벼랑
settle = []
for key, name, typ, rad in [("namwon", "남원읍성", "읍성", 180), ("unbong", "운봉", "마을", 120), ("inwol", "인월", "장시", 110),
                            ("silsangsa", "실상사", "사찰", 70)]:
    c = P[key]
    m = gauss(c, rad * 0.6) > 0.35
    lu[m & (slope < 0.25)] = 6                                     # 6 마을 터
    settle.append({"id": key, "name": name, "type": typ, "x": round(c[0], 1), "z": round(c[1], 1), "radius_m": rad,
                   "size": "대" if typ == "읍성" else "중", "notes": "임시 데이터", "confidence": "가설"})
bam = (noise(60, 1.0, 2) > 0.55) & (bank < 300) & (slope < 0.4) & (lu <= 1)
lu[bam] = 9                                                        # 9 대숲
lu[road_d < 0] = 4                                                 # 4 길
sandbar = (bank >= 0) & (bank < 6) & (noise(40, 1.0, 2) > 0.1)
lu[sandbar] = 8                                                    # 8 모래톱
lu[river_mask] = 5                                                 # 5 물

y_min, y_max = float(ygame.min()) - 1, float(ygame.max()) + 1
v = np.round((ygame - y_min) / (y_max - y_min) * 65535).astype(np.uint16)
Image.fromarray(v).save(os.path.join(OUT, "height.png"))
Image.fromarray(lu).save(os.path.join(OUT, "landuse.png"))

c = P["namwon"]
region = {
    "region_id": "JL_NAMWON_UNBONG", "name": "남원·운봉(임시 절차 데이터)", "status": "임시", "main_river": "yocheon",
    "sources": ["terrain-engine 임시 절차 생성 — 실측 아님"],
    "height": {"file": "height.png", "x0": X0, "z0": Z0, "cell": CELL, "w": W, "h": H, "y_min": y_min, "y_max": y_max},
    "landuse": {"file": "landuse.png", "x0": X0, "z0": Z0, "cell": CELL, "w": W, "h": H,
                "classes": ["숲", "풀밭", "논", "밭", "길", "물", "마을터", "바위", "모래톱", "대숲"]},
    "rivers": rivers, "roads": roads,
    "passes": [{"id": "yeowonjae", "name": "여원재", "x": round(yw[0], 1), "z": round(yw[1], 1),
                "y": round(float(sample(ygame, np.array([yw[0]]), np.array([yw[1]]))[0]), 1)}],
    "crossings": [],
    "settlements": settle,
    "landmarks": [
        {"id": "gwanghallu", "name": "광한루", "kit": "landmark/gwanghallu", "x": round(P["gwanghallu"][0], 1), "z": round(P["gwanghallu"][1], 1), "ry": 0, "confidence": "가설", "source": "임시"},
        {"id": "hwangsan", "name": "황산대첩비", "kit": "landmark/bigak", "x": round(P["hwangsan"][0], 1), "z": round(P["hwangsan"][1], 1), "ry": 0, "confidence": "가설", "source": "임시"},
        {"id": "silsangsa", "name": "실상사", "kit": "landmark/silsangsa", "x": round(P["silsangsa"][0], 1), "z": round(P["silsangsa"][1] - 20, 1), "ry": 0, "confidence": "가설", "source": "임시"},
    ],
    "spawn": {"x": round(c[0], 1), "z": round(c[1] + 140, 1)},
}
with open(os.path.join(OUT, "region.json"), "w") as f:
    json.dump(region, f, ensure_ascii=False, indent=1)
print("wrote", OUT, W, H, y_min, y_max)
