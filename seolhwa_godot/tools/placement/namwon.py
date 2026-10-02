#!/usr/bin/env python3
# 남원 읍내 배치 생성기 (placement-namwon).
#   python3 tools/placement/namwon.py            → region_data/JL_NAMWON_UNBONG/placement_namwon.json + 검사 결과
#   python3 tools/placement/namwon_plan.py       → shots/placement/namwon_plan.png (평면도)
# 손으로 정한 랜드마크(읍성·관아·객사·광한루원·향교·다리) + 규칙으로 늘어놓는 민가·장터·소품. 결정적(SEED 고정).
# 좌표는 게임 좌표(m), ry는 Godot Basis(UP, ry) — 로컬 +z(정면)가 남쪽일 때 0.
import json, math, os, random, sys

sys.path.insert(0, os.path.dirname(__file__))
from namwon_data import Region, ROOT, RDIR, rect_corners, rect_points, poly_overlap, local_to_world

SEED = 1870
OUT = os.path.join(RDIR, "placement_namwon.json")

# ── 읍성 기하 (region.json landmarks와 같게: 중심, 한 변 186 → 네 문이 ±93) ──
CX, CZ = -3227.8, 248.8
SIDE = 186.0
HALF = SIDE / 2
WALL_T = 4.6          # kit/landmark/_seong.gd T
INNER = HALF - WALL_T  # 성벽 안쪽 면

# ── 모델 크기(footprint, 삼각형) — kit/*/catalog.json ──
FP = {
    ("village/house_compound", "small"): ((14.6, 14.0), 10950),
    ("village/house_compound", "medium"): ((20.0, 17.4), 12712),
    ("village/house_compound", "large"): ((24.8, 21.8), 14452),
    ("village/choga", None): ((8.2, 6.4), 1984),
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
    ("village/sotdae", None): ((2.7, 1.0), 468),
    ("village/seonghwangdang", None): ((5.5, 4.6), 1928),
    ("village/seop_bridge", None): ((2.4, 0.0), 2080),
    ("village/jingeom", None): ((1.2, 0.0), 480),
    ("village/stone_bridge", None): ((2.6, 0.0), 1400),
    ("village/narutbae", None): ((1.9, 6.6), 240),
    ("village/ppallaeteo", None): ((4.9, 2.6), 536),
    ("village/props", None): ((2.0, 1.4), 300),
    ("village/firewood", None): ((1.9, 1.2), 680),
    ("village/jige", None): ((0.9, 1.1), 350),
    ("village/jangdok", None): ((2.4, 2.0), 924),
    ("landmark/namwon_eupseong", None): ((SIDE + 30, SIDE + 30), 57510),
    ("landmark/gwana", None): ((62.0, 78.0), 34536),
    ("landmark/gaeksa", None): ((47.0, 14.0), 13880),
    ("landmark/samun", None): ((12.8, 8.2), 4290),
    ("landmark/gwana_wall", None): ((12.0, 1.1), 384),
    ("landmark/gwanghallu", None): ((30.0, 14.4), 13102),
    ("landmark/gwanghallu_pond", None): ((0, 0), 8788),
    ("landmark/hyanggyo", None): ((38.0, 56.0), 19186),
}

BUILDING_KITS = {"village/house_compound", "village/choga", "village/giwa", "village/jumak", "village/market_shop"}


class Placer:
    def __init__(self, R):
        self.R = R
        self.items = []
        self.shapes = []   # (poly, item_id, kind)  kind: building|landmark|wall|prop|water|keepout
        self.tris = []     # (x, z, tris)  화면 삼각형 추정용
        self.rejects = {}

    # ── 기록 ──
    def add(self, id, kit, params, x, z, ry=0.0, rects=None, tris=0, y=None, flatten=True, clear_veg=True,
            group="남원 읍내", note=None, kind="building", tri_pts=None):
        it = {"id": id, "kit": kit, "params": params, "x": round(x, 2), "z": round(z, 2), "ry": round(ry, 4),
              "y": (round(y, 3) if y is not None else None), "flatten": flatten, "clear_veg": clear_veg, "group": group}
        if note:
            it["note"] = note
        self.items.append(it)
        for (lx, lz, w, d) in (rects or []):
            cx, cz = local_to_world(x, z, ry, lx, lz)
            self.shapes.append((rect_corners(cx, cz, w, d, ry), id, kind))
        if tri_pts:
            self.tris.extend(tri_pts)
        else:
            self.tris.append((x, z, tris))
        return it

    def keepout(self, name, cx, cz, w, d, ry=0.0):
        self.shapes.append((rect_corners(cx, cz, w, d, ry), name, "keepout"))

    def collides(self, poly, skip_keepout=False):
        for (q, qid, k) in self.shapes:
            if skip_keepout and k == "keepout":
                continue
            if poly_overlap(poly, q):
                return qid
        return None

    # ── 규칙 검사 ──
    def check_site(self, x, z, w, d, ry, gap=1.2, road_min=1.0, river_min=4.0, lu_min=0.6, lu_ok=(6, 4),
                   north_gap=None, slope_max=2.5, skip_keepout=False):
        R = self.R
        poly = rect_corners(x, z, w + 2 * gap, d + 2 * gap, ry)
        c = self.collides(poly, skip_keepout)
        if c:
            return "겹침:" + c
        pts = rect_points(x, z, w, d, ry, n=4)
        rd = min(R.road_clear(px, pz)[0] for (px, pz) in pts)
        if rd < road_min:
            return "길"
        rv = min(R.river_clear(px, pz)[0] for (px, pz) in pts)
        if rv < river_min:
            return "물"
        if lu_ok is not None:
            ok = sum(1 for (px, pz) in pts if R.landuse(px, pz) in lu_ok) / len(pts)
            if ok < lu_min:
                return "토지이용"
        hs = [R.height(px, pz) for (px, pz) in pts]
        if max(hs) - min(hs) > slope_max:
            return "경사"
        if north_gap is not None:
            g = self.road_north_gap(x, z, w, d)
            if g < north_gap:
                return "길가림"
        return None

    def road_north_gap(self, x, z, w, d, look=14.0):
        """건물 북쪽(카메라 반대쪽) 길까지 거리 — 건물이 남쪽 카메라와 길 사이에 서서 길을 가리는지"""
        R = self.R
        best = look
        for i in range(5):
            px = x - w / 2 + w * i / 4
            s = 0.0
            while s < best:
                if R.road_clear(px, z - d / 2 - s)[0] < 0:
                    best = s
                    break
                s += 1.0
        return best

    def reject(self, why):
        k = why.split(":")[0]
        self.rejects[k] = self.rejects.get(k, 0) + 1


