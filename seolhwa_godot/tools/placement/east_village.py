"""placement-east 3단계: 마을 터(landuse 6)를 줄(고샅) 단위로 촘촘히 채운다.

마을 터 칸(4m)을 그 마을 bbox 안에서 모으고, 경사의 등고선 방향(동서 ±30°)으로 줄을 긋는다.
줄마다 집 한 터(울+초가+장독+마당 소품+텃밭 / 집 묶음 / 텃밭·짚가리 덩이)를 이어 놓는다.
줄 간격 = 집터 깊이 + 고샅(약 4.5m). 집터는 모두 정면 +z(남, 카메라 쪽).
"""
import math
import random

import numpy as np

from east_place import Rect, l2w, clamp_ry, wrap_half, ry_along
import town_profile as PR

P = None  # east.P 를 주입받는다
import collections
FAIL = collections.Counter()   # 디버그: (종류, 실패 까닭)


def setP(fn):
    global P
    P = fn


YARD_PROPS = ["work", "manure_coop", "woodpile", "jars"]
WALLS = ["stone_lite", "todam_thatch", "fence_lite", "stone_lite", "todam_thatch"]


def house_piece(style, seed, roof, cx, cz, fp, r):
    """초가 터의 안채 한 채: 고을 지붕 재료(roof)·가옥형(plan)."""
    plan = style.plan if style else ""
    if roof == "choga" or not style:
        cp = {"seed": seed}
        if r.random() < 0.35:
            cp["w"] = 5.4
        if r.random() < 0.3:
            cp["gourd"] = True
        if plan:
            cp["plan"] = plan
        return P("village/choga", cp, cx, cz, cat="house", kind="choga", inner=True, footprint=fp, flatten=True, fp_center=True)
    cp = {"seed": seed}
    if plan and roof in ("neowa", "gulpi", "choga_low"):
        cp["plan"] = plan
    return P(PR.ROOF_KIT[roof], cp, cx, cz, cat="house", kind=roof, inner=True, footprint=fp, flatten=True, fp_center=True)


def yard_set(seed, rich=True, style=None, roof=None):
    """초가 한 터: 원점 = 마당(울) 가운데, 정면 +z. 울 14.4×12.5m(산촌 돌축대 터는 12.4×10.2m).
    style(profile.Style)이 있으면 지붕 재료·담 재료·가옥형을 고을 성격표에서."""
    r = random.Random(seed * 7919 + 17)
    terrace = bool(style and style.wall == "stone_terrace")
    if terrace:
        hx, z0, z1, hz = 5.6, -4.6, 4.4, -1.4
    elif style and style.layout in ("linear_street", "along_temple_road"):
        hx, z0, z1, hz = 6.4, -5.2, 5.2, -1.9      # 길가 띠(폭 ~16m)에 맞춘 좁은 터
    else:
        hx, z0, z1, hz = 7.2, -6.0, 6.5, -2.3
    if style:
        kind = style.wall_run
    else:
        kind = WALLS[seed % len(WALLS)]
    gate = r.uniform(-2.5, 2.5) if not terrace else r.uniform(-1.5, 1.5)
    cx = r.choice([-1.2, 0.0, 1.0])
    fp = [round(2 * hx + 0.8, 1), round(z1 - z0 + 0.8, 1)]
    rect = [-hx - 0.4, hx + 0.4, z0 - 0.4, z1 + 0.4]
    pcs = []
    if kind is None:
        # 담 없음(고개 마을): 자리만 잡는다
        pcs.append(P("reserve", {}, 0.0, 0.0, reserve=True, cat="wall", aabb=rect, margin=0.6))
    elif terrace:
        # 옆·뒤 돌담 + 앞(남) 돌축대 두 토막(가운데 드나드는 틈). 축대 높이는 놓은 뒤 땅에 맞춘다(fit_terrace)
        pts = [[-hx, round(z1 - 0.3, 2)], [-hx, z0], [hx, z0], [hx, round(z1 - 0.3, 2)]]
        pcs.append(P("village/wall_run", {"seed": seed, "kind": kind, "points": pts}, 0.0, 0.0, cat="wall", kind="wall_run",
                     aabb=rect, flatten=False, margin=0.6))
        for k, (a, b) in enumerate(((-hx, gate - 1.1), (gate + 1.1, hx))):
            pcs.append(P("village/stone_terrace", {"seed": seed * 2 + k, "ax": round(a, 2), "az": 0.0, "bx": round(b, 2), "bz": 0.0,
                                                  "drop": 1.2, "tiers": 1, "wall_h": 0.9},
                         0.0, z1, cat="wall", kind="stone_terrace", inner=True, flatten=False, terrace=True))
    else:
        pts = [[round(gate - 1.6, 2), z1], [-hx, z1], [-hx, z0], [hx, z0], [hx, z1], [round(gate + 1.6, 2), z1]]
        pcs.append(P("village/wall_run", {"seed": seed, "kind": kind, "points": pts}, 0.0, 0.0, cat="wall", kind="wall_run",
                     aabb=rect, flatten=False, margin=0.6))
    roof = roof or (style.pick_roof(seed) if style else "choga")
    pcs.append(house_piece(style, seed, roof, cx, hz, fp, r))
    pcs.append(P("village/jangdok", {"seed": seed, "w": 2.4, "d": 2.0, "n": [2, 2, 1]}, hx - 2.2, z0 + 1.6, cat="prop", inner=True,
                 flatten=False))
    if rich:
        fz = 2.6 if terrace else 3.5
        pcs.append(P("village/yard_props", {"seed": seed, "set": YARD_PROPS[seed % 4]}, -hx + 2.9, fz, cat="prop", inner=True,
                     flatten=False))
        if r.random() < 0.6 and not terrace:
            pcs.append(P("village/teotbat", {"seed": seed, "gourd": r.random() < 0.6}, hx - 2.8, z1 - 2.9, cat="prop", inner=True,
                         flatten=False))
        else:
            pcs.append(P("village/haystack", {"seed": seed}, hx - 2.4, fz - 0.2, cat="prop", inner=True, flatten=False))
    return pcs


