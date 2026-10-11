# 사건 「남원의 약속」(남원 재방문, 춘향) PART I 「단오」 — 이야기 데이터.
# 시나리오: seolhwa/docs/scenario/seolhwarok_NAMWON_CHUNHYANG_v1.1_scenario.md(ACT 0~5, §3~§17) · 결정 _DECISIONS.md(§1 변수 넷 · §4 진입 · §7 배치 확정)
# 자산·좌표: seolhwa/docs/production/CHUNHYANG_ASSETS_PLACEMENT_v1.0.md · 차림(when)·군중·카메라: region_data/JL_NAMWON_UNBONG/placement_story_namwon_chunhyang.json
#
# 진입(결정 §4): CASE_NAMWON_COMPLETE && CASE_HANYANG_BOOKSHOP_COMPLETE — 한양을 다녀온 뒤 처음 남원에 돌아왔을 때(case_registry.choose가 오누이 다음으로 고른다).
#   귀환 이유는 다른 고을의 소문(rumors_data CH_DANO_*)과 전국 지도 붉은 표(map_leads ch_dano_return) — 강제하지 않는다.
# 단계(phase): dano(단오 낮 — ACT 0~2) → courtship(그날 저녁 ~ 백년가약 — ACT 3·4) → farewell(소식 · 오리정 곁 북쪽 길 이별 — ACT 5, PART I 끝 뒤에도 머문다).
#   PART I 끝: CASE_NAMWON_CHUNHYANG_PART1_COMPLETE. 그 뒤 남원을 실제로 떠나면(region_main._travel → story.on_leave_space) LEFT_AFTER_PART1.
#   PART II-A(namwon_chunhyang_p2a_data.gd): 열림(결정 §4) PART1_COMPLETE && LEFT_AFTER_PART1 && (강릉 || 경주 || 황주 완료) — 남원에 다시 들면 단계 arrival → office → jail.
#   II-B(술·쌀·상소, 몽룡 귀환 이후)는 아직 없다.
# 전역 변수는 넷뿐(결정 §1): CASE_NAMWON_CHUNHYANG_OUTCOME · _COMPLETE · _PART1_COMPLETE · _LEFT_AFTER_PART1. 사건 안 플래그는 접두사 없이.
# 플레이어는 춘향·몽룡의 핵심 행동을 대신하지 않는다. 호감도·점수 없음 — 선택은 플래그마다 따로 기억한다(vow_heard · vow_own · vow_nod 등).
# 오누이 뒤 남원 사람(주모·방앗간 주인·포수·이웃 아낙)은 여기서 같은 CHR·그림으로 다시 세운다 — F-10(비활성 사건 인물 층) 전 임시 조치. 오누이 흐름은 옮기지 않는다.
extends RefCounted

const P2 := preload("res://story/namwon_chunhyang/namwon_chunhyang_p2a_data.gd")   # PART II-A(새 사또 — 행차~옥의 첫 밤)
const JAR := "ITM_CH_JAR"        # 장면 소품(§10 작은 술병과 찬합) — 월매 집에 닿으면 내려놓는다
const LETTER := "ITM_CH_LETTER"  # 장면 소품(§13 A 봉한 편지 — 열 수 없다)

