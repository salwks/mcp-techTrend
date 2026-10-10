# 역참 시험(헤드리스, tools/run_story_tests.sh station:*) — horse_ride.setup이 --stationtest를 보고 연다.
#   --stationtest=a,b[,ride_to]   같은 공간 역 a·b에 차례로 가서 '가 봄'으로 적히는지(역 구역에 들어서면 travel_nodes) → 마방의 말·마부가 생겼는지
#                                 → Travel.warp_to_station(a)(지도에서 고른 것과 같은 길: 역마 창이 길을 그리고 시각이 흐름) → a 마방 문 앞 도착
#                                 → (2026-10) 문 앞 넓은 E 없음: 역 문 앞에서 말 안내가 비고 E를 눌러도 말이 오지 않는다
#                                 → E 차례: 마부 곁이라도 더 가까운 고을 사람이 있으면 그 사람과 말하고 말은 오지 않는다
#                                 → 마부 대화: 목록(가 본 역·깃발 · 말을 빌린다 · 그만두겠소)이 뜨는 동안 말·역마 창이 없다 → 고른 뒤에야 말이 온다
#                                 → 길목 깃발: 가까이 가면 '가 봄'·알림 → 깃발 E → 역으로 · 역 마부 E → 깃발로 · 저장 파일에 남음
#                                 → 마부 '말을 빌린다' → ride_to 거점 어귀까지 말로 가서 내림(마부가 가로대의 말을 끌고 나옴)
#                                 + 처음 가는 길 막힘: 제주 역은 가 본 것으로 적어도 남해 뱃길을 안 건넜으면 못 간다 · 남원 첫 사건 전엔 남원 밖으로 못 감
#   --stationtest=cross:<역>      그 역을 가 본 것으로 적고 다른 공간으로 역마 → 새 장면에서 그 역 마방 문 앞에 섰나(Engine 메타로 이어 봄)
# 판정: "STATIONTEST PASS …" / "STATIONTEST FAIL …"
extends RefCounted

const Stations := preload("res://scripts/region/stations.gd")
const Travel := preload("res://scripts/region/travel.gd")
const HorseRide := preload("res://scripts/region/horse_ride.gd")
const Progress := preload("res://scripts/region/progress.gd")
const RideNet := preload("res://scripts/region/ride_net.gd")
const CONT := "seolhwa_stationtest_cont"

var main
var _fails: Array = []

func _init(m) -> void:
	main = m

func _fail(w: String) -> void:
	_fails.append(w)
	print("STATIONTEST check FAIL ", w)

func _wait_load() -> void:
	await main._wait_frames(10)
	var n := 0
	while main._loading and n < 6000:
		await main._wait_frames(1); n += 1
	n = 0
	while (main.world.stats.jobs > 0 or main.placement.busy()) and n < 900:
		await main._wait_frames(1); n += 1

func _yard(s: Dictionary) -> Vector2:
	return Vector2(float(s.yard[0]), float(s.yard[1]))

func _pp() -> Vector2:
	return Vector2(main.player_pos.x, main.player_pos.z)

func _end() -> void:
	Engine.time_scale = 1.0
	if _fails.is_empty(): print("STATIONTEST PASS")
	else: print("STATIONTEST FAIL %s" % " / ".join(_fails))
	main._quit()

