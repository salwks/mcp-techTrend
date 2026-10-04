# 사건 「비어 있는 책방」(ACT 1 한양, S1001~S1006) — 이야기 데이터.
# 시나리오 v2.1 §10(S1001~S1006), 인물 §3.3 우치, 대사 §27, 컷신 §28, 실패 §29(추격을 놓쳐도 이어진다), 지역 변화 §30, §44 필드.
# 남원 사건이 끝나 MAIN_MASTER_TRACE에 HANYANG이 들어 있을 때만 선다(case.requires — 쉼표 목록이면 포함 여부). 노정(R01)으로 오든 역마로 오든 처음 한양에 들면 S1001.
# 자리(게임 좌표 x,z — GG_HANYANG): 숭례문(−644, −332) → 종루(−291, −874) → 피맛골 책쾌 책방(−252, −938, world-scenario hy_sc_chaekbang) →
#   추격: 피맛골 → 시전 지붕(지름길) → 운종가 건너 → 중촌 골목 → 기와 지붕 줄(실루엣) → 개천 둑 → 광통교(끝) → 책방 옆 빈 창고(hy_sc_bin_changgo).
# 원작 제목은 화면에 쓰지 않는다. 우치는 전우치 이름을 빌린 메인 인물 — 전우치 전승 사건(F21 빈 관·F22·F23)은 여기서 쓰지 않는다(GG-01·H08은 뒤).
extends RefCounted

const PAPERS := "ITM_KEY_002"     # 이겸의 낡은 기록 조각(종이 세 장)
const PASS_DOC := "ITM_KEY_003"   # 우치의 위조 통행문서(§14 갈고리)
const COIN := "COIN"

