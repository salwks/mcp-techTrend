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

from . import fixtures, frame, geometry as G, plan as PL, program, site, svg, validate
from .adapters import region as RA
from .rules import DEFAULT, Rules

REAL_SITES = [("JL_NAMWON_UNBONG", "namwon_eup"), ("GS_GYEONGJU", "bulguksa_village"),
              ("JL_NAMWON_UNBONG", "banseon"), ("GW_GANGNEUNG", "anmok_village")]
SYN_SITES = ["syn_terrace", "syn_basin", "syn_ridge", "syn_estuary"]
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


def run(inp, rules, out_dir, label=None):
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
    plan, extras, store = PL.build(inp, A, family, fam_info, L1, F, rules, dependencies())
    plan["validation"] = []
    plan = _sanitize(plan)
    plan["validation"] = _sanitize(validate.run(plan, inp, A, L1, F, rules))
    plan = _sanitize(plan)
    if label:
        plan["variant"] = label
    dump(os.path.join(out_dir, "plan.json"), plan)
    dump(os.path.join(out_dir, "input.json"), _sanitize(input_record(inp, family)))
    dump(os.path.join(out_dir, "site.geojson"), _sanitize(PL.site_geojson(inp, A)))
    from .raster import write_npz
    write_npz(os.path.join(out_dir, "site-fields.npz"), PL.site_fields(A))
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
    return plan


def summary_line(plan):
    v = plan["validation"]
    fails = [c["id"] for c in v if c["pass"] is False]
    fr = plan.get("frame") or {}
    gates = sum(1 for o in (fr.get("openings") or []) if o["type"] == "gate")
    return (f"{plan['id']:<24} {plan['status']:<22} hh={plan['program']['households']['represented']:<4} "
            f"gates={gates} alts={len(plan['alternatives'])} checks_failed={fails}")


def bake_cmd(a, rules):
    env = allowed = None
    if a.envelope:
        env = G.from_geojson(json.load(open(a.envelope)))
    if a.allowed:
        allowed = G.from_geojson(json.load(open(a.allowed)))
    inp = RA.load(a.region, a.settlement, rules, envelope=env, allowed=allowed, family=a.family)
    if a.tier:
        inp.tier = a.tier
    out = os.path.join(a.out, a.settlement + (f"@{a.label}" if a.label else ""))
    p = run(inp, rules, out, a.label)
    print(summary_line(p))


def all_cmd(out, rules, include_failures=True, variants=True):
    lines = []
    for name in SYN_SITES:
        p = run(fixtures.load(name), rules, os.path.join(out, name))
        lines.append(summary_line(p)); print(lines[-1], flush=True)
    for reg, st in REAL_SITES:
        p = run(RA.load(reg, st, rules), rules, os.path.join(out, st))
        lines.append(summary_line(p)); print(lines[-1], flush=True)
    if include_failures:
        for name in FAIL_SITES:
            p = run(fixtures.load(name), rules, os.path.join(out, name))
            lines.append(summary_line(p)); print(lines[-1], flush=True)
    return lines


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
                run(RA.load(reg, st, rules), rules, os.path.join(d, st))
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
        if "combined.svg" in files:
            p = os.path.join(root, "combined.svg")
            head = open(p, encoding="utf-8").read(400)
            import re
            m = re.search(r'width="(\d+)" height="(\d+)"', head)
            w, h = m.group(1), m.group(2)
            png = os.path.join(root, "combined.png")
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
    f = sp.add_parser("fixture")
    f.add_argument("--name", required=True)
    al = sp.add_parser("all")
    dt = sp.add_parser("determinism")
    dt.add_argument("--names", nargs="+", default=["syn_terrace", "syn_estuary", "JL_NAMWON_UNBONG/namwon_eup"])
    sh = sp.add_parser("sheet")
    for p in (b, f, al, dt, sh):
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


if __name__ == "__main__":
    main()
