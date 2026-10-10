# 공통 승격 1차 — 대화 카메라 · 물 노정 깃발 · 사건 선언 고을 막음 · 사건 메타 검사 (2026-10-11)

근거: `seolhwa/docs/production/CITY_ROUTE_PRODUCTION_RULES_v1.0.md` 부록 결정 4·5·6, 백로그 F-1·F-6, C46.
하지 않은 것(뒤로): CITY_PROFILE, 권역 빛 tint, builder hook, 식생, 남원 region.json 형식 맞추기.

## 1. 공통 대화 카메라 (결정 4 · C27 · F-6)

| 무엇 | 어디 |
|---|---|
| 공통 값 `CameraRig.TALK` = pitch 38 · 거리 13.5 · fov 38 | `scripts/camera_rig.gd` |
| 값 고르기 `CameraRig.talk_spec(case_head, actor_spec)` — 공통 → `case.talk_camera` → `actor.talk_camera`(뒤가 앞을 덮음, 일부 키만 줘도 됨). `false` = 평소 카메라, `true` = 다시 켬. 반환 null이면 끔 | `scripts/camera_rig.gd` |
| 적용: 이야기 인물(사건 actor)에게 E로 말을 걸 때만(`story_director.interact`). 고을 사람(ambient_talk)·역참 마부·길목 깃발은 이 길을 지나지 않는다(따로 `station_keeper`·`ambient_talk`) | `scripts/story/story_director.gd` |
| 대화 중 명시적 `camera`/`cutscene`이 이긴다(예전과 같음). 대화가 끝나면 평소 시점·음악 1.0 | 〃 |
| 사건 연출이 대화 구도를 다시 쓸 때: `d.talk_camera_base()`(사건 단위 값, 꺼졌으면 {}) — 남원 마부 안내·아이들·포수·이웃 아낙·노인 다섯 곳이 `d.data.case.talk_camera`를 직접 읽던 것을 바꿈 | `story_director.gd`, `story/namwon/namwon_case.gd` |

남원은 사건 머리 `talk_camera` 38/13.5/38을 그대로 두었다(사건 연출값 — 규칙 G절). 값이 공통과 같아 화면이 같다.
다른 일곱 사건은 이제 이야기 인물과 말할 때 공통 TALK를 쓴다.

**덮어쓰기가 필요했던 사건: 없음.** 한양(포졸)·경주(마을 노인)·제주(해녀) 대화를 창 모드로 찍어 보았고, 두 사람이 모두 화면 가운데에 들어 구도가 깨지지 않았다(아래 5절).
경주 노인 곁 큰 나무는 예전에도 카메라 가까운 먹점 비움으로 반투명이었고, 가까워진 시점에서도 같다.

## 2. 강·바닷길 노정 깃발 없음 (결정 5·6 · C22)

- 규칙: 권역과 `ROUTE_PROFILE.kind == land` 노정만 길목 깃발. river·sea 노정은 깃대도 깃발 E도 없다.
- `ROUTE_PROFILE`이 아직 없어서 `Waymarks.route_kind(공간)`가 기존 데이터에서 끌어낸다(출처 순서):
  1. `region_data/travel/<공간>.json` `kind`가 `route`가 아니면 권역(깃발 그대로)
  2. 노정 `route.json`의 `route_type` — 한강·대동강은 `"river"`
  3. 공간 id 접두사 `RIVER_` → river, `SEA_` → sea (`SEA_NAMHAE_JEJU`는 `route_type`이 없다)
  4. 그 밖의 노정 → land
- `Waymarks.is_flag(n, sp)`가 공간을 받는다. 깃대(`setup`)·지도 표지(`flags_in`)·역마 창 목록의 깃발 표시(`fast_travel._gather`)·처음 알 때 깃발 알림(`horse_ride._discover`)이 모두 이 한 함수를 거친다.
- 빠진 깃발 6개: 한강 마포 선창·목계진·충주, 대동강 대동문 선창·겸이포, 남해~제주 덕진다리. 전체 102 → 96.
- 그대로인 것: 노드의 `fast`와 '가 봄'(progress `travel_nodes`). 그 거점은 역마 창 목록에 그대로 있고(깃발 표시만 없음), 마부·깃발 목록에서는 '가 본 다른 곳 — 역마 창'으로 간다. 지도의 역마·배(뱃길)도 그대로.
- 참고: 한강·대동강은 `AUTO_RIDE_ALLOWED=false`라 예전에도 `horse_ride`가 깃대를 세우지 않았다(지도 표지·마부 목록 '깃발 — ○○'만 있었다). 실제로 화면에서 사라지는 깃대는 남해~제주 덕진다리 하나다.
- 충돌체(결정 6): 깃발 키트(`kit/station/waymark.gd`)에 충돌체가 없음을 시험으로 확인했다.

