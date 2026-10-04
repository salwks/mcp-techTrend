# 설화록 v2.3.1 PATCH NOTES — 문서 정합성 잠금

> 기능/시나리오 변경 없음. v2.3의 설계 결정을 코드와 문서에서 같은 이름과 같은 플래그로 사용하기 위한 정합성 패치다.

## 1. 변수명 통일

- `CASE_PYEONGYANG_COMPLETE` → `CASE_PYONGYANG_COMPLETE`
- 기존 결말 변수 `CASE_PYONGYANG_OUTCOME`과 동일한 `PYONGYANG` 철자를 사용한다.
- 게임 코드도 `PYONGYANG`을 정본으로 한다.

## 2. 주요 사건 완료 플래그 8종 확정

```text
CASE_NAMWON_COMPLETE
CASE_HANYANG_BOOKSHOP_COMPLETE
CASE_GANGNEUNG_COMPLETE
CASE_GYEONGJU_COMPLETE
CASE_HWANGJU_COMPLETE
CASE_PYONGYANG_COMPLETE
CASE_HAMHUNG_COMPLETE
CASE_JEJU_COMPLETE
```

용도:
- 황주 완료: ACT 2의 세 갈래(강릉·경주·황주) 완료 판정에 포함
- 제주 완료: 한양 최종장 진입 조건에 포함

## 3. 숙련 6종은 확정, 구현은 2종부터

| 숙련 | 해금 조건 |
|---|---|
| 받아밀기 | `CASE_NAMWON_COMPLETE` |
| 빠른 투척 | `CASE_HANYANG_BOOKSHOP_COMPLETE` |
| 회피베기 | `CASE_GANGNEUNG_COMPLETE` |
| 빠른 사격 | `CASE_GYEONGJU_COMPLETE` |
| 큰 짐승 흘리기 | `CASE_PYONGYANG_COMPLETE && SKILL_BEAST_TRACE` |
| 보조도구 전환 | `CASE_HAMHUNG_COMPLETE` |

- 6종 모두 설계상 유지한다.
- Vertical Slice에서는 `받아밀기`, `빠른 투척`만 먼저 구현한다.
- 나머지 4종은 플레이테스트 후 삭제 대상이 아니라, 해당 사건 도달 시점에 순차 구현한다.

## 4. 상태 변수 중복 제거

시나리오 §7에서 `SKILL_*` 6종이 두 번 기재된 중복 블록을 제거했다.

## 5. 자산 문서 버전 정리

- CHARACTER_MASTER → v1.3, 기준 시나리오 v2.3.1
- PROP_MASTER → v1.3, §14 문구 v2.3.1로 통일
- ASSET_MASTER_INDEX → v1.3, 기준 시나리오 v2.3.1 및 산출물 버전 갱신
- `PRP_OFF_008` 박규상 객주 표식 세트 유지
- §14 번호 유지

## 6. 큰 짐승 흘리기 조건

최종 확정 조건은 다음과 같다.

```text
CASE_PYONGYANG_COMPLETE && SKILL_BEAST_TRACE
```

황주 완료만으로는 해금하지 않는다.

## 7. 제작 영향

- 신규 도시: 0
- 신규 노정: 0
- 신규 설화: 0
- 신규 캐릭터/대형 프롭: 0
- 신규 레벨 시스템: 0
- 코드 영향: 변수명 1건 정리 + 완료 플래그 2종 추가 + 중복 문서 정리

