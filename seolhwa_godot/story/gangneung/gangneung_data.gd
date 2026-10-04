# 사건 「고개에 남은 종소리」(ACT 2A 강릉, S2001~S2008) — 이야기 데이터.
# 시나리오: seolhwa/docs/scenario/seolhwarok_master_scenario_storyboard_v2.1_folklore_only_subevents.md §11 (규칙 §1.4·§1.5, 호신물 §6.5,
#   변수 §7, 소문 §24, 대사 §27, 컷신 §28, 실패 §29, 지역 변화 §30, 소스 잠금 §36, 전승 앵커 §37 A09 대관령 국사성황·산신)
# 체감 장르(§1.7): 의식·시간 압박 — 새벽 국사성황 모시기 전까지. 전투 없음(C만 '괴이를 베며 억지로 지나감', 상대가 베이지 않는다).
# 구조(§1.4): 사람의 도둑질(제물·방울)과 사람이 아닌 것의 흔적(옮겨진 경계석·긁힘·잔영·방울 소리)이 한 길 위에 겹쳐 있다.
#   원인은 끝까지 확정하지 않는다. 해결 수단은 모두 먼저 보여 준다(§1.5): 짐승 흔적 읽기(남원), 방울(도둑에게서), 새 금줄·호신부(월심),
#   경계석 빈자리(낮 조사), 규칙(밤 관찰).
# 자리(게임 좌표 x,z — GW_GANGNEUNG): 강릉 남대천가 단오장 굿당(1336, −343) → 대관령 반정 주막(−2097, 1310) → 국사성황사 길
#   (region.json seonghwangsa_trail) 중턱 옛 경계석(−2394, 1386) → 국사성황사(−2486, 1439). 반정·성황사 사이 약 430m.
# 조건식: story_runner(f·k·c·has·n·ph·v·out·w·fn) + 잔영 체계(tal·zone·night·spv — scripts/story/spirits.gd).
extends RefCounted

const BELL := "ITM_RIT_006"      # 제의용 방울
const ROPE := "ITM_RIT_005"      # 금줄(새것)
const CHARM := "ITM_RIT_001"     # 호신부
const COIN := "COIN"
const RESOLVED := "out('A') or out('B') or out('C')"

