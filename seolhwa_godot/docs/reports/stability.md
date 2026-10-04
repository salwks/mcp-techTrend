# stability 보고 — 다음 사건 전 안정화 (2026-10-04)

다음 사건을 만들기 전에 여섯 가지를 고쳤다.

- 헤드리스 공간 넘기 멈춤
- 작업 스레드 오류
- 끝낼 때 죽음
- 「남원」 두 번 뜸
- 큰 강 물 성능
- 시험 한 번에 돌리기

검증은 `tools/run_story_tests.sh`로 했다. 대본 시험 15개와 노정 걷기 2개가 모두 PASS다. 종료 코드는 모두 0이다. 누수 보고도 0이다.

## 1. 실행

| 하고 싶은 것 | 명령 |
|---|---|
| 시험 전부(헤드리스, 동시 3개) | `seolhwa_godot/tools/run_story_tests.sh` |
| 일부만 | `tools/run_story_tests.sh namwon hwangju:B walk` (이름 앞부분), `-j 1`(한 줄로), `-l`(목록) |
| 로그 | `/tmp/seolhwa_tests/<시각>/<이름>.log`(`LOGDIR=`로 바꿈). 제한 시간 배율 `TIMEOUT_SCALE=2` |

- 판정 기준은 넷이다.
  - PASS 줄이 있어야 한다. 대본 시험은 `STORYTEST|ONBOARDTEST PASS`, 걷기는 `WALK done`과 `TRAVEL arrive`다.
  - 종료 코드가 0이어야 한다.
  - SCRIPT ERROR가 0이어야 한다.
  - 제한 시간 안에 끝나야 한다.
- 표에는 다음도 같이 적는다.
  - RID 오류
  - crash(`handle_crash`)
- 시험마다 저장 파일을 따로 쓴다(`--savefile=user://st_<이름>.json`). 그래서 동시에 돌려도 서로 덮어쓰지 않는다.

## 2. 고친 것

### 2.1 헤드리스 공간 넘기 멈춤
- 원인: `region_main._wait_frames`가 `RenderingServer.frame_post_draw`를 기다린다. 그런데 더미 렌더러는 이 신호를 보내지 않는다. 그래서 `_leave`가 영원히 기다렸다.
- 고친 것: 헤드리스에서는 `get_tree().process_frame`으로 센다. `main.gd`도 같다.
- 결과: hwangju:A·B·C(황주 → 장산곶 노정 → 황주)가 헤드리스로 PASS다. 각각 약 35·33·51초 걸린다.
- 헤드리스 찍기(`_save`)는 그림이 없으므로 건너뛴다. 예전에는 `--walkroute`에서 SCRIPT ERROR가 났다.

### 2.2 작업 스레드 오류(farm.gd)
- 원인: 더미 렌더러(헤드리스)의 RID 저장소는 스레드 안전하지 않다.
  - 작업 스레드는 식생 흩뿌리기와 키트 짓기를 하면서 MultiMesh·메시를 만든다.
  - 메인 스레드는 필지 노드(`farm._mm_node`·`_mesh_node`)와 배치 노드를 만든다.
  - 둘이 동시에 RID를 만들면 `Initializing already initialized RID`, `Parameter "multimesh" is null` 오류가 났다.
  - 그 결과 자원이 엉켰다. 오류 backtrace는 farm.gd·region_world._make_node·placement_loader._place_one을 가리켰다.
  - 이것이 강릉 시험이 멈춘 원인이다. 끝낼 때 signal 11이 난 것도 이것 때문이다.
- `scripts/region/jobs.gd`를 새로 만들었다.
  - 헤드리스(또는 `--serialjobs`)에서는 짓기를 그 자리에서 메인 스레드로 돌리고, 끝난 가짜 번호를 돌려준다.
  - 창 모드(Mobile/RD)에서는 저장소가 스레드 안전하다. 그래서 예전처럼 WorkerThreadPool을 쓴다.
  - 식생 흩뿌리기와 키트 짓기가 이것을 쓴다.
- farm.gd를 이렇게 고쳤다.
  - `jobs_idle`·`wait_jobs`를 더했다. 끝내기·넘어가기 기다림에 필지 작업도 넣었다.
  - 타일을 버리거나 끝낼 때, 트리 밖에 있는 반쯤 만든 노드를 지운다. 예전에는 고아 노드와 RID가 샜다.
- `region_world.reset_edits`(배치 다시 읽기)를 고쳤다.
  - 예전에는 작업 스레드가 `hbytes`·`lbytes`를 읽는 동안 배열을 갈아 끼웠다.
  - 이제 필지·식생 작업을 먼저 기다린다.
- 부하 시험 결과는 다음과 같다.
  - 무엇을 했나: 키트 캐시를 비운 찬 불러오기 10회(강릉 6, 남원·운봉 4), 창과 헤드리스를 번갈아. 각 회차는 `--bench=15 --benchspeed=45`로 675m를 걸었다.
  - 결과: 종료 코드 0, SCRIPT ERROR 0, ERROR 0, crash 0.
  - 처음 두 회차에는 SCRIPT ERROR가 1씩 있었다. 아래 2.3의 끝내기 정리 실수이고, 고쳤다.

