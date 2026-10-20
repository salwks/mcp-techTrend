#!/usr/bin/env python3
"""rollout.gd가 적은 바뀐 항목(tools/bldg/rollout_<구역>.json)을 placement_namwon.json에 id로 끼워 넣는다(원본 형식 유지: indent=1, ensure_ascii=False)."""
import json, sys, os
here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, '..', '..'))
district = sys.argv[1] if len(sys.argv) > 1 else 'west'
ch = json.load(open(os.path.join(here, f'rollout_{district}.json')))
path = os.path.join(root, 'region_data/JL_NAMWON_UNBONG/placement_namwon.json')
d = json.load(open(path))
def clean(v, key=''):
    # Godot JSON은 수를 모두 실수로 읽는다 → 시드·개수는 정수로, float32 꼬리(16.7999992)는 4자리로
    if isinstance(v, dict): return {k: clean(x, k) for k, x in v.items()}
    if isinstance(v, list): return [clean(x, key) for x in v]
    if isinstance(v, float):
        if key in ('seed', 'n', 'tiers', 'rows') and v == int(v): return int(v)
        return round(v, 4)
    return v
by = {it['id']: clean(it) for it in ch['items']}
n = 0
for i, it in enumerate(d['items']):
    if it['id'] in by:
        new = by[it['id']]
        keep = dict(it)
        new.pop('reverted', None)
        for k in ('kit', 'params', 'footprint', 'was', 'rollout', 'ry', 'x', 'z'):
            if k in new: keep[k] = new[k]
            elif k in keep and k in ('was', 'rollout'): del keep[k]
        d['items'][i] = keep
        n += 1
with open(path, 'w') as f:
    json.dump(d, f, ensure_ascii=False, indent=1)
print(f'ROLLOUT_APPLY {district} items={n}')
