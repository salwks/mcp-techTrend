"""Layer 4 — water network for planning (L3-8 3회차 §2 water/drainage, VIL-05, BLD-07, V49).

(The WP4 data layer is `water.py`; this module is the planning network built on it.)

* Channels: every WP4 reach near the settlement. Coordinator decision 2026-10-25 (WP4 open issue
  1): planning uses the **carved channel cross-section of the heightfield** as the effective wet
  width/geometry; the mapped width is kept as a separate proposed attribute and reaches where the
  two disagree are flagged. No terrain re-bake.
* Crossings: mapped WP4 crossings (fords carry the riffle section, decision 2), Layer-2 culverts,
  and new typed crossings for new streets (straight bank-to-bank within 20° of the channel normal,
  dry abutments, supported span variant). New fords are never generated. A bridge does not join
  the street graph to the water graph.
* Street drains: directed links along the downhill side with an invert profile; minimum fall
  0.5 %; every low end needs an outlet (downstream drain, channel/drainage reserve by a descending
  path, or a wall water passage). No outlet is ever manufactured; flat runs ask for a grading
  contract.
* 빨래터 (laundry) access reservation on a freshwater bank with stage-dependent use.
"""
from __future__ import annotations

import math

import numpy as np
import shapely
from scipy import ndimage
from shapely.geometry import LineString, Point, Polygon

from . import geometry as G
from . import raster as Rr
from . import routing as Rt
from .layout_ctx import union


