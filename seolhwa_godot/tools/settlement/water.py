"""WP4 water data layer: WaterReach (spec 16 GEO-05/06, 01 NAT-03/04, audit 20 K3/WP4).

Each mapped channel (region rivers / fixture channels) is oriented by its mapped surface,
sampled every ``water.station_step_m`` and split into reaches at confluences and every
``water.reach_max_m``. Per reach, one record holds the three shapes on the same id:

* long profile — chainage, normal surface (mapped), design bed (surface − design depth), DEM
  terrain at the centre line, width;
* cross-section — DEM terrain samples across the channel (measured from the height data), the
  design channel inset (width from the data, depth = a test value by bed type), bank tops;
* plan — centre line, width, confluences, crossings.

Bed type is classified from gradient, valley confinement, rock next to the banks and mapped
bars — never from the word river/stream (GEO-05); the mix fractions stay unknown (no survey).
Flow features: rapids, drops, confluences and obstructions are the only foam causes (GEO-06).
Stage states come from ``water.stage_states`` only (the single source, audit K3); per state the
wetted width, dry bed, bank overtopping and lateral flood extent are evaluated on the section,
and every crossing is re-checked per state and per travel mode (V67).
Crossings: mapped crossings are typed; a route meeting water without a mapped crossing gets a
*candidate* record only (not applied — L0–2 keeps it impassable).
"""
from __future__ import annotations

import math

import numpy as np
import shapely
from shapely.geometry import LineString, Point

from . import contract as C
from . import geometry as G
from . import raster as Rr

STATE_ORDER_NOTE = "states ordered by offset (water.stage_states)"


class WaterLayer:
    pass


def _scope(inp):
    return inp.region if not inp.meta.get("fixture") else f"SYNTHETIC.{inp.id}"


def _surface_raster_at(inp, A, xs, zs):
    """Mapped surface near (x, z): nearest known water surface on the full grid."""
    W = A.full_wsurf
    v = Rr.bilinear(inp.grid, np.nan_to_num(W, nan=-9999.0), xs, zs)
    i = np.clip(np.round((np.asarray(xs) - inp.grid.x0) / inp.grid.cell).astype(int), 0, inp.grid.nx - 1)
    j = np.clip(np.round((np.asarray(zs) - inp.grid.z0) / inp.grid.cell).astype(int), 0, inp.grid.nz - 1)
    near = W[j, i]
    return np.where(np.isfinite(near), near, np.where(v > -9000, v, np.nan))


def _channel_paths(inp, A, rules):
    """(feature, xy array, surface array, width array, direction_basis) per channel feature."""
    step = rules.p("water.station_step_m")
    tol = rules.p("water.flow")["flat_tolerance_m"]
    out = []
    for f in inp.water_features:
        if f.centerline is None or f.kind not in ("river", "stream"):
            continue
        if f.points3 and len(f.points3) >= 2:
            P = np.array(f.points3, float)
            line = LineString(P[:, :2])
            seg = np.hypot(np.diff(P[:, 0]), np.diff(P[:, 1]))
            s_pts = np.concatenate([[0.0], np.cumsum(seg)])
            wid = np.array(f.widths if f.widths else [f.width_m] * len(P), float)
            basis_src = "mapped points (region.json rivers[].points y)"
        else:
            line = f.centerline
            s_pts = None
            basis_src = "mapped water surface raster"
        L = line.length
        if L < 2 * step:
            continue
        ss = np.linspace(0, L, int(math.ceil(L / step)) + 1)
        xy = shapely.get_coordinates(shapely.line_interpolate_point(line, ss))
        if s_pts is not None:
            y = np.interp(ss, s_pts, P[:, 2])
            w = np.interp(ss, s_pts, wid)
        else:
            y = _surface_raster_at(inp, A, xy[:, 0], xy[:, 1])
            w = np.full(len(ss), float(f.width_m))
        if not np.isfinite(y).all():
            y = np.where(np.isfinite(y), y, np.nanmedian(y) if np.isfinite(y).any() else 0.0)
        if y[-1] > y[0] + tol:
            xy, y, w = xy[::-1].copy(), y[::-1].copy(), w[::-1].copy()
            basis = f"surface falls along the reversed data order ({basis_src})"
        elif abs(y[-1] - y[0]) <= tol:
            basis = f"flat mapped surface: direction = data order (unknown) ({basis_src})"
        else:
            basis = f"surface falls along the data order ({basis_src})"
        out.append((f, xy, y, w, basis))
    return out


def _normals(xy):
    t = np.gradient(xy, axis=0)
    n = np.hypot(t[:, 0], t[:, 1])
    n[n == 0] = 1.0
    t = t / n[:, None]
    left = np.stack([t[:, 1], -t[:, 0]], axis=1)  # left bank looking downstream (x east, z south)
    return t, left


