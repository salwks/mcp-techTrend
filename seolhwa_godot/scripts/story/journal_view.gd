# 기록책 펼침면 — 실로 맨 옛 책(선장본) 한 펼침: 감색 표지 위 한지 두 쪽, 쪽마다 네 둘레 테(사주쌍변)와 세로 괘선(계선),
# 가운데 접힌 자리(판심)에 어미·책 이름·갈피 이름·장 수. 글은 세로로, 오른쪽 줄부터 왼쪽으로(오른쪽 쪽 → 왼쪽 쪽).
# 꼬리표(◆ 확인 · ◇ 들음 — 말한 사람 · △ 추정)는 테 위 여백에 작은 글씨로(두주). 스크롤 막대는 없다 — 쪽을 넘긴다.
#   넘기기: ← A(다음 쪽 — 옛 책은 왼쪽으로 읽어 간다) · → D(앞 쪽) · 휠 · 쪽 바깥 가장자리 클릭 · 숫자/갈피 클릭으로 갈피 첫 쪽
#   넘길 때 한 장이 등(가운데)을 축으로 넘어가는 그림(0.42초).
# story_ui가 만든다: open(data) · goto_section(i) · turn(+1/-1) · handle(ev) → 처리했으면 true. 쪽 자료는 scripts/story/journal_book.gd.
# 블록: title · head · para(soft, size) · quote · entry(tag fact|heard|guess, by, title, text, strong, note) · case(title, status) · gap · page(쪽 바꿈)
extends Control

signal section_shown(index: int)
signal close_requested

const VText := preload("res://scripts/story/vtext.gd")
const UiFonts := preload("res://scripts/ui_fonts.gd")

const PAPER := Color("#efe6d2")
const PAPER_SHADE := Color("#d9ccae")
const INK := Color("#2b2622")
const INK_SOFT := Color("#5f554b")
const SEAL := Color("#a8443c")
const INDIGO := Color("#3a4866")
const COVER := Color("#2a3142")
const RULE := Color(0.17, 0.15, 0.13, 0.30)
const FRAME := Color(0.17, 0.15, 0.13, 0.82)
const TAGS := { fact = ["◆", "확인"], heard = ["◇", "들음"], guess = ["△", "추정"], note = ["", ""] }
const TAG_COL := { fact = INK, heard = INDIGO, guess = SEAL, note = SEAL }
const SLIP_COLS := [Color("#cdbf9c"), Color("#e2d3a6"), Color("#d8c2b4"), Color("#c7cfbd"), Color("#c5cbd8"), Color("#d9cba0"), Color("#d4bfbd"), Color("#c9d0c8")]
const FLIP_SEC := 0.42
const BOOK_NAME := "기록책"

var sections: Array = []
var order: Array = []          # 표시 차례(앞 갈피 먼저) — sections 번호
var pages: Array = []          # {sec, cols, num}
var sec_spread := {}           # sections 번호 → 첫 펼침
var spread := 0
var cur_section := -1

var _k := 1.0
var _fs := 20.0
var _cell := 21.0
var _cw := 34.0
var _ncols := 12
var _col_h := 400.0
var _book := Rect2()
var _paper := Rect2()
var _pansim := Rect2()
var _page_r := [Rect2(), Rect2()]   # 0 오른쪽 쪽, 1 왼쪽 쪽
var _frame_r := [Rect2(), Rect2()]
var _inner_r := [Rect2(), Rect2()]
var _slips: Array = []         # [{sec, rect}]
var _hover := ""
var _flip_t := 1.0
var _flip_dir := 1
var _flip_from := 0
var _body: Font
var _classic: Font
var _laid_size := Vector2.ZERO
static var _hanji: Texture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_body = UiFonts.main()
	_classic = UiFonts.classic()
	resized.connect(_relayout)

func open(data: Dictionary, sec_index: int) -> void:
	sections = data.get("pages", [])
	order = []
	for i in sections.size():
		if bool(sections[i].get("front", false)): order.append(i)
	for i in sections.size():
		if not bool(sections[i].get("front", false)): order.append(i)
	_laid_size = Vector2.ZERO
	_relayout()
	_flip_t = 1.0
	goto_section(sec_index, false)

