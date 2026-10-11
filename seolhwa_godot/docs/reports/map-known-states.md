# 지도 세 단계 — UNKNOWN · KNOWN · VISITED (C65)

2026-10-11 · 사용자 결정 · 여덟 권역 공통(남원도 예외 없음) · 규칙 원문: `seolhwa/docs/production/CITY_ROUTE_PRODUCTION_RULES_v1.0.md` C65

## 규칙(네 줄)

- 지도는 '위치를 아는가'와 '직접 가 보았는가'를 구분한다.
- 권역 진입 시 대표 명소·공공시설은 KNOWN이 된다.
- 개별 생활시설·사적 공간·사건 장소·단서 위치는 자동 공개하지 않는다.
- NPC에게 정확한 위치를 들으면 UNKNOWN→KNOWN, 직접 방문하면 →VISITED.

## 세 단계와 저장 값

| 단계 | 저장(`progress.json` known.<공간>.<키>) | 지도 |
|---|---|---|
| UNKNOWN | 키 없음 | 이름·기호 없음 |
| KNOWN | `"told"`(사람이 일러 줌 — 사건 `known` 조건·`discover`·`Discovery.tell`) · `"known"`(권역 상식 · 사건 `start_known`) | 이름·자리 보임. 글은 옅은 먹(`_faint_col`, 한지 쪽으로 45%), 기호는 한지빛으로 바래고 점선 테(`_icon_faint`), 읍치 판은 점선 테. 사건 장소는 빈 동그라미(예전 '들음') |
| VISITED | `"visited"` | 보통 먹·보통 기호 |

- 코드: `scripts/region/discovery.gd` — `state()`(UNKNOWN 0 / KNOWN 1 / VISITED 2), `is_visited()`, `grant()`(상식 한꺼번에 — 이미 있는 키는 그대로). `is_known()`은 예전처럼 "이름을 쓸 만큼 아나"(KNOWN 또는 VISITED).
- 내려가는 일은 없다: `tell`은 키가 있으면 아무것도 안 하고, `grant`도 있는 키는 건너뛴다.
- 가 봄 셈(`region_map._update_discovery`)은 KNOWN이어도 적는다(예전 `is_known` 막음 → `is_visited`): 고을 구역 안 · 이름난 곳 45m · 고개 70m · 나루 40m(새로 — 나루 이름표 키 `town:<짧은 이름>`) · 건물 터 +14m · 사건 장소 radius.
- 같은 곳의 두 이름(이름난 곳 `lm:` · 건물 `bld:` — 경복궁·광한루): 한쪽을 가 보면 다른 쪽도 VISITED(`_twins`) — 지도에는 같은 이름이 하나만 남으므로 옅음/보통이 엇갈리지 않게.

## 권역 상식(region_known)

- 데이터: `region_data/region_known.json` — 권역마다 `towns`(고을 짧은 이름) · `landmarks`(region.json landmarks id) · `buildings`(배치 이름 — 그 이름의 건물 모두) · `passes`(id) · `ferries`(나루 이름). 코드에 박지 않는다.
- 풀이: `scripts/region/region_known.gd resolve()` → 지도 키. 지도에 없는 항목은 `missing`(시험이 실패로 본다).
- 적는 때: 지도(`region_map`)가 선 공간의 발견 셈마다 `grant_region_known()` — 그 권역에 서 있으면 곧(0.4초 안) 채운다. 키 수십 개 `has()`라 싸고, 새로 적은 것이 있을 때만 저장한다.
- 같은 우선순위 이름표끼리 솎을 때 상식 목록 차례가 앞선 것이 먼저(`rk` — 광한루가 오작교·광한루원보다). 그래서 목록 첫머리에 그 고을의 얼굴(광한루·동헌·용성관)을 둔다.
- 노정·뱃길: 뚜렷한 길목이 없어 비웠다(목록에 그 노정 id를 더하면 같은 규칙으로 돈다).

| 권역 | 키 수 | 고을 · 이름난 곳 · 건물 · 고개 · 나루 |
|---|---|---|
| 남원 JL_NAMWON_UNBONG | 27 | 4 · 12 · 9 · 1 · 1 |
| 한양 GG_HANYANG | 42 | 6 · 18 · 17 · 1 · 2(노량진·한강진 — 고을 키와 겹침) |
| 경주 GS_GYEONGJU | 36 | 2 · 13 · 14(오릉 5기 등 같은 이름 여럿) · 1 · 1 |
| 강릉 GW_GANGNEUNG | 16 | 3 · 6 · 6 · 1 · 0 |
| 황주 HH_HWANGJU | 13 | 2 · 3 · 8 · 0 · 0 |
| 평양 PA_PYEONGYANG | 31 | 3 · 13 · 14 · 0 · 1 |
| 함흥 HG_HAMHEUNG | 20 | 3 · 7 · 10 · 0 · 0 |
| 제주 JJ_JEJU | 16 | 4 · 5 · 7 · 0 · 0 |
| 합 | 201 | |

