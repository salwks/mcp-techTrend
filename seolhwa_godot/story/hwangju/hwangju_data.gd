# 사건 「빈 배의 값」(ACT 2C 황주, S4001~S4008) — 이야기 데이터.
# 시나리오: seolhwa/docs/scenario/seolhwarok_master_scenario_storyboard_v2.3.1_consistency_lock.md §13 (규칙 §1.3·§1.4·§1.5·§1.6,
#   변수 §7, 소문 §24, 대사 §27, 컷신 §28, 실패 §29, 지역 변화 §30, 소스 잠금 §36, 전승 앵커 §37 A11 — 등급 B, 소문으로만·확정 않음)
# 체감 장르(§1.7): 구조·선택. 전투 없음. 실패(구조 실패·중개인 도주)는 게임오버가 아니라 기록·소문·지역 변화로 남는다(§29).
# 원작 제목·인물 이름은 쓰지 않는다(§1.3) — 노인·딸·중개인은 이 사건의 사람들이다. '인당수'라는 이름도 쓰지 않는다.
# 핵심 학습(§13 S4008): 믿음이나 소문보다 지금 관찰할 수 있는 물리 현상(물살 — 던진 표식이 돌아오는 방향)을 먼저 본다.
#
# 두 공간에 걸친 사건(story_director CASES — 같은 사건 id, 항목 "space"로 가름):
#   HH_HWANGJU(권역): 도화동 — 눈먼 노인(S4001)·중개인(S4002). 사건 뒤 노인 집에 결말이 남는다.
#   HH_HWANGJU-JANGSANGOT(노정, 장산곶 바닷가 띠): 장산곶 어촌·선창·만 안쪽 모래톱·곶 앞 벼랑(제물 바위)·바위섬(S4003~S4008).
#     바위섬·암초·선창·뱃길은 world-scenario 담당(rt_sc_jangsan_islet, rt_jangsan_islet_lane).
# 시간·날씨(S4006): 장산곶에 닿으면 시계가 돈다(조사 중 2분 30초에 한 시간). 15시 바람(weather.force wind), 18시 큰 바람(storm) —
#   큰 바람 동안 뱃길이 닫히고, 바람이 지난 아침엔 늦다(C).
# 조건식: story_runner(f·k·c·has·n·ph·v·out·w·fn).
extends RefCounted

const RJ := "HH_HWANGJU"
const RT := "HH_HWANGJU-JANGSANGOT"
const ROPE := "ITM_TOOL_003"         # 밧줄(ITEM_MASTER 조사 도구 — 구조·등반·결박)
const FLOATS := "ITM_HJ_FLOAT"       # 그물 찌(사건용 생활품 — 표식으로 던진다, PRP_WAT_004 그물에서)
const COIN := "COIN"
const RESOLVED := "out('A') or out('B') or out('C')"
const STORY_HOURS := { "wind": 15.0, "storm": 18.0 }

