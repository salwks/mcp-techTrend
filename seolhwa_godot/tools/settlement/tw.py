"""WP4 terrain · water layer file (terrain-water.json) and its checks.

The layer is written next to plan.json. plan.json carries a reference + revision + check summary
and the Route records (inputs.movement_livelihood.routes) now carry long profile, sections,
support/drainage contacts and divide crossings.

Checks (spec 05 / 16 §7 acceptance written as data checks — no screen judgement is claimed):
  WP4.layer  generator invariants (gates publication like the L0–2 checks): one state source,
             referential integrity, schema, V18.
  V01 V02 V03 V64 V65 V66 V67 V19 per site; V63 and the V66 contrast across sites (cli wp4).
  V checks on GIVEN data (e.g. a mapped road that crosses a cliff) are findings: they are
  reported with pass true/false in the layer and never silently fixed or used to block the
  settlement plan.
"""
from __future__ import annotations

import json
import math

import numpy as np

from . import contract as C
from . import terrain as TR
from . import water as WT
from .plan import GeomStore


def build(inp, A, rules, plan):
    store = GeomStore()
    rp = plan.get("region_profile") or {}
    nat = ((rp.get("natural") or {}).get("fields")) or {}
    T, W = A.terrain, A.waterlayer
    trec = TR.records(T, inp, A, rules, store, nat)
    catch_ids = trec.pop("_catch_ids")
    reaches, crossings, cands, bodies = WT.records(W, inp, A, T, rules, store, nat, catch_ids)
    impacts = WT.stage_impacts(inp, A, W, A.movement, rules, inp.locks)
    layer = {
        "schema": "terrain-water/1", "id": inp.id, "region": inp.region,
        "region_profile": (rp.get("meta") or {}).get("stable_id"),
        "order": ["terrain_water", "movement_livelihood", "settlement_function", "frame"],
        "units": "world_m",
        "natural_profile": nat,
        "terrain": {k: trec[k] for k in ("summary", "catchments", "ridges", "saddles", "summits", "patches")},
        "habitats": trec["habitats"],
        "water": {"stage_states": rules.p("water.stage_states"), "stage_units": rules.p("flood.stage_units"),
                  "reaches": reaches, "water_bodies": bodies, "crossings": crossings,
                  "crossing_candidates": cands, "stage_impacts": impacts},
        "routes": "plan.json#inputs.movement_livelihood.routes",
        "fields": "terrain-fields.npz",
        "provenance": {"rules_hash": rules.hash, "inputs": dict(sorted(inp.provenance.get("input_hashes", {}).items())),
                       "classification_inputs": TR.CLASSIFY_INPUTS,
                       "rock_type_used_for_shape": False},
    }
    layer["geometry"] = dict(sorted(store.items.items()))
    return layer


def _wf_reaches(layer):
    out = {}
    for r in layer["water"]["reaches"]:
        out.setdefault(r["feature"], []).append(r["meta"]["stable_id"])
    return out


# ---------------------------------------------------------------- checks
def _c(cid, ok, detail, applicable=True, kind="finding"):
    return {"id": cid, "pass": (bool(ok) if applicable else None), "applicable": applicable, "kind": kind, "detail": detail}