static func data() -> Dictionary:
	return {
		"case": {
			"id": "hanyang", "record_title": "비어 있는 책방", "region": "GG_HANYANG", "outcome_var": "CASE_HANYANG_OUTCOME",
			"start_hour": 11.0,
			"requires": { "MAIN_MASTER_TRACE": "HANYANG" },     # 남원(S0010) 뒤에만
			"start_event": "S1001", "start_on_arrival": true,     # 노정·역마로 넘어와도 시작
			"complete_key": "HANYANG_BOOKSHOP",                   # 끝나면 CASE_HANYANG_BOOKSHOP_COMPLETE → 빠른 투척(scripts/story/skills.gd)
			"reset_vars": ["CASE_HANYANG_OUTCOME", "MAIN_WOOCHI_KNOWN", "ACT2_OPEN", "ACT3_OPEN", "MAIN_PARK_NAME_KNOWN", "SKILL_QUICK_THROW", "CASE_HANYANG_BOOKSHOP_COMPLETE"],
		},
		"items": {
			PAPERS: "이겸의 기록 조각", PASS_DOC: "위조 통행문서", COIN: "엽전",
			"ITM_TOOL_009": "사건 기록책", "ITM_WPN_001": "환도", "ITM_WPN_002": "활", "ITM_AMMO_001": "화살",
		},
		"hidden_items": ["ITM_TOOL_009", "ITM_WPN_001", "ITM_WPN_002", "ITM_AMMO_001"],
		"clues": {
			"note": { "title": "이겸의 쪽지", "text": "종루 뒤 피맛골, 책쾌. 옛 장부 일을 물어볼 것.", "kind": "fact" },
			"open_door": { "title": "열린 문", "text": "책방 문이 열려 있다. 사람은 없다.", "kind": "fact" },
			"ink": { "title": "넘어간 먹통", "text": "먹물이 서안 끝까지 흘렀다. 아직 마르지 않았다.", "kind": "fact" },
			"string": { "title": "끊어진 끈", "text": "책 묶음을 매던 끈. 끝이 칼로 자른 듯 반듯하다.", "kind": "fact" },
			"window": { "title": "열린 뒤창", "text": "뒤창 살이 밖으로 열렸다. 창턱 흙에 짚신 앞꿈치 자국.", "kind": "fact" },
			"torn": { "title": "찢긴 종이", "text": "장부에서 몇 장이 뜯겨 나갔다. 남은 장 끝에 이겸 선생의 글씨가 걸려 있다.", "kind": "fact" },
			"tea": { "title": "아직 따뜻한 차", "text": "찻잔에서 김이 오른다. 방금 전까지 누가 있었다.", "kind": "fact" },
			# v2.2 박규상 복선 — 범죄 단서로 강조하지 않는다(평소 거래 기록)
			"slip": { "title": "반쯤 찢긴 납품표", "text": "책 묶음 아래 깔린 종이·먹 납품표. 끝에 ‘박규상 객주’ 인장(朴).", "kind": "fact" },
			"figure": { "title": "골목의 사내", "text": "피맛골 어귀에서 이쪽을 보던 사내. 가볍고, 빠르다. 골목을 제 집처럼 안다.", "kind": "fact" },
			"rooftop": { "title": "지붕 위의 실루엣", "text": "기와 지붕 위를 달렸다. 담도 지붕도 길로 쓴다.", "kind": "fact" },
			"papers": { "title": "세 장의 종이", "text": "강릉 · 경주 · 황주. 이겸 선생의 필체. 뒷면에 다른 글씨 — “쫓아올 테면 제대로 보고 오시오.”", "kind": "fact" },
			"name": { "title": "‘우치’", "text": "포졸이 그렇게 불렀다. 지붕을 제 마당처럼 다닌다고.", "kind": "heard", "by": "포졸" },
			"thump": { "title": "빈 창고의 소리", "text": "책방 옆 빈 창고에서 무언가 부딪는 소리. 빗장은 바깥에서 질려 있었다.", "kind": "fact" },
			"chaekkwae": { "title": "책쾌의 말", "text": "“그 사람도 옛 기록을 찾았소.” 더는 말하지 않는다.", "kind": "heard", "by": "책쾌" },
		},
		"rules": {},
		"anchors": anchors(),
		# 지도에 적힐 곳(scripts/region/discovery.gd): 이겸의 쪽지가 '종루 뒤 피맛골, 책쾌'를 일러 준다(들음) — 추격 길·빈 창고는 가 봐야
		"map_places": [
			{ "id": "jongno", "name": "종루", "at": "bosingak", "building": true, "radius": 24.0, "known": "c('note')" },
			{ "id": "shop", "name": "책쾌의 책방", "at": "shop", "building": true, "radius": 10.0, "known": "c('note')" },
			{ "id": "bridge", "name": "광통교", "at": "bridge", "building": true, "radius": 14.0 },
		],
		"journal": {
			"unknowns": [
				{ "text": "책쾌는 어디로 갔는가.", "when": "c('open_door')", "until": "c('thump') or c('chaekkwae')" },
				{ "text": "지붕을 타고 달아난 사내는 누구인가.", "when": "c('figure') or c('rooftop')", "until": "c('name')" },
				{ "text": "이겸 선생은 무엇을 찾고 있었는가.", "when": "c('torn')", "until": "c('chaekkwae')" },
			],
			"places": [
				{ "name": "숭례문", "when": "true" }, { "name": "종루", "when": "c('note')" },
				{ "name": "책쾌의 책방", "when": "c('open_door')" }, { "name": "광통교", "when": "c('papers')" },
			],
		},
		"chases": chases(),
		"actors": actors(),
		"objects": objects(),
		"triggers": triggers(),
		"props": props(),
		"events": events(),
	}

static func anchors() -> Dictionary:
	return {
		# 도착·입성
		"gate_front": [-644.2, -309.6], "gate": [-644.2, -331.7], "gate_in": [-641.0, -352.0], "gate_view": [-644.0, -360.0],
		"jongno": [-291.2, -878.0], "jongno_view": [-250.0, -885.0], "bosingak": [-291.2, -873.5],
		# 책방(hy_sc_chaekbang: 가운데 (−252, −938), 앞 = 남쪽 피맛골, 뒤창 = 북쪽 뒷골목 z −942.8)
		"shop": [-252.0, -938.0], "shop_door": [-252.0, -933.6], "shop_front": [-252.0, -930.2], "shop_in": [-252.0, -936.2],
		"ink": [-251.9, -938.25], "string": [-249.5, -937.1], "torn": [-250.9, -937.1], "tea": [-251.25, -937.65],
		"window": [-250.4, -940.4], "window_out": [-250.4, -942.8], "slip": [-253.5, -937.0], "counter": [-252.0, -936.6], "shelf": [-253.9, -937.4],
		# 빈 창고(hy_sc_bin_changgo: (−241.6, −938.6), 대문 칸은 서쪽 반, 묶인 자리 bound (−240.7, −939.0))
		"warehouse": [-241.6, -938.6], "warehouse_gate": [-243.2, -934.2], "warehouse_in": [-242.6, -937.6], "bound": [-240.7, -939.0],
		# 추격 길
		"lane_mouth": [-221.6, -929.5], "bridge": [-313.6, -815.4], "bridge_north": [-312.5, -826.0], "papers": [-313.0, -817.6],
		"pojol_bridge": [-306.5, -824.0],
		# 순찰
		"pj_a1": [-340.0, -884.0], "pj_a2": [-215.0, -884.0], "pj_b1": [-298.0, -826.0], "pj_b2": [-262.0, -826.5],
		# 소문
		"rumor_jongno": [-280.0, -884.0], "rumor_pimat": [-240.0, -930.0],
	}