static func data() -> Dictionary:
	return {
		"case": {
			"id": "hwangju", "record_title": "빈 배의 값", "region": RJ, "outcome_var": "CASE_HWANGJU_OUTCOME",
			"start_hour": 9.0, "start_event": { RJ: "S4001", RT: "" }, "start_on_arrival": true,
			# 한양 S1006(세 갈래 열림) 뒤에만 선다 — 강릉·경주와 순서 상관없음
			"requires": { "ACT2_OPEN": true },
			"rule_label": "물살의 규칙", "rules_title": "물살의 규칙",
			"reset_vars": ["CASE_HWANGJU_OUTCOME", "CASE_HWANGJU_DETAIL", "CASE_HWANGJU_COMPLETE", "MAIN_GWAK_NAME_KNOWN"],
		},
		"items": {
			ROPE: "밧줄", FLOATS: "그물 찌", COIN: "엽전",
			"ITM_TOOL_009": "사건 기록책", "ITM_WPN_001": "환도", "ITM_WPN_002": "활", "ITM_AMMO_001": "화살",
			"ITM_KEY_002": "낡은 운송장(뒷면에 이겸의 메모)",
		},
		"hidden_items": ["ITM_TOOL_009", "ITM_WPN_001", "ITM_WPN_002", "ITM_AMMO_001"],
		"clues": {
			"daughter_left": { "kind": "heard", "by": "눈먼 노인", "title": "배를 탄 딸", "text": "도화동 눈먼 노인의 딸 연이가 돈 꾸러미를 두고 배를 탔다. 사흘째 소식이 없다." },
			"coins": { "kind": "fact", "title": "엽전 서른 냥", "text": "노인 집에 남은 엽전 꿰미. 셈 쪽지: '탁 중개 — 뱃삯 서른 냥'." },
			"sacrifice_talk": { "kind": "heard", "by": "도화동 아낙", "title": "동네의 말", "text": "이웃들은 연이가 제물로 팔려 갔다고 수군댄다." },
			"broker_words": { "kind": "heard", "by": "탁 중개인", "title": "중개인의 말", "text": "“위험한 바다에는 값을 치러야 하오.” 셈만 맞췄다고 한다. 장산곶에 볼일이 남았단다." },
			"wreck": { "kind": "fact", "title": "부서진 장삿배", "text": "만 안쪽 모래톱에 밀려온 잔해. 뱃머리 판자의 이름이 동네에서 말하던 그 장삿배다 — 값을 치르고도 부서졌다." },
			"receipt": { "kind": "fact", "title": "선주의 셈 쪽지", "text": "부서진 궤짝 속. '탁 중개에게 — 삼백 냥. 바닷길 값.' 노인 집엔 서른 냥이 남았다." },
			"foam_lines": { "kind": "fact", "title": "거품 줄", "text": "곶 앞 벼랑에서 보면 거품 줄 하나는 암초 사이로 바위섬 뒤로, 하나는 만 안쪽으로 휜다." },
			"rite_worn": { "kind": "fact", "title": "닳은 새김", "text": "벼랑 끝 옛 제의 바위. 앞면에 무언가 새겨졌지만 닳아서 읽을 수 없다." },
			"rite_rubbing": { "kind": "fact", "title": "옛 제의 탁본", "text": "탁본에 드러난 그림 — 짚으로 엮은 사람 꼴을 작은 배에 태워 띄우고, 시루와 쌀을 올렸다. 사람은 없다." },
			"drift_watch": { "kind": "fact", "title": "던진 찌", "text": "제물 바위 앞 물에 찌 셋을 던졌다. 둘은 만 안쪽으로, 하나는 암초 사이로 바위섬 뒤로 흘러갔다." },
			"floats_back": { "kind": "fact", "title": "돌아온 찌", "text": "만 안쪽 모래톱 — 부서진 배 조각이 올라온 그 갯가에 던진 찌 둘이 밀려와 있다. 바다는 받은 것을 돌려보낸다." },
			"cape_lost": { "kind": "fact", "title": "곶 끝의 찌", "text": "곶 끝에서 던진 찌는 먼바다로 나갔다. 물살은 자리마다 다르다." },
			"islet_cove": { "kind": "fact", "title": "바위섬 갯구멍", "text": "바위섬 뒤 자갈 갯가. 흘러든 찌가 바위틈 앞에 걸려 있다. 틈 안에 불 피운 자국." },
			"rescued": { "kind": "heard", "by": "연이", "title": "연이", "text": "바위섬 틈에서 연이를 찾았다. 배에서 떠밀려 물에 들었다가, 물살에 실려 섬 뒤 갯가에 닿았다고 한다." },
			"ribbon": { "kind": "fact", "title": "바위틈의 댕기", "text": "큰 바람이 지난 뒤 바위섬 갯구멍은 비어 있었다. 바위틈에 붉은 댕기 하나." },
			"waybill": { "kind": "fact", "title": "낡은 운송장", "text": "중개인 궤짝 밑바닥. 짐꾼 '곽칠성'. 도착지는 물에 번져 읽을 수 없다. 모서리에 붉은 朴 표식. 뒷면에 낯익은 필체." },
		},
		# 꼬리표(docs/reports/onboarding.md P1-7): 단서 kind fact(◆확인)·heard(◇들음 — by), 규칙 기본 guess(△추정). 중개인의 말은 들음이다
		"rules": {
			"R_CURRENT_ISLET": { "kind": "fact", "title": "제물 바위 앞 물은 바위섬 뒤로 돈다", "text": "벼랑 아래 던진 것 일부는 암초 사이를 지나 바위섬 뒤 갯구멍으로 흘러든다." },
			"R_SEA_RETURNS": { "kind": "fact", "title": "바다는 받은 것을 돌려보낸다", "text": "던진 찌는 사라지지 않았다. 물살이 정한 갯가 — 만 안쪽 모래톱으로 돌아왔다." },
			"R_NO_PRICE": { "kind": "guess", "title": "값을 치른 배도 부서졌다", "text": "사람을 바쳤다는 배는 그러고도 부서졌다. 사람 제물이 바람을 멎게 했다는 흔적은 없다." },
			"R_PLACE_DIFFERS": { "kind": "fact", "title": "물살은 자리마다 다르다", "text": "곶 끝에서 던진 것은 먼바다로 나갔다." },
		},
		"anchors": anchors(),
		# 지도에 적힐 곳: 노인·중개인이 장산곶을 일러 준다(들음). 바위섬 갯구멍은 물살을 보고 가 봐야 적힌다
		"map_places": [
			{ "id": "old_house", "space": RJ, "name": "눈먼 노인의 집", "at": "old_yard", "radius": 14.0, "known": "f('case_started')" },
			{ "id": "jangsan_pier", "space": RT, "name": "장산곶 선창", "at": "pier_land", "radius": 16.0, "known": "f('to_jangsan')" },
			{ "id": "rite_rock", "space": RT, "name": "제물 바위", "at": "rite_rock", "radius": 12.0 },
			{ "id": "bay_beach", "space": RT, "name": "만 안쪽 모래톱", "at": "bay_beach", "radius": 14.0 },
			{ "id": "islet_cove", "space": RT, "name": "바위섬 갯구멍", "at": "islet_cove", "radius": 10.0, "known": "k('R_CURRENT_ISLET')" },
		],
		# 지도 붉은 표(갈 곳, 보강서 §20) — 노인·중개인·어부가 일러 준 곳, 도착 장면이 보여 준 곳만.
		#   바위섬 갯구멍은 찌가 그리 흘러드는 것을 본 뒤에만(R_CURRENT_ISLET). 궤짝·셈 쪽지 자리는 넣지 않는다(fn 금지)
		"map_leads": [
			{ "id": "hj_old_house", "space": RJ, "name": "눈먼 노인의 집", "at": "old_yard", "hub": true, "when": "true", "until": "ph('done')",
				"note": "S4001 도화동 노인 집 — 사건의 들머리" },
			{ "id": "hj_jangsan", "space": RT, "name": "장산곶", "at": "j_arrive", "when": "c('broker_words')", "until": "f('jangsan_arrived')",
				"note": "S4002 중개인 “장산곶에 볼일이 남아서” · 노인 “장산곶까지 가 주시는 거요?” — S4003 닿으면 사라진다" },
			{ "id": "hj_wreck", "space": RT, "name": "만 안쪽 모래톱(부서진 배)", "at": "wreck", "when": "f('jangsan_arrived')", "until": "c('wreck')",
				"note": "S4003 도착 장면 “만 안쪽 모래톱에 부서진 배 조각이 밀려와 있다.” · 어부 “저 모래톱에 조각나 올라왔소”" },
			{ "id": "hj_cliff", "space": RT, "name": "곶 앞 벼랑", "at": "rite_rock", "when": "f('jangsan_arrived')", "until": "c('foam_lines') or c('rite_worn') or f('thrown')",
				"note": "S4003 도착 장면 “곶 끝 벼랑에 바람이 부딪친다.” · 어부 “제물 바치고도…”" },
			{ "id": "hj_broker_house", "space": RT, "name": "탁 서방 묵는 집", "at": "broker_spot", "when": "f('fisher_met')",
				"until": "talked('broker_jt') > 0 or f('broker_gone') or f('broker_caught')",
				"note": "어부 “탁 서방은 선창 위 집에 묵소.”(fisher_talk)" },
			{ "id": "hj_islet", "space": RT, "name": "바위섬 뒤 갯구멍", "at": "islet_cove", "when": "k('R_CURRENT_ISLET')",
				"until": "f('islet_seen') or f('rescued') or f('rescue_failed')",
				"note": "S4004 찌 하나가 바위섬 뒤로 — 기록 “물에 든 것은 바위섬 뒤 갯구멍으로 흘러든다” · 뱃사공(boat_ok)이 배를 대 준다" },
		],
		"journal": {
			"unknowns": [
				{ "text": "연이는 어디에 있는가.", "until": "f('rescued') or f('rescue_failed')" },
				{ "text": "바다가 값을 받는다는 말은 맞는가.", "when": "c('broker_words')", "until": "k('R_NO_PRICE')" },
				{ "text": "중개인이 받은 돈과 노인 집에 남은 돈은 같은가.", "when": "c('coins')", "until": "c('receipt')" },
				{ "text": "물에 든 것은 어디로 가는가.", "when": "c('foam_lines')", "until": "k('R_CURRENT_ISLET')" },
			],
			"places": [
				{ "name": "도화동 노인 집", "when": "true" }, { "name": "장산곶", "when": "f('jangsan_arrived')" },
				{ "name": "만 안쪽 모래톱", "when": "c('wreck')" }, { "name": "제물 바위", "when": "c('foam_lines') or c('rite_worn') or c('rite_rubbing')" },
				{ "name": "바위섬 갯구멍", "when": "c('islet_cove')" },
			],
		},
		"actors": actors(),
		"objects": objects(),
		"triggers": triggers(),
		"props": props(),
		"events": events(),
		"currents": currents(),
		# 탁본(경주 사건의 scripts/story/rubbing.gd — SKILL_RUBBING일 때 그 모듈이 "탁본을 뜬다"로 세운다). 뜬 것은 progress.rubbings에 남고
		#   사건은 그것만 본다(hwangju_case.ambient → rubbed). 모듈이 없으면 사건의 조사 대상(rite)이 같은 카드를 보여 준다.
		"rubbings": [{ "id": "hj_rite", "space": RT, "at": "rite_rock", "radius": 2.6, "label": "옛 제의 바위", "title": "탁본 — 옛 제의 바위",
			"text": RITE_RUBBING, "when": "f('jangsan_arrived') and not c('rite_rubbing')" }],
	}

