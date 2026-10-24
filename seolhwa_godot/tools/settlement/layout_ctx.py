"""WP5 shared context: reads only Layer 0–2 + WP4 artifacts (plan record, site analysis fields,
terrain-water layer) and the rules file. Every WP5 module receives one `Ctx`.

Conventions: world metres (x right, z south, north = -z). Rules hold historical (measured)
dimensions; the one building/plot factor from RegionProfile.scale_policy is applied exactly once
here (`wl`, `wa`, audit K1). Random variation is derived from stable ids (TOOL-04), never from one
global stream.
"""
from __future__ import annotations

import hashlib
import math
import random

import numpy as np
import shapely
from shapely.geometry import LineString, Point, Polygon, shape

from . import geometry as G
from . import program as P
from . import raster as Rr
from .plan import GeomStore


class Ctx:
    def __init__(self, plan, inp, A, layer, rules, reg=None, scope=None):
        self.plan, self.inp, self.A, self.layer, self.R = plan, inp, A, layer, rules
        self.reg = reg
        self.scope = scope or plan["id"]
        self.store = GeomStore()
        self.fr = plan["frame"]
        self.factor = P.building_factor(rules)
        prof = rules.profile(plan["program"]["profile"])
        self.profile = prof
        self.urban = bool(prof.get("urban"))
        self.kind = prof.get("settlement_kind", "village")
        self.sanchon = plan["program"]["profile"] in ("sanchon",)
        self.walled = bool(self.fr and self.fr.get("wall"))
        self.seed = int(plan["provenance"].get("seed") or 0)
        self.territory = G.polygonal(self.g(self.fr["territory"]))
        self.allowed = G.polygonal(self.g(plan["territory"]["allowed"]))
        self.revision_requests = []
        self.diagnostics = []
        self.reason_lines = []
        self.domain_total = None   # (geometry, reason, source) — every subdivision edge must lie on one

    # ------------------------------------------------------------------ helpers
    def g(self, gid):
        if gid is None:
            return None
        return shape(self.plan["geometry"][gid])

    def wl(self, hist_m):
        return float(hist_m) * self.factor

    def wa(self, hist_m2):
        return float(hist_m2) * self.factor * self.factor

    def rng(self, *key) -> random.Random:
        h = hashlib.sha256(("|".join([self.scope, str(self.seed)] + [str(k) for k in key])).encode()).hexdigest()
        return random.Random(int(h[:16], 16))

    def add(self, geom):
        return self.store.add(geom)

    def claim(self, kind, key=None, xz=None, tol=0.0, content=None):
        """Identity via the WP2 registry (falls back to a deterministic key id)."""
        if self.reg is None:
            return f"{kind}:{self.scope}:{key}"
        return self.reg.claim(kind, self.scope, key=key, xz=xz, tol=tol, content=content)

    def request(self, target, request, reason, **data):
        rid = f"rr-wp5-{len(self.revision_requests) + 1:02d}"
        rec = {"id": rid, "layer": "WP5", "target": target, "request": request, "reason": reason}
        if data:
            rec["data"] = data
        self.revision_requests.append(rec)
        return rid

    def reason(self, geom, reason, source=None):
        if geom is None or geom.is_empty:
            return
        self.reason_lines.append((geom, reason, source))

    # ------------------------------------------------------------------ raster sampling
    def sample(self, arr, xs, zs):
        """Nearest-cell sample of an analysis-window array at world points (clipped)."""
        w = self.A.win
        i = np.clip(np.rint((np.asarray(xs) - w.x0) / w.cell).astype(int), 0, w.nx - 1)
        j = np.clip(np.rint((np.asarray(zs) - w.z0) / w.cell).astype(int), 0, w.nz - 1)
        return arr[j, i]

    def height(self, xs, zs):
        return Rr.bilinear(self.A.win, self.A.h, xs, zs)

    def in_window(self, x, z):
        w = self.A.win
        i, j = w.ij(x, z)
        return w.inside(i, j)


def bearing_deg(dx, dz):
    return G.bearing_of(dx, dz)


def unit(dx, dz):
    n = math.hypot(dx, dz)
    return (dx / n, dz / n) if n > 1e-12 else (0.0, 0.0)


def tangent_at(line: LineString, s: float, h: float = 2.0):
    L = line.length
    a = line.interpolate(max(0.0, s - h))
    b = line.interpolate(min(L, s + h))
    return unit(b.x - a.x, b.y - a.y)


def largest_remainder(shares: dict, n: int) -> dict:
    keys = sorted(shares)
    tot = sum(shares[k] for k in keys)
    if n <= 0 or tot <= 0:
        return {k: 0 for k in keys}
    raw = {k: n * shares[k] / tot for k in keys}
    base = {k: int(math.floor(raw[k] + 1e-12)) for k in keys}
    left = n - sum(base.values())
    for k in sorted(keys, key=lambda k: (-(raw[k] - base[k]), k))[:left]:
        base[k] += 1
    return base


def parts(geom):
    return G.parts(geom)


def union(geoms):
    gs = [g for g in geoms if g is not None and not g.is_empty]
    if not gs:
        return Polygon()
    return shapely.union_all(gs)
