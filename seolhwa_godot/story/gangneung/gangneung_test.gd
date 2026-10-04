# 대본 시험(--storytest=gangneung:A|B|C) — 「고개에 남은 종소리」를 한 결말로 끝까지 몰아 본다.
#   출발 저장: story/gangneung/test_post_hanyang.json(남원 C 끝 + 한양 S1006 세 방향 열림)을 user://storytest_progress.json에 깐다.
#   자리로 순간이동해 조사·대화하고(story_test.go), 선택은 결말별 우선 목록. 밤에는 잔영이 보이는지·소리·규칙·경계를 확인한다.
#   --storyshots=폴더면 장면마다 화면을 찍는다. 끝에 STORYTEST PASS/FAIL.
extends "res://scripts/story/story_test.gd"

const Progress := preload("res://scripts/region/progress.gd")
const FIXTURE := "res://story/gangneung/test_post_hanyang.json"
const BELL := "ITM_RIT_006"

var _fps_min := 1000.0
var _fps_sum := 0.0
var _fps_n := 0
var _lead_seen := false
var _night_fps: Array = []

static func prepare(_dir) -> void:
	var j = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not (j is Dictionary): push_error("시험 출발 저장을 읽지 못함: " + FIXTURE); return
	var p := Progress.data()
	p.vars = j.get("vars", {}).duplicate(true)
	p.cases = j.get("cases", {}).duplicate(true)
	p.routes_done = j.get("routes_done", {}).duplicate(true)
	Progress.save()

# 조사 대상 id와 자리 이름이 다르다(socket → stone_socket 등): 대상의 at으로 옮긴 뒤 story_test.go와 같이
func go(id: String) -> void:
	await _idle()
	var p := Vector2.INF
	if d.actors.has(id): p = Vector2(d.actors[id].pos.x, d.actors[id].pos.z)
	else:
		for o in d.data.get("objects", []):
			if String(o.id) == id: p = d.anchor(o.at)
	if p == Vector2.INF: p = d.anchor(id)
	d.teleport_to(Vector2(p.x, p.y + 1.2), "up")
	await _frames(8)
	await _idle()
	d._refresh()
	var ok := false
	for t in d._targets():
		if t.id == id: ok = true
	if not ok:
		_fail("대상 없음/조건 안 맞음: " + id)
		return
	_log("interact " + id)
	d.interact(id)
	await _frames(2)
	await _idle()

func _fps_tick() -> void:
	var f := Engine.get_frames_per_second()
	if f <= 0: return
	_fps_min = minf(_fps_min, f); _fps_sum += f; _fps_n += 1

func _watch_fps() -> void:
	for i in 400000:
		await get_tree().create_timer(0.5, true, false, true).timeout
		if not is_inside_tree(): return
		if d.main._loading: continue
		_fps_tick()
		if d.S.phase == "night" and not d.runner.busy: _night_fps.append(Engine.get_frames_per_second())
		if d.spirits != null and d.spirits.spirit_visible("jy_lead") and not _lead_seen:
			_lead_seen = true; _log("잔영 jy_lead 보임 (%.0f, %.0f)" % [d.spirits.spirits.jy_lead.pos.x, d.spirits.spirits.jy_lead.pos.z])

