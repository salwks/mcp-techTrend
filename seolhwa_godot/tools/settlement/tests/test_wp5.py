"""WP5 Layers 3–5: districts, streets & water network, blocks and shared-edge parcels.

Unit tests (exact splits, frontage widths, half-edge twins) plus two end-to-end bakes:
* syn_terrace_locked — walled town with story locks: invariants, every household once, locks are
  immutable faces, access, edge attributes for WP6, Parcel contract.
* syn_stream — stream through the town (bridge-failure fixture): carved vs mapped width flagged,
  ford riffle section, Layer-2 skew crossing reported as a revision request (never hidden).
"""
import json

import pytest
from shapely.geometry import LineString, Polygon, box

from tools.settlement import cli, contract as Ct, fixtures, geometry as G, parcels as PA, subdivision as SB
from tools.settlement.rules import Rules

R = Rules()
G.set_grid(R.p("geometry.grid"))


# ------------------------------------------------------------------ units
def test_split_poly_is_exact():
    sq = box(0, 0, 40, 30)
    cuts = [LineString([(10, -1), (10, 31)]), LineString([(25, -1), (25, 31)]), LineString([(-1, 20), (41, 20)])]
    ps = PA.split_poly(sq, cuts)
    assert len(ps) == 6
    assert abs(sum(p.area for p in ps) - sq.area) < 1e-6
    for i, a in enumerate(ps):
        for b in ps[i + 1:]:
            assert a.intersection(b).area < 1e-9


def test_frontage_widths_cover_run_exactly():
    import random
    for L, lo, hi in ((97.3, 7.2, 16.8), (40.0, 12.0, 24.0), (13.0, 7.2, 16.8), (250.0, 21.6, 42.0)):
        w = PA.widths(random.Random(7), L, lo, hi)
        assert abs(sum(w) - L) < 1e-9
        if L >= lo:
            assert all(lo - 1e-6 <= x <= hi + 1e-6 for x in w), (L, w)


def test_subdivision_shared_half_edges():
    faces = [{"id": "a", "kind": "parcel", "geom": box(0, 0, 10, 10)},
             {"id": "b", "kind": "parcel", "geom": box(10, 0, 20, 10)},
             {"id": "c", "kind": "parcel", "geom": box(0, 10, 20, 20).difference(box(8, 13, 12, 17))},
             {"id": "d", "kind": "lock", "geom": box(8, 13, 12, 17)}]
    dom = box(0, 0, 20, 20)
    sub = SB.build(None, faces, dom)
    assert sub["diagnostics"]["unassigned_pieces"] == 0
    lines = {e["id"]: e["_line"] for e in sub["edges"]}
    use = {}
    for f in sub["faces"]:
        for ring in f["rings"]:
            for h in ring:
                use.setdefault(h, []).append(f["id"])
    for e in sub["edges"]:
        for side, sgn in (("left_face", "+"), ("right_face", "-")):
            if e[side] != "exterior":
                assert use.get(e["id"] + sgn) == [e[side]], (e, use.get(e["id"] + sgn))
        assert e["left_face"] != e["right_face"]
    # the shared edge a|b exists exactly once (not two independent insets)
    ab = [e for e in sub["edges"] if {e["left_face"], e["right_face"]} == {"a", "b"}]
    assert len(ab) == 1 and abs(ab[0]["_line"].length - 10.0) < 1e-6
    for f in faces:
        assert abs(abs(SB.signed_ring_area(sub, f["id"], lines)) - f["geom"].area) < 1e-6


def test_parcel_dimensions_scaled_once():
    class _C:
        R_ = R
    from tools.settlement import program
    f = program.building_factor(R)
    c = _C()
    c.R = R
    c.wl = lambda h: h * f
    c.wa = lambda a: a * f * f
    d = PA.role_dims(c, "urban_primary")
    raw = R.p("layout.parcels.roles")["urban_primary"]
    assert d["frontage"] == (raw["frontage"][0] * f, raw["frontage"][1] * f)
    assert d["area"] == (raw["area"][0] * f * f, raw["area"][1] * f * f)
    assert d["depth"] <= R.p("layout.parcels.strip_depth_max_hist_m") * f + 1e-9


# ------------------------------------------------------------------ end-to-end
@pytest.fixture(scope="module")
def locked_run(tmp_path_factory):
    d = tmp_path_factory.mktemp("wp5l")
    p = cli.run(fixtures.load("syn_terrace_locked"), R, str(d))
    lay = json.load(open(d / "layout.json", encoding="utf-8"))
    return p, lay, d


@pytest.fixture(scope="module")
def stream_run(tmp_path_factory):
    d = tmp_path_factory.mktemp("wp5s")
    p = cli.run(fixtures.load("syn_stream"), R, str(d))
    lay = json.load(open(d / "layout.json", encoding="utf-8"))
    return p, lay, d


def _chk(lay):
    return {c["id"]: c for c in lay["checks"]}


def test_locked_layout_invariants(locked_run):
    p, lay, d = locked_run
    c = _chk(lay)
    assert c["WP5.layer"]["pass"] is True, c["WP5.layer"]["detail"]
    assert any(v["id"] == "WP5.layer" and v["pass"] for v in p["validation"])
    for k in ("L5.twin_edges", "L5.households_once", "L5.locks", "L4.connected", "L4.wall_openings", "L4.planar", "V43", "V46"):
        assert c[k]["pass"] is True, (k, c[k]["detail"])
    assert lay["status"] == "complete"
    assert p["layout"]["status"] == "complete"
    for name in ("03-districts.svg", "04-streets-water.svg", "05-parcels.svg", "combined-layout.svg"):
        assert (d / name).exists()


