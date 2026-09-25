#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ACCOUNT = "choi.openai"
LIMIT = 100
ROOT = Path(__file__).resolve().parent
DATA_DIR = ROOT / "data"
OUTPUT = DATA_DIR / "choi_latest.json"
ARCHIVE = DATA_DIR / "choi_archive.json"
BACKUP_BASE_URL = os.environ.get(
    "CHOI_BACKUP_BASE_URL",
    "https://choi-threads-backup-collector.onrender.com",
).rstrip("/")
# The archive is cumulative; scheduled snapshot gaps must not create permanent report omissions.


def now_iso():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def load_json(path):
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
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


def post_key(post):
    return post.get("post_id") or post.get("permalink")


def dedupe_posts(posts):
    merged = {}
    for post in posts:
        key = post_key(post)
        if key:
            merged[key] = post
    return list(merged.values())


def combine_observations(primary_posts, backup_posts):
    # Backup fills gaps; the primary snapshot wins if both saw the same post.
    merged = {}
    for post in backup_posts:
        key = post_key(post)
        if key:
            merged[key] = post
    for post in primary_posts:
        key = post_key(post)
        if key:
            merged[key] = post
    return list(merged.values())


def archive_view(post):
    return {
        "post_id": post.get("post_id"),
        "published_at": post.get("published_at"),
        "text": post.get("text"),
        "permalink": post.get("permalink"),
        "media": post.get("media"),
        "engagement": post.get("engagement"),
    }


def merge_archive(previous_archive, posts, seen_at):
    existing = {}
    for item in previous_archive.get("posts", []):
        key = post_key(item)
        if key:
            existing[key] = dict(item)

    # If the archive did not exist yet, seed it from the last successful snapshot.
    if not existing:
        previous_latest = load_json(OUTPUT)
        seed_seen_at = previous_latest.get("latest_good_generated_at") or previous_latest.get("generated_at") or seen_at
        for item in previous_latest.get("posts", []):
            key = post_key(item)
            if key:
                lean = archive_view(item)
                lean["first_seen_at"] = seed_seen_at
                lean["last_seen_at"] = seed_seen_at
                existing[key] = lean

    for post in posts:
        key = post_key(post)
        if not key:
            continue
        lean = archive_view(post)
        if key in existing:
            first_seen_at = existing[key].get("first_seen_at") or seen_at
            existing[key].update(lean)
            existing[key]["first_seen_at"] = first_seen_at
            existing[key]["last_seen_at"] = seen_at
        else:
            lean["first_seen_at"] = seen_at
            lean["last_seen_at"] = seen_at
            existing[key] = lean

    merged = list(existing.values())
    merged.sort(key=lambda p: p.get("published_at") or "", reverse=True)
    return {
        "account": ACCOUNT,
        "generated_at": seen_at,
        "source": "merged observations from GitHub Actions primary collector and Render backup watchdog",
        "archive_count": len(merged),
        "limitations": [
            "Archive contains only posts observed by at least one successful collector.",
            "The primary and backup collectors are independent runtimes but both rely on anonymous Threads public access.",
            "A post can still be missed if it disappears before either collector observes it.",
            "Use report_state catch-up logic so posts discovered late are emitted exactly once.",
        ],
        "posts": merged,
    }


def fetch_json(url, timeout=75):
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "choi-threads-monitor-watchdog/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_backup_posts():
    errors = []
    for endpoint in ("/archive", "/collect"):
        url = BACKUP_BASE_URL + endpoint
        try:
            payload = fetch_json(url)
            if isinstance(payload, dict) and isinstance(payload.get("posts"), list):
                raw_posts = payload["posts"]
            elif isinstance(payload, dict) and "payload" in payload:
                raw_posts = extract_posts(payload["payload"])
            else:
                raw_posts = extract_posts(payload)

            normalized = dedupe_posts(normalize_post(post) for post in raw_posts)
            if not normalized:
                raise RuntimeError("backup collector returned no posts")

            meta = {
                "endpoint": endpoint,
                "collected_at": first(payload, "collected_at", "generated_at") if isinstance(payload, dict) else None,
                "archive_count": payload.get("archive_count") if isinstance(payload, dict) else None,
                "collection_ok": payload.get("collection_ok") if isinstance(payload, dict) else None,
            }
            return normalized, meta
        except Exception as exc:
            errors.append(f"{endpoint}: {exc}")

    raise RuntimeError("; ".join(errors))


