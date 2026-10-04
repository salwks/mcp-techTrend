# 사건 「산길의 실종」 — 데이터로 쓰기 번거로운 장면(여는 화면·회상·밤의 문·세 갈래 결말·다음 날 아침)과 기록책·결말 카드.
# 웹 seolhwa/src/story/case_sanggil.js·common.js·journal.js 이식(대사는 시나리오 §8에 맞춰 줄임).
# 데이터(namwon_data.gd)의 { "call": "이름" }과 조건식 fn('이름')이 이 함수들을 부른다.
extends RefCounted

const D := preload("res://story/namwon/namwon_data.gd")
const TTEOK := D.TTEOK
const OIL := D.OIL
const TORCH := D.TORCH
const CASE_TITLE := "산길의 실종"
const PATH_CLUES := ["torn_skirt", "blood", "tracks", "basket"]

var d      # story_director
var S:
	get: return d.S

func _init(director) -> void:
	d = director

# 데이터 단계 실행(같은 명령 집합) — 이 사건 함수 안에서 짧게 쓰려고
func R(steps: Array) -> void:
	await d.runner.exec(steps, d.runner.gen)

func flag(k: String, v = true) -> void:
	S.flags[k] = v; d.runner.log_line("flag", [k, v]); d.mark_dirty()

func f(k: String) -> bool: return S.is_flag(k)

# ---------------------------------------------------------------------------
# 판정
# ---------------------------------------------------------------------------
func cakes_found() -> int:
	var n := 0
	for k in ["cake_1", "cake_2", "cake_3"]:
		if f(k): n += 1
	return n

func path_clues() -> int:
	var n := cakes_found()
	for c in PATH_CLUES:
		if S.has_clue(c): n += 1
	return n

func can_rest() -> bool:
	return f("case_started") and (f("first_encounter") or S.clues.size() >= 5)

func warn_level() -> int:
	if not S.knows("K_MIMIC"): return 0
	return 2 if S.knows("K_FLOUR") else 1

func c_ready() -> bool:
	return f("hand_test") and bool(S.world.get("cake_bait", false)) and S.knows("K_TERRITORY") and (S.has(TORCH) or bool(S.world.get("torch_lit", false)))

func route_is(r: String) -> bool:
	return String(S.flags.get("route", "")) == r

# ---------------------------------------------------------------------------
# 첫 사건 단서 안내 단계(보강서 §14·§28 CASE_NAMWON_GUIDANCE_STAGE): 0 첫 단서 전 · 1 첫 단서 · 2 둘째 · 3 일반 조사
#   첫째 = 강한 안내(다음 단서 쪽을 한 줄로) · 둘째 = 먹점만(자세히면 약한 한 줄) · 셋째부터 자력 조사. 먹점 거리는 onboarding.gd가 단계를 읽는다
# ---------------------------------------------------------------------------
const GUIDE := "CASE_NAMWON_GUIDANCE_STAGE"
var last_guide_line := ""   # 시험 기록
func guidance(id: String) -> void:
	var st := int(S.flags.get(GUIDE, 0))
	var n := mini(3, path_clues())
	if n <= st: return
	S.flags[GUIDE] = n
	d.runner.log_line("guidance", n)
	var help := String(load("res://scripts/story/game_settings.gd").help())
	if help == "minimal" or path_clues() >= 7: return
	if n == 1:
		# 첫 단서: 다음 단서 방향을 약하게(떡은 고개 위로 이어진다)
		var line := "고갯길 위쪽에도 같은 떡이 보인다." if id.begins_with("cake") and cakes_found() < 3 else "고갯길 위쪽에도 무언가 떨어져 있다."
		last_guide_line = line
		await d.ui.caption(line, 2.6)
	elif n == 2 and help == "detailed":
		last_guide_line = "흔적은 고개 쪽으로 이어지는 것 같다."
		await d.ui.caption(last_guide_line, 2.2)

# 정체 감지(보강서 §25, onboarding.gd가 단계마다 부른다): 1 기록책 물음 강조 · 2 주변 사람의 한 줄 · 3 이미 본 단서를 다시 잇는 한 줄
func stall_hint(stage: int) -> String:
	if S.phase == "night":
		return ["", "오늘 밤 범이 오기 전에 무엇을 준비할 수 있는가.", "주모  “불이라도 하나 챙겨 가시오. 짐승은 불을 꺼린다던데.”", "범은 떡 냄새를 따라왔고, 빈터 밖까지는 쫓지 않았다."][mini(stage, 3)]
	if path_clues() == 0:
		return ["", "떡장수는 마지막으로 어디로 갔는가.", "포수  “고개 쪽 길은 요새 아무도 안 넘으려 하오.”", "떡장수는 고개 너머 장으로 가는 길이었다."][mini(stage, 3)]
	if not f("first_encounter"):
		return ["", "고갯마루 너머에는 무엇이 있었는가.", "", "떡이 한 방향으로 이어져 있었다."][mini(stage, 3)]
	if not f("met_kids"):
		return ["", "집에 남은 아이들은 어떻게 지내는가.", "주모  “그 집 애들은 누가 들여다보기나 하는지…”", "집에는 아이 둘이 남아 있다고 했다."][mini(stage, 3)]
	return ["", "범은 무엇에 끌리고, 무엇을 꺼리는가.", "", "범은 떡 냄새를 따라 내려왔다."][mini(stage, 3)]

