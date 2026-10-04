#!/usr/bin/env python3
# 이동수단 개선안 v1.0(seolhwa/docs/scenario/seolhwarok_TRAVEL_TRANSPORT_IMPROVEMENT_PLAN_v1.0.md) — 자동 기승 길·TRAVEL_GATE·멈춤 정책 만들기.
#
# 있는 데이터에서 저절로 만든다(손으로 고칠 것은 region_data/travel/overrides.json):
#   - 말 탈 길 그래프: region.json / route.json roads 중 대로·지선(뱃길 'ferry' 빼고). 8m마다 점, 길끼리 만나는 곳(끝점 12m 안·교차)을 잇는다.
#     40m 넘게 물(토지이용 5) 위를 지나는 구간(배로 건너는 곳)은 끊는다 — 말은 물을 건너지 않는다(여울·다리는 짧아 그대로).
#   - 거점(nodes): 고을·마을·장·주막·역·나루·절·고개(권역 passes)·노정 쉼터(stops)·포털 끝·굴 입구(interiors)·주막 키트(배치).
#     거점마다 구역(원·사각형·성곽 다각형)과 어귀 TRAVEL_GATE(큰길이 구역 경계를 지나는 곳 바깥 — 말에서 내리는 곳·다시 타는 곳).
#     도시(읍성·도성)는 성 안에 말을 들이지 않는다: 어귀는 성문 앞(성곽·core 사각형 밖 18m).
#   - 멈춤 정책(stops): PASS / OPTIONAL_STOP(감속, 멈출 수 있음) / FORCED_STOP(멈추고 내림) — 거점 종류·노정 볼거리(encounter 등급)로 정한다.
#   - 노정 필드(§24): ROUTE_ID·START_NODE·END_NODE·FIRST_VISIT_REQUIRED·AUTO_RIDE_ALLOWED·BASE_RIDE_SPEED·WEATHER_SPEED_MOD·
#     TRAVEL_GATES·OPTIONAL_STOPS·FORCED_STOPS·FAST_TRAVEL_NODES·SCENIC_BEATS (FAST_TRAVEL_UNLOCKED는 저장 상태라 엔진이 정한다).
# 이야기 사건 자리(사건 데이터 triggers·objects·소문·길가 장면)는 조건(when)에 따라 바뀌어 엔진(scripts/region/horse_ride.gd)이
# 실행 중에 사건 데이터에서 바로 뽑는다(트리거 70~200m 앞 하차, 엿듣는 대사·길가 장면은 감속).
#
# 실행: python3 tools/region/make_travel_gates.py            # 모든 권역·노정 → region_data/travel/<공간 id>.json
#       python3 tools/region/make_travel_gates.py JL_NAMWON_UNBONG
import json, math, os, sys, glob
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
RD = os.path.join(ROOT, 'region_data')
OUT = os.path.join(RD, 'travel')

RIDE_CLASSES = {'대로': 4, '지선': 3}
STEP = 8.0            # 길 점 간격(m)
JOIN_R = 12.0         # 길 끝이 다른 길에서 이만큼 안이면 잇는다
WET_BREAK = 40.0      # 이보다 긴 물 위 구간은 끊는다(배로 건너는 곳)
GATE_OUT = 10.0       # 마을 어귀: 구역 경계 바깥으로
CITY_OUT = 18.0       # 성문 앞: 성 밖으로
OFFROAD_MAX = 150.0   # 길에서 이만큼 안이면 가장 가까운 길 점을 어귀로

BASE_RIDE_SPEED = 18.0
WEATHER_SPEED_MOD = {'clear': 1.0, 'cloudy': 1.0, 'fog': 0.9, 'wind': 0.92, 'rain': 0.85, 'snow': 0.75, 'storm': 0.7, 'blizzard': 0.0}

