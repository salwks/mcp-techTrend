# CHOI Threads Monitor

Monitors the public Threads account `@choi.openai` for the ChatGPT 6-hour briefing workflow.

## Data

The monitor separates three reporting responsibilities:

- `choi_threads_monitor/data/choi_latest.json`: newest primary crawler snapshot and collection health.
- `choi_threads_monitor/data/choi_archive.json`: cumulative deduplicated posts observed by either collector.
- `choi_threads_monitor/data/choi_report_state.json`: post IDs/permalinks already emitted by the 6-hour briefing.

The collector keeps up to 100 recent public posts per primary fetch and merges every observed post into the cumulative archive. If the primary collection fails, the previous successful latest snapshot is preserved.

## Dual collector watchdog

There are now two independent runtimes:

1. **GitHub Actions primary collector** — scheduled every 15 minutes.
2. **Render backup watchdog** — polls every 5 minutes and retains an in-memory archive of every post seen since the current Render boot.

Before each GitHub run writes its new archive, `collect.py` asks the Render service for `/archive`. Any post present in the backup archive but missing from both the current primary snapshot and the existing GitHub archive is merged into `choi_archive.json` as a watchdog recovery.

This is designed around the current Render deployment behavior: monitor data commits may restart the Render service, so the GitHub collector drains the Render in-memory archive **before** its commit. The next Render boot then starts a fresh observation window.

`choi_latest.json` includes a `watchdog` object with:

- `status`
- `backup_collected_at`
- `backup_post_count`
- `backup_only_current_count`
- `recovered_to_archive_count`
- `recovered_keys`

A watchdog failure does not invalidate a successful primary snapshot, but it means the independent safety net was unavailable for that run.

## Scheduling

The four shard workflows run at minute 7, 22, 37 and 52 of every hour. They share the same concurrency group so delayed GitHub schedules serialize instead of racing each other.

The umbrella `choi-threads-monitor.yml` remains available for manual runs and code-change triggers, but does not also carry a cron schedule. This avoids duplicate collectors running at the same minute and causing duplicate commits/redeploys.

The Render watchdog polls every 5 minutes. Both collectors use anonymous public Threads access, so they are independent runtimes but not independent upstream APIs.

## Reporting logic

A downstream 6-hour report should:

1. read `choi_latest.json` first for `collection_status`, `generated_at`, `latest_good_generated_at`, `limitations`, `post_count`, and `watchdog`;
2. read `choi_archive.json` as the authoritative observed-post set;
3. select the exact wall-clock last 6 hours by `published_at` for the main report;
4. deduplicate by `post_id` or `permalink`;
5. read `choi_report_state.json` and automatically add any previously unreported archived post older than the current 6-hour window under a separate delayed-collection catch-up section;
6. after a successful report, add every emitted post ID/permalink to `choi_report_state.json`;
7. if the latest successful primary collection is stale or the watchdog failed, state that the newest interval may still be incomplete;
8. never invent posts that are absent from the GitHub archive.

This combination addresses two different failure modes:

- **late discovery**: archive + report_state catch-up prevents an observed post from falling permanently between report windows;
- **primary snapshot miss**: the 5-minute Render in-memory watchdog can recover a post observed between GitHub runs.

It still cannot guarantee recovery of a post that disappears before **both** anonymous collectors observe it.
