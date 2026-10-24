# settlement v2 — WP4 지형·물 데이터층 (settlement-v2-wp4-terrain-water)

2026-10-25 · 브랜치 `claude/settlement-v2` · 감사 문서 20 §5 WP4, 사양 16(GEO-01–07)·01(NAT-01–04·06)·19(C01–C05)·21(지역 프로필). 게임 런타임·`region_data` 변경 없음. Codex 교차 검토는 하지 않았다(이 문서의 판단은 Claude 단독).

## 1. 무엇을 추가했나

굽기 순서는 `지형·물 → 이동과 생업 → 정착 기능 → 틀`이다(`site.analyze`에서 지형·물 층을 만든 뒤 이동층을 만든다). 결과는 `plan.json` 옆 **`terrain-water.json`**(`terrain-water/1`, 스키마 `schemas/terrain-water.schema.json`)과 `terrain-fields.npz`에 쓴다. `plan.json`에는 `terrain_water{file, revision, summary, checks}`와 물길별 `site.water_features[].reaches[]`만 둔다.

| 모듈 | 내용 |
|---|---|
| `terrain.py` | 8 m 분석 격자(2 m 높이의 블록 평균, 1 km 여유 포함). 지도 물은 2 m 낮춰 경로를 따르게 하고(stream burning), 바다는 유출구다. 우선순위 채움 + ε, 2 m보다 깊은 닫힌 오목은 채우지 않고 내부 유역 끝으로 둔다. D8, 상류 면적, 배수선(≥20,000 m²)을 합류에서 구간으로 나눈다. 지도 물 한 덩어리 = 배수 단위 하나다. 배수선 없이 가장자리로 흩어지는 사면은 연결 덩어리로 묶는다(평행 사면 띠가 가짜 분수계를 만들지 않게). **능선** = 상·하류 관계가 아닌 두 유역의 공유 경계다(상·하류 유역 경계는 골을 가로지르므로 제외). 유출구가 다르면 `main`, 같으면 `spur`(지능선), 기복 없으면 `flat_divide`. **안부** = 능선 위 내부 최저점이며, 능선 따라 양쪽 상승 ≥4 m이고 능선을 가로지르면 양쪽이 낮아야 한다. 지도 고개(`passes`)는 120 m 안에서 맞추고 옮기지 않는다. **봉우리**를 찾는다. **지형 위치**는 평지/곡저/산록 완경사/사면/능선/안부/봉우리/물로 나누며, 경사·HAND(배수선 위 높이)·기복·바닥까지 거리로 정한다 |
| 〃 지면(2 m 작업 창) | 절벽 후보/노출 암체/너덜/모래톱·자갈/충적/흙 덮인 사면. 입력은 **원지형 경사**(게임 높이 remap을 되돌림 — 남원의 세로 ×2 때문에 게임 경사로는 반선 사면 중앙값이 45°가 나왔고, 되돌리면 27°), TPI30 볼록, 지도 바위·모래톱 분류, HAND, 절벽에서 최급경사로 40 m 붕락 경로다. **암종은 분류 입력이 아니다**(GEO-01). 암종은 `rock_type{candidates, grade, status, used_for_classification:false}`로 기록만 한다. 절벽에는 상·하단 접촉, `heightfield_representable:false`, 내부(동굴) `null`+이유를 둔다. 너덜에는 공급 절벽 ID가 있다 |
| 〃 서식(HabitatPatch) | 토지 이용 덩어리 → 관리 유형 자리표시. 경작지·마당(논·밭·마을 터)만 토지 이용에서 `cultivated_yard`로 정한다. 숲·대숲·초지는 `unknown`이고 후보 목록(자연림·보호림·마을숲·이용림·방치지)을 둔다. 지역 숲 기록(21)을 첨부하고 유역 ID와 잇는다. 값은 지어내지 않았다(WP10 몫) |
| `water.py` | WaterReach: 지도 물길을 지도 수면으로 방향 잡는다(평탄하면 "자료 순서, 미상"). 10 m 측점마다 나누고, 합류·400 m에서 측점 공유로 끊는다. 한 ID에 **종단**(수면·설계 하상·중심 지형·폭), **횡단**(높이 자료 지형 ±80 m + 설계 수로 + 둑 꼭대기), **평면**(중심선·폭·굴곡·합류·건널목)을 둔다. **하상 유형**은 경사·골 폭 비·둑 옆 바위·지도 모래톱으로 정한다(이름 아님). 유형: 암반/계단·소/여울·소/충적. 혼합 비율은 전부 `null`+이유다. **흐름 구간**: 급류·낙차(국소 급변)·합류·장애물(건널목)만 거품 원인이고, 잔잔 구간은 거품이 없다. 역경사는 실패로 두되, 닫힌 유역 안이면 `still_water_internal_basin` 예외로 **표시**한다. **수위 상태**는 `water.stage_states` 하나에서 온다. 구간마다 젖은 폭·마른 하상·둑 넘음·둑 너머 범람 폭을 낸다. **건널목**: 지도 건널목만 종류별(여울/징검다리/섶다리/돌다리/다리/나루)로 상태 × 수단 통과를 판정한다. 지도에 없는 길–물 만남은 `crossing_candidates`(`applied:false`, L0–2는 여전히 통과 불가)로만 둔다. **상태별 영향**(V67): 건널목·길(열림/젖음/끊김, 수단별)·물가 작업 칸·토지 이용별 잠김·잠금 수 |
| `livelihood.py` | Route에 WP4 채움. `long_profile`(10 m 측점·오름/내림), `width_section.sections`(평탄/사면/급사면, 골쪽 **지지 후보**(강제 아님), 산쪽 **절취면**), `support_drainage`(지도에 없는 배수선 횡단 + 처리 `null`/후보, 지도 건널목, 후보 건널목, 오목점, 젖은 땅), `divide_crossings`(능선·안부·창 가장자리 표시), `catchments_at_ends`, `cliff_traversal_m`. 수단 통과에 절벽 통과 이유를 더했다. 기존 길은 지우지 않는다 |
| `contract.natural_profile` + `regions/natural_profiles.json` | RegionProfile에 `natural.fields` 묶음을 더했다(8권역: 지형·암종 후보·하천 형태·하천 단면·석호·숲 기록·숲 관리). 21 문서의 값·등급·상태·출처 ID를 그대로 옮겼다. **confirmed는 등급 A/B + 출처 ID가 있을 때만**이고 아니면 proposed로 내리고 `downgraded`를 표시한다. U는 `value:null`·unknown이다. 한양 지형(도성도)은 회화라 proposed로 두었다 |
| `regions/region_corrections.json` | 21 §4·권역 §0이 제안한 region.json 수정 33건. **적용 안 함**(`applied:false`). §6에 WP4 관련분 목록 |
| `svg_tw.py` | 03 지형(능선·안부·유역·지형 위치·암체), 04 물(하상 유형·흐름 방향·거품 원인·건널목·상태표·대표 단면+수위선), 05 길(종단 경사 색·지지/절취·배수 접점·분수계 통과) → `combined-terrain-water.svg` |
| `tw.py` | 층 파일 조립·검사, `cli wp4`(교차 V63·V66) |
| 계약 | `contract-v1`에 더하기만 했다: TerrainPatch.landform `foot_slope/summit/water`, HabitatPatch.management `cultivated_yard`(경작지·마당)·`abandoned`(방치지). `cultivated`는 그대로 읽힌다 |
| rules | `terrain.*`·`ground.*`·`habitat.*`·`water.*`(수로·하상·흐름·건널목 규칙)·`routes.*` 49개. 모두 단위·출처·provisional(시험값). 건널목 규칙(여울 깊이·돌다리 높이·섶다리 큰물 철거·나루 운휴)은 지역 건널목 메모의 "가설" 외 근거가 없다 |

