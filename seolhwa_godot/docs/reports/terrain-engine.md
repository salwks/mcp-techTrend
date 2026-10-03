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

---

# 2단계 — 배치 불러오기 · 터 고르기 · 식생 비우기 · 다리 걷기 면

계약서 §8을 따랐고, walk 형식과 로더 동작은 §8에 직접 적었다(총괄 지시). `region_data/`는 읽기만 했다.

## 만든 것
| 파일 | 내용 |
|---|---|
| `scripts/region/placement_loader.gd` (첫 줄 `# LOADER_READY`) | `placement_*.json`(데이터 폴더 + `--placedir`)을 모두 읽는다. 배치형은 `layout()`이나 build() 결과 `pieces`로 풀어 조각마다 놓는다. 같은 kit+params는 한 번만, 작업 스레드 여러 개로 짓는다. 그다음 터 고르기 → 식생 비우기 → `add_static`(꼬리표 `placement`)과 걷기 면 순서로 처리한다 |
| `region_world.gd` 추가 | `flatten_rect`, `commit_terrain`(텍스처 다시 올리고 타일 다시), `reset_edits`, `add_veg_exclusion`, `add_walk`·`walk_at`, `ground_at`(지형만), `river_surface_at`, `remove_tagged`, 방향 있는 상자 충돌체(`obox`) |
| `region_main.gd` 추가 | 시작할 때 배치를 불러온다. **F5 또는 `--reload`**(파일이 바뀌면 1초 안에 다시 읽음), `--placedir=폴더[;폴더]`, `--noplace`, `--serialbuild`, `--markers`(배치가 있으면 임시 장승은 자동으로 숨김), `--cutaway`. 시작할 때 가림 반투명 재질을 미리 한 번 그린다 |
| `shots/region/test_place/placement_test.json` | 시험용(섶다리·징검다리·돌다리·읍성·집 5채). `--placedir`로만 읽힌다. 진짜 배치와 남원에서 겹치니 시험할 때만 쓸 것 |

### 터 고르기 (이음매 없음)
- 2m 높이 데이터(`hbytes`) 자체를 고친다. 회전된 footprint+2m 안은 목표 높이(항목 `y`, 없으면 안의 평균)로 맞추고, 바깥 5m에 걸쳐 smoothstep으로 원래 땅에 잇는다.
- 정점 셰이더와 CPU `height_at`이 같은 바이트를 읽으므로 둘이 어긋나지 않는다. 바뀐 텍스처는 한 번에 GPU로 올리고(`ImageTexture.update`), 타일 높이 범위와 식생은 다시 만든다.
- 고른 칸은 토지이용 바이트의 128 비트를 켠다. 그 칸은 잡음 디테일이 0이고 **마당색(분류 6)**으로 칠해져 집이 논 위에 뜨지 않는다. 길·물은 그대로 둔다.
- 처음 데이터는 따로 보관해 두고, 다시 읽을 때 되돌린 뒤 다시 적용한다.

### 식생 비우기
- 범위는 footprint+1m이고, flatten이면 고른 터 전체(+2m+4m)다.
- 식생 작업 스레드가 MultiMesh 인스턴스와 충돌체를 회전 사각형으로 거른다.
- `scatter`가 6번째 인자를 받으면 `exclude`(Rect2 또는 `{x,z,r}`)도 넘긴다. 아직 kit-nature에는 이 인자가 없어 엔진 쪽 거르기만 동작한다.

### 다리 걷기 면
- `height_at = max(지형, 걷기 면)`. 걷기 면 위에서는 하천 막기를 하지 않고, 다리가 놓인 crossings 25m 안에서는 물을 걸어 건너는 임시 허용을 끈다.
- kit-village의 `deck`는 설명 문자열이라 쓸 수 없다. 그래서 `stone_bridge`·`seop_bridge`·`jingeom`은 로더가 params로 걷기 면을 만든다.
- 다리 y가 null이면 양 끝 둑 평균, 징검다리·나루배·빨래터는 가까운 수면을 쓴다.
- 확인: 세 다리를 따라 높이와 막힘을 재는 시험(`shots/region/_t/t_walk.gd`)에서 막힌 칸이 없고 높이가 상판을 따른다. 게임 화면은 `shots/region/region_bridges_walk.png`(섶다리·홍예교 위).
- 고친 버그: 돌린 다리의 난간 상자를 축 정렬 상자로 감싸면 다리 가운데까지 막혔다. 방향 있는 상자로 바꿨다.

### 가림
총괄이 넣은 키트 점무늬 가림(occ_*)이 식생에도 먹으므로, 나무를 줄여 숨기는 cutaway는 **기본으로 끔**(`--cutaway`로 켬). 덕분에 숨긴 나무의 그림자가 같이 사라지던 문제도 없어졌다(`region_yeowonjae_day.png`에 점무늬 원이 보인다).

## 확인 (진짜 배치 `placement_namwon.json` 등, 실행 시점 2개 파일 535항목 → 665개)
- `shots/region/region_namwon_placed_overview.png`: 남원읍성·관아·객사·민가·장터 줄·광한루. 터 고르기와 마당색, 식생 비우기가 반영돼 있다.
- 투어 다시 찍음(`region_contact.png`): 광한루, 운봉 관아 담, 실상사 석탑, 황산 비각, 여원재 숲(점무늬 가림).
- 다시 읽기 시험(`shots/region/_t/t_reload.gd`): 두 번 읽어도 정적 물체·충돌체·높이가 같다.
- 불러오기 시간: 항목 186개 3.4s, 535개 6.9s. 메인 스레드에서 기다리며 짓기는 작업 스레드 8개가 한다. 배치가 더 늘면 타일 단위 지연 짓기가 필요하다(아래 요청 3).

## 성능 (2048×1536, MSAA 4×, `--bench=25`)
이번에도 다른 에이전트와 같은 맥을 썼다. 같은 설정이 59~123fps로 흔들린 적도 있다. 같은 시각 마을 장면 기준값은 92fps.

| 장소 | 평균 fps | 최악 | p99 | 33ms 넘은 프레임 | 삼각형 |
|---|---|---|---|---|---|
| 남원 읍내(배치 287개), 4.6m/s | 86 | 37ms | 18ms | 1 / 2153 | 140k |
| 남원읍성 안(배치 599개), 4.6m/s | 83~99 | 37~59ms | 17~21ms | 2~9 / 2100~2500 | 190k |
| 남원 출발 30m/s(배치 599개) | 77 | 45ms | 24ms | 4 / 1936 | 135k |
| 숲(2000,−300), 4.6m/s | 85 | 55ms | 21ms | 5 / 2121 | 370k |
| 숲 30m/s | 77 | 79ms | 30ms | 11 / 1923 | 350k |