static func data() -> Dictionary:
	return {
		"case": {
			"id": "gangneung", "record_title": "고개에 남은 종소리", "region": "GW_GANGNEUNG", "outcome_var": "CASE_GANGNEUNG_OUTCOME",
			"start_hour": 10.0, "start_event": "S2001",
			# 한양 S1006(세 방향 열림) 뒤에만 선다 — 아니면 이 권역은 소문만(story_director case.requires)
			"requires": { "ACT2_OPEN": true },
			"rule_label": "고개의 규칙", "rules_title": "고개의 규칙",
			# 새로 시작할 때 되돌리는 공통 변수(이 사건이 정하는 것만 — 남원·한양 결과는 그대로)
			"reset_vars": { "CASE_GANGNEUNG_OUTCOME": "", "CASE_GANGNEUNG_DETAIL": "" },
		},
		"items": {
			BELL: "제의용 방울", ROPE: "금줄", CHARM: "호신부", COIN: "엽전",
			"ITM_TOOL_009": "사건 기록책", "ITM_WPN_001": "환도", "ITM_WPN_002": "활", "ITM_AMMO_001": "화살",
		},
		"hidden_items": ["ITM_TOOL_009", "ITM_WPN_001", "ITM_WPN_002", "ITM_AMMO_001", CHARM],
		"clues": {
			"rumor_bell": { "title": "사라진 방울", "text": "대관령 국사성황께 올릴 제의용 방울이 없어졌다. 모시기는 내일 새벽이다.", "kind": "heard", "by": "무녀", "by_if": [["fn('route_is', 'jegwan')", "제관"]] },
			"moved_stone": { "title": "빈 돌자리", "text": "길섶 흙이 깊게 팼다. 둘레 이끼가 동그랗게 눌렸다 — 오래 박혀 있던 돌이 뽑혀 나갔다. 끌린 자국 곁에 발자국이 없다.", "kind": "fact" },
			"stone_carving": { "title": "누운 선돌", "text": "숲 쪽으로 몇 걸음, 이끼 낀 선돌이 누워 있다. 반쯤 닳은 새김 — 성황 길의 경계를 표하던 돌이다.", "kind": "fact" },
			"cut_rope": { "title": "끊긴 금줄", "text": "길을 가로지르던 금줄이 칼에 잘렸다. 한가운데 방울을 달던 고리만 남았다.", "kind": "fact" },
			"scratches": { "title": "바위의 가는 긁힘", "text": "가는 줄 셋. 짐승 발톱보다 가늘고, 사람 연장 자국처럼 곧지도 않다.", "kind": "fact" },
			"thief_prints": { "title": "뒤축 감은 짚신 자국", "text": "한쪽 뒤축이 뭉툭한 짚신 — 새끼로 감은 것이다. 무엇을 진 듯 깊게 팼다.", "kind": "fact" },
			"missing_offering": { "title": "빈 제물상", "text": "북어·초·쌀이 놓였던 자리만 남았다. 짚신 자국이 상 앞까지 왔다가 고개 아래로 내려간다.", "kind": "fact" },
			"split": { "title": "두 갈래 흔적", "text": "짚신 자국은 금줄 → 제물상 → 반정 쪽으로만 간다. 끌린 돌과 긁힘 둘레엔 사람 자국도, 짐승 자국도 없다.", "kind": "fact" },
			"stash": { "title": "바위 밑 꾸러미", "text": "북어·초·쌀 자루, 끊어 온 금줄 토막. 방울은 없다.", "kind": "fact" },
			"sandals": { "title": "주막 일꾼의 짚신", "text": "주막 처마 밑에 말리는 짚신. 뒤축을 새끼로 감았다.", "kind": "fact" },
			"confession": { "title": "덕보의 말", "text": "제물과 방울은 장에 내다 팔려고 가져갔다. 그 돌은 자기가 갔을 때 벌써 누워 있었다고 한다.", "kind": "heard", "by": "덕보" },
			"night_bell": { "title": "밤의 방울 소리", "text": "방울은 없는데 방울 소리가 난다. 소리는 옛 경계석 쪽으로 이끈다.", "kind": "fact" },
			"night_figure": { "title": "고갯길의 잔영", "text": "밤길에 희끄무레한 형체가 보였다 사라진다. 옛 차림 같다.", "kind": "fact" },
		},
		"rules": {
			"R_THIEF_APART": { "title": "도둑의 흔적은 따로다", "text": "사람이 훔친 자리와 돌이 옮겨진 자리는 흔적이 섞이지 않는다.", "kind": "guess" },
			"R_SOUND_LEADS": { "title": "방울 소리는 경계석으로 이끈다", "text": "밤이면 방울 없는 방울 소리가 옛 경계석 쪽에서 난다.", "kind": "guess" },
			"R_FAINT_OUT": { "title": "경계석 밖에선 희미하다", "text": "옛 경계 밖에서 본 형체는 얼룩지고 흐리다.", "kind": "fact" },
			"R_CLEAR_IN": { "title": "경계석 안에선 또렷하다", "text": "옛 경계 안으로 들어서면 형체가 또렷해진다.", "kind": "fact" },
			"R_BELL_HOME": { "title": "방울이 제자리 가까이 가면 소리가 멎는다", "text": "방울을 옛 경계석 자리로 가져가자 고개의 방울 소리가 그쳤다.", "kind": "fact" },
		},
		"anchors": anchors(),
		# 지도에 적힐 곳: 무녀·제관이 반정과 국사성황사 길을 일러 준다(들음). 옛 경계석 자리는 가 봐야 적힌다
		"map_places": [
			{ "id": "danoh", "name": "단오장 굿당", "at": "gutdang", "radius": 20.0, "start_known": true },
			{ "id": "banjeong", "name": "대관령 반정 주막", "at": "bj_jumo", "building": true, "radius": 18.0, "known": "f('case_started')" },
			{ "id": "guksa", "name": "국사성황사", "at": "altar_spot", "building": true, "radius": 20.0, "known": "f('case_started')" },
			{ "id": "stone", "name": "옛 경계석 자리", "at": "stone_socket", "radius": 12.0 },
		],
		# 지도 붉은 표(갈 곳, 보강서 §20) — 무녀·제관·흔적 가르기가 일러 준 곳만. 도둑·잔영·꾸러미 자리는 넣지 않는다(fn 금지)
		"map_leads": [
			{ "id": "gn_danoh", "name": "단오장 굿당", "at": "gutdang", "hub": true, "when": "true", "until": "ph('done')",
				"note": "S2001 도착 — 단오장 굿당(start_known)" },
			{ "id": "gn_banjeong", "name": "대관령 반정(제관)", "at": "bj_jumo", "when": "f('case_started')",
				"until": "talked('jegwan') > 0 or talked('jumo_bj') > 0 or f('thief_caught')",
				"note": "S2001 무녀 “제관 어른은 반정에 올라가 계시오.”" },
			{ "id": "gn_trail", "name": "국사성황사 길", "at": "altar_spot", "when": "f('case_started') and talked('jegwan') > 0",
				"until": "c('missing_offering') or f('tracks_split')",
				"note": "제관 “성황사 길을 살펴봐 주시오. 새벽까지 시간이 없소.”(jegwan_talk) — 성황사 제물상을 보거나 흔적을 가르면 사라진다" },
			{ "id": "gn_thief_way", "name": "반정 주막 쪽", "at": "bj_jumo", "when": "f('tracks_split')",
				"until": "c('sandals') or c('stash') or f('thief_caught')",
				"note": "S2003 흔적 가르기 토스트 “짚신 자국은 반정 주막 쪽으로 내려간다”" },
			{ "id": "gn_night_sound", "name": "소리 나는 데(옛 경계석 쪽)", "at": "stone_socket", "when": "ph('night') and c('night_bell')",
				"until": "f('bell_home') or f('resolved')",
				"note": "S2004 월심 “해 지면 오르시오. 소리 나는 데로.” · S2005 night_bell “소리는 옛 경계석 쪽으로 이끈다”" },
		],
		"journal": {
			"unknowns": [
				{ "text": "방울은 누가 가져갔는가.", "until": "c('confession') or c('stash')" },
				{ "text": "옛 경계석은 누가, 왜 옮겼는가." , "when": "c('moved_stone')" },
				{ "text": "밤의 방울 소리는 어디로 이끄는가.", "when": "c('night_bell')", "until": "k('R_SOUND_LEADS')" },
			],
			"places": [
				{ "name": "단오장 굿당", "when": "true" }, { "name": "대관령 반정 주막", "when": "talked('jumo_bj') > 0 or c('sandals')" },
				{ "name": "옛 경계석 자리", "when": "c('moved_stone') or c('cut_rope')" }, { "name": "국사성황사", "when": "c('missing_offering')" },
			],
		},
		"actors": actors(),
		"objects": objects(),
		"triggers": triggers(),
		"props": props(),
		"events": events(),
		# ---- 잔영·소리·경계(scripts/story/spirits.gd) ----
		"spirits": spirits(),
		"sounds": sounds(),
		"zones": zones(),
		"dread": {
			"zone": "boundary_wide", "when": "ph('night') and not f('bell_home') and not f('resolved')",
			"rate": 0.055, "decay": 0.2, "on_full": [{ "call": "dread_out" }],
		},
	}

