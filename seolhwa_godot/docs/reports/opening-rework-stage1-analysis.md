# 최초 플레이 개편 — 1단계 분석(조사·차이 분석)

기준 문서(우선순위 순): `seolhwa/docs/opening/Opening_Experience_Direction_Plan_v1_0.md`(기획) → `Main_Story_Script_Part01_v1_0.md`(대본) → `Planning_Baseline_v5_17_Archived.md`(참고).
변환 확인: docx `word/document.xml`의 표 수가 md와 같다(기획 11=11, 기준서 75=75, 대본 0=0). 글자 수도 비슷해 변환에서 빠진 표·본문은 없다.
시작 HEAD `f2398ba`. **이 단계에서는 게임 코드를 바꾸지 않았다.**

> 검증 범위: 아래 사실은 코드를 직접 읽고 확인했다(title_menu, onboarding, case_registry, story_director 시작부, story_ui 입력·title_card, namwon_case 도입부, namwon_data 머리·앵커·S0000~S0003, fast_travel.gate_for, region_map 머리말, camera_rig, run_story_tests.sh).
> 지도 줌 내부 동작, 말 자동 하차 거리, 남원 건물 배치 좌표는 이 보고서에서 **확정하지 않았다**. 2·4·5단계 첫 작업으로 실측한다(§6).

## 1. 지금 첫 플레이(확인된 사실)

| 순서 | 지금 | 파일 |
|---|---|---|
| 새 게임 | `Progress.reset_all()` 뒤 남원이면 `S.reset()` → 다음 프레임에 사건 `start_event`. 다른 곳이면 `NAMWON_START (-2952,184)`로 이동 | `title_menu.gd:_new_game` 275 |
| 사건 고르기 | 한 공간에서 한 번에 **사건 하나**(StoryRunner 하나). `SPACE_CASES.JL_NAMWON_UNBONG = ["namwon","namwon_chunhyang"]`. 요구가 맞고 안 끝난 첫 사건 | `case_registry.gd:choose` |
| S0000 | 검은 화면, 이겸의 세 문장 → 기록책 「남원」 → 동문 밖 약 250m 길 위(`s0000_start -2898.5,150.6`)에서 화면이 열림 | `namwon_case.prologue_open` 382 |
| S0001 전경 | 플레이어가 `s0000_vista (-2952,184)` 10m 또는 주막 40m 안에 들면: 동문으로 카메라 glide 3.0초 → 「남원」 → 「설화록」(2.6초) → 복귀 3.0초. Esc·Space·Enter로 건너뜀 | `namwon_case.vista` 436, triggers `s0001_vista(_late)` |
| 튜토리얼 | onboarding CORE = MOVE(5m)·RUN(2초)·INSPECT·TALK·JOURNAL(사건이 선 뒤)·MAP(들은 곳이 지도에 적힐 때)·COMBAT_DODGE·GUARD. 행동해야 끝나고, 기다리는 핵심 안내는 `ONBOARD_PENDING`에 저장 | `onboarding.gd` |
| 주막 | 동문 밖 주막 `tavern (-3005,231)`, 주모 물음이 물음을 연다 → 이겸 연결 → 사건 「산길의 실종」 → R 기록책 → 북쪽 고갯길 '들음' → M 지도 | `namwon_data` S0002 |
| 고을 막음 | `travel_gate.leave_space_until = CASE_NAMWON_COMPLETE` — 오누이를 끝내기 전엔 **다른 공간으로** 역마·깃발을 못 쓴다. 같은 공간(여원재·운봉 포함) 안 이동은 막지 않음 | `fast_travel.gate_for` |
| 춘향 | `requires: CASE_NAMWON_COMPLETE && CASE_HANYANG_BOOKSHOP_COMPLETE` | `namwon_chunhyang_data.gd:30` |
| 이겸 줄기(기존) | 오누이 끝 노인 “한양 간다고 했지” → `MAIN_MASTER_TRACE=HANYANG` → … → 함흥 함관령 옛 역참에서 이겸 재회 | `namwon_case.gd:3270`, `world-scenario.md:199` |
| 대화 입력 | `story_ui._input`: 선택지 ↑↓/W·S/1~9/E·Space·Enter, 대사 E·Space·Enter·좌클릭. `busy_input()` = modal·journal·_cooldown. R은 `not ui.modal`일 때만 | `story_ui.gd:441`, `story_director.gd:321` |
| 제목 카드 | `title_card(text, sec, size)` — 들어옴·나감 0.6초 고정(먹 번짐 없음). 「설화록」은 붓글씨 로고 | `story_ui.gd:949` |
| 카메라 | 40° 고정 yaw(남→북), 대화 TALK pitch 38·거리 13.5·fov 38, `shot{pos,look,fov}` 각본 시점, `glide(sec)` | `camera_rig.gd` |
| 시험 | `tools/run_story_tests.sh -l` = **73개**. 시험마다 `--savefile=user://st_<이름>.json` — 실제 저장(`user://progress.json`·칸·play_*)과 따로 | 같은 파일 |

