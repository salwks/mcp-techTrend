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
var _night_choices: Array = []  # 밤의 문 ~ 탈출 사이에 플레이어에게 물은 것(없어야 한다 — 탈출은 누이가 정한다)

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
	if d.S.is_flag("night_wait_started") and not d.S.is_flag("kids_escape_started"): _night_choices.append(labels.duplicate())
	for want in prefer:
		for i in labels.size():
			if labels[i] != "" and String(labels[i]).contains(want): return i
	for i in labels.size():
		var l := String(labels[i])
		if l == "": continue
		var bad := false
		for x in deny + ["그만", "다음에", "문 꼭", "문 걸고", "아직이다", "아직 준비", "칼을 뽑는다", "지금 뛰어나간다", "그만둔다"]:
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
	if _review or not d.main.args.has("storyshots") or DisplayServer.get_name() == "headless" or d.main.args.has("noreview"): return
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

# 화면 검토(--storyshots, 화면이 있을 때): 해 질 무렵 귀환부터(ACT 6~9) 대사·자막·암전·움직임을 실제 길이로(시간 배율 1)
func _real_night() -> void:
	if not d.main.args.has("storyshots") or DisplayServer.get_name() == "headless": return
	d.ui.auto_real = true
	Engine.time_scale = 1.0
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	if d.onboard != null:   # 순간이동으로 온 시험이라 이동·달리기 안내가 남아 있다 — 화면 검토에선 내린다(실제 놀이에선 이미 끝난 안내)
		for k in ["MOVE", "RUN", "TALK", "INSPECT", "JOURNAL", "MAP"]: d.onboard.seen_now(k)
	_log("REAL night begin")

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
	if branch in ["NA", "NB", "NC"]:   # 화면 다듬기용: 밤(ACT 7~9)만 — 준비를 마친 상태에서 S0007부터(--nightstop=플래그에서 멈춤)
		await _night_only(branch.substr(1))
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
	expect(d.S.is_flag("hunter_met") and d.S.has_clue("hunter_word") and not d.S.is_flag("hunter_watch"), "§27 포수 — 물음(역할 나누기는 아직)")
	await go("hunter")
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
	# ---- v3.2 ACT 6 해 질 무렵 귀환(§31·§32) · 포수와 역할 나누기(결정 4) ----
	expect(not d.case_fn.has_method("rest") and not d.case_fn.has_method("night_fall") and not d.case_fn.has_method("climax"), "옛 다리 없음(rest·night_fall·climax)")
	expect(not d.data.objects.any(func(o): return String(o.id) == "dusk_wait") and not d.data.triggers.any(func(t): return String(t.id) == "night_arrive"), "dusk_wait·옛 밤 들머리(night_arrive) 없음")
	expect(not d.S.is_flag("hunter_watch"), "포수 역할 나누기는 낮의 물음이 아니다")
	expect(d.case_fn.night_ready(), "해 질 무렵 귀환이 열린다(night_ready)")
	prefer = { "A": [], "B": ["흔적을"], "C": ["대답하지"] }[branch]
	_real_night()
	await walk_to("yard")
	for i in 600:
		if d.S.is_flag("dusk_prep"): break
		await _frames(1)
	await _idle()
	prefer = []
	expect(d.S.is_flag("dusk_return_seen") and d.S.is_flag("kids_warned") and d.S.is_flag("dusk_prep"), "§31~§32 귀환·경고 → 준비(kids_warned·dusk_prep)")
	expect(d.case_fn.dusk_choice == { "A": "not_yet", "B": "trace", "C": "silent" }[branch], "§31 대답 %s" % d.case_fn.dusk_choice)
	expect(d.S.is_flag("hunter_watch") and d.S.is_flag("hunter_role_dusk"), "결정 4 포수 역할 나누기(해 질 무렵) — hunter_watch")
	expect(d.main.hour >= 18.4 and d.main.hour <= 22.6, "해 질 무렵 %.2f시" % d.main.hour)
	var dsrc := FileAccess.get_file_as_string("res://story/namwon/namwon_case.gd")
	var dusk_txt := dsrc.substr(dsrc.find("func dusk_return"), dsrc.find("func _hunter_role") - dsrc.find("func dusk_return"))
	var death := ["죽었", "죽은", "돌아가셨", "잡아먹", "살아 있지"]
	expect(not death.any(func(w): return dusk_txt.contains(w)), "§31 어느 대답도 어머니의 죽음을 확정하지 않는다")
	expect(dusk_txt.contains("엄마여도요?") and dusk_txt.contains("…목소리만 듣고 열지 마.") and dusk_txt.contains("엄마 얼굴 보면 되잖아요."), "§32 경고 원문")
	# 준비 시간 — 큰 나무·헛간(낮에 못 봤으면 이때)
	await go("claw")
	expect(d.S.knows("K_CLIMB"), "K_CLIMB(긁힌 껍질)")
	await go("barn")
	match branch:
		"A":
			pass
		"B":
			prefer = ["참기름"]
			await go("back_step")
			prefer = []
			expect(bool(d.S.world.get("oil_on_step", false)), "쪽문 디딤돌에 참기름")
		"C":
			prefer = ["떡"]
			await go("cake_bait")
			prefer = []
			expect(bool(d.S.world.get("cake_bait", false)), "오솔길에 떡")
			prefer = ["횃불"]
			await go("yard_torch")
			prefer = []
			expect(bool(d.S.world.get("torch_lit", false)), "횃대 불")
			expect(d.case_fn.c_ready(), "C 준비(떡 + 먹이 버릇 + 불)")
	expect(not d.S.is_flag("kids_in_tree"), "플레이어가 아이들을 나무로 올려 보내지 않는다")
	snapshot("night prep")
	await shot("night_yard")
	# ---- §34 hide_spot 기다리기 → S0007 밤의 문 → 시간 벌기 → 나무 → 동아줄 ----
	prefer = ["기다린다."]
	_combat_shot = false
	_watch_shots()
	_watch_night()
	await go("night_wait")
	prefer = ["하늘을 올려다본다"]
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
	check_v32_night()
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

