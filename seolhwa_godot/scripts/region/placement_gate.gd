# 배치 조건(제작 규칙 F-11) — placement_*.json의 항목·군중(crowds)에 붙은 "when"을 사건·공통 변수가 바뀔 때만 다시 본다.
#
#   조건 언어는 이야기 DSL(story_runner.cond)과 같다. 항목의 사건은 파일 머리 "case"(항목 "case"가 있으면 그것):
#     ph('단계')   그 사건의 단계 — 지금 도는 사건이면 살아 있는 상태(story_state), 아니면 저장된 진행(progress cases.<id>), 없으면 ""
#     f('플래그') · w('지역 상태')   같은 사건의 flags · world
#     v('변수')    공통 상태 변수(CASE_NAMWON_COMPLETE …) — 도는 사건이 있으면 그 S.vars, 없으면 progress vars(+기본값)
#     active('id') 지금 이 공간에서 도는 사건이 그 id인가(case_registry.choose가 고른 것)
#     fn('is_night') · night()   밤인가(19~5시) — 도는 사건이 그 사건이고 같은 이름 함수가 있으면 사건 함수
#   빈 조건·"true"는 늘 참. 조건식 오류는 한 번 알리고 거짓.
#
#   다시 보는 때(매 프레임 식을 돌리지 않는다): poll()이 매 프레임 값 넷만 비교한다 —
#     progress.version(변수·사건 저장) · 도는 사건 id · 이야기 갱신 번호(story_director._refresh가 mark()) · 밤/낮(시간 조건이 있을 때만)
#   하나라도 바뀌면 refresh() — 조건이 바뀐 항목만 알림(cb(on)).
#
#   등록: add(키, when, case, cb) — 배치 항목(placement_loader._place_one → world.set_static_enabled), 군중(event_crowd.gd)이 쓴다.
#   시험: fake = { case_id, phase, vars:{}, cases:{id:{phase, flags, world}}, hour } 를 넣으면 실제 이야기·저장 대신 그 값을 본다.
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")
const StoryState := preload("res://scripts/story/story_state.gd")

var main = null          # region_main(story·hour) — 없으면 저장만 본다
var fake = null          # 시험용 상태(위 머리말)
var evals := 0           # 조건식을 돌린 횟수(시험: 매 프레임 돌지 않는지)
var refreshes := 0       # refresh() 횟수
var _items := {}         # 키 → { when, case, cbs:[Callable], on(null = 아직) }
var _exprs := {}
var _bad := {}
var _cur := ""           # 지금 보는 항목의 사건 id
var _uses_time := false
var _pv := -1
var _case := "?"
var _gen := 0
var _seen_gen := -1
var _night := false

func clear() -> void:
	_items.clear()
	_uses_time = false
	_pv = -1

# 조건 항목 등록 — 지금 값을 곧바로 cb(on)으로 알린다
func add(key: String, when, case_id: String, cb: Callable) -> bool:
	var w := _norm(when)
	if not _items.has(key): _items[key] = { when = w, case = case_id, cbs = [], on = null }
	var it: Dictionary = _items[key]
	it.when = w; it.case = case_id
	it.cbs.append(cb)
	if w.contains("night") or w.contains("hour"): _uses_time = true
	var on := eval(w, case_id)
	it.on = on
	cb.call(on)
	return on

func remove(key: String) -> void:
	_items.erase(key)

func has(key: String) -> bool: return _items.has(key)
func is_on(key: String) -> bool: return bool(_items.get(key, {}).get("on", false))
func keys() -> Array: return _items.keys()

# 이야기 쪽이 상태를 바꿨다(story_director._refresh·on_phase) — 다음 poll에서 다시 본다
func mark() -> void:
	_gen += 1

# 매 프레임: 값 넷만 비교, 바뀌었을 때만 refresh
func poll() -> void:
	if _items.is_empty(): return
	var cid := _active_case()
	var nt := _is_night() if _uses_time else false
	if Progress.version == _pv and cid == _case and _gen == _seen_gen and nt == _night: return
	_pv = Progress.version; _case = cid; _seen_gen = _gen; _night = nt
	refresh()

# 모두 다시 보고, 바뀐 항목만 알린다
func refresh() -> void:
	refreshes += 1
	for key in _items.keys():
		if not _items.has(key): continue
		var it: Dictionary = _items[key]
		var on := eval(it.when, it.case)
		if it.on != null and bool(it.on) == on: continue
		it.on = on
		for cb in it.cbs:
			if cb.is_valid(): cb.call(on)

static func _norm(when) -> String:
	if when == null: return ""
	if when is bool: return "" if when else "false"
	return String(when).strip_edges()

func eval(when, case_id := "") -> bool:
	var s := _norm(when)
	if s == "" or s == "true": return true
	if s == "false": return false
	var ex: Expression = _exprs.get(s)
	if ex == null:
		ex = Expression.new()
		if ex.parse(s) != OK:
			if not _bad.has(s): push_warning("배치 조건식 오류: %s — %s" % [s, ex.get_error_text()]); _bad[s] = true
			return false
		_exprs[s] = ex
	_cur = case_id
	evals += 1
	var r = ex.execute([], self, false)
	if ex.has_execute_failed():
		if not _bad.has(s): push_warning("배치 조건식 실행 실패: " + s); _bad[s] = true
		return false
	return bool(r)

# ---- 상태 읽기 ----
func _story():
	return main.get("story") if main != null else null

func _active_case() -> String:
	if fake is Dictionary: return String(fake.get("case_id", ""))
	var st = _story()
	return String(st.case_id) if st != null else ""

func _cstate(id: String) -> Dictionary:
	if id == "": id = _active_case()
	if fake is Dictionary:
		var c = (fake.get("cases", {}) as Dictionary).get(id)
		return c if c is Dictionary else {}
	var st = _story()
	if st != null and st.S != null and String(st.case_id) == id:
		return { phase = st.S.phase, flags = st.S.flags, world = st.S.world }
	return Progress.case_state(id)

func _hour() -> float:
	if fake is Dictionary and fake.has("hour"): return float(fake.hour)
	return float(main.hour) if main != null else 12.0

func _is_night() -> bool:
	var h := _hour()
	return h >= 19.0 or h < 5.0

# ---- 조건식에서 부르는 짧은 이름(이야기 DSL과 같은 이름) ----
func ph(p: String) -> bool: return String(_cstate(_cur).get("phase", "")) == p
func f(k: String) -> bool: return bool((_cstate(_cur).get("flags", {}) as Dictionary).get(k, false))
func w(k: String) -> bool: return bool((_cstate(_cur).get("world", {}) as Dictionary).get(k, false))
func active(id: String) -> bool: return _active_case() == id
func night() -> bool: return _is_night()
func v(name: String):
	if fake is Dictionary:
		var fv: Dictionary = fake.get("vars", {})
		return fv.get(name, StoryState.VAR_DEFAULTS.get(name))
	var st = _story()
	if st != null and st.S != null: return st.S.vars.get(name, StoryState.VAR_DEFAULTS.get(name))
	return Progress.get_var(name, StoryState.VAR_DEFAULTS.get(name))
func fn(name: String, a = null):
	var st = _story()
	if fake == null and st != null and st.case_fn != null and String(st.case_id) == (_cur if _cur != "" else String(st.case_id)) and st.case_fn.has_method(name):
		return st.case_fn.call(name) if a == null else st.case_fn.call(name, a)
	if name == "is_night": return _is_night()
	return null
