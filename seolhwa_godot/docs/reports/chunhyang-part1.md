# 춘향 PART I — 「남원의 약속」 단오~이별 (2026-10-11)

근거: `seolhwa/docs/scenario/seolhwarok_NAMWON_CHUNHYANG_v1.1_scenario.md`(ACT 0~5, §3~§17) · `_DECISIONS.md`(§1·§4·§7) ·
`seolhwa/docs/production/CHUNHYANG_ASSETS_PLACEMENT_v1.0.md` · `CITY_ROUTE_PRODUCTION_RULES_v1.0.md` · `chunhyang-prep.md` · `multi-case-registry.md` · `commonize-1.md` · `namwon-v32.md`.
대사 수정 요청서(`seolhwarok_DIALOGUE_REVISION_REQUEST_v1.0.md`)는 저장소에 없어 시나리오 대사를 그대로 쓰고, 덧붙인 말은 "눈앞의 것을 두고 짧게"로 맞췄다.

## 0. PART I 앞 고침(사용자 확정)

| 무엇 | 한 일 |
|---|---|
| 군중 인원 | `dano_market` 28 · `byeon_banquet` 14를 확정 첫 값으로 표기(배치 파일 `density_note`·`status`) |
| (a) 공식 8A 양옆 | 사령 줄을 축 ±6.6m(x -3168.7 / -3155.5, z 212.6~216.5)로 당겨 확정 8A(58/21/32) 틀 양쪽 끝에 대칭으로 보이게. 기생 줄은 단 앞 z 211.6(1.8m 간격), 이방 (-3166.6, 210.2), 플레이어 사령 자리 (-3168.7, 217.8) + 마주 선 선임 사령 `ch_saryeong_e4`. 축(변학도 → 기생·관속 → 사령│사령 → 춘향 → 가운데 통로) 비움. 4:3 투영 시험: 서 -0.83~-0.96 / 동 +0.83~+0.96(대칭, 맨 아래 둘만 살짝 잘림) |
| (b) F-11 규칙 잠금 | "when이 거짓인 조건부 배치는 기본 세계에 흔적이 없다". `clear_veg`를 조건부로: when 항목은 `_veg_excl` 대신 `region_world.add_veg_cond` — 식생은 그대로 흩뿌리고, 참인 동안만 그 자리 인스턴스를 크기 0으로 숨기고 충돌체를 끈다(`set_veg_cond`), 거짓이면 원래 변환으로 되살린다(지우거나 다시 짓지 않음). 걸친 묶음만 원래 자료(`src`)를 지녀 헤드리스에서도 같다. 가림 처리(`_cut`)가 숨긴 것을 되살리지 않게 막음. 제작 규칙 문서 C31·F-11 줄에 잠금 문장 |
| 식생 확인 | 광한루 앞 잔디: 사건 전 26 · 단오 26 중 26 숨김 · 끝난 뒤(farewell) 숨김 1(그 단계에도 서는 버드나무·평상 자리) · 실제 상태 0. 관아 바깥마당(추수 물자 자리): 원래 흩뿌린 식생이 없다(0 → 0, 사건 전·뒤 같음) |

## 1. 사건 등록·변수·출처

- 사건 `namwon_chunhyang`(`story/namwon_chunhyang/` 데이터·사건·시험), `case_registry.SPACE_CASES["JL_NAMWON_UNBONG"] = ["namwon", "namwon_chunhyang"]`.
- `requires`: `CASE_NAMWON_COMPLETE` && `CASE_HANYANG_BOOKSHOP_COMPLETE`. `choose()`가 오누이(끝남) 다음으로 춘향을 고른다 — 둘 중 하나라도 없으면 춘향 아님(시험).
- 전역 변수는 넷뿐: `CASE_NAMWON_CHUNHYANG_OUTCOME · _COMPLETE · _PART1_COMPLETE · _LEFT_AFTER_PART1` — `story_state.VAR_DEFAULTS`에 기본값(""/false)을 더했다(빈 문자열 bool 변환 사고 방지). 사건 안 플래그는 접두사 없음.
- `EVENT_CLASS FOLKLORE_EVENT` · **`SOURCE_ID F50` (새 번호)** · `CATALOG_ID HN01` · 지역 앵커 A01 메모. 검사 규칙상 FOLKLORE_EVENT 출처는 Fxx여야 하므로(A01은 앵커) F49(남원 오누이)와 같은 방식으로 원전 등록 F50을 더했다 → `seolhwarok_master_scenario_storyboard_v2.4_integrated_improvement.md` 레지스트리(F01~F50=50), 8개 주 사건 표에 한 줄, `## F50` 절.
- 사건 머리: record_title 「남원의 약속」 · rule_label · reset_vars(넷) · travel_gate 없음(첫 사건 아님) · `start_event C0001` + `start_on_arrival`(컷신 없이 단계만 선다 — 역마·노정 도착 시험이 막히지 않는다).

