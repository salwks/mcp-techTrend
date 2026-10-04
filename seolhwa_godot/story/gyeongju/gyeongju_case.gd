# 사건 「세 번째 등불」 — 데이터로 쓰기 번거로운 장면(도착·이동·낮 조사·밤을 기다림·세 불빛(움직임·깜빡임·사라짐)·
# 등성이 싸움(사람 적)·숯쟁이 구함·바위 밑 탁본 조각·우치와 추격·탁본 도구·새벽 결말)과 기록책·결말 카드.
# 데이터(gyeongju_data.gd)의 { "call": "이름" }과 조건식 fn('이름')이 부른다. 불빛 셋은 여기서 그린다(OmniLight + 빛 판).
#   ① 등불: 아낙 손(걸음에 흔들림) ② 신호: 등성이(셋 짧게·하나 길게 가렸다 열림, 먼 바다가 답함) ③ 흰 불: 흔들림·발소리 없이 비탈을 내려와 망부석 앞에서 꺼짐
extends RefCounted

const D := preload("res://story/gyeongju/gyeongju_data.gd")
const Progress := preload("res://scripts/region/progress.gd")
const Chase := preload("res://scripts/story/chase.gd")
const TOOL := D.TOOL
const FRAG := D.FRAG
const CASE_TITLE := "세 번째 등불"
const DAY_CLUES := ["pass_oil", "spur_rag", "stone_day"]
const L3_SPEED := 1.35
const L3_REST := 5.0

var d      # story_director
var S:
	get: return d.S

var lights := {}          # id → { node, omni, glow, halo, on(0~1), want }
var _l3_s := 0.0          # 셋째 불: 길 위 거리
var _l3_rest := 0.0       # 꺼진 뒤 다시 뜨기까지
var _l3_len := 0.0
var _l3_pts: Array = []
var _l3_near_said := false
var _blink_t := 0.0
var _wide := false
var _t := 0.0

func _init(director) -> void:
	d = director

func R(steps: Array) -> void:
	await d.runner.exec(steps, d.runner.gen)

func flag(k: String, v = true) -> void:
	S.flags[k] = v; d.runner.log_line("flag", [k, v]); d.mark_dirty()

func f(k: String) -> bool: return S.is_flag(k)
func senses() -> bool: return d.spirits != null and d.spirits.senses()

func on_load() -> void:
	if S.phase == "night" and d.main.hour > 5.0 and d.main.hour < 19.0: d.set_hour(22.0)

# ---------------------------------------------------------------------------
# S3001 도착 — 경주 장 주막(먼 포털로 왔으면 암전 한 번으로 장까지: 노정 도착의 마무리)
# ---------------------------------------------------------------------------
func arrival() -> void:
	flag("arrived")
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	if pp.distance_to(d.anchor("town_start")) > 300.0 and pp.distance_to(d.anchor("village_arrive")) > 300.0:
		d.cutscene(true)
		await d.ui.fade(true, 0.6)
		d.set_hour(11.0)
		d.set_weather("clear")
		d.teleport_to("town_start", "left")
		await wait_loaded(8.0)
		await d.ui.fade(false, 0.6)
		await d.ui.caption("서천 나루를 건너 경주 장에 닿았다.", 2.2)
		d.cutscene(false)
	if not S.has("ITM_TOOL_009"):
		for it in [["ITM_TOOL_009", 1], ["ITM_WPN_001", 1], ["ITM_WPN_002", 1], ["ITM_AMMO_001", 12], ["COIN", 8]]: d.give(it[0], it[1], true)

func start_case(route: String) -> void:
	if f("case_started"): return
	flag("case_started"); flag("route", route)
	S.seen["S3001"] = true
	if S.phase == "start": S.phase = "explore"
	d.learn_clue("rumor_lights", true)
	if not S.has("ITM_TOOL_009"):
		for it in [["ITM_TOOL_009", 1], ["ITM_WPN_001", 1], ["ITM_WPN_002", 1], ["ITM_AMMO_001", 12], ["COIN", 8]]: d.give(it[0], it[1], true)
	d.ui.toast("새 사건 — 「%s」" % CASE_TITLE, "journal")

# 먼 길(장 ↔ 치술령 아래 마을 약 5km)은 걸어도 되고 건너뛸 수도 있다(§36.2 이동거리 축소)
func travel(at: String, cap: String) -> void:
	await d.ui.fade(true, 0.7)
	d.teleport_to(at, "up")
	await wait_loaded(10.0)
	if S.phase != "night": d.set_hour(minf(d.main.hour + 1.5, 16.5))
	await d.ui.fade(false, 0.7)
	await d.ui.caption(cap, 2.2)

