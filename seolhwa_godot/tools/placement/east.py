#!/usr/bin/env python3
"""placement-east 생성기 — JL_NAMWON_UNBONG 권역 중 남원 읍내를 뺀 동쪽(x > −2300).

    python3 tools/placement/east.py            # placement_east.json + 평면도(shots/placement/east_plan_*.png)
    python3 tools/placement/east.py --noplan   # 평면도 생략

결정적: 모든 난수는 장소별 고정 seed(random.Random). 키트 실제 크기는 Godot으로 재서
tools/placement/east_bounds.json에 캐시한다(없는 것만 tools/placement/east_measure.gd로 잰다).
계약서: docs/REGION_CONTRACTS.md §8. 근거·가설: docs/reports/placement-east.md
"""
import json
import math
import os
import random
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from east_terrain import Terrain, ROOT, DATA, polyline_at, polyline_len, polyline_project  # noqa: E402
from east_place import Placer, Local, bkey, l2w, ry_along, ry_cross, clamp_ry, wrap_half, Rect  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
BOUNDS = os.path.join(HERE, "east_bounds.json")
OUT = os.path.join(DATA, "placement_east.json")
SCRATCH = os.environ.get("EAST_TMP", os.path.join(HERE, ".east_tmp"))


def P(kit, params, lx=0.0, lz=0.0, lry=0.0, **fl):
    return (kit, params, lx, lz, lry, fl)


# ---------------------------------------------------------------- 묶음(로컬 배치)
def choga_set(seed, rng=None, extra=None):
    """초가 한 채 + 장독(뒤) + 짚가리 또는 헛간(옆). 원점 = 초가. 모양 난수는 seed에서만(자리 찾기와 독립)."""
    rng = random.Random(seed * 7919 + 13)
    w = rng.choice([None, None, 5.4, 6.0])
    cp = {"seed": seed}
    if w:
        cp["w"] = w
    if rng.random() < 0.25:
        cp["gourd"] = True
    pcs = [P("village/choga", cp, cat="house", kind="choga")]
    pcs.append(P("village/jangdok", {"seed": seed, "w": 2.4, "d": 2.0, "n": [2, 2, 1]}, 2.4, -5.0, cat="prop", margin=0.3, flatten=False))
    side = rng.choice([-1, 1])
    kind = extra or rng.choice(["haystack", "heotgan", "firewood", "haystack"])
    if kind == "haystack":
        pcs.append(P("village/haystack", {"seed": seed}, side * 6.2, 0.8, cat="prop", margin=0.3, flatten=False))
    elif kind == "heotgan":
        pcs.append(P("village/heotgan", {"seed": seed, "walls": "back", "w": 3.2}, side * 6.9, 0.4, cat="house"))
    elif kind == "firewood":
        pcs.append(P("village/firewood", {"seed": seed, "style": "stack"}, side * 5.6, 1.6, cat="prop", margin=0.3, flatten=False))
    return pcs


def compound(seed, size):
    return [P("village/house_compound", {"seed": seed, "size": size}, cat="house", kind="house_" + size)]


def tree(variant, seed, lx=0.0, lz=0.0):
    # 나무는 줄기 둘레만 겹침 검사(수관은 지붕 위로 겹쳐도 된다)
    return P("nature/big_tree", {"seed": seed, "variant": variant}, lx, lz, cat="prop", kind="tree_" + variant,
             aabb=[-1.2, 1.2, -1.2, 1.2], flatten=False, margin=0.6, river_min=1.0)


# ---------------------------------------------------------------- 도우미
def road_points(T, rid, step=2.0):
    pts = T.road(rid)["points"]
    L = polyline_len(pts)
    out = []
    s = 0.0
    while s <= L:
        x, z, d = polyline_at(pts, s)
        out.append((s, x, z, d))
        s += step
    return out


def entrance(T, rid, cx, cz, R, toward):
    """길이 마을 둘레(R) 밖으로 나가는 점 중 toward 쪽."""
    best = None
    for s, x, z, d in road_points(T, rid):
        r = math.hypot(x - cx, z - cz)
        if abs(r - R) < 3.0:
            dd = math.hypot(x - toward[0], z - toward[1])
            if best is None or dd < best[0]:
                best = (dd, s, x, z, d)
    return best


