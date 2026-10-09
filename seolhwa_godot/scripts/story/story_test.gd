# 대본 시험(--storytest=namwon:A|B|C) — 사건을 처음부터 끝까지 한 갈래로 몰아 본다.
#   v3: 원작 장면(namwon_data FIXED_BEATS)이 모두, 그 순서로 일어났는지 · 범을 죽이지 않았는지 · 마을이 아이들을 거두지 않았는지 ·
#   CASE_NAMWON_OUTCOME이 A/B/C로 남는지(진행·숙련 해금·뒤 사건 소문이 그대로 읽는다)를 본다.
#   --storytest=namwon:onboard — 처음 하는 사람 안내(S0000 → S0002 → 첫 단서 단계 → 첫 호랑이 조우)만 본다(scripts/story/onboard_test.gd).
#   자리로 순간이동해 대상과 대화·조사하고(director.interact), 선택은 결말별 우선 목록으로 고르고, 전투는 간단한 봇이 싸운다.
#   단계마다 플래그·단서·버릇·소지품을 남기고, 끝에 결과를 STORYTEST PASS/FAIL로 찍은 뒤 끝낸다.
#   저장은 user://storytest_progress.json(사용자 저장 파일을 건드리지 않는다). --storyspeed=2.5 시간 배율(기본 2.5).
extends Node

var d          # story_director
var branch := "A"
var plan: Array = []
var prefer: Array = []
var deny: Array = []
var _t0 := 0
var _fails: Array = []
var _bot_tap := 0
var _bot_dodge_cd := 0.0
var _log_t := 0.0
var _bot_last := Vector2.INF
var _bot_stuck := 0.0
var _combat_shot := false
var bot_wait_first := false   # 안내 시험: 범이 처음 몸을 낮출 때까지 봇이 다가가지 않는다
var bot_passive := false      # 안내 시험: 베지 않고 피하기·막기만(목표가 죽이기가 아님을 본다)

func _init(director, spec: String) -> void:
	d = director
	var p := spec.split(":")
	branch = (p[1] if p.size() > 1 else "A").to_upper()
	name = "story_test"

func begin() -> void:
	d.ui.auto = true
	d.ui.auto_choice = choose
	Engine.time_scale = float(d.main.args.get("storyspeed", "2.5"))
	if d.main.args.has("camshake"): load("res://scripts/story/game_settings.gd").test_override["cam_shake"] = String(d.main.args.camshake)
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()

func _log(s: String) -> void:
	printerr("STORYTEST [%s] %6.1fs %s" % [branch, (Time.get_ticks_msec() - _t0) / 1000.0, s])

# ---- 선택 정책 ----
func choose(prompt: String, labels: Array) -> int:
	for want in prefer:
		for i in labels.size():
			if labels[i] != "" and String(labels[i]).contains(want): return i
	for i in labels.size():
		var l := String(labels[i])
		if l == "": continue
		var bad := false
		for x in deny + ["그만", "다음에", "문 꼭", "문 걸고", "아직이다", "칼을 뽑는다", "지금 뛰어나간다", "그만둔다"]:
			if l.contains(x): bad = true
		if not bad: return i
	for i in range(labels.size() - 1, -1, -1):
		if labels[i] != "": return i
	return 0

# ---- 기다리기 ----
func _idle() -> void:
	var n := 0
	while (d.runner.busy or d.ui.modal or d.combat_view.active) and n < 60000:
		await get_tree().process_frame
		n += 1
	await get_tree().process_frame

func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame

# 대상 곁으로 가서 말 걸기·조사(조건이 안 맞으면 실패로 남긴다)
func go(id: String) -> void:
	await _idle()
	var p: Vector2 = d.anchor(id) if not d.actors.has(id) else Vector2(d.actors[id].pos.x, d.actors[id].pos.z)
	d.teleport_to(Vector2(p.x, p.y + 1.6), "up")
	await _frames(8)
	await _idle()   # 자리 트리거(첫 조우 등)가 먼저 돌았으면 끝나길 기다린다
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

func walk_to(at) -> void:
	await _idle()
	var p: Vector2 = d.anchor(at)
	d.teleport_to(p, "up")
	await _frames(12)
	await _idle()

# --storyshots=폴더: 장면마다 창 화면(UI 포함)을 찍는다(헤드리스가 아닐 때)
func shot(nm: String, frames := 20) -> void:
	if not d.main.args.has("storyshots") or DisplayServer.get_name() == "headless": return
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	await _frames(frames)
	var dir: String = d.main._abs(String(d.main.args.storyshots))
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("story_%s_%s.png" % [branch, nm]))
	_log("SHOT " + nm)
	Engine.time_scale = ts

