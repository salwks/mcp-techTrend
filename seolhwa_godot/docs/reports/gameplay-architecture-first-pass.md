# 게임플레이 구조 1차 — 보고서

> 지시: `seolhwa/docs/production/BRIEF_gameplay_architecture_first_pass.md`(사용자 원문 요지)
> 상위 문서: `seolhwa/docs/production/SEOLHWAROK_GAMEPLAY_ARCHITECTURE_FINAL_v1.0.md`
> 나눠 맡음: 에이전트 1 = §26의 1~3(방향 문서 · Activity/Problem 계약 · 오누이 보강) — §1~§6. 에이전트 2 = §26의 4~6(춘향 II-B) — §7~§18. 에이전트 3 = §26의 7~10(재사용 demo · 전체 시험 · 실제 화면 순회 · 최종 보고) — §19~§33.
> **최종 요약은 §19(종합)부터 읽으면 된다.**
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

---

# 에이전트 2 — 춘향 PART II-B(브리프 §26의 4~6)

> 시작 HEAD `b7c1e37`. 범위: ACT 13 술·쌀·상소(Activity/Problem 첫 사례) → 남은 FIXED_BEAT(몽룡 귀환~어사출두~파면) → 피해 복구 · 석방 · 마지막 선택 · 광한루 결말.
> 재사용 demo·전체 14장 화면 순회·최종 보고는 에이전트 3.

## 7. 바꾼 파일(에이전트 2)

| 파일 | 무엇 |
|---|---|
| `story/namwon_chunhyang/namwon_chunhyang_p2b_data.gd` | **새** — II-B 데이터: 문제 셋(`problems()` wine·rice·petition) · 인물(아전·상인·농민·포졸·노인·거지 몽룡·월매·잔치 변학도·옥 춘향·역졸 여섯·어사 측 서리·아이 둘) · 일하는 손 objects(지고 간다/내려놓는다) · 트리거(장면·엿듣는 말) · 소품(빈 수레·한 독 남은 수레·물자·잔치 술독/가마니·돌아가는 가마니) · 기록 · 지도 표 · FIXED_BEATS 8 · 장면 C1300~C2201 |
| `story/namwon_chunhyang/namwon_chunhyang_p2b.gd` | **새** — II-B 연출(p2a를 잇고 case가 이것을 잇는다): 일의 결과·지고 가기·다시 묻기 · 14A · 월매 집 · 옥중 상봉 · 잔치 · 17A · 출두(8A→18A) · 피해 복구 · 석방 · 마지막 선택 · 광한루 · 불러오기 · 기록책 · 조작 비율(ctl2) |
| `story/namwon_chunhyang/namwon_chunhyang_p2b_test.gd` | **새** — 대본 시험 `namwon_chunhyang:iib1·iib2·iib3`(+ 실제 시간 `iibctl`) |
| `story/namwon_chunhyang/namwon_chunhyang_case.gd` | (PART I 파일, 최소) `extends` p2a → p2b 한 줄 · `music_wanted` 끝 `return ""` → `return p2b_music()`(잔치 음악) |
| `story/namwon_chunhyang/namwon_chunhyang_data.gd` | (PART I 파일, 최소) II-B를 잇는 블록(문제·인물·트리거·FIXED_BEATS +8 등) · 앵커 합치기 · 기록책 '모를 것' 둘의 `until`을 `false` → `mongryong_return_seen` / `chunhyang_released`(끝나도 남던 물음) · 머리 주석 |
| `story/namwon_chunhyang/namwon_chunhyang_p2a_test.gd` · `namwon_chunhyang_test.gd` | 'II-B 장면 없음'(데이터에 C13+가 없어야 함) → **'II-B가 돌지 않음'**(본 장면·서 있는 인물·플래그)으로. 하네스: `iib*` 갈래 · `choice_log` · II-B 컷 probe |
| `region_data/JL_NAMWON_UNBONG/placement_story_namwon_chunhyang.json` | 잔칫상 6개 축 쪽 0.5m(+방석 자리·빼는 곳) · `ti_wine_cart`/`ti_rice_sacks` when(내린 뒤 숨음) |
| `scripts/story/continue_test.gd` | `--continueexpect=chunhyang_p2b`(플레이 시험 저장 확인) |
| `tools/audio/make_placeholders.py` · `assets/audio/{sfx,bgm}` · `README.md` · `scripts/audio/sound.gd` · `tests/audio/sound_test.gd` | 임시 소리 `hoofbeats` · `chuldu_cry` · `cup_clink` · `brush_stroke` · `bgm_feast`(예전 파일 그대로 — 씨앗 뒤에 붙임) |
| `tools/run_story_tests.sh` | `namwon_chunhyang:iib1·iib2·iib3`(65 → 68) |
| `seolhwa/docs/production/CHUNHYANG_ASSETS_PLACEMENT_v1.0.md` §13 · `CITY_ROUTE_PRODUCTION_RULES_v1.0.md` C62 | 잔칫상 측정·고침 · 평소 시점 차일 FURLED |

새 공통 코드는 없다. `problems.gd`·`story_runner`·검사기는 손대지 않았다(계약 그대로 데이터만).

## 8. ACT 13 — 술·쌀·상소(Activity/Problem, 순서 자유 · 각각 한 번)

문법은 셋 다 같다: **현장에 가서 본다(E · 카드) → 사람에게 직접 묻는다(곁에 선 채 자막) → 둘이 맞지 않음을 잇는다(카드 한 장) → 고른다(고르기 창 한 번) → 몸으로 한다(지고 가기·다시 묻기·말하기)**. 정답 없음 — 플레이어는 이미 무엇이 부당한지 안다(§11). 각 문제 `when`: `ph('jail') and f('duty_on') and not f('duty_over')`.

| 문제 | 본 것(◆ fact) | 들은 것(◇ heard — 말한 사람) | 잇기(compare) | 고르기 → 깃발 | 몸으로 |
|---|---|---|---|---|---|
| **술** `wine` | 바깥마당 동쪽 **잔치 물목**("술 — 김가 술도가, 두 독 · 값은 관아 창고에서 셈") · 외삼문 동쪽 **수레의 술독 셋**(김가 봉지) | 술 상인 김가 "지난번 술값도 못 받았소 · 두 독이라 했는데 셋 다 내리라잖소"(선택) | 물목 두 독 ↔ 내리는 세 독, 값 치른 자국 없음(fact) → `wine_discrepancy_seen` | 세 독 다 내린다 `wine_taken_all` / 물목대로 두 독, 한 독은 수레에 `wine_left` / 다 내리되 상인의 말을 적는다 `wine_recorded`(상인 말을 들었을 때만 · 기록 ◇) | 수레에서 독 하나를 지고(`wine_lifted`, 장면 물건 `ITM_CH_WINEJAR`) 물자 곳에 내려놓음(`wine_stored`). 수레는 빈 수레/한 독 남은 수레로 바뀐다 |
| **쌀** `rice` | 박가네 수레의 **징발 표**("벼 두 가마") `rice_order_seen` · **대문 앞 가마니 넷**, 뒤주는 거의 빔 | 농민 박가 "겨울 먹을 겁니다 · 두 가마라 해서 내놨는데 넷을"(선택) | 표 두 가마 ↔ 넷(fact) → `rice_discrepancy_seen` | 물러서라 한다 `rice_taken_full` / 한 가마만 `rice_left` / 아전에게 다시 묻는다 `rice_reasked` | 가마니를 지고 관아로(약 65m) — 넷이면 대문 앞 가마니 사라짐 / 다시 묻기는 **외삼문 앞 아전에게 걸어가서** "표에 두 가마면 두 가마지"(`rice_reask_done`) |
| **상소** `petition` | 외삼문 곁 **방**("소지는 형방이 받아 사흘 안에 제사") · **형방 소지함**(잔치 물목 밑에 같은 이름 소지 셋, 열흘째 제사 없음) | 노인(◇ 농부) "잔치에 쓴다고 소를 가져갔소" `old_man_heard` · "책 한 권 끼고 다니는 선비가 … 적어 갔지" `yi_gyeom_trace_heard` — **둘 다 들은 것, 자동 확정 없음. 기록 글에 이겸이라 쓰지 않음. MAIN_MASTER_TRACE 그대로(시험)** | '내일 와' ↔ 열흘째 그대로(△ 추정) → `petition_gap_seen` | 아전 말대로 돌려보낸다 `petition_dismissed` / 소지를 맨 위에 올리고 받은 날을 적는다 `petition_processed` / 노인의 말을 내 기록책에 `old_man_recorded`(들었을 때만 · 기록 ◇) | 돌려보내기는 노인에게 가서 "내일 오시오" — 노인이 일어나 걸어간다 |

