"""게임 안 지도 그림 — 한지 바탕 + 먹빛 산 음영 + 물길 + 길(고지도 느낌). 이름표는 Godot이 그린다.
사용: python3 tools/region/render_map.py <권역 id>  → region_data/<권역 id>/map.png, map.json(그림↔게임 좌표)
"""
import json, os
import numpy as np
import common as C
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
D = C.OUT
SCALE = 4.0  # 그림 1px = 게임 4m

reg = json.load(open(os.path.join(D, 'region.json')))
hm = reg['height']
h16 = np.array(Image.open(os.path.join(D, hm['file'])), dtype=np.float32)
y = hm['y_min'] + h16 / 65535.0 * (hm['y_max'] - hm['y_min'])
step = int(round(SCALE / hm['cell']))
y = y[::step, ::step]
H, W = y.shape
x0, z0 = hm['x0'], hm['z0']

# 음영: 북서에서 빛
gy, gx = np.gradient(y, SCALE)
slope = np.hypot(gx, gy)
shade = np.clip((-gx * 0.7 + gy * 0.7) / (slope + 1e-3) * np.minimum(slope * 2.0, 1.0), -1, 1)
alt = (y - y.min()) / (y.max() - y.min())

paper = np.array([241, 233, 214], np.float32)
ink = np.array([60, 52, 44], np.float32)
green = np.array([196, 204, 168], np.float32)
img = np.empty((H, W, 3), np.float32)
lowland = np.clip(1.0 - alt * 3.0, 0, 1)[..., None]           # 들판은 옅은 풀빛
img[:] = paper * (1 - lowland * 0.35) + green * lowland * 0.35
tone = (np.clip(alt * 1.4, 0, 1) * 0.25 + np.clip(-shade, 0, 1) * 0.35 * np.clip(slope * 3, 0, 1))[..., None]
img = img * (1 - tone) + ink * tone
img = img + np.clip(shade, 0, 1)[..., None] * 10

pil = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
dr = ImageDraw.Draw(pil)

def px(x, z):
    return ((x - x0) / SCALE, (z - z0) / SCALE)

for r in reg.get('rivers', []):
    pts = [px(p[0], p[1]) for p in r['points']]
    w = {'S': 6, 'A': 5, 'B': 4, 'C': 2, 'D': 1}.get(r.get('grade', 'D'), 1)
    if len(pts) > 1: dr.line(pts, fill=(96, 128, 140), width=w, joint='curve')
for r in reg.get('roads', []):
    pts = [px(p[0], p[1]) for p in r['points']]
    w = {'대로': 3, '지선': 2}.get(r.get('class', ''), 1)
    if len(pts) > 1: dr.line(pts, fill=(150, 70, 52), width=w, joint='curve')

# 테두리
dr.rectangle([0, 0, W - 1, H - 1], outline=(60, 52, 44), width=4)
pil.save(os.path.join(D, 'map.png'), optimize=True)
json.dump({'file': 'map.png', 'x0': x0, 'z0': z0, 'scale': SCALE, 'w': W, 'h': H},
          open(os.path.join(D, 'map.json'), 'w'), ensure_ascii=False)
print('map', W, H, os.path.getsize(os.path.join(D, 'map.png')) // 1024, 'KB')
