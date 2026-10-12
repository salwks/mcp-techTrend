# 사건 「남원의 약속」 PART II-B 「출두」 — 이야기 데이터(ACT 13 관아 일 ~ ACT 22 광한루).
# 시나리오 v1.1 §32~§49 · 결정 §9(차일·잔칫상 간격·cower)·§10(증거 조합 퍼즐 없음의 뜻) · 대사 요청서 v1.0(짧게, 눈앞의 일).
# 게임플레이 구조 1차(seolhwa/docs/production/BRIEF_gameplay_architecture_first_pass.md §7~§20):
#   ACT 13 술·쌀·상소 = Activity/Problem(scripts/story/problems.gd) 세 개 — 순서 자유, 각각 한 번. 본다 → 일한다 → 잇는다 → 고른다 → 한다.
#   이것은 범인을 밝히는 증거 퍼즐이 아니다 — 플레이어는 이미 무엇이 부당한지 안다. 고른 것은 구체적 행동 깃발로만 남고(점수 없음),
#   ACT 19 주변 피해 복구와 마지막 춘향의 말에만 쓰인다. 몽룡 귀환·옥중 상봉·잔치·시·어사출두·변학도 파면·석방(FIXED_BEAT)은 문제 결과와 무관하다.
# 단계: jail(II-A 첫 밤 뒤 — 이튿날 관아 일 · 며칠 뒤 몽룡 귀환 · 월매 집 · 옥중 상봉) → feast(잔치 · 시) → reveal(출두 · 피해 복구) →
#   release(옥문 · 월매 · 마지막 선택) → epilogue(며칠 뒤 광한루) → done(CASE_NAMWON_CHUNHYANG_OUTCOME "RELEASED" · _COMPLETE).
# 장면 번호는 C13xx~C22xx. namwon_chunhyang_data.gd가 이 목록을 II-A 목록 뒤에 잇는다.
extends RefCounted

const JAR := "ITM_CH_WINEJAR"     # 지고 가는 술독 하나(장면 물건 — ITEM_MASTER에 올리지 않음, PART I·II-A와 같은 결정)
const SACK := "ITM_CH_RICESACK"   # 지고 가는 쌀가마니 하나

# 카메라(배치 파일 cameras와 같은 값)
const CAM_14A := { pos = [-3225.4, 1.75, 345.6], look = [-3228.0, 1.5, 352.5], fov = 38.0 }   # 플레이어 어깨 너머, 남문 밖(정면 클로즈업 금지)
const CAM_17A := { pos = [-3165.7, 2.3, 212.05], look = [-3165.7, 0.4, 212.0], fov = 30.0 }    # 종이를 위에서
const CAM_18A := { pos = [-3162.1, 2.75, 203.6], look = [-3162.1, -0.6, 239.5], fov = 40.0 }   # 변학도 뒤에서 정문 쪽 — 같은 축, 자세만 뒤집힌다(화면 순회: 조금 숙여 웅크린 변학도를 틀 안에 · 위 분합문 띠를 위로)
const CAM_FEAST := { "focus": [-3162.1, 213.6], "pitch": 24.0, "distance": 10.0, "fov": 40.0 }   # 잔치 놀이 — 낮고 가까운 틀(차일 SPREAD)
const CAM_EDGE := { "focus": [-3168.6, 216.4], "pitch": 22.0, "distance": 7.5, "fov": 40.0 }      # §41 서쪽 가장자리(낮은 틀)
const CAM_RESTO := { "focus": [-3152.4, 233.4], "pitch": 30.0, "distance": 11.0, "fov": 38.0 }    # ACT 19 바깥마당 물자 곳
const CAM_END := { "focus": [-3326.0, 442.5], "pitch": 22.0, "distance": 20.0, "fov": 38.0 }      # ACT 22 빈 그네(화면 순회: 그네 ti_swing -3330이 틀 밖이라 초점을 그네·아이 사이로)

const DUTY := "ph('jail') and f('duty_on') and not f('duty_over')"
const YEOKJOL := ["yeokjol_1", "yeokjol_2", "yeokjol_3", "yeokjol_4", "yeokjol_5", "yeokjol_6"]

static func items() -> Dictionary:
	return { JAR: "술독(김가 봉지)", SACK: "쌀가마니(박가네)" }

static func anchors() -> Dictionary:
	return {
		# ACT 13 — 술(외삼문 동쪽 수레 · 바깥마당 물자 곳의 물목)
		"ch_order_board": [-3152.8, 233.4], "ch_wine_merchant": [-3148.6, 251.4], "ch_wine_drop": [-3153.4, 227.6], "ch_wine_store": [-3155.0, 228.4],
		# 쌀(동문 밖 박가네 — nw_house_001)
		"ch_rice_pojol": [-3100.6, 275.0], "ch_rice_cart": [-3097.6, 272.8], "ch_rice_drop": [-3148.4, 233.2], "ch_rice_store": [-3147.2, 234.4],
		# 상소(외삼문 서쪽 담 밑 노인 · 외삼문 곁 방 · 형방 소지함)
		"ch_petition_sign": [-3166.8, 241.0], "ch_petition_box": [-3157.2, 236.6],
		# 아전(II-B) · 시작 자리
		"ch_ajeon_b": [-3165.2, 245.0], "ch_ajeon_b_player": [-3166.6, 247.6],
		# ACT 14 — 남문 밖(14A)
		"ch_beggar_from": [-3228.0, 371.0], "ch_beggar_pass": [-3228.4, 330.0], "ch_dusk_start": [-3228.0, 333.0],
		# ACT 16 — 밤 외삼문 · 옥
		"ch_mong_gate_night": [-3163.4, 244.4], "ch_wolmae_gate_night": [-3166.4, 245.4], "ch_mong_bars": [-3176.0, 231.0], "ch_reunion_watch": [-3173.3, 231.5],
		# ACT 17 — 잔치(몽룡 서안 앞 · 잔치 물자)
		"ch_mong_poem": [-3165.7, 212.8], "ch_feast_wine": [-3168.6, 208.9], "ch_feast_rice": [-3155.6, 208.9], "ch_mong_court": [-3162.1, 216.2],
		# ACT 18 — 역졸 자리(가운데 통로 양옆 · 보계 앞)
		"ch_yeokjol_1": [-3163.8, 217.6], "ch_yeokjol_2": [-3160.4, 217.6], "ch_yeokjol_3": [-3163.8, 219.0], "ch_yeokjol_4": [-3160.4, 219.0],
		"ch_yeokjol_5": [-3164.0, 215.0], "ch_yeokjol_6": [-3160.2, 215.0], "ch_yeokjol_from": [-3162.1, 238.0],
		# ACT 19 — 피해 복구(바깥마당 동쪽)
		"ch_resto_clerk": [-3153.0, 231.6], "ch_resto_merchant": [-3150.6, 234.8], "ch_resto_farmer": [-3148.2, 234.0], "ch_resto_elder": [-3155.6, 234.4],
		"ch_resto_player": [-3152.6, 236.4], "ch_resto_rice": [-3146.6, 236.2], "ch_mong_ask": [-3162.1, 215.0], "ch_player_ask": [-3163.6, 216.4],
		# ACT 20·21 — 옥문 · 바깥마당 가운데
		"ch_mong_release": [-3167.6, 230.6], "ch_chun_out": [-3168.4, 229.8], "ch_wolmae_release": [-3166.4, 231.8], "ch_player_release": [-3165.0, 232.4],
		# ACT 22 — 광한루(며칠 뒤)
		"ch_end_kid_b": [-3321.6, 442.6], "ch_end_start": [-3250.0, 446.0],
	}