func wait_loaded(limit: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		await d.get_tree().process_frame
		var w = d.main.world
		var c: Vector2i = w.tile_of(d.main.player_pos.x, d.main.player_pos.z)
		if not w.scatter_busy_near(c, 1) and not d.main.placement.busy_near(c, 1): break
	d.main.player_pos.y = d.world.height_at(d.main.player_pos.x, d.main.player_pos.z)

# ---------------------------------------------------------------------------
# S3002 낮 조사 — 별것 없다
# ---------------------------------------------------------------------------
func on_day_clue() -> void:
	S.seen["S3002"] = true
	var n := 0
	for c in DAY_CLUES:
		if S.has_clue(c): n += 1
	if n >= 2 and not f("hint_wait"):
		flag("hint_wait")
		d.ui.toast("낮에는 별것 없다. 망부석 위 너럭바위에서 밤을 기다려 볼까.", "info")

func examine_stone_day() -> void:
	var t := ["큰 바위가 바다 쪽을 보고 섰다. 앞에 돌무더기와 작은 제단.", "둘레에 발자국이 없다. 이끼 사이로 닳은 새김이 있는 듯한데 읽히지 않는다."]
	if bool(S.vars.get("SKILL_RUBBING", false)): t.append("(탁본 도구로 떠 볼 수 있을 것 같다.)")
	await d.ui.examine("망부석", t, "clue")

func elder_talk() -> void:
	await d.ui.say("마을 노인", ["숯쟁이 집사람은 밤마다 고개에 오르오. 말려도 소용없소."] if f("wife_met") else ["고개 불 셋 가운데 어느 게 그놈을 데려갔는지…"])
	await R([{ "choice": "", "loop": true, "options": [
		{ "label": "망부석은 어떤 바위요?", "when": "not f('el_stone')", "do": [{ "flag": "el_stone" },
			{ "say": "마을 노인", "lines": ["옛날 어느 부인이 바다 건너 간 남편을 기다리다 돌이 됐다는 바위요. 우린 그냥 그렇게 부르오."] }] },
		{ "label": "고개로 올라간다", "when": "not ph('night')", "end": true, "do": [{ "call": "travel", "args": ["pass", "마을 뒤 고갯길을 올라 성황당에 닿았다."] }] },
		{ "label": "그만 가 보겠소.", "end": true }] }])

# ---------------------------------------------------------------------------
# S3003 밤을 기다린다(너럭바위) → 불 셋
# ---------------------------------------------------------------------------
func wait_night() -> void:
	d.cutscene(true)
	await d.ui.caption("너럭바위에 앉아 해가 지기를 기다린다.", 1.8)
	await d.ui.fade(true, 0.9)
	S.phase = "night"
	d.on_phase()
	d.set_hour(20.6)
	d.set_weather("clear")
	d.teleport_to("lookout", "left")
	await wait_loaded(6.0)
	d.place_actor("wife", "wife_pass", null, "right")
	_l3_s = 0.0; _l3_rest = 6.0
	d.camera({ "focus": "lookout_focus", "distance": 80.0, "pitch": 44.0 })
	_wide = true
	await d.ui.fade(false, 0.9)
	await d.ui.caption("해가 지고, 고개가 어두워졌다.", 2.0)
	d.move_actor("wife", [[-999.3, 2777.7], [-986.0, 2789.0], "wife_bend"], 1.3, "walk", "idle")
	await d.ui.caption("…불이 하나. 고갯길을 오른다.", 2.4)
	await d.ui.caption("또 하나. 동쪽 등성이에서.", 2.4)
	_l3_rest = 0.0
	await d.ui.caption("그리고… 하나 더.", 2.4)
	S.seen["S3003"] = true
	d.journal_note("밤. 고개에 불이 셋")
	d.cutscene(false)
	d.ui.toast("너럭바위에서는 멀리 보인다. 가까이 가서 가려 보자.", "info")

# ---------------------------------------------------------------------------
# 첫째 불 — 아낙(S3004)
# ---------------------------------------------------------------------------
func near_wife() -> void:
	flag("wife_seen")
	await d.ui.caption("등불이 걸음에 맞춰 흔들린다. 흰 수건을 쓴 아낙이 고개 너머를 본다.", 2.6)
	d.learn_rule("R_SWAY")

func wife_met() -> void:
	if f("man_rescued"):
		await d.ui.say("아낙", ["…그이가 왔어요. 불 켜 둔 데로."])
	flag("wife_met")
	if not f("wife_seen"): flag("wife_seen"); d.learn_rule("R_SWAY")
	d.learn_clue("light_wife")
	S.seen["S3004"] = true
	await check_done()

func wife_night() -> void:
	if f("man_rescued"): await d.ui.say("아낙", ["날 밝으면 내려가요. 이 사람 데리고."])
	else: await d.ui.say("아낙", ["불 켜 두면 보고 찾아오겠지요."])

# ---------------------------------------------------------------------------
# 둘째 불 — 등성이의 신호, 밀수꾼(S3005)
# ---------------------------------------------------------------------------
func spur_encounter() -> void:
	flag("smugglers_met")
	d.cutscene(true)
	d.face_actor("player", null, "spur")
	if lights.has("l2"): lights.l2.want = false
	await d.ui.caption("불이 탁 꺼졌다. 누군가 \"쉿\" 한다.", 2.0)
	d.learn_clue("light_signal")
	d.learn_rule("R_BLINK")
	await d.ui.caption("짚 꾸러미를 진 사내 둘. 먼 바다 쪽에서 작은 불이 한 번 깜빡이고 사라진다.", 2.6)
	d.learn_clue("smugglers")
	S.seen["S3005"] = true
	d.cutscene(false)
	var res: String = await d.combat("spur", { "allow_flee": true })
	d.runner.last["fight"] = res
	var rep: Array = d.combat_view.human_report()
	var caught := 0
	for r in rep:
		if String(r.out) == "down":
			caught += 1
			flag("caught_a" if String(r.id) == "sm_a" else "caught_b")
	flag("fight_result", res)
	d.runner.log_line("fight", [res, rep.map(func(r): return [r.id, r.out])])
	match res:
		"lose":
			await d.ui.fade(true, 0.8)
			d.end_combat()
			d.teleport_to([-870.0, 2862.0], "down")
			await d.wait(0.6)
			await d.ui.fade(false, 0.8)
			await d.ui.caption("정신을 차리니 사내들은 짐을 지고 감포 쪽 비탈로 사라진 뒤였다.", 2.6)
		"escaped":
			await d.ui.caption("물러섰다. 사내들이 짐을 지고 감포 쪽 비탈로 사라진다.", 2.4)
		_:
			if caught == 2: await d.ui.caption("둘 다 쓰러졌다. 허리끈으로 손을 묶었다.", 2.2)
			elif caught == 1: await d.ui.caption("하나는 쓰러졌고, 하나는 감포 쪽 비탈로 달아났다.", 2.4)
			else: await d.ui.caption("둘 다 짐을 버리고 감포 쪽 비탈로 달아났다.", 2.2)
	flag("smugglers_resolved")
	await d.wait(0.6)
	await d.ui.caption("숯가마 쪽에서 끙끙대는 소리가 난다.", 2.0)
	d.mark_dirty()

func rescue() -> void:
	d.cutscene(true)
	await d.ui.caption("가지 더미 뒤에 사내가 손발이 묶인 채 웅크려 있다. 숯 검댕투성이다.", 2.4)
	await d.ui.fade(true, 0.4)
	d.anim_actor("husband", "idle")
	await d.ui.fade(false, 0.4)
	await d.ui.say("숯쟁이", ["…고맙소. 저 불을 보러 왔다가 저놈들한테 붙잡혔소.", "집사람이… 걱정하고 있을 텐데."])
	flag("man_rescued")
	d.learn_clue("rescued")
	d.cutscene(false)
	d.move_actor("husband", [[-866.0, 2860.0], [-905.0, 2846.0], [-951.0, 2830.0], [-967.0, 2821.8], [-972.8, 2802.6]], 1.7, "walk", "idle")
	d.ui.toast("숯쟁이가 고갯길 쪽으로 비틀비틀 내려간다.", "info")
	await check_done()

# ---------------------------------------------------------------------------
# 셋째 불 — 흔들림·발소리 없이 내려와 망부석 앞에서 꺼진다(S3006). 공격 없음.
# ---------------------------------------------------------------------------
func light3_end() -> void:
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	if pp.distance_to(d.anchor("stone_front")) > 15.0 or f("light3_seen") or S.phase != "night": return
	flag("light3_seen")
	d.cutscene(true)
	await d.ui.caption("흰 불이 망부석 앞에서 멎더니… 꺼졌다.", 2.2)
	if senses():
		await R([{ "spirit": "jy_figure", "do": "place", "at": "stone_front" }, { "spirit": "jy_figure", "do": "face", "to": "sea_answer" },
			{ "spirit": "jy_figure", "do": "show" }])
		await d.wait(1.0)
		await R([{ "spirit": "jy_figure", "do": "vanish" }])
		await d.ui.caption("꺼지는 순간, 흰 옷의 사람 형체가 바다 쪽을 보고 서 있었다. 곧 없었다.", 2.8)
		d.learn_clue("figure")
		flag("figure_seen")
	else:
		await d.ui.caption("바위 앞엔 아무도 없다. 이끼 낀 돌뿐.", 2.2)
		if d.spirits != null and d.spirits.owned().has(D.CHARM) and not d.spirits.equipped(""):
			d.ui.toast("호신부를 지니지 않았다 (Q)", "info")
	d.learn_clue("light_none")
	d.learn_rule("R_STILL")
	S.seen["S3006"] = true
	d.cutscene(false)
	d.ui.toast("바위 밑에 틈이 있다.", "info")

# ---------------------------------------------------------------------------
# S3007 탁본 조각 — 이겸의 두 줄
# ---------------------------------------------------------------------------
func find_fragment() -> void:
	d.anim_actor("player", "crouch")
	await d.ui.examine("바위 밑의 탁본 조각", [
		"바위 밑 틈에 기름종이로 싼 것이 끼어 있다. 펴 보니 닳은 새김을 먹으로 떠 낸 오래된 탁본 조각이다.",
		"가장자리에 낯익은 필체. “남겨진 흔적과 방금 생긴 흔적을 한데 묶지 말 것.”",
		"그 옆에 한 줄 더. “오래됐다는 이유로 진짜인 것도, 새것이라는 이유로 거짓인 것도 아니다.”"], "clue")
	d.anim_actor("player", "idle")
	flag("fragment")
	d.give(FRAG)
	d.learn_clue("fragment")
	master_trace()
	d.journal_note("이겸의 흔적 — 경주")
	await R([{ "event": "S3008" }])

func master_trace() -> void:
	var cur := String(S.vars.get("MAIN_MASTER_TRACE", ""))
	var parts := Array(cur.split(",", false))
	if not parts.has("GYEONGJU"): parts.append("GYEONGJU")
	var v := ",".join(PackedStringArray(parts))
	S.vars["MAIN_MASTER_TRACE"] = v
	Progress.set_var("MAIN_MASTER_TRACE", v)
	d.runner.log_line("var", ["MAIN_MASTER_TRACE", v])
	d.ui.toast("기록책에 새로 적힌 곳 — 경주", "journal")

# ---------------------------------------------------------------------------
# S3008 우치 — 짧은 추격(준비된 하산길)
# ---------------------------------------------------------------------------
func woochi_scene() -> void:
	flag("woochi_seen")
	d.place_actor("woochi", "woochi_spot", null, "up")
	d.cutscene(true)
	d.face_actor("player", null, "woochi_spot")
	await d.ui.say("우치", ["그 양반 아직도 그런 걸 적어놓고 다녔군."])
	await d.ui.say("나그네", ["스승을 압니까?"])
	await d.ui.say("우치", ["나보다 당신이 더 늦었소."])
	d.learn_clue("woochi_here")
	S.vars["MAIN_WOOCHI_KNOWN"] = true
	d.cutscene(false)
	var res: String = await Chase.run(d, "s3008")
	d.runner.last["chase"] = res
	flag("woochi_chase", res)
	flag("woochi_done")
	if res == "lost":
		await d.ui.caption("놓쳤다. 발자국이 고갯길을 따라 성황당 쪽으로 이어진다.", 2.4)
	d.learn_clue("rope")
	d.ui.toast("성황당 신목 밑동에 무언가 걸려 있다.", "info")
	d.mark_dirty()

# 우치가 남긴 탁본 도구 — 보상(SKILL_RUBBING)
func take_bundle() -> void:
	await d.ui.examine("신목 밑동", ["밧줄 매듭 곁에 작은 보자기가 걸려 있다. 솜방망이·먹·한지 몇 장 — 탁본 도구다.",
		"먹이 아직 마르지 않았다. 방금 무언가를 떠 간 것이다."], "clue")
	d.give(TOOL)
	S.vars["SKILL_RUBBING"] = true
	Progress.set_var("SKILL_RUBBING", true)
	d.runner.log_line("var", ["SKILL_RUBBING", true])
	d.ui.toast("탁본 도구 — 닳은 새김·표식을 먹으로 떠 볼 수 있다 (비석·돌 곁에서 E)", "item")
	await check_done()

# ---------------------------------------------------------------------------
# 셋을 다 가렸으면 새벽 → 결말
# ---------------------------------------------------------------------------
func check_done() -> void:
	if f("resolved"): return
	if not (f("wife_met") and f("man_rescued") and S.has(TOOL)): return
	await resolve()

func resolve() -> void:
	flag("resolved")
	var caught: bool = f("caught_a") or f("caught_b")
	var o := "A" if caught else "B"
	S.vars["CASE_GYEONGJU_OUTCOME"] = o
	S.vars["CASE_GYEONGJU_DETAIL"] = o + ("_figure" if f("figure_seen") else "")
	d.runner.log_line("outcome", S.vars.CASE_GYEONGJU_DETAIL)
	d.cutscene(true)
	await d.ui.fade(true, 1.0)
	d.end_combat()
	S.phase = "morning"
	d.on_phase()
	d.set_hour(6.0)
	d.teleport_to("village_square", "up")
	d.place_actor("wife", "couple_f", null, "right")
	d.place_actor("husband", "couple_m", null, "left")
	await wait_loaded(8.0)
	d.camera({ "focus": "village_square", "pitch": 36.0, "distance": 18.0 })
	await d.wait(0.3)
	await d.ui.fade(false, 1.0)
	await d.ui.caption("새벽. 치술령 아래 마을.", 2.0)
	await d.ui.caption({
		"A": "붙잡힌 사내들이 마당에 묶여 있다. 노인이 감포 객주로 사람을 보낸다.",
		"B": "등성이 사내들은 감포 쪽으로 달아났다. 노인이 혀를 찬다.",
	}[o], 2.6)
	await d.ui.caption("숯쟁이 부부가 고갯길을 내려왔다. 아낙의 등은 꺼져 있다.", 2.6)
	S.seen["S3008"] = true
	d.camera(null)
	await d.ui.caption(ENDING_EXTRA[o], 2.8)
	S.phase = "done"
	d.on_phase()
	d.set_hour(8.0)
	d.cutscene(false)
	d.journal_note("사건 종결 — 「%s」" % CASE_TITLE)
	await d.show_ending()
	d.save()

# ---------------------------------------------------------------------------
# 끝난 뒤 대사(§30·§27)
# ---------------------------------------------------------------------------
func _o() -> String: return String(S.vars.get("CASE_GYEONGJU_OUTCOME", ""))

func jumo_done() -> void:
	await d.ui.say("주모", { "A": ["치술령 불 둘은 사람 짓이었다더구먼. 하나는… 글쎄요."], "B": ["감포 바다엔 아직도 밤마다 불이 깜빡인대요."] }.get(_o(), ["치술령이 좀 조용해졌다더군요."]))

func guest_done() -> void:
	await d.ui.say("주막 손님", { "A": ["밀수꾼을 잡았다지? 그래도 셋째 불은 아직 뜬다더군."], "B": ["치술령에 불 하나 줄었대. 감포 쪽으로 옮겨 갔다나."] }.get(_o(), ["…"]))

func elder_done() -> void:
	await d.ui.say("마을 노인", { "A": ["저놈들은 관아로 넘기겠소. 바위 앞엔 마을 사람들이 상을 차렸소."], "B": ["놓친 놈들은 또 올 거요. 밤엔 어귀를 지켜야겠소."] }.get(_o(), ["고맙소."]))

func wife_done() -> void:
	await d.ui.say("아낙", ["이제 고개엔 안 올라가요. …그 흰 불은, 저도 봤어요. 무섭지는 않았어요."])

# 밤의 불빛·너럭바위 카메라·밤 붙잡기
func ambient(dt: float) -> void:
	_t += dt
	if S.phase == "night" and d.main.hour > 3.6 and d.main.hour < 18.0: d.set_hour(3.6)   # 셋을 가릴 때까지 밤
	_update_lights(dt)
	# 흔들리는 불(아낙) 가까이 — 처음 한 번
	var wa = d.actors.get("wife")
	if S.phase == "night" and not f("wife_seen") and wa != null and wa.shown and not d.runner.busy:
		if Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(Vector2(wa.pos.x, wa.pos.z)) < 11.0:
			d.runner.run([{ "call": "near_wife" }])
	# 너럭바위: 높은 데서는 멀리 보인다
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var on_top: bool = S.phase == "night" and pp.distance_to(d.anchor("lookout")) < 6.5 and not d.runner.busy and not d.combat_view.active and not d.free_move
	if on_top and not _wide:
		_wide = true; d.camera({ "focus": "lookout_focus", "distance": 80.0, "pitch": 44.0 })
	elif not on_top and _wide and not d.runner.busy:
		_wide = false; d.camera(null)

# ---------------------------------------------------------------------------
# 불빛 그리기
# ---------------------------------------------------------------------------
func _glow_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.75))
	var t := GradientTexture2D.new()
	t.gradient = g; t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5); t.fill_to = Vector2(1.0, 0.5)
	t.width = 64; t.height = 64
	return t