# 거점 종류별: (GATE_TYPE, 멈춤 정책(지나갈 때), 감속 m/s, 빠른 이동 거점?, 말 타는 곳?)
#   감속 0 = 감속 없음. FORCED_STOP = 그 구역 앞(어귀)에서 내린다. OPTIONAL_STOP은 '약간 감속'(§8.2) — 말 최고 18m/s에서 9~11m/s.
KIND = {
	'CITY':    ('CITY', 'FORCED_STOP', 0.0, True, True),
	'MARKET':  ('MARKET', 'OPTIONAL_STOP', 6.0, True, False),
	'VILLAGE': ('VILLAGE', 'OPTIONAL_STOP', 10.0, True, True),
	'HAMLET':  ('VILLAGE', 'OPTIONAL_STOP', 11.0, False, False),
	'INN':     ('VILLAGE', 'OPTIONAL_STOP', 10.0, True, True),
	'STATION': ('VILLAGE', 'OPTIONAL_STOP', 10.0, True, True),
	'FERRY':   ('FERRY', 'OPTIONAL_STOP', 7.0, True, True),      # 여울·나루터(물을 걸어 건넘). 배로 건너는 곳은 BOAT
	'BOAT':    ('FERRY', 'FORCED_STOP', 0.0, True, True),
	'TEMPLE':  ('TEMPLE', 'FORCED_STOP', 0.0, True, False),
	'SHRINE':  ('PASS', 'OPTIONAL_STOP', 11.0, False, False),
	'PASS':    ('PASS', 'OPTIONAL_STOP', 11.0, True, False),
	'COAST':   ('COAST', 'OPTIONAL_STOP', 10.0, True, False),
	'CAVE':    ('CAVE', 'FORCED_STOP', 0.0, False, False),
	'ROUTE_END': ('EVENT', 'FORCED_STOP', 0.0, True, True),   # 노정 끝(공간 넘어가기) — 포털 앞에서 멈춘다
	'HUB':     ('VILLAGE', 'OPTIONAL_STOP', 9.0, True, True),
}
SETTLE_KIND = {'읍성': 'CITY', '장시': 'MARKET', '마을': 'VILLAGE', '길가 마을': 'HAMLET', '쉼터': 'INN', '주막': 'INN', '역': 'STATION',
	'나루': 'FERRY', '포구': 'FERRY', '사찰': 'TEMPLE', '성황당': 'SHRINE', '원': 'INN'}
STOP_KIND = {'jumak': 'INN', 'town': 'HUB', 'village': 'VILLAGE', 'naru': 'FERRY', 'pass': 'PASS', 'pass_gate': 'PASS', 'samgeori': 'INN',
	'coast': 'COAST', 'port': 'FERRY', 'pier': 'FERRY', 'hamlet': 'HAMLET', 'station': 'STATION', 'temple': 'TEMPLE', 'cliff': 'COAST',
	'saejae': 'PASS', 'jebiwon': 'VILLAGE', 'alpine_village': 'VILLAGE', 'bukcheong': 'HUB', 'bridge': 'VILLAGE', 'port_arrive': 'FERRY'}
# 노정 볼거리(sights) 분류 → (GATE_TYPE, 등급별 정책). encounter.event_grade A·B는 감속(멈출 수 있음), C·D는 그냥 지나감
SIGHT_TYPE = {'pass': 'PASS', 'forest': 'FOREST', 'crossing': 'FERRY', 'ruin': 'EVENT', 'inn_site': 'EVENT', 'tomb': 'FOREST', 'pool': 'FOREST',
	'roadside': 'VILLAGE', 'hamlet': 'VILLAGE', 'sea': 'COAST', 'shoal': 'COAST', 'rapids': 'FERRY', 'shrine': 'TEMPLE', 'jochang': 'VILLAGE', 'pavilion': 'VILLAGE'}
GRADE_POLICY = {'A': ('OPTIONAL_STOP', 8.0), 'B': ('OPTIONAL_STOP', 10.0), 'C': ('PASS', 0.0), 'D': ('PASS', 0.0)}


def short(n):
	for sep in ['(', '—', ' — ']:
		i = n.find(sep)
		if i > 0: n = n[:i]
	return n.strip()


def load_landuse(space_dir, j):
	lm = j.get('landuse') or {}
	p = os.path.join(space_dir, lm.get('file', 'landuse.png'))
	if not os.path.exists(p): return None
	a = np.array(Image.open(p))
	return {'a': a, 'x0': float(lm.get('x0', 0)), 'z0': float(lm.get('z0', 0)), 'cell': float(lm.get('cell', 4))}


def lu_at(L, x, z):
	if L is None: return 1
	i = int(round((x - L['x0']) / L['cell'])); jj = int(round((z - L['z0']) / L['cell']))
	h, w = L['a'].shape[:2]
	if i < 0 or jj < 0 or i >= w or jj >= h: return 1
	return int(L['a'][jj, i]) & 0x7f


def resample(pts, step=STEP):
	out = [pts[0]]
	for a, b in zip(pts, pts[1:]):
		d = math.dist(a, b)
		n = max(1, int(math.ceil(d / step)))
		for k in range(1, n + 1):
			t = k / n
			out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
	return out


def split_wet(pts, L):
	"""물 위로 WET_BREAK m 넘게 이어지는 구간에서 끊는다(배로 건너는 곳). 반환: 조각 목록"""
	wet = [lu_at(L, x, z) == 5 for x, z in pts]
	pieces = []; cur = []
	i = 0
	n = len(pts)
	while i < n:
		if wet[i]:
			j = i
			while j < n and wet[j]: j += 1
			run = math.dist(pts[max(i - 1, 0)], pts[min(j, n - 1)])
			if run > WET_BREAK:
				if len(cur) >= 2: pieces.append(cur)
				cur = []
				i = j
				continue
			cur.extend(pts[i:j]); i = j
			continue
		cur.append(pts[i]); i += 1
	if len(cur) >= 2: pieces.append(cur)
	return pieces