def compound_set(seed, size, style=None, roof=None):
    fp = {"small": [14.8, 14.0], "medium": [20.0, 16.8], "large": [24.8, 21.8]}[size]
    p = {"seed": seed, "size": size}
    if style:
        roof = roof or ("giwa" if size == "large" else style.pick_roof(seed, 1))
        if roof != ("giwa" if size == "large" else "choga"):
            p["roof"] = roof
        if size != "large":
            p["wall"] = style.wall       # 관속 큰 기와집(large)은 기와 갓 토담 그대로
        if style.plan:
            p["plan"] = style.plan
    return [P("village/house_compound", p, cat="house", kind="house_" + size, footprint=fp, margin=0.8)]


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
    "gwan": [("hc_large", 0.35), ("hc_medium", 0.40), ("garden", 0.15), ("props", 0.10)],
    "fringe": [("garden", 0.45), ("props", 0.25), ("yard", 0.20), ("hc_small", 0.10)],
    "eup": [("yard", 0.42), ("hc_small", 0.14), ("hc_medium", 0.16), ("hc_large", 0.10), ("garden", 0.12), ("props", 0.06)],
    "village": [("yard", 0.55), ("hc_small", 0.14), ("hc_medium", 0.08), ("garden", 0.15), ("props", 0.08)],
    "market": [("jw", 0.72), ("shop", 0.22), ("props", 0.06)],
    "street": [("yard", 0.68), ("hc_small", 0.12), ("hc_medium", 0.06), ("garden", 0.08), ("props", 0.06)],
    "terrace": [("yard", 0.86), ("hc_small", 0.04), ("props", 0.10)],
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


