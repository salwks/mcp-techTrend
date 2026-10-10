# 새 사건 필수 메타 검사(제작 규칙 v1.0 C46 — 최소판, F-5 전체 검사기 아님). 헤드리스, validate_event_class.gd와 나란히 돌린다.
#   godot --headless --path . -s res://tools/story/validate_case_meta.gd
#   등록부(scripts/story/case_registry.gd)에 오른 모든 사건의 사건 머리(<id>_data.gd data().case)에 다음 키가 있어야 한다:
#     id · record_title · region · outcome_var · reset_vars · requires · EVENT_CLASS · SOURCE_ID
#     (requires는 비어 있어도 되지만 키는 있어야 한다. id는 등록 id와 같아야 하고, reset_vars는 목록 또는 사전, requires는 사전)
#   경고(실패 아님): 남원 값이 공통 기본값으로 새는 자리 — 남원이 아닌 사건에
#     rule_label이 없으면 기록·알림에 "범의 버릇"이 뜬다(story_director·journal_book 기본값)
#     싸움터(arenas)가 있는데 combat_bait_item이 없으면 떡(ITM_LIFE_001)을 던진다(story_director.combat 기본값)
#   끝 줄: CASEMETA PASS n warn=w / CASEMETA FAIL n
extends SceneTree

const CaseRegistry := preload("res://scripts/story/case_registry.gd")
const REQUIRED := ["id", "record_title", "region", "outcome_var", "reset_vars", "requires", "EVENT_CLASS", "SOURCE_ID"]
const NAMWON_DEFAULTS_OWNER := "namwon"   # 남원 기본값(범의 버릇·떡)의 주인 — 이 사건에는 경고하지 않는다

var fails := 0
var warns := 0
var n := 0

func _fail(where: String, msg: String) -> void:
	fails += 1
	print("FAIL %s: %s" % [where, msg])

func _warn(where: String, msg: String) -> void:
	warns += 1
	print("WARN %s: %s" % [where, msg])

# 사건 데이터 하나를 본다 — 실패 문구 목록과 경고 목록을 돌려준다(시험도 쓴다)
static func check(id: String, data: Dictionary) -> Dictionary:
	var f: Array = []; var w: Array = []
	var head = data.get("case")
	if not (head is Dictionary): return { fails = ["사건 머리(case) 없음"], warns = [] }
	for k in REQUIRED:
		if not head.has(k): f.append("필수 키 없음: " + k)
		elif k != "requires" and k != "reset_vars" and String(head[k]) == "": f.append("빈 값: " + k)
	if head.has("id") and String(head.id) != id: f.append("id '%s' ≠ 등록 id '%s'" % [head.id, id])
	# reset_vars: 목록, 또는 {변수: …} 사전(story_state.clear_saved는 키를 돌며 기본값으로 되돌린다 — 강릉·경주가 사전 꼴)
	if head.has("reset_vars") and not (head.reset_vars is Array or head.reset_vars is Dictionary): f.append("reset_vars가 목록·사전이 아님")
	if head.has("requires") and not (head.requires is Dictionary): f.append("requires가 사전이 아님")
	if id != NAMWON_DEFAULTS_OWNER:
		if not head.has("rule_label"): w.append("rule_label 없음 — 기록·알림에 남원 기본값 \"범의 버릇\"이 뜬다")
		if not (data.get("arenas", {}) as Dictionary).is_empty() and not data.has("combat_bait_item"):
			w.append("싸움터가 있는데 combat_bait_item 없음 — 남원 기본값 떡(ITM_LIFE_001)을 던진다")
	return { fails = f, warns = w }

func _init() -> void:
	# 검사기 자체가 막아야 할 것을 막는지
	var bad := check("x", { "case": { "id": "x", "record_title": "t", "region": "R", "outcome_var": "O", "reset_vars": [], "EVENT_CLASS": "FOLKLORE_EVENT", "SOURCE_ID": "F1" } })
	if not (bad.fails as Array).has("필수 키 없음: requires"): _fail("self", "requires 없는 사건이 통과함")
	var leak := check("x", { "case": { "id": "x" }, "arenas": { "a": {} } })
	if (leak.warns as Array).size() != 2: _fail("self", "남원 기본값 새는 자리 경고가 둘이 아님")
	for id in CaseRegistry.all_ids():
		n += 1
		var data := CaseRegistry.load_data(String(id))
		if data.is_empty(): _fail(id, "데이터 못 읽음 " + CaseRegistry.data_path(id)); continue
		var r := check(String(id), data)
		for e in r.fails: _fail(id, e)
		for e in r.warns: _warn(id, e)
		print("CASE %s %s" % [id, "ok" if (r.fails as Array).is_empty() else "FAIL"])
	if fails == 0: print("CASEMETA PASS %d warn=%d" % [n, warns])
	else: print("CASEMETA FAIL %d" % fails)
	quit(0 if fails == 0 else 1)
