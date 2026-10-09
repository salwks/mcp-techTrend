# 사건 「산길의 실종」 — 데이터로 쓰기 번거로운 장면(여는 화면·회상·밤의 문·세 갈래·동아줄·다음 날 아침·밤하늘)과 기록책·결말 카드.
# 웹 seolhwa/src/story/case_sanggil.js·common.js·journal.js 이식(대사는 시나리오 §8에 맞춰 줄임).
# v3(방향 전환안 §3·§8): 밤부터 원작 「해와 달이 된 오누이」 장면(FIXED_BEATS)을 화면에서 겪는다. 원작 인물의 핵심 행동은 오누이가 한다.
#   플레이어는 범을 죽이지 않는다 — A/B/C는 오누이가 나무에 오를 시간을 버는 방법. 마을이 오누이를 거두는 결말은 없다.
# v3.2(seolhwarok_NAMWON_v3.2_scenario.md) ACT 0~2: 여는 장면 · 주모 물음과 이겸 연결(사건 기록 도장) · 역참 마부 · 이웃 아낙 · 오누이.
#   함지 회상(mother_flashback)은 없앴다. 밤은 주막 잠(rest)이 아니라 외딴집에서 해 지기를 기다려(night_fall) 넘어간다.
# v3.2 ACT 3~5: 고갯길 단서 연출(떡 셋·치맛자락 인서트·피·발자국 따라가기·광주리 CAMERA 3A) · 어머니의 과거 장면(past_scene — 기록하지 않음) ·
#   첫 조우(first_encounter — 공포·CAMERA 4A·전투 배우기) · 포수·방앗간 · 연결 추론(check_link) · 외딴집 쪽 흰 발자국(white_trail).
# v3.2 ACT 6~9: 해 질 무렵 귀환·경고·포수와 역할 나누기(dusk_return) · 준비 · hide_spot 기다리기 → 밤의 문(night_door: night_arrival ·
#   first_knock(7A·7B·7C) · between_knocks(조작) · second_knock · kids_escape · reveal_tiger) → 시간 벌기(buy_time A/B/C, 끝에 밀쳐냄) →
#   tree_scene(우물·참기름·아우의 실수) · axe_climb · last_stand(조작) → 기존 ACT 10 동아줄(rope_night). 옛 climax()·night_fall()은 없앴다.
# 데이터(namwon_data.gd)의 { "call": "이름" }과 조건식 fn('이름')이 이 함수들을 부른다.
extends RefCounted

const D := preload("res://story/namwon/namwon_data.gd")
const Sound := preload("res://scripts/audio/sound.gd")
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

# 해 질 무렵 외딴집으로 돌아갈 때가 되었나(v3.2 §31 dusk_return) — 범을 보았고(§73 범의 정체는 첫 조우가 필수),
#   오누이를 만났고(“찾았어요?”), 범이 집 쪽으로 올 것을 짐작했을 때(흰 발자국·연결 추론 — 둘 다 놓쳤으면 단서 12개로 안전장치).
#   옛 밤 저장을 되돌린 경우(night_ready_legacy)도. 시각은 보지 않는다(게임 시계는 저절로 흐르지 않는다)
func night_ready() -> bool:
	if f("night_ready_legacy"): return true
	return f("case_started") and f("first_encounter") and f("met_kids") and (f("tiger_house_suspected") or f("link_inferred") or S.clues.size() >= 12)

# 주모에게 물은 것(이겸 연결 §9: 둘 이상) — "보지 못했소."는 물음이 아니다
const JUMO_QS := ["jq_who", "jq_what", "jq_when", "jq_route", "jq_kids", "jq_search"]
func jumo_asked() -> int:
	var n := 0
	for k in JUMO_QS:
		if f(k): n += 1
	return n

# C(떡과 횃불)가 되는가 — 오솔길 어귀에 떡(먹이 버릇을 알아야 놓을 수 있다) + 불(횃불을 지녔거나 마당 횃대에 붙였다). v3.2 §33
func c_ready() -> bool:
	return bool(S.world.get("cake_bait", false)) and S.knows("K_FOOD") and (S.has(TORCH) or bool(S.world.get("torch_lit", false)))

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
	if f("dusk_prep") or S.phase == "night":
		return ["", "오늘 밤 범이 오기 전에 무엇을 준비할 수 있는가.", "주모  “불이라도 하나 챙겨 가시오. 짐승은 불을 꺼린다던데.”", "범은 떡 냄새를 따라왔고, 빈터 밖까지는 쫓지 않았다."][mini(stage, 3)]
	if path_clues() == 0:
		return ["", "떡장수는 마지막으로 어디로 갔는가.", "포수  “고개 쪽 길은 요새 아무도 안 넘으려 하오.”", "떡장수는 고개 너머 장으로 가는 길이었다."][mini(stage, 3)]
	if not f("first_encounter"):
		return ["", "고갯마루 너머에는 무엇이 있었는가.", "", "떡이 한 방향으로 이어져 있었다."][mini(stage, 3)]
	if not S.has_clue("flour_prints"):
		return ["", "범은 사람 사는 데까지 내려와 무엇을 하는가.", "포수  “고개 아래 방앗간에서도 밤마다 뭔가 뒤진다더군.”", "범은 사람 냄새를 피하지 않았다."][mini(stage, 3)]
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
	if id in ["flour_prints", "claw_marks", "territory", "hunter_word", "flour_sack", "white_trail"]: S.seen["S0006"] = true
	if id in ["voice_at_night", "flour_prints"]: check_link()
	# 흉내 의심의 다른 길(§73): 밤에 문 앞에서 직접 본 것
	if id == "door_tricks" and not S.knows("K_MIMIC"): d.learn_rule("K_MIMIC", true)

# 사건 기록이 선다(v3.2 §9): 도장 소리 + 「새 사건」 → R 기록책 안내(실제로 열어야 끝난다)
func start_case(route: String) -> void:
	if f("case_started"): return
	flag("case_started"); flag("route", route)
	d.learn_clue("rumor", true)
	d.sfx("journal_stamp")
	d.ui.toast("새 사건 — 「%s」" % CASE_TITLE, "journal")
	if d.onboard != null: d.onboard.on_case_started()

# 주모 물음 하나가 끝날 때마다(namwon_data.jumo_questions) — 둘 이상이면 이겸 연결 한 번
func jumo_after_question() -> void:
	if jumo_asked() >= 2 and not f("igyeom_link"): await igyeom_link()

# §9 이겸 연결 — CAMERA 1B: 대화 구도에서 10% 다가선다. 그 뒤 사건 기록
func igyeom_link() -> void:
	flag("igyeom_link")
	var tc: Dictionary = d.talk_cam
	if not tc.is_empty():
		var c2 := tc.duplicate()
		c2.distance = float(tc.get("distance", 13.5)) * 0.9
		d.camera(c2)
	await d.ui.caption("주모의 눈길이 기록책에 머문다.", 1.4)
	await d.ui.say("주모", ["…그 책."])
	await d.ui.say("나그네", ["이 책이 왜 그러오?"])
	await d.ui.say("주모", ["며칠 전에 비슷한 책 들고 다니는 선비도 있었소."])
	await d.ui.say("나그네", ["그 사람이 뭘 물었소?"])
	await d.ui.say("주모", ["그 아낙 이야기를 묻더군.", "그리고 똑같이 고갯길을 물었소."])
	if not tc.is_empty(): d.camera(tc)
	start_case("jumo")

# §10 역참·마방 — 남원 역참 문 앞에 처음 다가갈 때(마부는 역참 그림 station_life의 마부, 대화 카메라는 기다리는 말 자리 쪽)
func station_intro() -> void:
	if f("station_tut_seen"): return
	flag("station_tut_seen")
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var w: Vector2 = _mabu_pos()
	var tc: Dictionary = d.data.get("case", {}).get("talk_camera", {})
	var cam := tc.duplicate(); cam.focus = [(pp.x + w.x) * 0.5, (pp.y + w.y) * 0.5]
	d.camera(cam)
	d.face_actor("player", null, w)
	Sound.music_level(0.5, 0.6)
	await d.ui.say("마부", ["먼 길 가시오?"])
	await R([{ "choice": "", "loop": true, "options": [
		{ "label": "말을 빌릴 수 있소?", "when": "not f('st_q_rent')", "do": [{ "flag": "st_q_rent" },
			{ "say": "마부", "lines": ["문 앞에 매 둔 말이면 내드리리다. 큰길로만 다니오.", "고개 너머 산길은 말이 못 들어가오. 거긴 걸어서 넘으시오."] }] },
		{ "label": "역마는 어떻게 쓰오?", "when": "not f('st_q_how')", "do": [{ "flag": "st_q_how" },
			{ "say": "마부", "lines": ["한 번 가 본 큰 고을이나 역이면 말을 갈아타며 빨리 갈 수 있소.", "처음 가는 길은 직접 넘어야 하고."] },
			{ "call": "fast_hint" }] },
		{ "label": "그냥 가겠소.", "end": true }] }])
	Sound.music_level(1.0, 1.0)
	d.camera(null)

# 마부 자리: 역참 그림(station_life)이 살아 있으면 그 마부, 아니면 기다리는 말 자리
func _mabu_pos() -> Vector2:
	var hr = d.main.get("horse_ride")
	var life = hr.life if hr != null else null
	if life != null and life.live.has("namwon") and life.live.namwon.has("groom"):
		var p: Vector3 = life.live.namwon.groom.ch.position
		var g := Vector2(p.x, p.z)
		if g.distance_to(Vector2(d.main.player_pos.x, d.main.player_pos.z)) < 12.0: return g   # 마방 안쪽 멀리 있으면 문 앞 쪽으로
	return d.anchor("station_wait")

# "H — 역마 이동"은 실제로 역마로 갈 곳이 있을 때만(가 본 다른 고을·역 — 같은 공간은 300m 밖) 보인다
func fast_ready() -> bool:
	var FT = load("res://scripts/region/fast_travel.gd")
	if d.main.get("horse_ride") == null: return false
	var ft = FT.new(d.main)
	ft._gather()
	var ok := false
	for it in ft.items:
		if bool(it.ok) and (not bool(it.same) or float(it.get("dist", 0.0)) > 300.0): ok = true; break
	ft.free()
	return ok

var fast_hint_shown := false   # 시험 기록
func fast_hint() -> void:
	if not fast_ready(): return
	fast_hint_shown = true
	if d.onboard != null: d.onboard.once("FAST", "H   역마 이동", Callable(), 6.0)

# §11 첫 방문 — 이웃 아낙이 빈 그릇을 들고 집에서 나온다(CAMERA 2A: 집을 위, 플레이어를 아래로). 말을 마치면 방앗간 쪽으로 간다
func neighbor_visit() -> void:
	if f("neighbor_visit_seen"): return
	flag("neighbor_visit_seen")
	d.cutscene(true)
	flag("neighbor_visit_on")
	d.place_actor("neighbor_visit", "house_door", null, "down")
	d.anim_actor("neighbor_visit", "idle")
	# 집(위)과 플레이어(아래)가 함께 들게 — 겨냥점은 집에서 플레이어 쪽으로 조금(대화창이 화면 아래 1/4을 덮는다)
	var hp: Vector2 = d.anchor("house")
	var pl := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var fo := hp + (pl - hp).limit_length(14.0) * 0.55
	d.camera({ "focus": [fo.x, fo.y], "pitch": 42.0, "distance": 24.0, "fov": 34.0 })
	Sound.music_level(0.5, 0.6)
	var door: Vector2 = d.anchor("house_door")
	await d.move_actor("neighbor_visit", [[door.x + 0.6, door.y + 2.0]], 1.2, "walk", "idle")
	d.face_actor("neighbor_visit", null, "player")
	d.face_actor("player", null, "neighbor_visit")
	await d.ui.say("이웃 아낙", ["길손이 웬일이시오?"])
	await d.ui.say("나그네", ["여기 사는 떡장수를 찾고 있소."])
	await d.ui.say("이웃 아낙", ["그 양반이면 아직도 안 왔어요."])
	d.face_actor("neighbor_visit", "up", null)   # 집 쪽을 돌아본다
	await d.wait(0.5)
	d.face_actor("neighbor_visit", null, "player")
	await d.ui.say("이웃 아낙", ["아이들 때문에 아침저녁으로 밥만 챙겨다 주고 있지.", "어미 돌아온다고 집을 안 떠나요."])
	Sound.music_level(1.0, 1.0)
	d.camera(null)
	d.cutscene(false)
	_neighbor_leave()

# house_door → yard → 방앗간 쪽으로 걸어가 사라진다(조작권은 이미 돌려줌)
func _neighbor_leave() -> void:
	await d.move_actor("neighbor_visit", ["yard", "mill"], 1.3, "walk", "idle")
	flag("neighbor_visit_on", false)
	d.show_actor("neighbor_visit", false)

# 낮 음악(v3.2 소리 원칙 — 최소): 남원 낮 탐색 동안만 bgm_day_calm을 조용히. 여는 검은 화면·첫 조우 뒤·밤에는 없다.
#   story_director가 1초마다 묻고 바뀔 때만 Sound.music을 부른다(다른 공간으로 가면 그쪽이 ""를 돌려 멈춘다)
func music_wanted() -> String:
	if S.phase == "night" and f("night_wait_started") and not f("night_music_off") and not f("act10_started"): return "bgm_night_drone"   # 밤 — 낮게(노크 때 끊는다)
	if S.phase != "explore" or f("first_encounter"): return ""
	if f("s0000_started") and not f("INTRO_MASTER_VOICE_DONE"): return ""
	var h: float = d.main.hour
	return "bgm_day_calm" if h >= 5.5 and h < 18.0 else ""

# 이전 결과로 범이 다쳤으면 체력 낮춰 시작
func combat_mods(_arena: String, mods: Dictionary) -> Dictionary:
	var m := mods.duplicate()
	if f("tiger_wounded"): m.hpRatio = minf(float(m.get("hpRatio", 1.0)), 0.85)
	return m

func on_load() -> void:
	# 결정 6 — 밤 도중 저장(옛 절정 climax_started·옛 밤 준비, 새 밤 장면)은 저녁 준비 바로 앞으로 되돌린다. 결말 변수는 S0009 끝에야 쓰므로 그 앞이면 모두
	if S.phase == "night" and String(S.vars.get("CASE_NAMWON_OUTCOME", "")) == "": _rollback_night()
	if f("beat_mother_harmed_running"): S.flags.erase("beat_mother_harmed_running")
	# v3.2 첫 조우 도중 저장: 조우를 처음부터 다시(트리거가 다시 선다)
	if f("first_encounter_running"):
		for k in ["first_encounter_running", "first_encounter", "_trig_s0005_pass", "_trig_s0005_territory"]: S.flags.erase(k)
	# v3.2: 없앤 함지 회상 도중 저장(show_mother) · 이웃 아낙이 걸어가던 도중 저장
	for k in ["show_mother", "neighbor_visit_on"]: S.flags.erase(k)
	kids_place()
	# 여는 장면 도중 저장에서 이어 하면: 남원 전경·제목은 건너뛴 것으로
	if f("s0000_started") and not f("INTRO_NAMWON_TITLE_DONE") and S.phase != "start":
		S.flags["INTRO_MASTER_VOICE_DONE"] = true
		if Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("s0000_vista")) > 400.0: S.flags["INTRO_NAMWON_TITLE_DONE"] = true

