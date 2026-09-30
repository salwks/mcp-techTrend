# 설화록 — 2단계 전투 프로토타입

개발계획서 27장 2단계: **플레이어와 호랑이만** 구현해 공격·회피·피격·거리 판정을 검증한다.
계획서 13~15장 원칙: 전투는 단순하게, 2D 자세만 보고 공격을 예측할 수 있게(몸을 낮춘다 → 멈춘다 → 돌진),
전투만으로도 이길 수 있지만 항상 가장 쉬운 길은 아니게(규칙을 이용한 해법이 있음).

## 1. 검증 항목
1. 고정 시점에서 깊이축(화면 위아래) 거리 판단이 되는가 — 발밑 그림자, 공격 범위 표시(토글)
2. 2D 자세만 보고 호랑이 공격을 예측할 수 있는가 — 예고 동작, 바닥 예고 표시(토글)
3. 회피·방어 타이밍이 공정하게 느껴지는가
4. 타격감 — 먹물 번짐 타격 효과, 히트스톱, 화면 흔들림
5. 규칙 활용 — 떡(먹이 집착), 영역(도망), 뒤에서 기습
6. 결말이 여럿인가 — 처치 / 물러나게 함 / 도망 / 패배

## 2. 조작
| 행동 | 키보드 | 모바일 | 설명 |
|---|---|---|---|
| 이동 | WASD·방향키 | 조이스틱 | 8방향 이동, 스프라이트는 4방향 |
| 공격 | J (탭) | 공격 | 환도 베기, 3연타 콤보 |
| 강공격 | J 길게 누름(0.5초) 후 떼기 | 공격 길게 | 모아 베기, 호랑이 경직 |
| 회피 | K | 회피 | 짧은 구르기(무적 시간), 기력 소모 |
| 방어 | L 누르고 있기 | 방어(누름) | 피해 70% 감소, 막을 때 기력 소모 |
| 활 | I 누르고 있다가 떼기 | 활(누름) | 조준(가장 가까운 대상 자동 보정) 후 발사, 화살 12발 |
| 떡 던지기 | U | 떡 | 앞쪽 약 5m에 떡을 던짐, 3개 |

## 3. 수치 (초안 — combat-dev가 조정)
- 플레이어: HP 100, 기력 100(0.6초 후 초당 30 회복). 공격 8, 강공격 24, 화살 10.
  회피 0.45초·3.5m·무적 0.3초·기력 25. 방어 중 피격 시 기력 = 피해×1.2 소모, 기력 0이면 방어가 깨짐.
- 호랑이: HP 320. 행동 규칙(계획서 12장):
  - **배회**: 6~9m 거리에서 플레이어 주위를 낮게 돈다(관찰).
  - **덮치기**: 몸을 낮추고(crouch 0.8초, 바닥에 돌진 경로 예고) → 일직선 8m 도약(피해 30, 넘어뜨림). 착지 후 1초 빈틈.
  - **앞발 치기**: 2m 이내에서 앞발을 드는 예고(0.4초) → 부채꼴 피해 15.
  - **포효**: HP 50% 이하에서 한 번. 예고 후 충격파, 가까우면 1초 경직. 이후 공격이 빨라짐.
  - **먹이 집착**: 떡이 떨어지면(분노 상태가 아닐 때) 먹으러 가서 3.5초 동안 먹는다. 이때 **뒤에서 치면 기습(피해 2배)**.
  - **영역**: 싸움터 반경을 벗어나면 쫓지 않고 포효한 뒤 영역 가운데로 돌아간다 → **도망** 결말.
  - **물러남**: HP 20% 이하가 되면 싸움을 멈추고 산으로 물러난다 → **물러나게 함** 결말(죽이지 않은 해결). 강공격·화살로 계속 몰아붙여 HP 0이면 **처치**.
- 결말: 처치 / 물러나게 함 / 도망 / 패배. 결말 화면에서 다시 하기.

## 4. 모듈 계약

