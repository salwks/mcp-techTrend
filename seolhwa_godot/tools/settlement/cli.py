"""settlement-v2 bake CLI (Layers 0–2).

python -m tools.settlement.cli bake --region JL_NAMWON_UNBONG --settlement namwon_eup --out OUT
python -m tools.settlement.cli fixture --name syn_terrace --out OUT
python -m tools.settlement.cli all --out OUT          # 4 synthetic + 4 real + failure fixtures
python -m tools.settlement.cli determinism --out OUT  # bake twice, compare bytes
"""
from __future__ import annotations

import argparse
import filecmp
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys

from . import adapt, envelope, fixtures, frame, geometry as G, layout, plan as PL, program, site, svg, svg_layout, svg_tw, terrain as TR, tw, validate
from . import registry as REG
from .adapters import region as RA
from .rules import DEFAULT, Rules

REAL_SITES = [("JL_NAMWON_UNBONG", "namwon_eup"), ("GS_GYEONGJU", "bulguksa_village"),
              ("JL_NAMWON_UNBONG", "banseon"), ("GW_GANGNEUNG", "anmok_village")]
SYN_SITES = ["syn_terrace", "syn_basin", "syn_ridge", "syn_estuary", "syn_mountain"]  # last one supplementary
WP5_SITES = ["syn_stream", "syn_terrace_locked"]  # supplementary WP5 fixtures (stream through town / story locks)
FAIL_SITES = ["fail_blocked_access", "fail_impossible_civic", "fail_water_crossing"]


def dependencies():
    import networkx, numpy, PIL, scipy, shapely
    return {"python": platform.python_version(), "numpy": numpy.__version__, "scipy": scipy.__version__,
            "shapely": shapely.__version__, "geos": shapely.geos_version_string, "pillow": PIL.__version__,
            "networkx": networkx.__version__}


def dump(path, obj):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, sort_keys=True, ensure_ascii=False, indent=1, allow_nan=False)
        f.write("\n")


def _sanitize(o):
    import math
    import numpy as np
    if isinstance(o, dict):
        return {str(k): _sanitize(v) for k, v in o.items()}
    if isinstance(o, (list, tuple)):
        return [_sanitize(v) for v in o]
    if isinstance(o, (np.bool_,)):
        return bool(o)
    if isinstance(o, (np.integer,)):
        return int(o)
    if isinstance(o, (np.floating, float)):
        v = float(o)
        if not math.isfinite(v):
            return None
        return round(v, 4)
    return o


def input_record(inp, family):
    hm = {"file": "height.png" if not inp.meta.get("fixture") else "fixture:" + inp.id,
          "origin_xz": [inp.grid.x0, inp.grid.z0], "cell_m": inp.grid.cell,
          "decode": {"note": "y_min + v/65535*(y_max-y_min) (region) or analytic (fixture)"},
          "already_remapped": True, "window_shape": [inp.grid.nz, inp.grid.nx]}
    return {"schema": "settlement-input/1", "id": inp.id, "seed": inp.seed,
            "coordinates": {"units": "world_m", "north_xz": [0, -1]}, "height": hm, "tier": inp.tier,
            "wall_type": inp.family if inp.family in ("auto", "plain", "plain_hill", "mountain", "unwalled") else "auto",
            "family_resolved": family,
            "territory": {"preferred": G.to_geojson(inp.territory["preferred"]), "allowed": G.to_geojson(inp.territory["allowed"]),
                          "protected": G.to_geojson(inp.territory.get("protected")), "sources": inp.territory.get("sources", {})},
            "features": "site.geojson", "locks": [], "axes": inp.axes, "historical_households": inp.historical_households,
            "roads": [{"id": r.id, "class": r.klass, "width_m": r.width_m} for r in inp.roads],
            "water": [{"id": f.id, "kind": f.kind, "freshwater": f.freshwater, "width_m": f.width_m} for f in inp.water_features],
            "vertical_scale": inp.vertical_scale, "provenance": inp.provenance.get("input_hashes", {})}


