# travel 보고 — 자동 기승·TRAVEL_GATE·역마 (2026-10-05)

기준: `seolhwa/docs/scenario/seolhwarok_TRAVEL_TRANSPORT_IMPROVEMENT_PLAN_v1.0.md`(이동수단 개선안 v1.0) + 총괄 결정 A~E.

| 결정 | 반영 |
|---|---|
| A 권역 안 큰길도 자동 기승 | 권역·노정 모두 region.json/route.json `roads`의 대로·지선을 말 길로. 남원 → 운봉(4.6km 길)도 말로 간다. 권역 안 가 본 고을 사이 역마도 된다 |
| B 카메라는 돌리지 않음 | 배 타기 풍경 시점과 같은 방식(낮은 pitch, yaw가 가는 쪽을 부드럽게 따라감, 내리면 천천히 돌아옴), 걷기보다 멀리(21m·20°). 플레이어 회전 없음 |
| C 소리 없음 | `horse_ride.audio_cue(cue, value)` 신호만(아래 §6) |
| D 이야기 길가 장면을 놓치지 않음 | R0101~R0104 반드시 감속(MUST), R05 첫 통과 사건 넷 앞 하차, 눈보라 강제 하차, 사건 트리거 앞 70~200m 하차 |
| E TRAVEL_GATE는 있는 데이터에서 생성 + 손 고침 | `tools/region/make_travel_gates.py` → `region_data/travel/<공간>.json`, 손 고침 `region_data/travel/overrides.json` |

## 1. 실행
```bash
python3 tools/region/make_travel_gates.py            # 모든 권역·노정(약 20초) — region.json·route.json·interiors·배치가 바뀌면 다시
godot --path seolhwa_godot res://scenes/region.tscn -- --region=JL_NAMWON_UNBONG   # 남원 동문 앞 큰길에서 E
# 시험(헤드리스, 시험만 4배 빠르게)
godot --headless --path seolhwa_godot res://scenes/region.tscn -- --region=JL_NAMWON_UNBONG --ridetest=namwon_eup:unbong_eup \
  --ridefixture=res://story/hwangju/test_post_hanyang.json --ridetime=4 --notitle --savefile=user://rt.json
tools/run_story_tests.sh ride fast                   # 자동 기승 6 + 역마 3
```

## 2. 데이터 — `region_data/travel/<공간 id>.json`
생성기가 있는 데이터만으로 만든다(공간 20개: 권역 8 + 노정 12).
- **graph**: 대로·지선(뱃길 `ferry` 빼고) 8m 점 + 이웃. 길 끝은 다른 길 12m 안 점에, 가운데 엇갈림은 4m 안 점끼리 잇는다(갈림). 40m 넘게 물 위로 가는 구간(배로 건너는 곳)은 끊는다 — 말은 물을 건너지 않는다(여울·섶다리·돌다리는 짧아 그대로). `city`: 도시(읍성 core·도성 성곽 다각형) 안 점 — 길 찾기가 들어가지 않는다.
- **nodes**(거점): 고을 settlements(읍성 CITY·장시 MARKET·마을 VILLAGE·주막/쉼터/원 INN·역 STATION·나루 FERRY·사찰 TEMPLE·성황당 SHRINE, 자동 들마을 HAMLET), 권역 passes(PASS), 노정 stops(type → 종류), 포털 끝(ROUTE_END — 노정 파일 + region.json portals, 10m 안 중복은 하나), 배 나루 양 끝(BOAT — crossings 나루 `ends`), 굴·큰 실내 입구(CAVE — `region_data/interiors`), 큰길 가 주막 키트(배치 `village/jumak*`, 이름은 가까운 고을 + "길 주막").
  - 구역 zone: 원(radius_m) / 사각형(읍성 core) / 다각형(도성 성곽 walls).
  - **어귀 gates**: 큰길이 구역 경계를 지나는 곳에서 바깥으로 10m(도시는 18m — 성문 앞) 물러선 길 점. 길이 구역을 안 지나면 150m 안 가장 가까운 길 점(그 뒤는 걸어서). 도시 안 거점(한양 북촌·운종가 등)은 어귀가 없다(성문 앞에서 내려 걷는다).
  - `fast`(역마 거점)·`mount`(말 타는 곳)·`arrive`(역마 도착 자리 = 첫 어귀).
