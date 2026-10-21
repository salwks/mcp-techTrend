#!/usr/bin/env python3
"""⑤ 폐가 단계 시트 spec → shots/building_rollout/ruin/sheets_ruin.json (그다음 sheet.gd). 줄 = 유형, 칸 = 단계 0~4"""
import json, os
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
R = 'res://shots/building_rollout/ruin/raw/'
T = [('choga', '초가(남부)'), ('anchae', '기와 안채(중부 ㄱ자)'), ('gotgan', '곳간'), ('chogahouse', '초가 묶음'), ('giwahouse', '읍내 기와집 묶음'), ('choga', '초가 가까이')]
S = ['0 막 비운 집', '1 몇 해', '2 반쯤 무너짐', '3 무너짐', '4 터만 남음']
cells = []
for i, (k, l) in enumerate(T):
    v = 'close' if i == 5 else 'town'
    for st in range(5):
        cells.append({'path': R + f'{k}_s{st}_{v}.png', 'label': f'{l} · {S[st]}'})
extra = json.load(open(os.path.join(root, 'shots/building_rollout/ruin/walk_cells.json'))) if os.path.exists(os.path.join(root, 'shots/building_rollout/ruin/walk_cells.json')) else []
sh = [{'out': 'res://shots/building_rollout/ruin/ruin_stages.jpg', 'title': '⑤ 폐가 옵션(ruin) — 단계 0~4 × 초가·기와 안채·곳간·초가 묶음·기와집 묶음 (마을 카메라 각) + 초가 가까이', 'cols': 5, 'cw': 600, 'ch': 400, 'cells': cells}]
if extra: sh.append({'out': 'res://shots/building_rollout/ruin/ruin_walkin.jpg', 'title': '⑤ 폐가 — 게임 안 마을 카메라 · 대문 → 마당 → 방 1인칭(단계별)', 'cols': 4, 'cw': 640, 'ch': 360, 'cells': extra})
json.dump({'sheets': sh}, open(os.path.join(root, 'shots/building_rollout/ruin/sheets_ruin.json'), 'w'), ensure_ascii=False, indent=1)
