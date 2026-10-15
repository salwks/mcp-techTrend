# 메인 서장 「이겸의 수상한 편지」 — 첫 15분(재기획 3단계). 이야기 데이터.
# 기준(우선순위): seolhwa/docs/replanning/Seolhwarok_Actual_Game_Replanning_v1_0.md(재기획) > Dialogue_Camera_UX_Spec_v1_1 >
#   Seolhwarok_First15_Playable_Scenario_v1_2.md(첫15 — 이 단계의 주 명세: 대사·사건 조건) > Map_Waypoint_Horse_UX_Spec_v1_3.
#   첫15에 없는 줄은 seolhwa/docs/opening/Main_Story_Script_Part01_v1_0.md(메인 대본 S1.0 — 첫15의 선행 문서)에서 가져오고, 둘 다 없는 줄만 새로 썼다
#   (새로 쓴 줄은 아래 "신규 대사"로 표시 — 보고서 replanning-stage3-first15.md §2).
# 사용자 결정: seolhwa/docs/replanning/DECISIONS_stage1.md — D1(새 게임 = 이겸의 편지, 오누이는 북쪽 길목 선택 사건) · D3 · D7(12초 안 조작).
#
# 흐름: OP00 거처 방(검은 화면 → 담 와이드 → 책상 쪽 → 등 뒤, 9.6초에 조작) → P00-A 방 물건 셋(장부 필수 아님 — 아무거나 하나) →
#   문 두드림(첫 조사 뒤) → [P00-B 셋 다 보면 짧은 기억] → P01-A 마당의 심부름꾼(대화 선택) · 문턱의 봉투(E — 편지 읽기, LETTER_RECEIVED) →
#   P01-B 서안: 옛 기록과 편지 견주기(문서 비교 — 셋 중 두 쌍, LETTER_SUSPICIOUS) → OP01 거처 밖 4m: 「설화록」(조작 그대로) →
#   P02-A 솔잎 주막 주모(TAVERN_TALK) → P02-B 숙박 장부 또는 손님(TAVERN_CLUE — 지도 '여원재 방면' KNOWN) → P02-C M 지도 · [목적지 설정](WAYPOINT_SET).
# 국면(phase): start → home(거처) → town(편지 의심 뒤 — 거리) → road(목적지를 정함 — 후속 운봉 길 앞, 쉬는 자리 rest_flag).
# 오누이 들머리(D1): 북문 밖 갈림길 행상(오누이 v3.4 F3401 대사) — 고르면 story_director.switch_case("namwon", N0000). 메인을 막지 않는다.
# 조건식: story_runner(f·c·ph·v·talked·fn).
extends RefCounted

const LETTER := "ITM_MAIN_LETTER"   # 출처 미확인 편지(메인 대본 P01-A '출처 미확인 편지' 인벤토리)
const COIN := "COIN"
const HX := -3252.0                 # 이겸의 거처(placement_story_main_p1.json ig_house) — 초가 가운데
const HZ := 240.4
const JX := -3206.91                # 솔잎 주막 = 기존 nw_jumak_naru(placement_namwon.json) — 새 건물 없음
const JZ := 484.16

static func L(x: float, z: float) -> Array: return [HX + x, HZ + z]    # 거처 기준 자리
static func J(x: float, z: float) -> Array: return [JX + x, JZ + z]    # 주막 기준 자리