- 시작: II-A 첫 밤 뒤 관아 앞에서 한 번 멀어졌다 돌아오면(`p2b_away`) C1300 "이튿날 아침" — 아전이 일 셋을 맡김(아전 곁에서 조작을 쥔 채 자막). 끝: 셋 다 풀리고 지고 간 것·다시 물은 것·노인에게 한 말까지 하면 `duty_complete` → 아전 C1305 → "며칠 뒤 해 질 무렵".
- 엿듣는 말(조작 그대로): 수레 곁 상인·아전("사또 생신인데 잔돈 가지고 시끄럽게 하지 마.") · 박가네 농민·포졸("관아 명령이다.") · 담 밑 노인·아전("내일 와." "어제도 내일 오라 했소.").
- 소극적/틀린 고르기도 결정이 나면 `result`가 돈다(막힘 없음). 사연을 안 들으면 '적어 둔다' 갈래가 없을 뿐.
- 점수 없음 — 행동 깃발만. 결말·복구가 그대로 읽는다.

## 9. FIXED_BEAT 보존(문제 결과와 무관)

순서(시험이 `S.world.beat_order`로 정확히 본다, 중복 없음): **몽룡 귀환(14A) → 월매 집 → 옥중 상봉 → 생일잔치 → 시(17A) → 어사출두 → 변학도 파면 → 피해 복구 → 춘향 석방 → 마지막 선택** → 광한루 끝. 사건 메타 FIXED_BEATS 11 → 19.

- **몽룡 귀환**: 남문 밖 해 질 무렵, 플레이어 어깨 너머 14A. 거지 차림(`mongryong_beggar`), 마패는 안 보임. "…오랜만이오." "그 모습은…" "못 본 사람으로 해 주시오." — 신분 설명·추리·선택 없음.
- **월매 집**: 대문 앞에서 조작을 쥔 채 엿듣는다. "돌아온다더니 거지가 돼 왔소?"(◇ 월매).
- **옥중 상봉**: 몽룡이 스스로 포졸에게 간다. 관아 관계(구체 행동 둘: 잡역을 스스로 맡음 `labour_accepted` + 줄을 놓지 않음)가 좋으면 "(거든다) 저 사람, 잠깐만 들여보내 주시오." 고를 수 있고, 아니거나 지켜보면 **월매가 엽전을 쥐여 주는 다른 길** — 어느 쪽이든 12A 옥 장면(둘의 장면, 플레이어는 창살 밖).
- **잔치**: 이튿날. EventCrowd 14(손님 8·기생 4·시중 2), 사령·선임은 고정 이야기 인물, 보계·교의·병풍·독상·술상·차일. 내가 나른 김가 술독(셋/둘)과 박가네 가마니가 보계 양옆에(8A 틀 안), 선택 관찰 "잔치 술독".
- **§41 몽룡 입장**: 서쪽 줄 끝에 서면 — 낮은 틀, 조작 그대로, 엿듣는 자막("어디 거지가 들어와." "글은 옷이 쓰는 게 아니잖소.").
- **§42 시**: 17A(종이를 위에서) 네 줄, 잔치 음악이 줄마다 작아짐. 손님 하나가 제자리에서 일어선다.
- **§43 어사출두**: 공식 8A(FURLED) 줄에 선 채 조작 — **음악 끊김 → 말발굽 → 침묵(hush) → 멀리 "암행어사 출두야!" → 더 가까이** → 18A(변학도 뒤에서 정문 쪽): 역졸 여섯이 들어오고 몽룡이 가운데로, 마패(`mapae`). **같은 노드가 제자리에서 자세만**: 군중 14 `apply_on_flag`(sit→kneel, 나머지 bow) · 사령 9 `set_pose kneel` · 변학도 제자리 `cower`. 보스전·전투 없음(trace에 combat 없음). §45 "관인을 거두시오." → 파면.
- **처벌은 문제와 무관**: 세 갈래(순응·저항·섞임) 모두 같은 출두·파면·석방.

## 10. 피해 복구 · 석방 · 마지막 선택 · 광한루

- **ACT 19**: 몽룡 "자네도 관아 일을 했다고 들었소. 직접 본 게 있소?" — 갈래는 **깃발에서만** 열린다(본 것/들은 것 말씨를 가른다):
  본 것 "술 물목은 두 독인데, 세 독을 내리라는 것을 보았습니다." · "쌀을 더 가져간 것을 보았습니다." · "노인의 소지가 열흘째 열리지도 않은 것을 보았습니다." /
  들은 것 "술 상인이 지난번 술값도 못 받았다고 들었습니다." · "박가네에서 그 쌀이 겨울 양식이라고 들었습니다." · "소를 가져갔다고 들었습니다."(몽룡 "본 것은 아니고?") /
  끝 "그것뿐입니다." 또는 "내가 직접 확인한 것은 많지 않소." 몽룡: "변학도 일은 내 조사로 이미 끝났소."
- 복구(합산 없음 — 깃발 → 복구 깃발): 술값 지급 `restore_wine_paid`(적어 둠/말함) · 한 독만 건짐 `restore_wine_partial`(남김) · 쌀 반환 `restore_rice_returned`(말함) · 박가가 고개 숙임 `restore_rice_thanks`(한 가마만) · 두 가마는 마당에 `restore_rice_spared`(다시 물음) · 노인 재조사 `restore_petition_reopened`(소지를 위로/적음/말함) · 아무것도 없으면 `restore_uncertain` "변학도는 관인을 빼앗겼다. 다만 빼앗긴 것들이 다 돌아갔는지는 아무도 확답하지 않았다." 바깥마당 물자 곳에서 바뀐 사람만 보인다(조작 그대로).
- **석방**: 몽룡이 직접 옥으로 걸어가고 플레이어·월매는 뒤(조작). 옥문 OPEN, "늦었소." "많이 늦었습니다." "…미안하오." "왔으니 됐습니다." 월매 "거지라더니." "아주 사람을 잡아먹으려고 작정을 했구먼."
- **마지막 선택**(II-A 포승만 읽는다): 잡음 → "그때 줄을 잡았던 것도 기억합니다." 미안합니다/명령이었습니다/(말 없음) → "압니다." "그래도 다음엔 생각하고 잡으세요." · 놓음 → "그때 손을 놓았지요. 바뀐 건 없었지만…" "봤습니다." · 느슨하게 → "혼날 줄 알면서 힘을 풀었더군요." "그것도 봤습니다."
- **광한루**(며칠 뒤): 빈 그네, 아이 둘. 기록책 "성춘향은 변학도의 수청을 끝내 거절했다." "이몽룡은 암행어사가 되어 남원으로 돌아왔다." + 내가 한 일 한 줄(놓음 "…한 번은 손을 놓았다." / 적어 둠 "…들은 말을 기록해 두었다." / 느슨하게 "…한 번은 줄을 느슨하게 잡았다." / 그 밖 "모든 것을 보았으나, 모든 일에 손을 쓸 수 있었던 것은 아니다.") → "약속을 지킨 것은 내가 아니었다." → `CASE_NAMWON_CHUNHYANG_OUTCOME = "RELEASED"` · `CASE_NAMWON_CHUNHYANG_COMPLETE = true`(단계 done) · 결말 카드.

