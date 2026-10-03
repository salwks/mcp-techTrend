"""권역 파이프라인 공용: 계약서 §1 투영·압축·격자 (docs/REGION_CONTRACTS.md).
권역은 명령행 인자(권역 id, 예: `python3 tools/region/build.py GS_GYEONGJU`) 또는 환경 변수 SEOLHWA_REGION으로 고른다.
기본은 JL_NAMWON_UNBONG. 권역 설정은 tools/region/regions/<id>.json(범위·기준점·K·격자 등).
SEOLHWA_OUT 환경 변수를 주면 산출물을 그 폴더에 쓴다(재현성 검사용)."""
import json, math, os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))           # seolhwa_godot/
REGIONS_DIR = os.path.join(HERE, "regions")

def _pick_region():
    known = {f[:-5] for f in os.listdir(REGIONS_DIR) if f.endswith(".json")} if os.path.isdir(REGIONS_DIR) else set()
    for a in sys.argv[1:]:
        a2 = a.split("=", 1)[1] if a.startswith("--region=") else a
        if a2 in known: return a2
    return os.environ.get("SEOLHWA_REGION", "JL_NAMWON_UNBONG")

REGION_ID = _pick_region()
CFG = json.load(open(os.path.join(REGIONS_DIR, REGION_ID + ".json"), encoding="utf-8"))
CACHE = os.path.join(HERE, CFG.get("cache", os.path.join("cache", REGION_ID)))
os.makedirs(CACHE, exist_ok=True)
OUT = os.environ.get("SEOLHWA_OUT") or os.path.join(ROOT, "region_data", REGION_ID)
SHOTS = os.environ.get("SEOLHWA_SHOTS") or os.path.join(ROOT, "shots", "region_data", *([] if CFG.get("shots_flat") else [REGION_ID]))

LAT0, LON0 = CFG["lat0"], CFG["lon0"]
K = CFG["K"]
Y_BASE_ALT = CFG.get("y_base_alt", 60.0)       # y = (alt - base) * K
M_PER_DEG_LON = math.cos(math.radians(LAT0)) * 111320.0
M_PER_DEG_LAT = 110574.0

# 게임 격자(계약서 §5 height): 픽셀 (i,j) 중심 = (X0 + i*CELL, Z0 + j*CELL)
CELL = CFG.get("cell", 2.0)
X0, Z0 = CFG["x0"], CFG["z0"]                   # 대칭 범위: x X0…−X0, z Z0…−Z0
W, H = int(round(-2 * X0 / CELL)) + 1, int(round(-2 * Z0 / CELL)) + 1
LU_CELL = 2 * CELL                               # landuse = 2배 거친 격자
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