func run(spec: String) -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if Engine.has_meta(CONT):
		await _verify_cross(); return
	await _wait_load()
	if spec.begins_with("cross:"):
		await _cross(spec.get_slice(":", 1)); return
	if spec.begins_with("flagshots"):
		await _flagshots(spec.get_slice(":", 1) if spec.contains(":") else ""); return
	var parts := spec.split(",")
	var a := Stations.by_id(parts[0]); var b := Stations.by_id(parts[1])
	var ride_to := parts[2] if parts.size() > 2 else ""
	if a.is_empty() or b.is_empty():
		print("STATIONTEST FAIL 역 없음 %s" % spec); main._quit(); return
	var hr = main.horse_ride
	# 1) 두 역에 들러 '가 봄'
	for s in [a, b]:
		if Stations.known(String(s.id)): _fail("%s 처음부터 가 봄으로 되어 있음" % s.id)
		var y := _yard(s)
		main.teleport(y.x, y.y)
		main.rig.update(0, main.player_pos, main.player.facing, null, true)
		await _wait_load()
		await main._wait_frames(60)
		var known := Stations.known(String(s.id))
		var L = hr.life.live.get(String(s.id))
		var nst: int = L.stalls.size() if L != null else 0
		var npad: int = L.pads.size() if L != null else 0
		var eating := 0
		if L != null:
			for h in L.stalls:
				if String(h.ch.anim) == "eat": eating += 1
		print("STATIONTEST visit %s(%s) known=%s stalls=%d eating=%d pads=%d wait=%s groom=%s task=%s" % [s.id, s.name, known, nst, eating, npad,
			L != null and L.has("wait"), L.groom.ch.kind if L != null else "", L.groom.task if L != null else ""])
		if not known: _fail("%s 들렀는데 가 봄이 아님" % s.id)
		if L == null or nst < 3 or npad < 1 or not L.has("wait"): _fail("%s 마방에 말·마부가 없음" % s.id)
	# 2) 지도 API로 역마: 지금(b) → a
	var listing: Array = Travel.stations()
	var la = listing.filter(func(x): return String(x.id) == String(a.id))
	print("STATIONTEST listing n=%d %s discovered=%s ok=%s" % [listing.size(), a.id, la[0].discovered if not la.is_empty() else "?", la[0].ok if not la.is_empty() else "?"])
	if la.is_empty() or not bool(la[0].discovered) or not bool(la[0].ok): _fail("목록에서 %s 갈 수 없음" % a.id)
	var h0: float = main.hour
	var r: Dictionary = Travel.warp_to_station(String(a.id))
	if not bool(r.ok): _fail("warp_to_station 거절 %s" % r.why)
	var t0 := Time.get_ticks_msec()
	await main._wait_frames(5)
	while main.fast_ui != null and is_instance_valid(main.fast_ui) and Time.get_ticks_msec() - t0 < 20000:
		await main._wait_frames(1)
	await _wait_load()
	await main._wait_frames(30)
	var d := _pp().distance_to(_yard(a))
	print("STATIONTEST warp %s → %s d=%.1fm hour %.1f → %.1f" % [b.id, a.id, d, h0, main.hour])
	if d > 4.0: _fail("역마 도착이 마방 문 앞이 아님 %.1fm" % d)
	if is_equal_approx(h0, main.hour): _fail("시각이 흐르지 않음")
	var L2 = hr.life.live.get(String(a.id))
	if L2 == null or not L2.has("wait"): _fail("도착한 역에 기다리는 말이 없음")
	else:
		var wd := Vector2(L2.wait.position.x, L2.wait.position.z).distance_to(_pp())
		print("STATIONTEST waiting horse %.1fm" % wd)
		if wd > 9.0: _fail("기다리는 말이 멀다 %.1fm" % wd)
	# 3) 처음 가는 길: 제주 역은 가 본 것으로 적어도 막힘(남해 뱃길 안 건넘)
	var jj := Stations.by_id("jeju")
	if not jj.is_empty() and not Progress.route_done("SEA_NAMHAE_JEJU"):
		HorseRide.discover(String(jj.space), String(jj.node))
		var js := Stations.state("jeju")
		print("STATIONTEST jeju state ok=%s why=%s" % [js.ok, js.why])
		if bool(js.ok): _fail("제주 첫 뱃길 전에 제주 역으로 갈 수 있음")
		var rj := Travel.warp_to_station("jeju")
		if bool(rj.ok): _fail("제주 역 warp가 열림")
	# 3b) 남원 첫 사건 막음(가짜 main — 남원, 첫 사건 안 끝남): 남원 밖으로 역마·깃발 못 감
	await _first_case_gate()
	# 4) 문 앞 넓은 E 없음 · E 차례 · 마부 대화 · 깃발
	await _no_area_e(hr, a)
	await _npc_wins(hr, a)
	await _keeper_menu_warp(hr, a, b)
	await _flags(hr, a)
	# 5) 마부 '말을 빌린다' — 마부가 끌어 옴 → ride_to까지
	if ride_to != "":
		await _go_station(a)
		await _ride(hr, a, ride_to)
	_end()

# ---- 공용 ----
func _d():
	return main.story

func _go_station(s: Dictionary) -> void:
	var y := _yard(s)
	main.teleport(y.x, y.y)
	main.rig.update(0, main.player_pos, main.player.facing, null, true)
	await _wait_load()
	await main._wait_frames(30)