def gate_props(pl, T, L, rid, s, group, gcode, rng, sotdae=True, both=True):
    """길 위 호 길이 s 자리에 장승 한 쌍(길 양쪽) + 솟대. 길이 막히지 않게 길 가장자리 밖에."""
    pts = T.road(rid)["points"]
    w = T.road(rid)["width_m"]
    placed = []
    for ds in [0, 3, -3, 6, -6, 9, -9]:
        x, z, d = polyline_at(pts, s + ds)
        nx, nz = -d[1], d[0]
        off = w / 2 + 1.4
        ry = clamp_ry(((int(abs(s)) % 9) - 4) * 0.04)
        pcs = [P("village/jangseung", {"seed": 11}, 0, 0, cat="prop", kind="jangseung", flatten=False, margin=0.2, road_min=0.2,
                 label="장승")]
        a = pl.check(L, pcs, x + nx * off, z + nz * off, ry, {"max_drop": 1.5})
        pcs2 = [P("village/jangseung", {"seed": 12, "female": True}, 0, 0, cat="prop", kind="jangseung", flatten=False,
                  margin=0.2, road_min=0.2)]
        b = pl.check(L, pcs2, x - nx * off, z - nz * off, ry, {"max_drop": 1.5})
        if a[0] and (b[0] or not both):
            placed += pl.commit(pcs, x + nx * off, z + nz * off, ry, group, gcode)
            if b[0]:
                placed += pl.commit(pcs2, x - nx * off, z - nz * off, ry, group, gcode)
            if sotdae:
                # 솟대: 남쪽(카메라 쪽) 장승 옆, 길에서 조금 더 떨어져
                side = 1 if nz > 0 else -1
                for k in [2.4, 3.6, -2.4]:
                    sx, sz = x + nx * side * (off + 1.6) + d[0] * k, z + nz * side * (off + 1.6) + d[1] * k
                    sp = [P("village/sotdae", {"seed": int(abs(s)) % 7 + 1, "n": 3}, cat="prop", kind="sotdae", flatten=False,
                            margin=0.2, road_min=0.3)]
                    if pl.check(L, sp, sx, sz, ry, {"max_drop": 2.0})[0]:
                        placed += pl.commit(sp, sx, sz, ry, group, gcode)
                        break
            return placed
    pl.log.append(f"[gate] {group} 장승 자리 못 찾음 (s={s:.0f})")
    return placed


def village(pl, T, gcode, group, cx, cz, R, rng, n_comp=(), n_choga=4, toward=None, road=None, well=True,
            tree_n=1, rules=None, R_search=None, persimmon=1, allow_cross=False):
    """마을 하나: 집 묶음(n_comp = 크기 목록) + 초가 묶음 n_choga + 우물 + 정자나무 + (어귀 장승·솟대)."""
    L = Local(T, cx, cz, R + 60)
    rules = dict(rules or {})
    rules.setdefault("max_drop", 2.4)
    specs = [("c", s) for s in n_comp] + [("g", None)] * n_choga
    # 큰 것부터
    out = []
    seed0 = random.Random(f"{gcode}{int(cx)}{int(cz)}").randint(1, 900)
    for i, (k, size) in enumerate(specs):
        seed = seed0 + i * 7
        pcs = compound(seed, size) if k == "c" else choga_set(seed)
        r = pl.place_search(L, pcs, cx, cz, R_search or R, group, gcode, rng, rules, allow_cross=allow_cross)
        if r:
            out += r
    if well:
        pl.place_search(L, [P("village/well", {"seed": seed0, "roof": seed0 % 2 == 0}, cat="prop", kind="well", margin=1.2)],
                        cx, cz, R * 0.6, group, gcode, rng, rules, face="none")
    for t in range(persimmon):
        pl.place_search(L, [tree("persimmon", seed0 + 50 + t)], cx, cz, R * 0.8, group, gcode, rng, rules, face="none")
    if road and toward:
        e = entrance(T, road, cx, cz, R + 6, toward)
        if e:
            gate_props(pl, T, L, road, e[1], group, gcode, rng)
            for t in range(tree_n):
                pl.place_search(L, [tree("zelkova", seed0 + 80 + t)], e[2], e[3], 14, group, gcode, rng,
                                {"road_min": 1.5, "max_drop": 3.0}, face="none")
    return out


