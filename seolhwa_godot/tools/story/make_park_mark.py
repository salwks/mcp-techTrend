"""박규상 객주 `朴` 표식 아틀라스(시나리오 v2.2) — assets/story/park_mark.png (512×256).
같은 그래픽 언어(붉은 백문 인장 + 한지·삼베)를 네 칸에 둔다. kit/story/park_mark.gd가 칸을 골라 쓴다.
  A (0,0)-(128,128)   작은 인장
  B (128,0)-(256,256) 반쯤 찢긴 납품표(納品 紙二十束 墨十丁 朴奎祥客主 + 인장) — 한양 S1002
  C (256,0)-(384,128) 곡물 자루·포장 표식(삼베 + 찍힌 인장) — R0104 천안삼거리, 뒤 사건의 창고
  D (384,0)-(512,256) 운송장 한 칸(運送 米百石 + 인장) — 평양 S5004 등 뒤 사건용
실행: python3 tools/story/make_park_mark.py (macOS AppleMyungjo 글꼴, Pillow)
"""
import os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONT = '/System/Library/Fonts/Supplemental/AppleMyungjo.ttf'
SEAL = (178, 52, 40)
random.seed(7)

def font(sz): return ImageFont.truetype(FONT, sz)

def seal(img, cx, cy, s, rot=0, alpha=255):
    t = Image.new('RGBA', (s, s), (0, 0, 0, 0)); d = ImageDraw.Draw(t)
    d.rounded_rectangle([1, 1, s - 2, s - 2], radius=max(2, s // 10), fill=SEAL + (alpha,))
    f = font(int(s * 0.78)); bb = d.textbbox((0, 0), '朴', font=f)
    d.text(((s - (bb[2] - bb[0])) / 2 - bb[0], (s - (bb[3] - bb[1])) / 2 - bb[1]), '朴', font=f, fill=(0, 0, 0, 0))  # 백문(글자가 비어 바탕이 보임)
    px = t.load()
    for _ in range(int(s * s * 0.06)):   # 인주가 덜 묻은 자리
        x = random.randrange(s); y = random.randrange(s)
        if px[x, y][3] > 0: px[x, y] = (0, 0, 0, 0)
    t = t.rotate(rot, resample=Image.BICUBIC)
    img.alpha_composite(t, (int(cx - s / 2), int(cy - s / 2)))

def column(d, x, y, txt, f, step):
    for i, ch in enumerate(txt): d.text((x, y + i * step), ch, font=f, fill=(40, 34, 30, 255))

im = Image.new('RGBA', (512, 256), (0, 0, 0, 0))
seal(im, 64, 64, 104)
# B 납품표
p = Image.new('RGBA', (128, 256), (236, 226, 200, 255)); d = ImageDraw.Draw(p)
for y in range(0, 256, 15): d.line([(0, y), (127, y)], fill=(226, 214, 186, 255))
f = font(19)
column(d, 96, 62, '納品', f, 22); column(d, 70, 62, '紙二十束', f, 22); column(d, 44, 62, '墨十丁', f, 22); column(d, 14, 62, '朴奎祥客主', f, 22)
seal(p, 64, 228, 40, rot=-6)
mask = Image.new('L', (128, 256), 255); md = ImageDraw.Draw(mask)
pts = [(0, 0)]; x = 0
while x < 128: pts.append((x, random.randint(26, 54))); x += random.randint(5, 11)
pts += [(128, 40), (128, 0)]
md.polygon(pts, fill=0); p.putalpha(mask)
im.alpha_composite(p, (128, 0))
# C 자루·포장
c = Image.new('RGBA', (128, 128), (186, 164, 118, 255)); d = ImageDraw.Draw(c)
for i in range(0, 128, 4):
    d.line([(i, 0), (i, 127)], fill=(172, 150, 104, 255)); d.line([(0, i), (127, i)], fill=(176, 154, 108, 255))
c = c.filter(ImageFilter.SMOOTH)
seal(c, 64, 62, 70, rot=8, alpha=230)
im.alpha_composite(c, (256, 0))
# D 운송장
q = Image.new('RGBA', (128, 256), (232, 222, 196, 255)); d = ImageDraw.Draw(q)
for x in range(16, 128, 22): d.line([(x, 10), (x, 246)], fill=(150, 60, 50, 160), width=1)
f2 = font(17)
column(d, 98, 20, '運送', f2, 19); column(d, 54, 30, '米百石', f2, 19)
seal(q, 62, 200, 34, rot=4)
im.alpha_composite(q, (384, 0))
out = os.path.join(ROOT, 'assets', 'story', 'park_mark.png')
os.makedirs(os.path.dirname(out), exist_ok=True)
im.save(out)
print('wrote', out)