func check_food() -> void:
	if S.knows("K_FOOD"): return
	var n := cakes_found()
	if (S.has_clue("basket") and n >= 1) or n >= 3:
		d.learn_rule("K_FOOD")
	elif n == 3: d.ui.toast("떡 세 개. 고개마다 하나씩…", "info")

func on_clue(id: String) -> void:
	if id in ["cakes", "torn_skirt", "blood", "tracks", "basket"]: S.seen["S0004"] = true
	if id in ["flour_prints", "claw_marks", "territory", "hunter_word", "flour_sack"]: S.seen["S0006"] = true

func start_case(route: String) -> void:
	if f("case_started"): return
	flag("case_started"); flag("route", route)
	d.learn_clue("rumor", true)
	d.ui.toast("새 사건 — 「%s」" % CASE_TITLE, "journal")
	if d.onboard != null: d.onboard.on_case_started()

# 이전 결과로 범이 다쳤으면 체력 낮춰 시작
func combat_mods(_arena: String, mods: Dictionary) -> Dictionary:
	var m := mods.duplicate()
	if f("tiger_wounded"): m.hpRatio = minf(float(m.get("hpRatio", 1.0)), 0.85)
	return m

func on_load() -> void:
	# 절정 도중 저장은 밤 준비 상태로 되돌린다(웹과 같음)
	if f("climax_started") and String(S.vars.get("CASE_NAMWON_OUTCOME", "")) == "":
		S.flags.erase("climax_started")
	if S.phase == "night": load_tiger_story()
	kids_place()
	# 여는 장면 도중 저장에서 이어 하면: 남원 전경·제목은 건너뛴 것으로
	if f("s0000_started") and not f("INTRO_NAMWON_TITLE_DONE") and S.phase != "start":
		S.flags["INTRO_MASTER_VOICE_DONE"] = true
		if Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("s0000_vista")) > 400.0: S.flags["INTRO_NAMWON_TITLE_DONE"] = true

# 호랑이 이야기 프레임(knock·sniff·climb_try·slip + 변장 :d, 15쪽 약 60MB)은 절정 직전(밤으로 넘어갈 때 암전 속)에 읽는다
func load_tiger_story() -> void:
	SpriteChar.load_bank("tiger", "frames.json")
	SpriteChar.merge_bank("frames_story.json", ["tiger"])

# ---------------------------------------------------------------------------
# 도입부(보강서 v1.0 §3~§9) — S0000 남원으로 가는 길 · S0001 남원 전경과 제목
# ---------------------------------------------------------------------------
# 건너뛸 수 있는 기다림(Esc·Space·Enter — onboarding.skip)
func _sw(sec: float) -> bool:
	var ob = d.onboard
	if ob == null: await d.wait(sec); return false
	var t := 0.0
	if d.ui.auto: sec = minf(sec, 0.05)
	while t < sec:
		if ob.skip: return true
		await d.get_tree().process_frame
		t += d.get_process_delta_time() / maxf(Engine.time_scale, 0.01)
	return ob.skip

# S0000-A: 검은 화면, 이겸의 세 문장 → 기록책 마지막 장 → 덮으며 길 위에서 화면이 열린다(긴 회상 없음)
func prologue_open() -> void:
	var ob = d.onboard
	if ob != null: ob.skippable = true; ob.skip = false
	d.ui._fade.color.a = 1.0
	d.main.rig.update(0, d.main.player_pos, d.main.player.facing, null, true)
	d.main.player.play("idle", true)
	if not await _sw(0.8):
		for l in ["“본 것은 본 대로.”", "“들은 것은 누가 말했는지.”", "“모르는 것은 모른다고.”"]:
			if ob != null and ob.skip: break
			await d.ui.center_text(l, 2.1)
			if await _sw(0.35): break
	flag("INTRO_MASTER_VOICE_DONE")
	d.ui.title_card_stop()
	d.ui.book_page(["남원", "이겸", "“남원에서 확인할 것이…”"], 0.0)
	await d.ui.fade(false, 0.4 if (ob != null and ob.skip) else 1.1)
	await _sw(1.6)
	await d.ui.book_close()
	if ob != null: ob.skippable = false; ob.skip = false

var _roadside_t := -1.0
func since_roadside() -> float:
	if not f("roadside_seen"): return 0.0
	if _roadside_t < 0.0: _roadside_t = Time.get_ticks_msec() / 1000.0
	return Time.get_ticks_msec() / 1000.0 - _roadside_t

# S0000-C: 남원 쪽에서 나그네 둘이 걸어와 지나간다 — 붙잡지 않는다(조작을 막지 않도록 따로 돈다), 시스템 효과 없음
func travellers() -> void:
	if f("INTRO_CONFLICTING_RUMOR_HEARD"): return
	flag("INTRO_CONFLICTING_RUMOR_HEARD")
	_travellers_go()