## 3. 사건 선언 고을 막음 (F-1 · C17)

- `fast_travel.gd`의 `FIRST_SPACE`와 남원 전용 분기를 지웠다.
- 사건 머리에 선언: `travel_gate = { leave_space_until: <풀림 변수>, notice: <알림 한 줄>, spaces: [공간…](선택) }`.
  남원: `{ leave_space_until: "CASE_NAMWON_COMPLETE", notice: "남원 일이 아직 끝나지 않았다 — 고을을 떠날 수 없다" }` (`story/namwon/namwon_data.gd`).
- `fast_travel.gate_for(공간, 지금 사건 id, 지금 phase)`: 그 공간에 올린 사건(`case_registry.ids_for`) + 지금 도는 사건을 보고, 선언이 있는데
  풀림 변수가 거짓이고 · 저장된 phase가 done이 아니고 · 지금 도는 그 사건의 phase가 done이 아니면 막는다(예전 남원 분기의 세 풀림 조건 그대로).
  `gate_why(main)`은 이것을 부르는 얇은 껍데기라 부르는 곳(역마 창·역참 API·마부·깃발·`reachable_from`)은 바뀌지 않았다.
- 사건 데이터는 크므로(`data()`) 선언만 공간별로 한 번 읽어 둔다(`clear_gate_cache()`는 시험용).
- 남원 밤 먼 길 막음(`case_fn.travel_lock()`)은 그대로 두었다. 장면 안 조건(dusk_prep·phase)에 따라 매 순간 바뀌는 hook이라 데이터 선언으로 옮기는 것이 자연스럽지 않다. 둘 다 '사건이 정하고 공통 장치가 읽는' 같은 계약이다(E절 표).

## 4. 사건 필수 메타 검사 (C46 최소판)

- 새 검사기 `tools/story/validate_case_meta.gd`(끝 줄 `CASEMETA PASS n warn=w`), `validate_event_class.gd`와 나란히 돌린다.
- 필수: `id · record_title · region · outcome_var · reset_vars · requires · EVENT_CLASS · SOURCE_ID`. `requires`는 비어도 되지만 키는 있어야 한다. `id`는 등록 id와 같아야 한다. `reset_vars`는 목록 또는 사전(강릉·경주는 `{변수: ""}` 사전 꼴 — `story_state.clear_saved`가 키를 돌므로 동작이 같다. 데이터는 바꾸지 않고 검사기가 둘 다 받는다).
- 경고(실패 아님): 남원 아닌 사건에 `rule_label`이 없으면("범의 버릇"이 뜸) · 싸움터가 있는데 `combat_bait_item`이 없으면(떡을 던짐).
- 지금 경고 5: 한양 `rule_label` 없음 · 경주·평양·함흥·제주 `combat_bait_item` 없음.
- **사건 데이터에 더한 키: 남원 `"requires": {}` 하나.** (없을 때도 `case_registry.unmet_key`가 {}로 읽었으므로 동작은 같다.) 남원 `travel_gate`는 3절 F-1로 더한 것이다.
- F-5 전체 검사기(도시 profile·공통 코드 id 분기·heard `by` 등)는 만들지 않았다.

## 5. 화면 (창 모드 1024×768, 시험 저장 `user://cz_shot_*.json` — 찍은 뒤 지움, 실제 저장은 건드리지 않음)

`seolhwa_godot/shots/commonize1/before/`·`after/` (git 밖)

| 장면 | 파일 | 본 것 |
|---|---|---|
| 남원 주모 첫 대화 | `namwon_jumo.png` | 전·후 시점 13.6/38/38 같음. 픽셀 차이는 주모 그림의 숨쉬기 프레임(56×136px 안)뿐 |
| 한양 포졸 대화 | `hanyang_talk.png` | 전: 도성 안 구역 28/45 → 후: 13.5/38/38, 두 사람 사이 겨냥. 포졸이 순찰로 걸어가도 둘 다 화면 안 |
| 경주 마을 노인 대화 | `gyeongju_talk.png` | 22/40 → 13.5/38/38. 노인·나그네 가운데, 나무는 반투명(예전과 같음) |
| 제주 해녀 대화 | `jeju_talk.png` | 22/40 → 13.5/38/38. 해녀 둘·나그네·불턱이 한 화면 |
| 육로 노정 깃발(삼남대로 전주) | `land_flag_jeonju_near.png` | 전·후 모두 쪽빛 깃발이 서 있다 |
| 바닷길 덕진다리 | `sea_deokjin_flag.png` | 전: 길가 깃발 → 후: 없음(말 안내만) |
| 한강 마포 선창 | `river_mapo_noflag.png` | 전·후 모두 깃발 없음(뱃길 마을, 위 2절 참고) |

