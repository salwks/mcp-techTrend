# 사건 「굴에 남은 숨」 — 데이터로 쓰기 번거로운 장면(남해 뱃길 첫 건넘, 화북포 도착·곽칠성, 김녕 수색, 굴 입구 흔적과 감응 매듭,
# 굴 안 어둠·구렁이·벽 너머 잔영, 아이 구조, 세 결말, 곽칠성의 나무패, 최종장 문)과 기록책·결말 카드.
# 데이터(jeju_data.gd)의 { "call": "이름" }과 조건식 fn('이름')이 부른다. 감응 매듭은 scripts/story/sensing.gd(d.sensing), 잔영은 spirits.gd(d.spirits).
extends RefCounted

const D := preload("res://story/jeju/jeju_data.gd")
const Progress := preload("res://scripts/region/progress.gd")
const Travel := preload("res://scripts/region/travel.gd")
const Discovery := preload("res://scripts/region/discovery.gd")
const CASE_TITLE := "굴에 남은 숨"
const R01 := "JL_NAMWON_UNBONG-GG_HANYANG"
# 최종장(ACT 6 한양 「칠패의 밤」) 문: ACT 2~5가 모두 끝나야 연다
const FINALE_NEEDS := ["CASE_GANGNEUNG_COMPLETE", "CASE_GYEONGJU_COMPLETE", "CASE_HWANGJU_COMPLETE", "CASE_PYONGYANG_COMPLETE", "CASE_HAMHUNG_COMPLETE", "CASE_JEJU_COMPLETE"]

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
func outcome() -> String: return String(S.vars.get("CASE_JEJU_OUTCOME", ""))
func resolved() -> bool: return outcome() != ""
func pp() -> Vector2: return Vector2(d.main.player_pos.x, d.main.player_pos.z)
func glance(t: String) -> void: d.ui.caption(t, 2.6)   # 조작을 막지 않는 한 줄
func setv(k: String, v) -> void:
	S.vars[k] = v
	Progress.set_var(k, v)
	d.runner.log_line("var", [k, v])

# ---------------------------------------------------------------------------
# 공간마다 세계 상태
# ---------------------------------------------------------------------------
func on_load() -> void:
	match space():
		D.RS:
			var boats = d.main.get("boats")
			if boats != null:
				var r: Dictionary = boats.route(D.LANE)
				if not r.is_empty():   # 관두포 선창(뱃길 처음 끝 내릴 자리)과 사공 자리
					var lp: Vector2 = r.land[0]
					var o: Vector2 = r.out[0] if r.has("out") else Vector2(-1, 0)
					d.data.anchors["rs_pier"] = [lp.x, lp.y]
					d.data.anchors["rs_boatman"] = [lp.x + o.x * 3.0 + o.y * 3.5, lp.y + o.y * 3.0 - o.x * 3.5]
					if d.actors.has("rs_boatman"): d._place_home(d.actors.rs_boatman)
				boats.skip_lock = approach_on()
				if not boats.arrived.is_connected(_on_boat_arrived): boats.arrived.connect(_on_boat_arrived)
		D.JJ:
			d.main.indoor_gate = indoor_gate
			_world_state()
			if f("gwak_met") and d.actors.has("gwak"): d.actors.gwak.name = "곽칠성"
			if f("child_saved"): d.anim_actor("mother", "idle")

func _world_state() -> void:
	var w = d.world
	if f("s7003") and w.get("decals") != null: w.decals.set_group_visible("s7003_tracks", true)
	if f("case_started"):
		w.set_prop_state("jj_sc_sagul_geumjul", "NORMAL" if outcome() == "A" else "BROKEN")
		w.set_prop_state("jj_sc_sagul_jemul", "NORMAL" if outcome() == "A" else "EMPTY")
	if f("snake_gone") or f("snake_dead"): w.set_prop_state(D.SAG + "/shed", "NORMAL")

# ---------------------------------------------------------------------------
# ACT 4.5 — 남해 뱃길(함흥 뒤 처음 지날 때만). 제주 첫 뱃길은 건너뛰기 없음
# ---------------------------------------------------------------------------
func approach_on() -> bool:
	return not Progress.route_done(D.RS) and not f("crossed")

func rs_arrival() -> void:
	if not S.has("ITM_TOOL_009"): _kit()
	glance("남해 뱃길 들머리. 곡성 들을 지나 영산강을 건너고, 덕진다리를 넘어 관두포까지 간다.")
	d.journal_note("남해 뱃길 — 곽칠성을 찾아 제주로")

func _kit() -> void:
	for it in [["ITM_TOOL_009", 1], ["ITM_WPN_001", 1], ["ITM_WPN_002", 1], ["ITM_AMMO_001", 12], ["COIN", 8]]: d.give(it[0], it[1], true)

func boatman_talk() -> void:
	if approach_on():
		await d.ui.say("관두포 사공", ["제주 가오? 오늘은 바람이 좋소. 선창 끝에서 배에 오르시오.", "처음 건너는 바다면 뱃전 꼭 잡으시오."])
	else:
		await d.ui.say("관두포 사공", ["오늘도 바람 보고 뜨오."])

var _amb_t := 0.0
const SEA_LINES := [[0.12, "rs_c1", "관두포가 멀어진다. 돛이 바람을 받는다."], [0.45, "rs_c2", "추자 바다. 물빛이 짙어진다. 사공이 노를 고쳐 잡는다."],
	[0.78, "rs_c3", "구름 밑으로 한라산이 드러난다."]]