func _relayout() -> void:
	if sections.is_empty() or size.x < 10.0: return
	if _laid_size == size: return
	_laid_size = size
	var keep := cur_section
	_geometry()
	_layout_all()
	if keep >= 0: spread = int(sec_spread.get(keep, 0))
	queue_redraw()

# ---------------------------------------------------------------------------
# 자리 잡기
# ---------------------------------------------------------------------------
func _geometry() -> void:
	var vs := size
	_k = clampf(vs.y / 768.0, 0.75, 2.4)
	var k := _k
	var bw := minf(vs.x * 0.94, vs.y * 1.62)
	var bh := minf(vs.y * 0.78, bw * 0.62)
	_book = Rect2((vs.x - bw) * 0.5, vs.y * 0.16, bw, bh)
	var cm := 11.0 * k
	_paper = _book.grow(-cm)
	var pw := 46.0 * k
	var cx := _paper.get_center().x
	_pansim = Rect2(cx - pw * 0.5, _paper.position.y, pw, _paper.size.y)
	_page_r[0] = Rect2(cx + pw * 0.5, _paper.position.y, _paper.end.x - cx - pw * 0.5, _paper.size.y)
	_page_r[1] = Rect2(_paper.position.x, _paper.position.y, cx - pw * 0.5 - _paper.position.x, _paper.size.y)
	var head := _paper.size.y * 0.155
	var foot := _paper.size.y * 0.055
	for i in 2:
		var pr: Rect2 = _page_r[i]
		var outer := 24.0 * k; var inner := 6.0 * k
		var x0 := pr.position.x + (inner if i == 0 else outer)
		var x1 := pr.end.x - (outer if i == 0 else inner)
		_frame_r[i] = Rect2(x0, pr.position.y + head, x1 - x0, pr.size.y - head - foot)
		_inner_r[i] = (_frame_r[i] as Rect2).grow(-5.0 * k)
	_fs = 20.5 * k
	_cell = _fs * 1.06
	var iw: float = (_inner_r[0] as Rect2).size.x
	_ncols = maxi(6, int(iw / (_fs * 1.72)))
	_cw = iw / _ncols
	_col_h = (_inner_r[0] as Rect2).size.y - _fs * 0.5
	# 판심 칸을 쪽 테와 같은 높이로
	_pansim = Rect2(_pansim.position.x, _frame_r[0].position.y, _pansim.size.x, _frame_r[0].size.y)

# ---------------------------------------------------------------------------
# 글을 세로 줄로 흘리기
# ---------------------------------------------------------------------------
var _cols: Array = []

func _new_col(indent_cells: float) -> Dictionary:
	var c := { g = [], y = indent_cells * _cell, note = null }
	_cols.append(c)
	return c

func _brk(kind: String) -> void:
	_cols.append({ brk = kind })

# runs: [[글, 글꼴, 크기, 색]] — 이어서 한 덩이로 흘린다
func _flow(runs: Array, first_indent: float, cont_indent: float, note = null) -> void:
	var c := _new_col(first_indent)
	c.note = note
	for r in runs:
		var text := String(r[0]); var font: Font = r[1]; var fs: float = r[2]; var col: Color = r[3]
		for i in text.length():
			var ch := text.substr(i, 1)
			if ch == "\n":
				c = _new_col(cont_indent); continue
			if ch == " " and c.g.is_empty(): continue
			var a := VText.advance(ch, fs, font)
			if c.y + a > _col_h + 0.5:
				var hang: bool = VText.is_closer(ch) and not c.g.is_empty() and c.y + a * 0.6 <= _col_h + _cell
				if not hang:
					c = _new_col(cont_indent)
					if ch == " ": continue
			c.g.append([ch, font, fs, col, c.y + a * 0.5])
			c.y += a

func _blank() -> void:
	_new_col(0)

