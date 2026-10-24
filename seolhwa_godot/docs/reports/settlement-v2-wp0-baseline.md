# settlement v2 — WP0 기준선 고정 (settlement-v2-wp0-baseline)

2026-10-25 · 브랜치 `claude/settlement-v2` · 감사 문서(environment-reference-v1/specification/20) §5 WP0. **게임 코드·이야기·배치·저장은 바꾸지 않았다**(읽기만). 기계용 목록: `tools/settlement/baseline/wp0_baseline.json`(`python -m tools.settlement.baseline`로 다시 만든다).

## 1. 이후 묶음이 깨면 안 되는 것(V16 기준 목록)

| 대상 | 개수 | 출처 | 정체성 ID 형식 |
|---|---:|---|---|
| 이야기 앵커(이름 붙은 자리) | 513 | `story/*/*_data.gd`의 `_anchors()` | `anchor:<자료 파일>:<이름>` |
| 이야기 배치 항목(집·마당·나무 등) | 65 | `region_data/*/placement_story_*.json` | `item:<지역>:<항목 id>` |
| 역참 자리(pos·hitch·wait·yard) | 124 | `region_data/stations.json` | `station:<역>:<자리>` |
| 지역 거점 id | 134 | `region_data/*/region.json settlements` | 기존 id 그대로 |

지역별 이야기 앵커: GG_HANYANG 35, GS_GYEONGJU 33, GW_GANGNEUNG 35, HG_HAMHEUNG 38, HH_HWANGJU 42, JJ_JEJU 52, JL_NAMWON_UNBONG 238, PA_PYEONGYANG 40.
이야기 배치 항목: GW_GANGNEUNG 2, JL_NAMWON_UNBONG 63.

## 2. 저장이 배경을 참조하는 필드(`scripts/region/progress.gd` 머리 주석에서)

| 필드 | 가리키는 것 | 위험 |
|---|---|---|
| `routes_done.<노정 id>` | region_data/routes/* ids | route id rename |
| `known.<공간 id>.<장소 키>` | settlement / landmark keys (region.json ids) | settlement id rename |
| `where{space,x,z}` | world coordinates | coordinate change of walkable ground |
| `waypoint{space,x,z,key}` | world coordinates + place key | coordinate / key change |
| `heard[].place` | place keys | key rename |
| `cases.<id>.world/flags` | story anchor names (story data), not placement ids | anchor rename |
| `travel_nodes/<space>/<node>` | region_data/travel node ids (stations discover_key) | node rename |

저장은 배치 항목 id를 직접 담지 않는다. 다만 `where`·`waypoint`의 **세계 좌표**와 거점·노정·이동 거점 **키**를 담으므로, 걸을 수 있는 땅의 좌표 이동과 키 변경이 저장 호환 위험이다. 저장이 배경 id를 간접 참조하는지(사건 flags 안의 이름 등)는 여기서 끝까지 추적하지 않았다 — 미확인.

## 3. 검사 기준선

| 검사 | 마지막 수치 | 이번에 다시 돌림 |
|---|---|---|
| tools/settlement pytest | 21 passed (settlement-v2-L0-2-impl §6) | 예(Python만) |
| settlement v2 determinism | 8 sites byte-identical (impl §6) | 예(Python만) |
| mountain_check --mtncheck=walk | 46/0 (integ-mountain report) | 아니오(보고서 인용) |
| town walk tests | west 68/0, eup 42/0 (audit WP12) | 아니오(보고서 인용) |
| ROOFCHECK / bldg smoke | smoke 0 · roof 0/288 (town-organic §6) | 아니오(보고서 인용) |
| save_guard_test | SAVEGUARDTEST PASS (protected; not run here) | 아니오(보고서 인용) |

Godot 검사는 실행하지 않았다(이번 묶음은 게임 쪽을 건드리지 않으므로 기준선 수치를 보고서에서 인용). Python 쪽은 이번에 pytest 21개 통과, 결정성(syn_estuary·anmok_village 24파일) 바이트 동일을 다시 확인했다.

## 4. 보호 규칙(이후 묶음 공통)

- 위 앵커·항목·역참 자리는 생성 전에 잠금으로 수입하고(WP2), 충돌하면 진단만 낸다 — 옮기지 않는다.
- `_remap_anchors`(story_director.gd:689)는 그대로 둔다. 새 굽기 경로에서는 좌표를 옮기지 않는다.
- 사용자 저장은 읽지도 덮지도 않는다. 게임 실행 인자는 `--` 뒤(저장 사고 2회).
- 다른 작업자의 미커밋 변경·`docs/reports/environment-reference-v1/`(소유자 결정 대기)는 커밋하지 않는다.
