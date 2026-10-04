# 사건 「강을 판 사내」 — 데이터로 쓰기 번거로운 장면(도착·나루 다툼·문서 비교·종이 마당 대면과 싸움·기록 창고·부벽루·문서 감정·결말)
# 과 기록책·결말 카드. 데이터(pyongyang_data.gd)의 { "call": "이름" }과 조건식 fn('이름')이 부른다.
# 문서 비교·감정 화면은 scripts/story/documents.gd(데이터 documents), 사람 싸움은 combat_view(arenas.hideout — chuman.gd)가 맡는다.
extends RefCounted

const D := preload("res://story/pyongyang/pyongyang_data.gd")
const Docs := preload("res://scripts/story/documents.gd")
const Progress := preload("res://scripts/region/progress.gd")
const CASE_TITLE := "강을 판 사내"
const STORE := "py_sc_girokgo"

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
func resolved() -> bool: return String(S.vars.get("CASE_PYONGYANG_OUTCOME", "")) != ""
func night_now() -> bool: return d.main.hour >= 19.5 or d.main.hour < 5.0
func caught_any() -> bool: return f("caught_a") or f("caught_b")
func cmp_count() -> int:
	var n := 0
	for c in ["cmp_paper", "cmp_ink", "cmp_seal"]:
		if S.has_clue(c): n += 1
	return n
func skill_found() -> int:
	var n := 0
	for k in Docs.found_list(S):
		if D.SKILL_SPOTS.has(String(k)): n += 1
	return n
func has_pass() -> bool:
	if S.has(D.PASS_DOC): return true
	var hs: Dictionary = Progress.case_state("hanyang")
	return int(hs.get("items", {}).get(D.PASS_DOC, 0)) > 0

func on_load() -> void:
	store_state()
	_place_caught()

func wait_loaded(limit: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		await d.get_tree().process_frame
		var w = d.main.world
		var c: Vector2i = w.tile_of(d.main.player_pos.x, d.main.player_pos.z)
		if not w.scatter_busy_near(c, 1) and not d.main.placement.busy_near(c, 1): break
	d.main.player_pos.y = d.world.height_at(d.main.player_pos.x, d.main.player_pos.z)

func _prop(key: String, state: String) -> void:
	var w = d.world
	if w.has_method("set_prop_state"): w.set_prop_state(key, state)

func _decals(group: String, on: bool) -> void:
	var dc = d.world.get("decals")
	if dc != null: dc.set_group_visible(group, on)

# 기록 창고(world-scenario py_sc_girokgo) — 사건 진행에 따라 살창·문·안의 소품·발자국
func store_state() -> void:
	var done: bool = S.phase == "done"
	var hit: bool = f("alarm")
	_prop(STORE + "/window", "BROKEN" if hit and not done else "SEALED")
	_prop(STORE + "/door", "OPEN" if f("store_open") else "SEALED")
	_prop(STORE + "_ham_1", "MOVED" if hit and not done else "SEALED")
	_prop(STORE + "_jangbu", "MOVED" if hit and not done else "NORMAL")
	_prop(STORE + "_shelf", "EMPTY" if hit else "NORMAL")
	_decals("s5004_tracks", S.has_clue("window") and not done)

func _place_caught() -> void:
	if f("alarm"): return
	if f("caught_a"): d.place_actor("sw_a", "tied_spot", null, "down"); d.anim_actor("sw_a", "tied")
	if f("caught_b"): d.place_actor("sw_b", "tied_b", null, "down"); d.anim_actor("sw_b", "tied")

func _travel_to(at: String, face: String, cap: String) -> void:
	d.cutscene(true)
	await d.ui.fade(true, 0.6)
	d.teleport_to(at, face)
	await wait_loaded(8.0)
	await d.ui.fade(false, 0.6)
	if cap != "": await d.ui.caption(cap, 2.2)
	d.cutscene(false)

# ---------------------------------------------------------------------------
# S5001 도착·나루 다툼
# ---------------------------------------------------------------------------
func arrival() -> void:
	flag("arrived")
	if d.main.weather != null: d.main.weather.force("clear", 30.0 * 60.0, 0.0); d.main.weather.snow = 0.0
	var far := Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("boatman_spot")) > 300.0
	if far:
		d.cutscene(true)
		await d.ui.fade(true, 0.6)
		d.set_hour(maxf(d.main.hour, 10.0))
		d.teleport_to("naru_arrive", "right")
		await wait_loaded(10.0)
		await d.ui.fade(false, 0.6)
		await d.ui.caption("중화길을 올라 선교 나루에서 강을 건넜다. 대동문 앞 나루가 시끄럽다.", 2.6)
		d.cutscene(false)
	if not S.has("ITM_TOOL_009"):
		for it in [["ITM_TOOL_009", 1], ["ITM_WPN_001", 1], ["ITM_WPN_002", 1], ["ITM_AMMO_001", 12], ["COIN", 8]]: d.give(it[0], it[1], true)

