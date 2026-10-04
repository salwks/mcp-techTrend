# 설화록 ASSET_MASTER_INDEX v1.3

## 1. 기준

현재 자산 마스터는 다음 프로젝트 자료를 기준으로 작성했다.

- `STORYBOARD_BRIEF.md`
- `seolhwarok_master_scenario_storyboard_v2.3.1_consistency_lock.md`

현재 범위는 **메인 시나리오 + F01~F48 + 현재 지역 전승 앵커**다.
아직 별도 원본 `FOLKTALE_CATALOG.md` 163편 전체를 대입한 최종판은 아니다.

---

## 2. 산출물

1. `seolhwarok_CHARACTER_MASTER_v1.3.md`
2. `seolhwarok_ITEM_MASTER_v1.0.md`
3. `seolhwarok_PROP_MASTER_v1.3.md`

---

## 3. 자산 구조

### Character

`고유 캐릭터 → 인간 베이스 → 지역 의상 → 초자연/동물 베이스 → 설화별 변형`

목표는 설화가 늘어도 고유 스프라이트 수가 선형으로 늘지 않게 하는 것이다.

### Item

`무기 → 생존 → 조사 → 생활사건 → 주술/호신 → 사건고유 → 증거`

설화 신물은 대부분 영구 장비가 아니라 사건 물품이다.

### Prop

`생활 공용 → 장소 키트 → 조사 단서 → 설화 고유 → 최종장`

대사 대신 환경으로 사건을 읽게 하는 핵심 자산이다.

---

## 4. 다음 163편 설화 매핑용 필수 필드

```text
SOURCE_ID
SOURCE_TITLE
REGION_GRADE
EVENT_SCALE
REQUIRED_CHARACTER_IDS[]
REQUIRED_ITEM_IDS[]
REQUIRED_PROP_IDS[]
NEW_CHARACTER_COUNT
NEW_SUPERNATURAL_COUNT
NEW_ANIMAL_COUNT
NEW_ANIMATION_COUNT
NEW_ITEM_COUNT
NEW_PROP_COUNT
ASSET_COST_SCORE
REUSE_RATE
PRODUCTION_PRIORITY
KEEP_OR_CUT
```

---

## 5. 통합 제작비 점수

```text
ASSET_COST_SCORE =
  unique_human * 3
+ unique_supernatural * 5
+ new_animal * 4
+ new_animation * 4
+ new_system_item * 5
+ unique_relic * 3
+ large_unique_prop * 5
+ interactive_prop * 3
+ static_prop * 1
```

### 판정

- 0~5: 낮음
- 6~12: 보통
- 13~20: 높음
- 21 이상: 매우 높음 — 사건 중요도 재검토

**제작비가 높다고 자동 제외하지 않는다.** 메인 사건·지역 대표 설화라면 높은 비용을 감수할 수 있다. 다만 짧은 D급 사건이 20점 이상이면 재구성하는 것이 원칙이다.

---

## 6. 재사용률 목표

### 캐릭터
- 일반 인간 캐릭터: 80% 이상 베이스 재사용
- 설화 고유 인간: 얼굴/의상 변형을 우선
- 초자연: 60% 이상 기본형 재사용
- 완전 고유 괴물: 매우 제한

### 아이템
- 일반/조사 아이템: 90% 이상 재사용
- 신물: 설화별 고유 허용
- 신규 시스템 아이템: 최소화

### 프롭
- 생활 프롭: 90% 이상 재사용
- 조사 단서: 상태/데칼 변형으로 재사용
- 설화 고유 프롭: 핵심 상징물만 제작

---

## 7. Vertical Slice 잠금 범위

### 캐릭터

플레이어, 남원 오누이, 떡장수 어머니, 호랑이, 주모, 포수, 농부, 아낙, 선비, 상인, 보부상, 뱃사공, 포졸, 책쾌, 우치, 소/말/개/닭.

### 아이템

환도, 활, 화살, 음식, 약, 등불, 횃불, 떡, 참기름, 기록책, 먹/종이.

### 프롭

남원 민가/주막 기본 키트 + `산길의 실종` 단서 세트 + 한양 책방 조사 세트.

이 범위만으로 먼저 **남원 → 노정 → 한양 첫 사건**을 완성한다.

---

## 8. 자산 추가 금지 규칙

