#!/usr/bin/env python3
"""여원재 대로 아랫주막 아래 골물 여울 고치기(integ-mountain, 2026-10-22) — build_mountain.py 다음에(rebuild.sh) 돌린다. 여러 번 돌려도 같다.
문제: 통영별로(대로)가 여원치 골물과 나란히 가며 두 번 물길을 건너고, 물길 바닥(river core — 길 깎기가 메우지 않음)으로 꺼져
  10m 구배 32%(설계 18%)가 걸어 재어졌다(mtncheck MTNGRADE: (-391.8, -873.2)).
고침: 이 구간(x −400 ~ −338) 대로 노면을 고른 비탈(약 11%)로 다시 깎고 메운다(물길 칸은 건드리지 않음),
  두 건널목은 홍예 돌다리(village/stone_bridge — 대로가 D급 물을 건너면 돌다리, tools/region/build.py 규칙과 같게)로 바꾸고 다리를 놓는다.
"""
import json, os
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.normpath(os.path.join(HERE, "..", "..", "region_data", "JL_NAMWON_UNBONG"))
X_LO, X_HI = -400.0, -338.0
HW = 3.1          # 대로 반폭(build_mountain lay와 같음)
BANK = 3.0        # 둑 섞임 폭
BR = { "x_mt_tongyeong_byeolro_1": 51, "x_mt_tongyeong_byeolro_2": 52 }   # 건널목 → 다리 seed

R = json.load(open(os.path.join(DATA, "region.json")))
hm = R["height"]
a = np.array(Image.open(os.path.join(DATA, "height.png"))).astype(np.float64)
H = hm["y_min"] + a / 65535.0 * (hm["y_max"] - hm["y_min"])
X0, Z0, CELL = hm["x0"], hm["z0"], hm["cell"]

def samp(x, z):
	i = (x - X0) / CELL; j = (z - Z0) / CELL; i0 = int(i); j0 = int(j); fi = i - i0; fj = j - j0
	return H[j0, i0] * (1 - fi) * (1 - fj) + H[j0, i0 + 1] * fi * (1 - fj) + H[j0 + 1, i0] * (1 - fi) * fj + H[j0 + 1, i0 + 1] * fi * fj

