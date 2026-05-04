"""Live smoke test of every tool. Prints PASS/FAIL per tool with first 200 chars
of output (or full error) so we can catch silent failures."""
import asyncio
import sys
import traceback

import trends_mcp as t


async def run(label, coro):
    try:
        out = await coro
    except Exception as e:
        print(f"❌ FAIL  {label}")
        print(f"   {type(e).__name__}: {e}")
        traceback.print_exc(limit=2)
        return False
    if not isinstance(out, str):
        print(f"❌ FAIL  {label}  (non-string return: {type(out).__name__})")
        return False
    if out.startswith("Error"):
        print(f"⚠️  ERR   {label}")
        print(f"   {out[:300]}")
        return False
    # Heuristic: a healthy markdown response should have a header and not be empty.
    if len(out) < 50:
        print(f"⚠️  THIN  {label} ({len(out)} chars)")
        print(f"   {out!r}")
        return False
    first_line = out.splitlines()[0] if out else ""
    print(f"✅ PASS  {label}  ({len(out):>5} chars · {first_line[:80]})")
    return True


async def main():
    results = []

    # --- arxiv ---
    results.append(await run(
        "arxiv_recent(cs.HC, 7d, 3)",
        t.arxiv_recent(category="cs.HC", days=7, max_results=3),
    ))
    results.append(await run(
        "arxiv_search('medical imaging', 3)",
        t.arxiv_search(query="medical imaging", max_results=3),
    ))
    results.append(await run(
        "arxiv_search('medical imaging', days=14, 3)",
        t.arxiv_search(query="medical imaging", days=14, max_results=3),
    ))

    # --- pubmed ---
    results.append(await run(
        "pubmed_search('mammography deep learning', 30d, 3)",
        t.pubmed_search(query="mammography deep learning", days=30, max_results=3),
    ))

    # --- pwc ---
    results.append(await run(
        "paperswithcode_trending('diffusion', 3)",
        t.paperswithcode_trending(query="diffusion", max_results=3),
    ))
    results.append(await run(
        "paperswithcode_trending('diffusion', days=30, 3)",
        t.paperswithcode_trending(query="diffusion", days=30, max_results=3),
    ))

    # --- github ---
    results.append(await run(
        "github_trending(weekly, 5)",
        t.github_trending(since="weekly", max_results=5),
    ))
    results.append(await run(
        "github_trending(python, daily, 5)",
        t.github_trending(language="python", since="daily", max_results=5),
    ))
    results.append(await run(
        "github_search('medical imaging', days=30, 3)",
        t.github_search(query="medical imaging", days=30, max_results=3),
    ))

    # --- huggingface ---
    results.append(await run(
        "huggingface_trending(models, trending, 3)",
        t.huggingface_trending(kind="models", sort="trending", max_results=3),
    ))
    results.append(await run(
        "huggingface_trending(datasets, recent, days=30, 3)",
        t.huggingface_trending(kind="datasets", sort="recent", days=30, max_results=3),
    ))
    results.append(await run(
        "huggingface_trending(spaces, trending, 3)",
        t.huggingface_trending(kind="spaces", sort="trending", max_results=3),
    ))

    # --- openFDA ---
    results.append(await run(
        "fda_510k_recent(days=180, 3)",
        t.fda_510k_recent(days=180, max_results=3),
    ))
    results.append(await run(
        "fda_510k_recent('device_name:mammo*', 365d, 3)",
        t.fda_510k_recent(query="device_name:mammo*", days=365, max_results=3),
    ))
    results.append(await run(
        "fda_recalls_recent(90d, 3)",
        t.fda_recalls_recent(days=90, max_results=3),
    ))
    results.append(await run(
        "fda_recalls_recent(class_level=1, 180d)",
        t.fda_recalls_recent(class_level="1", days=180, max_results=3),
    ))

    # --- aggregators ---
    results.append(await run(
        "trends_digest('medical imaging AI', 3, 14d)",
        t.trends_digest(topic="medical imaging AI", per_source_limit=3, days=14),
    ))
    results.append(await run(
        "trends_briefing(7d, 2)",
        t.trends_briefing(days=7, per_source_limit=2),
    ))
    results.append(await run(
        "trends_briefing(7d, 2, topic='medical imaging')",
        t.trends_briefing(days=7, per_source_limit=2, topic="medical imaging"),
    ))

    print()
    passed = sum(results)
    total = len(results)
    print(f"=== {passed}/{total} passed ===")
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