## 11. 저장/불러오기

- 사건 namespace만(공통 시스템이 따로 복제하지 않음). 문제 상태는 계약(`pb.*`), 일하는 손·장면은 사건 깃발.
- 불러오면: 마친 관찰은 다시 안 섬 · **지고 있던 술독/가마니는 그대로 지님**(되돌리지 않음) · 결정 유지(다시 묻기 전이면 결정 그대로·지고 갈 것 없음) · 장면 도중이면 그 장면 트리거만 다시(완료 깃발 있는 장면은 안 돎) · 잔치 도중이면 줄 끝부터(입장 장면 다시 안 함, 시 뒤면 출두만) · 출두 뒤면 같은 자세 다시 맞춤(군중·사령 kneel·변학도 cower) · beat는 `beat2`가 한 번만 센다.
- 시험한 것: iib1 관찰 하나 뒤 · 술독을 진 채 / iib2 잔치 도중(입장 뒤) / iib3 아전에게 묻기 전 · 잔치 날 아침 — 매번 저장→비움→다시 읽기 뒤 상태 문자열 같음, 끝난 장면이 다시 돌지 않음(마크 수 그대로).

## 12. 잔칫상 간격 — 실제 측정(사용자 결정 §9-3)

배우가 움직인 뒤(§41 몽룡이 걸어 들어오고 시중·기생이 오간 뒤 30프레임) 시험 `measure_gap`: 사령 실제 자리(x −3168.7 / −3155.5) 몸 반지름 0.375 끝 ↔ 잔칫상 충돌체 끝(world.blocked 0.005m 걸음으로 훑음), z 210.8 · 213.2 · 215.6 여섯 줄.

| | 사령↔상 실제 틈 | 플레이어 원(0.375) 통과 | 상 사이 가운데 | 사령↔앉은 손님 등(참고) |
|---|---|---|---|---|
| 고치기 전(상 x −3166.9 / −3157.3) | **1.18m**(여섯 줄 같음) — 1.6 미만 | 지나감 | 9.12m | 0.45m |
| **고친 뒤(상만 축 쪽 0.5m: −3166.4 / −3157.8)** | **1.68m ≥ 1.6** | 지나감 | **8.12m**(가운데 빼는 곳 5m 그대로) | 0.95m |

사령 줄은 움직이지 않았다. 방석 자리(`seats`)·빼는 곳(`table_w/e`)도 함께 0.5m. §42 서안(−3165.7, 212.0)과 겹치지 않음(상 z 범위 밖).

## 13. 조작 비율(실제 시간 — `--storytest=namwon_chunhyang:iibctl --ctlspeed=4.6`, 헤드리스 벽시계, II-A와 같은 판정)

창은 열지 않고 헤드리스 벽시계로 쟀다(대사·카드는 읽는 시간 1.0+0.06초/글자, 고르기·카드 1.5초 — II-A ctl과 같은 봇). 봇은 달리기 4.6m/s 직선(충돌 무시 — 실제 길보다 짧아 보수적). 갈래: 술 한 독 남김 · 쌀 한 가마(농민 말 들음) · 소지를 위로(노인 사연 들음) · 끌려감·줄 놓음.

| 판 | ACT 13(이튿날 아침 ~ 일을 마침) | II-B 전체(이튿날 아침 ~ 광한루 끝) |
|---|---|---|
| 처음(모든 결과 자막·대화를 대화창·컷으로) | 44.8% (67.5 / 150.5초) | 49.9% (311.5 / 624.3초) |
| 일의 결과·옮기는 자막을 걸으며 읽게 · 월매 집·외삼문 실랑이·복구 장면을 지켜보며 조작 | 52.8% (67.6 / 128.1초) | 61.4% (373.0 / 607.9초) |
| 사람에게 직접 묻는 말(상인·농민·노인)도 곁에 선 채 자막 | 65.8% (87.1 / 132.4초) | 64.1% (392.5 / 612.4초) |
| **지금** — 아전이 일을 맡기는 아침도 곁에 선 채 자막 | **76.4% (102.3 / 134.0초)** | **66.4% (407.6 / 613.6초)** |

조작이 아닌 시간(지금): ACT 13은 관찰 카드 여섯 · 잇기 카드 셋 · 고르기 셋 · 아침 암전 · 포졸 한마디·아전 다시 묻기 · 일을 마침 대화(약 32초). II-B 전체는 그 밖에 원전 장면 컷 — 14A · 옥 12A · 잔치 입장 · 17A 시 · 18A 출두와 §45 · 피해 복구 물음 · 석방·월매·마지막 선택 · 광한루(약 175초). 장면마다 누적 값은 실행 줄 `CTL2 … marks=`.
다시 재기: `godot --headless --path seolhwa_godot res://scenes/region.tscn -- --region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:iibctl --ctlspeed=4.6 --notitle --savefile=user://st_iibctl_run.json`(약 11분, `STORYTEST PASS … IIBCTL checks=135`).

## 14. 시험(에이전트 2 끝 — 차례로 한 번씩)

| 시험(차례로 한 번씩) | 결과 |
|---|---|
| `validate_event_class` | EVENTCLASS PASS checked=170 (159 → 170, II-B 장면 11) |
| `validate_case_meta` | CASEMETA PASS 9 warn=5 |
| `validate_problems` | **PROBLEMS PASS 9 problems=4**(오누이 1 + 술·쌀·상소 3 · namwon_chunhyang activities=16) |
| `case_registry_test` | REGTEST PASS 47 |
| `map_leads_test` | MAPLEADS PASS fixtures=69 |
| `sound_test` | SOUNDTEST PASS 50 (45 → 50, 새 소리 다섯) |
| `onboarding_rule_test` | ONBOARDRULE PASS 64 |
| `commonize_test` | COMMONTEST PASS 49 |
| `activity_test` | ACTIVITYTEST PASS 52 |
| `namwon_chunhyang:iib1`(새 — 순응·소극) | STORYTEST PASS checks=147 |
| `namwon_chunhyang:iib2`(새 — 저항) | STORYTEST PASS checks=145 |
| `namwon_chunhyang:iib3`(새 — 섞임) | STORYTEST PASS checks=145 |
| `namwon_chunhyang:iibctl`(실제 시간 — 목록 밖) | STORYTEST PASS checks=135 |
| `tools/run_story_tests.sh` 전체(마지막 한 번) | **68/68 PASS**, SCRIPT ERROR 0, exit 0 (65 → 68). 춘향 a 89 · b 80 · after 17 · p2a 123 · p2b 90 · p2c 85 · prep 65 · part2prep 61 그대로 |

