"""Reproducible synthetic sites (spec §4) and failure fixtures.

Domain x,z in [-512, 512], 2 m cells, north = -z, no noise.
G(a,b,s) = exp(-((x-a)^2 + (z-b)^2) / (2 s^2)).
"""
from __future__ import annotations

import hashlib
import json

import numpy as np
from shapely.geometry import LineString, Point, Polygon, box

from . import geometry as Gm
from .model import Road, SiteInput, WaterFeature, diag
from .raster import Grid, rasterize

GRID = Grid(-512.0, -512.0, 2.0, 513, 513)


def _xz():
    return np.meshgrid(GRID.xs(), GRID.zs())


def G(X, Z, a, b, s):
    return np.exp(-((X - a) ** 2 + (Z - b) ** 2) / (2 * s * s))


def terrace_height(X, Z):
    return 4 + 0.004 * Z + 5 * (1 + np.tanh((Z + 80) / 12))


def basin_height(X, Z):
    return terrace_height(X, Z) + 45 * G(X, Z, 0, -200, 140) + 25 * G(X, Z, -240, 0, 100) + 25 * G(X, Z, 240, 0, 100)


def ridge_height(X, Z):
    r = np.sqrt(X * X + Z * Z)
    return 20 + 0.12 * np.abs(X) + 70 * np.exp(-((r - 180) / 65) ** 2)


def estuary_height(X, Z):
    return 0.025 * (160 - X) + 8 * G(X, Z, -160, 0, 140)


def _band_z(z0, width):
    return box(-512, z0 - width / 2, 512, z0 + width / 2)


def _band_x(x0, width, z0=-512, z1=512):
    return box(x0 - width / 2, z0, x0 + width / 2, z1)


def _water(feats, height, const_surface=None):
    """Rasterize water features; surface: constant per feature or 'terrain-1'."""
    mask = np.zeros(GRID.shape, bool)
    surf = np.full(GRID.shape, np.nan)
    fresh = np.zeros(GRID.shape, bool)
    for f, s in feats:
        m = rasterize(GRID, f.area) & ~mask
        mask |= m
        if s == "terrain-1":
            surf[m] = height[m] - 1.0
        else:
            surf[m] = float(s)
        fresh[m] = f.freshwater
    return mask, surf, fresh


def _mk(id_, name, height, feats, roads, preferred, allowed, protected, tier, family,
        crossings=(), axes=(), notes=""):
    mask, surf, fresh = _water(feats, height)
    h = hashlib.sha256(np.ascontiguousarray(height, dtype="<f8").tobytes()).hexdigest()
    manifest = {
        "fixture": id_, "domain": [-512, 512], "cell_m": 2.0, "north_xz": [0, -1],
        "terrain_sha256": h,
        "water": [{"id": f.id, "kind": f.kind, "surface": s, "width_m": f.width_m} for f, s in feats],
        "roads": [{"id": r.id, "coords": Gm.coords_out(r.line.coords)} for r in roads],
        "territory": {k: Gm.to_geojson(v) for k, v in (("preferred", preferred), ("allowed", allowed), ("protected", protected))},
        "notes": notes,
    }
    mh = hashlib.sha256(Gm.canonical_json(manifest).encode()).hexdigest()
    site = SiteInput(
        id=id_, name=name, region="SYNTHETIC", seed=2203, tier=tier, family=family, grid=GRID,
        height=height.astype(np.float64), coverage=np.ones(GRID.shape, bool), vertical_scale=1.0,
        water_mask=mask, water_surface=surf, water_fresh=fresh,
        water_features=[f for f, _ in feats], roads=list(roads), crossings=list(crossings),
        farmland=rasterize(GRID, protected) & ~mask,
        territory={"preferred": preferred, "allowed": allowed, "protected": protected,
                   "sources": {"preferred": "fixture", "allowed": "fixture explicit envelope", "protected": "fixture farmland"},
                   "disagreements": []},
        axes=list(axes), historical_households=None,
        provenance={"input_hashes": {"fixture_manifest": mh, "terrain": h}, "manifest": manifest,
                    "vertical": {"scale": 1.0, "note": "synthetic: game metres = source metres"}},
        diagnostics=[diag("missing_halo", "info", "L0", "synthetic domain is 1024 m; 1 km halo clipped to domain (flow accumulation deferred)")],
        meta={"fixture": True, "notes": notes},
    )
    return site


def _river(id_, area, line, width, fresh=True, kind="river"):
    return WaterFeature(id=id_, kind=kind, freshwater=fresh, area=area, centerline=line, width_m=width)


def terrace():
    X, Z = _xz()
    h = terrace_height(X, Z)
    feats = [(_river("river_n", _band_z(-140, 20), LineString([(-512, -140), (512, -140)]), 20), 3.0)]
    roads = [Road("road_ew", "동서 큰길", "대로", 5.0, LineString([(-512, 10), (512, 10)])),
             Road("road_s", "남쪽 길", "중로", 4.0, LineString([(40, 512), (40, 10)]))]
    pref = box(-200, -60, 200, 240)
    allowed = box(-230, -75, 230, 260)
    prot = box(-512, -130, 512, -95).union(box(260, -40, 512, 300))
    return _mk("syn_terrace", "평탄 하안단구(합성)", h, feats, roads, pref, allowed, prot,
               "medium_eupchi", "plain", notes="flat river terrace; north lowland floods")


