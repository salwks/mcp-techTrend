# Activity/Problem 공통 시험(게임플레이 구조 1차 §23 — scripts/story/problems.gd) — 헤드리스, 저장은 따로(user://st_activity.json, 끝나면 지운다).
#   godot --headless --path . -s res://tests/activity/activity_test.gd
#   A 데이터 계약: 맞는 가짜 문제는 통과 · 틀린 것(없는 앵커·인물·활동·fail_forward, by 없는 heard, talk에 없는 heard, 모르는 type, after 과다, 금지 단계)은 잡는다
#   B 다른 사건 id를 공통 코드에 박지 않았다(problems.gd 글 · 활동 단계가 사건 id를 모른다)
#   C 실제 실행(StoryRunner + 가짜 연출): 관찰 기록(본 것 fact / 들은 것 heard+by) · 둘째 관찰 뒤 같은 흐름에서 결정 · 비교(needs 둘) 자동 ·
#     같은 활동을 두 번 불러도 한 번만(기록·물건·카드) · fail_forward 갈래 → 자리 → 추가 흔적 → 결과 한 번
#   D 저장/불러오기: 관찰 하나 뒤 JSON 저장 → 새 상태로 읽기 → 마친 관찰은 다시 서지 않고 결정은 아직 · 이어서 둘째 관찰 → 결정 한 번 ·
#     결정 뒤 저장 → 결정 유지 · 다시 묻지 않음 · 물건을 되돌리지 않음
#   E 문제 단계는 FIXED_BEAT(event)·phase·outcome을 건드리지 않는다
#   F 재사용 시연(브리프 §21): 춘향이 끝난 뒤 관아 곁일 「창고 장부 대조」(story/namwon_chunhyang/namwon_chunhyang_side_data.gd)가
#     같은 계약을 데이터만으로 쓴다 — 계약 통과 · 꼴(본 것 둘 + 들은 것 + 비교 + 결정 + fail_forward) · call 없음 · 사건 스크립트·공통 코드가 이 일을 모름 ·
#     끝나기 전엔 안 섬 · 실제 실행(곧장 · fail_forward) · 저장/불러오기 · 한 번만
#   가짜 문제는 이 파일 안 사전 — 등록부에도 놀이 콘텐츠에도 없다.
#   끝 줄: ACTIVITYTEST PASS n / ACTIVITYTEST FAIL n
extends SceneTree

const Problems := preload("res://scripts/story/problems.gd")
const CaseRegistry := preload("res://scripts/story/case_registry.gd")
const Progress := preload("res://scripts/region/progress.gd")
const StoryState := preload("res://scripts/story/story_state.gd")
const StoryRunner := preload("res://scripts/story/story_runner.gd")
const Validator := preload("res://tools/story/validate_problems.gd")

const SAVE := "user://st_activity.json"

var n := 0
var fails := 0

func ok(c: bool, what: String) -> void:
	n += 1
	if c: print("  ok  ", what)
	else:
		fails += 1
		print("  FAIL ", what)

# ---- 가짜 연출(story_director 대신 — 이야기 명령이 부르는 것만) ----
class FakeUI:
	extends RefCounted
	var cards := []
	var captions := []
	var choices := []
	var pick := {}     # 물음 → 고를 label 일부
	func say(_w, _l) -> void: pass
	func caption(t, _s := 0.0) -> void: captions.append(String(t))
	func toast(_t, _k := "") -> void: pass
	func examine(title, text, _k := "clue") -> void: cards.append([String(title), text])
	func choice(prompt: String, opts: Array) -> int:
		choices.append(prompt)
		var want := String(pick.get(prompt, ""))
		for i in opts.size():
			if want != "" and String(opts[i].label).contains(want): return i
		return 0

