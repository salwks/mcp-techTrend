# stations 보고 — 역참·마방(驛 馬房), 역마 이동(warp) (2026-10-05)

사용자 요청: "역참은 진짜 역참처럼 — 마구간에 말들이 건초를 먹고 있어서 들어가면 '아, 마방이구나' 해야 한다. 지도에도 보이고, 지도에서 고르면 다음 고을 역참·마방으로 가서 거기서 길을 떠난다."

## 1. 실행
```bash
python3 tools/region/make_stations.py          # 역 자리 → region_data/stations.json + 공간마다 placement_stations.json (약 5초, --check 는 쓰지 않고 보기)
python3 tools/region/make_travel_gates.py      # 역 거점·도착 자리·말 타는 곳을 travel/<공간>.json 에 (stations.json 을 읽음)
# 그림(한 번): python3 tools/web_export_server.py 8770 → http://localhost:8770/__tools/stable_bake.html (헤드리스 Brave --dump-dom, 약 1분)
tools/run_story_tests.sh station ride:namwon
godot --path seolhwa_godot res://scenes/region.tscn -- --region=JL_NAMWON_UNBONG --warp=-3009.7,196.9   # 남원 역참 마당
```
다시 만드는 순서: make_routes.py·배치 생성기 → make_stations.py → make_travel_gates.py. 배치 생성기(hubs·north·namwon·east·make_routes)는 쓰기 직전에 `tools/placement/station_reserve.py`로 마방 자리(터 +2m, 문 앞 +1m)의 물체를 뺀다 — 다시 돌려도 마방이 남는다(마방은 생성기가 안 건드리는 placement_stations.json).

## 2. 키트 — `kit/station/mabang.gd`(마방 터 27×21m) + `kit/station/hitch.gd`(길가 문 앞 9×2.6m)
- 마방: 앞이 트인 긴 마구간(칸 2.6m × 5칸, 대표 도시 6칸 — 처마를 높이(벽 2.9m)·짧게(0.55m) 내밀어 고정 카메라(38°)에서 칸 안 말이 보이게), 낮은 칸막이 널, 칸 앞 통나무 구유 + 건초, 깔짚, 그늘진 뒷벽; 울타리 친 말 놀이터(돌 물구유, 드나드는 틈); 짚가리 둘·건초 시렁; 마부 방(작은 채); 안장 걸이(언치·안장), 물동이, 작두.
- 문 앞: 말 매는 가로대 + 들통, 현판 기둥(글씨는 Label3D — 南原驛·靑坡驛…), 역 깃발(노란 바탕 붉은 테, 驛 글씨 — 제주는 馬).
- 지역 차림(`STYLES`): honam·yeongnam(초가, 대표 도시 기와; 영남 붉은 흙벽) · giho(초가/기와, 회벽) · gwanseo·haeseo(북서 이엉, 짙은 기와) · gwandong · **gwanbuk**(두꺼운 묵은 이엉, 칸마다 허리 높이 판벽(바람막이 반문), 굵은 3단 울타리, 높은 굴뚝) · **tamna**(현무암 벽·돌담 울타리, 새끼 그물 지붕, 조랑말).
- 삼각형: 마방 약 6~7천(먹선 포함), 문 앞 약 600. 마방은 occluder 끔(터가 한 키트라 마당에 서면 전체가 비쳐 보였음).