func _quad(col: Color, size: float, tex: Texture2D, alpha: float) -> MeshInstance3D:
	var q := QuadMesh.new(); q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = tex
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.disable_receive_shadows = true
	var mi := MeshInstance3D.new()
	mi.mesh = q; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _make_light(id: String, col: Color, energy: float, rng: float) -> Dictionary:
	var n := Node3D.new(); n.name = "gj_light_" + id
	d.main.scene_vp.add_child(n)
	var tex := _glow_tex()
	var glow := _quad(col.lightened(0.4), 0.8, tex, 1.0)
	var halo := _quad(col, 5.5, tex, 0.5)
	n.add_child(halo); n.add_child(glow)
	var o := OmniLight3D.new()
	o.light_color = col; o.light_energy = energy; o.omni_range = rng; o.shadow_enabled = false
	n.add_child(o)
	n.visible = false
	var rec := { node = n, omni = o, glow = glow, halo = halo, on = 0.0, want = false, energy = energy, col = col }
	lights[id] = rec
	return rec

func _set_light(rec: Dictionary, pos: Vector3, k: float) -> void:
	rec.node.position = pos
	rec.node.visible = k > 0.01
	rec.omni.light_energy = rec.energy * k
	(rec.glow.material_override as StandardMaterial3D).albedo_color.a = k
	(rec.halo.material_override as StandardMaterial3D).albedo_color.a = 0.5 * k

