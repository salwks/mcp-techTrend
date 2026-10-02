# terrain-engine 보고서 — 권역 지형 엔진·타일 스트리밍·물·원경·권역 실행 장면

담당 경로: `scripts/region/**`, `scenes/region.tscn`, `shaders/region_*`, `shots/region/**`. 다른 칸 파일과 `main.gd`·`materials.gd` 등 공용 파일은 고치지 않았다. `class_name`은 새로 만들지 않았다(preload만 사용). `--import`와 커밋은 하지 않았다.

## 1. 실행

```bash
godot --path seolhwa_godot res://scenes/region.tscn                       # 남원읍성 남문 앞(region.json.spawn)에서 시작
godot --path seolhwa_godot res://scenes/region.tscn -- --tour=shots/region   # 비교 장면 12장
godot --path seolhwa_godot res://scenes/region.tscn -- --bench=25 [--benchspeed=30] [--warp=2000,-300]
```
명령줄은 main.gd와 같다: `--warp=x,z --time --shot --frames --quit --bench --scale`, 끄기 `--nopost --notilt --nobloom --noshadow --nomsaa --nolamps --nochars --noworld --noocc`.
권역 전용: `--tour=dir`, `--tourcam=거리,피치|game`, `--cam=거리,피치[,fov]`(시점 점검), `--data=res://…/`(데이터 폴더), `--nofog --nofar --nowater --noscatter --nomarkers`, `--benchspeed=m/s`(빠르게 걸어 타일 로딩을 몰아서 시험), `--lod0=m --scatterfar=m --shadowdist=m`(튜닝), `--trace`(타일·식생 작업과 느린 프레임 기록).

데이터 경로는 설정 하나(`RegionWorld.DEFAULT_DIRS`/`--data`)로 바뀐다. 기본은 `region_data/JL_NAMWON_UNBONG/`(terrain-data 완성본)이고, 없으면 내 임시 데이터 `shots/region/tmp_data/`(같은 형식, `python3 scripts/region/tools/make_tmp_region.py`로 생성)를 쓴다. 마지막 검증은 모두 **진짜 데이터**로 했다.

## 2. 구조

| 파일 | 내용 |
|---|---|
| `scripts/region/region_world.gd` | 계약서 §6 지형 엔진. `extends "res://scripts/world.gd"`라 기존 `CameraRig`(타입 `World`)·가림 처리를 그대로 쓴다 |
| `scripts/region/region_main.gd` + `scenes/region.tscn` | main.gd를 복사해 고친 권역 실행 장면(플레이어·고정 시점·시간대·후처리·등불·가림·투어·벤치) |
| `scripts/region/png_raw.gd` | 16비트 PNG 원시값 읽기(아래 3.1) |
| `scripts/region/tools/make_tmp_region.py` | 같은 형식의 임시 권역 데이터 생성기(개발용) |
| `shaders/region_common.gdshaderinc` | 높이맵·토지이용 표본, 아주 약한 절차 잡음 — CPU `height_at`과 같은 식 |
| `shaders/region_terrain.gdshader` | 지형 툰 셰이더(붓 바림 램프 LIGHT_COLOR/π², 반구광, 높이 안개, ground.png) |
| `shaders/region_water.gdshader` | 하천 물(water.png 물결이 흐름 방향으로, 반투명, 여울 흰 물살·소 짙게) |
| `shaders/region_far.gdshader` | 원경: 권역 전체 32m 격자, sky_backdrop 먼 산 색 규칙(능선 먹빛·골짜기 안개) |

