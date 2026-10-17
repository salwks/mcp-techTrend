# 시작 메뉴에서 이어 하기 / 새 게임 → 말 걸기 시험(region_main --continuetest=continue|new — tools/run_story_tests.sh continue:*). 헤드리스로 돈다.
#   그냥 실행과 같은 길: 시작 메뉴가 떠 있는지 본 뒤 메뉴를 고른다(project.godot 첫 장면이 region.tscn이 아니면 알림 줄).
#   --continuefixture=<저장 json>  이야기를 세우기 전에 시험 저장 파일(--savefile)에 통째로 깐다(옛 저장 그대로 이어 하기).
#   메뉴를 닫고 이야기가 한가해지면(새 게임은 여는 장면 S0001을 자동으로 넘긴 뒤):
#     1 이야기 인물 곁 — E 대상이 그 인물이고, E 키(입력 이벤트)로 말이 열린다(S.talked가 는다).
#     2 고을 사람 곁 — E 대상이 고을 사람이고, E 키로 말 걸기가 된다(ambient.last가 바뀐다).
#   --continueexpect=rollback  (남원 결정 6) 옛 밤 절정 도중 저장 — 저녁 준비 바로 앞으로 되돌렸나(단서·아이템 그대로, 밤 임시 플래그 없음)
#     → 해 질 무렵 귀환(경고·포수·준비)이 다시 돌고 준비 상태(dusk_prep)가 되는지 본 뒤 1·2를 한다.
#   --continueexpect=rollback_rope  (남원 v3.2) 새 흐름의 동아줄 도중 저장(test_rope_save.json) — 결말 변수 전이라 같은 안전지점(21시 숨은 자리)으로
#   --continueexpect=morning  (남원 v3.2) 옛 v3 아침(북쪽 어귀 한 장면) 도중 저장(test_morning_save.json) — 새 아침(외딴집 마당·이웃 아낙)부터 다시
#   --continueexpect=v1_done  (남원 참기름 감사) 옛 v1 끝난 저장(결말 B · 세부 B_win — 플레이어가 나무에 기름을 바르던 때) — 결말 B 그대로, 빈 결말 문단 없음, 해결법 B는 고른 방법으로
#   --continueexpect=chunhyang_p2b  (춘향 II-B 플레이 시험 저장 play_chunhyang3) II-A 끝(옥의 첫 밤 뒤) — 관아 앞으로 걸어가면 이튿날 아침 아전이 일 셋을 맡긴다
#   통과하면 "CONTTEST PASS", 아니면 "CONTTEST FAIL <까닭>".
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")
const GameSettings := preload("res://scripts/story/game_settings.gd")
const GAME_SCENE := "res://scenes/region.tscn"

var main
var d
var _fails: Array = []

func _init(m) -> void:
	main = m

# 이야기보다 먼저(region_main._ready): 시험 저장을 깐다
static func apply_fixture(args: Dictionary) -> void:
	if not args.has("continuefixture"): return
	if args.has("savefile"): Progress.use_path(String(args.savefile))
	var j = JSON.parse_string(FileAccess.get_file_as_string(String(args.continuefixture)))
	if not (j is Dictionary):
		print("CONTTEST fixture 읽기 실패 ", args.continuefixture); return
	var dd := Progress.data()
	dd.clear()
	dd.merge(j, true)
	Progress.save()
	print("CONTTEST fixture %s where=%s" % [args.continuefixture, JSON.stringify(dd.get("where", {}))])

func _fail(why: String) -> void:
	_fails.append(why)
	print("CONTTEST check FAIL ", why)

func _ok(cond: bool, why: String) -> void:
	if cond: print("CONTTEST check ok ", why)
	else: _fail(why)

