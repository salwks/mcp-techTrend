# 게임플레이 구조 1차 — 보고서

> 지시: `seolhwa/docs/production/BRIEF_gameplay_architecture_first_pass.md`(사용자 원문 요지)
> 상위 문서: `seolhwa/docs/production/SEOLHWAROK_GAMEPLAY_ARCHITECTURE_FINAL_v1.0.md`
> 나눠 맡음: 에이전트 1 = §26의 1~3(방향 문서 · Activity/Problem 계약 · 오누이 보강) — 이 보고서 §1~§4. 에이전트 2·3 = 춘향 II-B · demo · 최종 화면·보고(§5 이후를 이어 쓴다).
> 시작 HEAD: `6ede0a9`(브랜치 `claude/youthful-gauss-d0fxzv`).

## 1. 바꾼 파일(에이전트 1)

| 파일 | 무엇 |
|---|---|
| `seolhwa/docs/production/SEOLHWAROK_GAMEPLAY_ARCHITECTURE_FINAL_v1.0.md` | 새 상위 문서 — 네 문장 · OBSERVE→CONNECT→DECIDE→ACT→RESULT · 성장 3단계 · 모듈 넷 · PROGRESSION 넷(미래만) · 만들지 않는 것 · 기록의 성격 · §11 해석 · Activity/Problem 계약 |
| `seolhwa/docs/scenario/seolhwarok_NAMWON_CHUNHYANG_v1.1_scenario.md` | "증거 조합 퍼즐 — 없음" 아래 뜻 한 단락(없는 것/있는 것) |
| `seolhwa/docs/scenario/seolhwarok_NAMWON_CHUNHYANG_v1.1_DECISIONS.md` | §10 같은 해석 결정 |
| `scripts/story/problems.gd` | **새 공통 모듈** — 문제 데이터 → 조사 대상·트리거·기록·활동 단계(expand) · 검사(validate) · 상태 읽기 |
| `scripts/story/story_runner.gd` | 명령 `{ "activity": "문제.활동" }` 하나 · 조건 함수 `pa·pd·pn·pdone` |
| `scripts/story/case_registry.gd` | `load_data`가 `Problems.expand`를 한 번(모든 소비처가 같은 데이터) |
| `tools/story/validate_problems.gd` | 새 검사기 — `PROBLEMS PASS` |
| `tests/activity/activity_test.gd` | 새 공통 시험 — `ACTIVITYTEST PASS 52` |
| `story/namwon/namwon_data.gd` | 오누이 문제 `beast_way`(관찰 넷 · 판단 하나 · 숲가 자리) · 앵커 6 · 추정 기록 `trace_downhill` |
| `story/namwon/namwon_case.gd` | `night_ready` 안전장치(단서 12개)가 문제 기록(pb_*·추정)을 세지 않게(`_core_clues`) — 관찰이 밤을 앞당기지 않는다 |
| `scripts/story/oneonui_observe_test.gd` | 새 대본 시험 `namwon:observe` · namwon:A/B에서 부르는 `beast_way` |
| `scripts/story/story_test.gd` | `go()`가 대상의 `at`을 읽는다(pb_* 대상) · OBSERVE 갈래 · A/B 첫 조우 뒤 관찰 |
| `tools/run_story_tests.sh` | `namwon:observe` 더함(64 → 65) |

## 2. 기존 시스템 조사 — 다시 쓴 것(코드 전에 정함)

새 실행기·새 화면·새 저장 칸은 만들지 않았다. 문제 데이터는 **이미 있는 이야기 명령으로 바뀌어** 돈다.

