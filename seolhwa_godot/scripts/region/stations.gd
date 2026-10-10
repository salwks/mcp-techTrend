# 역참·마방 — 데이터(region_data/stations.json, tools/region/make_stations.py)와 역마 이동 API.
#   Travel.stations() / Travel.station_known(id) / Travel.station_state(id) / Travel.warp_to_station(id) 가 여기로 온다(travel.gd).
#   - 역은 역마 거점(region_data/travel/<공간>.json 노드 st.node — kind STATION 또는 이미 있는 역 거점). 가 보면(거점 구역·도착 자리 30m 안)
#     progress.json travel_nodes[공간][노드]에 적힌다(horse_ride._discover) — st.discover_key = "travel_nodes/<공간>/<노드>".
#   - 역마 이동(warp): 가 본 역으로. 역마 창(fast_travel.gd)을 그 역을 고른 채 열어 바로 간다 — 지도 위 길이 그려지고 시각이 흐른 뒤 암전,
#     그 역 마방 문 앞(yard — 안장 얹은 말이 가로대에 매여 기다린다)에 선다. 처음 가는 길(안 지난 노정 너머 — 제주 첫 뱃길 포함)은 막힌다.
#   - main(region_main)은 horse_ride.setup이 register()로 알려 준다(장면을 다시 열 때마다).
extends RefCounted

const PATH := "res://region_data/stations.json"
const ARRIVE_META := "seolhwa_station_arrive"   # 다른 공간 역으로 넘어갈 때: 새 장면에서 마방 문 앞에 세운다 {space, node, id, yard}

static var _list = null
static var main = null

static func register(m) -> void:
	main = m

static func all() -> Array:
	if _list != null: return _list
	_list = []
	if FileAccess.file_exists(PATH):
		var j = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if j is Dictionary and j.get("stations") is Array: _list = j.stations
	return _list

static func by_id(id: String) -> Dictionary:
	for s in all():
		if String(s.id) == id: return s
	return {}

static func in_space(space: String) -> Array:
	return all().filter(func(s): return String(s.space) == space)

# 공간·노드 → 역(없으면 {})
static func for_node(space: String, node: String) -> Dictionary:
	for s in all():
		if String(s.space) == space and String(s.node) == node: return s
	return {}

static func known(id: String) -> bool:
	var s := by_id(id)
	if s.is_empty(): return false
	var tn = _progress().data().get("travel_nodes", {})
	return tn is Dictionary and tn.get(String(s.space)) is Dictionary and (tn[String(s.space)] as Dictionary).has(String(s.node))

static func _progress() -> Script:
	return load("res://scripts/region/progress.gd")

# 지도용 목록: stations.json 항목 + discovered(가 봄) + here(지금 공간) + ok/why(지금 자리에서 역마로 갈 수 있나)
static func listing() -> Array:
	var out := []
	var reach = null
	for s in all():
		var d: Dictionary = (s as Dictionary).duplicate()
		d.discovered = known(String(s.id))
		d.known = d.discovered
		var stt := state(String(s.id), reach)
		d.ok = bool(stt.ok); d.why = String(stt.why)
		out.append(d)
	return out

# 지금 자리에서 이 역으로 역마를 탈 수 있나: {ok, why}
static func state(id: String, _reach = null) -> Dictionary:
	var s := by_id(id)
	if s.is_empty(): return { ok = false, why = "없는 역" }
	if not known(id): return { ok = false, why = "아직 가 보지 않은 역이다" }
	if main == null or not is_instance_valid(main) or main.world == null: return { ok = false, why = "지금은 갈 수 없다" }
	var here := String(main.world.region.get("route_id", main.world.region.get("region_id", "")))
	if String(s.space) == here:
		var y: Array = s.yard
		if Vector2(main.player_pos.x, main.player_pos.z).distance_to(Vector2(float(y[0]), float(y[1]))) < 40.0: return { ok = false, why = "이미 이 역에 있다" }
		return { ok = true, why = "" }
	var FT: Script = load("res://scripts/region/fast_travel.gd")
	var reach: Dictionary = FT.reachable_from(main)
	if not reach.has(String(s.space)):
		var gw: String = FT.gate_why(main)
		return { ok = false, why = gw if gw != "" else "처음 가는 길은 걸어서(말 타고) 가 봐야 한다" }
	return { ok = true, why = "" }

