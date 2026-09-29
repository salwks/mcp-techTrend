# 모듈 계약서 (에이전트 간 인터페이스)

모든 에이전트는 이 문서의 형식과 API를 지킨다. 이 문서를 바꿔야 한다면 직접 고치지 말고
최종 보고에 "계약 변경 요청"으로 적는다. 코드는 순수 ES 모듈(빌드 없음, 외부 라이브러리 없음)이다.
화면의 모든 텍스트는 한국어로 쓴다.

## 0. 파일 소유권

| 경로 | 담당 |
|---|---|
| `index.html`, `src/main.js`, `src/engine/game.js`, `src/engine/input.js`, `src/engine/state.js`, `src/ui/window.js`, `src/data/characters.js` | 총괄(코어) — 읽기 전용 |
| `src/engine/audio.js` | sound-dev |
| `src/field/**` | field-dev |
| `src/data/maps.js`, `src/data/events.js` | world-designer |
| `src/battle/**`, `src/systems/effects.js`, `src/data/skills.js`, `src/data/items.js`, `src/data/enemies.js`, `src/data/troops.js`, `src/data/encounters.js` | battle-dev |
| `src/ui/scenes/**` | ui-dev |

### 씬 클래스 export (src/main.js가 import함 — 경로·이름 고정, 생성자는 `(game, params)`)
- `src/field/FieldScene.js` → `export class FieldScene`
- `src/battle/BattleScene.js` → `export class BattleScene`
- `src/ui/scenes/TitleScene.js`, `MenuScene.js`, `ShopScene.js`, `SaveScene.js`, `GameOverScene.js`, `EndingScene.js` → 같은 이름의 클래스

디버그: 브라우저 콘솔에서 `window.__game`으로 게임 객체에 접근할 수 있다.
로컬 실행: `cd legend_jrpg && python3 -m http.server 8000` → http://localhost:8000

## 1. 엔진 코어 (`src/engine/game.js`)

```js
import { Scene, WIDTH, HEIGHT } from '../engine/game.js'; // WIDTH=640, HEIGHT=480 (논리 좌표)

class MyScene extends Scene {
  constructor(game, params) { super(game, params); this.opaque = true; }
  enter() {}            // 스택에 올라갈 때
  exit() {}             // 스택에서 내려갈 때
  update(dt) {}         // dt: 초. 스택 최상단 씬만 호출됨
  draw(ctx) {}          // 불투명 씬부터 위로 순서대로 그림. opaque=false면 아래 씬도 그려짐
}
// 끝낼 때: this.finish(result)  → runScene()의 Promise가 result로 resolve
```

`game` 객체:
- `game.ctx`, `game.input`, `game.state`(GameState 또는 null), `game.time`(누적 초)
- `game.register(name, (game, params) => new Scene(...))`
- `await game.runScene(name, params)` → 씬을 푸시하고 끝날 때 결과를 돌려준다
- `game.reset(name, params)` → 스택 전체를 버리고 새 씬 하나로 시작한다. 버려진 씬의 Promise는 **영원히 resolve되지 않는다**(대기 중인 이벤트 스크립트가 자연스럽게 멈춤)
- `await game.fadeOut(ms=300)`, `await game.fadeIn(ms=300)`, `await game.wait(ms)`
- `game.flash(color='#fff', ms=200)`, `game.shake(ms=300, power=6)` (연출)

### 등록된 씬 이름과 파라미터

| 이름 | 담당 | params | 결과 |
|---|---|---|---|
| `title` | ui-dev | – | 없음(스스로 `game.reset('field', …)` 호출) |
| `field` | field-dev | `{ mapId?, x?, y?, dir? }` (생략 시 `state.map` 사용) | 없음 |
| `battle` | battle-dev | `{ troop, canEscape=true, bg='plains', bgm }` | `'win' \| 'lose' \| 'escape'` |
| `menu` | ui-dev | – | 없음 |
| `shop` | ui-dev | `{ items: [itemId...], title? }` | 없음 |
| `save` | ui-dev | `{ mode: 'save' \| 'load' }` | 로드 성공 시 `'loaded'`(ui-dev가 `game.reset('field')`까지 처리) |
| `gameover` | ui-dev | – | 없음(스스로 `reset`) |
| `ending` | ui-dev | – | 없음(끝나면 `reset('title')`) |

## 2. 입력 (`src/engine/input.js`)
액션: `up`, `down`, `left`, `right`, `confirm`, `cancel`, `menu`.
- `input.pressed(a)` 이번 프레임에 눌림 / `input.held(a)` 누르고 있음
- `input.repeat(a)` 커서 이동용(누른 순간 + 0.35초 후 0.1초마다 반복)
- 키: 방향키/WASD, 확인 Z·Enter·Space, 취소 X·Backspace, 메뉴 Esc·M·C. 모바일 가상 패드 포함.