- **gates**(§25 TRAVEL_GATE): `GATE_ID·ROUTE_ID·GATE_TYPE(CITY·VILLAGE·PASS·FERRY·FOREST·TEMPLE·EVENT·COAST·CAVE·MARKET)·POSITION·TRIGGER_RADIUS·AUTO_SLOW·AUTO_DISMOUNT·EVENT_ID·REENTER_RIDE_ALLOWED`.
- **stops**(§26 이동 이벤트): `TRAVEL_EVENT_ID·EVENT_TYPE·TRIGGER_POSITION·zone·WEATHER_CONDITION·TIME_CONDITION·STOP_POLICY·EVENT_ID·ONE_TIME·SLOW_SPEED·MUST` (+ 손 고침 `FIRST_VISIT_ONLY·WHEN·APPROACH_M`).

| 거점 종류 | 지나갈 때 정책 | 감속(m/s, 최고 18) | 역마 | 말 타는 곳 |
|---|---|---|---|---|
| 도시(읍성·도성) | FORCED_STOP — 성문 앞 하차, 성 안에 말을 들이지 않음 | – | O | O(성문 앞) |
| 장시 | OPTIONAL_STOP | 6 | O | X |
| 마을·주막·역·노정 고을 | OPTIONAL_STOP | 9~10 | O | O |
| 여울 나루(노정 걸어 건넘) | OPTIONAL_STOP | 7 | O | O |
| 배 나루 | FORCED_STOP(배는 걸어서 오른다) | – | O | O |
| 절·굴 입구 | FORCED_STOP | – | 절 O | X |
| 고개·성황당·바닷가 | OPTIONAL_STOP | 10~11 | 이름 있는 고개 O | X |
| 노정 끝(포털) | FORCED_STOP — 공간 넘어가기 전 | – | O | O |
| 노정 볼거리 sights | encounter 등급 A 8 · B 10(OPTIONAL_STOP), C·D PASS | | X | X |

- **노정 필드(§24)** `ride`: `ROUTE_ID·START_NODE·END_NODE·FIRST_VISIT_REQUIRED·AUTO_RIDE_ALLOWED(강 뱃길은 false)·BASE_RIDE_SPEED·WEATHER_SPEED_MOD·TRAVEL_GATES·OPTIONAL_STOPS·FORCED_STOPS·FAST_TRAVEL_NODES·SCENIC_BEATS`. `FAST_TRAVEL_UNLOCKED`는 저장 상태라 엔진이 정한다(§4).
- 날씨 속도(`WEATHER_SPEED_MOD`): 맑음·흐림 1, 안개 0.9, 강풍 0.92, **비 0.85**, 눈 0.75, 폭풍우 0.7, **눈보라 = 강제 하차**.
- 전국 지도용: 권역 `projection`, 노정 `geo_line` + 거점 진행도 `t`.

### 손 고침 `overrides.json`
| 공간 | 고침 |
|---|---|
| 삼남대로(R01) | **R0101** 오수·**R0102** 전주·**R0103** 곰나루 소문 구역(반경 26~30, 5.5m/s), **R0104** 천안삼거리 박규상 객주 수레(반경 22, 3.5m/s) — 모두 `MUST`(설정 '자동 감속 끔'에도 감속) |
| 영남대로 / 경흥대로 / 관동대로 | 문경새재·철령관·치악산 기슭 `FORCED_STOP` + `FIRST_VISIT_ONLY`(처음 지날 때만 관문 앞 하차 — §18) |
| 평양→함흥(R05) | 쓰러진 말·잘못된 이정표·눈에 묻힌 짐·세 갈래 발자국 `FORCED_STOP`, `WHEN: fn('r05_on')`(평양 사건 뒤 첫 통과일 때만), `APPROACH_M` 70~90 |

### 실행 중 이야기 자리(엔진이 사건 데이터에서 바로)
조건(when)이 매 순간 바뀌어 생성기가 아닌 엔진이 뽑는다(`horse_ride._story_points`, 0.5초마다).
- 사건 트리거(`triggers` steps/event) → **트리거 반경 바깥 100m 앞 하차**(70~200 범위), 하차 뒤 EVENT_APPROACH. 엿듣는 대사(`ambient`) → 감속.
- 조건부 조사 대상(`objects` when이 "true"가 아닌 것) → 반경 +6m 바깥 70m 앞 하차.
- 소문(`rumors_data`, 이번에 아직 안 들은 것) → 들리는 반경 10m 앞부터 자막 4.5초 동안 5m/s.
- 길가 장면(`vignettes_data`, 아직 안 본 것) → 반경+8m를 3.5m/s.
- 사건 접근 구간(트리거 + 접근 거리 × 0.9 안)에서는 다시 탈 수 없다(걸어서 살핀다).

