#!/usr/bin/env python3
# 역참·마방(驛 馬房) 자리 만들기 — region_data/stations.json + 공간마다 placement_stations.json(키트 kit/station/mabang.gd).
#
# 역(驛)은 조선 큰길(대로)에 30리 안팎마다 두고 역마를 길렀다. 고을 역은 읍성 밖 큰길 가에 있었다.
# 여기서는 (1) 대표 도시 8곳의 성문 밖 큰길 가, (2) 이미 '역'인 곳(인월역·구산역)과 역 구실을 하는 노정 쉼터(오수·전주·안보(새재 들머리)·
# 상주·원주·횡계·철령 아래·영흥·고원·청교(개성)), (3) 권역 쪽 노정 끝(포털) 가운데 다른 역이 1.5km 안에 없는 곳에 마방을 놓는다.
# 함흥→북청 노정의 '함관령 옛 역참'은 이야기에 쓰는 버려진 역이라 건드리지 않는다(그 노정에는 마방을 두지 않는다).
#
# 자리 고르기: 기준점(성문·쉼터·노정 끝) 둘레 큰길(대로·지선) 점마다 마방 터(27×21m, kit/station/mabang.gd)를 길 북쪽에 길 방향으로 놓아 보고
#   - 터 안에 다른 배치 물체(배치 placement_*.json — 키트 크기는 *_bounds.json 캐시)·다른 길·물·성곽·도시 구역이 없고
#   - 높이 차가 작고(터 고르기로 다듬음), 길이 동서로 지나가(정면이 남쪽 = 고정 카메라 쪽) 좋은 곳을 고른다.
#   도착·말 타는 자리(yard)는 길 중심에서 2.5m(마방 문 앞).
# 다른 생성기(placement 생성기·make_routes.py)가 다시 돌아도 마방 자리는 tools/placement/station_reserve.py로 비워 둔다.
# 순서: make_routes.py·배치 생성기 → make_stations.py → make_travel_gates.py(역 거점·말 타는 곳·역마 도착 자리를 stations.json에서)
#
# 실행: python3 tools/region/make_stations.py            # 모든 공간
#       python3 tools/region/make_stations.py --check    # 쓰지 않고 고른 자리만 보기
import json, math, os, sys, glob
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_travel_gates as MTG   # noqa: E402

ROOT = MTG.ROOT
RD = MTG.RD
OUT = os.path.join(RD, 'stations.json')
PLACE_FILE = 'placement_stations.json'
KIT = 'station/mabang'
W, D = 27.0, 21.0          # kit/station/mabang.gd W·D
NEAR_STATION = 1500.0      # 노정 끝 역: 이 안에 다른 역이 있으면 두지 않는다

