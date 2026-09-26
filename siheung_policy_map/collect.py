#!/usr/bin/env python3
"""시흥시 정책·사업 소식 수집기 (주 1회 GitHub Actions에서 실행).

시흥시청 게시판(보도자료, 고시·공고)의 최신 목록을 읽어 제목·날짜·링크를 모으고,
본문에 나오는 동 이름/지명으로 대략적인 위치를 붙여 data/projects.json 에 누적 저장한다.
외부 의존성 없이 표준 라이브러리만 사용한다.
"""
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATA_DIR = ROOT / "data"
OUTPUT = DATA_DIR / "projects.json"
SOURCES_FILE = ROOT / "sources.json"
PLACES_FILE = ROOT / "places.json"

KST = timezone(timedelta(hours=9))
USER_AGENT = "Mozilla/5.0 (compatible; siheung-policy-map/0.1; +https://github.com/salwks/mcp-techTrend)"
REQUEST_DELAY = 1.0      # 시청 서버 부담을 줄이기 위한 요청 간격(초)
MAX_DETAIL_FETCH = 60    # 1회 실행에서 본문을 새로 읽을 최대 건수
BODY_CHARS = 4000        # 위치 추정에 쓰는 본문 길이

CATEGORIES = [
    ("복지", ["복지", "돌봄", "노인", "어르신", "장애인", "아동", "보육", "출산", "기초생활", "취약계층", "건강", "보건", "의료"]),
    ("교통", ["교통", "도로", "버스", "철도", "전철", "지하철", "주차", "신안산선", "월곶판교", "서해선", "교차로", "보행"]),
    ("도시개발", ["개발", "재개발", "재건축", "도시계획", "지구단위", "택지", "공공주택", "주택", "건축", "착공", "준공", "정비", "토지", "용도지역", "도시관리계획"]),
    ("환경", ["환경", "공원", "녹지", "하천", "갯골", "탄소", "기후", "미세먼지", "폐기물", "재활용", "수질", "생태", "숲"]),
    ("경제·일자리", ["일자리", "창업", "기업", "소상공인", "상권", "전통시장", "경제", "고용", "산업", "스마트허브", "시화MTV", "투자"]),
    ("문화·관광", ["문화", "관광", "축제", "공연", "전시", "체육", "스포츠", "도서관", "거북섬", "오이도", "예술"]),
    ("교육·청년", ["교육", "학교", "청년", "청소년", "학생", "평생학습", "장학"]),
    ("안전", ["안전", "재난", "방범", "CCTV", "소방", "침수", "폭염", "한파", "감염병"]),
]

DATE_RE = re.compile(r"(20\d{2})[-./](\d{1,2})[-./](\d{1,2})")
WS_RE = re.compile(r"\s+")


def now_iso():
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def load_json(path, default):
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def fetch(url, timeout=30, retries=3):
    """시청 서버가 해외(GitHub Actions) 연결을 간헐적으로 끊어서 재시도한다."""
    for attempt in range(retries):
        try:
            return _fetch_once(url, timeout)
        except (urllib.error.URLError, TimeoutError, OSError):
            if attempt == retries - 1:
                raise
            time.sleep(5 * (attempt + 1))


def _fetch_once(url, timeout):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept-Language": "ko-KR,ko;q=0.9"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read()
        charset = resp.headers.get_content_charset()
    for enc in [charset, "utf-8", "euc-kr", "cp949"]:
        if not enc:
            continue
        try:
            return raw.decode(enc)
        except (LookupError, UnicodeDecodeError):
            continue
    return raw.decode("utf-8", errors="replace")


def clean(text):
    return WS_RE.sub(" ", text or "").strip()


def parse_date(text):
    m = DATE_RE.search(text or "")
    if not m:
        return None
    y, mo, d = (int(x) for x in m.groups())
    try:
        return datetime(y, mo, d).strftime("%Y-%m-%d")
    except ValueError:
        return None


