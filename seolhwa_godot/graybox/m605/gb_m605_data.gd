# 회색 상자 시험 — M605 「안의 차례, 밖의 자리」(최종 퍼즐). 본편에 합치지 않는다(--graybox=m605 로만 선다).
#   기준: 메인 대본 v2.2(seolhwa/docs/scenario/seolhwarok_main_full_playable_script_v2_draft.md) M504·M505·M506·M507-N·M605 +
#   사용자 결정(2026-10-19): 홈 하나씩 두드려 맞히기(최대 세 번 찍기) 대신 — 세 홈의 차례를 추론해 '해석 전체'를 한 번에 확인한다.
#     ① 밖의 세 홈(C-1/2/3 — M504 탁본 노트의 높이·뿌리·비탈 특징)과 이겸의 안쪽 기록(반복해 걸은 차례 + 아이의 '마지막 돌' 진술)을 견준다
#     ② 세 홈에 첫째·둘째·셋째를 정한다 ③ 정한 차례대로 세 홈을 두드려 묻는다 — 이겸이 두 번(맞다)/한 번(아니다)
#     ④ 맞으면 마지막 홈의 활성 숯 획을 E 길게 눌러 지운다
#   찍기(여섯 차례)를 막지는 않는다. 대신 확인마다 이겸이 기운을 모으는 실제 시간이 들고(점점 길어짐), 피로가 보이며,
#   틀리면 '아니다'만이 아니라 어긋난 기록 한 줄을 다시 보여 준다. 정답을 강조색으로 알려 주지 않는다.
# 자리: 남원 권역 숲속 빈터(namwon_data 'territory' — 평지, 사건 없음). 임시 상자·글자만(최종 그림·연출·소리 없음).
extends RefCounted

const OX := -3275.0
const OZ := -395.0
static func P(x: float, z: float) -> Array: return [OX + x, OZ + z]

# 홈(밖의 이름 → 실제 특징). 밖의 번호는 비탈을 바깥에서 본 왼쪽→오른쪽 자리일 뿐 차례가 아니다.
const GROOVES := {
	"C1": { "name": "C-1", "feat": "step", "x": -4.0, "z": -5.0, "lift": 0.0 },
	"C2": { "name": "C-2", "feat": "moss", "x": 0.0, "z": -5.6, "lift": 0.0 },
	"C3": { "name": "C-3", "feat": "root", "x": 4.0, "z": -5.0, "lift": 0.7 },
}
const ORDER_IDS := ["C1", "C2", "C3"]
# 안쪽 기록이 정하는 차례(특징으로): 뿌리 → 돌턱 → 이끼(기운 돌) → 다시 움막 앞
const TRUE_FEATS := ["root", "step", "moss"]
# 기록의 상대 차례 조건 — [앞, 뒤, 그 조건을 적은 기록 단서 id]. 둘이면 셋의 차례가 하나로 정해진다
const RELATIONS := [["root", "step", "in_day1"], ["step", "moss", "in_day3"]]
const RANK_LABEL := ["첫째", "둘째", "셋째"]

# 확인 비용(실제 시간, 초): 이겸이 기운을 모으는 동안 — n번째 확인 = BASE + STEP×(n−1)
const PAUSE_BASE := 8.0
const PAUSE_STEP := 16.0
const ENERGY_MAX := 6
const ERASE_HOLD := 2.5   # 숯 획 지우기: E를 누르고 있는 시간
const ERASE_GRACE := 1.2  # 손을 떼도 이만큼은 문지른 만큼이 남는다

static func data() -> Dictionary:
	return {
		"case": {
			"id": "gb_m605", "record_title": "회색 상자 M605 — 안의 차례, 밖의 자리", "region": "JL_NAMWON_UNBONG",
			"EVENT_CLASS": "MAIN_FRAME", "SOURCE_ID": "MAIN_FRAME_GRAYBOX_M605", "outcome_var": "CASE_GB_M605_OUTCOME", "complete_key": "GB_M605",
			"requires": {}, "start_hour": 7.0, "start_event": "GB0", "rule_label": "알아 둔 것",
			"reset_vars": ["CASE_GB_M605_OUTCOME", "CASE_GB_M605_COMPLETE"],
		},
		"items": {},
		"clues": clues(),
		"rules": {},
		"anchors": anchors(),
		"actors": [],
		"objects": objects(),
		"triggers": [],
		"props": [],
		"journal": {
			"unknowns": [
				{ "text": "세 홈 가운데 안쪽 기록의 첫째·둘째·셋째는 각각 어느 것인가", "until": "f('GB_CONFIRMED')" },
				{ "text": "아이가 '마지막 돌'에 더한 획은 어느 홈의 것인가", "until": "f('GB_DONE')" },
			],
		},
		"events": {
			"GB0": _ev("GB0", [{ "call": "begin" }]),
		},
	}

static func _ev(id: String, steps: Array) -> Dictionary:
	return {
		"EVENT_ID": id, "EVENT_CLASS": "MAIN_FRAME", "RECORD_TITLE": "회색 상자 M605", "SOURCE_ID": "MAIN_FRAME_GRAYBOX_M605",
		"MAIN_FRAME_ORIGIN_NOTE": "회색 상자 시험(메인 대본 v2.2 M605) — 창작 메인 프레임. 본편 아님.",
		"FOLKLORE_ECHO_IDS": [], "FOLKLORE_ANCHOR_IDS": [], "FOLKLORE_ANCHOR_MODE": "",
		"TRIGGER": "--graybox=m605", "LOCATION_TYPE": "시험 빈터", "TIME_WEATHER": "7일 07:00", "PLAYER_ACTIONS": "기록 읽기 · 차례 정하기 · 두드려 묻기 · 지우기",
		"RESOLUTION_BRANCHES": "-", "WORLD_STATE_CHANGE": "-", "steps": steps,
	}