def kit_fp(kit, var=None):
    return FP[(kit, var)]


# ─────────────────────────────── 랜드마크 ───────────────────────────────
def eupseong_pieces():
    """kit/landmark/namwon_eupseong.gd layout()을 그대로 옮김 → [(kit, x, z, ry, w, d, lz_off, tris)]"""
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
        # 성문 + 옹성: 로컬 z −2.8(안) … +16.5(밖), 폭 ±14.2
        put("seongmun", 0.0, zc, 28.4, 19.3, (16.5 - 2.8) / 2, 6636)
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


def place_landmarks(P, R, rng):
    notes = {}
    # 1) 남원읍성 — 한 변 186(region.json 네 문 ±93과 일치)
    pieces = eupseong_pieces()
    P.add("nw_eupseong", "landmark/namwon_eupseong", {"seed": 1870, "side": SIDE}, CX, CZ, 0.0,
          rects=[], kind="landmark", flatten=False, group="남원읍성",
          note="방형 평지 읍성. 4문 남 완월루·북 공신루·서 망미루·동 향일루(옹성). 성 안은 terrain-data가 반경 85m를 이미 고르게 함 → flatten 끔(조각마다 땅속 1.2m)",
          tri_pts=[(p[2], p[3], p[8]) for p in pieces])
    for (kit, sd, x, z, ry, w, d, lzo, tris) in pieces:
        cx, cz = local_to_world(x, z, ry, 0, lzo)
        P.shapes.append((rect_corners(cx, cz, w, d, ry), "읍성_" + sd + "_" + kit, "wall"))
    # 성문 안팎 광장(문 앞길이 막히지 않게)
    for (gx, gz, w, d) in [(CX, CZ + INNER - 9, 22, 18), (CX, CZ - INNER + 9, 22, 18), (CX + INNER - 9, CZ, 18, 22), (CX - INNER + 9, CZ, 18, 22)]:
        P.keepout("문안광장", gx, gz, w, d)
    P.keepout("남문밖광장", CX + 6, CZ + HALF + 22, 30, 14)
    # 성 안 십자로 길가 여유(길 4m + 양쪽 2m)
    P.keepout("남북길", CX, CZ, 8, SIDE)
    P.keepout("동서길", CX, CZ, SIDE, 8)

    # 2) 관아 일곽(동헌·내아·내외삼문) — 성 안 동북 구획, 외삼문이 동서길을 향함
    gx, gz = CX + 44.0, CZ - 44.5
    P.add("nw_gwana", "landmark/gwana", {"seed": 1871, "width": 60, "depth": 72}, gx, gz, 0.0,
          rects=[(0, 0, 62, 78)], tris=34536, group="남원도호부 관아", kind="landmark",
          note="동헌·내아·내외삼문 일곽. 위치 가설(성 안 동북, region.json namwon_dongheon −3184,222 근처)")
    # 3) 객사 용성관 — 성 안 서북 구획. 담장 + 외삼문 + 정당·익헌
    kx = CX - 44.0
    wall_z0, wall_z1 = CZ - 50.0, CZ - 6.0     # 담 북·남
    kw = 58.0
    P.add("nw_gaeksa", "landmark/gaeksa", {"seed": 1872, "jeongdang_bays": 5}, kx, CZ - 38.8, 0.0,
          rects=[(0, 0, 47, 14)], tris=13880, group="객사 용성관", kind="landmark",
          note="용성관: 정당 5칸 + 익헌 둘. region.json(−3270,254)은 동서길 위라 담 안쪽 북쪽(z≈210)으로 옮김")
    P.add("nw_gaeksa_samun", "landmark/samun", {"seed": 1873, "kind": "outer", "name": "용성관"}, kx, wall_z1, 0.0,
          rects=[(0, 0, 11.0, 5.6)], tris=4290, group="객사 용성관", kind="landmark")
    walls = wall_pieces([(kx - kw / 2, wall_z0), (kx + kw / 2, wall_z0), (kx + kw / 2, wall_z1), (kx - kw / 2, wall_z1)],
                        True, [(kx, wall_z1, 4.8)], 1880, 2.2)
    for i, w in enumerate(walls):
        P.add("nw_gaeksa_wall_%02d" % i, "landmark/gwana_wall", w["params"], w["x"], w["z"], w["ry"],
              rects=[(0, 0, w["params"]["length"], 1.1)], tris=int(384 * w["params"]["length"] / 12), group="객사 용성관",
              kind="wall", flatten=False)

    # 4) 광한루원 — 연못(오작교 포함) + 광한루(확정 위치 −3271.4, 450.1)
    lx, lz = -3271.4, 450.1
    pw, pd = 84.0, 40.0
    px, pz = -3279.0, 483.0
    bx = -pw * 0.18
    P.add("nw_gwanghallu_pond", "landmark/gwanghallu_pond", {"seed": 1582, "width": pw, "depth": pd, "bridge": True}, px, pz, 0.0,
          rects=[(0, 0, pw + 3, pd + 3), (bx, 0, 2.8, 57.0)], tris=8788, group="광한루원", kind="water",
          note="못 84×40(1870년 정원은 지금보다 작았다는 가설) + 삼신산 섬 셋 + 오작교(모델에 포함, 57m 남북). 오작교 x≈−3294(OSM −3283)")
    P.add("nw_gwanghallu", "landmark/gwanghallu", {"seed": 1626, "iklu": True}, lx, lz, 0.0,
          rects=[(4.0, 0, 30.0, 14.4)], tris=13102, group="광한루원", kind="landmark",
          note="OSM 위치 그대로(확정). 못 북쪽 둑, 익루는 동쪽")
    # 광한루 앞(못가) 비워 두기
    notes["pond_anchor_vs_kit"] = (px - pw * 0.32, pz - pd / 2 - 12.0)

    # 5) 향교 — 가설: 읍성 북쪽 산기슭(전묘후학, 남향). region.json(−3184,−50)은 광치천과 북쪽 길에 걸려
    #    광치천 북안의 논이 아닌 기슭(숲·밭·풀밭)에서 가설점에 가장 가까운 자리를 찾는다.
    hw, hd = 36.0, 50.0
    best = None
    for ix in range(-40, 41):
        for jz in range(-50, 21):
            x = -3184.3 + ix * 3.0; z = -49.8 + jz * 3.0
            if z > -80:      # 광치천 북쪽(산기슭)만
                continue
            d = math.hypot(x + 3184.3, z + 49.8)
            if best and d >= best[0]:
                continue
            why = P.check_site(x, z, hw + 2, hd + 6, 0.0, gap=1.0, road_min=4.0, river_min=6.0, lu_ok=(0, 1, 3, 6, 9), lu_min=0.7, slope_max=7.0)
            if why is None:
                best = (d, x, z)
    _, hx, hz = best
    P.add("nw_hyanggyo", "landmark/hyanggyo", {"seed": 1392, "width": hw, "depth": hd}, hx, hz, 0.0,
          rects=[(0, 0, hw + 2, hd + 6)], tris=19186, group="남원향교", kind="landmark",
          note="가설 위치: 향교동 지명(region.json −3184,−50) 북쪽, 광치천 건너 산기슭에서 논·물·길을 피한 가장 가까운 자리. 전묘후학, 남향")
    notes["hyanggyo"] = (round(hx, 1), round(hz, 1), round(best[0], 1))
    return notes


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