def build(inp, A, T, rules) -> WaterLayer:
    W = WaterLayer()
    W.states = sorted(rules.p("water.stage_states"), key=lambda s: s["offset"])
    W.paths = _channel_paths(inp, A, rules)
    step = rules.p("water.station_step_m")
    half = rules.p("water.section_half_m")
    sstep = rules.p("water.section_step_m")
    bz = rules.p("water.bank_zone_m")
    offs = np.arange(-half, half + 1e-9, sstep)
    H = inp.height
    reaches = []
    # confluence chainages: another channel's downstream end close to this line
    ends = {f.id: xy[-1] for f, xy, _, _, _ in W.paths}
    for f, xy, y, w, basis in W.paths:
        line = LineString(xy)
        ss = np.concatenate([[0.0], np.cumsum(np.hypot(np.diff(xy[:, 0]), np.diff(xy[:, 1])))])
        conf = []
        for g_id, e in ends.items():
            if g_id == f.id:
                continue
            d = line.distance(Point(e))
            if d <= float(np.max(w)) / 2 + 15.0:
                conf.append({"tributary": g_id, "chainage": round(float(line.project(Point(e))), 1)})
        ss0 = np.concatenate([[0.0], np.cumsum(np.hypot(np.diff(xy[:, 0]), np.diff(xy[:, 1])))])
        for c in conf:  # snap to the station grid (reach cuts are at stations)
            c["chainage"] = float(ss0[int(np.argmin(np.abs(ss0 - c["chainage"])))])
        conf.sort(key=lambda c: (c["chainage"], c["tributary"]))
        t, left = _normals(xy)
        # cross-section samples (terrain, measured from the height data)
        X = xy[:, 0][:, None] + left[:, 0][:, None] * offs[None, :]
        Z = xy[:, 1][:, None] + left[:, 1][:, None] * offs[None, :]
        prof = Rr.bilinear(inp.grid, H, X.ravel(), Z.ravel()).reshape(X.shape)
        centre = Rr.bilinear(inp.grid, H, xy[:, 0], xy[:, 1])
        breaks = sorted({0.0, float(ss[-1])} | {c["chainage"] for c in conf if 0 < c["chainage"] < ss[-1]})
        rmax = rules.p("water.reach_max_m")
        cuts = []
        for a, b in zip(breaks, breaks[1:]):
            n_ = max(1, int(math.ceil((b - a) / rmax)))
            cuts += [a + (b - a) * k / n_ for k in range(n_)]
        # cut at stations; neighbouring reaches share the cut station (continuous profile)
        qs = sorted({int(np.argmin(np.abs(ss - c))) for c in cuts} | {0, len(ss) - 1})
        for k, (qa, qb) in enumerate(zip(qs, qs[1:])):
            idx = np.arange(qa, qb + 1)
            if len(idx) < 2:
                continue
            a, b = float(ss[qa]), float(ss[qb])
            reaches.append({"feature": f, "k": k + 1, "idx": idx, "ss": ss[idx], "xy": xy[idx], "y": y[idx], "w": w[idx],
                            "prof": prof[idx], "centre": centre[idx], "left": left[idx], "basis": basis,
                            "confluences": [c for c in conf if a - 1e-6 <= c["chainage"] < b - 1e-6
                                            or (qb == len(ss) - 1 and abs(c["chainage"] - b) < 1e-6)]})
    W.offs = offs
    W.raw = reaches
    for r in reaches:
        _classify(r, inp, A, T, rules)
        _states(r, W, rules)
    _link(reaches)
    W.crossings, W.candidates = _crossings(inp, A, W, rules)
    return W


