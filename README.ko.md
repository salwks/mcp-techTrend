# trends-mcp

> English docs: **[README.md](README.md)**

학술(arXiv, PubMed, Papers with Code) · 코드(GitHub, Hugging Face) · 의료기기 규제(openFDA 510(k)/Recalls) 트렌드를 한 번에 조회하는 MCP 서버입니다. Claude Desktop 등 stdio MCP 클라이언트에서 사용합니다.

## 도구 목록

| 도구 | 카테고리 | 설명 |
|---|---|---|
| `arxiv_recent` | 학술 | 카테고리별 최근 N일 논문 (게시일 내림차순) |
| `arxiv_search` | 학술 | arXiv 키워드/문법 검색. `days`로 최근 N일 컷 가능 |
| `pubmed_search` | 학술 | PubMed 의학 논문 (MeSH/필드 태그 + `days` 지원) |
| `paperswithcode_trending` | 학술 | Papers with Code 검색/최신. `days`로 게시일 컷 가능 |
| `github_trending` | 코드 | github.com/trending 스크래핑 (비공식) |
| `github_search` | 코드 | GitHub Search API. `days`로 trending 근사 가능 |
| `huggingface_trending` | 코드 | HF Hub의 models / datasets / spaces. `days`로 lastModified 컷 가능 |
| `fda_510k_recent` | 규제 | FDA 510(k) 인허가 최신 |
| `fda_recalls_recent` | 규제 | FDA 의료기기 리콜 최신 (Class 필터 가능) |
| `trends_digest` | 통합 | 토픽 하나로 여러 소스 병렬 호출 → 마크다운 다이제스트(불릿) |
| `trends_briefing` | 통합 | "주간 뉴스" 스타일 — 토픽 없어도 활성 소스 전부 신문 포맷으로 흘림 |

모든 검색 도구는 `days` 파라미터로 최근 기간 필터링이 가능합니다. API가 자체 날짜 필터를 지원하지 않는 소스(arXiv search, Papers with Code, Hugging Face)는 충분히 오버페치 후 클라이언트에서 컷합니다.

### `trends_digest` vs `trends_briefing`

| | `trends_digest` | `trends_briefing` |
|---|---|---|
| 토픽 | **필수** | **선택** (없으면 "이번 주 새 소식") |
| 소스 범위 | 기본 4개 (사용자 지정 가능) | 활성 소스 **전부** |
| 출력 | 불릿 리스트 다이제스트 | 그룹화된 신문 포맷 (헤드라인-바이라인-리드) |
| 용도 | 토픽 deep-dive | 정기 브리핑 / 주간 뉴스 |

`trends_briefing`은 활성 소스를 자동으로 3개 그룹(`🎓 연구` / `💻 코드·모델` / `🏥 규제`)으로 묶어서 보여줍니다. 토픽 없이 호출하면 각 소스가 자연스러운 "최신 모드"로 동작합니다 — arXiv는 기본 카테고리(`cs.AI, cs.HC, cs.CV, eess.IV`)에서 최근 게시물, GitHub은 trending 페이지, PubMed은 의료 AI 관련 광역 질의 등. `arxiv_categories`/`pubmed_query` 파라미터로 기본값을 덮어쓸 수 있습니다.

## 캐싱

같은 쿼리를 짧은 시간 내 반복 호출 시 외부 API를 다시 치지 않도록 인메모리 TTL 캐시가 모든 HTTP 응답을 감쌉니다. 또한 동일 키에 대한 동시 호출은 in-flight future로 합쳐져 한 번만 upstream을 칩니다(`trends_digest`처럼 같은 토픽으로 여러 소스를 병렬 호출하는 시나리오에 유용).

| TTL 그룹 | 길이 | 적용 도구 |
|---|---|---|
| Trending | 5분 | github_trending, paperswithcode_trending, huggingface_trending(trending sort), github_search(`days` 사용 시) |
| Default | 10분 | arxiv_recent, arxiv_search, github_search, huggingface_trending(non-trending sort) |
| Static | 1시간 | pubmed_search, fda_510k_recent, fda_recalls_recent |

캐시는 프로세스 단위(서버 재시작 시 비움), 최대 256개 엔트리, LRU 유사(가장 오래된 엔트리부터 evict). 환경변수로 비활성화하는 옵션은 의도적으로 두지 않았습니다 — 짧은 TTL이라 즉각 무효화됩니다.