# ─────────────────────────────── 민가 ───────────────────────────────
HOUSE_TYPES = {
    # 이름: (kit, params 함수, footprint 변형 키, 큰 건물?)
    "large": ("village/house_compound", lambda s: {"seed": s, "size": "large"}, "large", True),
    "medium": ("village/house_compound", lambda s: {"seed": s, "size": "medium"}, "medium", True),
    "small": ("village/house_compound", lambda s: {"seed": s, "size": "small"}, "small", True),
    "giwa": ("village/giwa", lambda s: {"seed": s, "plain": True, "w": 7.2, "bays": 3}, "plain", True),
    "choga": ("village/choga", lambda s: {"seed": s}, None, False),
    "choga_gourd": ("village/choga", lambda s: {"seed": s, "w": 5.4, "gourd": True}, None, False),
}
# choga 단독은 마당·장독 자리까지 조금 넓게 잡는다
APRON = {"choga": (1.6, 3.0), "choga_gourd": (1.6, 3.0), "giwa": (1.0, 3.0)}


def house_fp(t):
    kit, _, var, _ = HOUSE_TYPES[t]
    (w, d), tris = FP[(kit, var)]
    ax, az = APRON.get(t, (0, 0))
    return w + ax, d + az, tris


def fill_band(P, rng, name, x0, x1, ztop, zbot, weights, counter, group, gap=1.4, north_gap=None,
              align="top", jitter=1.5, lu_min=0.6, ry_max=0.0, river_min=4.0):
    """띠(ztop…zbot) 안에 서→동으로 집을 늘어놓는다. align=top이면 북쪽 줄을 맞춘다(마당 남향)."""
    x = x0
    placed = 0
    tries = 0
    while x < x1 and tries < 400:
        tries += 1
        t = rng.choices(list(weights.keys()), list(weights.values()))[0]
        w, d, tris = house_fp(t)
        if d > (zbot - ztop):
            x += 2.0
            continue
        if x + w > x1:
            # 남은 폭에 맞는 작은 집
            t = "choga"
            w, d, tris = house_fp(t)
            if x + w > x1:
                break
        cx = x + w / 2
        jz = rng.uniform(0, jitter)
        cz = (ztop + d / 2 + jz) if align == "top" else (zbot - d / 2 - jz)
        ry = rng.uniform(-ry_max, ry_max) if ry_max else 0.0
        big = HOUSE_TYPES[t][3]
        ng = None
        if north_gap is not None:
            ng = north_gap if big else max(4.0, north_gap * 0.5)
        why = P.check_site(cx, cz, w, d, ry, gap=gap / 2, north_gap=ng, lu_min=lu_min, river_min=river_min)
        if why:
            P.reject(why)
            x += 2.0
            continue
        counter[0] += 1
        kit, pf, var, _ = HOUSE_TYPES[t]
        s = 100 + counter[0]
        P.add("nw_house_%03d" % counter[0], kit, pf(s), cx, cz, ry, rects=[(0, 0, w, d)], tris=tris, group=group,
              note="%s / %s" % (name, t))
        placed += 1
        x += w + gap + rng.uniform(0, 2.0)
    return placed


