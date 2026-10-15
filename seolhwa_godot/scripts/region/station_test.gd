# 역참 시험(헤드리스, tools/run_story_tests.sh station:*) — horse_ride.setup이 --stationtest를 보고 연다.
#   --stationtest=a,b[,ride_to]   같은 공간 역 a·b에 차례로 가서 '가 봄'으로 적히는지(역 구역에 들어서면 travel_nodes) → 마방의 말·마부가 생겼는지
#                                 → Travel.warp_to_station(a)(지도에서 고른 것과 같은 길: 역마 창이 길을 그리고 시각이 흐름) → a 마방 문 앞 도착
#                                 → (2026-10) 문 앞 넓은 E 없음: 역 문 앞에서 말 안내가 비고 E를 눌러도 말이 오지 않는다
#                                 → E 차례: 마부 곁이라도 더 가까운 고을 사람이 있으면 그 사람과 말하고 말은 오지 않는다
#                                 → 마부 대화: 목록(가 본 역·깃발 · 말을 빌린다 · 그만두겠소)이 뜨는 동안 말·역마 창이 없다 → 고른 뒤에야 말이 온다
#                                 → 길목 깃발: 가까이 가면 '가 봄'·알림 → 깃발 E → 역으로 · 역 마부 E → 깃발로 · 저장 파일에 남음
#                                 → 마부 '말을 빌린다' → ride_to 거점 어귀까지 말로 가서 내림(마부가 가로대의 말을 끌고 나옴)
#                                 + 처음 가는 길 막힘: 제주 역은 가 본 것으로 적어도 남해 뱃길을 안 건넜으면 못 간다 · 남원 첫 사건 전엔 남원 밖으로 못 감
#   --stationtest=dev             개발 '전국 이동 열림': 꺼짐 — 남원 첫 사건 막음이 지도 고르기에서 흐림·까닭 / 켬 — 안 가 본 역·깃발·다른 공간(처음 가는 길·첫 사건 포함)
#                                 모두 갈 곳 · 저장(travel_nodes·known) 그대로 · 안 가 본 깃발로 역마해도 '가 봄' 안 적힘 · 표시 / 끔 — 다시 막힘
#   --stationtest=pickshots       화면(창): 마부 한 줄 · 권역 지도 고르기 · 흐린 곳 까닭 · 확인 상자 · 전국 지도 · 깃발 고르기 · 말 건너뛰기 단추 · 개발 전국 지도(--shotdir)
#   --stationtest=cross:<역>      그 역을 가 본 것으로 적고 다른 공간으로 역마 → 새 장면에서 그 역 마방 문 앞에 섰나(Engine 메타로 이어 봄)
# 판정: "STATIONTEST PASS …" / "STATIONTEST FAIL …"
extends RefCounted

const Stations := preload("res://scripts/region/stations.gd")
const Travel := preload("res://scripts/region/travel.gd")
const HorseRide := preload("res://scripts/region/horse_ride.gd")
const Progress := preload("res://scripts/region/progress.gd")
const RideNet := preload("res://scripts/region/ride_net.gd")
const CONT := "seolhwa_stationtest_cont"
const DevTravel := preload("res://scripts/region/dev_travel.gd")
const Discovery := preload("res://scripts/region/discovery.gd")

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
	if spec == "dev":
		await _dev(); return
	if spec == "pickshots":
		await _pickshots(); return
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
	await _keeper_cancel(hr, a)
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

# ---- 지도 고르기(역참 마부·깃발 E → region_map.open_pick) ----
func _key(kc: int) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = kc; ev.keycode = kc; ev.pressed = down
		Input.parse_input_event(ev)
		await main._wait_frames(2)

func _wait_pick(ms := 15000):
	var mp = main._map
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await main._wait_frames(1)
		if mp != null and mp.picking() and mp.visible: return mp
	return null

func _pick_index(mp, want: String) -> int:
	var labels: Array = mp.pick_labels()
	for i in labels.size():
		if String(labels[i]).begins_with(want): return i
	return -1

