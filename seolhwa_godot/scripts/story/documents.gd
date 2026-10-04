# 문서 살피기·비교(문서 감정, 시나리오 §15 S5002·S5006, §31 '문서 비교' — 최종장 장부 조사도 같은 틀을 쓴다).
#   한지 위에 놓인 문서 1~3장을 나란히 펴 놓고, 돋보기(확대 칸)로 한 자리를 크게 보며, 이상한 데를 '짚는다'.
#   짚은 자리가 데이터의 짚을 곳(hotspot)에 맞으면 그 내용이 기록책에 ◆확인 단서로 남는다(사건 데이터 clues — kind fact).
#   정답 표시는 없다: 짚을 곳은 그려진 문서 그림에만 있다(먹 번짐·도장 자리·덧쓴 획·이어 붙인 종이). 먼저 짚게 하는 강조도 없다.
#   처음 열 때만 '무엇을 할 수 있는지' 한 줄(onboarding 처음 한 번 — DOC_EXAM, 감정법을 익힌 뒤 처음 DOC_SKILL).
#
# 감정 수준:
#   plain — 누구나: 종이 결·먹 번짐·도장 자리(눈으로 보이는 차이)
#   skill — SKILL_DOCUMENT_CHECK(평양 S5006)부터: 덧쓴 먹·도장 겹침·바꾼 종이·고친 날짜. 그 전에는 같은 자리를 짚어도 "별다른 것은 짚이지 않는다"
#
# 사건 데이터 "documents": { <문서 id>: spec } (또는 Docs.open(d, { "defs": {…} })로 바로 넘김)
#   spec: { title, aspect(세로/가로, 기본 1.4), seed,
#     paper: { base "#rrggbb", fiber 0~1(섬유 수), fiber_col, thin(얇아 비침), lines: n(세로 괘선 수), line_col },
#     cols:    [{ x, y, text, size(문서 폭 비율), ink 0~1, bleed 0~1(번짐), col }]   — 세로쓰기(위→아래), x는 글줄 가운데
#     ghosts:  [{ x, y, text, size, alpha }]          — 긁어 낸 자리 밑에 남은 옛 획(덧쓴 먹·고친 날짜)
#     scrapes: [{ rect: [x, y, w, h], alpha }]        — 긁어 낸 자리(종이가 일어나 밝다)
#     patches: [{ rect, base, fiber, seam }]          — 이어 붙인 종이(결·빛깔이 다르다, 이음매)
#     seals:   [{ at: [cx, cy], size, text: "平安監營", col, alpha, rot }]  — 같은 자리에 둘이면 도장 겹침
#     images:  [{ tex: "res://…png", region: [x, y, w, h](px), rect: [x, y, w, h], alpha }]  — 텍스처 칸(朴 표식 등)
#     burns:   [{ side: "left"|"right"|"top"|"bottom", depth, seed }]  — 탄 가장자리(그을린 띠·숯 끝, 함흥 역참의 불탄 장부)
#     hotspots: [{ id, rect: [x, y, w, h], level: "plain"|"skill", label(짚은 자리 이름), text(보이는 것), clue(단서 id), pair(비교 단서 id) }]
#   pair: 같은 pair를 가진 짚을 곳을 문서마다 다 짚으면 그 비교 단서를 얻는다(예: 두 문서의 먹을 다 짚으면 '먹 번짐이 다르다').
#   좌표는 모두 문서 정규 좌표(0~1, y는 아래로).
#
# 쓰기:  var r: Dictionary = await Docs.open(d, { "docs": ["deed_a", "deed_b"], "title": "…", "note": "…" })
#        r = { found: [이번에 새로 짚은 "문서/짚을 곳" …], all: [지금까지 짚은 것 …], closed: true }
#   짚은 것은 S.flags["_doc_found"]에 남는다(다시 열면 붉은 먹점으로 보인다).
#   시험: d.test에 doc_exam(exam)이 있으면 열린 뒤 그것을 부른다(exam.mark_spot(문서, 짚을 곳) · exam.close()). 없고 ui.auto면 바로 덮는다.
extends CanvasLayer

signal closed

