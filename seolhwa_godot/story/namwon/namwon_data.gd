# 사건 「산길의 실종」(ACT 0 남원, S0001~S0010) — 이야기 데이터.
# 시나리오: seolhwa/docs/scenario/seolhwarok_master_scenario_storyboard_v2.1_folklore_only_subevents.md §8 (규칙 §1, 대사 §27, 컷신 §28, 실패 §29, 지역 변화 §30)
# 웹 프로토타입(seolhwa/src/story/case_sanggil.js·dialogue.js)의 흐름·규칙(범의 버릇 K_*)·세 결말을 옮기고, 대사는 시나리오에 맞춰 줄였다.
# v3 재작업(seolhwa/docs/scenario/seolhwarok_DIRECTION_v3.0_tale_intervention.md §3·§5·§8): 조사 도입부는 그대로 두고, 밤부터는 원작 장면을
#   화면에서 겪는다(FIXED_BEATS). 원작 인물의 핵심 행동(문 앞 속임수에 맞서기·탈출·거짓말·동아줄 빌기)은 오누이가 하고,
#   플레이어는 범을 죽이지 않는다. 세 갈래 A/B/C는 오누이가 다음 장면으로 갈 시간을 버는 방법이다(CASE_NAMWON_OUTCOME은 그대로 A/B/C).
# v3.2(seolhwa/docs/scenario/seolhwarok_NAMWON_v3.2_scenario.md, 착수 순서 3 — ACT 0~2): 여는 장면·이동/달리기/살펴보기 안내 ·
#   주막 주모 묻기(choice·loop·when·flag — 새 엔진 없음) · 이겸 연결 · 역참 마부 · 외딴집 낮(이웃 아낙·오누이 세 물음·기도 복선·아궁이·함지).
#   함지 회상(mother_flashback)은 없앴고, 밤은 주막 잠이 아니라 외딴집에서 해 지기를 기다려 넘어간다.
# v3.2 착수 순서 4 — ACT 3~5(§15~§30): 고갯길 단서(6~8m 먹빛·발견 때 카메라 잠깐 기울임·떡 셋의 말·치맛자락 인서트·피·발자국 따라가기·
#   서낭당 광주리 CAMERA 3A) → 어머니의 과거 장면(CAMERA 3B, 기록하지 않음) → 첫 조우(트리거·공포·CAMERA 4A·전투 배우기 K·L) →
#   포수 물음 → 방앗간 물음·밀가루 바닥 → 연결 추론(§29) → 외딴집 쪽 흰 발자국(§30, 목적이 '보호'로).
# v3.2 착수 순서 5 — ACT 6~9(§31~§50): 해 질 무렵 귀환(dusk_return)·경고·포수와 역할 나누기 → 준비(디딤돌 기름·떡·횃불) → hide_spot “기다린다” →
#   S0007 밤의 문(첫 노크 7A·7B·7C → 조작 → 둘째 노크 → 누이가 정한 탈출 → 문이 열린 뒤 처음 전신) → 시간 벌기(A/B/C, 밀쳐냄) → 우물·참기름·도끼 →
#   마지막 개입 → S0009(기존 동아줄 ACT 10~). 옛 dusk_wait·night_fall 다리와 옛 밤 들머리는 없앴다.
# ID: CHARACTER/ITEM/PROP_MASTER v1.0.
#
# 자리(게임 좌표 x,z — JL_NAMWON_UNBONG): 남원 동문 밖 주막 → 읍성 → 북문 → 북쪽 어귀(장승·쉼터, 포수) → 고개(서낭당) →
#   고개 너머 숲가 외딴집(오누이)·물레방앗간·서쪽 숲 빈터(범의 영역). 건물은 region_data/JL_NAMWON_UNBONG/placement_story_namwon.json.
# 조건식은 story_runner.gd의 짧은 함수(f 플래그, k 버릇, c 단서, has/n 소지품, ph 국면, v 변수, out 결말, w 지역 상태, fn 사건 함수)를 쓴다.
extends RefCounted

const InteractData := preload("res://scripts/story/interact_data.gd")
const TTEOK := "ITM_LIFE_001"
const OIL := "ITM_LIFE_002"
const TORCH := "ITM_TOOL_002"
const COIN := "COIN"

# v3 §8 — 화면에서 반드시 일어나는 원작 장면(순서대로)
const FIXED_BEATS := [
	{ "id": "mother_harmed", "text": "떡 하나 주면 안 잡아먹지 — 범이 고갯길에서 떡장수 어머니를 해친다(광주리·떡 흔적·옷으로만)" },
	{ "id": "tiger_disguise", "text": "범이 어머니 옷을 걸치고 어머니 행세로 오누이 집에 다가온다" },
	{ "id": "door_tricks", "text": "문 앞 속임수 — 거친 목소리, 털 난 손, 밀가루 바른 손" },
	{ "id": "kids_escape_tree", "text": "오누이가 뒷간 핑계로 빠져나가 우물가 나무에 오른다" },
	{ "id": "well_reflection", "text": "범이 우물에 비친 오누이를 본다" },
	{ "id": "kids_lies", "text": "누이 “참기름을 바르고 올라왔지” — 아우가 “도끼로 찍고…” 하고 말해 버린다" },
	{ "id": "kids_prayer", "text": "오누이가 하늘에 동아줄을 빈다" },
	{ "id": "new_rope_rise", "text": "새 동아줄이 내려오고 오누이가 하늘로 오른다" },
	{ "id": "tiger_rotten_rope", "text": "범도 줄을 청한다 — 썩은 동아줄, 수수밭으로 떨어짐, 수숫대가 붉어짐" },
	{ "id": "sun_moon", "text": "하늘에 두 빛이 자리 잡는다(해와 달 — 인물로 그리지 않는다)" },
]

