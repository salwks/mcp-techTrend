# 처음 하는 사람 안내 대본 시험 — --storytest=namwon:onboard (story_test.gd가 부른다, --headless 가능, --storyshots=폴더면 장면을 찍는다)
#   남원 v3.2 ACT 0~2(seolhwarok_NAMWON_v3.2_scenario.md §S0000~§14):
#   새 게임 → S0000(이겸의 세 문장·기록책 한 장 「남원」) → 이동 안내(실제로 5m 넘게 걸어야 끝) → 달리기 안내(실제로 2초 넘게 달려야 끝) →
#   길가 짚신(4m 먹빛·2m 'E 살펴보기'·단서 아님) → 나그네 둘 → S0001 남원 전경 → 주막 주변대화·주모 「…」 → E 키로 주모(첫 E가 먹는지) →
#   물음이 물음을 연다·물은 것은 사라진다·둘 이상이면 이겸 연결(CAMERA 1B)·사건 기록(도장 소리)·“어느 길로” → 지도에 북쪽 고갯길 →
#   M·R 안내는 시간으로 끝나지 않고 실제로 열어야 끝 · 첫 기록 원문 네 줄 → 역참 마부(처음 한 번, H 안내는 역마가 열렸을 때만) →
#   외딴집 이웃 아낙 → 오누이 세 물음(지난밤 = 목소리는 들은 대로, K_MIMIC 아님) · 기도 복선 → 아궁이·함지(어머니 회상 없음) →
#   첫 단서 안내 단계 0→1→2→3 → 첫 호랑이 조우(느린 화면·회피 안내·관찰 기록) → 설정(안내 끔이면 먹점 없음) → Esc 메뉴.
#   끝에 ONBOARDTEST PASS/FAIL.
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")
const Discovery := preload("res://scripts/region/discovery.gd")
const GameSettings := preload("res://scripts/story/game_settings.gd")

var T      # story_test
var d
var shots := false
var want: Array = []          # 다음 선택에서 고를 글(앞에서부터, 보이는 것 하나를 고르고 뺀다)
var choice_log: Array = []    # [[물음, [글], 이겸 연결이 이미 됐나]]
var cues: Array = []          # sfx_cue로 난 소리
var cam_dists: Array = []     # 대화 중 본 카메라 거리(CAMERA 1A·1B)
var neighbor_seen_on := false
var cam_seen: Array = []      # 연출 카메라(override) 기록
var combat_hints: Array = []  # 전투 안내가 뜬 차례
var seen_with := {}           # 전투 안내가 끝난 순간의 dodges_ok·blocks_ok
var fight_t := 0.0            # 첫 조우 싸움 길이(판 시각)
var fight_win := false