### 계약 API (`RegionWorld`)
기존 World와 같은 이름: `height_at, blocked, move_circle(부모 것), interior_at, camera_zones, interiors, occluders, lights, npcs, spawn, update(dt,time), set_occluder_alpha`.
추가: `landuse_at(x,z)->int`, `focus(pos)`(스트리밍 중심), `add_static(node, world_xform, info)`(키트 build() 결과: colliders·lights·occluder·interior·footprint를 월드로 바꿔 등록, 타일이 근경일 때만 트리에 붙이고 떼며 조명·가림·실내 목록도 같이 넣고 뺀다. footprint 대각선 40m 넘는 큰 것은 중경에서도 보인다).
그 밖: `shutdown()`(**끝내기 전에 꼭 부를 것** — 진행 중 식생 작업을 기다린다. 트리 삭제 도중에 기다리면 macOS 종료 경로에서 멈춘 적이 있다), `data_height`, `height_fast`(식생용 빠른 높이), `lights_version`(등불 목록이 바뀌면 증가 → region_main이 발광 판을 맞춘다), `update_cutaway`, `update_scatter_lod`, `stats`.

### 3.1 데이터 읽기
Godot 이미지 로더는 16비트 PNG를 8비트로 줄인다(직접 시험: 값 15300 → 60/255). 높이 정밀도가 2.6m로 떨어지므로 `png_raw.gd`가 PNG 머리(IHDR)만 "8비트 회색+알파"로 고쳐 libpng에 다시 넘긴다(필터 단위가 같은 2바이트라 그대로 풀린다) → 바이트 [상위, 하위]. 4353×2113 높이맵 113ms, numpy 값과 일치 확인. 팔레트 PNG도 인덱스로 읽는다. landuse가 2배 거친 격자(4m)인 것도 `region.json.landuse` 메타로 처리.

### 3.2 지형 메시와 스트리밍 (계획서 §2.2)
- **CPU 메시 굽기 없음.** 모든 근경 조각이 "평평한 1m 정수 격자"(64×64칸 + 치마) 메시 하나를 같이 쓰고, **정점 셰이더가 높이맵 텍스처(RG8 = 16비트)로 세운다.** 같은 식(`r_height` = 쌍선형 데이터 + 아주 약한 값잡음 × 토지이용별 세기, 물·하상은 0)을 CPU `height_at`이 계산하고, 렌더 면과 같은 대각선으로 삼각형 보간한다 → 발이 땅에 붙고, 이웃 타일은 같은 월드 좌표에서 같은 높이를 쓰므로 **이음매가 수학적으로 없다**(Q20). 해시는 32비트 정수 연산이라 GPU·CPU 결과가 같다. 법선도 같은 함수의 중앙 차분이라 타일 경계에서 음영이 끊기지 않는다.
  - 그래서 타일을 붙이는 데 드는 일이 노드 몇 개 켜기뿐이라 로딩 중 지형 때문에 프레임이 멈추지 않는다. WorkerThreadPool은 식생(아래)에 쓴다. 요청서의 "백그라운드로 메시 생성"을 이 방식으로 대체했다.
- 타일 256m. 체비셰프 반경 ≤2 = **근경**(1m 격자, 타일당 64m 조각 16개 — 조각마다 높이 범위 AABB라 고정 시점 화면 밖은 그리지 않는다), 3~4 = **중경**(4m 격자 타일 하나, 잡음 없음), 그 너머 = **원경**(권역 전체 32m 격자 한 메시, 근·중경 사각형은 셰이더에서 구멍). 근경→중경은 한 타일 늦게 바꾼다(경계에서 왔다 갔다 할 때 다시 하지 않게). 근·중경 사이 틈은 양쪽 치마(6m/12m)로 가린다. 타일 노드는 풀에 넣어 다시 쓴다.
- 확인: `region_overview_unbong.png`(안개 끔, 520m 위)에서 근·중경 경계·타일 경계 이음매가 보이지 않는다.