def market(pl, T, L, rid, s0, s1, group, gcode, rng, shops=4, jwapan=10, goods=None):
    """장터: 길 북쪽에 가가(정면 = 길·남쪽), 길 남쪽 장마당에 좌판(남향)."""
    pts = T.road(rid)["points"]
    w = T.road(rid)["width_m"]
    goods = goods or ["onggi", "cloth", "grain", "straw", "fish", "mixed"]
    out = []
    s = s0
    n_shop = 0
    gi = 0
    # 북쪽 가가 줄
    while s < s1 and n_shop < shops:
        x, z, d = polyline_at(pts, s)
        nx, nz = -d[1], d[0]
        if nz > 0:
            nx, nz = -nx, -nz          # 북쪽(−z)
        ry = clamp_ry(ry_along(*d))
        g = goods[gi % len(goods)]
        gi += 1
        params = {"seed": 300 + gi, "goods": g}
        if g == "cloth":
            params["w"] = 4.5
        bb = pl.aabb("village/market_shop", params)
        off = w / 2 + 1.2 + (bb[3])     # 앞(+z) 끝이 길 가장자리에서 1.2m
        pcs = [P("village/market_shop", params, cat="market", kind="shop", road_min=0.6, label=None)]
        placed = False
        for extra in [0, 1.5, 3.0]:
            px, pz = x + nx * (off + extra), z + nz * (off + extra)
            ok = pl.check(L, pcs, px, pz, ry, {"max_drop": 2.0, "margin": 0.6})
            if ok[0]:
                out += pl.commit(pcs, px, pz, ry, group, gcode)
                n_shop += 1
                placed = True
                break
        s += (bb[1] - bb[0]) + 1.6 if placed else 3.0
    # 남쪽 장마당 좌판 2줄 + 북쪽 가가 사이 빈자리
    n_j = 0
    for row, roff in enumerate([w / 2 + 2.6, w / 2 + 7.0]):
        s = s0 + (2.0 if row else 0.0)
        while s < s1 and n_j < jwapan:
            x, z, d = polyline_at(pts, s)
            nx, nz = -d[1], d[0]
            if nz < 0:
                nx, nz = -nx, -nz          # 남쪽(+z)
            ry = clamp_ry(ry_along(*d))
            g = goods[(gi + n_j) % len(goods)]
            params = {"seed": 400 + n_j, "goods": g}
            if n_j % 3 == 2:
                params["awning"] = False
            pcs = [P("village/jwapan", params, cat="market", kind="jwapan", flatten=False, road_min=0.8, margin=0.8)]
            px, pz = x + nx * roff, z + nz * roff
            if pl.check(L, pcs, px, pz, ry, {"max_drop": 1.6, "river_min": 1.5})[0]:
                out += pl.commit(pcs, px, pz, ry, group, gcode)
                n_j += 1
                s += 4.2
            else:
                s += 2.0
    return out


def gwana_unbong(seed=7):
    """운봉현 관아(가설): 현(縣) 규모라 남원부 관아(60×72)보다 작게 — 외삼문 + 동헌 5칸 + 내아(기와 3칸) + 담 36×36.
    원점 = 일곽 가운데, 정면 +z."""
    W, D = 36.0, 36.0
    x0, x1, z0, z1 = -W / 2, W / 2, -D / 2, D / 2
    pcs = [
        P("landmark/samun", {"seed": seed, "kind": "outer", "name": "운봉현"}, 0.0, z1, cat="civic", kind="samun", label="운봉현 외삼문"),
        P("landmark/dongheon", {"seed": seed + 1, "bays": 5}, -5.0, -7.5, cat="civic", kind="dongheon", label="동헌"),
        P("village/giwa", {"seed": seed + 2, "plain": True, "w": 7.2, "bays": 3}, 10.5, -10.0, cat="civic", kind="naea", label="내아"),
        P("village/torch_post", {"seed": seed}, -8.2, z1 + 2.0, cat="prop", kind="torch", flatten=False, margin=0.2),
        P("village/torch_post", {"seed": seed + 1}, 8.2, z1 + 2.0, cat="prop", kind="torch", flatten=False, margin=0.2),
    ]
    # 담(gwana_wall, 로컬 x 방향), 외삼문 자리 틈 반폭 5.6
    k = 0

    def wall(ax, az, bx, bz):
        nonlocal k
        L = math.hypot(bx - ax, bz - az)
        n = max(1, math.ceil(L / 12.0))
        dx, dz = (bx - ax) / L, (bz - az) / L
        for j in range(n):
            t0, t1 = L * j / n, L * (j + 1) / n
            cx_, cz_ = ax + dx * (t0 + t1) / 2, az + dz * (t0 + t1) / 2
            ln = round(t1 - t0 + 0.25, 2)
            pcs.append(P("landmark/gwana_wall", {"seed": seed + 20 + k, "length": ln, "height": 2.2}, cx_, cz_,
                         -math.atan2(dz, dx), cat="wall", kind="wall", aabb=[-ln / 2, ln / 2, -0.55, 0.55], margin=0.2))
            k += 1

    pcs.append(P("reserve", {}, 0.0, 0.0, reserve=True, aabb=[x0, x1, z0, z1 + 2.5], margin=0.0))
    pcs.append(P("reserve", {}, 0.0, 0.0, reserve=True, aabb=[-6.0, 6.0, z1 + 2.5, z1 + 12.0], margin=0.0, nocheck=True))
    wall(x0, z0, x1, z0)
    wall(x1, z0, x1, z1)
    wall(x0, z1, x0, z0)
    wall(x1, z1, 7.4, z1)
    wall(-7.4, z1, x0, z1)
    return pcs


