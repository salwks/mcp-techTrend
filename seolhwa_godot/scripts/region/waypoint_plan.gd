# 지도 목적지 계획(재기획 4단계 — 지도 v1.3 §05·§06·§08, 결정 D4·역마): 지도에서 짚은 곳 하나를 두고
#   ① 지도 표시(늘 — 아는 곳·모르는 빈 곳 모두 핀) ② 걷기([목적지 설정] — 늘 됨, 플레이어가 직접 걷는다)
#   ③ 역마 자동 이동([말로 이동] — horse_ride.pin_plan: 큰길·말 타는 곳·이야기 막음) ④ 빠른 이동([빠른 이동] — 가 본 역참·깃발만, 역마 창 막힘 규칙 그대로)
#   을 따로 판정한다. 넷은 서로의 조건을 빌리지 않는다(D4).
# 목적지 사전 t = { kind: lead|place|station|flag|region|point, space, c: Vector2(그 공간 좌표), name, key, node?(역마 거점 id), station_id? }
# 다른 공간 목적지: ride_net은 공간 하나 안에서만 길을 찾는다 — 그래서 이 공간에서는 그쪽으로 이어진 노정의 길 끝(ROUTE_END)까지 말로 가고,
#   포털을 걸어서 넘은 뒤 다음 공간에서 다시 그쪽 길 끝으로 잇는다(next_hop). 이동 체계는 바꾸지 않는다.
extends RefCounted

const RideNet := preload("res://scripts/region/ride_net.gd")
const Stations := preload("res://scripts/region/stations.gd")
const Waymarks := preload("res://scripts/region/waymarks.gd")
const Travel := preload("res://scripts/region/travel.gd")
const FAST_NEAR := 220.0    # 짚은 곳에서 이만큼 안의 역참·깃발로 빠른 이동(그 지점 직접 빠른 이동은 없다 — 지도 v1.3 §06)

static var _adj = null

static func here_of(m) -> String:
	return String(m.world.region.get("route_id", m.world.region.get("region_id", "")))

# 공간 이웃: 길 데이터의 노정 길 끝(ROUTE_END.target) — 권역 ↔ 노정 ↔ 권역
static func space_adj() -> Dictionary:
	if _adj != null: return _adj
	_adj = {}
	for sp in RideNet.all_spaces():
		for n in RideNet.read(sp).get("nodes", []):
			if String(n.get("kind", "")) != "ROUTE_END": continue
			var t := String(n.get("target", ""))
			if t == "": continue
			if not _adj.has(sp): _adj[sp] = []
			if not _adj.has(t): _adj[t] = []
			if not (_adj[sp] as Array).has(t): _adj[sp].append(t)
			if not (_adj[t] as Array).has(sp): _adj[t].append(sp)
	return _adj

# from → to 공간 길에서 다음으로 들어설 공간("" = 길을 모름 · 같은 공간이면 to)
static func next_hop(from: String, to: String) -> String:
	if from == to: return to
	var adj := space_adj()
	var prev := { from: "" }
	var q := [from]
	while not q.is_empty():
		var u: String = q.pop_front()
		for w in adj.get(u, []):
			if prev.has(w): continue
			prev[w] = u
			if w == to:
				var cur: String = w
				while String(prev[cur]) != from: cur = String(prev[cur])
				return cur
			q.append(w)
	return ""

# 이 공간에서 다른 공간 목적지 쪽으로 나가는 길 끝 {id, name, p(도착 자리), next}. 없으면 {}
static func exit_for(here: String, target_space: String) -> Dictionary:
	var nxt := next_hop(here, target_space)
	if nxt == "" or nxt == here: return {}
	for n in RideNet.read(here).get("nodes", []):
		if String(n.get("kind", "")) == "ROUTE_END" and String(n.get("target", "")) == nxt:
			var a: Array = n.get("arrive", [n.x, n.z])
			return { id = String(n.id), name = String(n.name), p = Vector2(float(a[0]), float(a[1])), next = nxt }
	return {}

# 전국 지도에서 짚은 권역 → 그 권역의 대표 거점(읍치 CITY, 없으면 첫 역마 거점) 자리
static func region_target(sp: String, nm: String) -> Dictionary:
	var best = null
	for n in RideNet.read(sp).get("nodes", []):
		if not bool(n.get("fast", false)): continue
		if best == null or (String(n.kind) == "CITY" and String(best.kind) != "CITY"): best = n
	if best == null: return { kind = "region", space = sp, c = null, name = nm, key = "region:" + sp }
	var a: Array = best.get("arrive", [best.x, best.z])
	return { kind = "region", space = sp, c = Vector2(float(a[0]), float(a[1])), name = nm, key = "region:" + sp, node = String(best.id) }

# 빠른 이동: 목적지에 붙은 역참·길목 깃발(노드를 알면 그것, 아니면 FAST_NEAR 안 가장 가까운 것)이 역마 창 목록(fast_travel._gather — 가 봄·처음 가는 길·고을 막음)에서 ok일 때만
static func fast_opt(m, t: Dictionary) -> Dictionary:
	var kind := String(t.get("kind", "point"))
	if kind == "point": return { ok = false, why = "빈 곳으로는 빠른 이동이 없다 — 가 본 역참·길목 깃발로만 간다" }
	var sp := String(t.get("space", here_of(m)))
	var hit := {}
	var want := String(t.get("node", ""))
	var c = t.get("c")
	var bd := FAST_NEAR
	for n in RideNet.read(sp).get("nodes", []):
		if not bool(n.get("fast", false)): continue
		var is_st := not Stations.for_node(sp, String(n.id)).is_empty()
		if not is_st and not Waymarks.is_flag(n, sp): continue
		if want != "" and String(n.id) == want: hit = n; break
		if c is Vector2:
			var a: Array = n.get("arrive", [n.x, n.z])
			var d := (c as Vector2).distance_to(Vector2(float(a[0]), float(a[1])))
			if d < bd: bd = d; hit = n
	if hit.is_empty(): return { ok = false, why = "이곳 가까이에는 역참·길목 깃발이 없다 — 빠른 이동은 가 본 역·깃발로만 간다" }
	var out := { ok = false, why = "", space = sp, node = String(hit.id), name = String(hit.get("name", hit.id)) }
	var FT: Script = load("res://scripts/region/fast_travel.gd")
	var ft = FT.new(m)
	ft._gather()
	var found = null
	for it in ft.items:
		if String(it.space) == sp and String(it.id) == String(hit.id): found = it
	ft.free()
	if found == null:
		var a2: Array = hit.get("arrive", [hit.x, hit.z])
		var pp := Vector2(m.player_pos.x, m.player_pos.z)
		if sp == here_of(m) and pp.distance_to(Vector2(float(a2[0]), float(a2[1]))) < 80.0: out.why = "이미 이곳에 있다"
		else: out.why = "아직 가 보지 않은 곳이다 — 한 번 걸어서(말 타고) 가 봐야 빠른 이동이 열린다"
	elif not bool(found.ok): out.why = String(found.why)
	else: out.ok = true
	return out

# 거리 글: 미터 → "약 3.2km" · "약 450m"
static func dist_text(d: float) -> String:
	if d >= 1000.0: return "약 %.1fkm" % (d / 1000.0)
	return "약 %dm" % int(round(d / 10.0) * 10.0)
