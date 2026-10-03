"""확인용 그림: shots/region_data/overview.png(음영기복+하천+도로+마을·랜드마크+축척), landuse.png 지도."""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import common as C, export

S = 2          # 높이맵 2px → 그림 1px (4m/px)
FONT = None
for p in ["/System/Library/Fonts/AppleSDGothicNeo.ttc", "/Library/Fonts/Arial Unicode.ttf"]:
    if os.path.exists(p):
        FONT = p; break

def font(sz):
    try: return ImageFont.truetype(FONT, sz)
    except Exception: return ImageFont.load_default()

def hillshade(y):
    ys = y[::S, ::S].astype(np.float64)
    gz, gx = np.gradient(ys, C.CELL * S)
    az, alt = np.radians(315), np.radians(40)
    # 빛: 북서(−x, −z)에서
    lx, lz, ly = -np.cos(alt) * np.sin(np.radians(45)), -np.cos(alt) * np.cos(np.radians(45)), np.sin(alt)
    nx, nz, ny = -gx, -gz, np.ones_like(gx)
    n = np.sqrt(nx ** 2 + nz ** 2 + 1)
    hs = np.clip((nx * lx + nz * lz + ny * ly) / n, 0, 1)
    t = (ys - ys.min()) / (np.ptp(ys) + 1e-9)
    base = np.stack([0.55 + 0.35 * t, 0.62 + 0.25 * t, 0.45 + 0.35 * t], -1)
    return np.clip(base * (0.35 + 0.75 * hs[..., None]), 0, 1)

VIEW = [0.0, 0.0]          # 확대 그림의 픽셀 원점(높이맵 픽셀 단위)
def to_px(x, z):
    i, j = C.xz_to_ij(x, z); return (i - VIEW[0]) / S, (j - VIEW[1]) / S

def scale_bar(d, w, h):
    # 1km(게임) = 실제 3.33km
    L = (1000 if S >= 2 else 200) / C.CELL / S
    x0, y0 = 30, h - 40
    d.rectangle([x0 - 8, y0 - 30, x0 + L + 150, y0 + 18], fill=(255, 255, 255))
    d.rectangle([x0, y0, x0 + L / 2, y0 + 8], fill=(0, 0, 0)); d.rectangle([x0 + L / 2, y0, x0 + L, y0 + 8], outline=(0, 0, 0), fill=(255, 255, 255))
    d.text((x0, y0 - 24), "0", fill=(0, 0, 0), font=font(16))
    d.text((x0 + L - 20, y0 - 24), "1km 게임 (실제 3.3km)" if S >= 2 else "200m 게임 (실제 667m)", fill=(0, 0, 0), font=font(16))

