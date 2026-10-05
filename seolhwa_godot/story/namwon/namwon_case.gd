# 사건 「산길의 실종」 — 데이터로 쓰기 번거로운 장면(여는 화면·회상·밤의 문·세 갈래·동아줄·다음 날 아침·밤하늘)과 기록책·결말 카드.
# 웹 seolhwa/src/story/case_sanggil.js·common.js·journal.js 이식(대사는 시나리오 §8에 맞춰 줄임).
# v3(방향 전환안 §3·§8): 밤부터 원작 「해와 달이 된 오누이」 장면(FIXED_BEATS)을 화면에서 겪는다. 원작 인물의 핵심 행동은 오누이가 한다.
#   플레이어는 범을 죽이지 않는다 — A/B/C는 오누이가 나무에 오를 시간을 버는 방법. 마을이 오누이를 거두는 결말은 없다.
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

# C(떡과 횃불로 잠시 꾄다)를 고를 수 있는가 — 오솔길에 떡 + 빈터를 안다 + 불
func c_ready() -> bool:
	return bool(S.world.get("cake_bait", false)) and S.knows("K_TERRITORY") and (S.has(TORCH) or bool(S.world.get("torch_lit", false)))

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
	# 절정 도중 저장은 밤 준비 상태로 되돌린다(웹과 같음). 결말 변수는 S0009 끝에야 쓰므로 그 앞이면 모두 되돌린다
	if f("climax_started") and String(S.vars.get("CASE_NAMWON_OUTCOME", "")) == "":
		for k in ["climax_started", "pending_outcome", "pending_detail", "kids_in_tree", "kids_gone", "yard_losses", "hunter_helped"]: S.flags.erase(k)
		for k in ["kids_in_tree", "oil_on_tree", "sorghum_red", "white_paw"]: S.world.erase(k)
	if f("beat_mother_harmed_running"): S.flags.erase("beat_mother_harmed_running")
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
	SpriteChar.merge_bank("frames_story_namwon_rope.json", ["tiger"])   # 동아줄: 줄에 매달려 오르기(rope_climb)·뒤집혀 떨어지기(fall_flip), 옆모습 한 쪽

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
	# 사흘 전 고갯길(FIXED mother_harmed) — 광주리를 아직 안 봤어도 첫 조우 뒤에는 보인다
	if not f("beat_mother_harmed"): await pass_memory()

# ---------------------------------------------------------------------------
# 주막에서 쉬기 → 밤
# ---------------------------------------------------------------------------
func rest() -> void:
	await d.ui.say("주모", ["건넌방 비어 있소. 눈 좀 붙이시오."])
	if not f("beat_mother_harmed"): await pass_memory()   # 원작 순서 — 밤 전에 반드시
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
# FIXED_BEATS(v3 §3.2) — 원작 장면이 화면에서 일어난 순서를 남긴다(flags beat_<id>, flags beats = "id,id,…")
# ---------------------------------------------------------------------------
func beat(id: String) -> void:
	if f("beat_" + id): return
	flag("beat_" + id)
	var order := String(S.flags.get("beats", ""))
	S.flags["beats"] = id if order == "" else order + "," + id
	d.runner.log_line("beat", id)

func beats_seen() -> Array:
	var s := String(S.flags.get("beats", ""))
	return [] if s == "" else Array(s.split(","))

# 대본 시험이 원작 장면마다 화면을 찍는다(--storyshots, 화면이 있을 때만)
func _shot(nm: String) -> void:
	if d.test != null and d.test.has_method("tale_shot"): await d.test.tale_shot(nm)

# 지난 일(회상) 인물은 먹빛으로 눌러 그린다
const PAST_TINT := Color(0.12, 0.16, 0.28, 0.62)
func _tint(id: String, c: Color) -> void:
	var a = d.actors.get(id)
	if a != null and a.ch._mat != null: a.ch._mat.set_shader_parameter("flash", c)

# ---------------------------------------------------------------------------
# 사흘 전 고갯길(FIXED mother_harmed) — 광주리를 보거나 첫 조우 뒤, 늦어도 밤이 되기 전에 한 번.
# 해치는 순간은 보이지 않는다: 떡을 하나씩 내주며 걷는 뒷모습 → 서낭당 앞 → 암전 → 광주리 굴러떨어지는 소리.
# ---------------------------------------------------------------------------
func pass_memory() -> void:
	if f("beat_mother_harmed"): return
	flag("beat_mother_harmed_running")
	var back := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var face: String = d.main.player.facing
	var hour: float = d.main.hour
	d.cutscene(true)
	await d.ui.fade(true, 0.6)
	d.teleport_to("cake_3", "up")   # 인물은 플레이어 140m 안에서만 그린다
	d.set_hour(18.4)
	d.spawn_actor("mother_past", "ricecake_mother", "cake_1", "up", "떡장수", "")
	d.spawn_actor("tiger_past", "tiger", [-3168.5, -168.0], "left", "", "")
	await d.get_tree().process_frame
	_tint("mother_past", PAST_TINT); _tint("tiger_past", PAST_TINT)
	d.camera({ "focus": "cake_2", "pitch": 38.0, "distance": 24.0 })
	await d.wait(0.3)
	await d.ui.fade(false, 0.8)
	await d.ui.caption("사흘 전 해질녘, 이 고갯길.", 2.2)
	await d.move_actor("mother_past", ["cake_2"], 1.5, "walk", "idle")
	d.face_actor("tiger_past", null, "mother_past")
	await d.ui.caption("숲에서  “떡 하나 주면 안 잡아먹지.”", 2.6)
	await _shot("mother_pass")
	await d.ui.caption("떡장수는 광주리에서 떡 하나를 던져 주고 걸음을 재촉한다.", 2.4)
	d.move_actor("tiger_past", ["cake_2"], 1.4, "walk", "idle")
	await d.move_actor("mother_past", ["cake_3"], 1.7, "walk", "idle")
	await d.ui.caption("다음 굽이에서도  “떡 하나 주면 안 잡아먹지.”", 2.4)
	d.camera({ "focus": "basket", "pitch": 38.0, "distance": 22.0 })
	d.move_actor("tiger_past", ["cake_3", "torn_skirt"], 1.8, "walk", "idle")
	await d.move_actor("mother_past", ["torn_skirt", "basket"], 1.8, "walk", "idle")
	await d.ui.caption("서낭당 앞. 광주리에 떡이 하나도 남지 않았다.", 2.2)
	await d.move_actor("tiger_past", ["blood"], 2.6, "walk", "idle")
	await d.ui.fade(true, 0.5)
	d.despawn_actor("mother_past"); d.despawn_actor("tiger_past")
	d.shake(0.25, 0.5)
	await d.ui.caption("광주리가 굴러떨어지는 소리. 그 뒤로 고갯길은 조용해졌다.", 2.8)
	beat("mother_harmed")
	S.flags.erase("beat_mother_harmed_running")
	d.learn_clue("pass_memory", true)
	d.set_hour(hour)
	d.teleport_to(back, face)
	d.camera(null)
	await d.wait(0.3)
	await d.ui.fade(false, 0.8)
	d.cutscene(false)
	d.journal_note("사흘 전 고갯길")