### 4.1 combat — `src/combat/index.js` (combat-dev)
```js
export function createCombat(ctx) → Combat
ctx = {
  scene, world, camera, fx, hud, input,
  player,            // core Actor: { pos:{x,y,z}, facing, char, face(dir), sync() }
  makeChar(kind),    // 캐릭터 생성
  hitStop(ms),       // 전체 시간을 잠깐 멈춤(코어)
  shake(power, ms),  // 카메라 흔들림(코어)
  blocked(x, z, r),  // 충돌 판정(코어 motion.blocked 래핑)
}
Combat = {
  active, result,            // result: null | 'win' | 'repelled' | 'escaped' | 'lose'
  start(arena), reset(),     // arena: world.arenas[i]
  update(dt),                // 전투 중에는 플레이어 이동·행동·애니메이션을 combat이 전담
  setOption(k, v), options,  // telegraph(bool), ranges(bool, 공격 범위 표시), aimAssist(bool), hitStop(bool)
}
```
- 전투 중에는 코어가 플레이어 이동·대화를 하지 않는다.
- 입력: `input.pressed(a)`, `input.held(a)`, `input.released(a)`. 액션 `attack`, `dodge`, `guard`, `bow`, `item` 그리고 `input.moveVector()`, `input.running()`.
- 판정은 xz 평면의 원·부채꼴·선분으로 한다(높이 무시, 단 호랑이 도약 중에는 판정 없음 등은 자유).
- 화살은 combat이 만드는 간단한 3D 메시(먹선 느낌)로 날아간다. 떡도 combat이 만드는 작은 메시다.

### 4.2 chars 추가 애니메이션 (char-artist)
사람(player 우선):
`attack1`, `attack2`, `attack3`(콤보 베기), `charge`(강공격 모으기, 반복), `heavy`, `guard`(반복), `dodge`, `bow_draw`(반복), `bow_shoot`, `throw`, `hit`, `down`(넘어짐), `getup`, `dead`.
호랑이: `prowl`(낮게 걷기, 반복), `crouch`(반복), `pounce`, `land`, `swipe`, `roar`, `hit`, `stagger`, `eat`(반복), `dead`.
- `setAnim(name, { restart=false, speed=1 })`
- 1회성 애니메이션은 끝나면 마지막 자세 유지. `char.animDone`(bool), `char.animTime`(초), `char.animDuration(name)`(초).
- `char.flash(color = '#ffffff', ms = 120)`: 피격 시 번쩍임.
- 플레이어는 환도(짧은 칼)를 들고, 활은 등에 멘다(활 쏠 때 손에 듦).

### 4.3 fx 전투 효과 (fx-artist) — `fx.combat`
```js
fx.combat.spawn(type, pos /* Vector3 */, opts) → handle { remove() }
// 'hit'(먹물 번짐), 'heavyHit', 'block'(불꽃), 'dust'(흙먼지), 'slash'({dir: Vector3, radius, arc}), 'roar'(충격파 고리),
// 'lane'({dir, length, width, duration}) 덮치기 예고 경로, 'fan'({dir, radius, arc, duration}) 앞발 예고, 'ring'({radius, duration}) 공격 범위
fx.combat.update(dt)   // fx.update 안에서 호출해도 됨
```
- 바닥 표시는 지형 높이(`world.heightAt`)를 따라 살짝 띄워 그린다. 먹붓 획 질감.

### 4.4 world 추가 (env-artist)
```js
world.arenas = [ { name, x, z, radius, tigerStart:{x,z}, playerStart:{x,z}, camera:{pitch, distance, fov} } ]
```
- 산길 옆 숲속 빈터 "호랑이의 영역": 지름 약 22m, 비교적 평평, 가장자리에 바위·나무 몇 개(엄폐·가림 검증용). 전투용 카메라 구역 포함.

### 4.5 HUD API (코어가 제공, combat이 호출)
```js
hud.setPlayer(hp, maxHp, stamina, maxStamina)
hud.setFoe(name, hp, maxHp) / hud.setFoe(null)     // 호랑이 체력(숨기기)
hud.setAmmo({ arrows, bait })
hud.say(text, ms = 2200)                           // 상황 문구 "호랑이가 몸을 낮춘다…"
await hud.result(kind, title, text)                // 결말 화면. '다시 하기'를 누르면 resolve
hud.combatMode(on)                                 // 전투 UI·모바일 전투 버튼 표시
```

### 4.6 코어 (총괄)
입력 확장(held/released, 전투 키·모바일 버튼), HUD(체력·기력 붓획 게이지, 호랑이 체력, 화살·떡 수, 상황 문구, 결말 화면), 히트스톱·카메라 흔들림, 싸움터 진입 시 전투 시작, 검증 패널 전투 섹션.
