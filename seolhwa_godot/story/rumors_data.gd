# 소문 풀(시나리오 §24 지역 소문 풀, §9 R01 R0101~R0103) — 사건 결말에 따라 달라지는 주변 대화.
# 소문은 사실을 보장하지 않고, 퀘스트 표지처럼 쓰지 않는다. 지나가며 엿듣는 한 줄(자막)로만 나온다.
#   space: 권역 region_id 또는 노정 route id.  near: settlement id(그 공간 region.json/route.json) 또는 [x, z].
#   need: {변수: 값} 이 맞을 때만. var: 결말 변수(§7). lines: 값별 줄("" = 아직 해결 안 됨, "*" = 어떤 결말이든). pool: 값과 상관없이 번갈아 나오는 줄들.
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
	# ---- 한양(§24 한양 풀) — 결말과 상관없이 종로·장터에서 ----
	{ "id": "HY_JONGNO", "space": "GG_HANYANG", "near": "ungjongga", "radius": 46.0, "speaker": "장꾼",
		"pool": [
			"치악산 절에서 종이 저절로 울린다던데.",
			"밀양에선 죽은 처녀가 관아에 나타난다더라.",
			"철산 쪽 자매 귀신 이야기가 심상치 않대.",
			"대구 약령시에 죽은 사람 이름으로 약을 사는 놈이 있다더군.",
			"문경새재 주막에 밤마다 한 자리만 비워둔다더라.",
		] },
	# ---- 한양 S1006 허브 개방 뒤: 강릉·경주·황주 소문(§24 각 고을 풀에서) — 주막·장터에 ----
	{ "id": "HY_GN_PIMAT", "space": "GG_HANYANG", "near": [-240.0, -930.0], "radius": 22.0, "speaker": "책 사러 온 선비", "need": { "ACT2_OPEN": true },
		"pool": ["대관령에서 제물 건드리면 길이 달라진대."] },
	{ "id": "HY_GJ_JONGNO", "space": "GG_HANYANG", "near": [-291.0, -884.0], "radius": 30.0, "speaker": "시전 상인", "need": { "ACT2_OPEN": true },
		"pool": ["감포 바다에서 밤마다 불이 셋 떠."] },
	{ "id": "HY_HJ_GWANGTONG", "space": "GG_HANYANG", "near": [-313.0, -822.0], "radius": 24.0, "speaker": "다리 위 나그네", "need": { "ACT2_OPEN": true },
		"pool": ["장산곶에서 바다가 사람 이름을 부른다더군."] },
	{ "id": "HY_ACT2_CHILPAE", "space": "GG_HANYANG", "near": "chilpae_jang", "radius": 40.0, "speaker": "장꾼", "need": { "ACT2_OPEN": true },
		"pool": ["대관령에서 제물 건드리면 길이 달라진대.", "감포 바다에서 밤마다 불이 셋 떠.", "장산곶에서 바다가 사람 이름을 부른다더군."] },
	{ "id": "HY_ACT2_BAEOGAE", "space": "GG_HANYANG", "near": "baeogae_jang", "radius": 40.0, "speaker": "장꾼", "need": { "ACT2_OPEN": true },
		"pool": ["감포 바다에서 밤마다 불이 셋 떠.", "장산곶에서 바다가 사람 이름을 부른다더군.", "대관령에서 제물 건드리면 길이 달라진대."] },
	{ "id": "HY_ACT2_MAPO", "space": "GG_HANYANG", "near": [-2041.0, 902.0], "radius": 18.0, "speaker": "주막 손님", "need": { "ACT2_OPEN": true },
		"pool": ["장산곶에서 바다가 사람 이름을 부른다더군.", "대관령에서 제물 건드리면 길이 달라진대.", "감포 바다에서 밤마다 불이 셋 떠."] },
	{ "id": "NW_TOWN_TAVERN", "space": "JL_NAMWON_UNBONG", "near": [-3006.0, 228.0], "radius": 14.0, "speaker": "주막 손님", "after": true,
		"pool": [
			"이서 쪽 어느 집안 계집아이가 고생이 많다던데.",
			"지리산 안쪽에서는 장승을 함부로 옮기면 안 된다더라.",
		] },
	# ---- 강릉(§24) · R03 한양 → 강릉(노정) — 「고개에 남은 종소리」 결말에 따라 비틀린 소문 ----
	{ "id": "GN_JANG", "space": "GW_GANGNEUNG", "near": "gangneung_jang", "radius": 40.0, "speaker": "장꾼", "var": "CASE_GANGNEUNG_OUTCOME",
		"lines": {
			"": "대관령에서 제물 건드리면 길이 달라진대.",
			"A": "대관령 경계석이 하룻밤 새 제자리로 돌아왔다더군. 누가 세웠는지는 아무도 몰라.",
			"B": "성황사 방울 훔친 놈이 잡혔대. 방울이 저 혼자 울어서 들켰다나.",
			"C": "대관령 넘는 사람한테 방울이 따라온대. 밤엔 아무도 안 넘어.",
		} },
	{ "id": "GN_EUP", "space": "GW_GANGNEUNG", "near": "gangneung_eup", "radius": 50.0, "speaker": "주막 손님",
		"pool": ["경포호에 없는 배가 뜬다더군.", "헌화 벼랑에서 여인 목소리를 들었다는 사람이 있어."] },
	{ "id": "R0301", "space": "GG_HANYANG-GW_GANGNEUNG", "near": "rt_hoenggye", "radius": 34.0, "speaker": "횡계 사람", "var": "CASE_GANGNEUNG_OUTCOME",
		"lines": {
			"": "단오 앞두고 대관령 성황사가 시끄럽다던데.",
			"A": "고개 귀신이 방울을 돌려받고 물러갔대. 무당이 칼춤을 췄다나.",
			"B": "도둑놈 하나 잡으니 고개가 조용해졌다더군.",
			"C": "웬 나그네가 칼로 귀신을 베고 넘었대. 그 뒤로 밤마다 방울 소리가 난다지.",
		} },
	{ "id": "R0302", "space": "GG_HANYANG-GW_GANGNEUNG", "near": "rt_wonju", "radius": 34.0, "speaker": "장꾼", "need": { "ACT2_OPEN": true },
		"pool": ["치악산 절에서 종이 저절로 울린다던데.", "대관령에서 제물 건드리면 길이 달라진대."] },
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
	# need: { 변수: 값 } — 모두 맞을 때만(예: 한양 S1006 뒤 ACT2_OPEN)
	for k in r.get("need", {}):
		if str(live_vars.get(k, saved_vars.get(k, ""))) != str(r.need[k]): return ""
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
