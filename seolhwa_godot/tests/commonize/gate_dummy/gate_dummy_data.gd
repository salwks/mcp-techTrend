# 시험 전용 가짜 사건(tests/commonize) — 사건 선언 고을 막음(case.travel_gate)이 남원 아닌 사건에서도 똑같이 도는지만 본다.
#   놀이 콘텐츠가 아니다: case_registry SPACE_CASES에는 없고, 시험이 CaseRegistry.register()로 잠깐 올린다.
extends RefCounted

static func data() -> Dictionary:
	return {
		"case": {
			"id": "gate_dummy", "record_title": "시험용 막음 사건", "region": "TEST_GATE_SPACE",
			"outcome_var": "CASE_GATE_DUMMY_OUTCOME", "reset_vars": [], "requires": {},
			"EVENT_CLASS": "FOLKLORE_EVENT", "SOURCE_ID": "F00",
			"travel_gate": { "leave_space_until": "CASE_GATE_DUMMY_COMPLETE", "notice": "시험 — 아직 떠날 수 없다" },
			"talk_camera": false,
		},
		"actors": [], "objects": [], "triggers": [], "props": [], "events": {},
	}
