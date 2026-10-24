"""Adaptive siting (owner correction 2026-10-25): the builder always produces a believable
settlement on the given site by adapting the way Joseon builders did, instead of returning
`insufficient_capacity` / `no_candidate_found` as a final answer.

When the standard Layer 0–2 solve finds no valid frame, a fixed ladder of adaptations is tried
in order (the first that yields a valid frame wins; every step taken is recorded):

1. raised_platforms_and_terraces — flood-screen land is buildable only on raised 기단/집터 and
   slopes up to the terrace limit on 축대/석축 benches (resolved SiteTreatment records in WP5;
   the hazard fields themselves are never changed).
2. dry_bench_site_extent — the automatic planning envelope: higher dry benches around the allocation.
3. clusters_unwalled(_site_extent) — the same program as connected unwalled clusters.
4. steep_terraces — the steeper terrace limit on the extended site.
5. compact_functional_forms_on_benches — every institution keeps its function in its compact form
   (× factor) and may sit on a bench.
The tier and its institutions are never downgraded or deleted. A valid result below a quarter of
the program's household budget is kept as a fallback while fuller adaptations are tried; the
fullest one wins. Household counts are reported explicitly (they follow the land).

Story locks stay immutable throughout (they are never relaxed). No per-city special case is
used: the ladder and its limits are rules values applied to every site.
"""
from __future__ import annotations

import copy
import hashlib
import json

import numpy as np
from shapely.geometry import Polygon

from . import envelope, frame, program, site
from . import raster as Rr
from .rules import val

def adapted_rules(rules, slope_house, slope_civic, tag):
    R2 = copy.deepcopy(rules)
    P = R2.data["parameters"]
    P["slope.housing_max_deg"]["value"] = max(P["slope.housing_max_deg"]["value"], slope_house)
    P["slope.civic_max_deg"]["value"] = max(P["slope.civic_max_deg"]["value"], slope_civic)
    for name, prof in R2.data["profiles"].items():
        prof["residential_min_households"]["value"] = 1
    R2.hash = hashlib.sha256((rules.hash + "|adapt:" + tag + json.dumps(
        {"slope_house": slope_house, "slope_civic": slope_civic, "residential_min": 1}, sort_keys=True)).encode()).hexdigest()
    R2.adapted_from = rules.hash
    return R2


def minimal_civic(R2, factor):
    """Smallest form of every institution (compact variant scaled): e.g. a 당산나무 and 정자
    without a large 마당, a well with a small apron — a recorded design adaptation."""
    R4 = copy.deepcopy(R2)
    for key, spec in R4.data["institution_variants"].items():
        v = spec["variants"]["compact"]
        for k in ("width", "depth"):
            v[k]["value"] = round(v[k]["value"] * factor, 3)
        v["court_min_m2"]["value"] = round(v["court_min_m2"]["value"] * factor * factor, 3)
    # compact compounds on narrow benches: smaller house plots, less open garden per bench
    for prof in R4.data["profiles"].values():
        pm = prof["parcel_median_m2"]["value"]
        prof["parcel_median_m2"]["value"] = {k: round(v * factor, 1) for k, v in pm.items()}
    R4.data["parameters"]["program.f_open"]["value"] = min(R4.data["parameters"]["program.f_open"]["value"], 0.1)
    R4.hash = hashlib.sha256((R2.hash + f"|minimal_civic:{factor}").encode()).hexdigest()
    return R4