class FakeDirector:
	extends RefCounted
	var data := {}
	var S
	var ui := FakeUI.new()
	var log_story := false
	var runner
	func mark_dirty() -> void: pass
	func on_story_idle() -> void: pass
	func outcome_var() -> String: return "X_OUTCOME"
	func learn_clue(id: String, _q := false) -> void:
		if not S.clues.has(id): S.clues.append(id)
	func learn_rule(id: String, _q := false) -> void:
		if not S.rules.has(id): S.rules.append(id)
	func give(id: String, nn := 1, _q := false) -> void: S.items[id] = S.count(id) + nn
	func take(id: String, nn := 1) -> void: S.items[id] = maxi(0, S.count(id) - nn)
	func on_event(_i, _e) -> void: pass

# 다른 관아·사건에서도 쓸 꼴(장부 대조) — 본 것 둘 + 들은 것 하나 + 비교 + 결정(한 갈래는 fail_forward)
static func fixture() -> Dictionary:
	return {
		"anchors": { "ledger": [0.0, 0.0], "crates": [6.0, 0.0], "yard": [3.0, 3.0], "back_shed": [12.0, 0.0] },
		"actors": [{ "id": "clerk", "name": "창고지기", "talk": [{ "when": "true", "steps": [
			{ "say": "창고지기", "lines": ["어제 열 섬 들어왔소."] }, { "activity": "store.clerk_word" }] }] }],
		"clues": {},
		"objects": [],
		"triggers": [],
		"problems": {
			"store": {
				"title": "창고 장부 대조",
				"when": "f('open')",
				"activities": [
					{ "id": "ledger", "type": "inspect", "kind": "seen", "at": "ledger", "label": "장부 · 살펴보기", "text": ["장부에는 열 섬."],
						"record": { "title": "장부", "text": "열 섬이라 적혀 있다." }, "do": [{ "give": "ITM_X", "n": 1 }] },
					{ "id": "crates", "type": "inspect", "kind": "seen", "at": "crates", "label": "가마 · 살펴보기", "text": ["가마는 일곱."],
						"record": { "title": "가마", "text": "실제로는 일곱 가마." } },
					{ "id": "clerk_word", "type": "inspect", "kind": "heard", "actor": "clerk", "by": "창고지기",
						"record": { "title": "창고지기의 말", "text": "어제 열 섬 들어왔다고 했다." }, "required": false },
					{ "id": "gap", "type": "compare", "needs": ["ledger", "crates"], "text": ["장부와 가마 수가 다르다."],
						"record": { "title": "세 섬의 차이", "text": "장부 열 섬, 실제 일곱.", "kind": "fact" }, "flags": ["store_gap_seen"] },
					{ "id": "handle", "type": "decide", "after": 2, "from": ["ledger", "crates"], "at": "yard", "radius": 20.0, "prompt": "어떻게 할까?",
						"options": [
							{ "id": "report", "label": "적어 둔다", "flags": ["store_recorded"] },
							{ "id": "shed", "label": "뒤 헛간부터 본다", "fail_forward": "shed" }] },
				],
				"fail_forward": { "shed": { "at": "back_shed", "label": "헛간 · 살펴보기", "text": ["빈 헛간이다."],
					"extra": { "text": ["바닥에 쌀 낟알이 흘러 있다."], "record": { "title": "흘린 낟알", "text": "헛간 바닥에 쌀 낟알." } } } },
				"result": { "flags": ["store_handled"], "do": [{ "give": "ITM_DONE", "n": 1 }] },
			},
		},
	}

static func _second_decide(a: Dictionary) -> Dictionary:
	var b := a.duplicate(true)
	b.id = "handle2"
	return b

func _mk() -> Array:   # [director, state, runner] — 데이터는 expand까지
	var d := FakeDirector.new()
	d.data = Problems.expand(fixture())
	d.S = StoryState.new("")
	d.S.phase = "explore"
	d.S.flags["open"] = true
	d.runner = StoryRunner.new(d, d.S)
	return [d, d.S, d.runner]

func _obj(d, id: String) -> Dictionary:
	for o in d.data.objects:
		if String(o.id) == id: return o
	return {}

