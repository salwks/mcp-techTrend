"""trends_mcp — MCP server for academic / code / medical-device regulatory trends.

Single-file implementation. Run via `python trends_mcp.py` (stdio transport).
"""
from __future__ import annotations

import asyncio
import hashlib
import json
import os
import re
import time
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from enum import Enum
from typing import Any, Callable

import httpx
from bs4 import BeautifulSoup
from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, ConfigDict, Field

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

USER_AGENT = "trends-mcp/0.1"
HTTP_TIMEOUT = 20.0  # tight enough that 4-category arxiv round-robin stays
                     # under the MCP client's overall request timeout (~60-120s)

# TTL caching: keep recent API responses in memory to avoid repeated upstream
# calls within a short window. Tune per source — fast-moving pages get a short
# TTL, "static" searches (e.g. published papers) can hold longer.
CACHE_MAX_SIZE = 256
TTL_TRENDING = 300       # 5 min — github trending, hf trending, pwc trending
TTL_DEFAULT = 600        # 10 min — arxiv recent, github search, hf with filters
TTL_STATIC = 3600        # 1 h   — pubmed, fda, arxiv search (immutable history)

ARXIV_API = "https://export.arxiv.org/api/query"
PUBMED_BASE = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
# Papers with Code's API was sunset after Hugging Face acquired PwC in 2024;
# paperswithcode.com now serves HTML. We use HF's daily_papers feed instead —
# it's actually a richer source (editorial curation, comment counts, etc).
HF_DAILY_PAPERS_API = "https://huggingface.co/api/daily_papers"
GITHUB_API = "https://api.github.com/search/repositories"
GITHUB_TRENDING = "https://github.com/trending"
HF_API = "https://huggingface.co/api"
OPENFDA_510K = "https://api.fda.gov/device/510k.json"
OPENFDA_RECALL = "https://api.fda.gov/device/recall.json"

ATOM_NS = {"atom": "http://www.w3.org/2005/Atom"}


class ResponseFormat(str, Enum):
    MARKDOWN = "markdown"
    JSON = "json"


# ---------------------------------------------------------------------------
# Source allowlist (TRENDS_ENABLED_SOURCES env var)
# ---------------------------------------------------------------------------
# Each "source" gates one or more tools. Disabled sources are NOT registered
# with the MCP server, so they don't appear in the client's tool list at all.
# `trends_digest` is always registered but auto-restricts to enabled sources.

ALL_SOURCES: frozenset[str] = frozenset({
    "arxiv", "github", "huggingface", "paperswithcode",
    "pubmed", "fda_510k", "fda_recalls",
})


def _read_enabled_sources() -> frozenset[str]:
    raw = os.environ.get("TRENDS_ENABLED_SOURCES", "").strip()
    if not raw or raw in ("*", "all", "ALL"):
        return ALL_SOURCES
    parts = {p.strip().lower() for p in raw.split(",") if p.strip()}
    unknown = parts - ALL_SOURCES
    if unknown:
        import sys
        print(
            f"[trends-mcp] WARN: unknown sources in TRENDS_ENABLED_SOURCES: "
            f"{sorted(unknown)}. Valid: {sorted(ALL_SOURCES)}",
            file=sys.stderr,
        )
    return frozenset(parts & ALL_SOURCES)


ENABLED_SOURCES: frozenset[str] = _read_enabled_sources()


# ---------------------------------------------------------------------------
# FastMCP server
# ---------------------------------------------------------------------------

mcp = FastMCP("trends_mcp")


def _maybe_tool(*, source: str, **tool_kwargs: Any) -> Callable[[Callable[..., Any]], Callable[..., Any]]:
    """Register the tool only if its source is enabled. Otherwise leave the
    function defined (for internal reuse) but don't expose it via MCP."""

    def decorator(fn: Callable[..., Any]) -> Callable[..., Any]:
        if source in ENABLED_SOURCES:
            return mcp.tool(**tool_kwargs)(fn)
        return fn

    return decorator


# ---------------------------------------------------------------------------
# Common HTTP / error helpers
# ---------------------------------------------------------------------------

async def _http_get(
    url: str,
    *,
    params: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
    timeout: float | None = None,
) -> httpx.Response:
    """`timeout` overrides the global HTTP_TIMEOUT for this single call —
    useful for sources like arXiv where we want a tighter budget so a single
    hung category doesn't blow the multi-source briefing's overall budget."""
    h = {"User-Agent": USER_AGENT}
    if headers:
        h.update(headers)
    effective_timeout = timeout if timeout is not None else HTTP_TIMEOUT
    async with httpx.AsyncClient(timeout=effective_timeout, follow_redirects=True) as client:
        resp = await client.get(url, params=params, headers=h)
        resp.raise_for_status()
        return resp


# ---------------------------------------------------------------------------
# TTL cache (in-memory, per process)
# ---------------------------------------------------------------------------

class _TTLCache:
    """Tiny TTL cache. Stores (timestamp, value); evicts oldest when full.

    `ttl` is supplied at lookup time so the same payload can be reused under
    different freshness windows. A per-key asyncio.Lock coalesces duplicate
    concurrent requests so identical parallel callers share one HTTP roundtrip
    (the second caller acquires the lock after the first populated the cache,
    then hits on re-check).
    """

    def __init__(self, maxsize: int = CACHE_MAX_SIZE) -> None:
        self._data: dict[str, tuple[float, Any]] = {}
        self._maxsize = maxsize
        self._locks: dict[str, asyncio.Lock] = {}

    def get(self, key: str, ttl: float) -> Any | None:
        item = self._data.get(key)
        if item is None:
            return None
        ts, val = item
        if time.time() - ts > ttl:
            self._data.pop(key, None)
            return None
        return val

    def set(self, key: str, value: Any) -> None:
        if len(self._data) >= self._maxsize and key not in self._data:
            oldest = min(self._data, key=lambda k: self._data[k][0])
            self._data.pop(oldest, None)
        self._data[key] = (time.time(), value)

    def lock_for(self, key: str) -> asyncio.Lock:
        # Lock objects are tiny; per-key Lock retention is bounded by request
        # diversity in practice. Pruning would require tracking refcounts.
        lock = self._locks.get(key)
        if lock is None:
            lock = asyncio.Lock()
            self._locks[key] = lock
        return lock


_CACHE = _TTLCache()


def _cache_key(*parts: Any) -> str:
    blob = json.dumps(parts, sort_keys=True, default=str)
    return hashlib.md5(blob.encode("utf-8")).hexdigest()


async def _cached(key: str, ttl: float, fetch: Callable[[], Any]) -> Any:
    """Return cached value if fresh; otherwise await `fetch()` and cache it.

    Concurrent callers for the same key serialize on a per-key Lock; whichever
    one wins runs `fetch`, the rest fall through to a re-check that hits the
    fresh entry. On `fetch` exception, nothing is cached and all waiters retry
    independently next time.
    """
    hit = _CACHE.get(key, ttl)
    if hit is not None:
        return hit
    async with _CACHE.lock_for(key):
        hit = _CACHE.get(key, ttl)
        if hit is not None:
            return hit
        value = await fetch()
        _CACHE.set(key, value)
        return value


async def _http_get_json(
    url: str,
    *,
    params: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
    ttl: float = TTL_DEFAULT,
) -> Any:
    key = _cache_key("json", url, params, headers)

    async def fetch() -> Any:
        r = await _http_get(url, params=params, headers=headers)
        return r.json()

    return await _cached(key, ttl, fetch)


async def _http_get_text(
    url: str,
    *,
    params: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
    ttl: float = TTL_DEFAULT,
    timeout: float | None = None,
) -> str:
    key = _cache_key("text", url, params, headers)

    async def fetch() -> str:
        r = await _http_get(url, params=params, headers=headers, timeout=timeout)
        return r.text

    return await _cached(key, ttl, fetch)


def _handle_error(e: Exception, context: str) -> str:
    if isinstance(e, httpx.HTTPStatusError):
        code = e.response.status_code
        if code == 403:
            extra = ""
            if "github.com" in str(e.request.url):
                extra = " — set GITHUB_TOKEN env var to lift rate limit (60→5000/h)."
            return f"Error ({context}): HTTP 403 Forbidden — likely rate-limited.{extra}"
        if code == 404:
            return f"Error ({context}): HTTP 404 — resource not found."
        if code == 422:
            return f"Error ({context}): HTTP 422 — invalid query syntax. Detail: {e.response.text[:300]}"
        if code == 429:
            return f"Error ({context}): HTTP 429 — rate limited. Try again later."
        return f"Error ({context}): HTTP {code} — {e.response.text[:300]}"
    if isinstance(e, httpx.TimeoutException):
        return f"Error ({context}): request timed out after {HTTP_TIMEOUT}s."
    return f"Error ({context}): {type(e).__name__}: {e}"


def _format(payload: Any, fmt: ResponseFormat, *, render_md: Callable[[Any], str]) -> str:
    if fmt == ResponseFormat.JSON:
        return json.dumps(payload, ensure_ascii=False, indent=2, default=str)
    return render_md(payload)


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _trim(text: str | None, n: int = 240) -> str:
    if not text:
        return ""
    text = re.sub(r"\s+", " ", text).strip()
    return text if len(text) <= n else text[: n - 1] + "…"


def _fmt_date(dt: datetime | str | None) -> str:
    if not dt:
        return "?"
    if isinstance(dt, str):
        return dt[:10]
    return dt.strftime("%Y-%m-%d")


# ---------------------------------------------------------------------------
# 1. arXiv — recent and search
# ---------------------------------------------------------------------------

class ArxivRecentInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    category: str = Field(..., min_length=2, max_length=40, description="arXiv category, e.g. cs.AI, cs.HC, eess.IV")
    days: int = Field(7, ge=1, le=30)
    max_results: int = Field(20, ge=1, le=50)
    response_format: ResponseFormat = ResponseFormat.MARKDOWN


class ArxivSearchInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    query: str = Field(..., min_length=1, max_length=500)
    days: int | None = Field(None, ge=1, le=3650, description="If set, drop results older than N days (client-side filter).")
    max_results: int = Field(20, ge=1, le=50)
    sort_by: str = Field("relevance", pattern=r"^(relevance|submittedDate|lastUpdatedDate)$")
    response_format: ResponseFormat = ResponseFormat.MARKDOWN


def _parse_arxiv_atom(xml_text: str) -> list[dict[str, Any]]:
    root = ET.fromstring(xml_text)
    out: list[dict[str, Any]] = []
    for entry in root.findall("atom:entry", ATOM_NS):
        eid = (entry.findtext("atom:id", default="", namespaces=ATOM_NS) or "").strip()
        title = (entry.findtext("atom:title", default="", namespaces=ATOM_NS) or "").strip()
        summary = (entry.findtext("atom:summary", default="", namespaces=ATOM_NS) or "").strip()
        published = (entry.findtext("atom:published", default="", namespaces=ATOM_NS) or "").strip()
        updated = (entry.findtext("atom:updated", default="", namespaces=ATOM_NS) or "").strip()
        authors = [
            (a.findtext("atom:name", default="", namespaces=ATOM_NS) or "").strip()
            for a in entry.findall("atom:author", ATOM_NS)
        ]
        cats = [
            c.attrib.get("term", "")
            for c in entry.findall("{http://arxiv.org/schemas/atom}primary_category")
        ]
        # Extract arXiv id from URL like http://arxiv.org/abs/2604.12345v1
        arxiv_id = eid.rsplit("/", 1)[-1] if eid else ""
        out.append(
            {
                "id": arxiv_id,
                "url": eid,
                "title": title,
                "summary": summary,
                "published": published,
                "updated": updated,
                "authors": authors,
                "primary_category": cats[0] if cats else "",
            }
        )
    return out


def _render_arxiv_md(papers: list[dict[str, Any]], header: str) -> str:
    if not papers:
        return f"# {header}\n\n_결과 없음_"
    lines = [f"# {header}", f"_총 {len(papers)}건_", ""]
    for i, p in enumerate(papers, 1):
        authors = ", ".join(p["authors"][:4])
        if len(p["authors"]) > 4:
            authors += f" 외 {len(p['authors']) - 4}명"
        lines.append(
            f"## {i}. [{p['title']}]({p['url']})\n"
            f"- `{p['id']}` · {p['primary_category']} · {_fmt_date(p['published'])}\n"
            f"- 저자: {authors}\n"
            f"- {_trim(p['summary'], 500)}\n"
        )
    return "\n".join(lines)


