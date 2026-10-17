# 사용자 보고 1017 — 마을 카메라 더 낮게 · 누각 계단 · 뜬 용마루 · 풀 포기 (2026-10-17)

사용자 화면 셋(`shots/user_report_1017/5·6·7.webp`, git 밖)에서 받은 다섯 가지를 고쳤다. 같은 작업 트리에서 다른 에이전트가 물(water pass)을 하고 있었다. 그래서 물 셰이더·물 스크립트는 건드리지 않았다. `region_world.gd`에는 그쪽의 커밋 안 된 변경이 있어서, 내 몇 줄만 HEAD 위에 얹은 blob으로 따로 스테이징했다.

화면: `seolhwa_godot/shots/fix_1017/`

## 1. 확인한 기존 구현 및 문제점

### 1-1 마을 카메라(5.webp)
- `RegionWorld.TOWN_FRAME = { pitch 32, dist_k 0.78 }`를 `town_cam()`이 고을·도시 구역·'집 둘레' 구역에만 씌운다. 원본 `CAM_TOWN`·region.json은 40 그대로다.
- 카메라는 겨냥점(플레이어 가슴 + lookAhead + 구역 aimZ)을 `look_at`으로 바라본다. 그래서 플레이어는 원래 화면 가운데에 온다.
  - 예외: 도시 구역 aimZ(운종가 −5, 육조 −3)는 m 단위 옮김이다. 거리를 줄이면 화면에서 더 크게 먹혀 플레이어가 화면 아래로 내려갔다.
- fov 30이라 화면 맨 위는 pitch − 15° 아래를 본다. 22°에서도 7° 아래라 평지에서는 하늘이 들지 않는다.

### 1-2 누각 계단(6.webp — 광한루)
- `kit/landmark/gwanghallu.gd` 뒤 계단의 옆판이 `Kit.xf(…, atan2(F, run), 0, 0)`로 돌아가 있었다.
  - Godot 기저에서 +x축으로 +θ 돌리면 +z 끝이 내려간다. 계단은 +z(건물) 쪽으로 오르므로 옆판이 **반대로 기울었다**.
  - 길이도 ns·0.3 + 0.4로 빗변보다 짧았다.
  - 그래서 옆판 둘이 디딤판과 엇갈려 X자로 보였고, 디딤판은 받침 없이 떠 있었다.
- 같은 코드가 `_hub.pavilion`(누정 공용: 부벽루·경포대·칠사당·연북정·을밀대·관덕정·오대문·경회루·불국사 석축 누각·연광정)에도 있었다.
  - `stair = false`나 F ≤ 0.9인 키트는 계단이 없다.
- 계자난간이 북쪽 계단 머리를 막고 있었다.
- 걷기:
  - 광한루 실내 상자 `floor_y = 3.4`는 마루 전체를 F로 올린다.
  - 계단 걷기 면이 없어 땅에서 오를 수 없었다(building-floor-roof §5 남은 일).
  - 마루 가장자리에 충돌이 없어, 올라가 있으면 난간을 지나 3.4m 아래로 떨어질 수 있었다.

### 1-3 뜬 용마루(7.webp, 6.webp 먼 집)
- `C.curved_roof(…, nx, nz)`는 z를 `−hd + 2hd·j/nz`로 나눈다. **nz가 홀수면 용마루 줄 z = 0에 꼭짓점이 없다.**
  - 그러면 가장 높은 꼭짓점이 s = 1 − 1/nz 자리에서 접힌다.
  - 이때 높이는 rise·(0.25s + 0.75s²)다. 마루가 rise의 일부만큼 낮아지고, `ridge_cap`(eave + rise에 놓임)이 떠 보인다.
- 홀수인 곳:
  - 집 묶음(house_compound) 기와 안채 `roof_nz = 9`, 사랑채 `7`(작은 기와집도 같은 값): 약 0.3m.
  - 먼 읍내 lod 한 덩이 `nz = 5`: 약 0.77m.
  - 7.webp(nw_house_158 작은 토담 기와집)이 이 경우다.
- 용마루 상자는 높이 0.3(y − 0.07 ~ y + 0.23)이었다. 마루 양 비탈이 내려가는 자리에서는 아래에 틈이 보였다.