static func data() -> Dictionary:
	var out := {
		"case": {
			"id": "namwon_chunhyang", "record_title": "남원의 약속", "region": "JL_NAMWON_UNBONG",
			"EVENT_CLASS": "FOLKLORE_EVENT", "SOURCE_ID": "F50", "CATALOG_ID": "HN01", "ANCHOR_NOTE": "A01 춘향 계열(지역 고정 앵커)을 남원 재방문 주 사건으로 올린 원전 등록",
			"outcome_var": "CASE_NAMWON_CHUNHYANG_OUTCOME",
			"complete_key": "NAMWON_CHUNHYANG",
			"requires": { "CASE_NAMWON_COMPLETE": true, "CASE_HANYANG_BOOKSHOP_COMPLETE": true },
			"reset_vars": ["CASE_NAMWON_CHUNHYANG_OUTCOME", "CASE_NAMWON_CHUNHYANG_COMPLETE", "CASE_NAMWON_CHUNHYANG_PART1_COMPLETE", "CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1"],
			"rule_label": "알아 둔 것",
			"start_hour": 10.0,
			"start_event": "C0001", "start_on_arrival": true,   # 노정·역마로 와도 조용히 선다(컷신 없음 — 분위기만 바뀐다)
			"BASE_VERSION": "완판 84장본 「열녀춘향수절가」",
			"ENTRY": "단오날 광한루. 남원에 다시 들른 여행자가 군중 속에서 이몽룡·방자 일행을 우연히 만난다.",
			"CONTINUITY": "방자와 안면을 튼 뒤 몽룡·춘향 사이의 말과 편지를 한두 번 전하며 두 사람이 가까워지는 것을 곁에서 본다.",
			"FIXED_BEATS": [
				{ "id": "dano_swing", "text": "단오 광한루와 그네" },
				{ "id": "mong_sees", "text": "이몽룡이 춘향을 봄" },
				{ "id": "bangja_message", "text": "방자가 춘향에게 말을 전함" },
				{ "id": "first_meeting", "text": "몽룡과 춘향의 만남" },
				{ "id": "vow", "text": "백년가약" },
				{ "id": "farewell", "text": "몽룡의 한양행과 이별" },
				{ "id": "byeon_arrives", "text": "변학도 부임" },
				{ "id": "roll_call", "text": "기생 점고" },
				{ "id": "sucheong_demand", "text": "춘향에 대한 수청 요구" },
				{ "id": "refusal", "text": "춘향의 거절" },
				{ "id": "gonjang", "text": "곤장과 투옥" },
			],
			"GAME_ADAPTATION": "원전의 긴 시간을 며칠로 압축하고 '몇 달 후' 자막을 쓰지 않는다. 플레이어는 방자 곁의 외지인 — 심부름을 거들 뿐 춘향·몽룡의 선택을 대신하지 않는다. 연애 호감도·점수 없음.",
		},
		"items": { JAR: "작은 술병과 찬합", LETTER: "봉한 편지" },
		"hidden_items": [],
		"clues": {
			"dano": { "title": "단오장", "text": "남원에 단오장이 섰다. 광한루 앞 마당에 씨름판과 엿판, 버드나무 사이에 그네.", "kind": "fact" },
			"swing": { "title": "그네 탄 처녀", "text": "버드나무 사이 그네가 높이 올랐다 내려왔다. 다홍 치맛자락. 얼굴은 멀어서 보지 못했다.", "kind": "fact" },
			"name": { "title": "성춘향", "text": "그네를 탄 처녀는 성춘향. “남원에서 춘향 모르면 외지 사람이지요.”", "kind": "heard", "by": "방자" },
			"refusal": { "title": "춘향의 대답", "text": "“나는 관기 점고 나온 사람이 아니야. 보고 싶으면 본인이 말을 하라 그래.”", "kind": "heard", "by": "춘향" },
			"mong_laugh": { "title": "몽룡의 웃음", "text": "직접 말하라는 대답을 듣고 몽룡은 화내지 않았다. “재미있구나.”", "kind": "fact" },
			"wolmae_word": { "title": "월매의 말", "text": "“그 말을 그렇게 쉽게 하시면 안 됩니다.”", "kind": "heard", "by": "월매" },
			"sorry": { "title": "잘못했소", "text": "춘향이 사또 자제들은 원래 사람을 그렇게 부르느냐고 묻자 몽룡이 말했다. “잘못했소.”", "kind": "fact" },
			"letter": { "title": "봉한 편지", "text": "방자가 맡긴 편지를 춘향에게 전했다. 열어 보지 않았다.", "kind": "fact" },
			"walk": { "title": "오작교 곁", "text": "춘향과 몽룡이 오작교 곁을 함께 걸었다.", "kind": "fact" },
			"laugh": { "title": "담 너머 웃음", "text": "월매 집 담 너머에서 웃음소리가 났다.", "kind": "fact" },
			"vow": { "title": "백년가약", "text": "월매 집 마당. 몽룡 “어디에 있든 돌아오겠소.” 춘향 “그 말이면 됩니다.” 월매가 나를 증인으로 세웠다.", "kind": "fact" },
			"news": { "title": "한양행", "text": "몽룡의 아버지가 한양으로 올라간다. 몽룡도 따라가야 한다.", "kind": "heard", "by": "방자" },
			"farewell": { "title": "오리정 곁 북쪽 길", "text": "몽룡은 몇 번 뒤를 돌아보며 북쪽으로 갔다. 춘향은 따라가지 않았다. “믿으니 기다리는 겁니다.”", "kind": "fact" },
		},
		"rules": {},
		"anchors": anchors(),
		"map_places": [
			{ "id": "gwanghallu", "name": "광한루", "at": "ch_gwanghallu", "building": true, "radius": 26.0, "known": "f('case_started')" },
			{ "id": "wolmae_house", "name": "월매 집", "at": "ch_wolmae_house", "building": true, "radius": 10.0, "known": "f('evening_call')" },
		],
		# 지도 붉은 표 — 아는 곳만. 오리정(이별 길)에는 표를 두지 않는다(결정 §7-5: 배경 랜드마크만)
		"map_leads": [
			{ "id": "ch_dano_return", "name": "남원 단오장", "region": "JL_NAMWON_UNBONG", "when": "true", "until": "f('case_started')",
				"note": "한양 뒤 다른 고을 소문 “남원 단오장이 크게 선다더라”(rumors CH_DANO_*) — 강제하지 않는다" },
			{ "id": "ch_gwanghallu", "name": "광한루 단오 마당", "at": "ch_gwanghallu", "hub": true, "when": "f('case_started')", "until": "f('errand_choice')",
				"note": "§4 광한루 진입 — 1A" },
			{ "id": "ch_swing_lead", "name": "그네 — 방자가 간 곳", "at": "ch_swing_land", "when": "f('errand_choice') and not f('errand_with')", "until": "f('refusal_seen')",
				"note": "§7 같이 가지 않으면 방자를 나중에 춘향 근처에서 만난다" },
			{ "id": "ch_mong_lead", "name": "광한루 앞 — 몽룡", "at": "ch_gwanghallu_front", "when": "f('refusal_seen')", "until": "f('mong_reacted')",
				"note": "§9 몽룡에게 돌아감" },
			{ "id": "ch_wolmae_lead", "name": "월매 집", "at": "ch_wolmae_gate", "when": "f('evening_call')", "until": "f('first_meeting_done')",
				"note": "§10 방자 “이것 좀 같이 들고 갑시다”" },
			{ "id": "ch_bangja_letter", "name": "광한루 — 방자", "at": "ch_gwanghallu_front", "when": "f('first_meeting_done')", "until": "f('letter_asked')",
				"note": "§13 장면 A — 방자의 편지 부탁" },
			{ "id": "ch_letter_lead", "name": "월매 집 — 춘향", "at": "ch_wolmae_gate", "when": "f('letter_asked')", "until": "f('letter_delivered')",
				"note": "§13 장면 A — 편지 전하기" },
			{ "id": "ch_bangja_again", "name": "광한루 — 방자", "at": "ch_gwanghallu_front", "when": "f('walk_seen')", "until": "f('vow_invited')",
				"note": "§13 뒤 — 방자가 밤에 월매 집으로 부른다" },
			{ "id": "ch_vow_lead", "name": "월매 집(밤)", "at": "ch_wolmae_gate", "when": "f('vow_invited')", "until": "f('vow_done')",
				"note": "§14 백년가약" },
		],
		"journal": {
			"unknowns": [
				{ "text": "그네를 탄 처녀는 누구인가.", "when": "c('swing')", "until": "c('name')" },
				{ "text": "몽룡은 춘향을 다시 만날까.", "when": "c('refusal')", "until": "f('first_meeting_done')" },
				{ "text": "한양으로 간 몽룡은 돌아올까.", "when": "f('part1_done')", "until": "false" },
				{ "text": "새 사또는 춘향을 어떻게 할 셈인가.", "when": "c('bring_her')", "until": "f('jailed')" },
				{ "text": "춘향은 옥에서 얼마나 버틸까.", "when": "f('jailed')", "until": "false" },
			],
			"places": [
				{ "name": "광한루", "when": "f('case_started')" }, { "name": "그네(광한루원 북서)", "when": "c('swing')" },
				{ "name": "월매 집", "when": "f('evening_call')" }, { "name": "오작교", "when": "c('walk')" }, { "name": "오리정 곁 북쪽 길", "when": "c('farewell')" },
				{ "name": "남원 관아", "when": "f('labour_started')" }, { "name": "옥(관아 바깥마당 서쪽)", "when": "f('jailed')" },
			],
		},
		"actors": actors(),
		"objects": objects(),
		"triggers": triggers(),
		"props": props(),
		"events": events(),
	}
	# PART II-A를 잇는다(같은 사건 — 단계 arrival · office · jail)
	out.items.merge(P2.items())
	out.clues.merge(P2.clues())
	out.map_places = P2.map_places() + out.map_places
	out.map_leads = P2.map_leads() + out.map_leads
	out.actors += P2.actors()
	out.triggers += P2.triggers()
	out.props += P2.props()
	out.events.merge(P2.events())
	return out

