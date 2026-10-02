#!/usr/bin/env python3
# 남원 읍내 배치 생성기 (placement-namwon, 3단계).
#   python3 tools/placement/namwon.py        → region_data/JL_NAMWON_UNBONG/placement_namwon.json + 검사·통계
#   python3 tools/placement/namwon_plan.py   → shots/placement/namwon_plan*.png (평면도)
# 손으로 정한 랜드마크(읍성·관아·객사·광한루원·향교·다리) + 규칙으로 채우는 민가·장터·담·텃밭·마당 소품. 결정적(SEED 고정).
# 좌표는 게임 좌표(m), ry는 Godot Basis(UP, ry) — 로컬 +z(정면)가 남쪽일 때 0.
import json, math, os, random, sys

sys.path.insert(0, os.path.dirname(__file__))
from namwon_data import Region, Fields, add_village_dist, ROOT, RDIR, rect_corners, rect_points, poly_overlap, local_to_world

SEED = 1870
OUT = os.path.join(RDIR, "placement_namwon.json")

# ── 읍성 기하 (region.json 네 문 ±93과 같게) ──
CX, CZ = -3227.8, 248.8
SIDE = 186.0
HALF = SIDE / 2
WALL_T = 4.6
INNER = HALF - WALL_T
ONGSEONG = {"S": "front", "N": "west", "E": "south", "W": "north"}   # terrain-data 길과 맞춘 옹성 출구(총괄 지정)

# 작업 영역(래스터)
AX0, AZ0, AX1, AZ1 = -3560.0, -260.0, -2700.0, 640.0

# ── 모델 크기(footprint, 삼각형) — kit/*/catalog.json(3단계) ──
FP = {
    ("village/house_compound", "small"): ((14.8, 14.0), 8780),
    ("village/house_compound", "medium"): ((20.0, 16.8), 12972),
    ("village/house_compound", "large"): ((24.8, 21.8), 14792),
    ("village/choga", None): ((8.2, 6.4), 1984),
    ("village/choga", "gourd"): ((7.6, 6.4), 2488),
    ("village/giwa", "plain"): ((10.8, 8.8), 3856),
    ("village/jumak", None): ((11.2, 9.6), 4410),
    ("village/market_shop", None): ((7.0, 6.4), 1700),
    ("village/market_shop", "onggi"): ((7.0, 6.4), 2480),
    ("village/market_shop", "cloth"): ((5.5, 6.4), 1216),
    ("village/jwapan", None): ((2.4, 2.0), 608),
    ("village/jwapan", "noawn"): ((2.4, 2.0), 288),
    ("village/well", None): ((2.4, 2.0), 392),
    ("village/well", "roof"): ((2.4, 2.0), 492),
    ("village/haystack", None): ((2.4, 2.4), 376),
    ("village/jangseung", None): ((1.2, 1.2), 450),
    ("village/stone_jangseung", None): ((1.2, 1.2), 780),
    ("village/sotdae", None): ((2.7, 1.0), 468),
    ("village/seonghwangdang", None): ((5.5, 4.6), 1928),
    ("village/narutbae", None): ((1.9, 6.6), 240),
    ("village/ppallaeteo", None): ((4.9, 2.6), 536),
    ("village/props", None): ((2.0, 1.4), 300),
    ("village/firewood", None): ((1.9, 1.2), 720),
    ("village/jige", None): ((0.9, 1.1), 350),
    ("village/teotbat", None): ((4.8, 3.5), 1646),
    ("village/teotbat", "small"): ((3.8, 2.9), 1028),
    ("nature/garden_plot", None): ((6.3, 4.3), 748),
    ("village/yard_props", "manure_coop"): ((4.4, 3.0), 548),
    ("village/yard_props", "jars"): ((3.6, 2.2), 1288),
    ("village/yard_props", "work"): ((4.6, 3.0), 708),
    ("village/yard_props", "woodpile"): ((4.6, 3.2), 1896),
    ("village/village_square", None): ((8.0, 7.6), 2296),
    ("village/torch_post", None): ((0.7, 0.7), 262),
}

BUILDING_KITS = {"village/house_compound", "village/choga", "village/giwa", "village/jumak", "village/market_shop"}
HOUSE_KITS = {"village/house_compound", "village/choga", "village/giwa"}


class Placer:
    BUCKET = 16.0

    def __init__(self, R, F):
        self.R = R; self.F = F
        self.items = []
        self.shapes = []      # (poly, item_id, kind)
        self.grid = {}        # 버킷 → shape 인덱스
        self.tris = []        # (x, z, tris)
        self.rejects = {}

    def _bk(self, poly):
        xs = [p[0] for p in poly]; zs = [p[1] for p in poly]
        b = self.BUCKET
        for i in range(int(math.floor(min(xs) / b)), int(math.floor(max(xs) / b)) + 1):
            for j in range(int(math.floor(min(zs) / b)), int(math.floor(max(zs) / b)) + 1):
                yield (i, j)

    def add_shape(self, poly, id, kind):
        k = len(self.shapes)
        self.shapes.append((poly, id, kind))
        for bk in self._bk(poly):
            self.grid.setdefault(bk, []).append(k)

    def add(self, id, kit, params, x, z, ry=0.0, rects=None, tris=0, y=None, flatten=True, clear_veg=True,
            group="남원 읍내", note=None, kind="building", tri_pts=None, footprint=None):
        it = {"id": id, "kit": kit, "params": params, "x": round(x, 2), "z": round(z, 2), "ry": round(ry, 4),
              "y": (round(y, 3) if y is not None else None), "flatten": flatten, "clear_veg": clear_veg, "group": group}
        if footprint:
            it["footprint"] = [round(footprint[0], 2), round(footprint[1], 2)]
        if note:
            it["note"] = note
        self.items.append(it)
        for (lx, lz, w, d) in (rects or []):
            cx, cz = local_to_world(x, z, ry, lx, lz)
            self.add_shape(rect_corners(cx, cz, w, d, ry), id, kind)
        if tri_pts:
            self.tris.extend(tri_pts)
        else:
            self.tris.append((x, z, tris))
        return it

    def keepout(self, name, cx, cz, w, d, ry=0.0):
        self.add_shape(rect_corners(cx, cz, w, d, ry), name, "keepout")

    def collides(self, poly, skip_keepout=False):
        seen = set()
        for bk in self._bk(poly):
            for k in self.grid.get(bk, ()):
                if k in seen:
                    continue
                seen.add(k)
                q, qid, kind = self.shapes[k]
                if skip_keepout and kind == "keepout":
                    continue
                if poly_overlap(poly, q):
                    return qid
        return None

    def check_site(self, x, z, w, d, ry=0.0, gap=1.2, gz=None, road_min=1.0, river_min=4.0, lu_min=0.6, lu_ok=(6, 4),
                   slope_max=2.5, skip_keepout=False):
        F = self.F
        gz = gap if gz is None else gz
        poly = rect_corners(x, z, w + 2 * gap, d + 2 * gz, ry)
        pts = rect_points(x, z, w, d, ry, n=4)
        if min(F.road(px, pz) for (px, pz) in pts) < road_min:
            return "길"
        if min(F.river(px, pz) for (px, pz) in pts) < river_min:
            return "물"
        if lu_ok is not None:
            ok = sum(1 for (px, pz) in pts if F.landuse(px, pz) in lu_ok) / len(pts)
            if ok < lu_min:
                return "토지이용"
        hs = [F.height(px, pz) for (px, pz) in pts]
        if max(hs) - min(hs) > slope_max:
            return "경사"
        c = self.collides(poly, skip_keepout)
        if c:
            return "겹침"
        return None

    def reject(self, why):
        self.rejects[why] = self.rejects.get(why, 0) + 1