def make_slot(kind, seed, style=None):
    if kind == "jw":
        return jw_set(seed)
    if kind == "shop":
        return shop_set(seed)
    if kind == "yard":
        if style and style.pick_roof(seed) == "giwa":
            # 기와 안채는 초가 터(울 14m)에 안 들어가 작은 묶음(기와)으로
            return compound_set(seed, "medium", style, roof="giwa")
        return yard_set(seed, style=style)
    if kind.startswith("hc_"):
        return compound_set(seed, kind[3:], style)
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
              skip=0.06, limit=999, ry=None, in_frac=0.55, stats=None, phase=0.0, lu_ok=(6,), alleys=True, zone=None,
              style=None, single=False):
    """zone = (x, z, R, mix_name): 그 둘레 R 안의 줄 자리는 다른 섞음(예: 관아 앞 기와집)."""
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
    if single:
        # 계단식: 한 단(이 칸 무리)에 한 줄 — 무리 가운데 높이선
        b0 = float(np.median(b))
    row = 0
    while b0 < b.max() + 2 and placed < limit and not (single and row > 0):
        sel = np.abs(b - b0) < 4.0
        if sel.sum() == 0:
            b0 += pitch
            row += 1
            continue
        amin, amax = a[sel].min() - 2, a[sel].max() + 2
        cur = amin + rng.uniform(0, 3)
        k = 0
        hold = None
        row_hits = []   # (a0, a1, 앞 끝 b)
        while cur < amax and placed < limit:
            h = random.Random(seed * 1000 + row * 97 + k).random()
            k += 1
            if h < skip:
                cur += 4.0
                continue
            mx = mix
            if zone:
                px_ = cx + ux * cur + vx * b0
                pz_ = cz + uz * cur + vz * b0
                if (px_ - zone[0]) ** 2 + (pz_ - zone[1]) ** 2 < zone[2] ** 2:
                    mx = MIX[zone[3]]
            kind = pick(mx, random.Random(seed * 7 + row * 131 + k * 17).random())
            if hold and hold[1] > 0 and kind not in ("yard", "hc_small", "hc_medium", "hc_large"):
                kind = hold[0]
            sseed = seed * 100 + row * 37 + k
            pcs = make_slot(kind, sseed, style)
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
                    FAIL[(kind, "mask")] += 1
                    continue
                res = pl.check(L, pcs, x, z, rr, {"max_drop": max_drop, "road_min": 0.8})
                if not res[0]:
                    FAIL[(kind, res[2])] += 1
                if res[0]:
                    pl.commit(fit_terrace(T, pcs, x, z, rr), x, z, rr, group, gcode)
                    row_hits.append((cur, cur + w, b0 + db + d / 2))
                    placed += 1
                    if stats is not None:
                        stats[kind] = stats.get(kind, 0) + 1
                    ok = True
                    break
            if ok:
                hold = None
            elif single and kind in ("yard", "hc_small"):
                hold = (kind, (hold[1] - 1) if hold and hold[0] == kind else 4)
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


# ---------------------------------------------------------------- 고을 짜임(A2)
def fit_terrace(T, pcs, x, z, ry):
    """돌축대 토막의 높이(drop)를 땅에 맞춘다: 터(고른 땅, 평균 높이) − 축대 앞 3m 땅. 0.4m 단위, 0.8~2.8m."""
    if not any(fl.get("terrace") for *_, fl in pcs):
        return pcs
    ys = []
    for kit, params, lx, lz, lry, fl in pcs:
        if fl.get("footprint") and fl.get("fp_center"):
            w, d = fl["footprint"]
            for i in range(5):
                for j in range(5):
                    ys.append(T.height(*l2w(x, z, ry, (i / 4 - 0.5) * w, (j / 4 - 0.5) * d)))
    if not ys:
        return pcs
    yard = float(np.mean(ys))
    out = []
    for kit, params, lx, lz, lry, fl in pcs:
        if fl.get("terrace"):
            mx = (params["ax"] + params["bx"]) / 2
            front = np.mean([T.height(*l2w(x, z, ry, mx + dx, lz + 3.0)) for dx in (-1.5, 0.0, 1.5)])
            drop = min(2.8, max(0.8, round((yard - front) / 0.4) * 0.4))
            params = dict(params, drop=round(drop, 1), tiers=1 if drop < 1.5 else 2)
        out.append((kit, params, lx, lz, lry, fl))
    return out


def slot_box(pl, pcs):
    """로컬 x 범위(xmin, w)와 z 범위(zmin, zmax)."""
    xs, zs = [], []
    for kit, params, lx, lz, lry, fl in pcs:
        if fl.get("inner"):
            continue
        a = pl.aabb(kit, params, fl)
        xs += [lx + a[0], lx + a[1]]
        zs += [lz + a[2], lz + a[3]]
    return min(xs), max(xs) - min(xs), min(zs), max(zs)


def _mask_frac(T, x, z, ry, box, lu_ok=(6,)):
    big = Rect(x, z, ry, box)
    smp = big.samples(3.0)
    lm = T.lm
    n = 0
    for px, pz in smp:
        i = int(round((px - lm["x0"]) / lm["cell"])); j = int(round((pz - lm["z0"]) / lm["cell"]))
        if 0 <= j < T.L.shape[0] and 0 <= i < T.L.shape[1] and T.L[j, i] in lu_ok:
            n += 1
    return n / len(smp)