- 평균은 모든 곳에서 목표 55를 넘는다. 숲은 kit-nature가 밀도를 줄여 1단계 130만에서 37만 삼각형, 50에서 85fps가 됐다.
- **33ms 넘는 프레임이 걷기에서도 0.1~0.3% 남는다.** `--trace`로 보면 타일·식생·배치 작업과 같은 때가 아니고(그 프레임의 엔진 일은 0.1ms), 같은 설정 반복에서도 나왔다 안 나왔다 한다. 기기 부하로 보이지만 가림 반투명 재질이 처음 쓰일 때의 파이프라인 생성일 가능성도 있어 시작 시 미리 그리기를 넣었다. 조용한 때 다시 재야 결론이 난다.

## 남은 문제와 요청
1. **kit-village**: 다리 `deck`를 설명 문자열 대신 §8 `walk` 배열로 돌려주면 로더의 대체 계산을 지울 수 있다. 홍예교 끝단(y=0.1)과 둑 높이 차이가 큰 곳은 배치 쪽에서 다리 길이·위치를 맞춰야 한다. 시험 섶다리는 한쪽 둑이 4m 높아 끝에 2m 턱이 생겼다.
2. **kit-nature**: `scatter(…, exclude)` 인자를 넣어 주면 비운 자리 주변 밀도(예: 마당가 풀)를 그쪽에서 자연스럽게 다룰 수 있다. 지금은 엔진이 잘라내기만 한다.
3. **배치가 수천 개로 늘면**: 지금은 시작할 때 모두 짓는다(535항목 7s). footprint를 JSON에 넣어 주면 짓기를 타일이 가까워질 때 백그라운드로 미루도록 바꿀 수 있다. 배치 담당에게 `footprint` 필드를 권한다.
4. 배치형 `pieces`가 높이 차를 가져야 하면(예: 경사지 사찰) 조각에 `y`(부모 기준)를 넣으면 된다. 없으면 각 조각이 자기 자리 지형에 선다.
5. `interior.floor_y` 같은 §4 보완은 아직 엔진에서 쓰지 않는다(실내는 박스·카메라·hide만).

---

# 3단계 — 마을 땅·길·카메라 구역·안개·지연 짓기

## 고친 것
1. **마을 터 = 풀밭.**
   - 토지이용 6(마을 터)을 웹 마을 땅처럼 풀밭에 마른 흙 얼룩으로 칠한다. 맨 흙은 건물 둘레에만 깐다.
   - 새 **칠하기 텍스처**(높이와 같은 2m 격자, RGBA8)를 두었다. B에는 배치된 건물·소품의 footprint 바깥 거리를 넣고, 셰이더는 1.2~3.6m에 걸쳐 잡음으로 흔들어 흙 마당을 그린다. 가장자리는 풀과 섞인다.
   - 집 묶음·관아·향교·절·주막은 담 안 마당 전체를 흙으로 칠한다. 성 안처럼 넓은 곳은 건물·길 둘레만 흙이다.
   - 담·울·성벽·다리·장승·나무는 마당 칠하기에서 뺀다. 담 조각은 자리가 (0,0)이고 점이 params에 있어 footprint가 맞지 않는다.
   - 터 고르기 표시 비트는 이제 잡음 디테일만 끈다(색은 칠하기 텍스처가 정한다).
2. **길 그리기.**
   - region.json roads를 시작할 때 칠하기 텍스처 R·G·A(중심선 거리·반폭·등급)에 그린다. 76ms.
   - 셰이더는 흙길(조금 밝음), 바퀴·발 자국(대로·지선은 두 줄, 마을길·산길은 가운데 한 줄), 짙은 풀 길섶을 그린다. 대로는 반폭을 0.4m 넓혔다.
   - 4m 토지이용 래스터의 길(4)은 밟힌 풀 정도로만 칠한다. 또렷한 흙길은 선 데이터에서 나온다.
3. **카메라 구역**(region_world `_build_camera_zones`, 뒤에 있는 구역이 이김):
   - 권역 기본: 22m·40°
   - 고을·장터(settlements 반경, 30~220m): 22/40
   - 숲·산길(플레이어 둘레 14m 9점 중 5점 이상이 숲·대숲이고 고을 밖이면, 10프레임마다 움직이는 구역): 20/48
   - 고개(passes 45m): 22/30
   - 실내는 키트 `interior.camera`(CameraRig가 구역보다 먼저 본다)
   - `region.json.camera_zones`가 있으면 맨 뒤에 붙인다.
   - 확인: 스크린샷 로그에 `cam=22.0/40 운봉 읍치`가 찍힌다.
4. **안개(--nofog).**
   - 투어가 항목마다 `fog_on`을 덮어써서 `--nofog`가 무시됐다. 고쳤다.
   - 원경 셰이더의 거리 운해·안개빛도 `haze=0`으로 끈다.
   - 확인: `shots/region/stage3/nofog_check.png`(운봉 600m 위, 안개 없음). 맨 위 흰 띠는 권역 밖 하늘 그림판의 운해다.
5. **지연 짓기.**
   - footprint를 항목 → 키트 `static footprint(params)` → catalog.json(params 맞는 변형 우선) 순서로 정한다. 터 고르기·식생 비우기·마당 칠하기는 시작할 때 이것으로 한다.
   - 키트 짓기는 타일이 생길 때(중경 포함) 그 타일 항목만, 작업 스레드 그룹 작업(동시 2타일)으로 한다. 메인 스레드는 프레임당 8개씩 놓는다.
   - 시작 때 짓는 것: footprint를 모르는 것, layout 없는 배치형, 다리·징검다리·나루배·빨래터(walk·수면), 못(water). 지금 28개.
   - 시작 시간(`load_all`): 535항목 6.9s → **1081항목 1.4s, 1655항목 1.5s**.
   - 첫 화면 주변 25타일의 식생·키트가 다 붙기까지는 6~8s다. 백그라운드라 그동안도 화면은 돈다. 투어·벤치는 다 붙은 뒤 찍고 잰다.