func quarrel() -> void:
	d.cutscene(true)
	d.camera({ "focus": "boatman_spot", "distance": 18.0, "pitch": 34.0 })
	await d.wait(0.3)
	await d.ui.caption("구경꾼  “또 우치 짓이래.”", 1.8)
	d.face_actor("merchant_a", null, "merchant_b"); d.face_actor("merchant_b", null, "merchant_a")
	await d.ui.say("한 객주", ["이 나루 물길은 내가 샀소! 문서가 여기 있지 않소."])
	await d.ui.say("윤 상인", ["무슨 소리. 나도 샀소. 감영 도장까지 찍힌 문서요."])
	d.face_actor("boatman", null, "player")
	await d.ui.say("대동강 사공", ["둘 다 도장이 같으니, 난 누구 짐도 못 싣소."])
	await d.ui.caption("구경꾼  “우치가 강을 팔아먹었다더군.”", 2.0)
	d.camera(null)
	d.cutscene(false)
	start_case()

func start_case() -> void:
	if f("case_started"): return
	flag("case_started")
	S.seen["S5001"] = true
	if S.phase == "start": S.phase = "explore"
	d.learn_clue("two_deeds")
	d.learn_clue("woochi_blamed", true)
	d.ui.toast("새 사건 — 「%s」" % CASE_TITLE, "journal")
	d.journal_note("대동강 나루 — 같은 도장이 찍힌 물길 문서 둘")
	if d.onboard != null: d.onboard.on_case_started()

# ---------------------------------------------------------------------------
# 나루 사람들
# ---------------------------------------------------------------------------
func merchant_talk(w: String) -> void:
	var nm := "한 객주" if w == "a" else "윤 상인"
	var me := "merchant_a" if w == "a" else "merchant_b"
	if f("swindlers_resolved"):
		var l: Array
		if caught_any(): l = ["그놈들이 우치가 아니었다니. 판 돈이나 돌려받았으면 좋겠소."] if w == "a" else ["작달막한 그놈, 말 더듬는 것까지 연기였나 보오."]
		else: l = ["우치든 아니든, 내 백 냥은 강물에 떠내려갔소."] if w == "a" else ["…놓쳤단 말이오? 그 돈이 어떤 돈인데."]
		await d.ui.say(nm, l); return
	if not f("deeds_out"):
		await d.ui.say(nm, ["값 일백 냥을 치르고 산 물길이오. 감영 관인이 보이지 않소?"] if w == "a" else ["나도 일백 냥이오. 도장도 같고, 글도 같소."])
		await R([{ "choice": "", "options": [
			{ "label": "두 문서를 나란히 놓고 봅시다", "do": [{ "call": "lay_out" }] },
			{ "label": "그만 가 보겠소.", "end": true }] }])
		return
	if not S.knows("R_NOT_SAME"):
		await d.ui.say(nm, ["보시오, 같은 도장 아니오!"])
		await R([{ "choice": "", "options": [{ "label": "문서를 다시 견주어 봅시다", "do": [{ "event": "S5002" }] }, { "label": "그만 가 보겠소.", "end": true }] }])
		return
	var seller := "seller_" + w
	if not S.has_clue(seller):
		await d.ui.say("나그네", ["그 문서, 누구에게서 샀소?"])
		await d.ui.say(nm, ["우치라 했소. 키가 크고 턱에 흉이 있었지."] if w == "a" else ["우치? 작달막하고 말을 더듬던데."])
		d.learn_clue(seller)
		if S.has_clue("seller_a") and S.has_clue("seller_b") and not S.knows("R_TWO_SELLERS"):
			d.face_actor(me, null, "merchant_b" if w == "a" else "merchant_a")
			await d.ui.caption("두 상인이 서로를 본다. 같은 '우치'를 말하는 것 같지 않다.", 2.4)
			d.learn_rule("R_TWO_SELLERS")
		return
	await d.ui.say(nm, ["그 흉 있는 놈 잡히면 내 돈부터 받아야지."] if w == "a" else ["말을 그리 더듬던 놈이 셈은 빠르더이다."])

func merchant_done(w: String) -> void:
	var o := String(S.vars.get("CASE_PYONGYANG_OUTCOME", ""))
	if w == "a":
		await d.ui.say("한 객주", ["반이라도 돌려받았으니 됐소. 이제 소금배는 사공 셈으로 싣소."] if o == "A" else ["감영 방 보셨소? 물길은 사고팔 수 없다니. 진작 알았어야지."])
	else:
		await d.ui.say("윤 상인", ["뗏목은 내일 내려오오. 배 대는 값이야 남들 내는 만큼 내야지."])

func lay_out() -> void:
	flag("deeds_out")
	await d.ui.caption("두 상인이 사공의 짐 궤짝 위에 문서를 한 장씩 펼친다.", 2.2)
	await R([{ "event": "S5002" }])