func _key_e() -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E; ev.keycode = KEY_E; ev.pressed = down
		Input.parse_input_event(ev)
		await main._wait_frames(2)

# 마부를 세워 두고 그 곁(dist m)에 선다 — 반환 마부 자리
func _stand_by_groom(hr, s: Dictionary, dist: float) -> Vector2:
	var L = hr.life.live.get(String(s.id))
	if L == null: return Vector2.INF
	hr.life.hold(s, main.player_pos)
	var gp: Vector3 = L.groom.ch.position
	var g := Vector2(gp.x, gp.z)
	var y := _yard(s)
	var dir := (y - g).normalized() if y.distance_to(g) > 0.5 else Vector2(1, 0)
	var at := g + dir * dist
	main.player_pos = Vector3(at.x, main.world.height_at(at.x, at.y), at.y)
	main.player.position = main.player_pos
	await main._wait_frames(6)
	return g

func _idle_dialogue() -> void:
	var d = _d()
	var n := 0
	while (d.ui.modal or d.keeper.busy or d.ambient.busy) and n < 1200:
		await main._wait_frames(1); n += 1

# 3b) 남원 첫 사건 막음
class FakeMain:
	var world := { region = { region_id = "JL_NAMWON_UNBONG" } }

func _first_case_gate() -> void:
	var FT: Script = load("res://scripts/region/fast_travel.gd")
	var v0 = Progress.get_var("CASE_NAMWON_COMPLETE", false)
	var cs: Dictionary = Progress.case_state("namwon")
	var ph0 = cs.get("phase", null)
	Progress.data().vars["CASE_NAMWON_COMPLETE"] = false
	if not cs.is_empty(): cs.phase = "explore"
	var fm := FakeMain.new()
	var why: String = FT.gate_why(fm)
	var reach: Dictionary = FT.reachable_from(fm)
	Progress.data().vars["CASE_NAMWON_COMPLETE"] = v0
	if not cs.is_empty(): cs.phase = ph0
	print("STATIONTEST first-case gate why=%s reach=%s" % [why, reach.keys()])
	if why == "" or reach.size() != 1: _fail("남원 첫 사건 전인데 남원 밖 역마가 열림")
	if FT.gate_why(main) != "": _fail("남원을 마친 저장인데 막힘")

# 4a) 역 문 앞: 말 안내 없음, E를 눌러도 말이 오지 않음(마부 곁이 아닌 자리)
func _no_area_e(hr, s: Dictionary) -> void:
	await _go_station(s)
	var L = hr.life.live.get(String(s.id))
	var y := _yard(s)
	# 마부에게서 6m 넘게 떨어진 문 앞 길 자리
	var at := y
	if L != null:
		var gp: Vector3 = L.groom.ch.position
		var g := Vector2(gp.x, gp.z)
		if at.distance_to(g) < 6.0: at = y + (y - g).normalized() * (6.5 - at.distance_to(g))
	main.player_pos = Vector3(at.x, main.world.height_at(at.x, at.y), at.y); main.player.position = main.player_pos
	await main._wait_frames(10)
	var tgt = _d()._target
	print("STATIONTEST area-E prompt='%s' target=%s" % [hr.prompt, tgt.kind if tgt != null else "-"])
	if hr.prompt != "": _fail("역 문 앞에 넓은 말 안내가 남아 있음: %s" % hr.prompt)
	if tgt == null:
		await _key_e(); await main._wait_frames(20)
		if hr.state != "ON_FOOT" or (main.fast_ui != null and is_instance_valid(main.fast_ui)): _fail("역 문 앞 E로 말·역마가 시작됨")
	await _idle_dialogue()