6. **다리**: kit-village의 `walk` 배열을 그대로 쓴다(그래서 다리는 시작 때 짓는다). 진짜 배치의 다리 22개를 따라 걸어 본 결과는 아래 남은 문제 1.
7. **못 파기**: build 결과 `water {y, outline}`이 있으면(광한루원 연못) 테두리 안 땅을 물면 −0.95m로 판다(텍스처·height_at 둘 다). 걸어 들어가지 못하게 막고, 걷기 면 위는 예외다. 시작 때 짓는다(키트에 `static outline()`이 있으면 짓기 대상).
8. **식생 exclude**: kit-nature `scatter(…, exclude)`에 회전을 반영한 축 정렬 `Rect2`로 넘긴다. 집 묶음은 마당 포함 footprint, garden_plot·장터·광장도 clear_veg 항목이면 포함된다. 엔진 쪽 사후 거르기는 남겼다.
9. 가림 처리는 플레이어 50m 안 가림 물체만 검사한다(정적 물체 수천 개 대비).

## 비교 그림 (기본 게임 카메라)
- `shots/region/stage3/compare.png`: 줄마다 전/후. 남원 남문 앞 길, 운봉 읍치 마당, 남원 남쪽 마을 텃밭.
- 낱장: `before_nw/uw/mk.png`, `after_nw/uw/mk.png`.
- 전: 온통 누런 맨땅. 후: 풀밭 위에 흙길과 길섶, 건물 둘레 흙 마당, 텃밭·대숲.

## 성능 (조용할 때, 2048×1536, MSAA 4×, `--bench=25`, 같은 때 마을 장면 95fps)

| 장소 | 정적 물체 | 평균 fps | 최악 | p99 | 33ms 넘은 프레임 |
|---|---|---|---|---|---|
| 남원 읍내(spawn), 4.6m/s | 2,075 | **92** | 14.6ms | 13.0ms | 0 |
| 남원 출발 30m/s | 1,919 | 85 | 20.5ms | 15.6ms | 0 |
| 운봉 읍치(880,−700), 4.6m/s | 2,905 | 60 | 22.5~25.6ms | 20ms | 0 |
| 숲(2000,−300), 4.6m/s | 2,356 | 83 | 32.4ms | 20.4ms | 0 |

- 2단계에 남아 있던 33ms 넘는 프레임은 조용한 때 재니 0이었다(기기 부하였던 것으로 본다).
- 운봉이 60fps로 가장 낮다. 그리기 호출이 76으로 가장 많다. `--noshadow` 78, `--nopost` 119였지만 그 측정도 흔들렸다. 그림자 패스에 드는 정적 물체와 대숲이 원인 후보다.

## 남은 문제·요청
1. **다리 길이(배치 담당)**: 진짜 다리 22개 중 6개가 끝에서 막히거나 턱이 크다(시험 `shots/region/_t/t_walk2.gd`). 징검다리가 물길보다 짧거나 둑 높이 차가 크다.
   - 징검다리: `ea_br_ramcheon_unbong_ford_2`(턱 0.95m), `ea_br_x_baemsagol__r080_22`(턱 2.0m), `ea_br_x_inwol_bans_r075_14`·`r077_15`, `ea_br_x_tongyeong__r069_7`
   - 섶다리: `nw_cross_yocheon_east_ford`(턱 0.88m)
2. **kit-village house_compound `lod=1`**: 반경 2타일에서 가벼운 판으로 짓는 것은 아직 안 했다. 같은 항목을 두 벌 짓고 거리로 바꿔야 해서, 운봉 성능을 더 볼 때 하겠다.
3. **오작교**: 연못 안은 막혀 있어 오작교에 걷기 면(walk)이 없으면 못 건넌다. kit-landmark가 ojakgyo에 walk를 주면 연못 build 결과 walk로 합쳐 쓰겠다.
4. 실내 `interior.floor_y`는 아직 쓰지 않는다.

---

# 마무리

| 항목 | 한 일 | 결과 |
|---|---|---|
| 1a 키트 디스크 캐시 | `scripts/region/kit_cache.gd`. build() 결과를 `user://kit_cache/<md5>.scn`(노드·메시)과 `.info`(충돌체·조명·walk·anchors·interior.hide 경로)로 저장한다. 해시는 kit 경로+params+키트 파일+같은 칸 `_*.gd`+`kit.gd`. Kit 공용 재질은 파일에 넣지 않고 종류 이름만 적었다가 불러올 때 다시 붙인다. 저장은 메인 스레드에서 처음 놓을 때 한다(작업 스레드에서 메시를 저장하면 멈춘다) | 32MB. 1172개 중 1151개를 캐시에서 읽음(21개는 매번 지음) |
| 1b 시작 화면 | 한지색 바탕에 '설화록'과 진행 글(식생 타일·남은 건물). 반경 2타일 식생·건물이 다 붙으면 걷기 시작. 불러오는 동안은 작업 동시 수·붙이기 수를 늘린다 | **첫 실행 14.8s → 캐시 후 5.9~6.5s**. 캐시 후 시간은 대부분 지형·배치 불러오기 2.4s + 식생 흩뿌리기·키트 놓기 경합 |
| 2 숲 카메라 | 숲 구역이고 길(roads)에서 6m 넘게 떨어지면 55°·17m, 숲길은 48°·20m. 숲에서는 키트 점무늬 가림 반경 occ_r을 2.4에서 3.8로 | `final_forest_deep.png`(cam=17/55, 잎덩이를 점무늬로 비워 플레이어가 보임) |
| 3 실내 | 지붕을 숨긴 실내에서 벽 그림자가 드리운다. 실내에 들어가면 플레이어 머리 위 따뜻한 보조광(그림자 없음, 밤에 더 셈)을 서서히 켠다. `interior.floor_y`를 걷는 높이에 반영한다(마루·누각 위) | 광한루·동헌·객사 낮·밤 모두 보임(`final_interior_night.png`) |
| 6 밟힌 풀 띠 | 토지이용 길 칸(4)은 주변 토지이용 색으로 바꾼다. 길 색은 roads 칠하기(실제 폭)에서만 나온다 | 3칸 폭 띠 사라짐 |
| 7 숲 33ms 넘는 프레임 | 조용할 때 `--trace`로 숲 25s를 쟀다 | **avg 140fps, 최악 8.7ms, 0프레임**. 전에 보인 것은 기기 부하였다 |
| 14 붓 무늬 늘어남 | `kit.gd`: 삼각형마다 UV 1당 길이를 재서 2m(아틀라스 128px)보다 긴 면은 영역 안에서 반복한다. UV = 반복 좌표, CUSTOM0 = 아틀라스 영역. `materials.gd`: `kit_tiling=1`(Kit 재질만)이면 영역 안에서 fract와 textureGrad로 이음매 없이 읽는다. glTF 마을 재질은 0이라 예전과 같은 경로 | 성벽·담 확인. 기존 마을 refset 차이 1.2/2.3/1.4/5.0/1.2/18.8/4.1. 1단계와 거의 같고, 남은 차이는 총괄의 안개·점무늬 변경분으로 본다 |