# 결정 6 · §76 안전지점 롤백 — 밤 도중 저장을 새 장면 중간에 1:1로 맞추지 않는다. 단서·아이템·일반 진행은 그대로 두고, 밤의 임시 플래그·결과·
#   원작 밤 장면 기록(beat)만 지운다. 준비해 둔 것(디딤돌 기름·오솔길 떡·횃대 불)은 물건을 이미 쓴 것이라 그대로 둔다.
#   옛 밤(주막 잠·night_fall·옛 절정 — dusk_prep 없음): 해 질 무렵(18.6시) 외딴집 마당 → 곧 귀환·경고·포수·준비(dusk_return)가 다시 돈다.
#   새 밤(dusk_prep 있음): 준비 중(21시) 숨은 자리 — 다시 준비하고 “기다린다”를 고른다.
const NIGHT_TEMP_FLAGS := ["climax_started", "pending_outcome", "pending_detail", "kids_in_tree", "kids_gone", "yard_losses", "hunter_helped",
	"night_wait_started", "first_knock_seen", "hairy_paw_seen", "tiger_withdrawn", "white_paw_seen", "kids_escape_started", "kids_up_running",
	"tiger_revealed", "between_knocks_on", "night_music_off", "torch_block_on", "torch_carried", "tiger_shoved", "hunter_arrow", "time_line",
	"last_stand_done", "act10_started", "kids_asked", "resolved"]
const NIGHT_BEATS := ["tiger_disguise", "door_tricks", "kids_escape_tree", "well_reflection", "kids_lies", "kids_prayer", "new_rope_rise", "tiger_rotten_rope", "sun_moon"]
const NIGHT_WORLD := ["kids_in_tree", "oil_on_tree", "sorghum_red", "white_paw", "hairy_paw"]
var rollback := ""   # 시험 기록: "" | old_night | night
func _rollback_night() -> void:
	rollback = "night" if f("dusk_prep") else "old_night"
	for k in NIGHT_TEMP_FLAGS: S.flags.erase(k)
	for b in NIGHT_BEATS: S.flags.erase("beat_" + b)
	S.flags["beats"] = ",".join(beats_seen().filter(func(x): return not NIGHT_BEATS.has(x)))
	for k in NIGHT_WORLD: S.world.erase(k)
	for k in ["S0007", "S0008", "S0009"]: S.seen.erase(k)
	S.phase = "explore"
	if rollback == "old_night":
		for k in ["dusk_return_seen", "dusk_prep", "kids_warned", "_trig_dusk_return"]: S.flags.erase(k)
		S.flags["night_ready_legacy"] = true   # 옛 조건으로 밤까지 온 저장 — 귀환은 곧바로 열린다
		S.time = 18.6
	else:
		S.time = 21.0
	d.set_hour(S.time)
	d.teleport_to("hide_spot", "left")
	d.runner.log_line("rollback", rollback)
	printerr("STORY rollback namwon %s → 저녁 준비 앞(phase=%s clues=%d)" % [rollback, S.phase, S.clues.size()])

# 호랑이 이야기 프레임(knock·sniff·climb_try·slip + 변장 :d, 15쪽 약 60MB)은 절정 직전(밤으로 넘어갈 때 암전 속)에 읽는다
func load_tiger_story() -> void:
	SpriteChar.load_bank("tiger", "frames.json")
	SpriteChar.merge_bank("frames_story.json", ["tiger"])
	SpriteChar.merge_bank("frames_story_namwon_rope.json", ["tiger"])   # 동아줄: 줄에 매달려 오르기(rope_climb)·뒤집혀 떨어지기(fall_flip), 옆모습 한 쪽
	# 오누이: 하늘 줄을 손을 번갈아 끌어올림(rope_up). 본 은행(frames_story.json)을 먼저 읽어야 클립이 더해진다(없으면 climb 끝 자세로)
	for k in ["story_girl", "story_boy"]:
		if d._ensure_bank(k) == k: SpriteChar.merge_bank("frames_story_namwon_rope.json", [k])

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
			if await _sw(0.4): break
	flag("INTRO_MASTER_VOICE_DONE")
	d.ui.title_card_stop()
	d.ui.book_page(["남원"], 0.0)   # v3.2 §S0000 — 기록책 한 장: 남원
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

# ---------------------------------------------------------------------------
# ACT 3 고갯길(v3.2 §15~§22) — 단서마다 카메라 개입은 짧게(0.3~2초). 보는 것으로 시작하지 않고 다가가면(반경) 시작한다
# ---------------------------------------------------------------------------
func _pp() -> Vector2:
	return Vector2(d.main.player_pos.x, d.main.player_pos.z)

# 소리 하나(sfx_cue도 낸다 — 시험이 듣는다). opts: Sound.play·play_at의 {db, bus, …}
func _snd(id: String, at = null, opts := {}) -> void:
	d.sfx_cue.emit(id)
	if at == null: Sound.play(id, opts)
	else: Sound.play_at(id, d.audio_pos(at), d.main.scene_vp, opts)

# §15 단서 발견: 처음 그 단서 6~8m(NUDGE_R) 안에 들면 카메라가 단서 쪽으로 0.2초 기울었다가 곧장 돌아온다(조작은 그대로)
const NUDGE_R := 7.0
var _nudge_t := 0.0
var nudged: Array = []   # 시험 기록(기울인 단서 id 차례)
func ambient(dt: float) -> void:
	_night_clock(dt)
	_leash_step()
	if f("dusk_prep") and not f("night_wait_started") and S.phase == "explore" and d.main.hour > PREP_MAX_HOUR and not d.runner.busy:
		d.set_hour(PREP_MAX_HOUR)   # 준비하는 동안 밤이 깊어지기만 한다(자정은 숨어 기다려야 온다)
	_nudge_t -= dt
	if _nudge_t > 0.0: return
	_nudge_t = 0.12
	if S.phase != "explore" or not f("case_started"): return
	if d.runner.busy or d.ui.modal or d.ui.journal_open or d.combat_view.active or d._cut: return
	var rig = d.main.rig
	if rig.override != null or rig.focus != null or rig.gliding(): return
	var pp := _pp()
	for o in d.data.get("objects", []):
		if String(o.get("event_id", "")) != "S0004": continue
		var id := String(o.id)
		if f("nudge_" + id) or not d.runner.cond(o.get("when", true)): continue
		var at: Vector2 = d.anchor(o.at)
		if pp.distance_to(at) > NUDGE_R: continue
		S.flags["nudge_" + id] = true
		nudged.append(id)
		d.runner.log_line("nudge", id)
		_nudge(at)
		return

func _nudge(at: Vector2) -> void:
	var rig = d.main.rig
	var q := _pp().lerp(at, 0.45)
	var mine := { x = q.x, z = q.y }
	rig.focus = mine
	rig.glide(0.2)
	await d.get_tree().create_timer(0.22).timeout
	if is_same(rig.focus, mine):
		rig.focus = null
		rig.glide(0.2)

# 카메라를 sec초 동안 옮긴다(spec: d.camera와 같음) — 끝까지 기다린다
func _cam_to(spec: Dictionary, sec: float) -> void:
	d.camera(spec)
	d.main.rig.glide(sec)
	await d.wait(sec)

func _cam_back(sec := 0.5) -> void:
	d.camera(null)
	d.main.rig.glide(sec)
	_tilt(true)

# 틸트시프트 흐림 — 바닥 흔적을 내려다보는 짧은 연출 동안만 끈다(_cam_back이 원래대로 — 사용자가 P로 꺼 둔 것은 그대로)
var _tilt_saved = null
func _tilt(on: bool) -> void:
	var post = d.main.get("post")
	if post == null: return
	if not on:
		if _tilt_saved == null: _tilt_saved = post.tilt
		post.tilt = false
	elif _tilt_saved != null:
		post.tilt = _tilt_saved
		_tilt_saved = null

# §16~§18 떡 — 찾은 차례대로(어느 떡을 먼저 줍든 첫째·둘째·셋째의 말)
const CAKE_LINES := [
	["떡 하나가 흙에 반쯤 묻혀 있다.", "누군가 급히 떨어뜨린 것 같지는 않다.", "둘레 흙에 짐승 코 자국."],
	["같은 떡.", "첫 번째와 일정한 거리를 두고 떨어져 있다."],
	["또 하나."],
]
const CAKE_RECORD := "떡이 고갯길을 따라 이어진다."
var cake_order: Array = []   # 시험 기록: [떡 id, 몇 번째]
func cake_found(id: String) -> void:
	var n := cakes_found()   # 이 떡 플래그는 이미 섰다
	cake_order.append([id, n])
	await d.ui.examine("떨어진 떡", CAKE_LINES[clampi(n - 1, 0, 2)])
	if n == 2: d.ui.toast("기록 — " + CAKE_RECORD, "journal")   # 기록 갱신(§17) — 단서 글이 자란다(cakes text_if)
	if n == 3: await d.ui.say("나그네", ["…떨어진 게 아니라 하나씩 내놓은 건가."])

# §19 치맛자락 — 짧은 인서트(낮은 각도·FOV 48)
func skirt_insert() -> void:
	d.main.player.visible = false   # 인서트 — 천만 보이게(틸트 흐림도 잠깐 끈다)
	_tilt(false)
	await _cam_to({ "focus": "torn_skirt", "pitch": 18.0, "distance": 3.6, "fov": 48.0 }, 0.05)
	var sp: Vector2 = d.anchor("torn_skirt")
	d.main.rig.focus = { x = sp.x, z = sp.y, y = d.world.height_at(sp.x, sp.y) - 0.5 }   # 겨냥을 덤불 높이로 낮춘다
	d.main.rig.glide(0.3)
	var rec = d.props.get("p_skirt")
	if rec != null and rec.node != null: _no_occ(rec.node)   # 카메라 가까이 오는 물건은 먹점 무늬로 흐려진다 — 인서트 동안은 끈다
	await d.wait(0.35)
	await d.ui.caption("덤불에 쪽빛 천.", 1.8)
	await d.ui.caption("네 줄로 길게 찢어져 있다.", 2.0)
	d.main.player.visible = true
	_no_occ_clear()
	_cam_back(0.4)
	await d.ui.say("나그네", ["칼자국은 아니다."])
	d.learn_clue("torn_skirt")

# §20 피 — 음악·환경음이 끊긴다
func blood_scene() -> void:
	d.hush(4.0)
	await d.wait(0.6)
	await d.ui.examine("마른 피", ["마른 피.", "주변 풀이 한쪽으로 짓눌렸다."])
	d.learn_clue("blood")

# §21 발자국 — 카메라가 자국을 따라 약 2초: 짚신 자국이 끊기고 큰 발자국만 이어진다
const TRACK_PAN := [[-3160.0, -213.0], "tracks", "tracks_end", [-3178.0, -257.0]]
var pan_points := 0   # 시험 기록
func tracks_pan() -> void:
	await d.ui.caption("짚신 자국과 큰 짐승 발자국이 겹쳐 있다.", 2.2)
	_tilt(false)
	await _cam_to({ "focus": TRACK_PAN[0], "pitch": 54.0, "distance": 13.0, "fov": 34.0 }, 0.4)
	var rig = d.main.rig
	pan_points = 1
	for i in range(1, TRACK_PAN.size()):
		var p: Vector2 = d.anchor(TRACK_PAN[i])
		rig.focus = { x = p.x, z = p.y }
		rig.glide(0.6)
		await d.wait(0.6)
		pan_points += 1
		if i == 1: await _shot("tracks_pan")
	await d.ui.caption("짚신 자국은 끊기고, 큰 발자국만 이어진다.", 2.2)
	d.learn_clue("tracks")
	_cam_back(0.6)

# §22 서낭당 광주리 — CAMERA 3A(pitch 34 · 거리 10 · FOV 42) → 1.5초 정적 → §23 어머니의 과거 장면
func basket_scene() -> void:
	await _cam_to({ "focus": "basket", "pitch": 34.0, "distance": 10.0, "fov": 42.0 }, 0.6)
	await d.ui.caption("빈 광주리와 머리에 받치는 수건.", 2.2)
	await d.ui.caption("떡은 없다.", 1.8)
	d.learn_clue("basket")
	check_food()
	await _shot("basket")
	d.hush(2.6)
	await d.wait(1.5)   # 1.5초 정적
	await past_scene()
	_cam_back(0.6)

# ---------------------------------------------------------------------------
# §23 어머니의 과거 장면(CAMERA 3B) — 엄마를 처음이자 이곳에서만 직접 보여 준다. 플레이어가 과거를 보는 능력이 아니라 관객에게 보이는 서사 장면.
#   채도를 크게 뺀 화면 · 먹빛 가장자리(post_effect.past) · 조금 두꺼운 띠 · 플레이어 없음 · 얼굴은 보이지 않게(뒤에서, 어둡게).
#   숲 밖 목소리 “떡 하나 주면 안 잡아먹지.” 세 번 · 떡을 던짐 · 빈 광주리 · 돌아봄 → CUT TO BLACK · 숨 들이켬 · 광주리 구르는 소리.
#   기록책은 이 장면을 '확인한 사실'로 적지 않는다 — 남는 것은 빈 광주리와 피, 큰 짐승 흔적(본 흔적)뿐.
# ---------------------------------------------------------------------------
const PAST_SHADE := Color(0.10, 0.09, 0.085, 0.62)
const PAST_VOICE := "“떡 하나 주면 안 잡아먹지.”"
const PAST_KEEP := "빈 광주리와 피, 큰 짐승 흔적."
const PAST_HIDE_PROPS := ["p_cake_1", "p_cake_2", "p_cake_3", "p_skirt", "p_blood", "p_tracks", "p_basket"]
var past_voices := 0     # 시험 기록: 목소리 횟수
var past_cakes := 0      # 던진 떡
var past_look := {}      # 시험 기록: 장면 동안 본 것(플레이어 보임·채도·띠)
var _past_nodes: Array = []
var _follow_on := false

# 지난 일 인물은 먹빛으로 눌러 그린다(얼굴이 읽히지 않게)
func _tint(id: String, c: Color) -> void:
	var a = d.actors.get(id)
	if a != null and a.ch._mat != null: a.ch._mat.set_shader_parameter("flash", c)

# 지난 일 장면 동안 지금의 세상(다른 인물·고을 사람·지명·알림)을 감춘다
var _quiet_ids: Array = []
var _quiet_layer: CanvasLayer = null
func _world_quiet(on: bool) -> void:
	var amb = d.main.get("npcs_amb")
	if amb != null: amb.visible = not on
	if d.ui.get("_toasts") != null: d.ui._toasts.visible = not on
	if d.ui.get("_stamp") != null: d.ui._stamp.visible = not on   # 지명에 들어서며 찍히는 저장 도장
	# 지명·저장 도장·소지품 줄 같은 HUD는 큰 창이 열린 것처럼 감춘다(scripts/hud_gate.gd — 빈 층 하나를 '열린 창'으로)
	if on and _quiet_layer == null:
		_quiet_layer = CanvasLayer.new()
		_quiet_layer.add_to_group(load("res://scripts/hud_gate.gd").OVERLAY)
		d.add_child(_quiet_layer)
	elif not on and _quiet_layer != null:
		_quiet_layer.queue_free(); _quiet_layer = null
	if on:
		_quiet_ids = []
		for id in d.actors:
			var a: Dictionary = d.actors[id]
			if a.shown and id != "mother_past":
				_quiet_ids.append(id); a.shown = false; a.ch.visible = false
	else:
		for id in _quiet_ids:
			if d.actors.has(id): d.actors[id].shown = true
		_quiet_ids = []
		d.mark_dirty()