const INK := Color("#2b2622")
const PAPER := Color("#efe6d2")
const SEAL := Color("#a8443c")
const DESK := Color(0.12, 0.10, 0.085, 1.0)   # 불투명 — 뒤 화면의 소지품·안내 글이 비치지 않게
const ZOOMS := [2.0, 3.5, 6.0]
const TOL := 0.012

var d
var defs := {}
var ids: Array = []
var title_text := ""
var note_text := ""
var skill := false
var cursor := Vector2.ZERO        # 화면 좌표
var zoom_i := 1
var found_now: Array = []
var feedback := ""
var _feedback_t := 0.0
var _rects := {}                  # 문서 id → 화면 Rect2
var _fibers := {}                 # 문서 id → [[a, b, col, w]] (정규 좌표)
var _tex := {}
var _font: Font
var _root: Control
var _desk: Control
var _loupe: Control
var _side: VBoxContainer
var _title: Label
var _note: Label
var _fb: Label
var _keys: Label
var _hint: Label
var _found_box: VBoxContainer
var _zoom_l: Label
var _k := 1.0
var _key_move := Vector2.ZERO
var _open := false

static func open(director, opts: Dictionary) -> Dictionary:
	var ex = load("res://scripts/story/documents.gd").new()
	ex.d = director
	ex._setup(opts)
	director.add_child(ex)
	ex._start()
	if director.test != null and director.test.has_method("doc_exam"):
		director.test.doc_exam.call_deferred(ex)
	elif director.ui.auto:
		ex.close.call_deferred()
	await ex.closed
	var r := { found = ex.found_now.duplicate(), all = ex.all_found(), closed = true }
	ex.queue_free()
	return r

# 지금까지 짚은 것(사건 진행에 남은 것)
static func found_list(S) -> Array:
	var f = S.flags.get("_doc_found", {})
	return (f as Dictionary).keys() if f is Dictionary else []

func _setup(opts: Dictionary) -> void:
	name = "documents"
	layer = 9
	defs = opts.get("defs", d.data.get("documents", {}))
	ids = Array(opts.get("docs", [])).filter(func(i): return defs.has(String(i)))
	title_text = String(opts.get("title", "문서 살피기" if ids.size() < 2 else "문서 비교"))
	note_text = String(opts.get("note", ""))
	skill = bool(opts.get("skill", bool(d.S.vars.get("SKILL_DOCUMENT_CHECK", false))))
	_font = d.ui._font if d.ui.get("_font") != null else SystemFont.new()
	for id in ids: _fibers[id] = _make_fibers(defs[id], int(defs[id].get("seed", hash(id) % 9973)))

func all_found() -> Array:
	return found_list(d.S)

# ---------------------------------------------------------------------------
# 화면
# ---------------------------------------------------------------------------
func _start() -> void:
	_open = true
	d.ui.modal = true
	d.ui.prompt("")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new(); bg.color = DESK; bg.set_anchors_preset(Control.PRESET_FULL_RECT); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	_desk = Control.new(); _desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desk.draw.connect(_draw_desk)
	_root.add_child(_desk)
	_loupe = Control.new(); _loupe.mouse_filter = Control.MOUSE_FILTER_IGNORE; _loupe.clip_contents = true
	_loupe.draw.connect(_draw_loupe)
	_root.add_child(_loupe)
	_title = _label(28, PAPER); _root.add_child(_title)
	_note = _label(18, Color(PAPER, 0.75)); _note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _root.add_child(_note)
	_zoom_l = _label(17, Color(PAPER, 0.8)); _root.add_child(_zoom_l)
	_side = VBoxContainer.new(); _side.mouse_filter = Control.MOUSE_FILTER_IGNORE; _root.add_child(_side)
	var sh := _label(19, PAPER); sh.text = "짚은 것"; _side.add_child(sh)
	_found_box = VBoxContainer.new(); _found_box.mouse_filter = Control.MOUSE_FILTER_IGNORE; _side.add_child(_found_box)
	_fb = _label(20, PAPER); _fb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_fb)
	_keys = _label(17, Color(PAPER, 0.85)); _keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys.text = "마우스·W A S D  돋보기 옮기기    휠·Z X  배율    클릭·E·Space  짚기    Tab  다른 문서    Esc  덮기"
	_root.add_child(_keys)
	_hint = _label(19, INK); _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hp := PanelContainer.new(); hp.name = "hint_panel"; hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(PAPER, 0.95); sb.border_color = SEAL; sb.set_border_width_all(2); sb.set_corner_radius_all(3)
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	hp.add_theme_stylebox_override("panel", sb); hp.add_child(_hint); hp.visible = false
	_root.add_child(hp)
	_title.text = title_text
	_note.text = note_text
	_layout()
	get_viewport().size_changed.connect(_layout)
	if not _rects.is_empty(): cursor = (_rects[ids[0]] as Rect2).get_center()
	_redraw()
	_refresh_found()
	_first_hint()
	if d.log_story: printerr("DOCS open %s skill=%s found=%s" % [ids, skill, all_found()])