def yeok_inwol(seed=5):
    """인월역(가설): 역사(기와 3칸) + 마구간 둘 + 헛간 + 평대문 + 토담. 원점 = 마당, 정면 +z."""
    pcs = [
        P("village/giwa", {"seed": seed, "plain": True, "w": 7.2, "bays": 3}, 0.0, -4.6, cat="civic", kind="yeoksa", label="인월역"),
        P("village/oeyanggan", {"seed": seed}, -9.0, -5.0, cat="house", kind="mabang"),
        P("village/oeyanggan", {"seed": seed + 1}, -9.0, 0.5, cat="house", kind="mabang"),
        P("village/heotgan", {"seed": seed}, 9.0, -4.5, cat="house", kind="heotgan"),
        P("village/daemun", {"seed": seed, "style": "tile"}, 0.0, 6.5, cat="civic", kind="daemun"),
        P("village/torch_post", {"seed": seed}, 2.6, 8.4, cat="prop", kind="torch", flatten=False, margin=0.2),
    ]
    pcs.append(P("reserve", {}, 0.0, 0.0, reserve=True, aabb=[-12.5, 12.5, -11.8, 9.0], margin=0.0))
    pcs.append(P("reserve", {}, 0.0, 0.0, reserve=True, aabb=[-4.0, 4.0, 9.0, 16.0], margin=0.0, nocheck=True))
    for (ax, az, bx, bz) in [(-12.5, 6.5, -2.2, 6.5), (2.2, 6.5, 12.5, 6.5), (-12.5, 6.5, -12.5, -11.8), (12.5, 6.5, 12.5, -11.8),
                             (-12.5, -11.8, 12.5, -11.8)]:
        L = math.hypot(bx - ax, bz - az)
        pcs.append(P("village/todam", {"seed": seed + int(ax + az), "ax": ax, "az": az, "bx": bx, "bz": bz, "cap": "tile"},
                     0.0, 0.0, cat="wall", kind="todam",
                     aabb=[min(ax, bx) - 0.4, max(ax, bx) + 0.4, min(az, bz) - 0.4, max(az, bz) + 0.4], margin=0.1))
    return pcs


def jumak_set(seed):
    return [P("village/jumak", {"seed": seed}, cat="jumak", kind="jumak", label="주막")]


def mill(seed):
    return [P("village/mulbang_a", {"seed": seed}, cat="mill", kind="mulbang", label="물레방아", river_min=0.6, river_max=7.0)]


# ---------------------------------------------------------------- 다리(도강점)
def crossing_kit(T, c):
    rv = T.river(c["river_id"])
    g = rv["grade"]
    t = c["type"]
    if t == "섶다리":
        return "village/seop_bridge"
    if t == "돌다리":
        return "village/stone_bridge"
    if t == "징검다리":
        return "village/jingeom"
    if t == "여울":
        return "village/jingeom"      # 얕은 여울목에 디딤돌(D급 개울)
    return None


def bridges(pl, T, rng):
    done = []
    for c in T.region["crossings"]:
        if c["x"] < -2300:
            continue
        kit = crossing_kit(T, c)
        if not kit:
            continue
        if any(math.hypot(c["x"] - d[0], c["z"] - d[1]) < 9 for d in done):
            pl.log.append(f"[bridge] {c['id']} — 9m 안에 이미 다리가 있어 합침")
            continue
        L = Local(T, c["x"], c["z"], 40)
        rd = T.road(c["road_id"])
        s, _ = polyline_project(rd["points"], c["x"], c["z"])
        x1, z1, _ = polyline_at(rd["points"], max(0, s - 6))
        x2, z2, _ = polyline_at(rd["points"], s + 6)
        dx, dz = x2 - x1, z2 - z1
        n = math.hypot(dx, dz) or 1
        dx, dz = dx / n, dz / n
        ry = ry_cross(dx, dz)
        rv = T.river(c["river_id"])
        nr = L.nearest_river(c["x"], c["z"])
        rdx, rdz = nr[3] if nr else (1, 0)
        cosang = abs(dx * (-rdz) + dz * rdx)     # 길 방향과 하천 법선 사이
        cosang = max(cosang, 0.6)
        hw = max(rv["width_m"] / 2, 2.6)
        span = 2 * hw / cosang
        wy = L.water_y(c["x"], c["z"], c["river_id"])
        if kit == "village/jingeom":
            ln = round(min(span + 1.0, 22.0), 1)
            params = {"seed": 21 + len(done), "len": ln}
            y = round(wy, 2)
        else:
            ln = round(min(span + 3.0, 26.0), 1)
            if kit == "village/seop_bridge":
                params = {"seed": 31 + len(done), "len": ln, "spans": max(3, int(ln / 2.6))}
            else:
                params = {"seed": 41 + len(done), "len": ln, "hw": 1.3}
            # 둑 높이: 양 끝 땅 높이 중 낮은 쪽(물면보다 0.3 위는 되게)
            ea = T.height(c["x"] - dx * ln / 2, c["z"] - dz * ln / 2)
            eb = T.height(c["x"] + dx * ln / 2, c["z"] + dz * ln / 2)
            y = round(max(min(ea, eb), wy + 0.3), 2)
        label = {"village/seop_bridge": "섶다리", "village/stone_bridge": "돌다리", "village/jingeom": "징검다리"}[kit]
        pcs = [P(kit, params, cat="bridge", kind=kit.split("/")[-1], flatten=False, nocheck=True, y=None, label=label,
                 id=f"ea_br_{c['id']}")]
        pl.commit(pcs, c["x"], c["z"], ry, "다리·징검다리(도강점)", "br")
        done.append((c["x"], c["z"]))
        pl.log.append(f"[bridge] {c['id']} {c['type']}→{label} 길이 {ln} ry {math.degrees(ry):.0f}° y {y} (수면 {wy:.2f})")


