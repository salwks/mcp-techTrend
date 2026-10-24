"""WP2: identity registry (identity ≠ revision), locks imported before generation, V14, V16."""
import copy
import json

import pytest

from tools.settlement import cli, fixtures, geometry as G, locks as L, registry as REG
from tools.settlement.adapters import region as RA
from tools.settlement.rules import Rules
from tools.settlement.validate import _locks_preserved

R = Rules()
G.set_grid(R.p("geometry.grid"))


def test_registry_key_position_and_retire():
    r = REG.Registry()
    a = r.claim("civic", "s1", key="gaeksa", content={"v": 1})
    g = r.claim("gate", "s1", xz=(0, 0), tol=30, content={"v": 1})
    assert a == "civic:s1:001" and g == "gate:s1:001"
    r2 = REG.Registry()
    r2.data = copy.deepcopy(r.data)
    a2 = r2.claim("civic", "s1", key="gaeksa", content={"v": 2})          # same key, new revision
    g2 = r2.claim("gate", "s1", xz=(12, 5), tol=30, content={"v": 2})     # moved 13 m: same identity
    g3 = r2.claim("gate", "s1", xz=(200, 0), tol=30, content={"v": 1})    # far: new identity
    assert (a2, g2, g3) == ("civic:s1:001", "gate:s1:001", "gate:s1:002")
    assert r2.data["entries"][a2]["revision"] != r.data["entries"][a]["revision"]
    r3 = REG.Registry()
    r3.data = copy.deepcopy(r2.data)
    r3.claim("civic", "s1", key="gaeksa")
    assert sorted(r3.retire_unclaimed("s1")) == ["gate:s1:001", "gate:s1:002"]
    assert r3.claim("gate", "s1", xz=(12, 5), tol=30) == "gate:s1:003"   # retired ids are never reused


@pytest.fixture(scope="module")
def outdir(tmp_path_factory):
    return tmp_path_factory.mktemp("wp2")


def _ids(plan):
    fr = plan["frame"]
    out = {"frame": fr["stable_id"]}
    out.update({c["key"]: c["stable_id"] for c in fr["civic_reserves"]})
    out.update({n["id"]: n["stable_id"] for n in fr["primary_corridors"]["nodes"]})
    return out


def test_partial_regeneration_keeps_ids_v14(outdir):
    path = str(outdir / "registry.json")
    reg = REG.Registry(path)
    p1 = cli.run(fixtures.load("syn_estuary"), R, str(outdir / "e1"), registry=reg)
    cli.run(fixtures.load("fail_impossible_civic"), R, str(outdir / "f1"), registry=reg)
    reg.save()
    other_before = {k: v for k, v in reg.data["entries"].items() if v["scope"] == "fail_impossible_civic"}
    reg2 = REG.Registry(path)                         # regenerate only the estuary
    p2 = cli.run(fixtures.load("syn_estuary"), R, str(outdir / "e2"), registry=reg2)
    reg2.save()
    assert _ids(p1) == _ids(p2)
    other_after = {k: v for k, v in reg2.data["entries"].items() if v["scope"] == "fail_impossible_civic"}
    assert other_before == other_after                # non-target ids untouched
    assert p2["identity"]["retired"] == []


def test_locked_spots_never_move_and_conflicts_reported_v14(outdir):
    s = fixtures.load("syn_terrace_locked")
    before = [(l["id"], tuple(l["xz"])) for l in s.locks]
    p = cli.run(s, R, str(outdir / "locked"))
    assert [(l["id"], tuple(l["geometry_xz"])) for l in p["locks"]] == before
    chk = {c["id"]: c["pass"] for c in p["validation"]}
    assert chk["WP2.locks_preserved"] and chk["L2.intrusion"]
    # the wall never crosses a lock in the accepted frame; rejected candidates are reported
    assert not any(c["code"] == "lock_conflict" for c in p["frame"]["constraints"])
    assert p["lock_report"]["conflicts"], "candidates crossing the south story spot must be reported"
    assert any(e["category"] == "locks" and e["area_m2"] > 0 for e in p["program"]["area_ledger"]["categories"])


def test_region_adapter_imports_story_locks_v16():
    inp = RA.load("JL_NAMWON_UNBONG", "namwon_eup", R)
    kinds = {l["kind"] for l in inp.locks}
    assert {"story_anchor", "story_item", "station_anchor"} <= kinds
    plan = {"locks": [{"id": l["id"], "geometry_xz": l["xz"]} for l in inp.locks]}
    ok, det = _locks_preserved(plan, inp)
    assert ok, det
    assert det["baseline_in_window"] == len(inp.locks)