static func data() -> Dictionary:
	return {
		"case": {
			"id": "main_p1", "record_title": "이겸의 수상한 편지", "region": "JL_NAMWON_UNBONG",
			"EVENT_CLASS": "MAIN_FRAME", "SOURCE_ID": "MAIN_FRAME_P1_LETTER", "outcome_var": "CASE_MAIN_P1_OUTCOME", "complete_key": "MAIN_P1",
			"requires": {},
			# 사건 등록부(case_registry.choose): 메인 — 진행 중인 독립 설화(오누이·춘향 도중 옛 저장)가 먼저, 목적지를 정하면(WAYPOINT_SET) 쉬는 자리
			"main": true, "rest_flag": "WAYPOINT_SET",
			"start_hour": 9.5, "start_event": "OP00", "start_on_arrival": true,   # 다른 공간에서 넘어온 옛 저장도 처음 만나면 합류(JOIN)
			"rule_label": "알아 둔 것",
			"reset_vars": ["CASE_MAIN_P1_OUTCOME", "CASE_MAIN_P1_COMPLETE"],
			# 대화 카메라(CAM_TALK_2 — 2단계 talk_frame): 공통 값 그대로
			"talk_camera": true,
			# 안내(첫15 §07): 이동 안내는 실제 3m 걸으면 끝(오누이는 5m 그대로 — onboarding.MOVE_M)
			"onboard": { "move_m": 3.0, "journal_close": true },   # 기록책은 실제로 열고 닫아야 끝(첫15 §07)
			"BASE_VERSION": "메인 스토리 시나리오 1부 S1.0 서장(창작 메인 프레임)",
			"ENTRY": "새 게임. 남원 읍내 이겸의 거처에서 스승의 흔적을 살피다가 수상한 편지를 받는다.",
			"CONTINUITY": "편지를 의심하고 솔잎 주막에서 스승의 마지막 숙박과 '여원재 쪽 행선지'를 확인해 지도에 목적지를 정한다. 운봉·백운은 후속.",
			"GAME_ADAPTATION": "튜토리얼(이동·조사·대화·기록책·지도·목적지)을 설명 창 없이 사건 맥락에서 실제 행동으로 끝낸다. 위조자는 이 서장에서 정하지 않는다.",
		},
		"items": { LETTER: "출처 미확인 편지", COIN: "엽전", "ITM_TOOL_009": "사건 기록책" },
		"hidden_items": ["ITM_TOOL_009"],
		"clues": clues(),
		"rules": {},
		"anchors": anchors(),
		"actors": actors(),
		"objects": objects(),
		"documents": documents(),
		"triggers": triggers(),
		"props": props(),
		"map_places": map_places(),
		"map_leads": map_leads(),
		"journal": journal(),
		# 솔잎 주막 앞마당(주모·손님·장부 자리)에는 고을 사람을 세우지 않는다(겹침 — 제작 규칙 C63 비우기 구역). 다른 길은 그대로
		"ambient_exclude": [{ "id": "solip_yard", "rect": [JX - 6.5, JZ + 2.0, JX + 6.5, JZ + 7.0], "when": "true" }],
		"events": events(),
	}

static func clues() -> Dictionary:
	return {
		# P00-A 방 물건(첫15 대사 — 붓만 신규)
		"ledger": { "title": "밥값 장부", "text": "“국 두 그릇. 제자 몫은 내가 냄… 아니다, 둘 다 내가 냄.” 글씨는 늘 이렇게 고치셨다.", "kind": "fact" },
		"shoes": { "title": "다시 기운 신발", "text": "뒤축을 또 기웠다. 걷는 데 문제없다더니.", "kind": "fact" },
		"brush": { "title": "말려 둔 붓", "text": "창가에 붓 셋을 말려 두었다. 하나는 끝이 갈라졌는데도 버리지 않으셨다.", "kind": "fact" },   # 신규 대사
		# P01-A 편지(첫15·메인 대본 P01-A 전문)
		"letter": { "title": "이겸의 이름으로 온 편지", "text": "“나는 며칠 떠나 신선의 가르침을 구하겠노라. 걱정하지 말고 기다려라. 이 산의 일은 모두 내 뜻이니 남에게 책임을 묻지 말라. — 이겸” 산 아래 주막에서 심부름꾼이 가져왔다. 보낸 이는 확인하지 못했다.", "kind": "fact" },
		"messenger": { "title": "심부름꾼의 말", "text": "“산 아래 주막에서 전하라 했습니다. 이름을 두 번 묻더군요.”", "kind": "heard", "by": "심부름꾼" },
		# P01-B 견주기(문서 비교 짝 — documents.gd pair). 셋 중 둘이면 LETTER_SUSPICIOUS(메인 대본 P01-B)
		"cmp_date": { "title": "날짜가 없다", "text": "스승은 길을 나설 때마다 날짜부터 적었다. 이 편지에는 날짜가 없다.", "kind": "fact" },
		"cmp_way": { "title": "방향이 없다", "text": "옛 기록은 어느 길로 가는지 적는다. 편지는 ‘며칠 떠나’뿐이다.", "kind": "fact" },
		"cmp_blame": { "title": "‘남에게 책임을 묻지 말라’", "text": "옛 기록은 본 것과 들은 것을 나눠 적는다. 편지는 본 이도 들은 이도 없이 누구 탓도 하지 말라고만 한다.", "kind": "fact" },
		"suspicious": { "title": "수상한 편지", "text": "글씨 모양은 비슷하다. 하지만 스승이라면 날짜와 방향, 본 것과 들은 것을 적었을 것이다. 누가 대신 썼는지는 모른다 — 확인은 아직이다.", "kind": "guess" },
		# P02 솔잎 주막
		"tv_jumo": { "title": "주모의 말", "text": "“산 아래에서 책장수를 만났다가, 여원재 쪽 행선지를 묻더군.”", "kind": "heard", "by": "주모" },
		"tv_last": { "title": "마지막 숙박", "text": "솔잎 주막 숙박 장부 — 이겸, 하룻밤 묵음. 국값 줄에 스승의 고쳐 쓴 글씨.", "kind": "fact" },
		"tv_baekun": { "title": "백운 도사 소문", "text": "“백운 도사라는 자가 고개 너머에 나타났대.”", "kind": "heard", "by": "손님" },
	}

