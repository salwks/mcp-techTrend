"""Layer 5 — blocks and parcels (L3-8 3회차 §3, BLD-02, VIL-01/02/04, metrics §3.2).

For each block (stable order): street-frontage runs are measured along the street boundary (not
the centreline); each run is cut into frontage intervals whose widths come from the district's
parcel-role distribution (seeded from the block / run ids, then redistributed so the intervals
exactly cover the run, never starting a split within the junction clearance). Split lines leave
the frontage along the local normal (curved frontages pass their curvature to the lots) to the
role's strip depth (≤ 30 m world); the strip is split once, exactly, and pieces that touch no
interval are merged into the neighbour with the longest shared boundary — neighbouring lots are
never clipped independently.

Missing household access asks Layer 4 for a cul-de-sac (≤ 36 m) or a through lane (bounded
retries, then a revision request). Rear land becomes the garden of the frontage lot behind which
it lies (narrow, deep lots with gardens behind) up to the garden depth, otherwise a garden /
field / non-built parcel with management access (street contact or an explicit easement face).
Slivers merge into the compatible neighbour or stay as classified residuals. Every programmed
household is assigned exactly once or reported.
"""
from __future__ import annotations

import math

import numpy as np
import shapely
from shapely.geometry import LineString, MultiLineString, Point, Polygon
from shapely.ops import substring

from . import geometry as G
from .layout_ctx import tangent_at, union

RES_GROUPS = ("market_trade", "clerical", "elite", "craft", "ordinary")


def split_poly(poly, lines):
    """Exact split of a polygon by lines (polygonize of noded boundary + cut lines)."""
    if not lines:
        return [poly]
    cut = union([l.intersection(poly.buffer(0.01)) for l in lines])
    if cut.is_empty:
        return [poly]
    noded = shapely.union_all([poly.boundary, cut])
    out = []
    for p in shapely.polygonize([noded]).geoms:
        if p.area > 1e-6 and poly.contains(p.representative_point()):
            out.append(p)
    return out or [poly]


def role_for(C, group, hierarchy, hamlet=False):
    if hamlet:
        return "village_ordinary"
    if not C.urban:
        if group == "elite":
            return "village_elite"
        return "sanchon" if C.sanchon else "village_ordinary"
    if hierarchy in ("cul_de_sac",):
        return "rear_residential"
    if group == "elite":
        return "elite_urban"
    if group == "clerical":
        return "clerical"
    if group == "market_trade" and hierarchy in ("primary", "plaza"):
        return "urban_primary"
    if hierarchy == "lane":
        return "rear_residential" if group == "ordinary" else "urban_secondary"
    return "urban_secondary"


def role_dims(C, role):
    r = C.R.p("layout.parcels.roles")[role]
    fw = (C.wl(r["frontage"][0]), C.wl(r["frontage"][1]))
    ar = (C.wa(r["area"][0]), C.wa(r["area"][1]))
    ratio = r["ratio"]
    amid = math.sqrt(ar[0] * ar[1])
    fmid = (fw[0] + fw[1]) / 2          # mean of the seeded uniform frontage sample
    # depth so that mean frontage × depth meets the area target, inside the depth/frontage ratio range
    depth = min(max(amid / fmid, fmid * ratio[0]), fmid * ratio[1])
    dmax = C.wl(C.R.p("layout.parcels.strip_depth_max_hist_m"))
    return {"frontage": fw, "area": ar, "ratio": ratio, "depth": min(depth, dmax), "depth_raw": depth}


def widths(rng, L, lo, hi):
    """Seeded sample + constrained redistribution so the intervals exactly cover L."""
    mid = (lo + hi) / 2
    n = max(1, int(round(L / mid)))
    while n > 1 and L / n < lo:
        n -= 1
    while L / n > hi:
        n += 1
    w = [rng.uniform(lo, hi) for _ in range(n)]
    for _ in range(20):
        s = sum(w)
        w = [x * L / s for x in w]
        cl = [min(hi, max(lo, x)) for x in w]
        if all(abs(a - b) < 1e-9 for a, b in zip(cl, w)):
            break
        w = cl
    s = sum(w)
    w = [x * L / s for x in w]
    return w


class Block:
    def __init__(self, bid, poly, hamlet=None):
        self.id, self.poly, self.hamlet = bid, poly, hamlet
        self.lots, self.rear, self.revisions = [], [], 0