func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _font)
	l.set_meta("base", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.035))
	l.add_theme_constant_override("outline_size", 4 if col != INK else 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	_k = clampf(vs.y / 768.0, 0.8, 2.4)
	for l in _root.find_children("*", "Label", true, false):
		l.add_theme_font_size_override("font_size", int(float(l.get_meta("base", 18)) * _k))
	var left_w := vs.x * 0.64
	var top := vs.y * 0.13
	var h_max := vs.y * 0.66
	var n := maxi(1, ids.size())
	var gap := vs.x * 0.025
	var w_each := (left_w - gap * (n + 1)) / n
	_rects.clear()
	for i in ids.size():
		var sp: Dictionary = defs[ids[i]]
		var asp := float(sp.get("aspect", 1.4))
		var w := minf(w_each, h_max / asp)
		var h := w * asp
		var x := gap + i * (w_each + gap) + (w_each - w) * 0.5
		_rects[ids[i]] = Rect2(x, top + (h_max - h) * 0.5, w, h)
	_desk.position = Vector2.ZERO; _desk.size = vs
	var ls := minf(vs.x * 0.3, vs.y * 0.42)
	_loupe.position = Vector2(vs.x * 0.67, top); _loupe.size = Vector2(ls, ls)
	_zoom_l.position = Vector2(vs.x * 0.67, top + ls + 4 * _k); _zoom_l.size = Vector2(ls, 24 * _k)
	_side.position = Vector2(vs.x * 0.67, top + ls + 34 * _k); _side.size = Vector2(vs.x * 0.31, vs.y - (top + ls + 34 * _k) - 90 * _k)
	_title.position = Vector2(gap, vs.y * 0.025); _title.size = Vector2(vs.x * 0.9, 40 * _k)
	_note.position = Vector2(gap, vs.y * 0.025 + 40 * _k); _note.size = Vector2(left_w, 30 * _k)
	_fb.position = Vector2(gap, top + h_max + 30 * _k); _fb.size = Vector2(left_w - gap, 60 * _k)
	_keys.position = Vector2(0, vs.y - 36 * _k); _keys.size = Vector2(vs.x, 30 * _k)
	var hp: Control = _root.get_node("hint_panel")
	hp.custom_minimum_size = Vector2(vs.x * 0.76, 0); hp.reset_size()
	hp.position = Vector2(vs.x * 0.12, vs.y - 100 * _k - hp.size.y * 0.5)
	_hint.custom_minimum_size = Vector2(vs.x * 0.76 - 28, 0)
	_desk.queue_redraw(); _loupe.queue_redraw()

func _first_hint() -> void:
	var ob = d.get("onboard")
	var lines := []
	var keys := []
	if ob != null and not ob.is_seen("DOC_EXAM"):
		keys.append("DOC_EXAM")
		lines.append("문서를 나란히 펴 놓았다. 돋보기로 종이 · 먹 · 도장을 견주어 보고, 다른 데가 보이면 짚는다.")
	if skill and ob != null and not ob.is_seen("DOC_SKILL"):
		keys.append("DOC_SKILL")
		lines.append("이제 고쳐 쓴 자리도 보인다 — 덧쓴 먹 · 겹친 도장 · 바꿔 붙인 종이 · 고친 날짜.")
	if lines.is_empty(): return
	_hint.text = "\n".join(lines)
	var hp: Control = _root.get_node("hint_panel")
	hp.visible = true
	_layout()
	for k in keys: ob.seen_now(k)
	if d.log_story: printerr("HINT ", " / ".join(lines))
	await get_tree().create_timer(9.0, true, false, true).timeout
	if is_instance_valid(hp): hp.visible = false

# ---------------------------------------------------------------------------
# 입력
# ---------------------------------------------------------------------------
func _input(ev: InputEvent) -> void:
	if not _open: return
	if ev is InputEventMouseMotion:
		cursor = ev.position; _redraw(); get_viewport().set_input_as_handled(); return
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT: cursor = ev.position; mark()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP: set_zoom(zoom_i + 1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN: set_zoom(zoom_i - 1)
		get_viewport().set_input_as_handled(); return
	if not (ev is InputEventKey): return
	var kc: int = ev.physical_keycode
	var dir := { KEY_W: Vector2.UP, KEY_UP: Vector2.UP, KEY_S: Vector2.DOWN, KEY_DOWN: Vector2.DOWN,
		KEY_A: Vector2.LEFT, KEY_LEFT: Vector2.LEFT, KEY_D: Vector2.RIGHT, KEY_RIGHT: Vector2.RIGHT }
	if dir.has(kc):
		var v: Vector2 = dir[kc]
		if ev.pressed: _key_move = (_key_move + v).clamp(Vector2(-1, -1), Vector2(1, 1))
		else: _key_move = (_key_move - v).clamp(Vector2(-1, -1), Vector2(1, 1))
		get_viewport().set_input_as_handled(); return
	if not ev.pressed or ev.echo: return
	match kc:
		KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: mark()
		KEY_Z, KEY_MINUS: set_zoom(zoom_i - 1)
		KEY_X, KEY_EQUAL: set_zoom(zoom_i + 1)
		KEY_TAB: _next_doc()
		KEY_ESCAPE, KEY_Q, KEY_R: close()
	get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if not _open: return
	if _key_move != Vector2.ZERO:
		cursor += _key_move.normalized() * 260.0 * _k * dt
		var vs := get_viewport().get_visible_rect().size
		cursor = cursor.clamp(Vector2.ZERO, vs)
		_redraw()
	if _feedback_t > 0.0:
		_feedback_t -= dt
		if _feedback_t <= 0.0: _fb.text = ""

func set_zoom(i: int) -> void:
	zoom_i = clampi(i, 0, ZOOMS.size() - 1)
	_redraw()

func _next_doc() -> void:
	if ids.is_empty(): return
	var cur := doc_at(cursor)
	var i := (ids.find(cur) + 1) % ids.size() if cur != "" else 0
	cursor = (_rects[ids[i]] as Rect2).get_center()
	_redraw()

func _redraw() -> void:
	_loupe.queue_redraw(); _desk.queue_redraw()
	_zoom_l.text = "돋보기 ×%s   %s" % [str(ZOOMS[zoom_i]).trim_suffix(".0"), String(defs.get(doc_at(cursor), {}).get("title", ""))]

func close() -> void:
	if not _open: return
	_open = false
	d.ui.modal = false
	d.ui._cooldown = 0.2
	if d.log_story: printerr("DOCS close found_now=%s" % [found_now])
	closed.emit()

# ---------------------------------------------------------------------------
# 짚기
# ---------------------------------------------------------------------------
func doc_at(p: Vector2) -> String:
	for id in _rects:
		if (_rects[id] as Rect2).has_point(p): return String(id)
	return ""

func to_norm(id: String, p: Vector2) -> Vector2:
	var r: Rect2 = _rects[id]
	return (p - r.position) / r.size

func to_screen(id: String, q: Vector2) -> Vector2:
	var r: Rect2 = _rects[id]
	return r.position + q * r.size

# 이 자리(정규 좌표)에서 짚히는 것: 감정 수준이 닿는 것 중 skill 먼저, 그다음 좁은 것
func hotspot_at(id: String, q: Vector2) -> Dictionary:
	var best := {}
	var best_key := INF
	for h in defs[id].get("hotspots", []):
		var lv := String(h.get("level", "plain"))
		if lv == "skill" and not skill: continue
		var r: Array = h.rect
		var rc := Rect2(float(r[0]) - TOL, float(r[1]) - TOL, float(r[2]) + TOL * 2, float(r[3]) + TOL * 2)
		if not rc.has_point(q): continue
		var key := float(r[2]) * float(r[3]) + (0.0 if lv == "skill" else 10.0)
		if key < best_key: best_key = key; best = h
	return best

func is_found(id: String, hid: String) -> bool:
	var f = d.S.flags.get("_doc_found", {})
	return f is Dictionary and f.has("%s/%s" % [id, hid])

func mark() -> void:
	var id := doc_at(cursor)
	if id == "":
		_say("문서 위를 짚어야 한다."); return
	var q := to_norm(id, cursor)
	var h := hotspot_at(id, q)
	if d.log_story: printerr("DOCS mark %s (%.3f, %.3f) → %s" % [id, q.x, q.y, h.get("id", "-")])
	if h.is_empty():
		_say("별다른 것은 짚이지 않는다."); return
	var key := "%s/%s" % [id, String(h.id)]
	if is_found(id, String(h.id)):
		_say("이미 짚은 자리다 — " + String(h.get("label", ""))); return
	var f = d.S.flags.get("_doc_found", {})
	if not (f is Dictionary): f = {}
	f[key] = { x = snappedf(q.x, 0.001), y = snappedf(q.y, 0.001) }
	d.S.flags["_doc_found"] = f
	found_now.append(key)
	d.runner.log_line("doc", key)
	_say("%s — %s" % [String(h.get("label", "")), String(h.get("text", ""))], 5.0)
	if String(h.get("clue", "")) != "": d.learn_clue(String(h.clue))
	if String(h.get("pair", "")) != "": _check_pair(String(h.pair))
	_refresh_found()
	_redraw()

func _check_pair(pair: String) -> void:
	var need := []
	for id in ids:
		for h in defs[id].get("hotspots", []):
			if String(h.get("pair", "")) == pair: need.append([id, String(h.id)])
	if need.size() < 2: return
	for n in need:
		if not is_found(n[0], n[1]): return
	d.learn_clue(pair)

func _say(t: String, sec := 3.0) -> void:
	_fb.text = t
	_feedback_t = sec

# 시험·자동: 그 짚을 곳 안에서 그것이 먼저 짚히는 점을 찾아 짚는다
func mark_spot(id: String, hid: String) -> bool:
	if not _rects.has(id): return false
	for h in defs[id].get("hotspots", []):
		if String(h.id) != hid: continue
		var r: Array = h.rect
		for j in 9:
			for i in 9:
				var q := Vector2(float(r[0]) + float(r[2]) * (i + 0.5) / 9.0, float(r[1]) + float(r[3]) * (j + 0.5) / 9.0)
				if String(hotspot_at(id, q).get("id", "")) == hid:
					cursor = to_screen(id, q); mark(); return true
		cursor = to_screen(id, Vector2(float(r[0]) + float(r[2]) * 0.5, float(r[1]) + float(r[3]) * 0.5))
		mark()
		return false
	return false

# 시험·자동: 아무 데나(정규 좌표) 짚기
func mark_at(id: String, q: Vector2) -> void:
	if not _rects.has(id): return
	cursor = to_screen(id, q); mark()

func _refresh_found() -> void:
	for c in _found_box.get_children(): c.queue_free()
	for key in all_found():
		var parts := String(key).split("/")
		if parts.size() < 2 or not ids.has(parts[0]): continue
		for h in defs[parts[0]].get("hotspots", []):
			if String(h.id) != parts[1]: continue
			var l := _label(16, PAPER)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(_side.size.x, 0)
			l.add_theme_font_size_override("font_size", int(16 * _k))
			l.text = "확인 · %s — %s" % [String(defs[parts[0]].get("short", defs[parts[0]].get("title", ""))), String(h.get("label", ""))]
			_found_box.add_child(l)

# ---------------------------------------------------------------------------
# 그리기 — 문서 정규 좌표(q) → 화면(origin + q * size). 확대 칸은 같은 함수에 다른 사각형을 준다
# ---------------------------------------------------------------------------
func _draw_desk() -> void:
	for id in ids:
		var r: Rect2 = _rects[id]
		_desk.draw_rect(Rect2(r.position + Vector2(6, 8) * _k, r.size), Color(0, 0, 0, 0.35))
		draw_doc(_desk, defs[id], id, r, 1.0)
		var tl := String(defs[id].get("title", id))
		_desk.draw_string(_font, Vector2(r.position.x, r.end.y + 24 * _k), tl, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, int(17 * _k), Color(PAPER, 0.85))
		# 짚은 자리 — 붉은 먹점
		var f = d.S.flags.get("_doc_found", {})
		if f is Dictionary:
			for key in f:
				var parts := String(key).split("/")
				if parts[0] != id: continue
				var p := r.position + Vector2(float(f[key].x), float(f[key].y)) * r.size
				_desk.draw_arc(p, 9.0 * _k, 0, TAU, 20, Color(SEAL, 0.9), 2.2 * _k, true)
	# 돋보기 테
	var cur := doc_at(cursor)
	if cur != "":
		var lsz: Vector2 = _loupe.size / float(ZOOMS[zoom_i])   # 확대 칸에 든 만큼(문서 화면 크기 기준)
		_desk.draw_rect(Rect2(cursor - lsz * 0.5, lsz), Color(PAPER, 0.9), false, 1.5 * _k)
	_desk.draw_circle(cursor, 3.0 * _k, Color(SEAL, 0.95))

func _draw_loupe() -> void:
	var sz := _loupe.size
	_loupe.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.08, 0.07, 0.06))
	var id := doc_at(cursor)
	if id != "":
		var r: Rect2 = _rects[id]
		var z: float = ZOOMS[zoom_i]
		var q := to_norm(id, cursor)
		var big := Rect2(sz * 0.5 - q * r.size * z, r.size * z)
		draw_doc(_loupe, defs[id], id, big, z)
	else:
		_loupe.draw_string(_font, Vector2(12, sz.y * 0.5), "문서 위에 돋보기를 댄다", HORIZONTAL_ALIGNMENT_LEFT, sz.x - 24, int(17 * _k), Color(PAPER, 0.6))
	_loupe.draw_rect(Rect2(Vector2.ZERO, sz), Color(PAPER, 0.85), false, 2.0 * _k)
	_loupe.draw_line(Vector2(sz.x * 0.5 - 8, sz.y * 0.5), Vector2(sz.x * 0.5 + 8, sz.y * 0.5), Color(SEAL, 0.7), 1.0)
	_loupe.draw_line(Vector2(sz.x * 0.5, sz.y * 0.5 - 8), Vector2(sz.x * 0.5, sz.y * 0.5 + 8), Color(SEAL, 0.7), 1.0)

