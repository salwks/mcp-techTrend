# 지도에 적힌 곳(보강서 §10·§20) — "알고 있는 지리는 표시한다. 알아내야 하는 사실은 표시하지 않는다."
#   지형·물·길·성벽·이름 없는 집채는 바탕 지리라 늘 그린다. 이름(고을·이름 있는 건물·사건 장소)은 알게 된 것만 쓴다.
#   알게 되는 길: visited(가 봄 — 그 자리 가까이 감) · told(사람이 자리를 정확히 일러 줌 — 사건 데이터·대사) · known(처음부터 앎).
#   저장: progress.gd known { "<공간 id>": { "<키>": "visited"|"told" }, "_nation": {…} } — 새 게임이면 비워진다.
# 키:
#   town:<이름>            고을·마을 이름(place_title 지명)
#   bld:<이름>@<x>,<z>     이름 있는 건물(building_titles) — 같은 이름(주막)이 여럿이라 자리를 붙인다
#   place:<id>             사건 데이터 map_places의 장소(외딴집·물레방앗간·고갯길 …)
#   region:<권역 id>       전국 지도의 권역(가 봄, 또는 기록·말로 알게 됨 — told_regions())
#   sh:<이름>              전국 지도 거점 이름(그 이름의 고을을 가 봄)
# 사건 데이터 map_places 항목(story/<사건>/<사건>_data.gd "map_places"):
#   { "id", "name"(지도 글자), "at"(자리 이름·[x,z]), "radius"(가 봄 거리, 기본 18),
#     "start_known": true(처음부터 앎), "known": "조건식"(맞으면 told — 사람이 일러 줌), "building": true(이름 글자는 그 자리 건물 이름으로) }
# 사건 단계 명령 { "discover": "<map_places id>" }(story_runner)나 Discovery.tell(space, "place:<id>")로 직접 적을 수도 있다.
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")

const NATION := "_nation"
# 이겸의 흔적(MAIN_MASTER_TRACE 토큰) → 권역
const TRACE_REGION := { HANYANG = "GG_HANYANG", GANGNEUNG = "GW_GANGNEUNG", GYEONGJU = "GS_GYEONGJU", HWANGJU = "HH_HWANGJU",
	PYEONGYANG = "PA_PYEONGYANG", PYONGYANG = "PA_PYEONGYANG", HAMHUNG = "HG_HAMHEUNG", HAMHEUNG = "HG_HAMHEUNG", JEJU = "JJ_JEJU" }
const ACT2_REGIONS := ["GW_GANGNEUNG", "GS_GYEONGJU", "HH_HWANGJU"]
const START_REGION := "JL_NAMWON_UNBONG"   # 기록책 마지막 장의 곳 — 처음부터 안다

static func is_known(space: String, key: String) -> bool:
	return Progress.known(space).has(key)

static func how(space: String, key: String) -> String:
	return String(Progress.known(space).get(key, ""))

# 새로 알게 되면 true(지도 열기 안내 등에 쓴다)
static func visit(space: String, key: String) -> bool:
	var k := Progress.known(space)
	if String(k.get(key, "")) == "visited": return false
	k[key] = "visited"
	Progress.save()
	return true

static func tell(space: String, key: String) -> bool:
	var k := Progress.known(space)
	if k.has(key): return false
	k[key] = "told"
	Progress.save()
	return true

# 처음부터 아는 곳(기록책·여행 준비로 — 들음 표시 없이)
static func know(space: String, key: String) -> void:
	var k := Progress.known(space)
	if k.has(key): return
	k[key] = "known"
	Progress.save()

static func bld_key(name: String, c: Vector2) -> String:
	return "bld:%s@%d,%d" % [name, roundi(c.x), roundi(c.y)]

# 기록·말로 알게 된 권역(저장의 공통 변수에서 계산 — 따로 적지 않는다)
static func told_regions() -> Array:
	var out := [START_REGION]
	var v := Progress.vars()
	for t in String(v.get("MAIN_MASTER_TRACE", "")).split(",", false):
		var r = TRACE_REGION.get(String(t).strip_edges().to_upper())
		if r != null and not out.has(r): out.append(r)
	if bool(v.get("ACT2_OPEN", false)):
		for r in ACT2_REGIONS:
			if not out.has(r): out.append(r)
	if bool(v.get("ACT3_OPEN", false)) and not out.has("PA_PYEONGYANG"): out.append("PA_PYEONGYANG")
	if bool(v.get("ACT4_OPEN", false)) and not out.has("HG_HAMHEUNG"): out.append("HG_HAMHEUNG")   # 평양 S5005 우치가 던진 함흥 문서
	return out

static func region_known(id: String) -> bool:
	return is_known(NATION, "region:" + id) or told_regions().has(id)