세 갈래가 함께 보는 것: 술/쌀/상소 순서가 갈래마다 다름(풀린 차례 확인) · 각 문제 두 번 불러도 결정·기록·고르기 수 그대로, 남은 조사·결정 자리 없음 · 본 것 ◆/들은 것 ◇(말한 사람)/추정 △ · 소극적 고르기도 진행 · 몽룡 귀환(14A, 거지 차림, 마패 안 보임, 신분 선택 없음) · 월매 집 · 옥중 상봉(거듦/월매의 길) · 잔치(EventCrowd 14 = 손님 8·기생 4·시중 2, 포졸·사령 없음, 사령 고정 9, 변학도 교의, 잔치 차림, 잔치 음악, 내가 나른 술독 셋/둘·가마니) · 차일(잔치 틀 SPREAD · 평소 시점 FURLED · 17A SPREAD · 출두 8A·18A FURLED) · 사령↔상 실제 틈 ≥1.6·통과·가운데 통로 · 시 · 출두(8A 58 · 줄에서 조작 · 군중 14 같은 노드·같은 자리·자세만 · 사령 9 kneel · 변학도 cower · 음악 끊김 · 전투 없음) · 파면 · 복구 깃발이 갈래마다 다름(iib1 확답 없음 / iib2 술값·쌀 반환·고개 숙임·재조사 / iib3 한 독만·쌀 반환·두 가마 남음·재조사) · 본 것/들은 것 말씨("쌀을 더 가져간 것을 보았습니다." / "소를 가져갔다고 들었습니다.") · 석방 · 춘향 마지막 말이 포승대로 · 빈 그네·아이 둘 · 기록책 세 줄 · RELEASED · COMPLETE · 먼 길 막음 풀림 · FIXED_BEAT 순서·중복 없음 · MAIN_MASTER_TRACE 그대로 · 저장/불러오기(§11).

## 15. 화면(창 1024×768, 시험 저장 `user://st_iib_shots.json` — 찍은 뒤 지움) — `seolhwa_godot/shots/arch_pass/chunhyang/`(git 밖)

| 파일 | 내용 |
|---|---|
| `13_wine_work.png` | 술 일 — 수레에서 독 하나를 지고(상인의 말을 적은 갈래라 수레는 빈 수레), 왼쪽 위 알림: 잔치 물목 · 물목과 다른 수 · 적어 둔 것 · 술독(김가 봉지) |
| `18A_after.png` | 출두 뒤 18A — 몽룡(거지 차림) 가운데서 마패, 역졸, 기생이 제자리에서 절, 변학도는 아래 가운데 웅크림 |
| `19_restoration.png` | 피해 복구 — 바깥마당 물자 곳: 어사 측 서리, 술값 받는 김가, 고개 숙인 박가, 따로 불린 노인 |

같은 실행에서 다른 컷도 찍혔다(에이전트 3 순회용 참고): `14A_beggar_return` · `15_wolmae_beggar` · `16_12A_reunion` · `17_feast_general` · `17b_walk_feast`(평소 시점 — 차일 FURLED, 마당이 보임) · `17_mong_edge` · `17A_poem` · `18A_before` · `20_release` · `21_last_choice` · `22_gwanghallu_end`.
보고 고친 것: 첫 촬영 18A에서 편 차일 밑면이 화면 위 1/3을 덮음 → 18A도 출두 틀로 FURLED 그대로 · 보계 앞 역졸 둘이 18A 앞을 막음 → 가운데 통로 양옆(z 215)으로.
남은 것: 18A 카메라(배치 파일 확정값)가 동헌 대청 안이라 들어 올린 분합문이 위쪽에 검은 띠로 걸린다(차일 아님 — 공식 틀이라 손대지 않음, 에이전트 3/사용자 판단).
다시 찍기: `godot --path seolhwa_godot res://scenes/region.tscn --resolution 1024x768 -- --region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:iib2 --notitle --storyshots=shots/arch_pass/chunhyang --savefile=user://st_iib_shots.json`

## 16. 플레이 시험 저장

`user://play_chunhyang3.json`(새 파일 — `progress.json`·칸·`play_act9`·`play_chunhyang`·`play_chunhyang2`는 건드리지 않음): `story/hwangju/test_post_hanyang.json`(남원 C·한양 끝) + PART I 끝(백년가약 증인) + 떠남 + 강릉 완료 + **II-A 끝**(맡음 · 먼저 경고 · 느슨하게 · 팔 · 밥 가져다줌 · "왜 그렇게까지") — 단계 jail, 이튿날 아침 8.3시, 자리 = 관아 앞 서쪽 동서길(−3196.0, 249.4, 관아 앞에서 30m). 관아 앞으로 걸어가면 C1300(아전 · 일 셋).
헤드리스 확인(사본 `user://chp3_verify.json`에 깔아 — 확인 뒤 지움, 원본 md5 그대로): `--continuetest=continue --continuefixture=user://play_chunhyang3.json --continueexpect=chunhyang_p2b` → 시작 메뉴 → 이어 하기 → `STORY loaded case=namwon_chunhyang phase=jail` · II-A 선택 그대로 · 관아 앞으로 가자 C1300(8.4시, `duty_on`) · 상인·농민·노인·아전이 섬 · 조사 대상(술 수레·외삼문 곁 방) · E로 아전·고을 사람 말 걸기 → **CONTTEST PASS**.
(참고: 확인 중 `progress.json`의 md5가 바뀌었는데, 저장 시각 01:19:55 · 공간 남원→한양 노정 · 놀이 시간 11554초로 사용자가 띄워 둔 게임(pid 57900)이 쓴 것이다 — 시험은 모두 `--savefile=user://st_*`/사본만 썼다.)
실행: `godot --path seolhwa_godot -- --savefile=user://play_chunhyang3.json` → 이어 하기.

## 17. 새 기술 부채 · 판단이 필요한 것

1. **차일 평소 시점 FURLED**: C62는 '평소 잔치 놀이 SPREAD'인데, 조작 중 평소 카메라(높이 약 10m)는 천(4.6m, 반투명·가림 처리 없음) 위라 SPREAD면 마당·플레이어가 다 가려진다. 그래서 컷이 끝나 조작으로 돌아오는 경계에서 FURLED로 두었다(낮은 잔치 틀·17A·18A는 SPREAD, 출두 8A FURLED). 다르게 원하면 차일을 가림(occluder) 처리하는 쪽.
2. **출두 외침 소리**: `chuldu_cry`는 사람 목소리 비슷한 합성 모음 띠(임시) — 말은 자막이 맡는다. 실제 녹음으로 바꿔야 한다. `hoofbeats`·`bgm_feast`도 임시.
3. **역졸**: pojol·courier_b 그림을 그대로(마패는 몽룡만). 수행원 전용 차림 없음. 몽룡은 출두 뒤에도 거지 차림(마패만 보임) — 원전대로 옷을 갈아입는 컷 없음.
4. **동선 봇**: 실제 시간 측정 봇은 충돌을 무시한 직선(관아 → 동문 밖 박가네 등) — 실제 길보다 짧아 조작 비율은 보수적. 박가네 가는 실제 길(읍성 문)은 따로 확인하지 않았다.
5. **며칠 뒤 시간 건너뛰기**: 일을 마치면 곧 "며칠 뒤 해 질 무렵" 남문 안으로 옮긴다(잔치 준비 며칠은 압축). 그 사이 주막에서 쉬는 등의 자유 시간 없음.
6. **잔치 손님 일어섬**: "슬쩍 일어난다"는 B 구역 앉은 손님 하나의 자세를 idle로 바꾸는 것뿐(걸어 나가지 않음).
7. 복구 장면의 서리는 `official` 그림(이방과 같은 은행) — 어사 측 표시 없음.
8. 상소 '돌려보낸다'를 고른 뒤 노인에게 말해야 일이 끝난다(지도 표 있음) — 잊으면 아전이 "술, 쌀, 노인네." 한 줄만.