road = [r for r in R["roads"] if r["id"] == "tongyeong_byeolro"][0]
P = np.array([p[:2] for p in road["points"]], float)
sel = np.nonzero((P[:, 0] >= X_LO) & (P[:, 0] <= X_HI) & (P[:, 1] > -900) & (P[:, 1] < -850))[0]
k0, k1 = sel.min(), sel.max()
C = P[k0:k1 + 1]
# 1m 간격 중심선 + 길이
seg = np.hypot(*np.diff(C, axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
ss = np.arange(0, s[-1] + 1e-6, 1.0)
cx = np.interp(ss, s, C[:, 0]); cz = np.interp(ss, s, C[:, 1])
# 끝 높이: 고칠 구간 바로 바깥(이미 고른 노면)에서
meta = R.setdefault("integ_fixes", [])
done = any(m.get("id") == "integ_pass_ford" for m in meta if isinstance(m, dict))
if done:
	y0, y1 = [m for m in meta if isinstance(m, dict) and m.get("id") == "integ_pass_ford"][0]["ends"]
else:
	y0 = float(samp(*C[0])); y1 = float(samp(*C[-1]))
# 다리 자리는 평평하게(다리 끝이 둑과 같은 높이 — 기운 노면이면 끝에 턱이 생긴다), 그 사이는 곧은 비탈
BRL = 7.0
knots_s = [0.0]; knots_y = [y0]
xs = sorted([float(np.argmin(np.hypot(cx - c["x"], cz - c["z"]))) for c in R["crossings"] if c["id"] in BR])
lin = lambda q: y0 + (y1 - y0) * q / ss[-1]
for q in xs:
	yq = lin(q)
	knots_s += [q - BRL / 2 - 1.5, q + BRL / 2 + 1.5]; knots_y += [yq, yq]
knots_s.append(float(ss[-1])); knots_y.append(y1)
prof = np.interp(ss, knots_s, knots_y)
# 물길 칸(여원치 골물): 물폭/2 + 0.8m 안은 건드리지 않는다
gol = [r for r in R["rivers"] if r["id"] == "yeowonchi_gol"][0]
G = np.array([p[:2] for p in gol["points"]], float)
gw = float(gol.get("width_m", 2.5)) / 2 + 0.8
from scipy.spatial import cKDTree
ct = cKDTree(np.stack([cx, cz], 1)); gt = cKDTree(G)
j0 = int((C[:, 1].min() - HW - BANK - Z0) / CELL) - 1; j1 = int((C[:, 1].max() + HW + BANK - Z0) / CELL) + 2
i0 = int((C[:, 0].min() - HW - BANK - X0) / CELL) - 1; i1 = int((C[:, 0].max() + HW + BANK - X0) / CELL) + 2
J, I = np.mgrid[j0:j1, i0:i1]
X = X0 + I * CELL; Z = Z0 + J * CELL
pts = np.stack([X.ravel(), Z.ravel()], 1)
d, k = ct.query(pts); dg, _ = gt.query(pts)
d = d.reshape(X.shape); k = k.reshape(X.shape); dg = dg.reshape(X.shape)
w = np.where(d <= HW, 1.0, np.clip(1.0 - (d - HW) / BANK, 0.0, 1.0))
w = w * w * (3 - 2 * w)
w[dg < gw] = 0.0
sub = H[j0:j1, i0:i1]
H[j0:j1, i0:i1] = sub + (prof[k] - sub) * w
changed = float(np.abs((prof[k] - sub) * w).max())
v = np.clip(np.round((H - hm["y_min"]) / (hm["y_max"] - hm["y_min"]) * 65535.0), 0, 65535).astype(np.uint16)
Image.fromarray(v).save(os.path.join(DATA, "height.png"), optimize=False)
# 건널목 → 돌다리 + 배치
pl = json.load(open(os.path.join(DATA, "placement_mountain.json")))
pl["items"] = [it for it in pl["items"] if not str(it.get("id", "")).startswith("mt_br_")]
for c in R["crossings"]:
	if c["id"] not in BR: continue
	c["type"] = "돌다리"
	c["notes"] = "integ-mountain: 대로가 골물을 건넘 — 홍예 돌다리(tools/mountain/fix_pass_ford.py)"
	kk = int(np.argmin(np.hypot(cx - c["x"], cz - c["z"])))
	a0 = max(kk - 3, 0); a1 = min(kk + 3, len(cx) - 1)
	ry = float(np.arctan2(cx[a1] - cx[a0], cz[a1] - cz[a0]))
	pl["items"].append({ "id": "mt_br_" + c["id"], "kit": "village/stone_bridge", "params": { "seed": BR[c["id"]], "len": 7.0, "hw": 1.6, "arch": 0.35 },
		"x": round(float(cx[kk]), 2), "z": round(float(cz[kk]), 2), "ry": round(ry, 4), "y": round(float(prof[kk]), 3), "flatten": False, "clear_veg": True,
		"group": "다리·징검다리(도강점)", "note": "여원치 골물 대로 홍예 돌다리(가설) — integ-mountain fix_pass_ford.py" })
if not done: meta.append({ "id": "integ_pass_ford", "ends": [y0, y1], "note": "여원재 대로 아랫주막 아래 노면 고름(약 %.0f%%) + 골물 건널목 돌다리 2 — tools/mountain/fix_pass_ford.py" % ((y1 - y0) / ss[-1] * 100) })
json.dump(pl, open(os.path.join(DATA, "placement_mountain.json"), "w"), ensure_ascii=False, indent=1)
json.dump(R, open(os.path.join(DATA, "region.json"), "w"), ensure_ascii=False, indent=1)
print("fix_pass_ford: %.0fm, %.2f→%.2f (%.1f%%), 최대 바꿈 %.2fm, 다리 %d" % (ss[-1], y0, y1, (y1 - y0) / ss[-1] * 100, changed, len(BR)))
