# 대본 시험(--storytest=namwon:A|B|C) — 사건을 처음부터 끝까지 한 결말로 몰아 본다.
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

func _init(director, spec: String) -> void:
	d = director
	var p := spec.split(":")
	branch = (p[1] if p.size() > 1 else "A").to_upper()
	name = "story_test"

func begin() -> void:
	d.ui.auto = true
	d.ui.auto_choice = choose
	Engine.time_scale = float(d.main.args.get("storyspeed", "2.5"))
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
			await shot("ending", 1); return

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
	# S0004 고갯길(단서 셋 이상이면 고갯마루 아래에서 S0005 첫 조우)
	for id in ["cake_1", "cake_2", "cake_3", "torn_skirt"]: await go(id)
	await go("blood")
	await _frames(20)
	await _idle()
	for id in ["tracks", "basket"]:
		if not d.S.has_clue(id): await go(id)
	if not d.S.is_flag("first_encounter"):
		await walk_to("first_seen"); await _frames(30); await _idle()
	expect(d.S.is_flag("first_encounter"), "S0005 첫 조우")
	expect(d.S.knows("K_FOOD"), "K_FOOD(떡·광주리)")
	snapshot("after S0005")
	# S0003 오누이
	await go("nui")
	expect(d.S.is_flag("met_kids"), "S0003 오누이")
	await shot("s0003_house")
	await go("nui")
	expect(d.S.knows("K_MIMIC"), "K_MIMIC(문밖의 목소리)")
	await go("hearth")
	await go("kneading")
	# S0006 추가 조사
	await go("miller")
	await go("flour_prints")
	expect(d.S.knows("K_FLOUR"), "K_FLOUR(흰 발자국)")
	await go("hunter")
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
	# 쉬기 → 밤
	prefer = ["하룻밤"]
	await go("jumo")
	prefer = []
	expect(d.S.phase == "night", "주막에서 쉬고 밤")
	await walk_to("yard")
	await _frames(20); await _idle()
	match branch:
		"A":
			pass
		"B":
			prefer = ["큰 나무 위로"]
			await go("nui")
			prefer = []
			expect(d.S.is_flag("kids_in_tree"), "아이들 나무 위")
			prefer = ["참기름"]
			await go("claw")
			prefer = []
			expect(bool(d.S.world.get("oil_on_tree", false)), "밑동에 참기름")
		"C":
			prefer = ["속지 말라"]
			deny = ["큰 나무 위로"]
			await go("nui")
			prefer = []; deny = []
			expect(d.S.is_flag("hand_test"), "손을 보라 일렀다")
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
	prefer = ["숨어서 기다린다", "숨죽여", "횃불을 치켜든다", "뒤에서 덮친다", "다시 일어선다", "말없이"]
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
	expect(d.S.seen.has("S0009") and d.S.seen.has("S0010"), "S0009·S0010 장면")
	# 지역 변화 소품이 섰는가
	var want_props: Array = { "A": ["p_feast"], "B": ["p_feast"], "C": ["p_offering", "p_jeogori_c"] }[branch]
	for pid in want_props:
		expect(d.props.has(pid) and d.props[pid].get("want", false), "지역 변화 소품 " + pid)
	expect(d.actors.has("merchant_a") and d.actors.merchant_a.shown, "장꾼이 다시 다닌다")
	_log("vars=%s" % JSON.stringify(_case_vars()))
	_log("seen=%s" % JSON.stringify(d.S.seen.keys()))
	Engine.time_scale = 1.0
	if _fails.is_empty(): printerr("STORYTEST PASS namwon:%s outcome=%s detail=%s time=%.0fs" % [branch, o, d.S.vars.get("CASE_NAMWON_DETAIL", ""), (Time.get_ticks_msec() - _t0) / 1000.0])
	else: printerr("STORYTEST FAIL namwon:%s fails=%s" % [branch, JSON.stringify(_fails)])
	d.main._quit()

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
	if open or pl.st > 40.0:
		_bot_tap += 1
		out.held = { attack = (_bot_tap % 6) < 2 }
		out.move = dir * 0.15
		return out
	out.move = -dir   # 기력을 아끼며 물러선다
	return out
