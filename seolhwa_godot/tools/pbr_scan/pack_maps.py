#!/usr/bin/env python3
"""스캔 지도 → 두 장 묶음 PNG(assets/pbr_scan/src/_packed/<i>_<이름>_{a,b}.png). 그다음 tools/pbr_scan/pack.gd가 BC3·밉맵 Texture2DArray로.
  A: rgb 바탕색(sRGB 그대로), a 높이(층마다 1~99% 늘임)    B: r 거칠기, g 법선 y(GL), b AO, a 법선 x
  RES(기본 2048)는 첫 인자로 바꿀 수 있다(예: 1024)."""
import json, os, sys
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from fetch import LAYERS, SRC
RES = int(sys.argv[1]) if len(sys.argv) > 1 else 2048
OUT = os.path.join(SRC, "_packed"); os.makedirs(OUT, exist_ok=True)

def load(d, role, mode):
	for ext in (".jpg", ".png"):
		p = os.path.join(d, role + ext)
		if os.path.exists(p):
			im = Image.open(p).convert(mode)
			if im.size != (RES, RES): im = im.resize((RES, RES), Image.LANCZOS)
			return np.asarray(im).astype(np.float32) / 255.0
	return None

for i, L in enumerate(LAYERS):
	d = os.path.join(SRC, L["name"])
	col = load(d, "color", "RGB"); nrm = load(d, "normal", "RGB")
	h = load(d, "height", "L"); r = load(d, "rough", "L"); ao = load(d, "ao", "L")
	if h is None: h = np.full(col.shape[:2], 0.5, np.float32)
	lo, hi = np.percentile(h, 1), np.percentile(h, 99)
	h = np.clip((h - lo) / max(hi - lo, 1e-3), 0, 1)
	if r is None: r = np.full(h.shape, 0.8, np.float32)
	if ao is None: ao = np.ones(h.shape, np.float32)
	a = np.dstack([col, h]); b = np.dstack([r, nrm[..., 1], ao, nrm[..., 0]])
	Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, "%d_%s_a.png" % (i, L["name"])))
	Image.fromarray((b * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, "%d_%s_b.png" % (i, L["name"])))
	lin = np.power(col, 2.2).reshape(-1, 3).mean(0)
	print("packed", i, L["name"], "mean linear albedo", np.round(lin, 3), "mean rough", round(float(r.mean()), 2))