static func anchors() -> Dictionary:
	var a := {
		# 광한루·단오 마당(placement_story_namwon_chunhyang.json anchors와 같은 값)
		"ch_gwanghallu": [-3271.4, 450.1], "ch_gwanghallu_front": [-3271.4, 437.0], "ch_mong_view": [-3291.0, 447.5],
		"ch_bangja_bump": [-3264.0, 432.0], "ch_fan_drop": [-3264.6, 432.4], "ch_swing": [-3330.0, 444.0], "ch_swing_land": [-3325.0, 438.5], "ch_hyangdan": [-3327.6, 439.2],
		"ch_ssireum": [-3292.0, 431.0], "ch_market": [-3290.0, 392.5], "ch_ojakgyo": [-3283.4, 459.4],
		# 1A 들머리(동쪽 길목 C구역 — 군중 앞) · 방자 등장 자리
		"ch_vista_in": [-3250.0, 446.0], "ch_bangja_from": [-3259.5, 428.6], "ch_mong_wait": [-3270.0, 436.2], "ch_bangja_wait": [-3268.2, 435.6],
		# §6 1B 자리: 몽룡 뒤 플레이어·방자
		"ch_1b_player": [-3287.6, 450.0], "ch_1b_bangja": [-3288.6, 446.0],
		# §8 2A: 그네에서 내려온 춘향 · 방자 · 플레이어(프레임 옆)
		"ch_chun_land": [-3325.4, 440.0], "ch_bangja_swing": [-3323.4, 438.6], "ch_player_swing": [-3321.8, 437.2], "ch_chun_leave": [-3302.0, 453.5],
		# 월매 집(nw_house_158 — 결정 §7-3)
		"ch_wolmae_house": [-3212.99, 449.82], "ch_wolmae_yard": [-3213.0, 451.0], "ch_wolmae_gate": [-3213.0, 457.2], "ch_wolmae_front": [-3216.0, 459.8],
		"ch_wolmae_at_gate": [-3212.4, 458.2], "ch_bangja_gate": [-3216.2, 460.0], "ch_player_gate": [-3215.0, 461.8], "ch_mong_road": [-3229.0, 462.0], "ch_mong_gate": [-3214.0, 459.6],
		"ch_chun_gate": [-3210.9, 458.5], "ch_wolmae_aside": [-3213.4, 457.7], "ch_chun_yard": [-3212.2, 451.6], "ch_hyang_yard": [-3210.6, 452.4], "ch_wolmae_in": [-3214.2, 452.0],
		# §14 마당(밤)
		"ch_vow_mong": [-3214.3, 451.2], "ch_vow_chun": [-3212.1, 451.2], "ch_vow_wolmae": [-3213.2, 449.6], "ch_vow_bangja": [-3215.8, 453.6], "ch_vow_player": [-3211.2, 454.0],
		# §13 장면 B 오작교 곁 길
		"ch_walk_a": [-3292.0, 461.0], "ch_walk_b": [-3276.0, 458.0], "ch_walk_mong_a": [-3293.0, 461.6], "ch_walk_mong_b": [-3277.2, 458.8],
		# §16·§17 오리정 곁 북쪽 길(오리정 ti_orijeong (-3205.8, -10)은 배경만)
		"ch_farewell_follow": [-3211.6, 4.0], "ch_farewell_bangja": [-3210.2, 4.6], "ch_farewell_stand": [-3212.3, -6.0], "ch_farewell_mong": [-3212.7, -14.0],
		"ch_farewell_vanish": [-3223.5, -60.0], "ch_farewell_far": [-3215.0, -36.0],
		# 오누이 뒤 남원 사람(namwon_data와 같은 자리 — F-10 전 임시)
		"jumo": [-3001.0, 227.6], "miller": [-3179.6, -313.4], "hunter": [-3192.5, -133.5], "neighbor_after": [-3203.0, -127.5],
	}
	# 배치 파일의 PART II 앵커(관아·사령 줄·기생 줄·옥 — 같은 값을 두 번 적지 않음) · II-A 연출 자리. 이미 있는 이름은 PART I 값이 이긴다
	for src in [P2.placement_anchors(), P2.anchors()]:
		for k in src:
			if not a.has(k): a[k] = src[k]
	return a

