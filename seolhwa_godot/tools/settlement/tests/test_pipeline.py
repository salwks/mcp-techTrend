"""End-to-end Layer 0–2 runs on fixtures: invariants, failure fixtures, determinism."""
import filecmp
import json
import os

import pytest

from tools.settlement import cli, fixtures
from tools.settlement.rules import Rules

R = Rules()


@pytest.fixture(scope="module")
def outdir(tmp_path_factory):
    return tmp_path_factory.mktemp("settle")


def _checks(plan):
    return {c["id"]: c["pass"] for c in plan["validation"]}


def test_terrace_valid_all_checks(outdir):
    p = cli.run(fixtures.load("syn_terrace"), R, str(outdir / "t"))
    assert p["status"] == "valid"
    assert p["frame"]["family"] == "plain"
    assert len(p["alternatives"]) == 8
    gates = [o for o in p["frame"]["openings"] if o["type"] == "gate"]
    assert 2 <= len(gates) <= 4
    assert all(v is not False for v in _checks(p).values()), _checks(p)


def test_estuary_unwalled_valid(outdir):
    p = cli.run(fixtures.load("syn_estuary"), R, str(outdir / "e"))
    assert p["status"] == "valid" and p["frame"]["wall"] is None
    assert all(v is not False for v in _checks(p).values()), _checks(p)


@pytest.mark.parametrize("name,expect", [
    ("fail_blocked_access", {"blocked_access", "water_crossing_required", "corridor_grade", "civic_fit_failed"}),
    ("fail_impossible_civic", {"civic_fit_failed", "insufficient_capacity"}),
    ("fail_water_crossing", {"water_crossing_required", "civic_fit_failed", "untyped_route_crossing"}),
])
def test_failure_fixtures_adapt_and_report_initial_constraints(outdir, name, expect):
    """Owner 2026-10-25: the standard solve's failure is recorded (named constraints) and the
    builder adapts instead of stopping; the adaptation steps are recorded."""
    p = cli.run(fixtures.load(name), R, str(outdir / name))
    ad = p["adaptation"]
    assert ad is not None and ad["initial"]["rejections"] or ad["initial"]["L1"], ad
    assert set(ad["initial"]["rejections"]) & expect or ad["initial"]["L1"], ad["initial"]
    assert ad["tried"]
    if ad.get("result"):
        assert p["status"] in ("valid", "proposed"), (p["status"], p["validation"])


def test_repeat_runs_byte_identical(outdir):
    a, b = outdir / "da", outdir / "db"
    cli.run(fixtures.load("syn_estuary"), R, str(a))
    cli.run(fixtures.load("syn_estuary"), R, str(b))
    for f in ("plan.json", "input.json", "site.geojson", "site-fields.npz", "00-site.svg", "01-program.svg",
              "02-frame.svg", "combined.svg"):
        assert filecmp.cmp(a / f, b / f, shallow=False), f
