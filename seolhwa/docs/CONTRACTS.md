# 설화록 프로토타입 — 모듈 계약서

순수 ES 모듈, 빌드 없음. three.js r170은 `vendor/three/`에 포함되어 있고
`index.html`의 importmap으로 `import * as THREE from 'three'`,
`import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js'`처럼 쓴다.
사용 가능한 addons는 `vendor/three/addons/` 안의 파일뿐이다(더 필요하면 보고서에 요청).
이미지·모델·오디오 파일은 쓰지 않는다. 모든 텍스처는 캔버스로 절차 생성한다.

로컬 실행: `cd seolhwa && python3 -m http.server 8000`

## 0. 파일 소유권
| 경로 | 담당 |
|---|---|
| `index.html`, `src/main.js`, `src/core/**`, `docs/**` | 총괄(코어) |
| `src/world/**` | env-artist (3D 지형·건물·소품) |
| `src/chars/**` | char-artist (2D 컷아웃 캐릭터) |
| `src/fx/**` | fx-artist (조명·시간대·후처리) |

## 1. 좌표와 스케일
- 1 단위 = 1m. y가 위쪽. 성인 키 약 1.65m, 아이 1.1m, 호랑이 몸길이 약 2.6m·어깨높이 1m, 초가집 처마 높이 약 2.2m.
- 카메라는 **남쪽(+z)에서 북쪽(-z)을 바라본다**(yaw 고정). 기본 pitch 38°, 거리 16m, fov 30°.
  - 따라서 건물의 **정면은 +z를 향하게** 둔다(무대 세트). 뒷면은 대충 만들어도 된다.
- 월드 범위: x ∈ [-45, 45], z ∈ [-80, 30].
  - 마을 중심 (0, 0), 지면 높이 0 근처. 개울은 z≈-16 부근을 동서로 흐르고 돌다리는 x≈0.
  - 산길은 다리 북쪽에서 시작해 굽이치며 올라가 고갯마루 (약 x=8, z=-70, 높이 약 14m)에 닿는다.
  - 외딴 초가집(실내 검증용)은 숲 가장자리 (약 x=-22, z=-32).

## 2. world — `src/world/index.js`
```js
export function buildWorld(scene) → World
World = {
  heightAt(x, z) → number,          // 지면 높이(걸을 수 있는 면). 다리 위는 다리 상판 높이
  colliders: [ {type:'circle', x, z, r} | {type:'box', minX, maxX, minZ, maxZ} ],  // 통과 불가
  spawn: { x, z },                   // 마을 중앙 근처
  npcs: [ { id, kind, x, z, facing:'down'|'up'|'left'|'right', wander:false|number(반경m), name, lines:['대사', ...] } ],
  cameraZones: [ { name /* 한국어 장소명, 화면에 표시됨 예: '돌다리' */, minX, maxX, minZ, maxZ, pitch, distance, fov?, lookAhead? } ],  // 겹치면 배열 뒤쪽 우선
  interiors: [ { name, minX, maxX, minZ, maxZ, hide:[Object3D], camera:{pitch, distance, fov?} } ],  // 플레이어가 안에 있으면 hide 목록을 숨김(지붕·앞벽)
  occluders: [Object3D],             // 플레이어를 가릴 수 있는 큰 물체(나무, 지붕, 담). 코어가 반투명 처리
  lights: [ { x, y, z, kind:'lantern'|'window'|'torch'|'shrine' } ],  // 밤 조명 위치(fx가 사용)
  labels?: [ { x, y, z, text } ],    // 디버그용 장소 이름
  update?(dt, time),                 // 물 흐름, 천 흔들림 등
}
```
- 그림자: 지형·건물은 `receiveShadow`, 건물·나무·바위는 `castShadow`.
- **occluders의 각 객체는 자기만의 머티리얼 인스턴스를 가져야 한다**(코어가 opacity를 바꿈). 공유하면 코어가 복제한다.
- 스타일: 낮은 폴리곤 + 부드러운 버텍스 색 그라데이션, 먹선 느낌의 외곽선(뒤집은 헐 방식 등), 채도 낮은 자연색. 사실주의 텍스처 금지.

## 3. chars — `src/chars/index.js`
```js
export const KINDS = ['player','villager_m','villager_f','elder','child_boy','child_girl','hunter','tiger']
export function createCharacter(kind) → Character
Character = {
  object3d: THREE.Group,        // 원점 = 발 중심. 코어가 position만 바꾼다
  height, radius,               // m
  setFacing(dir),               // 'down'(카메라 쪽) | 'up' | 'left' | 'right'
  setAnim(name),                // 'idle' | 'walk' | 'run' | 'talk' | 호랑이: 'idle'|'walk'|'crouch'|'pounce'
  setMode(mode),                // '4dir'(기본, 방식 B) | 'front'(정면 1장 + 좌우반전, 방식 A)
  setSilhouette(on),            // 가려졌을 때 보이는 실루엣 표시 여부(기본 on)
  update(dt, camera),           // 애니메이션 진행 + 카메라를 향해 평면 정렬
}
```
- 스프라이트는 카메라 쪽을 향한 평면. 캐릭터 그림은 캔버스에 **컷아웃 부위(머리·몸통·팔·다리·옷자락)**로 그리고 부위 회전·이동으로 애니메이션한다.
- 조명 반응: 조명을 받는 머티리얼(`MeshStandardMaterial` 또는 `MeshLambertMaterial`, alphaTest)로 밤·초롱불 조명이 캐릭터에도 비치게 한다.
- 발밑 그림자(타원 블롭)는 항상. 실제 그림자 투사(`castShadow` + alpha 대응 `customDepthMaterial`)도 지원한다.
- 실루엣: 가려진 부분이 먹색 반투명으로 보이는 두 번째 패스(깊이 테스트 반전).

## 4. fx — `src/fx/index.js`
```js
export function createFX({ renderer, scene, camera, world }) → FX
FX = {
  update(dt, focus /* THREE.Vector3 플레이어 위치 */),
  render(),                     // 후처리 포함 최종 렌더
  resize(w, h),                 // CSS 픽셀
  setTime(hour 0~24), getTime(),// 시간대(낮·해질녘·밤) — 해·달·하늘·안개·색보정이 따라 바뀜
  setOption(name, value), getOptions() → { name: value },
  // 옵션: 'tiltShift'(bool), 'bloom'(bool), 'paper'(bool, 한지 질감+비네트), 'fog'(bool), 'timeFlow'(bool, 시간 자동 흐름)
}
```
- 방향광(해/달)의 그림자 카메라는 플레이어 주변만 덮도록 따라간다(해상도 절약).
- `world.lights`는 밤에만 켜진다. 실제 PointLight는 플레이어와 가까운 몇 개(최대 6)만 쓰고 나머지는 발광 스프라이트로 대체.

## 5. 코어가 하는 일 (`src/core/**`)
입력(키보드·가상 조이스틱), 플레이어 이동·충돌·높이, NPC 배치·배회·대화, 카메라 구역 연출, 가림 처리(occluder 반투명), 실내 판정(hide 목록 숨김), 검증 패널(옵션 토글, 체크리스트).
