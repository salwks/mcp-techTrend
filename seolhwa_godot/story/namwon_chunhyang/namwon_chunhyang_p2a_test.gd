# 대본 시험 PART II-A(--storytest=namwon_chunhyang:p2a|p2b|p2c|ctl) — namwon_chunhyang_test.gd가 부른다(같은 expect·walk_to·go).
#   p2a : 열림 판정(결정 §4 — 모든 조합 · 귀환 소문 · 지도 표) → 재방문(단오 없음·추수 차림) → 6A 행차(앞 포졸·가운데 가마·뒤 짐·양옆 군중) →
#         아전(맞소 · 맡는다) → 잡역(문서·기생·사령 줄) → 8A 점고(조작 그대로·줄 묶임) → 명령서 → 월매 집(먼저 경고) → 데려감(뒤따름) →
#         수청 8A(조작) → 두 번째 10A(춘향 높이) → 곤장(잡는다 — 맞음) → 팔을 내민다 → 옥까지 → 옥문 SEALED · 옥 차림 →
#         첫 밤(내가 가져다주겠소) → 옥 대화(왜) → II-A 끝 · 차일 규칙 · 조작 비율 기록 · II-B 없음 · 머리 다시 굽기 · 기록책
#   p2b : 아니오 · 싫다(포졸이 끌고 감) · 데려오라 했습니다 · 느슨하게(맞음) · 기다린다 · 포졸 설득
#   p2c : 무슨 일이오 · 맡는다 · 나오라 합니다 · 놓는다(맞음) · 팔 · 지나간다(향단이 다른 길로)
#   ctl : 창 모드 실제 시간 — 시험 봇이 실제 걸음(--ctlspeed, 기본 2.2 걷기)으로 다니고 대사는 읽는 시간만큼. 끝에 CTL 비율(목표 ≥0.70)
extends RefCounted

const P2 := preload("res://story/namwon_chunhyang/namwon_chunhyang_p2a_data.gd")
const Progress := preload("res://scripts/region/progress.gd")
const CaseRegistry := preload("res://scripts/story/case_registry.gd")
const MapLeads := preload("res://scripts/region/map_leads.gd")
const JournalBook := preload("res://scripts/story/journal_book.gd")
const Rumors := preload("res://story/rumors_data.gd")

var t      # namwon_chunhyang_test.gd 노드
var d
var br := "P2A"
var real := false        # ctl: 실제 걸음·실제 시간
var speed := 2.2
var probe := {}

func _init(test_node, branch: String) -> void:
	t = test_node; d = test_node.d; br = branch

func expect(c: bool, what: String) -> void: t.expect(c, what)

func _frames(n: int) -> void:
	for i in n: await t.get_tree().process_frame

func _idle() -> void: await t._idle()

# 실제 걸음(ctl) 또는 순간 이동(빠른 시험)
func walk(pts: Array) -> void:
	if not real:
		await t.walk_to(pts[pts.size() - 1])
		return
	for q in pts:
		var tgt: Vector2 = d.anchor(q)
		var guard := 0
		while guard < 60 * 400:
			guard += 1
			await t.get_tree().process_frame
			if not d.case_fn.controllable(): continue
			var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
			var v: Vector2 = tgt - pp
			var dt: float = t.get_process_delta_time()
			if v.length() < 0.3: break
			var step: float = minf(v.length(), speed * dt)
			var np := pp + v.normalized() * step
			d.set_player_pos(Vector3(np.x, d.world.height_at(np.x, np.y), np.y))
			d.main.player.facing = "right" if absf(v.x) > absf(v.y) and v.x > 0 else ("left" if absf(v.x) > absf(v.y) else ("down" if v.y > 0 else "up"))
			d.main.player.set_anim("walk")
		d.main.player.set_anim("idle")
	await _frames(4)

