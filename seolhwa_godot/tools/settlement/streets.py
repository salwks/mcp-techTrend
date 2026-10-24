"""Layer 4 — street network (L3-8 3회차 §2, audit K5, VIL-01, BLD-02).

Typed hierarchy (primary = Layer-2 corridors, secondary, lane, cul-de-sac, village 고샅) with
per-mode passability (도보/짐말/수레 test values from the movement layer). New streets are routed
on the analysis grid with c_e = l(1+8g²)(1+2R) (+ typed crossing costs) from the existing network
toward uncovered residential demand, so every branch ends on an existing street as a T junction
(no new crossing of a street). Villages first connect household clusters, entrances and water by
a minimum spanning tree and add loops only when the detour exceeds 1.8 and ≥8 households are
served; loops never justify a bridge.

Every bend carries a geometry reason (planned_axis, contour_follow, water_setback,
obstacle_avoidance, existing_route, junction_approach); a bend with no reason is straightened —
there are no random waves. Plazas come only from programs (forecourts, market, well).
"""
from __future__ import annotations

import math

import numpy as np
import shapely
from scipy import ndimage
from shapely.geometry import LineString, MultiLineString, Point, Polygon
from shapely.ops import nearest_points, substring

from . import geometry as G
from . import raster as Rr
from . import routing as Rt
from .layout_ctx import union


HRANK = {"primary": 0, "route": 1, "secondary": 2, "lane": 3, "gosat": 4, "cul_de_sac": 5}


class Net:
    """Street links with explicit nodes."""

    def __init__(self, C):
        self.C = C
        self.links = []   # dict: id, line, hierarchy, width, reason, bends, generation, parent, ...
        self.nseq = 0

    def add(self, line, hierarchy, width, **kw):
        self.nseq += 1
        rec = {"_id": self.nseq, "line": line, "hierarchy": hierarchy, "width_m": round(width, 3)}
        rec.update(kw)
        self.links.append(rec)
        return rec

    def lines(self):
        return [l["line"] for l in self.links]

    def split_at(self, pt, tol=0.10):
        """Split the link nearest to pt at its projection; returns the snapped node point."""
        best = None
        for l in self.links:
            d = l["line"].distance(pt)
            if best is None or d < best[0] - 1e-9:
                best = (d, l)
        if best is None:
            return pt
        l = best[1]
        s = l["line"].project(pt)
        q = l["line"].interpolate(s)
        q = Point(G.r2(q.x), G.r2(q.y))
        L = l["line"].length
        if s <= tol or s >= L - tol:
            e = l["line"].coords[0] if s <= tol else l["line"].coords[-1]
            return Point(e)
        a = LineString(list(substring(l["line"], 0, s).coords[:-1]) + [(q.x, q.y)])
        b = LineString([(q.x, q.y)] + list(substring(l["line"], s, L).coords[1:]))
        self.links.remove(l)
        for part, tag in ((a, "a"), (b, "b")):
            r = dict(l)
            r["line"] = part
            r["split_from"] = l.get("split_from", l["_id"])
            self.nseq += 1
            r["_id"] = self.nseq
            self.links.append(r)
        return q


def _sub(C, poly, margin=40.0):
    from .frame import Sub
    return Sub(C.A, poly.bounds, margin)


def width_world(C, hierarchy):
    hr = C.R.p("layout.streets.hierarchy")[hierarchy]
    return C.wl(hr["width_hist_default_m"])


def passable_mask(C, sub, domain, hierarchy, extra_block=None):
    A, R = C.A, C.R
    g = sub.grid
    w = width_world(C, hierarchy)
    inner = domain.buffer(-w / 2) if C.walled else domain
    m = Rr.rasterize(g, inner) & sub.a(A.cov)
    fr = C.fr
    block = [C.g(c["envelope"]) for c in fr["civic_reserves"]]
    block += [C.g(x["reservation"]) for x in fr.get("water_access", [])]
    block += [l["geom"] for l in C.inp.locks]
    block += [A.protected_poly, A.neigh_poly]
    if extra_block is not None:
        block.append(extra_block)
    bu = union([b.buffer(w / 2) for b in block if b is not None and not b.is_empty])
    m &= ~Rr.rasterize(g, bu)
    wet = Rr.rasterize(g, C.water_block) if not C.water_block.is_empty else np.zeros(g.shape, bool)
    m &= ~wet
    return m


