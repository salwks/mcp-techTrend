# WP7a 건물 서술자 계약 — 보고

2026-10-25 · 브랜치 `claude/wp7a-descriptors`(`claude/settlement-v2` + `claude/integ-bldg-matlight` 병합) · 감사 20 §5 WP7a, 계약 `settlement-v2-contract-handoff.md`.
마을 배치·이야기 내용은 바꾸지 않았다. 게임 화면이 바뀌는 곳은 아래 §3·§4에 모두 적었다.

## 1. 서술자 `building-descriptor/1`

- 만드는 곳: `kit/bldg/descriptor.gd` `describe(params, region_profile)`. 빌더가 가장 가까운 단계를 그릴 때 `building.gd`의 `REC` 훅이 그린 값을 적는다. 서술자용으로 형상을 따로 계산하지 않는다. 놀이 중에는 `REC = null`이라 그리기와 캐시는 그대로다.
- 내보내기: `godot --headless --path . -s res://tools/bldg/descriptor_export.gd -- --out=DIR [--set=presets|samples] [--regionprofile=plan.json]`. 343채에 51초, 8.8 MB.
- 스키마: `tools/settlement/schemas/contract-v1.schema.json`의 `$defs.BuildingDescriptor`. WP1 `Building` 필수 항목에 세부 항목을 더했다. 서술자는 그 자체로 `Building`으로도 통과한다.
- 좌표는 건물 로컬이다(몸채 가운데 땅이 원점, 앞이 +z). 단위는 world_m이고 `scale_applied: true`다.

| 항목 | 내용 |
|---|---|
| meta | stable_id `building:<키>`, provenance(근거 id·생성기·규칙 파일 해시·입력), status `proposed`, lock_scope(`params.spec` 이야기 집은 `shape`), revision(내용 SHA-256 — Python `canonical_json`과 같은 값) |
| type_basis | 프리셋·지역·신분·씨앗·평면형, `evidence`(_calib.gd 보정 항목: 범위·status·출처·지역 프로필) |
| scale | factor 1.2, axes [plan, height], 출처 `RegionProfile.scale_policy.building.factor`, region_profile id·factor, 명세 real_scale |
| column_grid · bay_spacing | 날개마다 x·z 기둥 줄, 퇴기둥 줄, 기둥 [x,z,밑,위], 칸 폭 배열·깊이 배열 |
| structural_bays / function_faces | 구조 칸(기둥 사이)과 기능 면(방·부엌·대청…)을 따로 둔다. 기능 면은 칸 id 목록·넓이·바닥 높이·데움·문 목록을 가진다(HOUSE-01) |
| partitions | 기능 면 사이 칸막이(논리)와 실제로 그렸는지 여부 |
| facades | 면마다 막힘/구멍 구간 [a,b], 구멍 쓰임(door/window/plank_door/vent_window/open_bay/gate/shop_front…)·높이, 두께 0.14, 양쪽 기능 면, 충돌 참조 |
| doors | 폭·문지방·머리 높이, `player_use`, `height_class`(player/measured), 잇는 면 두 개. 바닥 차가 0.32보다 큰 칸막이 문은 사람 길이 아니라고 적는다 |
| floor_base | 기단 다각형·높이·종류, 날개별 기단 윗면·바닥, 칸별 바닥, 댓돌·돌계단, site_fit(경사 대지 맞춤은 WP8, unknown) |
| maru | 툇·쪽마루 면, 받침(퇴기둥 / 독립 기둥 점), 끊김과 이유(agungi_work·wing_join·service_front) |
| sockets | chimney · agungi · hamsil_agungi(형상 없는 가정) · gudeul(방 밑 다각형·높이) · maru_support · entrance/service_door · service(장작·장독·가마솥 등) · anchor |
| heating | 불 계통: 아궁이 → 구들 줄 → 끝 칸, 굴뚝이 그 계통 끝에 있는지 |
| roof_support · roof | 기둥 위끝·창방·도리 높이·받침 줄. 날개마다 처마 외곽, 면별 처마 윗선/밑선, 용마루(메시에서 잼), 물매, 처마→용마루, 낙숫물 줄(박공·회첨 이음은 drains:false), 회첨 |
| members | 주춧돌·기둥(길이)·창방·도리·벽체 넓이·창호 종류별·툇마루·댓돌·계단 단·기단·지붕 평면 넓이·굴뚝·아궁이 |
| collision · condition | 충돌체(id)·걷기 면·footprint, 상태(normal/worn/… 폐가 단계) |