# 이야기가 다 돌 때까지(조건이 설 때까지) — 실제 시간이면 사람처럼 서서 기다린다
func until(cond: Callable, sec := 120.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await t.get_tree().process_frame
		if (Time.get_ticks_msec() - t0) / 1000.0 > sec: return false
	return true

func talk(id: String) -> void:
	if not real:
		await t.go(id, 1.2); return
	var a = d.actors.get(id)
	var p := Vector2(a.pos.x, a.pos.z)
	await walk([[p.x, p.y + 1.1]])
	await _idle()
	await until(func(): return d.case_fn.controllable(), 30.0)
	await _frames(2)
	d.interact(id)
	await _frames(2)
	await _idle()

func gated_on(id: String) -> bool: return t._gated_on(id)
func gate_off(id: String) -> bool: return t._gate_off(id)

# ---------------------------------------------------------------------------
func run() -> void:
	var S = d.S
	real = br == "CTL"
	if real:
		speed = float(d.main.args.get("ctlspeed", "2.2"))
		Engine.time_scale = 1.0
		d.ui.auto_real = true
		d.ui.auto_hold = 1.5   # 고르기·물건 카드에 사람이 쓰는 시간
	else:
		d.case_fn.fast_mul = 8.0
	if br == "P2A": _gate_checks()
	# PART I 끝 · 남원을 떠났다 · 강릉 완료(시험 저장을 꾸민다) → 다시 남원
	S.phase = "farewell"
	for k in ["case_started", "vista_seen", "bump_done", "met_bangja", "errand_choice", "errand_with", "refusal_seen", "mong_reacted", "evening_call",
			"first_meeting_done", "letter_asked", "letter_delivered", "walk_seen", "vow_invited", "vow_done", "vow_witness", "vow_heard", "farewell_scene_done",
			"part1_done", "farewell_talked", "chun_home", "bangja_off", "mong_off"]:
		S.flags[k] = true
	S.vars.CASE_NAMWON_CHUNHYANG_PART1_COMPLETE = true
	S.vars.CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1 = true
	S.vars[{ "P2A": "CASE_GANGNEUNG_COMPLETE", "P2B": "CASE_GYEONGJU_COMPLETE", "P2C": "CASE_HWANGJU_COMPLETE" }.get(br, "CASE_GANGNEUNG_COMPLETE")] = true
	d.teleport_to([-3227.8, 366.7], "up")   # 남문 밖(플레이 시험 저장과 같은 자리)
	d.case_fn.on_load()
	d.on_phase(); d._refresh()
	await _frames(12)
	expect(S.phase == "arrival" and S.is_flag("p2_started"), "PART II-A 열림 → 단계 arrival")
	expect(int(d.main.hour) == 10, "재방문 낮 10시")
	await _frames(20)
	# 단오 차림·군중은 없다(F-11) · 추수 차림만
	expect(gate_off("ti_swing") and gate_off("ti_streamers_ground") and gate_off("ti_ssireum"), "단오 차림 없음")
	expect(not d.main.crowd.is_shown("dano_market") and not d.main.crowd.is_shown("byeon_banquet"), "단오·잔치 군중 없음")
	expect(gated_on("ti_gamani_store_a") and gated_on("ti_byeotdan_south"), "PART II 추수 차림(곡식 가마니·볏단)")
	expect(gate_off("ti_dais") and gate_off("ti_chail") and gate_off("ti_hyeongteul"), "arrival엔 관아 단·차일·형틀 없음")
	expect(not d.actors.bangja.shown and not d.actors.mongryong.shown and not d.actors.chunhyang.shown, "방자·몽룡·춘향은 보이지 않는다")
	if br == "P2A": _hair_checks()
	# 비우기 구역(C63) — 재방문(arrival)부터 행차 길 한가운데에 고을 사람이 없다
	var amb = d.main.get("npcs_amb")
	var zone := { "path": P2.PROC_PATH, "width": P2.PROC_CLEAR_W }
	expect(d.ambient_zones().has("ch_proc_road") and amb != null and amb.zone_ids().has("ch_proc_road"), "arrival — 행차 길 비우기 구역 켜짐")
	# §19 6A 행차
	await walk([[-3228.0, 352.0], [-3228.0, 330.0], [-3228.0, 316.0]])
	await _idle()
	expect(S.is_flag("proc_seen") and S.has_clue("new_magistrate"), "C0601 6A 행차 — 새 사또(들음)")
	if not probe.is_empty() and probe.has("6a"):
		var p6: Dictionary = probe["6a"]
		expect(bool(p6.shot), "6A 각본 시점(낮고 긴 — 높이 %.1f)" % float(p6.cam_h))
		expect(float(p6.cam_h) < 2.5, "6A 낮은 카메라")
		expect(float(p6.pojol_z) < float(p6.gama_z) and float(p6.gama_z) < float(p6.porter_z), "앞 포졸(%.1f) · 가운데 가마(%.1f) · 뒤 짐(%.1f)" % [float(p6.pojol_z), float(p6.gama_z), float(p6.porter_z)])
		expect(int(p6.west) >= 3 and int(p6.east) >= 3, "군중 양옆(서 %d · 동 %d)" % [int(p6.west), int(p6.east)])
		expect(bool(p6.gama_node), "가마 소품이 행렬과 함께")
	if probe.has("6a_amb"):
		var pa: Dictionary = probe["6a_amb"]
		expect(bool(pa.zone_on) and int(pa.inzone) == 0, "6A 컷 — 행차 길 가운데 고을 사람 0(둘레 고을 사람 %d)" % int(pa.agents))
	expect(String(d.data.clues.new_magistrate.kind) == "heard", "새 사또 — 들은 것")
	var in_max := [0]
	var cond_in := func() -> bool:
		if amb != null: in_max[0] = maxi(in_max[0], amb.count_in(zone))
		return S.is_flag("proc_in")
	var ok_in := await until(cond_in, 140.0)
	expect(ok_in, "행차가 관아로 들어감")
	expect(amb != null and in_max[0] == 0, "행차 내내 길 가운데 고을 사람 없음(최대 %d)" % in_max[0])
	await _frames(3)
	expect(not d.ambient_zones().has("ch_proc_road") and amb != null and not amb.zone_ids().has("ch_proc_road"), "관아에 들자 비우기 풀림")
	var refilled := await until(func(): return amb != null and amb.count_in(zone) > 0, 40.0)
	expect(refilled, "풀린 뒤 보통 스트리밍이 길을 다시 채움(%d)" % (amb.count_in(zone) if amb != null else -1))
	# §20 아전
	var labour_pref: Array = { "P2A": ["맞소", "맡는다"], "P2B": ["아니오.", "싫다고"], "P2C": ["무슨 일이오", "맡는다"], "CTL": ["맞소", "맡는다"] }[br]
	t.prefer = labour_pref
	await walk([[-3226.0, 252.0], [-3172.0, 248.0], [-3166.4, 247.8]])
	await _idle()
	expect(S.is_flag("recog_done"), "C0701 아전 “전에 고개 범 일 때 포수하고 있던 사람 맞지?”")
	if br == "P2B":
		expect(S.is_flag("recog2_no") and S.is_flag("labour_refused") and not S.is_flag("labour_started"), "아니오 · 싫다고 함 — 아직 일 없음")
		expect(String(d.travel_lock()) != "", "싫다고 한 뒤에도 먼 길은 막힘(곧 끌려간다)")
		await walk([[-3182.0, 249.0]])
		await _idle()
		await until(func(): return S.is_flag("rounded_up") and not d.runner.busy, 30.0)
		expect(S.is_flag("rounded_up") and S.is_flag("labour_started") and S.has(P2.TALLY), "포졸이 장정들과 막음 — “관아에서 장정들 잠깐 쓰신다.” → 결국 잡역(목패)")
		expect(not S.is_flag("labour_accepted"), "첫 태도(싫다)만 기억 — labour_accepted 없음")
	else:
		expect(S.is_flag("labour_accepted") and S.has(P2.TALLY) and not S.is_flag("labour_refused"), "맡는다 — 목패")
		expect(S.is_flag("recog2_yes") if br != "P2C" else S.is_flag("recog2_what"), "알아봄 대답 기억")
	expect(S.phase == "office", "단계 office")
	await _frames(10)
	expect(d.actors.saryeong_w0.shown and d.actors.saryeong_senior.shown and d.actors.byeon.shown and d.actors.ibang.shown, "사령 줄·선임·변학도·이방이 선다")
	expect(String(d.actors.byeon.anim) == "sit" and not is_nan(d.actors.byeon.y_abs), "변학도 교의(대청 위)")
	expect(gated_on("ti_dais") and gated_on("ti_hyeongteul") and gate_off("ti_chail"), "office — 보계·형틀, 차일 없음")
	expect(String(d.travel_lock()) != "", "관아 일 도중 먼 길 막음 「%s」" % d.travel_lock())
	expect(S.has(P2.DOCS), "첫 일 — 문서 묶음")
	# 잡역 1·2·3
	await walk([[-3162.1, 243.0], [-3162.1, 230.0], [-3162.1, 219.5], [-3165.4, 212.2]])
	if br == "P2A":
		expect(d.case_fn.controllable(), "일하는 동안 조작은 플레이어에게")
		await t.cut("05_labour_control")
	await talk("ibang")
	expect(S.is_flag("docs_delivered") and not S.has(P2.DOCS), "이방에게 문서 — 다음은 기생")
	await walk([[-3162.1, 219.5], [-3157.6, 232.6]])
	await talk("gisaeng_1")
	expect(S.is_flag("gisaeng_called"), "바깥마당 기생들을 안으로")
	await walk([[-3162.1, 221.0], [-3162.1, 218.4], [-3168.7, 217.8]])
	# 줄에 서면 점고(8A) — 조작은 그대로, 줄을 벗어나면 끌려온다
	await until(func(): return S.is_flag("in_line"), 20.0)
	expect(S.is_flag("in_line"), "사령 줄 끝에 섬")
	await until(func(): return S.is_flag("summons_given") and not d.runner.busy, 200.0)
	if probe.has("jeomgo"):
		var pj: Dictionary = probe.jeomgo
		expect(float(pj.pitch) == 58.0 and float(pj.dist) == 21.0, "점고 공식 8A(58/21)")
		expect(bool(pj.ctl), "점고 동안 조작 가능(사령 줄)")
		expect(bool(pj.pulled), "줄을 벗어나면 제자리로(“제자리!”)")
		expect(int(pj.gisaeng_line) >= 6, "기생 여섯이 단 앞 줄에(%d)" % int(pj.gisaeng_line))
	expect(S.is_flag("jeomgo_done") and S.has_clue("bring_her") and String(d.data.clues.bring_her.by) == "변학도", "점고 — 이방 → 변학도 “데려와.”(들음 — 변학도)")
	expect(S.has(P2.SUMMONS) and S.has_clue("summons_paper"), "아전이 명령서를 준다")
	expect(not S.is_flag("leash_on") and not d.free_move, "점고 뒤 줄 묶임 풀림")
	# §24 월매 집
	t.prefer = { "P2A": ["좋은 일로"], "P2B": ["성춘향을 데려오라"], "P2C": ["관아에서 나오라"], "CTL": ["좋은 일로"] }[br]
	await walk([[-3162.1, 219.5], [-3162.1, 241.0], [-3170.0, 247.6], [-3228.0, 251.5], [-3228.0, 341.0], [-3228.0, 362.0], [-3226.0, 461.0], [-3216.0, 459.8]])
	await _idle()
	expect(S.is_flag("wolmae_summoned") and S.is_flag("escorting") and not S.has(P2.SUMMONS), "C0902 월매 집 — 춘향 “제가 가겠습니다.”")
	var w := ["summons_plain", "warned_wolmae", "summons_words"].filter(func(k): return S.is_flag(k))
	expect(w.size() == 1, "전할 말 하나만 기억(%s)" % [w])
	expect({ "P2A": "warned_wolmae", "P2B": "summons_words", "P2C": "summons_plain", "CTL": "warned_wolmae" }[br] in w, "고른 말 %s" % [w])
	expect(S.has_clue("chun_decides") and String(d.data.clues.chun_decides.by) == "춘향", "춘향이 스스로 정함(들음 — 춘향)")
	# 데려감 — 춘향은 제 걸음으로 뒤따른다
	t.prefer = { "P2A": ["포승 한쪽을 잡는다", "팔을 내민다"], "P2B": ["느슨하게", "그대로 기다린다"], "P2C": ["줄을 놓는다", "팔을 내민다"], "CTL": ["포승 한쪽을 잡는다", "팔을 내민다"] }[br]
	await walk([[-3226.0, 461.0], [-3228.0, 362.0], [-3228.0, 341.0], [-3228.0, 251.5], [-3170.0, 247.6], [-3162.1, 241.0], [-3162.1, 219.5], [-3162.1, 216.0]])
	if not real:
		var t0 := Time.get_ticks_msec()
		while not d.case_fn.chun_close() and Time.get_ticks_msec() - t0 < 60000:
			await t.get_tree().process_frame
		expect(d.case_fn.chun_close(), "춘향이 따라와 곁에(뒤따르기)")
		await t.walk_to([-3162.1, 215.0])
	# 수청 → 곤장 → 팔
	await until(func(): return S.is_flag("escort_jail") and not d.runner.busy, 240.0)
	var ps: Dictionary = d.case_fn.probe_sucheong
	expect(S.is_flag("sucheong1_done") and S.is_flag("sucheong2_done"), "수청 두 번 — 두 번 다 거절")
	expect(float(ps.get("first_pitch", -1)) == 58.0 and bool(ps.get("first_ctl", false)), "첫 요구 공식 8A — 사령 줄에서 조작을 쥔 채")
	expect(float(ps.get("second_pitch", -1)) == 22.0, "두 번째 요구 — 처음으로 춘향 높이(10A pitch 22)")
	var rs := ["restraint_obeyed", "restraint_loose", "restraint_refused"].filter(func(k): return S.is_flag(k))
	expect(rs.size() == 1 and rs[0] == { "P2A": "restraint_obeyed", "P2B": "restraint_loose", "P2C": "restraint_refused", "CTL": "restraint_obeyed" }[br], "줄 잡아 — %s 기록" % [rs])
	expect(S.is_flag("struck") and int(S.world.get("strikes", 0)) >= 6, "어느 경우든 춘향은 맞는다(%d)" % int(S.world.get("strikes", 0)))
	if probe.has("gonjang_cuts"): expect(int(probe.gonjang_cuts) == 4, "곤장 네 컷(얼굴·손·월매·기둥)")
	expect(d.case_fn.music_wanted() == "", "곤장 — BGM 없음")
	var arm := ["arm_offered", "arm_waited"].filter(func(k): return S.is_flag(k))
	expect(arm.size() == 1 and arm[0] == ("arm_waited" if br == "P2B" else "arm_offered"), "팔 — %s" % [arm])
	for k in ["byeon_arrives", "roll_call", "sucheong_demand", "refusal", "gonjang"]: expect(S.is_flag("beat_" + k), "FIXED_BEAT " + k)
	# 옥까지 데려간다(조작) → 옥문
	await walk([[-3162.1, 218.0], [-3162.1, 223.0], [-3167.8, 229.5]])
	if not real:
		var t1 := Time.get_ticks_msec()
		while not S.is_flag("jailed") and Time.get_ticks_msec() - t1 < 60000:
			await t.get_tree().process_frame
		if not S.is_flag("jailed"):
			t._log("DEBUG jail: player=%s chun=%s busy=%s close=%s esc=%s ph=%s" % [d.main.player_pos, d.actors.chunhyang.pos, d.runner.busy, d.case_fn.chun_close(), S.is_flag("escort_jail"), S.phase])
	await until(func(): return S.is_flag("dismissed") and not d.runner.busy, 120.0)
	var pj2: Dictionary = d.case_fn.probe_jail
	expect(S.is_flag("jailed") and String(pj2.get("gate", "")) == "SEALED" and String(pj2.get("cell", "")) == "SEALED", "옥문·살문 SEALED(%s/%s)" % [pj2.get("gate"), pj2.get("cell")])
	expect(S.phase == "jail" and S.is_flag("dismissed"), "단계 jail · 잡역 끝(목패는 아직)")
	expect(S.has(P2.TALLY), "목패를 지님(§30)")
	await _frames(6)
	expect(d.actors.chunhyang_jail.shown and String(d.actors.chunhyang_jail.spec.kind) == "chunhyang_prison" and not d.actors.chunhyang.shown, "옥 춘향(흰 무명·칼·묶은 머리) — 자세 %s" % d.actors.chunhyang_jail.anim)
	expect(String(d.actors.chunhyang_jail.anim) in ["sit", "kneel"], "옥 춘향 자세 sit/kneel")
	expect(d.case_fn.is_night(), "밤")
	# §30 첫날 밤
	t.prefer = { "P2A": ["내가 가져다주겠소"], "P2B": ["포졸을 설득"], "P2C": ["지나간다"], "CTL": ["내가 가져다주겠소"] }[br]
	if br == "P2A": t.prefer.append("왜 그렇게까지")
	if br == "CTL": t.prefer.append("몽룡이 돌아올")
	await walk([[-3162.1, 239.0], [-3163.6, 243.4]])
	await _idle()
	await until(func(): return S.is_flag("food_scene") and not d.runner.busy, 60.0)
	expect(S.is_flag("food_scene") and S.has_clue("food_refused"), "C1201 월매 “밥도 못 먹게 할 셈이오?” · 포졸 “안 된다니까.”")
	if br in ["P2A", "CTL"]:
		expect(S.is_flag("brought_prison_food") and S.has(P2.FOOD), "내가 가져다주겠다 — 바구니")
		await walk([[-3162.1, 238.0], [-3168.6, 229.6], [-3172.6, 230.6], [-3175.0, 231.4]])
		await until(func(): return S.is_flag("p2a_done") and not d.runner.busy, 60.0)
		expect(S.is_flag("jail_talked") and not S.has(P2.FOOD), "§31 옥 대화(12A) — 밥을 넣음")
		if br == "P2A": expect(S.is_flag("jail_talk_why") and not S.is_flag("jail_talk_return"), "“왜 그렇게까지 합니까?” 하나만")
	elif br == "P2B":
		expect(S.is_flag("persuaded_guard") and S.is_flag("food_in") and S.is_flag("p2a_done"), "포졸을 설득 — 포졸이 들고 감 · II-A 끝")
		expect(not S.is_flag("jail_talked"), "설득 — 옥 대화 없음")
	else:
		expect(S.is_flag("passed_food"), "지나간다")
		await walk([[-3180.0, 250.0]])
		await until(func(): return S.is_flag("p2a_done") and not d.runner.busy, 30.0)
		expect(S.is_flag("food_in") and S.is_flag("p2a_done"), "지나쳐도 밥은 다른 길로(향단) · II-A 끝")
	expect(String(d.travel_lock()) == "", "II-A 끝 — 먼 길 막음 풀림")
	expect(d.main.world.props.get_state("ti_jail/gate") == "SEALED", "옥문 다시 SEALED")
	# 조작 비율 측정 고리
	var cf = d.case_fn
	expect(cf.ctl.to_jail.all > 0.0 and cf.ctl.to_end.all >= cf.ctl.to_jail.all and cf.ctl.marks.size() >= 8, "조작 비율 고리(실제 시간) to_jail=%.2f to_end=%.2f" % [cf.ctl_ratio("to_jail"), cf.ctl_ratio("to_end")])
	printerr("CTL %s speed=%.1f to_jail=%.3f (%.1f/%.1fs) to_end=%.3f (%.1f/%.1fs)" % [br, speed, cf.ctl_ratio("to_jail"), cf.ctl.to_jail.ctl, cf.ctl.to_jail.all,
		cf.ctl_ratio("to_end"), cf.ctl.to_end.ctl, cf.ctl.to_end.all])
	if real: expect(cf.ctl_ratio("to_jail") >= 0.70, "조작 비율 ≥ 0.70 (재방문~투옥, 실제 시간) — %.3f" % cf.ctl_ratio("to_jail"))
	_no_p2b()
	if br == "P2A":
		await _chail_rule()
		_journal()
	await t._done()

# ---------------------------------------------------------------------------
func _gate_checks() -> void:
	var cands: Array = CaseRegistry.cases_for("JL_NAMWON_UNBONG")
	var base := { "CASE_NAMWON_COMPLETE": true, "CASE_HANYANG_BOOKSHOP_COMPLETE": true }
	expect(String(CaseRegistry.choose(cands, base).id) == "namwon_chunhyang", "PART I 뒤에도 춘향 사건이 돈다")
	var cf = d.case_fn
	var S = d.S
	var saved: Dictionary = S.vars.duplicate()
	var combos := [
		[{}, false, "아무것도"], [{ "P1": true }, false, "PART1만"], [{ "P1": true, "L": true }, false, "PART1+떠남(다른 고을 없음)"],
		[{ "P1": true, "GN": true }, false, "PART1+강릉(떠나지 않음)"], [{ "L": true, "GN": true }, false, "떠남+강릉(PART1 없음)"],
		[{ "P1": true, "L": true, "GN": true }, true, "PART1+떠남+강릉"], [{ "P1": true, "L": true, "GJ": true }, true, "PART1+떠남+경주"],
		[{ "P1": true, "L": true, "HJ": true }, true, "PART1+떠남+황주"], [{ "P1": true, "L": true, "PY": true }, false, "PART1+떠남+평양(셋 밖)"],
	]
	var key := { "P1": "CASE_NAMWON_CHUNHYANG_PART1_COMPLETE", "L": "CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1", "GN": "CASE_GANGNEUNG_COMPLETE",
		"GJ": "CASE_GYEONGJU_COMPLETE", "HJ": "CASE_HWANGJU_COMPLETE", "PY": "CASE_PYONGYANG_COMPLETE" }
	for c in combos:
		for k in key: S.vars[key[k]] = bool(c[0].get(k, false))
		expect(cf.part2_open() == c[1], "결정 §4 열림 %s → %s" % [c[2], c[1]])
	S.vars = saved
	# 열리지 않으면 farewell에 머문다(on_load가 PART II를 세우지 않음)
	S.phase = "farewell"; S.flags["part1_done"] = true; S.flags["farewell_scene_done"] = true; S.flags["chun_home"] = true
	S.vars.CASE_NAMWON_CHUNHYANG_PART1_COMPLETE = true; S.vars.CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1 = true
	for k in ["CASE_GANGNEUNG_COMPLETE", "CASE_GYEONGJU_COMPLETE", "CASE_HWANGJU_COMPLETE"]: S.vars[k] = false
	cf.on_load()
	expect(S.phase == "farewell" and not S.is_flag("p2_started"), "다른 고을을 끝내지 않으면 PART II 없음")
	S.vars = saved
	# 귀환 소문(강제 없음) — 셋 다 두 말 중 하나를 담고, 떠나기 전·그 고을 전에는 없다
	var seen := 0
	for r in Rumors.RUMORS:
		if not String(r.id).begins_with("CH_P2_"): continue
		seen += 1
		var reg: String = { "CH_P2_GN": "CASE_GANGNEUNG_COMPLETE", "CH_P2_GJ": "CASE_GYEONGJU_COMPLETE", "CH_P2_HJ": "CASE_HWANGJU_COMPLETE" }[String(r.id)]
		var on := { "CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1": true, reg: true, "CASE_NAMWON_CHUNHYANG_COMPLETE": false }
		var l := Rumors.pick(r, {}, on)
		expect(l.contains("남원 새 사또가 잔치를 크게 벌인다더군") or l.contains("곡식이고 술이고 관아로 들어간다던데"), "소문 %s “%s”" % [r.id, l])
		expect(Rumors.pick(r, {}, { "CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1": false, reg: true }) == "", "소문 %s 떠나기 전엔 없음" % r.id)
	expect(seen == 3, "귀환 소문 셋(강릉·경주·황주)")
	# 지도 붉은 표 — 남원 바깥에서 셈(저장 상태)
	var st := { "phase": "farewell", "flags": { "part1_done": true, "case_started": true }, "clues": [], "seen": {} }
	var vv := { "CASE_NAMWON_COMPLETE": true, "CASE_HANYANG_BOOKSHOP_COMPLETE": true, "CASE_NAMWON_CHUNHYANG_PART1_COMPLETE": true,
		"CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1": true, "CASE_GYEONGJU_COMPLETE": true }
	var ids := MapLeads.visible(null, { "namwon_chunhyang": st }, vv).map(func(e): return String(e.id))
	expect(ids.has("ch_p2_return"), "전국 지도 '남원 — 새 사또의 잔치' 표")
	st.flags["p2_started"] = true
	ids = MapLeads.visible(null, { "namwon_chunhyang": st }, vv).map(func(e): return String(e.id))
	expect(not ids.has("ch_p2_return"), "남원에 들면 귀환 표는 사라짐")

# 옥 춘향 머리 다시 굽기(사용자 결정 2) — 굽기 원본·결과가 새 머리
func _hair_checks() -> void:
	var src := FileAccess.get_file_as_string("res://tools/dress_art.js")
	expect(src.contains("dress: ['tied_low_hair', 'cangue']") and not src.contains("'loose_hair'"), "옥 춘향 머리 = 낮게 묶은 흐트러진 머리(tied_low_hair), 풀어 헤친 머리 없음")
	var jf := "res://data/frames_story_chunhyang_part2.json"
	var ok := FileAccess.file_exists(jf)
	var j = JSON.parse_string(FileAccess.get_file_as_string(jf)) if ok else null
	var clips: Dictionary = j.get("chunhyang_prison", {}).get("clips", {}) if j is Dictionary else {}
	var has_k := false; var has_s := false
	for k in clips:
		if String(k).contains("kneel"): has_k = true
		if String(k).contains("sit"): has_s = true
	expect(ok and has_k and has_s, "다시 구운 옥 춘향 은행(sit·kneel 포함)")
	var mt_json := FileAccess.get_modified_time(jf)
	var mt_src := FileAccess.get_modified_time("res://tools/dress_art.js")
	expect(mt_json + 600 >= mt_src, "굽기 결과가 머리 고침보다 새것(json %d · 원본 %d)" % [mt_json, mt_src])

# II-B 없음: 장면 번호 C13 이상 · 잔치·출두 단계 장면 · 거지 몽룡 · 잔치 군중
func _no_p2b() -> void:
	var late := []
	for e in d.events:
		if int(String(e).substr(1, 2)) >= 13: late.append(e)
	expect(late.is_empty(), "II-B 장면 없음(%s)" % [late])
	var beggar := []
	for id in d.actors:
		if String(d.actors[id].spec.get("kind", "")) in ["mongryong_beggar"]: beggar.append(id)
	expect(beggar.is_empty(), "거지 몽룡 없음(%s)" % [beggar])
	var flags_b := ["wine_recorded", "rice_left", "old_man_heard", "poem_called", "royal_inspector_reveal"]
	expect(flags_b.all(func(k): return not d.S.is_flag(k)), "II-B 플래그 없음")
	expect(not d.main.crowd.is_shown("byeon_banquet") and gate_off("ti_chail") and gate_off("ti_feast_w0"), "잔치 군중·차일·잔칫상 없음")
	var ph_used := {}
	for a in d.data.actors:
		var w := String(a.get("when", ""))
		for p in ["feast", "reveal", "release", "epilogue"]:
			if w.contains("ph('%s')" % p) and not String(a.id).begins_with("saryeong") and a.id != "pojol_gate": ph_used[p] = a.id
	expect(ph_used.is_empty(), "II-B 단계 인물 없음(%s)" % [ph_used])

# 차일 규칙(사용자 결정 1): 공식 8A(점고·수청·출두) FURLED · 잔치 놀이·낮은 틀 SPREAD · 컷에서만 바뀐다
func _chail_rule() -> void:
	var cf = d.case_fn
	expect(cf.chail_state_for("8A_jeomgo") == "FURLED" and cf.chail_state_for("8A_sucheong") == "FURLED" and cf.chail_state_for("8A_chuldu") == "FURLED", "차일: 8A 점고·수청·출두 FURLED")
	expect(cf.chail_state_for("feast_play") == "SPREAD" and cf.chail_state_for("10A") == "SPREAD" and cf.chail_state_for("17A") == "SPREAD", "차일: 잔치 놀이·낮은·가까운 틀 SPREAD")
	var S = d.S
	var ph0: String = S.phase
	S.phase = "feast"; d.on_phase(); d._refresh()
	await _frames(20)
	expect(gated_on("ti_chail"), "(시험) feast 강제 — 차일이 선다")
	d.main.world.set_prop_state("ti_chail/cloth", "SPREAD")
	cf.cut_to("8A_sucheong")
	expect(d.main.world.props.get_state("ti_chail/cloth") == "FURLED", "8A로 컷 → FURLED")
	d.camera({ "focus": [-3162.1, 214.0], "pitch": 30.0, "distance": 10.0, "fov": 36.0 })
	await _frames(10)
	expect(d.main.world.props.get_state("ti_chail/cloth") == "FURLED", "컷 없이 카메라만 바뀌면 그대로(눈앞에서 말지 않음)")
	cf.cut_to("feast_play")
	expect(d.main.world.props.get_state("ti_chail/cloth") == "SPREAD", "잔치 놀이로 컷 → SPREAD")
	d.camera(null)
	S.phase = ph0; d.on_phase(); d._refresh()
	await _frames(10)
	expect(gate_off("ti_chail"), "단계를 돌리면 차일 없음")

func _journal() -> void:
	var jd: Dictionary = d.journal_data()
	var txt := JSON.stringify(JournalBook.section(jd, "case"))
	expect(txt.contains("변학도") and txt.contains("옥"), "기록책 — 새 사또·옥")
	expect(txt.contains("데려와") and txt.contains("변학도"), "기록책 — 들은 말에 말한 사람(변학도)")
	expect(String(d.data.clues.gonjang.kind) == "fact" and String(d.data.clues.sucheong.kind) == "heard", "본 것(곤장)·들은 것(수청 거절) 구분")
