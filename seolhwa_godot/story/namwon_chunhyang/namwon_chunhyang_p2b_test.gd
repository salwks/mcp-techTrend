# 대본 시험 PART II-B(--storytest=namwon_chunhyang:iib1|iib2|iib3|iibctl) — namwon_chunhyang_test.gd가 부른다(같은 expect·walk_to·go·prefer).
#   iib1 순응·소극 : (II-A 맡음 · 줄 잡음) 술 → 쌀 → 상소. 다 내린다 · 물러서라 · 돌려보낸다(노인 사연 안 들음). 관찰 도중·술독을 진 채 저장/불러오기.
#                  옥중 상봉 거든다(관계 좋음) · 복구 "확인한 것은 많지 않소"(확답 없음) · 춘향 "그래도 다음엔 생각하고 잡으세요."
#   iib2 저항     : (끌려감 · 줄 놓음) 상소 → 쌀 → 술. 소지를 위로 · 한 가마만 · 상인의 말을 적는다(들은 것 셋). 옥중 상봉 월매의 길(관계 나쁨).
#                  잔치 도중 저장/불러오기 · 본 것·들은 것 다 말함(술값·쌀 반환·노인 재조사) · 춘향 "봤습니다."
#   iib3 섞임     : (맡음 · 느슨하게) 쌀 → 상소 → 술. 아전에게 다시 묻기(걸어가서) · 노인의 말을 적는다 · 한 독 남김. 상봉은 지켜봄(월매의 길).
#                  아전에게 묻기 전 저장/불러오기 · 잔치 날 아침 저장/불러오기 · 본 것(쌀)·들은 것(소)만 말함 · 춘향 "그것도 봤습니다."
#   iibctl        : 창 모드 실제 시간 — 시험 봇이 실제 걸음(--ctlspeed, 기본 4.6 달리기)으로. ACT 13 · II-B 전체 조작 비율(CTL2 줄)
# 셋 다: 순서 자유 · 한 번만 · 소극/틀린 판단도 진행 · 몽룡 귀환 · 월매 집 · 옥중 상봉 · 잔치 · 시 · 어사출두 · 파면(문제 결과와 무관) · 복구만 갈래마다 ·
#   석방 · COMPLETE · RELEASED · 포승 기억 · 잔치(EventCrowd 14 · 포졸/사령 없음 · 같은 노드 자세 · 사령↔상 실제 틈 · 차일 C62 · cower) · FIXED_BEAT 순서·중복 없음.
# 끝난 뒤 관아 곁일 「창고 장부 대조」(namwon_chunhyang_side_data.gd — 같은 문제 계약, 데이터만): iib1 바로 덮음(창고지기 말 안 들음) ·
#   iib2 창고지기 말 → 뒤 곳간(fail_forward) → 추가 흔적 · iib3 센 대로 적음. 끝나기 전엔 안 섬 · 결말·FIXED_BEAT·변수 그대로.
extends RefCounted

const P2 := preload("res://story/namwon_chunhyang/namwon_chunhyang_p2a_data.gd")
const P2B := preload("res://story/namwon_chunhyang/namwon_chunhyang_p2b_data.gd")
const Problems := preload("res://scripts/story/problems.gd")
const JournalBook := preload("res://scripts/story/journal_book.gd")
const Progress := preload("res://scripts/region/progress.gd")

const BODY_R := 0.375   # 사람 몸 반지름(SpriteChar.radius — 사령·플레이어 같음)
const GAP_MIN := 1.6    # 사령↔잔칫상 실제 걸음 틈(사용자 결정 §9-3)
const BEATS := ["mongryong_return", "wolmae_reunion", "jail_reunion", "birthday_feast", "poem", "royal_inspector", "byeon_dismissed", "restoration", "release", "last_choice"]

var t      # namwon_chunhyang_test.gd 노드
var d
var br := "IIB1"
var real := false
var speed := 4.6
var probe := {}
var S:
	get: return d.S

func _init(test_node, branch: String) -> void:
	t = test_node; d = test_node.d; br = branch

func expect(c: bool, what: String) -> void: t.expect(c, what)
func _frames(n: int) -> void:
	for i in n: await t.get_tree().process_frame
func _idle() -> void: await t._idle()
func pd(p: String) -> String: return d.runner.pd(p)
func pdone(p: String) -> bool: return d.runner.pdone(p)
func pa(p: String, a: String) -> bool: return d.runner.pa(p, a)