## 18. 에이전트 3에게

- 화면 순회: `godot --path seolhwa_godot res://scenes/region.tscn --resolution 1024x768 -- --region=JL_NAMWON_UNBONG --storytest=namwon_chunhyang:iib2 --notitle --storyshots=<폴더> --savefile=user://st_iib_shots.json` — `_cut` 이름: `13_wine_work` · `14A_beggar_return` · `15_wolmae_beggar` · `16_12A_reunion` · `17_feast_general` · `17b_walk_feast` · `17_mong_edge` · `17A_poem` · `18A_before` · `18A_after` · `19_restoration` · `20_release` · `21_last_choice` · `22_gwanghallu_end`. 쌀(박가네)·상소(형방 소지함) 장면은 `_cut`이 없다 — 필요하면 `obj()` 뒤에 `t.cut()` 한 줄.
- 갈래: iib1(순응·확답 없음) · iib2(저항·복구 넷) · iib3(섞임·본 것/들은 것 일부).
- 재사용 demo: 문제 데이터 꼴은 §8 표 그대로(본 것 둘 + 들은 것 + 비교 + 결정 + 결과 call). 일하는 손(지고 가기)은 사건 objects + call — 계약 밖.

---

# 에이전트 3 — 재사용 demo · 전체 시험 · 실제 화면 · 최종 보고(브리프 §26의 7~10)

> 시작 HEAD `29ddc13`. 범위: §21 재사용 demo 하나 · 전체 시험 · §24 화면 14장 · §29 평가 · §27 최종 보고.

## 19. 종합(먼저 읽을 것)

- **한 일(셋 합쳐서)**: 공통 모듈 하나(`problems.gd` — 활동 type 넷 · 문제 · fail_forward · 결과)를 데이터 계약으로 두고, 오누이(관찰 셋+선택 하나 · 초급 판단 한 번), 춘향 II-B 술·쌀·상소(문제 셋), 춘향 끝난 뒤 관아 곁일 「창고 장부 대조」(문제 하나 — 재사용 demo)에 썼다. 새 화면·모드·저장 칸·직업 UI 없음.
- **시험**: 대본 시험 **64 → 68**(새 넷: `namwon:observe` · `namwon_chunhyang:iib1·iib2·iib3`) 전부 PASS, SCRIPT ERROR 0. 새 검사·단위 시험 둘(`validate_problems` · `activity_test`). 숫자는 §23.
- **원전 등뼈 그대로**: FIXED_BEAT 순서·결말은 문제 결과와 무관(세 갈래가 같은 순서·같은 출두·같은 석방, 시험이 `beat_order`로 본다). 바뀌는 것은 주변 피해 복구 · 기록책 끝 줄 · 춘향의 마지막 말뿐.
- **남은 약점**: §28(새 기술 부채)·§30(§29 평가) — 요약하면 ① 조사 대상은 여전히 E 표시가 있는 자리라 "표시를 따라간다"는 느낌이 완전히 사라지지는 않았다 ② 비교 카드 글이 차이를 꽤 직접 말해 준다 ③ 18A 위쪽 분합문 띠 · 잔치 SPREAD 차일의 반투명 막 · 거꾸로 선 컷 카메라에서 인물 그림 방향 ④ 곁일은 결말 직후 같은 놀이에서만 열린다.

## 20. 재사용 demo — 관아 창고 장부 대조(브리프 §21)

`story/namwon_chunhyang/namwon_chunhyang_side_data.gd`(새, **데이터만**) — `namwon_chunhyang_data.gd`가 `problems`·`actors`·`anchors`를 잇는다(3줄 + preload 1줄).

| 활동 | type | 자리 | 글 |
|---|---|---|---|
| `book` 창고 장부 | inspect · seen(◆) | `ch_ledger_book` 바깥마당 동쪽 물자 곳 | 창고 장부. '벼 — 열두 가마 들임.' / 들인 날은 잔치 사흘 전. 내간 줄은 비어 있다. |
| `stock` 실제 가마니 | inspect · seen(◆) | `ch_ledger_stock`(ti_gamani_store_a/b 곁) | 쌓인 가마니를 하나씩 센다. 아홉. / 맨 위 줄에 셋 놓일 자리가 비었다. |
| `keeper` 창고지기 | inspect · heard(◇ 창고지기, 선택) | 인물 `ledger_keeper` talk 안 `{ activity: "ledger.keeper" }` | 잔치 끝나고 이방이 셋을 내갔다 · 어디로 갔는지는 모른다 |
| `gap` | compare(needs book·stock, fact) → `ledger_gap_seen` | 같은 흐름 | 장부는 열두. 창고는 아홉. / 내간 줄에는 아무것도 적히지 않았다. |
| `handle` | decide(after 2) "장부를 어떻게 할까?" | `ch_ledger_yard` r12 | 센 대로 적는다 `ledger_noted`(◆ 기록) / 뒤 곳간부터 확인한다 → **fail_forward** `back_shed` / 내 일이 아니다. 장부를 덮는다 `ledger_shut` |
| fail_forward `back_shed` | 자리 `ch_ledger_shed` | 뒤 곳간 | 곳간 안은 비었다 → 문턱에 낟알 · 수레바퀴 자국이 관아 뒷문 쪽으로(◆) → `ledger_noted` · 같은 결과 |
| result | `ledger_check_done` · 자막 한 줄 | | |

- **열림**: 문제 `when = ph('done')` — 사건이 끝난 뒤(= `CASE_NAMWON_CHUNHYANG_COMPLETE`). jail·feast·epilogue에는 대상·인물이 서지 않는다(시험). 물자 곳 가마니 소품 둘(`ti_gamani_store_a/b`)의 배치 when에 `or ph('done')`만 더했다.
- **데이터만 · 공통 코드에 사건 경로 없음**: 곁일 데이터·창고지기 talk에 `call` 없음(사건 스크립트를 부르지 않음) · `namwon_chunhyang_case/p2a/p2b.gd`와 `problems.gd`·`story_runner.gd`·`story_director.gd`에 `ledger` 글자 없음(activity_test F가 글을 훑는다) · `problems.gd`는 손대지 않았다.
- **검사기가 센다**: `PROBLEMS PASS 9 problems=5`(오누이 1 + 술·쌀·상소 3 + 곁일 1).
- **직업 UI·숙련도·보상 없음.** 결과는 행동 깃발 둘(`ledger_noted`/`ledger_shut`)과 기록뿐. 결말 변수·FIXED_BEAT·기록책 끝 줄은 그대로(시험).
- **한계(정직하게)**: 등록부 `choose()`는 "안 끝난 첫 사건 → 없으면 **첫** 사건"을 고른다. 남원은 `[namwon, namwon_chunhyang]`이라 둘 다 끝난 저장을 다시 불러오면 도는 사건은 오누이(끝남)다. 그래서 이 곁일은 **광한루 결말 직후, 남원을 떠나거나 다시 불러오기 전까지** 같은 놀이에서만 열린다. 공통 코드(`choose`)를 바꾸면 고칠 수 있지만 이번 범위(§28)를 넘어서 후속 후보로 둔다(§32).
- 시험: `activity_test` F(+19 — 계약 · 꼴 · call 없음 · 글자 없음 · 끝나기 전 안 섬 · 곧장 · fail_forward · 저장/불러오기 · 한 번만) · 대본 시험 iib1(바로 덮음) · iib2(창고지기 → 뒤 곳간 → 추가 흔적) · iib3(센 대로 적음) 끝에 실제 관아에서 걸어가 E로(자리 걸을 수 있음 · 두 번 불러도 한 번 · 결말 그대로).

