# 이동 규칙 시험(헤드리스, tools/run_story_tests.sh travel:*) — horse_ride.setup이 --traveltest를 보고 연다.
#   원칙: 이동은 편하게, 그러나 곁의 말 걸기·이야기 장면을 가로채지 않는다.
#   --traveltest=boat       나루(배 안내)가 떠 있어도 곁의 고을 사람이 먼저 E 대상 — 배 E는 오르지 않고 그 사람과 말한다 · 사람이 없으면 배 안내
#   --traveltest=mount      권역: 말 타는 곳 25m 안은 탈 수 있고 25~45m는 못 탄다(옛 45m) · 막 내린 자리 40m 안은 다시 탄다
#                            노정(--route): 말 타는 곳과 멀어도 큰길이면 탄다(그대로)
#   --traveltest=waymark    강·바닷길 노정(--route=SEA_NAMHAE_JEJU 등, 결정 5): 깃발(깃대·깃발 E)이 없다 · 거점에 가면 '가 봄'은 그대로 적히고
#                            깃발 알림은 없다 · 그 거점은 역마 창 목록에 그대로(깃발 아님) · 마부·깃발 목록에는 '깃발 — ○○'이 없다 · 뱃길(배)은 그대로
#   --traveltest=nightlock  남원 밤(해 질 무렵 준비 dusk_prep ~ 아침): 역마(역·깃발·마부)·역마 창·지도 역마·말·배·노정 포털·지나온 길 건너뛰기가
#                            모두 「아이들을 두고 멀리 떠날 수 없다」로 막히고, 걷기는 된다 · 아침이 되면 풀린다
# 판정: "TRAVELTEST PASS …" / "TRAVELTEST FAIL …"
extends RefCounted

const FT := preload("res://scripts/region/fast_travel.gd")
const Stations := preload("res://scripts/region/stations.gd")
const HorseRide := preload("res://scripts/region/horse_ride.gd")
const LOCK_LINE := "아이들을 두고 멀리 떠날 수 없다"

var main
var _fails: Array = []
var _oks := 0

func _init(m) -> void:
	main = m

func _ok(c: bool, w: String) -> void:
	if c: _oks += 1; print("TRAVELTEST check ok ", w)
	else: _fails.append(w); print("TRAVELTEST check FAIL ", w)

func _pp() -> Vector2:
	return Vector2(main.player_pos.x, main.player_pos.z)

func _wait_load() -> void:
	await main._wait_frames(10)
	var n := 0
	while main._loading and n < 6000:
		await main._wait_frames(1); n += 1
	n = 0
	while (main.world.stats.jobs > 0 or main.placement.busy()) and n < 900:
		await main._wait_frames(1); n += 1

func _put(p: Vector2) -> void:
	main.teleport(p.x, p.y)
	main.rig.update(0, main.player_pos, main.player.facing, null, true)
	await _wait_load()
	await main._wait_frames(20)

func _key_e() -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E; ev.keycode = KEY_E; ev.pressed = down
		Input.parse_input_event(ev)
		await main._wait_frames(2)

func _end() -> void:
	Engine.time_scale = 1.0
	if _fails.is_empty(): print("TRAVELTEST PASS checks=%d" % _oks)
	else: print("TRAVELTEST FAIL %s" % " / ".join(_fails))
	main._quit()

func run(spec: String) -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _wait_load()
	await main._wait_frames(30)
	match spec:
		"boat": await _boat()
		"mount": await _mount()
		"nightlock": await _nightlock()
		"waymark": await _waymark()
		_: _ok(false, "모르는 시험 " + spec)
	_end()

