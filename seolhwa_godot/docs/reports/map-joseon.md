# 지도 — 조선 고지도풍(대동여지도·동여도 / 군현지도·도성도)

사용자 의견 세 가지("측량도 같고 대충 칠했다", "지명 글자 크기가 들쭉날쭉", "사건 자리를 지도에서 보고 싶다")에 맞춰
지도 세 단계(L3 도시 · L2 권역 · L0 전국)를 다시 만들었다. 조작(M 도시, Tab 도시→권역→전국, 휠·+/-, 드래그·방향키, H)과
발견 규칙(모르는 이름은 안 씀)은 그대로다.

## 1. 바탕 그림(오프라인) — `tools/region/render_joseon_map.py`

```
python3 tools/region/render_joseon_map.py JL_NAMWON_UNBONG   # 권역 하나(L2 + 고을 L3)
python3 tools/region/render_joseon_map.py all                # 여덟 권역 + 전국
python3 tools/region/render_joseon_map.py nation             # 전국(terrarium z7 DEM 캐시: tools/region/cache/terrarium_z7)
```

| 산출 | 내용 |
|---|---|
| `region_data/<id>/map/l2.webp` | 권역(L2). 한지(얼룩·섬유·가장자리 바램), 산줄기, 물길, 바다, 붉은 길·10리 눈금 |
| `region_data/<id>/map/city_NN.webp` | 고을(L3). 고을(settlement bbox, 겹치면 합침) + 150m 둘레, 0.5m/px 안팎, 가장자리 투명 |
| `region_data/<id>/map.json` | `{file, x0, z0, scale, w, h, li_m, cities:[{file,x0,z0,scale,w,h,ids,core}]}` |
| `region_data/nation_map.webp/.json` | 전국(L0) `{file, lon0, lat0, lon1, lat1, w, h}` (경위도 등간격, 경도는 cos38°) |

- 산(음영 없음): DEM을 뒤집어 흐름 누적 → 등성이가 '물길'로 모인 선(가지 친 산줄기) + 유역 경계(산자분수령: 큰 유역 사이 경계 칸)를
  더해 끊긴 줄기를 잇는다. 그 선을 따라 봉우리(석산 뾰족·토산 둥긂, 청록 바림 + 위쪽 짙은 번짐 + 준법 먹선 + 붓 윤곽)를 남쪽이 북쪽을
  덮게 겹쳐 세우고, 아래에 옅은 풀빛 바림 띠와 큰 줄기 먹 등줄기. 제주는 오름마다 둥근 봉우리.
- 물: S·A·B급(또는 너비 12m↑)은 겹줄(먹빛 물가 + 옅은 물빛), 내는 외줄. 바다는 옅은 물빛에 비늘 물결, 물가 먹선.
  한양·평양처럼 '바다'가 큰 강인 곳은 흐르는 물결.
- 길: 대로·지선 붉은 선, 10리(실거리 4.2km × 권역 압축 K, 남원 1,260m)마다 눈금. 나룻길은 점선.
- 고을(L3, 군현지도·도성도 방식): 성벽(회색 석축 띠 + 바깥 여장), 성문(홍예 + 문루 지붕), 집은 서 있는 그림 —
  기와(회청 기와골·용마루·처마 곡선, 관아·이름난 건물은 크게·단청 띠)와 초가(둥근 볏짚), 둘레 높은 땅에 청록 산,
  내는 파랗게, 대로 붉게·길 황토, 논(줄무늬)·밭(점무늬), 큰 나무. 배치(placement_*.json)·카탈로그 footprint에서 읽는다.
- 전국: 해안·섬은 DEM, 북위 39.6° 북쪽은 travel.gd 윤곽 안만 조선(밖은 옅은 이웃 땅), 큰 강은 흐름 누적(우선순위 범람),
  산줄기는 같은 방법 + 백두대간 등뼈(백두산→철령→금강→설악→오대→태백→소백→속리→덕유→지리, 대략).
- 크기: 여덟 권역 그림 합계 약 7MB(webp), 옛 map.png 11MB는 지웠다(render_map.py도 지움 — 부르는 곳 없음).
- 배치가 바뀌면 고을 그림이 낡는다 → 이 도구를 다시 돌린다(권역 하나 30초 안팎, 전국 25초).

