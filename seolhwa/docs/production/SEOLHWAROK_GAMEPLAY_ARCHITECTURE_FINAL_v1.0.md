# 설화록 — 게임플레이 구조 최종 v1.0

> 상태: 확정(2026-10-11, 사용자 지시 `BRIEF_gameplay_architecture_first_pass.md` §1·§2·§3·§5·§6·§11·§22)
> 위상: 방향 문서 `seolhwarok_DIRECTION_v3.0_tale_intervention.md`(설화 개입형·공통 규칙 5개) 위에서, **플레이어가 설화 안에서 무엇을 하는가**를 정한다.
> 제작 규칙 `CITY_ROUTE_PRODUCTION_RULES_v1.0.md`(C01~C66)를 깨지 않는다. 이 문서가 새로 만드는 공통 코드는 §7의 얇은 계약 하나뿐이다.

---

## 1. 바뀌지 않는 네 문장

1. **설화록은 설화를 따라가기만 하는 게임이 아니다.** 설화 속 세계를 관찰하고, 이해하고, 그 안에서 자기 일을 하는 게임이다.
2. **설화의 주인공은 원작 인물이다.** 플레이어는 원작 인물의 핵심 선택과 행동을 빼앗지 않는다. (DIRECTION v3.0 공통 규칙 3과 같다.)
3. **설화 하나를 끝내면 이야기만 소비되는 것이 아니다.** 플레이어가 세상에서 할 수 있는 행동과 맡을 수 있는 책임이 쌓일 수 있다.
4. **초반에는 일을 받고, 중반에는 문제를 해결하고, 후반에는 판단과 책임을 맡는다.**

## 2. 기본 문법 — OBSERVE → CONNECT → DECIDE → ACT → RESULT

| 단계 | 플레이어가 하는 것 | 게임에서는 |
|---|---|---|
| OBSERVE 본다 | 현장에 가서 직접 본다 · 사람에게 직접 묻는다 | E 살펴보기(조사 대상) · 인물 대화. 별도 '관찰 모드' 없음 |
| CONNECT 잇는다 | 본 것·들은 것 몇 가지를 나란히 놓는다 | 기록책에 쌓인 기록 · 비교/연결이 열리는 순간의 짧은 한 줄 |
| DECIDE 정한다 | 어떻게 할지 고른다 | 고르기 창 한 번(최소) |
| ACT 한다 | 직접 가져가고, 남기고, 막아선다 | 이동·물건·자리·싸움(그 설화에 있으면) |
| RESULT 남는다 | 결과가 기억된다 | 구체적 행동 깃발 → 주변 결과·대사·결말 카드에서 다시 쓴다 |

- **다섯 단계를 모든 설화에 같은 비율로 억지로 넣지 않는다.** 오누이는 OBSERVE·ACT가 크고 DECIDE는 한 번뿐이다. 춘향 II-B는 OBSERVE·CONNECT·DECIDE가 관아 업무 안에 고르게 든다. 다른 설화는 ACT 하나가 거의 전부일 수도 있다.
- 문법은 **설계 점검표**다. 화면에 단계 이름이나 진행 막대를 띄우지 않는다.

## 3. 성장 3단계

| 단계 | 이름 | 플레이어의 자리 | 대표 |
|---|---|---|---|
| Stage 1 | **길손** | 일을 받는다. 시키는 일·부탁받은 일을 하면서 세상을 본다 | 남원 오누이(서사형 튜토리얼) · 춘향 PART I·II-A |
| Stage 2 | **해결사** | 문제를 푼다. 여러 기록을 이어 어떻게 할지 스스로 정한다 | 춘향 II-B 술·쌀·상소(첫 Problem) · 이후 관아·고을 일거리 |
| Stage 3 | **책임자 / 공적 역할** | 판단과 책임을 맡는다. 결정이 다른 사람의 삶에 공식적으로 닿는다 | (미래) — 지금은 만들지 않는다 |

- 단계는 **숫자 레벨이 아니다.** 어떤 일을 맡게 되는지(내용)로만 드러난다. 단계 UI·직업 이름표·숙련도 막대를 만들지 않는다.
- 한 설화 안에서도 자리는 바뀔 수 있다(구경꾼 → 손님 → 동원된 사령 — DIRECTION v3.0 §3.2). 단계는 설화를 지날수록 **열리는 일의 종류**다.

## 4. 모듈

