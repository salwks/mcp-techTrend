# 사건 「남원의 약속」 PART II-B — 출두(ACT 13~22): 이튿날 관아 일 셋(술·쌀·상소 — Activity/Problem, 순서 자유) →
# 며칠 뒤 남문 밖 거지 몽룡(14A) → 월매 집 → 밤 옥중 상봉 → 생일잔치(차일 SPREAD) → 몽룡 입장 · 시(17A) → 어사출두(8A FURLED → 18A, 같은 사람이 제자리에서 자세만) →
# 피해 복구(본 것/들은 것) → 옥문 · 월매 → 마지막 선택(II-A 포승을 춘향이 기억) → 며칠 뒤 광한루 → 끝(RELEASED).
#
# 원칙(브리프 §3·§12~§20): 출두·파면·석방은 몽룡이 한다 — 플레이어의 기록은 증거가 아니고 그 결과와 무관하다(FIXED_BEAT는 문제 결과를 읽지 않는다).
#   문제 결과(구체적 행동 깃발)는 ACT 19 주변 피해 복구에만 쓰인다. 춘향의 마지막 말은 II-A 포승(restraint_*)만 읽는다. 점수·합산 없음.
#   조작을 빼앗지 않는다: 일(걸어가 보기·묻기·지고 가기·다시 묻기) · 걸어서 따라가기 · 줄에 선 채 엿듣기(잔치 가장자리·출두 소리). 컷은 14A·월매 집·옥·17A·18A·복구·석방만.
# 사건 스크립트(namwon_chunhyang_case.gd, PART I)가 이 파일을 잇고, 이 파일은 II-A(namwon_chunhyang_p2a.gd)를 잇는다.
extends "res://story/namwon_chunhyang/namwon_chunhyang_p2a.gd"

const P2B := preload("res://story/namwon_chunhyang/namwon_chunhyang_p2b_data.gd")
const SoundB := preload("res://scripts/audio/sound.gd")
const OUTCOME_VAR := "CASE_NAMWON_CHUNHYANG_OUTCOME"

func _is_night() -> bool:
	var h: float = d.main.hour
	return h >= 19.0 or h < 5.0

func _pd(pid: String) -> String: return d.runner.pd(pid)
func _pdone(pid: String) -> bool: return d.runner.pdone(pid)

# 원전 장면 순서(시험이 본다) — 한 번만
func beat2(id: String) -> void:
	if f("beat_" + id): return
	beat(id)
	var order: Array = S.world.get("beat_order", [])
	order.append(id)
	S.world["beat_order"] = order

# ---------------------------------------------------------------------------
# 조작 비율 — ACT 13(이튿날 아침 ~ 일을 마침) · II-B 전체(이튿날 아침 ~ 광한루 끝). 벽시계 · II-A와 같은 판정(controllable)
# ---------------------------------------------------------------------------
var ctl2 := { "act13": { "ctl": 0.0, "all": 0.0 }, "p2b": { "ctl": 0.0, "all": 0.0 }, "marks": [] }
var _ctl2_us := -1

func _ctl2_tick() -> void:
	var now := Time.get_ticks_usec()
	var dt := 0.0 if _ctl2_us < 0 else (now - _ctl2_us) / 1000000.0
	_ctl2_us = now
	if not f("p2b_started") or dt <= 0.0 or dt > 0.5: return
	var c := controllable()
	if not f("duty_over"):
		ctl2.act13.all += dt
		if c: ctl2.act13.ctl += dt
	if not f("end_seen"):
		ctl2.p2b.all += dt
		if c: ctl2.p2b.ctl += dt

func ctl2_ratio(w: String) -> float:
	return ctl2[w].ctl / maxf(0.001, ctl2[w].all)

func _mark2(nm: String) -> void:
	ctl2.marks.append([nm, snappedf(ctl2.p2b.all, 0.1), snappedf(ctl2.p2b.ctl, 0.1)])

# ---------------------------------------------------------------------------
# 매 프레임(II-A p2_ambient 뒤)
# ---------------------------------------------------------------------------
func p2_ambient(dt: float) -> void:
	super(dt)
	_ctl2_tick()
	if not f("p2a_done"): return
	# 첫 밤 뒤 관아 앞에서 한 번 멀어지면(또는 쉬고 오면) 이튿날 아침이 선다
	if not f("p2b_away") and _pp().distance_to(d.anchor("ch_gwana_front")) > 20.0: flag("p2b_away")
	# 출두 뒤 자세(같은 사람 — 군중이 다시 지어졌으면 다시 맞춘다)
	if S.phase == "reveal" and f("royal_inspector_reveal"): _keep_reveal_poses()
	# 평소 시점(컷도 연출 카메라도 아님 — 컷이 끝나 조작으로 돌아온 경계·불러온 뒤)에서는 차일 FURLED
	if (S.phase == "feast" or S.phase == "reveal") and not d._cut and d.main.rig.override == null and d.main.rig.shot == null and chail_set != "FURLED":
		_chail_play()

func p2b_ready() -> bool: return f("p2b_away")
func p2b_busy() -> bool: return d.runner.busy

func p2b_music() -> String:
	if S.phase == "feast" and not f("music_cut"): return "bgm_feast"
	return ""

# ---------------------------------------------------------------------------
# ACT 13 — 이튿날 아침: 아전이 일 셋을 맡긴다(순서 자유)
# ---------------------------------------------------------------------------
func duty_morning() -> void:
	_mark2("C1300")
	flag("p2b_started")
	d.cutscene(true)
	await d.ui.fade(true, 0.8)
	d.set_hour(8.4)
	d.mark_dirty(); d._refresh()
	_place("ajeon_b", "ch_ajeon_b", "down")
	d.teleport_to("ch_ajeon_b_player", "up")
	d.face_actor("player", null, "ajeon_b")
	await d.wait(0.3)
	await d.ui.fade(false, 0.8)
	d.camera(null)
	d.cutscene(false)
	d.free_move = true   # 아전 곁에 선 채 듣는다(조작 그대로 — 자막)
	await line("", "이튿날 아침.")
	await line("아전", "왔소. 사또 생신 잔치가 코앞이라 손이 모자라오.")
	await line("아전", "외삼문 동쪽 술 수레 — 술독은 바깥마당 물자 쌓는 데로.")
	await line("아전", "동문 밖 박가네 쌀 가마니. 담 밑 노인네는 돌려보내고.")
	await line("나그네", "순서는?")
	await line("아전", "아무거나. 해 지기 전에만.")
	d.free_move = false
	flag("duty_on")
	d.learn_clue("duty_three")
	d.journal_note("이튿날 — 관아 잔치 일 셋(술 · 쌀 · 담 밑 노인)")
	d.ui.toast("관아 일 셋 — 순서는 마음대로", "info")

# 조작을 막지 않는 자막(일의 결과 · 곁의 반응) — 이야기 흐름은 바로 끝나고 자막만 이어 뜬다(걸으면서 읽는다)
func subs(lines: Array) -> void:
	for l in lines:
		await d.ui.caption(String(l), 1.4 + String(l).length() * 0.06)

# 사람에게 직접 묻는 말(들은 것) — 곁에 선 채 조작을 쥐고 듣는다(자막). 활동 기록은 데이터의 { activity }가 맡는다
func talk_free(who: String, lines: Array) -> void:
	d.free_move = true
	for l in lines: await line(who, String(l))
	d.free_move = false