func _travellers_go() -> void:
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var from: Vector2 = d.anchor("trav_from")
	if pp.distance_to(from) < 14.0: from = pp + (from - pp).normalized() * 18.0
	d.spawn_actor("trav_a", "traveler", [from.x, from.y], "right", "길손", "")
	d.spawn_actor("trav_b", "peddler", [from.x - 1.2, from.y + 1.1], "right", "동행", "")
	var path := ["trav_mid", "trav_to"] if pp.x < d.anchor("trav_mid").x + 4.0 else ["trav_to"]
	d.move_actor("trav_a", path, 1.45, "walk", "walk")
	d.move_actor("trav_b", path.map(func(q): return d.anchor(q) + Vector2(-1.0, 1.1)), 1.45, "walk", "walk")
	# 플레이어 곁을 지날 무렵 말이 들린다
	for i in 400:
		await d.get_tree().process_frame
		if not d.actors.has("trav_a"): return
		if Vector2(d.actors.trav_a.pos.x, d.actors.trav_a.pos.z).distance_to(Vector2(d.main.player_pos.x, d.main.player_pos.z)) < 13.0: break
	await d.ui.caption("길손  “그 기록하던 양반 말이야. 한양으로 갔다던데.”", 2.8)
	await d.ui.caption("동행  “한양? 지리산으로 들어갔다던데?”", 2.6)
	await d.ui.caption("길손  “내가 들은 건 그렇다니까.”", 2.4)
	for i in 1200:
		await d.get_tree().process_frame
		if not d.actors.has("trav_a") or d.actors.trav_a.path.is_empty(): break
	d.despawn_actor("trav_a"); d.despawn_actor("trav_b")

# S0000-D / S0001: 남원 성벽 — 성벽으로 천천히 옮겨 가 「남원」, 이어 「설화록」을 띄운 뒤 플레이어에게 천천히 돌아온다. 건너뛸 수 있다
func vista() -> void:
	var ob = d.onboard
	if ob != null: ob.skippable = true; ob.skip = false
	d.cutscene(true)
	var rig = d.main.rig
	d.camera({ "focus": "east_gate", "distance": 48.0, "pitch": 26.0 })
	var fp: Vector2 = d.anchor("east_gate")
	rig.glide(3.0, Vector3(fp.x, d.main.world.height_at(fp.x, fp.y) + 0.9, fp.y))   # 천천히 떠나 천천히 닿는다
	var skipped: bool = await _sw(3.2)
	if not skipped:
		var tt = d.main.get("_title")
		if tt != null: tt.show_title("남원", true)   # 지명 표시(place_title)와 같은 결
		else: d.ui.title_card("남원", 2.2, 52)
		skipped = await _sw(2.6)
	if not skipped:
		d.ui.title_card("설화록", 2.6, 92)
		skipped = await _sw(2.8)
	d.ui.title_card_stop()
	d.camera(null)
	rig.glide(1.0 if skipped else 3.0)   # 플레이어에게 천천히 돌아온다
	await _sw(1.0 if skipped else 3.0)
	d.cutscene(false)
	if ob != null: ob.skippable = false; ob.skip = false

# 떡가루 함지 — 짧은 회상(떡장수 어머니, 흔적·회상 중심)
func mother_flashback() -> void:
	await d.ui.examine("떡가루 묻은 함지", ["함지 바닥에 떡가루가 말라붙었다.", "새벽에 떡을 쪄 광주리에 담고 나간 자국이다."], "clue")
	d.cutscene(true)
	d.place_actor("mother", "kneading", null, "down")
	flag("show_mother")
	d.anim_actor("mother", "idle")
	await d.wait(0.8)
	await d.move_actor("mother", ["house_door", [-3210.0, -343.0], [-3196.0, -340.0]], 1.4, "walk", "walk")
	flag("show_mother", false)
	d.place_actor("mother", "home")
	await d.ui.caption("…해 지기 전엔 온다고 했다.", 2.0)
	d.cutscene(false)

# ---------------------------------------------------------------------------
# S0005 첫 조우 뒤
# ---------------------------------------------------------------------------
func after_first_encounter() -> void:
	var res := String(d.runner.last.get("first", "retreated"))
	d.learn_clue("first_sight")
	var tg = d.combat_view.battle.tiger
	if tg.hp < float(tg.G().hp) * 0.95: flag("tiger_wounded")
	if res == "lose":
		await d.ui.fade(true, 0.6)
		d.end_combat()
		await d.ui.caption("먹빛 줄무늬. 번뜩이는 눈. 그리고 어둠.", 2.2)
		d.teleport_to("wake_spot", "up")
		d.set_hour(19.5)
		flag("woke_by_hunter")
		await d.ui.fade(false, 0.8)
		await d.ui.say("포수", ["정신이 드시오? 고갯길에 쓰러져 있길래 업어 왔소.", "…그놈을 봤구려."])
		flag("hunter_after_wake")
	elif res == "escaped":
		d.end_combat()
		await d.ui.caption("정신없이 산길로 빠져나왔다. 등 뒤에서 낮은 울음이 따라온다.", 2.6)
	else:
		d.end_combat()
		await d.ui.caption("범은 땅이 울리도록 포효하고, 숲 너머로 사라졌다.", 2.6)
	d.set_hour(maxf(18.2, d.main.hour))
	d.journal_note("범을 보았다")
	# 보강서 §17 관찰 — 본 대로만(“돌진 패턴 해금” 같은 말은 쓰지 않는다)
	await R([{ "observe": "몸을 낮춘 뒤 잠시 멈춘다.", "about": "범" }, { "observe": "그다음 곧장 돌진한다.", "about": "범" }])