const RITE_RUBBING := ["짚으로 엮은 사람 꼴을 작은 배에 태워 띄운 그림.", "곁에 시루와 쌀 — 사람은 없다.", "옛날 이 바위에서 바다에 바친 것은 짚 인형이었다."]

static func anchors() -> Dictionary:
	return {
		# ---- 황주 도화동(HH_HWANGJU) — 작은 집(hj_dohwa_ha_small_01, 문은 +z) ----
		"hj_arrive": [-371.5, -367.5], "old_yard": [-386.4, -379.4], "old_gate": [-387.8, -376.9], "old_out": [-388.1, -374.4],
		"coins_spot": [-385.0, -380.4], "daughter_home": [-385.1, -379.0], "bowl_spot": [-386.6, -376.2],
		"na_spot": [-360.2, -372.4], "nb_spot": [-358.6, -374.0], "broker_hj": [-373.8, -370.6], "dohwa_lane": [-366.0, -366.0],
		# ---- 장산곶 노정(HH_HWANGJU-JANGSANGOT) ----
		"route_start": [-532.0, -11.4], "j_arrive": [338.0, -7.0], "j_village": [345.0, -9.0],
		"fa_spot": [327.0, -3.0], "fb_spot": [333.5, 0.5], "net_rack": [329.5, 2.5], "hut": [323.0, 4.0],
		"broker_spot": [363.0, -3.5], "broker_bundle": [361.4, -2.2], "broker_bound": [347.5, -4.0],
		"boat_spot": [345.0, -64.0], "pier_land": [347.0, -68.5], "lane_start": [360.0, -74.0],
		"wreck": [396.0, -48.5], "wreck_chest": [398.4, -48.0], "bay_beach": [391.0, -52.5], "floats_rest": [389.0, -51.0],
		"rite_rock": [451.0, -96.0], "throw_stand": [454.5, -99.5], "throw_pt": [447.0, -108.0], "sea_look": [456.0, -100.5],
		"cape_stand": [533.0, -57.0], "cape_pt": [547.5, -63.5],
		"islet_landing": [499.0, -195.0], "islet_boat": [500.6, -194.2], "islet_cove": [499.0, -199.0], "islet_shelter": [498.4, -205.6], "islet_floats": [500.2, -199.8],
		"pier_rest": [344.0, -66.5], "rest_spot": [325.0, 3.5], "straw_spot": [452.5, -98.5],
	}

