# 소문 풀(시나리오 §24 지역 소문 풀, §9 R01 R0101~R0103) — 사건 결말에 따라 달라지는 주변 대화.
# 소문은 사실을 보장하지 않고, 퀘스트 표지처럼 쓰지 않는다. 지나가며 엿듣는 한 줄(자막)로만 나온다.
#   space: 권역 region_id 또는 노정 route id.  near: settlement id(그 공간 region.json/route.json) 또는 [x, z].
#   need: {변수: 값} 이 맞을 때만. var: 결말 변수(§7). lines: 값별 줄("" = 아직 해결 안 됨, "*" = 어떤 결말이든). pool: 값과 상관없이 번갈아 나오는 줄들.
extends RefCounted

# 시나리오 v2.4.1 §1.11 — 생활·풍경·소문은 AMBIENT: 사건 수에 넣지 않고 설화 출처(SOURCE_ID)를 달지 않는다
const EVENT_CLASS := "AMBIENT"

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
	# ---- 남원 고을 — 산길 일 뒤(결말별로 비틀린 이야기, R0101~R0103과 같은 결). 사건 전에는 없다 ----
	{ "id": "NW_TOWN_AFTER", "space": "JL_NAMWON_UNBONG", "near": "namwon_jang", "radius": 40.0, "speaker": "장꾼", "var": "CASE_NAMWON_OUTCOME",
		"lines": {
			"A": "외딴집에 내려온 범을 장정들이 몰아냈다더군. 몽둥이가 다 부러졌대.",
			"B": "범이 기름 바른 나무에서 미끄러졌대. 그 집 아이들 꾀가 보통이 아니라나.",
			"C": "범한테 떡을 내주고 산으로 돌려보냈대. 그래서 서낭당에 떡이 쌓인다나.",
		} },
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
	# ---- 경주(§24) · R02 한양 → 경주(노정) — 「세 번째 등불」 결말에 따라 비틀린 소문(A 밀수꾼 붙잡음 · B 달아남) ----
	#   셋째 불(든 사람 없는 불)은 어느 결말에서도 풀리지 않은 채 소문에 남는다(§1.4).
	{ "id": "GJ_JANG", "space": "GS_GYEONGJU", "near": "gyeongju_jang", "radius": 44.0, "speaker": "장꾼", "var": "CASE_GYEONGJU_OUTCOME",
		"lines": {
			"": "감포 바다에서 밤마다 불이 셋 떠.",
			"A": "치술령 불 셋 가운데 둘은 사람 짓이었대. 밀수꾼이 잡혔다지. 나머지 하나는… 아무도 몰라.",
			"B": "치술령 불이 하나로 줄었대. 나머지는 감포 앞바다로 옮겨 갔다나.",
		} },
	{ "id": "GJ_EUP", "space": "GS_GYEONGJU", "near": "gyeongju_eup", "radius": 50.0, "speaker": "주막 손님",
		"pool": ["왕릉 사이에서 누가 말을 탄다는 소문이 있어.", "옛 절터에 없는 종소리가 난다더군."] },
	{ "id": "R0201", "space": "GG_HANYANG-GS_GYEONGJU", "near": "rt_saejae", "radius": 40.0, "speaker": "새재 주막 손님", "var": "CASE_GYEONGJU_OUTCOME",
		"lines": {
			"": "경주 쪽 고개에 밤마다 불이 셋 뜬다던데.",
			"A": "경주 고개 귀신불이 알고 보니 밀수꾼 등불이었대. 하나만 빼고.",
			"B": "경주 고개 귀신불을 쫓던 나그네가 밀수꾼한테 혼쭐이 났다나.",
		} },
	{ "id": "R0202", "space": "GG_HANYANG-GS_GYEONGJU", "near": "rt_sangju", "radius": 36.0, "speaker": "장꾼", "need": { "ACT2_OPEN": true },
		"pool": ["감포 바다에서 밤마다 불이 셋 떠.", "왕릉 사이에서 누가 말을 탄다는 소문이 있어."] },
	{ "id": "R0203", "space": "GG_HANYANG-GS_GYEONGJU", "near": "rt_jebiwon", "radius": 36.0, "speaker": "원집 주인", "var": "CASE_GYEONGJU_OUTCOME",
		"lines": {
			"": "치술령 아래 숯쟁이가 불 따라갔다 안 돌아왔대.",
			"A": "치술령 숯쟁이가 살아 돌아왔대. 마누라가 밤마다 등불 들고 기다렸다지.",
			"B": "치술령 숯쟁이는 돌아왔는데, 붙잡아 둔 놈들은 바다로 내뺐대.",
		} },
	# ---- 황주(§24) · R04 한양 → 황주 · R05 황주 → 평양 · R08 황주 → 장산곶 — 「빈 배의 값」 결말에 따라 비틀린 소문 ----
	#   사람 제물이 바다를 달랜다는 믿음은 소문으로만 돈다(§37 A11 — 확인하지 않는다). C(구조 실패)면 그 믿음이 오히려 굳는다(§29 잘못된 정보 유포).
	{ "id": "HJ_DOHWA", "space": "HH_HWANGJU", "near": "dohwadong", "radius": 44.0, "speaker": "도화동 사람", "var": "CASE_HWANGJU_OUTCOME",
		"lines": {
			"": "장산곶에서 바다가 사람 이름을 부른다더군.",
			"A": "노인 딸이 살아 돌아왔대. 바다 값 받아먹던 중개인은 관아에 끌려갔고.",
			"B": "노인 딸이 살아 돌아왔대. 중개한 놈은 말 타고 내뺐다지.",
			"C": "장산곶 바다가 처녀 하나를 받았대. 그 뒤로 바다가 잔잔하다나.",
		} },
	{ "id": "HJ_JANG", "space": "HH_HWANGJU", "near": "hwangju_jang", "radius": 46.0, "speaker": "장꾼",
		"pool": ["구월산에서 누가 단군 제사를 다시 올린다나.", "재령 들판에 밤이면 등불이 줄지어 움직인대.", "장산곶에서 바다가 사람 이름을 부른다더군."] },
	{ "id": "R0401", "space": "GG_HANYANG-HH_HWANGJU", "near": "rt_seoheung", "radius": 34.0, "speaker": "주막 손님", "var": "CASE_HWANGJU_OUTCOME",
		"lines": {
			"": "황주 쪽에 딸 하나가 큰돈 받고 배를 탔다던데.",
			"A": "황주 처녀가 바다에서 살아 나왔대. 바다 값이니 뭐니, 다 셈속이었다지.",
			"B": "황주 처녀가 바다에서 살아 나왔대. 용왕이 돌려보냈다는 사람도 있고.",
			"C": "황주 처녀가 장산곶 바다에 들었대. 그 덕에 뱃길이 순하다나.",
		} },
	{ "id": "R0402", "space": "GG_HANYANG-HH_HWANGJU", "near": "rt_kaesong", "radius": 40.0, "speaker": "장꾼", "need": { "ACT2_OPEN": true },
		"pool": ["장산곶에서 바다가 사람 이름을 부른다더군.", "구월산에서 누가 단군 제사를 다시 올린다나."] },
	{ "id": "R0501", "space": "HH_HWANGJU-PA_PYEONGYANG", "near": "rt_junghwa", "radius": 40.0, "speaker": "중화 나그네", "var": "CASE_HWANGJU_OUTCOME",
		"lines": {
			"": "황해도 바닷가에 처녀를 사 가는 장사꾼이 있다던데.",
			"A": "황주에서 바다 값 받던 중개인이 잡혔대. 장산곶 어부들이 관아까지 끌고 갔다나.",
			"B": "황주에서 바다 값 받던 중개인이 평양 쪽으로 숨어들었다는 말이 있어.",
			"C": "장산곶에서 또 처녀를 산다는 말이 돌아. 바다가 받으니 값이 오른다나.",
		} },
	{ "id": "R0801", "space": "HH_HWANGJU-JANGSANGOT", "near": "rt_guwol", "radius": 50.0, "speaker": "나무꾼",
		"pool": ["구월산에서 누가 단군 제사를 다시 올린다나."] },
	{ "id": "R0802", "space": "HH_HWANGJU-JANGSANGOT", "near": "rt_jaeryeong", "radius": 46.0, "speaker": "재령 사람",
		"pool": ["재령 들판에 밤이면 등불이 줄지어 움직인대."] },
	{ "id": "R0803", "space": "HH_HWANGJU-JANGSANGOT", "near": "rt_jangsan", "radius": 60.0, "speaker": "어부", "var": "CASE_HWANGJU_OUTCOME",
		"lines": {
			"A": "옛날처럼 짚배 띄우자는 말이 나와. 사람 대신.",
			"B": "탁가 놈 안 보인 뒤로 선주들이 바다 값 얘기를 덜 하오.",
			"C": "그 처녀 일 뒤로 바다가 순하다고들 하는데… 난 모르겠소.",
		} },
	# ---- ACT 4 함흥(§24 함흥 — 함흥차사는 사람들의 농담으로만, §37 A15) · R07 평양→함흥 · R09 북청길 · R06 경흥대로 ----
	{ "id": "HG_GATE", "space": "HG_HAMHEUNG", "near": [-184.0, 62.0], "radius": 26.0, "speaker": "동문 밖 장꾼", "var": "CASE_HAMHUNG_DETAIL",
		"lines": {
			"": "함흥에서 보낸 사람은 돌아오지 않는다더라.",
			"A": "북청 간 전갈꾼이 셋 다 왔대. 이번 차사는 돌아왔다고들 웃어.",
			"B_madong": "막동이는 눈 그치고 찾았는데 늦었대. 그 집 앞에 물 한 그릇 떠 놓았더군.",
			"B_gapsul": "갑술이는 도적한테 끌려갔대. 관아가 고개 북쪽 숲을 뒤진다더군.",
			"C": "셋 중에 하나만 왔대. 막동이 집 앞엔 물 한 그릇이 놓였고, 갑술이는 아직 소식이 없고.",
		} },
	{ "id": "HG_JANG", "space": "HG_HAMHEUNG", "near": "hamheung_jang", "radius": 40.0, "speaker": "장꾼",
		"pool": ["북청에선 사자탈이 혼자 움직인다던데.", "철령 넘다가 자기 목소리를 들으면 뒤돌아보지 말래."] },
	{ "id": "R0701", "space": "PA_PYEONGYANG-HG_HAMHEUNG", "near": "rt_gowon", "radius": 36.0, "speaker": "고원 주막 손님", "var": "CASE_HAMHUNG_OUTCOME",
		"lines": {
			"": "함흥에서 북청 보낸 전갈꾼이 안 온다더군. 함흥차사가 따로 없지.",
			"A": "함관령 눈보라에 갇힌 전갈꾼들을 웬 나그네가 다 데려왔다더군.",
			"B": "함관령에서 전갈꾼 하나를 잃었대. 눈 속에서.",
			"C": "함관령에서 전갈꾼 둘을 잃었대. 하나는 눈에, 하나는 도적한테.",
		} },
	{ "id": "R0901", "space": "HG_HAMHEUNG-BUKCHEONG", "near": "rt_hongwon", "radius": 40.0, "speaker": "홍원 주막 손님",
		"pool": ["북청에선 사자탈이 혼자 움직인다던데.", "함관령 옛 역참에 요새 불이 켜진대. 버린 지 오래된 곳인데."] },
	{ "id": "R0601", "space": "GG_HANYANG-HG_HAMHEUNG", "near": "rt_cheollyeong", "radius": 40.0, "speaker": "고갯길 나그네",
		"pool": ["철령 넘다가 자기 목소리를 들으면 뒤돌아보지 말래."] },
	# ---- ACT 3 평양 「강을 판 사내」(§24 평양 풀 · R05 황주→평양 · R07 평양→함흥) ----
	{ "id": "PY_NARU", "space": "PA_PYEONGYANG", "near": "daedong_naru", "radius": 40.0, "speaker": "나루 사람", "var": "CASE_PYONGYANG_OUTCOME",
		"lines": {
			"": "대동강을 판 사내가 있대.",
			"A": "강을 판 게 우치가 아니었대. 강창 뒤에서 종이 고치던 놈들이었다나.",
			"B": "우치가 대동강을 두 번 팔고 날랐대. 감영도 손을 못 쓴다나.",
		} },
	{ "id": "PY_JONGNO", "space": "PA_PYEONGYANG", "near": "pyeongyang_jongno", "radius": 44.0, "speaker": "장꾼", "need": { "ACT3_OPEN": true },
		"pool": ["대동강을 판 사내가 있대.", "기린굴에서 아이가 사라졌다더군.", "묘향산에 들어간 장사꾼이 사흘 뒤 빈손으로 돌아왔대."] },
	{ "id": "PY_NAESEONG", "space": "PA_PYEONGYANG", "near": "pyeongyang_naeseong", "radius": 40.0, "speaker": "감영 아전", "var": "CASE_PYONGYANG_OUTCOME",
		"lines": {
			"A": "기록 창고에 든 도둑은 따로라더군. 북관 문서만 가져갔대.",
			"B": "기록 창고 털린 것도 강 판 놈들 짓이라던데. 다들 우치라 하고.",
		} },
	{ "id": "R0551", "space": "HH_HWANGJU-PA_PYEONGYANG", "near": [240.0, 12.0], "radius": 40.0, "speaker": "평양 쪽 장꾼", "need": { "ACT3_OPEN": true },
		"var": "CASE_PYONGYANG_OUTCOME",
		"lines": {
			"": "평양 나루에서 강물을 사고판다던데. 도장 찍힌 문서까지 있대.",
			"A": "평양에서 강 팔던 놈들이 잡혔대. 우치 이름을 빌린 가짜였다나.",
			"B": "평양에서 우치가 강을 팔고 날랐대. 문서는 감영이 거뒀다지만.",
		} },
	{ "id": "R0751", "space": "PA_PYEONGYANG-HG_HAMHEUNG", "near": "rt_gangdong", "radius": 40.0, "speaker": "강동 나그네", "var": "CASE_PYONGYANG_OUTCOME",
		"lines": {
			"A": "평양 나루 사기꾼들, 감영 앞에 묶여 앉았다더군.",
			"B": "평양에선 아직도 우치가 강을 팔았다고들 하오.",
		} },
	{ "id": "R0752", "space": "PA_PYEONGYANG-HG_HAMHEUNG", "near": "rt_seongcheon", "radius": 40.0, "speaker": "성천 주막 손님", "need": { "CASE_PYONGYANG_COMPLETE": true },
		"pool": ["평양 감영 문서고가 털렸대. 북관 쪽 문서만 없어졌다나.", "함흥에서 북청 간 전갈이 셋이나 안 돌아왔대."] },
	# ---- 제주(§24 제주 풀 — 결말과 상관없이 화북포·제주성 장) · 김녕(「굴에 남은 숨」 결말별) · 남해 뱃길 관두포 ----
	{ "id": "JJ_HWABUK", "space": "JJ_JEJU", "near": "hwabuk_po", "radius": 40.0, "speaker": "포구 사람",
		"pool": ["김녕 굴에서 이름을 세 번 부르면 안 된대.", "송당 신목에 말고삐를 묶으면 말이 밤새 운다더군.", "산지포에서 물에 비친 얼굴이 다르게 보이는 날이 있대."] },
	{ "id": "JJ_JANG", "space": "JJ_JEJU", "near": "jeju_jang", "radius": 46.0, "speaker": "장꾼",
		"pool": ["송당 신목에 말고삐를 묶으면 말이 밤새 운다더군.", "산지포에서 물에 비친 얼굴이 다르게 보이는 날이 있대.", "김녕 굴에서 이름을 세 번 부르면 안 된대."] },
	{ "id": "JJ_GIMNYEONG", "space": "JJ_JEJU", "near": [3432.4, -884.0], "radius": 30.0, "speaker": "김녕 사람", "var": "CASE_JEJU_OUTCOME",
		"lines": {
			"": "김녕 굴에서 이름을 세 번 부르면 안 된대.",
			"A": "굴 앞에 금줄을 새로 맸대. 심방이 그러는데, 이제 굴이 숨을 고른대.",
			"B": "굴은 돌로 막았지. 그래도 밤이면 돌 틈으로 긴 숨소리가 샌대.",
			"C": "육지 나그네가 굴 뱀을 베었대. 옛날 판관처럼. …그런데 굴에선 아직도 뭐가 지나간다더군.",
		} },
	{ "id": "RS_GWANDU", "space": "SEA_NAMHAE_JEJU", "near": "rt_gwandu", "radius": 34.0, "speaker": "포구 뱃사람", "var": "CASE_JEJU_OUTCOME",
		"lines": {
			"": "제주 가오? 김녕 굴 이야기 들었소? 이름을 세 번 부르면 안 된다지.",
			"A": "김녕 굴에 금줄을 새로 맸다더군. 뭍사람 하나가 거들었대.",
			"B": "김녕 굴을 돌로 막았다더군. 아이는 찾았고.",
			"C": "김녕 굴 뱀을 뭍사람이 베었다더군. 옛날 판관 같다고들 해.",
		} },
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