func _hold_pick() -> void:
	var d = _d()
	d.ui.auto = true
	d.keeper.auto_pick = func(_m): pass   # 시험이 지도를 몬다(없으면 자동 진행이 바로 그만둔다)

# 4c) 마부 E → 지도 고르기(권역 지도 · 금빛 테 · 못 가는 곳 까닭 · 1인칭 커서) → 역 b 두 번 눌러 → 그제야 마부가 말을 끌고 와 역마
func _keeper_menu_warp(hr, a: Dictionary, b: Dictionary) -> void:
	var d = _d()
	await _go_station(a)
	await _stand_by_groom(hr, a, 1.5)
	hr.life.unhold(a)
	main.set_first_person(true, false)   # 1인칭: 지도 동안 커서를 놓고, 닫히면 다시 잡는다(C68)
	await main._wait_frames(6)
	var fp0: bool = main.fp_mouse_wanted()
	var tgt = d._target
	if tgt == null or String(tgt.kind) != "keeper":
		_fail("마부 곁에서 마부가 E 대상이 아님(%s)" % (tgt.kind if tgt != null else "-")); main.set_first_person(false, false); return
	_hold_pick()
	var h0: float = main.hour
	await _key_e()
	var mp = await _wait_pick()
	if mp == null: _fail("마부 E → 지도 고르기가 안 열림"); main.set_first_person(false, false); return
	await main._wait_frames(4)
	var L = hr.life.live.get(String(a.id))
	var items: Array = mp.pick_items()
	var ib := _pick_index(mp, "역마 — %s" % String(b.name))
	var hits_ok: int = mp._hits.filter(func(h): return h.has("pick") and bool(items[int(h.pick)].ok)).size()
	print("STATIONTEST keeper map mode=%s labels=%s rides=%s hits_ok=%d btn=%s fp_before=%s fp_now=%s" % [mp.mode, mp.pick_labels(), d.keeper.last.get("rides", []),
		hits_ok, mp._pick_btn.visible, fp0, main.fp_mouse_wanted()])
	if not bool(d.keeper.last.get("map", false)): _fail("마부 대화가 지도 고르기가 아님(글 목록)")
	if ib < 0: _fail("지도 갈 곳에 %s 없음" % b.name)
	if mp.mode == "nation": _fail("같은 공간 갈 곳이 있는데 전국 지도로 열림")
	if hits_ok < 1: _fail("갈 수 있는 곳이 지도에 금빛 표지로 없음")
	if (d.keeper.last.get("rides", []) as Array).is_empty() or not mp._pick_btn.visible: _fail("마부 지도에 '말만 빌리기'가 없음")
	if hr.state != "ON_FOOT" or (main.fast_ui != null and is_instance_valid(main.fast_ui)) or (L != null and L.has("bring")): _fail("고르기 전에 말·역마가 시작됨")
	if L != null and not bool(L.groom.get("talk", false)): _fail("고르는 동안 마부가 일손을 멈추지 않음")
	if not fp0 or main.fp_mouse_wanted(): _fail("1인칭: 지도 동안 커서를 놓지 않음(전 %s · 지금 %s)" % [fp0, main.fp_mouse_wanted()])
	# 못 가는 곳: 까닭이 보이고 확인되지 않는다
	var ix := -1
	for i in items.size():
		if not bool(items[i].ok): ix = i; break
	if ix < 0: _fail("못 가는 곳(흐린 표지)이 지도에 없음")
	else:
		mp.pick_select(ix)
		await main._wait_frames(2)
		var msg: PackedStringArray = mp._confirm_msg()
		await _key(KEY_ENTER)
		var why := String(items[ix].why)
		print("STATIONTEST blocked %s why=%s box=%s flash=%s still=%s" % [items[ix].label, why, msg, mp.pick.get("flash", ""), mp.picking()])
		if not mp.picking() or not String(mp.pick.get("flash", "")).contains(why) or not " ".join(msg).contains(why): _fail("못 가는 곳의 까닭이 안 보이거나 확인됨")
	# 역 b: 한 번 눌러 고르고(확인 상자 — 이름·길) 한 번 더 눌러 간다
	if ib >= 0:
		mp.pick_click(ib)
		await main._wait_frames(2)
		var box: PackedStringArray = mp._confirm_msg()
		print("STATIONTEST confirm box %s" % [box])
		if box.size() < 3 or not box[0].contains(String(b.name)) or not box[1].contains("리"): _fail("확인 상자에 이름·거리가 없음 %s" % [box])
		mp.pick_click(ib)
	else: mp.pick_cancel()
	var t0 := Time.get_ticks_msec()
	var brought := false
	while Time.get_ticks_msec() - t0 < 30000:
		await main._wait_frames(1)
		var L2 = hr.life.live.get(String(a.id))
		if L2 != null and L2.has("bring"): brought = true
		if main.fast_ui != null and is_instance_valid(main.fast_ui): break
	print("STATIONTEST keeper picked=%s brought=%s map_open=%s" % [d.keeper.last.get("picked", ""), brought, mp.visible])
	if mp.visible or mp.picking(): _fail("고른 뒤 지도가 닫히지 않음")
	if not brought: _fail("고른 뒤 마부가 말을 끌고 오지 않음")
	while main.fast_ui != null and is_instance_valid(main.fast_ui) and Time.get_ticks_msec() - t0 < 40000:
		await main._wait_frames(1)
	await _wait_load(); await main._wait_frames(30)
	var dd := _pp().distance_to(_yard(b))
	print("STATIONTEST keeper warp %s → %s d=%.1fm hour %.1f → %.1f fp_after=%s" % [a.id, b.id, dd, h0, main.hour, main.fp_mouse_wanted()])
	if dd > 4.0: _fail("마부 역마 도착이 %s 문 앞이 아님 %.1fm" % [b.id, dd])
	await _idle_dialogue()
	if not main.fp_mouse_wanted(): _fail("1인칭: 역마 뒤 커서를 다시 잡지 않음")
	main.set_first_person(false, false)
	d.keeper.auto_pick = Callable()