static func data() -> Dictionary:
	return {
		"case": {
			"id": "namwon", "record_title": "산길의 실종", "EVENT_CLASS": "FOLKLORE_EVENT", "SOURCE_ID": "F49", "CATALOG_ID": "JG01", "region": "JL_NAMWON_UNBONG", "outcome_var": "CASE_NAMWON_OUTCOME",
			"start_hour": 9.5,
			# v3.2 §8 CAMERA 1A — 이 사건 이야기 인물과 말할 때의 기준 카메라(플레이어와 인물 사이, 허리 위 클로즈업까지 가지 않는다)
			"talk_camera": { "pitch": 38.0, "distance": 13.5, "fov": 38.0 },
			# 도입부(보강서 v1.0 §3~§9): S0000 남원으로 가는 길 → S0001 남원 전경·첫 자유 이동
			"start_event": "S0000",
			# 첫 사건 단서 안내 단계(§14·§28): 0 첫 단서 전 · 1 첫 단서 · 2 둘째 · 3 일반 조사 — scripts/story/onboarding.gd 먹점
			"guidance_flag": "CASE_NAMWON_GUIDANCE_STAGE",
			# 새로 시작할 때 되돌릴 공통 변수(story_state 기본 목록 + 결말 세부 — 지난 판 결말 글이 기록책에 남지 않게)
			"reset_vars": ["CASE_NAMWON_OUTCOME", "CASE_NAMWON_DETAIL", "MAIN_MASTER_TRACE", "SKILL_BEAST_TRACE", "SKILL_GUARD_SHOVE", "CASE_NAMWON_COMPLETE"],
			# 제작자용 판본 기준(v3 §3.1·§3.2 — 플레이어에게 보이지 않음)
			"ENTRY": "고갯길에서 떡장수 어머니의 실종에 휘말린다.",
			"CONTINUITY": "어머니를 찾는 길이 곧 오누이 집으로 이어진다. 하룻밤 안에 끝난다.",
			"BASE_VERSION": "구전 일반형(전국) 「해와 달이 된 오누이」",
			# 플레이어가 무엇을 하든 이 순서로 화면에서 일어난다. 사건 스크립트가 beat(id)로 남기고(flags beat_<id>), 대본 시험이 순서를 본다.
			"FIXED_BEATS": FIXED_BEATS,
			"OPTIONAL_VARIANTS": "수숫대가 붉은 내력(씀). 해와 달을 서로 바꾸는 대목(쓰지 않음 — 누가 해가 되었는지 말하지 않는다). 우물에 비친 그림자(씀). 범이 아기를 해치는 대목(쓰지 않음).",
			"GAME_ADAPTATION": "조사 도입부(실종 → 고갯길 흔적 → 첫 조우 → 마을 조사 → 밤의 외딴집)를 원작 앞에 붙였다. 어머니를 해치는 대목은 사흘 전 일이라 고갯마루의 짧은 회상(실루엣)으로 보인다. 손님이 범 앞을 막는 세 갈래(싸움·디딤돌 기름·떡과 횃불)를 오누이가 나무에 오르는 사이에 넣었다. 마을이 오누이를 거두는 결말은 없다.",
		},
		"items": {
			TTEOK: "떡", OIL: "참기름", TORCH: "횃불", COIN: "엽전",
			"ITM_TOOL_009": "사건 기록책", "ITM_WPN_001": "환도", "ITM_WPN_002": "활", "ITM_AMMO_001": "화살",
		},
		"hidden_items": ["ITM_TOOL_009", "ITM_WPN_001", "ITM_WPN_002", "ITM_AMMO_001"],
		"clues": {
			"rumor": { "title": "떡장수 어미의 실종", "text": "고개 너머 사는 떡장수가 장에 갔다가 사흘째 돌아오지 않는다.", "kind": "heard", "by": "주모",
				"by_if": [["fn('route_is', 'kids')", "누이"]] },
			"kids_story": { "title": "오누이의 말", "text": "어머니는 장에 갔다. 해 지기 전엔 온다고 했다. 집에는 아이 둘만 남아 있다.", "kind": "heard", "by": "누이" },
			"cold_hearth": { "title": "식은 아궁이", "text": "재가 완전히 식었다. 이웃이 가져다주는 음식 말고는 며칠째 불을 쓰지 않은 것 같다.", "kind": "fact" },
			"mother_route": { "title": "떡가루 묻은 함지", "text": "실종 당일 새벽에도 떡을 만들어 장으로 갔다.", "kind": "heard", "by": "누이" },
			# v3.2 §12 — 들은 대로만. 흉내(K_MIMIC)라고 아직 정하지 않는다
			"voice_at_night": { "title": "어젯밤의 목소리", "text": "문밖에서 어머니를 닮은 목소리가 들렸다.", "kind": "heard", "by": "누이" },
			# 수량이 아니라 뜻이 자란다(§15): 하나 → 같은 간격으로 이어짐 → 서낭당 빈 광주리에서 끝남
			# v3.2 §16~§18 — 하나 → 고갯길을 따라 이어짐(기록 갱신) → 하나씩 내놓은 것 같다 → 서낭당 빈 광주리에서 끝남(text_if는 맞는 마지막)
			"cakes": { "title": "고갯길의 떡", "text": "떡 하나가 흙에 반쯤 묻혀 있었다. 둘레 흙에 짐승 코 자국.", "kind": "fact",
				"text_if": [["fn('cakes_found') >= 2", "떡이 고갯길을 따라 이어진다."],
					["fn('cakes_found') >= 3", "떡이 고갯길을 따라 이어진다. 떨어뜨린 게 아니라 하나씩 내놓은 것 같다."],
					["fn('cakes_found') >= 2 and c('basket')", "떡이 고갯길을 따라 이어지다가, 서낭당 앞 빈 광주리에서 끝난다."]] },
			"torn_skirt": { "title": "찢어진 치맛자락", "text": "덤불에 쪽빛 천. 네 줄로 길게 찢어져 있다. 칼자국은 아니다.", "kind": "fact" },
			"blood": { "title": "마른 피", "text": "마른 피. 주변 풀이 한쪽으로 짓눌렸다.", "kind": "fact" },
			"tracks": { "title": "겹친 발자국", "text": "짚신 자국과 큰 짐승 발자국이 겹쳐 있다. 짚신 자국은 끊기고 큰 발자국만 이어진다.", "kind": "fact" },
			"basket": { "title": "서낭당 앞 빈 광주리", "text": "빈 광주리와 머리에 받치는 수건. 떡은 없다.", "kind": "fact" },
			# v3.2 §28 — 주인은 본 것만 말한다(왜 그런지는 말하지 않는다)
			"flour_sack": { "title": "찢긴 밀가루 자루", "text": "밤마다 방앗간 자루가 찢긴다. 먹지는 않는다.", "kind": "heard", "by": "방앗간 주인" },
			"flour_prints": { "title": "밀가루 바닥의 큰 발자국", "text": "방앗간 바닥에 쏟아진 밀가루 위로 큰 발자국. 앞발 자국만 유난히 하얗다.", "kind": "fact" },
			# v3.2 §30 — 흰 발자국이 외딴집 쪽으로(여기서 목적이 '보호'로 바뀐다)
			"white_trail": { "title": "집 쪽으로 난 흰 발자국", "text": "흰 가루 묻은 큰 발자국이 숲가 외딴집 쪽으로 이어진다.", "kind": "fact" },
			"hunter_word": { "title": "포수의 말", "text": "“산짐승이면 사람 냄새 나면 피하는 게 보통이오. 저건 안 그래.”", "kind": "heard", "by": "포수" },
			"claw_marks": { "title": "큰 나무의 긁힌 껍질", "text": "사람 키를 넘는 곳까지 깊이 긁혔다. 매끈한 옹이 자리에선 미끄러진 자국뿐이다.", "kind": "fact" },
			"territory": { "title": "숲속 빈터", "text": "뼈가 구르고 나무마다 발톱 자국. 어귀엔 타다 만 횃불 — 누군가 불로 몰아낸 적이 있는 것 같다.", "kind": "fact" },
			# v3.2 §26 — 기록: 고갯마루의 범
			"first_sight": { "title": "고갯마루의 범", "text": "나무 사이로 얼굴을 보았다. 뒤에서 덮쳐 왔고, 버티자 물러나 숲으로 사라졌다. 집채만 한 범이다.", "kind": "fact" },
			# v3 — 원작 장면(FIXED_BEATS)을 보고 들은 대로.
			# pass_memory는 옛 저장 표시용으로만 남긴다 — v3.2 §23 어머니의 과거 장면은 기록책이 '확인한 사실'로 적지 않는다(이제 얻지 않는다)
			"pass_memory": { "title": "사흘 전 고갯길", "text": "고개마다 범이 “떡 하나 주면 안 잡아먹지” 하고 떡을 받아 갔다. 떡이 떨어진 서낭당 앞에서 떡장수는 돌아오지 못했다. 광주리와 수건만 남고 저고리는 없었다.", "kind": "guess" },
			"disguise_seen": { "title": "어머니 옷을 걸친 범", "text": "문이 밀려 열린 뒤에야 보았다. 떡장수의 저고리를 걸치고 머리에 수건을 쓴 범이었다.", "kind": "fact" },
			"door_tricks": { "title": "문 앞의 손", "text": "“엄마 왔다.” 목소리가 쉬었다. 문틈으로 내민 손엔 털이 숭숭했다. 범은 물러갔다가 가루 묻은 흰 손을 다시 내밀었다. 누이는 문을 열지 않았다.", "kind": "fact" },
			"kids_tree": { "title": "우물가 나무", "text": "누이가 먼저 “뒷문으로 가.” 하고 정했다. 오누이는 뒷간에 간다며 뒷문으로 빠져나가 우물가 나무에 올랐다.", "kind": "fact" },
			"reflection": { "title": "우물에 비친 얼굴", "text": "범은 우물에 비친 오누이를 보고 “거기 숨어 있었구나.” 했다. 아우가 킥 웃는 바람에 범이 고개를 들었다.", "kind": "fact" },
			"kids_lie": { "title": "참기름", "text": "“참기름을 바르고 올라왔지.” 범은 줄기에 기름을 바르고 오르다 미끄러지기만 했다.", "kind": "heard", "by": "누이" },
			"axe_slip": { "title": "도끼", "text": "“도끼로 찍고 올라오면 되는데.” 범은 도끼로 줄기를 찍어 발 디딜 데를 내며 올라왔다.", "kind": "heard", "by": "아우" },
			"prayer": { "title": "하늘에 빈 말", "text": "“하늘님, 저희를 살리시려거든 새 동아줄을 내려 주시고, 죽이시려거든 썩은 동아줄을 내려 주세요.”", "kind": "heard", "by": "누이" },
			"sky_rise": { "title": "새 동아줄", "text": "아이 둘이 하늘로 올라가는 것을 보았다.", "kind": "fact" },
			"rotten_rope": { "title": "썩은 동아줄", "text": "범도 같은 말로 줄을 빌었다. 내려온 것은 썩은 동아줄이었다. 범은 수수밭에 떨어졌고, 수숫대가 붉게 물들었다.", "kind": "fact" },
			"two_lights": { "title": "하늘의 두 빛", "text": "그날 밤, 하늘에 빛 둘이 자리를 잡았다.", "kind": "fact" },
		},
		"rules": {
			"K_FOOD": { "title": "먹이에 끌린다", "text": "떡을 하나씩 받아 간 것 같다. 먹을 것이 보이면 그쪽으로 갈지 모른다.", "kind": "guess" },
			# v3.2 §29 — 정답으로 정하지 않는다: 목소리·밀가루·첫 조우를 다 쥐었을 때 '그럴 수도 있다'로만(밤에 직접 보면 글이 자란다)
			"K_MIMIC": { "title": "아는 사람 목소리로 부르는지도 모른다", "text": "어젯밤 아이들이 들었다는 목소리와 이 범은 관계가 있을 수 있다. 아직 확인하지 못했다.", "kind": "guess",
				"text_if": [["c('door_tricks')", "문밖에서 어머니 목소리로 아이들을 불렀다. 목소리만으로는 믿을 수 없다."]] },
			"K_FLOUR": { "title": "앞발이 희다", "text": "밀가루를 밟은 앞발 자국만 유난히 하얗다. 왜 가루를 묻히는지는 모른다.", "kind": "guess",
				"text_if": [["c('door_tricks')", "밀가루를 바른 앞발을 문틈으로 내밀었다. 손을 보면 안다."]] },
			"K_CLIMB": { "title": "나무를 탄다", "text": "높이 오른다. 다만 미끄러운 줄기는 오르지 못한다.", "kind": "guess" },
			"K_TERRITORY": { "title": "숲속 빈터가 제 영역", "text": "숲속 빈터가 제 자리다. 불을 들이대면 잠시 그쪽으로 물러난다.", "kind": "guess" },
		},
		"anchors": anchors(),
		"arenas": {
			# 첫 조우(S0005): 고갯마루 아래 숲. 보스전 아님 — 피해를 주거나 물러나면 범도 물러난다
			"pass_wood": { "name": "고갯마루 아래 숲", "at": "player", "radius": 11.0, "tiger_offset": [-6.5, -7.0],
				"retreat_to": "territory", "camera": { "pitch": 46.0, "distance": 21.0, "fov": 30.0 } },
			# 마당(S0008 A·B): 큰 나무 포함, 지름 약 15m
			"house_yard": { "name": "외딴집 마당", "at": [-3212.5, -346.0], "radius": 7.5, "tiger_start": [-3219.0, -341.0], "player_start": [-3208.0, -349.5],
				"focus": "big_tree", "retreat_to": "territory", "camera": { "pitch": 46.0, "distance": 19.0, "fov": 30.0 } },
			# 범의 영역(숲속 빈터) — C에서 칼을 뽑으면 여기서
			"territory": { "name": "숲속 빈터", "at": "territory", "radius": 11.0, "tiger_start": [-3283.0, -400.0], "player_start": [-3264.0, -390.0],
				"camera": { "pitch": 48.0, "distance": 23.0, "fov": 30.0 } },
		},
		"actors": actors(),
		"objects": InteractData.expand(objects(), { TTEOK: "떡", OIL: "참기름", TORCH: "횃불" }),
		"map_places": map_places(),
		"map_leads": map_leads(),
		"journal": journal(),
		"triggers": triggers(),
		"props": props(),
		"events": events(),
	}

static func anchors() -> Dictionary:
	var a := _anchors()
	a.merge(_station_anchors())
	return a

# 남원 역참(region_data/stations.json "namwon" — 역참 작업이 정한 자리를 그대로 읽는다, 새 좌표를 만들지 않는다)
#   station_yard: 문 앞 길 점(말 타는 자리) · station_wait: 기다리는 말 자리(마부가 솔질하는 곳)
static func _station_anchors() -> Dictionary:
	var path := "res://region_data/stations.json"
	if not FileAccess.file_exists(path): return {}
	var j = JSON.parse_string(FileAccess.get_file_as_string(path))
	var list = j.get("stations", []) if j is Dictionary else j
	if not (list is Array): return {}
	for s in list:
		if s is Dictionary and String(s.get("id", "")) == "namwon" and s.has("yard"):
			return { "station_yard": s.yard, "station_wait": s.get("wait", s.yard) }
	return {}

