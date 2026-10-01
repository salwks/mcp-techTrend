# 설화록 — 3단계 사건 프로토타입: 「산길의 실종」

개발계획서 23~24장과 27장 3단계. 마을 하나와 사건 하나로 **탐험 → 사건 발견 → 조사 → 규칙 파악 → 대응 → 해결 → 보상·지역 변화**를 처음부터 끝까지 연결한다.
원작(해와 달이 된 오누이) 제목은 게임 어디에도 쓰지 않는다. 플레이어가 보는 것은 사건뿐이다.
목표 플레이 시간 30~45분. 이야기 중심 — 대사는 짧게 끊고, 장면마다 플레이어가 움직이는 구간을 둔다.

## 1. 사건 개요
- **겉으로 보이는 사건**: 고개 너머 장에 떡을 팔러 간 어미가 사흘째 돌아오지 않는다. 숲 가장자리 외딴집에는 오누이(돌이, 순이)만 남아 있다.
- **실제로 벌어진 일**: 고개의 호랑이가 어미를 해치고, 그 옷과 목소리를 흉내 내 아이들까지 노리고 있다.
- **호랑이의 규칙(계획서 12장)** — 조사로 알아내는 지식:
  - `K_FOOD` 먹이에 집착한다 (고갯길마다 떡이 하나씩 사라졌다, 빈 떡 광주리)
  - `K_MIMIC` 사람 목소리를 흉내 낸다 (나무꾼·포수 증언: 밤에 여자 목소리가 산에서 아이들 이름을 불렀다)
  - `K_FLOUR` 손(앞발)을 밀가루로 희게 칠해 사람 손인 척한다 (방앗간 밀가루 자루가 찢어짐, 흰 발자국)
  - `K_CLIMB` 나무를 탄다 (외딴집 앞 큰 나무의 높은 발톱 자국) / 단, 미끄러운 나무는 오르지 못한다
  - `K_TERRITORY` 고갯마루 너머 빈터가 영역이다 (뼈, 발톱 자국, 포수 증언)
- **사건 기록 제목**: 「산길의 실종」. 끝까지 원작 제목으로 부르지 않는다.

## 2. 진행 (장면 순서)
1. **도착 (낮, 10시)** — 나그네가 마을에 들어선다. 소개 문구 없음. 장승 앞 짧은 문구 한 줄(지명)만.
2. **사건 발견 (여러 경로, 계획서 10장)**: 주막 주모의 소문 / 순덕 어멈 수다 / 포수 막쇠 / 외딴집 오누이에게 직접. 어느 하나라도 들으면 사건 기록 「산길의 실종」 생성.
3. **오누이 만나기** — 외딴집. 순이(누이)는 어른스럽고 돌이(동생)는 겁먹음. "어머니가 떡 팔러 가셨어요… 고개를 넘어서."
4. **산길 조사** — 고갯길 굽이마다 떨어진 떡(3곳), 찢어진 치맛자락, 핏자국, 사람 발자국과 섞인 큰 짐승 발자국, 서낭당 앞 빈 떡 광주리와 어미의 수건. 각각 `조사`하면 단서·지식 획득.
5. **첫 조우 (해질녘 무렵, 산길/영역 근처)** — 호랑이가 숲에서 모습을 드러낸다. 처음에는 강한 적(조사 부족 시 승산 낮음). 싸우거나 도망칠 수 있다. 일정 피해를 주거나 시간이 지나면 호랑이는 "내 영역에서 나가라"는 듯 포효하고 물러난다(죽지 않음). 이 조우로 호랑이의 실체가 확인된다.
6. **마을 추가 조사** — 방앗간(밀가루 도난, 흰 발자국: `K_FLOUR`), 포수 막쇠(흉내·영역: `K_MIMIC`, `K_TERRITORY`), 기름집/끝순이(참기름 얻기), 헛간(낡은 동아줄 — 썩었음을 확인), 외딴집 앞 큰 나무(높은 발톱 자국: `K_CLIMB`). 주막에서 쉬면 **밤이 된다**(주모: "오늘 밤 그 집 애들이 걱정이구먼…").
7. **최종 상황 (밤, 22시)** — 외딴집. 호랑이가 어미의 옷을 걸치고 문을 두드린다: "얘들아, 엄마 왔다. 문 열어라."
   플레이어가 미리 한 준비와 지식에 따라 해결 방식이 열린다(계획서 15장 — 2~3개, 차이를 분명히):
   - **A. 직접 처치**: 마당에서 싸운다(전투 프로토타입 재사용, 싸움터 `house_yard`). 준비 없으면 어렵다.
   - **B. 함정**: (`K_CLIMB` + 참기름) 아이들을 큰 나무 위로 피신시키고 나무 밑동에 참기름을 바른다. 호랑이가 오르다 미끄러져 떨어지면 **기절한 채 전투 시작**(체력 감소, 몇 초 무방비) → 처치 또는 물러나게 함.
   - **C. 물러나게 함**: (`K_MIMIC`+`K_FLOUR`로 아이들에게 "문 열지 마라, 손을 보여 달라 하거라" 경고) + (`K_FOOD`+떡) 떡으로 영역 쪽으로 유인 + (`K_TERRITORY`) 횃불로 영역 밖까지 몰아낸다 → 싸우지 않고 해결. 호랑이는 산으로 돌아간다.
   - 경고를 하지 않았으면 아이들이 문을 열려 한다 → 즉시 마당 전투로 넘어감(아이들은 나무 위로 도망, 아이가 해를 입는 결말은 없음).