def build(C, demand_polys, pre_links=()):
    """Route secondaries / lanes / 고샅 for the residential demand; returns the Net and records."""
    A, R = C.A, C.R
    fr = C.fr
    net = Net(C)
    pc = fr.get("primary_corridors") or {}
    for l in pc.get("links", []):
        net.add(C.g(l["centerline"]), "primary", l["width_m"], source=l["id"], stable_ref=l.get("stable_id"),
                generation=0, reason_inherited=True, role=l.get("role"))
    for pl in pre_links:
        net.add(pl["line"], pl["hierarchy"], pl["width_m"], **{k: v for k, v in pl.items() if k not in ("line", "hierarchy", "width_m")})
    domain = C.street_domain
    sub = _sub(C, domain.union(union(demand_polys)) if demand_polys else domain)
    g = sub.grid
    h = sub.a(A.h)
    cm = 1.0 + R.p("layout.streets.flood_cost_k") * np.clip(sub.a(A.R), 0, 1)
    # typed bridge candidates (straight bank-to-bank) are passable at a crossing cost
    bridge_cells, bridge_cands = C.bridge_cells(sub)
    obligations = []
    reach = R.p("layout.streets.reach_m")["urban" if C.urban else "village"]
    demand = Rr.rasterize(g, union(demand_polys)) if demand_polys else np.zeros(g.shape, bool)
    min_cells = R.p("layout.streets.min_demand_m2") / (g.cell ** 2)
    hier_new = "secondary" if C.urban else "gosat"
    caps = {"secondary": R.p("movement.mode_limits")["pack_horse"], "lane": R.p("movement.mode_limits")["foot"],
            "gosat": R.p("movement.mode_limits")["foot"]}
    graphs = {}

    def graph(hier, allow_bridge=True):
        key = (hier, allow_bridge)
        if key not in graphs:
            pas = passable_mask(C, sub, domain, hier)
            mult = cm.copy()
            if allow_bridge and bridge_cells is not None:
                pas = pas | bridge_cells["mask"]
                mult = np.where(bridge_cells["mask"], bridge_cells["mult"], mult)
            graphs[key] = (Rt.build_graph(g, h, pas, radius=2, grade_k=R.p("routing.grade_cost_k"),
                                          grade_cap=caps[hier], cost_mult=mult), pas)
        return graphs[key]

    def net_mask():
        ls = net.lines()
        if not ls:
            return np.zeros(g.shape, bool)
        return Rr.rasterize(g, union([l.buffer(1.6) for l in ls]))

    added = []

    def add_path(cells, hier, purpose, gen, serves=None, allow_tee=True):
        pts = Rt.cells_to_xz(g, cells)
        if len(pts) < 2:
            return None
        start = Point(pts[0])
        on = min(net.lines(), key=lambda l: l.distance(start)) if net.lines() else None
        if on is not None and on.distance(start) <= 2.5:
            q = net.split_at(nearest_points(on, start)[0])
            pts = [(q.x, q.y)] + pts[1:]
        endp = Point(pts[-1])
        others = [l for l in net.lines() if l.distance(Point(pts[0])) > 0.5]
        if others:
            o = min(others, key=lambda l: l.distance(endp))
            if 0.0 < o.distance(endp) <= 2.5:
                q2 = net.split_at(nearest_points(o, endp)[0])
                pts = pts + [(q2.x, q2.y)]
        line = LineString(pts).simplify(R.p("layout.streets.simplify_m"))
        if line.length < 4.0:
            return None
        line, bends = explain_bends(C, sub, line, graph(hier)[1], hier)
        w = width_world(C, hier)
        rec = net.add(line, hier, w, purpose=purpose, generation=gen, bends=bends, serves=serves or [])
        added.append(rec)
        return rec

    # ---------------- obligations: water access (well) must touch the network
    for wsup in fr.get("water_access", []):
        wp = C.g(wsup["reservation"])
        d = min((l["line"].distance(wp) - l["width_m"] / 2 for l in net.links), default=1e9)
        ob = {"kind": "water_access", "target": wsup.get("stable_id", wsup["id"]), "distance_m": round(d, 2)}
        if d > 0.5:
            gr, pas = graph("lane")
            src = np.flatnonzero(net_mask() & pas)
            tgt = Rr.rasterize(g, wp.buffer(3.0)) & pas
            if src.size and tgt.any():
                dist, pred = Rt.dijkstra(gr, src)
                tc = np.flatnonzero(tgt)
                tc = tc[np.isfinite(dist[tc])]
                if tc.size:
                    t = int(tc[np.argmin(dist[tc])])
                    r = add_path(Rt.path_cells(pred, t), "lane", "water_access", 1)
                    ob["added"] = bool(r)
                    if r is not None:
                        # finish the lane on the well's edge (over the bank margin, which streets may cross)
                        end = Point(r["line"].coords[-1])
                        q = nearest_points(wp.boundary, end)[0]
                        if end.distance(q) > 0.05 and not C.water_block.difference(C.water_block.buffer(-R.p("layout.water.bank_setback_m"))).is_empty:
                            r["line"] = LineString(list(r["line"].coords) + [(G.r2(q.x), G.r2(q.y))])
                        ob["joined_well_edge"] = True
            if not ob.get("added"):
                C.request("L2/water_access", "shared water access cannot be reached by a street (bank setback / grade); "
                          "move the reservation or approve a bank path", "water_access_unreachable",
                          water_access=ob["target"], distance_m=ob["distance_m"])
        obligations.append(ob)
    # ---------------- villages: MST over clusters + entrances + water, then loops
    if not C.urban:
        village_tree(C, sub, net, demand_polys, graph, add_path, obligations)
    # ---------------- coverage: branches toward uncovered residential demand (T junctions)
    maxn = R.p("layout.streets.max_new")
    for it in range(maxn):
        nm = net_mask()
        if not nm.any():
            break
        # coverage by walking cost on the street graph (a cluster across water or a cliff is not
        # "near" a street just because it is close in plan)
        grc, pasc = graph("lane" if C.urban else "gosat")
        srcc = np.flatnonzero(nm & pasc)
        if srcc.size:
            dcov, _ = Rt.dijkstra(grc, srcc, limit=reach * 4)
            dist_e = dcov.reshape(g.shape)
        else:
            dist_e = ndimage.distance_transform_edt(~nm) * g.cell
        dist_e = np.where(np.isfinite(dist_e), dist_e, 1e6)
        unc = demand & (dist_e > reach)
        if not unc.any():
            break
        L, n = ndimage.label(unc, structure=np.ones((3, 3), bool))
        sizes = np.bincount(L.ravel())[1:]
        order = sorted(range(1, n + 1), key=lambda k: (-sizes[k - 1], k))
        done = False
        for k in order:
            if sizes[k - 1] < min_cells:
                break
            cm_ = L == k
            gen = 1 if C.urban else 2
            for hier in ([hier_new, "lane"] if C.urban else ["gosat"]):
                gr, pas = graph(hier)
                src = np.flatnonzero(nm & pas)
                if not src.size:
                    continue
                dist, pred = Rt.dijkstra(gr, src)
                dd = dist.reshape(g.shape)
                cand = cm_ & np.isfinite(dd)
                if not cand.any():
                    continue
                # deepest reachable uncovered cell (farthest from the street network)
                score = np.where(cand, dist_e, -1)
                t = int(np.argmax(score))
                cells = Rt.path_cells(pred, t)
                plen = len(cells) * g.cell
                h_use = hier
                if C.urban and hier == "secondary" and plen < 0.5 * R.p("layout.streets.hierarchy")["secondary"]["spacing_hist_m"][0] * C.factor:
                    h_use = "lane"
                r = add_path(cells, h_use, "residential_access", gen)
                if r is not None:
                    done = True
                    break
            if done:
                break
            # unreachable demand → report once and stop trying this patch
            demand &= ~cm_
            ys, xs = np.nonzero(cm_)
            x, z = g.xz(int(xs.mean()), int(ys.mean()))
            C.request("L4/streets", "residential land cannot be reached by a street within grade/water limits",
                      "unreachable_demand", xz=[G.r2(x), G.r2(z)], area_m2=round(float(sizes[k - 1] * g.cell ** 2), 1))
        if not done and not unc.any():
            break
        if not done:
            # nothing routable among remaining patches
            break
    C.street_sub = sub
    C.graph_fn = graph
    C.add_path = add_path
    C.net_mask = net_mask
    return net, {"obligations": obligations, "bridge_candidates": bridge_cands}