def run(inp, rules, out_dir, label=None, proposal=None, registry=None):
    G.set_grid(rules.p("geometry.grid"))
    os.makedirs(out_dir, exist_ok=True)
    A = site.analyze(inp, rules)
    family = inp.family
    fam_info = {"requested": inp.family}
    if family == "auto":
        family, stats = site.auto_family(A, rules)
        fam_info.update({"resolved": family, "terrain_stats": stats})
    L1 = program.standalone(A, rules, inp.tier, inp.historical_households)
    F = frame.solve(A, L1, rules, family)
    if inp.family == "auto" and not F["ranked"]:
        # terrain statistics are a prior, not a verdict: try the other walled families in fixed order
        tried = [{"family": family, "valid": False, "generated": F["generated"]}]
        for alt in ("plain", "plain_hill", "mountain"):
            if alt == family:
                continue
            F2 = frame.solve(A, L1, rules, alt)
            tried.append({"family": alt, "valid": bool(F2["ranked"]), "generated": F2["generated"]})
            if F2["ranked"]:
                F, family = F2, alt
                break
        fam_info["fallback_tried"] = tried
        fam_info["resolved"] = family
    # owner 2026-10-25: never end with "no settlement" — adapt (raised platforms, terraces,
    # unwalled clusters, smaller program, site extent, steeper terraces); every step recorded
    inp, A, rules, family, L1, F, adapt_rec = adapt.ladder(inp, A, rules, family, L1, F)
    if adapt_rec is not None and getattr(A, "flood_polys_orig", None) is not None:
        A.flood_polys = A.flood_polys_orig   # records and drawings keep the real flood screen
    plan, extras, store = PL.build(inp, A, family, fam_info, L1, F, rules, dependencies())
    plan["adaptation"] = adapt_rec
    plan["validation"] = []
    plan = _sanitize(plan)
    # identity ids (persistent) vs revisions (content) — WP2 / audit K10
    reg = registry if registry is not None else REG.Registry()
    scope = inp.id if proposal is None else f"{inp.id}@proposal"  # proposals never take baseline identities
    from .contract import revision as _rev
    plan["identity"] = REG.assign(plan, reg, rules, scope=scope, retire=False)  # retired after WP5 claims
    plan = _sanitize(plan)
    # WP4 terrain · water layer (own file; plan keeps a reference, revision and check summary)
    layer = _sanitize(tw.build(inp, A, rules, plan))
    reach_of = {}
    for r in layer["water"]["reaches"]:
        reach_of.setdefault(r["feature"], []).append(r["meta"]["stable_id"])
    for wf in plan["site"]["water_features"]:
        wf["reaches"] = reach_of.get(wf["id"], [])
    plan["validation"] = _sanitize(validate.run(plan, inp, A, L1, F, rules))
    layer["checks"] = _sanitize(tw.checks(layer, plan, inp, A, rules))
    inv = [c for c in layer["checks"] if c["kind"] == "invariant"]
    for c in inv:
        plan["validation"].append({"id": c["id"], "layer": "WP4", "pass": c["pass"], "applicable": c["applicable"],
                                   "detail": c["detail"]})
    from .contract import revision as _rev
    plan["terrain_water"] = {"file": "terrain-water.json", "fields": "terrain-fields.npz",
                             "revision": _rev({k: v for k, v in layer.items() if k != "checks"}),
                             "summary": layer["terrain"]["summary"],
                             "reaches": len(layer["water"]["reaches"]), "crossings": len(layer["water"]["crossings"]),
                             "crossing_candidates": len(layer["water"]["crossing_candidates"]),
                             "checks": [{"id": c["id"], "pass": c["pass"], "applicable": c["applicable"], "kind": c["kind"]}
                                        for c in layer["checks"]],
                             "note": "V checks on given data are findings (kind=finding) and do not gate the plan; WP4.layer invariants do"}
    # WP5 Layers 3–5 (own file; only the structural invariant WP5.layer gates the plan)
    lay = _sanitize(layout.build(plan, inp, A, layer, rules, reg, scope))
    plan["layout"] = {"file": "layout.json", "status": lay["status"], "status_reason": lay.get("status_reason") or lay.get("reason"),
                      "revision": _rev({k: v for k, v in lay.items() if k != "checks"}),
                      "summary": lay.get("summary"),
                      "checks": [{"id": c["id"], "pass": c["pass"], "applicable": c["applicable"], "kind": c["kind"]}
                                 for c in lay.get("checks", [])],
                      "revision_requests": len(lay.get("revision_requests", [])),
                      "note": "invariant WP5.layer gates the plan; hard checks make the layout 'incomplete' (with revision requests); V checks are findings"}
    # identities not produced by this accepted bake (L0–2 and WP5 objects) are retired, never reused
    plan["identity"]["retired"] = reg.retire_unclaimed(scope) if plan["status"] in ("valid", "proposed") else []
    plan["identity"]["claimed"] = sum(1 for i in reg.claimed if reg.data["entries"][i]["scope"] == scope)
    for c in lay.get("checks", []):
        if c["kind"] == "invariant":
            plan["validation"].append({"id": c["id"], "layer": "WP5", "pass": c["pass"], "applicable": c["applicable"],
                                       "detail": c["detail"]})
    failed = [c["id"] for c in plan["validation"] if c["pass"] is False]
    if failed and plan["status"] == "valid":
        # independent validation gates publication
        plan["status"] = "failed"
        plan["status_reason"] = "validation:" + ",".join(failed)
        plan["diagnostics"].append({"code": "validation_failed", "severity": "error", "layer": "plan",
                                    "message": "independent checks failed; plan not publishable", "data": {"checks": failed}})
    plan = _sanitize(plan)
    if label:
        plan["variant"] = label
    if proposal is not None:
        # a proposed site change is never published as valid (audit K2)
        plan["proposal"] = proposal
        if plan["status"] == "valid":
            plan["status"] = "proposed"
            plan["status_reason"] = proposal["kind"]
    if plan["status"] not in ("valid", "proposed") and lay.get("export") == "playable":
        lay["export"] = "diagnostic"   # a playable export needs an accepted plan as well
    plan["layout"]["export"] = lay.get("export")
    dump(os.path.join(out_dir, "plan.json"), plan)
    dump(os.path.join(out_dir, "terrain-water.json"), layer)
    dump(os.path.join(out_dir, "layout.json"), lay)
    dump(os.path.join(out_dir, "input.json"), _sanitize(input_record(inp, family)))
    dump(os.path.join(out_dir, "site.geojson"), _sanitize(PL.site_geojson(inp, A)))
    from .raster import write_npz
    write_npz(os.path.join(out_dir, "site-fields.npz"), PL.site_fields(A))
    write_npz(os.path.join(out_dir, "terrain-fields.npz"), TR.fields(A.terrain, A))
    # drawings
    sh = extras.get("shown")
    focus = inp.territory["allowed"]
    if sh is not None and "poly" in sh:
        focus = focus.union(sh["poly"])
    view = svg.view_for(focus.bounds)
    s0 = svg.site_svg(plan, inp, A, view)
    s1 = svg.program_svg(plan, inp, A, L1, extras, view)
    s2 = svg.frame_svg(plan, inp, A, extras, view, F)
    for name, s in (("00-site.svg", s0), ("01-program.svg", s1), ("02-frame.svg", s2)):
        with open(os.path.join(out_dir, name), "w", encoding="utf-8") as f:
            f.write(s)
    title = f"{inp.name} — {inp.region}/{inp.id} · {family} · {plan['status']}" + (f" · {label}" if label else "")
    with open(os.path.join(out_dir, "combined.svg"), "w", encoding="utf-8") as f:
        f.write(svg.combined([s0, s1, s2], title))
    vtw = svg.view_for(A.win.bounds(), margin_frac=0.0, min_margin=0.0)  # whole work window
    s3 = svg_tw.terrain_svg(layer, plan, inp, A, vtw)
    s4 = svg_tw.water_svg(layer, plan, inp, A, vtw)
    s5 = svg_tw.routes_svg(layer, plan, inp, A)
    for name, s in (("03-terrain.svg", s3), ("04-water.svg", s4), ("05-routes.svg", s5)):
        with open(os.path.join(out_dir, name), "w", encoding="utf-8") as f:
            f.write(s)
    with open(os.path.join(out_dir, "combined-terrain-water.svg"), "w", encoding="utf-8") as f:
        f.write(svg.combined([s3, s4, s5], f"{inp.name} — {inp.region}/{inp.id} · WP4 지형·물·길 지지/배수"))
    if lay["status"] != "skipped":
        from shapely.ops import unary_union
        from shapely.geometry import shape as _shape
        hs = [_shape(lay["geometry"][h["geometry"]]) for h in lay["districts"]["extramural"].get("hamlets", [])]
        vl = svg.view_for(unary_union([_shape(plan["geometry"][plan["frame"]["territory"]])] + hs).bounds,
                          margin_frac=0.08, min_margin=30)
        ss = [svg_layout.districts_svg(lay, plan, inp, A, vl), svg_layout.streets_svg(lay, plan, inp, A, vl),
              svg_layout.parcels_svg(lay, plan, inp, A, vl)]
        for name, s_ in zip(("03-districts.svg", "04-streets-water.svg", "05-parcels.svg"), ss):
            with open(os.path.join(out_dir, name), "w", encoding="utf-8") as f:
                f.write(s_)
        with open(os.path.join(out_dir, "combined-layout.svg"), "w", encoding="utf-8") as f:
            f.write(svg.combined(ss, f"{inp.name} — {inp.region}/{inp.id} · WP5 구역·길·물·필지 · layout {lay['status']}"
                                 + (f" · {label}" if label else "")))
    return plan


