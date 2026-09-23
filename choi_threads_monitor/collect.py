#!/usr/bin/env python3
# Workflow trigger: monitor initialized after workflow registration.
# PR smoke test marker.
import json
import os
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ACCOUNT = "choi.openai"
LIMIT = 100
ROOT = Path(__file__).resolve().parent
DATA_DIR = ROOT / "data"
OUTPUT = DATA_DIR / "choi_latest.json"

def now_iso():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def load_previous():
    if not OUTPUT.exists():
        return {}
    try:
        return json.loads(OUTPUT.read_text(encoding="utf-8"))
    except Exception:
        return {}

def find_th():
    candidates = [
        shutil.which("th"),
        str(Path.home() / "go" / "bin" / "th"),
        os.environ.get("TH_BIN"),
    ]
    for candidate in candidates:
        if candidate and Path(candidate).exists():
            return candidate
    raise FileNotFoundError("threads-cli binary 'th' not found")

def first(obj, *keys):
    if not isinstance(obj, dict):
        return None
    for key in keys:
        value = obj.get(key)
        if value not in (None, "", [], {}):
            return value
    return None

def normalize_post(post):
    if not isinstance(post, dict):
        return {"raw": post}
    return {
        "post_id": first(post, "post_id", "id", "pk", "code"),
        "published_at": first(post, "published_at", "timestamp", "taken_at", "created_at", "created_time"),
        "text": first(post, "text", "caption", "body", "content"),
        "permalink": first(post, "permalink", "url", "link"),
        "media": first(post, "media_urls", "media", "image_urls", "video_url"),
        "engagement": {
            "likes": first(post, "like_count", "likes"),
            "replies": first(post, "reply_count", "replies"),
            "reposts": first(post, "repost_count", "reposts"),
            "quotes": first(post, "quote_count", "quotes"),
        },
        "raw": post,
    }

def extract_posts(payload):
    if isinstance(payload, list):
        return payload
    if isinstance(payload, dict):
        for key in ("posts", "items", "data", "results"):
            value = payload.get(key)
            if isinstance(value, list):
                return value
        return [payload]
    return []

def write_payload(payload):
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def main():
    previous = load_previous()
    generated_at = now_iso()
    base = {
        "account": ACCOUNT,
        "generated_at": generated_at,
        "source": "tamnd/threads-cli anonymous public crawler",
        "collection_limit": LIMIT,
        "collection_status": "error",
        "latest_good_generated_at": previous.get("latest_good_generated_at"),
        "limitations": [],
        "post_count": len(previous.get("posts", [])),
        "posts": previous.get("posts", []),
    }

    try:
        th = find_th()
        proc = subprocess.run(
            [th, "profile", ACCOUNT, "--posts", "-n", str(LIMIT), "-o", "json", "--no-cache"],
            capture_output=True,
            text=True,
            timeout=180,
        )
        if proc.returncode != 0:
            raise RuntimeError(
                f"threads-cli exited {proc.returncode}: "
                + (proc.stderr.strip() or proc.stdout.strip() or "unknown error")
            )

        raw = json.loads(proc.stdout)
        posts = extract_posts(raw)
        normalized = [normalize_post(p) for p in posts]

        if not normalized:
            base["collection_status"] = "degraded"
            base["limitations"] = [
                "Collector returned no public posts. Previous successful posts, if any, were preserved.",
                "Anonymous Threads access exposes only the recent public window and can change without notice.",
            ]
        else:
            base.update({
                "collection_status": "ok",
                "latest_good_generated_at": generated_at,
                "limitations": [
                    "Anonymous crawler surface exposes recent public posts, not guaranteed full account history.",
                    "At most 100 recent records are collected per run; the report layer should filter the requested time window by published_at.",
                ],
                "post_count": len(normalized),
                "posts": normalized,
            })
    except Exception as exc:
        base["collection_status"] = "error"
        base["error"] = str(exc)
        base["limitations"] = [
            "Current collection failed; previous successful posts, if any, were preserved.",
            "Do not infer or fabricate missing posts.",
        ]

    write_payload(base)
    print(json.dumps({
        "collection_status": base["collection_status"],
        "post_count": base["post_count"],
        "generated_at": base["generated_at"],
        "error": base.get("error"),
    }, ensure_ascii=False))

if __name__ == "__main__":
    main()
