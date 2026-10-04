# 진행 저장 파일 — user://progress.json (시험: --savefile=user://다른.json)
# {
#   "version": 2,
#   "routes_done": { "<노정 id>": "2026-10-04T12:00:00" },   ← 노정을 끝에서 끝까지 지나가면(역마로 건너뛰기, region_main H 키)
#   "vars":  { MAIN_MASTER_TRACE, CASE_NAMWON_OUTCOME, SKILL_BEAST_TRACE … },   ← 시나리오 §7 공통 상태 변수(사건을 넘어 남는 값)
#   "cases": { "namwon": { phase, flags, clues, rules, items, world, talked, notes, time, seen } },   ← 사건별 진행(scripts/story)
#   "where": { space, kind, x, z, hour },   ← 이어 하기 자리(story_director가 10초마다·저장할 때)
#   "saved_at": "…"
# }
# 버전 1(routes_done만) 파일도 그대로 읽는다.
extends RefCounted

const DEFAULT_PATH := "user://progress.json"
static var path := DEFAULT_PATH
static var _d = null

static func data() -> Dictionary:
	if _d == null:
		_d = {}
		if FileAccess.file_exists(path):
			var j = JSON.parse_string(FileAccess.get_file_as_string(path))
			if j is Dictionary: _d = j
		if not (_d.get("routes_done") is Dictionary): _d["routes_done"] = {}
		if not (_d.get("vars") is Dictionary): _d["vars"] = {}
		if not (_d.get("cases") is Dictionary): _d["cases"] = {}
		_d["version"] = 2
	return _d

# 다른 저장 파일 쓰기(시험). 읽어 둔 것을 버린다
static func use_path(p: String) -> void:
	path = p if p != "" else DEFAULT_PATH
	_d = null

static func save() -> void:
	var d := data()
	d["saved_at"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, " "))
		f.close()

static func route_done(id: String) -> bool:
	return data().routes_done.has(id)

static func mark_route_done(id: String) -> void:
	if id == "" or route_done(id): return
	data().routes_done[id] = Time.get_datetime_string_from_system()
	save()
	print("PROGRESS route_done ", id)

# ---- 공통 상태 변수(§7) ----
static func get_var(k: String, dflt = null):
	return data().vars.get(k, dflt)

static func set_var(k: String, v) -> void:
	data().vars[k] = v

static func vars() -> Dictionary:
	return data().vars

# ---- 사건 진행 ----
static func case_state(id: String) -> Dictionary:
	var c = data().cases.get(id)
	return c if c is Dictionary else {}

static func save_case(id: String, st: Dictionary, v: Dictionary) -> void:
	data().cases[id] = st
	data().vars.merge(v, true)
	save()

# ---- 이어 하기 자리·새 게임 ----
static func where() -> Dictionary:
	var w = data().get("where")
	return w if w is Dictionary else {}

static func set_where(w: Dictionary) -> void:
	data()["where"] = w
	save()

static func has_save() -> bool:
	return not data().cases.is_empty() or not where().is_empty()

static func reset_all() -> void:
	_d = { "version": 2, "routes_done": {}, "vars": {}, "cases": {} }
	save()

static func clear_case(id: String) -> void:
	data().cases.erase(id)
	save()