static func anchors() -> Dictionary:
	return {
		# 강릉 단오장(남대천가) — 굿당(성황당 + 신목)
		"town_start": [1341.0, -322.5], "gutdang": [1336.3, -342.8], "mudang_spot": [1339.8, -336.4],
		"market_a_spot": [1327.5, -330.5], "market_b_spot": [1331.4, -326.8], "streamers": [1344.5, -338.8],
		"town_crowd_a": [1347.0, -332.0], "town_crowd_b": [1344.5, -329.0], "town_wolsim": [1338.2, -337.6], "town_jegwan": [1341.8, -335.2],
		# 대관령 반정 주막
		"bj_arrive": [-2087.5, 1301.5], "bj_jumo": [-2094.2, 1315.8], "jegwan_bj": [-2090.4, 1318.2],
		"deokbo_spot": [-2103.2, 1316.8], "sandals_spot": [-2099.0, 1317.4], "bj_road": [-2083.0, 1296.0],
		"stash_spot": [-2114.0, 1302.5], "stash_look": [-2113.6, 1305.4], "thief_bound": [-2100.6, 1312.4],
		# 옛 경계석(국사성황사 길 중턱)
		"stone_socket": [-2394.5, 1386.5], "lying_stone": [-2400.5, 1393.0], "cut_rope": [-2392.0, 1381.0],
		"scratch_rock": [-2389.0, 1389.8], "prints_b": [-2385.5, 1379.0], "approach": [-2362.0, 1396.5],
		"stone_spirit": [-2396.4, 1384.6], "socket_stand": [-2393.0, 1383.0],
		# 국사성황사
		"altar_spot": [-2483.5, 1447.6], "wolsim_spot": [-2480.0, 1449.6], "shrine_front": [-2483.5, 1452.5],
		"rite_jegwan": [-2486.2, 1450.2], "rite_wolsim": [-2481.2, 1449.4], "rite_player": [-2483.0, 1455.5],
		"rite_deokbo": [-2489.0, 1452.0],
		# 밤: 따라가면 길을 잃는 잔영(숲 쪽으로)
		"lure_end": [-2226.0, 1471.0],
	}