## 2. 흐름(단계 dano → courtship → farewell)

| 장면 | 무엇 |
|---|---|
| C0001 §3 | 조용히 선다: 단계 dano, 「새 사건」 도장. 단오 차림(F-11 when)·군중 28(EventCrowd)·`bgm_dano_bright`(낮)·장터 웅성임 `crowd_dano`·먼 북 `drum_far` |
| C0101 §4 CAMERA 1A | 광한루 반경 46m. 각본 시점(촬영 보고 다시 잡음: pos (-3246, +7, 420) → look (-3318, +6, 446), fov 30). 컷 동안만 안개 fogm 0.35(끝나면 원래 날씨·안개). 플레이어는 제자리(군중 LOD가 카메라 자리도 봄 — §9). 그네가 한 번 높이 오른다 |
| C0102 §5~§7 | 방자가 뛰어와 부딪힘 → 부채(키트 `fan`)가 떨어짐 → (주워 준다 / 그냥 지나간다). 주워 주면 "북쪽 범 일 때 있던 길손 아니오?" — 맞소 / 사람 잘못 봤소 / 대답 없음(방자는 크게 신경 쓰지 않음) → CAMERA 1B(몽룡 뒤 화면 오른쪽, 44m 밖 그네) → 심부름(같이 가 주지 / 혼자 가시오 / 더 본다) |
| C0202 §8 CAMERA 2A | 같이 가면 바로, 아니면 그네 곁(지도 표 "그네 — 방자가 간 곳")에서. 춘향 "보고 싶으면 본인이 말을 하라 그래." 춘향·향단은 자기 길로 |
| C0204 §9·§10 | 몽룡 "재미있구나." → 암전, 18:18, 단계 courtship → 방자 "이것 좀 같이 들고 갑시다"(장면 물건 `작은 술병과 찬합`, 지도에 월매 집) |
| C0302 §11·§12 | 월매 집(nw_house_158) 대문 밖: 월매 · 몽룡이 뒤늦게 · 춘향 "사또 자제들은 원래…" 몽룡 "잘못했소." → 자막 없이 다음 날 낮 |
| §13 며칠의 압축 | A 방자의 편지(봉한 편지 — "열어 볼 일은 아니다") → 춘향 "고맙습니다." · C 월매 집 앞 웃음(`laugh_far`, 필수 아님) · B 오작교 곁을 함께 걷는 두 사람(대사 없음) |
| C0402 → C0406 §14 | 방자 "오늘 밤 월매 집에" → (해 질 때까지 기다린다). 밤 마당(등롱 차림) 백년가약 → 월매 "들었지요?" — 들었습니다 / 두 분 말은 두 분이 지킬 일입니다 / 말없이 고개를 끄덕인다 → `vow_witness` + `vow_heard`·`vow_own`·`vow_nod` 중 하나(결과는 같고 PART I 뒤 월매 말만 다르다) |
| C0501 §15~§17 | 아침 방자 "한양으로 올라가신답니다" · 몽룡 "나도 가야 해." → 단계 farewell → 오리정 곁 북쪽 길 CAMERA 5A(겨냥 남쪽 3m·거리 24). 큰 음악 없음(바람 소리만). 몽룡은 두 번 뒤를 보고 사라짐, 방자 "길손, 잘 계시오." → `PART1_COMPLETE` |
| C0503 | 남은 춘향에게 말 걸기: 기다리실 겁니까?(약속했으니까요) / 한양은 멉니다(먼 길인 건 압니다) / 아무 말 없음(…가세요) → 춘향은 집으로(말을 걸지 않고 60m 떠나도) |
| 떠남 | `region_main._travel`(걷기 포털·역마·지도 이동 공통) → `story_director.on_leave_space(갈 곳)` → 사건 `on_leave` — PART I 뒤 남원 밖이면 `LEFT_AFTER_PART1` |