# 4b) 마부 곁(1.8m)인데 고을 사람이 더 가까우면(0.9m) 그 사람과 말한다 — 말은 오지 않는다
func _npc_wins(hr, s: Dictionary) -> void:
	var d = _d()
	await _go_station(s)
	var npc = main.get("npcs_amb")
	var g := await _stand_by_groom(hr, s, 1.8)
	if npc == null or g == Vector2.INF: _fail("고을 사람·마부 없음"); return
	var key := -1
	for k in npc.agents:
		var ag = npc.agents[k]
		if not ag.animal and ag.ch.visible: key = k; break
	if key < 0:
		# 사람이 아직 안 나왔으면 잠시 기다린다
		for i in 300:
			await main._wait_frames(2)
			for k in npc.agents:
				var ag = npc.agents[k]
				if not ag.animal and ag.ch.visible: key = k; break
			if key >= 0: break
	if key < 0: _fail("역 곁에 고을 사람이 없음"); return
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var away := (pp - g).normalized()
	npc.hold(key, main.player_pos)
	npc._place(npc.agents[key], pp + away * 0.9)
	if not npc._near.has(key): npc._near.append(key)
	await main._wait_frames(6)
	var tgt = d._target
	print("STATIONTEST E-priority target=%s groom_d=%.1f npc_d=0.9" % [tgt.kind if tgt != null else "-", pp.distance_to(g)])
	if tgt == null or String(tgt.kind) != "ambient": _fail("마부보다 가까운 고을 사람이 대상이 아님(%s)" % (tgt.kind if tgt != null else "-"))
	d.ui.auto = true
	await _key_e()
	await main._wait_frames(4)
	var talked: bool = d.ambient.busy or int(d.ambient.last.get("key", -1)) == key
	print("STATIONTEST E-priority talked=%s keeper=%s ride=%s fast=%s" % [talked, d.keeper.busy, hr.state, main.fast_ui != null and is_instance_valid(main.fast_ui)])
	if not talked: _fail("E가 곁 사람 말 걸기로 가지 않음")
	if d.keeper.busy or hr.state != "ON_FOOT" or (main.fast_ui != null and is_instance_valid(main.fast_ui)): _fail("곁 사람에게 E를 눌렀는데 역참이 움직임")
	await _idle_dialogue()
	npc.unhold(key)
	npc._place(npc.agents[key], pp + away * 12.0)
	await main._wait_frames(30)
	hr.life.unhold(s)

# 4c) 마부 대화: 목록이 뜨는 동안 말·역마 창 없음 → 역 b를 고르면 그제야 마부가 말을 끌고 와 역마
func _keeper_menu_warp(hr, a: Dictionary, b: Dictionary) -> void:
	var d = _d()
	await _go_station(a)
	await _stand_by_groom(hr, a, 1.5)
	hr.life.unhold(a)
	await main._wait_frames(4)
	var tgt = d._target
	if tgt == null or String(tgt.kind) != "keeper":
		_fail("마부 곁에서 마부가 E 대상이 아님(%s)" % (tgt.kind if tgt != null else "-")); return
	var seen := { labels = [], during_ok = true, groom_still = true }
	var want := "역마 — %s" % String(b.name)
	d.ui.auto = true
	d.ui.auto_choice = func(prompt: String, labels: Array) -> int:
		seen.labels = labels.duplicate()
		var L = hr.life.live.get(String(a.id))
		if hr.state != "ON_FOOT" or (main.fast_ui != null and is_instance_valid(main.fast_ui)) or (L != null and L.has("bring")): seen.during_ok = false
		if L != null and not bool(L.groom.get("talk", false)): seen.groom_still = false
		for i in labels.size():
			if String(labels[i]).begins_with(want): return i
		return labels.size() - 1
	var h0: float = main.hour
	await _key_e()
	var t0 := Time.get_ticks_msec()
	var brought := false
	while Time.get_ticks_msec() - t0 < 30000:
		await main._wait_frames(1)
		var L = hr.life.live.get(String(a.id))
		if L != null and L.has("bring"): brought = true
		if main.fast_ui != null and is_instance_valid(main.fast_ui): break
	print("STATIONTEST keeper menu labels=%s during_ok=%s groom_still=%s brought=%s" % [seen.labels, seen.during_ok, seen.groom_still, brought])
	var has_b := false; var has_ride := false; var has_end := false
	for l in seen.labels:
		if String(l).begins_with(want): has_b = true
		if String(l).begins_with("말을 빌린다"): has_ride = true
		if String(l) == "그만두겠소.": has_end = true
	if not (has_b and has_ride and has_end): _fail("마부 목록이 모자람(역 %s·말 빌리기 %s·그만 %s)" % [has_b, has_ride, has_end])
	if not seen.during_ok: _fail("고르기 전에 말·역마가 시작됨")
	if not seen.groom_still: _fail("말하는 동안 마부가 일손을 멈추지 않음")
	if not brought: _fail("고른 뒤 마부가 말을 끌고 오지 않음")
	while main.fast_ui != null and is_instance_valid(main.fast_ui) and Time.get_ticks_msec() - t0 < 40000:
		await main._wait_frames(1)
	await _wait_load(); await main._wait_frames(30)
	var dd := _pp().distance_to(_yard(b))
	print("STATIONTEST keeper warp %s → %s d=%.1fm hour %.1f → %.1f" % [a.id, b.id, dd, h0, main.hour])
	if dd > 4.0: _fail("마부 역마 도착이 %s 문 앞이 아님 %.1fm" % [b.id, dd])
	d.ui.auto_choice = Callable()
	await _idle_dialogue()