func _post_past(k: float) -> void:
	var post = d.main.get("post")
	if post != null: post.past = k

# 카메라가 인물 뒤를 따라간다(조금 앞을 겨냥 — 숲이 화면 대부분)
func _follow(id: String, ahead: Vector2) -> void:
	_follow_on = true
	while _follow_on and d.actors.has(id):
		var a: Dictionary = d.actors[id]
		d.main.rig.focus = { x = a.pos.x + ahead.x, z = a.pos.z + ahead.y }
		await d.get_tree().process_frame

# 떡 하나를 숲 쪽으로 던진다(포물선 0.7초) — 장면이 끝나면 지운다
func _throw_cake(from_id: String, side: float) -> void:
	var a = d.actors.get(from_id)
	if a == null: return
	past_cakes += 1
	var info: Dictionary = load("res://kit/story/clue.gd").build({ "kind": "tteok", "seed": 10 + past_cakes })
	var n: Node3D = info.node
	d._props_root.add_child(n)
	_past_nodes.append(n)
	var p0: Vector3 = a.pos + Vector3(0, 1.3, 0)
	var land := Vector2(a.pos.x + side * 4.5, a.pos.z - 1.5)
	var p1 := Vector3(land.x, d.world.height_at(land.x, land.y) + 0.05, land.y)
	var tw: Tween = d.create_tween()
	tw.tween_method(_cake_arc.bind(n, p0, p1), 0.0, 1.0, _dur(0.7))

func _cake_arc(u: float, n: Node3D, p0: Vector3, p1: Vector3) -> void:
	if is_instance_valid(n): n.position = p0.lerp(p1, u) + Vector3(0, sin(PI * u) * 1.4, 0)

func past_scene() -> void:
	if f("beat_mother_harmed"): return
	flag("beat_mother_harmed_running")
	var back := _pp()
	var face: String = d.main.player.facing
	var hour: float = d.main.hour
	d.cutscene(true)
	await d.ui.fade(true, 0.6)
	# 지금의 흔적(떡·광주리·핏자국 소품)은 감춘다 — 사흘 전이다
	for pid in PAST_HIDE_PROPS:
		var rec = d.props.get(pid)
		if rec != null and rec.node != null: rec.node.visible = false
	d.main.player.visible = false   # 플레이어 캐릭터 없음
	_world_quiet(true)
	d.teleport_to("cake_1", "up")
	d.set_hour(15.4)                # 장을 보고 해가 아직 높을 때 돌아갔다(주모)
	d.ui.letterbox(true, 0.125)     # 평소보다 조금 두꺼운 띠
	_post_past(1.0)
	var c1: Vector2 = d.anchor("cake_1")
	d.spawn_actor("mother_past", "ricecake_mother", [c1.x - 1.2, c1.y + 5.0], "up", "", "")
	await d.get_tree().process_frame
	_tint("mother_past", PAST_SHADE)
	d.camera({ "pitch": 22.0, "distance": 9.5, "fov": 40.0 })
	_follow("mother_past", Vector2(0.0, -1.8))
	await d.wait(0.3)
	past_look = { "player_visible": d.main.player.visible, "past": float(d.main.post.past) if d.main.get("post") != null else -1.0,
		"letterbox": d.ui._lb_top.size.y / maxf(1.0, d.ui.get_viewport().get_visible_rect().size.y) }
	await d.ui.fade(false, 0.9)
	# 첫 굽이 — 걷다가 목소리, 멈추고, 떡 하나를 숲 쪽으로
	await d.move_actor("mother_past", [[c1.x - 0.4, c1.y + 1.5]], 1.4, "walk", "idle")
	await _shot("past_walk")
	await _past_voice()
	await d.wait(0.5)
	_throw_cake("mother_past", 1.0)
	await d.wait(0.9)
	await d.move_actor("mother_past", ["cake_2"], 2.0, "walk", "idle")
	# 다음 굽이 — 또 목소리, 또 떡. 걸음이 빨라진다
	await _past_voice()
	await d.wait(0.35)
	_throw_cake("mother_past", -1.0)
	await _shot("past_throw")
	await d.wait(0.6)
	await d.move_actor("mother_past", ["cake_3", "torn_skirt"], 2.7, "walk", "idle")
	# 마지막 — 광주리 안이 빈다. 바닥을 한 번 더 더듬는다(멈칫)
	await d.ui.caption("광주리가 비었다.", 1.6)
	await d.wait(0.7)
	await _past_voice()
	await d.wait(0.5)
	# 뒤를 돌아보는 순간 CUT TO BLACK(얼굴은 보이지 않는다) — 과한 포효 없이 짧은 숨, 광주리 구르는 소리
	d.anim_actor("mother_past", "idle")
	await d.wait(0.25)
	await _shot("past_turn")
	d.ui._fade.color.a = 1.0
	d.face_actor("mother_past", "down", null)
	_follow_on = false
	_snd("breath_gasp")
	await d.wait(0.7)
	_snd("basket_roll")
	await d.wait(1.4)
	d.despawn_actor("mother_past")
	for n in _past_nodes:
		if is_instance_valid(n): n.queue_free()
	_past_nodes.clear()
	beat("mother_harmed")
	S.flags.erase("beat_mother_harmed_running")
	flag("past_scene_seen")
	# 현재로
	_post_past(0.0)
	d.main.player.visible = true
	_world_quiet(false)
	for pid in PAST_HIDE_PROPS:
		var rec = d.props.get(pid)
		if rec != null and rec.node != null: rec.node.visible = rec.shown
	d.set_hour(hour)
	d.teleport_to(back, face)
	d.camera(null)
	d.ui.letterbox(false)
	await d.wait(0.3)
	await d.ui.fade(false, 0.8)
	d.cutscene(false)
	d.journal_note(PAST_KEEP)   # 기록에는 본 흔적만(§23 — 과거 장면을 사실로 적지 않는다)

func _past_voice() -> void:
	past_voices += 1
	await d.ui.caption(PAST_VOICE, 2.4)

# 옛 이름(밤으로 넘어갈 때 아직 못 봤으면 — night_fall)
func pass_memory() -> void:
	await past_scene()

# ---------------------------------------------------------------------------
# ACT 4 첫 조우(v3.2 §24~§26)
#   §24 단서 셋 이상 + first_seen에 다가감(트리거 s0005_pass). 해질녘 보정은 지금 시각에서 저녁 쪽으로 몇 초에 걸쳐(되돌리지 않는다, 17시로 못 박지 않는다)
#   §25 음악·새소리가 끊긴다(Sound.hush) — 발걸음과 바람만. 조작은 쥔 채(free_move). 무언가 오른쪽, 이어 왼쪽 나무 사이를 지나간다(카메라는 돌리지 않는다).
#       first_seen 가까이 오면 CAMERA 4A(pitch 32 · 거리 18 · FOV 30) — 숲 안쪽에 범의 얼굴 1초 → 플레이어에게 돌아옴 → 그르렁 → 뒤에서 덮친다
#   §26 전투 = 전투 배우기(onboarding K 회피·L 막기 — 실제로 해야 끝). 목표는 죽이기가 아니다: 범은 쓰러지지 않고(undying)
#       약 22초 버티거나, 범 체력이 20% 깎이거나, 내 체력이 35% 아래로 내려가면 물러난다 → 따라갈 수는 있지만 숲에서 사라진다
# ---------------------------------------------------------------------------
const FIRST_DUSK := 17.3
const FIRST_RETREAT := { "seconds": 22.0, "hpRatio": 0.8, "playerHp": 0.35 }
var first_passes: Array = []   # 시험 기록: ["right", "left"]
var glimpse_t := 0.0           # 시험 기록: 얼굴을 보인 시간(초)
var dusk_from := -1.0          # 시험 기록: 보정 전 시각

# 지금 시각에서 저녁(FIRST_DUSK) 쪽으로 sec초에 걸쳐 흐른다 — 이미 저녁이거나 밤이면 그대로(되돌리지 않는다)
func _dusk_toward(to_h: float, sec: float) -> void:
	var h0: float = d.main.hour
	dusk_from = h0
	if h0 >= to_h - 0.05 or h0 < 5.0: return
	var t := 0.0
	var dur := _dur(sec)
	while t < dur:
		await d.get_tree().process_frame
		t += d.get_process_delta_time()
		d.set_hour(lerpf(h0, to_h, smoothstep(0.0, 1.0, minf(1.0, t / dur))))

# 무언가 나무 사이를 지나간다(side +1 오른쪽 · -1 왼쪽, 지금 고정 화면 안 — 카메라는 돌리지 않는다)
func _pass_by(side: float) -> void:
	var pp := _pp()
	var a := pp + Vector2(6.6 * side, -6.0)
	var b := pp + Vector2(5.4 * side, -11.5)
	if side < 0.0:   # 왼쪽은 안에서 밖으로
		var tmp := a
		a = b
		b = tmp
	var id := "first_shadow_%s" % ("r" if side > 0.0 else "l")
	d.spawn_actor(id, "tiger", [a.x, a.y], "up" if side > 0.0 else "down", "", "")
	await d.get_tree().process_frame
	_tint(id, Color(0.05, 0.045, 0.04, 0.55))
	first_passes.append("right" if side > 0.0 else "left")
	_snd("brush_rustle", a, { "db": -2.0 })
	_snd("footstep_heavy", a, { "db": -6.0 })
	await d.move_actor(id, [[b.x, b.y]], 6.5, "walk", "walk")
	d.despawn_actor(id)

func first_encounter() -> void:
	flag("first_encounter")          # 낮 음악은 이 플래그로 멈춘다(music_wanted)
	flag("first_encounter_running")
	d.hush(-1.0)                      # 음악·새소리(환경음) — 다시 열 때까지
	_dusk_toward(FIRST_DUSK, 7.0)
	d.free_move = true                # 발걸음과 바람만 — 조작은 그대로
	_snd("wind", "player", { "bus": "SFX", "db": -3.0 })
	await d.wait(1.4)
	await _pass_by(1.0)
	await d.wait(1.5)
	await _pass_by(-1.0)
	# first_seen 가까이 오거나(8m) 조금 지나면
	var t := 0.0
	while t < 6.0 and _pp().distance_to(d.anchor("first_seen")) > 8.0:
		await d.get_tree().process_frame
		t += d.get_process_delta_time() / maxf(Engine.time_scale, 0.01)
	d.free_move = false
	if d.main.player.anim in ["walk", "run"]: d.main.player.set_anim("idle")
	await _glimpse()
	# 그르렁 — 뒤에서
	var fv := _face_vec(d.main.player.facing)
	var behind := _pp() - fv * 6.0
	_snd("tiger_growl", behind, { "db": 2.0 })
	await d.wait(0.7)
	var res: String = await _first_fight(fv)
	d.runner.last["first"] = res
	S.flags.erase("first_encounter_running")
	await after_first_encounter()
	Sound.hush_end(2.5)