- FIXED_BEATS 6(단오 그네 · 몽룡이 봄 · 방자의 전갈 · 첫 만남 · 백년가약 · 이별) — 장면이 `beat_<id>`를 남긴다.
- 플레이어는 거들 뿐: 부르기·거절·약속·이별의 말은 모두 춘향·몽룡·월매가 한다. 점수·호감도 없음.
- 그네: 키트 `story/chunhyang` kind `swing`의 부분 `seat`을 가로대 축으로 흔든다(주기 5.5초, 1A·1B 때 한 번 높이). 춘향은 단오 낮 동안 발판 위에 서서 함께 움직인다. 1A에서 그네는 누각 뒤에 숨지 않는다(카메라를 동남쪽으로 옮겨 해결 — **그네는 옮기지 않았다**). 거리 약 87m — 1A 컷 동안만 안개를 옅게 해 그네 위 춘향이 노랑 저고리·다홍 치마의 사람으로 보인다(§9).
- 오리정: 이름표만(그대로). 지도 표·E·역마 없음.
- 기록책: 단서 13 — 본 것(단오장·그네·몽룡의 웃음·잘못했소·편지·오작교·백년가약·이별)과 들은 것(성춘향 — 방자 · 춘향의 대답 — 춘향 · 월매의 말 — 월매 · 한양행 — 방자)을 가른다. `summary()`가 흐름을 문단으로(월매에게 한 대답·이별의 말까지).
- 지도: map_places 광한루·월매 집, 붉은 표 9(귀환 `ch_dano_return`은 전국 지도 남원 자리 — 사건이 서면 사라짐).
- 귀환 이유: 한양 책방 뒤 칠패장·강릉장·경주장·황주장 소문 `CH_DANO_*` "남원 단오장이 크게 선다더라"(강제 없음).

## 3. 오누이 뒤 남원 사람(F-10 전 임시)

같은 CHR·그림으로 춘향 데이터에 다시 세웠다(오누이 흐름은 옮기지 않음): 주모(CHR_HUM_015 innkeeper) "북쪽 길은 다시 사람들이 다니오." · 방앗간 주인 · 포수 · 이웃 아낙(`CASE_NAMWON_MORNING` 세 갈래 대답 그대로 — sky/unknown/silent).

## 4. 인물 그림(굽기)

기존 웹 굽기(`tools/export_story_frames.js` `?set=namwon_chunhyang`, frameCore.BakeBank high — 먹선·한지 테·평면 채색, 앞·옆·뒤) → `data/frames_story_namwon_chunhyang.json`(git 밖, `story_director.BANK_FILES`·`KIND_FALLBACK`에 연결).

| kind | 바탕 | 차림 | 동작 |
|---|---|---|---|
| chunhyang | villager_f | 노랑 저고리·다홍 치마·붉은 댕기(땋은 머리), 1.55m | idle·walk·talk·sit |
| hyangdan | villager_f | 무명 저고리·쪽빛 치마·풀빛 댕기, 1.48m | idle·walk·talk |
| wolmae | villager_f | 쪽머리·옥색 비단 저고리·남치마 | idle·walk·talk |
| mongryong | villager_m | 옥색 도포·갓·수염 없음, 1.68m | idle·walk·run·talk |
| bangja | villager_m | 짧은 저고리·잠방이·벙거지·붉은 볼 | idle·walk·run·talk |

다섯 모두 새로 구웠다(향단 대체 없음). 그네 위 자세(swing_stand)·sit/bow/kneel 공용 자세는 PART II 준비 때(결정대로 미룸).

## 5. 키트·소리

- `kit/story/chunhyang.gd`: `swing`(기둥·버팀·가로대·색천 + 흔드는 `seat`) · `ssireum_ring`(모래 원판 + 새끼 테) · `fan`(떨어진 접부채). 배치의 placeholder(솟대·빈터)는 이제 쓰이지 않는다.
- 임시 소리(`make_placeholders.py`, 예전 파일 그대로): `bgm_dano_bright` · `crowd_dano`(Ambient) · `drum_far` · `laugh_far`. README·`sound.gd` TUNE·`sound_test` 목록에 더함.

## 6. 시험(마지막에 차례로 한 번씩)