# 4d) 길목 깃발: 알기 → 깃발에서 역으로 → 역 마부에게서 깃발로 → 저장 파일
func _flags(hr, a: Dictionary) -> void:
	var d = _d()
	var W = hr.flags
	if W == null or not W.enabled(): _fail("깃발 없음"); return
	# 역 a에서 300m 넘게 떨어진 가장 가까운 깃발
	var f := {}; var bd := INF
	for x in W.list:
		var dd: float = x.p.distance_to(_yard(a))
		if dd > 300.0 and dd < bd and not W.known(W.space, String(x.id)): bd = dd; f = x
	if f.is_empty(): _fail("시험할 깃발이 없음"); return
	if W.known(W.space, String(f.id)): _fail("깃발 %s가 처음부터 가 봄" % f.id)
	main.teleport(f.p.x + 1.2, f.p.y)
	main.rig.update(0, main.player_pos, main.player.facing, null, true)
	await _wait_load(); await main._wait_frames(60)
	var kn: bool = W.known(W.space, String(f.id))
	var live: bool = W.live.has(f.id) and bool(W.live[f.id].known)
	print("STATIONTEST flag %s(%s) known=%s live_known=%s spawned=%d" % [f.id, f.name, kn, live, W.stats.spawned])
	if not kn: _fail("깃발 곁에 갔는데 가 봄이 아님")
	if not live: _fail("깃발 그림이 없음/쪽빛이 아님")
	# 저장 파일(이어 하기·저장 칸은 이 파일)에 남았나
	var sf := ProjectSettings.globalize_path(String(main.args.get("savefile", "user://progress.json")))
	var j = JSON.parse_string(FileAccess.get_file_as_string(sf)) if FileAccess.file_exists(sf) else null
	var saved: bool = j is Dictionary and j.get("travel_nodes", {}).get(W.space, {}).has(String(f.id))
	print("STATIONTEST flag saved=%s file=%s" % [saved, sf])
	if not saved: _fail("깃발 가 봄이 저장 파일에 없음")
	# 깃발에서 E → 역 a로
	main.player_pos = Vector3(f.p.x + 1.0, main.world.height_at(f.p.x + 1.0, f.p.y), f.p.y); main.player.position = main.player_pos
	await main._wait_frames(8)
	var tgt = d._target
	if tgt == null or String(tgt.kind) != "flag": _fail("깃발 곁에서 깃발이 E 대상이 아님(%s)" % (tgt.kind if tgt != null else "-")); return
	await _menu_go(d, "역마 — %s" % String(a.name))
	var da := _pp().distance_to(_yard(a))
	print("STATIONTEST flag→station %s d=%.1fm" % [a.id, da])
	if da > 4.0: _fail("깃발에서 역으로 간 자리가 문 앞이 아님 %.1fm" % da)
	# 역 마부 → 깃발로
	await _stand_by_groom(hr, a, 1.5)
	hr.life.unhold(a)
	await main._wait_frames(4)
	await _menu_go(d, "깃발 — %s" % String(f.name))
	var node: Dictionary = hr.net.node_by.get(String(f.id), {})
	var arr: Array = node.get("arrive", [f.p.x, f.p.y])
	var df := _pp().distance_to(Vector2(float(arr[0]), float(arr[1])))
	print("STATIONTEST station→flag %s d=%.1fm" % [f.id, df])
	if df > 6.0: _fail("역에서 깃발로 간 자리가 깃발 곁이 아님 %.1fm" % df)