## 3. 움직이는 것 — `scripts/region/station_life.gd`(horse_ride가 만들고 매 프레임 부름)
플레이어가 150m 안에 오면 만들고 200m 밖이면 지운다(역 하나에 그림 9~11장).
- 칸 말(한 칸은 비움 — 나간 역마): 구유에 머리를 박고 씹기(eat) 65% / 서서 꼬리 휘두르고 귀 까딱·한 발 옮김(idle), 3~10초마다 바뀜. 카메라 쪽을 봐서 앞모습.
- 마당 말 둘(조랑말 셋): 풀 뜯기(graze) → 마당 안 다른 자리로 천천히 걷기(0.9m/s, 옆모습) → 서기/풀 뜯기.
- 기다리는 말: 안장 얹은 탈 말(ride_horse)이 가로대에 매여 있음(옆모습).
- 마부(mabu): 일 고리 — 기다리는 말 머리 앞에서 솔질 → 짚가리에서 건초를 안아(3D 짚단) 구유 앞에 붓기(그 칸 말이 먹기 시작) → 마당에서 쉬기. 마방 안 ↔ 문 앞은 마방 문(터 가장자리)과 마당 가운데를 거쳐 걷는다.
- **역에서 말 타기**: 문 앞 25m 안에서 안내가 "E   역마를 낸다 — ○○ 쪽으로 (약 N분)". E → 마부가 가로대의 말을 끌고 플레이어 곁으로(거리 ÷ 1.5m/s, 1.6~5초, 마부는 말 머리 곁 카메라 쪽에서 같이 걸음) → 오르기 → 마부는 일로 돌아감. 가로대 말은 플레이어가 40m 넘게 멀어지면 다시 매여 있다.
- 그림(`tools/export_stable_frames.js` → `data/frames_stable.json`, 그림 9장): stable_bay·chestnut(흰 이마줄)·grey(점박이)·pony(제주 과하마 0.82배, 짧고 굵은 다리, 덥수룩한 갈기) — side idle 4·eat 4·graze 4·walk 6, front idle 3·eat 4, back idle 3·eat 3(앞·뒤 walk는 옆으로 대신). 1m당 90px(탈 말 100보다 조금 낮게 — 말이 여러 마리라 페이지를 아낌). 마부: 웹 굽기 엔진(villager_m 차림 바꿈: 무명 저고리·조끼·머리띠·행전) idle·walk 앞옆뒤 + brush·feed(옆). 그림이 없으면 탈 말·주변 말·마을 사람으로 대신.
- 칸 말은 실루엣(가려진 인물 푸른 표시)을 끈다 — 구유 뒤 다리가 푸르게 비치던 것.

## 4. 자리 — `region_data/stations.json`(31곳)
| 종류 | 역 |
|---|---|
| 대표 도시(성문 밖 큰길) | 남원 역참(동문 밖 통영별로) · 청파역(숭례문 밖 용산 길) · 경주 역참 · 강릉 역참 · 황주 역참 · 대동역(평양) · 함흥 역참 · 제주목 마방(조랑말) |
| 위성 | 인월역(있던 역 거점 inwol_yeok 그대로) · 구산역(gusan_yeok 그대로) · 송당 목마장(조랑말) |
| 노정 | 오수역 · 전주 역참(삼례역 현판) · 안보역(새재 북쪽 들머리) · 상주 역참(낙양역 현판) · 원주 역참 · 횡계역 · 철령 아래 역참 · 영흥 역참 · 고원 역참 · 청교역(개성) |
| 노정 끝 길목(권역 쪽, 1.5km 안에 다른 역 없을 때) | 한양 길목(남원 북쪽 삼남대로·강릉·함흥·황주), 경주·함흥 길목(한양), 평양·장산곶 바닷가 띠 길목(황주), 황주·함흥 길목(평양) — 10곳 |

- 함흥→북청 노정의 **함관령 옛 역참**(이야기의 버려진 역)은 건드리지 않았다 — 그 노정에는 마방을 두지 않는다(`NO_STATION_SPACES`).
- 자리 고르기: 기준점(향할 고을 쪽 성문·쉼터·노정 끝) 둘레 큰길 점마다 마방을 길 양옆에 놓아 보고 — 터 안에 배치 물체(키트 크기는 `*_bounds.json` 캐시)·다른 길·물·성곽·도시 구역이 없고, 높이차 4.5m 안, 정면이 남쪽(±30°, 카메라 쪽), **말 길 덩이**(도시 안 점은 말이 못 들어감)가 향할 고을과 이어진 곳. 한양 노정 끝 다섯은 자리가 없어(빽빽) 두지 않았다.
- 필드: `id, name, sign, space, space_kind, kind, style, hub, pony, pos, ry, yard(도착·말 타는 자리, 길 중심 3m), road, hitch, wait, node, reuse_node, discover_key("travel_nodes/<공간>/<노드>"), lonlat, footprint, radius, note`.
- travel/<공간>.json: 역 거점(kind STATION 또는 있던 역 거점에 `station` 표)·`arrive`=yard·어귀=문 앞 길 점. **권역에서 말 타는 곳은 역 문 앞·노정 끝(포털)·배 나루 양 끝뿐** — 성문 앞·마을 어귀·길가 주막·큰길 갈림은 뺐다(엔진은 방금 내린 자리 40m·넘어온 포털 곁 60m를 더함). 노정은 그대로 큰길 어디서나 탄다(노정 자체가 말 길).