# ---------------------------------------------------------------------------
# 인물(CHARACTER_MASTER) — 월심 CHR_MAIN_008(무당 베이스 고유변형), 덕보(하인/머슴 CHR_HUM_026 변형 — 마을 사람), 제관(CHR_HUM_024 양반)
# ---------------------------------------------------------------------------
static func actors() -> Array:
	return [
		# 단오장 굿당의 무녀(CHR_HUM_014) — 사건 기록이 생기는 자리 ①
		{ "id": "gut_mudang", "chr": "CHR_HUM_014", "kind": "shaman", "name": "무녀", "at": "mudang_spot", "facing": "down",
			"when": "not ph('done')",
			"talk": [
				{ "when": "not fn('hub_open')", "steps": [{ "say": "무녀", "lines": ["단오가 코앞이라 손이 모자라오."] }] },
				{ "when": "not f('case_started')", "steps": [{ "event": "S2001" }] },
				{ "when": "true", "steps": [
					{ "say": "무녀", "lines": ["제관 어른은 반정에 계시오. 새벽엔 모시러 올라가야 하는데…"] },
					{ "choice": "", "options": [
						{ "label": "대관령 반정으로 오른다", "do": [{ "call": "travel", "args": ["bj_arrive", "구산역을 지나 대관령 반정까지 올랐다."] }] },
						{ "label": "그만 가 보겠소.", "end": true }] }] },
			] },
		{ "id": "market_a", "chr": "CHR_HUM_002", "kind": "merchant", "name": "장꾼", "at": "market_a_spot", "facing": "right",
			"talk": [
				{ "when": RESOLVED, "steps": [{ "say": "장꾼", "lines": ["모시기가 무사히 끝났다니 장도 제대로 서겠소."] }] },
				{ "when": "true", "steps": [{ "say": "장꾼", "lines": ["방울이 없으면 국사성황을 어찌 모셔 오누."] }] }] },
		{ "id": "market_b", "chr": "CHR_HUM_010", "kind": "villager_f", "name": "아낙", "at": "market_b_spot", "facing": "left",
			"talk": [
				{ "when": "out('C')", "steps": [{ "say": "아낙", "lines": ["밤이면 아직도 고개 쪽에서 방울 소리가 들린대요."] }] },
				{ "when": "true", "steps": [{ "say": "아낙", "lines": ["오색 천 다느라 허리가 휘네."] }] }] },
		# 지역 변화(§30): 모시기가 끝나면 단오장에 사람이 는다
		{ "id": "crowd_a", "chr": "CHR_HUM_028", "kind": "peddler", "name": "장꾼", "at": "town_crowd_a", "facing": "left", "when": "ph('done')",
			"talk": [{ "when": "true", "steps": [{ "say": "장꾼", "lines": ["대관령 넘어 사흘 길을 왔소. 단오장 구경은 해야지."] }] }] },
		{ "id": "crowd_b", "chr": "CHR_HUM_029", "kind": "farmwife", "name": "아낙", "at": "town_crowd_b", "facing": "up", "when": "ph('done')",
			"talk": [{ "when": "true", "steps": [{ "say": "아낙", "lines": ["신목에 소원 천 하나 매고 왔어요."] }] }] },
		# 제관 — 반정에서 모시기를 준비한다. 끝나면 단오장 굿당
		{ "id": "jegwan", "chr": "CHR_HUM_024", "kind": "scholar", "name": "제관",
			"at": { "morning": "rite_jegwan", "done": "town_jegwan", "default": "jegwan_bj" }, "facing": { "morning": "up", "default": "down" },
			"talk": [
				{ "when": "ph('done')", "steps": [{ "call": "jegwan_done" }] },
				{ "when": "not fn('hub_open')", "steps": [{ "say": "제관", "lines": ["모시기 준비로 바쁘니 나중에 오시오."] }] },
				{ "when": "not f('case_started')", "steps": [
					{ "say": "제관", "lines": ["방울이 없어졌소. 국사성황께 올릴 방울이.", "새벽엔 모시러 올라가야 하는데."] },
					{ "call": "start_case", "args": ["jegwan"] }] },
				{ "when": "ph('night')", "steps": [{ "call": "jegwan_night" }] },
				{ "when": "true", "steps": [{ "call": "jegwan_talk" }] },
			] },
		{ "id": "jumo_bj", "chr": "CHR_HUM_015", "kind": "innkeeper", "name": "반정 주모", "at": "bj_jumo", "facing": "down",
			"talk": [
				{ "when": RESOLVED, "steps": [{ "say": "반정 주모", "lines": ["모시기 행렬이 지나갔소. 올해는 무사히."] }] },
				{ "when": "ph('night')", "steps": [{ "call": "jumo_night" }] },
				{ "when": "true", "steps": [
					{ "say": "반정 주모", "lines": ["고개는 해 떨어지면 혼자 넘지 마시오."], "when": "not f('case_started')" },
					{ "say": "반정 주모", "lines": ["덕보 그놈, 요새 장 얘기만 하더니…"], "when": "f('case_started') and not f('thief_caught')" },
					{ "say": "반정 주모", "lines": ["건넌방 비었소. 밤길 오를 거면 눈 좀 붙이고 가시오."], "when": "f('thief_caught')" },
					{ "choice": "", "loop": true, "options": [
						{ "label": "여기서 밤을 기다리겠소.", "when": "f('got_charm')", "end": true, "do": [{ "call": "rest" }] },
						{ "label": "그만 가 보겠소.", "end": true }] }] },
			] },
		# 덕보 — 반정 주막 일꾼(제물 도둑). 잔영과는 상관없다
		{ "id": "deokbo", "chr": "CHR_HUM_026", "kind": "thief", "name": "주막 일꾼",
			"at": { "morning": "rite_deokbo", "default": "deokbo_spot" }, "facing": "left",
			"anim": { "morning": "cower", "default": "idle" },
			"when": "not f('thief_fled') and (not f('thief_caught') or ph('morning'))",
			"talk": [
				{ "when": "f('thief_caught')", "steps": [{ "say": "덕보", "lines": ["…장에 팔면 겨울 날 쌀은 되겠다 싶었소."] }] },
				{ "when": "c('stash') and (c('sandals') or c('thief_prints'))", "steps": [{ "call": "confront_thief" }] },
				{ "when": "true", "steps": [{ "say": "주막 일꾼", "lines": ["장작 패느라 바쁘오. 볼일 없으면 가시오."] }] },
			] },
		{ "id": "deokbo_bound", "chr": "CHR_HUM_026", "kind": "thief", "name": "덕보", "at": "thief_bound", "facing": "down", "anim": "cower",
			"when": "ph('done') and f('thief_caught')",
			"talk": [{ "when": "true", "steps": [{ "say": "덕보", "lines": ["관아로 넘어가기 전에… 그 돌은 정말 내가 안 건드렸소."] }] }] },
		# 월심 — 국사성황사에서 굿 준비. 장황하게 설명하지 않는다(§11 S2004)
		{ "id": "wolsim", "chr": "CHR_MAIN_008", "kind": "wolsim", "name": "월심",
			"at": { "morning": "rite_wolsim", "done": "town_wolsim", "default": "wolsim_spot" }, "facing": { "done": "down", "default": "up" },
			"anim": { "morning": "ritual", "done": "ritual", "default": "ritual" },
			"when": "(f('tracks_split') and not ph('night')) or ph('morning') or ph('done')",
			"talk": [
				{ "when": "ph('done')", "steps": [{ "say": "월심", "lines": ["보이는 걸 다 쫓지는 않았구려."] }], },
				{ "when": "not f('got_charm')", "steps": [{ "event": "S2004" }] },
				{ "when": "true", "steps": [{ "say": "월심", "lines": ["해 지면 오르시오. 소리 나는 데로."] }] },
			] },
	]

