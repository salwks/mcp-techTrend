# settlement v2 — WP1 공통 데이터 계약 v1 (settlement-v2-wp1-contract)

2026-10-25 · 브랜치 `claude/settlement-v2` · 감사 문서 20 §5 WP1, 사양 04 TOOL-01. 게임 변경 없음.

## 1. 파일

| 파일 | 내용 |
|---|---|
| `tools/settlement/schemas/contract-v1.schema.json` | 객체 17종의 JSON Schema(`$defs`)와 공통 `meta`·`measure` |
| `tools/settlement/contract.py` | `meta()`·`measure()`·`revision()`·`status_of()`·`v18_violations()`·`validate(kind, obj)`·`region_profile(inp, rules)` |
| `tools/settlement/tests/test_contract.py` | 스키마 단위 시험(예시 통과·필수 누락 실패·상태 열거), V18, 결측≠0, K1 단일 배율 기록 |
| `schemas/settlement-plan.schema.json` | `settlement-plan/2`로 올림. `/1` 출력도 그대로 읽힌다(열거에 둘 다) |

1차는 **필수 항목만** 둔다(감사의 과설계 위험). 각 객체의 세부 필드는 그 객체를 만드는 묶음(WP4·WP5·WP6·WP7a…)이 버전을 올려 채운다.

## 2. 객체와 필수 항목(요약)

| 객체 | 필수 |
|---|---|
| RegionProfile | region, period, coordinates, elevation, data_resolution, **scale_policy**, **water_states**, hypotheses |
| SourceRecord | title, url, written, depicts, kind(현황/수리 후/복원/발굴/실측/회화/검색 발췌/글/자료/설계 결정), access_scope, observations, limits, units_confirmed |
| TerrainPatch | original, modified, landform, rock_body, rock_type, structure_dir, exposure, change_reason |
| WaterReach | upstream, downstream, long_profile, cross_section, plan, flow, bed_mix, **states**(key·offset_world_m·status) |
| HabitatPatch | community, management(자연림/보호림/마을숲/이용림/경작지/unknown), soil, moisture, season |
| Route | purpose, nodes, **modes**(도보/짐말/수레 × 통과·한계·status), width_section, long_profile, support_drainage, centerline |
| Parcel | use, zones, access, yards, buildable, axes |
| Boundary | sides, purpose, implementation(독립 담/건물 외벽/문간채/옹벽/열린 경계/성벽), shared_id, geometry, section, ends |
| Opening | use(통행/배수/반입), width_m, height_m, access_sides, swing_side, state, host (+chainage) |
| Building | type_basis, column_grid, bay_spacing, function_faces, floor_base, roof_support, members, condition, **scale_applied=true** |
| ActivitySite · SurfaceProfile · WallSection · Fortification · DefenseFeature · LandUseProfile | 04 표의 필수 내용 그대로 |
| Lock | kind(이야기 앵커/이야기 항목/역참 자리/수동), geometry_xz, radius_m, source (WP2) |

**공통 meta**(모든 객체): `stable_id`(정체성, 처음 부여 뒤 유지) · `provenance{sources, generator, rules_hash, inputs}` · `rule_version` · `status`(confirmed/proposed/unknown) · `lock_scope`(position/shape/access/material/event_ref/state) · `revision`(내용 SHA-256, 형상이 바뀌면 바뀜) · `hypothesis`.

**결측과 0**: `measure{value, unit, status, missing_reason, source}`. 값이 없으면 `value:null` + 이유, status `unknown`. 0은 측정값 0일 때만.

## 3. 확신어 → status 대응표

| rules / region 확신어 | status | 비고 |
|---|---|---|
| measured | confirmed | SourceRecord가 있어야 실제로 confirmed가 된다 |
| agreed | proposed | 설계자 합의(사료 사실 아님) |
| provisional | proposed | 시험값 |
| 확정 | confirmed | 출처 필요 |
| 추정 | proposed | |
| 가설 | proposed + hypothesis=true | |
| 그 밖·없음 | unknown | |

**V18(가설 표시·자동 확정 없음)**: `meta(status="confirmed")`는 출처가 없거나 가설이면 예외를 낸다. `v18_violations()`가 객체 트리 전체를 훑는다. 생성기가 만드는 객체는 기본 `proposed`다.

## 4. K1 — 배율 기록 하나(소유자 결정 2026-10-25)

`RegionProfile.scale_policy`가 유일한 기록이다.
- `terrain`: 이동 거리용 지형 압축(K=0.30, 남원 세로 remap, 배정 바닥의 국지 배율). 목적: 지리 압축.
- `building`: **하나의 균일 배율 1.2를 평면과 높이에 함께**(`axes: [plan, height]`, 넓이 ×1.44 파생). 목적: 2 m 인물에 맞춘 건물·필지·골목 확대. `decided_by: owner 2026-10-25`.
- `rules_hold: measured_values`, `apply_once_at: bake` — 규칙 파일은 실측(역사) 값을 두고, 배율은 `program.building_factor()` 한 곳에서 한 번만 곱한다. `world.area_scale`은 파생값이며 따로 곱하지 않는다.
- `L1.scale_once` 검사는 필지·관아 넓이 = 실측 × 배율² 이고, 그 배율이 계획서의 RegionProfile 기록과 같은지를 본다.

## 5. K3 — 수위 상태(소유자 결정 2026-10-25)

`RegionProfile.water_states`(단위 world_m, status proposed): 갈수 −0.5 · 평수 0 · 증수(작은 물) +0.5 · 증수(큰물) +1.5(점유 제외) · 범람 +3.0. 범람 화면은 이 상태들의 오프셋을 그대로 쓰고, 계획서의 각 물길(`site.water_features[].stage_states`)과 `site.flood_screen`이 같은 키·값을 가진다(V67 재검사에 같은 값을 쓰기 위함). 규칙 시작 때 `flood.stage_offsets`와 상태 표가 다르면 오류로 멈춘다.

## 6. 인수(감사 WP1)

| 항목 | 결과 |
|---|---|
| V18 가설 표시·자동 확정 없음 | `test_v18_no_automatic_confirmation`, RegionProfile `v18_violations == []` — 통과 |
| 스키마 단위 시험 | 객체 17종 예시 통과 + 필수 누락 실패 + 상태 열거·meta 필수 — 통과(pytest) |
| K1 변환 기록 | `test_region_profile_single_scale_record_k1`, 계획서 `region_profile` 포함, `L1.scale_once` 확장 — 통과 |
| 기존 스키마 버전 올림·이전 출력 읽힘 | plan `/2`, 열거에 `/1` 유지 — 통과 |
