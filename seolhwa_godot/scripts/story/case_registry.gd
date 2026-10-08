# 사건 등록부 — 공간(권역·노정 id) 하나에 독립 사건 여러 개를 올리는 최소 층(예전 story_director CASES 자리).
#   SPACE_CASES: 공간 → 사건 id 목록(앞의 것이 먼저). 지금은 공간마다 기존 사건 하나 — 예전 CASES와 똑같다.
#   한 사건이 여러 공간에 걸치면 같은 사건 id를 여러 공간에 올린다(진행은 progress cases.<id> 하나).
#   사건 파일: dir_of(id) = res://story/<id>/ 의 <id>_data.gd · <id>_case.gd(· 시험 <id>_test.gd). 파일이 없는 id는 건너뛴다(불러오지 않는다).
#   사건마다 따로: 상태 cases.<id>(story_state) · 완료 변수 CASE_<case.complete_key 또는 ID 대문자>_COMPLETE(skills.gd) · 결말 변수 case.outcome_var.
#   한 공간에서 한 번에 도는 사건은 하나(StoryRunner 하나) — choose()가 고른다:
#     요구(case.requires)가 맞는 것 중 아직 안 끝난(phase != done) 첫 사건 → 없으면 요구가 맞는 첫 사건 → 없으면 ""(소문만).
# 새 사건 더하기(예: 남원 namwon_chunhyang): story/namwon_chunhyang/ 에 데이터·사건 스크립트를 만들고 SPACE_CASES의 목록 뒤에 id를 더한다.
# 시험(tests/registry)은 register()로 다른 폴더의 가짜 사건을 잠깐 올린다 — 놀이 콘텐츠에는 나오지 않는다.
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")

const SPACE_CASES := {
	"JL_NAMWON_UNBONG": ["namwon"],
	"GG_HANYANG": ["hanyang"],
	"GW_GANGNEUNG": ["gangneung"],
	"GS_GYEONGJU": ["gyeongju"],
	"HH_HWANGJU": ["hwangju"], "HH_HWANGJU-JANGSANGOT": ["hwangju"],
	"PA_PYEONGYANG": ["pyongyang"],
	"PA_PYEONGYANG-HG_HAMHEUNG": ["hamhung"], "HG_HAMHEUNG": ["hamhung"], "HG_HAMHEUNG-BUKCHEONG": ["hamhung"],
	"SEA_NAMHAE_JEJU": ["jeju"], "JJ_JEJU": ["jeju"],
}

static var _extra := {}   # 시험용 추가 등록: 공간 → [id]
static var _dirs := {}    # 시험용 사건 폴더: id → "res://…/"
static var _warned := {}

# ---- 시험용 등록(놀이 중에는 쓰지 않는다) ----
static func register(space: String, id: String, dir := "") -> void:
	var l: Array = _extra.get(space, [])
	if not l.has(id): l.append(id)
	_extra[space] = l
	if dir != "": _dirs[id] = dir if dir.ends_with("/") else dir + "/"

static func clear_extra() -> void:
	_extra = {}; _dirs = {}; _warned = {}

# ---- 파일 자리 ----
static func dir_of(id: String) -> String:
	return String(_dirs.get(id, "res://story/%s/" % id))

static func data_path(id: String) -> String: return dir_of(id) + id + "_data.gd"
static func case_path(id: String) -> String: return dir_of(id) + id + "_case.gd"
static func test_path(id: String) -> String: return dir_of(id) + id + "_test.gd"

static func has_data(id: String) -> bool:
	return id != "" and ResourceLoader.exists(data_path(id))

# 돌릴 수 있는 사건(데이터와 사건 스크립트가 다 있음)
static func exists(id: String) -> bool:
	return has_data(id) and ResourceLoader.exists(case_path(id))

# ---- 목록 ----
# 공간에 올린 id(파일 확인 전, 순서대로, 겹침 없이)
static func ids_for(space: String) -> Array:
	var out: Array = []
	for id in SPACE_CASES.get(space, []) + _extra.get(space, []):
		if not out.has(id): out.append(id)
	return out

# 공간에서 돌릴 수 있는 사건 — 파일이 없는 id는 한 번 알리고 건너뛴다
static func cases_for(space: String) -> Array:
	var out: Array = []
	for id in ids_for(space):
		if exists(String(id)): out.append(String(id))
		elif not _warned.has(id):
			_warned[id] = true
			printerr("CASEREG 사건 파일 없음 — 건너뜀: %s (%s)" % [id, space])
	return out

# 등록된 모든 사건 id(데이터가 있는 것만, 처음 나온 순서)
static func all_ids() -> Array:
	var out: Array = []
	var spaces: Array = SPACE_CASES.keys() + _extra.keys()
	for sp in spaces:
		for id in ids_for(String(sp)):
			if not out.has(id) and has_data(String(id)): out.append(String(id))
	return out

# 사건 데이터(<id>_data.gd의 data()) — 없거나 못 읽으면 {}
static func load_data(id: String) -> Dictionary:
	if not has_data(id): return {}
	var s = load(data_path(id))
	if s == null or not (s is Script) or not s.can_instantiate(): return {}
	var d = s.data()
	return d if d is Dictionary else {}

# ---- 고르기 ----
# case.requires {변수: 값} — 쉼표 목록 값(MAIN_MASTER_TRACE "HANYANG,GANGNEUNG")은 들어 있으면 맞음. 안 맞는 첫 변수 이름(맞으면 "")
static func unmet_key(case_head: Dictionary, vars_over = null) -> String:
	var req = case_head.get("requires", {})
	if not (req is Dictionary): return ""
	for k in req:
		var have := str(vars_over.get(k, "") if vars_over is Dictionary else Progress.get_var(k, ""))
		var want := str(req[k])
		if have != want and not have.split(",").has(want): return String(k)
	return ""

static func requires_met(case_head: Dictionary, vars_over = null) -> bool:
	return unmet_key(case_head, vars_over) == ""

# 후보 중 지금 돌릴 사건 하나 — { id, data(그 사건 데이터), why_id, why_key }. id ""이면 why_* = 첫 후보와 그 안 맞는 요구 변수
static func choose(cands: Array, vars_over = null) -> Dictionary:
	var met: Array = []
	var why_id := ""; var why_key := ""
	for id in cands:
		var dd := load_data(String(id))
		if dd.is_empty(): continue
		var k := unmet_key(dd.get("case", {}), vars_over)
		if k == "": met.append([String(id), dd])
		elif why_id == "": why_id = String(id); why_key = k
	for m in met:
		if String(Progress.case_state(m[0]).get("phase", "start")) != "done": return { id = m[0], data = m[1], why_id = "", why_key = "" }
	if not met.is_empty(): return { id = met[0][0], data = met[0][1], why_id = "", why_key = "" }
	return { id = "", data = {}, why_id = why_id, why_key = why_key }