# ---------------------------------------------------------------------------
# 추격 S1003(scripts/story/chase.gd). 앞섬·지름길·놓침 값은 여기서만 고친다.
# ---------------------------------------------------------------------------
static func chases() -> Dictionary:
	return {
		"s1003": {
			"actor": "woochi", "speed": 4.4, "burst": 6.3, "lead": 13.0, "min_lead": 6.0, "wait_lead": 27.0,
			"lose_lead": 46.0, "lose_off": 32.0, "lose_time": 6.0, "wake_lead": 17.0, "wake_time": 7.0, "retry_back": 9.0,
			"camera": { "distance": 40.0, "pitch": 47.0 }, "frame_reach": 18.0, "frame_mix": 0.55, "end_anim": "idle", "vanish_delay": 1.4,
			"segments": [
				# 피맛골 → 시전 뒤 풀밭
				{ "mode": "lane", "checkpoint": true, "run": ["lane_mouth", [-221.0, -916.0], [-216.0, -908.6]],
					"follow": ["shop_front", [-236.0, -930.0], "lane_mouth", [-221.0, -916.0], [-216.0, -908.6]] },
				# 지름길: 시전 행랑 뒤 담을 타고 지붕으로 — 플레이어는 동쪽 틈(x −191)으로 돈다
				{ "mode": "climb", "shortcut": true, "run": [[-215.6, -902.0]], "y": 4.1, "speed": 0.45,
					"follow": [[-216.0, -908.6], [-205.0, -907.6]], "caption": "사내가 시전 담을 짚고 지붕으로 뛰어오른다!" },
				{ "mode": "roof", "run": [[-209.0, -897.6], [-201.0, -896.0]], "speed": 0.9,
					"follow": [[-205.0, -907.6], [-192.0, -905.4], [-191.2, -897.5]] },
				{ "mode": "drop", "run": [[-199.6, -890.6]], "speed": 0.8, "anim": "crouch",
					"follow": [[-191.2, -897.5], [-191.2, -892.0]] },
				# 운종가를 건너 중촌 골목(hy_alley_177)으로
				{ "mode": "lane", "checkpoint": true, "run": [[-195.0, -882.0], [-190.4, -872.0], [-190.4, -846.5]],
					"follow": [[-191.2, -892.0], [-190.6, -872.0], [-190.4, -846.5]], "call": "chase_pojol" },
				# 기와 지붕 줄(중촌 92·93·94) — 지붕 위 실루엣. 플레이어는 남쪽 골목(hy_alley_141, z −828.6)으로
				{ "mode": "climb", "shortcut": true, "run": [[-198.6, -843.4]], "y": 4.3, "speed": 0.5,
					"follow": [[-190.4, -846.5], [-190.4, -829.0]], "caption": "또 지붕이다!" },
				{ "mode": "roof", "ink": true, "run": [[-205.5, -838.6], [-239.0, -838.6]], "speed": 0.95,
					"follow": [[-190.4, -829.0], [-243.0, -828.8]] },
				{ "mode": "drop", "run": [[-242.2, -831.0]], "speed": 0.8, "anim": "crouch",
					"follow": [[-243.0, -828.8], [-246.0, -826.0]] },
				# 개천 둑을 따라 광통교로
				{ "mode": "bank", "checkpoint": true, "run": [[-250.0, -822.5], [-256.0, -816.5], [-272.0, -815.5], [-289.0, -815.5], [-298.0, -821.0], [-305.0, -826.5], "bridge_north"],
					"follow": [[-246.0, -826.0], [-250.0, -822.5], [-256.0, -816.5], [-272.0, -815.5], [-289.0, -815.5], [-298.0, -821.0], [-305.0, -826.5], "bridge_north"],
					"caption": "사내가 개천 둑으로 꺾는다." },
				# 광통교를 건너 사라진다(끝 자리)
				{ "mode": "lane", "run": ["bridge", [-312.6, -807.0], [-309.5, -797.0]],
					"follow": ["bridge_north", "bridge", [-312.6, -808.0]] },
			],
		},
	}

