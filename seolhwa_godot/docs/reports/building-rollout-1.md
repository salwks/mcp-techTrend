# 건물 빌더 세계 반영 1차(building-rollout-1)

- 브랜치 `claude/building-builder`(작업 트리 `../trend-mcp-seolhwa-bldg`). 시작할 때 `origin/claude/youthful-gauss-d0fxzv`(a283bf1·9550854, 초가 처마 밑면·실내 겹친 면 + ROOFTEST)를 합쳤다(충돌은 `region_main.gd` 진입 인자 두 곳 — 둘 다 살림).
- 요청 순서: ① 남원 한 구역 반영 → ② 초가 지붕 표현 → ③ 고을 배치 틀 + 대문 방향 → ④ 산과 먼 능선 → ⑤ 폐가 옵션. 중간 우선 요청: 외벽 모서리 이음(§C).
- 화면: `shots/building_rollout/`(시트 JPEG, 낱장은 `raw/` — 깃 밖). 게임 실행은 늘 `godot --path . … -- <게임 인자>` · 시험 저장(`--savefile=user://st_*.json`) · `--kitcache=/tmp/seolhwa_bldg_kit_cache/`.

## 1. 남원 한 구역 반영(서문 밖 장터길 민가 구역)

### 1-1. 고른 구역과 까닭
- 범위 x −3420…−3322, z 200…365(읍성 서벽 바깥). 남문 밖 장터에서 서문으로 돌아가는 **장터길(`namwon_market_lane`)** 과 **성황사 오솔길** 둘레의 민가 띠다. 장터길에 좌판 22개가 서 있어 보통 놀이에서 지나다니는 길이다.
- 이야기 자리는 이 범위에 없다: 이겸 거처(−3192, 700) · 월매 집 둘레(−3213, 450) · 옥(−3175, 230) · 단오 터(−3297, 432) · 춘향 그네(−3330, 444)는 모두 밖이다. 그래서 시드를 잠글 이야기 집이 없었다(`tools/bldg/rollout.gd`의 `STORY_IDS`는 비어 있다).
- 옛 `village/house_compound` 13채를 바꿨다: small 초가 4 → `choga_house`, small·기와 6 → **`giwa_house`(새)**, medium 3 → `jungnong`.

### 1-2. 바꾼 것
| 파일 | 내용 |
|---|---|
| `kit/bldg/_spec.gd` | 새 유형 `giwajip`(읍내 중인·향리 一자 기와집 3~4칸, 막돌 기단, 맞배·팔작, 흙·회벽) — 작은 필지(15×14m)에 드는 기와 몸채 |
| `kit/bldg/compound.gd` | 새 묶음 `giwa_house`(기와 몸채 + 초가 곳간 + 장독대 + 기와 갓 토담 + 평대문/일각문 + 반쯤 내외담). 묶음 `lot: [w, d]`(필지) — 담·마당을 필지 안으로 줄인다(건물은 줄이지 않음, 헛간은 자리가 남을 때만) |
| `tools/bldg/rollout.gd` · `rollout_apply.py` · `rollout.sh` | 구역 표(DISTRICTS)의 옛 묶음만 바꾼다. 같은 자리·같은 필지(옛 footprint)에 드는 첫 시드를 옛 시드에서부터 찾는다(결정적). 바꾼 항목에 `was`(옛 kit·params·footprint)·`rollout` 표시 → `rollout.sh west --revert`로 되돌림. json 형식은 원본 그대로(들여쓰기 1) |
| `region_data/JL_NAMWON_UNBONG/placement_namwon.json` | 위 13항목만(`rollout: building-rollout-1/west`). 바뀐 항목 목록 `tools/bldg/rollout_west.json` |
| `tools/bldg/roof_check.gd` | `--set=place --file= --bbox=` — 배치에 놓인 건물 전부(빌더·옛 키트)를 월드 자리로 짓고 지붕끼리·담 갓·벽–지붕 여유를 본다 |
| `scripts/region/bldg_rollout.gd`(`--bldgrollout`) + `tools/bldg/rollout_views.json` | 구역 전후 화면(마을 카메라·기본·1인칭·내려다보기)·길 걷기·묶음마다 대문 걷기와 옆 담 막힘 |
| `tools/bldg/bench_district.sh` · `sheet.gd` · `sheet_pairs.py` | 구역 성능 · 시트 |
| `tools/run_story_tests.sh` | `EXTRA_ARGS` 환경 변수(모든 시험에 `--kitcache=…` 같은 인자 더하기) — 기본 동작은 같다 |

주의: `tools/placement/namwon.py`로 배치를 다시 만들면 이 변경이 지워진다. 그 뒤 `tools/bldg/rollout.sh west`를 다시 돌린다.