def place_houses(P, R, rng):
    c = [0]
    stat = {}
    inner_w, inner_e = CX - INNER + 3, CX + INNER - 3
    inner_n, inner_s = CZ - INNER + 3, CZ + INNER - 3
    # 성 안 (아전·향리·관속의 집: 기와집·큰 집이 많다)
    W_IN = {"large": 3, "medium": 4, "giwa": 3, "small": 2, "choga": 2}
    # 서남 구획: 장터길(성 안을 지나는 구간)의 동쪽
    stat["성안 서남 1열"] = fill_band(P, rng, "성안 서남", -3300, CX - 4, CZ + 13, CZ + 42, W_IN, c, "남원 읍내(성 안)", north_gap=9)
    stat["성안 서남 2열"] = fill_band(P, rng, "성안 서남", -3300, CX - 4, CZ + 45, inner_s, W_IN, c, "남원 읍내(성 안)", north_gap=6)
    stat["성안 동남 1열"] = fill_band(P, rng, "성안 동남", CX + 4, inner_e, CZ + 13, CZ + 42, W_IN, c, "남원 읍내(성 안)", north_gap=9)
    stat["성안 동남 2열"] = fill_band(P, rng, "성안 동남", CX + 4, inner_e, CZ + 45, inner_s, W_IN, c, "남원 읍내(성 안)", north_gap=6)
    # 서북 구획: 객사 담 뒤(북쪽)·서쪽
    stat["성안 서북"] = fill_band(P, rng, "성안 서북", inner_w, CX - 4, inner_n, CZ - 51, {"small": 3, "giwa": 2, "choga": 3}, c, "남원 읍내(성 안)")
    stat["성안 서쪽 띠"] = fill_band(P, rng, "성안 서쪽", inner_w, CX - 74, CZ - 50, CZ - 6, {"choga": 1}, c, "남원 읍내(성 안)", align="top")
    # 성 밖 (초가 위주)
    W_OUT = {"small": 4, "medium": 2, "choga": 4, "choga_gourd": 1}
    out_e = CX + HALF + 7     # 동벽 치 바깥
    stat["동문 밖 북쪽"] = fill_band(P, rng, "동문 밖", out_e, -3080, CZ - 60, CZ - 5, W_OUT, c, "남원 읍내(성 밖)", align="bot")
    stat["동문 밖 남쪽"] = fill_band(P, rng, "동문 밖", out_e, -3080, CZ + 8, CZ + 75, W_OUT, c, "남원 읍내(성 밖)", north_gap=8)
    stat["남벽 밖(남북길 동쪽)"] = fill_band(P, rng, "남문 밖 동쪽", CX + 4, -3120, CZ + HALF + 8, CZ + HALF + 34, W_OUT, c, "남원 읍내(성 밖)")
    stat["남문 밖 둘째 줄"] = fill_band(P, rng, "남문 밖 동쪽", CX + 4, -3150, CZ + HALF + 37, CZ + HALF + 75, {"small": 3, "choga": 3}, c, "남원 읍내(성 밖)", lu_min=0.3)
    stat["북벽 밖"] = fill_band(P, rng, "북문 밖", -3330, -3120, CZ - HALF - 40, CZ - HALF - 8, W_OUT, c, "남원 읍내(성 밖)", align="bot")
    stat["북문 밖 길가"] = fill_band(P, rng, "북문 밖", -3260, -3170, 50, CZ - HALF - 44, {"small": 2, "choga": 3}, c, "남원 읍내(성 밖)", align="bot", lu_min=0.2)
    stat["서벽 밖 1"] = fill_band(P, rng, "서문 밖", -3365, CX - HALF - 7, CZ - 90, CZ - 45, W_OUT, c, "남원 읍내(성 밖)", align="bot")
    stat["서벽 밖 2"] = fill_band(P, rng, "서문 밖", -3365, CX - HALF - 7, CZ - 42, CZ - 6, W_OUT, c, "남원 읍내(성 밖)", align="bot")
    stat["서벽 밖 3"] = fill_band(P, rng, "서문 밖", -3365, CX - HALF - 7, CZ + 8, CZ + 48, W_OUT, c, "남원 읍내(성 밖)", north_gap=8)
    stat["서벽 밖 4"] = fill_band(P, rng, "서문 밖", -3365, CX - HALF - 7, CZ + 50, CZ + 95, W_OUT, c, "남원 읍내(성 밖)")
    return stat


# ─────────────────────────────── 장터 ───────────────────────────────
GOODS = ["onggi", "cloth", "grain", "straw", "fish", "mixed"]


