# 사건 「빈 배의 값」 — 데이터로 쓰기 번거로운 장면(도착·공간 넘기·물살 관찰·탁본·시간과 날씨·뱃길 닫힘·구조·세 갈래 결말·운송장)
# 과 기록책·결말 카드. 데이터(hwangju_data.gd)의 { "call": "이름" }과 조건식 fn('이름')이 부른다.
# 물살 표식은 scripts/story/drift.gd, 탁본은 경주 사건 쪽 모듈(scripts/story/rubbing.gd — 데이터 rubbings로 바위를 넘기고, 뜬 기록 progress.rubbings만 본다)이 맡는다.
extends RefCounted

const D := preload("res://story/hwangju/hwangju_data.gd")
const Progress := preload("res://scripts/region/progress.gd")
const ROPE := D.ROPE
const FLOATS := D.FLOATS
const CASE_TITLE := "빈 배의 값"
const TIME_RATE := 1.0 / 150.0   # 장산곶에서 조사하는 동안 한 시간 = 2분 30초(대화·컷신 중에는 멈춤)

var d      # story_director
var S:
	get: return d.S

func _init(director) -> void:
	d = director

func R(steps: Array) -> void:
	await d.runner.exec(steps, d.runner.gen)

func flag(k: String, v = true) -> void:
	S.flags[k] = v; d.runner.log_line("flag", [k, v]); d.mark_dirty()

func f(k: String) -> bool: return S.is_flag(k)
func on_route() -> bool: return d.space_id == D.RT
func resolved() -> bool: return String(S.vars.get("CASE_HWANGJU_OUTCOME", "")) != ""
func storm_now() -> bool: return f("storm") and not f("storm_passed")
func lane_open() -> bool:
	if S.phase == "done": return true
	return f("boat_ok") and not storm_now()
func evidence() -> bool:
	return S.has_clue("coins") and S.has_clue("receipt") and S.knows("R_NO_PRICE")

func on_load() -> void:
	# 공간마다 날씨는 새로 선다 — 사건이 바꿔 둔 바람을 다시 건다
	if on_route() and S.phase != "done" and not resolved():
		if storm_now(): d.main.weather.force("storm", -1.0, 0.0)
		elif f("windy") and not f("storm_passed"): d.main.weather.force("wind", -1.0, 0.0)
		elif f("jangsan_arrived"): sea_weather()

# 사건 날씨의 출발점: 흐리고 바람 조금(북부 기후대 확률이 눈을 굴려도 바닷가 구조 장면은 눈 없이 — 바람·큰 바람으로만 나빠진다)
func sea_weather() -> void:
	var w = d.main.weather
	if w == null: return
	w.force("cloudy", -1.0, 0.0)
	w.snow = 0.0

# ---------------------------------------------------------------------------
# S4001 도착 — 도화동(먼 곳에 닿았으면 암전 한 번으로 어귀까지 — §36.2 이동거리 축소)
# ---------------------------------------------------------------------------
func arrival() -> void:
	flag("arrived")
	d.cutscene(true)
	if d.main.weather != null: d.main.weather.force("clear", 30.0 * 60.0, 0.0); d.main.weather.snow = 0.0
	var far := Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("old_gate")) > 300.0
	if far:
		await d.ui.fade(true, 0.6)
		d.teleport_to("hj_arrive", "left")
		await wait_loaded(10.0)
		await d.ui.fade(false, 0.6)
		await d.ui.caption("의주대로를 올라 황주에 닿았다. 황주천 건너 들마을 — 도화동.", 2.6)
	d.camera({ "focus": "old_yard", "distance": 22.0, "pitch": 34.0 })
	await d.ui.caption("낮은 초가 마당에 노인 하나가 대문 쪽으로 얼굴을 두고 앉아 있다.", 2.6)
	d.camera(null)
	d.cutscene(false)
	if not S.has("ITM_TOOL_009"):
		for it in [["ITM_TOOL_009", 1], ["ITM_WPN_001", 1], ["ITM_WPN_002", 1], ["ITM_AMMO_001", 12], ["COIN", 8]]: d.give(it[0], it[1], true)
	if Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("old_yard")) > 4.0:
		d.teleport_to("old_out", "up")

func start_case() -> void:
	if f("case_started"): return
	flag("case_started")
	S.seen["S4001"] = true
	if S.phase == "start": S.phase = "explore"
	d.learn_clue("daughter_left")
	d.ui.toast("새 사건 — 「%s」" % CASE_TITLE, "journal")
	d.journal_note("도화동 눈먼 노인의 딸이 배를 탔다")

