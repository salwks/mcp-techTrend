#!/usr/bin/env python3
"""trends-mcp interactive configurator.

Reads & writes the SETTINGS block at the top of run.py — edits in place,
preserves the rest of the file. No external deps; pure stdlib.

Usage:
    python configure.py                    # interactive menu
    python configure.py --show             # print current config and exit
    python configure.py --restart          # just kill stale MCP processes
"""
from __future__ import annotations

import ast
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Callable

# ---------------------------------------------------------------------------
# Paths and constants
# ---------------------------------------------------------------------------

HERE = Path(__file__).resolve().parent
RUN_PY = HERE / "run.py"
BACKUP_PY = HERE / "run.py.bak"
CATEGORIES_DOC = HERE / "ARXIV_CATEGORIES.md"

ALL_SOURCES: list[str] = [
    "arxiv", "github", "huggingface", "paperswithcode",
    "pubmed", "fda_510k", "fda_recalls",
]

PRESETS_ARXIV: dict[str, list[tuple[str, int]]] = {
    "medical-imaging": [("eess.IV", 5), ("cs.CV", 3), ("cs.HC", 2), ("q-bio.QM", 2)],
    "ai-ml":          [("cs.LG", 5), ("cs.CV", 3), ("cs.CL", 3), ("cs.AI", 2)],
    "robotics":       [("cs.RO", 5), ("cs.AI", 3), ("cs.LG", 2), ("cs.CV", 2)],
    "hci":            [("cs.HC", 5), ("cs.CY", 3), ("cs.AI", 2), ("cs.SI", 2)],
    "security":       [("cs.CR", 5), ("cs.LG", 2), ("cs.NI", 2)],
    "bio":            [("q-bio.QM", 4), ("q-bio.GN", 3), ("q-bio.BM", 3), ("stat.AP", 2)],
}

PRESETS_PUBMED: dict[str, str] = {
    "medical-imaging": (
        "(deep learning OR artificial intelligence OR machine learning) "
        "AND (mammography[Title/Abstract] OR breast cancer[Title/Abstract] "
        "OR medical imaging[Title/Abstract] OR radiology[Title/Abstract])"
    ),
    "general-medical": (
        "(deep learning OR artificial intelligence) "
        "AND (medical[Title/Abstract] OR clinical[Title/Abstract])"
    ),
    "cardiology": (
        "(deep learning OR artificial intelligence) "
        "AND (cardiology[MeSH] OR ECG[Title/Abstract] OR cardiac[Title/Abstract])"
    ),
    "ophthalmology": (
        "(deep learning OR artificial intelligence) "
        "AND (retina[Title/Abstract] OR fundus[Title/Abstract] OR OCT[Title/Abstract])"
    ),
    "pathology": (
        "(deep learning OR artificial intelligence) "
        "AND (pathology[MeSH] OR histopathology[Title/Abstract] OR H&E[Title/Abstract])"
    ),
}

VALID_ARXIV_ARCHIVES = frozenset({
    "cs", "math", "stat", "physics", "astro-ph", "cond-mat", "gr-qc", "hep-ex",
    "hep-lat", "hep-ph", "hep-th", "math-ph", "nlin", "nucl-ex", "nucl-th",
    "quant-ph", "q-bio", "q-fin", "eess", "econ",
})

# ANSI colors
class C:
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    MAGENTA = "\033[35m"
    CYAN = "\033[36m"
    RED = "\033[31m"


# ---------------------------------------------------------------------------
# Read / write run.py SETTINGS block
# ---------------------------------------------------------------------------