static func _face_vec(face: String) -> Vector2:
	return { "up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0) }.get(face, Vector2(0, -1))

# CAMERA 4A — 숲 안쪽을 잠깐 강조: 나무 사이 범의 얼굴(상체 일부) 1초, 사라짐, 플레이어에게 돌아옴
func _glimpse() -> void:
	var g: Vector2 = d.anchor("glimpse")
	d.spawn_actor("tiger_glimpse", "tiger", [g.x, g.y], "down", "", "")   # 정면 — 나무 뒤라 얼굴과 앞가슴만
	d.anim_actor("tiger_glimpse", "idle")
	await d.get_tree().process_frame
	_tint("tiger_glimpse", Color(0.06, 0.05, 0.04, 0.5))
	await _cam_to({ "focus": "glimpse", "pitch": 32.0, "distance": 18.0, "fov": 30.0 }, 0.35)
	var t0 := Time.get_ticks_msec()
	await _shot("first_glimpse")
	await d.wait(1.0)
	glimpse_t = (Time.get_ticks_msec() - t0) / 1000.0
	d.despawn_actor("tiger_glimpse")
	_cam_back(0.35)
	await d.wait(0.4)

# 뒤에서 덮친다 — 싸움터는 플레이어 자리, 범은 바라보는 쪽 반대편 6m
func _first_fight(fv: Vector2) -> String:
	var off := -fv * 6.0 + Vector2(-fv.y, fv.x) * 1.2
	d.data.arenas.pass_wood.tiger_offset = [off.x, off.y]
	return await d.combat("pass_wood", { "mods": { "firstEncounter": true, "undying": true, "tutorial": true },
		"allow_flee": true, "retreat_at": FIRST_RETREAT.duplicate(), "store": "first" })

# ---------------------------------------------------------------------------
# S0005 첫 조우 뒤 — 범이 물러나 숲으로(따라갈 수 있지만 사라진다) · 나그네 “범…” · 기록 고갯마루의 범
# ---------------------------------------------------------------------------
var first_result := ""   # 시험 기록
func after_first_encounter() -> void:
	var res := String(d.runner.last.get("first", "retreated"))
	first_result = res
	var tg = d.combat_view.battle.tiger
	var tpos: Vector2 = tg.pos
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
		_tiger_into_forest(tpos)
		await d.ui.say("나그네", ["범…"])
	d.learn_clue("first_sight")
	# 보강서 §17 관찰 — 본 대로만(“돌진 패턴 해금” 같은 말은 쓰지 않는다)
	await R([{ "observe": "몸을 낮춘 뒤 잠시 멈춘다.", "about": "범" }, { "observe": "그다음 곧장 돌진한다.", "about": "범" }])
	check_link()

# 물러난 범이 숲 쪽으로 걸어 들어가 사라진다(조작은 돌려준 채 — 따라가 볼 수 있다)
func _tiger_into_forest(from: Vector2) -> void:
	var to_t: Vector2 = d.anchor("territory")
	var dir := (to_t - from).normalized()
	var end := from + dir * 20.0
	d.spawn_actor("tiger_flee", "tiger", [from.x, from.y], "left", "", "")
	await d.move_actor("tiger_flee", [[from.x + dir.x * 8.0, from.y + dir.y * 8.0], [end.x, end.y]], 4.2, "walk", "walk")
	_snd("brush_rustle", end, { "db": -4.0 })
	d.despawn_actor("tiger_flee")

# ---------------------------------------------------------------------------
# ACT 5 범과 사건을 잇는다(v3.2 §27~§30)
# ---------------------------------------------------------------------------
# §28 방앗간 바닥: 주인과 말하다 바닥을 본다(카메라 잠깐) — 밀가루 위 큰 발자국, 앞발만 유난히 하얗다
func mill_floor() -> void:
	_snd("flour_rustle", "flour", { "db": -4.0 })
	_tilt(false)
	await _cam_to({ "focus": "flour", "pitch": 56.0, "distance": 8.0, "fov": 36.0 }, 0.4)
	await d.ui.caption("밀가루 바닥에 큰 발자국. 앞발 자국만 유난히 하얗다.", 2.4)
	await _shot("mill_flour")
	see_flour()
	var tc: Dictionary = d.talk_cam
	if not tc.is_empty():
		d.camera(tc); d.main.rig.glide(0.4); _tilt(true)
	else: _cam_back(0.4)

# 밀가루 발자국을 제 눈으로 보았다(주인과 말하며 · 또는 바닥을 바로 살펴) — §73 flour_prints
func see_flour() -> void:
	flag("flour_prints")
	d.learn_clue("flour_prints")
	d.learn_rule("K_FLOUR")

# §29 연결 추론 — 어젯밤의 목소리 + 밀가루 발자국 + 첫 조우를 모두 쥐면 기록책에 한 줄만. 흉내라고 정하지 않는다
const LINK_LINE := "어젯밤 아이들이 들었다는 목소리와 이 범은 관계가 있을 수 있다."
func check_link() -> void:
	if f("link_inferred"): return
	if not (S.has_clue("voice_at_night") and S.has_clue("flour_prints") and f("first_encounter")): return
	flag("link_inferred")
	d.ui.toast("기록 — " + LINK_LINE, "journal")
	d.learn_rule("K_MIMIC", true)   # 버릇 칸에도 '모른다'로만(글: 관계가 있을 수 있다 · 아직 확인하지 못했다)

# §30 흰 발자국 — 외딴집 쪽으로 짧게 따라간다 → “…집 쪽이다.” 여기서 목적이 조사에서 보호로
const PURPOSE_LINE := "오늘 밤은 아이들 곁에 있어야 한다."
func white_trail() -> void:
	if f("tiger_house_suspected"): return
	_tilt(false)
	await _cam_to({ "focus": "white_trail_a", "pitch": 50.0, "distance": 13.0, "fov": 34.0 }, 0.35)
	var rig = d.main.rig
	for pt in ["white_trail_b", "white_trail_c", "house_door"]:
		var p: Vector2 = d.anchor(pt)
		rig.focus = { x = p.x, z = p.y }
		rig.glide(0.55)
		await d.wait(0.55)
		if pt == "white_trail_b": await _shot("white_trail")
	await d.ui.say("나그네", ["…집 쪽이다."])
	flag("tiger_house_suspected")
	d.learn_clue("white_trail")
	await R([{ "discover": "house" }])
	_cam_back(0.6)
	d.ui.toast("기록 — " + PURPOSE_LINE, "journal")

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

# ---------------------------------------------------------------------------
# ACT 6 해 질 무렵 외딴집(v3.2 §31~§34)
#   돌아오면 누이 “찾았어요?” — 어느 대답도 어머니의 죽음을 확정하지 않는다 → 경고(§32) → 포수와 역할 나누기(결정 4, hunter_watch) →
#   준비(§33: 기존 물건 쓰기만 — 디딤돌 참기름 B · 오솔길 떡 + 횃불 C · 아무것도 없으면 A) → hide_spot “기다린다”(§34, 23:30).
#   옛 다리(dusk_wait → night_fall)와 옛 밤 들머리(“해가 지고, 달이 떴다…” · 정답을 먼저 말하던 문장 §3.3)는 없앴다.
# ---------------------------------------------------------------------------
const DUSK_HOUR := 18.9
const PREP_MAX_HOUR := 22.5
const DUSK_LINE := "해가 진다. 오늘 밤은 아이들 곁에 있어야 한다. 숨기 전에 할 수 있는 일을 해 두자."
var dusk_choice := ""   # 시험 기록: not_yet | trace | silent

func dusk_return() -> void:
	if f("dusk_return_seen"): return
	flag("dusk_return_seen")
	if not f("beat_mother_harmed"): await past_scene()   # 원작 순서 — 밤 전에 반드시(서낭당 광주리를 안 보고 온 드문 길)
	d.cutscene(true)
	Sound.music_level(0.5, 0.6)
	var door: Vector2 = d.anchor("house_door")
	await d.ui.fade(true, 0.5)
	if d.main.hour >= 5.0 and d.main.hour < DUSK_HOUR - 0.3: d.set_hour(DUSK_HOUR)   # 19시 전후 — 이미 저녁이면 그대로
	d.teleport_to(door + Vector2(0.4, 4.4), "up")
	# 누이와 아우가 문 앞으로 나와 있다
	d.place_actor("nui", door + Vector2(-0.55, 1.3), null, "down")
	d.place_actor("au", door + Vector2(0.45, 1.5), null, "down")
	d.anim_actor("nui", "idle"); d.anim_actor("au", "idle")
	var tc: Dictionary = d.data.get("case", {}).get("talk_camera", {})
	var cam := tc.duplicate()
	var fo := door + Vector2(0.2, 2.9)
	cam.focus = [fo.x, fo.y]
	d.camera(cam)
	await d.wait(0.3)
	await d.ui.fade(false, 0.8)
	await d.ui.caption("해가 고개 너머로 기운다.", 1.8)
	# §31 — 어느 대답도 어머니 일을 아이들에게 확정해서 말하지 않는다
	await d.ui.say("누이", ["찾았어요?"])
	var i: int = await d.ui.choice("", [{ label = "아직 못 찾았다." }, { label = "고갯길에서 흔적을 찾았다." }, { label = "(대답하지 않는다)" }])
	match i:
		0:
			dusk_choice = "not_yet"
			await d.ui.say("누이", ["…그래요."])
			await d.ui.say("아우", ["내일은 찾아요?"])
			await d.ui.say("나그네", ["찾아보마."])
		1:
			dusk_choice = "trace"
			await d.ui.say("누이", ["무슨 흔적요?"])
			await d.ui.say("나그네", ["엄마가 그 길로 간 건 맞다. 그다음은 아직 모른다."])
			d.face_actor("nui", null, "au")   # 누이가 아우를 한 번 본다
			await d.wait(0.6)
			d.face_actor("nui", null, "player")
			await d.ui.say("누이", ["…알겠어요. 아우 앞에선 거기까지만 해 주세요."])
		_:
			dusk_choice = "silent"
			await d.wait(1.2)
			d.face_actor("nui", null, "au")
			await d.wait(0.5)
			d.face_actor("nui", null, "player")
			await d.ui.say("누이", ["말하기 어려운 거면, 나중에 해 주세요."])
	# §32 경고 — 아이들을 무능하게 만들지 않는다(문을 열지 말지는 아이들이 정한다)
	_shot_soon("dusk_warning", 1.2)
	await d.ui.say("나그네", ["오늘 밤 누가 와도 문부터 열지 마라."])
	await d.ui.say("누이", ["엄마여도요?"])
	await d.ui.say("나그네", ["…목소리만 듣고 열지 마."])
	await d.ui.say("아우", ["엄마 얼굴 보면 되잖아요."])
	d.face_actor("nui", null, "au")
	await d.ui.say("누이", ["알았어."])
	flag("kids_warned")
	await _hunter_role()
	d.place_actor("nui", "home"); d.place_actor("au", "home")   # 집 안으로
	Sound.music_level(1.0, 1.0)
	d.camera(null)
	d.cutscene(false)
	flag("dusk_prep")
	d.ui.toast("기록 — " + DUSK_LINE, "journal")
	d.ui.toast("준비를 마치면 마당 구석에 숨어 기다린다.", "info")

# 결정 4 — 포수와 역할을 나눈다(낮의 물음에서 이리로 옮겼다). 크게 밀리면 먼 데서 화살 한 번(fail-forward)
func _hunter_role() -> void:
	var pp := _pp()
	var from: Vector2 = d.anchor("white_trail_b")
	d.spawn_actor("hunter_dusk", "hunter", [from.x, from.y], "left", "포수", "")
	var stop := pp + (from - pp).normalized() * 2.4
	await d.move_actor("hunter_dusk", [[stop.x, stop.y]], 2.2, "walk", "idle")
	d.face_actor("hunter_dusk", null, "player"); d.face_actor("player", null, "hunter_dusk")
	var tc: Dictionary = d.data.get("case", {}).get("talk_camera", {})
	var cam := tc.duplicate(); var fo := (pp + stop) * 0.5
	cam.focus = [fo.x, fo.y]
	d.camera(cam)
	await d.ui.say("포수", ["여기 있었구려."])
	_shot_soon("hunter_role", 1.6)
	await d.ui.say("포수", ["놈이 집으로 온다는 말이 맞다면 당신은 애들 곁에 있으시오.", "나는 고개 쪽 길을 막겠소."])
	await d.ui.say("나그네", ["…그러지."])
	await d.ui.say("포수", ["크게 밀리거든 소리를 지르시오. 멀리서라도 한 대는 쏘겠소."])
	flag("hunter_watch"); flag("hunter_role_dusk")
	_hunter_leave()

func _hunter_leave() -> void:
	await d.move_actor("hunter_dusk", ["white_trail_b", "white_trail_a", "mill"], 2.4, "walk", "idle")
	d.despawn_actor("hunter_dusk")

# §34 hide_spot — 기다린다(23:30) / 아직 준비할 것이 있다
func wait_at_hide() -> void:
	var prep := []
	if S.world.get("oil_on_step", false): prep.append("디딤돌에 참기름")
	if S.world.get("cake_bait", false): prep.append("오솔길 어귀에 떡")
	if S.world.get("torch_lit", false) or S.has(TORCH): prep.append("횃불")
	var head := ("준비: " + " · ".join(prep)) if not prep.is_empty() else "아무 준비도 하지 않았다."
	_mark_shot("hide_wait")
	var i: int = await d.ui.choice(head, [{ label = "기다린다." }, { label = "아직 준비할 것이 있다." }])
	if i == 0: await R([{ "event": "S0007" }])

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
	await d.ui.caption("오솔길 어귀에 떡을 띄엄띄엄 놓았다. 냄새가 마당까지 온다.", 2.4)

# ---------------------------------------------------------------------------
# 오누이 자리(밤에는 집 안 → 쪽문으로 빠져나감 → 나무 위)
# ---------------------------------------------------------------------------
func kids_place() -> void:
	if f("kids_gone"):
		d.show_actor("nui", false); d.show_actor("au", false)
		return
	if S.phase == "night" and f("kids_in_tree"):
		d.place_actor("nui", "perch_a", 2.7, "down")
		d.place_actor("au", "perch_b", 3.1, "down")
		d.anim_actor("nui", "perch"); d.anim_actor("au", "perch")
	elif S.phase == "night" and not f("kids_escape_started"):
		d.show_actor("nui", false); d.show_actor("au", false)   # 집 안 — 문은 닫혀 있다
	elif S.phase == "night":
		pass   # 달아나는 중(연출이 쥔다)
	else:
		d.place_actor("nui", "home"); d.place_actor("au", "home")

# 오누이가 나무 밑까지 달려와 오른다(FIXED kids_escape_tree) — 범 앞을 막는 동안 따로 돈다
func kids_up() -> void:
	if f("kids_in_tree") or f("kids_up_running"): return
	flag("kids_up_running")
	var tf: Vector2 = d.anchor("tree_foot")
	for id in ["nui", "au"]:
		var a = d.actors.get(id)
		if a != null and a.shown and Vector2(a.pos.x, a.pos.z).distance_to(tf) > 0.6:
			d.move_actor(id, ["tree_foot"], 3.2, "walk", "climb")
	for i in 600:
		var done := true
		for id in ["nui", "au"]:
			var a = d.actors.get(id)
			if a != null and not a.path.is_empty(): done = false
		if done: break
		await d.get_tree().process_frame
	flag("kids_in_tree")
	S.flags.erase("kids_up_running")
	d.world_state("kids_in_tree", true)
	d.place_actor("nui", "perch_a", 1.3, "up")
	d.place_actor("au", "perch_b", 1.7, "up")
	d.anim_actor("nui", "climb"); d.anim_actor("au", "climb")
	d.learn_clue("kids_tree", true)
	beat("kids_escape_tree")
	await d.wait(1.2)
	kids_place()

# ---------------------------------------------------------------------------
# 시험 기록·조작 비율
#   night_log: [종류, 누구, 글] — 누가 무엇을 언제 했나(탈출을 누이가 먼저 정하는지 시험이 본다)
#   ctl_time: 해 질 무렵 귀환부터 기도(ACT 10) 직전까지 조작을 쥔 시간 / 연출 시간(게임 초) — ambient가 매 프레임 센다
# ---------------------------------------------------------------------------
var night_log: Array = []
var ctl_time := { "free": 0.0, "cut": 0.0 }
var between_t := 0.0           # 노크 사이 조작을 돌려준 시간(게임 초)
var between_free := false      # 노크 사이 실제로 움직일 수 있었나(blocks_move가 거짓)
var mill_shadow_seen := false
var door_warned := false
var shoves: Array = []         # [갈래·장면, 밀려난 거리]
var tiger_full_seen_early := false

func _nlog(kind: String, who: String, text: String) -> void:
	night_log.append([kind, who, text])

func _say(who: String, lines: Array) -> void:
	for l in lines: _nlog("say", who, String(l))
	await d.ui.say(who, lines)

# 대사가 다 찍힌 뒤 한 장(화면 검토 때만 — 기다리지 않는다)
func _shot_soon(nm: String, sec: float) -> void:
	if d.test == null or not d.test.has_method("tale_shot"): return
	await d.wait(sec)
	d.test.tale_shot(nm)

# 숨어 듣는 목소리(조작을 쥔 채) — 자막으로
func _voice(who: String, line: String, sec := 2.2) -> void:
	_nlog("voice", who, line)
	await d.ui.caption("%s  “%s”" % [who, line], sec)

func _night_clock(dt: float) -> void:
	if not f("dusk_return_seen") or f("act10_started") or S.phase == "done": return
	if d.title != null and d.title.active: return
	if d.blocks_move() and not d.drives_player(): ctl_time.cut += dt
	else: ctl_time.free += dt

func control_share() -> float:
	var t: float = ctl_time.free + ctl_time.cut
	return 1.0 if t <= 0.0 else ctl_time.free / t

# 숨은 자리 둘레(반지름 r)에서만 움직이게 — 지금 나서면 아이들이 문을 열지도 모른다
var _leash_c := Vector2.INF
var _leash_r := 0.0
var _leash_said := false
func _leash(c: Vector2, r: float) -> void:
	_leash_c = c; _leash_r = r; _leash_said = false

func _leash_off() -> void:
	_leash_c = Vector2.INF

func _leash_step() -> void:
	if _leash_c == Vector2.INF: return
	var v := _pp() - _leash_c
	if v.length() <= _leash_r: return
	var q := _leash_c + v.normalized() * _leash_r
	d.set_player_pos(Vector3(q.x, d.world.height_at(q.x, q.y), q.y))
	if not _leash_said:
		_leash_said = true
		d.ui.caption("…지금 나서면 안 된다.", 1.6)

# 밤 음악(bgm_night_drone, 낮게) — 노크 때 끊는다
func _music_cut(on: bool) -> void:
	flag("night_music_off", on)
	if on: Sound.music_stop(0.12)
	else: Sound.music_level(NIGHT_BGM_LEVEL, 0.5)

const NIGHT_BGM_LEVEL := 0.35

# ---------------------------------------------------------------------------
# ACT 7 “엄마 왔다”(v3.2 §35~§41) — 한 장면으로 몰지 않는다. 첫 손 뒤 조작을 돌려준다(§39·§71).
#   범은 문이 열릴 때까지 화면 밖(발소리·목소리)·창호 그림자·문틈 앞발 일부로만 보인다. 전신은 reveal_tiger()에서 처음.
# ---------------------------------------------------------------------------
func night_door() -> void:
	await night_arrival()
	await first_knock()
	await between_knocks()
	await second_knock()
	await kids_escape()
	await reveal_tiger()
	await buy_time()
	await tree_scene()
	await axe_climb()
	await last_stand()
	flag("act10_started")
	await R([{ "event": "S0009" }, { "event": "S0010" }, { "event": "S0011" }])
	await finish()

# §35 배치 — 플레이어 hide_spot · 오누이 집 안 · 범 tiger_from(아직 보이지 않는다). 23:30
func night_arrival() -> void:
	flag("night_wait_started")
	d.cutscene(true)
	await d.ui.fade(true, 0.9)
	load_tiger_story()
	S.phase = "night"
	d.on_phase()
	d.set_hour(23.5)
	d.set_weather("clear")
	d.teleport_to("hide_spot", "left")
	kids_place()
	# 동아줄 빛은 암전 속에서 미리 짓는다(세기 0 — 처음 켤 때 셰이더를 짜느라 멈추지 않게)
	if not is_instance_valid(_sky_beam): _sky_light(d.anchor("rope_kids") + Vector2(0, 0.9), _ground("rope_kids"))
	if not is_instance_valid(_field_lamp): _field_light(d.anchor("sorghum"), _ground("sorghum"))
	_music_cut(false)
	await d.wait(0.5)
	await d.ui.fade(false, 1.0)

# CAMERA 7A — 고요: 문을 겨누고 숨은 플레이어 일부를 화면 한쪽에. 이 동안은 숨은 자리 둘레에서 움직일 수 있다(조작).
#   등잔불 · 바람 · 5~8초 정적 · 무거운 발소리 · 멈춤 · 노크 · 화면 밖 “얘들아.” … “엄마 왔다.” · 누이 “…엄마?”
# CAMERA 7B — 창호 그림자(사람 같지만 비정상적으로 큰) · 문 앞 대화 · 2초 정적
# §38 CAMERA 7C — 문틈 인서트: 털 난 앞발 일부만 · 누이 “…엄마 손 아니야.” · 그림자가 물러나고 발소리가 멀어진다
func cam_7a() -> Dictionary:
	var door: Vector2 = d.anchor("house_door")
	var fo := door.lerp(d.anchor("hide_spot"), 0.34)
	return { "focus": [fo.x, fo.y], "pitch": 34.0, "distance": 17.0, "fov": 36.0 }

func first_knock() -> void:
	var door: Vector2 = d.anchor("house_door")
	var hp: Vector2 = d.anchor("hide_spot")
	d.camera(cam_7a())
	d.main.rig.glide(0.01)
	d.cutscene(false)
	d.ui.letterbox(true)
	d.free_move = true
	_leash(hp, 3.2)
	d.hush(-1.0)   # 음악·환경음이 가라앉는다 — 바람만(SFX 버스)
	_snd("wind", "hide_spot", { "bus": "SFX", "db": -4.0 })
	await _shot("7a_still")
	await d.wait(6.0)   # 5~8초 정적
	# 무거운 발소리 — tiger_from에서 문 쪽으로(보이지 않는다)
	var tf: Vector2 = d.anchor("tiger_from")
	for k in 4:
		_snd("footstep_heavy", tf.lerp(door + Vector2(-1.5, 1.0), (k + 1) / 4.0), { "db": -8.0 + k * 1.5 })
		await d.wait(0.6)
	await d.wait(1.1)   # 발소리 멈춤
	_snd("knock", "house_door")
	_music_cut(true)
	flag("first_knock_seen")
	beat("tiger_disguise")   # 어머니 행세로 문 앞에 왔다(모습은 아직)
	await _voice("문밖", "얘들아.")
	await d.wait(1.0)
	await _voice("문밖", "엄마 왔다.")
	await _voice("누이", "…엄마?", 1.8)
	d.free_move = false
	_leash_off()
	# CAMERA 7B
	d.cutscene(true)
	if d.main.player.anim in ["walk", "run"]: d.main.player.set_anim("idle")
	_shadow_on(true)
	_room_view(true)
	await d.wait(0.5)
	await _shot("7b_shadow")
	await _say("누이", ["왜 이렇게 늦었어?"])
	await _say("문밖", ["고개에서 좀 늦었다.", "문 열어라."])
	await _say("누이", ["목소리가 왜 그래?"])
	await _say("문밖", ["바람을 오래 맞았더니 목이 쉬었구나."])
	await d.wait(2.0)
	# §38 첫 손
	await _say("아우", ["엄마, 손 보여 줘."])
	await _paw_insert("hairy_paw")
	flag("hairy_paw_seen")
	await _shot("7c_paw")
	await _say("누이", ["…엄마 손 아니야."])
	await d.wait(1.2)   # 침묵
	await _say("문밖", ["종일 일을 했더니 그렇지."])
	await _say("누이", ["아니야."])
	await d.wait(2.0)
	await _paw_insert_end("hairy_paw")
	# 그림자가 물러난다 · 발소리가 멀어진다
	_shadow_away()
	for k in 3:
		_snd("footstep_heavy", door + Vector2(-2.0 - k * 2.5, 1.5 + k), { "db": -6.0 - k * 4.0 })
		await d.wait(0.55)
	await d.wait(0.6)
	flag("tiger_withdrawn")

# 문틈 인서트(CAMERA 7C · 둘째 손): 플레이어를 감추고, 앞발 소품의 먹점 흐림·틸트 흐림을 끄고, 문지방 높이를 겨눈다
func _paw_insert(kind: String) -> void:
	d.world_state(kind, true)
	_tilt(false)
	var sill: Vector2 = d.anchor("door_sill")
	var gy: float = d.world.height_at(sill.x, sill.y)
	var look := Vector3(sill.x, gy + PAW_DY + 0.1, sill.y)
	d.main.rig.shot = { pos = look + Vector3(-0.3, 0.75, -2.1), look = look, fov = 50.0 }   # 7C — 낮은 시선, 문지방 앞발만
	await d.get_tree().process_frame
	d._update_props()
	var rec: Dictionary = d.props.get("p_" + kind, {})
	for i in 30:
		if rec.get("node") != null: break
		await d.get_tree().process_frame
	_no_occ(rec.get("node"))
	await d.wait(0.35)

func _paw_insert_end(kind: String) -> void:
	d.world_state(kind, false)
	_no_occ_clear()
	_room_view(true)

# 방 안(아이들 쪽)에서 닫힌 창호를 본다 — 아이들은 양옆에서 문을 향해 서 있다. 문밖의 것은 창호에 비친 그림자·문틈의 앞발로만
#   (밖에서 문을 보면 문 앞에 선 몸이 보여야 하므로, 7B·7C와 둘째 손은 아이들 쪽 시점으로 찍는다)
const PAW_DY := 0.58
var _glow_off: Array = []
func _room_view(on: bool) -> void:
	# 방 안 등잔의 발광 판(region_main.lamp_glows)이 카메라 바로 앞에서 문간을 하얗게 덮는다 — 이 시점 동안만 끈다
	for g in _glow_off:
		if is_instance_valid(g): g.visible = true
	_glow_off.clear()
	if on:
		var sl: Vector2 = d.anchor("door_sill")
		for g in d.main.get("lamp_glows") if d.main.get("lamp_glows") != null else []:
			if g.mesh.visible and Vector2(g.light.x, g.light.z).distance_to(sl) < 6.0:
				g.mesh.visible = false; _glow_off.append(g.mesh)
	if not on:
		d.main.rig.shot = null
		d.main.player.visible = true
		_tilt(true)
		return
	var sill: Vector2 = d.anchor("door_sill")
	var gy: float = d.world.height_at(sill.x, sill.y)
	var look := Vector3(sill.x, gy + PAW_DY + 0.95, sill.y)
	d.main.rig.shot = { pos = look + Vector3(-0.35, 0.35, -3.2), look = look, fov = 46.0 }
	d.main.player.visible = false
	_tilt(false)
	_door_occ(true)
	d.place_actor("nui", sill + Vector2(-0.95, -0.6), null, "up")
	d.place_actor("au", sill + Vector2(0.9, -0.75), null, "up")
	d.anim_actor("nui", "idle"); d.anim_actor("au", "idle")

# 문 앞 장면 동안: 숨은 플레이어와 카메라 사이의 집을 반투명으로 비우지 않는다(가림 기준을 문지방으로)
func _door_occ(on: bool) -> void:
	if not d.main.has_method("set_occ_script"): return
	if not on: d.main.set_occ_script(null); return
	var sill: Vector2 = d.anchor("door_sill")
	d.main.set_occ_script({ "focus": Vector3(sill.x, d.world.height_at(sill.x, sill.y) + 0.6, sill.y + 0.3), "r": 0.3, "near": 0.0 })   # 문 가까운 시점 — 카메라 앞 비우기도 끈다

# 쪽문 디딤돌 시점: 집을 점무늬로 비우지 않는다(범만 보면 된다)
func _step_occ(bs: Vector2, g: float) -> void:
	if d.main.has_method("set_occ_script"): d.main.set_occ_script({ "focus": Vector3(bs.x + 0.8, g + 0.7, bs.y + 0.6), "r": 0.3, "near": 0.0 })

# 창호(앞벽)에 비친 그림자 — 사람 같은 머리와 어깨지만 너무 크고 넓다. 그림자를 던지는 몸은 화면 밖에 있다
var _shadow: MeshInstance3D
const SHADOW_W := 0.82   # 창호지 한 짝(0.7 × 1.6)을 넘친다 — 머리가 문짝 위 끝을 넘는다(사람보다 크고 넓다)
const SHADOW_H := 1.9
func _shadow_on(on: bool) -> void:
	if not on:
		if is_instance_valid(_shadow): _shadow.queue_free()
		return
	if is_instance_valid(_shadow): return
	_shadow = MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(SHADOW_W, SHADOW_H)
	_shadow.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.015, 0.012, 0.02, 0.86)
	mat.albedo_texture = ImageTexture.create_from_image(_shadow_image())
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shadow.material_override = mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d._props_root.add_child(_shadow)
	# 열린 창호 한 짝(kit/village/choga.gd open: 경첩 x −0.7, 1.2rad 바깥으로)의 안쪽 면에 붙인다 — 방 안 등잔빛을 받은 창호지에 비친 그림자
	var h: Vector2 = d.anchor("house")
	var g: float = d.world.height_at(h.x, h.y)
	var dir := Vector2(cos(-1.2), -sin(-1.2))                  # 경첩에서 문짝 끝 쪽(x, z)
	var hinge := h + Vector2(-0.7, 2.0 + 0.06)                 # 집 앞면 zf = d/2 = 2
	var mid := hinge + dir * 0.35
	var n := Vector2(dir.y, -dir.x)                            # 방 안 쪽 법선
	_shadow.position = Vector3(mid.x + n.x * 0.035, g + 0.4 + 0.95, mid.y + n.y * 0.035)
	_shadow.rotation.y = atan2(n.x, n.y)
	_shadow_dir = Vector3(dir.x, 0, dir.y)

