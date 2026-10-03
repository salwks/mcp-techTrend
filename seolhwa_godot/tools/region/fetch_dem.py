"""AWS Terrain Tiles(terrarium) 다운로드 — 권역 설정 fetch_bbox + 여백. 캐시: 권역 설정 tiles(남원 cache/terrarium_z13, 그 밖 cache/<id>/terrarium_z13).
사용: python3 tools/region/fetch_dem.py <권역 id>"""
import math, os, sys, urllib.request
import numpy as np
import common as _C
from concurrent.futures import ThreadPoolExecutor
Z = 13
HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, _C.CFG.get("tiles", os.path.join(os.path.relpath(_C.CACHE, HERE), f"terrarium_z{Z}")))
URL = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"

def tile_xy(lat, lon, z=Z):
    n = 2 ** z
    x = (lon + 180) / 360 * n
    r = np.radians(lat)
    y = (1 - np.log(np.tan(r) + 1 / np.cos(r)) / np.pi) / 2 * n
    return x, y

def tile_range(lat0, lat1, lon0, lon1, margin=1):
    xa, ya = tile_xy(lat1, lon0); xb, yb = tile_xy(lat0, lon1)
    return (int(float(xa)) - margin, int(float(xb)) + margin, int(float(ya)) - margin, int(float(yb)) + margin)

def fetch(xy):
    x, y = xy
    p = os.path.join(CACHE, f"{x}_{y}.png")
    if os.path.exists(p) and os.path.getsize(p) > 0:
        return p, False
    urllib.request.urlretrieve(URL.format(z=Z, x=x, y=y), p)
    return p, True

def main(lat0=None, lat1=None, lon0=None, lon1=None):
    if lat0 is None: lat0, lat1, lon0, lon1 = _C.CFG["fetch_bbox"]
    os.makedirs(CACHE, exist_ok=True)
    x0, x1, y0, y1 = tile_range(lat0, lat1, lon0, lon1)
    jobs = [(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1)]
    with ThreadPoolExecutor(8) as ex:
        res = list(ex.map(fetch, jobs))
    tot = sum(os.path.getsize(p) for p, _ in res)
    print(f"tiles {len(jobs)} x{x0}-{x1} y{y0}-{y1} new={sum(n for _, n in res)} bytes={tot}")

if __name__ == "__main__":
    main()