static func anchors() -> Dictionary:
	var a := {
		"start": P(0.0, 2.6), "record": P(-3.6, 2.0), "knock": P(0.0, -1.6), "reset": P(4.4, 2.6), "center": P(0.0, -1.0),
	}
	for g in GROOVES:
		a["g_" + g] = P(float(GROOVES[g].x), float(GROOVES[g].z) + 1.1)   # 홈 앞 선 자리
	return a

# 기록 — 밖(제자 탁본 노트, M504 ◆)과 안(이겸 기록지 — 제자에게는 ◇ 남이 적은 것)
#   'feat' 표시는 시험 봇(읽는 봇)만 쓴다 — 글에 적힌 특징과 같다.
static func outside_notes() -> Array:
	return [
		{ "id": "out_C1", "g": "C1", "title": "탁본 노트 — C-1", "text": "비탈 왼쪽 아래. 홈 바로 앞에 무릎보다 낮은 넙적돌이 턱처럼 놓였다." },
		{ "id": "out_C2", "g": "C2", "title": "탁본 노트 — C-2", "text": "비탈 가운데 바깥 가장자리. 홈 아래에 젖은 이끼, 돌이 바깥쪽으로 기울었다." },
		{ "id": "out_C3", "g": "C3", "title": "탁본 노트 — C-3", "text": "비탈 오른쪽 위, 셋 중 가장 높다. 소나무 굵은 뿌리가 홈 오른편을 감고 내려간다." },
		{ "id": "out_same", "g": "", "title": "탁본 노트 — 세 홈 공통", "text": "무늬·숯 획·분필 점검선은 셋이 같다. 점검선은 스승님이 들어가기 전에 남긴 것이지 정답 표시가 아니다. 밖에서는 어느 숯 획이 마지막인지 알 수 없다." },
	]

static func inside_records() -> Array:
	return [
		{ "id": "in_day1", "title": "이겸 기록 — 갇힌 첫날 밤", "by": "이겸 기록지", "text": "움막에서 나와 비탈을 오르면 홈 셋을 지나야 다시 움막 앞이다. 굵은 뿌리가 손목에 걸리는 홈을 지나고 나서야 발끝이 걸리는 낮은 돌턱을 밟는다." },
		{ "id": "in_day3", "title": "이겸 기록 — 셋째 날", "by": "이겸 기록지", "text": "낮은 돌턱을 두 번째로 밟고 나면, 발이 미끄러지고 몸이 바깥으로 기우는 홈이 나온다. 거기서 한 걸음이면 다시 움막 앞." },
		{ "id": "in_fold", "title": "이겸 기록 — 넷째 날", "by": "이겸 기록지", "text": "차례는 늘 같다. 다만 안에서는 길이 접혀, 이 홈들이 밖의 어느 자리인지는 모른다." },
		{ "id": "in_child", "title": "아이의 말 — 이겸이 받아 적음", "by": "아이(이겸 기록지)", "text": "“집에 가려고 움막에서 나와 비슷한 돌마다 표시했어요. 마지막 돌에 획을 하나 더하고 부적에 적힌 말을 읽었어요.”" },
	]

# 기록지 여백(v2.2 M605 — 풀린 뒤에 보인다)
const MARGIN := "틀린 것은 지운다고 끝나지 않는다. 어디서 틀렸는지 남겨라."

static func clues() -> Dictionary:
	var c := {}
	for n in outside_notes(): c[n.id] = { "title": n.title, "text": n.text, "kind": "fact" }
	for r in inside_records(): c[r.id] = { "title": r.title, "text": r.text, "kind": "heard", "by": r.by }
	c["gb_wrong"] = { "title": "한 번 — 아니다", "text": "정한 차례대로 두드렸더니 한 번이 돌아왔다. 어디서 어긋났는지 기록과 다시 견준다.", "kind": "fact" }
	c["gb_right"] = { "title": "두 번 — 맞다", "text": "정한 차례대로 두드리자 느린 두 번이 돌아왔다. 셋째 자리가 아이의 '마지막 돌'이다.", "kind": "fact" }
	return c

static func objects() -> Array:
	var out := [
		{ "id": "o_record", "at": "record", "label": "기록지 묶음 · 읽기(우치가 들고 나옴)", "label_if": ["f('GB_READ')", "기록지 묶음 · 다시 읽기"], "radius": 1.8, "when": "not f('GB_DONE')",
			"steps": [{ "call": "read_record" }] },
		{ "id": "o_knock", "at": "knock", "label": "C 경계석 · 정한 차례대로 두드려 묻기", "radius": 1.8, "when": "not f('GB_CONFIRMED') and not f('GB_DONE')",
			"steps": [{ "call": "knock_confirm" }] },
		{ "id": "o_reset", "at": "reset", "label": "(시험) 처음부터 다시", "radius": 1.4, "when": "true",
			"steps": [{ "call": "reset_choice" }] },
	]
	for g in ORDER_IDS:
		var nm: String = GROOVES[g].name
		out.append({ "id": "o_" + g, "at": "g_" + g, "label": "%s 홈 · 기록의 차례 정하기" % nm, "radius": 1.5, "when": "not f('GB_CONFIRMED')",
			"steps": [{ "call": "assign", "args": [g] }] })
		out.append({ "id": "o_erase_" + g, "at": "g_" + g, "label": "%s 숯 획 · E 길게 눌러 문질러 지우기" % nm, "radius": 1.5,
			"when": "f('GB_CONFIRMED') and not f('GB_DONE') and v('GB_LAST') == '%s'" % g,
			"steps": [{ "call": "erase", "args": [g] }] })
	return out
