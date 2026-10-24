# 기와 줄 전후 시트(PIL — 창 없이): python3 tools/bldg/giwa_sheet.py → shots/giwa_geometry/*.jpg
import os
from PIL import Image, ImageDraw, ImageFont
R = 'shots/giwa_geometry/raw'; O = 'shots/giwa_geometry'
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
          [[(f'{R}/{b}_{k}_before.png', '전 · ' + L[k]), (f'{R}/{b}_{k}_after.png', '후 · ' + L[k])] for k in ks])
sheet(f'{O}/anchae_distance.jpg', '안채 거리별(후) — 30m 줄 · 37m 줄 점무늬 사라짐 · 43m 아틀라스 겉(중경 전) · 50m',
      [[(f'{R}/anchae_d30_after.png', '30m'), (f'{R}/anchae_d37_after.png', '37m(32~40m 점무늬)')], [(f'{R}/anchae_d43_after.png', '43m(giwa_lo)'), (f'{R}/anchae_d50_after.png', '50m')]])
