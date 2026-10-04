"""데칼 아틀라스(assets/kit/decals.png) 만들기 — 흰 RGB + 알파 모양, 4×4 칸(칸당 128px).
scripts/region/decals.gd의 KINDS 칸 번호와 같다. 다시 만들기: python3 tools/scenario/make_decal_atlas.py
0 foot(짚신 발자국) 1 paw(범 발자국) 2 blood(핏자국) 3 claw(발톱 긁힘) 4 flour(밀가루 면) 5 scorch(그을림)
6 puddle(물기) 7 hoof(말발굽) 8 rut(수레바퀴 자국, 세로로 이어짐) 9 drag(끌린 자국) 10 mud(진흙) 11 snake(뱀 지나간 자국)
12 shoe(가죽신·갖신 발자국) 13 drip(핏방울·물방울 줄) 14 ash(재 더미) 15 ink(먹물 쏟음)
"""
import math, random
from PIL import Image, ImageDraw, ImageFilter
import os

C = 128; S = 4                     # 칸 크기, 초표본 배율
W = C * 4
img = Image.new("L", (W * S, W * S), 0)
d = ImageDraw.Draw(img)
rnd = random.Random(1870)

def cell(i):
    return (i % 4) * C * S, (i // 4) * C * S

def P(i, x, y):  # 칸 i 안의 0..1 좌표 → 초표본 픽셀
    ox, oy = cell(i)
    return ox + x * C * S, oy + y * C * S

def ell(i, cx, cy, rx, ry, v=255):
    x0, y0 = P(i, cx - rx, cy - ry); x1, y1 = P(i, cx + rx, cy + ry)
    d.ellipse([x0, y0, x1, y1], fill=v)

def blob(i, cx, cy, r, n=64, rough=0.3, v=255, seed=0):
    rr = random.Random(seed)
    pts = []
    ph = [rr.random() * 6.28 for _ in range(4)]
    for k in range(n):
        a = k / n * math.tau
        f = 1 + rough * (0.5 * math.sin(a * 3 + ph[0]) + 0.3 * math.sin(a * 5 + ph[1]) + 0.2 * math.sin(a * 9 + ph[2]))
        pts.append(P(i, cx + math.cos(a) * r * f, cy + math.sin(a) * r * f))
    d.polygon(pts, fill=v)

# 0 짚신 발자국: 앞(위)이 넓은 타원 + 뒤꿈치, 짚 결 줄무늬
ell(0, 0.5, 0.36, 0.15, 0.24, 230)
ell(0, 0.5, 0.7, 0.12, 0.16, 230)
for k in range(9):   # 짚 결(발바닥 안쪽만 — 타원 폭에 맞춰 줄인다)
    y = 0.16 + k * 0.075
    hw = 0.13 if y < 0.55 else 0.1
    x0, y0 = P(0, 0.5 - hw, y); x1, y1 = P(0, 0.5 + hw, y + 0.012)
    d.rectangle([x0, y0, x1, y1], fill=160)
# 1 범 발자국: 큰 세 갈래 발바닥 + 발가락 넷
ell(1, 0.5, 0.64, 0.2, 0.15)
ell(1, 0.36, 0.72, 0.08, 0.08); ell(1, 0.64, 0.72, 0.08, 0.08)
for (x, y) in [(0.27, 0.4), (0.41, 0.3), (0.59, 0.3), (0.73, 0.4)]:
    ell(1, x, y, 0.075, 0.095)
# 2 핏자국: 덩이 + 튄 방울
blob(2, 0.48, 0.5, 0.22, rough=0.45, seed=3)
for k in range(14):
    a = rnd.random() * math.tau; r = 0.25 + rnd.random() * 0.2
    ell(2, 0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r, 0.015 + rnd.random() * 0.03, 0.015 + rnd.random() * 0.03)
# 3 발톱 긁힘: 네 줄 비스듬히, 가운데 깊게
for k in range(4):
    x = 0.28 + k * 0.15
    pts = [P(3, x - 0.012, 0.08), P(3, x + 0.012, 0.08), P(3, x + 0.06 + 0.02, 0.92), P(3, x + 0.06 - 0.005, 0.92)]
    d.polygon(pts, fill=255 - k * 15)
# 4 밀가루 면: 부드러운 흰 판 + 알갱이
blob(4, 0.5, 0.5, 0.4, n=64, rough=0.12, v=235, seed=4)
for k in range(400):
    a = rnd.random() * math.tau; r = rnd.random() ** 0.5 * 0.33
    ell(4, 0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r, 0.006, 0.006, rnd.choice([180, 255]))
# 5 그을림: 방사형 그을음(가장자리 들쭉날쭉)
for k in range(12):
    r = 0.46 - k * 0.035
    blob(5, 0.5, 0.5, r, n=64, rough=0.35 - k * 0.02, v=40 + k * 18, seed=50 + k)
# 6 물기: 부드러운 얼룩
blob(6, 0.5, 0.5, 0.4, n=64, rough=0.25, v=200, seed=6)
blob(6, 0.46, 0.52, 0.3, n=64, rough=0.3, v=255, seed=7)
# 7 말발굽: U자
ell(7, 0.5, 0.52, 0.3, 0.32)
ell(7, 0.5, 0.62, 0.14, 0.22, 0)
x0, y0 = P(7, 0.42, 0.62); x1, y1 = P(7, 0.58, 0.9)
d.rectangle([x0, y0, x1, y1], fill=0)
# 8 수레바퀴 자국: 세로 띠(위·아래 이어짐), 가장자리 흙
x0, y0 = P(8, 0.38, 0.0); x1, y1 = P(8, 0.62, 1.0)
d.rectangle([x0, y0, x1, y1], fill=190)
x0, y0 = P(8, 0.43, 0.0); x1, y1 = P(8, 0.57, 1.0)
d.rectangle([x0, y0, x1, y1], fill=255)
# 9 끌린 자국: 넓은 띠 + 줄
x0, y0 = P(9, 0.3, 0.02); x1, y1 = P(9, 0.7, 0.98)
d.rectangle([x0, y0, x1, y1], fill=120)
for k in range(6):
    x = 0.32 + k * 0.07
    x0, y0 = P(9, x, 0.02); x1, y1 = P(9, x + 0.015, 0.98)
    d.rectangle([x0, y0, x1, y1], fill=230)
# 10 진흙 덩이
blob(10, 0.5, 0.5, 0.36, n=64, rough=0.4, seed=10)
for k in range(6):
    a = rnd.random() * math.tau
    ell(10, 0.5 + math.cos(a) * 0.38, 0.5 + math.sin(a) * 0.38, 0.04, 0.035)
# 11 뱀 자국: S자 띠
pts = []
for k in range(40):
    t = k / 39
    pts.append((0.5 + 0.22 * math.sin(t * math.tau * 1.2), 0.04 + t * 0.92))
for k in range(len(pts) - 1):
    a = P(11, *pts[k]); b = P(11, *pts[k + 1])
    d.line([a, b], fill=255, width=int(0.075 * C * S))
# 12 가죽신 발자국: 좁고 앞이 뾰족(코), 굽 자국
d.polygon([P(12, 0.5, 0.08), P(12, 0.62, 0.22), P(12, 0.63, 0.55), P(12, 0.58, 0.9), P(12, 0.42, 0.9), P(12, 0.37, 0.55), P(12, 0.38, 0.22)], fill=230)
x0, y0 = P(12, 0.4, 0.58); x1, y1 = P(12, 0.6, 0.62)
d.rectangle([x0, y0, x1, y1], fill=120)
# 13 방울 줄: 세로로 떨어진 방울
for k in range(7):
    y = 0.08 + k * 0.13 + rnd.random() * 0.03
    r = 0.025 + rnd.random() * 0.03
    ell(13, 0.5 + (rnd.random() - 0.5) * 0.12, y, r, r * 1.2)
# 14 재 더미: 거친 회색 얼룩
blob(14, 0.5, 0.5, 0.38, n=64, rough=0.3, v=160, seed=14)
for k in range(260):
    a = rnd.random() * math.tau; r = rnd.random() ** 0.5 * 0.3
    ell(14, 0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r, 0.008, 0.008, rnd.choice([90, 255]))
# 15 먹물 쏟음: 흘러 퍼진 웅덩이 + 줄기
blob(15, 0.42, 0.42, 0.24, n=64, rough=0.35, seed=15)
blob(15, 0.62, 0.66, 0.14, n=64, rough=0.4, seed=16)
d.line([P(15, 0.45, 0.45), P(15, 0.66, 0.7)], fill=255, width=int(0.1 * C * S))

img = img.filter(ImageFilter.GaussianBlur(S * 0.8)).resize((W, W), Image.LANCZOS)
out = Image.new("RGBA", (W, W), (255, 255, 255, 0))
out.putalpha(img)
path = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "kit", "decals.png")
out.save(os.path.abspath(path))
print("saved", os.path.abspath(path))