static func _anchors() -> Dictionary:
	return {
		# S0000 남원으로 가는 길(동쪽 통영별로, 남원 동문에서 약 250m 밖) — 길가 짚신, 나그네 둘이 지나가는 곳, 전경이 열리는 곳
		"s0000_start": [-2898.5, 150.6], "s0000_sandal": [-2905.6, 153.6], "roadside": [-2905.6, 153.6], "s0000_rumor": [-2916.0, 159.5], "s0000_vista": [-2952.0, 184.0],
		"trav_from": [-2963.0, 193.0], "trav_mid": [-2927.2, 163.5], "trav_to": [-2876.0, 129.0],
		"main_road": [-2930.0, 166.0], "pass_road": [-3170.0, -176.0],
		# 남원
		"start": [-2952.0, 184.0], "yocheon_view": [-2960.0, 262.0], "jiri_view": [-2860.0, -420.0], "east_gate": [-3135.3, 248.8],
		"tavern": [-3005.0, 231.0], "jumo": [-3001.0, 227.6], "guest": [-3010.6, 228.4],
		"oil_shop": [-3220.1, 53.8], "oil_jars": [-3217.6, 53.4], "elder_town": [-3209.5, 38.0],
		"north_square": [-3196.0, -132.0], "hunter": [-3192.5, -133.5], "neighbor_after": [-3203.0, -127.5],
		# 고갯길 단서(S0004)
		"cake_1": [-3186.4, -138.4], "cake_2": [-3174.9, -162.4], "cake_3": [-3164.6, -184.3], "torn_skirt": [-3161.6, -199.4],
		"blood": [-3153.6, -215.3], "tracks": [-3158.8, -229.6], "tracks_end": [-3172.4, -249.6],
		"shrine": [-3147.5, -212.0], "basket": [-3148.6, -207.8], "offering": [-3148.2, -208.6], "first_seen": [-3157.0, -222.0],
		"merchant_a": [-3160.4, -190.0], "merchant_b": [-3166.5, -239.5],
		# 고개 너머
		"mill": [-3176.0, -318.0], "miller": [-3179.6, -313.4], "flour": [-3178.6, -314.6],
		# §30 방앗간 → 외딴집 흰 발자국(d_flour_trail 데칼과 같은 점)
		"white_trail_a": [-3190.0, -327.0], "white_trail_b": [-3200.0, -338.0], "white_trail_c": [-3207.0, -346.5],
		# §25 CAMERA 4A — 고갯마루 아래 숲 안쪽(범의 얼굴이 나무 사이로 잠깐)
		"glimpse": [-3166.0, -227.4],
		"house": [-3214.0, -357.0], "house_door": [-3214.0, -353.4], "hearth": [-3212.2, -356.4], "kneading": [-3216.0, -356.6],
		"kid_in_a": [-3215.6, -356.4], "kid_in_b": [-3213.6, -356.2], "yard": [-3212.5, -346.0],
		"big_tree": [-3205.5, -342.0], "claw": [-3205.5, -342.0], "perch_a": [-3205.0, -342.9], "perch_b": [-3206.2, -341.8],
		"barn": [-3223.5, -356.0], "barn_front": [-3223.5, -353.6],
		"yard_torch": [-3221.0, -339.6], "cake_bait": [-3222.0, -341.6], "hide_spot": [-3203.4, -351.0], "tiger_from": [-3233.0, -349.0],
		# v3 원작 장면: 쪽문 디딤돌 → 우물가 나무(오누이가 오른다) · 우물 · 동아줄 · 수수밭(범이 떨어진다)
		"back_step": [-3210.3, -357.0], "kids_run_1": [-3209.0, -353.0], "kids_run_2": [-3207.2, -346.4], "tree_foot": [-3205.9, -343.0],
		"well": [-3207.8, -343.8], "tiger_well": [-3208.4, -346.0], "tiger_tree": [-3203.6, -342.2],
		"rope_kids": [-3205.4, -342.5], "rope_tiger": [-3203.4, -342.4], "sorghum": [-3199.4, -347.6], "tiger_fall": [-3199.6, -347.2],
		"sky_watch": [-3210.4, -349.4],
		# v3.2 §43 C — 떡(cake_bait)과 나무 사이, 횃불을 들고 막아서는 자리
		"torch_block": [-3214.5, -343.2],
		# v3.2 §38·§40 문틈(툇마루 위 문지방) — 앞발이 들어오는 자리
		"door_sill": [-3214.0, -354.6],
		# 다음 날 아침 — 북쪽 어귀(마을 사람들이 빈 집 이야기를 한다)
		"neighbor_morning": [-3193.4, -128.6], "elder_morning": [-3199.6, -131.2], "morning_player": [-3196.4, -129.0],
		"night_start": [-3196.0, -130.0], "wake_spot": [-3195.0, -129.0],
		"territory": [-3275.0, -395.0], "territory_edge": [-3261.5, -386.5], "lure_end": [-3266.0, -390.0], "lure_player": [-3255.0, -383.0],
		"jeogori_c": [-3270.0, -392.0], "jeogori_yard": [-3215.0, -344.0],
	}

# ---------------------------------------------------------------------------
# v3.2 §8·§12 대화 물음 — story_runner의 choice(loop)·when·flag만으로(새 대화 엔진 없음).
#   물은 것은 flag가 남아 다시 나오지 않고(when), 앞 물음이 뒤 물음을 연다. 주모에게 둘 이상 물으면 이겸 연결(§9, jumo_after_question).
# ---------------------------------------------------------------------------
static func _q(fl: String, label: String, open: String, steps: Array, after := []) -> Dictionary:
	return { "label": label, "when": ("not f('%s')" % fl) + ((" and " + open) if open != "" else ""),
		"do": [{ "flag": fl }] + steps + after }

# 주모 — 처음 셋(어떤 사람이오? / 무슨 일이오? / 보지 못했소.) → 넷(언제·어느 길·아이들·마을)이 열린다
static func jumo_questions() -> Array:
	var open := "(f('jq_intro') or f('case_started'))"
	var first := "not f('jq_intro') and not f('case_started')"
	var after := [{ "call": "jumo_after_question" }]
	return [
		_q("jq_who", "어떤 사람이오?", "", [{ "flag": "jq_intro" },
			{ "say": "주모", "lines": ["고개 너머 사는 떡장수요.", "장날이면 여기에도 떡을 내려놓고 가는 사람이오. 아이 둘 데리고 혼자 살지."] }], after),
		_q("jq_what", "무슨 일이오?", first, [{ "flag": "jq_intro" },
			{ "say": "주모", "lines": ["떡장수 아낙 하나가 사흘째 집에 안 들어갔다오.", "장 보고 돌아간 뒤로 소식이 없소."] }], after),
		_q("jq_none", "보지 못했소.", first, [{ "flag": "jq_intro" },
			{ "say": "주모", "lines": ["…그렇겠지. 사흘이나 됐으니."] }]),
		_q("jq_when", "언제 사라졌소?", open, [
			{ "say": "주모", "lines": ["사흘 전 아침이오.", "장을 보고 해가 아직 높을 때 돌아갔는데, 집에는 못 들어갔다더군."] },
			{ "say": "나그네", "lines": ["누가 확인했소?"] },
			{ "say": "주모", "lines": ["이웃 아낙이 애들 끼니 챙기러 아침저녁으로 들른다오."] }], after),
		_q("jq_route", "어느 길로 갔소?", open, [
			{ "face": "jumo", "to": "pass_road" },
			{ "say": "주모", "lines": ["북문으로 나가 고개만 넘으면 되오.", "서낭당 지나 조금 내려가면 집 한 채가 있소."] },
			{ "face": "jumo", "to": "player" },
			{ "flag": "heard_pass_road" }, { "discover": "north_pass" }], after),
		_q("jq_kids", "아이들은?", open, [
			{ "say": "주모", "lines": ["누이는 제법 야무진데 아우가 아직 어리오.", "어미가 돌아올 거라고 집을 떠나질 않는다더군."] },
			{ "wait": 0.8 },
			{ "say": "주모", "lines": ["사흘이나 됐는데."] }], after),
		# 결정 4 — 마을이 손 놓고 있던 게 아니다(장정 셋·포수)
		_q("jq_search", "마을에서는 찾아보지 않았소?", open, [
			{ "say": "주모", "lines": ["첫날엔 장정 셋이 고개를 올라갔소.", "서낭당 못 가서 범 우는 소리를 듣고 돌아왔지."] },
			{ "say": "나그네", "lines": ["포수는?"] },
			{ "say": "주모", "lines": ["그 양반도 찾아봤다는데, 피 묻은 자리부터는 범 영역이라더군."] }], after),
	]

# 오누이 — 언제 · 어디로 · 지난밤(목소리는 들은 대로만 적는다, K_MIMIC은 아직) + 기도 복선(§13, 짧게)
static func kids_questions() -> Array:
	return [
		_q("kq_when", "어머니는 언제 나갔니?", "", [
			{ "say": "누이", "lines": ["사흘 전 새벽에요.", "떡을 많이 쪄서 장에 가지고 갔어요."] },
			{ "say": "아우", "lines": ["해 지기 전에 온댔어요."] }]),
		_q("kq_where", "어디로 가셨니?", "", [
			{ "face": "nui", "to": "pass_road" },
			{ "caption": "누이가 고개 쪽을 가리킨다.", "sec": 1.6 },
			{ "say": "누이", "lines": ["늘 같은 길로 가요."] },
			{ "face": "nui", "to": "player" },
			{ "flag": "heard_pass_road" }, { "discover": "north_pass" }]),
		_q("kq_night", "지난밤엔 괜찮았니?", "", [
			{ "caption": "누이가 잠시 말이 없다.", "sec": 1.4 },
			{ "say": "나그네", "lines": ["무슨 일이 있었니?"] },
			{ "say": "누이", "lines": ["…어젯밤에 엄마 목소리가 들렸어요."] },
			{ "say": "나그네", "lines": ["문밖에서?"] },
			{ "caption": "누이가 고개를 끄덕인다.", "sec": 1.2 },
			{ "say": "누이", "lines": ["그런데 이상해서 문을 안 열었어요."] },
			{ "say": "아우", "lines": ["누나가 못 열게 했어요."] },
			{ "say": "나그네", "lines": ["뭐가 이상했니?"] },
			{ "say": "누이", "lines": ["목소리가 좀… 달랐어요."] },
			{ "flag": "voice_at_night" }, { "clue": "voice_at_night" },
			# §13 기도 복선 — 설명하지 않고 짧게
			{ "say": "아우", "lines": ["누나는 어젯밤에도 하늘님한테 엄마 빨리 오게 해 달라고 빌었어요."] },
			{ "say": "누이", "lines": ["그런 걸 왜 말해."] },
			{ "say": "아우", "lines": ["엄마도 무서우면 그렇게 하랬잖아."] },
			{ "flag": "prayer_foreshadow" }]),
	]

