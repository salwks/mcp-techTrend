"""placement-east 배치기: 실제 키트 크기(east_bounds.json)로 회전 사각형 겹침·지형·하천·도로를 검사하며 놓는다.

좌표: 게임 좌표(m). ry는 Godot Basis(UP, ry): 로컬 +z → 월드 (sin ry, cos ry), 로컬 +x → (cos ry, −sin ry).
"""
import json
import math
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
MAX_RY = math.radians(30)


def bkey(kit, params):
    return kit + "|" + json.dumps(params, sort_keys=True, ensure_ascii=False)


def wrap_half(a):
    """각을 (−π/2, π/2]로(앞뒤가 같은 것: 다리·담)."""
    while a > math.pi / 2:
        a -= math.pi
    while a <= -math.pi / 2:
        a += math.pi
    return a


def clamp_ry(a, lim=MAX_RY):
    return max(-lim, min(lim, a))


def ry_along(dx, dz):
    """로컬 x축을 방향 (dx,dz)에 맞추는 ry, (−π/2, π/2]."""
    return wrap_half(math.atan2(-dz, dx))


def ry_cross(dx, dz):
    """로컬 z축을 방향 (dx,dz)에 맞추는 ry, (−π/2, π/2] (다리)."""
    return wrap_half(math.atan2(dx, dz))


def l2w(x, z, ry, lx, lz):
    c, s = math.cos(ry), math.sin(ry)
    return x + lx * c + lz * s, z - lx * s + lz * c


class Rect:
    """회전 사각형(월드)."""
    __slots__ = ("cx", "cz", "ux", "uz", "vx", "vz", "hx", "hz")

    def __init__(self, x, z, ry, aabb, margin=0.0):
        x0, x1, z0, z1 = aabb
        lcx, lcz = (x0 + x1) / 2, (z0 + z1) / 2
        self.cx, self.cz = l2w(x, z, ry, lcx, lcz)
        c, s = math.cos(ry), math.sin(ry)
        self.ux, self.uz = c, -s
        self.vx, self.vz = s, c
        self.hx = (x1 - x0) / 2 + margin
        self.hz = (z1 - z0) / 2 + margin

    def corners(self):
        out = []
        for a, b in [(-1, -1), (1, -1), (1, 1), (-1, 1)]:
            out.append((self.cx + self.ux * self.hx * a + self.vx * self.hz * b,
                        self.cz + self.uz * self.hx * a + self.vz * self.hz * b))
        return out

    def samples(self, step=2.0):
        nx = max(2, int(math.ceil(2 * self.hx / step)) + 1)
        nz = max(2, int(math.ceil(2 * self.hz / step)) + 1)
        out = []
        for i in range(nx):
            a = -self.hx + 2 * self.hx * i / (nx - 1)
            for j in range(nz):
                b = -self.hz + 2 * self.hz * j / (nz - 1)
                out.append((self.cx + self.ux * a + self.vx * b, self.cz + self.uz * a + self.vz * b))
        return out

    def overlaps(self, o):
        dx, dz = o.cx - self.cx, o.cz - self.cz
        for ax, az in [(self.ux, self.uz), (self.vx, self.vz), (o.ux, o.uz), (o.vx, o.vz)]:
            ra = self.hx * abs(self.ux * ax + self.uz * az) + self.hz * abs(self.vx * ax + self.vz * az)
            rb = o.hx * abs(o.ux * ax + o.uz * az) + o.hz * abs(o.vx * ax + o.vz * az)
            if abs(dx * ax + dz * az) > ra + rb:
                return False
        return True