func _layout_section(sec: Dictionary) -> void:
	_cols = []
	var fs := _fs
	for bl in sec.get("blocks", []):
		match String(bl.get("t", "para")):
			"title":
				_flow([[String(bl.text), _classic, fs * 1.42, INK]], 0.0, 0.0)
				if String(bl.get("sub", "")) != "": _flow([[String(bl.sub), _body, fs * 0.86, INK_SOFT]], 3.0, 3.0)
				_blank()
			"head":
				_flow([[String(bl.text), _classic, fs * 1.1, SEAL]], 0.0, 0.5)
			"case":
				_flow([["「%s」" % String(bl.title), _classic, fs * 1.15, INK]], 0.0, 1.0,
					{ lines = [String(bl.get("status", ""))], col = SEAL } if String(bl.get("status", "")) != "" else null)
			"quote":
				_flow([[String(bl.text), _classic, fs * float(bl.get("scale", 1.22)), INK if not bl.get("seal", false) else SEAL]], float(bl.get("indent", 2.0)), float(bl.get("indent", 2.0)))
			"gap":
				_blank()
			"page":
				_brk("page")
			"entry":
				var tag := String(bl.get("tag", "fact"))
				var lines := []
				if bl.has("note"): lines = [String(bl.note)]
				else:
					var tg: Array = TAGS.get(tag, TAGS.fact)
					lines = [String(tg[0]) + String(tg[1])]
					if tag == "heard" and String(bl.get("by", "")) != "": lines.append(String(bl.by))
				var runs := []
				var has_title := String(bl.get("title", "")) != ""
				if has_title: runs.append([String(bl.title) + ("  " if String(bl.get("text", "")) != "" else ""), _classic, fs * 1.02, SEAL if bl.get("strong", false) else INK])
				if String(bl.get("text", "")) != "": runs.append([String(bl.text), _body, fs * (0.95 if has_title else 1.0), INK])
				_flow(runs, 1.0, 2.0, { lines = lines, col = TAG_COL.get(tag, INK) })
			_:
				var soft: bool = bl.get("soft", false)
				var sz := float(bl.get("size", 21)) / 21.0
				_flow([[String(bl.get("text", "")), _body, fs * sz * (0.92 if soft else 1.0), INK_SOFT if soft else INK]], float(bl.get("indent", 1.0)), float(bl.get("indent", 1.0)))

func _layout_all() -> void:
	pages = []
	sec_spread = {}
	for si in order:
		var sec: Dictionary = sections[si]
		if pages.size() % 2 == 1: pages.append({ sec = pages[-1].sec, cols = [] })   # 갈피는 펼침 오른쪽 쪽부터
		sec_spread[si] = pages.size() / 2
		_layout_section(sec)
		var cur := []
		for c in _cols:
			if c.has("brk"):
				if not cur.is_empty():
					pages.append({ sec = si, cols = cur }); cur = []
				continue
			if cur.size() >= _ncols:
				pages.append({ sec = si, cols = cur }); cur = []
			cur.append(c)
		if not cur.is_empty() or pages.is_empty() or pages[-1].sec != si: pages.append({ sec = si, cols = cur })
	if pages.size() % 2 == 1: pages.append({ sec = pages[-1].sec, cols = [] })
	for i in pages.size(): pages[i].num = i + 1

func spread_count() -> int:
	return pages.size() / 2

# ---------------------------------------------------------------------------
# 넘기기
# ---------------------------------------------------------------------------
func goto_section(i: int, animate := true) -> void:
	if not sec_spread.has(i): i = order[0] if not order.is_empty() else 0
	_go(int(sec_spread.get(i, 0)), animate)

func turn(d: int) -> void:
	_go(spread + d, true)

func _go(s: int, animate: bool) -> void:
	if pages.is_empty(): return
	s = clampi(s, 0, spread_count() - 1)
	if not animate: _flip_t = 1.0
	if s == spread and cur_section >= 0:
		queue_redraw()
		return
	if animate and cur_section >= 0:
		_flip_from = spread
		_flip_dir = 1 if s > spread else -1
		_flip_t = 0.0
	spread = s
	var sec: int = pages[spread * 2].sec
	if sec != cur_section:
		cur_section = sec
		section_shown.emit(sec)
	queue_redraw()

