# 실제 게임 재기획 — 2단계 대화 UI·카메라(+ 저장 안전 확인)

기준: `seolhwa/docs/replanning/Seolhwarok_Dialogue_Camera_UX_Spec_v1_1.md`(이하 **대화 v1.1**), 사용자 결정 `seolhwa/docs/replanning/DECISIONS_stage1.md` D5·D8·D9.
1단계 분석: `replanning-stage1-analysis.md`. 브랜치 `claude/youthful-gauss-d0fxzv`, Godot 4.7.1, M1 Mac.

표기 — 이 보고서의 모든 항목은 셋 중 하나로 적는다.
- **설계**: 문서·결정에만 있고 코드에 없다.
- **코드 반영**: 코드에 들어갔지만 그 항목을 직접 재는 시험은 없다(화면·로그로만 봤거나 아직 안 봤다).
- **테스트 완료**: 이번에 실제로 돌린 시험·촬영으로 확인했다(명령과 결과를 §4에 적었다).

---

## 0. 저장 안전(재기획 추가 지시 1) — 테스트 완료

- 실제 저장 백업: `~/Documents/seolhwa_save_backup_20261016_005208/설화록/`(282개, 앞 에이전트가 만듦).
  - 지금 `progress.json` sha256 `f878cd6c…08a84d`, `settings.json` `af969ab1…a84d`가 백업 사본과 **같다**.
  - 즉, 백업 뒤로 사용자 저장에 쓴 것은 없다.
- 고친 것(앞 에이전트 3aaba1c, 이번에 확인):
  - 시험·촬영·도구 실행이면 저장 파일 경로를 모래상자 `…/app_userdata/설화록_test/`로 바꾼다(`save_guard.gd`).
  - `--savefile`은 `--nostory`에서도 가장 먼저 적용된다.
- 이번 확인 절차:
  1. 사용자 폴더 `~/Library/Application Support/Godot/app_userdata/설화록/`의 **파일 56,203개 전부**(kit_cache 포함)의 mtime·크기·sha256을 적었다(01:21).
  2. 1단계 사고를 낸 명령을 그대로 다시 돌렸다: `--warp=-3005,240 --mapshots=… --mapzooms --nostory`(창 실행, 200초 제한).
     - 로그: `SAVEGUARD sandbox=…/설화록_test why=--warp progress=…/설화록_test/tool_progress.json`
     - 로그: `PROGRESS checkpoint place 남원`
  3. 묶음 시험 둘(`talk:namwon`, `save:slot-load`)과 `SAVEGUARDTEST`를 돌렸다.
  4. 다시 적어 비교했다 → **mtime·크기 diff 0, sha256 diff 0**(56,203개 모두 같다).
  5. 모래상자는 받았다:
     - `tool_progress.json`(saved_at 01:26:36, `--nostory` 재실행 직후 확인)
     - `st_talk_namwon.json`, `st_save_slot-load*.json`, `settings.json`(01:25)
  6. 2단계 작업을 다 마친 뒤(02:17, 촬영 30여 회·단위 시험 10개·묶음 시험 전체 79개 뒤) 같은 방법으로 한 번 더 비교했다 → **56,203개 mtime·크기·sha256 모두 01:21과 같다**.
- 지킴 시험 추가(c5ac11b): 명령줄 가리기를 순수 함수 `SaveGuard.classify()`로 빼고, 9가지 명령줄을 넣어 본다.
  - 놀이 명령줄 → `user://`: 인자 없음 · `--savefile+--devtravel` · `--view/--scale/--fullscreen`
  - 모래상자: `--nostory` 지도 촬영 · `--talkshot` · `--storytest` · `--saveroot` · `-s`
  - 결과 `SAVEGUARDTEST PASS 19`(이전 10).
- 남은 것(저장 아님): 엔진 로그 `user://logs/`는 Godot 엔진이 시작할 때 연다.
  - 그래서 `--log-file`을 주지 않은 실행은 사용자 폴더 `logs/`의 돌려쓰기(최대 5개)를 건드린다.
  - 묶음 시험과 이번 촬영은 모두 `--log-file <모래상자>/logs/…`로 돌렸다.
  - `shader_cache`·`kit_cache`·`vulkan`은 캐시라 같이 쓴다(3aaba1c의 결정 그대로).
  - 이번 비교에서는 캐시도 바뀌지 않았다.