def _label_at(C, x, z):
    PG = C.dgrid
    i, j = PG.ij(x, z)
    if not PG.inside(i, j):
        return None
    k = int(C.dlab[j, i])
    return C.dnames[k] if k >= 0 else None


def _district_at(C, poly):
    """District part id by majority of planning cells inside the lot."""
    PG = C.dgrid
    xmin, zmin, xmax, zmax = poly.bounds
    best, cnt = None, {}
    xs = np.arange(xmin, xmax + 1e-9, PG.cell)
    zs = np.arange(zmin, zmax + 1e-9, PG.cell)
    pts = [Point(x, z) for z in zs for x in xs]
    pts = [p for p in pts if poly.contains(p)] or [poly.representative_point()]
    for p in pts:
        i, j = PG.ij(p.x, p.y)
        if not PG.inside(i, j):
            continue
        for did, m in C.district_masks.items():
            if m[j, i]:
                cnt[did] = cnt.get(did, 0) + 1
                break
    if cnt:
        best = max(sorted(cnt), key=lambda k: cnt[k])
    return best


def _hier_at(tree, link_index, pt):
    if tree is None:
        return "plaza"
    i = tree.nearest(pt)
    l = link_index[int(i)]
    return l["hierarchy"] if l["line"].distance(pt) - l["width_m"] / 2 < 1.5 else "plaza"


def frontage_runs(C, blk, public, link_index):
    b = blk.poly.boundary
    inter = b.intersection(public.buffer(0.05))
    ls = [g for g in getattr(inter, "geoms", [inter]) if g.geom_type in ("LineString", "MultiLineString")]
    if not ls:
        return []
    merged = shapely.line_merge(union(ls))
    runs = [g for g in getattr(merged, "geoms", [merged]) if g.geom_type == "LineString" and g.length >= 3.0]
    out = []
    for k, r in enumerate(sorted(runs, key=lambda r: (-round(r.length, 2), round(r.coords[0][1], 2), round(r.coords[0][0], 2)))):
        mid = r.interpolate(0.5, normalized=True)
        hier = "plaza"
        best = None
        for l in link_index:
            d = l["line"].distance(mid) - l["width_m"] / 2
            if best is None or d < best[0]:
                best = (d, l)
        if best is not None and best[0] < 1.0:
            hier = best[1]["hierarchy"]
        out.append({"line": r, "hierarchy": hier, "k": k})
    return out