# v3.2 §27 포수 — 첫 조우 뒤. 정답(흉내)은 말하지 않는다. 역할 나누기는 범이 집 쪽으로 간다고 짐작한 뒤(§30 tiger_house_suspected)
static func hunter_questions() -> Array:
	var after := "f('first_encounter')"
	return [
		_q("hq_before", "전부터 있었소?", after, [
			{ "say": "포수", "lines": ["고개 너머 숲엔 전부터 범이 하나 있었소.", "그래도 사람 다니는 길까지 나온 적은 없었지."] }]),
		_q("hq_people", "사람을 노리오?", after, [
			{ "say": "포수", "lines": ["산짐승이면 사람 냄새 나면 피하는 게 보통이오."] },
			{ "wait": 0.5 },
			{ "say": "포수", "lines": ["저건 안 그래."] },
			{ "clue": "hunter_word" }]),
		_q("hq_where", "어디로 가는 것 같소?", after, [
			{ "say": "포수", "lines": ["사람 사는 데 가까이 내려온 지 며칠 됐소.", "고개 아래 방앗간에서도 밤마다 뭔가 뒤진다더군."] }]),
		_q("hm_where", "그놈은 어디 사오?", after, [
			{ "say": "포수", "lines": ["고개 너머 서쪽 숲 어딘가. 거기까진 나도 안 들어가오."] }]),
		# 결정 4 역할 나누기(hunter_watch)는 낮의 물음이 아니라 해 질 무렵 외딴집에서(namwon_case.dusk_return · _hunter_role)
	]

# v3.2 §28 방앗간 주인 — 본 것만(왜 가루를 뒤집어쓰는지는 모른다)
static func miller_questions() -> Array:
	return [
		_q("mq_since", "언제부터 그랬소?", "", [
			{ "say": "방앗간 주인", "lines": ["사나흘 됐소. 처음엔 쥐인 줄 알았지."] }]),
		_q("mq_what", "무슨 짐승 같소?", "", [
			{ "say": "방앗간 주인", "lines": ["쥐새끼 발이 저렇게 크겠소?"] },
			{ "face": "miller", "to": "flour" },
			{ "say": "방앗간 주인", "lines": ["나도 밤엔 문 걸고 잔다오."] },
			{ "face": "miller", "to": "player" }]),
		_q("mq_eat", "곡식은 먹었소?", "", [
			{ "say": "방앗간 주인", "lines": ["한 톨도 안 먹었소. 자루만 찢고 가루만 흩어 놓지."] }]),
	]

# ---------------------------------------------------------------------------
# 인물(CHARACTER_MASTER) — at: 자리(국면별 사전 가능), when: 보일 조건, talk: 위에서부터 조건이 맞는 첫 묶음
# ---------------------------------------------------------------------------
static func actors() -> Array:
	return [
		{ "id": "jumo", "chr": "CHR_HUM_015", "kind": "innkeeper", "name": "주모", "at": "jumo", "facing": "down",
			"talk": [
				# v3 결말 뒤: 범은 수수밭에서 죽은 채 발견됐다(누가 잡은 게 아니다). 아이들이 어디 갔는지는 아무도 모른다
				{ "when": "ph('done')", "steps": [
					{ "say": "주모", "lines": ["고갯길에 장꾼들이 다시 넘어오오. 범이 수수밭에 떨어져 죽어 있었다지 뭐요."] },
					{ "choice": "", "options": [
						{ "label": "그 집 아이들은 어디 갔소?", "do": [{ "say": "주모", "lines": ["그러게 말이오. 이웃 아낙이 가 봤더니 집이 비었더래요.", "누가 데려갔다는 사람도 없고…"] }] },
						{ "label": "그만 가 보겠소.", "end": true }] }] },
				{ "when": "f('dusk_prep') or ph('night')", "steps": [
					{ "say": "주모", "lines": ["그 집 애들 생각에 나도 잠이 안 오오."] },
					{ "if": "k('K_TERRITORY') and not has('%s') and not w('torch_lit')" % TORCH, "then": [
						{ "choice": "", "options": [
							{ "label": "횃불 하나 빌릴 수 있겠소?", "do": [{ "say": "주모", "lines": ["관솔 넉넉히 감았소."] }, { "give": TORCH }] },
							{ "label": "그만 가 보겠소.", "end": true }] }] }] },
				{ "when": "not f('case_started')", "steps": [{ "event": "S0002" }] },
				# 사건이 선 뒤: 아직 안 물은 것만(물은 것은 다시 나오지 않는다) + 떡·횃불
				{ "when": "true", "steps": [
					{ "say": "주모", "lines": ["산에서 뭘 보셨소? 얼굴이 하얗구려."], "when": "f('first_encounter')" },
					{ "say": "주모", "lines": ["그 집 애들은 좀 보고 오셨소?"], "when": "not f('first_encounter') and not f('met_kids')" },
					{ "say": "주모", "lines": ["애들은 좀 어떻습디까?"], "when": "not f('first_encounter') and f('met_kids')" },
					# 예전 저장(주막에서 자고 밤을 넘기던 흐름)에서 이어 온 사람에게도 밤을 어디서 맞을지 알린다
					{ "say": "주모", "lines": ["그 애들만 두고 밤을 넘기게 할 순 없지. 해 지기 전에 그 집에 가 보시오."], "when": "fn('night_ready') and ph('explore') and not f('dusk_return_seen')" },
					{ "choice": "", "loop": true, "options": jumo_questions() + [
						{ "label": "떡을 좀 얻을 수 있겠소?", "when": "k('K_FOOD') and not f('jumo_tteok')", "do": [
							{ "say": "주모", "lines": ["어제 찐 거요. 냄새는 고소하지."] }, { "give": TTEOK, "n": 2 }, { "flag": "jumo_tteok" }] },
						{ "label": "횃불 하나 빌릴 수 있겠소?", "when": "k('K_TERRITORY') and not has('%s') and not w('torch_lit')" % TORCH, "do": [
							{ "say": "주모", "lines": ["관솔 넉넉히 감았소. 불은 짐승이 꺼리지."] }, { "give": TORCH }] },
						{ "label": "그만 가 보겠소.", "end": true }] }] },
			] },
		{ "id": "guest", "chr": "CHR_HUM_013", "kind": "traveler", "name": "손님", "at": "guest", "facing": "right",
			"talk": [
				{ "when": "v('CASE_NAMWON_OUTCOME') != ''", "steps": [{ "say": "손님", "lines": ["고개가 열렸다니 오늘은 넘어가 볼까."] }] },
				{ "when": "true", "steps": [{ "say": "손님", "lines": ["사흘이면… 돌아올 사람이면 벌써 왔지."] }] },
			] },
		{ "id": "hunter", "chr": "CHR_HUM_017", "kind": "hunter", "name": "포수", "at": "hunter", "facing": "down",
			"talk": [
				{ "when": "ph('done')", "steps": [
					{ "say": "포수", "lines": ["그놈을 수수밭에서 찾았소. 높은 데서 떨어진 것처럼 뼈가 다 부러졌더군.", "화살 자국은 없었소. 누가 잡은 게 아니오."] },
					{ "choice": "", "options": [
						{ "label": "그 집 아이들은 어디 갔소?", "do": [{ "say": "포수", "lines": ["모르겠소. 아이들 발자국이 우물가 나무 밑에서 끊겼어.", "나무 위에도 없었고."] }] },
						{ "label": "그만 가 보겠소.", "end": true }] }] },
				{ "when": "f('dusk_prep') or ph('night')", "steps": [
					{ "say": "포수", "lines": ["고개 쪽 길은 내가 지키고 있소. 어서 애들 곁으로 가시오."] }, { "flag": "hunter_watch" },
					{ "if": "k('K_TERRITORY') and not has('%s') and not w('torch_lit')" % TORCH, "then": [
						{ "say": "포수", "lines": ["이거 가져가시오. 관솔 횃불이오."] }, { "give": TORCH }] }] },
				{ "when": "f('woke_by_hunter') and not f('hunter_after_wake')", "steps": [
					{ "flag": "hunter_after_wake" }, { "say": "포수", "lines": ["고갯길에 쓰러져 있길래 업어 왔소. 그놈을 봤구려."] }] },
				# v3.2 §27 — 첫 조우 전: 고개 쪽 길 이야기만
				{ "when": "not f('first_encounter')", "steps": [
					{ "say": "포수", "lines": ["고개 쪽 길은 요새 아무도 안 넘으려 하오.", "넘을 거면 해 있을 때 넘으시오."] }] },
				# 첫 조우 뒤 처음: 봤소? → 물음
				{ "when": "not f('hunter_met')", "steps": [
					{ "flag": "hunter_met" },
					{ "say": "포수", "lines": ["봤소?"] },
					{ "say": "나그네", "lines": ["큰 범이오."] },
					{ "say": "포수", "lines": ["그놈이었군."] },
					{ "choice": "", "loop": true, "options": hunter_questions() + [{ "label": "그만 가 보겠소.", "end": true }] }] },
				{ "when": "true", "steps": [
					{ "say": "포수", "lines": ["해 지면 고개 쪽엔 얼씬도 마시오."], "when": "f('tiger_house_suspected')" },
					{ "choice": "", "loop": true, "options": hunter_questions() + [
						{ "label": "횃불을 얻을 수 있겠소?", "when": "k('K_TERRITORY') and not has('%s') and not w('torch_lit')" % TORCH, "do": [
							{ "say": "포수", "lines": ["아껴 쓰시오."] }, { "give": TORCH }] },
						{ "label": "그만 가 보겠소.", "end": true }] }] },
			] },
		{ "id": "miller", "chr": "CHR_HUM_009", "kind": "miller", "name": "방앗간 주인", "at": "miller", "facing": "down",
			"talk": [
				{ "when": "v('CASE_NAMWON_OUTCOME') != ''", "steps": [{ "say": "방앗간 주인", "lines": ["범이 수수밭에 죽어 있었다지. 이제 자루 찢을 놈은 없겠구먼."] }] },
				# v3.2 §28 — 또 왔구먼 → 밀가루 바닥과 큰 발자국(mill_floor) → 물음. 왜 가루를 뒤집어쓰는지는 아무도 말하지 않는다
				{ "when": "not f('mill_talked')", "steps": [
					{ "flag": "mill_talked" },
					{ "face": "miller", "to": "flour" },
					{ "say": "방앗간 주인", "lines": ["또 왔구먼."] },
					{ "face": "miller", "to": "player" },
					{ "say": "나그네", "lines": ["뭐가 말이오?"] },
					{ "say": "방앗간 주인", "lines": ["밤마다 자루가 찢어져."] },
					{ "clue": "flour_sack" },
					{ "call": "mill_floor" },
					{ "say": "나그네", "lines": ["먹으려고 온 건 아닌데…"] },
					{ "say": "방앗간 주인", "lines": ["그럼 대체 왜 가루를 뒤집어쓰는 건지."] },
					{ "choice": "", "loop": true, "options": miller_questions() + [{ "label": "그만 가 보겠소.", "end": true }] }] },
				{ "when": "true", "steps": [
					{ "say": "방앗간 주인", "lines": ["오늘 밤엔 또 어쩌려나."] },
					{ "choice": "", "loop": true, "options": miller_questions() + [{ "label": "그만 가 보겠소.", "end": true }] }] },
			] },
		{ "id": "oil_wife", "chr": "CHR_HUM_010", "kind": "farmwife", "name": "기름집 아낙", "at": "oil_shop", "facing": "down",
			"talk": [
				{ "when": "out('B')", "steps": [{ "say": "기름집 아낙", "lines": ["그 기름을 디딤돌에 부었다고요? 범이 거기서 미끄러졌다니…", "그 집 누이가 가끔 기름 사러 왔는데, 요새는 통 안 보여요."] }] },
				{ "when": "v('CASE_NAMWON_OUTCOME') != ''", "steps": [{ "say": "기름집 아낙", "lines": ["고개 너머 집 누이가 가끔 기름 사러 왔는데, 요새는 통 안 보여요."] }] },
				{ "when": "not has('%s') and not w('oil_on_tree')" % OIL, "steps": [
					{ "say": "기름집 아낙", "lines": ["참기름 사러 오셨소? 갓 짠 거요."] },
					{ "choice": "", "options": [
						{ "label": "한 병 주시오. (엽전 다섯 닢)", "disabled_when": "n('%s') < 5" % COIN, "hint": "엽전이 모자란다.", "do": [
							{ "take": COIN, "n": 5 }, { "give": OIL }, { "say": "기름집 아낙", "lines": ["한 방울만 묻어도 손이 미끄러워요."] }] },
						{ "label": "다음에 사겠소.", "end": true }] }] },
				{ "when": "true", "steps": [{ "say": "기름집 아낙", "lines": ["고소하지요? 남원 참기름이 제일이에요."] }] },
			] },
		{ "id": "elder", "chr": "CHR_HUM_022", "kind": "elder", "name": "노인",
			"at": { "morning": "elder_morning", "default": "elder_town" }, "facing": { "morning": "right", "default": "down" },
			"talk": [
				{ "when": "ph('done')", "steps": [{ "say": "노인", "lines": ["한양 가는 길이면 오수 지나 전주로 가게."] }] },
				{ "when": "true", "steps": [{ "say": "노인", "lines": ["고개 서낭당에 돌 하나 얹고 가게. 요즘은 그냥 지나가면 탈이 난다네."] }] },
			] },
		{ "id": "nui", "chr": "CHR_MAIN_009", "kind": "story_girl", "name": "누이",
			"at": "kid_in_a",
			"facing": "down", "when": "not f('kids_hidden') and not f('kids_gone')",
			"talk": [
				{ "when": "f('dusk_prep') or ph('night')", "steps": [{ "say": "누이", "lines": ["문 걸어 둘게요. 목소리만 듣고는 안 열어요."] }] },
				{ "when": "not f('met_kids')", "steps": [{ "event": "S0003" }] },
				{ "when": "true", "steps": [
					{ "choice": "", "loop": true, "options": kids_questions() + [{ "label": "문 꼭 걸고 있거라.", "end": true }] }] },
			] },
		{ "id": "au", "chr": "CHR_MAIN_010", "kind": "story_boy", "name": "아우",
			"at": "kid_in_b",
			"facing": "down", "when": "not f('kids_hidden') and not f('kids_gone')",
			"talk": [
				{ "when": "f('dusk_prep') or ph('night')", "steps": [{ "say": "아우", "lines": ["엄마 오면 누나가 먼저 볼 거래요."] }] },
				{ "when": "not f('met_kids')", "steps": [{ "event": "S0003" }] },
				{ "when": "true", "steps": [{ "say": "아우", "lines": ["오늘은 와요?"] }] },
			] },
		{ "id": "neighbor", "chr": "CHR_HUM_010", "kind": "villager_f", "name": "이웃 아낙",
			"at": { "morning": "neighbor_morning", "default": "neighbor_after" }, "facing": "down", "when": "ph('morning') or ph('done')",
			"talk": [{ "when": "true", "steps": [{ "say": "이웃 아낙", "lines": ["그 집 애들 끼니라도 챙기려고 갔더니 집이 비었어요.", "아이들은 어디 갔을까요. 산에 들어갔으면 큰일인데."] }] }] },
		# v3.2 §11 첫 방문 — 이웃 아낙이 빈 그릇을 들고 집에서 나온다(장면 전용, 아침의 이웃 아낙과 같은 그림 CHR_HUM_010). 말 걸기 없음
		{ "id": "neighbor_visit", "chr": "CHR_HUM_010", "kind": "villager_f", "name": "이웃 아낙", "at": "house_door", "facing": "down",
			"when": "f('neighbor_visit_on')" },
		# 지역 변화(§30): 고갯길에 장꾼이 다시 다닌다
		{ "id": "merchant_a", "chr": "CHR_HUM_003", "kind": "peddler", "name": "장꾼", "at": "merchant_a", "facing": "down",
			"when": "v('CASE_NAMWON_OUTCOME') != ''",
			"talk": [
				{ "when": "true", "steps": [{ "say": "장꾼", "lines": ["고개가 다시 열렸다길래 사흘 길을 하루에 왔소.", "고개 너머 수수밭이 죄 붉던데, 거기서 범이 죽었다더구먼."] }] }] },
		{ "id": "merchant_b", "chr": "CHR_HUM_002", "kind": "merchant", "name": "장꾼", "at": "merchant_b", "facing": "left",
			"when": "v('CASE_NAMWON_OUTCOME') != ''",
			"talk": [{ "when": "true", "steps": [{ "say": "장꾼", "lines": ["해 지기 전에 넘으려고 서두르는 중이오."] }] }] },
	]