## 2. 배율 하나(K1)

- `_spec.SCALE_CLS`(1.16/1.22/1.2)를 버렸다. `real_scale`은 `tools/settlement/rules/default.json`의 `world.length_scale`을 읽는다. 이 값이 RegionProfile building.factor의 출처다. 읽지 못하면 같은 값의 상수 1.2를 쓴다.
- 평면과 높이에 같은 배율을 쓰고, 프리셋을 해결할 때 한 번만 곱한다. 이야기 집(`params.spec`)은 다시 키우지 않는다.
- `descriptor_export --regionprofile`: 계획서의 factor와 빌더 배율이 다르면 종료 코드 2로 멈춘다. 남원 계획서(1.2)로 343채를 내보내 확인했다.
- SCALE1 검사는 네 값이 모두 같은지 본다: 규칙 값, 상수, 명세 real_scale, 계획서 factor. 또 해결 치수가 프리셋 실측값 × 배율과 같은지(벽 높이·칸 폭·처마)도 본다. 343/343 통과.
- 화면 영향: 서민·중인·양반 집은 1.22 → 1.2(−1.6%), 가난한 집은 1.16 → 1.2(+3.4%), 관아는 그대로다.

## 3. KHS 보정 프리셋(`kit/bldg/_calib.gd`)

모든 값은 실측값(배율 전)이다. status는 `proposed`이고, 근거가 없는 지역은 `unknown`이다. 생성기는 confirmed를 만들지 않는다.

| 지역 프로필 | 항목 | 이전 | 보정 | 근거 |
|---|---|---|---|---|
| 초가 south | 몸채 깊이 | 2.2–2.8 | 2.1–2.3(툇칸 따로) | 낙안 9동 |
| 〃 | rise_k | 0.6–0.95 | 0.72–0.76 | 낙안 |
| 〃 | 처마 내밀기 1.1–1.4·처짐 0.3–0.5·기단 | eave v2 그대로(드나드는 문 머리 +0.10, DOORCLEAR) | | 낙안 |
| 양반 south(호남) | 칸 | 2.5–2.9 | 2.0–2.4 | 김명관 |
| 〃 | 벽 높이 / 기단 | 2.3 / 장대석 0.55–0.85 | 2.0–2.2 / 0.17–0.28(한 단) | 김명관 |
| 〃 | 툇칸 / rise_k / 처마 eave_dy | 0.9 / 0.55–0.66 / +0.26 | 1.0–1.2 / 0.88–1.0 / −0.25~−0.05 | 김명관 |
| 양반 central(서울) | 칸 / 툇칸 / rise_k / eave_dy | 2.5–2.9 / 0.9 / 0.55–0.66 / +0.26 | 2.4–2.6 / 1.0–1.2 / 0.78–0.95 / −0.15~0 | 연경당·운현궁 |
| 〃 | 기단 | 0.55–0.95 | 그대로(이미 0.87–1.25에 맞음) | 〃 |
| 양반 그 밖 지역 | 칸 2.2–2.6, 툇칸 1.0–1.2, rise_k 0.8–0.95 | | status unknown(전체 권장값을 옮겨 씀) | 없음 |

- 기와 처마 높이는 `giwa_eave_dy`가 아래 한계를 둔다. 두 조건이 있다.
  - 벽 줄에서 지붕 밑면이 도리 윗면 + 0.05 위에 있어야 한다(WALLCLEAR).
  - 걸어 들어가는 집에서는 처마 밑면이 드나드는 문 머리 + 0.10 이상이어야 한다(DOORCLEAR).
- 그 결과 실측 목표(기둥 위끝 −0.4~0)까지는 내려가지 못한다.
  - 호남: 처마 끝이 기둥 위끝 −0.07~+0.12에 있다(배율 후).
  - 서울: 처마 끝이 기둥 위끝 +0.13~+0.19에 있다.
  - 이전에는 +0.31이었다.
