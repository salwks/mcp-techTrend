# 남원 읍내 배치 생성기 공용: region.json·height.png·landuse.png 읽기, 높이·토지이용 표본, 길·물 거리.
import json, math, os
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RDIR = os.path.join(ROOT, "region_data", "JL_NAMWON_UNBONG")


class Region:
    def __init__(self):
        self.r = json.load(open(os.path.join(RDIR, "region.json")))
        h = self.r["height"]
        self.hm = h
        img = Image.open(os.path.join(RDIR, h["file"]))
        a = np.array(img)
        if a.dtype != np.uint16:
            a = a.astype(np.uint16)
        self.H = h["y_min"] + a.astype(np.float32) / 65535.0 * (h["y_max"] - h["y_min"])
        lu = self.r["landuse"]
        self.lm = lu
        self.L = np.array(Image.open(os.path.join(RDIR, lu["file"])))
        self.roads = self.r["roads"]
        self.rivers = self.r["rivers"]
        # 선분 목록 (x0,z0,x1,z1, 반폭, id)
        segs = []
        for rd in self.roads:
            p = rd["points"]
            for i in range(len(p) - 1):
                segs.append((p[i][0], p[i][1], p[i + 1][0], p[i + 1][1], rd["width_m"] / 2, rd["id"]))
        self.road_segs = np.array([s[:5] for s in segs], dtype=np.float64)
        self.road_ids = [s[5] for s in segs]
        rs = []
        self.river_ids = []
        for rv in self.rivers:
            p = rv["points"]
            hw = max(rv["width_m"], 5.2) * 1.18 / 2
            for i in range(len(p) - 1):
                rs.append((p[i][0], p[i][1], p[i + 1][0], p[i + 1][1], hw, p[i][2]))
                self.river_ids.append(rv["id"])
        self.river_segs = np.array(rs, dtype=np.float64)

    def height(self, x, z):
        h = self.hm
        fi = (x - h["x0"]) / h["cell"]; fj = (z - h["z0"]) / h["cell"]
        i0 = int(math.floor(fi)); j0 = int(math.floor(fj))
        ti = fi - i0; tj = fj - j0
        i0 = min(max(i0, 0), h["w"] - 2); j0 = min(max(j0, 0), h["h"] - 2)
        a = self.H
        return float(a[j0, i0] * (1 - ti) * (1 - tj) + a[j0, i0 + 1] * ti * (1 - tj) + a[j0 + 1, i0] * (1 - ti) * tj + a[j0 + 1, i0 + 1] * ti * tj)

    def landuse(self, x, z):
        l = self.lm
        i = int(round((x - l["x0"]) / l["cell"])); j = int(round((z - l["z0"]) / l["cell"]))
        i = min(max(i, 0), l["w"] - 1); j = min(max(j, 0), l["h"] - 1)
        return int(self.L[j, i])

    def landuse_hist(self, x0, z0, x1, z1, step=2.0):
        c = {}
        n = 0
        for x in np.arange(x0, x1 + 1e-6, step):
            for z in np.arange(z0, z1 + 1e-6, step):
                k = self.landuse(x, z); c[k] = c.get(k, 0) + 1; n += 1
        return {k: v / n for k, v in c.items()}

    @staticmethod
    def _seg_dist(segs, x, z):
        x0, z0, x1, z1 = segs[:, 0], segs[:, 1], segs[:, 2], segs[:, 3]
        dx = x1 - x0; dz = z1 - z0
        L2 = dx * dx + dz * dz + 1e-9
        t = np.clip(((x - x0) * dx + (z - z0) * dz) / L2, 0, 1)
        px = x0 + t * dx; pz = z0 + t * dz
        return np.hypot(x - px, z - pz)

    def road_clear(self, x, z):
        """길 가장자리까지 거리(음수면 길 위), 가장 가까운 길 id"""
        d = self._seg_dist(self.road_segs, x, z) - self.road_segs[:, 4]
        k = int(np.argmin(d))
        return float(d[k]), self.road_ids[k]

    def river_clear(self, x, z):
        d = self._seg_dist(self.river_segs, x, z) - self.river_segs[:, 4]
        k = int(np.argmin(d))
        return float(d[k]), self.river_ids[k], float(self.river_segs[k, 5])

    def rect_clear(self, cx, cz, w, d, ry, kind="road"):
        """회전 사각형 가장자리 표본점들 중 길/물까지 최소 거리"""
        pts = rect_points(cx, cz, w, d, ry, n=5)
        f = self.road_clear if kind == "road" else self.river_clear
        best = (1e9, None)
        for (x, z) in pts:
            v = f(x, z)
            if v[0] < best[0]:
                best = (v[0], v[1])
        return best


def rect_corners(cx, cz, w, d, ry):
    # Godot Basis(UP, ry): 로컬 (x,z) → (x cos + z sin, -x sin + z cos)
    c = math.cos(ry); s = math.sin(ry)
    out = []
    for (lx, lz) in [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)]:
        out.append((cx + lx * c + lz * s, cz - lx * s + lz * c))
    return out


def local_to_world(cx, cz, ry, lx, lz):
    c = math.cos(ry); s = math.sin(ry)
    return (cx + lx * c + lz * s, cz - lx * s + lz * c)


def rect_points(cx, cz, w, d, ry, n=4):
    pts = []
    for i in range(n + 1):
        for j in range(n + 1):
            lx = -w / 2 + w * i / n; lz = -d / 2 + d * j / n
            pts.append(local_to_world(cx, cz, ry, lx, lz))
    return pts


def poly_overlap(a, b):
    """볼록 다각형 SAT 겹침"""
    for poly in (a, b):
        n = len(poly)
        for i in range(n):
            x0, z0 = poly[i]; x1, z1 = poly[(i + 1) % n]
            nx, nz = z1 - z0, -(x1 - x0)
            pa = [nx * p[0] + nz * p[1] for p in a]
            pb = [nx * p[0] + nz * p[1] for p in b]
            if max(pa) <= min(pb) + 1e-6 or max(pb) <= min(pa) + 1e-6:
                return False
    return True
