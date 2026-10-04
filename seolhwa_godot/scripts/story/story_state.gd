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

func clear_saved() -> void:
	Progress.clear_case(case_id)
	# 이 사건이 정한 공통 변수도 되돌린다(새로 시작)
	for k in ["CASE_NAMWON_OUTCOME", "MAIN_MASTER_TRACE", "SKILL_BEAST_TRACE"]:
		Progress.set_var(k, VAR_DEFAULTS[k])
		vars[k] = VAR_DEFAULTS[k]
	Progress.save()

# ---- 읽기 ----
func is_flag(k: String) -> bool: return bool(flags.get(k, false))
func count(item: String) -> int: return int(items.get(item, 0))
func has(item: String, n := 1) -> bool: return count(item) >= n
func has_clue(id: String) -> bool: return clues.has(id)
func knows(id: String) -> bool: return rules.has(id)