static func anchors() -> Dictionary:
	return {
		# 이겸의 거처(실내 x −2.9~2.9, z −1.9~1.95 — kit/village/choga.gd interior). 상자(왼쪽 뒤)·소반(오른쪽 뒤)·등잔은 키트 것
		"home_start": L(0.55, 0.55), "home_center": L(0.0, 0.0), "home_wide": L(0.0, 2.6),
		"desk": L(-0.6, -1.3), "desk_front": L(-0.55, -0.35), "ledger": L(0.75, -1.05), "brush": L(-2.0, 1.72), "shoes": L(1.95, 2.6),
		"door": L(0.0, 2.15), "threshold": L(-0.55, 2.38), "yard": L(0.0, 4.9), "messenger": L(1.25, 5.3), "yard_front": L(0.0, 6.75),
		"street": L(0.0, 8.6),
		# 솔잎 주막(nw_jumak_naru, kit/village/jumak.gd 앵커: jumo · guest_seat) — 앞마당 3~4m 비움(첫15 §04)
		"solip": J(0.0, 2.0), "solip_jumo": J(3.0, 5.15), "solip_guest": J(-2.7, 5.75), "solip_guest2": J(-4.3, 3.45), "solip_ledger": J(-1.2, 2.32),
		"solip_front": J(0.0, 7.2), "solip_sign": J(5.1, 4.8),
		# 남원 남문(완월루) 앞 — 골목 끝 소리 안내 자리
		"south_gate": [-3228.0, 344.0],
		# 북문 밖 전주길 갈림길(namwon_north_road · 여단 오솔길 갈림, 기름집 맞은편) — 오누이 v3.4 F3401 행상
		"north_fork": [-3209.0, 63.0],
		# 여원재 방면(재기획 §6 여원재 아랫주막 — 첫 15분에는 가지 않는다. 지도 목적지 후보)
		"yeowon": [-322.08, -889.46],
	}

# 오누이 v3.4 F3401 — 북쪽 갈림길의 소문(대사 그대로). 들어가겠다고 해야 사건이 선다(메인을 막지 않는다)
static func peddler_talk() -> Array:
	return [
		{ "when": "v('CASE_NAMWON_COMPLETE')", "steps": [{ "say": "행상", "lines": ["고개가 다시 열렸다길래 이리로 다니오."] }] },   # 신규 대사(오누이 끝난 뒤)
		{ "when": "true", "steps": [
			{ "say": "행상", "lines": ["고개 건너 떡 팔러 다니던 아낙이 사흘째 돌아오지 않았소."] },
			{ "say": "나그네", "lines": ["집에 남은 사람은 있습니까?"] },
			{ "say": "행상", "lines": ["아이 둘이오. 이웃이 끼니를 챙긴다는데, 밤은 영 걱정이지."] },
			{ "choice": "", "options": [
				{ "label": "고개 너머 그 집에 가 보겠소.  (「산길의 실종」을 시작한다)", "do": [{ "call": "enter_onui" }] },
				{ "label": "지금은 가던 길을 가겠소.", "end": true }] }] },
	]