# ---------------------------------------------------------------------------
# 주막에서 쉬기 → 밤
# ---------------------------------------------------------------------------
func rest() -> void:
	await d.ui.say("주모", ["건넌방 비어 있소. 눈 좀 붙이시오."])
	await d.ui.fade(true, 0.9)
	load_tiger_story()
	S.phase = "night"
	d.on_phase()
	d.set_hour(22.0)
	d.set_weather("clear")
	d.teleport_to("night_start", "up")
	kids_place()
	await d.wait(0.4)
	await d.ui.fade(false, 0.9)
	await d.ui.caption("달이 떴다…", 2.2)
	d.journal_note("밤이 되었다. 외딴집으로")

# ---------------------------------------------------------------------------
# 밤의 준비
# ---------------------------------------------------------------------------
func kids_place() -> void:
	var tree: bool = f("kids_in_tree") or f("kids_fled_to_tree")
	if S.phase == "night" and tree:
		d.place_actor("nui", "perch_a", 2.7, "down")
		d.place_actor("au", "perch_b", 3.1, "down")
		d.anim_actor("nui", "perch"); d.anim_actor("au", "perch")
	elif S.phase == "night" and f("climax_started"):
		d.show_actor("nui", false); d.show_actor("au", false)
	else:
		d.place_actor("nui", "home"); d.place_actor("au", "home")

func kids_climb() -> void:
	d.place_actor("nui", "perch_a", 1.3, "up")
	d.place_actor("au", "perch_b", 1.7, "up")
	d.anim_actor("nui", "climb"); d.anim_actor("au", "climb")
	await d.wait(1.2)
	kids_place()

func kids_night() -> void:
	var lvl := warn_level()
	await d.ui.say("누이", ["오늘 밤에도 올까요… 그 목소리."])
	await R([{ "choice": "", "loop": true, "options": [
		{ "label": "목소리에 속지 말라 이른다" if lvl > 0 else "아무에게도 문 열지 말라 이른다",
			"when": "not f('kids_warned') and not (fn('warn_level') == 0 and f('warn_tried'))", "do": [{ "call": "warn_kids" }] },
		{ "label": "큰 나무 위로 피신시킨다", "when": "not f('kids_in_tree')", "do": [{ "call": "kids_to_tree", "args": [true] }] },
		{ "label": "집 안으로 들여보낸다", "when": "f('kids_in_tree')", "do": [{ "call": "kids_to_tree", "args": [false] }] },
		{ "label": "문 걸고 기다려라.", "end": true }] }])

func warn_kids() -> void:
	var lvl := warn_level()
	if lvl == 0:
		await d.ui.say("누이", ["어머니 목소리면요?"])
		flag("warn_tried")
		d.ui.toast("아이들을 설득할 말이 부족하다. 그 목소리의 정체를 더 알아야 한다.", "info")
		return
	flag("kids_warned")
	var lines := ["어머니 목소리로 불러도 열지 마라."]
	if lvl == 2:
		lines.append("손을 보여 달라 해라. 허옇고 털 난 손이면 열지 마라.")
		flag("hand_test")
	await d.ui.say("나그네", lines)
	await d.ui.say("누이", ["…손을 보여 달라고 할게요."] if lvl == 2 else ["…안 열게요."])
	d.journal_note("아이들에게 단단히 일렀다")

func kids_to_tree(up: bool) -> void:
	if up:
		await d.ui.say("누이", ["나무 위요? …아우야, 손 꼭 잡아."])
		flag("kids_in_tree")
		d.world_state("kids_in_tree", true)
		await kids_climb()
		if not S.world.get("oil_on_tree", false) and S.knows("K_CLIMB"): d.ui.toast("범은 나무를 탄다. 이대로 괜찮을까…", "info")
	else:
		await d.ui.say("누이", ["네. 문고리 걸고 있을게요."])
		flag("kids_in_tree", false)
		d.world_state("kids_in_tree", false)
		kids_place()

# 큰 나무 + 참기름(물건 쓰기 — scripts/story/interact_data.gd가 '이곳에 사용할 수 있는 물건이 있다'를 먼저 묻는다)
func oil_tree() -> void:
	d.anim_actor("player", "throw")
	await d.wait(0.5)
	d.take(OIL)
	d.world_state("oil_on_tree", true)
	await d.ui.caption("밑동이 번들번들해졌다. 손바닥을 대자 주르륵 미끄러진다.", 2.4)

func place_bait() -> void:
	if not S.knows("K_FOOD"):
		await d.ui.examine("숲 오솔길 어귀", "빈터 쪽으로 이어지는 오솔길 어귀다. 범이 무엇에 끌리는지 안다면 여기서 쓸 수 있을 텐데.", "clue")
		return
	d.take(TTEOK, 1)
	d.world_state("cake_bait", true)
	await d.ui.caption("오솔길 어귀부터 빈터 쪽으로, 떡을 띄엄띄엄 놓았다.", 2.4)

func wait_at_door() -> void:
	var prep := []
	if f("kids_warned"): prep.append("손을 보라 일렀다" if f("hand_test") else "목소리에 속지 말라 일렀다")
	if f("kids_in_tree"): prep.append("아이들은 나무 위")
	if S.world.get("oil_on_tree", false): prep.append("밑동에 참기름")
	if S.world.get("cake_bait", false): prep.append("오솔길에 떡")
	if S.world.get("torch_lit", false) or S.has(TORCH): prep.append("횃불")
	var i: int = await d.ui.choice(("준비: " + " · ".join(prep)) if not prep.is_empty() else "아직 아무 준비도 하지 않았다.",
		[{ label = "숨어서 기다린다" }, { label = "아직이다" }])
	if i == 0: await R([{ "event": "S0007" }])