# ---------------------------------------------------------------------------
# 인물 — 고유 그림(frames_story_namwon_chunhyang.json): chunhyang · hyangdan · wolmae · mongryong · bangja
# ---------------------------------------------------------------------------
static func actors() -> Array:
	return [
		{ "id": "bangja", "chr": "CHR_CH_BANGJA", "kind": "bangja", "name": "방자",
			"at": { "dano": "ch_bangja_wait", "courtship": "ch_gwanghallu_front", "default": "ch_gwanghallu_front" }, "facing": "down",
			"when": "(f('bump_done') or not ph('dano')) and not f('bangja_off')",
			"talk": [
				{ "when": "f('walk_seen') and not f('vow_invited')", "steps": [{ "event": "C0402" }] },
				{ "when": "f('vow_invited') and not f('vow_done')", "steps": [{ "call": "vow_wait_offer" }] },
				{ "when": "f('first_meeting_done') and not f('letter_asked')", "steps": [{ "event": "C0401" }] },
				{ "when": "f('letter_asked') and not f('letter_delivered')", "steps": [{ "say": "방자", "lines": ["춘향이는 월매 집에 있을 거요. 편지는 손에서 손으로."] }] },
				{ "when": "f('letter_delivered') and not f('walk_seen')", "steps": [{ "say": "방자", "lines": ["전했소? 도련님은 아까 오작교 쪽으로 나가셨소."] }] },
				{ "when": "f('evening_call') and not f('first_meeting_done')", "steps": [{ "say": "방자", "lines": ["월매 집은 광한루 동쪽, 나루 주막 가는 길에 있소. 같이 갑시다."] }] },
				{ "when": "f('refusal_seen') and not f('mong_reacted')", "steps": [{ "say": "방자", "lines": ["도련님께 가서 뭐라고 해야 하나…"] }] },
				{ "when": "f('errand_choice') and not f('refusal_seen')", "steps": [{ "say": "방자", "lines": ["그네 쪽으로 가 보시오. 나도 곧 가오."] }] },
				{ "when": "true", "steps": [{ "say": "방자", "lines": ["오늘은 사람이 많아 발 디딜 데가 없소."] }] },
			] },
		{ "id": "mongryong", "chr": "CHR_CH_MONGRYONG", "kind": "mongryong", "name": "몽룡",
			"at": { "dano": "ch_mong_wait", "default": "ch_gwanghallu_front" }, "facing": "down",
			"when": "f('mong_on') or (ph('dano') and f('bump_done') and not f('mong_off'))",
			"talk": [
				{ "when": "f('refusal_seen') and not f('mong_reacted')", "steps": [{ "event": "C0204" }] },
				{ "when": "true", "steps": [{ "say": "몽룡", "lines": ["단오라 남원이 다 나온 것 같구나."] }] },
			] },
		{ "id": "chunhyang", "chr": "CHR_CH_CHUNHYANG", "kind": "chunhyang", "name": "춘향",
			"at": { "dano": "ch_chun_land", "courtship": "ch_chun_yard", "farewell": "ch_chun_yard", "default": "ch_chun_yard" }, "facing": "down",
			"when": "(ph('dano') and not f('chun_left_swing')) or (ph('courtship') and (f('first_meeting_done') or f('chun_on'))) or ph('farewell') or ((ph('arrival') or ph('office')) and f('chun_on'))",
			"talk": [
				{ "when": "f('escorting')", "steps": [{ "say": "춘향", "lines": ["…가요."] }] },
				{ "when": "f('escort_jail')", "steps": [{ "say": "춘향", "lines": ["…"] }] },
				{ "when": "f('farewell_scene_done') and not f('farewell_talked')", "steps": [{ "event": "C0503" }] },
				{ "when": "ph('farewell') and f('farewell_talked')", "steps": [{ "say": "춘향", "lines": ["…"] }] },
				{ "when": "f('letter_asked') and not f('letter_delivered') and has('%s')" % LETTER, "steps": [{ "event": "C0403" }] },
				{ "when": "f('letter_delivered')", "steps": [{ "say": "춘향", "lines": ["어머니는 안에 계세요."] }] },
				{ "when": "true", "steps": [{ "say": "춘향", "lines": ["볼일 있으세요?"] }] },
			] },
		{ "id": "hyangdan", "chr": "CHR_CH_HYANGDAN", "kind": "hyangdan", "name": "향단",
			"at": { "dano": "ch_hyangdan", "default": "ch_hyang_yard" }, "facing": "right",
			"when": "(ph('dano') and not f('chun_left_swing')) or (ph('courtship') and f('first_meeting_done')) or ph('farewell') or ph('arrival') or ph('office') or ph('jail')",
			"talk": [
				{ "when": "ph('jail')", "steps": [{ "say": "향단", "lines": ["마님이 밥을 지으셨어요. 들여보내 주기나 할는지."] }] },
				{ "when": "ph('office') and f('wolmae_summoned')", "steps": [{ "say": "향단", "lines": ["아가씨가 스스로 가셨어요. 마님은 말도 안 하세요."] }] },
				{ "when": "ph('arrival') or ph('office')", "steps": [{ "say": "향단", "lines": ["관아에서 사람이 자꾸 와요. 쌀이며 술이며 내놓으라고."] }] },
				{ "when": "ph('farewell') and f('part1_done')", "steps": [{ "say": "향단", "lines": ["아가씨는 요즘 말수가 적어요."] }] },
				{ "when": "ph('dano')", "steps": [{ "say": "향단", "lines": ["아가씨 그네 타시는 거 보러 왔어요? 다들 그래요."] }] },
				{ "when": "true", "steps": [{ "say": "향단", "lines": ["마님 찾으세요?"] }] },
			] },
		{ "id": "wolmae", "chr": "CHR_CH_WOLMAE", "kind": "wolmae", "name": "월매",
			"at": { "default": "ch_wolmae_in" }, "facing": "down",
			"when": "(ph('courtship') and (f('first_meeting_done') or f('wolmae_on'))) or ph('farewell') or ph('arrival') or ph('office') or (ph('jail') and not f('p2a_done'))",
			"talk": [
				{ "when": "ph('jail') and f('dismissed') and not f('food_scene')", "steps": [{ "say": "월매", "lines": ["밥도 못 먹게 할 셈이오?"] }] },
				{ "when": "ph('jail')", "steps": [{ "say": "월매", "lines": ["…"] }] },
				{ "when": "ph('office') and f('wolmae_summoned')", "steps": [{ "say": "월매", "lines": ["…가 보시오. 그 아이 따라."] }] },
				{ "when": "ph('arrival') or ph('office')", "steps": [{ "say": "월매", "lines": ["새 사또가 왔다지요. 잔치 준비한다고 동네가 다 시끄럽소."] }] },
				{ "when": "ph('farewell') and f('part1_done')", "steps": [
					{ "say": "월매", "lines": ["그 도련님 말, 길손도 들었지요."] },
					{ "say": "월매", "lines": ["들은 사람이 있으니 됐소."], "when": "f('vow_heard') or f('vow_nod')" },
					{ "say": "월매", "lines": ["두 사람이 지킬 일이라 했지요. 맞는 말이오."], "when": "f('vow_own')" }] },
				{ "when": "f('vow_invited') and not f('vow_done')", "steps": [{ "say": "월매", "lines": ["해 지면 오시오. 길손 양반도 들어야 할 말이 있소."] }] },
				{ "when": "true", "steps": [{ "say": "월매", "lines": ["우리 춘향이 일로 오셨소?"] }] },
			] },
		# ---- 오누이 뒤 남원 사람(같은 CHR·그림, 사건 뒤 말만 — F-10 전 임시 조치) ----
		{ "id": "jumo", "chr": "CHR_HUM_015", "kind": "innkeeper", "name": "주모", "at": "jumo", "facing": "down",
			"talk": [
				{ "when": "ph('dano') or ph('courtship')", "steps": [{ "say": "주모", "lines": ["북쪽 길은 다시 사람들이 다니오.", "단오라 광한루 쪽이 북새통이오. 장꾼들이 다 그리로 갔소."] }] },
				{ "when": "true", "steps": [{ "say": "주모", "lines": ["북쪽 길은 다시 사람들이 다니오."] }] },
			] },
		{ "id": "miller", "chr": "CHR_HUM_009", "kind": "miller", "name": "방앗간 주인", "at": "miller", "facing": "down",
			"talk": [{ "when": "true", "steps": [{ "say": "방앗간 주인", "lines": ["요샌 자루 찢기는 일이 없소. 밤에 잠을 좀 자오."] }] }] },
		{ "id": "hunter", "chr": "CHR_HUM_017", "kind": "hunter", "name": "포수", "at": "hunter", "facing": "down",
			"talk": [{ "when": "true", "steps": [{ "say": "포수", "lines": ["고개 쪽은 조용하오. 그놈 뒤로는 큰 짐승 자국이 없어."] }] }] },
		{ "id": "neighbor", "chr": "CHR_HUM_010", "kind": "villager_f", "name": "이웃 아낙", "at": "neighbor_after", "facing": "down",
			# 남원 v3.2 §64 아침의 대답(CASE_NAMWON_MORNING)을 기억한다 — 오누이 데이터와 같은 줄
			"talk": [
				{ "when": "v('CASE_NAMWON_MORNING') == 'sky'", "steps": [{ "say": "이웃 아낙", "lines": ["그날 하늘로 올라갔다고 하셨지요… 아직도 무슨 뜻인지 모르겠소."] }] },
				{ "when": "v('CASE_NAMWON_MORNING') == 'unknown'", "steps": [{ "say": "이웃 아낙", "lines": ["혹시 어디서라도 아이들 소식 들으면 알려 주시오."] }] },
				{ "when": "v('CASE_NAMWON_MORNING') == 'silent'", "steps": [{ "say": "이웃 아낙", "lines": ["그날은 아무 말씀도 안 하셨지요."] }] },
				{ "when": "true", "steps": [{ "say": "이웃 아낙", "lines": ["그 집은 아직 비어 있어요. 가끔 들여다보고 와요."] }] }] },
	] + guard_posts()

