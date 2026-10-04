# 소문 풀(시나리오 §24 지역 소문 풀, §9 R01 R0101~R0103) — 사건 결말에 따라 달라지는 주변 대화.
# 소문은 사실을 보장하지 않고, 퀘스트 표지처럼 쓰지 않는다. 지나가며 엿듣는 한 줄(자막)로만 나온다.
#   space: 권역 region_id 또는 노정 route id.  near: settlement id(그 공간 region.json/route.json) 또는 [x, z].
#   var: 결말 변수(§7). lines: 값별 줄("" = 아직 해결 안 됨, "*" = 어떤 결말이든). pool: 값과 상관없이 번갈아 나오는 줄들.
extends RefCounted

const ROUTE_R01 := "JL_NAMWON_UNBONG-GG_HANYANG"

const RUMORS := [
	# ---- R01 남원 → 한양(노정) — 플레이어가 겪은 것과 다른 이야기가 퍼진다 ----
	{ "id": "R0101", "space": ROUTE_R01, "near": "rt_osu", "radius": 30.0, "speaker": "주막 손님", "var": "CASE_NAMWON_OUTCOME",
		"lines": {
			"": "남원 고개에 범이 내려온다더군. 떡장수 하나가 안 돌아왔대.",
			"A": "호랑이가 사람 옷까지 입었다던데. 장정 열이 몽둥이로 때려잡았대.",
			"B": "호랑이가 사람 옷까지 입었다던데. 기름 바른 나무에서 떨어져 목이 부러졌대.",
			"C": "호랑이가 사람 옷까지 입었다던데. 떡 한 광주리 받고 산으로 돌아갔대.",
		} },
	{ "id": "R0102", "space": ROUTE_R01, "near": "rt_jeonju", "radius": 34.0, "speaker": "장꾼", "var": "CASE_NAMWON_OUTCOME",
		"lines": {
			"": "남원 쪽 고개는 해 지면 넘지 말라더군.",
			"A": "아이들이 나무 위에서 밤을 샜다더군. 범은 그 밑에서 칼에 맞았고.",
			"B": "아이들이 나무 위에서 밤을 샜다더군. 범이 줄 타고 오르다 떨어졌다나.",
			"C": "아이들이 나무 위에서 밤을 샜다더군. 범은 날이 새자 제 발로 갔대.",
		} },
	{ "id": "R0103", "space": ROUTE_R01, "near": "rt_gomnaru", "radius": 30.0, "speaker": "뱃사공", "var": "CASE_NAMWON_OUTCOME",
		"lines": {
			"": "남쪽에선 범이 사람 목소리를 흉내 낸다더군.",
			"A": "하늘에서 줄이 내려왔다는 말도 있던데? 범은 썩은 줄 잡았다 떨어졌고.",
			"B": "하늘에서 줄이 내려왔다는 말도 있던데? 아이들이 그 줄 타고 올라갔다나.",
			"C": "하늘에서 줄이 내려왔다는 말도 있던데? 범은 그 줄을 못 잡고 산으로 갔대.",
		} },
	# ---- 남원 고을 소문(§24) — 결말과 상관없이 장터·주막에서 ----
	{ "id": "NW_TOWN_MARKET", "space": "JL_NAMWON_UNBONG", "near": "namwon_jang", "radius": 40.0, "speaker": "장꾼",
		"pool": [
			"공주 곰나루에 밤이면 곰이 운다더군.",
			"인월 쪽 어떤 가난한 집에서 제비가 복을 가져왔다나.",
		] },
	{ "id": "NW_TOWN_TAVERN", "space": "JL_NAMWON_UNBONG", "near": [-3006.0, 228.0], "radius": 14.0, "speaker": "주막 손님", "after": true,
		"pool": [
			"이서 쪽 어느 집안 계집아이가 고생이 많다던데.",
			"지리산 안쪽에서는 장승을 함부로 옮기면 안 된다더라.",
		] },
]

# 이 공간에 걸린 소문(자리 p: Vector2 채워서)
static func for_space(space: String, region: Dictionary) -> Array:
	var out := []
	for r in RUMORS:
		if String(r.space) != space: continue
		var p = r.near
		var v := Vector2.INF
		if p is Array: v = Vector2(float(p[0]), float(p[1]))
		else:
			for s in region.get("settlements", []):
				if String(s.get("id", "")) == String(p): v = Vector2(float(s.x), float(s.z)); break
		if v == Vector2.INF: continue
		var rr: Dictionary = r.duplicate()
		rr.p = v
		out.append(rr)
	return out

# 지금 들을 줄(없으면 "")
static func pick(r: Dictionary, saved_vars: Dictionary, live_vars: Dictionary) -> String:
	if r.has("pool"):
		# 사건이 끝난 뒤에만(after) — 그 전에는 사건 이야기만 돈다
		if r.get("after", false) and String(live_vars.get("CASE_NAMWON_OUTCOME", saved_vars.get("CASE_NAMWON_OUTCOME", ""))) == "": return ""
		var pool: Array = r.pool
		var i := int(Time.get_unix_time_from_system() / 600.0) % pool.size()   # 10분마다 다른 소문
		return String(pool[i])
	var key := String(r.get("var", ""))
	var val := String(live_vars.get(key, saved_vars.get(key, "")))
	var lines: Dictionary = r.get("lines", {})
	if lines.has(val): return String(lines[val])
	return String(lines.get("*", ""))
