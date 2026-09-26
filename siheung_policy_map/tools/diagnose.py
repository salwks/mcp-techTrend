#!/usr/bin/env python3
"""게시판 마크업 진단용: 목록 페이지에서 게시물 링크와 페이지 이동 링크의 원본 HTML을 출력한다."""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import collect  # noqa: E402

for src in json.loads(collect.SOURCES_FILE.read_text(encoding="utf-8")):
    html = collect.fetch(src["url"])
    print(f"===== {src['id']} {src['url']} ({len(html)} bytes)")
    anchors = re.findall(r"<a\b[^>]*>", html)
    for a in anchors:
        if re.search(r"view|onclick|bIdx|page|Page", a):
            print("A:", a[:300])
    for m in re.finditer(r"<(tr|li)\b[^>]*>(?:(?!</\1>).){0,1500}?20\d\d[-.]\d\d[-.]\d\d", html, re.S):
        print("ROW:", re.sub(r"\s+", " ", m.group(0))[:700])
        break
    for m in re.finditer(r"function\s+\w*(?:view|View|page|Page|link|Link)\w*\s*\([^)]*\)\s*\{[^}]{0,400}", html):
        print("JS:", re.sub(r"\s+", " ", m.group(0)))
