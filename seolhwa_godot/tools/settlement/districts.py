"""Layer 3 — districts and activity allocation (L3-8 3회차 §1, audit K7, PUB-04).

Consumes only Layer 0–2 artifacts: the frame territory, civic reserves and forecourts, primary
corridors, the water-supply reservation, the area ledger's residential components with their
household counts, livelihoods, and the terrain-water fields. It never rediscovers the town or
enlarges its allocation.

* Districts are a land-use role + household mixture, not class zoning: households keep class,
  livelihood and group as separate attributes; no "north = elite" rule.
* Allocation on 4 m cells clipped to the usable components: cost C_ik + λ_k with an interface
  term β·(like neighbours); prices λ are iterated to meet area quotas (tolerance 2 % or one cell),
  then an exact boundary transfer, then small disconnected parts are relabelled.
* Non-built land is allocated as regions too (PUB-04): 성안 빈터(open ground), 과원·채마(orchard /
  garden from the f_open budget), 언덕(hill = unbuildable slope), 물길(watercourse), protected fields.
* Market: the Layer-2 market reserve is the funded square; trade/service households take the
  approach-chain frontage; the outside-gate market variant is always evaluated and reported.
* Outside-wall hamlets (walled settlements): part of the agriculture households on dry edges of
  paddies beside existing approaches, 5–15 per cluster; protected farmland is never consumed.
District boundaries are planning labels, not roads or walls (Layer 5 follows actual parcels).
"""
from __future__ import annotations

import math

import numpy as np
import shapely
from scipy import ndimage
from shapely.geometry import LineString, Point, Polygon, box

from . import geometry as G
from . import raster as Rr
from .layout_ctx import largest_remainder, union
from .raster import Grid

GROUPS = ("market_trade", "clerical", "elite", "craft", "ordinary", "garden_open")
FIXED = ("civic_reserve", "market_plaza", "civic_forecourt", "primary_street", "well", "watercourse",
         "field_protected", "lock", "hill", "open_ground")
KO = {"market_trade": "장시·가게·품팔이", "clerical": "아전·중인", "elite": "양반·지주", "craft": "수공업",
      "ordinary": "농·어·산업 서민", "garden_open": "과원·채마(텃밭)", "civic_reserve": "관아·공공", "market_plaza": "장터 마당",
      "civic_forecourt": "앞마당", "primary_street": "주 가로", "well": "우물", "watercourse": "물길",
      "field_protected": "보호 경작지", "lock": "이야기 고정 장소", "hill": "언덕(급경사)", "open_ground": "성안 빈터·범람지"}


def _grid_for(poly, cell):
    xmin, zmin, xmax, zmax = poly.bounds
    nx = int(math.ceil((xmax - xmin) / cell)) + 1
    nz = int(math.ceil((zmax - zmin) / cell)) + 1
    return Grid(xmin + cell / 2, zmin + cell / 2, cell, nx, nz)


def _norm_near(d, rng):
    lo, hi = rng
    return np.clip(1.0 - (d - lo) / max(hi - lo, 1e-9), 0.0, 1.0)


def _norm_far(d, rng):
    lo, hi = rng
    return np.clip((d - lo) / max(hi - lo, 1e-9), 0.0, 1.0)


def _dist_to(mask, cell):
    if not mask.any():
        return np.full(mask.shape, 1e9)
    return ndimage.distance_transform_edt(~mask) * cell


def main_gate(C):
    """Main gate by program-weighted route demand and civic access cost (L3-8 §1); a supplied
    designation (axes kind 'main_gate') wins."""
    fr = C.fr
    w = C.R.p("layout.gate_route_weights")
    paths = {p["ref"]: p for p in (fr.get("primary_corridors") or {}).get("paths", []) if p["role"] == "gate"}
    roads = {r.id: r for r in C.inp.roads}
    cands = []
    if C.walled:
        for o in fr["openings"]:
            if o["type"] != "gate":
                continue
            seq = int(o["id"].split("-")[1])
            dem = sum(w.get(roads[r].klass, w["default"]) for r in o.get("routes", []) if r in roads) or w["default"]
            L = paths.get(seq, {}).get("length_m") or 1e3
            cands.append({"id": o["id"], "seq": seq, "xz": o["center"], "demand": dem, "access_m": L,
                          "score": round(dem / (1.0 + L / 100.0), 4), "routes": o.get("routes", [])})
    else:
        for n in (fr.get("primary_corridors") or {}).get("nodes", []):
            if n["kind"] == "route_entrance":
                seq = int(n["id"].split("-")[-1])
                L = paths.get(seq, {}).get("length_m") or 1e3
                cands.append({"id": n["id"], "seq": seq, "xz": n["xz"], "demand": w["default"], "access_m": L,
                              "score": round(w["default"] / (1.0 + L / 100.0), 4), "routes": []})
    for a in C.inp.axes:
        if a.get("kind") == "main_gate" and a.get("ref"):
            for c in cands:
                if c["id"] == a["ref"]:
                    c["designated"] = True
    cands.sort(key=lambda c: (not c.get("designated"), -c["score"], c["id"]))
    return cands