# 원작 장면 찍기(namwon_case._shot이 부른다) — --storyshots=폴더, 화면이 있을 때만. 파일: namwon_<갈래>_<장면>.png
func tale_shot(nm: String) -> void:
	if not d.main.args.has("storyshots") or DisplayServer.get_name() == "headless": return
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	await _frames(3)
	var dir: String = d.main._abs(String(d.main.args.storyshots))
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("namwon_%s_%s.png" % [branch, nm]))
	_log("SHOT " + nm)
	Engine.time_scale = ts

# 동아줄 절정 화면 검토(--storyshots, 화면이 있을 때만 — namwon_case.rope_night이 부른다): 여기서부터 결말 카드까지
# 대사·자막·암전·연출을 실제 길이로 돌리고(ui.auto_real, 시간 배율 1), 1초마다 seq_NNN을 찍는다. --camshake=normal|off로 흔들림 설정을 정한다.
var _review := false
func review_begin() -> void:
	if _review or not d.main.args.has("storyshots") or DisplayServer.get_name() == "headless": return
	_review = true
	d.ui.auto_real = true
	Engine.time_scale = 1.0
	# 창이 다른 창에 가려지면 macOS가 창(루트 화면)을 다시 그리지 않아 찍힌 그림이 멈춘다 — 검토 동안 맨 위에
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_log("REVIEW begin")
	var dir: String = d.main._abs(String(d.main.args.storyshots))
	DirAccess.make_dir_recursive_absolute(dir)
	var n := 0
	var t0 := Time.get_ticks_msec()
	while _review and n < 240:
		await get_tree().create_timer(1.0, true, false, true).timeout
		if not _review: break
		get_viewport().get_texture().get_image().save_png(dir.path_join("seq_%03d.png" % n))
		n += 1
	_log("REVIEW %d shots %.1fs" % [n, (Time.get_ticks_msec() - t0) / 1000.0])

func review_end() -> void:
	if not _review: return
	_review = false
	d.ui.auto_real = false
	Engine.time_scale = float(d.main.args.get("storyspeed", "2.5"))

# 절정·결말 장면을 찍는 감시(대본과 따로 돈다)
func _watch_shots() -> void:
	var door := false
	var morning := false
	for i in 200000:
		await get_tree().process_frame
		if not door and d.actors.has("tiger_night") and d.actors.tiger_night.path.is_empty() and d.actors.tiger_night.anim == "knock":
			door = true; await shot("door", 2)
		if not morning and d.S.phase == "morning" and d.ui.modal:
			morning = true; await shot("morning", 2)
		if d.ui._ending.visible and d.ui._ending.modulate.a > 0.95:
			await shot("ending", 1); review_end(); return

func _fail(s: String) -> void:
	_fails.append(s)
	_log("FAIL " + s)

func expect(cond: bool, what: String) -> void:
	if cond: _log("ok " + what)
	else: _fail(what)

func snapshot(tag: String) -> void:
	var S = d.S
	_log("%s phase=%s flags=%s clues=%s rules=%s items=%s world=%s" % [tag, S.phase, JSON.stringify(_public_flags()), JSON.stringify(S.clues),
		JSON.stringify(S.rules), JSON.stringify(S.items), JSON.stringify(S.world)])

func _public_flags() -> Dictionary:
	var o := {}
	for k in d.S.flags:
		if not String(k).begins_with("_trig_"): o[k] = d.S.flags[k]
	return o