func _sea_progress() -> float:
	var boats = d.main.boats
	if not boats.riding() or boats.ride_id() != D.LANE: return -1.0
	var r: Dictionary = boats.ride.r
	var s0: float = r.half if int(boats.ride.dir) > 0 else r.len - r.half
	return absf(float(boats.ride.s) - s0) / maxf(1.0, float(r.len) - 2.0 * float(r.half))

func _on_boat_arrived(id: String, _place: String) -> void:
	if id != D.LANE or space() != D.RS or not approach_on(): return
	var r: Dictionary = d.main.boats.route(D.LANE)
	if not r.is_empty() and pp().distance_to(r.land[1]) > pp().distance_to(r.land[0]): return   # 화북포 쪽에 닿았을 때만
	flag("crossed")
	d.main.boats.skip_lock = false
	glance("화북포에 닿았다. 검은 돌 포구 너머로 돌담 마을이 보인다.")
	d.journal_note("제주 뱃길을 처음 건넜다 — 관두포에서 화북포로")
	S.save()

func ambient(dt: float) -> void:
	_amb_t -= dt
	if _amb_t > 0.0: return
	_amb_t = 0.15
	match space():
		D.RS:
			if not approach_on(): return
			var pr := _sea_progress()
			if pr < 0.0: return
			for l in SEA_LINES:
				if pr >= float(l[0]) and not f(String(l[1])):
					flag(String(l[1]))
					d.runner.log_line("sea", [l[1], snappedf(pr, 0.01)])
					d.ui.caption(String(l[2]), 3.0)
					break
		D.JJ:
			d.main.lantern = S.has(D.LANTERN)
			_snake_hazard(0.15)

# ---------------------------------------------------------------------------
# 굴 안 구렁이: 다가가면 고개를 치켜들고(땅에 물기 줄 예고) 문다 — 맞으면 뒤로 밀려난다. 싸움이 아니다(C를 고를 때만 싸움)
# ---------------------------------------------------------------------------
var _hz := ""
var _hz_t := 0.0
var _hz_cd := 0.0

func _snake_hazard(dt: float) -> void:
	_hz_cd -= dt
	var a = d.actors.get("snake")
	if a == null or not a.shown or d.runner.busy or d.ui.modal or (d.combat_view != null and d.combat_view.active):
		if _hz != "" and a != null: d.anim_actor("snake", "idle")
		_hz = ""
		return
	var sp := Vector2(a.pos.x, a.pos.z)
	var dist := sp.distance_to(pp())
	_hz_t += dt
	match _hz:
		"":
			if dist < 3.0 and _hz_cd <= 0.0:
				_hz = "wind"; _hz_t = 0.0
				d.face_actor("snake", null, "player")
				d.anim_actor("snake", "ready")
				var dir := (pp() - sp).normalized()
				d.combat_view.fx("lane", sp.x, sp.y, { dir = dir, length = 2.9, width = 0.7, duration = 0.75 })
				d.ui.caption("구렁이가 고개를 치켜든다!", 1.2)
				d.runner.log_line("snake", "wind")
		"wind":
			if _hz_t >= 0.75:
				_hz = "rec"; _hz_t = 0.0
				d.anim_actor("snake", "thrust")
				if dist < 3.2:
					var away := (pp() - sp).normalized()
					if away.length() < 0.1: away = Vector2(0, 1)
					d.teleport_to(pp() + away * 2.2, d.main.player.facing)
					d.shake(0.2, 0.3)
					d.ui.caption("물릴 뻔했다 — 뒤로 물러섰다.", 1.8)
					flag("snake_warned")
					d.runner.log_line("snake", "strike_near")
				else:
					d.runner.log_line("snake", "strike_miss")
		"rec":
			if _hz_t >= 0.8:
				_hz = ""; _hz_cd = 2.0
				d.anim_actor("snake", "idle")

# ---------------------------------------------------------------------------
# 화북포 — 도착·생활·곽칠성(S7001)·김녕 소식(S7002)
# ---------------------------------------------------------------------------
func jj_arrival() -> void:
	flag("jj_arrived")
	if not S.has("ITM_TOOL_009"): _kit()
	if S.phase == "start": S.phase = "explore"; d.on_phase()
	d.cutscene(true)
	if pp().distance_to(d.anchor("jj_arrive")) > 300.0:
		await d.ui.fade(true, 0.5)
		d.teleport_to("jj_arrive", "up")
		await wait_loaded(10.0)
		await d.ui.fade(false, 0.5)
	d.camera({ "focus": "hw_spring", "distance": 30.0, "pitch": 34.0 })
	await d.ui.caption("화북포. 검은 돌로 쌓은 포구, 돌담 사이로 바닷바람이 지난다.", 2.8)
	await d.ui.caption("물질 나갔던 해녀들이 테왁을 끌고 올라온다. 용천수 물터에선 아낙들이 물허벅을 채운다.", 3.0)
	d.camera(null)
	d.cutscene(false)
	await R([{ "discover": "hw_port" }])
	d.journal_note("제주 화북포에 닿았다 — 곽칠성을 찾는다")

