# 대본 시험(--storytest=namwon_chunhyang:<갈래>) — 「남원의 약속」 PART I.
#   godot --path seolhwa_godot res://scenes/region.tscn -- --region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:a
#   a     : 진입 판정(choose — 요구 둘 다일 때만) → C0001 단오(군중 28·차림·밝은 음악) → 오누이 뒤 남원 사람 → 1A → 부딪힘(주워 줌 · 맞소 · 같이 감) → 2A 거절 →
#           몽룡 → 저녁 월매 집 → 편지(열 수 없음) · 웃음 · 함께 걷기 → 밤 백년가약(들었습니다 → vow_witness · vow_heard) → 소식 · 5A 이별 → PART1_COMPLETE →
#           춘향에게 “기다리실 겁니까?” → PART II 없음 · 떠나면 LEFT_AFTER_PART1 · 기록책
#   b     : 다른 선택 — 지나감 · 혼자 가시오(나중에 그네 곁) · 고개 끄덕임 · 아무 말 없음
#   after : PART I 끝 + 떠남 + 강릉 완료(PART II 열림 조건 참)으로 다시 남원 — PART II는 아무것도 서지 않는다. 남원 사람 말 · 춘향 집
# 저장은 --savefile(run_story_tests.sh) — prepare가 남원·한양 끝 상태로 꾸민다. 결과는 STORYTEST PASS/FAIL.
# 화면 검토: --storyshots=shots/chunhyang_part1(창 모드) — 사건 함수의 _cut(이름)에서 찍는다.
extends Node

const Progress := preload("res://scripts/region/progress.gd")
const CaseRegistry := preload("res://scripts/story/case_registry.gd")
const JournalBook := preload("res://scripts/story/journal_book.gd")
const Rumors := preload("res://story/rumors_data.gd")

var d
var branch := "A"
var _t0 := 0
var _fails: Array = []
var prefer: Array = []
var _n := 0

static func prepare(_dir) -> void:
	Progress.data()
	for kv in [["MAIN_MASTER_TRACE", "HANYANG"], ["SKILL_BEAST_TRACE", true], ["CASE_NAMWON_OUTCOME", "C"], ["CASE_NAMWON_DETAIL", "C"],
			["CASE_NAMWON_MORNING", "unknown"], ["CASE_NAMWON_COMPLETE", true], ["CASE_HANYANG_OUTCOME", "followed"], ["CASE_HANYANG_BOOKSHOP_COMPLETE", true],
			["ACT2_OPEN", true], ["MAIN_WOOCHI_KNOWN", true], ["SKILL_GUARD_SHOVE", true], ["SKILL_QUICK_THROW", true]]:
		Progress.set_var(kv[0], kv[1])
	Progress.data().cases["namwon"] = { "v": 2, "phase": "done", "flags": { "case_started": true, "resolved": true }, "clues": [], "rules": [],
		"items": { "ITM_TOOL_009": 1, "COIN": 7 }, "world": {}, "talked": {}, "notes": [], "seen": { "S0010": true }, "time": 8.0 }
	Progress.data().cases["hanyang"] = { "v": 2, "phase": "done", "flags": { "case_started": true }, "clues": [], "rules": [], "items": {}, "world": {},
		"talked": {}, "notes": [], "seen": { "S1006": true }, "time": 12.0 }
	Progress.save()

func _init(director, spec: String) -> void:
	d = director
	var p := spec.split(":")
	branch = (p[1] if p.size() > 1 else "a").to_upper()
	name = "story_test"

func begin() -> void:
	d.ui.auto = true
	d.ui.auto_choice = choose
	if d.main.args.has("storyshots") and DisplayServer.get_name() != "headless": d.ui.auto_real = false
	Engine.time_scale = float(d.main.args.get("storyspeed", "2.5"))
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

func expect(c: bool, what: String) -> void:
	_n += 1
	if c: _log("ok " + what)
	else: _fails.append(what); _log("FAIL " + what)

# 이야기 인물·조사 대상 곁으로 가서 E
func go(id: String, dz := 1.2) -> void:
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
		_fails.append("대상 없음/조건 안 맞음: " + id); _log("FAIL 대상 없음 " + id); return
	_log("interact " + id)
	d.interact(id)
	await _frames(2)
	await _idle()

func walk_to(at) -> void:
	await _idle()
	d.teleport_to(at, "up")
	await _frames(12)
	await get_tree().create_timer(0.45).timeout
	await _idle()
	await _frames(4)
	await _idle()