func boatman_talk() -> void:
	if f("swindlers_resolved"):
		await d.ui.say("대동강 사공", ["감영에서 판정이 나기 전엔 어느 짐도 못 싣소."]); return
	if (S.has_clue("seller_a") or S.has_clue("seller_b")) and not S.has_clue("together"):
		await d.ui.say("대동강 사공", ["흉 있는 사내랑 작은 사내? 주막에서 둘이 한 상에 앉던데.", "주모한테 물어보시오."])
		d.learn_clue("together")
		return
	if not f("deeds_out"):
		await d.ui.say("대동강 사공", ["둘 다 도장이 같으니 난 누구 짐도 못 싣소.", "문서를 나란히 놓고 보면 뭐가 다른지 알겠지."])
		return
	await d.ui.say("대동강 사공", ["누구 것이 진짜든, 판 놈부터 찾으시오."])

func boatman_done() -> void:
	await d.ui.say("대동강 사공", ["물길은 원래 사공 것도 상인 것도 아니오. 배나 띄웁시다."] if String(S.vars.get("CASE_PYONGYANG_OUTCOME", "")) == "A"
		else ["배는 다시 뜨오. 그런데 다들 우치가 강을 팔았다고들 하니, 원."])

func jumo_tell() -> void:
	await d.ui.say("주모", ["흉 있는 사내랑 작은 사내? 그 둘, 강창 뒤에서 종이를 말리더이다.", "장사꾼이 종이는 왜 말리나 했지."])
	d.learn_clue("paper_yard")
	flag("hideout_known")
	await R([{ "discover": "py_paper_yard" }])
	d.journal_note("강창 뒤 종이 마당 — 판 사내 둘")

# ---------------------------------------------------------------------------
# S5002 문서 비교(눈으로) — 종이·먹 번짐·도장 자리
# ---------------------------------------------------------------------------
func compare() -> void:
	S.seen["S5002"] = true
	var before := cmp_count()
	await Docs.open(d, { "docs": ["deed_a", "deed_b"], "title": "대동강 물길 문서 둘",
		"note": "같은 관인이 찍힌 두 장. 무엇이 같고 무엇이 다른가." })
	var n := cmp_count()
	if n >= 2 and not S.knows("R_NOT_SAME"):
		await d.ui.caption("같은 관인이 찍혔어도, 두 문서는 한 손에서 나오지 않았다.", 2.6)
		d.learn_rule("R_NOT_SAME")
		await d.ui.say("한 객주", ["그럼 내 것이 가짜란 말이오?"])
		await d.ui.say("윤 상인", ["내 것이 진짜겠지!"])
		await d.ui.say("대동강 사공", ["누구 것이 진짜든, 판 놈부터 찾으시오."])
		d.journal_note("두 문서를 판 '우치'를 찾는다")
	elif n == before and n < 2:
		await d.ui.caption("아직 더 견주어 볼 데가 있을 것 같다.", 2.0)

# ---------------------------------------------------------------------------
# S5003 종이 마당 — 사기꾼 둘(붙잡거나 보내 준다)
# ---------------------------------------------------------------------------
func yard_look(kind: String) -> void:
	if kind == "paper":
		await d.ui.examine("널어 둔 종이", ["강창 뒤 줄에 얇고 흰 종이가 널려 있다.", "몇 장은 감영 문서 꼴로 반듯하게 오려 두었다."], "clue")
		d.learn_clue("drying_paper")
	else:
		await d.ui.examine("멍석 위 연장", ["날 선 긁개, 종이 부스러기, 먹통.", "오래된 공문 몇 장이 글자가 긁힌 채 포개져 있다."], "clue")
		d.learn_clue("scraper")
	if not f("swindlers_met"): await R([{ "event": "S5003" }])

func yard_meet() -> void:
	flag("swindlers_met")
	S.seen["S5003"] = true
	d.cutscene(true)
	d.place_actor("sw_a", "sw_enter", null, "right"); d.place_actor("sw_b", "sw_enter", null, "right")
	d.camera({ "focus": "hideout", "distance": 16.0, "pitch": 38.0 })
	await d.ui.caption("골목에서 사내 둘이 종이 뭉치를 안고 들어서다 멈춘다. 하나는 키가 크고 턱에 흉, 하나는 작달막하다.", 2.6)
	d.move_actor("sw_a", ["sw_a_spot"], 2.2, "walk", "idle")
	await d.move_actor("sw_b", ["sw_b_spot"], 2.2, "walk", "idle")
	d.face_actor("sw_a", null, "player"); d.face_actor("sw_b", null, "player")
	await d.ui.say("나그네", ["대동강 물길 문서, 당신들이 판 것이오?"])
	await d.ui.say("흉 있는 사내", ["…그, 그게 무슨 소리요."])
	await d.ui.say("작은 사내", ["혀, 형님. 그, 그 나그네…"])
	d.camera(null)
	d.cutscene(false)
	var i: int = await d.ui.choice("", [{ label = "붙잡는다" }, { label = "길을 비켜 준다" }])
	if i == 0: await _fight()
	else: await _let_go()
	flag("swindlers_resolved")
	d.mark_dirty()

