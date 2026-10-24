"""WP1 common data contract v1 (spec 04 TOOL-01): meta, status mapping, V18 rule,
RegionProfile (single scale record, K1) and object validation.

Status vocabulary (spec): confirmed | proposed | unknown.
Rules/region confidence → status (table below). A generator never emits `confirmed`
(V18: no automatic confirmation); confirmed needs at least one source record and must not
be a hypothesis.
"""
from __future__ import annotations

import hashlib
import json
import os

from . import GENERATOR_VERSION
from .geometry import canonical_json

CONTRACT_PATH = os.path.join(os.path.dirname(__file__), "schemas", "contract-v1.schema.json")
RULE_VERSION = "settlement-rules/1"
GENERATOR = f"settlement-v2/{GENERATOR_VERSION}"

# confidence words used in rules/default.json and region_data → contract status
STATUS_MAP = {
    "measured": "confirmed",     # value read from a source (still needs a SourceRecord to be confirmed)
    "agreed": "proposed",        # design agreement between designers, not a historical fact
    "provisional": "proposed",
    "확정": "confirmed",
    "추정": "proposed",
    "가설": "proposed",          # + hypothesis flag
    "unknown": "unknown",
    None: "unknown",
}
HYPOTHESIS_WORDS = {"가설", "hypothesis"}


def status_of(confidence) -> tuple[str, bool]:
    """(status, hypothesis) for a confidence word; unknown words map to unknown."""
    c = confidence.strip() if isinstance(confidence, str) else confidence
    return STATUS_MAP.get(c, "unknown"), (c in HYPOTHESIS_WORDS)


def revision(content) -> str:
    """Content hash (revision) — distinct from the persistent identity (stable_id)."""
    return hashlib.sha256(canonical_json(content).encode("utf-8")).hexdigest()


def meta(stable_id: str, *, status: str = "proposed", sources=(), rules_hash=None, lock_scope=(),
         content=None, hypothesis: bool = False, inputs=None) -> dict:
    if status == "confirmed" and (not sources or hypothesis):
        raise ValueError(f"{stable_id}: confirmed requires sources and no hypothesis (V18)")
    return {"stable_id": stable_id,
            "provenance": {"sources": list(sources), "generator": GENERATOR, "rules_hash": rules_hash,
                           "inputs": dict(inputs or {})},
            "rule_version": RULE_VERSION, "status": status, "lock_scope": sorted(set(lock_scope)),
            "revision": revision(content) if content is not None else None, "hypothesis": bool(hypothesis)}


def measure(value, unit: str, status: str = "proposed", missing_reason=None, source=None) -> dict:
    """Missing is null + reason, never 0."""
    if value is None and not missing_reason:
        missing_reason = "not measured"
    return {"value": value, "unit": unit, "status": status if value is not None else "unknown",
            "missing_reason": missing_reason if value is None else None, "source": source}


def v18_violations(obj: dict, path="$") -> list[str]:
    """Walk an object tree: any meta with status confirmed must have sources, must not be a
    hypothesis, and must not have been produced by this generator without a source."""
    out = []
    if isinstance(obj, dict):
        m = obj.get("meta")
        if isinstance(m, dict) and m.get("status") == "confirmed":
            if not m.get("provenance", {}).get("sources"):
                out.append(f"{path}: confirmed without sources")
            if m.get("hypothesis"):
                out.append(f"{path}: hypothesis marked confirmed")
        for k, v in obj.items():
            out += v18_violations(v, f"{path}.{k}")
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            out += v18_violations(v, f"{path}[{i}]")
    return out


_CONTRACT = None


def contract():
    global _CONTRACT
    if _CONTRACT is None:
        with open(CONTRACT_PATH, encoding="utf-8") as f:
            _CONTRACT = json.load(f)
    return _CONTRACT


def validate(kind: str, obj) -> list[str]:
    from .validate import schema_errors
    c = contract()
    if kind not in c["$defs"]:
        raise KeyError(kind)
    return schema_errors(obj, {"$ref": f"#/$defs/{kind}"}, "$", c)