---

## 1. 확인한 기존 구현 및 문제점

앞 에이전트가 남긴 것(bef3bde, 커밋 안 된 WIP)을 다시 하지 않고 확인했다.

| 항목 | 확인 결과 | 상태 |
|---|---|---|
| CAM_TALK_2 구도 계산 `talk_frame.gd` | 설 자리 × yaw 후보(0·±25·±35°)를 투영해 겹침 0·가림 없는 구도를 고른다. 기름집 아낙·주모 둘 다 `phase=side yaw=35 overlap=0 occ_npc=0` | 테스트 완료 |
| 대화 상자 215px(1080 기준 19.9%) | 1단계 290px(27%)에서 줄었다. 글 크기 이름 44·본문 40 그대로 | 테스트 완료 |
| WIP `onboarding.gd` | 말 걸기 접근 동안 안내·먹점·「…」를 감춘다 → **유지**(화면에서 WASD 안내가 흐려지며 사라짐 확인) | 테스트 완료 |
| WIP `talk_shot.gd` | `--talkpress`·`--talklong` → **유지**. 단, 긴 글 시험 문장이 '기름 사러' 대사였다. 참기름 강조 금지(결정 정정)와 겹칠 수 있어 **놀이와 무관한 중립 시험 문장으로 바꿨다** | 코드 반영 |
| **문제 1 — 긴 글 상자가 아래로 자람** | 글자 찍기 동안 Label이 보이는 글자만으로 줄을 나눠(기본 `VC_CHARS_BEFORE_SHAPING`) 상자가 찍히는 대로 커졌다. 아랫변 1010 → 1048. 낱말도 줄 끝에서 다음 줄로 뛰었다 | 고침, 테스트 완료 |
| **문제 2 — 고을 사람 겹침이 남음(D5 위반)** | `talk:namwon` 25회 중 4회 겹침(10% 틈 잣대 0.34~0.89) | 고침(§2) |
| 원인 2-a | 플레이어가 이미 0.75m 안에 붙어 서면 '상대를 뚫고 지나가지 않게' 검사가 모든 자리를 버렸다(`through` 54/54) | |
| 원인 2-b | 고을 사람은 카메라를 아예 돌리지 않았다 | |
| **문제 3 — 구도 계산이 무거움** | E 순간 한 번에 중앙값 51ms, 최대 125ms(헤드리스) | 고침 |
| 원인 3 | 설 자리 걷기 판정이 0.2m마다 고을 전체 충돌체를 훑었다 | |
| **문제 4 — 남원 이야기 시험 회귀**(조정자 보고) | `namwon:A/A2/B/C/onboard`가 주모 S0002·오누이 S0003·방앗간·포수·노크 사이 조작·밤 조작 비율·이웃 아낙에서 실패 | 고침, 테스트 완료 |
| 원인 4-a | `interact()`가 접근(한 걸음·0.55초 구도)을 **기다린 뒤** 대본을 시작했다. 그동안 `runner.busy`가 거짓이라 시험의 `_idle()`이 곧바로 지나가 장면 전에 검사했다 | |
| 원인 4-b | 노크 사이처럼 대본이 `free_move`로 조작을 돌려줄 때도 `talking`이 `blocks_move()`를 참으로 만들었다(밤 조작 비율 26~40%) | |
| 대화 복귀 | 카메라 yaw 0·talk_yaw 없음·override/focus 없음·평소 거리·가림 기준점 없음·이동 잠금 풀림 | 테스트 완료(`talk:cycle` 8·12회) |
| E 연타 | 3프레임마다 E: 줄 건너뜀 0. 닫힌 뒤 0.15초 연타로 다시 열림 0 | 테스트 완료 |
| 1인칭 C68 | 대화 구도·한 걸음·yaw 회전을 쓰지 않는다. 1인칭이 풀리지 않는다 | 테스트 완료(`talk:cycle-fp` 4·12회) |
| 1인칭 돌아보기 | 묶음 `view:namwon`(VIEWTEST, 시선 오차 검사)로 본다 → §4 | 테스트 완료 |
| 선택지 자리 | 대화 상자 자리(아랫변 고정)에서 위로. 두 사람을 덮지 않는다 | 테스트 완료(화면) |
| 고을 이름 「남원」 띠 | talkshot 순간이동 직후 화면 위쪽에 뜬다(1단계와 같음). 대화와는 겹치지 않는다 | 미해결(§5) |

