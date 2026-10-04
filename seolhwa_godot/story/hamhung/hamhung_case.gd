# 사건 「돌아오지 않는 전갈」 — 데이터로 쓰기 번거로운 장면(R05 날씨 단계·노정 사건 넷, 함흥 도착·공간 넘기, 북청길 눈보라·구조·수레 싸움,
# 역참 재회와 방 조사형 대화, 결말·남쪽 뱃길)과 기록책·결말 카드. 데이터(hamhung_data.gd)의 { "call": "이름" }과 조건식 fn('이름')이 부른다.
extends RefCounted

const D := preload("res://story/hamhung/hamhung_data.gd")
const Progress := preload("res://scripts/region/progress.gd")
const Travel := preload("res://scripts/region/travel.gd")
const Discovery := preload("res://scripts/region/discovery.gd")
const Docs := preload("res://scripts/story/documents.gd")
const CASE_TITLE := "돌아오지 않는 전갈"

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
func space() -> String: return d.space_id
func resolved() -> bool: return String(S.vars.get("CASE_HAMHUNG_OUTCOME", "")) != ""
func active() -> bool: return f("case_started") and S.phase != "done"
func px() -> float: return d.main.player_pos.x
func glance(t: String) -> void: d.ui.caption(t, 2.4)   # 조작을 막지 않는 한 줄

# ---------------------------------------------------------------------------
# 공간마다 세계 상태(날씨·불빛·데칼)를 다시 건다
# ---------------------------------------------------------------------------
func on_load() -> void:
	match space():
		D.RT5:
			if r05_on():
				flag("r05_started")
				_r05_stage = ""
				_r05_weather(0.0)
		D.RTB:
			var w = d.world
			if f("case_started"):
				w.set_prop_state("rt_sc_yeokcham_lamp", "USED")
				w.set_prop_state("rt_sc_yeokcham_hwaro", "USED")
				if f("tracks_seen") and w.get("decals") != null: w.decals.set_group_visible("s6004_tracks", true)
			if active() and f("rtb_arrived"): _rtb_weather(0.0)
			if f("master_met") and d.actors.has("yigyeom"): d.actors.yigyeom.name = "이겸"
			if f("gapsul_saved"): d.show_actor("gapsul", false)

# ---------------------------------------------------------------------------
# R05 평양→함흥 — 처음 지날 때만(평양 사건 뒤). 날씨가 단계로 나빠지고 고갯마루에서 눈보라. 한 번 지나면 보통 날씨
# ---------------------------------------------------------------------------
func r05_on() -> bool:
	return not f("r05_done")
func r05_active_ever() -> bool:
	return f("r05_started")

var _r05_stage := ""
var _amb_t := 0.0
const R05_STAGES := [[-420.0, "cloudy"], [-260.0, "wind"], [-140.0, "snow"], [120.0, "blizzard"], [INF, "snow"]]
static func r05_stage_at(x: float) -> String:
	for s in R05_STAGES:
		if x < float(s[0]): return String(s[1])
	return "snow"

func _r05_weather(fade: float) -> void:
	var k := r05_stage_at(px())
	if k == _r05_stage: return
	var first := _r05_stage == ""
	_r05_stage = k
	d.main.weather.force(k, -1.0, fade)
	d.runner.log_line("weather", [k, snappedf(px(), 1.0)])
	if first: return
	match k:
		"wind": d.ui.toast("바람이 일었다. 하늘이 낮다.", "info")
		"snow": d.ui.toast("눈발이 굵어진다.", "info")
		"blizzard":
			if not f("r05_blizzard_seen"):
				flag("r05_blizzard_seen")
				d.ui.toast("눈보라. 한 치 앞이 하얗다.", "info")

func _rtb_weather(fade: float) -> void:
	var k := "snow" if px() < -345.0 else "blizzard"
	if k == _r05_stage: return
	_r05_stage = k
	d.main.weather.force(k, -1.0, fade)

func ambient(dt: float) -> void:
	_amb_t -= dt
	if _amb_t > 0.0: return
	_amb_t = 0.4
	match space():
		D.RT5:
			if not r05_on() or not f("r05_started"): return
			_r05_weather(30.0)
			if absf(px() - D.PASS_X) < 30.0 and not f("r05_pass"):
				flag("r05_pass")
				d.journal_note("양덕 고갯마루 — 눈보라")
			if f("r05_pass") and absf(px()) > 560.0 and not d.runner.busy:
				flag("r05_done")
				d.main.weather.release(20.0)
				d.ui.toast("눈발이 가늘어진다.", "info")
				d.runner.log_line("r05", "done")
				S.save()
		D.RTB:
			if active() and f("rtb_arrived") and not f("station_entered"): _rtb_weather(20.0)