func _night_only(b: String) -> void:
	branch = b
	var S = d.S
	S.phase = "explore"
	for k in ["s0000_started", "INTRO_MASTER_VOICE_DONE", "INTRO_NAMWON_TITLE_DONE", "case_started", "met_kids", "first_encounter", "beat_mother_harmed",
			"past_scene_seen", "tiger_house_suspected", "dusk_return_seen", "kids_warned", "dusk_prep", "hunter_watch", "hunter_role_dusk"]: S.flags[k] = true
	S.flags["beats"] = "mother_harmed"
	S.rules = ["K_FOOD", "K_TERRITORY", "K_CLIMB"]
	S.items = { "ITM_TOOL_009": 1, "ITM_WPN_001": 1, "ITM_WPN_002": 1, "ITM_AMMO_001": 12, "ITM_LIFE_001": 3 }
	if b == "B": S.world["oil_on_step"] = true
	if b == "C": S.world["cake_bait"] = true; S.world["torch_lit"] = true
	d.set_hour(21.0)
	d.teleport_to("hide_spot", "left")
	d.case_fn.kids_place()
	d.mark_dirty()
	await _frames(20)
	_real_night()
	_watch_night()
	var stop := String(d.main.args.get("nightstop", "act10_started"))
	d.runner.run([{ "event": "S0007" }])
	for i in 200000:
		await get_tree().process_frame
		if S.is_flag(stop): break
	await _frames(30)
	printerr("STORYTEST PASS night-only %s stop=%s" % [b, stop])
	d.main._quit()

# ---- v3.2 ACT 6~9 밤 감시(대본과 따로 돈다) ----
var nw := { "early_tiger": [], "kids_in_tree": false, "between_seen": false, "between_free": false, "mill": false, "door": false,
	"arrow_set": false, "torch": false, "cues": [], "reveal_t": -1, "max_tiger_y": 0.0 }