def subdivide_block(C, blk, public, link_index):
    """Frontage strips → exact split → lots; returns rear remainder parts."""
    R = C.R
    poly = blk.poly
    runs = frontage_runs(C, blk, public, link_index)
    link_tree = shapely.STRtree([l["line"] for l in link_index]) if link_index else None
    cclear = R.p("layout.parcels.corner_clear_m")
    cuts, intervals, strips = [], [], []
    for run in runs:
        line = run["line"]
        L = line.length
        # district / group labels along the run (probe inward)
        segs = []
        step = 4.0
        n = max(1, int(L / step))
        prev = None
        for i in range(n + 1):
            s = min(L, i * step)
            tx, tz = tangent_at(line, s)
            p = line.interpolate(s)
            nx_, nz_ = -tz, tx
            if not poly.contains(Point(p.x + nx_ * 0.5, p.y + nz_ * 0.5)):
                nx_, nz_ = -nx_, -nz_
            lab = _label_at(C, p.x + nx_ * 8.0, p.y + nz_ * 8.0)
            grp = lab if lab in RES_GROUPS else "garden_open"
            if blk.hamlet:
                grp = "ordinary"
            hier = _hier_at(link_tree, link_index, Point(p.x - nx_ * 0.5, p.y - nz_ * 0.5))
            key = (grp, hier)
            if prev is None or key != prev[2]:
                if prev is not None:
                    segs.append((prev[0], s, prev[2]))
                prev = [s, s, key]
        segs.append((prev[0], L, prev[2]))
        # merge short segments into the longer neighbour
        changed = True
        while changed and len(segs) > 1:
            changed = False
            for i, (a, b, (g_, h_)) in enumerate(segs):
                role = role_for(C, g_ if g_ in RES_GROUPS else "ordinary", h_, bool(blk.hamlet))
                lo = role_dims(C, role)["frontage"][0]
                if b - a < lo:
                    j = i - 1 if i > 0 and (i == len(segs) - 1 or segs[i - 1][1] - segs[i - 1][0] >= segs[i + 1][1] - segs[i + 1][0]) else i + 1
                    a2, b2, g2 = segs[j]
                    segs[j] = (min(a, a2), max(b, b2), g2)
                    segs.pop(i)
                    changed = True
                    break
        for si, (a, b, (grp, hier)) in enumerate(segs):
            seg_line = substring(line, a, b)
            if seg_line.length < 1.0:
                continue
            g_role = grp if grp in RES_GROUPS else "ordinary"
            role = role_for(C, g_role, hier, bool(blk.hamlet))
            dims = role_dims(C, role)
            rng = C.rng("block", blk.id, run["k"], si)
            ws = widths(rng, b - a, *dims["frontage"])
            d = dims["depth"]
            strips.append(seg_line.buffer(d, cap_style="flat", quad_segs=4))
            s = a
            for wi, w in enumerate(ws):
                iv = substring(line, s, s + w)
                intervals.append({"line": iv, "run": run["k"], "hierarchy": hier,
                                  "group": grp if grp in RES_GROUPS else "ordinary", "garden_district": grp not in RES_GROUPS,
                                  "role": role, "depth": d, "width": w, "s": (s, s + w), "run_line": line})
                s += w
                if wi < len(ws) - 1 and cclear <= s <= L - cclear:
                    cuts.append(_cut(line, s, poly, d))
            # segment boundary inside the run
            if b < L - 1e-6 and cclear <= b <= L - cclear:
                cuts.append(_cut(line, b, poly, d))
    if not strips:
        blk.lots = []
        blk.rear = [poly]
        return
    S = G.polygonal(union(strips).intersection(poly))
    for c in cuts:
        C.reason(c, "frontage_normal", blk.id)
    pieces = []
    for sp in G.parts(S):
        for pc in split_poly(sp, cuts):
            # exact: pieces never exceed the strip (polygonize may return a shell without its hole)
            pieces += [q for q in G.parts(G.polygonal(pc.intersection(sp))) if q.area > 1e-4]
    # strip back boundaries (depth line) are construction lines too
    C.reason(S.boundary, "frontage_depth", blk.id)
    lots = {i: [] for i in range(len(intervals))}
    orphans = []
    ivbuf = [iv["line"].buffer(0.06, cap_style="flat") for iv in intervals]
    for p in pieces:
        best = None
        for i, ib in enumerate(ivbuf):
            if not p.intersects(ib):
                continue
            t = p.boundary.intersection(ib).length
            if t > 0.05 and (best is None or t > best[0]):
                best = (t, i)
        if best is None:
            orphans.append(p)
        else:
            lots[best[1]].append(p)
    out = []
    for i, ps in lots.items():
        if not ps:
            continue
        lp = G.polygonal(shapely.union_all(ps))
        prts = G.parts(lp)
        keep = max(prts, key=lambda q: (q.intersection(ivbuf[i]).area, q.area))
        for q in prts:
            if q is not keep:
                orphans.append(q)
        rec = dict(intervals[i])
        rec["poly"] = keep
        rec["base_area"] = keep.area
        out.append(rec)
    # merge orphans into the lot sharing the longest boundary
    for o in sorted(orphans, key=lambda q: -q.area):
        best = None
        for rec in out:
            t = rec["poly"].boundary.intersection(o.boundary).length
            if t > 0.05 and (best is None or t > best[0]):
                best = (t, rec)
        if best is not None:
            u = G.polygonal(best[1]["poly"].union(o))
            if u.geom_type == "Polygon":
                best[1]["poly"] = u
    blk.lots = out
    # rear = everything the lots do not cover (orphans included) — exact complement, no overlap
    used = union([l["poly"] for l in out])
    rear = G.polygonal(poly.difference(used)) if not used.is_empty else poly
    blk.rear = [r for r in G.parts(rear) if r.area > 0.5]


def _cut(line, s, poly, d):
    tx, tz = tangent_at(line, s)
    p = line.interpolate(s)
    nx_, nz_ = -tz, tx
    if not poly.contains(Point(p.x + nx_ * 0.5, p.y + nz_ * 0.5)):
        nx_, nz_ = -nx_, -nz_
    return LineString([(p.x - nx_ * 1.0, p.y - nz_ * 1.0), (p.x + nx_ * (d + 1.5), p.y + nz_ * (d + 1.5))])