func _trig(d, id: String) -> Dictionary:
	for t in d.data.triggers:
		if String(t.id) == id: return t
	return {}

func _run(r, steps: Array) -> void:
	await r.exec(steps, r.gen)

func _init() -> void:
	DirAccess.remove_absolute(Progress.SaveGuard.resolve(SAVE))
	Progress.use_path(SAVE)
	await _contract()
	_hardcode()
	await _runtime()
	await _saveload()
	_beats()
	await _reuse()
	DirAccess.remove_absolute(Progress.SaveGuard.resolve(SAVE))
	print("ACTIVITYTEST %s %d" % ["PASS" if fails == 0 else "FAIL", n if fails == 0 else fails])
	quit(0 if fails == 0 else 1)

# ---- A 데이터 계약 ----
func _contract() -> void:
	print("A 데이터 계약")
	var good := Problems.expand(fixture())
	ok(Problems.validate(good).is_empty(), "맞는 가짜 문제 통과 %s" % str(Problems.validate(good)))
	ok(Validator.guard_errors(good).is_empty(), "만든 단계마다 중복 완료 막음 %s" % str(Validator.guard_errors(good)))
	ok(Validator.saveload_errors("fixture", good).is_empty(), "검사기 저장/불러오기 %s" % str(Validator.saveload_errors("fixture", good)))
	var g2 := Problems.expand(good)
	ok(g2.objects.size() == 3 and g2.triggers.size() == 1, "expand 두 번 불러도 한 번만(대상 3 · 트리거 1 — %d · %d)" % [g2.objects.size(), g2.triggers.size()])
	ok(good.clues.has("pb_store_ledger") and good.clues.pb_store_ledger.kind == "fact", "본 것 기록 = fact")
	ok(good.clues.pb_store_clerk_word.kind == "heard" and good.clues.pb_store_clerk_word.by == "창고지기", "들은 것 기록 = heard + 말한 사람")
	ok(good.clues.pb_store_gap.kind == "fact" and good.clues.pb_store_ff_shed.kind == "fact", "비교(확인) fact · 추가 흔적 fact")
	ok(not good.objects.any(func(o): return String(o.id) == "pb_store_clerk_word"), "들은 것은 조사 대상을 만들지 않는다(인물 talk에서)")
	# 틀린 것 — 하나씩 고쳐서 잡히는지
	var cases := [
		["없는 앵커", func(f): f.problems.store.activities[0].at = "nowhere"],
		["없는 인물", func(f): f.problems.store.activities[2].actor = "ghost"],
		["by(말한 사람) 없음", func(f): f.problems.store.activities[2].erase("by")],
		["talk 어디에도", func(f): f.actors[0].talk[0].steps = []],
		["모르는 type", func(f): f.problems.store.activities[1].type = "classify"],
		["needs/from에 없는 활동", func(f): f.problems.store.activities[3].needs = ["ledger", "nope"]],
		["after 3 >", func(f): f.problems.store.activities[4].after = 3],
		["없는 fail_forward", func(f): f.problems.store.activities[4].options[1].fail_forward = "nope"],
		["'event' 금지", func(f): f.problems.store.activities[0].do = [{ "event": "S0007" }]],
		["'outcome' 금지", func(f): f.problems.store.result.do = [{ "outcome": "A" }]],
		["없는 활동을 부름", func(f): f.actors[0].talk[0].steps.append({ "activity": "store.typo" })],
		["record.title 없음", func(f): f.problems.store.activities[1].erase("record")],
		["decide는 문제마다 하나", func(f): f.problems.store.activities.append(_second_decide(f.problems.store.activities[4]))],
	]
	for c in cases:
		var f := fixture()
		c[1].call(f)
		var errs := Problems.validate(f)
		ok(errs.any(func(e): return String(e).contains(c[0])), "잡음: %s %s" % [c[0], str(errs.slice(0, 2))])