# ---------------------------------------------------------------------------
# PART II 고정 자리 — 사령·포졸(CHR_HUM_016, 그림 pojol). 공식 8A 양옆 줄(placement_story_namwon_chunhyang.json의 ch_saryeong_*)에
# 선다. PART II 단계(office 점고·수청·곤장 · feast 잔치 · reveal 출두)에서만. II-A(namwon_chunhyang_p2a.gd)는 곤장 때 몇을 옮겼다가 제자리로 돌린다.
# 출두(II-B) 때 자세 바꾸기는 story_director.set_pose("saryeong", "kneel")(같은 인물, 제자리).
# 서쪽 줄은 축(동쪽)을, 동쪽 줄은 서쪽을 본다. 플레이어 자리(ch_player_saryeong)는 인물이 아니다. 외삼문 포졸 하나(§30·§38).
# ---------------------------------------------------------------------------
const GUARD_WHEN := "ph('office') or ph('feast') or ph('reveal')"
static func guard_posts() -> Array:
	var out := []
	for side in ["w", "e"]:
		for i in 4:
			out.append({ "id": "saryeong_%s%d" % [side, i], "chr": "CHR_HUM_016", "kind": "pojol", "name": "사령",
				"at": "ch_saryeong_%s%d" % [side, i], "facing": "right" if side == "w" else "left", "when": GUARD_WHEN,
				"tags": ["saryeong", "row_" + side], "accent": false })
	out.append({ "id": "saryeong_senior", "chr": "CHR_HUM_016", "kind": "pojol", "name": "선임 사령", "at": "ch_saryeong_e4", "facing": "left",
		"when": GUARD_WHEN, "tags": ["saryeong", "row_e", "senior"], "accent": false })
	out.append({ "id": "pojol_gate", "chr": "CHR_HUM_016", "kind": "pojol", "name": "포졸", "at": "ch_gate_guard", "facing": "down",
		"when": "ph('office') or ph('jail') or ph('feast')", "tags": ["pojol"], "accent": false })
	return out

