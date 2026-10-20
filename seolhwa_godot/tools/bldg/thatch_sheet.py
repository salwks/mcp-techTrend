#!/usr/bin/env python3
"""초가 지붕 전후 시트 spec → shots/building_rollout/thatch/sheets_thatch.json (그다음 sheet.gd)"""
import json, os
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
names = [("s1","남부 #1"),("s2","남부 #2"),("s3","남부 #3"),("s4","남부 #4"),("s5","남부 #5"),("s6","남부 #6"),("c1","중부 ㄱ자 #1"),("n1","북부 겹집 #1"),("jumak1","주막 #1"),("j1","제주 #1"),("eave1","처마 가까이 #1"),("eave4","처마 가까이 #4"),("std2","기본 시점 #2")]
cells = []
for k, l in names:
    for t in ("before", "after"):
        cells.append({"path": f"res://shots/building_rollout/thatch/raw/{k}_{t}.png", "label": f"{l} · {'전' if t=='before' else '후'}"})
sh = [{"out": "res://shots/building_rollout/thatch/thatch_a.jpg", "title": "초가 지붕 — 전(왼) · 후(오른): 남부 시드 1~6 (마을 카메라 각 22°)", "cols": 2, "cw": 900, "ch": 600, "cells": cells[:12]},
      {"out": "res://shots/building_rollout/thatch/thatch_b.jpg", "title": "초가 지붕 — 전(왼) · 후(오른): 권역·주막·처마 가까이·기본 시점", "cols": 2, "cw": 900, "ch": 600, "cells": cells[12:]}]
json.dump({"sheets": sh}, open(os.path.join(root, "shots/building_rollout/thatch/sheets_thatch.json"), "w"), ensure_ascii=False, indent=1)
