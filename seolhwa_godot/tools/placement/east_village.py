"""placement-east 3단계: 마을 터(landuse 6)를 줄(고샅) 단위로 촘촘히 채운다.

마을 터 칸(4m)을 그 마을 bbox 안에서 모으고, 경사의 등고선 방향(동서 ±30°)으로 줄을 긋는다.
줄마다 집 한 터(울+초가+장독+마당 소품+텃밭 / 집 묶음 / 텃밭·짚가리 덩이)를 이어 놓는다.
줄 간격 = 집터 깊이 + 고샅(약 4.5m). 집터는 모두 정면 +z(남, 카메라 쪽).
"""
import math
import random

import numpy as np

from east_place import Rect, l2w, clamp_ry, wrap_half

P = None  # east.P 를 주입받는다


def setP(fn):
    global P
    P = fn


YARD_PROPS = ["work", "manure_coop", "woodpile", "jars"]
WALLS = ["stone_lite", "todam_thatch", "fence_lite", "stone_lite", "todam_thatch"]


def yard_set(seed, rich=True):
    """초가 한 터: 원점 = 마당(울) 가운데, 정면 +z. 울 14.4×12.5m."""
    r = random.Random(seed * 7919 + 17)
    hx, z0, z1 = 7.2, -6.0, 6.5
    kind = WALLS[seed % len(WALLS)]
    gate = r.uniform(-2.5, 2.5)
    pts = [[round(gate - 1.6, 2), z1], [-hx, z1], [-hx, z0], [hx, z0], [hx, z1], [round(gate + 1.6, 2), z1]]
    cx = r.choice([-1.2, 0.0, 1.0])
    cp = {"seed": seed}
    if r.random() < 0.35:
        cp["w"] = 5.4
    if r.random() < 0.3:
        cp["gourd"] = True
    fp = [round(2 * hx + 0.8, 1), round(z1 - z0 + 0.8, 1)]
    pcs = [
        # 울(겹침 검사·터 고르기를 대표): 마당 전체 사각형
        P("village/wall_run", {"seed": seed, "kind": kind, "points": pts}, 0.0, 0.0, cat="wall", kind="wall_run",
          aabb=[-hx - 0.4, hx + 0.4, z0 - 0.4, z1 + 0.4], flatten=False, margin=0.6),
        P("village/choga", cp, cx, -2.3, cat="house", kind="choga", inner=True, footprint=fp, flatten=True,
          fp_center=True),
        P("village/jangdok", {"seed": seed, "w": 2.4, "d": 2.0, "n": [2, 2, 1]}, 5.0, -4.4, cat="prop", inner=True, flatten=False),
    ]
    if rich:
        pcs.append(P("village/yard_props", {"seed": seed, "set": YARD_PROPS[seed % 4]}, -4.3, 3.5, cat="prop", inner=True, flatten=False))
        if r.random() < 0.6:
            pcs.append(P("village/teotbat", {"seed": seed, "gourd": r.random() < 0.6}, 4.4, 3.6, cat="prop", inner=True,
                         flatten=False))
        else:
            pcs.append(P("village/haystack", {"seed": seed}, 4.8, 3.4, cat="prop", inner=True, flatten=False))
    return pcs


def compound_set(seed, size):
    fp = {"small": [14.8, 14.0], "medium": [20.0, 16.8], "large": [24.8, 21.8]}[size]
    return [P("village/house_compound", {"seed": seed, "size": size}, cat="house", kind="house_" + size, footprint=fp, margin=0.8)]


def garden_set(seed):
    """마을 안 빈 터: 텃밭(nature/garden_plot) + 호박 넝쿨 + 짚가리."""
    r = random.Random(seed * 31 + 5)
    w = r.choice([5.0, 6.0, 7.0])
    pcs = [P("nature/garden_plot", {"seed": seed, "w": w, "d": 4.0}, 0.0, 0.0, cat="prop", kind="garden", flatten=False,
             aabb=[-w / 2 - 0.2, w / 2 + 0.2, -2.2, 2.2], margin=0.5),
           P("nature/pumpkin_vine", {"seed": seed}, -w / 2 + 1.0, 2.9, cat="prop", kind="pumpkin", inner=True, flatten=False)]
    if r.random() < 0.6:
        pcs.append(P("village/haystack", {"seed": seed}, w / 2 + 1.6, 0.4, cat="prop", kind="haystack", flatten=False,
                     margin=0.3))
    return pcs