# ---------------------------------------------------------------------------
# 조사 대상(물건) — 소품은 props()가 보인다
# ---------------------------------------------------------------------------
static func objects() -> Array:
	# §29 필드: interact_id(=id) · event_id · when · radius · prompt_type · highlight · first_hint · journal_entry · map_discovery · state_change
	# v3.2 §15 — 첫 사건이라 단서가 6~8m 안에 들면 먹빛이 비교적 강하게(mark_r 7) · 처음 그 반경에 들 때 카메라가 0.4초 기울었다 돌아온다(namwon_case.ambient)
	#   떡 셋은 찾은 차례대로 §16·§17·§18의 말(namwon_case.cake_found — 어느 떡을 먼저 줍든 첫째·둘째·셋째)
	var cake := func(id: String) -> Dictionary:
		return { "id": id, "at": id, "label": "떨어진 떡 · 살펴보기", "radius": 2.0, "when": "not f('%s') and f('case_started')" % id,
			"event_id": "S0004", "prompt_type": "INSPECT", "highlight": "tutorial_high", "first_hint": true, "journal_entry": "cakes",
			"state_change": "CASE_NAMWON_GUIDANCE_STAGE", "mark_r": 7.0, "mark_a": 1.0,
			"steps": [{ "flag": id }, { "call": "cake_found", "args": [id] }, { "clue": "cakes" }, { "give": TTEOK, "quiet": true },
				{ "call": "check_food" }, { "call": "guidance", "args": [id] }] }
	var path := func(o: Dictionary) -> Dictionary:   # 고갯길 단서(S0004) — 첫 사건 안내 단계
		o.merge({ "event_id": "S0004", "prompt_type": "INSPECT", "highlight": "tutorial_high", "state_change": "CASE_NAMWON_GUIDANCE_STAGE",
			"journal_entry": o.id, "mark_r": 7.0, "mark_a": 1.0 })
		o.steps = o.steps + [{ "call": "guidance", "args": [o.id] }]
		return o
	return [
		# S0000 길가의 첫 조사(v3.2 §5 — 사건 단서 아님, '세상에는 직접 살펴볼 수 있는 대상이 있다'만 가르친다)
		#   4m 안에서 아주 약한 먹빛 표시(mark_r·mark_a — onboarding._update_marks) · 손 닿는 거리(2m)에서 'E 살펴보기' · 속말 한 줄
		{ "id": "roadside", "at": "s0000_sandal", "label": "살펴보기", "radius": 2.0, "mark_r": 4.0, "mark_a": 0.4,
			"when": "f('s0000_started') and not f('roadside_seen')",
			"event_id": "S0000", "prompt_type": "INSPECT", "highlight": "normal", "first_hint": true,
			"steps": [{ "flag": "roadside_seen" }, { "caption": "오래 버려진 짚신이다.", "sec": 2.4 }] },
		cake.call("cake_1"),
		cake.call("cake_2"),
		cake.call("cake_3"),
		# §19 짧은 인서트(낮은 각도·FOV 48) · §20 피(음악이 끊긴다) · §21 발자국(카메라가 자국을 따라 2초) · §22 광주리(CAMERA 3A, 1.5초 정적 → §23 과거 장면)
		path.call({ "id": "torn_skirt", "at": "torn_skirt", "label": "덤불에 걸린 천 · 살펴보기", "when": "not c('torn_skirt') and f('case_started')",
			"steps": [{ "call": "skirt_insert" }] }),
		path.call({ "id": "blood", "at": "blood", "label": "길가의 얼룩 · 살펴보기", "when": "not c('blood') and f('case_started')",
			"steps": [{ "call": "blood_scene" }] }),
		path.call({ "id": "tracks", "at": "tracks", "label": "발자국 · 살펴보기", "when": "not c('tracks') and f('case_started')",
			"steps": [{ "call": "tracks_pan" }] }),
		path.call({ "id": "basket", "at": "basket", "label": "서낭당 앞 광주리 · 살펴보기", "when": "not c('basket') and f('case_started')",
			"steps": [{ "call": "basket_scene" }] }),
		# S0003 집 안
		# v3.2 §14 집 조사 — 흔적으로만. 함지에서 어머니가 나타나는 회상(mother_flashback)은 없앴다(§3.1)
		{ "id": "hearth", "at": "hearth", "label": "아궁이 · 살펴보기", "radius": 1.6, "when": "not c('cold_hearth') and f('case_started')",
			"steps": [{ "examine": "식은 아궁이", "text": ["재가 완전히 식었다.", "이웃이 가져다주는 음식 말고는 며칠째 불을 쓰지 않은 것 같다."] }, { "clue": "cold_hearth" }] },
		{ "id": "kneading", "at": "kneading", "label": "함지 · 살펴보기", "radius": 1.6, "when": "not c('mother_route') and f('case_started')",
			"steps": [{ "examine": "떡가루 묻은 함지", "text": "함지 바닥에 떡가루가 말라붙어 있다." },
				{ "if": "not f('kids_hidden') and not f('kids_gone')", "then": [
					{ "face": "nui", "to": "kneading" },
					{ "say": "누이", "lines": ["엄마가 장에 갈 때마다 저기서 떡을 만들어요."] },
					{ "say": "나그네", "lines": ["그날도?"] },
					{ "say": "누이", "lines": ["네."] }] },
				{ "clue": "mother_route" }] },
		# S0006 추가 조사 — §28 방앗간 바닥(주인에게 묻지 않고 바로 살펴도 된다 · 주인과 말하면 mill_floor가 같은 것을 보인다)
		{ "id": "flour_prints", "at": "flour", "label": "밀가루 바닥 · 살펴보기", "radius": 2.4, "when": "not c('flour_prints') and f('case_started')",
			"steps": [{ "examine": "밀가루 바닥", "text": ["쏟아진 밀가루 위로 손바닥보다 큰 발자국이 찍혀 있다.", "뒷발보다 앞발 자국이 유난히 하얗다."] },
				{ "call": "see_flour" }] },
		{ "id": "claw", "at": "claw", "radius": 2.6, "label": "우물가 큰 나무 · 살펴보기",
			"when": "f('case_started') and not c('claw_marks')",
			"steps": [
				{ "examine": "긁힌 껍질", "text": ["사람 키를 훌쩍 넘는 곳까지 껍질이 깊게 긁혀 있다.", "거친 껍질엔 발톱이 박혔고, 매끈한 옹이 자리에선 미끄러진 자국뿐이다."] },
				{ "clue": "claw_marks" }, { "rule": "K_CLIMB" }] },
		{ "id": "barn", "at": "barn_front", "label": "헛간 · 살펴보기", "radius": 2.2, "when": "f('case_started') and not f('barn_seen')",
			"steps": [{ "flag": "barn_seen" }, { "examine": "헛간", "text": ["볏단 사이에 곡식 자루와 떡 몇 덩이를 싼 보자기.", "장에 내다 팔고 남은 것이다."], "kind": "item" },
				{ "give": TTEOK, "n": 2 }] },
		{ "id": "territory_edge", "at": "territory_edge", "label": "숲속 빈터 어귀 · 살펴보기", "radius": 3.0, "when": "not c('territory')",
			"steps": [{ "examine": "숲속 빈터", "text": ["빈터 어귀에 짐승 뼈가 구른다. 둘레 나무마다 발톱 자국.", "타다 만 횃불 하나. 누군가 불을 들고 여기까지 몰아낸 적이 있다."] },
				{ "clue": "territory" }, { "rule": "K_TERRITORY" }] },
		# v3.2 §33 준비 시간(해 질 무렵 귀환 뒤 ~ hide_spot에서 기다리기 전) — 기존 물건 쓰기만(새 미니게임 없음)
		{ "id": "cake_bait", "at": "cake_bait", "label": "숲 오솔길 어귀 · 살펴보기", "radius": 2.4,
			"when": "f('dusk_prep') and not f('night_wait_started') and not w('cake_bait') and has('%s')" % TTEOK,
			"steps": [{ "if": "not k('K_FOOD')", "then": [{ "call": "place_bait" }] }],
			"use": [{ "item": TTEOK, "when": "k('K_FOOD')", "line": "떡을 오솔길에 띄엄띄엄 놓을 수 있다.", "do": [{ "call": "place_bait" }] }] },
		{ "id": "yard_torch", "at": "yard_torch", "label": "마당 횃대 · 살펴보기", "radius": 2.0,
			"when": "f('dusk_prep') and not f('night_wait_started') and not w('torch_lit') and has('%s')" % TORCH,
			"steps": [{ "caption": "마당 귀퉁이의 빈 횃대.", "sec": 1.4 }],
			"use": [{ "item": TORCH, "line": "횃대에 불을 옮겨 붙일 수 있다.", "do": [
				{ "take": TORCH }, { "world": "torch_lit" }, { "caption": "마당이 붉게 일렁인다.", "sec": 2.0 }] }] },
		# B: 쪽문 디딤돌에 참기름 — 아이들이 빠져나간 뒤 쫓아 나오는 범이 여기서 미끄러진다(나무에는 바르지 않는다: 나무 기름은 누이의 거짓말 몫)
		{ "id": "back_step", "at": "back_step", "label": "쪽문 디딤돌 · 살펴보기", "radius": 2.4,
			"when": "f('dusk_prep') and not f('night_wait_started') and has('%s') and not w('oil_on_step')" % OIL,
			"steps": [{ "caption": "부엌 쪽문 앞 디딤돌. 쪽문은 우물가 나무 쪽으로 나 있다.", "sec": 2.0 }],
			"use": [{ "item": OIL, "line": "디딤돌에 참기름을 부을 수 있다.", "do": [{ "call": "oil_step" }] }] },
		# §34 밤 기다리기 — 기다린다(23:30) / 아직 준비할 것이 있다
		{ "id": "night_wait", "at": "hide_spot", "label": "숨어서 기다린다", "radius": 2.6, "when": "f('dusk_prep') and not f('night_wait_started') and ph('explore')",
			"steps": [{ "call": "wait_at_hide" }] },
	]