func _night_now() -> bool:
	return d.main.hour >= 19.0 or d.main.hour < 5.0

func _update_lights(dt: float) -> void:
	if lights.is_empty():
		_make_light("l1", Color("#ffb860"), 2.2, 7.0)
		_make_light("l2", Color("#ff8a3a"), 2.6, 7.5)
		_make_light("l3", Color("#cfe2ff"), 1.6, 6.0)
		_make_light("sea", Color("#ffb070"), 0.0, 1.0)
		for p in D.L3_PATH: _l3_pts.append(Vector2(p[0], p[1]))
		for i in range(1, _l3_pts.size()): _l3_len += _l3_pts[i - 1].distance_to(_l3_pts[i])
	var night: bool = S.phase == "night"
	var fight: bool = d.combat_view != null and d.combat_view.active
	# ① 아낙의 등불(손 높이, 걸음에 흔들림)
	var l1: Dictionary = lights.l1
	var wa = d.actors.get("wife")
	var w1: bool = night and wa != null and wa.shown
	if w1:
		var sway := 0.05 * sin(_t * (7.0 if wa.anim == "walk" else 1.6))
		var side := 0.32 if wa.facing == "right" else (-0.32 if wa.facing == "left" else 0.0)
		_fade(l1, true, dt)
		_set_light(l1, Vector3(wa.pos.x + side + sway, wa.pos.y + 0.95 + absf(sway) * 0.6, wa.pos.z + 0.05), l1.on * (0.9 + 0.1 * sin(_t * 9.0)))
	else:
		_fade(l1, false, dt); _set_light(l1, l1.node.position, l1.on)
	# ② 등성이 신호: 셋 짧게·하나 길게(가렸다 열림). 먼 바다의 작은 답불. 결말 B면 밤마다 먼 데서 깜빡인다
	_blink_t = fmod(_blink_t + dt, 5.2)
	var bt := _blink_t
	var lit := (bt < 0.35) or (bt > 0.7 and bt < 1.05) or (bt > 1.4 and bt < 1.75) or (bt > 2.3 and bt < 3.8)
	var l2: Dictionary = lights.l2
	var sp: Vector2 = d.anchor("spur")
	var after_b: bool = S.phase == "done" and _o() == "B" and _night_now()
	if night and not f("smugglers_met") and not fight:
		l2.on = 1.0 if lit else 0.0
		_set_light(l2, Vector3(sp.x, d.world.height_at(sp.x, sp.y) + 1.4, sp.y), l2.on)
	elif after_b:
		var fe: Vector2 = d.anchor("flee_east")
		_set_light(l2, Vector3(fe.x, d.world.height_at(fe.x, fe.y) + 1.4, fe.y), 0.55 if lit else 0.0)
	else:
		_set_light(l2, l2.node.position, 0.0)
	var sea: Dictionary = lights.sea
	var sa: Vector2 = d.anchor("sea_answer")
	var ans: bool = night and not f("smugglers_met") and bt > 4.1 and bt < 4.45
	_set_light(sea, Vector3(sa.x, d.world.height_at(sa.x, sa.y) + 2.0, sa.y), 0.7 if ans else 0.0)
	# ③ 흰 불: 든 사람 없이, 흔들림 없이 비탈을 내려와 망부석 앞에서 꺼진다(밤마다 — 해결 뒤에도)
	var l3: Dictionary = lights.l3
	var w3: bool = (night or (S.phase == "done" and _night_now())) and not fight
	if not w3:
		_fade(l3, false, dt); _set_light(l3, l3.node.position, l3.on); return
	if _l3_rest > 0.0:
		_l3_rest -= dt
		_set_light(l3, l3.node.position, 0.0); l3.on = 0.0
		return
	var spd := L3_SPEED * (6.0 if d.ui.auto else 1.0)
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	_l3_s += spd * dt
	var q := _l3_at(_l3_s)
	l3.on = minf(1.0, l3.on + dt * 1.5)
	_set_light(l3, Vector3(q.x, d.world.height_at(q.x, q.y) + 1.25, q.y), l3.on)
	if not _l3_near_said and S.phase == "night" and pp.distance_to(q) < 10.0 and not d.runner.busy:
		_l3_near_said = true
		d.ui.caption("흰 불이 흔들림 없이 내려온다. 발소리가 없다.", 2.4)
	if _l3_s >= _l3_len:
		_l3_s = 0.0; _l3_rest = L3_REST; l3.on = 0.0
		_set_light(l3, l3.node.position, 0.0)
		d.runner.log_line("light3", ["vanish", snappedf(pp.distance_to(d.anchor("stone_front")), 0.1)])
		if S.phase == "night" and not f("light3_seen") and not d.runner.busy: d.runner.run([{ "call": "light3_end" }])