static func _col(v, dflt: Color) -> Color:
	if v is Color: return v
	if v is String and String(v).begins_with("#"): return Color(String(v))
	return dflt

func _make_fibers(sp: Dictionary, seed: int) -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var pp: Dictionary = sp.get("paper", {})
	var n := int(260.0 * float(pp.get("fiber", 0.5)))
	var fc := _col(pp.get("fiber_col"), Color(0.45, 0.38, 0.28))
	var out := []
	var asp := float(sp.get("aspect", 1.4))
	for i in n:
		var a := Vector2(rng.randf(), rng.randf())
		var ang := rng.randf() * TAU
		var l := rng.randf_range(0.008, 0.035)
		out.append([a, a + Vector2(cos(ang), sin(ang) / asp) * l, Color(fc, rng.randf_range(0.10, 0.32)), rng.randf_range(0.5, 1.4)])
	for p in sp.get("patches", []):
		var r: Array = p.rect
		var pc := _col(p.get("fiber_col"), Color(fc.r * 0.9, fc.g * 0.9, fc.b * 0.95))
		for i in int(90.0 * float(p.get("fiber", 0.3)) * float(r[2]) * float(r[3]) * 10.0):
			var a := Vector2(float(r[0]) + rng.randf() * float(r[2]), float(r[1]) + rng.randf() * float(r[3]))
			var ang := float(p.get("fiber_dir", 0.0)) + rng.randf_range(-0.25, 0.25)
			var l := rng.randf_range(0.006, 0.02)
			out.append([a, a + Vector2(cos(ang), sin(ang) / asp) * l, Color(pc, rng.randf_range(0.12, 0.3)), rng.randf_range(0.5, 1.0)])
	return out

