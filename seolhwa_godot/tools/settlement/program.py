"""Layer 1 — capacity-first settlement program (spec 2회차 §1).

Tier selects obligations and proportions; household counts come from the land.
All historical dimensions are scaled exactly once here (lengths ×1.2, areas ×1.44).
"""
from __future__ import annotations

import itertools
import math

import shapely
from shapely.geometry import Polygon

from . import geometry as G
from .model import diag
from .rules import val

CLASS_ORDER = ("elite", "specialist", "ordinary")


# ------------------------------------------------------------------ scaling (once)
def building_factor(rules) -> float:
    """The one building/plot scale (RegionProfile.scale_policy.building.factor, audit K1).
    Rules keep measured (historical) values; this factor is applied exactly once here."""
    return rules.p("world.length_scale")


def world_len(hist_m: float, rules) -> float:
    return hist_m * building_factor(rules)


def world_area(hist_m2: float, rules) -> float:
    f = building_factor(rules)
    return hist_m2 * f * f


def largest_remainder(shares: dict, n: int, order=None) -> dict:
    order = list(order or sorted(shares))
    tot = sum(shares[k] for k in order)
    raw = {k: n * shares[k] / tot if tot > 0 else 0.0 for k in order}
    base = {k: int(math.floor(raw[k] + 1e-12)) for k in order}
    left = n - sum(base.values())
    rema = sorted(order, key=lambda k: (-(raw[k] - base[k]), order.index(k)))
    for k in rema[:left]:
        base[k] += 1
    return base


# ------------------------------------------------------------------ institutions
def institutions(profile: dict, rules) -> list[dict]:
    """Resolved (world-space) institution records with variants, largest first."""
    tf = val(profile["institution_area_factor"])
    k = math.sqrt(tf)
    out = []
    for key in profile["institutions"]:
        spec = rules.institution(key)
        variants = {}
        for vname in ("full", "compact"):
            v = spec["variants"][vname]
            w = world_len(val(v["width"]) * k, rules)
            d = world_len(val(v["depth"]) * k, rules)
            variants[vname] = {
                "width_m": round(w, 2), "depth_m": round(d, 2), "area_m2": round(w * d, 2),
                "entrance_clearance_m": val(v["entrance_clearance"]),
                "court_min_m2": round(world_area(val(v["court_min_m2"]) * tf, rules), 1),
                "contents": list(v["contents"]),
                "hist_area_m2": round(val(v["width"]) * val(v["depth"]) * tf, 2),
            }
        out.append({"key": key, "name": spec["name"], "inside_wall": spec["inside_wall"], "variants": variants})
    stalls = val(profile["market_stalls"])
    if stalls > 0:
        a = world_area(stalls * rules.p("program.market_stall_m2"), rules)
        ac = world_area(math.ceil(stalls * 0.6) * rules.p("program.market_stall_m2"), rules)
        mk = lambda A, n: {"width_m": round(math.sqrt(2 * A), 2), "depth_m": round(math.sqrt(A / 2), 2),
                           "area_m2": round(A, 2), "entrance_clearance_m": 4.0, "court_min_m2": 0.0,
                           "contents": [f"{n} stalls (15 m² each incl. circulation, ×1.44)"],
                           "hist_area_m2": round(n * rules.p("program.market_stall_m2"), 2)}
        out.append({"key": "market", "name": "장터", "inside_wall": True,
                    "variants": {"full": mk(a, stalls), "compact": mk(ac, math.ceil(stalls * 0.6))}})
    out.sort(key=lambda r: (-r["variants"]["full"]["area_m2"], r["key"]))
    return out


def bundles(insts: list[dict]) -> list[dict]:
    """All full/compact combinations of inside-wall institutions, largest total area first."""
    keys = [r["key"] for r in insts if r["inside_wall"]]
    rec = {r["key"]: r for r in insts}
    out = []
    for combo in itertools.product(("full", "compact"), repeat=len(keys)):
        sel = dict(zip(keys, combo))
        area = sum(rec[k]["variants"][v]["area_m2"] for k, v in sel.items())
        out.append({"variants": sel, "area_m2": round(area, 2),
                    "name": "+".join(f"{k}:{v[0]}" for k, v in sel.items())})
    out.sort(key=lambda b: (-b["area_m2"], b["name"]))
    return out


# ------------------------------------------------------------------ households
def parcel_areas(profile: dict, rules) -> dict:
    med = val(profile["parcel_median_m2"])
    return {c: round(world_area(med[c], rules), 4) for c in CLASS_ORDER}


