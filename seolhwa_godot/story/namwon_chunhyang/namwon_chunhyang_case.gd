# 사건 「남원의 약속」 PART I — 데이터로 쓰기 번거로운 연출(1A·1B 각본 시점, 그네 흔들기, 방자와 부딪힘, 2A, 월매 집, 며칠의 압축, 백년가약, 5A 이별)과
# 기록책·소리·떠남(LEFT_AFTER_PART1). 데이터(namwon_chunhyang_data.gd)의 { "call": 이름 }과 조건식 fn('이름')이 이 함수들을 부른다.
# 원칙(시나리오 §1·§2): 플레이어는 곁에서 보고 거든다 — 춘향·몽룡의 핵심 행동(부르기·거절·약속·이별)을 대신하지 않는다. 점수·호감도 없음.
extends RefCounted

const D := preload("res://story/namwon_chunhyang/namwon_chunhyang_data.gd")
const Progress := preload("res://scripts/region/progress.gd")
const CASE_TITLE := "남원의 약속"
const REGION := "JL_NAMWON_UNBONG"
const V_PART1 := "CASE_NAMWON_CHUNHYANG_PART1_COMPLETE"
const V_LEFT := "CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1"
# 그네(kit story/chunhyang swing — 배치 ti_swing): 가로대 높이·흔들림 주기(줄 7.6m 진자 ≈ 5.5초)
const SWING_ID := "ti_swing"
const SWING_H := 8.5
const SWING_PERIOD := 5.5
const SWING_AMP := 0.5
const SWING_HIGH := 0.95
# 각본 시점(배치 파일 cameras — 확정값과 같다). pos·look의 가운데 값은 지형 위 높이
const CAM_1A := { pos = [-3246.0, 7.0, 420.0], look = [-3318.0, 6.0, 446.0], fov = 30.0 }
const CAM_1B := { pos = [-3286.2, 2.5, 450.8], look = [-3330.0, 4.2, 443.0], fov = 34.0 }
const CAM_2A := { "focus": [-3323.6, 439.0], "pitch": 34.0, "distance": 16.0, "fov": 40.0 }
const CAM_5A := { "focus": [-3212.0, -3.0], "pitch": 24.0, "distance": 24.0, "fov": 36.0 }

var d      # story_director
var S:
	get: return d.S
var _sw_t := 0.0
var _sw_amp := 0.0
var _sw_boost := 0.0
var _amb_t := 3.0
var _drum_t := 9.0
var _creak_t := 0.0

func _init(director) -> void:
	d = director

func R(steps: Array) -> void:
	await d.runner.exec(steps, d.runner.gen)

func flag(k: String, v = true) -> void:
	S.flags[k] = v; d.runner.log_line("flag", [k, v]); d.mark_dirty()

func unflag(k: String) -> void:
	S.flags.erase(k); d.mark_dirty()

func f(k: String) -> bool: return S.is_flag(k)

func say(who: String, lines) -> void:
	await d.ui.say(who, lines if lines is Array else [lines])

func beat(id: String) -> void:
	flag("beat_" + id)

# 대본 시험 화면 검토(--storyshots): 컷의 그 순간을 찍는다(시험이 아니면 아무것도 안 함)
func _cut(nm: String) -> void:
	if d.test != null and d.test.has_method("cut"): await d.test.cut(nm)

# ---------------------------------------------------------------------------
# 판정(조건식 fn)
# ---------------------------------------------------------------------------
func is_night() -> bool:
	var h: float = d.main.hour
	return h >= 19.0 or h < 5.0

# PART II 열림(결정 §4) — 지금은 판정만 있고 이 조건이 참이어도 PART II 장면·단계·차림은 하나도 서지 않는다
func part2_open() -> bool:
	var v := func(k: String) -> bool: return bool(S.vars.get(k, Progress.get_var(k, false)))
	return v.call(V_PART1) and v.call(V_LEFT) and (v.call("CASE_GANGNEUNG_COMPLETE") or v.call("CASE_GYEONGJU_COMPLETE") or v.call("CASE_HWANGJU_COMPLETE"))

# ---------------------------------------------------------------------------
# 음악·소리·그네(매 프레임 — story_director._update_ambient)
# ---------------------------------------------------------------------------
func music_wanted() -> String:
	if S.phase == "dano" or S.phase == "courtship":
		var h: float = d.main.hour
		if h >= 6.0 and h < 18.0 and not f("in_night_scene"): return "bgm_dano_bright"   # §3 BGM도 밝다
	return ""   # 저녁·밤·이별(§17 과한 음악을 쓰지 않는다)

