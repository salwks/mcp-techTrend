# 물 — 물결과 반사 (water pass, 2026-10-17)

요청: 설화록의 물을 **실제 반사와 물결**로 더 그럴듯하게. 그림 결(3D 땅 + 손그림 인물, 한지·먹)은 지키고, 번들거리는 사진 물은 피한다.
중간 지시(사용자): 민화식 물결 줄(water.png)과 그린 물결 띠는 새 물에서 걷는다. 물가 먹선은 따로 켜고 끌 수 있게 두고 기본은 끈다. 제목 화면 물(title_wp_water)·지도는 그대로.

## 1. 확인한 기존 구현 및 문제점

물은 다섯 갈래였다.

| 종류 | 그리는 곳 | 셰이더 | 어디에 |
|---|---|---|---|
| 하천 띠 | `region_world._river_chunk` — region.json `rivers`를 3m 간격 띠로(가로 꼭짓점 2개뿐) | `region_water.gdshader` | 요천·냇물 전부(남원 92줄), 건천(제주)은 같은 재질의 돌 바닥 |
| 바다·호수·큰 강 | `_build_sea` — 16×16 평판, 큰 강은 32m 칸(안쪽 불투명/물가 반투명) | `region_sea*.gdshader` + `region_sea_body.gdshaderinc` | 강릉·경주·제주 바다, 경포호, 한강·대동강 |
| 키트 물 | 키트 'water' 키(공용 반투명 재질 + water.png) | `Materials.world_shader(blend)` | 광한루 못, 경회루 못, 폭포 소, 빨래터 |
| 논물 | `farm.gd` | `region_paddy_water.gdshader` | 논 필지 |
| 물 반짝임 | `ambient_fx.gd` | 더하기 섞기 MultiMesh | 둘레 34m 물 칸 |

문제점
- **반사 없음.** 환경 반사광이 꺼져 있고(`REFLECTION_SOURCE_DISABLED`) 물도 하늘빛 근사가 없었다(논물만 하늘빛 두 단). 물이 둘레를 비추지 않아 "칠한 판"으로 읽혔다.
- **물결이 그림뿐.** 꼭짓점은 움직이지 않고, water.png(민화 물결 줄)를 흘리거나 바다는 물가 등치선 따라 흰 띠(band)를 그렸다. 띠 꼭짓점이 가장자리 2개뿐이라 꼭짓점 물결을 넣을 자리도 없었다.
- 바다 판은 1km 칸이라 너울을 꼭짓점으로 낼 수 없다.
- 배는 `sin()`으로 따로 흔들렸다(물과 무관).
- 물가: 바다는 높이맵 수심으로 흰 띠·먹선이 있었으나 4m 칸 계단 물가선이 흰 선으로 강조됐다. 하천 띠는 수심을 몰랐다(UV 가장자리만 옅게).

## 2. 유지·수정·신규

| 구분 | 무엇 |
|---|---|
| 유지 | **Mobile 렌더러**, 후처리(한지·깊이 흐림·먹 그늘·먹선)·안개 식·반구광 EMISSION 구조, 카메라 값(이번 작업 중 카메라 담당이 22°·×0.64로 바꾼 값 그대로), 물 메시 자리·수면 높이·걷기 막기, 큰 강 불투명/반투명 나누기, 건천 돌 바닥, 물 반짝임 VFX(해 반짝임과 겹치지 않고 물결 위 작은 빛점으로 어울려 그대로 둠), 제목 화면 물·지도·논물 |
| 수정 | 하천·바다·키트 물 셰이더(물결 줄·그린 띠 걷음), 하천 띠 가로 4칸 + 흐름 TANGENT, 배 놓기(물결을 탄다), 농사 물꼬는 하천 재질 복사본 |
| 신규 | `scripts/region/water_fx.gd`, `shaders/water_common.gdshaderinc`, `shaders/kit_water.gdshader`, 바다 물결 판, 평면 반사, 물 층·작은 물체 층·원경 층, 인자 `--nowaterrefl --nowaves --waterink --reflfar --refldiv --reflrate --fpyaw --watershots --waterdebug` |

### 반사 — 평면 반사(a)를 골랐다

