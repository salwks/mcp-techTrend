"""WP2 locks: story anchors, story placement items and station spots are imported as locks
*before* generation (audit K11). Locks are never moved; conflicts become diagnostics.

- story_anchor / station_anchor: point locks (position, access, event_ref). A frame may
  enclose them; the wall must not run through them; civic / water reservations must not cover
  them; they must stay reachable on foot from the route network.
- story_item: shape locks (position, shape, access) — the footprint (+clearance) is occupied
  land: no wall, reservation or corridor may cross it.
"""
from __future__ import annotations

import math

import numpy as np
from shapely.geometry import Point, Polygon, box

from . import baseline
from . import contract as C
from .model import diag


def _footprint(x, z, w, d, ry):
    c, s = math.cos(ry), math.sin(ry)
    pts = []
    for lx, lz in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)):
        pts.append((x + lx * c + lz * s, z - lx * s + lz * c))  # Godot rotation about +y
    return Polygon(pts)


def for_region(region: str, bounds, rules) -> list[dict]:
    """Locks whose position lies inside `bounds` (xmin, zmin, xmax, zmax)."""
    xmin, zmin, xmax, zmax = bounds
    win = box(xmin, zmin, xmax, zmax)
    ra = rules.p("locks.anchor_radius_m")
    rs = rules.p("locks.station_radius_m")
    cl = rules.p("locks.item_clearance_m")
    out = []
    for a in baseline.story_anchors():
        if a["region"] != region or not win.contains(Point(a["xz"])):
            continue
        out.append({"id": f"lock:{a['id']}", "kind": "story_anchor", "xz": a["xz"], "radius_m": ra,
                    "geom": Point(a["xz"]).buffer(ra, 16), "hard": False, "source": a["source"],
                    "lock_scope": ["position", "access", "event_ref"]})
    for it in baseline.story_items():
        if it["region"] != region or it["xz"][0] is None or not win.contains(Point(it["xz"])):
            continue
        fp = it.get("footprint")
        if fp:
            g = _footprint(it["xz"][0], it["xz"][1], float(fp[0]), float(fp[1]), float(it.get("ry") or 0.0)).buffer(cl, join_style="mitre")
        else:
            g = Point(it["xz"]).buffer(ra + cl, 16)
        out.append({"id": f"lock:{it['id']}", "kind": "story_item", "xz": it["xz"], "radius_m": None,
                    "geom": g, "hard": True, "source": it["source"],
                    "lock_scope": ["position", "shape", "access"]})
    for s in baseline.stations():
        sp = s.get("space")
        if sp != region or not win.contains(Point(s["xz"])):
            continue
        out.append({"id": f"lock:{s['id']}", "kind": "station_anchor", "xz": s["xz"], "radius_m": rs,
                    "geom": Point(s["xz"]).buffer(rs, 16), "hard": False, "source": s["source"],
                    "lock_scope": ["position", "access"]})
    out.sort(key=lambda l: l["id"])
    return out


def record(lock: dict, store) -> dict:
    """Contract Lock object (meta + geometry ref); locks are confirmed facts of the story data."""
    body = {"kind": lock["kind"], "geometry_xz": [float(lock["xz"][0]), float(lock["xz"][1])],
            "radius_m": lock["radius_m"], "source": lock["source"], "geometry": store.add(lock["geom"]),
            "hard": lock["hard"]}
    body["meta"] = C.meta(lock["id"], status="confirmed", sources=[lock["source"]], lock_scope=lock["lock_scope"],
                          content=body)
    body["id"] = lock["id"]
    return body


def site_conflicts(inp, A) -> list[dict]:
    """Layer-0 diagnostics for locks (never move them)."""
    out = []
    for l in inp.locks:
        x, z = l["xz"]
        i, j = A.win.ij(x, z)
        if not A.win.inside(i, j):
            continue
        codes = []
        if A.water[j, i]:
            codes.append("lock_in_water")
        if A.flood_ex[j, i]:
            codes.append("lock_in_flood_exclusion")
        if not np.isfinite(A.route_cost[j, i]):
            codes.append("lock_unreachable_from_routes")
        for c in codes:
            out.append(diag(c, "warning", "L0", "locked story spot kept in place; condition reported", lock=l["id"]))
    return out