def props_set(seed):
    r = random.Random(seed * 13 + 1)
    pcs = [P("village/yard_props", {"seed": seed, "set": YARD_PROPS[(seed + 1) % 4]}, 0.0, 0.0, cat="prop", kind="yard_props",
             flatten=False, margin=0.4)]
    pcs.append(P("village/didil_bang_a" if r.random() < 0.4 else "village/haystack", {"seed": seed}, 5.8, -0.5, cat="prop",
                 flatten=False, margin=0.4))
    return pcs


MIX = {
    "fringe": [("garden", 0.45), ("props", 0.25), ("yard", 0.20), ("hc_small", 0.10)],
    "eup": [("yard", 0.42), ("hc_small", 0.14), ("hc_medium", 0.16), ("hc_large", 0.10), ("garden", 0.12), ("props", 0.06)],
    "village": [("yard", 0.55), ("hc_small", 0.14), ("hc_medium", 0.08), ("garden", 0.15), ("props", 0.08)],
    "market": [("jw", 0.72), ("shop", 0.22), ("props", 0.06)],
    "mountain": [("yard", 0.66), ("hc_small", 0.08), ("garden", 0.16), ("props", 0.10)],
}


def pick(mix, h):
    t = 0.0
    for k, w in mix:
        t += w
        if h < t:
            return k
    return mix[-1][0]


GOODS = ["onggi", "cloth", "grain", "straw", "fish", "mixed"]


def jw_set(seed):
    """좌판 둘(나란히). 셋째마다 차일 없음."""
    out = []
    for i, lx in enumerate((-1.7, 1.7)):
        p = {"seed": seed * 2 + i, "goods": GOODS[(seed + i) % 6]}
        if (seed + i) % 3 == 2:
            p["awning"] = False
        out.append(P("village/jwapan", p, lx, 0.0, cat="market", kind="jwapan", flatten=False, margin=0.6))
    return out


def shop_set(seed):
    p = {"seed": seed, "goods": GOODS[seed % 6]}
    return [P("village/market_shop", p, cat="market", kind="shop", margin=0.6)]


def make_slot(kind, seed):
    if kind == "jw":
        return jw_set(seed)
    if kind == "shop":
        return shop_set(seed)
    if kind == "yard":
        return yard_set(seed)
    if kind.startswith("hc_"):
        return compound_set(seed, kind[3:])
    if kind == "garden":
        return garden_set(seed)
    return props_set(seed)


def slot_width(pl, pcs):
    """줄 방향 폭(로컬 x)과 깊이."""
    xs, zs = [], []
    for kit, params, lx, lz, lry, fl in pcs:
        if fl.get("inner"):
            continue
        a = pl.aabb(kit, params, fl)
        xs += [lx + a[0], lx + a[1]]
        zs += [lz + a[2], lz + a[3]]
    return max(xs) - min(xs), min(xs), max(zs) - min(zs)


def cells_of(T, s, others, extra_ids=()):
    """settlement s의 마을 터 칸(월드 좌표). 이웃 마을 bbox가 겹치면 더 가까운 중심 쪽에 준다."""
    lm = T.lm
    b = s["bbox"]
    i0 = int((b[0] - lm["x0"]) / lm["cell"]); i1 = int((b[2] - lm["x0"]) / lm["cell"]) + 1
    j0 = int((b[1] - lm["z0"]) / lm["cell"]); j1 = int((b[3] - lm["z0"]) / lm["cell"]) + 1
    sub = T.L[j0:j1, i0:i1]
    jj, ii = np.nonzero(sub == 6)
    xs = lm["x0"] + (ii + i0) * lm["cell"]
    zs = lm["z0"] + (jj + j0) * lm["cell"]
    keep = np.ones(len(xs), bool)
    d0 = (xs - s["x"]) ** 2 + (zs - s["z"]) ** 2
    for o in others:
        if o["id"] == s["id"] or o["id"] in extra_ids or not o.get("bbox"):
            continue
        ob = o["bbox"]
        inside = (xs >= ob[0]) & (xs <= ob[2]) & (zs >= ob[1]) & (zs <= ob[3])
        d1 = (xs - o["x"]) ** 2 + (zs - o["z"]) ** 2
        keep &= ~(inside & (d1 < d0))
    return np.stack([xs[keep], zs[keep]], 1)