## 2. 런타임 — `scripts/region/region_map.gd`

- 바탕 위에 그리는 것: 이름·기호, 사건 표지, 할 말 있는 사람, 역참, 플레이어, 테두리(겹선)·방위(북 붉게)·10리 자, 오른쪽 판.
- **글자·기호 크기 고정**: 모든 이름표와 기호는 화면 px로 그린다(확대와 무관). 매 그림마다 우선순위대로 자리를 잡고
  겹치면 이름을(그다음 기호를) 솎는다 — 지금 고을·권역 > 사건 > 거점(읍치) > 고을(장터·역·원·절) > 역참 > 마을 > 이름난 곳 > 고개·물·오름.
  이름은 기호의 오른쪽·위·아래·왼쪽 중 빈 자리. 글꼴은 덕온공주체(scripts/ui_fonts.gd, 제목·고을은 Classic), 먹 글씨 + 한지빛 테두리,
  읍치는 한지 판에 먹 테(place_title과 같은 '먹·한지' 결).
- 기호: 읍치(여장 두른 네모 성 + 붉은 점), 장터, 마을, 역참·마방(붉은 테 '역'), 원·주막(초가), 나루(배), 고개(꺾쇠), 절(기와),
  성황당(신목), 봉수, 거점 88곳(작은 네모), 권역 거점(겹 둥근 성).
- L2→L3: 권역 그림이 제 해상도를 넘길 만큼 확대하면(k > 1.15/scale) 고을 그림으로. 고을 밖 확대된 권역 그림은 한지빛으로 덮어 흐림을 감춘다.
- 오른쪽 판: 제목 곽(권역/고을/조선 팔도), 범례, **현재 사건**(사건별 표지 목록 — 누르면 그 자리로, 다른 공간이면 전국 지도의 그 권역으로),
  **역참** 목록.
- 발견: 이름난 곳(`lm:<id>`, 45m 안)·고개(`pass:<id>`, 70m 안)를 새로 적는다. 나머지 키는 그대로.
- 여는 시간: 6~8ms(사건 데이터는 지도를 만들 때 미리 읽음, 처음 고을 그림 읽기 포함). 전국 첫 열기 20~24ms. 목표 150ms 안.

## 3. 사건 표지 — `map_leads` (보강서 §20)

- 사건 데이터 `story/<사건>/<사건>_data.gd`에 `"map_leads"`(여덟 사건 모두, 45개):
  `{ id, name, at(앵커·[x,z]), when, until, space(기본 case.region), region(다른 권역을 가리킴), hub, note(근거) }`.
  들은 행선지만 — 주모의 "고개 너머", 이겸의 쪽지(종루 뒤 피맛골·책쾌의 책방), 어부 말 뒤 장산곶·바위섬 갯구멍, S7002 김녕 굴,
  사건 끝에 일러 주는 다음 권역(한양·강릉·경주·황주·평양·함흥·제주) 등. 단서·범인·숨은 괴이·해결 자리는 넣지 않았다
  (남원 빈터, 경주 세 불빛·가마·바위틈 등 제외).
- 셈: `scripts/region/map_leads.gd` — 지금 공간의 사건은 story_director의 runner.cond·anchor, 다른 사건은 progress.json 사건 상태
  (f c k ph v seen talked w out has n; fn 금지). case.requires가 안 맞으면 없다.
- 표시: 붉은 인(조금 기운 네모·흰 테·'사'). 마우스를 올리거나 누르면 「사건 이름」 행선지. 권역 지도·고을 지도는 그 자리, 전국 지도는 권역 자리에
  사건 이름과 함께.
- 할 말 있는 이야기 인물: NPC 대화 담당의 `story_director.talk_pending(id)`가 참인 인물을 작은 붉은 「…」로(그 파일은 읽기만).
- 시험: `godot --headless --path . -s res://tools/story/map_leads_test.gd` — `tools/story/map_leads_fixtures.json` 45개 상태에서
  보여야 할/숨어야 할 표지를 센다 → **MAPLEADS PASS 45/45**.

