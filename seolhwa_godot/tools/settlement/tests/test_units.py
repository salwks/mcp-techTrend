"""Fast unit checks: fixtures, geometry conventions, program arithmetic, ledger additivity."""
import math

import numpy as np
import pytest
import shapely
from shapely.geometry import Point, Polygon, box

from tools.settlement import fixtures, geometry as G, program as P, site
from tools.settlement.rules import Rules

R = Rules()
G.set_grid(R.p("geometry.grid"))


def test_rules_metadata_complete():
    for k, v in R.data["parameters"].items():
        assert {"value", "unit", "source", "confidence", "kind"} <= set(v), k


@pytest.mark.parametrize("name,fn,pts", [
    ("syn_terrace", fixtures.terrace_height, [(0, 0), (100, -140), (-512, 512)]),
    ("syn_basin", fixtures.basin_height, [(0, -200), (240, 0)]),
    ("syn_ridge", fixtures.ridge_height, [(180, 0), (0, 0), (0, 180)]),
    ("syn_estuary", fixtures.estuary_height, [(-160, 0), (160, 20)]),
])
def test_fixture_terrain_matches_spec(name, fn, pts):
    s = fixtures.load(name)
    for x, z in pts:
        i, j = s.grid.ij(x, z)
        assert abs(s.height[j, i] - fn(np.array([[x]], float), np.array([[z]], float))[0, 0]) < 1e-9
    # domain and cell exactly as spec §4
    assert (s.grid.x0, s.grid.z0, s.grid.cell, s.grid.nx) == (-512.0, -512.0, 2.0, 513)
    assert len(s.roads) == 2


def test_fixture_manifest_stable():
    a = fixtures.load("syn_basin").provenance["input_hashes"]
    b = fixtures.load("syn_basin").provenance["input_hashes"]
    assert a == b


def test_bearing_convention():
    assert G.bearing_of(0, -1) == 0.0          # north = -z
    assert abs(G.bearing_of(1, 0) - 90) < 1e-9  # east = +x
    dx, dz = G.bearing_vec(180)
    assert abs(dx) < 1e-9 and abs(dz - 1) < 1e-9


def test_canonical_ring_ccw_north_start():
    p = Polygon([(0, 0), (10, 0), (10, 10), (0, 10)])
    r = G.canon_ring(p)
    assert Polygon(r.coords).exterior.is_ccw
    assert r.coords[0][1] == 0.0


def test_interval_overlap_wraps():
    assert G.interval_overlap((95, 105), (0, 3), 100) == pytest.approx(3)
    assert G.interval_overlap((10, 20), (30, 40), 100) == 0


def test_largest_remainder_exact():
    c = P.largest_remainder({"elite": .07, "specialist": .18, "ordinary": .75}, 37, P.CLASS_ORDER)
    assert sum(c.values()) == 37
    for k, s in {"elite": .07, "specialist": .18, "ordinary": .75}.items():
        assert abs(c[k] - 37 * s) < 1


def test_scale_applied_once():
    prof = R.profile("medium_eupchi")
    pa = P.parcel_areas(prof, R)
    assert pa["ordinary"] == pytest.approx(350 * 1.44)
    for inst in P.institutions(prof, R):
        for v in inst["variants"].values():
            assert v["area_m2"] == pytest.approx(v["hist_area_m2"] * 1.44, abs=0.05)


def test_households_fit_components():
    prof = R.profile("minchon")
    hh = P.solve_households([("c1", 2000.0), ("c2", 500.0)], prof, R)
    a = P.parcel_areas(prof, R)
    for cid, cap in (("c1", 2000.0), ("c2", 500.0)):
        used = sum(hh["by_component"][cid][c] * a[c] for c in a)
        assert used <= cap + 1e-9


def test_overlay_additivity_regression():
    """set_precision stores a precision model; overlays must run in floating precision."""
    t = shapely.set_precision(Point(0, 0).buffer(300, 64), 0.05)
    t0 = G.unsnap(t)
    b = box(-3, -513, 3, 513)
    assert abs(t0.intersection(b).area + t0.difference(b).area - t0.area) < 1e-6


def test_layer0_probes_terrace():
    s = fixtures.load("syn_terrace")
    A = site.analyze(s, R)
    i, j = A.win.ij(0, 200)
    exp = math.degrees(math.atan(0.004 + 5 / 12 * (1 - math.tanh((200 + 80) / 12) ** 2)))
    assert abs(A.slope[j, i] - exp) < 0.05
    # river surface 3, lowland y≈3.44 near z=-140: the +0.5 game-m stage floods next to the river
    i, j = A.win.ij(0, -128)
    assert A.floods[0.5][j, i]
    assert not A.floods[3.0][A.win.ij(0, 100)[1], A.win.ij(0, 100)[0]]


def test_packing_exact_codex_case():
    """Codex review reproduction: greedy gave 7, exact packing fits 8."""
    hh = P.solve_households([("c1", 2520.0), ("c2", 2304.0)], R.profile("small_eupchi"), R)
    assert hh["N"] == 8