| 모듈 | 하는 일 | 지금 코드 |
|---|---|---|
| **STORY** | 원작 장면(FIXED_BEATS)·국면·결말. 원작 인물이 핵심 행동을 한다 | `scripts/story/story_runner.gd`(이야기 명령) · `story_director.gd` · `story/<사건>/<사건>_data.gd`·`_case.gd` |
| **ACTIVITY** | 플레이어가 손으로 하는 작은 일 하나 — 본다·비교한다·잇는다·정한다 | `scripts/story/problems.gd`의 활동 type 넷(§7) |
| **PROBLEM** | 여러 Activity와 결과를 한 문제로 묶는다. 틀려도 막히지 않는다(Fail Forward) | `scripts/story/problems.gd`(§7) |
| **PROGRESSION** | 설화를 지나며 쌓이는 것 | 지금은 `CASE_*_COMPLETE`·숙련(`skills.gd`)·흔적 변수뿐 — §5 |

- STORY가 등뼈다. **ACTIVITY/PROBLEM은 FIXED_BEAT·국면·결말을 움직이지 않는다**(§7 계약이 막는다). FIXED_BEAT는 Activity 성공 여부와 무관하게 일어난다.
- Activity/Problem이 바꾸는 것: 주변 피해·복구, 기록책, 대사, 결말 카드의 몇 줄, 나에 대한 기억.

## 5. PROGRESSION — 넷으로 나눠 둔다(미래 구조만, 이번에 구현하지 않음)

| 개념 | 뜻 | 섞지 말 것 | 지금 있는 씨앗 |
|---|---|---|---|
| **ROLE** 역할 | 지금 맡은 일(사령·서리·창고지기·길잡이…) — 설화마다 바뀔 수 있다 | 직업 시스템·직업 레벨 | 사건 안 자리(춘향 II-A 잡역 목패) |
| **REPUTATION** 평판 | 어느 고을·어느 무리가 나를 어떻게 기억하나 — 고을마다 따로, 사건 깃발에서 읽는다 | 하나의 숫자 · 선악 점수 | 사건 깃발(`wine_recorded`·`restraint_loose` 등) · 다른 고을 소문 |
| **AUTHORITY** 권한 | 내가 공식적으로 할 수 있는 것(문서 열람·명령·판결 곁) | 관직 승진·과거시험 | `SKILL_DOCUMENT_CHECK` 같은 할 수 있는 일 |
| **RELATION** 관계 | 특정 인물과의 관계(춘향·방자·포수…) — 그 인물이 무엇을 기억하나 | 호감도 수치·연애 | 인물별 깃발(춘향의 포승 기억) |

- 넷 다 **이번에는 만들지 않는다.** 지금 하는 것은 깃발 이름을 구체적 행동으로 남기는 것(§18 — 합산 금지)뿐이다. 나중에 이 넷이 필요해지면 그 깃발들을 읽어서 만든다.
- 데이터를 미리 만들어 두지 않는다(빈 표·빈 UI 금지).

## 6. 만들지 않는 것(§3)

전체 직업 시스템 · 관직 승진 · 과거시험 · 평판 시스템 전체 · 도덕성 수치 · 경제 시뮬레이션 · NPC 생활 AI 확대 ·
대규모 퍼즐 프레임워크 · 별도 '관찰 모드' · 레이튼식 전용 퍼즐 화면 여러 종 · 춘향 II-A 재작성 · 춘향 구출 분기 · 변학도 암살 ·
플레이어가 몽룡을 암행어사로 만드는 구조 · 플레이어의 증거가 어사출두를 일으키는 구조.

- 공통 코드는 **실제로 두 개 이상 콘텐츠에서 다시 쓰일 최소 계약**만 둔다. 이번 공통 코드는 §7의 `problems.gd` 하나(오누이 §4와 춘향 II-B에서 쓴다).
- 조작을 빼앗지 않는다. 대화·고르기 창이 길어져 '읽는 게임'이 되지 않게: 현장 이동·물건 직접 확인·사람에게 직접 묻기·필요한 곳에 직접 가져가기를 그대로 둔다. 별도 UI는 정보 연결·최종 판단 때만, 기존 고르기 창으로.

## 7. 기록 정보의 성격(§6)

| 성격 | 기록책 꼬리표 | 데이터 | 규칙 |
|---|---|---|---|
| **본 것** | ◆ 확인 | `clues.<id>.kind = "fact"` | 직접 본 사실만. 해석은 한 걸음까지("큰 자국이 나중에 생겼다") |
| **들은 것** | ◇ 들음 — 말한 사람 | `kind = "heard"`, `by` **필수** | 사실로 올리지 않는다. 누가 말했는지 반드시 |
| **추정** | △ 추정 | `kind = "guess"`(규칙 `rules`도 기본 guess) | "~인 것 같다". 정답으로 확정하지 않는다 |
| **확인** | ◆ 확인 / 사건 깃발 | `kind = "fact"` 또는 깃발 하나(`wine_discrepancy_seen`) | 비교로 확인한 것. 얇게 — 기록책을 갈아엎지 않는다 |