def place_market(P, R, rng):
    n = [0]

    def shop(x, z, ry=0.0, goods=None):
        goods = goods or rng.choice(GOODS)
        var = "onggi" if goods == "onggi" else ("cloth" if goods == "cloth" else None)
        params = {"seed": 300 + n[0], "goods": goods}
        if goods == "cloth":
            params["w"] = 4.5
        (w, d), tris = FP[("village/market_shop", var)]
        why = P.check_site(x, z, w, d, ry, gap=0.4, road_min=0.6, lu_min=0.3, lu_ok=(6, 4, 1), north_gap=4)
        if why:
            P.reject("장터:" + why)
            return False
        n[0] += 1
        P.add("nw_shop_%02d" % n[0], "village/market_shop", params, x, z, ry, rects=[(0, 0, w, d)], tris=tris,
              group="남원 장터", note="가가(假家) " + goods)
        return True

    m = [0]

    def jwa(x, z, ry=0.0):
        goods = rng.choice(GOODS)
        awn = rng.random() < 0.6
        (w, d), tris = FP[("village/jwapan", None if awn else "noawn")]
        why = P.check_site(x, z, w, d, ry, gap=0.5, road_min=0.4, lu_min=0.3, lu_ok=(6, 4, 1, 2), slope_max=1.5)
        if why:
            P.reject("좌판:" + why)
            return False
        m[0] += 1
        p = {"seed": 400 + m[0], "goods": goods}
        if not awn:
            p["awning"] = False
        P.add("nw_jwapan_%02d" % m[0], "village/jwapan", p, x, z, ry, rects=[(0, 0, w, d)], tris=tris,
              group="남원 장터", kind="prop", flatten=False)
        return True

    # 장터 가겟줄: 남문 밖 장터길 남쪽에 동서로 열린 장마당(z≈392)을 두고 북쪽 줄 가게가 남향
    x = -3334.0
    while x < -3246:
        if shop(x + 3.5, 386.5 + rng.uniform(-0.6, 0.6)):
            x += 7.8
        else:
            x += 2.0
    # 장마당 남쪽 가게 한 줄(광한루 쪽, 남향) — 광한루 앞을 가리지 않게 서쪽만
    x = -3336.0
    while x < -3292:
        if shop(x + 3.5, 420.0 + rng.uniform(-0.6, 0.6)):
            x += 7.8
        else:
            x += 2.0
    # 좌판 줄: 장마당 가운데 두 줄
    for row_z in (398.0, 405.5):
        x = -3332.0
        while x < -3240:
            if jwa(x + rng.uniform(0, 0.8), row_z + rng.uniform(-0.5, 0.5)):
                x += 3.6 + rng.uniform(0, 1.6)
            else:
                x += 1.5
    # 남문 밖 장터길 북쪽(성벽 앞) 좌판 — 성문 앞 장꾼
    pts = [(-3240.0 - i * 4.2, None) for i in range(12)]
    for (x, _) in pts:
        # 장터길 북쪽 2.5m
        best = None
        for zz in [z / 2 for z in range(690, 760)]:
            if R.road_clear(x, zz)[0] < 0:
                best = zz
                break
        if best:
            jwa(x, best - 3.4)
    # 남문에서 광한루 가는 길(구례길) 양쪽 좌판 — 장날 길가로 넘친 장꾼
    for zz in range(374, 440, 5):
        for sgn in (-1, 1):
            if rng.random() < 0.3:
                continue
            x0 = -3231.8
            jwa(x0 + sgn * (4.2 + rng.uniform(0, 1.0)), zz + rng.uniform(-0.8, 0.8))
    return {"가가": n[0], "좌판": m[0]}