func _menu_go(d, want: String) -> void:
	var seen := { labels = [] }
	d.ui.auto = true
	d.ui.auto_choice = func(_p: String, labels: Array) -> int:
		seen.labels = labels.duplicate()
		for i in labels.size():
			if String(labels[i]).begins_with(want): return i
		return labels.size() - 1
	await _key_e()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		await main._wait_frames(1)
		if main.fast_ui != null and is_instance_valid(main.fast_ui): break
	var opened: bool = main.fast_ui != null and is_instance_valid(main.fast_ui)
	while main.fast_ui != null and is_instance_valid(main.fast_ui) and Time.get_ticks_msec() - t0 < 40000:
		await main._wait_frames(1)
	await _wait_load(); await main._wait_frames(30)
	d.ui.auto_choice = Callable()
	await _idle_dialogue()
	print("STATIONTEST menu want=%s labels=%s opened=%s" % [want, seen.labels, opened])
	if not seen.labels.any(func(l): return String(l).begins_with(want)): _fail("목록에 %s 없음" % want)
	if not opened: _fail("%s 골랐는데 역마 창이 안 열림" % want)

func _ride(hr, a: Dictionary, ride_to: String) -> void:
	Engine.time_scale = float(main.args.get("ridetime", "4"))
	hr.test_log = true
	# 마부 대화: '말을 빌린다' → ride_to 쪽
	var d = _d()
	var rc: Array = hr.station_ride_choices(a)
	print("STATIONTEST ride choices=%s" % [rc.map(func(x): return String(x.node.id))])
	var c = null
	for x in rc:
		if String(x.node.id) == ride_to: c = x
	if c == null: _fail("말 빌리기 목록에 %s 없음" % ride_to); return
	await _stand_by_groom(hr, a, 1.5)
	hr.life.unhold(a)
	await main._wait_frames(4)
	d.ui.auto = true
	var step := { n = 0 }
	d.ui.auto_choice = func(_p: String, labels: Array) -> int:
		step.n += 1
		for i in labels.size():
			var l := String(labels[i])
			if step.n == 1 and l.begins_with("말을 빌린다"): return i
			if step.n == 2 and l.begins_with(String(c.name) + " 쪽으로"): return i
		return labels.size() - 1
	await _key_e()
	var tw := Time.get_ticks_msec()
	while not hr.mounted() and Time.get_ticks_msec() - tw < 20000: await main._wait_frames(1)
	d.ui.auto_choice = Callable()
	if not hr.mounted(): _fail("말을 빌린다 → 말에 못 탐"); return
	var led: bool = not hr._lead_st.is_empty()
	var L = hr.life.live.get(String(a.id))
	var gp0: Vector3 = L.groom.ch.position if L != null else Vector3.ZERO
	print("STATIONTEST mount led=%s bring=%.1fs from=(%.1f,%.1f)" % [led, hr._t_bring, hr._mount_from.x, hr._mount_from.z])
	if not led: _fail("마부가 말을 끌어 오지 않음")
	var groom_moved := 0.0
	var t0 := Time.get_ticks_msec()
	var saw_ride := false
	while hr.mounted() and Time.get_ticks_msec() - t0 < 600000:
		await main._wait_frames(1)
		if L != null and hr.state == "MOUNTING": groom_moved = maxf(groom_moved, L.groom.ch.position.distance_to(gp0))
		if hr.riding(): saw_ride = true
	await main._wait_frames(20)
	var n: Dictionary = hr.net.node_by.get(ride_to, {})
	var gd := INF
	for g in n.get("gates", []): gd = minf(gd, _pp().distance_to(Vector2(float(g.x), float(g.z))))
	var stops: Array = hr.stats.get("stops", [])
	print("STATIONTEST ride %s → %s len=%.0fm groom_moved=%.1fm dismount gate_d=%.1f stops=%s" % [a.id, ride_to, hr.L, groom_moved, gd,
		stops.map(func(x): return "%s:%s" % [x.why, x.id])])
	if not saw_ride: _fail("말이 가지 않음")
	if groom_moved < 1.0: _fail("마부가 말을 끌고 걷지 않음")
	if stops.is_empty() or String(stops[stops.size() - 1].why) != "dest": _fail("목적지에서 안 내림")
	if gd > 25.0: _fail("내린 자리가 어귀에서 멂 %.1fm" % gd)