# ---------------------------------------------------------------------------
# ACT 13 — Activity/Problem 세 개(순서 자유, 각각 한 번). 결과·갈래 깃발은 접두사 없는 사건 깃발(구체적 행동).
#   술:  물목(본 것) · 수레의 술독(본 것) · 상인의 말(들은 것, 선택) → 차이(본 것으로 확인) → 처리: 다 내린다 / 한 독 남긴다 / 상인의 말을 적는다
#   쌀:  징발 표(본 것) · 대문 앞 가마니(본 것) · 농민의 말(들은 것, 선택) → 차이 → 처리: 물러서라 한다 / 한 가마만 / 아전에게 다시 묻는다
#   상소: 노인의 사연(들은 것 — 확정하지 않음) · 선비 이야기(들은 것 — 이겸이라 하지 않음, MAIN_MASTER_TRACE 그대로) ·
#        소지가 가는 곳(본 것) · 실제 처리 상태(본 것) → '내일 와'와 실제(추정) → 처리: 돌려보낸다 / 소지를 위로 올린다 / 노인의 말을 적는다
# 일하는 손(술독·가마니를 지고 가기, 아전에게 다시 묻기, 노인에게 말하기)은 문제 밖 — 사건 코드(namwon_chunhyang_p2b.gd)와 아래 objects.
# ---------------------------------------------------------------------------
static func problems() -> Dictionary:
	return {
		"wine": {
			"title": "잔치 술", "when": DUTY,
			"activities": [
				{ "id": "order", "type": "inspect", "kind": "seen", "at": "ch_order_board", "label": "잔치 물목 · 살펴보기", "radius": 1.8,
					"text": ["잔치 물목. 술 — 김가 술도가, 두 독.", "끝에 한 줄. '값은 관아 창고에서 셈한다.'"],
					"record": { "title": "잔치 물목(술)", "text": "물목에 적힌 술은 김가 술도가에서 두 독. 값은 관아 창고에서 치른다고 적혀 있다." } },
				{ "id": "cart", "type": "inspect", "kind": "seen", "at": "ch_wine_cart", "label": "술 수레 · 살펴보기", "radius": 2.8,
					"text": ["수레에 술독 셋이 새끼로 묶여 있다.", "독마다 '김가' 봉지가 붙었다."],
					"record": { "title": "수레의 술독", "text": "외삼문 동쪽 김가 수레에 술독 셋. 봉지가 붙은 채다." } },
				{ "id": "merchant", "type": "inspect", "kind": "heard", "actor": "wine_merchant", "by": "술 상인 김가", "required": false,
					"record": { "title": "상인의 말", "text": "지난번 들인 술값도 아직 못 받았다고 한다. 이번엔 두 독이라 해서 왔는데 셋 다 내리라 한다고." } },
				{ "id": "gap", "type": "compare", "needs": ["order", "cart"],
					"text": ["물목: 두 독.", "수레: 세 독. 아전은 셋 다 내리라 한다."],
					"record": { "title": "물목과 다른 수", "text": "물목은 두 독. 수레에는 세 독. 아전은 셋 다 내리라 했다.", "kind": "fact" },
					"flags": ["wine_discrepancy_seen"] },
				{ "id": "handle", "type": "decide", "needs": ["gap"], "at": "ch_wine_cart", "radius": 14.0, "prompt": "술독을 어떻게 내릴까?",
					"options": [
						{ "id": "all", "label": "아전 말대로 세 독을 다 내린다.", "flags": ["wine_taken_all"] },
						{ "id": "leave", "label": "물목대로 두 독만. 한 독은 수레에 둔다.", "flags": ["wine_left"] },
						{ "id": "record", "label": "다 내리되, 상인의 말을 적어 둔다.", "when": "pa('wine','merchant')", "flags": ["wine_recorded", "wine_taken_all"],
							"record": { "title": "적어 둔 것 — 술", "text": "김가 술도가. 지난번 술값 못 받음. 이번 세 독(물목은 두 독). 값은 아직.", "kind": "heard", "by": "술 상인 김가" } },
					] },
			],
			"result": { "flags": ["wine_done"], "do": [{ "call": "wine_handled" }] },
		},
		"rice": {
			"title": "박가네 쌀", "when": DUTY,
			"activities": [
				{ "id": "order", "type": "inspect", "kind": "seen", "at": "ch_rice_cart", "label": "징발 표 · 살펴보기", "radius": 2.6,
					"text": ["수레 끌채에 꽂힌 징발 표.", "'동문 밖 박가 — 벼 두 가마. 잔치 소용.' 이방 수결."],
					"record": { "title": "징발 표", "text": "동문 밖 박가네에서 벼 두 가마. 이방의 수결." }, "flags": ["rice_order_seen"] },
				{ "id": "sacks", "type": "inspect", "kind": "seen", "at": "ch_rice_sacks", "label": "가마니 · 살펴보기", "radius": 2.6,
					"text": ["대문 앞에 가마니 넷. 포졸이 수레에 실을 참이다.", "열린 대문 안 뒤주는 거의 비었다."],
					"record": { "title": "대문 앞 가마니", "text": "박가네 대문 앞에 가마니 넷이 나와 있다. 마당 뒤주는 거의 비었다." } },
				{ "id": "farmer", "type": "inspect", "kind": "heard", "actor": "rice_farmer", "by": "농민 박가", "required": false,
					"record": { "title": "겨울 양식", "text": "두 가마라 해서 내놨는데 포졸이 넷을 내놓으라 했다고 한다. 겨울에 먹을 쌀이라고." } },
				{ "id": "gap", "type": "compare", "needs": ["order", "sacks"],
					"text": ["징발 표: 두 가마.", "대문 앞: 가마니 넷."],
					"record": { "title": "표보다 많은 가마니", "text": "징발 표는 두 가마. 대문 앞에 나온 가마니는 넷.", "kind": "fact" },
					"flags": ["rice_discrepancy_seen"] },
				{ "id": "handle", "type": "decide", "needs": ["gap"], "at": "ch_rice_sacks", "radius": 16.0, "prompt": "가마니를 어떻게 할까?",
					"options": [
						{ "id": "all", "label": "농민에게 물러서라 한다.", "flags": ["rice_taken_full"] },
						{ "id": "one", "label": "한 가마만 지고 간다.", "flags": ["rice_left"] },
						{ "id": "reask", "label": "아전에게 다시 묻고 오겠다.", "flags": ["rice_reasked"] },
					] },
			],
			"result": { "flags": ["rice_done"], "do": [{ "call": "rice_handled" }] },
		},
		"petition": {
			"title": "노인의 소지", "when": DUTY,
			"activities": [
				{ "id": "old_man", "type": "inspect", "kind": "heard", "actor": "petition_elder", "by": "농부", "required": false,
					"record": { "title": "소", "text": "관아가 사또 생일잔치에 쓴다며 소를 가져갔다고 한다." }, "flags": ["old_man_heard"] },
				{ "id": "scholar", "type": "inspect", "kind": "heard", "actor": "petition_elder", "by": "농부", "required": false,
					"record": { "title": "책을 든 선비", "text": "며칠 전 책 한 권을 들고 다니던 선비가 관아의 일을 물어보고 기록해 갔다고 한다." },
					"flags": ["yi_gyeom_trace_heard"] },
				{ "id": "route", "type": "inspect", "kind": "seen", "at": "ch_petition_sign", "label": "외삼문 곁 방 · 살펴보기", "radius": 1.8,
					"text": ["외삼문 곁에 붙은 방.", "'백성의 소지는 형방이 받아 사흘 안에 제사(題辭)를 내린다.'"],
					"record": { "title": "소지가 가는 곳", "text": "소지는 형방이 받아 사흘 안에 제사를 내린다고 외삼문 곁 방에 적혀 있다." } },
				{ "id": "status", "type": "inspect", "kind": "seen", "at": "ch_petition_box", "label": "형방 소지함 · 살펴보기", "radius": 1.8,
					"text": ["소지함 위에 잔치 물목이 덮여 있다.", "그 밑에 같은 이름의 소지 셋. 제사 칸이 비었다. 날짜는 열흘 전부터."],
					"record": { "title": "열리지 않은 소지", "text": "형방 소지함, 잔치 물목 밑에 같은 이름의 소지 셋. 제사 칸이 비었다. 가장 이른 것은 열흘 전." } },
				{ "id": "gap", "type": "compare", "needs": ["route", "status"],
					"text": ["방: 사흘 안에 제사.", "소지함: 같은 이름의 소지 셋. 제사 칸은 열흘째 비었다."],
					"record": { "title": "'내일 와'", "text": "방에는 사흘 안에 제사를 내린다고 적혀 있다. 노인의 소지는 열흘째 제사 칸이 비었다.", "kind": "guess" },
					"flags": ["petition_gap_seen"] },
				{ "id": "handle", "type": "decide", "needs": ["gap"], "at": "ch_petition_box", "radius": 12.0, "prompt": "노인의 소지를 어떻게 할까?",
					"options": [
						{ "id": "dismiss", "label": "아전 말대로 노인을 돌려보낸다.", "flags": ["petition_dismissed"] },
						{ "id": "process", "label": "소지를 맨 위에 올리고 받은 날을 적는다.", "flags": ["petition_processed"] },
						{ "id": "note", "label": "노인의 말을 내 기록책에 적어 둔다.", "when": "pa('petition','old_man')", "flags": ["old_man_recorded"],
							"record": { "title": "적어 둔 것 — 소", "text": "외삼문 담 밑 노인. 잔치에 쓴다며 소를 가져갔다고 함(들은 말). 소지 셋, 열흘째 제사 없음.", "kind": "heard", "by": "농부" } },
					] },
			],
			"result": { "flags": ["petition_done"], "do": [{ "call": "petition_handled" }] },
		},
	}