func run(t) -> void:
	T = t; d = t.d
	shots = d.main.args.has("storyshots") and DisplayServer.get_name() != "headless"
	GameSettings.test_override = { guide = "early", help = "normal" }
	# 새 게임과 같게: 처음 안내·지도 기록을 비운다
	Progress.data().onboard = {}
	Progress.data().known = {}
	Progress.data().cases = {}
	Progress.data().vars = {}
	d.S.reset()
	d.ui.auto_choice = _choose
	d.sfx_cue.connect(func(id): cues.append(String(id)))
	if shots: d.ui.auto_hold = 0.8   # 대화·선택을 찍을 만큼 띄워 둔다
	T._log("onboard 시작")
	# ---- S0000 ----
	if shots: d.ui.auto = false; _watch_prologue()
	await d.runner.run([{ "event": "S0000" }])
	d.ui.auto = true
	T.expect(d.S.is_flag("s0000_started") and d.S.is_flag("INTRO_MASTER_VOICE_DONE"), "S0000 이겸의 세 문장")
	T.expect(Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("s0000_start")) < 2.0, "S0000 남원 밖 길에서 시작")
	T.expect(not d.case_fn.has_method("mother_flashback") and not d.case_fn.has_method("rest"), "mother_flashback()·rest() 없음")
	for i in 120:
		await T._frames(1)
		if d.ui.hint_text().contains("이동"): break
	T.expect(d.ui.hint_text().contains("이동"), "이동 안내가 뜬다 (%s)" % d.ui.hint_text())
	# 순간이동은 이동으로 치지 않는다
	var p0: Vector2 = d.anchor("s0000_start")
	d.teleport_to(Vector2(p0.x - 2.5, p0.y + 0.5), "left")
	await T._frames(30)
	T.expect(not d.onboard.is_seen("MOVE"), "순간이동으로는 이동 안내가 끝나지 않는다")
	# 실제로 걷는다(키를 누른 채) — 5m 전에는 남고, 넘으면 끝
	await _hold(["move_left"], func(): return d.onboard.moved_m >= 2.0, 4.0)
	T.expect(not d.onboard.is_seen("MOVE") and d.ui.hint_text().contains("이동"), "2m 걸어서는 아직 (%.1fm)" % d.onboard.moved_m)
	await _hold(["move_left"], func(): return d.onboard.is_seen("MOVE"), 8.0)
	T.expect(d.onboard.is_seen("MOVE") and d.onboard.moved_m >= 5.0, "5m 넘게 걸으면 이동 안내가 끝난다 (%.1fm)" % d.onboard.moved_m)
	for i in 120:
		await T._frames(1)
		if d.ui.hint_text().contains("달리기"): break
	T.expect(d.ui.hint_text().contains("Shift") and d.ui.hint_text().contains("달리기"), "이어서 달리기 안내 (%s)" % d.ui.hint_text())
	await _hold(["move_right"], func(): return false, 1.2)   # 걷기만 해서는 안 끝난다
	T.expect(not d.onboard.is_seen("RUN"), "걷기로는 달리기 안내가 끝나지 않는다")
	await _hold(["move_right", "run"], func(): return d.onboard.ran_sec >= 1.0, 4.0)
	T.expect(not d.onboard.is_seen("RUN"), "1초 달려서는 아직 (%.1f초)" % d.onboard.ran_sec)
	await _hold(["move_right", "run"], func(): return d.onboard.is_seen("RUN"), 6.0)
	T.expect(d.onboard.is_seen("RUN") and d.onboard.ran_sec >= 2.0, "2초 넘게 달리면 달리기 안내가 끝난다 (%.1f초)" % d.onboard.ran_sec)
	# 처음 아는 곳: 남원 동문·큰길·주막(지도는 불러오기가 끝난 뒤 생긴다)
	for i in 120:
		await T._frames(1)
		if Discovery.is_known(d.space_id, "place:east_gate"): break
	await T._frames(30)
	var sp: String = d.space_id
	T.expect(Discovery.is_known(sp, "place:east_gate") and Discovery.is_known(sp, "place:main_road") and Discovery.is_known(sp, "place:tavern"), "지도 처음: 남원 동문·큰길·주막")
	T.expect(not Discovery.is_known(sp, "place:north_pass") and not Discovery.is_known(sp, "place:house") and not Discovery.is_known(sp, "place:clearing"), "지도 처음: 고갯길·외딴집·빈터는 없다")
	# 길가 짚신(v3.2 §5): 4m 안에서 약한 먹빛, 손 닿는 거리(2m)에서 'E 살펴보기', 단서 아님
	var sd: Vector2 = d.anchor("s0000_sandal")
	d.teleport_to(Vector2(sd.x + 3.4, sd.y), "left"); await T._frames(12)
	T.expect(d.onboard.last_marked.has("roadside") and (d._target == null or String(d._target.id) != "roadside"), "짚신 4m 안: 먹빛만(아직 E 없음)")
	d.teleport_to(Vector2(sd.x + 5.5, sd.y), "left"); await T._frames(12)
	T.expect(not d.onboard.last_marked.has("roadside"), "짚신 4m 밖: 먹빛 없음")
	d.teleport_to(Vector2(sd.x + 1.4, sd.y), "left"); await T._frames(12)
	T.expect(d._target != null and String(d._target.id) == "roadside" and String(d._target.label) == "살펴보기", "짚신 손 닿는 거리: E 살펴보기")
	await T.go("roadside")
	T.expect(d.S.is_flag("roadside_seen") and d.onboard.is_seen("INSPECT"), "길가 짚신 살펴보기")
	T.expect(d.S.clues.is_empty() and not d.S.is_flag("case_started"), "짚신은 사건 단서가 아니다")
	await T._frames(10)
	T.expect(not d.ui.hint_text().contains("기록책") and not _queued("JOURNAL"), "기록책 안내는 아직(사건 기록이 선 뒤에)")
	# 나그네 둘(서로 다른 말)
	await T.walk_to("s0000_rumor")
	for i in 600:
		await T._frames(1)
		if d.S.is_flag("INTRO_CONFLICTING_RUMOR_HEARD") and not d.actors.has("trav_a"): break
	T.expect(d.S.is_flag("INTRO_CONFLICTING_RUMOR_HEARD"), "S0000-C 나그네 둘이 지나간다")
	T.expect(d.S.clues.is_empty() and not d.S.is_flag("case_started"), "나그네 말은 시스템 효과가 없다")
	# ---- S0001 남원 전경 ----
	if shots: d.ui.auto = false; _watch_title()
	await T.walk_to("s0000_vista")
	await T._frames(10); await T._idle()
	d.ui.auto = true
	T.expect(d.S.is_flag("INTRO_NAMWON_TITLE_DONE") and d.S.seen.has("S0001"), "S0001 남원 전경·제목")
	T.expect(not d._cut and not d.blocks_move(), "전경 뒤 바로 조작")
	for i in 90:
		await T._frames(1)
		if d._music_cur == "bgm_day_calm": break
	T.expect(d._music_cur == "bgm_day_calm", "남원 낮 음악 bgm_day_calm (%s)" % d._music_cur)
	# ---- ACT 1 주막 ----
	await T.walk_to("tavern")
	await T._frames(40)
	var tt = d.main.get("_title")
	if tt != null:
		var nn: int = tt.shown.count("남원")
		T.expect(nn <= 1, "「남원」은 전경에서 한 번만(성문·주막에서 다시 안 뜸) — %d번" % nn)
	T.expect(d.S.flags.has("_trig_s0002_overhear"), "주막 주변대화가 들린다")
	var jp: Vector2 = Vector2(d.actors.jumo.pos.x, d.actors.jumo.pos.z)
	d.teleport_to(Vector2(jp.x, jp.y + 4.0), "up")
	for i in 240:
		await T._frames(1)
		if d.onboard.talk_marked.has("jumo"): break
	if not d.onboard.talk_marked.has("jumo"):
		var ja: Dictionary = d.actors.jumo
		var wp := Vector3(ja.pos.x, d.world.height_at(ja.pos.x, ja.pos.z) + 2.55, ja.pos.z)
		T._log("dbg vis=%s pend=%s frustum=%s busy=%s modal=%s cut=%s" % [ja.ch.visible, d.talk_pending("jumo"), d.main.cam.is_position_in_frustum(wp), d.runner.busy, d.ui.modal, d._cut])
	T.expect(d.onboard.talk_marked.has("jumo"), "주모 머리 위 「…」 (%s)" % JSON.stringify(d.onboard.talk_marked))
	T.expect(not d.S.is_flag("case_started") and not Discovery.is_known(sp, "place:north_pass"), "주모와 말하기 전: 사건 없음·고갯길 모름")
	if shots: _watch_dialog()
	# 첫 E: 키로 말을 건다(새 게임 직후 첫 E가 무시되던 흔들림 — 대상이 잡힌 프레임에 트리거가 이야기를 시작하면 대상을 내놓지 않는다)
	want = ["어떤 사람이오?", "언제 사라졌소?", "아이들은?", "마을에서는 찾아보지 않았소?", "어느 길로 갔소?", "그만 가 보겠소."]
	d.teleport_to(Vector2(jp.x, jp.y + 1.6), "up")
	var got_e := false
	for i in 90:
		await T._frames(1)
		if d._target != null and String(d._target.id) == "jumo" and not d.runner.busy:
			await _key(KEY_E)
			got_e = true
			break
	T.expect(got_e, "E 대상 = 주모")
	T.expect(d.runner.busy or int(d.S.talked.get("jumo", 0)) > 0, "첫 E로 주모와 말이 열린다")
	T.expect(d.onboard.is_seen("TALK"), "말을 걸면 대화 안내가 끝난다")
	await _watch_talk_cam()
	await T._idle()
	# 물음이 물음을 연다 · 물은 것은 다시 나오지 않는다 · 이겸 연결은 둘째 물음 뒤
	T._log("choices=%s" % JSON.stringify(choice_log))
	var l0: Array = choice_log[0][1] if choice_log.size() > 0 else []
	T.expect(l0 == ["어떤 사람이오?", "무슨 일이오?", "보지 못했소."], "주모 첫 물음 셋 %s" % JSON.stringify(l0))
	var l1: Array = choice_log[1][1] if choice_log.size() > 1 else []
	T.expect(l1.has("언제 사라졌소?") and l1.has("어느 길로 갔소?") and l1.has("아이들은?") and l1.has("마을에서는 찾아보지 않았소?") and not l1.has("어떤 사람이오?") and not l1.has("무슨 일이오?"),
		"“어떤 사람이오?” 뒤 새 물음 넷이 열리고 물은 것은 사라진다 %s" % JSON.stringify(l1))
	var l2: Array = choice_log[2][1] if choice_log.size() > 2 else []
	T.expect(choice_log.size() > 2 and not l2.has("언제 사라졌소?") and not l2.has("어떤 사람이오?"), "물은 것은 다시 나오지 않는다 %s" % JSON.stringify(l2))
	T.expect(choice_log.size() > 2 and not bool(choice_log[1][2]) and bool(choice_log[2][2]), "이겸 연결은 물음 하나 뒤가 아니라 둘 뒤")
	T.expect(d.S.is_flag("igyeom_link") and d.S.is_flag("case_started") and String(d.S.flags.get("route", "")) == "jumo", "이겸 연결 → 사건 기록")
	T.expect(cues.has("journal_stamp"), "사건 기록 도장 소리(journal_stamp) %s" % JSON.stringify(cues))
	var has_1a := cam_dists.any(func(x): return absf(x - 13.5) < 0.05)
	var has_1b := cam_dists.any(func(x): return absf(x - 12.15) < 0.05)
	T.expect(has_1a and has_1b, "대화 카메라 1A(13.5)·1B(12.15) 본 거리 %s" % JSON.stringify(cam_dists))
	T.expect(d.talk_cam.is_empty() and d.main.rig.override == null, "대화가 끝나면 평소 시점")
	T.expect(d.S.is_flag("jq_search") and _data_has("첫날엔 장정 셋이 고개를 올라갔소.") and _data_has("서낭당 못 가서 범 우는 소리를 듣고 돌아왔지.")
		and _data_has("포수는?") and _data_has("그 양반도 찾아봤다는데, 피 묻은 자리부터는 범 영역이라더군."), "마을에서 찾아봤다(장정 셋·포수)")
	T.expect(d.S.is_flag("heard_pass_road") and Discovery.how(sp, "place:north_pass") == "told", "“어느 길로 갔소” → 북쪽 고갯길이 지도에(들음)")
	# 첫 기록(§9 원문 네 줄)
	var jd: Dictionary = d.journal_data()
	var cs := _page_text(jd, 1)
	var rec: Array = d.case_fn.summary().slice(0, 4)
	T.expect(rec == ["떡장수 아낙이 사흘째 돌아오지 않는다.", "마지막으로 북쪽 고갯길로 갔다.", "집에는 아이 둘이 남아 있다.", "이겸으로 보이는 선비도 이 일을 물었다."],
		"첫 기록 원문 네 줄 %s" % JSON.stringify(rec))
	T.expect(cs.contains("산길의 실종") and cs.contains("이겸으로 보이는 선비도 이 일을 물었다.") and cs.contains("◇ 들음 — 주모") and cs.contains("아직 모르는 것"),
		"사건 기록: 산길의 실종 · 첫 기록 · 들음 — 주모 · 아직 모르는 것")
	T.expect(not _has_counter(cs) and not _has_counter(_page_text(jd, 0)), "숫자 체크리스트 없음")
	# M·R 안내: 시간이 지나도 끝나지 않는다 — 실제로 열어야
	T.expect(_queued("MAP"), "M 지도 안내가 선다")
	T.expect(_queued("JOURNAL"), "R 기록책 안내가 선다")
	if shots: _watch_hint("지도", "map_hint")
	await _secs(14.0)
	T.expect(not d.onboard.is_seen("MAP") and not d.onboard.is_seen("JOURNAL"), "14초 지나도 M·R 안내는 끝나지 않는다")
	T.expect(d.ui.hint_text().contains("지도") or d.ui.hint_text().contains("기록책"), "안내가 아직 떠 있다 (%s)" % d.ui.hint_text())
	await _key(KEY_R)
	await T._frames(6)
	T.expect(d.ui.journal_open and d.onboard.is_seen("JOURNAL"), "R로 기록책을 열면 기록책 안내가 끝난다")
	if shots:
		d.ui.journal_page(1)
		await _shot("journal_first_record", 100)
	await _key(KEY_R)
	await T._frames(6)
	T.expect(not d.ui.journal_open, "R로 닫힌다")
	T.expect(not d.onboard.is_seen("MAP"), "기록책을 열어도 지도 안내는 남는다")
	var mp = d.main.get("_map")
	T.expect(mp != null and not mp._meta.is_empty(), "지도가 있다")
	if mp != null and not mp._meta.is_empty():
		await _key(KEY_M)
		await T._frames(6)
		T.expect(mp.visible and d.onboard.is_seen("MAP"), "M으로 지도를 열면 지도 안내가 끝난다")
		await _shot("map_open", 14)
		await _key(KEY_M)
		await T._frames(6)
	# ---- 역참·마방(§10): 문 앞에 처음 다가갈 때 한 번 ----
	T.expect(d.data.anchors.has("station_wait") and d.data.anchors.has("station_yard"), "역참 자리는 stations.json에서")
	if shots: _watch_dialog()
	want = ["역마는 어떻게 쓰오?", "말을 빌릴 수 있소?", "그냥 가겠소."]
	await T.walk_to("station_wait")
	await T._frames(20); await T._idle()
	T.expect(d.S.is_flag("station_tut_seen") and d.S.is_flag("st_q_how") and d.S.is_flag("st_q_rent"), "마부: 먼 길 가시오? · 물음 둘")
	var fr: bool = d.case_fn.fast_ready()
	T.expect(not fr and not d.case_fn.fast_hint_shown and not _queued("FAST"), "역마로 갈 곳이 없으면 H 안내 없음")
	var n_talk := choice_log.size()
	await T.walk_to("tavern"); await T._frames(10)
	await T.walk_to("station_wait"); await T._frames(20); await T._idle()
	T.expect(choice_log.size() == n_talk, "마부 안내는 처음 한 번만")
	# ---- ACT 2 외딴집(§11~§14) ----
	T.expect(not Discovery.is_known(sp, "place:house"), "외딴집은 아직 지도에 없다")
	if shots: _watch_dialog()
	_watch_neighbor()
	await T.walk_to("yard")
	await T._frames(20); await T._idle()
	T.expect(d.S.is_flag("neighbor_visit_seen") and neighbor_seen_on, "외딴집 18m 안: 이웃 아낙이 나온다")
	for i in 900:
		await T._frames(1)
		if not d.actors.neighbor_visit.shown: break
	T.expect(not d.actors.neighbor_visit.shown and not d.S.is_flag("neighbor_visit_on"), "이웃 아낙은 방앗간 쪽으로 가고 사라진다")
	T.expect(not d._cut and not d.blocks_move(), "이웃 아낙 뒤 조작권")
	for i in 240:
		await T._frames(1)
		if Discovery.how(sp, "place:house") == "visited": break
	T.expect(Discovery.how(sp, "place:house") == "visited", "가 본 외딴집이 지도에")
	want = ["지난밤엔 괜찮았니?", "어머니는 언제 나갔니?", "어디로 가셨니?", "문 꼭 걸고 있거라."]
	var c0 := choice_log.size()
	if shots: _watch_dialog()
	await T.go("nui")
	var k0: Array = choice_log[c0][1] if choice_log.size() > c0 else []
	T.expect(k0 == ["어머니는 언제 나갔니?", "어디로 가셨니?", "지난밤엔 괜찮았니?", "문 꼭 걸고 있거라."], "오누이 세 물음 %s" % JSON.stringify(k0))
	var k1: Array = choice_log[c0 + 1][1] if choice_log.size() > c0 + 1 else []
	T.expect(not k1.has("지난밤엔 괜찮았니?") and k1.size() == 3, "물은 것은 사라진다 %s" % JSON.stringify(k1))
	T.expect(d.S.is_flag("met_kids") and d.S.has_clue("kids_story"), "오누이를 만났다(met_kids)")
	T.expect(d.S.is_flag("voice_at_night") and d.S.has_clue("voice_at_night") and String(d.data.clues.voice_at_night.title) == "어젯밤의 목소리", "지난밤: 어젯밤의 목소리(들음)")
	T.expect(not d.S.knows("K_MIMIC"), "목소리를 흉내라고 아직 정하지 않는다(K_MIMIC 없음)")
	T.expect(d.S.is_flag("prayer_foreshadow"), "기도 복선(짧게)")
	T.expect(d.S.is_flag("kq_when") and d.S.is_flag("kq_where"), "언제·어디로")
	await T.go("hearth")
	T.expect(d.S.has_clue("cold_hearth"), "아궁이: 식은 재")
	var n_actors: int = d.actors.size()
	await T.go("kneading")
	T.expect(d.S.has_clue("mother_route") and String(d.data.clues.mother_route.text) == "실종 당일 새벽에도 떡을 만들어 장으로 갔다.", "함지: 떡가루 묻은 함지(기록)")
	T.expect(not d.actors.has("mother") and not d.actors.has("mother_past") and d.actors.size() == n_actors and not d.S.is_flag("show_mother"), "함지에서 어머니가 나타나지 않는다")
	for o in d.data.objects:
		if String(o.id) == "kneading": T.expect(not JSON.stringify(o.steps).contains("\"call\""), "함지 조사는 회상을 부르지 않는다")
	# ---- ACT 3 고갯길(v3.2 §15~§22) — 첫 단서 안내 단계(§14) · 떡 셋의 말 · 6~8m 먹빛 · 다가가면 카메라가 잠깐 기울었다 돌아온다 ----
	if shots:
		d.ui.auto_real = true; Engine.time_scale = 1.0   # 찍을 때는 자막·카메라를 실제 길이로
		_watch_act3()
	T.expect(int(d.S.flags.get("CASE_NAMWON_GUIDANCE_STAGE", 0)) == 0, "안내 단계 0")
	T.expect(_paths("trail") >= 2, "§73 고갯길을 아는 길 둘 이상(주모·아이들·직접) — %d" % _paths("trail"))
	# 처음 그 단서 7m 안에 들면 카메라가 잠깐 기울었다가 돌아온다(보는 것이 아니라 다가감) — 9m 밖에서는 아니다
	var c1: Vector2 = d.anchor("cake_1")
	d.teleport_to(Vector2(c1.x, c1.y + 9.5), "up"); await _secs(0.5)
	T.expect(not d.case_fn.nudged.has("cake_1"), "9.5m 밖에서는 카메라가 기울지 않는다 %s" % JSON.stringify(d.case_fn.nudged))
	d.teleport_to(Vector2(c1.x, c1.y + 6.0), "up"); await _secs(0.35)
	T.expect(d.case_fn.nudged.has("cake_1"), "6m 안: 단서 쪽으로 카메라가 잠깐 기운다 %s" % JSON.stringify(d.case_fn.nudged))
	T.expect(d.onboard.last_marked.has("cake_1"), "6m 안: 먹빛 표시")
	await _secs(0.8)
	T.expect(d.main.rig.focus == null and d.main.rig.override == null, "기운 카메라는 곧장 돌아온다(고정 카메라)")
	var mr: Dictionary = {}
	for o in d.data.objects:
		if String(o.id) in ["cake_2", "torn_skirt", "basket"]: mr[o.id] = float(o.get("mark_r", 0.0))
	T.expect(mr.values().all(func(x): return x >= 6.0 and x <= 8.0), "고갯길 단서 먹빛 거리 6~8m %s" % JSON.stringify(mr))
	await T.go("cake_1")
	T.expect(int(d.S.flags.get("CASE_NAMWON_GUIDANCE_STAGE", 0)) == 1, "첫 단서 → 단계 1")
	T.expect(d.case_fn.last_guide_line.contains("같은 떡이 보인다"), "첫 단서 강한 안내 줄 (%s)" % d.case_fn.last_guide_line)
	d.teleport_to("cake_1", "up"); await T._frames(20)
	T.expect(d.onboard.last_marked.has("cake_2"), "다음 떡을 멀리서도 먹점으로 (%s)" % JSON.stringify(d.onboard.last_marked))
	if shots: await _shot("guide_dot", 10)
	d.case_fn.last_guide_line = ""
	await T.go("cake_2")
	T.expect(int(d.S.flags.get("CASE_NAMWON_GUIDANCE_STAGE", 0)) == 2 and d.case_fn.last_guide_line == "", "둘째 단서 → 단계 2(줄 없음)")
	jd = d.journal_data()
	T.expect(_page_text(jd, 1).contains("떡이 고갯길을 따라 이어진다."), "기록 갱신 — 떡이 고갯길을 따라 이어진다.")
	# §24 첫 조우는 단서 셋 이상일 때만 — 단서 둘로 first_seen에 가도 일어나지 않는다
	T.expect(d.case_fn.path_clues() == 2, "고갯길 단서 둘")
	await T.walk_to("first_seen"); await T._frames(20); await T._idle()
	T.expect(not d.S.is_flag("first_encounter"), "단서 둘로는 first_seen에 가도 첫 조우가 없다")
	await T.go("cake_3")
	T.expect(d.case_fn.cake_order.map(func(x): return x[1]) == [1, 2, 3], "떡 셋 — 찾은 차례대로 %s" % JSON.stringify(d.case_fn.cake_order))
	T.expect(d.case_fn.CAKE_LINES[0][0] == "떡 하나가 흙에 반쯤 묻혀 있다." and d.case_fn.CAKE_LINES[1][0] == "같은 떡." and d.case_fn.CAKE_LINES[2][0] == "또 하나.", "떡 셋의 말(원문)")
	T.expect(d.S.knows("K_FOOD"), "셋째 떡 뒤 K_FOOD(먹이에 끌린다 — 추정)")
	T.expect(String(d.data.rules.K_FOOD.get("kind", "guess")) == "guess", "K_FOOD는 추정(guess)")
	jd = d.journal_data()
	T.expect(_page_text(jd, 1).contains("하나씩 내놓은 것 같다"), "셋째 떡: 하나씩 내놓은 것 같다")
	T.expect(int(d.S.flags.get("CASE_NAMWON_GUIDANCE_STAGE", 0)) == 3, "셋째 단서 → 단계 3(일반 조사)")
	# §19 치맛자락 — 짧은 인서트(낮은 각도 · FOV 48)
	cam_seen.clear(); _watch_cam()
	await T.go("torn_skirt")
	T.expect(d.S.has_clue("torn_skirt") and cam_seen.any(func(c): return absf(float(c.get("fov", 0)) - 48.0) < 0.5 and float(c.get("pitch", 99)) < 25.0), "치맛자락 인서트(낮은 각도·FOV 48) %s" % JSON.stringify(cam_seen))
	T.expect(d.main.rig.override == null and d.main.rig.focus == null, "인서트 뒤 평소 시점")
	# 이제 단서 셋 — first_seen에 다가가면 첫 조우(§24~§26). 봇은 처음 몸 낮춤을 볼 때까지 다가가지 않고, 베지 않는다(죽이기가 목표가 아님)
	T.bot_wait_first = true
	T.bot_passive = true
	_watch_combat()
	var h0: float = d.main.hour
	await T.walk_to("first_seen")
	await T._frames(20); await T._idle()
	T.bot_wait_first = false
	T.bot_passive = false
	T.expect(d.S.is_flag("first_encounter"), "단서 셋 + first_seen 접근 → S0005 첫 조우")
	T.expect(d.case_fn.first_passes == ["right", "left"], "무언가 오른쪽, 이어 왼쪽 나무 사이를 지나간다 %s" % JSON.stringify(d.case_fn.first_passes))
	T.expect(d.case_fn.glimpse_t > 0.0, "CAMERA 4A 숲 안쪽 얼굴")
	T.expect(cues.has("wind") and cues.has("brush_rustle") and cues.has("tiger_growl"), "발걸음·바람·덤불·그르렁 %s" % JSON.stringify(cues))
	T.expect(d.case_fn.dusk_from >= 0.0 and d.main.hour >= minf(d.case_fn.dusk_from, h0) - 0.01 and d.main.hour > 16.5, "해질녘 보정 — 지금 시각에서 저녁 쪽으로(%.2f → %.2f)" % [d.case_fn.dusk_from, d.main.hour])
	T.expect(d.case_fn.first_result == "retreated", "베지 않고 버텨도 범이 물러난다(%s) — 목표는 죽이기가 아니다" % d.case_fn.first_result)
	T.expect(fight_t >= 18.0 and fight_t <= 30.0, "버틴 시간 약 20~25초 (%.1f초)" % fight_t)
	T.expect(not fight_win and d.combat_view.battle.tiger.undying, "첫 조우의 범은 쓰러지지 않는다(undying)")
	T.expect(d.onboard.is_seen("COMBAT_DODGE") and d.onboard.is_seen("COMBAT_GUARD"), "K 회피·L 막기 안내를 실제로 해서 마쳤다")
	T.expect(combat_hints == ["COMBAT_DODGE", "COMBAT_GUARD"], "안내 차례: K 회피 → L 막기 %s" % JSON.stringify(combat_hints))
	T.expect(seen_with.get("COMBAT_DODGE", 0) > 0 and seen_with.get("COMBAT_GUARD", 0) > 0, "회피는 실제로 피했을 때·막기는 실제로 막았을 때 끝났다 %s" % JSON.stringify(seen_with))
	T.expect(absf(Engine.time_scale - (1.0 if shots else float(d.main.args.get("storyspeed", "2.5")))) < 0.01, "느린 화면이 풀렸다 (%.2f)" % Engine.time_scale)
	T.expect(d.S.has_clue("first_sight") and String(d.data.clues.first_sight.title) == "고갯마루의 범", "기록: 고갯마루의 범")
	jd = d.journal_data()
	cs = _page_text(jd, 1)
	T.expect(cs.contains("몸을 낮춘 뒤 잠시 멈춘다.") and cs.contains("그다음 곧장 돌진한다."), "관찰 기록 두 줄")
	T.expect(not cs.contains("패턴") and not cs.contains("해금"), "시스템 용어 없음")
	for i in 90:
		await T._frames(1)
		if d._music_cur == "": break
	T.expect(d._music_cur == "", "첫 조우 뒤 낮 음악은 멈춘다 (%s)" % d._music_cur)
	for i in 600:
		await T._frames(1)
		if not d.actors.has("tiger_flee"): break
	T.expect(not d.actors.has("tiger_flee"), "물러난 범은 숲으로 들어가 사라진다")
	# §20 피 · §21 발자국(카메라가 자국을 따라 약 2초) · §22 광주리(CAMERA 3A) → §23 과거 장면
	cues.clear()
	await T.go("blood")
	T.expect(d.S.has_clue("blood") and String(d.data.clues.blood.text).begins_with("마른 피."), "피 — 마른 피.")
	await T.go("tracks")
	T.expect(d.S.has_clue("tracks") and d.case_fn.pan_points == d.case_fn.TRACK_PAN.size(), "발자국: 자국을 따라 카메라가 간다(%d점)" % d.case_fn.pan_points)
	cam_seen.clear(); _watch_cam()
	await T.go("basket")
	T.expect(cam_seen.any(func(c): return absf(float(c.get("pitch", 0)) - 34.0) < 0.1 and absf(float(c.get("distance", 0)) - 10.0) < 0.1 and absf(float(c.get("fov", 0)) - 42.0) < 0.1), "CAMERA 3A(34·10·42)")
	var pl: Dictionary = d.case_fn.past_look
	T.expect(d.S.is_flag("beat_mother_harmed") and d.S.is_flag("past_scene_seen"), "광주리 → 어머니의 과거 장면")
	T.expect(not bool(pl.get("player_visible", true)) and float(pl.get("past", 0.0)) > 0.9 and float(pl.get("letterbox", 0.0)) > 0.1, "과거 장면: 플레이어 없음·채도 뺌·먹빛 가장자리·조금 두꺼운 띠 %s" % JSON.stringify(pl))
	T.expect(d.case_fn.past_voices == 3 and d.case_fn.past_cakes == 2, "목소리 세 번 · 떡 둘을 던지고 마지막엔 빈 광주리 (%d·%d)" % [d.case_fn.past_voices, d.case_fn.past_cakes])
	T.expect(cues.has("breath_gasp") and cues.has("basket_roll") and cues.find("breath_gasp") < cues.find("basket_roll"), "CUT TO BLACK — 숨 들이켬 → 광주리 구르는 소리")
	T.expect(d.main.player.visible and float(d.main.post.past) == 0.0 and not d.actors.has("mother_past"), "현재로 돌아옴(플레이어·화면)")
	# 과거 장면은 사실로 기록되지 않는다 — 남는 것은 본 흔적만
	jd = d.journal_data()
	cs = _page_text(jd, 1)
	T.expect(not d.S.has_clue("pass_memory") and not cs.contains("떡 하나 주면") and not cs.contains("사흘 전 고갯길"), "기록책에 과거 장면이 사실로 적히지 않는다")
	T.expect(cs.contains(d.case_fn.PAST_KEEP), "기록에는: 빈 광주리와 피, 큰 짐승 흔적.")
	if shots:
		d.ui.journal_show(jd); d.ui.journal_page(1)
		await _shot("journal_after_pass", 60)
		d.ui.journal_close()
	# ---- ACT 5(§27~§30) — 포수 · 방앗간 · 연결 추론 · 외딴집 쪽 흰 발자국 ----
	T.expect(_paths("mimic") >= 2, "§73 흉내 의심 길 둘 이상(목소리·밀가루·밤) — %d" % _paths("mimic"))
	T.expect(_paths("house") >= 2, "§73 외딴집을 아는 길 둘 이상(주모·흔적·직접) — %d" % _paths("house"))
	T.expect(not d.S.is_flag("link_inferred") and not d.S.knows("K_MIMIC"), "밀가루를 보기 전엔 연결 추론 없음")
	if shots: _watch_dialog()
	want = ["사람을 노리오?", "전부터 있었소?", "어디로 가는 것 같소?", "그놈은 어디 사오?", "그만 가 보겠소."]
	var ch0 := choice_log.size()
	await T.go("hunter")
	T.expect(d.S.is_flag("hunter_met") and d.S.has_clue("hunter_word") and d.S.is_flag("hq_where"), "§27 포수: 봤소? · 물음")
	var hl: Array = choice_log[ch0][1] if choice_log.size() > ch0 else []
	T.expect(hl.has("전부터 있었소?") and hl.has("사람을 노리오?") and hl.has("어디로 가는 것 같소?") and not hl.has("그놈이 그 집으로 올지도 모르오."), "포수 물음 셋(역할 나누기는 아직) %s" % JSON.stringify(hl))
	T.expect(not d.S.is_flag("hunter_watch"), "역할 나누기는 범이 집 쪽으로 간다고 짐작한 뒤")
	# §28 방앗간 — 멀리서 가루 소리 → 주인 → 밀가루 바닥(앞발이 희다) → 물음. 정답(흉내)을 말하지 않는다
	cues.clear()
	await T.walk_to("mill")
	for i in 240:
		if cues.has("flour_rustle"): break
		await T._frames(1)
	await T._idle()
	T.expect(cues.has("flour_rustle"), "방앗간에 다가가면 가루 소리")
	if shots: _watch_dialog()
	want = ["무슨 짐승 같소?", "곡식은 먹었소?", "언제부터 그랬소?", "그만 가 보겠소."]
	await T.go("miller")
	T.expect(d.S.is_flag("mill_talked") and d.S.has_clue("flour_sack") and d.S.has_clue("flour_prints") and d.S.is_flag("flour_prints"), "§28 방앗간: 또 왔구먼 · 밀가루 바닥(flour_prints)")
	var said := JSON.stringify(load("res://story/namwon/namwon_data.gd").miller_questions()) + JSON.stringify(d.data.actors.filter(func(a): return a.id == "miller"))
	T.expect(not said.contains("흉내") and not said.contains("사람 손") and not said.contains("목소리"), "방앗간 주인은 정답을 말하지 않는다")
	# §29 연결 추론 — 한 줄만, 정답으로 정하지 않는다
	T.expect(d.S.is_flag("link_inferred"), "§29 목소리 + 밀가루 + 첫 조우 → 연결 추론")
	jd = d.journal_data()
	cs = _page_text(jd, 1)
	T.expect(cs.contains("어젯밤 아이들이 들었다는 목소리와 이 범은 관계가 있을 수 있다."), "기록책 한 줄: …관계가 있을 수 있다.")
	T.expect(not cs.contains("흉내 낸다") and not cs.contains("흉내를 낸다"), "흉내를 사실로 정하지 않는다")
	T.expect(d.S.knows("K_MIMIC") and String(d.data.rules.K_MIMIC.kind) == "guess" and String(d.data.rules.K_MIMIC.text).contains("확인하지 못했다"), "K_MIMIC은 추정(아직 확인하지 못했다)")
	# §30 흰 발자국 → “…집 쪽이다.” → 목적이 보호로 · 포수와 역할을 나눈다
	cam_seen.clear(); _watch_cam()
	await T.walk_to("white_trail_a")
	for i in 240:   # 자리 트리거는 0.2초마다 — 돌기 시작할 때까지
		if d.runner.busy or d.S.is_flag("tiger_house_suspected"): break
		await T._frames(1)
	await T._idle()
	T.expect(d.S.is_flag("tiger_house_suspected") and d.S.has_clue("white_trail"), "§30 흰 발자국 — …집 쪽이다(tiger_house_suspected)")
	T.expect(cam_seen.size() >= 1 and d.main.rig.override == null, "흰 발자국을 짧게 따라간 뒤 평소 시점")
	T.expect(d.case_fn.summary().any(func(x): return String(x).contains(d.case_fn.PURPOSE_LINE)), "목적: 오늘 밤은 아이들 곁에")
	want = ["그만 가 보겠소."]
	ch0 = choice_log.size()
	await T.go("hunter")
	hl = choice_log[ch0][1] if choice_log.size() > ch0 else []
	T.expect(not hl.has("그놈이 그 집으로 올지도 모르오.") and not d.S.is_flag("hunter_watch"), "포수 역할 나누기는 낮의 물음이 아니다(해 질 무렵 외딴집에서) %s" % JSON.stringify(hl))
	# 다음(ACT 6): 외딴집 마당에 다가가면 해 질 무렵 귀환이 열린다 — 옛 다리(dusk_wait·night_fall)는 없다
	T.expect(d.case_fn.night_ready() and not d.case_fn.has_method("night_fall"), "해 질 무렵 귀환이 열린다(night_ready) · night_fall 없음")
	T.expect(not d.data.objects.any(func(o): return String(o.id) == "dusk_wait"), "dusk_wait 다리 없음")
	if shots:
		d.ui.auto_real = false; Engine.time_scale = float(d.main.args.get("storyspeed", "2.5"))
	# ---- 설정: 상호작용 안내 끔 ----
	GameSettings.test_override = { guide = "off", help = "normal" }
	await T._frames(10)
	T.expect(d.onboard.last_marked.is_empty(), "상호작용 안내 끔 → 먹점 없음")
	GameSettings.test_override = { guide = "early", help = "normal" }
	# Esc 멈춤 메뉴: 화면이 멈추고, 닫으면 풀린다
	d.onboard.open_menu()
	await d.get_tree().process_frame
	T.expect(d.get_tree().paused and d.onboard.menu != null and is_instance_valid(d.onboard.menu), "Esc 멈춤 메뉴(설정)")
	if shots: _grab("menu")
	d.onboard.menu.close()
	await d.get_tree().process_frame
	T.expect(not d.get_tree().paused, "메뉴를 닫으면 다시 움직인다")
	Engine.time_scale = 1.0
	if T._fails.is_empty(): printerr("ONBOARDTEST PASS time=%.0fs" % ((Time.get_ticks_msec() - T._t0) / 1000.0))
	else: printerr("ONBOARDTEST FAIL fails=%s" % JSON.stringify(T._fails))
	d.main._quit()