def walk_line(pl, T, L, line, length, anchor, group, gcode, mix_name, seed, style, stats=None, gap=(1.4, 3.0),
              max_drop=2.6, in_frac=0.45, limit=999, skip=0.05, zone=None, off=0.0, lu_ok=(6,)):
    """곡선 하나(line(t) → x, z, ux, uz)를 따라 집터를 잇는다.
    anchor: "center"(줄 가운데가 선 위) | "front"(앞 끝이 선 뒤 off m — 길 북쪽 집) | "back"(뒤 끝이 선 앞 off m — 길 남쪽 집)."""
    rng = random.Random(seed)
    placed, t, k = 0, rng.uniform(0, 4), 0
    hold = None
    while t < length and placed < limit:
        k += 1
        h = random.Random(seed * 1000 + k).random()
        if h < skip:
            t += 4.0
            continue
        px0, pz0, _, _ = line(min(length, t))
        mx = MIX[mix_name]
        if zone and (px0 - zone[0]) ** 2 + (pz0 - zone[1]) ** 2 < zone[2] ** 2:
            mx = MIX[zone[3]]
        kind = pick(mx, random.Random(seed * 7 + k * 17).random())
        if hold and hold[1] > 0 and kind not in ("yard", "hc_small", "hc_medium", "hc_large"):
            kind = hold[0]      # 집터가 안 맞았으면 몇 걸음 더 같은 집터로(빈 데를 텃밭이 먼저 차지하지 않게)
        pcs = make_slot(kind, seed * 100 + k, style)
        xmin, w, zmin, zmax = slot_box(pl, pcs)
        ok = False
        hw_, hd_ = w / 2, (zmax - zmin) / 2
        xc, zc = xmin + hw_, (zmin + zmax) / 2
        ext_t = hw_
        for dv in (0.0, -1.0, 1.5, 3.0):
            px, pz, ux, uz = line(min(length, t + ext_t))
            rr = clamp_ry(ry_along(ux, uz)) + rng.uniform(-0.04, 0.04)
            c_, s_ = math.cos(rr), math.sin(rr)
            u = (c_, -s_); v = (s_, c_)
            ext_t = abs(ux * u[0] + uz * u[1]) * hw_ + abs(ux * v[0] + uz * v[1]) * hd_
            if anchor == "center":
                cxw, czw = px + v[0] * (dv if k % 2 else -dv), pz + v[1] * (dv if k % 2 else -dv)
            else:
                # 길 법선(남쪽, 남북길이면 동쪽)으로 side만큼: front = 길 북(서)쪽, back = 길 남(동)쪽
                nx, nz = -uz, ux
                if (nz < 0 and abs(nz) >= 0.3) or (abs(nz) < 0.3 and nx < 0):
                    nx, nz = -nx, -nz
                sd = -1.0 if anchor == "front" else 1.0
                ext_n = abs(nx * u[0] + nz * u[1]) * hw_ + abs(nx * v[0] + nz * v[1]) * hd_
                dn = off + dv + ext_n
                cxw, czw = px + sd * nx * dn, pz + sd * nz * dn
            x = cxw - (u[0] * xc + v[0] * zc)
            z = czw - (u[1] * xc + v[1] * zc)
            if _mask_frac(T, x, z, rr, [xmin, xmin + w, zmin, zmax], lu_ok) < in_frac:
                FAIL[(kind, "mask")] += 1
                continue
            res = pl.check(L, pcs, x, z, rr, {"max_drop": max_drop, "road_min": 0.8})
            if not res[0]:
                FAIL[(kind, res[2])] += 1
            if res[0]:
                pl.commit(fit_terrace(T, pcs, x, z, rr), x, z, rr, group, gcode)
                placed += 1
                if stats is not None:
                    stats[kind] = stats.get(kind, 0) + 1
                ok = True
                break
        if ok:
            hold = None
        elif kind in ("yard", "hc_small", "hc_medium", "hc_large"):
            hold = (kind, (hold[1] - 1) if hold and hold[0] == kind else 4)
        t += (2 * ext_t + rng.uniform(*gap)) if ok else 3.0
    return placed