- 이름만 다른 동일 기능 아이템 추가 금지.
- 설화 1회 등장용 인간을 무조건 고유 캐릭터화 금지.
- 원전에 없는 괴물 외형을 장식 목적으로 추가 금지.
- 설화 신물을 반복 파밍 장비로 변환 금지.
- 단순 생활 장면을 고유 퀘스트 자산으로 과대 제작 금지.
- 단서가 대사 없이 보여야 하는 경우 프롭을 아끼기 위해 텍스트로 대체하지 않는다.

---

## 9. 다음 작업 순서

### Step 1 — 163편 설화 전수 매핑

각 설화를 현재 Character/Item/Prop ID에 대입한다.

### Step 2 — 제작비 자동 산정

각 설화별 `ASSET_COST_SCORE`와 `REUSE_RATE`를 계산한다.

### Step 3 — 콘텐츠 등급 결정

- 메인/대표 사건
- 10~20분 지역 서브
- 3~10분 단기 사건
- 환경 전승/ECHO
- 소문만 사용
- 제외

### Step 4 — Vertical Slice 제작

남원→한양 구간에서 실제 자산 재사용률과 대사 절감 효과를 검증한다.

### Step 5 — 마스터 수정

플레이테스트 결과를 반영해 CHARACTER/ITEM/PROP 마스터를 갱신한다.

---

## 10. 이번 단계에서 새로 고정된 제작 철학

1. **설화 수가 늘어도 캐릭터 수가 같은 비율로 늘어나면 안 된다.**
2. **아이템은 수집 대상보다 문제 해결 수단이다.**
3. **프롭은 장식이 아니라 서사의 전달 수단이다.**
4. **고유 자산은 원형 설화의 핵심 상징에 집중한다.**
5. **163편 전체 매핑은 이야기 선택이면서 동시에 제작비 산정 작업이다.**


---

## 11. v2.3 수정의 제작 영향

### 추가되지 않은 것

- 신규 대표 도시: 0
- 신규 노정: 0
- 신규 설화: 0
- 신규 고유 NPC: 0
- 신규 무기: 0
- 신규 대형 환경 프롭: 0

### 추가되는 것

- 플레이어 소규모 전투 동작 최대 4종
- 전투 상태 로직 2종
- 박규상 객주 표식 텍스처 세트 1종
- 문서/탁본 필기 변형 수종

### 개발 우선순위

Vertical Slice에서는 아래만 즉시 반영한다.

1. `받아밀기`
2. `빠른 투척`
3. 천안삼거리 상단 수레 `朴` 표식
4. 한양 책방 납품표
5. 이겸 기록 한 줄

전투 숙련 6종은 설계상 확정한다. Vertical Slice에서는 2종만 먼저 구현하고, 나머지 4종은 해당 사건 도달 시점에 순차 구현한다. 복선 자산도 필요한 시점에 순차 반영한다.

따라서 v2.3.1은 **현재 제작을 멈추고 재작업할 수준의 변경이 아니다.**


---

## 12. 성장 시스템 확정

일반 레벨/경험치 체계는 사용하지 않는다.

성장 축:

1. 전투 숙련 — 주요 사건 완료로 해금
2. 조사 숙련 — 사건에서 새로운 조사법 획득
3. 도구·신앙 지식 — 특정 사건/인물/지역을 통해 획득

### 전투 숙련 해금

```text
CASE_NAMWON_COMPLETE              -> SKILL_GUARD_SHOVE
CASE_HANYANG_BOOKSHOP_COMPLETE    -> SKILL_QUICK_THROW
CASE_GANGNEUNG_COMPLETE           -> SKILL_EVADE_SLASH
CASE_GYEONGJU_COMPLETE            -> SKILL_SNAP_SHOT
CASE_HWANGJU_COMPLETE             -> 진행 조건용(숙련 직접 해금 없음)
CASE_PYONGYANG_COMPLETE
  + SKILL_BEAST_TRACE             -> SKILL_BEAST_SIDESTEP
CASE_HAMHUNG_COMPLETE             -> SKILL_TOOL_SLOT_PLUS
CASE_JEJU_COMPLETE                -> 최종장 진입 조건용(숙련 직접 해금 없음)
```

### 제작 영향

- 경험치 UI: 0
- 레벨업 UI: 0
- 레벨 숫자 밸런싱: 0
- 사건 완료 플래그 8종 + 숙련 플래그 6종
- Vertical Slice 즉시 구현: 받아밀기, 빠른 투척