# 4c') 마부 E → 지도 → Esc: 지도가 닫히고 말·역마·시각·자리 그대로
func _keeper_cancel(hr, a: Dictionary) -> void:
	var d = _d()
	await _go_station(a)
	await _stand_by_groom(hr, a, 1.5)
	hr.life.unhold(a)
	await main._wait_frames(4)
	_hold_pick()
	var h0: float = main.hour
	var p0 := _pp()
	await _key_e()
	var mp = await _wait_pick()
	if mp == null: _fail("취소 시험: 지도가 안 열림"); return
	# 재기획 2단계: 마부와 겹치면 말 걸 때 한 걸음 비켜 선다(talk_frame.gd, 최대 2.6m) — '자리 그대로'는 지도가 열린 뒤 자리로 본다
	var p1 := _pp()
	if p1.distance_to(p0) > 2.7: _fail("말 걸기 한 걸음이 너무 멀다 %.2f" % p1.distance_to(p0))
	await _key(KEY_ESCAPE)
	await main._wait_frames(20)
	await _idle_dialogue()
	var L = hr.life.live.get(String(a.id))
	print("STATIONTEST cancel map=%s picking=%s busy=%s ride=%s fast=%s hour %.2f→%.2f moved=%.2f" % [mp.visible, mp.picking(), d.keeper.busy, hr.state,
		main.fast_ui != null and is_instance_valid(main.fast_ui), h0, main.hour, _pp().distance_to(p0)])
	if mp.visible or mp.picking() or d.keeper.busy: _fail("Esc로 지도가 닫히지 않음")
	if hr.state != "ON_FOOT" or (main.fast_ui != null and is_instance_valid(main.fast_ui)) or (L != null and L.has("bring")): _fail("그만뒀는데 말·역마가 움직임")
	if absf(main.hour - h0) > 0.05 or _pp().distance_to(p1) > 0.5: _fail("그만뒀는데 시각·자리가 바뀜")
	d.keeper.auto_pick = Callable()

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
	var sf := ProjectSettings.globalize_path(Progress.slot_path(0))
	var j = JSON.parse_string(FileAccess.get_file_as_string(sf)) if FileAccess.file_exists(sf) else null
	var saved: bool = j is Dictionary and j.get("travel_nodes", {}).get(W.space, {}).has(String(f.id))
	print("STATIONTEST flag saved=%s file=%s" % [saved, sf])
	if not saved: _fail("깃발 가 봄이 저장 파일에 없음")
	# 깃발에서 E → 역 a로
	main.player_pos = Vector3(f.p.x + 1.0, main.world.height_at(f.p.x + 1.0, f.p.y), f.p.y); main.player.position = main.player_pos
	await main._wait_frames(8)
	var tgt = d._target
	if tgt == null or String(tgt.kind) != "flag": _fail("깃발 곁에서 깃발이 E 대상이 아님(%s)" % (tgt.kind if tgt != null else "-")); return
	var h1: float = main.hour
	await _menu_go(d, "역마 — %s" % String(a.name), true, true)   # 역마 연출을 Space로 건너뛴다 — 도착은 같아야 한다
	var da := _pp().distance_to(_yard(a))
	print("STATIONTEST flag→station(skip) %s d=%.1fm hour %.1f → %.1f" % [a.id, da, h1, main.hour])
	if is_equal_approx(h1, main.hour): _fail("건너뛴 역마에 시각이 흐르지 않음")
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

