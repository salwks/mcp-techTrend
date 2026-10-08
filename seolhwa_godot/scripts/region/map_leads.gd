# 지도 사건 표지(붉은 인) — 사건 데이터 story/<사건>/<사건>_data.gd의 "map_leads"(보강서 §20: 아는 것만, 알아낼 것은 아니다).
#   항목: { id, name(지도 글), at(앵커 이름·인물 id·[x,z]), when(조건식 — 참이면 보임), until(조건식 — 참이면 사라짐),
#           space(그 자리가 있는 공간 id, 기본 case.region), region(다른 권역을 가리킴 — 전국 지도에 그 권역 자리로), hub(true: 사건 거점), note }
#   조건식: story_runner와 같은 짧은 이름 — f c k ph v seen talked w out has n (fn은 쓰지 않는다: 지금 돌지 않는 사건은 저장만 보고 셈한다).
#   지금 공간의 사건(story_director)은 그 runner.cond·anchor로, 나머지는 progress.json 사건 상태로 센다. case.requires가 안 맞으면 아무것도 없다.
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")
const CaseRegistry := preload("res://scripts/story/case_registry.gd")   # 사건 목록(한 공간에 여럿이어도 사건마다 따로 센다 — 표지는 case id로 갈린다)

static var _cases = null

# 사건마다 {id, title, region, requires, outcome_var, leads, anchors} — 처음 한 번 읽는다
static func cases() -> Array:
	if _cases != null: return _cases
	var out: Array = []
	for id in CaseRegistry.all_ids():
		var d := CaseRegistry.load_data(String(id))
		if d.is_empty(): continue
		var cs: Dictionary = d.get("case", {})
		var leads = d.get("map_leads", [])
		out.append({ id = id, title = String(cs.get("record_title", id)), region = String(cs.get("region", "")),
			requires = cs.get("requires", {}), outcome_var = String(cs.get("outcome_var", "")),
			leads = leads if leads is Array else [], anchors = d.get("anchors", {}) })
	_cases = out
	return out

# 저장만 보고 조건식을 세는 작은 셈꾼(story_runner의 짧은 이름과 같다)
class Ev:
	extends RefCounted
	var st: Dictionary = {}
	var vars: Dictionary = {}
	var outv := ""
	var _ex := {}
	func f(key: String) -> bool: return bool((st.get("flags", {}) as Dictionary).get(key, false))
	func c(id: String) -> bool: return (st.get("clues", []) as Array).has(id)
	func k(id: String) -> bool: return (st.get("rules", []) as Array).has(id)
	func ph(p: String) -> bool: return String(st.get("phase", "start")) == p
	func v(name: String): return vars.get(name)
	func seen(id: String) -> bool: return (st.get("seen", {}) as Dictionary).has(id)
	func talked(id: String) -> int: return int((st.get("talked", {}) as Dictionary).get(id, 0))
	func w(key: String) -> bool: return bool((st.get("world", {}) as Dictionary).get(key, false))
	func out(o: String) -> bool: return String(vars.get(outv, "")) == o
	func n(item: String) -> int: return int((st.get("items", {}) as Dictionary).get(item, 0))
	func has(item: String, nn := 1) -> bool: return n(item) >= nn
	func fn(_name: String, _a = null): return null
	func cond(e) -> bool:
		if e == null: return true
		if e is bool: return e
		var s := String(e).strip_edges()
		if s == "": return true
		var ex: Expression = _ex.get(s)
		if ex == null:
			ex = Expression.new()
			if ex.parse(s) != OK: return false
			_ex[s] = ex
		var r = ex.execute([], self, false)
		if ex.has_execute_failed(): return false
		return bool(r)

static func requires_met(c: Dictionary) -> bool:
	var req = c.get("requires", {})
	if not (req is Dictionary): return true
	for k in req:
		var have := str(Progress.get_var(k, ""))
		var want := str(req[k])
		if have != want and not have.split(",").has(want): return false
	return true

# 보이는 표지 [{case, title, id, name, space, region, hub, pos(Vector2 또는 null), at}]
#   director: 지금 사건(story_director) — 있으면 그 사건은 runner.cond·anchor로 센다. state: 시험용 {사건 id: 상태}(없으면 저장)
static func visible(director = null, state_over: Dictionary = {}, vars_over = null) -> Array:
	var out: Array = []
	var act_id := ""
	if director != null and "case_id" in director and director.runner != null: act_id = String(director.case_id)
	for c in cases():
		var live: bool = String(c.id) == act_id and state_over.is_empty()
		if not live and not requires_met_with(c, vars_over): continue
		var ev: Ev = null
		if not live:
			ev = Ev.new()
			ev.st = state_over.get(c.id, Progress.case_state(String(c.id))) if not state_over.is_empty() else Progress.case_state(String(c.id))
			ev.vars = vars_over if vars_over is Dictionary else Progress.vars()
			ev.outv = String(c.outcome_var)
		for l in c.leads:
			if not (l is Dictionary): continue
			var ok: bool = director.runner.cond(l.get("when", true)) if live else ev.cond(l.get("when", true))
			if ok and l.has("until"): ok = not (director.runner.cond(l.until) if live else ev.cond(l.until))
			if not ok: continue
			var e := { case = String(c.id), title = String(c.title), id = String(l.get("id", "")), name = String(l.get("name", "")),
				space = String(l.get("space", c.region)), region = String(l.get("region", "")), hub = bool(l.get("hub", false)), pos = null, at = l.get("at") }
			if l.has("at"):
				if live and e.space == String(director.space_id): e.pos = director.anchor(l.at)
				else: e.pos = anchor_of(l.at, c.anchors, String(ev.st.get("phase", "start")) if ev != null else "start")
			out.append(e)
	return out

static func requires_met_with(c: Dictionary, vars_over) -> bool:
	if not (vars_over is Dictionary): return requires_met(c)
	var req = c.get("requires", {})
	if not (req is Dictionary): return true
	for k in req:
		var have := str(vars_over.get(k, ""))
		var want := str(req[k])
		if have != want and not have.split(",").has(want): return false
	return true

# 앵커 풀기(story_director.anchor와 같은 규칙 — 인물 id는 모른다)
static func anchor_of(at, anchors: Dictionary, phase: String, depth := 0):
	if depth > 6: return null
	if at is Vector2: return at
	if at is Array and at.size() >= 2: return Vector2(float(at[0]), float(at[1]))
	if at is Dictionary:
		if at.has("x"): return Vector2(float(at.x), float(at.get("z", at.get("y", 0.0))))
		return anchor_of(at.get(phase, at.get("default", null)), anchors, phase, depth + 1)
	if at is String and anchors.has(at): return anchor_of(anchors[at], anchors, phase, depth + 1)
	return null