# ---------------------------------------------------------------------------
# 밤의 준비
# ---------------------------------------------------------------------------
func kids_place() -> void:
	if f("kids_gone"):
		d.show_actor("nui", false); d.show_actor("au", false)
		return
	if S.phase == "night" and f("kids_in_tree"):
		d.place_actor("nui", "perch_a", 2.7, "down")
		d.place_actor("au", "perch_b", 3.1, "down")
		d.anim_actor("nui", "perch"); d.anim_actor("au", "perch")
	elif S.phase == "night" and f("climax_started"):
		d.show_actor("nui", false); d.show_actor("au", false)
	else:
		d.place_actor("nui", "home"); d.place_actor("au", "home")

# 오누이가 나무에 오른다(FIXED kids_escape_tree) — 범 앞을 막는 동안 따로 돈다
func kids_up() -> void:
	if f("kids_in_tree"): return
	flag("kids_in_tree")
	d.world_state("kids_in_tree", true)
	d.place_actor("nui", "perch_a", 1.3, "up")
	d.place_actor("au", "perch_b", 1.7, "up")
	d.anim_actor("nui", "climb"); d.anim_actor("au", "climb")
	d.learn_clue("kids_tree", true)
	beat("kids_escape_tree")
	await d.wait(1.2)
	kids_place()

func kids_night() -> void:
	await d.ui.say("누이", ["오늘 밤에도 올까요… 그 목소리."])
	await R([{ "choice": "", "loop": true, "options": [
		{ "label": "누가 와도 문 열지 마라", "when": "not f('kids_warned')", "do": [{ "call": "warn_kids" }] },
		{ "label": "문 걸고 기다려라.", "end": true }] }])

# 일러 둘 수는 있다. 문을 열지 말지는 아이들이 정한다(v3 규칙 3)
func warn_kids() -> void:
	flag("kids_warned")
	await d.ui.say("나그네", ["어머니 목소리로 불러도 문 열지 마라."])
	await d.ui.say("누이", ["…어머니 목소리면요?"])
	await d.ui.say("아우", ["엄마면 열어 줘야지."])
	d.journal_note("아이들에게 문을 열지 말라 일렀다")

# B: 쪽문 디딤돌 + 참기름(물건 쓰기)
func oil_step() -> void:
	d.anim_actor("player", "throw")
	await d.wait(0.5)
	d.take(OIL)
	d.world_state("oil_on_step", true)
	await d.ui.caption("디딤돌이 번들번들해졌다. 발을 올리자 주르륵 미끄러진다.", 2.4)

func place_bait() -> void:
	if not S.knows("K_FOOD"):
		await d.ui.examine("숲 오솔길 어귀", "빈터 쪽으로 이어지는 오솔길 어귀다. 범이 무엇에 끌리는지 안다면 여기서 쓸 수 있을 텐데.", "clue")
		return
	d.take(TTEOK, 1)
	d.world_state("cake_bait", true)
	await d.ui.caption("오솔길 어귀부터 빈터 쪽으로, 떡을 띄엄띄엄 놓았다.", 2.4)

func wait_at_door() -> void:
	var prep := []
	if f("kids_warned"): prep.append("아이들에게 일렀다")
	if S.world.get("oil_on_step", false): prep.append("디딤돌에 참기름")
	if S.world.get("cake_bait", false): prep.append("오솔길에 떡")
	if S.world.get("torch_lit", false) or S.has(TORCH): prep.append("횃불")
	var i: int = await d.ui.choice(("준비: " + " · ".join(prep)) if not prep.is_empty() else "아직 아무 준비도 하지 않았다.",
		[{ label = "숨어서 기다린다" }, { label = "아직이다" }])
	if i == 0: await R([{ "event": "S0007" }])

# ---------------------------------------------------------------------------
# S0007 밤의 문 — 어머니 행세(FIXED tiger_disguise) · 손과 목소리(door_tricks) · 오누이의 탈출. 플레이어는 숨어서 본다.
# ---------------------------------------------------------------------------
func climax() -> void:
	load_tiger_story()   # 이미 읽었으면 그냥 지나간다
	flag("climax_started")
	d.cutscene(true)
	await d.ui.fade(true, 0.6)
	d.teleport_to("hide_spot", "left")
	kids_place()
	d.camera({ "focus": [-3211.0, -352.0], "pitch": 40.0, "distance": 18.0 })
	d.set_hour(23.5)
	d.spawn_actor("tiger_night", "tiger", "tiger_from", "right", "???", "disguised")
	await d.wait(0.3)
	await d.ui.fade(false, 0.7)
	await d.ui.caption("자정 무렵. 숲에서 무언가가 내려온다.", 2.2)
	await d.move_actor("tiger_night", [[-3219.5, -351.0], [-3214.6, -352.6]], 3.2, "walk", "knock")
	await d.ui.caption("떡장수의 저고리를 걸치고 머리에 수건을 썼다. 그런데 네 발로 걷는다.", 2.6)
	d.learn_clue("disguise_seen", true)
	beat("tiger_disguise")
	d.face_actor("tiger_night", "up", null)
	d.anim_actor("tiger_night", "knock")
	await _shot("disguise")
	await d.ui.say("문밖의 목소리", ["얘들아, 엄마 왔다. 문 열어라."])
	await d.ui.say("누이", ["우리 엄마 목소리는 그렇게 굵지 않아요."])
	await d.ui.say("문밖의 목소리", ["찬바람 맞으며 고개를 넘었더니 목이 쉬었구나."])
	await d.ui.say("아우", ["그럼 손 좀 보여 줘요."])
	await d.ui.caption("문틈으로 손이 들어온다. 누렇고 털이 숭숭 났다.", 2.4)
	await d.ui.say("누이", ["우리 엄마 손엔 이렇게 털이 없어요!"])
	await d.ui.say("문밖의 목소리", ["종일 일을 해서 그렇단다. …잠깐 기다려라."])
	await d.move_actor("tiger_night", [[-3220.0, -350.0]], 2.4, "walk", "sniff")
	await d.ui.caption("범이 어둠 속으로 물러난다. 한참 뒤, 다시 문 앞으로 온다.", 2.4)
	await d.move_actor("tiger_night", [[-3214.6, -352.6]], 2.4, "walk", "knock")
	d.face_actor("tiger_night", "up", null)
	d.world_state("white_paw", true)
	await d.ui.caption("문틈으로 다시 손이 들어온다. 이번엔 허옇고 매끈하다. 밀가루가 푸슬푸슬 떨어진다.", 2.6)
	await _shot("door_hand")
	await d.ui.say("아우", ["엄마 손이다!"])
	if f("kids_warned"):
		await d.ui.say("누이", ["…아저씨가 아무한테도 열지 말랬는데."])
		await d.ui.say("아우", ["엄마 손이잖아, 누나."])
	await d.ui.caption("문고리가 벗겨진다.", 1.6)
	d.world_state("white_paw", false)
	d.learn_clue("door_tricks", true)
	beat("door_tricks")
	await d.move_actor("tiger_night", [[-3214.0, -354.4]], 2.0, "walk", "idle")
	d.show_actor("tiger_night", false)   # 집 안으로
	await d.ui.caption("방 안이 조용하다. 등잔불만 흔들린다.", 2.0)
	await d.ui.say("아우", ["(소곤소곤) 누나, 엄마 치마 밑에 꼬리가…"])
	await d.ui.say("누이", ["어머니, 저희 뒷간에 다녀올게요."])
	await d.ui.say("방 안의 목소리", ["얼른 다녀오너라."])
	# 쪽문으로 빠져나온 오누이가 우물가 나무로 뛴다
	d.place_actor("nui", "back_step", null, "right")
	d.place_actor("au", [-3210.6, -356.0], null, "right")
	d.move_actor("nui", ["kids_run_1", "kids_run_2", "tree_foot"], 2.6, "walk", "climb")
	d.move_actor("au", [[-3209.4, -353.4], "kids_run_2", "tree_foot"], 2.4, "walk", "climb")
	await d.ui.caption("쪽문이 열리고, 오누이가 맨발로 빠져나와 우물가 나무 쪽으로 달린다.", 2.2)
	await d.ui.say("방 안의 목소리", ["…얘들아? 왜 이리 오래 걸리느냐."])
	d.show_actor("tiger_night", true)
	d.place_actor("tiger_night", "house_door", null, "down")
	d.anim_actor("tiger_night", "idle")
	await d.ui.caption("범이 저고리를 벗어 던지고 방에서 뛰쳐나온다!", 2.0)
	d.cutscene(false)
	await buy_time()