def build(C):
    R, A = C.R, C.A
    fr = C.fr
    cell = R.p("layout.district.cell_m")
    T = C.territory
    PG = _grid_for(T, cell)
    X, Z = np.meshgrid(PG.xs(), PG.zs())
    inside = Rr.rasterize(PG, T)
    smp = lambda arr: C.sample(arr, X, Z)
    slope, Rf, h = smp(A.slope), smp(A.R), C.height(X.ravel(), Z.ravel()).reshape(X.shape)
    water = smp(A.water) | smp(A.drain)
    house_ok = smp(A.house_ok)
    flood_ex = smp(A.flood_ex)
    farm = smp(A.farmland)
    # ------------------------------------------------------------- fixed labels
    lab = np.full(PG.shape, -1, np.int16)   # -1 outside; codes: index into names
    names = list(FIXED) + list(GROUPS)
    code = {n: i for i, n in enumerate(names)}
    civ = [c for c in fr["civic_reserves"]]
    market = next((c for c in civ if c["key"] == "market"), None)
    env_m = union([C.g(c["envelope"]) for c in civ if c["key"] != "market"])
    fore_m = union([C.g(c["forecourt"]) for c in civ])
    mk_m = C.g(market["envelope"]) if market else Polygon()
    corr = C.g((fr.get("primary_corridors") or {}).get("reservation"))
    well = union([C.g(w["reservation"]) for w in fr.get("water_access", [])])
    locks = union([l["geom"] for l in C.inp.locks])
    prot = A.protected_poly
    comps = [G.polygonal(C.g(g)) for g in C.plan["program"]["area_ledger"].get("component_geometry", [])]
    comp_mask = [Rr.rasterize(PG, p) & inside for p in comps]
    alloc = np.zeros(PG.shape, bool)
    for m in comp_mask:
        alloc |= m
    lab[inside] = code["open_ground"]
    lab[inside & (slope > R.p("slope.housing_max_deg"))] = code["hill"]
    lab[inside & ~house_ok & flood_ex] = code["open_ground"]
    for nm, g in (("field_protected", prot), ("watercourse", None), ("primary_street", corr), ("civic_forecourt", fore_m),
                  ("civic_reserve", env_m), ("market_plaza", mk_m), ("well", well), ("lock", locks)):
        if nm == "watercourse":
            m = water & inside
        else:
            m = Rr.rasterize(PG, g) & inside if g is not None and not g.is_empty else np.zeros(PG.shape, bool)
        lab[m] = code[nm]
        alloc &= ~m
    # ------------------------------------------------------------- distances (Euclidean, world m)
    corr_lines = [C.g(l["centerline"]) for l in (fr.get("primary_corridors") or {}).get("links", [])]
    corr_line_m = Rr.rasterize(PG, union([l.buffer(cell * 0.75) for l in corr_lines])) if corr_lines else np.zeros(PG.shape, bool)
    d_corr = _dist_to(corr_line_m, cell)
    gates = main_gate(C)
    g0 = gates[0] if gates else None
    paths = {p["ref"]: p for p in (fr.get("primary_corridors") or {}).get("paths", []) if p["role"] == "gate"}
    chain = []
    if g0 and g0["seq"] in paths:
        chain.append(C.g(paths[g0["seq"]]["centerline"]).buffer(cell * 0.75))
    if market:
        chain.append(mk_m)
    d_app = _dist_to(Rr.rasterize(PG, union(chain)), cell) if chain else np.full(PG.shape, 1e9)
    d_gate = np.hypot(X - g0["xz"][0], Z - g0["xz"][1]) if g0 else np.full(PG.shape, 1e9)
    civ_pts = [c["entrance_socket"] for c in civ if c["key"] in ("dongheon", "jakcheong", "gaeksa", "hyangcheong", "jangdae", "gunchang")]
    d_civ = np.min([np.hypot(X - p[0], Z - p[1]) for p in civ_pts], axis=0) if civ_pts else np.full(PG.shape, 1e9)
    d_mk = _dist_to(Rr.rasterize(PG, mk_m), cell) if market else np.full(PG.shape, 1e9)
    d_water = _dist_to(water, cell)
    farm_or_edge = farm | (~inside)
    d_farm = _dist_to(farm_or_edge, cell)
    d_hill = _dist_to(slope > R.p("slope.housing_max_deg"), cell)
    ring = C.g(fr["wall"]["ring"]) if C.walled else None
    d_wall = _dist_to(Rr.rasterize(PG, ring.buffer(cell)), cell) if ring is not None else np.full(PG.shape, 1e9)
    rg = R.p("layout.district.ranges_m")
    sl = _norm_near(slope, rg["slope_deg"])
    quality = 0.6 * sl + 0.4 * (1 - np.clip(Rf, 0, 1))
    dry = 0.5 * sl + 0.5 * (1 - np.clip(Rf * 2, 0, 1))
    S = {"approach_frontage": _norm_near(d_app, rg["approach_frontage"]),
         "gate_access": _norm_near(d_gate, rg["gate_access"]),
         "civic_access": _norm_near(d_civ, rg["civic_access"]),
         "dry_level": dry, "land_quality": quality,
         "quiet": np.minimum(_norm_far(d_corr, rg["quiet"]), _norm_far(d_mk, rg["quiet"])),
         "transport": _norm_near(d_corr, rg["transport"]),
         "water_compat": _norm_near(d_water, rg["water"])}
    liv_access = {"agriculture": _norm_near(d_farm, rg["livelihood_access"]),
                  "forest_products": _norm_near(d_hill, rg["livelihood_access"]),
                  "fishing": _norm_near(d_water, rg["livelihood_access"]),
                  "salt_or_boat": _norm_near(d_water, rg["livelihood_access"]),
                  "garrison": _norm_near(np.minimum(d_wall, d_gate), rg["livelihood_access"])}
    W = R.p("layout.district.weights")
    # craft water-use compatibility: never upslope of / close to the drinking-water reservation
    craft_ban = np.zeros(PG.shape, bool)
    ws = fr.get("water_access", [])
    if ws:
        wx, wz = ws[0]["xz"]
        wy = float(C.height([wx], [wz])[0])
        dws = np.hypot(X - wx, Z - wz)
        craft_ban = (dws <= R.p("layout.craft.water_supply_setback_m")) & (h >= wy - R.p("layout.craft.upslope_drop_m"))
    # ------------------------------------------------------------- households
    hh = households(C)
    ext = extramural(C, hh)
    # cells per component, quotas per group
    fl, fo = R.p("program.f_lanes"), R.p("program.f_open")
    parea = C.plan["program"]["households"]["parcel_area_m2"]
    cell_a = cell * cell
    alloc_out = np.full(PG.shape, -1, np.int16)
    quota_rep = []
    for ci, m in enumerate(comp_mask):
        cid = f"c{ci + 1:02d}"
        m = m & alloc
        ncell = int(m.sum())
        if ncell == 0:
            continue
        mine = [r for r in hh if r["component"] == cid and not r.get("extramural")]
        need = {}
        for r in mine:
            need[r["group"]] = need.get(r["group"], 0.0) + parea[r["class"]] / (1 - fl - fo) * (1 - fo)
        gross = ncell * cell_a
        tot_need = sum(need.values())
        scale = min(1.0, gross * (1 - fo) / tot_need) if tot_need > 0 else 0.0
        quotas = {g: int(round(v * scale / cell_a)) for g, v in sorted(need.items())}
        quotas["garden_open"] = max(0, ncell - sum(quotas.values()))
        groups = sorted(quotas)
        cost = np.zeros((len(groups),) + PG.shape)
        for k, g in enumerate(groups):
            if g == "garden_open":
                s = 0.5 * _norm_far(d_corr, rg["quiet"]) + 0.3 * np.clip(Rf, 0, 1) + 0.2 * (1 - sl)
            elif g == "ordinary":
                livs = sorted({r["livelihood"] for r in mine if r["group"] == "ordinary"})
                acc = np.mean([liv_access.get(l, quality) for l in livs], axis=0) if livs else quality
                s = W[g]["livelihood_access"] * acc + W[g]["land_quality"] * quality
            else:
                s = sum(wv * S[t] for t, wv in W[g].items())
            cost[k] = 1.0 - s
            if g == "craft":
                cost[k][craft_ban] = 9.0
        labels, rep = allocate(cost, m, [quotas[g] for g in groups], R)
        for k, g in enumerate(groups):
            alloc_out[(labels == k) & m] = code[g]
        rep.update({"component": cid, "cells": ncell, "cell_m": cell, "quota_cells": quotas, "scale": round(scale, 4),
                    "groups": groups})
        quota_rep.append(rep)
    lab[alloc_out >= 0] = alloc_out[alloc_out >= 0]
    # ------------------------------------------------------------- districts & regions (connected parts)
    districts, regions = [], []
    hh_by_cg = {}
    for r in hh:
        if not r.get("extramural"):
            hh_by_cg.setdefault((r["component"], r["group"]), []).append(r)
    comp_of = np.full(PG.shape, -1, np.int16)
    for ci, m in enumerate(comp_mask):
        comp_of[m & (comp_of < 0)] = ci
    nd = 0
    for nm in names:
        m = lab == code[nm]
        if not m.any():
            continue
        L, n = ndimage.label(m, structure=np.ones((3, 3), bool))
        partlist = []
        for k in range(1, n + 1):
            pm = L == k
            jj, ii = np.nonzero(pm)
            partlist.append((int(pm.sum()), int(jj.min()), int(ii.min()), pm))
        partlist.sort(key=lambda t: (-t[0], t[1], t[2]))
        for cnt, _, _, pm in partlist:
            poly = Rr.mask_to_polygon(PG, pm)
            simp = G.polygonal(poly.simplify(cell * 0.5, preserve_topology=True))
            cen = poly.representative_point()
            if nm in GROUPS and nm != "garden_open":
                ci = int(np.bincount(comp_of[pm][comp_of[pm] >= 0]).argmax()) if (comp_of[pm] >= 0).any() else -1
                nd += 1
                districts.append({"_mask": pm, "group": nm, "component": f"c{ci + 1:02d}" if ci >= 0 else None,
                                  "cells": cnt, "area_m2": round(cnt * cell_a, 1), "geometry": C.add(simp),
                                  "xz": [G.r2(cen.x), G.r2(cen.y)], "role": _role(C, nm), "name_ko": KO[nm]})
            else:
                regions.append({"_mask": pm, "kind": nm, "cells": cnt, "area_m2": round(cnt * cell_a, 1),
                                "geometry": C.add(simp), "xz": [G.r2(cen.x), G.r2(cen.y)], "name_ko": KO[nm],
                                "inside_wall": bool(C.walled), "reason": _region_reason(nm)})
    # households to district parts (largest remainder by area)
    for (cid, g), lst in sorted(hh_by_cg.items()):
        parts_ = [d for d in districts if d["component"] == cid and d["group"] == g]
        if not parts_:
            parts_ = [d for d in districts if d["group"] == g]
        if not parts_:
            for r in lst:
                r["district"] = None
            C.request("L3/districts", "no district part for a household group", "district_missing", component=cid, group=g,
                      households=len(lst))
            continue
        alloc_n = largest_remainder({i: p["cells"] for i, p in enumerate(parts_)}, len(lst))
        k = 0
        for i in sorted(alloc_n):
            for _ in range(alloc_n[i]):
                parts_[i].setdefault("_hh", []).append(lst[k])
                k += 1
    # ids (identity registry) + records
    for i, d in enumerate(sorted(districts, key=lambda d: (GROUPS.index(d["group"]), -d["cells"], d["xz"]))):
        d["id"] = C.claim("district", key=f"{d['group']}", xz=d["xz"], tol=40.0, content=d["geometry"])
        mix = {}
        for r in d.get("_hh", []):
            r["district"] = d["id"]
            mix.setdefault(r["class"], {}).setdefault(r["livelihood"], 0)
            mix[r["class"]][r["livelihood"]] += 1
        d["households"] = len(d.get("_hh", []))
        d["household_mix"] = mix
        d["area_budget_m2"] = round(sum(parea[r["class"]] for r in d.get("_hh", [])), 1)
        d["status"] = "proposed"
        d["boundary_note"] = "planning label — not a road or wall; Layer 5 follows actual parcels"
    for r in sorted(regions, key=lambda r: (FIXED.index(r["kind"]) if r["kind"] in FIXED else 99, -r["cells"], r["xz"])):
        r["id"] = C.claim("region", key=r["kind"], xz=r["xz"], tol=40.0, content=r["geometry"])
        r["status"] = "proposed"
    open_sites = open_ground_states(C, regions)
    mk = market_record(C, gates, market, mk_m, districts)
    rec = {"grid": {"x0": PG.x0, "z0": PG.z0, "cell_m": cell, "nx": PG.nx, "nz": PG.nz},
           "labels": names, "main_gate": gates[0] if gates else None, "gate_ranking": gates,
           "districts": [_clean(d) for d in districts], "regions": [_clean(r) for r in regions],
           "households": hh, "allocation": quota_rep, "market": mk, "extramural": ext,
           "open_ground_sites": open_sites,
           "pub04": pub04(C, regions),
           "notes": ["class, wealth and livelihood are separate household attributes; no orientation-based class rule (K7)",
                     "craft subtypes unknown → every craft treated as potentially polluting (hypothesis)",
                     "distances are Euclidean on the 4 m planning grid (network distances deferred)"]}
    C.dgrid = PG
    C.dlab = lab
    C.dnames = names
    C.district_masks = {d["id"]: d["_mask"] for d in districts}
    return rec