def test_every_household_exactly_once(locked_run):
    p, lay, _ = locked_run
    hh = [h["id"] for h in lay["households"]]
    assert len(hh) == p["program"]["households"]["represented"] == len(set(hh))
    on = [x["household"] for x in lay["parcels"] if x.get("household")]
    assert sorted(on) == sorted(hh)
    assert all(h["parcel"] for h in lay["households"])


def test_locks_are_immutable_faces(locked_run):
    p, lay, _ = locked_run
    from shapely.geometry import shape
    locks = {l["id"]: shape(p["geometry"][l["geometry"]]) for l in p["locks"]}
    lf = [f for f in lay["subdivision"]["faces"] if f["kind"] == "lock"]
    assert lf
    for f in lf:
        g = shape(lay["geometry"][f["geometry"]])
        assert abs(g.area - locks[f["of"]].area) < 0.05
        # no parcel overlaps a lock
        for x in lay["parcels"]:
            assert shape(lay["geometry"][x["zones"]["lot"]]).intersection(locks[f["of"]]).area < 0.01


def test_edges_carry_wp6_contract(locked_run):
    _, lay, _ = locked_run
    E = lay["subdivision"]["edges"]
    assert E
    for e in E:
        assert e["geometry_reason"] != "unclassified"
        assert e["allowed_closures"] and e["implementation"] is None
        assert e["purpose"] and len(e["adjacency"]) == 2
        assert {"left_y", "right_y", "difference_m"} <= set(e["level"])
    # shared parcel boundaries are stored once (one edge, two parcel faces)
    party = [e for e in E if e["purpose"] == "party_boundary"]
    assert party and all(e["left_face"].startswith("parcel:") and e["right_face"].startswith("parcel:") for e in party)
    assert all(set(e["allowed_closures"]) <= {"free_wall", "building_wall", "fence", "hedge", "retaining_wall"} for e in party)
    # the town wall is closed only by the fortification; gates are Layer-2 openings
    tw = [e for e in E if e["purpose"] == "town_wall_inner"]
    assert tw and all(e["allowed_closures"] == ["fortification"] for e in tw)


def test_parcels_follow_contract(locked_run):
    _, lay, _ = locked_run
    for x in lay["parcels"]:
        assert Ct.validate("Parcel", x) == [], x["id"]
        assert x["meta"]["status"] == "proposed"
        assert x["axes"] is None and x["axes_missing_reason"]
    res = [x for x in lay["parcels"] if x["use"] == "residential"]
    assert all(x["household"] for x in res)


def test_streets_typed_with_reasons(locked_run):
    _, lay, _ = locked_run
    for l in lay["streets"]["links"]:
        assert set(l["modes"]) == {"foot", "pack_horse", "cart"}
        assert l["reason"]
        for b in l["bends"]:
            assert b["reason"]
    hier = {l["hierarchy"] for l in lay["streets"]["links"]}
    assert "primary" in hier and hier & {"secondary", "lane", "cul_de_sac"}
    assert all(p["program"] in ("civic_forecourt", "market", "well") for p in lay["streets"]["plazas"])


def test_districts_regions_and_quotas(locked_run):
    _, lay, _ = locked_run
    D = lay["districts"]
    groups = {d["group"] for d in D["districts"]}
    assert {"market_trade", "ordinary"} <= groups
    assert D["pub04"]["pass"] and D["pub04"]["non_built_kinds"]
    assert all(a["within_tolerance"] for a in D["allocation"])
    assert D["market"]["outside_gate"]["evaluated"] is True


def test_stream_carved_width_and_ford_riffle(stream_run):
    p, lay, _ = stream_run
    ch = [c for c in lay["water"]["channels"] if c["feature"] == "stream_x" and c["effective_wet"]["geometry"]]
    assert ch
    assert any(c["width_disagreement"] and c["effective_wet"]["width_m_median"] > c["mapped_width_m"]["median"] for c in ch)
    ford = [x for x in lay["water"]["crossings"] if x["class"] == "ford"]
    assert ford and ford[0]["riffle_section"]["depth_normal_m"]["value"] <= 0.4
    normal = next(s for s in ford[0]["states"] if s["key"] == "normal")
    assert normal["modes"]["foot"]["passable"] is True


def test_stream_bridge_failure_is_reported(stream_run):
    p, lay, _ = stream_run
    c = _chk(lay)
    assert c["WP5.layer"]["pass"] is True, c["WP5.layer"]["detail"]
    x2 = [x for x in lay["water"]["crossings"] if x["origin"] == "layer2_corridor_crossing"]
    assert x2
    bad = [x for x in x2 if not x["structure_supported"]]
    if bad:
        assert c["L4.typed_crossings"]["pass"] is False
        assert lay["status"] == "incomplete"
        assert any(r["reason"] == "crossing_unsupported" and r["target"].startswith("L2") for r in lay["revision_requests"])
    # wall water passages exist for the stream (V49 part)
    assert {w["channel"] for w in lay["water"]["wall_passages"]} >= {"stream_x"}