- 기록책(`journal_book.gd`)은 이미 fact/heard(by)/guess를 구분한다. 이번에 기록책을 리팩터링하지 않는다. 추론·확인은 기록 한 줄(guess/fact)이나 사건 깃발로 둔다.
- 대사에서도 구분한다: "쌀을 더 가져간 것을 **보았습니다**." / "소를 가져갔다고 **들었습니다**."

## 8. "증거 조합 퍼즐 없음"의 뜻(§11)

춘향 시나리오 v1.1의 "증거 조합 퍼즐 — 없음"은 **지우지도 뒤집지도 않는다.** 뜻은 이렇다.

- **없다**: 변학도를 무너뜨리거나 어사출두를 일으키려고 증거를 모아 조합하는 퍼즐. 범인을 밝히는 추리. 플레이어의 기록이 결정적 증거가 되는 구조.
- **있다**: 관아 일을 하며 장부·물자·주민의 말을 보고, 이해하고, 처리하는 문제해결(Activity/Problem).
- II-B의 Activity는 범인을 밝히는 증거 퍼즐이 아니다. 플레이어는 처음부터 무엇이 부당한지 안다. 문제는 **그 구조 안에서 무엇을 보았고, 어떻게 행동했는가**다.
- 플레이어의 기록은 몽룡의 성공 조건이 아니라 **주변 피해 복구**에 쓰인다(시나리오 ACT 19).

---

## 9. Activity/Problem 최소 계약(§5·§22 — `seolhwa_godot/scripts/story/problems.gd`)

### 9.1 먼저 조사한 기존 시스템과 다시 쓰는 것

| 기존 | 다시 쓰는 방법 |
|---|---|
| `story_runner` 이야기 명령(flag · clue · examine · choice · if · caption · give/take · discover) | 문제 데이터를 **이 명령들로 바꿔 넣는다** — 새 실행기 없음. 명령 하나(`activity`)와 조건 함수 넷(`pa·pd·pn·pdone`)만 더함 |
| `story_director` 조사 대상(`objects` — at·radius·label·when·steps, E 'n 살펴보기', 먹점 mark_r) | 본 것(seen) 활동마다 조사 대상 하나를 만든다 — E·먹점·안내 그대로 |
| `story_director` 자리 트리거(`triggers` — at·radius·once·when) | 결정(decide)을 '불러온 뒤 다시 묻는 자리' 하나로만 |
| 기록(`clues` kind fact/heard/guess, `by`) · 기록책 | 활동의 `record`가 기록이 된다(seen→fact, heard→heard+by, compare/connect→guess|fact) |
| 사건 깃발(`S.flags` = progress `cases.<id>.flags`) | 활동 완료·결정·결과가 모두 사건 namespace 깃발. 공통 시스템이 상태를 따로 복제하지 않는다 |
| 인물 대화(`actors[].talk` 조건 묶음) | 들은 것(heard)은 그 인물 talk 안에 `{ "activity": "문제.활동" }` 한 줄 |
| 지도 들음(`discover`) · 물건(`give/take`) | 결과 단계에서 그대로 |
| 사건 데이터 로드(`case_registry.load_data`) | 여기서 `Problems.expand(data)`를 한 번 — 모든 소비처(연출·기록책·검사기)가 같은 결과를 본다 |

### 9.2 데이터(사건 `<id>_data.gd`의 `"problems"`)

```gdscript
"problems": {
  "<문제 id>": {
    "title": "제작자용 이름",
    "when": "조건식(선택 — 모든 활동에 AND)",
    "activities": [
      # inspect — 본 것(E 살펴보기 대상이 생긴다)
      { "id": "a", "type": "inspect", "kind": "seen", "at": "앵커", "label": "… · 살펴보기", "text": ["카드 글"],
        "record": { "title": "기록 제목", "text": "기록 글" }, "required": true, "do": [단계…] },
      # inspect — 들은 것(인물 talk 안에 { "activity": "<문제>.b" })
      { "id": "b", "type": "inspect", "kind": "heard", "actor": "인물 id", "by": "말한 사람", "record": { … } },
      # compare / connect — needs가 다 끝나면 같은 흐름 안에서 저절로
      { "id": "c", "type": "compare", "needs": ["a", "b"], "text": ["…"], "record": { …, "kind": "fact" | "guess" }, "flags": ["사건_깃발"] },
      # decide — needs 또는 after n(from 목록 중 n개; from 기본 = 앞에 적힌 inspect)
      { "id": "d", "type": "decide", "after": 2, "at": "앵커(선택)", "radius": 30, "prompt": "물음",
        "options": [ { "id": "x", "label": "…", "when": "조건(선택)", "flags": [...], "record": {…}, "do": [...] },
                     { "id": "y", "label": "…", "fail_forward": "z" } ] },
    ],
    "fail_forward": { "z": { "at": "앵커", "label": "…", "text": ["잘못 짚은 자리"], "extra": { "text": [...], "record": {…} }, "do": [...] } },
    "result": { "flags": ["사건_깃발"], "do": [단계…] },
  }
}
```