### 1-3. 확인
- **지붕 겹침**(`roof_check --set=place`, 구역 안 건물 31→37채 조각 단위):
  - 전: **8건 실패** — 옛 묶음 안 안채↔사랑채(051·053·055, 0.18~0.27m), 헛간↔안채(059·077·087·141, 0.13~0.22m).
  - 후: **0건**(113 판). 벽–지붕 여유 19채 모두 통과, 최소 0.15m.
  - (그 밖 `beam()`의 "target vector can't be zero" 경고는 옛 키트 `_common.gd:252`에서 나는 기존 경고 — 빌더 검사에서도 같은 수로 난다.)
- **걷기·충돌**(`--bldgrollout --brset=west --brnoshots`, 플레이어 판정 5cm 걸음): **BRPASS 25 / BRFAIL 0**
  - 13채 모두 대문 밖 1.6m → 문지방(발 0.00~0.19m) → 마당 안 3m 닿음. 기와집 4채는 문 안 내외담에 막혀 옆으로 돌아 들어감(의도).
  - 12채 옆 담 밖 → 마당 가운데 곧장: 모두 막힘(1채는 시작 자리가 이웃 건물 안이라 건너뜀).
  - 대문 밖 6m에서 시작하면 5채가 실패했다 — 남북으로 쌓인 옛 배치에서 대문 앞 6m가 **이웃 묶음 뒷담 안**이다(대문 앞 골목 1.5~2m). 옛 배치의 문제라 그대로 두고 ③에서 대문을 길 쪽으로 돌렸다.
  - 길 걷기: 장터길 6마디 모두 닿음. **성황사 오솔길은 전·후 모두 x −3345.6에서 막힘** — 옛 배치가 052 묶음(필지 14.8×14)을 오솔길(z 288) 위에 놓았다. 같은 필지 안에서 바꾸는 1단계 규칙상 그대로 두고 ③에서 고쳤다.
- **성능**(`tools/bldg/bench_district.sh`, (−3341, 272) 장터길, 1920×1080 `--scale=1`, 맑음 11시, `--nostory`, 20초, 키트 캐시 더움 — 둘째 줄이 더운 값):

| 조건 | 전 avg fps / p99 ms | 후 avg fps / p99 ms | 화면 삼각형 전→후 | 그리기 전→후 |
|---|---|---|---|---|
| 마을 카메라 22°(제자리, 둘째 실행) | 103.6 / 10.0 | 140.9 / 7.0 | 303k → 366k | 143 → 126 |
| 기본 카메라 40° | 108.5 / 9.5 | 144.8 / 6.9 | 208k → 284k | 118 → 107 |
| 마을 카메라로 걸어 지나감(2.2m/s, 44m) | 111.1 / 15.2(worst 133ms, 33ms 넘음 3) | 133.1 / 12.1(worst 19ms, 0) | 305k → 318k | 125 → 112 |

  - 삼각형은 늘었고(빌더 near가 더 무겁다) 그리기는 줄었다(건물마다 한 메시). fps 차이의 일부는 같은 맥에서 다른 일이 돈 차이일 수 있다(전 측정이 먼저, 이야기 시험 3개가 함께 돌았다). 기준(≥60fps, p99 ≤ 16ms)은 둘 다 통과.
- **이야기 시험**(`EXTRA_ARGS=--kitcache=/tmp/… tools/run_story_tests.sh -j 3 first15 namwon`): **17 PASS · 1 FAIL**. 실패는 `namwon_chunhyang:p2a` "굽기 결과가 머리 고침보다 새것" — 알려진 작업 트리 수정 시각 문제(building-builder §11과 같은 줄). first15 세 갈래(new·onui·skip) 통과.
  - 이 실행이 도는 도중에 §C 모서리 수정을 `building.gd`에 쓰기 시작했다. 끝에 전체 시험을 다시 돌렸다(§끝).

### 1-4. 화면
- `step1_town.jpg` — 마을 카메라 6곳 전·후. `step1_walk.jpg` — 장터길·오솔길 걷기(마을 카메라 + 1인칭) 전·후. `step1_std_fp_over.jpg` — 기본 카메라 · 1인칭 · 구역 내려다보기 전·후.
- 본 것: 옛 묶음의 지붕 겹침(사랑채 지붕이 안채 처마에 박힘)이 사라졌다. 기와집은 기와 갓 토담·평대문으로, 중농은 아래채·곳간·우물이 있는 마당으로 읽힌다.
- 약한 곳: 대문이 모두 남쪽(+z)이라 장터길(동쪽)에서는 담 옆면만 보인다 → ③. 기와 갓 토담이 마을 카메라에서 꽤 검다(기존 `village/todam` 기와 갓 빛).
