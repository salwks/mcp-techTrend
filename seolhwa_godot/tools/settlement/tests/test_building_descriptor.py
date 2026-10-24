"""WP7a: building descriptors exported by the Godot builder (kit/bldg/descriptor.gd) match the
WP1 contract — BuildingDescriptor schema (Building's required items + WP7a details), V18,
revision = content hash, and the single scale record (K1): the factor in every descriptor is
RegionProfile.scale_policy.building.factor (rules world.length_scale), applied once.

Samples are regenerated with
  godot --headless --path . -s res://tools/bldg/descriptor_export.gd -- --set=samples --out=res://tools/bldg/descriptors/samples
"""
import glob
import hashlib
import json
import os

import pytest

from tools.settlement import contract as C
from tools.settlement.geometry import canonical_json
from tools.settlement.program import building_factor
from tools.settlement.rules import Rules

HERE = os.path.dirname(__file__)
SAMPLES = sorted(glob.glob(os.path.join(HERE, "..", "..", "bldg", "descriptors", "samples", "*.json")))
R = Rules()


def _load(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def test_samples_exist():
    assert len(SAMPLES) >= 4


@pytest.mark.parametrize("path", SAMPLES, ids=[os.path.basename(p) for p in SAMPLES])
def test_descriptor_schema(path):
    d = _load(path)
    assert C.validate("BuildingDescriptor", d) == []
    # the WP1 Building object is a subset: a descriptor is also a valid Building
    assert C.validate("Building", d) == []


@pytest.mark.parametrize("path", SAMPLES, ids=[os.path.basename(p) for p in SAMPLES])
def test_descriptor_v18_and_revision(path):
    d = _load(path)
    assert C.v18_violations(d) == []
    assert d["meta"]["status"] in ("proposed", "unknown")
    for e in d["type_basis"]["evidence"]:
        assert e["status"] in ("proposed", "unknown")       # generator never confirms
    body = {k: v for k, v in d.items() if k != "meta"}
    assert hashlib.sha256(canonical_json(body).encode("utf-8")).hexdigest() == d["meta"]["revision"]


@pytest.mark.parametrize("path", SAMPLES, ids=[os.path.basename(p) for p in SAMPLES])
def test_descriptor_single_scale_record_k1(path):
    d = _load(path)
    f = building_factor(R)
    assert d["scale_applied"] is True
    assert d["scale"]["factor"] == pytest.approx(f)
    assert d["scale"]["axes"] == ["plan", "height"]
    assert d["scale"]["source"] == "RegionProfile.scale_policy.building.factor"
    rs = d["scale"]["spec_real_scale"]
    assert rs == [pytest.approx(f), pytest.approx(f)]          # plan = height, once


@pytest.mark.parametrize("path", SAMPLES, ids=[os.path.basename(p) for p in SAMPLES])
def test_function_faces_cover_structural_bays(path):
    d = _load(path)
    ids = [b for f in d["function_faces"] for b in f["bays"]]
    assert sorted(ids) == sorted(b["id"] for b in d["structural_bays"])   # every bay in exactly one face
    doors = {x["id"] for x in d["doors"]}
    for f in d["function_faces"]:
        assert set(f["doors"]) <= doors
    for h in d["heating"]:
        kinds = {s["id"]: s["kind"] for s in d["sockets"]}
        assert kinds[h["fire"]] in ("agungi", "hamsil_agungi")
        assert all(kinds[g] == "gudeul" for g in h["gudeul"])