def in_walls(x, z, m=0.0):
    return abs(x - CX) < HALF + m and abs(z - CZ) < HALF + m


# ─────────────────────────────── 랜드마크 ───────────────────────────────
def eupseong_pieces():
    """kit/landmark/namwon_eupseong.gd layout() 기하 → [(kit, side, x, z, ry, w, d, lz_off, tris)]"""
    out = []
    side_ry = {"S": 0.0, "E": math.pi / 2, "N": math.pi, "W": -math.pi / 2}
    zc = HALF - WALL_T / 2
    gate_w = 16.0
    for sd in ["S", "E", "N", "W"]:
        ry = side_ry[sd]

        def put(kit, u, zl, w, d, lzo, tris):
            x, z = local_to_world(CX, CZ, ry, u, zl)
            out.append((kit, sd, x, z, ry, w, d, lzo, tris))
        put("seong_corner", HALF - WALL_T / 2, zc, 5.0, 5.0, 0, 274)
        put("seongmun", 0.0, zc, 28.4, 19.3, (16.5 - 2.8) / 2, 6518)
        g0, g1 = -HALF + WALL_T, HALF - WALL_T
        for (a, b) in [(g0, -gate_w / 2), (gate_w / 2, g1)]:
            L = b - a
            n = max(1, math.ceil(L / 24.0))
            for i in range(n):
                s0 = a + L * i / n; s1 = a + L * (i + 1) / n
                put("seong_wall", (s0 + s1) / 2, zc, s1 - s0, 5.1, 0, int(804 * (s1 - s0) / 20))
        for i in range(2):
            u = -HALF + SIDE * (i + 0.5) / 2
            put("seong_chi", u, HALF, 8.4, 6.4, 3.0, 476)
    return out


