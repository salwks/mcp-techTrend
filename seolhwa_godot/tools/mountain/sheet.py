#!/usr/bin/env python3
"""산 지형 전·후 시트 — shots/mountain/raw/mtn_<id>_<before|after>.png → shots/mountain/<시트>.jpg
  /Users/sinjaeho/miniconda3/bin/python3 tools/mountain/sheet.py
views.json 순서대로, 시트마다 [전 | 후] 두 칸씩(이름표는 views.json label). 'after'만 있으면 한 칸.
"""
import json, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
RAW = os.path.join(ROOT, "shots", "mountain", "raw")
OUT = os.path.join(ROOT, "shots", "mountain")
FONT = None
for f in ["/System/Library/Fonts/AppleSDGothicNeo.ttc", "/System/Library/Fonts/Supplemental/AppleGothic.ttf", "/System/Library/Fonts/Supplemental/AppleMyungjo.ttf"]:
	if os.path.exists(f): FONT = f; break
W, H = 960, 540

def font(n): return ImageFont.truetype(FONT, n) if FONT else ImageFont.load_default()

def sheet(name, title, views, tags=("before", "after")):
	rows = [v for v in views if os.path.exists(os.path.join(RAW, f"mtn_{v['id']}_after.png"))]
	if not rows: return None
	cols = len(tags)
	img = Image.new("RGB", (W * cols, 60 + (H + 34) * len(rows)), (24, 24, 24))
	d = ImageDraw.Draw(img)
	d.text((12, 14), title, fill=(240, 230, 200), font=font(28))
	for c, t in enumerate(tags):
		d.text((c * W + W // 2 - 30, 18), {"before": "전(1da7b59)", "after": "후(산 지형)"}.get(t, t), fill=(200, 200, 200), font=font(22))
	for r, v in enumerate(rows):
		y = 60 + r * (H + 34)
		d.text((12, y + 4), v.get("label", v["id"]) + f"  ({v['x']}, {v['z']})", fill=(230, 230, 230), font=font(22))
		for c, t in enumerate(tags):
			p = os.path.join(RAW, f"mtn_{v['id']}_{t}.png")
			if os.path.exists(p):
				img.paste(Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS), (c * W, y + 34))
			else:
				d.text((c * W + 20, y + 34 + H // 2), "(없음)", fill=(150, 150, 150), font=font(22))
	out = os.path.join(OUT, name + ".jpg")
	img.save(out, quality=82)
	return out

def main():
	V = json.load(open(os.path.join(HERE, "views.json")))["sets"]["mtn"]["views"]
	groups = [
		("sheet_1_namwon", "남원 — 고을 카메라·배산·먼 산(1인칭)", [v for v in V if v["id"].startswith("n")]),
		("sheet_2_pass", "여원치 고갯길 — 들머리·주막·갈지자·계곡·폭포·재 마루", [v for v in V if v["id"][:2] in ("p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8")]),
		("sheet_3_far", "재 마루·능선 — 먼 산줄기(걸어서 닿는 실제 땅)", [v for v in V if v["id"][:2] in ("p9", "pa", "pb", "pc", "pd")]),
		("sheet_4_rock_water", "바위·벼랑·암릉·너덜 · 계곡 개울 · 요천 기슭", [v for v in V if v["id"].startswith("r")]),
		("sheet_5_over", "내려다보기(안개 끔) · 지도", [v for v in V if v["id"].startswith("o") or v["id"].startswith("m")]),
	]
	for name, title, vs in groups:
		print(sheet(name, title, vs))

if __name__ == "__main__":
	main()
