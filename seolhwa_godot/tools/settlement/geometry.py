"""Vector geometry helpers: precision grid, canonical ordering, stable ids.

World coordinates are (x, z) metres; north is -z, east is +x. Bearings are
compass degrees clockwise from north, so bearing b points along (sin b, -cos b).
Canonical rings are counter-clockwise in the (x, z) math sense and start at the
northern-most vertex (min z, then min x).
"""
from __future__ import annotations

import hashlib
import json
import math

import numpy as np
import shapely
from shapely.geometry import (LineString, MultiLineString, MultiPolygon, Point,
                              Polygon, box, mapping)
from shapely.geometry.polygon import orient
from shapely.ops import substring

GRID = 0.05  # overwritten from rules by set_grid()


def set_grid(grid: float) -> None:
    global GRID
    GRID = float(grid)


class GeometryError(ValueError):
    pass


def snap(geom, grid: float | None = None, *, keep_lines: bool = False):
    """Reduce precision to the geometry grid and validate (never a silent repair)."""
    g = GRID if grid is None else grid
    if geom is None or geom.is_empty:
        return geom
    out = shapely.set_precision(geom, g, mode="valid_output")
    if not out.is_valid:
        raise GeometryError("invalid geometry after precision reduction")
    if not keep_lines and geom.geom_type in ("Polygon", "MultiPolygon"):
        out = polygonal(out)
    return out


def unsnap(geom):
    """Drop a stored precision model (lossless for on-grid vertices) → floating overlays."""
    if geom is None or geom.is_empty:
        return geom
    return shapely.set_precision(geom, 0.0)


def polygonal(geom):
    """Return only the polygonal part of a geometry (MultiPolygon or Polygon or empty)."""
    if geom is None or geom.is_empty:
        return Polygon()
    if geom.geom_type in ("Polygon", "MultiPolygon"):
        return geom
    polys = []
    for g in getattr(geom, "geoms", []):
        if g.geom_type == "Polygon" and not g.is_empty:
            polys.append(g)
        elif g.geom_type == "MultiPolygon":
            polys.extend(g.geoms)
    if not polys:
        return Polygon()
    return polys[0] if len(polys) == 1 else MultiPolygon(polys)


def parts(geom) -> list:
    """Polygon components in canonical order (largest area first, then north-west)."""
    geom = polygonal(geom)
    if geom.is_empty:
        return []
    ps = [geom] if geom.geom_type == "Polygon" else list(geom.geoms)
    ps = [p for p in ps if not p.is_empty]
    ps.sort(key=lambda p: (-round(p.area, 3), round(p.bounds[1], 3), round(p.bounds[0], 3)))
    return ps


def _rotate_ring(coords: list) -> list:
    pts = coords[:-1]
    k = min(range(len(pts)), key=lambda i: (round(pts[i][1], 4), round(pts[i][0], 4)))
    pts = pts[k:] + pts[:k]
    return pts + [pts[0]]


def canon_polygon(p: Polygon) -> Polygon:
    p = orient(p, 1.0)
    ext = _rotate_ring(list(p.exterior.coords))
    holes = []
    for r in p.interiors:
        holes.append(_rotate_ring(list(r.coords)))
    holes.sort(key=lambda r: (min(c[1] for c in r), min(c[0] for c in r)))
    return Polygon(ext, holes)


def canon(geom):
    """Canonical polygon/multipolygon (orientation, start vertex, component order)."""
    geom = polygonal(geom)
    if geom.is_empty:
        return geom
    ps = [canon_polygon(p) for p in parts(geom)]
    return ps[0] if len(ps) == 1 else MultiPolygon(ps)


def canon_ring(ring_poly: Polygon) -> LineString:
    """Canonical closed ring LineString of a polygon's exterior."""
    p = canon_polygon(Polygon(ring_poly.exterior.coords))
    return LineString(p.exterior.coords)


def r2(v: float) -> float:
    """Round a coordinate onto the output grid (0.05 m) as a short decimal."""
    q = round(round(v / GRID) * GRID, 2)
    return 0.0 if q == 0 else q


def coords_out(coords) -> list:
    return [[r2(c[0]), r2(c[1])] for c in coords]


def to_geojson(geom) -> dict:
    """GeoJSON dict with coordinates snapped to the grid."""
    if geom is None or geom.is_empty:
        return {"type": "GeometryCollection", "geometries": []}
    t = geom.geom_type
    if t == "Polygon":
        g = canon_polygon(geom)
        return {"type": "Polygon", "coordinates": [coords_out(g.exterior.coords)] +
                [coords_out(r.coords) for r in g.interiors]}
    if t == "MultiPolygon":
        g = canon(geom)
        if g.geom_type == "Polygon":
            return to_geojson(g)
        return {"type": "MultiPolygon", "coordinates": [
            [coords_out(p.exterior.coords)] + [coords_out(r.coords) for r in p.interiors]
            for p in g.geoms]}
    if t == "LineString":
        return {"type": "LineString", "coordinates": coords_out(geom.coords)}
    if t == "MultiLineString":
        return {"type": "MultiLineString", "coordinates": [coords_out(l.coords) for l in geom.geoms]}
    if t == "Point":
        return {"type": "Point", "coordinates": [r2(geom.x), r2(geom.y)]}
    m = mapping(geom)
    return json.loads(json.dumps(m))