class Local:
    """한 장소 둘레(반경 R)의 하천·도로 선분만 걸러 빠르게 거리 계산."""

    def __init__(self, T, cx, cz, R):
        self.T = T
        self.rv = self._filter(T._river_segs, cx, cz, R + 150)
        self.rd = self._filter(T._road_segs, cx, cz, R + 150)
        # 하천 수면 y 표본(징검다리·나룻 높이)
        pts = []
        for r in T.rivers:
            for p in r["points"]:
                if abs(p[0] - cx) < R + 150 and abs(p[1] - cz) < R + 150:
                    pts.append((p[0], p[1], p[2], r["id"]))
        self.rpts = pts

    @staticmethod
    def _filter(segs, cx, cz, R):
        A, B, W, I = segs
        m = (np.minimum(A[:, 0], B[:, 0]) < cx + R) & (np.maximum(A[:, 0], B[:, 0]) > cx - R) & \
            (np.minimum(A[:, 1], B[:, 1]) < cz + R) & (np.maximum(A[:, 1], B[:, 1]) > cz - R)
        idx = np.nonzero(m)[0]
        return A[idx], B[idx], W[idx], [I[i] for i in idx]

    @staticmethod
    def _dist(segs, P):
        """P: (n,2) → (n, nseg) 거리, 가까운 점"""
        A, B, W, I = segs
        if len(A) == 0:
            return None
        AB = B - A
        L2 = (AB ** 2).sum(1)
        L2[L2 == 0] = 1e-9
        AP = P[:, None, :] - A[None, :, :]
        t = np.clip((AP * AB[None]).sum(2) / L2[None], 0, 1)
        C = A[None] + AB[None] * t[..., None]
        d = np.sqrt(((C - P[:, None, :]) ** 2).sum(2))
        return d, C

    def river_clear(self, pts):
        P = np.asarray(pts, float)
        r = self._dist(self.rv, P)
        if r is None:
            return np.full(len(P), 1e9)
        d, _ = r
        return (d - np.maximum(self.rv[2] / 2, 2.6)[None]).min(1)

    def road_clear(self, pts):
        P = np.asarray(pts, float)
        r = self._dist(self.rd, P)
        if r is None:
            return np.full(len(P), 1e9)
        d, _ = r
        return (d - (self.rd[2] / 2)[None]).min(1)

    def nearest_road(self, x, z):
        r = self._dist(self.rd, np.array([[x, z]], float))
        if r is None:
            return None
        d, C = r
        k = int(np.argmin(d[0] - self.rd[2] / 2))
        A, B, W, I = self.rd
        ab = B[k] - A[k]
        L = float(np.hypot(*ab)) or 1.0
        return float(d[0, k] - W[k] / 2), float(W[k]), I[k], (ab[0] / L, ab[1] / L), (float(C[0, k, 0]), float(C[0, k, 1]))

    def nearest_river(self, x, z):
        r = self._dist(self.rv, np.array([[x, z]], float))
        if r is None:
            return None
        d, C = r
        k = int(np.argmin(d[0]))
        A, B, W, I = self.rv
        ab = B[k] - A[k]
        L = float(np.hypot(*ab)) or 1.0
        return float(d[0, k]), float(W[k]), I[k], (ab[0] / L, ab[1] / L), (float(C[0, k, 0]), float(C[0, k, 1]))

    def water_y(self, x, z, rid=None):
        best = None
        for px, pz, py, i in self.rpts:
            if rid and i != rid:
                continue
            d = (px - x) ** 2 + (pz - z) ** 2
            if best is None or d < best[0]:
                best = (d, py)
        return best[1] if best else self.T.height(x, z)


DEFAULT_RULES = dict(max_drop=2.4, river_min=2.5, road_min=0.8, lu_bad=(5, 7), lu_bad_frac=0.25, margin=1.0,
                     road_pref=(2.0, 30.0), xmin=-2300.0)


