# 설화록 — Godot 이식 (G0 1차)

월드 개발계획서 v1.1 §5 **G0 엔진 기반**의 첫 단계. 웹 프로토타입(`seolhwa/`) 1단계를 Godot 4로 옮겨 **같은 장면·같은 품질**을 재현한다.
Godot 4.7.1(macOS, Apple M1)에서 검증했다.

## 실행

```bash
godot --path seolhwa_godot                            # 게임(시작 메뉴·이야기·말 걸기) — 첫 장면 region.tscn
godot --path seolhwa_godot res://scenes/main.tscn   # G0 1차 마을 데모(--refset·--bench 등) — 첫 장면은 이제 region.tscn
```
창 1024×768, 장면은 화면 배율(레티나 2)만큼 크게 그림.

| 키 | 동작 |
|---|---|
| WASD / 방향키 | 이동 (Shift: 달리기) |
| T | 시간 6시간씩 넘기기 |
| P | 틸트시프트·한지 끄기/켜기 |

명령줄(`--` 뒤): `--time=22` `--warp=x,z` `--shot=out.png --frames=60 --quit` `--scale=2` `--refset=shots`(비교 장면 7장) `--bench=15`(자동 걷기 성능 측정)
비교용 끄기: `--nopost --notilt --nobloom --noshadow --nomsaa --nolamps --nochars --noworld --noocc`

## 데이터 만들기 (`data/`, git 제외)

마을·캐릭터는 웹 프로토타입이 만든 것을 그대로 내보내 쓴다(엔진 중립 형식: glTF, JSON, PNG).

```bash
python3 seolhwa_godot/tools/web_export_server.py 8770
```
브라우저로 http://localhost:8770 을 열고(탭이 보이는 상태, 창 1024×768·배율 2), 불러오기가 끝나면 개발자 콘솔에서:
```js
await (await import('/__tools/export_from_web.js')).done
```
`data/`에 `village.glb`(28MB), `world.json`, `heights.f32`, `frames*.json`·PNG, `paper.png`, `ref/ref_*.png`(웹 기준 스크린샷 7장)가 생긴다(약 1~2분).
처음 한 번은 `godot --headless --import --path seolhwa_godot`로 스크립트 클래스를 등록한다.

## 구조

| 파일 | 웹 원본 | 내용 |
|---|---|---|
| `scripts/main.gd` | `src/main.js`, `fx/index.js`, `fx/nightlights.js`, `core/occlusion.js` | 진입점, 이동·충돌, 마을 사람 배회, 밤 등불(가까운 6개만 실제 빛), 가림 처리, 실내 숨김, 자동 스크린샷·성능 측정 |
| `scripts/world.gd` | `src/world/*` (계약 CONTRACTS §2) | glTF·높이 격자·충돌체·카메라 구역 불러오기 |
| `scripts/materials.gd` | `world/materials.js` | 툰 재질(붓 바림 5단) + 반구광 + 높이 안개 |
| `scripts/camera_rig.gd` | `core/camera.js` | 고정 시점 카메라, 구역·실내 연출 |
| `scripts/sprite_char.gd` | `chars/Character.js`, `frameCore.js` | 프레임 캐릭터(카메라를 향한 판, 한지빛 테두리, 가려지면 먹색 실루엣, 발밑 그림자) |
| `scripts/time_of_day.gd` | `fx/timeofday.js` | 시간대 팔레트·해/달 방향 |
| `scripts/post_effect.gd` | `fx/post.js` | 후처리(컴포지터 효과 + compute): 틸트시프트, 블룸, 먹선, Neutral 톤매핑, 색보정, 한지, 비네트 |
| `shaders/sky_backdrop.gdshader` | `fx/sky.js` | 먼 산 능선·운해·하늘 |

밝기 맞추기: 웹(three.js)의 조명 세기 값을 그대로 쓴다. Godot의 `LIGHT_COLOR`는 세기×π라서 셰이더에서 π²로 나눈다(three의 Lambert 1/π와 맞춤).

## 검증 결과 (웹 기준 스크린샷과 비교, 2048×1536)

| 장면 | 평균 픽셀 차이(0~255) | 비고 |
|---|---|---|
| 마을 낮 / 해질녘 / 밤 | 0.9 / 2.0 / 1.2 | 사실상 같음 |
| 돌다리 낮 | 5.6 | 물 반투명 차이, 마을 사람 배회 위치 |
| 고갯마루 낮 | 2.5 | |
| 실내(외딴 초가) | 4.2 | 웹도 거의 검게 나옴 — 웹 쪽 확인 필요 |
| 집 뒤(가림 처리) | 21.3 | **의도한 차이**: 반투명 지붕을 한 겹만 보이게 함(아래) |

성능(Apple M1, 2048×1536, MSAA 4×, 자동 걷기): **평균 61.5fps, 최악 프레임 22.6ms**(시작 2초 제외). 웹 프로토타입은 같은 조건에서 60fps.

## 이식하며 정한 것

- **렌더러는 Mobile.** Forward+는 같은 화면에서 29fps, Mobile은 62fps. Mobile은 장면 버퍼에 밝기를 1/2로 저장하므로 후처리에서 `lum_mult = 2`로 되돌린다.
- **후처리는 컴포지터 효과(compute).** 패스마다 SubViewport를 잇는 방식은 이 맥에서 패스당 수 ms가 들어(Metal·Vulkan 모두) 21fps까지 떨어졌다.
- **하늘은 화면 전체 사각형.** Godot `Sky`에 시간 값을 매 프레임 넘기면 환경 큐브맵을 매 프레임 다시 구워 무겁다. 웹과 같은 방식으로 바꿨다.
- **반투명(가림 처리)은 깊이를 기록한다.** 웹처럼 깊이를 안 쓰면 흐려지는 동안 먹선 껍질 안쪽이 잎·지붕을 덮어 검게 번쩍인다(버드나무에서 재현). 그래서 웹보다 지붕이 밝게 보인다.
- **마을 사람도 프레임 그림.** 웹은 컷아웃으로 그리지만, 같은 굽기 엔진(`BakeBank`)으로 대기·걷기·대화를 구워 쓴다.

## 아직 안 옮긴 것 (G0 2차 이후)

호랑이 전투(`combat/`), 사건 「산길의 실종」(`story/`), UI(`ui/`), 대화창·장소 이름, 검증 패널, 날씨·바람(천 흔들림), 타일 스트리밍 시제품, 호랑이 NPC.
개발은 맥 로컬에서만 한다(클라우드용 설치 스크립트는 지웠다).
