#!/usr/bin/env python3
"""남원·운봉 권역(JL_NAMWON_UNBONG) 실제 산 만들기 — 오프라인 지형 손질(mountain-terrain).

원본(실측 DEM, 가로·세로 K=0.30 같은 압축)을 바탕으로:
  1. 세로 되살림(고도 재매핑 f): 분지·고을 바닥(y≤30)은 그대로, 그 위는 1.5배 → 2배로 솟게 한다(단조 함수라 평탄지·물 높이 순서가 그대로).
  2. 산 디테일: 비탈·고지대에만 능선형 잡음(골·등성이·바위턱). 길·물·마을·논밭·배치 둘레는 건드리지 않는다.
  3. 여원치 고갯길: 통영별로의 여원재 오르막을 갈지자(대로 구배 ≤ 14%)로 다시 놓고, 골짜기 물(여원치 골물)·폭포·계곡길·능선길·
     교룡산 산길을 깎아(절토·성토 둑) 넣는다.
  4. 자리(slot): 재 마루 쉼터·암자 터·화전 터·굴 어귀·전망 바위 같은 평평한 터를 고르고, 이름 붙은 자리(anchor)로 남긴다.
  5. 가파른 비탈 → 바위·벼랑(토지이용 7), 물 높이·배치 y·논 필지 바닥을 같은 f로 옮긴다.

원본은 tools/mountain/cache/base/에 둔다(없으면 git 커밋 BASE_COMMIT에서 꺼냄) — 몇 번을 돌려도 같은 결과(결정적).
실행(miniconda 파이썬: numpy·scipy·PIL):
  /Users/sinjaeho/miniconda3/bin/python3 tools/mountain/build_mountain.py            # region_data에 쓴다
  /Users/sinjaeho/miniconda3/bin/python3 tools/mountain/build_mountain.py --dry      # 계산·검사만(쓰지 않음)
뒤처리(이 순서): python3 tools/region/parcels.py JL_NAMWON_UNBONG(논·밭 필지 — 새 땅에 맞춰) · render_joseon_map.py JL_NAMWON_UNBONG(지도) · make_travel_gates.py JL_NAMWON_UNBONG(말길)
  (모두 miniconda 파이썬. tools/mountain/rebuild.sh가 차례로 돌린다)
"""
import heapq, json, math, os, subprocess, sys, gzip, struct
import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
RID = "JL_NAMWON_UNBONG"
DATA = os.path.join(ROOT, "region_data", RID)
BASE = os.path.join(HERE, "cache", "base")
BASE_COMMIT = "1da7b59"   # claude/building-builder — 산 손질 전 마지막 데이터
GIT = "/opt/homebrew/bin/git"
BASE_FILES = ["height.png", "landuse.png", "region.json", "parcels.bin", "placement_east.json", "placement_namwon.json"]
DRY = "--dry" in sys.argv
SEED = 1870

# ---- 고도 재매핑 f (게임 y → 게임 y). 단조 증가·이음 매끈(기울기 1 → 1.5 → 2)
REMAP_SRC = [-100.0, 3.0, 30.0, 50.0, 386.0, 1000.0]
REMAP_DST = [-100.0, 3.0, 30.0, 60.0, 732.0, 1960.0]
def f(y): return np.interp(y, REMAP_SRC, REMAP_DST)

X0, Z0, CELL = -4352.0, -2112.0, 2.0
LCELL = 4.0

def log(*a): print(*a, flush=True)

# ----------------------------------------------------------------------------- 입출력
def base_path(name):
	p = os.path.join(BASE, name)
	if not os.path.exists(p):
		os.makedirs(BASE, exist_ok=True)
		blob = subprocess.check_output([GIT, "-C", ROOT, "show", f"{BASE_COMMIT}:seolhwa_godot/region_data/{RID}/{name}"])
		open(p, "wb").write(blob)
	return p

def load_height():
	im = Image.open(base_path("height.png"))
	a = np.array(im).astype(np.float64)
	R = json.load(open(base_path("region.json")))
	hm = R["height"]
	return hm["y_min"] + a / 65535.0 * (hm["y_max"] - hm["y_min"]), R

def save_height(H, R):
	lo = math.floor(H.min()) - 1.0; hi = math.ceil(H.max()) + 1.0
	v = np.clip(np.round((H - lo) / (hi - lo) * 65535.0), 0, 65535).astype(np.uint16)
	R["height"]["y_min"] = lo; R["height"]["y_max"] = hi
	if not DRY:
		Image.fromarray(v).save(os.path.join(DATA, "height.png"), optimize=False)
	return lo, hi

# ----------------------------------------------------------------------------- 좌표·표본
NZ = NX = 0
def ij(x, z): return (np.asarray(z) - Z0) / CELL, (np.asarray(x) - X0) / CELL
def sample(H, x, z):
	j, i = ij(x, z)
	return ndimage.map_coordinates(H, [np.atleast_1d(j), np.atleast_1d(i)], order=1, mode="nearest")
def cell_xz(j, i): return X0 + i * CELL, Z0 + j * CELL

def smooth01(t): t = np.clip(t, 0.0, 1.0); return t * t * (3 - 2 * t)
def sstep(a, b, x): return smooth01((x - a) / (b - a))

def raster_polyline(shape, pts, r, cell=CELL):
	"""선분 둘레 r 안 칸 True(거리 변환용 씨앗)."""
	m = np.zeros(shape, bool)
	pts = np.asarray(pts, float)
	if len(pts) == 0: return m
	if len(pts) == 1: pts = np.vstack([pts, pts])
	for a, b in zip(pts[:-1], pts[1:]):
		L = max(np.hypot(*(b - a)), 1e-6)
		n = int(L / (cell * 0.5)) + 1
		for t in np.linspace(0, 1, n + 1):
			x, z = a + (b - a) * t
			j = int(round((z - Z0) / cell)); i = int(round((x - X0) / cell))
			k = int(math.ceil(r / cell))
			m[max(0, j - k):j + k + 1, max(0, i - k):i + k + 1] = True
	return m

def resample(pts, step=1.0):
	pts = np.asarray(pts, float)
	seg = np.hypot(*np.diff(pts, axis=0).T)
	s = np.concatenate([[0], np.cumsum(seg)])
	ss = np.arange(0, s[-1] + 1e-6, step)
	if ss[-1] < s[-1] - 1e-6: ss = np.append(ss, s[-1])
	return np.stack([np.interp(ss, s, pts[:, 0]), np.interp(ss, s, pts[:, 1])], 1), ss

def chaikin(pts, n=2):
	pts = np.asarray(pts, float)
	for _ in range(n):
		q = [pts[0]]
		for a, b in zip(pts[:-1], pts[1:]):
			q.append(a * 0.75 + b * 0.25); q.append(a * 0.25 + b * 0.75)
		q.append(pts[-1]); pts = np.array(q)
	return pts

# ----------------------------------------------------------------------------- 값 잡음(결정적)
def value_noise(shape, wl_cells, rng):
	gh = int(shape[0] / wl_cells) + 4; gw = int(shape[1] / wl_cells) + 4
	g = rng.random((gh, gw))
	z = ndimage.zoom(g, (wl_cells, wl_cells), order=3)
	return np.clip(z[:shape[0], :shape[1]], 0, 1)

# ----------------------------------------------------------------------------- A* 길 찾기(4m 격자, 16방향)
MOVES = [(0, 1), (1, 0), (0, -1), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1),
         (1, 2), (2, 1), (-1, 2), (-2, 1), (1, -2), (2, -1), (-1, -2), (-2, -1)]