def wall_pieces(pts, closed, gaps, seed, h=2.2, seg=12.0):
    """kit/landmark/_common.gd wall_pieces() 옮김"""
    out = []
    n = len(pts)
    m = n if closed else n - 1
    k = 0
    for i in range(m):
        a = pts[i]; b = pts[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        dx, dz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        cuts = []
        for g in gaps:
            t = (g[0] - a[0]) * dx + (g[1] - a[1]) * dz
            off = abs((g[0] - a[0]) * dz - (g[1] - a[1]) * dx)
            if off < 1.0 and 0 < t < L:
                cuts.append((t - g[2], t + g[2]))
        cuts.sort()
        spans = []
        s0 = 0.0
        for c in cuts:
            if c[0] > s0 + 0.3:
                spans.append((s0, c[0]))
            s0 = c[1]
        if L > s0 + 0.3:
            spans.append((s0, L))
        for (p0, p1) in spans:
            sl = p1 - p0
            ns = max(1, math.ceil(sl / seg))
            for j in range(ns):
                t0 = p0 + sl * j / ns; t1 = p0 + sl * (j + 1) / ns
                c = ((a[0] + dx * (t0 + t1) / 2), (a[1] + dz * (t0 + t1) / 2))
                out.append({"params": {"seed": seed + k, "length": round(t1 - t0 + 0.25, 2), "height": h},
                            "x": c[0], "z": c[1], "ry": -math.atan2(dz, dx)})
                k += 1
    return out


def place_landmarks(P, R, rng):
    notes = {}
    pieces = eupseong_pieces()
    P.add("nw_eupseong", "landmark/namwon_eupseong", {"seed": 1870, "side": SIDE, "ongseong": dict(ONGSEONG)}, CX, CZ, 0.0,
          rects=[], kind="landmark", flatten=False, group="남원읍성",
          note="방형 평지 읍성. 4문 남 완월루·북 공신루·서 망미루·동 향일루. 옹성 출구 S정면·N서·E남·W북(terrain-data 길과 맞춤). 성 안은 이미 고름 → flatten 끔",
          tri_pts=[(p[2], p[3], p[8]) for p in pieces])
    for (kit, sd, x, z, ry, w, d, lzo, tris) in pieces:
        cx, cz = local_to_world(x, z, ry, 0, lzo)
        P.add_shape(rect_corners(cx, cz, w, d, ry), "읍성_" + sd + "_" + kit, "wall")
    # 성문 안쪽 광장(작게)·남문 밖
    for (gx, gz, w, d) in [(CX, CZ + INNER - 7, 16, 12), (CX, CZ - INNER + 7, 16, 12), (CX + INNER - 7, CZ, 12, 16), (CX - INNER + 7, CZ, 12, 16)]:
        P.keepout("문안광장", gx, gz, w, d)
    P.keepout("남문밖광장", CX, CZ + HALF + 20, 18, 12)

    # 관아 일곽
    gx, gz = CX + 44.0, CZ - 44.5
    P.add("nw_gwana", "landmark/gwana", {"seed": 1871, "width": 60, "depth": 72}, gx, gz, 0.0,
          rects=[(0, 0, 62, 78)], tris=34536, group="남원도호부 관아", kind="landmark", footprint=(62, 78),
          note="동헌·내아·내외삼문 일곽. 위치 가설(성 안 동북). 외삼문 (−3183.8, 240.5)에 관아 앞길이 닿는다")
    # 객사 용성관
    kx = CX - 44.0
    wall_z0, wall_z1 = CZ - 50.0, CZ - 6.0
    kw = 58.0
    P.add("nw_gaeksa", "landmark/gaeksa", {"seed": 1872, "jeongdang_bays": 5}, kx, CZ - 38.8, 0.0,
          rects=[(0, 0, 47, 14)], tris=13880, group="객사 용성관", kind="landmark", footprint=(47, 14),
          note="용성관: 정당 5칸 + 익헌 둘. region.json yongseonggwan(−3271.8, 210)")
    P.add("nw_gaeksa_samun", "landmark/samun", {"seed": 1873, "kind": "outer", "name": "용성관"}, kx, wall_z1, 0.0,
          rects=[(0, 0, 11.0, 5.6)], tris=4290, group="객사 용성관", kind="landmark")
    walls = wall_pieces([(kx - kw / 2, wall_z0), (kx + kw / 2, wall_z0), (kx + kw / 2, wall_z1), (kx - kw / 2, wall_z1)],
                        True, [(kx, wall_z1, 4.8)], 1880, 2.2)
    for i, w in enumerate(walls):
        P.add("nw_gaeksa_wall_%02d" % i, "landmark/gwana_wall", w["params"], w["x"], w["z"], w["ry"],
              rects=[(0, 0, w["params"]["length"], 1.1)], tris=int(384 * w["params"]["length"] / 12), group="객사 용성관",
              kind="wall", flatten=False)
    # 객사 담 안 마당(빈 채로)
    P.keepout("객사마당", kx, (CZ - 31.8 + wall_z1) / 2, kw - 2, wall_z1 - (CZ - 31.8) - 2)

    # 광한루원
    lx, lz = -3271.4, 450.1
    pw, pd = 84.0, 40.0
    px, pz = -3279.0, 483.0
    bx = -pw * 0.18
    P.add("nw_gwanghallu_pond", "landmark/gwanghallu_pond", {"seed": 1582, "width": pw, "depth": pd, "bridge": True}, px, pz, 0.0,
          rects=[(0, 0, pw + 3, pd + 3), (bx, 0, 2.8, 57.0)], tris=8844, group="광한루원", kind="water",
          note="못 84×40(1870년 정원은 지금보다 작았다는 가설) + 삼신산 섬 셋 + 오작교(모델에 포함). footprint를 일부러 안 줌(로더가 시작 때 지어 물자리를 판다)")
    P.add("nw_gwanghallu", "landmark/gwanghallu", {"seed": 1626, "iklu": True}, lx, lz, 0.0,
          rects=[(4.0, 0, 30.0, 14.4)], tris=13102, group="광한루원", kind="landmark",
          note="OSM 위치 그대로(확정). 못 북쪽 둑, 익루는 동쪽")
    # 광한루원 정원(풀밭) 안은 민가를 들이지 않는다
    P.keepout("광한루원", -3277, 474, 110, 64)

    # 향교 — region.json namwon_hyanggyo(−3235.3, −97.8) 그대로, 겹치면 가까운 자리
    hw, hd = 36.0, 50.0
    best = None
    for ix in range(-12, 13):
        for jz in range(-12, 13):
            x = -3235.3 + ix * 2.0; z = -97.8 + jz * 2.0
            d = math.hypot(ix * 2.0, jz * 2.0)
            if best and d >= best[0]:
                continue
            why = P.check_site(x, z, hw + 2, hd + 6, 0.0, gap=0.5, road_min=2.0, river_min=4.0, lu_ok=None, slope_max=8.0)
            if why is None:
                best = (d, x, z)
    _, hx, hz = best
    P.add("nw_hyanggyo", "landmark/hyanggyo", {"seed": 1392, "width": hw, "depth": hd}, hx, hz, 0.0,
          rects=[(0, 0, hw + 2, hd + 6)], tris=19186, group="남원향교", kind="landmark", footprint=(hw + 2, hd + 6),
          note="가설 위치: 읍성 북쪽 광치천 건너 산기슭(region.json namwon_hyanggyo). 전묘후학, 남향")
    notes["hyanggyo"] = (round(hx, 1), round(hz, 1), "옮긴 거리 %.1f" % best[0])
    return notes


# ─────────────────────────────── 민가 ───────────────────────────────
HOUSE = {
    "large": ("village/house_compound", lambda s: {"seed": s, "size": "large"}, ("village/house_compound", "large")),
    "medium": ("village/house_compound", lambda s: {"seed": s, "size": "medium"}, ("village/house_compound", "medium")),
    "small": ("village/house_compound", lambda s: {"seed": s, "size": "small"}, ("village/house_compound", "small")),
    "giwa": ("village/giwa", lambda s: {"seed": s, "plain": True, "w": 7.2, "bays": 3}, ("village/giwa", "plain")),
    "choga": ("village/choga", lambda s: {"seed": s}, ("village/choga", None)),
    "choga_gourd": ("village/choga", lambda s: {"seed": s, "w": 5.4, "gourd": True}, ("village/choga", "gourd")),
}
# 단독 초가·기와는 마당·장독 자리까지 조금 넓게(겹침 검사용)
APRON = {"choga": (1.6, 3.0), "choga_gourd": (1.6, 3.0), "giwa": (1.0, 3.0)}
W_IN = {"large": 3, "medium": 4, "giwa": 3, "small": 2, "choga": 2}
W_OUT = {"small": 5, "medium": 3, "large": 0.6, "choga": 3, "choga_gourd": 1, "giwa": 0.6}
W_EDGE = {"small": 4, "choga": 4, "choga_gourd": 1, "medium": 1}


def house_dims(t):
    kit, _, key = HOUSE[t]
    (w, d), tris = FP[key]
    ax, az = APRON.get(t, (0, 0))
    return w + ax, d + az, tris, (w, d)


class Houses:
    def __init__(self, P, rng):
        self.P = P; self.rng = rng; self.n = 0; self.stat = {}

    def weights(self, x, z):
        if in_walls(x, z, -2):
            return W_IN, "남원 읍내(성 안)"
        return W_OUT, "남원 읍내(성 밖)"

    def try_put(self, t, x, z, ry, tag, gap=1.0, gz=None, road_min=1.0, lu_min=0.7, lu_ok=(6,)):
        w, d, tris, fp = house_dims(t)
        why = self.P.check_site(x, z, w, d, ry, gap=gap, gz=gz, road_min=road_min, lu_min=lu_min, lu_ok=lu_ok, slope_max=3.0)
        if why:
            self.P.reject(why)
            return False
        self.n += 1
        kit, pf, _ = HOUSE[t]
        _, group = self.weights(x, z)
        self.P.add("nw_house_%03d" % self.n, kit, pf(100 + self.n), x, z, ry, rects=[(0, 0, w, d)], tris=tris, group=group,
                   note="%s / %s" % (tag, t), footprint=fp)
        self.stat[tag] = self.stat.get(tag, 0) + 1
        return True

    def pick(self, x, z, edge=False):
        W, _ = self.weights(x, z)
        if edge and not in_walls(x, z):
            W = W_EDGE
        return self.rng.choices(list(W.keys()), list(W.values()))[0]

    def frontage(self, roads, step=1.0, only=None):
        """길 양쪽에 길과 나란히 집을 늘어놓는다(길에서 1.5~2.5m). 집 방향은 남향 기준 ±25° 안에서 길과 맞춘다."""
        R = self.P.R
        for rd in R.roads:
            if rd["id"] not in roads:
                continue
            pts = rd["points"]
            hw = rd["width_m"] / 2
            for side in (1, -1):
                carry = 0.0
                for i in range(len(pts) - 1):
                    a, b = pts[i], pts[i + 1]
                    L = math.hypot(b[0] - a[0], b[1] - a[1])
                    if L < 0.5:
                        continue
                    ux, uz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
                    nx, nz = uz * side, -ux * side          # 길 바깥쪽 법선
                    # 집 방향: 길과 나란하도록. 동서길이면 ry=atan2(-uz,ux) 근처, 남북길이면 0
                    ang = math.atan2(-uz, ux)                # 길 방향을 x축으로 보는 회전
                    while ang > math.pi / 2: ang -= math.pi
                    while ang < -math.pi / 2: ang += math.pi
                    ry = ang if abs(ang) <= math.radians(25) else 0.0
                    t = carry
                    while t < L:
                        x, z = a[0] + ux * t, a[1] + uz * t
                        if not (AX0 + 20 < x < AX1 - 20 and AZ0 + 20 < z < AZ1 - 20):
                            t += 4.0; continue
                        # 마을 터에서 25m 넘게 떨어진 길(들판·산길)은 건너뛴다
                        if self.P.F.village_dist(x, z) > 25 and not in_walls(x, z):
                            t += 4.0; continue
                        south = nz > 0.5      # 길 남쪽(카메라 쪽) 집
                        if only:
                            ty = self.rng.choice(only)
                        elif south and not in_walls(x, z):
                            ty = self.rng.choices(["choga", "choga_gourd", "small"], [3, 1, 2])[0]
                        else:
                            ty = self.pick(x, z, edge=False)
                        w, d, _, _ = house_dims(ty)
                        # 회전 사각형의 법선 방향 반폭
                        c, s = math.cos(ry), math.sin(ry)
                        ex = abs((nx * c - nz * s)) * w / 2 + abs((nx * s + nz * c)) * d / 2
                        along = abs((ux * c - uz * s)) * w / 2 + abs((ux * s + uz * c)) * d / 2
                        # 길 남쪽 집은 카메라–플레이어 시선에 걸리지 않게 더 물린다(가림 반투명이 겹치지 않게)
                        set_back = hw + (self.rng.uniform(4.5, 6.0) if south else self.rng.uniform(1.3, 2.6))
                        cx, cz = x + ux * along + nx * (set_back + ex), z + uz * along + nz * (set_back + ex)
                        if self.try_put(ty, cx, cz, ry, "길가:" + rd["id"], gap=0.8, road_min=1.0, lu_min=0.75, lu_ok=(6, 3, 1, 2, 4)):
                            t += 2 * along + self.rng.choice([1.6, 1.6, 2.2, 3.4])
                        else:
                            t += step
                    carry = max(0.0, t - L)

    def pack(self, x0, z0, x1, z1, tag, lane=3.4):
        """남은 마을 터를 줄 단위로 채운다(줄 사이 골목 lane m, 집 사이 1.6~3.4m)."""
        z = z0
        while z < z1:
            x = x0 + self.rng.uniform(0, 4)
            row_d = 0
            while x < x1:
                ty = self.pick(x, z, edge=True)
                w, d, _, _ = house_dims(ty)
                cx, cz = x + w / 2, z + d / 2 + self.rng.uniform(0, 1.2)
                if self.try_put(ty, cx, cz, self.rng.uniform(-0.06, 0.06), tag, gap=0.8, gz=lane / 2, lu_min=0.75):
                    x += w + self.rng.choice([1.6, 2.0, 2.6, 3.4])
                    row_d = max(row_d, d)
                else:
                    x += 2.0
            z += 3.0


def place_houses(P, R, rng):
    H = Houses(P, rng)
    town_roads = {"namwon_eup_street", "namwon_eup_street_ew", "namwon_gaeksa_lane", "namwon_gwana_lane", "namwon_market_lane",
                  "namwon_gurye_road", "tongyeong_byeolro", "namwon_north_road", "namwon_west_gate_lane"}
    H.frontage(town_roads)
    H.frontage(town_roads, step=0.5, only=["choga", "choga", "choga_gourd"])   # 둘째 판: 남은 길가 틈을 초가로
    H.pack(AX0 + 140, AZ0 + 150, AX1 - 80, AZ1 - 100, "마을 터 채우기")
    return H


# ─────────────────────────────── 장터 ───────────────────────────────
GOODS = ["onggi", "cloth", "grain", "straw", "fish", "mixed"]


def place_market(P, R, rng):
    n = [0]; m = [0]

    def shop(x, z, ry=0.0):
        goods = rng.choice(GOODS)
        var = "onggi" if goods == "onggi" else ("cloth" if goods == "cloth" else None)
        params = {"seed": 300 + n[0], "goods": goods}
        if goods == "cloth":
            params["w"] = 4.5
        (w, d), tris = FP[("village/market_shop", var)]
        why = P.check_site(x, z, w, d, ry, gap=0.4, road_min=0.6, lu_min=0.3, lu_ok=(6, 4, 1))
        if why:
            P.reject("장터:" + why); return False
        n[0] += 1
        P.add("nw_shop_%02d" % n[0], "village/market_shop", params, x, z, ry, rects=[(0, 0, w, d)], tris=tris,
              group="남원 장터", note="가가(假家) " + goods, footprint=(w, d))
        return True

    def jwa(x, z, ry=0.0):
        goods = rng.choice(GOODS)
        awn = rng.random() < 0.6
        (w, d), tris = FP[("village/jwapan", None if awn else "noawn")]
        why = P.check_site(x, z, w, d, ry, gap=0.5, road_min=0.4, lu_min=0.3, lu_ok=(6, 4, 1, 2), slope_max=1.5, skip_keepout=True)
        if why:
            P.reject("좌판:" + why); return False
        m[0] += 1
        p = {"seed": 400 + m[0], "goods": goods}
        if not awn:
            p["awning"] = False
        P.add("nw_jwapan_%02d" % m[0], "village/jwapan", p, x, z, ry, rects=[(0, 0, w, d)], tris=tris,
              group="남원 장터", kind="prop", flatten=False)
        return True

    # 장터길(남문 옹성 출구 → 서쪽) 남쪽에 가가 줄(남향), 그 남쪽에 장마당과 좌판 두 줄, 마당 남쪽 가가 한 줄
    for row_z in (386.5, 420.0):
        x = -3338.0 if row_z < 400 else -3338.0
        xe = -3240 if row_z < 400 else -3290
        while x < xe:
            x += 7.8 if shop(x + 3.5, row_z + rng.uniform(-0.6, 0.6)) else 2.0
    for row_z in (398.0, 405.5):
        x = -3334.0
        while x < -3238:
            x += (3.6 + rng.uniform(0, 1.6)) if jwa(x + rng.uniform(0, 0.8), row_z + rng.uniform(-0.5, 0.5)) else 1.5
    # 장터길 양쪽 좌판(성벽 앞, 남문 밖)
    lane = [r for r in R.roads if r["id"] == "namwon_market_lane"][0]["points"]
    for i in range(len(lane) - 1):
        a, b = lane[i], lane[i + 1]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L < 1 or max(a[1], b[1]) < 340:
            continue
        ux, uz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        t = 2.0
        while t < L:
            x, z = a[0] + ux * t, a[1] + uz * t
            for sgn in (1, -1):
                if rng.random() < 0.55:
                    jwa(x + uz * sgn * 3.4, z - ux * sgn * 3.4)
            t += 4.2
    # 남문 → 광한루 길(구례길) 양쪽 좌판
    for zz in range(372, 397, 5):
        for sgn in (-1, 1):
            if rng.random() < 0.35:
                continue
            jwa(-3231.8 + sgn * (4.0 + rng.uniform(0, 1.0)), zz + rng.uniform(-0.8, 0.8))
    return {"가가": n[0], "좌판": m[0]}


# ─────────────────────────────── 주막·다리·어귀·소품 ───────────────────────────────
def road_pt(R, rid, v, axis):
    road = [r for r in R.roads if r["id"] == rid][0]["points"]
    k = 0 if axis == "x" else 1
    for i in range(len(road) - 1):
        a, b = road[i], road[i + 1]
        lo, hi = sorted([a[k], b[k]])
        if lo <= v <= hi and hi > lo:
            t = (v - a[k]) / (b[k] - a[k])
            return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, b[0] - a[0], b[1] - a[1])
    return None