def relax(A, rules0, R2):
    """Raised platforms over the flood screen + terraces on steeper ground (buildability only;
    water, drainage reserves, protected land and locks stay excluded)."""
    A2 = copy.copy(A)
    base_ex = A.water | A.drain | ~A.cov
    A2.house_ok = (A.slope <= R2.p("slope.housing_max_deg")) & ~base_ex
    A2.civic_ok = (A.slope <= R2.p("slope.civic_max_deg")) & ~base_ex
    from scipy import ndimage
    # one-cell margin so reserves snapped to cell edges never touch protected land or locks
    occ = ndimage.binary_dilation(A.protected | A.locks, iterations=1)
    A2.house_poly = Rr.mask_to_polygon(A.win, A2.house_ok & ~occ)
    A2.civic_poly = Rr.mask_to_polygon(A.win, A2.civic_ok & ~occ & ~A.anchor_mask)
    A2.flood_polys_orig = getattr(A, "flood_polys_orig", A.flood_polys)
    A2.flood_ex_orig = getattr(A, "flood_ex_orig", A.flood_ex)
    fp = dict(A.flood_polys)
    fp[A.stage_ex] = Polygon()
    A2.flood_polys = fp
    A2.flood_ex = np.zeros_like(A.flood_ex)
    A2.raised = A2.flood_ex_orig & A2.house_ok
    A2.terraced = A2.house_ok & (A.slope > rules0.p("slope.housing_max_deg"))
    return A2


def _solve(A, R, tier, family, hist):
    L1 = program.standalone(A, R, tier, hist)
    F = frame.solve(A, L1, R, family)
    return L1, F


