import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import collect  # noqa: E402

PLACES = collect.load_json(collect.PLACES_FILE, None)

TABLE_HTML = """
<html><body>
<ul class="gnb"><li><a href="/main/contents.do">메뉴 링크</a></li></ul>
<table><thead><tr><th>번호</th><th>제목</th><th>등록일</th></tr></thead>
<tbody>
<tr><td>101</td><td class="subject"><a href="./view.do?bIdx=181408&amp;ptIdx=82&amp;mId=0100000000">배곧~월곶 보행교 건립 추진 <span>새글</span></a></td><td>2025-12-05</td></tr>
<tr><td>100</td><td><a href="#" onclick="fn_view('9876'); return false;">도시관리계획 결정 고시</a></td><td>2025.12.04</td></tr>
</tbody></table>
</body></html>
"""

LIST_HTML = """
<ul class="board">
  <li><a href="view.do?bIdx=5&ptIdx=82">목감동 어린이 공원 조성</a><span class="date">2025-11-30</span></li>
  <li><a href="view.do?bIdx=5&ptIdx=82">목감동 어린이 공원 조성</a><span class="date">2025-11-30</span></li>
</ul>
"""

SRC = {"id": "press", "name": "보도자료", "view_template": "view.do?id={id}"}


def test_parse_table_rows():
    items = collect.parse_list(TABLE_HTML, "https://www.siheung.go.kr/media/bbs/list.do?ptIdx=82", SRC)
    assert [i["date"] for i in items] == ["2025-12-05", "2025-12-04"]
    assert items[0]["title"] == "배곧~월곶 보행교 건립 추진"
    assert items[0]["url"] == "https://www.siheung.go.kr/media/bbs/view.do?bIdx=181408&ptIdx=82&mId=0100000000"
    assert items[1]["url"] == "https://www.siheung.go.kr/media/bbs/view.do?id=9876"


def test_parse_list_items_dedup_and_skips_menu():
    items = collect.parse_list(LIST_HTML, "https://example.go.kr/bbs/list.do", SRC)
    assert len(items) == 1
    assert items[0]["title"] == "목감동 어린이 공원 조성"


def test_locate_prefers_title_and_falls_back_to_citywide():
    loc = collect.locate("배곧 보행교 건립", "월곶과 배곧을 잇는 다리", PLACES)
    assert loc["name"] == "배곧동"
    loc = collect.locate("배곧~월곶 보행교 건립 추진", "배곧과 월곶을 잇는 보행교", PLACES)
    assert loc["name"] == "배곧동"
    loc = collect.locate("2026년 예산 공개", "시흥시 전체 예산", PLACES)
    assert loc["precision"] == "citywide"


def test_classify():
    assert collect.classify("어르신 돌봄 지원 확대") == "복지"
    assert collect.classify("시흥시장 간담회") == "행정 일반"
    assert collect.classify("신안산선 버스 노선 개편") == "교통"


def test_item_id_uses_board_index():
    it = {"url": "https://x/view.do?bIdx=181408&ptIdx=82", "date": "2025-12-05", "title": "t"}
    assert collect.item_id("press", it) == "press:181408"


SIHEUNG_HTML = """
<table><tbody>
<tr><td>33216</td><td class="taL tit">
<a href="#" data-action="/main/saeol/gosi/view.do?&notAncmtMgtNo=86008&mId=0401040100" onclick="req.post(this); return false;"> 무연고 사망자 공시송달 공고 </a>
</td><td class="date"> 2026-09-23</td></tr>
</tbody></table>
<ul><li><a href="#" onclick="goTo.view('list','190377','82','0100000000'); return false;" data-action="/media/bbs/view.do?bIdx=190377&ptIdx=82">
<strong>[소상공인과] 전통시장 상인 격려</strong> 작성일 2026-09-23</a></li></ul>
"""


def test_siheung_data_action_links():
    items = collect.parse_list(SIHEUNG_HTML, "https://www.siheung.go.kr/media/bbs/list.do?ptIdx=82&mId=0100000000", SRC)
    assert items[0]["url"] == "https://www.siheung.go.kr/main/saeol/gosi/view.do?notAncmtMgtNo=86008&mId=0401040100"
    assert items[1]["title"] == "[소상공인과] 전통시장 상인 격려"
    assert items[1]["url"] == "https://www.siheung.go.kr/media/bbs/view.do?bIdx=190377&ptIdx=82&mId=0100000000"
    assert collect.item_id("gosi", items[0]) == "gosi:86008"


def test_extract_body_skips_menu_and_footer():
    html = """<html><body><div>본문 바로가기 주메뉴 정왕동 배곧동 목감동 월곶동</div>
    <h3>임병택 시흥시장, 추석 앞두고 전통시장 찾아 상인 격려</h3>
    <div>작성일 2026-09-23</div><p>시흥시는 23일 삼미시장을 방문해 상인들을 격려했다고 밝혔다. 신천동 일대 전통시장 활성화 방안도 논의했다.</p>
    <div>이전글 다음글 목록</div><footer>정왕동 거북섬 오이도</footer></body></html>"""
    body = collect.extract_body(html, "[소상공인과] 임병택 시흥시장, 추석 앞두고 전통시장 찾아 상인 격려")
    assert "삼미시장" in body and "신천동" in body
    assert "주메뉴" not in body and "이전글" not in body and "거북섬" not in body
    loc = collect.locate("[소상공인과] 임병택 시흥시장, 추석 앞두고 전통시장 찾아 상인 격려", body, PLACES)
    assert loc["name"] == "신천동"
