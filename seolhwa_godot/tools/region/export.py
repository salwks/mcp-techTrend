"""계약서 §5 형식으로 쓰기: height.png(16bit), landuse.png(8bit), region.json"""
import json, math, os
import numpy as np
from PIL import Image
import common as C

def write_height(y, path=None):
    path = path or os.path.join(C.OUT, "height.png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    y_min = math.floor(float(y.min()) - 1.0)
    y_max = math.ceil(float(y.max()) + 1.0)
    v = np.round((y - y_min) / (y_max - y_min) * 65535).clip(0, 65535).astype(np.uint16)
    Image.fromarray(v).save(path, optimize=True)     # PIL: uint16 → mode I;16 → 16비트 회색조 PNG
    return dict(file="height.png", x0=C.X0, z0=C.Z0, cell=C.CELL, w=int(y.shape[1]), h=int(y.shape[0]),
                y_min=float(y_min), y_max=float(y_max),
                note="픽셀(i,j) 중심 = (x0+i*cell, z0+j*cell); y = y_min + v/65535*(y_max-y_min). 16bit 회색조, 행=+z(남쪽)")

def read_height(path=None):
    path = path or os.path.join(C.OUT, "height.png")
    meta = json.load(open(os.path.join(C.OUT, "region.json")))["height"]
    v = np.asarray(Image.open(path)).astype(np.float64)
    return meta["y_min"] + v / 65535 * (meta["y_max"] - meta["y_min"]), meta

def write_landuse(lu, path=None):
    path = path or os.path.join(C.OUT, "landuse.png")
    Image.fromarray(lu.astype(np.uint8), mode="L").save(path, optimize=True)
    return dict(file="landuse.png", x0=C.X0, z0=C.Z0, cell=C.LU_CELL, w=int(lu.shape[1]), h=int(lu.shape[0]),
                classes={"0": "숲", "1": "풀밭·초지", "2": "논", "3": "밭", "4": "길·맨땅", "5": "물", "6": "마을 터",
                         "7": "바위·벼랑", "8": "모래톱·자갈", "9": "대숲"},
                note="height와 같은 원점, 2배 거친 격자(4m). 픽셀(i,j) 중심 = (x0+i*cell, z0+j*cell)")

def write_region(d, path=None):
    path = path or os.path.join(C.OUT, "region.json")
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
    os.replace(tmp, path)