@_maybe_tool(
    source="arxiv",
    name="arxiv_recent",
    description=(
        "Fetch recent arXiv papers in a category, sorted by submission date "
        "(newest first). `days` filters by `published` date.\n\n"
        "Common categories: cs.AI (general AI), cs.LG (machine learning), "
        "cs.CV (computer vision), cs.CL (NLP), cs.HC (HCI / UX), "
        "cs.RO (robotics), cs.NE (neural networks), stat.ML (statistical ML), "
        "eess.IV (image/video processing — medical imaging lives here), "
        "eess.SP (signal processing), q-bio.QM (quantitative biology)."
    ),
    annotations={
        "readOnlyHint": True,
        "destructiveHint": False,
        "openWorldHint": True,
        "idempotentHint": False,
    },
)
async def arxiv_recent(
    category: str,
    days: int = 7,
    max_results: int = 20,
    response_format: ResponseFormat = ResponseFormat.MARKDOWN,
) -> str:
    try:
        args = ArxivRecentInput(
            category=category,
            days=days,
            max_results=max_results,
            response_format=response_format,
        )
        # Over-fetch because arXiv has no native date filter.
        fetch_n = min(args.max_results * 3, 100)
        params = {
            "search_query": f"cat:{args.category}",
            "sortBy": "submittedDate",
            "sortOrder": "descending",
            "start": 0,
            "max_results": fetch_n,
        }
        text = await _http_get_text(ARXIV_API, params=params, ttl=TTL_DEFAULT)
        papers = _parse_arxiv_atom(text)
        cutoff = _utc_now() - timedelta(days=args.days)
        filtered: list[dict[str, Any]] = []
        for p in papers:
            try:
                pub_dt = datetime.fromisoformat(p["published"].replace("Z", "+00:00"))
            except ValueError:
                continue
            if pub_dt >= cutoff:
                filtered.append(p)
            if len(filtered) >= args.max_results:
                break
        header = f"arXiv `{args.category}` — 최근 {args.days}일 ({len(filtered)}건)"
        return _format(filtered, args.response_format, render_md=lambda x: _render_arxiv_md(x, header))
    except Exception as e:
        return _handle_error(e, "arxiv_recent")


@_maybe_tool(
    source="arxiv",
    name="arxiv_search",
    description=(
        "Search arXiv. Plain keywords work (auto-prefixed `all:`); for advanced "
        "queries use arXiv field syntax: `ti:` (title), `au:` (author), "
        "`abs:` (abstract), `cat:` (category, e.g. `cat:eess.IV`). "
        "`days` cuts off results older than N days (`published` field). "
        "When `days` is set, results are sorted by submission date instead of relevance."
    ),
    annotations={
        "readOnlyHint": True,
        "destructiveHint": False,
        "openWorldHint": True,
        "idempotentHint": True,
    },
)
async def arxiv_search(
    query: str,
    days: int | None = None,
    max_results: int = 20,
    sort_by: str = "relevance",
    response_format: ResponseFormat = ResponseFormat.MARKDOWN,
) -> str:
    try:
        args = ArxivSearchInput(
            query=query,
            days=days,
            max_results=max_results,
            sort_by=sort_by,
            response_format=response_format,
        )
        q = args.query if ":" in args.query else f"all:{args.query}"
        # When `days` is set, force submittedDate sort and over-fetch so the
        # client-side cutoff can still return up to max_results.
        effective_sort = "submittedDate" if args.days else args.sort_by
        fetch_n = min(args.max_results * (5 if args.days else 1), 200)
        params: dict[str, Any] = {
            "search_query": q,
            "start": 0,
            "max_results": fetch_n,
        }
        if effective_sort != "relevance":
            params["sortBy"] = effective_sort
            params["sortOrder"] = "descending"
        ttl = TTL_STATIC if args.sort_by == "relevance" and not args.days else TTL_DEFAULT
        text = await _http_get_text(ARXIV_API, params=params, ttl=ttl)
        papers = _parse_arxiv_atom(text)
        if args.days:
            cutoff = _utc_now() - timedelta(days=args.days)
            kept: list[dict[str, Any]] = []
            for p in papers:
                try:
                    pub_dt = datetime.fromisoformat(p["published"].replace("Z", "+00:00"))
                except ValueError:
                    continue
                if pub_dt >= cutoff:
                    kept.append(p)
                if len(kept) >= args.max_results:
                    break
            papers = kept
        else:
            papers = papers[: args.max_results]
        suffix = f" · 최근 {args.days}일" if args.days else ""
        header = f"arXiv 검색 `{args.query}`{suffix} ({len(papers)}건)"
        return _format(papers, args.response_format, render_md=lambda x: _render_arxiv_md(x, header))
    except Exception as e:
        return _handle_error(e, "arxiv_search")


# ---------------------------------------------------------------------------
# 2. PubMed
# ---------------------------------------------------------------------------

class PubMedSearchInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    query: str = Field(..., min_length=1, max_length=500)
    days: int | None = Field(None, ge=1, le=3650)
    max_results: int = Field(20, ge=1, le=50)
    response_format: ResponseFormat = ResponseFormat.MARKDOWN


async def _pubmed_fetch_abstracts(pmids: list[str]) -> dict[str, str]:
    """Fetch abstract text for each PMID via efetch.fcgi (XML).

    Returns {pmid: abstract_text}. Empty values for PMIDs without abstracts
    (e.g. editorials, letters). Failures are swallowed — caller falls back
    to no-abstract rendering.
    """
    if not pmids:
        return {}
    params: dict[str, Any] = {
        "db": "pubmed",
        "id": ",".join(pmids),
        "retmode": "xml",
    }
    api_key = os.environ.get("NCBI_API_KEY")
    if api_key:
        params["api_key"] = api_key
    try:
        text = await _http_get_text(
            f"{PUBMED_BASE}/efetch.fcgi", params=params, ttl=TTL_STATIC
        )
    except Exception:
        return {}
    out: dict[str, str] = {}
    try:
        root = ET.fromstring(text)
    except ET.ParseError:
        return {}
    for article in root.findall(".//PubmedArticle"):
        pmid_el = article.find(".//MedlineCitation/PMID")
        if pmid_el is None or not pmid_el.text:
            continue
        pmid = pmid_el.text.strip()
        # AbstractText can be split into Background/Methods/Results/Conclusions
        # via the `Label` attribute; concatenate with labels for readability.
        parts: list[str] = []
        for ab in article.findall(".//Abstract/AbstractText"):
            label = ab.attrib.get("Label", "").strip()
            content = "".join(ab.itertext()).strip()
            if not content:
                continue
            parts.append(f"{label}: {content}" if label else content)
        if parts:
            out[pmid] = " ".join(parts)
    return out


def _render_pubmed_md(items: list[dict[str, Any]], header: str) -> str:
    if not items:
        return f"# {header}\n\n_결과 없음_"
    lines = [f"# {header}", f"_총 {len(items)}건_", ""]
    for i, it in enumerate(items, 1):
        authors = ", ".join(it["authors"][:4])
        if len(it["authors"]) > 4:
            authors += f" 외 {len(it['authors']) - 4}명"
        block = (
            f"## {i}. [{it['title']}]({it['url']})\n"
            f"- PMID `{it['pmid']}` · {it['journal']} · {it['pubdate']}\n"
            f"- 저자: {authors}\n"
        )
        if it.get("abstract"):
            block += f"- {_trim(it['abstract'], 500)}\n"
        lines.append(block)
    return "\n".join(lines)


@_maybe_tool(
    source="pubmed",
    name="pubmed_search",
    description=(
        "Search PubMed for biomedical publications. Plain keywords work; for "
        "advanced queries use MeSH and field tags: `mammography[MeSH]`, "
        "`smith[Author]`, `2025[PDat]`. Combine with `AND`/`OR`. "
        "`days` filters by publication date (`PDat` field)."
    ),
    annotations={
        "readOnlyHint": True,
        "destructiveHint": False,
        "openWorldHint": True,
        "idempotentHint": True,
    },
)
async def pubmed_search(
    query: str,
    days: int | None = None,
    max_results: int = 20,
    response_format: ResponseFormat = ResponseFormat.MARKDOWN,
) -> str:
    try:
        args = PubMedSearchInput(
            query=query,
            days=days,
            max_results=max_results,
            response_format=response_format,
        )
        api_key = os.environ.get("NCBI_API_KEY")
        term = args.query
        if args.days:
            term = f"({term}) AND (\"last {args.days} days\"[PDat])"

        common: dict[str, Any] = {"db": "pubmed", "retmode": "json"}
        if api_key:
            common["api_key"] = api_key

        # Step 1: esearch -> PMID list
        esearch_params = {**common, "term": term, "retmax": args.max_results, "sort": "pub_date"}
        es_data = await _http_get_json(
            f"{PUBMED_BASE}/esearch.fcgi", params=esearch_params, ttl=TTL_STATIC
        )
        pmids: list[str] = es_data.get("esearchresult", {}).get("idlist", [])
        if not pmids:
            header = f"PubMed `{args.query}` (0건)"
            return _format([], args.response_format, render_md=lambda x: _render_pubmed_md(x, header))

        # Step 2: esummary -> metadata
        esum_params = {**common, "id": ",".join(pmids)}
        es2_data = await _http_get_json(
            f"{PUBMED_BASE}/esummary.fcgi", params=esum_params, ttl=TTL_STATIC
        )
        result = es2_data.get("result", {})
        uids = result.get("uids", pmids)

        items: list[dict[str, Any]] = []
        for uid in uids:
            r = result.get(uid)
            if not r:
                continue
            authors = [a.get("name", "") for a in r.get("authors", []) if a.get("name")]
            items.append(
                {
                    "pmid": uid,
                    "url": f"https://pubmed.ncbi.nlm.nih.gov/{uid}/",
                    "title": r.get("title", "").rstrip("."),
                    "journal": r.get("fulljournalname") or r.get("source") or "",
                    "pubdate": r.get("pubdate") or r.get("epubdate") or "",
                    "authors": authors,
                }
            )

        # Step 3: efetch -> abstracts (one batched call). Best-effort: if it
        # fails or an article has no abstract, we just skip the field.
        abstracts = await _pubmed_fetch_abstracts([it["pmid"] for it in items])
        for it in items:
            it["abstract"] = abstracts.get(it["pmid"], "")

        header = f"PubMed `{args.query}` ({len(items)}건)"
        return _format(items, args.response_format, render_md=lambda x: _render_pubmed_md(x, header))
    except Exception as e:
        return _handle_error(e, "pubmed_search")


# ---------------------------------------------------------------------------
# 3. Papers with Code
# ---------------------------------------------------------------------------

class PwCInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    query: str | None = Field(None, max_length=300)
    days: int | None = Field(None, ge=1, le=3650, description="If set, drop results published more than N days ago.")
    sort_by: str = Field(
        "upvotes",
        pattern=r"^(upvotes|comments|recent)$",
        description="upvotes (community votes), comments (discussion volume), recent (publish time)",
    )
    max_results: int = Field(20, ge=1, le=50)
    response_format: ResponseFormat = ResponseFormat.MARKDOWN


def _render_pwc_md(items: list[dict[str, Any]], header: str) -> str:
    if not items:
        return f"# {header}\n\n_결과 없음_"
    lines = [f"# {header}", f"_총 {len(items)}건_", ""]
    for i, p in enumerate(items, 1):
        authors = ", ".join(p["authors"][:4])
        if len(p["authors"]) > 4:
            authors += f" 외 {len(p['authors']) - 4}명"
        lines.append(
            f"## {i}. [{p['title']}]({p['url_abs']})\n"
            f"- {_fmt_date(p['published'])} · 저자: {authors}\n"
            f"- {_trim(p['abstract'], 500)}\n"
            + (f"- [PDF]({p['url_pdf']})\n" if p.get("url_pdf") else "")
        )
    return "\n".join(lines)


def _hf_paper_to_item(entry: dict[str, Any]) -> dict[str, Any]:
    """Map a HF daily_papers entry to our common paper dict shape.

    HF returns nested {paper: {id, authors, summary, upvotes, ai_summary, ...},
    title, publishedAt, numComments, ...} where `paper.id` is the arXiv ID. We
    surface a HF papers URL for the abstract page and the canonical arXiv PDF.
    """
    paper = entry.get("paper") or {}
    arxiv_id = paper.get("id") or ""
    authors = [a.get("name", "") for a in (paper.get("authors") or []) if a.get("name")]
    return {
        "title": (entry.get("title") or paper.get("title") or "").strip(),
        "abstract": (entry.get("summary") or paper.get("summary") or "").strip(),
        # HF's auto-generated one-line lede — perfect for newspaper headlines.
        "ai_summary": (paper.get("ai_summary") or "").strip(),
        "published": entry.get("publishedAt") or paper.get("publishedAt") or "",
        "authors": authors,
        "upvotes": int(paper.get("upvotes") or 0),
        "num_comments": int(entry.get("numComments") or 0),
        "url_abs": f"https://huggingface.co/papers/{arxiv_id}" if arxiv_id else "",
        "url_pdf": f"https://arxiv.org/pdf/{arxiv_id}" if arxiv_id else "",
    }


