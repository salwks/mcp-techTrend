"""Normalized input model shared by adapters and fixtures."""
from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from .raster import Grid


@dataclass
class WaterFeature:
    id: str
    kind: str            # river | stream | lake | sea | sea_river
    freshwater: bool
    area: object         # shapely polygonal water surface (may be empty)
    centerline: object = None   # LineString for channels
    width_m: float = 0.0
    surface_note: str = ""
    points3: list | None = None   # WP4: mapped [x, z, surface_y] points, upstream → downstream as given
    widths: list | None = None    # WP4: per-point widths (world m) when mapped
    attrs: dict = field(default_factory=dict)  # WP4: name, grade, flows_to, parent, catchment_km2, source, confidence


@dataclass
class Road:
    id: str
    name: str
    klass: str
    width_m: float
    line: object         # LineString


@dataclass
class SiteInput:
    id: str
    name: str
    region: str
    seed: int
    tier: str
    family: str          # plain | plain_hill | mountain | unwalled
    grid: Grid
    height: np.ndarray   # game y (already remapped heights; never remapped again)
    coverage: np.ndarray  # bool: data present
    vertical_scale: float  # game metres per source metre near the settlement floor
    water_mask: np.ndarray
    water_surface: np.ndarray   # NaN where unknown / not water
    water_fresh: np.ndarray     # bool: freshwater cell
    water_features: list = field(default_factory=list)
    roads: list = field(default_factory=list)
    crossings: list = field(default_factory=list)
    farmland: np.ndarray | None = None
    territory: dict = field(default_factory=dict)   # preferred / allowed / protected(+sources)
    locks: list = field(default_factory=list)
    axes: list = field(default_factory=list)        # {id, bearing, source, confidence, kind}
    neighbours: list = field(default_factory=list)  # {id, geom}
    historical_households: int | None = None
    provenance: dict = field(default_factory=dict)
    diagnostics: list = field(default_factory=list)
    meta: dict = field(default_factory=dict)
    flood_exempt: np.ndarray | None = None  # water cells that are not flood sources (springs, summit ponds)


def diag(code: str, severity: str, layer: str, message: str, **data) -> dict:
    """Diagnostic record (severity: error | warning | info)."""
    d = {"code": code, "severity": severity, "layer": layer, "message": message}
    if data:
        d["data"] = data
    return d
