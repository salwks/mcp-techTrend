# 「남원의 약속」이 끝난 뒤 남원 관아의 작은 일거리 하나 — 「관아 창고 장부 대조」(게임플레이 구조 1차 브리프 §21 재사용 시연).
#   목적: II-B 술·쌀·상소와 같은 Activity/Problem 계약(scripts/story/problems.gd)을 **데이터만으로** 다시 쓸 수 있는지 보인다.
#   이 파일에는 사건 코드 호출(call)·새 화면·직업 UI·숙련도·보상이 없다. 사건 스크립트(namwon_chunhyang_*.gd)는 이 일을 모른다.
#   꼴: 본 것 둘(창고 장부 · 실제 가마니) + 들은 것 하나(창고지기) + 잇기(compare) + 고르기(decide — 한 갈래는 fail_forward 뒤 곳간).
#   열림: 사건이 끝난 뒤(단계 done = CASE_NAMWON_CHUNHYANG_COMPLETE). 본 흐름(II-B·결말)에는 아무 영향이 없다 — 결과는 이 일의 깃발뿐.
#   한계(보고서 §후속 후보): 등록부 choose()는 '안 끝난 첫 사건 → 없으면 첫 사건(오누이)'을 고르므로, 끝난 뒤 저장을 다시 불러오면
#   남원에서 도는 사건은 오누이(끝남)다 — 이 일은 광한루 결말 직후 같은 놀이에서만 열린다. 끝난 사건의 곁일을 다시 여는 것은 후속.
# namwon_chunhyang_data.gd가 problems·actors·anchors를 잇는다(problems는 case_registry.load_data가 expand).
extends RefCounted

const WHEN := "ph('done')"   # 사건이 끝난 뒤(OUTCOME RELEASED · COMPLETE와 같은 때)

static func anchors() -> Dictionary:
	return {
		# 관아 바깥마당 동쪽 물자 곳(ti_gamani_store_a/b · ti_dok_store 곁 — 배치 파일 when에 ph('done') 더함)
		"ch_ledger_book": [-3152.6, 231.0], "ch_ledger_stock": [-3149.0, 229.2], "ch_ledger_keeper": [-3151.2, 233.8],
		"ch_ledger_yard": [-3151.0, 231.0], "ch_ledger_shed": [-3144.6, 226.4],
	}

static func actors() -> Array:
	return [
		{ "id": "ledger_keeper", "chr": "CHR_HUM_004", "kind": "py_clerk", "name": "창고지기", "at": "ch_ledger_keeper", "facing": "down", "accent": false,
			"when": WHEN,
			"talk": [
				{ "when": "not pa('ledger','keeper')", "steps": [
					{ "say": "창고지기", "lines": ["어사 나리 쪽에서 창고를 다시 맞춰 보라는데, 글 아는 사람이 없소.", "장부엔 열두 가마요. 잔치 끝나고 이방이 셋을 내갔지. 어디로 갔는지는 나도 모르오."] },
					{ "activity": "ledger.keeper" }] },
				{ "when": "pd('ledger') == 'note'", "steps": [{ "say": "창고지기", "lines": ["적어 두었소? 그럼 나는 센 대로 말만 하면 되겠구려."] }] },
				{ "when": "pd('ledger') == 'shut'", "steps": [{ "say": "창고지기", "lines": ["덮어 두는 게 속 편하지요. 다들 그랬소."] }] },
				{ "when": "true", "steps": [{ "say": "창고지기", "lines": ["장부는 물자 곳 위에 펴 두었소."] }] },
			] },
	]

static func problems() -> Dictionary:
	return {
		"ledger": {
			"title": "관아 창고 장부 대조", "when": WHEN,
			"activities": [
				{ "id": "book", "type": "inspect", "kind": "seen", "at": "ch_ledger_book", "label": "창고 장부 · 살펴보기", "radius": 1.8,
					"text": ["창고 장부. '벼 — 열두 가마 들임.'", "들인 날은 잔치 사흘 전. 내간 줄은 비어 있다."],
					"record": { "title": "창고 장부", "text": "관아 창고 장부에 벼 열두 가마를 들였다고 적혀 있다. 내간 기록은 없다." } },
				{ "id": "stock", "type": "inspect", "kind": "seen", "at": "ch_ledger_stock", "label": "가마니 · 세어 보기", "radius": 2.2,
					"text": ["쌓인 가마니를 하나씩 센다. 아홉.", "맨 위 줄에 셋 놓일 자리가 비었다."],
					"record": { "title": "창고의 가마니", "text": "물자 곳에 쌓인 가마니는 아홉. 위 줄 셋 자리가 비었다." } },
				{ "id": "keeper", "type": "inspect", "kind": "heard", "actor": "ledger_keeper", "by": "창고지기", "required": false,
					"record": { "title": "창고지기의 말", "text": "잔치가 끝난 뒤 이방이 셋을 내갔다고 한다. 어디로 갔는지는 모른다고." } },
				{ "id": "gap", "type": "compare", "needs": ["book", "stock"],
					"text": ["장부는 열두. 창고는 아홉.", "내간 줄에는 아무것도 적히지 않았다."],
					"record": { "title": "세 가마의 차이", "text": "장부 열두 가마, 창고에 아홉. 내간 기록이 없다.", "kind": "fact" },
					"flags": ["ledger_gap_seen"] },
				{ "id": "handle", "type": "decide", "after": 2, "from": ["book", "stock"], "at": "ch_ledger_yard", "radius": 12.0, "prompt": "장부를 어떻게 할까?",
					"options": [
						{ "id": "note", "label": "센 대로 '아홉 — 셋은 내간 기록 없음'이라 적는다.", "flags": ["ledger_noted"],
							"record": { "title": "적어 둔 것 — 창고", "text": "벼 열두 가마 들임, 실제 아홉. 셋은 내간 기록 없음.", "kind": "fact" } },
						{ "id": "shed", "label": "뒤 곳간부터 확인한다.", "fail_forward": "back_shed" },
						{ "id": "shut", "label": "내 일이 아니다. 장부를 덮는다.", "flags": ["ledger_shut"] },
					] },
			],
			"fail_forward": {
				"back_shed": { "at": "ch_ledger_shed", "radius": 2.4, "label": "뒤 곳간 · 살펴보기",
					"text": ["곳간 안은 비었다. 빈 가마니 껍데기만 쌓였다."],
					"extra": { "text": ["문턱에 낟알이 흘렀다.", "수레바퀴 자국이 관아 뒷문 쪽으로 이어진다."],
						"record": { "title": "흘린 낟알", "text": "뒤 곳간 문턱에 낟알이 흘렀고, 수레바퀴 자국이 관아 뒷문 쪽으로 이어진다." } },
					"do": [{ "flag": "ledger_noted" }] },
			},
			"result": { "flags": ["ledger_check_done"], "do": [{ "caption": "장부를 물자 곳 위에 제자리로 펴 둔다." }] },
		},
	}
