#!/usr/bin/env python3
"""대표 도시 3곳 배치 생성기 — GS_GYEONGJU(경주) · GW_GANGNEUNG(강릉) · JJ_JEJU(제주목).

    python3 tools/placement/hubs.py GS_GYEONGJU            # region_data/GS_GYEONGJU/placement_hub.json + 평면도
    python3 tools/placement/hubs.py all --noplan
    python3 tools/placement/hubs.py all --profiles         # 고을 성격표(hub_profiles.py)를 region.json에 합쳐 쓰기만

남원 동쪽 생성기(east*.py)의 배치기·마을 짜임을 그대로 쓰고(지형 폴더만 바꿈), 문화권 가옥형(kit/culture/<문화권>/)을
고르는 집터(make_slot)를 덮어씌운다. 결정적(장소별 고정 seed). 키트 크기는 Godot으로 재서 tools/placement/hubs_bounds.json에 캐시.
근거·가설: docs/reports/placement-east.md "대표 도시 3곳" 절.
"""
import json
import math
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import east_terrain as ET  # noqa: E402

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
RIDS = ["GS_GYEONGJU", "GW_GANGNEUNG", "JJ_JEJU"] if (not ARGS or ARGS[0] == "all") else [ARGS[0]]
ET.DATA = os.path.join(ET.ROOT, "region_data", RIDS[0])

import east_place as EP  # noqa: E402
EP.DEFAULT_RULES["xmin"] = -1e9
from east_place import Placer, Local, Rect, bkey, l2w, ry_along, ry_cross, clamp_ry, wrap_half  # noqa: E402
import east_village as EV  # noqa: E402
import east as E  # noqa: E402
import town_profile as PR  # noqa: E402
import hub_profiles as HP  # noqa: E402
from east_terrain import polyline_at, polyline_len, polyline_project  # noqa: E402
import numpy as np  # noqa: E402

P = E.P
ROOT = ET.ROOT
BOUNDS = os.path.join(HERE, "hubs_bounds.json")
PREFIX = {"GS_GYEONGJU": "gs", "GW_GANGNEUNG": "gw", "JJ_JEJU": "jj"}


class HubPlacer(Placer):
    prefix = "hb"

    def new_id(self, grp, kind):
        k = (grp, kind)
        self.counter[k] = self.counter.get(k, 0) + 1
        return f"{self.prefix}_{grp}_{kind}_{self.counter[k]:02d}"


# ================================================================ 고을 성격 → 문화권 집
class CStyle(PR.Style):
    def __init__(self, sid, prof):
        roof = dict(prof.get("roof") or {"choga": 1.0})
        plan = PR.PLAN_BY_CLIMATE.get(prof.get("climate", "south"), "il")
        super().__init__(sid, roof, prof.get("wall", "todam"), prof.get("layout", "rows"), plan, prof.get("archetype", "plain"))
        self.culture = prof.get("culture")
        self.climate = prof.get("climate")


def style(T, rid, sid):
    s = next((x for x in T.region["settlements"] if x["id"] == sid), {"id": sid})
    return CStyle(sid, HP.profile_for(rid, s))


def style_of(rid, prof_key, **over):
    base = dict(HP.PROFILES[rid].get(prof_key) or HP.AUTO[rid])
    base.update(over)
    return CStyle(prof_key, base)


CULTURE_FP = {
    ("culture/yeongnam/compound", "small"): [16.0, 15.0], ("culture/yeongnam/compound", "medium"): [22.0, 22.0],
    ("culture/yeongnam/compound", "large"): [27.0, 36.0],
    ("culture/gwandong/compound", "small"): [18.0, 15.0], ("culture/gwandong/compound", "medium"): [16.0, 15.0],
    ("culture/gwandong/compound", "large"): [26.0, 22.0],
    ("culture/tamna/compound", "small"): [19.0, 22.0], ("culture/tamna/compound", "medium"): [19.0, 22.0],
    ("culture/tamna/compound", "large"): [19.0, 22.0],
}


def compound_c(seed, size, st):
    """문화권 집 묶음(layout 조각 단위로 로더가 푼다)."""
    cul = st.culture
    kit = f"culture/{cul}/compound"
    p = {"seed": seed, "size": size}
    if cul == "yeongnam" and size == "medium":
        p["roof"] = "giwa" if st.pick_roof(seed, 1) == "giwa" else "choga"
    if cul == "gwandong":
        if size == "small" and st.archetype != "mountain":
            p["size"] = size = "medium"
        if size == "medium" and st.pick_roof(seed, 1) == "giwa":
            p["size"] = size = "large"
    if cul == "tamna" and st.pick_roof(seed, 1) == "giwa" and size != "large":
        return tamna_giwa_yard(seed)
    return [P(kit, p, cat="house", kind=f"{cul[:2]}_{size}", footprint=CULTURE_FP[(kit, size)], margin=0.8)]


def yard_c(seed, house, wall, hx=7.2, z0=-6.0, z1=6.5, hz=-2.3, rich=True, props=True):
    """문화권 초가 한 터: 울(wall) + 안채(house = (kit, params, fp)) + 장독 + 마당 소품. 원점 = 마당 가운데, 정면 +z."""
    r = random.Random(seed * 7919 + 17)
    gate = r.uniform(-2.5, 2.5)
    fp = [round(2 * hx + 0.8, 1), round(z1 - z0 + 0.8, 1)]
    rect = [-hx - 0.4, hx + 0.4, z0 - 0.4, z1 + 0.4]
    pts = [[round(gate - 1.6, 2), z1], [-hx, z1], [-hx, z0], [hx, z0], [hx, z1], [round(gate + 1.6, 2), z1]]
    pcs = []
    if wall == "doldam":
        pcs.append(P("culture/tamna/doldam", {"seed": seed, "points": pts, "h": 1.35, "lite": True}, cat="wall", kind="doldam",
                     aabb=rect, flatten=False, margin=0.6))
    elif wall:
        pcs.append(P("village/wall_run", {"seed": seed, "kind": wall, "points": pts}, cat="wall", kind="wall_run", aabb=rect,
                     flatten=False, margin=0.6))
    else:
        pcs.append(P("reserve", {}, reserve=True, cat="wall", aabb=rect, margin=0.6))
    kit, params, lz = house
    pcs.append(P(kit, params, r.choice([-1.0, 0.0, 0.8]), lz if lz is not None else hz, cat="house", kind=kit.split("/")[-1],
                 inner=True, footprint=fp, flatten=True, fp_center=True))
    if props:
        pcs.append(P("village/jangdok", {"seed": seed, "w": 2.4, "d": 2.0, "n": [2, 2, 1]}, hx - 2.2, z0 + 1.6, cat="prop", inner=True,
                     flatten=False))
    if rich:
        pcs.append(P("village/yard_props", {"seed": seed, "set": EV.YARD_PROPS[seed % 4]}, -hx + 2.9, 3.5, cat="prop", inner=True,
                     flatten=False))
        if r.random() < 0.5:
            pcs.append(P("village/haystack", {"seed": seed}, hx - 2.4, 3.3, cat="prop", inner=True, flatten=False))
    return pcs


def tamna_giwa_yard(seed):
    """제주 관속 기와집(가설): 현무암 벽 기와 一자 채 + 현무암 집담."""
    h = ("culture/chae", {"seed": seed, "l": 10.5, "d": 4.8, "bays": "kdmmd", "roof": "giwa", "wall": "basalt", "F": 0.5,
                          "maru": 0.6, "chimney": "low"}, -2.0)
    return yard_c(seed, h, "doldam", hx=7.6, z0=-6.0, z1=6.0)


def yard_culture(seed, st):
    cul = st.culture
    roof = st.pick_roof(seed)
    if cul == "yeongnam":
        if roof == "giwa":
            return compound_c(seed, "medium", st)        # ㅁ자 기와 뜰집
        if roof in ("choga_low",):
            return yard_c(seed, ("village/choga_low", {"seed": seed}, None), "stone_lite")
        if seed % 2 == 0:
            # ㅁ자 초가 뜰집 한 채(몸채가 곧 담) — 영남의 첫 신호를 게임 시점에서도 보이게
            return [P("culture/yeongnam/tteuljip", {"seed": seed, "roof": "choga"}, cat="house", kind="tteuljip",
                      footprint=[16.4, 16.6], margin=0.8),
                    P("village/jangdok", {"seed": seed, "w": 2.4, "d": 2.0, "n": [2, 2, 1]}, 9.6, -5.0, cat="prop", margin=0.3,
                      flatten=False)]
        plan = "giyeok" if seed % 3 == 0 else "il"
        lz = -0.9 if plan == "giyeok" else -2.3
        return yard_c(seed, ("culture/yeongnam/choga", {"seed": seed, "plan": plan}, lz), "todam_thatch",
                      z0=(-6.6 if plan == "giyeok" else -6.0))
    if cul == "gwandong":
        if roof == "giwa":
            return compound_c(seed, "large", st)          # 강릉 반가
        if roof in ("neowa", "guitul", "gulpi"):
            return yard_c(seed, (PR.ROOF_KIT[roof], {"seed": seed, "plan": "giyeok" if seed % 2 else "il"}, None), "stone_lite")
        if roof == "choga_low":
            return yard_c(seed, ("village/choga_low", {"seed": seed}, None), "stone_lite")
        return yard_c(seed, ("culture/gwandong/haean", {"seed": seed}, -1.4), "stone_lite" if seed % 3 else "fence_lite")
    if cul == "tamna":
        if roof == "giwa":
            return tamna_giwa_yard(seed)
        if seed % 3 == 0:
            return compound_c(seed, "medium" if seed % 2 else "small", st)
        # 작은 외거리집: 안거리 하나 + 현무암 집담 + 어귀 정낭(묶음 19×22보다 좁은 터에 들어간다)
        pcs = yard_c(seed, ("culture/tamna/stone_house", {"seed": seed, "kind": "an"}, -2.4), "doldam", hx=7.4, z0=-6.4, z1=5.6,
                     rich=False)
        gx = random.Random(seed * 7919 + 17).uniform(-2.5, 2.5)      # yard_c 대문 자리와 같은 수열
        pcs.append(P("culture/tamna/jeongnang", {"seed": seed, "w": 2.2, "across": seed % 4}, gx, 5.6, cat="prop", kind="jeongnang",
                     inner=True, flatten=False))
        pcs.append(P("village/props", {"seed": seed, "kind": "dok"}, 4.6, 2.2, cat="prop", inner=True, flatten=False))
        return pcs
    return None


def small_c(seed, st):
    """작은 집터(후속 수정 — 읍내 밀도): 울 없는 좁은 一자·ㄱ자 집 하나 + 장독. 큰 집터 사이 빈 틈·길가를 메운다."""
    cul = st.culture
    r = random.Random(seed * 131 + 7)
    if cul == "yeongnam":
        roof = "giwa" if st.pick_roof(seed) == "giwa" else "choga"
        plan = "giyeok" if seed % 3 == 0 else "il"
        w = r.choice([8.4, 9.0, 9.6, 10.5])
        ov = 1.0 if roof == "giwa" else 0.7
        fp = [round(w + 2 * ov, 1), round(3.8 + 2 * ov + (3.3 if plan == "giyeok" else 0.0) + 0.6, 1)]
        return [P("culture/yeongnam/jageun", {"seed": seed, "plan": plan, "roof": roof, "w": w}, cat="house", kind="yn_small",
                  footprint=fp, margin=0.6),
                P("village/jangdok", {"seed": seed, "w": 1.8, "d": 1.6, "n": [2, 1]}, -w / 2 - ov - 1.3, -1.2, cat="prop", margin=0.2,
                  flatten=False)]
    if cul == "gwandong":
        if st.pick_roof(seed) == "giwa":
            return [P("culture/chae", {"seed": seed, "l": 9.0, "d": 4.2, "bays": "kdmd", "roof": "giwa", "F": 0.5, "maru": 0.6},
                      cat="house", kind="gd_small", footprint=[11.8, 7.6], margin=0.6)]
        return [P("culture/gwandong/haean", {"seed": seed, "w": r.choice([8.4, 9.0])}, cat="house", kind="gd_small",
                  footprint=[10.6, 9.0], margin=0.6),
                P("village/jangdok", {"seed": seed, "w": 1.8, "d": 1.6, "n": [2, 1]}, -7.0, -1.0, cat="prop", margin=0.2, flatten=False)]
    if cul == "tamna":
        if seed % 2:
            return yard_c(seed, ("culture/tamna/stone_house", {"seed": seed, "kind": "bak"}, -0.6), "doldam", hx=5.0, z0=-3.8, z1=3.8,
                          rich=False, props=False)
        return yard_c(seed, ("culture/tamna/stone_house", {"seed": seed, "kind": "an"}, -0.4), "doldam", hx=6.6, z0=-4.4, z1=4.4,
                      rich=False, props=False)
    return None


def garden_tamna(seed):
    """제주 밭(우영) — 현무암 밭담 두른 채마밭."""
    r = random.Random(seed * 31 + 5)
    w = r.choice([6.0, 7.0, 8.0]); d = 5.0
    pts = [[-w / 2 - 0.6, -d / 2 - 0.6], [w / 2 + 0.6, -d / 2 - 0.6], [w / 2 + 0.6, d / 2 + 0.6], [0.6, d / 2 + 0.6]]
    return [P("nature/garden_plot", {"seed": seed, "w": w, "d": d, "crops": ["bean", "millet", "cabbage"]}, cat="prop", kind="garden",
              flatten=False, aabb=[-w / 2 - 1.0, w / 2 + 1.0, -d / 2 - 1.0, d / 2 + 1.0], margin=0.5),
            P("culture/tamna/doldam", {"seed": seed, "points": pts, "h": 1.1, "lite": True}, cat="wall", kind="batdam", inner=True,
              flatten=False)]


def small_fill(pl, T, L, cells, roads, g, gc, seed, st, ry=None):
    """후속 수정(밀도): 큰 집터를 다 놓은 뒤, 길가(앞 물림 좁게)와 마을 터 빈 틈을 작은 집터로 메운다."""
    n = 0
    for k, rid_ in enumerate(roads):
        rd = T.road(rid_)
        n += EV.street_rows(pl, T, L, cells, rd["points"], rd["width_m"], g, gc, "small", seed + k * 7, st, stats=pl.stats_,
                            setback=(0.9, 1.8), max_drop=2.4, in_frac=0.25)
    for ph, sd in ((0.0, 50), (5.5, 51)):
        n += EV.fill_rows(pl, T, L, cells, g, gc, "small", seed + sd, pitch=11.0, ry=ry, in_frac=0.5, stats=pl.stats_, style=st,
                          phase=ph, gap=(0.8, 1.8), alleys=False)
    pl.log.append(f"[small] {g}: 작은 집터 {n}")
    return n