| 시험 | 결과 |
|---|---|
| `tools/story/validate_event_class.gd` | EVENTCLASS PASS checked=145 (exit 0) |
| `tools/story/validate_case_meta.gd` | CASEMETA PASS 9 warn=5 (exit 0) — 춘향 경고 없음 |
| `tests/registry/case_registry_test.gd` | REGTEST PASS 47 (exit 0) — 남원 두 사건으로 기대값 갱신 |
| `tools/story/map_leads_test.gd` | MAPLEADS PASS fixtures=61 (exit 0) — 춘향 fixture 8 |
| `tests/audio/sound_test.gd` | SOUNDTEST PASS 42 (exit 0) |
| `tests/onboarding/onboarding_rule_test.gd` | ONBOARDRULE PASS 64 (exit 0) |
| `tests/commonize/commonize_test.gd` | COMMONTEST PASS 49 (exit 0) |
| `tools/run_story_tests.sh` 전체(마지막 한 번) | **56/56 PASS**, SCRIPT ERROR 0, exit 0 — 새 `namwon_chunhyang:a·b·after` 포함(53 → 56). 첫 전체 실행에서 소문 고르기의 `String(true)` 오류(경주·역마·나루 시험 SCRIPT ERROR)를 찾아 `str()`로 고친 뒤 다시 돌린 결과 |

새 대본 시험(`story/namwon_chunhyang/namwon_chunhyang_test.gd`):
- `namwon_chunhyang:a`(82): 진입 판정(없음·오누이만·한양만 → 아님, 둘 다 → 춘향 · requires 둘 · 전역 변수 넷뿐) · 귀환 소문 넷(한양 뒤에만·PART I 뒤 그침) · 단오 군중 28 보임·잔치 군중 없음·단오 차림 · 남원 사람 넷(같은 CHR·주모 말·이웃 아낙 아침의 대답) · 1A~5A 끝까지(주워 줌·맞소·같이 감·웃음·기다림·들었습니다) · vow_witness+vow_heard만 · PART1_COMPLETE(사건 완료·결말은 아직) · FIXED_BEATS 6 · 이별 뒤 군중·단오 차림 내려감·큰 음악 없음 · 춘향 "기다리실 겁니까?" · PART II 없음(단계·차림 6·잔치 군중·장면) · 기록책 · 떠나면 LEFT_AFTER_PART1 · PART II 닫힘.
- `namwon_chunhyang:b`(61): 지나감(알아봄 없음) · 혼자 가시오 → 나중에 그네 곁에서 2A · 고개 끄덕임(vow_nod만) · 아무 말 없음.
- `namwon_chunhyang:after`(16): PART1 + LEFT + 강릉 완료(part2_open 참)로 다시 남원 — PART II 장면·차림·군중 없음, 단계 farewell, 춘향은 집·몽룡·방자 없음, 월매·주모 말.
- `chunhyang:prep`(65): 식생 조건부 숨김/되살림(광한루 잔디·관아 바깥마당) · 8A 양옆 대칭·축 비움·기생 줄 틀 안·춘향 가운데 추가.

## 7. 화면 (`seolhwa_godot/shots/chunhyang_part1/`, git 밖 — 창 모드 1024×768, 시험 저장 `user://chp_p1_story.json`·`chp_p1shot.json`)

| 파일 | 내용 |
|---|---|
| `01_festive_namwon.png` | 단오 장터(좌판·사람) |
| `02_1A_crowd_swing.png` | 1A — 왼쪽 누각, 가운데 단오 군중·씨름판, 뒤 버드나무 사이 그네 |
| `03_1B.png` | 1B — 오른쪽 몽룡(뒤), 44m 밖 그네 위 춘향 |
| `04_bangja_bump.png` | 방자와 부딪힘 |
| `05_refusal_2A.png` | 2A 거절 — 춘향·향단 / 방자·나그네 |
| `06_wolmae_house_evening.png` | 저녁 월매 집 대문 밖 — 월매·몽룡·춘향·방자 |
| `06b_walk_ojakgyo.png` | 오작교 곁 두 사람 |
| `07_vow_night.png` | 밤 마당 백년가약(등롱·창 불빛) |
| `08_farewell_5A.png` | 오리정 곁 북쪽 길 — 멀어지는 몽룡, 서 있는 춘향, 뒤 방자·나그네 |
| `09_journal_part1.png` | 기록책 사건 기록 「남원의 약속」 |
| `09_8A_sides_fixed.png` | 확정 8A 양옆 고침(대신 선 그림) |
| `10_lawn_veg_before.png` · `11_lawn_veg_dano.png` · `12_lawn_veg_after.png` | 광한루 앞 잔디 식생 — 사건 전 / 단오(숨김) / 끝난 뒤(되살림) |

