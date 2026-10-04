#!/usr/bin/env python3
"""북쪽 대표 도시 4곳 배치 생성기 — GG_HANYANG(한양) · HH_HWANGJU(황주) · PA_PYEONGYANG(평양) · HG_HAMHEUNG(함흥).

    python3 tools/placement/north.py GG_HANYANG            # region_data/GG_HANYANG/placement_north.json + 평면도
    python3 tools/placement/north.py all --noplan
    python3 tools/placement/north.py all --profiles         # 고을 성격표(north_profiles.py)를 region.json에 합쳐 쓰기만

남원 동쪽 생성기(east*.py)의 배치기·마을 짜임을 그대로 쓰고(지형 폴더만 바꿈), 문화권 가옥형(kit/culture/<문화권>/)을
고르는 집터(make_slot)를 덮어씌운다. 결정적(장소별 고정 seed). 키트 크기는 Godot으로 재서 tools/placement/north_bounds.json에 캐시.
성곽 선(region.json walls)은 엔진이 그린다고 보고 문(門)만 놓고, 성벽 띠는 비워 둔다(reserve). 황주 방형 읍성만 배치로 쌓는다.
근거·가설: docs/reports/placement-north.md
"""
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from north_common import *  # noqa: E402,F401,F403
from north_common import P, ET, EP, EV, E, PR, NP, np, ROOT, NorthPlacer, CStyle, style, Local, Rect, bkey, l2w  # noqa: E402
from north_common import ry_along, ry_cross, clamp_ry, wrap_half, polyline_at, polyline_len, polyline_project  # noqa: E402
import north_common as NC  # noqa: E402

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
ALL = ["GG_HANYANG", "HH_HWANGJU", "PA_PYEONGYANG", "HG_HAMHEUNG"]
RIDS = ALL if (not ARGS or ARGS[0] == "all") else [ARGS[0]]
BOUNDS = os.path.join(HERE, "north_bounds.json")
PREFIX = {"GG_HANYANG": "hy", "HH_HWANGJU": "hj", "PA_PYEONGYANG": "py", "HG_HAMHEUNG": "hg"}
OUTNAME = "placement_north.json"

# ================================================================ 문화권 집(make_slot 덮어쓰기)
CFP = {
    ("giho", "small"): [16.0, 15.0], ("giho", "medium"): [20.0, 21.0], ("giho", "large"): [24.0, 26.0], ("giho", "city"): [11.5, 14.0],
    ("haeseo", "small"): [16.0, 15.0], ("haeseo", "medium"): [19.0, 18.0], ("haeseo", "large"): [22.0, 22.0],
    ("gwanseo", "small"): [17.0, 15.0], ("gwanseo", "medium"): [19.0, 17.0], ("gwanseo", "large"): [22.0, 22.0],
    ("gwanbuk", "small"): [18.0, 17.0], ("gwanbuk", "medium"): [20.0, 19.0], ("gwanbuk", "large"): [24.0, 22.0],
}
NORTH_CULT = ("giho", "haeseo", "gwanseo", "gwanbuk")
VARIANTS = 14          # 같은 모양을 여러 번 쓰게(모델 수·불러오기 시간) — seed를 이 수 안으로 접는다


def sv(seed, salt=0):
    return (seed * 7 + salt * 13) % VARIANTS + 1


def compound_n(seed, size, st, roof=None):
    cul = st.culture
    kit = f"culture/{cul}/compound"
    p = {"seed": sv(seed, len(size)), "size": size}
    if cul == "giho" and size == "medium" and (roof or st.pick_roof(seed, 1)) == "giwa":
        p["roof"] = "giwa"
    if cul == "haeseo" and size == "large":
        p["roof"] = "giwa"
    return [P(kit, p, cat="house", kind=f"{cul[:2]}_{size}", footprint=CFP[(cul, size)], margin=0.8)]


def city_house(seed, st):
    """한양 도시 한옥(ㄷ/ㅁ, 필지 = footprint, 담 없음 — 집이 담). 북촌은 ㅁ 비율을 높인다."""
    shape = "ㅁ" if (seed % 10) < (5 if st.district == "bukchon" else 3) else "ㄷ"
    return [P("culture/giho/compound", {"seed": sv(seed, 3), "size": "city", "shape": shape}, cat="house", kind="gh_city",
              footprint=CFP[("giho", "city")], margin=0.6)]


def gwanbuk_props(seed):
    """관북 마당 일거리: 장작 井자 더미 + 땔감 줄(추위)."""
    return [P("village/firewood", {"seed": seed % 9 + 1, "style": "stack", "rows": 5}, cat="prop", kind="firewood", flatten=False,
              margin=0.4),
            P("village/firewood", {"seed": seed % 7 + 2, "len": 2.4, "rows": 5, "cover": True}, 2.8, 0.3, cat="prop", kind="firewood",
              flatten=False, margin=0.3),
            P("village/haystack", {"seed": seed % 11 + 1}, -3.0, 0.2, cat="prop", kind="haystack", flatten=False, margin=0.3)]


def yard_c(seed, house, wall, hx=7.0, z0=-5.6, z1=5.6, hz=-1.8):
    """작은 집 한 터(울 + 안채 + 장독) — 성 안 좁은 필지용. 원점 = 마당 가운데, 정면 +z. (hubs.yard_c를 줄인 것)"""
    r = random.Random((seed % 5) * 7919 + 17)     # 울 모양 5가지(모델 수를 줄임)
    gate_ = r.uniform(-2.0, 2.0)
    fp = [round(2 * hx + 0.8, 1), round(z1 - z0 + 0.8, 1)]
    rect = [-hx - 0.4, hx + 0.4, z0 - 0.4, z1 + 0.4]
    pts = [[round(gate_ - 1.6, 2), z1], [-hx, z1], [-hx, z0], [hx, z0], [hx, z1], [round(gate_ + 1.6, 2), z1]]
    pcs = [P("village/wall_run", {"seed": seed % 5 + 1, "kind": wall, "points": pts}, cat="wall", kind="wall_run", aabb=rect, flatten=False,
             margin=0.6)]
    kit, params, lz = house
    pcs.append(P(kit, params, 0.0, lz if lz is not None else hz, cat="house", kind=kit.split("/")[-1], inner=True, footprint=fp,
                 flatten=True, fp_center=True))
    pcs.append(P("village/jangdok", {"seed": seed % 5 + 1, "w": 2.2, "d": 1.8, "n": [2, 2, 1]}, hx - 2.0, z0 + 1.4, cat="prop", inner=True,
                 flatten=False))
    return pcs


def town_house(seed, st):
    """좁은 필지 한 채(문화권 몸채 하나 + 울): 해서 겹집 · 관서 평양 기와/서북 초가 · 관북 田자 · 기호 ㄱ자."""
    cul = st.culture
    giwa = st.pick_roof(seed, 2) == "giwa"
    v = sv(seed, 5)
    if cul == "haeseo":
        h = ("culture/haeseo/gyeopjip", {"seed": v, "plan": "il" if seed % 3 else "giyeok", "roof": "giwa" if giwa else "thatch"}, -1.6)
        return yard_c(seed, h, "todam_tile" if giwa else "fence_lite")
    if cul == "gwanseo":
        if giwa:
            h = ("culture/gwanseo/pyeongyang_giwa", {"seed": v, "plan": "il" if seed % 2 else "giyeok"}, -1.4)
            return yard_c(seed, h, "todam_tile", hx=9.4, z0=-6.6, z1=6.2)
        return yard_c(seed, ("culture/gwanseo/choga", {"seed": v}, -1.6), "todam_thatch", hx=8.2)
    if cul == "gwanbuk":
        pcs = yard_c(seed, ("culture/gwanbuk/jeonja", {"seed": v}, -1.2), "fence_lite", hx=8.6, z0=-6.6, z1=6.4)
        # 관북 마당 앞 장작 井자 더미(추위 신호, §8 — 골목에서 보이게 울 안 앞쪽)
        pcs.append(P("village/firewood", {"seed": seed % 7 + 1, "style": "stack", "rows": 5}, -6.6, 4.6, cat="prop", kind="firewood",
                     inner=True, flatten=False))
        return pcs
    h = ("culture/giho/giyeok", {"seed": v, "roof": "giwa", "sarang": False}, -1.0) if giwa else \
        ("culture/giho/choga_giyeok", {"seed": v}, -0.8)
    return yard_c(seed, h, "todam_tile" if giwa else "todam_thatch", hx=8.6, z0=-7.0, z1=6.4)


def py_lane_house(seed):
    """평양 골목 집(§8): 관서 짙은 기와 겹집(一자 깊은 몸채, 넓은 처마) 몸채를 골목에 바짝 — 마당 울 없이 대문간 칸이 골목에 붙는다."""
    r = random.Random(seed * 13 + 5)
    return [P("culture/gwanseo/pyeongyang_giwa", {"seed": sv(seed, 6), "plan": "giyeok" if r.random() < 0.25 else "il"}, cat="house",
              kind="py_lane", margin=0.4, road_min=0.2)]


def hg_lane_lot(seed):
    """함흥 골목 집 터(§8): 관북 田자 겹집 + 바자울(좁은 필지 15m) + 앞마당 장작 井자 더미 — 골목에 바짝."""
    pcs = yard_c(seed, ("culture/gwanbuk/jeonja", {"seed": sv(seed, 5)}, -1.4), "fence_lite", hx=7.0, z0=-6.6, z1=5.4)
    pcs.append(P("village/firewood", {"seed": seed % 7 + 1, "style": "stack", "rows": 5}, -4.4 if seed % 2 else 4.4, 4.4, cat="prop",
                 kind="firewood", inner=True, flatten=False))
    return pcs


def city_props(seed):
    """도성 안 마당·길가 소품(짚가리·디딜방아 같은 시골 것 없이): 장독 모음·작업 마당 + 평상·독·소쿠리·절구."""
    r = seed % 24
    return [P("village/yard_props", {"seed": r + 1, "set": ("jars", "work")[r % 2]}, cat="prop", kind="yard_props", flatten=False,
              margin=0.4),
            P("village/props", {"seed": r + 1, "kind": ("pyeongsang", "dok", "soguri", "jeolgu")[r % 4]}, 4.6, 0.2, cat="prop",
              kind="props", flatten=False, margin=0.3)]


_orig_make_slot = EV.make_slot


def make_slot(kind, seed, st=None):
    cul = getattr(st, "culture", None)
    if kind == "cprops":
        return city_props(seed)
    if kind in ("jw", "shop", "garden", "props") and not (kind == "props" and cul == "gwanbuk"):
        return _orig_make_slot(kind, seed % 24 + 1, st)     # 소품 모양은 24가지로 접는다(모델 수·재기)
    if cul not in NORTH_CULT:
        return _orig_make_slot(kind, seed, st)
    if kind == "town":
        return town_house(seed, st)
    if kind == "py_lane":
        return py_lane_house(seed)
    if kind == "hg_lane":
        return hg_lane_lot(seed)
    if kind == "city":
        if cul == "giho":
            return city_house(seed, st)
        return compound_n(seed, "large", st)
    if kind == "yard":
        roof = st.pick_roof(seed)
        if roof == "giwa":
            return compound_n(seed, "large" if cul != "giho" else ("large" if seed % 3 == 0 else "medium"), st, roof="giwa")
        return compound_n(seed, "small" if seed % 5 < 3 else "medium", st, roof="choga")
    if kind.startswith("hc_"):
        return compound_n(seed, kind[3:], st)
    if kind == "props" and cul == "gwanbuk":
        return gwanbuk_props(seed)
    return _orig_make_slot(kind, seed, st)


EV.make_slot = make_slot
EV.MIX.update({
    "hy_city": [("city", 0.60), ("hc_large", 0.12), ("hc_medium", 0.12), ("yard", 0.08), ("cprops", 0.08)],
    "hy_bukchon": [("city", 0.50), ("hc_large", 0.34), ("hc_medium", 0.10), ("cprops", 0.06)],
    "hy_jongno": [("city", 0.62), ("shop", 0.28), ("cprops", 0.10)],
    "hy_jungchon": [("city", 0.54), ("hc_medium", 0.26), ("hc_large", 0.08), ("cprops", 0.08), ("garden", 0.04)],
    "hy_namchon": [("hc_small", 0.38), ("hc_medium", 0.28), ("city", 0.18), ("garden", 0.08), ("cprops", 0.08)],
    "hy_east": [("city", 0.36), ("hc_medium", 0.20), ("hc_small", 0.18), ("garden", 0.16), ("cprops", 0.10)],
    "hy_lane": [("city", 0.86), ("hc_small", 0.08), ("cprops", 0.06)],
    "hy_lane_bukchon": [("city", 0.94), ("cprops", 0.06)],
    "hy_lane_namchon": [("hc_small", 0.52), ("city", 0.38), ("cprops", 0.10)],
    "hy_out": [("hc_small", 0.40), ("hc_medium", 0.24), ("city", 0.12), ("garden", 0.14), ("props", 0.10)],
    "nb_eup": [("town", 0.40), ("yard", 0.18), ("hc_large", 0.14), ("hc_medium", 0.14), ("garden", 0.07), ("props", 0.07)],
    "nb_eup_in": [("town", 0.74), ("hc_small", 0.10), ("props", 0.10), ("garden", 0.06)],
    "nb_eup_small": [("hc_small", 0.55), ("garden", 0.20), ("props", 0.25)],
    "nb_eup_out": [("yard", 0.56), ("hc_medium", 0.14), ("hc_small", 0.12), ("garden", 0.10), ("props", 0.08)],
    "py_in": [("hc_large", 0.36), ("town", 0.34), ("hc_medium", 0.14), ("props", 0.10), ("garden", 0.06)],
    "py_jongno": [("hc_large", 0.46), ("shop", 0.36), ("props", 0.18)],
    "py_lane": [("py_lane", 0.70), ("town", 0.18), ("props", 0.06), ("garden", 0.06)],
    "hg_lane": [("hg_lane", 0.74), ("town", 0.12), ("props", 0.08), ("garden", 0.06)],
    "nb_village": [("yard", 0.52), ("hc_small", 0.16), ("hc_medium", 0.10), ("garden", 0.14), ("props", 0.08)],
    "nb_port": [("yard", 0.46), ("hc_medium", 0.20), ("props", 0.22), ("garden", 0.12)],
    "nb_cold": [("yard", 0.30), ("town", 0.22), ("hc_medium", 0.16), ("hc_small", 0.08), ("props", 0.17), ("garden", 0.07)],
})