## 3. 엔진 — `scripts/region/horse_ride.gd`(새), `ride_net.gd`(새), `fast_travel.gd`(새), `ride_test.gd`(새)
상태(§23): `ON_FOOT → MOUNTING → AUTO_RIDE ⇄ RIDE_SLOW → DISMOUNTING → (EVENT_APPROACH) → ON_FOOT`, `FAST_TRAVEL`(역마 창).
- **타기(§13)**: 큰길 중심선 9m 안 + (권역) 말 타는 곳 45m 안(거점 어귀·주막·역·성문 앞·노정 끝·큰길 갈림 / 방금 내린 자리 40m / 넘어온 포털 곁 60m) — 노정은 큰길 어디서나. 안 됨: 숲·벼랑·대숲 토지이용, 도시·장·절·굴 구역 안, 실내, 배 위, 이야기가 플레이어를 쥔 동안, 사건 접근 구간, 눈보라.
- **안내**: 아래 가운데 `E   말에 오른다 — 운봉 읍치 쪽으로 (약 5분)   ·   Q 다른 곳 2/9`. 목적지 후보 = 길로 닿는 거점 어귀(최대 9). 기본 = 이야기 쪽(사건 자리 400m 안 어귀) → 노정이면 들어온 반대쪽 끝 → 가까운 순.
- **말 오르기**: 말이 길 뒤 12m에서 걸어와 곁에 서고(1.1초), 오르기(0.75초 — 플레이어 그림이 안장 높이로). 처음 한 번 안내 세 줄(`onboarding.once("RIDE")`): "말이 큰길을 따라 저절로 간다 / Space 멈춤·다시 감 · E 내리기 / 갈림길 앞에서는 A·D로 길을 고른다".
- **가기**: 그래프 다익스트라 길(모서리는 차이킨으로 다듬음) 위 s를 속도로 민다. 최고 18m/s(설정 빠름 23), 가속 3.2 · 감속 4.2m/s². 감속 구역·굽이(18m 앞 방향 변화)·멈춤 앞 제동(√(2·a·d), 마지막 몇 m는 1.2m/s)·갈림길 앞 9m/s.
- **멈춤(§32)**: 목적지 어귀, 성문 앞, FORCED_STOP, 사건 앞, 노정 끝, 눈보라(곧 멈춰 내림), 싸움(바로 내림), 이야기 teleport(내린 것으로), 길 위 사람·짐승(1.2초 기다렸다 안 비키면 2.5m/s로 비켜 지남). 놓인 물체 충돌체는 보지 않는다 — 다리 난간을 중심선이 스쳐 멈추던 것(길 데이터는 걷기 시험 막힘 0).
- **입력(타는 중)**: Space 멈춤·다시 감, E 내리기(곧 멈춰 내림 — 그 자리가 다시 타는 곳), 갈림길 110m 앞부터 `갈림길 — A ← 고원·양덕·평양 갈림길 길목 · 그대로: 정평·함흥 방면 길목` — A/D로 고르면 그 갈래 끝 거점으로 다시 길을 잡는다. 입력 없으면 정한 목적지(이야기 쪽)대로. 한 네거리의 두 갈림 점(30m 안)은 하나로.
- **내리기**: 0.7초, 말 옆 0.9m에 내려선다. 말은 왔던 길로 물러가다(3.2초) 사라진다(§14). HUD: "운봉 읍치 어귀에 닿았다", "○○ 성문 앞 — 성 안은 걸어서 든다", "이 앞은 걸어서 간다", "눈보라 — 말에서 내려 고삐를 잡고 걷는다", "길 끝 — 여기서부터 걸어서 넘어간다".
- **그림**: 말 `ride_horse`(앞·옆·뒤), 플레이어 `ride`(앞·옆·뒤)·`mount`·`dismount`. 말이 카메라를 볼 때(앞)는 말이 앞, 나머지는 탄 사람이 앞(카메라 쪽 0.12m). 탄 사람 발밑 그림자는 끈다. 그림이 없으면 주변 말 옆모습(안장 1.32m) + 앉기.
- **카메라**: `camera_rig.riding`, `RIDE {pitch 20, distance 21, fov 38}`, 말 뒤에서 볼 쪽(더 높은 산 쪽, 2초마다)으로 28° 비켜 섬. `ride_k`(오르며 0→1, 멈춤 40m 앞부터 0.35, 내리며 0)로 걷기 시점과 섞어 어귀·사건 앞에서 서서히 가까워진다(§15). 흔들림 `shake_y` = 보통 0.07 · 약함 0.03 · 끔 0m × 속도.
- **LOD**(배와 같이 `region_main._apply_low_view`): 먼 식생 ≤150m, 해 그림자 28m, 근경 타일 반경 1, 틸트시프트 띠 넓게.
- **region_main**(공용, 집중 편집): 만들기·`_update_horse`·`place_rider`·포털/실내 검사를 타는 동안 쉼·도착 자리를 말 타는 곳으로·H 역마 창·시험 인자. **camera_rig·region_map·game_settings·options_menu**도 몇 줄.

