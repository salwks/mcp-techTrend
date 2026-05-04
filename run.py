"""trends-mcp launcher — single source of truth for user configuration.

╔══════════════════════════════════════════════════════════════════════════╗
║  HOW TO CONFIGURE                                                        ║
║  ────────────────                                                        ║
║  1. Edit the four constants in the SETTINGS block below.                 ║
║  2. Quit Claude Desktop completely (Cmd+Q), then re-open.                ║
║     If trends still shows old behavior, run:                             ║
║       pkill -f trends_mcp                                                ║
║     and call the trends server once to respawn.                          ║
║  3. Verify in chat: "주간 뉴스 보여줘" or "weekly briefing".              ║
║                                                                          ║
║  WHY THIS FILE (instead of config.json's `env` block)                    ║
║  ─────────────────────────────────────────────────────                   ║
║  Some Claude Desktop builds truncate env values containing whitespace    ║
║  (only the first word reaches the child). Sandboxed builds also block    ║
║  shell-script wrappers. Setting via os.environ in Python is bulletproof. ║
║                                                                          ║
║  See README.md for context, ARXIV_CATEGORIES.md for the full category    ║
║  reference (200+ codes), and pyproject.toml for package metadata.        ║
╚══════════════════════════════════════════════════════════════════════════╝
"""
from __future__ import annotations

import os
import runpy
from pathlib import Path

# ───────────────────────────────  SETTINGS  ────────────────────────────────
# Edit these to match your workflow. Defaults below target medical-imaging AI;
# leave any field as "" to fall back to the server's domain-neutral default.

# 1) Source allowlist — comma-separated. Empty / "*" / "all" = enable all.
#    Valid: arxiv, github, huggingface, paperswithcode, pubmed, fda_510k, fda_recalls
#    Disabled sources: their tools won't appear in the chat at all.
TRENDS_ENABLED_SOURCES = ""

# 2) arXiv categories with weights (papers per category per briefing).
#    Format: "code:count,code:count,..." — ":count" optional (default 3).
#    Round-robin per category, so small categories don't get drowned by big ones.
#
#    PRESETS — pick one with `python configure.py` or write your own
#    (full reference: ARXIV_CATEGORIES.md):
#      ai-ml           :  "cs.LG:5,cs.CV:3,cs.CL:3,cs.AI:2"   ← default below
#      medical-imaging :  "eess.IV:5,cs.CV:3,cs.HC:2,q-bio.QM:2"
#      robotics        :  "cs.RO:5,cs.AI:3,cs.LG:2,cs.CV:2"
#      hci             :  "cs.HC:5,cs.CY:3,cs.AI:2,cs.SI:2"
#      security        :  "cs.CR:5,cs.LG:2,cs.NI:2"
#      bio             :  "q-bio.QM:4,q-bio.GN:3,q-bio.BM:3,stat.AP:2"
TRENDS_ARXIV_CATEGORIES = "cs.LG:5,cs.CV:3,cs.CL:3,cs.AI:2"

# 3) PubMed default query — used by trends_briefing when topic is omitted.
#    Use PubMed syntax (MeSH terms, [Title/Abstract] tags, AND/OR/NOT).
#    [Title/Abstract] tags keep matches precise; without them, PubMed expands
#    aggressively and you'll see unrelated papers.
#
#    PRESETS (apply via `python configure.py`):
#      general-medical (default below) — broad medical-AI feed
#      medical-imaging — mammography, breast cancer, radiology focus
#      cardiology      — ECG, cardiac AI
#      ophthalmology   — retina, fundus, OCT
#      pathology       — histopathology, H&E
TRENDS_DEFAULT_PUBMED_QUERY = (
    "(deep learning OR artificial intelligence) "
    "AND (medical[Title/Abstract] OR clinical[Title/Abstract])"
)

# 4) Optional API tokens — uncomment + fill to lift rate limits.
#    All tools work without these; tokens just raise the per-source ceiling.
# GITHUB_TOKEN = "ghp_..."        # 60 → 5,000 req/h
# HF_TOKEN = "hf_..."             # auth + higher caps for HF Hub
# NCBI_API_KEY = "..."            # 3 → 10 req/s for PubMed
# OPENFDA_API_KEY = "..."         # 240 → 120,000 req/day for openFDA

# ───────────────────────────  END OF SETTINGS  ─────────────────────────────

# ---------------------------------------------------------------------------

_HERE = Path(__file__).resolve().parent

# Apply the config. Use setdefault so external env vars (if any) win — useful
# for testing or temporary overrides via the parent shell.
for _name in (
    "TRENDS_ENABLED_SOURCES",
    "TRENDS_ARXIV_CATEGORIES",
    "TRENDS_DEFAULT_PUBMED_QUERY",
    "GITHUB_TOKEN",
    "HF_TOKEN",
    "NCBI_API_KEY",
    "OPENFDA_API_KEY",
):
    _value = globals().get(_name)
    if isinstance(_value, str) and _value:
        os.environ.setdefault(_name, _value)

# Hand off to the actual server. runpy.run_path simulates `python trends_mcp.py`,
# making __name__ == "__main__" inside the target module.
runpy.run_path(str(_HERE / "trends_mcp.py"), run_name="__main__")