## 3. 사운드 (`src/engine/audio.js`) — sound-dev
- `sfx(name)`: `cursor`, `confirm`, `cancel`, `buzzer`, `hit`, `crit`, `miss`, `magic`, `fire`, `ice`, `thunder`, `holy`, `heal`, `levelup`, `encounter`, `escape`, `chest`, `door`, `step`, `item`, `enemy_die`, `victory`
- `playBgm(key)`: `title`, `village`, `town`, `field`, `forest`, `dungeon`, `tower`, `castle`, `battle`, `boss`, `final_boss`, `victory`, `sad`, `ending`. 같은 키면 이어서 재생.
- `stopBgm()`, `unlockAudio()`(첫 사용자 입력에서 코어가 호출). 알 수 없는 키는 무시(에러 금지).

## 4. 게임 상태 (`src/engine/state.js`)
```js
state.party                 // ['ren','mia',...] 합류 순서
state.members[id]           // { id, level, exp, hp, mp, equip:{weapon,armor,accessory}, status:[] }
state.inventory             // { itemId: count }
state.gold, state.flags, state.map // {id,x,y,dir}
state.addMember(id, level?) ; state.hasMember(id)
state.partyMembers()        // 멤버 객체 배열
state.getStats(id)          // { maxHp, maxMp, atk, def, mag, spd }  (기본+성장+장비)
state.knownSkills(id)       // 습득한 스킬 ID 배열
state.gainExp(id, n)        // → [{ level, skills:[새 스킬 ID] }] 레벨업 목록
state.expForLevel(L), state.expToNext(id)
state.isAlive(id), state.fullHeal(), state.aliveMembers()
state.addItem(id,n=1), state.removeItem(id,n=1), state.itemCount(id)
state.canEquip(memberId,itemId), state.equip(memberId,itemId) /* 이전 장비는 가방으로 */, state.unequip(memberId, slot)
state.setFlag(k,v=true), state.getFlag(k)
state.serialize() ; GameState.deserialize(obj) ; GameState.newGame()
// 세이브: saveSlot(n,state), loadSlot(n) → GameState|null, listSlots() → [{slot, summary|null}]
```
멤버의 `status` 배열은 전투 후에도 남는 상태이상(`poison`)만 저장한다. 전투 중 버프/수면/기절은 battle 내부에서만 관리한다.

## 5. UI 공용 (`src/ui/window.js`)
- `FONT(size=18, bold=false)`, `COLORS`
- `drawWindow(ctx,x,y,w,h)`, `drawText(ctx,text,x,y,{size,color,align,bold,shadow})`, `wrapText(ctx,text,maxW,size)`
- `drawGauge(ctx,x,y,w,h,ratio,color)`, `drawCursor(ctx,x,y,t)`
- `new MessageWindow()` → `await msg.show(text, speaker?)`; 씬의 update/draw에서 `msg.update(dt, input)`, `msg.draw(ctx)` 호출. `msg.active`
- `new ChoiceList(items, {x,y,w,cols,cancelable})` → `update(input)`: 확정하면 인덱스, 취소하면 -1, 그 외 null. `draw(ctx)`. items: `{label, disabled?, right?}` 또는 문자열

## 6. 캐릭터 데이터 (`src/data/characters.js`, 코어)
```js
CHARACTERS.ren = { name, role, base:{hp,mp,atk,def,mag,spd}, growth:{...}, learnset:[{level, skill}], startEquip:{weapon,armor,accessory}, color }
```

## 7. 아이템·스킬·적 데이터 — battle-dev
```js
ITEMS.potion = {
  name:'회복약', desc:'HP를 80 회복한다', price:40,
  type:'consumable' | 'weapon' | 'armor' | 'accessory' | 'key',
  // consumable
  effect:{ kind:'heal'|'mp'|'cure'|'revive'|'damage'|'healAll', amount?, status?, element? },
  target:'ally'|'allAllies'|'enemy'|'allEnemies', usable:'both'|'battle'|'field',
  // equipment
  bonus:{ atk?, def?, mag?, spd?, maxHp?, maxMp? }, equipBy:['ren', ...], guard?:['poison','sleep']
}
SKILLS.heal = { name, desc, mp, kind:'physical'|'magic'|'heal'|'revive'|'cure'|'buff'|'debuff',
  power, element?, target:'enemy'|'allEnemies'|'ally'|'allAllies'|'self', field:true|false, status?, buff? }
ENEMIES.slime = { name, hp, mp, atk, def, mag, spd, exp, gold, drops:[{item,rate}], skills:[...], weak:[], resist:[], sprite:'slime', boss? }
TROOPS.boss_lich = { enemies:['lich','skeleton','skeleton'], boss:true, bgm:'boss' }
ENCOUNTERS.forest = { rate: 0.06, troops:[{ troop:'troop_forest_1', weight:3 }, ...] } // rate = 걸음당 확률
```
`src/systems/effects.js`:
```js
useItemInField(state, itemId, targetId|null) // → { ok:boolean, message:string }  (대상 전원형은 targetId 무시)
castSkillInField(state, casterId, skillId, targetId|null) // → { ok, message }  (MP 소모 포함)
canUseItemInField(itemId), canCastInField(skillId)
```

