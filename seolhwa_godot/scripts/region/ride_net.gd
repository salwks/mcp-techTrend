# 자동 기승 길 그래프·거점·멈춤 정책 — region_data/travel/<공간 id>.json(tools/region/make_travel_gates.py가 만든다)을 읽는다.
#   graph: 큰길(대로·지선) 8m 점 + 이웃(갈림 포함). city: 도시(읍성·도성) 안 점 — 말을 들이지 않는다(길 찾기에서 막음).
#   nodes: 거점 {id, name, kind(CITY·MARKET·VILLAGE·HAMLET·INN·STATION·FERRY·BOAT·TEMPLE·SHRINE·PASS·COAST·CAVE·ROUTE_END·HUB),
#          type(GATE_TYPE), zone{circle|rect|poly}, gates[{gi,x,z,out}], fast, mount, policy, slow, arrive[x,z]}
#   stops: 지나갈 때 정책 {TRAVEL_EVENT_ID, STOP_POLICY(PASS·OPTIONAL_STOP·FORCED_STOP), SLOW_SPEED, MUST, zone, FIRST_VISIT_ONLY?, WHEN?, APPROACH_M?}
#   mounts: 말 타는 곳 {id, kind, x, z}
# 길 찾기는 그래프 다익스트라(같은 출발점에서 여러 목적지를 한 번에 — 목적지 고르기 목록·갈림길 선택에 쓴다).
extends RefCounted

const DIR := "res://region_data/travel/"
const CELL := 24.0

static var _cache := {}

var space := ""
var j := {}
var ride := {}
var pts := PackedVector2Array()
var cls := PackedByteArray()
var nb: Array = []                # [PackedInt32Array]
var city := PackedByteArray()     # 1 = 도시 안(말 못 들임)
var nodes: Array = []
var node_by := {}
var stops: Array = []
var mounts: Array = []
var _grid := {}

static func read(id: String) -> Dictionary:
	if _cache.has(id): return _cache[id]
	var p := DIR + id + ".json"
	var d := {}
	if FileAccess.file_exists(p):
		var x = JSON.parse_string(FileAccess.get_file_as_string(p))
		if x is Dictionary: d = x
	_cache[id] = d
	return d

static func all_spaces() -> Array:
	var out := []
	var da := DirAccess.open(DIR)
	if da == null: return out
	for f in da.get_files():
		if f.ends_with(".json") and f != "overrides.json": out.append(f.get_basename())
	return out

func setup(id: String) -> bool:
	space = id
	j = read(id)
	if j.is_empty(): return false
	ride = j.get("ride", {})
	var g: Dictionary = j.get("graph", {})
	var P: Array = g.get("pts", [])
	pts.resize(P.size()); cls.resize(P.size()); city.resize(P.size()); city.fill(0)
	var C: Array = g.get("cls", [])
	for i in P.size():
		pts[i] = Vector2(float(P[i][0]), float(P[i][1]))
		cls[i] = int(C[i]) if i < C.size() else 3
		var k := _key(pts[i])
		if not _grid.has(k): _grid[k] = PackedInt32Array()
		_grid[k].append(i)
	for c in g.get("city", []): city[int(c)] = 1
	var tmp: Array = []
	tmp.resize(P.size())
	for i in P.size(): tmp[i] = PackedInt32Array()
	for e in g.get("edges", []):
		var a := int(e[0]); var b := int(e[1])
		tmp[a].append(b); tmp[b].append(a)
	nb = tmp
	nodes = j.get("nodes", [])
	for n in nodes: node_by[String(n.id)] = n
	stops = j.get("stops", [])
	mounts = j.get("mounts", [])
	return true

func ok() -> bool: return pts.size() > 1 and bool(ride.get("AUTO_RIDE_ALLOWED", true))

func _key(p: Vector2) -> Vector2i: return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

# 가장 가까운 길 점(rmax 안, 도시 안 점은 allow_city일 때만). 없으면 −1
func nearest(p: Vector2, rmax: float, allow_city := false) -> int:
	var best := -1; var bd := rmax
	var k := _key(p)
	var rr := int(ceil(rmax / CELL))
	for dx in range(-rr, rr + 1):
		for dz in range(-rr, rr + 1):
			var cell = _grid.get(k + Vector2i(dx, dz))
			if cell == null: continue
			for i in cell:
				if not allow_city and city[i] == 1: continue
				var d := pts[i].distance_to(p)
				if d < bd: bd = d; best = i
	return best