---

## 2. 유지·수정·신규

| 구분 | 무엇 | 근거 |
|---|---|---|
| 유지 | 기본 카메라(CAM_FIELD), 글 크기 44/40, 글자 찍기 45자/초, E·Space·Enter·클릭 넘기기 | 대화 v1.1 §0 보존 |
| 유지 | 1인칭은 대화 구도 없이 돌아보기만 | C68, 1단계 §3-B6 |
| 유지 | 고을 사람은 **평소 카메라가 먼저**. 겹침 없는 자리가 하나라도 있으면 카메라를 돌리지 않는다 | D5, C27 |
| 수정 | **장면을 곧바로 시작**한다. 구도 미끄러짐 0.55초·한 걸음·상대 돌아봄(0.2초 늦게)은 첫 대사와 **함께** 흐른다. 첫 상자는 0.18초 흐려지며 들어온다 | 회귀(문제 4). 콘티 '0.70초에 상자 등장'과 달라졌다 → §5 |
| 수정 | 대본이 그사이 사람을 돌리거나(face) 플레이어를 옮기면 **대본이 이긴다**. 한 걸음은 멈추고, 늦은 돌아봄은 하지 않는다 | 사건 연출 보존 |
| 수정 | `talking`은 `free_move`(노크 사이·추격)일 때 이동·안내를 막지 않는다 | 회귀(문제 4-b) |
| 수정 | 고을 사람·마부: 한 걸음으로 겹침을 못 풀면 **마지막으로 카메라 옆 돌기**(평소 yaw ±25·35°). 0.55초 들어가고 0.45초 돌아온다. 돌았으면 상대 그림 쪽도 그 yaw 기준으로 맞춘다 | D5 '절대', D9 첫 수단 |
| 수정 | 대화 카메라를 끈 이야기 인물(`talk_camera:false`)도 같은 마지막 수단을 쓴다 | D5 |
| 수정 | 설 자리: 이미 붙어 섰으면 물러나며 비켜 서기를 허용. 첫 고르기에 답이 없으면 1.1·2.3m, 15°마다 한 번 더 | 문제 2-a |
| 수정 | 가림 검사는 비용 순으로 미루어 하고, 걷기 판정은 둘레 충돌체만 골라 쓴다 | 문제 3 |
| 수정 | 긴 대사: 줄바꿈은 온 글 기준(`VC_CHARS_AFTER_SHAPING`), 아랫변 고정(위로 자람) | 문제 1 |
| 신규 | 로그 `TALKFRAME`에 `raw`(틈 없는 겹침, 대화 v1.1 §4 '20% 이하' 잣대)·`ms`·`rel`·`rej`(버린 까닭) | 진단 |
| 신규 | 로그 `TALKUI`(창 픽셀 기준 상자·선택지 자리, 본문 글 픽셀) | 해상도 확인 |
| 신규 | 묶음 시험 `talk:cycle`·`talk:cycle-fp`(TALKCYCLE 판정) | 복귀·연타 회귀 막기 |
| 설계(미구현) | 대화 중 M/R 막기·Esc 선택지(대화 v1.1 §9), CAM_OBJECT·CAM_EVENT_WIDE 이름표 | 이번 범위 밖 |
| 설계(미구현) | T05 대화 직전·직후 저장/불러오기 | 이번 범위 밖 |

D9 순서가 코드에서 어떻게 적용되는지:
- 이야기 인물: ① 겹침 0인 후보 가운데 가림 없는 옆 돌기·한 걸음 → ② 그래도 가리면 두 사람 둘레만 점무늬(`occ_script`) → ③ 거리 0.9·0.8배.
- 고을 사람: ① 한 걸음 → ② 옆 돌기(걸음으로 안 될 때만) → ③ 배경 가림은 점무늬. 거리는 바꾸지 않는다.

---

## 3. 수정 파일과 주요 변경