def summary_line(plan):
    v = plan["validation"]
    props = "".join(f" | proposal {p['proposed']['status']} hh={p['proposed']['households']} +{p['added_area_m2']:.0f}m²"
                    for p in plan.get("proposals", []))
    fails = [c["id"] for c in v if c["pass"] is False]
    fr = plan.get("frame") or {}
    gates = sum(1 for o in (fr.get("openings") or []) if o["type"] == "gate")
    lay = plan.get("layout") or {}
    return (f"{plan['id']:<24} {plan['status']:<22} hh={plan['program']['households']['represented']:<4} "
            f"gates={gates} alts={len(plan['alternatives'])} checks_failed={fails} layout={lay.get('status')}{props}")


def _auto(inp, rules):
    inp.diagnostics = [d for d in inp.diagnostics if d["code"] != "expansion_zero"]
    envelope.auto(inp, rules)
    return inp


def run_real(reg, st, rules, out_dir, label=None, propose=True, **load_kw):
    """Baseline on the existing allocation (expansion 0) + the automatic envelope as a
    *proposed* alternative with an impact report (audit K2)."""
    base_in = RA.load(reg, st, rules, **load_kw)
    base = run(base_in, rules, out_dir, label)
    if not propose or load_kw.get("allowed") is not None:
        return base
    prop_in = _auto(RA.load(reg, st, rules, **load_kw), rules)
    pdir = os.path.join(out_dir, "proposals", "auto_envelope")
    stub = {"kind": "site_change:auto_envelope", "status": "proposed", "requires_owner_approval": True}
    prop = run(prop_in, rules, pdir, label, proposal=stub)
    imp = envelope.impact(prop_in, base, prop)
    prop["proposal"] = imp
    dump(os.path.join(pdir, "plan.json"), prop)
    base["proposals"] = [dict(imp, id="proposal-auto-envelope", plan="proposals/auto_envelope/plan.json")]
    dump(os.path.join(out_dir, "plan.json"), base)
    return base


