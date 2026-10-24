# settlement v2 — WP2 정체성 ID·개정 해시 분리와 잠금 (settlement-v2-wp2-identity-locks)

2026-10-25 · 브랜치 `claude/settlement-v2` · 감사 문서 20 §5 WP2, 충돌 K10·K11. 게임 런타임 변경 없음(`_remap_anchors`는 그대로).

## 1. 정체성 ID ↔ 개정 해시(K10)

- `tools/settlement/registry.py`: 등록부(`settlement-id-registry/1`). 객체가 처음 나올 때 `<종류>:<범위>:<순번>` 정체성을 주고, 다시 구울 때 **알아보면 그대로 쓴다**.
  - 의미 키로 알아봄: 틀(`frame`), 성벽(`wall`), 관아 터(기관 키), 회랑 노드(문 정체성·관아 키), 링크(양 끝 노드 정체성), 경로, 물 확보 터(종류).
  - 위치로 알아봄: 문·수문(`registry.match_tol_m` 30 m), 분기점(15 m).
  - 더는 나오지 않는 정체성은 **은퇴**(지우지 않고, 다시 쓰지 않음). 은퇴는 받아들여진 굽기(valid/proposed)에서만.
- 모든 틀 기록에 `stable_id`(정체성)와 `revision`(내용 SHA-256)이 함께 붙는다. 형상이 바뀌면 revision만 바뀐다.
- 내용 해시 `g-…`는 기하 저장소 키로만 남는다(결정성 검사용).
- 범위: 기준안은 거점 id, 제안안(자동 허용 영역)은 `<id>@proposal` — 제안이 기준안 정체성을 가져가지 않는다.
- CLI: 기본은 굽기마다 새 등록부(같은 입력 → 같은 바이트). 영속 편집층은 `--registry` 경로를 줄 때(다음 묶음에서 연결; 이번에는 시험으로 검증).

## 2. 잠금 수입(K11)

`tools/settlement/locks.py`가 **생성 전에** 지역 어댑터에서 잠금을 채운다(`adapters/region.py`, 이전의 `locks=[]` 대체). 출처는 WP0과 같은 추출기(`baseline.py`).

| 종류 | 출처 | 기하 | 범위 | 생성에 주는 효과 |
|---|---|---|---|---|
| story_anchor | `story/*/*_data.gd` `_anchors()` | 점 + 반경 3 m | position·access·event_ref | 틀은 둘러쌀 수 있음 · 성벽이 지나가면 그 후보 기각(`lock_conflict`) · 관아 터·물 확보 터가 덮지 못함 |
| story_item | `placement_story_*.json` | 발자국(w·d·ry) + 2 m | position·shape·access | 위 + 장부 `locks` 범주(점유) · 주 가로가 지나가지 못함 |
| station_anchor | `stations.json` pos/hitch/wait/yard | 점 + 4 m | position·access | story_anchor와 같음 |

- **잠금은 옮기지 않는다.** 물 안·범람 제외 구역 안·길에서 닿지 않음은 L0 진단(`lock_in_water`·`lock_in_flood_exclusion`·`lock_unreachable_from_routes`), 성벽 교차는 후보 단위 `lock_conflict`로 `plan.lock_report`에 모은다.
- 계획서 `locks[]`는 계약 Lock 객체(meta: status confirmed, 출처 = 이야기 파일, lock_scope)로 나간다.
- 남원 읍 창(1 km 둘레)에는 잠금 304개(앵커 237·배치 항목 63·역참 자리 4). 불국사·반선·안목 창에는 이야기 자리가 없다.

## 3. 인수

| 항목 | 시험 | 결과 |
|---|---|---|
| V14 부분 재생성: 비대상 ID 유지 | `test_partial_regeneration_keeps_ids_v14` — 하구·실패 픽스처를 한 등록부에 굽고 하구만 다시 구움: 하구 정체성 동일, 다른 범위 항목 바이트 동일, 은퇴 0 | 통과 |
| V14 고정 입구(잠금) | `test_locked_spots_never_move_and_conflicts_reported_v14` — `syn_terrace_locked`(남쪽 성벽 자리 위 앵커·마을 안 앵커·잠긴 집): 잠금 좌표 불변, 받아들인 틀은 잠금을 가로지르지 않음, 가로지른 후보 15개는 보고, 장부 `locks` 168 m² | 통과 |
| V16 기준 목록 보존 | `WP2.locks_preserved`(계획서 검증) + `test_region_adapter_imports_story_locks_v16`: 창 안 WP0 기준선 항목이 모두 같은 좌표의 잠금으로 들어옴(남원 304/304) | 통과 |
| ENV-09/10 | 잠금 자동 해제·좌표 이동 없음(코드에 이동 경로 없음), 사건 참조 id = 이야기 파일의 이름 그대로 | 설계상 충족 |

## 4. 남은 것

- NPC 선택이 목록 순서에 의존하는 문제(town-organic §8)는 integ 마을 생성기 쪽이라 이번 범위 밖.
- 역참 건물 발자국(footprint·ry)은 아직 점 잠금으로만 받는다(건물 모양 잠금은 WP12 굽기에서).
- 영속 등록부 파일의 저장 위치·병합 규칙(사람 편집과 충돌 시 객체 수준 보고)은 TOOL-04 편집층 작업 때 정한다.