# ---------------------------------------------------------------------------
# 인물(CHARACTER_MASTER v1.3): 눈먼 노인(노인-남 CHR_HUM_022 변형), 연이(아낙 CHR_HUM_010 → 젊은 처녀 변형), 탁 중개인(상인 CHR_HUM_002 변형),
#   어부(CHR_HUM_018) 둘, 뱃사공(CHR_HUM_007), 도화동 아낙 둘(CHR_HUM_010)
# ---------------------------------------------------------------------------
static func actors() -> Array:
	return [
		# ---- 황주 ----
		{ "id": "old_man", "space": RJ, "chr": "CHR_HUM_022", "kind": "blind_elder", "name": "눈먼 노인", "at": "old_yard", "facing": "down",
			"anim": { "done": "sit", "default": "sit" }, "radius": 2.6,
			"talk": [
				{ "when": "ph('done')", "steps": [{ "call": "old_man_done" }] },
				{ "when": "not f('case_started')", "steps": [{ "event": "S4001" }] },
				{ "when": "true", "steps": [{ "call": "old_man_talk" }] },
			] },
		{ "id": "daughter_hj", "space": RJ, "chr": "CHR_HUM_010", "kind": "daughter", "name": "연이", "at": "daughter_home", "facing": "left",
			"anim": "sit", "when": "ph('done') and not out('C')",
			"talk": [{ "when": "true", "steps": [{ "call": "daughter_home_talk" }] }] },
		{ "id": "neigh_a", "space": RJ, "chr": "CHR_HUM_010", "kind": "farmwife", "name": "아낙", "at": "na_spot", "facing": "left",
			"talk": [
				{ "when": "out('C')", "steps": [{ "say": "아낙", "lines": ["노인이 날마다 대문 밖에 물 한 그릇 떠 놓고 앉아 있어요."] }] },
				{ "when": RESOLVED, "steps": [{ "say": "아낙", "lines": ["연이가 살아 왔다니, 이게 무슨 복이래."] }] },
				{ "when": "true", "steps": [{ "say": "아낙", "lines": ["뱃사람들이 처녀를 사 간다는 말이 돌았어요. 그런 걸 누가 믿나 했는데…"] }, { "clue": "sacrifice_talk" }] },
			] },
		{ "id": "neigh_b", "space": RJ, "chr": "CHR_HUM_023", "kind": "villager_f", "name": "아낙", "at": "nb_spot", "facing": "up",
			"talk": [
				{ "when": RESOLVED, "steps": [{ "say": "아낙", "lines": ["탁 서방 얼굴 본 지가 오래네요."] }] },
				{ "when": "true", "steps": [{ "say": "아낙", "lines": ["바다가 값을 받는다나. 그 돈 꾸러미가 그 값이래요."] }, { "clue": "sacrifice_talk" }] },
			] },
		# 탁 중개인 — 황주에선 S4002, 장산곶에선 선창 위 어부 집에 머문다
		{ "id": "broker", "space": RJ, "chr": "CHR_HUM_002", "kind": "broker", "name": "중개인", "at": "broker_hj", "facing": "left",
			"when": "f('case_started') and not f('to_jangsan')",
			"talk": [
				{ "when": "not seen('S4002')", "steps": [{ "event": "S4002" }] },
				{ "when": "true", "steps": [{ "say": "탁 중개인", "lines": ["셈은 다 치렀다 하지 않았소."] }, { "call": "offer_travel" }] },
			] },
		# ---- 장산곶 ----
		{ "id": "broker_jt", "space": RT, "chr": "CHR_HUM_002", "kind": "broker", "name": "탁 중개인", "at": "broker_spot", "facing": "down",
			"when": "f('jangsan_arrived') and not f('broker_gone') and not f('broker_caught')",
			"talk": [
				{ "when": "f('rescued')", "steps": [{ "call": "pier_choice" }] },
				{ "when": "true", "steps": [{ "call": "broker_jt_talk" }] },
			] },
		{ "id": "broker_tied", "space": RT, "chr": "CHR_HUM_002", "kind": "broker", "name": "탁 중개인", "at": "broker_bound", "facing": "down",
			"anim": "tied", "when": "f('broker_caught') and not ph('done')",
			"talk": [{ "when": "true", "steps": [{ "say": "탁 중개인", "lines": ["…바다 일은 바다에 물어보시오."] }] }] },
		{ "id": "fisher_a", "space": RT, "chr": "CHR_HUM_018", "kind": "fisher", "name": "어부", "at": "fa_spot", "facing": "right",
			"when": "f('jangsan_arrived')",
			"talk": [
				{ "when": "ph('done')", "steps": [{ "call": "fisher_done" }] },
				{ "when": "f('storm') and not f('storm_passed')", "steps": [{ "call": "fisher_storm" }] },
				{ "when": "true", "steps": [{ "call": "fisher_talk" }] },
			] },
		{ "id": "fisher_b", "space": RT, "chr": "CHR_HUM_018", "kind": "fisher", "name": "어부", "at": "fb_spot", "facing": "left",
			"when": "f('jangsan_arrived')",
			"talk": [
				{ "when": "out('A') and f('rubbed')", "steps": [{ "say": "어부", "lines": ["짚배를 엮어 띄우는 건 우리 할아비 적 일이오. 다시 해 보려고."] }] },
				{ "when": RESOLVED, "steps": [{ "say": "어부", "lines": ["그 장삿배 선원들은 다신 이 물에 안 온다오."] }] },
				{ "when": "true", "steps": [{ "say": "어부", "lines": ["그 장삿배, 사흘 바람을 맞고 저 모래톱에 조각나 올라왔소. 사람은 겨우 건졌지."] }] },
			] },
		{ "id": "boatman", "space": RT, "chr": "CHR_HUM_007", "kind": "boatman", "name": "뱃사공", "at": "boat_spot", "facing": "right",
			"when": "f('jangsan_arrived')",
			"talk": [
				{ "when": "ph('done')", "steps": [{ "say": "뱃사공", "lines": ["섬 뒤 물길은 이제 내가 아오. 언제든 태워 주리다."] }] },
				{ "when": "true", "steps": [{ "call": "boatman_talk" }] },
			] },
		# 바위섬 갯가에서 기다리는 뱃사공(배를 대 준 뒤)
		{ "id": "boatman_islet", "space": RT, "chr": "CHR_HUM_007", "kind": "boatman", "name": "뱃사공", "at": "islet_boat", "facing": "up",
			"when": "f('on_islet') and not ph('done')",
			"talk": [{ "when": "true", "steps": [{ "say": "뱃사공", "lines": ["물 바뀌기 전에 돌아가야 하오."] },
				{ "choice": "", "options": [{ "label": "선창으로 돌아간다", "do": [{ "call": "sail", "args": ["back"] }] }, { "label": "조금만 기다리시오.", "end": true }] }] }] },
		# 연이 — 바위섬 틈(S4006). 구하면 선창 → 어부 집 앞
		{ "id": "daughter", "space": RT, "chr": "CHR_HUM_010", "kind": "daughter", "name": "연이",
			"at": { "after": "rest_spot", "default": "islet_shelter" }, "facing": "down", "anim": { "after": "sit", "default": "cower" }, "radius": 3.0,
			"when": "(f('islet_seen') or f('rescued')) and not f('rescue_failed') and not ph('done')",
			"talk": [
				{ "when": "f('rescued')", "steps": [{ "say": "연이", "lines": ["…아버지 진지는 누가 차려 드리고 있을까."] }] },
				{ "when": "true", "steps": [{ "call": "rescue" }] },
			] },
		{ "id": "daughter_rest", "space": RT, "chr": "CHR_HUM_010", "kind": "daughter", "name": "연이", "at": "rest_spot", "facing": "down",
			"anim": "sit", "when": "ph('done') and not out('C')",
			"talk": [{ "when": "true", "steps": [{ "say": "연이", "lines": ["몸이 녹는 대로 아버지께 가겠어요."] }] }] },
	]