# ---- 대본 ----
func _run() -> void:
	_log("시작 branch=%s" % branch)
	if branch == "ONBOARD":
		await load("res://scripts/story/onboard_test.gd").new().run(self)
		return
	# S0000 남원으로 가는 길 → S0001 남원 전경(실제로 돌린다)
	await d.runner.run([{ "event": "S0000" }])
	expect(d.S.phase == "explore", "S0000 → explore")
	await walk_to("s0000_vista")
	await _frames(20); await _idle()
	expect(d.S.is_flag("INTRO_NAMWON_TITLE_DONE"), "S0001 남원 전경")
	await walk_to("east_gate")
	expect(d.S.is_flag("s0001_done"), "S0001 성문 통과")
	# S0002 주막
	await walk_to("tavern")
	await _frames(30)
	await go("jumo")
	expect(d.S.is_flag("case_started"), "S0002 사건 기록 생성")
	expect(d.S.is_flag("igyeom_link") and d.S.is_flag("heard_pass_road") and d.case_fn.jumo_asked() >= 2, "v3.2 주모 물음 → 이겸 연결 · 고갯길")
	expect(d.case_fn.summary().slice(0, 4) == Array(d.case_fn.FIRST_RECORD), "v3.2 첫 기록 네 줄")
	# S0004 고갯길(단서 셋 이상이면 고갯마루 아래에서 S0005 첫 조우)
	for id in ["cake_1", "cake_2", "cake_3", "torn_skirt"]: await go(id)
	expect(d.case_fn.cake_order.map(func(x): return x[1]) == [1, 2, 3], "v3.2 떡 셋 — 찾은 차례대로 첫째·둘째·셋째 말")
	await go("blood")
	await _frames(20)
	await _idle()
	for id in ["tracks", "basket"]:
		if not d.S.has_clue(id): await go(id)
	if not d.S.is_flag("first_encounter"):
		await walk_to("first_seen"); await _frames(30); await _idle()
	expect(d.S.is_flag("first_encounter"), "S0005 첫 조우")
	expect(d.case_fn.first_result in ["retreated", "repelled", "escaped", "lose"] and d.case_fn.first_result != "win", "첫 조우 — 범을 죽이지 않고 끝 (%s)" % d.case_fn.first_result)
	expect(d.S.has_clue("first_sight") and String(d.data.clues.first_sight.title) == "고갯마루의 범", "기록: 고갯마루의 범")
	expect(d.S.knows("K_FOOD"), "K_FOOD(떡·광주리)")
	# §23 어머니의 과거 장면 — 원작 장면(beat)으로는 남고, 기록책은 사실로 적지 않는다
	expect(d.S.is_flag("beat_mother_harmed") and d.S.is_flag("past_scene_seen") and not d.S.has_clue("pass_memory"), "과거 장면을 보았고 기록 단서로 남기지 않는다")
	expect(d.S.notes.has(d.case_fn.PAST_KEEP), "기록에는 빈 광주리와 피, 큰 짐승 흔적만")
	snapshot("after S0005")
	# S0003 오누이(v3.2 §12: 세 물음 — 지난밤 목소리는 들은 대로, K_MIMIC은 아직)
	await go("nui")
	expect(d.S.is_flag("met_kids"), "S0003 오누이")
	await shot("s0003_house")
	expect(d.S.has_clue("voice_at_night") and d.S.is_flag("voice_at_night") and not d.S.knows("K_MIMIC"), "어젯밤의 목소리(들음) — K_MIMIC 아님")
	await go("hearth")
	await go("kneading")
	expect(d.S.has_clue("mother_route") and not d.actors.has("mother") and not d.case_fn.has_method("mother_flashback"), "함지: 기록만(어머니 회상 없음)")
	# S0006 — §28 방앗간(주인과 말하며 밀가루 바닥을 본다) → §29 연결 추론 → §30 흰 발자국 → §27 포수(역할 나누기)
	await go("miller")
	expect(d.S.is_flag("mill_talked") and d.S.has_clue("flour_sack") and d.S.has_clue("flour_prints") and d.S.is_flag("flour_prints"), "방앗간: 주인 말 · 밀가루 바닥(flour_prints)")
	expect(d.S.knows("K_FLOUR"), "K_FLOUR(흰 앞발)")
	expect(d.S.is_flag("link_inferred") and d.S.knows("K_MIMIC") and d.case_fn.summary().has(d.case_fn.LINK_LINE), "§29 연결 추론(목소리·밀가루·첫 조우)")
	await walk_to("white_trail_a")
	for i in 240:
		if d.runner.busy or d.S.is_flag("tiger_house_suspected"): break
		await _frames(1)
	await _idle()
	expect(d.S.is_flag("tiger_house_suspected") and d.S.has_clue("white_trail"), "§30 흰 발자국 — 집 쪽이다(tiger_house_suspected)")
	await go("hunter")
	expect(d.S.is_flag("hunter_met") and d.S.has_clue("hunter_word") and d.S.is_flag("hunter_watch"), "§27 포수 — 물음·역할 나누기(hunter_watch)")
	await go("hunter")
	await go("claw")
	expect(d.S.knows("K_CLIMB"), "K_CLIMB(긁힌 껍질)")
	await go("barn")
	await go("territory_edge")
	expect(d.S.knows("K_TERRITORY"), "K_TERRITORY(숲속 빈터)")
	d.ui.journal_show(d.journal_data())
	await shot("journal", 10)
	d.ui.journal_close()
	if branch == "B":
		await go("oil_wife")
		expect(d.S.has("ITM_LIFE_002"), "참기름 삼")
	if branch == "C":
		prefer = ["횃불", "떡을 좀"]
		await go("jumo")
		prefer = []
		expect(d.S.has("ITM_TOOL_002"), "횃불 얻음")
	snapshot("before night")
	# 밤(v3.2 §3.2: 주막 잠이 아니라 외딴집에서 해 지기를 기다린다)
	expect(not d.case_fn.has_method("rest"), "주막 잠(rest) 필수 흐름 없음")
	prefer = ["여기서 기다린다"]
	await go("dusk_wait")
	prefer = []
	expect(d.S.phase == "night", "외딴집에서 기다리고 밤")
	await walk_to("yard")
	await _frames(20); await _idle()
	match branch:
		"A":
			pass
		"B":
			prefer = ["참기름"]
			await go("back_step")
			prefer = []
			expect(bool(d.S.world.get("oil_on_step", false)), "쪽문 디딤돌에 참기름")
		"C":
			await go("nui")
			expect(d.S.is_flag("kids_warned"), "아이들에게 일렀다(문을 열지 말지는 아이들이 정한다)")
			expect(not d.S.is_flag("kids_in_tree"), "플레이어가 아이들을 나무로 올려 보내지 않는다")
			prefer = ["떡"]
			await go("cake_bait")
			prefer = []
			expect(bool(d.S.world.get("cake_bait", false)), "오솔길에 떡")
			prefer = ["횃불"]
			await go("yard_torch")
			prefer = []
			expect(bool(d.S.world.get("torch_lit", false)), "횃대 불")
	snapshot("night prep")
	await shot("night_yard")
	# S0007 → S0008
	prefer = ["숨어서 기다린다", "떡 냄새 쪽으로" if branch == "C" else "막아선다", "횃불을 치켜든다", "다시 일어선다", "하늘을 올려다본다"]
	_combat_shot = false
	_watch_shots()
	await go("house_door")
	await _idle()
	var waited := 0
	while (d.S.phase != "done" or d.ui.modal) and waited < 20000:
		await get_tree().process_frame; waited += 1
		if waited % 600 == 0: _log("기다리는 중 phase=%s busy=%s combat=%s" % [d.S.phase, d.runner.busy, d.combat_view.active])
	snapshot("end")
	await shot("after", 40)
	var o := String(d.S.vars.get("CASE_NAMWON_OUTCOME", ""))
	expect(o == branch, "결말 %s (얻은 값 %s, %s)" % [branch, o, d.S.vars.get("CASE_NAMWON_DETAIL", "")])
	expect(String(d.S.vars.get("MAIN_MASTER_TRACE", "")) == "HANYANG", "S0010 MAIN_MASTER_TRACE = HANYANG")
	expect(bool(d.S.vars.get("SKILL_BEAST_TRACE", false)), "S0010 SKILL_BEAST_TRACE")
	expect(d.S.seen.has("S0009") and d.S.seen.has("S0010") and d.S.seen.has("S0011"), "S0009 동아줄·S0010 아침·S0011 밤하늘 장면")
	check_v3()
	# 지역 변화: 수수밭이 붉다(모든 갈래). 잔칫상·떡 공양은 없다(범을 잡은 사람이 없다)
	expect(d.props.has("p_sorghum_red") and d.props.p_sorghum_red.get("want", false), "지역 변화 — 붉은 수수밭")
	for pid in ["p_feast", "p_offering", "p_jeogori_c"]: expect(not d.props.has(pid), "옛 결말 소품 없음 " + pid)
	expect(d.actors.has("merchant_a") and d.actors.merchant_a.shown, "장꾼이 다시 다닌다")
	_log("vars=%s" % JSON.stringify(_case_vars()))
	_log("seen=%s" % JSON.stringify(d.S.seen.keys()))
	Engine.time_scale = 1.0
	if _fails.is_empty(): printerr("STORYTEST PASS namwon:%s outcome=%s detail=%s time=%.0fs" % [branch, o, d.S.vars.get("CASE_NAMWON_DETAIL", ""), (Time.get_ticks_msec() - _t0) / 1000.0])
	else: printerr("STORYTEST FAIL namwon:%s fails=%s" % [branch, JSON.stringify(_fails)])
	d.main._quit()

