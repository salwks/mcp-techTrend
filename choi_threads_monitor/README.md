# CHOI Threads Monitor

Monitors the public Threads account `@choi.openai` for the ChatGPT 6-hour briefing workflow.

## Data

The monitor now separates three responsibilities:

- `choi_threads_monitor/data/choi_latest.json`: newest crawler snapshot and collection health.
- `choi_threads_monitor/data/choi_archive.json`: cumulative deduplicated posts observed by successful collection runs.
- `choi_threads_monitor/data/choi_report_state.json`: post IDs already emitted by the 6-hour briefing, used to prevent permanent omissions when collection is delayed.

The collector keeps up to 100 recent public posts per fetch, but merges every successfully observed post into the cumulative archive. If collection fails, the previous successful snapshot is preserved and the status changes to `error` or `degraded`.

## Collector

The workflow installs [tamnd/threads-cli](https://github.com/tamnd/threads-cli) and runs its anonymous public crawler. No Threads login or API token is required.

GitHub Actions is scheduled every 15 minutes and can also be run manually. GitHub scheduled workflows can still be delayed, so reporting must not assume that the latest snapshot fully covers the wall-clock report window.

## Reporting logic

A downstream 6-hour report should:

1. read `choi_latest.json` first for `collection_status`, `generated_at`, `latest_good_generated_at`, `limitations`, and `post_count`;
2. read `choi_archive.json` as the authoritative observed-post set;
3. select the exact wall-clock last 6 hours by `published_at` for the main report;
4. deduplicate by `post_id` or `permalink`;
5. read `choi_report_state.json` and automatically add any previously unreported archived post older than the current 6-hour window under a separate delayed-collection catch-up section;
6. after a successful report, add every emitted post ID to `choi_report_state.json`;
7. if the latest successful collection is stale, state that the newest interval may still be incomplete, but do not permanently lose those posts: once they are observed later, rule 5 surfaces them exactly once.

This prevents a stale snapshot from causing a post to disappear forever between adjacent 6-hour reports. It cannot recover a post that was never visible to any successful anonymous crawler run.
