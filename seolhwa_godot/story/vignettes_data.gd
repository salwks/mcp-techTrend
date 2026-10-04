# 길가 장면(사건 기록 없음) — 노정·권역 어디서나 지나가며 한 번 보는 복선. scripts/story/vignettes.gd가 돌린다.
#   space: 권역 region_id 또는 노정 route id. at: [x, z](그 공간 좌표). radius: 이 안에 들면 대사 한 줄 + vars 더하기(저장에 한 번만).
#   props: 키트 소품(at은 장면 기준 [dx, dz]), people: 서 있는 인물(SpriteChar 종류). line: [말하는 이, 대사]. add: { 변수: 더할 값 }
extends RefCounted

const VIGNETTES := [
	# R0104 천안삼거리 — 바퀴를 고치는 박규상 객주 상단(시나리오 v2.2 §9 R0104). 퀘스트 없음.
	#   권역 키트에 수레 모델이 없어(새 모델 금지) 수레에서 내려 길 북쪽 가에 쌓아 둔 곡물 가마니 + 포장 표식(朴)으로 보인다.
	{ "id": "R0104", "space": "JL_NAMWON_UNBONG-GG_HANYANG", "at": [745.0, 6.8], "radius": 13.0, "requires": { "MAIN_MASTER_TRACE": "HANYANG" },
		"props": [
			{ "kit": "scenario/props", "params": { "kind": "gamani", "seed": 3 }, "at": [-1.2, 0.2], "ry": 0.3 },
			{ "kit": "scenario/props", "params": { "kind": "gamani", "seed": 5 }, "at": [0.1, 0.5], "ry": -0.2 },
			{ "kit": "scenario/props", "params": { "kind": "gamani", "seed": 8 }, "at": [-0.6, -1.0], "ry": 1.3 },
			{ "kit": "story/park_mark", "params": { "kind": "wrap", "size": 0.3 }, "at": [-1.2, 0.65], "dy": 0.12, "ry": 0.0 },
			{ "kit": "story/park_mark", "params": { "kind": "wrap", "size": 0.28 }, "at": [0.15, 0.05], "dy": 0.1, "ry": PI + 0.2 },
			{ "kit": "story/park_mark", "params": { "kind": "seal", "size": 0.1 }, "at": [1.0, 1.2], "ry": 0.4 },
		],
		"people": [
			{ "kind": "merchant", "at": [2.4, 0.9], "facing": "left" },
			{ "kind": "peddler", "at": [-2.8, 0.6], "facing": "right" },
		],
		"line": ["상단 일꾼", "박규상 객주 물건은 날짜를 어기면 안 돼."],
		"add": { "MAIN_PARK_MARK_COUNT": 1 } },
]