var _shadow_dir := Vector3.RIGHT

func _shadow_away() -> void:
	if not is_instance_valid(_shadow): return
	var tw: Tween = d.create_tween().set_parallel()
	tw.tween_property(_shadow, "position", _shadow.position + _shadow_dir * 0.5, _dur(1.6))
	tw.tween_property(_shadow.material_override, "albedo_color:a", 0.0, _dur(1.6))
	await tw.finished
	_shadow_on(false)

# 그림자 그림(알파만 — 위는 수건 두른 둥근 머리, 아래로 사람보다 훨씬 넓은 어깨와 등). 가장자리는 부드럽게
static func _shadow_image() -> Image:
	var W := 64; var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var u := (x + 0.5) / W - 0.5
			var v := 1.0 - (y + 0.5) / H
			var dist := minf(_sd_ellipse(Vector2(u, v - 0.83), Vector2(0.16, 0.085)),          # 머리
				minf(_sd_ellipse(Vector2(u - 0.14, v - 0.77), Vector2(0.09, 0.05)),              # 한쪽으로 처진 수건 끝
				minf(_sd_ellipse(Vector2(u * 0.92, v - 0.55), Vector2(0.46, 0.2)),                # 둥글고 넓은 어깨·등(사람보다 넓다)
					_sd_box(Vector2(u, v - 0.22), Vector2(0.36, 0.26)))))                         # 아래로 이어지는 몸
			var a := clampf(0.5 - dist * 60.0, 0.0, 1.0)
			a *= clampf(v * 3.0, 0.0, 1.0)   # 바닥 쪽으로 옅어진다
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img

static func _sd_ellipse(p: Vector2, r: Vector2) -> float:
	return (Vector2(p.x / r.x, p.y / r.y).length() - 1.0) * minf(r.x, r.y)

static func _sd_box(p: Vector2, b: Vector2) -> float:
	var q := Vector2(absf(p.x), absf(p.y)) - b
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)

# §39 첫 노크와 두 번째 노크 사이 — 컷신을 끝내고 15~30초 자유 이동(카메라는 평소대로 고정 시점).
#   방앗간 쪽으로 다가가면: 멀리 가루 자루 소리와 흐트러지는 가루, 무언가 어두운 것이 움직인다(가루를 바르는 장면은 보여 주지 않는다).
#   집 가까이 오면: 나그네 “문 열지 마.” 누이 “네.”
const BETWEEN_MIN := 15.0
const BETWEEN_MAX := 30.0
const MILL_NEAR := 33.0
func between_knocks() -> void:
	_room_view(false)
	kids_place()
	_door_occ(false)
	_shadow_on(false)
	d.camera(null)
	d.main.rig.glide(0.6)
	_tilt(true)
	d.cutscene(false)
	Sound.hush_end(1.5)
	_music_cut(false)
	d.free_move = true
	flag("between_knocks_on")
	var hp: Vector2 = d.anchor("hide_spot")
	var door: Vector2 = d.anchor("house_door")
	var mill: Vector2 = d.anchor("mill")
	await d.get_tree().process_frame
	between_free = not d.blocks_move()
	_shot_soon("between_free", 0.8)
	_nlog("control", "player", "between_knocks")
	var t := 0.0
	var left_home := false
	while true:
		await d.get_tree().process_frame
		if not (d.ui.journal_open or d.get_tree().paused): t += d.get_process_delta_time()
		var pp := _pp()
		if pp.distance_to(hp) > 4.5: left_home = true
		if not mill_shadow_seen and pp.distance_to(mill) < MILL_NEAR:
			mill_shadow_seen = true
			_mill_glimpse()
		if not door_warned and pp.distance_to(door) < 6.5:
			door_warned = true
			_door_warn()
		if t >= BETWEEN_MAX: break
		if t >= BETWEEN_MIN and (pp.distance_to(hp) < 4.0 or not left_home) and not d.ui.journal_open: break
	between_t = t
	d.free_move = false
	flag("between_knocks_on", false)
	if d.ui.journal_open: d.ui.journal_close()
	if _pp().distance_to(hp) > 9.0:   # 멀리 가 있으면 문소리에 숨은 자리로 돌아온다
		await d.ui.fade(true, 0.4)
		d.teleport_to("hide_spot", "left")
		await d.ui.fade(false, 0.4)

func _door_warn() -> void:
	await _voice("나그네", "문 열지 마.", 1.8)
	await _voice("누이", "네.", 1.4)