static func actors() -> Array:
	return [
		# P01-A 심부름꾼(열너댓 살 — 메인 대본). 문 두드린 뒤 마당에, 거처를 떠나 제목이 뜨면 돌아간다
		{ "id": "messenger", "kind": "courier", "name": "심부름꾼", "at": "messenger", "facing": "up",
			"when": "f('KNOCKED') and not f('TITLE_IN_WORLD_SEEN')",
			"talk": [
				{ "when": "not f('TALK_SEEN')", "steps": [
					{ "flag": "TALK_SEEN" },
					{ "say": "심부름꾼", "lines": ["남원 이겸 어른의 제자께 전하라더이다. 혹시 이름을 잘못 듣고 온 건 아니겠지요?"] },   # 메인 대본 P01-A
					{ "choice": "", "options": [
						{ "label": "누가 보냈지?", "do": [
							{ "say": "심부름꾼", "lines": ["산 아래 주막에서 전하라 했습니다. 이름을 두 번 묻더군요."] },
							{ "say": "심부름꾼", "lines": ["전 전하란 말만 듣고 왔는걸요."] }] },   # 메인 대본 [분기] 탓하면
						{ "label": "어디서 왔지?", "do": [
							{ "say": "심부름꾼", "lines": ["산 아래 주막에서 전하라 했습니다. 이름을 두 번 묻더군요."] },
							{ "say": "심부름꾼", "lines": ["주막 간판은 솔잎 그림이었습니다."] }] },   # 메인 대본 [분기]
						{ "label": "숨부터 고르고.", "do": [
							{ "caption": "심부름꾼이 숨을 고른다.", "sec": 1.2 },
							{ "say": "심부름꾼", "lines": ["산 아래 주막에서 전하라 했습니다. 이름을 두 번 묻더군요.", "주막 간판은 솔잎 그림이었습니다."] }] }] },
					{ "clue": "messenger" },
					{ "discover": "solip_jumak" },   # 메인 대본: 어느 경우든 근처 주막 위치를 지도에 표시
					{ "say": "심부름꾼", "lines": ["봉투는 문턱에 두었습니다."], "when": "not f('LETTER_RECEIVED')" }] },   # 신규 대사(봉투 자리)
				{ "when": "true", "steps": [{ "say": "심부름꾼", "lines": ["솔잎 그림 간판이오. 광한루 앞 나루 길가요."] }] },   # 신규 대사
			] },
		# P02-A·B 솔잎 주막 — 주모(첫15 대사)·손님(백운 소문)·짚신 묶는 손님(장면만)
		{ "id": "solip_jumo", "kind": "innkeeper", "name": "주모", "at": "solip_jumo", "facing": "left",
			"talk": [
				{ "when": "not f('TAVERN_TALK')", "steps": [
					{ "say": "주모", "lines": ["이겸이라면… 국값까지 적던 선비 아닌가."] },
					{ "choice": "", "loop": true, "options": [
						{ "label": "마지막으로 어디서 보셨소?", "when": "not f('tq_last')", "do": [{ "flag": "tq_last" }, { "flag": "TAVERN_TALK" },
							{ "say": "주모", "lines": ["산 아래에서 책장수를 만났다가, 여원재 쪽 행선지를 묻더군."] }, { "clue": "tv_jumo" }] },
						{ "label": "누구와 만났소?", "when": "not f('tq_who')", "do": [{ "flag": "tq_who" },
							{ "say": "주모", "lines": ["도술책 팔던 장사꾼이지. 아주 입이 달았어. 안 사면 복이 달아난다나."] }] },   # 메인 대본 P02-A ②
						{ "label": "고맙소.", "when": "f('TAVERN_TALK')", "end": true }] },
					{ "say": "주모", "lines": ["직접 본 건 숙박 장부뿐이오. 누구와 갔는지는 들은 말이지."] }] },   # 첫15 P02-B
				{ "when": "true", "steps": [
					{ "say": "주모", "lines": ["직접 본 건 숙박 장부뿐이오. 누구와 갔는지는 들은 말이지."] },
					{ "say": "주모", "lines": ["장부는 저 기둥에 걸려 있소."], "when": "not c('tv_last')" }] },   # 신규 대사
			] },
		{ "id": "solip_guest", "kind": "traveler", "name": "손님", "at": "solip_guest", "facing": "right",
			"talk": [
				{ "when": "not c('tv_baekun')", "steps": [
					{ "say": "손님", "lines": ["백운 도사라는 자가 고개 너머에 나타났대."] }, { "clue": "tv_baekun" }, { "call": "tavern_clue" }] },
				{ "when": "true", "steps": [{ "say": "손님", "lines": ["나도 들은 말이오. 본 건 아니고."] }] },   # 신규 대사
			] },
		{ "id": "solip_guest2", "kind": "villager_m", "name": "짚신 손님", "at": "solip_guest2", "facing": "down" },
		# 북문 밖 갈림길 행상 — 오누이 들머리(D1)
		{ "id": "peddler", "kind": "peddler", "name": "행상", "at": "north_fork", "facing": "left", "talk": peddler_talk() },
	]