func draw_doc(ci: CanvasItem, sp: Dictionary, id: String, r: Rect2, z: float) -> void:
	var P := func(q: Vector2) -> Vector2: return r.position + q * r.size
	var pp: Dictionary = sp.get("paper", {})
	var base := _col(pp.get("base"), PAPER)
	ci.draw_rect(r, base)
	# 얇은 종이: 얼룩덜룩 비침
	if bool(pp.get("thin", false)):
		var rng := RandomNumberGenerator.new(); rng.seed = int(sp.get("seed", 7)) + 31
		for i in 46:
			var c := Vector2(rng.randf(), rng.randf())
			var rad := minf(r.size.x * rng.randf_range(0.02, 0.07), minf(minf(c.x, 1.0 - c.x) * r.size.x, minf(c.y, 1.0 - c.y) * r.size.y))   # 종이 밖으로 번지지 않게
			ci.draw_circle(P.call(c), rad, Color(1, 1, 1, 0.06))
	# 이어 붙인 종이(빛깔·이음매)
	for p in sp.get("patches", []):
		var pr: Array = p.rect
		var rc := Rect2(P.call(Vector2(pr[0], pr[1])), Vector2(float(pr[2]), float(pr[3])) * r.size)
		ci.draw_rect(rc, _col(p.get("base"), base))
		var sa := float(p.get("seam", 0.25))
		ci.draw_line(rc.position, rc.position + Vector2(rc.size.x, 0), Color(0.3, 0.24, 0.16, sa), maxf(1.0, 0.6 * z))
		ci.draw_line(rc.position + Vector2(0, rc.size.y), rc.end, Color(0.3, 0.24, 0.16, sa), maxf(1.0, 0.6 * z))
	# 긁어 낸 자리
	for s in sp.get("scrapes", []):
		var sr: Array = s.rect
		ci.draw_rect(Rect2(P.call(Vector2(sr[0], sr[1])), Vector2(float(sr[2]), float(sr[3])) * r.size), Color(1, 0.99, 0.95, float(s.get("alpha", 0.18))))
	# 섬유
	for fb in _fibers.get(id, []):
		ci.draw_line(P.call(fb[0]), P.call(fb[1]), fb[2], maxf(0.6, float(fb[3]) * 0.5 * z))
	# 괘선
	var nl := int(pp.get("lines", 0))
	if nl > 0:
		var lc := _col(pp.get("line_col"), Color(0.66, 0.27, 0.24, 0.55))
		for i in nl + 1:
			var x := 0.08 + 0.84 * float(i) / float(nl)
			ci.draw_line(P.call(Vector2(x, 0.06)), P.call(Vector2(x, 0.94)), lc, maxf(0.8, 0.7 * z))
	# 텍스처 칸
	for im in sp.get("images", []):
		var tex := _texture(String(im.tex))
		if tex == null: continue
		var ir: Array = im.rect
		var src: Array = im.get("region", [0, 0, tex.get_width(), tex.get_height()])
		ci.draw_texture_rect_region(tex, Rect2(P.call(Vector2(ir[0], ir[1])), Vector2(float(ir[2]), float(ir[3])) * r.size),
			Rect2(float(src[0]), float(src[1]), float(src[2]), float(src[3])), Color(1, 1, 1, float(im.get("alpha", 1.0))))
	# 옛 획(긁고 덧쓴 밑)
	for g in sp.get("ghosts", []):
		_vtext(ci, r, Vector2(float(g.x), float(g.y)), String(g.text), float(g.get("size", 0.06)), Color(0.42, 0.34, 0.26, float(g.get("alpha", 0.22))), 0.0, z)
	# 글줄
	for c in sp.get("cols", []):
		_vtext(ci, r, Vector2(float(c.x), float(c.y)), String(c.text), float(c.get("size", 0.06)), Color(_col(c.get("col"), INK), float(c.get("ink", 0.92))), float(c.get("bleed", 0.0)), z)
	# 도장
	for s in sp.get("seals", []):
		_seal(ci, r, s, z)
	# 탄 가장자리(그을린 띠 + 숯이 된 끝) — 아래 글·표식이 그을음 밑으로 옅게 비친다
	for bn in sp.get("burns", []):
		_burn(ci, r, bn, z)

