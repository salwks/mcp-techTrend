#!/usr/bin/env python3
"""③ 고을 배치 틀 시트 spec → shots/building_rollout/town/sheets_town.json (그다음 sheet.gd)"""
import json, os
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
R = 'res://shots/building_rollout/raw/'
T = {'market': '장터', 'alley': '골목(서민)', 'alley_mid': '골목(중인)', 'jumak': '주막거리', 'gwana': '관아', 'well': '우물 블록'}
sheets = []
over = []; street = []
for k, l in T.items():
    over += [{'path': R + f'town_{k}_o_gal.png', 'label': f'{l} · 내려다보기'}, {'path': R + f'town_{k}_t_gal.png', 'label': f'{l} · 마을 카메라'}]
    for i in (1, 2, 3):
        for v, vl in (('town', '걷기 마을 카메라'), ('fp', '걷기 1인칭')):
            p = R + f'town_{k}_{i}_{v}_gal.png'
            if os.path.exists(os.path.join(root, p[6:])): street.append({'path': p, 'label': f'{l} · {vl} {i}'})
sheets.append({'out': 'res://shots/building_rollout/town/town_templates.jpg', 'title': '③ 고을 배치 틀 견본 — 내려다보기 · 마을 카메라', 'cols': 2, 'cw': 960, 'ch': 540, 'cells': over})
sheets.append({'out': 'res://shots/building_rollout/town/town_streets.jpg', 'title': '③ 고을 배치 틀 — 길 걷기(마을 카메라 · 1인칭)', 'cols': 4, 'cw': 640, 'ch': 360, 'cells': street})
W = [('west_t1', '장터길 북'), ('west_t2', '장터길 가운데'), ('west_t3', '장터길 남'), ('west_t4', '오솔길 어귀'), ('west_t5', '오솔길 서쪽'), ('west_t6', '북쪽 안 골목'), ('west_o1', '내려다보기'), ('west_lane_2_town', '장터길 걷기'), ('west_path_1_town', '오솔길 걷기'), ('west_path_2_town', '오솔길 걷기 2'), ('west_f1', '1인칭 장터길에서 서쪽'), ('west_f3', '1인칭 오솔길')]
cells = []
for k, l in W:
    for t, tl in (('after', '1단계(대문 남향)'), ('step3', '3단계(대문 길 쪽)')):
        cells.append({'path': R + f'{k}_{t}.png', 'label': f'{l} · {tl}'})
sheets.append({'out': 'res://shots/building_rollout/town/west_gates.jpg', 'title': '③ 남원 서문 밖 구역 — 대문을 길·골목 쪽으로(왼 1단계 · 오른 3단계)', 'cols': 2, 'cw': 960, 'ch': 540, 'cells': cells})
os.makedirs(os.path.join(root, 'shots/building_rollout/town'), exist_ok=True)
json.dump({'sheets': sheets}, open(os.path.join(root, 'shots/building_rollout/town/sheets_town.json'), 'w'), ensure_ascii=False, indent=1)
