#!/usr/bin/env python3
# 남원 배치 평면도: 지형 음영 + 토지이용 + 길·물 + footprint 사각형과 이름.
#   python3 tools/placement/namwon_plan.py → shots/placement/namwon_plan.png (읍내 2px/m), namwon_plan_wide.png (권역 서쪽 0.5px/m)
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from namwon_data import Region, ROOT, RDIR, rect_corners, local_to_world
import namwon as NW

FONT = None
for p in ["/System/Library/Fonts/AppleSDGothicNeo.ttc", "/Library/Fonts/Arial Unicode.ttf"]:
    if os.path.exists(p):
        FONT = p; break


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except Exception:
        return ImageFont.load_default()


LU_COL = {0: (96, 128, 88), 1: (176, 196, 140), 2: (190, 214, 222), 3: (214, 200, 160), 4: (226, 214, 186), 5: (90, 130, 190),
          6: (236, 226, 190), 7: (150, 146, 140), 8: (220, 216, 200), 9: (110, 150, 100)}

COLS = {
    "landmark": (150, 40, 120), "building": (180, 70, 30), "prop": (40, 110, 60), "water": (30, 90, 170), "wall": (90, 90, 90),
}


def kit_kind(kit):
    if kit.startswith("landmark/"):
        return "wall" if kit.endswith("wall") else "landmark"
    if kit in NW.BUILDING_KITS:
        return "building"
    return "prop"