# 역 목록. at: 기준 — ('node', 거점 id) | ('gate_toward', 도시 거점 id, 향할 노정 끝 거점 id) | ('xz', x, z)
#   reuse: 이미 있는 '역' 거점을 그대로 쓴다(거점 id 유지, 도착 자리만 마방 앞으로). want: 기준점에서 바라는 거리(m)
STATIONS = [
	# ---- 대표 도시: 성문 밖 큰길 ----
	dict(id='namwon', space='JL_NAMWON_UNBONG', name='남원 역참', sign='南原驛', style='honam', kind='hub', hub=True,
		at=('gate_toward', 'namwon_eup', 'unbong_eup'), note='동문 밖 통영별로(운봉·인월 가는 큰길) — 삼남대로 쪽은 북쪽 길목 역'),
	dict(id='cheongpa', space='GG_HANYANG', name='청파역', sign='靑坡驛', style='giho', kind='hub', hub=True,
		at=('gate_toward', 'hanyang_doseong_in', 'yongsan'), note='숭례문 밖 청파(용산 가는 길) — 한양 남쪽 큰 역, 삼남대로로 나가는 첫 역'),
	dict(id='gyeongju', space='GS_GYEONGJU', name='경주 역참', sign='慶州驛', style='yeongnam', kind='hub', hub=True,
		at=('gate_toward', 'gyeongju_eup', 'end_GG_HANYANG-GS_GYEONGJU_to')),
	dict(id='gangneung', space='GW_GANGNEUNG', name='강릉 역참', sign='江陵驛', style='gwandong', kind='hub', hub=True,
		at=('gate_toward', 'gangneung_eup', 'end_GG_HANYANG-GW_GANGNEUNG_to')),
	dict(id='hwangju', space='HH_HWANGJU', name='황주 역참', sign='黃州驛', style='haeseo', kind='hub', hub=True,
		at=('gate_toward', 'hwangju_eup', 'end_GG_HANYANG-HH_HWANGJU_to')),
	dict(id='daedong', space='PA_PYEONGYANG', name='대동역', sign='大同驛', style='gwanseo', kind='hub', hub=True,
		at=('gate_toward', 'pyeongyang_naeseong', 'end_HH_HWANGJU-PA_PYEONGYANG_to'), note='평양 대동역(평안도 역도의 으뜸)'),
	dict(id='hamheung', space='HG_HAMHEUNG', name='함흥 역참', sign='咸興驛', style='gwanbuk', kind='hub', hub=True,
		at=('gate_toward', 'hamheung_eup', 'end_GG_HANYANG-HG_HAMHEUNG_to')),
	dict(id='jeju', space='JJ_JEJU', name='제주목 마방', sign='濟州馬房', style='tamna', kind='hub', hub=True, pony=True,
		at=('gate_toward', 'jeju_mok', 'end_SEA_NAMHAE_JEJU_to'), note='제주는 역 대신 목마(牧馬) — 조랑말 마방'),
	# ---- 위성 고을의 역(이미 있는 역 거점) ----
	dict(id='inwol', space='JL_NAMWON_UNBONG', name='인월역', sign='引月驛', style='honam', kind='satellite', at=('node', 'inwol_yeok'), reuse='inwol_yeok'),
	dict(id='gusan', space='GW_GANGNEUNG', name='구산역', sign='丘山驛', style='gwandong', kind='satellite', at=('node', 'gusan_yeok'), reuse='gusan_yeok'),
	dict(id='songdang', space='JJ_JEJU', name='송당 목마장', sign='松堂牧場', style='tamna', kind='satellite', pony=True, at=('node', 'songdang'),
		note='중산간 목장 마을 — 조랑말'),
	# ---- 노정 쉼터 중 역 구실을 하는 곳 ----
	dict(id='osu', space='JL_NAMWON_UNBONG-GG_HANYANG', name='오수역', sign='獒樹驛', style='honam', kind='route', at=('node', 'rt_osu')),
	dict(id='jeonju', space='JL_NAMWON_UNBONG-GG_HANYANG', name='전주 역참', sign='參禮驛', style='honam', kind='route', at=('node', 'rt_jeonju'),
		note='전주 감영 북쪽 삼례역(호남 역도의 으뜸)을 전주 쉼터 곁에'),
	dict(id='anbo', space='GG_HANYANG-GS_GYEONGJU', name='안보역 (새재 들머리)', sign='安保驛', style='yeongnam', kind='route', at=('xz', -560.0, 0.0),
		note='문경새재(조령) 북쪽 들머리 — 관문 앞 처음 지날 때 하차와 겹치지 않게 고개 서쪽 길에'),
	dict(id='sangju', space='GG_HANYANG-GS_GYEONGJU', name='상주 역참', sign='洛陽驛', style='yeongnam', kind='route', at=('node', 'rt_sangju')),
	dict(id='wonju', space='GG_HANYANG-GW_GANGNEUNG', name='원주 역참', sign='原州驛', style='gwandong', kind='route', at=('node', 'rt_wonju')),
	dict(id='hoenggye', space='GG_HANYANG-GW_GANGNEUNG', name='횡계역', sign='橫溪驛', style='gwandong', kind='route', at=('node', 'rt_hoenggye')),
	dict(id='cheollyeong', space='GG_HANYANG-HG_HAMHEUNG', name='철령 아래 역참', sign='驛', style='gwanbuk', kind='route', at=('xz', -150.0, 40.0),
		note='철령관 남쪽 들머리(관문 앞 처음 지날 때 하차 자리 밖)'),
	dict(id='yeongheung', space='GG_HANYANG-HG_HAMHEUNG', name='영흥 역참', sign='永興驛', style='gwanbuk', kind='route', at=('node', 'rt_yeongheung')),
	dict(id='gowon', space='PA_PYEONGYANG-HG_HAMHEUNG', name='고원 역참', sign='高原驛', style='gwanbuk', kind='route', at=('node', 'rt_gowon')),
	dict(id='cheonggyo', space='GG_HANYANG-HH_HWANGJU', name='청교역', sign='靑郊驛', style='giho', kind='route', at=('node', 'rt_kaesong'),
		note='개성 남쪽 청교역'),
]
NO_STATION_SPACES = {'HG_HAMHEUNG-BUKCHEONG'}   # 함관령 옛 역참(버려진 역 — 이야기)
END_STYLE = {'JL_NAMWON_UNBONG': 'honam', 'GG_HANYANG': 'giho', 'GS_GYEONGJU': 'yeongnam', 'GW_GANGNEUNG': 'gwandong', 'HH_HWANGJU': 'haeseo',
	'PA_PYEONGYANG': 'gwanseo', 'HG_HAMHEUNG': 'gwanbuk', 'JJ_JEJU': 'tamna'}