# burns: [{ side: "left"|"right"|"top"|"bottom", depth(문서 폭·높이 비율), seed }] — 들쭉날쭉한 탄 끝
func _burn(ci: CanvasItem, r: Rect2, bn: Dictionary, z: float) -> void:
	var side := String(bn.get("side", "bottom"))
	var depth := float(bn.get("depth", 0.2))
	var rng := RandomNumberGenerator.new(); rng.seed = int(bn.get("seed", 11))
	var n := 28
	var edge := []   # 탄 경계(정규 좌표): 가장자리를 따라
	for i in n + 1:
		var u := float(i) / n
		var dd := depth * (0.62 + 0.38 * (0.5 + 0.5 * sin(u * 17.0 + rng.randf() * 0.8)) * rng.randf_range(0.75, 1.0))
		edge.append([u, dd])
	var to_pt := func(u: float, dd: float) -> Vector2:
		match side:
			"left": return r.position + Vector2(dd, u) * r.size
			"right": return r.position + Vector2(1.0 - dd, u) * r.size
			"top": return r.position + Vector2(u, dd) * r.size
		return r.position + Vector2(u, 1.0 - dd) * r.size
	for band in [[1.0, Color(0.36, 0.22, 0.10, 0.55)], [0.72, Color(0.24, 0.14, 0.07, 0.6)], [0.4, Color(0.07, 0.05, 0.04, 0.97)]]:
		var poly := PackedVector2Array()
		poly.append(to_pt.call(0.0, 0.0))
		for e in edge: poly.append(to_pt.call(float(e[0]), float(e[1]) * float(band[0])))
		poly.append(to_pt.call(1.0, 0.0))
		ci.draw_colored_polygon(poly, band[1])
	var rim := PackedVector2Array()
	for e in edge: rim.append(to_pt.call(float(e[0]), float(e[1]) * 0.4))
	ci.draw_polyline(rim, Color(0.55, 0.28, 0.1, 0.8), maxf(1.0, 0.8 * z))