## 4. 역마 — `scripts/region/fast_travel.gd`(§10·§11·§27·§28·§29)
- **H**(지도 M에서도 H) → "역마 — 가 본 곳으로" 창. 지나온 노정 포털 곁이면 그 노정 먼 끝을 먼저 고른다(예전 H 건너뛰기 대체). 전국 지도의 숫자 키 역마도 그대로.
- 거점: 모든 공간의 `fast` 거점 중 **가 본 곳**(거점 구역 +10m 또는 도착 자리 30m 안에 들면 `progress.json travel_nodes[공간][거점]`) — §28 중간 거점 단위 해금(`TRAVEL_NODE_*_DISCOVERED`에 해당). 지나온 노정 양 끝은 처음부터 안다(예전 저장 호환).
- **처음 가는 길은 못 건너뜀**: 공간 그래프(권역 ↔ 노정, 갈림 노정 포함) 너비 우선 — 지나는 노정이 모두 `routes_done`이어야 그 너머로 간다. 끝까지 안 지난 노정 안에서는 들어온 쪽으로만. 그래서 제주는 남해 뱃길을 한 번 건너야 열린다(§18). 막힌 곳은 흐리게 "처음 가는 길은 걸어서(말 타고) 가 봐야 한다".
- **연출(§11)**: 오른쪽 지도 — 같은 공간이면 큰길 그래프 위 지금 자리 → 목적지 길(다익스트라), 다른 공간이면 전국 윤곽 + 지나는 노정 geo_line을 이은 선. 2.8초 동안 선이 그려지며 "길에서 약 1일 18시간 — 낮 10시 → 밤 4시"처럼 시각이 흐른다. 걸리는 시간 = 길 거리 ÷ K(0.3) ÷ 7km/h(다른 공간은 경위도 거리 ×1.25). 2시간 넘으면 60% 확률로 날씨를 다시 고른다(강제 날씨면 그대로). 삯 없음.
- 도착: 같은 공간은 암전 0.3초 뒤 그 거점 어귀(말 타는 곳)로, 다른 공간은 예전 넘어가기(`_travel`, fast — 노정을 지나옴으로 치지 않음).

## 5. 시험(모두 헤드리스, `tools/run_story_tests.sh`에 9개 더함 — 전체 36개 모두 PASS, 종료 코드 0)
| 시험 | 확인 | 결과 |
|---|---|---|
| ride:namwon-unbong | 남원 동문 앞 → 운봉 읍치 어귀(4.6km): 어귀 0m·구역 밖에서 하차, 감속 구역 7 | PASS — 게임 시간 6.5분(달리기 16.5분 대비 0.39) |
| ride:r01-park | 삼남대로 끝→끝(2.1km): R0101~R0103 소문 셋·R0104 길가 장면이 나오고 그 구역 속도 ≤ 감속값, **MAIN_PARK_MARK_COUNT 2 → 3**, 말/달리기 ≤ 0.5 | PASS |
| ride:r05-event | 평양→함흥 첫 통과(test_post_act3): 첫 멈춤이 쓰러진 말 트리거 **바깥 100m 앞** | PASS |
| ride:hanyang-gate | 노량진 나루(북쪽 선창) → 한양: **숭례문 앞(성 밖)** 하차, 칠패 장 감속 | PASS |
| ride:fork-yeongheung | 경흥대로에서 영흥 갈림길 A → 고원·양덕·평양 갈림 끝 어귀에서 하차 | PASS |
| ride:blizzard | 함흥 큰길 300m에서 눈보라 → 곧 멈춰 내림, 다시 탈 수 없음 | PASS |
| fast:same-space | 남원 → 운봉 읍치 어귀(약 2.5시간 흐름) | PASS |
| fast:to-hanyang | 남원 → 한양 노량진(삼남대로 지나옴) — 넘어간 장면에서 자리 확인 | PASS |
| fast:jeju-blocked | 남해 뱃길 안 건넘 → 제주목 막힘 | PASS |