# ---------------------------------------------------------------------------
# S0007 밤의 문 → S0008 결말 갈래
# ---------------------------------------------------------------------------
func climax() -> void:
	load_tiger_story()   # 이미 읽었으면 그냥 지나간다
	flag("climax_started")
	d.cutscene(true)
	await d.ui.fade(true, 0.6)
	d.teleport_to("hide_spot", "left")
	kids_place()
	d.camera({ "focus": [-3209.0, -350.0], "pitch": 40.0, "distance": 19.0 })
	d.set_hour(23.5)
	d.spawn_actor("tiger_night", "tiger", "tiger_from", "right", "???", "disguised")
	await d.wait(0.3)
	await d.ui.fade(false, 0.7)
	await d.ui.caption("자정 무렵. 숲에서 무언가가 내려온다.", 2.2)
	await d.move_actor("tiger_night", [[-3219.5, -351.0], [-3214.6, -352.6]], 3.2, "walk", "knock")
	d.face_actor("tiger_night", "up", null)
	d.anim_actor("tiger_night", "knock")
	await d.ui.say("문밖의 목소리", ["문 열어라."])
	d.cutscene(false)
	if not f("kids_in_tree"): d.world_state("white_paw", true)
	var go: int = await d.ui.choice("", [{ label = "숨죽여 지켜본다" }, { label = "지금 뛰어나간다" }])
	if go == 1:
		await d.ui.caption("칼을 뽑아 들고 마당으로 뛰어들었다!", 1.8)
		await resolve("A", await yard_fight({}))
		return
	if f("kids_in_tree"):
		await tree_branch()
		return
	await door_branch()
	return

func tree_branch() -> void:
	await d.ui.say("문밖의 목소리", ["…얘들아? 어디 갔느냐."])
	d.anim_actor("tiger_night", "sniff")
	await d.wait(0.9)
	await d.move_actor("tiger_night", [[-3207.0, -341.6]], 2.0, "walk", "idle")
	d.face_actor("tiger_night", "right", null)
	await d.ui.say("아우", ["누, 누나…"])
	await d.ui.say("누이", ["쉿."])
	d.anim_actor("tiger_night", "climb_try")
	await d.wait(1.3)
	if S.world.get("oil_on_tree", false):
		await d.ui.caption("번들거리는 줄기에 발톱이 주르륵 미끄러진다!", 1.8)
		d.anim_actor("tiger_night", "slip")
		d.shake(0.5, 0.45)
		await d.wait(0.9)
		await d.ui.caption("범이 등을 땅에 찧고 나뒹군다. 지금이다!", 1.8)
		await resolve("B", await yard_fight({ "stunned": 3.0, "hpRatio": 0.75 }))
		return
	d.anim_actor("nui", "cower"); d.anim_actor("au", "cry")
	await d.ui.say("누이", ["오지 마!"])
	await d.ui.caption("범이 나무를 타고 오른다! 망설일 틈이 없다.", 1.8)
	await resolve("A", await yard_fight({}))
	return

func door_branch() -> void:
	if not f("kids_warned"):
		await d.ui.say("아우", ["엄마다! 누나, 엄마 왔어!"])
		await d.ui.caption("문고리가 덜컥 벗겨진다—", 1.4)
		await d.ui.caption("마당으로 먼저 뛰어들었다. 아이들은 뒷문으로 빠져나가 큰 나무 위로 기어오른다.", 2.6)
		flag("kids_fled_to_tree")
		d.show_actor("nui", true); d.show_actor("au", true)
		await kids_climb()
		await resolve("A", await yard_fight({}))
		return
	if f("hand_test"):
		await d.ui.say("누이", ["우리 엄마면 손 좀 보여 주세요."])
		await d.ui.caption("문틈 아래로 허연 앞발이 들어온다. 밀가루가 푸슬푸슬 떨어진다.", 2.4)
		await d.ui.say("누이", ["우리 엄마 손은 거칠고 까매요! 당신, 우리 엄마 아니지!"])
	else:
		await d.ui.say("누이", ["우리 엄마 목소리 아니야!"])
	await d.ui.caption("문밖이 조용해진다. 낮게, 목 깊은 데서 그르렁 소리.", 2.0)
	d.world_state("white_paw", false)
	if not S.world.get("cake_bait", false):
		await d.ui.caption("범이 어깨의 저고리를 털어 내고 문짝을 할퀸다!", 1.8)
		await resolve("A", await yard_fight({}))
		return
	d.anim_actor("tiger_night", "sniff")
	await d.ui.caption("바람결에 떡 냄새가 실려 온다. 범의 코가 오솔길 쪽으로 돌아간다.", 2.2)
	await d.move_actor("tiger_night", [[-3222.6, -342.4]], 2.4, "walk", "eat")
	d.anim_actor("tiger_night", "eat")
	if not c_ready():
		await d.ui.caption("범이 떡에 정신이 팔렸다. 등이 무방비다!", 1.8)
		await d.ui.choice("", [{ label = "뒤에서 덮친다" }])
		await resolve("A", await yard_fight({ "stunned": 1.5 }))
		return
	await lure()
	return

