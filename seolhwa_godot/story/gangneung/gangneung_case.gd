# 사건 「고개에 남은 종소리」 — 데이터로 쓰기 번거로운 장면(도착·이동·흔적 가르기·도둑과 마주함·호신부·밤의 경계석·세 갈래 결말·새벽 모시기)
# 과 기록책·결말 카드. 데이터(gangneung_data.gd)의 { "call": "이름" }과 조건식 fn('이름')이 부른다.
# 잔영·소리·호신물은 scripts/story/spirits.gd(d.spirits)가 맡고, 여기서는 그 API만 부른다.
extends RefCounted

const D := preload("res://story/gangneung/gangneung_data.gd")
const Progress := preload("res://scripts/region/progress.gd")
const BELL := D.BELL
const ROPE := D.ROPE
const CHARM := D.CHARM
const CASE_TITLE := "고개에 남은 종소리"
const SITE_CLUES := ["moved_stone", "stone_carving", "cut_rope", "scratches", "thief_prints", "missing_offering"]

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
func route_is(r: String) -> bool: return String(S.flags.get("route", "")) == r   # 기록책 발언자(by_if)
func beast_trace() -> bool: return bool(S.vars.get("SKILL_BEAST_TRACE", false))
func senses() -> bool: return d.spirits != null and d.spirits.senses()

# ---------------------------------------------------------------------------
# 열림 조건: 한양 S1006(세 방향 열림) 뒤 — 한양 사건 진행(seen.S1006) 또는 그 사건이 세우는 공통 변수
# ---------------------------------------------------------------------------
func hub_open() -> bool:
	if f("case_started") or bool(S.vars.get("ACT2_OPEN", Progress.get_var("ACT2_OPEN", false))): return true
	var hy: Dictionary = Progress.case_state("hanyang")
	if (hy.get("seen", {}) as Dictionary).has("S1006"): return true
	for k in ["ACT1_HUB_OPEN", "HUB_THREE_WAYS", "MAIN_HUB_OPEN"]:
		if bool(S.vars.get(k, Progress.get_var(k, false))): return true
	return false

func site_clues() -> int:
	var n := 0
	for c in SITE_CLUES:
		if S.has_clue(c): n += 1
	return n

func on_clue(id: String) -> void:
	if id in SITE_CLUES: S.seen["S2002"] = true

func on_load() -> void:
	# 단오(음력 5월) 무렵 사건 — 대관령 고산 눈선(기후대 바탕 눈)을 끈다
	if d.main.weather != null: d.main.weather.snow_line = 1e5
	if S.phase == "night" and not f("resolved"): d.set_hour(maxf(d.main.hour, 21.0) if d.main.hour > 12.0 else d.main.hour)

# ---------------------------------------------------------------------------
# S2001 도착 — 단오를 앞둔 남대천가(15초 이내)
# ---------------------------------------------------------------------------
func arrival() -> void:
	flag("arrived")
	d.cutscene(true)
	d.set_hour(10.0)
	d.set_weather("clear")
	d.teleport_to("town_start", "up")
	await wait_loaded(8.0)
	d.camera({ "focus": "gutdang", "distance": 70.0, "pitch": 24.0 })
	d.main.rig.update(0, d.main.player_pos, d.main.player.facing, null, true)
	await d.ui.caption("강릉. 단오를 앞둔 남대천가.", 2.6)
	d.camera({ "focus": "streamers", "distance": 26.0, "pitch": 30.0 })
	await d.ui.caption("굿당 신목에 오색 천이 걸리고, 장마당엔 좌판이 늘어선다.", 2.8)
	d.camera(null)
	await d.wait(1.0)
	d.cutscene(false)
	if not S.has("ITM_TOOL_009"):
		for it in [["ITM_TOOL_009", 1], ["ITM_WPN_001", 1], ["ITM_WPN_002", 1], ["ITM_AMMO_001", 12], ["COIN", 8]]: d.give(it[0], it[1], true)

func start_case(route: String) -> void:
	if f("case_started"): return
	flag("case_started"); flag("route", route)
	S.seen["S2001"] = true
	if S.phase == "start": S.phase = "explore"
	d.learn_clue("rumor_bell", true)
	if not S.has("ITM_TOOL_009"):
		for it in [["ITM_TOOL_009", 1], ["ITM_WPN_001", 1], ["ITM_WPN_002", 1], ["ITM_AMMO_001", 12], ["COIN", 8]]: d.give(it[0], it[1], true)
	d.ui.toast("새 사건 — 「%s」" % CASE_TITLE, "journal")
	d.journal_note("단오 모시기는 내일 새벽")