# v3 판정: 원작 장면 순서 · 범을 죽이지 않음 · 입양 결말 없음 · 기록 · 결말 변수
func check_v3() -> void:
	var want: Array = []
	for b in load("res://story/namwon/namwon_data.gd").FIXED_BEATS: want.append(String(b.id))
	var got: Array = d.case_fn.beats_seen()
	_log("beats=%s" % ",".join(got))
	expect(got == want, "FIXED_BEATS 순서대로 모두 (%d/%d)" % [got.size(), want.size()])
	var det := String(d.S.vars.get("CASE_NAMWON_DETAIL", ""))
	expect(det in ["A_hold", "A_down", "B_hold", "B_down", "C"] and det.begins_with(branch), "갈래 세부 %s — 범을 죽이는 결말 없음" % det)
	for e in d.runner.trace:
		if e[0] == "combat_result" or (e[0] == "outcome" and String(e[1]).ends_with("win")): _fail("범을 쓰러뜨린 기록 " + str(e))
	expect(d.S.is_flag("kids_gone") and not d.S.is_flag("kids_taken"), "아이들은 하늘로 — 마을이 거두지 않는다")
	expect(not (d.actors.nui.shown or d.actors.au.shown), "끝난 뒤 오누이가 마을에 없다")
	expect(d.S.has_clue("sky_rise") and String(d.data.clues.sky_rise.text) == "아이 둘이 하늘로 올라가는 것을 보았다." and String(d.data.clues.sky_rise.get("kind", "fact")) == "fact",
		"설화록: “아이 둘이 하늘로 올라가는 것을 보았다.” 확인")
	for id in ["disguise_seen", "door_tricks", "kids_tree", "reflection", "kids_lie", "axe_slip", "prayer", "rotten_rope", "two_lights"]:
		expect(d.S.has_clue(id), "본 장면 기록 " + id)
	expect(not d.S.has_clue("pass_memory"), "어머니의 과거 장면은 기록 단서가 아니다(v3.2 §23)")
	expect(d.S.is_flag("kids_asked"), "S0010 마을 사람들이 아이들 일을 모른다")
	expect(bool(d.S.vars.get("CASE_NAMWON_COMPLETE", false)), "CASE_NAMWON_COMPLETE(숙련 해금)")
	# v3.2 결정 2 · §67: 남원 완료 보상은 짐승 흔적 읽기 하나 — 받아밀기는 남원으로 열리지 않는다
	expect(bool(d.S.vars.get("SKILL_BEAST_TRACE", false)) and not bool(d.S.vars.get("SKILL_GUARD_SHOVE", false)), "남원 완료: 짐승 흔적 읽기만 · 받아밀기 아님")
	# 글: 범을 잡았다·아이들을 거뒀다는 말이 남아 있지 않다(기록책·결말 카드·고을 사람 반응·소문)
	var bad := ["쓰러뜨렸", "때려잡", "거뒀", "거두었", "거둔다", "칼에 맞았", "목이 부러졌", "잔칫날", "숟가락 둘"]
	var texts: Array = []
	texts.append_array(d.case_fn.summary())
	texts.append_array(d.case_fn.ending_data().paragraphs)
	texts.append(String(d.case_fn.ending_data().title))
	for r in load("res://story/rumors_data.gd").RUMORS:
		if String(r.get("var", "")) == "CASE_NAMWON_OUTCOME":
			for k in r.lines: texts.append(String(r.lines[k]))
	for o in load("res://story/ambient_talk_data.gd").OUTCOME:
		if String(o.get("var", "")) == "CASE_NAMWON_OUTCOME":
			for k in o.get("lines", {}): texts.append(str(o.lines[k]))
			for k in o.get("lines_hage", {}): texts.append(str(o.lines_hage[k]))
	for a in d.data.actors:
		for t in a.get("talk", []): texts.append(JSON.stringify(t))
	var hit := []
	for t in texts:
		for w in bad:
			if String(t).contains(w): hit.append("%s ← %s" % [w, String(t).left(40)])
	expect(hit.is_empty(), "범 처치·입양 글 없음 %s" % JSON.stringify(hit))