func ambient(dt: float) -> void:
	_update_swing(dt)
	if S.phase != "dano" and S.phase != "courtship": return
	if is_night() or d.main.hour >= 18.0: return
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var near: bool = pp.distance_to(d.anchor("ch_ssireum")) < 75.0 or pp.distance_to(d.anchor("ch_market")) < 50.0
	if not near: return
	_amb_t -= dt
	if _amb_t <= 0.0:
		_amb_t = 5.6
		d.sfx("crowd_dano", "ch_ssireum" if pp.distance_to(d.anchor("ch_ssireum")) < pp.distance_to(d.anchor("ch_market")) else "ch_market")
	_drum_t -= dt
	if _drum_t <= 0.0:
		_drum_t = 23.0
		d.sfx("drum_far", "ch_ssireum")

func _swing_node() -> Node3D:
	var pl = d.main.get("placement")
	if pl == null: return null
	var e = pl.gated.get(SWING_ID)
	if e == null or not is_instance_valid(e.node) or not (e.node as Node3D).is_inside_tree(): return null
	return e.node

# 춘향이 그네를 타는 동안(단오 낮, 내려오기 전) — 이 플래그가 서는 동안만 흔든다
func rider_on() -> bool:
	return S.phase == "dano" and not f("chun_landed") and not f("chun_left_swing")

func swing_boost(sec := 6.0) -> void:
	_sw_boost = sec

func _update_swing(dt: float) -> void:
	_sw_t += dt
	_sw_boost = maxf(0.0, _sw_boost - dt)
	var want := 0.0
	if rider_on(): want = SWING_HIGH if _sw_boost > 0.0 else SWING_AMP
	_sw_amp = move_toward(_sw_amp, want, dt * (0.35 if want > _sw_amp else 0.18))
	var n := _swing_node()
	if n == null: return
	var seat: Node3D = n.get_node_or_null("seat")
	if seat == null: return
	var a := _sw_amp * sin(TAU * _sw_t / SWING_PERIOD)
	var piv := Vector3(0, SWING_H, 0)
	seat.transform = Transform3D(Basis(Vector3.RIGHT, a), piv) * Transform3D(Basis(), -piv)
	if rider_on() and d.actors.has("chunhyang"):
		var ac: Dictionary = d.actors.chunhyang
		var wp: Vector3 = n.transform * (seat.transform * Vector3(0, 0.93, 0))
		ac.scripted = true
		ac.pos = Vector3(wp.x, d.world.height_at(wp.x, wp.z), wp.z)
		ac.y_abs = wp.y
		ac.facing = "down"
		var pp: Vector3 = d.main.player_pos
		_creak_t -= dt
		if _creak_t <= 0.0 and Vector2(pp.x - wp.x, pp.z - wp.z).length() < 40.0 and absf(a) > _sw_amp * 0.9 and _sw_amp > 0.3:
			_creak_t = SWING_PERIOD * 0.45
			d.sfx("rope_creak", Vector3(wp.x, wp.y + 3.0, wp.z))
	# 이별 뒤 춘향: 플레이어가 멀어지면 집으로(말을 걸지 않아도 된다)
	if S.phase == "farewell" and f("farewell_scene_done") and not f("chun_home"):
		var pp2 := Vector2(d.main.player_pos.x, d.main.player_pos.z)
		if pp2.distance_to(d.anchor("ch_farewell_stand")) > 60.0: chun_goes_home()

# ---------------------------------------------------------------------------
# 카메라 도움
# ---------------------------------------------------------------------------
func _shot(c: Dictionary) -> void:
	var w = d.world
	var p := Vector3(float(c.pos[0]), w.height_at(float(c.pos[0]), float(c.pos[2])) + float(c.pos[1]), float(c.pos[2]))
	var l := Vector3(float(c.look[0]), w.height_at(float(c.look[0]), float(c.look[2])) + float(c.look[1]), float(c.look[2]))
	d.main.rig.focus = null; d.main.rig.override = null
	d.main.rig.shot = { pos = p, look = l, fov = float(c.fov) }
	if d.main.has_method("set_occ_script"): d.main.set_occ_script({ "focus": l, "r": 0.0, "near": 0.0 })
	if d.main.has_method("set_cine_sharp"): d.main.set_cine_sharp(true)

func _cam_end() -> void:
	d.main.rig.shot = null
	d.camera(null)
	if d.main.has_method("set_occ_script"): d.main.set_occ_script(null)
	if d.main.has_method("set_cine_sharp"): d.main.set_cine_sharp(false)