# ---------------------------------------------------------------------------
# 조사 대상
# ---------------------------------------------------------------------------
static func objects() -> Array:
	var sea := "f('jangsan_arrived') and not ph('done')"
	return [
		# ---- 황주 ----
		{ "id": "coins", "space": RJ, "at": "coins_spot", "label": "엽전 꾸러미 · 조사", "radius": 1.8, "when": "f('case_started') and not c('coins')",
			"steps": [{ "examine": "엽전 꾸러미", "text": ["엽전 꿰미 셋 — 서른 냥. 노인은 손도 대지 않았다.", "꿰미 끈에 셈 쪽지가 매여 있다. '탁 중개 — 뱃삯 서른 냥.'"] },
				{ "clue": "coins" }] },
		# ---- 장산곶 ----
		{ "id": "wreck", "space": RT, "at": "wreck", "label": "부서진 배 · 조사", "radius": 3.2, "when": sea + " and not c('wreck')",
			"steps": [{ "examine": "부서진 장삿배", "text": ["모래톱에 밀려 올라온 뱃전 판자와 부러진 돛대.", "뱃머리 판자에 배 이름이 남았다 — 동네에서 말하던 그 장삿배다.", "값을 치르고 떠났다던 배가, 바다 위에서 부서졌다."] },
				{ "clue": "wreck" }, { "call": "check_no_price" }] },
		{ "id": "chest", "space": RT, "at": "wreck_chest", "label": "엎어진 궤짝 · 살펴보기", "radius": 1.8, "when": sea + " and c('wreck') and not c('receipt')",
			"steps": [{ "examine": "선주의 셈 쪽지", "text": ["젖은 궤짝 밑에 기름종이로 싼 쪽지 한 장.", "'탁 중개에게 — 삼백 냥. 바닷길 값.'", "노인 집에 남은 건 서른 냥이었다."], "kind": "item" },
				{ "clue": "receipt" }] },
		{ "id": "sea_look", "space": RT, "at": "sea_look", "label": "벼랑 아래 바다 · 살펴보기", "radius": 2.6, "when": sea + " and not c('foam_lines')",
			"steps": [{ "call": "look_sea" }] },
		{ "id": "rite", "space": RT, "at": "rite_rock", "label": "옛 제의 바위 · 조사", "radius": 2.4, "label_if": ["v('SKILL_RUBBING') == true", "옛 제의 바위 · 탁본"],
			"when": sea + " and not c('rite_rubbing') and not (c('rite_worn') and not v('SKILL_RUBBING')) and not (v('SKILL_RUBBING') and fn('rub_module'))",
			"steps": [{ "call": "examine_rite" }] },
		{ "id": "net", "space": RT, "at": "net_rack", "label": "그물 걸대 · 살펴보기", "radius": 2.4, "when": sea + " and not f('got_floats')",
			"steps": [{ "examine": "그물 걸대", "text": "말리는 그물에 나무 찌가 줄줄이 달렸다. 붉은 천을 맨 것도 있다." },
				{ "if": "f('jangsan_arrived')", "then": [{ "call": "take_floats" }] }] },
		{ "id": "throw", "space": RT, "at": "throw_stand", "label": "찌를 던져 물살을 본다", "radius": 2.6,
			"when": sea + " and has('%s') and not f('thrown')" % FLOATS, "steps": [{ "event": "S4004" }] },
		{ "id": "cape_throw", "space": RT, "at": "cape_stand", "label": "곶 끝에서도 찌를 던져 본다", "radius": 3.0,
			"when": sea + " and f('thrown') and has('%s') and not f('cape_thrown')" % FLOATS, "steps": [{ "call": "cape_throw" }] },
		{ "id": "floats_beach", "space": RT, "at": "floats_rest", "label": "밀려온 찌 · 줍기", "radius": 2.6,
			"when": sea + " and f('drift_bay_beach') and not c('floats_back')", "steps": [{ "call": "pick_floats" }] },
		{ "id": "islet_floats", "space": RT, "at": "islet_floats", "label": "바위틈 앞 · 살펴보기", "radius": 2.4,
			"when": sea + " and not c('islet_cove') and not f('rescue_failed')", "steps": [{ "call": "look_cove" }] },
		{ "id": "islet_empty", "space": RT, "at": "islet_shelter", "label": "바위틈 · 살펴보기", "radius": 2.8,
			"when": "f('storm_passed') and not f('rescued') and not " + "(" + RESOLVED + ")", "steps": [{ "call": "empty_cove" }] },
		{ "id": "hut", "space": RT, "at": "hut", "label": "어부 집 · 큰 바람을 피한다", "radius": 3.0,
			"when": "f('storm') and not f('storm_passed') and not (" + RESOLVED + ")", "steps": [{ "call": "wait_storm" }] },
		{ "id": "bundle", "space": RT, "at": "broker_bundle", "label": "중개인의 궤짝 · 살펴보기", "radius": 2.2,
			"when": "(f('broker_gone') or f('broker_caught')) and not c('waybill') and (" + RESOLVED + ")", "steps": [{ "event": "S4008" }] },
	]