func _run() -> void:
	_log("시작 branch=%s" % branch)
	_watch_fps()
	expect(String(d.S.vars.get("MAIN_MASTER_TRACE", "")) == "HANYANG", "출발 저장: MAIN_MASTER_TRACE = HANYANG")
	expect(bool(d.S.vars.get("ACT2_OPEN", false)), "출발 저장: 한양 S1006 세 방향 열림")
	# S2001 도착(단오장) → 반정으로
	prefer = ["대관령 반정"]
	await d.runner.run([{ "event": "S2001" }])
	prefer = []
	expect(d.S.is_flag("case_started"), "S2001 사건 기록 생성")
	expect(d.S.has_clue("rumor_bell"), "사라진 방울(소문)")
	await shot("s2001_banjeong")
	await go("jegwan")
	# S2002 제의길 조사(순서 없이)
	for id in ["socket", "lying_stone", "cut_rope", "scratch", "prints"]: await go(id)
	await walk_to(Vector2(-2395.5, 1377.0))
	await shot("s2002_boundary", 40)
	await go("altar")
	await shot("s2002_altar")
	for c in ["moved_stone", "stone_carving", "cut_rope", "scratches", "thief_prints", "missing_offering"]:
		expect(d.S.has_clue(c), "S2002 단서 " + c)
	# S2003 흔적 가르기(짐승 흔적 읽기) → 꾸러미·짚신 → 덕보
	prefer = ["짐승 흔적 읽기"]
	await go("prints")
	prefer = []
	expect(d.S.is_flag("tracks_split") and d.S.knows("R_THIEF_APART"), "S2003 흔적 가르기 → 도둑의 흔적은 따로")
	await go("stash")
	await go("sandals")
	await go("deokbo")
	expect(d.S.is_flag("thief_caught") and d.S.has(BELL), "S2003 덕보 — 방울 회수, 제관에게")
	# S2004 월심 — 호신부, 호신물 칸
	await go("wolsim")
	await shot("s2004_wolsim")
	expect(d.S.is_flag("got_charm"), "S2004 호신부")
	expect(int(d.S.vars.get("ITEM_TALISMAN_SLOT", 0)) == 1, "ITEM_TALISMAN_SLOT = 1")
	expect(d.spirits.equipped("ITM_RIT_001"), "호신부를 지님")
	expect(d.S.has("ITM_RIT_005"), "새 금줄")
	d.ui.journal_show(d.journal_data())
	await shot("journal", 10)
	d.ui.journal_close()
	snapshot("before choice")
	if branch == "B":
		prefer = ["돌려드린다"]
		await go("jegwan")
		prefer = []
	else:
		prefer = ["오늘 밤"]; deny = ["돌려드린다"]
		await go("jegwan")
		prefer = []; deny = []
		expect(d.S.is_flag("keep_bell"), "방울을 들고 밤에 오르기로")
		prefer = ["밤을 기다리"]
		await go("jumo_bj")
		prefer = []
		expect(d.S.phase == "night", "S2005 반정에서 밤")
		# 같은 길을 다시 오른다: 반정 → 고갯길 → 경계석 앞(소리·잔영)
		for p in [[-2134.0, 1428.0], [-2206.0, 1415.0], [-2285.0, 1422.0], [-2318.0, 1422.0], [-2340.0, 1412.0]]:
			await walk_to(Vector2(p[0], p[1]))
			await _frames(90)
		await shot("s2005_night_road")
		await walk_to("approach")
		await _frames(60); await _idle()
		await _frames(120)
		expect(d.S.knows("R_SOUND_LEADS"), "S2005 방울 소리는 경계석으로")
		expect(d.S.knows("R_FAINT_OUT"), "S2006 경계석 밖에선 희미")
		expect(d.spirits.spirit_visible("jy_stone"), "경계석 곁 잔영이 (희미하게) 보임")
		var op_out: float = d.spirits.spirits.jy_stone.op
		await shot("s2006_outside")
		await walk_to("socket_stand")
		await _frames(60); await _idle(); await _frames(120)
		var op_in: float = d.spirits.spirits.jy_stone.op
		_log("잔영 진하기 밖 %.2f → 안 %.2f" % [op_out, op_in])
		expect(d.S.knows("R_CLEAR_IN") and op_in > op_out + 0.2, "S2006 경계석 안에선 또렷")
		await shot("s2006_inside")
		if branch == "A":
			prefer = ["방울을 옛 자리", "누운 경계석"]
		else:
			prefer = ["칼을 뽑아"]
		_watch_shots_g()
		await go("socket_night")
		prefer = []
		if branch == "A": expect(d.S.knows("R_BELL_HOME"), "S2006 방울이 제자리 가까이 가면 소리가 멎음")
	var waited := 0
	while (d.S.phase != "done" or d.ui.modal or d.runner.busy) and waited < 20000:
		await get_tree().process_frame; waited += 1
		if waited % 600 == 0: _log("기다리는 중 phase=%s busy=%s" % [d.S.phase, d.runner.busy])
	snapshot("end")
	await shot("after", 40)
	var o := String(d.S.vars.get("CASE_GANGNEUNG_OUTCOME", ""))
	expect(o == branch, "결말 %s (얻은 값 %s, %s)" % [branch, o, d.S.vars.get("CASE_GANGNEUNG_DETAIL", "")])
	var tr := String(d.S.vars.get("MAIN_MASTER_TRACE", ""))
	expect(tr.contains("GANGNEUNG") and tr.contains("HANYANG"), "S2008 MAIN_MASTER_TRACE += GANGNEUNG (%s)" % tr)
	for e in ["S2001", "S2002", "S2003", "S2004", "S2007", "S2008"]: expect(d.S.seen.has(e), "장면 " + e)
	if branch != "B": expect(d.S.seen.has("S2005") and d.S.seen.has("S2006"), "장면 S2005·S2006")
	# 지역 변화(§30)
	match branch:
		"A": expect(d.props.has("p_restored") and d.props.p_restored.get("want", false), "A: 경계석·새 금줄·방울이 제자리")
		"B": expect(d.props.has("p_lying") and d.props.p_lying.get("want", false), "B: 경계석은 누운 채")
		"C": expect(d.runner.cond("ph('done') and out('C')"), "C: 밤마다 방울 소리(bell_after 조건)")
	expect(d.actors.has("crowd_a") and d.actors.crowd_a.shown, "단오장이 선다(장꾼)")
	expect(d.actors.has("deokbo_bound") and d.actors.deokbo_bound.shown, "덕보 체포(반정)")
	# 해결 뒤 밤: A면 잔영이 없고, B·C면 경계석 곁에 희미하게 남는다
	d.set_hour(22.5)
	d.teleport_to("approach", "up")
	await _frames(90)
	d.spirits.update(0.3)
	var left: bool = d.spirits.spirits.jy_stone.want
	expect(left == (branch != "A"), "해결 뒤 밤의 잔영 %s" % ("없음" if branch == "A" else "남음"))
	if branch == "C":
		var heard := false
		for s in d.spirits.sounds:
			if s.id == "bell_after":
				s._t = 0.0; heard = true
		d.spirits.update(0.1)
		expect(heard, "C: 해결 뒤 밤 방울 소리")
	_log("vars=%s" % JSON.stringify({ o = o, detail = d.S.vars.get("CASE_GANGNEUNG_DETAIL"), trace = tr, slot = d.S.vars.get("ITEM_TALISMAN_SLOT"), eq = d.S.vars.get("TALISMAN_EQUIPPED") }))
	_log("seen=%s" % JSON.stringify(d.S.seen.keys()))
	_fps_tick()
	_log("fps min=%.0f avg=%.0f (n=%d) lead_seen=%s" % [_fps_min, _fps_sum / maxf(1.0, _fps_n), _fps_n, _lead_seen])
	if not _night_fps.is_empty():
		var nf: Array = _night_fps.duplicate(); nf.sort()
		_log("밤 고갯길 fps min=%d median=%d (n=%d)" % [nf[0], nf[nf.size() / 2], nf.size()])
	Engine.time_scale = 1.0
	if _fails.is_empty(): printerr("STORYTEST PASS gangneung:%s outcome=%s detail=%s time=%.0fs" % [branch, o, d.S.vars.get("CASE_GANGNEUNG_DETAIL", ""), (Time.get_ticks_msec() - _t0) / 1000.0])
	else: printerr("STORYTEST FAIL gangneung:%s fails=%s" % [branch, JSON.stringify(_fails)])
	d.main._quit()

# 아침 모시기·결말 카드를 찍는 감시
func _watch_shots_g() -> void:
	var morning := false
	for i in 200000:
		await get_tree().process_frame
		if not morning and d.S.phase == "morning" and d.ui.modal:
			morning = true; await shot("morning", 2)
		if d.ui._ending.visible and d.ui._ending.modulate.a > 0.95:
			await shot("ending", 1); return
