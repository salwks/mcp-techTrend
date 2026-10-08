# 다중 사건 등록부: 최소 리팩터링 보고

브랜치 `claude/youthful-gauss-d0fxzv`. 커밋·push는 하지 않았고 변경은 작업 트리에만 있습니다. 작업을 시작할 때 트리는 깨끗했으므로(`git status` clean) 아래 변경은 모두 이번 작업에서 생긴 것입니다.

## 1. 기존 구조 문제: 사건 id 하나를 전제한 곳

흐름: `region_main` → `StoryDirector.create_for()` → `CASES[space_id]`(사건 id 하나) → `res://story/<id>/<id>_data.gd` → `case.requires` 검사 → `StoryState(id)` → `StoryRunner` → `<id>_case.gd` → actors/objects/triggers/props → `Progress.save_case(id)`(`cases.<id>` + `vars`)

| 위치 | 단일 사건 가정 | 조치 |
|---|---|---|
| `story_director.gd` `const CASES` | 공간 하나에 사건 id 문자열 하나. 같은 공간에 둘째 사건을 둘 자리가 없음 | 등록부로 옮김 |
| `story_director._setup` | 경로를 `res://story/<id>/`로 직접 만들고, 파일이 없거나 해석 오류가 나면 `load().data()`에서 멈춤 | 등록부를 거치고, 없으면 소문만 도는 공간으로 계속 진행 |
| `story_director.outcome_var()` | 데이터에 값이 없으면 기본으로 `CASE_NAMWON_OUTCOME`을 씀. 새 사건이 남원 결말을 덮을 수 있었음 | 기본값을 `CASE_<ID>_OUTCOME`으로 바꿈. 남원은 데이터에 값이 있어서 결과가 같음 |
| `story_state.clear_saved()` | `reset_vars`가 없으면 남원 변수(`CASE_NAMWON_COMPLETE` 등)를 되돌림. 새 사건을 새로 시작하면 남원 완료가 지워질 수 있었음 | 기본 목록은 `namwon`일 때만 쓰고, 다른 사건은 빈 목록 |
| `map_leads.gd` `CASE_IDS` | 사건 목록을 따로 고정해 둠. 표지 자체는 사건별 `case` 키로 갈려서 서로 덮이지는 않음 | 목록을 등록부에서 가져옴 |
| `journal_book._case_data()` | 경로 규칙을 직접 만듦. 다른 사건은 읽기만 하고 지우거나 덮지 않음 | 경로를 등록부에서 가져옴 |
| `tools/story/validate_event_class.gd` `CASES` | 고정 목록 | 등록부에서 가져옴 |
| `map_leads.visible`, `horse_ride`, `onboarding`, `save_keeper.meta`, `journal`의 "지금 사건" | 활성 사건 하나(`d.case_id`)만 '살아 있는' 사건으로 봄 | 그대로 둠. 이번 단계 설계("한 번에 한 사건 활성")와 맞음 |
| `StoryState.vars` / `Progress.save_case` | 저장할 때 상태가 가진 vars 스냅숏 전체를 merge함 | 그대로 둠. 5절 위험 참고 |

## 2. 변경한 구조 (파일별)

- **새 파일 `scripts/story/case_registry.gd`**: 등록부(정적 함수, RefCounted)
  - `SPACE_CASES`: 공간 → 사건 id 배열. 지금은 예전 `CASES`와 똑같이 공간마다 기존 사건 하나만 있음(12개 공간).
  - `cases_for(space)`: 등록된 id 가운데 `<id>_data.gd`와 `<id>_case.gd`가 모두 있는 것만 돌려줌. 파일이 없으면 `CASEREG … 건너뜀` 로그를 한 번 남기고, 실제 로드는 하지 않음.
  - `all_ids()` / `load_data(id)`: 파일이 없거나 해석에 실패하면 `{}`를 돌려줌.
  - `data_path`, `case_path`, `test_path`, `dir_of`: 기본 경로는 `res://story/<id>/`.
  - `unmet_key`, `requires_met`, `choose(cands)`: 예전 requires 규칙을 그대로 옮김(쉼표 목록이면 포함 여부로 판단). 여러 후보 중에서는 "요구 조건이 맞고 아직 끝나지 않은 첫 사건 → 없으면 요구 조건이 맞는 첫 사건 → 없으면 `""`" 순서로 고름.
  - `register()` / `clear_extra()`: 시험 전용 추가 등록이고 놀이 중에는 부르지 않음.