def ladder(inp, A, rules, family, L1, F):
    """Return (inp, A, rules, family, L1, F, record). Unchanged when the standard solve is valid."""
    rec = {"applied": [], "tried": [], "policy": "owner 2026-10-25: always produce a settlement by adaptation; locks never relaxed"}
    if F["ranked"]:
        return inp, A, rules, family, L1, F, None
    rej = {}
    for e in F["evaluated"]:
        for c in e["constraints"]:
            if c["severity"] == "error":
                rej[c["code"]] = rej.get(c["code"], 0) + 1
    rec["initial"] = {"family": family, "tier": inp.tier, "evaluated": len(F["evaluated"]), "rejections": dict(sorted(rej.items())),
                      "L1": [d["code"] for d in L1["diagnostics"]]}
    lim = rules.p("adapt.limits")
    R1 = adapted_rules(rules, lim["terrace_slope_deg"], lim["civic_terrace_slope_deg"], "terraces")
    A1 = relax(A, rules, R1)
    fams = [family] + ([] if family == "unwalled" else ["unwalled"])
    R3 = adapted_rules(rules, lim["steep_terrace_slope_deg"], lim["civic_steep_slope_deg"], "steep")
    # steep sites: longer 고샅 paths up to the benches (walking reach), recorded with the step
    R3.data["parameters"]["residential.access_max_m"]["value"] = lim["steep_access_reach_m"]
    R3.hash = hashlib.sha256((R3.hash + f"|reach:{lim['steep_access_reach_m']}").encode()).hexdigest()
    Rb = adapted_rules(rules, lim["steep_terrace_slope_deg"], lim["steep_terrace_slope_deg"], "bench")
    # last step: every usable bench counts; Layer 4 bends 고샅 (and typed crossings) to reach it
    Rb.data["parameters"]["residential.access_max_m"]["value"] = lim["bench_access_reach_m"]
    # narrow benches (one compound deep) count as house land
    Rb.data["parameters"]["residential.min_component_width_m"]["value"] = lim["bench_min_width_m"]
    Rb.data["parameters"]["residential.min_component_area_m2"]["value"] = lim["bench_min_area_m2"]
    R4 = minimal_civic(Rb, lim["minimal_civic_factor"])
    tier = inp.tier
    # ordered ladder (owner 2026-10-25 / design review): the program (tier, institutions) is kept;
    # the ground, form and footprint adapt. Household counts follow the land and are reported.
    steps = [("raised_platforms_and_terraces", R1, tier, family, False),
             ("dry_bench_site_extent", R1, tier, family, True)]
    if family != "unwalled":
        steps += [("clusters_unwalled", R1, tier, "unwalled", False),
                  ("clusters_unwalled_site_extent", R1, tier, "unwalled", True)]
    steps += [("steep_terraces", R3, tier, f, True) for f in fams]
    steps += [("compact_functional_forms_on_benches", R4, tier, f, True) for f in fams]
    env_cache = {}
    relaxed = {}
    best = None
    prof0 = rules.profile(inp.tier)
    # a result smaller than this is kept only as a fallback while fuller adaptations are tried
    nmin0 = max(val(prof0["residential_min_households"]),
                int(np.ceil(lim["fuller_fraction"] * val(prof0["max_households"]))))
    for name, R_, tier, fam, env in steps:
        inp_ = inp
        if env:
            if "inp" not in env_cache:
                i2 = copy.copy(inp)
                i2.diagnostics = [d for d in inp.diagnostics if d["code"] != "expansion_zero"]
                i2.territory = dict(inp.territory)
                i2.tier = tier
                envelope.auto(i2, rules)
                env_cache["inp"] = i2
                env_cache["A"] = site.analyze(i2, rules)
            inp_ = env_cache["inp"]
        key = (env, R_.hash)
        if key not in relaxed:
            relaxed[key] = relax(env_cache["A"] if env else A, rules, R_)
        A_ = relaxed[key]
        L1_, F_ = _solve(A_, R_, tier, fam, inp.historical_households)
        ok = bool(F_["ranked"])
        rec["tried"].append({"step": name, "family": fam, "tier": tier, "site_extent": env, "valid": ok,
                             "households": F_["ranked"][0]["households"]["N"] if ok else None})
        if ok and F_["ranked"][0]["households"]["N"] < nmin0:
            # valid but smaller than the program minimum: keep as a fallback, try to do better
            if best is None or F_["ranked"][0]["households"]["N"] > best[0]:  # noqa
                best = (F_["ranked"][0]["households"]["N"], (name, R_, tier, fam, env, inp_, A_, L1_, F_))
            continue
        if ok:
            inp2 = copy.copy(inp_)
            inp2.tier = tier
            rec["applied"] = [name] + (["site_extent"] if env and name != "site_extent" else [])
            rec["result"] = {"family": fam, "tier": tier,
                             "households_represented": F_["ranked"][0]["households"]["N"],
                             "program_household_budget": val(prof0["max_households"]),
                             "functions_kept": [r["key"] for r in L1_["insts"]],
                             "raised_platform_m2": round(float(A_.raised.sum()) * A_.win.cell ** 2, 1),
                             "terraced_m2": round(float(A_.terraced.sum()) * A_.win.cell ** 2, 1),
                             "slope_limits_deg": {"housing": R_.p("slope.housing_max_deg"), "civic": R_.p("slope.civic_max_deg")},
                             "residential_minimum": 1, "site_extent": env,
                             "rules_hash": R_.hash, "rules_base_hash": rules.hash}
            return inp2, A_, R_, fam, L1_, F_, rec
    if best is not None:
        name, R_, tier, fam, env, inp_, A_, L1_, F_ = best[1]
        inp2 = copy.copy(inp_)
        inp2.tier = tier
        rec["applied"] = [name] + (["site_extent"] if env and name != "site_extent" else [])
        rec["result"] = {"family": fam, "tier": tier, "below_program_minimum": True,
                         "raised_platform_m2": round(float(A_.raised.sum()) * A_.win.cell ** 2, 1),
                         "terraced_m2": round(float(A_.terraced.sum()) * A_.win.cell ** 2, 1),
                         "slope_limits_deg": {"housing": R_.p("slope.housing_max_deg"), "civic": R_.p("slope.civic_max_deg")},
                         "residential_minimum": 1, "site_extent": env, "rules_hash": R_.hash, "rules_base_hash": rules.hash}
        return inp2, A_, R_, fam, L1_, F_, rec
    rec["result"] = None
    rec["exhausted"] = True
    return inp, A, rules, family, L1, F, rec