func _process(dt: float) -> void:
	if _flip_t < 1.0:
		_flip_t = minf(1.0, _flip_t + dt / FLIP_SEC)
		queue_redraw()

# 입력: 처리했으면 true
func handle(ev: InputEvent) -> bool:
	if ev is InputEventMouseMotion:
		var h := _hit(ev.position)
		if h != _hover:
			_hover = h; queue_redraw()
		return false
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN: turn(1); return true
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP: turn(-1); return true
		if ev.button_index != MOUSE_BUTTON_LEFT: return false
		var h := _hit(ev.position)
		if h == "next": turn(1)
		elif h == "prev": turn(-1)
		elif h.begins_with("slip:"): goto_section(int(h.substr(5)))
		elif not _book.has_point(ev.position): close_requested.emit()
		return true
	if ev is InputEventKey and ev.pressed:
		var kc: int = ev.physical_keycode
		if kc in [KEY_LEFT, KEY_A, KEY_PAGEDOWN]: turn(1); return true
		if kc in [KEY_RIGHT, KEY_D, KEY_PAGEUP]: turn(-1); return true
		if kc == KEY_HOME: _go(0, true); return true
		if kc >= KEY_1 and kc <= KEY_9 and kc - KEY_1 < order.size():
			goto_section(order[kc - KEY_1]); return true
	return false

func _hit(p: Vector2) -> String:
	for s in _slips:
		if (s.rect as Rect2).has_point(p): return "slip:%d" % s.sec
	var edge := 70.0 * _k
	var lp: Rect2 = _page_r[1]; var rp: Rect2 = _page_r[0]
	if Rect2(_book.position.x - 30 * _k, _book.position.y, edge + 30 * _k, _book.size.y).has_point(p) and spread < spread_count() - 1: return "next"
	if Rect2(_book.end.x - edge, _book.position.y, edge + 30 * _k, _book.size.y).has_point(p) and spread > 0: return "prev"
	return ""

# ---------------------------------------------------------------------------
# 그리기
# ---------------------------------------------------------------------------
static func _hanji_tex() -> Texture2D:
	if _hanji != null: return _hanji
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new(); rng.seed = 1870
	var noise := FastNoiseLite.new(); noise.seed = 7; noise.frequency = 0.035
	for y in n:
		for x in n:
			var v := noise.get_noise_2d(x, y) * 0.5 + rng.randf() * 0.04
			img.set_pixel(x, y, Color(1, 1, 1, 0).lerp(Color(0.55, 0.47, 0.34, 1), clampf(0.05 + v * 0.10, 0.0, 0.16)))
	# 닥 섬유
	for i in 140:
		var a := Vector2(rng.randf() * n, rng.randf() * n)
		var ang := rng.randf() * TAU
		var l := rng.randf_range(5.0, 22.0)
		var c := Color(0.50, 0.42, 0.30, rng.randf_range(0.10, 0.26))
		for t in int(l):
			var p := a + Vector2(cos(ang), sin(ang)) * t + Vector2(0, sin(t * 0.4) * 0.7)
			var px := posmod(int(p.x), n); var py := posmod(int(p.y), n)
			img.set_pixel(px, py, img.get_pixel(px, py).blend(c))
	_hanji = ImageTexture.create_from_image(img)
	return _hanji