func _talk_cam(a, b) -> void:
	var tc: Dictionary = d.talk_camera_base()
	if tc.is_empty(): return
	var p: Vector2 = (d.anchor(a) + d.anchor(b)) * 0.5
	tc = tc.duplicate(); tc.focus = [p.x, p.y]
	d.camera(tc)

func _place(id: String, at, facing := "") -> void:
	d.place_actor(id, at, null, facing)

func _pp() -> Vector2:
	return Vector2(d.main.player_pos.x, d.main.player_pos.z)

# ---------------------------------------------------------------------------
# C0001 — 사건이 선다(조용히)
# ---------------------------------------------------------------------------
func start_case() -> void:
	if f("case_started"): return
	flag("case_started")
	flag("returned_namwon")
	d.sfx("journal_stamp")
	d.ui.toast("새 사건 — 「%s」" % CASE_TITLE, "journal")
	d.journal_note("남원에 다시 왔다. 단오장이 섰다고 한다")
	if d.onboard != null: d.onboard.on_case_started()

# §4 CAMERA 1A — 앞 장터 사람, 뒤 누각, 그보다 뒤 그네. 그네가 한 번 높이 올랐다 내려온다. 얼굴은 보이지 않는다
func vista_1a() -> void:
	flag("vista_seen")
	beat("dano_swing")
	d.cutscene(true)
	# 플레이어는 잠시 단오 마당 가운데로(그림은 숨김) — 군중 LOD가 이 컷을 채우게. 컷이 끝나면 제자리
	var back := _pp()
	d.main.player.visible = false
	d.teleport_to("ch_1a_hold")
	_shot(CAM_1A)
	swing_boost(SWING_PERIOD * 1.2)
	d.sfx("drum_far", "ch_ssireum")
	await d.wait(1.0)
	await d.ui.caption("광한루. 누각 앞 마당에 사람이 가득하다.", 2.6)
	await _cut("02_1A_crowd_swing")
	await d.ui.caption("누각 너머 버드나무 사이로 그네가 높이 오른다.", 2.6)
	d.learn_clue("dano")
	await d.wait(0.6)
	d.teleport_to(back)
	d.main.player.visible = true
	_cam_end()
	d.cutscene(false)

# §5 방자와 부딪힘 · 부채 · 알아봄
func bump() -> void:
	flag("bump_done")
	var pp := _pp()
	var from := pp + Vector2(3.2, -2.0)
	var to := pp + Vector2(0.75, -0.25)
	d.cutscene(true)
	_place("bangja", from, "left")
	_place("mongryong", "ch_mong_wait", "right")
	d.mark_dirty(); d._refresh()
	_talk_cam([to.x, to.y], [pp.x, pp.y])
	await d.move_actor("bangja", [to.x, to.y], 3.4, "run", "idle")
	d.face_actor("player", null, "bangja")
	d.shake(0.05, 0.25)
	await say("방자", "아이쿠.")
	await _cut("04_bangja_bump")
	d.data.anchors["ch_fan_drop"] = [pp.x + 0.35, pp.y - 0.15]
	flag("fan_dropped")
	await d.ui.caption("방자가 들고 있던 부채를 떨어뜨렸다.", 1.8)
	await R([{ "choice": "", "options": [
		{ "label": "(부채를 주워 준다)", "id": "fan_return", "do": [{ "flag": "fan_returned" }] },
		{ "label": "(그냥 지나간다)", "id": "fan_pass", "do": [{ "flag": "fan_passed" }] }] }])
	flag("fan_picked")
	if f("fan_returned"):
		await say("방자", "고맙소.")
		await say("방자", "…어디서 본 얼굴인데.")
		await d.wait(0.8)
		await say("방자", "북쪽 범 일 때 있던 길손 아니오?")
		await R([{ "choice": "", "options": [
			{ "label": "맞소.", "id": "recog_yes", "do": [{ "flag": "recog_yes" }, { "say": "방자", "lines": ["그럴 줄 알았소. 그때 고을이 다 뒤집혔지."] }] },
			{ "label": "사람 잘못 봤소.", "id": "recog_no", "do": [{ "flag": "recog_no" }, { "say": "방자", "lines": ["그런가? 닮은 사람도 다 있네."] }] },
			{ "label": "(대답하지 않는다)", "id": "recog_silent", "do": [{ "flag": "recog_silent" }, { "say": "방자", "lines": ["…뭐, 아무렴 어떻소."] }] }] }])
	else:
		d.anim_actor("bangja", "idle")
		await d.ui.caption("방자가 투덜거리며 부채를 주워 든다.", 1.8)
		await say("방자", "에이, 사람 참.")
	flag("met_bangja")
	await say("몽룡", "방자야.")
	d.face_actor("bangja", null, "mongryong")
	await say("방자", "예, 도련님.")