# 방앗간 쪽 — 가루 자루 소리, 흐트러지는 가루, 멀리 어두운 무언가가 방앗간 뒤로 사라진다(몸 모양은 읽히지 않는 흐린 덩어리)
func _mill_glimpse() -> void:
	# 방앗간 쪽으로 몇 걸음 앞(흰 발자국이 난 길목) — 고정 시점 화면 안에 들도록. 소리는 방앗간에서도
	var pp := _pp()
	var fl: Vector2 = d.anchor("flour")
	var ahead: Vector2 = pp + (fl - pp).normalized() * 4.5   # 방앗간은 화면 아래(카메라 쪽) — 멀리 두면 화면 밖
	_snd("flour_rustle", "flour", { "db": -1.0 })
	_snd("flour_rustle", ahead, { "db": -6.0 })
	_flour_puff(ahead, 1.4)
	_snd("footstep_heavy", ahead, { "db": -10.0 })
	var side := Vector2(-(fl - pp).normalized().y, (fl - pp).normalized().x)
	var a := ahead - side * 2.5
	var b := ahead + side * 3.0 + (fl - pp).normalized() * 4.0
	var blob := _blob(a)
	var tw: Tween = d.create_tween()
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(blob): return
		var q := a.lerp(b, k)
		blob.position = Vector3(q.x, d.world.height_at(q.x, q.y) + 0.55, q.y)
		(blob.material_override as StandardMaterial3D).albedo_color.a = 0.85 * sin(PI * k), 0.0, 1.0, _dur(2.4))
	_shot_soon("between_mill", 1.0)
	await tw.finished
	if is_instance_valid(blob): blob.queue_free()

func _blob(at: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(3.0, 1.5)
	mi.mesh = qm
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 32:
			var p := Vector2((x + 0.5) / 32.0 - 0.5, (y + 0.5) / 16.0 - 0.5)
			var a := clampf(1.0 - Vector2(p.x / 0.5, p.y / 0.5).length(), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.0, 0.0, 0.005, 0.0)
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d._props_root.add_child(mi)
	mi.position = Vector3(at.x, d.world.height_at(at.x, at.y) + 0.55, at.y)
	return mi

# 흩날리는 가루(흰 덩어리 몇 개가 부풀며 옅어진다)
func _flour_puff(at: Vector2, size := 1.0) -> void:
	var g: float = d.world.height_at(at.x, at.y)
	var bits: Array = []
	var rng := RandomNumberGenerator.new(); rng.seed = 41
	for i in 10:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = rng.randf_range(0.05, 0.11) * size; sm.height = sm.radius * 1.6; sm.radial_segments = 8; sm.rings = 4
		mi.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.93, 0.91, 0.86, 0.4)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d._props_root.add_child(mi)
		var ang := i * TAU / 10.0 + rng.randf() * 0.5
		mi.position = Vector3(at.x + cos(ang) * 0.25 * size, g + 0.25 * size, at.y + sin(ang) * 0.25 * size)
		bits.append([mi, ang])
	await _animate(1.8, func(k: float) -> void:
		for b in bits:
			var mi: MeshInstance3D = b[0]
			if not is_instance_valid(mi): continue
			mi.scale = Vector3.ONE * (1.0 + 2.2 * k)
			mi.position.y = g + (0.25 + 0.9 * k) * size
			mi.position.x = at.x + cos(b[1]) * (0.25 + 0.9 * k) * size
			mi.position.z = at.y + sin(b[1]) * (0.25 + 0.9 * k) * size
			(mi.material_override as StandardMaterial3D).albedo_color.a = 0.4 * (1.0 - k))
	for b in bits:
		if is_instance_valid(b[0]): b[0].queue_free()

# §40 두 번째 방문 — 노크 · “얘들아.” “엄마다.” · 하얀 손(가루가 떨어진다) · 누이는 곧바로 열지 않는다 · 작게 “뒷문으로 가.”
func second_knock() -> void:
	var door: Vector2 = d.anchor("house_door")
	d.cutscene(true)
	if d.main.player.anim in ["walk", "run"]: d.main.player.set_anim("idle")
	d.face_actor("player", null, "house_door")
	_music_cut(true)
	_door_occ(true)
	d.camera(cam_7a())
	d.main.rig.glide(0.4)
	_snd("knock", "house_door")
	await d.wait(0.6)
	await _say("문밖", ["얘들아.", "엄마다."])
	_room_view(true)
	await _say("아우", ["손 보여 줘."])
	await _paw_insert("white_paw")
	_flour_puff(d.anchor("door_sill") + Vector2(0, 0.25), 0.4)   # 밀가루가 조금 떨어진다
	flag("white_paw_seen")
	await _shot("white_paw")
	await _say("아우", ["봐, 엄마 손이잖아."])
	await d.wait(1.4)   # 누이는 곧바로 열지 않는다 — 가루를 본다
	await _say("누이", ["…엄마."])
	await _say("문밖", ["왜 그러니."])
	await _say("누이", ["잠깐만 기다려."])
	await _paw_insert_end("white_paw")
	await d.wait(0.5)
	# 누이가 아우를 본다. 작게 — 탈출은 누이가 정한다
	await _say("누이", ["(작게) 뒷문으로 가."])
	d.learn_clue("door_tricks", true)
	beat("door_tricks")

# §41 오누이 탈출 — 누이 “엄마, 우리 뒷간 좀 다녀올게.” → kid_in → back_step → kids_run_1 → kids_run_2
func kids_escape() -> void:
	await _say("누이", ["엄마, 우리 뒷간 좀 다녀올게."])
	await _say("문밖", ["어서 다녀오너라."])
	flag("kids_escape_started")
	_nlog("flag", "", "kids_escape_started")
	_room_view(false)
	_door_occ(false)
	var bs: Vector2 = d.anchor("back_step")
	d.camera({ "focus": [bs.x + 1.6, bs.y + 4.6], "pitch": 36.0, "distance": 15.0, "fov": 38.0 })
	d.main.rig.glide(0.5)
	d.place_actor("nui", "back_step", null, "right")
	d.place_actor("au", bs + Vector2(-0.5, 0.2), null, "right")
	d.move_actor("au", ["kids_run_1", "kids_run_2"], 2.6, "walk", "idle")
	await d.wait(0.1)
	var an = d.actors.nui
	d.runner.log_line("kids_escape", [an.shown, an.ch.visible, an.spec.get("_hidden", false), snappedf(an.pos.x, 0.1), snappedf(an.pos.z, 0.1)])
	_shot_soon("escape", 1.2)
	await d.move_actor("nui", ["kids_run_1", "kids_run_2"], 2.4, "walk", "idle")

# 앞문이 조금 열리고 범이 밀고 들어온다 — 이때 처음 전신(어머니 저고리와 수건을 걸친 범). 빈 방 → 열린 쪽문 → 저고리를 뜯어 던지고 돌진
func reveal_tiger() -> void:
	var door: Vector2 = d.anchor("house_door")
	var bs: Vector2 = d.anchor("back_step")
	d.camera({ "focus": [door.x, door.y + 0.4], "pitch": 28.0, "distance": 10.5, "fov": 38.0 })
	d.main.rig.glide(0.35)
	flag("tiger_revealed")   # 문이 열린다 — 여기서부터 전신이 보여도 된다
	_nlog("reveal", "tiger", "")
	# 등을 보이고 문 앞에 선 범 — 어머니 저고리가 등에, 수건이 머리에(앞에서 보면 얼굴이 먼저 읽혀 저고리가 묻힌다)
	d.spawn_actor("tiger_night", "tiger", [door.x - 0.4, door.y + 2.4], "up", "", "disguised")
	d.anim_actor("tiger_night", "idle")
	await d.wait(0.6)
	d.learn_clue("disguise_seen", true)
	await _shot("reveal")
	await d.ui.caption("어머니의 저고리와 수건을 걸친 범.", 2.4)
	await d.move_actor("tiger_night", [[door.x, door.y + 0.4]], 1.4, "walk", "knock")   # 문을 밀고 들어간다
	await d.wait(0.5)
	d.show_actor("tiger_night", false)   # 집 안으로
	await d.ui.caption("빈 방.", 1.4)
	# 열린 쪽문으로
	var g1: float = d.world.height_at(bs.x, bs.y)
	_tilt(false)
	d.main.rig.shot = { pos = Vector3(bs.x + 8.5, g1 + 3.4, bs.y + 5.5), look = Vector3(bs.x + 0.8, g1 + 0.7, bs.y + 0.6), fov = 38.0 }
	_step_occ(bs, g1)
	d.place_actor("tiger_night", bs + Vector2(0.3, 0.1), null, "right")   # 열린 쪽문 앞 디딤돌 곁
	d.show_actor("tiger_night", true)
	d.anim_actor("tiger_night", "sniff")
	await d.wait(0.6)
	_throw_jeogori(bs)
	d.actors.tiger_night.ch.variant = ""   # 저고리를 뜯어 던진다
	_snd("tiger_growl", bs, { "db": 1.0 })
	await d.wait(0.5)
	await _shot("tear")
	d.main.rig.shot = null
	_tilt(true)
	_door_occ(false)
	# 아이들은 kids_run_2 → tree_foot(따로 돈다)
	d.move_actor("nui", ["tree_foot"], 3.2, "walk", "climb")
	d.move_actor("au", ["tree_foot"], 3.0, "walk", "climb")
	# CUTSCENE 끝 — 조작은 곧바로(시간 벌기에서)

func _throw_jeogori(at: Vector2) -> void:
	var info: Dictionary = load("res://kit/story/clue.gd").build({ "kind": "jeogori", "seed": 41 })
	var n: Node3D = info.node
	d._props_root.add_child(n)
	_tale_nodes.append(n)
	var p0 := Vector3(at.x, d.world.height_at(at.x, at.y) + 1.2, at.y)
	var land := at + Vector2(-1.8, 1.6)
	var p1 := Vector3(land.x, d.world.height_at(land.x, land.y) + 0.03, land.y)
	var tw: Tween = d.create_tween()
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(n):
			n.position = p0.lerp(p1, u) + Vector3(0, sin(PI * u) * 0.9, 0)
			n.rotation.y = 2.2 * u, 0.0, 1.0, _dur(0.7))

# ---------------------------------------------------------------------------
# ACT 8 시간을 벌어라(v3.2 §42~§44) — 목표 한 줄. 준비에 따라: B 디딤돌에서 미끄러진 범과 짧은 싸움 · C 떡 냄새로 방향을 돌리고 횃불로 길을 막음 ·
#   A 약 25초 버티기. 범은 죽지 않는다(undying). 어느 갈래든 끝에 범이 플레이어를 3~4m 밀쳐내고(쓰러뜨리지 않는다) 아이들 쪽을 본다(§45).
#   크게 밀리면(hunter_watch) 먼 데서 포수의 화살이 한 번 날아온다(결정 4 fail-forward).
# ---------------------------------------------------------------------------
const TIME_LINE := "아이들이 나무까지 갈 시간을 벌어야 한다."
const FIGHT_A := 25.0
const FIGHT_B := 15.0
const LAST_STAND := 17.0
const LOW_HP := 0.3
const SHOVE_DIST := 3.6
var branch_now := ""     # 시험 기록
var fight_lens := {}     # 시험 기록: { "A": 초 … }
var torch_blocked := false

func buy_time() -> void:
	flag("time_line")
	d.ui.toast("기록 — " + TIME_LINE, "journal")
	var branch := "B" if S.world.get("oil_on_step", false) else ("C" if c_ready() else "A")
	branch_now = branch
	_nlog("branch", "", branch)
	var res := ""
	match branch:
		"B":
			res = await _slip_then_fight()
		"C":
			res = await _torch_block()
		_:
			d.cutscene(false)
			kids_up()
			res = await _time_fight({}, FIGHT_A, "A")
	await _shove(branch)
	await _record_branch(branch, res)

# §42 B — 쫓아 나오던 범이 디딤돌을 밟고 미끄러진다(짧은 카메라) → 12~18초 싸움
func _slip_then_fight() -> String:
	var bs: Vector2 = d.anchor("back_step")
	# 집 옆 디딤돌 — 동쪽 낮은 자리에서 본다(앞·위에서 보면 집 모서리와 지붕에 가린다)
	var g0: float = d.world.height_at(bs.x, bs.y)
	_tilt(false)
	d.main.rig.shot = { pos = Vector3(bs.x + 8.5, g0 + 3.4, bs.y + 5.5), look = Vector3(bs.x + 0.8, g0 + 0.7, bs.y + 0.6), fov = 38.0 }
	_step_occ(bs, g0)
	await d.move_actor("tiger_night", [bs + Vector2(1.0, 0.7)], 3.0, "walk", "slip")   # 디딤돌을 딛고 내려서다
	d.anim_actor("tiger_night", "slip")
	_snd("fall_impact", bs, { "db": -8.0 })
	if d.shake_enabled(): d.shake(0.3, 0.35)
	await d.wait(0.55)   # 나뒹군 모습에서 한 장
	await _shot("b_slip")
	await d.ui.caption("디딤돌을 딛는 순간, 범의 발이 주르륵 미끄러진다.", 1.8)
	d.main.rig.shot = null
	_tilt(true)
	_door_occ(false)
	kids_up()
	d.cutscene(false)
	return await _time_fight({ "stunned": 2.5, "hpRatio": 0.85 }, FIGHT_B, "B")

# §43 C — 떡 냄새에 범이 방향을 돌린다 → (조작) 횃불을 들고 범과 나무 사이를 막는다 → 범이 잠시 물러나고 아이들이 나무에 닿는다 → 범은 곧 돌아온다
func _torch_block() -> String:
	var bait: Vector2 = d.anchor("cake_bait")
	d.anim_actor("tiger_night", "sniff")
	d.face_actor("tiger_night", null, "cake_bait")
	await d.ui.caption("떡 냄새가 바람을 타고 온다. 범의 코가 오솔길 어귀 쪽으로 돌아간다.", 2.2)
	kids_up()
	d.move_actor("tiger_night", [bait + Vector2(1.0, 0.6)], 2.6, "walk", "eat")
	# 조작 — 횃불을 들고 길을 막는다
	var torch := _torch_follow()
	d.camera(null)
	d.cutscene(false)
	d.free_move = true
	flag("torch_block_on")
	d.ui.toast("횃불을 들고 범과 나무 사이를 막아선다.", "info")
	var blk: Vector2 = d.anchor("torch_block")
	var t := 0.0
	while t < 14.0 and _pp().distance_to(blk) > 2.6:
		await d.get_tree().process_frame
		t += d.get_process_delta_time()
	torch_blocked = _pp().distance_to(blk) <= 2.6
	fight_lens["C"] = t
	d.free_move = false
	flag("torch_block_on", false)
	d.cutscene(true)
	if d.main.player.anim in ["walk", "run"]: d.main.player.set_anim("idle")
	d.world_state("cake_bait", false)
	d.face_actor("tiger_night", null, "player")
	d.anim_actor("tiger_night", "idle")
	var mid: Vector2 = _pp().lerp(d.anchor("tiger_night"), 0.4)
	_tilt(false)
	d.camera({ "focus": [mid.x, mid.y], "pitch": 42.0, "distance": 18.0, "fov": 36.0 })
	d.main.rig.glide(0.4)
	await d.wait(0.45)
	await _shot("c_torch")
	await d.ui.caption("범이 불빛 앞에서 귀를 젖히고 한 걸음, 또 한 걸음 물러난다.", 2.2)
	var tp: Vector2 = d.anchor("tiger_night")
	await d.move_actor("tiger_night", [tp + Vector2(-4.0, -1.5)], 2.2, "retreat", "idle")
	await d.wait(0.8)
	await d.ui.caption("…오래가지 않았다.", 1.6)
	_snd("tiger_growl", "tiger_night", { "db": 2.0 })
	var pp := _pp()
	var near: Vector2 = pp + (d.anchor("tiger_night") - pp).normalized() * 1.8
	await d.move_actor("tiger_night", [near], 6.0, "walk", "idle")
	torch.set_meta("drop", true)
	_tilt(true)
	return "lured"