## 2. 검사 — 실행한 것만

**게시를 막는 불변식 `WP4.layer`:** 다음을 함께 본다.
- 상태 단일 원천: 구간·영향·범람 화면 = rules = RegionProfile
- ID 중복 없음
- 구간 참조
- 기하 참조
- 층 스키마
- V18

결과: `cli all` 12곳(합성 5·실제 4·실패 3) **모두 통과**했다. L0–2 상태·호수는 WP3 보고와 같다(남원 3호·불국사 0/제안 21·반선 없음·안목 1). `plan.validation` 실패는 0이다.

**V 검사(데이터 수준, 주어진 자료의 발견은 막지 않음 — `kind: finding`):**

| 곳 | V01 | V02 | V03 | V64 | V65 | V66 | V67 | V19 |
|---|---|---|---|---|---|---|---|---|
| syn_terrace | P | P | P | – | P | P | P | P |
| syn_basin | P | P | P | **F** | P | P | P | P |
| syn_ridge | P | P | P | P | P(예외 표시 1) | P | P | – |
| syn_estuary | P | P | P | **F** | P | P | P | P |
| syn_mountain | P | P | – | – | – | – | P | – |
| namwon_eup | P | P | P | P | **F** | P | P | P |
| bulguksa_village | P | P | P | **F** | **F** | P | P | P |
| banseon | P | P | P | –(창 가장자리 1건 제외) | **F** | P | P | P |
| anmok_village | P | P | P | – | **F** | P | P | P |
| fail_* 3곳 | P | P | P | – | water_crossing **F** | P | P | – |