## 2. 요구 → 지금 → 차이 → 제안 → 단계

| # | 기획 요구 | 지금(파일/함수) | 차이 | 제안 | 단계 |
|---|---|---|---|---|---|
| R1 | 새 게임 시작 = 남원읍성 안 이겸 거처(실내) | `title_menu._new_game` → 오누이 S0000(동문 밖 길) | 시작 장소·사건이 다름 | 새 사건 `main_p1`의 `start_event` P00. `NAMWON_START`를 거처 문 앞 앵커로(거처 좌표는 5단계 실측 뒤 잠금) | 2·5 |
| R2 | 오프닝 비조작 ≤25초(권장 18~22), O-01~O-06 쇼트 3.0/3.5/4.0/3.5/4.0/2.0초, 스킵 → 대사 기록책 요약 | `prologue_open`은 검은 화면 + 글. 쇼트 큐 없음(`rig.shot`·`glide`는 있음) | 초 단위 쇼트 실행기 없음 | `cinematic_shots_main_intro.json` + 작은 실행기(기존 `rig.shot`·`glide`·`ui.letterbox`·`_sw` 건너뛰기 재사용). 길이 ±0.2초 로그 시험 | 2 |
| R3 | 인게임 타이틀: 집 밖 첫 전경 조망에서 4.0초 + 퇴장 2.0초, 먹 번짐 0.5초, 한 번만 | 오누이 `vista`: 시작 ~1분 안에 「남원」+「설화록」 | 시점·길이·연출 다름 | `title_card`에 fade_in/fade_out 인자(기본값은 지금 그대로 — 오누이 불변) + 먹 번짐. 트리거: P01 끝난 뒤 집 밖 전경 자리, 깃발 `MAIN_TITLE_DONE` | 2·3 |
| R4 | 튜토리얼 U01~U10 순서(이동3m→시점25°→살펴보기→대화→기록→지도→표식→경로→역마→전투) | CORE MOVE 5m→RUN 2초 →INSPECT/TALK→JOURNAL→MAP→전투 | U02 시점·U07 표식·U08 경로·U09 역마 없음. MOVE 5m vs 3m. RUN이 바로 붙음 | CORE에 `LOOK`·`MAP_PIN`·`MAP_ROUTE`·`RIDE_OFFER` 키 추가. 사건이 `onboard_order`를 선언하면 그 순서·문턱 사용, 없으면 지금 그대로(오누이 시험 불변). RUN은 main_p1에선 집 밖에서 | 2 |
| R5 | 기록책 조사: 세 물건(기록책·신발·장부), 편지 비교 UI(셋 중 둘) | `problems.gd` inspect/compare/decide, `examine`, `clue kind fact/heard/guess` | 비교 '셋 중 둘 짚기' UI 없음 | 비교는 Problems `compare`(needs 2) + 선택지로 구현(새 화면 안 만듦). 실패 힌트 1회 | 3 |
| R6 | 대화 상태 단일 소유권, 선택 뒤 0.15초 쿨다운, 대화 중 M/R/탑승 막기, 끝나면 카메라 0.3~0.45초 복원 후 이동 | `ui.modal`·`_cooldown`·`busy_input` 있음. 지도 M·역마 H가 modal을 보는지는 미확인 | 소유권이 흩어짐 | `story_director.input_owner()` 하나(DIALOGUE/CHOICE/MAP/JOURNAL/RIDE/CUTSCENE/FREE)로 모으고 M·R·H·탑승이 모두 이것을 본다. 연타 100회 시험 | 3 |
| R7 | 지도: 커서 앵커 연속 줌(1틱 ×1.17), 드래그 6px 문턱, 좌클릭 = 핀, 우클릭 = 핀 해제, Tab 보조, Esc 단계 닫기, 줌/중심 유지 | `region_map.gd`: L3/L2/L0 단계 + 휠·+/-·드래그·방향키, `open_pick`은 역참 마부·깃발에서만 | 핀 개념 없음. 줌 앵커·LOD 전환 동작은 4단계에서 실측 | 연속 배율 + LOD는 배율로 자동. `waypoint` {space,x,z,label} progress 저장. 클릭/드래그 분리 | 4 |
| R8 | 역마: 지도 목적지 → 경로 계산 → 수동 안내/자동 기승/빠른 이동 구분 → 탑승점 → 자동 → 사건 앞 하차 | `station_keeper`→`open_pick`→`pick_done{warp|ride}`; `horse_ride` 자동 기승·TRAVEL_GATE 하차; `ride_net` 그래프 | 목적지가 역·깃발 노드뿐, 지도 핀에서 시작 불가 | 핀 → `ride_net` 가장 가까운 노드 + 마지막 도보 구간. 기존 하차 규칙(고을·사건 앞)은 그대로 재사용. 역참 마부 경로도 유지 | 4 |
| R9 | 월드 방위 표시(U08) | waymarks(길 표지) 있음, 목적지 방위 표시는 미확인 | 핀 방위 HUD 없음 | 화면 가장자리 작은 먹 화살 하나(핀이 있을 때만) | 4 |
| R10 | 이겸 거처·주막 조사점·백운 무대·성황당 제의·옛길 입구 배치 | 남원·여원재 placement 있음. `placement_story_main_intro.json` 없음 | 새 배치·실내 필요 | 새 placement 파일 + story manifest(로더 스키마 밖 키는 manifest로) | 5 |
| R11 | 자동저장: 집 조사·편지·주막 행적·성황당 도착·사자 해결 | `save_keeper` 자동 기록 있음 | 지점 지정 없음 | main_p1 단계에서 `save_keeper` 호출 | 3·6 |
| R12 | 지도 핀 저장·로드 복원, 대화 중 저장/로드 원복 | progress `where`·cases 저장 | 핀 없음 | progress 키 `waypoint` 1개 추가(없으면 무시 — 옛 저장 호환) | 4·6 |