def village_tree(C, sub, net, demand_polys, graph, add_path, obligations):
    """MST over cluster centres, entrances and water; loops only for detour > 1.8 and ≥8 households."""
    R = C.R
    g = sub.grid
    term = []
    for d in C.districts_rec:
        if d.get("households", 0) <= 0:
            continue
        x, z = d["xz"]
        term.append({"id": d["id"], "xz": (x, z), "households": d["households"]})
    for hm in getattr(C, "hamlets", []):
        x, z = hm["anchor"]
        term.append({"id": hm["id"], "xz": (x, z), "households": len(hm["households"])})
    if len(term) < 1:
        return
    gr, pas = graph("gosat", allow_bridge=False)
    cells = []
    for t in term:
        c = _nearest(pas, g, t["xz"])
        cells.append(c)
    nm = C.net_mask() if hasattr(C, "net_mask") else None
    lines = net.lines()
    netm = Rr.rasterize(g, union([l.buffer(1.6) for l in lines])) if lines else np.zeros(g.shape, bool)
    src = np.flatnonzero(netm & pas)
    dnet, pnet = Rt.dijkstra(gr, src) if src.size else (np.full(g.nx * g.nz, np.inf), None)
    n = len(term)
    D, P = [], []
    for c in cells:
        if c is None:
            D.append(np.full(g.nx * g.nz, np.inf))
            P.append(None)
            continue
        d, p = Rt.dijkstra(gr, [c])
        D.append(d)
        P.append(p)
    # Prim with the network as node 0
    INF = float("inf")
    in_tree = {"net"}
    edges = []
    rem = set(range(n))
    while rem:
        best = None
        for i in sorted(rem):
            if cells[i] is None:
                continue
            c_net = float(dnet[cells[i]])
            if math.isfinite(c_net) and (best is None or c_net < best[0]):
                best = (c_net, i, "net")
            for j in sorted(x for x in in_tree if x != "net"):
                cij = float(D[j][cells[i]])
                if math.isfinite(cij) and (best is None or cij < best[0] - 1e-9):
                    best = (cij, i, j)
        if best is None:
            for i in sorted(rem):
                C.request("L4/streets", "village cluster unreachable without crossing water or grade limits",
                          "cluster_unreachable", cluster=term[i]["id"])
            break
        _, i, j = best
        rem.discard(i)
        in_tree.add(i)
        edges.append((i, j))
    for i, j in edges:
        if j == "net":
            path = Rt.path_cells(pnet, cells[i])
        else:
            path = Rt.path_cells(P[j], cells[i])
            path = path  # from j to i
            # start must lie on the network → route from j's end, which is already connected
        rec = add_path(path, "gosat", "cluster_link", 1, serves=[term[i]["id"]] + ([term[j]["id"]] if j != "net" else []))
        obligations.append({"kind": "cluster_access", "target": term[i]["id"], "via": "network" if j == "net" else term[j]["id"],
                            "added": bool(rec)})
    # loops
    lp = R.p("layout.streets.village_loop")
    lines = net.lines()
    for a in range(n):
        for b in range(a + 1, n):
            if cells[a] is None or cells[b] is None:
                continue
            hh = term[a]["households"] + term[b]["households"]
            direct = float(D[a][cells[b]])
            if not math.isfinite(direct) or hh < lp["min_households"]:
                continue
            # network detour estimate: via the tree = |a→net| + |b→net| (upper bound)
            via = float(dnet[cells[a]] + dnet[cells[b]]) if src.size else math.inf
            if via / max(direct, 1e-6) > lp["detour"] and direct > 30.0:
                path = Rt.path_cells(P[a], cells[b])
                pl = LineString(Rt.cells_to_xz(g, path)) if len(path) > 1 else None
                if pl is not None and pl.length > 8.0:
                    core = substring(pl, 4.0, pl.length - 4.0)
                    if any(core.intersects(l) for l in net.lines()):
                        # a loop that would cut across an existing street: the T connection already
                        # there is within layout.streets.tee_tolerance → no new four-way crossing
                        obligations.append({"kind": "village_loop", "between": [term[a]["id"], term[b]["id"]], "added": False,
                                            "reason": f"would cross an existing street (T preferred, tolerance {R.p('layout.streets.tee_tolerance')})"})
                        continue
                rec = add_path(path, "gosat", "village_loop", 2,
                               serves=[term[a]["id"], term[b]["id"]])
                obligations.append({"kind": "village_loop", "between": [term[a]["id"], term[b]["id"]],
                                    "detour": round(via / max(direct, 1e-6), 2), "households": hh, "added": bool(rec),
                                    "bridge": False})