static func triggers() -> Array:
	return [
		# S0000-C 나그네 둘이 지나가며 이겸 이야기를 서로 다르게 한다(붙잡지 않음 — 시스템 효과 없음)
		{ "id": "s0000_travellers", "at": "s0000_rumor", "radius": 9.0, "when": "f('s0000_started') and not f('INTRO_CONFLICTING_RUMOR_HEARD')",
			"steps": [{ "call": "travellers" }] },
		{ "id": "s0000_travellers_late", "at": "s0000_start", "radius": 60.0,
			"when": "f('roadside_seen') and not f('INTRO_CONFLICTING_RUMOR_HEARD') and fn('since_roadside') > 9.0", "steps": [{ "call": "travellers" }] },
		# S0000-D → S0001: 남원이 보이는 곳(또는 성문·주막까지 먼저 오면 거기서) — 전경 카메라 · 「남원」 · 「설화록」 · 첫 자유 이동
		{ "id": "s0001_vista", "at": "s0000_vista", "radius": 10.0, "when": "f('s0000_started') and not f('INTRO_NAMWON_TITLE_DONE')", "event": "S0001" },
		{ "id": "s0001_vista_late", "at": "tavern", "radius": 40.0, "when": "f('s0000_started') and not f('INTRO_NAMWON_TITLE_DONE')", "event": "S0001" },
		# S0001 끝: 성문 통과
		{ "id": "s0001_gate", "at": "east_gate", "radius": 12.0, "when": "ph('explore') and not f('s0001_done')", "steps": [{ "flag": "s0001_done" }] },
		# S0002 주막 주변대화(지나가며 엿듣는다 — 조작을 막지 않는다)
		# v3.2 §7 — 조작권을 쥔 채 들린다. 주모 머리 위 「…」(onboarding talk marks)
		{ "id": "s0002_overhear", "at": "tavern", "radius": 15.0, "when": "ph('explore') and not f('case_started') and not (f('s0000_started') and not f('INTRO_NAMWON_TITLE_DONE'))", "ambient": [
			["주모", "아직도 안 왔다고?"], ["손님", "사흘이면 돌아올 사람이면 벌써 왔지."]] },
		# v3.2 §10 역참·마방 — 남원 역참(stations.json) 문 앞 기다리는 말·마부 곁에 처음 다가갈 때 한 번.
		#   사건이 선 뒤에만, 반경은 좁게(역참 문 앞이 주모 자리에서 14m — 주모 대화가 끝나자마자 뜨지 않게)
		{ "id": "station_intro", "at": "station_wait", "radius": 7.0, "when": "ph('explore') and f('case_started') and not f('station_tut_seen')",
			"steps": [{ "call": "station_intro" }] },
		# v3.2 §11 첫 방문 — 외딴집 18m 안: 이웃 아낙이 나온다(낮, 오누이를 만나기 전)
		{ "id": "neighbor_visit", "at": "house", "radius": 18.0,
			"when": "ph('explore') and f('case_started') and not f('met_kids') and not f('first_encounter') and not f('neighbor_visit_seen')",
			"steps": [{ "call": "neighbor_visit" }] },
		# S0005 첫 조우(v3.2 §24): 고갯길 단서 셋 이상 + first_seen에 다가감(보는 것이 아니라 반경) · 또는 빈터에 먼저 들어섬(범의 정체는 첫 조우가 필수)
		{ "id": "s0005_pass", "at": "first_seen", "radius": 16.0, "when": "ph('explore') and f('case_started') and not f('first_encounter') and fn('path_clues') >= 3",
			"event": "S0005" },
		# v3.2 §28 — 방앗간에 가까이 오면 멀리서 가루 자루 바스락(한 번)
		{ "id": "mill_rustle", "at": "mill", "radius": 26.0, "when": "ph('explore') and f('case_started') and not f('mill_talked')",
			"steps": [{ "sfx": "flour_rustle", "at": "flour" }] },
		# v3.2 §30 — 흰 발자국이 외딴집 쪽으로: 방앗간 바닥을 보았거나(밀가루 발자국) 범을 본 뒤, 자국이 시작되는 곳에 다가가면 짧게 따라간다
		{ "id": "white_trail", "at": "white_trail_a", "radius": 7.0,
			"when": "ph('explore') and f('case_started') and (c('flour_prints') or f('first_encounter')) and not f('tiger_house_suspected')",
			"steps": [{ "call": "white_trail" }] },
		{ "id": "s0005_territory", "at": "territory", "radius": 10.0, "when": "ph('explore') and f('case_started') and not f('first_encounter')", "event": "S0005" },
		# v3.2 §31 해 질 무렵 외딴집 귀환 — 범을 보았고 집 쪽으로 올 것을 짐작한 뒤(night_ready) 마당에 다가가면: 누이 “찾았어요?” → 경고 → 포수와 역할 나누기 → 준비
		{ "id": "dusk_return", "at": "yard", "radius": 15.0, "when": "ph('explore') and fn('night_ready') and not f('dusk_return_seen')",
			"steps": [{ "call": "dusk_return" }] },
	]

# ---------------------------------------------------------------------------
# 지도에 적힐 곳(scripts/region/discovery.gd) — 아는 지리만. 단서·범의 영역 같은 '알아낼 사실'은 넣지 않는다(빈터는 가 봐야 적힌다)
# ---------------------------------------------------------------------------
static func map_places() -> Array:
	return [
		{ "id": "east_gate", "name": "남원 동문", "at": "east_gate", "radius": 20.0, "start_known": true },
		{ "id": "main_road", "name": "큰길(통영별로)", "at": "main_road", "radius": 20.0, "start_known": true },
		{ "id": "tavern", "name": "주막", "at": "tavern", "building": true, "start_known": true },
		# 주모가 "고개 너머"라 일러 줌 → 북쪽 고갯길이 지도에(들음)
		{ "id": "north_pass", "name": "북쪽 고갯길", "at": "pass_road", "radius": 22.0, "known": "f('heard_pass_road')" },
		{ "id": "north_square", "name": "북쪽 어귀", "at": "north_square", "radius": 16.0 },
		{ "id": "shrine", "name": "고갯마루 서낭당", "at": "shrine", "radius": 10.0 },
		{ "id": "house", "name": "고개 너머 외딴집", "at": "house", "radius": 16.0 },
		{ "id": "mill", "name": "물레방앗간", "at": "mill", "radius": 12.0 },
		{ "id": "oil_shop", "name": "기름집", "at": "oil_shop", "radius": 8.0 },
		{ "id": "clearing", "name": "숲속 빈터", "at": "territory_edge", "radius": 9.0 },
	]