def overview(reg, y, path, title=None, lu=None):
    rgb = hillshade(y)
    if lu is not None:      # 마을 터(6)를 주황으로 얹음 — 실제 모양 확인용
        k = 2 // S if S < 2 else 1
        lv = lu == 6
        if S == 1: lv = np.repeat(np.repeat(lv, 2, 0), 2, 1)
        j0, i0 = int(VIEW[1]) // S, int(VIEW[0]) // S
        lv = lv[j0:j0 + rgb.shape[0], i0:i0 + rgb.shape[1]] if S == 1 else lv[:rgb.shape[0], :rgb.shape[1]]
        sub = rgb[:lv.shape[0], :lv.shape[1]]
        sub[lv] = sub[lv] * 0.45 + np.array([0.95, 0.55, 0.2]) * 0.55
        if C.REGION_ID != "JL_NAMWON_UNBONG":       # 바다·호수(물 칸)를 파랗게
            lw = lu == 5
            if S == 1: lw = np.repeat(np.repeat(lw, 2, 0), 2, 1)
            lw = lw[j0:j0 + rgb.shape[0], i0:i0 + rgb.shape[1]] if S == 1 else lw[:rgb.shape[0], :rgb.shape[1]]
            sub[lw] = sub[lw] * 0.3 + np.array([0.35, 0.55, 0.85]) * 0.7
    im = Image.fromarray((rgb * 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    ec = C.CFG.get("eupseong") or {}
    for l in reg.get("landmarks", []):
        if l["id"] == "namwon_eupseong" or l["id"] == ec.get("landmark"):
            hx_, hz_ = (93, 93) if l["id"] == "namwon_eupseong" else (ec.get("half_x", ec["half"]), ec["half"])
            a0 = to_px(l["x"] - hx_, l["z"] - hz_); a1 = to_px(l["x"] + hx_, l["z"] + hz_)
            d.rectangle([a0[0], a0[1], a1[0], a1[1]], outline=(90, 80, 70), width=3 if S == 1 else 2)
    for r in sorted(reg["rivers"], key=lambda r: "DCB".index(r["grade"])):
        pts = [to_px(p[0], p[1]) for p in r["points"]]
        w = {"S": 8, "A": 7, "B": 6, "C": 3, "D": 1}[r["grade"]]
        d.line(pts, fill=(40, 90, 210) if r["grade"] != "D" else (80, 130, 220), width=w)
    for rd in reg.get("roads", []):
        pts = [to_px(p[0], p[1]) for p in rd["points"]]
        w = {"대로": 5, "지선": 4, "마을길": 2, "산길": 2}.get(rd["class"], 2)
        d.line(pts, fill=(205, 30, 30), width=w)
    f = font(18); fs = font(15)
    for c in reg.get("crossings", []):
        px, pz = to_px(c["x"], c["z"]); d.rectangle([px - 5, pz - 5, px + 5, pz + 5], outline=(255, 255, 255), fill=(0, 160, 160))
    for p in reg.get("passes", []):
        px, pz = to_px(p["x"], p["z"]); d.polygon([(px, pz - 9), (px - 8, pz + 6), (px + 8, pz + 6)], fill=(120, 60, 0))
        d.text((px + 10, pz - 4), p["name"], fill=(80, 30, 0), font=f, stroke_width=2, stroke_fill=(255, 255, 255))
    for s in reg.get("settlements", []):
        px, pz = to_px(s["x"], s["z"]); r = 4
        d.ellipse([px - r, pz - r, px + r, pz + r], outline=(120, 60, 0), fill=(250, 200, 0), width=1)
        d.text((px + r + 3, pz + 2), s["name"], fill=(30, 30, 30), font=fs, stroke_width=2, stroke_fill=(255, 255, 255))
    for l in reg.get("landmarks", []):
        px, pz = to_px(l["x"], l["z"])
        d.ellipse([px - 5, pz - 5, px + 5, pz + 5], fill=(220, 0, 160), outline=(255, 255, 255))
        d.text((px + 7, pz - 20), l["name"], fill=(120, 0, 90), font=fs, stroke_width=2, stroke_fill=(255, 255, 255))
    sp = reg.get("spawn")
    if sp:
        px, pz = to_px(sp["x"], sp["z"]); d.line([(px - 9, pz), (px + 9, pz)], fill=(0, 0, 0), width=3); d.line([(px, pz - 9), (px, pz + 9)], fill=(0, 0, 0), width=3)
    for r in reg["rivers"]:
        if r["grade"] in "BC" and "지류" not in r["name"] and "무명" not in r["name"]:
            p = r["points"][len(r["points"]) // 2]; px, pz = to_px(p[0], p[1])
            d.text((px + 6, pz + 4), r["name"], fill=(20, 50, 160), font=f, stroke_width=2, stroke_fill=(255, 255, 255))
    scale_bar(d, im.width, im.height)
    if title: d.text((12, 34), title, fill=(0, 0, 0), font=f, stroke_width=2, stroke_fill=(255, 255, 255))
    d.text((12, 8), f"{reg['region_id']}  {reg['height']['w']}×{reg['height']['h']} cell {reg['height']['cell']}m  y {reg['height']['y_min']}…{reg['height']['y_max']}  N↑", fill=(0, 0, 0), font=f, stroke_width=2, stroke_fill=(255, 255, 255))
    os.makedirs(os.path.dirname(path), exist_ok=True); im.save(path)

LU_COL = {0: (52, 92, 52), 1: (150, 180, 100), 2: (120, 200, 210), 3: (205, 175, 110), 4: (180, 140, 100), 5: (40, 80, 200),
          6: (230, 90, 60), 7: (120, 110, 105), 8: (230, 220, 170), 9: (60, 150, 70)}

def landuse_map(reg, lu, path):
    a = np.zeros(lu.shape + (3,), np.uint8)
    for k, c in LU_COL.items(): a[lu == k] = c
    im = Image.fromarray(a); d = ImageDraw.Draw(im)
    names = {0: "숲", 1: "초지", 2: "논", 3: "밭", 4: "길·맨땅", 5: "물", 6: "마을 터", 7: "바위", 8: "모래톱", 9: "대숲"}
    f = font(18)
    for n, (k, c) in enumerate(LU_COL.items()):
        d.rectangle([12, 12 + n * 24, 32, 30 + n * 24], fill=c, outline=(0, 0, 0)); d.text((38, 10 + n * 24), names[k], fill=(255, 255, 255), font=f, stroke_width=2, stroke_fill=(0, 0, 0))
    im.save(path)

CL_COL = {0: (235, 170, 80), 1: (120, 190, 110), 2: (120, 160, 230), 3: (245, 245, 255), 4: (60, 190, 200)}

def climate_map(reg, y, cl, path):
    """기후대(계획서 B1) 위에 음영기복과 고을 유형(archetype)·signature."""
    hs = hillshade(y)[:cl.shape[0], :cl.shape[1]]
    a = np.zeros(cl.shape + (3,), float)
    for k, c in CL_COL.items(): a[cl == k] = np.array(c) / 255
    im = Image.fromarray((np.clip(a * (0.35 + 0.65 * hs.mean(-1, keepdims=True) / 0.9), 0, 1) * 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    f = font(18); fs = font(14)
    names = reg["climate"]["codes"]
    for n, (k, c) in enumerate(CL_COL.items()):
        d.rectangle([12, 40 + n * 24, 32, 58 + n * 24], fill=c, outline=(0, 0, 0)); d.text((38, 38 + n * 24), names[str(k)], fill=(255, 255, 255), font=f, stroke_width=2, stroke_fill=(0, 0, 0))
    for s in reg["settlements"]:
        pf = s.get("profile") or {}
        px, pz = to_px(s["x"], s["z"]); d.ellipse([px - 4, pz - 4, px + 4, pz + 4], fill=(200, 30, 30))
        lab = f"{pf.get('archetype', '?')}/{pf.get('climate', '?')}" + ("" if s["id"].startswith("auto") else f" {s['name']}: {pf.get('signature', '')}")
        d.text((px + 6, pz - 7), lab, fill=(20, 20, 20), font=fs, stroke_width=2, stroke_fill=(255, 255, 255))
    d.text((12, 8), "기후대 지도 (climate.png) + 고을 유형/기후대", fill=(0, 0, 0), font=f, stroke_width=2, stroke_fill=(255, 255, 255))
    im.save(path)

if __name__ == "__main__":
    reg = json.load(open(os.path.join(C.OUT, "region.json")))
    y, _ = export.read_height()
    LU = np.asarray(Image.open(os.path.join(C.OUT, "landuse.png")))
    overview(reg, y, os.path.join(C.SHOTS, "overview.png"), lu=LU)
    zooms = {"zoom_namwon": (-3700, -150, -2700, 650), "zoom_unbong": (-100, -1200, 1300, -250), "zoom_inwol": (2300, -1800, 3300, -1100),
             "zoom_silsangsa_banseon": (2300, -400, 3900, 1500)} if C.REGION_ID == "JL_NAMWON_UNBONG" else {k: tuple(v) for k, v in C.CFG.get("zooms", {}).items()}
    os.makedirs(C.SHOTS, exist_ok=True)
    for name, (x0, z0, x1, z1) in zooms.items():
        S = 1
        i0, j0 = [int(v) for v in C.xz_to_ij(x0, z0)]; i1, j1 = [int(v) for v in C.xz_to_ij(x1, z1)]
        VIEW[0], VIEW[1] = i0, j0
        overview(reg, y[j0:j1, i0:i1], os.path.join(C.SHOTS, name + ".png"), title=name, lu=LU)
    S = 2; VIEW[0] = VIEW[1] = 0
    lp = os.path.join(C.OUT, "landuse.png")
    if os.path.exists(lp):
        landuse_map(reg, np.asarray(Image.open(lp)), os.path.join(C.SHOTS, "landuse_map.png"))
    cp = os.path.join(C.OUT, "climate.png")
    if os.path.exists(cp):
        climate_map(reg, y, np.asarray(Image.open(cp)), os.path.join(C.SHOTS, "climate_map.png"))
    print("ok")