# ---------------------------------------------------------------------------
# R05 노정 사건 넷
# ---------------------------------------------------------------------------
func r05_horse() -> void:
	await d.ui.examine("쓰러진 짐말", ["길가 눈 속에 짐말이 쓰러져 있다. 굳은 지 오래지 않다.", "길마만 남았다. 짐은 누가 벗겨 갔다."], "clue")
	if bool(S.vars.get("SKILL_BEAST_TRACE", false)):
		await d.ui.examine("말 둘레의 눈", ["짐승 발자국도, 물어뜯은 자국도 없다.", "발굽이 얼음에 미끄러져 긁힌 자국뿐. 범이 아니라 추위다.", "짐을 벗겨 간 것은 짚신 발자국 — 사람이다."], "clue")
		flag("r05_horse_read")
	else:
		await d.ui.caption("말 둘레에 이런저런 자국이 있지만 눈에 덮여 무엇인지 모르겠다.", 2.4)
	d.learn_clue("r05_horse")

func r05_sign() -> void:
	flag("r05_sign_seen")
	await d.ui.examine("이정표", ["'양덕 →'이 큰길이 아니라 북쪽, 무너진 원터 쪽을 가리킨다.", "기둥 밑동의 언 흙이 새로 갈라져 있다. 바람이 돌린 게 아니다.",
		"바퀴 자국과 돌무더기는 동쪽 고갯길로 이어진다."], "clue")
	d.learn_clue("r05_sign")
	var i: int = await d.ui.choice("", [{ label = "이정표를 바로 돌려 세운다" }, { label = "그대로 둔다" }])
	flag("r05_sign_done")
	if i == 0:
		flag("r05_sign_fixed")
		await d.ui.caption("기둥을 뽑아 바로 꽂고 흙을 밟아 다진다. '양덕 →'이 고갯길을 가리킨다.", 2.6)
		d.journal_note("신창 갈림길 — 돌아간 이정표를 바로 세웠다")
	else:
		d.journal_note("신창 갈림길 — 누가 이정표를 돌려놓았다")

func r05_luggage() -> void:
	await d.ui.examine("눈 둔덕", ["눈 둔덕 위로 멜빵 한 가닥이 삐져나와 있다."], "clue")
	var i: int = await d.ui.choice("", [{ label = "눈을 파 본다" }, { label = "그만둔다" }])
	if i != 0: return
	await d.ui.examine("눈에 묻힌 봇짐", ["봇짐 하나. 언 주먹밥, 짚신 한 켤레.", "쪽지 — '고원 주막 — 김 서방'."], "item")
	d.give(D.LUGGAGE)
	d.learn_clue("r05_luggage")

func r05_tracks() -> void:
	await d.ui.examine("갈라진 발자국", ["발자국이 여기서 세 갈래로 갈라진다 — 고원으로 내려가는 길, 북쪽 비탈, 남쪽 골짜기."], "clue")
	if bool(S.vars.get("SKILL_BEAST_TRACE", false)):
		await d.ui.examine("발자국 읽기", ["북쪽·남쪽 두 줄은 걸음이 점점 짧아지다 제자리에서 돌아섰다. 길을 찾다 되돌아온 걸음이다.",
			"같은 짚신 셋이 길로 다시 모여 고원 쪽으로 갔다.", "사람을 따라붙은 짐승 발자국은 없다."], "clue")
		flag("r05_tracks_read")
	else:
		await d.ui.caption("어느 줄이 어디로 갔는지 눈에 반쯤 덮여 읽기 어렵다. 고원 쪽 길에 발자국이 가장 많다.", 2.6)
	d.learn_clue("r05_tracks")

func gowon_talk() -> void:
	if S.has(D.LUGGAGE):
		await d.ui.say("김 서방", ["내 봇짐! 고개에서 눈에 파묻고 왔는데. 살자고 버렸소."])
		d.take(D.LUGGAGE)
		flag("r05_returned")
		await d.ui.say("김 서방", ["엽전 몇 닢이라도 받으시오. 함흥 가는 길이면 함관령은 해 있을 때 넘으시오."])
		d.give(D.COIN, 3)
		return
	if f("r05_returned"):
		await d.ui.say("김 서방", ["봇짐 덕에 짚신을 갈아 신었소."]); return
	await d.ui.say("김 서방", ["고개에서 짐을 버리고 왔소. 셋이 길을 나눠 찾다가 다시 만났지."])

# ---------------------------------------------------------------------------
# S6001 함흥 동문 밖(먼 곳에 닿았으면 암전 한 번으로 — §36.2 이동거리 축소)
# ---------------------------------------------------------------------------
func arrival() -> void:
	flag("arrived")
	d.cutscene(true)
	var far := Vector2(px(), d.main.player_pos.z).distance_to(d.anchor("clerk_spot")) > 300.0
	if far:
		await d.ui.fade(true, 0.6)
		d.teleport_to("hg_arrive", "left")
		await wait_loaded(10.0)
		await d.ui.fade(false, 0.6)
		await d.ui.caption("경흥대로 끝, 함흥. 성천강을 건너 동문 밖 역참 마당에 닿았다.", 2.6)
	d.camera({ "focus": "clerk_spot", "distance": 22.0, "pitch": 34.0 })
	await d.ui.caption("역참 마당에 사람들이 모여 북쪽 고개를 본다. 아전 하나만 웃지 않는다.", 2.6)
	d.camera(null)
	d.cutscene(false)
	if not S.has("ITM_TOOL_009"):
		for it in [["ITM_TOOL_009", 1], ["ITM_WPN_001", 1], ["ITM_WPN_002", 1], ["ITM_AMMO_001", 12], ["COIN", 8]]: d.give(it[0], it[1], true)
	if Vector2(px(), d.main.player_pos.z).distance_to(d.anchor("clerk_spot")) > 4.0:
		d.teleport_to(Vector2(d.anchor("clerk_spot").x + 1.0, d.anchor("clerk_spot").y + 2.0), "up")