func wait_loaded(limit: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		await d.get_tree().process_frame
		var w = d.main.world
		var c: Vector2i = w.tile_of(d.main.player_pos.x, d.main.player_pos.z)
		if not w.scatter_busy_near(c, 1) and not d.main.placement.busy_near(c, 1): break
	d.main.player_pos.y = d.world.height_at(d.main.player_pos.x, d.main.player_pos.z)

# ---------------------------------------------------------------------------
# 황주 사람들
# ---------------------------------------------------------------------------
func old_man_talk() -> void:
	if f("to_jangsan"):
		await d.ui.say("눈먼 노인", ["장산곶까지 가 주시는 거요?"]); return
	await d.ui.say("눈먼 노인", ["그 돈엔 손도 안 댔소. 그 애가 돌아오면 돌려줄 거요."] if S.has_clue("coins") else ["마루 끝에 꾸러미가 있소. 그 애가 두고 간 거요."])
	if S.has_clue("broker_words"): await offer_travel()

func old_man_done() -> void:
	var o := String(S.vars.get("CASE_HWANGJU_OUTCOME", ""))
	var l: Array = { "A": ["연이 손이 이리 찬 줄 몰랐소. …고맙소."], "B": ["연이 손이 이리 찬 줄 몰랐소. 그 탁가 놈은 놓쳤다지만, 이 애가 왔으면 됐소."],
		"C": ["…물 한 그릇 떠 놓고 기다리오. 발소리가 들리면 그 애인가 하고."] }.get(o, ["누구시오?"])
	await d.ui.say("눈먼 노인", l)

func daughter_home_talk() -> void:
	await d.ui.say("연이", ["아버지 밥은 이제 제가 지어요."] if String(S.vars.get("CASE_HWANGJU_OUTCOME", "")) == "A" else ["그 사람, 또 어디서 누구 딸을 사고 있을까요."])

# 장산곶으로(노정 공간 넘어가기) — 걸어서 겸이포 길 끝 포털로 가도 되고, 여기서 바로 가도 된다
func offer_travel() -> void:
	var i: int = await d.ui.choice("", [{ label = "장산곶으로 간다 (겸이포 길)" }, { label = "그만 가 보겠소." }])
	if i == 0: await go_jangsan()

func go_jangsan() -> void:
	flag("to_jangsan")
	S.seen["S4002"] = true
	if S.phase == "start": S.phase = "explore"
	d.journal_note("장산곶으로 — 중개인도 그리 갔다")
	var pt = _portal_to(D.RT)
	if pt == null:
		d.ui.toast("길이 아직 닦이지 않았다", "info"); return
	await d.ui.fade(true, 0.7)
	d.set_hour(d.main.hour + 1.5)
	S.time = d.main.hour
	S.save()   # 대본 시험에서도 공간을 넘어 이어 가도록(사건 저장 파일 — 시험은 시험 파일)
	d.runner.log_line("travel", [D.RT])
	d.main._travel(pt)

# 사건이 끝난 뒤(또는 시험) 황주로 돌아가기
func go_hwangju() -> void:
	var pt = _portal_to(D.RJ)
	if pt == null: return
	S.time = d.main.hour
	S.save()
	d.main._travel(pt)

func _portal_to(target: String):
	for pt in d.main.portals:
		if String(pt.get("target", "")) == target: return pt
	return null

# ---------------------------------------------------------------------------
# S4003 장산곶 — 노정 들머리에서 곧장 갈지, 어촌 도착
# ---------------------------------------------------------------------------
func route_skip() -> void:
	var i: int = await d.ui.choice("장산곶 바닷가 띠. 재령 들과 구월산 기슭을 지나야 한다.", [
		{ label = "장산곶까지 곧장 간다" }, { label = "걸어서 간다" }])
	if i != 0: return
	await d.ui.fade(true, 0.7)
	d.teleport_to("j_arrive", "right")
	d.set_hour(maxf(d.main.hour + 2.0, 11.0))
	await wait_loaded(10.0)
	await d.ui.fade(false, 0.7)
	await d.ui.caption("재령 들을 지나 구월산 기슭을 돌아, 해 질 녘이 되기 전에 장산곶에 닿았다.", 2.6)

func jangsan_arrival() -> void:
	flag("jangsan_arrived")
	sea_weather()
	S.phase = "sea"
	d.on_phase()
	d.set_hour(maxf(d.main.hour, 11.0))
	d.cutscene(true)
	d.camera({ "focus": "rite_rock", "distance": 70.0, "pitch": 26.0 })
	await d.wait(0.3)
	await d.ui.caption("장산곶. 곶 끝 벼랑에 바람이 부딪친다.", 2.4)
	d.camera({ "focus": "wreck", "distance": 30.0, "pitch": 34.0 })
	await d.ui.caption("만 안쪽 모래톱에 부서진 배 조각이 밀려와 있다.", 2.4)
	d.camera(null)
	d.cutscene(false)
	S.seen["S4003"] = true
	await d.ui.caption("어부  “그 장삿배, 제물 바치고도 돌아오다 부서졌다지.”", 2.2)
	await d.ui.caption("어부  “쉿, 탁 서방 듣겠네.”", 1.8)
	d.journal_note("장산곶. 저녁 물때면 바람이 바뀐다고 한다")
	d.ui.toast("해가 기울면 바다가 거칠어진다", "info")

# ---------------------------------------------------------------------------
# 시계·날씨·뱃길(S4006 난이도) — 매 프레임(director ambient)
# ---------------------------------------------------------------------------
var _lane_t := 0.0
func ambient(dt: float) -> void:
	if not on_route() or S.phase == "done": return
	var busy: bool = d.runner.busy or d.ui.modal
	if f("jangsan_arrived") and not f("rescued") and not resolved() and not f("storm_passed") and not busy:
		if not storm_now():
			d.set_hour(d.main.hour + dt * TIME_RATE)
		if d.main.hour >= D.STORY_HOURS.wind and d.main.hour < 23.0 and not f("windy"):
			flag("windy")
			d.main.weather.force("wind", -1.0, 25.0)
			d.ui.toast("바람이 거세진다. 물결이 높아졌다.", "info")
		if d.main.hour >= D.STORY_HOURS.storm and d.main.hour < 23.0 and not f("storm"):
			d.runner.run([{ "call": "storm_start" }])
			return
	# 탁본(경주 모듈)으로 옛 제의 바위를 떴으면 — 사건은 그 기록만 본다
	if not f("rubbed") and not busy and f("jangsan_arrived") and bool(S.vars.get("SKILL_RUBBING", false)):
		var rb = Progress.data().get("rubbings")
		if rb is Dictionary and rb.has("hj_rite"):
			d.runner.run([{ "call": "rubbed" }]); return
	# 뱃길: 사건 동안 배는 뱃사공이 몬다(말을 걸어야 간다). 걸어서 배(뱃길 걷기 면)에 오르면 되돌린다 — 배가 저절로 떠나기 전에
	_lane_t -= dt
	if _lane_t > 0.0 or busy: return
	_lane_t = 0.15
	var end := _on_lane()
	if end != "": d.runner.run([{ "call": "lane_blocked", "args": [end] }])

# 플레이어가 장산곶 뱃길 걷기 면 위에 섰나("pier" | "islet" | "") — river_lanes와 같은 판정, 배를 띄우지는 않는다
func _on_lane() -> String:
	var L = d.main.get("lanes")
	if L == null: return ""
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	for f2 in L.lanes:
		if String(f2.id) != "rt_jangsan_islet_lane" or not f2.bb.has_point(pp): continue
		if d.world.ground_at(pp.x, pp.y) >= d.world.sea_y + 0.1: return ""
		var pr: Dictionary = L._project(f2, pp)
		if absf(pr.lat) < 2.4 and pr.s > -1.0 and pr.s < float(f2.len) + 1.0:
			return "pier" if pr.s < float(f2.len) * 0.5 else "islet"
	return ""

func lane_blocked(end: String) -> void:
	d.cutscene(true)
	if storm_now(): await d.ui.say("뱃사공", ["이 바람엔 못 띄우오! 바람 지나기를 기다리시오."])
	elif not f("boat_ok"): await d.ui.say("뱃사공", ["그 배 내 배요. 바위섬 쪽 물엔 안 들어가오."])
	else: await d.ui.say("뱃사공", ["배는 내가 모오. 갈 때 말하시오."])
	d.teleport_to("pier_land" if end == "pier" else "islet_cove", "left" if end == "pier" else "down")
	d.cutscene(false)

# 뱃사공이 노를 저어 간다(장산곶 선창 ↔ 바위섬 갯가, scripts/region/boat_ride.gd — 배 위 풍경 시점, Space 건너뛰기).
#   시각이 흐른다(물때 압박). 배 타기가 없으면 예전처럼 암전 한 번(§36.2 이동거리 축소). to: "islet" | "back"
const LANE := "rt_jangsan_islet_lane"
func sail(to: String) -> void:
	var boats = d.main.get("boats")
	if boats != null and not boats.route(LANE).is_empty() and not boats.riding():
		d.cutscene(true)
		flag("on_islet", to == "islet")
		if boats.board(LANE, 0 if to == "islet" else 1, true):
			d.ui.caption("뱃사공이 노를 저어 암초 사이로 배를 몰았다." if to == "islet" else "뱃사공이 배를 돌려 선창으로 저어 간다.", 2.4)
			await boats.arrived
		d.set_hour(d.main.hour + 0.2)
		if to != "islet": await d.ui.caption("배가 선창에 닿았다.", 1.6)
		d.cutscene(false)
		if to == "islet" and not f("islet_seen"): await islet_arrive()
		return
	d.cutscene(true)
	await d.ui.fade(true, 0.7)
	d.set_hour(d.main.hour + 0.4)
	if to == "islet":
		flag("on_islet")
		d.teleport_to("islet_cove", "down")
	else:
		flag("on_islet", false)
		d.teleport_to("pier_land", "up")
	await wait_loaded(6.0)
	await d.ui.fade(false, 0.7)
	await d.ui.caption("뱃사공이 노를 저어 암초 사이로 배를 몰았다." if to == "islet" else "배가 선창에 닿았다.", 2.0)
	d.cutscene(false)
	if to == "islet" and not f("islet_seen"): await islet_arrive()

func rubbed() -> void:
	flag("rubbed")
	S.seen["S4005"] = true
	d.learn_clue("rite_rubbing")

func storm_start() -> void:
	flag("storm")
	d.main.weather.force("storm", -1.0, 12.0)
	d.cutscene(true)
	await d.ui.caption("하늘이 시커멓게 내려앉는다. 큰 바람이다.", 2.4)
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var at_sea: bool = f("on_islet") or pp.distance_to(d.anchor("islet_landing")) < 40.0
	if at_sea:
		flag("on_islet", false)
		await d.ui.say("뱃사공", ["돌아가야 하오! 물이 뒤집힌다!"])
		await d.ui.fade(true, 0.6)
		d.teleport_to("pier_land", "left")
		await wait_loaded(6.0)
		await d.ui.fade(false, 0.6)
		await d.ui.caption("뱃사공이 억지로 배를 돌려 선창에 댔다. 바위섬은 물보라에 가렸다.", 2.6)
	d.cutscene(false)
	d.ui.toast("큰 바람 — 뱃길이 닫혔다. 어부 집에서 바람을 피할 수 있다.", "info")
	d.journal_note("큰 바람. 오늘 밤은 아무도 못 나간다")

func wait_storm() -> void:
	await d.ui.say("어부", ["밤새 불 지피고 있으시오. 이 바람은 아침에야 자오."])
	await d.ui.fade(true, 1.0)
	d.set_hour(6.0)
	d.main.weather.release(0.0)
	sea_weather()
	flag("storm_passed")
	flag("broker_gone")   # 중개인은 바람 속에 떠났다(짐 일부를 두고)
	d.teleport_to("hut", "down")
	await wait_loaded(6.0)
	await d.ui.fade(false, 1.0)
	await d.ui.caption("새벽. 바람이 잤다. 탁 중개인이 묵던 방은 비어 있다.", 2.6)
	d.ui.toast("뱃사공이 섬에 배를 대 주겠다고 한다", "info")
	flag("boat_ok")

# ---------------------------------------------------------------------------
# 장산곶 사람들
# ---------------------------------------------------------------------------
func fisher_talk() -> void:
	await d.ui.say("어부", ["탁 서방은 선창 위 집에 묵소. 선주 셈 받을 게 남았다나."] if not f("fisher_met") else ["바람 바뀌기 전에 볼일 보시오."])
	flag("fisher_met")
	await R([{ "choice": "", "loop": true, "options": [
		{ "label": "그물 찌 몇 개 얻을 수 있겠소?", "when": "not f('got_floats')", "do": [{ "call": "take_floats" }] },
		{ "label": "밧줄 좀 빌릴 수 있겠소?", "when": "not has('%s') and not f('rescued')" % ROPE, "do": [
			{ "say": "어부", "lines": ["걸대에 걸린 거 가져가시오. 바위에 걸어도 안 끊어지오."] }, { "give": ROPE }] },
		{ "label": "그 장삿배 이야기를 해 주시오", "when": "not f('fisher_ship')", "do": [{ "flag": "fisher_ship" },
			{ "say": "어부", "lines": ["바다에 값을 치렀으니 무사하다 했지. 사흘 바람을 맞고 저 모래톱에 올라왔소."] }] },
		{ "label": "그만 가 보겠소.", "end": true }] }])

func fisher_storm() -> void:
	await d.ui.say("어부", ["오늘 밤은 아무도 못 나가오. 들어와서 바람을 피하시오."])
	await R([{ "choice": "", "options": [{ "label": "바람이 지나기를 기다린다", "do": [{ "call": "wait_storm" }] }, { "label": "그만 가 보겠소.", "end": true }] }])

func fisher_done() -> void:
	var o := String(S.vars.get("CASE_HWANGJU_OUTCOME", ""))
	await d.ui.say("어부", { "A": ["삼백 냥에 서른 냥이라니. 관아에서 셈 다시 하겠지."], "B": ["탁 서방은 그날로 안 보이오. 연이는 몸이 많이 나았소."],
		"C": ["그 큰 바람 뒤로 바다가 잠잠하다고들 하오. …그게 무슨 소린지."] }.get(o, ["바다가 오늘은 순하오."]))

func broker_jt_talk() -> void:
	await d.ui.say("탁 중개인", ["또 보는구려. 여긴 뱃사람들 일이오."])
	if S.has_clue("receipt") and not f("broker_receipt"):
		flag("broker_receipt")
		await d.ui.say("탁 중개인", ["선주가 뭐라 적었든 내 알 바 아니오. 바다 값이 원래 비싸오."])

func boatman_talk() -> void:
	if storm_now():
		await d.ui.say("뱃사공", ["이 바람엔 못 띄우오. 바람 지나기를 기다리시오."]); return
	if f("boat_ok"):
		if f("rescued") or resolved():
			await d.ui.say("뱃사공", ["물이 순할 때 다녀옵시다."]); return
		await d.ui.say("뱃사공", ["바위섬 뒤 갯가까지 대 주리다."])
		await R([{ "choice": "", "options": [{ "label": "바위섬으로 갑시다", "do": [{ "call": "sail", "args": ["islet"] }] }, { "label": "조금 있다 가겠소.", "end": true }] }])
		return
	if not S.knows("R_CURRENT_ISLET"):
		await d.ui.say("뱃사공", ["바위섬 쪽엔 안 가오. 제물 바친 물이오."])
		await R([{ "choice": "", "options": [
			{ "label": "그 물이 어디로 도는지 아시오?", "do": [{ "say": "뱃사공", "lines": ["물살이야 날마다 보지만… 그 물엔 손 안 대오."] }] },
			{ "label": "그만 가 보겠소.", "end": true }] }])
		return
	var i: int = await d.ui.choice("", [{ label = "제물 바위 앞에 던진 찌가 바위섬 뒤로 흘러들었소" }, { label = "그만 가 보겠소." }])
	if i != 0: return
	await d.ui.say("뱃사공", ["…섬 뒤 갯구멍이라. 물이 그리 돈다면, 사람도 그리 갔겠구려.", "배를 대 보리다. 바위틈이 깊으니 맨손으론 안 될 거요."])
	flag("boat_ok")
	S.seen["S4006"] = true
	d.ui.toast("뱃사공이 바위섬에 배를 대 주겠다고 한다", "info")
	await R([{ "choice": "", "options": [{ "label": "바위섬으로 갑시다", "do": [{ "call": "sail", "args": ["islet"] }] }, { "label": "조금 있다 가겠소.", "end": true }] }])

# ---------------------------------------------------------------------------
# S4003·S4004 물살 관찰 — 벼랑에서 보고, 찌를 던지고, 돌아온 갯가에서 줍는다
# ---------------------------------------------------------------------------
func look_sea() -> void:
	await d.ui.examine("벼랑 아래 바다", ["바람에 물비린내가 실려 온다. 벼랑 밑으로 거품 줄이 두 갈래로 갈린다.",
		"하나는 암초 사이로 바위섬 쪽, 하나는 만 안쪽으로 휜다.", "무엇이든 띄워 보면 어디로 가는지 알 수 있을 텐데."], "clue")
	d.learn_clue("foam_lines")

func take_floats() -> void:
	if f("got_floats"): return
	flag("got_floats")
	await d.ui.say("어부", ["찌야 남아도는 거요. 붉은 천 맨 걸로 가져가시오. 눈에 잘 띄게."])
	d.give(FLOATS, 4)

func throw_floats() -> void:
	flag("thrown")
	d.teleport_to("throw_stand", "up")
	d.face_actor("player", null, "throw_pt")
	await d.ui.caption("붉은 천을 맨 찌 셋을 벼랑 아래 물에 던진다.", 2.0)
	d.take(FLOATS, 3)
	await R([{ "drift": "offering", "from": "throw_pt", "n": 3, "spread": 2.0, "seed": 4004, "watch": true, "time_scale": 4.0, "hours": 0.5,
		"view": { "distance": 48.0, "pitch": 52.0 }, "store": "drift" }])
	var res: Array = d.runner.last.get("drift", [])
	var bay := res.count("bay_beach")
	var isl := res.count("islet_cove")
	S.seen["S4004"] = true
	await d.ui.caption(("%s 만 안쪽 모래톱 쪽으로 흘러갔다." % ("둘은" if bay == 2 else ("셋 다" if bay == 3 else ("하나는" if bay == 1 else "아무것도")))) if bay > 0 else "만 안쪽으로 간 찌는 없다.", 2.4)
	if isl > 0:
		await d.ui.caption("하나는 암초 사이로 들어가 바위섬 뒤로 사라졌다.", 2.4)
		d.learn_rule("R_CURRENT_ISLET")
	d.learn_clue("drift_watch")
	if bay > 0: d.ui.toast("만 안쪽 모래톱 — 부서진 배가 올라온 그 갯가다", "info")
	if isl > 0: d.journal_note("물에 든 것은 바위섬 뒤 갯구멍으로 흘러든다")

func cape_throw() -> void:
	flag("cape_thrown")
	d.teleport_to("cape_stand", "right")
	d.face_actor("player", null, "cape_pt")
	d.take(FLOATS, 1)
	await R([{ "drift": "cape", "from": "cape_pt", "n": 1, "spread": 0.0, "seed": 4010, "watch": true, "time_scale": 4.0,
		"view": { "distance": 40.0, "pitch": 48.0 }, "store": "drift_cape" }])
	await d.ui.caption("곶 끝에서 던진 찌는 먼바다로 나가 보이지 않게 되었다.", 2.4)
	d.learn_clue("cape_lost")
	d.learn_rule("R_PLACE_DIFFERS")

func pick_floats() -> void:
	await d.ui.examine("돌아온 찌", ["부서진 배 조각 곁, 젖은 모래에 붉은 천 찌 둘이 밀려와 있다. 벼랑 아래 던진 바로 그것이다.",
		"바다는 받은 것을 삼키지 않았다. 물살이 정한 갯가로 돌려보냈다."], "rule")
	d.learn_clue("floats_back")
	d.learn_rule("R_SEA_RETURNS")
	d.give(FLOATS, 2, true)
	await check_no_price()

func check_no_price() -> void:
	if S.knows("R_NO_PRICE") or not (S.has_clue("wreck") and S.has_clue("floats_back")): return
	await d.ui.caption("값을 치렀다는 배도 부서져 같은 갯가에 올라왔다. 사람을 바쳐 바람이 멎었다는 흔적은 어디에도 없다.", 3.0)
	d.learn_rule("R_NO_PRICE")

# S4005 옛 제의 바위 — 탁본(경주 SKILL_RUBBING)이 있으면 더 읽는다. 없어도 사건은 풀린다(추가 단서만 없음)
func examine_rite() -> void:
	S.seen["S4005"] = true
	if not bool(S.vars.get("SKILL_RUBBING", false)):
		await d.ui.examine("옛 제의 바위", ["벼랑 끝, 바다 쪽을 보는 바위. 앞에 넓적한 제물 돌.", "앞면에 무언가 새겨져 있지만 바닷바람에 닳아 읽을 수 없다."], "clue")
		d.learn_clue("rite_worn")
		return
	var ok: bool = await rubbing({ "id": "hj_rite", "title": "옛 제의 바위", "at": "rite_rock",
		"before": ["앞면에 무언가 새겨져 있지만 바닷바람에 닳았다."],
		"result": D.RITE_RUBBING })
	if not ok: return
	flag("rubbed")
	d.learn_clue("rite_rubbing")

# 탁본 모듈(scripts/story/rubbing.gd)이 있으면 그쪽이 바위를 맡는다(이 대상은 숨는다 — 데이터 rite.when). 없을 때만 같은 카드를 여기서
func rub_module() -> bool:
	return d.get("_rub") != null

func rubbing(spec: Dictionary) -> bool:
	await d.ui.caption("종이를 바위에 대고 먹 방망이로 두드린다…", 1.8)
	await d.ui.examine("탁본 — " + String(spec.get("title", "")), spec.get("result", []), "clue")
	return true

# ---------------------------------------------------------------------------
# S4006 바위섬 — 구조
# ---------------------------------------------------------------------------
func islet_arrive() -> void:
	flag("islet_seen")
	d.cutscene(true)
	d.camera({ "focus": "islet_cove", "distance": 16.0, "pitch": 40.0 })
	await d.ui.caption("바위섬 뒤 자갈 갯가. 바위틈 앞에 붉은 것이 걸려 있다.", 2.4)
	d.camera(null)
	d.cutscene(false)

func look_cove() -> void:
	await d.ui.examine("바위틈 앞", ["벼랑에서 던진 붉은 천 찌 하나가 바위에 걸려 있다.", "틈 안쪽에 불 피운 자국과 조개껍데기. 누군가 여기서 밤을 났다."], "clue")
	d.learn_clue("islet_cove")
	flag("islet_seen")

func rescue() -> void:
	if storm_now(): return
	if not S.has(ROPE):
		await d.ui.say("연이", ["…누구세요?"])
		await d.ui.caption("바위틈이 깊고 미끄럽다. 손이 닿지 않는다. 밧줄이 있어야겠다.", 2.6)
		if not f("tried_no_rope"):
			flag("tried_no_rope")
			d.journal_note("바위틈의 연이 — 밧줄이 있어야 꺼낼 수 있다")
		return
	d.cutscene(true)
	await d.ui.caption("밧줄을 바위에 감아 걸고 틈으로 내려간다.", 2.0)
	await d.ui.fade(true, 0.6)
	d.place_actor("daughter", "islet_cove", null, "up")
	d.anim_actor("daughter", "sit")
	await d.ui.fade(false, 0.6)
	await d.ui.say("연이", ["…배에서 떠밀렸어요. 물에 들었는데, 물이 저를 이리로 데려왔어요.", "아버지는요?"])
	await d.ui.say("나그네", ["도화동에서 기다리신다."])
	flag("rescued")
	flag("on_islet", false)
	d.learn_clue("rescued")
	S.seen["S4006"] = true
	await d.ui.fade(true, 0.8)
	S.phase = "after"
	d.on_phase()
	d.place_actor("daughter", "rest_spot", null, "down")
	d.anim_actor("daughter", "sit")
	d.teleport_to("pier_land", "up")
	await wait_loaded(6.0)
	await d.ui.fade(false, 0.8)
	await d.ui.caption("연이를 배에 태워 선창으로 돌아왔다. 어부들이 거적을 들고 내려온다.", 2.6)
	d.cutscene(false)
	await pier_choice()

# ---------------------------------------------------------------------------
# S4007 — 선창: 중개인의 셈을 따질 것인가, 연이부터 돌볼 것인가
# ---------------------------------------------------------------------------
func pier_choice() -> void:
	if resolved(): return
	d.camera({ "focus": "broker_jt", "distance": 18.0, "pitch": 36.0 })
	await d.ui.caption("선창 위 집 앞에서 탁 중개인이 연이를 보더니 낯빛이 변한다. 짐을 챙기려 한다.", 2.6)
	d.camera(null)
	var ev_ok := evidence()
	var hint := "셈이 맞지 않는다는 걸 보여 줄 것이 있어야 한다." if not (S.has_clue("coins") and S.has_clue("receipt")) else "바다가 값을 받는다는 말이 틀렸다는 걸 보여 줄 것이 있어야 한다."
	var i: int = await d.ui.choice("", [
		{ label = "탁 중개인을 붙잡아 셈을 따진다", disabled = not ev_ok, hint = hint },
		{ label = "연이부터 어부 집에 눕혀 몸을 녹인다" }])
	if i == 0 and ev_ok: await confront()
	else: await tend()

func confront() -> void:
	d.cutscene(true)
	d.face_actor("player", null, "broker_jt")
	await d.ui.say("나그네", ["선주에게서 삼백 냥. 노인 집엔 서른 냥."])
	await d.ui.say("탁 중개인", ["…바다 값이 원래 비싸오."])
	var lines := ["값을 치렀다는 배는 부서져 저 모래톱에 올라왔소.", "벼랑에서 던진 찌는 사흘도 안 걸려 같은 갯가로 돌아왔고, 하나는 바위섬 뒤로 갔소. 연이도 거기 있었소."]
	if f("rubbed"): lines.append("이 곶에서 옛날 바다에 띄운 건 짚 인형이었소. 바위에 그렇게 새겨져 있소.")
	await d.ui.say("나그네", lines)
	await d.ui.say("어부", ["삼백 냥에 서른 냥이라. 탁 서방, 관아에 가서 셈하시오."])
	flag("broker_caught")
	await d.ui.fade(true, 0.5)
	await d.ui.fade(false, 0.5)
	await resolve("A")

func tend() -> void:
	d.cutscene(true)
	await d.ui.fade(true, 0.8)
	d.teleport_to("hut", "down")
	await wait_loaded(6.0)
	await d.ui.fade(false, 0.8)
	await d.ui.caption("어부 집 아궁이에 불을 지피고 연이를 눕혔다. 숨이 고르게 돌아온다.", 2.6)
	await d.ui.say("어부", ["탁 서방이 말을 빌려 타고 황주 쪽으로 내뺐소. 짐 반은 두고 갔더구먼."])
	flag("broker_gone")
	await resolve("B")

func empty_cove() -> void:
	d.cutscene(true)
	d.camera({ "focus": "islet_shelter", "distance": 9.0, "pitch": 46.0 })
	await d.ui.examine("빈 바위틈", ["큰 바람이 지난 갯구멍은 비어 있다. 불 자국은 물에 쓸려 갔다.", "바위틈에 붉은 댕기 하나가 걸려 있다."], "clue")
	d.learn_clue("ribbon")
	d.camera(null)
	flag("rescue_failed")
	await d.ui.caption("바다가 데려갔는지, 누가 먼저 데려갔는지 알 수 없다.", 2.6)
	await resolve("C")

# ---------------------------------------------------------------------------
# 결말 → S4008 운송장 → 결말 카드
# ---------------------------------------------------------------------------
func resolve(branch: String) -> void:
	var detail := branch
	if branch != "C" and f("rubbed"): detail = branch + "_rubbing"
	S.vars["CASE_HWANGJU_OUTCOME"] = branch
	S.vars["CASE_HWANGJU_DETAIL"] = detail
	S.seen["S4007"] = true
	d.runner.log_line("outcome", detail)
	flag("resolved")
	if branch != "A": flag("broker_gone")
	d.main.weather.release(8.0)
	d.cutscene(true)
	await d.ui.fade(true, 0.7)
	d.teleport_to(Vector2(d.anchor("broker_bundle").x + 1.2, d.anchor("broker_bundle").y + 1.6), "up")
	await wait_loaded(6.0)
	await d.ui.fade(false, 0.7)
	await d.ui.caption({ "A": "어부들이 중개인의 궤짝을 내왔다. 관아에 넘길 짐이다.",
		"B": "중개인이 두고 간 궤짝이 방구석에 엎어져 있다.", "C": "중개인이 묵던 방. 궤짝 하나가 두고 가져가지 않은 채 남았다." }[branch], 2.4)
	await R([{ "event": "S4008" }])
	await d.ui.caption(ENDING_EXTRA[branch], 3.0)
	S.phase = "done"
	d.on_phase()
	d.cutscene(false)
	d.journal_note("사건 종결 — 「%s」" % CASE_TITLE)
	await d.show_ending()
	d.save()

func waybill() -> void:
	d.cutscene(true)
	flag("waybill_open")
	d.camera({ "focus": "broker_bundle", "distance": 5.5, "pitch": 52.0 })
	await d.wait(0.6)
	await d.ui.examine("낡은 운송장", ["궤짝 밑바닥, 기름종이에 싼 낡은 운송장 한 장.", "짐꾼 — 곽칠성. 도착지는 물에 번져 읽을 수 없다.",
		"모서리에 붉은 인장 — 朴. 한양 책방의 납품표에서 본 것과 같은 표식이다. 이것만으로는 무엇도 알 수 없다."], "item")
	await d.ui.examine("운송장 뒷면", ["뒷면에 낯익은 필체.", "“말이 바다를 설명하지 못하면, 물건이 돌아오는 방향부터 본다.”"], "clue")
	d.learn_clue("waybill", true)
	d.give("ITM_KEY_002", 1)
	if not f("park_waybill"):
		flag("park_waybill")
		S.vars["MAIN_PARK_MARK_COUNT"] = int(S.vars.get("MAIN_PARK_MARK_COUNT", 0)) + 1
		d.runner.log_line("var", ["MAIN_PARK_MARK_COUNT", S.vars.MAIN_PARK_MARK_COUNT])
	S.vars["MAIN_GWAK_NAME_KNOWN"] = true
	var parts := Array(String(S.vars.get("MAIN_MASTER_TRACE", "")).split(",", false))
	if not parts.has("HWANGJU"): parts.append("HWANGJU")
	S.vars["MAIN_MASTER_TRACE"] = ",".join(PackedStringArray(parts))
	for k in ["MAIN_GWAK_NAME_KNOWN", "MAIN_PARK_MARK_COUNT", "MAIN_MASTER_TRACE"]: Progress.set_var(k, S.vars[k])
	d.runner.log_line("var", ["MAIN_GWAK_NAME_KNOWN", true])
	d.ui.toast("기록책에 새로 적힌 이름 — 곽칠성", "journal")
	d.journal_note("곽칠성 — 중개인의 낡은 운송장")
	d.camera(null)
	S.seen["S4008"] = true

# ---------------------------------------------------------------------------
# 사건 기록(R)
# ---------------------------------------------------------------------------
const OUTCOME_TEXT := {
	"A": "바위섬 뒤 갯구멍에서 연이를 찾아 데려왔다. 선주의 셈 쪽지와 노인 집의 서른 냥, 부서진 배와 돌아온 찌를 들이밀자 탁 중개인은 어부들에게 붙잡혔다.",
	"A_rubbing": "바위섬 뒤 갯구멍에서 연이를 찾아 데려왔다. 셈 쪽지와 서른 냥, 부서진 배와 돌아온 찌, 옛 바위의 짚 인형 그림을 들이밀자 탁 중개인은 어부들에게 붙잡혔다.",
	"B": "바위섬 뒤 갯구멍에서 연이를 찾아 데려왔다. 연이를 돌보는 사이 탁 중개인은 말을 빌려 타고 달아났다.",
	"B_rubbing": "바위섬 뒤 갯구멍에서 연이를 찾아 데려왔다. 연이를 돌보는 사이 탁 중개인은 말을 빌려 타고 달아났다.",
	"C": "큰 바람 전에 바위섬에 닿지 못했다. 바람이 지난 아침, 갯구멍엔 붉은 댕기 하나만 남아 있었다. 탁 중개인은 바람 속에 떠났다.",
}
const ENDING_EXTRA := {
	"A": "연이는 사흘 뒤 도화동으로 돌아갔다. 장산곶 어부들은 그 뒤로 선주들이 내미는 '바다 값'을 받지 않는다.",
	"B": "연이는 사흘 뒤 도화동으로 돌아갔다. 장산곶 바다가 값을 받는다는 말은 아직 남아 있다.",
	"C": "도화동 노인은 대문 밖에 물 한 그릇을 떠 놓고 앉아 있다. 장산곶 바다가 처녀를 받았다는 소문이 돈다.",
}

func solutions() -> Array:
	var know_where: bool = S.knows("R_CURRENT_ISLET")
	return [
		{ "id": "A", "title": "중개인의 셈을 밝힌다" if S.has_clue("receipt") or S.has_clue("coins") else "???", "available": f("rescued") and evidence(),
			"text": "연이를 구한 뒤, 셈 쪽지·서른 냥·부서진 배·돌아온 찌로 중개인의 '바다 값'이 거짓임을 보인다.",
			"hint": "연이부터 찾아야 한다." if not f("rescued") else ("셈이 맞지 않는다는 걸 보여 줄 것이 있어야 한다." if not (S.has_clue("coins") and S.has_clue("receipt")) else "바다가 값을 받는다는 말이 틀렸다는 걸 보여 줄 것이 있어야 한다.") },
		{ "id": "B", "title": "연이부터 구한다" if know_where else "???", "available": f("rescued"),
			"text": "바위섬 뒤 갯구멍에서 연이를 꺼내 데려온다. 중개인은 놓칠 수 있다.",
			"hint": "물에 든 것이 어디로 가는지부터 알아야 한다." if not know_where else ("뱃사공이 배를 대 주어야 한다." if not f("boat_ok") else "바위틈이 깊다 — 밧줄이 있어야 한다.") },
		{ "id": "C", "title": "늦는다", "available": f("rescue_failed"),
			"text": "큰 바람이 오기 전에 바위섬에 닿지 못하면, 바람이 지난 뒤엔 늦는다.", "hint": "해가 지면 큰 바람이 온다." },
	]

func summary() -> Array:
	var p := []
	p.append("황주 도화동 눈먼 노인의 딸 연이가 돈 꾸러미를 두고 배를 탔다. 사흘째 소식이 없다.")
	if S.has_clue("sacrifice_talk"): p.append("이웃들은 연이가 제물로 팔려 갔다고 수군댄다.")
	if S.has_clue("coins"): p.append("노인 집에 남은 엽전은 서른 냥. 셈 쪽지에 '탁 중개'.")
	if S.has_clue("broker_words"): p.append("탁 중개인: “위험한 바다에는 값을 치러야 하오.” — 그 말이 맞는지는 아직 모른다.")
	if f("jangsan_arrived"): p.append("장산곶. 만 안쪽 모래톱에 부서진 장삿배.")
	if S.has_clue("receipt"): p.append("선주의 셈 쪽지 — 중개인에게 삼백 냥.")
	if S.has_clue("drift_watch"): p.append("제물 바위 앞에 던진 찌: 둘은 만 안쪽 모래톱으로, 하나는 바위섬 뒤로.")
	if S.has_clue("rite_rubbing"): p.append("옛 제의 바위의 탁본 — 옛날엔 짚 인형을 띄웠다.")
	elif S.has_clue("rite_worn"): p.append("옛 제의 바위의 새김은 닳아 읽을 수 없다.")
	if f("boat_ok") and not f("rescued"): p.append("뱃사공이 바위섬에 배를 대 주겠다고 했다.")
	if f("tried_no_rope") and not f("rescued"): p.append("바위틈의 연이 — 밧줄이 있어야 꺼낼 수 있다.")
	if storm_now(): p.append("큰 바람. 뱃길이 닫혔다.")
	elif f("windy") and not resolved(): p.append("바람이 거세진다. 해가 지면 큰 바람이 온다고 한다.")
	var o := String(S.vars.get("CASE_HWANGJU_DETAIL", ""))
	if o != "":
		p.append(OUTCOME_TEXT.get(o, ""))
		p.append(ENDING_EXTRA.get(String(S.vars.get("CASE_HWANGJU_OUTCOME", "A")), ""))
		if bool(S.vars.get("MAIN_GWAK_NAME_KNOWN", false)): p.append("중개인의 낡은 운송장에 '곽칠성'. 모서리에 朴 표식, 뒷면에 스승의 필체.")
	return p

func journal() -> Dictionary:
	if not f("case_started"):
		return { "cases": [], "empty": "아직 황주에서 적힌 사건이 없다." }
	var clues := []
	for id in S.clues:
		var c: Dictionary = d.data.clues.get(id, { "title": id, "text": "" })
		clues.append({ "title": c.title, "text": c.text, "kind": c.get("kind", "fact"), "by": c.get("by", "") })
	var rules := []
	for id in S.rules:
		var r: Dictionary = d.data.rules.get(id, { "title": id, "text": "" })
		rules.append({ "title": r.title, "text": r.text })
	var solved: bool = resolved() and S.phase == "done"
	var sols := []
	for s in solutions():
		var chosen: bool = solved and String(S.vars.CASE_HWANGJU_OUTCOME) == s.id
		var e: Dictionary = s.duplicate()
		e.available = s.available or chosen
		if chosen: e.text = String(s.text) + " — 이렇게 끝났다."
		sols.append(e)
	return { "cases": [{ "id": "hwangju", "title": CASE_TITLE, "status": "solved" if solved else "active", "rules_title": "물살의 규칙",
		"summary": summary(), "clues": clues, "rules": rules, "solutions": sols, "notes": S.notes }] }

func ending_data() -> Dictionary:
	var o := String(S.vars.get("CASE_HWANGJU_DETAIL", "A"))
	var k := String(S.vars.get("CASE_HWANGJU_OUTCOME", "A"))
	return {
		"case_title": CASE_TITLE,
		"title": { "A": "돌아온 찌, 밝혀진 셈", "B": "돌아온 딸", "C": "물 한 그릇" }[k],
		"outcome": k,
		"paragraphs": [OUTCOME_TEXT.get(o, ""), ENDING_EXTRA.get(k, "")],
		"record": "기록책에 새로 적힌 이름 — 곽칠성.",
	}