def _nearest(mask, grid, xz, max_m=40.0):
    from .frame import nearest_true
    return nearest_true(mask, grid, xz[0], xz[1], max_m)


def explain_bends(C, sub, line, pas, hier):
    """Straighten bends without a reason; tag the rest (VIL-03, V43)."""
    R = C.R
    g = sub.grid
    h = sub.a(C.A.h)
    thr = R.p("layout.streets.bend_deg")
    cap = {"secondary": R.p("movement.mode_limits")["pack_horse"]}.get(hier, R.p("movement.mode_limits")["foot"])
    pts = list(line.coords)

    def feasible(a, b):
        seg = LineString([a, b])
        n = max(2, int(seg.length / (g.cell * 0.5)))
        ok = True
        for k in range(n + 1):
            p = seg.interpolate(k / n, normalized=True)
            i, j = g.ij(p.x, p.y)
            if not g.inside(i, j) or not pas[j, i]:
                ok = False
                break
        if not ok:
            return False, "blocked"
        _, _, gm = Rt.grade_profile(g, h, [a, b])
        return (gm <= cap + 1e-6), ("grade" if gm > cap + 1e-6 else "ok")

    changed = True
    guard = 0
    while changed and guard < 200:
        changed = False
        guard += 1
        for i in range(1, len(pts) - 1):
            t = _turn(pts[i - 1], pts[i], pts[i + 1])
            if t <= thr:
                continue
            ok, why = feasible(pts[i - 1], pts[i + 1])
            if ok:
                # chord feasible: the bend has no terrain/water/obstacle reason → straighten
                pts.pop(i)
                changed = True
                break
    # tag remaining bends
    bends = []
    water = C.water_block
    obst = C.obstacles
    road_lines = union([r.line for r in C.inp.roads]) if C.inp.roads else None
    L = LineString(pts)
    for i in range(1, len(pts) - 1):
        t = _turn(pts[i - 1], pts[i], pts[i + 1])
        if t <= thr:
            continue
        chord = LineString([pts[i - 1], pts[i + 1]])
        s = L.project(Point(pts[i]))
        if s < 6.0 or L.length - s < 6.0:
            why = "junction_approach"
        elif water is not None and not water.is_empty and chord.distance(water) < 3.0:
            why = "water_setback"
        elif obst is not None and not obst.is_empty and chord.intersects(obst):
            why = "obstacle_avoidance"
        elif road_lines is not None and Point(pts[i]).distance(road_lines) < 4.0:
            why = "existing_route"
        else:
            ok, w = feasible(pts[i - 1], pts[i + 1])
            why = "contour_follow" if w == "grade" else ("obstacle_avoidance" if w == "blocked" else "contour_follow")
        bends.append({"xz": [G.r2(pts[i][0]), G.r2(pts[i][1])], "turn_deg": round(t, 1), "reason": why})
    return LineString(pts), bends