## 4. 역참(역참 담당 API에 맞춤)

- `Travel.stations()`·`station_known(id)`·`warp_to_station(id)`(scripts/region/stations.gd). API가 없으면 `region_data/stations.json` +
  progress.json `travel_nodes`로 '가 본 역'을 알고, 이동은 역마 창으로.
- 가 본 역만 권역·고을·전국 지도에 '역' 기호 + 이름, 오른쪽 판 목록(다른 공간이면 공간 이름, `ok=false`면 "아직 못 감").
- H: 가 본 역이 있으면 오른쪽 판 역참 고르기(없으면 예전 역마 창). 숫자 키 1~9: 역참 고르기(역참이 있으면 노정 건너뛰기 번호 대신).
  고른 역을 한 번 더 누르거나 Enter/Y → `warp_to_station`(지도 길·시간 흐름·암전·마방 마당 도착은 역참 담당). 실패하면 지도를 다시 열고 까닭을 적는다.
  전국 지도의 금빛 '지나온 노정 건너뛰기'는 마우스로 그대로.

## 5. 화면(창 1024×768, `--mapshots=res://shots/map/... --mapzooms`)

| | 전(음영 지도) | 후 |
|---|---|---|
| 남원 도시 | `shots/map/before/JL_NAMWON_UNBONG_city.png` | `shots/map/after/JL_NAMWON_UNBONG_city.png` |
| 남원 권역 | `shots/map/before/JL_NAMWON_UNBONG_all.png` | `shots/map/after/JL_NAMWON_UNBONG_all.png` |
| 남원 전국 | `shots/map/before/JL_NAMWON_UNBONG_nation.png` | `shots/map/after/JL_NAMWON_UNBONG_nation.png` |
| 한양 도시·권역·전국 | `shots/map/before/GG_HANYANG_{city,all,nation}.png` | `shots/map/after/GG_HANYANG_{city,all,nation}.png` |
| 제주 도시·권역·전국 | `shots/map/before/JJ_JEJU_{city,all,nation}.png` | `shots/map/after/JJ_JEJU_{city,all,nation}.png` |

- 확대 단계별 글자 크기: `shots/map/after/<권역>_city_{min,mid,max}.png`, `_nation_max.png` — 이름표 크기가 모두 같다(13~22px 고정).
- 사건 표지 전/후(시험 저장 = fixture 상태): `shots/map/leads/`
  - 남원 `nw0`(주모 말 전: 주막 거점만) → `nw1`(주모 말 뒤: 고개 너머·고개 너머 외딴집)
  - 한양 `hy0`(쪽지 뒤: 책쾌의 책방·종루 뒤 피맛골) → `hy1`(종루에 닿은 뒤: 종루 표지 사라짐)
  - 제주 `jj0`(곽 서방 들은 뒤) → `jj1`(S7002: 김녕 굴)
  - 역참: `JL_NAMWON_UNBONG_station_city.png`(남원 역참을 가 본 저장)
- 촬영은 `--savefile=user://map_run_*.json`로 — 실제 저장(progress.json)을 건드리지 않는다.

## 6. 시험

- `tools/run_story_tests.sh` 전체: 결과는 아래 '대본 시험'에.
- `tools/story/map_leads_test.gd`: PASS 45/45.

## 7. 남은 것·주의

- 창(倉, 곡물 창고)은 데이터에 자리가 없어 기호를 두지 않았다(범례에도 없음). 데이터가 생기면 `_icon`에 한 줄.
- 고을 그림은 굽는 때의 배치를 쓴다 — 새 건물(예: 역참 마방)은 다시 구워야 그림에 나온다(기호·이름은 런타임이라 바로 나옴).
- 전국 북쪽 경계는 travel.gd 윤곽선(직선 구간)이 그대로 보인다 — 압록·두만 물줄기로 바꾸려면 윤곽을 다듬어야 한다.
- 함흥 `hg_forest_light`(숲 위 불빛)는 플레이어가 본 불빛(S6004 단서 글)이라 넣었지만, 역참이 숨은 자리라 지나치다고 보면 빼면 된다.
