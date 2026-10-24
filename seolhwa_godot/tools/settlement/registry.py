"""WP2 identity registry (audit K10): persistent identity IDs separate from content revisions.

An identity is assigned the first time an object appears and is kept on later bakes when the
object is recognised again — by a semantic key (civic institution, wall, frame) or by position
within a tolerance (gates, water passages, junctions). The revision (content hash) changes with
geometry; the identity does not. Entries that a later bake no longer produces are retired, never
deleted or reused. Identity order is deterministic (canonical processing order + counters), so a
fresh registry gives byte-identical results.
"""
from __future__ import annotations

import json
import math
import os

from .contract import revision

SCHEMA = "settlement-id-registry/1"


class Registry:
    def __init__(self, path: str | None = None):
        self.path = path
        self.data = {"schema": SCHEMA, "counters": {}, "entries": {}}
        if path and os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                self.data = json.load(f)
        self.claimed: set[str] = set()

    # ------------------------------------------------------------------ claim
    def claim(self, kind: str, scope: str, *, key=None, xz=None, tol: float = 0.0, content=None) -> str:
        ents = self.data["entries"]
        cands = sorted(i for i, e in ents.items() if e["kind"] == kind and e["scope"] == scope
                       and not e.get("retired") and i not in self.claimed)
        hit = None
        if key is not None:
            for i in cands:
                if ents[i].get("key") == key:
                    hit = i
                    break
        if hit is None and xz is not None and tol > 0:
            best = None
            for i in cands:
                p = ents[i].get("xz")
                if p is None or (key is not None and ents[i].get("key") not in (None, key)):
                    continue
                d = math.hypot(p[0] - xz[0], p[1] - xz[1])
                if d <= tol and (best is None or (d, i) < best):
                    best = (d, i)
            hit = best[1] if best else None
        if hit is None:
            ck = f"{kind}:{scope}"
            n = self.data["counters"].get(ck, 0) + 1
            self.data["counters"][ck] = n
            hit = f"{kind}:{scope}:{n:03d}"
            ents[hit] = {"kind": kind, "scope": scope, "first_revision": None}
        e = ents[hit]
        e["key"] = key
        e["xz"] = [round(xz[0], 2), round(xz[1], 2)] if xz is not None else None
        rev = revision(content) if content is not None else None
        if e.get("first_revision") is None:
            e["first_revision"] = rev
        e["revision"] = rev
        e.pop("retired", None)
        self.claimed.add(hit)
        return hit

    def retire_unclaimed(self, scope: str) -> list[str]:
        out = []
        for i, e in sorted(self.data["entries"].items()):
            if e["scope"] == scope and i not in self.claimed and not e.get("retired"):
                e["retired"] = True
                out.append(i)
        return out

    def save(self, path: str | None = None):
        p = path or self.path
        if not p:
            return
        os.makedirs(os.path.dirname(os.path.abspath(p)), exist_ok=True)
        with open(p, "w", encoding="utf-8") as f:
            json.dump(self.data, f, ensure_ascii=False, indent=1, sort_keys=True)
            f.write("\n")


def _rev(rec: dict) -> str:
    return revision({k: v for k, v in rec.items() if k not in ("stable_id", "revision")})


def assign(plan: dict, reg: Registry, rules, scope: str | None = None, retire: bool = True) -> dict:
    """Attach identity `stable_id` + content `revision` to frame records; returns a report."""
    scope = scope or plan["id"]
    tol = rules.p("registry.match_tol_m")
    jtol = rules.p("registry.junction_tol_m")
    fr = plan.get("frame")
    report = {"scope": scope, "claimed": 0}
    if fr is None:
        report["retired"] = []
        return report
    fr["stable_id"] = reg.claim("frame", scope, key="frame", content=fr.get("territory"))
    if fr.get("wall"):
        fr["wall"]["stable_id"] = reg.claim("wall", scope, key="wall", content=fr["wall"]["ring"])
        fr["wall"]["revision"] = _rev(fr["wall"])
    opening_ident = {}
    for o in sorted(fr.get("openings", []), key=lambda o: (o["chainage"][0], o["id"])):
        kind = "gate" if o["type"] == "gate" else "water_passage"
        o["stable_id"] = reg.claim(kind, scope, key=o.get("channel") if kind == "water_passage" else None,
                                   xz=o["center"], tol=tol, content=o)
        o["revision"] = _rev(o)
        opening_ident[o["id"]] = o["stable_id"]
    for c in fr.get("civic_reserves", []):
        c["stable_id"] = reg.claim("civic", scope, key=c["key"], content=c)
        c["revision"] = _rev(c)
    pc = fr.get("primary_corridors") or {}
    node_ident = {}
    for n in sorted(pc.get("nodes", []), key=lambda n: n["id"]):
        if n["kind"] == "gate" and n.get("opening") in opening_ident:
            n["stable_id"] = reg.claim("node", scope, key=f"gate:{opening_ident[n['opening']]}", content=n)
        elif n["kind"] == "civic_entrance":
            n["stable_id"] = reg.claim("node", scope, key=f"civic:{n['civic']}", content=n)
        else:
            n["stable_id"] = reg.claim("node", scope, key=None, xz=n["xz"], tol=jtol, content=n)
        n["revision"] = _rev(n)
        node_ident[n["id"]] = n["stable_id"]
    for l in sorted(pc.get("links", []), key=lambda l: l["id"]):
        a, b = sorted(node_ident.get(x, x) for x in l["nodes"])
        l["stable_id"] = reg.claim("link", scope, key=f"{a}|{b}", content=l)
        l["revision"] = _rev(l)
    for p in sorted(pc.get("paths", []), key=lambda p: p["id"]):
        src = p["id"]
        p["stable_id"] = reg.claim("path", scope, key=src, content=p)
        p["revision"] = _rev(p)
    for w in fr.get("water_access", []):
        w["stable_id"] = reg.claim("water_supply", scope, key=w["kind"], xz=w["xz"], tol=tol, content=w)
        w["revision"] = _rev(w)
    fr["revision"] = _rev(fr)
    report["claimed"] = sum(1 for i in reg.claimed if reg.data["entries"][i]["scope"] == scope)
    # only an accepted (valid/proposed) bake retires identities it no longer produces
    report["retired"] = (reg.retire_unclaimed(scope) if retire and plan.get("status") in ("valid", "proposed") else [])
    return report