# 방 물건(첫15 P00-A — 자유 선택, 2.4m) · 봉투 · 서안 · 주막 장부
static func objects() -> Array:
	return [
		{ "id": "o_ledger", "at": "ledger", "label": "밥값 장부 · 살펴보기", "radius": 1.6, "when": "not c('ledger')", "highlight": "tutorial_high",
			"steps": [{ "call": "inspect_room", "args": ["ledger"] }] },
		{ "id": "o_shoes", "at": "shoes", "label": "신발 · 살펴보기", "radius": 1.6, "when": "not c('shoes')", "highlight": "tutorial_high",
			"steps": [{ "call": "inspect_room", "args": ["shoes"] }] },
		{ "id": "o_brush", "at": "brush", "label": "붓 · 살펴보기", "radius": 1.6, "when": "not c('brush')", "highlight": "tutorial_high",
			"steps": [{ "call": "inspect_room", "args": ["brush"] }] },
		# P01-A 문턱의 봉투(재기획 OP-02 'E로 봉투를 조사' — 심부름꾼이 두고 마당에서 숨을 고른다)
		{ "id": "o_envelope", "at": "threshold", "label": "봉투 · 열어 보기", "radius": 1.8, "when": "f('KNOCKED') and not f('LETTER_RECEIVED')", "highlight": "tutorial_high",
			"steps": [{ "call": "read_letter" }] },
		# P01-B 서안 — 옛 기록과 편지 견주기(문서 비교, 덮었다가 다시 열 수 있다)
		{ "id": "o_desk", "at": "desk", "label": "서안 · 옛 기록과 편지 견주기", "radius": 1.7, "when": "f('LETTER_RECEIVED') and not f('LETTER_SUSPICIOUS')", "highlight": "tutorial_high",
			"steps": [{ "call": "compare_letter" }] },
		# P02-B 솔잎 주막 숙박 장부(확인된 사실 — ◆)
		{ "id": "o_solip_ledger", "at": "solip_ledger", "label": "숙박 장부 · 읽기", "radius": 1.8, "when": "f('TAVERN_NEAR') and not c('tv_last')",
			"steps": [{ "call": "tavern_ledger" }] },
	]