**교차 검사(`cli wp4`, `wp4.json`):**
- **V63 통과.** 합성 3지형(능선·평정 산·분지)에 같은 암종을 가정했다. 지형 위치 분포의 전변동 거리는 0.34–0.38이고, 지면 분포 거리는 0.04–0.26이다. 암종은 분류에 쓰지 않았다. 한계: 합성 기복뿐이며, 실제 같은 화강암 지역끼리 비교한 것이 아니다.
- **V66 대조 통과.** 암반·계단 구간 29개(반선·불국사)와 충적 구간 70개를 비교했다.

  | | 암반·계단 | 충적 |
  |---|---|---|
  | 경사 중앙 | 0.157 | 0.0016 |
  | 골 폭 비 중앙 | 4.0 | 11.0 |

**F의 내용(고치지 않고 보고):**
- **V65 실제 4곳 — 물막:** 지도 하천 폭(예: 만수천 2.5 m)이 높이 자료에 파인 골(약 8 m)보다 좁다. 그래서 수로 가장자리 3 m 안 지형이 평수 수면보다 낮다. 구간 수와 최대 차이:

  | 곳 | 구간 수 | 최대 차이 |
  |---|---|---|
  | 남원 | 31 | 1.25 m |
  | 불국사 | 17 | 0.61 m |
  | 반선 | 14 | 1.59 m |
  | 안목 | 17 | 1.87 m |

  리본 수면 가장자리가 지형 위에 떠 있을 가능성이다. 화면 확인은 하지 않았다.
- **V65 fail_water_crossing:** 두 지도 수면(river_n 상수 3.0, river_x140 지형−1)이 합류에서 어긋나 역류 1구간이 생긴다(픽스처 자료 불일치).
- **V64:**
  - syn_basin `road_e`는 동쪽 언덕 어깨로 주 분수계를 안부 없이 넘는다.
  - syn_estuary `road_coast`는 하구 저지의 낮은 분수계를 두 번 넘는다(인공물 가능성).
  - 불국사: `gampo_road`는 분수계를 6번 넘고, 양끝이 같은 유역이며 안부 통과가 없다. `seokguram_trail`(석굴암 산길)은 9번 넘고 안부 통과가 없다(산정 지그재그). 반면 `gyeongju_ulsan_road`와 `gampo_road_1`은 안부 통과로 P다.