| 기존 | 어떻게 다시 썼나 |
|---|---|
| `story_runner` 명령(flag·clue·examine·choice·if·caption·give/take·discover) | 활동 하나 = 이 명령들의 묶음(`data.activity_steps`) |
| `story_director` 조사 대상 `objects`(E 살펴보기·먹점 mark_r·when) | 본 것(seen) 활동 → 대상 `pb_<문제>_<활동>` |
| 자리 트리거 `triggers`(at·radius·once·when) | 결정 '불러온 뒤 다시 묻기' 하나(`once: false`, 결정 전·자리 안에서만) |
| 기록 `clues`(kind fact/heard/guess · by) · 기록책 `journal_book` | 활동 `record` → 기록. 기록책은 손대지 않음(◆확인 · ◇들음—말한 사람 · △추정 그대로) |
| 사건 깃발 `S.flags`(progress `cases.<id>.flags`) | 활동·결정·결과 상태 전부 — 사건 namespace만 |
| 인물 대화 `actors[].talk` | 들은 것(heard) = talk 안 `{ "activity": … }` 한 줄 |
| `onboarding.step` discover · `give/take` | 결과 단계에서 그대로(오누이: 물레방앗간이 지도에) |
| `case_registry.load_data` | expand를 여기서 한 번 |

`if case == …` 없음. `problems.gd`에는 사건 id·사건 변수 글자가 없다(검사기·시험이 확인).

## 3. Activity/Problem 데이터 계약(짧게)

자세한 것은 상위 문서 §9. 핵심:

- 활동 type 넷: `inspect`(kind `seen` — `at` 앵커·E 대상 / `heard` — `actor`·`by`, talk에 `{activity}`) · `compare`·`connect`(`needs` 둘 이상이 끝나면 같은 흐름에서 저절로) · `decide`(`needs` 또는 `after n` + `from`, `prompt`, `options[{id,label,when?,flags?,record?,do?,fail_forward?}]`, `at`/`radius`).
- 문제: `{ title, when?, activities, fail_forward?{ id: { at, label, text, extra{text, record}, do? } }, result?{ flags, do } }`.
- 상태: `pb.<문제>.<활동>` · `pb.<문제>.decision` · `pb.<문제>.ff.<자리>` · `pb.<문제>.done`. 결과·갈래 깃발은 접두사 없는 사건 깃발(구체적 행동 — 합산 없음).
- 조건식: `pa('문제','활동')` · `pd('문제')` · `pn('문제','a,b')` · `pdone('문제')`.
- 기록 id: `pb_<문제>_<활동>` · `pb_<문제>_<결정>_<갈래>` · `pb_<문제>_ff_<자리>`.
- 금지: 문제 단계 안 `event`·`phase`·`outcome`·`ending`(FIXED_BEAT·국면·결말은 문제와 무관 — 검사기가 막는다).
- 한 번만: 만든 단계 첫머리가 '아직 안 했으면' + 완료 깃발. 저장/불러오기: 마친 관찰 안 섬 · 물건 안 되돌림 · 결정 유지 · 결정 전에 끊긴 저장은 결정 자리에서 다시 묻는다.

예(오누이):

```gdscript
"beast_way": {
  "when": "f('case_started') and ph('explore') and not f('dusk_prep')",
  "activities": [
    { "id": "mud_print", "type": "inspect", "kind": "seen", "at": "obs_mud_print", "label": "길가 진흙 · 살펴보기",
      "text": ["진흙에 사람 발보다 훨씬 큰 자국이 남아 있다.", "발가락 넷 앞에 발톱이 찍혔다."],
      "record": { "title": "진흙의 큰 자국", "text": "…" } },
    …,
    { "id": "which_way", "type": "decide", "after": 2, "at": "obs_decide", "prompt": "어느 쪽 흔적을 먼저 확인할까?",
      "options": [{ "id": "down", "label": "물레방아 소리가 나는 길 아래쪽", … },
                  { "id": "forest", "label": "길을 벗어난 서쪽 숲가", "fail_forward": "deer_path", … }] },
  ],
  "fail_forward": { "deer_path": { "at": "obs_wrong_spot", "text": ["작은 굽 자국뿐이다. 노루가 다니는 길이다."],
      "extra": { "text": ["돌아서는데, 길가 흙에 큰 자국이 하나 더 있다.", "발톱 끝이 고개 아래를 향한다."], "record": {…} } } },
  "result": { "flags": ["beast_way_read"], "do": [{ "clue": "trace_downhill" }, { "discover": "mill" }] },
}
```

## 4. 오누이 — 서사형 튜토리얼 보강(§4)