def extra_bridge(pl, T, river_id, x, z, group, gcode, kit="village/seop_bridge", note=""):
    """길 자료에 없는 마을 다리(예: 인월 람천 남쪽 마을). 하천에 수직으로."""
    L = Local(T, x, z, 40)
    nr = L.nearest_river(x, z)
    _, w, rid, (rdx, rdz), (cx, cz) = nr
    rv = T.river(rid)
    hw = max(rv["width_m"] / 2, 2.6)
    ln = round(2 * hw + 3.5, 1)
    dx, dz = -rdz, rdx
    ry = ry_cross(dx, dz)
    wy = L.water_y(cx, cz, rid)
    ea = T.height(cx - dx * ln / 2, cz - dz * ln / 2)
    eb = T.height(cx + dx * ln / 2, cz + dz * ln / 2)
    y = round(max(min(ea, eb), wy + 0.3), 2)
    params = {"seed": 77, "len": ln, "spans": max(3, int(ln / 2.6))}
    pcs = [P(kit, params, cat="bridge", kind="seop_bridge", flatten=False, nocheck=True, y=None, label="섶다리")]
    pl.log.append(f"[bridge+] {group} {rid} 마을 섶다리 길이 {ln} @({cx:.0f},{cz:.0f}) {note}")
    return pl.commit(pcs, cx, cz, ry, group, gcode), (cx - dx * (ln / 2 + 4), cz - dz * (ln / 2 + 4)), (cx + dx * (ln / 2 + 4), cz + dz * (ln / 2 + 4))