def bake_cmd(a, rules):
    env = allowed = None
    if a.envelope:
        env = G.from_geojson(json.load(open(a.envelope)))
    if a.allowed:
        allowed = G.from_geojson(json.load(open(a.allowed)))
    out = os.path.join(a.out, a.settlement + (f"@{a.label}" if a.label else ""))
    if a.tier:
        inp = RA.load(a.region, a.settlement, rules, envelope=env, allowed=allowed, family=a.family)
        inp.tier = a.tier
        p = run(inp, rules, out, a.label)
    else:
        p = run_real(a.region, a.settlement, rules, out, a.label, propose=not a.no_auto_envelope,
                     envelope=env, allowed=allowed, family=a.family)
    print(summary_line(p))


def all_cmd(out, rules, include_failures=True, variants=True):
    lines = []
    for name in SYN_SITES:
        p = run(fixtures.load(name), rules, os.path.join(out, name))
        lines.append(summary_line(p)); print(lines[-1], flush=True)
    for name in WP5_SITES:
        p = run(fixtures.load(name), rules, os.path.join(out, name))
        lines.append(summary_line(p)); print(lines[-1], flush=True)
    for reg, st in REAL_SITES:
        p = run_real(reg, st, rules, os.path.join(out, st))
        lines.append(summary_line(p)); print(lines[-1], flush=True)
    if include_failures:
        for name in FAIL_SITES:
            p = run(fixtures.load(name), rules, os.path.join(out, name))
            lines.append(summary_line(p)); print(lines[-1], flush=True)
    return lines