# 역마로 그 역에 간다(지도 선택·시험). 반환 {ok, why}. ok면 역마 창이 길을 그리고 시각을 흘린 뒤 도착한다.
static func warp(id: String) -> Dictionary:
	var stt := state(id)
	if not bool(stt.ok):
		if main != null and is_instance_valid(main) and main.has_method("_show_hud"): main._show_hud("역마 — " + String(stt.why))
		print("STATION warp %s 막힘: %s" % [id, stt.why])
		return stt
	var s := by_id(id)
	var r := warp_node(String(s.space), String(s.node))
	if bool(r.ok): print("STATION warp %s → %s/%s" % [id, s.space, s.node])
	return r

# 역마 거점(역·깃발)으로: 역마 창을 그 거점을 고른 채 열어 바로 간다(지도 위 길·시각 흐름·도착 — 역·깃발 모두 같은 연출, 따로 만든 이동 없음).
#   막힘(처음 가는 길·남원 첫 사건)은 역마 창의 목록 규칙(fast_travel._gather)이 그대로 정한다 — 못 가면 창이 닫히고 {ok:false}.
static func warp_node(space: String, node: String) -> Dictionary:
	if main == null or not is_instance_valid(main): return { ok = false, why = "지금은 갈 수 없다" }
	if load("res://scripts/region/fast_travel.gd").refuse(main, "station"): return { ok = false, why = String(load("res://scripts/region/fast_travel.gd").lock_why(main)) }
	if main._loading or main._leaving or (main.horse_ride != null and main.horse_ride.busy()) or main.boats.riding():
		return { ok = false, why = "지금은 갈 수 없다" }
	if main.fast_ui != null and is_instance_valid(main.fast_ui): main.fast_ui.close()
	var FT: Script = load("res://scripts/region/fast_travel.gd")
	var ui = FT.new(main, "")
	ui.test_pick = "%s/%s" % [space, node]
	ui.auto_go = true
	main.fast_ui = ui
	main.add_child(ui)
	print("WARP node → %s/%s" % [space, node])
	return { ok = true, why = "" }

# 다른 공간 역으로 넘어가기 직전(fast_travel._arrive): 새 장면이 마방 문 앞에 세우도록 적어 둔다
static func set_arrival(space: String, node: String) -> void:
	var s := for_node(space, node)
	if s.is_empty(): return
	Engine.set_meta(ARRIVE_META, { space = space, node = node, id = String(s.id), yard = s.yard })

static func take_arrival() -> Dictionary:
	if not Engine.has_meta(ARRIVE_META): return {}
	var d: Dictionary = Engine.get_meta(ARRIVE_META)
	Engine.remove_meta(ARRIVE_META)
	return d

# 공간 좌표 → 이 역의 마방 키트 로컬(Vector2) / 반대
static func to_world(s: Dictionary, local: Vector3) -> Vector3:
	var ry := float(s.get("ry", 0.0))
	var c := Vector2(float(s.pos[0]), float(s.pos[1]))
	return Vector3(c.x + local.x * cos(ry) + local.z * sin(ry), 0.0, c.y - local.x * sin(ry) + local.z * cos(ry))

static func hitch_world(s: Dictionary, local: Vector3) -> Vector3:
	var h: Array = s.get("hitch", s.pos)
	return Vector3(float(h[0]) + local.x, 0.0, float(h[1]) + local.z)

# 글꼴: 공용 덕온공주체(scripts/ui_fonts.gd — 驛 같은 한자는 시스템 명조로 이어 씀)가 있으면 그것, 없으면 시스템 명조
static func font(classic := false) -> Font:
	if ResourceLoader.exists("res://scripts/ui_fonts.gd"):
		var uf: Script = load("res://scripts/ui_fonts.gd")
		var f = uf.classic() if classic else uf.main()
		if f is Font: return f
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["AppleMyungjo", "Nanum Myeongjo", "NanumMyeongjo", "Batang", "Noto Serif CJK KR", "Apple SD Gothic Neo"])
	return sf