def render(R, items, X0, Z0, X1, Z1, S, path, labels=True, title=""):
    h = R.hm
    i0 = int((X0 - h["x0"]) / h["cell"]); i1 = int((X1 - h["x0"]) / h["cell"])
    j0 = int((Z0 - h["z0"]) / h["cell"]); j1 = int((Z1 - h["z0"]) / h["cell"])
    H = R.H[j0:j1, i0:i1].astype(np.float32)
    gz, gx = np.gradient(H, h["cell"])
    # 북서쪽 빛
    shade = np.clip(0.75 + (-gx * -0.7 + -gz * -0.7) * 1.6, 0.35, 1.25)
    l = R.lm
    li0 = int((X0 - l["x0"]) / l["cell"]); lj0 = int((Z0 - l["z0"]) / l["cell"])
    LU = R.L[lj0:lj0 + (j1 - j0 + 1) // 2 + 1, li0:li0 + (i1 - i0 + 1) // 2 + 1]
    LU = np.repeat(np.repeat(LU, 2, 0), 2, 1)[:H.shape[0], :H.shape[1]]
    rgb = np.zeros(H.shape + (3,), np.float32)
    for k, c in LU_COL.items():
        rgb[LU == k] = c
    rgb *= shade[..., None]
    im = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).resize((int((X1 - X0) * S), int((Z1 - Z0) * S)), Image.BILINEAR)
    d = ImageDraw.Draw(im, "RGBA")
    P = lambda x, z: ((x - X0) * S, (z - Z0) * S)
    for rv in R.rivers:
        w = max(rv["width_m"], 5.2) * 1.18
        d.line([P(p[0], p[1]) for p in rv["points"]], fill=(60, 110, 200, 200), width=max(1, int(w * S)))
    for rd in R.roads:
        d.line([P(p[0], p[1]) for p in rd["points"]], fill=(160, 60, 40, 170), width=max(1, int(rd["width_m"] * S)))
    # 격자
    f = font(max(10, int(6 * S)) if S >= 1 else 11)
    step = 50 if S >= 1.5 else 200
    for x in range(int(X0 // step * step), int(X1), step):
        if x < X0: continue
        d.line([P(x, Z0), P(x, Z1)], fill=(0, 0, 0, 40)); d.text(P(x + 1, Z0 + 1), str(x), fill=(0, 0, 0, 160), font=font(11))
    for z in range(int(Z0 // step * step), int(Z1), step):
        if z < Z0: continue
        d.line([P(X0, z), P(X1, z)], fill=(0, 0, 0, 40)); d.text(P(X0 + 1, z + 1), str(z), fill=(0, 0, 0, 160), font=font(11))
    # 읍성 조각
    for (kit, sd, x, z, ry, w, dd, lzo, tris) in NW.eupseong_pieces():
        cx, cz = local_to_world(x, z, ry, 0, lzo)
        d.polygon([P(*c) for c in rect_corners(cx, cz, w, dd, ry)], fill=(110, 110, 110, 150), outline=(40, 40, 40, 255))
    lab = []
    for it in items:
        kit = it["kit"]
        key = (kit, None)
        var = None
        prm = it["params"]
        if kit == "village/house_compound": var = prm["size"]
        elif kit == "village/giwa": var = "plain"
        elif kit == "village/market_shop": var = "onggi" if prm.get("goods") == "onggi" else ("cloth" if prm.get("goods") == "cloth" else None)
        elif kit == "village/jwapan": var = None if prm.get("awning", True) else "noawn"
        elif kit == "village/well": var = "roof" if prm.get("roof") else None
        rects = []
        if kit == "landmark/namwon_eupseong":
            continue
        if kit == "landmark/gwanghallu_pond":
            rects = [(0, 0, prm["width"] + 3, prm["depth"] + 3), (-prm["width"] * 0.18, 0, 2.8, 57)]
        elif kit == "landmark/gwanghallu":
            rects = [(4, 0, 30, 14.4)]
        elif kit == "landmark/hyanggyo":
            rects = [(0, 0, prm["width"] + 2, prm["depth"] + 6)]
        elif kit == "landmark/gwana_wall":
            rects = [(0, 0, prm["length"], 1.1)]
        elif kit in ("village/seop_bridge", "village/stone_bridge"):
            rects = [(0, 0, 2.8, prm["len"])]
        elif kit == "village/jingeom":
            rects = [(0, 0, 1.4, prm["len"])]
        elif kit == "village/torch_post":
            rects = [(0, 0, 0.7, 0.7)]
        else:
            (w, dd), _ = NW.FP.get((kit, var), NW.FP.get((kit, None)))
            if kit == "village/choga":
                w += 1.6; dd += 3.0
            if kit == "village/giwa":
                w += 1.0; dd += 3.0
            rects = [(0, 0, w, dd)]
        kind = kit_kind(kit)
        if kit == "landmark/gwanghallu_pond": kind = "water"
        col = COLS[kind]
        for (lx, lz, w, dd) in rects:
            cx, cz = local_to_world(it["x"], it["z"], it["ry"], lx, lz)
            poly = [P(*c) for c in rect_corners(cx, cz, w, dd, it["ry"])]
            d.polygon(poly, fill=col + (90,), outline=col + (255,))
        # 정면(+z) 표시
        fx, fz = local_to_world(it["x"], it["z"], it["ry"], 0, 3.0)
        d.line([P(it["x"], it["z"]), P(fx, fz)], fill=col + (255,), width=1)
        if labels and kind in ("landmark", "building", "water") or (labels and kit in ("village/seop_bridge", "village/jingeom", "village/stone_bridge", "village/narutbae", "village/seonghwangdang", "village/ppallaeteo", "village/jangseung", "village/sotdae", "village/well")):
            name = short_name(it)
            if name:
                lab.append((P(it["x"], it["z"]), name, col))
    fl = font(12 if S >= 1.5 else 10)
    for (pt, name, col) in lab:
        tw = d.textlength(name, font=fl)
        d.rectangle([pt[0] - tw / 2 - 1, pt[1] - 7, pt[0] + tw / 2 + 1, pt[1] + 7], fill=(255, 255, 255, 170))
        d.text((pt[0] - tw / 2, pt[1] - 7), name, fill=col + (255,), font=fl)
    # spawn
    sp = R.r["spawn"]
    d.ellipse([P(sp["x"] - 2, sp["z"] - 2), P(sp["x"] + 2, sp["z"] + 2)], fill=(255, 0, 0, 255))
    d.text((8, im.size[1] - 22), title, fill=(0, 0, 0, 255), font=font(14))
    # 축척
    bx, by = im.size[0] - 20 - 50 * S, im.size[1] - 20
    d.line([(bx, by), (bx + 50 * S, by)], fill=(0, 0, 0, 255), width=3); d.text((bx, by - 16), "50m" if S >= 1 else "", fill=(0, 0, 0, 255), font=font(11))
    im.save(path)
    print("saved", os.path.relpath(path, ROOT), im.size)


NAMES = {"landmark/gwana": "관아(동헌·내아)", "landmark/gaeksa": "객사 용성관", "landmark/samun": "삼문", "landmark/gwanghallu": "광한루",
         "landmark/gwanghallu_pond": "광한루원 못·오작교", "landmark/hyanggyo": "향교(가설)", "village/jumak": "주막",
         "village/seop_bridge": "섶다리", "village/jingeom": "징검다리", "village/stone_bridge": "돌다리", "village/narutbae": "나룻배",
         "village/seonghwangdang": "성황당", "village/ppallaeteo": "빨래터", "village/jangseung": "장승", "village/sotdae": "솟대", "village/well": "우물",
         "village/giwa": "기와", "village/choga": "초", "village/market_shop": "가가"}


def short_name(it):
    k = it["kit"]
    if k == "village/house_compound":
        return {"small": "소", "medium": "중", "large": "대"}[it["params"]["size"]]
    return NAMES.get(k, "")


def main():
    R = Region()
    doc = json.load(open(os.path.join(RDIR, "placement_namwon.json")))
    items = doc["items"]
    os.makedirs(os.path.join(ROOT, "shots", "placement"), exist_ok=True)
    render(R, items, -3420, -40, -3040, 580, 2.0, os.path.join(ROOT, "shots", "placement", "namwon_plan.png"),
           title="placement_namwon — 읍내 (2px/m, 위=북, 빨간 점=spawn, 짧은 선=정면)")
    render(R, items, -3460, -620, -2700, 1020, 0.6, os.path.join(ROOT, "shots", "placement", "namwon_plan_wide.png"),
           title="placement_namwon — 넓게 (다리·향교·성황당·어귀)")


if __name__ == "__main__":
    main()