- 처마→용마루(배율 후)는 다음과 같다.
  - 호남: 3.8–4.4 m. 실측 ×1.2 = 4.1–4.6 m.
  - 서울: 3.6–4.1 m. 실측 ×1.2 = 2.4–4.0 m로, 우리 값이 범위 위쪽 끝에 있다.
- 용마루 높이:
  - 호남: 7.2–7.5 m. 실측 ×1.2 = 6.7–7.2 m보다 조금 높다.
  - 서울: 7.6–8.3 m로 조금 높다.
- 대청·부엌 칸은 bw의 1.05–1.1배라서 보정 상한을 넘는 칸이 남는다(배율 후 최대 3.1 m).

## 4. 빌더 구조 수정(서술자 검사가 찾은 것)

- **아궁이–구들–굴뚝(V27)**: 남부·북부·산간 초가, 주막, 읍내 기와집은 모든 씨앗에서 굴뚝이 부엌 쪽 끝에 있었다. 부엌 계통과 굴뚝이 서로 맞지 않는 상태였다. 안채 남부는 6채 중 5채, 사랑·아래채·행랑 일부도 같았다(300채 중 141채).
  - 고친 방법: `_spec.heat_fix`가 굴뚝을 데운 방 줄의 끝으로 옮긴다. 끝이 비어 있으면 옆에, 아니면 그 방 뒤(`back_bay`)에 둔다. 데운 방이 없는 행랑에서는 굴뚝을 없앴다.
  - `params.spec` 이야기 집은 손대지 않는다.
- **기능 면 room 열쇠(HOUSE-01)**: 같은 room 값을 가진 칸 사이에는 칸막이를 두지 않는다. 살림도 그 면 전체에 한 벌만 둔다. 막힌 앞벽은 충돌체를 트지 않는다. 프리셋에는 쓰지 않으므로 화면은 그대로다.
- **쪽마루 받침**: 간격을 1.6 m 이하로 했다(한 칸짜리 쪽마루는 2.9 m 간격이었다). 받침이 늘어난다.
- **합각 박공 널**: 꼭대기에서 0.1 m 물린다. rise_k를 올리면 두 널이 한 평면에 겹쳐 FACECHECK에서 sarang 전부와 anchae south가 실패했다.
- **기타**:
  - 뒤 굴뚝의 뒷면이 처마 띠와 우연히 한 평면에 놓이면 4 cm 뒤로 민다.
  - 부뚜막 몸 윗면을 덮개 속으로 넣었다(낮아진 호남 바닥에서 문지방과 겹쳤다).
- **compound giwa_house 곳간**: 긴 곳간이 앞 담을 4.5 m 뚫고 나가 있었다. 이전부터 있던 문제다. 배율 통일로 이엉 처마가 4 cm 낮아지자 담 갓이 처마에 닿아 ROOFCHECK에서 드러났다. 앞 담 안에 들도록 칸 수를 줄이고, 한 칸도 들지 않으면 두지 않는다.

## 5. V 번호 결과(`descriptor_check.gd`, 343채 + 구성 시험 2)

| V | 결과 | 메모 |
|---|---|---|
| SCHEMA | 344/344 | Python에서도 343채 모두 `BuildingDescriptor`·V18·revision 일치 |
| V18 | 344/344 | confirmed 없음 |
| SCALE1(K1) | 344/344 | |
| V09 | 344/344 | 서술자 부분: 벽 면이 처마 외곽 안, 드나드는 문 머리 + 0.10 ≤ 처마 밑. 지붕 뚫음·깜빡임은 §6 |
| V27 | 344/344, 경고 139 | 경고는 부엌 계통 끝에 굴뚝이 그려지지 않음, 또는 함실(가정)인 경우 |
| V54 | 40/40(ㄱ·ㄷ) | 기능 면이 지붕 아래에 있고, 넓이 합이 같고, 회첨이 있음 |
| V55 | 344/344, 경고 7 | 경고: 곳간 interior는 사람 키 문인데 안이 막힌 상자 |
| V57 | 1/1 | 남부 초가 부엌을 두 구조 칸(room)으로 나눔: 기능 면 같음, 칸막이 없음, 기둥 줄 +1, 방 문 유지. 처음에는 칸마다 살림이 생겨 문을 막았고, 이를 고쳤다 |
| V58 | 185/185, 경고 15 | 부엌 앞 마루 끊김(agungi_work), 받침, 디딤 단 ≤ 0.32. 경고: 객사 정청처럼 드나드는 문이 없는 채의 보기용 디딤 0.39 |
| V60 | 부분(344 경고) | 땅→기단→바닥 이동만 본다. 경사 대지 바닥 편집은 WP8 |
| V62 | 부분(344 경고) | 두께 기록, 구멍이 기둥 안쪽, 방 넓이만 본다. 두께 바꾸기 시험은 없다 |
| 관아 터 | 5/5 들어감 | `--plan`(syn_terrace) 본채 한 채 미리보기. 배치는 하지 않는다 |

