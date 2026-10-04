# 진행 저장 파일 — user://progress.json (시험: --savefile=user://다른.json)
# {
#   "version": 2,
#   "routes_done": { "<노정 id>": "2026-10-04T12:00:00" },   ← 노정을 끝에서 끝까지 지나가면(역마로 건너뛰기, region_main H 키)
#   "vars":  { MAIN_MASTER_TRACE, CASE_NAMWON_OUTCOME, SKILL_BEAST_TRACE … },   ← 시나리오 §7 공통 상태 변수(사건을 넘어 남는 값)
#   "cases": { "namwon": { phase, flags, clues, rules, items, world, talked, notes, time, seen } },   ← 사건별 진행(scripts/story)
#   "where": { space, kind, x, z, hour },   ← 이어 하기 자리(story_director가 10초마다·저장할 때)
#   "onboard": { ONBOARD_MOVE_SEEN: true, PLAY_TIME: 812.0 … },   ← 처음 한 번 안내(scripts/story/onboarding.gd) — 사건을 넘어 남는다
#   "known": { "<공간 id>": { "<장소 키>": "visited" | "told" }, "_nation": {…} },   ← 지도에 적힌 곳(scripts/region/discovery.gd)
#   "heard": [{ id, space, by, text, place }],   ← 사람에게 들은 소문(기록책 '사람의 말' — ◇ 들음 — 말한 사람, 사실로 올리지 않는다)
#   "meta": { place, case, hour, play, reason },   ← 저장 칸 목록에 보일 것(지금 고을·사건·게임 안 시각·놀이 시간·까닭)
#   "saved_at": "…"
# }
# 저장 칸: 이 파일(path)이 곧 자동 기록 칸(0)이다 — 늘 지금 진행. 손으로 남기는 칸 1~3은 같은 자리 <이름>_slot<n>.json(+ 작은 그림 .png).
#   checkpoint(까닭) — 뜻있는 때(고을에 들어섬·사건이 나아감·길 떠나기 전) 자동 기록 + on_checkpoint(story_ui 붓 도장 '기록을 남겼다')
#   save_slot(n, 그림) · load_slot(n)(칸 내용을 지금 진행으로 덮는다) · slot_info(n) · latest_slot()
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
		if not (_d.get("onboard") is Dictionary): _d["onboard"] = {}
		if not (_d.get("known") is Dictionary): _d["known"] = {}
		if not (_d.get("heard") is Array): _d["heard"] = []
		_d["version"] = 2
	return _d

# 다른 저장 파일 쓰기(시험). 읽어 둔 것을 버린다
static func use_path(p: String) -> void:
	path = p if p != "" else DEFAULT_PATH
	_d = null

static func save() -> void:
	var d := data()
	d["saved_at"] = Time.get_datetime_string_from_system()
	if meta_fn.is_valid():
		var m = meta_fn.call()
		if m is Dictionary and not m.is_empty(): d["meta"] = m
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
	# 사건이 나아갔다(국면·단서·버릇 수가 바뀜) — 자동 기록 표시
	var sig := "%s|%d|%d|%s" % [st.get("phase", ""), (st.get("clues", []) as Array).size(), (st.get("rules", []) as Array).size(),
		bool(st.get("flags", {}).get("case_started", false))]
	if _case_sig.has(id) and String(_case_sig[id]) != sig: _notify("case")
	_case_sig[id] = sig

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
	_d = { "version": 2, "routes_done": {}, "vars": {}, "cases": {}, "onboard": {}, "known": {}, "heard": [] }
	save()

static func clear_case(id: String) -> void:
	data().cases.erase(id)
	save()

# ---- 처음 한 번 안내(ONBOARD_*)·놀이 시간 — vars와 따로 둔다(story_state가 vars를 통째로 덮어 저장하므로) ----
static func onboard(k: String, dflt = false):
	return data().onboard.get(k, dflt)

static func set_onboard(k: String, v, write := true) -> void:
	data().onboard[k] = v
	if write: save()

# ---- 지도에 적힌 곳(scripts/region/discovery.gd) ----
static func known(space: String) -> Dictionary:
	var k: Dictionary = data().known
	if not (k.get(space) is Dictionary): k[space] = {}
	return k[space]