갈아엎지 않았다. 추적·첫 조우 전투·아이 보호·밤·원전 결말·사건 흔적·FIXED_BEATS 그대로. 관찰 넷(셋 + 선택 하나)과 아주 쉬운 판단 한 번만 더했다.
문법: 본다(E 살펴보기 + 카드 한 장) → 기록된다(◆) → 둘을 잇는다("어느 쪽 흔적을 먼저 확인할까?") → 걸어간다.

**자리** — 실제 길: `region.json namwon_north_road`(고갯마루 아래 (-3187.3,-265.4) → 방앗간 옆 (-3188.4,-345.4)). 첫 조우 숲(`tracks_end` -3172.4,-249.6)에서 방앗간·외딴집으로 내려가는 사이. 걸을 수 있는 땅인지 시험이 `world.blocked`로 본다.

| 활동 | 앵커(x, z) | 길까지 · 가까운 기존 자리 | 카드 글(본 것 + 한 걸음 해석) |
|---|---|---|---|
| `mud_print` 길가 진흙 | `obs_mud_print` (-3185.6, -272.0) | 길 동쪽 1.8m · tracks_end 26m | 진흙에 사람 발보다 훨씬 큰 자국이 남아 있다. / 발가락 넷 앞에 발톱이 찍혔다. |
| `bent_grass` 길섶 풀 | `obs_bent_grass` (-3190.4, -284.0) | 길 서쪽 2.8m · 방앗간 주인 31m | 길섶 풀이 한쪽으로 납작하게 눌려 있다. / 무거운 것이 비비고 지나간 자리다. |
| `fur` 덤불 가시 | `obs_fur` (-3185.2, -296.5) | 길 동쪽 2.5m · 방앗간 주인 18m | 덤불 가시에 누런 털 몇 가닥이 걸려 있다. / 사람 허리보다 높은 데다. |
| `which_way` 판단(셋 중 둘 뒤) | `obs_decide` (-3188.0, -284.0) r30 | 길 위 | 어느 쪽 흔적을 먼저 확인할까? — 물레방아 소리가 나는 길 아래쪽 / 길을 벗어난 서쪽 숲가 |
| fail_forward `deer_path` 숲가 | `obs_wrong_spot` (-3196.0, -288.5) | 길 서쪽 8.4m(서쪽 숲을 고른 뒤만) | 작은 굽 자국뿐이다. 노루가 다니는 길이다. → 돌아서는데, 길가 흙에 큰 자국이 하나 더 있다. / 발톱 끝이 고개 아래를 향한다. |
| `house_mixed` 울 밑 흙(선택) | `obs_house_mixed` (-3219.5, -348.5) | 외딴집 마당(sw_yard) 서쪽 끝 · 헛간 앞 5.2m | 작은 짚신 자국 위로 큰 자국이 겹쳐 찍혀 있다. / 큰 자국이 나중에 생겼다. |

- 결과(어느 갈래든 같은 것): 추정 △ "흔적이 가는 쪽 — 큰 자국은 고개 아래, 사람 사는 쪽으로 이어지는 것 같다." · 깃발 `beast_way_read` · 지도에 물레방앗간(들음). 서쪽 숲은 막히지 않고 헛걸음 한 번 + 흔적 하나 더 → 같은 결과로 본 흐름(방앗간 → 흰 발자국 → 외딴집).
- 관찰 글에 범·호랑이·방향의 정답을 쓰지 않는다(시험이 본다). "호랑이가 북쪽으로 갔다" 같은 글 없음.
- 보이는 때: 사건이 선 뒤 낮(`explore`), 밤 준비(`dusk_prep`)가 시작되면 사라진다(밤 장면을 가리지 않게). 첫 조우 전에 먼저 내려와도 된다.
- 관찰은 밤을 앞당기지 않는다: `night_ready`의 '단서 12개' 안전장치가 문제 기록(pb_*·trace_downhill)을 세지 않게 했다(이걸 안 했을 때 namwon:A/B가 낮에 해 질 무렵 귀환을 먼저 틀어 실패했다 — 고쳐서 PASS).
- 조작: 관찰 = E 한 번 + 카드 한 장, 판단 = 고르기 창 한 번(관찰 모드·전용 화면 없음).

### 시험