# 먼 길(읍내 ↔ 반정 약 3.7km)은 걷는 대신 건너뛸 수 있다(§36.2 이동거리 축소). 직접 걸어도 된다.
func travel(at: String, cap: String) -> void:
	await d.ui.fade(true, 0.7)
	d.teleport_to(at, "up")
	await wait_loaded(10.0)
	if S.phase != "night": d.set_hour(minf(d.main.hour + 1.0, 17.0))
	await d.ui.fade(false, 0.7)
	await d.ui.caption(cap, 2.2)

# 순간이동한 자리 둘레 타일(건물·식생)이 붙을 때까지
func wait_loaded(limit: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		await d.get_tree().process_frame
		var w = d.main.world
		var c: Vector2i = w.tile_of(d.main.player_pos.x, d.main.player_pos.z)
		if not w.scatter_busy_near(c, 1) and not d.main.placement.busy_near(c, 1): break
	d.main.player_pos.y = d.world.height_at(d.main.player_pos.x, d.main.player_pos.z)

# ---------------------------------------------------------------------------
# S2002·S2003 낮 조사 — 흔적 가르기(남원에서 얻은 짐승 흔적 읽기를 쓴다)
# ---------------------------------------------------------------------------
func on_site_clue() -> void:
	S.seen["S2002"] = true
	if site_clues() >= 3 and S.has_clue("thief_prints") and not f("hint_split") and not f("tracks_split"):
		flag("hint_split")
		d.ui.toast("사람 자국과 다른 흔적이 한길에 겹쳐 있다. 발자국 자리에서 갈라 보자." if beast_trace() else "흔적이 뒤섞여 있다. 짚신 자국을 끝까지 따라가 보자.", "info")

func examine_scratch() -> void:
	var t := ["바위 옆구리에 가는 줄 셋이 그어져 있다.", "짐승 발톱보다 가늘고, 사람 연장 자국처럼 곧지도 않다."]
	if beast_trace(): t.append("짐승이라면 둘레에 발자국과 털이 남았을 텐데, 아무것도 없다.")
	await d.ui.examine("바위의 가는 긁힘", t, "clue")

func split_tracks() -> void:
	var others := 0
	for c in ["moved_stone", "stone_carving", "scratches", "cut_rope"]:
		if S.has_clue(c): others += 1
	if others < 2:
		await d.ui.examine("짚신 자국", "무엇과 무엇을 갈라야 할지 아직 모르겠다. 둘레를 더 살펴보자.", "clue")
		return
	if not beast_trace():
		await d.ui.examine("뒤섞인 흔적", "자국이 겹쳐 가르기 어렵다. 짚신 자국을 끝까지 따라가 보는 수밖에.", "clue")
		return
	var i: int = await d.ui.choice("뒤섞인 흔적을 어떻게 볼까?", [{ label = "짐승 흔적 읽기로 가른다" }, { label = "그만둔다" }])
	if i != 0: return
	await d.ui.examine("두 갈래 흔적", [
		"짚신 자국 — 한 사람. 금줄 아래서 멈췄다가 성황사로 올라가고, 내려올 때 깊어진다. 반정 쪽으로 간다.",
		"끌린 돌 자국 — 곁에 사람 발자국이 없다. 짐승 발자국도, 털도 없다. 긁힘도 마찬가지다.",
		"두 흔적은 서로 밟지 않았다. 날도 다르다 — 돌 자국이 먼저다."], "rule")
	d.learn_clue("split")
	d.learn_rule("R_THIEF_APART")
	flag("tracks_split")
	S.seen["S2003"] = true
	d.ui.toast("짚신 자국은 반정 주막 쪽으로 내려간다", "info")

func confront_thief() -> void:
	await d.ui.say("주막 일꾼", ["뭐, 뭐요?"])
	var opts := []
	if S.has_clue("sandals") and S.has_clue("thief_prints"): opts.append({ label = "뒤축 감은 짚신과 고갯길 자국을 견준다" })
	if S.has_clue("stash"): opts.append({ label = "바위 밑 꾸러미의 금줄 토막을 내민다" })
	opts.append({ label = "그만둔다" })
	var i: int = await d.ui.choice("", opts)
	if i == opts.size() - 1: return
	await d.ui.say("덕보", ["…그, 그건."])
	await d.ui.caption("덕보가 지게 밑에서 무명에 싼 것을 꺼낸다. 놋쇠 방울 묶음이다.", 2.6)
	d.give(BELL)
	d.learn_clue("confession")
	await d.ui.say("덕보", ["장에 내다 팔면 겨울 쌀값은 되겠다 싶었소. 제물도…", "하지만 그 돌은 내가 안 건드렸소! 갔을 땐 벌써 누워 있었소."])
	if not f("tracks_split"):
		flag("tracks_split")
		d.learn_rule("R_THIEF_APART")
		S.seen["S2003"] = true
	await R([{ "choice": "", "options": [{ "label": "제관께 데려간다" }] }])
	flag("thief_caught")
	await d.ui.fade(true, 0.5)
	d.place_actor("jegwan", "jegwan_bj", null, "left")
	await d.ui.fade(false, 0.5)
	await d.ui.say("제관", ["네 이놈… 성황사 제물에 손을 대?", "방울은 모시기 전까지 그대가 맡아 주시오. 이놈은 내가 지키겠소."])
	d.journal_note("덕보가 제물과 방울을 훔쳤다")

# ---------------------------------------------------------------------------
# S2004 월심 — 호신부(호신물 칸이 열린다)
# ---------------------------------------------------------------------------
func give_charm() -> void:
	d.anim_actor("wolsim", "give")
	await d.wait(0.8)
	await d.ui.caption("월심이 접은 부적 한 장을 건넨다.", 2.0)
	await R([{ "talisman": "slots", "n": 1 }, { "talisman": "give", "id": CHARM }, { "talisman": "equip", "id": CHARM, "quiet": true }])
	flag("got_charm")
	S.seen["S2004"] = true
	d.ui.toast("호신물 칸이 열렸다 — 호신부를 지녔다 (Q: 지니기·풀기)", "item")
	d.anim_actor("wolsim", "ritual")

# ---------------------------------------------------------------------------
# 제관·주모
# ---------------------------------------------------------------------------
func jegwan_talk() -> void:
	if S.has(BELL) and f("thief_caught"):
		await d.ui.say("제관", ["방울만 있으면 새벽 모시기는 치를 수 있소."])
		await R([{ "choice": "", "loop": true, "options": [
			{ "label": "방울을 돌려드린다 (모시기에 맡긴다)", "end": true, "do": [{ "call": "resolve", "args": ["B"] }] },
			{ "label": "오늘 밤 방울을 들고 한 번 더 올라가 보겠소", "when": "f('got_charm') and not f('keep_bell')", "do": [
				{ "say": "제관", "lines": ["새벽 전엔 꼭 돌려주시오."] }, { "flag": "keep_bell" }] },
			{ "label": "옛 경계석을 아시오?", "when": "(c('moved_stone') or c('stone_carving')) and not f('jg_stone')", "do": [{ "call": "jegwan_stone" }] },
			{ "label": "그만 가 보겠소.", "end": true }] }])
		return
	await d.ui.say("제관", ["제물까지 없어졌다니… 누가 성황사에 손을 댔단 말이오."] if S.has_clue("missing_offering") else ["성황사 길을 살펴봐 주시오. 새벽까지 시간이 없소."])
	await R([{ "choice": "", "loop": true, "options": [
		{ "label": "옛 경계석을 아시오?", "when": "(c('moved_stone') or c('stone_carving')) and not f('jg_stone')", "do": [{ "call": "jegwan_stone" }] },
		{ "label": "그만 가 보겠소.", "end": true }] }])

func jegwan_stone() -> void:
	flag("jg_stone")
	await d.ui.say("제관", ["성황 길이 시작되는 표요. 그 앞에 금줄을 치고 방울을 달았지.", "돌이 누웠다고? …내 평생 처음 듣소."])

func jegwan_night() -> void:
	await d.ui.say("제관", ["잠이 안 오는구려. 고개 쪽에서 자꾸 방울 소리가…"])
	if S.has(BELL) and f("thief_caught"):
		await R([{ "choice": "", "options": [
			{ "label": "날 밝기를 기다려 방울을 돌려드린다", "do": [{ "call": "resolve", "args": ["B"] }] },
			{ "label": "그만 가 보겠소.", "end": true }] }])

func jumo_night() -> void:
	await d.ui.say("반정 주모", ["이 밤에 고개를 오르시오? 조심하시오."])

func jegwan_done() -> void:
	var o := String(S.vars.get("CASE_GANGNEUNG_OUTCOME", ""))
	var l: Array = { "A": ["올해 모시기는 어느 해보다 조용했소. 경계석 금줄은 해마다 새로 치겠소."],
		"B": ["모시기는 무사히 치렀소. 그 누운 돌은… 내년엔 사람을 모아 세워 보리다."],
		"C": ["모시기는 치렀소. 다만 밤이면 고개에서 아직도 방울 소리가 난다는구려."] }.get(o, ["단오 잘 보고 가시오."])
	await d.ui.say("제관", l)

# 반정 주막에서 밤을 기다린다 → S2005
func rest() -> void:
	await d.ui.say("반정 주모", ["건넌방 비었소. 눈 좀 붙이시오."])
	await d.ui.fade(true, 0.9)
	S.phase = "night"
	d.on_phase()
	d.set_hour(21.5)
	d.set_weather("clear")
	d.teleport_to("bj_arrive", "up")
	await d.wait(0.4)
	await d.ui.fade(false, 0.9)
	await d.ui.caption("달이 떴다. 고개 위쪽 어딘가에서…", 2.2)
	await R([{ "sound": "bell_night" }])
	d.learn_clue("night_bell")
	S.seen["S2005"] = true
	if not d.spirits.equipped(""): d.ui.toast("호신부를 지니지 않았다 (Q)", "info")
	d.journal_note("밤. 소리 나는 데로 오른다")

# ---------------------------------------------------------------------------
# 밤(S2005·S2006)
# ---------------------------------------------------------------------------
func night_approach() -> void:
	d.learn_rule("R_SOUND_LEADS")
	if senses():
		await d.ui.caption("경계석 곁에 희끄무레한 형체가 서 있다. 가까이 갈수록… 아직 흐리다.", 2.6)
		d.learn_clue("night_figure")
		d.learn_rule("R_FAINT_OUT")
	else:
		await d.ui.caption("방울 소리는 바로 앞에서 나는데, 아무것도 보이지 않는다. 등골이 서늘하다.", 2.6)
	S.seen["S2006"] = true

func enter_boundary() -> void:
	if senses():
		await d.ui.caption("경계 안으로 들어서자 형체가 또렷해진다. 옛 차림의 사내 — 얼굴은 보이지 않는다.", 2.8)
		if not S.knows("R_FAINT_OUT"): d.learn_rule("R_FAINT_OUT")
		d.learn_rule("R_CLEAR_IN")
		d.learn_clue("night_figure")
	else:
		await d.ui.caption("숨이 막힌다. 무언가 곁에 서 있는 것만 같다.", 2.2)

func lost_way() -> void:
	d.cutscene(true)
	await d.ui.caption("형체를 좇아 숲으로 들어섰다…", 1.8)
	await d.ui.fade(true, 0.8)
	d.teleport_to("bj_arrive", "up")
	d.set_hour(fposmod(d.main.hour + 0.7, 24.0) if d.main.hour > 12.0 else minf(d.main.hour + 0.7, 3.5))
	await wait_loaded(6.0)
	await d.ui.fade(false, 0.8)
	await d.ui.caption("정신을 차려 보니 반정 주막 앞이었다.", 2.2)
	d.cutscene(false)
	flag("lost_once")
	d.ui.toast("보인다고 다 따라가진 말라 했다.", "info")

func dread_out() -> void:
	d.cutscene(true)
	await d.ui.caption("귀가 먹먹해지고, 눈앞이 먹빛으로 번진다…", 2.0)
	await d.ui.fade(true, 0.8)
	d.teleport_to("bj_arrive", "up")
	await wait_loaded(6.0)
	await d.ui.fade(false, 0.8)
	await d.ui.caption("주막 툇마루였다. 주모가 찬물을 떠다 준다.", 2.2)
	d.cutscene(false)
	flag("fainted")
	if not d.spirits.equipped("") and d.spirits.owned().has(CHARM): d.ui.toast("호신부를 지니면 덜할지도 모른다 (Q)", "info")

# 옛 경계석 자리(밤) — S2006 규칙 확인, S2007 해결
func stone_night() -> void:
	for _i in 3:
		var opts := []
		var ids := []
		if S.has(BELL) and not f("bell_home"):
			opts.append({ label = "방울을 옛 자리 가까이 가져간다" }); ids.append("bell")
		if f("bell_home"):
			var ok: bool = S.has_clue("moved_stone") and S.has_clue("stone_carving") and S.has(ROPE)
			opts.append({ label = "누운 경계석을 제자리에 세우고 금줄을 친다", disabled = not ok, hint = "누운 돌이 어디 있는지, 다시 칠 금줄이 있어야 한다." }); ids.append("restore")
		opts.append({ label = "칼을 뽑아 벤다" }); ids.append("sword")
		opts.append({ label = "물러난다" }); ids.append("back")
		var i: int = await d.ui.choice("옛 경계석 자리. 방울 소리가 멎지 않는다." if not f("bell_home") else "옛 경계석 자리. 고요하다.", opts)
		match ids[i]:
			"bell": await bell_home()
			"restore": await restore(); return
			"sword": await force_through(); return
			_: return

func bell_home() -> void:
	d.cutscene(true)
	d.face_actor("player", null, "stone_socket")
	await d.ui.caption("방울을 들고 빈 돌자리 앞으로 다가섰다.", 2.0)
	flag("bell_home")
	await d.wait(0.8)
	await d.ui.caption("…방울 소리가 멎었다. 고개가 갑자기 조용하다.", 2.4)
	d.learn_rule("R_BELL_HOME")
	if senses(): await R([{ "spirit": "jy_stone", "do": "anim", "name": "head_turn" }])
	d.cutscene(false)

func restore() -> void:
	d.cutscene(true)
	await d.ui.fade(true, 0.6)
	await d.ui.caption("누운 선돌을 끌어 와 빈 자리에 세웠다. 장정 둘 몫이었다.", 2.4)
	d.take(ROPE); d.take(BELL)
	d.world_state("stone_restored", true)
	await d.ui.fade(false, 0.6)
	await d.ui.caption("새 금줄을 치고 한가운데 방울을 달았다.", 2.2)
	if senses():
		await R([{ "spirit": "jy_stone", "do": "show" }, { "spirit": "jy_stone", "do": "anim", "name": "head_turn" }])
		await d.wait(1.4)
		await d.ui.caption("형체가 이쪽을 한 번 돌아보더니, 먹물이 물에 풀리듯 옅어졌다.", 2.6)
		await R([{ "spirit": "jy_stone", "do": "vanish" }])
	else:
		await d.ui.caption("서늘하던 기운이 바람에 쓸려 간다.", 2.2)
	await resolve("A")

func force_through() -> void:
	d.cutscene(true)
	await d.ui.caption("칼을 뽑았다.", 1.4)
	d.anim_actor("player", "attack2")
	d.shake(0.25, 0.4)
	if senses():
		await R([{ "spirit": "jy_stone", "do": "vanish" }])
	await d.ui.caption("칼끝이 아무것도 베지 못했다. 형체는 흩어졌다가, 몇 걸음 뒤에서 다시 선다.", 2.8)
	if senses(): await R([{ "spirit": "jy_stone", "do": "release" }])
	await d.ui.caption("눈을 감고 경계를 억지로 지나 성황사까지 올랐다. 등 뒤에서 방울 소리가 따라온다.", 2.8)
	await resolve("C")

# ---------------------------------------------------------------------------
# 결말(S2007) → 새벽 모시기 → S2008 → 결말 카드
# ---------------------------------------------------------------------------
func resolve(branch: String) -> void:
	var detail := branch
	if branch == "C": detail = "C_bell" if S.has(BELL) else "C_nobell"
	S.vars["CASE_GANGNEUNG_OUTCOME"] = branch
	S.vars["CASE_GANGNEUNG_DETAIL"] = detail
	S.seen["S2007"] = true
	d.runner.log_line("outcome", detail)
	flag("resolved")
	if not f("thief_caught"): flag("thief_fled")
	d.camera(null)
	await morning(branch)

func morning(branch: String) -> void:
	d.cutscene(true)
	await d.ui.fade(true, 1.0)
	S.phase = "morning"
	d.on_phase()
	d.set_hour(5.6)
	d.teleport_to("rite_player", "up")
	await wait_loaded(8.0)
	if S.has(BELL): d.take(BELL)
	d.camera({ "focus": "shrine_front", "pitch": 34.0, "distance": 17.0 })
	await d.wait(0.4)
	await d.ui.fade(false, 1.0)
	await d.ui.caption("새벽. 대관령 국사성황사.", 2.0)
	d.anim_actor("wolsim", "ritual")
	await d.ui.caption({
		"A": "제관이 새로 친 금줄 앞에 절을 올린다. 경계석의 방울은 바람에 흔들릴 뿐 울지 않는다.",
		"B": "되찾은 방울을 앞세워 모시기가 시작된다. 행렬이 누운 경계석 곁을 지날 때, 방울이 한 번 울었다.",
		"C": "모시기는 치렀다. 행렬이 경계석 곁을 지날 때 사람들은 고개를 돌렸다.",
	}[branch], 3.0)
	if f("thief_fled"): await d.ui.caption("덕보는 밤사이 반정에서 사라졌다.", 2.0)
	await R([{ "event": "S2008" }])
	d.camera(null)
	await d.ui.caption(ENDING_EXTRA[branch], 2.8)
	S.phase = "done"
	d.on_phase()
	d.set_hour(8.0)
	d.cutscene(false)
	d.journal_note("사건 종결 — 「%s」" % CASE_TITLE)
	await d.show_ending()
	d.save()

func master_trace() -> void:
	var cur := String(S.vars.get("MAIN_MASTER_TRACE", ""))
	var parts := Array(cur.split(",", false))
	if not parts.has("GANGNEUNG"): parts.append("GANGNEUNG")
	var v := ",".join(PackedStringArray(parts))
	S.vars["MAIN_MASTER_TRACE"] = v
	Progress.set_var("MAIN_MASTER_TRACE", v)
	d.runner.log_line("var", ["MAIN_MASTER_TRACE", v])
	d.ui.toast("기록책에 새로 적힌 곳 — 강릉", "journal")

# ---------------------------------------------------------------------------
# 사건 기록(R)
# ---------------------------------------------------------------------------
const ROUTE_TEXT := {
	"mudang": "강릉 단오장에서 들었다. 대관령 국사성황께 올릴 방울이 없어졌다고.",
	"jegwan": "대관령 반정에서 제관에게 들었다. 국사성황께 올릴 방울이 없어졌다고.",
}
const OUTCOME_TEXT := {
	"A": "밤, 방울을 옛 경계석 자리로 가져가자 고개의 방울 소리가 멎었다. 누운 돌을 세우고 새 금줄에 방울을 달았다. 형체는 한 번 돌아보고 옅어졌다.",
	"B": "덕보를 제관에게 넘기고 방울을 돌려주었다. 새벽 모시기는 제대로 치렀다. 옛 경계석은 누운 채다.",
	"C_bell": "밤, 경계석 곁의 형체에 칼을 뽑았다. 칼은 아무것도 베지 못했고, 억지로 지나 성황사에 닿았다.",
	"C_nobell": "밤, 경계석 곁의 형체에 칼을 뽑았다. 칼은 아무것도 베지 못했고, 억지로 지나 성황사에 닿았다. 방울 없이 모시기를 치렀다.",
}
const ENDING_EXTRA := {
	"A": "단오장이 섰다. 고개를 넘는 장꾼들은 새로 친 금줄 앞에서 걸음을 늦춘다.",
	"B": "단오장이 섰다. 다만 밤길 나그네 가운데 고개에서 무언가를 봤다는 사람이 가끔 있다.",
	"C": "단오장은 섰다. 그 뒤로 밤마다 고개 쪽에서 방울 소리가 들린다.",
}

func solutions() -> Array:
	var has_bell: bool = S.has(BELL) or f("bell_home")
	var a_ok: bool = has_bell and S.has_clue("moved_stone") and S.has_clue("stone_carving") and (S.has(ROPE) or bool(S.world.get("stone_restored", false)))
	var a_hint := "누운 돌의 자리를 알아야 한다." if not S.has_clue("moved_stone") else ("방울을 되찾아야 한다." if not has_bell else "다시 칠 금줄이 있어야 한다.")
	return [
		{ "id": "A", "title": "방울과 경계석을 되돌린다" if S.has_clue("moved_stone") else "???", "available": a_ok,
			"text": "밤에 방울을 옛 경계석 자리로 가져가고, 누운 돌을 세워 금줄을 다시 친다.", "hint": a_hint },
		{ "id": "B", "title": "도둑을 넘기고 모시기에 맡긴다" if S.has_clue("thief_prints") else "???", "available": f("thief_caught") and has_bell,
			"text": "제물 도둑을 제관에게 넘기고, 되찾은 방울로 새벽 모시기를 치르게 한다.",
			"hint": "짚신 자국의 주인을 찾아야 한다." if not f("thief_caught") else "방울을 되찾아야 한다." },
		{ "id": "C", "title": "억지로 지나간다", "available": S.phase == "night" or f("got_charm"),
			"text": "칼을 뽑아 길을 막는 것을 베며 지나간다. 지나갈 수는 있겠지만…", "hint": "밤의 고개에 무엇이 있는지 아직 모른다." },
	]

func summary() -> Array:
	var p := []
	p.append(ROUTE_TEXT.get(String(S.flags.get("route", "mudang")), ROUTE_TEXT.mudang))
	if site_clues() > 0:
		var bits := []
		if S.has_clue("moved_stone") or S.has_clue("stone_carving"): bits.append("옛 경계석이 뽑혀 숲 쪽에 누웠다")
		if S.has_clue("cut_rope"): bits.append("금줄이 칼에 잘렸다")
		if S.has_clue("missing_offering"): bits.append("성황사 제물이 사라졌다")
		if S.has_clue("scratches"): bits.append("바위에 가는 긁힘이 남았다")
		p.append("국사성황사 길: " + ", ".join(bits) + "." if not bits.is_empty() else "국사성황사 길을 살폈다.")
	if f("tracks_split"): p.append("짚신 자국과 돌·긁힘의 흔적은 서로 섞이지 않는다.")
	if f("thief_caught"): p.append("반정 주막 일꾼 덕보가 제물과 방울을 훔쳤다. 돌은 건드리지 않았다고 한다.")
	if f("got_charm"): p.append("월심이 호신부를 주었다. 오늘 밤 다시 오르라고.")
	if S.phase == "night" and not f("resolved"): p.append("밤. 방울 없는 방울 소리가 옛 경계석 쪽에서 난다.")
	var o := String(S.vars.get("CASE_GANGNEUNG_DETAIL", ""))
	if o != "":
		p.append(OUTCOME_TEXT.get(o, ""))
		p.append(ENDING_EXTRA.get(String(S.vars.get("CASE_GANGNEUNG_OUTCOME", "A")), ""))
		if String(S.vars.get("MAIN_MASTER_TRACE", "")).contains("GANGNEUNG"): p.append("옛 제의 기록 뒷장에 스승의 필체가 있었다.")
	return p

func journal() -> Dictionary:
	if not f("case_started"):
		return { "cases": [], "empty": "아직 강릉에서 적힌 사건이 없다." }
	var clues := []
	for id in S.clues:
		var c: Dictionary = d.data.clues.get(id, { "title": id, "text": "" })
		clues.append({ "title": c.title, "text": c.text })
	var rules := []
	for id in S.rules:
		var r: Dictionary = d.data.rules.get(id, { "title": id, "text": "" })
		rules.append({ "title": r.title, "text": r.text })
	var solved: bool = String(S.vars.get("CASE_GANGNEUNG_OUTCOME", "")) != "" and S.phase in ["morning", "done"]
	var sols := []
	for s in solutions():
		var chosen: bool = solved and String(S.vars.CASE_GANGNEUNG_OUTCOME) == s.id
		var e: Dictionary = s.duplicate()
		e.available = s.available or chosen
		if chosen: e.text = String(s.text) + " — 이 방법으로 끝냈다."
		sols.append(e)
	return { "cases": [{ "id": "gangneung", "title": CASE_TITLE, "status": "solved" if solved else "active", "rules_title": "고개의 규칙",
		"summary": summary(), "clues": clues, "rules": rules, "solutions": sols, "notes": S.notes }] }

func ending_data() -> Dictionary:
	var o := String(S.vars.get("CASE_GANGNEUNG_DETAIL", "A"))
	var k := String(S.vars.get("CASE_GANGNEUNG_OUTCOME", "A"))
	return {
		"case_title": CASE_TITLE,
		"title": { "A": "제자리로 돌아간 방울", "B": "되찾은 방울", "C": "베어지지 않은 형체" }[k],
		"outcome": k,
		"paragraphs": [OUTCOME_TEXT.get(o, ""), ENDING_EXTRA.get(k, "")],
		"record": "단서 %d개 · 알아낸 고개의 규칙 %d가지. 호신물 칸이 열렸다(호신부). 기록책에 새로 적힌 곳 — 강릉." % [S.clues.size(), S.rules.size()],
	}