- **`scripts/story/story_director.gd`**
  - `CASES`를 지우고 `CaseRegistry`를 preload함. `create_for`는 더 이상 `case_id`를 미리 정하지 않음.
  - `_setup` 순서: 후보 = `cases_for(space)` → 대본 시험이면 이름 앞부분(`namwon:A` → `namwon`)이 후보에 있을 때 그 사건만 남김 → (시험) `prepare` → `choose()` → 사건 스크립트 로드(실패하면 소문만 도는 공간으로 진행) → `_filter_space` → 예전과 같은 방식으로 `StoryState` / `StoryRunner` / `case_fn`을 연결.
  - `outcome_var()` 기본값을 `CASE_<ID>_OUTCOME`으로 바꿈.
  - 로그 문구 `STORY case=… 아직 아님(…)`은 그대로 유지함.
- **`scripts/story/story_state.gd`**: `clear_saved()`의 기본 reset 목록을 namwon 전용으로 한정함.
- **`scripts/region/map_leads.gd`**: `CASE_IDS`를 지우고 `CaseRegistry.all_ids()` / `load_data()`를 씀. 순서는 예전과 같음(시험에서 확인).
- **`scripts/story/journal_book.gd`**: `_case_data()`가 `CaseRegistry.load_data()`를 씀. 파일이 없으면 예전처럼 null을 돌려줌.
- **`tools/story/validate_event_class.gd`**: 검사 목록을 `CaseRegistry.all_ids()`에서 가져옴(예전과 같은 여덟 사건).
- **새 파일 `tests/registry/case_registry_test.gd`**: 구조 시험 A~E(47개 항목).
- **새 파일 `tests/registry/reg_dummy/reg_dummy_data.gd`, `reg_dummy_case.gd`**: 시험 전용 가짜 사건. `SPACE_CASES`에는 없고, 시험이 실행 중에만 `register()`로 잠깐 올림. 놀이 콘텐츠에는 나오지 않음.
- **새 파일 `docs/reports/multi-case-registry.md`**: 이 보고서.

저장 형식은 바꾸지 않았습니다. `version` 2를 유지했고, `cases.<id>`와 `vars`도 그대로이며, `namwon` id도 바꾸지 않았습니다. 새 사건은 `cases.namwon_chunhyang` 같은 키로 따로 저장되고, 완료 변수는 `skills.complete_var()` 규칙에 따라 `CASE_NAMWON_CHUNHYANG_COMPLETE`가 됩니다(시험에서 확인).

## 3. 변경하지 않은 것

- **남원 v3.2 시나리오 내용은 그대로입니다.** `story/namwon/*`(namwon_case.gd의 밤 장면, `mother_flashback()`, 동아줄 연출, 대사, 결말 A/B/C), 그리고 다른 모든 `story/<사건>/` 데이터·스크립트·시험 파일은 손대지 않았습니다(`git diff`에 `story/`가 없음).
- StoryRunner, DSL, StoryUI, CombatView, Onboarding, SaveKeeper, title_menu, progress.gd, 전투 밸런스, 튜토리얼, 오디오, UI, 카메라, 기존 시험 fixture도 수정하지 않았습니다.
- 콘텐츠 쪽에서 문제로 보고할 것은 없습니다. 다만 사건 데이터 주석 몇 곳(`hwangju_data.gd` 등 8행 "story_director CASES")이 이제 등록부를 가리켜야 하는데, 콘텐츠 파일이라 고치지 않았습니다.