# ---- 술: 처리 결정(문제 결과) → 지고 간다 → 내려놓는다 ----
func wine_handled() -> void:
	_mark2("wine_decided")
	S.world["wine_jars"] = 2 if f("wine_left") else 3
	match _pd("wine"):
		"all": subs(["아전 말대로 세 독을 다 내린다."])
		"leave": subs(["물목대로 두 독. 한 독은 수레에 남긴다."])
		"record": subs(["김가의 이름과 독 수, 못 받은 값을 적었다. 독은 세 독 다 내린다."])
	d.ui.toast("술 수레에서 독 하나를 지고 — 바깥마당 물자 곳으로", "info")

func wine_lift() -> void:
	_mark2("wine_lift")
	flag("wine_lifted")
	flag("wine_unloaded")
	d.give(P2B.JAR)
	d.mark_dirty()
	subs(["관속 하나가 한 독을 더 진다. 한 독은 수레에 그대로." if f("wine_left") else "관속 둘이 나머지 두 독을 지게에 얹는다."])
	await _cut("13_wine_work")

func wine_drop() -> void:
	_mark2("wine_drop")
	d.take(P2B.JAR)
	flag("wine_stored")
	d.sfx("footstep_heavy", "ch_wine_drop")
	subs(["물자 쌓는 곳에 술독을 내려놓았다."])
	_check_duty()

# ---- 쌀 ----
func rice_handled() -> void:
	_mark2("rice_decided")
	match _pd("rice"):
		"all":
			await say("포졸", "들었지? 비키시오.")
			subs(["박가가 대문 기둥을 잡고 물러선다."])
			d.ui.toast("가마니 하나를 지고 — 관아 바깥마당으로", "info")
		"one":
			await say("포졸", "한 가마? …내가 지고 갈 것도 아니고. 알아서 하시오.")
			subs(["박가가 남은 가마니를 대문 안으로 끌어들인다."])
			d.ui.toast("가마니 하나를 지고 — 관아 바깥마당으로", "info")
		"reask":
			await say("포졸", "물어보든가. 수레는 여기 둔다.")
			d.ui.toast("아전에게 — 외삼문 앞", "info")

func rice_lift() -> void:
	_mark2("rice_lift")
	flag("rice_lifted")
	d.give(P2B.SACK)
	if _pd("rice") == "all":
		flag("rice_sacks_gone")
		flag("rice_cart_gone")
		subs(["포졸이 나머지 셋을 수레에 싣고 먼저 간다."])
	else:
		subs(["가마니 하나를 졌다. 셋은 박가네 마당에 남았다."])
	d.mark_dirty()

func rice_drop() -> void:
	_mark2("rice_drop")
	d.take(P2B.SACK)
	flag("rice_stored")
	d.sfx("flour_rustle", "ch_rice_drop")
	subs(["물자 쌓는 곳에 가마니를 내려놓았다."])
	_check_duty()

# 아전에게 다시 묻는다(걸어가서 — 말로)
func rice_reask() -> void:
	_mark2("rice_reask")
	await say("나그네", "박가네 징발 표는 두 가마인데, 포졸이 넷을 싣고 있소.")
	await say("아전", "표에 두 가마면 두 가마지. …넷이면 포졸 놈 제 셈이오.")
	await say("아전", "관속 보내서 두 가마만 들이라 하지.")
	subs(["관속 하나가 동문 쪽으로 뛰어간다."])
	flag("rice_reask_done")
	flag("rice_cart_gone")
	d.mark_dirty()
	_check_duty()

# ---- 상소 ----
func petition_handled() -> void:
	_mark2("petition_decided")
	match _pd("petition"):
		"dismiss":
			d.ui.toast("노인에게 — 외삼문 서쪽 담 밑", "info")
		"process":
			subs(["잔치 물목을 걷어 내고 노인의 소지 셋을 맨 위에 올렸다. 받은 날을 적었다."])
			flag("petition_act_done")
			_check_duty()
		"note":
			subs(["노인의 말을 들은 그대로 적었다. 소를 본 것은 아니다."])
			flag("petition_act_done")
			_check_duty()

func elder_dismiss() -> void:
	_mark2("elder_dismiss")
	await say("나그네", "오늘은 돌아가시오. …내일 오시오.")
	await say("노인", "어제도, 그제도 그 말이었소.")
	flag("petition_act_done")
	_check_duty()
	_elder_leaves()

func _elder_leaves() -> void:
	subs(["노인이 무릎을 짚고 일어나 천천히 걸어간다."])
	d.anim_actor("petition_elder", "idle")
	await d.move_actor("petition_elder", [[-3180.0, 246.0]], 0.9, "walk", "idle")
	flag("elder_gone")
	d.mark_dirty()

# 일 셋을 다 했나(결정 셋 + 지고 간 것 · 다시 물은 것 · 노인에게 한 말)
func duty_ready() -> bool:
	return _pdone("wine") and _pdone("rice") and _pdone("petition") and f("wine_stored") and (f("rice_stored") or f("rice_reask_done")) and f("petition_act_done")

func _check_duty() -> void:
	if f("duty_complete") or not duty_ready(): return
	flag("duty_complete")
	_mark2("duty_complete")
	d.ui.toast("일 셋을 마쳤다 — 외삼문 앞 아전에게", "info")

# 일을 마침 → 며칠 뒤 해 질 무렵 남문
func duty_end() -> void:
	_mark2("C1305")
	d.cutscene(true)
	_talk_cam("ajeon_b", "player")
	await say("아전", "다 했소? …품삯은 잔치 끝나고 한꺼번에 주겠소.")
	await say("아전", "잔칫날 아침에도 나오시오. 목패는 그때까지 차고 있고.")
	flag("duty_over")
	_mark2("duty_over")
	printerr("CTL2 act13=%.3f (%.1f/%.1fs)" % [ctl2_ratio("act13"), ctl2.act13.ctl, ctl2.act13.all])
	await d.ui.fade(true, 1.0)
	d.camera(null)
	d.set_hour(18.1)
	d.teleport_to("ch_dusk_start", "down")
	d.mark_dirty(); d._refresh()
	await d.wait(0.3)
	await d.ui.fade(false, 1.0)
	flag("dusk_on")
	d.cutscene(false)
	subs(["며칠이 지났다. 성안은 잔치 준비로 시끄럽다.", "해 질 무렵. 남문을 나서는 길."])

# ---------------------------------------------------------------------------
# ACT 14 — 돌아온 거지(CAMERA 14A: 플레이어 어깨 너머, 정면 클로즈업 없음). 신분을 설명하지 않는다
# ---------------------------------------------------------------------------
func beggar_return() -> void:
	_mark2("C1401")
	d.cutscene(true)
	flag("mong_b_on")
	d.mark_dirty(); d._refresh()
	_place("mong_b", "ch_beggar_from", "up")
	d.anim_actor("mong_b", "walk")
	d.teleport_to("ch_player_sgate", "down")
	_shot(P2B.CAM_14A)
	await d.wait(0.3)
	await d.ui.caption("허름한 옷의 사내가 장터길을 걸어 들어온다.", 2.4)
	await d.move_actor("mong_b", ["ch_beggar_meet"], 1.1, "walk", "idle")
	d.face_actor("mong_b", null, "player")
	await d.wait(0.8)
	await d.ui.caption("얼굴을 보고 걸음이 멈췄다.", 1.8)
	await _cut("14A_beggar_return")
	await say("몽룡", "…오랜만이오.")
	await say("나그네", "그 모습은…")
	await say("몽룡", "못 본 사람으로 해 주시오.")
	beat2("mongryong_return")
	flag("mongryong_return_seen")
	d.learn_clue("beggar_back")
	await d.move_actor("mong_b", ["ch_beggar_pass"], 1.2, "walk", "idle")
	unflag("mong_b_on")
	d.mark_dirty()
	_cam_end()
	d.cutscene(false)
	d.ui.toast("월매 집 쪽으로 — 남문 밖, 광한루 동쪽", "info")