class Graph:
	def __init__(self):
		self.pts = []; self.edges = set(); self.cls = []; self.grid = {}
	def _key(self, x, z, c=16.0): return (int(math.floor(x / c)), int(math.floor(z / c)))
	def near(self, x, z, r):
		best = -1; bd = r
		kx, kz = self._key(x, z)
		for dx in (-1, 0, 1):
			for dz in (-1, 0, 1):
				for i in self.grid.get((kx + dx, kz + dz), []):
					d = math.dist(self.pts[i], (x, z))
					if d < bd: bd = d; best = i
		return best, bd
	def add(self, x, z, cl, merge=1.5):
		i, d = self.near(x, z, merge)
		if i >= 0:
			self.cls[i] = max(self.cls[i], cl); return i
		self.pts.append((x, z)); self.cls.append(cl)
		self.grid.setdefault(self._key(x, z), []).append(len(self.pts) - 1)
		return len(self.pts) - 1
	def link(self, a, b):
		if a != b: self.edges.add((min(a, b), max(a, b)))
	def degree(self):
		deg = [0] * len(self.pts)
		for a, b in self.edges: deg[a] += 1; deg[b] += 1
		return deg


def build_graph(roads, L):
	g = Graph()
	ends = []   # (점 번호, 조각 번호)
	piece_ids = []
	for r in roads:
		cl = RIDE_CLASSES[r['class']]
		raw = [(float(p[0]), float(p[1])) for p in r['points']]
		if len(raw) < 2: continue
		for piece in split_wet(resample(raw), L):
			idx = [g.add(x, z, cl) for x, z in piece]
			pid = len(piece_ids); piece_ids.append(set(idx))
			for a, b in zip(idx, idx[1:]): g.link(a, b)
			ends.append((idx[0], pid)); ends.append((idx[-1], pid))
	# 길 끝 → 다른 조각의 가장 가까운 점(12m 안)
	for e, pid in ends:
		x, z = g.pts[e]
		best = -1; bd = JOIN_R
		kx, kz = g._key(x, z)
		for dx in (-1, 0, 1):
			for dz in (-1, 0, 1):
				for i in g.grid.get((kx + dx, kz + dz), []):
					if i in piece_ids[pid]: continue
					d = math.dist(g.pts[i], (x, z))
					if d < bd: bd = d; best = i
		if best >= 0: g.link(e, best)
	# 가운데에서 엇갈리는 길(X자): 다른 조각 점이 4m 안이면 잇는다
	for pid, ids in enumerate(piece_ids):
		for i in ids:
			x, z = g.pts[i]
			kx, kz = g._key(x, z)
			for dx in (-1, 0, 1):
				for dz in (-1, 0, 1):
					for k in g.grid.get((kx + dx, kz + dz), []):
						if k in ids or k == i: continue
						if math.dist(g.pts[k], (x, z)) < 4.0: g.link(i, k)
	return g


def seg_cross_circle(a, b, c, r):
	"""선분 a→b가 원 경계를 지나는 t 목록"""
	dx, dz = b[0] - a[0], b[1] - a[1]
	fx, fz = a[0] - c[0], a[1] - c[1]
	A = dx * dx + dz * dz
	if A < 1e-9: return []
	B = 2 * (fx * dx + fz * dz); C = fx * fx + fz * fz - r * r
	disc = B * B - 4 * A * C
	if disc < 0: return []
	s = math.sqrt(disc)
	return [t for t in ((-B - s) / (2 * A), (-B + s) / (2 * A)) if 0.0 <= t <= 1.0]


def inside(zone, x, z):
	k = zone['kind']
	if k == 'circle': return math.dist((x, z), zone['c']) <= zone['r']
	if k == 'rect':
		x0, z0, x1, z1 = zone['rect']; return x0 <= x <= x1 and z0 <= z <= z1
	if k == 'poly':
		pts = zone['pts']; n = len(pts); c = False
		j = n - 1
		for i in range(n):
			xi, zi = pts[i]; xj, zj = pts[j]
			if ((zi > z) != (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi + 1e-12) + xi): c = not c
			j = i
		return c
	return False