보고 고친 것: 1A(그네가 누각 뒤에 숨고 군중이 화면 밖 → 카메라 동남쪽·fov 30, 컷 동안 플레이어를 마당 가운데로), 1B(몽룡을 화면 한쪽으로), 2A(방자·나그네를 가까이, 단오 군중 비움 구역 `talk_swing_2A`), 월매 집(인물이 담 안에 가려짐 → 대문 밖으로, 고정 구도), 5A(뒤의 방자·나그네가 잘림 → 겨냥 남쪽 3m), 그네 줄(가늘어 안 보임 → 굵고 짙게, 버팀을 짧게).

다시 찍기:
- `godot --path seolhwa_godot res://scenes/region.tscn --resolution 1024x768 -- --region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:a --notitle --storyshots=shots/chunhyang_part1 --savefile=user://chp_p1_story.json`
- `… --region=JL_NAMWON_UNBONG --prepshot=sides8a,veg --nostory --notitle --shotdir=shots/chunhyang_part1 --savefile=user://chp_p1shot.json`

## 8. 남은 것 · 판단

1. ~~1A의 춘향은 작다~~ → §9에서 닫음(컷 동안만 안개 옅게, 카메라는 그대로).
2. **단오 차림 placeholder 정리**: 그네·씨름판은 실제 키트가 됐다. PART II 쪽 보계·교의·형틀·차일·수레(upright)는 여전히 placeholder(PART II 준비 때).
3. 미룬 것(결정대로): 공용 sit/bow/kneel(−0.42m 서 있기 꼼수 제거), 잔치 군중 역할 나누기, 수레 upright, 몽룡 거지 차림·변학도·기생 generic 굽기.
4. 오누이 뒤 남원 사람은 춘향 데이터에 다시 세운 **임시 조치** — F-10(비활성 사건 인물 층)이 생기면 옮긴다.
5. ~~`ITM_CH_JAR`·`ITM_CH_LETTER` 마스터에 올릴지~~ → 결정: 올리지 않는다(§9).
6. ~~1A 컷 동안 플레이어를 단오 마당으로 옮김~~ → §9에서 없앰(EventCrowd LOD가 카메라도 본다).

## 9. PART I 마무리 (2026-10-11)

PART I을 닫는 두 가지만 고쳤다. PART II 준비는 다음 단계.

### 9-1. 1A 안개 — 컷 동안만

- 카메라는 그대로(`CAM_1A` pos (-3246, +7, 420) → look (-3318, +6, 446), fov 30 — 가깝게 옮기지 않음).
- 1A 컷 동안만 `fogm 0.35`(`FOG_1A`): 남원 아침과 같은 `weather.force(지금 날씨 종류, -1, 0, { fogm })`. 지금 날씨 종류는 그대로 두고 안개 배율만 덮는다.
- 공통 도움 `story_director.cut_fog(fogm)` / `cut_fog_end()`: 시작할 때 `weather.snapshot()`(종류·강제 여부·남은 시간·지금 값)을 담고, 끝나면 `weather.restore()`로 전환 없이 그대로 되돌린다.
  되돌리는 때: `cutscene(false)`(어떻게 끝나든 — 건너뛰기 포함) · 공간을 떠날 때(`on_leave_space`) · 컷 밖 저장(`save`) · 장면을 내릴 때(`_exit_tree` — 끝내기·칸 불러오기). 날씨는 저장 파일에 들어가지 않으므로 컷 도중 저장해도 불러오면 원래 안개다.
- 화면 확인: 그네가 동쪽(카메라 쪽) 버드나무 `ti_swing_tree_e` 바로 뒤에 있어 **그네의 북쪽 반 호는 이 시점에서 늘 그 나무에 가린다**(카메라를 남쪽으로 8m·14m 옮겨 봤지만 나무와 그네 북쪽 끝이 거의 한 줄이라 그대로 — 되돌림). 남쪽 반 호에 오면 옅은 안개 속에서 노랑 저고리·다홍 치마·댕기가 보이는 사람이다. **카메라는 옮기지 않았다.**

### 9-2. EventCrowd LOD — 카메라도 본다(공통, C60)

