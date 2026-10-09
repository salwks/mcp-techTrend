# namwon-v32 보고 — 남원 「산길의 실종」 v3.2

기준 문서는 `seolhwa/docs/scenario/seolhwarok_NAMWON_v3.2_scenario.md`와 `seolhwarok_NAMWON_v3.2_DECISIONS.md`다.
대화 문체 요청서(`seolhwarok_DIALOGUE_REVISION_REQUEST_v1.0.md`)는 저장소에 없어서, 대사는 시나리오 원문을 그대로 썼다.

## 착수 순서 3 — ACT 0~2 (2026-10-09)

ACT 3 이후(고갯길 회상·첫 조우·전투 키·포수·방앗간·밤·동아줄)는 건드리지 않았다. 지금도 옛 흐름 그대로 돌아간다.
다만 밤으로 넘어가는 문만 주막에서 외딴집으로 옮겼다(아래 5).

### 1. 바뀐 흐름

| 장면 | 지금 | 파일 |
|---|---|---|
| S0000 여는 장면 | 검은 화면 → 이겸의 세 문장(사이 0.4초) → 기록책 한 장 **「남원」** → 덮고 화면이 열린다 | `namwon_case.prologue_open` |
| 이동 안내 | `W A S D 이동`: 실제로 **5m 넘게 걸어야** 끝난다. 걸은 거리를 더해 센다. 한 프레임에 3m 넘게 옮겨진 것(순간이동·여는 장면)은 세지 않는다 | `onboarding.track_move` |
| 달리기 안내 | 이동이 끝나면 `Shift 달리기`가 뜬다. 실제로 **2초 넘게 달려야**(게임 시간, 달리는 그림일 때) 끝난다. 둘 다 핵심 안내(CORE)라 시간으로는 끝나지 않는다 | 같은 곳 |
| 길가 짚신 | 4m 안에서 아주 약한 먹빛(`mark_r` 4, `mark_a` 0.4), 2m 안에서 `E 살펴보기`. 속말 “오래 버려진 짚신이다.” 단서가 아니고 사건도 세우지 않는다 | `namwon_data.objects` roadside |
| 전경 | 이미 만든 그대로 둔다(성벽 → 「남원」 → 「설화록」 → 돌아옴). 나그네 둘(S0000-C)도 그대로 두었다 | — |
| 주막 주변대화 | 주막 15m 안에 들면 조작을 쥔 채로 들린다. 주모 “아직도 안 왔다고?”, 손님 “사흘이면 돌아올 사람이면 벌써 왔지.” 주모 머리 위에는 「…」가 뜬다(이미 있던 talk mark) | triggers `s0002_overhear` |
| 대화 카메라 (CAMERA 1A) | 사건 머리 `case.talk_camera` = pitch 38 · 거리 13.5 · fov 38. 이야기 인물에게 말을 걸면 플레이어와 인물 사이를 겨냥한다. 끝나면 평소 시점으로 돌아간다. 남원 이야기 인물 모두에 적용되고, 다른 사건은 이 값이 없어서 그대로다 | `story_director._talk_camera` |
| 주모 물음 | 처음 셋(어떤 사람이오? / 무슨 일이오? / 보지 못했소.)을 고르면 넷(언제 사라졌소? / 어느 길로 갔소? / 아이들은? / 마을에서는 찾아보지 않았소?)이 열린다. 한 번 물은 것은 다시 나오지 않는다. 결정 4의 장정 셋·포수 대사를 넣었다. 새 엔진 없이 `choice·loop·when·flag·do`만 썼다 | `namwon_data.jumo_questions`, S0002 |
| 북쪽 고갯길 | “어느 길로 갔소?”를 물으면 `heard_pass_road`가 서고 지도에 북쪽 고갯길이 ‘들음’으로 적힌다. 그다음 `M 지도` 안내가 뜨고, **지도를 실제로 열어야** 끝난다. 아이들에게 “어디로 가셨니?”를 물어도 같다(§73 두 길) | `{ "discover": "north_pass" }` |
| 이겸 연결 (CAMERA 1B) | 물음을 둘 이상 마치면 한 번 뜬다. 카메라가 10% 다가선다(13.5 → 12.15). 주모 “…그 책.” ~ “그리고 똑같이 고갯길을 물었소.” | `namwon_case.igyeom_link` |
| 사건 기록 | 이겸 연결 뒤에 사건이 선다. 도장 소리(`journal_stamp`) + 「새 사건 — 「산길의 실종」」이 뜨고, 이어 `R 기록책 — 새 사건이 적혔다` 안내가 뜬다. 이 안내는 **기록책을 열어야** 끝난다. 예전에는 첫 조사 뒤에 기록책 안내가 떴는데, 그것은 뺐다 | `start_case`, `onboarding.on_case_started` |
| 첫 기록 | 기록책 맨 위에 원문 네 줄이 그대로 적힌다. “떡장수 아낙이 사흘째 돌아오지 않는다.” / “마지막으로 북쪽 고갯길로 갔다.” / “집에는 아이 둘이 남아 있다.” / “이겸으로 보이는 선비도 이 일을 물었다.” | `namwon_case.FIRST_RECORD` |
| 역참·마부 | 남원 역참(`region_data/stations.json`의 `namwon`)의 기다리는 말 자리 7m 안에 처음 들면 한 번 뜬다. 자리는 그 파일에서 읽고(`station_yard`·`station_wait`), 새 좌표는 만들지 않았다. 마부 “먼 길 가시오?” 다음 세 갈래로 고른다. `H 역마 이동`은 역마로 갈 곳이 실제로 있을 때만 뜬다(다른 공간이거나, 같은 공간이면 300m 밖의 가 본 역마 거점) | `station_intro`, `fast_ready` |
| 이웃 아낙 (CAMERA 2A) | 사건이 섰고, 오누이를 아직 안 만났고, 첫 조우 전일 때 외딴집 18m 안에 들면 한 번 뜬다. 장면 전용 인물 `neighbor_visit`(CHR_HUM_010)이 문에서 나와 말한 뒤 마당 → 방앗간 쪽으로 걸어가 사라진다. 카메라는 pitch 42 · 거리 24 · fov 34로, 집을 위에, 플레이어를 아래에 둔다 | `neighbor_visit` |
| 오누이 첫 대화 | 원문 대사로 시작한다. 주막을 거치지 않고 먼저 왔으면 짧은 다른 인사 뒤 사건이 선다. 이어 세 물음(언제 나갔니? / 어디로 가셨니? / 지난밤엔 괜찮았니?)을 고른다. “지난밤”은 단서 **어젯밤의 목소리**(들음 — 누이)와 플래그 `voice_at_night`만 남긴다. K_MIMIC은 이제 주지 않는다. 그 뒤 기도 복선(아우·누이 세 줄, `prayer_foreshadow`)이 짧게 나온다 | S0003, `kids_questions` |
| 아궁이·함지 | 아궁이는 원문 두 줄을 보여 준다. 함지는 조사 카드 → 누이 “엄마가 장에 갈 때마다…” → “그날도?” → “네.” → 기록 **떡가루 묻은 함지**(실종 당일 새벽에도 떡을 만들어 장으로 갔다). **`mother_flashback()`과 `mother` 인물은 지웠다** | objects hearth·kneading |
| 낮 음악 | 남원 낮 탐색 동안(여는 검은 화면 뒤 ~ 첫 조우 전, 5:30~18시) `bgm_day_calm`이 4초 동안 천천히 들어온다. 대화 중에는 절반 크기로 줄인다. 첫 조우·밤이 되면 멈춘다. 다른 공간으로 가면 그쪽 사건이 원하지 않아 멈춘다 | `case_fn.music_wanted`, `story_director._update_music` |