## 5. 역마 이동 API — `scripts/region/stations.gd`(travel.gd가 넘겨줌)
```gdscript
Travel.stations() -> Array         # stations.json 항목 + discovered(=known) + ok/why(지금 자리에서 갈 수 있나)
Travel.station_known(id) -> bool
Travel.station_state(id) -> {ok, why}   # why: "아직 가 보지 않은 역이다" / "처음 가는 길은 걸어서(말 타고) 가 봐야 한다" / "이미 이 역에 있다"
Travel.warp_to_station(id) -> {ok, why} # 역마 창을 그 역을 고른 채 열어 바로 감: 길 그리기 2.8초 + 시각 흐름 → 암전 → 마방 문 앞(기다리는 말 곁)
```
- 가 봄: 역 구역(터 둘레 24m) +10m 또는 문 앞 30m에 들면 progress.json `travel_nodes[공간][노드]`(기존 역마 거점과 같은 저장).
- 처음 가는 길 규칙은 역마 창 그대로(`FastTravel.reachable_from` — 공간 그래프에서 지나는 노정이 모두 지나옴이어야 함, 제주는 남해 뱃길을 한 번 건너야).
- 다른 공간 역: 역마 창 → `Stations.set_arrival` (Engine 메타) → 장면을 다시 연 뒤 horse_ride.setup이 마방 문 앞에 세우고 "역마 — ○○에 닿았다. 마부가 말을 매어 두었다".
- H(역마 창): 역 거점에 驛 표시. 역 문 앞에서 열면 제목 "역마 — 역에서 역으로", 역이 먼저.
- 지도(region_map — 다른 에이전트가 고치는 중, 이 작업에서 안 고침): 지도 에이전트(a28ec1a721627779e)에 위 형식과 API를 보냈다. 지도의 `_station_go`가 이미 `Travel.warp_to_station`을 찾아 부르고, `_st_api`로 `Travel.stations()`·`station_known`을 쓴다.

## 6. 시험 — `scripts/region/station_test.gd`, `tools/run_story_tests.sh`
| 시험 | 확인 | 결과 |
|---|---|---|
| station:namwon | 남원 역참·인월역 들러 가 봄(칸 말 5·4, 먹는 말, 마당 말 2, 기다리는 말, 마부) → `Travel.stations()` → `warp_to_station("namwon")`(인월→남원, 시각 8.0→11.5시, 문 앞 0.1m, 기다리는 말 4.9m) → 제주 역 가 봄으로 적어도 막힘 → E: 마부가 말을 끌고 14.9m 걸음(3.3초) → 운봉 읍치 어귀(4.4km)에서 내림(어귀 0m) | PASS |
| station:to-cheongpa | 남원에서 청파역(한양)으로 역마(약 43시간 길) → 새 장면 청파역 문 앞 0.0m, 마방 말, 다시 탈 수 있음 | PASS |
| ride:namwon-unbong | 출발을 남원 성문 앞 → **남원 역참**으로(성문 앞은 이제 말 타는 곳이 아님) | PASS — 4404m 411초(달리기 957초) |
| 전체 `tools/run_story_tests.sh`(42개) | 모두 PASS(jeju:A는 아래) | PASS |

