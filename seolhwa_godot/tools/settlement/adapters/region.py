"""Adapter: region_data/<REGION>/ → normalized SiteInput.

Conventions (region.json): pixel (i,j) centre = (x0 + i*cell, z0 + j*cell); rows run +z
(south); 16-bit heights decode y = y_min + v/65535*(y_max - y_min) and are ALREADY the
game heights (height.remap is provenance only — never applied again). River points are
[x, z, y] with per-point `widths`; roads are [x, z(, y)]. landuse.png is a 4 m class grid
with the same origin; it is resampled to the 2 m grid by nearest centre (floor(t+0.5)).
`sea` with kind == "river" (PA_PYEONGYANG) is a freshwater river surface.
Territory precedence: explicit envelope → settlement.core / existing wall → disk of
area_m2 (else radius_m). bbox is never treated as permission. Expansion defaults to 0.
"""
from __future__ import annotations

import hashlib
import json
import math
import os

import numpy as np
import shapely
from PIL import Image
from scipy import ndimage
from shapely.geometry import LineString, Point, Polygon, box, shape

from .. import geometry as G
from ..model import Road, SiteInput, WaterFeature, diag
from ..raster import Grid, rasterize

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "region_data"))


def _sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _remap_slope(remap, y_pre):
    src, dst = remap["src"], remap["dst"]
    for k in range(len(src) - 1):
        if src[k] <= y_pre <= src[k + 1]:
            return (dst[k + 1] - dst[k]) / (src[k + 1] - src[k])
    return 1.0


def _remap_inv(remap, y_game):
    src, dst = remap["src"], remap["dst"]
    for k in range(len(dst) - 1):
        if dst[k] <= y_game <= dst[k + 1]:
            t = (y_game - dst[k]) / (dst[k + 1] - dst[k])
            return src[k] + t * (src[k + 1] - src[k])
    return y_game


def allocation(s: dict, region: dict, envelope=None):
    """(preferred polygon, source label, disagreement notes)."""
    notes = []
    area = s.get("area_m2")
    core = s.get("core")
    bbox = s.get("bbox")
    if envelope is not None:
        return envelope, "explicit_envelope", notes
    for w in region.get("walls", []) or []:
        if w.get("closed") and Polygon(w["points"]).contains(Point(s["x"], s["z"])):
            poly = Polygon(w["points"])
            notes.append(f"existing wall {w['id']} used as allocation")
            return poly, f"existing_wall:{w['id']}", notes
    if core:
        poly = box(core[0], core[1], core[2], core[3])
        if area:
            r = poly.area / area
            notes.append(f"core area {poly.area:.0f} m² vs recorded area_m2 {area:.0f} m² (ratio {r:.2f})")
        if bbox:
            notes.append(f"derived bbox {(bbox[2]-bbox[0]):.0f}×{(bbox[3]-bbox[1]):.0f} m ignored as permission")
        return poly, "settlement.core", notes
    if area:
        r = math.sqrt(area / math.pi)
        if bbox:
            notes.append(f"derived bbox {(bbox[2]-bbox[0]):.0f}×{(bbox[3]-bbox[1]):.0f} m ({(bbox[2]-bbox[0])*(bbox[3]-bbox[1]):.0f} m²) ignored as permission; "
                         f"disk from area_m2 {area:.0f} m² (r={r:.1f} m)")
        if s.get("radius_m"):
            notes.append(f"radius_m {s['radius_m']} vs area-equivalent radius {r:.1f}")
        return Point(s["x"], s["z"]).buffer(r, 64), "area_m2_disk", notes
    r = float(s.get("radius_m", 40))
    return Point(s["x"], s["z"]).buffer(r, 64), "radius_m_disk", notes


def tier_for(s: dict, rules) -> str:
    m = rules.mapping()
    t = s.get("type")
    tb = m["tier_by_type"].get(t)
    if isinstance(tb, dict):
        return tb.get(s.get("size", "M"), "small_eupchi")
    if isinstance(tb, str):
        return tb
    arch = (s.get("profile") or {}).get("archetype", "plain")
    return m["village_by_archetype"].get(arch, "minchon")