# 깃발·마부 E → 지도에서 want를 골라 Enter → 역마 창(skip이면 연출 도중 Space로 건너뛴다)
func _menu_go(d, want: String, flag := false, skip := false) -> void:
	_hold_pick()
	await _key_e()
	var mp = await _wait_pick()
	if mp == null: _fail("%s: 지도 고르기가 안 열림" % want); return
	var labels: Array = mp.pick_labels()
	var i := _pick_index(mp, want)
	if flag and mp._pick_btn.visible: _fail("깃발 지도에 말 빌리기가 있음")
	if i < 0: _fail("지도 갈 곳에 %s 없음 %s" % [want, labels]); mp.pick_cancel(); await _idle_dialogue(); return
	mp.pick_select(i)
	await main._wait_frames(2)
	await _key(KEY_ENTER)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		await main._wait_frames(1)
		if main.fast_ui != null and is_instance_valid(main.fast_ui): break
	var opened: bool = main.fast_ui != null and is_instance_valid(main.fast_ui)
	var skipped := false
	if skip and opened:
		var t1 := Time.get_ticks_msec()
		while is_instance_valid(main.fast_ui) and main.fast_ui._anim < 0.0 and Time.get_ticks_msec() - t1 < 5000: await main._wait_frames(1)
		if is_instance_valid(main.fast_ui) and main.fast_ui._anim < 0.5:
			await _key(KEY_SPACE)
			skipped = true
	while main.fast_ui != null and is_instance_valid(main.fast_ui) and Time.get_ticks_msec() - t0 < 40000:
		await main._wait_frames(1)
	await _wait_load(); await main._wait_frames(30)
	d.keeper.auto_pick = Callable()
	await _idle_dialogue()
	print("STATIONTEST map want=%s labels=%s opened=%s skipped=%s dt=%.1fs" % [want, labels, opened, skipped, (Time.get_ticks_msec() - t0) / 1000.0])
	if not opened: _fail("%s 골랐는데 역마 창이 안 열림" % want)

