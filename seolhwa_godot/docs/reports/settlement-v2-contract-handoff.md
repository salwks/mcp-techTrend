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

## WP4 지형·물 데이터층 — 추가된 것(2026-10-25)

자세한 것은 `settlement-v2-wp4-terrain-water.md` §4를 본다.

- **층 파일**: `terrain-water.json`(`terrain-water/1`, `schemas/terrain-water.schema.json`)과 `terrain-fields.npz`.
- **계획서 연결**:
  - `plan.terrain_water{file, revision, summary, checks}`
  - `plan.site.water_features[].reaches[]`
- **Route**: 다음 필드를 채웠다.
  - `long_profile`(chainage·y·ascent/descent)
  - `width_section.sections`(지지 후보·절취면)
  - `support_drainage`(배수선 횡단의 처리는 null+후보)
  - `divide_crossings`, `catchments_at_ends`, `cliff_traversal_m`, `modes[].reasons`
- **WaterReach·건널목**: 같은 상태 키를 쓴다.
  - WaterReach: 종단·횡단·평면·하상 유형(혼합 비율 null)·흐름 원인·상태별 젖은 폭/둑 넘음
  - 건널목: 상태 × 수단 통과
  - 지도에 없는 건널목은 후보(`applied:false`)일 뿐이다.
- **TerrainPatch**: landform(8 m)과 ground(2 m 절벽·암체·너덜·모래톱·충적)로 나뉜다. 암종은 기록만 하며 분류에 쓰지 않는다.
- **HabitatPatch**: 관리 유형 자리표시다. 경작지·마당만 정해져 있고 나머지는 unknown(WP10).
- **RegionProfile.natural**: 21 지역 값이다. confirmed는 A/B와 출처가 있을 때만이다.
- **계약 enum 추가**: landform `foot_slope/summit/water`, management `cultivated_yard/abandoned`.
- **불변식 `WP4.layer`** 만 게시를 막는다. V01–V67 결과는 발견(finding)으로 보고한다.

## WP5 Layers 3–5 구역·길·물·필지 — 추가된 것(2026-10-25)

자세한 것은 `settlement-v2-wp5-layout.md`를 본다.

- **층 파일**: `layout.json`(`settlement-layout/1`, `schemas/settlement-layout.schema.json`). 계획서에는 `plan.layout{file, status, revision, summary, checks, revision_requests}`만 둔다. 불변식 `WP5.layer`만 게시를 막는다. 굳은 검사(hard)가 실패하면 layout 상태가 `incomplete`가 되고 `revision_requests`가 남는다.
- **구역**(`districts`): 역할 + 가구 혼합(계급·생업·묶음은 따로). 비건축 영역(`regions`: 언덕·빈터·물길·보호 경작지·과원/채마)도 영역이다. 구역 경계는 길·담이 아니다(계획 표지).
- **가구**(`households[]`): `hh:<범위>:<nnnn>`, 계급·생업·묶음·구역·필지. 한 번만 배정된다(성 밖 마을 가구는 `hamlet`).
- **길**(`streets`): `nodes`·`links`(primary=L2 회랑, route=지도 길, secondary·lane·cul_de_sac·gosat). 링크마다 `modes{foot, pack_horse, cart}`·`grade`·`reason`·`bends[]{reason}`·`width_basis`. 광장은 프로그램에서만(앞마당·장터·우물).
- **물**(`water`): `channels[]{effective_wet(파인 골 단면), mapped_width_m(별도 속성), width_disagreement}`, `crossings[]`(지도 WP4·L2 회랑·새 길, 여울은 `riffle_section`), `drains[]{invert, fall, outlet, terminal}`, `wall_passages`.
- **필지**(`parcels[]`): 계약 Parcel(use·zones·access·yards(null+이유)·buildable·axes(null+이유)) + role·block·district·household·frontage.
- **세분 그래프**(`subdivision`): `edges[]`는 한 번만 저장(`left_face`·`right_face`), `faces[].rings`는 부호 있는 변(`e+`/`e-`).

### WP6(경계·담·문·수구)이 받을 것

- 변마다: `adjacency`(양쪽 면 범주), `purpose`(street_frontage·party_boundary·rear_or_side_boundary·town_wall_inner·gate_opening·water_edge·lock_boundary…), `geometry_reason`(이 변을 만든 선: street_edge·frontage_normal·frontage_depth·rear_split·easement·civic_envelope·water_setback·town_wall·lock_shape·territory_edge…), `allowed_closures`(계약 Boundary.implementation + fence·hedge; 하나를 WP6이 고른다), `implementation: null`, `level{left_y, right_y, difference_m}`·`level_change`(0.6 m 넘으면 `retaining_wall` 선택지 추가).
- 공유 변은 하나다: 양쪽 필지가 같은 변을 반대 방향으로 참조한다. 담을 양쪽에서 따로 만들지 않는다(V41 준비).
- 성벽 안쪽 변은 `fortification`만 허용, 문 구간은 `gate_opening`(L2 opening id). WP5는 성벽 개구부를 새로 만들지 않는다.
- **수구 요청**: 길 배수가 성벽에 닿았는데 수구가 없으면 `revision_requests[]{target:"WP6/수구", reason:"wall_outlet_needed", data.xz}` — WP6이 수구 Opening을 만들 자리다.
- 통행권(`easements[]`)은 경계가 아니라 면이다(수혜 필지·폭·양끝 입구).

### WP8(L6–7 집 짜임·단차)이 받을 것

- 필지의 `buildable`(쓸 땅 ∩ 필지), `zones.rear_garden`, `frontage{street_hierarchy, width_m}`, `depth_m`, `household`(계급·생업은 `households[]`).
- `axes`는 null이다: 방위는 L6에서 남향을 가중치로만 정한다(K6). `yards`도 null(L6).
- 변의 `level`은 정지 전 지형값(시험)이다. 단차·옹벽·배수 해결은 WP8 몫이다. 경사 0.5 % 미만 길 배수는 `needs: grading_contract_or_culvert`.
- 장터·빈터의 상태(`activity_sites[]`: 평시/장날, 평시/조련/활쏘기)는 상시 형상이 아니다.