# ---------------------------------------------------------------------------
# 인물(II-B) — 고유: mongryong_beggar · wolmae · byeon · chunhyang_prison / generic: 아전 py_clerk · 상인 merchant · 농민 farmer · 노인 elder ·
#   포졸·역졸 pojol(+ courier_b) · 어사 측 서리 official · 아이 둘. 사령 줄·잔치 군중은 PART II 준비 그대로(guard_posts · EventCrowd byeon_banquet).
# ---------------------------------------------------------------------------
static func actors() -> Array:
	var out := [
		{ "id": "ajeon_b", "chr": "CHR_HUM_004", "kind": "py_clerk", "name": "아전", "at": "ch_ajeon_b", "facing": "down",
			"when": "(ph('jail') and f('p2b_started') and not f('duty_over')) or ph('feast')",
			"talk": [
				{ "when": "f('duty_complete') and not f('duty_over')", "steps": [{ "event": "C1305" }] },
				{ "when": "f('rice_reasked') and not f('rice_reask_done')", "steps": [{ "call": "rice_reask" }] },
				{ "when": "ph('feast')", "steps": [{ "say": "아전", "lines": ["오늘은 서쪽 줄 끝이오. 사또 눈에 띄게 굴지 마시오."] }] },
				{ "when": "has('%s') or has('%s')" % [JAR, SACK], "steps": [{ "say": "아전", "lines": ["물자 쌓는 데는 바깥마당 동쪽이오. 내삼문 쪽 말고."] }] },
				{ "when": "true", "steps": [{ "say": "아전", "lines": ["술, 쌀, 노인네. 해 지기 전에."] }] },
			] },
		{ "id": "wine_merchant", "chr": "CHR_HUM_002", "kind": "merchant", "name": "술 상인", "at": "ch_wine_merchant", "facing": "up",
			"when": "(ph('jail') and f('p2b_started') and not f('duty_over')) or (ph('reveal') and f('resto_on') and f('restore_wine_paid'))",
			"talk": [
				{ "when": "f('duty_on') and not pa('wine','merchant')", "steps": [
					{ "call": "talk_free", "args": ["술 상인", ["지난번 들인 술값도 아직 못 받았소.", "이번엔 두 독이라 해서 왔더니, 셋 다 내리라잖소. 셋 값은 누가 주오?"]] },
					{ "activity": "wine.merchant" }] },
				{ "when": "pd('wine') == 'leave'", "steps": [{ "say": "술 상인", "lines": ["한 독이라도 남았으니… 이건 도로 싣고 가겠소."] }] },
				{ "when": "pd('wine') == 'record'", "steps": [{ "say": "술 상인", "lines": ["적어 두면 뭐가 달라지오? …그래도 적으시오. 김가요, 김가."] }] },
				{ "when": "pd('wine') == 'all'", "steps": [{ "say": "술 상인", "lines": ["다 가져가시오. 어디 가서 따지겠소."] }] },
				{ "when": "true", "steps": [{ "say": "술 상인", "lines": ["술값은 관아 창고에서 준다더니."] }] },
			] },
		{ "id": "rice_farmer", "chr": "CHR_HUM_009", "kind": "farmer", "name": "농민 박가", "at": "ch_farmer", "facing": "right",
			"when": "(ph('jail') and f('p2b_started') and not f('duty_over')) or (ph('reveal') and f('resto_on') and (f('restore_rice_returned') or f('restore_rice_thanks')))",
			"talk": [
				{ "when": "f('duty_on') and not pa('rice','farmer')", "steps": [
					{ "call": "talk_free", "args": ["농민 박가", ["이건 겨울 먹을 겁니다.", "두 가마라 해서 내놨소. 근데 포졸이 넷을 내놓으라잖소."]] },
					{ "activity": "rice.farmer" }] },
				{ "when": "pd('rice') == 'one'", "steps": [{ "say": "농민 박가", "lines": ["…셋은 남았소. 이번 겨울은 나겠소."] }] },
				{ "when": "pd('rice') == 'all'", "steps": [{ "say": "농민 박가", "lines": ["…"] }] },
				{ "when": "pd('rice') == 'reask'", "steps": [{ "say": "농민 박가", "lines": ["물어봐 준다고요? …기다리겠소."] }] },
				{ "when": "true", "steps": [{ "say": "농민 박가", "lines": ["관아 사람이오? 또 뭘 가져가려고."] }] },
			] },
		{ "id": "rice_pojol", "chr": "CHR_HUM_016", "kind": "pojol", "name": "포졸", "at": "ch_rice_pojol", "facing": "left", "accent": false,
			"when": "ph('jail') and f('p2b_started') and not f('duty_over') and not f('rice_cart_gone')",
			"talk": [
				{ "when": "pd('rice') == ''", "steps": [{ "say": "포졸", "lines": ["관아 일 하는 사람이오? 그럼 거들어. 넷 다 실어 가야 하오."] }] },
				{ "when": "true", "steps": [{ "say": "포졸", "lines": ["해 지기 전에 들어가야 하오."] }] },
			] },
		{ "id": "petition_elder", "chr": "CHR_HUM_022", "kind": "elder", "name": "노인", "at": "ch_elder_petition", "facing": "down", "anim": "sit",
			"when": "(ph('jail') and f('p2b_started') and not f('duty_over') and not f('elder_gone')) or (ph('reveal') and f('resto_on') and f('restore_petition_reopened'))",
			"talk": [
				{ "when": "pd('petition') == 'dismiss' and not f('petition_act_done')", "steps": [{ "call": "elder_dismiss" }] },
				{ "when": "f('duty_on') and not pa('petition','old_man')", "steps": [
					{ "say": "노인", "lines": ["사또 좀 만나게 해 주시오."] },
					{ "choice": "", "options": [
						{ "label": "(사연을 듣는다) 무슨 일이오?", "id": "listen", "do": [
							{ "call": "talk_free", "args": ["노인", ["잔치에 쓴다고 소를 가져갔소. 밭 갈 소를."]] },
							{ "activity": "petition.old_man" },
							{ "call": "talk_free", "args": ["노인", ["며칠 전에도 책 한 권 끼고 다니는 선비가 와서 이런 일을 묻더군."]] },
							{ "call": "talk_free", "args": ["나그네", ["어떤 선비였소?"]] },
							{ "call": "talk_free", "args": ["노인", ["이름은 말 안 했소. 내 말만 한참 적어 갔지."]] },
							{ "activity": "petition.scholar" }] },
						{ "label": "(그냥 지나간다)", "id": "pass", "do": [{ "flag": "elder_passed" }] }] }] },
				{ "when": "pd('petition') == 'process'", "steps": [{ "say": "나그네", "lines": ["소지를 맨 위에 올려 두었소. 받은 날도 적었고."] }, { "say": "노인", "lines": ["…올려만 두면 누가 보오. 그래도 고맙소."] }] },
				{ "when": "pd('petition') == 'note'", "steps": [{ "say": "노인", "lines": ["적었소? 내 말을?"] }] },
				{ "when": "true", "steps": [{ "say": "노인", "lines": ["내일 오라는 말만 사흘째요."] }] },
			] },
		# 몽룡(거지 차림) — 남문 밖 귀환부터 석방까지 한 사람(같은 노드). 마패는 출두 때만(동작 mapae)
		{ "id": "mong_b", "chr": "CHR_CH_MONGRYONG", "kind": "mongryong_beggar", "name": "몽룡", "at": "ch_beggar_from", "facing": "up", "accent": false,
			"when": "f('mong_b_on')" },
		{ "id": "wolmae_b", "chr": "CHR_CH_WOLMAE", "kind": "wolmae", "name": "월매", "at": "ch_wolmae_at_gate", "facing": "down", "accent": false,
			"when": "f('wolmae_b_on')",
			"talk": [{ "when": "true", "steps": [{ "say": "월매", "lines": ["…"] }] }] },
		# 잔치·출두의 변학도(교의 — 대청 dy 1.05). 출두 때 제자리 cower(결정 §9-5)
		{ "id": "byeon_feast", "chr": "CHR_CH_BYEON", "kind": "byeon", "name": "변학도", "at": "ch_byeon_seat", "facing": "down", "anim": "sit", "accent": false,
			"when": "ph('feast') or ph('reveal')" },
		# 석방 때 옥 춘향(옥문을 나와 바깥마당으로)
		{ "id": "chun_release", "chr": "CHR_CH_CHUNHYANG", "kind": "chunhyang_prison", "name": "춘향", "at": "ch_jail_cell", "facing": "down", "anim": "sit", "accent": false,
			"when": "ph('release')" },
		# ACT 19 — 어사 측 서리
		{ "id": "resto_clerk", "chr": "CHR_HUM_004", "kind": "official", "name": "어사 측 서리", "at": "ch_resto_clerk", "facing": "down", "accent": false,
			"when": "ph('reveal') and f('resto_on')" },
		# ACT 22 — 그네 곁 아이 둘
		{ "id": "end_kid_a", "chr": "CHR_HUM_020", "kind": "child_boy", "name": "아이", "at": "ch_end_kids", "facing": "right", "when": "ph('epilogue') or ph('done')", "accent": false },
		{ "id": "end_kid_b", "chr": "CHR_HUM_021", "kind": "child_girl", "name": "아이", "at": "ch_end_kid_b", "facing": "left", "when": "ph('epilogue') or ph('done')", "accent": false },
	]
	# ACT 18 — 역졸 여섯(어사 수행원: pojol · courier_b 섞기). 출두 컷에서 외삼문으로 들어와 제자리에 선다
	for i in YEOKJOL.size():
		out.append({ "id": YEOKJOL[i], "chr": "CHR_HUM_016", "kind": "pojol" if i % 2 == 0 else "courier_b", "name": "역졸",
			"at": "ch_" + YEOKJOL[i], "facing": "up" if i < 4 else "down", "accent": false, "tags": ["yeokjol"],
			"when": "(ph('reveal') or ph('release')) and f('yeokjol_in')" })
	return out