def v06_cmd(out, rules, seeds=(2203, 7919)):
    """V06: 읍성·농촌·나루 on two terrains and two seeds with one rule system; report the
    functional / circulation differences (not just size)."""
    rows = []
    for terrain in ("terrace", "basin"):
        for prog in ("eupchi", "village", "waterside"):
            for seed in seeds:
                inp = fixtures.v06(terrain, prog, seed)
                p = run(inp, rules, os.path.join(out, inp.id))
                fr = p.get("frame") or {}
                civ = sorted(c["key"] for c in fr.get("civic_reserves", []))
                gates = sum(1 for o in fr.get("openings", []) if o["type"] == "gate")
                pc = fr.get("primary_corridors") or {}
                liv = p["program"]["households"].get("livelihood", {})
                lay = json.load(open(os.path.join(out, inp.id, "layout.json"), encoding="utf-8"))
                rows.append({"terrain": terrain, "program": prog, "seed": seed, "status": p["status"],
                             "layout": _v06_layout(lay),
                             "family": p["provenance"]["family"], "walled": bool(fr.get("wall")), "gates": gates,
                             "civic": civ, "households": p["program"]["households"]["represented"],
                             "road_class": pc.get("road_class"), "corridor_links": len(pc.get("links", [])),
                             "water_access": [w["kind"] for w in fr.get("water_access", [])],
                             "livelihood_ordinary": sorted((liv.get("ordinary") or {}).keys()),
                             "frame_id": fr.get("id"), "checks_failed": [c["id"] for c in p["validation"] if c["pass"] is False]})
                print(rows[-1], flush=True)
    # acceptance: per terrain and seed the three programs differ in function and circulation
    # (Layers 0–2) and in districts, street hierarchy, parcel roles and water work (Layers 3–5)
    verdict = []
    for terrain in ("terrace", "basin"):
        for seed in seeds:
            r = {x["program"]: x for x in rows if x["terrain"] == terrain and x["seed"] == seed}
            e, v, w = r["eupchi"], r["village"], r["waterside"]
            ok = (e["walled"] and e["gates"] >= 2 and {"gaeksa", "dongheon"} <= set(e["civic"])
                  and not v["walled"] and set(v["civic"]) == {"community", "well"}
                  and not w["walled"] and "fishing" in w["livelihood_ordinary"]
                  and "fishing" not in v["livelihood_ordinary"]
                  and all(x["status"] in ("valid", "proposed") for x in (e, v, w))
                  and not any(x["checks_failed"] for x in (e, v, w)))
            le, lv, lw = e["layout"], v["layout"], w["layout"]
            ok35 = (lv["status"] != "skipped" and le["status"] != "skipped" and lw["status"] != "skipped"
                    and "market_trade" in le["district_groups"] and {"secondary", "lane"} & set(le["hierarchy"])
                    and any(r.startswith("urban") or r in ("clerical", "elite_urban", "rear_residential") for r in le["roles"])
                    and le["pub04"] and "gosat" in lv["hierarchy"] and all(r.startswith("village") or r == "sanchon" for r in lv["roles"])
                    and "landing_or_fishing_access" in lw["activities"] and "landing_or_fishing_access" not in lv["activities"])
            verdict.append({"terrain": terrain, "seed": seed, "pass": ok, "layers_3_5": bool(ok35)})
    seed_effect = sorted({(x["terrain"], x["program"]) for x in rows
                          if len({y["frame_id"] for y in rows if y["terrain"] == x["terrain"] and y["program"] == x["program"]}) > 1})
    rep = {"V06": {"pass": all(v["pass"] for v in verdict), "pass_layers_3_5": all(v["layers_3_5"] for v in verdict),
                   "per_terrain_seed": verdict},
           "rows": rows, "seed_changed_frame_for": [list(t) for t in seed_effect],
           "note": "seed only reorders alternatives the rules cannot separate (frame.seed_tie_epsilon)"}
    dump(os.path.join(out, "v06.json"), rep)
    print(json.dumps(rep["V06"], ensure_ascii=False))
    return rep