# ---------------------------------------------------------------------------
# 조사 대상(낮 S2002 — 순서 없이) · 밤 경계석
# ---------------------------------------------------------------------------
static func objects() -> Array:
	var day := "f('case_started') and not ph('night')"
	return [
		{ "id": "socket", "at": "stone_socket", "label": "길섶의 팬 자리 · 살펴보기", "radius": 2.2, "when": day + " and not c('moved_stone')",
			"steps": [{ "examine": "빈 돌자리", "text": ["길섶 흙이 깊게 팼다. 둘레 이끼가 동그랗게 눌렸다.", "오래 박혀 있던 돌이 뽑혀 나갔다. 끌린 자국이 숲 쪽으로 이어지는데, 곁에 발자국이 하나도 없다."] },
				{ "clue": "moved_stone" }, { "call": "on_site_clue" }] },
		{ "id": "lying_stone", "at": "lying_stone", "label": "누운 돌 · 살펴보기", "radius": 2.2, "when": day + " and not c('stone_carving')",
			"steps": [{ "examine": "누운 선돌", "text": ["이끼 낀 선돌이 숲 쪽으로 누워 있다. 장정 둘은 붙어야 움직일 무게다.", "반쯤 닳은 새김 — 성황 길의 경계를 표하던 돌이다."] },
				{ "clue": "stone_carving" }, { "call": "on_site_clue" }] },
		{ "id": "cut_rope", "at": "cut_rope", "label": "끊긴 금줄 · 살펴보기", "radius": 2.4, "when": day + " and not c('cut_rope')",
			"steps": [{ "examine": "끊긴 금줄", "text": ["길을 가로지르던 금줄이 늘어져 있다. 단면이 곧다 — 칼로 잘랐다.", "한가운데 방울을 달던 고리만 남았다."] },
				{ "clue": "cut_rope" }, { "call": "on_site_clue" }] },
		{ "id": "scratch", "at": "scratch_rock", "label": "바위 · 살펴보기", "radius": 2.2, "when": day + " and not c('scratches')",
			"steps": [{ "call": "examine_scratch" }, { "clue": "scratches" }, { "call": "on_site_clue" }] },
		{ "id": "prints", "at": "prints_b", "radius": 2.4, "label": "발자국 · 살펴보기", "label_if": ["c('thief_prints')", "뒤섞인 흔적 · 가르기"],
			"when": day + " and (not c('thief_prints') or not f('tracks_split'))",
			"steps": [
				{ "if": "not c('thief_prints')", "then": [
					{ "examine": "짚신 자국", "text": ["짚신 자국이 금줄 아래를 지나 성황사 쪽으로 올라갔다가 내려왔다.", "한쪽 뒤축이 뭉툭하다 — 새끼로 감은 짚신이다. 내려올 때 더 깊다."] },
					{ "clue": "thief_prints" }, { "call": "on_site_clue" }],
				  "else": [{ "call": "split_tracks" }] }] },
		{ "id": "altar", "at": "altar_spot", "label": "국사성황사 제물상 · 살펴보기", "radius": 2.4, "when": day + " and not c('missing_offering')",
			"steps": [{ "examine": "빈 제물상", "text": ["북어·초·쌀이 놓였던 자리만 남았다.", "짚신 자국이 상 앞까지 왔다가 고개 아래로 내려간다."] },
				{ "clue": "missing_offering" }, { "call": "on_site_clue" }] },
		{ "id": "stash", "at": "stash_look", "label": "바위 밑 · 살펴보기", "radius": 2.6, "when": day + " and not c('stash') and (f('tracks_split') or c('thief_prints'))",
			"steps": [{ "examine": "바위 밑 꾸러미", "text": ["반정 주막 뒤 바위 밑에 보자기가 쑤셔 박혀 있다.", "북어·초·쌀 자루, 끊어 온 금줄 토막. 방울은 없다."] },
				{ "clue": "stash" }] },
		{ "id": "sandals", "at": "sandals_spot", "label": "처마 밑 짚신 · 살펴보기", "radius": 1.8, "when": day + " and not c('sandals') and c('thief_prints')",
			"steps": [{ "examine": "말리는 짚신", "text": "주막 처마 밑에 짚신 한 켤레. 뒤축을 새끼로 감았다. 일꾼 덕보의 것이다." }, { "clue": "sandals" }] },
		{ "id": "go_town", "at": "bj_road", "label": "강릉 읍내로 내려간다", "radius": 3.0, "when": "f('case_started') and not ph('night') and not ph('morning')",
			"steps": [{ "call": "travel", "args": ["town_start", "고개를 내려와 단오장으로 돌아왔다."] }] },
		# 밤(S2005~S2007): 옛 경계석 자리
		{ "id": "socket_night", "at": "socket_stand", "label": "옛 경계석 자리", "radius": 3.2, "when": "ph('night') and not f('resolved')",
			"steps": [{ "call": "stone_night" }] },
	]