# 지도 붉은 표(갈 곳) — 들은 곳·가라는 곳만(보강서 §20 "알고 있는 지리는 표시한다. 알아내야 하는 사실은 표시하지 않는다").
# 범의 영역(빈터)·단서 자리는 넣지 않는다. 조건은 f·c·k·ph·v·seen·talked·w·out·has·n만(fn 금지 — 지도가 저장에서 따로 읽는다)
static func map_leads() -> Array:
	return [
		{ "id": "nw_tavern", "name": "주막", "at": "tavern", "hub": true, "when": "true", "until": "ph('done')",
			"note": "사건의 들머리 — 동문 밖 주막(start_known). S0002 주모" },
		{ "id": "nw_pass", "name": "고개 너머", "at": "pass_road", "when": "f('case_started')", "until": "seen('S0004')",
			"note": "S0002 주모 “고개 너머 사는 떡장수요” — 고갯길 단서를 하나라도 보면(S0004) 사라진다" },
		{ "id": "nw_kids_house", "name": "고개 너머 외딴집", "at": "house", "when": "f('case_started')", "until": "f('met_kids')",
			"note": "주모 “그 집 애들은 좀 보고 오셨소?” · 소문 rumor(고개 너머 사는 떡장수). S0003에서 만나면 사라진다" },
		# v3.2 §27 포수 “방앗간에서도 밤마다 뭔가 뒤진다더군.” → 방앗간(가 보면·주인과 말하면 사라진다)
		{ "id": "nw_mill", "name": "물레방앗간", "at": "mill", "when": "f('hq_where') and not ph('night')", "until": "f('mill_talked') or c('flour_prints')",
			"note": "포수 hq_where — mill_talked·flour_prints면 사라진다" },
		{ "id": "nw_night_house", "name": "외딴집(오늘 밤)", "at": "house", "when": "f('dusk_prep') or ph('night')", "until": "seen('S0007') or f('night_wait_started')",
			"note": "해 질 무렵 귀환·경고 뒤(dusk_prep) — 준비하러 마을에 다녀올 때 돌아올 곳. hide_spot에서 기다리면(S0007) 사라진다" },
		{ "id": "nw_to_hanyang", "name": "한양", "region": "GG_HANYANG", "when": "seen('S0010')", "until": "v('CASE_HANYANG_BOOKSHOP_COMPLETE') == true",
			"note": "S0010 노인 “한양 간다고 했지.” → MAIN_MASTER_TRACE = HANYANG" },
	]

# 사건 기록 칸(scripts/story/journal_book.gd): 아직 모르는 것 · 확인한 장소 · 사용 가능한 관련 물건(뜻을 가진 뒤에만)
static func journal() -> Dictionary:
	return {
		"unknowns": [
			{ "text": "떡장수는 어디에서 사라졌는가.", "until": "c('tracks') or c('basket')" },
			{ "text": "누구 또는 무엇을 만났는가.", "until": "f('first_encounter')" },
			{ "text": "문밖에서 어머니 목소리로 부른 것은 누구인가.", "when": "c('voice_at_night')", "until": "c('door_tricks')" },
			{ "text": "범은 왜 사람 사는 데까지 내려오는가.", "when": "f('first_encounter')", "until": "f('tiger_house_suspected')" },
			{ "text": "범은 무엇에 끌려 사람 가까이까지 내려오는가.", "when": "f('first_encounter')", "until": "k('K_FOOD')" },
			{ "text": "범을 잠시라도 집에서 떼어 놓을 수 있는가.", "when": "f('first_encounter')", "until": "k('K_TERRITORY')" },
		],
		"places": [
			{ "name": "남원 주막", "when": "f('case_started') and (fn('route_is', 'jumo') or talked('jumo') > 0)" },
			{ "name": "오누이 집", "when": "f('met_kids')" },
			{ "name": "북쪽 고갯길", "when": "fn('path_clues') > 0" },
			{ "name": "고갯마루 서낭당", "when": "c('basket')" },
			{ "name": "물레방앗간", "when": "c('flour_sack') or c('flour_prints')" },
			{ "name": "기름집", "when": "talked('oil_wife') > 0" },
			{ "name": "숲속 빈터 어귀", "when": "c('territory')" },
			{ "name": "우물가 나무", "when": "c('kids_tree')" },
			{ "name": "수수밭", "when": "c('rotten_rope')" },
		],
		"solutions_when": "f('first_encounter')",
		"items": [
			{ "id": OIL, "when": "f('first_encounter')" },
			{ "id": TTEOK, "when": "k('K_FOOD')" },
			{ "id": TORCH, "when": "k('K_TERRITORY')" },
		],
	}

# ---------------------------------------------------------------------------
# 소품(조건이 참일 때만) — kit/story/clue.gd + 세계 데칼(있으면)
# ---------------------------------------------------------------------------
static func props() -> Array:
	return [
		{ "id": "p_sandal", "kit": "story/clue", "params": { "kind": "sandal", "seed": 4 }, "at": "s0000_sandal", "ry": 0.8 },
		{ "id": "p_cake_1", "kit": "story/clue", "params": { "kind": "tteok", "seed": 1 }, "at": "cake_1", "ry": 0.3, "when": "not f('cake_1')" },
		{ "id": "p_cake_2", "kit": "story/clue", "params": { "kind": "tteok", "seed": 2 }, "at": "cake_2", "ry": 1.2, "when": "not f('cake_2')" },
		{ "id": "p_cake_3", "kit": "story/clue", "params": { "kind": "tteok", "seed": 3 }, "at": "cake_3", "ry": 2.1, "when": "not f('cake_3')" },
		{ "id": "p_skirt", "kit": "story/clue", "params": { "kind": "skirt" }, "at": "torn_skirt", "ry": 0.0 },
		{ "id": "p_blood", "kit": "story/clue", "params": { "kind": "blood" }, "at": "blood", "ry": 0.4 },
		{ "id": "d_blood", "decal": { "kind": "blood", "size": 1.1, "ry": 0.6 }, "at": "blood" },
		{ "id": "p_tracks", "kit": "story/clue", "params": { "kind": "tracks", "length": 4.5 }, "at": "tracks", "ry": 0.55 },
		{ "id": "d_tracks", "trail": { "kind": "paw", "points": ["tracks", "tracks_end", [-3180.0, -262.0]], "step": 0.9, "size": 0.5 } },
		{ "id": "p_basket", "kit": "story/clue", "params": { "kind": "basket" }, "at": "basket", "ry": 0.2 },
		{ "id": "p_flour", "kit": "story/clue", "params": { "kind": "flour", "length": 5.0 }, "at": "flour", "ry": -0.9 },
		{ "id": "d_shoes", "trail": { "kind": "shoe", "points": [[-3163.0, -192.0], [-3157.0, -212.0], "tracks"], "step": 0.8, "size": 0.45 } },
		{ "id": "d_claw", "decal": { "kind": "claw", "size": 0.9, "wall": true, "dy": 3.0, "ry": 0.0 }, "at": [-3205.5, -341.45] },
		{ "id": "d_claw_low", "decal": { "kind": "claw", "size": 0.6, "wall": true, "dy": 1.2, "ry": 0.3 }, "at": [-3205.4, -341.45] },
		{ "id": "d_flour", "decal": { "kind": "flour", "size": 1.8 }, "at": "flour" },
		{ "id": "d_flour_trail", "trail": { "kind": "flour_paw", "points": ["flour", "white_trail_a", "white_trail_b", "white_trail_c"], "step": 0.9, "size": 0.48 } },
		{ "id": "p_claw", "kit": "story/clue", "params": { "kind": "claw", "r": 0.42, "h": 3.4 }, "at": "big_tree" },
		{ "id": "p_oil", "kit": "story/clue", "params": { "kind": "oil", "r": 0.42 }, "at": "big_tree", "when": "w('oil_on_tree') and not ph('done')" },
		{ "id": "p_oil_jars", "kit": "story/clue", "params": { "kind": "oil_jars" }, "at": "oil_jars" },
		{ "id": "p_bones", "kit": "story/clue", "params": { "kind": "bones" }, "at": "territory_edge" },
		{ "id": "p_bait", "kit": "story/clue", "params": { "kind": "cake_trail", "n": 6, "length": 10.0 }, "at": [-3227.0, -341.5], "ry": 0.15,
			"when": "w('cake_bait')" },
		{ "id": "p_torch_fire", "kit": "story/clue", "params": { "kind": "torch_fire" }, "at": "yard_torch", "when": "w('torch_lit')" },
		{ "id": "p_white_paw", "kit": "story/clue", "params": { "kind": "white_paw" }, "at": "door_sill", "dy": 0.58, "ry": 3.14159, "when": "w('white_paw')" },
		# v3.2 §38 CAMERA 7C — 문틈의 털 난 앞발(일부만)
		{ "id": "p_hairy_paw", "kit": "story/clue", "params": { "kind": "hairy_paw" }, "at": "door_sill", "dy": 0.58, "ry": 3.14159, "when": "w('hairy_paw')" },
		# v3: 우물(오누이가 비친 곳) · 쪽문 디딤돌(B 참기름) · 수수밭(범이 떨어져 붉게 물든다 — 사건 뒤에도 남는다)
		{ "id": "p_well", "kit": "village/well", "params": { "seed": 49 }, "at": "well", "ry": 0.4 },
		{ "id": "p_step", "kit": "story/tale", "params": { "kind": "step_stone" }, "at": "back_step", "ry": 0.0 },
		{ "id": "p_oil_step", "kit": "story/tale", "params": { "kind": "oil_step" }, "at": "back_step", "ry": 0.0, "when": "w('oil_on_step') and not ph('done')" },
		{ "id": "p_sorghum", "kit": "story/tale", "params": { "kind": "sorghum", "w": 5.0, "d": 4.5 }, "at": "sorghum", "when": "not w('sorghum_red')" },
		{ "id": "p_sorghum_red", "kit": "story/tale", "params": { "kind": "sorghum", "w": 5.0, "d": 4.5, "red": true }, "at": "sorghum", "when": "w('sorghum_red')" },
	]