def _turn(a, b, c):
    u = (b[0] - a[0], b[1] - a[1])
    v = (c[0] - b[0], c[1] - b[1])
    nu, nv = math.hypot(*u), math.hypot(*v)
    if nu < 1e-9 or nv < 1e-9:
        return 0.0
    cs = max(-1.0, min(1.0, (u[0] * v[0] + u[1] * v[1]) / (nu * nv)))
    return math.degrees(math.acos(cs))


def classify_inherited(C, net):
    """Tag the bends of Layer-2 primary corridors (kept as approved; never straightened)."""
    out = []
    for l in net.links:
        if l["hierarchy"] != "primary":
            continue
        pts = list(l["line"].coords)
        bends = []
        for i in range(1, len(pts) - 1):
            t = _turn(pts[i - 1], pts[i], pts[i + 1])
            if t <= C.R.p("layout.streets.bend_deg"):
                continue
            chord = LineString([pts[i - 1], pts[i + 1]])
            if C.obstacles is not None and chord.intersects(C.obstacles):
                why = "obstacle_avoidance"
            elif C.water_block is not None and chord.distance(C.water_block) < 3.0:
                why = "water_setback"
            else:
                why = "planned_axis_grid_path"
            bends.append({"xz": [G.r2(pts[i][0]), G.r2(pts[i][1])], "turn_deg": round(t, 1), "reason": why})
        l["bends"] = bends
    return out