class RowParser(HTMLParser):
    """게시판 목록의 행(<tr> 또는 <li>)마다 텍스트와 링크를 모은다.

    시청 게시판 마크업이 바뀌어도 동작하도록 특정 class 에 의존하지 않고,
    '날짜가 있고 링크가 있는 행'을 게시물로 본다.
    """

    ROW_TAGS = ("tr", "li")

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.rows = []
        self.stack = []  # 열린 행들(중첩 li 대응)
        self.in_script = False

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style"):
            self.in_script = True
            return
        attrs = dict(attrs)
        if tag in self.ROW_TAGS:
            self.stack.append({"text": [], "links": []})
        elif tag == "a" and self.stack:
            self.stack[-1]["links"].append({"href": attrs.get("href") or "", "onclick": attrs.get("onclick") or "",
                                            "title": attrs.get("title") or "", "text": [], "open": True})

    def handle_endtag(self, tag):
        if tag in ("script", "style"):
            self.in_script = False
        elif tag == "a" and self.stack and self.stack[-1]["links"]:
            self.stack[-1]["links"][-1]["open"] = False
        elif tag in self.ROW_TAGS and self.stack:
            row = self.stack.pop()
            self.rows.append(row)
            if self.stack:  # 부모 행에도 텍스트를 이어 붙인다
                self.stack[-1]["text"].extend(row["text"])

    def handle_data(self, data):
        if self.in_script or not self.stack:
            return
        row = self.stack[-1]
        row["text"].append(data)
        if row["links"] and row["links"][-1]["open"]:
            row["links"][-1]["text"].append(data)


def is_nav_link(href):
    return not href or href.startswith("#") or href.lower().startswith(("javascript:", "mailto:", "tel:"))


def resolve_link(link, base_url, source):
    href = link["href"].strip()
    if not is_nav_link(href):
        return urllib.parse.urljoin(base_url, href)
    # onclick="fn_view('12345')" 형태 → sources.json 의 view_template 로 URL 구성
    template = source.get("view_template")
    code = link["onclick"] + " " + href
    m = re.search(r"\(\s*['\"]?([A-Za-z0-9_-]+)['\"]?", code)
    if template and m:
        return urllib.parse.urljoin(base_url, template.format(id=m.group(1)))
    return None


def parse_list(html, base_url, source):
    parser = RowParser()
    parser.feed(html)
    items, seen = [], set()
    for row in parser.rows:
        text = clean(" ".join(row["text"]))
        date = parse_date(text)
        if not date or not row["links"]:
            continue
        best = max(row["links"], key=lambda l: len(clean(" ".join(l["text"])) or l["title"]))
        title = clean(" ".join(best["text"])) or clean(best["title"])
        title = re.sub(r"\s*(새글|new|NEW|첨부파일 있음)\s*$", "", title)
        if len(title) < 4:
            continue
        url = resolve_link(best, base_url, source)
        key = url or f"{source['id']}:{date}:{title}"
        if key in seen:
            continue
        seen.add(key)
        items.append({"title": title, "date": date, "url": url})
    return items


class TextParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts, self.skip = [], 0

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style", "nav", "header", "footer"):
            self.skip += 1

    def handle_endtag(self, tag):
        if tag in ("script", "style", "nav", "header", "footer") and self.skip:
            self.skip -= 1

    def handle_data(self, data):
        if not self.skip:
            self.parts.append(data)


def extract_body(html, title):
    p = TextParser()
    p.feed(html)
    text = clean(" ".join(p.parts))
    # 본문은 보통 제목이 다시 나온 뒤에 시작한다
    idx = text.find(title[:20]) if title else -1
    if idx >= 0:
        text = text[idx + len(title[:20]):]
    return text[:BODY_CHARS]


def classify(text):
    scores = []
    for name, words in CATEGORIES:
        n = sum(text.count(w) for w in words)
        if n:
            scores.append((n, name))
    return max(scores)[1] if scores else "행정 일반"