@_maybe_tool(
    source="paperswithcode",
    name="paperswithcode_trending",
    description=(
        "Daily curated AI papers feed (now backed by Hugging Face's daily_papers — "
        "Papers with Code API was sunset after the 2024 HF acquisition). "
        "Empty query returns the newest curated papers. "
        "Search is client-side filtering over the daily-papers stream."
    ),
    annotations={
        "readOnlyHint": True,
        "destructiveHint": False,
        "openWorldHint": True,
        "idempotentHint": False,
    },
)
async def paperswithcode_trending(
    query: str | None = None,
    days: int | None = None,
    sort_by: str = "upvotes",
    max_results: int = 20,
    response_format: ResponseFormat = ResponseFormat.MARKDOWN,
) -> str:
    try:
        args = PwCInput(
            query=query, days=days, sort_by=sort_by,
            max_results=max_results, response_format=response_format,
        )
        # daily_papers ignores q/search params; fetch the latest stream and
        # filter client-side. The endpoint returns up to 50 entries by default.
        raw = await _http_get_json(HF_DAILY_PAPERS_API, ttl=TTL_TRENDING)
        if not isinstance(raw, list):
            raw = []
        cutoff = _utc_now() - timedelta(days=args.days) if args.days else None
        q_lower = args.query.lower() if args.query else None
        # First pass: filter by topic + date window (don't truncate yet — sort below).
        candidates: list[dict[str, Any]] = []
        for entry in raw:
            paper = entry.get("paper") or {}
            title = entry.get("title") or paper.get("title") or ""
            summary = entry.get("summary") or paper.get("summary") or ""
            if q_lower and q_lower not in title.lower() and q_lower not in summary.lower():
                continue
            pub = entry.get("publishedAt") or paper.get("publishedAt") or ""
            if cutoff and pub:
                try:
                    pub_dt = datetime.fromisoformat(pub.replace("Z", "+00:00"))
                    if pub_dt.tzinfo is None:
                        pub_dt = pub_dt.replace(tzinfo=timezone.utc)
                except ValueError:
                    continue
                if pub_dt < cutoff:
                    continue
            candidates.append(_hf_paper_to_item(entry))
        # Sort by chosen popularity signal.
        if args.sort_by == "upvotes":
            candidates.sort(key=lambda x: (x.get("upvotes") or 0, x.get("num_comments") or 0), reverse=True)
        elif args.sort_by == "comments":
            candidates.sort(key=lambda x: (x.get("num_comments") or 0, x.get("upvotes") or 0), reverse=True)
        # `recent` keeps the API's natural order (newest first).
        items = candidates[: args.max_results]
        suffix_bits: list[str] = []
        if args.days:
            suffix_bits.append(f"최근 {args.days}일")
        suffix_bits.append(f"sort={args.sort_by}")
        suffix = " · " + " · ".join(suffix_bits)
        header = f"Daily AI Papers (HF) `{args.query or '최신'}`{suffix} ({len(items)}건)"
        return _format(items, args.response_format, render_md=lambda x: _render_pwc_md(x, header))
    except Exception as e:
        return _handle_error(e, "paperswithcode_trending")


# ---------------------------------------------------------------------------
# 4. GitHub — trending (scrape) and search (API)
# ---------------------------------------------------------------------------

class GitHubTrendingInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    language: str | None = Field(None, max_length=40)
    since: str = Field("daily", pattern=r"^(daily|weekly|monthly)$")
    max_results: int = Field(25, ge=1, le=25)
    response_format: ResponseFormat = ResponseFormat.MARKDOWN


class GitHubSearchInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    query: str = Field(..., min_length=1, max_length=300)
    language: str | None = Field(None, max_length=40)
    days: int | None = Field(None, ge=1, le=3650)
    sort: str = Field("stars", pattern=r"^(stars|forks|updated|best-match)$")
    max_results: int = Field(20, ge=1, le=100)
    response_format: ResponseFormat = ResponseFormat.MARKDOWN


def _render_github_md(items: list[dict[str, Any]], header: str) -> str:
    if not items:
        return f"# {header}\n\n_결과 없음_"
    lines = [f"# {header}", f"_총 {len(items)}건_", ""]
    for i, r in enumerate(items, 1):
        bits: list[str] = []
        if r.get("language"):
            bits.append(str(r["language"]))
        bits.append(f"⭐{r.get('stars', 0):,}")
        if "forks" in r and r["forks"] is not None:
            bits.append(f"🍴{r['forks']:,}")
        if r.get("stars_period"):
            bits.append(f"📈+{r['stars_period']:,}")
        meta = " · ".join(bits)
        desc = _trim(r.get("description"), 200)
        lines.append(
            f"## {i}. [{r['full_name']}]({r['url']})\n"
            f"- {meta}\n"
            + (f"- {desc}\n" if desc else "")
        )
    return "\n".join(lines)


@_maybe_tool(
    source="github",
    name="github_trending",
    description=(
        "Browse github.com/trending — the public 'what's hot now' feed. "
        "USE THIS WHEN: user wants to browse trending repos with no specific "
        "topic in mind ('파이썬 트렌딩 보여줘', 'GitHub 핫한 거'). "
        "USE github_search INSTEAD WHEN: user has a specific topic/keyword. "
        "Note: this is HTML scraping (no official API), so layout changes can break it."
    ),
    annotations={
        "readOnlyHint": True,
        "destructiveHint": False,
        "openWorldHint": True,
        "idempotentHint": False,
    },
)
async def github_trending(
    language: str | None = None,
    since: str = "daily",
    max_results: int = 25,
    response_format: ResponseFormat = ResponseFormat.MARKDOWN,
) -> str:
    try:
        args = GitHubTrendingInput(
            language=language, since=since, max_results=max_results, response_format=response_format
        )
        url = GITHUB_TRENDING + (f"/{args.language}" if args.language else "")
        # Trending UI pulses fast — keep TTL short.
        text = await _http_get_text(url, params={"since": args.since}, ttl=TTL_TRENDING)
        soup = BeautifulSoup(text, "html.parser")
        articles = soup.select("article.Box-row")
        repos: list[dict[str, Any]] = []
        for art in articles[: args.max_results]:
            h2 = art.select_one("h2 a")
            if not h2:
                continue
            href = h2.get("href", "").strip()
            full_name = re.sub(r"\s+", "", h2.get_text()).strip("/")
            desc_el = art.select_one("p")
            desc = desc_el.get_text(strip=True) if desc_el else ""
            lang_el = art.select_one('[itemprop="programmingLanguage"]')
            language_v = lang_el.get_text(strip=True) if lang_el else None
            stars = 0
            forks = 0
            for a in art.select("a.Link--muted"):
                ah = a.get("href", "")
                num_text = a.get_text(strip=True).replace(",", "")
                m = re.search(r"\d+", num_text)
                if not m:
                    continue
                n = int(m.group())
                if ah.endswith("/stargazers"):
                    stars = n
                elif ah.endswith("/forks") or ah.endswith("/network/members"):
                    forks = n
            period_el = art.select_one("span.d-inline-block.float-sm-right")
            stars_period = None
            if period_el:
                pm = re.search(r"[\d,]+", period_el.get_text())
                if pm:
                    stars_period = int(pm.group().replace(",", ""))
            repos.append(
                {
                    "full_name": full_name,
                    "url": "https://github.com" + href if href.startswith("/") else href,
                    "description": desc,
                    "language": language_v,
                    "stars": stars,
                    "forks": forks,
                    "stars_period": stars_period,
                }
            )
        header = f"GitHub Trending — {args.since}" + (f" · {args.language}" if args.language else "")
        return _format(repos, args.response_format, render_md=lambda x: _render_github_md(x, header))
    except Exception as e:
        return _handle_error(e, "github_trending")