static func triggers() -> Array:
	return [
		# S2001 단오장 주변대화(지나가며 엿듣는다)
		{ "id": "s2001_overhear", "at": "gutdang", "radius": 22.0, "when": "fn('hub_open') and not f('case_started')", "ambient": [
			["장꾼", "대관령 방울이 없어졌다지?"], ["아낙", "모시기가 내일 새벽인데…"]] },
		# 반정에 먼저 닿았을 때(노정으로 대관령을 넘어 들어온 경우)
		{ "id": "s2001_banjeong", "at": "bj_jumo", "radius": 16.0, "when": "fn('hub_open') and not f('case_started')", "ambient": [
			["반정 주모", "성황사 방울이 없어졌다오."], ["제관", "새벽까지 찾아야 하오."]] },
		# 밤: 방울 소리를 따라 경계석 가까이
		{ "id": "night_approach", "at": "approach", "radius": 14.0, "when": "ph('night') and not f('resolved')", "steps": [{ "call": "night_approach" }] },
	]

# ---------------------------------------------------------------------------
# 소품(kit/story/ritual.gd, 세계 데칼)
# ---------------------------------------------------------------------------
static func props() -> Array:
	var stone_moved := "not out('A')"
	return [
		# 단오 준비 흔적(S2001): 굿당 앞 오색 천
		{ "id": "p_streamers", "kit": "story/ritual", "params": { "kind": "streamers", "w": 6.5 }, "at": "streamers", "ry": 0.4 },
		{ "id": "p_streamers_done", "kit": "story/ritual", "params": { "kind": "streamers", "w": 5.0, "seed": 3 }, "at": [1349.0, -327.0], "ry": -0.2, "when": "ph('done')" },
		# 옛 경계석 자리
		{ "id": "p_socket", "kit": "story/ritual", "params": { "kind": "socket" }, "at": "stone_socket", "when": stone_moved },
		{ "id": "p_lying", "kit": "story/ritual", "params": { "kind": "stone", "lying": true }, "at": "lying_stone", "ry": 0.6, "when": stone_moved },
		{ "id": "p_restored", "kit": "story/ritual", "params": { "kind": "restored" }, "at": "stone_socket", "ry": 0.25, "when": "out('A')" },
		{ "id": "p_rope_cut", "kit": "story/ritual", "params": { "kind": "geumjul", "state": "BROKEN", "w": 3.4 }, "at": "cut_rope", "ry": 1.45, "when": "not out('A')" },
		{ "id": "p_scratch", "kit": "story/ritual", "params": { "kind": "scratch" }, "at": "scratch_rock", "ry": -0.6 },
		{ "id": "d_drag", "trail": { "kind": "drag", "points": ["stone_socket", [-2397.5, 1389.5], "lying_stone"], "step": 1.1, "size": 0.9 }, "when": stone_moved },
		{ "id": "d_prints_b", "trail": { "kind": "foot", "points": [[-2409.0, 1390.0], [-2399.0, 1382.5], [-2392.0, 1381.2], [-2384.0, 1378.6], [-2377.0, 1380.4], [-2366.0, 1388.0]], "step": 0.8, "size": 0.5 },
			"when": "not ph('done')" },
		# 국사성황사 — 빈 제물상, 짚신 자국
		{ "id": "p_altar", "kit": "story/ritual", "params": { "kind": "jemul", "state": "EMPTY" }, "at": "altar_spot", "ry": 0.0, "when": "not ph('morning') and not ph('done')" },
		{ "id": "p_altar_full", "kit": "story/ritual", "params": { "kind": "jemul", "state": "NORMAL" }, "at": "altar_spot", "ry": 0.0, "when": "ph('morning') or ph('done')" },
		{ "id": "d_prints_altar", "trail": { "kind": "foot", "points": [[-2483.5, 1446.4], [-2478.5, 1444.0], [-2476.0, 1436.0], [-2474.5, 1426.0], [-2471.0, 1419.5]], "step": 0.8, "size": 0.5 },
			"when": "not ph('done')" },
		# 반정 — 도둑이 숨긴 꾸러미, 처마 밑 짚신
		{ "id": "p_stash", "kit": "story/ritual", "params": { "kind": "stash" }, "at": "stash_spot", "ry": 0.3, "when": "not f('thief_caught')" },
		{ "id": "d_prints_stash", "trail": { "kind": "foot", "points": [[-2111.5, 1323.0], [-2113.0, 1313.0], [-2113.8, 1306.0]], "step": 0.8, "size": 0.5 }, "when": "not f('thief_caught')" },
		{ "id": "p_sandals", "kit": "story/ritual", "params": { "kind": "sandals" }, "at": "sandals_spot", "ry": 0.2, "when": "not f('thief_caught')" },
		# 모시기(아침): 제관이 든 방울(성황사 앞 말뚝)
		{ "id": "p_bell_rite", "kit": "story/ritual", "params": { "kind": "bell", "hung": true }, "at": [-2485.0, 1449.0], "when": "ph('morning') and not out('A')" },
	]

