# 대본 시험(--storytest=hanyang[:r01]) — 남원을 끝낸 저장(MAIN_MASTER_TRACE = HANYANG)에서 S1001~S1006까지.
#   godot --path seolhwa_godot res://scenes/region.tscn -- --region=GG_HANYANG --storytest=hanyang
#   hanyang      : 숭례문 앞(역마 도착 자리)에서 시작. 추격은 한 번 일부러 놓치고(멈춰 서기) '다시 쫓기'로 끝까지 따라간다.
#   hanyang:r01  : R01 노정 끝 포털(노들 남쪽)에 닿은 자리에서 시작(먼 도착 → 숭례문 앞). 추격은 놓친 뒤 '발자국을 따라간다'.
# 저장은 user://storytest_progress.json(prepare가 남원 끝 상태로 꾸민다). 결과는 STORYTEST PASS/FAIL.
extends Node

const Progress := preload("res://scripts/region/progress.gd")
const Rumors := preload("res://story/rumors_data.gd")

var d
var branch := "GATE"
var _t0 := 0
var _fails: Array = []
var prefer: Array = []
# 추격 봇
var bot_mode := "follow"     # follow | stand
var bot_speed := 4.6
var _bot_s := -1.0
var _blocked := 0
var _blocked_at := []
var _chase_log_t := 0.0
var _shots := {}

# 남원 사건을 끝낸 저장으로 꾸민다(사건 장면을 다시 돌리지 않고)
static func prepare(_dir) -> void:
	Progress.data()
	Progress.set_var("MAIN_MASTER_TRACE", "HANYANG")
	Progress.set_var("SKILL_BEAST_TRACE", true)
	Progress.set_var("CASE_NAMWON_OUTCOME", "C")
	Progress.set_var("CASE_NAMWON_DETAIL", "C")
	Progress.set_var("MAIN_PARK_MARK_COUNT", 1)   # R0104 천안삼거리를 지나왔다고 치고
	Progress.set_var("SKILL_GUARD_SHOVE", true)
	Progress.data().cases["namwon"] = { "v": 2, "phase": "done", "flags": { "case_started": true, "resolved": true }, "clues": [], "rules": [],
		"items": { "ITM_TOOL_009": 1, "ITM_WPN_001": 1, "ITM_WPN_002": 1, "ITM_AMMO_001": 12, "COIN": 7 }, "world": {}, "talked": {}, "notes": [],
		"seen": { "S0010": true }, "time": 8.0 }
	Progress.save()

func _init(director, spec: String) -> void:
	d = director
	var p := spec.split(":")
	branch = (p[1] if p.size() > 1 else "gate").to_upper()
	name = "story_test"

func begin() -> void:
	d.ui.auto = true
	d.ui.auto_choice = choose
	Engine.time_scale = float(d.main.args.get("storyspeed", "2.5"))
	if d.main.args.has("novsync"):   # 추격 중 fps를 수직 동기 없이 잰다(chase 기록 "fps" 평균·최저)
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()

func _log(s: String) -> void:
	printerr("STORYTEST [%s] %6.1fs %s" % [branch, (Time.get_ticks_msec() - _t0) / 1000.0, s])

func choose(_prompt: String, labels: Array) -> int:
	for want in prefer:
		for i in labels.size():
			if labels[i] != "" and String(labels[i]).contains(want): return i
	for i in labels.size():
		if labels[i] != "" and not String(labels[i]).contains("그만"): return i
	return 0

func _idle() -> void:
	var n := 0
	while (d.runner.busy or d.ui.modal) and n < 60000:
		await get_tree().process_frame
		n += 1
	await get_tree().process_frame

func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func _fail(s: String) -> void:
	_fails.append(s); _log("FAIL " + s)

func expect(c: bool, what: String) -> void:
	if c: _log("ok " + what)
	else: _fail(what)