def astar(H, a, b, g0, gcap, avoid=None, prefer=None, step=5.0, pad=160.0, side_w=0.6, turn_w=4.0):
	"""a, b: (x, z). 상태 = (칸, 들어온 방향) — 꺾을 때마다 벌점(turn_w·Δ각²·m)이라 길이 잘게 흔들리지 않고 갈지자는 굵게 꺾인다.
	구배 g0까지는 벌점 없음, gcap 넘으면 큰 벌점, gcap×1.8 넘는 걸음은 못 감. avoid: 2m 격자 벌점(추가 비용/m), prefer: 2m 격자 할인(0..1)."""
	xa, za = a; xb, zb = b
	bx0 = min(xa, xb) - pad; bx1 = max(xa, xb) + pad; bz0 = min(za, zb) - pad; bz1 = max(za, zb) + pad
	nx = int((bx1 - bx0) / step) + 1; nz = int((bz1 - bz0) / step) + 1
	gx = bx0 + np.arange(nx) * step; gz = bz0 + np.arange(nz) * step
	GX, GZ = np.meshgrid(gx, gz)
	h = sample(H, GX.ravel(), GZ.ravel()).reshape(nz, nx)
	h = ndimage.gaussian_filter(h, 1.0)   # 잡음 디테일·바위턱은 깎아 내므로 길 고르기는 살짝 흐린 땅으로
	sy, sx = np.gradient(h, step)
	sl2 = np.minimum(sx * sx + sy * sy, 4.0)
	extra = np.zeros_like(h)
	if avoid is not None:
		jj, ii = ij(GX, GZ)
		extra += ndimage.map_coordinates(avoid, [jj.ravel(), ii.ravel()], order=0, mode="nearest").reshape(nz, nx)
	disc = np.ones_like(h)
	if prefer is not None:
		jj, ii = ij(GX, GZ)
		disc -= 0.5 * ndimage.map_coordinates(prefer, [jj.ravel(), ii.ravel()], order=1, mode="nearest").reshape(nz, nx)
	ang = [math.atan2(dj, di) for dj, di in MOVES]
	ND = len(MOVES)
	sa = (int(round((za - bz0) / step)), int(round((xa - bx0) / step)))
	sb = (int(round((zb - bz0) / step)), int(round((xb - bx0) / step)))
	INF = 1e18
	dist = np.full((nz, nx, ND + 1), INF)
	prev = -np.ones((nz, nx, ND + 1), np.int64)
	dist[sa[0], sa[1], ND] = 0.0
	pq = [(0.0, sa[0], sa[1], ND)]
	end = None
	while pq:
		d, j, i, dr = heapq.heappop(pq)
		if d > dist[j, i, dr]: continue
		if (j, i) == sb: end = (j, i, dr); break
		for m, (dj, di) in enumerate(MOVES):
			jj2, ii2 = j + dj, i + di
			if not (0 <= jj2 < nz and 0 <= ii2 < nx): continue
			L = step * math.hypot(dj, di)
			gr = abs(h[jj2, ii2] - h[j, i]) / L
			if gr > gcap * 1.8: continue
			pen = 0.0 if gr <= g0 else ((gr - g0) / max(gcap - g0, 1e-3)) ** 2 * 6.0
			if gr > gcap: pen += 60.0 * (gr - gcap) / gcap
			tc = 0.0
			if dr < ND:
				da = abs((ang[m] - ang[dr] + math.pi) % (2 * math.pi) - math.pi)
				tc = turn_w * da * da * step
			c = L * (disc[jj2, ii2] * (1.0 + side_w * sl2[jj2, ii2]) + pen + extra[jj2, ii2]) + tc
			nd = d + c
			if nd < dist[jj2, ii2, m]:
				dist[jj2, ii2, m] = nd; prev[jj2, ii2, m] = (j * nx + i) * (ND + 1) + dr
				heapq.heappush(pq, (nd, jj2, ii2, m))
	if end is None: raise RuntimeError(f"A* 실패 {a}→{b} (g0={g0}, gcap={gcap})")
	out = []; st = end
	while True:
		j, i, dr = st; out.append((gx[i], gz[j]))
		if (j, i) == sa and dr == ND: break
		k = prev[j, i, dr]
		if k < 0: break
		cell, dr2 = divmod(k, ND + 1); st = (cell // nx, cell % nx, dr2)
	out.reverse()
	out[0] = (xa, za); out[-1] = (xb, zb)
	return out

def simplify(pts, tol=2.5):
	"""더글러스–포이커(작은 계단 지우기)."""
	pts = np.asarray(pts, float)
	if len(pts) < 3: return pts
	keep = np.zeros(len(pts), bool); keep[0] = keep[-1] = True
	st = [(0, len(pts) - 1)]
	while st:
		a, b = st.pop()
		if b <= a + 1: continue
		ab = pts[b] - pts[a]; L = np.linalg.norm(ab)
		v = pts[a + 1:b] - pts[a]
		d = np.abs(ab[0] * v[:, 1] - ab[1] * v[:, 0]) / L if L > 1e-9 else np.linalg.norm(v, axis=1)
		k = int(np.argmax(d))
		if d[k] > tol: keep[a + 1 + k] = True; st += [(a, a + 1 + k), (a + 1 + k, b)]
	return pts[keep]

def smooth_path(pts, tol=2.5, n=3): return chaikin(simplify(pts, tol), n)

# ----------------------------------------------------------------------------- 깎기
def grade_limit(y, ds, g, pin_start=True, pin_end=True, iters=6):
	y = y.copy()
	for _ in range(iters):
		for k in range(1, len(y)): y[k] = np.clip(y[k], y[k - 1] - g * ds, y[k - 1] + g * ds)
		for k in range(len(y) - 2, -1, -1): y[k] = np.clip(y[k], y[k + 1] - g * ds, y[k + 1] + g * ds)
	return y

def road_profile(H, pts, gmax, win=10, y0=None, y1=None):
	xy, s = resample(pts, 1.0)
	t = sample(H, xy[:, 0], xy[:, 1])
	if win > 1: t = ndimage.uniform_filter1d(t, size=2 * win + 1, mode="nearest")
	if y0 is not None: t[0] = y0
	if y1 is not None: t[-1] = y1
	# 끝점 고정 + 구배 제한: 앞·뒤로 번갈아 조이고, 끝점은 다시 박는다
	for _ in range(4):
		t = grade_limit(t, 1.0, gmax)
		if y0 is not None: t[0] = y0
		if y1 is not None: t[-1] = y1
	return xy, s, t

def carve(H, xy, tgt, hw, bank=0.9, reach=30.0, only_cut=False, only_fill=False, landuse=None, lu_val=None, lu_hw=None, keep=None):
	x0 = xy[:, 0].min() - hw - reach; x1 = xy[:, 0].max() + hw + reach
	z0 = xy[:, 1].min() - hw - reach; z1 = xy[:, 1].max() + hw + reach
	j0 = max(0, int((z0 - Z0) / CELL)); j1 = min(H.shape[0] - 1, int((z1 - Z0) / CELL) + 1)
	i0 = max(0, int((x0 - X0) / CELL)); i1 = min(H.shape[1] - 1, int((x1 - X0) / CELL) + 1)
	J, I = np.mgrid[j0:j1 + 1, i0:i1 + 1]
	X = X0 + I * CELL; Z = Z0 + J * CELL
	tree = cKDTree(xy)
	d, k = tree.query(np.stack([X.ravel(), Z.ravel()], 1), distance_upper_bound=hw + reach)
	ok = np.isfinite(d)
	d = d.reshape(X.shape); k = np.where(ok, k, 0).reshape(X.shape); ok = ok.reshape(X.shape)
	sub = H[j0:j1 + 1, i0:i1 + 1]
	t = tgt[k]
	dh = sub - t
	B = np.clip(np.abs(dh) / bank, 1.0, reach)
	u = (d - hw) / B
	w = np.where(d <= hw, 1.0, np.where(u < 1.0, 1.0 - smooth01(u), 0.0)) * ok
	if keep is not None: w = w * ~keep[j0:j1 + 1, i0:i1 + 1]
	if only_cut: w = np.where(dh > 0, w, 0.0)
	if only_fill: w = np.where(dh < 0, w, 0.0)
	H[j0:j1 + 1, i0:i1 + 1] = sub + (t - sub) * w
	if landuse is not None and lu_val is not None:
		core = ok & (d <= (lu_hw if lu_hw is not None else hw))
		jj = (J[core] * CELL) / LCELL; ii = (I[core] * CELL) / LCELL
		landuse[np.clip(np.round(jj).astype(int), 0, landuse.shape[0] - 1), np.clip(np.round(ii).astype(int), 0, landuse.shape[1] - 1)] = lu_val
	return float(np.abs((t - sub) * w).max()) if w.any() else 0.0

def flatten_pad(H, cx, cz, rx, rz, ry=0.0, y=None, edge=6.0):
	"""회전 사각 터를 높이 y(없으면 가운데 평균)로 고르고 edge m에 걸쳐 원래 땅에 잇는다."""
	R = math.hypot(rx, rz) + edge + 2
	j0 = max(0, int((cz - R - Z0) / CELL)); j1 = int((cz + R - Z0) / CELL) + 1
	i0 = max(0, int((cx - R - X0) / CELL)); i1 = int((cx + R - X0) / CELL) + 1
	J, I = np.mgrid[j0:j1 + 1, i0:i1 + 1]
	X = X0 + I * CELL - cx; Z = Z0 + J * CELL - cz
	c, s = math.cos(ry), math.sin(ry)
	lx = X * c - Z * s; lz = X * s + Z * c
	ex = np.maximum(np.abs(lx) - rx, 0); ez = np.maximum(np.abs(lz) - rz, 0)
	e = np.hypot(ex, ez)
	sub = H[j0:j1 + 1, i0:i1 + 1]
	if y is None: y = float(sub[e <= 0].mean())
	w = 1.0 - smooth01(e / edge)
	H[j0:j1 + 1, i0:i1 + 1] = sub + (y - sub) * w
	return y

# ----------------------------------------------------------------------------- 물(골물) 경로
def flow_trace(H, src, stop_xy, max_len=3000.0, step=2.0):
	"""src에서 가장 가파른 내리막을 따라(살짝 흐린 땅) stop_xy 반경 12m에 닿거나 고이면 멈춘다."""
	Hs = ndimage.gaussian_filter(H, 1.5)
	x, z = src; pts = [(x, z)]
	L = 0.0
	while L < max_len:
		j, i = int(round((z - Z0) / CELL)), int(round((x - X0) / CELL))
		best = None; bh = Hs[j, i]
		for dj in (-1, 0, 1):
			for di in (-1, 0, 1):
				if dj == di == 0: continue
				hh = Hs[j + dj, i + di]
				if hh < bh - 1e-4: bh = hh; best = (dj, di)
		if best is None:
			# 웅덩이: 가장 낮은 이웃(같거나 조금 높음)으로 넘긴다
			cand = [(Hs[j + dj, i + di], (dj, di)) for dj in (-2, -1, 0, 1, 2) for di in (-2, -1, 0, 1, 2) if (dj, di) != (0, 0) and (x + di * CELL, z + dj * CELL) not in pts[-6:]]
			best = min(cand)[1]
		x += best[1] * CELL; z += best[0] * CELL
		pts.append((x, z)); L += CELL * math.hypot(*best)
		if math.hypot(x - stop_xy[0], z - stop_xy[1]) < 12.0: pts.append(tuple(stop_xy)); break
	return pts

# ============================================================================= 본 처리
def main():
	H0, R = load_height()
	H = f(H0)
	shape = H.shape
	LU = np.array(Image.open(base_path("landuse.png"))).astype(np.uint8)
	log("원본", H0.min(), H0.max(), "→ 재매핑", H.min().round(1), H.max().round(1))
	rivers = R["rivers"]; roads = R["roads"]
	for r in rivers:
		for p in r["points"]: p[2] = round(float(f(p[2])), 3)
	for k in ("passes", "landmarks"):
		for p in R.get(k, []):
			if p.get("y") is not None: p["y"] = round(float(f(p["y"])), 2)
	pl = {}
	for name in ["placement_east.json", "placement_namwon.json"]:
		d = json.load(open(base_path(name)))
		n = 0
		for it in d["items"]:
			if it.get("y") is not None:
				it["y"] = round(float(f(it["y"])), 3); n += 1
		pl[name] = d; log(name, "y 옮김", n)

	# ---- 지킬 곳(산 디테일 금지): 길·물·마을·논밭·배치
	prot = np.zeros(shape, bool)
	for r in roads: prot |= raster_polyline(shape, [p[:2] for p in r["points"]], float(r.get("width_m", 3)) / 2 + 3)
	for r in rivers: prot |= raster_polyline(shape, [p[:2] for p in r["points"]], max(float(r.get("width_m", 2.5)), 5.2) / 2 + 6)
	lu2 = np.repeat(np.repeat(LU, 2, 0), 2, 1)[:shape[0], :shape[1]] & 127
	prot |= np.isin(lu2, [2, 3, 4, 5, 6, 8, 9])
	for s in R["settlements"]:
		bb = s.get("bbox")
		if bb:
			j0, i0 = [int(v) for v in ij(bb[0], bb[1])]; j1, i1 = [int(v) for v in ij(bb[2], bb[3])]
			# bbox: [x0, z0, x1, z1]
			jj0, ii0 = int((bb[1] - Z0) / CELL), int((bb[0] - X0) / CELL); jj1, ii1 = int((bb[3] - Z0) / CELL), int((bb[2] - X0) / CELL)
			prot[max(0, jj0):jj1 + 1, max(0, ii0):ii1 + 1] = True
	for d in pl.values():
		for it in d["items"]:
			j = int((it["z"] - Z0) / CELL); i = int((it["x"] - X0) / CELL)
			prot[max(0, j - 8):j + 9, max(0, i - 8):i + 9] = True
	sp = json.load(open(os.path.join(DATA, "placement_story_namwon.json")))
	for it in sp["items"]:
		assert it.get("y") is None or it["y"] < REMAP_SRC[2], "이야기 배치 y가 재매핑 구간에 든다"
		j = int((it["z"] - Z0) / CELL); i = int((it["x"] - X0) / CELL)
		prot[max(0, j - 15):j + 16, max(0, i - 15):i + 16] = True
	dprot = ndimage.distance_transform_edt(~prot) * CELL

	# ---- 남원 배산: 교룡산 남동 줄기를 읍성 서북쪽 뒤까지 끌어내린다(그림 값 — 광치천·지류 물길과 이야기 무대(북쪽 숲)는 비킨다)
	spur = np.array([(-3830.0, -370.0, 168.0), (-3700.0, -235.0, 122.0), (-3600.0, -120.0, 84.0), (-3545.0, -20.0, 56.0), (-3528.0, 40.0, 40.0)])
	sx0, sx1, sz0, sz1 = -4000.0, -3300.0, -560.0, 220.0
	j0, j1 = int((sz0 - Z0) / CELL), int((sz1 - Z0) / CELL); i0, i1 = int((sx0 - X0) / CELL), int((sx1 - X0) / CELL)
	J, I = np.mgrid[j0:j1, i0:i1]; XX = X0 + I * CELL; ZZ = Z0 + J * CELL
	sxy, _ = resample(spur[:, :2], 2.0)
	crest = np.interp(np.concatenate([[0], np.cumsum(np.hypot(*np.diff(spur[:, :2], axis=0).T))]), np.concatenate([[0], np.cumsum(np.hypot(*np.diff(spur[:, :2], axis=0).T))]), spur[:, 2])
	sl_ = np.concatenate([[0], np.cumsum(np.hypot(*np.diff(spur[:, :2], axis=0).T))])
	cs = np.interp(np.concatenate([[0], np.cumsum(np.hypot(*np.diff(sxy, axis=0).T))]), sl_, spur[:, 2])
	dd, kk = cKDTree(sxy).query(np.stack([XX.ravel(), ZZ.ravel()], 1))
	dd = dd.reshape(XX.shape); cz = cs[kk].reshape(XX.shape)
	# 끝(읍성 쪽)은 둥글게 낮아진다
	nrng = np.random.default_rng(SEED + 3)
	nn = value_noise(XX.shape, 38, nrng); nf = value_noise(XX.shape, 14, nrng)
	# 옆 등줄기·골이 갈라지게: 거리를 잡음으로 늘이고 줄인다(등고선이 들쭉날쭉)
	de = dd * (0.72 + 0.62 * nn + 0.06 * (nf - 0.5))
	cone = cz * (0.92 + 0.16 * nn) - 0.62 * de - 0.0018 * de * de
	sub = H[j0:j1, i0:i1]
	riv = np.zeros(shape, bool)
	for r in rivers: riv |= raster_polyline(shape, [p[:2] for p in r["points"]], 4.0)
	for r in roads:
		if r["class"] in ("대로", "지선"): riv |= raster_polyline(shape, [p[:2] for p in r["points"]], 4.0)
	sp0 = json.load(open(os.path.join(DATA, "placement_story_namwon.json")))
	for it in sp0["items"]:
		j = int((it["z"] - Z0) / CELL); i = int((it["x"] - X0) / CELL); riv[max(0, j - 2):j + 3, max(0, i - 2):i + 3] = True
	dr = (ndimage.distance_transform_edt(~riv[j0:j1, i0:i1]) * CELL)
	wm = sstep(25.0, 70.0, dr)
	add = np.maximum(cone - sub, 0.0)
	# 부드러운 최대(산발치가 들과 매끈하게 이어지게)
	add = add * add / (add + 6.0)
	H[j0:j1, i0:i1] = sub + add * wm
	# 솟은 줄기 위 들(풀밭·논·밭) → 숲(줄기에 다랑이가 얹히지 않게 — 필지는 parcels.py가 다시 만든다)
	raised = np.zeros(shape, bool); raised[j0:j1, i0:i1] = add * wm > 3.0
	r4 = raised[::2, ::2][:LU.shape[0], :LU.shape[1]]
	LU[r4 & np.isin(LU & 127, [1, 2, 3])] = 0
	log("남원 배산(교룡산 남동 줄기): 최대 돋움 %.1fm" % (add * wm).max())

	# ---- 산 디테일: 능선형 잡음(등성이·골·바위턱) — 비탈·고지대·지킬 곳에서 먼 곳만
	rng = np.random.default_rng(SEED)
	gy, gx = np.gradient(H, CELL); slope = np.hypot(gx, gy)
	n1 = value_noise(shape, 70, rng); n2 = value_noise(shape, 26, rng); n3 = value_noise(shape, 10, rng)
	ridged = lambda n: 1.0 - np.abs(2.0 * n - 1.0)
	det = (ridged(n1) - 0.62) * 13.0 + (ridged(n2) - 0.62) * 5.0 + (n3 - 0.5) * 2.2
	mask = sstep(0.22, 0.6, slope) * sstep(40.0, 90.0, H) * sstep(10.0, 40.0, dprot)
	H += det * mask
	H_pre = H.copy()   # 물·길 깎기 전(절개면 찾기)
	log("산 디테일: 최대 |Δ| %.1fm, 적용 비율 %.1f%%" % (np.abs(det * mask).max(), (mask > 0.05).mean() * 100))

	anchors = []; new_roads = []; new_rivers = []; new_cross = []; props = []
	def anchor(id, name, typ, x, z, notes="", route=None, r=6.0, refs=None, view=None):
		a = { "id": id, "name": name, "type": typ, "x": round(float(x), 1), "z": round(float(z), 1), "y": None, "r": r, "notes": notes }
		if route: a["route"] = route
		if refs: a["refs"] = refs
		if view is not None: a["view_yaw"] = view
		anchors.append(a); return a

	# ---- 1) 여원치 골물(시냇물·폭포): 재 아래 남쪽 골(−44,−770)에서 시작 → 골짜기 → 아랫주막 남쪽 → r072 머리
	tong = next(r for r in roads if r["id"] == "tongyeong_byeolro")
	r072 = next(r for r in rivers if r["id"] == "r072")
	src = (-46.0, -778.0)
	head = tuple(r072["points"][0][:2])
	raw = flow_trace(H, src, head)
	# 길·주막과 떨어뜨리기: 대로(옛 선형) 중심에서 11m, 주막 묶음 둘레(−322,−889)·(−334,−852)는 남쪽으로 비킨다
	old_tong = np.array([p[:2] for p in tong["points"]])
	ttree = cKDTree(old_tong)
	pts = np.array(raw, float)
	pts = chaikin(pts[::3], 2)
	xy, s = resample(pts, 2.0)
	for k in range(len(xy)):
		d, q = ttree.query(xy[k])
		if d < 11.0 and s[k] > 60:
			a = old_tong[max(q - 1, 0)]; b = old_tong[min(q + 1, len(old_tong) - 1)]
			tdir = (b - a) / max(np.linalg.norm(b - a), 1e-6); nrm = np.array([-tdir[1], tdir[0]])
			side = np.sign(np.dot(xy[k] - old_tong[q], nrm)) or 1.0
			if -360 < xy[k][0] < -290: side = 1.0 if nrm[1] > 0 else -1.0   # 주막 곁은 남쪽(+z)
			xy[k] = old_tong[q] + nrm * side * 11.0
	xy = ndimage.uniform_filter1d(xy, 5, axis=0, mode="nearest")
	xy[-1] = head
	xy, s = resample(xy, 1.0)
	# 수면: 둘레 2m 최저 땅을 따라 단조 감소(하류 끝은 r072 머리 수면 이상)
	t = np.minimum.reduce([sample(H, xy[:, 0] + dx, xy[:, 1] + dz) for dx, dz in [(0, 0), (2, 0), (-2, 0), (0, 2), (0, -2)]])
	t = ndimage.uniform_filter1d(t, 5, mode="nearest") - 0.3
	wy = np.minimum.accumulate(t)
	wy = np.maximum(wy, r072["points"][0][2] + 0.05)
	# 폭포: 6m 안에서 2.5m 넘게 떨어지는 곳(가장 큰 곳 하나 + 그 밖 작은 폭포·여울)
	drops = []
	for k in range(len(wy) - 6):
		dd = wy[k] - wy[k + 6]
		if dd > 2.5: drops.append((dd, k))
	falls = []
	for dd, k in sorted(drops, reverse=True):
		if all(abs(k - q) > 25 for _, q in falls): falls.append((dd, k))
	falls = sorted(falls[:3], key=lambda v: v[1])
	# 바닥 = 수면 − 0.45, 폭 반 2.8m 물길을 판다(둑 비탈 0.9)
	carve(H, xy, wy - 0.45, 2.8, bank=0.9, reach=14.0, landuse=LU, lu_val=5, lu_hw=2.0)
	new_rivers.append({ "id": "yeowonchi_gol", "name": "여원치 골물", "grade": "D", "width_m": 2.5, "flows_to": "r072", "parent": "r072",
		"catchment_km2": 0.6, "source": "mountain-terrain(2026-10-21): 재매핑 땅의 흐름 추적 + 길 비킴", "confidence": "가설",
		"points": [[round(float(a), 1), round(float(b), 1), round(float(c), 3)] for (a, b), c in zip(xy[::4], wy[::4])] + ([[float(xy[-1][0]), float(xy[-1][1]), round(float(wy[-1]), 3)]] if (len(xy) - 1) % 4 else []),
		"widths": [] , "notes": "재 아래 남쪽 골에서 나와 여원치 골짜기를 따라 아랫주막 남쪽을 지나 백암천 지류(r072) 머리에 듦. 폭포 %d곳." % len(falls) })
	new_rivers[-1]["widths"] = [2.5] * len(new_rivers[-1]["points"])
	gol_xy = xy; gol_wy = wy
	for n, (dd, k) in enumerate(falls):
		kb = min(k + 6, len(xy) - 1)
		px, pz = xy[kb]; up = xy[max(k - 2, 0)] - xy[kb]; up /= max(np.linalg.norm(up), 1e-6)
		ry = math.atan2(-up[0], -up[1])
		props.append({ "id": f"mt_falls_{n+1:02d}", "kit": "route/waterfall", "params": { "seed": 81 + n, "h": round(float(min(dd + 1.0, 8.0)), 2), "w": 1.6, "r": 3.4, "water_y": 0.06 },
			"x": round(float(px), 2), "z": round(float(pz), 2), "ry": round(ry, 4), "y": round(float(wy[kb] - 0.06), 3), "flatten": False, "clear_veg": True, "group": "여원치 골(산 지형)" })
		anchor(f"yw_falls_{n+1}", "여원치 골 폭포" + ("" if n == 0 else f" {n+1}"), "폭포·소", px, pz, "골물이 바위턱에서 %.1fm 떨어져 소를 이룬다" % dd, "yw_valley_trail" if pz < -880 and px < -60 else "yw_gully_trail", r=9.0)
	log("골물: 길이 %.0fm, 수면 %.1f→%.1f, 폭포 %s" % (s[-1], wy[0], wy[-1], [(round(d, 1), int(k)) for d, k in falls]))

	# 물길 핵심 칸(길 깎기가 메우지 않는다 — 건널목은 여울·징검다리로 물속을 걸어 건넘): 모든 하천 + 골물
	all_rivers = rivers + new_rivers
	river_core = np.zeros(shape, bool)
	for r in all_rivers:
		river_core |= raster_polyline(shape, [p[:2] for p in r["points"]], max(float(r.get("width_m", 2.5)), 5.2) / 2 * 0.8 + 0.4)
	# 물길 벌점 격자(길 A*가 물을 따라 걷지 않게, 건너기는 허용)
	water_av = np.zeros(shape)
	for r in all_rivers:
		mm = raster_polyline(shape, [p[:2] for p in r["points"]], max(float(r.get("width_m", 2.5)), 5.2) / 2 + 3)
		water_av[mm] = 3.0
	# 배치(건물·소품·이야기 무대) 둘레는 길이 뚫지 않게
	pl_av = np.zeros(shape)
	def av_r(kit):
		if kit.startswith("landmark/"): return 32.0
		if kit.startswith("bldg/") or any(k in kit for k in ("compound", "jumak", "choga", "giwa", "heotgan", "teotbat")): return 12.0
		if kit in ("route/waterfall", "nature/cliff"): return 8.0
		return 4.0
	for it in [it for d in pl.values() for it in d["items"]] + sp["items"] + props:
		rr = int(av_r(str(it.get("kit", ""))) / CELL)
		j = int((it["z"] - Z0) / CELL); i = int((it["x"] - X0) / CELL); pl_av[max(0, j - rr):j + rr + 1, max(0, i - rr):i + rr + 1] = 40.0
	gt = cKDTree(gol_xy)
	TRAILS = []
	def lay(id, pts, hw, gmax, win, bank, reach, lu_hw, y0=None, y1=None):
		xy, s, t = road_profile(H, pts, gmax, win=win, y0=y0, y1=y1)
		if hw < 2.0: lu_hw = max(lu_hw, hw + 0.6)   # 산길: 길 칸(토지이용 4)을 넉넉히 — 식생 큰 바위·나무가 길에 걸치지 않게
		mx = carve(H, xy, t, hw, bank=bank, reach=reach, landuse=LU, lu_val=4, lu_hw=lu_hw, keep=river_core)
		TRAILS.append({ "id": id, "xy": xy, "hw": hw, "gmax": gmax, "win": win, "bank": bank, "reach": reach, "lu_hw": lu_hw, "y0": float(t[0]), "y1": y1 })
		return xy, s, t, mx
	def road_rec(id, name, cls, width, xy, every, src, notes):
		pts = [[round(float(a), 1), round(float(b), 1)] for a, b in xy[::every]]
		if (len(xy) - 1) % every: pts.append([round(float(xy[-1][0]), 1), round(float(xy[-1][1]), 1)])
		return { "id": id, "name": name, "class": cls, "width_m": width, "points": pts, "confidence": "가설", "source": src, "notes": notes }
	def g10(t): return np.max(np.abs(t[10:] - t[:-10])) / 10 * 100 if len(t) > 11 else 0.0

	# ---- 2) 통영별로 여원재 오르막 다시 놓기(갈지자, 대로 구배 ≤ 18%)
	P = np.array([p[:2] for p in tong["points"]])
	def nearest_idx(x, z): return int(np.argmin(np.hypot(P[:, 0] - x, P[:, 1] - z)))
	ia = nearest_idx(-1000.0, -560.0)   # 오르막 시작(백암천 골 어귀)
	ib = nearest_idx(126.0, -963.0)     # 재 넘어 운봉 쪽
	ipass = nearest_idx(35.4, -978.6)
	way1 = [tuple(P[ia]), (-326.0, -876.0)]                      # 골 어귀 → 아랫주막 앞(옛 선형 근처)
	way2 = [(-326.0, -876.0), (-58.0, -952.0), (35.4, -978.6)]   # 주막 → 마애불 아래 → 재 마루
	av = water_av + np.where(pl_av > 0, 12.0, 0.0)
	seg = []
	for ws, (g0, gcap) in [(way1, (0.10, 0.17)), (way2, (0.12, 0.19))]:
		for a, b in zip(ws[:-1], ws[1:]):
			p = astar(H, a, b, g0, gcap, avoid=av, side_w=0.8, turn_w=10.0)
			seg += p if not seg else p[1:]
	seg += [tuple(q) for q in P[ipass + 1:ib + 1]]
	seg = smooth_path(seg, 3.0)
	y_a = float(sample(H, *P[ia])[0]); y_b = float(sample(H, *P[ib])[0])
	xy, s, t, mx = lay("tongyeong_byeolro", seg, 3.1, 0.18, 8, 0.85, 26.0, 2.5, y0=y_a, y1=y_b)
	tong_head = [list(q) for q in P[:ia]]; tong_tail = [list(q) for q in P[ib + 1:]]
	tong["notes"] = tong.get("notes", "") + " / mountain-terrain(2026-10-21): 여원재 오르막(백암천 골 어귀→아랫주막→마애불 아래→재 마루)을 세로 되살림 지형에 맞춰 갈지자로 다시 놓음(구배 ≤ 18%)."
	log("통영별로 여원재 오르막: %.0fm, 높이 %.1f→%.1f, 최대 구배 %.1f%%(10m), 최대 깎기/돋우기 %.1fm" % (s[-1], t[0], t.max(), g10(t), mx))
	pass_route = xy
	ttree = cKDTree(xy)
	def on_tong(x, z):
		d, k = ttree.query((x, z)); q = xy[k]
		# 물길 핵심 칸이 아닌 가장 가까운 점
		for kk in sorted(range(max(0, k - 30), min(len(xy), k + 30)), key=lambda v: abs(v - k)):
			jj_, ii_ = ij(*xy[kk])
			if not river_core[int(round(float(jj_))), int(round(float(ii_)))]: return tuple(xy[kk])
		return tuple(q)

	# ---- 2b) 봉우리 너럭(전망 바위): 길 끝을 여기에 붙인다
	def top_of(c, r):
		pj, pi = ij(*c); r = int(r)
		hh = H[int(pj) - r:int(pj) + r + 1, int(pi) - r:int(pi) + r + 1]
		q = np.unravel_index(hh.argmax(), hh.shape); return cell_xz(int(pj) - r + q[0], int(pi) - r + q[1])
	peak = top_of((-326.0, -1150.0), 20)
	ypk = flatten_pad(H, peak[0], peak[1], 5.0, 4.0, 0.3, y=float(sample(H, *peak)[0]) - 0.6, edge=5.0)
	gy_peak = top_of((-4018.0, -415.0), 30)
	yg = flatten_pad(H, gy_peak[0], gy_peak[1], 5.0, 4.0, 0.0, y=float(sample(H, *gy_peak)[0]) - 0.6, edge=5.0)

	# ---- 3) 계곡길(산길): 아랫주막 동쪽 → 골물 북안을 따라 → 폭포 소 → 마애불 앞 대로
	valley_pts = []
	for k in range(len(gol_xy) - 1, 0, -1):
		x, z = gol_xy[k]
		if not (-300 < x < -70 and -960 < z < -862): continue
		tdir = gol_xy[k - 1] - gol_xy[k]; tdir /= max(np.linalg.norm(tdir), 1e-6); nrm = np.array([-tdir[1], tdir[0]])
		valley_pts.append(gol_xy[k] + nrm * 5.0)
	valley_pts = np.array(valley_pts[::10]) if valley_pts else np.zeros((0, 2))
	trail_av = pl_av.copy(); trail_av[raster_polyline(shape, gol_xy[::2], 6.0)] = 12.0; trail_av[raster_polyline(shape, gol_xy[::2], 3.6)] = 30.0
	near_gol = np.zeros(shape); near_gol[raster_polyline(shape, gol_xy[::2], 14.0)] = 1.0
	v_start = on_tong(-288.0, -888.0); v_end = on_tong(-62.0, -950.0)
	ws = [v_start] + [tuple(q) for q in valley_pts[1:-1:3]] + [v_end]
	trail = []
	for a, b in zip(ws[:-1], ws[1:]):
		p = astar(H, a, b, 0.18, 0.42, avoid=trail_av, prefer=near_gol, pad=60.0, side_w=0.5, turn_w=6.0)
		trail += p if not trail else p[1:]
	trail = smooth_path(trail, 2.0)
	vxy, vs, vt, _ = lay("yw_valley_trail", trail, 1.4, 0.36, 4, 0.95, 12.0, 1.0, y0=float(sample(H, *trail[0])[0]), y1=float(sample(H, *trail[-1])[0]))
	log("계곡길: %.0fm, %.1f→%.1f, 최대 구배(10m) %.0f%%" % (vs[-1], vt[0], vt[-1], g10(vt)))

	# ---- 3b) 골 오름길(산길): 계곡길 끝(마애불 앞) → 남쪽 골물을 따라 폭포 둘 → 바위굴 어귀(가파른 오르막)
	gully_end = None; cave = None
	if falls:
		kf = min(falls[0][1] + 6, len(gol_xy) - 1)
		up0 = gol_xy[max(falls[0][1] - 2, 0)] - gol_xy[kf]; up0 /= np.linalg.norm(up0); nrm0 = np.array([-up0[1], up0[0]])
		cave = gol_xy[kf] + nrm0 * 9.0 + up0 * 2.0
		cy = flatten_pad(H, cave[0], cave[1], 3.0, 2.5, math.atan2(up0[0], up0[1]), edge=4.0)
		gully_end = cave - up0 * 3.0          # 굴 어귀 앞(아래쪽) — 벼랑은 굴 뒤(위쪽)에 선다
		g_start = vxy[int(len(vxy) * 0.85)]   # 계곡길 위쪽(대로 깎은 비탈 들머리를 비킴)
		gp = astar(H, tuple(g_start), tuple(gully_end), 0.22, 0.6, avoid=trail_av, prefer=near_gol, pad=50.0, side_w=0.4, turn_w=5.0)
		gp = smooth_path(gp, 2.0)
		uxy, us, ut, _ = lay("yw_gully_trail", gp, 1.3, 0.55, 3, 1.0, 10.0, 0.9, y0=float(sample(H, *gp[0])[0]), y1=cy)
		log("골 오름길: %.0fm, %.1f→%.1f, 최대 구배(10m) %.0f%%" % (us[-1], ut[0], ut[-1], g10(ut)))

	# ---- 4) 능선길(백두대간 마루금): 재 마루 → 북쪽 봉우리 전망 바위
	ridge_prefer = np.clip((H - ndimage.uniform_filter(H, 41)) / 12.0, 0, 1)
	r_start = on_tong(42.0, -985.0)
	rw = [r_start, (-130.0, -1050.0), (-246.0, -1100.0), tuple(peak)]
	rt = []
	for a, b in zip(rw[:-1], rw[1:]):
		p = astar(H, a, b, 0.2, 0.55, avoid=pl_av, prefer=ridge_prefer, pad=70.0, side_w=0.3, turn_w=6.0)
		rt += p if not rt else p[1:]
	rt = smooth_path(rt, 2.0)
	rxy, rs, rtt, _ = lay("yw_ridge_trail", rt, 1.3, 0.5, 3, 1.0, 9.0, 0.9, y0=float(sample(H, *rt[0])[0]), y1=ypk)
	log("능선길: %.0fm, %.1f→%.1f, 봉우리 (%.0f,%.0f) y=%.1f, 최대 구배(10m) %.0f%%" % (rs[-1], rtt[0], rtt[-1], peak[0], peak[1], ypk, g10(rtt)))

	# ---- 5) 교룡산 산길: 남원 북쪽 길 → 교룡산 남동 줄기(배산) → 산성 동문 터 → 선국사 터(산사) → 정상
	ny = next(r for r in roads if r["id"] == "namwon_north_road")
	NP = np.array([p[:2] for p in ny["points"]])
	k0 = int(np.argmin(np.hypot(NP[:, 0] + 3175, NP[:, 1] + 152)))   # 광치천 징검다리·향교(−3247,−98) 북쪽 — 향교 담과 물을 비켜 서쪽으로
	gw = [tuple(NP[k0]), (-3520.0, -170.0), tuple(gy_peak)]
	g_av = pl_av.copy()
	for it in sp["items"]:
		j = int((it["z"] - Z0) / CELL); i = int((it["x"] - X0) / CELL); g_av[j - 12:j + 13, i - 12:i + 13] = 40.0
	gt_ = []
	for a, b in zip(gw[:-1], gw[1:]):
		p = astar(H, a, b, 0.16, 0.45, avoid=g_av + water_av, pad=120.0, side_w=0.6, turn_w=8.0)
		gt_ += p if not gt_ else p[1:]
	gt_ = smooth_path(gt_, 2.5)
	gxy, gs, gtt, _ = lay("gyoryong_trail", gt_, 1.4, 0.38, 5, 0.95, 12.0, 1.0, y0=float(sample(H, *gt_[0])[0]), y1=yg)
	log("교룡산 산길: %.0fm, %.1f→%.1f, 정상 (%.0f,%.0f), 최대 구배(10m) %.0f%%" % (gs[-1], gtt[0], gtt[-1], gy_peak[0], gy_peak[1], g10(gtt)))

	# ---- 6) 자리(slot) 고르기: 길 곁 가장 덜 가파른 곳을 찾아 평평하게(길에서 10m 넘으면 이음 오솔길)
	taken = [(it["x"], it["z"]) for d in pl.values() for it in d["items"]] + [(it["x"], it["z"]) for it in sp["items"]]
	taken_t = cKDTree(np.array(taken))
	slots = []
	def best_spot(route_xy, s_lo, s_hi, off_lo=6.0, off_hi=26.0, side=None):
		gy_, gx_ = np.gradient(ndimage.uniform_filter(H, 5), CELL); sl_ = np.hypot(gx_, gy_)
		tk = cKDTree(np.array(taken + [(a["x"], a["z"]) for a in slots])) if slots else taken_t
		best = None
		for k in range(int(s_lo), min(int(s_hi), len(route_xy) - 2), 3):
			tdir = route_xy[k + 1] - route_xy[k]; tdir /= max(np.linalg.norm(tdir), 1e-6); nrm = np.array([-tdir[1], tdir[0]])
			for sg in ([side] if side else [-1, 1]):
				for off in np.arange(off_lo, off_hi + 0.1, 3.0):
					c = route_xy[k] + nrm * sg * off
					if tk.query(c)[0] < 35.0: continue
					j, i = ij(*c)
					if river_core[int(j) - 6:int(j) + 7, int(i) - 6:int(i) + 7].any(): continue
					v = sl_[int(j) - 3:int(j) + 4, int(i) - 3:int(i) + 4].mean()
					if best is None or v < best[0]: best = (v, c, k)
		return best
	links = []
	def slot(id, name, typ, c, rx, rz, notes, route, route_xy, lu=4, ry=0.0, y=None, view=None):
		yy = flatten_pad(H, c[0], c[1], rx, rz, ry, y=y, edge=7.0)
		jj0, ii0 = int((c[1] - rz - Z0) / LCELL), int((c[0] - rx - X0) / LCELL); jj1, ii1 = int((c[1] + rz - Z0) / LCELL), int((c[0] + rx - X0) / LCELL)
		LU[jj0:jj1 + 1, ii0:ii1 + 1] = lu
		d, k = cKDTree(route_xy).query(c)
		if d > 10.0:   # 이음 오솔길
			links.append((id, tuple(route_xy[k]), tuple(c), route))
			route = id + "_path"
		a = anchor(id, name, typ, c[0], c[1], notes, route, r=max(rx, rz), view=view); a["y"] = round(yy, 2); a["slot"] = [rx * 2, rz * 2]
		slots.append(a); return a
	k_top = int(np.argmin(np.hypot(pass_route[:, 0] - 35.4, pass_route[:, 1] + 978.6)))
	ytop = float(sample(H, *pass_route[k_top])[0])
	anchor("yw_jaemaru", "여원재 재 마루(고갯마루)", "재 마루", 35.4, -978.6, "섬진·낙동 분수계. 서낭당 돌무더기·신목·장승 한 쌍·고갯마루 주막(배치 ea_yw_*)이 이미 있다.", "tongyeong_byeolro",
		r=25.0, refs=["ea_yw_seonghwangdang_01", "ea_yw_sinmok_01", "ea_yw_jangseung_01", "ea_yw_jangseung_02", "ea_yw_jumak_01"], view=-110.0)
	anchor("yw_seonang", "여원재 서낭당 돌무더기", "서낭당·장승", 37.0, -988.0, "돌을 얹고 지나가는 자리. 장승 한 쌍이 길 양쪽에 선다.", "tongyeong_byeolro", r=10.0, refs=["ea_yw_seonghwangdang_01", "ea_yw_jangseung_01", "ea_yw_jangseung_02"])
	anchor("yw_top_jumak", "고갯마루 주막(쉼터)", "주막·쉼터", 75.0, -986.0, "재를 넘는 길손이 쉬는 주막 — 이미 배치(ea_yw_jumak_01).", "tongyeong_byeolro", r=14.0, refs=["ea_yw_jumak_01"])
	slot("yw_top_swimteo", "재 마루 쉼터 마당", "쉼터 터", (12.0, -965.0), 7.0, 5.0, "재 마루 서쪽 너럭 마당(빈 터) — 남원 쪽으로 내려다보인다.", "tongyeong_byeolro", pass_route, y=ytop, view=-110.0)
	anchor("yw_lower_jumak", "여원재 아랫주막", "주막·쉼터", -326.0, -876.0, "오르막 들머리 주막(ea_yj_*).", "tongyeong_byeolro", r=14.0, refs=["ea_yj_jumak_01", "ea_yj_choga_01"])
	anchor("yw_maaebul", "여원치 마애불", "바위·마애불", -40.8, -938.8, "재 마루 조금 못 미친 길가 바위 얼굴(landmark).", "tongyeong_byeolro", r=16.0, refs=["ea_yw_maaebul_01"])
	if falls and cave is not None:
		k = min(falls[0][1] + 6, len(gol_xy) - 1)
		fx, fz = gol_xy[k]
		up = gol_xy[max(falls[0][1] - 2, 0)] - gol_xy[k]; up /= np.linalg.norm(up); nrm = np.array([-up[1], up[0]])
		ry = math.atan2(-up[0], -up[1])   # 벼랑 앞면(+z)이 아래쪽(굴 어귀·길 쪽)을 본다
		props.append({ "id": "mt_cave_cliff", "kit": "nature/cliff", "params": { "w": 9.0, "h": 7.0, "d": 3.0, "seed": 7 },
			"x": round(float(cave[0] + up[0] * 4.5), 2), "z": round(float(cave[1] + up[1] * 4.5), 2), "ry": round(ry, 4), "y": None, "flatten": False, "clear_veg": True, "group": "여원치 골(산 지형)" })
		a = anchor("yw_cave", "여원치 골 바위굴 어귀", "동굴·바위굴", cave[0], cave[1], "폭포 곁 벼랑 밑 움푹한 바위굴 어귀(빈 자리 — 굴 안 공간은 아직 없음).", "yw_gully_trail", r=4.0)
		a["slot"] = [6.0, 5.0]
		anchor("yw_cliff", "여원치 골 벼랑", "바위·벼랑", fx + up[0] * 6, fz + up[1] * 6, "폭포를 이루는 바위 벼랑(가파른 바위 비탈 — 토지이용 바위).", "yw_gully_trail", r=10.0)
	b = best_spot(rxy, len(rxy) * 0.55, len(rxy) * 0.9, 10.0, 26.0)
	slot("yw_amja_teo", "능선 아래 암자 터", "산사·암자 터", b[1], 8.0, 6.0, "마루금 아래 남쪽 너럭 — 작은 암자가 앉을 빈 터(돌축대 자리).", "yw_ridge_trail", rxy)
	b = best_spot(pass_route, len(pass_route) * 0.45, len(pass_route) * 0.8, 16.0, 40.0)
	slot("yw_hwajeon", "여원치 화전 터", "화전·산촌", b[1], 14.0, 9.0, "갈지자 고갯길 곁 볕 드는 비탈 — 화전 밭뙈기·산막 한 채가 앉을 자리(밭 토지이용).", "tongyeong_byeolro", pass_route, lu=3)
	b2 = best_spot(pass_route, len(pass_route) * 0.2, len(pass_route) * 0.45, 18.0, 40.0)
	slot("yw_sanchon", "여원치 산촌 터", "화전·산촌", b2[1], 12.0, 8.0, "골 어귀 위 완만한 등 — 산촌 두어 집 자리(빈 터).", "tongyeong_byeolro", pass_route, lu=1)
	anchor("yw_peak_view", "능선 북쪽 봉우리 전망 바위", "전망·봉우리", peak[0], peak[1], "운봉 고원·지리산 줄기·남원 분지가 함께 보이는 바위 봉우리.", "yw_ridge_trail", r=6.0, view=-120.0)["y"] = round(ypk, 2)
	anchor("yw_forest_path", "여원치 계곡 숲길", "숲길", *vxy[len(vxy) // 3], "참나무·소나무 섞인 골짜기 숲 속 오솔길.", "yw_valley_trail")
	anchor("yw_switchback", "여원재 갈지자 고갯길", "고갯길", *pass_route[int(len(pass_route) * 0.7)], "아랫주막 위에서 재 마루까지 갈지자로 오르는 대로.", "tongyeong_byeolro")
	b = best_spot(gxy, len(gxy) * 0.45, len(gxy) * 0.62, 6.0, 20.0)
	slot("gy_sanseong_gate", "교룡산성 동문 터", "산성 터", b[1], 6.0, 4.0, "산성 동쪽 문 자리(빈 터 — 성돌 무너진 자리).", "gyoryong_trail", gxy)
	b = best_spot(gxy, len(gxy) * 0.66, len(gxy) * 0.9, 10.0, 30.0)
	slot("gy_seonguksa_teo", "선국사 터(산사)", "산사·암자 터", b[1], 12.0, 9.0, "산성 안 골짜기 절 자리(빈 터 — 법당 축대 자리).", "gyoryong_trail", gxy)
	anchor("gy_peak", "교룡산 정상 마루", "전망·봉우리", gy_peak[0], gy_peak[1], "남원 진산 꼭대기 — 읍성과 요천 들, 동쪽 여원재 줄기가 내려다보인다.", "gyoryong_trail", r=6.0, view=120.0)["y"] = round(yg, 2)
	anchor("gy_forest_path", "교룡산 솔숲길", "숲길", *gxy[len(gxy) // 3], "남원 북쪽에서 진산으로 오르는 솔숲 오솔길.", "gyoryong_trail")
	anchor("nw_baesan", "남원 배산(교룡산 남동 줄기 끝)", "배산", -3545.0, -20.0, "읍성 서북쪽 뒤로 내려온 교룡산 남동 줄기의 끝 봉우리 — 서문 밖·성황사 오솔길 뒤로 솟는다(그림 값으로 끌어내림).", None, r=60.0)
	# 폭포 보는 자리: 가장 가까운 산길에서 12m 넘게 떨어진 폭포는 소 가장자리(7m)까지 이음 오솔길
	tr_xy = [(tr["id"], tr["xy"]) for tr in TRAILS if tr["id"] != "tongyeong_byeolro"]
	for a in anchors:
		if a["type"] != "폭포·소": continue
		best = None
		for tid, txy in tr_xy:
			d, k = cKDTree(txy).query((a["x"], a["z"]))
			if best is None or d < best[0]: best = (d, tid, txy[k])
		a["route"] = best[1]
		if best[0] > 12.0:
			c = np.array([a["x"], a["z"]]); v = best[2] - c; v /= np.linalg.norm(v)
			links.append((a["id"], tuple(best[2]), tuple(c + v * 7.5), best[1])); a["route"] = a["id"] + "_path"
	# 이음 오솔길(길에서 10m 넘게 떨어진 터)
	link_xy = {}
	for sid, a, b, rid in links:
		p = astar(H, a, b, 0.2, 0.5, avoid=pl_av + water_av, pad=30.0, side_w=0.5, turn_w=5.0)
		p = smooth_path(p, 1.5)
		lxy, _, lt, _ = lay(sid + "_path", p, 1.2, 0.45, 2, 1.0, 8.0, 0.8, y0=float(sample(H, *p[0])[0]), y1=float(sample(H, *p[-1])[0]))
		link_xy[sid] = (lxy, rid)

	# ---- 6b) 다시 깎기: 터 고르기·봉우리 너럭이 길 끝·가장자리를 건드린 곳을 길 높이로 되돌린다(끝점 높이는 처음 값 그대로)
	for tr in TRAILS:
		y1 = tr["y1"] if tr["y1"] is not None else float(sample(H, *tr["xy"][-1])[0])
		xy2, _, t2 = road_profile(H, tr["xy"], tr["gmax"], win=tr["win"], y0=tr["y0"], y1=y1)
		carve(H, xy2, t2, tr["hw"], bank=tr["bank"], reach=tr["reach"], landuse=LU, lu_val=4, lu_hw=tr["lu_hw"], keep=river_core)
		tr["t"] = t2
	for tr in TRAILS:
		log("  길 %-22s %5.0fm  최대 구배(10m) %3.0f%%" % (tr["id"], len(tr["xy"]), g10(tr["t"])))

	# ---- 6c) 길 기록 + 건널목(물길 핵심 칸을 지나는 곳마다 — 여울·징검다리)
	tong["points"] = tong_head + [[round(float(a), 1), round(float(b), 1)] for a, b in pass_route[::3]] + tong_tail
	new_roads.append(road_rec("yw_valley_trail", "여원치 계곡길(골물 따라 폭포 소·마애불)", "산길", 2.4, vxy, 2, ["mountain-terrain(2026-10-21): 재매핑 지형 A*(구배 ≤ 36%) — 지리 놀이 공간(이야기 없음)"], "아랫주막 동쪽에서 골물 북안을 따라 오르다 폭포 소를 지나 마애불 앞에서 대로에 붙는다."))
	if gully_end is not None:
		new_roads.append(road_rec("yw_gully_trail", "여원치 남쪽 골 오름길(폭포·바위굴)", "산길", 2.2, uxy, 2, ["mountain-terrain(2026-10-21) A*(구배 ≤ 55%)"], "마애불 앞에서 남쪽 골물을 거슬러 폭포 둘을 지나 바위굴 어귀까지(가파른 오르막)."))
	new_roads.append(road_rec("yw_ridge_trail", "여원재 능선길(대간 마루금 → 북쪽 봉우리)", "산길", 2.2, rxy, 2, ["mountain-terrain(2026-10-21): 마루금 선호 A*"], "재 마루에서 북쪽 마루금을 타고 전망 바위 봉우리까지."))
	new_roads.append(road_rec("gyoryong_trail", "교룡산 산길(북쪽 길 → 배산 줄기 → 산성 동문 터 → 선국사 터 → 정상)", "산길", 2.4, gxy, 2, ["교룡산성·선국사: 남원 교룡산(고증 참고 — 위치는 게임 지형에 맞춤)", "mountain-terrain(2026-10-21) A*"], "namwon_north_road에서 갈라져 교룡산 남동 줄기를 타고 정상 마루까지."))
	for sid, (lxy, rid) in link_xy.items():
		new_roads.append(road_rec(sid + "_path", "이음 오솔길(" + sid + ")", "산길", 2.0, lxy, 2, ["mountain-terrain(2026-10-21)"], f"{rid}에서 빈 터 {sid}로 드는 오솔길."))
	rmeta = []
	for r in all_rivers:
		rp = np.array([p[:2] for p in r["points"]])
		rmeta.append((r, cKDTree(rp), max(float(r.get("width_m", 2.5)), 5.2) / 2 * 0.8 + 0.4))
	for tr in TRAILS:
		xyt = tr["xy"]; inr = np.zeros(len(xyt), bool); which = [None] * len(xyt)
		for r, tree, hw_ in rmeta:
			d, _ = tree.query(xyt, distance_upper_bound=hw_ + 2.5)
			hit = d < hw_ + 1.0
			for k in np.nonzero(hit)[0]: inr[k] = True; which[k] = r
		k = 0; n = 0
		while k < len(xyt):
			if inr[k]:
				k2 = k
				while k2 + 1 < len(xyt) and inr[k2 + 1]: k2 += 1
				km = (k + k2) // 2; r = which[km]; n += 1
				new_cross.append({ "id": f"x_mt_{tr['id']}_{n}", "name": "%s 건널목" % r.get("name", "물"), "type": "여울" if r.get("grade", "D") == "D" else "징검다리",
					"river_id": r["id"], "road_id": tr["id"], "x": round(float(xyt[km][0]), 1), "z": round(float(xyt[km][1]), 1), "confidence": "가설",
					"notes": "mountain-terrain: 길이 물길을 건너는 곳(물속을 걸어 건넘)" })
				k = k2 + 1
			else: k += 1
	log("건널목 %d곳" % len(new_cross))

	# ---- 7) 바위가 드러난 땅: 벼랑·바위 비탈(기울기) · 길을 깎은 절개면 · 암릉(능선 마루) · 너덜(벼랑 발치) · 물길 바닥과 기슭
	#   토지이용 7(바위·벼랑) / 8(자갈·모래·너덜)이면 식생(scatter)이 벼랑·큰 바위·바위·너덜 덮개·여울 돌을 실제 메시(+충돌)로 놓고,
	#   지형 셰이더는 바위결(층리·금)·자갈 무늬·젖은 기슭으로 칠한다. (material-lighting 병합 때 7 → M_ROCK, 8 → M_PATH/자갈, 5 → 하상 돌)
	LW, LH = LU.shape[1], LU.shape[0]
	def to4(a): return a[::2, ::2][:LH, :LW]
	# 고을(마을 터 bbox + 40m) 안은 바위·너덜·물길 칠하기를 하지 않는다(고을 사람 자리·이야기 무대·걷기 시험이 예전 그대로)
	town = np.zeros(LU.shape, bool)
	for st_ in R["settlements"]:
		bb = st_.get("bbox")
		if not bb: continue
		town[max(0, int((bb[1] - 40 - Z0) / LCELL)):int((bb[3] + 40 - Z0) / LCELL) + 1, max(0, int((bb[0] - 40 - X0) / LCELL)):int((bb[2] + 40 - X0) / LCELL) + 1] = True
	Hs3 = ndimage.uniform_filter(H, 3)
	gy, gx = np.gradient(Hs3, CELL); slope = np.hypot(gx, gy)
	sl4 = to4(slope); H4 = to4(H)
	dprot4 = to4(ndimage.distance_transform_edt(~prot) * CELL)
	cut4 = to4(H_pre - H)                                  # 길·물을 깎아 낮아진 깊이(+ = 절개)
	ridge4 = to4(H - ndimage.gaussian_filter(H, 6.0))      # 둘레보다 솟은 정도(능선 마루 +)
	rn = value_noise(LU.shape, 9, np.random.default_rng(SEED + 7))
	rn2 = value_noise(LU.shape, 4, np.random.default_rng(SEED + 9))
	luc = LU & 127
	soft = np.isin(luc, [0, 1]) & ~town
	steep = (sl4 > 1.0 + 0.45 * rn) & soft & (dprot4 > 4.0)
	steep = ndimage.binary_opening(steep, iterations=1)
	cutbank = (cut4 > 1.2) & (sl4 > 0.6) & soft
	amneung = (ridge4 > 4.0) & (sl4 > 0.35) & (H4 > 130.0) & (rn2 > 0.62) & soft & (dprot4 > 4.0)
	rock = steep | cutbank | amneung
	LU[rock] = 7
	# 너덜: 바위 칸에서 12m 안 아래쪽(더 낮은) 비탈
	dist_r, idx_r = ndimage.distance_transform_edt(~rock, return_indices=True)
	hr = H4[idx_r[0], idx_r[1]]
	scree = (~rock) & (dist_r * LCELL <= 8.0) & (H4 < hr - 1.5) & (sl4 > 0.35) & (sl4 < 1.0) & np.isin(LU & 127, [0, 1]) & (rn2 > 0.58) & (dprot4 > 4.0)
	LU[scree] = 8
	log("바위 드러남: 비탈 %d · 절개면 %d · 암릉 %d · 너덜 %d칸 (바위 %.2f%%)" % (steep.sum(), cutbank.sum(), amneung.sum(), scree.sum(), (LU & 127 == 7).mean() * 100))
	# 물길: 바닥(5)을 물폭만큼 확실히, 기슭 띠는 들·마을 냇가면 자갈·모래(8), 산골·가파른 기슭이면 바위(7)
	cl = np.zeros(LU.shape, bool); wgrid = np.zeros(LU.shape); ggrid = np.zeros(LU.shape)
	for r in rivers + new_rivers:
		w = max(float(r.get("width_m", 2.5)), 5.2); g = {"B": 7.0, "C": 4.5}.get(r.get("grade", "D"), 3.0)
		pts = np.array([p[:2] for p in r["points"]], float)
		xy, _ = resample(pts, 2.0)
		jj = np.clip(np.round((xy[:, 1] - Z0) / LCELL).astype(int), 0, LH - 1); ii = np.clip(np.round((xy[:, 0] - X0) / LCELL).astype(int), 0, LW - 1)
		cl[jj, ii] = True; wgrid[jj, ii] = np.maximum(wgrid[jj, ii], w); ggrid[jj, ii] = np.maximum(ggrid[jj, ii], g)
	dw, iw = ndimage.distance_transform_edt(~cl, return_indices=True)
	dw = dw * LCELL
	ww = wgrid[iw[0], iw[1]]; bw = ggrid[iw[0], iw[1]]
	chw = ww / 2.0 * 0.8
	busy = np.zeros(shape, bool)   # 길·배치(물은 뺀다 — 물가 띠를 칠해야 하므로)
	for r in roads + new_roads: busy |= raster_polyline(shape, [p[:2] for p in r["points"]], float(r.get("width_m", 3)) / 2 + 1.0)
	for it in [it for d in pl.values() for it in d["items"]] + sp["items"]:
		j = int((it["z"] - Z0) / CELL); i = int((it["x"] - X0) / CELL); busy[max(0, j - 4):j + 5, max(0, i - 4):i + 5] = True
	settled = np.isin(luc, [4, 6]) | to4(busy)
	core = (dw <= chw) & ~settled & ~town
	LU[core & ((LU & 127) != 5)] = 5
	band = (dw > chw) & (dw <= chw + bw * (0.7 + 0.6 * rn)) & ~settled & ~town & np.isin(LU & 127, [0, 1, 2, 3, 9]) & ~((np.isin(LU & 127, [2, 3])) & (dw > chw + 1.5))
	rocky_bank = band & ((sl4 > 0.45) | ((H4 > 95.0) & (bw <= 3.0)))
	LU[rocky_bank] = 7
	LU[band & ~rocky_bank] = 8
	log("물길: 바닥 %d · 자갈·모래 기슭 %d · 바위 기슭 %d칸" % (core.sum(), (band & ~rocky_bank).sum(), rocky_bank.sum()))
	# ---- 7b) 큰 벼랑·암릉 바위(실제 메시 + 충돌 — 배치 소품): 길에서 보이는 가장 가파른 비탈과 능선 마루
	#   벼랑: 비탈 발치(내리막 쪽)에 밑동을 두고 윗비탈 높이까지 솟게(h = 위 땅 − 발치 + 1.5m), 정면(+z)이 내리막. 길 중심에서 7m 넘게.
	#   암릉: 능선 마루(둘레보다 4m 넘게 솟은 곳)에 큰 바위 무더기.
	S6 = ndimage.gaussian_filter(H, 3.0)
	gy6, gx6 = np.gradient(S6, CELL); sl6 = np.hypot(gx6, gy6)
	trail_pts = np.vstack([tr["xy"][::2] for tr in TRAILS])
	ttr = cKDTree(trail_pts)
	def nms_pick(mask, score, spacing, cap, area):
		jj, ii = np.nonzero(mask)
		if len(jj) == 0: return []
		order = np.argsort(-score[jj, ii])
		picked = []
		for o in order:
			x, z = cell_xz(jj[o], ii[o])
			if not (area[0] <= x <= area[2] and area[1] <= z <= area[3]): continue
			if any((x - px) ** 2 + (z - pz) ** 2 < spacing ** 2 for px, pz in picked): continue
			picked.append((x, z))
			if len(picked) >= cap: break
		return picked
	dtr = np.full(shape, 1e9)
	sub_m = np.zeros(shape, bool)
	n_cliff = 0; n_rock = 0
	for area, cap_c, cap_r in [((-1100.0, -1300.0, 300.0, -600.0), 70, 40), ((-4200.0, -620.0, -3450.0, 120.0), 45, 25)]:
		j0, j1 = int((area[1] - Z0) / CELL), int((area[3] - Z0) / CELL); i0, i1 = int((area[0] - X0) / CELL), int((area[2] - X0) / CELL)
		J, I = np.mgrid[j0:j1:3, i0:i1:3]
		X = X0 + I * CELL; Z = Z0 + J * CELL
		d, _ = ttr.query(np.stack([X.ravel(), Z.ravel()], 1)); d = d.reshape(X.shape)
		dfull = np.full(shape, 1e9); dfull[j0:j1:3, i0:i1:3] = d
		near_ok = (dfull > 9.0) & (dfull < 260.0)
		luv = np.repeat(np.repeat(LU & 127, 2, 0), 2, 1)[:shape[0], :shape[1]]
		cm = near_ok & (sl6 > 1.15) & ~prot & ~np.isin(luv, [4, 5, 6])
		for (x, z) in nms_pick(cm, sl6, 16.0, cap_c, area):
			j, i = ij(x, z); j = int(round(float(j))); i = int(round(float(i)))
			dn = -np.array([gx6[j, i], gy6[j, i]]); dn /= max(np.linalg.norm(dn), 1e-6)   # 내리막
			foot = np.array([x, z]) + dn * 3.0
			wcl = 7.0 + (n_cliff * 37 % 50) / 10.0
			if ttr.query(foot)[0] < wcl * 0.5 + 4.5 or ttr.query(np.array([x, z]))[0] < wcl * 0.5 + 4.5: continue
			yf = float(sample(H, *foot)[0]); yt = float(sample(H, *(np.array([x, z]) - dn * 5.0))[0])
			h = float(np.clip(yt - yf + 1.5, 4.0, 14.0))
			ry = math.atan2(dn[0], dn[1])
			props.append({ "id": f"mt_cliff_{n_cliff:03d}", "kit": "nature/cliff", "params": { "w": round(7.0 + (n_cliff * 37 % 50) / 10.0, 1), "h": round(h, 1), "d": 3.5, "seed": 100 + n_cliff },
				"x": round(float(foot[0]), 2), "z": round(float(foot[1]), 2), "ry": round(ry, 4), "y": round(yf - 0.4, 2), "flatten": False, "clear_veg": True, "group": "벼랑(산 지형)" })
			n_cliff += 1
		ridge_full = H - ndimage.gaussian_filter(H, 6.0)
		rmask = (dfull > 10.0) & (dfull < 200.0) & (ridge_full > 4.0) & (sl6 > 0.3) & ~prot & ~np.isin(luv, [4, 5, 6])
		for (x, z) in nms_pick(rmask, ridge_full, 12.0, cap_r, area):
			props.append({ "id": f"mt_amneung_{n_rock:03d}", "kit": "nature/boulder", "params": { "s": round(2.4 + (n_rock * 13 % 20) / 10.0, 1), "seed": 300 + n_rock },
				"x": round(float(x), 2), "z": round(float(z), 2), "ry": round((n_rock * 1.7) % 6.283, 3), "y": None, "flatten": False, "clear_veg": True, "group": "암릉(산 지형)" })
			n_rock += 1
	log("큰 벼랑 %d · 암릉 바위 %d (배치 소품)" % (n_cliff, n_rock))

	# 계곡 너럭바위·큰 바위(지리 소품 — 충돌 있음): 골물 따라 18m마다 한쪽 기슭에
	rngp = np.random.default_rng(SEED + 11)
	for k in range(30, len(gol_xy) - 30, 18):
		if any(abs(k - q) < 14 for _, q in falls): continue
		tdir = gol_xy[min(k + 2, len(gol_xy) - 1)] - gol_xy[k - 2]; tdir /= max(np.linalg.norm(tdir), 1e-6); nrm = np.array([-tdir[1], tdir[0]])
		side = 1.0 if rngp.random() < 0.5 else -1.0
		c = gol_xy[k] + nrm * side * (3.4 + rngp.random() * 1.2)
		if min(np.min(np.hypot(*(tr["xy"] - c).T)) for tr in TRAILS) < 3.5: continue   # 길 위에는 놓지 않는다
		kit = "nature/slab_rock" if rngp.random() < 0.45 else "nature/boulder"
		props.append({ "id": f"mt_gol_rock_{k}", "kit": kit, "params": ({ "seed": int(k) } if kit == "nature/slab_rock" else { "s": round(1.6 + rngp.random() * 1.2, 2), "seed": int(k) }),
			"x": round(float(c[0]), 2), "z": round(float(c[1]), 2), "ry": round(float(rngp.random() * 6.283), 3), "y": None, "flatten": False, "clear_veg": True, "group": "여원치 골(산 지형)" })
	# 건널목 징검돌(보기 — 걸어 건너기는 여울 규칙 그대로)
	for cr in new_cross:
		if cr.get("river_id") == "yeowonchi_gol" or cr["type"] == "여울":
			props.append({ "id": "mt_" + cr["id"] + "_stones", "kit": "nature/stream_stones", "params": { "seed": len(props) }, "x": cr["x"], "z": cr["z"], "ry": 0.0, "y": None, "flatten": False, "clear_veg": False, "group": "건널목 징검돌(보기)" })

	# ---- 8) y 채우기·쓰기
	for a in anchors:
		if a["y"] is None: a["y"] = round(float(sample(H, a["x"], a["z"])[0]), 2)
	R["rivers"] = rivers + new_rivers
	R["roads"] = roads + new_roads
	R["crossings"] = R["crossings"] + new_cross
	R["height"]["remap"] = { "src": REMAP_SRC, "dst": REMAP_DST, "note": "mountain-terrain(2026-10-21): 원래 y(=(해발−60)·K) → 게임 y. 고을 바닥 y≤30은 그대로, 위로 1.5배→2배(세로 되살림). 해발 = f⁻¹(y)/K + 60" }
	R["projection"]["vertical_remap"] = "height.remap 참고 — y=(alt−60)·K는 재매핑 전 값"
	lo, hi = save_height(H, R)
	MJ = { "note": "산 지형 자리(mountain-terrain 2026-10-21) — 앞으로 이야기가 쓸 수 있는 지리 자리 목록. 이야기·인물·사건은 없다. type: 재 마루·서낭당·장승·주막·쉼터·폭포·소·바위·벼랑·동굴·산사·암자 터·화전·산촌·숲길·전망·배산. slot = 평평하게 고른 빈 터 크기[가로, 세로] m.",
		"routes": [
			{ "id": "yeowonchi", "name": "여원치(여원재) 고갯길", "roads": ["tongyeong_byeolro", "yw_valley_trail", "yw_gully_trail", "yw_ridge_trail"],
			  "walk": [[round(float(a), 1), round(float(b), 1)] for a, b in pass_route[::25]] + [[round(float(pass_route[-1][0]), 1), round(float(pass_route[-1][1]), 1)]] },
			{ "id": "yw_valley", "name": "여원치 계곡길", "roads": ["yw_valley_trail"], "walk": [[round(float(a), 1), round(float(b), 1)] for a, b in vxy[::20]] + [[round(float(vxy[-1][0]), 1), round(float(vxy[-1][1]), 1)]] },
			{ "id": "yw_gully", "name": "여원치 남쪽 골 오름길", "roads": ["yw_gully_trail"], "walk": [[round(float(a), 1), round(float(b), 1)] for a, b in uxy[::12]] } if gully_end is not None else None,
			{ "id": "yw_ridge", "name": "여원재 능선길", "roads": ["yw_ridge_trail"], "walk": [[round(float(a), 1), round(float(b), 1)] for a, b in rxy[::20]] + [[round(float(rxy[-1][0]), 1), round(float(rxy[-1][1]), 1)]] },
			{ "id": "yocheon_bank", "name": "요천 기슭 길(광한루–요천 나루) — 물가 바닥·기슭 점검", "roads": ["namwon_gurye_road"], "bbox": [-3420.0, 380.0, -3050.0, 1000.0] },
			{ "id": "gyoryong", "name": "교룡산 산길", "roads": ["gyoryong_trail"], "walk": [[round(float(a), 1), round(float(b), 1)] for a, b in gxy[::20]] + [[round(float(gxy[-1][0]), 1), round(float(gxy[-1][1]), 1)]] },
		],
		"anchors": anchors }
	MJ["routes"] = [r for r in MJ["routes"] if r]
	if not DRY:
		R["build"].setdefault("mountain", "tools/mountain/build_mountain.py")
		json.dump(R, open(os.path.join(DATA, "region.json"), "w"), ensure_ascii=False, indent=1)
		Image.fromarray(LU).save(os.path.join(DATA, "landuse.png"))
		json.dump(MJ, open(os.path.join(DATA, "mountain.json"), "w"), ensure_ascii=False, indent=1)
		for name, d in pl.items(): json.dump(d, open(os.path.join(DATA, name), "w"), ensure_ascii=False, indent=1)
		json.dump({ "area": "산 지형(여원치 골·교룡산)", "note": "mountain-terrain(2026-10-21): 지리 소품만(폭포·벼랑). 이야기 없음. tools/mountain/build_mountain.py가 만든다.", "items": props },
			open(os.path.join(DATA, "placement_mountain.json"), "w"), ensure_ascii=False, indent=1)
	if os.environ.get("MTN_PNG"): debug_png(H, LU, R, anchors, os.environ["MTN_PNG"])
	log("높이 범위 %.1f..%.1f, 자리 %d, 새 길 %d, 새 물 %d, 건널목 %d, 소품 %d" % (lo, hi, len(anchors), len(new_roads), len(new_rivers), len(new_cross), len(props)))
	for a in anchors: log("  ANCHOR %-18s %-14s (%.0f, %.1f, %.0f) %s" % (a["id"], a["type"], a["x"], a["y"], a["z"], a["name"]))

def debug_png(H, LU, R, anchors, out):
	from PIL import ImageDraw
	for nm, (x0, x1, z0, z1) in { "pass": (-1100, 300, -1400, -500), "namwon": (-4352, -2900, -800, 600) }.items():
		sub = H[int((z0 - Z0) / CELL):int((z1 - Z0) / CELL), int((x0 - X0) / CELL):int((x1 - X0) / CELL)]
		gy, gx = np.gradient(sub, CELL)
		l = np.array([-1, -1, 1.5]); l /= np.linalg.norm(l)
		n = np.dstack([-gx, -gy, np.ones_like(gx)]); n /= np.linalg.norm(n, axis=2, keepdims=True)
		sh = np.clip((n * l).sum(2), 0, 1)
		c = (sub - sub.min()) / np.ptp(sub)
		rgb = np.dstack([0.4 + 0.6 * c, 0.55 + 0.3 * c, 0.35 + 0.3 * c]) * (0.35 + 0.65 * sh[..., None])
		lu = np.repeat(np.repeat(LU, 2, 0), 2, 1)[int((z0 - Z0) / CELL):int((z1 - Z0) / CELL), int((x0 - X0) / CELL):int((x1 - X0) / CELL)] & 127
		rgb[lu == 7] = rgb[lu == 7] * 0.5 + np.array([0.5, 0.5, 0.5]) * 0.5
		cont = (np.floor(sub / 20) != np.floor(np.roll(sub, 1, 0) / 20)) | (np.floor(sub / 20) != np.floor(np.roll(sub, 1, 1) / 20))
		rgb[cont] *= 0.65
		im = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)); d = ImageDraw.Draw(im)
		Q = lambda x, z: ((x - x0) / CELL, (z - z0) / CELL)
		for r in R["rivers"]: d.line([Q(p[0], p[1]) for p in r["points"]], fill=(0, 80, 255), width=3)
		for r in R["roads"]: d.line([Q(*p[:2]) for p in r["points"]], fill=(200, 0, 0) if r["class"] in ("대로", "지선") else (120, 40, 0), width=3 if r["class"] != "산길" else 2)
		for a in anchors:
			x, z = Q(a["x"], a["z"]); d.ellipse([x - 5, z - 5, x + 5, z + 5], outline=(255, 255, 0), width=2); d.text((x + 6, z - 4), a["id"], fill=(0, 0, 0))
		for g in range(-5000, 5000, 100):
			if x0 <= g <= x1: d.line([Q(g, z0), Q(g, z1)], fill=(230, 230, 230), width=1); d.text(Q(g + 2, z0 + 4), str(g), fill=(255, 255, 255))
			if z0 <= g <= z1: d.line([Q(x0, g), Q(x1, g)], fill=(230, 230, 230), width=1); d.text(Q(x0 + 2, g), str(g), fill=(255, 255, 255))
		im.save(os.path.join(out, f"mtn_{nm}.png"))

def remap_parcels():
	"""parcels.bin(PRCL v2): P[:,2] 논 바닥, I[:,2:4] 물꼬 위·아래 바닥 — 절대 y라 같은 f로 옮긴다."""
	raw = open(base_path("parcels.bin"), "rb").read()
	head = raw[:24]
	body = bytearray(gzip.decompress(raw[24:]))
	magic, ver = head[:4], struct.unpack("<I", head[4:8])[0]
	n, nv, ni, _ = struct.unpack("<IIII", head[8:24])
	P = np.frombuffer(bytes(body[:n * 48]), np.float32).reshape(n, 12).copy()
	P[:, 2] = f(P[:, 2]).astype(np.float32)
	off_i = n * 48 + nv * 12
	Iarr = np.frombuffer(bytes(body[off_i:off_i + ni * 16]), np.float32).reshape(ni, 4).copy()
	Iarr[:, 2:4] = f(Iarr[:, 2:4]).astype(np.float32)
	body[:n * 48] = P.tobytes(); body[off_i:off_i + ni * 16] = Iarr.tobytes()
	open(os.path.join(DATA, "parcels.bin"), "wb").write(head + gzip.compress(bytes(body), 6, mtime=0))
	log("논 필지 바닥 %d · 물꼬 %d 옮김" % (n, ni))

if __name__ == "__main__":
	main()