class Placer:
    def __init__(self, T, bounds, catalog_fp):
        self.T = T
        self.bounds = bounds
        self.catalog_fp = catalog_fp
        self.items = []
        self.rects = []      # (Rect, item index)
        self.missing = {}
        self.counter = {}
        self.log = []

    # ---- 크기 ----
    def aabb(self, kit, params, fl=None):
        if fl and fl.get("aabb"):
            return fl["aabb"]
        k = bkey(kit, params)
        b = self.bounds.get(k)
        if b and "aabb" in b:
            return b["aabb"][:4]
        self.missing[k] = {"key": k, "kit": kit, "params": params}
        fp = self.catalog_fp.get(kit, (6.0, 6.0))
        return [-fp[0] / 2, fp[0] / 2, -fp[1] / 2, fp[1] / 2]

    def tris(self, kit, params):
        b = self.bounds.get(bkey(kit, params))
        return b["tris"] if b else 0

    # ---- 검사 ----
    def check(self, L, pieces, x, z, ry, rules, ignore_overlap=False):
        """pieces = [(kit, params, lx, lz, lry, flags)] — 묶음 전체를 (x,z,ry)에 놓을 때 문제 없나.
        반환 (ok, drop, info)"""
        R = dict(DEFAULT_RULES)
        R.update(rules or {})
        allpts = []
        rects = []
        for kit, params, lx, lz, lry, fl in pieces:
            wx, wz = l2w(x, z, ry, lx, lz)
            rect = Rect(wx, wz, ry + lry, self.aabb(kit, params, fl))
            rects.append((rect, fl))
            if fl.get("nocheck"):
                continue
            pts = rect.samples(2.0)
            if fl.get("ground", True):
                allpts.extend(pts)
            if min(p[0] for p in pts) < R["xmin"]:
                return False, 0, "xmin"
            rc = L.river_clear(pts)
            if rc.min() < fl.get("river_min", R["river_min"]):
                return False, 0, "river"
            if "river_max" in fl and rc.min() > fl["river_max"]:
                return False, 0, "river_far"
            dc = L.road_clear(pts)
            if dc.min() < fl.get("road_min", R["road_min"]):
                return False, 0, "road"
            lus = [self.T.landuse(px, pz) for px, pz in pts]
            bad = sum(1 for u in lus if u in R["lu_bad"]) / len(lus)
            if bad > R["lu_bad_frac"] or (5 in lus and fl.get("no_water", True)):
                return False, 0, "landuse"
            if not ignore_overlap:
                big = Rect(wx, wz, ry + lry, self.aabb(kit, params, fl), fl.get("margin", R["margin"]))
                for o, _ in self.rects:
                    if abs(o.cx - big.cx) < 60 and abs(o.cz - big.cz) < 60 and big.overlaps(o):
                        return False, 0, "overlap"
        if allpts:
            hs = [self.T.height(px, pz) for px, pz in allpts]
            drop = max(hs) - min(hs)
            if drop > R["max_drop"]:
                return False, drop, "drop"
        else:
            drop = 0.0
        return True, drop, rects

    # ---- 놓기 ----
    def new_id(self, grp, kind):
        k = (grp, kind)
        self.counter[k] = self.counter.get(k, 0) + 1
        return f"ea_{grp}_{kind}_{self.counter[k]:02d}"

    def commit(self, pieces, x, z, ry, group, gcode, y=None):
        out = []
        for kit, params, lx, lz, lry, fl in pieces:
            wx, wz = l2w(x, z, ry, lx, lz)
            if fl.get("reserve"):
                # 담 안 마당 등: 다른 것이 들어오지 못하게 자리만 잡는다(배치 파일에는 쓰지 않음)
                self.rects.append((Rect(wx, wz, ry + lry, fl["aabb"]), -1))
                continue
            kind = fl.get("kind") or kit.split("/")[-1]
            it = {
                "id": fl.get("id") or self.new_id(gcode, kind),
                "kit": kit, "params": params,
                "x": round(wx, 2), "z": round(wz, 2), "ry": round(ry + lry, 4),
                "y": fl.get("y", y),
                "flatten": fl.get("flatten", True),
                "clear_veg": fl.get("clear_veg", True),
                "group": group,
                "_cat": fl.get("cat", "house"), "_label": fl.get("label"), "_bkey": bkey(kit, params),
                "_aabb": self.aabb(kit, params, fl), "_tris": 0,
            }
            self.items.append(it)
            rect = Rect(wx, wz, ry + lry, self.aabb(kit, params, fl))
            self.rects.append((rect, len(self.items) - 1))
            out.append(it)
        return out

    def place_fixed(self, L, pieces, x, z, ry, group, gcode, rules=None, y=None, force=True):
        ok, drop, info = self.check(L, pieces, x, z, ry, rules)
        if not ok:
            self.log.append(f"[fixed] {group} {pieces[0][0]} @({x:.0f},{z:.0f}) 검사 실패: {info} (drop {drop:.1f})" + (" — 강제" if force else " — 생략"))
            if not force:
                return None
        return self.commit(pieces, x, z, ry, group, gcode, y)

    def place_search(self, L, pieces, cx, cz, R, group, gcode, rng, rules=None, face="road", n=260,
                     pref=None, north_bias=1.5, ry_fixed=None, road_pref=None, group_y=False, allow_cross=False):
        """(cx,cz) 반경 R 안에서 놓을 자리를 찾는다. face='road'면 가까운 길에 나란히(±30°)."""
        Rr = dict(DEFAULT_RULES)
        Rr.update(rules or {})
        rp = road_pref or Rr["road_pref"]
        best = None
        px, pz = pref or (cx, cz)
        for i in range(n):
            if i == 0:
                x, z = cx, cz
            else:
                a = rng.uniform(0, 2 * math.pi)
                r = R * math.sqrt(rng.uniform(0, 1))
                x, z = cx + r * math.cos(a), cz + r * math.sin(a)
            nr = L.nearest_road(x, z)
            if ry_fixed is not None:
                ry = ry_fixed + rng.uniform(-0.08, 0.08)
            elif face == "road" and nr and nr[0] < 40:
                ry = clamp_ry(ry_along(*nr[3]))
            else:
                ry = rng.uniform(-0.15, 0.15)
            ok, drop, info = self.check(L, pieces, x, z, ry, rules)
            if not ok:
                continue
            if not allow_cross and nr and nr[0] < 80:
                # 길과 집 사이에 내가 있으면(다리 없이 건너야 하면) 버린다
                line = [(x + (nr[4][0] - x) * t / 10.0, z + (nr[4][1] - z) * t / 10.0) for t in range(11)]
                if L.river_clear(line).min() < 0:
                    continue
            score = drop * 0.8 + math.hypot(x - px, z - pz) / max(R, 1) * 2.0 + rng.uniform(0, 0.4)
            if nr:
                dd = nr[0]
                if dd < rp[0]:
                    score += 1.0
                elif dd > rp[1]:
                    score += (dd - rp[1]) / 20.0
                # 길이 집 남쪽(카메라 쪽, 정면 쪽)에 있으면 좋다
                if nr[4][1] < z - 2:
                    score += north_bias
            if best is None or score < best[0]:
                best = (score, x, z, ry)
        if best is None:
            self.log.append(f"[search] {group} {pieces[0][0]} 자리 못 찾음 (중심 {cx:.0f},{cz:.0f} R{R})")
            return None
        y = None
        if group_y:
            # 묶음(관아·역) 전체를 한 높이로 고른다: 조각 중심 높이의 중앙값
            hs = sorted(self.T.height(*l2w(best[1], best[2], best[3], lx, lz)) for _, _, lx, lz, _, _ in pieces)
            y = round(hs[len(hs) // 2], 2)
        return self.commit(pieces, best[1], best[2], best[3], group, gcode, y)