def finalize(C, net):
    """Nodes, link records, per-mode passability, grade, planarity; corridor polygons."""
    R, A = C.R, C.A
    tol = R.p("geometry.endpoint_match")
    # node every genuine same-level intersection (bridges are separate structures)
    joined = []
    # close near misses: a dead end within 2.5 m (4 m to a mapped route / Layer-2 corridor end) of
    # another street is joined to it as a T (no accidental gaps or near-miss crossings)
    for _ in range(2):
        for l in sorted(net.links, key=lambda x: x["_id"]):
            for end in (0, -1):
                pe = Point(l["line"].coords[end])
                others = [o for o in net.links if o is not l]
                if not others or any(o["line"].distance(pe) <= tol for o in others):
                    continue
                o = min(others, key=lambda o: (o["line"].distance(pe), o["_id"]))
                d = o["line"].distance(pe)
                lim = 6.0 if (o["hierarchy"] in ("route", "primary") or l["hierarchy"] in ("route", "primary")) else 2.5
                if d <= lim:
                    q = nearest_points(o["line"], pe)[0]
                    cs = list(l["line"].coords)
                    cs = [(G.r2(q.x), G.r2(q.y))] + cs if end == 0 else cs + [(G.r2(q.x), G.r2(q.y))]
                    l["line"] = LineString(cs)
                    joined.append({"link": l["_id"], "to": o["_id"], "gap_m": round(d, 2)})
    # join street components that run within 6 m of each other (a short connector, T at both ends)
    for _ in range(4):
        n_ = len(net.links)
        par = list(range(n_))

        def fd(i):
            while par[i] != i:
                par[i] = par[par[i]]
                i = par[i]
            return i
        for i in range(n_):
            for j in range(i + 1, n_):
                if net.links[i]["line"].distance(net.links[j]["line"]) <= tol:
                    par[fd(i)] = fd(j)
        comps = {}
        for i in range(n_):
            comps.setdefault(fd(i), []).append(i)
        if len(comps) <= 1:
            break
        keys = sorted(comps, key=lambda k: min(comps[k]))
        best = None
        for a_ in range(len(keys)):
            ua = union([net.links[i]["line"] for i in comps[keys[a_]]])
            for b_ in range(a_ + 1, len(keys)):
                ub = union([net.links[i]["line"] for i in comps[keys[b_]]])
                d = ua.distance(ub)
                if d <= 6.0 and (best is None or d < best[0]):
                    best = (d, ua, ub)
        if best is None:
            break
        pa, pb = nearest_points(best[1], best[2])
        con = LineString([(G.r2(pa.x), G.r2(pa.y)), (G.r2(pb.x), G.r2(pb.y))])
        if con.length > 0.05:
            net.add(con, "gosat", width_world(C, "gosat"), purpose="component_connector", generation=3, bends=[], serves=[])
            joined.append({"connector_m": round(con.length, 2)})
    lines = net.lines()
    noded = shapely.union_all(lines, grid_size=G.GRID) if lines else MultiLineString()
    pieces = [p for p in getattr(noded, "geoms", [noded]) if p.geom_type == "LineString" and p.length > 0.05]
    # trim overshoot stubs created by noding (a dead-end piece < 2.5 m hanging off a junction)
    for _ in range(2):
        deg = {}
        for p in pieces:
            for c in (p.coords[0], p.coords[-1]):
                k = (round(c[0], 2), round(c[1], 2))
                deg[k] = deg.get(k, 0) + 1
        keep = []
        for p in pieces:
            a = deg[(round(p.coords[0][0], 2), round(p.coords[0][1], 2))]
            b = deg[(round(p.coords[-1][0], 2), round(p.coords[-1][1], 2))]
            if p.length < 2.5 and min(a, b) == 1 and max(a, b) >= 3:
                joined.append({"trimmed_stub_m": round(p.length, 2)})
                continue
            keep.append(p)
        pieces = keep
    # rebuild links from noded pieces, keeping attributes from the original link
    new = []
    for p in pieces:
        mid = p.interpolate(0.5, normalized=True)
        src = min(net.links, key=lambda l: (round(l["line"].distance(mid), 3), HRANK.get(l["hierarchy"], 9), l["_id"]))
        r = dict(src)
        r["line"] = LineString([(G.r2(x), G.r2(z)) for x, z in p.coords])
        new.append(r)
    nodes = {}

    def node_of(pt):
        key = (round(pt[0] / tol), round(pt[1] / tol))
        for k in ((key[0] + dx, key[1] + dz) for dx in (-1, 0, 1) for dz in (-1, 0, 1)):
            if k in nodes:
                return nodes[k]
        nodes[key] = {"xz": [G.r2(pt[0]), G.r2(pt[1])], "links": []}
        return nodes[key]
    for r in new:
        a = node_of(r["line"].coords[0])
        b = node_of(r["line"].coords[-1])
        r["_na"], r["_nb"] = a, b
        a["links"].append(r)
        b["links"].append(r)
    # node kinds
    gates = {tuple(o["center"]): o for o in C.fr.get("openings", []) if o["type"] == "gate"}
    civic = {tuple(n["xz"]): n for n in (C.fr.get("primary_corridors") or {}).get("nodes", [])}
    node_recs = []
    for k in sorted(nodes, key=lambda k: (nodes[k]["xz"][1], nodes[k]["xz"][0])):
        n = nodes[k]
        deg = len(n["links"])
        x, z = n["xz"]
        l2 = next((v for kk, v in civic.items() if math.hypot(kk[0] - x, kk[1] - z) <= 0.5), None)
        kind = l2["kind"] if l2 else ("junction" if deg >= 3 else ("end" if deg == 1 else "bend"))
        if deg >= 3:
            kind = "junction" if not l2 else l2["kind"]
        n["kind"] = kind
        n["degree"] = deg
        n["id"] = C.claim("street_node", key=(l2 or {}).get("id"), xz=[x, z], tol=1.0, content=n["xz"])
        n["l2"] = (l2 or {}).get("id")
        tee = None
        if deg == 3:
            tee = _is_tee(n)
        node_recs.append({"id": n["id"], "xz": n["xz"], "kind": kind, "degree": deg, "layer2_node": n["l2"],
                          "junction_form": tee, "level": 0})
    links = []
    for r in sorted(new, key=lambda r: (r["hierarchy"] != "primary", r["_na"]["id"], r["_nb"]["id"], r["line"].length)):
        line = r["line"]
        sid = C.claim("street", key=f"{min(r['_na']['id'], r['_nb']['id'])}|{max(r['_na']['id'], r['_nb']['id'])}|{r['hierarchy']}",
                      content=G.to_geojson(line))
        r["id"] = sid
        modes, grade = mode_record(C, line, r["width_m"], r["hierarchy"])
        reason = _link_reason(r)
        rec = {"id": sid, "nodes": [r["_na"]["id"], r["_nb"]["id"]], "centerline": C.add(line), "hierarchy": r["hierarchy"],
               "width_m": r["width_m"], "length_m": round(line.length, 2), "reason": reason, "bends": r.get("bends", []),
               "modes": modes, "grade": grade, "purpose": r.get("purpose", "civic_access" if r["hierarchy"] == "primary" else None),
               "generation": r.get("generation", 0), "layer2_link": r.get("source"),
               "serves": r.get("serves", []), "status": "proposed",
               "width_basis": ("Layer-2 approved corridor" if r["hierarchy"] == "primary" else "mapped route width (data)" if r["hierarchy"] == "route" else
                               f"layout.streets.hierarchy.{r['hierarchy']} (historical m × factor once)")}
        links.append(rec)
        r["rec"] = rec
    # planarity: links meet only at nodes
    near = []
    allp = [r["line"] for r in new]
    for i, a in enumerate(allp):
        for j in range(i + 1, len(allp)):
            b = allp[j]
            if not a.intersects(b):
                continue
            x = a.intersection(b)
            for p in getattr(x, "geoms", [x]):
                if p.geom_type != "Point":
                    near.append({"links": [new[i]["id"], new[j]["id"]], "kind": "overlap"})
                    continue
                ends = [Point(c) for c in (a.coords[0], a.coords[-1], b.coords[0], b.coords[-1])]
                if min(p.distance(e) for e in ends) > tol * 2:
                    near.append({"links": [new[i]["id"], new[j]["id"]], "kind": "crossing_without_node",
                                 "xz": [G.r2(p.x), G.r2(p.y)]})
    # near misses: a dead end within 2 m of another link without a node
    for r in new:
        for end, nd in ((r["line"].coords[0], r["_na"]), (r["line"].coords[-1], r["_nb"])):
            if nd["degree"] != 1:
                continue
            pe = Point(end)
            for o in new:
                if o is r:
                    continue
                d = o["line"].distance(pe)
                if tol < d < 2.0:
                    near.append({"links": [r["id"], o["id"]], "kind": "near_miss", "distance_m": round(d, 3)})
    # corridor polygons
    polys = []
    for r in new:
        polys.append(r["line"].buffer(r["width_m"] / 2, quad_segs=4, cap_style="round" if r["hierarchy"] != "cul_de_sac" else "flat"))
    return {"nodes": node_recs, "links": links, "planarity": {"violations": near, "pass": not near, "near_misses_joined": joined},
            "_new": new, "_corr": union(polys)}