def _clean(d):
    return {k: v for k, v in d.items() if not k.startswith("_")}


def _role(C, g):
    if g == "market_trade":
        return "market_frontage" if C.urban else "mixed_residential"
    if g == "ordinary":
        return "mixed_residential"
    return {"clerical": "clerical_residential", "elite": "elite_residential", "craft": "craft_workshops"}[g]


def _region_reason(nm):
    return {"hill": "unbuildable slope kept as land (언덕) — PUB-04", "open_ground": "flood exclusion / unusable fragment kept open (빈터) — PUB-04",
            "garden_open": "f_open budget allocated as 과원·채마 — PUB-04", "watercourse": "mapped water + drainage reserve (물길) — PUB-04",
            "field_protected": "protected farmland (never occupied)", "lock": "story lock (immutable)",
            "civic_reserve": "Layer-2 civic envelope", "market_plaza": "Layer-2 market reserve (program-funded square)",
            "civic_forecourt": "Layer-2 forecourt (reserved void)", "primary_street": "Layer-2 primary corridor",
            "well": "Layer-2 water-supply reservation"}.get(nm, nm)


def allocate(cost, mask, quotas, R):
    """Price iteration (λ) with an interface term, then exact boundary transfers.
    cost: (K, nz, nx); mask: cells to allocate; quotas: cells per group (sum == mask.sum())."""
    K = cost.shape[0]
    beta = R.p("layout.district.interface_beta")
    its = R.p("layout.district.iterations")
    tol = R.p("layout.district.quota_tolerance")
    lam = np.zeros(K)
    q = np.asarray(quotas, float)
    idx = np.nonzero(mask)
    C = cost[:, idx[0], idx[1]]  # K × N
    lab = np.argmin(C, axis=0)
    ker = np.ones((3, 3))
    ker[1, 1] = 0
    full = np.full(mask.shape, -1, np.int16)
    for it in range(its):
        full[idx] = lab
        nb = np.stack([ndimage.convolve((full == k).astype(float), ker, mode="constant")[idx] for k in range(K)])
        tot = C + lam[:, None] - beta * nb
        lab = np.argmin(tot, axis=0)
        cnt = np.bincount(lab, minlength=K).astype(float)
        lam += 0.15 * (cnt - q) / np.maximum(q, 1.0)
    # relabel tiny disconnected parts to their most common neighbour
    full[idx] = lab
    minp = R.p("layout.district.min_part_cells")
    relabelled = 0
    for k in range(K):
        L, n = ndimage.label(full == k, structure=np.ones((3, 3), bool))
        if n <= 1:
            continue
        sizes = np.bincount(L.ravel())[1:]
        for p in range(1, n + 1):
            if sizes[p - 1] >= minp or sizes[p - 1] == sizes.max():
                continue
            pm = L == p
            ring = ndimage.binary_dilation(pm, structure=np.ones((3, 3), bool)) & ~pm & (full >= 0)
            if not ring.any():
                continue
            nbv = np.bincount(full[ring], minlength=K)
            nbv[k] = 0
            if nbv.max() == 0:
                continue
            full[pm] = int(np.argmax(nbv))
            relabelled += int(pm.sum())
    # exact transfers (deterministic): move the cheapest cells from over- to under-quota groups
    lab = full[idx]
    cnt = np.bincount(lab, minlength=K)
    moved = 0
    for _ in range(4 * K):
        out_tol = [k for k in range(K) if abs(cnt[k] - q[k]) > max(1, tol * q[k])]
        if not out_tol:
            break
        a = max(out_tol, key=lambda k: (abs(cnt[k] - q[k]), -k))
        if cnt[a] > q[a]:
            k = a
            cands = [j for j in range(K) if cnt[j] < q[j]]
            if not cands:
                break
            j = max(cands, key=lambda j: (q[j] - cnt[j], -j))
        else:
            j = a
            cands = [k for k in range(K) if cnt[k] > q[k]]
            if not cands:
                break
            k = max(cands, key=lambda k: (cnt[k] - q[k], -k))
        n = int(min(cnt[k] - q[k], q[j] - cnt[j]))
        if n <= 0:
            break
        sel = np.nonzero(lab == k)[0]
        d = C[j, sel] - C[k, sel]
        order = np.lexsort((sel, d))[:n]
        lab[sel[order]] = j
        cnt = np.bincount(lab, minlength=K)
        moved += n
    full[idx] = lab
    lab = full[idx]
    cnt = np.bincount(lab, minlength=K)
    err = [int(cnt[k] - q[k]) for k in range(K)]
    ok = all(abs(e) <= max(1, tol * q[k]) for k, e in enumerate(err))
    out = np.full(mask.shape, -1, np.int16)
    out[idx] = lab
    return out, {"iterations": its, "exact_transfer_cells": int(moved), "relabelled_cells": relabelled,
                 "quota_error_cells": dict(zip(range(K), err)), "within_tolerance": bool(ok),
                 "lambda": [round(float(v), 4) for v in lam]}