def zone_gates(g, zone, out_m, node_id):
	"""그래프 간선이 구역 경계를 지나는 곳 → 바깥으로 out_m 물러선 그래프 점(어귀). [{gi, x, z, edge_in}]"""
	res = []
	adj = {}
	for a, b in g.edges:
		adj.setdefault(a, []).append(b); adj.setdefault(b, []).append(a)
	ins = [inside(zone, x, z) for x, z in g.pts]
	seen = set()
	for a, b in g.edges:
		if ins[a] == ins[b]: continue
		o = a if not ins[a] else b      # 바깥 점
		i = b if o == a else a
		if o in seen: continue
		# 바깥쪽으로 out_m만큼 그래프를 따라 물러선다(안쪽 점에서 멀어지는 방향)
		prev, cur, walked = i, o, math.dist(g.pts[o], g.pts[i]) * 0.5
		while walked < out_m:
			nxt = [k for k in adj.get(cur, []) if k != prev and not ins[k]]
			if not nxt: break
			k = max(nxt, key=lambda k: math.dist(g.pts[k], g.pts[i]))
			walked += math.dist(g.pts[k], g.pts[cur]); prev, cur = cur, k
		if cur in seen: continue
		seen.add(o); seen.add(cur)
		ox, oz = g.pts[cur]; ix, iz = g.pts[i]
		d = math.dist((ox, oz), (ix, iz)) or 1.0
		res.append({'gi': cur, 'x': round(ox, 1), 'z': round(oz, 1), 'out': [round((ox - ix) / d, 3), round((oz - iz) / d, 3)]})
	# 같은 쪽(25m 안) 어귀는 하나로
	keep = []
	for r in res:
		if all(math.dist((r['x'], r['z']), (k['x'], k['z'])) > 25.0 for k in keep): keep.append(r)
	return keep


def nearest_gi(g, x, z, rmax):
	best = -1; bd = rmax
	for i, p in enumerate(g.pts):
		d = math.dist(p, (x, z))
		if d < bd: bd = d; best = i
	return best, bd


def zone_of_settlement(s, j, kind):
	c = (float(s['x']), float(s['z']))
	if kind == 'CITY':
		# 성곽 다각형(region walls — 이 고을 안에 있으면) > core(성벽 사각형) > bbox
		for w in j.get('walls', []):
			pts = [(float(p[0]), float(p[1])) for p in w.get('points', [])]
			if w.get('closed') and len(pts) > 3 and inside({'kind': 'poly', 'pts': pts}, *c):
				return {'kind': 'poly', 'pts': pts}
		if isinstance(s.get('core'), list) and len(s['core']) == 4:
			return {'kind': 'rect', 'rect': [float(v) for v in s['core']]}
		if isinstance(s.get('bbox'), list) and len(s['bbox']) == 4:
			x0, z0, x1, z1 = [float(v) for v in s['bbox']]
			return {'kind': 'rect', 'rect': [x0 + (x1 - x0) * 0.15, z0 + (z1 - z0) * 0.15, x1 - (x1 - x0) * 0.15, z1 - (z1 - z0) * 0.15]}
	r = float(s.get('radius_m', 40.0))
	if kind in ('MARKET',): r = min(r, 70.0)
	return {'kind': 'circle', 'c': c, 'r': max(18.0, r)}


def zone_json(z):
	if z['kind'] == 'circle': return {'kind': 'circle', 'c': [round(z['c'][0], 1), round(z['c'][1], 1)], 'r': round(z['r'], 1)}
	if z['kind'] == 'rect': return {'kind': 'rect', 'rect': [round(v, 1) for v in z['rect']]}
	return {'kind': 'poly', 'pts': [[round(x, 1), round(zz, 1)] for x, zz in z['pts']]}


def placement_items(space_dir):
	out = []
	for f in sorted(glob.glob(os.path.join(space_dir, 'placement_*.json'))):
		try: d = json.load(open(f))
		except Exception: continue
		for it in d.get('items', []):
			if isinstance(it, dict) and 'x' in it: out.append(it)
	return out


def route_portals_into(region_id):
	"""노정 파일들에서 이 권역 쪽 포털 자리(region_main과 같은 방식)"""
	out = []
	for f in sorted(glob.glob(os.path.join(RD, 'routes', '*', 'route.json'))):
		r = json.load(open(f))
		for end, p in (r.get('portals') or {}).items():
			if isinstance(p, dict) and p.get('region') == region_id and 'x' in p:
				out.append({'id': '%s_%s' % (r['route_id'], end), 'name': p.get('name', r.get('name', '')), 'x': float(p['x']), 'z': float(p['z']),
					'target': r['route_id'], 'label': short(r.get('name', r['route_id']))})
	return out