다시 찍기:
- 대화: `godot --path seolhwa_godot res://scenes/region.tscn --resolution 1024x768 -- --region=GG_HANYANG --ridefresh --ridevars=MAIN_MASTER_TRACE=HANYANG --talkshot=auto --notitle --winshot --shotdir=… --savefile=user://cz.json` (새 도구 `scripts/story/talk_shot.gd` — 이야기 인물 곁으로 가서 `d.interact` 뒤 첫 대사에서 찍음. 남원은 `--ridefixture=res://story/namwon/test_early_save.json --talkshot=jumo`)
- 깃발: `--route=JL_NAMWON_UNBONG-GG_HANYANG --stationtest=flagshots:rt_jeonju --winshot` · 바닷길: `--route=SEA_NAMHAE_JEJU --warp=-443.1,-38.4 --shot=… --waitload --frames=300 --quit --winshot --nostory`

## 6. 시험 (차례로, 하나씩)

| 시험 | 결과 |
|---|---|
| `tools/story/validate_event_class.gd` | EVENTCLASS PASS checked=127 (exit 0) |
| `tools/story/validate_case_meta.gd` (새) | CASEMETA PASS 8 warn=5 (exit 0) |
| `tests/registry/case_registry_test.gd` | REGTEST PASS 47 (exit 0) |
| `tests/audio/sound_test.gd` | SOUNDTEST PASS 38 (exit 0) |
| `tests/onboarding/onboarding_rule_test.gd` | ONBOARDRULE PASS 64 (exit 0) |
| `tools/story/map_leads_test.gd` | MAPLEADS PASS fixtures=53 (exit 0) |
| `tests/commonize/commonize_test.gd` (새) | COMMONTEST PASS 49 (exit 0) |
| `tools/run_story_tests.sh` 전체(마지막 한 번) | **52/52 PASS**, SCRIPT ERROR 0, exit 0 — 새 `travel:sea-waymark` 포함(51 → 52). `station:namwon`(남원 첫 사건 막음 문구)·`namwon:onboard`(대화 거리 13.5·12.15) 그대로 통과 |

새 시험:
- `tests/commonize/commonize_test.gd`(헤드리스 `-s`):
  A 대화 카메라 우선순위 — 기본 · 사건 덮어쓰기 · 인물 덮어쓰기 · 사건 false · 인물 false · 사건 false 위 인물 값 · 인물 true · 남원 38/13.5/38 그대로 · 다른 일곱 사건 공통 값.
  B 고을 막음 — 남원 선언이 있고 `FIRST_SPACE`가 없다 · 남원 첫 사건 전 막힘(같은 문구) · 도는 중 막힘 · phase done/저장 done/완료 변수로 풀림 · 다른 공간은 안 막음 · 가짜 사건 `tests/commonize/gate_dummy`(선언 있음) 막힘·풀림 · 선언 없는 `reg_dummy`는 안 막음.
  C 깃발 — river·sea 노정 깃발 0 · 노정 종류 · land 노정·권역 깃발 그대로(남원–한양 5, 남원 13) · 전체 96 · 물 노정 6 거점 fast 그대로 · 깃발 키트 충돌체 0.
- `travel:sea-waymark`(`travel_rules_test.gd --traveltest=waymark`, `--route=SEA_NAMHAE_JEJU`): 깃발 목록·깃대 노드 없음 · 뱃길 그대로 · 덕진다리에 가면 '가 봄' 적힘 · 곁에 깃발 E 없음 · 역마 창 목록에 그대로(갈 수 있음·깃발 아님) · 마부·깃발 목록에 '깃발 — 덕진다리' 없음, 역마 창으로.
- 남원 첫 사건 막음은 기존 `station:namwon`(역마 → 제주 막힘 → 남원 첫 사건 막음 문구)이 새 장치로 그대로 통과한다.

## 7. 새 소유 파일

| 규칙 | 소유 |
|---|---|
| C27 대화 카메라 | `scripts/camera_rig.gd` `TALK`·`talk_spec` → `scripts/story/story_director.gd` `interact`·`_talk_camera`·`talk_camera_base` |
| C22 깃발(land만) | `scripts/region/waymarks.gd` `route_kind`·`space_has_flags`·`is_flag(n, sp)` |
| C17 고을 막음 | `scripts/region/fast_travel.gd` `gate_for`·`gate_why` ← 사건 `case.travel_gate` |
| C46 사건 메타 | `tools/story/validate_case_meta.gd` |
| 시험·도구 | `tests/commonize/commonize_test.gd` · `tests/commonize/gate_dummy/` · `scripts/region/travel_rules_test.gd`(waymark) · `scripts/story/talk_shot.gd`(--talkshot) |