**fps**(M1, 2048×1536 창, 맑음 10시, 마방 마당에서 0.8m/s로 15초): 남원 역참 평균 **145.0fps**(최악 7.6ms), 청파역 **144.9fps** — 80 넘음.

그림(게임 카메라, `shots/stations/` — git 밖): `namwon_a.png`(기와 마구간, 칸마다 구유에 머리 박은 말, 오른쪽 마당 말), `namwon_b.png`(문 앞: 마부가 안장 말 솔질, 南原驛 현판, 역 깃발), `cheongpa_a/b.png`(한양 청파역), `jeju_a/b.png`(제주목 마방 — 새끼 그물 지붕·조랑말, 비), `hamheung_a/b.png`(관북: 칸 판벽·굵은 울타리), `kit_honam.png`·`kit_giho.png`(키트 위에서).

**jeju:A**: 처음 전체 실행에서 한 번 실패했다("남해 뱃길 — 이제 지나온 길"). 저장 담당 에이전트의 전체 시험과 같은 때 돌아서, 두 실행기가 같은 user://st_jeju_A.json을 쓰며 장면을 다시 열 때 서로의 저장을 읽은 탓이었다. 혼자 다시 돌리면 jeju:A·station 2개 모두 PASS, 저장 담당 쪽 전체 실행도 42/42 PASS. 시험 묶음을 동시에 둘 돌릴 때는 저장 파일 이름이 겹친다는 점에 주의.

## 7. 남은 것·가설
- 칸 말은 앞모습(구유 쪽 = 카메라 쪽)이라 옆모습보다 덜 또렷하다. '마방'이라는 신호는 칸 말 줄 + 마당의 옆모습 말 + 문 앞 안장 말·마부·현판이 같이 준다. 칸 안 말은 처마 그늘과 화면 위쪽 틸트시프트 흐림 때문에 조금 흐리게 보인다.
- 마부의 길은 직선 + 마방 문·마당 가운데 두 점 — 울타리·짚가리를 스칠 때가 있다(그림이라 충돌 없음).
- 경주·대동·함흥 역은 도시 안을 말이 못 지나가므로(그래프에서 도시 점 막힘) 그 역에서 탈 수 있는 곳은 그쪽 노정 끝·몇 고을뿐이다(성 반대편 고을은 걸어서 성을 지나 거기 역·나루에서 탄다).
- 현판 한자는 실제 역명이거나(오수역 獒樹驛·청파역 靑坡驛·대동역 大同驛·인월역 引月驛·구산역 丘山驛·횡계역 橫溪驛·청교역 靑郊驛·안보역 安保驛·삼례역 參禮驛·낙양역 洛陽驛) 고을 이름 + 驛(가설). 고증은 참고용.
- 공용 파일 `travel.gd`·`fast_travel.gd`를 통째로 커밋했다(다른 에이전트의 `Progress.checkpoint`·`ui_fonts.gd` 포함). 그 의존 파일도 이제 커밋되어(2e5812f 등) HEAD에서 열린다.
- `data/frames_stable*.png`는 git 밖 — 다른 맥에서는 굽기를 한 번 돌린다.

## 8. 칸 말 다듬기 (2026-10-05, 검토 뒤)
- **반투명처럼 보이던 까닭**: 가림 점무늬가 아니었다(`--nodither`로 찍어도 같음). 칸 말이 화면 위쪽 틸트시프트 흐림 띠에 걸려 뒷벽 이엉·볕 줄과 섞여 비쳐 보였다(`--notilt`면 또렷). 처마 그늘은 문제 아님(먹선·담채는 그대로 읽힘).
  → `station_life.stable_view(pos)`: 칸 말 22m 안이면 region_main이 위쪽 흐림을 줄인다(top_bias 1.0 → 0.25, 선명 띠 0.07 → 0.16, 배·말 위 낮은 시점과 같은 식으로 천천히).