# ---------------------------------------------------------------------------
# 일하는 손(문제 밖) — 지고 가기 · 내려놓기
# ---------------------------------------------------------------------------
static func objects() -> Array:
	return [
		{ "id": "p2b_wine_lift", "at": "ch_wine_cart", "label": "술독 · 지고 간다", "radius": 2.8, "prompt_type": "INSPECT",
			"when": "ph('jail') and pd('wine') != '' and not f('wine_lifted')", "steps": [{ "call": "wine_lift" }] },
		{ "id": "p2b_wine_drop", "at": "ch_wine_drop", "label": "술독 · 내려놓는다", "radius": 2.2, "prompt_type": "INSPECT",
			"when": "ph('jail') and has('%s')" % JAR, "steps": [{ "call": "wine_drop" }] },
		{ "id": "p2b_rice_lift", "at": "ch_rice_sacks", "label": "가마니 · 지고 간다", "radius": 2.6, "prompt_type": "INSPECT",
			"when": "ph('jail') and (pd('rice') == 'all' or pd('rice') == 'one') and not f('rice_lifted')", "steps": [{ "call": "rice_lift" }] },
		{ "id": "p2b_rice_drop", "at": "ch_rice_drop", "label": "가마니 · 내려놓는다", "radius": 2.2, "prompt_type": "INSPECT",
			"when": "ph('jail') and has('%s')" % SACK, "steps": [{ "call": "rice_drop" }] },
		# 잔치 — 내가 나른 것(선택 관찰 — 문제 밖, 잔치에서 이어짐을 손으로 확인)
		{ "id": "p2b_feast_wine", "at": "ch_feast_wine", "label": "술독 · 살펴보기", "radius": 1.8, "prompt_type": "INSPECT",
			"when": "ph('feast') and f('feast_seen') and not f('feast_wine_looked')", "steps": [{ "call": "feast_wine_look" }] },
	]