## 4. 테스트 결과 (실제로 실행한 것만)

로그: `/private/tmp/…/scratchpad/{baseline,after,after2}/` (임시 위치)

| 시험 | 수정 전 | 수정 후 |
|---|---|---|
| `tools/run_story_tests.sh` 전체 44개(namwon:A/B/C/onboard, hanyang×3, gangneung×3, gyeongju×2, hwangju×3, pyongyang×3, hamhung×4, jeju×3, walk×2, ride×6, fast×3, station×2, talk×3, continue:namwon-early, continue:new, save:slot-load) | 44/44 PASS | 44/44 PASS (SCRIPT ERROR 0) |
| 필수 항목: namwon:A/B/C, namwon:onboard, continue:namwon-early, continue:new, save:slot-load, talk:namwon | PASS | PASS. 결말 A/B/C와 detail(A_hold, B_hold, C)이 같음 |
| `tools/story/map_leads_test.gd` | PASS fixtures=45 | PASS fixtures=45 |
| `tools/story/validate_event_class.gd` | PASS checked=126 | PASS checked=126 |
| `tests/registry/case_registry_test.gd` (A~E, 새 시험) | 해당 없음 | REGTEST PASS 47 |
| namwon:A/B/onboard 재실행 | 해당 없음 | PASS |

- 44개 로그 모두에서 사건 준비 줄(`STORY ready/loaded case=… phase=… actors=… props=… events=…`)이 수정 전후로 같았습니다.
- 몇몇 로그에서 선택 단서(`blood`)나 소리 시각이 달랐는데, 이는 시험 봇의 경로 편차입니다. 수정 전 기준선에서도 namwon:B에서 같은 차이가 났고, 재실행하면 바뀌며, 결말은 같았습니다.
- **Godot 실행 확인(창 모드, 자동)**: 시험용 저장 파일(`user://st_smoke_*.json`, 끝난 뒤 지움)로 `--uishots`(기록책 8갈피, Esc 메뉴, 저장·불러오기 창, 조사 카드, 대화, 선택, 도장)와 `--mapshots`(남원 고을·권역·전국 지도)를 **수정 전과 후에 각각 찍어 픽셀을 비교**했습니다.
  - 지도 3장은 차이 0픽셀이었습니다.
  - UI 화면은 책·창 부분이 같았고, 차이는 배경에서 걸어 다니는 마을 사람들뿐이었습니다(눈으로 확인).
- **손으로 하는 GUI 플레이는 하지 않았습니다.** 새 게임 → 남원 진입 → 주모·오누이에게 말 걸기 → 기록책 → 지도 → 저장 후 이어하기를 사람이 키보드로 직접 해 보지는 않았습니다. 이 흐름은 다음으로 대신 확인했습니다.
  - continue:new: 시작 메뉴 → 새 게임 → 이야기 인물과 고을 사람에게 E로 말 걸기
  - continue:namwon-early: 옛 저장으로 이어하기
  - talk:namwon: 남원 인물 대화 24회
  - save:slot-load: 칸 저장·불러오기, 버전 1 저장 읽기
  - 위 창 모드 스크린숏
- 사용자의 실제 저장(`progress.json`, 칸 파일)은 건드리지 않았고, 사용자의 `godot --path .` 프로세스도 종료하지 않았습니다.
- 참고: 처음 돌린 기준선은 실행 도중 제가 파일을 고치기 시작해 결과가 오염되었습니다. 그래서 중단하고 HEAD로 되돌린 상태에서 다시 돌렸고, 위 표의 "수정 전"은 그 깨끗한 실행 결과입니다.

## 5. 남은 위험 (다중 사건 실제 콘텐츠를 넣기 전에 필요한 것)