# ---- 고르기: want 앞에서부터 보이는 글 하나 ----
func _choose(prompt: String, labels: Array) -> int:
	choice_log.append([prompt, labels.duplicate(), d.S.is_flag("igyeom_link")])
	for wi in want.size():
		var i := labels.find(want[wi])
		if i >= 0:
			want.remove_at(wi)
			return i
	return T.choose(prompt, labels)

func _data_has(line: String) -> bool:
	return JSON.stringify(load("res://story/namwon/namwon_data.gd").jumo_questions()).contains(line)

# 키 누르기(입력 이벤트 — 실제로 누른 것과 같은 길)
func _key(kc: int) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = kc
		ev.keycode = kc
		ev.pressed = down
		Input.parse_input_event(ev)
		await T._frames(2)

# 동작(이동·달리기)을 누른 채 cond가 참이 되거나 sec(실제 초)가 지날 때까지
func _hold(acts: Array, cond: Callable, sec: float) -> void:
	for a in acts: Input.action_press(a)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		await T._frames(1)
		if cond.call(): break
	for a in acts: Input.action_release(a)
	await T._frames(2)

# 게임 시간 sec초(시간 배율 반영) 동안 프레임을 돌린다
func _secs(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await d.get_tree().process_frame
		t += d.get_process_delta_time()

# 대화가 끝날 때까지 대화 카메라 거리를 모은다
func _watch_talk_cam() -> void:
	for i in 20000:
		var o = d.main.rig.override
		if o != null and o.has("distance") and not d.talk_cam.is_empty():
			var x := float(o.distance)
			if not cam_dists.any(func(y): return absf(y - x) < 0.01): cam_dists.append(x)
		if not d.runner.busy and i > 4: break
		await T._frames(1)

func _watch_neighbor() -> void:
	for i in 4000:
		await T._frames(1)
		if d.actors.has("neighbor_visit") and d.actors.neighbor_visit.shown and d.S.is_flag("neighbor_visit_on"):
			neighbor_seen_on = true; return

func _queued(k: String) -> bool:
	if d.onboard.hint_key() == k: return true
	for q in d.onboard._queue:
		if q[0] == k: return true
	return false

func _page_text(jd: Dictionary, i: int) -> String:
	var pg: Dictionary = jd.pages[i]
	return d.ui._page_text(pg)

static func _has_counter(t: String) -> bool:
	var re := RegEx.new(); re.compile("\\d+\\s*/\\s*\\d+")
	return re.search(t) != null

func _shot(nm: String, frames := 12) -> void:
	if not shots: return
	await T.shot(nm, frames)

# 여는 장면 찍기(검은 화면 글 · 기록책 한 장)
func _watch_prologue() -> void:
	var got := {}
	for i in 4000:
		await d.get_tree().process_frame
		if not got.has("line") and d.ui._center.modulate.a > 0.95:
			got.line = true; _grab("prologue_line")
		if not got.has("book") and d.ui._book.visible and d.ui._fade.color.a < 0.05:
			got.book = true; _grab("prologue_book"); return

func _watch_title() -> void:
	var got := {}
	for i in 4000:
		await d.get_tree().process_frame
		if not got.has("vista") and d._cut and i > 40:
			got.vista = true; _grab("vista")
		if not got.has("title") and d.ui._title_l.text == "설화록" and d.ui._title_l.modulate.a > 0.95:
			got.title = true; _grab("title_seolhwa"); return

# 대화·선택 화면 찍기: 말하는 사람마다 한 장, 선택지가 넷 이상이면 한 장(이야기가 끝나면 그만)
const WHO := { "주모": "jumo", "마부": "mabu", "이웃 아낙": "neighbor", "누이": "nui", "아우": "au", "포수": "hunter", "방앗간 주인": "miller" }
func _watch_dialog() -> void:
	var got := {}
	var started := false
	for i in 20000:
		await d.get_tree().process_frame
		if d.runner.busy: started = true
		elif started: return
		if d.ui._choice.visible and d.ui._choice_btns.size() >= 4:
			var key := "choice_" + String(d.ui._choice_btns[0].text)
			if not got.has(key):
				got[key] = true; await _settle(); _grab("choices_%s_%d" % [_who_now(), got.size()])
		elif d.ui._dialog.visible and d.ui._dlg_text.visible_ratio >= 0.99:
			var who := String(d.ui._dlg_name.text)
			if WHO.has(who) and not got.has(who):
				got[who] = true; await _settle(); _grab("talk_" + String(WHO[who]))

func _who_now() -> String:
	if d.S.is_flag("mill_talked"): return "miller"
	if d.S.is_flag("hunter_met"): return "hunter"
	if d.S.is_flag("met_kids"): return "kids"
	if d.S.is_flag("station_tut_seen"): return "mabu"
	return "jumo"

func _watch_hint(word: String, nm: String) -> void:
	for i in 6000:
		await d.get_tree().process_frame
		if d.ui.hint_text().contains(word) and d.ui._hint.modulate.a > 0.95 and not d.ui.modal:
			_grab(nm); return

func _settle() -> void:
	for i in 3: await d.get_tree().process_frame

func _grab(nm: String) -> void:
	var dir: String = d.main._abs(String(d.main.args.storyshots))
	DirAccess.make_dir_recursive_absolute(dir)
	d.get_viewport().get_texture().get_image().save_png(dir.path_join("onboard_%s.png" % nm))
	T._log("SHOT " + nm)

# §73 필수 단서 안전장치 — 핵심 정보마다 닿는 길(데이터에서 센다)
func _paths(kind: String) -> int:
	var D = load("res://story/namwon/namwon_data.gd")
	var jq := JSON.stringify(D.jumo_questions())
	var kq := JSON.stringify(D.kids_questions())
	var places: Array = d.data.map_places
	var has_place := func(id): return places.any(func(p): return String(p.id) == id and float(p.get("radius", 0.0)) > 0.0)
	var trig := func(id): return d.data.triggers.any(func(t): return String(t.id) == id)
	var n := 0
	match kind:
		"trail":   # 주모에게 들음 · 아이들에게 들음 · 직접(지도에 가 본 곳)
			if jq.contains("\"discover\":\"north_pass\""): n += 1
			if kq.contains("\"discover\":\"north_pass\""): n += 1
			if has_place.call("north_pass"): n += 1
		"house":   # 주모(서낭당 지나 집 한 채) · 흔적(흰 발자국) · 직접
			if jq.contains("집 한 채"): n += 1
			if trig.call("white_trail") and d.case_fn.has_method("white_trail"): n += 1
			if has_place.call("house"): n += 1
		"mimic":   # 아이의 목소리 증언 · 밀가루 발자국(연결 추론) · 밤 실제 목격
			if kq.contains("\"clue\":\"voice_at_night\""): n += 1
			if d.case_fn.has_method("check_link") and (JSON.stringify(d.data.objects).contains("see_flour") or JSON.stringify(d.data.actors).contains("mill_floor")): n += 1
			if (d.case_fn.get_script() as GDScript).source_code.contains("id == \"door_tricks\" and not S.knows(\"K_MIMIC\")"): n += 1
	return n

# 연출 카메라(override)를 이야기가 끝날 때까지 모은다
func _watch_cam() -> void:
	var started := false
	for i in 20000:
		await d.get_tree().process_frame
		var o = d.main.rig.override
		if o != null:
			var c: Dictionary = o.duplicate()
			if not cam_seen.any(func(x): return x == c): cam_seen.append(c)
		if d.runner.busy: started = true
		elif started: return

# 첫 조우 싸움: 안내 차례·끝난 순간의 실제 회피·막기 수·싸움 길이(+ 화면이 있으면 K·L 안내 찍기)
func _watch_combat() -> void:
	combat_hints.clear(); seen_with.clear(); fight_t = 0.0; fight_win = false
	var cv = d.combat_view
	for i in 40000:
		await d.get_tree().process_frame
		if cv.active: break
	if not cv.active: return
	var dodge0: bool = d.onboard.is_seen("COMBAT_DODGE")
	var guard0: bool = d.onboard.is_seen("COMBAT_GUARD")
	var grabbed := {}
	while cv.active:
		var b = cv.battle
		fight_t = b.time
		fight_win = fight_win or b.outcome == "win"
		var k: String = d.onboard.hint_key()
		if k.begins_with("COMBAT_") and (combat_hints.is_empty() or combat_hints[-1] != k): combat_hints.append(k)
		if not dodge0 and d.onboard.is_seen("COMBAT_DODGE"): dodge0 = true; seen_with["COMBAT_DODGE"] = int(b.player.dodges_ok)
		if not guard0 and d.onboard.is_seen("COMBAT_GUARD"): guard0 = true; seen_with["COMBAT_GUARD"] = int(b.player.blocks_ok)
		if shots and k.begins_with("COMBAT_") and not grabbed.has(k) and d.ui._hint.modulate.a > 0.95:
			grabbed[k] = true
			_grab("combat_" + ("K" if k == "COMBAT_DODGE" else "L"))
		await d.get_tree().process_frame

# ACT 3 화면(찍을 때만): 떡 카드 · 치맛자락 인서트 · 광주리(CAMERA 3A)는 자막이 다 떴을 때
func _watch_act3() -> void:
	var got := {}
	for i in 200000:
		await d.get_tree().process_frame
		if d.S.is_flag("past_scene_seen") and got.has("basket"): return
		if d.ui._card.visible and String(d.ui._card_title.text) == "떨어진 떡":
			var nm := "cake_%d" % d.case_fn.cakes_found()
			if not got.has(nm):
				got[nm] = true; await _settle(); _grab(nm)
		var cap := String(d.ui._caption.text)
		if d.ui._caption.modulate.a > 0.95:
			if cap == "네 줄로 길게 찢어져 있다." and not got.has("skirt"):
				got.skirt = true; _grab("skirt_insert")
			elif cap == "떡은 없다." and not got.has("basket"):
				got.basket = true; _grab("basket_3a")
			elif cap == "짚신 자국은 끊기고, 큰 발자국만 이어진다." and not got.has("tracks"):
				got.tracks = true; _grab("tracks_end")
			elif cap == d.case_fn.PAST_VOICE and not got.has("voice%d" % d.case_fn.past_voices):
				got["voice%d" % d.case_fn.past_voices] = true; _grab("past_voice_%d" % d.case_fn.past_voices)