func go(id: String, dz := 1.0) -> void:
	await _idle()
	var p: Vector2 = d.anchor(id) if not d.actors.has(id) else Vector2(d.actors[id].pos.x, d.actors[id].pos.z)
	d.teleport_to(Vector2(p.x, p.y + dz), "up")
	await _frames(8)
	await _idle()
	d._refresh()
	var ok := false
	for t in d._targets():
		if t.id == id: ok = true
	if not ok:
		var pp: Vector3 = d.main.player_pos
		_fail("대상 없음/조건 안 맞음: %s (플레이어 %.1f,%.1f → 대상 %.1f,%.1f)" % [id, pp.x, pp.z, p.x, p.y])
		return
	_log("interact " + id)
	d.interact(id)
	await _frames(2)
	await _idle()

func walk_to(at) -> void:
	await _idle()
	d.teleport_to(at, "up")
	await _frames(12)
	await get_tree().create_timer(0.45).timeout   # 자리 트리거는 0.2초마다 본다(시간 배율·fps와 상관없이)
	await _idle()

func shot(nm: String, frames := 10) -> void:
	if not d.main.args.has("storyshots") or DisplayServer.get_name() == "headless": return
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	await _frames(frames)
	var dir: String = d.main._abs(String(d.main.args.storyshots))
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("hanyang_%s_%s.png" % [branch, nm]))
	_log("SHOT " + nm)
	Engine.time_scale = ts

# ---- 추격 봇: 쫓는 길(follow)을 플레이어 달리기 속도로 따라간다. stand면 멈춰 선다(놓치기 시험) ----
func chase_bot(c, dt: float) -> void:
	if _bot_s < 0.0: _bot_s = c.prog
	_chase_log_t += dt
	if _chase_log_t > 2.0:
		_chase_log_t = 0.0
		_log("추격 seg=%d %s 앞섬 %.1f 벗어남 %.1f 우치(%.1f,%.1f y=%s) fps=%d" % [c.seg_i, c.segs[c.seg_i].mode, c.lead, c.off, c.a.pos.x, c.a.pos.z,
			str(snappedf(c.a.y_abs, 0.1)) if not is_nan(c.a.y_abs) else "땅", Engine.get_frames_per_second()])
	var sk := "%d_%s" % [c.seg_i, c.segs[c.seg_i].mode]
	if not _shots.has(sk) and c.started and c.seg_s > 2.0 and c.seg_i in [2, 4, 6, 8]:
		_shots[sk] = true
		_shot_now("chase_" + sk)
	if bot_mode == "stand" and d.main.args.has("blockmap") and not _shots.has("_map"):
		_shots["_map"] = true
		var a: PackedStringArray = String(d.main.args.blockmap).split(",")   # x0,z0,x1,z1
		for zz in range(int(a[1]), int(a[3]) + 1):
			var row := ""
			for xx in range(int(a[0]), int(a[2]) + 1): row += "#" if d.world.blocked(xx, zz, 0.3) else "."
			_log("map z=%d %s" % [zz, row])
	if bot_mode == "stand":
		d.main.player.set_anim("idle")
		return
	_bot_s = minf(_bot_s + bot_speed * dt, c.follow_total)
	var p: Vector2 = c.follow_point(_bot_s)
	var prev := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	if d.world.blocked(p.x, p.y, 0.3):
		_blocked += 1
		if _blocked_at.size() < 40 and (_blocked_at.is_empty() or _blocked_at[-1].distance_to(p) > 2.0): _blocked_at.append(p)
	d.set_player_pos(Vector3(p.x, d.world.height_at(p.x, p.y), p.y))
	d.main.player.facing = d.main.facing_from(p.x - prev.x, p.y - prev.y, d.main.player.facing)
	d.main.player.set_anim("run")

# 추격 중 화면(대본은 추격이 끝날 때까지 기다리므로 따로)
func _shot_now(nm: String) -> void:
	if not d.main.args.has("storyshots") or DisplayServer.get_name() == "headless": return
	var dir: String = d.main._abs(String(d.main.args.storyshots))
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("hanyang_%s_%s.png" % [branch, nm]))
	_log("SHOT " + nm)