func _ride(hr, a: Dictionary, ride_to: String) -> void:
	Engine.time_scale = float(main.args.get("ridetime", "4"))
	hr.test_log = true
	var r1: Dictionary = await _ride_once(hr, a, ride_to, false)
	if r1.is_empty(): return
	# 같은 길을 건너뛰기로: 같은 어귀에 내리고 같은 거점이 '가 봄'으로 적혀야 한다
	var kn: Dictionary = HorseRide.known_nodes().get(hr.net.space, {})
	for id in r1.found: kn.erase(id)
	await _go_station(a)
	var r2: Dictionary = await _ride_once(hr, a, ride_to, true)
	if r2.is_empty(): return
	var dp: float = (r1.at as Vector2).distance_to(r2.at)
	var missing: Array = (r1.found as Array).filter(func(id): return not HorseRide.is_discovered(hr.net.space, String(id)))
	print("STATIONTEST ride skip same=%.1fm state=%s/%s found=%s missing=%s" % [dp, r1.state, r2.state, r1.found, missing])
	if dp > 5.0: _fail("건너뛴 말 타기 도착이 다름 %.1fm" % dp)
	if String(r2.state) != String(r1.state): _fail("건너뛴 뒤 상태가 다름 %s / %s" % [r1.state, r2.state])
	if not missing.is_empty(): _fail("건너뛰니 지나온 거점 '가 봄'이 빠짐 %s" % [missing])

# 마부 지도 → R(말만 빌리기) → 'ride_to 쪽' 말 패 → Enter. skip이면 타자마자 Space(건너뛰기 단추와 같은 길)
func _ride_once(hr, a: Dictionary, ride_to: String, skip: bool) -> Dictionary:
	var d = _d()
	var rc: Array = hr.station_ride_choices(a)
	var c = null
	for x in rc:
		if String(x.node.id) == ride_to: c = x
	if c == null: _fail("말 빌리기 목록에 %s 없음" % ride_to); return {}
	await _stand_by_groom(hr, a, 1.5)
	hr.life.unhold(a)
	await main._wait_frames(4)
	var known0: Dictionary = (HorseRide.known_nodes().get(hr.net.space, {}) as Dictionary).duplicate()
	_hold_pick()
	await _key_e()
	var mp = await _wait_pick()
	if mp == null: _fail("말 빌리기: 지도가 안 열림"); return {}
	await _key(KEY_R)
	var i := _pick_index(mp, "말 — %s 쪽으로" % String(c.name))
	print("STATIONTEST ride map sub=%s labels=%s" % [mp.pick.get("sub", ""), mp.pick_labels()])
	if String(mp.pick.get("sub", "")) != "ride" or i < 0: _fail("지도에서 말 타고 갈 쪽(%s)을 못 고름" % c.name); mp.pick_cancel(); return {}
	mp.pick_select(i)
	await main._wait_frames(2)
	await _key(KEY_ENTER)
	var tw := Time.get_ticks_msec()
	while not hr.mounted() and Time.get_ticks_msec() - tw < 20000: await main._wait_frames(1)
	d.keeper.auto_pick = Callable()
	if not hr.mounted(): _fail("말 빌리기 → 말에 못 탐"); return {}
	var led: bool = not hr._lead_st.is_empty()
	var L = hr.life.live.get(String(a.id))
	var gp0: Vector3 = L.groom.ch.position if L != null else Vector3.ZERO
	print("STATIONTEST mount led=%s bring=%.1fs skip=%s" % [led, hr._t_bring, skip])
	if not led: _fail("마부가 말을 끌어 오지 않음")
	var groom_moved := 0.0
	var t0 := Time.get_ticks_msec()
	var saw_ride := false
	var skipped := 0
	var ov = main.get_node_or_null("travel_overlay")
	while hr.mounted() and Time.get_ticks_msec() - t0 < 600000:
		await main._wait_frames(1)
		if L != null and hr.state == "MOUNTING": groom_moved = maxf(groom_moved, L.groom.ch.position.distance_to(gp0))
		if hr.riding(): saw_ride = true
		if skip and hr.can_skip():
			await main._wait_frames(2)
			if ov != null and String(ov.what) == "horse" and ov._btn.visible:
				await _key(KEY_SPACE); skipped += 1
			elif hr.can_skip(): hr.skip(); skipped += 1
	await main._wait_frames(20)
	var n: Dictionary = hr.net.node_by.get(ride_to, {})
	var gd := INF
	for g in n.get("gates", []): gd = minf(gd, _pp().distance_to(Vector2(float(g.x), float(g.z))))
	var stops: Array = hr.stats.get("stops", [])
	var found: Array = (HorseRide.known_nodes().get(hr.net.space, {}) as Dictionary).keys().filter(func(k): return not known0.has(k))
	var dt := (Time.get_ticks_msec() - t0) / 1000.0
	print("STATIONTEST ride %s → %s len=%.0fm groom_moved=%.1fm gate_d=%.1f stops=%s skipped=%d t=%.1fs found=%s" % [a.id, ride_to, hr.L, groom_moved, gd,
		stops.map(func(x): return "%s:%s" % [x.why, x.id]), skipped, dt, found])
	if not saw_ride: _fail("말이 가지 않음")
	if groom_moved < 1.0: _fail("마부가 말을 끌고 걷지 않음")
	if stops.is_empty() or String(stops[stops.size() - 1].why) != "dest": _fail("목적지에서 안 내림")
	if gd > 25.0: _fail("내린 자리가 어귀에서 멂 %.1fm" % gd)
	if skip and skipped < 1: _fail("말 타기 건너뛰기를 못 함")
	return { at = _pp(), state = hr.state, found = found }

