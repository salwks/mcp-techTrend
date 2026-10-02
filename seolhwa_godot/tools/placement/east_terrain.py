"""placement-east 지형 도우미: region.json·height.png·landuse.png를 읽어 높이·토지이용·하천·도로 거리를 준다.

좌표는 모두 게임 좌표(m). 계약서 §1·§5.
"""
import json
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA = os.path.join(ROOT, "region_data", "JL_NAMWON_UNBONG")


class Terrain:
    def __init__(self):
        self.region = json.load(open(os.path.join(DATA, "region.json"), encoding="utf-8"))
        h = self.region["height"]
        self.hm = h
        im = Image.open(os.path.join(DATA, h["file"]))
        a = np.array(im).astype(np.float32)
        self.H = h["y_min"] + a / 65535.0 * (h["y_max"] - h["y_min"])
        lu = self.region["landuse"]
        self.lm = lu
        self.L = np.array(Image.open(os.path.join(DATA, lu["file"])))
        self.rivers = self.region["rivers"]
        self.roads = self.region["roads"]
        # 선분 묶음(벡터 거리 계산용)
        self._river_segs = self._segs([(r["points"], r["width_m"], r["id"]) for r in self.rivers])
        self._road_segs = self._segs([(r["points"], r["width_m"], r["id"]) for r in self.roads])

    @staticmethod
    def _segs(lines):
        A, B, W, I = [], [], [], []
        for pts, w, rid in lines:
            for p, q in zip(pts[:-1], pts[1:]):
                A.append(p[:2]); B.append(q[:2]); W.append(w); I.append(rid)
        return np.array(A, float), np.array(B, float), np.array(W, float), I

    # ---- 높이(쌍선형) ----
    def height(self, x, z):
        h = self.hm
        fx = (x - h["x0"]) / h["cell"]; fz = (z - h["z0"]) / h["cell"]
        i = int(math.floor(fx)); j = int(math.floor(fz))
        i = min(max(i, 0), h["w"] - 2); j = min(max(j, 0), h["h"] - 2)
        tx = fx - i; tz = fz - j
        H = self.H
        return float((H[j, i] * (1 - tx) + H[j, i + 1] * tx) * (1 - tz) + (H[j + 1, i] * (1 - tx) + H[j + 1, i + 1] * tx) * tz)

    def landuse(self, x, z):
        l = self.lm
        i = int(round((x - l["x0"]) / l["cell"])); j = int(round((z - l["z0"]) / l["cell"]))
        i = min(max(i, 0), l["w"] - 1); j = min(max(j, 0), l["h"] - 1)
        return int(self.L[j, i])

    def slope_range(self, corners):
        """주어진 점들의 높이 최대-최소(m)."""
        hs = [self.height(x, z) for x, z in corners]
        return max(hs) - min(hs)

    # ---- 거리 ----
    @staticmethod
    def _seg_dist(segs, x, z):
        A, B, W, I = segs
        P = np.array([x, z])
        AB = B - A
        L2 = (AB ** 2).sum(1)
        L2[L2 == 0] = 1e-9
        t = np.clip(((P - A) * AB).sum(1) / L2, 0, 1)
        C = A + AB * t[:, None]
        d = np.sqrt(((C - P) ** 2).sum(1))
        k = int(np.argmin(d))
        return float(d[k]), float(W[k]), I[k], AB[k] / math.sqrt(L2[k]), C[k]

    def river_clear(self, x, z):
        """하천 가장자리까지 거리(음수 = 물 안). 땅에 판 물길 반폭은 max(w/2, 2.6)."""
        A, B, W, I = self._river_segs
        P = np.array([x, z])
        AB = B - A
        L2 = (AB ** 2).sum(1); L2[L2 == 0] = 1e-9
        t = np.clip(((P - A) * AB).sum(1) / L2, 0, 1)
        C = A + AB * t[:, None]
        d = np.sqrt(((C - P) ** 2).sum(1)) - np.maximum(W / 2, 2.6)
        return float(d.min())

    def nearest_river(self, x, z):
        return self._seg_dist(self._river_segs, x, z)

    def road_clear(self, x, z):
        A, B, W, I = self._road_segs
        P = np.array([x, z])
        AB = B - A
        L2 = (AB ** 2).sum(1); L2[L2 == 0] = 1e-9
        t = np.clip(((P - A) * AB).sum(1) / L2, 0, 1)
        C = A + AB * t[:, None]
        d = np.sqrt(((C - P) ** 2).sum(1)) - W / 2
        return float(d.min())

    def nearest_road(self, x, z):
        """(거리, 폭, id, 방향 단위벡터, 가장 가까운 점)"""
        return self._seg_dist(self._road_segs, x, z)

    def road(self, rid):
        for r in self.roads:
            if r["id"] == rid:
                return r
        raise KeyError(rid)

    def river(self, rid):
        for r in self.rivers:
            if r["id"] == rid:
                return r
        raise KeyError(rid)


def polyline_at(points, s):
    """폴리라인을 따라 길이 s 지점의 (x, z, 방향)."""
    acc = 0.0
    for p, q in zip(points[:-1], points[1:]):
        dx = q[0] - p[0]; dz = q[1] - p[1]
        L = math.hypot(dx, dz)
        if L == 0:
            continue
        if acc + L >= s:
            t = (s - acc) / L
            return p[0] + dx * t, p[1] + dz * t, (dx / L, dz / L)
        acc += L
    p, q = points[-2], points[-1]
    L = math.hypot(q[0] - p[0], q[1] - p[1]) or 1
    return q[0], q[1], ((q[0] - p[0]) / L, (q[1] - p[1]) / L)


def polyline_len(points):
    return sum(math.hypot(q[0] - p[0], q[1] - p[1]) for p, q in zip(points[:-1], points[1:]))


def polyline_project(points, x, z):
    """점을 폴리라인에 투영 → (호 길이 s, 거리)."""
    best = (1e18, 0.0)
    acc = 0.0
    for p, q in zip(points[:-1], points[1:]):
        dx = q[0] - p[0]; dz = q[1] - p[1]
        L2 = dx * dx + dz * dz
        if L2 == 0:
            continue
        t = max(0.0, min(1.0, ((x - p[0]) * dx + (z - p[1]) * dz) / L2))
        cx = p[0] + dx * t; cz = p[1] + dz * t
        d = math.hypot(x - cx, z - cz)
        if d < best[0]:
            best = (d, acc + t * math.sqrt(L2))
        acc += math.sqrt(L2)
    return best[1], best[0]