### 2. 주막 잠 → 외딴집 기다리기 (§3.2)

`rest()`와 주모의 “하룻밤 묵어 가겠소.”를 지웠다. 이제 외딴집 마당 구석(`hide_spot`)에서 “해 지기를 기다린다”(`dusk_wait`)를 고르면 `night_fall()`로 밤이 된다.
조건은 예전 쉬기 조건과 같다(사건이 섰고, 첫 조우를 했거나 단서 다섯 개 이상).
그 뒤로는 예전 밤 흐름(밤 준비 → 숨어 기다리기 S0007 → A/B/C)이 그대로 이어진다. 이 부분은 ACT 6을 새로 짤 때 바뀔 다리다.

예전 저장에서 이어 하면서 주막에서 자던 길을 기억하는 사람을 위해, 이 조건이 되면 주모가 한 줄 일러 준다(“해 지기 전에 그 집에 가 보시오”).
주막 쉬기(F, `save_keeper.rest`)는 일반 기능으로 그대로 남겼다.

### 3. 첫 E 흔들림 — 원인과 고침

**원인.** 새 게임 직후 시험(continue:new)은 주모 곁으로 순간이동해 E를 누른다. 그곳은 전경 늦은 트리거(`s0001_vista_late`, 주막 40m)의 범위 안이다.
`story_director.update`는 E 대상을 매 프레임 잡지만, 자리 트리거는 0.2초마다만 본다.
그래서 주모가 E 대상으로 잡힌 뒤 한두 프레임 늦게 트리거가 전경 장면을 시작할 수 있었다.
트리거가 이야기를 시작한 바로 그 프레임에도 `_update_target()`이 대상을 그대로 남겼다.
그 사이 누른 E는 다음 프레임 입력에서 `runner.busy`에 막혀 버려졌다.
시험 쪽 진단이 나중에 찍힐 때는 전경이 이미 끝나 있었다(auto라 짧다). 그래서 “대상은 jumo, busy·modal 아님”으로 보였다.

