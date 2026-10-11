# 오누이 서사형 튜토리얼 관찰·초급 판단(게임플레이 구조 1차 §4·§23) — story_test.gd가 부른다.
#   run(T)      --storytest=namwon:observe — 첫 조우 뒤 상태를 꾸며 놓고:
#               관찰이 기록된다(본 것 fact · 기록책 '현재까지 확인한 것') · 관찰 하나로는 묻지 않는다 · 관찰 둘 뒤 같은 자리에서 "어느 쪽 흔적을 먼저 확인할까?" ·
#               관찰 도중 저장/불러오기(마친 관찰 다시 안 섬 · 결정 아직) · 서쪽 숲(틀린 판단) → 결정 뒤 저장/불러오기(결정 유지·다시 안 물음) →
#               숲가 헛걸음 → 추가 흔적 → 같은 결과(흔적이 가는 쪽 — 추정 △)로 본 흐름 · 두 번 불러도 한 번만 · 선택 관찰 둘(털·울 밑) ·
#               FIXED_BEATS·국면·결말 변수 그대로 · 관찰 자리가 걸을 수 있는 땅(막힘 없음).   끝에 STORYTEST PASS/FAIL.
#               --storyshots=폴더(창 모드)면 관찰 카드 한 장과 판단 선택 한 장을 찍는다(oneonui_observe.png · oneonui_decide.png).
#   beast_way(T, wrong)  namwon:A(길 아래 — 바로 풀림) · namwon:B(서쪽 숲 — Fail Forward)가 첫 조우 뒤에 부른다. 끝까지 가서 FIXED_BEATS·결말 A/B는 원래 시험이 본다.
extends RefCounted

const Problems := preload("res://scripts/story/problems.gd")
const JournalBook := preload("res://scripts/story/journal_book.gd")

const PID := "beast_way"
const PROMPT := "어느 쪽 흔적을 먼저 확인할까?"
const OBS := ["mud_print", "bent_grass", "fur", "house_mixed"]

var T
var d
var prompts: Array = []
var shots := false

func _hook(t) -> void:
	T = t; d = t.d
	d.ui.auto_choice = func(p: String, labels: Array) -> int:
		prompts.append(p)
		return T.choose(p, labels)

func _o(aid: String) -> String: return "pb_%s_%s" % [PID, aid]

func _target_ids() -> Array:
	d._refresh()
	return d._targets().map(func(x): return String(x.id))

# ---- namwon:A/B 안에서(첫 조우 뒤) ----
func beast_way(t, wrong: bool) -> void:
	_hook(t)
	var beats0: Array = d.case_fn.beats_seen()
	var phase0: String = d.S.phase
	T.prefer = ["서쪽 숲가"] if wrong else ["길 아래쪽"]
	await T.go(_o("mud_print"))
	T.expect(d.S.has_clue(_o("mud_print")) and prompts.is_empty(), "§4 관찰 하나 — 기록 · 아직 묻지 않음")
	await T.go(_o("bent_grass"))
	T.prefer = []
	T.expect(prompts.count(PROMPT) == 1, "§4 관찰 둘 뒤 초급 판단 한 번")
	if wrong:
		T.expect(d.runner.pd(PID) == "forest" and not d.runner.pdone(PID), "§4 서쪽 숲(틀린 판단) — 막히지 않고 숲가가 열린다")
		await T.go(_o("ff_deer_path"))
		T.expect(d.S.has_clue("pb_%s_ff_deer_path" % PID), "§4 Fail Forward — 헛걸음 뒤 추가 흔적")
	else:
		T.expect(d.runner.pd(PID) == "down", "§4 길 아래쪽")
	T.expect(d.runner.pdone(PID) and d.S.is_flag("beast_way_read") and d.S.has_clue("trace_downhill"), "§4 결과: 흔적이 가는 쪽(추정) · beast_way_read")
	T.expect(d.case_fn.beats_seen() == beats0 and d.S.phase == phase0 and String(d.S.vars.get("CASE_NAMWON_OUTCOME", "")) == "", "§4 관찰·판단은 FIXED_BEATS·국면·결말을 건드리지 않는다")
	d.ui.auto_choice = T.choose

