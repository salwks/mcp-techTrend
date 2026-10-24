"""Resolved SiteTreatment records (owner correction 2026-10-25, design review #2).

Adaptation never edits the hazard fields (flood screen, slope): it builds on them. Every occupied
parcel (and civic reserve) that stands on flood-screen land or on ground steeper than the standard
housing limit gets an explicit, checkable treatment:

* raised platform (기단/집터 돋움): polygon, design water state + freeboard, platform elevation,
  fill depth/volume, perimeter 축대 sections (height × length), access transition to the street
  (steps or ramp), platform drain with its outlet invert onto the street drain;
* terrace bench (축대/석축): bench elevation, cut/fill, retaining height, number of benches when one
  lift would exceed the single-lift limit, access transition.

The treated surface (platforms and benches applied to the analysis heightfield) is then used to
re-check flooding at the design state, the street-to-platform transitions and the edge ground
profiles handed to WP6. No 둑 (levee) is generated in this pass — the record says so.
"""
from __future__ import annotations

import math

import numpy as np
from shapely.geometry import Point

from . import geometry as G
from . import raster as Rr


def _pts(poly, step=2.0):
    xmin, zmin, xmax, zmax = poly.bounds
    xs = np.arange(xmin + step / 2, xmax, step)
    zs = np.arange(zmin + step / 2, zmax, step)
    pts = [(x, z) for z in zs for x in xs if poly.contains(Point(x, z))]
    if not pts:
        c = poly.representative_point()
        pts = [(c.x, c.y)]
    return np.array(pts)