# ---------------------------------------------------------------------------
# 인물 — CHR_MAIN_003 우치, CHR_MAIN_007 책쾌, CHR_HUM_016 포졸
# ---------------------------------------------------------------------------
static func actors() -> Array:
	return [
		{ "id": "woochi", "chr": "CHR_MAIN_003", "kind": "woochi", "name": "사내", "at": "lane_mouth", "facing": "left",
			"when": "f('woochi_seen') and not f('chase_done')" },
		{ "id": "chaekkwae", "chr": "CHR_MAIN_007", "kind": "chaekkwae", "name": "책쾌",
			"at": { "done": "counter", "default": "bound" }, "facing": "down", "anim": { "done": "sit", "default": "tied" },
			"when": "f('heard_thump')", "radius": 2.4,
			"talk": [
				{ "when": "ph('done') and fn('act2_all_done') and not f('act3_hook')", "steps": [{ "event": "S1401" }] },
				{ "when": "ph('done')", "steps": [
					{ "say": "책쾌", "lines": ["책 보러 왔소, 길 물으러 왔소?"] },
					{ "choice": "", "loop": true, "options": [
						{ "label": "강릉 쪽은 어떻소?", "when": "not f('ask_gn')", "do": [{ "flag": "ask_gn" },
							{ "say": "책쾌", "lines": ["대관령을 넘어야 하오. 제사 철엔 고갯길이 시끄럽지."] }] },
						{ "label": "경주는?", "when": "not f('ask_gj')", "do": [{ "flag": "ask_gj" },
							{ "say": "책쾌", "lines": ["남쪽 끝이오. 무덤이 산처럼 솟은 고을."] }] },
						{ "label": "황주는?", "when": "not f('ask_hj')", "do": [{ "flag": "ask_hj" },
							{ "say": "책쾌", "lines": ["의주 가는 길 위요. 바다 쪽 일이면 장산곶까지 가야 할 거요."] }] },
						{ "label": "그만 가 보겠소.", "end": true }] }] },
				{ "when": "not f('freed')", "steps": [{ "event": "S1005" }] },
			] },
		{ "id": "pojol_a", "chr": "CHR_HUM_016", "kind": "pojol", "name": "포졸", "at": "pj_a1", "facing": "right",
			"patrol": ["pj_a1", "pj_a2"], "patrol_speed": 1.25,
			"talk": [
				{ "when": "f('chase_done')", "steps": [{ "say": "포졸", "lines": ["지붕 타는 놈 말이오? 잡히는 꼴을 못 봤소."] }] },
				{ "when": "true", "steps": [{ "say": "포졸", "lines": ["길 막지 말고 비켜 서시오."] }] },
			] },
		{ "id": "pojol_b", "chr": "CHR_HUM_016", "kind": "pojol", "name": "포졸", "at": { "default": "pj_b1" }, "facing": "left",
			"patrol": ["pj_b1", "pj_b2"], "patrol_speed": 1.1,
			"talk": [
				{ "when": "f('chase_done')", "steps": [{ "say": "포졸", "lines": ["우치 그놈이오. 쫓아 봐야 헛걸음이지."] }, { "clue": "name" }] },
				{ "when": "true", "steps": [{ "say": "포졸", "lines": ["개천 둑은 미끄럽소. 조심하시오."] }] },
			] },
	]