func _fight() -> void:
	d.show_actor("sw_a", false); d.show_actor("sw_b", false)
	var res: String = await d.combat("hideout", { "allow_flee": true })
	d.runner.last["fight"] = res
	var rep: Array = d.combat_view.human_report()
	for r in rep:
		if String(r.out) == "down": flag("caught_a" if String(r.id) == "sw_a" else "caught_b")
	flag("fight_result", res)
	d.runner.log_line("fight", [res, rep.map(func(r): return [r.id, r.out])])
	d.end_combat()
	if res == "lose":
		await d.ui.fade(true, 0.8)
		d.teleport_to([d.anchor("hideout").x + 3.0, d.anchor("hideout").y - 4.0], "down")
		await d.wait(0.6)
		await d.ui.fade(false, 0.8)
	_place_caught()
	if f("caught_a"): d.show_actor("sw_a", true)
	if f("caught_b"): d.show_actor("sw_b", true)
	_place_caught()
	if caught_any():
		await d.ui.caption("둘 다 쓰러졌다. 허리끈으로 손을 묶었다." if f("caught_a") and f("caught_b") else "하나는 붙잡았고, 하나는 강창 뒤 골목으로 달아났다.", 2.4)
		var who := "흉 있는 사내" if f("caught_a") else "작은 사내"
		await d.ui.say(who, ["우치 이름은 빌렸을 뿐이오! 감영에서 버린 공문을 사다 고쳤소.", "창고? 우린 감영 창고엔 손도 안 댔소!"])
		d.learn_clue("confession")
	else:
		await d.ui.caption("정신을 차리니 사내들은 종이 뭉치를 안고 골목으로 사라진 뒤였다." if res == "lose" else "사내들이 종이 뭉치를 안고 강창 뒤 골목으로 달아났다.", 2.6)
		d.learn_clue("fled")
		flag("fled")

func _let_go() -> void:
	d.cutscene(true)
	await d.ui.caption("길을 비켜 서자, 두 사내는 종이 뭉치를 끌어안고 골목으로 달아난다.", 2.4)
	d.move_actor("sw_a", ["flee_west"], 4.4, "run", "idle")
	await d.move_actor("sw_b", ["flee_west"], 4.2, "run", "idle")
	d.show_actor("sw_a", false); d.show_actor("sw_b", false)
	d.learn_clue("fled")
	flag("fled")
	d.cutscene(false)

func caught_talk(w: String) -> void:
	await d.ui.say("흉 있는 사내" if w == "a" else "작은 사내", ["강물이야 누가 팔든 흐르는 거 아니오."] if w == "a" else ["가, 감영 창고는 정말 모, 모르오."])

# ---------------------------------------------------------------------------
# S5004 기록 창고
# ---------------------------------------------------------------------------
func alarm() -> void:
	flag("alarm")
	S.phase = "store"
	d.on_phase()
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	d.spawn_actor("pojol_run", "pojol", [pp.x - 6.0, pp.y + 2.0], "right", "포졸", "")
	d.cutscene(true)
	d.move_actor("pojol_run", [[pp.x - 1.6, pp.y + 0.6]], 4.0, "run", "idle")
	await d.wait(0.6)
	await d.ui.say("포졸", ["나그네! 감영 기록 창고가 털렸소!"])
	if caught_any():
		await d.ui.say("포졸", ["이놈들 짓이오?"])
		await d.ui.say("흉 있는 사내" if f("caught_a") else "작은 사내", ["창고는 정말 모르오! 우린 종이나 고쳤지."])
		await d.ui.say("포졸", ["이 둘은 감영으로 끌고 가겠소. 물길 문서 둘도 서리 어른께 맡기오."])
	else:
		await d.ui.say("포졸", ["달아난 놈들 짓인가 했는데… 물길 문서 둘은 서리 어른께 맡기오."])
	await d.ui.say("포졸", ["서리 어른이 문서 볼 줄 아는 사람을 찾소. 감영 뒤뜰 창고로 가 보시오."])
	flag("deeds_to_clerk")
	d.despawn_actor("pojol_run")
	store_state()
	d.cutscene(false)
	await R([{ "discover": "py_girokgo" }])
	d.journal_note("감영 기록 창고가 털렸다")
	var i: int = await d.ui.choice("", [{ label = "감영 뒤 기록 창고로 간다" }, { label = "걸어서 간다" }])
	if i == 0:
		await _travel_to("clerk_store", "up", "대동문을 지나 감영 뒤뜰로 올라갔다.")

func store_arrive() -> void:
	flag("store_seen")
	S.seen["S5004"] = true
	d.cutscene(true)
	d.camera({ "focus": "store_door", "distance": 15.0, "pitch": 40.0 })
	await d.ui.caption("감영 뒤뜰, 높은 마루의 기와 곳간. 서리 하나가 문 앞을 서성인다.", 2.4)
	d.face_actor("clerk", null, "player")
	await d.ui.say("평양 서리", ["평양 감영 서리요. 뒤 살창이 부서졌소. 앞문 자물쇠는 그대로고.", "무엇이 없어졌는지는 안을 봐야 알겠소."])
	d.camera(null)
	d.cutscene(false)