def contour_ry(T, cells):
    """마을 터 평균 경사의 등고선 방향 → 줄 방향 ry(±30°)."""
    if len(cells) == 0:
        return 0.0
    gx = gz = 0.0
    for x, z in cells[:: max(1, len(cells) // 200)]:
        gx += T.height(x + 4, z) - T.height(x - 4, z)
        gz += T.height(x, z + 4) - T.height(x, z - 4)
    if abs(gx) + abs(gz) < 1e-3:
        return 0.0
    ux, uz = -gz, gx          # 등고선 방향
    return clamp_ry(wrap_half(math.atan2(-uz, ux)))


def fill_rows(pl, T, L, cells, group, gcode, mix_name, seed, pitch=18.0, gap=(1.6, 3.2), max_drop=2.6,
              skip=0.06, limit=999, ry=None, in_frac=0.55, stats=None, phase=0.0, lu_ok=(6,), alleys=True):
    """마을 터 칸을 줄로 채운다. 반환: 놓은 집터 수."""
    if len(cells) == 0:
        return 0
    rng = random.Random(seed)
    mix = MIX[mix_name]
    ry = contour_ry(T, cells) if ry is None else ry
    c, s = math.cos(ry), math.sin(ry)
    ux, uz = c, -s          # 줄 방향(로컬 x)
    vx, vz = s, c           # 앞(로컬 +z, 남쪽)
    cx, cz = cells[:, 0].mean(), cells[:, 1].mean()
    a = (cells[:, 0] - cx) * ux + (cells[:, 1] - cz) * uz
    b = (cells[:, 0] - cx) * vx + (cells[:, 1] - cz) * vz
    cellset = set((int(round(x)), int(round(z))) for x, z in cells)
    lm = T.lm

    def in_mask(x, z):
        i = int(round((x - lm["x0"]) / lm["cell"])); j = int(round((z - lm["z0"]) / lm["cell"]))
        return T.L[j, i] in lu_ok

    placed = 0
    b0 = b.min() + rng.uniform(4, 9) + phase
    row = 0
    while b0 < b.max() + 2 and placed < limit:
        sel = np.abs(b - b0) < 4.0
        if sel.sum() == 0:
            b0 += pitch
            row += 1
            continue
        amin, amax = a[sel].min() - 2, a[sel].max() + 2
        cur = amin + rng.uniform(0, 3)
        k = 0
        row_hits = []   # (a0, a1, 앞 끝 b)
        while cur < amax and placed < limit:
            h = random.Random(seed * 1000 + row * 97 + k).random()
            k += 1
            if h < skip:
                cur += 4.0
                continue
            kind = pick(mix, random.Random(seed * 7 + row * 131 + k * 17).random())
            sseed = seed * 100 + row * 37 + k
            pcs = make_slot(kind, sseed)
            w, xmin, d = slot_width(pl, pcs)
            ok = False
            # 줄에서 앞뒤로 조금 흔들어 맞는 자리 찾기
            for db in (0.0, -2.0, 2.0, -4.0, 4.0):
                xa = cur - xmin + rng.uniform(-0.6, 0.6)
                x = cx + ux * xa + vx * (b0 + db)
                z = cz + uz * xa + vz * (b0 + db)
                rr = ry + rng.uniform(-0.06, 0.06)
                # 마을 터 안이어야: 사각형 표본 중 in_frac 이상이 landuse 6
                big = Rect(x, z, rr, [xmin, xmin + w, -d / 2, d / 2])
                smp = big.samples(3.0)
                frac = sum(1 for p in smp if in_mask(*p)) / len(smp)
                if frac < in_frac:
                    continue
                res = pl.check(L, pcs, x, z, rr, {"max_drop": max_drop, "road_min": 0.8})
                if res[0]:
                    pl.commit(pcs, x, z, rr, group, gcode)
                    row_hits.append((cur, cur + w, b0 + db + d / 2))
                    placed += 1
                    if stats is not None:
                        stats[kind] = stats.get(kind, 0) + 1
                    ok = True
                    break
            cur += (w + rng.uniform(*gap)) if ok else 3.0
        if alleys and len(row_hits) >= 2:
            # 고샅: 이 줄 집터들 앞(남쪽) 2.2m — 끊긴 데(12m 넘는 틈)에서 나눈다
            segs = [[row_hits[0]]]
            for h in row_hits[1:]:
                if h[0] - segs[-1][-1][1] > 12.0:
                    segs.append([h])
                else:
                    segs[-1].append(h)
            for sg in segs:
                if len(sg) < 2:
                    continue
                bl = max(h[2] for h in sg) + 2.2
                pts = []
                for aa in (sg[0][0], sg[-1][1]):
                    pts.append([round(cx + ux * aa + vx * bl, 2), round(cz + uz * aa + vz * bl, 2)])
                pl.alleys.append({"group": group, "width_m": 3.0, "points": pts})
        b0 += pitch + rng.uniform(-1.0, 1.0)
        row += 1
    return placed
