# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] — 2026-05-21

### Fixed — arXiv briefing reliability

- **Fully serial per-category fetch.** The briefing previously fetched
  arXiv categories 2-at-a-time (`ARXIV_BATCH_SIZE=2`) with a 3s gap.
  arXiv's API TOU asks for *serial* access with ≥3s spacing, and in
  practice the 2-concurrent pattern tripped HTTP 429 even on light,
  single-user traffic. Now `ARXIV_BATCH_SIZE=1` with a 5s gap (~20-25s
  for 4 categories — well inside the MCP client timeout).
- **Rate-limit failures are now visible.** `_fetch_arxiv_for_category_safe`
  used to swallow every error into `[]`, so a 429 made the briefing's
  arXiv section silently empty — indistinguishable from "no new papers"
  and easy to misdiagnose as a server bug. It now returns
  `(error_msg, papers)`; the briefing aggregates per-category results
  and surfaces a representative error when all categories fail (partial
  success still degrades gracefully — available papers are shown).
- **Dropped the 2s-after-429 retry.** arXiv expects a 30-60s cooldown
  after a 429; a 2s retry almost always hit 429 again and just burned
  the briefing's time budget. 5xx still gets one 1s retry.

## [0.2.0] — 2026-05-06

### Added — chat-side configuration tools (5)
Settings can now be edited from chat as well as `configure.py` — both paths
read & write the same `run.py` SETTINGS block via the shared `Config` class
in configure.py, so changes from either side are visible to the other.

- `trends_get_config` — show current sources / categories / pubmed query /
  which tokens are set. Token VALUES are never returned.
- `trends_set_enabled_sources(sources)` — toggle active sources. `["*"]` /
  `["all"]` enables all.
- `trends_set_arxiv_categories(categories)` — set `[code:weight, …]`.
  Validated against the full 200+ arXiv category list.
- `trends_set_pubmed_query(query)` — set the default PubMed query used by
  `trends_briefing` when no topic is given.
- `trends_set_token(provider, value)` — set/clear an optional rate-limit
  token. `provider` ∈ {github, hf, ncbi, openfda}. Description carries
  minimal-scope guidance (no `repo`-scoped GitHub PATs).

### Security — RCE in chat-side config writes (CVE-track candidate)
The first-pass implementation of the chat-side tools wrote user-supplied
strings into `run.py` via simple f-string interpolation (`f'"{p}"'`).
Run.py is parsed and executed by Python at the next MCP spawn, so a value
like `foo" + __import__("os").system("...") + "bar` would break out of
the string literal and execute arbitrary code at next Claude Desktop
launch.

Fixed in three layers:
- `_format_pubmed_literal` and the token write path now encode values via
  `json.dumps()`. JSON string syntax is a strict subset of Python's, so
  the result is always a safely-escaped Python literal.
- New `_PY_STR_LIT` regex (`"(?:[^"\\]|\\.)*"`) replaces all `"[^"]*"`
  patterns. The naive form truncated mid-value when a stored literal
  contained `\"`, leaving residual chars after substitution and corrupting
  the file on subsequent updates.
- A latent ordering bug in the token write (running both `# KEY = "..."` →
  `KEY = "..."` and a redundant follow-up `KEY = "..."` → `KEY = "..."`
  substitution) is collapsed via `re.subn` so only one fires.

Verified: PoC payload now stored as data, file remains valid Python through
set / update / clear cycles, smoke test 18/19 (unchanged).

### Fixed
- `configure.py` `save()` corrupted run.py when the multi-line PubMed query
  contained nested parens (the default did). Latent because `save()` had
  never actually been exercised on the default. Replaced regex `\(.*?\)`
  (lazy + DOTALL — stops at first `)` inside the query) with AST-line-range
  substitution.
- `trends_set_enabled_sources` displayed `(all) → (none)` when the user
  passed all 7 sources explicitly. Pure display bug — the underlying state
  was correct (Config stores `""` as the "enable everything" sentinel).

### Internal
- `_format_pubmed_literal` indentation aligned to 4 spaces so save is
  idempotent on no-change saves.

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