func _watch_night() -> void:
	d.sfx_cue.connect(func(id): nw.cues.append(String(id)))
	var hp: Vector2 = d.anchor("hide_spot")
	var mill: Vector2 = d.anchor("mill")
	var step := 0
	for i in 400000:
		await get_tree().process_frame
		var S = d.S
		if S.phase == "done": return
		if S.is_flag("kids_in_tree"): nw.kids_in_tree = true
		# 문이 열리기 전(reveal_tiger) 범의 전신이 화면에 있으면 안 된다 — 범 그림(이야기 인물·전투)이 하나라도 보이면 기록
		if S.is_flag("night_wait_started") and not S.is_flag("tiger_revealed"):
			for id in d.actors:
				var a: Dictionary = d.actors[id]
				if String(a.spec.get("kind", "")) == "tiger" and a.shown and a.ch.visible: nw.early_tiger.append(String(id))
			if d.combat_view.active: nw.early_tiger.append("combat")
		# §39 노크 사이: 조작이 돌아왔나 → 방앗간 쪽으로(가루 소리·그림자) → 집 가까이(“문 열지 마.”) → 숨은 자리
		if S.is_flag("between_knocks_on"):
			if not nw.between_seen:
				nw.between_seen = true
				nw.between_free = not d.blocks_move() and d.free_move
				_log("노크 사이 조작 blocks_move=%s free_move=%s" % [d.blocks_move(), d.free_move])
			if step == 0:
				await _frames(90)   # 숨은 자리에서 조작이 돌아온 모습을 잠깐(화면 검토)
				var q: Vector2 = mill + (hp - mill).normalized() * 30.0
				d.teleport_to(q, "up"); step = 1
			elif step == 1 and d.case_fn.mill_shadow_seen:
				await _frames(150)
				nw.mill = nw.cues.has("flour_rustle")
				d.teleport_to(d.anchor("house_door") + Vector2(1.2, 4.0), "up"); step = 2
			elif step == 2 and d.case_fn.door_warned:
				await _frames(30)
				nw.door = true
				d.teleport_to(hp, "left"); step = 3
		# B: 시간 벌기 싸움 6초쯤 크게 밀린다(체력 20) → 먼 데서 포수의 화살(fail-forward). A는 25초를 끝까지 본다
		if branch == "B" and not nw.arrow_set and S.is_flag("time_line") and d.combat_view.active and not S.is_flag("hunter_arrow") \
				and not S.is_flag("tiger_shoved") and d.combat_view.battle.time > 6.0:
			nw.arrow_set = true
			d.combat_view.battle.player.hp = 20.0
			_log("시험: 플레이어 체력 20 → 포수 화살을 기다린다")
		# C: 횃불을 들고 길을 막는다(조작)
		if S.is_flag("torch_block_on") and not nw.torch:
			nw.torch = true
			await _frames(10)
			d.teleport_to("torch_block", "left")
		if d.actors.has("tiger_night") and S.is_flag("last_stand_done"): nw.max_tiger_y = maxf(nw.max_tiger_y, float(d.actors.tiger_night.y_abs) if not is_nan(d.actors.tiger_night.y_abs) else 0.0)