- **방법:** 거울 카메라를 물면(y)에 비춰 1/2 해상도 SubViewport(장면 뷰포트와 같은 world_3d, MSAA 끔)에 그린다. 물 셰이더는 반사 카메라의 투영 행렬(`water_refl_m`)로 자기 자리를 투영해 그 그림을 읽고, 물결 법선만큼 흔든다(먼 곳일수록 덜).
- **거울면 높이:** 0.25초마다 플레이어 둘레 25m 안 못이 있으면 못 높이, 아니면 `river_surface_at`(하천·바다·호수, 70m). 물면 높이가 거울면에서 0.35~0.9m 넘게 다르면(경사진 냇물 먼 곳·다른 못) 그 물은 하늘빛 반사로 부드럽게 넘어간다.
- **안 그리는 때(UPDATE_DISABLED):** 70m 안에 물이 없을 때, 실내, 불러오기 중, 창이 포커스를 잃어 배경 fps를 낮출 때(`region_main._fg_max_fps`), 카메라가 물면보다 낮을 때, 화면 품질 '낮음'.
- **비용 줄이기(측정으로 정함):**
  - 2프레임에 한 번 그린다(그 사이엔 지난 그림과 그때 행렬 — 자리는 맞고 한 프레임 늦을 뿐). 1인칭에서 고개를 초당 60° 넘게 돌리면 매 프레임.
  - 3인칭은 반사 먼 끝 140m·원경 능선 고리 뺌. 1인칭은 200m·해상도 1/3.
  - 3m 안 작은 정적 물체(장독·소쿠리·장작…)는 `SMALL_LAYER`로 — 반사 카메라만 그리지 않는다.
  - 물 메시는 `WATER_LAYER` — 반사 카메라가 물 자신을 그리지 않는다. **반사 그림을 읽는 재질은 물 층 메시에만 둔다**(같은 그림을 그리며 읽으면 Metal 오류: 처음에 논 물꼬가 하천 재질을 같이 써서 났다 → 물꼬는 복사본). 키트 못은 `add_static`에서 물 표면을 물 층 메시로 떼어 `water_refl` 재질을 준다.
- **(b) 화면 공간 가짜 반사는 넣지 않았다:** 반투명 물에서 화면 텍스처를 읽으면 Mobile에서 복사 한 번이 더 들고, 3인칭 32°→22° 시점에선 물에 비칠 물체(둑 위 나무·집)가 화면 밖이라 거의 하늘만 나온다. '낮음'은 하늘빛 반사 + 프레넬 + 해 반짝임.
- **인물(2D 판):** 판이 카메라를 보는 방향 그대로 거울 카메라에도 서 있어 위아래 뒤집힌 모습으로 비친다(`naru_fp*`). 1인칭에서는 본 화면처럼 플레이어 그림 층을 뺀다.
- **언제나:** 프레넬(그림용으로 조금 올림 0.14~0.98 — 3인칭에서도 둑이 비쳐 읽힘)로 반사와 물빛을 섞는다. 물빛은 수심으로(깊으면 짙은 푸른 녹색, 얕으면 바닥 빛과 반투명). 해 반짝임은 `light()`의 SPECULAR — 실제 해 방향(visual-pass 서남 볕)·그림자(ATTENUATION)·밤엔 달·등불을 따르고, 단단한 점으로 끊어 툰 결.

### 물결