# 사건 함수의 _cut(이름) — 화면 검토일 때만 찍는다
func cut(nm: String) -> void:
	if not d.main.args.has("storyshots") or DisplayServer.get_name() == "headless": return
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	await _frames(50)
	var dir: String = d.main._abs(String(d.main.args.storyshots))
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("%s.png" % nm))
	_log("SHOT " + nm)
	Engine.time_scale = ts

# 지금 고를 talk 항목의 첫 대사(인물의 말이 맞는지)
func first_line(id: String) -> String:
	var a: Dictionary = d.actors.get(id, {})
	for t in a.get("spec", {}).get("talk", []):
		if d.runner.cond(t.get("when", true)):
			for st in t.get("steps", []):
				if st is Dictionary and st.has("say"): return String((st.get("lines", []) as Array)[0])
			return ""
	return ""

func _gated_on(id: String) -> bool:
	var e = d.main.placement.gated.get(id)
	return e != null and not bool(e.get("off", false))

func _gate_off(id: String) -> bool:
	var e = d.main.placement.gated.get(id)
	return e == null or bool(e.get("off", false))

func _done() -> void:
	Engine.time_scale = 1.0
	if _fails.is_empty(): printerr("STORYTEST PASS namwon_chunhyang:%s checks=%d time=%.0fs" % [branch, _n, (Time.get_ticks_msec() - _t0) / 1000.0])
	else: printerr("STORYTEST FAIL namwon_chunhyang:%s fails=%s" % [branch, JSON.stringify(_fails)])
	d.main._quit()