def from_geojson(d: dict):
    from shapely.geometry import shape
    return shape(d)


def canonical_json(obj) -> str:
    return json.dumps(obj, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def stable_id(kind: str, obj) -> str:
    """Content-derived id: kind-sha1(canonical json)[:10]."""
    if hasattr(obj, "geom_type"):
        obj = to_geojson(obj)
    h = hashlib.sha1(canonical_json(obj).encode("utf-8")).hexdigest()[:10]
    return f"{kind}-{h}"


def bearing_vec(bearing_deg: float) -> tuple[float, float]:
    b = math.radians(bearing_deg)
    return math.sin(b), -math.cos(b)


def bearing_of(dx: float, dz: float) -> float:
    """Compass bearing (deg, [0,360)) of a world vector."""
    b = math.degrees(math.atan2(dx, -dz)) % 360.0
    return 0.0 if abs(b - 360.0) < 1e-9 else b


def angle_diff(a: float, b: float, period: float = 360.0) -> float:
    d = (a - b) % period
    return min(d, period - d)


def oriented_rect(cx: float, cz: float, width: float, depth: float, bearing: float,
                  chamfer: float = 0.0) -> Polygon:
    """Rectangle centred on (cx,cz); depth runs along the bearing (front = bearing side).

    chamfer > 0 cuts each corner by that length (octagon-like chamfered rectangle).
    """
    fx, fz = bearing_vec(bearing)          # forward
    rx, rz = -fz, fx                       # right-hand (bearing + 90)
    hw, hd = width / 2.0, depth / 2.0
    if chamfer <= 0:
        local = [(-hw, hd), (hw, hd), (hw, -hd), (-hw, -hd)]
    else:
        c = min(chamfer, hw * 0.9, hd * 0.9)
        local = [(-hw + c, hd), (hw - c, hd), (hw, hd - c), (hw, -hd + c),
                 (hw - c, -hd), (-hw + c, -hd), (-hw, -hd + c), (-hw, hd - c)]
    pts = [(cx + u * rx + v * fx, cz + u * rz + v * fz) for u, v in local]
    return Polygon(pts)


def front_strip(cx: float, cz: float, width: float, depth: float, bearing: float,
                clearance: float) -> Polygon:
    """Entrance clearance strip in front of an oriented rectangle."""
    fx, fz = bearing_vec(bearing)
    off = depth / 2.0 + clearance / 2.0
    return oriented_rect(cx + fx * off, cz + fz * off, width * 0.6, clearance, bearing)


def front_point(cx, cz, depth, bearing, extra=0.0):
    fx, fz = bearing_vec(bearing)
    return cx + fx * (depth / 2.0 + extra), cz + fz * (depth / 2.0 + extra)


def iou(a, b) -> float:
    u = a.union(b).area
    return a.intersection(b).area / u if u > 0 else 0.0


def chainage(ring: LineString, x: float, z: float) -> float:
    return float(ring.project(Point(x, z)))


def ring_interval(ring: LineString, s0: float, s1: float) -> LineString:
    """Sub-line of a closed ring from s0 to s1 (wrapping if s1 < s0)."""
    L = ring.length
    s0 %= L
    s1 %= L
    if s1 >= s0:
        return substring(ring, s0, s1)
    a = substring(ring, s0, L)
    b = substring(ring, 0, s1)
    return LineString(list(a.coords) + list(b.coords)[1:])


def interval_overlap(a: tuple[float, float], b: tuple[float, float], L: float) -> float:
    """Overlap length of two chainage intervals on a ring of length L (handles wrap)."""
    def segs(iv):
        s0, s1 = iv[0] % L, iv[1] % L
        return [(s0, s1)] if s1 >= s0 else [(s0, L), (0.0, s1)]
    tot = 0.0
    for p in segs(a):
        for q in segs(b):
            tot += max(0.0, min(p[1], q[1]) - max(p[0], q[0]))
    return tot


def isoperimetric(geom) -> float:
    P = geom.length
    return 4 * math.pi * geom.area / (P * P) if P > 0 else 0.0


def simplify_ring_polygon(p: Polygon, tol: float) -> Polygon:
    q = p.simplify(tol, preserve_topology=True)
    return polygonal(q) if not q.is_empty else p


def largest(geom):
    ps = parts(geom)
    return ps[0] if ps else Polygon()


def line_crossings(line: LineString, ring: LineString) -> list[tuple[float, float]]:
    """Intersection points between a polyline and a ring, sorted by along-line distance."""
    inter = line.intersection(ring)
    pts = []
    if inter.is_empty:
        return pts
    geoms = getattr(inter, "geoms", [inter])
    for g in geoms:
        if g.geom_type == "Point":
            pts.append((g.x, g.y))
        elif g.geom_type in ("LineString", "MultiLineString"):
            c = g.centroid
            pts.append((c.x, c.y))
    pts.sort(key=lambda p: line.project(Point(p)))
    out = []
    for p in pts:
        if not out or math.hypot(p[0] - out[-1][0], p[1] - out[-1][1]) > 0.5:
            out.append(p)
    return out


__all__ = [n for n in dir() if not n.startswith("_")] + ["box", "Point", "Polygon",
                                                          "LineString", "MultiPolygon",
                                                          "MultiLineString", "np"]