# ---------------------------------------------------------------------------
# 자리 트리거 · 엿듣는 말
# ---------------------------------------------------------------------------
static func triggers() -> Array:
	return [
		# 이튿날 아침 — 첫 밤 뒤 관아 앞(한 번 멀어졌다 다시 오거나, 날이 밝았을 때)
		{ "id": "c1300_morning", "at": "ch_gwana_front", "radius": 7.0, "when": "ph('jail') and f('p2a_done') and not f('p2b_started') and fn('p2b_ready')", "event": "C1300" },
		# ACT 14 — 며칠 뒤 해 질 무렵, 남문 밖
		{ "id": "c1401_beggar", "at": "ch_player_sgate", "radius": 5.0, "when": "ph('jail') and f('dusk_on') and not f('mongryong_return_seen')", "event": "C1401" },
		# ACT 15 — 월매 집
		{ "id": "c1501_wolmae", "at": "ch_wolmae_front", "radius": 7.0, "when": "ph('jail') and f('mongryong_return_seen') and not f('wolmae_reunion_seen')", "event": "C1501" },
		# ACT 16 — 밤 외삼문 밖
		{ "id": "c1601_reunion", "at": "ch_prison_food", "radius": 8.0, "when": "ph('jail') and f('wolmae_reunion_seen') and not f('jail_reunion_seen')", "event": "C1601" },
		# ACT 17 — 잔치 날 내삼문 · 서쪽 줄 끝
		{ "id": "c1701_feast", "at": "ch_naesammun", "radius": 4.5, "when": "ph('feast') and f('feast_day') and not f('feast_seen')", "event": "C1701" },
		{ "id": "c1702_mong", "at": "ch_player_saryeong", "radius": 1.8, "when": "ph('feast') and f('feast_seen') and not f('mong_feast_in')", "event": "C1702" },
		# 시 뒤에 불러온 저장(드묾 — 같은 흐름이라 보통은 저장되지 않음) → 출두만 다시(시는 다시 하지 않는다)
		{ "id": "c1801_resume", "at": "ch_player_saryeong", "radius": 3.0, "once": false, "when": "ph('feast') and f('poem_done') and not f('royal_inspector_reveal') and not fn('p2b_busy')", "event": "C1801" },
		{ "id": "c1901_resume", "once": false, "when": "ph('reveal') and f('royal_inspector_reveal') and not f('restore_done') and not fn('p2b_busy')", "steps": [{ "call": "restoration_resume" }] },
		# ACT 20 — 옥문
		{ "id": "c2001_release", "at": "ch_jail_gate", "radius": 5.0, "when": "ph('release') and not f('chunhyang_released')", "event": "C2001" },
		# ACT 22 — 광한루
		{ "id": "c2201_end", "at": "ch_gwanghallu_front", "radius": 12.0, "when": "ph('epilogue') and not f('end_seen')", "event": "C2201" },
		# 엿듣는 말(조작을 막지 않음)
		{ "id": "b_wine_cart", "at": "ch_wine_cart", "radius": 9.0, "when": "ph('jail') and f('duty_on') and not f('pb.wine.done')",
			"ambient": [["술 상인", "지난번 것도 아직 돈 못 받았소."], ["아전", "사또 생신인데 잔돈 가지고 시끄럽게 하지 마."]] },
		{ "id": "b_rice_farm", "at": "ch_rice_sacks", "radius": 12.0, "when": "ph('jail') and f('duty_on') and not f('pb.rice.done')",
			"ambient": [["농민", "이건 겨울 먹을 겁니다."], ["포졸", "관아 명령이다."]] },
		{ "id": "b_petition", "at": "ch_elder_petition", "radius": 7.5, "when": "ph('jail') and f('duty_on') and not f('pb.petition.done')",
			"ambient": [["노인", "사또 좀 만나게 해 주시오."], ["아전", "내일 와."], ["노인", "어제도 내일 오라 했소."]] },
		{ "id": "b_feast_gate", "at": "ch_oesammun_in", "radius": 9.0, "when": "ph('feast') and f('feast_day') and not f('feast_seen')",
			"ambient": [["관속", "술동이 비면 바로 채워. 사또 상 먼저."], ["시중 아낙", "떡 더 내가요!"]] },
		{ "id": "b_release_road", "at": "ch_oesammun_in", "radius": 8.0, "when": "ph('release') and not f('chunhyang_released')",
			"ambient": [["관속", "옥문 열쇠! 어사또께서 직접 가신다."]] },
	]