static func triggers() -> Array:
	return [
		# S4001 도화동 — 지나가며 엿듣는 말
		{ "id": "s4001_overhear", "space": RJ, "at": "old_gate", "radius": 20.0, "when": "not f('case_started')", "ambient": [
			["아낙", "연이가 큰돈 받고 배를 탔다지?"], ["아낙", "제물로 팔려 갔다는 소리도 있어."]] },
		# 장산곶 노정에 들어서면(사건 중) — 곧장 갈지 묻는다
		{ "id": "route_skip", "space": RT, "at": "route_start", "radius": 90.0, "when": "f('to_jangsan') and not f('jangsan_arrived')",
			"steps": [{ "call": "route_skip" }] },
		# S4003 장산곶 어촌에 닿음
		{ "id": "s4003", "space": RT, "at": "j_arrive", "radius": 34.0, "when": "f('to_jangsan') and not f('jangsan_arrived')", "event": "S4003" },
		# 바위섬에 닿음
		{ "id": "islet_land", "space": RT, "at": "islet_landing", "radius": 6.0, "when": "f('jangsan_arrived') and not f('islet_seen') and not f('rescued') and not f('storm_passed')", "once": true,
			"steps": [{ "call": "islet_arrive" }] },
	]

# ---------------------------------------------------------------------------
# 소품(kit/story/sea.gd, kit/story/park_mark.gd, 세계 데칼)
# ---------------------------------------------------------------------------
static func props() -> Array:
	return [
		# 황주
		{ "id": "p_coins", "space": RJ, "kit": "story/sea", "params": { "kind": "coins" }, "at": "coins_spot", "ry": 0.3, "when": "not ph('done')" },
		{ "id": "p_bowl", "space": RJ, "kit": "story/sea", "params": { "kind": "bowl" }, "at": "bowl_spot", "ry": 0.2, "when": "out('C')" },
		# 장산곶
		{ "id": "p_wreck", "space": RT, "kit": "story/sea", "params": { "kind": "wreck", "seed": 4003 }, "at": "wreck", "ry": 0.35 },
		{ "id": "p_rite", "space": RT, "kit": "story/sea", "params": { "kind": "rite_stone", "seed": 4005 }, "at": "rite_rock", "ry": 2.7 },
		{ "id": "p_ropes", "space": RT, "kit": "story/sea", "params": { "kind": "ropes" }, "at": "net_rack", "ry": 0.0 },
		{ "id": "p_bundle", "space": RT, "kit": "story/sea", "params": { "kind": "bundle" }, "at": "broker_bundle", "ry": 0.4, "when": "not c('waybill')" },
		{ "id": "p_waybill", "space": RT, "kit": "story/park_mark", "params": { "kind": "waybill", "size": 0.34 }, "at": "broker_bundle", "dy": 0.5, "ry": 0.4,
			"when": "f('waybill_open') and not ph('done')" },
		{ "id": "p_floats_beach", "space": RT, "kit": "story/sea", "params": { "kind": "floats", "n": 2 }, "at": "floats_rest", "ry": 0.8,
			"when": "f('drift_bay_beach') and not c('floats_back')" },
		{ "id": "p_floats_islet", "space": RT, "kit": "story/sea", "params": { "kind": "floats", "n": 1, "seed": 5 }, "at": "islet_floats", "y": 0.42, "ry": 0.4,
			"when": "f('drift_islet_cove') or c('islet_cove')" },
		{ "id": "p_blanket", "space": RT, "kit": "story/sea", "params": { "kind": "blanket" }, "at": "rest_spot", "ry": 0.2, "when": "f('rescued')" },
		{ "id": "p_ribbon", "space": RT, "kit": "story/sea", "params": { "kind": "ribbon" }, "at": "islet_shelter", "y": 0.66, "ry": 0.3, "when": "f('storm_passed') and not f('rescued')" },
		# 지역 변화(§30) A·B + 탁본: 어부들이 짚배를 엮어 옛 방식을 되살린다
		{ "id": "p_straw", "space": RT, "kit": "story/sea", "params": { "kind": "straw" }, "at": "straw_spot", "ry": 0.9, "when": "ph('done') and f('rubbed') and not out('C')" },
	]