def load(region_id: str, settlement_id: str, rules, *, envelope=None, allowed=None, family=None,
         seed: int = 2203) -> SiteInput:
    rdir = os.path.join(ROOT, region_id)
    rpath = os.path.join(rdir, "region.json")
    with open(rpath, encoding="utf-8") as f:
        region = json.load(f)
    hs = {"region.json": _sha(rpath)}
    sett = {s["id"]: s for s in region["settlements"]}
    if settlement_id not in sett:
        raise KeyError(f"{settlement_id} not in {region_id}")
    s = sett[settlement_id]
    diags = []
    pref, src, notes = allocation(s, region, envelope)
    allowed_poly = allowed if allowed is not None else pref
    if allowed is None:
        diags.append(diag("expansion_zero", "info", "L1", "no explicit allowed envelope: allowed = preferred (expansion 0)"))
    for n in notes:
        diags.append(diag("allocation_disagreement", "info", "L1", n))
    # ---------------- height window
    hm = region["height"]
    halo = rules.p("site.halo_m")
    xmin, zmin, xmax, zmax = allowed_poly.bounds
    cell = float(hm["cell"])
    i0 = max(0, int(math.floor((xmin - halo - hm["x0"]) / cell)))
    j0 = max(0, int(math.floor((zmin - halo - hm["z0"]) / cell)))
    i1 = min(hm["w"], int(math.ceil((xmax + halo - hm["x0"]) / cell)) + 1)
    j1 = min(hm["h"], int(math.ceil((zmax + halo - hm["z0"]) / cell)) + 1)
    clipped = (i0 == 0 or j0 == 0 or i1 == hm["w"] or j1 == hm["h"])
    hpath = os.path.join(rdir, hm["file"])
    hs[hm["file"]] = _sha(hpath)
    im = Image.open(hpath)
    raw = np.array(im)
    if raw.shape != (hm["h"], hm["w"]):
        raise ValueError(f"height.png shape {raw.shape} != metadata {(hm['h'], hm['w'])}")
    raw = raw[j0:j1, i0:i1].astype(np.float64)
    height = hm["y_min"] + raw / 65535.0 * (hm["y_max"] - hm["y_min"])
    grid = Grid(hm["x0"] + i0 * cell, hm["z0"] + j0 * cell, cell, i1 - i0, j1 - j0)
    if clipped:
        diags.append(diag("missing_halo", "warning", "L0", "1 km halo clipped by region extent; confidence lowered"))
    # ---------------- vertical scale (source metres → game metres near the floor)
    K = region["projection"]["K"]
    remap = hm.get("remap")
    pm = rasterize(grid, pref)
    y_floor = float(np.median(height[pm])) if pm.any() else float(np.median(height))
    if remap:
        y_pre = _remap_inv(remap, y_floor)
        vscale = K * _remap_slope(remap, y_pre)
    else:
        vscale = K
    vert = {"K": K, "remap": remap, "floor_y": round(y_floor, 2), "scale": round(vscale, 4),
            "note": "flood stages are source metres × scale; heights are used as decoded (remap not reapplied)"}
    # ---------------- landuse resample (nearest centre)
    lm = region["landuse"]
    lpath = os.path.join(rdir, lm["file"])
    hs[lm["file"]] = _sha(lpath)
    lu = np.array(Image.open(lpath))
    xs = grid.xs()
    zs = grid.zs()
    li = np.floor((xs - lm["x0"]) / lm["cell"] + 0.5).astype(int)
    lj = np.floor((zs - lm["z0"]) / lm["cell"] + 0.5).astype(int)
    valid_i = (li >= 0) & (li < lm["w"])
    valid_j = (lj >= 0) & (lj < lm["h"])
    lu2 = np.full(grid.shape, 255, dtype=np.uint8)
    lu2[np.ix_(valid_j, valid_i)] = lu[np.ix_(lj[valid_j], li[valid_i])]
    coverage = lu2 != 255
    wclass = rules.p("water.landuse_water_class")
    farm = np.isin(lu2, rules.p("agriculture.farmland_classes"))
    # ---------------- water
    gb = box(*grid.bounds())
    feats = []
    water = np.zeros(grid.shape, bool)
    surf = np.full(grid.shape, np.nan)
    fresh = np.zeros(grid.shape, bool)
    river_cells = np.zeros(grid.shape, bool)
    vx_mask = np.zeros(grid.shape, bool)
    vx_val = np.zeros(grid.shape)
    for r in region.get("rivers", []):
        pts = r["points"]
        ws = r.get("widths") or [r.get("width_m", 2.5)] * len(pts)
        line = LineString([(p[0], p[1]) for p in pts])
        if not line.intersects(gb.buffer(50)):
            continue
        segs = []
        for k in range(len(pts) - 1):
            a, b = pts[k], pts[k + 1]
            w = max(ws[k], ws[k + 1])
            segs.append(LineString([(a[0], a[1]), (b[0], b[1])]).buffer(w / 2, cap_style="round"))
        area = G.polygonal(shapely.union_all(segs)).intersection(gb)
        m = rasterize(grid, area)
        river_cells |= m
        for p in pts:
            i, j = grid.ij(p[0], p[1])
            if grid.inside(i, j):
                vx_mask[j, i] = True
                vx_val[j, i] = p[2]
        clip = line.intersection(gb)
        if clip.is_empty:
            continue
        cl = max(getattr(clip, "geoms", [clip]), key=lambda g: g.length) if clip.geom_type != "LineString" else clip
        wmed = float(np.median(ws))
        feats.append(WaterFeature(id=r["id"], kind="river" if wmed >= 6 else "stream", freshwater=True,
                                  area=area, centerline=cl, width_m=round(wmed, 2),
                                  surface_note=f"points y; grade {r.get('grade')}"))
    lakes = region.get("lakes", []) or []
    lake_mask = np.zeros(grid.shape, bool)
    for lk in lakes:
        poly = Polygon(lk["outline"])
        if not poly.intersects(gb):
            continue
        m = rasterize(grid, poly)
        lake_mask |= m
        surf[m] = lk["y"]
        fresh[m] = True
        feats.append(WaterFeature(id=lk["id"], kind="lake", freshwater=True, area=poly.intersection(gb)))
    lu_water = lu2 == wclass
    if vx_mask.any():
        d, (jj, ii) = ndimage.distance_transform_edt(~vx_mask, return_indices=True)
        near = vx_val[jj, ii]
        dist_m = d * cell
    else:
        near = np.full(grid.shape, np.nan)
        dist_m = np.full(grid.shape, np.inf)
    rc = (river_cells | (lu_water & (dist_m <= 30.0))) & ~lake_mask
    surf[rc] = near[rc]
    fresh[rc] = True
    sea = region.get("sea")
    rest = lu_water & ~rc & ~lake_mask
    if sea and rest.any():
        surf[rest] = sea["y"]
        is_river = sea.get("kind") == "river"
        fresh[rest] = is_river
        feats.append(WaterFeature(id="sea", kind="sea_river" if is_river else "sea", freshwater=is_river,
                                  area=Polygon(), surface_note=sea.get("name", "")))
        diags.append(diag("coastal_static_level", "warning" if not is_river else "info", "L0",
                          "large water body treated as a static level; tide/surge scenarios not available"
                          if not is_river else "sea.kind=river: large river surface treated as freshwater static level"))
    elif rest.any():
        diags.append(diag("water_surface_missing", "warning", "L0", "landuse water cells without a mapped surface",
                          cells=int(rest.sum())))
    water = rc | lake_mask | lu_water
    # ---------------- roads / crossings
    roads = []
    for rd in region.get("roads", []):
        line = LineString([(p[0], p[1]) for p in rd["points"]])
        if not line.intersects(gb):
            continue
        clip = line.intersection(gb)
        for n_, g in enumerate(getattr(clip, "geoms", [clip])):
            if g.geom_type != "LineString" or g.length < 1:
                continue
            roads.append(Road(id=rd["id"] if n_ == 0 else f"{rd['id']}#{n_}", name=rd.get("name", rd["id"]),
                              klass=rd.get("class", ""), width_m=float(rd.get("width_m", 3.0)), line=g))
    crossings = [{"id": c["id"], "type": c.get("type", ""), "road_id": c.get("road_id"), "river_id": c.get("river_id"),
                  "xz": [c["x"], c["z"]]} for c in region.get("crossings", [])
                 if gb.contains(Point(c["x"], c["z"]))]
    # ---------------- neighbours, axes
    neighbours = []
    for o in region["settlements"]:
        if o["id"] == settlement_id:
            continue
        if not gb.contains(Point(o["x"], o["z"])):
            continue
        g, osrc, _ = allocation(o, region)
        if g.intersects(gb):
            neighbours.append({"id": o["id"], "geom": g, "source": osrc})
    axes = []
    for ax in region.get("axes", []) or []:
        c = ax.get("center", {})
        if math.hypot(c.get("x", 1e9) - s["x"], c.get("z", 1e9) - s["z"]) > 400:
            continue
        j, a = ax.get("jinsan"), ax.get("ansan")
        if j and a:
            b = G.bearing_of(a["x"] - j["x"], a["z"] - j["z"])
            axes.append({"id": f"axis-{settlement_id}", "bearing": round(b, 2), "kind": "jinsan_ansan",
                         "source": f"region.axes: {j.get('name')} → {a.get('name')}",
                         "confidence": f"jinsan {j.get('confidence')} / ansan {a.get('confidence')}"})
    tier = tier_for(s, rules)
    fam = family or ("auto" if s.get("type") == "읍성" else "unwalled")
    inp = SiteInput(
        id=settlement_id, name=s.get("name", settlement_id), region=region_id, seed=seed, tier=tier, family=fam,
        grid=grid, height=height, coverage=coverage, vertical_scale=vscale,
        water_mask=water & coverage, water_surface=surf, water_fresh=fresh,
        water_features=feats, roads=roads, crossings=crossings, farmland=farm & coverage,
        territory={"preferred": pref, "allowed": allowed_poly, "protected": Polygon(),
                   "sources": {"preferred": src, "allowed": "explicit" if allowed is not None else "= preferred (expansion 0)",
                               "protected": "farmland outside preferred ∪ neighbouring allocations"},
                   "disagreements": notes},
        locks=[], axes=axes, neighbours=neighbours, historical_households=None,
        provenance={"input_hashes": hs, "vertical": vert, "height_window_px": [i0, j0, i1, j1],
                    "settlement_record": {k: s.get(k) for k in ("type", "size", "x", "z", "radius_m", "area_m2", "core", "bbox")},
                    "archetype": (s.get("profile") or {}).get("archetype")},
        diagnostics=diags, meta={"fixture": False})
    return inp