# ---------------------------------------------------------------------------
# S0008 시간을 번다 — A 막아섬 / B 디딤돌 함정 / C 떡과 횃불. 범은 죽지 않는다(undying). 어느 쪽이든 오누이는 나무에 오른다.
# ---------------------------------------------------------------------------
func buy_time() -> void:
	d.camera(null)
	if S.world.get("oil_on_step", false):
		await d.move_actor("tiger_night", ["back_step"], 3.0, "walk", "slip")
		d.anim_actor("tiger_night", "slip")
		d.shake(0.5, 0.45)
		await d.ui.caption("쪽문 디딤돌을 딛는 순간, 범의 앞발이 주르륵 미끄러진다!", 2.0)
		kids_up()
		await d.ui.caption("범이 등을 땅에 찧고 버둥거린다. 그사이 오누이가 나무를 타고 오른다.", 2.2)
		await resolve("B", await yard_fight({ "stunned": 3.0, "hpRatio": 0.75 }, 18.0))
		return
	var opts := [{ label = "칼을 뽑고 범 앞을 막아선다" }]
	var can_c := c_ready()
	if can_c: opts.append({ label = "떡 냄새 쪽으로 범을 꾄다" })
	var i: int = await d.ui.choice("범이 아이들 쪽으로 몸을 돌린다.", opts)
	if i == 1 and can_c:
		await lure()
		return
	await d.ui.caption("칼을 뽑아 들고 범과 나무 사이로 뛰어들었다!", 1.8)
	kids_up()
	await resolve("A", await yard_fight({}, 30.0))

# C: 떡으로 빈터 어귀까지 꾀어내고 횃불로 잠시 물러나게 한다 — 범은 곧 돌아온다
func lure() -> void:
	d.anim_actor("tiger_night", "sniff")
	await d.ui.caption("바람결에 떡 냄새가 실려 온다. 범의 코가 오솔길 쪽으로 돌아간다.", 2.2)
	kids_up()
	await d.move_actor("tiger_night", [[-3222.6, -342.4]], 2.4, "walk", "eat")
	d.anim_actor("tiger_night", "eat")
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
		await resolve("A", await fight_loop("territory", {}, 24.0))
		return
	await d.ui.caption("횃불이 타닥 튄다. 범이 귀를 젖히고 한 걸음, 또 한 걸음 물러선다.", 2.4)
	await d.move_actor("tiger_night", [[-3275.0, -396.0], [-3290.0, -404.0]], 2.6, "retreat", "idle")
	d.despawn_actor("tiger_night")
	await d.ui.caption("범이 빈터 깊숙이 사라졌다. …오래가지 않았다. 나뭇가지 꺾이는 소리가 외딴집 쪽으로 돌아간다.", 3.0)
	await resolve("C", "lured")

func yard_fight(mods: Dictionary, secs: float) -> String:
	d.despawn_actor("tiger_night")
	d.world_state("white_paw", false)
	d.camera(null)
	return await fight_loop("house_yard", mods, secs)

# 시간을 버는 싸움: 범은 쓰러지지 않는다(undying) — secs초를 버티거나 크게 다치게 하면 물러난다.
# 지면: 범이 나를 넘어 나무 쪽으로 간다. 포수가 지켜보거나 두 번째면 포수의 화살이 범을 돌려세운다
func fight_loop(arena_id: String, mods: Dictionary, secs := 30.0) -> String:
	var m := mods.duplicate()
	m.undying = true
	var losses := 0
	for i in 3:
		var res: String = await d.combat(arena_id, { "mods": m, "allow_flee": false, "store": "yard", "retreat_at": { "seconds": secs, "hpRatio": 0.45 } })
		if res != "lose" and res != "escaped": return res
		d.end_combat()
		if res == "escaped":
			await d.ui.caption("아이들을 두고 물러설 수는 없다.", 1.8)
			m.stunned = 0.0
			continue
		losses += 1
		flag("yard_losses", losses)
		await d.ui.caption("눈앞이 캄캄해진다… 범이 나를 넘어 나무 쪽으로 간다.", 2.2)
		if f("hunter_watch") or losses >= 2:
			await d.ui.say("포수", ["이놈아, 이쪽이다!"])
			await d.ui.caption("어둠 속에서 날아온 화살에 범이 몸을 돌린다.", 2.2)
			flag("hunter_helped")
			return "lose"
		await d.ui.choice("", [{ label = "다시 일어선다" }])
		m = { "undying": true, "hpRatio": float(m.get("hpRatio", 1.0)) }
	return "lose"

# ---------------------------------------------------------------------------
# 갈래 확정(결과는 S0009 끝에 CASE_NAMWON_OUTCOME으로) → S0009 동아줄 → S0010 아침 → S0011 밤하늘 → 결말 카드
# ---------------------------------------------------------------------------
func resolve(branch: String, res: String) -> void:
	var detail := "C" if branch == "C" else "%s_%s" % [branch, "down" if res == "lose" else "hold"]
	flag("pending_outcome", branch)
	flag("pending_detail", detail)
	S.seen["S0008"] = true
	d.runner.log_line("outcome", detail)
	d.camera(null)
	d.end_combat()
	d.despawn_actor("tiger_night")
	if branch == "A":
		await d.ui.caption("범이 한 걸음 물러나 으르렁거린다. 그사이 오누이는 나무 높이 올랐다." if res != "lose"
			else "몸을 일으켰을 때, 오누이는 이미 나무 높이 올라 있었다.", 2.6)
	elif branch == "B":
		await d.ui.caption("범이 겨우 몸을 일으킨다. 앞발이 아직 번들거린다. 오누이는 나무 높이 올랐다.", 2.6)
	kids_up()
	await R([{ "event": "S0009" }, { "event": "S0010" }, { "event": "S0011" }])
	await finish()

