# 전투 숙련 해금표(시나리오 v2.2 §6.1·§6.3.1 — 레벨 없음). 사건이 끝나면(phase done) story_director가
#   CASE_<키>_COMPLETE = true 를 세우고 이 표를 훑어 조건이 맞은 숙련 변수(SKILL_*)를 켠다. 체력·기력은 여기에 묶지 않는다.
#   unlock: 갈래 목록 — 갈래 하나라도 맞으면(또는). 갈래가 이름 하나면 그 변수가 참, 이름 배열이면 모두 참(그리고).
#   예: 큰 짐승 흘리기 = 평양 완료 그리고 짐승 흔적 읽기(v2.3).
#   사건 키: 사건 데이터 case.complete_key(없으면 사건 id 대문자). 남원 NAMWON · 한양 책방 HANYANG_BOOKSHOP · 강릉 GANGNEUNG …
# 동작이 있는 것은 P0 둘(받아밀기·빠른 투척 — scripts/combat/cplayer.gd skills). 나머지 넷은 해금 변수만. unlock이 빈 목록이면 아직 어느 사건도 열지 않는다.
extends RefCounted

const TABLE := [
	# 남원 v3.2 결정 2: 남원 완료 보상은 '짐승 흔적 읽기'(SKILL_BEAST_TRACE — namwon_data S0010) 하나뿐. 받아밀기는 남원에서 빼고 지금은 아무 사건도 열지 않는다.
	# TODO(전투 진행 정리): 받아밀기를 열 사건을 정한다 — 후보는 막기로 받는 싸움을 처음 본격적으로 쓰는 뒤 사건(강릉·경주 등).
	#   이미 받아밀기를 연 옛 저장은 그대로 둔다(끄지 않는다). 막기·회피 자체는 기본 능력이다(남원 첫 조우에서 K·L로 배운다).
	{ "var": "SKILL_GUARD_SHOVE", "name": "받아밀기", "unlock": [] },
	{ "var": "SKILL_QUICK_THROW", "name": "빠른 투척", "unlock": ["CASE_HANYANG_BOOKSHOP_COMPLETE"] },
	{ "var": "SKILL_EVADE_SLASH", "name": "회피베기", "unlock": ["CASE_GANGNEUNG_COMPLETE"] },
	{ "var": "SKILL_SNAP_SHOT", "name": "빠른 사격", "unlock": ["CASE_GYEONGJU_COMPLETE"] },
	{ "var": "SKILL_BEAST_SIDESTEP", "name": "큰 짐승 흘리기", "unlock": [["CASE_PYONGYANG_COMPLETE", "SKILL_BEAST_TRACE"]] },
	{ "var": "SKILL_TOOL_SLOT_PLUS", "name": "보조도구 전환", "unlock": ["CASE_HAMHUNG_COMPLETE"] },
]

# 사건 완료 변수(사건 데이터 case.complete_key — 없으면 사건 id 대문자). 문서의 PYEONGYANG 표기는 PYONGYANG으로 통일
const COMPLETE_VARS := ["CASE_NAMWON_COMPLETE", "CASE_HANYANG_BOOKSHOP_COMPLETE", "CASE_GANGNEUNG_COMPLETE", "CASE_GYEONGJU_COMPLETE",
	"CASE_HWANGJU_COMPLETE", "CASE_PYONGYANG_COMPLETE", "CASE_HAMHUNG_COMPLETE", "CASE_JEJU_COMPLETE"]

static func complete_var(case_data: Dictionary, case_id: String) -> String:
	return "CASE_%s_COMPLETE" % String(case_data.get("complete_key", case_id.to_upper()))

# 조건이 맞았는데 아직 꺼진 숙련을 켜고, 새로 켠 이름들을 돌려준다
static func unlock(vars: Dictionary) -> Array:
	var got := []
	for s in TABLE:
		if bool(vars.get(s.var, false)): continue
		for c in s.unlock:
			var ok := true
			for name in (c if c is Array else [c]):
				if not bool(vars.get(name, false)): ok = false
			if ok:
				vars[s.var] = true
				got.append(String(s.name))
				break
	return got