# ================================================================ 기하·공용
def poly_contains(poly, x, z):
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, zi = poly[i][0], poly[i][1]
        xj, zj = poly[j][0], poly[j][1]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / ((zj - zi) or 1e-9) + xi:
            inside = not inside
        j = i
    return inside


def cells_in_poly(T, poly, lu=(1, 2, 3, 6), rect=None):
    xs = [p[0] for p in poly]; zs = [p[1] for p in poly]
    x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
    if rect:
        x0, z0, x1, z1 = max(x0, rect[0]), max(z0, rect[1]), min(x1, rect[2]), min(z1, rect[3])
    if x0 >= x1 or z0 >= z1:
        return np.zeros((0, 2))
    c = NC.rect_cells(T, x0, z0, x1, z1, lu=lu)
    return c[poly_contains_np(poly, c)] if len(c) else c


def poly_contains_np(poly, pts):
    """poly_contains를 점 배열에(같은 식)."""
    x, z = pts[:, 0], pts[:, 1]
    inside = np.zeros(len(pts), bool)
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, zi = poly[i][0], poly[i][1]
        xj, zj = poly[j][0], poly[j][1]
        inside ^= ((zi > z) != (zj > z)) & (x < (xj - xi) * (z - zi) / ((zj - zi) or 1e-9) + xi)
        j = i
    return inside


def cells_rect(T, rect, lu=(1, 2, 3, 6)):
    return NC.rect_cells(T, rect[0], rect[1], rect[2], rect[3], lu=lu)


def minus_rects(cells, rects):
    if len(cells) == 0:
        return cells
    m = np.ones(len(cells), bool)
    for r in rects:
        m &= ~((cells[:, 0] >= r[0]) & (cells[:, 0] <= r[2]) & (cells[:, 1] >= r[1]) & (cells[:, 1] <= r[3]))
    return cells[m]


def near_road_cells(T, cells, rids, dmax):
    if len(cells) == 0:
        return cells
    pts = []
    for rid in rids:
        rp = T.road(rid)["points"]
        Ltot = polyline_len(rp)
        s = 0.0
        while s <= Ltot:
            pts.append(polyline_at(rp, s)[:2]); s += 4.0
    pts = np.array(pts)
    keep = np.zeros(len(cells), bool)
    for i in range(0, len(cells), 2000):
        c = cells[i:i + 2000]
        d = np.sqrt(((c[:, None, :] - pts[None]) ** 2).sum(2)).min(1)
        keep[i:i + 2000] = d < dmax
    return cells[keep]


def reserve_rect(pl, x0, z0, x1, z1):
    pl.commit([P("reserve", {}, reserve=True, aabb=[x0, x1, z0, z1])], 0.0, 0.0, 0.0, "_", "_")