# §6 CAMERA 1B — 몽룡의 뒤, 먼 그네(몸을 훑는 클로즈업 없음)
func swing_1b() -> void:
	beat("mong_sees")
	await d.ui.fade(true, 0.5)
	_place("mongryong", "ch_mong_view", "left")
	_place("bangja", "ch_1b_bangja", "left")
	d.teleport_to("ch_1b_player", "left")
	_shot(CAM_1B)
	swing_boost(SWING_PERIOD * 1.3)
	await d.wait(0.3)
	await d.ui.fade(false, 0.6)
	await d.wait(1.6)
	await _cut("03_1B")
	await d.ui.caption("그네가 나뭇잎 위로 높이 오른다. 다홍 치맛자락, 웃음소리.", 2.8)
	d.learn_clue("swing")
	await d.wait(1.0)
	await d.ui.caption("그네는 다시 나뭇잎 뒤로 내려간다.", 1.8)
	await say("몽룡", "…방자야.")
	await say("방자", "예.")
	await say("몽룡", "저 아이가 누구냐?")
	await say("방자", "성춘향이옵니다.")
	await say("몽룡", "아느냐?")
	await say("방자", "남원에서 춘향 모르면 외지 사람이지요.")
	d.face_actor("bangja", null, "player")
	await d.wait(0.5)
	await say("방자", "딱 이 양반처럼.")
	d.learn_clue("name")
	_cam_end()
	_talk_cam("mongryong", "player")

# §7 방자의 심부름 — 어떤 선택도 진행을 막지 않는다
func errand() -> void:
	d.face_actor("mongryong", null, "bangja")
	await say("몽룡", "가서 잠깐 보자고 전해라.")
	await say("방자", "제가 말입니까?")
	await say("몽룡", "그럼 내가 뛰어가랴?")
	await say("방자", "나으리 자제가 사람 부르는 걸 제가 전하면 아주 좋아하겠습니다.")
	d.face_actor("bangja", null, "player")
	await R([{ "choice": "", "options": [
		{ "label": "같이 가 주지.", "id": "errand_with", "do": [{ "flag": "errand_with" }, { "say": "방자", "lines": ["그럼 갑시다. 둘이 가면 덜 무안하겠지."] }] },
		{ "label": "혼자 가시오.", "id": "errand_alone", "do": [{ "flag": "errand_alone" }, { "say": "방자", "lines": ["…그러지요, 뭐."] }] },
		{ "label": "(무슨 일인지 더 본다)", "id": "errand_watch", "do": [{ "flag": "errand_watch" }] }] }])
	flag("errand_choice")
	if f("errand_watch"):
		await d.ui.caption("몽룡은 그네 쪽에서 눈을 떼지 않는다. 방자가 한숨을 쉬고 걸음을 뗀다.", 2.6)
	d.camera(null)
	d.cutscene(false)
	if f("errand_with"):
		await refusal()
	else:
		# 방자 혼자 그네 쪽으로 — 플레이어는 나중에 그네 곁에서 다시 만난다(트리거 c0202_swing)
		d.move_actor("bangja", ["ch_bangja_swing"], 1.5, "walk", "idle")
		d.ui.toast("방자가 그네 쪽으로 갔다", "info")

# §8 춘향(CAMERA 2A) — 춘향은 몽룡이 부르니까 따라가는 인물이 아니다
func refusal() -> void:
	if f("refusal_seen"): return
	beat("bangja_message")
	d.cutscene(true)
	await d.ui.fade(true, 0.5)
	flag("chun_landed")
	_place("chunhyang", "ch_chun_land", "right")
	_place("hyangdan", "ch_hyangdan", "right")
	_place("bangja", "ch_bangja_swing", "left")
	d.teleport_to("ch_player_swing", "left")
	d.camera(CAM_2A)
	await d.wait(0.3)
	await d.ui.fade(false, 0.6)
	await d.ui.caption("춘향과 향단이 그네에서 내려온다.", 2.0)
	await say("방자", "춘향아.")
	d.face_actor("chunhyang", null, "bangja")
	await say("춘향", "왜.")
	await say("방자", "광한루에 도련님이 계시는데…")
	await say("춘향", "그래서?")
	await say("방자", "잠깐 와 보라신다.")
	await say("춘향", "내가 왜?")
	await say("방자", "…그럴 줄 알았다.")
	await say("춘향", ["나는 관기 점고 나온 사람이 아니야.", "보고 싶으면 본인이 말을 하라 그래."])
	await _cut("05_refusal_2A")
	d.learn_clue("refusal")
	flag("met_chunhyang")
	d.face_actor("bangja", null, "player")
	await say("방자", ["봤지요?", "내가 이럴 줄 알았다니까."])
	# 춘향은 자기 길로 간다
	d.move_actor("hyangdan", ["ch_chun_leave"], 1.3, "walk", "idle")
	await d.move_actor("chunhyang", ["ch_chun_leave"], 1.3, "walk", "idle")
	flag("chun_left_swing")
	flag("refusal_seen")
	d.camera(null)
	d.cutscene(false)
	_place("bangja", "ch_bangja_wait", "down")
	d.ui.toast("방자는 광한루 앞 몽룡에게 돌아갔다", "info")