def access_cut(C, blk, public, link_index, target=None, through=False):
    """Layer-4 access revision: a cul-de-sac (≤36 m) or a through lane toward a rear part."""
    R = C.R
    hr = R.p("layout.streets.hierarchy")
    runs = frontage_runs(C, blk, public, link_index)
    runs = [r for r in runs if r["hierarchy"] not in ("cul_de_sac",) and r["line"].length >= 20.0]
    if not runs:
        return None
    cc = R.p("layout.parcels.corner_clear_m") + 5.0
    tp = target.representative_point() if target is not None else None
    if tp is not None:
        run = min(runs, key=lambda r: (round(r["line"].distance(tp), 1), r["k"]))
        line = run["line"]
        s = min(max(line.project(tp), cc), line.length - cc)
    else:
        run = runs[0]
        line = run["line"]
        s = line.length / 2
    if line.length < 2 * cc:
        return None
    p = line.interpolate(s)
    tx, tz = tangent_at(line, s)
    nx_, nz_ = -tz, tx
    if not blk.poly.contains(Point(p.x + nx_ * 0.5, p.y + nz_ * 0.5)):
        nx_, nz_ = -nx_, -nz_
    ray = LineString([(p.x, p.y), (p.x + nx_ * 400, p.y + nz_ * 400)])
    hit = ray.intersection(blk.poly.boundary)
    pts = [g for g in getattr(hit, "geoms", [hit]) if g.geom_type == "Point" and g.distance(p) > 1.0]
    if not pts:
        return None
    far = min(pts, key=lambda q: q.distance(p))
    D = far.distance(p)
    cmax = C.wl(hr["cul_de_sac"]["length_hist_max_m"])
    dr = role_dims(C, "rear_residential")["depth"]
    if through or D > cmax + 2 * dr:
        far_pub = far.distance(public) < 0.3
        if not far_pub:
            if through:
                return None
            through = False
        else:
            through = True
    if through:
        hier, w = "lane", C.wl(hr["lane"]["width_hist_default_m"])
        L = D
    else:
        hier, w = "cul_de_sac", C.wl(hr["cul_de_sac"]["width_hist_default_m"])
        L = min(cmax, D - dr * 0.6)
        if L < role_dims(C, "urban_secondary" if C.urban else "village_ordinary")["depth"] + 6.0:
            return None
    cl = LineString([(G.r2(p.x), G.r2(p.y)), (G.r2(p.x + nx_ * L), G.r2(p.y + nz_ * L))])
    corr = G.polygonal(cl.buffer(w / 2, cap_style="flat").intersection(blk.poly))
    if corr.is_empty:
        return None
    return {"line": cl, "corridor": corr, "hierarchy": hier, "width_m": w, "length_m": round(L, 2), "block": blk.id,
            "through": through}