- **꼭짓점 물결:** 네 갈래 사인 물결의 합(파장 21·12.5·7.3·4.1m × 종류별 배율, 바람 방향으로 돌림). 바다 0.20m, 큰 강 0.035m, 하천 0.022m(소는 덜, 여울은 더), 못 0.012m. 바람(weather `wind`)이 세면 커진다(바다 ×0.75~2.15).
- **바다 물결 판:** 256m 네모(2m 격자), 카메라 초점 앞쪽을 따라 8m 단위로 끊어 옮긴다(꼭짓점이 미끄러지지 않게). 가장자리 32m는 물결을 0으로 줄여 먼 판과 높이가 맞고, 먼 판은 그 네모 안을 버린다(`hole`). 얕은 물가(수심 4m 안)는 너울을 줄인다.
- **잔물결:** 이음매 없는 잡음 법선 지도 두 겹(16m·6.5m)을 하천은 흐름(TANGENT) 쪽으로, 큰 강은 흐름 지도(flow_tex, 두 위상), 바다·못은 바람 쪽으로 흘린다. 60~70m 크기 바람 자국(거친 곳·잔잔한 곳)이 천천히 옮겨 가 반사가 군데군데 흐려지고 맑아진다.
- **물가:** 하천은 높이맵 수심으로 얕은 곳 바닥 빛·반투명, 물가선에 끊긴 젖은 테. 바다는 너울 마루가 닿을 때마다 거품 띠가 넓어졌다 빠지고(swash), 잔물결 높이로 성기게 끊어 그린 선이 아니게 했다. 바람 센 날 먼 너울 마루에 흰 물결.
- **비:** `water_rain`(weather `rain`)만큼 1.1m 칸마다 퍼지는 빗방울 고리(`naru_fp_rain.jpg`).
- **배:** `WaterFX.boat_xf` — 셰이더와 같은 식·같은 시각(`water_t`)으로 높이(×0.7)와 2m 떨어진 두 점 기울기 평균으로 기운다. 나룻배·뱃길 배(boat_ride)·오가는 배(river_lanes)·region_world 나룻배.
- **물가 먹선:** `water_ink` 전역(기본 0). `--waterink`로 켠 화면을 같이 찍었다(`*_ink_on.jpg` — 끈 것은 같은 이름에서 `_ink_on`을 뺀 것).

## 3. 수정 파일과 주요 변경

| 파일 | 변경 |
|---|---|
| `scripts/region/water_fx.gd`(새) | 전역 uniform 실행 중 등록(project.godot 안 건드림 — 편집기가 덮어쓰지 않게), 잔물결 법선 지도, 물결 식 `wave()`·`boat_xf()`, 평면 반사(거울 카메라·주기·크기·층), 바다 물결 판 옮기기, 촬영 보조(`--fpyaw`·`--watershots`), 벤치 GPU 측정 시도 |
| `shaders/water_common.gdshaderinc`(새) | `w_wave`·`w_detail`·`w_gust`·`w_rain`·`w_reflect`·`w_fresnel`·`w_fog`·`WATER_LIGHT`(확산 램프 + 해 반짝임) |
| `shaders/region_water.gdshader` | water.png 걷음, 꼭짓점 물결, 흐름 잔물결, 수심(region_common r_hdata), 여울 흰 물살(잡음), 반사·프레넬·반짝임, 먹선 토글, 건천 그대로 |
| `shaders/region_sea_body.gdshaderinc` + `region_sea*.gdshader` 넷 | water.png·band 걷음, 물결 판 꼭짓점·hole, 잔물결·바람 자국, swash·흰 물결, 반사, `specular_disabled` 뺌(반짝임) |
| `shaders/kit_water.gdshader`(새) + `scripts/kit/kit.gd` | 키트 'water'·'water_refl' 재질 — 누운 면은 못 물, 선 면(폭포)은 아래로 흐르는 흰 물줄기 결 |
| `scripts/region/region_world.gd` | 하천 띠 가로 4칸·TANGENT, `mat_water` 수심 값, 물 층, `surface_mats`, 바다 물결 판(`sea_patch`·`sea_far_mat`), 큰 강·호수 물결 값, `_split_water`(키트 못 → 물 층), `_mark_small`(작은 물체 층), 나룻배 물결 |
| `scripts/region/region_main.gd` | WaterFX 만들기(`--nowater`면 안 만듦), 인자 설명, `watershots`를 자동 실행 목록에 |
| `scripts/region/farm.gd` | 물꼬 재질 = 하천 재질 복사본(반사 그림 없음) |
| `scripts/region/kit_cache.gd` | 디스크 캐시가 `water_refl` 재질도 이름으로 저장 |
| `scripts/region/boat_ride.gd`·`river_lanes.gd` | 배 놓기를 `WaterFX.boat_xf`로 |

## 4. 실행한 테스트와 결과

| 시험 | 결과 |
|---|---|
| 관련 묶음 `run_story_tests.sh -j 2 walk:hangang-boat travel:boat-priority travel:boat-skip travel:sea-waymark station:namwon ride:namwon-unbong view:namwon` | **7/7 PASS**, SCRIPT ERROR 0 (walk:hangang-boat `stuck=1`은 예전 로그 6번과 같음) |
| 전체 `tools/run_story_tests.sh -j 3` (`/tmp/seolhwa_tests/water_full`) | **94/94 PASS**, 로그에 SCRIPT ERROR 0 · 반사 그림 충돌 오류("same texture in framebuffer") 0 |
| `tests/camera/camera_view_test.gd` · `tests/save/save_guard_test.gd` | CAMVIEWTEST PASS 30 · SAVEGUARDTEST PASS 31 |

