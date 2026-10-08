# 남원 「남원의 약속」(춘향) v1.1 — 착수 전 결정 (2026-10-08)

> 기준 원문: 「남원의 약속」 제작 시나리오 v1.0 (BASE 완판 84장본 「열녀춘향수절가」)
> 아래 결정을 원문에 반영하면 v1.1 기준판이 된다. 착수는 남원 v3.2 완료 뒤이며, 코드보다 자산 목록과 남원 실제 좌표 배치를 먼저 만든다.

## 1. 사건 ID·변수 정규화
- 사건 id는 `namwon_chunhyang`이고, 데이터는 `story/namwon_chunhyang/`에 둔다. 등록은 `case_registry.SPACE_CASES["JL_NAMWON_UNBONG"]`에 한다.
- 전역에서 쓰거나 다른 사건이 참조하는 변수는 다음 넷뿐이다.
  - `CASE_NAMWON_CHUNHYANG_OUTCOME`: 고정 결말이므로 최종값은 `"RELEASED"` 하나다. 도덕 점수가 아니다.
  - `CASE_NAMWON_CHUNHYANG_COMPLETE`
  - `CASE_NAMWON_CHUNHYANG_PART1_COMPLETE`
  - `CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1`
- 사건 내부 flag는 `cases.namwon_chunhyang`의 namespace 안에서 접두사 없이 쓴다:
  met_bangja, vow_witness, warned_wolmae, restraint_obeyed / restraint_loose / restraint_refused,
  brought_prison_food, wine_recorded, rice_left, old_man_heard 등.
- 원문의 `CHUNHYANG_*`, `CASE_CHUNHYANG_COMPLETE`는 쓰지 않는다.
- 플레이어 행동의 차이는 합산하지 않고 flag마다 따로 기억한다.

## 2. 이겸의 흔적 — 2차 흔적만
- 위치: PART II ACT 13, 관아 앞에서 소를 빼앗긴 노인의 말을 듣는 장면.
  - 노인: "며칠 전에도 책 한 권 끼고 다니는 선비가 와서 이런 일을 묻더군."
  - 나그네: "어떤 선비였소?"
  - 노인: "이름은 말 안 했소. 내 말만 한참 적어 갔지."
- 기록책에는 ◇ 들음 — 농부 로만 남긴다. `MAIN_MASTER_TRACE`는 바꾸지 않는다. 시스템이 "이겸이다"라고 확정하지 않는다.

## 3. 계절 — 전역 시스템 없이 사건별 세트 드레싱
- 확인 결과 weather.gd에는 월·계절 개념이 없다. Season Manager는 만들지 않는다.
- 오누이: 봄이라는 설정만 둔다. 계절 변환은 없다.
- PART I(단오·초여름): 기본 녹색 환경에 그네, 색천, 장터, 씨름판, 단오 군중을 더한다.
- PART II(초가을~추수 직후): 관아와 읍성 주변에만 곡식가마, 볏짚, 수확물, 감나무 열매(기존 variant), 잔치 물자를 둔다. 숲 전체를 단풍으로 바꾸지 않는다.
- 쓸 수 있는 기존 자산: 황금빛 rice_tuft, 조·보리 계열 작물, 감나무 variant.

## 4. 재방문 시점
- PART I 진입: `CASE_NAMWON_COMPLETE && CASE_HANYANG_BOOKSHOP_COMPLETE`. 한양을 다녀온 뒤 처음 남원에 돌아왔을 때 열린다.
  - 귀환 이유는 다른 지역의 소문과 지도 리드로 준다("남원 단오장이 크게 선다더라"). 강제하지 않는다.
- PART I이 끝나면 `CASE_NAMWON_CHUNHYANG_PART1_COMPLETE`를 세우고, 남원을 실제로 떠나면 `CASE_NAMWON_CHUNHYANG_LEFT_AFTER_PART1`를 세운다.
- PART II 진입: PART1_COMPLETE && LEFT_AFTER_PART1 && (CASE_GANGNEUNG_COMPLETE || CASE_GYEONGJU_COMPLETE || CASE_HWANGJU_COMPLETE).
  - 귀환 소문: "남원 새 사또가 잔치를 크게 벌인다더군." / "곡식이고 술이고 관아로 들어간다던데."
- `MAIN_PROGRESS >= required_gate` 같은 추상 변수는 쓰지 않는다.

## 5. requires
- 오누이 완료(`CASE_NAMWON_COMPLETE`)는 필수다. 방자와 아전이 "북쪽 범 때 있던 길손"으로 알아보는 대사가 이를 전제로 한다.

## 6. 자산 축소
- 고유 외형을 만드는 인물: 춘향, 몽룡(평복과 거지 차림), 방자, 월매, 변학도, 향단.
- 기존 generic bank를 재사용하는 인물: 이방, 사령, 어사 수행원, 장터 군중, 잔치 손님.
- 공간: 광한루는 기존 남원 자산을 우선 쓴다. 새로 만드는 핵심은 그네, 월매 집 연출 구역, 관아 단, 옥, 잔치 props다.
- 단오 장터와 잔치 군중은 성능을 확인하고 인원을 정한다.

## 착수 순서
남원 v3.2 완료 → 자산 목록과 남원 좌표 배치 → 춘향 데이터와 사건 코드 → 검사기에 새 사건 메타 필수 항목 추가(case.id, record_title, region, outcome_var, reset_vars, EVENT_CLASS, SOURCE_ID).