## 21. 바꾼 파일 — 세 에이전트 전체(시작 `6ede0a9` → 끝)

| 파일 | 누가 | 무엇 |
|---|---|---|
| `seolhwa/docs/production/BRIEF_gameplay_architecture_first_pass.md` | 1 | 새 — 사용자 지시 원문 요지 |
| `seolhwa/docs/production/SEOLHWAROK_GAMEPLAY_ARCHITECTURE_FINAL_v1.0.md` | 1 · 3 | 새 상위 문서 · (3) §10에 세 번째 적용(곁일 demo) 한 줄 |
| `seolhwa/docs/scenario/…_v1.1_scenario.md` · `…_v1.1_DECISIONS.md` | 1 | '증거 조합 퍼즐 없음'의 뜻 |
| `seolhwa/docs/production/CHUNHYANG_ASSETS_PLACEMENT_v1.0.md` · `CITY_ROUTE_PRODUCTION_RULES_v1.0.md` | 2 | 잔칫상 측정·고침 · C62 평소 시점 FURLED |
| `scripts/story/problems.gd` | 1 | **새 공통 모듈** |
| `scripts/story/story_runner.gd` · `case_registry.gd` | 1 | 명령 `activity` · 조건 `pa·pd·pn·pdone` · load_data에서 expand |
| `tools/story/validate_problems.gd` · `tests/activity/activity_test.gd` | 1 · 3 | 새 검사기 · 새 공통 시험((3) F 재사용 시연 +19) |
| `story/namwon/namwon_data.gd` · `namwon_case.gd` | 1 | 오누이 문제 `beast_way` · night_ready가 문제 기록을 세지 않게 |
| `scripts/story/oneonui_observe_test.gd` · `story_test.gd` | 1 | 대본 시험 `namwon:observe` · 하네스 |
| `story/namwon_chunhyang/namwon_chunhyang_p2b_data.gd` · `_p2b.gd` · `_p2b_test.gd` | 2 · 3 | II-B 데이터·연출·시험. (3) CAM_18A look · CAM_END focus · 18A 동안 변학도 등 쪽 · 시험에 곁일·쌀/상소 컷·17A 자막 다시 띄움 |
| `story/namwon_chunhyang/namwon_chunhyang_side_data.gd` | 3 | **새** — 곁일 「창고 장부 대조」(데이터만) |
| `story/namwon_chunhyang/namwon_chunhyang_data.gd` · `_case.gd` · `_p2a_test.gd` · `_test.gd` | 2 · 3 | II-B 잇기 · (3) 곁일 잇기 4줄 |
| `region_data/JL_NAMWON_UNBONG/placement_story_namwon_chunhyang.json` | 2 · 3 | 잔칫상 0.5m · 수레/가마니 when · (3) 물자 곳 가마니 when `or ph('done')` · 18A look y 1.8 → −0.6 |
| `scripts/story/continue_test.gd` | 2 | `--continueexpect=chunhyang_p2b` |
| `scripts/audio/sound.gd` · `tests/audio/sound_test.gd` · `tools/audio/make_placeholders.py` · `assets/audio/{sfx,bgm}/*` · `README.md` | 2 | 임시 소리 다섯 |
| `tools/run_story_tests.sh` | 1 · 2 | 64 → 65 → 68 |
| `docs/reports/gameplay-architecture-first-pass.md` | 1 · 2 · 3 | 이 보고서 |

## 22. 새 공통 모듈 · 다시 쓴 기존 시스템

- **새 공통 모듈은 `scripts/story/problems.gd` 하나**(+ 검사기 `validate_problems.gd`). II-B와 곁일은 공통 코드를 하나도 더하지 않았다.
- **다시 쓴 것**(§2 표 그대로 — 새 실행기 없음): `story_runner` 명령(flag·clue·examine·choice·if·caption·give/take·discover) · `story_director` 조사 대상 `objects`(E·먹점) · 자리 트리거 `triggers` · 기록 `clues`(fact/heard+by/guess)와 기록책 `journal_book` · 사건 깃발 `cases.<id>.flags` · 인물 talk · `case_registry.load_data` · 배치 파일 when 게이트(F-11) · EventCrowd `apply_on_flag` · `set_pose`/`anim_actor` · 기존 카메라 컷(`_shot`/`camera`) · 기존 고르기 창.
- 오누이 관찰 목록: §4 표(진흙 · 눌린 풀 · 덤불 털 · 판단 · 숲가 fail_forward · 외딴집 울 밑 흙).
- Activity/Problem 계약: §3 · 상위 문서 §9.
- 술·쌀·상소 흐름: §8. FIXED_BEAT 보존: §9. 저장/불러오기: §11(+ 곁일은 activity_test F · 검사기 saveload).

## 23. 시험 숫자(최종 — 차례로 한 번씩, 동시에 둘 돌리지 않음)

| 시험 | 에이전트 1 시작 전 | 최종 |
|---|---|---|
| `validate_event_class` | checked=159 | **EVENTCLASS PASS checked=170** |
| `validate_case_meta` | PASS 9 warn=5 | **CASEMETA PASS 9 warn=5** |
| `validate_problems`(새) | — | **PROBLEMS PASS 9 problems=5** |
| `case_registry_test` | 47 | **REGTEST PASS 47** |
| `map_leads_test` | fixtures=69 | **MAPLEADS PASS fixtures=69** |
| `sound_test` | 45 | **SOUNDTEST PASS 50** |
| `onboarding_rule_test` | 64 | **ONBOARDRULE PASS 64** |
| `commonize_test` | 49 | **COMMONTEST PASS 49** |
| `activity_test`(새) | — | **ACTIVITYTEST PASS 71**(에이전트 1 52 + 곁일 F 19) |
| `tools/run_story_tests.sh` 전체(마지막 한 번) | 64 | **68/68 PASS · SCRIPT ERROR 0 · exit 0** |

- 더한 대본 시험 **4개**(`namwon:observe` · `namwon_chunhyang:iib1` · `iib2` · `iib3`) — 64 → 68. 더한 검사·단위 시험 스크립트 **2개**(`validate_problems` · `activity_test`). 목록 밖 실제 시간 측정 `iibctl` 1개.
- 대본 시험 안 확인 수: iib1 147 → **159** · iib2 145 → **161** · iib3 145 → **158**(곁일 +12~16). 오누이 observe 32 · A/B/C 결말 A/B/C 그대로. 춘향 a 89 · b 80 · after 17 · p2a 123 · p2b 90 · p2c 85 · prep 65 · part2prep 61 그대로.
- 기존 경고(헤드리스 종료 때 ObjectDB 누수 경고 · "2 resources still in use")는 시작 전 activity_test에도 같이 있었다(오류 아님).

## 24. 실제 화면 순회(브리프 §24 — 창 1024×768, 시험 저장만)

`seolhwa_godot/shots/arch_pass/tour/`(git 밖). 원본은 `tour_raw/`. 시험 저장 `user://st_tour_oneonui.json` · `user://st_iib_tour.json`(찍은 뒤 지움). `progress.json`·칸·`play_*`는 건드리지 않음.