| 파일 | 변경 | 커밋 |
|---|---|---|
| `scripts/region/save_guard.gd` | 명령줄 가리기를 `classify()`로 | c5ac11b |
| `tests/save/save_guard_test.gd` | 명령줄 9가지 → SAVEGUARDTEST 19 | c5ac11b |
| `scripts/story/onboarding.gd` | 접근 동안 안내·먹점·「…」 감춤(WIP 마무리) | 18bd8bd |
| 〃 | free_move일 때는 감추지 않음 | 09f887a |
| `scripts/story/talk_shot.gd` | `--talkpress`·`--talklong`(중립 문장) | 18bd8bd |
| 〃 | `TALKUI` 로그 | d942b9e |
| `scripts/story/story_ui.gd` | `VC_CHARS_AFTER_SHAPING`, `_keep_dialog_bottom()` | d942b9e |
| `scripts/story/story_director.gd` | 접근을 기다리지 않음(`_approach_tail`) | 09f887a |
| 〃 | `_step_player`는 끝까지 걸었나를 돌려준다 | 09f887a |
| 〃 | `talk_plain_begin`은 구도를 돌려주고, 옆 돌기 시작·끝(`_plain_turn_begin/_end`), `face_toward_player` | 09f887a |
| 〃 | `blocks_move` free_move 예외, TALKFRAME 로그 확장 | 09f887a |
| `scripts/story/talk_frame.gd` | `plan(…, turn_ok)`, `_eval`·`_occ_fill`(미룬 가림 검사) | 09f887a |
| 〃 | 2차 설 자리, 물러나기 허용, `_walkable`/`_hit`/`_gather_cols`, `raw`·`ms`·`rel`·`rej` | 09f887a |
| `scripts/story/ambient_talk.gd` | 돌았으면 상대 그림 쪽 지정 | 09f887a |
| `scripts/region/npc_ambient.gd` | `hold(key, toward, face="")` · `hold_face` | 09f887a |
| `scripts/region/station_keeper.gd` | 마부도 같은 처리 | 09f887a |
| `tools/run_story_tests.sh` | `talk:cycle`·`talk:cycle-fp`, TALKCYCLE 판정 | 83318b0 |
| `tests/onboarding/onboarding_rule_test.gd` | 가짜 감독에 `talking`(새 동작이 의도라 시험을 고침) | 1da8c85 |
| `scripts/region/station_test.gd` | 마부 취소 시험의 '자리 그대로'를 말 걸기 한 걸음 뒤 자리 기준으로(새 동작이 의도라 시험을 고침) | 이 보고서 커밋 |

참기름 관련 데이터·`DECISIONS_stage1.md`는 건드리지 않았다.

---

## 4. 실행한 테스트와 결과

공통 조건:
- 저장은 모두 모래상자다(`--savefile=user://s2b_*.json` → `설화록_test/`).
- 엔진 로그는 `--log-file <모래상자>/logs/`로 냈다.
- 화면은 창 실행 `--winshot`이다.

### 4-1. 기준 장면 전후(T01) — 테스트 완료

- 전(before) 화면은 git worktree로 찍었다.
  - 위치: `/Users/sinjaeho/Documents/works/seolhwa-before-3aaba1c`
  - 기준 3aaba1c = ce89ac9 + 저장 지킴만. 대화·UI 코드는 ce89ac9과 같다.
  - 저장 지킴이 없는 ce89ac9을 그대로 돌리면 실제 저장에 쓸 수 있어 이렇게 했다.
  - 이 worktree는 끝나고 지웠다.
- 후(after) 화면은 현재 코드다.
  - 명령: `--talkshot=<id> --newgame --talkmid=12 --talkback --resolution 1920x1080`
  - 자리: 인물 발에서 (-0.6, +1.7), 카메라 쪽. 1단계 가림 재현 자리와 같다.