func _wait_until(f: Callable, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		if f.call(): return true
		await main._wait_frames(1)
	return f.call()

func _press_e() -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		ev.keycode = KEY_E
		ev.pressed = down
		Input.parse_input_event(ev)
		await main._wait_frames(2)

func run(spec: String) -> void:
	GameSettings.test_override = { guide = "early", help = "normal" }
	# 그냥 실행(godot --path .)이 여는 장면 — 게임 장면이 아니면 시작 메뉴·이야기 없이 걷기만 된다(알림만, 판정에는 넣지 않는다)
	var ms := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	if ms != GAME_SCENE: print("CONTTEST note 첫 장면이 %s — 게임은 godot --path . %s 로 연다" % [ms, GAME_SCENE])
	await main._wait_frames(10)
	await _wait_until(func(): return not main._loading, 120.0)
	d = main.story
	if d == null or d.S == null:
		_finish("이야기 없음"); return
	await _wait_until(func(): return d.title != null and d.title.active, 10.0)
	_ok(d.title != null and d.title.active, "시작 메뉴가 떠 있음")
	if d.title == null or not d.title.active:
		_finish(""); return
	var wp = d.title.get("_wp")
	_ok(wp != null and wp.get_child_count() >= 9 + 3, "시작 메뉴 움직이는 바탕(겹·학·꽃잎) %s" % [wp.get_child_count() if wp != null else -1])
	var wp_ref: WeakRef = weakref(wp) if wp != null else null
	# 재기획 3단계 첫 15분 흐름(story/main_p1/main_p1_first15_test.gd): 새 게임부터 지도 목적지까지 한 번에
	if spec == "first15":
		var ft = load("res://story/main_p1/main_p1_first15_test.gd").new(self, main)
		await ft.run()
		_finish(""); return
	d.ui.auto = true
	print("CONTTEST pick %s phase=%s seen=%s" % [spec, d.S.phase, d.S.seen.keys()])
	d.title._pick(0 if spec == "new" else 1)
	# 메뉴가 닫히고, 이야기가 시작되고(새 게임은 여는 장면), 조작이 풀릴 때까지
	await _wait_until(func(): return d.title == null or not is_instance_valid(d.title) or not d.title.active, 10.0)
	await main._wait_frames(30)
	if spec == "new" and wp_ref != null: _ok(await _wait_until(func(): return wp_ref.get_ref() == null, 5.0), "메뉴가 닫히면 움직이는 바탕도 풀림")
	var idle := func(): return d._started and not d.blocks_move() and not d.runner.busy and not d.combat_view.active
	_ok(await _wait_until(idle, 120.0), "이야기 한가함 started=%s busy=%s modal=%s cut=%s" % [d._started, d.runner.busy, d.ui.modal, d._cut])
	_ok(d.S.phase != "start", "phase=" + String(d.S.phase))
	print("CONTTEST state phase=%s seen=%s talked=%s" % [d.S.phase, d.S.seen.keys(), d.S.talked])
	match String(main.args.get("continueexpect", "")):
		"join": await _join()
		"chunhyang": await _chunhyang_entry()
		"yield": await _yield()
		"main_resume": await _main_resume()
		"main_migrate": await _main_migrate()
		"main_nomove": await _main_nomove()
		"sonagi_mid": await _sonagi_mid()
		"main_oldcmp": await _main_oldcmp()
		"main_oldjumak": await _main_oldjumak()
		"chunhyang_mid": await _chunhyang_mid()
		"rollback": await _rollback()
		"rollback_rope": await _rollback_rope()
		"morning": await _morning()
		"v1_done": await _v1_done()
		"chunhyang_p2b": await _chunhyang_p2b()
	await _story_actor()
	# 21시 외딴집(새 밤 안전지점)에는 바깥에 다니는 고을 사람이 없다 — 그 경우만 고을 사람 말 걸기를 건너뛴다
	if String(main.args.get("continueexpect", "")) != "rollback_rope": await _ambient()
	_finish("")

# 1 이야기 인물: 말할 거리가 있는 인물(가까운 순) 곁으로 가서 E — 140m 밖 인물은 안 그리므로 보임은 따지지 않는다
func _story_actor() -> void:
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var tgt = null; var bd := INF
	# 인물이 제자리에 섰나 — 자리 이름이 인물 id와 같으면 (0,0)에 서던 일(주모·손님·포수·방앗간 주인)
	var stray: Array = []
	for id in d.actors:
		var a: Dictionary = d.actors[id]
		if a.shown and Vector2(a.pos.x, a.pos.z).length() < 1.0: stray.append(id)
	_ok(stray.is_empty(), "인물이 제자리(세상 한가운데에 선 인물 %s)" % [stray])
	for id in d.actors:
		var a: Dictionary = d.actors[id]
		if not a.shown or a.spec.get("talk") == null: continue
		if not a.spec.talk.any(func(t): return d.runner.cond(t.get("when", true))): continue
		var ap := Vector2(a.pos.x, a.pos.z)
		if ap.distance_to(pp) < bd: bd = ap.distance_to(pp); tgt = { id = String(id), p = ap, label = String(a.name) }
	if tgt == null:
		_fail("말 걸 이야기 인물이 없음"); return
	var id := String(tgt.id)
	var p: Vector2 = tgt.p + Vector2(0.8, 0.0)
	main.teleport(p.x, p.y)
	var near := func(): return d._target != null and String(d._target.get("id", "")) == id
	_ok(await _wait_until(near, 3.0), "E 대상 = 이야기 인물 %s (안내 '%s')" % [id, String(tgt.label)])
	var n0 := int(d.S.talked.get(id, 0))
	var opened := func(): return int(d.S.talked.get(id, 0)) > n0
	# E를 누르는 순간 지나가던 고을 사람이 더 가까우면 E가 그쪽으로 간다(새 게임 직후 장터 — 예전부터 가끔 실패하던 까닭).
	# 그러면 그 말을 닫고 다시 이야기 인물 곁에 서서 누른다(최대 3번). 무엇이 E를 받았는지 남긴다
	var got := false
	for attempt in 3:
		await _wait_until(near, 3.0)
		await _press_e()
		if await _wait_until(opened, 3.0): got = true; break
		var tg = d._target
		print("CONTTEST retry %d E 대상=%s busy=%s modal=%s" % [attempt + 1, "없음" if tg == null else "%s:%s" % [tg.kind, tg.get("id", tg.get("key", ""))], d.runner.busy, d.ui.modal])
		await _wait_until(func(): return not d.runner.busy and not d.ui.modal, 30.0)
		main.teleport(p.x, p.y)
	_ok(got, "E로 %s와 말이 열림" % id)
	await _wait_until(func(): return not d.runner.busy and not d.ui.modal, 60.0)

# 남원 결정 6 — 옛 밤 절정 도중 저장(fixture story/namwon/test_climax_save.json)을 저녁 준비 바로 앞으로 되돌린다
func _rollback() -> void:
	var fx = JSON.parse_string(FileAccess.get_file_as_string(String(main.args.get("continuefixture", ""))))
	var old: Dictionary = fx.cases.namwon if fx is Dictionary else {}
	var S = d.S
	_ok(String(d.case_fn.get("rollback")) == "old_night", "옛 밤 저장을 알아봄(rollback=%s)" % d.case_fn.get("rollback"))
	_ok(S.phase != "night" and S.phase != "done", "밤에서 빠져나옴(phase=%s)" % S.phase)
	for k in ["climax_started", "kids_in_tree", "pending_outcome", "pending_detail", "yard_losses", "beat_tiger_disguise", "beat_door_tricks", "beat_kids_escape_tree"]:
		_ok(not S.flags.has(k), "밤 임시 플래그 지움 " + k)
	for k in ["white_paw", "kids_in_tree"]: _ok(not S.world.has(k), "밤 지역 상태 지움 " + k)
	_ok(String(S.flags.get("beats", "")) == "mother_harmed", "원작 장면 기록은 밤 앞까지만(%s)" % S.flags.get("beats", ""))
	var miss: Array = old.get("clues", []).filter(func(c): return not S.clues.has(c))
	_ok(miss.is_empty(), "단서 그대로(%d개, 빠진 것 %s)" % [S.clues.size(), miss])
	var items_ok := true
	for k in old.get("items", {}): if int(S.items.get(k, 0)) != int(old.items[k]): items_ok = false
	_ok(items_ok, "아이템 그대로 %s" % JSON.stringify(S.items))
	_ok(bool(S.world.get("oil_on_step", false)), "준비해 둔 디딤돌 기름은 그대로")
	_ok(d.case_fn.prep_count() == 1 and d.case_fn.prep_room() and d.case_fn.pick_branch() == "B", "옛 디딤돌 기름 = 문 앞 장애물 하나(준비 %d/2 · 갈래 %s)" % [d.case_fn.prep_count(), d.case_fn.pick_branch()])
	_ok(not S.seen.has("S0007"), "S0007(밤의 문)을 다시 본다")
	# 저녁 준비 바로 앞 — 마당에서 해 질 무렵 귀환이 다시 돈다(경고·포수·준비)
	var ready := func(): return S.is_flag("dusk_prep") and not d.runner.busy
	_ok(await _wait_until(ready, 90.0), "해 질 무렵 귀환이 다시 돌고 준비 시간(dusk_prep)")
	_ok(S.is_flag("kids_warned") and S.is_flag("hunter_watch") and S.phase == "explore", "경고·포수 역할(hunter_watch) · 준비 중(explore)")
	_ok(main.hour >= 18.4 and main.hour <= 22.6, "해 질 무렵 %.2f시" % main.hour)
	_ok(d.actors.nui.shown and d.actors.au.shown, "오누이가 집에 있다")
	_ok(d._targets().any(func(t): return String(t.id) == "night_wait") or Vector2(main.player_pos.x, main.player_pos.z).distance_to(d.anchor("hide_spot")) > 2.6, "숨은 자리 “기다린다”가 열려 있다")
	print("CONTTEST rollback flags=%d clues=%d hour=%.2f" % [S.flags.size(), S.clues.size(), main.hour])

# 남원 v3.2 — 새 흐름의 동아줄 도중 저장(결말 변수 전): 같은 안전지점(준비 중 21시 · 숨은 자리)으로. 동아줄·기도 플래그는 지운다
func _rollback_rope() -> void:
	var S = d.S
	_ok(String(d.case_fn.get("rollback")) == "night", "새 밤 저장을 알아봄(rollback=%s)" % d.case_fn.get("rollback"))
	_ok(S.phase == "explore", "밤에서 빠져나옴(phase=%s)" % S.phase)
	for k in ["act10_started", "prayer_1", "prayer_2", "rope_hint", "rope_reached", "kids_on_rope", "rope_rise_done", "pending_outcome", "night_wait_started", "last_stand_done", "beat_kids_prayer", "beat_new_rope_rise"]:
		_ok(not S.flags.has(k), "동아줄·밤 플래그 지움 " + k)
	_ok(String(S.flags.get("beats", "")) == "mother_harmed", "원작 장면 기록은 밤 앞까지만(%s)" % S.flags.get("beats", ""))
	_ok(S.is_flag("dusk_prep") and S.is_flag("kids_warned") and bool(S.world.get("oil_on_step", false)), "준비 상태(dusk_prep·경고·디딤돌 기름)는 그대로")
	_ok(d.case_fn.prep_count() == 1 and d.case_fn.prep_room() and d.case_fn.pick_branch() == "B", "옛 디딤돌 기름 = 문 앞 장애물 하나(준비 %d/2 · 갈래 %s)" % [d.case_fn.prep_count(), d.case_fn.pick_branch()])
	_ok(not S.seen.has("S0007") and not S.seen.has("S0009"), "S0007·S0009를 다시 본다")
	_ok(String(S.vars.get("CASE_NAMWON_OUTCOME", "")) == "" and not S.world.has("sorghum_red"), "결말 변수·붉은 수수밭 없음")
	_ok(main.hour >= 20.5 and main.hour <= 22.6, "준비 중 %.2f시" % main.hour)
	_ok(Vector2(main.player_pos.x, main.player_pos.z).distance_to(d.anchor("hide_spot")) < 3.0 and d._targets().any(func(t): return String(t.id) == "night_wait"), "숨은 자리 “기다린다”가 열려 있다")
	print("CONTTEST rollback_rope flags=%d clues=%d hour=%.2f" % [S.flags.size(), S.clues.size(), main.hour])

# 남원 v3.2 — 옛 v3 아침 저장: 새 아침(외딴집 마당 · 이웃 아낙 세 갈래)부터. 결말 변수(B)는 그대로
func _morning() -> void:
	var S = d.S
	var ok := func(): return S.is_flag("morning_truth_choice") and not d.runner.busy and not d.ui.modal
	_ok(await _wait_until(ok, 90.0), "새 아침 — 이웃 아낙 물음까지 돈다")
	_ok(String(d.case_fn.get("rollback")) == "old_morning", "옛 아침 저장을 알아봄(rollback=%s)" % d.case_fn.get("rollback"))
	_ok(S.phase == "morning" and S.seen.has("S0010") and S.is_flag("morning_yard_seen"), "S0010 외딴집 마당 아침(phase=%s)" % S.phase)
	_ok(String(S.vars.get("CASE_NAMWON_OUTCOME", "")) == "B" and String(S.vars.get("CASE_NAMWON_MORNING", "")) != "", "결말 B 그대로 · 아침 대답 %s" % S.vars.get("CASE_NAMWON_MORNING", ""))
	_ok(d.case_fn.solutions().any(func(s): return String(s.id) == "B" and s.available), "끝낸 B 저장 — 해결법 B가 고른 방법으로 보인다")
	_ok(d.case_fn.outcome_text(String(S.vars.get("CASE_NAMWON_DETAIL", ""))) == String(d.case_fn.OUTCOME_TEXT.B_hold) and d.case_fn.summary().has(String(d.case_fn.OUTCOME_TEXT.B_hold)), "B 결말 문장 그대로(기록)")
	_ok(Vector2(main.player_pos.x, main.player_pos.z).distance_to(d.anchor("yard")) < 12.0, "외딴집 마당에서 아침(순간이동으로 어귀에 가 있지 않다)")
	_ok(S.is_flag("kids_gone") and not d.actors.nui.shown and bool(S.world.get("sorghum_red", false)) and bool(S.world.get("fall_traces", false)), "아이들 없음 · 붉은 수수밭 · 흔적")
	_ok(not S.is_flag("elder_book") and not S.seen.has("S0011"), "노인·마지막 밤은 아직(걸어 내려가야)")
	print("CONTTEST morning choice=%s hour=%.2f" % [S.vars.get("CASE_NAMWON_MORNING", ""), main.hour])

# 재기획 3단계(추가 지시 2): 오누이를 끝낸 옛 저장 — 메인 서장에 합류(여는 장면 없이 JOIN), 오누이 결과·춘향 진입 변수는 그대로
func _join() -> void:
	_ok(d.case_id == "main_p1" and d.S.is_flag("JOINED") and d.S.is_flag("OP00_DONE"), "끝난 오누이 저장 → 메인 서장 합류(case=%s JOINED=%s)" % [d.case_id, d.S.is_flag("JOINED")])
	_ok(not d.S.is_flag("START_AT_IEGYEOM_HOME"), "합류는 거처로 옮기지 않는다(여는 장면 없음)")
	_ok(bool(Progress.get_var("CASE_NAMWON_COMPLETE", false)) and String(Progress.case_state("namwon").get("phase", "")) == "done", "오누이 완료·진행 그대로")
	_ok(d.actors.has("peddler") and d.actors.has("solip_jumo"), "메인 서장 인물이 선다(행상·솔잎 주모)")
	print("CONTTEST join case=%s phase=%s" % [d.case_id, d.S.phase])

# 재기획 3단계(D3·추가 지시 3): 한양 책방까지 끝낸 옛 저장 — 남원에 오면 춘향(오누이 완료 요구 없이도 그대로 선다)
func _chunhyang_entry() -> void:
	_ok(d.case_id == "namwon_chunhyang", "한양 뒤 옛 저장 → 춘향 사건(case=%s)" % d.case_id)
	var CR = load("res://scripts/story/case_registry.gd")
	var cands: Array = CR.cases_for("JL_NAMWON_UNBONG")
	var v := Progress.vars().duplicate(); v["CASE_NAMWON_COMPLETE"] = false
	_ok(String(CR.choose(cands, v).id) == "namwon_chunhyang", "오누이 완료가 없어도 춘향 진입(D3)")
	print("CONTTEST chunhyang case=%s phase=%s" % [d.case_id, d.S.phase])

# 재기획 3단계(추가 지시 2): 오누이가 이 자리에서 끝났다(--case=namwon로 끝난 저장을 세움) — 한가해지면 메인 서장으로 합류
func _yield() -> void:
	main.args.erase("case")
	var t0 := Time.get_ticks_msec()
	var ok := await _wait_until(func(): return d.case_id == "main_p1" and d._started and not d.runner.busy, 20.0)
	_ok(ok, "끝난 오누이 → %.1f초 뒤 메인 서장 합류(case=%s)" % [(Time.get_ticks_msec() - t0) / 1000.0, d.case_id])
	_ok(d.S.is_flag("JOINED"), "합류(JOINED)")

# 재기획 3단계 저장 재개: 메인 서장 도중 저장(test_main_letter_save.json — 편지를 읽은 뒤) 이어 하기
func _main_resume() -> void:
	_ok(d.case_id == "main_p1" and d.S.is_flag("LETTER_RECEIVED") and not d.S.is_flag("LETTER_SUSPICIOUS"), "편지 뒤 저장 → 메인 서장 그 자리(case=%s)" % d.case_id)
	_ok(not d.S.seen.has("JOIN") and not d.S.is_flag("JOINED"), "새로 합류하지 않고 이어 함")
	_ok(d._targets().any(func(t): return String(t.id) == "o_desk"), "서안 견주기가 E 대상으로 남아 있음")

# 이겸 거처 이전(4~7단계): 옛 거처(객사 담 앞) 안에서 저장한 옛 저장(test_main_letter_save.json 원본 그대로 — 자리 -3251.9, 243.8) →
#   새 거처 안 같은 상대 자리로 · 지도 키 bld:이겸의 거처@ 옮김 · 사건 진행·기록·인물 그대로 · 프롤로그 없음
func _main_migrate() -> void:
	var c = d.case_fn
	var D = load("res://story/main_p1/main_p1_data.gd")
	await _wait_until(func(): return c.get("_migrate_to") == null, 5.0)
	await main._wait_frames(10)
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var want := Vector2(D.HX, D.HZ) + Vector2(-3251.9 - D.OLD_HX, 243.8 - D.OLD_HZ)
	_ok(c.migrated and d.S.is_flag("HOME_MOVED"), "옛 거처 안 저장 → 새 거처로 옮김(HOME_MOVED)")
	_ok(pp.distance_to(want) < 1.0, "새 거처 안 같은 상대 자리(%.1f, %.1f) — 바람 (%.1f, %.1f)" % [pp.x, pp.y, want.x, want.y])
	var rel := pp - Vector2(D.HX, D.HZ)
	_ok(absf(rel.x) <= 4.6 and rel.y >= -3.6 and rel.y <= 6.9, "옮긴 자리가 새 거처 집·앞마당 안(상대 %.1f, %.1f — 옛 저장은 문턱 앞)" % [rel.x, rel.y])
	var kn: Dictionary = Progress.known("JL_NAMWON_UNBONG")
	_ok(not kn.has("bld:이겸의 거처@-3252,240") and String(kn.get("bld:이겸의 거처@%d,%d" % [roundi(D.HX), roundi(D.HZ)], "")) == "visited", "지도 키 옮김(옛 키 없음 · 새 키 visited)")
	_ok(d.case_id == "main_p1" and d.S.is_flag("LETTER_RECEIVED") and not d.S.is_flag("LETTER_SUSPICIOUS") and String(d.S.phase) == "home", "사건 진행 그대로(편지 뒤 · 국면 home)")
	_ok(["ledger", "shoes", "brush", "messenger", "letter"].all(func(k): return d.S.has_clue(k)) and d.S.has(D.LETTER), "기록(단서 다섯)·소지품 그대로")
	_ok(int(d.S.talked.get("messenger", 0)) == 2 and d.S.is_flag("KNOCKED"), "인물 상태 그대로(심부름꾼 대화 2·문 두드림)")
	_ok(not c.prologue_played and not d.S.is_flag("PROLOGUE_SEEN"), "옛 저장에 프롤로그 없음")
	_ok(d._targets().any(func(t): return String(t.id) == "o_desk"), "서안 견주기가 E 대상(새 거처)")
	print("CONTTEST main_migrate at=(%.1f,%.1f)" % [pp.x, pp.y])

# 여는 사건 A 「소나기」 시험(claude/opening-a-sonagi-trial 전용): 소나기에서 갈래를 정한 바로 그때의 저장(프롤로그 도중 — OP00_DONE 전) →
#   프롤로그를 다시 틀지 않고(옛 저장 규칙 그대로) 거처에서 이어 하며, 갈래·기록책 첫 줄·지금 마당의 갈래 소품이 남는다. 지난날 이겸·비·이동 허용이 남지 않는다
func _sonagi_mid() -> void:
	var c = d.case_fn
	var want := String(main.args.get("sonagiwant", ""))
	await _wait_until(func(): return c._sonagi_built, 6.0)
	_ok(d.case_id == "main_p1" and String(d.S.phase) == "home" and d.S.is_flag("OP00_DONE"), "프롤로그 도중 저장 → 거처 국면에서 이어 함(OP00_DONE은 불러올 때 섬)")
	_ok(not c.prologue_played and not d.actors.has("yigyeom_past"), "프롤로그를 다시 틀지 않음 · 지난날 이겸 없음")
	_ok(c.sonagi_saved() == want and c.summary().size() == 1, "소나기 갈래 그대로(%s) · 기록책 첫 줄 %s" % [c.sonagi_saved(), c.summary()])
	_ok(c._sonagi_built and c._sonagi_nodes.has("tucked") and c._sonagi_nodes.has("ring") == (want == "other"), "지금 마당에 갈래 소품이 다시 섬 %s" % [c._sonagi_nodes.keys()])
	var wx = main.weather
	_ok(not d.free_move and String(d.story_prompt) == "" and (wx == null or String(wx.kind) != "rain"), "비·이동 허용·줍기 안내가 남지 않음")
	_ok(["ledger", "shoes", "brush"].all(func(k): return not d.S.has_clue(k)) and not d.S.is_flag("KNOCKED"), "진행은 프롤로그 직후 그대로(방 조사 전)")
	print("CONTTEST sonagi_mid want=%s at=(%.1f,%.1f) hour=%.1f" % [want, main.player_pos.x, main.player_pos.z, main.hour])

# 옛 자리 가까이의 보통 저장(옛 거처 밖 길 위 · 또는 편지를 의심한 뒤 국면 town) — 옮기지 않는다
func _main_nomove() -> void:
	var c = d.case_fn
	await main._wait_frames(30)
	var wh: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(main.args.continuefixture))).get("where", {})
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	_ok(not c.migrated and not d.S.is_flag("HOME_MOVED"), "옮기지 않음(HOME_MOVED 없음)")
	_ok(pp.distance_to(Vector2(float(wh.x), float(wh.z))) < 1.5, "저장 자리 그대로(%.1f, %.1f)" % [pp.x, pp.y])
	_ok(not c.prologue_played, "옛 저장에 프롤로그 없음")
	print("CONTTEST main_nomove phase=%s at=(%.1f,%.1f)" % [d.S.phase, pp.x, pp.y])