| # | 파일 | 보이는 것 | 판정 |
|---|---|---|---|
| 1 | `01_oneonui_observe.png` | 고갯마루 아래 흙길, 카드 "진흙의 큰 자국" | 읽힘. 시험이 바로 들어가서 「남원」 지명·깃발 알림이 같이 보인다(실제 놀이에선 지난 알림) |
| 2 | `02_oneonui_decide.png` | "어느 쪽 흔적을 먼저 확인할까?" 두 갈래 · 왼쪽 위 기록 둘 | 읽힘 |
| 3 | `03_wine_work.png` | 술독을 진 플레이어 · 빈 수레 · 상인 · 기록 알림(물목 · 다른 수 · 적어 둔 것) | 읽힘 |
| 4 | `04_rice_work.png` | 박가네 대문 앞, 가마니 하나를 진 플레이어 · 포졸 · 수레 · 기록(징발 표 · 대문 앞 가마니 · 표보다 많은 가마니) | 읽힘(처음엔 카드가 가마니를 덮어서 → 진 뒤에 찍음) |
| 5 | `05_petition_work.png` | 카드 "열리지 않은 소지" · 형방 소지함 · 노인 사연 기록 | 읽힘. 담·지붕 가림 처리로 화면이 조금 어지럽다 |
| 6 | `06_beggar_return.png` | 14A 남문 밖 어깨 너머, 노을 길 끝에 거지 몽룡 | 읽힘. 몽룡이 작다(어깨 너머 원칙 — 손대지 않음) |
| 7 | `07_jail_reunion.png` | 12A 옥 — 창살 안 춘향, 거지 몽룡 | 읽힘(어두움은 밤) |
| 8 | `08_feast_general.png` | 잔치 낮은 틀(SPREAD) — 변학도 교의 · 기생 · 손님 · 시중 | 읽히지만 **편 차일이 반투명 막으로 화면 전체를 덮어 흐리다**(§25-1) |
| 9 | `09_17A_poem.png` | 서안 위 종이 · 시 둘째 줄 자막 | 읽힘(시험 화면 검토가 자막을 짧게 지워서 시험이 둘째 줄을 다시 띄워 찍음 — 실제 놀이는 3.2초씩 뜬다) |
| 10 | `10_18A_before.png` | 변학도 등 뒤 → 내삼문·외삼문 축, 역졸 · 거지 몽룡 · 기생 | 읽힘(고침 — 아래 참고) · 위쪽 분합문 띠 남음 |
| 11 | `11_18A_after.png` | 같은 구도 — 몽룡 마패, 기생 절, 변학도 웅크림(아래 가운데) | 읽힘(고침) |
| 12 | `12_restoration.png` | 바깥마당 물자 곳 — 어사 측 서리 · 술값 받는 김가 · 고개 숙인 박가 · 노인 | 잘 읽힘 |
| 13 | `13_release.png` | 옥문 앞 — 옥을 나온 춘향과 몽룡("왔으니 됐습니다." 직후) | 읽힘. 두 사람이 화면 오른쪽 아래로 크게 걸려 옥문이 왼쪽에 남는다 |
| + | `17_extra_last_choice.png` | 마지막 선택 — 플레이어 어깨 너머 춘향·몽룡·월매 | 읽힘(얕은 초점 흐림) |
| 14 | `14_gwanghallu_end.png` | 광한루 — 빈 그네 · 버드나무 밑 아이 둘 | 읽힘(고침) |
| + | `15_extra_ledger_side.png` | 곁일 — 카드 "세 가마의 차이" · 가마니 · 창고지기 | 읽힘 |
| + | `16_extra_walk_feast_furled.png` | 잔치 평소 시점(조작) — 차일 FURLED, 마당·플레이어 보임 | 읽힘 |

**고친 것(실제 문제만)**:
- 11 출두 뒤: 웅크린 변학도가 **틀 밖으로 빠졌다**(모자 끝 몇 픽셀). → `CAM_18A`·배치 파일 `18A` look y 1.8 → −0.6(조금 숙임, pos·fov 그대로 — 출두 전/후 같은 구도 유지). 위 분합문 띠도 화면 위로 약 70px 올라갔다.
- 10 출두 전: 숙이자 변학도 그림이 **카메라를 마주 보는 얼굴**로 보였다(그림 방향은 세상 기준 — 아래를 보면 남쪽 카메라 쪽 얼굴). → 18A 컷 동안만 `face_actor("byeon_feast","up")`, 컷 뒤 "down"으로 되돌림.
- 14 광한루: 그네(ti_swing −3330)가 **틀 밖**(초점 −3318, 반폭 약 11m). → `CAM_END` focus (−3318, 442) → (−3326, 442.5).
- 4 쌀: 카드가 가마니를 덮어 → 시험 컷을 '진 뒤'로. 9 시: 시험 자막만 다시 띄움(연출 코드 그대로).
- 공식 카메라는 이 둘(18A·END) 말고 손대지 않았다.

## 25. 에이전트 2의 §17 열린 항목 — 판정

1. **차일 FURLED(조작 시점 경계)**: 그대로 둔다. `16_extra_walk_feast_furled`는 마당·플레이어·사령 줄이 다 보인다. 반대로 SPREAD인 `08_feast_general`은 천이 반투명 막으로 화면 전체를 덮어 흐리다 — 조작 시점에서 SPREAD였다면 더 나빴을 것. C62의 '평소 잔치 놀이 SPREAD'와 다르지만, 컷 경계에서만 바뀌고 천 애니메이션이 없으니 규칙의 뜻(갑자기 바뀌지 않음)은 지킨다. 낮은 잔치 틀의 반투명 막은 차일 가림 처리(아랫면 occluder) 쪽 후속(§32).
2. **18A 분합문 검은 띠**: 반만 고침 — 숙여서 위로 올렸다(§24). 여전히 외삼문 지붕 높이에 띠가 걸린다. 들어 올린 분합문은 동헌 건물 모형의 일부라 이 컷에서만 숨기려면 건물 키트를 손대야 하고, 더 숙이면 변학도가 화면 가운데를 가린다. 대청 안 상인방처럼 읽히는 정도라 여기서 멈춤.
3. **`chuldu_cry` 임시 소리**: 화면으로는 판단할 수 없다(합성 모음 띠). 말은 자막 "암행어사 출두야!"가 맡으므로 읽기에는 문제없음. 실제 녹음으로 바꿔야 한다(§28). `hoofbeats`·`bgm_feast`도 임시.

## 26. FIXED_BEAT · 저장/불러오기(최종 확인)

- FIXED_BEAT 순서 `mongryong_return → wolmae_reunion → jail_reunion → birthday_feast → poem → royal_inspector → byeon_dismissed → restoration → release → last_choice`가 iib1·2·3 모두 같고 중복 없음. 곁일을 마친 뒤에도 `beat_order`·OUTCOME RELEASED·COMPLETE·기록책 끝 줄이 그대로(시험).
- 저장/불러오기: 문제 계약이 맡는다(§11). 곁일은 activity_test F에서 장부 본 뒤 · 결정(뒤 곳간) 뒤 저장 → 다시 읽기: 본 것 다시 안 섬 · 결정 유지 · 다시 안 물음 · fail_forward 자리 그대로.

## 27. 조작(§25)

ACT 13 조작 비율 76.4% · II-B 전체 66.4%(§13, 에이전트 2 측정). 곁일은 걸어가 E 셋 + 카드 넷 + 고르기 한 번(조작을 빼앗는 컷 없음).

## 28. 새 기술 부채(셋 합쳐서 — §17에 더해)