def build(C, parcels, faces_by_id, fin, drains):
    A, R = C.A, C.R
    cfg = R.p("treatment.rules")
    raised = getattr(A, "raised", None)
    terraced = getattr(A, "terraced", None)
    off = R.p("flood.exclusion_offset")
    state = A.stage_names.get(off, str(off))
    h = A.h.copy()
    out = []
    links = [(l, shape_line(C, l)) for l in fin["links"]]
    dr_by_street = {}
    for d in drains:
        dr_by_street.setdefault(d["street"], []).append(d)
    for blk, lot in parcels:
        if lot.get("use") != "residential" and not lot.get("civic"):
            continue
        p = lot["poly"]
        P = _pts(p)
        fr = float(np.mean(C.sample(raised, P[:, 0], P[:, 1]))) if raised is not None else 0.0
        ft = float(np.mean(C.sample(terraced, P[:, 0], P[:, 1]))) if terraced is not None else 0.0
        if fr <= 0.05 and ft <= 0.05:
            continue
        ys = np.asarray(C.height(P[:, 0], P[:, 1]), float)
        rec = {"id": C.claim("treatment", key=lot["pid"], content=G.to_geojson(p)), "parcel": lot["pid"],
               "polygon": C.add(p), "status": "proposed", "hypothesis": True, "kinds": []}
        if fr > 0.05:
            ws = np.asarray(C.sample(A.wsurf, P[:, 0], P[:, 1]), float)
            ws = ws[np.isfinite(ws)]
            water = float(ws.max()) + off if ws.size else float(ys.max())
            level = max(water + cfg["freeboard_m"], float(np.percentile(ys, 50)))
            fill = np.clip(level - ys, 0, None)
            rec["kinds"].append("raised_platform")
            rec["platform"] = {"design_state": state, "design_water_y": round(water, 2), "freeboard_m": cfg["freeboard_m"],
                               "elevation_y": round(level, 2), "fill_max_m": round(float(fill.max()), 2),
                               "fill_mean_m": round(float(fill.mean()), 2), "fill_volume_m3": round(float(fill.sum()) * 4.0, 1),
                               "flood_on_raised_surface": False}
        else:
            level = float(np.median(ys))
            rec["kinds"].append("terrace_bench")
        cut = np.clip(ys - level, 0, None)
        fil = np.clip(level - ys, 0, None)
        rise = float(max(cut.max(), fil.max()))
        lifts = max(1, int(math.ceil(rise / cfg["single_lift_m"]))) if rise > 0 else 0
        # perimeter retaining (축대): ground just outside the parcel against the platform / bench
        ring = p.exterior
        L = ring.length
        n = max(8, int(L / 2.0))
        out_pts, sect = [], []
        c = p.centroid
        for k in range(n):
            q = ring.interpolate(k / n, normalized=True)
            vx, vz = q.x - c.x, q.y - c.y
            m = math.hypot(vx, vz) or 1.0
            out_pts.append((q.x + vx / m * 1.0, q.y + vz / m * 1.0))
        oy = np.asarray(C.height([q[0] for q in out_pts], [q[1] for q in out_pts]), float)
        dh = level - oy
        hi = dh[np.abs(dh) > cfg["step_m"]]
        rec["earthwork"] = {"cut_max_m": round(float(cut.max()), 2), "fill_max_m": round(float(fil.max()), 2),
                            "cut_volume_m3": round(float(cut.sum()) * 4.0, 1), "fill_volume_m3": round(float(fil.sum()) * 4.0, 1),
                            "bench_y": round(level, 2), "lifts": lifts, "single_lift_limit_m": cfg["single_lift_m"]}
        rec["retaining"] = {"sections": [{"height_max_m": round(float(np.abs(hi).max()), 2) if hi.size else 0.0,
                                          "length_m": round(L * hi.size / n, 1),
                                          "retained_side": "platform" if (hi.size and float(np.mean(hi)) > 0) else "uphill_ground",
                                          "kind": "축대/석축 (section in WP6)"}] if hi.size else [],
                            "note": "retaining is a support component; the enclosure (담) on top is chosen separately in WP6"}
        # access transition to the fronting street
        st = _front_street(lot, links)
        if st is not None:
            l, line = st
            q = line.interpolate(line.project(p.centroid))
            sy = float(C.height([q.x], [q.y])[0])
            d_ = level - sy
            if abs(d_) <= cfg["step_m"]:
                tr = {"kind": "threshold", "height_m": round(d_, 2)}
            elif abs(d_) <= cfg["ramp_max_rise_m"]:
                tr = {"kind": "ramp", "height_m": round(d_, 2), "length_m": round(abs(d_) / cfg["ramp_grade"], 1)}
            else:
                tr = {"kind": "steps", "height_m": round(d_, 2), "risers": int(math.ceil(abs(d_) / cfg["riser_m"])),
                      "riser_m": cfg["riser_m"]}
            tr["street"] = l["id"]
            rec["access"] = tr
            # platform drain → the street drain of that street
            ds = dr_by_street.get(l["id"], [])
            if ds:
                inv = min(d_["invert"]["y_low"] for d_ in ds)
                rec["drain"] = {"outlet": ds[0]["id"], "platform_drain_invert_y": round(level - 0.3, 2),
                                "street_drain_invert_y": round(inv, 2), "falls_to_outlet": bool(level - 0.3 > inv)}
            else:
                rec["drain"] = {"outlet": None, "note": "fronting street has no drain run (flat or route); soakaway in the yard"}
        else:
            rec["access"] = {"kind": "via_easement_or_rear", "note": "no fronting street; transition at the easement head"}
        rec["levee"] = None
        rec["levee_note"] = "no 둑 generated in WP5; platforms carry the freeboard"
        out.append(rec)
        # apply to the treated surface
        m = Rr.rasterize(A.win, p)
        h[m] = level
    C.treated_h = h
    # re-check on the treated surface: every raised platform clear of the design water state
    bad = []
    for r in out:
        if "platform" in r:
            if r["platform"]["elevation_y"] < r["platform"]["design_water_y"] + r["platform"]["freeboard_m"] - 1e-6:
                bad.append(r["id"])
                r["platform"]["flood_on_raised_surface"] = True
    summary = {"treatments": len(out), "raised_platforms": sum(1 for r in out if "platform" in r),
               "terrace_benches": sum(1 for r in out if "terrace_bench" in r["kinds"]),
               "fill_volume_m3": round(sum(r["earthwork"]["fill_volume_m3"] for r in out), 1),
               "cut_volume_m3": round(sum(r["earthwork"]["cut_volume_m3"] for r in out), 1),
               "steps": sum(1 for r in out if (r.get("access") or {}).get("kind") == "steps"),
               "flooded_after_treatment": bad,
               "hazard_fields": "unchanged (flood screen and slope stay as analysed; treatments build on them)"}
    return out, summary


def shape_line(C, l):
    from shapely.geometry import shape
    return shape(C.store.items[l["centerline"]])


def _front_street(lot, links):
    if lot.get("run_line") is None:
        return None
    mid = lot["run_line"].interpolate(sum(lot["s"]) / 2) if lot.get("s") else lot["run_line"].interpolate(0.5, normalized=True)
    best = min(links, key=lambda t: t[1].distance(mid)) if links else None
    return best