- LOD 거리 = min(플레이어까지, 지금 카메라의 땅 위 자리까지). 카메라의 땅 위 자리는 카메라 자리(x,z)와 겨냥점(x,z — 각본 시점이면 `shot.look`, 아니면 `rig.target`) 둘(`event_crowd.lod_dist` · `cam_ground`).
  1A는 망원 시점(fov 30)이라 틀 뒤쪽(그네 곁 B구역 서쪽)이 카메라 자리에서 70~85m다 — 카메라 자리만 보면 숨으므로 겨냥점도 본다.
- 평소에는 겨냥점이 플레이어(+앞보기 1.2m)라 예전과 같다(`chunhyang:prep`의 "60m 밖 숨김"·"멀리 가면 모두 숨김" 그대로 통과).
- 1A에서 플레이어를 단오 마당으로 옮기던 임시 조치(`ch_1a_hold` 앵커 · 숨김 · 되돌림)를 없앴다.
- 시험(`namwon_chunhyang:a`·`b`, 82 → 88): 1A 컷 앞·가운데·끝난 프레임의 플레이어 자리가 똑같다(Vector3 ==) · 플레이어를 숨기지 않는다 · 1A 틀(카메라 절두체) 안 단오 군중 13~14명 모두 살아 있음(active/reduced, 그중 12~13명은 플레이어 거리만으로는 숨었을 사람) · 컷 동안 fogm 0.35 · 끝난 프레임에 원래 날씨(snapshot 전체)와 같음.
- 제작 규칙 C60에 LOD 규칙 문장.

### 9-3. 아이템 결정(기록만)

술병·찬합(`ITM_CH_JAR`)과 봉한 편지(`ITM_CH_LETTER`)는 춘향 데이터 안의 사건 한정 장면 물건으로 둔다 — **ITEM_MASTER에 올리지 않는다**(결정 문서 §8에도 적음).

### 9-4. 화면 (`seolhwa_godot/shots/chunhyang_part1_close/`, git 밖 — 창 모드 1024×768)

| 파일 | 내용 |
|---|---|
| `1A_before.png` | 고치기 전 1A(안개 그대로, 플레이어를 마당으로 옮긴 상태 — `shots/chunhyang_part1/02_1A_crowd_swing.png`와 같은 것) |
| `1A_after.png` | 고친 뒤 1A, 컷이 찍는 그 순간 — 안개 옅음, 군중 그대로 차 있음. 이때 춘향은 그네 북쪽 끝이라 앞 버드나무에 가림 |
| `1A_after_swing_south.png` · `1A_after_swing_south_b.png` | 같은 컷 1~2초 뒤 — 그네 남쪽 반 호의 춘향(사람으로 보임) |

### 9-5. 플레이 시험 저장

`user://play_chunhyang.json`(새 파일 — 다른 저장은 건드리지 않음): `story/hwangju/test_post_hanyang.json`(남원 C 끝 · 한양 S1006 끝) + `CASE_NAMWON_MORNING`(unknown) + 처음 안내 본 것, 자리 = 남원읍성 남문 앞(-3227.8, 366.7) 10시.
헤드리스 확인(사본으로): 시작 메뉴 → 이어 하기 → `case=namwon_chunhyang` · C0001 「새 사건」 · 단계 dano.
실행: `godot --path seolhwa_godot -- --savefile=user://play_chunhyang.json` → 이어하기.

### 9-6. 시험(차례로 한 번씩)

| 시험 | 결과 |
|---|---|
| `validate_event_class` | EVENTCLASS PASS checked=145 (exit 0) |
| `validate_case_meta` | CASEMETA PASS 9 warn=5 (exit 0) |
| `case_registry_test` | REGTEST PASS 47 (exit 0) |
| `map_leads_test` | MAPLEADS PASS fixtures=61 (exit 0) |
| `sound_test` | SOUNDTEST PASS 42 (exit 0) |
| `onboarding_rule_test` | ONBOARDRULE PASS 64 (exit 0) |
| `commonize_test` | COMMONTEST PASS 49 (exit 0) |
| `chunhyang:prep` | PREPTEST PASS 65 |
| `tools/run_story_tests.sh` 전체 | **56/56 PASS, exit 0** — `namwon_chunhyang:a` 88 · `b` 79 · `after` 16. 첫 전체 실행에서 `travel:boat-priority`(한양 나루 E 말 걸기, 이번 변경과 무관한 공간) 하나가 한 번 FAIL → 혼자 다시 PASS → 전체를 다시 돌려 56/56 |