# ---- 대본 ----
func _run() -> void:
	_log("시작 branch=%s vars=%s" % [branch, JSON.stringify({ t = d.S.vars.MAIN_MASTER_TRACE, o = d.S.vars.CASE_NAMWON_OUTCOME })])
	expect(d.case_id == "hanyang", "남원 뒤 한양 사건이 섰다")
	# 도착 자리: 역마(숭례문 앞) 또는 R01 노정 끝(노들 남쪽 포털)
	if branch == "R01": d.teleport_to([-1809.2, 2516.0], "up")
	else: d.teleport_to("gate_front", "up")
	await _frames(10)
	await d.runner.run([{ "event": "S1001" }])
	expect(d.S.phase == "explore" and d.S.is_flag("case_started"), "S1001 → 사건 기록")
	expect(Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("gate")) < 80.0, "숭례문 앞에 섬")
	expect(d.S.has_clue("note"), "이겸의 쪽지")
	await walk_to("gate")
	expect(d.S.is_flag("gate_passed"), "숭례문 지남")
	await walk_to("jongno")
	await _frames(20); await _idle()
	expect(d.S.is_flag("s1001_done"), "S1001 종루")
	await shot("jongno")
	# S1002 책방
	await walk_to("shop_door")
	await _frames(10); await _idle()
	expect(d.S.is_flag("in_shop"), "S1002 책방 문턱")
	_log("앵커 책방: back_window=%s inside=%s desk=%s / 창고: door=%s bound=%s" % [d.world.prop_anchor("hy_sc_chaekbang", "back_window"),
		d.world.prop_anchor("hy_sc_chaekbang", "inside"), d.world.prop_anchor("hy_sc_chaekbang", "desk"),
		d.world.prop_anchor("hy_sc_bin_changgo", "door"), d.world.prop_anchor("hy_sc_bin_changgo", "bound")])
	_log("상태: window=%s meoktong=%s tea=%s" % [d.world.get_prop_state("hy_sc_chaekbang/window"), d.world.get_prop_state("hy_sc_chaekbang_meoktong"),
		d.world.get_prop_state("hy_sc_chaekbang_tea")])
	for id in ["ink", "tea", "string", "torn", "window"]: await go(id, 0.6)
	expect(d.case_fn.shop_clues() == 5, "책방 단서 다섯")
	await go("slip", 0.6)
	expect(int(d.S.vars.get("MAIN_PARK_MARK_COUNT", 0)) == 2 and bool(d.S.vars.get("MAIN_PARK_NAME_KNOWN", false)), "v2.2 납품표 — 박규상 표식 +1·이름")
	await shot("shop")
	# S1003 추격
	bot_mode = "stand"   # 처음엔 멈춰 서서 일부러 놓친다(§29 놓침 → 다시 쫓기/발자국)
	prefer = ["다시 쫓는다"] if branch != "R01" else ["발자국을"]
	var fol := func():
		# 놓친 뒤 다시 쫓기면 그다음부터는 따라간다
		while not d.S.is_flag("chase_done") and not d.S.is_flag("chase_lost"):
			await get_tree().process_frame
			if d.get_node_or_null("chase") == null and bot_mode == "stand" and d.runner.last.get("chase", "") == "lost":
				bot_mode = "follow"; _bot_s = -1.0; _shots.clear()
	fol.call()
	d.teleport_to("shop_front", "up")
	var w := 0
	while not d.S.is_flag("woochi_seen") and w < 900:
		await get_tree().process_frame; w += 1
	expect(d.S.is_flag("woochi_seen"), "S1003 골목의 사내")
	await _idle()
	_log("추격 결과 vars=%s flags lost=%s done=%s 막힌 칸 %d %s" % [d.S.vars.get("CASE_HANYANG_OUTCOME"), d.S.is_flag("chase_lost"), d.S.is_flag("chase_done"),
		_blocked, JSON.stringify(_blocked_at.map(func(v): return [snappedf(v.x, 0.1), snappedf(v.y, 0.1)]))])
	if branch == "R01":
		expect(d.S.is_flag("chase_lost"), "놓치고 발자국을 따라감(§29)")
		await walk_to("bridge")
		await _frames(20); await _idle()
	else:
		expect(d.S.is_flag("chase_followed"), "다시 쫓아 끝까지 따라감")
	expect(d.S.is_flag("chase_done"), "S1003 끝(광통교)")
	# S1004
	await go("papers", 1.2)
	expect(bool(d.S.vars.get("MAIN_WOOCHI_KNOWN", false)), "S1004 MAIN_WOOCHI_KNOWN")
	expect(d.S.count("ITM_KEY_002") == 3, "종이 세 장")
	await go("pojol_b", 1.0)
	# S1005
	await walk_to("warehouse_gate")
	await _frames(20); await _idle()
	expect(d.S.is_flag("heard_thump"), "빈 창고의 소리")
	await go("warehouse_gate", 0.8)
	expect(d.S.is_flag("gate_open"), "빗장 벗김")
	await go("chaekkwae", 0.9)
	expect(d.S.is_flag("freed"), "S1005 책쾌 구조")
	var n := 0
	while (d.S.phase != "done" or d.ui.modal or d.runner.busy) and n < 20000:
		await get_tree().process_frame; n += 1
	expect(d.S.phase == "done", "S1006 허브")
	expect(bool(d.S.vars.get("ACT2_OPEN", false)), "S1006 세 갈래 열림")
	expect(bool(d.S.vars.get("SKILL_QUICK_THROW", false)), "v2.2 빠른 투척 열림")
	expect(not d.case_fn.act2_all_done(), "ACT 3 잠김(세 사건 전)")
	expect(d.world.get_prop_state("hy_sc_chaekbang/window") == "SEALED", "책방 다시 엶(뒤창 닫힘)")
	await shot("hub")
	# 소문
	for rid in ["HY_GN_PIMAT", "HY_GJ_JONGNO", "HY_HJ_GWANGTONG"]:
		var r: Dictionary = {}
		for x in Rumors.for_space("GG_HANYANG", d.world.region):
			if x.id == rid: r = x
		expect(not r.is_empty() and Rumors.pick(r, Progress.vars(), d.S.vars) != "", "소문 " + rid)
	await walk_to([-291.0, -884.0])
	var rw := 0
	while not d._rumor_seen.has("HY_GJ_JONGNO") and rw < 240:   # 소문은 0.5초마다 본다(시간 배율 1에서도)
		await get_tree().process_frame; rw += 1
	expect(d._rumor_seen.has("HY_GJ_JONGNO"), "종루에서 경주 소문을 들음")
	# 허브 대화와 §14 갈고리(아직 안 열림)
	prefer = ["강릉", "경주", "황주"]
	await go("chaekkwae", 1.6)
	prefer = []
	expect(not d.S.is_flag("act3_hook"), "§14 갈고리는 세 사건 뒤")
	_log("vars=%s" % JSON.stringify({ o = d.S.vars.CASE_HANYANG_OUTCOME, w = d.S.vars.MAIN_WOOCHI_KNOWN, a2 = d.S.vars.ACT2_OPEN }))
	_log("seen=%s clues=%s" % [JSON.stringify(d.S.seen.keys()), JSON.stringify(d.S.clues)])
	for e in ["S1001", "S1002", "S1003", "S1004", "S1005", "S1006"]:
		expect(d.S.seen.has(e), "장면 " + e)
	Engine.time_scale = 1.0
	if _fails.is_empty(): printerr("STORYTEST PASS hanyang:%s outcome=%s time=%.0fs" % [branch, d.S.vars.CASE_HANYANG_OUTCOME, (Time.get_ticks_msec() - _t0) / 1000.0])
	else: printerr("STORYTEST FAIL hanyang:%s fails=%s" % [branch, JSON.stringify(_fails)])
	d.main._quit()