func check_v32_night() -> void:
	var c = d.case_fn
	var S = d.S
	for k in ["kids_warned", "night_wait_started", "first_knock_seen", "hairy_paw_seen", "tiger_withdrawn", "white_paw_seen", "kids_escape_started", "hunter_watch"]:
		expect(S.is_flag(k), "§74 플래그 " + k)
	expect(nw.kids_in_tree, "§74 kids_in_tree(아이들이 나무에 올랐다)")
	# 문 앞 장면을 한 컷신으로 몰지 않는다 — 첫 손 뒤 조작이 실제로 돌아온다(§39·§71)
	expect(nw.between_seen and nw.between_free and c.between_free, "§39 노크 사이 조작이 돌아온다(blocks_move 거짓)")
	expect(c.between_t >= 15.0 - 0.01 and c.between_t <= 30.5, "§39 자유 이동 15~30초 (%.1f초)" % c.between_t)
	expect(nw.mill and c.mill_shadow_seen, "§39 방앗간 쪽으로 다가가면 가루 소리·흐린 그림자")
	expect(nw.door and c.door_warned and c.night_log.any(func(e): return e[1] == "나그네" and e[2] == "문 열지 마.") and c.night_log.any(func(e): return e[1] == "누이" and e[2] == "네."), "§39 집 가까이 — “문 열지 마.” “네.”")
	# 범은 문이 열릴 때까지 화면 밖·그림자·앞발 일부로만
	expect(nw.early_tiger.is_empty(), "문이 열리기 전 범의 전신이 보이지 않는다 %s" % JSON.stringify(nw.early_tiger.slice(0, 3)))
	# 탈출은 누이가 정한다 — “뒷문으로 가.”가 탈출보다 먼저, 그 사이 플레이어에게 묻지 않는다
	var li := -1; var le := -1; var lb := -1
	for i in c.night_log.size():
		var e: Array = c.night_log[i]
		if e[0] == "say" and e[1] == "누이" and String(e[2]).contains("뒷문으로 가.") and li < 0: li = i
		if e[0] == "say" and e[1] == "누이" and String(e[2]) == "엄마, 우리 뒷간 좀 다녀올게." and lb < 0: lb = i
		if e[0] == "flag" and e[2] == "kids_escape_started" and le < 0: le = i
	expect(li >= 0 and lb > li and le > lb, "§40~§41 누이가 탈출을 정한다(뒷문으로 가 → 뒷간 핑계 → 탈출) %d·%d·%d" % [li, lb, le])
	expect(_night_choices.is_empty(), "밤의 문 ~ 탈출 사이 플레이어 선택 없음 %s" % JSON.stringify(_night_choices))
	# ACT 8 — 갈래가 준비대로 · 죽일 수 없다 · 밀쳐냄으로 끝
	expect(c.branch_now == branch, "§42~§44 준비대로 갈래 %s" % c.branch_now)
	var sh: Array = c.shoves.filter(func(x): return x[0] == branch)
	expect(sh.size() == 1 and float(sh[0][1]) >= 2.9 and float(sh[0][1]) <= 4.0, "§45 범이 3~4m 밀쳐낸다(쓰러뜨리지 않음) %s" % JSON.stringify(c.shoves))
	for e in d.runner.trace:
		if e[0] == "fight" and String(e[1][1]) == "win": _fail("범을 죽인 싸움 " + str(e))
	match branch:
		"A": expect(float(c.fight_lens.get("A", 0.0)) >= 20.0 and float(c.fight_lens.get("A", 0.0)) <= 28.0, "§44 A 약 25초 버티기(%.1f초)" % float(c.fight_lens.get("A", 0.0)))
		"B": expect(c.fight_lens.has("B") and float(c.fight_lens.B) >= 6.0 and float(c.fight_lens.B) <= 18.5, "§42 B 미끄러짐 뒤 짧은 싸움(%.1f초)" % float(c.fight_lens.get("B", 0.0)))
		"C": expect(c.torch_blocked and not c.fight_lens.has("C_fight"), "§43 C 떡 냄새·횃불로 길을 막음(싸움 없이)")
	if branch == "B":
		expect(S.is_flag("hunter_arrow") and not c.arrow_info.is_empty() and c.night_log.filter(func(e): return e[0] == "arrow").size() == 1,
			"결정 4 fail-forward — 크게 밀리자 포수의 화살 한 번 %s" % JSON.stringify(c.arrow_info))
	else:
		expect(not S.is_flag("hunter_arrow"), "잘 버티면 포수의 화살은 없다")
	expect(S.is_flag("time_line") and not S.notes.has(c.TIME_LINE), "ACT 8 목표 한 줄(시간을 벌어야 한다)")
	# ACT 9
	expect(c.axe_hits >= 3 and nw.cues.has("axe_hit"), "§49 도끼 axe_hit %d" % c.axe_hits)
	expect(c.fight_lens.has("last") and float(c.fight_lens.last) >= 4.0, "§50 마지막 개입 — 다시 조작(%.1f초)" % float(c.fight_lens.get("last", 0.0)))
	expect(S.is_flag("last_stand_done") and S.is_flag("act10_started"), "ACT 9 끝 → 기존 ACT 10 동아줄로")
	for id in ["knock", "footstep_heavy", "wind", "flour_rustle"]: expect(nw.cues.has(id), "소리 " + id)
	for l in [["범", "거기 숨어 있었구나."], ["아우", "킥."], ["범", "어떻게 거기까지 올라갔느냐?"], ["누이", "참기름을 바르고 올라왔지."], ["아우", "도끼로 찍고 올라오면 되는데."], ["누이", "아우야!"]]:
		expect(c.night_log.any(func(e): return e[0] == "say" and e[1] == l[0] and e[2] == l[1]), "원문 %s “%s”" % l)
	# §3.3 정답 선공개 문장은 없다
	var src := FileAccess.get_file_as_string("res://story/namwon/namwon_case.gd") + FileAccess.get_file_as_string("res://story/namwon/namwon_data.gd")
	expect(not src.contains("네 발로 걷는다") and not src.contains("머리에 수건을 썼다. 그런데"), "§3.3 “…네 발로 걷는다.” 문장이 없다")
	_log("밤 조작 비율(귀환~기도 앞, 시험 시간) %.0f%% free=%.1f cut=%.1f · 노크 사이 %.1f초 · 싸움 %s" % [c.control_share() * 100.0, c.ctl_time.free, c.ctl_time.cut, c.between_t, JSON.stringify(c.fight_lens)])

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