# ---------------------------------------------------------------------------
# ACT 15 — 월매 집: 월매가 처음에는 못 알아본다
# ---------------------------------------------------------------------------
func wolmae_reunion() -> void:
	_mark2("C1501")
	flag("mong_b_on"); flag("wolmae_b_on")
	d.mark_dirty(); d._refresh()
	_place("mong_b", "ch_mong_gate", "up")
	_place("wolmae_b", "ch_wolmae_at_gate", "down")
	d.camera({ "focus": [-3213.6, 459.0], "pitch": 30.0, "distance": 11.5, "fov": 38.0 })
	d.free_move = true   # 대문 앞에서 지켜본다 — 조작은 그대로(엿듣는 자막)
	d.sfx("knock", "ch_wolmae_gate")
	await d.wait(0.6)
	await line("", "월매가 문을 연다. 처음에는 알아보지 못한다.")
	await line("몽룡", "어머니.")
	await line("월매", "…도련님?")
	await line("몽룡", "예.")
	await line("", "월매가 옷을 훑어본다.")
	await line("월매", "이 꼴은 뭡니까.")
	await line("몽룡", "사정이 있었습니다.")
	await line("월매", "춘향이가 옥에서 죽어 가는데 사정?")
	await _cut("15_wolmae_beggar")
	await line("월매", "돌아온다더니 거지가 돼 왔소?")
	await line("", "몽룡은 변명하지 않는다.")
	await line("몽룡", "춘향은 어디 있습니까?")
	await line("월매", "옥에 있지 어디 있겠소.")
	beat2("wolmae_reunion")
	flag("wolmae_reunion_seen")
	d.learn_clue("beggar_wolmae")
	d.free_move = false
	d.cutscene(true)
	await d.ui.fade(true, 1.0)
	d.set_hour(21.0)
	_stage_gate_night()
	d.camera(null)
	await d.wait(0.3)
	await d.ui.fade(false, 1.0)
	d.cutscene(false)
	subs(["밤. 몽룡이 관아 쪽으로 간다. 월매가 바구니를 들고 뒤따른다."])
	d.ui.toast("외삼문 밖으로", "info")

func _stage_gate_night() -> void:
	flag("mong_b_on"); flag("wolmae_b_on")
	d.mark_dirty(); d._refresh()
	_place("mong_b", "ch_mong_gate_night", "right")
	_place("wolmae_b", "ch_wolmae_gate_night", "right")

# 관아와의 관계(구체적 행동 둘 — 점수 아님): 잡역을 스스로 맡았고 줄을 놓지 않았다
func office_trust() -> bool:
	return f("labour_accepted") and not f("restraint_refused")

# ---------------------------------------------------------------------------
# ACT 16 — 옥중 상봉: 몽룡이 스스로 찾아간다. 관계가 좋으면 거들 수 있고, 아니어도 월매가 다른 길로 — 장면은 늘 일어난다
# ---------------------------------------------------------------------------
func jail_reunion() -> void:
	_mark2("C1601")
	_stage_gate_night()
	d.face_actor("pojol_gate", null, "mong_b")
	d.face_actor("mong_b", null, "pojol_gate")
	var mid: Vector2 = (d.anchor("ch_mong_gate_night") + d.anchor("ch_gate_guard")) * 0.5
	d.camera({ "focus": [mid.x, mid.y], "pitch": 30.0, "distance": 10.0, "fov": 38.0 })
	d.free_move = true   # 외삼문 앞에서 지켜본다(조작 그대로) — 몽룡이 스스로 들어갈 길을 찾는다
	await line("몽룡", "옥에 갇힌 사람 하나 보러 왔소.")
	await line("포졸", "거지가 옥에는 왜?")
	await line("몽룡", "…아는 사람이오.")
	await line("포졸", "안 돼. 사또 분부요.")
	d.free_move = false
	if office_trust():
		await R([{ "choice": "", "options": [
			{ "label": "(거든다) 저 사람, 잠깐만 들여보내 주시오.", "id": "help", "do": [{ "flag": "reunion_helped" }] },
			{ "label": "(지켜본다)", "id": "watch", "do": [{ "flag": "reunion_watched" }] }] }])
	else:
		flag("reunion_other_way")
	d.free_move = true
	if f("reunion_helped"):
		await line("", "목패를 보였다.")
		await line("포졸", "…목패 찬 양반 말이니. 잠깐이오. 말은 짧게.")
	else:
		d.face_actor("wolmae_b", null, "pojol_gate")
		await line("월매", "이거 받고 눈 좀 감으시오.")
		await line("", "월매가 바구니 밑에서 엽전 꾸러미를 꺼내 포졸 손에 쥐여 준다.")
		await line("포졸", "…밥 넣는 동안만이오.")
	d.free_move = false
	d.cutscene(true)
	# 옥(12A) — 둘의 장면. 플레이어는 창살 밖
	await d.ui.fade(true, 0.8)
	d.main.world.set_prop_state("ti_jail/gate", "OPEN")
	_place("mong_b", "ch_mong_bars", "up")
	_place("wolmae_b", "ch_jail_gate", "left")
	d.teleport_to("ch_reunion_watch", "left")
	_shot(P2.CAM_12A)
	await d.wait(0.4)
	await d.ui.fade(false, 0.8)
	await say("몽룡", "춘향아.")
	await d.ui.caption("춘향이 눈을 뜬다. 한동안 알아보지 못한다.", 2.2)
	await say("춘향", "…도련님?")
	await say("몽룡", "나 왔다.")
	await d.ui.caption("춘향은 웃지도 못한다.", 1.6)
	await _cut("16_12A_reunion")
	await say("몽룡", ["이 꼴로 왔소.", "나를 따라와도 고생뿐일 텐데…"])
	await say("춘향", "그 말을 하려고 왔습니까?")
	await say("몽룡", "…아니.")
	await say("춘향", "그럼 됐습니다.")
	await d.ui.caption("몽룡이 고개를 숙인다.", 1.6)
	await say("춘향", "살아 있으면 된 줄 알았어요.")
	await d.ui.caption("나는 창살 밖에 서 있었다.", 1.8)
	beat2("jail_reunion")
	flag("jail_reunion_seen")
	d.learn_clue("reunion")
	# 이튿날 — 잔치(단계 feast)
	await d.ui.fade(true, 1.2)
	_cam_end()
	d.main.world.set_prop_state("ti_jail/gate", "SEALED")
	unflag("mong_b_on"); unflag("wolmae_b_on")
	S.phase = "feast"; d.runner.log_line("phase", S.phase); d.on_phase()
	flag("feast_day")
	d.set_hour(11.0)
	d.teleport_to("ch_gwana_front", "up")
	d.mark_dirty(); d._refresh()
	stage_feast()
	await d.wait(0.4)
	await d.ui.fade(false, 1.0)
	d.cutscene(false)
	subs(["이튿날. 사또 생신 잔치."])
	d.ui.toast("관아 안마당으로", "info")