func clerk_talk() -> void:
	if not f("store_open"):
		await d.ui.say("평양 서리", ["앞문 자물쇠는 멀쩡하오."])
		await R([{ "choice": "", "options": [{ "label": "앞문을 열어 주시오", "do": [{ "call": "open_store" }] }, { "label": "그만 가 보겠소.", "end": true }] }])
		return
	if not S.has_clue("rack_gap"):
		await d.ui.say("평양 서리", ["시렁을 보시오. 무엇이 비었는지."]); return
	if not f("woochi_met"):
		await d.ui.say("평양 서리", ["물길 문서 둘은 내가 맡아 두었소. 같은 관인이 찍혔으니 감영도 난처하오.",
			"그 쪽지의 일을 보고 오시거든 다시 들르시오. 문서 보는 법을 조금 알려 드리리다."]); return
	await d.ui.say("평양 서리", ["문서는 서두르면 안 보이오."])

func clerk_done() -> void:
	await d.ui.say("평양 서리", ["글보다 고쳐 쓴 자리 — 그 양반 말이 맞았소.", "함흥 쪽 길은 칠성문 밖이오. 눈이 일찍 오니 단단히 차려 가시오."])

func look_window() -> void:
	await d.ui.examine("뒤 살창", ["살이 바깥에서 비틀려 부러졌다. 창틀에 진흙 묻은 가죽신 자국.",
		"발자국은 서쪽 담 밑으로 이어진다. 담 위 기와 한 장이 밀려 있다."], "clue")
	d.learn_clue("window")
	store_state()

func open_store() -> void:
	if f("store_open"): return
	await d.ui.say("평양 서리", ["열어 드리리다. 안의 것은 손대지 마시오 — 보기만."])
	flag("store_open")
	store_state()
	await d.ui.caption("자물쇠가 풀리고 널문이 열린다. 시렁 하나가 엉성하게 비었다.", 2.2)

func look_rack() -> void:
	await d.ui.examine("빈 시렁", ["벽 시렁의 문서 묶음 가운데 한 칸만 비었다. 칸 머리에 '북관'.",
		"다른 묶음엔 손도 대지 않았다. 먼지에 묶음 자리만 네모나게 남았다."], "clue")
	d.learn_clue("rack_gap")
	await d.ui.say("평양 서리", ["함흥 감영과 오간 공문들이오. 그런 걸 왜…"])
	d.learn_clue("clerk_north")
	d.learn_rule("R_OTHER_AIM")
	await d.ui.examine("빈 칸의 쪽지", ["비어 버린 칸 안쪽에 접힌 쪽지 하나.", "“달 뜨면 부벽루.”", "광통교 난간의 종이 뒷면과 같은 손이다."], "clue")
	d.learn_clue("woochi_note")
	flag("bu_known")
	await R([{ "discover": "py_bubyeongnu" }])
	d.journal_note("달 뜨면 부벽루 — 우치의 쪽지")

func look_ledger() -> void:
	if not S.has_clue("ledger_seen"):
		flag("ledger_open")
		await d.ui.examine("안쪽 궤", ["궤 밑바닥, 기름종이에 싼 낡은 장부 한 장.", "곡물 운송 대장 — 평양 강창에서 함흥 창으로 쌀과 조를 실어 보냈다."], "item")
		d.learn_clue("ledger_seen")
		if not f("park_ledger"):
			flag("park_ledger")
			S.vars["MAIN_PARK_MARK_COUNT"] = int(S.vars.get("MAIN_PARK_MARK_COUNT", 0)) + 1
			Progress.set_var("MAIN_PARK_MARK_COUNT", S.vars.MAIN_PARK_MARK_COUNT)
			d.runner.log_line("var", ["MAIN_PARK_MARK_COUNT", S.vars.MAIN_PARK_MARK_COUNT])
	await Docs.open(d, { "docs": ["grain_ledger"], "title": "곡물 운송 대장", "note": "오래된 대장 한 장. 거래처와 석 수를 본다." })
	if S.has_clue("ledger_park") and not f("park_note"):
		flag("park_note")
		await d.ui.caption("한양 책방 납품표에서 본 朴 표식이다. 이것만으로는 무엇도 알 수 없다.", 2.6)
		d.journal_note("곡물 운송 대장의 거래처 — 박규상 객주")

# ---------------------------------------------------------------------------
# S5005 부벽루 — 밤
# ---------------------------------------------------------------------------
func bu_wait() -> void:
	await d.ui.caption("부벽루는 비어 있다. 쪽지엔 '달 뜨면'이라 했다.", 2.0)
	var i: int = await d.ui.choice("", [{ label = "달 뜨기를 기다린다" }, { label = "나중에 온다" }])
	if i != 0: return
	d.cutscene(true)
	await d.ui.fade(true, 0.8)
	d.set_hour(21.5)
	if d.main.weather != null: d.main.weather.force("clear", 20.0 * 60.0, 0.0); d.main.weather.snow = 0.0
	d.teleport_to("bu_approach", "right")
	await wait_loaded(6.0)
	d.mark_dirty()
	await d.ui.fade(false, 0.8)
	d.cutscene(false)
	await bu_lamp()