- **V67 관찰:** 상태가 올라갈수록 건널목이 막히고 길이 끊긴다(도보 기준).
  - 남원: 증수(작은 물) 건널목 4/8·길 4, 큰물 8/8·길 5
  - 안목: **평수**에서 여울 1곳이 도보 불가다. 충적 설계 깊이 0.8 m(시험값) > 도보 여울 0.5 m(시험값)이기 때문이다. 즉 시험값끼리의 충돌이며 사실 판단이 아니다.
- **V19**는 구조 검사다. 관리 유형을 바꿔도 지형·물 개정 해시가 그대로이고, 서식이 유역에 연결되는지를 본다. 관리 유형 자체는 아직 unknown이다.

**pytest:** 아래 §5. **결정성:** §5.

## 3. 도면

`docs/reports/settlement-v2-wp4/` JPG 10장(합성 5·실제 4·실패 1). 각 장은 03 지형 | 04 물 | 05 길 종단이다. 03·04는 2 m 작업 창 전체를 보여 준다(분석은 1 km 여유까지 하지만 그림은 작업 창만). 사람 화면 판정은 하지 않았다.

## 4. WP5·WP6이 받을 계약(추가분)

- **읽을 곳**:
  - `plan.terrain_water.file` → `terrain-water.json`
  - Route는 `plan.inputs.movement_livelihood.routes[]`
  - 물길 → 구간: `plan.site.water_features[].reaches[]`
- **Route**(같은 Route 스키마, 필드 추가):
  - `long_profile{station_step_m, chainage[], y[], ascent_m, descent_m, max_station_grade, sustained_grade_10m, local_max_grade, length_m}`
  - `width_section.sections[]{chainage[a,b], section(flat|sidehill|steep_sidehill), valley_side_support(natural_slope|retaining_candidate), hill_side(none|cut_face), uphill}`
  - `support_drainage[]{kind: drainage_crossing|mapped_crossing|unmapped_water_crossing|low_point|wet_ground, chainage, …}` — 배수선 횡단의 `treatment`는 `null`+후보다. WP5가 길·필지와 함께 정한다.
  - `divide_crossings[]{ridge, ridge_kind, saddle, saddle_distance_m, at_window_edge}`, `catchments_at_ends`, `cliff_traversal_m`, `modes[].reasons`
- **WaterReach** `water:<지역>:<물길>:<NN>`:
  - `upstream/downstream`
  - `long_profile.stations[]{chainage, xz, surface_y, bed_y_design, terrain_centre_y, width_m}`
  - `cross_section.representative{offsets_m, terrain_y, channel{width_m, depth_m(measure, 시험값), bed_width_m, bank_ratio}, bank_top_y}`, `surface_above_bank_max_m`
  - `plan{centerline, width_m, sinuosity, confluences, crossings}`
  - `flow{direction_basis, segments[]{kind, chainage, cause, foam}, exception}`
  - `bed_mix{type, basis, components{…fraction:null}}`
  - `banks`
  - `states[]{key, offset_world_m, wetted_width_m, dry_bed_fraction, exposed_bed_width_m, bank_overtopped_fraction, flooded_beyond_bank_m}` — **키·값은 RegionProfile.water_states와 같다**
  - `catchment`
  - `region_hint`(21 필드)
- **건널목** `crossing:<지역>:<id>`:
  - `{class, mapped:true, reach, chainage, states[]{key, modes{foot|pack_horse|cart:{passable, reason}}}, evidence{status, hypothesis}}`
  - 후보는 `crossing_candidate:*`(`applied:false`, `ford_feasible_on_foot_at`, `suggested_classes`)
  - WP6 수구·WP5 물가 작업 자리는 `stage_impacts[]`(상태별 건널목·길·물가 칸·토지 이용 잠김·잠금)를 같은 키로 재검사한다
- **TerrainPatch**:
  - `kind: landform`(8 m) — 지형 위치·유역·지면 분율
  - `kind: ground`(2 m) — 절벽·암체·너덜·모래톱·충적, `rock_body{class, inputs, top/bottom_contact, supply_cliffs, heightfield_representable, interior}`
  - 공통: `rock_type{…used_for_classification:false}`, `structure_dir`(measure null)
