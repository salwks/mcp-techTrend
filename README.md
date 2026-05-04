# trends-mcp

[![mcp-techTrend MCP server](https://glama.ai/mcp/servers/salwks/mcp-techTrend/badges/score.svg)](https://glama.ai/mcp/servers/salwks/mcp-techTrend)

> 한국어 문서: **[README.ko.md](README.ko.md)**

A single MCP server that pulls **academic + code + medical-device-regulatory**
trend data from seven sources and renders newspaper-style briefings — with
per-domain tuning baked in.

| Source | Tools | Notes |
|---|---|---|
| arXiv | `arxiv_recent`, `arxiv_search` | Per-category round-robin so small categories aren't drowned by big ones |
| PubMed | `pubmed_search` | Full abstracts via `efetch.fcgi` |
| HF Daily Papers | `paperswithcode_trending` | Sorted by community upvotes (replaces sunset PwC API) |
| GitHub | `github_trending`, `github_search` | Trending page scrape + Search API with `created:>` date filter |
| Hugging Face | `huggingface_trending` | Models / datasets / spaces, trending or recent |
| openFDA 510(k) | `fda_510k_recent` | Device clearances |
| openFDA Recalls | `fda_recalls_recent` | Recall events with class filter |
| **(aggregators)** | `trends_digest`, `trends_briefing` | Multi-source parallel calls |

`trends_briefing` is the headline tool: invoke "weekly news" / "주간 뉴스" and
get a newspaper-formatted briefing across all enabled sources, automatically
translated into the user's conversation language by the LLM.

---

## Why this exists

Most academic / code / regulatory MCP servers are single-source. This one is
multi-source **and domain-aware**: a researcher tracking medical-imaging AI,
an ML engineer following ML papers, a security analyst watching CVEs and
trending repos — all configure once via `python configure.py`, then
`trends_briefing` becomes the "Monday morning newspaper" for their domain.

What makes it useful:
- **Newspaper format** with translation hint — the LLM auto-translates source
  text (paper abstracts, recall reasons, etc.) to your conversation language
  while preserving identifiers, URLs, and metric values verbatim.
- **Per-category round-robin** for arXiv — `cs.HC` (~50 papers/wk) doesn't
  get drowned by `cs.LG` (~1500/wk) when both are tracked together.
- **TTL cache + concurrent-request coalescing** — repeat calls and parallel
  briefings don't hammer upstream APIs.
- **No required tokens.** All seven sources work anonymously; tokens just
  raise the per-source rate limit ceiling.
- **Sandbox-safe Python launcher.** Bypasses the `claude_desktop_config.json`
  `env` block (which truncates whitespace-containing values on some macOS
  builds) by setting environment variables in Python before handing off to
  the server.

---

## Install

```bash
git clone https://github.com/salwks/mcp-techTrend.git
cd mcp-techTrend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

Connect to Claude Desktop by editing
`~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "trends": {
      "command": "/path/to/trends-mcp/.venv/bin/python",
      "args": ["/path/to/trends-mcp/run.py"]
    }
  }
}
```

> ⚠️ `args` points at `run.py` (the launcher), **not** `trends_mcp.py`.
> The launcher sets domain-specific env vars before the server starts.

Restart Claude Desktop. The `trends` server should appear with 11 tools.

---

## Configuration

**One source of truth: `run.py`.** Two ways to edit it:

### A. Interactive TUI — `configure.py` (recommended)

```bash
python configure.py
```

```
═══ trends-mcp 설정 ═══
  [1] Active sources       (7/7 enabled)
  [2] arXiv categories     (4 entries · 13 papers/wk)
  [3] PubMed query
  [4] API tokens           (0/4 set)
  [5] Show current config
  [6] Save and restart
  [7] Quit without saving
```

Toggle sources with numbers, set arXiv weights with `set 1 7`, apply presets
with `preset medical-imaging`, save with `[6]`. The save action backs up to
`run.py.bak`, writes the new SETTINGS block (AST-based — never touches
non-config code), and runs `pkill -f trends_mcp` so Claude Desktop respawns
the server with the new config on next call.

> The TUI menu labels are in Korean; commands and presets are in English.
> i18n of the TUI itself is on the v0.2 roadmap.

Single-shot modes:
```bash
python configure.py --show       # print current config
python configure.py --restart    # pkill stale MCP processes
```

### B. Direct edit — `run.py` SETTINGS block

```python
TRENDS_ENABLED_SOURCES = ""                          # "" = all
TRENDS_ARXIV_CATEGORIES = "cs.LG:5,cs.CV:3,cs.CL:3,cs.AI:2"
TRENDS_DEFAULT_PUBMED_QUERY = "(deep learning OR AI) AND (medical OR clinical)"
# GITHUB_TOKEN = "ghp_..."         # raises 60 → 5,000 req/h
# HF_TOKEN = "hf_..."
# NCBI_API_KEY = "..."             # raises 3 → 10 req/s for PubMed
# OPENFDA_API_KEY = "..."          # raises 240 → 120,000 req/day
```

Restart Claude Desktop after saving (or `pkill -f trends_mcp`).

### Presets

```python
# AI/ML researcher (default)
TRENDS_ARXIV_CATEGORIES = "cs.LG:5,cs.CV:3,cs.CL:3,cs.AI:2"