### 3.3 지형 재질
`Materials` 툰 셰이더 규칙 그대로(붓 바림 5단 램프 `LIGHT_COLOR/π²`, `EMISSION = base·hemi/π`, Materials와 같은 안개 식). 색은 웹 `terrain.js`의 COL(grass/forest/lane/path/rock/cliff/bank/bed/paddy/high)을 토지이용별로 고르고 웹 땅 붓 텍스처 `assets/kit/ground.png`(7m 반복)를 곱한다. 토지이용 경계는 잡음으로 흔든 4칸 섞기(붓질 같은 경계).
- 숲 바닥·풀밭·길·마을 터·바위·모래톱·대숲: 웹 색 + 얼룩.
- **논**: 48m 구역마다 지형 기울기로 돌린 필지 격자(긴 변이 등고선을 따름, 24×9m), 0.5m 논두렁, 필지마다 **물 댄 논(하늘빛 반사, 프레넬)** / 모 자란 논.
- **밭**: 28×13m 필지, 등고선 따라 1.1m 고랑 그늘, 작물 밭/맨흙 밭, 밭둑.
- 경사 → 흙·바위·벼랑, 높은 산은 조금 차갑게.
- 픽셀 잡음은 해시 대신 이음매 없는 잡음 텍스처(FastNoiseLite, 두 배율 겹침)로 — 처음 해시 fbm 판은 이 셰이더만으로 2~3ms를 썼다.

### 3.4 하천·물
`region.json.rivers`의 수면 y·폭으로 띠 메시(3m 간격, 250m 조각, 폭 `max(width_m, 5.2)`·1.18배 — terrain-data 권고). 물결 흐름 속도는 수면 기울기로: 기울기 큰 곳은 **여울**(흰 물살 한 겹 더, 빠르게), 평평한 곳은 **소**(짙고 고요). 가장자리는 투명하게. 중경 너머(원경 위)에는 물을 그리지 않는다.
걷기: 하천 중심선에서 폭의 80% 안이면서 땅이 수면보다 낮으면 막는다(물 속으로 걸어 들어가지 않음), landuse 5(물)도 막는다. `crossings` 14m 안은 건널 수 있다(다리 상판은 아직 없음 — 6절).

### 3.5 식생 연결(kit/nature/scatter.gd) — 백그라운드
- 시작 때 메인 스레드에서 `Scatter.warm(0)`, `warm(1)`(0.3~0.4s). 스크립트가 문법 오류이거나 `scatter`가 없으면 건너뛴다(만드는 중에도 장면이 뜬다).
- 근경 타일마다 WorkerThreadPool(동시 2개)로 `scatter(rect, height_fast, landuse_at, 권역 시드, lod)`: **반경 ≤1 타일은 lod0+lod1, 반경 2는 lod1만**. `height_fast`(3µs, 데이터+잡음 바로 계산)를 넘겨 타일당 scatter 시간이 122ms → 54ms(lod0)로 줄었다(`height_at`은 삼각형 보간 때문에 14µs).
- 작업 스레드는 원본 MultiMesh 버퍼를 **한 번만** 읽어 64m 칸으로 다시 나눈 "자료"만 만든다. MultiMesh·노드 생성은 메인 스레드에서 프레임당 24묶음씩. (작업 스레드에서 MultiMesh 수백 개를 만들고 버퍼를 여러 번 읽었을 때 렌더 스레드와 엉켜 130ms 프레임이 났다 → 이렇게 고쳐 사라짐.)
- 거리로 벌 고르기: 플레이어에서 32m 안 묶음은 lod0, 그 밖은 lod1, 안개가 97%가 되는 거리(1.9/안개농도, 낮 ≈220m, 밤 ≈110m) 너머는 그리지 않는다. lod1과 키 0.9m 미만(풀·꽃·잔돌)은 그림자를 끈다.
- 충돌: scatter의 colliders를 타일별 32m 격자에 넣어 `blocked()`가 주변 칸만 본다.
- **식생 가림 처리(cutaway)**: MultiMesh라 기존 occluders(반투명)로는 안 되므로, 카메라→플레이어 선분에 수관이 걸린 키 큰 식생(키 2.5m 이상) 인스턴스를 0.1초 동안 줄여 숨겼다가 지나가면 되돌린다(`region_forest_game.png`: 숲 한가운데서도 플레이어가 보인다).

