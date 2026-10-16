# 저장 지킴 강화 — 테스트 실행과 실제 저장의 완전 분리 (2026-10-16)

## 1. 사고
- 18:43~18:48에 오프닝 캡처 실행을 하면서 게임 인자를 `--` 없이 넘겼다. 예: `godot --path . --savefile=… --titletest=…`
- Godot은 `--` 앞에 있는 낯선 인자를 버린다. 그래서 이 실행은 놀이 실행으로 판정됐고, 사용자 `progress.json`을 다시 썼다(18:48:38).
- 이전 지킴(save_guard.gd)은 사용자 인자(`--` 뒤)만 보았다. 인자를 빠뜨리면 지킴을 지나쳤다.

## 2. 보존
- 실제 저장은 복원하지도, 초기화하지도 않았다.
- 새벽 백업: `~/Documents/seolhwa_save_backup_20261016_005208`
- 사고 뒤 지금 상태 사본: `~/Documents/seolhwa_save_backup_20261016_185856` (progress.json·progress.png·settings.json)

## 3. 바꾼 것
**`scripts/region/save_guard.gd`**

명령줄 판정 classify(user_args, eng_args)를 세 가지로 나눈다.

| 판정 | 조건 | 결과 |
|---|---|---|
| 실행 중단 | `--` 앞에 엔진이 모르는 `-` 인자가 있다(게임 인자를 `--` 없이 넘김) | `blocked:` — 어떤 저장도 쓰지 않는다 |
| 모래상자 | 사용자 인자 가운데 놀이용이 아닌 것이 있다, `-s`/`--script`, 또는 도구 엔진 인자(`--headless`·`--write-movie`·`--fixed-fps`·`--quit`·`--quit-after`·`--check-only`·`--benchmark`·`--import`·`--export*`·`--doctool`) | 저장을 모래상자에 쓴다 |
| 놀이 | 그 밖(편집기 F5가 붙이는 `--remote-debug`·`--editor-pid`·`--position` 등 포함) | 지금처럼 user:// 에 쓴다 |

- 엔진 인자 목록(ENGINE_OPTS)은 `godot --help`(4.7.1)에서 뽑았다.
- 모래상자 폴더를 만들지 못하거나, 그 폴더가 사용자 폴더 안이면 실행을 중단한다. 놀이 저장으로 넘어가지 않는다.
- `write_ok(path)` 하나로 쓰기를 판정한다. 막힌 실행은 아무 데도 쓰지 않는다. 모래상자 실행은 사용자 폴더에 쓰지 않는다.

**쓰기 자리 모두 write_ok를 거친다**
- `progress.gd`: save, save_slot, load_slot(칸 → 진행 복사), 시작 때 지우는 tool 칸
- `game_settings.gd`: set_v
- `save_keeper.gd`: 자동 칸 그림

**실행 중단**
- `region_main.gd`의 `_ready` 맨 앞에서 막혔으면 `SAVEGUARD 실행 중단 — <까닭>`을 찍고 종료 코드 3으로 끝낸다.

## 4. 시험
**`tests/save/save_guard_test.gd`: SAVEGUARDTEST PASS 31**
- 명령줄 23가지를 넣어 본다. 이 가운데 `--`를 빠뜨린 4가지는 실행 중단, 엔진 도구 인자 3가지는 모래상자, 놀이·편집기 4가지는 user:// 판정이어야 한다.

**`tools/save_guard_e2e.sh`(새로 만듦): SAVEGUARDE2E PASS 7**
- 실제 게임을 6번 돌린다.
  - `--` 빠뜨림 4가지(창 2, 헤드리스 1, --nostory 촬영 1): 모두 종료 3으로 중단
  - `--`를 넣은 실행 2가지: 모두 모래상자
- 사용자 저장 폴더의 저장 파일 552개를 sha256·크기·수정 시각으로 견주었다. 바뀐 파일은 0개다.

**기존 기능 회귀: 모두 PASS**
- `run_story_tests.sh save first15:new continue:`
  - 저장 칸 저장·불러오기
  - 새 게임 첫 15분
  - 이어 하기 10가지(오누이 도중, 끝, 합류, 춘향 진입, 메인 편지 뒤)
- 이 시험을 돌리는 동안에도 사용자 progress.json의 수정 시각은 바뀌지 않았다.

## 5. 남은 것
- 놀이 실행(`godot --path .`, 편집기 F5)이 막히지 않는지는 판정 시험으로만 확인했다. 실제 저장에 쓰는 실행이라 직접 돌리지 않았다.
  - 편집기가 목록에 없는 숨은 인자를 붙이면 F5 실행이 중단될 수 있다. 그러면 화면과 로그에 그 인자 이름이 찍히므로, ENGINE_OPTS에 한 줄 더하면 된다.
- 엔진 버전을 올리면 ENGINE_OPTS를 `godot --help`로 다시 맞춘다.
