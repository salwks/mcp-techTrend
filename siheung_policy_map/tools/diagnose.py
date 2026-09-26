#!/usr/bin/env python3
"""게시판 마크업 진단용: 페이지 이동 방식과 게시물 행 구조를 출력한다."""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import collect  # noqa: E402

KEY = re.compile(r"(?:bIdx|notAncmtMgtNo)=(\d+)")
for src in json.loads(collect.SOURCES_FILE.read_text(encoding="utf-8")):
    try:
        html = collect.fetch(src["url"])
    except Exception as e:  # noqa: BLE001
        print(f"===== {src['id']} FAILED: {e}")
        continue
    first = KEY.findall(html)[:3]
    print(f"===== {src['id']} page1 ids={first}")
    for m in re.findall(r"<form\b[^>]*>", html):
        print("FORM:", m[:300])
    for m in re.findall(r"<input\b[^>]*>", html):
        if re.search(r"page|Page|idx|Idx|mId", m):
            print("INPUT:", m[:200])
    for m in re.findall(r"<script\b[^>]*src=[^>]*>", html):
        print("SCRIPT:", m[:200])
    for m in re.finditer(r"goPage\s*=?\s*function|function\s+goPage[^{]*\{[^}]{0,400}", html):
        print("JS:", re.sub(r"\s+", " ", m.group(0)))
    for param in ["pageIndex", "page", "cp", "currentPage", "pageNo", "curPage", "nowPage", "pageNum"]:
        sep = "&" if "?" in src["url"] else "?"
        try:
            ids = KEY.findall(collect.fetch(f"{src['url']}{sep}{param}=2"))[:3]
        except Exception as e:  # noqa: BLE001
            ids = [f"ERR {e}"]
        print(f"PARAM {param}=2 ids={ids} {'<-- differs' if ids and ids != first else ''}")
    rows = collect.parse_list(html, src["url"], src)
    for r in rows[:3]:
        print("PARSED:", r)
    if rows and rows[0]["url"]:
        try:
            body = collect.extract_body(collect.fetch(rows[0]["url"]), rows[0]["title"])
            print("BODY(GET):", body[:300])
        except Exception as e:  # noqa: BLE001
            print("BODY(GET) FAILED:", e)