| 시험 | 결과 |
|---|---|
| `validate_problems`(새) | PROBLEMS PASS 9 problems=1 |
| `activity_test`(새, 공통 — 계약 · 하드코딩 · 실제 실행 · 한 번만 · Fail Forward · 저장/불러오기 · 등뼈) | ACTIVITYTEST PASS 52 |
| `namwon:observe`(새 대본 시험) | STORYTEST PASS checks=32 — 관찰 기록(fact·기록책 ◆) · 하나로는 안 물음 · 둘 뒤 한 번 · 관찰 도중 저장/불러오기 · 서쪽 숲 → 판단 뒤 저장/불러오기(유지·안 물음) · 숲가 → 추가 흔적 → 같은 결과 · 두 번 불러도 한 번 · 선택 관찰 둘 · FIXED_BEATS·국면·결말 그대로 · 밤 준비 때 없음 · 자리 다섯 다 걸을 수 있음 |
| `namwon:A`(길 아래) · `namwon:B`(서쪽 숲 Fail Forward) · `namwon:C`(건너뜀) | 셋 다 끝까지 PASS — FIXED_BEATS 열 개 순서·결말 A/B/C·밤 조작 비율 그대로 |
| 그 밖의 검사·단위 시험 | §6 표 |

### 화면(창 1024×768, 시험 저장 `user://st_oneonui_shots.json` — 찍은 뒤 지움)

`seolhwa_godot/shots/arch_pass/oneonui/`(git 밖)

| 파일 | 내용 |
|---|---|
| `oneonui_observe.png` | 길가 진흙 살펴보기 — 카드 "진흙의 큰 자국"(◆단서), 고갯마루 아래 흙길 |
| `oneonui_decide.png` | 관찰 둘 뒤 "어느 쪽 흔적을 먼저 확인할까?" — 두 갈래, 왼쪽 위 알림 둘(진흙의 큰 자국 · 눌린 풀) |

다시 찍기: `godot --path seolhwa_godot res://scenes/region.tscn --resolution 1024x768 -- --storytest=namwon:observe --storyshots=shots/arch_pass/oneonui --savefile=user://st_oneonui_shots.json`
(시험이 상태를 꾸며 바로 들어가서 첫 장에 「남원」 지명과 깃발 알림이 같이 보인다 — 실제 놀이에서는 이미 지난 알림이다.)

## 5. 에이전트 2에게 — 춘향 II-B 술·쌀·상소를 이 계약으로

`story/namwon_chunhyang/`의 II-B 데이터에 `"problems"`를 두고, `namwon_chunhyang_data.gd`가 PART I·II-A처럼 이어 붙이면 된다(`out.problems = …` — `case_registry.load_data`가 expand한다. `anchors`·`actors`가 같은 사전에 있어야 검사기가 자리·인물을 찾는다). 세 문제는 서로 독립(순서 자유), 각 문제는 한 번만 풀린다.

```gdscript
static func problems() -> Dictionary:
	return {
		"wine": {   # 술 — 관아 지시 → 수레의 실제 술독 → 상인의 말 → 차이 → 처리
			"when": "ph('act13')",   # II-B 단계 이름에 맞춘다
			"activities": [
				{ "id": "order", "type": "inspect", "kind": "seen", "at": "<관아 지시 문서 앵커>", "label": "술 지시 · 살펴보기",
					"text": ["…독이라 적혀 있다."], "record": { "title": "관아의 술 지시", "text": "…" } },
				{ "id": "cart", "type": "inspect", "kind": "seen", "at": "<술 수레 앵커>", "label": "술 수레 · 살펴보기",
					"text": ["수레에 실린 독은 …"], "record": { "title": "수레의 술독", "text": "…" } },
				{ "id": "merchant", "type": "inspect", "kind": "heard", "actor": "<술 상인 actor id>", "by": "술 상인",
					"record": { "title": "상인의 말", "text": "…" }, "required": false },   # 상인 talk에 { "activity": "wine.merchant" }
				{ "id": "gap", "type": "compare", "needs": ["order", "cart"], "text": ["지시와 수레가 맞지 않는다."],
					"record": { "title": "지시와 다른 수", "text": "…", "kind": "fact" }, "flags": ["wine_discrepancy_seen"] },
				{ "id": "handle", "type": "decide", "needs": ["gap"], "at": "<수레 앵커>", "radius": 12.0, "prompt": "술독을 어떻게 할까?",
					"options": [
						{ "id": "all", "label": "전부 가져간다", "flags": ["wine_taken_all"] },
						{ "id": "leave", "label": "한 독 남긴다", "flags": ["wine_left"], "do": [{ "world": "wine_jar_left" }] },
						{ "id": "record", "label": "상인의 말을 기록한다", "when": "pa('wine','merchant')", "flags": ["wine_recorded"] }] },
			],
			"result": { "flags": ["wine_done"] },
		},
		"rice": { … order(징발 지시량) · sacks(실린 가마 수) · farmer(heard, 농민) · gap(compare) ·
			handle(decide: 전부 rice_taken_all / 한 가마만 rice_left / 아전에게 다시 묻기 rice_reasked) … },
		"petition": { … old_man(heard — 노인, 이겸 가능성 한 줄은 record 글로만, MAIN_MASTER_TRACE 안 바꿈 → old_man_heard) ·
			route(seen — 문서가 가야 할 곳) · status(seen — 실제 처리 상태) · gap(compare: "내일 와"와 실제 — kind guess) ·
			handle(decide: 기록한다 petition_processed / 그냥 둔다) … },
	}
```

