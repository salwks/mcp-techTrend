"""WP0 baseline freeze (read-only): story anchors, story placement items, stations, and the
save fields that reference background ids. Output is the V16 reference list that later work
packages must preserve. Nothing in the game is modified.

python -m tools.settlement.baseline --out tools/settlement/baseline/wp0_baseline.json
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))

STORY_REGION = {"namwon": "JL_NAMWON_UNBONG", "namwon_chunhyang": "JL_NAMWON_UNBONG", "main_p1": "JL_NAMWON_UNBONG",
                "gyeongju": "GS_GYEONGJU", "gangneung": "GW_GANGNEUNG", "hanyang": "GG_HANYANG",
                "hamhung": "HG_HAMHEUNG", "hwangju": "HH_HWANGJU", "jeju": "JJ_JEJU", "pyongyang": "PA_PYEONGYANG"}
NUM = r"-?\d+(?:\.\d+)?"
PAIR = re.compile(r'"([A-Za-z0-9_]+)"\s*:\s*\[\s*(' + NUM + r')\s*,\s*(' + NUM + r')\s*\]')


def _func_body(src: str, name: str) -> str | None:
    m = re.search(r"static func " + re.escape(name) + r"\(\)[^\n]*\n", src)
    if not m:
        return None
    rest = src[m.end():]
    n = re.search(r"\n(static )?func ", rest)
    return rest[: n.start()] if n else rest


def story_anchors():
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "story", "*", "*_data.gd"))):
        folder = os.path.basename(os.path.dirname(path))
        src = open(path, encoding="utf-8").read()
        body = _func_body(src, "_anchors") or _func_body(src, "anchors")
        if body is None:
            continue
        seen = set()
        for k, x, z in PAIR.findall(body):
            if k in seen:
                continue
            seen.add(k)
            stem = os.path.basename(path)[:-len("_data.gd")]
            out.append({"id": f"anchor:{stem}:{k}", "name": k, "story": folder, "story_file": stem,
                        "region": STORY_REGION.get(folder), "xz": [float(x), float(z)],
                        "source": os.path.relpath(path, ROOT), "kind": "story_anchor"})
    return out


def story_items():
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "region_data", "*", "placement_story_*.json"))):
        region = os.path.basename(os.path.dirname(path))
        d = json.load(open(path, encoding="utf-8"))
        for it in d.get("items", []):
            p = it.get("params", {}) or {}
            fp = it.get("footprint") or ([p["w"], p["d"]] if "w" in p and "d" in p else None)
            out.append({"id": f"item:{region}:{it['id']}", "item_id": it["id"], "region": region,
                        "kit": it.get("kit"), "xz": [it.get("x"), it.get("z")], "ry": it.get("ry", 0.0),
                        "footprint": fp, "yard": bool(it.get("yard")),
                        "source": os.path.relpath(path, ROOT), "kind": "story_item"})
    return out


def stations():
    path = os.path.join(ROOT, "region_data", "stations.json")
    if not os.path.exists(path):
        return []
    d = json.load(open(path, encoding="utf-8"))
    out = []
    for s in d.get("stations", []):
        for key in ("pos", "hitch", "wait", "yard"):
            v = s.get(key)
            if isinstance(v, list) and len(v) >= 2:
                out.append({"id": f"station:{s['id']}:{key}", "station": s["id"], "space": s.get("space"),
                            "xz": [float(v[0]), float(v[1])], "kind": "station_anchor",
                            "source": "region_data/stations.json"})
    return out


def save_references():
    """Save fields (scripts/region/progress.gd header) that point at background data."""
    return [
        {"field": "routes_done.<노정 id>", "references": "region_data/routes/* ids", "risk": "route id rename"},
        {"field": "known.<공간 id>.<장소 키>", "references": "settlement / landmark keys (region.json ids)", "risk": "settlement id rename"},
        {"field": "where{space,x,z}", "references": "world coordinates", "risk": "coordinate change of walkable ground"},
        {"field": "waypoint{space,x,z,key}", "references": "world coordinates + place key", "risk": "coordinate / key change"},
        {"field": "heard[].place", "references": "place keys", "risk": "key rename"},
        {"field": "cases.<id>.world/flags", "references": "story anchor names (story data), not placement ids", "risk": "anchor rename"},
        {"field": "travel_nodes/<space>/<node>", "references": "region_data/travel node ids (stations discover_key)", "risk": "node rename"},
    ]


def settlement_ids():
    out = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "region_data", "*", "region.json"))):
        region = os.path.basename(os.path.dirname(path))
        d = json.load(open(path, encoding="utf-8"))
        out[region] = sorted(s["id"] for s in d.get("settlements", []))
    return out


CHECKS = [  # last reported numbers (cited from reports — this baseline does not re-run Godot)
    {"check": "tools/settlement pytest", "last": "21 passed (settlement-v2-L0-2-impl §6)", "rerun_here": True},
    {"check": "settlement v2 determinism", "last": "8 sites byte-identical (impl §6)", "rerun_here": True},
    {"check": "mountain_check --mtncheck=walk", "last": "46/0 (integ-mountain report)", "rerun_here": False},
    {"check": "town walk tests", "last": "west 68/0, eup 42/0 (audit WP12)", "rerun_here": False},
    {"check": "ROOFCHECK / bldg smoke", "last": "smoke 0 · roof 0/288 (town-organic §6)", "rerun_here": False},
    {"check": "save_guard_test", "last": "SAVEGUARDTEST PASS (protected; not run here)", "rerun_here": False},
]


def build():
    anchors = story_anchors()
    items = story_items()
    st = stations()
    return {"schema": "settlement-baseline/1", "story_anchors": anchors, "story_items": items,
            "station_anchors": st, "settlement_ids": settlement_ids(), "save_references": save_references(),
            "checks": CHECKS,
            "counts": {"story_anchors": len(anchors), "story_items": len(items), "station_anchors": len(st)}}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "baseline", "wp0_baseline.json"))
    a = ap.parse_args(argv)
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    b = build()
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(b, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    print(json.dumps(b["counts"]))


if __name__ == "__main__":
    main()