def in_camera_band(F, x, z, r=3.0):
    """나무(수관 반지름 r)가 어떤 길의 남쪽 4~18m 띠에 드나: 북쪽으로 훑어 길을 만나는 거리"""
    for ox in (-r, 0.0, r):
        s = 0.0
        while s <= 18.0 + r:
            if F.road(x + ox, z - s) <= 0.0:
                if s >= 4.0 - r:
                    return True
                break
            s += 0.5
    return False


def place_fixed_misc(P, R, rng):
    """민가보다 먼저 자리를 잡는 것: 주막·건널목·어귀 쉼터·성황당"""
    s = {"주막": 0, "건널목": [], "어귀": []}

    def jumak(id, x, z, note):
        (w, d), tris = FP[("village/jumak", None)]
        if P.check_site(x, z, w, d, 0.0, gap=0.6, road_min=1.0, lu_ok=None, river_min=3.0):
            return False
        P.add(id, "village/jumak", {"seed": int(abs(x)) % 97, "flag": True}, x, z, 0.0, rects=[(0, 0, w, d)], tris=tris,
              group="주막", note=note, footprint=(w, d))
        return True
    for (id, rid, v, axis, note) in [
        ("nw_jumak_naru", "namwon_gurye_road", 497.0, "z", "요천 광한루 앞 나루 길가 주막(구례·곡성 방면)"),
        ("nw_jumak_east", "tongyeong_byeolro", -3000.0, "x", "동문 밖 통영별로(운봉 가는 길) 길가 주막"),
    ]:
        r = road_pt(R, rid, v, axis)
        done = False
        for off in (8.5, 9.5, 11.0, -8.5, -9.5, -11.0):
            for slide in (0, 4, -4, 8, -8, 12, -12):
                x, z, dx, dz = r
                L = math.hypot(dx, dz); ux, uz = dx / L, dz / L
                cx, cz = x + ux * slide + uz * off, z + uz * slide - ux * off
                if jumak(id, cx, cz, note):
                    done = True; break
            if done: break
        s["주막"] += int(done)

    # 건널목
    for cr in R.r["crossings"]:
        if cr["x"] >= -2300:
            continue
        road = [r for r in R.roads if r["id"] == cr["road_id"]][0]
        river = [r for r in R.rivers if r["id"] == cr["river_id"]][0]
        best = None
        for i in range(len(road["points"]) - 1):
            a = road["points"][i]; b = road["points"][i + 1]
            d = math.hypot((a[0] + b[0]) / 2 - cr["x"], (a[1] + b[1]) / 2 - cr["z"])
            if best is None or d < best[0]:
                best = (d, b[0] - a[0], b[1] - a[1])
        dx, dz = best[1], best[2]
        water_w = max(river["width_m"], 5.2) * 1.18
        Ld = math.hypot(dx, dz); ux, uz = dx / Ld, dz / Ld
        ry = math.atan2(dx, dz)
        if ry > math.pi / 2: ry -= math.pi; ux, uz = -ux, -uz
        if ry < -math.pi / 2: ry += math.pi; ux, uz = -ux, -uz
        # 수면 높이·하천 중심(건널목에서 가장 가까운 하천 점)
        rp = min(river["points"], key=lambda p: math.hypot(p[0] - cr["x"], p[1] - cr["z"]))
        wy = rp[2]
        # 다리 맞추기: 끝 높이 = max(수면+0.2, …). 양쪽으로 물 가장자리 밖에서 땅이 그 높이에 닿는 곳을 끝으로
        end_off = {"섶다리": 0.17, "돌다리": 0.10}.get(cr["type"], 0.0)
        deck_end = wy + (0.2 if cr["type"] == "섶다리" else 0.12)
        half = water_w / 2
        def h_at(sv):
            return R.height(cr["x"] + ux * sv, cr["z"] + uz * sv)
        if cr["type"] in ("섶다리", "돌다리"):
            # 둑(길 돋움)이 물 가장자리에서 이미 높으면 그 높이에 맞춘다(낮은 쪽은 멀리 뻗거나 둑길 돋움)
            edge_h = max(h_at(half + 0.8), h_at(-half - 0.8))
            deck_end = max(deck_end, min(edge_h, wy + 2.0))
        def reach(sign):
            sv = half + 0.6
            while sv < half + 16:
                if h_at(sign * sv) >= deck_end - 0.08:
                    return sv, True
                sv += 0.25
            return half + 1.0, False
        se, oke = reach(1); sw, okw = reach(-1)
        L = round(se + sw + 0.6, 1)
        mid = (se - sw) / 2
        bcx, bcz = cr["x"] + ux * mid, cr["z"] + uz * mid
        y_br = deck_end - end_off
        steps = (round(abs(h_at(se) - deck_end), 2), round(abs(h_at(-sw) - deck_end), 2))
        fit_note = "끝 높이 %.2f(수면 %.2f+0.2), 끝 땅 높이 차 +쪽 %.2f / −쪽 %.2f%s" % (
            deck_end, wy, steps[0], steps[1], "" if (oke and okw) else " — 한쪽 둑이 수면보다 낮아 턱이 남음(terrain-data 요청)")
        t = cr["type"]
        # 둑이 수면보다 낮은 쪽: 다리 머리에 흙 둑길(터 고르기 y=끝 높이)을 돋운다 — 횃대 하나를 표지로 두고 footprint로 터를 잡는다
        if t in ("섶다리", "돌다리"):
            for (sign, sv, ok) in ((1, se, oke), (-1, sw, okw)):
                if ok:
                    continue
                # 횃대(충돌체)는 길 옆 2.4m, 터는 길 폭 전체를 덮게 가로로 넓게
                lat = 2.4
                ax_ = cr["x"] + ux * (mid + sign * (L / 2 + 3.4)) + uz * lat
                az_ = cr["z"] + uz * (mid + sign * (L / 2 + 3.4)) - ux * lat
                P.add("nw_cross_" + cr["id"] + "_approach%s" % ("p" if sign > 0 else "m"), "village/torch_post", {"seed": 56},
                      ax_, az_, ry, rects=[(0, 0, 0.8, 0.8)], tris=262, y=deck_end, flatten=True, group="건널목", kind="prop",
                      footprint=(6.4, 3.0),
                      note="다리 머리 흙 둑길: 이쪽 땅이 수면보다 낮아(%.2f < %.2f) 끝 높이로 돋움(가로 7m·길이 7m + 가장자리 5m)" % (h_at(sign * sv), deck_end))
                fit_note += " → 둑길 돋움으로 메움"
        if t == "섶다리":
            sp = max(4, int(round(L / 3.0)))
            P.add("nw_cross_" + cr["id"], "village/seop_bridge", {"seed": 51, "len": L, "spans": sp, "hw": 1.0}, bcx, bcz, ry,
                  rects=[(0, 0, 2.8, L)], tris=1632 + 112 * sp, y=y_br, flatten=False, group="건널목", kind="prop",
                  note="%s 섶다리(가설). %s" % (cr["name"], fit_note))
        elif t == "징검다리":
            P.add("nw_cross_" + cr["id"], "village/jingeom", {"seed": 52, "len": L}, bcx, bcz, ry,
                  rects=[(0, 0, 1.4, L)], tris=int(33 * L), flatten=False, group="건널목", kind="prop",
                  note="%s 징검다리(가설). y=null → 로더가 수면" % cr["name"])
        elif t == "돌다리":
            P.add("nw_cross_" + cr["id"], "village/stone_bridge", {"seed": 53, "len": L, "hw": 1.2, "arch": 0.5}, bcx, bcz, ry,
                  rects=[(0, 0, 2.8, L)], tris=1500, y=y_br, flatten=False, group="건널목", kind="prop",
                  note="%s 홍예 돌다리(가설, 대로). %s" % (cr["name"], fit_note))
        elif t == "나루":
            bx, bz = local_to_world(cr["x"], cr["z"], ry, 0, -water_w * 0.32)
            P.add("nw_cross_" + cr["id"] + "_boat", "village/narutbae", {"seed": 54, "len": 6.4}, bx, bz, ry,
                  rects=[], tris=240, flatten=False, clear_veg=False, group="건널목", kind="prop",
                  note="요천 광한루 앞 나루 나룻배(가설). 원점=수면, 이물이 읍내 쪽")
            tx, tz = local_to_world(cr["x"], cr["z"], ry, 2.2, -water_w / 2 - 3.0)
            P.add("nw_cross_" + cr["id"] + "_torch", "village/torch_post", {"seed": 55}, tx, tz, 0.0, rects=[(0, 0, 0.7, 0.7)],
                  tris=262, group="건널목", kind="prop", flatten=False)
        s["건널목"].append((cr["id"], t, L, fit_note if t in ("섶다리", "돌다리") else ""))

    # 마을 어귀: 장승 한 쌍 + 솟대 + 쉼터(village_square)
    entries = [
        ("남쪽 어귀(요천 건너 구례길)", "namwon_gurye_road", 556.0, "z", "stone"),
        ("동쪽 어귀(통영별로, 요천 섶다리 앞)", "tongyeong_byeolro", -2850.0, "x", "wood"),
        ("북쪽 어귀(전주길, 광치천 건너)", "namwon_north_road", -125.0, "z", "wood"),
        ("동문 밖 마을 어귀", "tongyeong_byeolro", -3075.0, "x", "none"),
    ]
    k = 0
    for (name, rid, v, axis, js) in entries:
        r = road_pt(R, rid, v, axis)
        if not r:
            continue
        x, z, dx, dz = r
        L = math.hypot(dx, dz); nx, nz = dz / L, -dx / L
        placed = 0
        if js != "none":
            for sgn, female in ((1, False), (-1, True)):
                for off in (3.6, 4.4, 5.4):
                    jx, jz = x + nx * off * sgn, z + nz * off * sgn
                    if not P.check_site(jx, jz, 1.2, 1.2, 0.0, gap=0.3, road_min=0.3, lu_ok=None, river_min=2.0, slope_max=3):
                        k += 1
                        if js == "stone":
                            P.add("nw_jangseung_%02d" % k, "village/stone_jangseung", {"seed": 60 + k, "variant": k % 3}, jx, jz, 0.0,
                                  rects=[(0, 0, 1.2, 1.2)], tris=780, group="마을 어귀", kind="prop", flatten=False,
                                  note=name + " 돌장승(실상사 석장승 참고, 남원 읍 어귀 석장승은 가설)")
                        else:
                            P.add("nw_jangseung_%02d" % k, "village/jangseung", {"seed": 60 + k, "female": female}, jx, jz, 0.0,
                                  rects=[(0, 0, 1.2, 1.2)], tris=450, group="마을 어귀", kind="prop", flatten=False, note=name)
                        placed += 1
                        break
            for off in (7.5, 9.0, 11.0):
                jx, jz = x + nx * off, z + nz * off
                if not P.check_site(jx, jz, 2.7, 1.0, 0.0, gap=0.3, road_min=0.3, lu_ok=None, river_min=2.0, slope_max=3):
                    k += 1
                    P.add("nw_sotdae_%02d" % k, "village/sotdae", {"seed": 70 + k, "n": 3}, jx, jz, 0.0, rects=[(0, 0, 2.7, 1.0)],
                          tris=468, group="마을 어귀", kind="prop", flatten=False, note=name)
                    break
        # 쉼터: 길 옆 8×7.6
        sq = False
        # 정자나무가 길 남쪽 4~18m 띠(카메라 통로)에 들지 않게: 길 북쪽 먼저, 남쪽이면 나무 없이
        nsg = -1 if nz > 0 else 1                   # 길 북쪽으로 가는 법선 부호
        for off in (7.5 * nsg, 9.0 * nsg, 11.0 * nsg, -7.5 * nsg, -9.0 * nsg, -11.0 * nsg):
            for slide in (0, 6, -6, 12, -12):
                ux, uz = dx / L, dz / L
                qx, qz = x + ux * slide + nx * off, z + uz * slide + nz * off
                if not P.check_site(qx, qz, 8.0, 7.6, 0.0, gap=0.6, road_min=0.8, lu_ok=None, river_min=3.0, slope_max=2.5):
                    k += 1
                    sp = {"seed": 80 + k}
                    if in_camera_band(P.F, qx, qz):
                        sp["tree"] = "none"
                    P.add("nw_square_%02d" % k, "village/village_square", sp, qx, qz, 0.0, rects=[(0, 0, 8.0, 7.6)],
                          tris=2296, group="마을 어귀", kind="prop", note=name + " 쉼터(정자나무·평상)", footprint=(8.0, 7.6))
                    sq = True; break
            if sq: break
        s["어귀"].append((name, placed, sq))

    # 성황당: 북쪽 길 고개
    ps = [p for p in R.r["passes"] if p["id"].startswith("pass_namwon_north")]
    if ps:
        ps = ps[0]
        for (ox, oz) in [(-7, 4), (7, 4), (-8, -2), (8, -2), (-10, 6), (10, 6)]:
            x, z = ps["x"] + ox, ps["z"] + oz
            if not P.check_site(x, z, 5.5, 4.6, 0.0, gap=0.5, road_min=0.8, lu_ok=None, slope_max=5) and not in_camera_band(P.F, x, z):
                P.add("nw_seonghwangdang", "village/seonghwangdang", {"seed": 81}, x, z, 0.0, rects=[(0, 0, 5.5, 4.6)], tris=1928,
                      group="마을 어귀", kind="prop", note="북쪽 전주길 고갯마루 성황당(가설)", footprint=(5.5, 4.6))
                s["성황당"] = (round(x, 1), round(z, 1))
                break

    # 빨래터: 요천 읍내 쪽 물가
    s["빨래터"] = 0
    yoc = [r for r in R.rivers if r["id"] == "yocheon"][0]
    hw = max(yoc["width_m"], 5.2) * 1.18 / 2
    for tx in (-3150.0, -3250.0, -3045.0):
        pts = yoc["points"]
        i = min(range(len(pts) - 1), key=lambda i: abs(pts[i][0] - tx) + (0 if pts[i][1] < 700 else 1e6))
        a, b = pts[i], pts[i + 1]
        dx, dz = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dz)
        n1 = (dz / L, -dx / L)
        if (CX - a[0]) * n1[0] + (CZ - a[1]) * n1[1] < 0:
            n1 = (-n1[0], -n1[1])
        bx, bz = a[0] + n1[0] * (hw * 0.85), a[1] + n1[1] * (hw * 0.85)
        ry = math.atan2(n1[0], n1[1])
        if P.collides(rect_corners(bx, bz, 4.9, 2.6, ry)):
            continue
        s["빨래터"] += 1
        P.add("nw_ppallaeteo_%d" % s["빨래터"], "village/ppallaeteo", {"seed": 90 + s["빨래터"], "n": 3}, bx, bz, ry,
              rects=[(0, 0, 4.9, 2.6)], tris=536, flatten=False, group="요천 빨래터", kind="prop",
              note="요천 읍내 쪽 물가 빨래터. y=null → 로더가 수면")
    return s