## 3. 충돌과 권장 해결

### C1. 1부 서장이 오누이 S0000을 대체하나, 앞에 오나 — **앞에 온다(권장)**
- 사실: 공간당 사건 하나만 돈다(`case_registry.choose`). `main_p1`을 남원 목록 맨 앞에 두면 끝날 때까지 오누이가 서지 않는다.
- 권장(A): 새 게임 = `main_p1` P00부터. 오누이는 **지우지 않고** `main_p1` 완료(`CASE_MAIN_P1_COMPLETE`) 뒤 서는 두 번째 사건으로. 오누이 데이터에 `start_event` 분기 하나만 더한다: 메인 도입을 봤으면 S0000(검은 화면·세 문장·길 위 시작·순간이동)과 S0001 전경·제목을 건너뛰고 주막 주변대화 트리거로 시작. 메인 도입을 안 본 옛 저장·시험은 지금 그대로.
- 대안(B): 서장 P00~P03만 첫 사건으로, 1장 M101~M105는 오누이 뒤. → 여원재로 떠나는 흐름이 오누이에 끊긴다(사용자 요구 '여원재 방면 이동'과 어긋남).
- 대안(C): 한 공간에 사건 둘을 동시에 돌리게 등록부를 고침. → 러너·저장·시험 전체에 위험이 크다. 권하지 않음.
- 영향: 오누이 시작이 1부 완료(약 60~90분) 뒤로 밀린다. 춘향은 그대로 오누이·한양 뒤.

### C2. 이겸 거처·편지·여원재 방향 ↔ 오누이(동문 밖 주막)·춘향
- 대본 P02 짚신 손님 “**북쪽** 산마을”, 오누이 주모 “**북쪽 고갯길**”. 기준서 v5.17 QA도 “남원 북쪽 전주길의 F49 위치를 운봉·인월 메인 길목과 혼동하지 않았는가?”를 묻는다. 여원재는 남원 **동쪽**.
- 권장: 1부 대사 방위만 “동쪽 고개(여원재) 너머 산마을”로 고친다(대본 의미 불변, 방위 단어만). 오누이의 북쪽 고갯길은 그대로.
- P02 ‘솔잎 주막’: 오누이 주막(-3005,231)을 같이 쓰면 주모 대사가 겹친다. 권장: 오누이 주막과 다른 기존 주막/장터 건물을 쓰고 인물만 새로(주막 주인·짚신 손님·밥 먹는 손님). 새 주막 건물은 만들지 않는다(기획 §7). 후보는 5단계 실측에서 잠금.
- 이겸 기존 줄기(오누이 → 한양 → … → 함흥 재회)와 새 메인(운봉 옛길 실종)이 정사(正史)로 어긋난다 → **사용자 결정 D2**. 이번 개편은 기존 사건 데이터(`MAIN_MASTER_TRACE` 등)를 바꾸지 않고, 메인은 새 변수 `MAIN_P1_*`만 쓴다.
- 오누이 주인공 호칭 “나그네/길손” — 대본도 “이겸의 **숙소**”라 둘 다 떠도는 기록자로 읽혀 충돌 아님.
- 춘향 게이트(`requires`)는 손대지 않는다.