def build_space(space_id, space_dir, is_route, overrides):
	j = json.load(open(os.path.join(space_dir, 'route.json' if is_route else 'region.json')))
	L = load_landuse(space_dir, j)
	river = is_route and str(j.get('route_type', '')) == 'river'
	roads = [r for r in j.get('roads', []) if r.get('class') in RIDE_CLASSES and 'ferry' not in str(r.get('id', ''))
		and len(r.get('points', [])) >= 2]
	if river: roads = []
	g = build_graph(roads, L)
	nodes = []

	def add_node(nid, name, kind, x, z, zone, extra=None):
		gt, pol, slow, fast, mount = KIND[kind]
		n = {'id': nid, 'name': name, 'kind': kind, 'type': gt, 'x': round(x, 1), 'z': round(z, 1), 'zone': zone, 'fast': fast, 'mount': mount,
			'policy': pol, 'slow': slow}
		if extra: n.update(extra)
		nodes.append(n)
		return n

	if not is_route:
		for s in j.get('settlements', []):
			k = SETTLE_KIND.get(s.get('type', ''), 'VILLAGE')
			nm = str(s.get('name', s.get('id', '')))
			if '나루' in nm and k in ('INN', 'VILLAGE'): k = 'FERRY'
			auto = str(s.get('id', '')).startswith('auto_village')
			if auto: k = 'HAMLET'
			n = add_node(s['id'], short(s.get('title', nm)) if not auto else '들마을', k, float(s['x']), float(s['z']), zone_of_settlement(s, j, k))
			if auto: n['fast'] = False
		for p in j.get('passes', []):
			if 'x' not in p: continue
			nm = str(p.get('name', ''))
			add_node(p['id'], short(nm), 'PASS', float(p['x']), float(p['z']), {'kind': 'circle', 'c': (float(p['x']), float(p['z'])), 'r': 40.0},
				{'fast': nm not in ('무명 고개', '') })
		# 포털 끝(노정으로 넘어가는 곳) — 노정 파일 + region.json portals(같은 대상·10m 안이면 하나)
		ports = route_portals_into(space_id)
		for p in j.get('portals', []):
			to = p.get('to')
			tgt = to.split(':', 1)[1] if isinstance(to, str) and ':' in to else (to.get('route', to.get('region', '')) if isinstance(to, dict) else '')
			if not tgt or 'x' not in p: continue
			if any(q['target'] == tgt and math.dist((q['x'], q['z']), (float(p['x']), float(p['z']))) < 10.0 for q in ports): continue
			ports.append({'id': p.get('id', tgt), 'name': p.get('name', ''), 'x': float(p['x']), 'z': float(p['z']), 'target': tgt, 'label': short(str(p.get('name', tgt)).lstrip('→ '))})
		for p in ports:
			lab = str(p.get('label') or p.get('name') or p['target'])
			add_node('end_' + p['id'], '%s 길목' % short(lab.lstrip('→ ')), 'ROUTE_END', p['x'], p['z'], {'kind': 'circle', 'c': (p['x'], p['z']), 'r': 28.0},
				{'portal': p['id'], 'target': p['target']})
		# 배로 건너는 나루(crossings 나루 + ends): 양 끝
		for c in j.get('crossings', []):
			if c.get('type') != '나루' or not isinstance(c.get('ends'), list) or len(c['ends']) < 2: continue
			for e, end in enumerate(c['ends'][:2]):
				add_node('%s_%d' % (c['id'], e), short(str(c.get('name', '나루'))), 'BOAT', float(end[0]), float(end[1]),
					{'kind': 'circle', 'c': (float(end[0]), float(end[1])), 'r': 22.0}, {'boat': c['id']})
	else:
		for s in j.get('stops', []):
			k = STOP_KIND.get(s.get('type', ''), 'VILLAGE')
			r = 55.0
			for st in j.get('settlements', []):
				if st.get('id') == s.get('id'): r = float(st.get('radius_m', r))
			add_node(s['id'], str(s.get('title') or short(s.get('name', s['id']))), k, float(s['x']), float(s['z']),
				{'kind': 'circle', 'c': (float(s['x']), float(s['z'])), 'r': max(30.0, min(r, 70.0))}, {'t': s.get('t')})
		# 노정 양 끝·갈림 끝(포털)
		main = max(roads, key=lambda r: (RIDE_CLASSES[r['class']] * 10, len(r['points']))) if roads else None
		for end, p in (j.get('portals') or {}).items():
			if not isinstance(p, dict) or end == 'note': continue
			if 'route_x' in p: x, z = float(p['route_x']), float(p['route_z'])
			elif main is not None: x, z = main['points'][0] if end == 'from' else main['points'][-1]
			else: continue
			tgt = p.get('region') or p.get('route') or ''
			nm = str(p.get('name', '')) or tgt
			add_node('end_' + end, '%s 길목' % short(nm), 'ROUTE_END', float(x), float(z), {'kind': 'circle', 'c': (float(x), float(z)), 'r': 26.0},
				{'portal': '%s_%s' % (space_id, end), 'target': tgt, 'end': end})
		for c in j.get('crossings', []):
			if c.get('type') == '나루' and c.get('sea_lane') and isinstance(c.get('ends'), list):
				for e, end in enumerate(c['ends'][:2]):
					add_node('%s_%d' % (c['id'], e), short(str(c.get('name', '나루'))), 'BOAT', float(end[0]), float(end[1]),
						{'kind': 'circle', 'c': (float(end[0]), float(end[1])), 'r': 22.0}, {'boat': c['id']})
	# 굴·큰 실내 입구(interiors)
	for f in sorted(glob.glob(os.path.join(RD, 'interiors', '*', 'interior.json'))):
		it = json.load(open(f))
		if it.get('region') != space_id: continue
		for e in it.get('entrances', []):
			x, z = float(e['at'][0]), float(e['at'][1])
			add_node('cave_%s_%s' % (it['id'], e['id']), short(str(it.get('name', '굴'))) + ' 어귀', 'CAVE', x, z, {'kind': 'circle', 'c': (x, z), 'r': 30.0})
	# 주막 키트(배치) — 큰길 가 주막은 말 타는 곳(같은 자리 거점이 없을 때만)
	for it in placement_items(space_dir):
		if not str(it.get('kit', '')).startswith('village/jumak'): continue
		x, z = float(it['x']), float(it['z'])
		if any(math.dist((x, z), (n['x'], n['z'])) < 60.0 for n in nodes): continue
		gi, d = nearest_gi(g, x, z, 40.0)
		if gi < 0: continue
		near = min(((math.dist((x, z), (n['x'], n['z'])), n['name']) for n in nodes if n['kind'] not in ('HAMLET', 'ROUTE_END', 'BOAT', 'CAVE')), default=(1e9, ''))
		nm = ('%s 길 주막' % near[1]) if near[0] < 900.0 else '길가 주막'
		add_node('inn_%d_%d' % (round(x), round(z)), nm, 'INN', x, z, {'kind': 'circle', 'c': (x, z), 'r': 18.0}, {'fast': False})

	# 도시(읍성·도성) 안 길 점: 말을 들이지 않는다(엔진 길 찾기에서 막음). 도시 안 거점의 어귀는 버린다(걸어서 간다)
	city_zones = [n['zone'] for n in nodes if n['kind'] == 'CITY']
	in_city = [i for i, p in enumerate(g.pts) if any(inside(z, *p) for z in city_zones)]
	city_set = set(in_city)
	# 거점마다 어귀(gates)
	gates = []
	for n in nodes:
		zone = n['zone']
		out_m = CITY_OUT if n['kind'] == 'CITY' else GATE_OUT
		gl = zone_gates(g, zone, out_m, n['id']) if len(g.pts) else []
		if n['kind'] != 'CITY': gl = [x for x in gl if x['gi'] not in city_set]
		if not gl and len(g.pts):
			gi, d = nearest_gi(g, n['x'], n['z'], OFFROAD_MAX)
			if gi in city_set and n['kind'] != 'CITY': gi = -1
			if gi >= 0 and not inside(zone, *g.pts[gi]):
				gl = [{'gi': gi, 'x': round(g.pts[gi][0], 1), 'z': round(g.pts[gi][1], 1), 'out': [0, 0], 'offroad': round(d, 1)}]
			elif gi >= 0:
				# 길이 구역 한가운데를 지나지 않고 안에서 끝남(막다른 길 끝 쉼터 등): 그 점
				gl = [{'gi': gi, 'x': round(g.pts[gi][0], 1), 'z': round(g.pts[gi][1], 1), 'out': [0, 0], 'inner': True}]
		n['gates'] = gl
		for k, gt in enumerate(gl):
			gates.append({'GATE_ID': '%s#%d' % (n['id'], k), 'ROUTE_ID': space_id, 'GATE_TYPE': n['type'], 'POSITION': [gt['x'], gt['z']],
				'TRIGGER_RADIUS': 14.0, 'AUTO_SLOW': True, 'AUTO_DISMOUNT': True, 'EVENT_ID': None,
				'REENTER_RIDE_ALLOWED': bool(n['mount'] or n['kind'] in ('VILLAGE', 'HAMLET', 'PASS', 'FERRY', 'MARKET', 'HUB')),
				'node': n['id'], 'gi': gt['gi']})
		n['zone'] = zone_json(zone)
		n['arrive'] = [gl[0]['x'], gl[0]['z']] if gl else [n['x'], n['z']]
	# 지나갈 때 멈춤 정책(stops) — 거점 구역 + 노정 볼거리
	stops = []
	for n in nodes:
		stops.append({'TRAVEL_EVENT_ID': n['id'], 'ROUTE_ID': space_id, 'EVENT_TYPE': n['type'], 'TRIGGER_POSITION': [n['x'], n['z']],
			'zone': n['zone'], 'WEATHER_CONDITION': None, 'TIME_CONDITION': None, 'STOP_POLICY': n['policy'], 'EVENT_ID': None,
			'ONE_TIME': False, 'SLOW_SPEED': n['slow'], 'MUST': False, 'node': n['id'], 'name': n['name']})
	for s in j.get('sights', []) if is_route else []:
		enc = s.get('encounter') or {}
		gr = str(enc.get('event_grade', enc.get('grade', 'D')))
		pol, slow = GRADE_POLICY.get(gr, ('PASS', 0.0))
		x, z = float(s['x']), float(s['z'])
		stops.append({'TRAVEL_EVENT_ID': s['id'], 'ROUTE_ID': space_id, 'EVENT_TYPE': SIGHT_TYPE.get(str(s.get('category', '')), 'VILLAGE'),
			'TRIGGER_POSITION': [x, z], 'zone': {'kind': 'circle', 'c': [x, z], 'r': 36.0}, 'WEATHER_CONDITION': None, 'TIME_CONDITION': None,
			'STOP_POLICY': pol, 'EVENT_ID': None, 'ONE_TIME': False, 'SLOW_SPEED': slow, 'MUST': False, 'name': str(s.get('title', '')),
			'grade': gr})
	# 말 타는 곳: 거점 어귀(mount) + 큰길 갈림(대로 점, 이웃 3 이상)
	mounts = []
	for n in nodes:
		if not n['mount']: continue
		for gt in n['gates']: mounts.append({'id': n['id'], 'kind': n['kind'], 'x': gt['x'], 'z': gt['z']})
	deg = g.degree()
	for i, dg in enumerate(deg):
		if dg >= 3 and g.cls[i] >= 4 and i not in city_set and not any(math.dist(g.pts[i], (m['x'], m['z'])) < 60.0 for m in mounts):
			mounts.append({'id': 'junction_%d' % i, 'kind': 'JUNCTION', 'x': round(g.pts[i][0], 1), 'z': round(g.pts[i][1], 1)})

	out = {
		'space': space_id, 'kind': 'route' if is_route else 'region', 'version': 1, 'generated_by': 'tools/region/make_travel_gates.py',
		'ride': {
			'ROUTE_ID': space_id, 'AUTO_RIDE_ALLOWED': bool(len(g.pts) > 1 and not river), 'BASE_RIDE_SPEED': BASE_RIDE_SPEED,
			'WEATHER_SPEED_MOD': WEATHER_SPEED_MOD, 'FIRST_VISIT_REQUIRED': bool(is_route),
		},
		'graph': {'pts': [[round(x, 1), round(z, 1)] for x, z in g.pts], 'edges': sorted([list(e) for e in g.edges]), 'cls': g.cls, 'city': in_city},
		'nodes': nodes, 'gates': gates, 'stops': stops, 'mounts': mounts,
	}
	# 전국 지도 자리(역마 연출): 권역 projection, 노정 geo_line + 거점 진행도 t
	if isinstance(j.get('projection'), dict): out['projection'] = j['projection']
	if is_route:
		out['geo_line'] = j.get('geo_line', [])
		main_pts = [(float(p[0]), float(p[1])) for p in (max(roads, key=lambda r: (RIDE_CLASSES[r['class']] * 10, len(r['points'])))['points'] if roads else [])]
		for n in nodes:
			if n.get('t') is None: n['t'] = round(progress(main_pts, n['x'], n['z']), 4) if main_pts else 0.5
	rd = out['ride']
	if is_route:
		ends = [n for n in nodes if n['kind'] == 'ROUTE_END']
		rd['START_NODE'] = next((n['id'] for n in ends if n.get('end') == 'from'), None)
		rd['END_NODE'] = next((n['id'] for n in ends if n.get('end') == 'to'), None)
		rd['SCENIC_BEATS'] = [x['title'] for x in sorted(j.get('stops', []) + j.get('sights', []), key=lambda s: float(s.get('t', 0) or 0)) if x.get('title')]
	rd['TRAVEL_GATES'] = [gt['GATE_ID'] for gt in gates]
	rd['OPTIONAL_STOPS'] = [s['TRAVEL_EVENT_ID'] for s in stops if s['STOP_POLICY'] == 'OPTIONAL_STOP']
	rd['FORCED_STOPS'] = [s['TRAVEL_EVENT_ID'] for s in stops if s['STOP_POLICY'] == 'FORCED_STOP']
	rd['FAST_TRAVEL_NODES'] = [n['id'] for n in nodes if n['fast']]
	apply_overrides(out, overrides.get(space_id, {}))
	return out