| 장면 | 전 | 후 | 로그(후) |
|---|---|---|---|
| 기름집 아낙 | 플레이어가 아낙 앞(카메라 쪽)에 서서 아랫몸을 가림. 상자 27% | 카메라 35° 옆 돌기, 두 사람 나란히, 서로 마주 봄(옆모습), 지붕 가림 없음. 상자 19.9% | `phase=side yaw=35 overlap=0 raw=0 occ_npc=0 ms=24.7` |
| 주모 | 플레이어 삿갓·몸이 주모를 거의 다 가림 | 같은 구도, 아궁이·주막 맥락 보존 | `phase=side yaw=35 overlap=0 raw=0 occ_npc=0 ms=24.0` |
| 복귀(back) | — | 대화를 끝까지 넘기고 45프레임 뒤: talk_yaw 없음·override/focus 없음·가림 기준점 없음·talking 거짓·거리 22/40 | 찍은 순간 yaw 0.31°·0.17°(0.45초 미끄러짐의 끝자락). `talk:cycle`에서는 0.7초 뒤 0 |

화면(`seolhwa_godot/shots/replan_stage2/`, 1280px JPEG):
- 기름집 아낙: `oil_wife_1_before.jpg` · `oil_wife_2_after_mid.jpg`(12프레임, 옮겨 가는 중) · `oil_wife_3_after.jpg` · `oil_wife_4_after_back.jpg`
- 주모: `jumo_1_before.jpg` · `jumo_2_after_mid.jpg` · `jumo_3_after.jpg` · `jumo_4_after_back.jpg`

전환이 부드러운지는 중간 화면(mid)과 0.55초 smoothstep 코드로 봤다. 녹화나 프레임 시간 측정은 하지 않았다(§5).

### 4-2. 대화 상자 해상도(D8, T04 일부) — 테스트 완료

- 명령: `--talkshot=jumo --talkpress=3 --talklong`, 선택지는 `--talkpress=12`.
- 숫자는 창 픽셀 기준이다.

| 창 | 논리 화면 | 한 줄 대사 상자 | 긴 글(4줄) | 선택지 | 본문 글 |
|---|---|---|---|---|---|
| 1920×1080 | 1920×1080 | y795~1010, 215px(19.9%), x 9~91% | y757~1010(23.4%) | y734~1010, 상자와 겹침 없음 | 40px |
| 1280×720 | 1920×1080 | y530~673, 143px(19.9%) | 23.4% | y489~673 | 27px |
| 2560×1440 | 1920×1080 | y1060~1347, 287px(19.9%) | 23.4% | (안 찍음) | 53px |
| 1680×1050(16:10) | 1920×1200 | y773~982, 209px(19.9%) | 22.9% | y724~982 | 38px |

- 대화 v1.1 §3 목표(1080: y795~1010, 215px)와 픽셀까지 같다.
- 긴 글은 재기획 상한 25% 안에서 위로 자란다(고친 뒤).
- 1280×720 본문 27px은 1080의 40px과 같은 비율이다(canvas_items 늘림).
- 화면:
  - 한 줄 대사: `res_<창>_first.jpg`
  - 긴 글: `res_<창>_long.jpg`
  - 선택지: `res_<창>_choice.jpg`(1920·1280·1680)
- 1600×900·1280×800·1024×768(T04의 나머지)은 돌리지 않았다(미검증).

### 4-3. 복귀·연타·1인칭(T03 일부) — 테스트 완료

- `--talkshot=oil_wife --talkcycle=12 --newgame`(헤드리스): **TALKCYCLE PASS 12**.
  - 네 방향 × 3. 구도는 side·none·step이 섞였다.
  - 대화마다 E를 28~31번 연타했다.
- `… --view=first`: **TALKCYCLE PASS 12**. 대화 구도·yaw 회전 없음, 1인칭 유지.
- 묶음에 넣은 `talk:cycle`(8회)·`talk:cycle-fp`(4회): 둘 다 PASS.
- 주모로 순환 시험(`--talkshot=jumo --talkcycle`)을 돌리면 새 게임 여는 장면(컷·runner.busy) 동안 대상이 잡히지 않아 실패한다.
  - 시험 자리 문제이고, 대화 동작 문제가 아니다.
  - 주모의 복귀는 4-1 back 화면으로 봤다.

### 4-4. 고을 사람·다른 이야기 인물(D5, T02) — 테스트 완료(로그 판정)

- `talk:namwon`·`talk:hanyang`·`talk:jeju` 세 고을에서 각 24회 말 걸기, 모두 PASS.
- 플레이어는 시험이 상대에게서 0.9m, 8방향 가운데 하나에 세운다.
- 고친 뒤 TALKFRAME 73회:

