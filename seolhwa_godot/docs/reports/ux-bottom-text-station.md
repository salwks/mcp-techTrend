# UX 수정 — 아래쪽 글 크기 · 역참 마부 대화 · 길목 깃발 (2026-10-10)

사용자 보고 두 가지(아래 글이 작다 / 역참 근처에서 E를 누르면 말이 와서 끌고 간다)와 추가 요청(마을·노정·쉼터 깃발을 웨이포인트·역참 역할로)을 한 번에 고쳤다.

## 1. 아래쪽 글

1024×768 창에서 뷰포트가 1024×768(배율 _k = 1.0)로 잡힌다 — 레티나 ×2는 OS가 늘리는 것이라 글 픽셀 크기가 그대로 보이는 크기다.

| 글 | 전 | 후 | 배율 | 파일 |
|---|---|---|---|---|
| 조사·대화 안내 E (`story_ui.prompt`) | 22 (처음 27) · 키 칸 18/22 | **32 (처음 38)** · 키 칸 26/30 | 1.45× / 1.4× | scripts/story/story_ui.gd |
| 처음 한 번 안내 띠 (`d.ui.hint`) | 21, 여백 14 | **30**, 여백 18, 줄 간격 4 | 1.43× | 〃 |
| 자막·조작 유지 자막 (`d.ui.caption`) | 28, 흰 글 먹 테만 | **40**, 먹빛 반투명 띠(52%) 위, 줄 간격 5 | 1.43× | 〃 |
| 오른쪽 아래 키 안내 F | 19 · 키 칸 16 | **27** · 키 칸 22 | 1.42× | 〃 |
| 소지품 | 18 | **25** | 1.39× | 〃 |
| 말·배 안내 (region_main `_boat_text`) | 22, 글꼴 없음(기본), 600px 칸 | **32**, 덕온공주체, 키 칸 + 흰 글(조사 안내와 같은 꼴) | 1.45× | scripts/region/region_main.gd |
| 호신물 칸(왼쪽 아래) | 19 | **26** | 1.37× | scripts/story/spirits.gd |
| 전투: 상황 문구 / 화살·떡 / 키 안내 | 26 / 20 / 16 | **36 / 28 / 21** | 1.3~1.4× | story_ui.gd |
| 저장 도장 글 '기록을 남겼다' | 17 | **22** | 1.3× | 〃 |
| 왼쪽 위 HUD(`_show_hud`) | 22 | 28, 덕온공주체 | 1.27× | region_main.gd |

자리(아래에서 위로, `BOTTOM_*` 상수 × _k): 소지품 46 → 키 안내 F 94 → 조사·말·배 안내 줄 152(높이 52) → 안내 띠 아랫변 160 → 자막 띠 아랫변(안내 띠가 있으면 그 위). 저장 도장은 262로 올려 안내 줄·키 안내와 겹치지 않게 했다. 말 안내가 두 줄이면 `story_ui.set_bottom_extra()`로 안내 띠·자막이 그만큼 올라간다.

줄바꿈: Godot의 한국어 줄바꿈은 음절 사이에서도 끊어 "털|이"처럼 낱말이 갈렸다(전 화면 4_caption_long). `StoryUI.wrap_words()`가 띄어쓰기에서만 끊고 줄 길이를 고르게 맞춘다(자막·안내 띠·조사 안내·말 안내·전투 키 안내).

화면(시험 저장 `user://ui_bottom.json` + `story/hwangju/test_post_hanyang.json`, 실제 저장은 건드리지 않음):
- 전: `shots/ui_bottom_text/before/1~7*.png` · 후: `shots/ui_bottom_text/after/1~7*.png`
- 다시 찍기: `godot --path seolhwa_godot res://scenes/region.tscn --resolution 1024x768 -- --region=JL_NAMWON_UNBONG --notitle --savefile=user://ui_bottom.json --uifixture=res://story/hwangju/test_post_hanyang.json --bottomshots=shots/ui_bottom_text/after`

## 2. 역참 — 마부가 유일한 입구

원인: 역참 문 앞 25m(`life.near`)와 말 타는 곳 45m(`MOUNT_R`)가 '역마를 낸다/말에 오른다' 안내를 띄웠고, `ambient_talk.target()`은 말 안내가 있으면 고을 사람을 대상에서 뺐다 — 넓은 구역이 곁 사람 E를 가로챘다.