def locate(title, body, places):
    """제목(가중치 3)과 본문에서 지명을 찾아 가장 많이 언급된 곳을 고른다.

    동점이면 priority(구체적 지점 우선), 그다음 제목에 먼저 나온 지명을 고른다.
    """
    best, best_key = None, None
    for place in places["places"]:
        names = [place["name"]] + place.get("aliases", [])
        score = sum(title.count(n) * 3 + body.count(n) for n in names)
        if not score:
            continue
        first = min((title.find(n) for n in names if n in title), default=len(title))
        key = (score, place.get("priority", 0), -first)
        if best_key is None or key > best_key:
            best, best_key = place, key
    if best:
        return {"name": best["name"], "lat": best["lat"], "lng": best["lng"], "precision": best.get("kind", "dong")}
    c = places["citywide"]
    return {"name": c["name"], "lat": c["lat"], "lng": c["lng"], "precision": "citywide"}


def item_id(source_id, item):
    if item["url"]:
        q = urllib.parse.parse_qs(urllib.parse.urlparse(item["url"]).query)
        for k in ("bIdx", "idx", "nttId", "seq", "notAncmtMgtNo", "id"):
            if q.get(k):
                return f"{source_id}:{q[k][0]}"
        return f"{source_id}:{item['url']}"
    return f"{source_id}:{item['date']}:{item['title']}"


def collect_source(source, known, places, budget):
    items, errors = [], []
    for page in range(1, source.get("pages", 1) + 1):
        url = source["url"]
        if page > 1:
            sep = "&" if "?" in url else "?"
            url = f"{url}{sep}{source.get('page_param', 'pageIndex')}={page}"
        try:
            html = fetch(url)
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            errors.append(f"{url}: {e}")
            break
        found = parse_list(html, url, source)
        if not found:
            errors.append(f"{url}: 게시물 행을 찾지 못함 (페이지 구조 변경 가능)")
            break
        items.extend(found)
        time.sleep(REQUEST_DELAY)

    out = []
    for it in items:
        pid = item_id(source["id"], it)
        prev = known.get(pid)
        body = prev.get("_body", "") if prev else ""
        if not prev and it["url"] and budget[0] > 0:
            budget[0] -= 1
            try:
                body = extract_body(fetch(it["url"]), it["title"])
            except (urllib.error.URLError, TimeoutError, OSError) as e:
                errors.append(f"{it['url']}: {e}")
            time.sleep(REQUEST_DELAY)
        text = it["title"] + " " + body
        out.append({
            "id": pid,
            "title": it["title"],
            "date": it["date"],
            "url": it["url"] or source["url"],
            "source": source["name"],
            "category": classify(text),
            "location": locate(it["title"], body, places),
            "summary": body[:180],
            "first_seen": prev["first_seen"] if prev else now_iso(),
            "_body": body,
        })
    return out, errors


def main():
    sources = load_json(SOURCES_FILE, [])
    places = load_json(PLACES_FILE, None)
    if not sources or not places:
        print("sources.json / places.json 을 읽지 못했습니다.", file=sys.stderr)
        return 2

    previous = load_json(OUTPUT, {})
    known = {p["id"]: p for p in previous.get("projects", [])}
    budget = [MAX_DETAIL_FETCH]
    report, fresh = [], {}

    for source in sources:
        if not source.get("enabled", True):
            continue
        got, errors = collect_source(source, known, places, budget)
        for g in got:
            fresh[g["id"]] = g
        report.append({"id": source["id"], "name": source["name"], "count": len(got), "errors": errors[:10]})
        print(f"[{source['id']}] {len(got)}건, 오류 {len(errors)}건")
        for e in errors[:10]:
            print("   -", e)

    merged = {**known, **fresh}  # 과거 수집분은 유지(누적 아카이브)
    projects = sorted(merged.values(), key=lambda p: (p["date"], p["id"]), reverse=True)
    new_count = sum(1 for k in fresh if k not in known)

    # 본문은 위치 재계산용으로 짧게만 보관
    for p in projects:
        p["_body"] = p.get("_body", "")[:BODY_CHARS]

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps({
        "updated_at": now_iso() if fresh else previous.get("updated_at"),
        "checked_at": now_iso(),
        "new_this_run": new_count,
        "sources": report,
        "projects": projects,
    }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"총 {len(projects)}건 저장 (신규 {new_count}건)")

    if not fresh:
        print("모든 출처에서 수집에 실패했습니다.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