def street_rows(pl, T, L, cells, road_pts, road_w, group, gcode, mix_name, seed, style, stats=None, sides=(-1, 1),
                setback=(1.4, 4.2), max_drop=2.6, limit=999, in_frac=0.3):
    """길촌(linear_street): 마을 터 띠를 지나는 길 양쪽에 집을 길과 나란히 늘어놓는다.
    길 북쪽 집은 앞(대문·마루)이 길을 보고, 남쪽 집은 고정 카메라(남쪽) 때문에 등을 길에 대되 조금 더 물린다."""
    from east_terrain import polyline_at, polyline_len
    if len(cells) == 0:
        return 0
    Ltot = polyline_len(road_pts)
    # 마을 터 칸에서 30m 안을 지나는 길 구간만
    ss = np.arange(0.0, Ltot, 2.0)
    P_ = np.array([polyline_at(road_pts, s)[:2] for s in ss])
    near = np.array([np.min(np.abs(cells[:, 0] - x) + np.abs(cells[:, 1] - z)) < 30.0 for x, z in P_])
    if not near.any():
        return 0
    s0, s1 = float(ss[near].min()), float(ss[near].max())

    def line(t):
        s = s0 + t
        xa, za, _ = polyline_at(road_pts, max(0.0, s - 8.0))
        xb, zb, _ = polyline_at(road_pts, min(Ltot, s + 8.0))
        x, z, _ = polyline_at(road_pts, s)
        d = math.hypot(xb - xa, zb - za) or 1.0
        return x, z, (xb - xa) / d, (zb - za) / d
    n = 0
    for k, side in enumerate(sides):
        # side −1 = 길 북쪽(앞이 길), +1 = 길 남쪽(등이 길)
        anchor = "front" if side < 0 else "back"
        off = road_w / 2 + (setback[0] if side < 0 else setback[1])
        n += walk_line(pl, T, L, line, s1 - s0, anchor, group, gcode, mix_name, seed + k * 13, style, stats=stats, off=off,
                       max_drop=max_drop, limit=limit - n, in_frac=in_frac)
    return n


def ring_rows(pl, T, L, cells, cx, cz, group, gcode, mix_name, seed, style, stats=None, r0=26.0, pitch=17.0, max_drop=2.6,
              limit=999, zone=None, in_frac=0.5):
    """둥근 무리(round_cluster): 장터·공동 마당 둘레로 고리 줄. 집은 고리를 따라 돌고(±30°), 앞은 남쪽."""
    if len(cells) == 0:
        return 0
    rmax = float(np.sqrt(((cells - [cx, cz]) ** 2).sum(1)).max())
    n = 0
    r = r0
    ring = 0
    while r < rmax + 4 and n < limit:
        circ = 2 * math.pi * r
        th0 = random.Random(seed + ring).uniform(0, 2 * math.pi)

        def line(t, r=r, th0=th0):
            th = th0 + t / r
            # 시계 방향으로 돌며 접선
            return cx + r * math.cos(th), cz + r * math.sin(th), -math.sin(th), math.cos(th)
        n += walk_line(pl, T, L, line, circ, "center", group, gcode, mix_name, seed * 10 + ring, style, stats=stats,
                       max_drop=max_drop, limit=limit - n, zone=zone, in_frac=in_frac)
        r += pitch + random.Random(seed * 3 + ring).uniform(-1.0, 1.0)
        ring += 1
    return n


def terrace_fill(pl, T, L, cells, group, gcode, mix_name, seed, style, stats=None, band=7.0, max_drop=6.0, min_cells=5):
    """계단식(terraced): 마을 터를 등고 단(band m)과 이어진 무리로 나눠, 단마다 한 줄. 줄 앞은 돌축대(fit_terrace)."""
    from scipy.ndimage import label
    if len(cells) == 0:
        return 0
    lm = T.lm
    ii = np.round((cells[:, 0] - lm["x0"]) / lm["cell"]).astype(int)
    jj = np.round((cells[:, 1] - lm["z0"]) / lm["cell"]).astype(int)
    hs = np.array([T.height(x, z) for x, z in cells])
    tier = np.floor((hs - hs.min()) / band).astype(int)
    i0, j0 = ii.min(), jj.min()
    grid = np.zeros((jj.max() - j0 + 1, ii.max() - i0 + 1), int)
    grid[jj - j0, ii - i0] = tier + 1
    n = 0
    comps = []
    for tv in sorted(set(tier.tolist())):
        lab, nl = label(grid == tv + 1, structure=np.ones((3, 3)))
        for c in range(1, nl + 1):
            sel = lab[jj - j0, ii - i0] == c
            sel &= tier == tv
            if sel.sum() >= min_cells:
                comps.append((tv, cells[sel]))
    # 아래 단부터(계곡 쪽) — 위 단이 아래 단 집 뒤로 겹쳐 보이게
    for k, (tv, cc) in enumerate(comps):
        got = fill_rows(pl, T, L, cc, group, gcode, "terrace", seed + k * 7, max_drop=max_drop, in_frac=0.3, stats=stats,
                        style=style, single=True, gap=(1.2, 2.4), skip=0.0)
        n += got
        pl.log.append(f"[terrace] {group} 단 {tv} 칸 {len(cc)} → {got}")
    return n