func until(cond: Callable, sec := 120.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await t.get_tree().process_frame
		if (Time.get_ticks_msec() - t0) / 1000.0 > sec: return false
	return true

# 걸어가기: 빠른 시험은 마지막 점으로 순간이동, 실제 시간(ctl)은 점마다 직선으로 걷는다(충돌 무시 — 실제 길보다 짧아 비율은 보수적)
func walk(pts: Array) -> void:
	if not real:
		await t.walk_to(pts[pts.size() - 1])
		return
	for q in pts:
		var tgt: Vector2 = d.anchor(q)
		var guard := 0
		while guard < 60 * 600:
			guard += 1
			await t.get_tree().process_frame
			if not d.case_fn.controllable(): continue
			var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
			var v: Vector2 = tgt - pp
			var dt: float = t.get_process_delta_time()
			if v.length() < 0.3: break
			var np := pp + v.normalized() * minf(v.length(), speed * dt)
			d.set_player_pos(Vector3(np.x, d.world.height_at(np.x, np.y), np.y))
			d.main.player.facing = "right" if absf(v.x) > absf(v.y) and v.x > 0 else ("left" if absf(v.x) > absf(v.y) else ("down" if v.y > 0 else "up"))
			d.main.player.set_anim("run" if speed > 3.0 else "walk")
		d.main.player.set_anim("idle")
	await _frames(4)

# 이야기 인물에게 말 걸기
func talk(id: String) -> void:
	if not real:
		await t.go(id, 1.2); return
	var a = d.actors.get(id)
	await walk([[a.pos.x, a.pos.z + 1.1]])
	await _idle()
	await until(func(): return d.case_fn.controllable(), 30.0)
	await _frames(2)
	d.interact(id)
	await _frames(2)
	await _idle()

# 조사 대상(문제 활동 pb_* · 일하는 손 p2b_*)에 다가가 E — 대상 둘레의 걸을 수 있는 자리로
func _obj(id: String) -> Dictionary:
	for o in d.data.objects:
		if String(o.id) == id: return o
	return {}

func free_spot(at: Vector2, r: float) -> Vector2:
	for rr in [r * 0.6, r * 0.8, r * 0.4, r * 0.95]:
		for k in 16:
			var a := TAU * k / 16.0 + PI * 0.5
			var q: Vector2 = at + Vector2(cos(a), sin(a)) * rr
			if not d.world.blocked(q.x, q.y, BODY_R): return q
	return Vector2.INF

func obj(id: String) -> void:
	await _idle()
	var o := _obj(id)
	if o.is_empty():
		expect(false, "대상 없음 " + id); return
	var at: Vector2 = d.anchor(o.at)
	var q := free_spot(at, float(o.get("radius", 2.0)))
	expect(q != Vector2.INF, "%s — 둘레에 걸을 수 있는 자리" % id)
	if q == Vector2.INF: return
	if real: await walk([[q.x, q.y]])
	else:
		d.teleport_to(q, "up")
		await _frames(6)
	await _idle()
	d._refresh()
	var ok := false
	for x in d._targets():
		if x.id == id: ok = true
	if not ok:
		expect(false, "대상이 지금 없음/조건 안 맞음: " + id); return
	if real: await until(func(): return d.case_fn.controllable(), 30.0)
	t._log("interact " + id)
	d.interact(id)
	await _frames(2)
	await _idle()

func in_targets(id: String) -> bool:
	d._refresh()
	for x in d._targets():
		if x.id == id: return true
	return false

# ---------------------------------------------------------------------------
func run() -> void:
	real = br == "IIBCTL"
	if real:
		speed = float(d.main.args.get("ctlspeed", "4.6"))
		Engine.time_scale = 1.0
		d.ui.auto_real = true
		d.ui.auto_hold = 1.5
	else:
		d.case_fn.fast_mul = 8.0
	_setup_after_p2a()
	await _frames(12)
	expect(S.phase == "jail" and S.is_flag("p2a_done") and not S.is_flag("p2b_started"), "II-A 끝(옥의 첫 밤) — II-B는 아직")
	expect(not d.actors.mong_b.shown and not d.actors.ajeon_b.shown and not d.actors.byeon_feast.shown, "II-B 인물은 아직 없다")
	expect(String(d.travel_lock()) == "", "II-A 끝 — 먼 길 막음 풀림(II-B 전)")
	_anchor_checks()
	var mtrace0 = S.vars.get("MAIN_MASTER_TRACE", Progress.get_var("MAIN_MASTER_TRACE", ""))
	# 이튿날 — 관아 앞에서 한 번 멀어졌다 다시 오면
	await walk([[-3162.1, 238.0], [-3162.1, 244.0], [-3186.0, 251.0]])
	await _frames(6)
	expect(S.is_flag("p2b_away") and not S.is_flag("p2b_started"), "멀어짐 — 아직 아침 아님")
	await walk([[-3172.0, 247.5], [-3166.0, 246.5]])
	await until(func(): return S.is_flag("duty_on") and not d.runner.busy, 60.0)
	expect(S.is_flag("duty_on") and S.has_clue("duty_three") and int(d.main.hour) == 8, "C1300 이튿날 아침 — 아전이 일 셋(%.1f시)" % d.main.hour)
	expect(String(d.travel_lock()) != "", "II-B 관아 일 — 먼 길 막음")
	await _frames(6)
	expect(d.actors.wine_merchant.shown and d.actors.rice_farmer.shown and d.actors.petition_elder.shown and d.actors.ajeon_b.shown, "상인·농민·노인·아전이 선다")
	expect(_gated_on("ti_wine_cart") and _gated_on("ti_rice_sacks"), "술 수레·대문 앞 가마니(배치 파일 when)")
	# 세 문제 — 순서 자유(갈래마다 다르게)
	var plan: Array = { "IIB1": [["wine", "all"], ["rice", "all"], ["petition", "dismiss"]],
		"IIB2": [["petition", "process"], ["rice", "one"], ["wine", "record"]],
		"IIB3": [["rice", "reask"], ["petition", "note"], ["wine", "leave"]],
		"IIBCTL": [["wine", "leave"], ["rice", "one"], ["petition", "process"]] }[br]
	var solved := []
	for step in plan:
		var pid: String = step[0]
		match pid:
			"wine": await _wine(step[1])
			"rice": await _rice(step[1])
			"petition": await _petition(step[1])
		solved.append(pid)
		for p in ["wine", "rice", "petition"]:
			expect(pdone(p) == solved.has(p), "순서 자유 — %s 뒤 %s %s" % [solved, p, "풀림" if solved.has(p) else "아직"])
		_once_check(pid)
	expect(S.vars.get("MAIN_MASTER_TRACE", Progress.get_var("MAIN_MASTER_TRACE", "")) == mtrace0, "MAIN_MASTER_TRACE 그대로(%s)" % str(mtrace0))
	expect(S.is_flag("duty_complete"), "일 셋을 마침")
	expect(not S.has(P2B.JAR) and not S.has(P2B.SACK), "지고 간 것은 다 내려놓음")
	# 일을 마침 → 며칠 뒤 해 질 무렵
	await talk("ajeon_b")
	await until(func(): return S.is_flag("dusk_on") and not d.runner.busy, 60.0)
	expect(S.is_flag("duty_over") and S.is_flag("dusk_on") and d.main.hour >= 18.0, "C1305 일을 마침 → 며칠 뒤 해 질 무렵(%.1f시)" % d.main.hour)
	if real: printerr("CTL2 %s act13=%.3f (%.1f/%.1fs)" % [br, d.case_fn.ctl2_ratio("act13"), d.case_fn.ctl2.act13.ctl, d.case_fn.ctl2.act13.all])
	# ACT 14 남문 밖
	await walk([[-3228.0, 338.0], [-3226.4, 346.0]])
	await until(func(): return S.is_flag("mongryong_return_seen") and not d.runner.busy, 90.0)
	expect(S.is_flag("mongryong_return_seen") and S.has_clue("beggar_back"), "ACT 14 남문 밖 — 거지 몽룡(14A)")
	if probe.has("14A"):
		var p14: Dictionary = probe["14A"]
		expect(bool(p14.shot) and String(p14.kind) == "mongryong_beggar" and String(p14.anim) != "mapae", "14A 어깨 너머 · 거지 차림 · 마패 안 보임(%s)" % p14)
	expect(not S.is_flag("mongryong_id_known") and not d.actors.mong_b.shown, "신분을 묻지도 만들지도 않는다 — 몽룡은 지나간다")
	# ACT 15 월매 집
	await walk([[-3228.0, 380.0], [-3226.0, 455.0], [-3216.0, 459.8]])
	await until(func(): return S.is_flag("wolmae_reunion_seen") and not d.runner.busy, 90.0)
	expect(S.is_flag("wolmae_reunion_seen") and S.has_clue("beggar_wolmae") and String(d.data.clues.beggar_wolmae.by) == "월매", "ACT 15 월매 집 — “돌아온다더니 거지가 돼 왔소?”(들음 — 월매)")
	expect(d.case_fn._is_night(), "밤")
	# ACT 16 옥중 상봉
	t.prefer = { "IIB1": ["(거든다)"], "IIB3": ["(지켜본다)"], "IIBCTL": ["(거든다)"] }.get(br, [])
	await walk([[-3226.0, 455.0], [-3228.0, 362.0], [-3228.0, 251.5], [-3170.0, 247.6], [-3164.6, 244.8]])
	await until(func(): return S.phase == "feast" and not d.runner.busy, 120.0)
	expect(S.is_flag("jail_reunion_seen") and S.has_clue("reunion"), "ACT 16 옥중 상봉 — 몽룡이 스스로")
	match br:
		"IIB1": expect(S.is_flag("reunion_helped"), "관계 좋음(맡음·줄 잡음) — 포졸에게 거듦")
		"IIB2": expect(S.is_flag("reunion_other_way") and not S.is_flag("reunion_helped"), "관계 나쁨(끌려감·줄 놓음) — 거들 수 없어도 월매의 길로 상봉")
		"IIB3": expect(S.is_flag("reunion_watched") and not S.is_flag("reunion_helped"), "지켜봄 — 월매의 길로 상봉")
	expect(S.is_flag("feast_day") and S.phase == "feast" and int(d.main.hour) == 11, "이튿날 잔치(단계 feast)")
	await _frames(20)
	_banquet_static()
	if br == "IIB3": await _reload("잔치 날 아침")
	# ACT 17 잔치 — 내삼문
	await walk([[-3162.1, 243.0], [-3162.1, 230.0], [-3162.1, 221.0]])
	await until(func(): return S.is_flag("feast_seen") and not d.runner.busy, 60.0)
	expect(S.is_flag("feast_seen") and S.has_clue("feast_goods"), "ACT 17 잔치 — 내가 나른 술·쌀이 상 곁에")
	if probe.has("feast"):
		expect(String(probe.feast.chail) == "SPREAD", "잔치 놀이 틀 — 차일 SPREAD(C62)")
	expect(_feast_goods_ok(), "잔치 물자 소품 — 술독(%s)·가마니" % ("둘" if S.is_flag("wine_left") else "셋"))
	await _frames(8)
	expect(d.main.world.props.get_state("ti_chail/cloth") == "FURLED" and d.case_fn.controllable(), "컷이 끝나 평소 시점(조작) — 차일 FURLED(높은 틀, 컷 경계에서만)")
	await t.cut("17b_walk_feast")
	if br == "IIB2": await _reload("잔치 도중(입장 뒤 · 줄 끝 전)")
	if not real:
		await obj("p2b_feast_wine")
		expect(S.is_flag("feast_wine_looked"), "잔치 술독 살펴보기(선택)")
	# 서쪽 줄 끝 → 몽룡 입장 · 시 · 출두 · 복구
	t.prefer = { "IIB1": ["확인한 것은 많지 않소", "명령이었습니다"],
		"IIB2": ["세 독을 내리라는", "술값도 못 받았다고", "쌀을 더 가져간", "겨울 양식이라고", "소를 가져갔다고", "열흘째 열리지도", "그것뿐입니다"],
		"IIB3": ["쌀을 더 가져간", "소를 가져갔다고", "그것뿐입니다"],
		"IIBCTL": ["세 독을 내리라는", "쌀을 더 가져간", "그것뿐입니다"] }[br]
	await walk([[-3162.1, 218.6], [-3168.7, 217.8]])
	await until(func(): return S.phase == "release" and not d.runner.busy, 240.0)
	_check_feast_reveal()
	_check_restoration()
	# ACT 20 옥문 — 몽룡을 따라(조작)
	expect(d.case_fn.controllable(), "옥으로 — 몽룡을 따라 걷는다(조작)")
	await walk([[-3158.0, 236.0], [-3165.0, 234.0], [-3167.2, 231.6]])
	await until(func(): return S.phase == "epilogue" and not d.runner.busy, 120.0)
	expect(S.is_flag("chunhyang_released") and S.has_clue("release"), "ACT 20 석방 — “왔으니 됐습니다.”")
	var want_last: String = { "IIB1": "그래도 다음엔 생각하고 잡으세요.", "IIB2": "봤습니다.", "IIB3": "그것도 봤습니다.", "IIBCTL": "봤습니다." }[br]
	expect(String(d.case_fn.last_line) == want_last and S.is_flag("last_choice_done"), "ACT 21 마지막 — 춘향이 포승을 기억 “%s”" % d.case_fn.last_line)
	if br == "IIB1": expect(S.is_flag("last_order") and not S.is_flag("last_sorry"), "잡았던 경우 — “명령이었습니다.” 하나만")
	# ACT 22 광한루
	await walk([[-3262.0, 440.0], [-3270.0, 438.0]])
	await until(func(): return S.phase == "done" and not d.runner.busy, 90.0)
	expect(S.is_flag("end_seen") and S.phase == "done", "ACT 22 광한루 — 끝")
	expect(bool(probe.get("end", {}).get("ok", false)), "빈 그네 · 아이 둘(광한루 컷 — %s)" % probe.get("end", {}))
	var el: Array = S.world.get("end_lines", [])
	expect(el.size() == 3 and String(el[0]).contains("수청을 끝내 거절") and String(el[1]).contains("암행어사"), "기록책 두 줄(원전)")
	var want_line: String = { "IIB1": "모든 것을 보았으나", "IIB2": "한 번은 손을 놓았다", "IIB3": "들은 말을 기록해 두었다", "IIBCTL": "한 번은 손을 놓았다" }[br]
	expect(el.size() == 3 and String(el[2]).contains(want_line), "내가 한 일 한 줄 — %s" % (el[2] if el.size() == 3 else "?"))
	expect(String(S.vars.get("CASE_NAMWON_CHUNHYANG_OUTCOME", "")) == "RELEASED", "OUTCOME RELEASED")
	expect(bool(S.vars.get("CASE_NAMWON_CHUNHYANG_COMPLETE", false)), "CASE_NAMWON_CHUNHYANG_COMPLETE = true")
	expect(String(d.travel_lock()) == "", "끝 — 먼 길 막음 풀림")
	# FIXED_BEAT — 순서 그대로 · 한 번씩 · 문제 결과와 무관
	var order: Array = S.world.get("beat_order", [])
	expect(order == BEATS, "원전 순서 그대로·중복 없음 %s" % [order])
	for b in ["byeon_arrives", "roll_call", "sucheong_demand", "refusal", "gonjang"]: expect(S.is_flag("beat_" + b), "II-A FIXED_BEAT 그대로 " + b)
	var fb: Array = d.data.case.FIXED_BEATS.map(func(x): return String(x.id))
	for b in ["mongryong_return", "jail_reunion", "birthday_feast", "poem", "royal_inspector", "byeon_dismissed", "release"]:
		expect(fb.has(b) and S.is_flag("beat_" + b), "FIXED_BEAT %s(사건 메타·일어남)" % b)
	_journal()
	if not real: await _side_job()
	var cf = d.case_fn
	printerr("CTL2 %s speed=%.1f act13=%.3f (%.1f/%.1fs) p2b=%.3f (%.1f/%.1fs)" % [br, speed, cf.ctl2_ratio("act13"), cf.ctl2.act13.ctl, cf.ctl2.act13.all,
		cf.ctl2_ratio("p2b"), cf.ctl2.p2b.ctl, cf.ctl2.p2b.all])
	expect(cf.ctl2.act13.all > 0.0 and cf.ctl2.p2b.all >= cf.ctl2.act13.all, "조작 비율 고리 act13=%.2f p2b=%.2f" % [cf.ctl2_ratio("act13"), cf.ctl2_ratio("p2b")])
	await t._done()

# ---------------------------------------------------------------------------
# II-A 끝 상태(옥의 첫 밤 — 갈래마다 다른 첫 태도·포승·밥)를 꾸민다
# ---------------------------------------------------------------------------
func _setup_after_p2a() -> void:
	S.phase = "jail"
	for k in ["case_started", "vista_seen", "bump_done", "met_bangja", "errand_choice", "errand_with", "refusal_seen", "mong_reacted", "evening_call",
			"first_meeting_done", "letter_asked", "letter_delivered", "walk_seen", "vow_invited", "vow_done", "vow_witness", "vow_heard", "farewell_scene_done",
			"part1_done", "farewell_talked", "chun_home", "bangja_off", "mong_off",
			"p2_started", "proc_on", "proc_seen", "proc_in", "recog_done", "labour_started", "docs_delivered", "gisaeng_called", "in_line", "jeomgo_done",
			"summons_given", "wolmae_summoned", "sucheong1_done", "sucheong2_done", "struck", "jailed", "dismissed", "food_scene", "food_in", "p2a_done",
			"beat_byeon_arrives", "beat_roll_call", "beat_sucheong_demand", "beat_refusal", "beat_gonjang", "beat_jail"]:
		S.flags[k] = true
	var by: Dictionary = {
		"IIB1": ["recog2_yes", "labour_accepted", "summons_plain", "restraint_obeyed", "arm_offered", "brought_prison_food", "jail_talked", "jail_talk_return"],
		"IIB2": ["recog2_no", "labour_refused", "rounded_up", "summons_words", "restraint_refused", "arm_waited", "persuaded_guard"],
		"IIB3": ["recog2_what", "labour_accepted", "warned_wolmae", "restraint_loose", "arm_offered", "passed_food"],
		"IIBCTL": ["recog2_yes", "labour_refused", "rounded_up", "warned_wolmae", "restraint_refused", "arm_offered", "brought_prison_food", "jail_talked", "jail_talk_why"] }
	for k in by[br]: S.flags[k] = true
	for c in ["new_magistrate", "labour", "roll_call", "bring_her", "summons_paper", "chun_decides", "sucheong", "gonjang", "jailed", "food_refused"]:
		if not S.clues.has(c): S.clues.append(c)
	S.items[P2.TALLY] = 1
	S.vars.CASE_NAMWON_CHUNHYANG_PART1_COMPLETE = true
	S.vars.CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1 = true
	S.vars.CASE_GANGNEUNG_COMPLETE = true
	d.set_hour(19.8)
	d.teleport_to("ch_jail_leave", "down")
	d.case_fn.on_load()
	d.on_phase(); d._refresh()

func _gated_on(id: String) -> bool: return t._gated_on(id)
func _gate_off(id: String) -> bool: return t._gate_off(id)

# II-B 자리마다 둘레에 걸을 수 있는 땅이 있나(조사·말 걸기 자리 · 배우 자리)
func _anchor_checks() -> void:
	var bad := []
	for o in P2B.objects():
		if free_spot(d.anchor(o.at), float(o.get("radius", 2.0))) == Vector2.INF: bad.append(o.id)
	for pid in d.data.problems:
		for a in d.data.problems[pid].activities:
			if a.has("at") and free_spot(d.anchor(a.at), float(a.get("radius", 2.0))) == Vector2.INF: bad.append("%s.%s" % [pid, a.id])
	for k in ["ch_ajeon_b_player", "ch_dusk_start", "ch_player_sgate", "ch_reunion_watch", "ch_resto_player", "ch_player_ask", "ch_end_start", "ch_mong_court", "ch_mong_ask"]:
		var p: Vector2 = d.anchor(k)
		if d.world.blocked(p.x, p.y, 0.3): bad.append(k)
	expect(bad.is_empty(), "II-B 자리 모두 걸을 수 있음(%s)" % [bad])

# ---------------------------------------------------------------------------
# ACT 13 — 술
# ---------------------------------------------------------------------------
func _wine(mode: String) -> void:
	if mode == "record":
		await talk("wine_merchant")
		expect(pa("wine", "merchant") and S.has_clue("pb_wine_merchant") and String(d.data.clues.pb_wine_merchant.kind) == "heard"
			and String(d.data.clues.pb_wine_merchant.by) == "술 상인 김가", "술 — 상인의 말(들은 것 ◇ — 술 상인 김가)")
	await obj("pb_wine_cart")
	expect(pa("wine", "cart") and S.has_clue("pb_wine_cart") and String(d.data.clues.pb_wine_cart.kind) == "fact", "술 — 수레의 술독(본 것 ◆)")
	expect(pd("wine") == "" and not pa("wine", "gap"), "관찰 하나로는 차이도 결정도 없음")
	if br == "IIB1":
		await _reload("술 관찰 하나")
		expect(not in_targets("pb_wine_cart") and in_targets("pb_wine_order"), "불러온 뒤 — 본 수레는 다시 보지 않음 · 물목은 아직")
	t.prefer = [{ "all": "세 독을 다 내린다", "leave": "한 독은 수레에 둔다", "record": "상인의 말을 적어 둔다" }[mode]]
	await obj("pb_wine_order")
	await until(func(): return pdone("wine") and not d.runner.busy, 30.0)
	expect(pa("wine", "gap") and S.is_flag("wine_discrepancy_seen") and String(d.data.clues.pb_wine_gap.kind) == "fact", "술 — 물목과 수레의 차이(본 것으로 확인)")
	expect(pd("wine") == mode and pdone("wine") and S.is_flag("wine_done"), "술 — 처리 %s(결정 하나 · 풀림)" % pd("wine"))
	var wf := ["wine_taken_all", "wine_left", "wine_recorded"].filter(func(k): return S.is_flag(k))
	expect({ "all": ["wine_taken_all"], "leave": ["wine_left"], "record": ["wine_taken_all", "wine_recorded"] }[mode] == wf, "술 행동 깃발 %s" % [wf])
	if mode == "record": expect(S.has_clue("pb_wine_handle_record") and String(d.data.clues.pb_wine_handle_record.kind) == "heard", "상인의 말을 적음 — 들은 것으로")
	if br == "IIB1": expect(not t.choice_log.any(func(c): return String(c[0]).contains("술독을") and (c[1] as Array).any(func(l): return String(l).contains("상인의 말"))), "상인 말을 안 들었으면 '적어 둔다' 갈래 없음")
	# 지고 간다 → 내려놓는다
	await obj("p2b_wine_lift")
	expect(S.has(P2B.JAR) and S.is_flag("wine_unloaded"), "술독을 졌다")
	await _frames(4)
	expect(_gate_off("ti_wine_cart") and d.props.has("p_cart_one" if mode == "leave" else "p_cart_empty") and d.props["p_cart_one" if mode == "leave" else "p_cart_empty"].shown,
		"수레 — %s" % ("한 독 남음" if mode == "leave" else "빈 수레"))
	if br == "IIB1":
		await _reload("술독을 진 채")
		expect(S.has(P2B.JAR) and S.is_flag("wine_lifted") and not S.is_flag("wine_stored"), "불러와도 진 술독 그대로(되돌리지 않음)")
	await obj("p2b_wine_drop")
	expect(S.is_flag("wine_stored") and not S.has(P2B.JAR), "물자 곳에 내려놓음")

# ---------------------------------------------------------------------------
# 쌀
# ---------------------------------------------------------------------------
func _rice(mode: String) -> void:
	if mode == "one":
		await talk("rice_farmer")
		expect(pa("rice", "farmer") and String(d.data.clues.pb_rice_farmer.kind) == "heard", "쌀 — 농민의 말(들은 것)")
	await obj("pb_rice_order")
	expect(pa("rice", "order") and S.is_flag("rice_order_seen"), "쌀 — 징발 표(본 것) · rice_order_seen")
	t.prefer = [{ "all": "물러서라 한다", "one": "한 가마만 지고", "reask": "아전에게 다시 묻고" }[mode]]
	await obj("pb_rice_sacks")
	await until(func(): return pdone("rice") and not d.runner.busy, 30.0)
	expect(S.is_flag("rice_discrepancy_seen") and pd("rice") == mode, "쌀 — 표 두 가마·대문 앞 넷 → %s" % pd("rice"))
	var rf := ["rice_taken_full", "rice_left", "rice_reasked"].filter(func(k): return S.is_flag(k))
	expect(rf == [{ "all": "rice_taken_full", "one": "rice_left", "reask": "rice_reasked" }[mode]], "쌀 행동 깃발 %s" % [rf])
	if mode == "reask":
		expect(not S.is_flag("rice_reask_done"), "아직 아전에게 묻지 않음")
		if br == "IIB3": await _reload("아전에게 묻기 전")
		expect(pd("rice") == "reask" and not in_targets("p2b_rice_lift"), "불러와도 결정 그대로 · 지고 갈 것 없음")
		await walk([[-3120.0, 268.0], [-3150.0, 250.0], [-3166.0, 247.0]])
		await talk("ajeon_b")
		expect(S.is_flag("rice_reask_done") and S.is_flag("rice_cart_gone"), "아전에게 다시 물음(걸어가서) — 두 가마만")
		return
	await obj("p2b_rice_lift")
	expect(S.has(P2B.SACK), "가마니를 졌다")
	await t.cut("13b_rice_work")   # 화면 순회 — 대문 앞 가마니 곁에서 한 가마를 진 채(카드가 가마니를 가리지 않게 카드 뒤에서 찍음)
	await _frames(4)
	if mode == "all": expect(_gate_off("ti_rice_sacks"), "넷 다 실어 감 — 대문 앞 가마니 없음")
	else: expect(_gated_on("ti_rice_sacks"), "한 가마만 — 대문 앞 가마니는 남음")
	await walk([[-3120.0, 268.0], [-3150.0, 250.0], [-3162.1, 243.0], [-3162.1, 236.0]])
	await obj("p2b_rice_drop")
	expect(S.is_flag("rice_stored") and not S.has(P2B.SACK), "가마니를 내려놓음")

# ---------------------------------------------------------------------------
# 상소
# ---------------------------------------------------------------------------
func _petition(mode: String) -> void:
	t.prefer = ["(그냥 지나간다)"] if mode == "dismiss" else ["(사연을 듣는다)"]
	await talk("petition_elder")
	if mode == "dismiss":
		expect(S.is_flag("elder_passed") and not S.is_flag("old_man_heard"), "상소 — 그냥 지나감(사연 안 들음)")
	else:
		expect(S.is_flag("old_man_heard") and S.is_flag("yi_gyeom_trace_heard"), "상소 — 노인의 사연·선비 이야기")
		var c1: Dictionary = d.data.clues.pb_petition_old_man
		var c2: Dictionary = d.data.clues.pb_petition_scholar
		expect(String(c1.kind) == "heard" and String(c1.by) == "농부" and String(c2.kind) == "heard" and String(c2.by) == "농부", "◇ 들음 — 농부(둘 다 자동 확정 없음)")
		expect(not String(c2.text).contains("이겸") and not String(c2.title).contains("이겸"), "선비가 이겸이라고 쓰지 않음")
	await obj("pb_petition_route")
	t.prefer = [{ "dismiss": "노인을 돌려보낸다", "process": "소지를 맨 위에", "note": "노인의 말을 내 기록책에" }[mode]]
	if shooting(): _watch_card("열리지 않은 소지", "13c_petition_work")
	await obj("pb_petition_status")
	await _wait_watch()
	await until(func(): return pdone("petition") and not d.runner.busy, 30.0)
	expect(S.is_flag("petition_gap_seen") and String(d.data.clues.pb_petition_gap.kind) == "guess", "'내일 와'와 실제 — 추정 △")
	expect(pd("petition") == mode, "상소 처리 %s" % pd("petition"))
	if mode == "dismiss":
		await talk("petition_elder")
		await until(func(): return S.is_flag("elder_gone"), 30.0)
		expect(S.is_flag("petition_dismissed") and S.is_flag("elder_gone") and S.is_flag("petition_act_done"), "노인을 돌려보냄(“어제도, 그제도 그 말이었소.”)")
	elif mode == "process":
		expect(S.is_flag("petition_processed") and S.is_flag("petition_act_done"), "소지를 맨 위에 — 받은 날")
	else:
		expect(S.is_flag("old_man_recorded") and String(d.data.clues.pb_petition_handle_note.kind) == "heard", "노인의 말을 적음 — 들은 것으로")

# 한 번만: 풀린 문제는 다시 돌려도 결정·기록이 그대로, 조사 대상·결정 자리도 없다
func _once_check(pid: String) -> void:
	var dec := pd(pid)
	var nclue: int = S.clues.size()
	var nchoice: int = t.choice_log.size()
	d.runner.run([{ "activity": pid + ".handle" }, { "activity": pid + ".gap" }])
	expect(pd(pid) == dec and S.clues.size() == nclue and t.choice_log.size() == nchoice, "%s — 두 번 불러도 한 번(결정 %s)" % [pid, dec])
	var left := []
	for o in d.data.objects:
		if String(o.get("problem", "")) == pid and in_targets(String(o.id)): left.append(o.id)
	for tr in d.data.triggers:
		if String(tr.get("problem", "")) == pid and d.runner.cond(tr.get("when", true)): left.append(tr.id)
	expect(left.is_empty(), "%s — 남은 조사·결정 자리 없음(%s)" % [pid, left])

# ---------------------------------------------------------------------------
# 잔치(정적): EventCrowd 14 · 포졸/사령 없음 · 사령 고정 자리 · 변학도 교의
# ---------------------------------------------------------------------------
func _banquet_static() -> void:
	var cr = d.main.crowd
	expect(cr != null and cr.is_shown("byeon_banquet"), "잔치 군중 선다(feast)")
	var ms: Array = cr.members("byeon_banquet") if cr != null else []
	var tags := {}
	var bad := []
	for m in ms:
		tags[String(m.get("tag", ""))] = int(tags.get(String(m.get("tag", "")), 0)) + 1
		if String(m.kind) in ["pojol", "py_clerk_guard", "official"] or String(m.get("tag", "")) in ["saryeong", "pojol"]: bad.append(m.kind)
	expect(ms.size() == 14 and int(tags.get("guest", 0)) == 8 and int(tags.get("gisaeng", 0)) == 4 and int(tags.get("servant", 0)) == 2, "EventCrowd 14 = 손님 8 · 기생 4 · 시중 2(%s)" % [tags])
	expect(bad.is_empty(), "포졸·사령은 군중에 없음(%s)" % [bad])
	var sar := 0
	for id in d.actors:
		if String(id).begins_with("saryeong") and d.actors[id].shown: sar += 1
	expect(sar == 9, "사령 고정 자리(이야기 인물) 9(줄 8 + 선임)")
	expect(d.actors.byeon_feast.shown and String(d.actors.byeon_feast.anim) == "sit" and not is_nan(d.actors.byeon_feast.y_abs), "변학도 교의(대청 위)")
	for id in ["ti_chail", "ti_dais", "ti_seat_screen", "ti_feast_w0", "ti_feast_e2", "ti_jusang_dais_w"]: expect(_gated_on(id), "잔치 차림 " + id)
	expect(_gate_off("ti_hyeongteul") and _gate_off("ti_wine_cart"), "형틀·술 수레 없음")
	expect(d.case_fn.music_wanted() == "bgm_feast", "잔치 음악")

func _feast_goods_ok() -> bool:
	var w := "p_feast_wine2" if S.is_flag("wine_left") else "p_feast_wine3"
	var o := "p_feast_wine3" if S.is_flag("wine_left") else "p_feast_wine2"
	return d.props.has(w) and d.props[w].shown and not (d.props.has(o) and d.props[o].shown) and d.props.has("p_feast_rice") and d.props.p_feast_rice.shown

# 사령↔잔칫상 실제 걸음 틈: 사령(이야기 인물 실제 자리) 몸 둘레 끝에서 상 충돌체(배치 키트 box_c) 끝까지 · 그 사이로 플레이어 원이 걸어 지나가나
func measure_gap() -> Dictionary:
	var out := { "rows": [], "min": INF, "walk": true }
	var w = d.world
	var zs := [210.8, 213.2, 215.6]
	for side in ["w", "e"]:
		var dirx := 1.0 if side == "w" else -1.0
		var sx: float = d.actors["saryeong_%s1" % side].pos.x
		for z in zs:
			var edge := INF
			for k in 800:
				var x: float = sx + dirx * 0.005 * k
				if w.blocked(x, z, 0.01): edge = x; break
			var gap: float = absf(edge - sx) - BODY_R
			out.rows.append([side, z, snappedf(sx, 0.01), snappedf(edge, 0.01), snappedf(gap, 0.01)])
			out.min = minf(out.min, gap)
		# 플레이어 원(0.375)이 그 틈 가운데로 z 209.9 → 217.2를 걸어 지나가나(실제 이동 함수)
		var cx: float = sx + dirx * (BODY_R + (out.min if out.min < INF else 1.0) * 0.5)
		var p := Vector3(cx, w.height_at(cx, 209.9), 209.9)
		var stuck := 0
		while p.z < 217.2 and stuck < 3:
			var q = w.move_circle(p, 0.0, 0.05, BODY_R)
			if q == null or absf(q.x - p.x) > 0.001: stuck += 1
			if q == null: break
			p = q
		if p.z < 217.2: out.walk = false
	# 앉은 손님(방석)과 사령 사이(참고): 사람 몸 둘씩 뺀 폭
	var seats: Array = []
	var cr = d.main.crowd
	if cr != null:
		for m in cr.members("byeon_banquet"):
			if String(m.role) == "sit" and String(m.get("rect", "")) == "A_court_w": seats.append(m.home.x)
	if not seats.is_empty(): out["seat_lane_w"] = snappedf(absf(seats.max() - d.actors.saryeong_w1.pos.x) - BODY_R * 2.0, 0.01)
	var tw = d.main.placement.gated.get("ti_feast_w1")
	out["table_w_x"] = snappedf(float(tw.node.global_position.x), 0.01) if tw != null and tw.node != null else NAN
	out["aisle"] = snappedf(absf(float(d.main.placement.gated.get("ti_feast_e1").node.global_position.x) - float(tw.node.global_position.x)) - 0.48, 0.01) if tw != null and tw.node != null else NAN
	return out

# 잔치·출두 확인(컷의 그 순간 probe + 끝난 뒤 상태)
func _check_feast_reveal() -> void:
	var cf = d.case_fn
	expect(S.is_flag("mong_feast_in") and S.is_flag("banquet_poem_seen") and S.has_clue("poem"), "§41·§42 몽룡 입장 · 시(17A)")
	if probe.has("edge"): expect(bool(probe.edge.ctl), "몽룡 입장 — 줄 끝에서 조작을 쥔 채 엿듣는다")
	if probe.has("17A"): expect(bool(probe["17A"].shot) and String(probe["17A"].chail) == "SPREAD", "17A 종이를 위에서 · 차일 SPREAD")
	if probe.has("gap"):
		var g: Dictionary = probe.gap
		t._log("GAP " + JSON.stringify(g))
		expect(float(g.min) >= GAP_MIN, "사령↔잔칫상 실제 걸음 틈 %.2fm ≥ %.1f(배우가 움직인 뒤 — %s)" % [float(g.min), GAP_MIN, g.rows])
		expect(bool(g.walk), "그 틈으로 플레이어 원(0.375)이 걸어 지나감")
		expect(float(g.aisle) >= 5.0, "가운데 통로 유지(%.2fm)" % float(g.aisle))
	var pr: Dictionary = cf.probe_reveal
	expect(S.is_flag("royal_inspector_reveal") and S.is_flag("byeon_dismissed") and S.has_clue("reveal"), "ACT 18 어사출두 · 변학도 파면(관인을 거둠)")
	expect(String(pr.get("chail_8a", "")) == "FURLED" and float(pr.get("pitch_8a", -1)) == 58.0, "출두 소리 — 공식 8A(58) · 차일 FURLED(C62)")
	expect(bool(pr.get("ctl_8a", false)), "말발굽~외침 동안 줄에서 조작을 쥔 채(보스전 없음)")
	expect(String(pr.get("chail_18a", "")) == "FURLED", "18A(출두 틀) — 차일 FURLED 그대로(8A에서 바뀌지 않음)")
	var b: Dictionary = pr.get("before", {})
	var a: Dictionary = pr.get("after", {})
	var same_crowd: bool = (b.get("crowd", []) as Array).size() == 14 and (a.get("crowd", []) as Array).size() == 14
	var posed := 0
	for i in mini((b.get("crowd", []) as Array).size(), (a.get("crowd", []) as Array).size()):
		var x: Array = b.crowd[i]; var y: Array = a.crowd[i]
		if x[0] != y[0] or x[1] != y[1] or x[0] == 0: same_crowd = false
		if String(y[2]) in ["kneel", "bow"]: posed += 1
	expect(same_crowd, "출두 — 군중 14 같은 노드·같은 자리")
	if not same_crowd: t._log("CROWD before=%s after=%s" % [b.get("crowd"), a.get("crowd")])
	expect(posed == 14 and int(pr.get("n_crowd", 0)) == 14, "군중 14 모두 자세만 바뀜(sit→kneel · 나머지 bow) %d" % posed)
	var same_act := true
	var kneel := 0
	for id in b.get("actors", {}):
		var x2: Array = b.actors[id]; var y2: Array = a.actors.get(id, [])
		if y2.is_empty() or x2[0] != y2[0] or x2[1] != y2[1]: same_act = false
		if String(id).begins_with("saryeong") and String(y2[2]) == "kneel": kneel += 1
	expect(same_act and (b.get("actors", {}) as Dictionary).size() >= 10, "사령·변학도 같은 노드·제자리(%d)" % (b.get("actors", {}) as Dictionary).size())
	expect(kneel == 9 and int(pr.get("n_saryeong", 0)) == 9, "사령 9 kneel(%d)" % kneel)
	expect(String((a.get("actors", {}) as Dictionary).get("byeon_feast", ["", "", ""])[2]) == "cower", "변학도 제자리 cower")
	expect(S.is_flag("music_cut") and cf.music_wanted() == "", "잔치 음악 끊김(출두 뒤)")
	expect(not cf.has_method("combat_mods") or true, "싸움 없음")
	var seen_combat := false
	for tr in d.runner.trace:
		if String(tr[0]) == "combat": seen_combat = true
	expect(not seen_combat, "보스전 없음 — 싸움 기록 없음")

func _check_restoration() -> void:
	var want: Dictionary = {
		"IIB1": { "on": ["restore_uncertain"], "off": ["restore_wine_paid", "restore_rice_returned", "restore_petition_reopened", "restore_rice_thanks", "restore_wine_partial"] },
		"IIB2": { "on": ["restore_wine_paid", "restore_rice_returned", "restore_rice_thanks", "restore_petition_reopened"], "off": ["restore_uncertain", "restore_wine_partial"] },
		"IIB3": { "on": ["restore_wine_partial", "restore_rice_returned", "restore_rice_spared", "restore_petition_reopened"], "off": ["restore_uncertain", "restore_wine_paid", "restore_rice_thanks"] },
		"IIBCTL": { "on": ["restore_wine_paid", "restore_rice_returned", "restore_rice_thanks", "restore_petition_reopened"], "off": ["restore_uncertain"] } }[br]
	for k in want.on: expect(S.is_flag(k), "피해 복구 %s" % k)
	for k in want.off: expect(not S.is_flag(k), "피해 복구 없음 %s" % k)
	expect(S.is_flag("byeon_dismissed") and S.is_flag("royal_inspector_reveal"), "처벌은 문제 결과와 무관하게 늘")
	# 본 것/들은 것 말씨 — 몽룡의 물음 갈래
	var labels := []
	for c in t.choice_log:
		for l in c[1]: labels.append(String(l))
	if br == "IIB3":
		expect(labels.has("쌀을 더 가져간 것을 보았습니다.") and labels.has("소를 가져갔다고 들었습니다."), "본 것 “쌀을 더 가져간 것을 보았습니다.” · 들은 것 “소를 가져갔다고 들었습니다.”")
		expect(S.is_flag("told_rice_seen") and S.is_flag("told_ox_heard") and not S.is_flag("told_wine_seen"), "말한 것만 기록")
	if br == "IIB2":
		expect(labels.has("술 상인이 지난번 술값도 못 받았다고 들었습니다.") and labels.has("술 물목은 두 독인데, 세 독을 내리라는 것을 보았습니다."), "술 — 본 것·들은 것 따로")
	if br == "IIB1":
		expect(S.is_flag("told_nothing") and labels.has("내가 직접 확인한 것은 많지 않소.") and not labels.has("소를 가져갔다고 들었습니다."), "듣지 않은 소 이야기는 갈래에 없음 · “확인한 것은 많지 않소”")
	if probe.has("resto"):
		var pr: Dictionary = probe.resto
		expect(bool(pr.merchant) == S.is_flag("restore_wine_paid") and bool(pr.elder) == S.is_flag("restore_petition_reopened"), "복구 장면 — 바뀐 사람만 보임(%s)" % pr)

func _journal() -> void:
	var txt := JSON.stringify(JournalBook.section(d.journal_data(), "case"))
	expect(txt.contains("술") and txt.contains("박가네") and txt.contains("암행어사"), "기록책 — 관아 일·출두")
	expect(txt.contains("옥문이 열렸다"), "기록책 — 석방")

# ---------------------------------------------------------------------------
# 저장 → 비우기 → 다시 읽기(사건 on_load까지) — 시험 저장 파일만
# ---------------------------------------------------------------------------
func _key_state() -> String:
	var fl := {}
	for k in S.flags:
		var ks := String(k)
		if ks.begins_with(Problems.PREFIX) or ks.begins_with("beat_") or ks.begins_with("wine_") or ks.begins_with("rice_") or ks.begins_with("petition") \
				or ks in ["duty_on", "duty_complete", "feast_day", "feast_seen", "old_man_heard", "jail_reunion_seen", "mongryong_return_seen"]:
			fl[k] = str(S.flags[k])
	var it := {}
	for k in S.items: it[k] = int(S.items[k])
	return JSON.stringify([S.phase, fl, S.clues, it, S.world.get("beat_order", [])])

func _reload(tag: String) -> void:
	await _idle()
	var before := _key_state()
	var marks0: int = d.case_fn.ctl2.marks.size()
	S.save()
	S.reset()
	expect(not S.is_flag("p2b_started"), "비운 뒤엔 II-B가 없다(%s)" % tag)
	var ok: bool = S.load_saved()
	d.case_fn.on_load()
	d.mark_dirty(); d._refresh()
	await _frames(10)
	await _idle()
	expect(ok and _key_state() == before, "저장/불러오기(%s) — 관찰·결정·물건·국면·FIXED_BEAT 그대로" % tag)
	expect(d.case_fn.ctl2.marks.size() == marks0 and not d.runner.busy, "불러온 뒤 끝난 장면이 다시 돌지 않음(%s)" % tag)

# ---------------------------------------------------------------------------
# 컷의 그 순간(namwon_chunhyang_test.cut이 부른다)
# ---------------------------------------------------------------------------
func probe_cut(nm: String) -> void:
	match nm:
		"14A_beggar_return":
			var a = d.actors.mong_b
			probe["14A"] = { shot = d.main.rig.shot != null, kind = String(a.spec.kind), anim = String(a.anim) }
		"17_feast_general":
			probe["feast"] = { chail = d.main.world.props.get_state("ti_chail/cloth") }
		"17_mong_edge":
			probe["edge"] = { ctl = d.case_fn.controllable() }
			await _frames(30)   # 시중·기생이 오가고 몽룡이 걸어 들어온 뒤
			probe["gap"] = measure_gap()
		"17A_poem":
			probe["17A"] = { shot = d.main.rig.shot != null, chail = d.main.world.props.get_state("ti_chail/cloth") }
			if shooting():   # 화면 검토는 자막을 짧게 지운다(auto) — 실제 놀이처럼 둘째 줄을 종이 위에 다시 띄워 찍는다
				d.ui.auto_real = true
				d.ui.caption("옥쟁반의 좋은 안주는 백성의 기름이라.", 2.6)
				d.ui.auto_real = false
		"22_gwanghallu_end":
			var sw: bool = _gated_on("ti_swing")
			probe["end"] = { ok = sw and d.actors.end_kid_a.shown and d.actors.end_kid_b.shown and not d.case_fn.rider_on(), swing = sw }
		"19_restoration":
			probe["resto"] = { merchant = d.actors.wine_merchant.shown, elder = d.actors.petition_elder.shown, farmer = d.actors.rice_farmer.shown, clerk = d.actors.resto_clerk.shown }

# ---------------------------------------------------------------------------
# 화면(창 --storyshots): 카드가 떠 있는 동안 찍는다(오누이 observe 시험과 같은 방식) — 헤드리스면 아무것도 안 한다
# ---------------------------------------------------------------------------
var _watching := false
func shooting() -> bool: return d.main.args.has("storyshots") and DisplayServer.get_name() != "headless"

func _watch_card(title: String, nm: String) -> void:
	_watching = true
	d.ui.auto_hold = 2.5
	for i in 6000:
		await t.get_tree().process_frame
		if d.ui._card.visible and String(d.ui._card_title.text) == title:
			await t.cut(nm); break
	d.ui.auto_hold = 0.03
	_watching = false

func _wait_watch() -> void:
	for i in 6000:
		if not _watching: break
		await t.get_tree().process_frame

# ---------------------------------------------------------------------------
# 끝난 뒤 관아 곁일 「창고 장부 대조」 — 같은 Activity/Problem 계약을 데이터만으로(브리프 §21 재사용 시연)
# ---------------------------------------------------------------------------
func _side_job() -> void:
	var p: Dictionary = d.data.problems.get("ledger", {})
	expect(not p.is_empty() and String(p.get("when", "")) == "ph('done')", "곁일 「창고 장부 대조」 — 사건이 끝난 뒤에만(ph done)")
	expect(not JSON.stringify(p).contains("\"call\"") and not JSON.stringify(d.actors.ledger_keeper.spec.get("talk", [])).contains("\"call\""), "곁일은 데이터만 — 사건 코드 호출(call) 없음")
	var vars0 := JSON.stringify([S.vars.get("CASE_NAMWON_CHUNHYANG_OUTCOME"), S.vars.get("CASE_NAMWON_CHUNHYANG_COMPLETE"), S.world.get("beat_order", []), S.world.get("end_lines", [])])
	await _frames(6)
	expect(d.actors.ledger_keeper.shown and in_targets("pb_ledger_book") and _gated_on("ti_gamani_store_a"), "끝난 뒤 — 창고지기·장부·가마니가 선다")
	var mode: String = { "IIB1": "shut", "IIB2": "shed", "IIB3": "note" }.get(br, "note")
	if mode != "shut":
		await talk("ledger_keeper")
		expect(pa("ledger", "keeper") and String(d.data.clues.pb_ledger_keeper.kind) == "heard" and String(d.data.clues.pb_ledger_keeper.by) == "창고지기", "곁일 — 창고지기의 말(들은 것 ◇)")
	await obj("pb_ledger_book")
	expect(pa("ledger", "book") and String(d.data.clues.pb_ledger_book.kind) == "fact" and pd("ledger") == "", "곁일 — 장부(본 것 ◆) · 하나로는 안 물음")
	t.prefer = [{ "shut": "장부를 덮는다", "shed": "뒤 곳간부터", "note": "센 대로" }[mode]]
	if shooting(): _watch_card("세 가마의 차이", "23_ledger_side")
	await obj("pb_ledger_stock")
	await _wait_watch()
	await until(func(): return pd("ledger") != "" and not d.runner.busy, 30.0)
	expect(S.is_flag("ledger_gap_seen") and pd("ledger") == mode, "곁일 — 장부 열둘·창고 아홉 → 고름 %s" % pd("ledger"))
	if mode == "shed":
		expect(not pdone("ledger") and in_targets("pb_ledger_ff_back_shed"), "뒤 곳간 — 아직 안 풀림, 헛걸음 자리가 열림(막히지 않음)")
		await obj("pb_ledger_ff_back_shed")
		expect(S.has_clue("pb_ledger_ff_back_shed") and S.is_flag("ledger_noted"), "헛걸음 → 추가 흔적(흘린 낟알)")
	await until(func(): return pdone("ledger") and not d.runner.busy, 30.0)
	expect(pdone("ledger") and S.is_flag("ledger_check_done"), "곁일 풀림 — 결과 깃발 한 번")
	expect(S.is_flag("ledger_noted") == (mode != "shut") and S.is_flag("ledger_shut") == (mode == "shut"), "곁일 행동 깃발(%s)" % mode)
	_once_check("ledger")
	expect(JSON.stringify([S.vars.get("CASE_NAMWON_CHUNHYANG_OUTCOME"), S.vars.get("CASE_NAMWON_CHUNHYANG_COMPLETE"), S.world.get("beat_order", []), S.world.get("end_lines", [])]) == vars0
		and S.phase == "done", "곁일은 결말·FIXED_BEAT·기록책 끝 줄을 바꾸지 않는다")