static func objects() -> Array:
	return []

# ---------------------------------------------------------------------------
# 자리 트리거
# ---------------------------------------------------------------------------
static func triggers() -> Array:
	return [
		# §4 광한루 축제 구역 반경 — 1A(카메라가 바로 춘향을 잡지 않는다)
		{ "id": "c0101_vista", "at": "ch_gwanghallu", "radius": 46.0, "when": "ph('dano') and not f('vista_seen')", "event": "C0101" },
		# §5 군중 사이 — 방자와 부딪힘
		{ "id": "c0102_bump", "at": "ch_bangja_bump", "radius": 9.0, "when": "ph('dano') and f('vista_seen') and not f('bump_done')", "event": "C0102" },
		# §8 같이 가지 않았으면 방자를 나중에 춘향 근처에서
		{ "id": "c0202_swing", "at": "ch_swing_land", "radius": 9.0, "when": "ph('dano') and f('errand_choice') and not f('refusal_seen')", "event": "C0202" },
		# §9 몽룡에게 돌아감(가까이 가면 — 말 걸기로도)
		{ "id": "c0204_mong", "at": "ch_gwanghallu_front", "radius": 6.5, "when": "ph('dano') and f('refusal_seen') and not f('mong_reacted')", "event": "C0204" },
		# §11 월매 집 앞(술병·찬합을 들고)
		{ "id": "c0302_wolmae", "at": "ch_wolmae_front", "radius": 6.0, "when": "ph('courtship') and f('evening_call') and not f('first_meeting_done')", "event": "C0302" },
		# §13 장면 B — 오작교 곁을 함께 걷는 두 사람(대사 없음)
		{ "id": "c0404_walk", "at": "ch_ojakgyo", "radius": 34.0, "when": "ph('courtship') and f('letter_delivered') and not f('walk_seen') and not fn('is_night')", "event": "C0404" },
		# §13 장면 C — 월매 집 앞을 지나면 웃음소리(상호작용 필수 아님)
		{ "id": "c0405_laugh", "at": "ch_wolmae_front", "radius": 11.0, "when": "ph('courtship') and f('letter_delivered') and not f('vow_invited') and not fn('is_night')", "steps": [
			{ "flag": "laugh_heard" }, { "sfx": "laugh_far", "at": "ch_wolmae_yard" }, { "clue": "laugh", "quiet": true },
			{ "caption": "담 너머에서 웃음소리가 난다.", "sec": 1.8 }] },
		# §14 밤 월매 집 마당
		{ "id": "c0406_vow", "at": "ch_wolmae_front", "radius": 7.0, "when": "ph('courtship') and f('vow_invited') and not f('vow_done') and fn('is_night')", "event": "C0406" },
	]