1. **한 공간에서 한 번에 한 사건만 활성화됩니다.** 다른 등록 사건의 actor/object/trigger/prop은 그 사건이 활성일 때만 생깁니다. 예를 들어 남원이 진행 중이면 춘향 인물은 서지 않습니다. 여러 사건의 인물이 동시에 서야 한다면 "비활성 사건의 actor/prop만 띄우는 얕은 층"이 다음 작업으로 필요합니다. 이때 id 충돌을 막기 위해 사건 접두사 규칙을 정해야 합니다.
2. **활성 사건 전환은 장면을 열 때(`_setup`)만 일어납니다.** 남원을 끝낸 같은 장면 안에서 바로 춘향이 시작되지는 않고, 공간에 다시 들어오거나 불러오기를 해야 합니다. 같은 장면에서 이어지게 하려면 director에 "사건 바꾸기"(runner/actors 정리 후 재연결)가 필요합니다.
3. **`StoryState.vars` 스냅숏 덮어쓰기**: `save_case`가 상태의 vars 전체를 merge합니다. 지금은 StoryState가 한 번에 하나라 문제가 없지만, 두 상태를 동시에 살려 두면 오래된 스냅숏이 다른 사건의 공통 변수(예: `CASE_NAMWON_COMPLETE`)를 되돌릴 수 있습니다. 동시 실행을 하게 되면 "바뀐 키만 저장"으로 고쳐야 합니다.
4. **새 사건 데이터에 꼭 넣을 것**: `case.outcome_var`, `case.reset_vars`, `case.requires`(예: `CASE_NAMWON_COMPLETE: true`), `record_title`.
   - `reset_vars`가 없으면 이제 아무 공통 변수도 되돌리지 않습니다.
   - `journal_book.CASE_TITLES`에 없는 사건은 `record_title`이 제목으로 쓰입니다.
5. **고르기 규칙(`choose`)은 잠정 정책입니다.** 남원과 춘향이 둘 다 요구 조건을 만족하고 끝나지 않았다면 먼저 등록된 쪽이 섭니다. 실제 v3.2 흐름(언제 어느 사건이 서는가)에 맞춰 사건 데이터의 requires로 정하거나, 필요하면 규칙을 다듬어야 합니다.
6. **대본 시험 이름 규칙**: `--storytest=<사건id>:<갈래>`의 앞부분이 이 공간의 사건 id이면 그 사건만 후보로 남깁니다. 새 사건의 시험 이름은 사건 id로 시작해야 합니다(예: `namwon_chunhyang:A`).
7. **기록책 '사건 기록'은 지금 사건만 자세히 보여 주고**, 나머지 사건은 제목과 진행 상태만 보여 줍니다(지우지 않음). 같은 공간 사건끼리 묶어 보여 주는 것은 하지 않았습니다.
8. `save_keeper.meta`의 칸 목록 '사건'은 활성 사건 하나만 적습니다.

## 6. 다음 단계 판단

**남원 v3.2 구현을 시작해도 됩니다.** 기존 남원 흐름은 바뀌지 않았고(필수 시험 모두 PASS, 준비 줄 동일), 둘째·셋째 사건은 다음 순서로 더할 수 있습니다.

1. `story/namwon_chunhyang/` 아래에 `namwon_chunhyang_data.gd`와 `namwon_chunhyang_case.gd`를 만듭니다. 형식은 기존 사건 데이터와 같습니다.
2. `case_registry.gd`의 `SPACE_CASES["JL_NAMWON_UNBONG"]`에 id를 덧붙입니다.

다만 v3.2가 **남원 진행 중에 춘향·흥부 인물이 같은 마을에 함께 서 있어야 하는 설계**라면, 콘텐츠를 넣기 전에 5절 1번(비활성 사건 인물 띄우기)과 2번(같은 장면 안 전환)을 작은 단계로 먼저 하는 것을 권합니다. 오누이(namwon) 하나만 먼저 v3.2로 구현한다면 지금 구조로 충분합니다.