### 2.3 끝낼 때 죽음(signal 11, 134)
`--verbose`로 누수를 찾았다.

- static 캐시가 렌더 서버가 내려간 뒤에 풀렸다.
  - 원인: 재질·셰이더·텍스처, 그림 묶음(`SpriteChar._banks`), 식생 원본 메시, 소품 색 재질이 static 값에 있었다.
  - 이것들이 렌더 서버가 내려간 뒤에 풀려 RID 누수가 보고됐다. 헤드리스에서는 사라진 서버에 자원을 돌려주다 죽었다.
  - 고친 것: `scripts/region/quit_cleanup.gd`가 `get_tree().quit()` 전에 이 캐시들을 비운다.
- 진행 중인 식생 작업이 있는 타일을 지우면 결과가 버려졌다.
  - 버려진 것은 트리 밖 MultiMeshInstance3D 수십 개다. 걷는 동안에도 샜다.
  - 고친 것: 끝난 뒤 지운다(`_scatter_orphans`).
- RefCounted 고리를 끊었다.
  - 배 타기 ↔ 강 뱃길 고리는 넘어갈 때·끝낼 때 끊는다.
  - 싸움판 ↔ 플레이어·범·사람 적 고리는 `cbattle.dispose()`가 끊는다. combat_view가 지워질 때 부른다.
- 결과: 아래와 같이 모두 깨끗하다.
  - hwangju:A 헤드리스 `--verbose`
    - 전: RID 수백 개, ObjectDB 114개, 끝낼 때 signal 11
    - 후: 누수 보고 0, 종료 코드 0
  - 창 모드 `--bench`, 창 모드 hwangju:B: 종료 코드 0, 누수 보고 없음
  - 마지막 전체 시험 17개 로그: leaked·still in use·crash·RID 오류가 모두 0

### 2.4 「남원」 두 번 뜸
- 전경 연출이 「남원」을 띄운 뒤, 성문에 들어서면 place_title이 「남원」을 또 띄웠다.
- 이제 이야기가 띄운 지명을 static으로 기억한다.
  - 기억하는 것: `show_title(이름, true)`, `story_ui.title_card`.
  - 같은 이름의 구역에 60초 안에 들어서면 지명 표시를 건너뛴다.
  - 남원만이 아니라 모든 지명에 적용된다. 공간을 넘어도 기억이 남는다.
- onboard 시험에 "「남원」은 한 번만" 확인을 더했다. 로그에는 `PLACE title skip 남원 (story)`가 남는다(`--logtitle`).

### 2.5 큰 강 물 성능(노량진 나루)
측정 결과, 셰이더 계산은 원인이 아니었다. 아래 수치는 `--sailspeed=11` 배 타기, 2048×1536이다.

| 바꾼 것 | 평균 fps |
|---|---|
| 그대로 | 78.6 |
| 흐름 지도 4번 읽기 → 1번 | 79.8 |
| 물가 흐림 3번 읽기 빼기 | 79.1 |
| 수심(높이 4번) 읽기 빼기 | 80.1 |
| 색 계산 빼기 | 78.5 |
| 그림자 받기 끔 | 86.3 |
| 물 끔(`--nowater`) | 96.9 |
| **물 판을 통째로 불투명** | **98.4** |

반투명 그리기 자체가 무거웠다. 섞기를 하고, 물 아래 땅까지 다 칠하기 때문이다. 화면 먼 쪽만 싸게 하는 방법은 효과가 작다. 낮은 배 시점에서는 수평선 바로 아래 띠만 먼 물이기 때문이다. 그래서 판을 나눴다.

- `shaders/region_sea_body.gdshaderinc`: 본문을 하나로 모았다. 판마다 정의 하나로 고른다.
  - `region_sea.gdshader`: 바다·호수용이다. 예전과 같다.
  - `region_sea_split.gdshader`: 반투명 물가 띠다. 알파가 0.94 이상인 곳은 일찍 버린다.
  - `region_sea_opaque.gdshader`: 불투명 판이다. 물가 띠를 뺀 나머지를 그린다. 두 판은 같은 식으로 골라 맞물린다.
  - `region_sea_interior.gdshader`: 불투명이고 discard가 없다. 그래서 GPU가 물 아래 땅을 칠하지 않고 건너뛴다(타일 GPU의 숨은 면 제거).
- region_world는 큰 강(sea.kind=river)일 때만 판을 나눈다.
  - 물 가림을 2^k 배수로 채운 밉맵에서 32m 칸을 읽는다.
  - 둘레 8칸까지 모두 바다인 칸은 interior 판으로 그린다.
  - 나머지 물 칸은 opaque 판 + split 판으로 그린다. 한양은 interior 1186칸, 물가 1613칸이다.
  - 감김 방향은 옛 격자와 같게 했다. 뒷면이 되면 cull_disabled에서 NORMAL이 뒤집혀 물빛이 밝아진다.
  - `--nowatersplit`을 주면 예전 판으로 그린다.