# ---------------------------------------------------------------------------
# 잔영(SPIRIT_BASE, CHR_CRE_004 계열 '일반 잔영') — 밤 + 호신부(감지)일 때만 보인다(§11 S2005)
# ---------------------------------------------------------------------------
static func spirits() -> Array:
	var night_case := "ph('night') and not f('resolved')"
	return [
		# 경계석 곁에 선 형체 — 밖에선 희미, 안에선 또렷(S2006). 해결 뒤 B·C면 밤마다 희미하게 남는다
		{ "id": "jy_stone", "kind": "spirit_m", "name": "잔영", "at": "stone_spirit", "facing": "down",
			"when": "(%s) or (ph('done') and not out('A'))" % night_case, "night": true, "sense": true,
			"zone": "boundary", "alpha_in": 0.88, "alpha_out": 0.3, "motion": "float", "watch": 7.0, "range": 48.0, "lift": 0.15 },
		# 고갯길을 앞서 가는 형체 — 간헐적으로 보이며 경계석 쪽으로(S2005)
		{ "id": "jy_lead", "kind": "spirit_m", "name": "잔영", "at": [-2300.0, 1423.0], "when": night_case, "night": true, "sense": true,
			"motion": "drift", "speed": 0.7, "loop": "restart", "flicker": [2.5, 5.0, 1.5, 3.5], "alpha_in": 0.55, "range": 42.0,
			"path": [[-2300.0, 1423.0], [-2318.0, 1422.0], [-2333.0, 1415.0], [-2348.0, 1405.0], [-2358.0, 1395.0], [-2372.0, 1386.0], [-2384.0, 1380.0]] },
		# 숲으로 꾀는 형체 — 따라가면 길을 잃는다("보인다고 다 따라가진 말고")
		{ "id": "jy_lure", "kind": "spirit_m", "name": "잔영", "at": [-2236.0, 1430.0], "when": night_case, "night": true, "sense": true,
			"motion": "drift", "speed": 0.5, "loop": "restart", "flicker": [3.0, 6.0, 2.0, 4.0], "alpha_in": 0.5, "range": 36.0,
			"path": [[-2236.0, 1430.0], [-2234.0, 1442.0], [-2230.0, 1456.0], [-2226.0, 1470.0]] },
	]

static func sounds() -> Array:
	return [
		# 방울 없는 방울 소리 — 경계석 쪽에서(S2005). 방울을 제자리에 가져가면 멎는다(S2006)
		{ "id": "bell_night", "from": "stone_socket", "when": "ph('night') and not f('bell_home') and not f('resolved')", "night": true,
			"every": [6.0, 10.0], "range": 520.0, "caption": "딸랑— 방울 소리.", "near": "딸랑, 딸랑. 바로 곁에서 방울이 운다.", "near_r": 10.0,
			"dir": true, "fx": "ring", "audio": "bell_far" },
		# C 뒤: 밤마다 고개 쪽에서 방울 소리가 남는다(§11 S2007 C)
		{ "id": "bell_after", "from": "stone_socket", "when": "ph('done') and out('C')", "night": true,
			"every": [150.0, 240.0], "range": 100000.0, "caption": "…밤바람에 실려 고개 쪽에서 방울 소리가 들린다.", "dir": false, "fx": "ring", "audio": "bell_far" },
	]

static func zones() -> Dictionary:
	var night_case := "ph('night') and not f('resolved')"
	return {
		# 옛 경계석의 안(또렷)·밖(희미)
		"boundary": { "at": "stone_socket", "radius": 8.5, "when": night_case, "enter": [{ "call": "enter_boundary" }] },
		# 착란이 차는 넓은 둘레(호신부가 누그러뜨린다)
		"boundary_wide": { "at": "stone_socket", "radius": 30.0 },
		# 숲으로 꾀는 형체를 따라가면 길을 잃는다
		"lost": { "at": "lure_end", "radius": 7.0, "when": night_case, "enter": [{ "call": "lost_way" }] },
	}