# 편지 조사 개편(2026-10-17) 옛 저장: 견주기 도중(test_main_compare_old_save.json — 옛 짝 cmp_date + cmp_blame, 옛 짚은 자리 o_witness·l_blame) →
#   서안을 다시 열고 덮으면 옛 규칙(이미 시작한 견주기의 cmp_blame을 열쇠 짝으로 인정)으로 끝까지 — 새 짝 cmp_unknown 없이도 막히지 않는다
func _e_target(id: String, why: String) -> bool:
	var tp := Vector2.ZERO
	for t in d._targets():
		if String(t.id) == id: tp = t.p
	main.teleport(tp.x + 0.6, tp.y + 0.5)
	var near := func(): return d._target != null and String(d._target.get("id", "")) == id
	var ok := await _wait_until(near, 4.0)
	_ok(ok, "%s: E 대상 %s" % [why, id])
	await _wait_until(func(): return not d.ui.busy_input(), 2.0)
	await _press_e()
	return ok

func _main_oldcmp() -> void:
	var c = d.case_fn
	_ok(d.case_id == "main_p1" and d.S.is_flag("LETTER_RECEIVED") and not d.S.is_flag("LETTER_SUSPICIOUS") and d.S.has_clue("cmp_blame"), "옛 견주기 도중 저장(cmp_date + cmp_blame) 불러옴")
	_ok(c.compare_state() == 2 and c.compare_pairs() == 2, "옛 짝 둘 — 옛 규칙으로 끝낼 수 있음(state %d)" % c.compare_state())
	_ok(d.data.clues.has("cmp_blame") and d.data.clues.has("cmp_unknown"), "옛 단서 cmp_blame 정의가 남아 기록책에 보임")
	_ok(d._targets().any(func(t): return String(t.id) == "o_desk"), "서안 견주기가 E 대상")
	var ui_auto: bool = d.ui.auto
	await _e_target("o_desk", "옛 견주기 이어 하기")
	var ok := await _wait_until(func(): return d.S.is_flag("LETTER_SUSPICIOUS") and not d.runner.busy, 30.0)
	_ok(ok and d.S.is_flag("LETTER_COMPARE_2") and String(d.S.phase) == "town" and not d.S.has_clue("cmp_unknown"), "다시 열고 덮으면 끝까지(LETTER_SUSPICIOUS · 국면 town) — 새 짝 없이")
	print("CONTTEST main_oldcmp phase=%s auto=%s" % [d.S.phase, ui_auto])