# ---------------------------------------------------------------------------
# ACT 17 — 생일잔치(차일 SPREAD — 잔치 놀이·낮은 틀). 앞서 나른 술과 쌀이 상 곁에 있다
# ---------------------------------------------------------------------------
# 변학도 교의: 대청 마루 = 안마당 땅 + 1.05(II-A stage_office와 같은 계산)
func stage_feast() -> void:
	if not d.actors.has("byeon_feast"): return
	var seat: Vector2 = d.anchor("ch_byeon_seat")
	var court: Vector2 = d.anchor("ch_dais")
	var dy: float = d.world.height_at(court.x, court.y + 1.6) + 1.05 - d.world.height_at(seat.x, seat.y)
	d.place_actor("byeon_feast", "ch_byeon_seat", dy, "down")
	d.anim_actor("byeon_feast", "cower" if f("royal_inspector_reveal") else "sit")
	if f("royal_inspector_reveal"): d.set_pose(["byeon_feast"], "cower")

func feast_enter() -> void:
	_mark2("C1701")
	beat2("birthday_feast")
	d.cutscene(true)
	cut_to("feast_play")
	d.camera(P2B.CAM_FEAST)
	d.sfx("cup_clink", "ch_court")
	await d.wait(0.4)
	await d.ui.caption("관아 안마당. 차일 아래 손님 상이 두 줄로 놓였다. 음악, 웃음.", 2.6)
	await _cut("17_feast_general")
	var n_jars := 2 if f("wine_left") else 3
	await d.ui.caption("보계 곁에 김가 봉지가 붙은 술독 %s. 아침에 내가 내린 것이다." % ("둘" if n_jars == 2 else "셋"), 2.6)
	await d.ui.caption("건너편엔 동문 밖에서 실어 온 가마니. 상마다 떡과 술병.", 2.4)
	d.learn_clue("feast_goods")
	flag("feast_seen")
	cut_to("none")
	_chail_play()
	d.camera(null)
	d.cutscene(false)
	d.ui.toast("서쪽 줄 끝에 선다", "info")

# 평소 시점(조작 — pitch 38 · 거리 16, 높이 약 10m)은 차일(높이 4.6, 반투명 아님) 위에서 내려다본다 — 8A처럼 FURLED로 둔다.
#   컷이 끝나 조작으로 돌아오는 그 경계에서만 바꾼다(C62 — 눈앞에서 말아 올리지 않는다). 불러온 뒤(평소 시점)도 같다
func _chail_play() -> void:
	var pl = d.main.get("placement")
	var e = pl.gated.get("ti_chail") if pl != null else null
	if e == null or bool(e.get("off", false)): return
	if d.main.world.props.get_state("ti_chail/cloth") != "FURLED": d.main.world.set_prop_state("ti_chail/cloth", "FURLED")
	chail_set = "FURLED"

func feast_wine_look() -> void:
	flag("feast_wine_looked")
	await d.ui.examine("잔치 술독", ["김가 술도가 봉지가 그대로 붙어 있다.", "아침에 수레에서 내린 독이다."], "clue")

# §41 몽룡 입장 — 플레이어는 서쪽 줄 끝에서 조작을 쥔 채 엿듣는다(낮은 틀). §42 시 — 17A(종이를 위에서) 컷
var probe_feast := {}
func mong_enters() -> void:
	_mark2("C1702")
	flag("mong_feast_in")
	leash_at = d.anchor("ch_player_saryeong")
	flag("leash_on")
	cut_to("feast_play")
	d.camera(P2B.CAM_EDGE)
	flag("mong_b_on")
	d.mark_dirty(); d._refresh()
	_place("mong_b", "ch_mong_edge", "right")
	d.free_move = true
	await d.move_actor("mong_b", [[-3169.9, 217.0]], 1.0, "walk", "idle")
	d.face_actor("saryeong_w3", null, "mong_b")
	await line("사령", "어디 거지가 들어와.")
	await line("몽룡", "지나가는 선비요.")
	await line("사령", "선비가 그 꼴이오?")
	await line("몽룡", "글은 옷이 쓰는 게 아니잖소.")
	d.sfx("laugh_far", "ch_court")
	await line("", "근처 손님들이 웃는다.")
	await _cut("17_mong_edge")
	await line("변학도", "시나 한 수 지을 줄 아느냐?")
	await line("몽룡", "종이와 붓을 주시면.")
	probe_feast["edge_ctl"] = controllable()
	flag("poem_called")
	d.mark_dirty(); d._refresh()
	await d.move_actor("mong_b", ["ch_naesammun", "ch_mong_poem"], 1.3, "walk", "idle")
	d.face_actor("mong_b", "up", null)
	d.anim_actor("mong_b", "sit")
	# 17A — 종이를 위에서. 연회 소리가 점점 작아진다
	d.free_move = false
	d.cutscene(true)
	cut_to("17A")
	_shot(P2B.CAM_17A)
	d.sfx("brush_stroke", "ch_poem_table")
	SoundB.music_level(0.55, 1.0)
	await d.wait(0.6)
	var verse := ["금동이의 좋은 술은 백성의 피요.", "옥쟁반의 좋은 안주는 백성의 기름이라.", "촛농 떨어질 때 백성의 눈물 떨어지고,", "노랫소리 높은 곳에 원망 소리 높구나."]
	var lv := [0.4, 0.28, 0.18, 0.1]
	for i in verse.size():
		await d.ui.caption(verse[i], 3.2)
		SoundB.music_level(lv[i], 1.2)
		if i == 1: await _cut("17A_poem")
	_cam_end()
	cut_to("feast_play")
	d.camera(P2B.CAM_FEAST)
	await d.ui.caption("손님 몇의 얼굴이 굳는다.", 1.8)
	d.sfx("cup_clink", "ch_court")
	_one_guest_rises()
	await d.ui.caption("한 사람은 술잔을 내려놓는다. 다른 사람은 슬쩍 일어난다.", 2.4)
	await say("변학도", "뭐라 쓴 것이냐?")
	await say("몽룡", "시입니다.")
	beat2("poem")
	flag("banquet_poem_seen")
	d.learn_clue("poem")
	d.anim_actor("mong_b", "idle")
	d.move_actor("mong_b", ["ch_naesammun", "ch_oesammun_in"], 1.4, "walk", "idle")
	flag("poem_done")
	await chuldu()

# 시를 읽은 뒤 손님 하나가 슬쩍 일어선다(같은 사람 — 제자리에서 자세만)
var risen_guest := -1
func _one_guest_rises() -> void:
	var cr = d.main.crowd
	if cr == null: return
	var ms: Array = cr.members("byeon_banquet")
	for i in ms.size():
		var m: Dictionary = ms[i]
		if String(m.role) == "sit" and String(m.get("rect", "")) == "B_court_e":
			m.pose = "idle"
			if m.get("ch") != null and is_instance_valid(m.ch): m.ch.play("idle", true)
			risen_guest = i
			return