# ---------------------------------------------------------------------------
# 소품(II-B — 이야기 소품, 충돌체 없음). 배치 파일의 수레·가마니(ti_wine_cart · ti_rice_sacks)는 내린 뒤 숨는다(when)
# ---------------------------------------------------------------------------
static func props() -> Array:
	return [
		{ "id": "p_order_desk", "kit": "scenario/props", "params": { "kind": "jangbu", "seed": 3301 }, "at": "ch_order_board", "dy": 0.0, "ry": 0.0,
			"when": "ph('jail') and f('p2b_started') and not f('duty_over')" },
		{ "id": "p_petition_desk", "kit": "scenario/props", "params": { "kind": "chaeksang", "seed": 3302 }, "at": "ch_petition_box", "dy": 0.0, "ry": 3.1416,
			"when": "ph('jail') and f('p2b_started')" },
		{ "id": "p_cart_one", "kit": "story/snow_road", "params": { "kind": "cart", "upright": true, "jars": 1 }, "at": "ch_wine_cart", "dy": 0.0,
			"when": "ph('jail') and f('wine_unloaded') and f('wine_left')" },
		{ "id": "p_cart_empty", "kit": "story/snow_road", "params": { "kind": "cart", "upright": true, "jars": 0 }, "at": "ch_wine_cart", "dy": 0.0,
			"when": "ph('jail') and f('wine_unloaded') and not f('wine_left')" },
		{ "id": "p_store_wine", "kit": "village/props", "params": { "kind": "dok", "n": 3, "seed": 3303 }, "at": "ch_wine_store", "dy": 0.0,
			"when": "ph('jail') and f('wine_stored') and not f('wine_left')" },
		{ "id": "p_store_wine2", "kit": "village/props", "params": { "kind": "dok", "n": 2, "seed": 3303 }, "at": "ch_wine_store", "dy": 0.0,
			"when": "ph('jail') and f('wine_stored') and f('wine_left')" },
		{ "id": "p_rice_cart", "kit": "story/snow_road", "params": { "kind": "cart", "upright": true, "jars": 0 }, "at": "ch_rice_cart", "dy": 0.0, "ry": 1.5708,
			"when": "ph('jail') and f('p2b_started') and not f('rice_cart_gone')" },
		{ "id": "p_store_rice", "kit": "scenario/props", "params": { "kind": "gamani", "seed": 3304 }, "at": "ch_rice_store", "dy": 0.0,
			"when": "ph('jail') and (f('rice_stored') or f('rice_reask_done'))" },
		# 잔치 — 내가 나른 술독(김가 봉지)과 가마니가 상 곁에(8A 틀 안)
		{ "id": "p_feast_wine3", "kit": "village/props", "params": { "kind": "dok", "n": 3, "seed": 3305 }, "at": "ch_feast_wine", "dy": 0.0,
			"when": "(ph('feast') or ph('reveal')) and not f('wine_left')" },
		{ "id": "p_feast_wine2", "kit": "village/props", "params": { "kind": "dok", "n": 2, "seed": 3305 }, "at": "ch_feast_wine", "dy": 0.0,
			"when": "(ph('feast') or ph('reveal')) and f('wine_left')" },
		{ "id": "p_feast_rice", "kit": "scenario/props", "params": { "kind": "gamani", "seed": 3306 }, "at": "ch_feast_rice", "dy": 0.0,
			"when": "ph('feast') or ph('reveal')" },
		# ACT 19 — 돌아가는 가마니
		{ "id": "p_resto_rice", "kit": "scenario/props", "params": { "kind": "gamani", "seed": 3307 }, "at": "ch_resto_rice", "dy": 0.0,
			"when": "ph('reveal') and f('resto_on') and f('restore_rice_returned')" },
	]

