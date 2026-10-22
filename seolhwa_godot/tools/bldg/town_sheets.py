#!/usr/bin/env python3
"""town-organic 전·후 시트 명세 → tools/bldg/sheet.gd(창 필요)
   python3 tools/bldg/town_sheets.py west eup > /tmp/spec.json; godot --path . -s res://tools/bldg/sheet.gd -- --spec=/tmp/spec.json"""
import json, sys, os
here = os.path.dirname(os.path.abspath(__file__)); root = os.path.abspath(os.path.join(here, '..', '..'))
V = json.load(open(os.path.join(here, 'town_views.json')))
raw = 'res://shots/town_organic/raw/'
sheets = []
for dn in sys.argv[1:]:
    if dn not in ('west', 'eup'):
        # 도시·마을 빌더 견본: 전이 없다 — 한 장에 내려다보기 3 + 마을 카메라 + 1인칭
        vs = V['sets'][dn]['views']
        cells = []
        for v in vs:
            p = '%s%s_%s_after.png' % (raw, dn, v['id'])
            if os.path.exists(os.path.join(root, p[6:])): cells.append(dict(path=p, label=v['label']))
        sheets.append(dict(out='res://shots/town_organic/settle_%s.jpg' % dn, title='도시·마을 빌더 견본 — %s' % V['sets'][dn].get('label', dn), cols=3, cw=640, ch=360, cells=cells))
        continue
    vs = V['sets'][dn]['views']
    def pairs(ids):
        cells = []
        for v in vs:
            if v['id'] in ids:
                for tag, lab in (('before', '전'), ('after', '후')):
                    p = '%s%s_%s_%s.png' % (raw, dn if tag == 'after' else dn + '_before', v['id'], tag)
                    if os.path.exists(os.path.join(root, p[6:])): cells.append(dict(path=p, label='%s · %s' % (v['label'], lab)))
        return cells
    town = [v['id'] for v in vs if v['mode'] == 'town']
    sheets.append(dict(out='res://shots/town_organic/%s_town_a.jpg' % dn, title='고을 짜임 %s — 마을 카메라(22°·×0.64) 전 ↔ 후' % dn, cols=2, cells=pairs(town[:5])))
    sheets.append(dict(out='res://shots/town_organic/%s_town_b.jpg' % dn, title='고을 짜임 %s — 마을 카메라(길 위) 전 ↔ 후' % dn, cols=2, cells=pairs(town[5:])))
    sheets.append(dict(out='res://shots/town_organic/%s_over.jpg' % dn, title='고을 짜임 %s — 내려다보기 · 참고 그림 각(동남 28°) · 남쪽 34° 전 ↔ 후' % dn, cols=2, cells=pairs(['o1', 'o2', 'o3', 'r1', 'r5'])))
    sheets.append(dict(out='res://shots/town_organic/%s_std_fp.jpg' % dn, title='고을 짜임 %s — 기본 카메라(40°) · 1인칭(길 걷기) 전 ↔ 후' % dn, cols=2, cells=pairs([v['id'] for v in vs if v['mode'] in ('std', 'fp')])))
print(json.dumps(dict(sheets=sheets), ensure_ascii=False, indent=1))