func _case_vars() -> Dictionary:
	var o := {}
	for k in ["CASE_NAMWON_OUTCOME", "CASE_NAMWON_DETAIL", "MAIN_MASTER_TRACE", "SKILL_BEAST_TRACE"]: o[k] = d.S.vars.get(k)
	return o

# ---- 전투 봇: 덮치기 예고엔 옆으로, 앞발 예고엔 뒤로 구르고, 빈틈(착지·앞발 뒤·경직·먹기)에 벤다 ----
func combat_bot() -> Dictionary:
	var b = d.combat_view.battle
	var pl = b.player; var tg = b.tiger
	var v: Vector2 = tg.pos - pl.pos
	var dist := v.length()
	var dir := v / maxf(dist, 0.001)
	var out := { move = Vector2.ZERO, held = {}, run = false }
	_bot_dodge_cd -= 1.0 / 60.0
	_log_t += 1.0 / 60.0
	if b.time > 6.0 and not _combat_shot:
		_combat_shot = true
		shot("combat_%s" % d.combat_view._arena.get("id", ""), 2)
	if _log_t > 5.0:
		_log_t = 0.0
		_log("전투 t=%.0f 나 hp=%.0f st=%.0f %s (%.1f,%.1f) / 범 hp=%.0f %s (%.1f,%.1f) 거리 %.1f fps=%d" % [b.time, pl.hp, pl.st, pl.state, pl.pos.x, pl.pos.y, tg.hp, tg.state, tg.pos.x, tg.pos.y, dist, Engine.get_frames_per_second()])
	if not pl.alive or tg.state in ["gone", "dead"]: return out
	if bot_wait_first and tg.stats.pounces == 0 and b.time < 10.0: return out
	var open: bool = tg.state in ["land", "stagger", "hit", "stunned", "getup", "eat", "toBait", "retreat", "retreatStagger", "backoff", "roar", "territory", "home"] \
		or (tg.state == "swipe" and tg.t > 0.14)
	if tg.state == "crouch" and _bot_dodge_cd <= 0.0 and dist < 11.0 and pl.st >= 25.0:
		_bot_dodge_cd = 0.7
		out.move = Vector2(-dir.y, dir.x); out.held = { dodge = true }
		return out
	# 막기 안내(L)가 떠 있으면 안내대로 앞발을 막는다(실제로 막아야 안내가 끝난다)
	var lhint: bool = d.onboard != null and d.onboard.hint_key() == "COMBAT_GUARD"
	if lhint and tg.state in ["swipeWind", "swipe"] and dist < 4.5:
		out.held = { guard = true }; return out
	var skl: bool = d.main.args.has("allskills")   # 숙련 시험: 막기를 늦게 눌러 받아밀기, 멀 때 걸으며 빠른 투척
	if skl and tg.state == "swipeWind" and dist < 4.0:
		if tg.t < 0.22: out.move = -dir * 0.2; return out
		out.held = { guard = true }; return out
	if skl and dist > 5.0 and pl.bait > 0 and fmod(b.time, 9.0) < 0.05:
		out.move = dir; out.held = { item = true }; return out
	if tg.state == "swipeWind" and dist < 4.0:
		if _bot_dodge_cd <= 0.0 and pl.st >= 25.0:
			_bot_dodge_cd = 0.6
			out.move = -dir; out.held = { dodge = true }
		else: out.held = { guard = true }
		return out
	if tg.state == "swipe" and tg.t <= 0.14 and dist < 4.0:
		out.held = { guard = true }; return out
	if dist > 2.0:
		# 막혀 서 있으면(기둥·나무) 옆으로 비켜 돈다
		if _bot_last.distance_to(pl.pos) < 0.01: _bot_stuck += 1.0 / 60.0
		else: _bot_stuck = 0.0
		_bot_last = pl.pos
		var side := 1.0 if fmod(_bot_stuck, 2.4) < 1.2 else -1.0
		out.move = dir if _bot_stuck < 0.4 else (dir * 0.3 + Vector2(-dir.y, dir.x) * side).normalized()
		if _bot_stuck > 0.4 and int(_bot_stuck * 60.0) % 120 == 0:
			_log("봇 막힘 (%.1f,%.1f) blocked=%s h=%.2f" % [pl.pos.x, pl.pos.y, d.world.blocked(pl.pos.x, pl.pos.y, 0.375), d.world.height_at(pl.pos.x, pl.pos.y)])
		out.run = dist > 3.5
		return out
	if bot_passive:
		out.move = -dir * 0.3   # 베지 않는다 — 곁에서 버틴다
		return out
	if open or pl.st > 40.0:
		_bot_tap += 1
		out.held = { attack = (_bot_tap % 6) < 2 }
		out.move = dir * 0.15
		return out
	out.move = -dir   # 기력을 아끼며 물러선다
	return out