# C: 떡으로 꾀어 영역 어귀까지, 횃불로 몰아낸다(싸우지 않고)
func lure() -> void:
	await d.ui.caption("떡 하나를 삼키고, 범은 다음 떡 냄새를 좇는다. 횃불을 쥐고 뒤를 밟았다.", 2.6)
	await d.ui.fade(true, 0.7)
	d.world_state("cake_bait", false)
	d.place_actor("tiger_night", "lure_end", null, "left")
	d.anim_actor("tiger_night", "eat")
	d.teleport_to("lure_player", "left")
	d.camera({ "focus": [-3260.0, -387.0] })
	if not S.world.get("torch_lit", false): flag("torch_carried")
	await d.wait(0.3)
	await d.ui.fade(false, 0.7)
	await d.ui.caption("숲속 빈터 어귀. 마지막 떡 앞에서 범이 고개를 든다.", 2.2)
	d.face_actor("tiger_night", "right", null)
	d.anim_actor("tiger_night", "idle")
	var c: int = await d.ui.choice("", [{ label = "횃불을 치켜든다" }, { label = "칼을 뽑는다" }])
	if c == 1:
		d.despawn_actor("tiger_night")
		d.camera(null)
		var res := await fight_loop("territory", {})
		await resolve("A", res)
		return
	await d.ui.caption("횃불이 타닥 튄다. 범이 귀를 젖히고 한 걸음, 또 한 걸음 물러선다.", 2.4)
	await d.move_actor("tiger_night", [[-3275.0, -396.0], [-3290.0, -404.0]], 2.6, "retreat", "idle")
	await d.ui.caption("범은 한 번 돌아보더니 빈터 깊숙이 사라졌다. 어깨에 걸쳤던 저고리가 덤불에 걸려 남았다.", 2.8)
	d.despawn_actor("tiger_night")
	await resolve("C", "repelled")
	return

func yard_fight(mods: Dictionary) -> String:
	d.despawn_actor("tiger_night")
	d.world_state("white_paw", false)
	d.camera(null)
	if not f("kids_in_tree") and not f("kids_fled_to_tree"):
		d.show_actor("nui", false); d.show_actor("au", false)
	return await fight_loop("house_yard", mods)

# 마당 싸움: 지면 다시 일어선다(아이들을 두고 물러설 수 없다). 두 번 지거나 포수가 지켜보면 포수가 한 방
func fight_loop(arena_id: String, mods: Dictionary) -> String:
	var m := mods.duplicate()
	var losses := 0
	for i in 12:
		var res: String = await d.combat(arena_id, { "mods": m, "allow_flee": false, "store": "yard" })
		if res == "win" or res == "repelled" or res == "retreated": return res
		d.end_combat()
		if res == "escaped":
			await d.ui.caption("아이들을 두고 물러설 수는 없다.", 1.8)
			m.stunned = 0.0
			continue
		losses += 1
		flag("yard_losses", losses)
		await d.ui.caption("눈앞이 캄캄해진다… 아이들의 울음소리가 귓가를 때린다.", 2.2)
		m = { "hpRatio": float(m.get("hpRatio", 1.0)) }
		if losses >= 2 or f("hunter_watch"):
			await d.ui.say("포수", ["버티시오! 내가 한 방 먹였소!"])
			m.hpRatio = minf(float(m.hpRatio), 0.55)
			flag("hunter_helped")
		await d.ui.choice("", [{ label = "다시 일어선다" }])
	return "win"

# ---------------------------------------------------------------------------
# 결말 확정 → 다음 날 아침(S0009·S0010) → 결말 카드
# ---------------------------------------------------------------------------
func resolve(branch: String, res: String) -> void:
	var detail := "C" if branch == "C" else "%s_%s" % [branch, "repel" if res in ["repelled", "retreated"] else "win"]
	S.vars["CASE_NAMWON_OUTCOME"] = branch
	S.vars["CASE_NAMWON_DETAIL"] = detail
	S.seen["S0008"] = true
	d.runner.log_line("outcome", detail)
	flag("resolved")
	d.camera(null)
	d.end_combat()
	d.despawn_actor("tiger_night")
	if branch != "C":
		await d.ui.caption("범이 마지막 숨을 몰아쉬고 쓰러졌다. 어깨에 걸쳤던 저고리가 흙바닥에 떨어진다." if detail.ends_with("win")
			else "범이 피를 흘리며 숲으로 달아난다. 마당엔 저고리 한 벌이 떨어져 남았다.", 2.8)
		if f("kids_in_tree") or f("kids_fled_to_tree"): await d.ui.caption("나무 위에서 오누이가 떨며 내려다본다.", 1.8)
	await morning()