def apply_overrides(out, ov):
	"""손으로 고친 값(overrides.json): ride{} 덮기, stops_set{id: 필드}, stops_add[], nodes_set{id: 필드}, nodes_add[], gates_add[]"""
	if not ov: return
	out['ride'].update(ov.get('ride', {}))
	byid = {s['TRAVEL_EVENT_ID']: s for s in out['stops']}
	for sid, f in ov.get('stops_set', {}).items():
		if sid in byid: byid[sid].update(f); byid[sid]['override'] = True
	for s in ov.get('stops_add', []):
		s = dict(s); s.setdefault('ROUTE_ID', out['space']); s['override'] = True
		if 'zone' not in s:
			p = s['TRIGGER_POSITION']; s['zone'] = {'kind': 'circle', 'c': p, 'r': float(s.get('RADIUS', 30.0))}
		out['stops'] = [x for x in out['stops'] if x['TRAVEL_EVENT_ID'] != s['TRAVEL_EVENT_ID']] + [s]
	nb = {n['id']: n for n in out['nodes']}
	for nid, f in ov.get('nodes_set', {}).items():
		if nid in nb: nb[nid].update(f); nb[nid]['override'] = True
	for n in ov.get('nodes_add', []):
		n = dict(n); n['override'] = True; out['nodes'].append(n)
	for gt in ov.get('gates_add', []):
		gt = dict(gt); gt['override'] = True; out['gates'].append(gt)
	rd = out['ride']
	rd['OPTIONAL_STOPS'] = [s['TRAVEL_EVENT_ID'] for s in out['stops'] if s['STOP_POLICY'] == 'OPTIONAL_STOP']
	rd['FORCED_STOPS'] = [s['TRAVEL_EVENT_ID'] for s in out['stops'] if s['STOP_POLICY'] == 'FORCED_STOP']
	rd['FAST_TRAVEL_NODES'] = [n['id'] for n in out['nodes'] if n.get('fast')]