# ---------------------------------------------------------------------------
# 사건 장면(§44 필드 + steps) — EVENT_CLASS FOLKLORE_EVENT(§1.11). SOURCE_VERIFIED=false인 장면은 실행하지 않는다.
# ---------------------------------------------------------------------------
static func _ev(id: String, trigger: String, loc: String, tw: String, actions: String, branches: String, wsc: String, steps: Array) -> Dictionary:
	return {
		"EVENT_ID": id, "EVENT_CLASS": "FOLKLORE_EVENT", "RECORD_TITLE": "산길의 실종", "SOURCE_ID": "F49", "CATALOG_ID": "JG01",   # F49 = 게임 설화 소스 id · JG01 = 163편 카탈로그 원번호(추적용)
		"SOURCE_TITLE_INTERNAL": "해와 달이 된 오누이", "SOURCE_TYPE": "tale", "SOURCE_REGION_GRADE": "D",
		"SOURCE_REGION_NOTE": "전국형 민담. 남원 고유 전승이라고 주장하지 않는다. 떡장수 어머니→호랑이→오누이→목소리·손 속임수→나무 위→동아줄→수수밭→해와 달을 화면에서 그대로 겪는다(DIRECT, v3 §8).",
		"ADAPTATION_MODE": "DIRECT", "TRIGGER": trigger, "LOCATION_TYPE": loc, "TIME_WEATHER": tw,
		"PLAYER_ACTIONS": actions, "RESOLUTION_BRANCHES": branches, "WORLD_STATE_CHANGE": wsc, "SOURCE_VERIFIED": true,
		"steps": steps,
	}

static func events() -> Dictionary:
	return {
		# 보강서 v1.0 S0000 — 검은 화면 이겸의 세 문장 → 기록책 마지막 장을 덮으며 화면이 열린다(이후 길가 짚신·기록책·나그네 둘은 자리 트리거)
		"S0000": _ev("S0000", "새 게임", "남원 외곽 통영별로(동문 밖 약 250m)", "이른 아침 · 맑음", "걷는다 · 길가를 살핀다 · 기록책을 본다", "-", "-", [
			{ "phase": "explore" }, { "time": 8.0 }, { "weather": "clear" },
			{ "teleport": "s0000_start", "face": "left" },
			{ "give": "ITM_TOOL_009", "quiet": true }, { "give": "ITM_WPN_001", "quiet": true }, { "give": "ITM_WPN_002", "quiet": true },
			{ "give": "ITM_AMMO_001", "n": 12, "quiet": true }, { "give": COIN, "n": 12, "quiet": true },
			{ "flag": "s0000_started" },
			{ "call": "prologue_open" },
		]),
		# S0001 — 남원 전경(지리산 능선 → 요천 → 읍성 → 플레이어) · 「남원」 · 「설화록」(15초 안팎, Esc·Space로 건너뜀) → 남원 첫 자유 이동
		"S0001": _ev("S0001", "남원이 보이는 길목", "남원 동문 밖(통영별로)", "아침 · 맑음", "성 안팎을 자유롭게 다닌다", "-", "-", [
			{ "phase": "explore" },
			{ "if": "not f('s0000_started')", "then": [   # 옛 저장·시험: S0000 없이 바로 S0001
				{ "time": 9.5 }, { "teleport": "start", "face": "left" },
				{ "give": "ITM_TOOL_009", "quiet": true }, { "give": "ITM_WPN_001", "quiet": true }, { "give": "ITM_WPN_002", "quiet": true },
				{ "give": "ITM_AMMO_001", "n": 12, "quiet": true }, { "give": COIN, "n": 12, "quiet": true }, { "flag": "s0000_started" }] },
			{ "call": "vista" },
			{ "flag": "INTRO_NAMWON_TITLE_DONE" },
		]),
		# v3.2 §8 주모 첫 대화(CAMERA 1A — case.talk_camera) → 물음이 물음을 연다 → 둘 이상 물으면 §9 이겸 연결 → 사건 기록(도장) → R 기록책
		"S0002": _ev("S0002", "주모에게 말을 건다(지나가면 주변대화)", "남원 동문 밖 주막", "오전", "묻는다(어떤 사람·언제·어느 길·아이들·마을)", "-", "사건 기록 생성 · 북쪽 고갯길이 지도에", [
			{ "if": "not f('jq_intro')", "then": [
				{ "say": "주모", "lines": ["길손이시오?"] },
				{ "say": "나그네", "lines": ["그렇소."] },
				{ "face": "jumo", "to": "pass_road" },
				{ "caption": "주모가 북쪽 고갯길 쪽을 한번 본다.", "sec": 1.6 },
				{ "face": "jumo", "to": "player" },
				{ "say": "주모", "lines": ["혹시 오면서 아낙 하나 못 보셨소?"] }],
			  "else": [{ "say": "주모", "lines": ["또 물을 게 있소?"] }] },
			{ "choice": "", "loop": true, "options": jumo_questions() + [{ "label": "그만 가 보겠소.", "when": "f('jq_intro')", "end": true }] },
		]),
		# v3.2 §12 오누이 첫 대화(주막에서 듣고 왔으면 원문 그대로, 먼저 왔으면 여기서 사건이 선다) → 세 물음
		"S0003": _ev("S0003", "오누이에게 말을 건다", "고개 너머 외딴집", "낮", "묻는다(언제·어디로·지난밤) · 집 안을 살핀다(아궁이·함지)", "-", "-", [
			{ "flag": "met_kids" },
			{ "if": "f('case_started')", "then": [
				{ "say": "누이", "lines": ["누구세요?"] },
				{ "say": "나그네", "lines": ["장에 갔던 어머니를 찾고 있다."] },
				{ "say": "아우", "lines": ["엄마 봤어요?"] },
				{ "say": "나그네", "lines": ["…아직은."] },
				{ "say": "누이", "lines": ["오늘은 오겠죠?"] }],
			  "else": [
				{ "say": "누이", "lines": ["누구세요?"] },
				{ "say": "나그네", "lines": ["지나가던 길손이다. 어른은 안 계시니?"] },
				{ "say": "아우", "lines": ["엄마는 장에 갔어요."] },
				{ "say": "누이", "lines": ["사흘 전에요. …오늘은 오겠죠?"] },
				{ "call": "start_case", "args": ["kids"] }] },
			{ "clue": "kids_story" },
			{ "choice": "", "loop": true, "options": kids_questions() + [{ "label": "문 꼭 걸고 있거라.", "end": true }] },
		]),
		# S0004·S0006·S0008은 장면 하나가 아니라 조사 대상·선택이 모인 구간 — 기록용(단서·결말을 고르면 seen에 남는다)
		"S0004": _ev("S0004", "사건 기록 생성 뒤 고갯길", "고갯길(떡 셋·치맛자락·핏자국·발자국·서낭당 광주리)", "낮", "순서 없이 조사(3개 이상이면 첫 조우 가능). 서낭당 광주리에서 어머니의 과거 장면(§23, 기록하지 않음) — FIXED mother_harmed",
			"-", "-", []),
		"S0006": _ev("S0006", "첫 조우 뒤(선택)", "방앗간·포수·기름집·헛간·큰 나무·숲속 빈터", "낮~해질녘", "포수·방앗간 주인에게 묻는다 · 연결 추론(§29) · 외딴집 쪽 흰 발자국(§30) · 준비(참기름·떡·횃불)",
			"-", "-", []),
		"S0008": _ev("S0008", "S0007 — 오누이가 뒷문으로 빠져나가고 범이 뒤쫓을 때", "외딴집 마당", "밤", "범 앞을 막아선다 / 디딤돌의 참기름 / 떡 냄새와 횃불로 길을 막는다(준비한 것에 따라)",
			"A 막아섬(약 25초, 죽지 않는 범) · B 디딤돌에서 미끄러진 범과 짧은 싸움(12~18초) · C 떡 냄새로 방향을 돌리고 횃불로 길을 막음(범은 곧 돌아온다) — 끝에 범이 밀쳐내고 아이들은 나무 위",
			"CASE_NAMWON_OUTCOME = A | B | C (범을 죽이지 않는다)", []),
		# v3.2 §24~§26: 음악·새소리가 끊기고(발걸음과 바람만) 무언가 오른쪽·왼쪽 나무 사이로 지나간다 → CAMERA 4A 얼굴 1초 → 그르렁 → 뒤에서 덮친다 →
		#   전투 배우기(K 회피·L 막기는 실제로 해야 끝) — 목표는 범을 죽이는 게 아니라 버티기(약 22초) 또는 한쪽 체력이 꽤 깎임 → 범이 물러나 숲으로 사라진다
		"S0005": _ev("S0005", "고갯길 단서 3개 이상 + first_seen에 다가감", "고갯마루 아래 숲", "해질녘(지금 시각에서 저녁 쪽으로)", "버틴다 · 피한다(K) · 막는다(L) · 물러난다(보스전 아님)",
			"범이 물러남 / 플레이어가 물러남 / 쓰러져 포수에게 업혀 옴", "-", [
			{ "call": "first_encounter" },
		]),
		# S0007 밤의 문(FIXED tiger_disguise · door_tricks · kids_escape_tree 시작) → S0008 시간을 번다 → S0009 동아줄과 두 빛 → S0010 아침(빈 집) → S0011 밤하늘
		"S0007": _ev("S0007", "해 질 무렵 귀환·준비 뒤 hide_spot에서 “기다린다”", "외딴집 마당", "밤(23:30)", "숨어서 지켜본다(문 앞 속임수에 맞서고 탈출을 정하는 것은 누이) · 노크 사이 조작 · 시간 벌기 · 마지막 개입", "-", "-", [
			{ "call": "night_door" },
		]),
		"S0009": _ev("S0009", "S0007의 우물·참기름·도끼·마지막 개입 뒤(ACT 10~)", "외딴집 우물가 나무 · 수수밭", "밤", "곁에서 본다(동아줄을 비는 것은 오누이)", "-",
			"오누이가 하늘로 올라감 · 범이 썩은 동아줄과 수수밭에 떨어짐(수숫대가 붉어짐) · 하늘에 두 빛", [
			{ "call": "rope_night" },
		]),
		"S0010": _ev("S0010", "다음 날 아침", "북쪽 어귀", "아침", "아이들 일을 묻는 마을 사람들 곁에 선다 · 기록책을 보인다", "-",
			"아이들이 어디 갔는지 아무도 모른다 · MAIN_MASTER_TRACE = HANYANG, SKILL_BEAST_TRACE", [
			{ "call": "morning_village" },
			{ "say": "노인", "lines": ["그 책… 전에도 그런 책 들고 다니던 양반이 있었소."] },
			{ "say": "나그네", "lines": ["어디로 갔습니까?"] },
			{ "say": "노인", "lines": ["한양 간다고 했지."] },
			{ "var": "MAIN_MASTER_TRACE", "value": "HANYANG" },
			{ "var": "SKILL_BEAST_TRACE", "value": true },
			{ "toast": "새 해결 수단 — 짐승 흔적 읽기", "kind": "rule" },
			{ "journal": "이겸의 흔적 — 한양" },
		]),
		"S0011": _ev("S0011", "S0010 뒤, 그날 밤", "북쪽 어귀", "밤", "밤하늘을 올려다본다", "-", "-", [
			{ "call": "night_sky" },
		]),
	}