_orig_make_slot = EV.make_slot
_orig_house_piece = EV.house_piece


def make_slot(kind, seed, st=None):
    cul = getattr(st, "culture", None)
    if not cul or kind in ("jw", "shop"):
        return _orig_make_slot(kind, seed, st)
    if kind == "yard":
        if st.wall == "stone_terrace":
            return EV.yard_set(seed, style=st)
        return yard_culture(seed, st)
    if kind.startswith("hc_"):
        return compound_c(seed, kind[3:], st)
    if kind == "small":
        return small_c(seed, st)
    if kind == "garden" and cul == "tamna":
        return garden_tamna(seed)
    if kind == "props" and cul == "tamna":
        return [P("village/yard_props", {"seed": seed, "set": "jars"}, cat="prop", kind="yard_props", flatten=False, margin=0.4),
                P("jj_bulteok" if False else "village/props", {"seed": seed, "kind": "dok"}, 3.2, 0.4, cat="prop", flatten=False,
                  margin=0.3)]
    return _orig_make_slot(kind, seed, st)


def house_piece(st, seed, roof, cx, cz, fp, r):
    cul = getattr(st, "culture", None)
    if cul == "yeongnam" and roof == "choga":
        return P("culture/yeongnam/choga", {"seed": seed, "plan": "il"}, cx, cz, cat="house", kind="yn_choga", inner=True, footprint=fp,
                 flatten=True, fp_center=True)
    return _orig_house_piece(st, seed, roof, cx, cz, fp, r)


def _clamp_or_south(a, lim=EP.MAX_RY):
    """길이 남북에 가까우면(±30° 밖) 비스듬히 세우지 않고 남향 그대로 — 격자 읍내가 어긋나 보이지 않게."""
    return a if abs(a) <= lim else 0.0


EV.clamp_ry = _clamp_or_south
EV.make_slot = make_slot
EV.house_piece = house_piece
EV.MIX.update({
    "yn_in": [("hc_medium", 0.34), ("yard", 0.50), ("hc_large", 0.04), ("garden", 0.05), ("props", 0.07)],
    "yn_eup": [("yard", 0.56), ("hc_medium", 0.18), ("hc_small", 0.12), ("garden", 0.08), ("props", 0.06)],
    "yn_ban": [("hc_large", 0.22), ("hc_medium", 0.40), ("yard", 0.26), ("garden", 0.12)],
    "gd_eup": [("yard", 0.46), ("hc_large", 0.16), ("hc_medium", 0.18), ("garden", 0.12), ("props", 0.08)],
    "gd_ban": [("hc_large", 0.4), ("yard", 0.35), ("garden", 0.15), ("props", 0.10)],
    "tn_eup": [("yard", 0.72), ("hc_large", 0.08), ("garden", 0.12), ("props", 0.08)],
    "tn_village": [("yard", 0.76), ("garden", 0.14), ("props", 0.10)],
    "shore": [("yard", 0.70), ("garden", 0.12), ("props", 0.18)],
    "front": [("yard", 0.88), ("props", 0.12)],
    # 후속 수정(밀도): 작은 집터로 길가·틈 메우기
    "small": [("small", 1.0)],
})


# ================================================================ 공용 도우미
def wall_pieces(pts, closed, gaps, seed, h=2.2, seg=12.0):
    """kit/landmark/_common.gd wall_pieces() 옮김(namwon.py와 같음)."""
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
                out.append({"params": {"seed": seed + k, "length": round(t1 - t0 + 0.25, 2), "height": h},
                            "x": a[0] + dx * (t0 + t1) / 2, "z": a[1] + dz * (t0 + t1) / 2, "ry": -math.atan2(dz, dx)})
                k += 1
    return out


def court(seed, x0, x1, z0, z1, gaps, h=2.2, kit="landmark/gwana_wall", sides=(True, True, True, True)):
    """담 둘레(로컬 좌표) 조각들 + 담 안 reserve. sides = (북, 동, 남, 서)."""
    pcs = []
    corners = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    for i, on in enumerate(sides):
        if not on:
            continue
        a, b = corners[i], corners[(i + 1) % 4]
        for w in wall_pieces([a, b], False, gaps, seed + i * 10, h):
            ln = w["params"]["length"]
            pcs.append(P(kit, w["params"], w["x"], w["z"], w["ry"], cat="wall", kind="wall", aabb=[-ln / 2, ln / 2, -0.55, 0.55],
                         margin=0.1, flatten=False, nocheck=True))
    pcs.append(P("reserve", {}, reserve=True, aabb=[x0, x1, z0, z1], margin=0.0))
    return pcs


def put(pl, pcs, x, z, ry, g, gc, R=0.0, rules=None, seed=1, n=400, force=True, road_pref=(0.5, 40.0)):
    """정해진 자리(가까이 R 안에서 찾기 → 안 되면 그 자리에 강제)."""
    T = pl.T
    L = Local(T, x, z, max(R, 40) + 100)
    if R > 0:
        r = pl.place_search(L, pcs, x, z, R, g, gc, random.Random(seed), rules, ry_fixed=ry, n=n, road_pref=road_pref,
                            north_bias=0.0, pref=(x, z))
        if r:
            return r
    return pl.place_fixed(L, pcs, x, z, ry, g, gc, rules, force=force)


def search(pl, pcs, x, z, R, g, gc, seed, rules=None, face="road", n=400, road_pref=(1.0, 8.0), ry=None):
    L = Local(pl.T, x, z, R + 100)
    return pl.place_search(L, pcs, x, z, R, g, gc, random.Random(seed), rules or {"max_drop": 3.0}, face=face, n=n,
                           road_pref=road_pref, ry_fixed=ry)


def lmk(T, lid):
    return next(l for l in T.region["landmarks"] if l["id"] == lid)


def stl(T, sid):
    return next(s for s in T.region["settlements"] if s["id"] == sid)


def rect_cells(T, x0, z0, x1, z1, lu=(6,)):
    lm = T.lm
    i0 = int((x0 - lm["x0"]) / lm["cell"]); i1 = int((x1 - lm["x0"]) / lm["cell"]) + 1
    j0 = int((z0 - lm["z0"]) / lm["cell"]); j1 = int((z1 - lm["z0"]) / lm["cell"]) + 1
    sub = T.L[j0:j1, i0:i1]
    jj, ii = np.nonzero(np.isin(sub, lu))
    return np.stack([lm["x0"] + (ii + i0) * lm["cell"], lm["z0"] + (jj + j0) * lm["cell"]], 1).astype(float)


def seonghwang(pl, x, z, g, gc, seed, R=24, dangjip=False, rules=None):
    """고개·어귀 성황당: 돌무더기 + 신목(느티)."""
    shp = {"seed": seed, "tree": False}
    if dangjip:
        shp["dangjip"] = True
    anc = pl.bounds.get(bkey("village/seonghwangdang", shp), {}).get("anchors", {}).get("tree", [0, 0, -1.2])
    pcs = [P("village/seonghwangdang", shp, cat="shrine", kind="seonghwangdang", label="성황당", road_min=0.8),
           P("nature/big_tree", {"seed": seed + 1, "variant": "zelkova", "h": 8.0, "spread": 5.0}, anc[0], anc[2], cat="prop",
             kind="sinmok", aabb=[-1.2, 1.2, -1.2, 1.2], flatten=False, nocheck=True, tree=True)]
    L = Local(pl.T, x, z, R + 80)
    r = pl.place_search(L, pcs, x, z - 6, R, g, gc, random.Random(seed), rules or {"max_drop": 3.0}, road_pref=(0.8, 7.0),
                        pref=(x, z - 6), north_bias=0.0)
    if not r:
        r = pl.place_search(L, pcs[:1], x, z, R, g, gc, random.Random(seed + 1), rules or {"max_drop": 3.5}, road_pref=(0.8, 9.0))
    return r


def jumak_c(seed, cul):
    """주막 — 문화권 집 모양으로(탐라 돌집·관동 너와), 나머지는 village/jumak."""
    if cul == "tamna":
        return [P("culture/tamna/stone_house", {"seed": seed, "kind": "an"}, 0.0, -1.5, cat="jumak", kind="jumak", label="주막",
                  aabb=[-6.2, 6.2, -5.4, 2.4], margin=0.6),
                P("village/props", {"seed": seed, "kind": "pyeongsang"}, -2.4, 3.6, cat="prop", kind="pyeongsang", flatten=False,
                  margin=0.3, road_min=0.4),
                P("village/props", {"seed": seed + 1, "kind": "yongsu"}, 4.8, 3.2, cat="prop", kind="yongsu", flatten=False, margin=0.2,
                  road_min=0.3),
                P("village/props", {"seed": seed + 2, "kind": "gamasot"}, 1.4, 3.6, cat="prop", kind="gamasot", flatten=False,
                  margin=0.2, road_min=0.4)]
    if cul == "gwandong_mt":
        return [P("village/neowa_house", {"seed": seed, "plan": "il"}, 0.0, -1.5, cat="jumak", kind="jumak", label="주막",
                  aabb=[-4.8, 4.8, -5.0, 2.2], margin=0.6),
                P("village/props", {"seed": seed, "kind": "pyeongsang"}, -2.2, 3.4, cat="prop", kind="pyeongsang", flatten=False,
                  margin=0.3, road_min=0.4),
                P("village/props", {"seed": seed + 1, "kind": "yongsu"}, 4.2, 3.0, cat="prop", kind="yongsu", flatten=False, margin=0.2,
                  road_min=0.3),
                P("village/firewood", {"seed": seed, "style": "stack"}, -5.8, 0.6, cat="prop", flatten=False, margin=0.3)]
    return [P("village/jumak", {"seed": seed}, cat="jumak", kind="jumak", label="주막")]


def bulteok(seed):
    """해녀 불턱 — 바닷가 현무암 둥근 담(옷 갈아입고 불 쬐는 자리)."""
    pts = []
    for k in range(9):
        a = math.pi * 0.15 + k / 8 * math.pi * 1.7
        pts.append([round(math.cos(a) * 2.6, 2), round(math.sin(a) * 2.2, 2)])
    return [P("culture/tamna/doldam", {"seed": seed, "points": pts, "h": 1.1, "lite": False}, cat="prop", kind="bulteok",
              label="불턱", aabb=[-3.2, 3.2, -2.8, 2.8], margin=0.4, flatten=False, river_min=0.0)]


def mulbtong(seed):
    """용천수 물통 — 돌담으로 둘러친 샘(남탕·여탕) + 빨래터."""
    pts_a = [[-4.0, 1.6], [-4.0, -2.0], [-0.3, -2.0], [-0.3, 1.6]]
    pts_b = [[0.3, 1.6], [0.3, -2.0], [4.0, -2.0], [4.0, 1.6]]
    return [P("culture/tamna/doldam", {"seed": seed, "points": pts_a, "h": 1.4, "lite": False}, cat="prop", kind="mulbtong",
              label="용천수 물통", aabb=[-4.4, 4.4, -2.4, 2.2], margin=0.4, flatten=True, river_min=0.0),
            P("culture/tamna/doldam", {"seed": seed + 1, "points": pts_b, "h": 1.4, "lite": False}, cat="prop", kind="mulbtong",
              inner=True, flatten=False),
            P("village/ppallaeteo", {"seed": seed}, -2.1, 0.0, cat="prop", kind="ppallaeteo", inner=True, flatten=False),
            P("village/well", {"seed": seed, "roof": False}, 2.1, -0.2, cat="prop", kind="spring", inner=True, flatten=False)]


def boats(pl, x, z, g, gc, seed, n=3, R=40):
    """물가 배: 가까운 물(하천·바다) 가장자리에 나룻배 n척(원점 = 수면, 로더가 y를 수면으로)."""
    T = pl.T
    lm = T.lm
    got = 0
    rng = random.Random(seed)
    cand = []
    for _ in range(600):
        a = rng.uniform(0, 2 * math.pi); r = R * math.sqrt(rng.uniform(0, 1))
        px, pz = x + r * math.cos(a), z + r * math.sin(a)
        if T.landuse(px, pz) != 5:
            continue
        # 물 가장자리 4~9m 안(뭍 칸이 가까운 곳)
        near = any(T.landuse(px + dx, pz + dz) != 5 for dx, dz in [(6, 0), (-6, 0), (0, 6), (0, -6)])
        if near:
            cand.append((math.hypot(px - x, pz - z), px, pz))
    cand.sort()
    placed = []
    for _, px, pz in cand:
        if got >= n:
            break
        if any(math.hypot(px - qx, pz - qz) < 7 for qx, qz in placed):
            continue
        ry = rng.uniform(-0.5, 0.5)
        pl.commit([P("village/narutbae", {"seed": seed + got}, cat="bridge", kind="narutbae", flatten=False, nocheck=True, clear_veg=False,
                     y=0.0 if T.region.get("sea") and T.height(px, pz) < 0.2 else None)], px, pz, ry, g, gc)
        placed.append((px, pz)); got += 1
    return got


def warehouses(pl, x, z, g, gc, seed, n=3, cul=None, R=40):
    """포구 객주·창고(§26): 헛간(창고) 줄 + 가가."""
    out = 0
    for k in range(n):
        if cul == "tamna":
            pcs = [P("culture/chae", {"seed": seed + k, "l": 9.0, "d": 4.4, "bays": "bkkb", "roof": "tti", "wall": "basalt", "F": 0.3,
                                      "rope": 0.55, "rise_k": 0.42}, cat="house", kind="changgo", label="객주 창고")]
        else:
            pcs = [P("village/heotgan", {"seed": seed + k, "w": 6.0, "d": 4.0, "walls": "three"}, cat="house", kind="changgo",
                     label="객주 창고")]
        if search(pl, pcs, x, z, R, g, gc, seed + k * 7, {"max_drop": 2.4, "river_min": 0.5}, road_pref=(0.8, 10.0)):
            out += 1
    return out