8. **결과 (다음 날 아침)** — 지역이 달라진다(계획서 16장):
   - 처치: 마을 잔치 분위기, 포수가 가죽을 탐냄, 산길에 장꾼이 다시 다닌다.
   - 함정: 처치와 같으나 "나무 위 오누이"가 마을의 이야깃거리가 됨.
   - 물러나게 함: 호랑이는 살아 있지만 사람을 해치지 않는다. **밤이면 멀리서 울음소리**가 들린다(밤 시간대 사운드/문구). 서낭당에 떡을 바치는 사람이 생긴다.
   - 공통: 어미의 소식(찢어진 저고리 — 돌아오지 못함)을 오누이에게 전하는 장면. 마을 사람들이 오누이를 거둔다. 사건 기록 완료.
   - 보상(계획서 17장): 돈 약간 + **새 해결 수단** "짐승의 흔적 읽기"(이후 사건에서 발자국 단서가 더 자세히 보임 — 이번엔 기록 문구만).
9. **에필로그 카드** — 사건 기록 최종 문단 + "다시 하기"(사건 처음부터).

## 3. 모듈 계약

### 3.1 story — `src/story/**` (story-dev)
```js
export function createStory(ctx) → Story
ctx = {
  scene, world, camera, rig, fx, hud, ui, input, combat,
  player,                 // Actor
  npcs,                   // { [id]: Actor } — world.npcs 의 id
  makeChar(kind),         // 새 캐릭터(예: 변장 호랑이) 생성
  say(name, lines) → Promise,          // 대화창
  setTime(h), getTime(), fade(ms, toBlack:boolean) → Promise,
  teleport({x,z}), wait(ms) → Promise,
  setWorldState(key, value),           // world.setState 래핑(지역 변화)
}
Story = {
  update(dt),
  busy,                    // 컷신 중이면 true → 코어가 플레이어 조작을 막음
  interactTargets() → [{ id, x, z, radius, label, kind:'npc'|'clue'|'object' }],  // 지금 조사/대화 가능한 대상
  interact(id) → Promise,  // 코어가 '조사' 입력 시 호출
  allowArena(arena) → bool, // 코어의 싸움터 자동 전투 허용 여부(이야기 흐름 중 제어)
  journal(),               // 사건 기록 데이터 { cases:[{ id, title, status, summary:[문단], clues:[{id,title,text}], rules:[{id,title,text}], solutions:[{id,title,available}] }] }
  save(), load(), restart(),
}
```
- 사건 스크립트는 데이터 + 작은 명령 집합(say, choice, give, flag, wait, move actor, face, camera focus, fade, time, spawn/despawn, combat, journal 갱신)으로 작성. 상태는 `flags`, `clues`, `knowledge`, `items`(떡, 참기름, 횃불, 낡은 동아줄).
- NPC 대사는 플래그에 따라 바뀐다(이야기 진행에 맞춰). 세계관 보충은 선택 대화.
- 저장: localStorage(try/catch), 키 `seolhwa_story_v1`.