static func clues() -> Dictionary:
	return {
		"duty_three": { "title": "잔치 일 셋", "text": "이튿날 아침 아전이 일을 셋 맡겼다. 외삼문 동쪽 술 수레, 동문 밖 박가네 쌀, 담 밑 노인.", "kind": "fact" },
		"beggar_back": { "title": "남문 밖의 사내", "text": "해 질 무렵 남문 밖. 해진 도포에 찢어진 갓. 이몽룡이었다. “못 본 사람으로 해 주시오.”", "kind": "fact" },
		"beggar_wolmae": { "title": "거지가 돼 왔소?", "text": "월매가 문을 열고 한참 만에 알아보았다. “돌아온다더니 거지가 돼 왔소?” 몽룡은 변명하지 않았다.", "kind": "heard", "by": "월매" },
		"reunion": { "title": "창살 너머", "text": "밤, 옥. 몽룡이 춘향을 불렀다. 춘향 “살아 있으면 된 줄 알았어요.” 나는 창살 밖에 있었다.", "kind": "fact" },
		"feast_goods": { "title": "잔치 상", "text": "잔치 마당 보계 곁에 김가 봉지가 붙은 술독. 건너편에 동문 밖에서 실어 온 가마니. 내가 나른 것이다.", "kind": "fact" },
		"poem": { "title": "네 줄의 시", "text": "몽룡이 쓴 시. 금동이의 좋은 술은 백성의 피요, 옥쟁반의 좋은 안주는 백성의 기름이라…", "kind": "fact" },
		"reveal": { "title": "출두", "text": "잔치 음악이 끊기고 말발굽. “암행어사 출두야!” 이몽룡이 마패를 들었다. 변학도는 관인을 빼앗겼다.", "kind": "fact" },
		"restoration": { "title": "다시 셈한 것", "text": "어사 측이 잔치에 들어간 물자와 밀린 소지를 다시 셈했다. 내가 본 것과 들은 것을 따로 말했다.", "kind": "fact" },
		"release": { "title": "옥문", "text": "옥문이 열렸다. 몽룡 “늦었소.” 춘향 “왔으니 됐습니다.”", "kind": "fact" },
	}

static func map_leads() -> Array:
	return [
		{ "id": "ch_p2b_morning", "name": "관아 앞 — 이튿날", "at": "ch_gwana_front", "when": "f('p2a_done')", "until": "f('p2b_started')", "note": "ACT 13 시작 — 아전" },
		{ "id": "ch_p2b_wine", "name": "외삼문 동쪽 — 술 수레", "at": "ch_wine_cart", "when": "f('duty_on')", "until": "f('wine_stored')", "note": "§32 술" },
		{ "id": "ch_p2b_rice", "name": "동문 밖 박가네 — 쌀", "at": "ch_rice_sacks", "when": "f('duty_on')", "until": "f('rice_stored') or f('rice_reask_done')", "note": "§33 쌀" },
		{ "id": "ch_p2b_reask", "name": "아전 — 다시 묻기", "at": "ch_ajeon_b", "when": "f('rice_reasked')", "until": "f('rice_reask_done')", "note": "§33 아전에게 다시 묻는다" },
		{ "id": "ch_p2b_elder", "name": "외삼문 서쪽 담 밑 — 노인", "at": "ch_elder_petition", "when": "f('duty_on')", "until": "f('petition_act_done')", "note": "§34 상소" },
		{ "id": "ch_p2b_store", "name": "바깥마당 동쪽 — 물자 쌓는 곳", "at": "ch_wine_drop", "when": "has('%s') or has('%s')" % [JAR, SACK], "until": "false", "note": "지고 간 것을 내려놓는다" },
		{ "id": "ch_p2b_done", "name": "아전 — 일을 마침", "at": "ch_ajeon_b", "when": "f('duty_complete')", "until": "f('duty_over')", "note": "ACT 13 끝" },
		{ "id": "ch_p2b_sgate", "name": "남문 밖", "at": "ch_player_sgate", "when": "f('dusk_on')", "until": "f('mongryong_return_seen')", "note": "ACT 14 CAMERA 14A" },
		{ "id": "ch_p2b_wolmae", "name": "월매 집", "at": "ch_wolmae_gate", "when": "f('mongryong_return_seen')", "until": "f('wolmae_reunion_seen')", "note": "ACT 15" },
		{ "id": "ch_p2b_gate_night", "name": "외삼문 밖(밤)", "at": "ch_prison_food", "when": "f('wolmae_reunion_seen')", "until": "f('jail_reunion_seen')", "note": "ACT 16 옥중 상봉" },
		{ "id": "ch_p2b_feast", "name": "관아 안마당 — 잔치", "at": "ch_naesammun", "when": "f('feast_day')", "until": "f('feast_seen')", "note": "ACT 17" },
		{ "id": "ch_p2b_line", "name": "서쪽 줄 끝", "at": "ch_player_saryeong", "when": "f('feast_seen')", "until": "f('mong_feast_in')", "note": "§41" },
		{ "id": "ch_p2b_jail", "name": "옥 — 몽룡이 간 곳", "at": "ch_jail_gate", "when": "ph('release')", "until": "f('chunhyang_released')", "note": "ACT 20" },
		{ "id": "ch_p2b_end", "name": "광한루", "at": "ch_gwanghallu_front", "when": "ph('epilogue')", "until": "f('end_seen')", "note": "ACT 22" },
	]