- **유역·능선·안부·봉우리**:
  - `catchment:*{drains_to, downstream, outlet_kind, truncated_by_window}`
  - `ridge:*{kind, between, saddles}`
  - `saddle:*{ridge, rise_m, derived, mapped_pass{…evidence_status}}`
- **HabitatPatch** `habitat:*{management(cultivated_yard|unknown…), management_candidates, catchments, region_forest_*}` — WP10이 채운다.
- **RegionProfile.natural.fields**: 21 값·등급·상태·출처. 형태에 쓰지 말 것.
- **필드 파일** `terrain-fields.npz`: coarse_height, upslope_area, drainage, catchment, hand, landform, window_ground. 원점·격자는 배열 안에 있다.

## 5. 실행 기록

(아래 숫자는 이번에 실제로 돌린 것)
- `cli all`(12곳, 실제 4곳은 제안안 포함): 15분 56초, `plan.validation` 실패 0.
- `cli wp4`: V63·V66 대조 통과.
- `tests/test_wp4.py` 8개 통과(3분 42초).
- 전체 pytest **73개 통과**(기존 65 + WP4 8), 12분 18초.
- 결정성: syn_terrace·syn_ridge·syn_estuary·남원 읍(기준안+제안안)·반선(기준안+제안안)을 두 번 구웠고 **98파일 바이트 동일**하다(`settlement-v2-wp4/determinism.json`, png 제외 — 기존 규칙). `wp4.json`은 교차 검사 결과다.

## 6. 남은 문제와 21 수정 제안(적용 안 함)

- **물막(V65):** 지도 폭과 파인 골 폭의 불일치. 처리 방법을 정해야 한다: 리본 폭을 골에 맞출지, 골을 다시 구울지(재굽기는 별도 승인). 런타임 확인 전에는 판단을 보류한다.
- **시험값끼리 충돌:** 충적 설계 깊이 0.8 m > 여울 도보 0.5 m. 지도에 "여울"로 표시된 곳이 평수에 도보 불가로 나온다. 하천 단면 자료(21: river.sections 전 권역 U)가 오기 전에는 사용자 결정 사항이다.
- **분수계 판정의 한계:**
  - 합성 하구의 저지 "주 능선"은 지도 물 낮추기(2 m)의 인공물일 수 있다.
  - 작업 창 가장자리 능선은 V64에서 제외해 보고만 했다.
  - 산정 지그재그(교룡산 길)는 안부 밖 통과가 여럿이다(V64는 안부 통과 1회 이상이면 P).
- **절벽:** 반선 절벽 후보 약 4만 m²의 대부분은 지도 바위 분류(7)와 경사 ≥35°에서 왔다. 높이장 밖 형상은 WP9/런타임 몫이고 만들지 않았다.
- **지도 고개:** 여원재 등은 이번 4곳 창 밖이라 맞춤 검증은 불국사 1건뿐이다.
- **런타임 검사:** Godot `mountain_check 46/0`은 이번에 돌리지 않았다(런타임·region_data 무변경이므로 영향 없음으로 판단했을 뿐 확인이 아니다).
- **21 수정 제안 중 WP4 관련(`regions/region_corrections.json`):**
  - 람천 표기·'임천' 근거 없음
  - 요천 '모래 바닥 얕은 내' 근거 없음
  - 바래봉 철쭉 forbidden 추가
  - 경포호 1870 윤곽이 현대보다 큼
  - 남대천 현대 직강 하도를 1870 하도로 쓰지 말 것 — 안목 구간의 하상 분류가 이 현대 하도 위에서 나온 것이다
  - 강릉 진산(대관령)
  - 만세교 목교 근대
  - 월파루 절벽 위
  - 대동강 배다리 상태
  - 수표교·이간수문 등 누락
  - 산지천 편입 가설 유지