# ---------------------------------------------------------------------------
# 사건 장면(§44 필드 + steps) — 소스 A09(지역 고정 전승). SOURCE_VERIFIED=false면 실행하지 않는다.
# ---------------------------------------------------------------------------
static func _ev(id: String, trigger: String, loc: String, tw: String, actions: String, branches: String, wsc: String, steps: Array) -> Dictionary:
	return {
		"EVENT_ID": id, "RECORD_TITLE": "고개에 남은 종소리", "SOURCE_ID": "A09",
		"SOURCE_TITLE_INTERNAL": "대관령 국사성황·산신 전승", "SOURCE_TYPE": "legend", "SOURCE_REGION_GRADE": "A",
		"SOURCE_REGION_NOTE": "강릉·대관령 지역신앙(단오·국사성황 모시기). 금줄·방울·제물·경계석은 제의 공간의 물건으로만 쓰고 새 금기·새 괴이 능력을 만들지 않는다(§36.2). 잔영의 정체는 확정하지 않는다(§1.4).",
		"ADAPTATION_MODE": "VARIANT", "TRIGGER": trigger, "LOCATION_TYPE": loc, "TIME_WEATHER": tw,
		"PLAYER_ACTIONS": actions, "RESOLUTION_BRANCHES": branches, "WORLD_STATE_CHANGE": wsc, "SOURCE_VERIFIED": true,
		"steps": steps,
	}

static func events() -> Dictionary:
	return {
		"S2001": _ev("S2001", "한양 S1006 이후 강릉 도착(단오장 또는 반정)", "강릉 남대천가 단오장 굿당", "오전 · 맑음",
			"주변대화를 엿듣고 무녀·제관에게 묻는다", "-", "사건 기록 생성", [
			{ "if": "not f('arrived')", "then": [{ "call": "arrival" }] },
			{ "say": "나그네", "lines": ["방울이 없어졌다고요?"] },
			{ "say": "무녀", "lines": ["국사성황께 올릴 방울이오. 제관 어른은 반정에 올라가 계시오."] },
			{ "call": "start_case", "args": ["mudang"] },
			{ "choice": "", "options": [
				{ "label": "대관령 반정으로 오른다", "do": [{ "call": "travel", "args": ["bj_arrive", "구산역을 지나 대관령 반정까지 올랐다."] }] },
				{ "label": "단오장을 더 둘러본다", "end": true }] },
		]),
		# S2002·S2003은 조사 대상이 모인 구간 — 단서를 얻으면 seen에 남는다(기록용)
		"S2002": _ev("S2002", "사건 기록 생성 뒤", "국사성황사 길(옛 경계석·성황사)", "낮", "옮겨진 돌·끊긴 금줄·빈 제물상·발자국·긁힘을 순서 없이 조사", "-", "-", []),
		"S2003": _ev("S2003", "발자국을 짐승 흔적 읽기로 가른다", "옛 경계석 · 반정 주막", "낮",
			"사람 발자국과 다른 흔적을 가른다 → 꾸러미·짚신 → 덕보와 마주함", "도둑을 제관에게 넘김", "방울 회수", []),
		"S2004": _ev("S2004", "흔적을 가른 뒤 국사성황사", "국사성황사", "낮", "월심에게서 호신부를 받는다", "-", "ITEM_TALISMAN_SLOT = 1", [
			{ "say": "월심", "lines": ["오늘 밤 다시 올라가시오."] },
			{ "call": "give_charm" },
			{ "say": "월심", "lines": ["보인다고 다 따라가진 말고."] },
			{ "if": "not has('%s')" % ROPE, "then": [
				{ "say": "월심", "lines": ["끊긴 줄은 다시 치면 되오."] }, { "give": ROPE }] },
		]),
		"S2005": _ev("S2005", "반정에서 밤을 기다린 뒤", "국사성황사 길(밤)", "밤", "같은 길을 다시 오른다 — 간헐적인 잔영, 방울 소리를 따라", "-", "-", []),
		"S2006": _ev("S2006", "옛 경계석 둘레(밤)", "옛 경계석", "밤", "경계 안팎을 오가며 본다 · 방울을 옛 자리에 가져간다", "-", "-", []),
		"S2007": _ev("S2007", "규칙을 안 뒤", "옛 경계석 / 반정", "밤~새벽",
			"방울·경계석을 되돌린다 / 도둑을 넘기고 모시기에 맡긴다 / 칼을 뽑아 억지로 지나간다",
			"A 방울·경계석 복원 · B 도둑 체포 + 제의 정상 진행 · C 괴이를 베며 강제 통과(밤마다 소리가 남음)",
			"A: 경계석·새 금줄·방울 / B: 덕보 체포, 경계석은 누운 채 / C: 밤마다 방울 소리", []),
		"S2008": _ev("S2008", "결말 다음 새벽, 모시기 뒤", "국사성황사", "새벽", "옛 제의 기록 뒷장을 본다", "-", "MAIN_MASTER_TRACE += GANGNEUNG", [
			{ "say": "제관", "lines": ["모시는 순서는 이 기록대로 했소. …뒷장에 웬 글씨가."] },
			{ "examine": "옛 제의 기록 뒷장", "text": ["순서를 적은 앞장과 다른 손이다. 낯익은 필체.", "“사람이 훔친 것과 사람이 아닌 것이 남긴 흔적을 섞지 말 것.”", "아래에 더 작은 글씨. “원인이 둘이면, 해결도 하나일 필요는 없다.”"], "kind": "clue" },
			{ "call": "master_trace" },
			{ "journal": "이겸의 흔적 — 강릉" },
		]),
	}