# ─────────────────────────────── 주막·다리·소품 ───────────────────────────────
def place_misc(P, R, rng):
    s = {}
    # 주막 1: 광한루 아래 요천 나루 길가
    def jumak(id, x, z, ry, note, flag=True):
        (w, d), tris = FP[("village/jumak", None)]
        why = P.check_site(x, z, w, d, ry, gap=0.6, road_min=1.0, lu_ok=None, river_min=3.0)
        if why:
            print("  ! 주막 자리 실패", id, why)
            return False
        P.add(id, "village/jumak", {"seed": int(abs(x)) % 97, "flag": flag}, x, z, ry, rects=[(0, 0, w, d)], tris=tris,
              group="주막", note=note)
        return True
    s["주막"] = 0
    for (id, cands, note) in [
        ("nw_jumak_naru", [(-3213.5, 496.0), (-3214.0, 492.0), (-3216.0, 499.0), (-3245.0, 432.0)], "요천 광한루 앞 나루 길가 주막(구례·곡성 방면)"),
        ("nw_jumak_east", [(-3100.0, 233.0), (-3092.0, 232.0), (-3110.0, 232.0), (-3070.0, 230.0)], "동문 밖 통영별로(운봉 가는 길) 길가 주막"),
    ]:
        for (x, z) in cands:
            if jumak(id, x, z, 0.0, note):
                s["주막"] += 1
                break

    # 다리·나루 (region.json crossings 중 x < −2300)
    s["건널목"] = []
    for cr in R.r["crossings"]:
        if cr["x"] >= -2300:
            continue
        road = [r for r in R.roads if r["id"] == cr["road_id"]][0]
        river = [r for r in R.rivers if r["id"] == cr["river_id"]][0]
        # 길 방향(건널목 근처 선분)
        best = None
        for i in range(len(road["points"]) - 1):
            a = road["points"][i]; b = road["points"][i + 1]
            mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            d = math.hypot(mx - cr["x"], mz - cr["z"])
            if best is None or d < best[0]:
                best = (d, b[0] - a[0], b[1] - a[1])
        dx, dz = best[1], best[2]
        # 수면 y·폭
        wy = None; dmin = 1e9
        for p in river["points"]:
            d = math.hypot(p[0] - cr["x"], p[1] - cr["z"])
            if d < dmin:
                dmin = d; wy = p[2]
        water_w = max(river["width_m"], 5.2) * 1.18
        ry = math.atan2(dx, dz)
        if ry > math.pi / 2: ry -= math.pi
        if ry < -math.pi / 2: ry += math.pi
        L = round(water_w + 6.0, 1)
        # 둑 높이: 다리 양 끝 땅 높이 중 높은 쪽(지형이 물가로 낮아지므로)
        e1 = local_to_world(cr["x"], cr["z"], ry, 0, L / 2); e0 = local_to_world(cr["x"], cr["z"], ry, 0, -L / 2)
        bank = max(R.height(*e0), R.height(*e1))
        t = cr["type"]
        if t == "섶다리":
            sp = max(4, int(round(L / 3.0)))
            P.add("nw_cross_" + cr["id"], "village/seop_bridge", {"seed": 51, "len": L, "spans": sp, "hw": 1.0}, cr["x"], cr["z"], ry,
                  rects=[(0, 0, 2.8, L)], tris=1632 + 112 * sp, y=bank, flatten=False, group="요천 건널목", kind="prop",
                  note="%s 섶다리(겨울~봄, 가설). 길이 %.1fm, y=둑 높이. walk 면은 엔진(deck 식)" % (cr["name"], L))
        elif t == "징검다리":
            P.add("nw_cross_" + cr["id"], "village/jingeom", {"seed": 52, "len": L}, cr["x"], cr["z"], ry,
                  rects=[(0, 0, 1.4, L)], tris=60 * L, y=wy, flatten=False, group="건널목", kind="prop",
                  note="%s 징검다리(가설). y=수면" % cr["name"])
        elif t == "돌다리":
            P.add("nw_cross_" + cr["id"], "village/stone_bridge", {"seed": 53, "len": L, "hw": 1.2, "arch": 0.5}, cr["x"], cr["z"], ry,
                  rects=[(0, 0, 2.8, L)], tris=1500, y=bank, flatten=False, group="건널목", kind="prop",
                  note="%s 홍예 돌다리(가설, 대로). y=둑 높이" % cr["name"])
        elif t == "나루":
            # 북안(읍내 쪽)에 대 놓은 나룻배: 이물(−z)이 북쪽 둑을 본다
            bx, bz = local_to_world(cr["x"], cr["z"], ry, 0, -water_w * 0.32)
            bry = ry  # 이물(−z)이 길의 북쪽(읍내 쪽)을 본다
            P.add("nw_cross_" + cr["id"] + "_boat", "village/narutbae", {"seed": 54, "len": 6.4}, bx, bz, bry,
                  rects=[], tris=240, y=wy, flatten=False, clear_veg=False, group="요천 건널목", kind="prop",
                  note="요천 광한루 앞 나루 나룻배(가설). 원점=수면")
            # 나루터 표: 강가 장대(횃대)
            tx, tz = local_to_world(cr["x"], cr["z"], ry, 2.2, -water_w / 2 - 3.0)
            P.add("nw_cross_" + cr["id"] + "_torch", "village/torch_post", {"seed": 55}, tx, tz, 0.0, rects=[(0, 0, 0.7, 0.7)],
                  tris=262, group="요천 건널목", kind="prop", flatten=False)
        s["건널목"].append((cr["id"], t, round(L, 1)))

    # 장승·솟대: 마을 어귀 (길 양쪽)
    s["어귀"] = []
    def road_at(rid, x_or_z, axis):
        road = [r for r in R.roads if r["id"] == rid][0]["points"]
        for i in range(len(road) - 1):
            a, b = road[i], road[i + 1]
            k = 0 if axis == "x" else 1
            lo, hi = sorted([a[k], b[k]])
            if lo <= x_or_z <= hi and hi > lo:
                t = (x_or_z - a[k]) / (b[k] - a[k])
                return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, b[0] - a[0], b[1] - a[1])
        return None
    entries = [
        ("남쪽 어귀(요천 건너 구례길)", "namwon_gurye_road", 556.0, "z"),
        ("동쪽 어귀(통영별로)", "tongyeong_byeolro", -3062.0, "x"),
        ("북쪽 어귀(전주길)", "namwon_north_road", 80.0, "z"),
    ]
    k = 0
    for (name, rid, v, axis) in entries:
        r = road_at(rid, v, axis)
        if not r:
            print("  ! 어귀 실패", name); continue
        x, z, dx, dz = r
        L = math.hypot(dx, dz); nx, nz = dz / L, -dx / L   # 길에 수직
        placed = []
        for sgn, female in ((1, False), (-1, True)):
            for off in (3.6, 4.4, 5.2):
                jx, jz = x + nx * off * sgn, z + nz * off * sgn
                why = P.check_site(jx, jz, 1.2, 1.2, 0.0, gap=0.3, road_min=0.3, lu_ok=None, river_min=2.0, slope_max=3)
                if not why:
                    k += 1
                    P.add("nw_jangseung_%02d" % k, "village/jangseung", {"seed": 60 + k, "female": female}, jx, jz, 0.0,
                          rects=[(0, 0, 1.2, 1.2)], tris=450, group="마을 어귀", kind="prop", flatten=False, note=name)
                    placed.append((jx, jz))
                    break
        # 솟대: 장승 바깥쪽
        for off in (7.5, 9.0, 11.0):
            jx, jz = x + nx * off, z + nz * off
            why = P.check_site(jx, jz, 2.7, 1.0, 0.0, gap=0.3, road_min=0.3, lu_ok=None, river_min=2.0, slope_max=3)
            if not why:
                k += 1
                P.add("nw_sotdae_%02d" % k, "village/sotdae", {"seed": 70 + k, "n": 3}, jx, jz, 0.0, rects=[(0, 0, 2.7, 1.0)],
                      tris=468, group="마을 어귀", kind="prop", flatten=False, note=name)
                break
        s["어귀"].append((name, len(placed)))

    # 성황당: 북쪽 길 무명 고개(전주 방면)
    ps = [p for p in R.r["passes"] if p["id"] == "pass_namwon_north_12"][0]
    for (ox, oz) in [(-7, 4), (7, 4), (-8, -2), (8, -2), (-10, 6)]:
        x, z = ps["x"] + ox, ps["z"] + oz
        if not P.check_site(x, z, 5.5, 4.6, 0.0, gap=0.5, road_min=0.8, lu_ok=None, slope_max=4):
            P.add("nw_seonghwangdang", "village/seonghwangdang", {"seed": 81}, x, z, 0.0, rects=[(0, 0, 5.5, 4.6)], tris=1928,
                  group="마을 어귀", kind="prop", note="북쪽 길 고갯마루 성황당(가설)")
            s["성황당"] = (round(x, 1), round(z, 1))
            break

    # 빨래터: 요천 북안(읍내 쪽) — 원점 = 수면, 물이 −z쪽이므로 북안에서는 ry=π(빨래하는 이가 남쪽 물을 본다 → 카메라 쪽 얼굴)
    s["빨래터"] = 0
    yoc = [r for r in R.rivers if r["id"] == "yocheon"][0]
    hw = max(yoc["width_m"], 5.2) * 1.18 / 2
    for (tx, want) in [(-3150.0, "N"), (-3250.0, "N"), (-3045.0, "W")]:
        # 가장 가까운 점
        pts = yoc["points"]
        i = min(range(len(pts) - 1), key=lambda i: abs(pts[i][0] - tx) + (0 if pts[i][1] < 700 else 1e6))
        a, b = pts[i], pts[i + 1]
        dx, dz = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dz)
        # 물 흐름의 왼쪽/오른쪽 법선 중 읍성 쪽
        n1 = (dz / L, -dx / L)
        if (CX - a[0]) * n1[0] + (CZ - a[1]) * n1[1] < 0:
            n1 = (-n1[0], -n1[1])
        bx, bz = a[0] + n1[0] * (hw * 0.85), a[1] + n1[1] * (hw * 0.85)
        # 로컬 −z(물 쪽)가 −n1을 향하게: (−sin ry, −cos ry) = −n1 → ry = atan2(n1x, n1z)
        ry = math.atan2(n1[0], n1[1])
        if P.collides(rect_corners(bx, bz, 4.9, 2.6, ry)):
            continue
        s["빨래터"] += 1
        P.add("nw_ppallaeteo_%d" % s["빨래터"], "village/ppallaeteo", {"seed": 90 + s["빨래터"], "n": 3}, bx, bz, ry,
              rects=[(0, 0, 4.9, 2.6)], tris=536, y=a[2], flatten=False, group="요천 빨래터", kind="prop",
              note="요천 읍내 쪽 물가 빨래터. 원점=수면")

    # 우물: 성 안 네거리 가까이·장터·동문 밖·남문 밖
    s["우물"] = 0
    for (x, z, roof) in [(CX - 9, CZ + 12, False), (CX + 9, CZ - 13, False), (CX - 14, CZ + HALF + 12, True), (-3112, 262, True),
                         (-3345, 240, True), (CX - 20, CZ - HALF - 22, True), (-3255, 300, False), (-3190, 300, False)]:
        for (ox, oz) in [(0, 0), (3, 0), (-3, 0), (0, 3), (0, -3), (5, 3), (-5, 3)]:
            if not P.check_site(x + ox, z + oz, 2.4, 2.0, 0.0, gap=0.6, road_min=0.5, lu_ok=None):
                s["우물"] += 1
                P.add("nw_well_%d" % s["우물"], "village/well", {"seed": 95 + s["우물"], "roof": roof}, x + ox, z + oz, 0.0,
                      rects=[(0, 0, 2.4, 2.0)], tris=492 if roof else 392, group="남원 읍내", kind="prop")
                break
    return s


