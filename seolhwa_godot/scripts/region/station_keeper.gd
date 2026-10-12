# 역참 마부·길목 깃발 대화 — 역마 이동의 입구.
#   마부(역참 그림 station_life의 마부, 모든 역 region_data/stations.json): 곁(REACH m)에서 E → "어디로 가시오? 지도에서 짚어 주시오." →
#     지도가 '갈 곳 고르기'로 열린다(region_map.open_pick — 2026-10-13: 글 목록 대신 지도. 사용자 "텍스트로 정하는 건 유저가 알 턱이 있나").
#     · 금빛 테: 가 본 역·깃발(역마 창 fast_travel._gather 목록 그대로 — 처음 가는 길·남원 첫 사건 막음도 같은 규칙)
#     · 바랜 기호: 못 가는 곳(아는 고을의 안 가 본 역·깃발 · 처음 가는 길 · 첫 사건) — 손을 대거나 고르면 까닭, 확인되지 않는다
#     · 지도 안 R(단추): '말만 빌리겠소 — 큰길 따라' — 말 타고 갈 쪽('말' 패)을 같은 지도에서 고른다(그 자리에서 말을 탈 수 있을 때만)
#     · Esc·M: 그만(말도 역마도 오지 않는다)
#     고른 뒤에야 말이 온다(역마: 마부가 말을 끌고 와 곁에 선 뒤 역마 창 · 말 빌리기: 마부가 말을 끌고 나와 태움). 말하는 동안 마부는 일손을 멈춘다.
#   깃발(scripts/region/waymarks.gd): 곁에서 E → 같은 지도 고르기(말 빌리기 없음 — 깃발에는 말이 없다), 고르면 바로 역마.
#   남원 v3.2 첫 방문 마부 안내(namwon_case.station_intro)는 끝에서 menu()로 이어진다.
#   지도가 없을 때(지도 그림 없는 시험 장면)만 menu_text(예전 글 목록)를 쓴다 — 고르는 길로 쓰지 않는다.
# story_director가 쥐고 target(pp)을 고를 때 이야기 인물 다음으로 고을 사람·마부·깃발 가운데 가장 가까운 것을 고른다(넓은 구역 E 없음).
extends RefCounted

const Stations := preload("res://scripts/region/stations.gd")
const Waymarks := preload("res://scripts/region/waymarks.gd")

const REACH := 2.4          # 마부에게 E 닿는 거리 — 이야기 인물(2.2)·고을 사람(1.9)과 같은 결

var d                       # story_director
var busy := false
var last := {}              # 시험: { from, labels, picked, action }
var log_lines := true
var auto_pick: Callable = Callable()   # 시험: (region_map) — 지도 고르기를 대신 몬다(없고 d.ui.auto면 바로 그만)

func _init(director) -> void:
	d = director

func _hr():
	return d.main.get("horse_ride")

# ---- 대상 ----
func target(pp: Vector2) -> Variant:
	if busy: return null
	var hr = _hr()
	if hr == null or hr.busy() or d.main.world.indoor != null: return null
	var best = null; var bd := INF
	if hr.life != null and hr.life.enabled():
		var k: Dictionary = hr.life.keeper_near(pp, REACH)
		if not k.is_empty():
			bd = pp.distance_to(k.p)
			best = { id = "keeper:" + String(k.st.id), kind = "keeper", st = k.st, p = k.p, r = REACH, label = "마부 · 말 걸기" }
	if hr.get("flags") != null and hr.flags.enabled():
		var f: Dictionary = hr.flags.near(pp, REACH)
		if not f.is_empty() and pp.distance_to(f.p) < bd:
			best = { id = "flag:" + String(f.id), kind = "flag", flag = f, p = f.p, r = REACH, label = "%s 깃발 · 역마" % String(f.name) }
	return best

# ---- E ----
func talk(t: Dictionary) -> void:
	if busy: return
	if String(t.kind) == "flag": await talk_flag(t.flag)
	else: await talk_keeper(t.st)