# ---------------------------------------------------------------- 공간 읽기
class Space:
	def __init__(self, sid):
		self.id = sid
		rp = os.path.join(RD, sid, 'region.json')
		self.is_route = not os.path.exists(rp)
		self.dir = os.path.join(RD, 'routes', sid) if self.is_route else os.path.join(RD, sid)
		self.j = json.load(open(os.path.join(self.dir, 'route.json' if self.is_route else 'region.json')))
		h = self.j['height']
		self.hm = h
		a = np.array(Image.open(os.path.join(self.dir, h['file']))).astype(np.float32)
		self.H = h['y_min'] + a / 65535.0 * (h['y_max'] - h['y_min'])
		self.L = MTG.load_landuse(self.dir, self.j)
		self.travel = json.load(open(os.path.join(RD, 'travel', sid + '.json')))
		g = self.travel['graph']
		self.pts = [tuple(p) for p in g['pts']]
		self.adj = {}
		for a_, b_ in g['edges']:
			self.adj.setdefault(a_, []).append(b_); self.adj.setdefault(b_, []).append(a_)
		self.city = set(g.get('city', []))
		self.nodes = {n['id']: n for n in self.travel['nodes']}
		# 말 길 덩이(도시 안 점은 말이 못 들어가니 끊는다): 점 → 덩이 번호, 덩이마다 닿는 거점 수
		par = list(range(len(self.pts)))
		def f(x):
			while par[x] != x: par[x] = par[par[x]]; x = par[x]
			return x
		for a_, b_ in g['edges']:
			if a_ in self.city or b_ in self.city: continue
			par[f(a_)] = f(b_)
		self.comp = [f(i) for i in range(len(self.pts))]
		self.comp_nodes = {}
		for n in self.travel['nodes']:
			for c_ in {self.comp[gt['gi']] for gt in n.get('gates', []) if gt['gi'] < len(self.pts)}:
				self.comp_nodes[c_] = self.comp_nodes.get(c_, 0) + 1
		self.obst = obstacles(self.dir)
		self.segs = []   # (a, b, half width, kind)
		for r in self.j.get('roads', []):
			p = r.get('points', [])
			for u, v in zip(p, p[1:]): self.segs.append(((u[0], u[1]), (v[0], v[1]), float(r.get('width_m', 3)) / 2, 'road'))
		for r in self.j.get('rivers', []):
			p = r.get('points', [])
			for u, v in zip(p, p[1:]): self.segs.append(((u[0], u[1]), (v[0], v[1]), float(r.get('width_m', 8)) / 2 + 2.0, 'river'))
		for w in self.j.get('walls', []):
			p = w.get('points', [])
			for u, v in zip(p, p[1:]): self.segs.append(((u[0], u[1]), (v[0], v[1]), 3.0, 'wall'))
		self.city_zones = [n['zone'] for n in self.travel['nodes'] if n['kind'] == 'CITY']

	def height(self, x, z):
		h = self.hm
		fx = (x - h['x0']) / h['cell']; fz = (z - h['z0']) / h['cell']
		i = int(math.floor(fx)); j = int(math.floor(fz))
		if i < 0 or j < 0 or i >= h['w'] - 1 or j >= h['h'] - 1: return None
		tx = fx - i; tz = fz - j; H = self.H
		return float((H[j, i] * (1 - tx) + H[j, i + 1] * tx) * (1 - tz) + (H[j + 1, i] * (1 - tx) + H[j + 1, i + 1] * tx) * tz)

	def road_dir(self, i):
		"""그래프 점 i의 길 방향(이웃 둘~넷 평균)"""
		nb = self.adj.get(i, [])
		if not nb: return None
		vs = []
		for k in nb:
			d = (self.pts[k][0] - self.pts[i][0], self.pts[k][1] - self.pts[i][1])
			l = math.hypot(*d) or 1.0
			vs.append((d[0] / l, d[1] / l))
		if len(vs) == 1: v = vs[0]
		else:
			v = (vs[0][0] - vs[1][0], vs[0][1] - vs[1][1]) if vs[0][0] * vs[1][0] + vs[0][1] * vs[1][1] < 0 else vs[0]
		l = math.hypot(*v) or 1.0
		return (v[0] / l, v[1] / l)


