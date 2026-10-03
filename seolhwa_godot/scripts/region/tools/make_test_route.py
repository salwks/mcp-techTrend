#!/usr/bin/env python3
"""시험용 작은 노정(terrain-engine 개발용) — 계약서 §10 / 계획서 §2.1 노정 형식을 엔진이 불러오는지 검증하려고 만든다.
진짜 노정(region_data/routes/, data 담당)이 생기기 전까지만 쓴다.

    python3 scripts/region/tools/make_test_route.py [out_root=shots/region/test_route]
    godot --path . res://scenes/region.tscn -- --routedir=res://shots/region/test_route/ --route=TEST_PALLYANG

노정 띠: x −1024…+1024(2048m, 길 따라), z −192…+192(폭 384m). 길은 x를 따라 굽이치고,
주막(−700) → 고개·성황당(−300, 고산 기후대로 표시해 기후대 전환 시험) → 나루(+300, 남북으로 흐르는 강) → 장승(+800).
양 끝 포털: from = 남원 권역 동쪽 끝(통영별로 함양 방면), to = 남원 권역 북쪽 끝(전주 방면 길) — 권역이 하나뿐이라 고리로 잇는다.
"""
import json, math, os, sys
import numpy as np
from PIL import Image

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "../../../shots/region/test_route")
RID = "TEST_PALLYANG"
OUT = os.path.join(ROOT, RID)
os.makedirs(OUT, exist_ok=True)

CELL = 2.0
X0, X1, Z0, Z1 = -1024.0, 1024.0, -192.0, 192.0
W = int((X1 - X0) / CELL) + 1
H = int((Z1 - Z0) / CELL) + 1
xs = X0 + np.arange(W) * CELL
zs = Z0 + np.arange(H) * CELL
XX, ZZ = np.meshgrid(xs, zs)
rng = np.random.default_rng(11)

def road_z(x):
    return 38.0 * np.sin(x / 260.0) + 12.0 * np.sin(x / 90.0 + 1.0)

def profile(x):
    """길 고도 단면(압축): 들(40) → 고개(98, x=-300) → 강 골짜기(20, x=+300) → 언덕(44)."""
    pts = [(-1100, 38), (-800, 44), (-560, 62), (-300, 98), (-80, 60), (150, 30), (300, 20), (450, 26), (700, 40), (1100, 44)]
    px, py = zip(*pts)
    return np.interp(x, px, py)

def noise(scale, amp, oct=4):
    out = np.zeros((H, W), np.float32)
    a, s = amp, scale
    for _ in range(oct):
        gw, gh = int(W * CELL / s) + 3, int(H * CELL / s) + 3
        g = rng.random((gh, gw)).astype(np.float32) * 2 - 1
        from scipy.ndimage import zoom
        z = zoom(g, (H / gh, W / gw), order=3)[:H, :W]
        out += z * a
        a *= 0.5; s /= 2
    return out

rz = road_z(XX)
d = np.abs(ZZ - rz)
base = profile(XX)
# 길 양옆 산: 멀어질수록 높게(골짜기 띠), 북쪽(-z)이 더 높다(배산)
side = np.where(ZZ < rz, 1.25, 0.85)
h = base + (np.maximum(d - 25.0, 0) / 120.0) ** 1.6 * 70.0 * side + noise(220, 9.0) * np.clip((d - 15) / 60, 0, 1)
# 강(남북, x=300 둘레): 골짜기를 파고 수면 18
RX = 300.0 + 20.0 * np.sin(ZZ / 70.0)
rd = np.abs(XX - RX)
river_w = 16.0
h = np.where(rd < river_w * 0.5 + 6, np.minimum(h, 18.0 + np.maximum(rd - river_w * 0.5, 0) * 0.6 - 1.4), h)
h = np.where(rd < river_w * 0.5, 16.4, h)
# 길은 단면을 따른다(길 폭 둘레 깎기·메우기)
road_mask = d < 4.0
h = np.where(d < 9.0, base * (1 - np.clip((d - 4) / 5, 0, 1)) + h * np.clip((d - 4) / 5, 0, 1), h)
h = np.where(rd < river_w * 0.5, 16.4, h)  # 나루 자리는 물
y_min, y_max = float(h.min()) - 1.0, float(h.max()) + 1.0
v = np.clip((h - y_min) / (y_max - y_min) * 65535.0, 0, 65535).astype(np.uint16)
Image.fromarray(v, mode="I;16").save(os.path.join(OUT, "height.png"))