def wall_band(pl, pts, closed, half=8.0):
    """엔진이 그릴 성벽 선: 띠(폭 2·half)를 비워 둔다(집이 성벽에 걸리지 않게)."""
    n = len(pts)
    m = n if closed else n - 1
    for i in range(m):
        a, b = pts[i], pts[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L < 0.5:
            continue
        ry = -math.atan2(b[1] - a[1], b[0] - a[0])
        pl.commit([P("reserve", {}, reserve=True, aabb=[-L / 2 - half * 0.5, L / 2 + half * 0.5, -half, half])],
                  (a[0] + b[0]) / 2, (a[1] + b[1]) / 2, ry, "_", "_")


def wall_tangent_ry(wall_pts, x, z):
    best = None
    for a, b in zip(wall_pts[:-1], wall_pts[1:]):
        dx, dz = b[0] - a[0], b[1] - a[1]
        L2 = dx * dx + dz * dz
        if L2 == 0:
            continue
        t = max(0, min(1, ((x - a[0]) * dx + (z - a[1]) * dz) / L2))
        d = math.hypot(a[0] + dx * t - x, a[1] + dz * t - z)
        if best is None or d < best[0]:
            best = (d, dx, dz)
    return ry_along(best[1], best[2]) if best else 0.0


def gate(pl, T, lid, kit, params, ry, g, gc, label, fp=None, dx=0.0, dz=0.0, flatten=True):
    l = NC.lmk(T, lid)
    fl = dict(cat="landmark", kind="gate", label=label, nocheck=True, flatten=flatten, id=f"{pl.prefix}_gate_{lid}")
    if fp:
        fl["footprint"] = fp
    return pl.commit([P(kit, params, **fl)], l["x"] + dx, l["z"] + dz, ry, g, gc)


def court_pcs(seed, x0, x1, z0, z1, gate_x=0.0, gap=5.8, h=2.2, kit="landmark/gwana_wall"):
    pcs = []
    for w in NC.wall_pieces([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], True, [(gate_x, z1, gap)], seed, h):
        ln = w["params"]["length"]
        pcs.append(P(kit, w["params"], w["x"], w["z"], w["ry"], cat="wall", kind="wall", aabb=[-ln / 2, ln / 2, -0.55, 0.55],
                     flatten=False, nocheck=True))
    pcs.append(P("reserve", {}, reserve=True, aabb=[x0, x1, z0, z1]))
    return pcs


def sajeon_row(pl, T, rid, s0, s1, g, gc, seed, bays=10, goods=None, sides=(-1, 1), setback=1.2, kit="landmark/hy_sijeon",
               depth=5.0, south_setback=None, south_signs=True, south_stalls=False):
    """큰길 양옆 시전 행랑 줄(길 북쪽은 정면이 길·남쪽, 남쪽은 ry+π로 길을 봄 — 운종가 키트와 같은 규칙).
    동서 큰길(§8): 카메라는 남쪽에서 북쪽을 보므로 간판 줄은 북쪽에 바짝, 남쪽(카메라 쪽) 줄은 south_setback만큼 물리고
    간판을 끈다(south_signs) — 플레이어를 덜 가리고, 그 틈에는 낮은 좌판(south_stalls)을 둔다."""
    rd = T.road(rid)
    pts, w = rd["points"], rd["width_m"]
    goods = goods or ["silk", "cloth", "paper", "fish", "mixed"]
    n = 0
    for side in sides:
        s = s0 + (6.0 if side > 0 else 0.0)
        k = 0
        while s < s1:
            prm = {"seed": sv(seed + k + (50 if side > 0 else 0)), "bays": bays, "goods": goods[(k + (side > 0)) % len(goods)]}
            if side > 0 and not south_signs:
                prm["signs"] = False
            bb = pl.aabb(kit, prm)
            wlen = bb[1] - bb[0]
            x, z, d = polyline_at(pts, s + wlen / 2)
            nx, nz = -d[1], d[0]
            if nz > 0:
                nx, nz = -nx, -nz       # 북쪽
            if side > 0:
                nx, nz = -nx, -nz
            sb = south_setback if (side > 0 and south_setback is not None) else setback
            off = w / 2 + sb + bb[3]
            ry = clamp_ry(ry_along(*d), math.radians(45)) + (math.pi if side > 0 else 0.0)
            L = Local(T, x, z, 60)
            pcs = [P(kit, prm, cat="market", kind="sijeon", label="시전 행랑", road_min=0.3, margin=0.4)]
            ok = pl.check(L, pcs, x + nx * off, z + nz * off, ry, {"max_drop": 2.6, "road_min": 0.3})
            if ok[0]:
                pl.commit(pcs, x + nx * off, z + nz * off, ry, g, gc)
                n += 1
                if side > 0 and south_stalls and sb > 3.5:
                    # 물린 줄 앞 틈(길가)에 낮은 좌판 — 칸 가운데쯤 하나씩
                    so = w / 2 + 1.6
                    for q, fr in enumerate((0.3, 0.75)):
                        sx_, sz_, _ = polyline_at(pts, s + wlen * fr)
                        jp = [P("village/jwapan", {"seed": sv(seed + k * 3 + q), "goods": goods[(k + q) % len(goods)]}, cat="market",
                                kind="jwapan", flatten=False, margin=0.3, road_min=-9)]
                        if pl.check(L, jp, sx_ + nx * so, sz_ + nz * so, ry, {"max_drop": 2.0, "road_min": -9})[0]:
                            pl.commit(jp, sx_ + nx * so, sz_ + nz * so, ry, g, gc)
                s += wlen + random.Random(seed * 31 + k).uniform(1.2, 3.0)
            else:
                s += 4.0
            k += 1
    return n


def road_s(T, rid, x, z):
    return polyline_project(T.road(rid)["points"], x, z)[0]


def fill(pl, T, cells, g, gc, mix, seed, st, pitch=18.0, limit=999, max_drop=2.8, in_frac=0.45, lu_ok=(1, 2, 3, 6), two=True):
    if len(cells) == 0:
        return 0
    cx, cz = float(cells[:, 0].mean()), float(cells[:, 1].mean())
    R = float(np.sqrt(((cells - [cx, cz]) ** 2).sum(1)).max()) + 20
    L = Local(T, cx, cz, R + 60)
    n = EV.fill_rows(pl, T, L, cells, g, gc, mix, seed, pitch=pitch, max_drop=max_drop, limit=limit, in_frac=in_frac, lu_ok=lu_ok,
                     ry=0.0, stats=pl.stats_, style=st, gap=(1.2, 2.6))
    if two and n < limit:
        n += EV.fill_rows(pl, T, L, cells, g, gc, mix, seed + 1, pitch=pitch, max_drop=max_drop, limit=limit - n, in_frac=in_frac,
                          lu_ok=lu_ok, ry=0.0, stats=pl.stats_, style=st, phase=pitch / 2, gap=(1.0, 2.2))
    pl.log.append(f"[fill] {g} 칸 {len(cells)} → {n}")
    return n


HOUSE_KINDS = ("city", "town", "yard", "hc_small", "hc_medium", "hc_large", "py_lane", "hg_lane")


def grid_fill(pl, T, cells, g, gc, mix, seed, st, step=(19.0, 18.0), limit=999, max_drop=3.0, lu_ok=(1, 2, 3, 6), in_frac=0.5,
              fallback=("town", "hc_small", "garden", "props"), small_p=0.35):
    """성 안·도시 구역 촘촘히: 어긋난 격자 점마다 섞음(mix)에서 집터를 뽑아 놓고, 안 되면 작은 집 → 텃밭·일거리 순으로.
    줄 짜임(fill_rows)보다 빈틈이 적다. 정면은 모두 남쪽(+z). 반환: 놓은 집터 수."""
    if len(cells) == 0:
        return 0
    rng = random.Random(seed)
    cx, cz = float(cells[:, 0].mean()), float(cells[:, 1].mean())
    R = float(np.sqrt(((cells - [cx, cz]) ** 2).sum(1)).max()) + 20
    L = Local(T, cx, cz, R + 60)
    x0, x1 = cells[:, 0].min(), cells[:, 0].max()
    z0, z1 = cells[:, 1].min(), cells[:, 1].max()
    sx, sz = step
    cellset = set((int(round(x / 4.0)), int(round(z / 4.0))) for x, z in cells)
    n = 0
    row = 0
    z = z0 + sz / 2
    while z <= z1 and n < limit:
        x = x0 + (sx / 2 if row % 2 else 0.0) + rng.uniform(0, 2.0)
        while x <= x1 and n < limit:
            if (int(round(x / 4.0)), int(round(z / 4.0))) not in cellset:
                x += 4.0
                continue
            k = int(x * 7 + z * 13) & 0xFFFF
            h = random.Random(seed * 100003 + k).random()
            first = EV.pick(EV.MIX[mix], h)
            seq = [first] + [f for f in fallback if f != first]
            done = None
            for j, kind in enumerate(seq):
                if kind not in HOUSE_KINDS and j > 0 and random.Random(seed + k + j).random() > small_p:
                    continue
                pcs = EV.make_slot(kind, seed * 1000 + k, st)
                xmin, w, zmin, zmax = EV.slot_box(pl, pcs)
                for dx, dz in ((0, 0), (1.5, 0), (-1.5, 0), (0, 1.5), (0, -1.5), (3, 0), (-3, 0)):
                    px = x + dx - (xmin + w / 2); pz = z + dz - (zmin + zmax) / 2
                    if EV._mask_frac(T, px, pz, 0.0, [xmin, xmin + w, zmin, zmax], lu_ok) < in_frac:
                        continue
                    res = pl.check(L, pcs, px, pz, 0.0, {"max_drop": max_drop, "road_min": 0.8})
                    if res[0]:
                        pl.commit(EV.fit_terrace(T, pcs, px, pz, 0.0), px, pz, 0.0, g, gc)
                        done = (kind, w)
                        break
                if done:
                    break
            if done:
                n += 1
                pl.stats_[done[0]] = pl.stats_.get(done[0], 0) + 1
                x += done[1] + rng.uniform(1.0, 2.2)
            else:
                x += 4.0
        z += sz
        row += 1
    pl.log.append(f"[grid] {g} 칸 {len(cells)} → {n}")
    return n


def streets(pl, T, cells, rids, g, gc, mix, seed, st, limit=999, max_drop=2.8, in_frac=0.3, setback=(1.2, 4.2)):
    if len(cells) == 0:
        return 0
    cx, cz = float(cells[:, 0].mean()), float(cells[:, 1].mean())
    R = float(np.sqrt(((cells - [cx, cz]) ** 2).sum(1)).max()) + 20
    L = Local(T, cx, cz, R + 60)
    n = 0
    for k, rid in enumerate(rids):
        rd = T.road(rid)
        n += EV.street_rows(pl, T, L, cells, rd["points"], rd["width_m"], g, gc, mix, seed + k * 17, st, stats=pl.stats_,
                            max_drop=max_drop, limit=limit - n, in_frac=in_frac, setback=setback)
        if n >= limit:
            break
    pl.log.append(f"[street] {g} {rids} → {n}")
    return n


def _in_any_rect(pl, x, z, pad=1.5):
    for o, _ in pl.near_rects(x, z, 40.0):
        dx, dz = x - o.cx, z - o.cz
        if abs(dx * o.ux + dz * o.uz) <= o.hx + pad and abs(dx * o.vx + dz * o.vz) <= o.hz + pad:
            return True
    return False


def add_lane(pl, T, g, pts, w=3.0):
    """골목 하나: 배치기 지형(T.roads)에 더해 집이 길 위에 앉지 않게 하고, placement alleys로 내보내 엔진이 마을길로 칠하게 한다."""
    rid = f"{pl.prefix}_lane_{len(pl.alleys):03d}"
    T.roads.append({"id": rid, "name": "골목", "class": "마을길", "width_m": w, "points": pts})
    T._road_segs = T._segs([(r["points"], r["width_m"], r["id"]) for r in T.roads])
    pl.alleys.append({"group": g, "width_m": w, "points": pts})
    return rid


def w2l(fr, x, z):
    """월드 → 골목 틀(fr = (ox, oz, ry)) 로컬. l2w의 역."""
    ox, oz, ry = fr
    c, s_ = math.cos(ry), math.sin(ry)
    dx, dz = x - ox, z - oz
    return dx * c - dz * s_, dx * s_ + dz * c


def lane_grid(pl, T, cells, rect, g, pitch=21.0, ns_every=72.0, w=3.0, min_len=24.0, seed=0, lu_ok=(1, 2, 3, 6), frame=None):
    """도시 구역 골목 격자: 동서 골목을 pitch 간격으로(집이 골목 북쪽에 붙어 남쪽 골목을 본다), 남북 골목을 ns_every 간격으로.
    구역 칸·마을 터 위만, 이미 놓인 것(궁궐·관청·큰길가 집·예약 띠)은 끊고 지나간다. 반환: 동서 골목 id 목록.
    frame = (ox, oz, ry)이면 격자를 그 틀(고을 큰길 방향)로 돌린다 — rect는 틀 로컬 좌표. None이면 월드 축(한양)."""
    if len(cells) == 0:
        return []
    fr = frame or (0.0, 0.0, 0.0)
    cellset = set((int(round(x / 4.0)), int(round(z / 4.0))) for x, z in cells)
    rng = random.Random(seed)
    A, B, W_, _ = T._road_segs          # 이 구역 골목을 더하기 전 길(남북 골목이 동서 골목에 끊기지 않게)
    x0, z0, x1, z1 = rect
    cs = [l2w(fr[0], fr[1], fr[2], u, v) for u, v in ((x0, z0), (x1, z0), (x0, z1), (x1, z1))]
    wx0, wx1 = min(c[0] for c in cs), max(c[0] for c in cs)
    wz0, wz1 = min(c[1] for c in cs), max(c[1] for c in cs)
    m = (np.maximum(A[:, 0], B[:, 0]) > wx0 - 20) & (np.minimum(A[:, 0], B[:, 0]) < wx1 + 20) & \
        (np.maximum(A[:, 1], B[:, 1]) > wz0 - 20) & (np.minimum(A[:, 1], B[:, 1]) < wz1 + 20)
    A, B, W_ = A[m], B[m], W_[m]
    AB = B - A
    L2 = (AB ** 2).sum(1)
    L2[L2 == 0] = 1e-9

    def clear(x, z):
        if len(A) == 0:
            return 1e9
        P_ = np.array([x, z])
        t = np.clip(((P_ - A) * AB).sum(1) / L2, 0, 1)
        return float((np.sqrt(((A + AB * t[:, None] - P_) ** 2).sum(1)) - W_ / 2).min())

    def ok(u, v):
        x, z = l2w(fr[0], fr[1], fr[2], u, v)
        return (int(round(x / 4.0)), int(round(z / 4.0))) in cellset and T.landuse(x, z) in lu_ok and \
            clear(x, z) > 1.0 and not _in_any_rect(pl, x, z)

    def runs(samples):
        out, cur = [], []
        for q, good in samples:
            if good:
                cur.append(q)
            else:
                if len(cur) >= 2:
                    out.append(cur)
                cur = []
        if len(cur) >= 2:
            out.append(cur)
        return out

    def wpt(u, v):
        x, z = l2w(fr[0], fr[1], fr[2], u, v)
        return [round(x, 1), round(z, 1)]
    ew = []
    z = z0 + pitch * 0.6 + rng.uniform(0, 3.0)
    while z < z1 - 6:
        xs = np.arange(x0, x1 + 0.1, 2.0)
        for r in runs([((float(x), z), ok(float(x), z)) for x in xs]):
            if r[-1][0] - r[0][0] >= min_len:
                rid = add_lane(pl, T, g, [wpt(r[0][0], z), wpt(r[-1][0], z)], w)
                pl.lane_local[rid] = (fr, round(r[0][0], 1), round(r[-1][0], 1), round(z, 1))
                ew.append(rid)
        z += pitch
    x = x0 + ns_every * 0.5 + rng.uniform(0, 8.0)
    while x < x1 - 6:
        zs = np.arange(z0, z1 + 0.1, 2.0)
        for r in runs([((x, float(z)), ok(x, float(z))) for z in zs]):
            if r[-1][1] - r[0][1] >= min_len:
                add_lane(pl, T, g, [wpt(x, r[0][1]), wpt(x, r[-1][1])], w)
        x += ns_every
    pl.log.append(f"[lanes] {g}: 동서 {len(ew)}")
    return ew


def lane_rows(pl, T, cells, lane_ids, g, gc, mix, seed, st, limit=999, setback=0.5, max_drop=3.2, gap=(0.6, 1.6),
              fallback=("city", "cprops")):
    """동서 골목 북쪽에 집을 바짝(물림 setback m, 남향 ry 0) 늘어놓는다 — 대문·정면이 골목을 본다.
    섞음(mix)에서 집터를 뽑고, 안 맞으면 fallback 순(한양: 도시 한옥 → 소품). (street_rows는 집이 자주 실패해 줄이 소품뿐이 되었다)
    골목이 돌린 틀(lane_grid frame)에 있으면 집도 그 틀 방향(ry)으로 놓는다."""
    if len(cells) == 0 or not lane_ids:
        return 0
    cellset = set((int(round(x / 4.0)), int(round(z / 4.0))) for x, z in cells)
    n = 0
    for li, rid in enumerate(lane_ids):
        rd = T.road(rid)
        fr, xa, xb, zl = pl.lane_local[rid]
        xa, xb = min(xa, xb), max(xa, xb)
        ox, oz, ry = fr
        cx_, cz_ = l2w(ox, oz, ry, (xa + xb) / 2, zl - 10)
        L = Local(T, cx_, cz_, (xb - xa) / 2 + 40)
        rng = random.Random(seed + li * 31)
        x = xa + rng.uniform(0.0, 1.2)
        k = 0
        while x < xb - 4 and n < limit:
            k += 1
            sd = seed * 1000 + li * 97 + k
            first = EV.pick(EV.MIX[mix], random.Random(sd).random())
            done = None
            for kind in [first] + [q for q in fallback if q != first]:
                pcs = EV.make_slot(kind, sd, st)
                xmin, w, zmin, zmax = EV.slot_box(pl, pcs)
                if x + w > xb + 0.5:
                    continue
                px = x - xmin
                pz = zl - rd["width_m"] / 2 - setback - zmax
                ccx, ccz = l2w(ox, oz, ry, px + xmin + w / 2, pz + (zmin + zmax) / 2)
                if (int(round(ccx / 4.0)), int(round(ccz / 4.0))) not in cellset:
                    continue
                wx, wz = l2w(ox, oz, ry, px, pz)
                res = pl.check(L, pcs, wx, wz, ry, {"max_drop": max_drop, "road_min": 0.3})
                if res[0]:
                    pl.commit(EV.fit_terrace(T, pcs, wx, wz, ry), wx, wz, ry, g, gc)
                    done = (kind, w)
                    break
            if done:
                if done[0] in HOUSE_KINDS:
                    n += 1
                pl.stats_[done[0]] = pl.stats_.get(done[0], 0) + 1
                x += done[1] + rng.uniform(*gap)
            else:
                x += 3.0
    pl.log.append(f"[lane rows] {g} → 집 {n}")
    return n


def block_rows(pl, T, rect, g, gc, seed, st, kit_fn, depth=8.9, lane_w=3.0, setback=0.5, gap=(0.9, 1.8), max_drop=2.4):
    """읍내 구획을 남향 집 줄로 촘촘히: 남쪽 끝부터 골목(폭 lane_w) + 그 북쪽에 집 앞을 골목에 바짝(setback) 붙인 줄을 되풀이.
    kit_fn(seed) → (kit, params). 집은 마당 울 없이 몸채만(읍내 거리집). 반환: 놓은 집 수."""
    x0, z0, x1, z1 = rect
    rng = random.Random(seed)
    L = Local(T, (x0 + x1) / 2, (z0 + z1) / 2, max(x1 - x0, z1 - z0) / 2 + 40)
    pitch = lane_w + setback + depth + 0.8
    zl = z1 - lane_w / 2
    n = 0
    k = 0
    while zl - lane_w / 2 - setback - depth > z0 - 0.5:
        add_lane(pl, T, g, [[round(x0, 1), round(zl, 1)], [round(x1, 1), round(zl, 1)]], lane_w)
        L = Local(T, (x0 + x1) / 2, (z0 + z1) / 2, max(x1 - x0, z1 - z0) / 2 + 40)
        x = x0 + rng.uniform(0.0, 1.5)
        while x < x1:
            k += 1
            kit, prm = kit_fn(seed * 100 + k)
            bb = pl.aabb(kit, prm)
            w = bb[1] - bb[0]
            if x + w > x1 + 0.5:
                break
            hx = x - bb[0]
            hz = zl - lane_w / 2 - setback - bb[3]
            pcs = [P(kit, prm, cat="house", kind=kit.split("/")[-1], margin=0.4, road_min=0.2)]
            ok = pl.check(L, pcs, hx, hz, 0.0, {"max_drop": max_drop, "road_min": 0.2})
            if ok[0]:
                pl.commit(EV.fit_terrace(T, pcs, hx, hz, 0.0), hx, hz, 0.0, g, gc)
                n += 1
                x += w + rng.uniform(*gap)
            else:
                x += 3.0
        zl -= pitch
    pl.log.append(f"[block] {g} {tuple(round(v) for v in rect)} → {n}")
    return n


GREEN_KITS = ("nature/garden_plot", "nature/pumpkin_vine", "nature/big_tree")


def urban_rects(pl, T, poly, rects, green_groups=(), step=8.0, pad=6.0):
    """도시 땅(§8): rects(구역 사각형 합) 안 step 칸 가운데가 성곽(poly) 안·마을 터(6)이고 궁궐·종묘·정원(green_groups 묶음,
    텃밭·큰 나무) 자리가 아니면 도시 칸. 줄마다 이어 붙여 [x0,z0,x1,z1] 사각형으로 — 엔진이 그 안 마을 터를 흙으로 칠하고 풀·꽃을 비운다."""
    X0 = min(r[0] for r in rects); Z0 = min(r[1] for r in rects); X1 = max(r[2] for r in rects); Z1 = max(r[3] for r in rects)
    nx = int(math.ceil((X1 - X0) / step)); nz = int(math.ceil((Z1 - Z0) / step))
    cx = X0 + (np.arange(nx) + 0.5) * step
    cz = Z0 + (np.arange(nz) + 0.5) * step
    GX, GZ = np.meshgrid(cx, cz)
    pts = np.stack([GX.ravel(), GZ.ravel()], 1)
    ok = np.zeros(len(pts), bool)
    for r in rects:
        ok |= (pts[:, 0] >= r[0]) & (pts[:, 0] <= r[2]) & (pts[:, 1] >= r[1]) & (pts[:, 1] <= r[3])
    ok &= poly_contains_np(poly, pts)
    ok &= np.isin(NC.landuses(T, pts), (4, 6))
    for it in pl.items:
        if it["group"] in green_groups:
            m = pad
        elif it["kit"] in GREEN_KITS:
            m = 2.0
        else:
            continue
        rc = Rect(it["x"], it["z"], it["ry"], it["_aabb"], m)
        cs = rc.corners()
        bx0 = min(c[0] for c in cs); bx1 = max(c[0] for c in cs); bz0 = min(c[1] for c in cs); bz1 = max(c[1] for c in cs)
        ok &= ~((pts[:, 0] > bx0 - step / 2) & (pts[:, 0] < bx1 + step / 2) & (pts[:, 1] > bz0 - step / 2) & (pts[:, 1] < bz1 + step / 2))
    ok = ok.reshape(nz, nx)
    out = []
    for j in range(nz):
        i = 0
        while i < nx:
            if ok[j, i]:
                i0 = i
                while i < nx and ok[j, i]:
                    i += 1
                out.append([round(X0 + i0 * step, 1), round(Z0 + j * step, 1), round(X0 + i * step, 1), round(Z0 + (j + 1) * step, 1)])
            else:
                i += 1
    pl.urban.extend(out)
    pl.log.append(f"[urban] 도시 땅 사각형 {len(out)}, 칸 {int(ok.sum())} ({ok.sum() * step * step / 1e4:.1f} ha)")
    return out


def first_land(T, x0, z0, x1, z1, step=1.0):
    """(x0,z0)(물)에서 (x1,z1) 쪽으로 가며 처음 뭍(토지이용≠5)이 되는 점."""
    L = math.hypot(x1 - x0, z1 - z0)
    n = int(L / step)
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n; z = z0 + (z1 - z0) * i / n
        if T.landuse(x, z) != 5:
            return x, z
    return x1, z1


def naru_set(pl, T, wx, wz, lx, lz, g, gc, seed, n_boats=4, cul=None, big=False):
    """나루(§25): 물가 선창(py_daedong_naru) + 나룻배 + 사공 집 + 주막 + 말 대기(외양간) + 짐(짚가리·지게) + 창고."""
    ex, ez = first_land(T, wx, wz, lx, lz)
    ux, uz = (wx - lx), (wz - lz)
    d = math.hypot(ux, uz) or 1
    ux, uz = ux / d, uz / d
    ry = math.atan2(ux, uz)        # 로컬 +z가 물 쪽
    px, pz = ex - ux * 1.0, ez - uz * 1.0
    pl.commit([P("landmark/py_daedong_naru", {"seed": seed % 5 + 1, "pier": 10.0 if big else 7.0}, cat="landmark", kind="naru",
                 label="나루", flatten=False, nocheck=True, clear_veg=True)], px, pz, ry, g, gc)
    NC.boats(pl, wx, wz, g, gc, seed, n=n_boats, R=45)
    st_x, st_z = ex - ux * 22, ez - uz * 22
    NC.search(pl, NC.jumak_c(seed + 1, None), st_x, st_z, 40, g, gc, seed + 1, {"max_drop": 2.6})
    NC.search(pl, [P("village/oeyanggan", {"seed": seed % 6 + 1}, cat="house", kind="oeyanggan", label="말 대기")], st_x, st_z, 45, g,
              gc, seed + 2, {"max_drop": 2.6})
    NC.search(pl, [P("village/choga", {"seed": seed % 9 + 1}, cat="house", kind="sagong", label="사공 집")], st_x, st_z, 45, g, gc,
              seed + 3, {"max_drop": 2.6})
    NC.warehouses(pl, st_x, st_z, g, gc, seed + 4, n=4 if big else 2, R=50)
    NC.scatter_props(pl, ex - ux * 10, ez - uz * 10, 14, g, gc, seed + 5, "village/props",
                     lambda k: {"seed": seed + k, "kind": ["jige", "dok", "pyeongsang"][k % 3]}, 4 if big else 2,
                     aabb=[-1.2, 1.2, -1.2, 1.2])


def port_set(pl, T, sid, g, gc, seed, st, warehouses_n=8, boats_n=6, road=None):
    """포구(§26): 객주·창고·상인이 나루보다 많다 — 창고 줄 + 객주(큰 집) + 좌판 + 배."""
    s = NC.stl(T, sid)
    x, z = s["x"], s["z"]
    NC.warehouses(pl, x, z, g, gc, seed, n=warehouses_n, R=70)
    for k in range(3):
        NC.search(pl, compound_n(seed + 40 + k, "large", st, roof="giwa"), x, z, 70, g, gc, seed + 40 + k, {"max_drop": 2.8})
    for k in range(5):
        NC.search(pl, [P("village/jwapan", {"seed": seed + k, "goods": ["fish", "grain", "straw", "mixed", "fish"][k]}, cat="market",
                         kind="jwapan", flatten=False, margin=0.6)], x, z, 50, g, gc, seed + 60 + k, {"max_drop": 2.0})
    NC.search(pl, NC.jumak_c(seed + 70, None), x, z, 60, g, gc, seed + 70)
    NC.search(pl, NC.jumak_c(seed + 71, None), x, z, 60, g, gc, seed + 71)
    NC.boats(pl, x, z, g, gc, seed + 80, n=boats_n, R=140)


def village(pl, T, rid, sid, g, gc, mix, seed, limit=40, road=None, toward=None, square=True):
    st = NC.style(T, rid, sid)
    s = NC.stl(T, sid)
    if road is None:
        road = NC.nearest_road_id(T, s)
    return E.village2(pl, T, sid, g, gc, mix, seed, road=road, toward=toward, square=square, wells=1, limit=limit, style=st,
                      layout="rows", stats=pl.stats_)


def jumak_on(pl, T, rid, xz, ds, g, gc, seed, label):
    rp = T.road(rid)["points"]
    s, _ = polyline_project(rp, *xz)
    x, z, _ = polyline_at(rp, s + ds)
    r = NC.search(pl, NC.jumak_c(seed, None), x, z - 6, 50, g, gc, seed, {"max_drop": 3.0})
    if r:
        r[0]["_label"] = label
    return r


def lm_put(pl, T, lid, pcs, g, gc, ry=0.0, dx=0.0, dz=0.0, R=0.0, rules=None, seed=1):
    l = NC.lmk(T, lid)
    return NC.put(pl, pcs, l["x"] + dx, l["z"] + dz, ry, g, gc, R=R, rules=rules or {"max_drop": 4.0, "road_min": 0.5}, seed=seed)


def ritual3(pl, T, sj, yd, sh, g="읍치 제의 시설", gc="rit", seed=800, names=("사직단", "여단", "성황사")):
    NC.ritual(pl, T, "landmark/sajikdan", {"seed": 1, "dual": False}, [25.0, 25.0], sj[0], sj[1], g, gc, seed + 1, names[0])
    NC.ritual(pl, T, "landmark/yeodan", {"seed": 1}, [19.0, 19.0], yd[0], yd[1], g, gc, seed + 2, names[1])
    NC.ritual(pl, T, "landmark/seonghwangsa", {"seed": 1, "tree_stub": True}, [20.0, 18.0], sh[0], sh[1], g, gc, seed + 3, names[2])


# ================================================================ 황주(해서 · 평지 방형 읍성)
def build_hwangju(pl, T):
    rid = "HH_HWANGJU"
    HS = NC.style(T, rid, "hwangju_eup")
    NC.bridges(pl, T)
    CX, CZ, H, WT = 31.0, -929.0, 73.0, 4.6
    G, GC = "황주 읍내", "eup"
    names = {"S": "남문", "E": "동문", "N": "북문", "W": "서문"}
    opens = {"S": "front", "E": "front", "N": "front", "W": "front"}
    NC.eupseong(pl, T, CX, CZ, H, H, names, "landmark/seong_wall", WT,
                lambda sd, nm: ("landmark/hj_eupseong_gate", {"seed": 11 + "SENW".index(sd), "name": nm, "open": opens[sd]}),
                "황주읍성", "seong", 1100, gate_w=24.0)   # 문 키트가 양옆 성벽 머리를 품는다(폭 23.8m) — 18m면 성벽 조각과 겹쳤다
    # 객사 제안관: 성 안 서북 구획, 동서길을 바라봄(가설: 사신 길 큰 객사)
    gz = -941.0
    pcs = [P("landmark/hj_gaeksa", {"seed": 21, "wing_bays": 4}, 0.0, -20.0, cat="civic", kind="gaeksa", label="제안관(객사)",
             footprint=[52.0, 14.0], nocheck=True),
           P("landmark/samun", {"seed": 22, "kind": "outer", "name": "제안관"}, 0.0, 0.0, cat="civic", kind="samun", label="제안관 삼문",
             nocheck=True)]
    pcs += court_pcs(2200, -29.0, 29.0, -52.5, 0.0, 0.0, 5.8)   # 북쪽 담을 북문 안쪽 머리(z −995.3)에서 1.5m 물림
    pl.commit(pcs, CX - 33.0, gz, 0.0, "객사 제안관", "gaeksa")
    # 황주목 관아: 성 안 동북 구획(외삼문 → 동헌 → 내아)
    pl.commit([P("landmark/hyeon_gwana", {"seed": 31, "width": 36, "depth": 40, "naesammun": True}, cat="civic", kind="gwana",
                 label="황주목 관아", footprint=[38.0, 44.0], nocheck=True)], CX + 35.5, -957.0, 0.0, "황주목 관아", "gwana")
    for tx in (CX + 28.0, CX + 43.0):
        pl.commit([P("village/torch_post", {"seed": 35}, cat="prop", kind="torch", flatten=False, nocheck=True)], tx, -934.0, 0.0,
                  "황주목 관아", "gwana")
    # 성 안 민가
    inner = (CX - H + WT + 1.5, CZ - H + WT + 1.5, CX + H - WT - 1.5, CZ + H - WT - 1.5)
    cin = cells_rect(T, inner, lu=(1, 2, 3, 6))
    # 성 안: 큰 집 묶음 대신 해서 겹집 몸채(一자, 울 없이)를 남향 줄로 촘촘히 — 남쪽 두 구획은 골목(3m)마다 한 줄, 관아 북쪽 띠도 한 줄.
    # 동서 큰길(eup_ew) 남쪽 첫 줄은 큰길을 등지고, 그다음 줄부터 골목 앞. 읍내 거리 짜임(평지 해서 고을)
    def hj_house(sd):
        r = random.Random(sd)
        return "culture/haeseo/gyeopjip", {"seed": sv(sd, 5), "plan": "il", "roof": "giwa" if r.random() < 0.3 else "thatch"}
    WI = WT + 1.0
    # 우물(§18 필수): 줄 짓기 전에 동서 큰길 남쪽 가에 둘
    for k, (wx, wz) in enumerate([(CX - 30, CZ + 7.0), (CX + 30, CZ + 7.0)]):
        NC.search(pl, [P("village/well", {"seed": 440 + k, "roof": k == 0}, cat="prop", kind="well", label="읍내 우물", margin=0.8)], wx, wz,
                  12, G, GC, 440 + k, face="none")
    for k, rect in enumerate([(CX - H + WI, CZ + 4.0, CX - 4.5, CZ + H - WI),          # 서남
                              (CX + 4.5, CZ + 4.0, CX + H - WI, CZ + H - WI),          # 동남
                              (CX + 4.5, CZ - H + WI, CX + H - WI, CZ - 49.5)]):       # 관아 북쪽 띠
        block_rows(pl, T, rect, G + "(성 안)", GC, 430 + k * 7, HS, hj_house)
    grid_fill(pl, T, cin, G + "(성 안)", GC, "nb_eup_in", 420, HS, step=(15.0, 15.0), in_frac=0.3,
              fallback=("town", "props", "garden"), small_p=0.5)
    # 남문 밖 장(의주대로 장거리)
    rng = random.Random(501)
    Lm = Local(T, CX, -800, 160)
    s0 = road_s(T, "uiju_south", CX, CZ + H + 14)
    E.market(pl, T, Lm, "uiju_south", s0 + 12, s0 + 110, "황주 장", "jang", rng, shops=7, jwapan=16)
    jst = NC.style(T, rid, "hwangju_jang")
    jc = EV.cells_of(T, NC.stl(T, "hwangju_jang"), T.region["settlements"])
    streets(pl, T, jc, ["uiju_south"], "황주 장", "jang", "nb_eup_out", 505, jst, limit=24)
    NC.search(pl, NC.jumak_c(503, None), CX + 18, CZ + H + 70, 40, "황주 장", "jang", 503)
    NC.search(pl, NC.jumak_c(504, None), CX - 20, CZ + H + 120, 40, "황주 장", "jang", 504)
    # 성 밖 민가(읍내 마을 터)
    s_ = NC.stl(T, "hwangju_eup")
    b = s_["bbox"]
    cout = cells_rect(T, (b[0], b[1], b[2], b[3]), lu=(6,))
    cout = minus_rects(cout, [(CX - H - 10, CZ - H - 10, CX + H + 10, CZ + H + 10)])
    # 성 밖은 길가 줄 위주로 줄임(성 안을 채운 만큼) — 읍내 전체가 §18 일반 읍성 40~100동 안에 들게
    streets(pl, T, cout, ["uiju_north", "gyeomipo_road", "east_lane", "uiju_south"], G + "(성 밖)", GC, "nb_eup_out", 450, HS, limit=52)
    fill(pl, T, cout, G + "(성 밖)", GC, "nb_eup_out", 470, HS, pitch=18.0, limit=16)
    for rid_, tw in [("uiju_south", (40, -560)), ("uiju_north", (40, -1200)), ("gyeomipo_road", (-300, -945))]:
        e = E.entrance(T, rid_, CX, CZ, 130, tw)
        if e:
            NC.gate_c(pl, T, rid_, e[1], G, GC, 480 + len(rid_), "haeseo")
    # 향교(동쪽 산기슭, 가설) + 제의 시설
    NC.search(pl, [P("landmark/hyanggyo", {"seed": 601, "width": 36.0, "depth": 48.0}, cat="landmark", kind="hyanggyo", label="황주향교",
                     footprint=[38.0, 52.0])], 175, -1000, 60, "황주향교", "gyo", 601, {"max_drop": 4.5, "road_min": 0.6},
              road_pref=(2.0, 40.0), ry=0.0)
    ritual3(pl, T, (-130, -985), (40, -1090), (160, -1070), names=("황주 사직단", "황주 여단", "황주 성황사"))
    # 월파루(황주천 가 누각, 가설 위치 = region.json)
    lm_put(pl, T, "wolparu", [P("landmark/py_bubyeongnu", {"seed": 701}, cat="landmark", kind="nu", label="월파루", footprint=[19.6, 13.0])],
           "월파루", "wolpa", R=20, seed=701)
    # 도화동(심청 이야기 — 고증 B, 소문으로만): 새김 바위 + 복숭아나무 + 우물
    village(pl, T, rid, "dohwadong", "도화동", "dohwa", "nb_village", 801, limit=22, road="dohwa_lane", toward=(-200, -480))
    lm_put(pl, T, "dohwadong_well", [P("village/well", {"seed": 802, "roof": True}, cat="landmark", kind="well", label="도화동 우물"),
                                    P("landmark/hj_dohwadong", {"seed": 803}, 6.0, -4.0, cat="landmark", kind="dohwa", label="도화동 바위",
                                      flatten=False)], "도화동", "dohwa", R=16, seed=802)
    # 황주천 건넛마을(나루·주막) · 천주 들마을 · 들마을 몇
    village(pl, T, rid, "namcheon_ferry_village", "황주천 건넛마을", "namcheon", "nb_village", 821, limit=10)
    NC.search(pl, NC.jumak_c(822, None), 110, -60, 40, "황주천 건넛마을", "namcheon", 822)
    village(pl, T, rid, "cheonju_village", "천주 들마을", "cheonju", "nb_village", 831, limit=10)
    for sid, sd in [("auto_village_01", 841), ("auto_village_03", 842), ("auto_village_05", 843), ("auto_village_06", 844)]:
        village(pl, T, rid, sid, f"들마을({sid})", "av", "nb_village", sd, limit=8)
    for rid_, xz, nm in [("uiju_north", (250, -1600), "의주대로 중화 쪽"), ("uiju_south", (380, 1250), "의주대로 봉산 쪽"),
                         ("gyeomipo_road", (-1200, -1250), "겸이포길")]:
        jumak_on(pl, T, rid_, xz, 0, "길가 주막", "rd", 900 + len(nm), "주막(" + nm + ")")


# ================================================================ 평양(관서 · 감영 · 대동강)
def build_pyeongyang(pl, T):
    rid = "PA_PYEONGYANG"
    reg = T.region
    GS = NC.style(T, rid, "pyeongyang_naeseong")
    walls = {w["id"]: w for w in reg["walls"]}
    nw = walls["pyeongyang_naeseong_wall"]["points"]
    jw = walls["pyeongyang_jungseong_wall"]["points"]
    NC.bridges(pl, T)
    # ── 성문(성벽 선은 엔진) ──
    G0 = "평양성 문"
    gate(pl, T, "daedongmun", "landmark/py_daedongmun", {"seed": 1}, math.pi / 2, G0, "gate", "대동문", fp=[24.0, 10.0])
    gate(pl, T, "botongmun", "landmark/py_botongmun", {"seed": 2}, -math.pi / 2, G0, "gate", "보통문", fp=[20.0, 9.0])
    gate(pl, T, "chilseongmun", "landmark/py_chilseongmun", {"seed": 3}, math.pi, G0, "gate", "칠성문", fp=[12.0, 7.0])
    gate(pl, T, "hyeonmumun", "landmark/py_chilseongmun", {"seed": 4}, math.pi, G0, "gate", "현무문", fp=[12.0, 7.0], flatten=False)
    gate(pl, T, "jeongeummun", "landmark/py_chilseongmun", {"seed": 5}, math.pi / 2, G0, "gate", "전금문", fp=[12.0, 7.0], flatten=False)
    gx = {g_: NC.lmk(T, g_) for g_ in ("daedongmun", "botongmun", "chilseongmun", "hyeonmumun", "jeongeummun")}
    for g_ in gx.values():      # 문 안팎 광장
        reserve_rect(pl, g_["x"] - 13, g_["z"] - 13, g_["x"] + 13, g_["z"] + 13)
    wall_band(pl, nw, True, 7.0)
    wall_band(pl, jw, False, 6.0)
    # ── 연광정·종각·대동관(객사) ──
    lm_put(pl, T, "ryeongwangjeong", [P("landmark/py_ryeongwangjeong", {"seed": 11}, cat="landmark", kind="pavilion", label="연광정",
                                        footprint=[28.0, 20.0], river_min=-9, road_min=-9)], "연광정", "ryeon", ry=math.pi / 2,
           dx=10, dz=-22, R=12, rules={"max_drop": 6.0, "road_min": -9, "river_min": -9, "lu_bad": ()}, seed=11)
    NC.search(pl, [P("landmark/hy_bosingak", {"seed": 12}, cat="landmark", kind="jonggak", label="평양 종각", footprint=[13.6, 10.0])],
              128, 22, 24, "평양 종로", "jongno", 12, {"max_drop": 2.6}, road_pref=(0.8, 5.0), ry=clamp_ry(ry_along(78 - 156, 33 - 73)))
    pcs = [P("landmark/gaeksa", {"seed": 13, "name": "대동관", "jeongdang_bays": 5, "wing_bays": 5}, 0.0, -18.0, cat="civic",
             kind="gaeksa", label="대동관(객사)", footprint=[60.0, 14.0], nocheck=True),
           P("landmark/samun", {"seed": 14, "kind": "outer", "name": "대동관"}, 0.0, 0.0, cat="civic", kind="samun", nocheck=True)]
    pcs += court_pcs(2300, -33.0, 33.0, -40.0, 0.0)
    NC.put(pl, pcs, 112.0, -2.0, clamp_ry(ry_along(78 - 156, 33 - 73)), "대동관", "gaeksa", R=30, seed=13,
           rules={"max_drop": 3.5, "road_min": 0.3})
    # ── 평안감영(선화당): 감영 앞길 끝, 남향 ──
    pl.commit([P("landmark/gwana", {"seed": 21, "width": 66, "depth": 74}, cat="civic", kind="gamyeong", label="평안감영(선화당)",
                 footprint=[68.0, 80.0], nocheck=True)], 26.0, -76.0, 0.0, "평안감영", "gamyeong")
    for tx in (18.0, 34.0):
        pl.commit([P("village/torch_post", {"seed": 22}, cat="prop", kind="torch", flatten=False, nocheck=True)], tx, -33.0, 0.0, "평안감영",
                  "gamyeong")
    # 사창(감영 곳간) 줄
    for k in range(4):
        NC.search(pl, [P("village/heotgan", {"seed": 23 + k, "w": 9.0, "d": 5.0, "walls": "three"}, cat="house", kind="changgo",
                         label="사창")], -45, -150, 40, "평안감영", "gamyeong", 23 + k, {"max_drop": 2.6})
    # 숭령전(단군·동명왕 사당 — 가설 자리: 종로 서쪽 북편)
    pcs = [P("landmark/dongheon", {"seed": 31, "bays": 5}, 0.0, -9.0, cat="civic", kind="shrine", label="숭령전", footprint=[18.0, 10.0],
             nocheck=True),
           P("landmark/samun", {"seed": 32, "kind": "inner"}, 0.0, 6.0, cat="civic", kind="samun", nocheck=True)]
    pcs += court_pcs(3100, -16.0, 16.0, -20.0, 8.0)
    NC.search(pl, pcs, -50, -10, 40, "숭령전", "sungnyeong", 31, {"max_drop": 3.0, "road_min": 0.5}, ry=clamp_ry(ry_along(-78, -33)),
              road_pref=(0.5, 12.0))
    # ── 모란봉: 을밀대·부벽루·기린굴·최승대·영명사 ──
    MR = {"max_drop": 9.0, "road_min": -9, "lu_bad": (5,)}
    lm_put(pl, T, "eulmildae", [P("landmark/py_eulmildae", {"seed": 201}, cat="landmark", kind="dae", label="을밀대",
                                  footprint=[17.4, 21.4])], "모란봉", "moran", R=14, rules=MR, seed=201)
    lm_put(pl, T, "bubyeongnu", [P("landmark/py_bubyeongnu", {"seed": 202}, cat="landmark", kind="nu", label="부벽루",
                                   footprint=[19.6, 13.0])], "모란봉", "moran", ry=math.pi / 2, R=14, rules=MR, seed=202)
    lm_put(pl, T, "girin_gul", [P("landmark/py_giringgul", {"seed": 203}, cat="landmark", kind="cave", label="기린굴",
                                  footprint=[13.0, 14.0], flatten=False)], "모란봉", "moran", ry=0.0, R=16, rules=MR, seed=203)
    lm_put(pl, T, "choeseungdae", [P("village/jeongja", {"seed": 204, "s": 4.0}, cat="landmark", kind="jeongja", label="최승대")],
           "모란봉", "moran", R=16, rules=MR, seed=204)
    pcs = [P("landmark/bogwangjeon", {"seed": 205}, 0.0, -6.0, cat="landmark", kind="beopdang", label="영명사", nocheck=True),
           P("landmark/samun", {"seed": 206, "kind": "inner"}, 0.0, 10.0, cat="landmark", kind="samun", nocheck=True)]
    lm_put(pl, T, "yeongmyeongsa", pcs, "영명사", "yeongmyeong", R=22, rules=MR, seed=205)
    # 기자릉(북쪽 산기슭): 봉분 + 석물
    lm_put(pl, T, "gijareung", [P("landmark/gj_tumulus", {"seed": 211, "radius": 8.0, "height": 3.6}, cat="landmark", kind="tumulus",
                                  label="기자릉", flatten=False, footprint=[16.0, 16.0]),
                                P("village/stone_jangseung", {"seed": 1, "variant": 0}, -6.0, 11.0, cat="prop", kind="seokin",
                                  flatten=False, nocheck=True),
                                P("village/stone_jangseung", {"seed": 2, "variant": 1}, 6.0, 11.0, cat="prop", kind="seokin",
                                  flatten=False, nocheck=True)], "기자릉", "gija", R=20, rules={"max_drop": 6.0, "road_min": 1.0}, seed=211)
    # ── 종로 장거리: 가가·좌판 + 평양 기와 가게집 ──
    rng = random.Random(41)
    Lj = Local(T, 0, 0, 260)
    s_a = road_s(T, "jongno_pyeongyang", 60, 25)
    E.market(pl, T, Lj, "jongno_pyeongyang", s_a, s_a + 90, "평양 종로", "jongno", rng, shops=8, jwapan=14)
    cin = cells_in_poly(T, nw)
    JS = NC.style(T, rid, "pyeongyang_jongno")
    streets(pl, T, cin, ["jongno_pyeongyang", "gamyeong_road", "chilseong_road"], "평양 종로", "jongno", "py_jongno", 45, JS, max_drop=3.0)
    # ── 내성 안 민가(§8): 종로 방향으로 돌린 골목 격자 → 골목마다 관서 짙은 기와 겹집을 바짝 → 남은 틈 채우기 ──
    for k, (wx, wz) in enumerate([(-80, 40), (60, -150), (140, -40)]):
        NC.search(pl, [P("village/well", {"seed": 70 + k, "roof": True}, cat="prop", kind="well", margin=1.0)], wx, wz, 30, "평양 내성",
                  "naeseong", 70 + k, face="none")
    fr = (0.0, 0.0, ry_along(220 - (-195), 99 - (-70)))      # 종로(대동문 → 보통문 쪽) 방향 틀
    loc = [w2l(fr, x_, z_) for x_, z_ in nw]
    prect = (min(u for u, _ in loc), min(v for _, v in loc), max(u for u, _ in loc), max(v for _, v in loc))
    lanes = lane_grid(pl, T, cin, prect, "평양 내성", pitch=14.6, ns_every=64.0, seed=61, frame=fr)
    lane_rows(pl, T, cin, lanes, "평양 내성", "naeseong", "py_lane", 62, GS, setback=0.4, max_drop=3.4, gap=(0.5, 1.4),
              fallback=("py_lane", "town", "props"))
    grid_fill(pl, T, cin, "평양 내성", "naeseong", "py_in", 60, GS, step=(17.0, 17.0), max_drop=3.4)
    urban_rects(pl, T, nw, [(min(p_[0] for p_ in nw), min(p_[1] for p_ in nw), max(p_[0] for p_ in nw), max(p_[1] for p_ in nw))],
                green_groups=("숭령전", "모란봉", "영명사"))
    # ── 중성 · 외성 ──
    jpoly = [[-181.6, 165.9], [-181.6, 431.2], [51.9, 464.4], [176.4, 331.7], [176.4, 180.0], [-25.9, 215.6]]
    jst = NC.style(T, rid, "jungseong")
    cj = cells_in_poly(T, jpoly)
    streets(pl, T, cj, ["jungseong_road"], "중성", "jungseong", "nb_village", 80, jst, max_drop=3.0)
    fill(pl, T, cells_in_poly(T, jpoly, lu=(6,)), "중성", "jungseong", "nb_village", 81, jst, pitch=18.0, limit=60)
    NC.search(pl, [P("landmark/hyanggyo", {"seed": 82, "width": 38.0, "depth": 50.0}, cat="landmark", kind="hyanggyo", label="평양향교",
                     footprint=[40.0, 54.0])], -110, 300, 70, "평양향교", "gyo", 82, {"max_drop": 4.0, "road_min": 0.6},
              road_pref=(2.0, 30.0), ry=0.0)
    village(pl, T, rid, "oeseong", "외성 들", "oeseong", "nb_village", 90, limit=14, road="jungseong_road", toward=(-207, 563))
    # ── 대동강 나루(대동문 앞) · 선교리 나루 ──
    naru_set(pl, T, 262.0, 113.0, 200.0, 92.0, "대동강 나루", "naru", 100, n_boats=6, big=True)
    village(pl, T, rid, "daedong_naru", "대동강 나루", "naru", "nb_port", 110, limit=16)
    naru_set(pl, T, 300.0, 125.0, 350.0, 150.0, "선교리 나루", "seongyo", 120, n_boats=3)
    village(pl, T, rid, "seongyo", "선교리", "seongyo", "nb_village", 130, limit=22, road="junghwa_road", toward=(600, 1031))
    village(pl, T, rid, "neungrado", "능라도", "neungra", "nb_village", 140, limit=8, square=False)
    NC.boats(pl, 470.0, -330.0, "능라도", "neungra", 141, n=2, R=60)
    village(pl, T, rid, "yanggakdo", "양각도", "yanggak", "nb_village", 150, limit=8, square=False)
    NC.boats(pl, -60.0, 880.0, "양각도", "yanggak", 151, n=2, R=70)
    # ── 보통문 밖 의주길 ──
    bst = NC.style(T, rid, "botong_out")
    cb = EV.cells_of(T, NC.stl(T, "botong_out"), reg["settlements"])
    streets(pl, T, cb, ["gwanseo_daero"], "보통문 밖", "botong", "nb_village", 300, bst, limit=26)
    NC.search(pl, NC.jumak_c(301, None), -330, -95, 40, "보통문 밖", "botong", 301)
    NC.search(pl, [P("village/oeyanggan", {"seed": 302}, cat="house", kind="mabang", label="마방")], -360, -110, 40, "보통문 밖",
              "botong", 302, {"max_drop": 2.6})
    NC.seonghwang(pl, -470.0, -190.0, "보통문 밖", "botong", 303)
    # ── 제의 시설·들마을·길가 주막 ──
    ritual3(pl, T, (-290, -40), (40, -420), (-120, -300), names=("평양 사직단", "평양 여단", "평양 성황사"))
    for sid, sd in [("auto_village_00", 401), ("auto_village_02", 402), ("auto_village_05", 403), ("auto_village_04", 404)]:
        village(pl, T, rid, sid, f"들마을({sid})", "av", "nb_village", sd, limit=8)
    jumak_on(pl, T, "junghwa_road", (640, 1300), 0, "길가 주막", "rd", 501, "주막(중화길)")
    jumak_on(pl, T, "gwanseo_daero", (-1189, -402), 0, "길가 주막", "rd", 502, "주막(관서대로)")
    jumak_on(pl, T, "chilseong_road", (14, -929), 0, "길가 주막", "rd", 503, "주막(칠성문길)")


# ================================================================ 함흥(관북 · 감영 · 성천강)
def build_hamheung(pl, T):
    rid = "HG_HAMHEUNG"
    reg = T.region
    GB = NC.style(T, rid, "hamheung_eup")
    hw = next(w for w in reg["walls"] if w["id"] == "hamheung_wall")["points"]
    # 만세교: 성천강 긴 나무다리(길이는 물길에 맞춤)
    c = next(x for x in reg["crossings"] if x["id"] == "manse_crossing")
    rd = T.road(c["road_id"]) if c.get("road_id") else T.road("gyeongheung_daero")
    s, _ = polyline_project(rd["points"], c["x"], c["z"])
    x1, z1, _ = polyline_at(rd["points"], max(0, s - 10)); x2, z2, _ = polyline_at(rd["points"], s + 10)
    dx, dz = x2 - x1, z2 - z1; n = math.hypot(dx, dz) or 1; dx, dz = dx / n, dz / n
    L = Local(T, c["x"], c["z"], 80)
    wy = L.water_y(c["x"], c["z"], c.get("river_id"))
    tA, tB, y, step = E.fit_span(T, L, c["x"], c["z"], dx, dz, wy, False)
    ln = round(max(40.0, (tB - tA) + 8.0), 1)
    tm = (tA + tB) / 2
    bx, bz = c["x"] + dx * tm, c["z"] + dz * tm
    pl.commit([P("landmark/hh_mansegyo", {"seed": 1, "length": ln, "deck": round(max(1.6, y - wy + 1.6), 2)}, cat="bridge", kind="mansegyo",
                 label="만세교", flatten=False, nocheck=True, y=round(wy - 0.6, 2), id="hg_br_mansegyo", clear_veg=True)],
              bx, bz, ry_cross(dx, dz), "만세교", "manse")
    reg["crossings"] = [x for x in reg["crossings"] if x["id"] != "manse_crossing"]
    NC.bridges(pl, T)
    # ── 성문·누정(성벽 선은 엔진) ──
    G0 = "함흥읍성 문"
    gate(pl, T, "hamheung_south_gate", "landmark/hh_eupseong_gate", {"seed": 1, "name": "남문", "open": "front"},
         wall_tangent_ry(hw, -409.8, 278.6), G0, "gate", "함흥읍성 남문", fp=[27.2, 22.7])
    gate(pl, T, "hamheung_east_gate", "landmark/hh_eupseong_gate", {"seed": 2, "name": "동문", "open": "front"}, math.pi / 2, G0, "gate",
         "함흥읍성 동문", fp=[27.2, 22.7])
    gate(pl, T, "nakminnu", "landmark/seongmun", {"seed": 3, "name": "낙민루", "lu": 2, "ongseong": False, "width": 16.0}, -math.pi / 2,
         G0, "gate", "낙민루", fp=[16.0, 10.0])
    lm_put(pl, T, "gucheongak", [P("landmark/py_bubyeongnu", {"seed": 4}, cat="landmark", kind="nu", label="구천각",
                                   footprint=[19.6, 13.0])], G0, "gate", R=16, rules={"max_drop": 8.0, "road_min": -9}, seed=4)
    for lid in ("hamheung_south_gate", "hamheung_east_gate", "nakminnu"):
        g_ = NC.lmk(T, lid)
        reserve_rect(pl, g_["x"] - 14, g_["z"] - 14, g_["x"] + 14, g_["z"] + 14)
    wall_band(pl, hw, True, 7.0)
    # ── 함경감영 선화당(성안길 끝, 남향) · 객사 풍패관 ──
    pl.commit([P("landmark/gwana", {"seed": 21, "width": 62, "depth": 70}, cat="civic", kind="gamyeong", label="함경감영(선화당)",
                 footprint=[64.0, 76.0], nocheck=True)], -414.0, 28.0, 0.0, "함경감영", "gamyeong")
    for tx in (-421.0, -407.0):
        pl.commit([P("village/torch_post", {"seed": 22}, cat="prop", kind="torch", flatten=False, nocheck=True)], tx, 69.0, 0.0, "함경감영",
                  "gamyeong")
    pcs = [P("landmark/gaeksa", {"seed": 23, "name": "풍패관", "jeongdang_bays": 5, "wing_bays": 5}, 0.0, -18.0, cat="civic",
             kind="gaeksa", label="풍패관(객사)", footprint=[60.0, 14.0], nocheck=True),
           P("landmark/samun", {"seed": 24, "kind": "outer", "name": "풍패관"}, 0.0, 0.0, cat="civic", kind="samun", nocheck=True)]
    pcs += court_pcs(2400, -33.0, 33.0, -40.0, 0.0)
    NC.search(pl, pcs, -335, 150, 50, "풍패관", "gaeksa", 23, {"max_drop": 3.2, "road_min": 0.3}, ry=0.0, road_pref=(0.5, 30.0))
    for k in range(4):
        NC.search(pl, [P("village/heotgan", {"seed": 25 + k, "w": 9.0, "d": 5.0, "walls": "three"}, cat="house", kind="changgo",
                         label="감영 창고")], -470, -20, 40, "함경감영", "gamyeong", 25 + k, {"max_drop": 2.6})
    # ── 성 안 민가(§8): 큰길가 줄 → 동서 골목 격자 → 골목마다 田자 집 터(바자울·장작 더미)를 바짝 → 남은 틈 ──
    cin = cells_in_poly(T, hw)
    for k, (wx, wz) in enumerate([(-470, 180), (-330, 60), (-300, 210)]):
        NC.search(pl, [P("village/well", {"seed": 40 + k, "roof": True}, cat="prop", kind="well", margin=1.0)], wx, wz, 30, "함흥 성 안",
                  "in", 40 + k, face="none")
    hrect = (min(p_[0] for p_ in hw), min(p_[1] for p_ in hw), max(p_[0] for p_ in hw), max(p_[1] for p_ in hw))
    lanes = lane_grid(pl, T, cin, hrect, "함흥 성 안", pitch=16.6, ns_every=60.0, seed=33)
    lane_rows(pl, T, cin, lanes, "함흥 성 안", "in", "hg_lane", 34, GB, setback=0.4, max_drop=3.4, gap=(0.4, 1.2),
              fallback=("hg_lane", "props"))
    streets(pl, T, cin, ["hamheung_inner", "bukcheong_road", "gyeongheung_daero"], "함흥 성 안", "in", "nb_cold", 30, GB, max_drop=3.0,
            setback=(0.6, 2.4))
    grid_fill(pl, T, cin, "함흥 성 안", "in", "nb_cold", 31, GB, step=(18.0, 17.0), max_drop=3.4)
    # ── 남문 밖 장(성천강 둑) ──
    jst = NC.style(T, rid, "hamheung_jang")
    rng = random.Random(51)
    Lm = Local(T, -420, 360, 200)
    # 남문에서 남동으로 나가는 길(본궁길 아래쪽)을 장거리로
    br = T.road("bongung_road")["points"]
    s_gate = polyline_project(br, -410, 290)[0]
    E.market(pl, T, Lm, "bongung_road", s_gate + 20, s_gate + 120, "함흥 장", "jang", rng, shops=7, jwapan=16,
             goods=["fish", "cloth", "grain", "straw", "mixed", "fish"])
    jc = EV.cells_of(T, NC.stl(T, "hamheung_jang"), reg["settlements"])
    jc = np.asarray(jc)[~poly_contains_np(hw, np.asarray(jc))] if len(jc) else jc
    streets(pl, T, jc, ["bongung_road", "gyeongheung_daero", "seoho_road"], "함흥 장", "jang", "nb_cold", 55, jst, max_drop=2.8, limit=60)
    fill(pl, T, jc, "함흥 장", "jang", "nb_cold", 56, jst, pitch=18.0, limit=50)
    NC.search(pl, NC.jumak_c(57, None), -440, 330, 40, "함흥 장", "jang", 57)
    NC.search(pl, NC.jumak_c(58, None), -560, 70, 40, "만세교", "manse", 58)
    # ── 만세교 서쪽 머리 주막·마방 ──
    mst = NC.style(T, rid, "manse_west")
    cm = EV.cells_of(T, NC.stl(T, "manse_west"), reg["settlements"])
    streets(pl, T, cm, ["gyeongheung_daero"], "만세교 서쪽", "mansew", "nb_cold", 60, mst, limit=16)
    NC.search(pl, NC.jumak_c(61, None), -760, 20, 40, "만세교 서쪽", "mansew", 61)
    NC.search(pl, [P("village/oeyanggan", {"seed": 62}, cat="house", kind="mabang", label="마방")], -800, 15, 40, "만세교 서쪽", "mansew",
              62, {"max_drop": 2.6})
    # ── 반룡산: 치마대 ──
    lm_put(pl, T, "chimadae", [P("nature/boulder", {"seed": 71, "s": 2.6}, cat="landmark", kind="dae", label="치마대",
                                 aabb=[-4.0, 4.0, -4.0, 4.0], flatten=False),
                               P("village/cairn", {"seed": 72, "altar": True}, 6.0, 3.0, cat="prop", kind="cairn", flatten=False)],
           "반룡산", "bannyong", R=14, rules={"max_drop": 8.0, "road_min": -9}, seed=71)
    # ── 함흥본궁 + 반송 + 본궁 아래 마을 ──
    l = NC.lmk(T, "hamheung_bongung")
    NC.put(pl, [P("landmark/hh_bongung", {"seed": 81}, cat="landmark", kind="bongung", label="함흥본궁", footprint=[66.0, 54.0])],
           l["x"], l["z"], 0.0, "함흥본궁", "bongung", R=30, rules={"max_drop": 4.0, "road_min": 0.5}, seed=81)
    NC.search(pl, [P("landmark/hh_bansong", {"seed": 82}, cat="landmark", kind="bansong", label="본궁 반송", footprint=[8.0, 8.0])],
              l["x"] + 20, l["z"] + 38, 20, "함흥본궁", "bongung", 82, {"max_drop": 3.0}, face="none")
    village(pl, T, rid, "bongung_village", "본궁 아래 마을", "bongungv", "nb_cold", 83, limit=24)
    village(pl, T, rid, "unheung", "운흥", "unheung", "nb_cold", 90, limit=22, road="unheung_lane", toward=(-200, 38))
    # ── 향교·제의 시설·들마을·길가 주막 ──
    NC.search(pl, [P("landmark/hyanggyo", {"seed": 95, "width": 36.0, "depth": 48.0}, cat="landmark", kind="hyanggyo", label="함흥향교",
                     footprint=[38.0, 52.0])], -150, 140, 70, "함흥향교", "gyo", 95, {"max_drop": 4.0, "road_min": 0.6},
              road_pref=(2.0, 40.0), ry=0.0)
    ritual3(pl, T, (-600, 230), (-330, -230), (-470, -120), names=("함흥 사직단", "함흥 여단", "함흥 성황사"))
    for sid, sd in [("auto_village_02", 101), ("auto_village_03", 102), ("auto_village_01", 103), ("auto_village_05", 104)]:
        village(pl, T, rid, sid, f"들마을({sid})", "av", "nb_cold", sd, limit=8)
    jumak_on(pl, T, "gyeongheung_daero", (-1373, 630), 0, "길가 주막", "rd", 111, "주막(정평길)")
    jumak_on(pl, T, "bukcheong_road", (902, 42), 0, "길가 주막", "rd", 112, "주막(북청길)")


# ================================================================ 한양(기호 · 도읍)
HY_DISTRICTS = [
    # (이름, 코드, rect x0,z0,x1,z1, mix, settlement id(style), pitch, limit)
    ("북촌", "bukchon", (-470, -1600, 60, -1245), "hy_bukchon", "bukchon", 16.0, 170),
    ("서촌(인왕산 아래)", "seochon", (-900, -1250, -700, -940), "hy_city", "hanyang_doseong_in", 17.0, 70),
    ("운현궁·인사동 골목", "insa", (-460, -1240, 240, -1000), "hy_city", "hanyang_doseong_in", 16.0, 180),
    ("피맛골(종로 뒤)", "pimat", (-480, -1000, 640, -925), "hy_jongno", "ungjongga", 15.0, 90),
    ("중촌(개천 가)", "jungchon", (-300, -885, 820, -690), "hy_jungchon", "jungchon", 16.0, 170),
    ("남촌(남산골)", "namchon", (-460, -560, 380, -140), "hy_namchon", "namchon", 17.0, 120),
    ("동촌(이현·종묘 동쪽)", "dongchon", (250, -1450, 830, -1000), "hy_east", "hanyang_doseong_in", 18.0, 120),
    ("숭례문 안(남대문로)", "namdaemun", (-700, -690, -300, -360), "hy_city", "hanyang_doseong_in", 16.0, 90),
    ("광희문 안", "gwanghui", (380, -840, 860, -560), "hy_east", "hanyang_doseong_in", 18.0, 70),
]


def build_hanyang(pl, T):
    rid = "GG_HANYANG"
    reg = T.region
    HY = NC.style(T, rid, "hanyang_doseong_in")
    wall = next(w for w in reg["walls"] if w["id"] == "hanyang_doseong_wall")["points"]
    # 도강점: 광통교는 전용 키트로(아래), 나머지는 기본(돌다리·징검다리·나룻배)
    skip = {"gwangtonggyo_x", "x_gaecheon_l_cheonggyecheon_19", "ogansumun_x"}
    keep = reg["crossings"]
    reg["crossings"] = [c for c in keep if c["id"] not in skip]
    NC.bridges(pl, T)
    reg["crossings"] = keep
    # ── 4대문·4소문(성벽 선은 엔진) ──
    G0 = "한양도성 문"
    gate(pl, T, "sungnyemun", "landmark/hy_sungnyemun", {"seed": 1}, 0.0, G0, "gate", "숭례문", fp=[30.0, 10.0])
    gate(pl, T, "heunginjimun", "landmark/hy_heunginjimun", {"seed": 2, "open": "east"}, math.pi / 2, G0, "gate", "흥인지문",
         fp=[31.2, 25.7])
    gate(pl, T, "donuimun", "landmark/hy_donuimun", {"seed": 3}, -math.pi / 2, G0, "gate", "돈의문", fp=[20.0, 8.0])
    sk = NC.lmk(T, "sukjeongmun")
    gate(pl, T, "sukjeongmun", "landmark/hy_sukjeongmun", {"seed": 4}, wall_tangent_ry(wall, sk["x"], sk["z"]), G0, "gate", "숙정문",
         fp=[14.0, 7.0], flatten=False)
    for lid, nm in [("hyehwamun", "혜화문"), ("gwanghuimun", "광희문"), ("changuimun", "창의문"), ("souimun", "소의문")]:
        l = NC.lmk(T, lid)
        gate(pl, T, lid, "landmark/seongmun", {"seed": 5 + len(lid), "name": nm, "lu": 1, "ongseong": False, "width": 13.0},
             wall_tangent_ry(wall, l["x"], l["z"]), G0, "gate", nm, fp=[13.0, 9.0], flatten=(lid != "changuimun"))
    # 오간수문(개천이 성 밖으로 나가는 다섯 홍예 수문) — seongmun 문루 없이 홍예 다섯
    og = NC.lmk(T, "ogansumun")
    pl.commit([P("landmark/seongmun", {"seed": 9, "name": "오간수문", "lu": 0, "ongseong": False, "width": 26.0, "height": 4.6, "aw": 3.0,
                                       "spring": 1.2, "arch_x": [-9.6, -4.8, 0.0, 4.8, 9.6], "doors": "open"},
                 cat="landmark", kind="sumun", label="오간수문", flatten=False, nocheck=True, footprint=[26.0, 8.0], id="hy_gate_ogansumun")],
              og["x"] - 26.0, og["z"] + 8.0, wall_tangent_ry(wall, og["x"], og["z"]), G0, "gate")
    for lid in ("sungnyemun", "heunginjimun", "donuimun", "hyehwamun", "gwanghuimun", "souimun", "ogansumun"):
        g_ = NC.lmk(T, lid)
        reserve_rect(pl, g_["x"] - 16, g_["z"] - 16, g_["x"] + 16, g_["z"] + 16)
    wall_band(pl, wall, False, 8.0)
    # ── 궁궐: 경복궁(광화문이 육조거리 북쪽 끝) ──
    GP = "경복궁"
    pl.commit([P("landmark/hy_gyeongbokgung", {"seed": 11}, cat="landmark", kind="palace", label="경복궁",
                 flatten=True)], -582.0, -1289.0, 0.0, GP, "gbg")   # footprint 없이: 경회루 못(water)이 시작 때 땅을 파게(로더 안내)
    for k, (hx, hz, ln) in enumerate([(-582, -1380, 64.0), (-622, -1420, 40.0), (-542, -1420, 40.0), (-582, -1460, 64.0)]):
        pl.commit([P("landmark/hy_haenggak", {"seed": 12 + k, "length": ln}, cat="landmark", kind="haenggak", flatten=True, nocheck=True)],
                  hx, hz, 0.0, GP, "gbg")
    pl.commit([P("landmark/hy_palace_gate", {"seed": 16, "name": "사정문", "stories": 1, "roof": "paljak", "H": 3.6}, cat="landmark",
                 kind="gate", flatten=True, nocheck=True)], -582.0, -1352.0, 0.0, GP, "gbg")
    for k in range(10):
        a = k * 2.399; r_ = 20 + 60 * math.sqrt((k + 1) / 10)
        NC.search(pl, [NC.tree(["zelkova", "broadleaf", "zelkova", "chestnut"][k % 4],
                               20 + k)], -582 + r_ * math.cos(a), -1520 + r_ * math.sin(a) * 0.5, 12, GP, "gbg", 20 + k,
                  {"max_drop": 5.0, "road_min": 1.0}, face="none", n=60)
    reserve_rect(pl, -700, -1600, -500, -1215)
    # 육조거리: 광화문 앞 큰길 양옆 관청(키트는 길이 130, 남쪽에 관청 둘씩 더)
    GY = "육조거리"
    pl.commit([P("landmark/hy_yukjo_geori", {"seed": 31, "length": 130.0, "gate": False}, cat="landmark", kind="yukjo", label="육조거리",
                 footprint=[110.0, 150.0], flatten=True)], -580.0, -1127.0, 0.0, GY, "yukjo")
    for i, (en, wn) in enumerate([("한성부", "공조"), ("사헌부", "장례원")]):
        z = -1127.0 - 65.0 + 26.0 + (3 + i) * 38.0
        pl.commit([P("landmark/hy_yukjo", {"seed": 40 + i, "name": en, "width": 34.0, "depth": 30.0}, cat="civic", kind="yukjo", label=en,
                     footprint=[30.0, 34.0], nocheck=True)], -580.0 + 35.0, z, -math.pi / 2, GY, "yukjo")
        pl.commit([P("landmark/hy_yukjo", {"seed": 50 + i, "name": wn, "width": 34.0, "depth": 30.0}, cat="civic", kind="yukjo", label=wn,
                     footprint=[30.0, 34.0], nocheck=True)], -580.0 - 35.0, z, math.pi / 2, GY, "yukjo")
    reserve_rect(pl, -640, -1205, -520, -935)
    # 창덕궁(돈화문이 돈화문로 북쪽 끝) · 종묘 · 사직단 · 운현궁
    pl.commit([P("landmark/hy_changdeokgung", {"seed": 61}, cat="landmark", kind="palace", label="창덕궁", footprint=[122.0, 100.0])],
              46.0, -1373.0, 0.0, "창덕궁", "cdg")
    reserve_rect(pl, -20, -1600, 220, -1325)
    pcs = [P("landmark/hy_jongmyo", {"seed": 62}, 0.0, -14.0, cat="landmark", kind="jongmyo", label="종묘", footprint=[112.6, 50.0], nocheck=True),
           P("landmark/hy_palace_gate", {"seed": 63, "name": "종묘 외대문", "stories": 1, "roof": "paljak", "H": 3.4}, 0.0, 44.0,
             cat="landmark", kind="gate", nocheck=True)]
    pcs += court_pcs(6300, -66.0, 66.0, -56.0, 44.0, 0.0, 8.5, h=3.0)
    lm_put(pl, T, "jongmyo", pcs, "종묘", "jongmyo", dz=4.0, R=20, rules={"max_drop": 5.0, "road_min": 0.3}, seed=62)
    lm_put(pl, T, "sajikdan", [P("landmark/hy_sajikdan", {"seed": 64}, cat="landmark", kind="sajikdan", label="사직단",
                                 footprint=[57.0, 57.0])], "사직단", "sajik", R=24, rules={"max_drop": 5.0, "road_min": 0.3}, seed=64)
    pcs = [P("culture/giho/compound", {"seed": 3, "size": "large"}, -14.0, -6.0, cat="civic", kind="unhyeon", label="운현궁 노락당",
             footprint=[24.0, 26.0], nocheck=True),
           P("culture/giho/compound", {"seed": 5, "size": "large"}, 14.0, -6.0, cat="civic", kind="unhyeon", footprint=[24.0, 26.0],
             nocheck=True),
           P("landmark/samun", {"seed": 66, "kind": "outer", "name": "운현궁"}, 0.0, 14.0, cat="civic", kind="samun", nocheck=True)]
    pcs += court_pcs(6600, -32.0, 32.0, -22.0, 14.0, 0.0, 5.8, h=2.6)
    lm_put(pl, T, "unhyeongung", pcs, "운현궁", "unhyeon", R=30, rules={"max_drop": 3.5, "road_min": 0.3}, seed=65)
    # 포도청(좌·우) · 성균관 · 경희궁 터 · 모화관 · 동관왕묘 · 서빙고 · 목멱산 봉수
    for lid, nm, sd, (dx, dz) in [("podocheong_left", "좌포도청", 71, (0.0, 20.0)), ("podocheong_right", "우포도청", 72, (5.0, -42.0))]:
        lm_put(pl, T, lid, [P("landmark/hyeon_gwana", {"seed": sd, "width": 34, "depth": 34, "naesammun": False}, cat="civic", kind="podo",
                              label=nm, footprint=[36.0, 38.0])], nm, "podo", dx=dx, dz=dz, R=30,
               rules={"max_drop": 3.0, "road_min": 0.5}, seed=sd)
    lm_put(pl, T, "seonggyungwan", [P("landmark/hyanggyo", {"seed": 73, "width": 48.0, "depth": 62.0}, cat="landmark", kind="hyanggyo",
                                      label="성균관(문묘)", footprint=[50.0, 66.0])], "성균관", "sgg", R=30,
           rules={"max_drop": 5.0, "road_min": 0.5}, seed=73)
    pcs = [P("landmark/hy_palace_gate", {"seed": 74, "name": "흥화문", "stories": 1, "roof": "ujin", "H": 3.8}, 0.0, 26.0,
             cat="landmark", kind="gate", label="경희궁 터", nocheck=True),
           P("landmark/hy_haenggak", {"seed": 75, "length": 30.0}, -20.0, -10.0, cat="landmark", kind="haenggak", nocheck=True),
           P("landmark/hy_haenggak", {"seed": 76, "length": 24.0}, 22.0, -18.0, cat="landmark", kind="haenggak", nocheck=True),
           P("reserve", {}, reserve=True, aabb=[-50, 50, -40, 30])]
    lm_put(pl, T, "gyeonghuigung_site", pcs, "경희궁 터", "ghg", R=30, rules={"max_drop": 5.0, "road_min": 0.5}, seed=74)
    pcs = [P("landmark/gaeksa", {"seed": 77, "name": "모화관", "jeongdang_bays": 5, "wing_bays": 3}, 0.0, -10.0, cat="civic",
             kind="gaeksa", label="모화관", footprint=[46.0, 14.0], nocheck=True),
           P("landmark/hy_palace_gate", {"seed": 78, "name": "영은문", "bays": [4.6], "stories": 1, "roof": "paljak", "H": 4.2}, 0.0, 14.0,
             cat="civic", kind="gate", label="영은문", nocheck=True)]
    lm_put(pl, T, "mohwagwan", pcs, "모화관", "mohwa", R=40, rules={"max_drop": 3.5, "road_min": 0.4}, seed=77)
    pcs = [P("landmark/dongheon", {"seed": 79, "bays": 5}, 0.0, -8.0, cat="civic", kind="shrine", label="동관왕묘", nocheck=True),
           P("landmark/samun", {"seed": 80, "kind": "outer", "name": "동묘"}, 0.0, 12.0, cat="civic", kind="samun", nocheck=True)]
    pcs += court_pcs(8000, -18.0, 18.0, -20.0, 12.0)
    lm_put(pl, T, "donggwanwangmyo", pcs, "동관왕묘", "dongmyo", R=30, rules={"max_drop": 3.0, "road_min": 0.5}, seed=79)
    pcs = []
    for k in range(4):
        pcs.append(P("village/heotgan", {"seed": 81 + k, "w": 12.0, "d": 6.0, "walls": "four"}, (k - 1.5) * 14.0, 0.0, cat="civic",
                     kind="binggo", label="서빙고" if k == 0 else None, nocheck=k > 0))
    lm_put(pl, T, "seobinggo", pcs, "서빙고", "binggo", R=40, rules={"max_drop": 3.5, "road_min": 0.5}, seed=81)
    pcs = [P("village/cairn", {"seed": 90 + k, "altar": k == 2}, (k - 2) * 4.2, 0.0, cat="landmark", kind="bongsu",
             label="목멱산 봉수대" if k == 2 else None, flatten=False, nocheck=k != 2) for k in range(5)]
    lm_put(pl, T, "mokmyeok_bongsu", pcs, "목멱산 봉수대", "bongsu", R=20, rules={"max_drop": 6.0, "road_min": -9}, seed=90)
    # ── 개천 다리: 광통교·수표교(원점 = 개천 바닥, 상판 +3m) ──
    for lid, kit, sd in [("gwangtonggyo", "landmark/hy_gwangtonggyo", 101), ("supyogyo", "landmark/hy_supyogyo", 102)]:
        l = NC.lmk(T, lid)
        Lb = Local(T, l["x"], l["z"], 60)
        nr = Lb.nearest_river(l["x"], l["z"])
        rdx, rdz = nr[3] if nr else (1.0, 0.0)
        cx_, cz_ = nr[4] if nr else (l["x"], l["z"])
        nx, nz = -rdz, rdx
        hA = T.height(cx_ + nx * 9, cz_ + nz * 9); hB = T.height(cx_ - nx * 9, cz_ - nz * 9)
        pl.commit([P(kit, {"seed": sd}, cat="bridge", kind="gaecheon_bridge", label={"gwangtonggyo": "광통교", "supyogyo": "수표교"}[lid],
                     flatten=False, nocheck=True, y=round(min(hA, hB) - 3.0, 2), id=f"hy_br_{lid}")], cx_, cz_, ry_cross(nx, nz),
                  "개천 다리", "gaecheon")
    # ── 운종가(종로): 종루 네거리 키트 + 동·서로 시전 행랑 줄 ──
    G1 = "운종가"
    jr = T.road("unjongga")["points"]
    sx = road_s(T, "unjongga", -291, -885)
    x0_, z0_, d0 = polyline_at(jr, sx)
    # 남쪽(카메라 쪽) 줄은 5m 물리고 간판을 끔 — 북쪽 간판 줄이 화면에 서고, 틈에는 좌판(§8)
    ry_j = ry_along(*d0)
    pl.commit([P("landmark/hy_unjongga", {"seed": 111, "length": 200.0, "south_off": 5.0, "south_signs": False}, cat="landmark",
                 kind="unjongga", label="운종가", flatten=True, footprint=[204.0, 40.0])], x0_, z0_, ry_j, G1, "jongno")
    for q in range(16):
        lx = (-1 if q % 2 else 1) * (13.0 + (q // 2) * 11.6)
        if abs(lx) > 96:
            continue
        pl.commit([P("village/jwapan", {"seed": sv(117 + q), "goods": ["silk", "cloth", "paper", "fish", "mixed"][q % 5]}, cat="market",
                     kind="jwapan", flatten=False, nocheck=True)], *l2w(x0_, z0_, ry_j, lx, 11.2), ry_j + math.pi, G1, "jongno")
    sajeon_row(pl, T, "unjongga", sx + 106, road_s(T, "unjongga", 610, -925), G1, "jongno", 120, setback=0.6, south_setback=6.0,
               south_signs=False, south_stalls=True)
    sajeon_row(pl, T, "unjongga", road_s(T, "unjongga", -520, -915), sx - 106 - 34, G1, "jongno", 140, bays=8, setback=0.6,
               south_setback=6.0, south_signs=False, south_stalls=True)
    # 배오개 장(이현): 종로 동쪽 끝 가가·좌판 + 둘레 장거리
    bst = NC.style(T, rid, "baeogae_jang")
    Lb = Local(T, 420, -880, 200)
    E.market(pl, T, Lb, "gwanghuimun_lane", road_s(T, "gwanghuimun_lane", 376, -900), road_s(T, "gwanghuimun_lane", 376, -900) + 70,
             "배오개 장", "baeogae", random.Random(131), shops=6, jwapan=14, goods=["onggi", "grain", "straw", "mixed", "cloth"])
    # ── 구역 채우기(길가 줄 → 구역 칸) ──
    cin = cells_in_poly(T, wall + [wall[0]], lu=(1, 2, 3, 6))
    pl.log.append(f"[hanyang] 도성 안 칸 {len(cin)}")
    road_sets = {
        "bukchon": ["bukchon_ro", "donhwamun_ro", "changuimun_road"],
        "seochon": ["sajik_lane", "seomun_ro", "changuimun_road"],
        "insa": ["bukchon_ro", "donhwamun_ro", "seonggyungwan_lane"],
        "pimat": [],
        "jungchon": ["gaecheon_lane", "gwanghuimun_lane"],
        "namchon": ["namchon_lane", "namdaemunro"],
        "dongchon": ["seonggyungwan_lane", "hyehwamun_out"],
        "namdaemun": ["namdaemunro", "mapo_road"],
        "gwanghui": ["gwanghuimun_lane", "hangangjin_road"],
    }
    # 시전 행랑을 운종가 밖 큰길에도: 남대문로(숭례문→종루), 돈화문로 남쪽 끝(종로 쪽) — 19세기 말 사진에 가게 줄이 보이는 길
    sajeon_row(pl, T, "namdaemunro", 30.0, polyline_len(T.road("namdaemunro")["points"]) - 40.0, "남대문로 시전", "ndm_sj", 160, bays=8,
               goods=["cloth", "mixed", "paper", "fish", "silk"], setback=0.8)
    dh = T.road("donhwamun_ro")["points"]
    sajeon_row(pl, T, "donhwamun_ro", polyline_len(dh) - 190.0, polyline_len(dh) - 24.0, "돈화문로 시전", "dhm_sj", 170, bays=6,
               goods=["paper", "silk", "mixed"], setback=0.8)
    # 구역마다: ① 큰길가 집 줄(큰 집) → ② 골목 격자(동서 21m 간격, 남북 72m) 북쪽에 도시 한옥을 골목에 바짝 → ③ 남은 틈 채우기
    # (도성 안 땅은 north_post가 마을 터로 칠함 — 예전처럼 큰길 70m 띠 밖을 채마밭으로 비워 두지 않는다)
    for k, (nm, code, rect, mix, sid, pitch, lim) in enumerate(HY_DISTRICTS):
        st = NC.style(T, rid, sid)
        c = cin[(cin[:, 0] >= rect[0]) & (cin[:, 0] <= rect[2]) & (cin[:, 1] >= rect[1]) & (cin[:, 1] <= rect[3])]
        lim = int(lim * 3.2)
        n = 0
        if road_sets.get(code):
            n += streets(pl, T, c, road_sets[code], nm, code, mix, 2000 + k * 50, st, limit=lim // 3, max_drop=3.0, setback=(0.6, 3.0))
        lanes = lane_grid(pl, T, c, rect, nm, pitch=21.0, ns_every=72.0, seed=2020 + k * 50)
        lmix = "hy_lane_namchon" if code == "namchon" else ("hy_lane_bukchon" if code == "bukchon" else "hy_lane")
        n += lane_rows(pl, T, c, lanes, nm, code, lmix, 2030 + k * 50, st, limit=lim - n)
        stp = (13.4, 17.5) if mix in ("hy_city", "hy_jongno", "hy_jungchon", "hy_bukchon") else (19.0, 19.0)
        n += grid_fill(pl, T, c, nm, code, mix, 2010 + k * 50, st, step=stp, limit=max(0, lim - n), max_drop=3.6,
                       fallback=("city", "hc_small", "cprops"), small_p=0.2)
        pl.log.append(f"[district] {nm}: {n}")
    for k, (wx, wz) in enumerate([(-250, -1320), (-120, -1080), (150, -1060), (-150, -800), (300, -760), (-80, -420), (540, -700),
                                  (-780, -1050), (480, -1200)]):
        NC.search(pl, [P("village/well", {"seed": 150 + k, "roof": k % 2 == 0}, cat="prop", kind="well", margin=1.0)], wx, wz, 40, "도성 우물",
                  "well", 150 + k, face="none")
    urban_rects(pl, T, wall, [d[2] for d in HY_DISTRICTS] + [(-640, -1205, -520, -935)],
                green_groups=("경복궁", "창덕궁", "종묘", "사직단", "경희궁 터", "성균관", "동관왕묘"))
    # ── 성 밖: 칠패 장 · 성저 길가 · 왕십리 · 나루·포구 ──
    cst = NC.style(T, rid, "chilpae_jang")
    Lc = Local(T, -760, -280, 200)
    E.market(pl, T, Lc, "samnam_daero", road_s(T, "samnam_daero", -660, -300), road_s(T, "samnam_daero", -660, -300) + 110, "칠패 장",
             "chilpae", random.Random(201), shops=6, jwapan=18, goods=["fish", "fish", "grain", "straw", "mixed", "onggi"])
    cc = EV.cells_of(T, NC.stl(T, "chilpae_jang"), reg["settlements"])
    streets(pl, T, cc, ["samnam_daero", "mapo_road"], "칠패 장", "chilpae", "hy_out", 205, cst, limit=30)
    out = [c for c in NC.rect_cells(T, -1400, -1300, 1300, 200, lu=(1, 3, 6))]
    out = np.array(out) if out else np.zeros((0, 2))
    out = out[~poly_contains_np(wall, out)] if len(out) else out
    for k, (rids, nm, code, lim) in enumerate([(["samnam_daero"], "청파 길가", "cheongpa", 40), (["seomun_ro"], "서대문 밖", "seomun", 40),
                                                (["dongdaemun_out"], "동대문 밖", "dongmun", 40), (["mapo_road"], "아현 길가", "ahyeon", 30)]):
        streets(pl, T, near_road_cells(T, out, rids, 36.0), rids, nm, code, "hy_out", 220 + k * 9, HY, limit=lim, max_drop=3.0)
    village(pl, T, rid, "wangsimni", "왕십리 채마밭", "wangsim", "nb_village", 240, limit=26)
    port_set(pl, T, "mapo", "마포 나루(삼개)", "mapo", 300, NC.style(T, rid, "mapo"), warehouses_n=9, boats_n=7)
    village(pl, T, rid, "mapo", "마포 나루(삼개)", "mapo", "nb_port", 310, limit=26)
    port_set(pl, T, "yongsan", "용산 포구", "yongsan", 320, NC.style(T, rid, "yongsan"), warehouses_n=7, boats_n=5)
    village(pl, T, rid, "yongsan", "용산 포구", "yongsan", "nb_port", 330, limit=22)
    nr_ = NC.stl(T, "noryangjin")
    naru_set(pl, T, -1420.0, 2060.0, -1500.0, 2190.0, "노량진 나루", "noryang", 340, n_boats=5, big=True)
    naru_set(pl, T, -1380.0, 1740.0, -1372.0, 1700.0, "노량진 나루(북안)", "noryangn", 345, n_boats=3)
    village(pl, T, rid, "noryangjin", "노량진 나루", "noryang", "nb_village", 350, limit=18)
    naru_set(pl, T, 950.0, 1520.0, 912.0, 1430.0, "한강진 나루", "hangang", 360, n_boats=4, big=True)
    village(pl, T, rid, "hangangjin", "한강진 나루", "hangang", "nb_village", 370, limit=16)
    village(pl, T, rid, "seobinggo_village", "서빙고 마을", "binggov", "nb_village", 380, limit=12)
    for sid, sd in [("auto_village_00", 401), ("auto_village_01", 402), ("auto_village_02", 403)]:
        village(pl, T, rid, sid, f"들마을({sid})", "av", "nb_village", sd, limit=8)
    for rid_, xz, nm in [("seomun_ro", (-1689, -1451), "무악재 아래"), ("samnam_south", (-1600, 2400), "삼남대로 과천 쪽"),
                         ("dongdaemun_out", (2144, -227), "살곶이 쪽"), ("hyehwamun_out", (951, -2058), "동소문 밖")]:
        jumak_on(pl, T, rid_, xz, 0, "길가 주막", "rd", 450 + len(nm), "주막(" + nm + ")")
    NC.seonghwang(pl, -1790.0, -1590.0, "무악재", "muak", 470)


BUILDERS = {"GG_HANYANG": build_hanyang, "HH_HWANGJU": build_hwangju, "PA_PYEONGYANG": build_pyeongyang, "HG_HAMHEUNG": build_hamheung}


# ================================================================ 실행
def run_region(rid, bounds, fp):
    ET.DATA = os.path.join(ROOT, "region_data", rid)
    for it_ in range(25):
        T = ET.Terrain()
        pl = NorthPlacer(T, bounds, fp)
        pl.prefix = PREFIX[rid]
        pl.stats_ = {}
        BUILDERS[rid](pl, T)
        if not pl.missing:
            break
        if it_ == 24:
            raise SystemExit("키트 크기 재기가 수렴하지 않음")
        res = E.measure(pl.missing)
        bad = [k for k, v in res.items() if v.get("error")]
        if bad:
            raise SystemExit(f"키트 없음: {bad[:5]}")
        bounds.update(res)
        json.dump(bounds, open(BOUNDS, "w", encoding="utf-8"), ensure_ascii=False, indent=0, sort_keys=True)
    return T, pl


TITLE_CATS = ("civic", "landmark", "jumak", "shrine", "bridge")

# 카메라 구역(§8, region.json camera_zones — 엔진이 맨 뒤에 붙여 이긴다): 도읍 큰길에서는 카메라를 조금 높이고 가파르게 해
# 길 북쪽 시전 간판 줄이 화면에 들고 남쪽(카메라 쪽) 줄이 플레이어를 덜 가린다. 도성 안 골목도 집이 더 들게 조금 높게.
CAM_ZONES = {
    "GG_HANYANG": [
        {"name": "도성 안", "minX": -900.0, "maxX": 860.0, "minZ": -1600.0, "maxZ": -140.0, "pitch": 45.0, "distance": 28.0, "aimZ": -2.5},
        {"name": "운종가 큰길", "minX": -600.0, "maxX": 800.0, "minZ": -965.0, "maxZ": -868.0, "pitch": 47.0, "distance": 32.0, "aimZ": -5.0},
        {"name": "육조거리", "minX": -640.0, "maxX": -520.0, "minZ": -1205.0, "maxZ": -935.0, "pitch": 47.0, "distance": 32.0, "aimZ": -3.0},
    ],
    "PA_PYEONGYANG": [
        {"name": "평양 내성", "minX": -210.0, "maxX": 332.0, "minZ": -300.0, "maxZ": 215.0, "pitch": 45.0, "distance": 28.0, "aimZ": -2.5},
    ],
    "HG_HAMHEUNG": [
        {"name": "함흥 성 안", "minX": -543.0, "maxX": -205.0, "minZ": -166.0, "maxZ": 279.0, "pitch": 45.0, "distance": 28.0, "aimZ": -2.5},
    ],
}


def write_camzones(rid):
    """CAM_ZONES를 region.json camera_zones에 넣는다(src "north" 것만 바꿈 — 다른 구역은 그대로)."""
    path = os.path.join(ROOT, "region_data", rid, "region.json")
    r = json.load(open(path, encoding="utf-8"))
    old = [z for z in r.get("camera_zones", []) if z.get("src") != "north"]
    new = old + [dict(z, src="north") for z in CAM_ZONES.get(rid, [])]
    if new == r.get("camera_zones", []) or (not new and "camera_zones" not in r):
        return
    r["camera_zones"] = new
    with open(path, "w", encoding="utf-8") as f:
        json.dump(r, f, ensure_ascii=False, indent=1)


def write(rid, T, pl, bounds):
    items = []
    for it in pl.items:
        b = bounds.get(it["_bkey"], {})
        it["_tris"] = b.get("tris", 0)
        o = {k: v for k, v in it.items() if not k.startswith("_")}
        if rid == "GG_HANYANG" and it["kit"] in ("village/yard_props", "village/props", "village/haystack", "village/didil_bang_a"):
            o["yard"] = False     # 도성 안 소품은 제 마당 흙을 칠하지 않음(불러오기 시간 — 둘레 집 마당이 이미 칠함)
        if it.get("_label") and (it["_cat"] in TITLE_CATS or it["kit"] in ("village/well",)) and it["_label"] not in ("나루",):
            o["title"] = it["_label"]
        items.append(o)
    import station_reserve  # 역참 마방 자리 비워 두기(tools/region/make_stations.py)
    items = station_reserve.keep_clear(rid, items)
    doc = {"area": "north",
           "note": f"북쪽 대표 도시 배치(tools/placement/north.py {rid}, 결정적). 문화권 가옥형 kit/culture/. 성벽 선은 엔진. "
                   "근거·가설: docs/reports/placement-north.md",
           "items": items,
           "alleys": [dict(id=f"{pl.prefix}_alley_{i:03d}", **a) for i, a in enumerate(pl.alleys)]}
    if pl.urban:
        doc["urban"] = pl.urban
    out = os.path.join(ROOT, "region_data", rid, OUTNAME)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    return doc, out


def write_profiles(rid):
    path = os.path.join(ROOT, "region_data", rid, "region.json")
    r = json.load(open(path, encoding="utf-8"))
    for s in r["settlements"]:
        p = NP.profile_for(rid, s)
        p.pop("houses", None)
        s["profile"] = p
        t = NP.TITLES[rid].get(s["id"])
        if t:
            s["title"] = t
    r["culture_key"] = NP.CULTURE[rid]
    with open(path, "w", encoding="utf-8") as f:
        json.dump(r, f, ensure_ascii=False, indent=1)


VIEWS = {
    "GG_HANYANG": {"city": (-150, -1000, 760, 0.7), "jongno": (-150, -900, 260, 1.8), "palace": (-500, -1250, 230, 1.8),
                   "mapo": (-2000, 900, 200, 1.8), "noryang": (-1450, 2000, 260, 1.4)},
    "HH_HWANGJU": {"town": (31, -900, 220, 2.0), "dohwa": (-380, -360, 120, 2.5)},
    "PA_PYEONGYANG": {"city": (40, 0, 330, 1.4), "moran": (280, -560, 90, 3.0), "naru": (230, 110, 110, 2.5)},
    "HG_HAMHEUNG": {"city": (-420, 150, 260, 1.6), "bongung": (640, 1420, 120, 2.5)},
}

if __name__ == "__main__":
    bounds = {}
    for f in (os.path.join(HERE, "hubs_bounds.json"), E.BOUNDS, BOUNDS):
        if os.path.exists(f):
            try:
                bounds.update(json.load(open(f, encoding="utf-8")))
            except Exception:
                pass
    fp = NC.load_catalog_fp()
    for rid in RIDS:
        if "--profiles" in sys.argv:
            write_profiles(rid)
            print("profiles →", rid)
            continue
        T, pl = run_region(rid, bounds, fp)
        doc, out = write(rid, T, pl, bounds)
        write_camzones(rid)
        print(f"== {rid}: items {len(doc['items'])} → {out}")
        for l in pl.log:
            print("  ", l)
        bad = E.verify(pl)
        print("  overlaps:", len(bad), bad[:12])
        print("  tris total", sum(it["_tris"] for it in pl.items))
        cb = NC.count_buildings(pl)
        print("  buildings total", sum(cb.values()), "by group:", dict(cb.most_common()))
        print("  stats:", pl.stats_)
        if "--noplan" not in sys.argv:
            from east_plan import render
            for nm, (x, z, h, ppm) in VIEWS[rid].items():
                render(T, pl.items, bounds, nm, x, z, h, ppm, out=os.path.join(ROOT, "shots", "placement", f"north_{PREFIX[rid]}_{nm}.png"))