def _v06_layout(lay):
    if lay.get("status") == "skipped":
        return {"status": "skipped"}
    roles = sorted({p["role"] for p in lay["parcels"] if p["use"] == "residential"})
    return {"status": lay["status"], "district_groups": sorted({d["group"] for d in lay["districts"]["districts"]}),
            "hierarchy": sorted({l["hierarchy"] for l in lay["streets"]["links"]}), "roles": roles,
            "pub04": bool(lay["districts"]["pub04"]["pass"] and lay["districts"]["pub04"]["walled"]),
            "activities": sorted({a["activity"] for a in lay["activity_sites"]}),
            "households_on_parcels": lay["summary"]["households_on_parcels"],
            "loops": next((c["detail"]["network"]["independent_loops"] for c in lay["checks"] if c["id"] == "V46" and c["detail"].get("network")), None)}


def wp5_cmd(out):
    """WP5 summary over an `all` output tree: per-site layout status, checks and metrics."""
    rows = {}
    for name in SYN_SITES + ["syn_stream", "syn_terrace_locked"] + [st for _, st in REAL_SITES] + FAIL_SITES:
        for p in (os.path.join(out, name, "layout.json"), os.path.join(out, name, "proposals", "auto_envelope", "layout.json")):
            if os.path.exists(p):
                lay = json.load(open(p, encoding="utf-8"))
                key = name + ("@proposal" if "proposals" in p else "")
                rows[key] = {"status": lay["status"], "reason": lay.get("status_reason") or lay.get("reason"),
                             "summary": lay.get("summary"),
                             "checks": {c["id"]: c["pass"] for c in lay.get("checks", [])},
                             "metrics": lay.get("metrics"), "revision_requests": [r["reason"] for r in lay.get("revision_requests", [])]}
    dump(os.path.join(out, "wp5.json"), rows)
    for n, r in rows.items():
        print(f"{n:<34} {r['status']:<16} " + " ".join(f"{k}={'P' if v is True else 'F' if v is False else '-'}" for k, v in r["checks"].items()))
    return rows