def _is_tee(n):
    dirs = []
    x, z = n["xz"]
    for r in n["links"]:
        cs = list(r["line"].coords)
        far = cs[1] if math.hypot(cs[0][0] - x, cs[0][1] - z) < 0.5 else cs[-2]
        dirs.append(G.bearing_of(far[0] - x, far[1] - z))
    dirs.sort()
    gaps = [(dirs[(i + 1) % 3] - dirs[i]) % 360 for i in range(3)]
    return "T" if any(abs(gp - 180) <= 25 for gp in gaps) else "Y"


def _link_reason(r):
    if r["hierarchy"] == "primary":
        return "planned_axis" if r.get("role") == "civic_link" else "existing_route"
    if r["hierarchy"] == "route":
        return "existing_route"
    bends = r.get("bends", [])
    if not bends:
        return "straight"
    cnt = {}
    for b in bends:
        cnt[b["reason"]] = cnt.get(b["reason"], 0) + 1
    return max(sorted(cnt), key=lambda k: cnt[k])


def mode_record(C, line, width, hier):
    R = C.R
    lim = R.p("movement.mode_limits")
    mw = R.p("layout.streets.mode_width_m")
    sus, loc, _, _, _ = Rt.sustained_grade(C.A.win, C.A.h, list(line.coords), R.p("routing.mountain.window_m"), 2.0)
    modes = {}
    for m in ("foot", "pack_horse", "cart"):
        why = []
        ok = True
        if width < mw[m]:
            ok = False
            why.append(f"width {width:.2f} < {mw[m]} m")
        if sus > lim[m] + 1e-6:
            ok = False
            why.append(f"sustained grade {sus:.3f} > {lim[m]}")
        if hier == "cul_de_sac" and m == "cart":
            why.append("dead end: no cart turning space (test value)")
            ok = False
        modes[m] = {"passable": ok, "reasons": why, "status": "proposed"}
    if not modes["foot"]["passable"] and sus > lim["foot"]:
        modes["foot"]["steps_required"] = True
    return modes, {"sustained_10m": round(sus, 4), "local_max": round(loc, 4)}


def plazas(C):
    """Only program-funded open spaces (no circular junction plazas)."""
    out = []
    for c in C.fr["civic_reserves"]:
        out.append({"id": f"plaza:{c['id']}:forecourt", "program": "civic_forecourt", "of": c.get("stable_id", c["id"]),
                    "geometry": C.add(C.g(c["forecourt"])), "_g": C.g(c["forecourt"])})
        if c["key"] == "market":
            out.append({"id": f"plaza:{c['id']}", "program": "market", "of": c.get("stable_id", c["id"]),
                        "geometry": C.add(C.g(c["envelope"])), "_g": C.g(c["envelope"])})
    for w in C.fr.get("water_access", []):
        out.append({"id": f"plaza:{w['id']}", "program": "well", "of": w.get("stable_id", w["id"]),
                    "geometry": C.add(C.g(w["reservation"])), "_g": C.g(w["reservation"])})
    return out
