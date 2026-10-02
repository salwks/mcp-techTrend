"""권역 파이프라인 공용: 계약서 §1 투영·압축·격자 (docs/REGION_CONTRACTS.md)."""
import math, os
import numpy as np

REGION_ID = "JL_NAMWON_UNBONG"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))           # seolhwa_godot/
CACHE = os.path.join(HERE, "cache")
OUT = os.path.join(ROOT, "region_data", REGION_ID)
SHOTS = os.path.join(ROOT, "shots", "region_data")

LAT0, LON0 = 35.4175, 127.50
K = 0.30
Y_BASE_ALT = 60.0                  # y = (alt - 60) * K
M_PER_DEG_LON = math.cos(math.radians(LAT0)) * 111320.0
M_PER_DEG_LAT = 110574.0

# 게임 격자(계약서 §5 height): 픽셀 (i,j) 중심 = (X0 + i*CELL, Z0 + j*CELL)
CELL = 2.0
X0, Z0 = -4352.0, -2112.0
W, H = 4353, 2113                  # x −4352…+4352, z −2112…+2112 (256m 타일 경계에 맞춤)
LU_CELL = 4.0                      # landuse = 2배 거친 격자
LU_W, LU_H = (W - 1) // 2 + 1, (H - 1) // 2 + 1

def geo_to_game(lat, lon):
    east = (np.asarray(lon) - LON0) * M_PER_DEG_LON
    north = (np.asarray(lat) - LAT0) * M_PER_DEG_LAT
    return east * K, -north * K

def game_to_geo(x, z):
    lon = LON0 + np.asarray(x) / K / M_PER_DEG_LON
    lat = LAT0 - np.asarray(z) / K / M_PER_DEG_LAT
    return lat, lon

def alt_to_y(alt):
    return (np.asarray(alt) - Y_BASE_ALT) * K

def y_to_alt(y):
    return np.asarray(y) / K + Y_BASE_ALT

def xz_to_ij(x, z, cell=CELL):
    return (np.asarray(x) - X0) / cell, (np.asarray(z) - Z0) / cell

def ij_to_xz(i, j, cell=CELL):
    return X0 + np.asarray(i) * cell, Z0 + np.asarray(j) * cell

def grid_xz(cell=CELL):
    w = int(round((-2 * X0) / cell)) + 1
    h = int(round((-2 * Z0) / cell)) + 1
    xs = X0 + np.arange(w) * cell
    zs = Z0 + np.arange(h) * cell
    return xs, zs

def bilinear(a, fi, fj):
    """a[j,i] 격자에서 실수 픽셀 좌표 (fi, fj) 쌍선형 표본."""
    fi = np.clip(np.asarray(fi, float), 0, a.shape[1] - 1.001)
    fj = np.clip(np.asarray(fj, float), 0, a.shape[0] - 1.001)
    i0 = np.floor(fi).astype(int); j0 = np.floor(fj).astype(int)
    u = fi - i0; v = fj - j0
    return (a[j0, i0] * (1 - u) * (1 - v) + a[j0, i0 + 1] * u * (1 - v)
            + a[j0 + 1, i0] * (1 - u) * v + a[j0 + 1, i0 + 1] * u * v)