def build(C, blocks, public, link_index, households):
    """Run Layer 5 over all blocks; returns parcels, easements, access additions, reports."""
    R = C.R
    tries = R.p("layout.parcels.retries")
    for blk in blocks:
        subdivide_block(C, blk, public, link_index)
    added_access = []
    # ---- eligibility (buildable envelope) and district of each lot
    for blk in blocks:
        _annotate(C, blk)
    # deficits → access revisions (cul-de-sacs / through lanes) toward the largest rear parts
    rmin = C.wa(R.p("layout.parcels.roles")["rear_residential"]["area"][0])
    blk_cap = lambda b: max(tries["access"], int(b.poly.area // C.wa(2500)))
    for rnd in range(40):
        need = _deficits(C, blocks, households)
        tot_def = sum(v for v in need.values() if v > 0) - sum(-v for v in need.values() if v < 0)
        if tot_def <= 0:
            break
        cand = []
        for blk in blocks:
            if blk.revisions >= blk_cap(blk):
                continue
            for r in blk.rear:
                if r.area >= 2 * rmin:
                    cand.append((-round(r.area, 1), blk.id, blk, r))
        cand.sort(key=lambda t: (t[0], t[1]))
        want = max(1, math.ceil(tot_def / 3))
        done_blocks = set()
        progressed = False
        for _, _, blk, r in cand:
            if len(done_blocks) >= want:
                break
            if blk.id in done_blocks:
                continue
            acc = access_cut(C, blk, public, link_index, target=r)
            blk.revisions += 1
            if acc is None:
                continue
            # trial: accept the revision only if it adds usable lots (bounded, deterministic)
            before = _usable(C, [blk])
            snap = (blk.poly, blk.lots, blk.rear)
            pub2 = union([public, acc["corridor"]])
            li2 = link_index + [{"line": acc["line"], "hierarchy": acc["hierarchy"], "width_m": acc["width_m"]}]
            prts = G.parts(G.polygonal(blk.poly.difference(acc["corridor"])))
            trial = []
            for k, part in enumerate(prts):
                tb = blk if k == 0 else Block(f"{blk.id}.{k + 1}", part, blk.hamlet)
                tb.poly = part
                tb.lots, tb.rear = [], []
                subdivide_block(C, tb, pub2, li2)
                _annotate(C, tb)
                trial.append(tb)
            after = _usable(C, trial)
            if after <= before:
                blk.poly, blk.lots, blk.rear = snap
                continue
            done_blocks.add(blk.id)
            progressed = True
            sid = C.claim("street", key=f"access:{blk.id}:{blk.revisions}", content=G.to_geojson(acc["line"]))
            acc["id"] = sid
            acc["lots_gained"] = after - before
            added_access.append(acc)
            C.reason(acc["corridor"].boundary, "rear_access_demand", sid)
            public = pub2
            link_index.append(li2[-1])
            for tb in trial[1:]:
                tb.revisions = blk.revisions
                blocks.append(tb)
        if not progressed:
            break
    # ---- remaining deficit: rear lots with explicit access easements (flag lots)
    easements = _rear_lots(C, blocks, households, public)
    # ---- rear land → garden of the lot in front (depth limit) / own parcel / easement
    easements += _rear(C, blocks, public)
    # ---- slivers
    slv = _slivers(C, blocks)
    # ---- households (district first, then group, then any); unused lots merge or become gardens
    unplaced = _assign(C, blocks, households)
    _surplus(C, blocks)
    return {"blocks": blocks, "access_added": added_access, "easements": easements, "slivers": slv,
            "unplaced": unplaced, "public": public}


def _usable(C, blocks):
    n = 0
    for b in blocks:
        for lot in b.lots:
            if lot["eligible"] and lot["poly"].area >= 0.5 * role_dims(C, lot["role"])["area"][0]:
                n += 1
    return n


def _split_equal(poly, k):
    """Cut a polygon into k pieces of equal area by lines across its long axis."""
    if k <= 1:
        return [poly]
    mrr = poly.minimum_rotated_rectangle
    cs = list(mrr.exterior.coords)[:4]
    e = [(cs[i], cs[(i + 1) % 4]) for i in range(4)]
    long = max(e, key=lambda ab: math.hypot(ab[1][0] - ab[0][0], ab[1][1] - ab[0][1]))
    (x0, z0), (x1, z1) = long
    L = math.hypot(x1 - x0, z1 - z0)
    ux, uz = (x1 - x0) / L, (z1 - z0) / L
    nx_, nz_ = -uz, ux
    c = mrr.centroid
    # project onto the long axis
    t0 = min((p[0] - c.x) * ux + (p[1] - c.y) * uz for p in poly.exterior.coords)
    t1 = max((p[0] - c.x) * ux + (p[1] - c.y) * uz for p in poly.exterior.coords)
    W = 4 * L
    cuts = []
    target = poly.area / k
    for j in range(1, k):
        lo, hi = t0, t1
        for _ in range(40):
            m = (lo + hi) / 2
            half = Polygon([(c.x + ux * (t0 - 1) + nx_ * W, c.y + uz * (t0 - 1) + nz_ * W),
                            (c.x + ux * m + nx_ * W, c.y + uz * m + nz_ * W),
                            (c.x + ux * m - nx_ * W, c.y + uz * m - nz_ * W),
                            (c.x + ux * (t0 - 1) - nx_ * W, c.y + uz * (t0 - 1) - nz_ * W)])
            a = poly.intersection(half).area
            if a < target * j:
                lo = m
            else:
                hi = m
        m = (lo + hi) / 2
        cuts.append(LineString([(c.x + ux * m + nx_ * W, c.y + uz * m + nz_ * W), (c.x + ux * m - nx_ * W, c.y + uz * m - nz_ * W)]))
    return split_poly(poly, cuts), cuts


def _rear_lots(C, blocks, households, public):
    """Remaining household deficit → rear lots cut side by side from rear land, each reached by
    its own frontage contact or an explicit easement face (L3-8 §3: cul-de-sac / easement)."""
    R = C.R
    ew = C.wl(R.p("layout.streets.hierarchy")["easement"]["width_hist_default_m"])
    easements = []
    need = _deficits(C, blocks, households)
    left = sum(v for v in need.values() if v > 0) - sum(-v for v in need.values() if v < 0)
    if left <= 0:
        return easements
    role = "rear_residential" if C.urban else ("sanchon" if C.sanchon else "village_ordinary")
    dims = role_dims(C, role)
    amid = math.sqrt(dims["area"][0] * dims["area"][1])
    cand = sorted(((r.area, b.id, b, r) for b in blocks for r in b.rear if r.area >= dims["area"][0]),
                  key=lambda t: (-round(t[0], 1), t[1]))
    for _, _, blk, r in cand:
        if left <= 0:
            break
        k = int(max(1, r.area // amid))
        res = _split_equal(r, k)
        pieces, cuts = (res if isinstance(res, tuple) else (res, []))
        for c in cuts:
            C.reason(c.intersection(r.buffer(0.01)), "rear_split", blk.id)
        blk.rear = [x for x in blk.rear if x is not r]
        front = union([o["poly"] for o in blk.lots if o.get("run") is not None])
        order = sorted(pieces, key=lambda q: (-round(q.boundary.intersection(front.boundary).length if not front.is_empty else 0, 1),
                                              round(q.bounds[1], 2), round(q.bounds[0], 2)))
        unused = []
        for pc in order:
            if left <= 0:
                unused.append(pc)
                continue
            touch = pc.boundary.intersection(public.buffer(0.05)).length > 2.0
            lot = {"poly": pc, "role": role, "use": "residential", "group": "ordinary", "eligible": True, "run": None,
                   "s": None, "hierarchy": None, "width": None, "depth": None, "base_area": pc.area,
                   "district": _district_at(C, pc) if not blk.hamlet else None, "hamlet": blk.hamlet, "rear_lot": True}
            bd = G.polygonal(pc.intersection(C.buildable)) if not C.buildable.is_empty else Polygon()
            lot["buildable"], lot["buildable_m2"] = bd, bd.area
            if bd.area < 0.5 * dims["area"][0]:
                unused.append(pc)
                continue
            if not touch:
                e = _easement(C, blk, pc, ew, public)
                if e is None:
                    unused.append(pc)
                    continue
                easements.append(e)
                lot["access"] = {"kind": "easement", "easement": e["id"]}
            blk.lots.append(lot)
            left -= 1
        if unused:
            # unused slices go back as one rear area (no fragmentation)
            blk.rear += [q for q in G.parts(G.polygonal(shapely.union_all(unused))) if q.area > 0.5]
    return easements


def _annotate(C, blk):
    R = C.R
    bp = C.buildable
    for lot in blk.lots:
        p = lot["poly"]
        bd = G.polygonal(p.intersection(bp)) if not bp.is_empty else Polygon()
        lot["buildable_m2"] = bd.area
        lot["buildable"] = bd
        lot["district"] = _district_at(C, p) if not blk.hamlet else None
        lot["hamlet"] = blk.hamlet
        role = lot["role"]
        amin = role_dims(C, role)["area"][0] if role != "garden" else 0
        lot["eligible"] = role != "garden" and bd.area >= 0.5 * amin and lot["group"] in RES_GROUPS
        if lot["eligible"] and not blk.hamlet:
            lot["use"] = "residential"
        elif lot["eligible"] and blk.hamlet:
            lot["use"] = "residential"
        else:
            lot["use"] = None


def _deficits(C, blocks, households):
    have = {}
    for blk in blocks:
        for lot in blk.lots:
            if lot["eligible"]:
                k = lot["hamlet"] or lot["district"] or f"group:{lot['group']}"
                have[k] = have.get(k, 0) + 1
    need = {}
    for h in households:
        k = h.get("hamlet") or h.get("district") or f"group:{h['group']}"
        need[k] = need.get(k, 0) + 1
    return {k: need[k] - have.get(k, 0) for k in need}


def _surplus(C, blocks):
    """Lots left without a household: merge into the occupied run neighbour when the merged
    frontage stays inside the role range (+15 %), otherwise keep as a frontage garden (텃밭)."""
    for blk in blocks:
        for lot in blk.lots:
            if lot.get("household") or lot.get("use") != "garden" or lot.get("run") is None or not lot.get("vacant_reason"):
                continue
            nb = [o for o in blk.lots if o is not lot and o.get("household") and o.get("run") == lot["run"]
                  and o.get("s") and (abs(o["s"][1] - lot["s"][0]) < 0.05 or abs(o["s"][0] - lot["s"][1]) < 0.05)]
            for o in sorted(nb, key=lambda o: o["width"]):
                hi = role_dims(C, o["role"])["frontage"][1]
                u = G.polygonal(o["poly"].union(lot["poly"]))
                if o["width"] + lot["width"] <= hi * 1.15 and u.geom_type == "Polygon":
                    o["poly"] = u
                    o["width"] += lot["width"]
                    o["s"] = (min(o["s"][0], lot["s"][0]), max(o["s"][1], lot["s"][1]))
                    lot["_gone"] = True
                    break
        blk.lots = [l for l in blk.lots if not l.get("_gone")]


def _rear(C, blocks, public):
    R = C.R
    gmax = C.wl(R.p("layout.parcels.garden_depth_max_hist_m"))
    ew = C.wl(R.p("layout.streets.hierarchy")["easement"]["width_hist_default_m"])
    easements = []
    for blk in blocks:
        extra = []
        for r in sorted(blk.rear, key=lambda q: (-q.area, q.bounds)):
            touch_pub = r.boundary.intersection(public.buffer(0.05)).length > 2.0
            best = None
            for lot in blk.lots:
                t = lot["poly"].boundary.intersection(r.boundary).length
                if t > 0.5 and (best is None or t > best[0]):
                    best = (t, lot)
            depth_ok = False
            if best is not None:
                lot = best[1]
                merged = G.polygonal(lot["poly"].union(r))
                dep = merged.area / max(lot.get("width") or math.sqrt(lot["poly"].area), 1.0)
                depth_ok = dep <= gmax and merged.geom_type == "Polygon"
            if best is not None and (depth_ok or not touch_pub) and r.area <= 3 * max(best[1].get("base_area", best[1]["poly"].area), 1.0):
                lot = best[1]
                lot["garden_poly"] = G.polygonal(union([lot.get("garden_poly"), r]))
                lot["poly"] = G.polygonal(lot["poly"].union(r))
                if lot["poly"].geom_type != "Polygon":
                    lot["poly"] = G.largest(lot["poly"])
                lot["rear_garden"] = True
                if not depth_ok:
                    lot["garden_depth_exceeded"] = True
                continue
            use = _nonres_use(C, r)
            rec = {"poly": r, "role": use, "use": use, "group": None, "eligible": False, "run": None, "s": None,
                   "hierarchy": None, "width": None, "depth": None, "district": _district_at(C, r), "hamlet": blk.hamlet,
                   "buildable_m2": 0.0, "rear_parcel": True}
            if not touch_pub:
                # management access: explicit easement face along the nearest frontage split
                e = _easement(C, blk, r, ew, public)
                if e is not None:
                    easements.append(e)
                    rec["access"] = {"kind": "easement", "easement": e["id"]}
                else:
                    rec["access"] = {"kind": "none"}
                    C.request("L5/parcels", "rear parcel without street contact or feasible easement", "rear_access_missing",
                              block=blk.id, area_m2=round(r.area, 1))
            extra.append(rec)
        blk.lots += extra
        blk.rear = []
    return easements


def _nonres_use(C, poly):
    c = poly.representative_point()
    lab = _label_at(C, c.x, c.y)
    if lab == "hill":
        return "hill"
    if lab == "open_ground":
        return "open_ground"
    if lab == "field_protected":
        return "field"
    return "garden"


def _easement(C, blk, rear, w, public=None):
    """Easement strip from the street along a frontage split line to the rear parcel (shortest
    feasible); verified to touch both the street side and the rear parcel."""
    front_lots = [o for o in blk.lots if o.get("run") is not None and o.get("run_line") is not None]
    front = union([o["poly"] for o in front_lots])
    cands = []
    for lot in front_lots:
        if lot["poly"].boundary.intersection(rear.boundary).length <= 0.5:
            continue
        line = lot["run_line"]
        for s_ in lot["s"]:
            if s_ <= 1.0 or s_ >= line.length - 1.0:
                continue
            cut = _cut(line, s_, blk.poly, (lot["depth"] or 20.0) + 6.0)
            if not cut.intersects(rear):
                continue
            strip = G.polygonal(cut.buffer(w / 2, cap_style="flat").intersection(blk.poly))
            strip = G.polygonal(strip.difference(union(list(blk.rear) + [rear])))
            strip = G.polygonal(strip.intersection(front))
            if strip.is_empty:
                continue
            strip = G.largest(strip)
            ok_rear = strip.boundary.intersection(rear.boundary).length >= 0.8 * w
            ok_pub = public is None or strip.boundary.intersection(public.buffer(0.05)).length >= 0.8 * w
            if ok_rear and ok_pub:
                cands.append((round(strip.area, 2), round(s_, 2), strip))
    if not cands:
        return None
    _, _, strip = min(cands, key=lambda t: (t[0], t[1]))
    for o in blk.lots:
        if o.get("poly") is not None and o["poly"].intersects(strip):
            rest = G.polygonal(o["poly"].difference(strip))
            prts = G.parts(rest)
            if prts:
                o["poly"] = prts[0]
                for extra in prts[1:]:
                    blk.rear.append(extra)
    eid = C.claim("easement", key=None, xz=[G.r2(strip.centroid.x), G.r2(strip.centroid.y)], tol=3.0, content=G.to_geojson(strip))
    C.reason(strip.boundary, "easement", eid)
    return {"id": eid, "poly": strip, "width_m": round(w, 2), "purpose": "access", "beneficiaries": [],
            "entrances": "street end and rear-parcel end", "block": blk.id,
            "note": "explicit access face — not pedestrian passage through another courtyard"}


def _slivers(C, blocks):
    R = C.R
    sv = R.p("layout.parcels.sliver")
    neck = C.wl(sv["neck_hist_m"])
    out = {"merged": 0, "residual": 0}
    for blk in blocks:
        keep = []
        for lot in sorted(blk.lots, key=lambda l: l["poly"].area):
            role = lot["role"] if lot["role"] in R.p("layout.parcels.roles") else None
            amin = role_dims(C, role)["area"][0] if role else 0.0
            sliver = (role and lot["poly"].area < sv["area_frac"] * amin) or lot["poly"].buffer(-neck / 2).is_empty
            if not sliver:
                keep.append(lot)
                continue
            best = None
            for o in blk.lots:
                if o is lot or o.get("_gone"):
                    continue
                t = o["poly"].boundary.intersection(lot["poly"].boundary).length
                if t > 0.3 and (best is None or t > best[0]):
                    best = (t, o)
            if best is not None:
                o = best[1]
                u = G.polygonal(o["poly"].union(lot["poly"]))
                if u.geom_type == "Polygon":
                    o["poly"] = u
                    lot["_gone"] = True
                    out["merged"] += 1
                    continue
            lot["residual"] = True
            lot["eligible"] = False
            lot["use"] = "residual_" + ("garden" if lot.get("group") else "nonbuildable")
            out["residual"] += 1
            keep.append(lot)
        blk.lots = [l for l in blk.lots if not l.get("_gone")]
    return out


def _assign(C, blocks, households):
    """Households → eligible lots: same district (or hamlet) first, then same group, else report."""
    order = {"elite": 0, "specialist": 1, "ordinary": 2}
    lots = []
    for blk in blocks:
        for i, lot in enumerate(blk.lots):
            lot["_ord"] = (blk.id, lot.get("run") if lot.get("run") is not None else 999, (lot.get("s") or (0, 0))[0], i)
            if lot["eligible"]:
                lots.append(lot)
    lots.sort(key=lambda l: l["_ord"])
    free = list(lots)
    unplaced = []
    pending = sorted(households, key=lambda h: (order[h["class"]], h["id"]))
    for stage in ("district", "group", "any"):
        rest = []
        for h in pending:
            key_ = h.get("hamlet") or h.get("district")
            if stage == "district":
                cand = [l for l in free if (l["hamlet"] or l["district"]) == key_]
            elif stage == "group":
                cand = [l for l in free if l["group"] == h["group"] and bool(l["hamlet"]) == bool(h.get("hamlet"))]
            else:
                cand = [l for l in free if bool(l["hamlet"]) == bool(h.get("hamlet"))]
            if not cand:
                rest.append(h)
                continue
            # biggest-need households take the largest lots
            l = max(cand, key=lambda l: (l["poly"].area, [-x for x in l["_ord"][1:3]] if False else 0)) if h["class"] != "ordinary" else cand[0]
            free.remove(l)
            l["household"] = h["id"]
            l["use"] = "residential"
            h["assign_stage"] = stage
            h["_lot"] = l
        pending = rest
    for h in pending:
        unplaced.append(h["id"])
    for l in free:
        l["eligible"] = False
        l["use"] = "garden"
        l["vacant_reason"] = "no household left for this lot (garden / 텃밭)"
    if unplaced:
        C.request("L5/parcels", "households without a parcel (quota loss is never silent)", "household_unplaced",
                  households=len(unplaced))
    return unplaced