# ---------------------------------------------------------------------------
# 조사 대상
# ---------------------------------------------------------------------------
static func objects() -> Array:
	var shop := func(id: String, label: String, title: String, text, state: Array) -> Dictionary:
		var steps := []
		if not state.is_empty(): steps.append({ "call": "prop", "args": state })
		steps.append_array([{ "examine": title, "text": text }, { "clue": id }, { "call": "check_shop" }])
		return { "id": id, "at": id, "label": label, "radius": 1.7, "when": "f('in_shop') and not c('%s')" % id, "steps": steps }
	return [
		shop.call("ink", "먹통 · 살펴보기", "넘어간 먹통", ["먹통이 엎어져 먹물이 서안 끝까지 흘렀다.", "손끝에 묻어난다. 아직 마르지 않았다."], []),
		shop.call("string", "끈 · 살펴보기", "끊어진 끈", ["책 묶음을 매던 끈이 기둥 곁에 떨어져 있다.", "끝이 칼로 자른 듯 반듯하다."], []),
		shop.call("torn", "장부 · 살펴보기", "찢긴 종이", ["장부에서 몇 장이 뜯겨 나갔다.", "남은 장 끝에 낯익은 필체 — 이겸 선생의 글씨다."], []),
		shop.call("tea", "찻잔 · 살펴보기", "아직 따뜻한 차", ["찻잔에서 김이 오른다.", "잔은 하나. 마신 사람은 방금 전까지 여기 있었다."], []),
		{ "id": "window", "at": "window", "label": "뒤창 · 살펴보기", "radius": 1.8, "when": "f('in_shop') and not c('window')",
			"steps": [
				{ "examine": "열린 뒤창", "text": ["뒤창 살이 밖으로 열려 있다.", "창턱 흙에 짚신 앞꿈치 자국. 창 밖 뒷골목으로 이어진다."] },
				{ "clue": "window" }, { "call": "show_tracks" }, { "call": "check_shop" }] },
		# v2.2: 책 묶음 아래 납품표(책방 단서 수에는 넣지 않는다 — 추격 조건과 무관)
		{ "id": "slip", "at": "slip", "label": "책 묶음 · 들춰 보기", "radius": 1.5, "when": "f('in_shop') and not c('slip')",
			"steps": [
				{ "examine": "반쯤 찢긴 납품표", "text": ["책 묶음 아래 납품표가 깔려 있다. 종이 스무 묶음, 먹 열 정.", "찢긴 끝에 붉은 인장 하나 — ‘박규상 객주’."], "kind": "item" },
				{ "clue": "slip" }, { "call": "park_slip" }] },
		# S1004: 놓친 자리의 종이 세 장
		{ "id": "papers", "at": "papers", "label": "다리 난간의 종이 · 살펴보기", "radius": 2.6, "when": "f('chase_done') and not c('papers')",
			"steps": [{ "event": "S1004" }] },
		# S1005 앞: 빈 창고 빗장
		{ "id": "warehouse_gate", "at": "warehouse_gate", "label": "빈 창고 · 살펴보기", "label_if": ["f('heard_thump')", "빈 창고 · 빗장 벗기기"], "radius": 2.4,
			"when": "f('case_started') and not f('gate_open')",
			"steps": [{ "if": "f('heard_thump')", "then": [{ "call": "open_warehouse" }],
				"else": [{ "examine": "빈 창고", "text": "빗장이 바깥에서 질러진 빈 창고. 안은 조용하다." }] }] },
	]

static func triggers() -> Array:
	return [
		# S1001: 숭례문을 지나 도성 안으로, 종루까지
		{ "id": "s1001_gate", "at": "gate", "radius": 18.0, "when": "ph('explore') and not f('gate_passed')", "steps": [
			{ "flag": "gate_passed" }, { "caption": "숭례문. 문 안쪽에서 소리가 밀려온다 — 장사치, 수레, 사람.", "sec": 2.6 }] },
		{ "id": "s1001_jongno", "at": "jongno", "radius": 34.0, "when": "ph('explore') and not f('s1001_done')", "steps": [
			{ "flag": "s1001_done" }, { "flag": "gate_passed" },
			{ "toast": "종루. 쪽지대로라면 이 큰길 뒤가 피맛골이다.", "kind": "journal" }] },
		# S1002: 책방 문턱
		{ "id": "s1002_door", "at": "shop_door", "radius": 3.0, "when": "ph('explore') and not f('in_shop')", "event": "S1002" },
		# S1003: 뒤창을 보고 단서 셋 이상 — 책방을 나서면 골목 어귀의 사내
		{ "id": "s1003_start", "at": "shop_front", "radius": 3.6, "when": "ph('explore') and c('window') and fn('shop_clues') >= 3 and not f('chase_done')",
			"event": "S1003" },
		# 놓쳤고 발자국을 따라가기로 했다: 끝 자리(광통교)에 닿으면
		{ "id": "s1003_tracks_end", "at": "bridge", "radius": 12.0, "when": "f('chase_lost') and not f('chase_done')", "steps": [
			{ "flag": "chase_done" }, { "caption": "발자국은 광통교 난간 앞에서 끊겼다.", "sec": 2.4 }] },
		# 종이를 본 뒤 책방 가까이: 빈 창고의 소리(S1005 앞)
		{ "id": "s1005_thump", "at": "warehouse", "radius": 16.0, "when": "c('papers') and not f('heard_thump')", "steps": [
			{ "flag": "heard_thump" }, { "shake": 0.06, "sec": 0.3 },
			{ "caption": "책방 옆 빈 창고에서 쿵— 쿵— 둔한 소리.", "sec": 2.4 }, { "clue": "thump" }] },
	]