그 밖: 시험용 `--gointerior=n`(불러오기가 끝나면 n번째 실내로)을 더했다. 공용 파일은 `scripts/kit/kit.gd`(Geo.rect, remap_uv, Batch.mesh의 CUSTOM0)와 `scripts/materials.gd`(kit_tiling) 두 곳만 고쳤다.

---

# 4단계 — 여러 권역·노정 · 전국 지도 · 기후대·날씨 (계약서 §10, 계획서 §2.1, TOWN_IDENTITY_CLIMATE_PLAN B2·B3·B4)

## 실행
```bash
godot --path . res://scenes/region.tscn -- --region=JJ_JEJU                 # 권역 고르기(기본 JL_NAMWON_UNBONG, --data도 그대로)
godot --path . res://scenes/region.tscn -- --route=<id> [--routedir=res://shots/region/test_route/]
godot --path . res://scenes/region.tscn -- --routedir=res://shots/region/test_route/ --portaltest=2 --weather=rain   # 포털 넘나들기 자동 시험
godot --path . res://scenes/region.tscn -- --weather=clear|cloudy|rain|fog|snow|wind     # 날씨 고정. 게임 중 U = 날씨 돌리기(…→자동)
```
그 밖: `--waitload`(불러오기 화면이 걷힌 뒤 --shot), `--openmap --mapmode=all|nation --winshot`(지도 찍기), `--shotdir`(portaltest 출력).

