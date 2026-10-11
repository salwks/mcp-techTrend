# 권역 상식(region_known) — 권역에 들어서면 '물어보면 고을 사람이 가리켜 줄' 대표 명소·공공시설을 KNOWN으로 적는다(C65).
#   데이터: res://region_data/region_known.json { "<공간 id>": { towns, landmarks, buildings, passes, ferries, note } }
#     towns      고을·마을 짧은 이름(place_title TITLES)        → town:<이름>
#     landmarks  region.json landmarks의 id                       → lm:<id>
#     buildings  배치 이름(배치 title · building_titles 이름)    → bld:<이름>@<x>,<z> (그 이름의 건물 모두)
#     passes     region.json passes의 id                          → pass:<id>
#     ferries    region.json crossings(나루)의 이름              → town:<짧은 이름>(지도 나루 이름표 키)
#   넣지 않는 것: 개별 생활시설(주막·방앗간·외딴집)·사적 공간(사람 집)·사건 장소(place: — 절대 자동 아님)·단서 자리·숨은 굴.
#   KNOWN은 '위치를 앎'일 뿐 '가 봄'이 아니다 — 역참·역마·깃발(travel_nodes)은 여기서 건드리지 않는다.
extends RefCounted

const PATH := "res://region_data/region_known.json"
const Discovery := preload("res://scripts/region/discovery.gd")
const Travel := preload("res://scripts/region/travel.gd")

static var _data = null

static func data() -> Dictionary:
	if _data == null:
		_data = {}
		if FileAccess.file_exists(PATH):
			var j = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if j is Dictionary: _data = j
	return _data

static func spec(space: String) -> Dictionary:
	var s = data().get(space)
	return s if s is Dictionary else {}

# 이름표 충돌 우선순위(C66): { 이름: 값 } — 기본 0. 같은 종류(prio)끼리 겹칠 때만 쓴다
static func label_priority(space: String) -> Dictionary:
	var lp = spec(space).get("label_priority", {})
	return lp if lp is Dictionary else {}

static func spaces() -> Array:
	return data().keys().filter(func(k): return not String(k).begins_with("_"))

# 이 공간의 상식 키 → { keys: [키…], missing: ["종류:이름" — 데이터에는 있는데 지도에 없는 것] }
#   towns: 고을 짧은 이름 목록 · items: [{name, c: Vector2}](이름 있는 건물) · region: region.json
static func resolve(space: String, towns: Array, items: Array, region: Dictionary) -> Dictionary:
	var s := spec(space)
	var keys: Array = []
	var missing: Array = []
	for t in s.get("towns", []):
		if towns.has(String(t)): keys.append("town:" + String(t))
		else: missing.append("town:" + String(t))
	var lm_ids := {}
	for l in region.get("landmarks", []): lm_ids[String(l.get("id", l.get("name", "")))] = true
	for id in s.get("landmarks", []):
		if lm_ids.has(String(id)): keys.append("lm:" + String(id))
		else: missing.append("lm:" + String(id))
	for nm in s.get("buildings", []):
		var hit := false
		for it in items:
			if String(it.name) == String(nm):
				var k := Discovery.bld_key(String(it.name), it.c)
				if not keys.has(k): keys.append(k)
				hit = true
		if not hit: missing.append("bld:" + String(nm))
	var ps_ids := {}
	for ps in region.get("passes", []): ps_ids[String(ps.get("id", ps.get("name", "")))] = true
	for id in s.get("passes", []):
		if ps_ids.has(String(id)): keys.append("pass:" + String(id))
		else: missing.append("pass:" + String(id))
	var fr := {}
	for cr in region.get("crossings", []):
		if String(cr.get("type", "")) == "나루": fr[String(cr.get("name", ""))] = true
	for nm in s.get("ferries", []):
		if fr.has(String(nm)):
			var k := "town:" + Travel.short_name(String(nm))
			if not keys.has(k): keys.append(k)
		else: missing.append("ferry:" + String(nm))
	return { keys = keys, missing = missing }