def place_fieldside(P, R, rng):
    """마을 가장자리 짚가리·볏단: 성 밖 집 남쪽 들 가장자리(논·밭 경계)"""
    n = 0
    houses = [it for it in P.items if it["kit"] in ("village/house_compound", "village/choga") and "성 밖" in it["group"]]
    rng2 = random.Random(SEED + 7)
    for it in houses:
        if rng2.random() > 0.45:
            continue
        for (ox, oz) in [(rng2.uniform(-6, 6), 13.0), (rng2.uniform(-8, 8), 15.0), (11.0, 2.0), (-11.0, 2.0)]:
            x, z = it["x"] + ox, it["z"] + oz
            kind = rng2.choice(["haystack", "haystack", "byeotdan"])
            w, d = (2.4, 2.4) if kind == "haystack" else (1.8, 1.4)
            if P.check_site(x, z, w, d, 0.0, gap=0.6, road_min=0.8, lu_ok=(6, 2, 3, 1, 4), lu_min=0.5):
                continue
            n += 1
            if kind == "haystack":
                P.add("nw_haystack_%02d" % n, "village/haystack", {"seed": 700 + n, "s": round(rng2.uniform(0.8, 1.05), 2)}, x, z, 0.0,
                      rects=[(0, 0, w, d)], tris=376, group="남원 읍내(성 밖)", kind="prop", flatten=False)
            else:
                P.add("nw_haystack_%02d" % n, "village/props", {"seed": 700 + n, "kind": "byeotdan"}, x, z, 0.0,
                      rects=[(0, 0, w, d)], tris=384, group="남원 읍내(성 밖)", kind="prop", flatten=False)
            break
    return n