**고침**(`story_director.update`).
1. 트리거가 이야기를 시작한 프레임에는 E 대상을 내놓지 않는다.
2. E 대상이 새로 잡히는 프레임에는 그 자리 트리거를 먼저 본다(0.2초를 기다리지 않는다).

이제 대상이 보일 때는 그 자리의 트리거가 이미 끝나 있다.
continue:new를 `--storylog`로 열 번 돌렸다. 열 번 모두 트리거가 먼저 돌고 나서 E가 한 번에 들어갔다(다시 누름 0번).
고치기 전에는 여덟 번 중 한 번(첫 고침만 넣었을 때)은 고을 사람 E에서 같은 경쟁으로 실패했다.
continue_test의 “다시 누르기”는 안전망으로 남겼다.

실제 놀이에서는 이 자리(주막 40m)에 순간이동해 들어갈 일이 거의 없다. 같은 꼴(대상이 막 잡힌 자리에서 트리거가 늦게 도는 것)은 다른 트리거에도 생길 수 있어서 일반 규칙으로 고쳤다.

### 4. 저장

- 저장 형식(`version` 2, `cases.namwon`)은 그대로다.
- `on_load`가 없앤 회상의 `show_mother`와 걸어가던 이웃 아낙의 `neighbor_visit_on`을 지운다.
- 예전 이른 저장(`test_early_save.json`, 주모를 만나기 전)은 그대로 이어진다. 이어 한 뒤 가장 가까운 이야기 인물(손님)과 E로 말이 열린다.
- 예전 저장에 `case_started`가 있으면 북쪽 고갯길은 이미 지도에 적혀 있다(예전 조건). 새 조건은 `heard_pass_road`다.
- 예전 저장의 사건 기록 요약은 주막 경로면 새 첫 기록 네 줄로 보인다.
- 예전 저장에서 MOVE를 이미 본 사람에게는 달리기 안내가 갑자기 뜨지 않는다. 달리면 조용히 끝난다.

### 5. 새·바뀐 플래그

