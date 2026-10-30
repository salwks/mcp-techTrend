# Daily AI News — 운영 파이프라인

Updated: 2026-10-30 (Asia/Seoul)

## 소스 범위 및 주기

| 구분 | 정보원 | 원천 수집 | 분석·저장 |
|---|---|---|---|
| 일반 AI 뉴스 | CHOI Threads, Hacker News Firebase, Techmeme RSS | 기존 CHOI 수집 + HN/Techmeme 매시 17분 (GitHub) | 01:50, 07:50, 13:50, 19:50 KST 6시간 리포트 |
| 학술 논문 | **Hugging Face Daily Papers만** | **12:00 KST 하루 1회** (GitHub Actions) | 12:35 KST DB 조회 요청 → 12:43 적재 → 12:55 일일 AI 분석 예정 |
| Daily AI News | 위 6시간 리포트 4개 + 전날 HF 학술 리포트 1개 | 매일 07:50 KST 준비 확인 | 최종본은 메인 대화에서 검수·저장 후 사용자 지시로 발송 |

**학술 소스는 Hugging Face Daily Papers 단일 소스입니다.**
OpenAI / Google DeepMind / Berkeley AI Research RSS와 arXiv / OpenAlex API는 학술 수집에 사용하지 않습니다.
OpenAI 등 주요 기업 소식이 Techmeme·Hacker News에 뉴스로 등장한 경우에는 **일반 뉴스**로 처리할 수 있습니다.

2026-10-30 운영 변경:
- 연구기관 RSS 수집 코드와 GitHub 연구 스냅샷 내 해당 20건을 제거했습니다.
- Supabase 연구기관 발표 cron 2개와 HF 야간 보정 cron 2개를 해제했습니다.
- 연구기관 발표 뉴스 원본으로 적재됐던 20건은 배치·보고서 반영 기록이 없음을 확인한 뒤 삭제했습니다.
- Hugging Face API는 정오 GitHub 예약 1회, Supabase 적재 1회로 조정했습니다. 예약 재시도나 사람의 `workflow_dispatch`를 제외하면 다른 정기 학술 수집은 없습니다.
- 학술 AI 분석 작업은 00:30 대신 정오 수집 이후인 12:55 KST 하루 1회로 변경했습니다.

GitHub Actions 예약은 지연될 수 있으며, **12:00 정오 스냅샷은 반드시 그날 자정까지 뒤늦게 올라오는 모든 논문을 포함한다는 보장이 없습니다.** 사용자가 요청한 하루 한 번 수집 정책을 우선합니다.

## 데이터 및 신뢰성

- 수집·6시간 리포트 DB: Supabase Flyfly `rnwysxxamizxzgisdcgj`.
- 뉴스 원본: `public.ai_news_raw` (CHOI, Hacker News, Techmeme).
- 뉴스 배치: `public.ai_news_6h_batches.posts` — 6시간 리포트의 **유일한 입력**.
- 뉴스 보고서: `public.ai_news_6h_reports`.
- Hugging Face 원본: `public.ai_research_daily_papers`, 유일 키 (paper_date, paper_id).
- 학술 보고서: `public.ai_research_daily_reports`, 메이저·마이너·전체 ID 커버리지 저장.
- 수집 요청·결과 기록: `public.ai_news_feed_fetches` (과거 실행 기록은 보존).
- 최종 뉴스레터: 별도 Supabase Daily AI News 프로젝트 `tiabwoiuohfvtqutulsb`, `public.newsletter_editions`.

일반 뉴스는 기존 fixed window 종료 시각(KST 01:45, 07:45, 13:45, 19:45)을 사용하고,
배치는 종료 후 약 2분에 생성합니다. 외부 뉴스의 회차 배정은 최초 관찰 시각, CHOI는 게시 시각을 사용합니다.
GitHub `six_hour_intake.*`는 운영 미리보기일 뿐 실제 6시간 분석 입력은 아닙니다.

## 발행 전 통합

발행일 D의 `public.get_daily_ai_news_report_bundle(D)`가
직전 24시간의 6시간 뉴스 리포트 4개와 **D-1 날짜 Hugging Face 학술 리포트**를 함께 반환합니다.
`academic_complete=true`는 전체 논문 ID 커버리지와 저장 상태가 일치할 때만 표시됩니다.

HTML 이메일은 `daily_ai_news/email_template.html`의 3개 섹션,
(1) 주요 뉴스 / (2) AI 단신 / (3) 학술 연구를 사용하도록 작성됐습니다.
단 **최종 발행본 HTML에 실제 적용하는 코드는 아직 연결되지 않았으며, 자동 발송도 활성화되지 않았습니다.**
기존의 07:50/08:15 작업은 확인 업무이며, 본문 편집과 발송은 지정된 메인 대화에서만 진행합니다.

학술 분석 자동화는 재활성화돼 있지만 이전 실행의 `requires_user_action=true`가 남아 있어
다음 예약 실행의 실제 DB 쓰기가 성공할 때까지 완전 자동 운영은 미검증 상태입니다.