### 1-4 풀 포기(7.webp)
- 3인칭 `town_layer`의 `t_tufts`와 1인칭 `near_layer` 포기는 모두 다섯·여섯 가닥 부채꼴이다.
  - 크기 변화가 0.7~1.3배뿐이었다.
  - 잎 수·부채 폭·빛깔이 모두 같았다.
- 1인칭 눈높이에서는 큰 짙은 별이 고르게 되풀이되었다(0.45m 칸에 60%).

### 1-5 그 밖(5·6·7.webp)
- 토담 박힌 돌: 두 줄에 같은 크기의 밝은 돌이 고르게 박혀 물방울 무늬처럼 보였다(`kit/village/todam.gd`).
- 각진 먼 나무: 나무 손질은 따로 대기 중인 일이라 손대지 않았다(§5).
- z-fighting: 세 화면에서 따로 보이지 않았다.

## 2. 유지·수정·신규

| 구분 | 무엇 |
|---|---|
| 유지 | 원본 `CAM_TOWN`·region.json 40°, 숲 48·길 밖 숲 55·고개 30, 대화 TALK, 1인칭, 말·배·지도·사건 카메라, 가림 반투명·점무늬, 실내 지붕 숨김, 지붕 꼴·곡선(칸 수만 짝수로), 땅 꾸밈 층 구조 |
| 수정 | `TOWN_FRAME` 32°·×0.78 → **22°·×0.64**, 도시 구역 aimZ 줄임, 광한루·누정 계단, 지붕 깊이 칸 짝수, 용마루 몸 깊이, 풀 포기 두 층, 토담 박힌 돌 |
| 신규 | `landmark/_common.wood_stair`(공용 나무 계단 + 디딤판 걷기 면), 광한루 난간 충돌·계단 머리 틈 |

### 2-1 마을 카메라: 22°·×0.64
- 비교한 곳: 남원 장터(−3290,393), 골목(−3098,280), 이겸 마당(−3192,716 — 700은 방 안이라 실내 카메라), 요천 나루(−3207,494), **남문 성벽 안쪽**(−3228,334 — 성벽·옹성이 카메라와 플레이어 사이), 한양 운종가(−291,−878).
- 각은 32·28·25·22, 거리 배율은 0.78·0.72·0.68·0.64로 비교했다.
  - 각이 1° 낮아질 때 거리를 약 0.02배씩 줄였다. 플레이어 크기가 비슷하게 남는다.
- 판단:
  - 하늘·지평선: 여섯 곳 모두 22°에서도 화면에 들지 않았다. 먼 LOD·안개는 바뀐 것 없이 보였다.
  - 앞 지붕·차일: 화면 아래를 지나가고 가림 반투명이 비운다. 장터 22°에서 앞 차일이 반투명으로 플레이어 앞을 덮지만 플레이어는 보인다.
  - 성벽: 남문 성벽·홍예가 플레이어 앞을 지나도 기존 가림 반투명이 처리했다(네 각 모두).
  - 깊이 흐림: 초점이 가까워져 먼 마당 끝이 조금 더 무르다. 설정 '깊이 흐림'으로 조절된다.
  - 한양 운종가: 22°에서 군중이 겹쳐 보이기 시작한다. aimZ를 줄인 뒤 플레이어는 화면 가운데 조금 아래에 오고 가려지지 않았다.
- 결론: 다섯 곳 모두 잘 읽혀 **가장 낮은 22°**로 정했다.
- aimZ 보정: `town_cam`이 aimZ에 clamp((pitch − 15)/25, 0, 1)을 곱한다(22°에서 ×0.28, 운종가 −5 → −1.4).

### 2-2 공용 나무 계단 `Co.wood_stair(x, z_top, F, w, dir, run, rise)`
- n = ceil(F / rise) 단이다. 디딤판 n − 1장을 놓고, 마지막 단은 마루 자체다.
- 디딤판 앞 코는 땅 끝(n·run, 0)과 마루 끝(0, F)을 잇는 한 직선 위에 놓인다.
- 옆판 둘은 그 직선보다 0.1m 아래를 따라간다. 땅속 0.35m에서 시작해 마루 밑(F − 0.08)까지 닿고, 기울기 부호는 `dir·θ`다.
- 디딤판마다 건물 걷기 면 `floor = true`를 둔다. 한 단 F/n은 광한루 0.227m로 MAX_STEP 0.32 이하다.
- 광한루:
  - 15단(디딤판 14 + 마루).
  - 북쪽 난간을 계단 폭 + 0.12만큼 틔웠다.
  - 마루 끝 네 변에 난간 충돌을 두었다. 계단 머리만 열었다.
  - `walk = stair.walks`, `stair_foot` 앵커는 새 계단 발치다(이야기 자료는 이 앵커를 쓰지 않는다).