# 길 위 가장 가까운 자리(선분 투영) — {i: 가까운 점, d: 거리}
func road_dist(p: Vector2, rmax: float) -> float:
	var i := nearest(p, rmax, true)
	if i < 0: return INF
	var best := pts[i].distance_to(p)
	for k in nb[i]:
		var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[k])
		best = minf(best, q.distance_to(p))
	return best

# 다익스트라(도시 안 점은 지나지 않음). {dist: PackedFloat32Array, prev: PackedInt32Array}
func dijkstra(src: int, max_d := INF) -> Dictionary:
	var n := pts.size()
	var dist := PackedFloat32Array(); dist.resize(n); dist.fill(INF)
	var prev := PackedInt32Array(); prev.resize(n); prev.fill(-1)
	if src < 0 or src >= n: return { dist = dist, prev = prev }
	var hk := PackedFloat32Array(); var hv := PackedInt32Array()
	dist[src] = 0.0
	_push(hk, hv, 0.0, src)
	while hk.size() > 0:
		var top := _pop(hk, hv)
		var d: float = top[0]; var u: int = top[1]
		if d > dist[u] + 0.01 or d > max_d: continue
		for w in nb[u]:
			if city[w] == 1: continue
			var nd := d + pts[u].distance_to(pts[w])
			if nd < dist[w]:
				dist[w] = nd; prev[w] = u
				_push(hk, hv, nd, w)
	return { dist = dist, prev = prev }

static func _push(hk: PackedFloat32Array, hv: PackedInt32Array, k: float, v: int) -> void:
	hk.append(k); hv.append(v)
	var i := hk.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if hk[p] <= hk[i]: break
		var tk := hk[p]; hk[p] = hk[i]; hk[i] = tk
		var tv := hv[p]; hv[p] = hv[i]; hv[i] = tv
		i = p

static func _pop(hk: PackedFloat32Array, hv: PackedInt32Array) -> Array:
	var out := [hk[0], hv[0]]
	var last := hk.size() - 1
	hk[0] = hk[last]; hv[0] = hv[last]
	hk.resize(last); hv.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1; var r := l + 1; var m := i
		if l < last and hk[l] < hk[m]: m = l
		if r < last and hk[r] < hk[m]: m = r
		if m == i: break
		var tk := hk[m]; hk[m] = hk[i]; hk[i] = tk
		var tv := hv[m]; hv[m] = hv[i]; hv[i] = tv
		i = m
	return out

func path_ids(dj: Dictionary, dst: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if dst < 0 or is_inf(float(dj.dist[dst])): return out
	var u := dst
	while u >= 0:
		out.append(u); u = int(dj.prev[u])
	out.reverse()
	return out

# 거점까지 가장 가까운 어귀: {gi, d, gate} (닿지 못하면 gi −1)
func node_goal(dj: Dictionary, n: Dictionary) -> Dictionary:
	var best := { gi = -1, d = INF, gate = {} }
	for g in n.get("gates", []):
		var gi := int(g.gi)
		if gi < 0 or gi >= pts.size(): continue
		var d: float = dj.dist[gi]
		if d < best.d: best = { gi = gi, d = d, gate = g }
	return best

func degree(i: int) -> int: return (nb[i] as PackedInt32Array).size()

# ---- 구역 ----
static func in_zone(z: Dictionary, p: Vector2, grow := 0.0) -> bool:
	match String(z.get("kind", "")):
		"circle":
			return p.distance_to(Vector2(float(z.c[0]), float(z.c[1]))) <= float(z.r) + grow
		"rect":
			var r: Array = z.rect
			return p.x >= float(r[0]) - grow and p.x <= float(r[2]) + grow and p.y >= float(r[1]) - grow and p.y <= float(r[3]) + grow
		"poly":
			if not z.has("_poly"):
				var pp := PackedVector2Array()
				for q in z.pts: pp.append(Vector2(float(q[0]), float(q[1])))
				z["_poly"] = pp
			return Geometry2D.is_point_in_polygon(p, z._poly)
	return false

# 이 자리를 덮는 거점(가장 작은 구역부터 — 마을 > 도시)
func node_at(p: Vector2, kinds := []) -> Dictionary:
	var best := {}; var ba := INF
	for n in nodes:
		if not kinds.is_empty() and not kinds.has(String(n.kind)): continue
		var z: Dictionary = n.get("zone", {})
		if not in_zone(z, p): continue
		var area := 1.0
		match String(z.get("kind", "")):
			"circle": area = float(z.r) * float(z.r)
			"rect": area = absf((float(z.rect[2]) - float(z.rect[0])) * (float(z.rect[3]) - float(z.rect[1])))
			_: area = 1e9
		if area < ba: ba = area; best = n
	return best
