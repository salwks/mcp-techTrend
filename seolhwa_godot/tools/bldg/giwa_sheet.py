# 기와 줄 전후 시트(PIL — 창 없이): python3 tools/bldg/giwa_sheet.py → shots/giwa_geometry/*.jpg
import os
from PIL import Image, ImageDraw, ImageFont
import sys
R = 'shots/giwa_geometry/raw'; O = 'shots/giwa_geometry'
T = sys.argv[1] if len(sys.argv) > 1 else 'after'
F = ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc', 26)
FT = ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc', 34)
def sheet(out, title, rows, cw=800, ch=533):
    W = 2 * cw + 24; H = 70 + len(rows) * (ch + 44)
    im = Image.new('RGB', (W, H), (237, 230, 214)); d = ImageDraw.Draw(im)
    d.text((12, 14), title, font=FT, fill=(40, 30, 25))
    for i, cells in enumerate(rows):
        for j, (p, lab) in enumerate(cells):
            x = 8 + j * (cw + 8); y = 70 + i * (ch + 44)
            if os.path.exists(p): im.paste(Image.open(p).convert('RGB').resize((cw, ch)), (x, y + 36))
            d.text((x + 4, y + 4), lab, font=F, fill=(40, 30, 25))
    im.save(out, quality=88); print(out)
L = {'ref': '기준 각 22°·11시', 'low': '낮은 해(스치는 빛)', 'fp': '1인칭 눈높이 1.6m·약 7m', 'corner': '회첨 모퉁이 가까이(8시)', 'hap': '합각·옆 비탈 가까이(8시)'}
for b, ks, nm in [('anchae', ['ref', 'low', 'fp', 'corner'], '안채(중부 1, ㄱ자·회첨)'), ('sarang', ['ref', 'low', 'fp', 'hap'], '사랑채(남부 1, 팔작)')]:
    sheet(f'{O}/{b}_before_after.jpg', f'{nm} — 왼쪽 전(아틀라스 기와) · 오른쪽 후(수키와 줄 + 국가유산청 기와 그림판)',
          [[(f'{R}/{b}_{k}_before.png', '전 · ' + L[k]), (f'{R}/{b}_{k}_{T}.png', '후 · ' + L[k])] for k in ks])
def crop(p, d, d0=34):
    a = Image.open(p).convert('RGB'); W, H = a.size; f = d0 / d; cw, ch = int(W * f), int(H * f)
    o = p.replace('.png', '_crop.png'); a.crop(((W - cw) // 2, (H - ch) // 2, (W + cw) // 2, (H + ch) // 2)).save(o); return o
sheet(f'{O}/anchae_distance.jpg', '안채 거리별(후, 같은 크기로 잘라 키움) — 34m 줄 · 38m 줄 점무늬 + 겉 수키와 빛 띠 · 42·46m 아틀라스 겉(줄 자리 맞춤)',
      [[(crop(f'{R}/anchae_d34_{T}.png', 34), '34m'), (crop(f'{R}/anchae_d38_{T}.png', 38), '38m(32~40m 사이)')], [(crop(f'{R}/anchae_d42_{T}.png', 42), '42m(giwa_lo)'), (crop(f'{R}/anchae_d46_{T}.png', 46), '46m')]])
cl = {3: '3m', 7: '7m', 15: '15m', 30: '30m'}
sheet(f'{O}/closeup_khs_vs_ours.jpg', '가까이 견주기(낮은 해) — 왼쪽 국가유산청 김명관 고택 안채 원본(Blender EEVEE, 같은 각·거리) · 오른쪽 우리 사랑채(남부 1)',
      [[(f'{R}/khs_src_c{d}.png', '원본 ' + cl[d]), (f'{R}/sarang_c{d}_{T}.png', '우리 ' + cl[d])] for d in [3, 7, 15, 30]])