# ---- 1 나루: 배 안내보다 곁 사람이 먼저 ----
func _boat() -> void:
	var boats = main.boats
	var npc = main.npcs_amb
	var d = main.story
	if boats == null or boats.routes.is_empty() or npc == null or d == null:
		_ok(false, "배·고을 사람·이야기 없음"); return
	d.ui.auto = true
	var R: float = boats.BOARD_R
	var found := false
	for r in boats.routes:
		for e in 2:
			var land: Vector2 = r.land[e]
			await _put(land)
			# 나루 곁에 선 사람(사공·길손)을 찾아 그 사람 0.9m 곁, 내릴 자리 R 안에 선다
			for k in 40:
				await main._wait_frames(3)
				# 나루 곁 사람(사공·길손 — 나루 자리에 서는 사람이 없으면 가장 가까운 고을 사람을 나루 곁으로 불러 세운다)
				var key: int = npc.nearest_talkable(land, R + 2.0)
				if key < 0:
					var bd := 80.0
					for kk in npc.agents:
						var a2 = npc.agents[kk]
						if a2.animal or not a2.ch.visible or npc.NO_TALK.has(a2.mode): continue
						var dd := Vector2(a2.pos.x, a2.pos.z).distance_to(land)
						if dd < bd: bd = dd; key = kk
				if key < 0: continue
				var np: Vector2 = npc.info(key).p
				if np.distance_to(land) > R - 1.0:
					var ag = npc.agents[key]
					np = land + Vector2(1.6, 0.4)
					ag.pos = Vector3(np.x, main.world.height_at(np.x, np.y), np.y); ag.ch.position = ag.pos
				var at: Vector2 = np + (land - np).limit_length(0.9)
				if at.distance_to(land) >= R - 0.3: continue
				main.teleport(at.x, at.y)
				npc.hold(key, main.player_pos)
				await main.get_tree().create_timer(1.0, true, false, true).timeout   # 고을 사람 훑기(SCAN)가 한 번 돌게
				await main._wait_frames(5)
				var t = d.get("_target")
				print("TRAVELTEST boat %s end=%d npc=%s prompt='%s' target=%s" % [r.id, e, npc.info(key).kind, boats.prompt, (t.kind if t != null else "-")])
				if boats.prompt == "": continue
				found = true
				_ok(t != null and String(t.kind) == "ambient", "나루 배 안내(%s)가 떠 있어도 곁 사람이 E 대상" % boats.prompt)
				var shown := String(main._boat_prompt.get_meta("raw", "")) if main._boat_prompt != null else ""
				_ok(not shown.contains(boats.prompt), "곁 사람이 있으면 배 E 안내를 띄우지 않는다('%s')" % shown)
				var ev := InputEventKey.new()
				ev.physical_keycode = KEY_E; ev.keycode = KEY_E; ev.pressed = true
				Input.parse_input_event(ev)
				var talked := false
				for f in 12:
					await main._wait_frames(1)
					if d.ambient.busy or d.ui.modal: talked = true
				ev = ev.duplicate(); ev.pressed = false
				Input.parse_input_event(ev)
				await main._wait_frames(5)
				_ok(not boats.riding(), "E는 배에 오르지 않는다")
				_ok(talked, "E로 곁 사람과 말한다")
				var n := 0
				while (d.ambient.busy or d.ui.modal) and n < 1200:
					await main._wait_frames(1); n += 1
				npc.unhold(key)
				break
			if found: break
		if found: break
	_ok(found, "나루 곁 고을 사람 자리를 찾았다")
	if not found: return
	# 사람이 없는 자리(내릴 자리 바로 위)에서는 배 안내가 그대로
	var r0 = boats.routes[0]
	for e in 2:
		await _put(r0.land[e])
		await main._wait_frames(10)
		if d.get("_target") == null: break
	if d.get("_target") == null:
		_ok(boats.prompt != "", "곁 사람이 없으면 나루 배 안내(%s)" % boats.prompt)

# ---- 2 말 타는 곳 반지름 ----
func _mount() -> void:
	var hr = main.horse_ride
	if hr == null or not hr.enabled:
		_ok(false, "말 타기 없음"); return
	var net = hr.net
	if main.world.is_route:
		# 노정: 말 타는 곳과 상관없이 큰길이면 탄다
		var tried := 0; var good := 0
		for i in range(0, net.pts.size(), maxi(1, net.pts.size() / 40)):
			var q: Vector2 = net.pts[i]
			var far := true
			for mt in net.mounts:
				if q.distance_to(Vector2(float(mt.x), float(mt.z))) < 45.0: far = false; break
			if not far: continue
			await _put(q)
			var c: Dictionary = hr.mount_check()
			tried += 1
			if bool(c.ok): good += 1
			if String(c.get("why", "")) == "no_mount_spot": _ok(false, "노정 큰길에서 말 타는 곳 둘레를 따짐 %s" % str(q))
			if tried >= 6: break
		_ok(tried > 0 and good > 0, "노정: 말 타는 곳 45m 밖 큰길에서도 탄다(%d/%d)" % [good, tried])
		return
	_ok(is_equal_approx(HorseRide.MOUNT_R, 25.0), "권역 말 타는 곳 둘레 25m (%s)" % HorseRide.MOUNT_R)
	# 말 타는 곳 둘레 20m · 33m 큰길 자리(다른 말 타는 곳과 멀고, 막 내린·도착 자리 없음)
	var near_ok := false; var far_no := false; var redo_ok := false
	for mt in net.mounts:
		var m := Vector2(float(mt.x), float(mt.z))
		for want in [20.0, 33.0]:
			var p := _road_at(net, m, want)
			if p == Vector2.INF: continue
			var other := false
			for m2 in net.mounts:
				var mm := Vector2(float(m2.x), float(m2.z))
				if mm != m and p.distance_to(mm) < 25.0: other = true
			if other: continue
			await _put(p)
			hr._last_dismount = Vector2.INF; hr._arrived_mount = Vector2.INF
			var c: Dictionary = hr.mount_check()
			var why := String(c.get("why", ""))
			if why != "" and why != "no_mount_spot": continue   # 숲·사건 자리 등 다른 까닭은 빼고 본다
			if want == 20.0 and bool(c.ok): near_ok = true
			if want == 33.0 and why == "no_mount_spot":
				far_no = true
				# 막 내린 자리 40m 안은 다시 탄다
				hr._last_dismount = p + Vector2(12.0, 0.0)
				var c2: Dictionary = hr.mount_check()
				if bool(c2.ok): redo_ok = true
				hr._last_dismount = Vector2.INF
		if near_ok and far_no and redo_ok: break
	_ok(near_ok, "권역: 말 타는 곳 20m 안 큰길에서 탄다")
	_ok(far_no, "권역: 말 타는 곳 33m(옛 45m 안) 큰길에서는 못 탄다")
	_ok(redo_ok, "권역: 막 내린 자리 40m 안은 다시 탄다")
	_ok(is_equal_approx(HorseRide.STATION_QUIET, 45.0), "역참 문 앞 45m 조용한 둘레 그대로")