# ---------------------------------------------------------------------------
# ACT 18 — 어사출두: 잔치 음악 → 끊김 → 말발굽 → 침묵 → 외침(공식 8A FURLED — 플레이어는 줄에서 조작을 쥔 채) →
#   18A(변학도 뒤에서 정문 쪽, 출두 틀이라 FURLED 그대로) — 같은 군중·사령·변학도가 제자리에서 자세만 바꾼다. 보스전 없음
# ---------------------------------------------------------------------------
var probe_reveal := {}
func chuldu() -> void:
	if f("royal_inspector_reveal"): return
	_mark2("C1801")
	d.cutscene(false)
	leash_at = d.anchor("ch_player_saryeong")
	d.teleport_to("ch_player_saryeong", "right")
	flag("leash_on")
	cut_to("8A_chuldu")
	d.free_move = true
	probe_reveal["chail_8a"] = chail_set
	probe_reveal["pitch_8a"] = float((d.main.rig.override if d.main.rig.override != null else {}).get("pitch", -1.0))
	await d.wait(0.8)
	flag("music_cut")
	SoundB.music_stop(0.3)
	await line("", "잔치 음악이 뚝 끊긴다.")
	d.sfx("hoofbeats", Vector2(-3162.1, 262.0))
	await line("", "밖에서 말발굽. 여러 사람의 발소리.")
	d.hush(3.0)
	await d.wait(2.0)
	probe_reveal["ctl_8a"] = controllable()
	d.sfx("chuldu_cry", Vector2(-3162.1, 275.0))
	await line("", "멀리서 — “암행어사 출두야!”")
	await line("", "아무도 바로 움직이지 못한다.")
	d.sfx("chuldu_cry", Vector2(-3162.1, 242.0))
	await line("", "더 가까이 — “암행어사 출두야!”")
	# 18A — 같은 관아 축, 변학도 뒤에서
	d.free_move = false
	unflag("leash_on")
	d.cutscene(true)
	S.phase = "reveal"; d.runner.log_line("phase", S.phase); d.on_phase()
	stage_feast()
	cut_to("8A_chuldu")   # 18A도 출두(권력) 틀 — 차일 FURLED 그대로(낮은 18A에서 편 천 밑면이 화면 위 1/3을 덮었다 — 촬영)
	_shot(P2B.CAM_18A)
	d.face_actor("byeon_feast", "up", null)   # 18A는 변학도 등 뒤 — 그림을 등 쪽으로(아래를 보면 카메라를 마주 본다. 화면 순회). 컷 뒤 되돌림
	probe_reveal["chail_18a"] = chail_set
	flag("yeokjol_in")
	flag("mong_b_on")
	d.mark_dirty(); d._refresh()
	for i in P2B.YEOKJOL.size():
		var id: String = P2B.YEOKJOL[i]
		_place(id, "ch_yeokjol_from", "up")
		d.move_actor(id, ["ch_naesammun", "ch_" + id], 2.2, "run", "idle")
	_place("mong_b", "ch_naesammun", "up")
	await d.move_actor("mong_b", ["ch_mong_court"], 1.2, "walk", "idle")
	await _cut("18A_before")
	# 힘이 바뀌는 순간 — 같은 사람, 제자리에서 자세만
	probe_reveal["before"] = _pose_nodes()
	flag("royal_inspector_reveal")
	d.anim_actor("mong_b", "mapae")
	var n_crowd: int = d.main.crowd.apply_on_flag("byeon_banquet", "royal_inspector_reveal") if d.main.crowd != null else 0
	var sar: Array = d.set_pose("saryeong", "kneel")
	d.set_pose(["byeon_feast"], "cower")
	for id in P2B.YEOKJOL: d.face_actor(id, "up", null)
	beat2("royal_inspector")
	await d.wait(0.6)
	probe_reveal["after"] = _pose_nodes()
	probe_reveal["n_crowd"] = n_crowd
	probe_reveal["n_saryeong"] = sar.size()
	await d.ui.caption("아까까지 허리를 세우던 사람들이 고개를 숙인다.", 2.4)
	await _cut("18A_after")
	d.face_actor("byeon_feast", "down", null)
	await say("변학도", "…누구냐.")
	await say("몽룡", "전라도를 살피라는 명을 받고 내려온 암행어사 이몽룡이오.")
	await say("변학도", "이…")
	await say("몽룡", "변학도.")
	await say("몽룡", "관인을 거두시오.")
	d.move_actor("yeokjol_5", [[-3163.4, 209.4]], 1.6, "walk", "idle")
	d.move_actor("yeokjol_6", [[-3160.8, 209.4]], 1.6, "walk", "idle")
	await d.ui.caption("역졸 둘이 보계에 올라 관인을 거둔다. 곳간 문에 봉인이 붙는다.", 2.6)
	beat2("byeon_dismissed")
	flag("byeon_dismissed")
	d.learn_clue("reveal")
	d.journal_note("암행어사 출두 — 이몽룡. 변학도는 관인을 빼앗겼다")
	await restoration()

# 같은 사람인가: 군중(노드 instance id)·사령·변학도 노드와 자리·자세
func _pose_nodes() -> Dictionary:
	var out := { "crowd": [], "actors": {} }
	var cr = d.main.crowd
	if cr != null:
		for m in cr.members("byeon_banquet"):
			var ch = m.get("ch")
			out.crowd.append([ch.get_instance_id() if ch != null and is_instance_valid(ch) else 0, [snappedf(m.pos2.x, 0.01), snappedf(m.pos2.y, 0.01)],
				String(m.get("pose", "")), String(m.role), String(m.kind)])
	for id in d.actors:
		var a: Dictionary = d.actors[id]
		if id.begins_with("saryeong") or id == "byeon_feast":
			out.actors[id] = [a.ch.get_instance_id(), [snappedf(a.pos.x, 0.01), snappedf(a.pos.z, 0.01)], String(a.anim)]
	return out

func _keep_reveal_poses() -> void:
	var cr = d.main.crowd
	if cr != null and cr.is_shown("byeon_banquet"):
		for m in cr.members("byeon_banquet"):
			if String(m.get("pose", "")) == "":
				cr.apply_on_flag("byeon_banquet", "royal_inspector_reveal")
				break
	if d.actors.has("byeon_feast") and String(d.actors.byeon_feast.anim) != "cower": d.set_pose(["byeon_feast"], "cower")

# ---------------------------------------------------------------------------
# ACT 19 — 피해 복구: 몽룡은 이미 자기 조사를 끝냈다. 플레이어가 본 것(본 대로)과 들은 것(누가 말했는지)은 주변 피해에만 쓰인다
# ---------------------------------------------------------------------------
func told_any() -> bool:
	for k in ["told_wine_seen", "told_wine_heard", "told_rice_seen", "told_rice_heard", "told_ox_heard", "told_petition_seen"]:
		if f(k): return true
	return false