새 흐름(모든 역 31곳, region_data/stations.json):
1. 역 문 앞 45m(`STATION_QUIET`) 안에서는 큰길 말 타기 안내·E가 없다.
2. 마부(station_life의 마부) 곁 2.4m에서 "마부 · 말 걸기" → E → 마부가 일손을 멈추고(손질·여물 나르기 정지, 손님 쪽을 봄) "어디로 가시오?"
3. 목록: `역마 — ○○`(가 본 역) · `깃발 — ○○`(가 본 깃발) — 역마 창 목록(`fast_travel._gather`)을 그대로 써서 처음 가는 길·남원 첫 사건 막음이 같다. 못 가는 곳은 흐리게 까닭과 함께(둘까지). 그다음 `말을 빌린다 — 큰길 따라`(그 역 문 앞 길에서 탈 수 있을 때) · `가 본 다른 곳 — 역마 창`(나루·절·노정 끝 등이 있을 때) · `그만두겠소.`
4. 고른 뒤에야 말이 온다: 역마 → "말을 내 오리다." → 마부가 가로대의 말을 끌고 손님 곁으로(0.8~4초) → 역마 창(지도 위 길·시각 흐름 — 예전과 같은 연출) → 같은 공간이면 닫힐 때 말을 다시 매어 둔다. 말 빌리기 → 갈 곳 고르기 → (마방 안에서 말을 걸었으면 짧은 암전으로 문 앞 길로) → 마부가 말을 끌고 나와 태움(예전 `begin_ride`).
5. E 차례(story_director `_update_target`): 이야기 인물이 먼저, 그다음 고을 사람·마부·깃발 가운데 **가장 가까운 것**. 큰길 말 타기 안내는 이제 곁 사람 말 걸기를 막지 않는다(region_main은 대상이 있으면 말 E를 주지 않는다 — 원래 규칙).
6. 남원 v3.2 첫 방문 마부 안내(`namwon_case.station_intro`, station_wait 7m 자동)는 그대로 두고, 마지막 고르기 "그냥 가겠소." 대신 "어디로 갈 수 있소?"로 끝나 같은 마부 목록으로 이어진다(거기서 그만두겠소).

### H 키 — 결정
**아무 데서나 여는 H 역마 창을 없앴다.** 역마는 역참 마부·길목 깃발에게 E로, 또는 지도(M)의 역참 목록(지도 안 H — 그대로)에서 고른다. 밖에서 H를 누르면 "역마 — 역참 마부나 길목 깃발에게 E로 말을 건다 (지도 M에서도 역을 고른다)"가 뜬다. 남긴 H는 하나: 지나온 노정 포털 곁 16m에서 뜨는 "H: 역마 타고 ○○까지 (지나온 길 건너뛰기)"(그 자리에서만, 안내가 떠 있을 때만). 마부 곁에서만 H를 살리는 쪽은 E와 같은 일을 두 키로 하게 되어 버렸다. 안내 글(남원 `fast_hint`, 기록책 '여행 방법')도 고쳤다.

### 지도 역마(region_map)
- 권역 지도 역참 목록(`_station_go` → `Travel.warp_to_station`)과 전국 지도 노정 건너뛰기(`_fast_go`)는 그대로 둔다. 둘 다 지도를 열고 → 고르고 → Enter/Y로 한 번 더 확인해야 가므로 이번 같은 '구역 덫'이 아니다.

### 마부 일손 멈춤
`station_life.hold/unhold` — 싸다(마부 상태에 talk 깃 하나, 길을 잇거나 다음 일로). 했다.

## 3. 길목 깃발(웨이포인트 · 역마 타는 자리)

- 자리(새 좌표 없음): 역마 거점 데이터 `region_data/travel/<공간>.json` nodes 가운데 빠른 이동 거점(fast)이고 kind가 CITY·MARKET·VILLAGE·HUB·COAST·INN·PASS인 것(역 STATION·노정 끝·나루·배·절·굴 제외)의 도착 자리(arrive) → 가장 가까운 큰길 방향에 직각으로 4m 길가, 처음 세울 때 담·집 충돌을 비켜 빈 자리로. 깃대: `kit/station/waymark.gd`(돌 받침 두 단 + 4.2m 장대 + 가로대 쪽빛 깃발·붉은 테·꼬리 — 역참 깃발의 노랑과 색으로 가름). 모르는 깃발은 바랜 무명빛.
- 수(102): 남원 13 · 한양 12 · 경주 10 · 평양 8 · 강릉 7 · 제주 7 · 함흥 5 · 황주 5 / 노정: 한양–함흥 5 · 남원–한양 5 · 한양–황주 4 · 한양–경주 3 · 한양–강릉 3 · 평양–함흥 3 · 황주–장산곶 3 · 한강 뱃길 3 · 함흥–북청 2 · 대동강 2 · 황주–평양 1 · 남해–제주 1. (strongholds.json은 전국 지도 점이라 권역 안 좌표가 없어 쓰지 않았다.)
- 알기: 역마 거점과 같은 '가 봄'(progress.json travel_nodes — 거점 구역·도착 30m). 처음 알면 알림 띠 "깃발 — ○○. 역마 길목으로 적었다", 깃발이 쪽빛으로, 지도에 표지. 저장·저장 칸·이어 하기는 travel_nodes 그대로 실린다.
- E: 깃발 2.4m — 마부와 같은 '가장 가까운 대상' 규칙. 목록은 마부와 같다(말 빌리기 없음), 고르면 바로 역마 창.
- 지도: 권역 지도에 장대+쪽빛 깃발 기호(고을 기호 오른쪽 위에 늘 그림), 전국 지도에도(겹치면 솎음), 범례 "길목 깃발(역마)".

