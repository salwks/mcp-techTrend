# CHOI Threads Monitor

Monitors the public Threads account `@choi.openai` for the ChatGPT 6-hour briefing workflow.

## Data model

The monitor now uses a **pending queue** instead of a permanent cumulative post archive:

- `choi_threads_monitor/data/choi_latest.json`: newest primary crawler snapshot and collection health.
- `choi_threads_monitor/data/choi_archive.json`: **only posts that have been observed but not yet acknowledged by a ChatGPT report**.
- `choi_threads_monitor/data/choi_report_state.json`: recent acknowledgement keys for already-emitted posts. Keep at most the newest 300 IDs/permalinks.

Once a post has been delivered in a successful report, its ID/permalink is added to `choi_report_state.json`. A state change triggers the monitor workflow, and the next collector pass removes that acknowledged post from `choi_archive.json`. If the same Threads post appears again in later crawler snapshots, its recent acknowledgement key prevents it from being re-added.

This means old full post bodies and media URLs no longer accumulate indefinitely.

## Dual collector watchdog

There are two collector runtimes:

1. **GitHub Actions primary collector** — scheduled by the four shard workflows.
2. **Render backup watchdog** — polls every 5 minutes and retains an in-memory observation window.

Before GitHub writes the pending queue, `collect.py` asks Render for `/archive`. A post seen only by the backup can therefore enter the pending queue even if a GitHub schedule was delayed.

Both runtimes use anonymous public Threads access, so they are independent runtimes but not independent upstream APIs. A post can still be missed if it disappears before either collector observes it.

## Reporting / acknowledgement flow

A 6-hour report should:

1. read `choi_latest.json` first and report collection freshness/limitations;
2. read `choi_archive.json` as the authoritative **unreported-post queue**;
3. read `choi_report_state.json` for recent acknowledgement keys;
4. from the pending queue, put posts in the exact last-six-hour wall-clock interval into the main section;
5. put older pending posts into the delayed-collection catch-up section;
6. after a successful report, add every actually emitted post ID (or permalink when no ID exists) to `choi_report_state.json`;
7. deduplicate and retain only the newest 300 acknowledgement keys;
8. re-read the state after writing and verify that every emitted key is present;
9. if state verification fails, do not delete pending posts and report the state-write failure.

Updating `choi_report_state.json` triggers `.github/workflows/choi-threads-monitor.yml`, so acknowledged posts are pruned from the pending queue promptly. The workflow does not trigger on its own latest/archive data commit, avoiding a loop.

## Why this is safer

- **Late discovery:** a post remains pending until it has actually been reported.
- **State-write failure:** the post stays in the pending queue, so it may repeat but will not be silently lost.
- **Successful report:** the post is acknowledged and then physically removed from the pending queue.
- **Storage:** old post text/media is deleted instead of accumulating forever.
- **Deduplication:** only a rolling recent acknowledgement window is kept.

The design prioritizes avoiding permanent omissions over avoiding a rare duplicate.