func _l3_at(s: float) -> Vector2:
	for i in range(1, _l3_pts.size()):
		var l: float = _l3_pts[i - 1].distance_to(_l3_pts[i])
		if s <= l: return _l3_pts[i - 1].lerp(_l3_pts[i], s / maxf(l, 0.001))
		s -= l
	return _l3_pts[_l3_pts.size() - 1]

func _fade(rec: Dictionary, on: bool, dt: float) -> void:
	rec.on = move_toward(rec.on, 1.0 if on else 0.0, dt * 2.0)

# 시험용: 셋째 불의 지금 자리(없으면 INF)
func light3_pos() -> Vector2:
	if lights.is_empty() or _l3_rest > 0.0: return Vector2.INF
	return _l3_at(_l3_s)

# ---------------------------------------------------------------------------
# 사건 기록(R) — 증언은 말한 사람과 함께(kind heard + by). 숫자 세기는 쓰지 않는다.
# ---------------------------------------------------------------------------
const ROUTE_TEXT := {
	"jumo": "경주 장 주막에서 들었다. 치술령에 밤마다 불이 셋 뜬다고.",
	"elder": "치술령 아래 마을 노인에게 들었다. 숯쟁이가 고개로 올라가 안 돌아왔다고.",
}
const OUTCOME_TEXT := {
	"A": "흔들리는 등불은 남편을 기다리던 아낙이었다. 가렸다 열리던 불은 감포 쪽 배에 신호하던 밀수꾼이었다 — 붙잡아 마을에 넘겼다. 숯가마 뒤에 묶여 있던 숯쟁이를 구했다.",
	"B": "흔들리는 등불은 남편을 기다리던 아낙이었다. 가렸다 열리던 불은 감포 쪽 배에 신호하던 밀수꾼이었다 — 놓쳤다. 숯가마 뒤에 묶여 있던 숯쟁이는 구했다.",
}
const THIRD_TEXT := "흔들리지 않던 흰 불은 망부석 앞에서 꺼졌다. 든 사람은 없었다."
const ENDING_EXTRA := {
	"A": "그 뒤로 치술령 밤길에 횃불 든 마을 사람이 는다. 망부석 앞에는 상이 차려진다. 흰 불은 가끔 아직 뜬다.",
	"B": "치술령 불은 하나로 줄었다. 대신 감포 앞바다에서 밤마다 불이 깜빡인다는 말이 돈다.",
}