- `_hub.pavilion` 누정: 같은 함수로 꼴만 바꿨다(rise 0.25, run 0.3). 걷기 면은 `info.stair_walks`에 담았다.
  - 각 누정 키트는 마루에 실내 floor_y가 없어 올라가도 설 곳이 없다. 그래서 키트 반환에 넣지 않았다(§5).

### 2-3 용마루
- `village/_common.curved_roof`와 `landmark/_roof.surfaces`에서 `nz += nz % 2`로 늘 짝수가 되게 했다.
  - 삼각형은 기와집 지붕이 9 → 10줄이라 약 +11%다.
- 용마루 몸은 위 끝(y + 0.23)을 그대로 두고 아래를 y − 0.19까지 깊게 했다(0.3 → 0.42).
  - 적용한 곳: `village ridge_cap`, `landmark _roof.ridge_cap`과 `add`의 용마루, `house_compound` lod 기와, `culture/_cc` 기와.
- 끝 치켜든 장식(취두 자리)은 그대로다.

### 2-4 풀 포기
- `t_tufts`(3인칭 town_layer, 다섯 곳에서 부름):
  - 크기 0.4~1.4배(작은 것이 많게), 잎 3~6가닥, 부채 폭 0.8~1.8rad, 방향 흔들림 ±0.65rad.
  - 빛깔은 짙은 풀·연둣빛·마른 짚빛, 진하기 0.55~0.9로 포기마다 다르게 했다.
  - 잎 두께도 포기마다 다르다.
- 1인칭(`near_detail`)에서는 카메라 3~9m 안의 town 포기를 성기게·옅게 지운다(밀도·세기 모두 smoothstep). 그 자리는 near_layer의 가는 포기가 받는다.
- `near_layer` 포기:
  - 밀도 0.6 → 0.45, 크기 0.12~0.42m.
  - 잎 수·부채 폭·빛깔을 같은 식으로 달리했다.
  - 발밑 1~3m는 지운다.
- 3D 풀 키트를 눈앞에 심는 방법은 쓰지 않았다(비용·스트리밍 일이 커짐 — §5).

### 2-5 토담 박힌 돌
- 자리를 ±0.25칸, 높이를 ±0.11m 흩었다. 크기는 0.1~0.26으로 작은 것이 많다.
- 납작하게 반쯤 묻혔고, 빛깔은 흙빛에 가깝다. 빠지는 비율은 25 → 35%다.

## 3. 수정 파일과 주요 변경

| 파일 | 변경 |
|---|---|
| `kit/landmark/_common.gd` | 새 `wood_stair` |
| `kit/landmark/gwanghallu.gd` | 계단 → `Co.wood_stair` + 걷기 면, 북쪽 난간 틈, 난간 충돌 5개, `stair_foot` 앵커 |
| `kit/landmark/_hub.gd` | `pavilion` 계단 → `Co.wood_stair`, `info.stair_walks` |
| `kit/village/_common.gd` | `curved_roof` nz 짝수, `ridge_cap` 깊이 |
| `kit/landmark/_roof.gd` | `surfaces` nz 짝수, 용마루 깊이 두 곳 |
| `kit/village/house_compound.gd` | lod 기와 용마루 깊이 |
| `kit/culture/_cc.gd` | 기와 용마루 깊이 |
| `kit/village/todam.gd` | 박힌 돌 흩기·크기·빛깔 |
| `shaders/region_terrain.gdshader` | `t_tufts` 변화, town_layer 1인칭 가까이 지우기(`tnear`), near_layer 포기 변화·발밑 지우기 |
| `scripts/region/region_world.gd` | `TOWN_FRAME` 22/0.64, `town_cam` aimZ 보정 (3줄) |
| `tests/camera/camera_view_test.gd` | 마을 구도 허용 범위 30~40° → 20~40°, 거리 0.7~1.0 → 0.6~1.0 |
| `scripts/region/view_test.gd` | '3인칭 각 > 35' → '마을 구도 각 − 1 이상' |
| `scripts/story/prep_test.gd` | '가까운 군중 움직임' = active + reduced > 0 (아래 §4) |