func _road_at(net, c: Vector2, r: float) -> Vector2:
	for i in 36:
		var a := i * TAU / 36.0
		var p := c + Vector2(cos(a), sin(a)) * r
		var gi: int = net.nearest(p, 1.2)
		if gi >= 0: return p
	return Vector2.INF

# ---- 3 남원 밤: 걷기는 자유, 먼 길은 막힘 ----
func _nightlock() -> void:
	var d = main.story
	if d == null or String(d.case_id) != "namwon":
		_ok(false, "남원 이야기 없음"); return
	var n := 0
	while (d.runner.busy or d.ui.modal) and n < 3000:
		await main._wait_frames(1); n += 1
	var S = d.S
	for k in ["s0000_started", "INTRO_MASTER_VOICE_DONE", "INTRO_NAMWON_TITLE_DONE", "case_started", "met_kids", "first_encounter",
			"dusk_return_seen", "kids_warned", "dusk_prep", "hunter_watch"]: S.flags[k] = true
	S.phase = "explore"
	d.set_hour(20.5)
	await _put(d.anchor("mill") + Vector2(6.0, 6.0))
	for ph in ["explore", "night"]:
		S.phase = ph
		await main._wait_frames(5)
		_ok(String(d.travel_lock()) == LOCK_LINE and FT.lock_why(main) == LOCK_LINE, "%s: 먼 길 막음 「%s」" % [ph, FT.lock_why(main)])
		FT.refused.clear()
		Stations.warp_node("JL_NAMWON_UNBONG", "namwon_eup")           # 역마(역·지도 역참 목록·마부 고른 뒤)
		main.open_fast_travel()                                        # 역마 창(마부 '역마 창'·지도 M·포털 H)
		main.map_fast_travel({ id = "fast_x", kind = "region", target = "GG_HANYANG", tx = 0.0, tz = 0.0, label = "한양", fast = true })   # 전국 지도 역마
		main._travel({ id = "pt_x", kind = "region", target = "GG_HANYANG", tx = NAN, tz = NAN, label = "한양" })   # 노정 포털 걸어 나가기
		main._travel({ id = "fast_pt", kind = "route", target = "JL_NAMWON_UNBONG-GG_HANYANG", tx = 0.0, tz = 0.0, label = "한양", fast = true })   # 지나온 길 건너뛰기
		main.horse_ride.begin_ride({})                                  # 말 타기(큰길 E · 마부 '말을 빌린다')
		main.boats.board("any")                                         # 배
		main.story.keeper.talk_keeper({})                               # 역참 마부
		main.story.keeper.talk_flag({})                                 # 길목 깃발
		await main._wait_frames(3)
		var whats: Array = FT.refused.map(func(e): return String(e[0]))
		for w in ["station", "fast_ui", "map", "portal", "skip", "horse", "boat", "keeper", "flag"]:
			_ok(whats.has(w), "%s: 막힘 — %s" % [ph, w])
		_ok(FT.refused.all(func(e): return String(e[1]) == LOCK_LINE), "%s: 막힐 때마다 알림 「%s」" % [ph, LOCK_LINE])
		_ok(not main._leaving and (main.fast_ui == null or not is_instance_valid(main.fast_ui)) and not main.horse_ride.mounted() and not main.boats.riding(),
			"%s: 장면을 떠나지 않았다(역마 창·말·배 없음)" % ph)
		_ok(main._hud != null and String(main._hud.text) == LOCK_LINE, "%s: 화면 알림 「%s」" % [ph, main._hud.text if main._hud != null else "-"])
		# 걷기는 된다(보이지 않는 벽 없음)
		var p0 := _pp()
		Input.action_press("move_up")
		await main.get_tree().create_timer(1.2, true, false, true).timeout
		Input.action_release("move_up")
		await main._wait_frames(2)
		_ok(_pp().distance_to(p0) > 1.0 and not d.blocks_move(), "%s: 걷기는 자유(%.1fm)" % [ph, _pp().distance_to(p0)])
	# 아침이면 풀린다
	S.phase = "morning"
	await main._wait_frames(5)
	_ok(String(d.travel_lock()) == "" and FT.lock_why(main) == "", "아침: 먼 길 막음이 풀린다")
	FT.refused.clear()
	main.open_fast_travel()
	await main._wait_frames(5)
	_ok(FT.refused.is_empty() and main.fast_ui != null and is_instance_valid(main.fast_ui), "아침: 역마 창이 다시 열린다")
	if main.fast_ui != null and is_instance_valid(main.fast_ui): main.fast_ui.close()
	S.phase = "done"
	_ok(String(d.travel_lock()) == "", "사건이 끝나면 막음 없음")