# ---------------------------------------------------------------------------
# 소품(조건이 참일 때만) — 추격 발자국(world.decals), 다리 위 종이
# ---------------------------------------------------------------------------
static func props() -> Array:
	return [
		# 뒤창 → 뒷골목 → 피맛골은 미리 깔린 데칼 그룹 s1003_tracks(사건 함수 show_tracks가 켠다). 그 뒤 길은 여기서
		{ "id": "d_tracks_lane", "trail": { "kind": "foot", "points": ["lane_mouth", [-221.0, -916.0], [-216.0, -908.6]], "step": 0.85, "size": 0.5 },
			"when": "f('woochi_seen')" },
		{ "id": "d_tracks_jongno", "trail": { "kind": "foot", "points": [[-199.6, -890.6], [-195.0, -882.0], [-190.4, -872.0], [-190.4, -846.5]], "step": 1.0, "size": 0.5 },
			"when": "f('woochi_seen')" },
		{ "id": "d_tracks_bank", "trail": { "kind": "wet_foot", "points": [[-242.2, -831.0], [-250.0, -822.5], [-256.0, -816.5], [-272.0, -815.5], [-289.0, -815.5], [-298.0, -821.0], [-305.0, -826.5], "bridge_north"],
			"step": 0.95, "size": 0.5 }, "when": "f('woochi_seen')" },
		{ "id": "d_tile", "decal": { "kind": "drag", "size": 1.2, "ry": 0.4 }, "at": [-242.6, -830.6], "when": "f('woochi_seen')" },
		# v2.2 납품표(朴 인장) — 책 묶음 아래로 반쯤 삐져나옴. 허브에서는 책쾌가 치웠다
		{ "id": "p_slip", "kit": "story/park_mark", "params": { "kind": "slip", "size": 0.26 }, "at": "slip", "dy": 0.46, "ry": 0.5,
			"when": "not ph('done')" },
		# 다리 위 종이 세 장(조사 전까지)
		{ "id": "p_papers", "kit": "scenario/props", "params": { "kind": "jangbu", "n": 3, "seed": 31 }, "at": "papers", "dy": 0.05, "ry": 0.3,
			"when": "f('chase_done') and not c('papers')" },
	]

# ---------------------------------------------------------------------------
# 사건 장면(§44 필드 + steps)
# ---------------------------------------------------------------------------
static func _ev(id: String, trigger: String, loc: String, tw: String, actions: String, branches: String, wsc: String, steps: Array) -> Dictionary:
	return {
		"EVENT_ID": id, "RECORD_TITLE": "비어 있는 책방", "SOURCE_ID": "MAIN-ACT1",
		"SOURCE_TITLE_INTERNAL": "메인 — 우치(전우치 이름을 빌린 라이벌)의 첫 등장", "SOURCE_TYPE": "classic", "SOURCE_REGION_GRADE": "D",
		"SOURCE_REGION_NOTE": "메인 시나리오 §10. 전우치 전승 자체(F21 빈 관 등)는 쓰지 않고 이름만 빌린 인물의 행동(지붕·골목·종이)만 보인다(§36.2 ECHO).",
		"ADAPTATION_MODE": "ECHO", "TRIGGER": trigger, "LOCATION_TYPE": loc, "TIME_WEATHER": tw,
		"PLAYER_ACTIONS": actions, "RESOLUTION_BRANCHES": branches, "WORLD_STATE_CHANGE": wsc, "SOURCE_VERIFIED": true,
		"steps": steps,
	}