# ---------------------------------------------------------------- RegionProfile (K1, K3)
def region_profile(inp, rules) -> dict:
    """One record of every game transform for a region: terrain compression (travel distance)
    and the building/plot enlargement for 2 m characters are two transforms with different
    purposes (audit K1); rules hold measured values; the building factor is applied once at
    bake (program.py), never baked into rule values."""
    prov = inp.provenance or {}
    vert = prov.get("vertical") or {}
    fixture = bool(inp.meta.get("fixture"))
    from .program import building_factor
    factor = building_factor(rules)
    states = rules.p("water.stage_states")
    rid = inp.region if not fixture else f"SYNTHETIC.{inp.id}"
    body = {
        "schema": "region-profile/1",
        "region": rid,
        "period": {"label": "조선 후기(공통 규칙)" if not fixture else "synthetic", "status": "unknown" if not fixture else "proposed"},
        "coordinates": {"units": "world_m", "north_xz": [0, -1],
                        "source_projection": "synthetic" if fixture else "x=(lon-lon0)*cos(lat0)*111320*K, z=-(lat-lat0)*110574*K"},
        "elevation": {"units": "world_m", "datum": "game y" if not fixture else "fixture y",
                      "decode": "y_min + v/65535*(y_max-y_min)" if not fixture else "analytic",
                      "already_remapped": True},
        "data_resolution": {"height_cell_m": inp.grid.cell,
                            "landuse_cell_m": 4.0 if not fixture else None},
        "scale_policy": {
            "terrain": {"horizontal_K": vert.get("K", 1.0), "vertical": {
                "remap": vert.get("remap"), "local_scale_at_floor": inp.vertical_scale},
                "purpose": "geographic compression of travel distance (terrain only)",
                "status": "confirmed" if not fixture else "proposed"},
            "building": {"factor": factor, "axes": ["plan", "height"],
                         "purpose": "enlarge buildings/plots/lanes for 2 m characters (one uniform factor)",
                         "status": "confirmed", "decided_by": "owner 2026-10-25 (audit K1)",
                         "area_factor": round(factor * factor, 6)},
            "rules_hold": "measured_values",
            "apply_once_at": "bake",
        },
        "water_states": {"units": rules.p("flood.stage_units"), "states": states, "status": "proposed",
                         "note": "flood screen offsets = named stage states of each WaterReach (audit K3)"},
        "hypotheses": [{"topic": "flood stage offsets", "status": "proposed"},
                       {"topic": "period/region values (rock type, river sections, bay sizes)", "status": "unknown"}],
    }
    body["natural"] = natural_profile(rid if not fixture else None)
    src = ["owner_decision:2026-10-25"]
    body["meta"] = meta(f"region:{rid}", status="proposed", sources=src, rules_hash=rules.hash,
                        content={k: v for k, v in body.items() if k != "meta"})
    return body


# ---------------------------------------------------------------- natural profile (WP4)
NATURAL_PATH = os.path.join(os.path.dirname(__file__), "regions", "natural_profiles.json")
_NAT = None


def natural_profile(region):
    """Natural-layer RegionProfile fields from spec 21 (terrain · rock · water · forest).
    confirmed only with grade A/B and at least one source id; otherwise downgraded to proposed
    and flagged. Unknown regions (fixtures) get an empty, explicitly unknown block."""
    global _NAT
    if _NAT is None:
        with open(NATURAL_PATH, encoding="utf-8") as f:
            _NAT = json.load(f)
    src = "tools/settlement/regions/natural_profiles.json"
    rows = (_NAT["regions"].get(region) if region else None)
    if not rows:
        return {"source": src, "fields": {}, "status": "unknown",
                "missing_reason": "no regional profile (synthetic fixture or region not drafted)"}
    out = {}
    for k in sorted(rows):
        v = dict(rows[k])
        st = v.get("status", "unknown")
        if st not in ("confirmed", "proposed", "unknown"):
            st = "unknown"
        if st == "confirmed" and (v.get("grade") not in ("A", "B") or not v.get("sources")):
            st = "proposed"
            v["downgraded"] = True
        if v.get("value") is None:
            st = "unknown"
        v["status"] = st
        out[k] = v
    return {"source": src, "fields": out, "status": "proposed",
            "note": "transcribed from spec 21 drafts; recorded inputs only, never used to shape terrain (GEO-01)"}