- **그림 — 꼭두각시를 걷어내고 말을 '그린다'** (`tools/horse_art.js`, 탈 말·마방 말·주변 말이 같이 씀): 예전 말은 몸통 타원 + 막대 다리 + 머리 조각을 돌리는 꼭두각시였다. 이제는 장마다 말 한 마리를 한 윤곽으로 그린다.
  - 옆: 등선(기갑 → 등 → 허리 → 엉덩이 → 꼬리뿌리 → 궁둥이 → 넓적다리 뒤)·배선(사타구니 → 배 → 앞가슴 → 어깨끝)·목(갈기 선 + 목 밑선)을 한 붓으로 잇는다. 머리는 머리뼈 꼴(이마·콧등·둥근 주둥이·큰 볼·턱 밑) 한 덩이에 귀·눈·콧구멍·입술·굴레를 얹는다. 갈기는 아래 가장자리가 들쭉날쭉한 숱이고, 근육 결(어깨·넓적다리·엉덩이뼈·팔꿈치)을 붓으로 넣는다. 다리는 관절 사슬(앞: 팔꿈치·앞팔·무릎·정강이·구절·발목·굽 / 뒤: 넓적다리·뒤로 뾰족한 비절·정강이·구절·발목·굽)에 굵기 윤곽을 입힌다. 디딘 굽이 땅에 닿도록 몸 높이를 맞추고, 든 다리는 무릎·비절이 꺾여 굽이 뒤집힌다.
  - 앞·뒤: 정면 꼴로 따로 그린다(가슴·어깨·앞팔·긴 얼굴·앞머리 털 / 두 볼기·꼬리·비절). `turn`으로 몸이 조금 돌아 한쪽 옆구리와 먼 뒷다리가 보인다. 칸 말은 `front|eat·idle`(turn −0.45)과 `eatR·idleR`(+0.45)를 칸마다 번갈아 쓴다. 칸 말 idle은 고개를 처마 아래로 낮춘다(`stall`).
  - 걸음새(실제 걸음): walk 8장 = 네 박(왼뒤 → 왼앞 → 오른뒤 → 오른앞, 디딤 62%, 앞발 디딜 때마다 머리 끄덕임). 탈 말 run 6장 = 속보(대각 두 박, 디딤 46%, 뜸·위아래 출렁). eat(구유)·graze(땅 풀) 4장은 씹을 때 눈을 감았다 뜨고, 귀를 돌리고, 꼬리를 휘두른다. 마지막 장에서 앞발을 옮긴다. idle 4장은 꼬리 휘두름 → 귀 돌림 → 머리 들어 둘러봄 → 뒷발 쉬기(굽 끝만 땅에) 차례다.
  - 굽는 곳: `export_stable_frames.js`(마방 말 넷 — side idle·eat·graze·walk, front 넷, back 둘), `export_ride_frames.js`(탈 말 side·front·back × idle·walk·run, 안장·언치·등자·뱃대끈·고삐는 덧그림), `export_npc_frames.js`(주변 말 side idle·walk 8·eat=graze). 옛 그림 코드(leg/legV/drawSide/drawFront/drawBack/drawQ3)는 지웠다. 미리 보기는 `tools/horse_preview.html?v=side|front|back[&pony&turn=0.45]`(data/preview/에도 저장)로 한다.
- 굽기: `python3 tools/web_export_server.py 8771` → 앱 브라우저 창(또는 일반 브라우저)으로 `http://localhost:8771/__tools/stable_bake.html` — 헤드리스 Brave `--dump-dom`은 이번에 모듈이 끝나기 전에 나와서 굽기가 안 됐다(PUT 0). `data/frames_stable*`는 git 밖이라 다른 맥에서는 다시 굽는다.
- 화면(게임 카메라, 1280×720 창 → 2560×1440, 맑음): 마방 전 `shots/horses/before_stable_{namwon,jeju}.png` · 후 `shots/horses/after_stable_{namwon,jeju}.png`. 말 타기 전 `shots/horses/before_ride/` · 후 `shots/horses/after_ride/`(남원 역참 → 운봉 자동 기승 20·50·80%와 내리기).