`jq_intro` · `jq_who` · `jq_what` · `jq_none` · `jq_when` · `jq_route` · `jq_kids` · `jq_search` · `heard_pass_road` · `igyeom_link` · `station_tut_seen` · `st_q_rent` · `st_q_how` · `neighbor_visit_seen`(v3.2 권장) · `neighbor_visit_on`(잠깐) · `met_kids`(그대로) · `kq_when` · `kq_where` · `kq_night` · `voice_at_night`(v3.2 권장, 단서 id와 같다) · `prayer_foreshadow`.
지운 것: `show_mother`, 인물 `mother`, 함수 `mother_flashback`·`rest`·`can_rest`(→ `night_ready`).

### 6. 시험

| 시험 | 결과 |
|---|---|
| `tools/story/validate_event_class.gd` | EVENTCLASS PASS checked=126 (exit 0) |
| `tests/registry/case_registry_test.gd` | REGTEST PASS 47 (exit 0) |
| `tests/audio/sound_test.gd` | SOUNDTEST PASS 37 (exit 0) |
| `tests/onboarding/onboarding_rule_test.gd` | ONBOARDRULE PASS 43 (exit 0) — G(이동 5m·순간이동 제외·달리기 2초) 8개 더함 |
| `tools/story/map_leads_test.gd` | MAPLEADS PASS fixtures=45 (exit 0) |
| `tools/run_story_tests.sh` 전체(마지막 한 번) | 44/44 PASS, SCRIPT ERROR 0, exit 0 (namwon:A/B/C 결말 A·B·C, onboard, continue:namwon-early·new, save:slot-load 포함) |

`namwon:onboard`는 새 흐름으로 다시 썼다. 대본은 `scripts/story/onboard_test.gd`다. 확인하는 것:
- 이동·달리기·짚신: 순간이동은 이동으로 치지 않는다. 2m에는 남고 5m에서 끝난다. 걷기로는 달리기가 안 끝나고, 1초에는 남고 2초에서 끝난다. 짚신은 4m 안/밖 먹빛과 2m 'E 살펴보기'를 보고, 단서가 아님을 본다.
- 주모: 실제 E 키로 첫 말을 건다. 「…」가 뜬다. 첫 물음 셋 → 넷이 열리고, 물은 것은 사라진다. 이겸 연결은 물음 하나 뒤가 아니라 둘 뒤에 온다. 도장 소리가 난다. 카메라 거리 13.5와 12.15를 본다. 장정 셋·포수 대사, 북쪽 고갯길 ‘들음’을 본다.
- 첫 기록과 안내: 첫 기록 네 줄이 원문과 같다. M·R 안내는 14초가 지나도 남아 있다가, R 키와 M 키로 실제로 열어야 끝난다.
- 역참: 마부는 처음 한 번만 뜬다. 역마로 갈 곳이 없으면 H 안내가 없다.
- 외딴집: 이웃 아낙이 나왔다가 사라진다. 오누이 세 물음이 열리고 물은 것은 사라진다. 지난밤은 들음이고 K_MIMIC이 아니다. 기도 복선, 아궁이, 함지(어머니 인물이 생기지 않고 `call`이 없음)를 본다. `mother_flashback`·`rest` 함수가 없음을 본다.
- 그 뒤: 첫 단서 안내 단계와 첫 조우는 예전 그대로 본다. 첫 조우 뒤 낮 음악이 멈추는지 본다.

`namwon:A/B/C`(`story_test.gd`)도 고쳤다.
- 주모 물음 → 이겸 연결·첫 기록 네 줄을 본다.
- 오누이에게서 K_MIMIC 대신 어젯밤의 목소리를 본다.
- 함지에 회상이 없음을 본다.
- 밤은 `dusk_wait`로 넘어가고, `rest` 함수가 없음을 본다.
- 결말 A/B/C와 FIXED_BEATS는 예전 그대로 본다.

### 7. 화면 (창 모드, 시험 저장 `user://st_shots_v32.json`)

`seolhwa_godot/shots/namwon_v32_act02/`(git 밖)에 있다.