# ---------------------------------------------------------------- 장소들
def build(pl, T):
    reg = T.region
    st = {s["id"]: s for s in reg["settlements"]}
    lm = {s["id"]: s for s in reg["landmarks"]}

    # ===== 다리 먼저(길 위 고정 자리) =====
    bridges(pl, T, random.Random(1))

    # ===== 1. 여원재 =====
    rng = random.Random(101)
    g, gc = "여원재", "yw"
    ps = next(p for p in reg["passes"] if p["id"] == "yeowonjae")
    L = Local(T, ps["x"], ps["z"], 120)
    # 성황당: 고갯마루 길가(북쪽), 신목은 kit-nature 느티나무를 anchors.tree에
    sh_params = {"seed": 3, "tree": False}
    anc = pl.bounds.get(bkey("village/seonghwangdang", sh_params), {}).get("anchors", {}).get("tree", [0, 0, -1.2])
    sh = [P("village/seonghwangdang", sh_params, cat="shrine", kind="seonghwangdang", label="성황당", road_min=0.8),
          P("nature/big_tree", {"seed": 9, "variant": "zelkova", "h": 8.0, "spread": 5.0}, anc[0], anc[2], cat="prop", kind="sinmok",
            aabb=[-1.2, 1.2, -1.2, 1.2], flatten=False, nocheck=True)]
    pl.place_search(L, sh, ps["x"], ps["z"] - 6, 22, g, gc, rng, {"max_drop": 2.6}, road_pref=(0.8, 6.0))
    s_pass, _ = polyline_project(T.road("tongyeong_byeolro")["points"], ps["x"], ps["z"])
    gate_props(pl, T, L, "tongyeong_byeolro", s_pass + 14, g, gc, rng, sotdae=False)
    # 고갯마루 주막(가설): 고개 동쪽 내리막 첫 평지
    pl.place_search(L, jumak_set(5), ps["x"] + 40, ps["z"], 60, g, gc, rng, {"max_drop": 3.0}, road_pref=(1.0, 8.0))
    # 아랫주막(region.json yeowon_jumak)
    yj = st["yeowon_jumak"]
    L2 = Local(T, yj["x"], yj["z"], 80)
    pl.place_search(L2, jumak_set(6), yj["x"], yj["z"], 40, "여원재 아랫주막", "yj", rng, {"max_drop": 3.0}, road_pref=(1.0, 8.0))
    pl.place_search(L2, choga_set(61, rng, "heotgan"), yj["x"], yj["z"], 45, "여원재 아랫주막", "yj", rng, {"max_drop": 3.0})
    pl.place_search(L2, [tree("zelkova", 62)], yj["x"], yj["z"], 30, "여원재 아랫주막", "yj", rng, {"max_drop": 3.0}, face="none")

    # ===== 2. 이백 마을(남원→여원재 길가 들마을) =====
    rng = random.Random(202)
    s = st["ibaek"]
    village(pl, T, "ib", "이백 마을", s["x"], s["z"], 55, rng, n_comp=("medium", "small", "small"), n_choga=4,
            road="tongyeong_byeolro", toward=(-2000, -100))

    # ===== 3. 운봉 읍치 =====
    rng = random.Random(303)
    g, gc = "운봉 읍치", "ub"
    ga = lm["unbong_gwana"]
    L = Local(T, ga["x"], ga["z"], 160)
    pl.place_search(L, gwana_unbong(), ga["x"], ga["z"], 26, g, gc, rng, {"max_drop": 3.0, "road_min": 0.6},
                    ry_fixed=0.0, n=400, road_pref=(0.5, 8.0), group_y=True)
    # 운봉장: 읍내길(관아→장터) 북서쪽 가가 + 남동쪽 좌판
    ust = T.road("unbong_eup_street")
    Lm = Local(T, st["unbong_jang"]["x"], st["unbong_jang"]["z"], 80)
    market(pl, T, Lm, "unbong_eup_street", 22, polyline_len(ust["points"]) - 4, g, gc, rng, shops=3, jwapan=8)
    # 마을: 이방·향리 기와집 둘 + 초가 집들
    u = st["unbong_eup"]
    village(pl, T, gc, g, u["x"], u["z"], 110, rng, n_comp=("large", "large", "medium", "medium", "small", "small"),
            n_choga=12, road="tongyeong_byeolro", toward=(1050, -960), tree_n=1, persimmon=2)
    pl.place_search(L, jumak_set(31), 900, -830, 45, g, gc, rng, {"max_drop": 2.6}, road_pref=(1.0, 6.0))
    pl.place_search(Local(T, 760, -800, 120), mill(32), 760, -790, 90, g, gc, rng, {"max_drop": 2.0, "river_min": 0.6})

    # ===== 4. 황산대첩비 + 비전 마을 =====
    rng = random.Random(404)
    g, gc = "황산대첩비·비전", "hs"
    hb = lm["hwangsan_daecheopbi"]
    L = Local(T, hb["x"], hb["z"], 120)
    pl.place_fixed(L, [P("landmark/hwangsan_bigak", {"seed": 1, "wall": True}, cat="landmark", kind="bigak", label="황산대첩비각")],
                   hb["x"], hb["z"], 0.0, g, gc, {"max_drop": 4.0})
    b = st["bijeon"]
    village(pl, T, gc, g, b["x"] - 20, b["z"] + 5, 50, rng, n_comp=("small", "medium"), n_choga=3,
            road="tongyeong_byeolro", toward=(1460, -1370))

    # ===== 5. 인월(장·역·마을·람천 섶다리) =====
    rng = random.Random(505)
    g, gc = "인월", "iw"
    iw = st["inwol_jang"]
    L = Local(T, iw["x"], iw["z"], 160)
    tp = T.road("tongyeong_byeolro")["points"]
    s_m, _ = polyline_project(tp, iw["x"] - 40, iw["z"])
    market(pl, T, L, "tongyeong_byeolro", s_m, s_m + 85, g, gc, rng, shops=5, jwapan=12)
    yk = st["inwol_yeok"]
    pl.place_search(L, yeok_inwol(), yk["x"] - 25, yk["z"] - 25, 45, g, gc, rng, {"max_drop": 3.0}, ry_fixed=0.0, n=400,
                    road_pref=(1.0, 14.0), group_y=True)
    pl.place_search(L, jumak_set(51), 2722, -1462, 30, g, gc, rng, {"max_drop": 2.6}, road_pref=(1.0, 6.0))
    pl.place_search(L, jumak_set(52), 2880, -1470, 40, g, gc, rng, {"max_drop": 2.6}, road_pref=(1.0, 6.0))
    village(pl, T, gc, g, iw["x"], iw["z"] - 55, 85, rng, n_comp=("medium", "medium", "small", "large"), n_choga=5,
            road="tongyeong_byeolro", toward=(2560, -1500), persimmon=2)
    # 람천 남쪽 마을 + 섶다리(가설)
    _, a_end, b_end = extra_bridge(pl, T, "ramcheon", iw["x"] + 5, iw["z"] + 25, g, gc, note="인월장 남쪽 람천 건너 마을")
    south = a_end if a_end[1] > b_end[1] else b_end
    village(pl, T, gc, g, south[0], south[1] + 22, 32, rng, n_comp=("small",), n_choga=3, well=True, persimmon=1)
    pl.place_search(Local(T, iw["x"], iw["z"], 160), mill(53), iw["x"] - 70, iw["z"] + 20, 80, g, gc, rng, {"max_drop": 2.0}, allow_cross=True)
    # 인월 동쪽(함양 쪽) 어귀 장승
    e = entrance(T, "tongyeong_byeolro", iw["x"], iw["z"], 110, (3000, -1500))
    if e:
        gate_props(pl, T, Local(T, e[2], e[3], 40), "tongyeong_byeolro", e[1], g, gc, rng)

    # ===== 6. 실상사 + 산내 =====
    rng = random.Random(606)
    g, gc = "실상사", "ss"
    sm = lm["silsangsa"]
    L = Local(T, sm["x"], sm["z"], 140)
    pl.place_fixed(L, [P("landmark/silsangsa", {"seed": 1}, cat="landmark", kind="silsangsa", label="실상사"),
                       # 천왕문 앞 진입로는 비워 둔다
                       P("reserve", {}, 0.0, 0.0, reserve=True, aabb=[-7.0, 7.0, 34.0, 52.0], margin=0.0)],
                   sm["x"], sm["z"], 0.0, g, gc, {"max_drop": 6.0})
    # 해탈교 서쪽 끝 석장승 자리(실상사 석장승 1725년 — 키트는 나무 장승이라 가설·대체)
    hb_ = next(c for c in reg["crossings"] if c["id"] == "haetal_bridge")
    rp = T.road("inwol_banseon_road")["points"]
    s_h, _ = polyline_project(rp, hb_["x"], hb_["z"])
    gate_props(pl, T, L, "inwol_banseon_road", s_h + 20, g, gc, rng, sotdae=False)
    # 절 아래 주막·초가 몇 채(가설: 사하촌)
    pl.place_search(L, jumak_set(61), sm["x"] - 45, sm["z"] + 70, 40, g, gc, rng, {"max_drop": 2.6}, road_pref=(1.0, 6.0),
                    pref=(sm["x"] - 55, sm["z"] + 70))

    rng = random.Random(616)
    g, gc = "산내 마을", "sn"
    sn = st["sannae"]
    village(pl, T, gc, g, sn["x"], sn["z"], 42, rng, n_comp=("small",), n_choga=5,
            road="inwol_banseon_road", toward=(3200, 380), rules={"max_drop": 4.0}, R_search=60)
    pl.place_search(Local(T, sn["x"], sn["z"], 120), mill(62), sn["x"] + 20, sn["z"] - 10, 90, g, gc, rng, {"max_drop": 3.6}, allow_cross=True)

    # ===== 7. 반선(뱀사골 어귀) =====
    rng = random.Random(707)
    g, gc = "반선 마을", "bs"
    bs = st["banseon"]
    village(pl, T, gc, g, bs["x"], bs["z"], 30, rng, n_comp=(), n_choga=4, road="inwol_banseon_road",
            toward=(2300, 1250), rules={"max_drop": 4.0, "river_min": 1.5}, R_search=55)
    pl.place_search(Local(T, bs["x"], bs["z"], 120), jumak_set(71), bs["x"] + 10, bs["z"] - 30, 60, g, gc, rng, {"max_drop": 4.0},
                    road_pref=(1.0, 6.0))
    pl.place_search(Local(T, bs["x"], bs["z"], 120), mill(72), bs["x"] + 20, bs["z"] - 60, 100, g, gc, rng, {"max_drop": 3.6}, allow_cross=True)

    # ===== 8. 들마을 후보(몇 곳만, 작게) =====
    for sid, nc, comp, sd in [("auto_village_03", 3, ("small",), 801), ("auto_village_04", 4, ("small",), 802),
                              ("auto_village_06", 3, (), 803)]:
        s = st[sid]
        rng = random.Random(sd)
        village(pl, T, "av", f"들마을({sid})", s["x"], s["z"], 36, rng, n_comp=comp, n_choga=nc, persimmon=1, tree_n=1,
                road=None, allow_cross=True)

    # ===== 9. 길가 주막(가설) =====
    rng = random.Random(909)
    for rid, xz, nm in [("tongyeong_byeolro", (-800, -560), "이백–여원재 길"),
                        ("tongyeong_byeolro", (1300, -1190), "운봉–황산 길"),
                        ("tongyeong_byeolro", (2064, -1640), "황산–인월 고개"),
                        ("tongyeong_byeolro", (3500, -1650), "인월–함양 길"),
                        ("inwol_banseon_road", (3205, -600), "인월–실상사 길"),
                        ("inwol_banseon_road", (2690, 780), "산내–반선 길")]:
        rp = T.road(rid)["points"]
        s, _ = polyline_project(rp, *xz)
        x, z, _ = polyline_at(rp, s)
        Lr = Local(T, x, z, 80)
        r = pl.place_search(Lr, jumak_set(900 + int(s) % 97), x, z - 8, 60, "길가 주막", "rd", rng, {"max_drop": 3.6},
                            road_pref=(1.0, 6.0))
        if r:
            r[0]["_label"] = "주막(" + nm + ")"


