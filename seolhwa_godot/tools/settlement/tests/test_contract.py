"""WP1: common data contract v1 — schema unit tests, V18 (no automatic confirmation),
missing ≠ 0, K1 single scale record."""
import copy
import json

import pytest

from tools.settlement import contract as C, fixtures, geometry as G
from tools.settlement.rules import Rules
from tools.settlement.validate import schema_errors, load_schema

R = Rules()
G.set_grid(R.p("geometry.grid"))


def M(sid, **kw):
    return C.meta(sid, **kw)


EXAMPLES = {
    "SourceRecord": {"meta": M("source:vr12"), "title": "낙안 들마루집 기록화보고서", "url": "https://example.invalid",
                     "written": "2010", "depicts": "현황", "kind": "survey", "access_scope": "선별 쪽",
                     "observations": ["평면·단면"], "limits": ["1건"], "units_confirmed": True},
    "TerrainPatch": {"meta": M("terrain:t1"), "original": "g-000000000000", "modified": None, "landform": "slope",
                     "rock_body": None, "rock_type": C.measure(None, "class"), "structure_dir": C.measure(None, "deg"),
                     "exposure": "soil", "change_reason": None},
    "WaterReach": {"meta": M("water:yocheon:001"), "upstream": [], "downstream": [], "long_profile": [], "cross_section": None,
                   "plan": "g-000000000000", "flow": "unknown", "bed_mix": None,
                   "states": [{"key": "high_major", "offset_world_m": 1.5, "status": "proposed"}]},
    "HabitatPatch": {"meta": M("habitat:h1"), "community": "pine", "management": "village_grove", "soil": None,
                     "moisture": None, "season": "summer"},
    "Route": {"meta": M("route:r1"), "purpose": "town access", "nodes": ["n1", "n2"],
              "modes": [{"mode": "foot", "passable": True, "limit": 0.15, "status": "proposed"}],
              "width_section": {"width_m": 4.8}, "long_profile": [], "support_drainage": [], "centerline": "g-000000000000"},
    "Parcel": {"meta": M("parcel:p1"), "use": "residential", "zones": [], "access": [], "yards": [], "buildable": None, "axes": []},
    "Boundary": {"meta": M("boundary:b1"), "sides": ["parcel:p1", "street:s1"], "purpose": "privacy",
                 "implementation": "free_wall", "shared_id": "boundary:b1", "geometry": "g-000000000000",
                 "section": None, "ends": []},
    "Opening": {"meta": M("opening:o1"), "use": "drainage", "width_m": 1.2, "height_m": None, "access_sides": [],
                "swing_side": None, "state": "open", "host": "boundary:b1", "chainage": [10.0, 11.2]},
    "Building": {"meta": M("building:k1"), "type_basis": "source:vr12", "column_grid": [], "bay_spacing": [2.6, 2.6],
                 "function_faces": [], "floor_base": None, "roof_support": None, "members": [], "condition": "normal",
                 "scale_applied": True},
    "ActivitySite": {"meta": M("activity:a1"), "activity": "laundry", "users": [], "spaces": [], "state": "normal"},
    "SurfaceProfile": {"meta": M("surface:s1"), "material_id": "todam", "base": "earth", "real_size_m": None,
                       "channels": [], "exposure": None, "weather_response": None, "wear": "worn"},
    "WallSection": {"meta": M("wallsection:w1"), "outer": None, "inner": None, "foundation": None, "fill": None,
                    "top": None, "drainage": None, "ground_both_sides": [None, None]},
    "Fortification": {"meta": M("fort:f1"), "function": "eupseong", "terrain": "plain", "access": [], "water_source": [],
                      "sections": [], "features": []},
    "DefenseFeature": {"meta": M("defense:d1"), "kind": "chi", "host_boundary": "boundary:b1", "chainage": [1, 2]},
    "LandUseProfile": {"meta": M("landuse:l1"), "cultivation": None, "forest_use": None, "management_state": None, "basis": []},
    "Lock": {"meta": M("lock:anchor:namwon:east_gate", lock_scope=["position", "access"]), "kind": "story_anchor",
             "geometry_xz": [-3135.3, 248.8], "radius_m": 3.0, "source": "story/namwon/namwon_data.gd"},
}