# §9 몽룡에게 돌아감 — "재미있구나."
func mong_reacts() -> void:
	if f("mong_reacted"): return
	flag("mong_reacted")
	d.cutscene(true)
	_place("mongryong", "ch_mong_wait", "right")
	_place("bangja", "ch_bangja_wait", "left")
	_talk_cam("mongryong", "player")
	await say("몽룡", "뭐라더냐?")
	await say("방자", "보고 싶으시면 직접 말씀하시랍니다.")
	await say("몽룡", "…그래?")
	await say("방자", "화나셨습니까?")
	await say("몽룡", "아니다.")
	await d.ui.caption("몽룡이 잠깐 웃는다.", 1.6)
	await say("몽룡", "재미있구나.")
	d.learn_clue("mong_laugh")

# §10 저녁 — 방자가 다시 부른다. 작은 술병과 찬합(그 장면에서만 드는 물건)
func evening_call() -> void:
	await d.ui.fade(true, 1.0)
	d.set_hour(18.3)
	flag("mong_off")
	S.phase = "courtship"; d.runner.log_line("phase", S.phase); d.on_phase()
	var pp := _pp()
	_place("bangja", [pp.x + 1.6, pp.y + 0.4], "left")
	d.camera(null)
	await d.wait(0.4)
	await d.ui.fade(false, 1.0)
	await say("방자", ["길손.", "어차피 주막 가는 길이면 이것 좀 같이 들고 갑시다."])
	d.give(D.JAR)
	await say("방자", "월매 집이오. 광한루 동쪽, 나루 주막 가는 길에 있소.")
	flag("evening_call")
	await R([{ "discover": "wolmae_house" }])
	d.cutscene(false)
	d.move_actor("bangja", ["ch_bangja_gate"], 1.6, "walk", "idle")

# §11·§12 월매 집 — 월매 · 몽룡 · 춘향
func wolmae_house() -> void:
	beat("first_meeting")
	d.cutscene(true)
	_place("bangja", "ch_bangja_gate", "right")
	flag("wolmae_on")
	d.mark_dirty(); d._refresh()
	_place("wolmae", "ch_wolmae_at_gate", "down")
	d.teleport_to("ch_player_gate", "up")
	d.camera({ "focus": [-3213.0, 459.4], "pitch": 30.0, "distance": 11.5, "fov": 38.0 })
	d.sfx("knock", "ch_wolmae_gate")
	await d.wait(0.6)
	await say("월매", "이게 누구야?")
	d.take(D.JAR)
	await say("방자", "저… 도련님께서.")
	await say("월매", "도련님?")
	flag("mong_on")
	d.mark_dirty(); d._refresh()
	_place("mongryong", "ch_mong_road", "right")
	await d.move_actor("mongryong", ["ch_mong_gate"], 1.4, "walk", "idle")
	d.face_actor("mongryong", null, "wolmae")
	d.face_actor("wolmae", null, "mongryong")
	await say("월매", "사또 자제께서 이 누추한 집엔 웬일이십니까?")
	await say("몽룡", "춘향을 만나러 왔습니다.")
	await say("월매", "그 말을 그렇게 쉽게 하시면 안 됩니다.")
	d.learn_clue("wolmae_word")
	d.face_actor("bangja", null, "player")
	d.face_actor("player", null, "bangja")
	await d.ui.caption("방자와 눈이 마주친다.", 1.6)
	# §12
	flag("chun_on")
	d.mark_dirty(); d._refresh()
	_place("chunhyang", "ch_chun_yard", "down")
	await d.move_actor("chunhyang", ["ch_chun_gate"], 1.2, "walk", "idle")
	d.face_actor("chunhyang", null, "mongryong")
	_place("wolmae", "ch_wolmae_aside", "right")
	await say("춘향", "저를 부르셨다지요.")
	await say("몽룡", "그랬소.")
	await say("춘향", "무슨 일로요?")
	await say("몽룡", "…보고 싶어서.")
	await d.wait(1.2)   # 짧은 침묵
	await say("춘향", "사또 자제들은 원래 사람을 그렇게 부릅니까?")
	await say("몽룡", "잘못했소.")
	await _cut("06_wolmae_house_evening")
	d.learn_clue("sorry")
	await d.wait(0.8)
	# 며칠의 압축(§13) — 자막 없이 다음 날 낮으로
	await d.ui.fade(true, 1.2)
	flag("first_meeting_done")
	unflag("mong_on"); unflag("chun_on"); unflag("wolmae_on")
	d.set_hour(10.5)
	d.camera(null)
	for id in ["chunhyang", "wolmae", "bangja", "hyangdan"]: d.place_actor(id, "home")
	d.journal_note("월매 집 대문 앞에서 몽룡과 춘향이 처음 마주 섰다")
	await d.wait(0.4)
	await d.ui.fade(false, 1.0)
	d.cutscene(false)

