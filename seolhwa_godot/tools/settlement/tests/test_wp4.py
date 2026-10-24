"""WP4 terrain · water layer: ridges/saddles/catchments, ground classes, reaches & stage states,
crossings per state, route support/drainage, region natural profile status rules, determinism."""
import filecmp
import json

import numpy as np
import pytest

from tools.settlement import cli, contract as C, fixtures, geometry as G, site, terrain, water
from tools.settlement.rules import Rules

R = Rules()
G.set_grid(R.p("geometry.grid"))


@pytest.fixture(scope="module")
def ridge_run(tmp_path_factory):
    d = tmp_path_factory.mktemp("wp4r")
    p = cli.run(fixtures.load("syn_ridge"), R, str(d))
    layer = json.load(open(d / "terrain-water.json", encoding="utf-8"))
    return p, layer, d


def _chk(layer):
    return {c["id"]: c for c in layer["checks"]}


def test_ridge_saddles_and_catchments(ridge_run):
    _, layer, _ = ridge_run
    T = layer["terrain"]
    # ring ridge r=180 has its two low points at (0, ±180): computed 안부 there
    near = [s for s in T["saddles"] if abs(s["xz"][0]) < 20 and abs(abs(s["xz"][1]) - 180) < 20]
    assert len(near) == 2, [s["xz"] for s in T["saddles"]]
    assert all(s["ridge"] and s["rise_m"][0] >= R.p("terrain.saddle_min_rise_m") for s in near)
    assert T["summary"]["ridges"]["main"] >= 2
    # the closed bowl is an internal sink catchment, not filled over the saddle
    assert any(c["outlet_kind"] == "sink" for c in T["catchments"])


def test_v_checks_ridge(ridge_run):
    p, layer, _ = ridge_run
    c = _chk(layer)
    assert c["WP4.layer"]["pass"] is True, c["WP4.layer"]["detail"]
    for k in ("V01", "V02", "V03", "V64", "V65", "V66", "V67"):
        assert c[k]["pass"] is True, (k, c[k]["detail"])
    # the bowl stream (V-shaped surface in a closed basin) is a marked exception, not a silent pass
    assert c["V65"]["detail"]["marked_exceptions"]
    assert any(v["id"] == "WP4.layer" and v["pass"] for v in p["validation"])


def test_stage_states_single_source(ridge_run):
    p, layer, _ = ridge_run
    keys = [(s["key"], s["offset"]) for s in sorted(R.p("water.stage_states"), key=lambda s: s["offset"])]
    for r in layer["water"]["reaches"]:
        assert [(s["key"], s["offset_world_m"]) for s in r["states"]] == keys
    assert [(s["key"], s["offset_world_m"]) for s in layer["water"]["stage_impacts"]] == keys
    rp = [(s["key"], s["offset"]) for s in sorted(p["region_profile"]["water_states"]["states"], key=lambda s: s["offset"])]
    assert rp == keys
    # plan water features point at their reaches
    wf = {w["id"]: w for w in p["site"]["water_features"]}
    assert all(wf[r["feature"]]["reaches"] for r in layer["water"]["reaches"])


def test_route_support_drainage_filled(ridge_run):
    p, _, _ = ridge_run
    for rt in p["inputs"]["movement_livelihood"]["routes"]:
        lp = rt["long_profile"]
        assert lp["ascent_m"] > 0 and len(lp["chainage"]) == len(lp["y"])
        assert rt["width_section"]["sections"]
        assert rt["divide_crossings"] and rt["divide_crossings"][0]["saddle"]
        assert all(m["reasons"] or m["passable"] for m in rt["modes"])
        assert C.validate("Route", rt) == []


def test_terrace_reach_alluvial_and_crossing_states(tmp_path):
    p = cli.run(fixtures.load("syn_basin"), R, str(tmp_path / "b"))
    layer = json.load(open(tmp_path / "b" / "terrain-water.json", encoding="utf-8"))
    xs = layer["water"]["crossings"]
    assert xs and xs[0]["class"] == "bridge" and xs[0]["mapped"]
    st = {s["key"]: s["modes"]["foot"]["passable"] for s in xs[0]["states"]}
    assert st["normal"] is True
    for r in layer["water"]["reaches"]:
        assert all(v["fraction"]["value"] is None for v in r["bed_mix"]["components"].values())  # no invented mix
        assert r["bed_mix"]["basis"]["not_from"]
    assert _chk(layer)["V67"]["pass"] is True


def test_ground_classes_do_not_read_rock_type():
    inp = fixtures.load("syn_ridge")
    A = site.analyze(inp, R)
    g1 = A.terrain.ground.copy()
    T2 = terrain.build(inp, A, R)
    assert np.array_equal(g1, T2.ground)
    assert "rock" not in " ".join(terrain.CLASSIFY_INPUTS).replace("landuse rock/bar class", "")


def test_natural_profile_status_rules():
    nat = C.natural_profile("JL_NAMWON_UNBONG")
    f = nat["fields"]
    assert f["river.sections"]["status"] == "unknown" and f["river.sections"]["value"] is None
    for k, v in f.items():
        if v["status"] == "confirmed":
            assert v["grade"] in ("A", "B") and v["sources"], k
    assert C.natural_profile(None)["status"] == "unknown"
    # every region file entry follows the rule
    for reg in ("GG_HANYANG", "GS_GYEONGJU", "GW_GANGNEUNG", "HG_HAMHEUNG", "HH_HWANGJU", "JJ_JEJU", "PA_PYEONGYANG"):
        for k, v in C.natural_profile(reg)["fields"].items():
            assert v["status"] in ("confirmed", "proposed", "unknown")
            if v["status"] == "confirmed":
                assert v["grade"] in ("A", "B") and v["sources"], (reg, k)


def test_layer_byte_identical(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    cli.run(fixtures.load("syn_estuary"), R, str(a))
    cli.run(fixtures.load("syn_estuary"), R, str(b))
    for f in ("terrain-water.json", "terrain-fields.npz", "03-terrain.svg", "04-water.svg", "05-routes.svg", "plan.json"):
        assert filecmp.cmp(a / f, b / f, shallow=False), f
