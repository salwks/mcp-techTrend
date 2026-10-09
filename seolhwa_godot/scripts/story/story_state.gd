# 이야기 상태 — 사건 하나의 진행(phase·flags·clues·rules·items·world·talked·notes)과 공통 상태 변수(시나리오 §7).
# 저장은 progress.gd(user://progress.json의 cases.<id> 와 vars).
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")

# §7 공통 상태 변수(기본값). 점수 값은 내부값이며 플레이어에게 보이지 않는다.
const VAR_DEFAULTS := {
	MAIN_MASTER_TRACE = "", MAIN_WOOCHI_KNOWN = false, MAIN_PAST_EVENT_KNOWN = false, MAIN_GWAK_NAME_KNOWN = false,
	MAIN_GWAK_FOUND = false, MAIN_MASTER_FOUND = false,
	CASE_NAMWON_OUTCOME = "", CASE_GANGNEUNG_OUTCOME = "", CASE_GYEONGJU_OUTCOME = "", CASE_HWANGJU_OUTCOME = "",
	CASE_PYONGYANG_OUTCOME = "", CASE_HAMHUNG_OUTCOME = "", CASE_JEJU_OUTCOME = "",
	SKILL_BEAST_TRACE = false, ITEM_TALISMAN_SLOT = 0, SKILL_RUBBING = false, SKILL_DOCUMENT_CHECK = false, ITEM_SENSING_KNOT = false,
	FINAL_EVIDENCE_SCORE = 0, FINAL_CIVILIAN_HARM = 0, FINAL_WOOCHI_METHOD = 0, FINAL_SPIRIT_RESOLVED = false,
	FINAL_CRIME_RESOLVED = false, FINAL_PUBLIC_EXPOSURE = false,
	# 구현용(시나리오 §10 S1006·§14): 세 갈래(ACT 2) 열림, 평양(ACT 3) 열림, 한양 추격 결과(followed | lost)
	ACT2_OPEN = false, ACT3_OPEN = false, CASE_HANYANG_OUTCOME = "",
	# v2.2: 박규상 표식을 본 횟수·이름을 앎(§7 추가), 전투 숙련 P0(받아밀기 — 남원 v3.2 결정 2로 아직 여는 사건 없음, 빠른 투척 — 한양 뒤)
	MAIN_PARK_MARK_COUNT = 0, MAIN_PARK_NAME_KNOWN = false,
	SKILL_GUARD_SHOVE = false, SKILL_QUICK_THROW = false, SKILL_EVADE_SLASH = false, SKILL_SNAP_SHOT = false,
	SKILL_BEAST_SIDESTEP = false, SKILL_TOOL_SLOT_PLUS = false,   # 해금표 scripts/story/skills.gd(CASE_<키>_COMPLETE)
	CASE_NAMWON_COMPLETE = false, CASE_HANYANG_BOOKSHOP_COMPLETE = false, CASE_GANGNEUNG_COMPLETE = false, CASE_GYEONGJU_COMPLETE = false,
	CASE_HWANGJU_COMPLETE = false, CASE_PYONGYANG_COMPLETE = false, CASE_HAMHUNG_COMPLETE = false, CASE_JEJU_COMPLETE = false,
	# 제주(§7 ITEM_KEY_001 — 강복의 곡물 수량패), 플레이어의 첫 문장(S7008), 최종장 문(ACT 2~5 모두 끝 — 한양 귀환)
	ITEM_KEY_001 = false, PLAYER_FIRST_LINE = "", ACT6_OPEN = false,
	# v2.4 §17 함흥: S6011 돌아온 전갈꾼 수(3/2/1 — 0은 아직), S6009 조사 카드 「서강의 두 필체」를 봄(최종장 S8003·S8004 복선)
	HAMHUNG_MESSENGERS_RETURNED = 0, HAMHUNG_SEOGANG_CARD_SEEN = false,
}

var case_id := ""
var phase := "start"
var flags := {}
var clues: Array = []
var rules: Array = []
var items := {}
var world := {}
var talked := {}
var notes: Array = []
var seen := {}
var time := 10.0
var vars := {}

func _init(id := "") -> void:
	case_id = id
	reset()

func reset() -> void:
	phase = "start"
	flags = {}; clues = []; rules = []; items = {}; world = {}; talked = {}; notes = []; seen = {}
	time = 10.0
	vars = VAR_DEFAULTS.duplicate()
	vars.merge(Progress.vars(), true)

func to_dict() -> Dictionary:
	return { v = 2, phase = phase, flags = flags, clues = clues, rules = rules, items = items, world = world,
		talked = talked, notes = notes, seen = seen, time = time }

func from_dict(d: Dictionary) -> bool:
	if d.is_empty() or not d.has("flags"): return false
	phase = String(d.get("phase", "start"))
	flags = d.get("flags", {}); clues = d.get("clues", []); rules = d.get("rules", [])
	items = d.get("items", {}); world = d.get("world", {}); talked = d.get("talked", {})
	notes = d.get("notes", []); seen = d.get("seen", {}); time = float(d.get("time", 10.0))
	for k in items: items[k] = int(items[k])
	return true

func save() -> void:
	if case_id == "": return
	Progress.save_case(case_id, to_dict(), vars)

func load_saved() -> bool:
	return from_dict(Progress.case_state(case_id))

func clear_saved(keys = null) -> void:
	Progress.clear_case(case_id)
	# 이 사건이 정한 공통 변수도 되돌린다(새로 시작). keys: 사건 데이터 case.reset_vars(없으면 남원은 남원 것, 다른 사건은 없음 —
	# 한 공간의 다른 사건이 남원 완료·흔적 변수를 지우지 않게)
	if keys == null: keys = ["CASE_NAMWON_OUTCOME", "MAIN_MASTER_TRACE", "SKILL_BEAST_TRACE", "SKILL_GUARD_SHOVE", "CASE_NAMWON_COMPLETE"] if case_id == "namwon" else []
	for k in keys:
		Progress.set_var(k, VAR_DEFAULTS.get(k, ""))
		vars[k] = VAR_DEFAULTS.get(k, "")
	Progress.save()

# ---- 읽기 ----
func is_flag(k: String) -> bool: return bool(flags.get(k, false))
func count(item: String) -> int: return int(items.get(item, 0))
func has(item: String, n := 1) -> bool: return count(item) >= n
func has_clue(id: String) -> bool: return clues.has(id)
func knows(id: String) -> bool: return rules.has(id)
