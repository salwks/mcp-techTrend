"""data-north 보조: 권역 설정(regions/<ID>.json bbox)으로 AWS terrarium z13 타일 받기 → cache/<ID>/terrarium_z13/
(공용 cache/terrarium_z13에 섞지 않는다 — dem.load_mosaic가 폴더 전체를 모자이크하므로).
실행: python3 tools/region/north_dem.py [ID ...]"""
import json, os, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from fetch_dem import Z, URL, tile_range

def run(rid):
    c = json.load(open(os.path.join(HERE, "regions", f"{rid}.json")))
    d = os.path.join(HERE, "cache", rid, f"terrarium_z{Z}"); os.makedirs(d, exist_ok=True)
    b = c["fetch_bbox"]; x0, x1, y0, y1 = tile_range(*b)
    def get(xy):
        x, y = xy; p = os.path.join(d, f"{x}_{y}.png")
        if not (os.path.exists(p) and os.path.getsize(p) > 0): urllib.request.urlretrieve(URL.format(z=Z, x=x, y=y), p)
        return os.path.getsize(p)
    jobs = [(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1)]
    with ThreadPoolExecutor(8) as ex: tot = sum(ex.map(get, jobs))
    print(rid, "tiles", len(jobs), "bytes", tot)

if __name__ == "__main__":
    for rid in (sys.argv[1:] or ["GG_HANYANG", "HH_HWANGJU", "PA_PYEONGYANG", "HG_HAMHEUNG"]): run(rid)