_BOUNDS = None
def kit_radius(it):
	global _BOUNDS
	if _BOUNDS is None:
		_BOUNDS = {}
		for f in glob.glob(os.path.join(ROOT, 'tools', 'placement', '*_bounds.json')):
			try: _BOUNDS.update(json.load(open(f)))
			except Exception: pass
	fp = it.get('footprint')
	if not fp:
		key = it.get('kit', '') + '|' + json.dumps(it.get('params', {}), sort_keys=True, separators=(', ', ': '), ensure_ascii=False)
		b = _BOUNDS.get(key)
		if b: fp = b.get('footprint')
	if fp: return 0.5 * math.hypot(float(fp[0]), float(fp[1]))
	k = it.get('kit', '')
	p = it.get('params', {})
	if 'ax' in p and 'bx' in p: return 0.5 * math.hypot(p['bx'] - p['ax'], p['bz'] - p['az']) + 0.5
	if 'len' in p: return float(p['len']) / 2 + 0.5
	for key, r in (('compound', 9.0), ('wall', 8.0), ('gwana', 30.0), ('eupseong', 60.0), ('jumak', 9.0), ('market', 5.0), ('giwa', 6.0), ('choga', 5.0),
			('house', 6.0), ('bridge', 8.0), ('tree', 4.0), ('pine', 3.0), ('garden', 3.0), ('props', 1.5), ('jangdok', 1.5), ('haystack', 1.5)):
		if key in k: return r
	return 4.0


def obstacles(space_dir):
	out = []
	for f in sorted(glob.glob(os.path.join(space_dir, 'placement_*.json'))):
		if os.path.basename(f) == PLACE_FILE: continue
		try: d = json.load(open(f))
		except Exception: continue
		for it in d.get('items', []):
			if not isinstance(it, dict) or 'x' not in it: continue
			cx, cz = float(it['x']), float(it['z'])
			p = it.get('params', {})
			if 'ax' in p and 'bx' in p:   # 두 점 모델(담·울타리): 선분으로
				out.append(('seg', (cx + p['ax'], cz + p['az']), (cx + p['bx'], cz + p['bz']), 0.8))
			else:
				out.append(('c', (cx, cz), kit_radius(it)))
	return out


def seg_dist(p, a, b):
	dx, dz = b[0] - a[0], b[1] - a[1]
	l2 = dx * dx + dz * dz
	t = 0.0 if l2 < 1e-9 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / l2))
	return math.hypot(p[0] - a[0] - dx * t, p[1] - a[1] - dz * t)


