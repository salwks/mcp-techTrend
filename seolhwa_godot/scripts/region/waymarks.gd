# 길목 깃발 — 마을 어귀·노정 중간·쉼터(주막·고개)에 선 깃대(kit/station/waymark.gd). 길잡이(웨이포인트)이자 역마 타는 자리.
#   자리: 새 좌표를 만들지 않는다 — 역마 거점 데이터(region_data/travel/<공간>.json nodes, tools/region/make_travel_gates.py)의
#     빠른 이동 거점(fast) 가운데 FLAG_KINDS(읍치·장·마을·거점 고을·바닷가 마을·주막·고개)의 도착 자리(arrive)를 쓰고,
#     큰길 옆(길 중심선에서 SIDE m)으로 비켜 세운다. 역(STATION — 역참 마부가 있음)·노정 끝(포털)·나루·배·절·굴은 깃발이 없다.
#   알기: 깃발 거점은 역마 거점과 같은 '가 봄'(progress.json travel_nodes — horse_ride._discover가 거점 구역·도착 자리 30m 안에서 적는다).
#     처음 알면 알림 띠 '깃발 — ○○'과 지도 표지(region_map). 저장·이어 하기는 travel_nodes 그대로.
#   E: 깃발 곁(REACH m) — story_director가 이야기 인물·고을 사람·역참 마부와 같은 '가장 가까운 대상' 규칙으로 고른다(scripts/region/station_keeper.gd 대화).
#   그림: 플레이어 NEAR m 안 깃발만 만들고 FAR m 밖이면 지운다. 모르는 깃발은 바랜 무명빛, 알면 쪽빛. 충돌체는 없다(결정 6 — 지나갈 수 있다).
#   강·바닷길 노정(route_kind river·sea)에는 깃발을 세우지 않는다(결정 5) — 그 거점은 역마 창·지도·배로 그대로 간다.
# horse_ride가 만든다: setup(main, net) · update(dt) · near(pp, r) · stats
extends RefCounted

const Waymark := preload("res://kit/station/waymark.gd")
const RideNet := preload("res://scripts/region/ride_net.gd")

const FLAG_KINDS := ["CITY", "MARKET", "VILLAGE", "HUB", "COAST", "INN", "PASS"]
const NEAR := 160.0
const FAR := 220.0
const SIDE := 4.0           # 큰길 중심선에서 비켜 서는 거리(m)
const REACH := 2.4          # E 닿는 거리(이야기 인물 2.2 · 고을 사람 1.9와 비슷하게 — 가장 가까운 대상이 이긴다)

var main
var world
var net
var space := ""
var list: Array = []        # [{id, name, kind, space, p: Vector2, node}]
var live := {}              # id → {nd: Node3D, known}
var root: Node3D
var _chk := 0.0
var stats := { spawned = 0 }

# 노정 종류(ROUTE_PROFILE.kind — 제작 규칙 v1.0 C-4): "land" · "river" · "sea". 권역(노정 아님)은 "".
#   ROUTE_PROFILE 파일이 아직 없어 기존 데이터에서 끌어낸다(출처 순서):
#   1 region_data/travel/<공간>.json의 kind가 "route"가 아니면 권역 → ""
#   2 노정 route.json의 route_type(한강·대동강 "river") — 있으면 그 값
#   3 공간 id 접두사 RIVER_ → river, SEA_ → sea (SEA_NAMHAE_JEJU는 route_type이 없다)
#   4 그 밖의 노정 → land
static var _kinds := {}
static func route_kind(sp: String) -> String:
	if _kinds.has(sp): return _kinds[sp]
	var k := ""
	if String(RideNet.read(sp).get("kind", "")) == "route" or sp.begins_with("RIVER_") or sp.begins_with("SEA_"):
		k = "land"
		for r in load("res://scripts/region/travel.gd").routes():
			if String(r.id) == sp:
				var rt := String(r.json.get("route_type", ""))
				if rt in ["river", "sea"]: k = rt
				break
		if k == "land":
			if sp.begins_with("RIVER_"): k = "river"
			elif sp.begins_with("SEA_"): k = "sea"
	_kinds[sp] = k
	return k

# 이 공간에 길목 깃발을 세우나(결정 5): 권역과 land 노정만. river·sea 노정은 깃발(물리 깃대와 깃발 E)이 없다 — 거점의 fast·가 봄은 그대로
static func space_has_flags(sp: String) -> bool:
	return not (route_kind(sp) in ["river", "sea"])