def solve_households(components: list[tuple[str, float]], profile: dict, rules) -> dict:
    """Max represented households N s.t. integer per-component packing fits.

    components: (id, effective parcel area = (1-f_lanes-f_open)*A_j).
    Class counts: largest remainder of profile shares; packing: greedy, then exact
    bounded DFS (_pack). `optimal` is false if a larger N hit the DFS node limit.
    """
    shares = val(profile["class_shares"])
    a = parcel_areas(profile, rules)
    total = sum(e for _, e in components)
    amin = min(a.values())
    upper = int(total // amin) if amin > 0 else 0
    tried = 0
    uncertain = False
    for n in range(upper, -1, -1):
        tried += 1
        counts = largest_remainder(shares, n, CLASS_ORDER)
        need = sum(counts[c] * a[c] for c in CLASS_ORDER)
        if need > total + 1e-9:
            continue
        assign, method = _pack(counts, a, components)
        if assign is None and method == "greedy_lower_bound":
            uncertain = True
        ok = assign is not None
        if ok:
            return {"N": n, "by_class": counts, "by_component": assign, "parcel_area_m2": a,
                    "parcel_area_used_m2": round(need, 2), "effective_area_m2": round(total, 2),
                    "search": {"upper": upper, "tried": tried, "exhausted": False, "method": method,
                               "optimal": not uncertain}}
    return {"N": 0, "by_class": {c: 0 for c in CLASS_ORDER}, "by_component": {}, "parcel_area_m2": a,
            "parcel_area_used_m2": 0.0, "effective_area_m2": round(total, 2),
            "search": {"upper": upper, "tried": tried, "exhausted": True}}


def _pack(counts, a, components, node_limit=200000):
    """Integer assignment of households to components (capacity per component).

    Greedy first; if it fails, exact depth-first search over per-component class counts
    (memoized on remaining demand) with a node limit. Returns (assignment, method).
    """
    order = sorted(CLASS_ORDER, key=lambda c: -a[c])
    rem = [[cid, e] for cid, e in components]
    assign = {cid: {c: 0 for c in CLASS_ORDER} for cid, _ in components}
    ok = True
    for c in order:
        for _ in range(counts[c]):
            rem.sort(key=lambda t: (-t[1], t[0]))
            if not rem or rem[0][1] + 1e-9 < a[c]:
                ok = False
                break
            rem[0][1] -= a[c]
            assign[rem[0][0]][c] += 1
        if not ok:
            break
    if ok:
        return assign, "greedy"
    comps = list(components)
    nodes = [0]
    seen = set()

    def fill(i, need):
        if all(v == 0 for v in need):
            return {}
        if i >= len(comps):
            return None
        key = (i, need)
        if key in seen:
            return None
        nodes[0] += 1
        if nodes[0] > node_limit:
            raise TimeoutError
        cid, cap = comps[i]
        rest_cap = sum(e for _, e in comps[i:])
        if sum(n * a[c] for n, c in zip(need, order)) > rest_cap + 1e-9:
            seen.add(key)
            return None
        # enumerate class counts for this component, largest classes first
        def rec(k, left, take):
            if k == len(order):
                nxt = tuple(n - t for n, t in zip(need, take))
                sub = fill(i + 1, nxt)
                if sub is not None:
                    sub[cid] = dict(zip(order, take))
                return sub
            c = order[k]
            mx = min(need[k], int((left + 1e-9) // a[c]))
            for t in range(mx, -1, -1):
                r = rec(k + 1, left - t * a[c], take + (t,))
                if r is not None:
                    return r
            return None
        out = rec(0, cap, ())
        if out is None:
            seen.add(key)
        return out
    try:
        res = fill(0, tuple(counts[c] for c in order))
    except TimeoutError:
        return None, "greedy_lower_bound"
    if res is None:
        return None, "exact"
    full = {cid: {c: 0 for c in CLASS_ORDER} for cid, _ in components}
    for cid, d in res.items():
        full[cid].update(d)
    return full, "exact"


def livelihoods(by_class: dict, profile: dict) -> dict:
    cond = val(profile["livelihood_given_class"])
    out = {}
    for c in CLASS_ORDER:
        n = by_class.get(c, 0)
        dist = cond.get(c, {})
        if n and dist:
            out[c] = largest_remainder(dist, n)
    return out


# ------------------------------------------------------------------ ledger
def _diff(a, b):
    # full-precision overlay keeps the partition additive (ledger residual ≤ 0.1 m²);
    # output geometry is snapped to the grid only when serialized
    if a.is_empty or b is None or b.is_empty:
        return a
    return G.polygonal(a.difference(b))


def _inter(a, b):
    if a.is_empty or b is None or b.is_empty:
        return Polygon()
    return G.polygonal(a.intersection(b))


def partition(T, A, reserves: list[tuple[str, object]], access_geom, rules):
    """Mutually exclusive partition of territory T by precedence.

    reserves: ordered (category, geometry) occupied reservations (civic, corridors,
    water access...). Returns (ledger entries, residential components, fragments).
    """
    # vertices are already on the 0.05 m grid; overlays run in floating precision
    # (a stored precision model would snap-round every intersection and break additivity)
    T = G.unsnap(G.polygonal(shapely.set_precision(T, G.GRID)))
    reserves = [(c, G.unsnap(g)) for c, g in reserves]
    remaining = T
    entries = []
    pre = [("water", G.unsnap(A.water_poly)), ("drainage_reserve", G.unsnap(A.drain_poly)),
           ("protected", G.unsnap(A.protected_poly)), ("locks", G.unsnap(A.lock_poly))]
    for cat, g in pre + list(reserves) + [("flood_exclusion", G.unsnap(A.flood_polys[rules.p("flood.exclusion_offset")]))]:
        piece = _inter(remaining, g)
        remaining = _diff(remaining, piece)
        entries.append({"category": cat, "area_m2": piece.area, "geom": piece})
    unb = _diff(remaining, G.unsnap(A.house_poly))
    remaining = _diff(remaining, unb)
    entries.append({"category": "unbuildable_slope", "area_m2": unb.area, "geom": unb})
    min_a = rules.p("residential.min_component_area_m2")
    min_w = rules.p("residential.min_component_width_m")
    acc = rules.p("residential.access_max_m")
    comps, frags = [], []
    for p in G.parts(remaining):
        reason = None
        if p.area < min_a:
            reason = "below_min_area"
        elif p.buffer(-min_w / 2).is_empty:
            reason = "below_min_width"
        elif access_geom is not None and (access_geom.is_empty or not p.intersects(access_geom)):
            reason = "inaccessible"
        (frags if reason else comps).append((p, reason))
    res = G.polygonal(shapely.union_all([p for p, _ in comps])) if comps else Polygon()
    frag = G.polygonal(shapely.union_all([p for p, _ in frags])) if frags else Polygon()
    entries.append({"category": "residential_gross", "area_m2": res.area, "geom": res})
    entries.append({"category": "unusable_fragment", "area_m2": frag.area, "geom": frag,
                    "reasons": sorted({r for _, r in frags})})
    total = sum(e["area_m2"] for e in entries)
    return T, entries, comps, frags, T.area - total


def ledger_record(T, entries, residual, rules, comps_eff):
    fl, fo = rules.p("program.f_lanes"), rules.p("program.f_open")
    res = next(e for e in entries if e["category"] == "residential_gross")["area_m2"]
    return {
        "territory_m2": round(T.area, 2),
        "categories": [{"category": e["category"], "area_m2": round(e["area_m2"], 2)} for e in entries],
        "residential_split": {"parcels_m2": round(res * (1 - fl - fo), 2), "lanes_m2": round(res * fl, 2),
                              "open_cultivated_m2": round(res * fo, 2), "f_lanes": fl, "f_open": fo},
        "components": [{"id": cid, "effective_m2": round(e, 2)} for cid, e in comps_eff],
        "residual_m2": round(residual, 4),
    }


def program_record(profile_name, profile, insts, bundle, hh, rules, historical=None):
    hsize = rules.p("program.household_size")
    N = hh["N"]
    rec = {
        "profile": profile_name,
        "profile_name": profile["name"],
        "scale": {"length": rules.p("world.length_scale"), "area": rules.p("world.area_scale"),
                  "scale_applied": True, "note": "historical dimensions scaled once in program.py; all exported values are world metres"},
        "households": {"represented": N, "by_class": hh["by_class"], "livelihood": livelihoods(hh["by_class"], profile),
                       "population_estimate": round(N * hsize, 1), "status": "planning_capacity_estimate",
                       "parcel_area_m2": hh["parcel_area_m2"], "search": hh["search"],
                       "by_component": hh["by_component"]},
        "residential_minimum": val(profile["residential_min_households"]),
        "institutions": [],
        "historical_households": historical,
        "representation_ratio": (round(N / historical, 4) if historical else None),
    }
    for r in insts:
        v = bundle["variants"].get(r["key"]) if bundle else None
        rec["institutions"].append({
            "key": r["key"], "name": r["name"], "inside_wall": r["inside_wall"],
            "variant": v if v else ("extramural_deferred" if not r["inside_wall"] else None),
            "envelope": r["variants"][v] if v else r["variants"]["full"]})
    return rec


def standalone(A, rules, profile_name: str, historical=None, territory: str = "preferred"):
    """Layer 1 on the allocation alone (area-only civic bundle choice).
    territory='allowed' estimates what the whole planning envelope could hold (ranking target)."""
    profile = rules.profile(profile_name)
    insts = institutions(profile, rules)
    if territory == "allowed":
        T = G.polygonal(A.inp.territory["allowed"].difference(A.neigh_poly)) if not A.neigh_poly.is_empty \
            else A.inp.territory["allowed"]
    else:
        T = G.polygonal(A.inp.territory["preferred"].intersection(A.inp.territory["allowed"]))
    # no corridors exist yet: access is not filtered here (Layer 2 re-solves with walking reach)
    T, entries, comps, frags, residual = partition(T, A, [], None, rules)
    fl, fo = rules.p("program.f_lanes"), rules.p("program.f_open")
    usable = sum(p.area for p, _ in comps)
    corridor_est = rules.p("routing.corridor_width_m") * 2 * math.sqrt(max(usable, 0))
    wres = rules.p("water_access.reservation_m") ** 2
    a = parcel_areas(profile, rules)
    shares = val(profile["class_shares"])
    nmin = val(profile["residential_min_households"])
    cmin = largest_remainder(shares, nmin, CLASS_ORDER)
    need_min = sum(cmin[c] * a[c] for c in CLASS_ORDER) / (1 - fl - fo)
    diags = []
    chosen = None
    blist = bundles(insts)
    for b in blist:
        civ = sum(insts_by(insts, k)["variants"][v]["area_m2"] + insts_by(insts, k)["variants"][v]["entrance_clearance_m"] *
                  insts_by(insts, k)["variants"][v]["width_m"] * 0.6 for k, v in b["variants"].items())
        if usable - civ - corridor_est - wres >= need_min:
            chosen = (b, civ)
            break
    if chosen is None:
        b = blist[-1] if blist else {"variants": {}, "area_m2": 0.0, "name": "none"}
        civ = sum(insts_by(insts, k)["variants"][v]["area_m2"] for k, v in b["variants"].items())
        chosen = (b, civ)
        diags.append(diag("insufficient_capacity", "error", "L1",
                          "allocation cannot hold the smallest civic bundle plus the residential minimum",
                          usable_m2=round(usable, 1), civic_m2=round(civ, 1), residential_min_m2=round(need_min, 1)))
    b, civ = chosen
    eff_total = max(0.0, usable - civ - corridor_est - wres)
    scale = eff_total / usable if usable > 0 else 0.0
    comps_eff = [(f"c{i + 1:02d}", p.area * scale * (1 - fl - fo)) for i, (p, _) in enumerate(comps)]
    hh = solve_households(comps_eff, profile, rules)
    if hh["N"] < nmin and not diags:
        diags.append(diag("insufficient_capacity", "error", "L1", "represented households below profile minimum",
                          households=hh["N"], minimum=nmin))
    prog = program_record(profile_name, profile, insts, b, hh, rules, historical)
    prog["bundle"] = {"name": b["name"], "area_m2": b["area_m2"], "civic_with_clearance_m2": round(civ, 1),
                      "tried": [x["name"] for x in blist[:blist.index(b) + 1]] if b in blist else []}
    prog["estimates"] = {"corridor_m2": round(corridor_est, 1), "water_reservation_m2": wres,
                         "note": "standalone L1: civic/corridor areas are estimates; Layer 2 re-solves with placed geometry"}
    led = ledger_record(T, entries, residual, rules, comps_eff)
    led["estimated_deductions_m2"] = {"civic": round(civ, 1), "corridors": round(corridor_est, 1), "water_reservation": wres}
    return {"program": prog, "ledger": led, "territory": T, "entries": entries, "components": comps,
            "fragments": frags, "insts": insts, "bundles": blist, "diagnostics": diags, "profile": profile}


def insts_by(insts, key):
    for r in insts:
        if r["key"] == key:
            return r
    raise KeyError(key)