# ---------------------------------------------------------------------------
func _run() -> void:
	expect(d.case_id == "namwon_chunhyang", "오누이·한양 뒤 남원 — 춘향이 도는 사건")
	if branch == "AFTER": await _run_after(); return
	_entry_gate()
	await d.runner.run([{ "event": "C0001" }])
	await _frames(6); await _idle()
	expect(d.S.phase == "dano" and d.S.is_flag("case_started"), "C0001 → 단계 dano · 사건 기록")
	expect(d.case_fn.music_wanted() == "bgm_dano_bright", "밝은 단오 음악")
	# 단오 장터(화면 검토) → 단오 차림·군중(광한루 앞으로 가서)
	if branch == "A":
		await walk_to([-3262.0, 403.0])
		d.main.player.facing = "left"
		await cut("01_festive_namwon")
	await walk_to([-3236.0, 452.0])
	await _frames(20)
	var cr = d.main.crowd
	expect(cr != null and cr.is_shown("dano_market"), "단오 군중이 선다(dano)")
	expect(cr != null and cr.members("dano_market").size() == 28, "단오 군중 28명(확정)")
	expect(cr != null and not cr.is_shown("byeon_banquet"), "잔치 군중은 없다")
	expect(_gated_on("ti_streamers_ground") and _gated_on("ti_swing") and _gated_on("ti_ssireum"), "단오 차림(색천·그네·씨름판)")
	if branch == "A":
		await _aftermath_npcs()
		await walk_to([-3236.0, 452.0])
	# §4 1A
	await walk_to("ch_vista_in")
	expect(d.S.is_flag("vista_seen") and d.S.has_clue("dano"), "C0101 1A — 단오장")
	# §5~§8
	prefer = ["주워 준다", "맞소", "같이 가 주지"] if branch == "A" else ["그냥 지나간다", "혼자 가시오"]
	await walk_to([-3263.0, 433.0])
	await _idle()
	expect(d.S.is_flag("bump_done") and d.S.is_flag("met_bangja"), "C0102 방자와 부딪힘")
	expect(d.S.has_clue("swing") and d.S.has_clue("name"), "1B 그네 · 이름(방자에게 들음)")
	if branch == "A":
		expect(d.S.is_flag("fan_returned") and d.S.is_flag("recog_yes"), "부채 주워 줌 · “맞소”")
		expect(d.S.is_flag("errand_with") and d.S.is_flag("refusal_seen"), "같이 가서 2A 거절 장면")
	else:
		expect(d.S.is_flag("fan_passed") and not d.S.is_flag("recog_yes"), "그냥 지나감(알아봄 없음)")
		expect(d.S.is_flag("errand_alone") and not d.S.is_flag("refusal_seen"), "혼자 보냄 — 아직 거절 장면 전")
		await walk_to("ch_swing_land")
		expect(d.S.is_flag("refusal_seen"), "나중에 그네 곁에서 방자를 만나 거절 장면")
	expect(d.S.has_clue("refusal") and d.S.clues.has("refusal"), "춘향의 대답(들음 — 춘향)")
	expect(String(d.data.clues.refusal.kind) == "heard" and String(d.data.clues.swing.kind) == "fact", "기록: 본 것(그네)과 들은 것(대답) 구분")
	# §9 → §10
	await walk_to("ch_gwanghallu_front")
	expect(d.S.is_flag("mong_reacted") and d.S.has_clue("mong_laugh"), "C0204 몽룡 “재미있구나.”")
	expect(d.S.phase == "courtship" and d.S.is_flag("evening_call") and d.S.has("ITM_CH_JAR"), "§10 저녁 — 술병·찬합을 받아 듦")
	expect(d.main.hour >= 18.0 and d.case_fn.music_wanted() == "", "저녁엔 음악이 그친다")
	# §11·§12
	await walk_to("ch_wolmae_front")
	expect(d.S.is_flag("first_meeting_done") and d.S.has_clue("sorry") and d.S.has_clue("wolmae_word"), "C0302 월매 집 — “잘못했소.”")
	expect(not d.S.has("ITM_CH_JAR"), "술병·찬합은 내려놓음")
	# §13 며칠의 압축 — A 편지
	await go("bangja")
	expect(d.S.is_flag("letter_asked") and d.S.has("ITM_CH_LETTER"), "C0401 편지를 받음(열 수 없음)")
	await go("chunhyang", 1.0)
	expect(d.S.is_flag("letter_delivered") and not d.S.has("ITM_CH_LETTER"), "C0403 춘향에게 전함 — “고맙습니다.”")
	# C 웃음(필수 아님 — a만)
	if branch == "A":
		await walk_to([-3221.0, 466.0])
		await walk_to("ch_wolmae_front")
		expect(d.S.is_flag("laugh_heard"), "§13 C 담 너머 웃음소리")
	# B 함께 걷기
	await walk_to("ch_ojakgyo")
	expect(d.S.is_flag("walk_seen") and d.S.has_clue("walk"), "C0404 오작교 곁을 함께 걷는 두 사람(대사 없음)")
	# 밤 초대 → 기다림
	prefer = ["해 질 때까지"]
	await go("bangja")
	expect(d.S.is_flag("vow_invited") and d.case_fn.is_night(), "C0402 밤 초대 → 해 질 때까지 기다림")
	# §14 백년가약 → §15 · §16 · §17
	prefer = ["들었습니다"] if branch == "A" else ["고개를 끄덕인다"]
	await walk_to("ch_wolmae_front")
	await _idle()
	expect(d.S.is_flag("vow_done") and d.S.is_flag("vow_witness"), "C0406 백년가약 — vow_witness")
	if branch == "A": expect(d.S.is_flag("vow_heard") and not d.S.is_flag("vow_own") and not d.S.is_flag("vow_nod"), "월매에게 “들었습니다.” — vow_heard만")
	else: expect(d.S.is_flag("vow_nod") and not d.S.is_flag("vow_heard"), "말없이 고개를 끄덕임 — vow_nod만")
	expect(d.S.phase == "farewell" and d.S.has_clue("news") and d.S.has_clue("farewell"), "C0501 소식 · 오리정 곁 북쪽 길 이별")
	expect(bool(d.S.vars.get("CASE_NAMWON_CHUNHYANG_PART1_COMPLETE", false)) and d.S.is_flag("part1_done"), "PART1_COMPLETE")
	expect(not bool(d.S.vars.get("CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1", false)), "아직 남원 안 — LEFT 아님")
	expect(not bool(d.S.vars.get("CASE_NAMWON_CHUNHYANG_COMPLETE", false)) and String(d.S.vars.get("CASE_NAMWON_CHUNHYANG_OUTCOME", "")) == "", "사건 완료·결말은 아직(PART II)")
	for k in ["dano_swing", "mong_sees", "bangja_message", "first_meeting", "vow", "farewell"]: expect(d.S.is_flag("beat_" + k), "FIXED_BEAT " + k)
	await _frames(10)
	expect(not cr.is_shown("dano_market"), "이별 뒤 단오 군중은 사라짐")
	expect(_gate_off("ti_streamers_ground") and _gate_off("ti_swing"), "단오 차림 내려감(farewell)")
	expect(d.case_fn.music_wanted() == "", "이별에는 큰 음악 없음")
	# §17 춘향에게 말 걸기
	prefer = ["기다리실 겁니까"] if branch == "A" else ["아무 말 하지"]
	await go("chunhyang", 1.4)
	if branch == "A": expect(d.S.is_flag("farewell_ask_wait"), "“기다리실 겁니까?” — “약속했으니까요.”")
	else: expect(d.S.is_flag("farewell_silent"), "아무 말 하지 않음 — “…가세요.”")
	expect(d.S.is_flag("chun_home"), "춘향은 집으로")
	_no_part2("PART I 끝")
	# 기록책
	var jd: Dictionary = d.journal_data()
	var case_pg: Dictionary = JournalBook.section(jd, "case")
	var txt := JSON.stringify(case_pg)
	expect(txt.contains("남원의 약속") and txt.contains("백년가약"), "기록책 사건 기록 — 「남원의 약속」 PART I")
	expect(txt.contains("춘향"), "기록책 — 들은 말에 말한 사람")
	if d.main.args.has("storyshots") and DisplayServer.get_name() != "headless":
		d.ui.journal_toggle(JournalBook.build(d, "case"))
		await cut("09_journal_part1")
		d.ui.journal_toggle(jd)
	# 떠남 → LEFT_AFTER_PART1
	d.on_leave_space("GG_HANYANG")
	expect(bool(d.S.vars.get("CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1", false)) and bool(Progress.get_var("CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1", false)), "남원을 떠나면 LEFT_AFTER_PART1")
	expect(not d.case_fn.part2_open(), "PART II 닫힘(강릉·경주·황주 아직)")
	await _done()