func _vtext(ci: CanvasItem, r: Rect2, at: Vector2, text: String, size: float, col: Color, bleed: float, z: float) -> void:
	var fs := maxi(4, int(size * r.size.x))
	var step := size * r.size.x * 1.08
	var p := r.position + at * r.size
	for i in text.length():
		var ch := text.substr(i, 1)
		if ch == " ": p.y += step * 0.6; continue
		var o := Vector2(-fs * 0.5, fs * 0.86)
		if bleed > 0.0:
			var rad := fs * 0.07 * bleed
			for k in 8:
				var a := TAU * k / 8.0
				ci.draw_string(_font, p + o + Vector2(cos(a), sin(a)) * rad, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, col.a * 0.16 * bleed))
		ci.draw_string(_font, p + o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		p.y += step

func _seal(ci: CanvasItem, r: Rect2, s: Dictionary, z: float) -> void:
	var c := r.position + Vector2(float(s.at[0]), float(s.at[1])) * r.size
	var half := float(s.get("size", 0.16)) * r.size.x * 0.5
	var col := Color(_col(s.get("col"), SEAL), float(s.get("alpha", 0.86)))
	var rot := float(s.get("rot", 0.0))
	var tr := Transform2D(rot, c)
	ci.draw_set_transform_matrix(tr)
	ci.draw_rect(Rect2(-half, -half, half * 2, half * 2), col)
	ci.draw_rect(Rect2(-half * 0.86, -half * 0.86, half * 1.72, half * 1.72), Color(PAPER, 0.5 * col.a), false, maxf(1.0, half * 0.05))
	var rng := RandomNumberGenerator.new(); rng.seed = int(s.get("seed", 5))
	for i in 40:   # 인주가 덜 묻은 자리
		ci.draw_circle(Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half)), maxf(0.6, half * rng.randf_range(0.02, 0.06)), Color(PAPER, 0.35 * col.a))
	var t := String(s.get("text", ""))
	var fs := maxi(4, int(half * 0.78))
	var cells := [Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, -0.5), Vector2(-0.5, 0.5)]   # 오른쪽 위→아래, 왼쪽 위→아래
	for i in mini(4, t.length()):
		var cp: Vector2 = cells[i] * half * 0.92
		ci.draw_string(_font, cp + Vector2(-fs * 0.5, fs * 0.36), t.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PAPER, 0.92 * col.a))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

func _texture(path: String) -> Texture2D:
	if _tex.has(path): return _tex[path]
	var t: Texture2D = null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path)) if FileAccess.file_exists(path) else null
	if img != null and not img.is_empty(): t = ImageTexture.create_from_image(img)
	_tex[path] = t
	return t