class Config:
    """In-memory snapshot of run.py's SETTINGS values."""

    def __init__(self) -> None:
        self.enabled_sources: str = ""
        self.arxiv_categories: str = ""
        self.pubmed_query: str = ""
        self.tokens: dict[str, str | None] = {
            "GITHUB_TOKEN": None,
            "HF_TOKEN": None,
            "NCBI_API_KEY": None,
            "OPENFDA_API_KEY": None,
        }

    @classmethod
    def load(cls) -> "Config":
        """Parse run.py via AST — robust against query strings containing
        parentheses, brackets, or any other regex-confounding chars."""
        cfg = cls()
        text = RUN_PY.read_text()
        try:
            tree = ast.parse(text)
        except SyntaxError as e:
            raise SystemExit(f"run.py 파싱 실패 (문법 오류): {e}") from e
        # Walk top-level assignments. (We don't recurse — settings are at top.)
        for node in tree.body:
            if not isinstance(node, ast.Assign) or len(node.targets) != 1:
                continue
            target = node.targets[0]
            if not isinstance(target, ast.Name):
                continue
            name = target.id
            value = node.value
            # Implicit string concat in source ('..' '..') becomes one Constant.
            if not (isinstance(value, ast.Constant) and isinstance(value.value, str)):
                continue
            sval = value.value
            if name == "TRENDS_ENABLED_SOURCES":
                cfg.enabled_sources = sval
            elif name == "TRENDS_ARXIV_CATEGORIES":
                cfg.arxiv_categories = sval
            elif name == "TRENDS_DEFAULT_PUBMED_QUERY":
                cfg.pubmed_query = sval
            elif name in cfg.tokens:
                cfg.tokens[name] = sval
        return cfg

    def save(self) -> None:
        text = RUN_PY.read_text()
        # Backup once per save.
        BACKUP_PY.write_text(text)
        # Replace simple string assignments.
        text = re.sub(
            r'(TRENDS_ENABLED_SOURCES\s*=\s*)"[^"]*"',
            lambda m: f'{m.group(1)}"{self.enabled_sources}"',
            text,
        )
        text = re.sub(
            r'(TRENDS_ARXIV_CATEGORIES\s*=\s*)"[^"]*"',
            lambda m: f'{m.group(1)}"{self.arxiv_categories}"',
            text,
        )
        # PubMed query — replace the parenthesized concatenated literal.
        new_pubmed = self._format_pubmed_literal(self.pubmed_query)
        text = re.sub(
            r'(TRENDS_DEFAULT_PUBMED_QUERY\s*=\s*)\(.*?\)',
            lambda m: f'{m.group(1)}{new_pubmed}',
            text, count=1, flags=re.DOTALL,
        )
        # Tokens — toggle commented vs uncommented based on value.
        for key, val in self.tokens.items():
            if val is None:
                # Re-comment the line (preserve indent).
                text = re.sub(
                    rf'^(\s*){key}(\s*=\s*)"[^"]*"',
                    lambda m, k=key: f'{m.group(1)}# {k}{m.group(2)}"..."',
                    text, count=1, flags=re.MULTILINE,
                )
            else:
                # Uncomment + set value.
                text = re.sub(
                    rf'^(\s*)#\s*{key}(\s*=\s*)"[^"]*"',
                    lambda m, k=key, v=val: f'{m.group(1)}{k}{m.group(2)}"{v}"',
                    text, count=1, flags=re.MULTILINE,
                )
                # If already uncommented, just update the value.
                text = re.sub(
                    rf'^(\s*){key}(\s*=\s*)"[^"]*"',
                    lambda m, k=key, v=val: f'{m.group(1)}{k}{m.group(2)}"{v}"',
                    text, count=1, flags=re.MULTILINE,
                )
        RUN_PY.write_text(text)

    @staticmethod
    def _format_pubmed_literal(query: str) -> str:
        """Format a query string as Python parenthesized concatenated literals,
        wrapping at clause boundaries for readability."""
        if not query:
            return '("")'
        # Wrap roughly every 80 chars at AND/OR boundaries.
        parts: list[str] = []
        remaining = query
        while len(remaining) > 80:
            # Find break point near 80 chars at " AND " or " OR ".
            cut = -1
            for kw in (" AND ", " OR "):
                idx = remaining.rfind(kw, 0, 80)
                if idx > cut:
                    cut = idx + 1  # keep the leading space on next line
            if cut <= 0:
                cut = 80
            parts.append(remaining[:cut].rstrip())
            remaining = remaining[cut:]
        parts.append(remaining)
        body = "\n        ".join(f'"{p} "' if i + 1 < len(parts) else f'"{p}"'
                                  for i, p in enumerate(parts))
        # Strip trailing spaces in each literal.
        return f'(\n        {body}\n    )'

    # --- helpers ---

    def sources_set(self) -> set[str]:
        if not self.enabled_sources or self.enabled_sources in ("*", "all"):
            return set(ALL_SOURCES)
        return {s.strip() for s in self.enabled_sources.split(",") if s.strip()}

    def set_sources(self, active: set[str]) -> None:
        if active == set(ALL_SOURCES):
            self.enabled_sources = ""
        else:
            self.enabled_sources = ",".join(s for s in ALL_SOURCES if s in active)

    def arxiv_pairs(self) -> list[tuple[str, int]]:
        pairs: list[tuple[str, int]] = []
        for chunk in self.arxiv_categories.split(","):
            chunk = chunk.strip()
            if not chunk:
                continue
            if ":" in chunk:
                code, count = chunk.split(":", 1)
                try:
                    pairs.append((code.strip(), int(count.strip())))
                except ValueError:
                    continue
            else:
                pairs.append((chunk, 3))
        return pairs

    def set_arxiv_pairs(self, pairs: list[tuple[str, int]]) -> None:
        self.arxiv_categories = ",".join(f"{c}:{n}" for c, n in pairs)


