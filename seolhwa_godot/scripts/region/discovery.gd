# 지도에 적힌 곳(보강서 §10·§20) — "알고 있는 지리는 표시한다. 알아내야 하는 사실은 표시하지 않는다."
#   지형·물·길·성벽·이름 없는 집채는 바탕 지리라 늘 그린다. 이름(고을·이름 있는 건물·사건 장소)은 알게 된 것만 쓴다.
# 세 단계(C65 — 여덟 권역 공통, 남원도 예외 없음): '위치를 아는가'와 '직접 가 보았는가'를 가른다.
#   UNKNOWN  저장에 키 없음 — 이름도 기호도 없다. 직접 찾거나 사람·문서·사건으로 알아야 한다.
#   KNOWN    "told"(사람이 자리를 정확히 일러 줌 — 사건 데이터·대사) · "known"(권역 상식 region_known · 처음부터 앎 start_known)
#            — 이름·자리는 지도에 있으나 아직 안 가 봄(지도: 옅은 먹·빈 기호).
#   VISITED  "visited" — 그 자리 다가가는 거리 안에 실제로 들어섬(지도: 보통 기호).
#   넘어감: 권역 진입 → 대표 명소·공공시설 KNOWN(grant, scripts/region/region_known.gd · region_data/region_known.json) ·
#           NPC가 정확히 일러 줌 → UNKNOWN→KNOWN(tell) · 다가감 → →VISITED(visit). 내려가는 일은 없다.
#   역참·역마·깃발(travel_nodes)은 따로다 — '가 봄'만 센다. KNOWN은 역마·역참 조건을 채우지 않는다.
#   저장: progress.gd known { "<공간 id>": { "<키>": "visited"|"told"|"known" }, "_nation": {…} } — 새 게임이면 비워진다.
#   옛 저장("visited"/"told"만)도 그대로 읽는다 — "told"는 KNOWN. 상식 목록은 그 권역에 다음에 들어설 때(불러와 그 권역에 서면 곧) 채운다.
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

const UNKNOWN := 0
const KNOWN := 1
const VISITED := 2

# 이름을 쓸 만큼 아나(KNOWN 또는 VISITED)
static func is_known(space: String, key: String) -> bool:
	return Progress.known(space).has(key)

# 세 단계 — "visited"만 VISITED, 그 밖의 값("told"·"known")은 KNOWN
static func state(space: String, key: String) -> int:
	var k := Progress.known(space)
	if not k.has(key): return UNKNOWN
	return VISITED if String(k[key]) == "visited" else KNOWN

static func is_visited(space: String, key: String) -> bool:
	return state(space, key) == VISITED

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

# 권역 상식(KNOWN) 한꺼번에 — 이미 아는 키(들음·가 봄)는 그대로. 새로 적은 수
static func grant(space: String, keys: Array) -> int:
	var k := Progress.known(space)
	var n := 0
	for key in keys:
		if k.has(key): continue
		k[key] = "known"; n += 1
	if n > 0: Progress.save()
	return n

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