func bu_lamp() -> void:
	if not night_now() or f("bu_lamp_seen"): return
	flag("bu_lamp_seen")
	await d.ui.caption("달이 모란봉 위로 올랐다. 부벽루 난간 곁에 등불 하나.", 2.4)

func bu_approach() -> void:
	await R([{ "event": "S5005" }])

func bu_scene() -> void:
	S.seen["S5005"] = true
	d.cutscene(true)
	d.teleport_to("bu_stand", "right")
	d.camera({ "focus": "bu_woochi", "distance": 11.0, "pitch": 30.0 })
	await d.wait(0.3)
	await d.ui.caption("난간에 기대 앉은 사내가 등불 아래 문서를 읽고 있다.", 2.4)
	d.anim_actor("woochi", "idle")
	d.face_actor("woochi", null, "player")
	await d.ui.say("나그네", ["스승과 무슨 사이였습니까?"])
	await d.ui.say("우치", ["한때 같은 걸 봤고."])
	await d.ui.caption("종이를 접는다.", 1.6)
	await d.ui.say("우치", ["다르게 적었지."])
	await d.ui.say("나그네", ["어디 있습니까?"])
	await d.ui.say("우치", ["살아 있다면 동쪽이오."])
	await d.ui.caption("우치가 접은 문서 하나를 발밑으로 던진다.", 2.0)
	d.give(D.HAM_DOC, 1)
	await d.ui.examine("함흥 전갈 문서", ["함흥 감영에서 북청으로 보낸 전갈 세 사람의 이름과 떠난 날짜.", "돌아온 날짜 칸은 비어 있다."], "item")
	d.learn_clue("woochi_words")
	d.learn_clue("hamhung_doc")
	S.vars["MAIN_WOOCHI_KNOWN"] = true
	await d.move_actor("woochi", ["bu_exit1", "bu_exit2"], 4.6, "run", "idle")
	d.show_actor("woochi", false)
	await d.ui.caption("우치는 청류벽 쪽 어둠으로 사라졌다.", 2.2)
	d.camera(null)
	flag("woochi_met")
	S.phase = "teach"
	d.on_phase()
	d.cutscene(false)
	d.journal_note("함흥 — 돌아오지 않은 전갈 셋")
	var i: int = await d.ui.choice("", [{ label = "날이 밝으면 감영 서리에게 간다" }, { label = "여기 좀 더 있는다" }])
	if i == 0:
		d.cutscene(true)
		await d.ui.fade(true, 0.8)
		d.set_hour(8.0)
		d.teleport_to("store_inside", "right")
		await wait_loaded(8.0)
		await d.ui.fade(false, 0.8)
		await d.ui.caption("날이 밝았다. 기록 창고 서리 책상에 물길 문서 두 장이 펼쳐져 있다.", 2.4)
		d.cutscene(false)

# ---------------------------------------------------------------------------
# S5006 문서 감정 — 평양 서리, 이겸의 옛 종이
# ---------------------------------------------------------------------------
func teach() -> void:
	if night_now():
		await d.ui.say("평양 서리", ["이 밤에 문서를 보면 먹빛을 잘못 읽소. 날 밝거든 봅시다."])
		var i: int = await d.ui.choice("", [{ label = "날이 밝기를 기다린다" }, { label = "그만 가 보겠소." }])
		if i != 0: return
		await d.ui.fade(true, 0.8)
		d.set_hour(8.0)
		await d.ui.fade(false, 0.8)
	S.seen["S5006"] = true
	d.cutscene(true)
	d.face_actor("clerk", null, "player")
	await d.ui.say("평양 서리", ["부벽루에 등불이 섰다더니… 만나셨구려."])
	await d.ui.say("평양 서리", ["도장은 훔칠 수 있소. 종이는 사면 그만이고.", "보는 데는 차례가 있소. 긁힌 결, 도장 밑 글자, 이어 붙인 자리, 날짜의 먹빛."])
	await d.ui.examine("서리 서랍의 낡은 종이", ["몇 해 전 북쪽 문서를 보러 왔던 선비가 두고 갔다는 종이 한 장. 낯익은 필체.",
		"“글보다 고쳐 쓴 자리를 먼저 보라. 거짓말은 새 문장을 만들지만, 손은 옛 흔적을 다 지우지 못한다.”"], "clue")
	d.learn_clue("master_note")
	await d.ui.say("평양 서리", ["이(李) 아무개라던가. 그 양반도 함흥 쪽 문서를 묻더이다."])
	var parts := Array(String(S.vars.get("MAIN_MASTER_TRACE", "")).split(",", false))
	if not parts.has("PYONGYANG"): parts.append("PYONGYANG")
	S.vars["MAIN_MASTER_TRACE"] = ",".join(PackedStringArray(parts))
	S.vars["SKILL_DOCUMENT_CHECK"] = true
	for k in ["MAIN_MASTER_TRACE", "SKILL_DOCUMENT_CHECK"]: Progress.set_var(k, S.vars[k])
	d.runner.log_line("var", ["SKILL_DOCUMENT_CHECK", true])
	flag("skill_learned")
	d.cutscene(false)
	await d.ui.caption("새로 익혔다 — 문서 감정", 2.4)
	d.journal_note("문서 감정 — 덧쓴 먹 · 도장 겹침 · 바꾼 종이 · 고친 날짜")
	await d.ui.say("평양 서리", ["물길 문서 둘이 여기 있소. 다시 보시오."])
	await examine_deeds()