def place_fill(P, R, rng, houses):
    """집 둘레 채우기: 마당 소품 묶음·텃밭·우물, 길가 돌담(wall_run), 길가 생활 소품"""
    s = {"마당소품": 0, "텃밭": 0, "우물": 0, "길가담": 0, "길가소품": 0, "짚가리": 0}
    rng2 = random.Random(SEED + 11)
    hs = [it for it in P.items if it["kit"] in HOUSE_KITS]
    sets = ["manure_coop", "jars", "work", "woodpile"]
    for it in hs:
        w, d = it["footprint"]
        x, z = it["x"], it["z"]
        # 마당 소품: 대문 옆(남쪽 앞 모서리) 또는 옆구리
        if rng2.random() < 0.55:
            st = rng2.choice(sets)
            (pw, pd), tris = FP[("village/yard_props", st)]
            for (ox, oz) in [(w / 2 + pw / 2 + 0.8, d / 2 - pd / 2), (-(w / 2 + pw / 2 + 0.8), d / 2 - pd / 2),
                             (w / 2 + pw / 2 + 0.8, 0), (-(w / 2 + pw / 2 + 0.8), 0), (0, -(d / 2 + pd / 2 + 0.8))]:
                cx, cz = local_to_world(x, z, it["ry"], ox, oz)
                if not P.check_site(cx, cz, pw, pd, it["ry"], gap=0.4, road_min=0.6, lu_ok=None, slope_max=2):
                    s["마당소품"] += 1
                    P.add("nw_yard_%03d" % s["마당소품"], "village/yard_props", {"seed": 600 + s["마당소품"], "set": st}, cx, cz, it["ry"],
                          rects=[(0, 0, pw, pd)], tris=tris, group=it["group"], kind="prop", flatten=False, footprint=(pw, pd))
                    break
        # 텃밭: 집 옆이나 뒤(북쪽). 성 안은 덜
        if rng2.random() < (0.3 if in_walls(x, z) else 0.6):
            if rng2.random() < 0.5:
                kit, key = "village/teotbat", (None if rng2.random() < 0.6 else "small")
                (gw, gd), tris = FP[(kit, key)]
                params = {"seed": 650 + s["텃밭"]}
                if key == "small":
                    params.update({"w": 3.5, "d": 2.6, "rows": 3, "gourd": False})
            else:
                kit = "nature/garden_plot"
                gw, gd = rng2.choice([(4.0, 3.0), (5.0, 4.0), (6.0, 4.0)])
                tris = int(476 + (gw * gd - 16) * 15)
                params = {"seed": 650 + s["텃밭"], "w": gw, "d": gd}
                gw += 0.3; gd += 0.3
            for (ox, oz) in [(-(w / 2 + gw / 2 + 1.2), -d / 4), (w / 2 + gw / 2 + 1.2, -d / 4), (0, -(d / 2 + gd / 2 + 1.5)),
                             (-(w / 2 + gw / 2 + 1.2), d / 4), (w / 2 + gw / 2 + 1.2, d / 4)]:
                cx, cz = local_to_world(x, z, it["ry"], ox, oz)
                if not P.check_site(cx, cz, gw, gd, it["ry"], gap=0.5, road_min=0.8, lu_ok=(6, 3, 1), lu_min=0.5, slope_max=2):
                    s["텃밭"] += 1
                    P.add("nw_garden_%03d" % s["텃밭"], kit, params, cx, cz, it["ry"], rects=[(0, 0, gw, gd)], tris=tris,
                          group=it["group"], kind="prop", flatten=False, footprint=(gw, gd))
                    break
        # 짚가리: 성 밖 집 옆, 논 가
        if not in_walls(x, z) and rng2.random() < 0.25:
            for (ox, oz) in [(w / 2 + 2.5, d / 2 + 2.0), (-(w / 2 + 2.5), d / 2 + 2.0), (0, d / 2 + 3.0)]:
                cx, cz = x + ox, z + oz
                if not P.check_site(cx, cz, 2.4, 2.4, 0.0, gap=0.4, road_min=0.8, lu_ok=None, slope_max=2):
                    s["짚가리"] += 1
                    P.add("nw_haystack_%02d" % s["짚가리"], "village/haystack", {"seed": 700 + s["짚가리"], "s": round(rng2.uniform(0.8, 1.05), 2)},
                          cx, cz, 0.0, rects=[(0, 0, 2.4, 2.4)], tris=376, group=it["group"], kind="prop", flatten=False)
                    break

    # 우물: 마을 곳곳(집 6~8채에 하나 꼴), 길 가까이
    targets = [(CX - 9, CZ + 12), (CX + 9, CZ - 13), (CX - 14, CZ + HALF + 14), (-3105, 290), (-3360, 240), (CX - 26, CZ - HALF - 22),
               (-3255, 300), (-3190, 300), (-3020, 250), (-2930, 180), (-3240, 40), (-3225, 110), (-3370, 330), (-3215, 400), (-3360, 180)]
    for (x, z) in targets:
        for (ox, oz) in [(0, 0), (3, 0), (-3, 0), (0, 3), (0, -3), (5, 4), (-5, 4), (6, -4), (-6, -4), (8, 0), (-8, 0)]:
            if not P.check_site(x + ox, z + oz, 2.4, 2.0, 0.0, gap=0.8, road_min=0.6, lu_ok=None):
                s["우물"] += 1
                roof = not in_walls(x, z)
                P.add("nw_well_%02d" % s["우물"], "village/well", {"seed": 95 + s["우물"], "roof": roof}, x + ox, z + oz, 0.0,
                      rects=[(0, 0, 2.4, 2.0)], tris=492 if roof else 392, group="남원 읍내", kind="prop")
                break

    # 길가 돌담(wall_run stone_lite): 길 가장자리 1.2m 밖, 집 사이 빈 길가 8~22m 구간
    town = {"namwon_gurye_road", "tongyeong_byeolro", "namwon_north_road", "namwon_market_lane", "namwon_eup_street", "namwon_eup_street_ew"}
    for rd in R.roads:
        if rd["id"] not in town:
            continue
        pts = rd["points"]
        hw = rd["width_m"] / 2 + 1.0
        for side in (1, -1):
            run = []
            def flush():
                if len(run) >= 9:
                    seg = run[:]
                    # 18m 정도로 끊는다
                    for k0 in range(0, len(seg) - 8, 20):
                        part = seg[k0:k0 + 17]
                        if len(part) < 9: break
                        ox, oz = part[0]
                        pl = [[round(p[0] - ox, 2), round(p[1] - oz, 2)] for p in part[::3]]
                        if pl[-1] != [round(part[-1][0] - ox, 2), round(part[-1][1] - oz, 2)]:
                            pl.append([round(part[-1][0] - ox, 2), round(part[-1][1] - oz, 2)])
                        s["길가담"] += 1
                        kind = rng2.choice(["stone_lite", "stone_lite", "todam_thatch", "fence_lite"])
                        rects = []
                        for q in range(len(pl) - 1):
                            ax_, az_ = pl[q]; bx_, bz_ = pl[q + 1]
                            Lq = math.hypot(bx_ - ax_, bz_ - az_)
                            if Lq < 0.1: continue
                            rects.append(((ax_ + bx_) / 2, (az_ + bz_) / 2, Lq, 1.0, -math.atan2(bz_ - az_, bx_ - ax_)))
                        P.add("nw_wallrun_%03d" % s["길가담"], "village/wall_run", {"seed": 800 + s["길가담"], "kind": kind, "points": pl},
                              ox, oz, 0.0, rects=[], tris=int(sum(r[2] for r in rects) * (90 if kind == "stone_lite" else 60)),
                              group="남원 읍내(길가 담)", kind="wall", flatten=False)
                        for (rx, rz, Lq, dd, rr) in rects:
                            P.add_shape(rect_corners(ox + rx, oz + rz, Lq, dd, rr), "nw_wallrun_%03d" % s["길가담"], "wall")
                run.clear()
            for i in range(len(pts) - 1):
                a, b = pts[i], pts[i + 1]
                L = math.hypot(b[0] - a[0], b[1] - a[1])
                if L < 0.5: continue
                ux, uz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
                nx, nz = uz * side, -ux * side
                t = 0.0
                while t < L:
                    x, z = a[0] + ux * t + nx * hw, a[1] + uz * t + nz * hw
                    t += 1.0
                    ok = (P.F.landuse(x + nx * 2, z + nz * 2) == 6 and not in_walls(x, z, 6) and P.F.road(x, z) > 0.6
                          and P.F.river(x, z) > 3 and not P.collides(rect_corners(x, z, 1.4, 1.4, 0.0)))
                    if ok:
                        run.append((x, z))
                    else:
                        flush()
            flush()

    # 길가 생활 소품
    STREET = [
        ("village/jige", lambda q: {"seed": q, "load": "wood"}, (0.9, 1.1), 392),
        ("village/props", lambda q: {"seed": q, "kind": "pyeongsang"}, (2.0, 1.3), 216),
        ("village/props", lambda q: {"seed": q, "kind": "dok"}, (1.6, 1.0), 480),
        ("village/props", lambda q: {"seed": q, "kind": "meongseok"}, (2.4, 1.8), 124),
        ("village/firewood", lambda q: {"seed": q, "style": "stack"}, (1.9, 1.2), 720),
        ("village/props", lambda q: {"seed": q, "kind": "jeolgu"}, (0.9, 0.9), 208),
        ("village/props", lambda q: {"seed": q, "kind": "byeotdan"}, (1.8, 1.4), 384),
    ]
    for rd in R.roads:
        if rd["id"] not in town | {"namwon_gaeksa_lane", "namwon_gwana_lane"}:
            continue
        pts = rd["points"]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            if L < 1e-3: continue
            ux, uz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
            t = 0.0
            while t < L:
                x, z = a[0] + ux * t, a[1] + uz * t
                t += 6.0
                if rng2.random() < 0.55:
                    continue
                sgn = rng2.choice((-1, 1))
                off = rd["width_m"] / 2 + rng2.uniform(0.9, 1.8)
                px, pz = x + uz * off * sgn, z - ux * off * sgn
                if P.F.landuse(px + uz * sgn * 2, pz - ux * sgn * 2) != 6 and not in_walls(px, pz):
                    continue
                kit, pf, (w, d), tris = rng2.choice(STREET)
                if P.check_site(px, pz, w, d, 0.0, gap=0.3, road_min=0.4, lu_ok=None, river_min=2.0, slope_max=1.5, skip_keepout=True):
                    continue
                s["길가소품"] += 1
                P.add("nw_prop_%03d" % s["길가소품"], kit, pf(500 + s["길가소품"]), px, pz, 0.0, rects=[(0, 0, w, d)], tris=tris,
                      group="남원 읍내(길가 소품)", kind="prop", flatten=False)
    return s