# ---- namwon:observe ----
func run(t) -> void:
	_hook(t)
	shots = d.main.args.has("storyshots") and DisplayServer.get_name() != "headless"
	var S = d.S
	# 첫 조우를 마치고 오누이를 만난 뒤(외딴집 첫 방문·이웃 아낙 끝) — 밤 준비 전
	S.phase = "explore"
	for k in ["s0000_started", "INTRO_MASTER_VOICE_DONE", "INTRO_NAMWON_TITLE_DONE", "s0001_done", "case_started", "igyeom_link", "heard_pass_road",
			"first_encounter", "beat_mother_harmed", "past_scene_seen", "met_kids", "neighbor_visit_seen", "station_tut_seen"]: S.flags[k] = true
	S.flags["beats"] = "mother_harmed"
	S.items = { "ITM_TOOL_009": 1, "ITM_WPN_001": 1, "ITM_WPN_002": 1, "ITM_AMMO_001": 12 }
	d.set_hour(13.0)
	d.mark_dirty()
	await T._frames(10)
	var beats0: Array = d.case_fn.beats_seen()
	# 계약: 데이터가 공통 검사를 통과하고, 관찰 넷·판단 하나·숲가 자리 하나가 조사 대상/트리거로 섰다
	_ex(Problems.validate(d.data).is_empty(), "계약 검사 통과 %s" % str(Problems.validate(d.data)))
	var oids: Array = d.data.objects.map(func(o): return String(o.id))
	_ex(OBS.all(func(a): return oids.has(_o(a))) and oids.has(_o("ff_deer_path")) and d.data.triggers.any(func(x): return String(x.id) == _o("which_way")),
		"관찰 넷 · 숲가 자리 · 판단 다시 묻기 트리거")
	# 관찰 자리는 걸을 수 있는 땅(나무·바위에 막히지 않음)
	for a in OBS + ["ff_deer_path"]:
		var at = T._obj_at(_o(a))
		var p: Vector2 = d.anchor(at)
		d.teleport_to(Vector2(p.x, p.y + 1.6), "up")
		await T._frames(6)
		_ex(not d.main.world.blocked(p.x, p.y, 0.3) and not d.main.world.blocked(p.x, p.y + 1.6, 0.3), "걸을 수 있는 자리 %s (%.1f, %.1f)" % [a, p.x, p.y])
	_ex(not _target_ids().has(_o("ff_deer_path")), "숲가 자리는 서쪽 숲을 고르기 전엔 없다")
	# ① 관찰 하나 — 본 것으로 기록
	if shots: _watch_card("진흙의 큰 자국", "oneonui_observe")
	await T.go(_o("mud_print"))
	if shots: await _wait_watch()
	var c1: Dictionary = d.data.clues.get(_o("mud_print"), {})
	_ex(S.has_clue(_o("mud_print")) and String(c1.get("kind", "")) == "fact", "관찰 단서 등록 — 본 것(fact)")
	var jd := JournalBook.section(d.journal_data(), "case")
	_ex(jd.blocks.any(func(b): return String(b.get("title", "")) == "진흙의 큰 자국" and String(b.get("tag", "")) == "fact"), "기록책 '현재까지 확인한 것'에 ◆본 것으로")
	_ex(not String(c1.get("text", "")).contains("호랑이") and not String(c1.get("text", "")).contains("범이"), "관찰 글은 정답이 아니다(범·호랑이라 쓰지 않는다)")
	_ex(prompts.is_empty() and d.runner.pd(PID) == "", "관찰 하나로는 판단을 묻지 않는다")
	# ② 관찰 도중 저장/불러오기
	await _reload("관찰 하나")
	_ex(d.runner.pa(PID, "mud_print") and S.has_clue(_o("mud_print")) and d.runner.pd(PID) == "", "불러온 뒤: 관찰 하나 그대로 · 판단 아직")
	_ex(not _target_ids().has(_o("mud_print")), "불러온 뒤 마친 관찰은 다시 서지 않는다")
	_ex(not S.has_clue("trace_downhill") and not d.runner.cond(_trig_when()), "불러온 뒤에도 관찰 하나로는 판단이 열리지 않는다")
	# ③ 관찰 둘 → 같은 자리에서 판단(틀린 쪽: 서쪽 숲)
	T.prefer = ["서쪽 숲가"]
	if shots: _watch_choice("oneonui_decide")
	await T.go(_o("bent_grass"))
	if shots: await _wait_watch()
	T.prefer = []
	_ex(prompts == [PROMPT], "관찰 둘 뒤 초급 판단 한 번 %s" % str(prompts))
	_ex(d.runner.pd(PID) == "forest" and not d.runner.pdone(PID) and not S.has_clue("trace_downhill"), "서쪽 숲(틀린 판단) — 아직 결과 없음")
	# ④ 판단 뒤 저장/불러오기 — 결정 유지 · 다시 묻지 않음 · 숲가 자리 열림
	await _reload("판단 뒤")
	_ex(d.runner.pd(PID) == "forest" and not d.runner.cond(_trig_when()), "불러온 뒤: 결정 유지 · 다시 묻지 않음")
	var wp: Vector2 = d.anchor(T._obj_at(_o("ff_deer_path")))
	d.teleport_to(Vector2(wp.x, wp.y + 1.6), "up")
	await T._frames(20); await T._idle()
	_ex(prompts.size() == 1, "판단 자리 안에서 불러와도 다시 묻지 않는다")
	_ex(_target_ids().has(_o("ff_deer_path")), "불러온 뒤 숲가 자리가 선다")
	# ⑤ Fail Forward: 헛걸음 → 추가 흔적 → 같은 결과 → 본 흐름(방앗간 쪽)
	await T.go(_o("ff_deer_path"))
	var cff: Dictionary = d.data.clues.get("pb_%s_ff_deer_path" % PID, {})
	_ex(S.has_clue("pb_%s_ff_deer_path" % PID) and String(cff.get("kind", "")) == "fact", "Fail Forward — 추가 흔적(본 것)")
	_ex(d.runner.pdone(PID) and S.is_flag("beast_way_read") and S.has_clue("trace_downhill") and String(d.data.clues.trace_downhill.kind) == "guess",
		"같은 결과 — 흔적이 가는 쪽(추정 △) · beast_way_read")
	_ex(load("res://scripts/region/discovery.gd").is_known(d.space_id, "place:mill"), "본 흐름으로 — 물레방앗간이 지도에")
	_ex(not _target_ids().has(_o("ff_deer_path")), "숲가 자리는 한 번만")
	# ⑥ 두 번 불러도 한 번만
	var nclue: int = S.clues.size()
	await d.runner.run([{ "activity": PID + ".mud_print" }, { "activity": PID + ".which_way" }])
	await T._idle()
	_ex(S.clues.size() == nclue and prompts.size() == 1, "같은 관찰·판단을 다시 불러도 기록·물음이 늘지 않는다")
	# ⑦ 선택 관찰 둘(가시의 털 · 울 밑 두 자국) — 판단 뒤에도 본 대로 쌓인다
	await T.go(_o("fur"))
	await T.go(_o("house_mixed"))
	_ex(S.has_clue(_o("fur")) and S.has_clue(_o("house_mixed")) and prompts.size() == 1, "선택 관찰 둘 기록 · 다시 묻지 않음")
	# ⑧ 이야기 등뼈 그대로
	_ex(d.case_fn.beats_seen() == beats0 and S.phase == "explore" and String(S.vars.get("CASE_NAMWON_OUTCOME", "")) == "" and not S.is_flag("dusk_prep"),
		"FIXED_BEATS·국면·결말 변수 그대로")
	# 밤 준비가 시작되면 관찰 자리는 비켜 준다(밤 장면을 가리지 않게)
	S.flags["dusk_prep"] = true
	var pp: Vector2 = d.anchor("obs_house_mixed")
	S.flags.erase(Problems.key(PID, "house_mixed"))
	d.teleport_to(Vector2(pp.x, pp.y + 1.6), "up")
	await T._frames(6)
	_ex(not _target_ids().has(_o("house_mixed")), "밤 준비(dusk_prep) 동안 관찰 자리 없음")
	S.flags[Problems.key(PID, "house_mixed")] = true
	S.flags.erase("dusk_prep")
	Engine.time_scale = 1.0
	if T._fails.is_empty(): printerr("STORYTEST PASS namwon:observe checks=%d time=%.0fs" % [_n_ok(), (Time.get_ticks_msec() - T._t0) / 1000.0])
	else: printerr("STORYTEST FAIL namwon:observe fails=%s" % JSON.stringify(T._fails))
	d.main._quit()