# 진입 판정 — 요구 둘(오누이 완료 && 한양 책방 완료)일 때만 춘향
func _entry_gate() -> void:
	var cands: Array = CaseRegistry.cases_for("JL_NAMWON_UNBONG")
	expect(cands == ["namwon", "namwon_chunhyang"], "남원 등록부: 오누이 다음 춘향(%s)" % [cands])
	var none := { "CASE_NAMWON_COMPLETE": false, "CASE_HANYANG_BOOKSHOP_COMPLETE": false }
	var only_nw := { "CASE_NAMWON_COMPLETE": true, "CASE_HANYANG_BOOKSHOP_COMPLETE": false }
	var only_hy := { "CASE_NAMWON_COMPLETE": false, "CASE_HANYANG_BOOKSHOP_COMPLETE": true }
	var both := { "CASE_NAMWON_COMPLETE": true, "CASE_HANYANG_BOOKSHOP_COMPLETE": true }
	expect(String(CaseRegistry.choose(cands, none).id) != "namwon_chunhyang", "요구 없음 → 춘향 아님")
	expect(String(CaseRegistry.choose(cands, only_nw).id) == "namwon", "오누이만 끝 → 오누이(끝난 사건, 춘향 아님)")
	expect(String(CaseRegistry.choose(cands, only_hy).id) != "namwon_chunhyang", "한양만 → 춘향 아님")
	expect(String(CaseRegistry.choose(cands, both).id) == "namwon_chunhyang", "둘 다 → 춘향")
	# 귀환 이유 — 다른 고을 소문(강제 없음): 한양 책방 뒤에만, PART I 뒤에는 그치는 말
	for r in Rumors.RUMORS:
		if String(r.id).begins_with("CH_DANO_"):
			expect(Rumors.pick(r, Progress.vars(), { "CASE_NAMWON_CHUNHYANG_PART1_COMPLETE": false }).contains("남원 단오장"), "소문 %s “남원 단오장이 크게 선다더라”" % r.id)
			expect(Rumors.pick(r, { "CASE_HANYANG_BOOKSHOP_COMPLETE": false }, { "CASE_HANYANG_BOOKSHOP_COMPLETE": false }) == "", "소문 %s 한양 전에는 없음" % r.id)
			expect(Rumors.pick(r, Progress.vars(), { "CASE_NAMWON_CHUNHYANG_PART1_COMPLETE": true }) == "", "소문 %s PART I 뒤에는 그침" % r.id)
	var head: Dictionary = d.data.case
	expect(head.requires.size() == 2 and head.requires.has("CASE_NAMWON_COMPLETE") and head.requires.has("CASE_HANYANG_BOOKSHOP_COMPLETE"), "requires 둘(결정 §4)")
	var gl := []
	for k in d.S.vars:
		if String(k).begins_with("CASE_NAMWON_CHUNHYANG_"): gl.append(k)
	for k in Progress.vars():
		if String(k).begins_with("CASE_NAMWON_CHUNHYANG_") and not gl.has(k): gl.append(k)
	gl.sort()
	expect(gl.all(func(k): return k in ["CASE_NAMWON_CHUNHYANG_COMPLETE", "CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1", "CASE_NAMWON_CHUNHYANG_OUTCOME", "CASE_NAMWON_CHUNHYANG_PART1_COMPLETE"]), "전역 변수는 넷뿐(%s)" % [gl])