def to_world(c, ry, lx, lz):
	# Godot 회전: 로컬 +x → (cos ry, −sin ry), 로컬 +z → (sin ry, cos ry)
	return (c[0] + lx * math.cos(ry) + lz * math.sin(ry), c[1] - lx * math.sin(ry) + lz * math.cos(ry))


def to_local(c, ry, x, z):
	dx, dz = x - c[0], z - c[1]
	return (dx * math.cos(ry) - dz * math.sin(ry), dx * math.sin(ry) + dz * math.cos(ry))


def rect_ok(S, c, ry, hw, hd, pad_obj=0.8, small_ok=False):
	"""사각형 터(가운데 c, 회전 ry, 반폭 hw·반깊이 hd) 안에 배치 물체·길·물·담이 없나"""
	def in_rect(x, z, pad):
		lx, lz = to_local(c, ry, x, z)
		return abs(lx) <= hw + pad and abs(lz) <= hd + pad
	R = math.hypot(hw, hd) + 2
	for o in S.obst:
		if o[0] == 'c':
			p, r = o[1], o[2]
			if math.dist(p, c) > R + r: continue
			if small_ok and r < 1.8: continue     # 문 앞 터: 길가 소품(짚단·장독 하나)은 비켜 둔다
			if in_rect(p[0], p[1], min(r, 6.0) * pad_obj): return False
		else:
			a, b, w = o[1], o[2], o[3]
			if seg_dist(c, a, b) > R + w: continue
			for k in range(9):
				t = k / 8.0
				if in_rect(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, w): return False
	for a, b, w, kind in S.segs:
		if seg_dist(c, a, b) > R + w + 8: continue
		n = max(2, int(math.dist(a, b) / 2.0))
		for k in range(n + 1):
			t = k / n
			if in_rect(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, w + 0.5): return False
	return True


HITCH_W, HITCH_D = 9.2, 2.6     # kit/station/hitch.gd 터
YARD_OFF = 3.0                  # 길 중심 → 도착 자리


import collections
DBG = collections.Counter()
def _no(tag):
	DBG[tag] += 1
	return None


def try_site(S, gi, taken, side):
	"""그래프 점 gi 옆(side ±1 = 길 왼쪽/오른쪽)에 마방을 놓아 본다 → (벌점, 자리) 또는 None.
	마방은 늘 정면(+z)이 거의 남쪽(카메라 쪽): 길이 동서로 지나면 길 방향에 맞춰 ±30° 안으로 돌리고, 아니면 0°."""
	d = S.road_dir(gi)
	if d is None: return _no('nodir')
	if d[0] < 0: d = (-d[0], -d[1])
	n = (-d[1] * side, d[0] * side)            # 길에서 마방 쪽
	aligned = math.atan2(-d[1], d[0])
	ry = aligned if abs(aligned) <= math.radians(30) else 0.0
	ex = (math.cos(ry), -math.sin(ry)); ez = (math.sin(ry), math.cos(ry))
	ext = W / 2 * abs(n[0] * ex[0] + n[1] * ex[1]) + D / 2 * abs(n[0] * ez[0] + n[1] * ez[1])
	g = S.pts[gi]
	hext = HITCH_W / 2 * abs(n[0]) + HITCH_D / 2 * abs(n[1])     # 문 앞 터(ry 0)의 길 쪽 반폭
	hoff = hext + 4.3                                             # 길 중심 → 문 앞 가운데(대로 반폭 3 + 1.3)
	gap = hoff + hext + 0.8
	c = (g[0] + n[0] * (ext + gap), g[1] + n[1] * (ext + gap))
	hx, hz = W / 2 + 1.0, D / 2 + 1.0
	samples = [to_world(c, ry, sx * hx, sz * hz) for sx in (-1, -0.5, 0, 0.5, 1) for sz in (-1, -0.5, 0, 0.5, 1)]
	hs = []
	for x, z in samples:
		h = S.height(x, z)
		if h is None: return _no('oob')
		hs.append(h)
		if MTG.lu_at(S.L, x, z) == 5: return _no('water')   # 물
	rng = max(hs) - min(hs)
	if rng > 4.5: return _no('slope')
	for zn in S.city_zones:
		for x, z in samples[::2] + [c]:
			if MTG.inside(zn, x, z): return _no('city_in')
		if zn['kind'] == 'circle' and math.dist(c, zn['c']) < zn['r'] + 30: return _no('city_r')
	for q in taken:
		if math.dist(q, c) < 70: return _no('taken')
	if not rect_ok(S, c, ry, W / 2, D / 2): return _no('rect')
	# 길가 문 앞(가로대·현판·깃발): 길에서 HITCH_OFF, 길 방향으로 조금 비켜(마방 문 쪽)
	hitch = (g[0] + n[0] * hoff, g[1] + n[1] * hoff)
	if not rect_ok(S, hitch, 0.0, HITCH_W / 2, HITCH_D / 2, 0.6, True): return _no('hitch')
	hh = S.height(*hitch)
	if hh is None or abs(hh - S.height(*g)) > 1.6: return _no('hitch_h')
	yard = (g[0] + n[0] * YARD_OFF - d[0] * 2.5, g[1] + n[1] * YARD_OFF - d[1] * 2.5)   # 문 앞 곁 길가(말이 길 쪽에서 다가와 선다)
	south = n[1] > 0.5     # 마방이 길 남쪽 — 길이 마구간 뒤로 지나감(정면은 그래도 카메라 쪽)
	pen = rng * 3.0 + abs(ry) * 25.0 + (25.0 if south else 0.0)
	return pen, {'c': c, 'ry': ry, 'gi': gi, 'road': g, 'yard': yard, 'hitch': hitch, 'slope': rng}