# ---- B 공통 코드에 사건 id 없음 ----
func _hardcode() -> void:
	print("B 다른 사건 id 하드코딩 없음")
	var ids := CaseRegistry.all_ids()
	ok(ids.size() >= 9 and Validator.hardcoded(ids).is_empty(), "problems.gd에 등록 사건 id 글자 없음(%d개 확인) %s" % [ids.size(), str(Validator.hardcoded(ids))])
	ok(not Validator.hardcoded(["namwon"], ["res://tests/activity/activity_test.gd"]).is_empty(), "검사가 실제로 찾는다(이 파일의 'namwon' 글자)")
	var src := FileAccess.get_file_as_string("res://scripts/story/problems.gd")
	ok(not src.contains("case_id") and not src.contains("CASE_"), "problems.gd가 사건 id·사건 변수를 읽지 않는다")
	var f := Problems.expand(fixture())
	ok(not JSON.stringify(f.activity_steps).contains("namwon"), "만든 단계에 다른 사건 이름이 끼지 않는다")

# ---- C 실제 실행 ----
func _runtime() -> void:
	print("C 실제 실행")
	var m := _mk(); var d = m[0]; var S = m[1]; var r = m[2]
	var o_ledger := _obj(d, "pb_store_ledger")
	ok(r.cond(o_ledger.when), "처음엔 장부 살펴보기가 선다")
	await _run(r, o_ledger.steps)
	ok(r.pa("store", "ledger") and S.has_clue("pb_store_ledger") and d.ui.cards.size() == 1, "관찰 기록 · 카드 한 장")
	ok(not r.cond(o_ledger.when), "마친 관찰은 대상에서 빠진다")
	ok(d.ui.choices.is_empty() and r.pd("store") == "", "관찰 하나로는 결정을 묻지 않는다")
	# 같은 활동을 두 번 — 기록·물건·카드가 늘지 않는다
	await _run(r, [{ "activity": "store.ledger" }])
	await _run(r, o_ledger.steps)
	ok(S.clues.count("pb_store_ledger") == 1 and S.count("ITM_X") == 1 and d.ui.cards.size() == 1, "두 번 불러도 한 번만(기록 1 · 물건 1 · 카드 1)")
	# 들은 것(인물 talk의 activity)
	await _run(r, d.data.actors[0].talk[0].steps)
	ok(S.has_clue("pb_store_clerk_word") and r.pa("store", "clerk_word"), "들은 것 — 인물 대화 안에서 기록")
	# 둘째 관찰 → 같은 흐름에서 비교(needs) → 결정(after 2)
	d.ui.pick = { "어떻게 할까?": "적어 둔다" }
	await _run(r, _obj(d, "pb_store_crates").steps)
	ok(r.pa("store", "gap") and S.is_flag("store_gap_seen") and S.has_clue("pb_store_gap"), "비교가 둘째 관찰 뒤 저절로(차이 확인 깃발)")
	ok(d.ui.choices == ["어떻게 할까?"] and r.pd("store") == "report", "같은 흐름에서 결정 한 번 — report")
	ok(S.is_flag("store_recorded") and S.is_flag("store_handled") and r.pdone("store") and S.count("ITM_DONE") == 1, "결정 깃발 · 결과 깃발 · 결과 물건 한 번")
	ok(not r.cond(_trig(d, "pb_store_handle").when), "결정 뒤엔 다시 묻는 트리거가 서지 않는다")
	await _run(r, [{ "activity": "store.handle" }])
	ok(d.ui.choices.size() == 1 and S.count("ITM_DONE") == 1, "결정 활동을 다시 불러도 묻지 않고 결과도 한 번")
	ok(not r.cond(_obj(d, "pb_store_ff_shed").when), "다른 갈래(fail_forward) 자리는 서지 않는다")
	# fail_forward 갈래
	var m2 := _mk(); var d2 = m2[0]; var S2 = m2[1]; var r2 = m2[2]
	d2.ui.pick = { "어떻게 할까?": "헛간" }
	await _run(r2, _obj(d2, "pb_store_ledger").steps)
	await _run(r2, _obj(d2, "pb_store_crates").steps)
	ok(r2.pd("store") == "shed" and not r2.pdone("store") and not S2.is_flag("store_handled"), "잘못 짚은 갈래 — 아직 풀리지 않음(막히지 않고 자리가 열린다)")
	var ff := _obj(d2, "pb_store_ff_shed")
	ok(r2.cond(ff.when), "fail_forward 자리가 선다")
	await _run(r2, ff.steps)
	ok(S2.has_clue("pb_store_ff_shed") and r2.pdone("store") and S2.is_flag("store_handled") and not r2.cond(ff.when), "헛걸음 → 추가 흔적 → 결과(같은 결과 깃발) · 자리 닫힘")
	ok(d2.ui.cards.size() == 2 + 1 + 2, "카드: 관찰 둘 + 비교 + 헛간·추가 흔적 (%d)" % d2.ui.cards.size())
	await _run(r2, ff.steps)
	ok(S2.count("ITM_DONE") == 1 and d2.ui.cards.size() == 5, "fail_forward 자리를 다시 불러도 한 번만")