# ---- 4 강·바닷길 노정 깃발 없음(결정 5) ----
func _waymark() -> void:
	const Waymarks := preload("res://scripts/region/waymarks.gd")
	var sp := String(main.world.region.get("route_id", main.world.region.get("region_id", "")))
	var kind := Waymarks.route_kind(sp)
	_ok(kind in ["river", "sea"], "%s: 물 노정(%s)" % [sp, kind])
	var hr = main.horse_ride
	_ok(hr.flags != null and hr.flags.list.is_empty() and not hr.flags.enabled() and main.scene_vp.get_node_or_null("waymarks") == null,
		"깃발 없음(목록 %d · 깃대 노드 없음)" % (hr.flags.list.size() if hr.flags != null else -1))
	_ok(main.boats != null and not main.boats.routes.is_empty(), "뱃길 그대로(%d)" % (main.boats.routes.size() if main.boats != null else 0))
	# 물 노정의 마을 거점(예전 깃발 자리)
	var node := {}
	for n in hr.net.nodes if hr.net != null else []:
		if bool(n.get("fast", false)) and Waymarks.is_flag(n): node = n; break
	if node.is_empty():
		var j: Dictionary = load("res://scripts/region/ride_net.gd").read(sp)
		for n in j.get("nodes", []):
			if bool(n.get("fast", false)) and Waymarks.is_flag(n): node = n; break
	if node.is_empty(): _ok(false, "예전 깃발 거점이 없음"); return
	var id := String(node.id)
	var a: Array = node.get("arrive", [node.x, node.z])
	var at := Vector2(float(a[0]), float(a[1]))
	var kn: Dictionary = HorseRide.known_nodes()
	if kn.get(sp) is Dictionary: kn[sp].erase(id)
	await _put(at)
	await main._wait_frames(60)
	_ok(HorseRide.is_discovered(sp, id), "%s 도착: '가 봄' 그대로 적힘" % id)
	var d = main.story
	if d != null and d.keeper != null:
		var t = d.keeper.target(_pp())
		_ok(t == null or String(t.get("kind", "")) != "flag", "%s 곁: 깃발 E 없음" % id)
	await _put(at + Vector2(0.0, 220.0))
	var ft = FT.new(main)
	ft._gather()
	var it := {}
	for x in ft.items:
		if String(x.space) == sp and String(x.id) == id: it = x
	ft.free()
	_ok(not it.is_empty() and bool(it.ok) and not bool(it.flag), "역마 창 목록에 %s 그대로(갈 수 있음 · 깃발 아님)" % id)
	if d != null and d.keeper != null:
		var dl: Array = d.keeper.destinations()
		var labs: Array = dl[0].map(func(o): return String(o.label))
		_ok(labs.filter(func(l): return l.begins_with("깃발 — " + String(node.name))).is_empty() and int(dl[1]) > 0,
			"마부·깃발 목록에 '깃발 — %s' 없음 · 역마 창(가 본 다른 곳)으로 간다 %s rest=%d" % [node.name, labs, int(dl[1])])