def progress(pts, x, z):
	if len(pts) < 2: return 0.5
	tot = 0.0; best = 1e18; at = 0.0
	for a, b in zip(pts, pts[1:]):
		dx, dz = b[0] - a[0], b[1] - a[1]; l = math.hypot(dx, dz) or 1e-6
		t = max(0.0, min(1.0, ((x - a[0]) * dx + (z - a[1]) * dz) / (l * l)))
		d = math.dist((x, z), (a[0] + dx * t, a[1] + dz * t))
		if d < best: best = d; at = tot + t * l
		tot += l
	return at / tot


def main():
	only = set(sys.argv[1:])
	os.makedirs(OUT, exist_ok=True)
	ovp = os.path.join(OUT, 'overrides.json')
	overrides = json.load(open(ovp)) if os.path.exists(ovp) else {}
	overrides = {k: v for k, v in overrides.items() if not k.startswith('_')}
	spaces = []
	for d in sorted(glob.glob(os.path.join(RD, '*', 'region.json'))):
		spaces.append((os.path.basename(os.path.dirname(d)), os.path.dirname(d), False))
	for d in sorted(glob.glob(os.path.join(RD, 'routes', '*', 'route.json'))):
		spaces.append((json.load(open(d)).get('route_id', os.path.basename(os.path.dirname(d))), os.path.dirname(d), True))
	for sid, sdir, is_route in spaces:
		if only and sid not in only: continue
		out = build_space(sid, sdir, is_route, overrides)
		with open(os.path.join(OUT, sid + '.json'), 'w') as f:
			json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
		deg = [0] * len(out['graph']['pts'])
		for a, b in out['graph']['edges']: deg[a] += 1; deg[b] += 1
		comps = components(len(deg), out['graph']['edges'])
		print('%-30s pts=%5d edges=%5d parts=%d nodes=%3d gates=%3d stops=%3d (forced %d, optional %d) mounts=%d ride=%s' % (
			sid, len(deg), len(out['graph']['edges']), comps, len(out['nodes']), len(out['gates']), len(out['stops']),
			len(out['ride']['FORCED_STOPS']), len(out['ride']['OPTIONAL_STOPS']), len(out['mounts']), out['ride']['AUTO_RIDE_ALLOWED']))


def components(n, edges):
	par = list(range(n))
	def f(x):
		while par[x] != x: par[x] = par[par[x]]; x = par[x]
		return x
	for a, b in edges: par[f(a)] = f(b)
	return len({f(i) for i in range(n)}) if n else 0


if __name__ == '__main__':
	main()