func restoration() -> void:
	_mark2("C1901")
	d.cutscene(true)
	d.anim_actor("mong_b", "idle")
	_place("mong_b", "ch_mong_ask", "left")
	d.teleport_to("ch_player_ask", "right")
	_cam_end()
	cut_to("talk_low")
	var mid: Vector2 = (d.anchor("ch_mong_ask") + d.anchor("ch_player_ask")) * 0.5
	d.camera({ "focus": [mid.x, mid.y], "pitch": 24.0, "distance": 6.5, "fov": 38.0 })
	await say("몽룡", ["자네도 관아 일을 했다고 들었소.", "직접 본 게 있소?"])
	var any := "f('told_wine_seen') or f('told_wine_heard') or f('told_rice_seen') or f('told_rice_heard') or f('told_ox_heard') or f('told_petition_seen')"
	var opts := []
	if f("wine_discrepancy_seen"):
		opts.append({ "label": "술 물목은 두 독인데, 세 독을 내리라는 것을 보았습니다.", "id": "wine_seen", "when": "not f('told_wine_seen')",
			"do": [{ "flag": "told_wine_seen" }, { "say": "몽룡", "lines": ["물목과 수레를 둘 다 보았단 말이오."] }] })
	if d.runner.pa("wine", "merchant"):
		opts.append({ "label": "술 상인이 지난번 술값도 못 받았다고 들었습니다.", "id": "wine_heard", "when": "not f('told_wine_heard')",
			"do": [{ "flag": "told_wine_heard" }, { "say": "몽룡", "lines": ["들은 말이구려. 누구에게?"] }, { "say": "나그네", "lines": ["외삼문 동쪽 김가 술도가 상인에게 들었습니다."] }] })
	if f("rice_discrepancy_seen"):
		opts.append({ "label": "쌀을 더 가져간 것을 보았습니다.", "id": "rice_seen", "when": "not f('told_rice_seen')",
			"do": [{ "flag": "told_rice_seen" }, { "say": "몽룡", "lines": ["얼마나?"] }, { "say": "나그네", "lines": ["징발 표는 두 가마, 대문 앞에 나온 건 넷이었습니다."] }] })
	if d.runner.pa("rice", "farmer"):
		opts.append({ "label": "박가네에서 그 쌀이 겨울 양식이라고 들었습니다.", "id": "rice_heard", "when": "not f('told_rice_heard')",
			"do": [{ "flag": "told_rice_heard" }, { "say": "몽룡", "lines": ["박가에게 들은 말이오. 알겠소."] }] })
	if f("old_man_heard"):
		opts.append({ "label": "소를 가져갔다고 들었습니다.", "id": "ox_heard", "when": "not f('told_ox_heard')",
			"do": [{ "flag": "told_ox_heard" }, { "say": "몽룡", "lines": ["본 것은 아니고?"] }, { "say": "나그네", "lines": ["외삼문 담 밑 노인에게 들었습니다. 소는 보지 못했습니다."] }] })
	if f("petition_gap_seen"):
		opts.append({ "label": "노인의 소지가 열흘째 열리지도 않은 것을 보았습니다.", "id": "petition_seen", "when": "not f('told_petition_seen')",
			"do": [{ "flag": "told_petition_seen" }, { "say": "몽룡", "lines": ["형방 소지함 말이오? 잔치 물목 밑에?"] }] })
	opts.append({ "label": "그것뿐입니다.", "id": "end", "when": any, "end": true })
	opts.append({ "label": "내가 직접 확인한 것은 많지 않소.", "id": "none", "when": "not (%s)" % any, "end": true, "do": [{ "flag": "told_nothing" }] })
	await R([{ "choice": "", "loop": true, "options": opts }])
	if told_any(): await say("몽룡", ["변학도 일은 내 조사로 이미 끝났소.", "본 것과 들은 것은 따로 적어, 빼앗긴 사람들 셈에 쓰겠소."])
	else: await say("몽룡", ["그렇소.", "변학도 일은 내 조사로 이미 끝났소."])
	_restore_flags()
	# 바깥마당 물자 곳 — 바뀐 것만 보인다
	await d.ui.fade(true, 0.8)
	_cam_end()
	flag("resto_on")
	d.mark_dirty(); d._refresh()
	_place("resto_clerk", "ch_resto_clerk", "down")
	if f("restore_wine_paid"): _place("wine_merchant", "ch_resto_merchant", "left")
	if f("restore_rice_returned") or f("restore_rice_thanks"): _place("rice_farmer", "ch_resto_farmer", "down")
	if f("restore_petition_reopened"):
		_place("petition_elder", "ch_resto_elder", "right")
		d.anim_actor("petition_elder", "idle")
	d.teleport_to("ch_resto_player", "up")
	cut_to("resto")
	d.camera(P2B.CAM_RESTO)
	await d.wait(0.3)
	await d.ui.fade(false, 0.8)
	d.cutscene(false)
	d.free_move = true   # 바깥마당에서 지켜본다(조작 그대로) — 바뀐 것만 보인다
	var jars := int(S.world.get("wine_jars", 3))
	if f("restore_wine_paid"):
		d.sfx("cup_clink", "ch_resto_merchant")
		await line("", "김가가 관아 창고 앞에서 술값을 받는다. %s 값." % ("두 독" if jars == 2 else "세 독"))
	elif f("restore_wine_partial"):
		await line("", "김가는 수레에 남긴 한 독만 건졌다. 내린 두 독 값이 나올지는 모른다.")
	if f("restore_rice_returned"): await line("", "박가네 가마니가 수레에 실려 동문 쪽으로 돌아간다.")
	if f("restore_rice_thanks"):
		d.face_actor("rice_farmer", null, "player")
		d.anim_actor("rice_farmer", "bow")
		await line("", "박가가 나를 알아보고 고개를 숙인다.")
	elif f("restore_rice_spared") and not f("restore_rice_returned"):
		await line("", "포졸이 더 실으려던 두 가마는 박가네 마당에 그대로 있다고 한다.")
	if f("restore_petition_reopened"): await line("", "어사 측 서리가 담 밑 노인을 따로 불러 앉힌다. 소 일을 처음부터 다시 묻는다.")
	if f("restore_uncertain"): await line("", "변학도는 관인을 빼앗겼다. 다만 빼앗긴 것들이 다 돌아갔는지는 아무도 확답하지 않았다.")
	await _cut("19_restoration")
	beat2("restoration")
	d.learn_clue("restoration")
	d.free_move = false
	d.cutscene(true)
	# ACT 20 — 몽룡이 직접 옥으로. 플레이어와 월매는 뒤(조작)
	await d.ui.fade(true, 0.8)
	_cam_end()
	unflag("resto_on")
	S.phase = "release"; d.runner.log_line("phase", S.phase); d.on_phase()
	d.set_hour(14.0)
	flag("wolmae_b_on")
	d.mark_dirty(); d._refresh()
	_place("mong_b", "ch_naesammun", "down")
	_place("wolmae_b", "ch_oesammun_in", "up")
	await d.wait(0.3)
	await d.ui.fade(false, 0.8)
	d.move_actor("mong_b", ["ch_mong_release"], 1.3, "walk", "idle")
	d.move_actor("wolmae_b", ["ch_wolmae_release"], 1.0, "walk", "idle")
	cut_to("none")
	d.cutscene(false)
	subs(["몽룡이 직접 옥으로 간다."])
	d.ui.toast("옥으로 — 몽룡을 따라", "info")

# 피해 복구 결과(구체적 행동 깃발 → 복구 깃발 — 합산 없음). 처벌·석방은 여기서 읽지 않는다
func _restore_flags() -> void:
	if f("wine_recorded") or f("told_wine_seen") or f("told_wine_heard"): flag("restore_wine_paid")
	elif f("wine_left"): flag("restore_wine_partial")
	if f("told_rice_seen") or f("told_rice_heard"): flag("restore_rice_returned")
	if f("rice_left"): flag("restore_rice_thanks")
	if f("rice_reask_done"): flag("restore_rice_spared")
	if f("told_ox_heard") or f("told_petition_seen") or f("petition_processed") or f("old_man_recorded"): flag("restore_petition_reopened")
	if not (f("restore_wine_paid") or f("restore_rice_returned") or f("restore_petition_reopened")): flag("restore_uncertain")
	flag("restore_done")