# 오누이 뒤 남원 사람(같은 CHR·그림) — 사건 뒤 말만
func _aftermath_npcs() -> void:
	for id in ["jumo", "miller", "hunter", "neighbor"]:
		expect(d.actors.has(id), "남원 사람 다시 섬 " + id)
	expect(String(d.actors.jumo.spec.chr) == "CHR_HUM_015" and String(d.actors.jumo.spec.kind) == "innkeeper", "주모 같은 CHR·그림")
	expect(first_line("jumo") == "북쪽 길은 다시 사람들이 다니오.", "주모 “북쪽 길은 다시 사람들이 다니오.”")
	expect(first_line("neighbor").contains("소식 들으면"), "이웃 아낙 — 아침의 대답(CASE_NAMWON_MORNING unknown)")
	await go("jumo", 1.0)
	expect(int(d.S.talked.get("jumo", 0)) == 1, "주모에게 말 걸기")
	await go("neighbor", 1.0)
	expect(not d.data.has("arenas") and not d.events.has("S0007"), "오누이 흐름은 옮기지 않음")

func _no_part2(when: String) -> void:
	expect(d.S.phase == "farewell", "%s: 단계 farewell에 머묾(PART II 단계 없음)" % when)
	for id in ["ti_gamani_store_a", "ti_dais", "ti_hyeongteul", "ti_chail", "ti_feast_w0", "ti_wine_cart"]:
		expect(_gate_off(id), "%s: PART II 차림 없음 %s" % [when, id])
	expect(not d.main.crowd.is_shown("byeon_banquet"), "%s: 잔치 군중 없음" % when)
	var p2 := false
	for e in d.events:
		if int(String(e).substr(1, 2)) >= 6: p2 = true
	expect(not p2, "%s: PART II 장면 없음" % when)

# PART I 끝 + 떠남 + 강릉 완료 → 다시 남원: PART II 열림 조건은 참이어도 아무것도 서지 않는다
func _run_after() -> void:
	var S = d.S
	S.phase = "farewell"
	for k in ["case_started", "vista_seen", "bump_done", "met_bangja", "errand_choice", "errand_with", "refusal_seen", "mong_reacted", "evening_call",
			"first_meeting_done", "letter_asked", "letter_delivered", "walk_seen", "vow_invited", "vow_done", "vow_witness", "vow_own", "farewell_scene_done",
			"part1_done", "farewell_talked", "chun_home", "bangja_off", "mong_off"]:
		S.flags[k] = true
	S.vars.CASE_NAMWON_CHUNHYANG_PART1_COMPLETE = true
	S.vars.CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1 = true
	S.vars.CASE_GANGNEUNG_COMPLETE = true
	d.case_fn.on_load()
	d.on_phase(); d._refresh()
	await _frames(10)
	expect(d.case_fn.part2_open(), "PART II 열림 조건 참(PART1 · LEFT · 강릉)")
	await walk_to("ch_wolmae_front")
	await _frames(20)
	_no_part2("다시 남원")
	expect(not d.runner.busy and S.phase == "farewell", "도착해도 PART II 장면이 돌지 않음")
	expect(d.actors.chunhyang.shown and not d.actors.mongryong.shown and not d.actors.bangja.shown, "춘향은 집에, 몽룡·방자는 없다")
	expect(first_line("wolmae") == "그 도련님 말, 길손도 들었지요.", "월매 — PART I 뒤 말")
	await go("wolmae", 1.0)
	expect(first_line("jumo") == "북쪽 길은 다시 사람들이 다니오.", "주모 — 사건 뒤 말")
	expect(not d.main.crowd.is_shown("dano_market"), "단오 군중 없음")
	await _done()