# 횃불(불빛)이 플레이어 손 곁을 따라다닌다 — 밀려나면 떨어진다
func _torch_follow() -> Node3D:
	var n := Node3D.new()
	var stick := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.025; cm.bottom_radius = 0.03; cm.height = 0.7
	stick.mesh = cm
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.25, 0.17, 0.1)
	stick.material_override = sm
	n.add_child(stick)
	var fire := MeshInstance3D.new()
	var fm := SphereMesh.new(); fm.radius = 0.11; fm.height = 0.3; fm.radial_segments = 8; fm.rings = 4
	fire.mesh = fm
	var mm := StandardMaterial3D.new(); mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mm.albedo_color = Color(1.0, 0.62, 0.22)
	fire.material_override = mm
	fire.position.y = 0.42
	n.add_child(fire)
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.6, 0.28); l.light_energy = 2.4; l.omni_range = 6.0; l.shadow_enabled = false
	l.position.y = 0.5
	n.add_child(l)
	d._props_root.add_child(n)
	_tale_nodes.append(n)
	_torch_loop(n)
	return n

func _torch_loop(n: Node3D) -> void:
	while is_instance_valid(n) and not n.has_meta("drop"):
		var p: Vector3 = d.main.player_pos
		n.position = p + Vector3(0.38, 1.0, 0.12)   # 손 높이
		await d.get_tree().process_frame
	if not is_instance_valid(n): return
	var p0 := n.position
	await _animate(0.5, func(k: float) -> void:
		if is_instance_valid(n): n.position = p0 + Vector3(0.6 * k, -2.0 * k * k, 0.0))
	if is_instance_valid(n): n.queue_free()

# 시간을 버는 싸움(마당) — 범은 쓰러지지 않는다. secs초를 버티거나 크게 다치게 하면 물러난다. 크게 밀리면 포수의 화살(한 번)
func _time_fight(mods: Dictionary, secs: float, tag: String) -> String:
	var m := mods.duplicate()
	m.undying = true
	var ar: Dictionary = d.data.arenas.house_yard
	var tn = d.actors.get("tiger_night")
	if tn != null and tn.shown: ar["tiger_start"] = [tn.pos.x, tn.pos.z]
	d.despawn_actor("tiger_night")
	d.world_state("white_paw", false)
	d.camera(null)
	_arrow_watch()
	var res: String = await d.combat("house_yard", { "mods": m, "allow_flee": false, "store": "yard", "retreat_at": { "seconds": secs, "hpRatio": 0.4 } })
	var b = d.combat_view.battle
	fight_lens[tag] = float(b.time)
	_last_tiger = b.tiger.pos
	d.end_combat()
	d.runner.log_line("fight", [tag, res, snappedf(float(b.time), 0.1)])
	if res == "lose" and f("hunter_watch") and not f("hunter_arrow"):   # 화살보다 먼저 쓰러졌으면 — 쓰러진 뒤 화살
		flag("hunter_arrow")
		_nlog("arrow", "포수", "after_lose")
		await d.ui.say("포수", ["이놈아, 이쪽이다!"])
		await d.ui.caption("어둠 속에서 날아온 화살에 범이 몸을 돌린다.", 2.0)
	return res

var _last_tiger := Vector2.INF
# 싸움 곁에서: 크게 밀리면 포수의 화살(한 번) · 범이 물러나기 시작하면 걸어 나가기를 기다리지 않고 곧 판을 닫는다(끝은 밀쳐냄 §45)
func _arrow_watch() -> void:
	await d.get_tree().process_frame
	var hp_max := float(load("res://scripts/combat/ctuning.gd").T.player.hp)
	var ret_t := -1.0
	while d.combat_view != null and d.combat_view.active:
		var b = d.combat_view.battle
		if not f("hunter_arrow") and f("hunter_watch") and b.player.alive and b.player.hp <= hp_max * LOW_HP and b.tiger.alive and not b.tiger.retreating:
			_hunter_arrow(b, hp_max)
		if b.tiger.retreating:
			if ret_t < 0.0: ret_t = float(b.time)
			elif float(b.time) - ret_t >= 1.4: b.finish("retreated", 0.0)
		await d.get_tree().process_frame

var arrow_info := {}   # 시험 기록
func _hunter_arrow(b, hp_max: float) -> void:
	flag("hunter_arrow")
	var tg = b.tiger
	var from: Vector2 = tg.pos + Vector2(8.5, 6.5)   # 먼 데(마당 밖, 고개 쪽 어둠)
	var dir: Vector2 = (tg.pos - from).normalized()
	b.spawn_arrow(from, dir, 6.0, true)
	tg.go("stagger"); tg.stun_for = 1.4; tg.set_anim("stagger", true, 1.4)
	b.player.hp = maxf(b.player.hp, hp_max * 0.3)
	b.retreat_at = { "seconds": b.time + 1.8 }   # 흐름을 잇는다 — 곧 물러난다
	arrow_info = { "t": float(b.time), "player_hp": float(b.player.hp) }
	_nlog("arrow", "포수", "fight")
	d.runner.log_line("hunter_arrow", snappedf(float(b.time), 0.1))
	b.env.say("어둠 속에서 화살 하나가 날아와 범의 어깨에 박힌다.", 2400)
	d.ui.caption("포수  “이놈아, 이쪽이다!”", 1.8)

# §45 범이 플레이어를 크게 밀쳐낸다 — 쓰러지지만 죽거나 오래 기절하지 않는다. 범은 아이들을 찾는다(나무 쪽을 본다)
func _shove(tag: String) -> void:
	d.cutscene(true)
	var pp := _pp()
	var tree: Vector2 = d.anchor("big_tree")
	var tpos: Vector2 = _last_tiger
	var tn = d.actors.get("tiger_night")
	if tn != null and tn.shown: tpos = Vector2(tn.pos.x, tn.pos.z)
	if tpos == Vector2.INF or tpos.distance_to(pp) < 0.3: tpos = pp + (tree - pp).normalized() * 2.0
	var dir := (pp - tpos).normalized()
	var start := pp - dir * 1.7
	d.spawn_actor("tiger_night", "tiger", [start.x, start.y], _face_of(dir), "", "")
	d.anim_actor("tiger_night", "swipe")
	_snd("tiger_growl", start, { "db": 2.0 })
	await d.wait(0.25)
	# 3~4m 뒤로 밀려난다 — 곧장 뒤가 막혔으면(집·나무) 조금 비껴 가장 멀리 밀리는 쪽으로
	var to := pp
	for ang in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]:
		var dv := dir.rotated(ang)
		var q0 := pp
		var l := 0.0
		while l + 0.2 <= SHOVE_DIST:
			var q := pp + dv * (l + 0.2)
			if d.world.blocked(q.x, q.y, 0.375): break
			l += 0.2; q0 = q
		if q0.distance_to(pp) > to.distance_to(pp) + 0.05: to = q0
		if to.distance_to(pp) >= SHOVE_DIST - 0.25: break
	d.anim_actor("player", "hit")
	if d.shake_enabled(): d.shake(0.25, 0.3)
	var p0 := pp
	await _animate(0.38, func(k: float) -> void:
		var q := p0.lerp(to, 1.0 - (1.0 - k) * (1.0 - k))
		d.set_player_pos(Vector3(q.x, d.world.height_at(q.x, q.y), q.y)))
	d.anim_actor("player", "down")
	shoves.append([tag, snappedf(p0.distance_to(to), 0.01)])
	d.runner.log_line("shove", [tag, snappedf(p0.distance_to(to), 0.01)])
	flag("tiger_shoved")
	await _shot("shove")
	# 범은 아이들을 찾는다
	d.face_actor("tiger_night", null, "big_tree")
	d.anim_actor("tiger_night", "sniff")
	await d.wait(0.8)
	d.anim_actor("player", "getup")
	await d.wait(0.5)
	d.anim_actor("player", "idle")

static func _face_of(v: Vector2) -> String:
	return "right" if absf(v.x) > absf(v.y) * 1.05 and v.x > 0 else ("left" if absf(v.x) > absf(v.y) * 1.05 else ("down" if v.y > 0 else "up"))

# 갈래 기록(결과는 S0009 끝에 CASE_NAMWON_OUTCOME으로)
func _record_branch(branch: String, res: String) -> void:
	var detail := "C" if branch == "C" else "%s_%s" % [branch, "down" if res == "lose" else "hold"]
	flag("pending_outcome", branch)
	flag("pending_detail", detail)
	S.seen["S0008"] = true
	d.runner.log_line("outcome", detail)
	if not f("kids_in_tree"): await kids_up()

# ---------------------------------------------------------------------------
# ACT 9 나무와 우물(v3.2 §46~§50)
# ---------------------------------------------------------------------------
# §46 우물 — 우물 표면에 오누이 얼굴 · 범 “거기 숨어 있었구나.” · 아우 “킥.” · 범이 위를 본다
# §47 참기름 거짓말 — 범 “어떻게 거기까지 올라갔느냐?” 누이 “참기름을 바르고 올라왔지.” → 기름을 바르고 오르다 미끄러짐, 한 번 더
# §48 아우의 실수 — “바보.” “쉿.” “도끼로 찍고 올라오면 되는데.” “아우야!” → 범이 헛간 쪽을 본다
func tree_scene() -> void:
	d.cutscene(true)
	if d.ui._fade.color.a > 0.01: await d.ui.fade(false, 0.3)
	kids_place()
	var well: Vector2 = d.anchor("well")
	var tree: Vector2 = d.anchor("big_tree")
	var mid := well.lerp(tree, 0.5)
	d.camera({ "focus": [mid.x, mid.y + 0.6], "pitch": 30.0, "distance": 13.0, "fov": 40.0 })
	d.main.rig.glide(0.5)
	await d.move_actor("tiger_night", ["tiger_well"], 2.4, "walk", "sniff")
	d.face_actor("tiger_night", null, "well")
	# 우물을 내려다보는 짧은 시점
	_tilt(false)
	var twp: Vector2 = d.anchor("tiger_well")
	var wl := well.lerp(twp, 0.4)
	d.camera({ "focus": [wl.x, wl.y], "pitch": 40.0, "distance": 9.5, "fov": 40.0 })
	d.main.rig.glide(0.35)
	await d.wait(0.4)
	await d.ui.caption("우물 물 위에 오누이 얼굴이 비친다.", 2.0)
	await _shot("well")
	await _say("범", ["거기 숨어 있었구나."])
	await _say("아우", ["킥."])
	d.face_actor("tiger_night", null, "big_tree")
	d.anim_actor("tiger_night", "idle")
	d.camera({ "focus": [mid.x, mid.y + 0.6], "pitch": 26.0, "distance": 13.0, "fov": 42.0 })
	d.main.rig.glide(0.4)
	_tilt(true)
	d.learn_clue("reflection", true)
	beat("well_reflection")
	await d.move_actor("tiger_night", ["tiger_tree"], 2.0, "walk", "idle")
	d.face_actor("tiger_night", "up", null)
	await _say("범", ["어떻게 거기까지 올라갔느냐?"])
	await _say("누이", ["참기름을 바르고 올라왔지."])
	# 부엌에서 기름 단지를 들고 와 줄기에 바른다
	await d.move_actor("tiger_night", [d.anchor("house_door") + Vector2(1.0, 1.2)], 5.0, "walk", "idle")
	await d.move_actor("tiger_night", ["tiger_tree"], 5.0, "walk", "idle")
	d.face_actor("tiger_night", "up", null)
	d.world_state("oil_on_tree", true)
	for k in 2:   # 오르다 미끄러짐 — 한 번 더
		d.anim_actor("tiger_night", "climb_try")
		d.place_actor("tiger_night", "tiger_tree", 0.7, "up")
		await d.wait(0.8)
		d.anim_actor("tiger_night", "slip")
		d.place_actor("tiger_night", "tiger_tree", 0.0, "up")
		_snd("footstep_heavy", "tiger_tree", { "db": -4.0 })
		if k == 0: await _shot("oil_slip")
		await d.wait(0.7)
	await d.ui.caption("또 미끄러진다.", 1.4)
	d.learn_clue("kids_lie", true)
	await _say("아우", ["바보."])
	await _say("누이", ["쉿."])
	await _say("아우", ["도끼로 찍고 올라오면 되는데."])
	await _say("누이", ["아우야!"])
	d.learn_clue("axe_slip", true)
	beat("kids_lies")
	d.face_actor("tiger_night", null, "barn")   # 범이 헛간 쪽을 본다
	d.anim_actor("tiger_night", "idle")
	await d.wait(0.8)

# §49 도끼 — 쿵, 쿵. 한 칸씩 올라오는 범. 흔들림은 아주 약하게(설정 cam_shake가 꺼져 있으면 흔들지 않는다)
var axe_hits := 0   # 시험 기록
func axe_climb() -> void:
	await d.move_actor("tiger_night", ["barn_front"], 6.0, "walk", "idle")
	await d.wait(0.4)
	await d.move_actor("tiger_night", ["tiger_tree"], 6.0, "walk", "idle")
	d.face_actor("tiger_night", "up", null)
	d.anim_actor("tiger_night", "climb_try")
	for k in 3:
		_snd("axe_hit", "tiger_tree")
		axe_hits += 1
		if d.shake_enabled(): d.shake(0.05, 0.12)
		d.place_actor("tiger_night", "tiger_tree", 0.5 * (k + 1), "up")
		if k == 1: await _shot("axe_climb")
		await d.ui.caption("쿵.", 0.8)
		await d.wait(0.4)

# §50 플레이어 마지막 개입 — 다시 조작. 활·환도·떡·몸으로 막아 약 15~20초 더 번다. 범은 죽지 않는다.
#   범이 줄기에서 뛰어내려 이쪽을 치고, 시간이 지나면 다시 나무로 돌아가 오른다 → ACT 10 기도(기존 동아줄 장면)로
func last_stand() -> void:
	await d.ui.caption("범이 줄기에서 뛰어내려 이쪽을 노려본다.", 1.6)
	d.cutscene(false)
	var res := await _time_fight({}, LAST_STAND, "last")
	d.runner.log_line("last_stand", res)
	d.cutscene(true)
	var tp: Vector2 = _last_tiger if _last_tiger != Vector2.INF else d.anchor("tiger_tree")
	d.spawn_actor("tiger_night", "tiger", [tp.x, tp.y], "up", "", "")
	await d.move_actor("tiger_night", ["tiger_tree"], 5.0, "walk", "climb_try")
	d.place_actor("tiger_night", "tiger_tree", 1.4, "up")
	d.anim_actor("tiger_night", "climb_try")
	_snd("axe_hit", "tiger_tree")
	flag("last_stand_done")

func commit_outcome() -> void:
	if String(S.vars.get("CASE_NAMWON_OUTCOME", "")) != "": return
	S.vars["CASE_NAMWON_OUTCOME"] = String(S.flags.get("pending_outcome", "A"))
	S.vars["CASE_NAMWON_DETAIL"] = String(S.flags.get("pending_detail", "A_hold"))
	d.runner.log_line("commit", S.vars["CASE_NAMWON_OUTCOME"])
	d.mark_dirty()