### 3.6 원경
`region_far.gdshader`: 권역 전체 32m 격자를 sky_backdrop의 먼 산 색 규칙으로(능선 = `mix(hor, ink, 0.26~0.43)`, 산발치 = 운해·안개빛, 멀수록 안개) 칠하고 조명은 쓰지 않는다. 근·중경 사각형 안은 버린다. 근·중경 지형은 기존 Materials와 같은 안개를 쓴다(아래 6-2 참고 — 지형만 먹빛으로 남기면 나무·키트와 안 맞아서 꺼 두었다, `far_k`).

### 3.7 임시 표지
`region.json` settlements·landmarks·passes 자리에 장승 같은 기둥(Kit, 이름 Label3D)을 `add_static`으로 놓는다(충돌 원 0.3m). add_static 경로 시험을 겸한다. `--nomarkers`로 끈다.

## 4. 스크린샷 (`shots/region/`, 2048×1536, 진짜 데이터)

| 파일 | 내용 |
|---|---|
| `region_contact.png` | 모아 보기 |
| `region_namwon_day/dusk/night.png` | 남원읍성 터(마을 터 = 아직 건물 없는 맨땅), 낮·해질녘·밤 |
| `region_gwanghallu_day.png`, `region_yeowonjae_day.png`, `region_unbong_day.png`, `region_hwangsan_day.png`, `region_inwol_day.png`, `region_silsangsa_day.png` | 각 장소 표지 9m 남쪽, 투어 시점(34m·36°) |
| `region_river_day.png` | 요천 물가(여울 물결, 모래톱, 논) |
| `region_overview_unbong.png`, `region_overview_jiri.png` | 높은 시점·안개 끔: 운봉 분지 필지·하천·숲, 지리산 쪽 원경 — 타일 이음매 점검 |
| `region_forest_game.png` | 게임 시점, 숲 속(가림 처리로 앞 나무가 비켜남) |
| `region_paddy_game.png` | 게임 시점, 논·밭 필지 |

## 5. 성능 (Apple M1, 2048×1536, MSAA 4×, 후처리·그림자 켬, `--bench=25`, 처음 불러오기 끝난 뒤부터 잼)

**주의: 다른 에이전트들이 같은 맥에서 Godot·Python을 돌리는 동안 쟀다.** 같은 시각 마을 장면(`--bench`) 기준값은 65~66fps(README의 조용한 때 값 61.5). 같은 설정도 실행마다 ±5fps 흔들렸다.

| 장소·걸음 | 평균 fps | 최악 | p99 | 33ms 넘은 프레임 | 그린 삼각형(그림자 포함) |
|---|---|---|---|---|---|
| 남원 분지, 달리기 4.6m/s (spawn) | **62~68** | 23ms | 19ms | 0 | 120~170k |
| 남원 분지, 30m/s(타일 로딩 몰아서, 720m에 근경 타일 20여 개 새로) | 57~63 | 43ms | 32ms | 7 / 1565 | 150k |
| 지리산 쪽 빽빽한 숲(2000,−300), 4.6m/s | **50** | 29~31ms | 26ms | 0 | 1.3M |
| 같은 숲, 30m/s | 49 | 46ms | 37ms | 15 / 1224 | 1.4M |
| (참고) 마을 장면 main.gd | 65 | 23~61ms | | | |

- 처음 불러오기: 데이터·텍스처·원경·물 0.6s + 식생 warm 0.4s + 첫 25타일 식생 3~5s(백그라운드, 그동안도 화면은 돈다).
- 목표(평균 55 이상, 최악 33ms 이하) 대비: **들·마을·하천(권역 대부분)은 달성, 걷는 속도에서는 숲에서도 최악 33ms 이하**를 지켰다. **빽빽한 숲 평균은 50fps로 미달** — 그린 삼각형의 90%가 식생이고(지형은 화면에 10~17만), 그림자 패스가 그 절반이다(`--noshadow` 67fps, `--noscatter` 70fps). 원인과 요청은 6-3.
- 30m/s(달리기의 6.5배)로 타일을 몰아서 불러올 때만 33ms 넘는 프레임이 드물게(0.5~1%) 생긴다. 정상 걸음·달리기에서는 없었다.
- 기존 마을 장면 확인: `godot --path . -- --refset=…` 7장 웹 기준 대비 차이 1.1 / 2.1 / 1.3 / 5.5 / 2.3 / 21.5 / 4.2 — README 값과 같다(main.gd 쪽 그대로).