일부러 뺀 것(UNKNOWN 그대로 — 들음·가 봄으로만): 월매 집 · 주막 · 물레방앗간 · 외딴집 · 옥 자리 · 사람 집 · 모든 사건 장소(`place:`) · 범 흔적 · 숨은 굴(기린굴·김녕사굴) · 사건 거점이 된 곳(부벽루 · 대관령 국사성황사 · 반정 주막 · 치술령 · 처용·연오랑 바위 · 도화동 우물 · 책쾌의 책방 · 창고들). 사건이 쓰는 **공공 건물**(광한루·광통교·대동강 나루)은 건물 이름만 상식이고 `place:` 키는 사건이 정한다. 목록 전체는 C65 표.

## 옛 저장

- 고른 방법: **다음 진입 때 채움**(불러오기 때 따로 고치지 않는다). 옛 저장을 불러와 그 권역에 서면 지도의 첫 발견 셈(0.4초 안)에 상식이 채워진다. 불러오기는 장면을 다시 열므로 칸 불러오기도 같다. 아직 가지 않은 권역은 처음 들어설 때 채워진다.
- 옛 값(`visited`·`told`)은 바꾸지 않는다. `told`는 그대로 KNOWN.
- 지금 시험 저장(복사본 `user://st_known_usercopy.json` — 원본은 읽기만)으로 남원을 열어 확인: visited 30개 그대로 + known 14개 더해짐, 광한루(`bld:광한루@-3271,450`·`lm:gwanghallu`)는 이미 VISITED라 보통 먹으로 보인다.

## 역참·역마 조건(KNOWN이 가 봄을 대신하지 않는가)

- 역참 목록·역마(`Stations.known/state`) · 길목 깃발(`Waymarks.known` → `horse_ride.is_discovered`) · 역마 창은 모두 `progress.json travel_nodes`만 센다. `Discovery`(known 사전)를 읽는 곳은 지도 이름표와 전국 지도 권역(`region_known(id)` — `_nation` 키·기록 토큰)뿐이고, 상식은 `_nation`도 travel_nodes도 건드리지 않는다.
- 시험이 직접 본다: 상식 적기 전후 travel_nodes·`_nation` JSON이 같음 · 그 공간 역참마다 `Stations.known == horse_ride.is_discovered`, 안 가 본 역은 `Stations.state().ok == false`.

## 지도 그림

- 확대 단계·글 크기(C64 — 고을 이름 26·24 그대로, 그 밖 ≥26)·솎기 그대로. KNOWN·VISITED는 색만 다르고 크기·글꼴은 같다(시험이 잰다).
- 범례에 '가 본 곳'(보통 마름모) · '아는 곳'(바랜 마름모 + 점선 테, 옅은 글), 범례 아래 줄 "아는 곳만 이름이 적힌다 · 옅은 먹은 알지만 아직 안 가 본 곳".
- 사건 표지(map_leads, 붉은 인)는 바꾸지 않았다.

## 시험

- `tools/region/region_known_test.gd`(헤드리스 `-s`): 여덟 권역 목록이 모두 지도 키로 풀리는가 · 금지어(주막·방앗간·외딴집·월매·옥·집) · 사건 장소 이름(공공 건물·start_known 제외) → `REGIONKNOWN PASS regions=8 keys=201`. `-- dump`면 권역마다 고을·건물 이름을 찍는다(목록 짤 때).
- `scripts/region/map_known_test.gd`(`--knowntest`, 묶음 `map:known-namwon`·`map:known-hanyang`): 진입 → 상식 모두 KNOWN(VISITED 아님) · 남원 광한루·동헌 KNOWN · 월매 집·외딴집·고갯길·주막·방앗간·사건 장소 UNKNOWN · told → KNOWN · 다가감 → VISITED · 역참·역마·깃발·전국 키 불변 · 그림 KNOWN 옅음 → VISITED 보통(글 크기 같음) · 범례 · 옛 저장(visited/told만)에 상식 채움·옛 값 그대로 · 저장 왕복.
- `--knownshots=<폴더>`(창 모드, `--knownvisit`면 광한루에 가 본 뒤도): `shots/map_known_states/`
  - `namwon_first_entry_city.png` · `namwon_first_entry_close.png` · `namwon_first_entry_region.png` — 첫 진입(광한루·오작교·용성관·향교·동문·운봉 옅게)
  - `namwon_after_visit_city.png` · `namwon_after_visit_close.png` — 광한루에 가 본 뒤(광한루·오작교 보통 먹)
  - `hanyang_first_entry_city.png` · `hanyang_first_entry_close.png` · `hanyang_first_entry_region.png` — 한양 첫 진입(경복궁·창덕궁·종묘·육조거리 … 옅게)
  - `namwon_legend.png` · `hanyang_legend.png` — 범례