func start_case() -> void:
	if f("case_started"): return
	flag("case_started")
	S.seen["S6001"] = true
	if S.phase == "start": S.phase = "explore"
	d.learn_clue("three_couriers")
	d.ui.toast("새 사건 — 「%s」" % CASE_TITLE, "journal")
	d.journal_note("함흥에서 북청으로 보낸 전갈꾼 셋이 돌아오지 않았다")

func wait_loaded(limit: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		await d.get_tree().process_frame
		var w = d.main.world
		var c: Vector2i = w.tile_of(d.main.player_pos.x, d.main.player_pos.z)
		if not w.scatter_busy_near(c, 1) and not d.main.placement.busy_near(c, 1): break
	d.main.player_pos.y = d.world.height_at(d.main.player_pos.x, d.main.player_pos.z)

func offer_travel() -> void:
	var i: int = await d.ui.choice("", [{ label = "북청길로 간다 (함관령)" }, { label = "그만 가 보겠소." }])
	if i == 0: await go_bukcheong()

func go_bukcheong() -> void:
	flag("to_bukcheong")
	var pt = _portal_to(D.RTB)
	if pt == null:
		d.ui.toast("길이 아직 닦이지 않았다", "info"); return
	await d.ui.fade(true, 0.7)
	d.set_hour(d.main.hour + 1.0)
	S.time = d.main.hour
	S.save()   # 대본 시험에서도 공간을 넘어 이어 가도록
	d.runner.log_line("travel", [D.RTB])
	d.main._travel(pt)

func go_hamhung() -> void:
	var pt = _portal_to(D.HG)
	if pt == null: return
	S.time = d.main.hour
	S.save()
	d.main._travel(pt)

func _portal_to(target: String):
	for pt in d.main.portals:
		if String(pt.get("target", "")) == target: return pt
	return null

func clerk_done() -> void:
	var o := String(S.vars.get("CASE_HAMHUNG_OUTCOME", ""))
	await d.ui.say("역참 아전", { "A": ["셋 다 돌아왔소. 이번엔 아무도 함흥차사 소리를 못 하겠지."],
		"B": ["둘이 돌아왔소. …하나는 우리가 늦었소."], "C": ["순돌이 하나 돌아왔소. 나머지는 장정들이 아직 찾고 있소."] }.get(o, ["북청길은 눈이 그쳐야 다니오."]))

func town_done() -> void:
	var o := String(S.vars.get("CASE_HAMHUNG_OUTCOME", ""))
	await d.ui.say("장꾼", ["함흥차사 소리는 이제 안 하오."] if o == "A" else ["농담 삼아 한 말이 이리 될 줄은 몰랐소."])

# ---------------------------------------------------------------------------
# 북청길 — 함관령 눈보라
# ---------------------------------------------------------------------------
func rtb_arrival() -> void:
	flag("rtb_arrived")
	_r05_stage = ""
	_rtb_weather(0.0)
	d.set_hour(maxf(d.main.hour, 12.0))
	d.cutscene(true)
	await d.ui.caption("북청길. 함관령 오르는 길이 눈보라에 지워진다.", 2.6)
	d.cutscene(false)
	d.journal_note("함관령 — 눈보라")

func take_pouch() -> void:
	await d.ui.examine("길 위의 주머니", ["감영 인이 찍힌 가죽 주머니. 안에 봉한 전갈.", "길 아래 골짜기로 비틀거린 발자국이 내려간다. 눈이 벌써 덮어 간다."], "item")
	d.give(D.POUCH)
	d.learn_clue("pouch")
	d.learn_rule("R_SNOW_COVERS")
	d.journal_note("함관령 길 위 — 감영 전갈 주머니. 발자국이 골짜기로")

# S6002 막동 — 살아 있다. 업어 서낭당 돌담 밑 불 곁으로
func rescue_madong() -> void:
	d.cutscene(true)
	await d.ui.caption("소나무 밑에 사내 하나가 웅크려 있다. 숨은 붙어 있다.", 2.4)
	await d.ui.say("막동", ["…주머니… 감영 주머니를…"])
	var i: int = await d.ui.choice("", [{ label = "업어서 서낭당 돌담 밑으로 옮긴다" }, { label = "조금만 기다리시오." }])
	if i != 0:
		d.cutscene(false); return
	await d.ui.fade(true, 0.7)
	flag("madong_saved")
	S.seen["S6002"] = true
	d.teleport_to(Vector2(d.anchor("shrine_rest").x - 1.4, d.anchor("shrine_rest").y + 0.4), "right")
	await wait_loaded(6.0)
	await d.ui.fade(false, 0.7)
	await d.ui.caption("서낭당 돌담 밑, 바람이 덜 드는 자리에 불을 피웠다. 막동의 입술에 핏기가 돈다.", 2.6)
	await d.ui.say("막동", ["주머니를 떨궈 주우러 돌아섰다가 길을 잃었소.", "갑술이랑 순돌이는 수레를 따라 고개를 넘었소."])
	if S.has(D.POUCH): await d.ui.say("막동", ["그 주머니, 감영 것이오. 가지고 계시오. 내 발로는 못 가오."])
	d.learn_clue("madong")
	d.cutscene(false)

func pass_post() -> void:
	var lines := ["서낭당 돌무더기 곁 표목이 고개 북쪽 옛 숲길을 가리킨다. 큰길은 동쪽이다.", "밑동 언 흙이 새로 갈라졌다. 누가 돌려놓았다."]
	if f("r05_sign_seen"): lines.append("양덕 고개의 이정표와 같은 솜씨다.")
	await d.ui.examine("함관령 표목", lines, "clue")
	d.learn_clue("turned_post")
	if f("r05_sign_seen") or f("cart_looked"): d.learn_rule("R_TURNED_SIGN")

# S6003 수레 약탈 — 사람 도적 둘과 짧은 싸움(경주 사람 적 전투 모듈)
func cart_fight() -> void:
	flag("cart_seen")
	d.cutscene(true)
	d.teleport_to(Vector2(d.anchor("cart_arena").x - 7.0, d.anchor("cart_arena").y + 1.0), "right")
	d.camera({ "focus": "cart", "distance": 20.0, "pitch": 38.0 })
	await d.ui.caption("고개 넘어 길가. 수레가 엎어져 있고, 사내 둘이 터진 가마니를 뒤진다.", 2.6)
	await d.ui.caption("수레 곁에 사람 하나가 묶여 있다. 붉은 띠 — 역졸이다.", 2.2)
	d.camera(null)
	d.learn_clue("cart_raided")
	S.seen["S6003"] = true
	d.cutscene(false)
	var res: String = await d.combat("cart", { "allow_flee": true })
	d.runner.last["fight"] = res
	flag("cart_fought")
	flag("fight_result", res)
	var rep: Array = d.combat_view.human_report()
	var caught := 0
	for r in rep:
		if String(r.out) == "down": caught += 1
	if caught > 0: flag("raider_caught")
	d.runner.log_line("fight", [res, rep.map(func(r): return [r.id, r.out])])
	match res:
		"lose", "escaped":
			if res == "lose":
				await d.ui.fade(true, 0.8)
				d.end_combat()
				d.teleport_to(Vector2(d.anchor("cart_arena").x - 6.0, d.anchor("cart_arena").y + 2.0), "right")
				await d.wait(0.6)
				await d.ui.fade(false, 0.8)
				await d.ui.caption("정신을 차리니 수레 곁이 비어 있다.", 2.2)
			else:
				await d.ui.caption("물러섰다. 사내들이 묶인 역졸을 일으켜 세운다.", 2.2)
			d.end_combat()
			flag("gapsul_taken")
			d.show_actor("gapsul", false)
			d.learn_clue("gapsul_taken")
			await d.ui.caption("도적들은 역졸을 끌고 고개 북쪽 숲으로 사라졌다. 끌린 자국이 눈에 남았다.", 2.8)
			d.journal_note("수레 곁 역졸(갑술)이 끌려갔다")
		_:
			await d.ui.caption("둘 다 쓰러졌다. 허리끈으로 손을 묶었다." if caught == 2 else ("하나는 쓰러졌고, 하나는 고개 북쪽 숲으로 달아났다." if caught == 1 else "둘 다 가마니를 버리고 숲으로 달아났다."), 2.4)
			await d.ui.fade(true, 0.4)
			d.end_combat()
			await d.ui.fade(false, 0.4)
	d.mark_dirty()

func free_gapsul() -> void:
	d.cutscene(true)
	await d.ui.caption("수레 곁 역졸의 손목 끈을 끊는다.", 2.0)
	d.anim_actor("gapsul", "idle")
	await d.ui.say("갑술", ["…고맙소. 표목을 따라 숲길로 들었다가 저놈들한테 걸렸소.", "순돌이는 북쪽 숲으로 뛰었소. 그 애 발이 젖어 있었는데."])
	flag("gapsul_saved")
	d.learn_clue("gapsul")
	d.cutscene(false)
	d.ui.toast("갑술이 서낭당 쪽으로 비틀비틀 내려간다.", "info")
	d.move_actor("gapsul", ["shrine_rest"], 1.6, "walk", "idle")
	_hide_later("gapsul", 9.0)

func _hide_later(id: String, sec: float) -> void:
	await d.get_tree().create_timer(sec, true, false, true).timeout
	if d.S != null and d.actors.has(id):
		flag("gapsul_gone")
		d.show_actor(id, false)

func look_cart() -> void:
	flag("cart_looked")
	await d.ui.examine("엎어진 수레", ["구휼미 가마니. 끌채 끈은 칼로 끊겼다.", "수레는 큰길이 아니라 표목이 가리킨 옛 숲길 들머리에서 엎어졌다."], "clue")
	if S.has_clue("turned_post"): d.learn_rule("R_TURNED_SIGN")

# S6004 숲으로 간 발자국 — 숲 위 불빛
func tracks() -> void:
	flag("tracks_seen")
	S.seen["S6004"] = true
	var w = d.world
	if w.get("decals") != null: w.decals.set_group_visible("s6004_tracks", true)
	w.set_prop_state("rt_sc_yeokcham_lamp", "USED")
	w.set_prop_state("rt_sc_yeokcham_hwaro", "USED")
	d.set_hour(maxf(d.main.hour, 16.8))
	d.cutscene(true)
	d.camera({ "focus": "station_door", "distance": 34.0, "pitch": 30.0 })
	await d.ui.caption("길에서 북쪽 숲으로 발자국 둘. 끌리듯 걷는 짚신 하나, 곁을 받치는 가죽신 하나.", 2.8)
	await d.ui.caption("숲 위, 무너진 마구간 너머에 불빛이 하나.", 2.4)
	d.camera(null)
	d.cutscene(false)
	d.learn_clue("tracks")

# ---------------------------------------------------------------------------
# S6005~S6006 역참 — 불빛·벽 지도·불탄 기록·종이를 태우는 노인 / "그 책 아직 갖고 있었구나."
# ---------------------------------------------------------------------------
func enter_station() -> void:
	flag("station_entered")
	S.seen["S6005"] = true
	S.phase = "station"
	d.on_phase()
	d.cutscene(true)
	await d.ui.fade(true, 0.6)
	d.teleport_to("room_in", "left")
	d.place_actor("yigyeom", "yg_spot", null, "right")
	d.anim_actor("yigyeom", "burn")
	await d.wait(0.3)
	await d.ui.fade(false, 0.6)
	await d.ui.caption("등잔불. 벽에 지도 한 장. 바닥에 그을린 종이 더미.", 2.4)
	await d.ui.caption("화로 곁에 노인 하나가 종이를 한 장씩 불에 넣는다. 화로 저편에 젊은 역졸 하나가 떨며 누워 있다.", 3.0)
	d.learn_clue("station")
	# S6006 — 노인이 기록책을 본다. 긴 컷신 없음
	d.face_actor("yigyeom", null, "player")
	d.anim_actor("yigyeom", "sit")
	await d.ui.caption("노인의 눈이 나그네의 기록책에 머문다.", 2.0)
	await d.ui.say("노인", ["그 책 아직 갖고 있었구나."])
	flag("master_met")
	S.seen["S6006"] = true
	d.actors.yigyeom.name = "이겸"
	var parts := Array(String(S.vars.get("MAIN_MASTER_TRACE", "")).split(",", false))
	if not parts.has("HAMHUNG"): parts.append("HAMHUNG")
	S.vars["MAIN_MASTER_TRACE"] = ",".join(PackedStringArray(parts))
	Progress.set_var("MAIN_MASTER_TRACE", S.vars.MAIN_MASTER_TRACE)
	d.runner.log_line("var", ["MAIN_MASTER_TRACE", S.vars.MAIN_MASTER_TRACE])
	d.face_actor("yigyeom", "right", null)
	d.anim_actor("yigyeom", "burn")
	d.cutscene(false)
	d.journal_note("함관령 옛 역참 — 스승을 찾았다")
	d.ui.toast("방을 둘러볼 수 있다", "info")

func tend_sundol() -> void:
	var i: int = await d.ui.choice("", [{ label = "젖은 버선을 벗기고 발을 주무른다" }, { label = "그만둔다" }])
	if i != 0: return
	await d.ui.fade(true, 0.5)
	flag("sundol_tended")
	d.anim_actor("sundol", "sit")
	await d.ui.fade(false, 0.5)
	await d.ui.say("순돌", ["숲에서 쓰러졌는데 저 어른이 업어 왔소.", "사흘째 저 종이를 태워 불을 지피셨소."])
	d.learn_clue("sundol")
	await d.ui.caption("노인은 말없이 종이 한 장을 더 불에 넣는다.", 2.2)

# S6007 방 조사형 대화 — 물건마다 짧게. 불탄 장부의 朴은 플레이어가 먼저 찾아야 이겸이 말한다
func room_ledger() -> void:
	S.seen["S6007"] = true
	if not f("ledger_opened"):
		flag("ledger_opened")
		await d.ui.examine("불탄 장부", ["반쯤 탄 곡물 장부. 가장자리가 숯이 되어 부스러진다."], "clue")
	# 문서 살피기(scripts/story/documents.gd): 그을린 가장자리 밑의 朴은 돋보기로 직접 찾는다 — 정답 표시 없음
	await Docs.open(d, { "docs": ["burnt_ledger"], "title": "불탄 장부", "note": "그을린 장부 한 장. 줄과 가장자리를 돋보기로 훑는다." })
	if not S.has_clue("park_ledger"):
		await d.ui.caption("그을음 밑에 무엇이 더 있는지 아직 모르겠다.", 2.0)
		return
	flag("ledger_done")
	S.vars["MAIN_PARK_MARK_COUNT"] = int(S.vars.get("MAIN_PARK_MARK_COUNT", 0)) + 1
	Progress.set_var("MAIN_PARK_MARK_COUNT", S.vars.MAIN_PARK_MARK_COUNT)
	d.runner.log_line("var", ["MAIN_PARK_MARK_COUNT", S.vars.MAIN_PARK_MARK_COUNT])
	await d.ui.say("이겸", ["이제 그 이름이 낯설진 않겠구나."])
	await d.ui.say("이겸", ["저걸 쓴 사람이 죽었다."])
	_room_check()

func room_ham() -> void:
	S.seen["S6007"] = true
	await d.ui.examine("기록함", ["이겸의 옛 기록이 묶여 있다. 서강 창고 사건 — 증인 명단.", "곽칠성. 이름 위에 먹줄이 그어져 있다."], "clue")
	flag("ham_done")
	d.learn_clue("gwak_record")
	await d.ui.say("이겸", ["내 기록 때문에 엉뚱한 사람이 잡혀갔다."])
	_room_check()

func room_map() -> void:
	S.seen["S6007"] = true
	await d.ui.examine("벽 지도", ["지나온 고을마다 작은 표 — 남원, 한양, 강릉, 경주, 황주, 평양.", "한양 서강에만 다른 먹으로 동그라미. 광통교 종이 뒷면의 그 글씨다. 마른 지 오래지 않다."], "clue")
	flag("map_done")
	d.learn_clue("woochi_map")
	await d.ui.say("이겸", ["그놈은 이야기를 만들면 진실도 움직일 수 있다고 했지."])
	_room_check()

func room_done() -> bool:
	return f("ledger_done") and f("ham_done") and f("map_done")

func _room_check() -> void:
	if room_done() and not f("room_hint"):
		flag("room_hint")
		d.ui.toast("스승에게 물을 것이 있다", "info")

# S6008 질문 → S6009 반전 → S6010 제주 단서
func master_talk() -> void:
	if not room_done():
		await d.ui.say("이겸", ["둘러봐라. 본 것은 본 대로."]); return
	var i: int = await d.ui.choice("", [{ label = "왜 돌아오지 않았습니까?" }, { label = "나중에 여쭙겠습니다." }])
	if i != 0: return
	d.cutscene(true)
	d.anim_actor("yigyeom", "sit")
	d.face_actor("yigyeom", null, "player")
	await d.ui.say("이겸", ["돌아가서 뭘 써야 할지 몰랐다."])
	await d.ui.caption("화로에서 불티가 튄다.", 1.6)
	await d.ui.say("이겸", ["그때는 기록을 남기겠다고 산 사람을 너무 늦게 봤다."])
	flag("asked_why")
	S.seen["S6008"] = true
	d.learn_rule("R_RESCUE_FIRST")
	# S6009 — 이겸과 우치는 추적자와 범인이 아니었다
	await d.ui.say("나그네", ["우치는 선생님을 압니다."])
	await d.ui.say("이겸", ["열두 해 전, 그놈과 나는 같은 일을 맡았다. 쫓고 쫓기는 사이가 아니었다."])
	await d.ui.examine("서강 창고 — 열두 해 전", ["강복이라는 짐꾼이 장부와 곡식이 맞지 않는 것을 찾았다. 창고에 불이 났고 강복이 죽었다.",
		"이겸은 사람의 짓을 의심했고, 우치는 범인을 끌어내려 가짜 귀신 소동을 벌였다. 사람이 몰려 다쳤다.",
		"관아는 서둘러 덮었다. 곽칠성이 죄를 쓰고, 이겸의 기록 일부는 빼앗겼다. 둘은 크게 다퉜다.",
		"그러나 강복이 죽은 뒤 설명되지 않는 일도 있었다고 한다."], "clue")
	d.learn_clue("past_event")
	S.vars["MAIN_PAST_EVENT_KNOWN"] = true
	S.seen["S6009"] = true
	# S6010 — 곽칠성은 제주로
	await d.ui.say("이겸", ["곽칠성은 제주로 갔다. 귀양이었다."])
	await d.ui.caption("노인이 오래 화로를 본다.", 1.6)
	await d.ui.say("이겸", ["내가 가야 했는데 못 갔다."])
	await d.ui.caption("노인이 기록 한 묶음을 내민다. 나그네는 그것을 기록책 사이에 챙긴다.", 2.6)
	d.give(D.RECORD)
	d.learn_clue("gwak_jeju")
	S.vars["MAIN_MASTER_FOUND"] = true
	for k in ["MAIN_MASTER_FOUND", "MAIN_PAST_EVENT_KNOWN"]:
		Progress.set_var(k, true)
		d.runner.log_line("var", [k, true])
	Discovery.tell(Discovery.NATION, "region:JJ_JEJU")   # 전국 지도에 제주(들음)
	S.seen["S6010"] = true
	d.journal_note("곽칠성 — 제주로 귀양. 다음은 제주다")
	await resolve()

# ---------------------------------------------------------------------------
# 결말 — 몇 사람이 돌아왔나(§29: 놓친 사람도 기록·소문·지역 변화로 남는다)
# ---------------------------------------------------------------------------
func saved_count() -> int:
	return 1 + (1 if f("madong_saved") else 0) + (1 if f("gapsul_saved") else 0)

func resolve() -> void:
	var n := saved_count()
	var o: String = ["C", "B", "A"][n - 1]
	var detail := o
	if o == "B": detail = "B_madong" if not f("madong_saved") else "B_gapsul"
	S.vars["CASE_HAMHUNG_OUTCOME"] = o
	S.vars["CASE_HAMHUNG_DETAIL"] = detail
	d.runner.log_line("outcome", detail)
	flag("resolved")
	await d.ui.fade(true, 0.8)
	S.phase = "done"
	d.on_phase()
	d.set_hour(7.0)
	d.main.weather.release(0.0)
	d.main.weather.force("snow", 60.0, 0.0)
	d.anim_actor("yigyeom", "write")
	await d.ui.fade(false, 0.8)
	await d.ui.caption(ENDING_EXTRA[detail], 3.0)
	d.cutscene(false)
	d.journal_note("사건 종결 — 「%s」" % CASE_TITLE)
	await d.show_ending()
	await d.ui.caption("제주 가는 배는 해남 관두포에서 뜬다. 남해 뱃길은 남원 남쪽 끝에서 시작한다.", 3.0)
	d.save()

# 끝난 뒤 이겸 — 남쪽 뱃길(§18: 함흥 → 지나온 노정 빠른 이동 → 남부 출항 노정. 제주 뱃길 첫 건넘은 건너뛰지 못한다)
func master_done() -> void:
	await d.ui.say("이겸", ["제주 가는 배는 관두포에서 뜬다. 바람을 기다려야 할 게다.", "나는 이 사람들을 함흥까지 데려다 놓고 따라가마."])
	var ok := fast_south_ok()
	var i: int = await d.ui.choice("", [{ label = "남해 뱃길로 떠난다 (역마로 한양·남원을 거쳐)", disabled = not ok, hint = "지나온 길을 거슬러 남원까지 가야 한다." },
		{ label = "조금 더 있겠습니다." }])
	if i == 0 and ok: await go_south()

func fast_south_ok() -> bool:
	var to_hanyang: bool = Progress.route_done("GG_HANYANG-HG_HAMHEUNG") or \
		(Progress.route_done(D.RT5) and Progress.route_done("HH_HWANGJU-PA_PYEONGYANG") and Progress.route_done("GG_HANYANG-HH_HWANGJU"))
	return to_hanyang and Progress.route_done("JL_NAMWON_UNBONG-GG_HANYANG")

func south_target() -> Dictionary:
	for r in Travel.routes():
		if String(r.id) != D.SOUTH_ROUTE: continue
		var e: Vector2 = Travel.route_ends(r.json).from
		return { id = "hamhung_south", kind = "route", target = D.SOUTH_ROUTE, tx = e.x, tz = e.y, label = "남해 뱃길 들머리 (역마)", fast = true }
	return {}

func go_south() -> void:
	var pt := south_target()
	if pt.is_empty():
		d.ui.toast("길이 아직 닦이지 않았다", "info"); return
	await d.ui.caption("역마를 갈아타며 한양을 지나 남원 남쪽 끝까지 내려간다.", 2.4)
	S.time = d.main.hour
	S.save()
	d.runner.log_line("travel", [D.SOUTH_ROUTE])
	d.main._travel(pt)

# ---------------------------------------------------------------------------
# 사건 기록(R)
# ---------------------------------------------------------------------------
const OUTCOME_TEXT := {
	"A": "함관령 눈보라 속에서 막동을 찾아 불 곁에 눕혔고, 고개 넘어 수레에서 도적을 물리쳐 갑술을 풀었다. 순돌은 옛 역참에서 스승이 살려 두었다. 셋 다 함흥으로 돌아왔다.",
	"B_madong": "고개 넘어 수레에서 갑술을 풀었고, 순돌은 옛 역참에서 스승이 살려 두었다. 길 아래 골짜기로 내려간 막동의 발자국은 그사이 눈에 덮였다.",
	"B_gapsul": "눈보라 속에서 막동을 찾아 불 곁에 눕혔고, 순돌은 옛 역참에서 스승이 살려 두었다. 수레 곁의 갑술은 도적들이 끌고 갔다.",
	"C": "옛 역참에서 스승이 살려 둔 순돌만 돌아왔다. 막동의 발자국은 눈에 덮였고, 갑술은 도적들이 끌고 갔다.",
}
const ENDING_EXTRA := {
	"A": "눈이 그친 아침, 세 전갈꾼이 함흥 동문으로 들어갔다. 사람들은 더는 함흥차사라고 웃지 않는다.",
	"B_madong": "눈이 그친 뒤 함흥 장정들이 골짜기에서 막동을 찾았을 때는 늦었다. 동문 밖 그의 집 앞에 물 한 그릇이 놓였다.",
	"B_gapsul": "함흥 관아가 고개 북쪽 숲으로 사람을 풀었다. 갑술의 소식은 아직 없다.",
	"C": "눈이 그친 뒤 함흥 장정들이 막동을 찾았을 때는 늦었다. 관아는 고개 북쪽 숲에서 갑술을 찾는 중이다.",
}

func solutions() -> Array:
	return [
		{ "id": "madong", "title": "막동을 찾는다", "available": f("madong_saved"),
			"text": "길 위의 주머니에서 골짜기로 내려간 발자국을 따라가 막동을 불 곁으로 옮긴다.",
			"hint": "발자국이 눈에 덮이기 전에." if S.has_clue("pouch") and not f("madong_saved") and not f("station_entered") else "" },
		{ "id": "gapsul", "title": "갑술을 구한다", "available": f("gapsul_saved"),
			"text": "고개 넘어 수레에서 도적을 물리치고 묶인 갑술을 푼다.", "hint": "도적들이 끌고 갔다." if f("gapsul_taken") else "" },
		{ "id": "station", "title": "숲 위 불빛으로 간다", "available": f("tracks_seen"),
			"text": "숲으로 간 발자국 둘을 따라 옛 역참으로.", "hint": "" },
	]

func summary() -> Array:
	var p := []
	p.append("함흥에서 북청으로 보낸 전갈꾼 셋 — 막동·갑술·순돌 — 이 사흘째 돌아오지 않는다. 사람들은 '함흥차사'라고 웃는다.")
	if S.has_clue("pouch"): p.append("함관령 길 위에 감영 전갈 주머니. 발자국이 골짜기로 내려갔다.")
	if f("madong_saved"): p.append("막동을 찾아 서낭당 돌담 밑 불 곁에 눕혔다.")
	if S.has_clue("cart_raided"): p.append("고개 넘어 엎어진 구휼미 수레. 끌채 끈은 칼로 끊겼다.")
	if f("gapsul_saved"): p.append("수레 곁에 묶인 갑술을 풀었다.")
	elif f("gapsul_taken"): p.append("도적들이 갑술을 끌고 고개 북쪽 숲으로 사라졌다.")
	if S.has_clue("tracks"): p.append("숲으로 간 발자국 둘. 숲 위에 불빛.")
	if f("master_met"): p.append("함관령 옛 역참에서 스승 이겸을 찾았다. 제 기록을 태워 순돌을 살리고 있었다.")
	if bool(S.vars.get("MAIN_PAST_EVENT_KNOWN", false)): p.append("열두 해 전 서강 창고 — 이겸과 우치는 같은 일을 맡았었다. 곽칠성은 제주로 귀양 갔다.")
	var o := String(S.vars.get("CASE_HAMHUNG_DETAIL", ""))
	if o != "":
		p.append(OUTCOME_TEXT.get(o, ""))
		p.append(ENDING_EXTRA.get(o, ""))
	return p

func journal() -> Dictionary:
	if not f("case_started"):
		return { "cases": [], "empty": "아직 함흥에서 적힌 사건이 없다." }
	var clues := []
	for id in S.clues:
		var c: Dictionary = d.data.clues.get(id, { "title": id, "text": "" })
		clues.append({ "title": c.title, "text": c.text, "kind": c.get("kind", "fact"), "by": c.get("by", "") })
	var rules := []
	for id in S.rules:
		var r: Dictionary = d.data.rules.get(id, { "title": id, "text": "" })
		rules.append({ "title": r.title, "text": r.text })
	var solved: bool = resolved() and S.phase == "done"
	return { "cases": [{ "id": "hamhung", "title": CASE_TITLE, "status": "solved" if solved else "active", "rules_title": "눈길에서 본 것",
		"summary": summary(), "clues": clues, "rules": rules, "solutions": solutions(), "notes": S.notes }] }

func ending_data() -> Dictionary:
	var o := String(S.vars.get("CASE_HAMHUNG_DETAIL", "A"))
	var k := String(S.vars.get("CASE_HAMHUNG_OUTCOME", "A"))
	return {
		"case_title": CASE_TITLE,
		"title": { "A": "돌아온 전갈", "B": "늦은 전갈", "C": "하나만 돌아온 전갈" }[k],
		"outcome": k,
		"paragraphs": [OUTCOME_TEXT.get(o, ""), ENDING_EXTRA.get(o, "")],
		"record": "스승을 찾았다. 곽칠성 — 제주.",
	}