모든 실행은 `--` 뒤 게임 인자 + `--savefile=user://water_*.json`(모래상자)이다. 실제 저장 폴더·백업은 건드리지 않았다.

### 4-1. 성능(제자리 12초 `--bench=12 --benchspeed=0`, 맑음 11시, `--nostory`)

전(옛 물)은 같은 커밋에서 물 파일만 HEAD 이전 것으로 되돌린 복제본(copy-on-write)으로 쟀다. 카메라는 둘 다 지금 값(나루는 '집 둘레' 22°).

| 곳 · 해상도 | 전 fps · p99 | 후 fps · p99 | 비고 |
|---|---|---|---|
| **요천 나루 1920×1080(마을 구도)** | 104.2 · 9.7ms | **94.7 · 10.6ms** | 반사 켬(나루 y=9.86) — 예산(≥60·≤16ms) 안 |
| 요천 나루 1920×1080 화면 품질 낮음 | — | 108.6 · 9.5ms | 하늘빛 반사만 |
| 요천 나루 2560×1440(레티나 창 기본) | 67.7 · 15.0ms | 60.8 · 16.7ms | |
| 요천 나루 1인칭 1920×1080 | 69.2 · 14.8ms | 63.9 · 16.7ms | 1인칭은 원래 무거움(먼 경치 140만 삼각형) |
| 광한루 못 1920×1080 | 129.0 · 8.3ms | 117.1 · 9.1ms | 못 높이로 반사 |
| 강릉 바닷가 1920×1080 | 103.4 · 10.0ms | 93.0 · 11.1ms | 물결 판 + 반사(y=0) |
| 강릉 바닷가 강풍 1920×1080 | — | 92.8 · 11.1ms | 너울 ×2.15·흰 물결 |

비용 나눔(2560×1440 나루, 반사를 매 프레임 그리던 때): 물 셰이더 자체 +0.7ms(반사 끔 66.9 vs 물 숨김 70.0fps), 반사 +3.4ms 중 해 그림자 다시 그리기 약 0.7ms·화소 약 1ms·나머지는 두 번째 3D 패스 고정 비용. 반사 먼 끝(420→120m)·작은 물체 빼기는 삼각형·그리기 호출은 줄였지만 시간은 거의 그대로였다 → 2프레임에 한 번이 가장 컸다(매 프레임 1080p 80fps → 92~95fps).

측정 주의:
- 다른 에이전트(카메라 수정)의 시험·촬영과 같은 GPU를 쓴 앞쪽 측정은 버렸다. 벤치 스크립트가 다른 godot 실행이 없을 때만 재고, 도중에 겹치면 다시 잰다.
- 이 맥 1080p fps는 80·100·120·140 근처로 뭉쳐 나온다(화면 동기 탓으로 보임) — 차이는 2560×1440 값으로 판단했다.
- `viewport_get_measured_render_time_gpu`는 이 맥(Metal)에서 0을 돌려줘 쓰지 못했다.

## 5. 남은 문제