static func events() -> Dictionary:
	return {
		"S1001": _ev("S1001", "MAIN_MASTER_TRACE = HANYANG, 한양 첫 진입(노정·역마)", "남대문 → 종로", "낮 · 맑음", "이겸의 쪽지대로 책쾌를 찾는다",
			"-", "사건 기록 생성", [
			{ "phase": "explore" }, { "flag": "case_started" }, { "time": 11.0 }, { "weather": "clear" },
			{ "call": "arrive" },
			{ "clue": "note", "quiet": true },
			{ "toast": "새 사건 — 「비어 있는 책방」", "kind": "journal" },
			{ "journal": "이겸의 쪽지 — 종루 뒤 피맛골, 책쾌" },
		]),
		"S1002": _ev("S1002", "책방 문턱", "피맛골 책쾌 책방", "낮", "먹통·끈·뒤창·종이·찻잔을 조사한다", "-", "-", [
			{ "flag": "in_shop" }, { "flag": "s1001_done" },
			{ "caption": "문이 열려 있다. 아무도 없다.", "sec": 2.2 },
			{ "clue": "open_door", "quiet": true },
		]),
		"S1003": _ev("S1003", "뒤창 + 단서 셋 이상, 책방을 나섬", "피맛골 → 운종가 → 중촌 골목·지붕 → 개천 둑 → 광통교", "낮",
			"쫓는다(놓치면 다시 쫓거나 발자국을 따라간다)", "끝까지 따라감 / 놓치고 발자국을 따라감", "-", [
			{ "call": "woochi_appears" },
			{ "call": "run_chase" },
		]),
		"S1004": _ev("S1004", "놓친 자리(광통교)의 종이", "광통교", "낮", "종이를 읽는다", "-", "MAIN_WOOCHI_KNOWN = true", [
			{ "examine": "세 장의 종이", "text": ["난간 틈에 접힌 종이 세 장이 끼워져 있다.", "강릉 · 경주 · 황주. 이겸 선생의 필체다."], "kind": "item" },
			{ "examine": "뒷면", "text": ["뒤집으니 다른 글씨가 있다.", "“쫓아올 테면 제대로 보고 오시오.”"], "kind": "clue" },
			{ "clue": "papers" }, { "give": PAPERS, "n": 3 },
			{ "var": "MAIN_WOOCHI_KNOWN", "value": true },
			{ "journal": "종이 세 장 — 강릉 · 경주 · 황주" },
		]),
		"S1005": _ev("S1005", "빈 창고에서 소리, 빗장을 벗김", "책방 옆 빈 창고", "낮", "끈을 끊어 책쾌를 푼다", "-", "-", [
			{ "choice": "", "options": [{ "label": "(끈을 끊는다)" }] },
			{ "call": "free_chaekkwae" },
			{ "say": "책쾌", "lines": ["…죽일 생각은 없던 모양이오."] },
			{ "say": "나그네", "lines": ["이겸 선생은?"] },
			{ "say": "책쾌", "lines": ["그 사람도 옛 기록을 찾았소."] },
			{ "say": "책쾌", "lines": ["박 객주? 종이값은 꼬박 치르는 큰손이오."], "when": "c('slip')" },
			{ "clue": "chaekkwae" },
			{ "event": "S1006" },
		]),
		"S1006": _ev("S1006", "S1005 직후", "책쾌 책방(허브)", "낮", "세 갈래 중 먼저 갈 곳을 고른다", "-",
			"한양 주막·장터에 강릉·경주·황주 소문, 세 노정 열림, ACT 3은 세 사건 뒤", [
			{ "call": "open_hub" },
		]),
		# §14 갈고리(ACT 2가 모두 끝난 뒤 — 지금은 조건만 걸어 둔다)
		"S1401": _ev("S1401", "강릉·경주·황주 사건 모두 해결 뒤 책쾌", "책쾌 책방", "낮", "탁자 위 통행문서를 본다", "-", "평양 노정(ACT 3) 열림", [
			{ "flag": "act3_hook" },
			{ "say": "책쾌", "lines": ["우치가 평양으로 올라갔소."] },
			{ "examine": "탁자 위 통행문서", "text": ["관인이 찍힌 통행문서. 진짜인지 아닌지는 아직 가릴 수 없다."], "kind": "item" },
			{ "give": PASS_DOC },
			{ "examine": "종이 뭉치 포장지", "text": ["통행문서 밑 종이 뭉치를 묶은 포장지에 붉은 납품 표식 — 朴. '박규상 객주'."], "kind": "item" },
			{ "call": "park_wrap" },
			{ "say": "책쾌", "lines": ["저 상단 종이는 한양 어디서나 쓰오."] },
			{ "var": "ACT3_OPEN", "value": true },
			{ "journal": "평양으로 — 우치의 통행문서" },
		]),
	}