func solutions() -> Array:
	return [
		{ "id": "L1", "title": "흔들리는 불" if f("wife_seen") else "???", "available": f("wife_met"),
			"text": "걸음에 맞춰 흔들리는 등불 — 든 사람에게 다가가 묻는다.", "hint": "밤에 고갯길 굽이로 가 보자." },
		{ "id": "L2", "title": "가렸다 열리는 불" if f("smugglers_met") else "???", "available": f("smugglers_resolved") and f("man_rescued"),
			"text": "신호하던 자들과 부딪치고, 사라진 사람을 찾는다.", "hint": "동쪽 등성이 — 그 뒤 숯가마." },
		{ "id": "L3", "title": "흔들리지 않는 불" if f("light3_seen") else "???", "available": f("light3_seen"),
			"text": "따라가 어디서 꺼지는지 본다. 벨 것도 쫓을 것도 없다.", "hint": "망부석 앞에서 기다려 보자." },
	]

func summary() -> Array:
	var p := []
	p.append(ROUTE_TEXT.get(String(S.flags.get("route", "jumo")), ROUTE_TEXT.jumo))
	if S.has_clue("missing_man"): p.append("숯쟁이가 사흘째 안 돌아왔다(마을 노인의 말).")
	if S.seen.has("S3002") and S.phase != "night" and S.phase != "done": p.append("낮의 고개엔 별것 없다. 성황당 기름 자국, 등성이의 그을린 천, 발자국 없는 바위.")
	if S.seen.has("S3003"): p.append("밤, 너럭바위에서 고개에 뜬 불 셋을 보았다.")
	if f("wife_met"): p.append("흔들리는 등불 — 남편을 기다리는 아낙(아낙의 말).")
	if f("smugglers_met"): p.append("가렸다 열리는 불 — 등성이에서 감포 쪽 배에 신호하던 사내들.")
	if f("man_rescued"): p.append("숯가마 뒤에 묶여 있던 숯쟁이를 구했다.")
	if f("light3_seen"): p.append(THIRD_TEXT + (" 꺼지는 순간 흰 옷의 형체가 바다 쪽을 보고 있었다." if f("figure_seen") else ""))
	if f("fragment"): p.append("바위 밑에서 스승의 탁본 조각을 찾았다.")
	if f("woochi_done"): p.append("우치가 나타났다가 미리 매어 둔 밧줄로 고개 아래로 사라졌다.")
	var o := _o()
	if o != "":
		p.append(OUTCOME_TEXT.get(o, ""))
		p.append(ENDING_EXTRA.get(o, ""))
	return p

