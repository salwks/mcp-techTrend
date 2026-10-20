#!/usr/bin/env python3
"""④ 먼 산 전후 시트 spec → shots/building_rollout/mountains/sheets_mtn.json (그다음 sheet.gd)"""
import json, os
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
R = 'res://shots/building_rollout/raw/'
V = [('fp_gh', '1인칭 광한루 앞 → 북(읍성 뒤 진산)'), ('fp_n', '1인칭 읍성 안 → 북'), ('fp_nw', '1인칭 읍성 안 → 서북(교룡산 쪽)'), ('fp_s', '1인칭 읍성 안 → 남(요천·안산)'), ('fp_e', '1인칭 동문 밖 → 동'), ('fp_w', '1인칭 서문 밖 → 서'), ('low_s', '낮은 원경 남 → 북'), ('low_e', '낮은 원경 동 → 서'), ('town_c', '마을 카메라 읍성 안'), ('town_w', '마을 카메라 서문 밖'), ('std_c', '기본 카메라 읍성 안')]
cells = []
for k, l in V:
    for t, tl in (('before', '전'), ('after', '후')):
        cells.append({'path': R + f'mtn_{k}_{t}.png', 'label': f'{l} · {tl}'})
os.makedirs(os.path.join(root, 'shots/building_rollout/mountains'), exist_ok=True)
sh = [{'out': 'res://shots/building_rollout/mountains/mountains_fp.jpg', 'title': '④ 남원 먼 산(배산임수) — 1인칭 · 낮은 원경 전(왼) · 후(오른)', 'cols': 2, 'cw': 960, 'ch': 540, 'cells': cells[:16]},
      {'out': 'res://shots/building_rollout/mountains/mountains_cams.jpg', 'title': '④ 먼 산 — 마을 카메라(22°) · 기본 카메라(40°): 화면 위 끝이 지평선 아래라 먼 산이 들지 않는다(그대로임을 확인)', 'cols': 2, 'cw': 960, 'ch': 540, 'cells': cells[16:]}]
json.dump({'sheets': sh}, open(os.path.join(root, 'shots/building_rollout/mountains/sheets_mtn.json'), 'w'), ensure_ascii=False, indent=1)