def bridges(pl, T, gc_map=None):
    """권역 도강점 전부: 돌다리·섶다리·징검다리(여울은 디딤돌), 나루는 나룻배 + 횃대(§25 나머지는 장소별)."""
    done = []
    for c in T.region["crossings"]:
        kit = E.crossing_kit(T, c)
        # 후속 수정: 건천이 읍내 큰길(폭 3.5m 이상)을 건너는 데는 징검다리 대신 돌다리(제주성 안 산지천·무명 내)
        if kit == "village/jingeom" and T.river(c["river_id"]).get("dry") and float(T.road(c["road_id"]).get("width_m", 3.0)) >= 3.5:
            kit = "village/stone_bridge"
        if any(math.hypot(c["x"] - d[0], c["z"] - d[1]) < 9 for d in done):
            continue
        L = Local(T, c["x"], c["z"], 40)
        if c["type"] == "나루":
            boats(pl, c["x"], c["z"], "나루", "naru", 600 + len(done), n=2, R=30)
            done.append((c["x"], c["z"]))
            continue
        if not kit:
            continue
        rd = T.road(c["road_id"])
        s, _ = polyline_project(rd["points"], c["x"], c["z"])
        x1, z1, _ = polyline_at(rd["points"], max(0, s - 6))
        x2, z2, _ = polyline_at(rd["points"], s + 6)
        dx, dz = x2 - x1, z2 - z1
        n = math.hypot(dx, dz) or 1
        dx, dz = dx / n, dz / n
        wy = L.water_y(c["x"], c["z"], c["river_id"])
        nr = L.nearest_river(c["x"], c["z"])
        rdx, rdz = nr[3] if nr else (1, 0)
        nx, nz = -rdz, rdx
        if nx * dx + nz * dz < 0:
            nx, nz = -nx, -nz
        jg = kit == "village/jingeom"
        base = math.atan2(nz, nx)
        road_a = math.atan2(dz, dx)
        best = None
        cands = [road_a, base] + [base + math.radians(d_) for d_ in range(-60, 61, 15)]
        for k, ang in enumerate(cands):
            ddx, ddz = math.cos(ang), math.sin(ang)
            tA, tB, y, step = E.fit_span(T, L, c["x"], c["z"], ddx, ddz, wy, jg)
            score = step * 4 + (tB - tA) * 0.08 + (0 if k == 0 else 0.15)
            if best is None or score < best[0]:
                best = (score, ddx, ddz, tA, tB, y, step)
        _, dx, dz, tA, tB, y, step = best
        ln = round(min(max(tB - tA, 4.0), 38.0), 1)
        tm = (tA + tB) / 2
        bx, bz = c["x"] + dx * tm, c["z"] + dz * tm
        if jg:
            params = {"seed": 21 + len(done), "len": ln}
        elif kit == "village/seop_bridge":
            params = {"seed": 31 + len(done), "len": ln, "spans": max(3, int(ln / 2.6))}
        else:
            params = {"seed": 41 + len(done), "len": ln, "hw": 1.3}
        label = {"village/seop_bridge": "섶다리", "village/stone_bridge": "돌다리", "village/jingeom": "징검다리"}[kit]
        pl.commit([P(kit, params, cat="bridge", kind=kit.split("/")[-1], flatten=False, nocheck=True, y=round(y, 2), label=label,
                     id=f"{pl.prefix}_br_{c['id']}")], bx, bz, ry_cross(dx, dz), "다리·징검다리(도강점)", "br")
        done.append((c["x"], c["z"]))


def gate_c(pl, T, road, s, g, gc, seed, cul, sotdae=True):
    """마을 어귀: 영남·관동은 장승(+솟대), 탐라는 방사탑 둘(길 양쪽)."""
    L = Local(T, *polyline_at(T.road(road)["points"], s)[:2], 60)
    if cul != "tamna":
        return E.gate_props(pl, T, L, road, s, g, gc, random.Random(seed), sotdae=sotdae, quiet=True)
    pts = T.road(road)["points"]
    w = T.road(road)["width_m"]
    for ds in [0, 4, -4, 8, -8, 12, -12, 16, -16]:
        x, z, d = polyline_at(pts, s + ds)
        nx, nz = -d[1], d[0]
        off = w / 2 + 2.8
        a = [P("landmark/jj_bangsatap", {"seed": seed}, cat="prop", kind="bangsatap", label="방사탑", margin=0.3, road_min=0.3)]
        b = [P("landmark/jj_bangsatap", {"seed": seed + 1}, cat="prop", kind="bangsatap", margin=0.3, road_min=0.3)]
        if pl.check(L, a, x + nx * off, z + nz * off, 0.0, {"max_drop": 2.0})[0] and pl.check(L, b, x - nx * off, z - nz * off, 0.0, {"max_drop": 2.0})[0]:
            return pl.commit(a, x + nx * off, z + nz * off, 0.0, g, gc) + pl.commit(b, x - nx * off, z - nz * off, 0.0, g, gc)
    return []


def village_c(pl, T, rid, sid, g, gc, mix, seed, road=None, toward=None, limit=999, square=True, wells=1, street=None,
              center=None, max_drop=2.6, extra_ids=(), cells=None):
    """문화권 마을: east.village2(짜임·어귀·마당·우물) + 성격표 문화권 집. 탐라 어귀는 방사탑."""
    st = style(T, rid, sid)
    if st.culture == "tamna" and road and toward:
        s_ = stl(T, sid)
        e = E.entrance(T, road, s_["x"], s_["z"], min(70, s_.get("radius_m", 40)), toward)
        if e:
            gate_c(pl, T, road, e[1], g, gc, seed, "tamna")
        road_, toward_ = None, None
    else:
        road_, toward_ = road, toward
    return E.village2(pl, T, sid, g, gc, mix, seed, road=road_, toward=toward_, square=square, wells=wells, limit=limit, style=st,
                      street=street, center=center, max_drop=max_drop, extra_ids=extra_ids, cells=cells, stats=pl.stats_)


def tree(variant, seed, lx=0.0, lz=0.0, **kw):
    p = {"seed": seed, "variant": variant}
    p.update(kw)
    return P("nature/big_tree", p, lx, lz, cat="prop", kind="tree_" + variant, aabb=[-1.2, 1.2, -1.2, 1.2], flatten=False,
             margin=0.6, river_min=1.0, tree=True)


def scatter_props(pl, x, z, R, g, gc, seed, kit, params_fn, n, rules=None, face="none", aabb=None):
    got = 0
    for k in range(n * 3):
        if got >= n:
            break
        pcs = [P(kit, params_fn(k), cat="prop", kind=kit.split("/")[-1], flatten=False, margin=0.5, aabb=aabb, nocheck=False)]
        if search(pl, pcs, x, z, R, g, gc, seed + k * 13, rules or {"max_drop": 4.0}, face=face, n=80):
            got += 1
    return got


def ritual(pl, T, kit, params, fp, x, z, g, gc, seed, label, R=60):
    """읍치 제의 시설: 사직단(서)·여단(북)·성황사(진산 기슭) — 원칙 방향의 가설 자리 근처에서 찾는다."""
    pcs = [P(kit, params, cat="landmark", kind=kit.split("/")[1], label=label, footprint=fp, road_min=0.3)]
    if kit.endswith("seonghwangsa"):
        anc = pl.bounds.get(bkey(kit, params), {}).get("anchors", {}).get("tree")
        if anc:
            pcs.append(P("nature/big_tree", {"seed": seed + 1, "variant": "zelkova"}, anc[0], anc[2], cat="prop", kind="sinmok",
                         aabb=[-1.2, 1.2, -1.2, 1.2], flatten=False, nocheck=True))
    L = Local(T, x, z, R + 100)
    r = pl.place_search(L, pcs, x, z, R, g, gc, random.Random(seed), {"max_drop": 3.5, "lu_bad": (5, 6, 7)}, n=600,
                        road_pref=(0.5, 60.0), north_bias=0.0, ry_fixed=0.0, pref=(x, z))
    if r:
        r[0]["_label"] = label
    return r


# ================================================================ 읍성(성벽 둘레)
def eupseong(pl, T, cx, cz, hx, hz, gates, wall_kit, wall_thick, gate_fn, g, gc, seed, corner=True, chi=True, gate_w=18.0,
             river_gap=True):
    """방형(직사각) 읍성: 네 변 성벽 조각 + 성문 + 모서리 + 치. gates = {"S": name, ...}.
    하천이 성벽 선을 지나면 그 자리는 수구(水口)로 비운다."""
    side = {"S": (0.0, hx, hz), "E": (math.pi / 2, hz, hx), "N": (math.pi, hx, hz), "W": (-math.pi / 2, hz, hx)}
    Lw = Local(T, cx, cz, max(hx, hz) + 60)
    n_wall = 0
    for sd, (ry, half_a, half_o) in side.items():
        zc = half_o - wall_thick / 2
        if sd in gates:
            gx, gz = l2w(cx, cz, ry, 0.0, zc)
            pl.commit([P(*gate_fn(sd, gates[sd]), cat="landmark", kind="seongmun", label=gates[sd], flatten=False, nocheck=True,
                         id=f"{pl.prefix}_eupseong_gate_{sd}")], gx, gz, ry, g, gc)
            # 문 안·밖 광장
            for lz, w_, d_ in ((zc - wall_thick / 2 - 7.0, 16.0, 12.0), (zc + wall_thick / 2 + 7.0, 18.0, 12.0)):
                qx, qz = l2w(cx, cz, ry, 0.0, lz)
                pl.commit([P("reserve", {}, reserve=True, aabb=[-w_ / 2, w_ / 2, -d_ / 2, d_ / 2])], qx, qz, ry, g, gc)
        if corner:
            ux, uz = l2w(cx, cz, ry, half_a - wall_thick / 2, zc)
            if wall_kit == "landmark/seong_wall":
                pl.commit([P("landmark/seong_corner", {"seed": seed}, cat="wall", kind="corner", flatten=False, nocheck=True)], ux, uz, ry,
                          g, gc)
        g0, g1 = -half_a + wall_thick, half_a - (0.0 if wall_kit != "landmark/seong_wall" else wall_thick)
        if wall_kit != "landmark/seong_wall":
            g0, g1 = -half_a, half_a
        cuts = []
        if sd in gates:
            cuts.append((-gate_w / 2 - 1.5, gate_w / 2 + 1.5))
        # 수구: 하천이 지나는 자리
        if river_gap:
            u = g0
            while u < g1:
                wx, wz = l2w(cx, cz, ry, u, zc)
                if Lw.river_clear([(wx, wz)])[0] < 0.5:
                    cuts.append((u - 2.5, u + 2.5))
                u += 1.0
        cuts.sort()
        merged = []
        for c in cuts:
            if merged and c[0] <= merged[-1][1] + 1.0:
                merged[-1] = (merged[-1][0], max(merged[-1][1], c[1]))
            else:
                merged.append(c)
        spans = []
        s0 = g0
        for c in merged:
            if c[0] - s0 > 1.0:
                spans.append((s0, c[0]))
            s0 = max(s0, c[1])
        if g1 - s0 > 1.0:
            spans.append((s0, g1))
        for (a, b) in spans:
            L_ = b - a
            nseg = max(1, math.ceil(L_ / 20.0))
            for i in range(nseg):
                s_a = a + L_ * i / nseg; s_b = a + L_ * (i + 1) / nseg
                ln = round(s_b - s_a + (0.0 if wall_kit == "landmark/seong_wall" else 0.3), 2)
                wx, wz = l2w(cx, cz, ry, (s_a + s_b) / 2, zc)
                pl.commit([P(wall_kit, {"seed": seed + n_wall, "length": ln}, cat="wall", kind="seong_wall", flatten=False,
                             nocheck=True, aabb=[-ln / 2, ln / 2, -wall_thick / 2, wall_thick / 2 + 0.4])], wx, wz, ry, g, gc)
                n_wall += 1
        if chi:
            for u in (-half_a / 2, half_a / 2):
                if abs(u) < gate_w and sd in gates:
                    continue
                wx, wz = l2w(cx, cz, ry, u, half_o)
                if Lw.river_clear([(wx, wz)])[0] < 3.0:
                    continue
                pl.commit([P("landmark/seong_chi", {"seed": seed + 90, "width": 8, "depth": 6}, cat="wall", kind="chi", flatten=False,
                             nocheck=True)], wx, wz, ry, g, gc)
        # 성벽 안 순성로(3m)·밖 해자 자리(8m)는 집을 들이지 않는다
        for lz, d_ in ((zc - wall_thick / 2 - 1.5, 3.0), (zc + wall_thick / 2 + 4.0, 8.0)):
            qx, qz = l2w(cx, cz, ry, 0.0, lz)
            pl.commit([P("reserve", {}, reserve=True, aabb=[-half_a, half_a, -d_ / 2, d_ / 2])], qx, qz, ry, g, gc)
    return n_wall