func morning() -> void:
	d.cutscene(true)
	await d.ui.fade(true, 1.0)
	S.phase = "morning"
	flag("kids_in_tree", false); flag("kids_fled_to_tree", false)
	d.world_state("torch_lit", false); d.world_state("kids_in_tree", false); d.world_state("white_paw", false)
	d.on_phase()
	d.show_actor("nui", true); d.show_actor("au", true)
	kids_place()
	d.set_hour(8.0)
	d.teleport_to("morning_player", "up")
	d.camera({ "focus": [-3212.0, -346.0], "pitch": 36.0, "distance": 15.0 })
	await d.wait(0.4)
	await d.ui.fade(false, 1.0)
	await d.ui.caption("날이 밝았다.", 1.8)
	await R([{ "event": "S0009" }, { "event": "S0010" }])
	d.camera(null)
	d.cutscene(false)
	await d.ui.caption({
		"A": "고갯길에 다시 장꾼이 다닌다. 마을은 사흘 동안 잔치를 벌였다.",
		"B": "'나무 위 오누이' 이야기는 그해 겨울 내내 사랑방을 돌았다.",
		"C": "범은 살아 있다. 다만 다시는 사람을 해치지 않았다. 서낭당엔 떡을 바치는 사람이 생겼다.",
	}[String(S.vars.CASE_NAMWON_OUTCOME)], 2.8)
	S.phase = "done"
	d.on_phase()
	d.journal_note("사건 종결 — 「%s」" % CASE_TITLE)
	await d.show_ending()
	d.save()

# S0009 — 어미 소식(긴 대사 금지: 플레이어는 침묵, 누이가 표정을 보고 안다)
func mother_news() -> void:
	d.face_actor("nui", "up", null); d.face_actor("au", "up", null)
	await d.ui.say("누이", ["어머니는요?"])
	await d.ui.choice("", [{ label = "(말없이 저고리를 건넨다)" }])
	await d.ui.caption("누이는 저고리를 받아 들고, 오래 말이 없었다.", 2.4)
	d.anim_actor("au", "cry")
	d.anim_actor("nui", "hug")
	await d.wait(1.2)
	await d.ui.say("이웃 아낙", ["이제 우리 집에서 같이 살자."])
	flag("kids_taken")

# ---------------------------------------------------------------------------
# 지역 변화: 밤이면 멀리서 범 울음(C — 범은 살아 있다)
# ---------------------------------------------------------------------------
var _roar_cd := 0.0
func ambient(dt: float) -> void:
	_roar_cd -= dt
	if _roar_cd > 0.0 or String(S.vars.get("CASE_NAMWON_OUTCOME", "")) != "C" or S.phase != "done": return
	var h: float = d.main.hour
	if h >= 19.5 or h < 4.5:
		_roar_cd = 240.0
		d.ui.caption("…멀리 숲 너머에서 범이 운다.", 3.0)
		d.shake(0.08, 0.6)

# ---------------------------------------------------------------------------
# 사건 기록(R) — 웹 journal.js
# ---------------------------------------------------------------------------
const ROUTE_TEXT := {
	"jumo": "주막에서 들었다. 고개 너머 사는 떡장수가 사흘째 돌아오지 않는다고.",
	"kids": "고개 너머 외딴집에서 오누이를 만났다. 어머니가 장에 간 지 사흘째라 한다.",
}
const OUTCOME_TEXT := {
	"A_win": "밤, 어미의 저고리를 걸친 범이 외딴집 문을 두드렸다. 마당에서 맞서 범을 쓰러뜨렸다.",
	"A_repel": "밤, 어미의 저고리를 걸친 범이 외딴집 문을 두드렸다. 마당에서 맞섰고, 범은 피를 흘리며 숲으로 달아났다.",
	"B_win": "밤, 범은 나무 위의 오누이를 노렸다. 참기름 바른 줄기에 미끄러져 나뒹군 범을 마당에서 쓰러뜨렸다.",
	"B_repel": "밤, 범은 나무 위의 오누이를 노렸다. 참기름 바른 줄기에 미끄러져 나뒹군 범은 결국 숲으로 달아났다.",
	"C": "밤, 아이들은 문을 열지 않았다. 떡 냄새를 좇은 범은 숲속 빈터 어귀에서 횃불을 보고 제 영역으로 돌아갔다. 피 한 방울 보지 않았다.",
}
const ENDING_EXTRA := {
	"A": "고갯길에 다시 장꾼이 다닌다. 마을은 사흘 동안 잔치를 벌였다.",
	"B": "'나무 위 오누이' 이야기는 그해 겨울 내내 사랑방을 돌았다.",
	"C": "범은 살아 있다. 다만 다시는 사람을 해치지 않았다. 밤이면 멀리서 울음소리가 들리고, 서낭당엔 떡을 바치는 사람이 생겼다.",
}

func solutions() -> Array:
	var k := func(id): return S.knows(id)
	var has_torch: bool = S.has(TORCH) or bool(S.world.get("torch_lit", false))
	var has_bait: bool = S.has(TTEOK) or bool(S.world.get("cake_bait", false))
	var has_oil: bool = S.has(OIL) or bool(S.world.get("oil_on_tree", false))
	var b := [k.call("K_CLIMB"), has_oil]
	var cp := 0
	for id in ["K_MIMIC", "K_FLOUR", "K_FOOD", "K_TERRITORY"]:
		if k.call(id): cp += 1
	var c_ok: bool = k.call("K_MIMIC") and k.call("K_FLOUR") and k.call("K_FOOD") and has_bait and k.call("K_TERRITORY") and has_torch
	var c_hint := "범의 버릇을 더 알면 싸우지 않아도 될지 모른다." if cp < 2 else "범의 버릇이 하나씩 맞춰지고 있다. 싸우지 않을 길이 있을지도 모른다."
	if cp == 4: c_hint += ("" if has_torch else " 불이 있어야 할 것 같다.") if has_bait else " 꾈 것이 있어야 할 것 같다."
	return [
		{ "id": "A", "title": "맞서 싸운다", "available": true, "text": "마당에서 정면으로 맞선다. 준비가 없으면 힘겨운 싸움이 된다." },
		{ "id": "B", "title": "미끄러운 나무" if b[0] else "???", "available": b[0] and b[1],
			"text": "아이들을 큰 나무 위로 피신시키고, 밑동에 참기름을 바른다.",
			"hint": "범은 나무를 탄다. 줄기를 미끄럽게 할 무언가가 있다면…" if b[0] else ("기름병이 손에 있다. 쓸 데가 있을까…" if has_oil else "범이 어디까지 오를 수 있는지 아직 모른다.") },
		{ "id": "C", "title": "피를 보지 않고 돌려보낸다" if cp >= 2 else "???", "available": c_ok,
			"text": "아이들에게 손을 보라 이르고, 떡으로 영역 쪽까지 꾀어 낸 뒤 횃불로 몰아낸다.", "hint": c_hint },
	]