var _oks := 0
func _n_ok() -> int: return _oks
func _ex(c: bool, what: String) -> void:
	_oks += 1
	T.expect(c, what)

func _trig_when() -> String:
	for x in d.data.triggers:
		if String(x.id) == _o("which_way"): return String(x.when)
	return "false"

# 저장 → 상태 비우기 → 저장에서 다시 읽기(사건 on_load까지) — 시험 저장 파일(--savefile)만 쓴다
func _reload(tag: String) -> void:
	await T._idle()
	var S = d.S
	var before := _key_state()
	S.save()
	S.reset()
	_ex(not d.runner.pa(PID, "mud_print"), "비운 뒤엔 관찰이 없다(%s)" % tag)
	var ok: bool = S.load_saved()
	if d.case_fn.has_method("on_load"): d.case_fn.on_load()
	d.mark_dirty()
	await T._frames(6)
	_ex(ok and _key_state() == before, "저장/불러오기(%s) — 관찰·결정·기록·물건·국면 그대로" % tag)

func _key_state() -> String:
	var S = d.S
	var pb := {}
	for k in S.flags:
		if String(k).begins_with(Problems.PREFIX) or k in ["beast_way_read", "beats"]: pb[k] = str(S.flags[k])
	var it := {}
	for k in S.items: it[k] = int(S.items[k])
	return JSON.stringify([S.phase, pb, S.clues, it])