| 장면 | 파일 |
|---|---|
| 여는 장면 | `onboard_prologue_line.png`, `onboard_prologue_book.png` |
| 전경 | `onboard_vista.png`, `onboard_title_seolhwa.png` |
| 주모 대화와 물음 | `onboard_talk_jumo.png`, `onboard_choices_jumo_2.png`, `onboard_choices_jumo_3.png` |
| 지도 안내 | `onboard_map_hint.png`, `story_ONBOARD_map_open.png` |
| 첫 기록 | `story_ONBOARD_journal_first_record.png` |
| 마부 | `onboard_talk_mabu.png` |
| 이웃 아낙 | `onboard_talk_neighbor.png` |
| 오누이 | `onboard_talk_nui.png`, `onboard_talk_au.png`, `onboard_choices_kids_3.png` |

눈으로 확인한 것:
- 첫 기록 쪽에 네 줄과 ‘들음 — 주모’가 보인다.
- 이웃 아낙은 문 앞에, 플레이어는 화면 아래에 선다. 처음에는 집만 겨냥해서 플레이어가 대화창 뒤에 가려졌다. 그래서 겨냥점을 플레이어 쪽으로 조금 옮겼다.
- 마부 대화 때 마부 그림은 제 일을 계속하며 멀리 걸어간다(아래 정할 것 2).

### 8. 남긴 것 (다음 단계)

- ACT 3~5: 고갯길 회상(`pass_memory`를 새 회상으로), 첫 조우 연출과 전투 키 학습(J·K·L·I·U, K·L을 실제로 해야 끝나게), 포수, 방앗간, 연결 추론.
- ACT 6~: 해 질 무렵 귀환과 경고, 준비, `hide_spot` “기다린다”. 이번 `dusk_wait`·`night_fall` 다리는 그때 바뀐다. 밤 시작의 정답 선공개 문장(§3.3)도 그때 고친다.
- `SKILL_GUARD_SHOVE`를 남원 완료에서 빼는 일(결정 2)은 하지 않았다. `story_test`는 아직 예전처럼 받아밀기 해금을 본다.
- K_MIMIC을 얻는 길: 지금은 남원 어디서도 얻지 않는다(“지난밤”에서 뺐다). 흉내 의심은 목소리 증언·밀가루 발자국·밤에 직접 본 것으로 잇는 일(§73)이라, ACT 5 연결 추론에서 붙인다. 지금 해결법 C의 “???” 제목은 K_FOOD·K_TERRITORY·K_FLOUR 셋으로도 풀린다.

### 9. 정할 것

1. **역참 마부를 언제 띄울까.** 남원 역참 문 앞은 주모 자리에서 14m 거리이고, 전경에서 주막으로 가는 길 위에 있다. 사건 전에 띄우면 주모보다 마부가 먼저 나온다. 그래서 사건이 선 뒤 기다리는 말 7m 안에서만 띄운다. 이렇게 하면 주막에서 바로 북문으로 가는 사람은 마부를 못 만날 수 있다. 사건 전에도 띄울지, 지도 붉은 표로 한 번 일러 줄지 정해야 한다.
2. **마부 그림.** 대화 때 역참 그림(`station_life`)의 마부가 일을 멈추지 않는다. 카메라는 마부가 12m 안이면 마부 쪽을, 멀면 기다리는 말 쪽을 겨냥한다. 대화 동안 마부를 플레이어 앞으로 불러 세우려면 `station_life`에 “잠깐 서기”를 더해야 한다(역참 작업 파일).
3. **나그네 둘(S0000-C)**은 v3.2 원문에 없는 장면이지만 남겼다. 뺄지 정해야 한다.
4. **“빈 그릇”**: 이웃 아낙 그림(villager_f)은 머리에 무언가를 이고 있다. 손에 든 빈 그릇 그림은 따로 없다.
5. **H 역마 ‘열림’의 뜻.** 지금은 다른 공간이거나 같은 공간 300m 밖의 가 본 역마 거점이 하나라도 있으면 열린 것으로 본다. 새 게임 첫 방문에서는 늘 닫혀 있다. 다른 기준이 필요한지 정해야 한다.
6. 대화 카메라를 남원 밖 사건에도 쓸지 정해야 한다. 지금은 사건 머리에 `talk_camera`를 넣은 사건만 쓴다.
