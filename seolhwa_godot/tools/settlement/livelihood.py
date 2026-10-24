"""WP3 / audit K9: the "movement and livelihood" input layer, between terrain·water and
settlement function (spec order: 지형·물 → 이동과 생업 → 정착 기능 → …).

Routes become contract Route records with per-mode passability (foot / pack horse / cart; the
limits are provisional test values, audit K5) measured on the existing route lines; the
settlement frame reads its approaches from this layer, not from raw region roads. Livelihood
records cultivation, forest and water-work land around the allocation. Nothing here invents
new routes or fields: it describes the given data so later layers can depend on it.
"""
from __future__ import annotations

import math

import numpy as np
from shapely.geometry import Point

from . import contract as C
from . import raster as Rr
from . import routing as Rt

PURPOSE_BY_CLASS = {"대로": "inter-town trunk", "중로": "town link", "소로": "local path"}


def build(inp, A, rules, store=None) -> dict:
    modes = rules.p("movement.mode_limits")
    routes = []
    for r in inp.roads:  # given data, canonical order
        pts = list(r.line.coords)
        sus, loc, _, _, _ = Rt.sustained_grade(inp.grid, A.full_h, pts, rules.p("routing.mountain.window_m"), 0.0)
        mlist = []
        for m in ("foot", "pack_horse", "cart"):
            lim = modes[m]
            mlist.append({"mode": m, "passable": bool(sus <= lim), "limit": lim, "status": "proposed",
                          "measured_sustained_grade": round(sus, 4)})
        body = {"purpose": PURPOSE_BY_CLASS.get(r.klass, "route"), "class": r.klass, "name": r.name,
                "nodes": [f"end:{r.id}:0", f"end:{r.id}:1"], "modes": mlist,
                "width_section": {"width_m": r.width_m, "status": "proposed"},
                "long_profile": {"sustained_grade_10m": round(sus, 4), "local_max_grade": round(loc, 4),
                                 "length_m": round(r.line.length, 1)},
                "support_drainage": [],  # unknown here (WP4)
                "centerline": store.add(r.line) if store is not None else None,
                "source_id": r.id}
        scope = inp.region if not inp.meta.get("fixture") else f"SYNTHETIC.{inp.id}"
        body["meta"] = C.meta(f"route:{scope}:{r.id}".replace("#", "_"), status="proposed",
                              sources=[f"region_data/{inp.region}/region.json#roads"] if not inp.meta.get("fixture") else ["fixture"],
                              content={k: v for k, v in body.items() if k != "centerline"})
        routes.append(body)
    pref = inp.territory["preferred"]
    c = pref.centroid
    cell_a = A.win.cell ** 2
    X, Z = np.meshgrid(A.win.xs(), A.win.zs())
    lv = {}
    lu = inp.meta.get("landuse")
    for rad in rules.p("agriculture.radii_m"):
        disk = (X - c.x) ** 2 + (Z - c.y) ** 2 <= rad * rad
        rec = {"farmland_m2": round(float((disk & A.farmland).sum()) * cell_a, 1)}
        if lu is not None:
            luw = lu[A.sl]
            rec["paddy_m2"] = round(float((disk & (luw == 2)).sum()) * cell_a, 1)
            rec["field_m2"] = round(float((disk & (luw == 3)).sum()) * cell_a, 1)
            rec["forest_m2"] = round(float((disk & np.isin(luw, (0, 9))).sum()) * cell_a, 1)
        rec["freshwater_bank_cells"] = int((disk & A.bank).sum())
        lv[str(rad)] = rec
    layer = {"order": ["terrain_water", "movement_livelihood", "settlement_function", "frame"],
             "routes": routes, "crossings": A.existing_crossings,
             "livelihood": {"within_m": lv, "irrigation": None, "irrigation_missing_reason": "no irrigation data (WP4/C06)",
                            "forest_use": None, "forest_use_missing_reason": "management type unknown (WP10)",
                            "status": "proposed"}}
    return layer


def frame_roads(inp, A):
    """Roads the frame approaches from = the movement layer's routes. Existing routes are given
    facts and are all kept, whatever their per-mode passability (recorded, not used to drop)."""
    keep = {r["source_id"] for r in A.movement["routes"]}
    return [r for r in inp.roads if r.id in keep]