def is_valid_category(code: str) -> bool:
    if not code:
        return False
    archive = code.split(".", 1)[0]
    return archive in VALID_ARXIV_ARCHIVES


# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------

def clear_screen() -> None:
    os.system("clear" if os.name != "nt" else "cls")


def header(title: str) -> None:
    print(f"{C.BOLD}{C.CYAN}═══ {title} ═══{C.RESET}")


def hint(text: str) -> None:
    print(f"{C.DIM}{text}{C.RESET}")


def ok(text: str) -> None:
    print(f"{C.GREEN}✓{C.RESET} {text}")


def warn(text: str) -> None:
    print(f"{C.YELLOW}⚠{C.RESET} {text}")


def err(text: str) -> None:
    print(f"{C.RED}✗{C.RESET} {text}")


def prompt(text: str) -> str:
    try:
        return input(f"{C.BLUE}{text}{C.RESET}").strip()
    except (KeyboardInterrupt, EOFError):
        print()
        sys.exit(0)


# ---------------------------------------------------------------------------
# Menu screens
# ---------------------------------------------------------------------------

def screen_main(cfg: Config) -> str:
    clear_screen()
    header("trends-mcp 설정")
    hint(f"File: {RUN_PY}")
    print()
    sources = cfg.sources_set()
    pairs = cfg.arxiv_pairs()
    enabled_tokens = sum(1 for v in cfg.tokens.values() if v)
    print(f"  [1] 활성 소스         {C.DIM}({len(sources)}/{len(ALL_SOURCES)} 활성){C.RESET}")
    print(f"  [2] arXiv 카테고리    {C.DIM}({len(pairs)}개 · 합 {sum(n for _,n in pairs)}편/주){C.RESET}")
    print(f"  [3] PubMed 쿼리       {C.DIM}({len(cfg.pubmed_query)}자){C.RESET}")
    print(f"  [4] API 토큰          {C.DIM}({enabled_tokens}/4 활성){C.RESET}")
    print(f"  [5] 현재 설정 보기")
    print(f"  [6] {C.GREEN}저장하고 재시작{C.RESET}")
    print(f"  [7] {C.YELLOW}변경 취소하고 종료{C.RESET}")
    print()
    return prompt("선택: ")


