# Daily AI News — production intake and editorial pipeline

Updated: 2026-10-30 (Asia/Seoul)

## Sources and schedules

| Source | Collection | DB ingestion | Production treatment |
|---|---|---|---|
| CHOI Threads | existing monitor/Render backup | existing backup trigger | six-hour `batch.posts` |
| Techmeme / Hacker News | GitHub hourly at UTC :17 | Flyfly pg_cron UTC :33 fetch, :39/:43 persist | six-hour `batch.posts` |
| OpenAI/DeepMind/BAIR notices | GitHub 12:00 KST | Flyfly 12:35 / 12:50 fetch, 12:42 / 12:57 persist | six-hour `batch.posts` after first discovery |
| Hugging Face Daily Papers | GitHub 12:00 KST, completeness check 23:30 KST | Flyfly after noon and at 23:44/23:53, persisted before midnight | separate daily papers and research report |
| Daily research analysis | once after nightly completeness check, 00:30 KST | ChatGPT automation | previous calendar date report |

GitHub Actions may be delayed. Check `public.ai_news_feed_fetches` and
`public.ai_research_daily_reports` for processing results; a successful HTTP enqueue is not an ingestion guarantee.

## Database locations

- Collection and six-hour reports: Supabase Flyfly `rnwysxxamizxzgisdcgj`.
- Final newsletter and delivery records: Supabase Daily AI News `tiabwoiuohfvtqutulsb`.
- Existing authoritative news input: `public.ai_news_6h_batches.posts`.
- Full Hugging Face paper-day roster: `public.ai_research_daily_papers` (one row per date and paper).
- One finished academic editorial report: `public.ai_research_daily_reports` (major/minor items, report text, source ID coverage).
- HTTP fetch status: `public.ai_news_feed_fetches`.

All new ingestion is idempotent by news source key or (paper date, paper ID).
Original publication timestamps remain unchanged. Non-Threads news use immutable
`collected_at` (the first observation time) to select a six-hour processing window,
so late-discovered material is not silently assigned to an already-closed report.

## Authoritative six-hour windows

Supabase's existing window endpoints (KST): 01:45, 07:45, 13:45, 19:45.
Its pg_cron builds the batch at :47, then the ChatGPT six-hour reporter reads
`batch.posts` and stores `ai_news_6h_reports` at approximately :50.

GitHub's `six_hour_intake.*` is **only a rolling operator preview**.
It is not the production report input and does not contain the full daily paper list.
The operator preview is refreshed after hourly external collection and at fixed boundaries.

## Academic edition date

The Daily AI News edition for date D (KST) uses the research report
for paper_date D-1. The function `public.get_daily_ai_news_report_bundle(D)`
returns both the four news-report records and:
`academic_date`, `academic_paper_count`, `academic_report`, `academic_complete`.

`academic_complete=true` requires a ready report, matching source counts and complete paper-ID coverage.
If late-day reconciliation adds papers, ingestion marks the previous report pending
until all new IDs are analyzed. Do not use an incomplete academic report as complete.

## One-email layout

Use `daily_ai_news/email_template.html` for **one** email with the top navigation
and these in-body sections: (1) 주요 뉴스; (2) AI 단신; (3) 학술 연구.
Academic majors receive detailed background/method/results/meaning/limitations;
minors each receive a short Korean brief and a paper source link.
Mail-client support for intra-email anchor navigation varies.

## Remaining permission-dependent stage

The user-approved publication workflow keeps final edition authoring/validation
in the designated main Daily AI News conversation. Existing 07:50 and 08:15
automations are status checks only and may not create drafts or send messages.
Automatic creation of the final `newsletter_editions` HTML from two Supabase
projects is not enabled, and mail transmission remains explicitly user-directed.

The newly created daily academic analysis automation requires a user approval
to access its connected resources (its immediate test run returned
`requires_user_action=true`). On 2026-10-30, the 26-item academic edition
was manually stored and verified, but future scheduled automated writes
are **not proven** until the authorization and next-run validation succeed.

arXiv and OpenAlex direct API enrichment are optional verification enhancements,
not yet configured as scheduled collectors.