## 6. 남은 문제와 총괄 요청

1. **(공용 materials.gd·sprite_char.gd) 낮은 안개 기준 높이**: `FOG_CODE`의 `fog_mist`가 절대 높이 y∈[−2, 7]에만 걸린다(마을 바닥 y=0 기준). 권역은 y 3~386이라 키트·캐릭터에는 낮은 안개가 거의 안 생긴다. 내 셰이더는 `mist_base`(플레이어 발 높이)를 받는다. 전역 uniform `fog_base`를 만들어 `smoothstep(fog_base−2, fog_base+7, y)`로 바꿔 주면 region_main이 매 프레임 넣겠다.
2. **(공용) 원경 공기원근**: 먼 능선을 먹빛으로 남기는 규칙을 지형에만 넣으면 안개색 나무·물과 반대로 보여 꺼 두었다(`region_terrain.gdshader`의 `far_k`). 같은 식을 공용 안개(Materials·Kit·SpriteChar)에 넣으면 지형도 `far_k=1`로 맞춘다. 지금 화면에는 고정 시점이라 200m 너머가 거의 안 보여 큰 문제는 아니다.
3. **(kit-nature) 식생 삼각형**: 숲 타일 하나가 lod0 **320만**, lod1 51만 삼각형이다(계획서 §2.2 타일당 6만 예산의 50배). 엔진에서 64m로 다시 나누고 거리로 벌을 고르고 그림자를 줄여 숲 평균 32→50fps까지 올렸지만, 55를 넘기려면 숲 lod0 밀도(나무 수 또는 나무당 삼각형)를 절반 안팎으로 줄여야 한다. 또 scatter가 MultiMesh 버퍼(PackedFloat32Array)를 결과에 같이 넣어 주거나 64m 묶음으로 바로 주면 엔진이 `MultiMesh.buffer`를 렌더 서버에서 다시 읽지 않아도 된다.
4. **식생 가림**은 인스턴스를 줄여 숨기는 방식이라 그 나무의 그림자도 같이 사라진다. Kit 재질에 "카메라–플레이어 원기둥 안은 디더로 비우기" 같은 전역 uniform이 생기면 더 자연스럽다(공용 재질이라 요청만).
5. **다리·나루 높이**: `height_at`은 지형만 안다. kit-village 다리가 놓이면 상판 높이가 필요하다 → `add_static`의 info에 `walk: [{minX,maxX,minZ,maxZ, y | y0,y1(축)}]` 같은 걷기 면을 추가하는 계약 확장을 제안(엔진은 그 칸에서 지형 대신 그 높이를 쓰겠다). 지금은 crossings 14m 안에서 물에 들어갈 수 있다(여울처럼 걸어 건넘).
6. **마을 터(landuse 6)**는 건물 없이 넓은 노란 맨땅(남원읍성 반경 85m)이라 지금 투어 장면 다수가 빈 마당이다. 마을·랜드마크 배치(이번 범위 밖)가 들어오면 해결된다. 배치 담당은 `world.add_static(node, Transform3D(Basis(ry), Vector3(x, world.height_at(x,z), z)), info)`만 부르면 된다.
7. 카메라 구역(camera_zones)은 `region.json.camera_zones`가 있으면 그대로 쓴다(지금은 없음).
8. 측정 환경: 다른 에이전트가 같은 맥을 쓰는 동안이라 수치가 흔들린다. 조용할 때 `--bench=25`(spawn), `--bench=25 --warp=2000,-300`(숲)을 다시 재 주길 권한다.
9. 개발용 임시 데이터 `shots/region/tmp_data/`(12MB)는 진짜 데이터가 있으면 쓰지 않는다. 필요 없으면 지워도 된다(생성기는 남김).