func summary() -> Array:
	var p := []
	p.append(ROUTE_TEXT.get(String(S.flags.get("route", "jumo")), ROUTE_TEXT.jumo))
	if f("met_kids") and String(S.flags.get("route", "")) != "kids": p.append("외딴집의 오누이는 문고리를 걸어 잠그고 어머니를 기다린다.")
	var cakes := cakes_found()
	if cakes > 0 or S.has_clue("basket"):
		p.append("고갯길 굽이마다 떡이 떨어져 있었다. 그 끝, 서낭당 앞엔 빈 광주리와 수건." if S.has_clue("basket")
			else ("고갯길에 떡이 떨어져 있다." if cakes <= 1 else "고갯길 굽이마다 떡이 떨어져 있다. 고개 쪽으로 이어진다."))
	var bits := []
	if S.has_clue("torn_skirt"): bits.append("찢어진 치맛자락")
	if S.has_clue("blood"): bits.append("마른 핏자국")
	var t := (", ".join(bits) + ".") if not bits.is_empty() else ""
	if S.has_clue("tracks"): t += (" " if t != "" else "") + "사람 발자국은 고갯마루에서 끊기고, 큰 짐승의 발자국만 이어진다."
	if t != "": p.append(t)
	if f("first_encounter"): p.append("해질녘 고갯마루 아래 숲에서 그것을 보았다. 범이다.")
	var o := String(S.vars.get("CASE_NAMWON_DETAIL", ""))
	if S.phase == "night" and o == "": p.append("밤이 되었다. 범은 오늘 밤 외딴집에 올 것이다. 숨기 전에 할 수 있는 일을 하자.")
	if o != "":
		p.append(OUTCOME_TEXT.get(o, ""))
		p.append("어미는 돌아오지 못했다. 마을 사람들이 오누이를 거두었다.")
		p.append(ENDING_EXTRA.get(String(S.vars.get("CASE_NAMWON_OUTCOME", "A")), ""))
		if String(S.vars.get("MAIN_MASTER_TRACE", "")).split(",").has("HANYANG"):
			p.append("기록책을 본 노인이 말했다. 전에도 그런 책을 든 양반이 한양으로 갔다고.")
			p.append("기록책 가장자리, 이겸 선생의 오래된 한 줄 — “발자국은 한 번 남지만, 사람 말은 걸을수록 달라진다.”")   # v2.2 S0010
	return p

func journal() -> Dictionary:
	if not f("case_started"):
		return { "cases": [], "empty": "마지막으로 적힌 곳: 남원. 아직 적힌 사건이 없다." }
	var clues := []
	for id in S.clues:
		var c: Dictionary = d.data.clues.get(id, { "title": id, "text": "" })
		var text := String(c.text)
		clues.append({ "title": c.title, "text": text })
	var rules := []
	for id in S.rules:
		var r: Dictionary = d.data.rules.get(id, { "title": id, "text": "" })
		rules.append({ "title": r.title, "text": r.text })
	var solved: bool = String(S.vars.get("CASE_NAMWON_OUTCOME", "")) != "" and S.phase in ["morning", "done"]
	var sols := []
	for s in solutions():
		var chosen: bool = solved and String(S.vars.CASE_NAMWON_OUTCOME) == s.id
		var e: Dictionary = s.duplicate()
		e.available = s.available or chosen
		if chosen: e.text = String(s.text) + " — 이 방법으로 끝냈다."
		sols.append(e)
	return { "cases": [{ "id": "namwon", "title": CASE_TITLE, "status": "solved" if solved else "active",
		"summary": summary(), "clues": clues, "rules": rules, "solutions": sols, "notes": S.notes }] }

func ending_data() -> Dictionary:
	var o := String(S.vars.get("CASE_NAMWON_DETAIL", "A_win"))
	var k := String(S.vars.get("CASE_NAMWON_OUTCOME", "A"))
	return {
		"case_title": CASE_TITLE,
		"title": { "A": "범을 쓰러뜨렸다" if o.ends_with("win") else "숲으로 달아난 범", "B": "나무 위의 오누이", "C": "숲으로 돌아간 범" }[k],
		"outcome": k,
		"paragraphs": [OUTCOME_TEXT.get(o, ""), "어미는 돌아오지 못했다. 마을 사람들이 오누이를 거두었다.", ENDING_EXTRA.get(k, "")],
		"record": "새 해결 수단 「짐승 흔적 읽기」. 기록책에 새로 적힌 곳 — 한양.",
	}