static func map_places() -> Array:
	return [
		{ "id": "farm_bak", "name": "박가네(동문 밖)", "at": "ch_rice_sacks", "building": true, "radius": 8.0, "known": "f('duty_on')" },
	]

static func unknowns() -> Array:
	return [
		{ "text": "노인의 소는 어디로 갔나.", "when": "f('old_man_heard')", "until": "f('restore_petition_reopened') or ph('done')" },
		{ "text": "몽룡은 왜 그 꼴로 돌아왔나.", "when": "f('mongryong_return_seen')", "until": "f('royal_inspector_reveal')" },
	]

static func places() -> Array:
	return [{ "name": "동문 밖 박가네", "when": "f('duty_on')" }]

# 원전 고정 장면(II-B) — 문제 결과와 무관하게 일어난다(PART I 6 · II-A 5와 합 18)
static func fixed_beats() -> Array:
	return [
		{ "id": "mongryong_return", "text": "몽룡이 거지 차림으로 돌아옴" },
		{ "id": "wolmae_reunion", "text": "월매 집의 거지 몽룡" },
		{ "id": "jail_reunion", "text": "옥중 상봉" },
		{ "id": "birthday_feast", "text": "변학도 생일잔치" },
		{ "id": "poem", "text": "몽룡의 시" },
		{ "id": "royal_inspector", "text": "암행어사 출두" },
		{ "id": "byeon_dismissed", "text": "변학도 파면(관인을 거둠)" },
		{ "id": "release", "text": "춘향 석방" },
	]

static func _ev(id: String, trigger: String, loc: String, tw: String, actions: String, branches: String, wsc: String, steps: Array) -> Dictionary:
	return {
		"EVENT_ID": id, "EVENT_CLASS": "FOLKLORE_EVENT", "RECORD_TITLE": "남원의 약속", "SOURCE_ID": "F50", "CATALOG_ID": "HN01",
		"SOURCE_TITLE_INTERNAL": "춘향전(열녀춘향수절가)", "SOURCE_TYPE": "pansori_novel", "SOURCE_REGION_GRADE": "A",
		"SOURCE_REGION_NOTE": "남원 고정 전승(지역 앵커 A01 춘향 계열 — 관아·옥·광한루). 완판 84장본의 거지 몽룡 귀환~어사출두~석방(PART II-B)을 화면에서 그대로 겪는다(DIRECT). 플레이어는 관아 일을 하는 외지인 — 출두를 만들지 않는다.",
		"ADAPTATION_MODE": "DIRECT", "TRIGGER": trigger, "LOCATION_TYPE": loc, "TIME_WEATHER": tw,
		"PLAYER_ACTIONS": actions, "RESOLUTION_BRANCHES": branches, "WORLD_STATE_CHANGE": wsc, "SOURCE_VERIFIED": true,
		"steps": steps,
	}

static func events() -> Dictionary:
	return {
		"C1300": _ev("C1300", "옥의 첫 밤 뒤 관아 앞(이튿날)", "외삼문 앞", "아침", "아전에게 일 셋을 받는다", "-", "duty_on · 지도에 술 수레·박가네·담 밑 노인", [{ "call": "duty_morning" }]),
		"C1305": _ev("C1305", "일 셋을 마치고 아전에게", "외삼문 앞", "낮 → 며칠 뒤 해 질 무렵", "일을 마쳤다고 알린다", "-", "duty_over · dusk_on", [{ "call": "duty_end" }]),
		"C1401": _ev("C1401", "며칠 뒤 해 질 무렵 남문 밖", "남문 밖 장터길(CAMERA 14A)", "해 질 무렵", "멈춰 선다", "-", "mongryong_return_seen", [{ "call": "beggar_return" }]),
		"C1501": _ev("C1501", "그 뒤 월매 집", "월매 집 대문", "해 질 무렵 → 밤", "곁에서 본다", "-", "wolmae_reunion_seen", [{ "call": "wolmae_reunion" }]),
		"C1601": _ev("C1601", "밤 외삼문 밖", "외삼문 → 옥(CAMERA 12A)", "밤", "거들거나 지켜본다",
			"관아 관계가 좋으면 포졸에게 거든다 / 아니면 월매가 다른 길로 — 어느 쪽이든 몽룡은 춘향을 만난다", "jail_reunion_seen · 단계 feast", [{ "call": "jail_reunion" }]),
		"C1701": _ev("C1701", "잔치 날 내삼문", "관아 안마당(잔치 — 차일 SPREAD)", "낮", "본다 · 걷는다", "-", "feast_seen", [{ "call": "feast_enter" }]),
		"C1702": _ev("C1702", "서쪽 줄 끝에 선다", "관아 안마당(가장자리 · CAMERA 17A)", "낮", "줄에서 본다(조작 그대로)", "-", "poem_done", [{ "call": "mong_enters" }]),
		"C1801": _ev("C1801", "시 뒤", "관아 안마당(공식 8A → CAMERA 18A)", "낮", "줄에서 본다 — 싸우지 않는다", "-",
			"royal_inspector_reveal · byeon_dismissed · 단계 reveal(같은 사람이 제자리에서 자세만)", [{ "call": "chuldu" }]),
		"C1901": _ev("C1901", "출두 뒤 몽룡이 묻는다", "관아 안마당 → 바깥마당", "낮", "본 것과 들은 것을 말한다",
			"말한 것(본 것/들은 것)에 따라 술값 · 쌀 반환 · 노인 재조사 — 처벌은 그대로", "restore_* · 단계 release", [{ "call": "restoration" }]),
		"C2001": _ev("C2001", "몽룡을 따라 옥문", "옥 → 바깥마당", "낮", "본다 · 춘향에게 답한다",
			"줄을 잡음 / 느슨하게 / 놓음 — 춘향이 기억한다(점수 없음)", "chunhyang_released · 단계 epilogue", [{ "call": "release" }]),
		"C2201": _ev("C2201", "며칠 뒤 광한루", "광한루 · 빈 그네", "낮", "지나간다", "-",
			"CASE_NAMWON_CHUNHYANG_OUTCOME RELEASED · CASE_NAMWON_CHUNHYANG_COMPLETE", [{ "call": "epilogue" }]),
	}