# ---- 들은 소문(scripts/story/ambient_talk.gd · story_director 엿듣기) — 같은 글은 한 번, 최근 40개 ----
const HEARD_MAX := 40

static func heard() -> Array:
	return data().heard

static func heard_has(text: String) -> bool:
	for h in data().heard:
		if h is Dictionary and String(h.get("text", "")) == text: return true
	return false

# 새로 적었으면 true
static func add_heard(e: Dictionary) -> bool:
	if heard_has(String(e.get("text", ""))): return false
	var l: Array = data().heard
	l.append(e)
	while l.size() > HEARD_MAX: l.pop_front()
	save()
	return true

# ---- 저장 칸 · 자동 기록 ----
const SLOTS := 3
static var meta_fn: Callable = Callable()        # () → { place, case, hour, play } — story 쪽(save_keeper.gd)이 건다
static var on_checkpoint: Callable = Callable()  # (까닭) → story_ui 붓 도장
static var place_now := ""                       # 지금 고을 이름(place_title.gd가 적는다)
static var _case_sig := {}
static var _last_note := -100000

# 뜻있는 때의 자동 기록(지금 진행 파일에 쓰고 도장)
static func checkpoint(reason: String) -> void:
	save()
	_notify(reason)

static func _notify(reason: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_note < 4000: return   # 잇달아 찍지 않게
	_last_note = now
	print("PROGRESS checkpoint ", reason)
	if on_checkpoint.is_valid(): on_checkpoint.call(reason)

static func slot_path(n: int) -> String:
	if n <= 0: return path
	return "%s_slot%d.json" % [path.get_basename(), n]

static func thumb_path(n: int) -> String:
	return slot_path(n).get_basename() + ".png"

static func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p): return {}
	var j = JSON.parse_string(FileAccess.get_file_as_string(p))
	return j if j is Dictionary else {}

# 칸 n(0 = 자동)을 쓴다: 지금 진행 그대로 + 작은 그림
static func save_slot(n: int, thumb: Image = null) -> bool:
	save()
	if n > 0:
		var f := FileAccess.open(slot_path(n), FileAccess.WRITE)
		if f == null: return false
		f.store_string(JSON.stringify(data(), " "))
		f.close()
	if thumb != null and not thumb.is_empty(): thumb.save_png(thumb_path(n))
	print("PROGRESS save_slot ", n, " ", slot_path(n))
	return true

# 칸 내용을 지금 진행으로 덮는다(예전 파일 꼴도 data()가 채운다)
static func load_slot(n: int) -> bool:
	var j := _read(slot_path(n))
	if j.is_empty(): return false
	if n > 0:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null: return false
		f.store_string(JSON.stringify(j, " "))
		f.close()
		_d = null
		data()
		_case_sig.clear()
		if FileAccess.file_exists(thumb_path(n)): DirAccess.copy_absolute(ProjectSettings.globalize_path(thumb_path(n)), ProjectSettings.globalize_path(thumb_path(0)))
	print("PROGRESS load_slot ", n)
	return true

# 칸 목록에 보일 것: { saved_at, meta, where, thumb } — 비었으면 {}
static func slot_info(n: int) -> Dictionary:
	var j := data() if n <= 0 else _read(slot_path(n))
	if j.is_empty() or (n <= 0 and j.get("cases", {}).is_empty() and not (j.get("where") is Dictionary)): return {}
	return { saved_at = String(j.get("saved_at", "")), meta = j.get("meta", {}) if j.get("meta") is Dictionary else {},
		where = j.get("where", {}) if j.get("where") is Dictionary else {}, thumb = thumb_path(n) if FileAccess.file_exists(thumb_path(n)) else "" }

# 가장 새 칸(이어 하기) — 없으면 -1
static func latest_slot() -> int:
	var best := -1; var best_t := ""
	for n in SLOTS + 1:
		var info := slot_info(n)
		if info.is_empty(): continue
		if best < 0 or String(info.saved_at) > best_t:
			best = n; best_t = String(info.saved_at)
	return best