func _draw() -> void:
	if pages.is_empty(): return
	var k := _k
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.035, 0.03, 0.78))
	_draw_slips()
	# 표지(감색) + 그림자
	draw_rect(Rect2(_book.position + Vector2(5, 8) * k, _book.size), Color(0, 0, 0, 0.35))
	draw_rect(_book, COVER)
	draw_rect(_book.grow(-3.0 * k), Color(1, 1, 1, 0.05), false, 1.0 * k)
	# 종이 두 쪽(뒤로 겹친 장 끝을 몇 줄)
	for i in 3:
		var g := (3 - i) * 1.6 * k
		draw_rect(Rect2(_paper.position.x - g, _paper.position.y + g * 0.6, _paper.size.x + g * 2, _paper.size.y), PAPER_SHADE.darkened(0.06 * i))
	var cur := spread
	var flipping := _flip_t < 1.0
	# 오른쪽 쪽: 앞으로 넘길 때는 넘어오는 장이 덮을 때까지 옛 쪽
	var right_idx := cur * 2
	var left_idx := cur * 2 + 1
	if flipping:
		if _flip_dir > 0 and _flip_t < 0.5: right_idx = _flip_from * 2
		if _flip_dir < 0 and _flip_t < 0.5: left_idx = _flip_from * 2 + 1
	_draw_page(0, right_idx)
	_draw_page(1, left_idx)
	_draw_pansim(cur)
	# 등 쪽 그늘(접힌 자리)
	var sw := 26.0 * k
	_shade(Rect2(_pansim.position.x - sw, _paper.position.y, sw, _paper.size.y), 0.0, 0.16)
	_shade(Rect2(_pansim.end.x, _paper.position.y, sw, _paper.size.y), 0.16, 0.0)
	if flipping: _draw_flip()
	_draw_edges()
	_draw_foot()

func _shade(r: Rect2, a0: float, a1: float) -> void:
	var c0 := Color(0.25, 0.18, 0.10, a0); var c1 := Color(0.25, 0.18, 0.10, a1)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([c0, c1, c1, c0]))

func _draw_paper(r: Rect2) -> void:
	draw_rect(r, PAPER)
	draw_texture_rect(_hanji_tex(), r, true, Color(1, 1, 1, 0.9))

func _draw_frame(side: int) -> void:
	var fr: Rect2 = _frame_r[side]
	var k := _k
	draw_rect(fr, FRAME, false, 2.4 * k)
	draw_rect(fr.grow(-3.4 * k), Color(FRAME, 0.55), false, 0.9 * k)
	var ir: Rect2 = _inner_r[side]
	for j in range(1, _ncols):
		var x := ir.end.x - j * _cw
		draw_line(Vector2(x, fr.position.y + 3.4 * k), Vector2(x, fr.end.y - 3.4 * k), RULE, maxf(1.0, 0.8 * k))

func _draw_page(side: int, idx: int) -> void:
	_draw_paper(_page_r[side])
	_draw_frame(side)
	if idx < 0 or idx >= pages.size(): return
	var pg: Dictionary = pages[idx]
	var ir: Rect2 = _inner_r[side]
	var fr: Rect2 = _frame_r[side]
	for j in pg.cols.size():
		var c: Dictionary = pg.cols[j]
		var x: float = ir.end.x - (j + 0.5) * _cw
		for gl in c.g:
			VText.draw(self, gl[1], Vector2(x, ir.position.y + _fs * 0.25 + float(gl[4])), String(gl[0]), float(gl[2]), gl[3])
		if c.note != null: _draw_note(x, fr.position.y, c.note)

# 두주: 테 위 여백에 작은 세로 글(오른쪽 줄 먼저). 꼬리표 낱말 + 말한 사람
func _draw_note(x: float, frame_top: float, note: Dictionary) -> void:
	var lines: Array = note.lines
	var col: Color = note.col
	var ns := _fs * 0.6
	var room := (frame_top - _paper.position.y) - 14.0 * _k
	var longest := 0.0
	for l in lines: longest = maxf(longest, VText.length(_body, String(l), ns))
	if longest > room: ns *= room / longest
	var n := lines.size()
	for i in n:
		var t := String(lines[i])
		var xx := x + (0.0 if n == 1 else (0.24 - 0.48 * i / float(n - 1)) * _cw)
		var len := VText.length(_body, t, ns)
		var y0 := frame_top - 7.0 * _k - len
		VText.column(self, _body, Vector2(xx, y0), t, ns, col)