말 속도(삼남대로 2.1km, 달리기 직선 7.7분): 감속 줄이기 전 6.5분(0.84) → 최고 16m/s·구역 5m/s 4.0분(0.53) → **최고 18m/s·구역 9~11m/s·소문 구역 짧게 3.75분(0.49)**. 경흥대로 2.1km 3.3분(0.44), 노량진→숭례문 2.4km 4.3분(0.50). 권역 안 남원→운봉 4.6km는 6.5분(0.39). 설정 '빠름'(23m/s)이면 더 짧다.

**fps**(M1, 2048×1536, 창, 맑음 10시, 남원 동문 → 이백 2km 타는 동안): 평균 **102.7fps**(잠깐 57 — 근경 타일 붙을 때 한 번), 헤드리스 시험은 140대. 그림: `shots/region/ride/namwon_eup_ibaek_*.png`(섶다리 건너기·들길·내린 뒤 말이 돌아봄).

## 6. 소리 자리(§16 — 소리 체계가 생기면)
`region_main.horse_ride.audio_cue(cue: String, value: float)`:
`mount` · `hooves_start`(속도) · `gait`(속도 m/s, 0.5초마다 — 말발굽 빠르기·크기) · `slow`(감속 구역에 듦) · `halt`(멈춤·길 막힘) · `event_near`(사건 앞 하차 — 음악 줄이기) · `hooves_stop` · `dismount`.
`state_changed(old, new)`(TRAVEL_STATE), `ride_done(node_id, why)`(why: dest·city·gate·event·end·blizzard·player·blocked).

## 7. 그림 굽기 — `tools/export_ride_frames.js` + `tools/ride_bake.html`
`python3 tools/web_export_server.py 8770` → `http://localhost:8770/__tools/ride_bake.html`(헤드리스 Brave `--dump-dom`, 약 1분) → `data/frames_ride.json`·`frames_ride_horse_0..3.png`·`frames_ride_player_0..1.png`.
- 말(CHR_ANI_002): 웹에 짐승 리그가 없어 주변 짐승처럼 캔버스 먹선·담채. 주변 말의 1.3배(등 1.87m — 사람 2.06m에 맞춤). 옆(왼쪽을 봄 — 오른쪽은 뒤집기)·앞(긴 얼굴·흰 코잔등·귀·굴레·등자)·뒤(엉덩이 두 둥치·꼬리) × idle 4 · walk 6(네 박) · run 6(구보 — 몸이 앞뒤로 흔들림·꼬리 뜸). 붉은 언치·가죽 안장·등자·고삐.
- 플레이어: 웹 굽기 엔진에 동작만 더함 — `ride`(앞·옆·뒤 6장 고리, 무릎 굽혀 걸터앉아 두 손 고삐, 걸음 따라 들썩임), `mount`·`dismount`(옆, 서기 → 다리 들어 올림 → 넘김 → 앉음). 엉덩이가 원점. 지팡이는 안장에 꽂아 안 보인다.
- `data/`는 git 밖 — 다른 맥에서는 한 번 굽는다.

## 8. 남은 것·가설
- 마부·마방 사람(선택)은 넣지 않았다. 말 타는 곳에 별도 키트 없음(어귀·주막·역 자리 그대로).
- 말 그림은 거친 먹선(옆모습 목·머리 꼴이 조금 뻣뻣함). 앞 시점 다리 들림은 작게 보인다. 필요하면 그림 담당이 다듬기.
- 탄 사람 `mount`·`dismount`는 옆모습만(앞·뒤 시점이면 옆으로 대신).
- 한양 노량진 나루처럼 큰길이 배로 이어지는 곳은 그래프가 끊긴다 — 나루 어귀에서 내려 배(boat_ride)를 타고 건너편 나루 어귀에서 다시 탄다(노정 끝 → 한양 도성은 말 → 배 → 말).
- 권역 안 역마의 '가 본 곳'은 거점 구역에 들어가야 적힌다(말로 지나쳐도 구역 안을 지나면 적힘). 예전 저장은 지나온 노정 양 끝만 안다.
- 사건 자리 하차는 사건 데이터 조건을 그대로 믿는다 — 조건이 늘 참인 조사 대상(`when` 없음·"true")은 하차 대상에서 뺐다(마을 안 일상 조사물 때문에 말이 서지 않게).
- 여행 기록책 3쪽(여행 방법)에는 아직 말 타기 줄을 넣지 않았다(이야기 담당 파일).