func talk_keeper(st: Dictionary) -> void:
	if load("res://scripts/region/fast_travel.gd").refuse(d.main, "keeper"): return   # 이야기가 먼 길을 막았다(남원 밤)
	busy = true
	var hr = _hr()
	var life = hr.life
	life.hold(st, d.main.player_pos)
	var gp: Vector3 = life.groom_pos(st)
	if gp != Vector3.INF: d.face_actor("player", null, Vector2(gp.x, gp.z))
	d.ui.prompt(""); d._target = null
	if d.onboard != null: d.onboard.on_interact("actor")
	print("KEEPER talk %s" % st.id)
	await d.ui.say("마부", ["어디로 가시오? 지도에서 짚어 주시오."])
	var a: Dictionary = await menu({ kind = "keeper", st = st })
	life.unhold(st)
	busy = false
	await act(a)

func talk_flag(f: Dictionary) -> void:
	if load("res://scripts/region/fast_travel.gd").refuse(d.main, "flag"): return
	busy = true
	d.ui.prompt(""); d._target = null
	d.face_actor("player", null, f.p)
	print("KEEPER flag %s" % f.id)
	var a: Dictionary = await menu({ kind = "flag", flag = f })
	busy = false
	await act(a)

# ---- 갈 곳(지도에서 고른다 — region_map.open_pick) ----
# 역마로 갈 곳: 역마 창 목록(_gather) 가운데 역·깃발 — 같은 막힘 규칙(처음 가는 길 · 남원 첫 사건).
#   반환 [갈 곳들, 역·깃발이 아닌 가 본 거점 수]. 갈 곳 = { label, name, kind, ok, disabled, hint, why, same, space, space_name, node, station_id,
#   c(이 공간 좌표 — 같은 공간일 때), ll(경위도), km, hours, route(확인 상자 둘째 줄) }
func destinations() -> Array:
	var FT = load("res://scripts/region/fast_travel.gd")
	var ft = FT.new(d.main)
	ft._gather()
	var out := []
	var rest := 0
	for it in ft.items:
		if not (bool(it.get("station", false)) or bool(it.get("flag", false))):
			if bool(it.ok): rest += 1
			continue
		var what := "역마" if bool(it.station) else "깃발"
		var lab := "%s — %s" % [what, String(it.name)]
		if not bool(it.same): lab += " (%s)" % String(it.space_name)
		var o := { label = lab, name = String(it.name), kind = "station" if bool(it.station) else "flag", ok = bool(it.ok), disabled = not bool(it.ok),
			hint = String(it.why), why = String(it.why), same = bool(it.same), space = String(it.space), space_name = String(it.space_name),
			node = String(it.id), station_id = String(it.get("station_id", "")), c = it.at if bool(it.same) else null, ll = FT._ll(String(it.space), it.at), route = "" }
		if bool(it.ok):
			var km := 0.0
			if bool(it.same): km = ft._road_km(it)
			elif ft.here_ll != null and o.ll != null: km = FT._geo_km(ft.here_ll, o.ll) * 1.25
			var hours := clampf(km / FT.HORSE_KMH, 0.3, 60.0)
			o.km = km; o.hours = hours
			var li := int(round(km / 0.42))   # 10리 ≈ 4.2km
			if bool(it.same): o.route = "큰길로 약 %d리 · %s 걸린다" % [li, FT._dur_text(hours)]
			else:
				var via: Array = (it.get("via", []) as Array).map(func(x): return ft._space_name(String(x)))
				o.route = "%s 지나 · 약 %d리 · %s 걸린다" % [" → ".join(PackedStringArray(via)), li, FT._dur_text(hours)]
		out.append(o)
	ft.free()
	return [out, rest]

# 말 빌려 갈 쪽(마부만): horse_ride.station_ride_choices → 지도 위 '말' 패
func ride_dests(st: Dictionary) -> Array:
	var hr = _hr()
	var rc: Array = hr.station_ride_choices(st) if hr != null else []
	var out := []
	for c in rc:
		var n: Dictionary = c.node
		var a: Array = n.get("arrive", [n.x, n.z])
		out.append({ label = "말 — %s 쪽으로" % String(c.name), name = String(c.name), kind = "ride", ok = true, why = "", same = true,
			c = Vector2(float(a[0]), float(a[1])), ll = null, mins = int(c.mins), choice = c })
	return out

func _map():
	var m = d.main.get("_map")
	return m if m != null and is_instance_valid(m) and not m._meta.is_empty() else null