# ─────────────────────────────── 통계 ───────────────────────────────
def screen_stats(P, R):
    """게임 카메라(거리 22·pitch 40, 화면 폭 35~40m): 플레이어 기준 x±20, z −22…+14 창에 들어오는 집 수,
    그리고 넓은 창(x±35, z −85…+12)의 삼각형 합 최대"""
    houses = [(it["x"], it["z"]) for it in P.items if it["kit"] in HOUSE_KITS or it["kit"] in ("village/jumak", "village/market_shop")
              or it["kit"] in ("landmark/gwana", "landmark/gaeksa", "landmark/samun", "landmark/gwanghallu", "landmark/hyanggyo")]
    # 관아·향교는 화면을 여럿 채우므로 조각 자리도 센다
    for it in P.items:
        if it["kit"] in ("landmark/gwana", "landmark/hyanggyo"):
            w, d = it.get("footprint", (40, 40))
            for ox in (-w / 3, w / 3):
                for oz in (-d / 3, d / 3):
                    houses.append((it["x"] + ox, it["z"] + oz))
    samples = []
    town = {"namwon_gurye_road", "tongyeong_byeolro", "namwon_north_road", "namwon_market_lane", "namwon_eup_street", "namwon_eup_street_ew"}
    for rd in R.roads:
        if rd["id"] not in town: continue
        pts = rd["points"]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            for t in range(0, int(L), 10):
                x, z = a[0] + (b[0] - a[0]) * t / max(L, 1e-6), a[1] + (b[1] - a[1]) * t / max(L, 1e-6)
                if not (AX0 < x < -2790 and AZ0 < z < 600): continue
                if in_walls(x, z) or any(P.F.landuse(x + ox, z + oz) == 6 for (ox, oz) in ((6, 0), (-6, 0), (0, 6), (0, -6))):
                    samples.append(sum(1 for (hx, hz) in houses if abs(hx - x) <= 20 and z - 22 <= hz <= z + 14))
    samples.sort()
    best = (0, None)
    for px in range(-3400, -2820, 10):
        for pz in range(-120, 540, 10):
            s = sum(t for (x, z, t) in P.tris if px - 35 <= x <= px + 35 and pz - 85 <= z <= pz + 12)
            if s > best[0]:
                best = (s, (px, pz))
    q = lambda f: samples[int(f * (len(samples) - 1))] if samples else 0
    return {"길 위 표본": len(samples), "화면 집 수 10%": q(0.1), "중앙값": q(0.5), "90%": q(0.9),
            "3채 미만 비율": round(sum(1 for v in samples if v < 3) / max(1, len(samples)), 2)}, best