def households(C):
    """One record per programmed household (assigned exactly once later): class, livelihood,
    district group, component. Livelihoods are spread over components in proportion to the
    class counts (largest remainder, deterministic)."""
    prog = C.plan["program"]["households"]
    groups = C.R.p("layout.district.groups")
    by_comp = prog.get("by_component", {})
    liv = prog.get("livelihood", {})
    out = []
    n = 0
    for cls in ("elite", "specialist", "ordinary"):
        comps = sorted(c for c in by_comp if by_comp[c].get(cls, 0) > 0)
        lv = liv.get(cls, {})
        remaining = dict(lv)
        for ci, c in enumerate(comps):
            k = by_comp[c][cls]
            if ci == len(comps) - 1:
                share = dict(remaining)
            else:
                share = largest_remainder({l: remaining[l] for l in remaining}, k) if sum(remaining.values()) else {}
            for l in sorted(share):
                remaining[l] -= share[l]
            # pad if livelihoods are fewer than households (should not happen)
            seq = [l for l in sorted(share) for _ in range(share[l])]
            while len(seq) < k:
                seq.append("unknown")
            for l in seq[:k]:
                n += 1
                out.append({"id": f"hh:{C.scope}:{n:04d}", "class": cls, "livelihood": l,
                            "group": groups.get(l, "ordinary"), "component": c, "district": None, "parcel": None})
    return out


