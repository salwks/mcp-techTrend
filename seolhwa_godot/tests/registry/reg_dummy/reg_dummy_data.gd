# 시험 전용 가짜 사건(tests/registry) — 등록부가 한 공간에 사건 둘을 올릴 수 있는지만 본다. 놀이 콘텐츠가 아니다:
#   scripts/story/case_registry.gd SPACE_CASES에는 없고, 시험이 CaseRegistry.register()로 잠깐 올린다.
extends RefCounted

static func data() -> Dictionary:
	return {
		"case": {
			"id": "reg_dummy", "record_title": "시험용 둘째 사건", "region": "JL_NAMWON_UNBONG",
			"outcome_var": "CASE_REG_DUMMY_OUTCOME",
			"requires": { "CASE_NAMWON_COMPLETE": true },   # 남원이 끝나야 선다(요구 고르기 시험)
		},
		"actors": [], "objects": [], "triggers": [], "props": [], "events": {},
		"map_leads": [{ "id": "reg_dummy_lead", "name": "시험 표지", "at": [0.0, 0.0], "when": true }],
	}