- 활동 type은 **inspect · compare · connect · decide 넷뿐**이다. classify 등은 필요해질 때까지 만들지 않는다.
- `required`(기본 true)는 결정이 없는 문제에서만 쓴다 — required가 다 끝나면 풀린다. 결정이 있는 문제는 결정(또는 fail_forward 자리)으로 풀린다.
- 문제가 풀리면 `result`가 **한 번** 돈다.

### 9.3 상태(사건 namespace)

| 깃발 | 뜻 |
|---|---|
| `pb.<문제>.<활동>` = true | 활동을 마침 |
| `pb.<문제>.decision` = "갈래 id" | 고른 갈래(빈 값 = 아직) |
| `pb.<문제>.ff.<자리>` = true | fail_forward 자리를 봄 |
| `pb.<문제>.done` = true | 문제가 풀림(result가 돌았다) |
| `result.flags`·`options[].flags`·`activities[].flags` | **구체적 행동 깃발**(접두사 없이 사건 이름 — `wine_recorded`, `beast_way_read`) — 결말·복구가 읽는다 |

조건식(`story_runner`): `pa('문제','활동')` · `pd('문제')` · `pn('문제','a,b')` · `pdone('문제')`. 기록 id: `pb_<문제>_<활동>` · `pb_<문제>_<결정>_<갈래>` · `pb_<문제>_ff_<자리>`.

### 9.4 지키는 것

- **공통 코드에 `if case == …` 없음.** `problems.gd`에는 사건 id·사건 변수 글자가 없다(검사기가 글을 훑는다).
- **한 번만**: 만든 단계마다 첫 단계가 '아직 안 했으면' 조건, 그 안 첫 단계가 완료 깃발 — 두 번 불러도 기록·물건·카드·결과가 늘지 않는다.
- **저장/불러오기**: 완료한 관찰은 다시 서지 않고(대상 when), 처리한 물건은 되돌리지 않고(give/take는 한 번), 결정 깃발은 남고(다시 묻는 트리거 when), FIXED_BEAT는 문제 단계에 들어갈 수 없다(`event`·`phase`·`outcome`·`ending` 금지 — 검사기). 결정 전에 끊긴 저장은 결정 자리에 들면 다시 묻는다.
- 조작을 빼앗지 않는다: 관찰은 E 한 번 + 카드 한 장, 결정은 고르기 창 한 번. 관찰 모드·전용 퍼즐 화면 없음.

### 9.5 검사·시험

- `tools/story/validate_problems.gd` — 등록된 모든 사건: 계약(type·앵커·인물·by·talk 연결·needs/from/fail_forward·없는 활동 부름·금지 단계) · 공통 코드 사건 id 글자 · 한 번만 막음 · 저장/불러오기 → `PROBLEMS PASS`.
- `tests/activity/activity_test.gd` — 가짜 '창고 장부 대조' 문제로 계약·하드코딩·실제 실행(StoryRunner)·한 번만·Fail Forward·저장/불러오기 → `ACTIVITYTEST PASS`.

## 10. 첫 두 적용

- **오누이(Stage 1, 서사형 튜토리얼)** — 문제 `beast_way`: 길가 관찰 셋 중 둘 → "어느 쪽 흔적을 먼저 확인할까?" → 서쪽 숲은 헛걸음·추가 흔적 뒤 같은 결과. 보고서 `seolhwa_godot/docs/reports/gameplay-architecture-first-pass.md` §3.
- **춘향 II-B ACT 13(Stage 2의 첫 문제)** — 술·쌀·상소를 같은 계약으로(순서 자유). 보고서 §5(선언 방법).
- **재사용 시연 — 관아 창고 장부 대조(§21)** — 춘향이 끝난 뒤 남원 관아 곁일 하나를 데이터 파일 하나(`story/namwon_chunhyang/namwon_chunhyang_side_data.gd`)로: 본 것 둘 + 들은 것 + 비교 + 결정 + fail_forward. 공통 코드·사건 스크립트 변경 없음. 보고서 §20.