# ---- 화면(창 모드 --storyshots) ----
var _watching := false
func _watch_card(title: String, nm: String) -> void:
	_watching = true
	d.ui.auto_hold = 1.2
	Engine.time_scale = 1.0
	for i in 4000:
		await d.get_tree().process_frame
		if d.ui._card.visible and String(d.ui._card_title.text) == title:
			for k in 20: await d.get_tree().process_frame
			_grab(nm); break
	d.ui.auto_hold = 0.03
	_watching = false

func _watch_choice(nm: String) -> void:
	_watching = true
	d.ui.auto_hold = 1.2
	Engine.time_scale = 1.0
	for i in 6000:
		await d.get_tree().process_frame
		if d.ui._choice.visible and String(d.ui._choice_prompt.text) == PROMPT:
			for k in 20: await d.get_tree().process_frame
			_grab(nm); break
	d.ui.auto_hold = 0.03
	_watching = false

func _wait_watch() -> void:
	for i in 6000:
		if not _watching: break
		await d.get_tree().process_frame
	Engine.time_scale = float(d.main.args.get("storyspeed", "2.5"))

func _grab(nm: String) -> void:
	var dir: String = d.main._abs(String(d.main.args.storyshots))
	DirAccess.make_dir_recursive_absolute(dir)
	d.get_viewport().get_texture().get_image().save_png(dir.path_join("%s.png" % nm))
	T._log("SHOT " + nm)
