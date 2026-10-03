# 진행 기록(최소) — user://progress.json. 엔진에 따로 저장 상태가 없어서 만든 작은 파일.
# { "routes_done": { "<노정 id>": "2026-10-04T12:00:00" } } — 노정을 한 끝에서 다른 끝(포털)까지 지나가면 기록하고,
# 그 노정은 권역 쪽 포털에서 역마(驛馬)로 건너뛸 수 있다(region_main H 키).
extends RefCounted

const PATH := "user://progress.json"
static var _d = null

static func data() -> Dictionary:
	if _d == null:
		_d = {}
		if FileAccess.file_exists(PATH):
			var j = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if j is Dictionary: _d = j
		if not (_d.get("routes_done") is Dictionary): _d["routes_done"] = {}
	return _d

static func route_done(id: String) -> bool:
	return data().routes_done.has(id)

static func mark_route_done(id: String) -> void:
	if id == "" or route_done(id): return
	data().routes_done[id] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_d, " "))
		f.close()
	print("PROGRESS route_done ", id)