def channels(C):
    """Effective (carved) wet geometry per reach + mapped width attribute + disagreement flags."""
    R, A, inp = C.R, C.A, C.inp
    half = R.p("layout.water.carved_half_m")
    dis = R.p("layout.water.width_disagreement")
    near = C.territory.buffer(200.0)
    out = []
    polys = []
    full = inp.grid
    for r in C.layer["water"]["reaches"]:
        st = r["long_profile"]["stations"]
        if len(st) < 2:
            continue
        xy = np.array([s["xz"] for s in st], float)
        if not LineString(xy).intersects(near):
            continue
        quads = []
        rows = []
        prev = None
        for k, s in enumerate(st):
            a = xy[max(0, k - 1)]
            b = xy[min(len(xy) - 1, k + 1)]
            tx, tz = b - a
            n = math.hypot(tx, tz) or 1.0
            nx_, nz_ = -tz / n, tx / n    # left normal (x,z math sense)
            offs = np.arange(-half, half + 1e-9, 1.0)
            px = s["xz"][0] + offs * nx_
            pz = s["xz"][1] + offs * nz_
            ty = Rr.bilinear(full, inp.height, px, pz)
            sy = s.get("surface_y")
            if sy is None:
                rows.append({"chainage": s["chainage"], "carved_width_m": None, "mapped_width_m": s.get("width_m")})
                prev = None
                continue
            wet = ty < sy
            c0 = int(np.argmin(np.abs(offs)))
            if not wet[c0]:
                cand = np.nonzero(wet & (np.abs(offs) <= 3.0))[0]
                c0 = int(cand[np.argmin(np.abs(offs[cand]))]) if cand.size else None
            if c0 is None:
                # no carved section below the mapped surface: fall back to the mapped width (flagged)
                mw = float(s.get("width_m") or 0.0)
                rows.append({"chainage": s["chainage"], "carved_width_m": 0.0, "mapped_width_m": s.get("width_m"),
                             "effective_source": "mapped (no carved section below the mapped surface)"})
                if mw > 0:
                    L = (s["xz"][0] - mw / 2 * nx_, s["xz"][1] - mw / 2 * nz_)
                    Rr_ = (s["xz"][0] + mw / 2 * nx_, s["xz"][1] + mw / 2 * nz_)
                    if prev is not None:
                        q = Polygon([prev[0], prev[1], Rr_, L]).buffer(0)
                        if not q.is_empty:
                            quads.append(q)
                    prev = (L, Rr_)
                else:
                    prev = None
                continue
            lo = c0
            while lo > 0 and wet[lo - 1]:
                lo -= 1
            hi = c0
            while hi < len(offs) - 1 and wet[hi + 1]:
                hi += 1
            wl, wr = offs[lo] - 0.5, offs[hi] + 0.5
            cw = float(wr - wl)
            L = (s["xz"][0] + wl * nx_, s["xz"][1] + wl * nz_)
            Rr_ = (s["xz"][0] + wr * nx_, s["xz"][1] + wr * nz_)
            truncated = lo == 0 or hi == len(offs) - 1
            rows.append({"chainage": s["chainage"], "carved_width_m": round(cw, 2), "mapped_width_m": s.get("width_m"),
                         "left_m": round(float(wl), 2), "right_m": round(float(wr), 2), "truncated": bool(truncated),
                         "effective_source": "carved"})
            if prev is not None:
                q = Polygon([prev[0], prev[1], Rr_, L]).buffer(0)
                if not q.is_empty:
                    quads.append(q)
            prev = (L, Rr_)
        eff = G.polygonal(shapely.union_all(quads)) if quads else Polygon()
        cws = [x["carved_width_m"] for x in rows if x.get("carved_width_m") is not None]
        mws = [x["mapped_width_m"] for x in rows if x.get("mapped_width_m") is not None]
        med = lambda v: float(sorted(v)[len(v) // 2]) if v else None
        cm, mm = med(cws), med(mws)
        flag = None
        if cm is not None and mm is not None:
            d = abs(cm - mm)
            flag = bool(d > dis["abs_m"] and d > dis["rel"] * max(mm, 1e-6))
        n_dis = sum(1 for x in rows if x.get("carved_width_m") is not None and x.get("mapped_width_m") is not None
                    and abs(x["carved_width_m"] - x["mapped_width_m"]) > max(dis["abs_m"], dis["rel"] * x["mapped_width_m"]))
        rec = {"reach": r["meta"]["stable_id"], "feature": r["feature"], "kind": r.get("kind"),
               "effective_wet": {"geometry": C.add(eff) if not eff.is_empty else None,
                                 "width_m_median": cm, "source": "carved channel cross-section of the heightfield (normal stage)",
                                 "stations_fallback_to_mapped": sum(1 for x in rows if x.get("effective_source", "").startswith("mapped")),
                                 "status": "proposed"},
               "mapped_width_m": {"median": mm, "status": "proposed", "role": "separate attribute (not used for planning)"},
               "width_disagreement": flag, "stations_disagreeing": n_dis, "stations": len(rows),
               "basis": "coordinator decision 2026-10-25 (WP4 open issue 1); no terrain re-bake",
               "upstream": r["upstream"], "downstream": r["downstream"]}
        out.append(rec)
        if not eff.is_empty:
            polys.append(eff)
    C.effective_wet = union(polys)
    setback = R.p("layout.water.bank_setback_m")
    wb = union([C.effective_wet, A.water_poly, A.drain_poly])
    C.water_block = G.polygonal(wb.buffer(setback).intersection(C.territory.buffer(400.0))) if not wb.is_empty else Polygon()
    return out


def bridge_cells(C, sub):
    """Straight bank-to-bank crossing candidates over effective channels inside the street domain."""
    R = C.R
    cfg = R.p("layout.water.new_bridge")
    g = sub.grid
    mask = np.zeros(g.shape, bool)
    mult = np.ones(g.shape)
    cands = []
    if C.effective_wet.is_empty:
        return {"mask": mask, "mult": mult}, cands
    dom = C.street_domain
    for ch in C.channels_rec:
        gid = ch["effective_wet"]["geometry"]
        if gid is None:
            continue
        reach = next((r for r in C.layer["water"]["reaches"] if r["meta"]["stable_id"] == ch["reach"]), None)
        st = reach["long_profile"]["stations"]
        xy = np.array([s["xz"] for s in st], float)
        for k in range(0, len(st), 1):
            x, z = st[k]["xz"]
            if not dom.buffer(5.0).contains(Point(x, z)):
                continue
            a = xy[max(0, k - 1)]
            b = xy[min(len(xy) - 1, k + 1)]
            tx, tz = b - a
            n = math.hypot(tx, tz) or 1.0
            nx_, nz_ = -tz / n, tx / n
            wet = C.effective_wet
            # walk outward until leaving the water block on both sides
            def edge(sign):
                for d in np.arange(0.5, 60.0, 0.5):
                    p = Point(x + sign * d * nx_, z + sign * d * nz_)
                    if not C.water_block.contains(p):
                        return d
                return None
            dl, dr = edge(-1), edge(1)
            if dl is None or dr is None:
                continue
            ab = cfg["abutment_m"]
            p0 = (x - (dl + ab) * nx_, z - (dl + ab) * nz_)
            p1 = (x + (dr + ab) * nx_, z + (dr + ab) * nz_)
            span = 0.0
            seg = LineString([p0, p1])
            iw = seg.intersection(wet)
            span = iw.length if not iw.is_empty else 0.0
            if span <= 0:
                continue
            typ = next((t for t, m in sorted(cfg["max_span_m"].items(), key=lambda kv: kv[1]) if span <= m), None)
            if typ is None:
                continue
            ok_ab = all(C.in_window(*p) and bool(C.sample(C.A.passable, [p[0]], [p[1]])[0]) for p in (p0, p1))
            if not ok_ab:
                continue
            cells = Rr.rasterize(g, seg.buffer(0.9))
            mask |= cells
            mult = np.where(cells, max(1.0, cfg["cost_m"] / max(seg.length, 1.0)), mult)
            cands.append({"reach": ch["reach"], "station": k, "line": seg, "span_m": round(span, 2), "structure": typ,
                          "angle_to_normal_deg": 0.0})
    return {"mask": mask, "mult": mult}, cands


def crossings(C, streets_fin, bridge_cands):
    """Typed crossings: mapped (WP4), Layer-2 culverts, new street crossings."""
    R = C.R
    out = []
    near = C.territory.buffer(300.0)
    for x in C.layer["water"]["crossings"]:
        if x.get("xz") and not near.contains(Point(x["xz"])):
            continue
        rec = {"id": x["meta"]["stable_id"], "origin": "mapped_wp4", "class": x["class"], "reach": x.get("reach"),
               "route": x.get("route"), "xz": x.get("xz"), "states": x.get("states"),
               "riffle_section": x.get("riffle_section"), "status": "proposed",
               "evidence": x.get("evidence"), "water_graph_link": "none (crossing structure; street and water graphs stay separate)"}
        out.append(rec)
    water = union([C.effective_wet, C.A.water_poly])
    from .water import crossing_states
    rules_c = R.p("water.crossing_rules")
    for l in streets_fin["_new"]:
        line = l["line"]
        if water.is_empty or not line.intersects(water):
            continue
        inter = line.intersection(water)
        for part in getattr(inter, "geoms", [inter]):
            if part.is_empty or part.length < 0.2:
                continue
            mid = part.interpolate(0.5, normalized=True)
            if l["hierarchy"] == "route":
                mp = [x for x in C.layer["water"]["crossings"] if x.get("xz") and Point(x["xz"]).distance(mid) <= 40.0]
                out.append({"id": C.claim("crossing_plan", key=None, xz=[G.r2(mid.x), G.r2(mid.y)], tol=5.0, content=[l["id"], "route"]),
                            "origin": "mapped_route", "class": mp[0]["class"] if mp else None, "street": l["id"],
                            "xz": [G.r2(mid.x), G.r2(mid.y)], "span_m": round(part.length, 2),
                            "structure_supported": bool(mp), "mapped_crossing": mp[0]["meta"]["stable_id"] if mp else None,
                            "status": "proposed", "water_graph_link": "none",
                            "note": "existing route over water: the mapped WP4 crossing carries it" if mp else
                                    "route meets water without a mapped crossing (L0: impassable)"})
                continue
            skew = None
            if l["hierarchy"] == "primary":
                # Layer 2 assumed a culvert from the mapped width; the carved (planning) span decides
                spans = R.p("layout.water.new_bridge")["max_span_m"]
                kind = "layer2_corridor_crossing"
                struct = next((t for t, m in sorted(spans.items(), key=lambda kv: kv[1]) if part.length <= m), None)
                cand = None
                ch = min(C.channels_rec, key=lambda c: 0 if c["effective_wet"]["geometry"] is None else
                         shape_of(C, c["effective_wet"]["geometry"]).distance(mid)) if C.channels_rec else None
                skew = _skew(C, line, mid, ch)
            else:
                cand = min(bridge_cands, key=lambda c: c["line"].distance(mid)) if bridge_cands else None
                if cand is not None and cand["line"].distance(mid) > 6.0:
                    cand = None
                kind = "new_street_crossing"
                struct = cand["structure"] if cand else ("culvert" if part.length <= R.p("layout.water.new_bridge")["max_span_m"]["culvert"] else None)
            sid = C.claim("crossing_plan", key=None, xz=[G.r2(mid.x), G.r2(mid.y)], tol=5.0, content=[l["id"], struct])
            rec = {"id": sid, "origin": kind, "class": struct, "street": l["id"], "xz": [G.r2(mid.x), G.r2(mid.y)],
                   "layer2_assumption": "culvert (mapped width below water_passage.sluice_min_width_m)" if l["hierarchy"] == "primary" else None,
                   "span_m": round(part.length, 2), "structure_supported": struct is not None,
                   "angle_to_normal_deg": cand["angle_to_normal_deg"] if cand else skew,
                   "skew_exceeds_preference": bool(skew is not None and skew > R.p("layout.water.new_bridge")["max_angle_deg"]),
                   "abutments": "dry, inside the street domain (checked at candidate generation)" if cand else None,
                   "reach": cand["reach"] if cand else None, "status": "proposed", "hypothesis": True,
                   "water_graph_link": "none"}
            if struct in ("slab_bridge", "timber_bridge"):
                rec["states"] = None
                rec["states_note"] = "deck height not designed (WP6/WP8); clearance per stage to be checked against the deck"
            if struct is None:
                if kind == "layer2_corridor_crossing":
                    C.request("L2/primary_corridors", "corridor crosses the carved channel skew / wider than any span variant: "
                              "re-route square to the channel or approve a bridge variant", "crossing_unsupported",
                              street=l["id"], xz=rec["xz"], span_m=rec["span_m"], angle_to_normal_deg=skew)
                else:
                    C.request("L4/water", "street crosses water without a supported crossing variant", "crossing_unsupported",
                              street=l["id"], xz=rec["xz"])
            out.append(rec)
    return out


def shape_of(C, gid):
    from shapely.geometry import shape
    return shape(C.store.items[gid])


def _skew(C, line, mid, ch):
    """Angle (deg) between the street and the channel normal at the crossing."""
    if ch is None:
        return None
    reach = next((r for r in C.layer["water"]["reaches"] if r["meta"]["stable_id"] == ch["reach"]), None)
    if reach is None:
        return None
    xy = [s_["xz"] for s_ in reach["long_profile"]["stations"]]
    if len(xy) < 2:
        return None
    cl = LineString(xy)
    s0 = cl.project(mid)
    a, b = cl.interpolate(max(0, s0 - 3)), cl.interpolate(min(cl.length, s0 + 3))
    s1 = line.project(mid)
    c, d = line.interpolate(max(0, s1 - 3)), line.interpolate(min(line.length, s1 + 3))
    ch_b = G.bearing_of(b.x - a.x, b.y - a.y)
    st_b = G.bearing_of(d.x - c.x, d.y - c.y)
    ang = G.angle_diff(st_b, ch_b, 180.0)       # 0 = parallel, 90 = square
    return round(90.0 - ang, 1)


def wall_passages(C):
    if not C.walled:
        return []
    out = []
    for o in C.fr["openings"]:
        if o["type"] == "water_passage":
            out.append({"opening": o.get("stable_id", o["id"]), "channel": o.get("channel"), "center": o["center"],
                        "subtype": o["subtype"], "width_m": o["width_m"]})
    return out


def drains(C, streets_fin):
    """Directed street drains with invert profiles and explicit outlets (no manufactured outlet)."""
    R, A = C.R, C.A
    minf = R.p("layout.drains.min_fall")
    search = R.p("layout.drains.outlet_search_m")
    win = A.win
    wmask = A.water | A.drain
    passages = wall_passages(C)
    ring = C.g(C.fr["wall"]["ring"]) if C.walled else None
    out = []
    node_y = {}
    links = streets_fin["_new"]
    # node heights
    for l in links:
        for nd in (l["_na"], l["_nb"]):
            if nd["id"] not in node_y:
                node_y[nd["id"]] = float(C.height([nd["xz"][0]], [nd["xz"][1]])[0])
    runs = []
    for l in links:
        if l["hierarchy"] == "route":
            continue  # existing route drainage is the WP4 Route support_drainage record
        line = l["line"]
        L = line.length
        if L < 2.0:
            continue
        n = max(2, int(L / 2.0))
        ss = np.linspace(0, L, n + 1)
        pts = [line.interpolate(s) for s in ss]
        ys = C.height([p.x for p in pts], [p.y for p in pts])
        k = 3
        ysm = np.convolve(np.pad(ys, k, mode="edge"), np.ones(2 * k + 1) / (2 * k + 1), mode="valid")
        sgn = np.sign(np.round(np.diff(ysm), 3))
        # split at sign changes (ignore zeros)
        cuts = [0]
        last = 0
        for i, s in enumerate(sgn):
            if s == 0:
                continue
            if last != 0 and s != last:
                cuts.append(i)
            last = s
        cuts.append(n)
        for a, b in zip(cuts, cuts[1:]):
            if b - a < 1:
                continue
            ya, yb = float(ys[a]), float(ys[b])
            hi, lo = (a, b) if ya >= yb else (b, a)
            fall = abs(ya - yb) / max(ss[b] - ss[a], 1e-6)
            seg = LineString([(pts[i].x, pts[i].y) for i in range(a, b + 1)])
            if hi > lo:
                seg = LineString(list(seg.coords)[::-1])
            runs.append({"link": l, "line": seg, "fall": fall, "y_hi": max(ya, yb), "y_lo": min(ya, yb),
                         "lo_pt": (pts[lo].x, pts[lo].y), "lo_is_node": lo in (0, n),
                         "lo_node": (l["_na"] if lo == 0 else l["_nb"]) if lo in (0, n) else None})
    by_node_down = {}
    for r in runs:
        # runs leaving a node downhill continue a drain that arrives there
        st = r["line"].coords[0]
        for nd in (r["link"]["_na"], r["link"]["_nb"]):
            if math.hypot(nd["xz"][0] - st[0], nd["xz"][1] - st[1]) < 0.6:
                by_node_down.setdefault(nd["id"], []).append(r)
    for i, r in enumerate(sorted(runs, key=lambda r: (r["link"]["id"], r["line"].coords[0]))):
        side_off = r["link"]["width_m"] / 2 - 0.3
        outlet = None
        if r["lo_is_node"] and r["lo_node"] is not None:
            nxt = [q for q in by_node_down.get(r["lo_node"]["id"], []) if q is not r]
            if nxt:
                outlet = {"kind": "downstream_drain", "to_link": nxt[0]["link"]["id"]}
        if outlet is None:
            outlet = _outlet_search(C, r["lo_pt"], wmask, ring, passages, search)
        flat = r["fall"] < minf
        did = C.claim("drain", key=None, xz=[G.r2(r["lo_pt"][0]), G.r2(r["lo_pt"][1])], tol=2.0,
                      content=[r["link"]["id"], G.to_geojson(r["line"])])
        rec = {"id": did, "street": r["link"]["id"], "geometry": C.add(r["line"]), "direction": "geometry order (high → low)",
               "side_offset_m": round(side_off, 2), "invert": {"depth_below_street_m": 0.3, "y_high": round(r["y_hi"] - 0.3, 3),
                                                            "y_low": round(r["y_lo"] - 0.3, 3), "status": "proposed"},
               "fall": round(r["fall"], 4), "min_fall_ok": not flat, "outlet": outlet, "status": "proposed",
               "hydraulic_sizing": None, "hydraulic_sizing_missing_reason": "deferred (L3-8 §2)"}
        if flat:
            rec["needs"] = "grading_contract_or_culvert"
        if outlet["kind"] == "wall_outlet_needed":
            C.request("WP6/수구", "drain reaches the town wall where no water passage exists", "wall_outlet_needed",
                      drain=did, xz=outlet["xz"])
        out.append(rec)
    _resolve_chains(out)
    for d in out:
        if d["outlet"]["kind"] == "none" or d["terminal"]["kind"] == "none":
            C.request("L4/drainage", "street drain does not reach an outlet (never manufactured)", "drain_no_outlet",
                      drain=d["id"], terminal=d["terminal"])
        elif d["terminal"]["kind"] == "wall_outlet_needed":
            pass
    return out


def _resolve_chains(drains):
    """Follow downstream drains to a terminal outlet (channel / drainage reserve / wall water
    passage / a 수구 position contracted to WP6); cycles and dead ends are 'none'."""
    by_street = {}
    for d in drains:
        by_street.setdefault(d["street"], []).append(d)
    term = ("channel_or_drainage_reserve", "wall_water_passage", "wall_outlet_needed", "open_land_runoff")
    for d in drains:
        seen = set()
        cur = d
        res = {"kind": "none", "via": []}
        for _ in range(200):
            k = cur["outlet"]["kind"]
            if k in term:
                res = {"kind": k, "via": sorted(seen - {d["id"]}), "at": cur["outlet"].get("xz")}
                break
            if k != "downstream_drain":
                break
            if cur["id"] in seen:
                res = {"kind": "none", "reason": "cycle", "via": sorted(seen)}
                break
            seen.add(cur["id"])
            nxt = by_street.get(cur["outlet"]["to_link"], [])
            nxt = [x for x in nxt if x["id"] not in seen]
            if not nxt:
                res = {"kind": "none", "reason": "downstream street has no further drain", "via": sorted(seen)}
                break
            cur = nxt[0]
        d["terminal"] = res


def _outlet_search(C, pt, wmask, ring, passages, search):
    A = C.A
    win = A.win
    i, j = win.ij(*pt)
    if not win.inside(i, j):
        return {"kind": "none", "reason": "outside the analysis window"}
    path = [(i, j)]
    seen = {(i, j)}
    L = 0.0
    while L <= search:
        ci, cj = path[-1]
        x, z = win.xz(ci, cj)
        if C.domain_total is not None and L > 0 and not C.domain_total.contains(Point(x, z)) and not A.protected[cj, ci]:
            # left the settlement onto open, unprotected land: surface runoff (no structure manufactured)
            ln = LineString([win.xz(a, b) for a, b in path]) if len(path) > 1 else None
            return {"kind": "open_land_runoff", "path": C.add(ln) if ln is not None else None, "length_m": round(L, 1),
                    "xz": [G.r2(x), G.r2(z)], "status": "proposed", "hypothesis": True,
                    "note": "drain discharges onto unbuilt, unprotected land outside the settlement along the natural fall line"}
        if wmask[cj, ci]:
            ln = LineString([win.xz(a, b) for a, b in path]) if len(path) > 1 else None
            return {"kind": "channel_or_drainage_reserve", "path": C.add(ln) if ln is not None else None,
                    "length_m": round(L, 1), "xz": [G.r2(x), G.r2(z)],
                    "crosses_parcels": "resolved in Layer 5 (drain easement on each crossed parcel)"}
        if ring is not None and ring.distance(Point(x, z)) < 3.0:
            for p in passages:
                if math.hypot(p["center"][0] - x, p["center"][1] - z) <= 15.0:
                    return {"kind": "wall_water_passage", "opening": p["opening"], "xz": [G.r2(x), G.r2(z)],
                            "length_m": round(L, 1)}
            return {"kind": "wall_outlet_needed", "xz": [G.r2(x), G.r2(z)], "length_m": round(L, 1),
                    "note": "a 수구 is required here (WP6); no opening is created by WP5"}
        best = None
        for di in (-1, 0, 1):
            for dj in (-1, 0, 1):
                if di == dj == 0:
                    continue
                a, b = ci + di, cj + dj
                if not win.inside(a, b) or (a, b) in seen:
                    continue
                dh = A.h[cj, ci] - A.h[b, a]
                if dh <= 0 and not wmask[b, a]:
                    continue
                gr = dh / (win.cell * math.hypot(di, dj))
                if best is None or gr > best[0]:
                    best = (gr, a, b, math.hypot(di, dj))
        if best is None:
            return {"kind": "none", "reason": "local low point (pit) — needs grading or soakaway decision",
                    "xz": [G.r2(x), G.r2(z)], "length_m": round(L, 1)}
        path.append((best[1], best[2]))
        seen.add((best[1], best[2]))
        L += best[3] * win.cell
    return {"kind": "none", "reason": f"no channel within {search} m of descending path", "length_m": round(L, 1)}


def laundry(C, net):
    """빨래터 access reservation on a freshwater bank (stage-dependent use)."""
    if C.effective_wet.is_empty:
        return []
    A, R = C.A, C.R
    best = None
    lines = net.lines()
    if not lines:
        return []
    netu = union(lines)
    for ch in C.channels_rec:
        if ch["kind"] not in ("river", "stream") or ch["effective_wet"]["geometry"] is None:
            continue
        reach = next((r for r in C.layer["water"]["reaches"] if r["meta"]["stable_id"] == ch["reach"]), None)
        for s in reach["long_profile"]["stations"][::2]:
            p = Point(s["xz"])
            d = p.distance(netu)
            if d > 150.0:
                continue
            # bank point on the effective wet edge nearest the network
            edge = C.effective_wet.boundary
            q = edge.interpolate(edge.project(p))
            if not C.in_window(q.x, q.y):
                continue
            sl = float(C.sample(A.slope, [q.x], [q.y])[0])
            if sl > R.p("slope.housing_max_deg"):
                continue
            if any(l["geom"].distance(q) < 6.0 for l in C.inp.locks) or A.protected_poly.contains(q):
                continue
            dn = q.distance(netu)
            key = (round(dn, 1), s["chainage"], ch["reach"])
            if best is None or key < best[0]:
                best = (key, q, s, ch, reach)
    if best is None:
        return []
    _, q, s, ch, reach = best
    sy = s["surface_y"]
    by = float(C.height([q.x], [q.y])[0])
    free = by - sy if sy is not None else None
    states = []
    for stt in reach["states"]:
        off = stt["offset_world_m"]
        usable = free is not None and off <= free - 0.1 and off >= -1.0
        states.append({"key": stt["key"], "usable": bool(usable),
                       "reason": (f"bank +{free:.2f} m vs level {off:+.2f}" if free is not None else "surface unknown")})
    site = Point(q.x, q.y).buffer(3.0, 8)
    sid = C.claim("activity", key=f"laundry:{ch['reach']}", content=[G.r2(q.x), G.r2(q.y)])
    return [{"id": sid, "activity": "laundry", "users": ["households"], "reach": ch["reach"],
             "xz": [G.r2(q.x), G.r2(q.y)], "spaces": {"work": C.add(site)}, "bank_above_normal_m": round(free, 2) if free is not None else None,
             "network_distance_m": round(q.distance(netu), 1), "state": "normal", "states": states,
             "status": "proposed", "hypothesis": True,
             "basis": "BLD-10/C13: shared facility placed from users + path + water level; work-stone height unknown (V29 data only)",
             "_pt": q}]