## 8. 맵 데이터 — world-designer (`src/data/maps.js`)
```js
MAPS.village = {
  name:'루멘 마을', bgm:'village', battleBg:'village',
  encounter: null | 'forest',          // ENCOUNTERS 키
  dark: false,                          // true면 필드 담당이 어둡게 연출(동굴 등)
  tiles: [ '############', '#....,,....#', ... ], // 모든 행 길이가 같아야 함
  npcs: [ { id:'elder', x, y, sprite:'elder', name:'오웬 장로', dir:'down', wander:false,
            event:'evt_elder' /* 또는 */ , lines:['대사1','대사2'],
            showIf:'flag' , hideIf:'flag' } ],
  triggers: [ { x, y, w:1, h:1, event:'evt_x', showIf?, hideIf? } ], // 밟으면 실행. 한 번만 원하면 이벤트 안에서 플래그를 세우고 hideIf 사용
  exits: [ { x, y, w:1, h:1, to:'forest', tx, ty, dir:'down', showIf?, hideIf? } ],
  chests: [ { id:'c1', x, y, item:'potion', count:1 } | { id, x, y, gold:100 } ], // 연 상태 플래그: `chest_<mapId>_<id>`
  objects: [ { x, y, sprite:'save_crystal'|'sign', event?, lines? } ],
  onEnter: 'evt_id' | null,              // 맵 진입 시마다 실행(스스로 플래그로 1회 제어)
}
```
**타일 문자**
- 통행 가능: `.` 풀, `,` 흙길, `F` 꽃밭, `S` 모래, `=` 나무 바닥, `_` 돌 바닥, `K` 붉은 융단, `B` 다리, `D` 문, `X` 황무지, `C` 동굴 바닥, `^` 계단(장식)
- 통행 불가: `T` 나무, `t` 마른 나무, `~` 물, `#` 돌벽, `H` 목조 벽, `R` 지붕, `M` 바위산, `W` 마왕성 벽, `L` 용암, `P` 기둥, `A` 제단, `c` 카운터(건너편 NPC와 대화 가능), `b` 책장, `f` 울타리, `w` 우물, `' '` 공허(검정)

**NPC/오브젝트 스프라이트 키**: `ren`, `mia`, `garen`, `sela`, `elder`, `lina`, `villager_m`, `villager_f`, `child`, `merchant`, `innkeeper`, `blacksmith`, `soldier`, `priest`, `sailor`, `mage`, `old_man`, `cat`, `wolf`, `goblin`, `monster`, `lich`, `vorg`, `demon_king`, `save_crystal`, `sign`, `chest`

## 9. 이벤트 스크립트 — world-designer 작성 / field-dev 실행 (`src/data/events.js`)
```js
EVENTS.evt_elder = [ { cmd:'text', speaker:'오웬 장로', text:'...' }, ... ]
```
| cmd | 필드 | 설명 |
|---|---|---|
| `text` | `text`, `speaker?` | 메시지. `\n` 줄바꿈, 길면 자동 페이지 |
| `choice` | `text?`, `speaker?`, `options:[..]`, `branches:[[cmds],[cmds]]` | 선택지 |
| `if` | `flag` 또는 `member` 또는 `item`(+`count`), `not?`, `then:[..]`, `else:[..]` | 조건 분기 |
| `setFlag` | `flag`, `value=true` | |
| `join` | `member`, `level?` | 파티 합류 + "○○이(가) 동료가 되었다!" 메시지 |
| `battle` | `troop`, `canEscape=false`, `bg?`, `bgm?`, `onLose?:[cmds]`, `onWin?:[cmds]` | `onLose` 없으면 패배 시 게임오버 |
| `giveItem` / `takeItem` | `item`, `count=1` | 획득 메시지 포함(give) |
| `giveGold` | `amount` | |
| `equip` | `member`, `item` | 인벤토리에 없어도 장착(성검 해방용), 기존 장비는 사라짐 |
| `heal` | – | 파티 완전 회복 + 상태이상 해제 |
| `inn` | `price` | 숙박 여부를 묻고, 수락하면 골드를 내고 페이드 후 회복 |
| `shop` | `items:[..]` | 상점 씬 |
| `teleport` | `map`, `x`, `y`, `dir?` | 페이드 전환 |
| `wait` | `ms` | |
| `shake` / `flash` | `ms?`, `color?` | 연출 |
| `bgm` | `key` | BGM 변경 |
| `sfx` | `name` | 효과음 |
| `npcMove` | `npc`, `path:'LLUURD'` | NPC 이동(연출) |
| `playerMove` | `path` | 플레이어 이동(연출) |
| `face` | `dir` | 플레이어 방향 |
| `save` | – | 세이브 씬 열기 |
| `ending` | – | 엔딩 씬(→ 타이틀) |