# ---------------------------------------------------------------------------
# 소품 — 방자가 떨어뜨린 부채(§5)
# ---------------------------------------------------------------------------
static func props() -> Array:
	return [
		{ "id": "p_fan", "kit": "story/chunhyang", "params": { "kind": "fan" }, "at": "ch_fan_drop", "dy": 0.0, "ry": 0.7,
			"when": "f('fan_dropped') and not f('fan_picked')" },
	]

# ---------------------------------------------------------------------------
# 사건 장면 — FOLKLORE_EVENT F50(춘향, 카탈로그 HN01 · 지역 앵커 A01)
# ---------------------------------------------------------------------------
static func _ev(id: String, trigger: String, loc: String, tw: String, actions: String, branches: String, wsc: String, steps: Array) -> Dictionary:
	return {
		"EVENT_ID": id, "EVENT_CLASS": "FOLKLORE_EVENT", "RECORD_TITLE": "남원의 약속", "SOURCE_ID": "F50", "CATALOG_ID": "HN01",
		"SOURCE_TITLE_INTERNAL": "춘향전(열녀춘향수절가)", "SOURCE_TYPE": "pansori_novel", "SOURCE_REGION_GRADE": "A",
		"SOURCE_REGION_NOTE": "남원 고정 전승(지역 앵커 A01 춘향 계열 — 광한루·오작교·관아·옥). 완판 84장본을 기준으로 단오~이별(PART I)을 화면에서 그대로 겪는다(DIRECT).",
		"ADAPTATION_MODE": "DIRECT", "TRIGGER": trigger, "LOCATION_TYPE": loc, "TIME_WEATHER": tw,
		"PLAYER_ACTIONS": actions, "RESOLUTION_BRANCHES": branches, "WORLD_STATE_CHANGE": wsc, "SOURCE_VERIFIED": true,
		"steps": steps,
	}