## 만든 것
| 파일 | 내용 |
|---|---|
| `scripts/region/travel.gd` (새) | 공간 목록·포털·넘어가기 예약. regions.json(없으면 region_data/*/region.json을 훑음), 노정 찾기(region_data/routes/ + --routedir), 권역 좌표→경위도, 노정 진행도, 간단한 한반도·제주 윤곽(경위도 꺾은선) |
| `scripts/region/weather.gd` (새) | climate.png 기후대 → 날씨 확률표·전환·젖음/눈 쌓임·기후대 빛 보정·입자 |
| `shaders/region_precip.gdshader` (새) | 비·눈·바람 티끌 입자(카메라 둘레 상자, 정점 셰이더가 움직임, 높이맵 아래 낱알 버림, 그리기 1번) |
| `scripts/region/tools/make_test_route.py` (새) | 시험 노정 `shots/region/test_route/TEST_PALLYANG/`(2048×384m 띠, 주막→고개·성황당(고산 기후대)→나루→장승, 배치 7개, 양 끝 포털 = 남원 동쪽 끝·북쪽 끝 고리) |
| `region_world.gd` | `region.json` 또는 `route.json`을 같은 방식으로 읽음(`is_route`, `K` = projection.K). scatter에 **이 공간의 roads를 7번째 인자로** 넘김(전에는 scatter가 남원 region.json을 직접 읽었음). `region.json.sea {y}`이면 바다 수면 한 장(제주) |
| `region_main.gd` | `--region/--route/--routedir`, 포털(장승 한 쌍 + "→ 목적지" 글씨, add_static 꼬리표 `portal`), 넘어가기, 날씨 연결(U, --weather), 시간대 상태 위에 기후대·날씨 보정(`_apply_atmo`) |
| `region_map.gd` | Tab: 도시(L3) → 권역(L2) → **전국(L0)** → 도시. 전국 지도 = 한반도 윤곽 + 권역 점 + 노정 선(route.json `geo_line` 또는 두 권역을 잇는 직선) + 지금 자리(권역은 투영으로 경위도, 노정은 주 도로 진행도로 선 위 보간). map.json이 없는 공간(노정·새 권역)은 길·물·고을·포털을 벡터로 그린다 |
| `place_title.gd` | 남원 TITLES는 그대로, 다른 공간은 settlement `title/short` 또는 이름 앞부분 |
| 공용 `materials.gd` · `sprite_char.gd` · `project.godot` | 전역 `wet`(0)·`snow`(0)·`snow_line`(1e5) 추가. Kit·glTF 재질(lit): 눈선 위·snow만큼 윗면(법선 y)부터 눈 덮기, 젖으면 어둡게. 캐릭터: 젖으면 조금 어둡게. 기본값이면 분기를 건너뜀 |
| `region_terrain/far.gdshader` | 젖은 땅(어둡게 + 평지·길 물웅덩이 하늘 반사), 눈 덮기(평평한 곳부터, 밟힌 길·마당은 흙이 비침, 붓 텍스처 유지), 원경 산도 눈선 위 하얗게 |

### 노정·포털 규칙(엔진 해석 — 데이터 담당과 맞출 것)
- `route.json` = region.json 형식 + `route_id, name, from_region, to_region, stops, portals{from:{region,x,z,name}, to:{…}}`, 선택 `geo_line:[[경도,위도]…]`(전국 지도 선), `climate_zone`.
- `portals.from.x,z` = **그 권역 안** 포털 자리(권역 좌표). 노정 쪽 자리는 `route_x/route_z`, 없으면 주 도로(가장 긴 대로)의 첫 점(from)·끝 점(to).
- 권역 쪽 포털은 노정 파일들에서 모은다. `region.json.portals:[{id,name,x,z,to}]`도 읽는다 — `to`는 `{route|region, x?, z?}` 또는 문자열 `"route:<id>"`·`"region:<id>"`(제주 형식), `"map_only"`는 넘어가지 않는다. 대상이 아직 없으면 "길이 아직 닦이지 않았다" 알림만.
- 포털 반경 5m에 들어서면 넘어간다. 도착은 맞은편 끝에서 길을 따라(없으면 공간 가운데 쪽으로) 16m 안쪽 빈자리, 12m 벗어나야 그 포털이 다시 켜진다.
- 넘어가기: 짧은 한지색 화면("○○ (으)로 가는 길…") → `placement.stop()`·`world.shutdown()`(식생 작업 기다림)·날씨 전역값 되돌림 → Engine 메타에 예약 → `reload_current_scene()`. 새 장면은 명령줄보다 예약을 먼저 본다(시각·날씨 고정·젖음/눈 이어받음). 키트 디스크 캐시·Kit 재질은 정적이라 이어 쓴다.

## 확인
- **포털 왕복**(`--portaltest=2 --weather=rain`): 남원 → 시험 노정 → 남원 북쪽 끝, 도착 화면 `shots/region/travel/travel_0/1/2_*.png`. 넘어갈 때 정리 확인: 남원을 떠날 때 389MB·노드 4.5k → 노정 198MB·노드 1.4k, 남원 재진입 343MB(키트 캐시 덕에 불러오기 1.5s). 고아 노드 3k는 떼어 둔 정적 물체(설계상)이고 장면을 지우면 같이 지워진다.
- **새 권역** `--region=JJ_JEJU`(data-east, K=0.28): 지형·식생·바다·포털(화북포 뱃길 → 아직 없는 노정) 정상. `shots/region/travel/jeju_*.png`.
- 기후대: 남원 climate.png = 남부 + 고산(지리산 고지). 눈선 = rule.alpine_alt_m(위도대) → y − 15m(남원 297, 제주 293). `w_jiri_snowline.png`: 맑은 날에도 지리산 고지만 잔설(나무 윗면·땅). 고산 칸에 들어서면 고산 확률로 날씨를 다시 고른다.
- 날씨 비교 `shots/region/weather/w_contact.png`(남원 남문 앞: 맑음·비·눈·안개).
- 지도 `shots/region/travel/map_nation_namwon.png`, `map_nation_route.png`(노정 위 자리), `map_route_all.png`(노정 벡터 지도).
- 마을 장면 `--refset` 웹 기준 차이 1.1/2.1/1.2/5.2/2.2/21.8/4.2 — 이전과 같음(village_day는 이전 결과와 픽셀 차 0). 기본값(wet=0·snow=0·snow_line=1e5)에서는 그대로.

## 성능 (2048×1536, MSAA 4×, `--bench=25`, 다른 에이전트와 같은 맥)
| 장소·날씨 | 평균 fps | p99 | 33ms 넘은 프레임 |
|---|---|---|---|
| 남원 spawn 맑음 | 110 | 19.9ms | 8 / 2745 |
| 남원 spawn 비(입자 7000 → 줄여 5000) | 104 | 32ms | 20 / 2604 |
| 남원 spawn 눈(4500) | 104 | 33.7ms | 24 / 2605 |
| 지리산 숲(2000,−300) 눈 | 119 | 11ms | 3 / 2977 |
| 시험 노정 비 | 123 | 8.5ms | 0 |
| 제주 화북 맑음(바다 포함) | 128 | 11ms | 1 |
목표 평균 55 이상은 모두 넘는다. 비·눈에서 p99가 맑음보다 높다(반투명 입자 겹침 그리기 — 비는 5000개로 줄였다).

## 기후대·날씨 값(weather.gd)
- 확률: 남부 맑음 .42·흐림 .22·비 .24·안개 .12 / 중부 + 눈 .08·강풍 .03 / 북부 눈 .40·맑음 .25 / 고산 눈 .28·안개 .25·강풍 .12 / 해안섬 해무 .30·강풍 .10. 120~260초마다, 기후대가 바뀌면 다시 고른다. 전환 약 10초.
- 젖음: 비 40초에 젖고 2분에 마름(안개는 0.3까지). 눈: 1분에 쌓이고 5분에 걸쳐 기후대 바탕(북부 0.55)으로 녹음.
- 빛(B3): 남부 해 따뜻·안개 ×1.12·채도 ↑ / 북부 해 차갑게·세기 0.9·**해 높이 ×0.62**·채도 0.88·후처리 gain 차갑게 / 고산 차갑고 안개 ×1.2 / 해안 안개 ×1.25·푸른 회색. 흐림·비는 해 세기·채도·번짐을 줄이고 하늘·안개를 회색으로, 반구광은 고르게. 눈이 쌓이면 땅 되비침을 밝고 차갑게.

## 남은 문제·요청
1. **노정 데이터 형식**: 위 '노정·포털 규칙'을 data 담당이 확인해 주길(특히 portals x,z가 권역 좌표라는 점, 노정 쪽 끝은 주 도로 끝). 진짜 노정이 오면 `--portaltest`로 바로 시험할 수 있다. 시험 노정 `shots/region/test_route/`는 그때 지워도 된다.
2. **regions.json**이 아직 없다 → 엔진이 region_data/*/region.json을 훑어 이름·투영 기준점으로 대신한다. `map_pos`는 0~1(전국 지도 상자 비율, 위가 0) 또는 경위도로 읽는다.
3. **kit-nature scatter.gd**: 엔진이 이제 roads를 넘기므로 `ROADS_JSON`(남원 고정) 기본값은 안 쓰인다. 수종 고도(`forest_mix(alt)`)가 y에서 해발을 거꾸로 낼 때 K=0.30을 가정한다면 권역 K(제주 0.28, 한양 0.5)를 받아야 한다 — 엔진에서 넘길 인자가 필요하면 말해 달라.
4. 제주 climate.png는 제주성(해안)도 남부(0)로 나온다 — 해안섬(4) 판정은 data-east 쪽 확인 필요.
5. 비 오는 동안 지붕 아래로도 빗줄기가 지나간다(높이맵만 보고 버림). 실내에 들어가면 입자를 끈다.
6. 원본 명세 v0.3 §31(L0~L3)은 지도 단계(도시 L3·권역 L2·전국 L0)로 맞췄다. L1(팔도) 단계는 전국 지도를 확대하면 되지만 도 경계 자료가 없어 그리지 않았다.

---

# 5단계 — 바다·호수·하천 폭 (terrain-data §16 엔진 요청)

## 만든 것
| 파일 | 내용 |
|---|---|
| `shaders/region_sea.gdshader` (새) | 바다·호수 수면 하나의 셰이더. 평평한 판(바다 = `sea.y`, 호수 = `lakes[].y`)에 높이맵으로 수심을 내어 **물가선 = 땅 높이와 수면이 만나는 곳**(땅 위는 버림 → 물가에서 깜박임 없음). 물가 바로 앞 흰 물거품(붓 텍스처로 끊김) + 땅 쪽 옅은 먹선, 얕은 물가는 옥빛·반투명, 먼 바다는 짙은 쪽빛. 바다는 물결 띠가 물가 쪽으로 천천히 밀려옴(약하게). 빛·안개는 region_water와 같은 툰 규칙(붓 바림 램프, 반구광, 같은 안개·물안개 식) |
| `region_world.gd` | 예전 제주 바다(하천 재질을 복사한 판 한 장, 물가 표현 없음)를 바꿨다: `_build_sea()`가 바다 판 + 호수 다각형(`Geometry2D.triangulate_polygon`)을 만든다. **물 가림 텍스처**(토지이용 격자 4m, RG8): R = 바다 칸(물(5) 칸 중 `sea.y`+0.15 아래, 호수 윤곽 밖, 32m 밉에서 바다 비율 27% 미만인 좁은 물길 제외), G = 뭍. 바다 판은 R로 호수 바닥·하구 하천 바닥·지도 밖 뭍 쪽을 버리고, G의 밉맵(16·64·256m 흐림)으로 '물가 가까움'을 낸다(데이터 바다 바닥은 거의 평평한 −0.42~−0.45m라 수심만으로는 얕은 띠를 못 낸다). 지도 밖은 가장자리 칸이 이어지므로 바다 쪽 가장자리에서만 수평선까지 물이 보인다 |
| 〃 하천 폭 | `rivers[].widths`(점별)가 있으면 그 폭(최소 1.6m), 없으면 예전대로 `max(width_m, 5.2)`. 데이터 폭은 구간 계단(2.5 → 7 → 15)이라 ±8점(약 60m) 상자 평균 두 번으로 조금씩 넓어지게. 폭은 다시 뽑기(3m)와 걷기 막기 선분 반경에도 점별로 들어간다. **호수 안 구간은 물 띠를 그리지 않는다**(호수 수면이 덮음) |
| 〃 걷기 | 호수 윤곽 안이면서 땅이 호수면 −0.05 아래면 막음. 바다 수면 −0.15 아래 땅(토지이용이 물이 아닌 바다 밑 바위·모래 칸)도 막음. 새 API `is_sea(x,z)`, `lake_at(x,z)`, 필드 `sea_y`, `lakes`, `water_mask`, `sea_map` |
| `region_map.gd` | 바다(물 가림 R을 LA8로, 바다색 + 네 방향으로 민 짙은 판 = 물가 먹선), 호수(다각형 + 먹선 + 이름), 용천수(도시 축척 점·이름), 오름(반원 기호·이름, 권역 확대 때), **읍성 성벽**: 배치에 `*_eupseong` 키트가 있으면 params `side`/`size`/footprint 사각형, 없으면 region.json 랜드마크 `size_m` 사각형(제주성 280×230·경주읍성 150 — 지금 지도에 나옴). 전에는 남원 외 읍성 키트가 지도에서 150m짜리 기와 지붕 네모로 칠해질 뻔했다 |

## 확인 (`shots/region/water/`)
- 제주 화북 해안 `jeju_hwabuk_coast_high.png`(높은 시점, 안개 끔)·`jeju_coast_game.png`(게임 시점): 현무암 해안선을 따라 흰 물거품 + 먹선, 얕은 물가 옥빛, 물결 무늬.
- 강릉 경포호 `gangneung_gyeongpoho_high.png`: 호수 수면·윤곽, 동해 바다·모래 해안, 하구 물길은 바다로 칠하지 않음. 남대천 `gangneung_namdaecheon_taper.png`: 위(상류 2.5m)에서 아래(7m)로 점점 넓어짐.
- 지도 `map_gangneung_all.png`(동해·경포호), `map_jeju_city.png`(바다·제주성 성벽·산지물 용천수).
- 남원(JL_NAMWON_UNBONG): `sea`·`lakes`·`widths`가 없어 같은 코드 경로(바다 만들기 건너뜀, 폭 `max(width_m,5.2)`, 하천 띠 한 줄 그대로) — 모습 그대로, 오류 없음.
- 불러오기 비용: 물 가림 0.17~0.41s(제주 2081×993 칸, 다른 에이전트와 같은 맥).

## 성능 (2048×1536, MSAA 4×, `--bench=25 --weather=clear`)
| 장소 | 평균 fps | p99 | 33ms 넘은 프레임 |
|---|---|---|---|
| 제주 화북 해안(바다 화면 절반) | 103.8 | 11.1ms | 0 / 2595 |
| 강릉 경포호 물가(호수·바다) | 103.5 | 11.2ms | 0 / 2588 |
| 남원 spawn | 110.3 | 11.1ms | 0 / 2758 (이전 110과 같음) |

## region.json 새 필드 처리 상황
| 필드 | 처리 |
|---|---|
| `sea {y, share}` | 3D 수면·물가, 지도, 걷기 막기 |
| `lakes [{y, outline}]` | 3D 수면, 지도(이름), 걷기 막기, 호수 안 하천 띠 생략 |
| 하천 `widths` | 3D 물 띠 폭·걷기 막기(계단 완화). `reaches`는 쓰지 않음(widths와 같은 정보) |
| `springs` | 지도만(점·이름). 3D 물터는 배치(키트) 몫으로 남김 — 엔진이 물 원판을 깔면 키트와 겹친다 |
| `oreums` | 기복은 이미 height에 구워져 있음. 지도에 기호·이름 |
| 읍성(`landmarks.size_m`) | 지도 성벽 사각형. region.json에 `walls` 필드는 없다(3D 성벽은 키트 몫) |
| `portals`, `culture` | 4단계에서 처리(portals) / 쓰지 않음(culture — place_title·배치 쪽) |
| `hydro`, `build`, `qa` | 정보용, 엔진은 쓰지 않음 |

## 남은 문제·요청 (data 담당)
1. **경포호 안 위촌천 제방**: 위촌천(r001)·지류(r032)가 호수를 가로지르는데, DEM에 하천 양옆 둑 칸(+0.8~1.3m)이 호수 안에 남아 호수면 위로 두 줄 계단 모양으로 드러난다(`gangneung_gyeongpoho_high.png` 가운데 사선). 호수 윤곽 안은 높이를 호수 바닥으로 눌러 주길(하천은 호수 들머리·날머리에서 끊어도 엔진은 괜찮다).
2. 경포호 윤곽과 DEM이 조금 어긋난다: 윤곽 남쪽 바깥에 호수면보다 낮은 밭 칸이 있다(경계가 직선으로 잘려 보임). 1870년 더 넓은 호수(가설)로 바꿀 때 같이 맞추면 된다.
3. **제주 건천**: 하천이 비 올 때만 흐르는 건천인데 엔진은 물 띠를 그린다. 하천에 `dry: true`(또는 `flow: "intermittent"`) 같은 표시를 주면 마른 돌 바닥(물 없음, 비 올 때만 물)으로 그리겠다.
4. 남원에는 `widths`가 없어 하천 폭이 예전처럼 일정하다(명세 §6 "일정한 폭" 금지). 같은 형식으로 넣어 주면 엔진은 그대로 따른다.
5. 하구: 해수면 아래 하천 바닥은 바다에서 빼고(32m 열림) 하천 띠가 덮는다. 강어귀 끝 몇 m는 하천 띠(y≈0.01)와 바다 판(0)이 겹친다 — 하천 마지막 점 y를 `sea.y`보다 0.05 이상 높게 주면 깔끔하다.
6. 모래·자갈 칸 중 해수면 −0.15 아래는 이제 걸어 들어가지 못한다(바다 밑). 포구 배치가 그런 칸에 물체를 두면 알려 달라.

# 6단계 — 큰 강 · 성곽 · 건천 · 위도 띠 (terrain-data-north §5, data-east 건천 요청)

## 만든 것
| 파일 | 내용 |
|---|---|
| `region_world.gd` 큰 강 | `sea.kind == "river"`(한강·대동강)이면 같은 바다 판(`region_sea.gdshader`)을 **강 모드**로: 판은 높이맵 범위까지만(바다처럼 3km 밖 수평선으로 뻗지 않음), 강 빛깔(옅은 녹빛), 흰 파도 띠 없음·물가 거품 ¼, 호수처럼 고요한 물가. **흐름 지도**: `render:false`/`spec_grade S` 하천 중심선(점 순서 = 하류)을 32m 칸에 찍고 BFS로 번지게 한 뒤 세 번 흐려 RG8 → 셰이더가 두 위상 flow-map으로 결을 하류로 0.6m/s 민다(+ 결을 따라 옅은 물비늘). 섬(능라도·양각도·노들)은 원래대로 뭍. 큰 강 중심선은 **리본·걷기 막기 선분을 만들지 않는다**(물면·걷기는 sea 경로가 맡음) |
| 〃 나루 뱃길 | crossings `type:"나루"` + `ends[2]`인 나루마다 양 끝을 잇는 **걷기 면**(물 면 +0.32m 갑판, 반폭 1.9m, 양 끝 4m는 둑 위로)을 깐다. 나룻배(`kit/village/narutbae`) 한 척이 플레이어가 뱃길 물 위에 있는 동안 발밑을 따라오고 내리면 그 자리에 남는다(`update_ferries`, region_main이 매 프레임 부름). 그 나루와 `part_of` 표지점은 '물에 걸어 들어가기 허용(_near_crossing)'에서 뺐다 — 큰 강 바닥으로 빠지지 않게. 다리는 없다(명세 §6) |
| 〃 성곽 `walls` | **결정**: 지도에는 늘 그리고, 3D는 **배치 키트가 덮지 않은 구간만** 싼 돌벽(대신 벽)을 깐다. 성벽 선을 4m로 다시 뽑아, 배치(_pending)에 있는 성벽·문 키트(`*wall*`·`*seong*`·`*gate*`·`*mun`·`*eupseong*`, 관아·집 담 제외) 자리 반경(footprint 반 + 3m) 안이면 '덮임'. 문(`gates` 랜드마크 9m 안)·길(칠하기 거리 2.5m 안)·물(토지이용 5) 위는 비운다. 남은 구간은 48m 조각(add_static, `wall_proxy` 태그, 타일 스트리밍·가림 occluder)으로: 두께 4m, 높이 `height_m` [산, 평지]를 경사로 섞고, 바깥(닫힌 선은 넓이 부호로)에 1.1m 여장(타구 틈). 원형 충돌체 2m 간격, 둘레 6m 식생 비우기. 배치 다시 읽기(F5) 때 다시 계산. 끄기 `--nowallproxy` |
| 〃 건천 | `rivers[].dry == true` 또는 `flow == "intermittent"`(제주 38개 전부): 걷기 막기 선분 없음 + 토지이용 물(5) 칸 중 중심선 둘레(폭/2+6m)를 `dry_mask`로 표시 → **걸어서 건넌다**. 리본(폭 0.8배, 최소 2.4m)은 `region_water` dry 모드: 현무암 자갈 + 둥근 바위(밝은 윗면·먹빛 테). 비가 오면(`wet_level` ← weather.wet, 0.35→0.85) 돌이 어두워지고 가운데에 물줄기가 드러난다. 지형 셰이더도 `dry_tex`로 건천 칸을 돌 바닥 색으로(넓은 바닥용 — 제주는 4m 한 칸 폭이라 거의 리본이 보임) |
| `weather.gd` 위도 띠 | 기본 기후대 순서: `climate_zone` → **`climate.band`/`climate.rule.band`(새, 덮어쓰기)** → (둘 다 없으면) **climate.png의 남부·중부·북부 칸 중 가장 많은 것** → 위도. 눈선 위도대도 같은 띠를 쓴다. 황주(38.7°N)는 데이터가 climate.png를 중부로 칠해 두었으므로 이제 `zone=central`(전에는 north) |
| `region_map.gd` | `walls` 꺾은선을 성벽 선으로(도시 축척), 큰 강은 바다보다 녹빛 `RIVER_COL`, 나룻배 뱃길(`*ferry*` 길)은 물 위 점선 |
| `region_world.river_surface_at` | 큰 강·바다 칸이 가까우면 `sea.y`, 호수 안이면 호수 면 — 나루 배치(나룻배·빨래터) 높이에 쓰인다 |

## 확인 (`shots/region/stage6/`)
- `hanyang_noryang_high.png`: 노량진 나루 — 한강 물면(녹빛, 파도 띠 없음), 뱃길 위 나룻배에 탄 플레이어. `pyeongyang_daedong_high.png`: 대동강·대동문 앞 나루, 배치된 성안 마을과 대신 벽(강가 내성·남쪽 중성). `hanyang_wall_proxy.png`: 동쪽 성벽 대신 벽(여장).
- `jeju_dry_clear.png` / `jeju_dry_rain.png`: 산지천 — 맑을 때 마른 돌 바닥, 비 올 때 가운데 물줄기.
- 남원(JL_NAMWON_UNBONG)·제주: sea.kind·walls·big river가 없거나 바다라 경로가 그대로(제주 바다 kind=sea, 남원 zone=south) — 제주 하천만 건천으로 바뀜(요청대로).
- 기록: 한양 walls proxy 8840m·덮임 0m·틈 264m·188조각 0.9s, 평양 2040m·덮임 144m(배치가 놓은 성문·성벽 구간)·60조각 0.2s, 함흥 924m·덮임 24m.

## 성능 (2048×1536, MSAA 4×, `--bench=25 --weather=clear`, spawn에서 달리기)
| 권역 | 평균 fps | p99 | 33ms 넘은 프레임 |
|---|---|---|---|
| GG_HANYANG | 120.0 | 8.3ms | 0 |
| 한양 동쪽 성벽 옆(812,−1180) | 108.5 | 14.3ms | 0 |
| PA_PYEONGYANG(배치 2977개) | 109.5 | 9.7ms | 0 |
| JJ_JEJU | 119.5 | 9.0ms | 0 |
| JL_NAMWON_UNBONG | 119.7 | 8.8ms | 0 |

## 남은 문제·요청
1. **큰 강 중심선 방향**: 점 순서를 하류로 가정했다(한강·대동강 모두 동→서라 맞음). 다른 큰 강을 넣을 때도 점을 하류 순으로.
2. 나룻배는 한 척이 플레이어를 따라온다(반대편에서 타면 배가 그쪽으로 옮겨 온다 — 사공이 저어 온 셈). 배치가 선착장에 둔 나룻배와 별개다.
3. 대신 벽은 문 키트가 없을 때 문 자리를 그냥 비운다(9m 틈). kit-landmark 성벽·문이 배치되면 그 구간은 자동으로 빠진다. 한양 인왕산 쪽 작은 꺾임은 데이터 선 그대로.
4. (data-north) 노들섬 자리는 물(모래톱 가설) — 한강 뱃길이 지금 노량진 380m 한 번에 건넌다.
5. 건천 칸이 4m 한 칸 폭이라 지형 셰이더 돌 바닥은 거의 안 보인다(리본이 대신). 넓은 건천 바닥을 원하면 토지이용 모래·자갈(8) 띠를 둘러 주면 된다.

# 7단계 — 노정 포털 정리 · 걷기 시험 · 배 높이 (routes §6 엔진 요청)

| 요청 | 처리 |
|---|---|
| 1. 포털 중복 | `Travel.portals_for`(권역 쪽): region.json `portals` 중 노정 파일에서 이미 만든 포털과 **같은 종류·같은 대상·10m 안**이면 버린다(노정 쪽 것이 도착 자리를 갖고 있어 그것을 남김). 한양은 이제 6개(노정 파일 5 + 겹치지 않는 region.json 한강진→경주 1) |
| 2. 도착 끝 | region.json 포털로 노정에 들어갈 때 `to`에 x,z가 없으면, 그 노정의 portals에서 **이 권역이 붙은 끝**(from/to, 양쪽 다면 포털 자리에 가까운 끝)의 `route_ends` 자리를 도착 자리로 쓴다. 전에는 노정 spawn(from 끝)이라 to 끝 권역(함흥 등)에서 들어가면 반대편에 떨어졌다. 이름 없는 포털은 노정 이름을 label로 |
| 3. 전국 지도 짧은 이름 | `Travel.routes()`가 route.json `short`(없으면 이름 앞부분 — `·`·공백·`(` 앞)을 `short`로. 전국 지도는 지금 노정만 긴 이름, 나머지는 short. 고을 점·이미 쓴 글자와 겹치면 선을 따라 0.5→0.35→0.65→0.2→0.8 자리로 옮기고, 끝내 겹치면 안 쓴다 |
| 4. 노정 걷기 시험 | `--walkroute[=n] [--walkspeed=12]`(`--portaltest` 확장, n 뜻 같음: 1이면 2): 노정 공간에서는 순간이동 없이 **주 도로(Travel.main_road)를 플레이어 쪽 끝부터 끝 포털까지** 걷는다(6m 간격 길 점, 다른 포털은 걷는 동안 잠금). 1.5초 넘게 못 움직이면 `WALK stuck #k at (x,z) wp lu near=물/물체/경사·가장자리`를 남기고 다음 길 점으로 옮긴다. 끝에 `WALK done dist time stuck skipped`. 권역 공간에서는 예전처럼 가장 먼 포털로 |
| 5. 배 높이 | `placement_loader._y_for`: `village/narutbae`는 손으로 적은 `y`보다 `world.river_surface_at`(하천·호수·**바다**·큰 강)을 먼저 따른다(40m 안에 물이 없을 때만 y·지형). routes의 `"y": 0.0`은 빼도 되고 둬도 된다 |

## 확인
- `--route=GG_HANYANG-HH_HWANGJU --walkroute=2 --walkspeed=20`: 의주대로 455점 3595m를 185s에 걸어 황주 도착, 막힘 3번(출발 포털 장승 곁 1, 길 점 79·83 근처 2 — 하나는 물 칸, 건너뛴 거리 38m) → 황주 → 장산곶 노정까지 이어짐. 출력 그림 `shots/region/stage6/walk/`.
- 그 실행 중 황주 도착 직후 `Out of bounds get index '2'` SCRIPT ERROR가 3번 났는데, 같은 경로를 `--portaltest`로 다시 돌리고 황주를 직접 열었을 때는 재현되지 않았다(같은 때 배치·place_title 쪽 파일이 고쳐지던 중 — 다시 보이면 알려 달라).

## 남은 것
- **노정 갈림(영흥·정평 합류)은 하지 않았다.** 지금 노정은 두 끝 공간 하나씩이라, 갈림을 하려면 route.json에 세 번째 끝(`portals.branch:{route, route_x, route_z}`)과 노정→노정 넘어가기가 필요하다(Travel.portals_for의 노정 쪽에 end 목록을 일반화, 도착 자리 계산은 2번과 같음). 데이터 쪽이 형식을 정하면 엔진은 반나절 일.
- 걷기 시험은 빠르게(20m/s) 걸으면 배치 지연 짓기보다 앞서 가 아직 안 놓인 물체(장승·담)를 지나칠 수 있다 — 막힘 검사를 엄격히 하려면 `--walkspeed=4.6`.
