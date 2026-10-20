#!/usr/bin/env python3
"""전후 비교 시트 spec 만들기: shots/building_rollout/raw/<set>_<id>_<tagA>.png ↔ _<tagB>.png 를 두 칸씩.
   python3 tools/bldg/sheet_pairs.py <spec_out.json> <sheet_name> "<제목>" <tagA> <tagB> id[:라벨] …
   → spec에 시트 하나를 더한다(없으면 만든다). 그다음: godot --path . -s res://tools/bldg/sheet.gd -- --spec=res://<spec_out>"""
import json, sys, os
spec_path, name, title, ta, tb = sys.argv[1:6]
ids = sys.argv[6:]
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
p = os.path.join(root, spec_path)
spec = json.load(open(p)) if os.path.exists(p) else {'sheets': []}
spec['sheets'] = [s for s in spec['sheets'] if not s['out'].endswith('/' + name + '.jpg')]
cells = []
for i in ids:
    k, _, lab = i.partition(':')
    for t in (ta, tb):
        cells.append({'path': f'res://shots/building_rollout/raw/{k}_{t}.png', 'label': f'{lab or k} · {t}'})
spec['sheets'].append({'out': f'res://shots/building_rollout/{name}.jpg', 'title': title, 'cols': 2, 'cw': 960, 'ch': 540, 'cells': cells})
json.dump(spec, open(p, 'w'), ensure_ascii=False, indent=1)
print('spec', p, len(spec['sheets']))
