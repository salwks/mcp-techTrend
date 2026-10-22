"""Rules file loader. Every tunable lives in rules/default.json with metadata."""
from __future__ import annotations

import hashlib
import json
import os

DEFAULT = os.path.join(os.path.dirname(__file__), "rules", "default.json")
META_KEYS = {"value", "unit", "source", "confidence", "kind"}


class Rules:
    def __init__(self, path: str = DEFAULT):
        with open(path, "rb") as f:
            raw = f.read()
        self.path = path
        self.hash = hashlib.sha256(raw).hexdigest()
        self.data = json.loads(raw)
        if self.data.get("schema") != "settlement-rules/1":
            raise ValueError("rules schema must be settlement-rules/1")
        self.used: set[str] = set()
        self.check_metadata()

    def check_metadata(self):
        bad = []

        def walk(o, path):
            if isinstance(o, dict):
                if "value" in o and not META_KEYS <= set(o):
                    bad.append(path)
                for k, v in o.items():
                    walk(v, f"{path}.{k}")
        for sec in ("parameters", "profiles", "institution_variants", "objectives"):
            walk(self.data.get(sec, {}), sec)
        for k, v in self.data["parameters"].items():
            if not (isinstance(v, dict) and META_KEYS <= set(v)):
                bad.append(f"parameters.{k}")
        if bad:
            raise ValueError(f"rules entries missing metadata: {bad[:5]}")

    def p(self, key: str):
        self.used.add(key)
        return self.data["parameters"][key]["value"]

    def profile(self, name: str) -> dict:
        return self.data["profiles"][name]

    def institution(self, key: str) -> dict:
        return self.data["institution_variants"][key]

    def objective_weight(self, k):
        return self.data["objectives"]["weights"][k]["value"]

    def objective_range(self, k):
        return self.data["objectives"]["ranges"][k]["value"]

    def mapping(self):
        return self.data["mapping"]


def val(entry):
    """Value of a metadata entry (or a raw literal)."""
    return entry["value"] if isinstance(entry, dict) and "value" in entry else entry