| | 남원 | 한양 | 제주 |
|---|---|---|---|
| 겹침 0(none·step·side·fade) | 24 | 21 | 24 |
| 틈 잣대 겹침 남음 | 1(raw 0.19) | 3(raw 0.19·0.19·0.20) | 0 |
| 고치기 전(같은 시험) | 4회 겹침(0.34~0.89) | 0 | 4회(0.60~0.71) |

- 남은 4회는 모두 **장터 판대 뒤 장꾼(mode=stall)** 이다.
  - 시험이 플레이어를 판대 옆 0.9m에 세운 경우: `rej` blocked 53 · through 33 · far 16.
  - 틈 없는 겹침은 19~20%로, 대화 v1.1 §4 '겹침 20% 이하'의 경계다.
  - 실제 놀이(판대 앞에서 다가감)에서 나는지는 **미검증** → §5.
- 구도 계산 시간(헤드리스, 73회): 고치기 전 중앙값 51ms·최대 125ms → 고친 뒤 **중앙값 14ms · p90 28ms · 최대 35ms**.
- 이야기 인물(남원 묶음 시험 A·B·C·A2·onboard 로그):

| 인물 | 결과 |
|---|---|
| 포수 10 · 주모 6 · 방앗간 5 · 이웃 아낙 4 · 기름집 아낙 1 | 모두 `side`, raw 0, 가림 0 |
| 누이 5 | `fade+side`(집 안이라 지붕 점무늬). 겹침 0 |

- 다른 권역 이야기 인물(전체 묶음 로그 TALKFRAME, 고을 사람 제외 192회):
  - 모든 권역에서 **틈 없는 겹침 raw 0, `overlap` 단계 0회**.
  - 권역별 구도 단계:

    | 권역 | 단계(횟수) |
    |---|---|
    | 남원 | side 46 · fade+side 9 · step 5 |
    | 강릉 | side 14 |
    | 경주 | side 6 · fade 2 |
    | 한양 | fade+side 4 · fade 2 · step 2 |
    | 황주 | step 9 · none 3 · fade 2 |
    | 평양 | step 18 · fade 9 |
    | 함흥 | step 11 · fade+side 7 |
    | 제주 | step 25 · none 1 |

  - fade는 겹침은 없고 배경(지붕·나무)만 두 사람 둘레 점무늬로 비운 경우다. 점무늬 화면은 이번에 찍지 않았다.

### 4-5. 남원 회귀(조정자 보고)와 묶음 시험 전체

- 회귀 고친 뒤(09f887a 앞 작업본):
  - `namwon:A` PASS(A_hold, 58s) · `namwon:A2` PASS · `namwon:B` PASS(B_hold) · `namwon:C` PASS · `namwon:onboard` PASS(35s)
  - `continue:*` 6개 모두 PASS(early·new·climax·rope·morning·v1done)
- 헤드리스 단위 시험·검사기:

| 시험·검사기 | 결과 |
|---|---|
| CAMVIEWTEST | PASS 27 |
| ONBOARDRULE | PASS 64 — 처음엔 가짜 감독에 `talking`이 없어 FAIL. 새 동작이 의도라 시험을 고쳤다 |
| REGTEST | PASS 47 |
| COMMONTEST | PASS 49 |
| ACTIVITYTEST | PASS 71 |
| SAVEGUARDTEST | PASS 19 |
| CASEMETA | PASS 9 warn=5 |
| EVENTCLASS | PASS 170 |
| PROBLEMS | PASS 9 |
| MAPLEADS | PASS 69 |

- `tools/run_story_tests.sh` 전체(77개 = 75 + talk:cycle 둘): 결과는 아래 FULL 표.

전체 묶음 1회(동시 3개, 79개 — 1단계 때 75개 + 그 뒤 들어온 namwon:A2·talk:cycle·talk:cycle-fp 등): **77 PASS · 2 FAIL**.