def screen_sources(cfg: Config) -> None:
    while True:
        clear_screen()
        header("활성 소스")
        hint("토글할 번호 입력 (콤마/공백 구분). a=전체, n=없음, q=뒤로")
        print()
        active = cfg.sources_set()
        for i, s in enumerate(ALL_SOURCES, 1):
            mark = f"{C.GREEN}[x]{C.RESET}" if s in active else "[ ]"
            print(f"  [{i}] {mark} {s}")
        print()
        ans = prompt("> ").lower()
        if ans in ("q", ""):
            return
        if ans == "a":
            cfg.set_sources(set(ALL_SOURCES))
            continue
        if ans == "n":
            cfg.set_sources(set())
            continue
        # Toggle by numbers.
        toggled = active.copy()
        bad: list[str] = []
        for tok in re.split(r"[,\s]+", ans):
            if not tok:
                continue
            try:
                idx = int(tok)
                if not 1 <= idx <= len(ALL_SOURCES):
                    raise ValueError
                src = ALL_SOURCES[idx - 1]
                if src in toggled:
                    toggled.remove(src)
                else:
                    toggled.add(src)
            except ValueError:
                bad.append(tok)
        cfg.set_sources(toggled)
        if bad:
            warn(f"무시: {bad}")
            prompt("(엔터로 계속)")


def screen_arxiv(cfg: Config) -> None:
    while True:
        clear_screen()
        header("arXiv 카테고리")
        hint("명령:  set <번호> <개수>  /  add <code> [개수]  /  remove <번호>")
        hint("       preset <이름>  /  list  /  clear  /  q")
        print()
        pairs = cfg.arxiv_pairs()
        if not pairs:
            print(f"  {C.DIM}(비어있음 — 서버 default `cs.AI:3,cs.LG:3,cs.CV:3` 사용){C.RESET}")
        else:
            for i, (code, n) in enumerate(pairs, 1):
                print(f"  [{i}] {C.CYAN}{code:<14}{C.RESET} → {n}편/주")
            print(f"      {C.DIM}─────────────────{C.RESET}")
            print(f"      {C.BOLD}합계: {sum(n for _, n in pairs)}편/주{C.RESET}")
        print()
        print(f"  {C.DIM}프리셋: {' / '.join(PRESETS_ARXIV.keys())}{C.RESET}")
        print()
        ans = prompt("> ")
        if not ans or ans.lower() == "q":
            return
        try:
            _arxiv_command(cfg, ans)
        except ValueError as e:
            err(str(e))
            prompt("(엔터로 계속)")


def _arxiv_command(cfg: Config, line: str) -> None:
    parts = line.split()
    if not parts:
        return
    cmd = parts[0].lower()
    pairs = cfg.arxiv_pairs()

    if cmd == "set" and len(parts) == 3:
        idx = int(parts[1])
        count = int(parts[2])
        if not 1 <= idx <= len(pairs):
            raise ValueError(f"번호 {idx} 범위 밖")
        if count < 1:
            raise ValueError("개수는 1 이상")
        pairs[idx - 1] = (pairs[idx - 1][0], count)
        cfg.set_arxiv_pairs(pairs)
    elif cmd == "add" and len(parts) >= 2:
        code = parts[1]
        if not is_valid_category(code):
            raise ValueError(f"잘못된 카테고리: {code}. 유효 archive: {sorted(VALID_ARXIV_ARCHIVES)}")
        count = int(parts[2]) if len(parts) > 2 else 3
        if any(c == code for c, _ in pairs):
            raise ValueError(f"{code} 이미 있음 — set 명령으로 변경하세요")
        pairs.append((code, count))
        cfg.set_arxiv_pairs(pairs)
    elif cmd == "remove" and len(parts) == 2:
        idx = int(parts[1])
        if not 1 <= idx <= len(pairs):
            raise ValueError(f"번호 {idx} 범위 밖")
        del pairs[idx - 1]
        cfg.set_arxiv_pairs(pairs)
    elif cmd == "preset" and len(parts) == 2:
        name = parts[1]
        if name not in PRESETS_ARXIV:
            raise ValueError(f"프리셋 없음: {name}. 가능: {list(PRESETS_ARXIV)}")
        cfg.set_arxiv_pairs(PRESETS_ARXIV[name])
        ok(f"프리셋 '{name}' 적용")
    elif cmd == "clear":
        cfg.set_arxiv_pairs([])
    elif cmd == "list":
        if CATEGORIES_DOC.exists():
            # Pipe through pager so user can scroll.
            with open(CATEGORIES_DOC) as f:
                pager = shutil.which("less") or shutil.which("more") or "cat"
                subprocess.run([pager], stdin=f)
        else:
            warn(f"{CATEGORIES_DOC.name} 파일 없음")
            prompt("(엔터로 계속)")
    else:
        raise ValueError(f"알 수 없는 명령: {line}")


