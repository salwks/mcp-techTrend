# settlement v2 — 다음 묶음(WP4·WP7a·WP11)이 받을 데이터 계약 요약

2026-10-25 · 브랜치 `claude/settlement-v2`. 정본: `tools/settlement/schemas/contract-v1.schema.json`, `tools/settlement/contract.py`. 자세한 설명은 `settlement-v2-wp1-contract.md`.

## 공통 규칙(모든 묶음)

- 모든 객체에 `meta{stable_id, provenance{sources, generator, rules_hash, inputs}, rule_version, status, lock_scope, revision, hypothesis}`.
  - `stable_id` = 정체성(등록부가 유지). `revision` = 내용 SHA-256.
  - 생성기는 `confirmed`를 만들지 않는다(V18). `contract.meta(status="confirmed")`는 출처가 없거나 가설이면 예외.
- 결측은 `measure{value:null, missing_reason}`. 0은 측정값 0일 때만.
- 단위는 미터(world_m). 배율 기록은 `RegionProfile.scale_policy` 하나뿐이다.
  - `building.factor` 1.2를 평면과 높이에 함께 쓴다.
  - 규칙에는 실측값을 두고, 굽기에서 한 번만 곱한다(`program.building_factor`). 이미 축척한 값을 다시 키우지 않는다(`scale_applied:true`).
- 잠금(`locks[]`, Lock 객체)은 옮기지 않는다. 충돌은 진단으로만 낸다(`plan.lock_report`).
  - 이야기 앵커 ID: `lock:anchor:<자료 파일>:<이름>`
  - 이야기 배치 ID: `lock:item:<지역>:<id>`
  - 역참 ID: `lock:station:<역>:<자리>`
  - 기준 목록: `tools/settlement/baseline/wp0_baseline.json`
- 계획서는 `settlement-plan/2`(`/1`도 읽힘)이고 `region_profile`을 담는다.

## WP4 지형·물 데이터층이 받을 것·채울 것

- **받음**: `RegionProfile.water_states`(갈수 −0.5·평수 0·증수 +0.5·큰물 +1.5·범람 +3.0, world_m, proposed).
- **받음**: 계획서 `site.water_features[].stage_states`, `site.flood_screen{상태 키: offset·geometry}`.
- **받음**: `inputs.movement_livelihood.routes[]`(Route: purpose·nodes·modes[도보/짐말/수레 × passable·limit·measured_sustained_grade]·width_section·long_profile·centerline).
  - 수단 한계는 시험값이다: 도보 .25·짐말 .15·수레 .10, 10 m 지속 경사.
- **받음**: `crossings`(지도에 있는 건널목만 물 위 통과).
- **채울 것**: WaterReach `long_profile·cross_section·bed_mix·states`(같은 키로), TerrainPatch(능선·안부·암체), Route `long_profile·support_drainage`(지금은 지속 경사만, 지지/배수 `[]`).
- **보장할 것**: 같은 상태 키·값을 V67 재검사에 쓴다. 상태 값을 바꾸면 `water.stage_states` 하나만 바꾼다(rules 시작 때 범람 오프셋과 일치 검사).

## WP7a 건물 서술자가 받을 것

- `Building{type_basis, column_grid, bay_spacing, function_faces, floor_base, roof_support, members, condition, scale_applied:true}` — 1차 필수 항목만 있다. 세부(처마 외곽·출입 소켓·마루 지지·아궁이–구들–굴뚝)는 WP7a가 스키마 버전을 올려 추가한다.
- 배율은 `RegionProfile.scale_policy.building.factor`를 읽는다. `_spec.gd`의 `SCALE_CLS`(1.16/1.22/1.2)와 겹치지 않게, 서술자에는 해결된 세계 치수와 `scale_applied:true`만 둔다.
- 관아 터: 계획서 `frame.civic_reserves[]{stable_id, key, variant, envelope, forecourt, entrance_socket, bearing_deg, width_m, depth_m, court_min_m2, contents, terrace_required}`. 건물 배치는 이 안에서 한다.

## WP11 KHS 승인·보정이 받을 것

- `SourceRecord{title, url, written, depicts, kind(current_state/after_repair/restoration/excavation/survey/painting/search_excerpt/text/data/design_decision), access_scope, observations, limits, units_confirmed}` — 낙안 현황은 `current_state` 또는 `restoration`으로 표시한다(V18).
- 확신어 → status 대응표(`contract.status_of`): measured→confirmed(출처 필수), agreed/provisional/추정→proposed, 가설→proposed+hypothesis, 나머지→unknown.
- 보정 결과(칸·처마·용마루)는 `measure`로 넣고, 단위가 확정되지 않았으면 `units_confirmed:false`로 둔다. 이 경우 자동 수입하지 않는다.

## 정체성 등록부

- `tools/settlement/registry.py`(`settlement-id-registry/1`). 의미 키·위치(30 m)로 알아보고, 은퇴는 하되 재사용하지 않는다. 제안안은 `<id>@proposal` 범위.
- 굽기 기본은 새 등록부라서 결정적이다. 영속 편집층 경로와 병합 규칙은 아직 정하지 않았다.