# 판심: 위아래 검은 어미, 책 이름 · 갈피 이름 · 장 수
func _draw_pansim(cur: int) -> void:
	var k := _k
	var r := _pansim
	_draw_paper(Rect2(r.position.x, _paper.position.y, r.size.x, _paper.size.y))
	draw_rect(r, FRAME, false, 2.4 * k)
	var cx := r.get_center().x
	var w := r.size.x
	var y_top := r.position.y + r.size.y * 0.16
	var y_bot := r.position.y + r.size.y * 0.80
	_eomi(cx, y_top, w, 1)
	_eomi(cx, y_bot, w, -1)
	var sec: Dictionary = sections[pages[cur * 2].sec] if not pages.is_empty() else {}
	var fs := _fs * 0.78
	var y := y_top + 12.0 * k
	y += VText.column(self, _classic, Vector2(cx, y), BOOK_NAME, fs, INK) + fs * 0.6
	VText.column(self, _body, Vector2(cx, y), String(sec.get("tab", "")), fs * 0.82, INK_SOFT)
	var num := VText.hanja_num(cur + 1)
	var nl := VText.length(UiFonts.system(), num, fs)
	VText.column(self, UiFonts.main(), Vector2(cx, y_bot - 10.0 * k - nl), num, fs, INK)
	draw_line(Vector2(cx, r.position.y), Vector2(cx, r.end.y), Color(INK, 0.12), 1.0)

func _eomi(cx: float, y: float, w: float, dir: int) -> void:
	var hw := w * 0.5 - 2.0 * _k
	var h := 16.0 * _k * dir
	var notch := 6.0 * _k * dir
	draw_colored_polygon(PackedVector2Array([Vector2(cx - hw, y - h * 0.3), Vector2(cx + hw, y - h * 0.3), Vector2(cx + hw, y + h * 0.35),
		Vector2(cx, y + h * 0.35 + notch * 0.2), Vector2(cx - hw, y + h * 0.35)]), Color(INK, 0.88))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - hw, y + h * 0.35), Vector2(cx, y + h * 0.35 + notch), Vector2(cx + hw, y + h * 0.35)]), Color(INK, 0.88))

func _draw_slips() -> void:
	_slips = []
	var k := _k
	var sw := 30.0 * k
	var gap := 7.0 * k
	var x := _paper.end.x - 26.0 * k - sw
	var ns := 14.5 * k
	for oi in order.size():
		var si: int = order[oi]
		var on := si == cur_section
		var label := String(sections[si].get("tab", ""))
		var lns := ns
		var len := VText.length(_body, label, lns)
		var room := _book.position.y - 34.0 * k
		if len > room:
			lns *= room / len; len = room
		var vis := len + 24.0 * k + (8.0 * k if on else 0.0)
		var r := Rect2(x, _book.position.y - vis, sw, vis + 14.0 * k)
		var col: Color = SLIP_COLS[oi % SLIP_COLS.size()]
		if not on: col = col.darkened(0.12)
		draw_rect(Rect2(r.position + Vector2(2, 2) * k, r.size), Color(0, 0, 0, 0.3))
		draw_rect(r, col)
		if _hover == "slip:%d" % si and not on: draw_rect(r, Color(1, 1, 1, 0.12))
		draw_rect(r, Color(INK, 0.5), false, 1.0 * k)
		var digit := str(oi + 1)
		draw_string(_body, Vector2(x + sw * 0.5 - ns * 0.28, r.position.y + ns * 0.95), digit, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ns * 0.8), Color(INK, 0.55))
		VText.column(self, _body, Vector2(x + sw * 0.5, r.position.y + ns * 1.3), label, lns, SEAL if on else INK)
		_slips.append({ sec = si, rect = Rect2(r.position, Vector2(sw, vis)) })
		x -= sw + gap