# ================================================================ 경주
def build_gyeongju(pl, T):
    rid = "GS_GYEONGJU"
    reg = T.region
    bridges(pl, T)
    CX, CZ, H = -2936.0, -2258.0, 75.0
    WT = 4.6
    G, GC = "경주 읍내", "eup"
    YN = style(T, rid, "gyeongju_eup")

    # ── 1. 읍성(4문) ──
    names = {"S": "징례문", "E": "향일문", "N": "공진문", "W": "망미문"}
    eupseong(pl, T, CX, CZ, H, H, names, "landmark/seong_wall", WT,
             lambda sd, nm: ("landmark/gj_eupseong_gate", {"seed": 11 + "SENW".index(sd), "name": nm, "open": "none"}),
             "경주읍성", "seong", 1100, gate_w=18.0)

    # ── 2. 객사 동경관: 남북 축(남문→네거리→북) 끝, 남문을 바라봄. 북문길(z −2292) 남쪽 좁은 띠 ──
    # 후속 수정: 북문길을 순성로 바로 안(z −2318.5)에서 꺾어(fix_roads) 일곽을 41.5m 깊이로, 앞마당 약 18m
    gz1, gz0 = -2268.5, -2310.0
    pcs = [P("landmark/gj_dongyeonggwan", {"seed": 21}, 0.0, -27.0, cat="civic", kind="gaeksa", label="동경관", footprint=[45.6, 14.0],
             nocheck=True),
           P("landmark/samun", {"seed": 22, "kind": "outer", "name": "동경관"}, 0.0, 0.0, cat="civic", kind="samun", label="동경관 삼문",
             nocheck=True)]
    for w in wall_pieces([(-26, 0.0), (26, 0.0), (26, gz0 - gz1), (-26, gz0 - gz1)], True, [(0.0, 0.0, 6.0), (0.0, gz0 - gz1, 2.4)],
                         2200, 2.2):
        ln = w["params"]["length"]
        pcs.append(P("landmark/gwana_wall", w["params"], w["x"], w["z"], w["ry"], cat="wall", kind="wall",
                     aabb=[-ln / 2, ln / 2, -0.55, 0.55], flatten=False, nocheck=True))
    pcs.append(P("reserve", {}, reserve=True, aabb=[-26, 26, gz0 - gz1, 0.0]))
    pl.commit(pcs, CX, gz1, 0.0, "객사 동경관", "gaeksa", y=None)

    # ── 3. 경주부 관아(동헌 일승각): 객사 서쪽 곁(서북 구획, 가설) — 외삼문(동서길) → 내삼문 → 동헌 → 내아 ──
    ax0, ax1, az0, az1 = -3001.5, -2964.5, -2326.0, -2264.0
    acx = (ax0 + ax1) / 2
    pcs = [P("landmark/samun", {"seed": 31, "kind": "outer", "name": "경주부 관아"}, acx, az1, cat="civic", kind="samun",
             label="경주부 관아", nocheck=True),
           P("landmark/samun", {"seed": 32, "kind": "inner"}, acx, az1 - 15.0, cat="civic", kind="samun", nocheck=True),
           P("landmark/dongheon", {"seed": 33, "bays": 7}, acx, az1 - 27.5, cat="civic", kind="dongheon", label="일승각",
             footprint=[23.7, 10.6], nocheck=True),
           P("landmark/naea", {"seed": 34, "wing": True}, acx + 3.0, az0 + 11.0, cat="civic", kind="naea", label="내아",
             footprint=[15.7, 15.4], nocheck=True)]
    for w in wall_pieces([(ax0, az0), (ax1, az0), (ax1, az1), (ax0, az1)], True, [(acx, az1, 6.0)], 2300, 2.4) + \
            wall_pieces([(ax0, az1 - 15.0), (ax1, az1 - 15.0)], False, [(acx, az1 - 15.0, 6.0)], 2350, 2.2):
        ln = w["params"]["length"]
        pcs.append(P("landmark/gwana_wall", w["params"], w["x"], w["z"], w["ry"], cat="wall", kind="wall",
                     aabb=[-ln / 2, ln / 2, -0.55, 0.55], flatten=False, nocheck=True))
    pcs.append(P("reserve", {}, reserve=True, aabb=[ax0, ax1, az0, az1]))
    pcs.append(P("reserve", {}, reserve=True, aabb=[acx - 8, acx + 8, az1, az1 + 4.0]))
    pl.commit(pcs, 0.0, 0.0, 0.0, "경주부 관아", "gwana")
    for tx in (acx - 7.5, acx + 7.5):
        pl.commit([P("village/torch_post", {"seed": 35}, cat="prop", kind="torch", flatten=False, nocheck=True)], tx, az1 + 2.2, 0.0,
                  "경주부 관아", "gwana")

    # ── 4. 성 안 민가: 길가 줄(십자길 양쪽) → 구획 채우기. 성 안은 이속 기와 ㅁ자 뜰집 위주 ──
    inner = (CX - H + WT + 1.5, CZ - H + WT + 1.5, CX + H - WT - 1.5, CZ + H - WT - 1.5)
    cells_in = rect_cells(T, *inner, lu=(6, 1, 3))
    Lin = Local(T, CX, CZ, 130)
    for k, rid_ in enumerate(["gyeongju_eup_street_ns", "gyeongju_eup_street_ew", "gyeongju_eup_street_n"]):
        rd = T.road(rid_)
        EV.street_rows(pl, T, Lin, cells_in, rd["points"], rd["width_m"], G + "(성 안)", GC, "yn_in", 410 + k * 7, YN,
                       stats=pl.stats_, max_drop=2.4, in_frac=0.3)
    EV.fill_rows(pl, T, Lin, cells_in, G + "(성 안)", GC, "yn_in", 420, pitch=17.0, ry=0.0, in_frac=0.4, stats=pl.stats_, style=YN)
    EV.fill_rows(pl, T, Lin, cells_in, G + "(성 안)", GC, "yn_in", 421, pitch=17.0, ry=0.0, in_frac=0.4, stats=pl.stats_, style=YN,
                 phase=8.5, gap=(1.2, 2.4))
    EV.fill_rows(pl, T, Lin, cells_in, G + "(성 안)", GC, "yn_in", 422, pitch=14.0, ry=0.0, in_frac=0.4, stats=pl.stats_, style=YN,
                 phase=4.0, gap=(1.0, 2.0))
    small_fill(pl, T, Lin, cells_in, ["gyeongju_eup_street_ns", "gyeongju_eup_street_ew", "gyeongju_eup_street_n"], G + "(성 안)", GC,
               425, YN, ry=0.0)
    # 성 안 우물 둘
    for k, (wx, wz) in enumerate([(CX - 30, CZ + 30), (CX + 30, CZ + 28)]):
        search(pl, [P("village/well", {"seed": 440 + k, "roof": False}, cat="prop", kind="well", margin=1.0)], wx, wz, 25, G, GC, 440 + k,
               face="none")

    # ── 5. 서문 밖 장(봉황대 그늘): 영천길 따라 가가·좌판 ──
    rng = random.Random(501)
    Lm = Local(T, -3040, -2230, 160)
    wr = T.road("gyeongju_west_road")["points"]
    s0, _ = polyline_project(wr, -3012, -2258)
    E.market(pl, T, Lm, "gyeongju_west_road", s0 + 14, s0 + 95, "경주 장", "jang", rng, shops=6, jwapan=14)
    jcells = EV.cells_of(T, stl(T, "gyeongju_jang"), reg["settlements"])
    EV.fill_rows(pl, T, Lm, jcells, "경주 장", "jang", "market", 502, pitch=8.5, gap=(1.0, 2.0), max_drop=1.8, limit=16, stats=pl.stats_)
    search(pl, jumak_c(503, "yeongnam"), -3080, -2215, 40, "경주 장", "jang", 503)
    search(pl, jumak_c(504, "yeongnam"), -2850, -2262 + 14, 30, G, GC, 504, road_pref=(1.0, 6.0))   # 동문 밖(감포길)

    # ── 6. 봉황대·노서 고분(성 서쪽 장터 둘레) + 대릉원(성 남서 들) — 경주의 첫 신호 ──
    bh = lmk(T, "bonghwangdae")
    put(pl, [P("landmark/gj_tumulus", {"seed": 601, "radius": 30.0, "height": 15.0, "trees": 3}, cat="landmark", kind="tumulus",
               label="봉황대", flatten=False, footprint=[60.0, 60.0])], bh["x"], bh["z"], 0.0, "고분", "tomb", R=14,
        rules={"max_drop": 12.0, "lu_bad": (5,), "road_min": 0.5})
    for k, (tx, tz, r_, h_, tw) in enumerate([
            (-3118, -2140, 12, 5.0, False), (-3100, -2100, 9, 4.0, False), (-3132, -2178, 8, 3.5, False),  # 노서동 고분(금관총·서봉총 쪽)
            (-3000, -2085, 22, 10.0, True),                                                                  # 대릉원 황남대총(표형분)
            (-3048, -2058, 14, 6.5, False), (-2962, -2040, 12, 6.0, False), (-3030, -2018, 10, 5.0, False),  # 대릉원
            (-2995, -2135, 9, 4.0, False), (-2905, -2110, 8, 3.5, False), (-3070, -2098, 11, 5.0, False),
            (-2885, -2060, 10, 4.5, False), (-3090, -2040, 9, 4.0, False)]):
        put(pl, [P("landmark/gj_tumulus", {"seed": 610 + k, "radius": float(r_), "height": h_, "twin": tw}, cat="landmark",
                   kind="tumulus", label="고분", flatten=False, footprint=[2 * r_ * (1.8 if tw else 1.0), 2 * r_])],
            tx, tz, 0.0, "고분", "tomb", R=26, seed=610 + k, rules={"max_drop": 9.0, "lu_bad": (5, 6), "road_min": 1.5}, force=False)

    # ── 7. 성 밖 민가(읍내 마을 터) ──
    s_ = stl(T, "gyeongju_eup")
    b = s_["bbox"]
    cells_out = rect_cells(T, b[0], b[1], b[2], b[3], lu=(6,))
    m = ~((np.abs(cells_out[:, 0] - CX) < H + 10) & (np.abs(cells_out[:, 1] - CZ) < H + 10))
    cells_out = cells_out[m]
    Lo = Local(T, CX, CZ, 260)
    for k, rid_ in enumerate(["gyeongju_ulsan_road", "gampo_road", "north_road", "gyeongju_west_road"]):
        rd = T.road(rid_)
        EV.street_rows(pl, T, Lo, cells_out, rd["points"], rd["width_m"], G + "(성 밖)", GC, "yn_eup", 450 + k * 11, YN,
                       stats=pl.stats_, max_drop=2.4, in_frac=0.35)
    for k, rid_ in enumerate(["gyeongju_ulsan_road", "gampo_road", "north_road", "gyeongju_west_road"]):
        rd = T.road(rid_)     # 길가 띠: 마을 터 밖 길가(밭·풀밭)까지 작은 집터를 잇는다(읍내 들머리 길촌)
        EV.street_rows(pl, T, Lo, cells_out, rd["points"], rd["width_m"], G + "(성 밖)", GC, "front", 460 + k * 11, YN,
                       stats=pl.stats_, max_drop=2.4, in_frac=0.0)
    EV.fill_rows(pl, T, Lo, cells_out, G + "(성 밖)", GC, "yn_eup", 470, pitch=18.0, in_frac=0.5, stats=pl.stats_, style=YN)
    EV.fill_rows(pl, T, Lo, cells_out, G + "(성 밖)", GC, "yn_eup", 471, pitch=18.0, in_frac=0.5, stats=pl.stats_, style=YN, phase=9.0)
    EV.fill_rows(pl, T, Lo, cells_out, G + "(성 밖)", GC, "yn_eup", 472, pitch=14.0, in_frac=0.5, stats=pl.stats_, style=YN, phase=4.0,
                 gap=(1.0, 2.0))
    small_fill(pl, T, Lo, cells_out, ["gyeongju_ulsan_road", "gampo_road", "north_road", "gyeongju_west_road"], G + "(성 밖)", GC, 475,
               YN)
    # 어귀: 남문 밖 울산길(장승·솟대), 북문 밖
    for rid_, tw in [("gyeongju_ulsan_road", (-2932, -2060)), ("north_road", (-2925, -2420)), ("gampo_road", (-2760, -2255))]:
        e = E.entrance(T, rid_, CX, CZ, 120, tw)
        if e:
            gate_c(pl, T, rid_, e[1], G, GC, 480 + len(rid_), "yeongnam")

    # ── 8. 읍치 제의 시설(원칙: 사직단 서·여단 북·성황사 진산 기슭) — 가설 자리 ──
    ritual(pl, T, "landmark/sajikdan", {"seed": 801, "dual": False}, [25.0, 25.0], -3170, -2300, "읍치 제의 시설", "rit", 801, "경주 사직단")
    ritual(pl, T, "landmark/yeodan", {"seed": 802}, [19.0, 19.0], -2930, -2470, "읍치 제의 시설", "rit", 802, "경주 여단")
    ritual(pl, T, "landmark/seonghwangsa", {"seed": 803, "tree_stub": True}, [20.0, 18.0], -2700, -2350, "읍치 제의 시설", "rit", 803,
           "경주 성황사")

    # ── 9. 남쪽 들: 첨성대·계림·반월성·향교·교촌·오릉·나정 ──
    G9 = "월성 들(첨성대·계림·반월성)"
    c = lmk(T, "cheomseongdae")
    put(pl, [P("landmark/gj_cheomseongdae", {"seed": 901}, cat="landmark", kind="cheomseongdae", label="첨성대", footprint=[6.0, 6.0])],
        c["x"], c["z"], 0.0, G9, "wol", R=10)
    c = lmk(T, "gyerim")
    put(pl, [P("landmark/gj_gyerim_bigak", {"seed": 902}, cat="landmark", kind="bigak", label="계림", footprint=[10.0, 7.0])],
        c["x"], c["z"] + 14, 0.0, G9, "wol", R=12)
    for k in range(9):
        a = k * 2.399; r_ = 10 + 18 * math.sqrt((k + 1) / 9)
        search(pl, [tree(["zelkova", "broadleaf", "zelkova", "chestnut"][k % 4], 910 + k)], c["x"] + r_ * math.cos(a),
               c["z"] - 6 + r_ * math.sin(a) * 0.8, 20, G9, "wol", 910 + k, {"max_drop": 5.0, "road_min": 1.0}, face="none", n=150)
    c = lmk(T, "banwolseong")
    # 반월성은 남천이 남쪽을 감는다 — 물길이 둔덕 안을 지나지 않게 북쪽으로 물린다(압축 땅에서 생긴 겹침)
    Lb = Local(T, c["x"], c["z"], 200)
    bz = c["z"]
    for dz in range(0, 80, 4):
        if Lb.river_clear(Rect(c["x"], c["z"] - dz, 0.0, [-95, 95, -45, 14]).samples(4.0)).min() > 3.0:
            bz = c["z"] - dz
            break
    pl.log.append(f"[banwolseong] 북쪽으로 {c['z'] - bz:.0f}m")
    put(pl, [P("landmark/gj_banwolseong", {"seed": 903, "length": 190.0, "width": 60.0}, cat="landmark", kind="banwolseong",
               label="반월성 터", flatten=False, footprint=[190.0, 60.0], nocheck=True)], c["x"], bz, 0.0, G9, "wol")
    c = lmk(T, "gyeongju_hyanggyo")
    # 향교: region 점(−2936,−1855)은 남천 물길 위 → 남천 북쪽 둔치(교촌 동쪽, 계림 서쪽)에서 찾는다(가설)
    put(pl, [P("landmark/hyanggyo", {"seed": 904, "width": 34.0, "depth": 42.0}, cat="landmark", kind="hyanggyo", label="경주향교",
               footprint=[36.0, 48.0]), P("reserve", {}, 0.0, 0.0, reserve=True, aabb=[-6.0, 6.0, 24.0, 32.0], nocheck=True)],
        c["x"] + 8, c["z"] - 38, 0.0, "교촌", "gyo", R=45, rules={"max_drop": 4.0, "road_min": 0.6, "river_min": 3.0, "lu_bad": (5, 7)},
        n=900)
    village_c(pl, T, rid, "gyochon", "교촌", "gyo", "yn_ban", 905, road="gyochon_lane", toward=(-2900, -1990),
              center=(stl(T, "gyochon")["x"], stl(T, "gyochon")["z"]), limit=16)
    c = lmk(T, "oreung")
    for k, (dx, dz, r_, h_) in enumerate([(-22, -10, 10, 5.0), (0, -18, 11, 5.5), (20, -6, 9, 4.5), (-8, 12, 8, 4.0), (16, 16, 7, 3.5)]):
        put(pl, [P("landmark/gj_tumulus", {"seed": 920 + k, "radius": float(r_), "height": h_}, cat="landmark", kind="tumulus",
                   label="오릉", flatten=False, footprint=[2 * r_, 2 * r_])], c["x"] + dx, c["z"] + dz, 0.0, "오릉", "oreung", R=10,
            seed=920 + k, rules={"max_drop": 8.0, "lu_bad": (5,), "road_min": 1.0}, force=False)
    search(pl, [P("culture/yeongnam/sadang", {"seed": 926}, cat="civic", kind="sadang", label="숭덕전")], c["x"] + 8, c["z"] + 40, 24,
           "오릉", "oreung", 926, {"max_drop": 3.0}, road_pref=(1.0, 30.0))
    c = lmk(T, "najeong")
    pcs = [P("village/well", {"seed": 931, "roof": False}, cat="landmark", kind="najeong", label="나정"),
           P("landmark/gj_gyerim_bigak", {"seed": 932}, 0.0, -6.0, cat="landmark", kind="bigak", footprint=[10.0, 7.0])]
    put(pl, pcs, c["x"], c["z"], 0.0, "나정", "najeong", R=20, rules={"max_drop": 3.0})
    for k in range(7):
        search(pl, [P("nature/pine", {"seed": 933 + k, "s": 1.2}, cat="prop", kind="pine", aabb=[-0.8, 0.8, -0.8, 0.8], flatten=False,
                      margin=0.4, tree=True)], c["x"], c["z"] - 8, 22, "나정", "najeong", 933 + k, face="none", n=60)

    # ── 10. 분황사(모전석탑) + 황룡사 터(빈 들의 초석) ──
    c = lmk(T, "bunhwangsa")
    pcs = [P("landmark/gj_mojeon_tap", {"seed": 1001}, 0.0, 2.0, cat="landmark", kind="mojeontap", label="분황사 모전석탑",
             footprint=[14.0, 14.0]),
           P("landmark/bogwangjeon", {"seed": 1002}, 0.0, -17.0, cat="landmark", kind="beopdang", label="분황사", nocheck=True)]
    pcs += court(1003, -24.0, 24.0, -25.0, 15.0, [(0.0, 15.0, 3.0)], h=2.0)
    put(pl, pcs, c["x"], c["z"], 0.0, "분황사", "bunhwang", R=20, rules={"max_drop": 3.0, "road_min": 0.5})
    scatter_props(pl, c["x"] + 10, c["z"] + 90, 45, "황룡사 터", "hwangnyong", 1010, "nature/rock",
                  lambda k: {"seed": 1010 + k, "s": 0.9, "mossy": True}, 22, aabb=[-1.0, 1.0, -1.0, 1.0])

    # ── 11. 서천 나루(형산강, §25): 나룻배 + 주막 + 사공 집 + 창고 ──
    c = next(x for x in reg["crossings"] if x["id"] == "seocheon_naru")
    search(pl, jumak_c(1101, "yeongnam"), c["x"] + 22, c["z"] + 4, 40, "서천 나루", "naru", 1101)
    search(pl, yard_culture(1102, YN), c["x"] + 30, c["z"] - 20, 50, "서천 나루", "naru", 1102)
    warehouses(pl, c["x"] + 26, c["z"] + 20, "서천 나루", "naru", 1103, n=2)
    boats(pl, c["x"], c["z"], "서천 나루", "naru", 1110, n=2, R=40)

    # ── 12. 불국사 + 진현(절 아래 마을) + 석굴암 ──
    c = lmk(T, "bulguksa")
    yb = T.height(c["x"], c["z"] + 34)
    put(pl, [P("landmark/gj_bulguksa", {"seed": 1201}, cat="landmark", kind="bulguksa", label="불국사", footprint=[66.0, 62.0]),
             P("reserve", {}, 0.0, 0.0, reserve=True, aabb=[-8.0, 8.0, 31.0, 46.0], nocheck=True)],
        c["x"], c["z"], 0.0, "불국사", "bulguk", rules={"max_drop": 40.0, "road_min": -99, "lu_bad": (5,)})
    pl.items[-1]["y"] = round(yb, 2)
    village_c(pl, T, rid, "bulguksa_village", "진현(불국사 아래)", "jinhyeon", "village", 1210, limit=14,
              street=nearest_road_id(T, stl(T, "bulguksa_village")))
    s_ = stl(T, "bulguksa_village")
    rd_ = nearest_road_id(T, s_)
    if rd_:
        s1, _ = polyline_project(T.road(rd_)["points"], s_["x"], s_["z"])
        E.gate_props(pl, T, Local(T, s_["x"], s_["z"], 120), rd_, s1 + 30, "진현(불국사 아래)", "jinhyeon", random.Random(1211),
                     sotdae=False, kit="village/stone_jangseung", quiet=True)
    search(pl, jumak_c(1212, "yeongnam"), s_["x"] + 20, s_["z"] + 10, 50, "진현(불국사 아래)", "jinhyeon", 1212)
    c = lmk(T, "seokguram")
    put(pl, [P("landmark/gj_seokguram", {"seed": 1220}, cat="landmark", kind="seokguram", label="석굴암", footprint=[22.0, 20.0])],
        c["x"], c["z"], 0.55, "석굴암", "seokgul", R=24, rules={"max_drop": 8.0, "road_min": -99})

    # ── 13. 추령·장항(길목 쉼터) ──
    ps = next(p for p in reg["passes"] if p["id"] == "churyeong")
    seonghwang(pl, ps["x"], ps["z"], "추령", "churyeong", 1301)
    s_ = stl(T, "jangang")
    search(pl, jumak_c(1302, "yeongnam"), s_["x"], s_["z"], 30, "장항 주막", "jangang", 1302)
    search(pl, yard_culture(1303, style(T, rid, "jangang")), s_["x"] + 10, s_["z"] - 10, 40, "장항 주막", "jangang", 1303)
    search(pl, [tree("zelkova", 1304)], s_["x"] - 10, s_["z"] - 8, 30, "장항 주막", "jangang", 1304, face="none")

    # ── 14. 감은사 터·이견대·대왕암·대본 ──
    c = lmk(T, "gameunsa_ji")
    pcs = [P("landmark/seoktap", {"seed": 1401, "height": 13.4}, -11.0, 0.0, cat="landmark", kind="seoktap", label="감은사 터 삼층석탑",
             footprint=[5.0, 5.0]),
           P("landmark/seoktap", {"seed": 1402, "height": 13.4}, 11.0, 0.0, cat="landmark", kind="seoktap", footprint=[5.0, 5.0])]
    put(pl, pcs, c["x"], c["z"], 0.0, "감은사 터", "gameun", R=24, rules={"max_drop": 4.0})
    scatter_props(pl, c["x"], c["z"] - 14, 18, "감은사 터", "gameun", 1405, "nature/rock", lambda k: {"seed": 1405 + k, "s": 0.8},
                  10, aabb=[-0.9, 0.9, -0.9, 0.9])
    c = lmk(T, "igyeondae")
    search(pl, [P("village/cairn", {"seed": 1410, "altar": True}, cat="landmark", kind="igyeondae", label="이견대 터"),
                P("nature/pine", {"seed": 1411, "s": 1.3}, -4.0, -3.0, cat="prop", kind="pine", inner=True, flatten=False)],
           c["x"], c["z"], 25, "대본", "daebon", 1410, {"max_drop": 3.0}, face="none")
    c = lmk(T, "daewangam")
    pl.commit([P("landmark/gj_cheoyongam", {"seed": 1420}, cat="landmark", kind="daewangam", label="대왕암", flatten=False, nocheck=True,
                 y=0.0, clear_veg=False)], c["x"], c["z"], 0.3, "대본", "daebon")
    village_c(pl, T, rid, "daebon", "대본", "daebon", "shore", 1430, road="coast_lane", toward=(3100, 300), limit=12)
    boats(pl, stl(T, "daebon")["x"] + 40, stl(T, "daebon")["z"], "대본", "daebon", 1431, n=3, R=70)

    # ── 15. 감포 포구(§26: 객주·창고·상인) + 처용·연오랑 바위 ──
    s_ = stl(T, "gampo")
    village_c(pl, T, rid, "gampo", "감포 포구", "gampo", "shore", 1501, road="coast_lane", toward=(3500, -1000), limit=18)
    warehouses(pl, s_["x"] + 15, s_["z"], "감포 포구", "gampo", 1502, n=4, R=50)
    search(pl, jumak_c(1503, "yeongnam"), s_["x"], s_["z"] + 20, 50, "감포 포구", "gampo", 1503)
    Lg = Local(T, s_["x"], s_["z"], 140)
    for k in range(4):
        sp = [P("village/jwapan", {"seed": 1504 + k, "goods": "fish"}, cat="market", kind="jwapan", flatten=False, margin=0.6)]
        search(pl, sp, s_["x"] + 10, s_["z"] + 5, 40, "감포 포구", "gampo", 1504 + k, {"max_drop": 2.0})
    boats(pl, s_["x"] + 40, s_["z"], "감포 포구", "gampo", 1510, n=5, R=80)
    for lid, lb in [("cheoyongam_moved", "처용 바위"), ("yeonorang_rock_moved", "연오랑 바위")]:
        c = lmk(T, lid)
        x_, z_ = sea_spot(T, c["x"], c["z"])
        pl.commit([P("landmark/gj_cheoyongam", {"seed": 1520 + len(lid)}, cat="landmark", kind="searock", label=lb, flatten=False,
                     nocheck=True, y=0.0, clear_veg=False)], x_, z_, 0.0, "감포 포구", "gampo")

    # ── 16. 치술령 아래 마을 + 치술령 성황당 + 망부석 ──
    village_c(pl, T, rid, "chisul_village", "치술령 아래 마을", "chisul", "terrace", 1601, road="chisul_trail",
              toward=(-1050, 2764), limit=12, max_drop=4.5)
    ps = next(p for p in reg["passes"] if p["id"] == "chisullyeong")
    seonghwang(pl, ps["x"], ps["z"], "치술령", "chisul", 1602)
    c = lmk(T, "chisullyeong_mangbuseok")
    put(pl, [P("nature/boulder", {"seed": 1603, "s": 3.4, "mossy": True}, cat="landmark", kind="mangbuseok", label="망부석",
               aabb=[-5.0, 5.0, -5.0, 5.0], flatten=False),
             P("village/cairn", {"seed": 1604, "altar": True}, 6.5, 3.0, cat="prop", kind="cairn", flatten=False)],
        c["x"], c["z"], 0.0, "치술령", "chisul", R=20, rules={"max_drop": 6.0, "road_min": -99})

    # ── 17. 들마을(분지 안 몇 곳, 작게) ──
    for sid, sd in [("auto_village_01", 1701), ("auto_village_02", 1702), ("auto_village_04", 1703), ("auto_village_05", 1704),
                    ("auto_village_00", 1705)]:
        village_c(pl, T, rid, sid, f"들마을({sid})", "av", "village", sd, square=True, limit=8)

    # ── 18. 길가 주막(§27: 고개 전후·나루·읍성 밖·갈림길) ──
    for rid_, xz, nm in [("gyeongju_ulsan_road", (-1748, -186), "울산길 고개 아래"), ("gampo_road", (-959, -1710), "감포길 고개 아래")]:
        rp = T.road(rid_)["points"]
        s, _ = polyline_project(rp, *xz)
        x, z, _ = polyline_at(rp, s + 40)
        r = search(pl, jumak_c(1800 + int(s) % 97, "yeongnam"), x, z - 8, 60, "길가 주막", "rd", 1800 + int(s) % 97, {"max_drop": 3.6})
        if r:
            r[0]["_label"] = "주막(" + nm + ")"


