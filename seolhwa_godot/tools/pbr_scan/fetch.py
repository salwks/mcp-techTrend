#!/usr/bin/env python3
"""사진 스캔 PBR(CC0) 내려받기 — Poly Haven · ambientCG의 2K 지도(바탕색·법선(GL)·거칠기·AO·높이)를
assets/pbr_scan/src/<이름>/ 에 둔다(깃 밖 — .gitignore · Godot 가져오기 밖 — .gdignore). 출처·라이선스는 assets/pbr_scan/manifest.json.
  python3 tools/pbr_scan/fetch.py          # 없는 것만 받는다
다음: godot --path . -s res://tools/pbr_scan/pack.gd  (Texture2DArray 두 장으로 묶어 assets/pbr_scan/scan_a.res · scan_b.res)
"""
import io, json, os, sys, urllib.request, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "pbr_scan")
SRC = os.path.join(OUT, "src")
UA = {"User-Agent": "seolhwa-godot-asset-fetch/1.0"}

# 층 순서 = shaders/pbr_scan.gdshaderinc S_* = tools/pbr_scan/pack.gd
LAYERS = [
	{"name": "granite", "ko": "화강암 벼랑·바위(회색, 풍화)", "site": "ambientcg", "id": "Rock030", "tile_m": 4.0},
	{"name": "mossy_rock", "ko": "이끼·지의 낀 바위", "site": "polyhaven", "id": "mossy_rock", "tile_m": 3.0},
	{"name": "forest_floor", "ko": "숲 바닥(부엽토·이끼 얼룩·잎)", "site": "polyhaven", "id": "brown_mud_leaves_01", "tile_m": 3.0},
	{"name": "leaf_litter", "ko": "낙엽 깔린 바닥", "site": "polyhaven", "id": "dry_decay_leaves", "tile_m": 2.5},
	{"name": "trail_soil", "ko": "다져진 산길 흙(짙은 흙·돌)", "site": "polyhaven", "id": "forest_ground_04", "tile_m": 3.0},
	{"name": "masato", "ko": "마사토·자갈 섞인 풍화 화강암 흙", "site": "polyhaven", "id": "rocky_trail", "tile_m": 3.0},
	{"name": "river_pebbles", "ko": "냇돌·자갈(하상)", "site": "polyhaven", "id": "ganges_river_pebbles", "tile_m": 2.0},
]

def get(url):
	with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r: return r.read()

def fetch_polyhaven(L, d):
	files = json.loads(get("https://api.polyhaven.com/files/" + L["id"]))
	urls = {}
	for key, role in [("Diffuse", "color"), ("nor_gl", "normal"), ("Rough", "rough"), ("AO", "ao"), ("Displacement", "height")]:
		if key in files and "2k" in files[key]:
			f2 = files[key]["2k"].get("jpg") or files[key]["2k"].get("png")
			u = f2["url"] if isinstance(f2, dict) else f2
			urls[role] = u
	for role, u in urls.items():
		p = os.path.join(d, role + os.path.splitext(u)[1])
		if not os.path.exists(p):
			open(p, "wb").write(get(u))
	return {"page": "https://polyhaven.com/a/" + L["id"], "files": urls, "license": "CC0 1.0 (https://polyhaven.com/license)"}

def fetch_ambientcg(L, d):
	url = "https://ambientcg.com/get?file=%s_2K-JPG.zip" % L["id"]
	roles = {"_Color.": "color", "_NormalGL.": "normal", "_Roughness.": "rough", "_AmbientOcclusion.": "ao", "_Displacement.": "height"}
	if not all(any(f.startswith(r + ".") for f in os.listdir(d)) for r in ["color", "normal", "rough", "height"]):
		z = zipfile.ZipFile(io.BytesIO(get(url)))
		for n in z.namelist():
			for k, role in roles.items():
				if k in n: open(os.path.join(d, role + os.path.splitext(n)[1]), "wb").write(z.read(n))
	return {"page": "https://ambientcg.com/view?id=" + L["id"], "files": {"zip": url}, "license": "CC0 1.0 (https://docs.ambientcg.com/license/)"}

def main():
	os.makedirs(SRC, exist_ok=True)
	open(os.path.join(SRC, ".gdignore"), "w").close()
	man = {"about": "사진 스캔 PBR 층(CC0). 원본은 assets/pbr_scan/src/(깃 밖) — tools/pbr_scan/fetch.py로 다시 받는다.", "resolution": "2K source", "layers": []}
	for i, L in enumerate(LAYERS):
		d = os.path.join(SRC, L["name"]); os.makedirs(d, exist_ok=True)
		info = fetch_polyhaven(L, d) if L["site"] == "polyhaven" else fetch_ambientcg(L, d)
		man["layers"].append({"index": i, **L, **info, "maps": sorted(os.listdir(d))})
		print("ok", L["name"], sorted(os.listdir(d)))
	old = {}
	mp = os.path.join(OUT, "manifest.json")
	if os.path.exists(mp): old = json.load(open(mp))
	for k in ("packed", "vram_bytes"):
		if k in old: man[k] = old[k]
	json.dump(man, open(mp, "w"), ensure_ascii=False, indent=1)

if __name__ == "__main__": main()