def extramural(C, hh):
    """Outside-wall hamlets on dry edges of paddies beside existing approaches (L3-8 §1)."""
    R, A = C.R, C.A
    cfg = R.p("layout.extramural")
    rec = {"applies": bool(C.walled and cfg["applies_to_walled"]), "hamlets": [], "moved": 0, "unplaced": 0,
           "rule": "agriculture_share of agriculture households; 5–15 per cluster; dry paddy edges; never protected farmland"}
    C.hamlets = []
    if not rec["applies"]:
        rec["reason"] = "unwalled settlement (households already live in clusters)" if not C.walled else "rule disabled"
        return rec
    agri = [r for r in hh if r["livelihood"] == "agriculture"]
    want = int(math.floor(len(agri) * cfg["agriculture_share"]))
    if want < cfg["cluster_min"]:
        rec["reason"] = f"{want} households < cluster minimum {cfg['cluster_min']}"
        return rec
    win = A.win
    allowed_m = Rr.rasterize(win, C.allowed)
    terr_m = Rr.rasterize(win, C.territory.buffer(10.0))
    farm = A.farmland
    if not farm.any():
        rec["reason"] = "no paddy/field data in the window — no dry paddy edge to settle"
        return rec
    d_farm = ndimage.distance_transform_edt(~farm) * win.cell
    m = (allowed_m & ~terr_m & A.house_ok & ~A.protected & ~farm & ~A.locks & ~A.neigh_mask & ~A.anchor_mask
         & (d_farm <= cfg["paddy_edge_m"]) & np.isfinite(A.route_cost) & (A.route_cost <= cfg["approach_max_m"]))
    if not m.any():
        rec["reason"] = "no dry paddy-edge land inside the allowed envelope outside the wall"
        return rec
    L, n = ndimage.label(m, structure=np.ones((3, 3), bool))
    comps = []
    for k in range(1, n + 1):
        pm = L == k
        rc = float(A.route_cost[pm].min())
        comps.append((rc, int(pm.sum()), k, pm))
    comps.sort(key=lambda t: (t[0], -t[1], t[2]))
    fl, fo = R.p("program.f_lanes"), R.p("program.f_open")
    parea = C.wa(C.R.p("layout.parcels.roles")["village_ordinary"]["area"][0] * 1.5)
    moving = sorted(agri, key=lambda r: r["id"])[-want:]
    left = list(moving)
    for rc, cnt, k, pm in comps:
        if len(left) < cfg["cluster_min"]:
            break
        area = cnt * win.cell ** 2
        cap = int(area * (1 - fl - fo) // parea)
        take = min(cap, cfg["cluster_max"], len(left))
        if take < cfg["cluster_min"]:
            continue
        need = take * parea / (1 - fl - fo)
        jj, ii = np.nonzero(pm & (A.route_cost <= rc + 1e-6))
        cx, cz = win.xz(int(ii[0]), int(jj[0]))
        poly = Rr.mask_to_polygon(win, pm)
        rad = math.sqrt(need * 1.6 / math.pi)
        hp = G.polygonal(poly.intersection(Point(cx, cz).buffer(rad, 16)))
        hp = G.largest(G.polygonal(hp.simplify(2.0, preserve_topology=True)))
        if hp.is_empty or hp.area < 0.6 * need:
            hp = G.largest(G.polygonal(poly.simplify(2.0, preserve_topology=True)))
        grp, left = left[:take], left[take:]
        hid = C.claim("hamlet", key=None, xz=[G.r2(cx), G.r2(cz)], tol=60.0, content=G.to_geojson(hp))
        for r in grp:
            r["extramural"] = True
            r["hamlet"] = hid
            r["component"] = None
            r["group"] = "ordinary"
        C.hamlets.append({"id": hid, "poly": hp, "households": [r["id"] for r in grp], "anchor": (cx, cz)})
        C.reason(hp.boundary, "hamlet_extent", hid)
        rec["hamlets"].append({"id": hid, "geometry": C.add(hp), "households": take, "area_m2": round(hp.area, 1),
                               "route_cost_m": round(rc, 1), "anchor_xz": [G.r2(cx), G.r2(cz)],
                               "basis": "dry edge of paddies (≤ paddy_edge_m), housing-buildable, not protected/farmland, near an approach",
                               "status": "proposed"})
    moved = sum(h["households"] for h in rec["hamlets"])
    rec["moved"] = moved
    rec["unplaced"] = want - moved
    rec["requested"] = want
    if rec["unplaced"]:
        rec["unplaced_note"] = "households that found no hamlet land stay inside the wall (no silent drop)"
    return rec


def market_record(C, gates, market, mk_m, districts):
    """Inside market (Layer-2 reserve) + the outside-gate variant (always evaluated)."""
    A, R = C.A, C.R
    rec = {"placement_rule": R.p("layout.market.placement"), "funded_stalls": C.profile["market_stalls"]["value"],
           "inside": None, "outside_gate": None, "selected": None}
    if market:
        rec["inside"] = {"reserve": market["id"], "envelope": market["envelope"], "area_m2": market["area_m2"],
                         "frontage_districts": [d.get("id") for d in districts if d["group"] == "market_trade"]}
        rec["selected"] = "inside"
    if not C.walled or not gates or not market:
        rec["outside_gate"] = {"evaluated": False, "reason": "unwalled or no market program/gate"}
        if not market and rec["funded_stalls"]:
            rec["selected"] = None
            C.request("L3/market", "program funds stalls but no market reserve was placed", "market_missing")
        return rec
    g = gates[0]
    gx, gz = g["xz"]
    c = C.territory.centroid
    ox, oz = gx - c.x, gz - c.y
    n = math.hypot(ox, oz) or 1.0
    ox, oz = ox / n, oz / n
    depth = market["depth_m"]
    width = market["width_m"]
    cx, cz = gx + ox * (10.0 + depth / 2), gz + oz * (10.0 + depth / 2)
    b = G.bearing_of(ox, oz)
    rect = G.oriented_rect(cx, cz, width, depth, b)
    bad = union([C.territory.buffer(2.0), A.protected_poly, A.water_poly, A.flood_polys[R.p("flood.exclusion_offset")],
                 A.neigh_poly, union([l["geom"] for l in C.inp.locks]), A.farm_poly])
    ok_part = G.polygonal(rect.intersection(C.allowed).difference(bad))
    slope_ok = float(np.mean(C.sample(A.slope, [ok_part.centroid.x], [ok_part.centroid.y]) <= R.p("slope.civic_max_deg"))) if not ok_part.is_empty else 0.0
    feasible = (not ok_part.is_empty) and ok_part.area >= 0.8 * rect.area and slope_ok >= 1.0
    rec["outside_gate"] = {"evaluated": True, "gate": g["id"], "geometry": C.add(rect), "area_m2": round(rect.area, 1),
                           "usable_m2": round(ok_part.area, 1), "feasible": bool(feasible),
                           "connects_to": "same civic approach (main gate path)",
                           "applied": R.p("layout.market.placement") == "outside_gate" and feasible,
                           "status": "proposed",
                           "reason": ("allowed, dry, level land beside the main-gate approach" if feasible else
                                      "outside land blocked (allowed envelope / protected / flood / water / slope)")}
    if rec["outside_gate"]["applied"]:
        rec["selected"] = "outside_gate"
        C.outside_market = rect
    return rec


STATE_USE = {"peacetime": {"use": "passage · drying · grazing (hypothesis)"}, "drill": {"use": "조련 (event state)"},
             "archery": {"use": "활쏘기 (event state)"}}


def open_ground_states(C, regions):
    """PUB-05 / V70: event occupation of 성안 빈터 is a state, not permanent geometry."""
    out = []
    if not (C.walled and C.kind in ("eupchi", "fortress")):
        return out
    for r in regions:
        if r["kind"] != "open_ground" or r["area_m2"] < 400:
            continue
        sid = C.claim("activity", key=f"open_ground:{r['id']}", content=r["geometry"])
        out.append({"id": sid, "activity": "open_ground_use", "region": r["id"], "users": ["town"],
                    "spaces": {"ground": r["geometry"]},
                    "state": "peacetime",
                    "states": [dict(STATE_USE.get(k, {"use": k}), key=k, permanent_geometry=False,
                                    props=[] if k == "peacetime" else ["temporary only"])
                               for k in C.R.p("layout.open_ground.states")],
                    "status": "proposed", "hypothesis": True,
                    "basis": "PUB-05: one open ground carries several event states (별방 record); no permanent event props"})
    return out


def pub04(C, regions):
    kinds = sorted({r["kind"] for r in regions if r["kind"] in ("open_ground", "garden_open", "hill", "watercourse", "field_protected")})
    area = {k: round(sum(r["area_m2"] for r in regions if r["kind"] == k), 1) for k in kinds}
    gdn = round(sum(r["area_m2"] for r in regions if r["kind"] == "garden_open"), 1)
    return {"walled": C.walled, "non_built_kinds": kinds, "area_m2": area, "garden_open_m2": gdn,
            "pass": (not C.walled) or bool(kinds),
            "rule": "PUB-04: walled interiors keep open ground, gardens/orchards, hills and watercourses as regions"}