키트 캐시는 스크립트 의존 해시라 바뀐 키트를 저절로 다시 짓는다. 첫 실행 때 KITMISS가 조금 늘고, 그다음부터는 그대로다.

## 4. 실행한 테스트와 결과

모든 실행은 `--` 뒤 게임 인자 + `--savefile=user://fix1017_*.json` 또는 `st_*`(모래상자)로 했다. 실제 저장 폴더·백업은 건드리지 않았다. 묶음 시험은 매번 `pgrep run_story_tests`로 다른 묶음이 없는지 확인하고 돌렸다.

| 시험 | 결과 |
|---|---|
| `tests/camera/camera_view_test.gd` | CAMVIEWTEST PASS 30 |
| talk:namwon/hanyang/jeju/cycle/cycle-fp | 5/5 PASS |
| seat:namwon/hanyang | 2/2 PASS |
| first15:new/onui/skip | 3/3 PASS |
| view:namwon | 처음 FAIL "3인칭 각 22.0"(시험이 > 35를 기대 — 32°였던 앞 커밋부터 이미 맞지 않던 값) → 고친 뒤 **PASS checks=66** |
| chunhyang:prep | 처음 FAIL 1/65 "가까운 군중 active 0"(frozen 23 · reduced 2) → 고친 뒤 PASS 65 |
| chunhyang:part2prep | PASS 61 |
| 전체 `tools/run_story_tests.sh -j 3` | §4-1 |

- chunhyang:prep 판단:
  - 같은 자리에서 `--townframe=32,0.78`은 active 3, 22°는 active 1(PASS) 또는 0(FAIL, reduced 2)이었다. 화면 안에 드는 군중 수가 각에 따라 달라 경계에 걸린 것이다.
  - 시험의 뜻(가까운 군중이 그려지고 움직인다)은 세 프레임에 한 번 움직이는 reduced도 만족한다. 그래서 판정을 active + reduced로 바꿨다.
- 걷기 확인(광한루): 계단 가운데(−3265.3, 442.5)에 순간이동하면 1인칭 눈높이가 디딤판 위에 선다(`stairs_after_on_stair.jpg`). 디딤판 한 단은 0.227m < MAX_STEP이다.

### 4-1 전체 묶음
- `tools/run_story_tests.sh -j 3`(`/tmp/seolhwa_tests/20261017_222832`): **93/94 PASS**, SCRIPT ERROR 0.
- 실패 1: talk:namwon "E 대상 11/20".
  - 같은 시각에 물 에이전트의 벤치·촬영이 함께 돌아 부하가 컸다. 로그는 "E 대상 아님 target=없음 dist 0.9~1.0"으로, 닿는 거리 경계에서 걸렸다.
  - 바로 뒤 talk:namwon만 두 번 다시 돌린 결과는 **PASS talks=24 · PASS talks=24**다. 앞선 묶음(talk 다섯)에서도 PASS였다.
  - 카메라·계단·지붕·땅 변경은 E 대상 판정(거리·바라보는 쪽)에 닿지 않는다. 부하 때 흔들림으로 본다.

### 4-2 성능(1920×1080, `--scale=1 --bench=12 --benchspeed=0`, 맑음 11시, 남원 장터)

같은 시간에 물 에이전트가 벤치·촬영을 계속 돌렸다. 그래서 서로 겹친 값과 겹치지 않은 값을 나눠 적는다.

| 조건 | fps · p99 | 삼각형 · 그리기 |
|---|---|---|
| 32°(`--townframe=32,0.78`), 단독 | 143.8 · 7.2ms | 199k · 128 |
| 32°, 단독 | 134.8 · 10.0ms | 199k · 129 |
| 22°(`--nowaterrefl`) | 133.2 · 10.4ms | 267k · 179 |
| 22°, 다른 Godot 하나와 겹침 | 115.5 · 9.1ms | 267k · 180 |
| 22° 남문 → 성 안 걸어서(4.6m/s, 20초) | 143.4 · 9.0ms | 292k · 117 |