## 설치

```bash
cd /path/to/trend-mcp
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 설정

**모든 사용자 설정은 `run.py` 한 곳에서만 합니다.** Claude Desktop config의 `env` 블록은 의도적으로 사용하지 않습니다 — 일부 macOS 버전에서 공백 포함 multi-word value를 잘라먹고, sandbox + provenance 정책이 셸 wrapper도 차단하기 때문입니다. Python launcher가 가장 안정적입니다.

### 방법 A: 메뉴식 TUI — `configure.py` (추천)

```bash
cd /path/to/trends-mcp
python configure.py
```

체크박스로 소스 토글, 숫자 입력으로 카테고리 가중치 조정, 프리셋 한 줄 적용, 저장과 동시에 잔존 MCP 프로세스 정리까지 한 번에. 추가 의존성 0 (stdlib만 사용).

```
═══ trends-mcp 설정 ═══
  [1] 활성 소스         (7/7 활성)
  [2] arXiv 카테고리    (4개 · 합 12편/주)
  [3] PubMed 쿼리       (193자)
  [4] API 토큰          (0/4 활성)
  [5] 현재 설정 보기
  [6] 저장하고 재시작
  [7] 변경 취소하고 종료
```

**Single-shot 모드:**
```bash
python configure.py --show         # 현재 설정 출력 후 종료
python configure.py --restart      # 잔존 trends_mcp 프로세스만 종료
```

**arXiv 메뉴 명령 (메뉴 [2]번 안):**
- `set <번호> <개수>` — 가중치 변경 (예: `set 1 7`)
- `add <code> [개수]` — 추가 (예: `add cs.LG 4`)
- `remove <번호>` — 제거
- `preset <이름>` — 프리셋 적용 (`medical-imaging` / `ai-ml` / `robotics` / `hci` / `security` / `bio`)
- `list` — 전체 카테고리 200+개 페이저로 보기

**PubMed 메뉴 ([3]번 안):**
직접 입력 / 프리셋 적용 / 비우기. 프리셋: `medical-imaging`, `general-medical`, `cardiology`, `ophthalmology`, `pathology`.

**저장 시 동작:**
1. `run.py.bak`로 백업
2. SETTINGS 블록만 정확히 in-place 교체 (AST 기반 — 다른 코드 안 건드림)
3. `pkill -f trends_mcp`로 잔존 프로세스 정리
4. 다음 도구 호출 시 Claude Desktop이 새 설정으로 자동 respawn

### 방법 B: 직접 편집 — `run.py` 상단 4개 상수

```python
# ── run.py 상단 ──

# 1) 활성화할 소스 (빈 값 = 전부)
TRENDS_ENABLED_SOURCES = ""
#   예: "arxiv,github,huggingface,pubmed,fda_510k,fda_recalls"
#   유효: arxiv, github, huggingface, paperswithcode, pubmed, fda_510k, fda_recalls

# 2) arXiv 카테고리 + 가중치 (code:count 콤마 구분)
TRENDS_ARXIV_CATEGORIES = "eess.IV:5,cs.CV:3,cs.HC:2,q-bio.QM:2"
#   카테고리별 round-robin — 작은 카테고리(cs.HC ~50편/주)가
#   큰 카테고리(cs.LG ~1500편/주)에 묻히지 않도록 정확히 N건씩
#   가중치 생략 가능: "cs.HC,eess.IV" → 둘 다 default 3건

# 3) PubMed 광역 쿼리 (trends_briefing 토픽 없는 모드용)
TRENDS_DEFAULT_PUBMED_QUERY = (
    "(deep learning OR artificial intelligence OR machine learning) "
    "AND (mammography[Title/Abstract] OR breast cancer[Title/Abstract] "
    "OR medical imaging[Title/Abstract] OR radiology[Title/Abstract])"
)
#   PubMed 문법(MeSH, [Title/Abstract] 태그) 사용 가능
#   [Title/Abstract] 태그 없이 쓰면 너무 광역 매칭됨

# 4) (선택) API 토큰 — 주석 풀어서 채움
# GITHUB_TOKEN = "ghp_..."     # 60 → 5000 req/h
# HF_TOKEN = "hf_..."          # 인증/한도 향상
# NCBI_API_KEY = "..."         # 3 → 10 req/s
# OPENFDA_API_KEY = "..."      # 240 → 120,000 req/day
```

**적용 방법**: 편집 후 Claude Desktop **Cmd+Q → 재실행**. 잔존 trends 프로세스가 있으면 `pkill -f trends_mcp` 한 번.

### 워크플로우별 프리셋

```python
# AI/ML 연구자
TRENDS_ARXIV_CATEGORIES = "cs.LG:5,cs.CV:3,cs.CL:3,cs.AI:2"