def write_json(path, payload):
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    previous = load_json(OUTPUT)
    previous_archive = load_json(ARCHIVE)
    generated_at = now_iso()
    archive_payload = None
    primary_posts = []
    backup_posts = []

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
        "watchdog": {
            "status": "not_checked",
            "checked_at": generated_at,
            "backup_base_url": BACKUP_BASE_URL,
            "backup_post_count": 0,
            "backup_only_current_count": 0,
            "recovered_to_archive_count": 0,
        },
    }

    primary_error = None
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
        primary_posts = dedupe_posts(normalize_post(p) for p in extract_posts(raw))

        if not primary_posts:
            base["collection_status"] = "degraded"
            base["limitations"] = [
                "Primary collector returned no public posts. Previous successful latest snapshot was preserved.",
                "The Render watchdog may still recover posts into choi_archive.json.",
            ]
        else:
            base.update({
                "collection_status": "ok",
                "latest_good_generated_at": generated_at,
                "limitations": [
                    "Anonymous crawler surface exposes recent public posts, not guaranteed full account history.",
                    "At most 100 recent records are collected per primary run.",
                    "Use choi_archive.json for reporting; the Render watchdog can recover posts missed between primary runs.",
                ],
                "post_count": len(primary_posts),
                "posts": primary_posts,
            })
    except Exception as exc:
        primary_error = str(exc)
        base["collection_status"] = "error"
        base["error"] = primary_error
        base["limitations"] = [
            "Current primary collection failed; previous successful latest snapshot was preserved.",
            "The Render watchdog is checked independently and can still add observed posts to the archive.",
            "Do not infer or fabricate missing posts.",
        ]

    backup_meta = {}
    try:
        backup_posts, backup_meta = fetch_backup_posts()
        primary_keys = {post_key(p) for p in primary_posts if post_key(p)}
        previous_keys = {post_key(p) for p in previous_archive.get("posts", []) if post_key(p)}
        backup_keys = {post_key(p) for p in backup_posts if post_key(p)}
        recovered_keys = sorted(backup_keys - primary_keys - previous_keys)
        backup_only_keys = backup_keys - primary_keys

        base["watchdog"] = {
            "status": "ok",
            "checked_at": generated_at,
            "backup_base_url": BACKUP_BASE_URL,
            "endpoint": backup_meta.get("endpoint"),
            "backup_collected_at": backup_meta.get("collected_at"),
            "backup_archive_count": backup_meta.get("archive_count"),
            "backup_post_count": len(backup_posts),
            "backup_only_current_count": len(backup_only_keys),
            "recovered_to_archive_count": len(recovered_keys),
            "recovered_keys": recovered_keys,
            "limitations": [
                "The watchdog is an independent runtime, but it uses the same anonymous Threads crawler family.",
                "Its in-memory archive is drained into GitHub before commit-triggered Render redeploys.",
            ],
        }

        if primary_error is not None:
            base["collection_status"] = "degraded"
            base["limitations"].append(
                "Primary collection failed, but the independent Render watchdog responded successfully."
            )
    except Exception as exc:
        base["watchdog"] = {
            "status": "error",
            "checked_at": generated_at,
            "backup_base_url": BACKUP_BASE_URL,
            "backup_post_count": 0,
            "backup_only_current_count": 0,
            "recovered_to_archive_count": 0,
            "error": str(exc),
            "limitations": [
                "Backup watchdog was unavailable for this run; the primary collector result is still usable if collection_status is ok.",
            ],
        }

    observed_posts = combine_observations(primary_posts, backup_posts)
    if observed_posts:
        archive_payload = merge_archive(previous_archive, observed_posts, generated_at)
        archive_payload["watchdog"] = {
            "status": base["watchdog"].get("status"),
            "recovered_to_archive_count": base["watchdog"].get("recovered_to_archive_count", 0),
            "backup_only_current_count": base["watchdog"].get("backup_only_current_count", 0),
        }

    if not primary_posts and not backup_posts and primary_error is not None:
        base["collection_status"] = "error"

    write_json(OUTPUT, base)
    if archive_payload is not None:
        write_json(ARCHIVE, archive_payload)

    print(json.dumps({
        "collection_status": base["collection_status"],
        "post_count": base["post_count"],
        "generated_at": base["generated_at"],
        "archive_count": archive_payload.get("archive_count") if archive_payload else previous_archive.get("archive_count"),
        "watchdog_status": base["watchdog"].get("status"),
        "watchdog_backup_post_count": base["watchdog"].get("backup_post_count"),
        "watchdog_recovered_count": base["watchdog"].get("recovered_to_archive_count"),
        "error": base.get("error"),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