| 실패 | 까닭 | 처리 | 다시 돌림 |
|---|---|---|---|
| `station:namwon` | `그만뒀는데 시각·자리가 바뀜`. 마부에게 말 걸 때 겹치면 한 걸음 비켜 서는 **새 동작**(bef3bde) 때문에 자리가 0.52m 바뀌었다. 시험은 '지도 취소 뒤 역마로 옮겨지지 않았나'를 보려던 것이다 | 시험을 고쳤다(`station_test.gd`). 의도된 새 동작이다. '자리 그대로'는 지도가 열린 뒤 자리로 보고, 말 걸기 걸음은 2.7m 이하인지 따로 본다 | **PASS** |
| `hwangju:B` | 4초 만에 엔진 충돌(signal 11). `farm.gd:572 _build_tile`이 작업 스레드에서 `propagate_notification`을 불렀다. 대화 코드와 무관한 스레드 문제로 보인다 | 손대지 않았다 | **PASS**(38초). 간헐 충돌로 남긴다(§5) |

- `view:namwon` PASS checks=66(1인칭 돌아보기 시선 오차 포함).
- `talk:*` 5개 PASS, `continue:*` 6개 PASS, `namwon:*` 6개 PASS.
- 다른 권역 이야기 인물: 한양·강릉·경주·황주·평양·함흥·제주·남원 춘향의 묶음 시험이 모두 PASS다(사건 대사 흐름은 그대로).

---

## 5. 남은 문제·미결정

1. **콘티 타이밍이 달라졌다** — 사용자 확인 필요.
   - 대화 v1.1 §6은 '0.15~0.70초 구도 → 0.70초에 상자'다.
   - 지금은 대본을 곧바로 시작한다. 첫 상자가 구도 미끄러짐(0.55초)과 함께 0.18초 흐려지며 들어온다.
   - 이유: 대본을 늦게 세우면 사건 흐름(시험의 장면 기다림, 노크 사이 조작)이 어긋났다.
   - 콘티대로 늦추려면 '첫 say만 구도가 설 때까지 기다리기'를 따로 넣어야 한다. 이야기 흐름에는 영향이 없다.
2. **장터 판대 장꾼**: 플레이어가 판대 옆에 바짝 붙으면 틈 없는 겹침 19~20%가 남는다(D5 '절대'의 경계).
   - 남은 수단은 둘이다. 상대가 한 걸음 비키기, 또는 플레이어 그림 반투명(배경 가림 처리의 확장).
   - 둘 다 연출·체계 변경이라 결정을 받아야 한다.
3. **고을 사람 카메라 옆 돌기**: C27('고을 사람은 카메라를 움직이지 않는다')에 예외를 하나 뒀다.
   - 예외는 걸음으로 겹침을 못 풀 때만이다. 이번 시험 73회 중 1회(남원 side)였다.
   - D5 '절대'를 따르기 위한 것이다. 원치 않으면 끄기 쉽다(`plan(…, turn_ok=false)`).
4. 배경 가림이 몸 전체(occ_npc=3)인 대화가 고을 사람에게 많다(남원 8·한양 6·제주 7).
   - 예: 지붕 아래·처마 밑 사람.
   - 두 사람 둘레 점무늬로 비우지만, 고을 사람은 거리를 바꾸지 않는다.
   - 점무늬가 충분히 보이게 하는지 화면으로는 보지 않았다(미검증).
5. 미검증:
   - 1600×900·1280×800·1024×768
   - 실제 손 플레이 녹화와 미끄러짐 중 프레임 시간(T07)
   - 대화 직전·직후 저장/불러오기(T05)
   - 대화 중 M/R·Esc 선택지(§9)
   - 역참 깃발 대화(사람이 아니라 기물이라 구도 처리를 넣지 않음)
6. talkshot 순간이동 직후 고을 이름 「남원」 띠(1단계부터). 실제 놀이에서 나는지는 미검증.
7. `hwangju:B` 간헐 엔진 충돌. `farm.gd:572`가 작업 스레드에서 노드 알림을 부른다. 대화와 무관하고, 다시 돌리면 PASS다.

## 6. 다음 단계

- 위 5-1(콘티 타이밍)과 5-2(판대 장꾼 마지막 수단)를 정해 주면 2단계를 닫는다.
- 그다음 3단계(첫 15분 — 이겸의 편지, D1·D7)로 간다.
- 2단계 남은 시험을 3단계 앞에 붙여도 된다: T04 나머지 해상도, T05 저장, §9 M/R·Esc.