- **예산(≥ 60fps, p99 ≤ 16ms) 안**이다.
- 22°는 화면이 더 멀리(북쪽) 닿아 삼각형 +34%, 그리기 +40%다. 혼자 잰 fps는 측정 흔들림 안이다.
- 풀 포기 셰이더 변경은 포기 칸 안 화소만 고리를 돈다(잎 수가 6 이하로 줄어드는 포기가 많음). 비용 차이는 따로 잴 만큼 크지 않았다.
- 1인칭 기와집 앞(물 가까이) 74fps · p99 14.5ms(`--nowaterrefl`)는 물 에이전트의 작업 중인 반사·물결 상태다. 이번 변경과 무관하다.

## 5. 남은 문제

1. **각진 먼 나무**(6·7.webp): 나무 손질은 따로 대기 중인 일이라 손대지 않았다.
2. **누정 계단 걷기**: `_hub.pavilion` 누정(부벽루·경포대·을밀대 등)은 계단 꼴만 고쳤다. 마루 실내 floor_y·난간 충돌이 없어 오를 곳이 없다. 키트마다 `walk = info.stair_walks` + interior floor_y를 붙이면 광한루와 같아진다.
3. **landmark 돌 기단 0.35~0.4m**: MAX_STEP(0.32)보다 높고 걷기 면도 없다. 광한루 기단 위를 걸으면 발이 0.35m 묻힌다(전부터 있던 일, 다른 landmark 공통).
4. **광한루 마루 밑**: 실내 상자 floor_y가 마루 둘레 전체라 마루 밑 땅으로는 들어가지 못한다(전과 같음). 익루(동쪽 날개)는 충돌 상자 그대로다.
5. **22°의 한양 군중**: 군중이 겹쳐 보인다. 플레이어가 가려지지는 않았지만, 장날 사건에서 가까운 군중이 앞을 덮을 수 있다. 원하면 도시 구역(`src: north`)만 25°로 따로 둘 수 있다(`town_cam`에서 한 줄).
6. 1인칭 풀 포기는 여전히 땅에 그린 무늬다. 눈앞에 진짜 3D 풀(nature 풀 키트)을 몇 포기 심는 일은 스트리밍·비용 일이 커서 하지 않았다.
7. 토담 박힌 돌 변경으로 같은 seed의 토담·집 묶음 이후 무작위 값(갓 지붕 등)의 순서가 조금 바뀌었다(모양 차이는 미미).

## 6. 다음 단계

1. 사용자 화면 확인 — 22°가 너무 낮으면 `RegionWorld.TOWN_FRAME`만 25/0.68로 바꾼다(비교 그림에 있음).
2. 누정 키트 마루 걷기: `py_bubyeongnu`·`gn_gyeongpodae`·`hy_gyeonghoeru` 등에 interior floor_y + `walk = info.stair_walks` + 난간 충돌.
3. landmark 기단 걷기 면(기단 0.3m로 낮추거나 댓돌 한 단) — building-floor-roof §6-1과 함께.
4. 나무 손질(대기 중인 일)에서 먼 나무 LOD 모서리.

## 화면 목록(`seolhwa_godot/shots/fix_1017/`)

- `camera_sheet.jpg` — 여섯 곳 32°(전) / 22°(후). 운종가 후는 aimZ 보정 판.
- `camera_<곳>_32_28_25_22.jpg` — market · lane · naru · gate(남문 성벽 가림) · unjongga, 네 각 비교.
- `stairs_before_after.jpg` · `stairs_crop_before_after.jpg` — 광한루 계단 1인칭(같은 자리·같은 방향).
- `stairs_after_on_stair.jpg` — 계단 위에 선 눈높이(걷기 면).
- `ridge_crop_before_after.jpg` — 먼 기와집 용마루(같은 화면).
- `ridge_tuft_before_after.jpg` — 1인칭 풀 포기·기와집(전 / 후).
- `tuft_fp_after.jpg` — 7.webp와 같은 기와 토담집 앞 1인칭(후).
- 다시 찍기: `godot --path seolhwa_godot res://scenes/region.tscn --resolution 1920x1080 -- --region=JL_NAMWON_UNBONG --warp=-3274,438 --time=11 --weather=clear --nostory --savefile=user://fix1017_shot.json --waitload --frames=90 --shot=<png> --quit [--view=first --fpyaw=70,4] [--townframe=32,0.78]`