@_maybe_tool(
    source="github",
    name="github_search",
    description=(
        "Search GitHub repositories by keyword via the official Search API. "
        "USE THIS WHEN: user has a specific topic ('medical imaging 리포', "
        "'mammography GitHub'). `days` filters by repository `created_at` "
        "(treats it as 'repos created in the last N days') — pair with "
        "`sort=stars` for a stable trending-substitute. "
        "USE github_trending INSTEAD WHEN: no specific topic, just browsing."
    ),
    annotations={
        "readOnlyHint": True,
        "destructiveHint": False,
        "openWorldHint": True,
        "idempotentHint": True,
    },
)
async def github_search(
    query: str,
    language: str | None = None,
    days: int | None = None,
    sort: str = "stars",
    max_results: int = 20,
    response_format: ResponseFormat = ResponseFormat.MARKDOWN,
) -> str:
    try:
        args = GitHubSearchInput(
            query=query,
            language=language,
            days=days,
            sort=sort,
            max_results=max_results,
            response_format=response_format,
        )
        q_parts = [args.query]
        if args.language:
            q_parts.append(f"language:{args.language}")
        if args.days:
            since_date = (_utc_now() - timedelta(days=args.days)).strftime("%Y-%m-%d")
            q_parts.append(f"created:>{since_date}")
        params: dict[str, Any] = {
            "q": " ".join(q_parts),
            "per_page": args.max_results,
        }
        if args.sort != "best-match":
            params["sort"] = args.sort
            params["order"] = "desc"
        headers = {
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        token = os.environ.get("GITHUB_TOKEN")
        if token:
            headers["Authorization"] = f"Bearer {token}"
        ttl = TTL_TRENDING if args.days else TTL_DEFAULT
        data = await _http_get_json(GITHUB_API, params=params, headers=headers, ttl=ttl)
        items = data.get("items", []) if isinstance(data, dict) else []
        repos = [
            {
                "full_name": r.get("full_name", ""),
                "url": r.get("html_url", ""),
                "description": r.get("description") or "",
                "language": r.get("language"),
                "stars": r.get("stargazers_count", 0),
                "forks": r.get("forks_count", 0),
                "created_at": r.get("created_at"),
                "updated_at": r.get("updated_at"),
            }
            for r in items[: args.max_results]
        ]
        header = f"GitHub 검색 `{args.query}` ({len(repos)}건)"
        return _format(repos, args.response_format, render_md=lambda x: _render_github_md(x, header))
    except Exception as e:
        return _handle_error(e, "github_search")


# ---------------------------------------------------------------------------
# 5. Hugging Face — models / datasets / spaces
# ---------------------------------------------------------------------------

class HFTrendingInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    kind: str = Field("models", pattern=r"^(models|datasets|spaces)$")
    sort: str = Field("trending", pattern=r"^(trending|downloads|likes|recent)$")
    query: str | None = Field(None, max_length=200)
    tag: str | None = Field(None, max_length=80)
    days: int | None = Field(None, ge=1, le=3650, description="If set, drop entries whose lastModified is older than N days.")
    max_results: int = Field(20, ge=1, le=50)
    response_format: ResponseFormat = ResponseFormat.MARKDOWN


_HF_SORT_MAP = {
    "trending": "trendingScore",
    "downloads": "downloads",
    "likes": "likes",
    "recent": "lastModified",
}


def _render_hf_md(items: list[dict[str, Any]], header: str, kind: str) -> str:
    if not items:
        return f"# {header}\n\n_결과 없음_"
    lines = [f"# {header}", f"_총 {len(items)}건_", ""]
    for i, it in enumerate(items, 1):
        bits: list[str] = []
        if it.get("downloads") is not None:
            bits.append(f"📥 {it['downloads']:,}")
        bits.append(f"❤️ {it.get('likes', 0):,}")
        if it.get("lastModified"):
            bits.append(f"업데이트 {_fmt_date(it['lastModified'])}")
        meta = " · ".join(bits)
        sub = ""
        if kind == "models" and it.get("pipeline_tag"):
            sub = f" · `{it['pipeline_tag']}`"
        if kind == "spaces" and it.get("sdk"):
            sub = f" · `{it['sdk']}`"
        tags = it.get("tags") or []
        tag_line = ", ".join(tags[:6])
        lines.append(
            f"## {i}. [{it['id']}]({it['url']}){sub}\n"
            f"- {meta}\n"
            + (f"- 태그: {tag_line}\n" if tag_line else "")
        )
    return "\n".join(lines)


@_maybe_tool(
    source="huggingface",
    name="huggingface_trending",
    description=(
        "Browse Hugging Face Hub. `kind` selects models / datasets / spaces "
        "(default models). `sort`: trending / downloads / likes / recent. "
        "`days` filters by `lastModified` — CAUTION: this catches old entries "
        "with recent edits, not just newly published ones. For 'truly new' "
        "discovery prefer sort='recent' + days=N."
    ),
    annotations={
        "readOnlyHint": True,
        "destructiveHint": False,
        "openWorldHint": True,
        "idempotentHint": False,
    },
)
async def huggingface_trending(
    kind: str = "models",
    sort: str = "trending",
    query: str | None = None,
    tag: str | None = None,
    days: int | None = None,
    max_results: int = 20,
    response_format: ResponseFormat = ResponseFormat.MARKDOWN,
) -> str:
    try:
        args = HFTrendingInput(
            kind=kind,
            sort=sort,
            query=query,
            tag=tag,
            days=days,
            max_results=max_results,
            response_format=response_format,
        )
        url = f"{HF_API}/{args.kind}"
        # Over-fetch when filtering by days, since HF API has no date filter.
        fetch_n = min(args.max_results * (5 if args.days else 1), 200)
        params: dict[str, Any] = {
            "sort": _HF_SORT_MAP[args.sort],
            "direction": -1,
            "limit": fetch_n,
        }
        if args.query:
            params["search"] = args.query
        if args.tag:
            params["filter"] = args.tag
        headers: dict[str, str] = {}
        token = os.environ.get("HF_TOKEN")
        if token:
            headers["Authorization"] = f"Bearer {token}"
        ttl = TTL_TRENDING if args.sort == "trending" else TTL_DEFAULT
        raw = await _http_get_json(url, params=params, headers=headers or None, ttl=ttl)
        if not isinstance(raw, list):
            raw = []
        cutoff = _utc_now() - timedelta(days=args.days) if args.days else None
        items: list[dict[str, Any]] = []
        for r in raw:
            last_mod = r.get("lastModified") or r.get("last_modified")
            if cutoff:
                if not last_mod:
                    continue
                try:
                    lm_dt = datetime.fromisoformat(str(last_mod).replace("Z", "+00:00"))
                    if lm_dt.tzinfo is None:
                        lm_dt = lm_dt.replace(tzinfo=timezone.utc)
                except ValueError:
                    continue
                if lm_dt < cutoff:
                    continue
            rid = r.get("id") or r.get("modelId") or ""
            if args.kind == "models":
                disp_url = f"https://huggingface.co/{rid}"
            elif args.kind == "datasets":
                disp_url = f"https://huggingface.co/datasets/{rid}"
            else:
                disp_url = f"https://huggingface.co/spaces/{rid}"
            items.append(
                {
                    "id": rid,
                    "url": disp_url,
                    "downloads": r.get("downloads"),
                    "likes": r.get("likes", 0),
                    "lastModified": last_mod,
                    "tags": r.get("tags") or [],
                    "pipeline_tag": r.get("pipeline_tag"),
                    "library_name": r.get("library_name"),
                    "sdk": r.get("sdk"),
                    "task_categories": r.get("task_categories") or [],
                }
            )
            if len(items) >= args.max_results:
                break
        header = f"Hugging Face {args.kind} — {args.sort}"
        if args.query:
            header += f" · `{args.query}`"
        if args.tag:
            header += f" · #{args.tag}"
        if args.days:
            header += f" · 최근 {args.days}일"
        return _format(items, args.response_format, render_md=lambda x: _render_hf_md(x, header, args.kind))
    except Exception as e:
        return _handle_error(e, "huggingface_trending")


# ---------------------------------------------------------------------------
# 6. openFDA — 510(k) clearances and recalls
# ---------------------------------------------------------------------------

class FDA510kInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    query: str | None = Field(None, max_length=300)
    days: int = Field(30, ge=1, le=365)
    max_results: int = Field(20, ge=1, le=100)
    response_format: ResponseFormat = ResponseFormat.MARKDOWN


class FDARecallInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    query: str | None = Field(None, max_length=300)
    days: int = Field(90, ge=1, le=365)
    # Accept Arabic ("1","2","3") or Roman ("I","II","III") — normalized internally.
    class_level: str | None = Field(None, pattern=r"^(?:[123]|I{1,3})$")
    max_results: int = Field(20, ge=1, le=100)
    response_format: ResponseFormat = ResponseFormat.MARKDOWN


def _render_510k_md(items: list[dict[str, Any]], header: str) -> str:
    if not items:
        return f"# {header}\n\n_결과 없음_"
    lines = [f"# {header}", f"_총 {len(items)}건_", ""]
    for i, r in enumerate(items, 1):
        knum = r.get("k_number", "")
        url = f"https://www.accessdata.fda.gov/scripts/cdrh/cfdocs/cfpmn/pmn.cfm?ID={knum}" if knum else ""
        link = f"[{knum}]({url})" if url else knum
        lines.append(
            f"## {i}. {r.get('device_name', '?')} — {link}\n"
            f"- 신청자: {r.get('applicant', '?')}\n"
            f"- 결정: {r.get('decision_description') or r.get('decision_code', '?')} · "
            f"{r.get('decision_date', '?')} · 제품코드 `{r.get('product_code', '?')}`\n"
        )
    return "\n".join(lines)


def _render_recall_md(items: list[dict[str, Any]], header: str) -> str:
    if not items:
        return f"# {header}\n\n_결과 없음_"
    lines = [f"# {header}", f"_총 {len(items)}건_", ""]
    for i, r in enumerate(items, 1):
        lines.append(
            f"## {i}. {_trim(r.get('product_description'), 120)}\n"
            f"- 회수번호 `{r.get('recall_number', '?')}` · {r.get('classification', '?')} · "
            f"{r.get('event_date_initiated', '?')}\n"
            f"- 회사: {r.get('recalling_firm', '?')} · 상태: {r.get('recall_status', '?')}\n"
            f"- 사유: {_trim(r.get('reason_for_recall'), 400)}\n"
        )
    return "\n".join(lines)


def _build_openfda_search(parts: list[str]) -> str:
    return "+AND+".join(parts) if parts else ""


@_maybe_tool(
    source="fda_510k",
    name="fda_510k_recent",
    description=(
        "Recent FDA 510(k) clearances via openFDA. Date filter is always applied. "
        "openFDA uses token-exact matching on string fields — for partial name "
        "matches use wildcards (e.g. `device_name:mammo*` not `device_name:mammography`)."
    ),
    annotations={
        "readOnlyHint": True,
        "destructiveHint": False,
        "openWorldHint": True,
        "idempotentHint": True,
    },
)
async def fda_510k_recent(
    query: str | None = None,
    days: int = 30,
    max_results: int = 20,
    response_format: ResponseFormat = ResponseFormat.MARKDOWN,
) -> str:
    try:
        args = FDA510kInput(
            query=query, days=days, max_results=max_results, response_format=response_format
        )
        end = _utc_now().strftime("%Y%m%d")
        start = (_utc_now() - timedelta(days=args.days)).strftime("%Y%m%d")
        date_clause = f"decision_date:[{start}+TO+{end}]"
        parts = [date_clause]
        if args.query:
            parts.append(args.query)
        search = _build_openfda_search(parts)
        params: dict[str, Any] = {
            "search": search,
            "limit": args.max_results,
            "sort": "decision_date:desc",
        }
        api_key = os.environ.get("OPENFDA_API_KEY")
        if api_key:
            params["api_key"] = api_key
        # openFDA's `+AND+` must NOT be percent-encoded; pass as a manually-built URL.
        url = f"{OPENFDA_510K}?search={search}&limit={params['limit']}&sort=decision_date:desc"
        if api_key:
            url += f"&api_key={api_key}"
        data = await _http_get_json(url, ttl=TTL_STATIC)
        items = data.get("results", []) if isinstance(data, dict) else []
        header = f"FDA 510(k) — 최근 {args.days}일 ({len(items)}건)"
        return _format(items, args.response_format, render_md=lambda x: _render_510k_md(x, header))
    except httpx.HTTPStatusError as e:
        # openFDA returns 404 when zero results — show empty list instead of error.
        if e.response.status_code == 404:
            header = f"FDA 510(k) — 최근 {args.days}일 (0건)"
            return _format([], args.response_format, render_md=lambda x: _render_510k_md(x, header))
        return _handle_error(e, "fda_510k_recent")
    except Exception as e:
        return _handle_error(e, "fda_510k_recent")


# openFDA stores recall classification as Roman numerals ("Class I/II/III").
# Accept both Arabic and Roman input from callers and normalize for the query.
_RECALL_CLASS_TO_ROMAN: dict[str, str] = {
    "1": "I", "2": "II", "3": "III",
    "I": "I", "II": "II", "III": "III",
}


@_maybe_tool(
    source="fda_recalls",
    name="fda_recalls_recent",
    description=(
        "Recent FDA medical device recalls via openFDA. Optionally filter by class "
        "(1=most serious, 3=least). Note: openFDA query syntax uses token-exact "
        "matching on string fields — for partial matches use wildcards "
        "(e.g. `product_description:mammog*`)."
    ),
    annotations={
        "readOnlyHint": True,
        "destructiveHint": False,
        "openWorldHint": True,
        "idempotentHint": True,
    },
)
async def fda_recalls_recent(
    query: str | None = None,
    days: int = 90,
    class_level: str | None = None,
    max_results: int = 20,
    response_format: ResponseFormat = ResponseFormat.MARKDOWN,
) -> str:
    try:
        args = FDARecallInput(
            query=query,
            days=days,
            class_level=class_level,
            max_results=max_results,
            response_format=response_format,
        )
        end = _utc_now().strftime("%Y%m%d")
        start = (_utc_now() - timedelta(days=args.days)).strftime("%Y%m%d")
        parts = [f"event_date_initiated:[{start}+TO+{end}]"]
        if args.query:
            parts.append(args.query)
        if args.class_level:
            roman = _RECALL_CLASS_TO_ROMAN.get(args.class_level, args.class_level)
            parts.append(f"classification:Class+{roman}")
        search = _build_openfda_search(parts)
        api_key = os.environ.get("OPENFDA_API_KEY")
        url = f"{OPENFDA_RECALL}?search={search}&limit={args.max_results}&sort=event_date_initiated:desc"
        if api_key:
            url += f"&api_key={api_key}"
        data = await _http_get_json(url, ttl=TTL_STATIC)
        items = data.get("results", []) if isinstance(data, dict) else []
        cls_tag = f" · Class {args.class_level}" if args.class_level else ""
        header = f"FDA Recalls — 최근 {args.days}일{cls_tag} ({len(items)}건)"
        return _format(items, args.response_format, render_md=lambda x: _render_recall_md(x, header))
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            cls_tag = f" · Class {args.class_level}" if args.class_level else ""
            header = f"FDA Recalls — 최근 {args.days}일{cls_tag} (0건)"
            return _format([], args.response_format, render_md=lambda x: _render_recall_md(x, header))
        return _handle_error(e, "fda_recalls_recent")
    except Exception as e:
        return _handle_error(e, "fda_recalls_recent")


# ---------------------------------------------------------------------------
# 7. trends_digest — parallel multi-source aggregator
# ---------------------------------------------------------------------------

class DigestSource(str, Enum):
    ARXIV = "arxiv"
    GITHUB = "github"
    HUGGINGFACE = "huggingface"
    PAPERSWITHCODE = "paperswithcode"
    PUBMED = "pubmed"
    FDA_510K = "fda_510k"
    FDA_RECALLS = "fda_recalls"


_DEFAULT_SOURCES: list[str] = [
    s for s in (
        DigestSource.ARXIV.value,
        DigestSource.GITHUB.value,
        DigestSource.HUGGINGFACE.value,
        DigestSource.PAPERSWITHCODE.value,
    ) if s in ENABLED_SOURCES
]


def _digest_arxiv_md(items: list[dict[str, Any]]) -> list[str]:
    out = []
    for it in items:
        out.append(
            f"- [{it['title']}]({it['url']}) — `{it['id']}` · "
            f"{it.get('primary_category', '')} · {_fmt_date(it.get('published'))}"
        )
    return out


def _digest_github_md(items: list[dict[str, Any]]) -> list[str]:
    out = []
    for r in items:
        bits = [f"⭐{r.get('stars', 0):,}"]
        if r.get("language"):
            bits.append(str(r["language"]))
        desc = _trim(r.get("description"), 120)
        out.append(f"- [{r['full_name']}]({r['url']}) — " + " · ".join(bits) + (f" — {desc}" if desc else ""))
    return out


def _digest_hf_md(items: list[dict[str, Any]]) -> list[str]:
    out = []
    for it in items:
        bits: list[str] = []
        if it.get("downloads") is not None:
            bits.append(f"📥{it['downloads']:,}")
        bits.append(f"❤️{it.get('likes', 0):,}")
        out.append(f"- [{it['id']}]({it['url']}) — " + " · ".join(bits))
    return out


def _digest_pwc_md(items: list[dict[str, Any]]) -> list[str]:
    return [
        f"- [{it['title']}]({it['url_abs']}) — {_fmt_date(it.get('published'))}"
        for it in items
    ]


def _digest_pubmed_md(items: list[dict[str, Any]]) -> list[str]:
    out: list[str] = []
    for it in items:
        line = (
            f"- [{it['title']}]({it['url']}) — PMID `{it['pmid']}` · "
            f"{it.get('journal', '')} · {it.get('pubdate', '')}"
        )
        if it.get("abstract"):
            line += f"\n  > {_trim(it['abstract'], 320)}"
        out.append(line)
    return out


def _digest_510k_md(items: list[dict[str, Any]]) -> list[str]:
    out = []
    for r in items:
        knum = r.get("k_number", "")
        url = f"https://www.accessdata.fda.gov/scripts/cdrh/cfdocs/cfpmn/pmn.cfm?ID={knum}"
        out.append(
            f"- [{r.get('device_name', '?')}]({url}) — {r.get('applicant', '?')} · {r.get('decision_date', '?')}"
        )
    return out


def _digest_recall_md(items: list[dict[str, Any]]) -> list[str]:
    return [
        f"- {_trim(r.get('product_description'), 100)} — `{r.get('recall_number', '?')}` · "
        f"{r.get('classification', '?')} · {r.get('event_date_initiated', '?')}"
        for r in items
    ]


async def _digest_call(
    source: str, topic: str, per_source_limit: int, days: int
) -> tuple[str, str | None, list[dict[str, Any]]]:
    """Returns (source, error_or_none, items_list)."""
    try:
        if source == DigestSource.ARXIV.value:
            params = {
                "search_query": f"all:{topic}",
                "sortBy": "submittedDate",
                "sortOrder": "descending",
                "max_results": per_source_limit,
            }
            text = await _http_get_text(ARXIV_API, params=params, ttl=TTL_DEFAULT)
            return source, None, _parse_arxiv_atom(text)[:per_source_limit]

        if source == DigestSource.GITHUB.value:
            since_date = (_utc_now() - timedelta(days=days)).strftime("%Y-%m-%d")
            params = {
                "q": f"{topic} created:>{since_date}",
                "per_page": per_source_limit,
                "sort": "stars",
                "order": "desc",
            }
            headers = {
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            }
            tok = os.environ.get("GITHUB_TOKEN")
            if tok:
                headers["Authorization"] = f"Bearer {tok}"
            data = await _http_get_json(GITHUB_API, params=params, headers=headers, ttl=TTL_TRENDING)
            items = [
                {
                    "full_name": x.get("full_name", ""),
                    "url": x.get("html_url", ""),
                    "description": x.get("description") or "",
                    "language": x.get("language"),
                    "stars": x.get("stargazers_count", 0),
                }
                for x in (data.get("items") or [])[:per_source_limit]
            ]
            return source, None, items

        if source == DigestSource.HUGGINGFACE.value:
            params = {
                "sort": "trendingScore",
                "direction": -1,
                "limit": per_source_limit,
                "search": topic,
            }
            headers: dict[str, str] = {}
            tok = os.environ.get("HF_TOKEN")
            if tok:
                headers["Authorization"] = f"Bearer {tok}"
            raw = await _http_get_json(
                f"{HF_API}/models", params=params, headers=headers or None, ttl=TTL_TRENDING
            )
            if not isinstance(raw, list):
                raw = []
            items = [
                {
                    "id": x.get("id", ""),
                    "url": f"https://huggingface.co/{x.get('id', '')}",
                    "downloads": x.get("downloads"),
                    "likes": x.get("likes", 0),
                }
                for x in raw[:per_source_limit]
            ]
            return source, None, items

        if source == DigestSource.PAPERSWITHCODE.value:
            raw = await _http_get_json(HF_DAILY_PAPERS_API, ttl=TTL_TRENDING)
            if not isinstance(raw, list):
                raw = []
            q_lower = topic.lower()
            items = []
            for entry in raw:
                paper = entry.get("paper") or {}
                title = entry.get("title") or paper.get("title") or ""
                summary = entry.get("summary") or paper.get("summary") or ""
                if q_lower and q_lower not in title.lower() and q_lower not in summary.lower():
                    continue
                arxiv_id = paper.get("id") or ""
                items.append({
                    "title": title.strip(),
                    "url_abs": f"https://huggingface.co/papers/{arxiv_id}" if arxiv_id else "",
                    "published": entry.get("publishedAt") or paper.get("publishedAt") or "",
                })
                if len(items) >= per_source_limit:
                    break
            return source, None, items

        if source == DigestSource.PUBMED.value:
            term = f"({topic}) AND (\"last {days} days\"[PDat])"
            common = {"db": "pubmed", "retmode": "json"}
            api_key = os.environ.get("NCBI_API_KEY")
            if api_key:
                common["api_key"] = api_key
            r1 = await _http_get_json(
                f"{PUBMED_BASE}/esearch.fcgi",
                params={**common, "term": term, "retmax": per_source_limit, "sort": "pub_date"},
                ttl=TTL_STATIC,
            )
            pmids = r1.get("esearchresult", {}).get("idlist", [])
            if not pmids:
                return source, None, []
            r2 = await _http_get_json(
                f"{PUBMED_BASE}/esummary.fcgi",
                params={**common, "id": ",".join(pmids)},
                ttl=TTL_STATIC,
            )
            result = r2.get("result", {})
            uids = result.get("uids", pmids)
            abstracts = await _pubmed_fetch_abstracts(list(uids))
            items = []
            for uid in uids:
                rec = result.get(uid)
                if not rec:
                    continue
                items.append(
                    {
                        "pmid": uid,
                        "url": f"https://pubmed.ncbi.nlm.nih.gov/{uid}/",
                        "title": rec.get("title", "").rstrip("."),
                        "journal": rec.get("fulljournalname") or rec.get("source") or "",
                        "pubdate": rec.get("pubdate") or "",
                        "abstract": abstracts.get(uid, ""),
                    }
                )
            return source, None, items

        if source == DigestSource.FDA_510K.value:
            end = _utc_now().strftime("%Y%m%d")
            start = (_utc_now() - timedelta(days=max(days, 30))).strftime("%Y%m%d")
            search = f"decision_date:[{start}+TO+{end}]+AND+device_name:{topic}"
            url = f"{OPENFDA_510K}?search={search}&limit={per_source_limit}&sort=decision_date:desc"
            api_key = os.environ.get("OPENFDA_API_KEY")
            if api_key:
                url += f"&api_key={api_key}"
            try:
                data = await _http_get_json(url, ttl=TTL_STATIC)
                return source, None, (data.get("results") or [])[:per_source_limit]
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 404:
                    return source, None, []
                raise

        if source == DigestSource.FDA_RECALLS.value:
            end = _utc_now().strftime("%Y%m%d")
            start = (_utc_now() - timedelta(days=max(days, 90))).strftime("%Y%m%d")
            search = f"event_date_initiated:[{start}+TO+{end}]+AND+product_description:{topic}"
            url = f"{OPENFDA_RECALL}?search={search}&limit={per_source_limit}&sort=event_date_initiated:desc"
            api_key = os.environ.get("OPENFDA_API_KEY")
            if api_key:
                url += f"&api_key={api_key}"
            try:
                data = await _http_get_json(url, ttl=TTL_STATIC)
                return source, None, (data.get("results") or [])[:per_source_limit]
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 404:
                    return source, None, []
                raise

        return source, f"Unknown source: {source}", []
    except Exception as e:
        return source, _handle_error(e, f"digest:{source}"), []


_DIGEST_SECTION = {
    DigestSource.ARXIV.value: ("📌 arXiv", _digest_arxiv_md),
    DigestSource.GITHUB.value: ("📌 GitHub", _digest_github_md),
    DigestSource.HUGGINGFACE.value: ("📌 Hugging Face (models)", _digest_hf_md),
    DigestSource.PAPERSWITHCODE.value: ("📌 Papers with Code", _digest_pwc_md),
    DigestSource.PUBMED.value: ("📌 PubMed", _digest_pubmed_md),
    DigestSource.FDA_510K.value: ("📌 FDA 510(k)", _digest_510k_md),
    DigestSource.FDA_RECALLS.value: ("📌 FDA Recalls", _digest_recall_md),
}


@mcp.tool(
    name="trends_digest",
    description=(
        "One-shot multi-source digest for a topic. Calls sources in parallel; "
        "partial failures don't break the report.\n\n"
        "PRESENTATION RULES — follow strictly:\n"
        "1) PRESERVE SECTION STRUCTURE. The output has separate per-source "
        "sections (📌 arXiv, 📌 PubMed, 📌 GitHub, etc.). Do NOT merge them.\n"
        "2) TRANSLATE INLINE TEXT into the user's conversation language; keep "
        "section headers and emoji as-is.\n"
        "3) PRESERVE VERBATIM: proper nouns, IDs (PMID, k_number, arXiv IDs), "
        "URLs, repository names, metric values.\n"
        "4) Render every item — no summarization at the digest level."
    ),
    annotations={
        "readOnlyHint": True,
        "destructiveHint": False,
        "openWorldHint": True,
        "idempotentHint": False,
    },
)
async def trends_digest(
    topic: str,
    sources: list[str] | None = None,
    per_source_limit: int = 5,
    days: int = 14,
) -> str:
    if not topic or not topic.strip():
        return "Error: `topic` is required."
    topic = topic.strip()
    sources = sources or _DEFAULT_SOURCES
    if not sources:
        return (
            "Error: no sources enabled. Set TRENDS_ENABLED_SOURCES env var "
            f"to a subset of {sorted(ALL_SOURCES)}."
        )
    valid = {s.value for s in DigestSource}
    bad = [s for s in sources if s not in valid]
    if bad:
        return f"Error: unknown sources {bad}. Valid: {sorted(valid)}"
    disabled = [s for s in sources if s not in ENABLED_SOURCES]
    if disabled:
        return (
            f"Error: sources {disabled} are disabled by TRENDS_ENABLED_SOURCES env var. "
            f"Currently enabled: {sorted(ENABLED_SOURCES)}."
        )
    per_source_limit = max(1, min(per_source_limit, 15))
    days = max(1, min(days, 90))

    tasks = [_digest_call(s, topic, per_source_limit, days) for s in sources]
    results = await asyncio.gather(*tasks, return_exceptions=False)

    lines = [
        f"# 트렌드 다이제스트: `{topic}`",
        f"_최근 {days}일 · 소스 {len(sources)}개_",
        "",
    ]
    for source, err, items in results:
        title, render = _DIGEST_SECTION[source]
        lines.append(f"## {title}")
        if err:
            lines.append(f"_{err}_\n")
            continue
        if not items:
            lines.append("_결과 없음_\n")
            continue
        lines.extend(render(items))
        lines.append("")
    lines.append(
        "<!-- PRESENTATION HINT: keep per-source sections (📌 arXiv, 📌 PubMed, "
        "etc.) separate — do NOT merge. Translate inline content to the user's "
        "conversation language; preserve URLs, IDs, author/repo/journal names, "
        "and metric values verbatim. Render every item, no summarization. -->"
    )
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# 8. trends_briefing — newspaper-style multi-source briefing
# ---------------------------------------------------------------------------
# Differs from trends_digest in three ways:
#   - Topic is optional. Without one, each source uses its natural "what's new"
#     mode (arxiv → recent in default categories, github → trending page, etc).
#   - Always covers ALL enabled sources, not just a default 4.
#   - Renders in newspaper format: grouped sections, headlines, lede, byline.

# Domain-neutral default for distribution. Users override via env var.
_FALLBACK_BRIEFING_ARXIV_WEIGHTS: list[tuple[str, int]] = [
    ("cs.AI", 3), ("cs.LG", 3), ("cs.CV", 3),
]
_FALLBACK_BRIEFING_PUBMED_QUERY: str = (
    "(artificial intelligence[Title/Abstract] OR deep learning[Title/Abstract] "
    "OR machine learning[Title/Abstract]) AND (medical OR clinical OR healthcare)"
)
_DEFAULT_PER_CATEGORY = 3
# Validate against the canonical arXiv taxonomy (top-level archive prefixes).
# The exhaustive list of valid leaf categories is too long to inline here; we
# accept any "<archive>.<sub>" or "<archive>" form whose archive prefix is known.
_VALID_ARXIV_ARCHIVES: frozenset[str] = frozenset({
    "cs", "math", "stat", "physics", "astro-ph", "cond-mat", "gr-qc", "hep-ex",
    "hep-lat", "hep-ph", "hep-th", "math-ph", "nlin", "nucl-ex", "nucl-th",
    "quant-ph", "q-bio", "q-fin", "eess", "econ",
})


def _is_valid_arxiv_category(code: str) -> bool:
    """Loose validation — accepts `cs.HC`, `eess.IV`, etc. by archive prefix."""
    if not code:
        return False
    archive = code.split(".", 1)[0]
    return archive in _VALID_ARXIV_ARCHIVES


def _parse_arxiv_category_weights(raw: str) -> list[tuple[str, int]]:
    """Parse `TRENDS_ARXIV_CATEGORIES` value.

    Format: comma-separated `category[:count]`. Examples:
        "cs.HC:5,eess.IV:5,cs.CV:3"   → weighted
        "cs.HC,eess.IV,cs.CV"          → all default count
        "cs.HC:5, eess.IV ,cs.CV:2"    → whitespace tolerated

    Invalid categories trigger a stderr WARN and are skipped.
    Returns [] on empty input — caller falls back to default.
    """
    raw = raw.strip()
    if not raw:
        return []
    out: list[tuple[str, int]] = []
    bad: list[str] = []
    for chunk in raw.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        if ":" in chunk:
            cat, count_str = chunk.split(":", 1)
            cat = cat.strip()
            try:
                count = int(count_str.strip())
                if count < 1:
                    raise ValueError
            except ValueError:
                bad.append(chunk)
                continue
        else:
            cat = chunk
            count = _DEFAULT_PER_CATEGORY
        if not _is_valid_arxiv_category(cat):
            bad.append(cat)
            continue
        out.append((cat, count))
    if bad:
        import sys
        print(
            f"[trends-mcp] WARN: ignoring invalid arXiv category entries in "
            f"TRENDS_ARXIV_CATEGORIES: {bad}",
            file=sys.stderr,
        )
    return out


def _read_arxiv_category_weights() -> list[tuple[str, int]]:
    # Primary: TRENDS_ARXIV_CATEGORIES (with weights).
    primary = os.environ.get("TRENDS_ARXIV_CATEGORIES", "")
    parsed = _parse_arxiv_category_weights(primary)
    if parsed:
        return parsed
    # Backward-compat: TRENDS_DEFAULT_ARXIV_CATEGORIES (categories only, all use default count).
    legacy = os.environ.get("TRENDS_DEFAULT_ARXIV_CATEGORIES", "").strip()
    if legacy:
        cats = [c.strip() for c in legacy.split(",") if c.strip() and _is_valid_arxiv_category(c.strip())]
        if cats:
            return [(c, _DEFAULT_PER_CATEGORY) for c in cats]
    return list(_FALLBACK_BRIEFING_ARXIV_WEIGHTS)


def _read_default_pubmed_query() -> str:
    raw = os.environ.get("TRENDS_DEFAULT_PUBMED_QUERY", "").strip()
    return raw or _FALLBACK_BRIEFING_PUBMED_QUERY


DEFAULT_BRIEFING_ARXIV_WEIGHTS: list[tuple[str, int]] = _read_arxiv_category_weights()
# Backward-compat: keep the old list name pointing at category-only view.
DEFAULT_BRIEFING_ARXIV_CATEGORIES: list[str] = [c for c, _ in DEFAULT_BRIEFING_ARXIV_WEIGHTS]
DEFAULT_BRIEFING_PUBMED_QUERY: str = _read_default_pubmed_query()

# Group ordering for newspaper layout. Sections within a group keep this order.
_BRIEFING_GROUPS: list[tuple[str, list[str]]] = [
    ("🎓 연구 동향", ["arxiv", "pubmed", "paperswithcode"]),
    ("💻 코드 / 모델", ["github", "huggingface"]),
    ("🏥 규제 / 의료기기", ["fda_510k", "fda_recalls"]),
]


# arXiv fetch tuning. We prioritize completeness over latency: a slow
# category should still surface its papers rather than getting dropped.
#
# Layout: categories are processed in batches of `ARXIV_BATCH_SIZE`,
# parallel within a batch, sequential across batches. With 4 categories
# and BATCH_SIZE=2, that's `(B1 parallel) → 3s gap → (B2 parallel)`.
# Worst case: max(b1) + 3s + max(b2). Best case (cache hit or fast
# response): about max-of-batch ≈ a few seconds.
#
# `INTER_BATCH_DELAY=3.0` matches arXiv's recommended request spacing
# so we stay polite even under a fresh-cache run.
# `PER_CATEGORY_TIMEOUT=25.0` is generous enough that genuinely-slow
# categories still complete instead of being silently dropped.
# Sequential per-category fetches with a 5s gap — arxiv's API docs explicitly
# request serial (not parallel) access with at least a 3s spacing. Earlier
# we ran 2-at-a-time with 3s between batches; in practice arxiv still flagged
# that as bursty and rate-limited even single-user traffic. Going fully serial
# trades ~10-15s of briefing latency for a near-zero 429 rate.
ARXIV_BATCH_SIZE = 1
ARXIV_INTER_BATCH_DELAY = 5.0
ARXIV_PER_CATEGORY_TIMEOUT = 25.0


async def _fetch_arxiv_for_category(
    category: str, count: int, days: int
) -> list[dict[str, Any]]:
    """Fetch up to `count` papers from one arXiv category, time-cut to `days`.

    Uses an arxiv-specific short timeout (`ARXIV_PER_CATEGORY_TIMEOUT`) so a
    hung category fails fast instead of eating 20s of the briefing budget.
    """
    fetch_n = min(max(count * 4, 12), 100)  # over-fetch for date filter
    params = {
        "search_query": f"cat:{category}",
        "sortBy": "submittedDate",
        "sortOrder": "descending",
        "max_results": fetch_n,
    }
    text = await _http_get_text(
        ARXIV_API, params=params, ttl=TTL_DEFAULT,
        timeout=ARXIV_PER_CATEGORY_TIMEOUT,
    )
    papers = _parse_arxiv_atom(text)
    cutoff = _utc_now() - timedelta(days=days)
    kept: list[dict[str, Any]] = []
    for p in papers:
        try:
            pub_dt = datetime.fromisoformat(p["published"].replace("Z", "+00:00"))
        except ValueError:
            continue
        if pub_dt >= cutoff:
            kept.append(p)
        if len(kept) >= count:
            break
    return kept


async def _fetch_arxiv_for_category_safe(
    category: str, count: int, days: int
) -> tuple[str | None, list[dict[str, Any]]]:
    """Failure-isolated wrapper around `_fetch_arxiv_for_category`.

    Returns `(error_msg, papers)`. `error_msg` is None on success and a
    short human-readable string on failure (with `papers=[]`).

    Retry policy:
      - 429 (rate limit): NO retry. arXiv's TOU asks for ~30-60s cooldown
        after a 429, which is too long to absorb inside a briefing — the
        old 2s retry almost always hit 429 again anyway. Surface the rate
        limit instead so the caller can show it to the user.
      - 5xx: one retry after 1s. Transient server errors usually recover.
      - timeout / connect / parse: fail fast, no retry.
    """
    try:
        return None, await _fetch_arxiv_for_category(category, count, days)
    except httpx.HTTPStatusError as e:
        code = e.response.status_code
        if code == 429:
            return "rate limited (HTTP 429) — arXiv expects 30-60s cooldown before retry", []
        if 500 <= code < 600:
            await asyncio.sleep(1.0)
            try:
                return None, await _fetch_arxiv_for_category(category, count, days)
            except Exception:
                return f"HTTP {code} after retry", []
        return f"HTTP {code}", []
    except httpx.TimeoutException:
        return "timeout", []
    except Exception as e:
        return type(e).__name__, []


async def _briefing_call(
    source: str,
    topic: str | None,
    arxiv_weights: list[tuple[str, int]],
    pubmed_query: str,
    per_source_limit: int,
    days: int,
) -> tuple[str, str | None, list[dict[str, Any]]]:
    """Returns (source, error_or_none, items_list) — newspaper-mode fetch."""
    try:
        if source == "arxiv":
            if topic:
                # Topic-driven mode: a single keyword search across all of arXiv.
                params = {
                    "search_query": f"all:{topic}",
                    "sortBy": "submittedDate",
                    "sortOrder": "descending",
                    "max_results": per_source_limit * 4,
                }
                text = await _http_get_text(ARXIV_API, params=params, ttl=TTL_DEFAULT)
                papers = _parse_arxiv_atom(text)
                cutoff = _utc_now() - timedelta(days=days)
                kept: list[dict[str, Any]] = []
                for p in papers:
                    try:
                        pub_dt = datetime.fromisoformat(p["published"].replace("Z", "+00:00"))
                    except ValueError:
                        continue
                    if pub_dt >= cutoff:
                        kept.append(p)
                    if len(kept) >= per_source_limit:
                        break
                return source, None, kept
            # Topicless mode: category-balanced round-robin. Each category gets
            # exactly its configured count — small categories don't get drowned
            # out by large ones (e.g. cs.HC ~50/wk vs cs.LG ~1500/wk).
            #
            # FETCH STRATEGY: batched parallel (ARXIV_BATCH_SIZE per batch),
            # sequential across batches with `ARXIV_INTER_BATCH_DELAY` spacing.
            # Faster than fully-sequential, gentler on arXiv than fully-parallel.
            #
            # FAILURE ISOLATION: each category is wrapped independently in
            # `_fetch_arxiv_for_category_safe`. A single timeout / 429 / 5xx
            # / parse failure no longer wipes out the entire arXiv section —
            # that category just contributes 0 papers while siblings keep
            # their results.
            if not arxiv_weights:
                return source, None, []
            per_cat_results: list[tuple[str | None, list[dict[str, Any]]]] = []
            for batch_start in range(0, len(arxiv_weights), ARXIV_BATCH_SIZE):
                if batch_start > 0:
                    await asyncio.sleep(ARXIV_INTER_BATCH_DELAY)
                batch = arxiv_weights[batch_start : batch_start + ARXIV_BATCH_SIZE]
                # Parallel fetch within the batch. With ARXIV_BATCH_SIZE=1
                # this is effectively serial; kept as gather so the batching
                # knob still works if it's ever tuned back up.
                batch_results = await asyncio.gather(*[
                    _fetch_arxiv_for_category_safe(cat, count, days)
                    for cat, count in batch
                ])
                per_cat_results.extend(batch_results)
            # Aggregate. Partial success (≥1 category returned papers) → use
            # what we have, no global error — graceful degradation. All-fail
            # → surface a representative error so the briefing makes the cause
            # visible instead of an empty arXiv section (the old behaviour,
            # which led to "is this broken?" diagnoses upstream).
            merged: list[dict[str, Any]] = []
            errors: list[str] = []
            for err, papers in per_cat_results:
                if err is not None:
                    errors.append(err)
                merged.extend(papers)
            if merged:
                return source, None, merged
            if errors:
                rate_err = next((e for e in errors if "rate limited" in e), None)
                return source, rate_err or errors[0], []
            return source, None, []

        if source == "github":
            if topic:
                since_date = (_utc_now() - timedelta(days=days)).strftime("%Y-%m-%d")
                params = {
                    "q": f"{topic} created:>{since_date}",
                    "per_page": per_source_limit,
                    "sort": "stars",
                    "order": "desc",
                }
                headers = {
                    "Accept": "application/vnd.github+json",
                    "X-GitHub-Api-Version": "2022-11-28",
                }
                tok = os.environ.get("GITHUB_TOKEN")
                if tok:
                    headers["Authorization"] = f"Bearer {tok}"
                data = await _http_get_json(
                    GITHUB_API, params=params, headers=headers, ttl=TTL_TRENDING
                )
                items = [
                    {
                        "full_name": x.get("full_name", ""),
                        "url": x.get("html_url", ""),
                        "description": x.get("description") or "",
                        "language": x.get("language"),
                        "stars": x.get("stargazers_count", 0),
                        "stars_period": None,
                    }
                    for x in (data.get("items") or [])[:per_source_limit]
                ]
                return source, None, items
            # Topicless: use trending scrape, mapping `days` to since-window.
            since = "daily" if days <= 1 else ("weekly" if days <= 7 else "monthly")
            text = await _http_get_text(
                GITHUB_TRENDING, params={"since": since}, ttl=TTL_TRENDING
            )
            soup = BeautifulSoup(text, "html.parser")
            articles = soup.select("article.Box-row")
            repos: list[dict[str, Any]] = []
            for art in articles[:per_source_limit]:
                h2 = art.select_one("h2 a")
                if not h2:
                    continue
                href = h2.get("href", "").strip()
                full_name = re.sub(r"\s+", "", h2.get_text()).strip("/")
                desc_el = art.select_one("p")
                desc = desc_el.get_text(strip=True) if desc_el else ""
                lang_el = art.select_one('[itemprop="programmingLanguage"]')
                language = lang_el.get_text(strip=True) if lang_el else None
                stars = 0
                for a in art.select("a.Link--muted"):
                    ah = a.get("href", "")
                    num_text = a.get_text(strip=True).replace(",", "")
                    m = re.search(r"\d+", num_text)
                    if not m:
                        continue
                    if ah.endswith("/stargazers"):
                        stars = int(m.group())
                period_el = art.select_one("span.d-inline-block.float-sm-right")
                stars_period = None
                if period_el:
                    pm = re.search(r"[\d,]+", period_el.get_text())
                    if pm:
                        stars_period = int(pm.group().replace(",", ""))
                repos.append(
                    {
                        "full_name": full_name,
                        "url": "https://github.com" + href if href.startswith("/") else href,
                        "description": desc,
                        "language": language,
                        "stars": stars,
                        "stars_period": stars_period,
                    }
                )
            return source, None, repos

        if source == "huggingface":
            params = {
                "sort": "trendingScore",
                "direction": -1,
                "limit": per_source_limit * 2,
            }
            if topic:
                params["search"] = topic
            headers: dict[str, str] = {}
            tok = os.environ.get("HF_TOKEN")
            if tok:
                headers["Authorization"] = f"Bearer {tok}"
            raw = await _http_get_json(
                f"{HF_API}/models",
                params=params,
                headers=headers or None,
                ttl=TTL_TRENDING,
            )
            if not isinstance(raw, list):
                raw = []
            items = [
                {
                    "id": x.get("id", ""),
                    "url": f"https://huggingface.co/{x.get('id', '')}",
                    "downloads": x.get("downloads"),
                    "likes": x.get("likes", 0),
                    "lastModified": x.get("lastModified") or x.get("last_modified"),
                    "pipeline_tag": x.get("pipeline_tag"),
                    "tags": x.get("tags") or [],
                }
                for x in raw[:per_source_limit]
            ]
            return source, None, items

        if source == "paperswithcode":
            raw = await _http_get_json(HF_DAILY_PAPERS_API, ttl=TTL_TRENDING)
            if not isinstance(raw, list):
                raw = []
            q_lower = topic.lower() if topic else None
            cutoff = _utc_now() - timedelta(days=days)
            candidates: list[dict[str, Any]] = []
            for entry in raw:
                paper = entry.get("paper") or {}
                title = entry.get("title") or paper.get("title") or ""
                summary = entry.get("summary") or paper.get("summary") or ""
                if q_lower and q_lower not in title.lower() and q_lower not in summary.lower():
                    continue
                pub = entry.get("publishedAt") or paper.get("publishedAt") or ""
                if pub:
                    try:
                        pub_dt = datetime.fromisoformat(pub.replace("Z", "+00:00"))
                        if pub_dt.tzinfo is None:
                            pub_dt = pub_dt.replace(tzinfo=timezone.utc)
                        if pub_dt < cutoff:
                            continue
                    except ValueError:
                        pass
                candidates.append(_hf_paper_to_item(entry))
            # Briefing's HF-papers section is the "trending" lane: sort by upvotes
            # so the most-talked-about papers float to the top.
            candidates.sort(
                key=lambda x: (x.get("upvotes") or 0, x.get("num_comments") or 0),
                reverse=True,
            )
            return source, None, candidates[:per_source_limit]

        if source == "pubmed":
            base_query = topic if topic else pubmed_query
            term = f"({base_query}) AND (\"last {days} days\"[PDat])"
            common: dict[str, Any] = {"db": "pubmed", "retmode": "json"}
            api_key = os.environ.get("NCBI_API_KEY")
            if api_key:
                common["api_key"] = api_key
            r1 = await _http_get_json(
                f"{PUBMED_BASE}/esearch.fcgi",
                params={**common, "term": term, "retmax": per_source_limit, "sort": "pub_date"},
                ttl=TTL_STATIC,
            )
            pmids = r1.get("esearchresult", {}).get("idlist", [])
            if not pmids:
                return source, None, []
            r2 = await _http_get_json(
                f"{PUBMED_BASE}/esummary.fcgi",
                params={**common, "id": ",".join(pmids)},
                ttl=TTL_STATIC,
            )
            result = r2.get("result", {})
            uids = result.get("uids", pmids)
            abstracts = await _pubmed_fetch_abstracts(list(uids))
            items: list[dict[str, Any]] = []
            for uid in uids:
                rec = result.get(uid)
                if not rec:
                    continue
                items.append(
                    {
                        "pmid": uid,
                        "url": f"https://pubmed.ncbi.nlm.nih.gov/{uid}/",
                        "title": rec.get("title", "").rstrip("."),
                        "journal": rec.get("fulljournalname") or rec.get("source") or "",
                        "pubdate": rec.get("pubdate") or "",
                        "authors": [a.get("name", "") for a in rec.get("authors", []) if a.get("name")],
                        "abstract": abstracts.get(uid, ""),
                    }
                )
            return source, None, items

        if source == "fda_510k":
            end = _utc_now().strftime("%Y%m%d")
            start = (_utc_now() - timedelta(days=max(days, 30))).strftime("%Y%m%d")
            search = f"decision_date:[{start}+TO+{end}]"
            if topic:
                search += f"+AND+device_name:{topic}"
            url = f"{OPENFDA_510K}?search={search}&limit={per_source_limit}&sort=decision_date:desc"
            api_key = os.environ.get("OPENFDA_API_KEY")
            if api_key:
                url += f"&api_key={api_key}"
            try:
                data = await _http_get_json(url, ttl=TTL_STATIC)
                return source, None, (data.get("results") or [])[:per_source_limit]
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 404:
                    return source, None, []
                raise

        if source == "fda_recalls":
            end = _utc_now().strftime("%Y%m%d")
            start = (_utc_now() - timedelta(days=max(days, 90))).strftime("%Y%m%d")
            search = f"event_date_initiated:[{start}+TO+{end}]"
            if topic:
                search += f"+AND+product_description:{topic}"
            url = f"{OPENFDA_RECALL}?search={search}&limit={per_source_limit}&sort=event_date_initiated:desc"
            api_key = os.environ.get("OPENFDA_API_KEY")
            if api_key:
                url += f"&api_key={api_key}"
            try:
                data = await _http_get_json(url, ttl=TTL_STATIC)
                return source, None, (data.get("results") or [])[:per_source_limit]
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 404:
                    return source, None, []
                raise

        return source, f"Unknown source: {source}", []
    except Exception as e:
        return source, _handle_error(e, f"briefing:{source}"), []


# --- Newspaper-style renderers (one section per source) ---------------------

def _byline(parts: list[str]) -> str:
    return " · ".join(p for p in parts if p)


def _briefing_arxiv(items: list[dict[str, Any]]) -> str:
    out: list[str] = []
    for it in items:
        authors = ", ".join(it["authors"][:3])
        if len(it["authors"]) > 3:
            authors += " 외"
        out.append(f"#### 📄 [{it['title']}]({it['url']})")
        out.append(f"*{_byline([it.get('primary_category', ''), _fmt_date(it.get('published')), authors])}*")
        if it.get("summary"):
            out.append(f"> {_trim(it['summary'], 500)}")
        out.append("")
    return "\n".join(out)


def _briefing_pubmed(items: list[dict[str, Any]]) -> str:
    out: list[str] = []
    for it in items:
        authors = ", ".join(it["authors"][:3])
        if len(it["authors"]) > 3:
            authors += " 외"
        out.append(f"#### 🩺 [{it['title']}]({it['url']})")
        out.append(f"*{_byline([it.get('journal', ''), it.get('pubdate', ''), authors])}*")
        if it.get("abstract"):
            out.append(f"> {_trim(it['abstract'], 500)}")
        else:
            out.append(f"> PMID `{it['pmid']}` (no abstract on file)")
        out.append("")
    return "\n".join(out)


def _briefing_pwc(items: list[dict[str, Any]]) -> str:
    out: list[str] = []
    for it in items:
        authors = ", ".join(it["authors"][:3])
        if len(it["authors"]) > 3:
            authors += " 외"
        # Popularity badge built from HF community signals.
        metric_bits: list[str] = []
        if it.get("upvotes"):
            metric_bits.append(f"👍 {it['upvotes']}")
        if it.get("num_comments"):
            metric_bits.append(f"💬 {it['num_comments']}")
        byline_parts = ["HF Daily Papers", _fmt_date(it.get("published")), authors]
        if metric_bits:
            byline_parts.append(" ".join(metric_bits))
        out.append(f"#### 📐 [{it['title']}]({it['url_abs']})")
        out.append(f"*{_byline(byline_parts)}*")
        # Prefer ai_summary (one-liner) as the lede, fall back to abstract excerpt.
        lede = it.get("ai_summary") or it.get("abstract") or ""
        if lede:
            out.append(f"> {_trim(lede, 500)}")
        out.append("")
    return "\n".join(out)


def _briefing_github(items: list[dict[str, Any]]) -> str:
    out: list[str] = []
    for it in items:
        period = f" (+{it['stars_period']:,} 이번 기간)" if it.get("stars_period") else ""
        meta = _byline([
            f"⭐ {it.get('stars', 0):,}{period}",
            it.get("language") or "",
        ])
        out.append(f"#### ⭐ [{it['full_name']}]({it['url']})")
        out.append(f"*{meta}*")
        if it.get("description"):
            out.append(f"> {_trim(it['description'], 200)}")
        out.append("")
    return "\n".join(out)


def _briefing_hf(items: list[dict[str, Any]]) -> str:
    out: list[str] = []
    for it in items:
        bits: list[str] = []
        if it.get("downloads") is not None:
            bits.append(f"📥 {it['downloads']:,}")
        bits.append(f"❤️ {it.get('likes', 0):,}")
        if it.get("pipeline_tag"):
            bits.append(f"`{it['pipeline_tag']}`")
        out.append(f"#### 🤖 [{it['id']}]({it['url']})")
        out.append(f"*{_byline(bits)}*")
        tags = it.get("tags") or []
        if tags:
            out.append(f"> 태그: {', '.join(tags[:6])}")
        out.append("")
    return "\n".join(out)


def _briefing_510k(items: list[dict[str, Any]]) -> str:
    out: list[str] = []
    for it in items:
        knum = it.get("k_number", "")
        url = (
            f"https://www.accessdata.fda.gov/scripts/cdrh/cfdocs/cfpmn/pmn.cfm?ID={knum}"
            if knum else ""
        )
        title = (
            f"[{it.get('device_name', '?')}]({url})" if url else it.get("device_name", "?")
        )
        out.append(f"#### 🏥 {title}")
        out.append(
            f"*{_byline([it.get('applicant', '?'), it.get('decision_description') or it.get('decision_code', '?'), it.get('decision_date', '?')])}*"
        )
        out.append(f"> 510(k) `{knum}` · 제품코드 `{it.get('product_code', '?')}`")
        out.append("")
    return "\n".join(out)


def _briefing_recalls(items: list[dict[str, Any]]) -> str:
    out: list[str] = []
    for it in items:
        prod = _trim(it.get("product_description"), 100)
        out.append(f"#### ⚠️ {prod}")
        out.append(
            f"*{_byline([it.get('classification', '?'), it.get('recalling_firm', '?'), it.get('event_date_initiated', '?')])}*"
        )
        reason = _trim(it.get("reason_for_recall"), 400)
        if reason:
            out.append(f"> 사유: {reason}")
        out.append("")
    return "\n".join(out)


_BRIEFING_RENDERERS: dict[str, tuple[str, Callable[[list[dict[str, Any]]], str]]] = {
    "arxiv": ("arXiv — 최신 논문", _briefing_arxiv),
    "pubmed": ("PubMed — 의학 문헌", _briefing_pubmed),
    "paperswithcode": ("Papers with Code", _briefing_pwc),
    "github": ("GitHub — Trending", _briefing_github),
    "huggingface": ("Hugging Face — Trending Models", _briefing_hf),
    "fda_510k": ("FDA 510(k) — 최근 인허가", _briefing_510k),
    "fda_recalls": ("FDA Recalls — 최근 회수", _briefing_recalls),
}


@mcp.tool(
    name="trends_briefing",
    description=(
        "Newspaper-style weekly briefing across all enabled sources. "
        "Topic is optional — without it, each source shows its 'what's new' feed. "
        "Use this when the user asks for '주간 뉴스' / '주간 트렌드' / 'weekly news' / 'briefing' style output.\n\n"
        "PRESENTATION RULES — follow strictly:\n"
        "1) PRESERVE STRUCTURE EXACTLY. The output is already organized into "
        "three groups (🎓 연구 동향 / 💻 코드 / 모델 / 🏥 규제 / 의료기기) and "
        "seven distinct source sections (arXiv, PubMed, Papers with Code, "
        "GitHub, Hugging Face, FDA 510(k), FDA Recalls). Do NOT merge sections "
        "(e.g. don't combine arXiv + PubMed into one 'papers' list). Do NOT "
        "reorder sections or items within a section. Do NOT change emoji or "
        "section headers.\n"
        "2) TRANSLATE INLINE TEXT ONLY. Translate paper titles, abstracts, "
        "descriptions, and recall reasons into the user's current conversation "
        "language. Keep section headers, group titles, emoji, and metadata "
        "labels in their original form.\n"
        "3) PRESERVE VERBATIM: proper nouns, author names, journal names, "
        "repository names (e.g. 'mattpocock/skills'), arXiv IDs, PMIDs, "
        "k_numbers, URLs, dates, and metric values (stars, downloads, etc.).\n"
        "4) NO SUMMARIZATION at the briefing level. Render every item the "
        "tool returned. The user wants the full feed, not your synthesis.\n"
        "5) ITEM-LEVEL DEPTH. For each paper, repo, model, or recall, preserve "
        "enough of the upstream abstract/description to convey *what's new "
        "and why it matters* — typically 2–4 sentences (around 150–300 chars "
        "of translated content per item). Do NOT collapse to a single "
        "headline-length sentence; the user wants to grasp each item without "
        "clicking through. Carry the problem → method → result/contribution "
        "structure when present in the source abstract."
    ),
    annotations={
        "readOnlyHint": True,
        "destructiveHint": False,
        "openWorldHint": True,
        "idempotentHint": False,
    },
)
async def trends_briefing(
    days: int = 7,
    per_source_limit: int = 5,
    topic: str | None = None,
    arxiv_categories: list[str] | None = None,
    pubmed_query: str | None = None,
) -> str:
    days = max(1, min(days, 30))
    per_source_limit = max(1, min(per_source_limit, 15))
    pq = pubmed_query or DEFAULT_BRIEFING_PUBMED_QUERY
    if topic is not None:
        topic = topic.strip() or None

    # arxiv_categories accepts both plain "cs.HC" and weighted "cs.HC:5".
    # Empty/None → use the env-var-configured default weights.
    if arxiv_categories:
        weights: list[tuple[str, int]] = []
        for entry in arxiv_categories:
            entry = entry.strip()
            if not entry:
                continue
            if ":" in entry:
                cat, count_str = entry.split(":", 1)
                try:
                    count = max(1, int(count_str.strip()))
                except ValueError:
                    count = _DEFAULT_PER_CATEGORY
                cat = cat.strip()
            else:
                cat = entry
                count = _DEFAULT_PER_CATEGORY
            if _is_valid_arxiv_category(cat):
                weights.append((cat, count))
    else:
        weights = DEFAULT_BRIEFING_ARXIV_WEIGHTS

    if not ENABLED_SOURCES:
        return (
            "Error: no sources enabled. Set TRENDS_ENABLED_SOURCES env var "
            f"to a subset of {sorted(ALL_SOURCES)} or unset it for all."
        )

    # Stable order: walk groups, keep only enabled sources.
    ordered: list[str] = []
    for _, group_sources in _BRIEFING_GROUPS:
        for s in group_sources:
            if s in ENABLED_SOURCES and s not in ordered:
                ordered.append(s)

    tasks = [_briefing_call(s, topic, weights, pq, per_source_limit, days) for s in ordered]
    results = await asyncio.gather(*tasks, return_exceptions=False)
    by_source: dict[str, tuple[str | None, list[dict[str, Any]]]] = {
        src: (err, items) for src, err, items in results
    }

    end_dt = _utc_now()
    start_dt = end_dt - timedelta(days=days)
    total = sum(len(items) for _, items in by_source.values())

    headline_meta = (
        f"**{start_dt.strftime('%Y년 %m월 %d일')} ~ {end_dt.strftime('%Y년 %m월 %d일')}**"
        f" · 활성 소스 {len(ordered)}개 · 총 {total}건"
    )
    if topic:
        headline_meta += f" · 토픽 `{topic}`"

    lines: list[str] = [
        "# 📰 트렌드 브리핑",
        "",
        headline_meta,
        "",
        "---",
        "",
    ]

    for group_title, group_sources in _BRIEFING_GROUPS:
        present = [s for s in group_sources if s in by_source]
        if not present:
            continue
        # Skip group if every section is empty AND no errors to report.
        if not any(by_source[s][0] or by_source[s][1] for s in present):
            continue
        lines.append(f"## {group_title}")
        lines.append("")
        for s in present:
            err, items = by_source[s]
            section_title, render = _BRIEFING_RENDERERS[s]
            lines.append(f"### {section_title}")
            lines.append("")
            if err:
                lines.append(f"_{err}_")
                lines.append("")
                continue
            if not items:
                lines.append("_이 기간 새 항목 없음_")
                lines.append("")
                continue
            lines.append(render(items))
        lines.append("---")
        lines.append("")

    # Presentation hint — picked up by the assistant when rendering.
    lines.append(
        "<!-- PRESENTATION HINT: render this briefing EXACTLY as structured. "
        "Keep all section headers (### arXiv, ### PubMed, etc.) separate — do "
        "NOT merge them into combined lists. Translate inline content "
        "(titles, abstracts, descriptions, reasons) into the user's "
        "conversation language; keep URLs, IDs, author names, journal names, "
        "repository names, and metric values verbatim. Render every item — "
        "do not summarize at the briefing level. -->"
    )

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Configuration tools — chat-side parity with configure.py
# ---------------------------------------------------------------------------
# Both this MCP and configure.py read & write the same SETTINGS block at the
# top of run.py. We import Config from configure.py so there's a single
# load/save implementation; otherwise the two interfaces would drift.
#
# Changes apply on the next MCP spawn: quit Claude Desktop (Cmd+Q) and reopen,
# or run `pkill -f trends_mcp` in a terminal. We deliberately do NOT pkill
# from inside these tools — that would kill the very process responding to
# the request.

from configure import (  # noqa: E402  (intentional late import — keeps the rest of the file independent)
    Config as _Config,
    ALL_SOURCES as _CFG_ALL_SOURCES,
    RUN_PY as _RUN_PY,
)

_TOKEN_PROVIDERS: dict[str, str] = {
    "github": "GITHUB_TOKEN",
    "hf": "HF_TOKEN",
    "ncbi": "NCBI_API_KEY",
    "openfda": "OPENFDA_API_KEY",
}


def _restart_hint() -> str:
    return (
        "\n\n⚠️ Restart Claude Desktop (Cmd+Q then reopen) to apply, or run "
        "`pkill -f trends_mcp` in a terminal to force the next call to respawn."
    )


@mcp.tool(
    name="trends_get_config",
    description=(
        "Show current trends-mcp configuration: enabled sources, arXiv "
        "categories, PubMed default query, and which optional rate-limit "
        "tokens are set. Token VALUES are never returned (only whether they "
        "are configured). Use this to confirm state before or after a "
        "trends_set_* call."
    ),
    annotations={
        "readOnlyHint": True,
        "destructiveHint": False,
        "openWorldHint": False,
        "idempotentHint": True,
    },
)
async def trends_get_config() -> dict[str, Any]:
    cfg = _Config.load()
    return {
        "enabled_sources": sorted(cfg.sources_set()),  # always normalized; empty → all
        "all_sources": sorted(_CFG_ALL_SOURCES),
        "arxiv_categories": cfg.arxiv_categories,
        "pubmed_query": cfg.pubmed_query,
        "tokens_set": {
            "github": cfg.tokens["GITHUB_TOKEN"] is not None,
            "hf": cfg.tokens["HF_TOKEN"] is not None,
            "ncbi": cfg.tokens["NCBI_API_KEY"] is not None,
            "openfda": cfg.tokens["OPENFDA_API_KEY"] is not None,
        },
        "config_file": str(_RUN_PY),
    }


@mcp.tool(
    name="trends_set_enabled_sources",
    description=(
        "Set which sources are enabled. Pass a list like ['arxiv', 'github']. "
        "Valid: arxiv, github, huggingface, paperswithcode, pubmed, fda_510k, "
        "fda_recalls. Pass ['*'] or ['all'] to enable all. "
        "Disabled sources' tools won't appear in the tool list at all "
        "(requires restart to take effect)."
    ),
    annotations={
        "readOnlyHint": False,
        "destructiveHint": False,
        "openWorldHint": False,
        "idempotentHint": True,
    },
)
async def trends_set_enabled_sources(sources: list[str]) -> str:
    cfg = _Config.load()
    before = cfg.enabled_sources or "(all)"

    # "*" / "all" → empty string, which downstream interprets as "enable all".
    if any(s.strip().lower() in ("*", "all") for s in sources):
        cfg.enabled_sources = ""
        after = "(all)"
    else:
        unknown = [s for s in sources if s not in _CFG_ALL_SOURCES]
        if unknown:
            return (
                f"Error: unknown sources {unknown}. "
                f"Valid: {sorted(_CFG_ALL_SOURCES)}"
            )
        cfg.set_sources({s for s in sources})  # canonical ordering via Config
        # Config.set_sources stores "" when ALL sources are passed (its
        # "enable everything" sentinel) — so empty string here means (all),
        # not (none). Mirror the same convention as `before` above.
        after = cfg.enabled_sources or "(all)"

    cfg.save()
    return f"✅ enabled_sources: {before} → {after}{_restart_hint()}"


@mcp.tool(
    name="trends_set_arxiv_categories",
    description=(
        "Set the default arXiv categories used by trends_briefing. "
        "Pass a list of entries; each entry is 'code' (e.g. 'cs.HC') or "
        "'code:weight' (e.g. 'cs.HC:5'). Weight = papers per briefing per "
        "category (default 3). Example: ['cs.LG:5', 'cs.CV:3', 'cs.CL:2']. "
        "See ARXIV_CATEGORIES.md for the full list of valid codes."
    ),
    annotations={
        "readOnlyHint": False,
        "destructiveHint": False,
        "openWorldHint": False,
        "idempotentHint": True,
    },
)
async def trends_set_arxiv_categories(categories: list[str]) -> str:
    cfg = _Config.load()
    before = cfg.arxiv_categories or "(none)"

    pairs: list[tuple[str, int]] = []
    invalid: list[str] = []
    for entry in categories:
        entry = entry.strip()
        if not entry:
            continue
        if ":" in entry:
            code, count_str = entry.split(":", 1)
            code = code.strip()
            try:
                count = max(1, int(count_str.strip()))
            except ValueError:
                invalid.append(entry)
                continue
        else:
            code = entry
            count = 3  # default weight
        if not _is_valid_arxiv_category(code):
            invalid.append(code)
            continue
        pairs.append((code, count))

    if invalid:
        return (
            f"Error: invalid category codes: {invalid}. "
            f"See ARXIV_CATEGORIES.md for the valid set."
        )

    cfg.set_arxiv_pairs(pairs)
    cfg.save()
    return f"✅ arxiv_categories: {before} → {cfg.arxiv_categories}{_restart_hint()}"


@mcp.tool(
    name="trends_set_pubmed_query",
    description=(
        "Set the default PubMed query used by trends_briefing when no topic "
        "is provided. Use PubMed syntax: MeSH terms, [Title/Abstract] tags, "
        "AND/OR/NOT. [Title/Abstract] tags keep matches precise. "
        "Example: '(deep learning) AND (radiology[Title/Abstract])'."
    ),
    annotations={
        "readOnlyHint": False,
        "destructiveHint": False,
        "openWorldHint": False,
        "idempotentHint": True,
    },
)
async def trends_set_pubmed_query(query: str) -> str:
    cfg = _Config.load()
    q = query.strip()
    before_short = (cfg.pubmed_query[:60] + "...") if len(cfg.pubmed_query) > 60 else cfg.pubmed_query
    cfg.pubmed_query = q
    cfg.save()
    after_short = (q[:60] + "...") if len(q) > 60 else q
    return f"✅ pubmed_query: {before_short!r} → {after_short!r}{_restart_hint()}"


@mcp.tool(
    name="trends_set_token",
    description=(
        "Set or clear an optional rate-limit booster token. trends-mcp ONLY "
        "needs read access — when creating these tokens use the MINIMAL scope:\n"
        "  - github: NO scope at all (just authentication for rate limit). "
        "Do NOT use a token with 'repo' scope here.\n"
        "  - hf: read access only.\n"
        "  - ncbi / openfda: API keys (no scope concept).\n"
        "Pass empty string for value to remove a token. "
        "Provider must be one of: github, hf, ncbi, openfda."
    ),
    annotations={
        "readOnlyHint": False,
        "destructiveHint": False,
        "openWorldHint": False,
        "idempotentHint": True,
    },
)
async def trends_set_token(provider: str, value: str) -> str:
    key = _TOKEN_PROVIDERS.get(provider.lower())
    if key is None:
        return (
            f"Error: unknown provider {provider!r}. "
            f"Valid: {sorted(_TOKEN_PROVIDERS)}"
        )
    cfg = _Config.load()
    was_set = cfg.tokens[key] is not None
    if value.strip() == "":
        cfg.tokens[key] = None
        cfg.save()
        return f"✅ {key} cleared (was {'set' if was_set else 'unset'}).{_restart_hint()}"
    cfg.tokens[key] = value.strip()
    cfg.save()
    return f"✅ {key} {'replaced' if was_set else 'set'}.{_restart_hint()}"


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