# 문서 비교(scripts/story/documents.gd) — 세로쓰기는 오른쪽 줄부터. 짝(pair) 셋 가운데 둘을 양쪽에서 짚으면 LETTER_SUSPICIOUS
static func documents() -> Dictionary:
	return {
		"old_record": { "title": "스승의 옛 기록", "short": "옛 기록", "aspect": 1.36, "seed": 3161,
			"paper": { "base": "#e8dcbc", "fiber": 0.6, "fiber_col": "#8a7656", "lines": 6, "line_col": "#9a6a5060" },
			"cols": [
				{ "x": 0.86, "y": 0.07, "text": "구월 열이틀 맑음", "size": 0.062, "ink": 0.95 },
				{ "x": 0.72, "y": 0.07, "text": "남원 동문 밖 동쪽 큰길로", "size": 0.058, "ink": 0.92 },
				{ "x": 0.58, "y": 0.07, "text": "짚신 손님에게 들음 내가 보지 못함", "size": 0.052, "ink": 0.9 },
				{ "x": 0.44, "y": 0.07, "text": "국 두 그릇 내가 냄", "size": 0.058, "ink": 0.9, "bleed": 0.3 },
				{ "x": 0.30, "y": 0.07, "text": "모르는 것은 모른다고 적는다", "size": 0.055, "ink": 0.88 },
			],
			"hotspots": [
				{ "id": "o_date", "rect": [0.81, 0.04, 0.1, 0.62], "label": "날짜", "text": "길을 나선 날과 날씨부터 적었다.", "pair": "cmp_date" },
				{ "id": "o_way", "rect": [0.67, 0.04, 0.1, 0.8], "label": "방향", "text": "어느 문으로 나가 어느 길로 갔는지.", "pair": "cmp_way" },
				{ "id": "o_witness", "rect": [0.53, 0.04, 0.1, 0.9], "label": "들은 것 · 본 것", "text": "누구에게 들었는지, 직접 보지 못한 것까지 나눠 적었다.", "pair": "cmp_blame" },
			] },
		"letter": { "title": "이겸의 이름으로 온 편지", "short": "새 편지", "aspect": 1.36, "seed": 3162,
			"paper": { "base": "#f3eddc", "fiber": 0.25, "fiber_col": "#a49478" },
			"cols": [
				{ "x": 0.80, "y": 0.18, "text": "나는 며칠 떠나", "size": 0.06, "ink": 0.97 },
				{ "x": 0.67, "y": 0.18, "text": "신선의 가르침을 구하겠노라", "size": 0.056, "ink": 0.97 },
				{ "x": 0.54, "y": 0.18, "text": "걱정하지 말고 기다려라", "size": 0.056, "ink": 0.97 },
				{ "x": 0.41, "y": 0.18, "text": "이 산의 일은 모두 내 뜻이니", "size": 0.054, "ink": 0.97 },
				{ "x": 0.28, "y": 0.18, "text": "남에게 책임을 묻지 말라", "size": 0.056, "ink": 0.97 },
				{ "x": 0.15, "y": 0.62, "text": "이겸", "size": 0.062, "ink": 0.97 },
			],
			"hotspots": [
				{ "id": "l_nodate", "rect": [0.84, 0.02, 0.14, 0.15], "label": "날짜 자리", "text": "첫 줄 위가 비었다. 날짜도 날씨도 없다.", "pair": "cmp_date" },
				{ "id": "l_days", "rect": [0.75, 0.16, 0.1, 0.5], "label": "‘며칠 떠나’", "text": "어디로, 어느 길로 가는지가 없다.", "pair": "cmp_way" },
				{ "id": "l_blame", "rect": [0.23, 0.16, 0.1, 0.8], "label": "‘남에게 책임을 묻지 말라’", "text": "본 이도 들은 이도 없이, 누구 탓도 하지 말라고만 한다.", "pair": "cmp_blame" },
			] },
	}

static func triggers() -> Array:
	return [
		# P02-A 길 안내(첫15 OP01 '주막 안내는 골목 끝 소리·간판·지도'): 남문 앞에 오면 나루 쪽에서 웃음소리 한 번
		{ "id": "solip_sound", "at": "south_gate", "radius": 22.0, "when": "ph('town') and not f('TAVERN_NEAR')", "steps": [{ "sfx": "laugh_far", "at": "solip_jumo" }] },
		# 주막 앞마당 16m — 사발 소리, 주모 머리 위 「…」(onboarding talk marks), 장부가 E 대상이 된다
		{ "id": "solip_near", "at": "solip", "radius": 16.0, "when": "not f('TAVERN_NEAR')", "steps": [{ "flag": "TAVERN_NEAR" }, { "sfx": "cup_clink", "at": "solip_jumo" }] },
	]

static func props() -> Array:
	return [
		{ "id": "p_desk", "kit": "story/clue", "params": { "kind": "seoan", "seed": 3171 }, "at": "desk", "ry": 0.0, "dy": 0.4 },
		{ "id": "p_ledger", "kit": "story/clue", "params": { "kind": "ledger", "seed": 3172 }, "at": "ledger", "ry": 0.4, "dy": 0.77 },
		{ "id": "p_brush", "kit": "story/clue", "params": { "kind": "brush", "seed": 3173 }, "at": "brush", "ry": 0.0, "dy": 1.28 },
		{ "id": "p_shoes", "kit": "story/clue", "params": { "kind": "sandal", "seed": 3174 }, "at": "shoes", "ry": 0.3, "dy": 0.12 },
		{ "id": "p_envelope", "kit": "story/clue", "params": { "kind": "ledger", "seed": 3175 }, "at": "threshold", "ry": -0.2, "dy": 0.42,
			"when": "f('KNOCKED') and not f('LETTER_RECEIVED')" },
		{ "id": "p_solip_ledger", "kit": "story/clue", "params": { "kind": "ledger_hang", "seed": 3176 }, "at": "solip_ledger", "ry": 0.0, "dy": 1.25 },
	]