func wait_loaded(limit: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		await d.get_tree().process_frame
		var w = d.main.world
		var c: Vector2i = w.tile_of(d.main.player_pos.x, d.main.player_pos.z)
		if not w.scatter_busy_near(c, 1) and not d.main.placement.busy_near(c, 1): break
	d.main.player_pos.y = d.world.height_at(d.main.player_pos.x, d.main.player_pos.z)

func hw_woman_talk() -> void:
	await d.ui.say("화북 아낙", ["물 길으러 왔소? 이 물은 바다 밑에서 솟는 물이라 짜지 않소."])
	if not S.has_clue("gwak_porter"):
		var i: int = await d.ui.choice("", [{ label = "귀양 온 곽 아무개라는 이를 찾소" }, { label = "그만 가 보겠소." }])
		if i != 0: return
		await d.ui.say("화북 아낙", ["귀양 온 늙은이? 곽 서방이오. 열 몇 해째 저 물가에서 짐을 지오. 말은 없소."])
		d.learn_clue("gwak_porter")

func hw_woman_done() -> void:
	await d.ui.say("화북 아낙", { "A": ["김녕 굴에 금줄을 새로 맸다더군. 심방이 직접 맸대."],
		"B": ["김녕 굴은 돌로 막았대. 아이는 찾았고."], "C": ["김녕 굴 뱀을 육지 사람이 베었다던데. 옛날 판관처럼."] }.get(outcome(), ["물 길으러 왔소?"]))

func haenyeo_b_talk() -> void:
	if f("case_started") and not resolved():
		await d.ui.say("해녀", ["김녕 아이 일은 들었소. 그 굴엔 우리도 안 들어가오."]); return
	await d.ui.say("해녀", ["전복 철은 지났소. 요즘은 미역이오."])

# S7001 — "그 일은 끝났소." 억지 설득 선택지 없음
func s7001() -> void:
	d.cutscene(true)
	d.face_actor("gwak", null, "player")
	await d.ui.caption("늙은 짐꾼이 지게를 내려놓는다. 굽은 등, 볕에 그은 목덜미. 손마디가 굵다.", 2.8)
	var i: int = await d.ui.choice("", [{ label = "열두 해 전 서강 창고 일을 여쭙고 싶습니다." }, { label = "…아니오. 길을 잘못 들었소." }])
	if i != 0:
		d.cutscene(false); return
	await d.ui.say("곽칠성", ["그 일은 끝났소."])
	await d.ui.caption("그는 다시 지게를 진다. 더 말하지 않는다.", 2.2)
	flag("gwak_met")
	S.seen["S7001"] = true
	d.actors.gwak.name = "곽칠성"
	setv("MAIN_GWAK_NAME_KNOWN", true)
	d.learn_clue("gwak_closed")
	d.journal_note("화북포 물가의 늙은 짐꾼 — 곽칠성. “그 일은 끝났소.”")
	d.cutscene(false)
	await d.wait(1.0)
	await R([{ "event": "S7002" }])

func gwak_again() -> void:
	if f("case_started"):
		await offer_gimnyeong(); return
	await d.ui.say("곽칠성", ["짐이나 나르시오."])

# S7002 — 김녕 아이 실종. 곽칠성이 수색에 나서고 나그네도 함께
func s7002() -> void:
	d.cutscene(true)
	d.spawn_actor("runner", "jj_man", "runner_from", "left", "김녕 사람", "")
	d.camera({ "focus": "gwak_pier", "distance": 24.0, "pitch": 36.0 })
	await d.move_actor("runner", ["runner_to"], 4.0, "run", "idle")
	await d.ui.say("김녕 사람", ["김녕에서 아이가 없어졌소! 덕이가… 어제 해 질 녘에 굴 쪽으로 가는 걸 봤다는 사람이 있소!"])
	await d.ui.say("화북 뱃사람", ["그 굴? 뱀 굴 말이오?"])
	await d.ui.caption("곽칠성이 지게를 벗어 놓는다.", 2.0)
	await d.ui.say("곽칠성", ["…굴 길은 내가 아오."])
	d.camera(null)
	start_case()
	d.learn_clue("child_missing")
	d.cutscene(false)
	await offer_gimnyeong()

func start_case() -> void:
	if f("case_started"): return
	flag("case_started")
	S.seen["S7002"] = true
	d.ui.toast("새 사건 — 「%s」" % CASE_TITLE, "journal")
	d.journal_note("김녕 아이 덕이가 굴 쪽으로 가고 돌아오지 않았다")
	await R([{ "discover": "gw_cave" }])
	if d.onboard != null: d.onboard.on_case_started()

func offer_gimnyeong() -> void:
	if S.phase == "gimnyeong": return
	var i: int = await d.ui.choice("", [{ label = "김녕으로 같이 간다 (동쪽 해안길)" }, { label = "조금 있다 가겠소." }])
	if i == 0: await go_gimnyeong()

func go_gimnyeong() -> void:
	flag("to_gimnyeong")
	d.cutscene(true)
	await d.ui.fade(true, 0.7)
	d.despawn_actor("runner")
	S.phase = "gimnyeong"
	d.on_phase()
	d.set_hour(maxf(d.main.hour + 2.0, 13.0))
	d.teleport_to("gw_arrive", "up")
	await wait_loaded(10.0)
	await d.ui.fade(false, 0.7)
	await d.ui.caption("동쪽 해안길을 따라 김녕. 굴 앞 풀밭에 마을 사람들이 모여 있다.", 2.6)
	await d.ui.caption("덕이 어미가 굴 쪽만 본다. 아무도 굴 안에 들지 않았다.", 2.4)
	d.cutscene(false)
	d.journal_note("김녕 굴 앞 — 수색")

func gwak_search() -> void:
	if not f("s7003"):
		await d.ui.say("곽칠성", ["입구부터 보시오. 들어가는 건 그다음이오."]); return
	if not S.has(D.LANTERN) and f("simbang_here"):
		await d.ui.say("곽칠성", ["불 없이 들면 못 나오오."])
		d.give(D.LANTERN); return
	if f("child_saved") and not resolved():
		await d.ui.say("곽칠성", ["아이는 찾았소. 남은 일은 당신이 정하시오."]); return
	await d.ui.say("곽칠성", ["…"])

func elder_done() -> void:
	await d.ui.say("김녕 노인", { "A": ["금줄을 새로 맸으니 올해 제물도 올려야지."],
		"B": ["막아 두면 된다고들 하오. …밤엔 돌 틈에서 바람 소리가 나오."],
		"C": ["뱀을 베었다고? 옛날 판관도 그랬다지. 그래도 굴 앞에 금줄은 다시 쳐야 하오."] }.get(outcome(), ["…"]))

func simbang_done() -> void:
	await d.ui.say("심방", ["매듭은 가지고 가시오. 섞인 걸 나누는 건 그 매듭이 아니라 당신 눈이오."])

func simbang_talk() -> void:
	if not f("child_saved"):
		await d.ui.say("심방", ["아이부터 찾으시오. 굿은 그다음이오."]); return
	if not f("bowl_got"):
		await d.ui.say("심방", ["제물을 다시 올리려 해도 그릇이 없소. 굴에서 사라졌다지."]); return
	await d.ui.say("심방", ["굴 바닥 판 자리부터 메워야 하오. 길이 상한 채로는 못 올리오."])

# ---------------------------------------------------------------------------
# S7003 굴 입구 — 부서진 금줄·사라진 제물·큰 뱀 흔적·사람 신발 흔적
# ---------------------------------------------------------------------------
func s7003() -> void:
	flag("s7003")
	S.seen["S7003"] = true
	_world_state()
	d.cutscene(true)
	d.camera({ "focus": "rope", "distance": 14.0, "pitch": 48.0 })
	await d.ui.caption("굴 입구. 금줄이 끊겨 늘어졌다. 안쪽 옛 제단 돌 앞 제물상이 비었다.", 2.8)
	await d.ui.caption("입구 흙 위에 자국이 여럿 겹쳤다.", 2.0)
	d.camera(null)
	await d.ui.say("곽칠성", ["안으로는 혼자 들지 마시오."])
	d.cutscene(false)

func mouth_seen() -> int:
	var n := 0
	for c in ["rope_cut", "snake_track", "shoe_track", "fake_track", "offer_gone"]:
		if S.has_clue(c): n += 1
	return n

# S7004 제주 심방 — 감응 매듭. "사람이 만든 흔적하고 다른 게 섞여 있으면 이게 먼저 흔들릴 거요."
func s7004() -> void:
	flag("simbang_here")
	S.seen["S7004"] = true
	d.cutscene(true)
	d.place_actor("simbang", "gw_simbang_in", null, "down")
	d.anim_actor("simbang", "walk")
	d.camera({ "focus": "gw_gather", "distance": 18.0, "pitch": 40.0 })
	await d.ui.caption("요령 소리. 짙은 저고리에 흰 치마, 마을 심방이 장정 하나를 앞세우고 온다.", 2.6)
	await d.move_actor("simbang", ["gw_simbang"], 1.6, "walk", "idle")
	d.face_actor("simbang", null, "player")
	await d.ui.say("심방", ["금줄이 끊겼다고."])
	await d.ui.caption("심방이 허리춤에서 붉은 실 매듭 하나를 풀어 건넨다.", 2.2)
	d.anim_actor("simbang", "give")
	await d.ui.say("심방", ["사람이 만든 흔적하고 다른 게 섞여 있으면 이게 먼저 흔들릴 거요."])
	d.anim_actor("simbang", "idle")
	var sp = d.spirits
	if sp.slots() <= 0: sp.set_slots(1)
	sp.give_talisman(D.KNOT)
	sp.equip(D.KNOT, true)
	setv("ITEM_SENSING_KNOT", true)
	d.ui.toast("호신물 — 감응 매듭을 지녔다 (Q: 지니기·풀기)", "item")
	d.camera(null)
	# 곽칠성 — 초롱(굴 안은 어둡다)
	d.face_actor("gwak", null, "player")
	await d.ui.say("곽칠성", ["불 없이 들면 못 나오오."])
	if not S.has(D.LANTERN): d.give(D.LANTERN)
	d.main.lantern = true
	d.cutscene(false)
	d.journal_note("심방에게 감응 매듭을 받았다 · 곽칠성의 초롱")
	if d.onboard != null:
		d.onboard.once("KNOT", "감응 매듭 — 흔적 곁에 서서 매듭을 본다. 떨리는가, 가만한가.   Q 지니기·풀기", func(): return d.sensing.level > 0.3, 10.0)

# 살펴보기(흔적마다). 매듭을 지녔으면 매듭의 모양을 한 줄 덧붙인다 — 결론은 쓰지 않는다
const LOOKS := {
	"rope": ["끊긴 금줄", ["금줄이 입구 바위 사이에서 끊겨 늘어졌다.", "끝이 칼로 자른 듯 반듯하다."], "rope_cut", "human"],
	"snake_tr": ["흙 위의 자국", ["굵은 몸이 기어 들어간 자국. 비늘 결이 그대로 찍혔다.", "굴 안쪽으로 이어진다."], "snake_track", "other"],
	"shoe_tr": ["발자국", ["가죽신 발자국. 둘이다. 굴 안으로 들었다.", "이 마을 사람들은 짚신이나 미투리를 신는다."], "shoe_track", "human"],
	"fake_tr": ["넓게 끈 자국", ["풀밭에서 굴로, 사람 어깨너비로 넓게 끈 자국. 큰 뱀이 지나간 듯도 하다.", "그런데 비늘 결이 없다. 가장자리에 짚 부스러기."], "fake_track", "human"],
	"altar": ["옛 제단", ["옛 제단 돌. 오래된 촛농 위에 흙 묻은 발자국.", "제물상이 비었다. 떡 부스러기 위로 굵게 끌고 간 자국 — 그리고 놋그릇 놓였던 자리만 둥글게 깨끗하다."], "offer_gone", "mixed"],
	"stele": ["옛 비석", ["입구 곁 닳은 비석. 글자는 다 읽을 수 없다.", "곽칠성: “판관이 뱀을 베었다는 비석이라오. 그게 지금 굴에 있는 것과 같은 건지는 모르오.”"], "stele", ""],
	"sack": ["풀숲", ["풀숲에 찢어진 짚 섬 하나와 새끼줄.", "섬 밑바닥이 흙에 쓸려 닳았다. 넓게 끈 자국은 여기서 시작된다."], "", "human"],
	"dig": ["파헤친 자리", ["굴 바닥을 파헤친 구덩이. 깨진 독 조각, 버린 곡괭이 자루.", "구덩이 곁에 흙 묻은 놋그릇 — 제단에서 사라진 그릇이다."], "dig_site", "human"],
	"shed": ["허물", ["굴 안쪽 바닥에 큰 허물.", "사려 있던 구렁이보다 조금 작다. 오래된 것이다."], "shed", "other"],
}

func look(id: String) -> void:
	var L: Array = LOOKS[id]
	var lines: Array = (L[1] as Array).duplicate()
	var tr := String(L[3])
	var knot: bool = d.sensing != null and d.sensing.sensing()
	if knot and tr != "":
		lines.append(d.sensing.line(tr))
		flag("k_" + id, tr)
		if tr == "other": d.sensing.boost(0.9, 2.0)
	await d.ui.examine(String(L[0]), lines, "clue")
	if String(L[2]) != "": d.learn_clue(String(L[2]))
	if id == "sack": flag("sack_found")
	if knot and tr != "": _observe(id, tr)
	if id == "dig": await _dig()
	_knot_rules()

const OBS_ABOUT := { rope = "끊긴 금줄", snake_tr = "뱀 자국", shoe_tr = "가죽신 발자국", fake_tr = "넓게 끈 자국", altar = "옛 제단", sack = "짚 섬", dig = "도굴 자리", shed = "허물" }
func _observe(id: String, tr: String) -> void:
	var how: String = { "human": "매듭은 가만했다.", "other": "매듭이 떨었다.", "mixed": "매듭이 떨리다 멎다 했다." }[tr]
	d.onboard.observe(String(OBS_ABOUT.get(id, id)), "%s 곁에서 %s" % [String(OBS_ABOUT.get(id, id)), how])

func _knot_rules() -> void:
	var still := 0; var trem := 0
	for k in S.flags:
		if not String(k).begins_with("k_"): continue
		if String(S.flags[k]) == "human": still += 1
		elif String(S.flags[k]) == "other": trem += 1
	if still >= 2 and trem >= 1: d.learn_rule("R_KNOT_STILL")
	if String(S.flags.get("k_fake_tr", "")) == "human" and String(S.flags.get("k_snake_tr", "")) == "other": d.learn_rule("R_FAKE_TRACK")
	if String(S.flags.get("k_altar", "")) == "mixed": d.learn_rule("R_MIXED_ALTAR")

func _dig() -> void:
	if f("pit_filled"): return
	var i: int = await d.ui.choice("", [{ label = "놋그릇을 챙기고 구덩이를 메운다" }, { label = "그대로 둔다" }])
	if i != 0: return
	await d.ui.fade(true, 0.5)
	flag("bowl_got"); flag("pit_filled")
	d.give(D.BOWL)
	await d.ui.fade(false, 0.5)
	await d.ui.caption("흙을 긁어모아 구덩이를 메웠다. 굴 바닥이 다시 고르다.", 2.4)
	d.journal_note("굴 안 도굴 자리를 메우고 놋그릇을 챙겼다")

# 굴(실내 공간 jj_sagul) 들어가기: 등불이 없으면 막는다 — region_main.indoor_gate
func indoor_gate(iid: String) -> String:
	if iid == D.SAG and not S.has(D.LANTERN): return "굴 안이 칠흑이다. 불 없이는 들 수 없다."
	return ""

# ---------------------------------------------------------------------------
# S7005 굴 안 — 실제 큰 뱀, 도굴 흔적, 매듭 반응, 벽 너머 훨씬 큰 잔영
# ---------------------------------------------------------------------------
func s7005() -> void:
	S.seen["S7005"] = true
	d.cutscene(true)
	d.camera({ "focus": "snake_face", "distance": 14.0, "pitch": 56.0 })
	await d.ui.caption("등불이 굴 벽을 핥는다. 안쪽에 굵은 몸이 사려 있다 — 구렁이다.", 2.8)
	d.learn_clue("snake_seen")
	await d.ui.caption("그 앞 바닥이 파헤쳐져 있다.", 2.0)
	d.camera({ "focus": "deep", "distance": 17.0, "pitch": 52.0 })
	flag("shade_wake")
	d.sensing.boost(1.0, 9.0)
	await R([{ "spirit": "shade", "do": "place", "at": "shade_a" }, { "spirit": "shade", "do": "appear" }])
	await d.ui.caption("품의 매듭이 세차게 떤다.", 2.0)
	await R([{ "spirit": "shade", "do": "move", "to": ["shade_b"], "speed": 2.2 }])
	await d.ui.caption("안쪽 끝 벽 너머로, 굴보다 긴 무엇이 천천히 지나갔다.", 2.6)
	await R([{ "spirit": "shade", "do": "vanish" }])
	d.learn_clue("shade")
	unflag_wake()
	d.camera(null)
	await d.ui.caption("옆 굴 쪽에서 가는 숨소리가 들린다.", 2.2)
	d.cutscene(false)

func unflag_wake() -> void:
	S.flags.erase("shade_wake"); d.mark_dirty()

# ---------------------------------------------------------------------------
# S7006 아이 — 먼저 찾을 수 있다. 구조만 하고 나올 수도 있다(결말 B)
# ---------------------------------------------------------------------------
func s7006() -> void:
	d.cutscene(true)
	await d.ui.caption("옆 굴 바위 밑에 아이가 웅크려 있다. 숨이 고르다.", 2.4)
	await d.ui.say("아이", ["…등불 든 아저씨 둘이 굴로 들어가길래 따라갔어. 큰 뱀이 나와서 여기 숨었어."])
	flag("child_found")
	S.seen["S7006"] = true
	d.learn_clue("child_story")
	var i: int = await d.ui.choice("", [{ label = "아이를 업고 굴 밖으로 나간다" }, { label = "조금만 여기 있어라." }])
	if i != 0:
		d.cutscene(false); return
	await d.ui.fade(true, 0.7)
	flag("child_saved")
	d.teleport_to("gw_gather", "up")
	d.anim_actor("mother", "idle")
	await wait_loaded(4.0)
	await d.ui.fade(false, 0.7)
	await d.ui.caption("굴 밖. 덕이 어미가 아이를 끌어안는다.", 2.4)
	d.journal_note("덕이를 옆 굴에서 업어 나왔다")
	d.cutscene(false)
	if f("snake_dead"):
		await resolve("C"); return
	await decide()

# 구조 뒤: 굴을 막을까(B), 굴 안에 남은 일을 할까(A·C)
func decide() -> void:
	await d.ui.say("김녕 장정", ["아이는 찾았소. 저 굴은… 돌로 막아 버립시다."])
	var i: int = await d.ui.choice("", [{ label = "굴을 막읍시다." }, { label = "아직 굴 안에 남은 일이 있소." }])
	if i == 0:
		await resolve("B")
	else:
		await d.ui.say("곽칠성", ["…해 지기 전에 나오시오."])
		d.journal_note("굴 안엔 아직 구렁이와 파헤친 자리가 남았다")

# A — 놋그릇을 찾고 구덩이를 메운 뒤 심방과 함께 제물을 다시 올리고 금줄을 맨다
func ritual_offer() -> void:
	var i: int = await d.ui.choice("", [{ label = "심방과 함께 제물을 다시 올리고 금줄을 맨다" }, { label = "아직이오." }])
	if i != 0: return
	d.cutscene(true)
	await d.ui.fade(true, 0.7)
	d.teleport_to("altar_look", "up")
	d.place_actor("simbang", "jemul", null, "up")
	d.place_actor("gwak", "cave_mid", null, "up")
	await wait_loaded(4.0)
	await d.ui.fade(false, 0.7)
	d.anim_actor("simbang", "ritual")
	d.camera({ "focus": "altar_look", "distance": 13.0, "pitch": 55.0 })
	await d.ui.caption("심방이 요령을 흔든다. 놋그릇에 쌀을 담고 떡을 괴어 제단 돌에 올린다.", 2.8)
	d.take(D.BOWL)
	d.world.set_prop_state("jj_sc_sagul_jemul", "NORMAL")
	flag("ritual_done")
	d.camera({ "focus": "snake_face", "distance": 15.0, "pitch": 55.0 })
	await d.ui.caption("안쪽에 사려 있던 구렁이가 몸을 푼다.", 2.0)
	await d.move_actor("snake", ["crevice"], 1.6, "walk", "idle")
	flag("snake_gone")
	d.show_actor("snake", false)
	await d.ui.caption("구렁이는 바위틈으로 천천히 들어갔다.", 2.2)
	d.camera({ "focus": "deep", "distance": 17.0, "pitch": 52.0 })
	flag("shade_wake")
	d.sensing.boost(0.6, 6.0)
	await R([{ "spirit": "shade", "do": "place", "at": "shade_b" }, { "spirit": "shade", "do": "appear" },
		{ "spirit": "shade", "do": "move", "to": ["shade_a"], "speed": 2.6 }])
	await d.ui.caption("벽 너머의 긴 것이 한 번 더 지나가고, 숨이 잦아든다.", 2.6)
	await R([{ "spirit": "shade", "do": "vanish" }])
	unflag_wake()
	await d.ui.fade(true, 0.6)
	d.teleport_to("gw_gather", "up")
	d.world.set_prop_state("jj_sc_sagul_geumjul", "NORMAL")
	d.anim_actor("simbang", "idle")
	d.place_actor("simbang", "home"); d.place_actor("gwak", "home")
	await d.ui.fade(false, 0.6)
	d.camera(null)
	await d.ui.caption("입구에 새 금줄을 맸다.", 2.0)
	d.cutscene(false)
	await resolve("A")

# C — 구렁이를 벤다(짐승 상대 싸움). 잔영은 남는다
func snake_face() -> void:
	if not S.has_clue("snake_seen"): d.learn_clue("snake_seen")
	var i: int = await d.ui.choice("사려 있는 구렁이가 고개를 든다.", [{ label = "칼을 뽑는다" }, { label = "조용히 물러선다" }])
	if i != 0:
		d.teleport_to(d.anchor("snake_face") + Vector2(0, 1.8), "up"); return
	flag("snake_fought")
	d.show_actor("snake", false)
	d.teleport_to("fight_start", "up")
	var res: String = await d.combat("snake", { "allow_flee": true })
	flag("fight_result", res)
	var rep: Array = d.combat_view.human_report()
	var at: Vector2 = d.anchor("snake_spot")
	for r in rep: at = r.pos
	d.runner.log_line("fight", [res, rep.map(func(r): return [r.id, r.out, r.get("hp", 0)])])
	if res == "win":
		flag("snake_dead")
		d.data.anchors["snake_spot"] = [at.x, at.y]
		d.end_combat()
		d.place_actor("snake_body", [at.x, at.y], null, "right")
		d.anim_actor("snake_body", "fall")
		d.world.set_prop_state(D.SAG + "/shed", "NORMAL")
		await d.ui.caption("구렁이가 늘어졌다.", 2.0)
		d.sensing.boost(1.0, 6.0)
		await d.ui.caption("…그런데 매듭이 멎지 않는다.", 2.0)
		flag("shade_wake")
		await R([{ "spirit": "shade", "do": "place", "at": "shade_a" }, { "spirit": "shade", "do": "appear" },
			{ "spirit": "shade", "do": "move", "to": ["shade_b"], "speed": 2.8 }])
		await d.ui.caption("벽 너머에서, 베인 뱀보다 훨씬 긴 무엇이 지나간다.", 2.6)
		await R([{ "spirit": "shade", "do": "vanish" }])
		unflag_wake()
		if not S.has_clue("shade"): d.learn_clue("shade")
		if f("child_saved"): await resolve("C")
		else: d.journal_note("구렁이를 베었다. 벽 너머의 것은 남았다")
	elif res == "lose":
		await d.ui.fade(true, 0.8)
		d.end_combat()
		d.teleport_to("gw_gather", "up")
		await wait_loaded(4.0)
		await d.ui.fade(false, 0.8)
		await d.ui.caption("정신이 드니 굴 밖이다. 곽칠성이 끌어냈다고 한다.", 2.4)
		d.show_actor("snake", true)
	else:
		d.end_combat()
		await d.ui.caption("물러섰다. 구렁이가 다시 몸을 사린다.", 2.0)
		d.show_actor("snake", true)
	d.mark_dirty()

# ---------------------------------------------------------------------------
# S7007 결말 → S7008 곽칠성의 증언
# ---------------------------------------------------------------------------
func resolve(o: String) -> void:
	if resolved(): return
	setv("CASE_JEJU_OUTCOME", o)
	d.runner.log_line("outcome", o)
	S.seen["S7007"] = true
	flag("resolved")
	if o == "B": flag("sealed")
	await d.ui.fade(true, 0.8)
	S.phase = "after"
	d.on_phase()
	d.set_hour(8.0)
	_world_state()
	d.teleport_to("gw_gather", "up")
	await d.ui.fade(false, 0.8)
	await d.ui.caption(ENDING_EXTRA[o], 3.0)
	d.journal_note("사건 종결 — 「%s」" % CASE_TITLE)
	await d.show_ending()
	await d.wait(0.5)
	await R([{ "event": "S7008" }])

# S7008 — 사건 뒤 곽칠성이 먼저 찾아온다. 나무패. 이겸의 메모 없음 — 플레이어 자신의 첫 문장
func s7008() -> void:
	if f("gwak_tally"): return
	d.cutscene(true)
	d.place_actor("gwak", "gw_gwak", null, "up")
	d.anim_actor("gwak", "walk")
	await d.move_actor("gwak", [d.anchor("gw_gather") + Vector2(1.2, 0.6)], 1.2, "walk", "idle")
	d.face_actor("gwak", null, "player")
	await d.ui.caption("곽칠성이 먼저 다가온다. 품에서 닳은 나무패 하나를 꺼낸다.", 2.6)
	d.anim_actor("gwak", "give")
	await d.ui.say("곽칠성", ["저 숫자 때문에 사람이 죽었소."])
	await d.ui.say("나그네", ["박규상?"])
	await d.ui.caption("곽칠성이 오래 나그네를 본다.", 1.8)
	await d.ui.say("곽칠성", ["아직 살아 있소?"])
	d.anim_actor("gwak", "idle")
	d.give(D.TALLY)
	d.learn_clue("tally")
	d.learn_clue("park_alive")
	flag("gwak_tally")
	S.seen["S7008"] = true
	setv("MAIN_GWAK_FOUND", true)
	setv("ITEM_KEY_001", true)
	await d.ui.caption("기록책을 편다. 이번 장에는 스승의 글씨가 없다.", 2.4)
	setv("PLAYER_FIRST_LINE", D.PLAYER_LINE)
	d.ui.toast("나의 기록 — " + D.PLAYER_LINE, "journal")
	await d.ui.caption("“%s”" % D.PLAYER_LINE, 3.4)
	S.phase = "done"
	d.on_phase()
	d.cutscene(false)
	finale_gate()
	d.save()

func act6_ok() -> bool:
	for k in FINALE_NEEDS:
		if S.vars.get(k, Progress.get_var(k, false)) != true: return false
	return true

# 최종장 문: ACT 2~5를 모두 마쳤으면 한양으로 돌아가는 길이 열린다
func finale_gate() -> void:
	if not act6_ok():
		d.runner.log_line("finale", "not_yet")
		return
	if not bool(S.vars.get("ACT6_OPEN", false)):
		setv("ACT6_OPEN", true)
		Discovery.tell(Discovery.NATION, "region:GG_HANYANG")
		await d.ui.caption("한양으로 돌아갈 때다. 배는 화북포에서 뜬다.", 2.8)
		d.journal_note("한양으로 — 서강 옛 창고, 칠패")

func gwak_done() -> void:
	await d.ui.say("곽칠성", ["한양에 가거든 서강 옛 창고 벽의 홈을 보시오. 그 패가 들어맞을 거요."])
	var ok := bool(S.vars.get("ACT6_OPEN", false))
	var i: int = await d.ui.choice("", [{ label = "한양으로 돌아간다 (화북포 뱃길 · 역마)", disabled = not ok, hint = "아직 끝내지 못한 일이 있다." }, { label = "조금 더 있겠소." }])
	if i == 0 and ok: await go_hanyang()

func hanyang_target() -> Dictionary:
	for r in Travel.routes():
		if String(r.id) != R01: continue
		var ps = r.json.get("portals", {})
		for e in ["to", "from"]:
			var p = ps.get(e) if ps is Dictionary else null
			if p is Dictionary and String(p.get("region", "")) == "GG_HANYANG" and p.has("x"):
				return { id = "jeju_hanyang", kind = "region", target = "GG_HANYANG", tx = float(p.x), tz = float(p.z), label = "한양 (뱃길 · 역마)", fast = true }
	return {}

func go_hanyang() -> void:
	var pt := hanyang_target()
	if pt.is_empty():
		d.ui.toast("길이 아직 닦이지 않았다", "info"); return
	await d.ui.caption("화북포에서 배를 타고 관두포로, 역마를 갈아타며 남원을 지나 한양까지 올라간다.", 2.6)
	S.time = d.main.hour
	S.save()
	d.runner.log_line("travel", ["GG_HANYANG"])
	d.main._travel(pt)

# ---------------------------------------------------------------------------
# 사건 기록(R)
# ---------------------------------------------------------------------------
const OUTCOME_TEXT := {
	"A": "덕이를 옆 굴에서 업어 나왔다. 도굴꾼이 판 구덩이를 메우고, 그들이 흙을 퍼 담던 놋그릇을 찾아 심방과 함께 제단에 다시 올렸다. 구렁이는 바위틈으로 물러났다.",
	"B": "덕이를 옆 굴에서 업어 나왔다. 마을 사람들이 굴 입구를 돌로 막았다.",
	"C": "굴 안쪽에서 구렁이를 베었다. 덕이는 옆 굴에서 업어 나왔다.",
}
const ENDING_EXTRA := {
	"A": "입구에 새 금줄이 매였다. 벽 너머의 긴 숨은 한 번 더 지나가고 잦아들었다. 무엇이었는지는 모른다.",
	"B": "구렁이도, 파헤친 자리도, 벽 너머의 긴 것도 돌 뒤에 그대로 남았다. 밤이면 돌 틈으로 숨소리가 샌다고들 한다.",
	"C": "마을은 옛 판관 이야기를 다시 꺼냈다. 그러나 매듭은 멎지 않았다 — 벽 너머의 긴 것은 그날 밤에도 지나갔다.",
}

func solutions() -> Array:
	return [
		{ "id": "seal", "title": "굴을 막는다", "available": f("child_saved"), "text": "아이는 찾았다. 마을 사람들은 굴을 돌로 막자고 한다.", "hint": "" },
		{ "id": "restore", "title": "제물과 굴 길을 되돌린다", "available": f("bowl_got") and f("pit_filled"),
			"text": "놋그릇을 찾았고 파헤친 자리를 메웠다. 심방과 함께 제물을 다시 올린다.",
			"hint": "제물상의 그릇은 어디로 갔을까." if S.has_clue("offer_gone") and not f("bowl_got") else "" },
		{ "id": "kill", "title": "구렁이를 벤다", "available": S.has_clue("snake_seen"), "text": "굴 안쪽에 사려 있는 구렁이와 맞선다.", "hint": "" },
	]

func summary() -> Array:
	var p := []
	p.append("제주 화북포에서 귀양 온 늙은 짐꾼 곽칠성을 찾았다. 서강 창고 일을 묻자 “그 일은 끝났소.” 그때 김녕에서 아이가 없어졌다는 소식이 왔다.")
	if f("s7003"): p.append("김녕 굴 입구 — 끊긴 금줄, 빈 제물상, 큰 뱀이 기어 든 자국, 가죽신 발자국, 그리고 넓게 끈 '뱀 자국' 하나.")
	if f("simbang_here"): p.append("심방이 감응 매듭을 건넸다. 곽칠성은 초롱을 건넸다.")
	if S.has_clue("shade"): p.append("굴 안에 실제 구렁이가 사려 있었고, 안쪽 끝 벽 너머로는 그보다 훨씬 긴 무엇이 지나갔다.")
	if f("child_saved"): p.append("덕이를 옆 굴에서 업어 나왔다.")
	if resolved():
		p.append(OUTCOME_TEXT.get(outcome(), ""))
		p.append(ENDING_EXTRA.get(outcome(), ""))
	if f("gwak_tally"):
		p.append("사건 뒤 곽칠성이 먼저 와서 강복의 곡물 수량패를 내놓았다. “저 숫자 때문에 사람이 죽었소.” — 박규상의 이름에 “아직 살아 있소?”")
		p.append("나의 기록 — “%s”" % D.PLAYER_LINE)
	return p

func journal() -> Dictionary:
	if not f("case_started"):
		return { "cases": [], "empty": "아직 제주에서 적힌 사건이 없다." }
	var solved: bool = resolved() and S.phase == "done"
	return { "cases": [{ "id": "jeju", "title": CASE_TITLE, "status": "solved" if solved else "active", "rules_title": "굴에서 본 것",
		"summary": summary(), "clues": [], "rules": [], "solutions": solutions(), "notes": S.notes }] }

func ending_data() -> Dictionary:
	var o := outcome()
	return {
		"case_title": CASE_TITLE,
		"title": { "A": "다시 맨 금줄", "B": "막힌 굴", "C": "베인 뱀" }.get(o, CASE_TITLE),
		"outcome": o,
		"paragraphs": [OUTCOME_TEXT.get(o, ""), ENDING_EXTRA.get(o, "")],
		"record": "덕이를 찾았다. 감응 매듭을 지녔다.",
	}