# ---------------------------------------------------------------------------
# ACT 20·21 — 옥문 · 월매 · 마지막 선택(춘향이 II-A 포승을 기억한다)
# ---------------------------------------------------------------------------
var last_line := ""
func release() -> void:
	_mark2("C2001")
	d.cutscene(true)
	_place("mong_b", "ch_mong_release", "left")
	_place("wolmae_b", "ch_wolmae_release", "left")
	d.teleport_to([-3165.4, 234.4], "left")
	_shot(P2.CAM_JAIL_DOOR)
	d.main.world.set_prop_state("ti_jail/cell", "OPEN")
	d.main.world.set_prop_state("ti_jail/gate", "OPEN")
	_place("chun_release", "ch_jail_gate_in2", "right")
	d.anim_actor("chun_release", "walk")
	await d.wait(0.4)
	await d.ui.caption("옥문이 열린다. 춘향이 나온다.", 1.8)
	await d.move_actor("chun_release", ["ch_chun_out"], 0.8, "walk", "idle")
	d.face_actor("chun_release", null, "mong_b")
	await d.ui.caption("몽룡 뒤의 사람들을 보고, 무슨 일인지 바로 알아보지 못한다.", 2.4)
	await say("몽룡", "늦었소.")
	await say("춘향", "많이 늦었습니다.")
	await say("몽룡", "…미안하오.")
	await say("춘향", "왔으니 됐습니다.")
	await _cut("20_release")
	beat2("release")
	flag("chunhyang_released")
	d.learn_clue("release")
	# §48 월매
	await d.move_actor("wolmae_b", [[-3167.8, 230.9]], 2.4, "run", "idle")
	d.face_actor("wolmae_b", null, "chun_release")
	await d.ui.caption("월매가 뛰어와 춘향을 안는다.", 1.8)
	d.face_actor("wolmae_b", null, "mong_b")
	await say("월매", "거지라더니.")
	await d.ui.caption("몽룡이 처음으로 웃는다.", 1.6)
	await say("몽룡", "그랬습니다.")
	await say("월매", "아주 사람을 잡아먹으려고 작정을 했구먼.")
	await d.ui.caption("춘향도 아주 조금 웃는다.", 1.6)
	# ACT 21 — 마지막 선택
	_cam_end()
	var pp := _pp()
	var cp := _apos("chun_release")
	d.camera({ "focus": [(pp.x + cp.x) * 0.5, (pp.y + cp.y) * 0.5], "pitch": 22.0, "distance": 5.6, "fov": 38.0 })
	d.face_actor("chun_release", null, "player")
	d.face_actor("player", null, "chun_release")
	await say("춘향", "그날 마당에서부터 계속 있었지요.")
	await say("나그네", "그랬습니다.")
	if f("restraint_obeyed"):
		await say("춘향", "그때 줄을 잡았던 것도 기억합니다.")
		await R([{ "choice": "", "options": [
			{ "label": "미안합니다.", "id": "sorry", "do": [{ "flag": "last_sorry" }] },
			{ "label": "명령이었습니다.", "id": "order", "do": [{ "flag": "last_order" }] },
			{ "label": "(아무 말 하지 않는다)", "id": "silent", "do": [{ "flag": "last_silent" }] }] }])
		await say("춘향", "압니다.")
		await d.wait(1.0)
		last_line = "그래도 다음엔 생각하고 잡으세요."
		await say("춘향", last_line)
	elif f("restraint_refused"):
		await say("춘향", ["그때 손을 놓았지요.", "바뀐 건 없었지만…"])
		await d.wait(1.0)
		last_line = "봤습니다."
		await say("춘향", last_line)
	elif f("restraint_loose"):
		last_line = "그것도 봤습니다."
		await say("춘향", ["혼날 줄 알면서 힘을 풀었더군요.", last_line])
	else:
		last_line = "…고맙습니다."
		await say("춘향", last_line)
	S.world["last_line"] = last_line
	beat2("last_choice")
	flag("last_choice_done")
	await _cut("21_last_choice")
	# 며칠 뒤 — 광한루
	await d.ui.fade(true, 1.2)
	_cam_end()
	unflag("mong_b_on"); unflag("wolmae_b_on")
	S.phase = "epilogue"; d.runner.log_line("phase", S.phase); d.on_phase()
	d.set_hour(10.5)
	d.teleport_to("ch_end_start", "left")
	d.mark_dirty(); d._refresh()
	await d.wait(0.4)
	await d.ui.fade(false, 1.0)
	d.cutscene(false)
	subs(["며칠 뒤."])
	d.ui.toast("광한루 쪽으로", "info")

# ---------------------------------------------------------------------------
# ACT 22 — 광한루: 빈 그네, 아이 둘. 기록책 — 내가 실제로 한 일 한 줄. 끝
# ---------------------------------------------------------------------------
func action_line() -> String:
	if f("restraint_refused"): return "나는 관아의 명령을 몇 번 따랐고, 한 번은 손을 놓았다."
	if f("wine_recorded") or f("old_man_recorded") or f("petition_processed"): return "나는 그날 관아에서 들은 말을 기록해 두었다."
	if f("restraint_loose"): return "나는 관아의 명령을 따랐고, 한 번은 줄을 느슨하게 잡았다."
	return "모든 것을 보았으나, 모든 일에 손을 쓸 수 있었던 것은 아니다."

func epilogue() -> void:
	_mark2("C2201")
	flag("end_seen")
	d.cutscene(true)
	d.camera(P2B.CAM_END)
	d.anim_actor("end_kid_a", "run")
	await d.wait(0.4)
	await d.ui.caption("처음과 같은 광한루. 그네는 비어 있다.", 2.2)
	await d.ui.caption("그 곁에서 아이 둘이 논다. 단오는 이미 지났다.", 2.2)
	await _cut("22_gwanghallu_end")
	var lines := ["성춘향은 변학도의 수청을 끝내 거절했다.", "이몽룡은 암행어사가 되어 남원으로 돌아왔다.", action_line()]
	S.world["end_lines"] = lines
	d.sfx("page_turn")
	await d.ui.examine("기록책", lines, "journal")
	await d.ui.caption("약속을 지킨 것은 내가 아니었다.", 3.0)
	for l in lines: S.notes.append(l)
	d.journal_note("약속을 지킨 것은 내가 아니었다")
	S.vars[OUTCOME_VAR] = "RELEASED"
	d.runner.log_line("outcome", "RELEASED")
	S.phase = "done"; d.runner.log_line("phase", S.phase); d.on_phase()
	d.camera(null)
	d.cutscene(false)
	printerr("CTL2 act13=%.3f (%.1f/%.1fs) p2b=%.3f (%.1f/%.1fs) marks=%s" % [ctl2_ratio("act13"), ctl2.act13.ctl, ctl2.act13.all,
		ctl2_ratio("p2b"), ctl2.p2b.ctl, ctl2.p2b.all, JSON.stringify(ctl2.marks)])
	await d.show_ending()
	d.save()