def screen_pubmed(cfg: Config) -> None:
    while True:
        clear_screen()
        header("PubMed 쿼리")
        print()
        if cfg.pubmed_query:
            print(f"{C.DIM}현재:{C.RESET}")
            print(f"  {cfg.pubmed_query}")
        else:
            print(f"  {C.DIM}(빈 값 — 서버 fallback 사용){C.RESET}")
        print()
        print(f"  [1] 직접 입력")
        print(f"  [2] 프리셋 적용")
        print(f"  [3] 비우기 (서버 fallback 사용)")
        print(f"  [q] 뒤로")
        print()
        ans = prompt("> ").lower()
        if ans in ("q", ""):
            return
        if ans == "1":
            print(f"\n{C.DIM}전체 쿼리 한 줄로 입력 (Esc 같은 거 X, 그냥 엔터로 끝). 빈 값=취소{C.RESET}")
            new_q = prompt("query: ")
            if new_q:
                cfg.pubmed_query = new_q
        elif ans == "2":
            print()
            keys = list(PRESETS_PUBMED)
            for i, k in enumerate(keys, 1):
                preview = PRESETS_PUBMED[k][:80].replace("\n", " ")
                print(f"  [{i}] {C.CYAN}{k:<18}{C.RESET} {C.DIM}{preview}...{C.RESET}")
            print()
            sel = prompt("프리셋 번호: ")
            try:
                idx = int(sel)
                if 1 <= idx <= len(keys):
                    cfg.pubmed_query = PRESETS_PUBMED[keys[idx - 1]]
                    ok(f"프리셋 '{keys[idx - 1]}' 적용")
                    prompt("(엔터로 계속)")
            except ValueError:
                pass
        elif ans == "3":
            cfg.pubmed_query = ""


def screen_tokens(cfg: Config) -> None:
    while True:
        clear_screen()
        header("API 토큰")
        hint("번호 입력 → 토큰 값 입력 (빈 값 = 비활성). q = 뒤로")
        print()
        keys = list(cfg.tokens.keys())
        for i, k in enumerate(keys, 1):
            v = cfg.tokens[k]
            if v is None:
                status = f"{C.DIM}(미설정){C.RESET}"
            else:
                # Mask token (show only first 6 chars + length).
                masked = v[:6] + "…" if len(v) > 6 else v
                status = f"{C.GREEN}{masked}{C.RESET} ({len(v)}자)"
            print(f"  [{i}] {k:<18} {status}")
        print()
        ans = prompt("> ").lower()
        if ans in ("q", ""):
            return
        try:
            idx = int(ans)
            if not 1 <= idx <= len(keys):
                continue
            key = keys[idx - 1]
            new_val = prompt(f"  {key} = ")
            cfg.tokens[key] = new_val if new_val else None
        except ValueError:
            pass