func clerk_practice() -> void:
	await d.ui.say("평양 서리", ["다시 보시겠소?"])
	await examine_deeds()

func examine_deeds() -> void:
	await Docs.open(d, { "docs": ["deed_a", "deed_b"], "title": "물길 문서 둘 — 감정", "note": "이번엔 고쳐 쓴 자리를 본다." })
	var n := skill_found()
	if n >= 2:
		await resolve()
		return
	var tries := int(S.flags.get("exam_tries", 0)) + 1
	S.flags["exam_tries"] = tries
	var hint: Array = [["글자보다 그 밑을 보시오. 긁어 낸 데는 결이 일어나 있소."], ["날짜의 먹빛과 도장 테두리를 보시오."], ["종이 한 장이 처음부터 한 장이었는지 보시오."]][mini(tries - 1, 2)]
	await d.ui.say("평양 서리", (["하나는 보셨구려. "] if n == 1 else []) + hint)

func examine_pass() -> void:
	await Docs.open(d, { "docs": ["pass_doc"], "title": "통행문서 — 감정", "note": "한양 책쾌의 탁자에서 받은 통행문서." })
	if S.has_clue("pass_forged") and not f("pass_note"):
		flag("pass_note")
		await d.ui.caption("우치의 통행문서도 고쳐 쓴 것이다. 관인만 진짜다.", 2.4)

# ---------------------------------------------------------------------------
# 결말
# ---------------------------------------------------------------------------
func resolve() -> void:
	if resolved(): return
	var branch := "A" if caught_any() else "B"
	var detail := ("A_both" if f("caught_a") and f("caught_b") else "A_one") if branch == "A" else "B"
	flag("proven")
	d.learn_rule("R_EDIT_TRACE")
	d.cutscene(true)
	await d.ui.say("평양 서리", ["둘 다 감영이 낸 그대로가 아니오. 한 장은 세금 표를 긁어 고쳤고, 한 장은 종이를 이어 붙였소.", "물길은 애초에 사고파는 것이 아니고."])
	if branch == "A": await d.ui.say("평양 서리", ["붙잡힌 놈이 판 돈 반은 내놓았소. 나머지는 벌써 먹고 마셨다지."])
	else: await d.ui.say("평양 서리", ["판 돈은 달아난 놈들과 함께 사라졌구려. 나루에선 아직도 우치가 강을 팔았다 하겠지."])
	S.vars["CASE_PYONGYANG_OUTCOME"] = branch
	S.vars["CASE_PYONGYANG_DETAIL"] = detail
	S.vars["ACT4_OPEN"] = true
	d.runner.log_line("outcome", detail)
	for k in ["ACT4_OPEN", "SKILL_DOCUMENT_CHECK", "MAIN_MASTER_TRACE", "MAIN_PARK_MARK_COUNT", "MAIN_WOOCHI_KNOWN"]: Progress.set_var(k, S.vars.get(k))
	flag("resolved")
	await d.ui.fade(true, 0.7)
	S.phase = "done"
	d.on_phase()
	store_state()
	d.teleport_to("store_door", "down")
	await wait_loaded(6.0)
	await d.ui.fade(false, 0.7)
	await d.ui.caption(ENDING_EXTRA[branch], 3.0)
	d.cutscene(false)
	await R([{ "discover": "py_hamhung_road" }])
	d.journal_note("함흥으로 — 칠성문 밖 북쪽 길")
	d.journal_note("사건 종결 — 「%s」" % CASE_TITLE)
	await d.show_ending()
	d.save()

# ---------------------------------------------------------------------------
# 사건 기록(R)
# ---------------------------------------------------------------------------
const OUTCOME_TEXT := {
	"A_both": "물길 문서 둘을 견주고, 우치의 이름을 빌린 사기꾼 둘을 강창 뒤 종이 마당에서 붙잡았다. 감영 서리와 함께 문서를 감정해 고쳐 쓴 자리를 밝혔다.",
	"A_one": "물길 문서 둘을 견주고, 우치의 이름을 빌린 사기꾼 하나를 붙잡았다. 하나는 달아났다. 감영 서리와 함께 문서를 감정해 고쳐 쓴 자리를 밝혔다.",
	"B": "물길 문서 둘을 견주었지만, 우치의 이름을 빌린 사기꾼 둘은 달아났다. 감영 서리와 함께 문서를 감정해 고쳐 쓴 자리만 밝혔다.",
}
const ENDING_EXTRA := {
	"A": "감영이 나루에 방을 붙였다 — 물길은 사고팔 수 없다. 이튿날부터 대동강 나루에 다시 배가 뜬다.",
	"B": "감영이 나루에 방을 붙였다 — 물길은 사고팔 수 없다. 배는 다시 뜨지만, 나루에선 아직도 우치가 강을 팔았다고들 한다.",
}