func journal() -> Dictionary:
	if not f("case_started"):
		return { "cases": [], "empty": "아직 경주에서 적힌 사건이 없다." }
	var clues := []
	for id in S.clues:
		var c: Dictionary = d.data.clues.get(id, { "title": id, "text": "" })
		var e := { "title": c.title, "text": c.text }
		for k in ["kind", "by"]:
			if c.has(k): e[k] = c[k]
		clues.append(e)
	var rules := []
	for id in S.rules:
		var r: Dictionary = d.data.rules.get(id, { "title": id, "text": "" })
		rules.append({ "title": r.title, "text": r.text, "kind": r.get("kind", "guess") })
	var solved: bool = _o() != "" and S.phase in ["morning", "done"]
	return { "cases": [{ "id": "gyeongju", "title": CASE_TITLE, "status": "solved" if solved else "active", "rules_title": "불빛의 결",
		"summary": summary(), "clues": clues, "rules": rules, "solutions": solutions(), "notes": S.notes }] }

func ending_data() -> Dictionary:
	var k := _o() if _o() != "" else "A"
	return {
		"case_title": CASE_TITLE,
		"title": { "A": "가려낸 세 불빛", "B": "바다로 옮겨 간 불빛" }[k],
		"outcome": k,
		"paragraphs": [OUTCOME_TEXT.get(k, ""), THIRD_TEXT, ENDING_EXTRA.get(k, "")],
		"record": "탁본 도구를 얻었다 — 닳은 새김과 표식을 떠 볼 수 있다. 기록책에 새로 적힌 곳 — 경주.",
	}