def main():
    R = Region()
    F = Fields(R, AX0, AZ0, AX1, AZ1)
    add_village_dist(F)
    rng = random.Random(SEED)
    P = Placer(R, F)
    notes = place_landmarks(P, R, rng)
    mk = place_market(P, R, rng)
    ms = place_fixed_misc(P, R, rng)
    H = place_houses(P, R, rng)
    fs = place_fill(P, R, rng, H)

    # 최종 검사: 겹침(파이썬 SAT). 같은 무리(읍성 조각끼리, 객사 담끼리, 담 토막끼리)는 뺀다
    bad = []
    shp = [s for s in P.shapes if s[2] != "keepout"]
    grp = lambda sid: "읍성" if sid.startswith("읍성") else ("객사담" if sid.startswith(("nw_gaeksa_wall", "nw_gaeksa_samun")) else sid)
    for i in range(len(shp)):
        for j in range(i + 1, len(shp)):
            a, b = shp[i], shp[j]
            if grp(a[1]) == grp(b[1]):
                continue
            ax = [p[0] for p in a[0]]; bx = [p[0] for p in b[0]]
            if max(ax) < min(bx) or max(bx) < min(ax):
                continue
            if poly_overlap(a[0], b[0]):
                bad.append((a[1], b[1]))
    n_house = sum(1 for it in P.items if it["kit"] in HOUSE_KITS)
    in_n = sum(1 for it in P.items if it["kit"] in HOUSE_KITS and in_walls(it["x"], it["z"]))
    total = sum(t for (_, _, t) in P.tris)
    st, scr = screen_stats(P, R)
    kinds = {}
    for it in P.items:
        k = it["kit"] + ("/" + it["params"]["size"] if "size" in it["params"] else "")
        kinds[k] = kinds.get(k, 0) + 1
    doc = {"area": "namwon", "generator": "tools/placement/namwon.py (seed %d, 3단계)" % SEED,
           "note": "남원 읍내(1870 전후 남원도호부 읍치). 게임 좌표, ry 라디안(0=정면 남향). 근거·가설은 docs/reports/placement-namwon.md",
           "items": P.items}
    with open(OUT, "w") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    print("wrote", os.path.relpath(OUT, ROOT), "items", len(P.items))
    print("민가", n_house, "(성 안 %d, 성 밖 %d)" % (in_n, n_house - in_n))
    print("종류", json.dumps(kinds, ensure_ascii=False))
    print("민가 자리", json.dumps(H.stat, ensure_ascii=False))
    print("장터", mk)
    print("고정", json.dumps(ms, ensure_ascii=False))
    print("채우기", json.dumps(fs, ensure_ascii=False))
    print("랜드마크", notes)
    print("거절", P.rejects)
    print("화면 집 수", st)
    print("삼각형 합(전체) %d, 넓은 창 최대 %d at %s" % (total, scr[0], scr[1]))
    print("겹침", len(bad), bad[:10])
    return 0 if not bad else 1


if __name__ == "__main__":
    sys.exit(main())