# 편지 조사 개편 옛 저장: 주막 도중(test_main_jumak_old_save.json — 옛 판 주모 증언 tv_jumo만, TAVERN_CLUE 전) → 옛 단서가 지도 등록 셈에 든다:
#   짚신 손님 하나만 더 들으면 '여원재 방면'(둘)
func _main_oldjumak() -> void:
	var c = d.case_fn
	_ok(d.case_id == "main_p1" and d.S.has_clue("tv_jumo") and not d.S.is_flag("TAVERN_CLUE") and String(d.S.phase) == "town", "옛 주막 저장(tv_jumo · TAVERN_CLUE 전) 불러옴")
	_ok(c.tavern_sources() == 1, "옛 판 주모 증언 tv_jumo가 지도 등록 셈에 듦(1)")
	await _e_target("solip_guest2", "짚신 손님")
	var ok := await _wait_until(func(): return d.S.has_clue("tv_guest2") and d.S.is_flag("TAVERN_CLUE") and not d.runner.busy, 20.0)
	_ok(ok and c.tavern_sources() == 2, "옛 tv_jumo + 짚신 손님 = 둘 → 지도 '여원재 방면'(TAVERN_CLUE)")
	_ok(d.data.map_leads.any(func(l): return String(l.id) == "mp_yeowon" and d.runner.cond(l.when)), "지도 붉은 인 '여원재 방면'(목적지 후보) 조건이 섬")
	print("CONTTEST main_oldjumak sources=%d" % c.tavern_sources())