# 토지이용(같은 격자 2m): 0 숲, 1 풀, 2 논, 3 밭, 4 길, 5 물, 6 마을 터, 7 바위, 8 모래톱
lu = np.zeros((H, W), np.uint8)
gy, gx = np.gradient(h, CELL)
slope = np.hypot(gx, gy)
lu[:] = 0
lu[(d < 70) & (slope < 0.18)] = 1
lu[(d < 110) & (slope < 0.08) & (h < 45)] = 2
lu[(d > 14) & (d < 60) & (slope < 0.12) & (h >= 45) & (h < 70)] = 3
lu[slope > 0.85] = 7
lu[(rd < river_w * 0.5 + 7) & (rd >= river_w * 0.5)] = 8
lu[rd < river_w * 0.5] = 5
lu[road_mask] = 4
STOPS = [
    {"type": "주막", "name": "팔량 주막", "x": -700.0, "t": 0.16},
    {"type": "고개", "name": "시험 고개(성황당)", "x": -300.0, "t": 0.35},
    {"type": "나루", "name": "시험 나루", "x": 300.0, "t": 0.65},
    {"type": "장승", "name": "장승배기", "x": 800.0, "t": 0.89},
]
for s in STOPS:
    s["z"] = float(road_z(s["x"]))
    if s["type"] in ("주막", "장승"):
        lu[(np.hypot(XX - s["x"], ZZ - s["z"]) < 34) & (lu != 4) & (lu != 5)] = 6
Image.fromarray(lu, mode="L").save(os.path.join(OUT, "landuse.png"))

# 기후대(4m): 남부(0), 고개 둘레 높은 곳은 고산(3) — 기후대 전환 시험
cl = np.zeros((H, W), np.uint8)
cl[(np.abs(XX + 300) < 200)] = 3
cl4 = cl[::2, ::2]
Image.fromarray(cl4, mode="L").save(os.path.join(OUT, "climate.png"))