# §13 장면 B — 오작교 곁을 함께 걷는 두 사람(대사 없음)
func walk_together() -> void:
	flag("walk_seen")
	d.cutscene(true)
	flag("mong_on")
	d.mark_dirty(); d._refresh()
	_place("chunhyang", "ch_walk_a", "right")
	_place("mongryong", "ch_walk_mong_a", "right")
	d.camera({ "focus": "ch_ojakgyo", "pitch": 30.0, "distance": 24.0, "fov": 38.0 })
	await d.wait(0.6)
	d.move_actor("mongryong", ["ch_walk_mong_b"], 0.9, "walk", "idle")
	await d.move_actor("chunhyang", ["ch_walk_b"], 0.9, "walk", "idle")
	await _cut("06b_walk_ojakgyo")
	d.learn_clue("walk")
	await d.wait(1.0)
	unflag("mong_on")
	d.place_actor("chunhyang", "home")
	d.camera(null)
	d.cutscene(false)

# 방자: 밤에 월매 집으로 — 해 질 때까지 기다릴 수 있다(주막 쉬기와 같은 암전)
func vow_wait_offer() -> void:
	if is_night():
		await say("방자", "해가 졌소. 어서 월매 집으로 갑시다.")
		return
	await R([{ "choice": "", "options": [
		{ "label": "(해 질 때까지 기다린다)", "id": "wait_night", "do": [{ "call": "_wait_night" }] },
		{ "label": "알겠소. 이따 가겠소.", "id": "later", "end": true }] }])

func _wait_night() -> void:
	await d.ui.fade(true, 0.9)
	d.set_hour(19.6)
	await d.wait(0.4)
	await d.ui.fade(false, 0.9)

# §14 백년가약 — 월매가 플레이어와 방자를 증인으로 세운다. 선택은 결과를 바꾸지 않고 따로 기억된다
func vow() -> void:
	beat("vow")
	flag("in_night_scene")
	d.cutscene(true)
	await d.ui.fade(true, 0.8)
	flag("mong_on")
	d.mark_dirty(); d._refresh()
	_place("wolmae", "ch_vow_wolmae", "down")
	_place("mongryong", "ch_vow_mong", "right")
	_place("chunhyang", "ch_vow_chun", "left")
	_place("bangja", "ch_vow_bangja", "up")
	d.teleport_to("ch_vow_player", "up")
	d.camera({ "focus": "ch_wolmae_yard", "pitch": 34.0, "distance": 13.0, "fov": 38.0 })
	await d.wait(0.4)
	await d.ui.fade(false, 0.9)
	d.face_actor("wolmae", null, "player")
	await say("월매", "길손 양반도 들으시오.")
	await say("몽룡", "어머니.")
	await say("월매", ["젊은 사람 말은 바람보다 빠르다오.", "오늘 한 말 내일 잊으면 이 아이만 바보 되는 거요."])
	d.face_actor("mongryong", null, "chunhyang")
	await say("몽룡", "잊지 않겠습니다.")
	await say("춘향", "저도 그렇습니다.")
	await say("몽룡", "어디에 있든 돌아오겠소.")
	await say("춘향", "그 말이면 됩니다.")
	d.face_actor("wolmae", null, "player")
	await say("월매", "들었지요?")
	await _cut("07_vow_night")
	await R([{ "choice": "", "options": [
		{ "label": "들었습니다.", "id": "vow_heard", "do": [{ "flag": "vow_heard" }] },
		{ "label": "두 분 말은 두 분이 지킬 일입니다.", "id": "vow_own", "do": [{ "flag": "vow_own" }] },
		{ "label": "(말없이 고개를 끄덕인다)", "id": "vow_nod", "do": [{ "flag": "vow_nod" }] }] }])
	flag("vow_witness")
	d.learn_clue("vow")
	d.journal_note("백년가약 — 월매 집 마당에서 증인으로 들었다")
	flag("vow_done")
	unflag("in_night_scene")
	await d.wait(0.6)
	await d.ui.fade(true, 1.2)
	d.set_hour(9.5)
	await d.wait(0.3)
	await R([{ "event": "C0501" }])