1. **곁일이 결말 직후에만 열림**: `case_registry.choose()`가 둘 다 끝난 남원에서 첫 사건(오누이)을 고른다(§20).
2. **카드가 북쪽 대상을 덮음**: 조사 카드(화면 위 가운데 1/3)가 E로 마주 본 대상(플레이어 바로 위)을 가린다 — 쌀 가마니 컷. 공통 UI(C64)라 손대지 않음.
3. **거꾸로 선 컷 카메라의 그림 방향**: 인물 그림은 세상 기준 facing이라, 남쪽을 보는 18A에서는 카메라를 마주 선 역졸·사령이 뒷모습(어두운 머리)으로 보인다. 변학도만 컷 동안 돌렸다. 카메라 기준 facing은 공통 렌더 쪽 일.
4. **SPREAD 차일 반투명 막**(§25-1) · **18A 분합문 띠**(§25-2).
5. **임시 소리**: `chuldu_cry` · `hoofbeats` · `bgm_feast` · `cup_clink` · `brush_stroke`.
6. **시험 화면 검토 모드는 자막을 짧게 지운다**(`auto_real=false`) — 17A처럼 자막이 핵심인 컷은 시험이 다시 띄워 찍었다. 다른 컷도 같은 현상이 있을 수 있다(그림 확인용으로는 문제없음).
7. 시험 봇은 순간이동 — 실제 걸음은 `iibctl`(충돌 무시 직선)만. 박가네·뒤 곳간까지 실제 길은 플레이로 확인 필요.

## 29. 다음 설화에서 그대로 쓸 수 있는 것

- `problems.gd` 계약 전체(활동 넷 · decide `after/needs` · fail_forward · result) — 곁일이 **데이터 파일 하나 + 잇기 4줄**로 된다는 것을 보였다.
- 검사기 `validate_problems`(계약 · 사건 id 하드코딩 · 한 번만 · 저장/불러오기)와 activity_test의 F 꼴(실제 사건 데이터를 가짜 연출로 돌리기).
- 본 것/들은 것/추정 구분(◆/◇ by/△)과 대사 말씨("보았습니다"/"들었습니다").
- "일하는 손"(지고 가기·내려놓기)은 사건 objects + `has(item)` 조건으로 — 계약 밖이지만 같은 꼴로 복사 가능.
- 행동 깃발 → 복구/기억 갈래(합산 없음) 패턴.

## 30. 아직 만들지 않은 것 — Role · Reputation · Authority(상위 문서 §5)

- **ROLE**: 직업·역할 상태 없음. 씨앗은 사건 안 자리(II-A 잡역 목패, 곁일의 '글 아는 사람' 부탁)뿐.
- **REPUTATION**: 숫자·고을별 평판 없음. 씨앗은 행동 깃발(`wine_recorded` · `rice_reasked` · `petition_processed` · `ledger_noted` · `restraint_*`).
- **AUTHORITY**: 문서 열람·명령 권한 없음. 곁일도 "어사 쪽 부탁"이라는 말로만 열린다(권한 체크 없음).
- **RELATION**: 수치 없음 — 춘향의 포승 기억처럼 인물별 깃발만.
- 관직·과거·경제·보상·숙련도 UI 없음(§3 그대로).

## 31. §29 성공 기준 — 화면과 흐름으로 본 정직한 평가

1. **오누이 "표시를 따라간 것이 아니라 주변을 보고 위험을 알아냈다"** — **반쯤**. 카드 글은 정답(범·방향)을 말하지 않고 본 것만 쓴다(진흙 자국 · 눌린 풀 · 높은 털 · 겹친 자국) — 이 부분은 기준에 맞다. 다만 관찰 자리가 E 표시·먹점이 있는 조사 대상이고 길에서 2~3m 안이라, 플레이어는 "표시를 찾아 누른다". 판단도 두 갈래 중 하나(틀려도 같은 결과)라 쉽다. 튜토리얼로서는 적당하지만 "내가 알아냈다"는 감각은 약하다 → 후속: 먹점 반경을 줄이거나 하나는 표시 없이(§32).
2. **춘향 "내가 그 관아에서 일하면서 어떻게 빼앗는지 직접 봤다"** — **대체로 그렇다**. 세 일 모두 문서(물목·징발 표·방)와 실물(독 셋·가마니 넷·열흘째 소지)을 직접 보고, 플레이어가 **자기 손으로** 독·가마니를 지고 관아로 나른다(03·04 화면). 잔치에서 내가 나른 술독이 상 곁에 다시 보인다. 약점: 비교 카드 글이 "값을 치른다는 말은 아무도 하지 않는다" · "'내일 와'는 일을 미루는 말이었다"처럼 결론을 꽤 말해 준다 — 설명을 듣는 쪽에 조금 기운다.
3. **"작은 행동은 결말을 바꾸지 않았지만, 누군가의 피해와 나에 대한 기억은 바꿨다"** — **그렇다**(흐름으로 확인). 세 갈래 모두 출두·파면·석방·결말이 같고(시험), 복구 장면(12 화면)에 서는 사람이 갈래마다 다르며(iib1 확답 없음 / iib2 술값·쌀 반환·재조사 / iib3 한 독만·두 가마 남음), 춘향의 마지막 말과 기록책 끝 줄이 포승·기록 행동을 그대로 되짚는다. 약점: 복구가 한 장면의 자막·서 있는 사람으로만 보여서 무게가 가볍다.

## 32. 후속 후보(이번에 하지 않음 — §28 범위 통제)

1. 끝난 사건의 곁일을 다시 여는 방법(`choose()`가 '곁일이 남은 끝난 사건'을 고르게 — 공통 코드, 사용자 결정 필요).
2. 오누이 관찰 하나를 표시 없이(먹점 없음, 가까이 가야 E) — "표시를 따라간다" 줄이기.
3. 비교 카드 글을 한 걸음 덜 말하게(결론 문장을 빼고 숫자만).
4. 차일 아랫면 가림(occluder) 처리 → C62 원래대로 평소 잔치 놀이 SPREAD.
5. 18A 분합문 — 동헌 키트에 '들어 올린 분합문' 숨김 파라미터.
6. 카메라 기준 인물 그림 방향(거꾸로 선 컷).
7. 조사 카드 위치를 대상과 겹치지 않게(공통 UI, C64 범위 안에서).
8. `chuldu_cry` 등 실제 녹음.
9. 복구 장면에 직접 걸어가 한 사람씩 말 걸기(지금은 서 있기만).
10. 곁일을 남원 밖 관아(다른 고을)에 하나 더 — 같은 계약 두 번째 재사용.

## 33. 사람이 직접 해 볼 것

`godot --path seolhwa_godot -- --savefile=user://play_chunhyang3.json` → 이어 하기(II-A 끝, 관아 앞 30m — 에이전트 2 §16).
- 관아 앞으로 걸어가 아전 → 술·쌀·상소를 아무 순서로. 카드·고르기가 길게 느껴지는지, 박가네까지 실제 길로 갈 만한지.
- 가마니를 진 채 저장 → 불러오기 → 진 것이 그대로인지.
- 잔치: 평소 시점 FURLED가 어색한지, 낮은 틀 SPREAD의 반투명 막이 거슬리는지.
- 출두: 18A 위 분합문 띠 · 역졸이 뒷모습으로 보이는 것 · `chuldu_cry` 소리.
- 광한루 결말 직후(떠나기 전) 관아 바깥마당 동쪽 → 창고지기 · 장부 · 가마니 → "장부를 어떻게 할까?"(곁일). 다시 불러오면 사라진다는 것도 확인(§20 한계).