static func map_places() -> Array:
	return [
		{ "id": "iegyeom_house", "name": "이겸의 거처", "at": "home_center", "building": true, "radius": 8.0, "start_known": true },
		{ "id": "solip_jumak", "name": "솔잎 주막", "at": "solip", "building": true, "radius": 12.0, "known": "f('TALK_SEEN') or f('LETTER_SUSPICIOUS')" },
		{ "id": "yeowon", "name": "여원재 방면", "at": "yeowon", "radius": 40.0, "known": "f('TAVERN_CLUE')" },
		{ "id": "north_fork", "name": "북문 밖 갈림길", "at": "north_fork", "radius": 14.0 },
	]

# 지도 붉은 표 — waypoint: true면 [목적지 설정]을 고를 수 있다(지도 v1.3 최소판 — 4단계에서 상세 카드로)
static func map_leads() -> Array:
	return [
		{ "id": "mp_home", "name": "이겸의 거처", "at": "home_center", "hub": true, "when": "true", "until": "f('LETTER_SUSPICIOUS')",
			"note": "새 게임 시작 자리(OP00) — 편지를 의심하면 사라진다" },
		{ "id": "mp_solip", "name": "솔잎 주막", "at": "solip", "when": "f('TALK_SEEN') or f('LETTER_SUSPICIOUS')", "until": "f('TAVERN_TALK')", "waypoint": true,
			"note": "심부름꾼 “주막 간판은 솔잎 그림이었습니다.”(메인 대본 — 어느 경우든 지도에) · 편지를 의심한 뒤에도" },
		{ "id": "mp_yeowon", "name": "여원재 방면", "at": "yeowon", "when": "f('TAVERN_CLUE')", "until": "false", "waypoint": true, "frame": true,
			"note": "첫15 P02-B 장부 또는 손님 → '여원재 방면' 후보(KNOWN_NOT_VISITED). 목적지 설정(P02-C)" },
	]

static func journal() -> Dictionary:
	return {
		"unknowns": [
			{ "text": "스승은 어디로 가셨는가.", "until": "f('TAVERN_CLUE')" },
			{ "text": "편지는 정말 스승이 쓴 것인가.", "when": "f('LETTER_RECEIVED')" },
			{ "text": "산 아래 주막에서 편지를 맡긴 이는 누구인가.", "when": "c('messenger')" },
		],
		"places": [
			{ "name": "이겸의 거처", "when": "true" },
			{ "name": "솔잎 주막", "when": "f('TAVERN_NEAR')" },
		],
		"items": [{ "id": LETTER, "when": "f('LETTER_RECEIVED')" }],
	}

static func _ev(id: String, trigger: String, loc: String, tw: String, actions: String, steps: Array) -> Dictionary:
	return {
		"EVENT_ID": id, "EVENT_CLASS": "MAIN_FRAME", "RECORD_TITLE": "이겸의 수상한 편지", "SOURCE_ID": "MAIN_FRAME_P1_LETTER",
		"MAIN_FRAME_ORIGIN_NOTE": "메인 스토리 시나리오 1부 S1.0 서장(이겸의 편지·솔잎 주막) — 창작 메인 프레임. 실제 전승 사건이 아니다.",
		"FOLKLORE_ECHO_IDS": [], "FOLKLORE_ANCHOR_IDS": [], "FOLKLORE_ANCHOR_MODE": "",
		"TRIGGER": trigger, "LOCATION_TYPE": loc, "TIME_WEATHER": tw, "PLAYER_ACTIONS": actions, "RESOLUTION_BRANCHES": "-", "WORLD_STATE_CHANGE": "-",
		"steps": steps,
	}

static func events() -> Dictionary:
	return {
		# OP00 — 새 게임(첫15 OP00 · D7 12초 안 조작). 옛 저장(오누이를 지난 사람)이 처음 이 사건을 만나면 JOIN(여는 장면 없이 합류)
		"OP00": _ev("OP00", "새 게임", "남원 읍내 이겸의 거처(실내)", "오전 09:30 · 맑음", "걷는다 · 방 물건을 살핀다",
			[{ "call": "open" }]),
		"P00B": _ev("P00B", "방 물건 셋을 다 살핌", "이겸의 거처", "오전", "짧은 기억(건너뛸 수 있다)", [{ "call": "flashback" }]),
		"P01B": _ev("P01B", "편지를 받은 뒤 서안", "이겸의 거처", "오전", "옛 기록과 편지를 견준다", [{ "call": "compare_letter" }]),
		"P02C": _ev("P02C", "여원재 방면이 지도에 적힌 뒤", "남원 — 지도", "낮", "M 지도 · 목적지 설정", []),
	}