# 춘향 도중 옛 저장(test_chunhyang_mid_save.json — 한양 뒤 + 춘향 단오 진행 중) — 춘향을 그대로 이어 간다(메인 서장·프롤로그가 끼지 않는다)
func _chunhyang_mid() -> void:
	_ok(d.case_id == "namwon_chunhyang", "춘향 도중 저장 → 춘향 그대로(case=%s)" % d.case_id)
	_ok(d.S.is_flag("case_started") and String(d.S.phase) != "start", "춘향 진행 그대로(phase=%s)" % d.S.phase)
	var mst := Progress.case_state("main_p1")
	_ok(not bool((mst.get("flags", {}) as Dictionary).get("PROLOGUE_SEEN", false)), "메인 서장 프롤로그가 끼지 않음")

# 남원 참기름 감사 — 옛 v1 끝난 저장(test_v1_done_save.json: phase done · 결말 B · 세부 B_win). 값은 바꾸지 않고 문장만 B_hold로 읽는다
func _v1_done() -> void:
	# 재기획 3단계: 끝난 오누이 저장은 메인 서장에 합류한다 — 오누이 결말 글은 그 사건을 다시 세워(같은 자리) 본다
	_ok(d.case_id == "main_p1", "끝난 옛 v1 저장 → 메인 서장 합류(case=%s)" % d.case_id)
	_ok(d.switch_case("namwon", { "reload": true }), "오누이를 다시 세워 결말 글 보기")
	await _wait_until(func(): return d._started and not d.runner.busy, 10.0)
	var S = d.S
	var c = d.case_fn
	_ok(S.phase == "done" and String(S.vars.get("CASE_NAMWON_OUTCOME", "")) == "B" and String(S.vars.get("CASE_NAMWON_DETAIL", "")) == "B_win", "옛 v1 결말 B 그대로(phase=%s · %s · %s)" % [S.phase, S.vars.get("CASE_NAMWON_OUTCOME", ""), S.vars.get("CASE_NAMWON_DETAIL", "")])
	var ed: Dictionary = c.ending_data()
	_ok(String(ed.paragraphs[1]) == String(c.OUTCOME_TEXT.B_hold), "결말 화면 둘째 문단이 비지 않는다(B_win → B_hold)")
	_ok(c.summary().has(String(c.OUTCOME_TEXT.B_hold)) and not c.summary().has(""), "기록 요약에 빈 문단 없음")
	_ok(c.outcome_text("B_repel") == String(c.OUTCOME_TEXT.B_hold) and c.outcome_text("A_win") == String(c.OUTCOME_TEXT.A_hold) and c.outcome_text("A_repel") == String(c.OUTCOME_TEXT.A_hold), "옛 세부 값 넷 → *_hold 문장")
	_ok(c.solutions().any(func(s): return String(s.id) == "B" and s.available), "해결법 B가 고른 방법으로 보인다")
	var jd: Dictionary = c.journal()
	_ok(String(jd.cases[0].status) == "solved", "기록책 사건 — 풀림")
	print("CONTTEST v1_done outcome=%s detail=%s" % [S.vars.get("CASE_NAMWON_OUTCOME", ""), S.vars.get("CASE_NAMWON_DETAIL", "")])