@pytest.mark.parametrize("kind", sorted(EXAMPLES))
def test_examples_validate(kind):
    assert C.validate(kind, EXAMPLES[kind]) == []


@pytest.mark.parametrize("kind", sorted(EXAMPLES))
def test_missing_required_fails(kind):
    ex = copy.deepcopy(EXAMPLES[kind])
    req = C.contract()["$defs"][kind]["required"]
    ex.pop(req[-1])
    assert C.validate(kind, ex)


def test_meta_required_fields_and_status_enum():
    ex = copy.deepcopy(EXAMPLES["Parcel"])
    ex["meta"]["status"] = "approved"
    assert C.validate("Parcel", ex)
    ex = copy.deepcopy(EXAMPLES["Parcel"])
    del ex["meta"]["revision"]
    assert C.validate("Parcel", ex)


def test_missing_is_not_zero():
    a = C.measure(None, "m")
    b = C.measure(0.0, "m", status="confirmed", source="source:x")
    assert a["value"] is None and a["missing_reason"] and a["status"] == "unknown"
    assert b["value"] == 0.0 and b["missing_reason"] is None and b["status"] == "confirmed"


def test_v18_no_automatic_confirmation():
    with pytest.raises(ValueError):
        C.meta("building:x", status="confirmed")                     # no source
    with pytest.raises(ValueError):
        C.meta("building:x", status="confirmed", sources=["s"], hypothesis=True)
    bad = {"a": {"meta": dict(C.meta("parcel:p"), status="confirmed")}}
    assert C.v18_violations(bad)
    assert C.v18_violations({"meta": C.meta("parcel:p", status="confirmed", sources=["source:x"])}) == []


def test_status_mapping_table():
    assert C.status_of("measured") == ("confirmed", False)
    assert C.status_of("agreed") == ("proposed", False)
    assert C.status_of("provisional") == ("proposed", False)
    assert C.status_of("가설") == ("proposed", True)
    assert C.status_of("추정") == ("proposed", False)
    assert C.status_of("확정") == ("confirmed", False)
    assert C.status_of("whatever") == ("unknown", False)


def test_revision_is_content_hash_identity_is_not():
    m1 = C.meta("gate:s:001", content={"xz": [1, 2]})
    m2 = C.meta("gate:s:001", content={"xz": [1, 3]})
    assert m1["stable_id"] == m2["stable_id"] and m1["revision"] != m2["revision"]


def test_region_profile_single_scale_record_k1():
    s = fixtures.load("syn_terrace")
    rp = C.region_profile(s, R)
    assert C.validate("RegionProfile", rp) == []
    b = rp["scale_policy"]["building"]
    assert b["factor"] == R.p("world.length_scale") and set(b["axes"]) == {"plan", "height"}
    assert rp["scale_policy"]["apply_once_at"] == "bake" and rp["scale_policy"]["rules_hold"] == "measured_values"
    assert rp["water_states"]["units"] == "world_m"
    assert [st["offset"] for st in rp["water_states"]["states"] if st.get("screen")] == R.p("flood.stage_offsets")
    assert C.v18_violations(rp) == []


def test_contract_schema_is_valid_json_with_all_objects():
    defs = C.contract()["$defs"]
    for k in ["RegionProfile", "SourceRecord", "TerrainPatch", "WaterReach", "HabitatPatch", "Route", "Parcel",
              "Boundary", "Opening", "Building", "ActivitySite", "SurfaceProfile", "WallSection", "Fortification",
              "DefenseFeature", "LandUseProfile", "Lock"]:
        assert k in defs


def test_plan_schema_reads_v1_and_v2():
    sch = load_schema("settlement-plan.schema.json")
    assert set(sch["properties"]["schema"]["enum"]) == {"settlement-plan/1", "settlement-plan/2"}