# 지도에서 고른다. 지도가 없을 때(시험 장면 등)만 예전 글 목록(menu_text — 안쪽 대비책)
func menu(from: Dictionary) -> Dictionary:
	var mp = _map()
	if mp == null: return await menu_text(from)
	var dl: Array = destinations()
	var rides: Array = ride_dests(from.st) if String(from.kind) == "keeper" else []
	last = { from = String(from.kind), labels = (dl[0] as Array).map(func(o): return String(o.label)), picked = "", action = {}, map = true,
		rides = rides.map(func(o): return String(o.label)) }
	if log_lines: print("KEEPER map %s %s rides=%d" % [from.kind, last.labels, rides.size()])
	mp.open_pick({ from = String(from.kind), dests = dl[0], rides = rides })
	if auto_pick.is_valid(): auto_pick.call_deferred(mp)
	elif d.ui.auto: mp.pick_cancel.call_deferred()   # 시험 자동 진행(고르는 시험이 아니면 그만)
	var res: Dictionary = await mp.pick_done
	var a := { act = String(res.get("act", "end")), from = from }
	var o: Dictionary = res.get("dest", {})
	last.picked = String(o.get("label", ""))
	match a.act:
		"warp":
			a.space = o.space; a.node = o.node; a.station_id = o.station_id
			if String(from.kind) == "keeper": await d.ui.say("마부", ["말을 내 오리다."])
		"ride":
			a.choice = o.choice
	last.action = a
	print("KEEPER pick %s → %s" % [last.picked, a.act])
	return a

# 안쪽 대비책: 지도가 없을 때만 쓰는 글 목록(예전 흐름)
func menu_text(from: Dictionary) -> Dictionary:
	var dl: Array = destinations()
	var opts: Array = []
	for o in dl[0]: opts.append(o.merged({ act = "warp" }))
	var rides: Array = ride_dests(from.st) if String(from.kind) == "keeper" else []
	for r in rides: opts.append(r.merged({ act = "ride" }))
	opts.append({ label = "그만두겠소.", act = "end" })
	last = { from = String(from.kind), labels = opts.map(func(o): return String(o.label)), picked = "", action = {}, map = false }
	var i: int = await d.ui.choice("어디로 가겠소?", opts)
	var o: Dictionary = opts[i] if i >= 0 and i < opts.size() else { act = "end" }
	last.picked = String(o.get("label", ""))
	var a := { act = String(o.act), from = from }
	if a.act == "warp": a.space = o.space; a.node = o.node; a.station_id = o.station_id
	elif a.act == "ride": a.choice = o.choice
	last.action = a
	return a

# ---- 고른 뒤에야 말이 온다 ----
func act(a: Dictionary) -> void:
	var hr = _hr()
	var from: Dictionary = a.get("from", {})
	match String(a.get("act", "end")):
		"warp":
			if String(from.get("kind", "")) == "keeper" and hr.life != null:
				var st: Dictionary = from.st
				var sec: float = hr.life.bring(st, d.main.player_pos)
				var t_end := Time.get_ticks_msec() + int((sec + 0.3) * 1000.0)   # 말을 끌어 오는 동안도 Space로 건너뛴다
				while sec > 0.0 and Time.get_ticks_msec() < t_end and not Input.is_action_just_pressed("boat_skip"):
					await d.get_tree().process_frame
				var r: Dictionary = Stations.warp_node(String(a.space), String(a.node))
				if not bool(r.ok):
					hr.life.bring_end(st); d.ui.toast("역마 — " + String(r.why)); return
				# 역마 창이 닫힐 때(같은 공간 도착 · 막힘) 말을 다시 매어 둔다(다른 공간이면 장면이 바뀐다)
				while d.main.fast_ui != null and is_instance_valid(d.main.fast_ui):
					await d.get_tree().process_frame
				if is_instance_valid(hr.life.main): hr.life.bring_end(st)
			else:
				var r2: Dictionary = Stations.warp_node(String(a.space), String(a.node))
				if not bool(r2.ok): d.ui.toast("역마 — " + String(r2.why))
		"ride":
			var st2: Dictionary = from.st
			var y: Array = st2.yard
			var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
			if pp.distance_to(Vector2(float(y[0]), float(y[1]))) > 5.0:
				# 마방 안쪽에서 말을 걸었으면 문 앞 길로 나간다(짧은 암전)
				await d.ui.fade(true, 0.25)
				d.main.teleport(float(y[0]), float(y[1]))
				await d.ui.fade(false, 0.25)
			hr.begin_ride(a.choice, st2)

