#!/usr/bin/env python3
"""integ-mountain 전·후 시트 — shots/integ_mountain/raw/<set>_<id>_<tag>.png → shots/integ_mountain/<시트>.jpg
  /Users/sinjaeho/miniconda3/bin/python3 tools/mountain/integ_sheet.py
  cam: base(644b7ec 합치기 전 — 예전 카메라) | after          mtn: base | merge(mountain-terrain 합친 그대로) | after
"""
import json, os
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
RAW = os.path.join(ROOT, "shots", "integ_mountain", "raw"); OUT = os.path.join(ROOT, "shots", "integ_mountain")
F = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
def font(n): return ImageFont.truetype(F, n)
LBL = {"base": "전(644b7ec — 합치기 전)", "merge": "합친 그대로(산 지형)", "after": "후(integ-mountain)"}
def sheet(name, title, setn, views, tags, W):
	H = W * 9 // 16
	img = Image.new("RGB", (W * len(tags), 56 + (H + 30) * len(views)), (22, 22, 22)); d = ImageDraw.Draw(img)
	d.text((10, 12), title, fill=(240, 230, 200), font=font(26))
	for c, t in enumerate(tags): d.text((c * W + 10, 34), LBL[t], fill=(190, 190, 190), font=font(18))
	for r, v in enumerate(views):
		y = 56 + r * (H + 30)
		d.text((10, y + 4), v["label"], fill=(235, 235, 235), font=font(20))
		for c, t in enumerate(tags):
			p = os.path.join(RAW, "%s_%s_%s.png" % (setn, v["id"], t))
			if os.path.exists(p): img.paste(Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS), (c * W, y + 30))
	o = os.path.join(OUT, name + ".jpg"); img.save(o, quality=84); print(o)
V = json.load(open(os.path.join(HERE, "integ_views.json")))["sets"]
cam = V["cam"]["views"]; mtn = V["mtn"]["views"]
sheet("sheet_1_camera", "카메라 — 마을 구도(그대로)·들·길·산 구도·바라보기(V)", "cam", cam, ["base", "after"], 960)
sheet("sheet_2_rock_cliff", "바위·벼랑·암릉", "mtn", mtn[0:4], ["base", "merge", "after"], 720)
sheet("sheet_3_stream_forest", "개울·폭포·숲", "mtn", mtn[4:10], ["base", "merge", "after"], 720)
sheet("sheet_4_far", "1인칭 먼 산 — 남원에서·능선·재 마루", "mtn", mtn[10:15], ["base", "merge", "after"], 720)