# 의료 영상 / 임상 AI
TRENDS_ARXIV_CATEGORIES = "eess.IV:5,cs.CV:3,cs.HC:2,q-bio.QM:2"

# 로봇
TRENDS_ARXIV_CATEGORIES = "cs.RO:5,cs.AI:3,cs.LG:2,cs.CV:2"

# HCI / UX 연구
TRENDS_ARXIV_CATEGORIES = "cs.HC:5,cs.CY:3,cs.AI:2,cs.SI:2"

# 보안
TRENDS_ARXIV_CATEGORIES = "cs.CR:5,cs.LG:2,cs.NI:2"

# 계산생물학
TRENDS_ARXIV_CATEGORIES = "q-bio.QM:4,q-bio.GN:3,q-bio.BM:3,stat.AP:2"
```

### 자주 쓰는 arXiv 카테고리

전체 200+개는 [`ARXIV_CATEGORIES.md`](ARXIV_CATEGORIES.md) 참고.

| Code | 의미 | 주간 게시물 |
|---|---|---|
| `cs.AI` | AI 일반 | 500~800편 |
| `cs.LG` | 머신러닝 | 1,500~2,000편 (가장 많음) |
| `cs.CV` | 컴퓨터비전 | 1,000~1,500편 |
| `cs.CL` | NLP | 500~800편 |
| `cs.HC` | HCI / UX | 50~100편 |
| `cs.RO` | 로봇 | 100~200편 |
| `cs.NE` | 신경망 | ~100편 |
| `cs.CR` | 보안 | ~200편 |
| `stat.ML` | 통계 ML | 200~400편 |
| `eess.IV` | 영상처리 (의료영상) | 100~200편 |
| `eess.SP` | 신호처리 | ~150편 |
| `q-bio.QM` | 정량생물 | 50~100편 |

### 소스 활성화 / 비활성화

```python
# trends_briefing은 항상 등록. 다른 도구는 활성 소스만 등록됨.
TRENDS_ENABLED_SOURCES = "arxiv,github,huggingface,paperswithcode"
# → fda_510k, fda_recalls, pubmed 도구는 채팅에 안 보임
```

빈 값 / `"*"` / `"all"`은 전부 활성화. 알 수 없는 이름은 stderr에 경고 후 무시. `trends_digest`/`trends_briefing`은 항상 등록되며, 비활성 소스를 명시적으로 지정하면 거부합니다.

## Claude Desktop 연결

`~/Library/Application Support/Claude/claude_desktop_config.json` (macOS):

```json
{
  "mcpServers": {
    "trends": {
      "command": "/절대경로/trend-mcp/.venv/bin/python",
      "args": ["/절대경로/trend-mcp/run.py"]
    }
  }
}
```

⚠️ `args`는 `run.py` (launcher)지 `trends_mcp.py`가 아닙니다. launcher가 환경변수를 set한 후 본 서버를 실행합니다.

설정 후 Claude Desktop 재시작 → 도구 아이콘에 `trends`가 보이면 성공.

## 알려진 제약

- **GitHub Trending**은 페이지 스크래핑 → UI 변경 시 깨질 수 있음. 안정적인 trending이 필요하면 `github_search(query, days=7)`를 권장.
- **Hugging Face `trendingScore`**는 비공식 정렬 키. API 변경 가능성.
- **Papers with Code** 공식 trending 엔드포인트 없음 → 키워드 검색 또는 최신순으로 근사.
- **arXiv** 자체 trending 부재 → 카테고리별 최근 게시일 정렬로 근사.
- Reddit / Hacker News는 본 서버 범위 밖이라 의도적으로 제외.

## 확장 여지 (TODO)

- 식약처 의료기기 인허가 (공공데이터포털 API, 인증키 필요)
- bioRxiv / medRxiv (RSS 또는 API)
- Semantic Scholar (인용 네트워크)
- openFDA Adverse Events (MAUDE)
- EU EUDAMED (스크래핑)
- PMDA 일본 의료기기

## 라이선스

MIT