func _draw_flip() -> void:
	var t := _flip_t
	var e := t * t * (3.0 - 2.0 * t)
	var ang := e * PI
	var cx := _pansim.get_center().x
	var wl: float = (_page_r[1] as Rect2).size.x + _pansim.size.x * 0.5
	var wr: float = (_page_r[0] as Rect2).size.x + _pansim.size.x * 0.5
	var y0 := _paper.position.y; var y1 := _paper.end.y
	var c := cos(ang)
	# 앞으로: 왼쪽 장이 들려 오른쪽으로 / 뒤로: 오른쪽 장이 왼쪽으로
	var on_left := (c > 0.0) == (_flip_dir > 0)
	var w := absf(c) * (wl if on_left else wr)
	var lift := sin(ang) * 18.0 * _k
	var x_out := cx - w if on_left else cx + w
	var poly := PackedVector2Array([Vector2(cx, y0), Vector2(x_out, y0 - lift), Vector2(x_out, y1 + lift * 0.4), Vector2(cx, y1)])
	# 덮이는 쪽에 드리운 그림자
	var sh := 60.0 * _k * sin(ang)
	var sx := x_out - sh if on_left else x_out
	draw_rect(Rect2(minf(sx, x_out), y0, sh, y1 - y0), Color(0, 0, 0, 0.10 * sin(ang)))
	var shade := 0.25 * (1.0 - absf(c))
	var pc := PAPER.darkened(shade)
	draw_colored_polygon(poly, pc)
	var tex_c := PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9)])
	draw_polygon(poly, tex_c, PackedVector2Array([Vector2(0, 0), Vector2(w / 256.0, 0), Vector2(w / 256.0, (y1 - y0) / 256.0), Vector2(0, (y1 - y0) / 256.0)]), _hanji_tex())
	# 등에서 바깥쪽으로 짙어지는 그늘
	_shade_poly(poly, 0.18 * (1.0 - absf(c)) + 0.04)
	var edge := PackedVector2Array([poly[1], poly[2]])
	draw_polyline(edge, Color(INK, 0.25), 1.2 * _k)

func _shade_poly(poly: PackedVector2Array, a: float) -> void:
	var c0 := Color(0.2, 0.14, 0.08, a); var c1 := Color(0.2, 0.14, 0.08, 0.0)
	draw_polygon(poly, PackedColorArray([c0, c1, c1, c0]))

func _draw_edges() -> void:
	var k := _k
	var ns := 14.0 * k
	var cy := _book.get_center().y
	var can_next := spread < spread_count() - 1
	var can_prev := spread > 0
	if can_next:
		var a := 0.95 if _hover == "next" else 0.55
		var x: float = _book.position.x - 22.0 * k
		draw_colored_polygon(PackedVector2Array([Vector2(x - 8 * k, cy), Vector2(x + 6 * k, cy - 11 * k), Vector2(x + 6 * k, cy + 11 * k)]), Color(PAPER, a))
		VText.column(self, _body, Vector2(x, cy + 22 * k), "다음 쪽", ns, Color(PAPER, a))
	if can_prev:
		var a := 0.95 if _hover == "prev" else 0.55
		var x: float = _book.end.x + 22.0 * k
		draw_colored_polygon(PackedVector2Array([Vector2(x + 8 * k, cy), Vector2(x - 6 * k, cy - 11 * k), Vector2(x - 6 * k, cy + 11 * k)]), Color(PAPER, a))
		VText.column(self, _body, Vector2(x, cy + 22 * k), "앞 쪽", ns, Color(PAPER, a))
	if _hover == "next" and can_next: _shade(Rect2(_paper.position.x, _paper.position.y, 50 * k, _paper.size.y), 0.14, 0.0)
	if _hover == "prev" and can_prev: _shade(Rect2(_paper.end.x - 50 * k, _paper.position.y, 50 * k, _paper.size.y), 0.0, 0.14)

func _draw_foot() -> void:
	var k := _k
	var fs := int(15.0 * k)
	var t := "← A  다음 쪽      → D  앞 쪽      1–%d  갈피      R · Esc  덮기" % order.size()
	var w := _body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_body, Vector2((size.x - w) * 0.5, _book.end.y + 30.0 * k), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PAPER, 0.82))
	var pg := "%d / %d 장" % [spread + 1, spread_count()]
	var w2 := _body.get_string_size(pg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_body, Vector2(_book.end.x - w2, _book.end.y + 30.0 * k), pg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PAPER, 0.6))