# 깃발 거점인가(지도·대화·시험도 쓴다). sp: 그 거점이 있는 공간 — river·sea 노정이면 false
static func is_flag(n: Dictionary, sp := "") -> bool:
	if sp != "" and not space_has_flags(sp): return false
	return bool(n.get("fast", false)) and String(n.get("kind", "")) in FLAG_KINDS and String(n.get("station", "")) == ""

# 공간의 깃발 거점(데이터만 — 자리는 도착 자리 그대로). 지도·대화용
static func flags_in(sp: String) -> Array:
	var out := []
	for n in RideNet.read(sp).get("nodes", []):
		if is_flag(n, sp):
			out.append({ id = String(n.id), name = String(n.name), kind = String(n.kind), space = sp, p = anchor_of(n) })
	return out

# 깃발 기준 자리: 도착 자리(arrive — 역마로 닿는 곳, 읍성은 성문 어귀). 세울 때 담·문루를 비켜 빈 자리로(_spawn)
static func anchor_of(n: Dictionary) -> Vector2:
	var a: Array = n.get("arrive", [n.x, n.z])
	return Vector2(float(a[0]), float(a[1]))

func setup(m, rn) -> void:
	main = m; world = m.world; net = rn
	space = String(world.region.get("route_id", world.region.get("region_id", "")))
	if net == null: return
	for n in net.nodes:
		if not is_flag(n, space): continue
		var av := anchor_of(n)
		list.append({ id = String(n.id), name = String(n.name), kind = String(n.kind), space = space, p = _sides(av)[0], arrive = av })
	if list.is_empty(): return
	root = Node3D.new(); root.name = "waymarks"
	main.scene_vp.add_child(root)
	print("WAYMARK space=%s flags=%d" % [space, list.size()])

func enabled() -> bool: return root != null

# 도착 자리 곁 큰길 옆 두 자리: 가장 가까운 길 점의 방향에 직각으로 ±SIDE m — 다른 길에서 먼 쪽을 앞에
func _sides(a: Vector2) -> Array:
	var gi: int = net.nearest(a, 30.0, true)
	if gi < 0: return [a + Vector2(SIDE, 0), a - Vector2(SIDE, 0)]
	var q: Vector2 = net.pts[gi]
	var dir := Vector2.RIGHT
	var nbs: PackedInt32Array = net.nb[gi]
	if nbs.size() > 0: dir = (net.pts[nbs[0]] - q).normalized()
	if dir.length() < 0.1: dir = Vector2.RIGHT
	var side := Vector2(-dir.y, dir.x)
	var c1: Vector2 = a + side * SIDE; var c2: Vector2 = a - side * SIDE
	return [c1, c2] if net.road_dist(c1, 30.0) >= net.road_dist(c2, 30.0) else [c2, c1]

static func known(sp: String, id: String) -> bool:
	return load("res://scripts/region/horse_ride.gd").is_discovered(sp, id)

func by_id(id: String) -> Dictionary:
	for f in list:
		if String(f.id) == id: return f
	return {}

# 이 자리에서 E 닿는 가장 가까운 깃발({}이면 없음)
func near(pp: Vector2, r := REACH) -> Dictionary:
	var best := {}; var bd := r
	for f in list:
		var d := pp.distance_to(f.p)
		if d < bd: bd = d; best = f
	return best

func update(dt: float) -> void:
	if not enabled(): return
	_chk -= dt
	if _chk > 0.0: return
	_chk = 0.5
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	for f in list:
		var d := pp.distance_to(f.p)
		var L = live.get(f.id)
		if d < NEAR and not main._loading:
			var k := known(space, String(f.id))
			if L == null or bool(L.known) != k:
				if L != null: L.nd.queue_free()
				_spawn(f, k)
		elif d > FAR and L != null:
			L.nd.queue_free(); live.erase(f.id)

func _spawn(f: Dictionary, k: bool) -> void:
	if not bool(f.get("settled", false)) and main.has_method("_nearest_free"):
		# 처음 세울 때(그 둘레 건물 충돌이 올라온 뒤) 담·집 안에 들지 않게: 양쪽 길가 가운데 덜 밀리는 쪽
		var a: Vector2 = f.arrive
		var best: Vector2 = f.p; var bm := INF
		for c in _sides(a):
			var q: Vector2 = main._nearest_free(c.x, c.y, 0.6)
			var mv := q.distance_to(c)
			if mv < bm: bm = mv; best = q
		f.p = best
		f.settled = true
	var nd := Waymark.node({ seed = hash(String(f.id)) & 0xffff, known = k })
	nd.name = "flag_" + String(f.id)
	var p: Vector2 = f.p
	nd.position = Vector3(p.x, world.height_at(p.x, p.y), p.y)
	root.add_child(nd)
	live[f.id] = { nd = nd, known = k }
	stats.spawned = int(stats.spawned) + 1
