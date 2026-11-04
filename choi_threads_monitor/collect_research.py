#!/usr/bin/env python3
"""Collect Hugging Face Daily Papers once near noon KST for previous business day.

No lab RSS, arXiv, or OpenAlex API requests. Keep the source-date HF
snapshot strictly separate from the general-news data outputs.
"""
import datetime as dt
import json
import urllib.parse
import urllib.request
from pathlib import Path

DATA = Path(__file__).resolve().parent / "data"
TODAY_JSON = DATA / "hf_daily_today.json"
TODAY_MD = DATA / "hf_daily_today.md"
KST = dt.timezone(dt.timedelta(hours=9))
UA = "DailyAINewsHuggingFaceMonitor/1.0"


def get(url):
    request = urllib.request.Request(
        url, headers={"User-Agent": UA, "Accept": "application/json"}
    )
    with urllib.request.urlopen(request, timeout=35) as response:
        return response.read()


def utc(value):
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(str(value).replace("Z", "+00:00")).astimezone(
            dt.timezone.utc
        ).isoformat().replace("+00:00", "Z")
    except (ValueError, TypeError):
        return None


def collect_daily(date):
    result = {}
    for page in range(20):
        params = urllib.parse.urlencode(
            {"date": date, "p": page, "limit": 100, "sort": "publishedAt"}
        )
        rows = json.loads(get("https://huggingface.co/api/daily_papers?" + params))
        if not isinstance(rows, list):
            raise ValueError("Unexpected Hugging Face Daily Papers response")
        for item in rows:
            if not isinstance(item, dict):
                continue
            p = item.get("paper") or item
            pid = p.get("id") or p.get("paperId")
            if not pid:
                continue
            record = {
                "id": "hf:" + str(pid),
                "source": "hf_daily_papers",
                "type": "paper",
                "daily_papers_date": date,
                "title": p.get("title") or item.get("title"),
                "url": "https://huggingface.co/papers/" + str(pid),
                "arxiv_url": "https://arxiv.org/abs/" + str(pid),
                "published_at": utc(p.get("publishedAt") or item.get("publishedAt")),
                "summary": (p.get("summary") or "")[:3200],
                "upvotes": p.get("upvotes", item.get("upvotes", 0)),
                "comments": p.get("numComments", item.get("numComments", 0)),
                "has_code": bool(p.get("githubRepo") or p.get("repository")),
                "project_page": p.get("projectPage"),
                "signals": ["huggingface_daily_papers"],
            }
            if not record["title"]:
                continue
            result[record["id"]] = record
        if len(rows) < 100:
            break
    else:
        raise ValueError("Hugging Face daily pagination exceeded 20 pages")
    if not result:
        raise ValueError("No Hugging Face Daily Papers; old snapshot preserved")
    return list(result.values())


def write_json(path, data):
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def main():
    now = dt.datetime.now(dt.timezone.utc)
    # The Hugging Face Daily Papers list is not guaranteed to be complete
    # for today's KST date at local noon. Report the previous business day.
    local_date = now.astimezone(KST).date()
    date = local_date - dt.timedelta(days=1)
    while date.weekday() >= 5:
        date -= dt.timedelta(days=1)
    stamp = now.isoformat().replace("+00:00", "Z")

    # Fetch and validate first. An API failure must not erase saved papers.
    current = collect_daily(date.isoformat())
    try:
        old = json.loads(TODAY_JSON.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        old = {"items": []}
    previously = {
        x["id"]: x
        for x in old.get("items", [])
        if isinstance(x, dict)
        and x.get("source") == "hf_daily_papers"
        and x.get("id")
    }
    seen = 0
    for paper in current:
        old_item = previously.get(paper["id"], {})
        paper["first_seen_at"] = old_item.get("first_seen_at", stamp)
        paper["last_seen_at"] = stamp
        if paper["id"] not in previously:
            seen += 1
        previously[paper["id"]] = paper

    oldest_date = (date - dt.timedelta(days=6)).isoformat()
    kept = [
        x
        for x in previously.values()
        if x.get("daily_papers_date")
        and oldest_date <= x["daily_papers_date"] <= date.isoformat()
    ]
    kept.sort(key=lambda x: (x.get("published_at") or "", x["id"]), reverse=True)
    todays = [x for x in kept if x.get("daily_papers_date") == date.isoformat()]
    todays.sort(key=lambda x: (x.get("upvotes") or 0, x["id"]), reverse=True)
    if len(todays) != len(current):
        raise ValueError("Target paper list count differs from fetched unique IDs")

    # Write only Hugging Face Daily Papers files, not shared news state.
    DATA.mkdir(parents=True, exist_ok=True)
    write_json(
        TODAY_JSON,
        {"date": date.isoformat(), "items_count": len(todays), "items": todays},
    )
    md = ["# Hugging Face Daily Papers — " + date.isoformat(), "",
          "Total: " + str(len(todays)), ""]
    for i, x in enumerate(todays, 1):
        md.extend([
            "### " + str(i) + ". " + x["title"],
            "Paper: " + x["url"],
            "Upvotes: " + str(x.get("upvotes") or 0),
            "",
            str(x.get("summary") or "(No abstract supplied)"),
            "",
        ])
    TODAY_MD.write_text("\n".join(md) + "\n", encoding="utf-8")
    print(json.dumps({"date": date.isoformat(), "papers": len(todays),
                      "new": seen, "retained": len(todays)}))


if __name__ == "__main__":
    main()
