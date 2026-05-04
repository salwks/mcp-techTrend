# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-05-04

First public release.

### Tools (11)
- `arxiv_recent`, `arxiv_search` — recent papers in a category, keyword/field search
- `pubmed_search` — PubMed search with full abstracts (esearch + esummary + efetch)
- `paperswithcode_trending` — backed by HF Daily Papers (PwC API was sunset
  after the 2024 HF acquisition); sorted by community upvotes by default
- `github_trending` — github.com/trending HTML scrape
- `github_search` — GitHub Search API; `days` filter via `created:>YYYY-MM-DD`
- `huggingface_trending` — HF Hub models / datasets / spaces, multiple sort keys
- `fda_510k_recent` — openFDA 510(k) clearances with date filter
- `fda_recalls_recent` — openFDA recall events; class filter (Arabic↔Roman normalized)
- `trends_digest` — multi-source bullet-list digest for a topic
- `trends_briefing` — newspaper-style briefing across all enabled sources

### Configuration
- **`run.py` Python launcher** — single source of truth for env vars. Bypasses
  `claude_desktop_config.json`'s `env` block, which truncates whitespace-
  containing values on some macOS builds. Also sandbox-safe (no shell wrapper).
- **`configure.py` interactive TUI** — menu-driven settings editor with
  checkbox-style source toggles, weighted arXiv categories, PubMed presets,
  AST-based in-place save, automatic `pkill -f trends_mcp` on save.
- Single-shot CLI: `python configure.py --show` / `--restart`.
- arXiv presets: `ai-ml` (default), `medical-imaging`, `robotics`, `hci`,
  `security`, `bio`.
- PubMed presets: `medical-imaging`, `general-medical` (default), `cardiology`,
  `ophthalmology`, `pathology`.

### Aggregator features
- **Per-category round-robin for arXiv** — small categories (e.g. `cs.HC`,
  ~50/wk) aren't drowned out by large ones (`cs.LG`, ~1500/wk). Sequential
  per-category fetches with 0.35s spacing to avoid arXiv burst-rate-limit;
  one automatic retry on HTTP 429 with 2s backoff.
- **Newspaper format with translation hint** — `trends_briefing` emits
  grouped sections (🎓 Research / 💻 Code & Models / 🏥 Regulatory) plus an
  HTML-comment footer instructing the LLM to translate content to the user's
  conversation language while preserving IDs, URLs, and metric values.
- **HF Daily Papers community signals** — captures `paper.upvotes`,
  `numComments`, and `paper.ai_summary` (one-line LLM-generated lede); used
  for trending sort and the briefing's "what's hot" section.
- **PubMed abstract fetching** — second-stage `efetch.fcgi` call enriches
  search results with structured `BACKGROUND/METHODS/RESULTS` text.

### Performance
- Per-process in-memory TTL cache (5 min trending / 10 min default / 1 hour
  static) wraps every HTTP response.
- Per-key `asyncio.Lock` coalesces concurrent identical requests — N parallel
  callers fire one upstream HTTP roundtrip.
- Cache size capped at 256 entries; oldest evicted when full.

### Source allowlist
- `TRENDS_ENABLED_SOURCES` env var (also exposed in `configure.py`) gates
  which sources register their tools. Disabled sources don't appear in the
  client's tool list at all.

### Distribution
- MIT license
- Domain-neutral defaults (`cs.LG:5,cs.CV:3,cs.CL:3,cs.AI:2` for arXiv)
- Korean docs preserved as `README.ko.md`; English `README.md` is canonical
- `ARXIV_CATEGORIES.md` reference covers 200+ category codes plus weekly
  paper counts and workflow presets

### Known issues / future work (v0.2+)
- TUI menu labels are Korean — i18n planned
- Briefing section headers (`🎓 연구 동향` etc.) are Korean — i18n planned
- No mock-based unit tests yet (live smoke test in `tests/smoke_test.py`
  hits real APIs)
- bioRxiv / medRxiv, Semantic Scholar, openFDA Adverse Events (MAUDE), EU
  EUDAMED, PMDA, MFDS not yet supported