# ---------------------------------------------------------------- 실행
def load_catalog_fp():
    fp = {}
    for f in ["kit/village/catalog.json", "kit/landmark/catalog.json", "kit/nature/catalog.json"]:
        try:
            c = json.load(open(os.path.join(ROOT, f), encoding="utf-8"))
        except Exception:
            continue
        items = c.get("models") or c.get("items") or []
        base = f.split("/")[1]
        for it in items:
            if it.get("footprint"):
                fp[base + "/" + it["name"]] = tuple(it["footprint"])
    return fp


def measure(missing):
    os.makedirs(SCRATCH, exist_ok=True)
    fin = os.path.join(SCRATCH, "east_measure_in.json")
    fout = os.path.join(SCRATCH, "east_measure_out.json")
    json.dump(list(missing.values()), open(fin, "w"), ensure_ascii=False)
    cmd = ["godot", "--path", ROOT, "--headless", "-s", "res://tools/placement/east_measure.gd", "--", f"--in={fin}", f"--out={fout}"]
    print("measure:", len(missing), "개 —", " ".join(cmd[:6]))
    subprocess.run(cmd, check=True, capture_output=True, timeout=600)
    return json.load(open(fout, encoding="utf-8"))


def run():
    T = Terrain()
    bounds = json.load(open(BOUNDS, encoding="utf-8")) if os.path.exists(BOUNDS) else {}
    fp = load_catalog_fp()
    for it_ in range(10):
        pl = Placer(T, bounds, fp)
        build(pl, T)
        if not pl.missing:
            break
        if it_ == 9:
            raise SystemExit("키트 크기 재기가 수렴하지 않음")
        res = measure(pl.missing)
        bounds.update(res)
        json.dump(bounds, open(BOUNDS, "w", encoding="utf-8"), ensure_ascii=False, indent=0, sort_keys=True)
    return T, pl, bounds