def nearest_road_id(T, s):
    best = None
    for rd in T.roads:
        for p in rd["points"]:
            d = math.hypot(p[0] - s["x"], p[1] - s["z"])
            if best is None or d < best[0]:
                best = (d, rd["id"])
    return best[1] if best and best[0] < 80 else None


def sea_spot(T, x, z, R=260):
    """(x,z) 둘레에서 가장 가까운 바닷가 물 칸(물 가장자리 3~10m 안)."""
    best = None
    for r in range(0, int(R), 4):
        for k in range(max(8, r // 2)):
            a = k / max(8, r // 2) * 2 * math.pi
            px, pz = x + r * math.cos(a), z + r * math.sin(a)
            if T.landuse(px, pz) == 5 and T.height(px, pz) < -0.3:
                if any(T.landuse(px + dx, pz + dz) != 5 for dx, dz in [(10, 0), (-10, 0), (0, 10), (0, -10)]):
                    return px, pz
                if best is None:
                    best = (px, pz)
    return best or (x, z)


# ================================================================ 강릉
def build_gangneung(pl, T):
    rid = "GW_GANGNEUNG"
    reg = T.region
    bridges(pl, T)
    GD = style(T, rid, "gangneung_eup")
    G, GC = "강릉 읍내", "eup"

    # ── 1. 객사 임영관(삼문 국보) — 관동대로·여러 길이 모이는 읍내 한가운데, 남향 ──
    c = lmk(T, "imyeonggwan")
    pl.commit([P("landmark/gn_imyeonggwan", {"seed": 11}, cat="civic", kind="imyeonggwan", label="임영관", footprint=[54.0, 46.0],
                 nocheck=True, flatten=True),
               P("reserve", {}, 0.0, 0.0, reserve=True, aabb=[-27.0, 27.0, -23.0, 23.0]),
               P("reserve", {}, 0.0, 0.0, reserve=True, aabb=[-8.0, 8.0, 23.0, 32.0])], c["x"], c["z"], 0.0, "객사 임영관", "gaeksa")
    # ── 2. 관아(칠사당·동헌) — 객사 동북 곁 ──
    c = lmk(T, "gangneung_gwana")
    pl.commit([P("landmark/gn_gwana", {"seed": 21}, cat="civic", kind="gwana", label="강릉대도호부 관아", footprint=[46.0, 46.0],
                 nocheck=True),
               P("reserve", {}, 0.0, 0.0, reserve=True, aabb=[-23.0, 23.0, -23.0, 23.0])], c["x"], c["z"], 0.0, "강릉대도호부 관아",
              "gwana")
    # ── 3. 향교 ──
    c = lmk(T, "gangneung_hyanggyo")
    put(pl, [P("landmark/hyanggyo", {"seed": 31, "width": 40.0, "depth": 50.0}, cat="landmark", kind="hyanggyo", label="강릉향교",
               footprint=[42.0, 56.0]), P("reserve", {}, 0.0, 0.0, reserve=True, aabb=[-6.0, 6.0, 28.0, 36.0], nocheck=True)],
        c["x"], c["z"], 0.0, "강릉향교", "hyanggyo", R=40, rules={"max_drop": 4.5, "road_min": 0.6})

    # ── 4. 읍내 민가(길촌: 길 따라 반가·잿빛 초가) ──
    s_ = stl(T, "gangneung_eup")
    b = s_["bbox"]
    cells = rect_cells(T, b[0], b[1], b[2], b[3], lu=(6,))
    Lt = Local(T, s_["x"], s_["z"], 220)
    for k, rid_ in enumerate(["gwandong_daero", "gyeongpo_road", "north_coast_road", "hyanggyo_lane", "anmok_road", "haksan_road"]):
        rd = T.road(rid_)
        EV.street_rows(pl, T, Lt, cells, rd["points"], rd["width_m"], G, GC, "gd_eup", 410 + k * 11, GD, stats=pl.stats_,
                       max_drop=2.6, in_frac=0.35)
    for k, rid_ in enumerate(["gwandong_daero", "gyeongpo_road", "north_coast_road", "hyanggyo_lane", "anmok_road", "haksan_road"]):
        rd = T.road(rid_)
        EV.street_rows(pl, T, Lt, cells, rd["points"], rd["width_m"], G, GC, "front", 420 + k * 11, GD, stats=pl.stats_,
                       max_drop=2.6, in_frac=0.0)
    EV.fill_rows(pl, T, Lt, cells, G, GC, "gd_eup", 430, pitch=18.0, in_frac=0.5, stats=pl.stats_, style=GD,
                 zone=(1230, -470, 60.0, "gd_ban"))
    EV.fill_rows(pl, T, Lt, cells, G, GC, "gd_eup", 431, pitch=18.0, in_frac=0.5, stats=pl.stats_, style=GD, phase=9.0)
    small_fill(pl, T, Lt, cells, ["gwandong_daero", "gyeongpo_road", "north_coast_road", "hyanggyo_lane", "anmok_road", "haksan_road"],
               G, GC, 435, GD)
    for k, (wx, wz) in enumerate([(1160, -470), (1280, -420), (1150, -390)]):
        search(pl, [P("village/well", {"seed": 440 + k, "roof": k % 2 == 0}, cat="prop", kind="well", margin=1.0)], wx, wz, 30, G, GC,
               440 + k, face="none")
    # 홍살문 대신: 관동대로 읍내 들머리 장승·솟대(강릉 솟대) + 정자나무
    for rid_, tw in [("gwandong_daero", (1000, -300)), ("north_coast_road", (1220, -600)), ("gyeongpo_road", (1000, -640))]:
        e = E.entrance(T, rid_, s_["x"], s_["z"], 125, tw)
        if e:
            gate_c(pl, T, rid_, e[1], G, GC, 450 + len(rid_), "gwandong")

    # ── 5. 남대천 단오장(장시) + 굿당 + 나루 주막 ──
    js = stl(T, "gangneung_jang")
    Lm = Local(T, js["x"], js["z"], 160)
    ar = T.road("anmok_road")["points"]
    s0, _ = polyline_project(ar, 1250, -412)
    E.market(pl, T, Lm, "anmok_road", s0, s0 + 85, "강릉 장(단오장)", "jang", random.Random(501), shops=6, jwapan=16)
    jc = EV.cells_of(T, js, reg["settlements"])
    EV.fill_rows(pl, T, Lm, jc, "강릉 장(단오장)", "jang", "market", 502, pitch=8.5, gap=(1.0, 2.0), max_drop=1.8, limit=18,
                 stats=pl.stats_)
    seonghwang(pl, js["x"] + 10, js["z"] + 20, "강릉 장(단오장)", "jang", 503, R=40, dangjip=True)
    c = next(x for x in reg["crossings"] if x["id"] == "x_anmok_road_namdaecheon_10")
    search(pl, jumak_c(504, "gwandong"), c["x"] - 22, c["z"] - 8, 40, "강릉 장(단오장)", "jang", 504)
    search(pl, jumak_c(505, "gwandong"), 1110, -385, 40, G, GC, 505)                 # 관동대로 읍내 밖

    # ── 6. 제의 시설(가설): 사직단 서·여단 북·성황사(대성황사) 서쪽 기슭 ──
    ritual(pl, T, "landmark/sajikdan", {"seed": 601, "dual": False}, [25.0, 25.0], 990, -470, "읍치 제의 시설", "rit", 601, "강릉 사직단")
    ritual(pl, T, "landmark/yeodan", {"seed": 602}, [19.0, 19.0], 1180, -700, "읍치 제의 시설", "rit", 602, "강릉 여단")
    ritual(pl, T, "landmark/seonghwangsa", {"seed": 603, "tree_stub": True}, [20.0, 18.0], 1060, -380, "읍치 제의 시설", "rit", 603,
           "강릉 대성황사")

    # ── 7. 경포: 오죽헌·선교장·경포대·홍장암·경포 마을 ──
    c = lmk(T, "ojukheon")
    put(pl, [P("landmark/gn_ojukheon", {"seed": 701}, cat="landmark", kind="ojukheon", label="오죽헌", footprint=[13.0, 16.0])],
        c["x"], c["z"], 0.0, "오죽헌", "ojuk", R=20)
    put(pl, [P("culture/gwandong/compound", {"seed": 702, "size": "large"}, cat="house", kind="banga", label="오죽헌 안채",
               footprint=[26.0, 22.0])], c["x"] + 26, c["z"] + 2, 0.0, "오죽헌", "ojuk", R=20, force=False)
    for k in range(5):
        search(pl, [P("nature/bamboo", {"seed": 703 + k, "n": 12, "r": 1.8, "h": 7.0}, cat="prop", kind="bamboo",
                      aabb=[-2.0, 2.0, -2.0, 2.0], flatten=False, margin=0.3)], c["x"] - 4, c["z"] - 16, 18, "오죽헌", "ojuk", 703 + k,
               face="none", n=80)
    c = lmk(T, "seongyojang")
    pcs = [P("culture/gwandong/banga", {"seed": 711}, 0.0, -6.0, cat="house", kind="banga", label="선교장", footprint=[23.1, 18.0]),
           P("culture/gwandong/banga", {"seed": 712, "haengrang": False, "bays": "wdmmd"}, 20.0, -14.0, cat="house", kind="banga_byeol",
             footprint=[17.0, 10.2]),
           P("village/jeongja", {"seed": 713}, -24.0, 12.0, cat="landmark", kind="hwallaejeong", label="활래정")]
    put(pl, pcs, c["x"], c["z"], 0.0, "선교장", "seongyo", R=30, rules={"max_drop": 3.5})
    c = lmk(T, "gyeongpodae")
    put(pl, [P("landmark/gn_gyeongpodae", {"seed": 721}, cat="landmark", kind="gyeongpodae", label="경포대", footprint=[18.6, 14.0])],
        c["x"], c["z"], 0.0, "경포대", "gyeongpo", R=30, rules={"max_drop": 4.0})
    for k in range(8):
        search(pl, [P("nature/pine", {"seed": 722 + k, "s": 1.2}, cat="prop", kind="pine", aabb=[-0.8, 0.8, -0.8, 0.8], flatten=False,
                      margin=0.4, tree=True)], c["x"], c["z"] - 6, 30, "경포대", "gyeongpo", 722 + k, face="none", n=60)
    c = lmk(T, "hongjangam")
    pl.commit([P("nature/boulder", {"seed": 731, "s": 2.4, "mossy": False}, cat="landmark", kind="hongjangam", label="홍장암",
                 flatten=False, nocheck=True, clear_veg=False, y=-0.6)], c["x"], c["z"], 0.0, "경포대", "gyeongpo")
    village_c(pl, T, rid, "gyeongpo_village", "경포 마을", "gpv", "gd_ban", 740, road="gyeongpo_road", toward=(980, -1400), limit=18)

    # ── 8. 안목 갯마을 + 헌화 벼랑(수로부인) ──
    s_ = stl(T, "anmok_village")
    village_c(pl, T, rid, "anmok_village", "안목 갯마을", "anmok", "shore", 801, road="anmok_road", toward=(2212, -1042), limit=14)
    boats(pl, s_["x"] + 30, s_["z"], "안목 갯마을", "anmok", 802, n=4, R=90)
    c = lmk(T, "heonhwa_cliff")
    pcs = [P("nature/cliff", {"seed": 811, "w": 9, "h": 8, "d": 4}, cat="landmark", kind="heonhwa", label="헌화 벼랑",
             aabb=[-5.0, 5.0, -2.6, 2.6], flatten=False),
           P("nature/cliff", {"seed": 812, "w": 7, "h": 6, "d": 3}, 8.0, 1.0, 0.3, cat="landmark", kind="cliff", aabb=[-4.0, 4.0, -2.0, 2.0],
             flatten=False)]
    put(pl, pcs, c["x"], c["z"], 0.0, "헌화 벼랑", "heonhwa", R=30, rules={"max_drop": 9.0, "road_min": -99})
    for k in range(7):
        search(pl, [P("nature/azalea", {"seed": 820 + k, "kind": "cheoljjuk", "bloom": True}, cat="prop", kind="azalea",
                      aabb=[-0.9, 0.9, -0.7, 0.7], flatten=False, margin=0.2)], c["x"], c["z"] + 2, 14, "헌화 벼랑", "heonhwa", 820 + k,
               {"max_drop": 9.0}, face="none", n=60)

    # ── 9. 학산(범일국사) + 굴산사지 당간지주 ──
    s_ = stl(T, "haksan")
    village_c(pl, T, rid, "haksan", "학산 마을", "haksan", "village", 901, road="haksan_road", toward=(1206, -203),
              center=(s_["x"], s_["z"]), limit=16)
    c = lmk(T, "gulsansa_dangganjiju")
    put(pl, [P("landmark/gn_dangganjiju", {"seed": 911, "budo": True}, cat="landmark", kind="dangganjiju", label="굴산사 터 당간지주",
               footprint=[10.0, 8.0])], c["x"], c["z"], 0.0, "굴산사 터", "gulsan", R=20, rules={"max_drop": 3.0, "lu_bad": (5,)})
    search(pl, [P("village/well", {"seed": 912, "roof": False}, cat="landmark", kind="seokcheon", label="석천", margin=1.0)],
           s_["x"] + 10, s_["z"] - 15, 40, "학산 마을", "haksan", 912, face="none")

    # ── 10. 구산역(역참 + 마방 + 주막) + 나루 ──
    s_ = stl(T, "gusan_yeok")
    search(pl, yeok_gusan(1001), s_["x"], s_["z"], 110, "구산역", "gusan", 1001, {"max_drop": 4.5}, n=900, road_pref=(1.0, 20.0), ry=0.0)
    search(pl, jumak_c(1002, "gwandong_mt"), s_["x"] + 30, s_["z"], 50, "구산역", "gusan", 1002)
    search(pl, jumak_c(1003, "gwandong"), s_["x"] - 30, s_["z"] + 10, 50, "구산역", "gusan", 1003)
    gst = style(T, rid, "gusan_yeok")
    for k in range(4):
        search(pl, yard_culture(1010 + k, gst), s_["x"] + (k - 1.5) * 25, s_["z"] - 25, 90, "구산역", "gusan", 1010 + k, {"max_drop": 4.0})
    c = next(x for x in reg["crossings"] if x["id"] == "x_gwandong_d_namdaecheon_0")
    search(pl, [P("village/choga", {"seed": 1020}, cat="house", kind="sagong", label="사공 집")], c["x"] + 20, c["z"] - 14, 40,
           "구산 나루", "gnaru", 1020)
    warehouses(pl, c["x"] - 20, c["z"] - 14, "구산 나루", "gnaru", 1021, n=1)

    # ── 11. 반정 주막·대관령 성황당·국사성황사 ──
    s_ = stl(T, "banjeong_jumak")
    search(pl, jumak_c(1101, "gwandong_mt"), s_["x"], s_["z"], 40, "반정", "banjeong", 1101, {"max_drop": 4.0})
    seonghwang(pl, s_["x"] + 10, s_["z"] - 10, "반정", "banjeong", 1102, R=40, rules={"max_drop": 4.0})
    ps = next(p for p in reg["passes"] if p["id"] == "daegwallyeong")
    seonghwang(pl, ps["x"], ps["z"], "대관령", "daegwal", 1103, R=40, rules={"max_drop": 4.5})
    c = lmk(T, "daegwallyeong_seonghwangsa")
    put(pl, [P("landmark/gn_guksa_seonghwangdang", {"seed": 1104}, cat="landmark", kind="guksa", label="대관령 국사성황사",
               footprint=[17.0, 10.0])], c["x"], c["z"], 0.0, "대관령 국사성황사", "guksa", R=40, rules={"max_drop": 5.0})

    # ── 12. 들마을·산촌 ──
    for sid, sd, mx in [("auto_village_00", 1201, "village"), ("auto_village_02", 1202, "village"), ("auto_village_04", 1203, "village"),
                        ("auto_village_03", 1204, "village")]:
        village_c(pl, T, rid, sid, f"들마을({sid})", "av", mx, sd, limit=8)


def yeok_gusan(seed):
    """구산역(가설): 역사(기와 一자 채) + 마방 둘 + 헛간 + 대문 + 돌담. 원점 = 마당, 정면 +z."""
    pcs = [P("culture/chae", {"seed": seed, "l": 9.6, "d": 4.6, "bays": "wdmdw", "roof": "giwa", "wall": "plaster", "F": 0.6, "maru": 0.6},
             0.0, -5.0, cat="civic", kind="yeoksa", label="구산역"),
           P("village/oeyanggan", {"seed": seed}, -9.0, -5.0, cat="house", kind="mabang", label="마방"),
           P("village/oeyanggan", {"seed": seed + 1}, -9.0, 0.5, cat="house", kind="mabang"),
           P("village/heotgan", {"seed": seed}, 9.0, -4.5, cat="house", kind="heotgan"),
           P("village/daemun", {"seed": seed, "style": "tile"}, 0.0, 6.5, cat="civic", kind="daemun"),
           P("village/torch_post", {"seed": seed}, 2.6, 8.4, cat="prop", kind="torch", flatten=False, margin=0.2)]
    pcs.append(P("reserve", {}, reserve=True, aabb=[-12.5, 12.5, -11.8, 9.0]))
    pcs.append(P("reserve", {}, reserve=True, aabb=[-4.0, 4.0, 9.0, 16.0], nocheck=True))
    pts = [[-2.2, 6.5], [-12.5, 6.5], [-12.5, -11.8], [12.5, -11.8], [12.5, 6.5], [2.2, 6.5]]
    pcs.append(P("village/wall_run", {"seed": seed, "kind": "stone_lite", "points": pts}, cat="wall", kind="wall_run",
                 aabb=[-12.9, 12.9, -12.2, 6.9], flatten=False, inner=True))
    return pcs


# ================================================================ 제주
def build_jeju(pl, T):
    rid = "JJ_JEJU"
    reg = T.region
    bridges(pl, T)
    CX, CZ, HX, HZ = -2994.0, -146.0, 140.0, 115.0
    WT = 3.0
    G, GC = "제주목 읍내", "eup"
    TN = style(T, rid, "jeju_mok")

    # ── 1. 제주성(현무암, 남·동·서 3문 — 북쪽은 바다) + 성문 돌하르방 ──
    names = {"S": "정원루", "E": "제중루", "W": "진서루"}
    eupseong(pl, T, CX, CZ, HX, HZ, names, "landmark/jj_eupseong_wall", WT,
             lambda sd, nm: ("landmark/seongmun", {"seed": 11 + "SENW".index(sd), "name": nm, "open": "none", "lu": 1, "width": 14.0,
                                                   "depth": 4.0}),
             "제주성", "seong", 1100, corner=False, chi=False, gate_w=14.0)
    side = {"S": (0.0, HZ), "E": (math.pi / 2, HX), "W": (-math.pi / 2, HX)}
    for sd, (ry, half_o) in side.items():
        for k, u in enumerate((-4.6, 4.6)):
            x, z = l2w(CX, CZ, ry, u, half_o + 3.0)
            pl.commit([P("landmark/jj_dolhareubang", {"seed": 30 + k + "SEW".index(sd) * 2, "hand": "right" if k else "left"},
                         cat="landmark", kind="dolhareubang", label="돌하르방", flatten=False, nocheck=True)], x, z, ry, "제주성", "seong")

    # ── 2. 관덕정(앞 광장) + 목관아(뒤) ──
    c = lmk(T, "gwandeokjeong")
    gx, gz = c["x"] + 5.0, -164.0
    pl.commit([P("landmark/jj_gwandeokjeong", {"seed": 41}, cat="civic", kind="gwandeokjeong", label="관덕정", footprint=[24.2, 24.0],
                 nocheck=True),
               P("reserve", {}, 0.0, 0.0, reserve=True, aabb=[-16.0, 16.0, 12.0, 24.0])], gx, gz, 0.0, "관덕정", "gwandeok")
    pl.commit([P("landmark/jj_mokgwana", {"seed": 42}, cat="civic", kind="mokgwana", label="제주목 관아", footprint=[50.0, 62.0],
                 nocheck=True),
               P("reserve", {}, 0.0, 0.0, reserve=True, aabb=[-25.0, 25.0, -31.0, 31.0])], gx, gz - 12.0 - 33.0, 0.0, "제주목 관아",
              "mokgwana")
    # ── 3. 객사 영주관(가설: 남북길 축 끝 북쪽) ──
    kx, kz1 = -3004.0, -152.0
    pcs = [P("landmark/gaeksa", {"seed": 51, "jeongdang_bays": 3, "wing_bays": 3, "name": "영주관"}, 0.0, -22.0, cat="civic", kind="gaeksa",
             label="영주관", nocheck=True),
           P("landmark/samun", {"seed": 52, "kind": "outer", "name": "영주관"}, 0.0, 0.0, cat="civic", kind="samun", nocheck=True)]
    pcs += [P("landmark/jj_basalt_wall", {"seed": 53, "w": 56.0, "d": 40.0, "height": 2.0, "gates": [[0.0, 20.0, 3.4]]}, 0.0, -20.0,
              cat="wall", kind="basalt_wall", flatten=False, nocheck=True, inner=True),
            P("reserve", {}, reserve=True, aabb=[-28.0, 28.0, -40.0, 0.0])]
    pl.commit(pcs, kx, kz1, 0.0, "객사 영주관", "gaeksa")

    # ── 4. 성 안 민가: 낮은 돌집 + 올레, 관속 기와 몇 채 ──
    inner = (CX - HX + WT + 1.0, CZ - HZ + WT + 1.0, CX + HX - WT - 1.0, CZ + HZ - WT - 1.0)
    cells_in = rect_cells(T, *inner, lu=(6, 1, 3))
    Lin = Local(T, CX, CZ, 200)
    for k, rid_ in enumerate(["jeju_eup_street_ew", "jeju_eup_street_ns"]):
        rd = T.road(rid_)
        EV.street_rows(pl, T, Lin, cells_in, rd["points"], rd["width_m"], G + "(성 안)", GC, "tn_eup", 410 + k * 7, TN,
                       stats=pl.stats_, max_drop=2.4, in_frac=0.3)
    EV.fill_rows(pl, T, Lin, cells_in, G + "(성 안)", GC, "tn_eup", 420, pitch=23.0, ry=0.0, in_frac=0.4, stats=pl.stats_, style=TN)
    EV.fill_rows(pl, T, Lin, cells_in, G + "(성 안)", GC, "tn_eup", 421, pitch=23.0, ry=0.0, in_frac=0.4, stats=pl.stats_, style=TN,
                 phase=11.5, gap=(1.2, 2.4))
    small_fill(pl, T, Lin, cells_in, ["jeju_eup_street_ew", "jeju_eup_street_ns"], G + "(성 안)", GC, 425, TN, ry=0.0)
    # 장: 동문 안 산지천 가(제주 장)
    js = stl(T, "jeju_jang")
    Lm = Local(T, js["x"], js["z"], 120)
    er = T.road("jeju_eup_street_ew")["points"]
    s0, _ = polyline_project(er, -2945, -136)
    E.market(pl, T, Lm, "jeju_eup_street_ew", s0, s0 + 70, "제주 장", "jang", random.Random(501), shops=4, jwapan=14,
             goods=["fish", "mixed", "cloth", "onggi", "grain", "fish"])
    # 성 안 우물(가설: 성 안 물은 산지천·가락쿳물) → 용천수 물통 하나
    search(pl, mulbtong(460), -2945, -200, 30, G, GC, 460, {"max_drop": 2.0, "river_min": 0.5}, face="none")

    # ── 5. 성 밖: 남문 밖 삼성혈, 동문 밖 산지포, 서쪽 향교 ──
    c = lmk(T, "samseonghyeol")
    put(pl, [P("landmark/jj_samseonghyeol", {"seed": 501}, cat="landmark", kind="samseonghyeol", label="삼성혈", footprint=[25.0, 24.0])],
        c["x"], c["z"], 0.0, "삼성혈", "samseong", R=12)
    for k in range(10):
        a = k * 2.399; r_ = 16 + 10 * math.sqrt((k + 1) / 10)
        search(pl, [P("nature/pine", {"seed": 510 + k, "s": 1.3}, cat="prop", kind="pine", aabb=[-0.8, 0.8, -0.8, 0.8], flatten=False,
                      margin=0.4, tree=True)], c["x"] + r_ * math.cos(a), c["z"] + r_ * math.sin(a), 6, "삼성혈", "samseong", 510 + k,
               face="none", n=40)
    search(pl, [P("landmark/hyanggyo", {"seed": 520, "width": 36.0, "depth": 46.0}, cat="landmark", kind="hyanggyo", label="제주향교",
                  footprint=[38.0, 52.0])], -3250, -70, 70, "제주향교", "hyanggyo", 520, {"max_drop": 4.0}, ry=0.0, road_pref=(1.0, 50.0))
    s_ = stl(T, "jeju_mok")
    b = s_["bbox"]
    cells_out = rect_cells(T, b[0], b[1], b[2], b[3], lu=(6,))
    m = ~((np.abs(cells_out[:, 0] - CX) < HX + 10) & (np.abs(cells_out[:, 1] - CZ) < HZ + 10))
    cells_out = cells_out[m]
    Lo = Local(T, CX, CZ, 260)
    for k, rid_ in enumerate(["jeju_south_gate_lane", "jeju_east_coast_road", "jeju_west_coast_road", "sanjipo_lane"]):
        rd = T.road(rid_)
        EV.street_rows(pl, T, Lo, cells_out, rd["points"], rd["width_m"], G + "(성 밖)", GC, "tn_village", 530 + k * 11, TN,
                       stats=pl.stats_, max_drop=2.4, in_frac=0.35)
    for k, rid_ in enumerate(["jeju_south_gate_lane", "jeju_east_coast_road", "jeju_west_coast_road", "sanjipo_lane"]):
        rd = T.road(rid_)
        EV.street_rows(pl, T, Lo, cells_out, rd["points"], rd["width_m"], G + "(성 밖)", GC, "front", 540 + k * 11, TN,
                       stats=pl.stats_, max_drop=2.4, in_frac=0.0)
    EV.fill_rows(pl, T, Lo, cells_out, G + "(성 밖)", GC, "tn_village", 550, pitch=23.0, in_frac=0.5, stats=pl.stats_, style=TN)
    small_fill(pl, T, Lo, cells_out, ["jeju_south_gate_lane", "jeju_east_coast_road", "jeju_west_coast_road", "sanjipo_lane"],
               G + "(성 밖)", GC, 555, TN)
    search(pl, jumak_c(560, "tamna"), CX + HX + 26, CZ + 12, 30, G + "(성 밖)", GC, 560, road_pref=(1.0, 6.0))

    # ── 6. 산지포(포구: 객주·창고) + 산지물 ──
    s_ = stl(T, "sanji_po")
    sp = next(x for x in reg["springs"] if x["id"] == "spring_sanjimul")
    search(pl, mulbtong(601), sp["x"], sp["z"], 20, "산지포", "sanji", 601, {"max_drop": 2.0, "river_min": 0.0}, face="none")
    village_c(pl, T, rid, "sanji_po", "산지포", "sanji", "shore", 602, road="sanjipo_lane", toward=(-2840, -299), limit=10)
    warehouses(pl, s_["x"] + 6, s_["z"] + 10, "산지포", "sanji", 603, n=3, cul="tamna")
    search(pl, jumak_c(604, "tamna"), s_["x"] - 4, s_["z"] + 30, 30, "산지포", "sanji", 604)
    boats(pl, s_["x"], s_["z"] - 20, "산지포", "sanji", 605, n=4, R=70)

    # ── 7. 제의 시설(가설): 사직단 서·여단(북은 바다 → 동북 바닷가 언덕)·성황사(남쪽 기슭) ──
    ritual(pl, T, "landmark/sajikdan", {"seed": 701, "dual": False}, [25.0, 25.0], -3230, 40, "읍치 제의 시설", "rit", 701, "제주 사직단")
    ritual(pl, T, "landmark/yeodan", {"seed": 702}, [19.0, 19.0], -2780, -60, "읍치 제의 시설", "rit", 702, "제주 여단")
    ritual(pl, T, "landmark/seonghwangsa", {"seed": 703, "tree_stub": True}, [20.0, 18.0], -3060, 110, "읍치 제의 시설", "rit", 703,
           "제주 성황사")

    # ── 8. 화북포(뱃길 관문): 화북진 돌성 + 해신사 + 객주 + 배 ──
    s_ = stl(T, "hwabuk_po")
    c = lmk(T, "hwabuk_haesinsa")
    put(pl, [P("landmark/seonghwangsa", {"seed": 801, "tree_stub": False}, cat="landmark", kind="haesinsa", label="화북포 해신사",
               footprint=[20.0, 18.0])], c["x"], c["z"], 0.0, "화북포", "hwabuk", R=30, rules={"max_drop": 3.0})
    search(pl, [P("landmark/jj_basalt_wall", {"seed": 802, "w": 44.0, "d": 30.0, "height": 2.8, "gates": [[0.0, 15.0, 2.6], [22.0, 0.0, 2.6]]},
                  cat="landmark", kind="hwabukjin", label="화북진", flatten=True, footprint=[45.0, 31.0]),
                P("culture/chae", {"seed": 803, "l": 9.6, "d": 4.6, "bays": "wdmdw", "roof": "giwa", "wall": "basalt", "F": 0.5},
                  0.0, -6.0, cat="civic", kind="jinsa", inner=True)],
           s_["x"] + 40, s_["z"] - 10, 50, "화북포", "hwabuk", 804, {"max_drop": 3.0}, ry=0.0, road_pref=(1.0, 20.0))
    village_c(pl, T, rid, "hwabuk_po", "화북포", "hwabuk", "shore", 805, road="jeju_east_coast_road", toward=(-2214, -200), limit=16)
    warehouses(pl, s_["x"], s_["z"] - 10, "화북포", "hwabuk", 806, n=3, cul="tamna")
    search(pl, jumak_c(807, "tamna"), s_["x"] - 20, s_["z"] + 10, 40, "화북포", "hwabuk", 807)
    boats(pl, s_["x"], s_["z"] - 40, "화북포", "hwabuk", 808, n=5, R=90)
    sp = next(x for x in reg["springs"] if x["id"] == "spring_hwabuk_po")
    search(pl, mulbtong(809), sp["x"], sp["z"], 25, "화북포", "hwabuk", 809, {"max_drop": 2.0, "river_min": 0.0}, face="none")

    # ── 9. 조천(길목 쉼터): 연북정 + 용천수 물통 + 해녀 마을 ──
    s_ = stl(T, "jocheon")
    c = lmk(T, "yeonbukjeong")
    put(pl, [P("landmark/jj_yeonbukjeong", {"seed": 901}, cat="landmark", kind="yeonbukjeong", label="연북정", footprint=[18.0, 14.0])],
        c["x"], c["z"], 0.0, "조천", "jocheon", R=30, rules={"max_drop": 3.0, "lu_bad": (7,), "road_min": 0.3})
    for k, sid_ in enumerate(["spring_jocheon_named", "spring_jocheon"]):
        sp = next(x for x in reg["springs"] if x["id"] == sid_)
        search(pl, mulbtong(910 + k * 5), sp["x"], sp["z"], 25, "조천", "jocheon", 910 + k * 5, {"max_drop": 2.0, "river_min": 0.0},
               face="none")
    village_c(pl, T, rid, "jocheon", "조천", "jocheon", "tn_village", 920, road="jeju_east_coast_road", toward=(-560, -706), limit=16)
    search(pl, jumak_c(921, "tamna"), s_["x"] + 10, s_["z"] + 20, 40, "조천", "jocheon", 921)
    search(pl, bulteok(922), s_["x"] + 30, s_["z"] - 50, 60, "조천", "jocheon", 922, {"max_drop": 2.5, "lu_bad": (5,), "road_min": 0.5},
           face="none")
    boats(pl, s_["x"], s_["z"] - 60, "조천", "jocheon", 923, n=3, R=90)

    # ── 10. 송당(본향당) ──
    s_ = stl(T, "songdang")
    village_c(pl, T, rid, "songdang", "송당", "songdang", "tn_village", 1001, road="jungsangan_road", toward=(3000, 900), limit=14)
    c = lmk(T, "songdang_bonhyangdang")
    pcs = [P("nature/big_tree", {"seed": 1002, "variant": "broadleaf", "h": 9.0, "spread": 6.0}, 0.0, -2.0, cat="landmark", kind="sinmok",
             label="송당 본향당", aabb=[-1.4, 1.4, -1.4, 1.4], flatten=False),
           P("landmark/jj_basalt_wall", {"seed": 1003, "w": 14.0, "d": 11.0, "height": 1.2, "gates": [[0.0, 5.5, 1.4]]}, 0.0, 0.0,
             cat="wall", kind="dangdam", inner=True, flatten=False),
           P("village/cairn", {"seed": 1004, "altar": True}, 0.0, 1.0, cat="prop", kind="jedan", inner=True, flatten=False)]
    put(pl, pcs, c["x"], c["z"], 0.0, "송당 본향당", "bonhyang", R=30, rules={"max_drop": 4.0})
    # 중산간 목장: 잣성(긴 돌담) 몇 줄
    for k in range(4):
        x0 = s_["x"] - 160 + k * 70
        pts = [[0.0, 0.0], [18.0, 1.5], [36.0, -1.0], [54.0, 2.0]]
        search(pl, [P("culture/tamna/doldam", {"seed": 1010 + k, "points": pts, "h": 1.2, "lite": True}, -27.0, 0.0, cat="wall",
                      kind="jatseong", aabb=[-27.5, 27.5, -1.5, 2.5], flatten=False, margin=0.4)], x0, s_["z"] + 120, 50,
               "송당 목장", "mokjang", 1010 + k, {"max_drop": 6.0}, face="none", n=80)

    # ── 11. 김녕(해녀 마을) + 김녕사굴 ──
    s_ = stl(T, "gimnyeong")
    village_c(pl, T, rid, "gimnyeong", "김녕", "gimnyeong", "tn_village", 1101, road="jeju_east_coast_road", toward=(2777, -1449),
              limit=16)
    sp = next(x for x in reg["springs"] if x["id"] == "spring_gimnyeong")
    search(pl, mulbtong(1102), sp["x"], sp["z"], 25, "김녕", "gimnyeong", 1102, {"max_drop": 2.0, "river_min": 0.0}, face="none")
    search(pl, bulteok(1103), s_["x"], s_["z"] - 60, 70, "김녕", "gimnyeong", 1103, {"max_drop": 2.5, "lu_bad": (5,), "road_min": 0.5},
           face="none")
    boats(pl, s_["x"], s_["z"] - 70, "김녕", "gimnyeong", 1104, n=3, R=100)
    c = lmk(T, "gimnyeong_sagul")
    put(pl, [P("landmark/jj_gimnyeongsagul", {"seed": 1110}, cat="landmark", kind="sagul", label="김녕사굴", footprint=[17.0, 14.0])],
        c["x"], c["z"], 0.0, "김녕사굴", "sagul", R=30, rules={"max_drop": 4.0})

    # ── 12. 용천수 마을 후보(작게): 돌집 + 물통 + 불턱 ──
    for sid, sd in [("auto_village_00", 1201), ("auto_village_01", 1202), ("auto_village_03", 1203), ("auto_village_05", 1204),
                    ("auto_village_02", 1205), ("auto_village_04", 1206)]:
        s_ = stl(T, sid)
        village_c(pl, T, rid, sid, f"용천수 마을({sid})", "av", "tn_village", sd, limit=7, square=False)
        spid = "spring_" + sid
        sp = next((x for x in reg["springs"] if x["id"] == spid), None)
        if sp:
            search(pl, mulbtong(sd + 50), sp["x"], sp["z"], 25, f"용천수 마을({sid})", "av", sd + 50, {"max_drop": 2.0, "river_min": 0.0},
                   face="none")
        search(pl, bulteok(sd + 60), s_["x"], s_["z"] - 40, 60, f"용천수 마을({sid})", "av", sd + 60,
               {"max_drop": 2.5, "lu_bad": (5,), "road_min": 0.5}, face="none")


BUILDERS = {"GS_GYEONGJU": build_gyeongju, "GW_GANGNEUNG": build_gangneung, "JJ_JEJU": build_jeju}


# ================================================================ 실행
def load_catalog_fp():
    fp = E.load_catalog_fp()
    try:
        c = json.load(open(os.path.join(ROOT, "kit/culture/catalog.json"), encoding="utf-8"))
        for it in c.get("models", []):
            if it.get("footprint"):
                fp["culture/" + it["name"]] = tuple(it["footprint"])
    except Exception:
        pass
    return fp


def fix_roads(rid):
    """후속 수정: region.json 길 고치기(되풀이해도 같은 결과). data-east가 region.json을 다시 빌드해도 hubs.py를 돌리면 다시 맞춰진다.
    - 강릉: 관동대로·경포길·북쪽 해안길·향교길이 임영관 한가운데 점에서 출발해 일곽 마당을 지났다 → 삼문 앞 길(z≈−412)에서 시작.
    - 경주: 북문길(성 안)이 동경관 뒤 22m(z −2292.5)에서 꺾여 객사 앞마당이 4~6m였다 → 북문 안 순성로 바로 안(z −2318.5)에서 꺾는다."""
    path = os.path.join(ROOT, "region_data", rid, "region.json")
    r = json.load(open(path, encoding="utf-8"))
    rd = {x["id"]: x for x in r["roads"]}
    changed = []

    def setp(rid_, pts):
        if rid_ in rd and rd[rid_]["points"] != pts:
            rd[rid_]["points"] = pts
            changed.append(rid_)
    if rid == "GW_GANGNEUNG":
        p = rd["gwandong_daero"]["points"]
        if p[0] == [1204.0, -439.3]:
            setp("gwandong_daero", p[1:])
        p = rd["gyeongpo_road"]["points"]
        if p[0] == [1204.7, -440.0]:
            setp("gyeongpo_road", p[8:])                                     # [1174.6, −412] 삼문 앞 길에서
        p = rd["north_coast_road"]["points"]
        if p[0] == [1204.7, -440.0]:
            setp("north_coast_road", [[1236.0, -412.1], [1238.0, -446.0]] + p[3:])   # 일곽 동쪽 담(x 1231) 밖으로 돌아 북쪽
        p = rd["hyanggyo_lane"]["points"]
        if p[0] == [1204.0, -440.7]:
            setp("hyanggyo_lane", [[1171.0, -411.5], [1171.0, -470.0]] + p[4:])     # 일곽 서쪽 담(x 1177) 밖으로 돌아 북서 교동
    if rid == "GS_GYEONGJU":
        p = rd["gyeongju_eup_street_n"]["points"]
        if p[1] == [-2935.7, -2292.5]:
            setp("gyeongju_eup_street_n", [p[0], [-2935.7, -2318.5], [-2899.7, -2318.5], [-2899.7, -2258.5]])
    if changed:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(r, f, ensure_ascii=False, indent=1)
        print("roads fixed:", rid, changed)


def run_region(rid, bounds, fp):
    ET.DATA = os.path.join(ROOT, "region_data", rid)
    T = ET.Terrain()
    # 후속 수정: 제주 건천은 마른 돌 바닥이 보이게 집터를 바닥에서 조금 더 물린다(기본 2.5m → 4m)
    EP.DEFAULT_RULES["river_min"] = 4.0 if rid == "JJ_JEJU" else 2.5
    for it_ in range(10):
        pl = HubPlacer(T, bounds, fp)
        pl.prefix = PREFIX[rid]
        pl.stats_ = {}
        BUILDERS[rid](pl, T)
        if not pl.missing:
            break
        if it_ == 9:
            raise SystemExit("키트 크기 재기가 수렴하지 않음")
        res = E.measure(pl.missing)
        bad = [k for k, v in res.items() if v.get("error")]
        if bad:
            raise SystemExit(f"키트 없음: {bad[:5]}")
        bounds.update(res)
        json.dump(bounds, open(BOUNDS, "w", encoding="utf-8"), ensure_ascii=False, indent=0, sort_keys=True)
    return T, pl


def write(rid, T, pl, bounds):
    items = []
    for it in pl.items:
        b = bounds.get(it["_bkey"], {})
        it["_tris"] = b.get("tris", 0)
        o = {k: v for k, v in it.items() if not k.startswith("_")}
        if it.get("_label") and (it["_cat"] in ("civic", "landmark", "jumak", "shrine") or it["kit"] in ("village/well",)) \
                and it["_label"] not in ("고분", "돌하르방", "방사탑"):
            o["title"] = it["_label"]
        items.append(o)
    import station_reserve  # 역참 마방 자리 비워 두기(tools/region/make_stations.py)
    items = station_reserve.keep_clear(rid, items)
    doc = {"area": "hub",
           "note": f"대표 도시 배치(tools/placement/hubs.py {rid}, 결정적). 문화권 가옥형 kit/culture/. 근거·가설: docs/reports/placement-east.md",
           "items": items,
           "alleys": [dict(id=f"{pl.prefix}_alley_{i:03d}", **a) for i, a in enumerate(pl.alleys)]}
    out = os.path.join(ROOT, "region_data", rid, "placement_hub.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    return doc, out


def write_profiles(rid):
    path = os.path.join(ROOT, "region_data", rid, "region.json")
    r = json.load(open(path, encoding="utf-8"))
    for s in r["settlements"]:
        mt = (s.get("profile") or {}).get("archetype") == "mountain"
        p = HP.profile_for(rid, s, mountain=mt)
        p.pop("houses", None) if False else None
        s["profile"] = p
        t = HP.TITLES[rid].get(s["id"])
        if t:
            s["title"] = t
    r["culture_key"] = {"GS_GYEONGJU": "yeongnam", "GW_GANGNEUNG": "gwandong", "JJ_JEJU": "tamna"}[rid]
    with open(path, "w", encoding="utf-8") as f:
        json.dump(r, f, ensure_ascii=False, indent=1)


def count_buildings(pl):
    from collections import Counter
    c = Counter()
    for it in pl.items:
        if it["_cat"] in ("house", "civic", "landmark", "jumak", "market", "shrine") and it["kit"] not in ("reserve",):
            if it["kit"] in ("village/jwapan",) or it["kit"].startswith("nature/"):
                continue
            c[it["group"]] += 1
    return c


if __name__ == "__main__":
    bounds = json.load(open(BOUNDS, encoding="utf-8")) if os.path.exists(BOUNDS) else {}
    if not bounds and os.path.exists(E.BOUNDS):
        bounds = json.load(open(E.BOUNDS, encoding="utf-8"))
    fp = load_catalog_fp()
    for rid in RIDS:
        if "--profiles" in sys.argv:
            write_profiles(rid)
            print("profiles →", rid)
            continue
        fix_roads(rid)
        T, pl = run_region(rid, bounds, fp)
        doc, out = write(rid, T, pl, bounds)
        print(f"== {rid}: items {len(doc['items'])} → {out}")
        for l in pl.log:
            print("  ", l)
        bad = E.verify(pl)
        print("  overlaps:", len(bad), bad[:12])
        print("  tris total", sum(it["_tris"] for it in pl.items))
        for g, (s, x, z) in sorted(E.screen_tris(pl).items(), key=lambda a: -a[1][0])[:6]:
            print(f"   screen(r60) {g}: {s} @({x:.0f},{z:.0f})")
        cb = count_buildings(pl)
        print("  buildings by group:", dict(cb.most_common()))
        print("  stats:", pl.stats_)
        print("  fails:", EV.FAIL.most_common(12)); EV.FAIL.clear()
        if "--noplan" not in sys.argv:
            from east_plan import render
            views = {"GS_GYEONGJU": {"town": (-2950, -2200, 230, 2.0), "south": (-2900, -1950, 200, 2.0), "gampo": (3500, -1100, 220, 1.6)},
                     "GW_GANGNEUNG": {"town": (1220, -440, 200, 2.0), "gyeongpo": (1000, -1550, 300, 1.4), "gusan": (-918, 500, 120, 2.5)},
                     "JJ_JEJU": {"town": (-2994, -120, 220, 2.0), "hwabuk": (-1923, -440, 120, 2.5), "jocheon": (-90, -930, 120, 2.5)}}[rid]
            for nm, (x, z, h, ppm) in views.items():
                render(T, pl.items, bounds, nm, x, z, h, ppm, out=os.path.join(ROOT, "shots", "placement", f"hub_{PREFIX[rid]}_{nm}.png"))