# ---- 다른 공간 역으로 ----
func _cross(id: String) -> void:
	var s := Stations.by_id(id)
	if s.is_empty():
		print("STATIONTEST FAIL 역 없음 %s" % id); main._quit(); return
	HorseRide.discover(String(s.space), String(s.node))
	var stt := Stations.state(id)
	print("STATIONTEST cross %s state=%s" % [id, stt])
	if not bool(stt.ok):
		print("STATIONTEST FAIL 갈 수 없음 %s" % stt.why); main._quit(); return
	Engine.set_meta(CONT, { id = id, space = String(s.space), h0 = main.hour })
	var r := Travel.warp_to_station(id)
	if not bool(r.ok):
		Engine.remove_meta(CONT)
		print("STATIONTEST FAIL warp 거절 %s" % r.why); main._quit()

func _verify_cross() -> void:
	var e: Dictionary = Engine.get_meta(CONT)
	Engine.remove_meta(CONT)
	await _wait_load()
	await main._wait_frames(60)
	var s := Stations.by_id(String(e.id))
	var here := String(main.world.region.get("route_id", main.world.region.get("region_id", "")))
	var d := _pp().distance_to(_yard(s))
	var L = main.horse_ride.life.live.get(String(e.id))
	print("STATIONTEST cross arrive space=%s d=%.1fm hour %.1f → %.1f life=%s" % [here, d, float(e.h0), main.hour, L != null])
	if here != String(e.space): _fail("다른 공간에 닿음 %s" % here)
	if d > 4.0: _fail("마방 문 앞이 아님 %.1fm" % d)
	if L == null or not L.has("wait"): _fail("마방 말이 없음")
	# 도착한 역: 문 앞 넓은 말 안내 없음, 마부 대화로 말을 빌릴 수 있다
	if main.horse_ride.prompt != "": _fail("도착한 역 문 앞에 넓은 말 안내 %s" % main.horse_ride.prompt)
	if main.horse_ride.station_ride_choices(s).is_empty(): _fail("도착한 역에서 말을 빌릴 수 없음")
	_end()

# ---- 화면(창 필요): --stationtest=flagshots[:거점,거점] --shotdir=폴더 — 깃발 곁(가 봄 전·후) · 권역 지도 · 전국 지도 ----
func _flagshots(ids: String) -> void:
	var dir: String = main._abs(String(main.args.get("shotdir", "shots/flags")))
	var W = main.horse_ride.flags
	if W == null or not W.enabled(): print("STATIONTEST FAIL 깃발 없음"); main._quit(); return
	var pick: Array = []
	if ids != "":
		for id in ids.split(","): if not W.by_id(id).is_empty(): pick.append(W.by_id(id))
	else: pick = W.list.slice(0, 2)
	for f in pick:
		# 깃발에서 카메라 쪽(+z)으로 조금 비켜 선다 — 깃발이 화면 가운데 위쪽에
		main.teleport(f.p.x - 2.5, f.p.y + 4.0)
		main.rig.update(0, main.player_pos, main.player.facing, null, true)
		await _wait_load(); await main._wait_frames(90)
		# 깃발은 처음 세울 때 담·집을 비켜 자리를 고친다 — 고친 자리 곁으로 다시
		main.teleport(f.p.x - 2.5, f.p.y + 4.0)
		main.rig.update(0, main.player_pos, main.player.facing, null, true)
		await main._wait_frames(30)
		var L = W.live.get(f.id)
		print("STATIONTEST flagshot %s p=%s arrive=%s player=%s live=%s map_flags=%d" % [f.id, f.p, f.get("arrive"), main.player_pos, L.nd.position if L != null else "-", main._map._collect_flags().size() if main._map != null else -1])
		main._save(dir.path_join("flag_%s_%s.png" % [W.space, f.id]))
	var mp = main._map
	if mp != null:
		# 지도: 지금 자리 표시가 깃발을 덮지 않게 마지막 깃발에서 150m 비켜 선다
		var lp: Vector2 = pick[pick.size() - 1].p if not pick.is_empty() else Vector2.ZERO
		main.teleport(lp.x + 150.0, lp.y + 60.0)
		await _wait_load(); await main._wait_frames(20)
		mp.toggle()
		await main._wait_frames(30)
		main._save(dir.path_join("map_town_%s.png" % W.space))
		mp.show_mode("all")
		await main._wait_frames(30)
		main._save(dir.path_join("map_region_%s.png" % W.space))
		mp.show_mode("nation")
		await main._wait_frames(30)
		main._save(dir.path_join("map_nation_%s.png" % W.space))
		mp.toggle()
	print("STATIONTEST PASS flagshots")
	main._quit()
