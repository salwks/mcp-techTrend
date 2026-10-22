# trees-khs 전·후 시트: python3 tools/trees_khs/sheet.py [tag_before] [tag_after] [out_prefix]
#   shots/trees_khs/raw/<set>_<id>_<tag>.png 를 시점마다 한 줄(전 | 후)로 — 4줄씩 sheet_N.jpg
import sys, os, json
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
RAW = os.path.join(ROOT, 'shots/trees_khs/raw')
A = sys.argv[1] if len(sys.argv) > 1 else 'before'
B = sys.argv[2] if len(sys.argv) > 2 else 'after'
PRE = sys.argv[3] if len(sys.argv) > 3 else 'sheet'
views = json.load(open(os.path.join(os.path.dirname(__file__), 'views.json')))['sets']['trees']['views']
W, H = 960, 540
font = None
for f in ['/System/Library/Fonts/AppleSDGothicNeo.ttc', '/System/Library/Fonts/Supplemental/AppleGothic.ttf']:
    if os.path.exists(f): font = ImageFont.truetype(f, 26); break
rows = []
for v in views:
    pa = os.path.join(RAW, 'trees_%s_%s.png' % (v['id'], A)); pb = os.path.join(RAW, 'trees_%s_%s.png' % (v['id'], B))
    if not (os.path.exists(pa) and os.path.exists(pb)): continue
    row = Image.new('RGB', (W * 2, H + 40), (24, 24, 24))
    row.paste(Image.open(pa).convert('RGB').resize((W, H), Image.LANCZOS), (0, 40))
    row.paste(Image.open(pb).convert('RGB').resize((W, H), Image.LANCZOS), (W, 40))
    d = ImageDraw.Draw(row)
    d.text((10, 6), '%s  %s   (전 %s | 후 %s)' % (v['id'], v['label'], A, B), fill=(235, 235, 235), font=font)
    rows.append(row)
out = os.path.join(ROOT, 'shots/trees_khs')
for i in range(0, len(rows), 4):
    part = rows[i:i + 4]
    sh = Image.new('RGB', (W * 2, sum(r.size[1] for r in part)))
    y = 0
    for r in part: sh.paste(r, (0, y)); y += r.size[1]
    p = os.path.join(out, '%s_%d.jpg' % (PRE, i // 4 + 1)); sh.save(p, quality=86); print(p)