# 춘향 II-B 플레이 시험 저장: II-A 끝(jail · p2a_done) — 관아 앞으로 가면 C1300(이튿날 아침 · 일 셋), 술 수레·박가네·노인이 선다
func _chunhyang_p2b() -> void:
	var S = d.S
	_ok(d.case_id == "namwon_chunhyang" and S.phase == "jail" and S.is_flag("p2a_done") and not S.is_flag("p2b_started"), "II-A 끝 · II-B 아직(phase=%s)" % S.phase)
	_ok(S.has("ITM_CH_TALLY") and S.is_flag("restraint_loose") and S.is_flag("labour_accepted"), "목패 · II-A 선택 그대로")
	var gp: Vector2 = d.anchor("ch_gwana_front")
	_ok(Vector2(main.player_pos.x, main.player_pos.z).distance_to(gp) > 20.0, "관아 앞에서 떨어진 자리에서 시작")
	await main._wait_frames(10)
	main.teleport(gp.x - 0.8, gp.y + 0.6)
	var go := func(): return S.is_flag("duty_on") and not d.runner.busy and not d.ui.modal
	_ok(await _wait_until(go, 90.0), "관아 앞 — 이튿날 아침 아전이 일 셋(C1300)")
	await main._wait_frames(10)
	_ok(d.actors.wine_merchant.shown and d.actors.rice_farmer.shown and d.actors.petition_elder.shown and d.actors.ajeon_b.shown, "술 상인·농민·노인·아전이 선다")
	_ok(d._targets().any(func(t): return String(t.id) == "pb_wine_cart") and d._targets().any(func(t): return String(t.id) == "pb_petition_route"), "조사 대상(술 수레·외삼문 곁 방)이 열려 있다")
	print("CONTTEST chunhyang_p2b hour=%.2f duty_on=%s" % [main.hour, S.is_flag("duty_on")])