# ---------------------------------------------------------------------------
# 물살(scripts/story/drift.gd) — 제물 바위 앞: 둘은 만 안쪽 모래톱, 하나는 암초 사이로 바위섬 갯구멍. 곶 끝: 먼바다.
# 물줄기 꺾은선은 tools 없이 drift.simulate()로 맞췄다(hwangju_test.gd PROBE). 모두 바다(해발 0 아래) 위를 지난다.
# ---------------------------------------------------------------------------
static func currents() -> Dictionary:
	return {
		"offering": {
			"streams": [
				{ "id": "to_islet", "points": [[449.0, -109.0], [462.0, -122.0], [474.0, -142.0], [484.0, -162.0], [493.0, -180.0], [498.0, -190.0], [499.0, -196.0]],
					"width": 5.0, "speed": 1.6, "pull": 0.5 },
				{ "id": "to_bay", "points": [[445.0, -109.0], [432.0, -111.0], [418.0, -104.0], [405.0, -92.0], [396.0, -76.0], [392.0, -62.0], [392.0, -55.0]],
					"width": 5.0, "speed": 1.5, "pull": 0.5 },
			],
			"ambient": [0.0, -0.05], "noise": 0.15, "max_time": 150.0,
			"shores": [
				{ "id": "islet_cove", "at": [499.0, -195.0], "radius": 3.5, "rest": "islet_floats", "name": "바위섬 갯구멍" },
				{ "id": "bay_beach", "at": [392.0, -54.0], "radius": 4.0, "rest": "floats_rest", "name": "만 안쪽 모래톱" },
			],
		},
		"cape": {
			"streams": [{ "id": "out", "points": [[547.0, -64.0], [555.0, -80.0], [560.0, -105.0], [558.0, -135.0], [552.0, -170.0]], "width": 6.0, "speed": 1.5, "pull": 0.3 }],
			"ambient": [0.0, -0.1], "noise": 0.15, "max_time": 55.0, "shores": [],
		},
	}