# ---- 개발 '전국 이동 열림'(scripts/region/dev_travel.gd) ----
func _save_text() -> String:
	var sf := ProjectSettings.globalize_path(Progress.slot_path(0))
	var j = JSON.parse_string(FileAccess.get_file_as_string(sf)) if FileAccess.file_exists(sf) else null
	if not (j is Dictionary): return ""
	return JSON.stringify([j.get("travel_nodes", {}), j.get("known", {}), j.get("routes_done", {})])

func _dev() -> void:
	var d = _d()
	var mp = main._map
	Progress.save()
	var st := Stations.by_id("namwon")
	# 1) 꺼짐 + 남원 첫 사건 전: 지도 고르기에서 다른 공간은 흐리고 까닭이 첫 사건 알림
	HorseRide.discover(String(st.space), String(st.node))
	var jj := Stations.by_id("jeju")
	HorseRide.discover(String(jj.space), String(jj.node))
	Progress.save()
	var v0 = Progress.get_var("CASE_NAMWON_COMPLETE", false)
	Progress.data().vars["CASE_NAMWON_COMPLETE"] = false
	var cs: Dictionary = Progress.case_state("namwon")
	var ph0 = cs.get("phase", null)
	if not cs.is_empty(): cs.phase = "explore"
	var FT: Script = load("res://scripts/region/fast_travel.gd")
	var gate: String = FT.gate_why(main)
	var dl: Array = d.keeper.destinations()
	var cross: Array = (dl[0] as Array).filter(func(o): return not bool(o.same))
	print("STATIONTEST dev off gate=%s cross=%s" % [gate, cross.map(func(o): return "%s:%s:%s" % [o.label, o.ok, o.why])])
	if gate == "" or cross.is_empty() or cross.any(func(o): return bool(o.ok) or String(o.why) != gate): _fail("첫 사건 막음이 지도 갈 곳에서 흐림·까닭으로 안 보임")
	# 2) 켬: 첫 사건 중이어도 모두 열림
	var save0 := _save_text()
	DevTravel.set_on(true)
	await main._wait_frames(3)
	var ov = main.get_node_or_null("travel_overlay")
	var shown: bool = ov != null and ov._dev.visible
	dl = d.keeper.destinations()
	var all: Array = dl[0]
	var nok: int = all.filter(func(o): return bool(o.ok)).size()
	var spaces := {}
	for o in all: spaces[String(o.space)] = true
	var js := Stations.state("jeju")
	print("STATIONTEST dev on dests=%d ok=%d spaces=%d jeju=%s gate='%s' lock='%s' shown=%s" % [all.size(), nok, spaces.size(), js, FT.gate_why(main), FT.lock_why(main), shown])
	if nok != all.size() or all.size() < 60 or spaces.size() < 8: _fail("개발: 모든 역·깃발이 열리지 않음 %d/%d 공간 %d" % [nok, all.size(), spaces.size()])
	if not bool(js.ok): _fail("개발: 제주(처음 가는 길)가 막힘")
	if not shown: _fail("개발 표시 '전국 이동 열림'이 없음")
	# 지도 고르기: 전국 지도에 다른 공간 갈 곳이 모두 금빛
	_hold_pick()
	var hr = main.horse_ride
	mp.open_pick({ from = "flag", dests = all, rides = [] })
	await main._wait_frames(3)
	await _key(KEY_TAB)
	await main._wait_frames(3)
	var items: Array = mp.pick_items()
	var hits_ok: int = mp._hits.filter(func(h): return h.has("pick") and bool(items[int(h.pick)].ok)).size()
	print("STATIONTEST dev map mode=%s hits_ok=%d" % [mp.mode, hits_ok])
	if mp.mode != "nation" or hits_ok < 20: _fail("개발: 전국 지도에 열린 갈 곳이 적음 %d" % hits_ok)
	mp.pick_cancel()
	await main._wait_frames(3)
	# 안 가 본 깃발로 역마 — 도착해도 '가 봄'이 저장에 안 남는다
	var fl := {}
	for o in all:
		if bool(o.same) and String(o.kind) == "flag" and not HorseRide.is_discovered(String(o.space), String(o.node)): fl = o; break
	if not fl.is_empty():
		var r: Dictionary = Stations.warp_node(String(fl.space), String(fl.node))
		var t0 := Time.get_ticks_msec()
		await main._wait_frames(5)
		while main.fast_ui != null and is_instance_valid(main.fast_ui) and Time.get_ticks_msec() - t0 < 20000: await main._wait_frames(1)
		await _wait_load(); await main._wait_frames(60)
		var at: Vector2 = fl.c
		print("STATIONTEST dev warp %s ok=%s d=%.1fm discovered=%s" % [fl.label, r.ok, _pp().distance_to(at), HorseRide.is_discovered(String(fl.space), String(fl.node))])
		if not bool(r.ok) or _pp().distance_to(at) > 8.0: _fail("개발: 안 가 본 깃발로 역마가 안 됨")
		if HorseRide.is_discovered(String(fl.space), String(fl.node)): _fail("개발: 역마 도착이 '가 봄'으로 적힘")
	Progress.save()
	var save1 := _save_text()
	if save0 != save1: _fail("개발: 저장 파일의 가 봄·앎·지나온 길이 바뀜")
	# 3) 끔: 다시 막힘
	DevTravel.set_on(false)
	js = Stations.state("jeju")
	var gate2: String = FT.gate_why(main)
	print("STATIONTEST dev off again jeju=%s gate=%s" % [js, gate2])
	if bool(js.ok) or gate2 == "": _fail("개발을 껐는데 막힘이 안 돌아옴")
	Progress.data().vars["CASE_NAMWON_COMPLETE"] = v0
	if not cs.is_empty(): cs.phase = ph0
	d.keeper.auto_pick = Callable()
	_end()