pytest: `test_building_descriptor.py`(13) + contract + units = 72 통과(settle2 venv).

## 6. 기존 검사(전 → 후)

| 검사 | 전(병합 기준) | 후 |
|---|---|---|
| roof_check `--set=all` ROOFCHECK | 6/345(모두 옛 키트 village) | 6/345(같은 옛 키트 6건) |
| WALLCLEAR / DOORCLEAR / EAVEBAND | 0/258 · 0/258(드나드는 문 51, 최소 0.06) · 0/18 | 0/258 · 0/258(최소 0.04) · 0/18 |
| roof_check `--set=ruin` WALLCLEAR | 4/96 | 6/96 — 같은 종류(지붕이 빠진 자리 outside·beam_top). 배율이 바뀌어 꺼지는 칸이 달라짐. 미해결 |
| FACECHECK | 16/304 | 14/304 — 새로 생긴 것: jumak/central/1·2(ㄱ 날개 이음 벽 5 mm 겹침, 배율 탓에 north/1·south/2에서 옮겨 옴) |
| CORNERCHECK | gaps 38, bad 2 | gaps 36, bad 2 |
| 이야기(`run_story_tests.sh first15 talk view`, --kitcache=/tmp/seolhwa_wp7a_kit_cache/) | | talk 5/5·view 1/1·first15 new·onui PASS, first15:skip FAIL — 병합 기준(integ 7003976)에서도 같은 실패(이전부터 있던 것). 실제 저장 progress.json sha·수정 시각 그대로 |

## 7. 시트

`shots/wp7a/choga_ref.jpg`, `choga_door.jpg`, `yangban_ref.jpg`, `yangban_door.jpg`. 낱장은 `tools/bldg/wp7a_shots.sh <tag>`로 찍는다. 화면을 맞추는 방식 때문에 전후 확대가 조금 다르다.

## 8. WP8로 넘기는 것

1. 경사 대지에서 건물별 바닥·기단 편집(V60 전체). 지금 site_fit은 unknown이다.
2. 함실 아궁이를 형상으로 만들고, 부엌 계통 굴뚝이 그려지지 않은 139채를 처리한다. 두 계통이 굴뚝 하나를 같이 쓰는 문제도 있다.
3. 벽 두께가 0.14로 고정이다. V62의 두께 바꾸기와 토석벽(stone_mud)의 실제 두께가 없다.
4. 기와 처마를 실측(기둥 위끝 −0.4~0)까지 내리려면 처마 쪽 지붕 단면(prof_giwa)이나 도리 높이를 바꿔야 한다. 처마 이음 위험이 있어 사용자 결정이 필요하다.
5. 대청·부엌 칸 배수(1.05–1.1)가 보정 상한을 넘는다. 서울 양반 용마루가 실측 ×1.2보다 0.5 m 높다.
6. 옛 키트 `placement_loader plan_scale`(1.16/1.2/1.22)는 이번 단일 배율 밖에 남아 있다.
7. 문제 두 가지가 남았다.
   - 곳간 interior: 사람 키 문인데 안이 막혀 있다.
   - 창 앞 충돌 틈: interior 방의 창 앞면에 0.9 m 틈이 있다. 이전부터 있던 것이고, 문이 아닌 앞면 중 손댄 것은 "wall"뿐이다.
8. 남원에 적용할 때는 `params.spec` 이야기 집과 rollout 배치가 바뀌지 않았는지 고지도와 함께 대조한다.
9. 서술자 → civic_reserves 실제 배치(문 겹·마당 묶음)는 WP7b다.