### 이동 규칙
- 따로 만든 이동 없음: `Stations.warp_node(공간, 거점)` = 역마 창을 그 거점으로 열어 자동 진행(역·깃발 같은 연출 — 지도 위 길, 시각 흐름, 도착 자리). `Stations.warp(id)`도 이것을 쓴다.
- 처음 가는 길: 지나는 노정이 모두 '지나옴'이어야(예전 규칙 그대로 — 제주 첫 뱃길 포함).
- 남원 첫 사건: `fast_travel.gate_why()` — 남원 권역에서 `CASE_NAMWON_COMPLETE`(또는 남원 사건 phase done) 전이면 다른 공간으로 가는 역마·깃발이 모두 막힌다("남원 일이 아직 끝나지 않았다 — 고을을 떠날 수 없다"). 남원 안의 가 본 곳끼리는 예전 H처럼 갈 수 있다.

## 4. 시험

- 새·고친 시험: `station:namwon`(scripts/region/station_test.gd) — 두 역 가 봄 → 지도 API 역마 → 제주 막힘 → **남원 첫 사건 막음** → **역 문 앞 넓은 E 없음** → **마부 곁 1.8m · 고을 사람 0.9m에서 E → 고을 사람과 말하고 말·역마 없음** → **마부 E → 목록(역·깃발·말 빌리기·그만) 동안 말·역마 창 없음·마부 멈춤 → 역 고르면 마부가 말을 끌고 와 역마 → 그 역 문 앞** → **깃발 가 봄·쪽빛·저장 파일 → 깃발 E로 역 → 역 마부 E로 깃발** → 마부 '말을 빌린다'로 운봉까지. `station:to-cheongpa` 도착 확인을 '문 앞 넓은 안내 없음 + 마부에게 말 빌리기 가능'으로. `save:slot-load` — 깃발 가 봄이 저장 칸에서 이어지는지. `namwon:onboard` — 마부 안내가 마부 목록으로 이어지고 그만두면 말이 오지 않는다.
- ride:* · fast:*는 API(mount_check·begin_ride·open_fast_travel)를 바로 써서 동작 그대로 — 고치지 않았다.
- 돌린 것(모두 종료 코드 0): validate_event_class(EVENTCLASS PASS 127) · case_registry(REGTEST PASS 47) · sound(SOUNDTEST PASS 38) · onboarding_rule(ONBOARDRULE PASS 64) · map_leads(MAPLEADS PASS 53) · tools/run_story_tests.sh 전체(결과는 아래).

전체 결과: `tools/run_story_tests.sh` 47개 **모두 PASS, 종료 코드 0** (station:namwon 130초, namwon:onboard 44초, ride·fast·talk·continue·save 모두 PASS, SCRIPT ERROR 0).

## 5. 화면
- 아래 글 전/후: `shots/ui_bottom_text/before/`, `shots/ui_bottom_text/after/`
- 깃발: `shots/ui_bottom_text/flags/flag_JL_NAMWON_UNBONG_namwon_eup.png`(읍성 성문 어귀) · `flag_JL_NAMWON_UNBONG_ibaek.png`(마을) · `flag_JL_NAMWON_UNBONG-GG_HANYANG_rt_jeonju.png`(노정 중간) · `map_region_JL_NAMWON_UNBONG.png` · `map_nation_*.png` · `map_town_*.png`
- 다시 찍기: `--stationtest=flagshots[:거점,거점] --shotdir=… --winshot`

## 6. 정할 것
- 남원 안 역마: 첫 사건 중에도 남원 안 가 본 곳끼리는 마부·깃발로 갈 수 있다(예전 H와 같음). 밤 장면 도중 막을지.
- 큰길 말 타기(주막·어귀 45m 안 E)는 그대로 넓은 구역이다 — 이제 곁 사람이 먼저지만, 이것도 '말 매어 둔 곳' 같은 대상으로 좁힐지.
- 배 안내(나루 E)는 아직 곁 사람 말 걸기를 비켜 가게 한다(ambient_talk: 배 안내가 있으면 고을 사람 대상 없음) — 같은 덫이 나루에 남아 있다. 같은 규칙으로 바꿀지.
- 깃발은 충돌체가 없다(지나갈 수 있음). 강·바닷길 노정의 마을(한강 3·대동강 2·남해 1)에도 깃발이 선다 — 뺄지.
- 1024×768에서 세 줄 안내 띠(말 타기 첫 안내)는 플레이어 발치를 조금 가린다.