def basin(family="plain_hill", id_="syn_basin"):
    X, Z = _xz()
    h = basin_height(X, Z)
    feats = [(_river("river_s", _band_z(180, 20), LineString([(-512, 180), (512, 180)]), 20), 4.0)]
    roads = [Road("road_s", "남쪽 길", "대로", 5.0, LineString([(0, 512), (0, 60)])),
             Road("road_e", "동쪽 길", "중로", 4.0, LineString([(512, 70), (150, 70)]))]
    cross = [{"id": "bridge_s", "type": "다리", "road_id": "road_s", "river_id": "river_s", "xz": [0, 180]}]
    if family == "mountain":
        pref = Point(0, -170).buffer(260, 64)
        prot = box(-512, 150, 512, 512)
    else:
        pref = box(-190, -300, 190, 120)
        prot = box(-512, 150, 512, 512)
    axes = [{"id": "axis_n_s", "bearing": 180.0, "source": "fixture: rear hill (0,-200) → open south", "confidence": "가설", "kind": "jinsan_ansan"}]
    return _mk(id_, "산 등진 분지(합성)" + (" — 산성 변형" if family == "mountain" else ""), h, feats, roads,
               pref, pref, prot, "small_eupchi", family, crossings=cross, axes=axes,
               notes="hill-backed basin, rear hill north")


def ridge(family="mountain"):
    X, Z = _xz()
    h = ridge_height(X, Z)
    feats = [(_river("stream_x0", _band_x(0, 4), LineString([(0, -512), (0, 512)]), 4.0, kind="stream"), "terrain-1")]
    roads = [Road("road_n", "북쪽 고갯길", "중로", 4.0, LineString([(12, -512), (12, 0)])),
             Road("road_s", "남쪽 고갯길", "중로", 4.0, LineString([(-12, 512), (-12, 0)]))]
    pref = Point(0, 0).buffer(300, 64)
    prot = Polygon()
    return _mk("syn_ridge", "가파른 산등성이·골(합성)", h, feats, roads, pref, pref, prot,
               "sanseong_refuge", family, notes="ring ridge r=180 around a small bowl; V valley along x=0; refuge-fortress program (산성 holds garrison/storage, not the 읍치)")


def estuary():
    X, Z = _xz()
    h = estuary_height(X, Z)
    sea = box(160, -512, 512, 512)
    feats = [(WaterFeature("sea_e", "sea", False, sea, None, 0.0), 0.0),
             (_river("river_z0", box(-512, -10, 160, 10), LineString([(-512, 0), (160, 0)]), 20), 0.0)]
    roads = [Road("road_coast", "바닷가 길", "중로", 4.0, LineString([(60, -512), (60, 512)])),
             Road("road_w", "서쪽 길", "소로", 3.0, LineString([(-512, -70), (60, -70)]))]
    cross = [{"id": "bridge_coast", "type": "다리", "road_id": "road_coast", "river_id": "river_z0", "xz": [60, 0]}]
    pref = box(-220, -170, 60, 130)
    prot = box(-512, 30, -230, 512)
    return _mk("syn_estuary", "하구·바닷가 저지(합성)", h, feats, roads, pref, pref, prot,
               "waterside_village", "unwalled", crossings=cross, notes="coastal estuary; sea x>=160 level 0")


# ---------------------------------------------------------------- failure fixtures
def blocked_access():
    X, Z = _xz()
    h = terrace_height(X, Z)
    pit = (np.abs(X - 0) <= 110) & (Z >= 30) & (Z <= 230)
    h = np.where(pit, h - 30.0, h)
    feats = [(_river("river_n", _band_z(-140, 20), LineString([(-512, -140), (512, -140)]), 20), 3.0)]
    roads = [Road("road_ew", "동서 큰길", "대로", 5.0, LineString([(-512, 0), (512, 0)])),
             Road("road_s", "남쪽 길", "중로", 4.0, LineString([(160, 512), (160, 0)]))]
    pref = box(-130, 14, 130, 246)
    return _mk("fail_blocked_access", "실패: 접근 막힘(30 m 벼랑 웅덩이)", h, feats, roads, pref, pref, Polygon(),
               "small_eupchi", "plain", notes="town floor 30 m below a vertical rim; no ≤10% corridor from any gate")


def impossible_civic():
    s = terrace()
    pref = box(-30, 40, 30, 100)
    s.id = "fail_impossible_civic"
    s.name = "실패: 관아 자리 없음(60×60 m 배정)"
    s.territory = dict(s.territory, preferred=pref, allowed=pref, protected=Polygon())
    s.farmland = np.zeros(GRID.shape, bool)
    s.provenance["input_hashes"]["override"] = hashlib.sha256(b"impossible_civic:60x60").hexdigest()
    return s


def water_crossing():
    X, Z = _xz()
    h = terrace_height(X, Z)
    feats = [(_river("river_n", _band_z(-140, 20), LineString([(-512, -140), (512, -140)]), 20), 3.0),
             (_river("river_x140", _band_x(140, 16, -150, 512), LineString([(140, -150), (140, 512)]), 16, kind="river"), "terrain-1")]
    roads = [Road("road_e", "동쪽 길", "대로", 5.0, LineString([(512, 100), (150, 100)]))]
    pref = box(-200, -60, 200, 240)
    return _mk("fail_water_crossing", "실패: 물 건너야 함(건널목 없음)", h, feats, roads, pref, pref, Polygon(),
               "medium_eupchi", "plain", notes="only road arrives east of an unbridged river; civic land is west")


SYNTHETIC = {"syn_terrace": terrace, "syn_basin": basin, "syn_ridge": ridge, "syn_estuary": estuary,
             "syn_basin_sanseong": lambda: basin("mountain", "syn_basin_sanseong")}
FAILURES = {"fail_blocked_access": blocked_access, "fail_impossible_civic": impossible_civic,
            "fail_water_crossing": water_crossing}


def load(name: str) -> SiteInput:
    if name in SYNTHETIC:
        return SYNTHETIC[name]()
    return FAILURES[name]()