def pick(S, st, taken):
	at = st['at']
	tgt = None
	if at[0] == 'gate_toward':
		city = S.nodes[at[1]]; tgt = S.nodes.get(at[2])
		tp = (tgt['x'], tgt['z']) if tgt else (city['x'], city['z'])
		gates = city.get('gates', [])
		gate = min(gates, key=lambda g: math.dist((g['x'], g['z']), tp)) if gates else {'x': city['x'], 'z': city['z']}
		base = (gate['x'], gate['z']); want = 110.0; rad = 950.0
		# 성문에서 바깥(노정 끝 쪽)으로: 성문보다 노정 끝에 가까운 점만
		outward = lambda p: math.dist(p, tp) < math.dist(base, tp) + 20
	elif at[0] == 'node':
		n = S.nodes[at[1]]
		base = (n['x'], n['z']); want = 40.0 if st['kind'] == 'satellite' else 60.0; rad = 450.0
		outward = lambda p: True
	else:
		base = (at[1], at[2]); want = 0.0; rad = 420.0
		outward = lambda p: True
	# 말 길 덩이: 향할 거점(노정 끝·이웃 고을)의 어귀가 있는 덩이, 아니면 둘레에서 거점이 가장 많이 닿는 덩이 — 역에서 말 타고 실제로 갈 수 있게
	want_comp = None
	if at[0] == 'gate_toward' and tgt and tgt.get('gates'): want_comp = S.comp[tgt['gates'][0]['gi']]
	else:
		cands = {S.comp[i] for i, p in enumerate(S.pts) if math.dist(p, base) <= rad and i not in S.city}
		if cands: want_comp = max(cands, key=lambda c_: S.comp_nodes.get(c_, 0))
	best = None
	for i, p in enumerate(S.pts):
		dd = math.dist(p, base)
		if dd > rad or i in S.city or not outward(p): continue
		if want_comp is not None and S.comp[i] != want_comp: continue
		for side in (1, -1):
			r = try_site(S, i, taken, side)
			if r is None: continue
			sc = abs(dd - want) + r[0]
			if best is None or sc < best[0]: best = (sc, r[1], dd)
	return best