static func events() -> Dictionary:
	return {
		# ACT 0 §3 — 다시 온 남원(조용히 선다: 컷신 없음, 단오 차림·군중·밝은 음악은 단계 dano의 when으로)
		"C0001": _ev("C0001", "CASE_NAMWON_COMPLETE && CASE_HANYANG_BOOKSHOP_COMPLETE, 그 뒤 처음 남원", "남원 권역 어디든(도착)", "낮 · 맑음",
			"남원을 걷는다", "-", "단오 차림(광한루·장터 둘레) · 단오 군중 28 · 밝은 음악", [
			{ "phase": "dano" }, { "call": "start_case" },
		]),
		# ACT 1 §4 CAMERA 1A
		"C0101": _ev("C0101", "광한루 축제 구역 반경", "광한루 · 단오 마당", "낮", "본다", "-", "-", [
			{ "call": "vista_1a" },
		]),
		# §5~§7 방자와 부딪힘 · 부채 · 그네(1B) · 심부름
		"C0102": _ev("C0102", "1A 뒤 군중 사이를 지남", "광한루 앞 잔디", "낮", "부채를 주워 주거나 그냥 지나간다 · 알아보는 말에 답한다 · 심부름에 같이 갈지 고른다",
			"주워 줌(맞소/사람 잘못 봤소/대답 없음) · 지나감 / 같이 감 · 혼자 가시오 · 더 본다", "-", [
			{ "call": "bump" },
			{ "call": "swing_1b" },
			{ "call": "errand" },
		]),
		# §8 춘향(2A) — 같이 가면 바로, 아니면 그네 곁에 닿을 때
		"C0202": _ev("C0202", "방자를 따라(또는 나중에) 그네 곁", "광한루원 북서 그네", "낮", "곁에서 본다", "-", "-", [
			{ "call": "refusal" },
		]),
		# §9 몽룡에게 돌아감 → §10 저녁 방자의 심부름
		"C0204": _ev("C0204", "춘향의 대답 뒤 광한루 앞", "광한루 앞", "낮 → 해 질 무렵", "곁에서 듣는다 · 술병과 찬합을 받아 든다", "-", "단계 courtship", [
			{ "call": "mong_reacts" },
			{ "call": "evening_call" },
		]),
		# §11·§12 월매 집
		"C0302": _ev("C0302", "술병·찬합을 들고 월매 집 앞", "월매 집(nw_house_158) 대문", "해 질 무렵", "곁에서 본다", "-", "-", [
			{ "call": "wolmae_house" },
		]),
		# §13 며칠의 압축 — A 편지 부탁 / A 편지 전함 / B 함께 걷는 두 사람
		"C0401": _ev("C0401", "다음 날 광한루 앞 방자", "광한루 앞", "낮", "편지를 받는다(열 수 없다)", "-", "-", [
			{ "flag": "letter_asked" },
			{ "say": "방자", "lines": ["길손, 하나만 더 부탁합시다."] },
			{ "say": "방자", "lines": ["도련님이 이걸 춘향이한테 꼭 손으로 전하래요. 나는 사또 댁에 불려 가야 해서."] },
			{ "give": LETTER },
			{ "examine": "봉한 편지", "text": ["단단히 봉했다. 겉에는 아무것도 적혀 있지 않다.", "남의 편지다. 열어 볼 일은 아니다."], "kind": "item" },
			{ "say": "방자", "lines": ["월매 집이오. 대답은 안 받아 와도 되오."] },
		]),
		"C0403": _ev("C0403", "편지를 들고 춘향에게", "월매 집 마당", "낮", "편지를 전한다", "-", "-", [
			{ "say": "나그네", "lines": ["방자가 전해 달라 하오."] },
			{ "take": LETTER },
			{ "flag": "letter_delivered" },
			{ "say": "춘향", "lines": ["고맙습니다."] },
			{ "clue": "letter", "quiet": true },
			{ "journal": "방자의 편지를 춘향에게 전했다(열어 보지 않았다)" },
		]),
		"C0404": _ev("C0404", "편지를 전한 뒤 오작교 곁", "오작교 곁 길", "낮", "본다(대사 없음)", "-", "-", [
			{ "call": "walk_together" },
		]),
		"C0402": _ev("C0402", "함께 걷는 두 사람을 본 뒤 방자", "광한루 앞", "낮", "밤에 월매 집으로 오라는 말을 듣는다", "-", "-", [
			{ "flag": "vow_invited" },
			{ "say": "방자", "lines": ["길손, 오늘 밤 월매 집에 좀 와 주시오."] },
			{ "say": "방자", "lines": ["월매가 길손 양반도 꼭 오라 합디다. 무슨 일인지는 나도 모르오."] },
			{ "call": "vow_wait_offer" },
		]),
		# §14 백년가약(밤 · 월매 집 마당)
		"C0406": _ev("C0406", "밤, 월매 집 마당", "월매 집 마당", "밤 · 등롱", "증인으로 듣는다 · 월매에게 답한다", "들었습니다 / 두 분 말은 두 분이 지킬 일입니다 / 말없이 고개를 끄덕인다",
			"vow_witness(+ vow_heard · vow_own · vow_nod) — 결과는 같고 월매의 믿음만 다르다", [
			{ "call": "vow" },
		]),
		# §15 소식 → §16·§17 오리정 곁 북쪽 길(CAMERA 5A) → PART I 끝
		"C0501": _ev("C0501", "백년가약 다음 날 아침", "월매 집 앞 → 오리정 곁 북쪽 길", "낮", "곁에서 본다", "-",
			"단계 farewell · CASE_NAMWON_CHUNHYANG_PART1_COMPLETE", [
			{ "call": "news" },
			{ "call": "farewell" },
		]),
		"C0503": _ev("C0503", "몽룡이 시야에서 사라진 뒤 춘향에게 말을 건다", "오리정 곁 북쪽 길", "낮", "말을 건다", "기다리실 겁니까? / 한양은 멉니다 / 아무 말 하지 않는다", "-", [
			{ "flag": "farewell_talked" },
			{ "choice": "", "options": [
				{ "label": "기다리실 겁니까?", "id": "wait", "do": [{ "flag": "farewell_ask_wait" }, { "say": "춘향", "lines": ["약속했으니까요."] }] },
				{ "label": "한양은 멉니다.", "id": "far", "do": [{ "flag": "farewell_ask_far" }, { "say": "춘향", "lines": ["먼 길인 건 압니다."] }] },
				{ "label": "(아무 말 하지 않는다)", "id": "silent", "do": [{ "flag": "farewell_silent" }, { "say": "춘향", "lines": ["…가세요."] }] }] },
			{ "call": "chun_goes_home" },
		]),
	}