# ---------------------------------------------------------------------------
# S0009 ACT 10~ — 동아줄을 비는 것(오누이) · 새 줄 · 썩은 줄 · 수수밭 · 두 빛(기존 장면 그대로 — 착수 순서 6에서 다시 짠다).
#   우물·참기름·도끼·마지막 개입(ACT 9)은 night_door가 먼저 한다
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
	await d.ui.fade(true, 0.4)
	d.teleport_to("sky_watch", "right")
	kids_place()
	if not d.actors.has("tiger_night"): d.spawn_actor("tiger_night", "tiger", "tiger_tree", "up", "", "")
	d.place_actor("tiger_night", "tiger_tree", 1.4, "up")
	d.anim_actor("tiger_night", "climb_try")
	if not is_instance_valid(_sky_beam): _sky_light(d.anchor("rope_kids") + Vector2(0, 0.9), _ground("rope_kids"))   # (옛 길·시험) 미리 짓지 못했으면
	if not is_instance_valid(_field_lamp): _field_light(d.anchor("sorghum"), _ground("sorghum"))
	d.camera({ "focus": [-3205.0, -344.6], "pitch": 24.0, "distance": 18.0 })
	await d.wait(0.3)
	await d.ui.fade(false, 0.5)
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
	_sharp(false)
	_no_occ_clear()
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

# 새 동아줄 — 오누이가 붙잡자마자 각본 시점: 나무 밑동 → 줄을 붙잡은 아이들 → 아이들 곁에서 함께 올라(화면 높이의 1/4 넘게)
# → 수관 위에서 카메라는 멈추고 아이들만 빛기둥 속으로 작아지며 올라간다 → 범에게로 내려온다
func rope_rise(rope: Node3D) -> void:
	await d.ui.caption("누이가 아우를 앞세워 줄을 붙잡는다.", 1.8)
	_sharp(true)   # 줄을 붙잡는 순간부터 붉은 수수밭까지 흐림(틸트시프트)을 끈다
	var rk: Vector2 = d.anchor("rope_kids") + Vector2(0, 0.9)   # 줄을 줄기 앞(카메라 쪽)으로 조금 — 붙잡는 순간 시점이 바뀌어 티 나지 않는다
	var g := _ground("rope_kids")
	rope.position.z = rk.y
	_no_occ(rope)
	var an = d.actors.get("nui"); var aa = d.actors.get("au")
	# rope_up(손을 번갈아 끌어올림, 구운 그림은 발이 y_abs) — 줄을 몸 가운데·몸 뒤(카메라 반대쪽)로 두고 아우가 위, 누이가 아래
	var climb_frames: bool = an.ch.has_anim("rope_up") and aa.ch.has_anim("rope_up")
	var kid_c := 1.45   # 바라볼 점: 누이 발(y_abs)에서 두 아이 가운데까지
	if climb_frames:
		d.place_actor("nui", rk + Vector2(0, 0.5), 3.9, "up"); d.place_actor("au", rk + Vector2(0, 0.45), 5.35, "up")   # 줄보다 0.5m 앞 — 뒤로 젖힌 그림 위쪽이 줄 뒤로 들어가지 않게
		d.anim_actor("nui", "rope_up"); d.anim_actor("au", "rope_up")
		aa.ch.anim_time = 0.45   # 두 아이 손이 엇갈리게(반 주기 어긋남)
	else:   # 그림이 없으면 예전처럼 climb 끝 자세(그림이 y_abs보다 1.3~2.8m 위)
		d.place_actor("nui", rk + Vector2(-0.15, 0), 3.0, "up"); d.place_actor("au", rk + Vector2(0.2, 0), 3.9, "up")
		d.anim_actor("nui", "climb"); d.anim_actor("au", "climb")
		kid_c = 2.1
	d.place_actor("tiger_night", "tiger_tree", 0.0, "up")   # 범은 밑동에서 올려다본다(카메라가 들리면 화면 밖으로)
	d.anim_actor("tiger_night", "idle")
	var yn: float = an.y_abs; var ya: float = aa.y_abs; var yr: float = rope.position.y
	# 나무 밑동에서 시작(남쪽 낮은 자리, 조금 비켜서)
	var cam0 := Vector3(rk.x + 0.8, g + 1.4, rk.y + 6.2)
	_cam_cut(cam0, Vector3(rk.x, g + 0.8, rk.y), 40.0)
	_occ(Vector3(rk.x, yn + kid_c, rk.y), 2.6)
	if not is_instance_valid(_sky_beam): _sky_light(rk, g)
	d.sfx("rope_creak")
	# 밑동에서 줄을 붙잡은 아이들까지 고개를 들며 다가선다(아이 둘이 화면 높이의 절반쯤)
	var near := func(lift: float) -> Vector3: return Vector3(rk.x + 0.8, yn + lift + kid_c - 1.6, rk.y + 6.6)
	await _cam_move(1.8, near.call(0.0), Vector3(rk.x, yn + kid_c - 0.1, rk.y), 38.0, func(k: float) -> void: _sky_light_k(0.35 * k))
	await _shot("rope_grab")
	var rise := func(lift: float) -> void:
		an.y_abs = yn + lift; aa.y_abs = ya + lift
		rope.position.y = yr + lift
		_occ(Vector3(rk.x, yn + lift + kid_c, rk.y), 2.6)
		if is_instance_valid(_sky_spot): _sky_spot.position.y = yn + lift + 3.2
	# 오른다 — 카메라가 아이들 곁에서 같이 올라간다(아이 크기 그대로, 수관을 지나 하늘로). 3.2초에 약 9m
	var lift_a := 9.0
	var once := {}   # 람다 안에서 한 번만(지역 변수는 값으로 잡힌다)
	await _animate(3.2, func(k: float) -> void:
		var lift: float = lift_a * (0.35 * k * k + 0.65 * k)   # 천천히 떠나 고르게
		rise.call(lift)
		_cam_gen += 1
		_cam(near.call(lift), Vector3(rk.x, yn + lift + kid_c - 0.1, rk.y), 38.0)
		_sky_light_k(0.35 + 0.45 * k)
		if k > 0.45 and not once.has("rise_mid"): once["rise_mid"] = true; _mark_shot("rise_mid"))
	await _shot("rise")
	d.sfx("wind")
	# 수관 위: 카메라는 멈추고 고개만 든다. 아이들은 빛기둥 속으로 작아지며 올라가 빛에 묻힌다
	var cam_stop: Vector3 = near.call(lift_a) + Vector3(0, 0, 1.6)
	var sky_look := Vector3(rk.x, g + 24.0, rk.y)
	var p_stop := _cam_pos
	await _animate(3.4, func(k: float) -> void:
		var lift: float = lift_a + 26.0 * (k * k * 0.7 + 0.3 * k)
		rise.call(lift)
		var w := smoothstep(0.0, 1.0, k)
		var follow := Vector3(rk.x, yn + lift + kid_c, rk.y)
		_cam_gen += 1
		_cam_fov = lerpf(38.0, 44.0, w)
		_cam(p_stop.lerp(cam_stop, w), follow.lerp(sky_look, smoothstep(0.35, 1.0, k)))
		_sky_light_k(0.8 + 0.2 * k)
		if k > 0.55 and not once.has("flash"):   # 빛에 묻힌다
			once["flash"] = true
			an.ch.flash(Color(1.0, 0.93, 0.74), 1400.0); aa.ch.flash(Color(1.0, 0.93, 0.74), 1400.0)
		if k > 0.3 and not once.has("light"): once["light"] = true; _mark_shot("light"))
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

# 가림 점무늬를 받지 않게(새 동아줄): 카메라가 아이들 곁 5~7m로 다가서면 카메라 앞 비우기(occ_near)와 아이들 둘레 비우기(occ_r)가
# 아이들이 붙잡은 줄까지 지운다. 줄 재질만 점무늬를 뺀 셰이더 사본으로 바꾼다(잎·가지는 그대로 비워진다)
var _nodither := {}
var _nodither_mi := []   # 바꾼 MeshInstance3D(장면이 끝나면 되돌린다 — 소품 수수밭)
func _no_occ_clear() -> void:
	for mi in _nodither_mi:
		if is_instance_valid(mi):
			for i in mi.get_surface_override_material_count(): mi.set_surface_override_material(i, null)
	_nodither_mi.clear()

func _no_occ(n: Node) -> void:
	if n == null: return
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null: continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as ShaderMaterial
			if m == null or m.shader == null: continue
			if not _nodither.has(m.shader):
				var sh := Shader.new()
				sh.code = m.shader.code.replace("if (occ_r > 0.0 || occ_near > 0.0) {", "if (false) {")
				_nodither[m.shader] = sh
			var m2 := m.duplicate() as ShaderMaterial
			m2.shader = _nodither[m.shader]
			mi.set_surface_override_material(i, m2)
		_nodither_mi.append(mi)

# 흐림(틸트시프트) 끄기/되돌리기 — 동아줄 장면에서만
func _sharp(on: bool) -> void:
	if d.main.has_method("set_cine_sharp"): d.main.set_cine_sharp(on)

# 움직이는 도중의 한 장면(화면 검토 때만): 기다리지 않고 찍는다
func _mark_shot(nm: String) -> void:
	if d.test != null and d.test.has_method("tale_shot"): d.test.tale_shot(nm)

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
		_no_occ(d.props.get("p_sorghum", {}).get("node"))   # 카메라 앞 비우기(occ_near, 6~12m)도 받지 않게 — 수숫대가 반투명해 보였다
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
	_sharp(false)   # 붉은 수수밭 뒤 고요까지 — 두 빛(암전) 전에 흐림을 되돌린다
	d.learn_clue("rotten_rope", true)
	beat("tiger_rotten_rope")

# 수숫대가 떨어진 자리에서부터 줄줄이 붉어진다(붉은 줄을 하나씩 겹쳐 세우고, 다 되면 소품을 붉은 판으로)
func sorghum_red() -> void:
	var c: Vector2 = d.anchor("sorghum")
	var y := _ground("sorghum")
	var rows := []
	for ri in [2, 1, 3, 0, 4]:
		rows.append(_tale_node({ "kind": "sorghum", "w": 5.0, "d": 4.5, "row": ri, "red": true }, c, y + 0.01))
		_no_occ(rows[-1])
		await d.wait(0.6)
	d.world_state("sorghum_red", true)
	await d.get_tree().process_frame
	d._update_props()
	var red_rec: Dictionary = d.props.get("p_sorghum_red", {})
	for i in 60:   # 소품은 다음 갱신에서 지어진다 — 지어지면 점무늬를 빼고 나서 줄들을 치운다
		if red_rec.get("node") != null: break
		await d.get_tree().process_frame
	_no_occ(red_rec.get("node"))
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
# v3.2 §9 첫 기록(주막에서 사건이 섰을 때) — 원문 그대로 네 줄
const FIRST_RECORD := [
	"떡장수 아낙이 사흘째 돌아오지 않는다.",
	"마지막으로 북쪽 고갯길로 갔다.",
	"집에는 아이 둘이 남아 있다.",
	"이겸으로 보이는 선비도 이 일을 물었다.",
]
const ROUTE_TEXT := {
	"jumo": "주막에서 들었다. 고개 너머 사는 떡장수가 사흘째 돌아오지 않는다고.",
	"kids": "고개 너머 외딴집에서 오누이를 만났다. 어머니가 장에 간 지 사흘째라 한다.",
}
const NIGHT_TEXT := "밤, 문밖에서 “엄마 왔다.” 하는 목소리가 났다. 문틈으로 털 난 손을 내밀었다가 물러갔고, 다시 와서는 가루 묻은 흰 손을 내밀었다. 누이는 문을 열지 않고 아우를 데리고 뒷문으로 빠져나갔다. 문을 밀고 들어온 것은 떡장수의 저고리와 수건을 걸친 범이었다."
const OUTCOME_TEXT := {
	"A_hold": "범이 아이들을 쫓을 때, 칼을 뽑고 범 앞을 막아섰다. 범은 쓰러지지 않았지만, 그사이 아이들은 우물가 나무에 올랐다.",
	"A_down": "범이 아이들을 쫓을 때, 칼을 뽑고 범 앞을 막아섰다. 나는 쓰러졌지만, 그사이 아이들은 우물가 나무에 올랐다.",
	"B_hold": "범이 아이들을 쫓아 쪽문으로 나오다 디딤돌에 부어 둔 참기름에 미끄러졌다. 그사이 아이들은 우물가 나무에 올랐다.",
	"B_down": "범이 아이들을 쫓아 쪽문으로 나오다 디딤돌에 부어 둔 참기름에 미끄러졌다. 그사이 아이들은 우물가 나무에 올랐다.",
	"C": "범이 아이들을 쫓을 때, 오솔길 어귀의 떡 냄새로 범의 코를 돌려 놓고 횃불로 길을 막았다. 범은 곧 돌아왔지만, 그사이 아이들은 우물가 나무에 올랐다.",
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
	var c_ok: bool = k.call("K_FOOD") and has_bait and has_torch
	var c_hint := "범의 버릇을 더 알면 범을 잠시 집에서 떼어 놓을 수 있을지 모른다." if cp < 2 else "범이 무엇에 끌리고 무엇을 꺼리는지 하나씩 맞춰지고 있다."
	if cp == 4: c_hint += ("" if has_torch else " 불이 있어야 할 것 같다.") if has_bait else " 꾈 것이 있어야 할 것 같다."
	return [
		{ "id": "A", "title": "범 앞을 막아선다", "available": true, "text": "범과 아이들 사이를 막아선다. 이 범은 쉽게 쓰러지지 않는다. 버티는 만큼 아이들이 멀어진다." },
		{ "id": "B", "title": "미끄러운 디딤돌" if k.call("K_CLIMB") else "???", "available": k.call("K_CLIMB") and has_oil,
			"text": "아이들이 드나드는 쪽문 디딤돌에 참기름을 부어 둔다. 쫓아 나오는 범이 미끄러진다.",
			"hint": "범은 미끄러운 곳을 오르지 못했다. 미끄럽게 할 무언가가 있다면…" if k.call("K_CLIMB") else ("기름병이 손에 있다. 쓸 데가 있을까…" if has_oil else "범이 무엇에 미끄러지는지 아직 모른다.") },
		{ "id": "C", "title": "떡과 횃불로 잠시 꾄다" if cp >= 2 else "???", "available": c_ok,
			"text": "오솔길 어귀에 떡을 놓아 범의 코를 돌려 놓고, 횃불로 나무 쪽 길을 막는다. 범은 곧 돌아온다.", "hint": c_hint },
	]

func summary() -> Array:
	var p := []
	if String(S.flags.get("route", "jumo")) == "kids":
		p.append(ROUTE_TEXT.kids)
		if f("igyeom_link"): p.append(FIRST_RECORD[3])
	else: p.append_array(FIRST_RECORD)
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
	if f("first_encounter"): p.append("해질녘 고갯마루에서 범을 보았다. 뒤에서 덮쳤다가 물러나 숲으로 사라졌다.")
	# §23 어머니의 과거 장면은 적지 않는다(옛 저장의 회상 기록만 그대로 보인다)
	if S.has_clue("pass_memory") and not f("past_scene_seen"): p.append("사흘 전 고갯길 — 떡장수는 고개마다 떡을 내주며 걸었고, 서낭당 앞에서 돌아오지 못했다.")
	if S.has_clue("flour_prints"): p.append("방앗간 밀가루 바닥에 큰 발자국. 앞발 자국만 유난히 하얗다.")
	if f("link_inferred"): p.append(LINK_LINE)
	if f("tiger_house_suspected"): p.append("흰 발자국이 외딴집 쪽으로 이어진다. " + PURPOSE_LINE)
	var o := String(S.flags.get("pending_detail", S.vars.get("CASE_NAMWON_DETAIL", "")))
	if f("dusk_prep") and o == "" and not f("night_wait_started"): p.append(DUSK_LINE)
	if f("time_line") and o == "": p.append(TIME_LINE)
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