func ending_data() -> Dictionary:
	var resto := []
	if f("restore_wine_paid"): resto.append("김가는 술값을 받았다")
	if f("restore_rice_returned"): resto.append("박가네 가마니는 돌아갔다")
	if f("restore_petition_reopened"): resto.append("노인의 소 일은 다시 조사된다")
	var tail := ("내가 본 것과 들은 것 덕에 — " + ", ".join(resto) + ".") if not resto.is_empty() else "빼앗긴 것들이 다 돌아갔는지는 모른다."
	return {
		"case_title": "남원의 약속",
		"title": "옥문이 열린 날",
		"outcome": "RELEASED",
		"paragraphs": ["성춘향은 변학도의 수청을 끝내 거절했다. 이몽룡은 암행어사가 되어 돌아왔고, 변학도는 관인을 빼앗겼다.", action_line() + " " + tail],
		"record": "단서 %d개 · 관아 일 셋(술·쌀·상소). 기록책에 새로 적힌 곳 — 남원 관아 · 옥 · 동문 밖 박가네." % S.clues.size(),
	}

# ---------------------------------------------------------------------------
# 먼 길 막음 · 불러오기 · 기록책
# ---------------------------------------------------------------------------
func p2_travel_lock() -> String:
	var s := super()
	if s != "": return s
	if f("p2b_started") and not f("end_seen"): return "남원 관아 일이 아직 끝나지 않았다 — 지금은 멀리 갈 수 없다"
	return ""

# 장면 도중 저장이면 그 장면 처음으로(트리거 다시) — 끝난 장면(완료 깃발)은 다시 돌지 않는다. 한 관찰·결정·지고 간 물건·FIXED_BEAT는 그대로
const RESUME := [["c1300_morning", "duty_on"], ["c1401_beggar", "mongryong_return_seen"], ["c1501_wolmae", "wolmae_reunion_seen"],
	["c1601_reunion", "jail_reunion_seen"], ["c1701_feast", "feast_seen"], ["c2001_release", "last_choice_done"], ["c2201_end", "end_seen"]]
func p2_on_load() -> void:
	super()
	if not f("p2b_started"): return
	d.free_move = false
	for k in ["leash_on", "resto_on"]: S.flags.erase(k)
	for pr in RESUME:
		if not f(pr[1]): S.flags.erase("_trig_" + String(pr[0]))
	if not f("duty_on"): S.flags.erase("p2b_started")   # 아침 장면 도중 — 다시
	# 지고 가던 것은 그대로 지니고 있다(되돌리지 않는다)
	if f("wine_lifted") and not f("wine_stored") and not S.has(P2B.JAR): d.give(P2B.JAR, 1, true)
	if f("rice_lifted") and not f("rice_stored") and not S.has(P2B.SACK): d.give(P2B.SACK, 1, true)
	match S.phase:
		"jail":
			if f("wolmae_reunion_seen") and not f("jail_reunion_seen"): _stage_gate_night()
			elif not f("jail_reunion_seen"):
				S.flags.erase("mong_b_on"); S.flags.erase("wolmae_b_on")
		"feast":
			# 시 전 → 줄 끝에서 다시(시는 아직). 시 뒤 → 출두만 다시(c1801_resume) — 시는 다시 하지 않는다
			if not f("poem_done"):
				for k in ["mong_feast_in", "poem_called", "music_cut", "mong_b_on", "_trig_c1702_mong"]: S.flags.erase(k)
			else:
				S.flags.erase("mong_b_on")
			stage_feast()
		"reveal":
			S.flags["mong_b_on"] = true
			stage_feast()
			d.place_actor("mong_b", "ch_mong_court", null, "down")
			d.anim_actor("mong_b", "mapae")
			d.set_pose("saryeong", "kneel")
		"release":
			if not f("last_choice_done"):
				S.flags["mong_b_on"] = true; S.flags["wolmae_b_on"] = true
				d.place_actor("mong_b", "ch_mong_release", null, "left")
				d.place_actor("wolmae_b", "ch_wolmae_release", null, "left")
				S.flags.erase("chunhyang_released")   # 옥문 장면을 처음부터(beat2는 한 번만 센다)
	d.mark_dirty()

# 출두 뒤 불러온 저장(드묾 — 같은 흐름이라 보통은 저장되지 않음): 복구 물음만 다시(출두는 다시 하지 않는다)
func restoration_resume() -> void:
	if S.phase == "reveal" and f("royal_inspector_reveal") and not f("restore_done"): await restoration()

func p2_summary() -> Array:
	var p := super()
	if not f("p2b_started"): return p
	p.append("이튿날 아침 아전이 잔치 일 셋을 맡겼다. 술 수레, 동문 밖 박가네 쌀, 담 밑 노인.")
	if _pdone("wine"):
		var w: String = { "all": "아전 말대로 세 독을 다 내렸다.", "leave": "물목대로 두 독만 내리고 한 독은 수레에 남겼다.", "record": "세 독을 다 내렸지만 상인의 말을 적어 두었다." }.get(_pd("wine"), "")
		p.append("술 물목은 두 독이었는데 아전은 세 독을 다 내리라 했다. " + w)
	if _pdone("rice"):
		var r: String = { "all": "농민에게 물러서라 했다. 포졸이 넷을 다 실었다.", "one": "한 가마만 지고 왔다. 셋은 박가네 마당에 남았다.", "reask": "아전에게 다시 물었다. 두 가마만 들이라는 말이 나왔다." }.get(_pd("rice"), "")
		p.append("박가네 징발 표는 두 가마였는데 대문 앞에는 넷이 나와 있었다. " + r)
	if _pdone("petition"):
		var q: String = { "dismiss": "아전 말대로 노인을 돌려보냈다.", "process": "노인의 소지를 맨 위에 올리고 받은 날을 적었다.", "note": "노인의 말을 들은 그대로 적어 두었다." }.get(_pd("petition"), "")
		p.append("담 밑 노인의 소지는 열흘째 열리지도 않았다. " + q)
	if f("old_man_heard"): p.append("노인은 잔치에 쓴다며 소를 가져갔다고 했다. 들은 말이다. 책을 든 선비가 와서 적어 갔다는 말도 했다.")
	if f("mongryong_return_seen"): p.append("며칠 뒤 해 질 무렵 남문 밖에서 거지 차림의 몽룡을 보았다. 못 본 사람으로 해 달라고 했다.")
	if f("jail_reunion_seen"):
		p.append(("밤, 포졸에게 거들어 몽룡이 옥에 들었다. " if f("reunion_helped") else "밤, 월매가 포졸에게 엽전을 쥐여 주고 몽룡이 옥에 들었다. ") + "나는 창살 밖에 있었다.")
	if f("banquet_poem_seen"): p.append("잔치 날, 내가 나른 술독과 가마니가 상 곁에 있었다. 몽룡이 시를 썼다.")
	if f("royal_inspector_reveal"): p.append("말발굽 소리 뒤에 “암행어사 출두야!” 몽룡이 마패를 들었고, 변학도는 관인을 빼앗겼다.")
	if f("restore_uncertain"): p.append("몽룡이 본 것이 있느냐고 물었다. 빼앗긴 것들이 다 돌아갔는지는 아무도 확답하지 않았다.")
	elif f("restore_wine_paid") or f("restore_rice_returned") or f("restore_petition_reopened"):
		p.append("몽룡에게 본 것과 들은 것을 따로 말했다. 그 말은 피해 본 사람들 셈에 쓰였다.")
	if f("chunhyang_released"): p.append("옥문이 열렸다. 춘향 “왔으니 됐습니다.”")
	if last_line != "" or S.world.has("last_line"): p.append("춘향이 그날 줄 이야기를 했다. “%s”" % String(S.world.get("last_line", last_line)))
	return p