# ---- D 저장/불러오기 ----
func _reload(d, S) -> Array:
	var j := JSON.stringify(S.to_dict())
	var S2 := StoryState.new("")
	S2.from_dict(JSON.parse_string(j))
	var d2 := FakeDirector.new()
	d2.data = d.data
	d2.S = S2
	d2.runner = StoryRunner.new(d2, S2)
	return [d2, S2, d2.runner]

func _saveload() -> void:
	print("D 저장/불러오기")
	var m := _mk(); var d = m[0]; var S = m[1]; var r = m[2]
	await _run(r, _obj(d, "pb_store_ledger").steps)
	var l := _reload(d, S); var d2 = l[0]; var S2 = l[1]; var r2 = l[2]
	ok(r2.pa("store", "ledger") and S2.has_clue("pb_store_ledger") and S2.count("ITM_X") == 1, "관찰 하나 뒤 저장 → 그대로(기록·물건)")
	ok(not r2.cond(_obj(d2, "pb_store_ledger").when), "마친 관찰은 불러온 뒤 다시 서지 않는다")
	ok(not r2.cond(_trig(d2, "pb_store_handle").when) and r2.pd("store") == "", "결정은 아직(관찰 하나)")
	d2.ui.pick = { "어떻게 할까?": "헛간" }
	await _run(r2, _obj(d2, "pb_store_crates").steps)
	ok(d2.ui.choices.size() == 1 and r2.pd("store") == "shed", "불러온 뒤 둘째 관찰 → 결정 한 번")
	var l3 := _reload(d2, S2); var d3 = l3[0]; var S3 = l3[1]; var r3 = l3[2]
	ok(r3.pd("store") == "shed" and not r3.cond(_trig(d3, "pb_store_handle").when), "결정 뒤 저장 → 결정 유지 · 다시 묻지 않음")
	ok(r3.cond(_obj(d3, "pb_store_ff_shed").when), "fail_forward 자리는 불러온 뒤에도 열려 있다")
	await _run(r3, _obj(d3, "pb_store_ff_shed").steps)
	var l4 := _reload(d3, S3); var S4 = l4[1]; var r4 = l4[2]
	ok(r4.pdone("store") and S4.is_flag("store_handled") and S4.count("ITM_DONE") == 1 and S4.count("ITM_X") == 1, "풀린 뒤 저장 → 결과·물건 그대로(되돌리지 않음)")
	# 결정 도중 끊김(관찰 둘은 저장, 결정 전) → 불러오면 다시 묻는 트리거가 선다(자리 안에서)
	var S5 := StoryState.new("")
	S5.flags = { "open": true, Problems.key("store", "ledger"): true, Problems.key("store", "crates"): true }
	var r5 := StoryRunner.new(d, S5)
	ok(r5.cond(_trig(d, "pb_store_handle").when) and String(_trig(d, "pb_store_handle").at) == "yard", "결정 전에 끊긴 저장 → 결정 자리 트리거가 다시 선다")