# §15 소식(낮) — 방자가 뛰어온다
func news() -> void:
	S.phase = "farewell"; d.runner.log_line("phase", S.phase); d.on_phase()
	flag("mong_on"); flag("chun_on")
	d.mark_dirty(); d._refresh()
	_place("mongryong", "ch_mong_gate", "right")
	_place("chunhyang", "ch_chun_gate", "left")
	_place("bangja", "ch_mong_road", "right")
	d.teleport_to("ch_wolmae_front", "up")
	_talk_cam("ch_mong_gate", "ch_wolmae_front")
	d.cutscene(true)
	await d.wait(0.3)
	await d.ui.fade(false, 1.0)
	await d.move_actor("bangja", ["ch_bangja_gate"], 3.6, "run", "idle")
	d.face_actor("bangja", null, "mongryong")
	await say("방자", "도련님 아버님이 한양으로 올라가신답니다.")
	d.learn_clue("news")
	await d.wait(0.8)
	d.face_actor("mongryong", null, "chunhyang")
	await say("몽룡", "나도 가야 해.")
	await d.wait(0.8)

# §16·§17 오리정 곁 북쪽 길(CAMERA 5A) — 큰 울음·과한 음악 없음. 춘향은 따라가지 않는다
func farewell() -> void:
	beat("farewell")
	await d.ui.fade(true, 1.2)
	d.set_hour(11.0)
	_place("chunhyang", "ch_farewell_stand", "up")
	_place("mongryong", "ch_farewell_mong", "down")
	_place("bangja", "ch_farewell_bangja", "up")
	d.teleport_to("ch_farewell_follow", "up")
	d.camera(CAM_5A)
	if d.main.has_method("set_cine_sharp"): d.main.set_cine_sharp(true)
	await d.wait(0.5)
	await d.ui.fade(false, 1.2)
	d.sfx("wind")
	await d.wait(1.0)
	await say("몽룡", "함께 가자고 하고 싶소.")
	await d.wait(1.6)   # 춘향은 대답하지 않는다
	await say("몽룡", "…지금은 그렇게 할 수가 없소.")
	await say("춘향", "압니다.")
	await say("몽룡", "돌아오겠소.")
	await say("춘향", "그 말은 이미 들었습니다.")
	await say("몽룡", "믿지 못하오?")
	await say("춘향", "믿으니 기다리는 겁니다.")
	await _cut("08_farewell_5A")
	await d.wait(1.0)
	# §17 몽룡은 몇 번 뒤를 본다. 방자가 짐을 지고 따른다
	d.face_actor("bangja", null, "player")
	await say("방자", "길손, 잘 계시오.")
	await d.move_actor("mongryong", [[-3213.2, -24.0]], 1.1, "walk", "idle")
	d.face_actor("mongryong", "down", null)
	d.move_actor("bangja", [[-3212.0, -19.0]], 1.4, "walk", "idle")
	await d.wait(1.4)
	await d.move_actor("mongryong", ["ch_farewell_far"], 1.1, "walk", "idle")
	d.face_actor("mongryong", "down", null)
	await d.wait(1.1)
	d.move_actor("bangja", ["ch_farewell_far"], 1.4, "walk", "idle")
	await d.move_actor("mongryong", ["ch_farewell_vanish"], 1.2, "walk", "idle")
	unflag("mong_on")
	flag("bangja_off")
	d.mark_dirty(); d._refresh()
	await d.wait(2.4)   # 몽룡이 시야에서 사라진 뒤에도 춘향은 잠시 서 있다
	d.learn_clue("farewell")
	end_part1()
	d.camera(null)
	if d.main.has_method("set_cine_sharp"): d.main.set_cine_sharp(false)
	d.cutscene(false)