1. **레티나 창 기본(2560×1440)·1인칭은 경계선**: 나루 2560×1440 60.8fps·p99 16.7ms, 1인칭 1080p 63.9·16.7ms. 예산 기준(1080p 마을 구도)은 넉넉하지만 이 둘은 반사 프레임이 16.7ms에 걸친다. 더 줄이려면 반사 그림을 4프레임에 한 번, 1인칭 1/4 해상도, 또는 반사 전용 낮은 LOD가 필요하다.
2. **잘라 내는 면(oblique clip) 없음**: Godot 4.7 Camera3D에 사용자 투영이 없어 거울 카메라가 물 아래(땅 속)에서 본다. 땅은 뒷면이 걸러져 괜찮지만, 둑 너머 먼 집이 '땅을 뚫고' 반사 그림에 들어간다. 3인칭에선 그 자리가 물이 아닌 곳이라 보이지 않고, 1인칭 먼 물에서 드물게 둑에 가려져야 할 먼 지붕이 비칠 수 있다.
3. **거울면은 하나**: 경사진 냇물은 플레이어 둘레 높이 하나만 쓴다(0.35~0.9m 벗어나면 하늘빛으로 넘어감). 높이가 다른 물 둘(못과 냇물)이 함께 보이면 가까운 것만 거울.
4. **바다 물가 4m 칸 계단**: 바다 칸 가림(water_mask 4m)에서 오는 각진 물가선은 예전부터 있었다. 거품을 성기게 해 덜 드러나지만 남아 있다.
5. **호수(경포호)·큰 강은 꼭짓점 물결 없음**(법선 물결만) — 판이 윤곽 다각형·32m 칸이라 꼭짓점이 없다. 잔잔한 물이라 화면 차이는 작다.
6. **논물(region_paddy_water)은 그대로**(water.png 잔물결 포함). 필지마다 높이가 달라 평면 반사가 맞지 않는다. 사용자 결정에 따라 하늘빛 + 같은 잔물결 법선으로 바꿀 수 있다.
7. **밤 등불 반사**는 평면 반사가 등불 빛 판까지 그대로 비추지만 밤 화면으로는 확인하지 못했다(해 질 녘만 찍음).
8. 해 반짝임은 해를 바라볼 때만 난다. 마을 구도(북쪽을 봄)·서남 볕에서는 거의 안 보이고, 해 질 녘 서쪽을 볼 때 보인다.

## 6. 다음 단계

1. **물가 먹선 결정**(사용자): `after/naru_town.jpg` ↔ `after/naru_town_ink_on.jpg`, `after/sea_coast.jpg` ↔ `after/sea_coast_ink_on.jpg`. 켜기로 하면 `water_fx.gd`의 `water_ink` 기본값만 1로 바꾼다.
2. 레티나 기본 해상도 여유가 더 필요하면 반사 주기·크기를 화면 품질 '보통' 단계로 하나 더 나눈다(높음 = 지금, 보통 = 4프레임·1/3, 낮음 = 하늘빛).
3. 논물을 같은 물 공용 식(하늘빛 반사·잔물결 법선·반짝임)으로 — 싸게 됨.
4. 나루 둘레 꾸밈(물가 계단·말뚝)이 생기면 반사에 그대로 비친다(visual-pass 다음 단계 3과 이어짐).
5. 밤 등불·달 반사 화면 확인, 비 오는 바다 물결 확인.

## 화면(`shots/water/`, 1600px JPEG)

| 장면 | 전 | 후 |
|---|---|---|
| 요천 나루 마을 구도(22°) | `before/naru_town.jpg` | `after/naru_town.jpg` (먹선 켬 `after/naru_town_ink_on.jpg`, 화면 품질 낮음 `after/naru_town_low.jpg`) |
| 냇굽이(요천 하류) | `before/river_bend.jpg` | `after/river_bend.jpg` |
| 강릉 안목 바닷가 | `before/sea_coast.jpg` | `after/sea_coast.jpg` (먹선 켬 `after/sea_coast_ink_on.jpg`) |
| 해 질 녘 나루(18.3시) | `before/naru_dusk.jpg` | `after/naru_dusk.jpg` |
| 1인칭 물 보기 | `before/naru_fp.jpg` | `after/naru_fp.jpg`, 냇물 쪽 `after/naru_fp_river.jpg`, 비 `after/naru_fp_rain.jpg` |
| 광한루 못 | `before/pond.jpg` | `after/pond.jpg` |
| 물결 움직임(0.3초 간격) | `before/seq_90·100·110·120.jpg`(프레임 수 다르게 따로 실행) | `after/seq_naru_0~3.jpg`, 강풍 바다 `after/seq_sea_0~3.jpg` |

다시 찍기: `godot --path seolhwa_godot res://scenes/region.tscn --resolution 1920x1080 -- --region=JL_NAMWON_UNBONG --warp=-3199,486 --time=11 --weather=clear --nostory --savefile=user://water_shot.json --waitload --frames=90 --shot=<png> --quit [--view=first --fpyaw=20,-12] [--waterink] [--gfx=low]`, 물결 움직임은 `--watershots=4 --shotdir=<폴더>`. 자리: 나루 −3199,486 · 냇굽이 −3962,996 · 광한루 못 −3255,500 · 강릉 바닷가(GW_GANGNEUNG) 2705,−900.