def wp4_cmd(out):
    """WP4 summary over an `all` output tree: per-site V checks + cross-site V63 / V66."""
    rows = {}
    for name in SYN_SITES + [st for _, st in REAL_SITES] + FAIL_SITES:
        p = os.path.join(out, name, "terrain-water.json")
        if os.path.exists(p):
            rows[name] = json.load(open(p, encoding="utf-8"))
    per = {n: {c["id"]: c["pass"] for c in l["checks"]} for n, l in rows.items()}
    # V63: same (assumed) rock type, different relief → different landform / exposure mix;
    # the rock type is never a classification input
    v63_sites = [n for n in ("syn_ridge", "syn_mountain", "syn_basin") if n in rows]

    def mix(l):
        a = l["terrain"]["summary"]["landform_area_m2"]
        g = l["terrain"]["summary"]["ground_area_m2"]
        ta, tg = sum(a.values()) or 1, sum(v for k, v in g.items() if k != "water") or 1
        return ({k: v / ta for k, v in a.items()}, {k: v / tg for k, v in g.items() if k != "water"})
    dists = {}
    for i, a in enumerate(v63_sites):
        for b in v63_sites[i + 1:]:
            (la, ga), (lb, gb) = mix(rows[a]), mix(rows[b])
            dl = sum(abs(la.get(k, 0) - lb.get(k, 0)) for k in set(la) | set(lb)) / 2
            dg = sum(abs(ga.get(k, 0) - gb.get(k, 0)) for k in set(ga) | set(gb)) / 2
            dists[f"{a}|{b}"] = {"landform_tv": round(dl, 4), "ground_tv": round(dg, 4)}
    used = any(p["rock_type"]["used_for_classification"] for n in v63_sites for p in rows[n]["terrain"]["patches"])
    v63 = {"pass": bool(dists) and not used and all(d["landform_tv"] >= 0.2 for d in dists.values()),
           "sites": v63_sites, "assumption": "one rock type for all synthetic sites (classification never reads it)",
           "total_variation": dists, "rock_type_used_for_shape": used,
           "limit": "synthetic relief only; real granite areas (JL 운봉·GS 분지) not compared at the same rock"}
    # V66: bedrock / step-pool reaches vs alluvial reaches differ in section and are not one template
    rs = [(n, r) for n, l in rows.items() for r in l["water"]["reaches"]]
    rock = [(n, r) for n, r in rs if r["bed_mix"]["type"] in ("bedrock", "step_pool_boulder")]
    allu = [(n, r) for n, r in rs if r["bed_mix"]["type"] == "alluvial_sand_gravel"]
    med = lambda xs: sorted(xs)[len(xs) // 2] if xs else None
    v66 = {"rock_reaches": len(rock), "alluvial_reaches": len(allu),
           "sites_rock": sorted({n for n, _ in rock}), "sites_alluvial": sorted({n for n, _ in allu}),
           "median_grade": {"rock": med([r["bed_mix"]["basis"]["grade"] for _, r in rock]),
                            "alluvial": med([r["bed_mix"]["basis"]["grade"] for _, r in allu])},
           "median_confinement": {"rock": med([r["bed_mix"]["basis"]["confinement_ratio"] for _, r in rock]),
                                  "alluvial": med([r["bed_mix"]["basis"]["confinement_ratio"] for _, r in allu])},
           "design_depth_m": {"rock": med([r["cross_section"]["representative"]["channel"]["depth_m"]["value"] for _, r in rock]),
                              "alluvial": med([r["cross_section"]["representative"]["channel"]["depth_m"]["value"] for _, r in allu])}}
    v66["pass"] = bool(rock and allu) and v66["median_confinement"]["rock"] < v66["median_confinement"]["alluvial"]
    rep = {"V63": v63, "V66_contrast": v66, "per_site": per,
           "note": "data-level checks; no in-game screen judgement was made"}
    dump(os.path.join(out, "wp4.json"), rep)
    print(json.dumps({"V63": v63["pass"], "V66_contrast": v66["pass"]}, ensure_ascii=False))
    for n, c in per.items():
        print(f"{n:<24} " + " ".join(f"{k}={'P' if v is True else 'F' if v is False else '-'}" for k, v in c.items()))
    return rep


def _hash_tree(d):
    out = {}
    for root, _, files in os.walk(d):
        for f in sorted(files):
            if f.endswith(".png"):
                continue
            p = os.path.join(root, f)
            out[os.path.relpath(p, d)] = hashlib.sha256(open(p, "rb").read()).hexdigest()
    return out


def determinism_cmd(out, rules, names):
    a, b = os.path.join(out, "run_a"), os.path.join(out, "run_b")
    for d in (a, b):
        shutil.rmtree(d, ignore_errors=True)
    for d in (a, b):
        for n in names:
            if n in fixtures.SYNTHETIC or n in fixtures.FAILURES:
                run(fixtures.load(n), rules, os.path.join(d, n))
            else:
                reg, st = n.split("/")
                run_real(reg, st, rules, os.path.join(d, st))
    ha, hb = _hash_tree(a), _hash_tree(b)
    same = ha == hb
    diff = sorted(k for k in set(ha) | set(hb) if ha.get(k) != hb.get(k))
    rep = {"identical": same, "files": len(ha), "differing": diff}
    dump(os.path.join(out, "determinism.json"), rep)
    print(json.dumps(rep, ensure_ascii=False))
    return same


def sheet_cmd(out):
    """Rasterize each combined.svg to combined.png with headless Chrome (review only)."""
    chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    for root, _, files in os.walk(out):
        for name in ("combined.svg", "combined-terrain-water.svg", "combined-layout.svg"):
            if name not in files:
                continue
            p = os.path.join(root, name)
            head = open(p, encoding="utf-8").read(400)
            import re
            m = re.search(r'width="(\d+)" height="(\d+)"', head)
            w, h = m.group(1), m.group(2)
            png = os.path.join(root, name.replace(".svg", ".png"))
            subprocess.run([chrome, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--window-size={w},{h}",
                            f"--screenshot={png}", "file://" + os.path.abspath(p)], check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
            print(png, os.path.exists(png))


def main(argv=None):
    ap = argparse.ArgumentParser(prog="settlement")
    sp = ap.add_subparsers(dest="cmd", required=True)
    b = sp.add_parser("bake")
    b.add_argument("--region", required=True)
    b.add_argument("--settlement", required=True)
    b.add_argument("--envelope")
    b.add_argument("--allowed")
    b.add_argument("--tier")
    b.add_argument("--family")
    b.add_argument("--label")
    b.add_argument("--no-auto-envelope", action="store_true")
    f = sp.add_parser("fixture")
    f.add_argument("--name", required=True)
    al = sp.add_parser("all")
    dt = sp.add_parser("determinism")
    dt.add_argument("--names", nargs="+", default=["syn_terrace", "syn_estuary", "JL_NAMWON_UNBONG/namwon_eup"])
    sh = sp.add_parser("sheet")
    v6 = sp.add_parser("v06")
    w4 = sp.add_parser("wp4")
    w5 = sp.add_parser("wp5")
    for p in (b, f, al, dt, sh, v6, w4, w5):
        p.add_argument("--rules", default=DEFAULT)
        p.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "out"))
    a = ap.parse_args(argv)
    rules = Rules(a.rules)
    G.set_grid(rules.p("geometry.grid"))
    if a.cmd == "bake":
        bake_cmd(a, rules)
    elif a.cmd == "fixture":
        p = run(fixtures.load(a.name), rules, os.path.join(a.out, a.name))
        print(summary_line(p))
    elif a.cmd == "all":
        all_cmd(a.out, rules)
    elif a.cmd == "determinism":
        ok = determinism_cmd(a.out, rules, a.names)
        sys.exit(0 if ok else 1)
    elif a.cmd == "sheet":
        sheet_cmd(a.out)
    elif a.cmd == "wp4":
        wp4_cmd(a.out)
    elif a.cmd == "wp5":
        wp5_cmd(a.out)
    elif a.cmd == "v06":
        rep = v06_cmd(a.out, rules)
        sys.exit(0 if rep["V06"]["pass"] else 1)


if __name__ == "__main__":
    main()