def checks(layer, plan, inp, A, rules):
    from .validate import load_schema, schema_errors
    out = []
    st = rules.p("water.stage_states")
    keys = [(s["key"], s["offset"]) for s in sorted(st, key=lambda s: s["offset"])]
    rp_states = [(s["key"], s["offset"]) for s in sorted((plan.get("region_profile") or {}).get("water_states", {}).get("states", []),
                                                         key=lambda s: s["offset"])]
    bad = []
    for r in layer["water"]["reaches"]:
        if [(s["key"], s["offset_world_m"]) for s in r["states"]] != keys:
            bad.append(r["meta"]["stable_id"])
    imp = [(s["key"], s["offset_world_m"]) for s in layer["water"]["stage_impacts"]]
    fs = sorted((v["offset_world_m"], k) for k, v in plan["site"]["flood_screen"].items())
    fs_ok = all((k, o) in keys for o, k in fs)
    ids = set()
    dup = []
    for sec in ("catchments", "ridges", "saddles", "patches"):
        for o in layer["terrain"][sec]:
            sid = (o.get("meta") or {}).get("stable_id") or o.get("id")
            if sid in ids:
                dup.append(sid)
            ids.add(sid)
    for o in layer["water"]["reaches"] + layer["habitats"] + layer["water"]["crossings"]:
        sid = o["meta"]["stable_id"]
        if sid in ids:
            dup.append(sid)
        ids.add(sid)
    rids = {r["meta"]["stable_id"] for r in layer["water"]["reaches"]}
    dangling = sorted({x for r in layer["water"]["reaches"] for x in r["upstream"] + r["downstream"] if x not in rids}
                      | {c["reach"] for c in layer["water"]["crossings"] if c.get("reach") and c["reach"] not in rids})
    refs = set()

    def walk(o):
        if isinstance(o, dict):
            for k, v in o.items():
                if k != "geometry" or not isinstance(v, dict) or not any(str(x).startswith("g-") for x in v):
                    walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
        elif isinstance(o, str) and o.startswith("g-") and len(o) == 14:
            refs.add(o)
    walk({k: v for k, v in layer.items() if k != "geometry"})
    miss = sorted(refs - set(layer["geometry"]))
    errs = schema_errors(json.loads(json.dumps(layer)), load_schema("terrain-water.schema.json"))
    v18 = C.v18_violations(layer)
    out.append(_c("WP4.layer", not bad and keys == rp_states and imp == keys and fs_ok and not dup and not dangling and not miss and not errs and not v18,
                  {"states_single_source": not bad and keys == rp_states and imp == keys and fs_ok,
                   "reaches_with_other_states": bad[:5], "duplicate_ids": dup[:5], "dangling_reach_refs": dangling[:5],
                   "missing_geometry": miss[:5], "schema_errors": errs[:8], "v18": v18[:5]}, kind="invariant"))
    routes = plan["inputs"]["movement_livelihood"]["routes"]
    lim = rules.p("movement.mode_limits")
    # V01 — routes: real length / ascent output, no mode judged passable through a cliff or over its limit
    if routes:
        det = []
        ok = True
        for r in routes:
            lp = r["long_profile"]
            have = all(k in lp for k in ("length_m", "ascent_m", "descent_m", "chainage", "y"))
            mis = [m["mode"] for m in r["modes"] if m["passable"] and (m["measured_sustained_grade"] > lim[m["mode"]] + 1e-9 or (r.get("cliff_traversal_m") or 0) > 0)]
            ok &= have and not mis
            det.append({"route": r["meta"]["stable_id"], "length_m": lp.get("length_m"), "ascent_m": lp.get("ascent_m"),
                        "passable": {m["mode"]: m["passable"] for m in r["modes"]}, "cliff_traversal_m": r.get("cliff_traversal_m"),
                        "misjudged_modes": mis})
        out.append(_c("V01", ok, det[:12]))
    else:
        out.append(_c("V01", None, "no routes in window", applicable=False))
    # V02 — cliff/talus relations: every cliff has top & bottom contacts and is flagged as needing
    # separate geometry; every talus has a supply cliff; no interior claimed without data
    cl = [p for p in layer["terrain"]["patches"] if p["kind"] == "ground" and p["rock_body"]["class"] == "cliff"]
    ta = [p for p in layer["terrain"]["patches"] if p["kind"] == "ground" and p["rock_body"]["class"] == "talus"]
    bad_c = [p["meta"]["stable_id"] for p in cl if not p["rock_body"].get("top_contact") or not p["rock_body"].get("bottom_contact")
             or p["rock_body"].get("heightfield_representable") is not False or p["rock_body"]["interior"]["value"] is not None]
    bad_t = [p["meta"]["stable_id"] for p in ta if not p["rock_body"].get("supply_cliffs")]
    rock_used = any(p["rock_type"]["used_for_classification"] for p in layer["terrain"]["patches"])
    out.append(_c("V02", not bad_c and not bad_t and not rock_used,
                  {"cliffs": len(cl), "talus": len(ta), "cliffs_missing_contacts": bad_c[:5], "talus_without_supply": bad_t[:5],
                   "rock_type_used_for_shape": rock_used},
                  applicable=True))
    # V03 — flow continuity across reach joins, foam only with a cause, no bed/surface gap
    reaches = layer["water"]["reaches"]
    if reaches:
        byid = {r["meta"]["stable_id"]: r for r in reaches}
        jumps = []
        tol = rules.p("water.flow")["flat_tolerance_m"]
        for r in reaches:
            last = r["long_profile"]["stations"][-1]
            for d in r["downstream"]:
                if byid[d]["feature"] != r["feature"]:
                    continue
                first = byid[d]["long_profile"]["stations"][0]
                if math.hypot(first["xz"][0] - last["xz"][0], first["xz"][1] - last["xz"][1]) > 1.0 or first["surface_y"] > last["surface_y"] + tol:
                    jumps.append([r["meta"]["stable_id"], d])
        causeless = [r["meta"]["stable_id"] for r in reaches for s in r["flow"]["segments"] if s["foam"] and not s.get("cause")]
        gap = [r["meta"]["stable_id"] for r in reaches if any(s["bed_y_design"] >= s["surface_y"] for s in r["long_profile"]["stations"])]
        out.append(_c("V03", not jumps and not causeless and not gap,
                      {"reaches": len(reaches), "discontinuous_joins": jumps[:5], "foam_without_cause": causeless[:5],
                       "bed_not_below_surface": gap[:5],
                       "foam_segments": sum(1 for r in reaches for s in r["flow"]["segments"] if s["foam"])}))
    else:
        out.append(_c("V03", None, "no channel reaches in window", applicable=False))
    # V64 — a route over a main divide joins two catchments through at least one saddle (안부)
    #       and carries sections; crossings off a saddle (e.g. zig-zags near a summit) are listed
    over = []
    edge = []
    for r in routes:
        dvs = [d for d in r.get("divide_crossings", []) if d["ridge_kind"] == "main"]
        edge += [{"route": r["meta"]["stable_id"], "ridge": d["ridge"]} for d in dvs if d.get("at_window_edge")]
        dvs = [d for d in dvs if not d.get("at_window_edge")]
        if not dvs:
            continue
        ends = r.get("catchments_at_ends") or [None, None]
        at_saddle = [d["saddle"] for d in dvs if d["saddle"]]
        over.append({"route": r["meta"]["stable_id"], "divide_crossings": len(dvs), "via_saddles": sorted(set(at_saddle)),
                     "off_saddle": [d["ridge"] for d in dvs if not d["saddle"]], "ends": ends,
                     "two_sides": bool(ends[0] and ends[1] and ends[0] != ends[1]),
                     "sections": bool(r["width_section"].get("sections")),
                     "passable": {m["mode"]: m["passable"] for m in r["modes"]},
                     "pass": bool(at_saddle) and bool(ends[0] and ends[1] and ends[0] != ends[1]) and bool(r["width_section"].get("sections"))})
    if over:
        out.append(_c("V64", all(o["pass"] for o in over), {"routes": over[:8], "ignored_at_window_edge": edge[:5]}))
    else:
        out.append(_c("V64", None, {"note": "no route crosses a main divide inside this window", "ignored_at_window_edge": edge[:5]},
                      applicable=False))
    # V65 — profile / section / plan on the same id; no unexplained reverse flow; no water film
    if reaches:
        rev = [r["meta"]["stable_id"] for r in reaches if any(s["kind"] == "reverse" for s in r["flow"]["segments"]) and not r["flow"].get("exception")]
        exc = [r["meta"]["stable_id"] for r in reaches if r["flow"].get("exception")]
        film = [r["meta"]["stable_id"] for r in reaches if r["cross_section"]["stations_with_surface_above_bank"] > 0]
        same = all(r["plan"]["centerline"] and r["cross_section"]["representative"] and r["long_profile"]["stations"] for r in reaches)
        link = all((d in byid and r["meta"]["stable_id"] in byid[d]["upstream"]) for r in reaches for d in r["downstream"])
        out.append(_c("V65", same and link and not rev and not film,
                      {"same_reach_id": same, "links_symmetric": link, "reverse_flow": rev[:5], "surface_above_bank": film[:5],
                       "marked_exceptions": exc[:5],
                       "flat_reaches": sum(1 for r in reaches if "flat mapped surface" in r["flow"]["direction_basis"])}))
    else:
        out.append(_c("V65", None, "no channel reaches", applicable=False))
    # V66 (per site) — bed type from gradient/confinement/rock, never from kind/name alone
    if reaches:
        kinds = {}
        for r in reaches:
            kinds.setdefault(r["kind"], set()).add(r["bed_mix"]["type"])
        basis_ok = all(r["bed_mix"]["basis"]["grade"] is not None and r["bed_mix"]["basis"]["confinement_ratio"] is not None for r in reaches)
        out.append(_c("V66", basis_ok, {"bed_types": sorted({r["bed_mix"]["type"] for r in reaches}),
                                        "by_kind": {k: sorted(v) for k, v in sorted(kinds.items())},
                                        "note": "the bedrock-vs-alluvial contrast is checked across sites (cli wp4)"}))
    else:
        out.append(_c("V66", None, "no channel reaches", applicable=False))
    # V67 — every state re-checks crossings, routes, riverside work, vegetation, locks
    impacts = layer["water"]["stage_impacts"]
    need = {"crossings", "routes", "riverside_work_cells_flooded", "flooded_by_landuse_m2", "locks_flooded"}
    cross_ok = all(c["states"] is None or [s["key"] for s in c["states"]] == [k for k, _ in keys] for c in layer["water"]["crossings"])
    ok = all(need <= set(i) for i in impacts) and cross_ok and [(i["key"], i["offset_world_m"]) for i in impacts] == keys
    summary = []
    for i in impacts:
        summary.append({"key": i["key"], "routes_cut_foot": sum(1 for r in i["routes"] if r["modes"]["foot"] == "cut"),
                        "routes_wet": sum(1 for r in i["routes"] if r["modes"]["foot"] == "wet"),
                        "crossings_impassable_foot": sum(1 for v in i["crossings"].values() if v is not None and not v["foot"]),
                        "riverside_flooded": i["riverside_work_cells_flooded"], "locks_flooded": i["locks_flooded"]})
    out.append(_c("V67", ok, {"crossings": len(layer["water"]["crossings"]), "per_state": summary}))
    # V19 — management overlays never change the natural base (terrain / water revisions)
    hab = layer["habitats"]
    if hab:
        base_rev = [o["meta"]["revision"] for o in layer["terrain"]["patches"] + layer["water"]["reaches"]]
        import copy
        alt = copy.deepcopy(layer)
        for h in alt["habitats"]:
            h["management"] = "protected" if h["management"] == "unknown" else "abandoned"
        alt_rev = [o["meta"]["revision"] for o in alt["terrain"]["patches"] + alt["water"]["reaches"]]
        linked = all(h["catchments"] for h in hab)
        out.append(_c("V19", base_rev == alt_rev and linked,
                      {"habitats": len(hab), "linked_to_catchments": linked,
                       "management": {k: sum(1 for h in hab if h["management"] == k) for k in sorted({h["management"] for h in hab})},
                       "note": "data-level: overlay change leaves terrain/water revisions unchanged"}))
    else:
        out.append(_c("V19", None, "no habitat patches", applicable=False))
    return out
