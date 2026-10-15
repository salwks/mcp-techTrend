# 사건 등록부 — 공간(권역·노정 id) 하나에 독립 사건 여러 개를 올리는 최소 층(예전 story_director CASES 자리).
#   SPACE_CASES: 공간 → 사건 id 목록(앞의 것이 먼저). 지금은 공간마다 기존 사건 하나 — 예전 CASES와 똑같다.
#   한 사건이 여러 공간에 걸치면 같은 사건 id를 여러 공간에 올린다(진행은 progress cases.<id> 하나).
#   사건 파일: dir_of(id) = res://story/<id>/ 의 <id>_data.gd · <id>_case.gd(· 시험 <id>_test.gd). 파일이 없는 id는 건너뛴다(불러오지 않는다).
#   사건마다 따로: 상태 cases.<id>(story_state) · 완료 변수 CASE_<case.complete_key 또는 ID 대문자>_COMPLETE(skills.gd) · 결말 변수 case.outcome_var.
#   한 공간에서 한 번에 도는 사건은 하나(StoryRunner 하나) — choose()가 고른다(재기획 3단계 D1·D3, 요구 case.requires가 맞는 것만):
#     ① 진행 중인 독립 사건(phase가 start·done 아님, 메인 아님) — 옛 저장의 오누이·춘향 도중은 그 사건을 이어 한다(추가 지시 2)
#     ② 진행 중인 메인(case.main) — 쉬는 자리(case.rest_flag가 선 저장)가 아니면
#     ③ 아직 안 끝난 독립 사건 가운데 스스로 서는 것(case.entry가 "trigger"가 아님 — 춘향처럼 고을에 들면 서는 사건)
#     ④ 아직 안 끝난 메인
#     ⑤ 요구가 맞는 첫 사건(들머리 트리거 사건은 뒤로) → 없으면 ""(소문만).
#   들머리 트리거 사건(case.entry "trigger" — 남원 오누이): 스스로 고르지 않는다. 메인 사건의 들머리(행상 등)가 story_director.switch_case로 세운다.
# 새 사건 더하기(예: 남원 namwon_chunhyang): story/namwon_chunhyang/ 에 데이터·사건 스크립트를 만들고 SPACE_CASES의 목록 뒤에 id를 더한다.
# 시험(tests/registry)은 register()로 다른 폴더의 가짜 사건을 잠깐 올린다 — 놀이 콘텐츠에는 나오지 않는다.
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")
const Problems := preload("res://scripts/story/problems.gd")   # 사건 데이터의 problems → 조사 대상·트리거·기록(불러올 때 한 번)

const SPACE_CASES := {
	# 재기획 3단계(D1·D3): 메인 서장 main_p1(이겸의 편지 — 새 게임)이 먼저. 오누이(namwon)는 북쪽 길목 행상에서 들어가는 선택 사건(entry trigger),
	#   춘향(PART I 진입: 한양 책방 완료 — 오누이 완료 요구는 뗐다)
	"JL_NAMWON_UNBONG": ["main_p1", "namwon", "namwon_chunhyang"],
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
	return Problems.expand(d) if d is Dictionary else {}

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

# 후보 중 지금 돌릴 사건 하나 — { id, data(그 사건 데이터), why_id, why_key, rule }. id ""이면 why_* = 첫 후보와 그 안 맞는 요구 변수
#   rule: 고른 규칙 번호(1~5 — 머리말) · 시험·로그용
static func choose(cands: Array, vars_over = null) -> Dictionary:
	var met: Array = []
	var why_id := ""; var why_key := ""
	for id in cands:
		var dd := load_data(String(id))
		if dd.is_empty(): continue
		var k := unmet_key(dd.get("case", {}), vars_over)
		if k == "": met.append([String(id), dd])
		elif why_id == "": why_id = String(id); why_key = k
	var pick := func(m: Array, rule: int) -> Dictionary: return { id = m[0], data = m[1], why_id = "", why_key = "", rule = rule }
	for m in met:   # ① 진행 중인 독립 사건
		if not is_main(m[1]) and _phase(m[0]) not in ["start", "done"]: return pick.call(m, 1)
	for m in met:   # ② 진행 중인 메인(쉬는 자리 아님)
		if is_main(m[1]) and _phase(m[0]) not in ["start", "done"] and not resting(m[0], m[1]): return pick.call(m, 2)
	for m in met:   # ③ 스스로 서는 독립 사건(아직 안 끝남)
		if not is_main(m[1]) and not is_trigger_entry(m[1]) and _phase(m[0]) != "done": return pick.call(m, 3)
	for m in met:   # ④ 아직 안 끝난 메인
		if is_main(m[1]) and _phase(m[0]) != "done": return pick.call(m, 4)
	for m in met:   # ⑤ 요구가 맞는 첫 사건(들머리 트리거 사건은 뒤로)
		if not is_trigger_entry(m[1]): return pick.call(m, 5)
	if not met.is_empty(): return pick.call(met[0], 5)
	return { id = "", data = {}, why_id = why_id, why_key = why_key, rule = 0 }

static func _phase(id: String) -> String:
	return String(Progress.case_state(id).get("phase", "start"))

# 메인 사건(case.main) — 독립 설화보다 뒤에 고른다(진행 중 독립 사건이 먼저)
static func is_main(dd: Dictionary) -> bool:
	return bool(dd.get("case", {}).get("main", false))

# 들머리 트리거로만 서는 사건(case.entry "trigger") — 스스로 고르지 않는다
static func is_trigger_entry(dd: Dictionary) -> bool:
	return String(dd.get("case", {}).get("entry", "")) == "trigger"

# 메인이 쉬는 자리(case.rest_flag가 저장된 깃발에 섰다) — 그동안은 스스로 서는 독립 사건이 먼저
static func resting(id: String, dd: Dictionary) -> bool:
	var rf := String(dd.get("case", {}).get("rest_flag", ""))
	if rf == "": return false
	return bool((Progress.case_state(id).get("flags", {}) as Dictionary).get(rf, false))
