# Activity/Problem 계약 검사(게임플레이 구조 1차 §5·§22 — scripts/story/problems.gd). 헤드리스, validate_case_meta.gd와 나란히 돌린다.
#   godot --headless --path . -s res://tools/story/validate_problems.gd
#   등록부의 모든 사건 데이터(불러올 때 problems.expand가 끝난 것)에 대해:
#     1 계약: 활동 type 넷(inspect·compare·connect·decide)만 · seen은 있는 앵커 · heard는 by와 있는 인물 + 그 인물 talk의 { activity } ·
#       needs/from/fail_forward가 있는 id · 데이터 어디서든 { activity: '문제.활동' }이 있는 활동 · 문제 단계에 event·phase·outcome·ending 없음
#     2 공통 코드에 사건 id 없음: scripts/story/problems.gd 글에 등록된 사건 id 글자('namwon' 등)가 없다
#     3 중복 완료 막음: 만든 활동 단계마다 첫 단계가 '아직 안 했으면'(pa/pd) 조건이고, 그 안 첫 단계가 완료 깃발
#     4 저장/불러오기: 활동을 다 마친 깃발을 JSON으로 저장했다 다시 읽으면 깃발이 그대로이고, 마친 관찰 자리·결정 다시 묻기가 다시 서지 않는다
#   저장 파일: user://st_validate_problems.json(사용자 저장을 건드리지 않는다 — 끝나면 지운다)
#   끝 줄: PROBLEMS PASS 사건수 problems=문제수 / PROBLEMS FAIL 실패수
extends SceneTree

const CaseRegistry := preload("res://scripts/story/case_registry.gd")
const Problems := preload("res://scripts/story/problems.gd")
const Progress := preload("res://scripts/region/progress.gd")
const StoryState := preload("res://scripts/story/story_state.gd")
const StoryRunner := preload("res://scripts/story/story_runner.gd")
const COMMON := ["res://scripts/story/problems.gd"]
const SAVE := "user://st_validate_problems.json"

var fails := 0
var n_cases := 0
var n_probs := 0

func _fail(where: String, msg: String) -> void:
	fails += 1
	print("FAIL %s: %s" % [where, msg])

# 공통 코드에 사건 id 글자가 있나(시험도 쓴다) — 찾은 것 목록
static func hardcoded(ids: Array, files := COMMON) -> Array:
	var out := []
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		for id in ids:
			for q in ["'%s'" % id, "\"%s\"" % id]:
				if src.contains(q): out.append("%s: %s" % [path.get_file(), q])
	return out

# 만든 단계에 중복 완료 막음이 있나 — 실패 문구
static func guard_errors(data: Dictionary) -> Array:
	var errs := []
	var acts: Dictionary = data.get("activity_steps", {})
	for k in acts:
		var st: Array = acts[k]
		var g = st[0] if not st.is_empty() else {}
		var cond := String(g.get("if", "")) if g is Dictionary else ""
		if not (cond.begins_with("not pa(") or cond.begins_with("pd(")): errs.append("%s: 첫 단계가 완료 막음 조건이 아님" % k); continue
		var then_: Array = g.get("then", [])
		if cond.begins_with("not pa(") and (then_.is_empty() or not String(then_[0].get("flag", "")).begins_with(Problems.PREFIX)):
			errs.append("%s: 막음 안 첫 단계가 완료 깃발이 아님" % k)
	for o in data.get("objects", []):
		if String(o.get("id", "")).begins_with("pb_") and not String(o.get("when", "")).contains("not "):
			errs.append("%s: 조사 대상 when에 '마쳤으면 숨김'이 없음" % o.id)
	return errs

# 활동을 다 마친 상태를 저장 → 다시 읽기 → 만든 대상·트리거가 다시 서지 않나 — 실패 문구
static func saveload_errors(id: String, data: Dictionary) -> Array:
	var errs := []
	var S := StoryState.new("")
	S.phase = "explore"
	for pid in data.get("problems", {}):
		var p: Dictionary = data.problems[pid]
		for a in p.get("activities", []):
			S.flags[Problems.key(pid, String(a.id))] = true
			if String(a.get("type", "")) == "decide" and not (a.get("options", []) as Array).is_empty():
				S.flags[Problems.decision_key(pid)] = String(a.options[0].id)
		for ff in p.get("fail_forward", {}): S.flags[Problems.ff_key(pid, ff)] = true
		S.flags[Problems.done_key(pid)] = true
	var j := JSON.stringify(S.to_dict())
	var S2 := StoryState.new("")
	if not S2.from_dict(JSON.parse_string(j)): return ["저장 다시 읽기 실패"]
	for k in S.flags:
		if String(k).begins_with(Problems.PREFIX) and str(S2.flags.get(k)) != str(S.flags[k]): errs.append("깃발이 저장 뒤 바뀜: " + k)
	var r := StoryRunner.new(null, S2)
	for o in data.get("objects", []):
		if String(o.get("id", "")).begins_with("pb_") and r.cond(o.get("when", true)): errs.append("다 마친 뒤 불러와도 다시 섬: " + String(o.id))
	for t in data.get("triggers", []):
		if String(t.get("id", "")).begins_with("pb_") and r.cond(t.get("when", true)): errs.append("다 마친 뒤 불러와도 다시 물음: " + String(t.id))
	return errs

func _init() -> void:
	Progress.use_path(SAVE)
	var ids := CaseRegistry.all_ids()
	for e in hardcoded(ids): _fail("공통 코드", "사건 id 글자 " + e)
	# 검사기가 막아야 할 것을 막는지(작은 가짜 데이터)
	var bad := { "anchors": {}, "actors": [], "problems": { "p": { "activities": [
		{ "id": "a", "type": "inspect", "kind": "seen", "at": "nowhere", "text": "x", "record": { "title": "t" } },
		{ "id": "b", "type": "inspect", "kind": "heard", "actor": "ghost", "record": { "title": "t" } },
		{ "id": "c", "type": "classify" }] } } }
	var be := Problems.validate(bad)
	for want in ["없는 앵커", "by(말한 사람) 없음", "없는 인물", "모르는 type"]:
		if not be.any(func(e): return String(e).contains(want)): _fail("self", "잘못된 데이터를 못 잡음: " + want)
	for id in ids:
		n_cases += 1
		var data := CaseRegistry.load_data(String(id))
		if data.is_empty(): _fail(id, "데이터 못 읽음"); continue
		var np: int = (data.get("problems", {}) as Dictionary).size()
		n_probs += np
		for e in Problems.validate(data): _fail(id, e)
		if np == 0:
			print("CASE %s problems=0" % id); continue
		for e in guard_errors(data): _fail(id, e)
		for e in saveload_errors(String(id), data): _fail(id, e)
		print("CASE %s problems=%d activities=%d" % [id, np, (data.get("activity_steps", {}) as Dictionary).size()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	if fails == 0: print("PROBLEMS PASS %d problems=%d" % [n_cases, n_probs])
	else: print("PROBLEMS FAIL %d" % fails)
	quit(0 if fails == 0 else 1)