# PART I 끝 — 변수 하나(결정 §1). 남원을 실제로 떠나면 LEFT_AFTER_PART1(on_leave)
func end_part1() -> void:
	if f("part1_done"): return
	flag("farewell_scene_done")
	flag("part1_done")
	S.vars[V_PART1] = true
	d.runner.log_line("var", [V_PART1, true])
	d.mark_dirty()
	d.journal_note("몽룡이 한양으로 떠났다. 춘향은 남원에 남았다")
	d.sfx("journal_stamp")
	d.ui.toast("「%s」 — 단오의 기록을 마쳤다" % CASE_TITLE, "journal")

func chun_goes_home() -> void:
	if f("chun_home"): return
	flag("chun_home")
	unflag("chun_on")
	d.place_actor("chunhyang", "home")

# 남원 권역을 떠날 때(region_main._travel → story_director.on_leave_space)
func on_leave(target: String) -> void:
	if target == REGION: return
	if bool(S.vars.get(V_PART1, false)) and not bool(S.vars.get(V_LEFT, false)):
		S.vars[V_LEFT] = true
		Progress.set_var(V_LEFT, true)
		d.runner.log_line("var", [V_LEFT, true])

# ---------------------------------------------------------------------------
# 불러오기 — 장면 도중 자리 되돌리기
# ---------------------------------------------------------------------------
func on_load() -> void:
	for k in ["in_night_scene", "mong_on", "wolmae_on"]: S.flags.erase(k)
	if S.phase == "courtship" and not f("first_meeting_done"): S.flags.erase("chun_on")
	if S.phase == "farewell":
		if f("farewell_scene_done") and not f("chun_home"):
			flag("chun_on")
			d.place_actor("chunhyang", "ch_farewell_stand", null, "up")
		elif not f("farewell_scene_done"):
			# 소식·이별 도중 저장 — 이별을 다시(월매 집 앞 아침부터)
			S.flags.erase("chun_on")
			S.phase = "courtship"
			for k in ["vow_done", "_trig_c0406_vow"]: S.flags.erase(k)
	if f("evening_call") and not f("first_meeting_done") and not S.has(D.JAR): d.give(D.JAR, 1, true)
	if f("letter_asked") and not f("letter_delivered") and not S.has(D.LETTER): d.give(D.LETTER, 1, true)

# ---------------------------------------------------------------------------
# 기록책(R) — 본 것(fact)과 들은 것(heard — 말한 사람)은 단서 글이 가른다. 여기 문단은 흐름만
# ---------------------------------------------------------------------------
func summary() -> Array:
	var p := []
	p.append("한양을 다녀와 남원에 다시 들렀다. 단오장이 섰다.")
	if f("vista_seen"): p.append("광한루 앞 마당에 사람이 가득했고, 누각 너머 버드나무 사이로 그네가 높이 올랐다.")
	if f("met_bangja"): p.append("군중 속에서 부채를 든 하인 방자와 부딪혔다. 사또 자제 이몽룡의 하인이다.")
	if S.has_clue("name"): p.append("몽룡이 그네 탄 처녀를 보았다. 방자의 말로는 성춘향.")
	if f("refusal_seen"): p.append("방자가 몽룡의 말을 전했지만 춘향은 따라오지 않았다. 보고 싶으면 본인이 말하라고 했다.")
	if f("first_meeting_done"): p.append("그날 저녁 월매 집 대문 앞. 몽룡은 춘향 앞에서 “잘못했소.” 하고 말했다.")
	if f("letter_delivered"): p.append("방자가 맡긴 편지를 춘향에게 전했다. 열어 보지 않았다.")
	if f("walk_seen"): p.append("두 사람이 오작교 곁을 함께 걷는 것을 보았다.")
	if f("vow_done"):
		var how := "들었다고 답했다." if f("vow_heard") else ("두 사람이 지킬 일이라고 답했다." if f("vow_own") else "말없이 고개를 끄덕였다.")
		p.append("밤, 월매 집 마당에서 백년가약을 증인으로 들었다. 월매가 “들었지요?” 하고 물었고 나는 " + how)
	if f("part1_done"):
		p.append("몽룡은 아버지를 따라 한양으로 갔다. 오리정 곁 북쪽 길에서 춘향은 따라가지 않고 서 있었다.")
		if f("farewell_ask_wait"): p.append("기다리겠느냐고 묻자 춘향은 “약속했으니까요.” 했다.")
		elif f("farewell_ask_far"): p.append("한양은 멀다고 하자 춘향은 “먼 길인 건 압니다.” 했다.")
		elif f("farewell_silent"): p.append("아무 말도 하지 않았다. 춘향이 “…가세요.” 했다.")
	return p