def write(T, pl, bounds):
    items = []
    for it in pl.items:
        b = bounds.get(it["_bkey"], {})
        it["_tris"] = b.get("tris", 0)
        items.append({k: v for k, v in it.items() if not k.startswith("_")})
    doc = {"area": "east",
           "note": "placement-east 생성(tools/placement/east.py, 결정적). 남원 읍내를 뺀 x > −2300 — 여원재·운봉·황산·인월·실상사·산내·반선·들마을·길가·도강점. 근거·가설: docs/reports/placement-east.md",
           "items": items}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    return doc


def verify(pl):
    """겹침(먹선 크기 기준 회전 사각형) 전수 검사 + 화면당 삼각형."""
    rects = [(Rect(it["x"], it["z"], it["ry"], it["_aabb"]), it) for it in pl.items]
    bad = []
    for i in range(len(rects)):
        a, ia = rects[i]
        for j in range(i + 1, len(rects)):
            b, ib = rects[j]
            if abs(a.cx - b.cx) > 80 or abs(a.cz - b.cz) > 80:
                continue
            # 같은 묶음 안의 의도된 겹침(성황당-신목, 담 모서리)은 제외
            cats = {ia["_cat"], ib["_cat"]}
            if "bridge" in cats:
                continue
            if a.overlaps(b):
                if ("wall" in cats and len(cats) == 1):
                    continue
                if ia["kit"] == "nature/big_tree" or ib["kit"] == "nature/big_tree":
                    if "seonghwangdang" in (ia["kit"] + ib["kit"]):
                        continue
                bad.append((ia["id"], ib["id"]))
    return bad


def screen_tris(pl, radius=60.0):
    """각 건물 둘레 radius 안 키트 삼각형 합의 최대(근사 '한 화면')."""
    pts = [(it["x"], it["z"], it["_tris"], it["group"]) for it in pl.items]
    best = {}
    for x, z, _, g in pts:
        s = sum(t for x2, z2, t, _ in pts if (x2 - x) ** 2 + (z2 - z) ** 2 < radius * radius)
        if s > best.get(g, (0,))[0]:
            best[g] = (s, x, z)
    return best


if __name__ == "__main__":
    T, pl, bounds = run()
    doc = write(T, pl, bounds)
    print(f"items {len(doc['items'])} → {OUT}")
    for l in pl.log:
        print(" ", l)
    bad = verify(pl)
    print("overlaps:", len(bad), bad[:20])
    tot = sum(it["_tris"] for it in pl.items)
    print("tris total", tot)
    for g, (s, x, z) in sorted(screen_tris(pl).items(), key=lambda a: -a[1][0]):
        print(f"  screen(r60) {g}: {s} @({x:.0f},{z:.0f})")
    from collections import Counter
    print(Counter(it["group"] for it in pl.items))
    if "--noplan" not in sys.argv:
        from east_plan import render
        views = {
            "yeowonjae": (-120, -930, 240, 1.6), "unbong": (860, -760, 140, 2.5), "hwangsan": (1630, -1330, 80, 4),
            "inwol": (2770, -1470, 120, 3), "silsangsa": (3690, 20, 80, 3.5), "sannae": (3018, 486, 60, 5),
            "banseon": (2170, 1490, 60, 5), "ibaek": (-1276, -222, 70, 4),
        }
        for sid in ["auto_village_03", "auto_village_04", "auto_village_06"]:
            s = next(s for s in T.region["settlements"] if s["id"] == sid)
            views["auto_" + sid[-2:]] = (s["x"], s["z"], 50, 5)
        for name, (x, z, h, ppm) in views.items():
            render(T, pl.items, bounds, name, x, z, h, ppm)
        print("plans written")