road_x = np.arange(-1000.0, 1000.1, 8.0)
road_pts = [[float(x), float(road_z(x))] for x in road_x]
riv_z = np.arange(Z0, Z1 + 0.1, 8.0)
riv_pts = [[float(300.0 + 20.0 * math.sin(z / 70.0)), float(z), 18.0] for z in riv_z]
route = {
    "route_id": RID,
    "name": "시험 노정(팔량치 고리)",
    "kind": "route",
    "status": "시험(terrain-engine) — 진짜 노정 데이터가 오면 지운다",
    "from_region": "JL_NAMWON_UNBONG",
    "to_region": "JL_NAMWON_UNBONG",
    "compression": {"note": "시험용 — 실제 도로 아님"},
    "projection": {"K": 0.3, "y_base_alt": 60.0, "note": "노정은 압축 축척이라 실제 경위도와 맞지 않음(계획서 §2.1)"},
    "climate_zone": "south",
    "height": {"file": "height.png", "x0": X0, "z0": Z0, "cell": CELL, "w": W, "h": H, "y_min": y_min, "y_max": y_max},
    "landuse": {"file": "landuse.png", "x0": X0, "z0": Z0, "cell": CELL, "w": W, "h": H},
    "climate": {"file": "climate.png", "x0": X0, "z0": Z0, "cell": 4.0, "w": cl4.shape[1], "h": cl4.shape[0],
                "codes": {"0": "south", "1": "central", "2": "north", "3": "alpine", "4": "coast"},
                "rule": {"alpine_alt_m": {"0": 360.0}, "note": "시험: 고개 둘레 높은 곳 잔설(y 81 위)"}},
    "rivers": [{"id": "test_river", "name": "시험 강", "grade": "B", "width_m": river_w, "points": riv_pts, "flows_to": ""}],
    "roads": [{"id": "test_road", "name": "시험 대로", "class": "대로", "width_m": 5.0, "points": road_pts}],
    "passes": [{"id": "test_pass", "name": "시험 고개", "x": -300.0, "z": float(road_z(-300.0)), "y": 98.0 - 60 * 0}],
    "crossings": [{"id": "test_naru", "type": "나루", "river_id": "test_river", "road_id": "test_road", "x": 300.0, "z": float(road_z(300.0))}],
    "settlements": [{"id": "test_" + str(i), "name": s["name"], "type": s["type"], "x": s["x"], "z": s["z"], "radius_m": 30} for i, s in enumerate(STOPS)],
    "landmarks": [],
    "stops": STOPS,
    "spawn": {"x": road_pts[0][0] + 20.0, "z": road_pts[0][1]},
    "portals": {
        "from": {"region": "JL_NAMWON_UNBONG", "x": 4318.0, "z": -1735.0, "name": "함양 방면"},
        "to": {"region": "JL_NAMWON_UNBONG", "x": -3480.0, "z": -2060.0, "name": "전주 방면"},
    },
    # 전국 지도 선(경도, 위도) — 노정 좌표는 압축이라 지도는 이 선을 따라 진행도로 그린다
    "geo_line": [[127.66, 35.40], [127.73, 35.52], [127.6, 35.7], [127.3, 35.75], [127.15, 35.82]],
}
json.dump(route, open(os.path.join(OUT, "route.json"), "w"), ensure_ascii=False, indent=1)

def at(x, dz=0.0):
    return float(x), float(road_z(x) + dz)

items = []
jx, jz = at(-700, 16)
items.append({"id": "tr_jumak", "kit": "village/jumak", "params": {"seed": 4}, "x": jx, "z": jz, "ry": 0.0, "flatten": True, "group": "팔량 주막"})
items.append({"id": "tr_firewood", "kit": "village/firewood", "params": {"seed": 2}, "x": jx + 7, "z": jz + 1, "ry": 0.0, "group": "팔량 주막"})
sx, sz = at(-300, -12)
items.append({"id": "tr_seonghwang", "kit": "village/seonghwangdang", "params": {"seed": 3}, "x": sx, "z": sz, "ry": 0.0, "flatten": True, "group": "시험 고개"})
items.append({"id": "tr_cairn", "kit": "village/cairn", "params": {"seed": 5}, "x": sx + 6, "z": sz + 4, "ry": 0.0, "group": "시험 고개"})
nx_, nz_ = 300.0 + 20.0 * math.sin(float(road_z(300.0)) / 70.0), float(road_z(300.0) + 6.0)
items.append({"id": "tr_narutbae", "kit": "village/narutbae", "params": {"seed": 1}, "x": nx_, "z": nz_, "ry": 1.5708, "y": None, "group": "시험 나루"})
for i, f in enumerate([False, True]):
    x, z = at(800, -4 if i == 0 else 4)
    items.append({"id": "tr_jangseung_%d" % i, "kit": "village/jangseung", "params": {"seed": 7 + i, "female": f}, "x": x - 3, "z": z + (-3 if i == 0 else 3), "ry": 0.0, "group": "장승배기"})
json.dump({"area": "test_route", "items": items}, open(os.path.join(OUT, "placement_route.json"), "w"), ensure_ascii=False, indent=1)
print("test route ->", OUT, W, H, "y", round(y_min, 1), round(y_max, 1))