# ---- 화면(창): --stationtest=pickshots --shotdir=… --winshot ----
func _pickshots() -> void:
	var dir: String = main._abs(String(main.args.get("shotdir", "shots/station_map_pick")))
	DirAccess.make_dir_recursive_absolute(dir)
	var d = _d()
	var hr = main.horse_ride
	var a := Stations.by_id("namwon")
	var b := Stations.by_id("inwol")
	for s in [a, b, Stations.by_id("jeju")]: HorseRide.discover(String(s.space), String(s.node))
	for n in ["namwon_jang", "unbong_eup"]: HorseRide.discover("JL_NAMWON_UNBONG", n)
	for n in RideNet.read("GG_HANYANG").get("nodes", []).slice(0, 40):
		if bool(n.get("fast", false)): HorseRide.discover("GG_HANYANG", String(n.id))
	Progress.save()
	await _go_station(a)
	await main._wait_frames(60)
	await _stand_by_groom(hr, a, 1.6)
	hr.life.unhold(a)
	await main._wait_frames(10)
	d.ui.auto = true
	d.ui.auto_hold = 2.5
	d.keeper.auto_pick = func(_m): pass
	await _key_e()
	await main._wait_frames(40)
	main._save(dir.path_join("1_keeper_line.png"))
	var mp = await _wait_pick()
	if mp == null: print("STATIONTEST FAIL 지도 안 열림"); main._quit(); return
	await main._wait_frames(20)
	main._save(dir.path_join("2_region_picker.png"))
	var items: Array = mp.pick_items()
	for i in items.size():
		if not bool(items[i].ok) and bool(items[i].same):
			mp.pick_select(i); break
	await main._wait_frames(10)
	main._save(dir.path_join("3_blocked_reason.png"))
	mp.pick_select(_pick_index(mp, "역마 — %s" % String(b.name)))
	await main._wait_frames(10)
	main._save(dir.path_join("4_confirm.png"))
	await _key(KEY_TAB)
	await main._wait_frames(10)
	mp.pick_cycle(1)
	await main._wait_frames(10)
	main._save(dir.path_join("5_nation_picker.png"))
	await _key(KEY_ESCAPE)
	await main._wait_frames(20)
	await _idle_dialogue()
	# 깃발
	var W = hr.flags
	var f = W.by_id("namwon_jang")
	if not f.is_empty():
		main.teleport(f.p.x + 1.0, f.p.y)
		main.rig.update(0, main.player_pos, main.player.facing, null, true)
		await _wait_load(); await main._wait_frames(60)
		main.player_pos = Vector3(f.p.x + 1.0, main.world.height_at(f.p.x + 1.0, f.p.y), f.p.y); main.player.position = main.player_pos
		await main._wait_frames(10)
		await _key_e()
		mp = await _wait_pick()
		await main._wait_frames(20)
		main._save(dir.path_join("6_flag_picker.png"))
		if mp != null: await _key(KEY_ESCAPE)
		await main._wait_frames(10)
		await _idle_dialogue()
	# 말 건너뛰기 단추
	await _go_station(a)
	await _stand_by_groom(hr, a, 1.5)
	hr.life.unhold(a)
	await main._wait_frames(6)
	await _key_e()
	mp = await _wait_pick()
	if mp != null:
		await _key(KEY_R)
		await main._wait_frames(10)
		main._save(dir.path_join("7_ride_picker.png"))
		mp.pick_select(_pick_index(mp, "말 — 운봉 읍치"))
		await _key(KEY_ENTER)
		var t0 := Time.get_ticks_msec()
		while not hr.riding() and Time.get_ticks_msec() - t0 < 20000: await main._wait_frames(1)
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 4000: await main._wait_frames(1)
		main._save(dir.path_join("8_ride_skip_button.png"))
		await _key(KEY_SPACE)
		while hr.mounted() and Time.get_ticks_msec() - t1 < 30000: await main._wait_frames(1)
		await main._wait_frames(30)
	# 개발: 전국 지도 모두 열림
	DevTravel.set_on(true)
	d.keeper.auto_pick = func(_m): pass
	mp = main._map
	mp.open_pick({ from = "flag", dests = d.keeper.destinations()[0], rides = [] })
	await main._wait_frames(5)
	await _key(KEY_TAB)
	await main._wait_frames(20)
	main._save(dir.path_join("9_dev_nation_all_open.png"))
	mp.pick_cancel()
	DevTravel.set_on(false)
	print("STATIONTEST PASS pickshots")
	main._quit()

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
