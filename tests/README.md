# tests/

Live smoke test that exercises every tool against real upstream APIs.

```bash
cd ..
.venv/bin/python tests/smoke_test.py
```

This is **not** a unit test suite — it makes real network requests to arXiv,
PubMed, GitHub, openFDA, etc. Useful for spot-checking after dependency
upgrades or upstream API changes. Mock-based unit tests (CI-friendly) are
TODO for v0.2.