# ---------------------------------------------------------------------------
# 사건 장면(§44 필드 + steps) — 소스 A11(지역 고정 전승, 등급 B). SOURCE_VERIFIED=false면 실행하지 않는다.
# ---------------------------------------------------------------------------
static func _ev(id: String, trigger: String, loc: String, tw: String, actions: String, branches: String, wsc: String, steps: Array) -> Dictionary:
	return {
		"EVENT_ID": id, "RECORD_TITLE": "빈 배의 값", "SOURCE_ID": "A11",
		"SOURCE_TITLE_INTERNAL": "심청 계열(황주 도화동·장산곶 전승 연계)", "SOURCE_TYPE": "classic", "SOURCE_REGION_GRADE": "B",
		"SOURCE_REGION_NOTE": "황주·장산곶은 전승 연계로만 쓰고 유일한 실재 장소라 단정하지 않는다(§37 A11). 게임 안에서는 원작 제목·인물 이름·'인당수'를 쓰지 않는다(§1.3). 사람 제물이 바다를 달랜다는 믿음은 소문으로만 두고 확인하지 않는다 — 플레이어가 확인하는 것은 물살·잔해·셈이다.",
		"ADAPTATION_MODE": "VARIANT", "TRIGGER": trigger, "LOCATION_TYPE": loc, "TIME_WEATHER": tw,
		"PLAYER_ACTIONS": actions, "RESOLUTION_BRANCHES": branches, "WORLD_STATE_CHANGE": wsc, "SOURCE_VERIFIED": true,
		"steps": steps,
	}

static func events() -> Dictionary:
	return {
		"S4001": _ev("S4001", "한양 S1006 이후 황주 도착(도화동)", "황주 도화동 노인 집", "오전 · 맑음",
			"엿듣는 말 · 노인과 대화 · 엽전 꾸러미 조사", "-", "사건 기록 생성", [
			{ "if": "not f('arrived')", "then": [{ "call": "arrival" }] },
			{ "face": "old_man", "to": "player" },
			{ "say": "눈먼 노인", "lines": ["…연이냐?", "아니구나. 발소리가 다르오."] },
			{ "say": "눈먼 노인", "lines": ["그 애가 돈 꾸러미를 두고 갔소. 배를 탄다고.", "뱃일 밥 짓는 데 간다더니, 사흘째 소식이 없소."] },
			{ "call": "start_case" },
		]),
		"S4002": _ev("S4002", "노인 이야기를 들은 뒤 동네 어귀의 중개인", "도화동 어귀", "오전",
			"중개인에게 묻는다(그 말을 정답으로 두지 않는다)", "-", "중개인이 장산곶으로 떠남", [
			{ "say": "탁 중개인", "lines": ["노인 일로 오셨소? 셈은 다 치렀소."] },
			{ "choice": "", "options": [
				{ "label": "그 셈이 무슨 값이오?", "do": [{ "say": "탁 중개인", "lines": ["위험한 바다에는 값을 치러야 하오.", "장산곶 뱃사람들은 다 아는 일이지."] }] },
				{ "label": "연이는 어디 있소?", "do": [{ "say": "탁 중개인", "lines": ["배를 탔으면 바다에 있겠지.", "위험한 바다에는 값을 치러야 하오."] }] }] },
			{ "say": "탁 중개인", "lines": ["나는 셈만 맞췄소. 장산곶에 볼일이 남아서, 이만."] },
			{ "clue": "broker_words" },
			{ "flag": "broker_left_hj" },
			{ "move": "broker", "to": ["dohwa_lane", [-352.0, -360.0]], "speed": 2.4 },
			{ "show": "broker", "value": false },
			{ "call": "offer_travel" },
		]),
		"S4003": _ev("S4003", "장산곶 어촌에 닿음", "장산곶 벼랑·만 안쪽 모래톱", "낮 · 바람",
			"벼랑과 잔해를 보고 물살을 살핀다", "-", "시계가 돈다(15시 바람, 18시 큰 바람)", [
			{ "call": "jangsan_arrival" },
		]),
		"S4004": _ev("S4004", "그물 찌를 얻은 뒤 곶 앞 벼랑(제물 바위)", "제물 바위 앞 벼랑", "낮",
			"찌를 던지고 떠내려가는 곳을 지켜본다 → 돌아온 갯가에서 줍는다", "-", "-", [
			{ "call": "throw_floats" },
		]),
		"S4005": _ev("S4005", "옛 제의 바위(탁본 숙련이 있으면 더 읽는다)", "제물 바위", "낮",
			"새김을 본다 · 탁본(경주 완료 시)", "탁본 있음: 다른 제물을 쓴 옛 흔적 / 없음: 추가 단서 없이 진행", "-", []),
		"S4006": _ev("S4006", "물살이 바위섬 뒤로 도는 것을 안 뒤", "장산곶 앞 바위섬 갯구멍", "낮(15시 바람 · 18시 큰 바람)",
			"뱃사공을 설득해 섬으로 · 밧줄로 바위틈의 연이를 꺼낸다", "구조 / 큰 바람 전에 못 함", "-", []),
		"S4007": _ev("S4007", "구조 뒤 선창 · 또는 큰 바람이 지난 아침", "장산곶 선창·어부 집", "낮 / 아침",
			"중개인의 셈을 따진다 / 연이부터 돌본다 / (구조 실패)",
			"A 사기 입증(중개인 붙잡힘) · B 딸 구조에 집중(중개인 도주) · C 준비 부족으로 구조 실패(게임오버 아님)",
			"A·B: 노인 집에 연이, 탁본을 했으면 짚배 / C: 노인 집 대문 밖 정화수, 바다가 처녀를 받았다는 소문", []),
		"S4008": _ev("S4008", "결말 뒤 중개인의 궤짝", "장산곶 어촌", "-",
			"낡은 운송장을 본다", "-", "MAIN_GWAK_NAME_KNOWN · MAIN_PARK_MARK_COUNT += 1 · MAIN_MASTER_TRACE += HWANGJU", [
			{ "call": "waybill" },
		]),
	}