func solutions() -> Array:
	var two: bool = S.knows("R_TWO_SELLERS")
	return [
		{ "id": "A", "title": "판 사내를 붙잡는다", "available": caught_any(),
			"text": "우치의 이름을 빌려 물길을 판 자들을 찾아 붙잡고, 문서를 감정해 고쳐 쓴 자리를 밝힌다.",
			"hint": "판 사내가 누구인지부터 알아야 한다." if not two else ("둘이 어디 있는지 알아야 한다." if not f("hideout_known") else "종이 마당에서 마주쳐야 한다.") },
		{ "id": "B", "title": "문서만 바로잡는다", "available": f("fled"),
			"text": "판 자들은 놓치더라도, 문서를 감정해 고쳐 쓴 자리를 밝힌다.", "hint": "문서가 어떻게 고쳐졌는지 알아야 한다." },
	]

func summary() -> Array:
	var p := []
	p.append("대동문 앞 나루. 두 상인이 저마다 '대동강 물길을 쓴다'는 문서를 들고 다툰다. 두 장 다 같은 감영 관인. 사람들은 우치 짓이라 한다.")
	if S.knows("R_NOT_SAME"): p.append("종이·먹·도장 자리를 견주니, 두 문서는 한 손에서 나오지 않았다.")
	elif cmp_count() > 0: p.append("두 문서를 견주어 보는 중이다.")
	if S.knows("R_TWO_SELLERS"): p.append("판 '우치'의 생김새가 상인마다 다르다 — 둘이다.")
	if f("hideout_known") and not f("swindlers_met"): p.append("주모: 그 둘은 강창 뒤에서 종이를 말렸다.")
	if f("swindlers_resolved"):
		if caught_any(): p.append("종이 마당에서 사기꾼을 붙잡았다. “우치 이름은 빌렸을 뿐이오. 창고는 모르오.”")
		else: p.append("종이 마당의 두 사내는 달아났다.")
	if f("alarm"): p.append("감영 기록 창고가 털렸다. 뒤 살창이 바깥에서 부러졌다.")
	if S.has_clue("rack_gap"): p.append("북관 — 함경도 쪽 문서 묶음만 비었다. 빈 칸에 쪽지: “달 뜨면 부벽루.”")
	if S.has_clue("ledger_seen"): p.append("창고 안쪽 궤에 곡물 운송 대장 한 장. 거래처 박규상 객주 — 석 수는 맞는다.")
	if f("woochi_met"): p.append("부벽루에서 우치를 만났다. “한때 같은 걸 봤고, 다르게 적었지.” “살아 있다면 동쪽이오.” 함흥 전갈 문서를 던지고 사라졌다.")
	if f("skill_learned"): p.append("평양 서리에게 문서 감정을 배웠다. 서리가 간직한 종이 — 스승의 필체.")
	var o := String(S.vars.get("CASE_PYONGYANG_DETAIL", ""))
	if o != "":
		p.append(OUTCOME_TEXT.get(o, ""))
		p.append(ENDING_EXTRA.get(String(S.vars.get("CASE_PYONGYANG_OUTCOME", "A")), ""))
	return p

func journal() -> Dictionary:
	if not f("case_started"):
		return { "cases": [], "empty": "아직 평양에서 적힌 사건이 없다." }
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
		var chosen: bool = solved and String(S.vars.CASE_PYONGYANG_OUTCOME) == s.id
		var e: Dictionary = s.duplicate()
		e.available = s.available or chosen
		if chosen: e.text = String(s.text) + " — 이렇게 끝났다."
		sols.append(e)
	return { "cases": [{ "id": "pyongyang", "title": CASE_TITLE, "status": "solved" if solved else "active", "rules_title": "문서의 결",
		"summary": summary(), "clues": clues, "rules": rules, "solutions": sols, "notes": S.notes }] }

func ending_data() -> Dictionary:
	var o := String(S.vars.get("CASE_PYONGYANG_DETAIL", "A_both"))
	var k := String(S.vars.get("CASE_PYONGYANG_OUTCOME", "A"))
	return {
		"case_title": CASE_TITLE,
		"title": { "A": "물길은 팔 수 없다", "B": "남은 소문" }[k],
		"outcome": k,
		"paragraphs": [OUTCOME_TEXT.get(o, ""), ENDING_EXTRA.get(k, ""), "우치가 던진 문서 — 함흥에서 북청으로 간 전갈 셋이 돌아오지 않았다."],
		"record": "새로 익힌 것 — 문서 감정. 기록책에 새로 적힌 곳 — 함흥.",
	}
