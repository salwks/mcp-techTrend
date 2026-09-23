# CHOI Threads Monitor

Monitors the public Threads account `@choi.openai` for the ChatGPT 6-hour briefing workflow.

## Data

The current snapshot is written to:

`choi_threads_monitor/data/choi_latest.json`

The collector keeps up to 100 recent public posts and never fabricates missing content. If collection fails, the previous successful post payload is preserved and the status is changed to `error` or `degraded`.

## Collector

The workflow installs [tamnd/threads-cli](https://github.com/tamnd/threads-cli) and runs its anonymous public crawler. No Threads login or API token is required.

GitHub Actions runs twice an hour and can also be run manually.

The downstream report should:
1. read this JSON,
2. use only posts whose timestamp falls within the requested 6-hour window,
3. deduplicate by post ID or permalink,
4. report collection limitations when status is not `ok`.