func commit_outcome() -> void:
	if String(S.vars.get("CASE_NAMWON_OUTCOME", "")) != "": return
	S.vars["CASE_NAMWON_OUTCOME"] = String(S.flags.get("pending_outcome", "A"))
	S.vars["CASE_NAMWON_DETAIL"] = String(S.flags.get("pending_detail", "A_hold"))
	d.runner.log_line("commit", S.vars["CASE_NAMWON_OUTCOME"])
	d.mark_dirty()

# ---------------------------------------------------------------------------
# S0009 우물가 나무 — 우물에 비친 얼굴 · 참기름과 도끼(오누이의 말) · 동아줄을 비는 것(오누이) · 새 줄 · 썩은 줄 · 수수밭 · 두 빛
# ---------------------------------------------------------------------------
var _tale_nodes: Array = []
func _tale_node(params: Dictionary, at: Vector2, y: float) -> Node3D:
	var info: Dictionary = load("res://kit/story/tale.gd").build(params)
	var n: Node3D = info.node
	d._props_root.add_child(n)
	n.position = Vector3(at.x, y, at.y)
	_tale_nodes.append(n)
	return n

func _free_tale_nodes() -> void:
	for n in _tale_nodes:
		if is_instance_valid(n): n.queue_free()
	_tale_nodes.clear()

func _ground(at) -> float:
	var p: Vector2 = d.anchor(at)
	return d.world.height_at(p.x, p.y)

func _dur(sec: float) -> float:
	return 0.08 if d.ui.auto and not d.ui.auto_real else sec