def _classify(r, inp, A, T, rules):
    th = rules.p("water.bed.thresholds")
    s, y, w = r["ss"], r["y"], r["w"]
    L = float(s[-1] - s[0])
    grade = float(-(np.polyfit(s - s[0], y, 1)[0])) if L > 0 else 0.0
    r["grade"], r["length_m"] = grade, L
    # confinement: width of ground below the high_major level vs channel width
    hm = next((st for st in rules.p("water.stage_states") if st.get("exclusion")), None)
    lev = y + (hm["offset"] if hm else 1.5)
    half = rules.p("water.section_half_m")
    sstep = rules.p("water.section_step_m")
    o = np.arange(-half, half + 1e-9, sstep)
    widths = []
    for q in range(len(s)):
        below = r["prof"][q] <= lev[q]
        c0 = len(o) // 2
        inch = np.abs(o) <= w[q] / 2
        below = below | inch
        lft = c0
        while lft - 1 >= 0 and below[lft - 1]:
            lft -= 1
        rgt = c0
        while rgt + 1 < len(o) and below[rgt + 1]:
            rgt += 1
        widths.append(float(o[rgt] - o[lft]) + sstep)
    conf = float(np.median(np.array(widths) / np.maximum(w, 0.5)))
    # rock next to the banks / mapped bars (2 m work window only)
    rock_frac = bar_frac = None
    g = getattr(T, "ground", None)
    if g is not None:
        win = A.win
        pts = []
        for q in range(len(s)):
            for side in (-1, 1):
                for d in (w[q] / 2 + 1.0, w[q] / 2 + 3.0, w[q] / 2 + 6.0):
                    pts.append((r["xy"][q, 0] + side * r["left"][q, 0] * d, r["xy"][q, 1] + side * r["left"][q, 1] * d))
        pts = np.array(pts)
        ii = np.round((pts[:, 0] - win.x0) / win.cell).astype(int)
        jj = np.round((pts[:, 1] - win.z0) / win.cell).astype(int)
        ok = (ii >= 0) & (ii < win.nx) & (jj >= 0) & (jj < win.nz)
        if ok.sum() >= max(3, len(pts) // 3):
            from .terrain import GC
            vals = g[jj[ok], ii[ok]]
            land = vals != GC["water"]
            n = max(1, int(land.sum()))
            rock_frac = round(float(np.isin(vals, [GC["cliff"], GC["rock_exposure"]]).sum()) / n, 4)
            bar_frac = round(float((vals == GC["bar_gravel"]).sum()) / n, 4)
    if rock_frac is not None and rock_frac >= th["rock_adjacent_frac"] and grade >= th["rock_grade"]:
        bt = "bedrock"
    elif grade >= th["steep_grade"]:
        bt = "step_pool_boulder"
    elif grade >= th["riffle_grade"] or (bar_frac or 0) > 0.05:
        bt = "riffle_pool_gravel"
    elif conf >= th["unconfined_ratio"]:
        bt = "alluvial_sand_gravel"
    else:
        bt = "riffle_pool_gravel"
    r["bed_type"] = bt
    r["confinement"] = round(conf, 3)
    r["rock_frac"], r["bar_frac"] = rock_frac, bar_frac
    depth = rules.p("water.section.depth_by_bed")[bt]
    r["depth"] = depth


def _states(r, W, rules):
    br = rules.p("water.section.bank_ratio")
    bz = rules.p("water.bank_zone_m")
    o = W.offs
    sstep = o[1] - o[0]
    w, y, d = r["w"], r["y"], r["depth"]
    wbed = np.maximum(0.0, w - 2 * d * br)
    # bank tops (left = +offset side)
    btl, btr = [], []
    for q in range(len(w)):
        lz = (o >= w[q] / 2) & (o <= w[q] / 2 + bz)
        rz = (o <= -w[q] / 2) & (o >= -w[q] / 2 - bz)
        btl.append(float(r["prof"][q][lz].max()) if lz.any() else float("nan"))
        btr.append(float(r["prof"][q][rz].max()) if rz.any() else float("nan"))
    r["bank_left"], r["bank_right"] = np.array(btl), np.array(btr)
    res = []
    for st in W.states:
        off = st["offset"]
        lev = y + off
        if off <= 0:
            dep = d + off
            wet = np.where(dep > 0, np.minimum(w, wbed + 2 * dep * br), 0.0)
            over_l = over_r = np.zeros(len(w), bool)
            ext_l = ext_r = np.zeros(len(w))
        else:
            wet = w.copy()
            over_l = lev > r["bank_left"]
            over_r = lev > r["bank_right"]
            ext_l, ext_r = np.zeros(len(w)), np.zeros(len(w))
            for q in range(len(w)):
                for side, arr in ((1, ext_l), (-1, ext_r)):
                    sel = (side * o) > w[q] / 2
                    prof = r["prof"][q][sel] if side == 1 else r["prof"][q][sel][::-1]
                    k = 0
                    while k < len(prof) and prof[k] <= lev[q]:
                        k += 1
                    arr[q] = k * sstep
        res.append({"key": st["key"], "name": st["name"], "offset_world_m": off,
                    "wetted_width_m": {"min": round(float(wet.min()), 2), "median": round(float(np.median(wet)), 2),
                                       "max": round(float(wet.max()), 2)},
                    "dry_bed_fraction": round(float(np.mean(wet <= 0)), 4),
                    "exposed_bed_width_m": round(float(np.median(np.maximum(0.0, w - wet))), 2),
                    "bank_overtopped_fraction": {"left": round(float(np.mean(over_l)), 4), "right": round(float(np.mean(over_r)), 4)},
                    "flooded_beyond_bank_m": {"left": round(float(ext_l.max()), 1), "right": round(float(ext_r.max()), 1)},
                    "screen": bool(st.get("screen")), "exclusion": bool(st.get("exclusion")),
                    "status": "proposed", "basis": "design channel (test depth) + DEM banks"})
    r["states"] = res
    # flow features (foam causes only where there is a cause)
    fl = rules.p("water.flow")
    s = r["ss"]
    seg = []
    if len(s) >= 2:
        g = -np.diff(y) / np.maximum(np.diff(s), 1e-9)
        drop = -np.diff(y)
        for q in range(len(g)):
            a, b = float(s[q]), float(s[q + 1])
            nb = max(g[q - 1] if q > 0 else 0.0, g[q + 1] if q + 1 < len(g) else 0.0)
            if drop[q] >= fl["drop_m"] and g[q] >= 2 * max(nb, 0.0) and g[q] >= fl["rapid_grade"]:
                seg.append({"kind": "drop", "chainage": [round(a, 1), round(b, 1)], "cause": f"abrupt surface step {drop[q]:.2f} m", "foam": True})
            elif g[q] >= fl["rapid_grade"]:
                seg.append({"kind": "rapid", "chainage": [round(a, 1), round(b, 1)], "cause": f"surface grade {g[q]:.3f}", "foam": True})
            elif abs(g[q]) <= fl["still_grade"]:
                seg.append({"kind": "still", "chainage": [round(a, 1), round(b, 1)], "cause": "near-flat surface", "foam": False})
            elif g[q] < -fl["flat_tolerance_m"] / max(float(s[q + 1] - s[q]), 1e-9):
                seg.append({"kind": "reverse", "chainage": [round(a, 1), round(b, 1)], "cause": f"surface rises {(-drop[q]):.2f} m downstream", "foam": False})
    for c in r["confluences"]:
        hw = float(np.max(w)) / 2 + 5
        seg.append({"kind": "confluence", "chainage": [round(c["chainage"] - hw, 1), round(c["chainage"] + hw, 1)],
                    "cause": f"tributary {c['tributary']} joins", "foam": True})
    r["flow_segments"] = _merge_segments(seg)


def _merge_segments(seg):
    seg = sorted(seg, key=lambda x: (x["kind"], x["chainage"][0]))
    out = []
    for x in seg:
        if out and out[-1]["kind"] == x["kind"] and x["kind"] in ("still", "rapid", "reverse") and abs(out[-1]["chainage"][1] - x["chainage"][0]) < 1e-6:
            out[-1]["chainage"][1] = x["chainage"][1]
            continue
        out.append(dict(x, chainage=list(x["chainage"])))
    return sorted(out, key=lambda x: (x["chainage"][0], x["kind"]))


def _link(reaches):
    byf = {}
    for r in reaches:
        byf.setdefault(r["feature"].id, []).append(r)
    for f_id, rs in byf.items():
        rs.sort(key=lambda r: r["ss"][0])
        for a, b in zip(rs, rs[1:]):
            a.setdefault("down", []).append(b)
            b.setdefault("up", []).append(a)
    for r in reaches:
        for c in r["confluences"]:
            trib = byf.get(c["tributary"])
            if not trib:
                continue
            last = trib[-1]
            # the reach of r that starts at the confluence receives the tributary
            target = None
            for q in byf[r["feature"].id]:
                if q["ss"][0] - 1e-6 <= c["chainage"] <= q["ss"][-1] + 1e-6:
                    target = q
                    if abs(q["ss"][0] - c["chainage"]) < 1.0:
                        break
            if target is not None and target is not last:
                last.setdefault("down", []).append(target)
                target.setdefault("up", []).append(last)


def _state_index(W, key):
    return [s["key"] for s in W.states].index(key)


def crossing_states(cls, rule, W, depth, level_normal, bank_top, modes_all=("foot", "pack_horse", "cart")):
    out = []
    for st in W.states:
        off = st["offset"]
        modes = {}
        for m in modes_all:
            if m not in rule["modes"]:
                modes[m] = {"passable": False, "reason": f"{cls} does not carry {m} (test value)"}
                continue
            kind = rule["rule"]
            if kind == "seasonal" and _state_index(W, st["key"]) >= _state_index(W, rule["removed_from"]):
                fb = W.rules_crossing[rule["fallback"]]
                dmax = fb["max_depth_m"].get(m)
                dd = depth + off
                ok = dmax is not None and dd <= dmax
                modes[m] = {"passable": bool(ok), "reason": f"removed at {rule['removed_from']} → ford: depth {dd:.2f} m vs {dmax} m"}
            elif kind == "seasonal":
                modes[m] = {"passable": True, "reason": "bridge in place"}
            elif kind == "depth":
                dd = depth + off
                ok = dd <= rule["max_depth_m"][m]
                modes[m] = {"passable": bool(ok), "reason": f"depth {max(dd, 0):.2f} m vs {rule['max_depth_m'][m]} m"}
            elif kind == "stone_top":
                ok = off <= rule["stone_top_above_normal_m"]
                modes[m] = {"passable": bool(ok), "reason": f"level +{off:g} vs stone top +{rule['stone_top_above_normal_m']}"}
            elif kind == "deck":
                deck = bank_top + rule["deck_above_bank_m"] if np.isfinite(bank_top) else None
                lev = level_normal + off
                ok = deck is not None and lev <= deck
                modes[m] = {"passable": bool(ok), "reason": (f"level {lev:.2f} vs deck {deck:.2f} (deck = bank top + test value)"
                                                             if deck is not None else "deck height unknown")}
            elif kind == "operating":
                ok = _state_index(W, st["key"]) < _state_index(W, rule["suspended_from"])
                modes[m] = {"passable": bool(ok), "reason": "ferry operating" if ok else f"suspended from {rule['suspended_from']}"}
        out.append({"key": st["key"], "offset_world_m": off, "modes": modes})
    return out


def _nearest_station(W, x, z, feature_id=None):
    best = None
    for r in W.raw:
        if feature_id and r["feature"].id != feature_id:
            continue
        d = np.hypot(r["xy"][:, 0] - x, r["xy"][:, 1] - z)
        q = int(np.argmin(d))
        if best is None or d[q] < best[0]:
            best = (float(d[q]), r, q)
    return best


def _crossings(inp, A, W, rules):
    rules_c = rules.p("water.crossing_rules")
    W.rules_crossing = rules_c
    types = rules.p("water.crossing_types")
    match = rules.p("water.crossing.match_m")
    out, cands = [], []
    scope = _scope(inp)
    for c in inp.crossings:
        x, z = c["xz"]
        b = _nearest_station(W, x, z, c.get("river_id")) or _nearest_station(W, x, z)
        cls = types.get(c.get("type", ""), None)
        rec = {"id": f"crossing:{scope}:{c['id']}", "source_id": c["id"], "name": c.get("name"), "type_ko": c.get("type"),
               "class": cls or "unknown", "mapped": True, "xz": [G.r2(x), G.r2(z)], "route": c.get("road_id"),
               "river": c.get("river_id"), "notes": c.get("notes")}
        if b is None or b[0] > match:
            rec.update({"reach": None, "chainage": None, "states": None,
                        "missing_reason": "no mapped channel within match distance in this window"})
        else:
            d, r, q = b
            rec["reach_ref"] = (r["feature"].id, r["k"])
            rec["chainage"] = round(float(r["ss"][q]), 1)
            rec["distance_to_channel_m"] = round(d, 1)
            if cls in rules_c:
                bt = np.nanmax([r["bank_left"][q], r["bank_right"][q]])
                rec["states"] = crossing_states(cls, rules_c[cls], W, r["depth"], float(r["y"][q]), float(bt))
            else:
                rec["states"] = None
                rec["missing_reason"] = f"crossing type {c.get('type')!r} has no rule"
            r.setdefault("crossings", []).append(rec["id"])
            if cls in ("stepping_stones", "ford", "stone_bridge", "bridge", "brush_bridge"):
                hw = float(r["w"][q]) / 2 + 3
                r["flow_segments"].append({"kind": "obstruction", "chainage": [round(rec["chainage"] - hw, 1), round(rec["chainage"] + hw, 1)],
                                           "cause": f"{cls} {c['id']}", "foam": True})
                r["flow_segments"] = sorted(r["flow_segments"], key=lambda x: (x["chainage"][0], x["kind"]))
        st, hyp = C.status_of(c.get("confidence"))
        src = [f"region_data/{inp.region}/region.json#crossings:{c['id']}"] if not inp.meta.get("fixture") else ["fixture"]
        rec["evidence"] = {"status": st, "hypothesis": hyp, "confidence": c.get("confidence")}
        rec["rule_status"] = "proposed (test values: water.crossing_rules)"
        rec["meta"] = C.meta(rec["id"], status="proposed", sources=src, rules_hash=rules.hash, hypothesis=hyp,
                             content={k: v for k, v in rec.items() if k != "reach_ref"})
        out.append(rec)
    # route meets water without a mapped crossing → candidate only (not applied)
    for e in A.existing_crossings:
        if e["type"] != "unmapped":
            continue
        x, z = e["xz"]
        b = _nearest_station(W, x, z)
        rec = {"id": f"crossing_candidate:{scope}:{e['id']}", "xz": e["xz"], "mapped": False, "applied": False,
               "note": "route meets water without a mapped crossing; L0–2 keeps it impassable. A typed crossing needs a source or an owner decision"}
        if b is not None and b[0] <= match:
            d, r, q = b
            rec["reach_ref"] = (r["feature"].id, r["k"])
            rec["chainage"] = round(float(r["ss"][q]), 1)
            ford = rules_c["ford"]
            ok = [st["key"] for st in W.states if r["depth"] + st["offset"] <= ford["max_depth_m"]["foot"]]
            rec["ford_feasible_on_foot_at"] = ok
            rec["design_depth_m"] = r["depth"]
            rec["suggested_classes"] = (["ford", "stepping_stones"] if "normal" in ok else ["bridge", "ferry"])
        rec["meta"] = C.meta(rec["id"], status="proposed", sources=["derived: route ∩ water"], rules_hash=rules.hash,
                             content={k: v for k, v in rec.items() if k != "reach_ref"})
        cands.append(rec)
    return out, cands


# ---------------------------------------------------------------- records
def records(W, inp, A, T, rules, store, profile_natural, catch_ids):
    from .terrain import catchment_at
    scope = _scope(inp)
    rid = {}
    for r in W.raw:
        rid[id(r)] = f"water:{scope}:{r['feature'].id.replace('#', '_')}:{r['k']:02d}"
    xid = {}
    for r in W.raw:
        xid[(r["feature"].id, r["k"])] = rid[id(r)]
    reaches = []
    hints = _hints(profile_natural)
    for r in W.raw:
        f = r["feature"]
        line = LineString(r["xy"])
        stations = [{"chainage": round(float(s), 1), "xz": [G.r2(p[0]), G.r2(p[1])], "surface_y": round(float(y), 3),
                     "bed_y_design": round(float(y - r["depth"]), 3), "terrain_centre_y": round(float(t), 3),
                     "width_m": round(float(w), 2)}
                    for s, p, y, t, w in zip(r["ss"], r["xy"], r["y"], r["centre"], r["w"])]
        qm = len(r["ss"]) // 2
        o = W.offs
        sel = np.abs(o) <= min(rules.p("water.section_half_m"), max(40.0, 4 * float(r["w"][qm])))
        rep = {"chainage": round(float(r["ss"][qm]), 1), "offsets_m": [round(float(v), 1) for v in o[sel]],
               "terrain_y": [round(float(v), 3) for v in r["prof"][qm][sel]], "surface_y": round(float(r["y"][qm]), 3),
               "channel": {"width_m": round(float(r["w"][qm]), 2), "depth_m": C.measure(r["depth"], "world_m", "proposed",
                                                                                         source="water.section.depth_by_bed (test value)"),
                           "bed_width_m": round(max(0.0, float(r["w"][qm]) - 2 * r["depth"] * rules.p("water.section.bank_ratio")), 2),
                           "bank_ratio": rules.p("water.section.bank_ratio")},
               "bank_top_y": {"left": round(float(r["bank_left"][qm]), 3), "right": round(float(r["bank_right"][qm]), 3)},
               "parts": ["water", "submerged_bed", "exposed_bed(low)", "bank", "floodable_ground"],
               "terrain_source": "height data (measured)", "channel_source": "design inset (test values)"}
        tms = np.array(r["centre"]) - np.array(r["y"])
        gapv = r["y"] - np.minimum(r["bank_left"], r["bank_right"])
        film = gapv > rules.p("water.flow")["flat_tolerance_m"]
        cx, cz = r["xy"][-1]
        down_c = catchment_at(T, cx, cz)
        hint = hints.get(f.id) or (hints.get(f.attrs.get("name")) if f.attrs.get("name") else None)
        body = {
            "feature": f.id, "name": f.attrs.get("name") or f.id, "kind": f.kind,
            "upstream": sorted(rid[id(u)] for u in r.get("up", [])), "downstream": sorted(rid[id(d)] for d in r.get("down", [])),
            "long_profile": {"stations": stations, "length_m": round(r["length_m"], 1), "grade": round(r["grade"], 5),
                             "drop_m": round(float(r["y"][0] - r["y"][-1]), 3),
                             "terrain_minus_surface_m": {"min": round(float(tms.min()), 3), "median": round(float(np.median(tms)), 3),
                                                         "max": round(float(tms.max()), 3)},
                             "note": "surface = mapped normal stage; bed = design (surface − test depth); terrain from height data"},
            "cross_section": {"representative": rep, "stations_with_surface_above_bank": int(film.sum()),
                              "surface_above_bank_max_m": round(float(max(0.0, np.nanmax(gapv))), 3),
                              "stations": len(r["ss"]),
                              "status": "proposed"},
            "plan": {"centerline": store.add(line), "width_m": {"min": round(float(np.min(r["w"])), 2), "median": round(float(np.median(r["w"])), 2),
                                                               "max": round(float(np.max(r["w"])), 2)},
                     "sinuosity": round(r["length_m"] / max(1e-6, math.hypot(*(r["xy"][-1] - r["xy"][0]))), 4),
                     "confluences": r["confluences"], "crossings": sorted(r.get("crossings", []))},
            "flow": {"direction_basis": r["basis"], "segments": r["flow_segments"],
                     "exception": _exception(r, T),
                     "foam_rule": "foam only on drop / rapid / confluence / obstruction segments (GEO-06)"},
            "bed_mix": {"type": r["bed_type"],
                        "basis": {"grade": round(r["grade"], 5), "confinement_ratio": r["confinement"],
                                  "rock_adjacent_fraction": r["rock_frac"], "bar_fraction": r["bar_frac"],
                                  "not_from": "kind/name (river/stream)"},
                        "components": _components(r["bed_type"]), "status": "proposed"},
            "banks": {"left_top_y": {"min": round(float(np.nanmin(r["bank_left"])), 3), "max": round(float(np.nanmax(r["bank_left"])), 3)},
                      "right_top_y": {"min": round(float(np.nanmin(r["bank_right"])), 3), "max": round(float(np.nanmax(r["bank_right"])), 3)},
                      "side_convention": "left/right looking downstream"},
            "states": r["states"],
            "catchment": {"dem_catchment_at_end": catch_ids.get(down_c),
                          "dem_upslope_area_m2_at_end": _acc_at(T, cx, cz),
                          "region_catchment_km2": f.attrs.get("catchment_km2"),
                          "note": "DEM area is window-limited (game m²); region value is source km² of the whole river"},
            "region_hint": hint,
            "region_attrs": {k: f.attrs.get(k) for k in ("grade", "flows_to", "parent", "confidence")} if f.attrs else None,
        }
        st, hyp = C.status_of(f.attrs.get("confidence")) if f.attrs else ("proposed", False)
        src = ([f"region_data/{inp.region}/region.json#rivers:{f.id}"] + ([f.attrs["source"]] if isinstance(f.attrs.get("source"), str) else list(f.attrs.get("source") or [])))\
            if not inp.meta.get("fixture") else ["fixture"]
        body["evidence"] = {"channel_line": st, "hypothesis": hyp}
        body["meta"] = C.meta(rid[id(r)], status="proposed", sources=src, rules_hash=rules.hash, hypothesis=hyp,
                              content=body)
        reaches.append(body)
    bodies = reaches
    xs = []
    for c in W.crossings:
        c2 = dict(c)
        ref = c2.pop("reach_ref", None)
        c2["reach"] = xid.get(tuple(ref)) if ref else None
        xs.append(c2)
    cs = []
    for c in W.candidates:
        c2 = dict(c)
        ref = c2.pop("reach_ref", None)
        c2["reach"] = xid.get(tuple(ref)) if ref else None
        cs.append(c2)
    bodies_lake = []
    for f in inp.water_features:
        if f.kind in ("lake", "sea", "sea_river", "spring"):
            bodies_lake.append({"id": f"waterbody:{scope}:{f.id}", "kind": f.kind, "freshwater": f.freshwater,
                                "geometry": store.add(f.area) if f.area is not None and not f.area.is_empty else None,
                                "flow": ("still or tidal water: no downstream flow is forced (NAT-04)"),
                                "states": [{"key": s["key"], "offset_world_m": s["offset"], "status": "proposed"} for s in W.states],
                                "note": f.surface_note})
    return bodies, xs, cs, bodies_lake


def _exception(r, T):
    """A reverse surface is an exception state only where the reach lies in a closed basin
    (internal sink catchment): still water / 정수역 (spec 01 NAT-03-1). Otherwise it stays a failure."""
    if not any(sg["kind"] == "reverse" for sg in r["flow_segments"]):
        return None
    from .terrain import catchment_at
    q = int(np.argmin(r["y"]))
    l = catchment_at(T, float(r["xy"][q, 0]), float(r["xy"][q, 1]))
    o = T.outlet_cell.get(l)
    if o is not None and T.sinks.flat[o]:
        return {"state": "still_water_internal_basin", "reason": "reach lies in a closed (internal sink) catchment",
                "status": "proposed"}
    return None


def _acc_at(T, x, z):
    i, j = T.gc.ij(x, z)
    if not T.gc.inside(i, j):
        return None
    jj, ii = j, i
    # largest upslope area within one coarse cell (the channel cell next to the end point)
    a = T.acc.reshape(T.hc.shape)[max(0, jj - 1):jj + 2, max(0, ii - 1):ii + 2]
    return round(float(a.max()), 1)


def _components(bt):
    roles = {"bedrock": {"bedrock": "dominant_candidate", "boulder": "present_candidate"},
             "step_pool_boulder": {"boulder": "dominant_candidate", "gravel": "present_candidate", "bedrock": "possible"},
             "riffle_pool_gravel": {"gravel": "dominant_candidate", "sand": "present_candidate", "boulder": "possible"},
             "alluvial_sand_gravel": {"sand": "dominant_candidate", "gravel": "present_candidate", "fine": "possible"}}[bt]
    out = {}
    for k in ("bedrock", "boulder", "gravel", "sand", "fine"):
        out[k] = {"role": roles.get(k, "not_indicated"),
                  "fraction": C.measure(None, "fraction", missing_reason="no bed survey (21: river.sections U); class is a design inference")}
    return out


def _hints(prof):
    out = {}
    if not prof:
        return out
    for k, v in prof.items():
        if not k.startswith("river.") or v.get("value") is None:
            continue
        key = k.split(".", 1)[1]
        out[key] = {"field": k, **v}
        for name in ("요천", "람천", "만수천", "형산강", "북천", "남대천", "성천강", "황주천", "대동강", "개천"):
            if name in (v.get("value") or ""):
                out.setdefault(name, {"field": k, **v})
    return out


def stage_impacts(inp, A, W, movement, rules, locks):
    """V67: per stage state, what the change touches — crossings, routes, riverside work spots,
    vegetation/farmland, locks. Same state keys and offsets as RegionProfile.water_states."""
    lu = inp.meta.get("landuse")
    luw = lu[A.sl] if lu is not None else None
    names = inp.meta.get("landuse_classes", {}) if lu is not None else {}
    cell_a = A.win.cell ** 2
    out = []
    route_lines = {r.id: r.line for r in inp.roads}
    for st in W.states:
        off = st["offset"]
        if off > 0 and off in A.floods:
            fm = A.floods[off] & ~A.water
        else:
            fm = np.zeros(A.win.shape, bool)
        rec = {"key": st["key"], "name": st["name"], "offset_world_m": off, "status": "proposed"}
        if luw is not None:
            rec["flooded_by_landuse_m2"] = {names.get(int(k), str(int(k))): round(float((fm & (luw == k)).sum()) * cell_a, 1)
                                            for k in sorted(set(np.unique(luw[fm]).tolist()) - {255})} if fm.any() else {}
        else:
            rec["flooded_by_landuse_m2"] = {"farmland": round(float((fm & A.farmland).sum()) * cell_a, 1),
                                            "other": round(float((fm & ~A.farmland).sum()) * cell_a, 1)}
        rec["riverside_work_cells_flooded"] = int((fm & A.bank).sum())
        rec["riverside_work_cells"] = int(A.bank.sum())
        rec["exposed_bed_m2"] = round(sum(float(np.trapezoid(np.maximum(0.0, r["w"] - _wet(r, off, rules)), r["ss"]))
                                          for r in W.raw), 1) if off < 0 else 0.0
        xs = {}
        for c in W.crossings:
            if not c.get("states"):
                xs[c["id"]] = None
                continue
            s_ = next(s for s in c["states"] if s["key"] == st["key"])
            xs[c["id"]] = {m: v["passable"] for m, v in s_["modes"].items()}
        rec["crossings"] = xs
        rts = []
        for rt in movement["routes"]:
            line = route_lines.get(rt["source_id"])
            L_in = 0.0
            if line is not None and fm.any():
                n = max(2, int(line.length / A.win.cell))
                pts = shapely.get_coordinates(shapely.line_interpolate_point(line, np.linspace(0, line.length, n)))
                ii = np.round((pts[:, 0] - A.win.x0) / A.win.cell).astype(int)
                jj = np.round((pts[:, 1] - A.win.z0) / A.win.cell).astype(int)
                ok = (ii >= 0) & (ii < A.win.nx) & (jj >= 0) & (jj < A.win.nz)
                L_in = float(fm[jj[ok], ii[ok]].sum()) * line.length / n
            on = [c for c in W.crossings if c.get("route") == rt["source_id"] and c.get("states")]
            modes = {}
            for m in ("foot", "pack_horse", "cart"):
                cut = [c["id"] for c in on if not xs[c["id"]][m]]
                modes[m] = "cut" if cut else ("wet" if L_in > 0 else "open")
            rts.append({"route": rt["meta"]["stable_id"], "inundated_length_m": round(L_in, 1), "modes": modes,
                        "crossings": sorted(c["id"] for c in on)})
        rec["routes"] = rts
        lk = 0
        for l in locks:
            g = l.get("geom")
            if g is not None and fm.any():
                m = Rr.rasterize(A.win, g)
                lk += int((m & fm).any())
        rec["locks_flooded"] = lk
        out.append(rec)
    return out


def _wet(r, off, rules):
    br = rules.p("water.section.bank_ratio")
    d = r["depth"]
    wbed = np.maximum(0.0, r["w"] - 2 * d * br)
    dep = d + off
    return np.where(dep > 0, np.minimum(r["w"], wbed + 2 * dep * br), 0.0)