### 3.2 ui — `src/ui/**` (ui-dev)
```js
export function createUI(root) → UI
ui.toast(text, kind='info'|'clue'|'rule'|'journal')    // 화면 위 한지 띠 알림
await ui.examine({ title, text, kind })                // 조사 카드(한지 카드, 먹 삽화 느낌 테두리) — 확인으로 닫힘
await ui.choice(prompt, [{ label, disabled, hint }])   // → index (키보드 위/아래+확인, 터치)
ui.journalOpen(data) / ui.journalClose() / ui.journalToggle(dataProvider) // 사건 기록 책자 UI
await ui.caption(text, ms)                             // 내레이션 자막(영화 자막처럼 화면 아래 중앙)
ui.letterbox(on)                                       // 컷신 위아래 먹색 띠
await ui.ending({ title, paragraphs, outcome })        // 사건 종결 카드 → '다시 하기'
ui.items(list)                                         // 소지품 작은 표시 [{id,label,count}]
ui.isModal                                             // 모달(조사 카드·선택지·기록) 열림 여부
```
- 조작: 키보드(방향키·확인 E/Space/Enter·취소 Esc/X) + 터치. 사건 기록 열기 **R 키** / 모바일 "기록" 버튼.
- 스타일은 기존 `src/core/ui.css`의 한지·먹·낙관 토큰을 그대로 이어 쓴다(자체 CSS 파일 `src/ui/ui.css`).

### 3.3 world 추가 (env-artist)
```js
world.anchors = { name: {x, z} }        // 이야기가 참조하는 장소(아래 목록)
world.setState(key, value)              // 지역 변화(아래 키), 즉시 보이기/숨기기
world.arenas += { id:'house_yard', ... } // 외딴집 마당 싸움터(기존 arena에도 id:'territory' 부여)
```
- 새 장소: **주막**(마을, 평상·술독·주모 자리), **방앗간**(개울가 물레방아, 찢어진 밀가루 자루, 흰 발자국), **기름집 또는 끝순이네 부엌**(참기름 병), **헛간**(낡은 동아줄), **외딴집 앞 큰 나무**(오를 수 있어 보이는 큰 고목, 높은 발톱 자국).
- 단서 소품(state로 표시/숨김): 산길의 떨어진 떡 3개(`rice_cake_1..3`), 찢어진 치맛자락, 핏자국, 짐승+사람 발자국 길, 서낭당 앞 빈 떡 광주리와 수건, 방앗간 흰 발자국.
- anchors 이름: `inn, mill, oil_shop, barn, big_tree, house_door, house_yard, cake_1, cake_2, cake_3, torn_skirt, blood, tracks, basket, flour_prints, claw_tree, territory_edge, village_gate, tiger_first_seen`.
- setState 키: `oil_on_tree`(나무 밑동 번들거림), `kids_in_tree`(아이들 위치는 story가 옮김—소품 불필요), `cake_bait`(유인용 떡이 놓인 자리 표시), `torch_lit`(마당 횃불), `village_after_win`/`village_after_repel`(잔치 깃발·장꾼·서낭당 떡 공양 등 지역 변화), `clue_taken_<id>`(주운 단서 소품 숨김).
- 마당 싸움터: 외딴집 앞, 지름 약 16m, 큰 나무 포함.

### 3.4 chars 추가 (char-artist)
- 새 종류: `innkeeper`(주모), `miller`(방앗간 주인), `woodcutter`(나무꾼). 기존 오누이·포수 재사용.
- 오누이 동작: `cower`(웅크려 떪), `cry`, `climb`(나무 오르기), `perch`(나무 위 앉음, 반복), `hug`.
- 호랑이: `disguise` 변형(어미 저고리를 어깨에 걸침, 앞발이 하얗다 — `char.setVariant('disguised')`), `knock`(문 두드리기, 반복), `climb_try`, `slip`(미끄러져 떨어짐), `sniff`, `eat`(기존), `retreat`(돌아서 산으로).
- **프레임 방식 확정**: 주인공·호랑이는 프레임 방식이 기본. 해상도를 올린다(메모리 절감 기법 병행).

### 3.5 combat 확장 (combat-dev)
- `combat.start(arena, opts)` — `opts.mods`: `{ stunned: 초, hpRatio, enraged, disguised, firstEncounter: true }`, `opts.retreatAt`(이 체력 비율 또는 시간에 호랑이가 물러남), `opts.allowFlee`.
- 첫 조우 모드: 일정 피해(약 25%) 또는 60초가 지나면 포효 후 영역 쪽으로 물러남 → result `'retreated'`.
- 결과를 `await combat.finished` 형태로 받을 수 있게(또는 `onEnd` 콜백).
- 마당 싸움터에서는 아이들이 있는 나무 쪽으로 호랑이가 향하려는 경향(지키는 느낌).

### 3.6 코어 (총괄)
- 상호작용 라우팅(조사 프롬프트: 가장 가까운 story 대상), 컷신 중 조작 차단, 대화 Promise 래핑, 시간·페이드·순간이동 헬퍼, 싸움터 자동 전투 게이트, R 키·모바일 "기록" 버튼, 스토리 저장/불러오기 연결.