def screen_show(cfg: Config) -> None:
    clear_screen()
    header("현재 설정")
    print()
    print(f"  {C.BOLD}활성 소스{C.RESET}")
    active = cfg.sources_set()
    for s in ALL_SOURCES:
        mark = f"{C.GREEN}[x]{C.RESET}" if s in active else "[ ]"
        print(f"    {mark} {s}")
    print()
    print(f"  {C.BOLD}arXiv 카테고리{C.RESET}")
    pairs = cfg.arxiv_pairs()
    if not pairs:
        print(f"    {C.DIM}(default){C.RESET}")
    else:
        for code, n in pairs:
            print(f"    {C.CYAN}{code:<14}{C.RESET} {n}편/주")
    print()
    print(f"  {C.BOLD}PubMed 쿼리{C.RESET}")
    if cfg.pubmed_query:
        print(f"    {cfg.pubmed_query}")
    else:
        print(f"    {C.DIM}(default fallback){C.RESET}")
    print()
    print(f"  {C.BOLD}API 토큰{C.RESET}")
    for k, v in cfg.tokens.items():
        marker = f"{C.GREEN}set{C.RESET}" if v else f"{C.DIM}-{C.RESET}"
        print(f"    {k:<20} {marker}")
    print()
    prompt("(엔터로 메인 메뉴) ")


# ---------------------------------------------------------------------------
# Save & restart
# ---------------------------------------------------------------------------

def save_and_restart(cfg: Config) -> None:
    print()
    cfg.save()
    ok(f"저장 완료 → {RUN_PY.name}  (백업: {BACKUP_PY.name})")

    # Kill stale MCP processes so Claude Desktop re-spawns with new config.
    try:
        result = subprocess.run(
            ["pkill", "-f", "trends_mcp"],
            capture_output=True, text=True,
        )
        if result.returncode == 0:
            ok("기존 trends_mcp 프로세스 종료")
        else:
            hint("(돌고 있던 trends_mcp 프로세스 없음)")
    except FileNotFoundError:
        warn("pkill 없음 — 수동으로 trends_mcp 프로세스 종료 필요")

    ok("Claude Desktop의 다음 trends 호출 시 새 설정으로 spawn됩니다.")
    print()
    prompt("(엔터) ")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> int:
    if not RUN_PY.exists():
        err(f"run.py 없음: {RUN_PY}")
        return 1

    # Single-shot modes
    if "--show" in sys.argv:
        cfg = Config.load()
        screen_show(cfg)
        return 0
    if "--restart" in sys.argv:
        try:
            subprocess.run(["pkill", "-f", "trends_mcp"], check=False)
            ok("trends_mcp 프로세스 종료")
        except FileNotFoundError:
            err("pkill 없음")
            return 1
        return 0

    cfg = Config.load()
    dirty = False

    while True:
        choice = screen_main(cfg)
        if choice == "1":
            before = cfg.enabled_sources
            screen_sources(cfg)
            if cfg.enabled_sources != before:
                dirty = True
        elif choice == "2":
            before = cfg.arxiv_categories
            screen_arxiv(cfg)
            if cfg.arxiv_categories != before:
                dirty = True
        elif choice == "3":
            before = cfg.pubmed_query
            screen_pubmed(cfg)
            if cfg.pubmed_query != before:
                dirty = True
        elif choice == "4":
            before = dict(cfg.tokens)
            screen_tokens(cfg)
            if cfg.tokens != before:
                dirty = True
        elif choice == "5":
            screen_show(cfg)
        elif choice == "6":
            save_and_restart(cfg)
            return 0
        elif choice == "7":
            if dirty:
                ans = prompt(f"{C.YELLOW}변경사항이 있습니다. 정말 취소? (y/N): {C.RESET}").lower()
                if ans != "y":
                    continue
            print("종료.")
            return 0
        else:
            warn(f"알 수 없는 선택: {choice!r}")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print()
        sys.exit(0)