# 2 고을 사람: 이야기 인물에서 떨어진 고을 사람 곁으로 가서 E
func _ambient() -> void:
	var npc = main.npcs_amb
	if npc == null:
		_fail("고을 사람 없음"); return
	var targets: Array = d._targets()
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var keys: Array = npc.agents.keys().filter(func(k):
		var ag: Dictionary = npc.agents[k]
		if ag.animal or String(ag.mode) == "gull": return false
		var ap := Vector2(ag.pos.x, ag.pos.z)
		return not targets.any(func(t): return ap.distance_to(t.p) < float(t.r) + 3.0))
	keys.sort_custom(func(a, b): return Vector2(npc.agents[a].pos.x, npc.agents[a].pos.z).distance_to(pp) < Vector2(npc.agents[b].pos.x, npc.agents[b].pos.z).distance_to(pp))
	var tried := 0
	for key in keys:
		if not npc.agents.has(key): continue
		var ag: Dictionary = npc.agents[key]
		tried += 1
		if tried > 12: break
		main.teleport(ag.pos.x + 0.9, ag.pos.z)
		var amb := func(): return d._target != null and String(d._target.kind) == "ambient" and not d.ui.busy_input() \
			and not d.runner.busy and not d.blocks_move()
		if not await _wait_until(amb, 2.0): continue
		var before: Dictionary = d.ambient.last.duplicate()
		var label := String(d._target.label)
		await _press_e()
		var talked := func(): return d.ambient.busy or d.ambient.last != before
		var ok: bool = await _wait_until(talked, 3.0)
		if not ok: print("CONTTEST state target=%s busy_input=%s runner=%s modal=%s amb_busy=%s" % [d._target, d.ui.busy_input(), d.runner.busy, d.ui.modal, d.ambient.busy])
		_ok(ok, "E로 고을 사람과 말 걸기(%s)" % label)
		await _wait_until(func(): return not d.ambient.busy, 20.0)
		return
	_fail("E 대상이 되는 고을 사람을 못 찾음(시도 %d)" % tried)

func _finish(why: String) -> void:
	if why != "": _fails.append(why)
	if _fails.is_empty(): print("CONTTEST PASS")
	else: print("CONTTEST FAIL ", "; ".join(_fails))
	main._quit()