### C3. 지도/웨이포인트/역마 ↔ 제작 규칙 C04·C65·C69·C70
- C65(UNKNOWN/KNOWN/VISITED 세 단계)는 `region_map` 머리말에 구현돼 있다. 권장: 핀은 KNOWN·VISITED 육지에만 직접, UNKNOWN 칸은 핀은 꽂되 이름 없이 “모르는 곳”(기획 §9 ‘길을 직접 확인해야 한다’ — routes_done 정책 유지).
- 자동 기승은 지금 처럼 큰길(`ride_net`)만. 핀이 산길이면 가장 가까운 안전 하차점까지만 + 도보 안내(순간이동 없음).
- 빠른 이동(가 본 역 건너뛰기)과 자동 기승은 지도에서 다른 단추로.
- C04·C69·C70의 정확한 문구는 이 보고서에서 다시 인용하지 않았다(4단계 착수 때 `CITY_ROUTE_PRODUCTION_RULES_v1.0.md`와 대조 — 어기는 변경은 하지 않는다).

### C4. 제목 타이밍 ↔ 오누이 전경 제목
- 권장: 메인 새 게임에서는 오누이 전경·제목을 띄우지 않는다(C1 분기). 메인 제목은 P01 뒤 집 밖 조망에서 한 번(4.0+2.0초). 오누이를 옛 흐름으로 시작하는 저장·시험은 지금 그대로.

### C5. 튜토리얼 순서 ↔ onboarding CORE
- CORE 키·`ONBOARD_*_SEEN` 저장 형식은 그대로 두고, 사건별 순서·문턱(`onboard_order`, MOVE 3m)만 더한다. 이미 SEEN인 키는 다시 띄우지 않는다(옛 저장 호환). RUN은 집 밖에서, 전투 K·L은 첫 실제 전투에서만(이미 그렇다).

### C6. 스킵 키
- 기획 “Esc 길게 0.8초” vs 지금 `skippable`이면 Esc·Space·Enter 즉시 건너뜀. 권장: 지금 계약 유지(Esc·Space·Enter) — 시험·오누이와 같다. 길게 누르기는 대사 넘기기 E/Enter와 겹치지 않으므로 필요 없음.

## 4. 사용자 결정(셋)

- **D1 1부 범위**: (권장) 이번에 서장 P00~P03 + 1장 M101~M105까지 구현(CHAPTER_1_COMPLETE에서 멈추고 「제2장」 자막). 대안: 서장만(여원재로 떠나는 데서 끝).
- **D2 이겸 정사 충돌**: 기존 줄기(한양 → 함흥 재회)와 새 메인(운봉 옛길 실종). (권장) 이번엔 기존 데이터 불변 + 새 메인 변수 분리, 정리는 2부 기획 때. 대안: 지금 기존 사건의 이겸 대사 수정(독립 설화 손상 위험).
- **D3 오누이 순서**: (권장) 1부 완료 뒤 오누이 시작(C1-A). 대안: 서장 뒤 오누이를 먼저(C1-B).

## 5. 2~6단계 계획

| 단계 | 손댈 파일 | 새 파일·데이터 | 시험 | 크기 |
|---|---|---|---|---|
| 2 오프닝·첫 조작·튜토리얼 | `title_menu.gd`(시작 앵커), `case_registry.gd`(목록 앞에 main_p1), `onboarding.gd`(LOOK·order·문턱), `story_ui.gd`(title_card fade 인자), `camera_rig.gd`(필요 시 쇼트 보간) | `story/main_p1/main_p1_data.gd`·`_case.gd`·`_test.gd`, `cinematic_shots_main_intro.json`, 쇼트 실행기 | `main_p1:intro`(쇼트 길이·스킵·HUD 복귀), `onboarding_rule_test` 확장 | 중(600~900줄) |
| 3 서장·1장 대사·조사·사건·카메라 | `story_director.gd`(input_owner), `story_ui.gd`(쿨다운 0.15), `namwon_data.gd`(오누이 시작 분기만) | main_p1 이벤트 P00~M105, problems(편지 비교·제물·술 증거) | `main_p1:A`(전부), `:B`(최소 경로), `:save`(장면마다 저장/로드), 연타 시험 | 대(1500~2500줄 데이터 위주) |
| 4 지도·웨이포인트·역마 | `region_map.gd`(연속 줌·핀·클릭/드래그), `horse_ride.gd`·`ride_net.gd`(임의 목적지), `station_keeper.gd`(유지), `progress.gd`(waypoint) | 방위 HUD | `map:pin`(줌 20회 앵커 오차 ≤20px, 핀 저장/로드), `ride:pin-yeowon`(하차 규칙) | 대(700~1000줄) |
| 5 배치 | placement 로더(새 파일 읽기 확인) | `placement_story_main_intro.json`, 거처 실내(`interior_space`) | `view:main_intro` 스크린샷, 충돌 검사 | 중 |
| 6 통합 | — | — | 73개 + 새 시험 전부, 새 게임 → 여원재 수동 순회, 옛 저장(test_*_save.json) 이어 하기 | 중 |