def lonlat(S, x, z):
	pj = S.j.get('projection') or {}
	if not S.is_route and 'lat0' in pj:
		K = float(pj['K']); lat0 = float(pj['lat0']); lon0 = float(pj['lon0'])
		return [round(lon0 + x / (math.cos(math.radians(lat0)) * 111320.0 * K), 5), round(lat0 - z / (110574.0 * K), 5)]
	gl = S.j.get('geo_line') or []
	if len(gl) < 2: return None
	roads = [r for r in S.j.get('roads', []) if r.get('class') in MTG.RIDE_CLASSES]
	if not roads: return None
	main = max(roads, key=lambda r: (MTG.RIDE_CLASSES[r['class']] * 10, len(r['points'])))
	t = MTG.progress([(p[0], p[1]) for p in main['points']], x, z)
	tot = sum(math.dist(a, b) for a, b in zip(gl, gl[1:]))
	want = tot * t
	for a, b in zip(gl, gl[1:]):
		l = math.dist(a, b)
		if want <= l:
			k = want / max(l, 1e-9)
			return [round(a[0] + (b[0] - a[0]) * k, 5), round(a[1] + (b[1] - a[1]) * k, 5)]
		want -= l
	return [round(gl[-1][0], 5), round(gl[-1][1], 5)]


def other_id(tgt, sid):
	parts = tgt.split('-')
	return next((q for q in parts if q != sid), parts[-1])


def end_stations(spaces, chosen):
	"""권역 쪽 노정 끝(땅길)마다: 1.5km 안에 역이 없으면 길목 역"""
	out = []
	for sid in sorted(END_STYLE):
		S = spaces.get(sid)
		if S is None: continue
		for n in S.travel['nodes']:
			if n['kind'] != 'ROUTE_END': continue
			tgt = str(n.get('target', ''))
			if tgt.startswith('RIVER_') or tgt.startswith('SEA_') or tgt in NO_STATION_SPACES: continue
			if not os.path.exists(os.path.join(RD, 'routes', tgt, 'route.json')): continue
			p = (n['x'], n['z'])
			if any(c['space'] == sid and math.dist(p, c['_c']) < NEAR_STATION for c in chosen + out): continue
			if any(c['space'] == sid and c.get('_target') == tgt for c in out): continue   # 같은 노정으로 가는 끝은 하나만
			nm = MTG.short(n['name']).replace(' 길목', '').strip()
			orp = os.path.join(RD, other_id(tgt, sid), 'region.json')
			if os.path.exists(orp):   # 이웃 권역 이름: '평양 길목 역참'(한 고을에 노정 끝이 여럿이라 가는 곳으로 부른다)
				nm = MTG.short(json.load(open(orp)).get('region_name', nm)).split('·')[0]
			parts = tgt.split('-')
			other = next((q for q in parts if q != sid), parts[-1])
			st = dict(id='end_%s_%s' % (sid[:2].lower(), other.split('_')[-1].lower()[:8]), space=sid, name='%s 길목 역참' % nm, sign='驛', style=END_STYLE[sid], kind='end',
				at=('node', n['id']), note='노정 끝(%s) 가까이' % tgt, pony=sid == 'JJ_JEJU')
			r = pick(S, st, [c['_c'] for c in chosen + out if c['space'] == sid])
			if r is None:
				print('  (길목 역 자리 없음) %s %s' % (sid, n['id'])); continue
			st['_c'] = r[1]['c']; st['_site'] = r[1]; st['_d'] = r[2]; st['_target'] = tgt
			out.append(st)
	return out


