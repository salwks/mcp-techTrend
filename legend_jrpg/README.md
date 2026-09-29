# 빛의 계승자 (The Heir of Light)

고전 영웅전설 스타일의 웹 브라우저 JRPG입니다.
평범한 소년 **렌**이 봉인된 성검에 선택받아 용사가 되고, 여정 중에 만난 동료
**미아**(사제), **가렌**(기사), **셀라**(마법사)와 함께 **마왕 자르가스**를 쓰러뜨리는 이야기입니다.

이 게임은 **여러 AI 에이전트가 역할을 나눠 협업하는 방식**으로 만들었습니다.

## 실행 방법

ES 모듈을 쓰기 때문에 파일을 더블클릭하면 실행되지 않습니다. 간단한 로컬 서버로 열어주세요.

```bash
cd legend_jrpg
python3 -m http.server 8000
# 브라우저에서 http://localhost:8000
```

설치나 빌드는 필요 없고, 외부 라이브러리·이미지·오디오 파일도 쓰지 않습니다.
그래픽과 음악은 모두 코드로 생성합니다.

## 조작

| 동작 | 키보드 | 모바일 |
|---|---|---|
| 이동 / 커서 | 방향키, WASD | 십자 패드 |
| 확인 / 대화 / 조사 | Z, Enter, Space | A |
| 취소 | X, Backspace | B |
| 메뉴 | Esc, M, C | 메뉴 |

## 에이전트 팀 구성

| 에이전트 | 담당 | 파일 |
|---|---|---|
| 총괄(오케스트레이터) | 기획서, 인터페이스 계약, 엔진 코어, 통합 | `docs/`, `src/engine/`(audio 제외), `src/ui/window.js`, `src/main.js` |
| `field-dev` | 필드 이동, 타일·캐릭터 도트, 이벤트 실행기 | `src/field/` |
| `world-designer` | 시나리오, 대사, 맵, 이벤트 | `src/data/maps.js`, `src/data/events.js` |
| `battle-dev` | 턴제 전투, 적, 스킬·아이템, 밸런스 | `src/battle/`, `src/systems/`, `src/data/{skills,items,enemies,troops,encounters}.js` |
| `ui-dev` | 타이틀, 메뉴, 상점, 세이브, 엔딩 | `src/ui/scenes/` |
| `sound-dev` | 칩튠 BGM·효과음(WebAudio) | `src/engine/audio.js` |
| `qa-tester` | 데이터 검증, 자동 플레이 테스트 | `tools/` |

에이전트 정의는 `.claude/agents/*.md`에 있습니다. 이 폴더를 Claude Code 프로젝트로 열면
"battle-dev에게 보스 밸런스 조정을 맡겨줘"처럼 역할별로 작업을 맡길 수 있습니다.

협업 규칙:
1. `docs/GDD.md`: 스토리, 캐릭터, 모든 ID(스킬·아이템·맵·보스)를 고정합니다.
2. `docs/CONTRACTS.md`: 모듈 간 데이터 형식과 API를 정의합니다. 에이전트는 이 계약만 보고 병렬로 개발합니다.
3. 파일 소유권을 나눠서 동시에 수정할 때 충돌이 나지 않게 합니다.