## 6. 이겸 거처·사건 장소 후보(좌표는 5단계에서 잠금)

기획 §7의 확인값: 남원읍성 (-3227.8, 248.8), 관아 외삼문 (-3162.1, 239.5), 여원재 아랫주막 (-322.08, -889.46) `ea_yj_jumak_01`, 성황당 (36.64, -988.14) `ea_yw_seonghwangdang_01`, 여원재 주막 (75.29, -985.8), 운봉 주막 (900, -830) `ea_ub_jumak_01`. 코드에서 확인한 값: 동문 앵커 (-3135.3, 248.8), 오누이 주막 (-3005, 231), 오누이 시작 (-2898.5, 150.6).
**이 보고서에서는 placement JSON과 대조를 마치지 못했다** — 이 값들은 미검증이다.

| 장소 | 후보 원칙 | 확인할 것 |
|---|---|---|
| 이겸 거처(P00~P01) | 읍성 안 동문 쪽, 관아(춘향 사용)·광한루와 떨어진 작은 초가/기와 한 채, 실내 `interior_space` | 춘향 PART I/II 사용 건물 제외, 문 방향, 첫 3m·조사물 2개 |
| 전경·제목 자리 | 거처에서 동문으로 나가는 길 위, 읍성·요천이 보이는 곳 | 오누이 `s0000_vista`(-2952,184)와 겹치지 않게 |
| 솔잎 주막(P02) | 오누이 주막이 아닌 기존 주막/장터 건물 | 오누이 주모 15m 주변대화 범위 밖 |
| 도사 광고판(P03)·백운 무대(M101) | 여원재 아랫주막 인근 길가 | 길 그래프와 충돌 없음 |
| 제단(M102~M104) | 여원재 성황당 기존 배치 재사용(중복 소품 금지) | 경사·식생 |
| 옛길 입구(M105) | 성황당 옆 도로에서 갈라지는 작은 길 | 도깨비 길(2장)과 분리 |

## 7. 위험과 대비

| 위험 | 대비 |
|---|---|
| main_p1을 앞에 두면 오누이 시험(namwon:A/B/C/onboard/observe·continue:*·talk:namwon·map:known-namwon·view:namwon)이 메인을 고름 | 시험은 `--storytest=namwon:*`가 이미 사건을 고정(`prefer`). continue 시험은 픽스처 저장에 `CASE_MAIN_P1_COMPLETE` 넣거나 시작 분기 확인. 매 단계 73개 전부 |
| 옛 저장(오누이 진행 중)이 이어 하기에서 메인으로 바뀜 | choose 전에: 오누이 `cases.namwon.phase`가 start가 아니면 메인을 건너뛴다(옛 저장 보호 규칙) |
| 새 게임 `reset_all`이 실제 저장을 지움 | 시험은 `--savefile` 별도 파일만. 실제 progress·칸·play_* 열지 않음 |
| 연속 줌이 이름표 겹침 솎기·MAPTEXTTEST를 깸 | 글 크기 화면 고정 규칙 유지, map:text-zoom 시험으로 확인 |
| 지도 핀 → 말이 길 없는 곳에서 맴돎 | 큰길 노드까지만 자동, 나머지 도보 안내. 시험 `ride:pin-offroad` |
| input_owner 도입이 춘향·전투 입력을 바꿈 | 기존 조건(`ui.modal` 등)을 감싸기만, 동작 동일 확인(talk:*·namwon_chunhyang:*) |
| title_card 변경이 오누이 「설화록」 시험(onboard_test:535)을 깸 | 기본 인자값 = 지금 값 |