def main():
	check = '--check' in sys.argv
	spaces = {}
	for st in STATIONS:
		if st['space'] not in spaces: spaces[st['space']] = Space(st['space'])
	for sid in END_STYLE:
		if sid not in spaces and os.path.exists(os.path.join(RD, sid, 'region.json')): spaces[sid] = Space(sid)
	chosen = []
	for st in STATIONS:
		S = spaces[st['space']]
		DBG.clear()
		r = pick(S, st, [c['_c'] for c in chosen if c['space'] == st['space']])
		if r is None:
			print('!! 자리 없음: %s (%s) %s' % (st['id'], st['space'], dict(DBG))); continue
		st = dict(st); st['_c'] = r[1]['c']; st['_site'] = r[1]; st['_d'] = r[2]
		chosen.append(st)
	chosen += end_stations(spaces, chosen)
	recs = []
	place = {}
	for k, st in enumerate(chosen):
		S = spaces[st['space']]; s = st['_site']
		node = st.get('reuse') or ('station_' + st['id'])
		yard = s['yard']
		rec = {
			'id': st['id'], 'name': st['name'], 'sign': st.get('sign', '驛'), 'space': st['space'], 'space_kind': 'route' if S.is_route else 'region',
			'kind': st['kind'], 'style': st['style'], 'hub': bool(st.get('hub', False)), 'pony': bool(st.get('pony', False)),
			'pos': [round(s['c'][0], 2), round(s['c'][1], 2)], 'ry': round(s['ry'], 4),
			'yard': [round(yard[0], 2), round(yard[1], 2)], 'road': [round(s['road'][0], 2), round(s['road'][1], 2)],
			'hitch': [round(s['hitch'][0], 2), round(s['hitch'][1], 2)], 'wait': [round(s['hitch'][0] + 0.25, 2), round(s['hitch'][1] + 0.85, 2)],
			'node': node, 'reuse_node': bool(st.get('reuse')), 'discover_key': 'travel_nodes/%s/%s' % (st['space'], node),
			'lonlat': lonlat(S, s['c'][0], s['c'][1]), 'footprint': [W, D], 'radius': 24.0,
		}
		if st.get('note'): rec['note'] = st['note']
		recs.append(rec)
		params = {'seed': 7001 + k, 'style': st['style'], 'hub': bool(st.get('hub', False))}
		place.setdefault(st['space'], []).append({'id': 'station_' + st['id'], 'kit': KIT, 'params': params, 'x': rec['pos'][0], 'z': rec['pos'][1],
			'ry': rec['ry'], 'flatten': True, 'clear_veg': True, 'yard': True, 'group': 'station'})
		place[st['space']].append({'id': 'station_%s_gate' % st['id'], 'kit': 'station/hitch', 'params': {'seed': 7101 + k, 'hub': bool(st.get('hub', False))},
			'x': rec['hitch'][0], 'z': rec['hitch'][1], 'ry': 0.0, 'flatten': True, 'clear_veg': True, 'yard': False, 'group': 'station'})
		print('%-12s %-28s %-24s pos=(%7.1f,%7.1f) ry=%5.1f° 기준에서 %4.0fm 높이차 %.1fm' % (st['id'], st['space'], st['name'], rec['pos'][0], rec['pos'][1],
			math.degrees(rec['ry']), st['_d'], s['slope']))
	if check: return
	doc = {'version': 1, 'generated_by': 'tools/region/make_stations.py', 'kit': 'res://kit/station/mabang.gd',
		'note': '역참·마방. pos·ry = 마방 터(kit/station/mabang.gd, 정면 +z ≈ 남쪽), hitch = 길가 문 앞(kit/station/hitch.gd, ry 0), wait = 안장 얹고 기다리는 말, yard = 도착·말 타는 자리(길가), node = region_data/travel/<space>.json 거점 id(역마 거점), '
			'discover_key = progress.json travel_nodes/<space>/<node>(가 보면 적힘). lonlat = 전국 지도 자리(경도, 위도).',
		'stations': recs}
	with open(OUT, 'w') as f: json.dump(doc, f, ensure_ascii=False, indent=1)
	# 공간마다 배치 파일(마방이 없어진 공간의 옛 파일은 지운다)
	for f in glob.glob(os.path.join(RD, '*', PLACE_FILE)) + glob.glob(os.path.join(RD, 'routes', '*', PLACE_FILE)):
		sid = os.path.basename(os.path.dirname(f))
		if sid not in place: os.remove(f)
	for sid, items in place.items():
		S = spaces[sid]
		with open(os.path.join(S.dir, PLACE_FILE), 'w') as f:
			json.dump({'generated_by': 'tools/region/make_stations.py', 'note': '역참 마방(kit/station/mabang.gd) — region_data/stations.json', 'items': items},
				f, ensure_ascii=False, indent=1)
	print('stations=%d → %s' % (len(recs), os.path.relpath(OUT, ROOT)))


if __name__ == '__main__':
	main()