# 하늘에서 줄이 내려온다(아래 끝이 bottom 높이까지)
func _rope_down(at: String, rotten: bool, bottom_off: float) -> Node3D:
	var p: Vector2 = d.anchor(at)
	var bottom := _ground(at) + bottom_off
	var n := _tale_node({ "kind": "rope", "rotten": rotten, "length": 60.0, "seed": 49 if not rotten else 50 }, p, bottom + 48.0)
	var tw: Tween = d.create_tween()
	tw.tween_property(n, "position:y", bottom, _dur(2.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	return n

# 매 프레임 sec초 동안 fnc(k 0→1)
func _animate(sec: float, fnc: Callable) -> void:
	var dur := _dur(sec)
	var t := 0.0
	while t < dur:
		await d.get_tree().process_frame
		t += d.get_process_delta_time() / maxf(Engine.time_scale, 0.01) if not d.ui.auto else d.get_process_delta_time()
		fnc.call(minf(1.0, t / dur))
	fnc.call(1.0)

func rope_night() -> void:
	d.cutscene(true)
	d.end_combat()
	await d.ui.fade(true, 0.5)
	d.teleport_to("sky_watch", "right")
	kids_place()
	d.spawn_actor("tiger_night", "tiger", [-3214.0, -349.6], "right", "범", "")
	d.camera({ "focus": [-3205.0, -344.6], "pitch": 24.0, "distance": 18.0 })   # 낮게 — 나무 위·줄이 화면에 들게
	_sky_light(d.anchor("rope_kids") + Vector2(0, 0.9), _ground("rope_kids"))   # 빛기둥 셰이더를 암전 속에서 미리 짓는다(세기 0)
	_field_light(d.anchor("sorghum"), _ground("sorghum"))
	await d.wait(0.3)
	await d.ui.fade(false, 0.6)
	# 우물에 비친 얼굴
	await d.ui.caption("범이 다시 마당으로 와 코를 킁킁댄다. 아이들이 보이지 않는다.", 2.2)
	await d.move_actor("tiger_night", ["tiger_well"], 2.2, "walk", "sniff")
	d.face_actor("tiger_night", null, "well")
	await d.ui.caption("범이 우물을 들여다본다. 물 위에 오누이 얼굴이 비친다.", 2.4)
	await _shot("well")
	await d.ui.say("범", ["얘들아, 우물 속에 들어가 있었구나. 바가지로 건져 주마."])
	await d.ui.caption("나무 위에서 아우가 그만 킥 웃음을 터뜨린다.", 2.0)
	d.face_actor("tiger_night", null, "big_tree")
	d.learn_clue("reflection", true)
	beat("well_reflection")
	await d.move_actor("tiger_night", ["tiger_tree"], 2.0, "walk", "idle")
	d.face_actor("tiger_night", "up", null)
	# 오누이의 거짓말 — 참기름, 그리고 아우의 실수
	await d.ui.say("범", ["거기 있었구나. 얘들아, 너희는 어떻게 그리 높이 올라갔느냐?"])
	await d.ui.say("누이", ["참기름을 바르고 올라왔지."])
	d.world_state("oil_on_tree", true)
	await d.ui.caption("범이 부엌에서 기름 단지를 들고 나와 줄기에 처덕처덕 바른다.", 2.2)
	d.anim_actor("tiger_night", "climb_try")
	await d.wait(1.0)
	d.anim_actor("tiger_night", "slip")
	d.shake(0.3, 0.4)
	await d.ui.caption("오르려다 주르륵 미끄러진다. 다시 올라도 또 미끄러진다.", 2.2)
	d.learn_clue("kids_lie", true)
	await d.ui.say("아우", ["바보, 도끼로 찍고 올라오면 되지."])
	await d.ui.say("누이", ["아우야!"])
	d.learn_clue("axe_slip", true)
	beat("kids_lies")
	await d.ui.caption("범이 헛간에서 도끼를 물고 나와 줄기를 찍는다. 쿵, 쿵. 한 칸씩 올라온다.", 2.4)
	d.anim_actor("tiger_night", "climb_try")
	for y in [0.7, 1.4]:
		d.place_actor("tiger_night", "tiger_tree", y, "up")
		d.shake(0.18, 0.25)
		await d.wait(0.6)
	var i: int = await d.ui.choice("", [{ label = "활을 쏘아 범을 늦춘다" }, { label = "숨죽여 지켜본다" }])
	if i == 0:
		d.anim_actor("player", "throw")
		await d.ui.caption("화살이 범의 어깨에 박힌다. 범이 한 번 으르렁거리고, 다시 도끼를 든다.", 2.4)
	# 동아줄을 비는 것은 오누이
	d.anim_actor("nui", "perch"); d.anim_actor("au", "cower")
	await d.ui.say("누이", ["하늘님, 저희를 살리시려거든 새 동아줄을 내려 주시고, 죽이시려거든 썩은 동아줄을 내려 주세요."])
	d.learn_clue("prayer", true)
	beat("kids_prayer")
	if d.test != null and d.test.has_method("review_begin"): d.test.review_begin()   # 화면 검토(--storyshots): 여기서 결말까지 실제 길이로
	d.camera({ "focus": [-3204.6, -343.0], "pitch": 14.0, "distance": 19.0, "fov": 50.0 })   # 낮고 넓게 — 줄이 내려오는 것이 화면에 들게
	var rope := await _rope_down("rope_kids", false, 3.6)
	await d.ui.caption("하늘에서 동아줄 하나가 스르르 내려온다.", 2.2)
	await _shot("rope")
	await rope_rise(rope)
	await rotten_rope_fall()
	await two_lights()
	_rope_cam_end()
	_free_tale_nodes()
	commit_outcome()
	d.camera(null)

# ---------------------------------------------------------------------------
# 동아줄 절정의 각본 시점 — 이 장면에서만. 카메라 자리·바라볼 점을 직접 정해(CameraRig.shot) 하늘을 올려다본다.
# 큰 나무의 잎은 그동안 걷어 내고(region_main.set_occ_script), 끝나면(암전 속) 평소 시점·가림으로 돌린다.
# ---------------------------------------------------------------------------
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _cam_fov := 46.0
func _cam(pos: Vector3, look: Vector3, fov := -1.0) -> void:
	_cam_pos = pos; _cam_look = look
	if fov > 0.0: _cam_fov = fov
	d.main.rig.shot = { pos = pos, look = look, fov = _cam_fov }

# 지금 시점에서 sec초 동안 새 시점으로(천천히 떠나 천천히 닿는다). follow(k)가 있으면 바라볼 점을 매 프레임 그것으로 덮는다
# 새 _cam_move나 _cam_cut이 시작되면 앞의 움직임은 거기서 멈춘다(뒤의 것이 이긴다)
var _cam_gen := 0
func _cam_cut(pos: Vector3, look: Vector3, fov := -1.0) -> void:
	_cam_gen += 1
	_cam(pos, look, fov)

func _cam_move(sec: float, pos: Vector3, look: Vector3, fov := -1.0, step := Callable()) -> void:
	_cam_gen += 1
	var gen := _cam_gen
	var p0 := _cam_pos; var l0 := _cam_look; var f0 := _cam_fov
	var f1 := fov if fov > 0.0 else f0
	await _animate(sec, func(k: float) -> void:
		if gen != _cam_gen:
			if step.is_valid(): step.call(k)
			return
		var w := smoothstep(0.0, 1.0, k)
		_cam_fov = lerpf(f0, f1, w)
		_cam(p0.lerp(pos, w), l0.lerp(look, w))
		if step.is_valid(): step.call(k))

func _rope_cam_end() -> void:
	d.main.rig.shot = null
	if d.main.has_method("set_occ_script"): d.main.set_occ_script(null)
	if is_instance_valid(_sky_beam): _sky_beam.queue_free()
	if is_instance_valid(_sky_spot): _sky_spot.queue_free()
	if is_instance_valid(_field_lamp): _field_lamp.queue_free()

# 카메라와 focus 사이의 잎·가지를 점무늬로 비운다(큰 나무의 수관이 오르는 아이들·범을 덮지 않게)
func _occ(focus: Vector3, r := 3.2) -> void:
	if d.main.has_method("set_occ_script"): d.main.set_occ_script({ "focus": focus, "r": r })

# 수수밭을 비추는 달빛(붉은 물이 밤에도 읽히게) — 수숫대 장면부터 끝까지
var _field_lamp: OmniLight3D
func _field_light(at: Vector2, g: float) -> void:
	_field_lamp = OmniLight3D.new()
	_field_lamp.light_color = Color(1.0, 0.92, 0.82)
	_field_lamp.light_energy = 0.0
	_field_lamp.omni_range = 10.0
	_field_lamp.shadow_enabled = false
	d._props_root.add_child(_field_lamp)
	_field_lamp.position = Vector3(at.x, g + 4.0, at.y + 3.0)

# 하늘에서 줄을 따라 내려오는 빛(빛기둥 + 위에서 비추는 불빛)
var _sky_beam: MeshInstance3D
var _sky_spot: OmniLight3D   # 아이들 바로 위에서 따라 오르며 내리비춘다(스포트라이트는 Mobile에서 셰이더를 새로 짜느라 몇 초 멈춘다)
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.66, 1.0);
uniform float strength = 0.0;
varying float h;
void vertex() { h = UV.y; }
void fragment() {
	float edge = pow(abs(dot(NORMAL, VIEW)), 3.0);       // 가운데가 짙고 가장자리는 흐리게
	float fall = smoothstep(1.0, 0.25, h) * smoothstep(0.0, 0.08, h);   // 아래 끝은 땅 위에서 사라진다
	ALBEDO = tint.rgb;
	ALPHA = 1.0;
	ALBEDO *= edge * fall * strength;
}
"""
func _sky_light(at: Vector2, g: float) -> void:
	_sky_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.0; cm.bottom_radius = 1.3; cm.height = 46.0; cm.radial_segments = 24; cm.rings = 1
	cm.cap_top = false; cm.cap_bottom = false
	_sky_beam.mesh = cm
	var sm := ShaderMaterial.new()
	var sh := Shader.new(); sh.code = BEAM_SHADER
	sm.shader = sh
	_sky_beam.material_override = sm
	_sky_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d._props_root.add_child(_sky_beam)
	_sky_beam.position = Vector3(at.x, g + 2.0 + 23.0, at.y)
	_sky_spot = OmniLight3D.new()
	_sky_spot.light_color = Color(1.0, 0.9, 0.68)
	_sky_spot.light_energy = 0.0
	_sky_spot.omni_range = 7.0
	_sky_spot.shadow_enabled = false
	d._props_root.add_child(_sky_spot)
	_sky_spot.position = Vector3(at.x, g + 6.0, at.y + 0.8)

func _sky_light_k(k: float) -> void:
	if is_instance_valid(_sky_beam): (_sky_beam.material_override as ShaderMaterial).set_shader_parameter("strength", 0.14 * k)
	if is_instance_valid(_sky_spot): _sky_spot.light_energy = 3.0 * k

# 새 동아줄 — 오누이가 붙잡자마자 각본 시점: 나무 밑동 → 오르는 아이들을 따라 위로 → 수관 위에서 줄과 하늘을 가운데 → 범에게로 내려온다
func rope_rise(rope: Node3D) -> void:
	await d.ui.caption("누이가 아우를 앞세워 줄을 붙잡는다.", 1.8)
	var rk: Vector2 = d.anchor("rope_kids") + Vector2(0, 0.9)   # 줄을 줄기 앞(카메라 쪽)으로 조금 — 붙잡는 순간 시점이 바뀌어 티 나지 않는다
	var g := _ground("rope_kids")
	rope.position.z = rk.y
	d.place_actor("nui", rk + Vector2(-0.15, 0), 3.0, "up"); d.place_actor("au", rk + Vector2(0.2, 0), 3.9, "up")   # 둘이 겹치지 않게
	d.place_actor("tiger_night", "tiger_tree", 0.0, "up")   # 범은 밑동에서 올려다본다(카메라가 들리면 화면 밖으로)
	d.anim_actor("tiger_night", "idle")
	d.anim_actor("nui", "climb"); d.anim_actor("au", "climb")
	var an = d.actors.get("nui"); var aa = d.actors.get("au")
	var yn: float = an.y_abs; var ya: float = aa.y_abs; var yr: float = rope.position.y
	# 나무 밑동에서 시작(남쪽 낮은 자리, 조금 비켜서). 아이 그림은 줄 아래 끝(y_abs)보다 1.3~2.8m 위에 그려진다(climb 끝 자세)
	var kid_c := 2.1
	var cam0 := Vector3(rk.x + 0.9, g + 1.5, rk.y + 8.0)
	_cam_cut(cam0, Vector3(rk.x, g + 0.8, rk.y), 40.0)
	_occ(Vector3(rk.x, yn + kid_c, rk.y), 2.6)
	if not is_instance_valid(_sky_beam): _sky_light(rk, g)
	d.sfx("rope_creak")
	# 밑동에서 줄을 붙잡은 아이들까지 천천히 고개를 든다
	await _cam_move(1.8, cam0, Vector3(rk.x, yn + kid_c, rk.y), 38.0, func(k: float) -> void: _sky_light_k(0.35 * k))
	await _shot("rope_grab")
	var lift_of := func(k: float) -> float: return 36.0 * k * k
	var rise := func(lift: float) -> void:
		an.y_abs = yn + lift; aa.y_abs = ya + lift
		rope.position.y = yr + lift
		_occ(Vector3(rk.x, yn + lift + kid_c, rk.y), 2.6)
		if is_instance_valid(_sky_spot): _sky_spot.position.y = yn + lift + 4.0
	# 오른다 — 카메라는 아이들을 따라 위로(2.8초, 수관 위 약 12m까지)
	var cam1 := Vector3(rk.x + 0.7, g + 2.4, rk.y + 8.5)
	await _cam_move(2.8, cam1, Vector3(rk.x, g + 12.0, rk.y), 32.0, func(k: float) -> void:
		var lift: float = lift_of.call(0.6 * k)
		rise.call(lift)
		_cam_look = Vector3(rk.x, yn + lift + kid_c, rk.y)
		d.main.rig.shot.look = _cam_look
		_sky_light_k(0.35 + 0.65 * k))
	await _shot("rise")
	d.sfx("wind")
	# 수관 위: 줄과 하늘을 가운데 두고, 아이들은 빛 속으로 올라 화면 위로 사라진다
	var sky_look := Vector3(rk.x, g + 19.0, rk.y)
	await _cam_move(2.6, cam1 + Vector3(0, 0, 3.0), sky_look, 46.0, func(k: float) -> void:
		rise.call(lift_of.call(0.6 + 0.4 * k)))
	await _shot("sky")
	flag("kids_gone")
	flag("kids_in_tree", false)
	d.world_state("kids_in_tree", false)
	kids_place()
	rope.queue_free()
	d.learn_clue("sky_rise", true)
	beat("new_rope_rise")
	await d.ui.caption("아이 둘이 줄을 타고 하늘로 올라갔다.", 2.6)
	# 빛이 걷히고, 다시 나무 밑의 범에게로 내려온다
	var rt: Vector2 = d.anchor("rope_tiger")
	var gt := _ground("rope_tiger")
	d.place_actor("tiger_night", "tiger_tree", 0.0, "up")
	d.anim_actor("tiger_night", "idle")
	_occ(Vector3(rt.x, gt + 2.0, rt.y))
	await _cam_move(2.6, Vector3(rt.x + 0.8, gt + 2.0, rt.y + 12.5), Vector3(rt.x + 0.4, gt + 1.6, rt.y), 44.0, func(k: float) -> void: _sky_light_k(1.0 - k))
	if is_instance_valid(_sky_beam): _sky_beam.queue_free()
	if is_instance_valid(_sky_spot): _sky_spot.queue_free()
	await _shot("tiger_below")

# 썩은 동아줄 — 범이 매달려 오르고(rope_climb), 끊어져 뒤집히며(fall_flip) 수수밭에 떨어진다.
# 그다음은 읽을 만큼씩: 떨어짐 → 흔들림(설정이 꺼져 있으면 짧은 암전) → 수숫대 → 붉게 번짐 → 고요
func rotten_rope_fall() -> void:
	await d.ui.say("범", ["하늘님, 저를 살리시려거든 새 동아줄을 내려 주시고, 죽이시려거든 썩은 동아줄을 내려 주세요."])
	var rt: Vector2 = d.anchor("rope_tiger")
	var gt := _ground("rope_tiger")
	_cam_move(2.6, _cam_pos + Vector3(0, 0.6, 0), Vector3(rt.x + 0.4, gt + 4.0, rt.y))   # 내려오는 줄을 따라 살짝 올려다본다
	var rot: Node3D = await _rope_down("rope_tiger", true, 1.0)
	await d.ui.caption("또 하나의 줄이 내려온다. 빛이 검누렇다.", 2.0)
	d.place_actor("tiger_night", "rope_tiger", 0.4, "left")
	d.anim_actor("tiger_night", "rope_climb")
	var at = d.actors.get("tiger_night")
	var yt: float = at.y_abs
	d.sfx("rope_creak")
	d.ui.caption("범이 줄을 붙잡고 오른다. 줄이 삐걱거린다.", 2.4)
	var creaks := [0.35, 0.7]
	await _cam_move(3.0, Vector3(rt.x + 1.2, gt + 2.8, rt.y + 13.5), Vector3(rt.x + 0.4, gt + 6.0, rt.y), -1.0, func(k: float) -> void:
		at.y_abs = yt + 4.6 * smoothstep(0.0, 1.0, k)
		_occ(Vector3(rt.x, at.y_abs + 2.2, rt.y))
		_cam_look.y = maxf(_cam_look.y, at.y_abs + 2.2); d.main.rig.shot.look = _cam_look
		if not creaks.is_empty() and k >= creaks[0]:
			creaks.pop_front(); d.sfx("rope_creak")
			d.shake(0.08, 0.15))
	await _shot("tiger_climb")
	# 끊어진다
	var top: float = at.y_abs
	rot.queue_free()
	var piece := _tale_node({ "kind": "rope_end", "length": 3.0 }, rt, top + 0.4)
	d.sfx("rope_snap")
	d.ui.caption("뚝—", 1.2)   # 끊어지는 순간 곧바로 뒤집히며 떨어진다
	d.shake(0.12, 0.15)
	await d.wait(0.25)
	d.anim_actor("tiger_night", "fall_flip")
	var to: Vector2 = d.anchor("tiger_fall")
	var g1 := _ground("tiger_fall")
	var ch = at.ch
	var mid := Vector3((rt.x + to.x) * 0.5, gt + 2.2, (rt.y + to.y) * 0.5)
	var fall := func(k: float) -> void:
		var q := rt.lerp(to, k)
		at.pos = Vector3(q.x, at.pos.y, q.y)
		at.y_abs = lerpf(top, g1 + 1.4, k * k) + sin(k * PI) * 1.4   # 수숫대 끝에 닿는 순간 끊는다(누운 몸은 보이지 않게)
		ch.roll = lerpf(-PI * 0.9, 0.25, k)   # 놓친 순간은 거의 바로 선 몸 → 떨어지며 뒤집혀 등부터 수숫대에 닿는다(fall_flip은 배가 하늘로 향한 그림)
		ch.fx_scale = 1.0 + 0.16 * sin(k * PI) - 0.1 * k
		piece.position = Vector3(q.x + 0.3, at.y_abs + 1.0 - 0.6 * k, q.y)
		piece.rotation.z = 1.6 * k
	_cam_move(1.6, Vector3(mid.x + 0.6, gt + 2.4, mid.z + 13.0), mid)
	await _animate(0.6, func(k: float) -> void: fall.call(0.5 * k))
	await _shot("fall")
	await _animate(0.55, func(k: float) -> void: fall.call(0.5 + 0.5 * k))
	# 떨어진 충격 — 흔들림 설정이 켜져 있으면 흔들고, 꺼져 있으면 짧은 암전
	d.sfx("fall_impact")
	var sc: Vector2 = d.anchor("sorghum")
	var gs := _ground("sorghum")
	var cpos := Vector3(sc.x + 0.6, gs + 2.4, sc.y + 8.0)
	var to_field := func() -> void:   # 수숫대 시점으로 넘어간다(누운 범은 그리지 않는다)
		d.despawn_actor("tiger_night")
		piece.queue_free()
		_cam_cut(cpos, Vector3(sc.x, gs + 1.2, sc.y), 40.0)
		_occ(cpos + Vector3(0, 0, -1.0), 0.5)   # 수숫대는 점무늬로 비우지 않는다
		_field_lamp.light_energy = 4.0
	if d.shake_enabled():
		d.shake(0.8, 0.7)
		await d.wait(0.35)
		to_field.call()
		await d.wait(0.6)
	else:
		d.ui._fade.color.a = 1.0   # 흔들림을 껐으면 짧은 암전
		to_field.call()
		await d.wait(0.8)
		await d.ui.fade(false, 0.5)
	# 수숫대(아직 푸르다) — 흔들리던 것이 멎는다
	d.ui.caption("수숫대가 크게 흔들리다가 멎는다.", 2.2)
	var field = d.props.get("p_sorghum", {}).get("node")
	await _animate(1.8, func(k: float) -> void:   # 떨어진 충격으로 수수밭 전체가 출렁이다 잦아든다
		if field is Node3D and is_instance_valid(field):
			var a := 0.08 * sin(k * PI * 5.0) * (1.0 - k)
			field.rotation = Vector3(a * 0.6, field.rotation.y, a))
	await _shot("stalks")
	await d.wait(0.5)
	# 붉은 물이 번진다
	d.ui.caption("범이 떨어진 자리부터 수숫대가 붉게 물든다.", 3.2)
	await sorghum_red()
	await _shot("red")
	# 고요
	d.sfx("wind")
	await d.wait(2.2)
	await _shot("still")
	d.learn_clue("rotten_rope", true)
	beat("tiger_rotten_rope")

# 수숫대가 떨어진 자리에서부터 줄줄이 붉어진다(붉은 줄을 하나씩 겹쳐 세우고, 다 되면 소품을 붉은 판으로)
func sorghum_red() -> void:
	var c: Vector2 = d.anchor("sorghum")
	var y := _ground("sorghum")
	var rows := []
	for ri in [2, 1, 3, 0, 4]:
		rows.append(_tale_node({ "kind": "sorghum", "w": 5.0, "d": 4.5, "row": ri, "red": true }, c, y + 0.01))
		await d.wait(0.6)
	d.world_state("sorghum_red", true)
	await d.get_tree().process_frame
	d._update_props()
	for n in rows: n.queue_free()
	_tale_nodes = _tale_nodes.filter(func(n): return is_instance_valid(n) and not rows.has(n))

# 하늘에 두 빛이 자리 잡는다(FIXED sun_moon) — 인물이 아니라 빛으로, 민화 결의 하늘 판
func two_lights() -> void:
	await d.ui.fade(true, 0.8)
	var sky = load("res://scripts/story/tale_sky.gd").new()
	sky.mode = "lights"
	d.add_child(sky)
	sky.alpha = 1.0
	await d.ui.fade(false, 0.8)
	var tw: Tween = d.create_tween()
	tw.tween_property(sky, "progress", 1.0, _dur(4.2)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await d.ui.caption("밤하늘 높이, 빛 둘이 떠오른다.", 2.4)
	if tw.is_running(): await tw.finished
	var tw2: Tween = d.create_tween()
	tw2.tween_property(sky, "settle", 1.0, _dur(2.4))
	await d.ui.caption("붉은 빛 하나, 흰 빛 하나. 두 빛이 하늘에 자리를 잡는다.", 2.6)
	if tw2.is_running(): await tw2.finished
	d.learn_clue("two_lights", true)
	beat("sun_moon")
	await _shot("two_lights")
	await d.wait(1.0)
	await d.ui.fade(true, 0.8)
	sky.queue_free()

# ---------------------------------------------------------------------------
# S0010 이튿날 아침 — 빈 집. 아이들이 어디 갔는지 아무도 모른다(본 사람은 나그네뿐)
# ---------------------------------------------------------------------------
func morning_village() -> void:
	d.cutscene(true)
	if d.ui._fade.color.a < 0.99: await d.ui.fade(true, 1.0)
	S.phase = "morning"
	d.world_state("torch_lit", false); d.world_state("kids_in_tree", false); d.world_state("white_paw", false); d.world_state("oil_on_tree", false)
	d.on_phase()
	kids_place()
	d.set_hour(8.0)
	d.teleport_to("morning_player", "up")
	d.camera({ "focus": "north_square", "pitch": 36.0, "distance": 15.0 })
	await d.wait(0.4)
	await d.ui.fade(false, 1.0)
	await d.ui.caption("이튿날 아침, 북쪽 어귀.", 1.8)
	await d.ui.say("이웃 아낙", ["고개 너머 그 집에 가 봤어요. 문은 열려 있고, 아무도 없어요."])
	await d.ui.say("포수", ["수수밭에 범이 떨어져 죽어 있더군. 누가 쏜 자국은 없고."])
	await d.ui.say("이웃 아낙", ["아이들은 어디 갔소? 혹시 보셨소?"])
	var i: int = await d.ui.choice("", [{ label = "(하늘을 올려다본다)" }, { label = "(아무 말도 하지 않는다)" }])
	if i == 0: await d.ui.caption("아침 해가 고개 위로 올라와 있다.", 2.0)
	await d.ui.say("포수", ["아이들 발자국이 우물가 나무 밑에서 끊겼소. 그다음은 아무도 모르오."])
	await d.ui.say("이웃 아낙", ["…산에 들어갔으면 큰일인데."])
	flag("kids_asked")
	await _shot("morning")

# S0011 그날 밤 — 나그네가 밤하늘을 올려다본다
func night_sky() -> void:
	d.camera(null)
	await d.ui.fade(true, 1.0)
	d.set_hour(21.5)
	var sky = load("res://scripts/story/tale_sky.gd").new()
	sky.mode = "look"
	d.add_child(sky)
	sky.alpha = 1.0
	await d.ui.fade(false, 1.0)
	await d.ui.caption("그날 밤, 고개 위로 달이 떴다.", 2.8)
	await _shot("night_sky")
	await d.wait(1.6)
	await d.ui.fade(true, 0.8)
	sky.queue_free()
	await d.ui.fade(false, 0.8)
	d.cutscene(false)

func finish() -> void:
	commit_outcome()
	S.phase = "done"
	flag("resolved")
	d.on_phase()
	d.journal_note("사건 종결 — 「%s」" % CASE_TITLE)
	await d.show_ending()
	d.save()

# ---------------------------------------------------------------------------
# 사건 기록(R) — 웹 journal.js
# ---------------------------------------------------------------------------
const ROUTE_TEXT := {
	"jumo": "주막에서 들었다. 고개 너머 사는 떡장수가 사흘째 돌아오지 않는다고.",
	"kids": "고개 너머 외딴집에서 오누이를 만났다. 어머니가 장에 간 지 사흘째라 한다.",
}
const NIGHT_TEXT := "밤, 떡장수의 저고리를 걸친 범이 외딴집 문을 두드렸다. 털 난 손을 내밀었다가, 밀가루를 바른 손으로 다시 왔다. 아이들은 문을 열었고, 뒷간 핑계로 쪽문을 빠져나갔다."
const OUTCOME_TEXT := {
	"A_hold": "범이 아이들을 쫓을 때, 칼을 뽑고 범 앞을 막아섰다. 범은 쓰러지지 않았지만, 그사이 아이들은 우물가 나무에 올랐다.",
	"A_down": "범이 아이들을 쫓을 때, 칼을 뽑고 범 앞을 막아섰다. 나는 쓰러졌지만, 그사이 아이들은 우물가 나무에 올랐다.",
	"B_hold": "범이 아이들을 쫓아 쪽문으로 나오다 디딤돌에 부어 둔 참기름에 미끄러졌다. 그사이 아이들은 우물가 나무에 올랐다.",
	"B_down": "범이 아이들을 쫓아 쪽문으로 나오다 디딤돌에 부어 둔 참기름에 미끄러졌다. 그사이 아이들은 우물가 나무에 올랐다.",
	"C": "범이 아이들을 쫓을 때, 오솔길의 떡 냄새로 숲속 빈터 어귀까지 꾀어내고 횃불로 물러나게 했다. 범은 곧 돌아왔지만, 그사이 아이들은 우물가 나무에 올랐다.",
}
const TALE_END := [
	"아이 둘이 하늘로 올라가는 것을 보았다. 범도 줄을 빌었지만, 썩은 동아줄이 끊어져 수수밭에 떨어졌다.",
	"그날 밤 하늘에 빛 둘이 자리를 잡았다. 마을 사람들은 아이들이 어디 갔는지 모른다.",
]

func solutions() -> Array:
	var k := func(id): return S.knows(id)
	var has_torch: bool = S.has(TORCH) or bool(S.world.get("torch_lit", false))
	var has_bait: bool = S.has(TTEOK) or bool(S.world.get("cake_bait", false))
	var has_oil: bool = S.has(OIL) or bool(S.world.get("oil_on_step", false))
	var cp := 0
	for id in ["K_MIMIC", "K_FLOUR", "K_FOOD", "K_TERRITORY"]:
		if k.call(id): cp += 1
	var c_ok: bool = k.call("K_FOOD") and has_bait and k.call("K_TERRITORY") and has_torch
	var c_hint := "범의 버릇을 더 알면 범을 잠시 집에서 떼어 놓을 수 있을지 모른다." if cp < 2 else "범이 무엇에 끌리고 무엇을 꺼리는지 하나씩 맞춰지고 있다."
	if cp == 4: c_hint += ("" if has_torch else " 불이 있어야 할 것 같다.") if has_bait else " 꾈 것이 있어야 할 것 같다."
	return [
		{ "id": "A", "title": "범 앞을 막아선다", "available": true, "text": "범과 아이들 사이를 막아선다. 이 범은 쉽게 쓰러지지 않는다. 버티는 만큼 아이들이 멀어진다." },
		{ "id": "B", "title": "미끄러운 디딤돌" if k.call("K_CLIMB") else "???", "available": k.call("K_CLIMB") and has_oil,
			"text": "아이들이 드나드는 쪽문 디딤돌에 참기름을 부어 둔다. 쫓아 나오는 범이 미끄러진다.",
			"hint": "범은 미끄러운 곳을 오르지 못했다. 미끄럽게 할 무언가가 있다면…" if k.call("K_CLIMB") else ("기름병이 손에 있다. 쓸 데가 있을까…" if has_oil else "범이 무엇에 미끄러지는지 아직 모른다.") },
		{ "id": "C", "title": "떡과 횃불로 잠시 꾄다" if cp >= 2 else "???", "available": c_ok,
			"text": "오솔길에 떡을 놓아 범을 빈터 어귀까지 꾀어내고, 횃불로 잠시 물러나게 한다. 범은 곧 돌아온다.", "hint": c_hint },
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
	if S.has_clue("pass_memory"): p.append("사흘 전 고갯길 — 떡장수는 고개마다 떡을 내주며 걸었고, 서낭당 앞에서 돌아오지 못했다.")
	var o := String(S.flags.get("pending_detail", S.vars.get("CASE_NAMWON_DETAIL", "")))
	if S.phase == "night" and o == "" and not f("climax_started"): p.append("밤이 되었다. 범은 오늘 밤 외딴집에 올 것이다. 숨기 전에 할 수 있는 일을 하자.")
	if S.has_clue("door_tricks"): p.append(NIGHT_TEXT)
	if o != "": p.append(OUTCOME_TEXT.get(o, ""))
	if S.has_clue("sky_rise"): p.append_array(TALE_END)
	if String(S.vars.get("MAIN_MASTER_TRACE", "")).split(",").has("HANYANG"):
		p.append("기록책을 본 노인이 말했다. 전에도 그런 책을 든 양반이 한양으로 갔다고.")
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
		if chosen: e.text = String(s.text) + " — 이 방법으로 시간을 벌었다."
		sols.append(e)
	return { "cases": [{ "id": "namwon", "title": CASE_TITLE, "status": "solved" if solved else "active",
		"summary": summary(), "clues": clues, "rules": rules, "solutions": sols, "notes": S.notes }] }

func ending_data() -> Dictionary:
	var o := String(S.vars.get("CASE_NAMWON_DETAIL", "A_hold"))
	var k := String(S.vars.get("CASE_NAMWON_OUTCOME", "A"))
	return {
		"case_title": CASE_TITLE,
		"title": "하늘로 오른 아이들",
		"outcome": k,
		"paragraphs": [NIGHT_TEXT, OUTCOME_TEXT.get(o, ""), TALE_END[0], TALE_END[1]],
		"record": "새 해결 수단 「짐승 흔적 읽기」. 기록책에 새로 적힌 곳 — 한양.",
	}
