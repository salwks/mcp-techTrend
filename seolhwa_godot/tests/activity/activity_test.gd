# Activity/Problem 공통 시험(게임플레이 구조 1차 §23 — scripts/story/problems.gd) — 헤드리스, 저장은 따로(user://st_activity.json, 끝나면 지운다).
#   godot --headless --path . -s res://tests/activity/activity_test.gd
#   A 데이터 계약: 맞는 가짜 문제는 통과 · 틀린 것(없는 앵커·인물·활동·fail_forward, by 없는 heard, talk에 없는 heard, 모르는 type, after 과다, 금지 단계)은 잡는다
#   B 다른 사건 id를 공통 코드에 박지 않았다(problems.gd 글 · 활동 단계가 사건 id를 모른다)
#   C 실제 실행(StoryRunner + 가짜 연출): 관찰 기록(본 것 fact / 들은 것 heard+by) · 둘째 관찰 뒤 같은 흐름에서 결정 · 비교(needs 둘) 자동 ·
#     같은 활동을 두 번 불러도 한 번만(기록·물건·카드) · fail_forward 갈래 → 자리 → 추가 흔적 → 결과 한 번
#   D 저장/불러오기: 관찰 하나 뒤 JSON 저장 → 새 상태로 읽기 → 마친 관찰은 다시 서지 않고 결정은 아직 · 이어서 둘째 관찰 → 결정 한 번 ·
#     결정 뒤 저장 → 결정 유지 · 다시 묻지 않음 · 물건을 되돌리지 않음
#   E 문제 단계는 FIXED_BEAT(event)·phase·outcome을 건드리지 않는다
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Progress.use_path(SAVE)
	await _contract()
	_hardcode()
	await _runtime()
	await _saveload()
	_beats()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
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