# ---- E FIXED_BEAT·국면·결말 무관 ----
func _beats() -> void:
	print("E 이야기 등뼈 무관")
	var f := Problems.expand(fixture())
	var keys := {}
	Problems._find_keys(f.activity_steps, keys)
	for o in f.objects: Problems._find_keys(o.get("steps", []), keys)
	ok(not keys.has("event") and not keys.has("phase") and not keys.has("outcome") and not keys.has("ending"), "만든 단계에 event·phase·outcome·ending 없음")
	var nw := CaseRegistry.load_data("namwon")
	ok(Problems.validate(nw).is_empty() and nw.has("activity_steps"), "실제 사건 데이터(오누이) 계약 통과")

# ---- F 재사용 시연 — 관아 창고 장부 대조(실제 사건 데이터) ----
const SIDE_PATH := "res://story/namwon_chunhyang/namwon_chunhyang_side_data.gd"

func _side_mk(data: Dictionary, phase: String) -> Array:
	var d := FakeDirector.new()
	d.data = data
	d.S = StoryState.new("")
	d.S.phase = phase
	d.runner = StoryRunner.new(d, d.S)
	return [d, d.S, d.runner]

func _reuse() -> void:
	print("F 재사용 시연 — 관아 창고 장부 대조")
	var data := CaseRegistry.load_data("namwon_chunhyang")
	var p: Dictionary = data.get("problems", {}).get("ledger", {})
	ok(not p.is_empty() and Problems.validate(data).is_empty(), "춘향 사건 데이터에 곁일 ledger · 계약 통과 %s" % str(Problems.validate(data).slice(0, 2)))
	var kinds := []
	for a in p.get("activities", []): kinds.append("%s/%s" % [a.type, a.get("kind", "")])
	ok(kinds == ["inspect/seen", "inspect/seen", "inspect/heard", "compare/", "decide/"] and (p.get("fail_forward", {}) as Dictionary).size() == 1,
		"꼴: 본 것 둘 + 들은 것 + 비교 + 결정 + fail_forward (%s)" % [kinds])
	var side_src := FileAccess.get_file_as_string(SIDE_PATH)
	var keys := {}
	Problems._find_keys(p, keys)
	ok(not keys.has("call") and not side_src.contains("\"call\""), "곁일 데이터에 사건 코드 호출(call) 없음 — 데이터만")
	var leaks := []
	for f in ["namwon_chunhyang_case.gd", "namwon_chunhyang_p2a.gd", "namwon_chunhyang_p2b.gd"]:
		var src := FileAccess.get_file_as_string("res://story/namwon_chunhyang/" + f)
		if src.contains("ledger"): leaks.append(f)
	for f in ["res://scripts/story/problems.gd", "res://scripts/story/story_runner.gd", "res://scripts/story/story_director.gd"]:
		if FileAccess.get_file_as_string(f).contains("ledger"): leaks.append(f.get_file())
	ok(leaks.is_empty(), "사건 스크립트·공통 코드가 곁일을 모른다(글자 'ledger' 없음 %s)" % [leaks])
	ok(Validator.guard_errors(data).is_empty() and Validator.saveload_errors("namwon_chunhyang", data).is_empty(), "검사기 — 중복 완료 막음 · 저장/불러오기")
	var objs := {}
	for o in data.objects:
		if String(o.get("problem", "")) == "ledger": objs[String(o.id)] = o
	var trig := {}
	for tr in data.triggers:
		if String(tr.get("problem", "")) == "ledger": trig = tr
	ok(objs.has("pb_ledger_book") and objs.has("pb_ledger_stock") and objs.has("pb_ledger_ff_back_shed") and not trig.is_empty(), "조사 대상 셋(장부·가마니·뒤 곳간) · 결정 자리 하나")
	# 끝나기 전(단계 jail · epilogue)엔 안 선다
	for ph in ["jail", "feast", "epilogue"]:
		var r0 = _side_mk(data, ph)[2]
		ok(not r0.cond(objs.pb_ledger_book.when) and not r0.cond(objs.pb_ledger_stock.when), "단계 %s — 곁일 안 섬(본 흐름 방해 없음)" % ph)
	# 곧장: 장부 → 창고지기 → 가마니 → 비교 → 결정(적는다)
	var m := _side_mk(data, "done"); var d = m[0]; var S = m[1]; var r = m[2]
	ok(r.cond(objs.pb_ledger_book.when), "끝난 뒤(done) — 장부가 선다")
	await _run(r, objs.pb_ledger_book.steps)
	ok(r.pa("ledger", "book") and S.has_clue("pb_ledger_book") and d.ui.choices.is_empty(), "장부(본 것) · 하나로는 안 물음")
	var keeper: Dictionary = {}
	for ac in data.actors:
		if String(ac.id) == "ledger_keeper": keeper = ac
	await _run(r, keeper.talk[0].steps)
	ok(S.has_clue("pb_ledger_keeper") and String(data.clues.pb_ledger_keeper.kind) == "heard" and String(data.clues.pb_ledger_keeper.by) == "창고지기", "창고지기의 말(들은 것 + 말한 사람)")
	d.ui.pick = { "장부를 어떻게 할까?": "센 대로" }
	await _run(r, objs.pb_ledger_stock.steps)
	ok(S.is_flag("ledger_gap_seen") and r.pd("ledger") == "note" and S.is_flag("ledger_noted") and r.pdone("ledger") and S.is_flag("ledger_check_done"), "비교 → 결정 한 번 → 풀림(ledger_noted)")
	var nc: int = S.clues.size()
	await _run(r, objs.pb_ledger_stock.steps + [{ "activity": "ledger.handle" }, { "activity": "ledger.gap" }])
	ok(S.clues.size() == nc and d.ui.choices.size() == 1, "두 번 불러도 한 번")
	ok(not S.vars.has("CASE_NAMWON_CHUNHYANG_OUTCOME") or String(S.vars.CASE_NAMWON_CHUNHYANG_OUTCOME) == "", "곁일은 결말 변수를 건드리지 않는다")
	# fail_forward 갈래 + 저장/불러오기
	var m2 := _side_mk(data, "done"); var d2 = m2[0]; var S2 = m2[1]; var r2 = m2[2]
	d2.ui.pick = { "장부를 어떻게 할까?": "뒤 곳간" }
	await _run(r2, objs.pb_ledger_book.steps)
	var l := _reload(d2, S2); var d3 = l[0]; var S3 = l[1]; var r3 = l[2]
	d3.ui.pick = d2.ui.pick
	ok(r3.pa("ledger", "book") and not r3.cond(objs.pb_ledger_book.when), "장부 본 뒤 저장 → 불러와도 다시 안 섬")
	await _run(r3, objs.pb_ledger_stock.steps)
	ok(r3.pd("ledger") == "shed" and not r3.pdone("ledger") and r3.cond(objs.pb_ledger_ff_back_shed.when), "뒤 곳간 갈래 — 안 막힘, 헛걸음 자리 열림")
	var l4 := _reload(d3, S3); var S4 = l4[1]; var r4 = l4[2]
	ok(r4.pd("ledger") == "shed" and not r4.cond(trig.when) and r4.cond(objs.pb_ledger_ff_back_shed.when), "결정 뒤 저장 → 결정 유지 · 다시 안 물음 · 자리 그대로")
	await _run(r4, objs.pb_ledger_ff_back_shed.steps)
	ok(S4.has_clue("pb_ledger_ff_back_shed") and r4.pdone("ledger") and S4.is_flag("ledger_check_done") and S4.is_flag("ledger_noted"), "헛걸음 → 추가 흔적 → 같은 결과")