- 결과
  - 배 타기 속도 그대로(5.5m/s, 85초): **81.0 → 98.3fps**
  - 같은 길, 시험 속도: 78.6 → 97.6fps
- 화면 차이(0~255 평균)
  - 배 시점 5장: 0.3~3.7. 같은 설정으로 두 번 찍어도 1.1~3.4만큼 흔들리므로 같은 수준이다.
  - 기본 시점(나루 둑, `--shot`): 0.39. 40 넘게 다른 픽셀은 0%다.
  - 바뀌는 것은 안쪽 물의 알파 0.97이 1이 되는 것뿐이다. 바닥이 3% 비치던 것이 사라진다.

### 2.6 대본 시험을 흔들리지 않게
- gyeongju:A가 가끔 FAIL했다. 이번 작업 전 첫 전체 시험에서도 그랬다. 밀수꾼 둘이 다 달아나 결말이 B로 나왔다.
- 대본 시험의 싸움을 이렇게 바꿨다.
  - 프레임마다 고정 걸음(`time_scale/60`)으로 진행한다.
  - 정해진 난수를 쓴다(`--combatseed`, 기본 1870).
  - 이제 결과가 기계 부하에 따라 바뀌지 않는다.
- 경주 시험 봇을 이렇게 바꿨다.
  - 달아나는 자를 먼저 노리고 활을 당긴다.
  - 싸움터 가장자리를 넘지 않는다.
  - 결과는 PASS(A_figure)이고, 매번 같다.
- 시험 스크립트에 해석 오류가 있으면 시간 초과까지 기다리지 않고 바로 `STORYTEST FAIL`로 끝낸다.

## 3. 시험 결과(마지막 전체, 헤드리스, `-j 3`)

| 시험 | 결과 | 코드 | 초 | 결과 줄 |
|---|---|---|---|---|
| namwon:A | PASS | 0 | 173 | A_win |
| namwon:B | PASS | 0 | 309 | B_repel |
| namwon:C | PASS | 0 | 38 | C |
| namwon:onboard | PASS | 0 | 23 | 「남원」 한 번 |
| hanyang | PASS | 0 | 56 | followed |
| hanyang:r01 | PASS | 0 | 35 | lost |
| hanyang:act3 | PASS | 0 | 17 | ACT3 |
| gangneung:A | PASS | 0 | 23 | A |
| gangneung:B | PASS | 0 | 15 | B |
| gangneung:C | PASS | 0 | 23 | C_bell |
| gyeongju:A | PASS | 0 | 32 | A_figure |
| gyeongju:B | PASS | 0 | 25 | B |
| hwangju:A | PASS | 0 | 40 | A_rubbing |
| hwangju:B | PASS | 0 | 37 | B |
| hwangju:C | PASS | 0 | 56 | C |
| walk:hwangju-pyeongyang | PASS | 0 | 55 | 578m, 막힘 0 → 평양 도착 |
| walk:hangang-boat | PASS | 0 | 223 | 뱃길 타고 998m 걸음, 막힘 1(막다른 노정 시험 방식) → 한양 도착 |

모든 시험에서 SCRIPT ERROR, RID 오류, 누수 보고가 0이었다. 창 모드 hwangju:B도 PASS, 종료 코드 0이다.

## 4. 성능(`--bench=12 --nostory`, 2048×1536, M1, 다른 Godot 없음)

| 자리 | 평균 fps | p99 | 33ms 넘음 |
|---|---|---|---|
| 남원 읍내(시작 자리, 45m 걸음) | 119.8 | 8.5ms | 0 |
| 한양 운종가(종로, −168, −870) | 108.2 | 9.3ms | 0 |
| 노량진 나루 배 타기(`--ridetest=noryang_naru`) | **98.3**(예전 판 81.0) | — | — |
| 강릉 들(필지, 1155, −480) | 120.0 | 8.5ms | 0 |
| 강릉 들 빠르게 걷기(`--benchspeed=30`, 283m) | 118.9 | 9.1ms | 0 |

- 운종가와 강릉 들 첫 자리는 북쪽이 막혀 있었다(걸은 거리 0m). 그래서 이 두 줄은 서 있는 자리의 수치다.
- 120 언저리 수치는 화면 주사율 상한에 걸렸을 수 있다.

## 5. 남은 것
- 헤드리스는 짓기가 메인 스레드라 불러오기가 조금 느리다. 시험 결과에는 영향이 없다. 창 모드는 그대로다.
- 바다(제주 등)와 호수는 판을 나누지 않았다. 제주 바다 뱃길은 94fps였다(terrain-engine 보고). 같은 방법(바다 칸 한가운데 불투명)을 쓸 수 있지만, 바다는 먼 바다 알파가 0.95라 경계값(0.94)을 다시 정해야 한다.
- `walk:hangang-boat`의 막힘 1은 막다른 노정 시험이 출발 포털로 순간이동하는 것이다(routes 보고와 같다).