- **들은 것은 `kind: "heard"` + `by`**(기록책 ◇). 노인의 말은 들은 것으로만 — 자동 확정 금지. 확인은 `compare`의 `kind: "fact"`나 깃발로.
- 결과 깃발 이름은 브리프 §18 예시대로 구체 행동(합산 없음). 결말·피해 복구는 이 깃발을 읽는다(`f('wine_left')` 등).
- **FIXED_BEAT·국면은 문제 밖에서**: 몽룡 귀환·옥중 상봉·잔치·어사출두·석방은 사건 흐름(트리거·`_case.gd`)이 일으킨다. 문제 단계에 `event`·`phase`·`outcome`·`ending`을 넣으면 검사기가 FAIL. 세 일이 다 끝났는지는 `pdone('wine') and pdone('rice') and pdone('petition')`으로 읽는다(소극적 판단도 "풀림"이다 — 막히지 않는다).
- 실패해도 막히지 않게: 틀린/소극적 판단도 결정이 나면 `result`가 돈다. 헛걸음이 필요하면 갈래에 `fail_forward`.
- 인물 talk에 `{ "activity": "rice.farmer" }`를 넣는 것을 잊으면 검사기가 "talk 어디에도 없음"으로 잡는다.
- 단계마다 저장/불러오기는 계약이 맡는다(대상 when·결정 트리거). 사건 쪽에서 따로 할 일 없음.
- 검사: `godot --headless --path . -s res://tools/story/validate_problems.gd` → `PROBLEMS PASS 9 problems=4`가 되어야 한다.
- 재사용 fixture(§21 '관아 창고 장부 대조')는 `tests/activity/activity_test.gd`의 `fixture()`가 이미 같은 꼴(본 것 둘 + 들은 것 + 비교 + 결정 + fail_forward)이다 — demo를 만들 때 그대로 옮겨 쓰면 된다.

## 6. 시험 숫자(에이전트 1 끝)

| 시험(차례로 한 번씩) | 결과 |
|---|---|
| `validate_event_class` | EVENTCLASS PASS checked=159 |
| `validate_case_meta` | CASEMETA PASS 9 warn=5 |
| `validate_problems`(새) | PROBLEMS PASS 9 problems=1 |
| `case_registry_test` | REGTEST PASS 47 |
| `map_leads_test` | MAPLEADS PASS fixtures=69 |
| `sound_test` | SOUNDTEST PASS 45 |
| `onboarding_rule_test` | ONBOARDRULE PASS 64 |
| `commonize_test` | COMMONTEST PASS 49 |
| `activity_test`(새) | ACTIVITYTEST PASS 52 |
| `tools/run_story_tests.sh` 전체(마지막 한 번) | **65/65 PASS**, SCRIPT ERROR 0, exit 0 — 새 `namwon:observe` 포함(64 → 65). namwon:A·B·C 결말 A/B/C 그대로 |
