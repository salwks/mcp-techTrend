# 처음 하는 사람 안내 대본 시험 — --storytest=namwon:onboard (story_test.gd가 부른다, --headless 가능, --storyshots=폴더면 장면을 찍는다)
#   새 게임 → S0000(이겸의 세 문장·기록책 마지막 장·이동 안내·길가 짚신·기록책 안내·나그네 둘) → S0001(남원 전경·제목) →
#   S0002(주막·“그 책…”·사건 기록) → 지도에 아는 곳만 → 첫 단서 안내 단계 0→1→2→3(먹점·한 줄) → 첫 호랑이 조우(느린 화면·회피 안내·관찰 기록)
#   → 설정(상호작용 안내 끔이면 먹점 없음). 끝에 ONBOARDTEST PASS/FAIL.
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")
const Discovery := preload("res://scripts/region/discovery.gd")
const GameSettings := preload("res://scripts/story/game_settings.gd")

var T      # story_test
var d
var shots := false

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
	T._log("onboard 시작")
	# ---- S0000 ----
	if shots: d.ui.auto = false; _watch_prologue()
	await d.runner.run([{ "event": "S0000" }])
	d.ui.auto = true
	T.expect(d.S.is_flag("s0000_started") and d.S.is_flag("INTRO_MASTER_VOICE_DONE"), "S0000 이겸의 세 문장")
	T.expect(Vector2(d.main.player_pos.x, d.main.player_pos.z).distance_to(d.anchor("s0000_start")) < 2.0, "S0000 남원 밖 길에서 시작")
	for i in 120:
		await T._frames(1)
		if d.ui.hint_text().contains("이동"): break
	T.expect(d.ui.hint_text().contains("이동"), "이동 안내가 뜬다 (%s)" % d.ui.hint_text())
	var p0: Vector2 = d.anchor("s0000_start")
	d.teleport_to(Vector2(p0.x - 1.5, p0.y + 0.8), "left")
	await T._frames(40)
	T.expect(d.onboard.is_seen("MOVE") and not d.ui.hint_text().contains("이동"), "움직이면 이동 안내가 사라진다")
	# 처음 아는 곳: 남원 동문·큰길·주막(지도는 불러오기가 끝난 뒤 생긴다)
	for i in 120:
		await T._frames(1)
		if Discovery.is_known(d.space_id, "place:east_gate"): break
	await T._frames(30)
	var sp: String = d.space_id
	T.expect(Discovery.is_known(sp, "place:east_gate") and Discovery.is_known(sp, "place:main_road") and Discovery.is_known(sp, "place:tavern"), "지도 처음: 남원 동문·큰길·주막")
	T.expect(not Discovery.is_known(sp, "place:north_pass") and not Discovery.is_known(sp, "place:house") and not Discovery.is_known(sp, "place:clearing"), "지도 처음: 고갯길·외딴집·빈터는 없다")
	# 길가 짚신(첫 조사) → 기록책 안내
	await T.go("roadside")
	T.expect(d.S.is_flag("roadside_seen") and d.onboard.is_seen("INSPECT"), "길가 짚신 살펴보기")
	await T._frames(10)
	T.expect(d.ui.hint_text().contains("기록책"), "첫 조사 뒤 기록책 안내 (%s)" % d.ui.hint_text())
	var jd: Dictionary = d.journal_data()
	d.ui.journal_show(jd)
	var travel := _page_text(jd, 0)
	T.expect(travel.contains("찾는 사람 — 이겸") and travel.contains("마지막 확인 장소: 남원") and travel.contains("현재 행방: 모름"), "기록책 여행 기록(이겸·남원·모름)")
	T.expect(_page_text(jd, 1).contains("아직 기록된 사건 없음"), "기록책 사건 기록: 아직 없음")
	T.expect(d.onboard.is_seen("JOURNAL"), "기록책을 열면 안내가 끝난다")
	await _shot("journal_travel")
	d.ui.journal_close()
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
	# ---- S0002 주막 ----
	await T.walk_to("tavern")
	await T._frames(40)
	var tt = d.main.get("_title")
	if tt != null:
		var nn: int = tt.shown.count("남원")
		T.expect(nn <= 1, "「남원」은 전경에서 한 번만(성문·주막에서 다시 안 뜸) — %d번" % nn)
	await T.go("jumo")
	T.expect(d.S.is_flag("case_started"), "S0002 사건 기록 생성")
	for i in 200:
		await T._frames(1)
		if Discovery.how(sp, "place:north_pass") != "": break
	T.expect(Discovery.how(sp, "place:north_pass") == "told", "주모 말 → 북쪽 고갯길이 지도에(들음)")
	T.expect(d.onboard.is_seen("MAP") or d.ui.hint_text().contains("지도") or _queued("MAP"), "지도 안내(한 번)")
	jd = d.journal_data()
	var cs := _page_text(jd, 1)
	T.expect(cs.contains("「산길의 실종」") or cs.contains("산길의 실종"), "사건 기록: 산길의 실종")
	T.expect(cs.contains("◇ 들음 — 주모") and cs.contains("아직 모르는 것") and cs.contains("확인한 장소"), "사건 기록: 들음 — 주모 · 아직 모르는 것 · 확인한 장소")
	T.expect(not _has_counter(cs) and not _has_counter(_page_text(jd, 0)), "숫자 체크리스트 없음")
	d.ui.journal_show(load("res://scripts/story/journal_book.gd").build(d, 1))
	await _shot("journal_case")
	d.ui.journal_close()
	# 지도 — 아는 곳만
	if shots:
		d.teleport_to("tavern", "up"); await T._frames(30)
		d.main._map.toggle(); await _shot("map_known", 20)
		d.main._map.toggle()
	# ---- 첫 단서 안내 단계(§14) ----
	T.expect(int(d.S.flags.get("CASE_NAMWON_GUIDANCE_STAGE", 0)) == 0, "안내 단계 0")
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
	T.expect(_page_text(jd, 1).contains("일정한 간격"), "단서 글이 뜻으로 자란다(떡이 이어짐)")
	await T.go("torn_skirt")
	T.expect(int(d.S.flags.get("CASE_NAMWON_GUIDANCE_STAGE", 0)) == 3, "셋째 단서 → 단계 3(일반 조사)")
	# ---- 첫 호랑이 조우(§16·§17) — 봇은 처음 몸 낮춤을 볼 때까지 다가가지 않는다(처음 하는 사람처럼) ----
	T.bot_wait_first = true
	await T.go("blood")
	await T._frames(20); await T._idle()
	for id in ["cake_3", "tracks", "basket"]:
		if not d.S.is_flag("first_encounter") and not d.S.has_clue(id) and not d.S.is_flag(id): await T.go(id)
	if not d.S.is_flag("first_encounter"):
		await T.walk_to("first_seen"); await T._frames(30); await T._idle()
	T.bot_wait_first = false
	T.expect(d.S.is_flag("first_encounter"), "S0005 첫 조우")
	T.expect(d.onboard.is_seen("COMBAT_DODGE"), "첫 돌진에 느린 화면 + 회피 안내")
	T.expect(absf(Engine.time_scale - float(d.main.args.get("storyspeed", "2.5"))) < 0.01, "느린 화면이 풀렸다 (%.2f)" % Engine.time_scale)
	jd = d.journal_data()
	cs = _page_text(jd, 1)
	T.expect(cs.contains("몸을 낮춘 뒤 잠시 멈춘다.") and cs.contains("그다음 곧장 돌진한다."), "관찰 기록 두 줄")
	T.expect(not cs.contains("패턴") and not cs.contains("해금"), "시스템 용어 없음")
	# 오누이 집: 가 보면 지도에
	T.expect(not Discovery.is_known(sp, "place:house"), "외딴집은 아직 지도에 없다")
	await T.go("nui")
	for i in 240:
		await T._frames(1)
		if Discovery.how(sp, "place:house") == "visited": break
	T.expect(Discovery.how(sp, "place:house") == "visited", "가 본 외딴집이 지도에")
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

func _queued(k: String) -> bool:
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

func _grab(nm: String) -> void:
	var dir: String = d.main._abs(String(d.main.args.storyshots))
	DirAccess.make_dir_recursive_absolute(dir)
	d.get_viewport().get_texture().get_image().save_png(dir.path_join("onboard_%s.png" % nm))
	T._log("SHOT " + nm)