# Medical imaging / clinical AI
TRENDS_ARXIV_CATEGORIES = "eess.IV:5,cs.CV:3,cs.HC:2,q-bio.QM:2"

# Robotics
TRENDS_ARXIV_CATEGORIES = "cs.RO:5,cs.AI:3,cs.LG:2,cs.CV:2"

# HCI / UX
TRENDS_ARXIV_CATEGORIES = "cs.HC:5,cs.CY:3,cs.AI:2,cs.SI:2"

# Security
TRENDS_ARXIV_CATEGORIES = "cs.CR:5,cs.LG:2,cs.NI:2"

# Computational biology
TRENDS_ARXIV_CATEGORIES = "q-bio.QM:4,q-bio.GN:3,q-bio.BM:3,stat.AP:2"
```

Common arXiv categories (full reference: [`ARXIV_CATEGORIES.md`](ARXIV_CATEGORIES.md)):

| Code | Field | Weekly papers (approx) |
|---|---|---|
| `cs.AI` | Artificial Intelligence | 500–800 |
| `cs.LG` | Machine Learning | 1,500–2,000 (largest) |
| `cs.CV` | Computer Vision | 1,000–1,500 |
| `cs.CL` | NLP | 500–800 |
| `cs.HC` | HCI / UX | 50–100 |
| `cs.RO` | Robotics | 100–200 |
| `cs.CR` | Security | ~200 |
| `eess.IV` | Image/Video Processing (medical imaging) | 100–200 |
| `q-bio.QM` | Quantitative biology | 50–100 |

### Source allowlist

```python
TRENDS_ENABLED_SOURCES = "arxiv,github,huggingface,paperswithcode"
# → fda_510k, fda_recalls, pubmed tools won't appear in the tool list at all
```

Empty / `"*"` / `"all"` = enable everything. Disabled sources don't register
their tools, so the chat tool list itself shrinks. `trends_digest` and
`trends_briefing` remain registered and skip disabled sources gracefully.

---

## Tools

| Tool | Purpose |
|---|---|
| `arxiv_recent` | Recent papers in one category, by submission date |
| `arxiv_search` | Keyword / field-syntax search (`ti:`, `au:`, `abs:`, `cat:`) |
| `pubmed_search` | PubMed search (MeSH terms, field tags) — abstracts via efetch |
| `paperswithcode_trending` | HF Daily Papers, sorted by community upvotes |
| `github_trending` | Browse github.com/trending (HTML scrape) |
| `github_search` | GitHub Search API; `days` filters by `created:` |
| `huggingface_trending` | HF Hub models / datasets / spaces |
| `fda_510k_recent` | Recent FDA 510(k) clearances |
| `fda_recalls_recent` | Recent FDA medical-device recalls (class filter) |
| `trends_digest` | Multi-source bullet-list digest, given a topic |
| `trends_briefing` | Multi-source newspaper briefing; topic optional |

All search tools accept `days=N` for recent-N-days filtering. `trends_briefing`
groups results into 🎓 Research / 💻 Code & Models / 🏥 Regulatory sections.

### `trends_digest` vs `trends_briefing`

|  | `trends_digest` | `trends_briefing` |
|---|---|---|
| Topic | required | optional ("what's new" mode) |
| Source range | configurable subset (default 4) | all enabled sources |
| Format | bullet-list digest | grouped newspaper format |
| Use case | topic deep-dive | regular weekly briefing |

---

## Caching

Per-process in-memory TTL cache wraps every HTTP response. Concurrent
identical requests are coalesced via per-key `asyncio.Lock` — N parallel
callers fire one upstream request.

| TTL group | Length | Tools |
|---|---|---|
| Trending | 5 min | `github_trending`, `paperswithcode_trending`, `huggingface_trending` (trending sort), `github_search` (with `days`) |
| Default | 10 min | `arxiv_recent`, `arxiv_search`, `github_search`, `huggingface_trending` (other sorts) |
| Static | 1 hour | `pubmed_search`, `fda_510k_recent`, `fda_recalls_recent` |

Up to 256 entries; oldest evicted when full. No way to disable — TTLs are
short enough that staleness is bounded.

---

## Known limitations

- **GitHub Trending** is HTML scraping — no official API exists. Layout
  changes can break it. Stable trending substitute: `github_search` with
  `days=7` and `sort=stars`.
- **HF `trendingScore`** is undocumented. API surface may change.
- **HF Daily Papers** covers ~50 curated papers/day, not all of arXiv. It's
  a "what was talked about" feed, not exhaustive.
- **arXiv** has no native trending — we approximate via category-balanced
  recent-submissions feeds.
- **openFDA `classification` field** sometimes returns `None` even on
  recently classified recalls (upstream data lag). Search index lags too.

---

## Roadmap (TODO)

- v0.2: i18n for the TUI menu and briefing section headers
- bioRxiv / medRxiv via RSS
- Semantic Scholar (citation graph)
- openFDA Adverse Events (MAUDE)
- EU EUDAMED scraping
- PMDA (Japan medical devices)
- MFDS (Korea medical devices)
- Mock-based test suite for CI

---

## License

[MIT](LICENSE)
