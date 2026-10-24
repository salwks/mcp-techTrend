"""One authoritative planar subdivision with shared half-edges (L3-8 3회차 §3–§4).

Input: semantic faces that tile the domain (built by precedence differences and exact splits, so
neighbours share boundary geometry). The boundary linework of all faces is noded once on the
0.05 m output grid and polygonized (`polygonize_full` reports cuts, dangles and invalid rings).
Every noded piece becomes one edge stored once with its left and right face; faces reference
rings of signed edges (`e+` = along, `e-` = reversed). Neighbours therefore reference the same
edge geometry in opposite directions — boundaries are never inset independently.

Each edge carries adjacency, purpose, geometry reason (from the construction line it lies on) and
the allowed closure types for WP6.
"""
from __future__ import annotations

import math

import numpy as np
import shapely
from shapely.geometry import LineString, MultiLineString, Point, Polygon

from . import geometry as G


def _lines_of(geom):
    if geom is None or geom.is_empty:
        return []
    b = geom.boundary
    return [b] if b.geom_type == "LineString" else list(getattr(b, "geoms", []))


def build(C, faces, domain, extra_lines=(), reason_of=None):
    """faces: list of {id, kind, use, geom, public(bool), ...}; extra_lines: construction lines
    whose endpoints must split edges (opening intervals); reason_of(points) → [(reason, source)]
    per noded segment, so an edge never spans two geometry reasons."""
    grid = G.GRID
    lines = []
    for f in faces:
        lines += _lines_of(f["geom"])
    lines += [l for l in extra_lines if l is not None and not l.is_empty]
    noded = shapely.union_all(lines, grid_size=grid)
    polys, cuts, dangles, invalid = shapely.polygonize_full([noded])
    polys = [p for p in getattr(polys, "geoms", []) if not p.is_empty]
    # assign each polygonized piece to a semantic face (representative point, else max overlap)
    tree = shapely.STRtree([f["geom"] for f in faces])
    piece_face = []
    slivers = 0
    for p in polys:
        rp = p.representative_point()
        hits = tree.query(rp, predicate="intersects")
        hits = [int(h) for h in hits if faces[int(h)]["geom"].contains(rp)]
        if len(hits) == 1:
            piece_face.append(hits[0])
            continue
        cand = tree.query(p, predicate="intersects")
        best = max((int(h) for h in cand), key=lambda h: (faces[h]["geom"].intersection(p).area, -h), default=None)
        piece_face.append(best)
        if p.area < 0.05:
            slivers += 1
    unassigned = sum(1 for x in piece_face if x is None)
    face_of_piece = [faces[i]["id"] if i is not None else "unclassified" for i in piece_face]
    ptree = shapely.STRtree(polys) if polys else None
    # segments
    segs = []
    for ln in getattr(noded, "geoms", [noded]):
        cs = list(ln.coords)
        for a, b in zip(cs, cs[1:]):
            if a != b:
                segs.append((a, b))
    # left / right face per segment (offset probes)
    mids, lefts, rights = [], [], []
    for a, b in segs:
        dx, dz = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dz)
        e = min(0.01, n / 4)
        mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        lx, lz = mx - dz / n * e, mz + dx / n * e
        rx, rz = mx + dz / n * e, mz - dx / n * e
        lefts.append(Point(lx, lz))
        rights.append(Point(rx, rz))
    def locate(pts):
        out = ["exterior"] * len(pts)
        if ptree is None:
            return out
        idx = ptree.query(pts, predicate="within")
        for pi, gi in zip(idx[0], idx[1]):
            out[int(pi)] = face_of_piece[int(gi)]
        return out
    # exact side assignment from the polygonized rings (interior is left of a CCW exterior and
    # of a CW hole); probes only as a fallback for segments missing from the rings
    from shapely.geometry.polygon import orient as _orient
    side = {}
    for pi, poly in enumerate(polys):
        op = _orient(poly, 1.0)
        for ring in [op.exterior] + list(op.interiors):
            cs = list(ring.coords)
            for a, b in zip(cs, cs[1:]):
                side[(a, b)] = face_of_piece[pi]
    PL = locate(lefts)
    PR = locate(rights)
    L, Rr = [], []
    fb = 0
    for k, (a, b) in enumerate(segs):
        l_ = side.get((a, b))
        r_ = side.get((b, a))
        if l_ is None and r_ is None:
            fb += 1
            l_, r_ = PL[k], PR[k]
        L.append(l_ if l_ is not None else "exterior")
        Rr.append(r_ if r_ is not None else "exterior")
    mids_pts = [Point((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) for a, b in segs]
    RS = reason_of(mids_pts) if reason_of is not None else [("none", None)] * len(segs)
    # merge consecutive segments into edges between break nodes (degree != 2 or face change)
    keep = [k for k in range(len(segs)) if L[k] != Rr[k]]
    internal = len(segs) - len(keep)
    deg, adj = {}, {}
    for k in keep:
        a, b = segs[k]
        for p_ in (a, b):
            deg[p_] = deg.get(p_, 0) + 1
            adj.setdefault(p_, []).append(k)

    def lab_from(k, node):
        a, b = segs[k]
        return ((L[k], Rr[k], RS[k]), b) if a == node else ((Rr[k], L[k], RS[k]), a)

    brk = set(p_ for p_, d in deg.items() if d != 2)
    for p_, d in deg.items():
        if d == 2 and p_ not in brk:
            j, k = adj[p_]
            (lj, _), (lk, _) = lab_from(j, p_), lab_from(k, p_)
            # passing through: incoming j reversed must equal outgoing k
            if (lj[1], lj[0], lj[2]) != lk:
                brk.add(p_)
    used = set()
    edges = []

    def walk(k, start):
        lab, nxt = lab_from(k, start)
        used.add(k)
        pts = [start, nxt]
        cur = nxt
        while cur not in brk:
            cand = [j for j in adj[cur] if j not in used]
            if not cand:
                break
            j = cand[0]
            lab2, nx2 = lab_from(j, cur)
            if lab2 != lab:
                break
            used.add(j)
            pts.append(nx2)
            cur = nx2
            if cur == start:
                break
        return {"pts": pts, "left": lab[0], "right": lab[1], "reason": lab[2]}

    for p_ in sorted(brk):
        for k in sorted(adj.get(p_, [])):
            if k not in used:
                edges.append(walk(k, p_))
    for k in keep:
        if k not in used:
            st = min(segs[k])
            brk.add(st)
            edges.append(walk(k, st))
    # nodes
    nodes = {}
    for e in edges:
        for p in (e["pts"][0], e["pts"][-1]):
            if p not in nodes:
                nodes[p] = f"v{len(nodes) + 1:05d}"
    edges.sort(key=lambda e: (min(e["left"], e["right"]), max(e["left"], e["right"]), str(e["reason"][0]),
                              e["pts"][0][1], e["pts"][0][0]))
    face_ids = {f["id"] for f in faces}
    out_edges = []
    for n, e in enumerate(edges):
        e["line"] = LineString(e["pts"])
        if C is not None and getattr(C, "reg", None) is not None:
            # persistent boundary identity (registry: side faces + reason, matched by position)
            m = e["line"].interpolate(0.5, normalized=True)
            e["id"] = C.claim("boundary", key=f"{min(e['left'], e['right'])}|{max(e['left'], e['right'])}|{e['reason'][0]}",
                              xz=[G.r2(m.x), G.r2(m.y)], tol=0.5, content=G.to_geojson(e["line"]))
        else:
            e["id"] = f"e{n + 1:05d}"
        e["nodes"] = [nodes[e["pts"][0]], nodes[e["pts"][-1]]]
    # rings per face
    half = {}
    for e in edges:
        if e["left"] != "exterior":
            half.setdefault(e["left"], []).append((e["id"], "+", e["pts"][0], e["pts"][-1]))
        if e["right"] != "exterior":
            half.setdefault(e["right"], []).append((e["id"], "-", e["pts"][-1], e["pts"][0]))
    rings = {}
    ring_fail = []
    for fid, hs in half.items():
        start = {}
        for h in hs:
            start.setdefault(h[2], []).append(h)
        usedh = set()
        rs = []
        for h in sorted(hs):
            if (h[0], h[1]) in usedh:
                continue
            ring = []
            cur = h
            guard = 0
            while guard < len(hs) + 2:
                guard += 1
                usedh.add((cur[0], cur[1]))
                ring.append(f"{cur[0]}{cur[1]}")
                if cur[3] == h[2]:
                    break
                nxts = [x for x in start.get(cur[3], []) if (x[0], x[1]) not in usedh]
                if not nxts:
                    ring_fail.append(fid)
                    break
                cur = sorted(nxts)[0]
            rs.append(ring)
        rings[fid] = rs
    rec_edges = []
    fmap = {f["id"]: f for f in faces}
    for e in edges:
        rec_edges.append({"id": e["id"], "nodes": e["nodes"], "left_face": e["left"], "right_face": e["right"],
                          "length_m": round(e["line"].length, 3), "_line": e["line"], "_reason": e["reason"]})
    rec = {"vertices": [{"id": v, "xz": [G.r2(p[0]), G.r2(p[1])]} for p, v in sorted(nodes.items(), key=lambda kv: kv[1])],
           "edges": rec_edges,
           "faces": [{"id": fid, "rings": rings.get(fid, [])} for fid in sorted(fmap)],
           "diagnostics": {"polygonize_cuts": len(getattr(cuts, "geoms", [])), "polygonize_dangles": len(getattr(dangles, "geoms", [])),
                           "polygonize_invalid_rings": len(getattr(invalid, "geoms", [])), "snapping_slivers": slivers,
                           "unassigned_pieces": unassigned, "internal_edges_dropped": internal,
                           "ring_failures": sorted(set(ring_fail)), "pieces": len(polys), "side_probe_fallbacks": fb},
           "_polys": polys, "_piece_face": face_of_piece}
    return rec


def ring_area(rec, fid, edge_lines):
    """Signed area from the face's edge rings (exact twin check)."""
    tot = 0.0
    for ring in next((f["rings"] for f in rec["faces"] if f["id"] == fid), []):
        pts = []
        for h in ring:
            eid, sgn = h[:-1], h[-1]
            cs = list(edge_lines[eid].coords)
            if sgn == "-":
                cs = cs[::-1]
            pts.extend(cs if not pts else cs[1:])
        if len(pts) >= 4:
            tot += Polygon(pts).area if Polygon(pts).is_valid else abs(_shoelace(pts))
            tot = tot if _shoelace(pts) >= 0 else tot - 2 * abs(_shoelace(pts))
    return tot


def _shoelace(pts):
    s = 0.0
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        s += x0 * z1 - x1 * z0
    return s / 2


def signed_ring_area(rec, fid, edge_lines):
    tot = 0.0
    for ring in next((f["rings"] for f in rec["faces"] if f["id"] == fid), []):
        pts = []
        for h in ring:
            eid, sgn = h[:-1], h[-1]
            cs = list(edge_lines[eid].coords)
            if sgn == "-":
                cs = cs[::-1]
            pts.extend(cs if not pts else cs[1:])
        tot += _shoelace(pts)
    return tot
