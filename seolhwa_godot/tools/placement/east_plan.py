"""placement-east 평면도: 음영기복 + 토지이용 + 하천 + 도로 + 배치 사각형(footprint, 회전 반영).

render(T, items, bounds, name, cx, cz, half, ppm) → shots/placement/east_plan_<name>.png
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from east_terrain import ROOT

LU_COL = {0: (96, 128, 84), 1: (150, 170, 110), 2: (170, 190, 150), 3: (180, 160, 110), 4: (196, 176, 140),
          5: (90, 140, 200), 6: (215, 195, 140), 7: (140, 130, 120), 8: (210, 200, 170), 9: (80, 140, 90)}

CAT_COL = {"house": (200, 150, 60), "landmark": (170, 60, 150), "civic": (190, 70, 70), "market": (230, 120, 30),
           "jumak": (220, 60, 40), "bridge": (40, 170, 170), "prop": (60, 60, 60), "mill": (60, 90, 200),
           "wall": (120, 60, 60), "shrine": (150, 40, 40)}


def _font(sz):
    for p in ["/System/Library/Fonts/AppleSDGothicNeo.ttc", "/System/Library/Fonts/Supplemental/AppleGothic.ttf"]:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, sz)
            except Exception:
                pass
    return ImageFont.load_default()


def render(T, items, bounds, name, cx, cz, half, ppm=2.0, title="", out=None):
    W = int(half * 2 * ppm)
    hm = T.hm
    # 높이 표본
    xs = cx - half + (np.arange(W) + 0.5) / ppm
    zs = cz - half + (np.arange(W) + 0.5) / ppm
    fi = np.clip(((xs - hm["x0"]) / hm["cell"]).round().astype(int), 0, hm["w"] - 1)
    fj = np.clip(((zs - hm["z0"]) / hm["cell"]).round().astype(int), 0, hm["h"] - 1)
    Hs = T.H[np.ix_(fj, fi)]
    gz, gx = np.gradient(Hs, 1.0 / ppm)
    # 북서 빛
    lx, lz, ly = -0.6, -0.6, 0.55
    n = np.sqrt(gx ** 2 + gz ** 2 + 1)
    shade = np.clip((-gx * lx - gz * lz + ly) / n / 0.9, 0.25, 1.15)
    lm = T.lm
    li = np.clip(((xs - lm["x0"]) / lm["cell"]).round().astype(int), 0, lm["w"] - 1)
    lj = np.clip(((zs - lm["z0"]) / lm["cell"]).round().astype(int), 0, lm["h"] - 1)
    Ls = T.L[np.ix_(lj, li)]
    col = np.zeros((W, W, 3), float)
    for k, c in LU_COL.items():
        col[Ls == k] = c
    img = np.clip(col * shade[..., None], 0, 255).astype(np.uint8)
    im = Image.fromarray(img, "RGB")
    d = ImageDraw.Draw(im, "RGBA")

    def P(x, z):
        return ((x - cx + half) * ppm, (z - cz + half) * ppm)

    # 등고선(2m 게임)
    # 하천
    for r in T.rivers:
        pts = [P(p[0], p[1]) for p in r["points"]]
        w = max(r["width_m"], 5.2) * ppm
        d.line(pts, fill=(60, 110, 220, 200), width=max(1, int(w)))
    for r in T.roads:
        pts = [P(p[0], p[1]) for p in r["points"]]
        d.line(pts, fill=(150, 60, 40, 220), width=max(1, int(r["width_m"] * ppm)))
    f = _font(max(11, int(ppm * 5)))
    fs = _font(10)
    for c in T.region["crossings"]:
        x, y = P(c["x"], c["z"])
        d.rectangle([x - 4, y - 4, x + 4, y + 4], outline=(0, 200, 200), width=2)
    # 배치
    for it in items:
        x0, x1, z0, z1 = it["_aabb"][:4]
        c, s = math.cos(it["ry"]), math.sin(it["ry"])
        corners = []
        for lx_, lz_ in [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]:
            # Godot Basis(UP, ry): x' = x cos + z sin, z' = -x sin + z cos
            wx = it["x"] + lx_ * c + lz_ * s
            wz = it["z"] - lx_ * s + lz_ * c
            corners.append(P(wx, wz))
        colr = CAT_COL.get(it.get("_cat", "house"), (200, 150, 60))
        d.polygon(corners, fill=colr + (150,), outline=(20, 20, 20, 255))
        # 정면 표시(+z 방향)
        fx, fz = it["x"] + s * (z1 + 1.0), it["z"] + c * (z1 + 1.0)
        d.line([P(it["x"], it["z"]), P(fx, fz)], fill=(255, 255, 255, 230), width=1)
        if it.get("_label"):
            px, py = P(it["x"], it["z"])
            d.text((px + 3, py - 6), it["_label"], fill=(0, 0, 0, 255), font=fs)
    # 축척
    d.rectangle([10, W - 22, 10 + 50 * ppm, W - 16], fill=(0, 0, 0))
    d.text((12, W - 40), "50m", fill=(0, 0, 0), font=f)
    d.text((10, 8), f"{name}  {title}  center=({cx:.0f},{cz:.0f})  N↑ (카메라는 아래쪽)", fill=(0, 0, 0), font=f)
    out = out or os.path.join(ROOT, "shots", "placement", f"east_plan_{name}.png")
    im.save(out)
    return out
