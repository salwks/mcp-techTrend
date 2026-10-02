"""실측 DEM(terrarium z13) → 게임 격자 고도(m, 실제 고도). 결과 캐시: cache/dem_alt.npy"""
import glob, math, os
import numpy as np
from PIL import Image
from scipy import ndimage
import common as C
from fetch_dem import Z, CACHE as TILE_DIR, tile_xy

def load_mosaic():
    files = glob.glob(os.path.join(TILE_DIR, "*_*.png"))
    xs = sorted({int(os.path.basename(f).split("_")[0]) for f in files})
    ys = sorted({int(os.path.basename(f).split("_")[1].split(".")[0]) for f in files})
    tx0, ty0 = xs[0], ys[0]
    mos = np.zeros((len(ys) * 256, len(xs) * 256), np.float32)
    for f in files:
        b = os.path.basename(f)[:-4]
        x, y = map(int, b.split("_"))
        a = np.asarray(Image.open(f).convert("RGB"), np.float32)
        e = a[..., 0] * 256 + a[..., 1] + a[..., 2] / 256 - 32768
        mos[(y - ty0) * 256:(y - ty0 + 1) * 256, (x - tx0) * 256:(x - tx0 + 1) * 256] = e
    return mos, tx0, ty0

def build(force=False):
    p = os.path.join(C.CACHE, "dem_alt.npy")
    if os.path.exists(p) and not force:
        return np.load(p)
    mos, tx0, ty0 = load_mosaic()
    xs, zs = C.grid_xz()
    X, Zg = np.meshgrid(xs, zs)
    lat, lon = C.game_to_geo(X, Zg)
    tx, ty = tile_xy(lat, lon)
    px = (tx - tx0) * 256 - 0.5          # 픽셀 중심 보정
    py = (ty - ty0) * 256 - 0.5
    alt = ndimage.map_coordinates(mos, [py, px], order=3, mode="nearest").astype(np.float32)
    np.save(p, alt)
    return alt

if __name__ == "__main__":
    a = build(force=True)
    print(a.shape, a.min(), a.max(), a.mean())