STREET_PROPS = [
    ("village/jige", lambda s: {"seed": s, "load": "wood"}, (0.9, 1.1), 392),
    ("village/jige", lambda s: {"seed": s, "load": "basket"}, (0.9, 1.1), 320),
    ("village/props", lambda s: {"seed": s, "kind": "pyeongsang"}, (2.0, 1.3), 216),
    ("village/props", lambda s: {"seed": s, "kind": "dok"}, (1.6, 1.0), 480),
    ("village/props", lambda s: {"seed": s, "kind": "meongseok"}, (2.4, 1.8), 124),
    ("village/props", lambda s: {"seed": s, "kind": "soguri", "fill": "grain"}, (0.8, 0.8), 80),
    ("village/firewood", lambda s: {"seed": s, "style": "stack"}, (1.9, 1.2), 720),
    ("village/props", lambda s: {"seed": s, "kind": "jeolgu"}, (0.9, 0.9), 208),
]


def place_street_props(P, R, rng):
    """읍내 길가 생활 소품(지게·평상·항아리·멍석·장작·절구) — 게임 시점(폭 25m 안팎)에서 빈 마당이 덜 비어 보이게"""
    n = 0
    town = {"namwon_eup_street", "namwon_eup_street_ew", "namwon_market_lane", "namwon_gurye_road", "tongyeong_byeolro", "namwon_north_road"}
    for rd in R.roads:
        if rd["id"] not in town:
            continue
        pts = rd["points"]
        acc = 0.0
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            if L < 1e-3:
                continue
            ux, uz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
            t = 0.0
            while t < L:
                x, z = a[0] + ux * t, a[1] + uz * t
                t += 7.0
                if math.hypot(x - CX, z - CZ) > 175 or z > 460:
                    continue
                if rng.random() < 0.45:
                    continue
                sgn = rng.choice((-1, 1))
                off = rd["width_m"] / 2 + rng.uniform(1.6, 3.2)
                px, pz = x + uz * off * sgn, z - ux * off * sgn
                kit, pf, (w, d), tris = rng.choice(STREET_PROPS)
                if P.check_site(px, pz, w, d, 0.0, gap=0.5, road_min=0.5, lu_ok=None, river_min=2.0, slope_max=1.5, skip_keepout=True):
                    continue
                n += 1
                P.add("nw_prop_%03d" % n, kit, pf(500 + n), px, pz, 0.0, rects=[(0, 0, w, d)], tris=tris,
                      group="남원 읍내(길가 소품)", kind="prop", flatten=False)
    return n


def screen_estimate(P):
    """게임 시점 화면 추정: 카메라가 남쪽, 플레이어 (px,pz) 기준 x±35, z −85…+12 창 안 삼각형 합 최대"""
    best = (0, None)
    for px in range(-3360, -3060, 10):
        for pz in range(120, 540, 10):
            s = sum(t for (x, z, t) in P.tris if px - 35 <= x <= px + 35 and pz - 85 <= z <= pz + 12)
            if s > best[0]:
                best = (s, (px, pz))
    return best


def main():
    R = Region()
    rng = random.Random(SEED)
    P = Placer(R)
    notes = place_landmarks(P, R, rng)
    hs = place_houses(P, R, rng)
    mk = place_market(P, R, rng)
    ms = place_misc(P, R, rng)
    fs = place_fieldside(P, R, rng)
    sp = place_street_props(P, R, rng)
    print("길가 소품", sp)

    # ── 최종 검사: 건물 footprint 겹침(파이썬 SAT) ──
    bad = []
    shp = [s for s in P.shapes if s[2] != "keepout"]
    for i in range(len(shp)):
        for j in range(i + 1, len(shp)):
            a, b = shp[i], shp[j]
            if a[1] == b[1] or (a[1].startswith("읍성") and b[1].startswith("읍성")):
                continue
            if a[1].startswith("nw_gaeksa_wall") and b[1].startswith("nw_gaeksa_wall"):
                continue
            if {a[1], b[1]} <= {"nw_gaeksa_samun"} | {s[1] for s in shp if s[1].startswith("nw_gaeksa_wall")}:
                continue
            if poly_overlap(a[0], b[0]):
                bad.append((a[1], b[1]))
    n_build = sum(1 for it in P.items if it["kit"] in BUILDING_KITS)
    n_house = sum(1 for it in P.items if it["kit"] in ("village/house_compound", "village/choga", "village/giwa"))
    total = sum(t for (_, _, t) in P.tris)
    scr = screen_estimate(P)
    kinds = {}
    for it in P.items:
        k = it["kit"] + ("/" + it["params"].get("size") if "size" in it["params"] else "")
        kinds[k] = kinds.get(k, 0) + 1
    doc = {
        "area": "namwon",
        "generator": "tools/placement/namwon.py (seed %d)" % SEED,
        "note": "남원 읍내(1870 전후 남원도호부 읍치). 게임 좌표, ry 라디안(0=정면 남향). 근거·가설은 docs/reports/placement-namwon.md",
        "items": P.items,
    }
    with open(OUT, "w") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    print("wrote", os.path.relpath(OUT, ROOT), "items", len(P.items))
    print("민가", n_house, "건물(민가+가가+주막)", n_build)
    print("종류", json.dumps(kinds, ensure_ascii=False))
    print("민가 띠", json.dumps(hs, ensure_ascii=False))
    print("장터", mk, "기타", json.dumps(ms, ensure_ascii=False), "짚가리", fs)
    print("랜드마크 메모", notes)
    print("거절 사유", P.rejects)
    print("삼각형 합(전체) %d, 화면 창 최대 %d at %s" % (total, scr[0], scr[1]))
    print("겹침", len(bad), bad[:10])
    return 0 if not bad else 1


if __name__ == "__main__":
    sys.exit(main())
