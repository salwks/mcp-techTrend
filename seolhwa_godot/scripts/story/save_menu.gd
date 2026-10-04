# 저장 · 불러오기 창(Esc 멈춤 메뉴 · 시작 메뉴에서) — 한지 위에 칸 넷: 자동 기록 + 손으로 남기는 칸 1~3.
#   칸마다 작은 그림 · 고을 · 사건 · 게임 안 시각(시진) · 놀이 시간 · 남긴 때.
#   저장: 칸 1~3에 지금 진행을 남긴다(차 있으면 한 번 더 눌러 덮어쓴다). 불러오기: 그 칸으로 돌아간다(한 번 더 눌러 확인 — 지금 진행은 사라진다).
#   ↑↓·W·S 고르기 · Enter·E·Space 정하기 · Tab 저장↔불러오기 · Esc 닫기 · 클릭.
# keeper(save_keeper.gd)가 있으면 그것으로 저장·불러오기, 없으면(시작 메뉴) on_load(n)을 부른다.
extends CanvasLayer

const Progress := preload("res://scripts/region/progress.gd")
const UiFonts := preload("res://scripts/ui_fonts.gd")
const SaveKeeper := preload("res://scripts/story/save_keeper.gd")
const PAPER := Color("#efe6d2")
const INK := Color("#2b2622")
const INK_SOFT := Color("#5f554b")
const SEAL := Color("#a8443c")

var mode := "save"
var keeper = null
var on_close: Callable = Callable()
var on_load: Callable = Callable()   # (n) — keeper가 없을 때(시작 메뉴)
var _rows: Array = []
var _sel := 0
var _arm := -1
var _k := 1.0
var _box: VBoxContainer
var _title: Label
var _msg: Label
var _was_paused := false

func _init(m := "save", k = null) -> void:
	mode = m
	keeper = k
	layer = 45
	name = "save_menu"
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_was_paused = get_tree().paused
	if keeper != null: get_tree().paused = true
	_k = clampf(get_viewport().get_visible_rect().size.y / 768.0, 0.8, 2.4)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.5); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(PAPER, 0.98); sb.border_color = Color(INK, 0.8); sb.set_border_width_all(2)
	sb.set_corner_radius_all(2); sb.shadow_color = Color(0, 0, 0, 0.35); sb.shadow_size = 10
	sb.content_margin_left = 34 * _k; sb.content_margin_right = 34 * _k; sb.content_margin_top = 22 * _k; sb.content_margin_bottom = 20 * _k
	p.add_theme_stylebox_override("panel", sb)
	cc.add_child(p)
	_box = VBoxContainer.new(); _box.add_theme_constant_override("separation", int(10 * _k))
	p.add_child(_box)
	_build()

func _lab(text: String, size: float, col: Color, classic := false) -> Label:
	var l := UiFonts.label(text, int(size * _k), col, classic)
	return l

func _build() -> void:
	for c in _box.get_children(): c.queue_free()
	_rows = []
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", int(26 * _k))
	for m in ["save", "load"]:
		var on: bool = m == mode
		var t := _lab("저장" if m == "save" else "불러오기", 34 if on else 24, SEAL if on else INK_SOFT, true)
		t.size_flags_vertical = Control.SIZE_SHRINK_END
		t.mouse_filter = Control.MOUSE_FILTER_STOP
		var mm: String = m
		t.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: _switch(mm))
		head.add_child(t)
	_box.add_child(head)
	var r := ColorRect.new(); r.color = Color(INK, 0.7); r.custom_minimum_size = Vector2(620 * _k, 1.5); _box.add_child(r)
	for n in range(0, Progress.SLOTS + 1):
		_add_row(n)
	_msg = _lab("", 17, SEAL); _box.add_child(_msg)
	var keys := _lab("↑↓ 고르기 · Enter 정하기 · Tab 저장/불러오기 · Esc 닫기", 15, INK_SOFT); _box.add_child(keys)
	if _sel >= _rows.size() or not _rows[_sel].ok: _sel = _first_ok()
	_refresh()

func _first_ok() -> int:
	for i in _rows.size():
		if _rows[i].ok: return i
	return 0

func _add_row(n: int) -> void:
	var info := Progress.slot_info(n)
	var ok := (n > 0) if mode == "save" else not info.is_empty()
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0, 0, 0, 0); sb.border_color = Color(INK, 0.25); sb.set_border_width_all(1)
	sb.content_margin_left = 10 * _k; sb.content_margin_right = 10 * _k; sb.content_margin_top = 6 * _k; sb.content_margin_bottom = 6 * _k
	row.add_theme_stylebox_override("panel", sb)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", int(14 * _k)); h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var tr := TextureRect.new(); tr.custom_minimum_size = Vector2(128, 72) * _k
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if String(info.get("thumb", "")) != "":
		var img := Image.load_from_file(ProjectSettings.globalize_path(String(info.thumb)))
		if img != null and not img.is_empty(): tr.texture = ImageTexture.create_from_image(img)
	var frame := PanelContainer.new(); frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsb := StyleBoxFlat.new(); fsb.bg_color = Color(0.82, 0.77, 0.66); fsb.border_color = Color(INK, 0.6); fsb.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.add_child(tr)
	h.add_child(frame)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", int(2 * _k)); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := _lab("자동 기록" if n == 0 else "칸 %d" % n, 21, SEAL, true)
	v.add_child(name_l)
	if info.is_empty():
		v.add_child(_lab("비어 있음" if n > 0 else "아직 없음", 18, INK_SOFT))
	else:
		var m: Dictionary = info.meta
		var place := String(m.get("place", ""))
		if place == "": place = String(info.where.get("space", ""))
		var cs := String(m.get("case", ""))
		v.add_child(_lab(place + (("  ·  「%s」" % cs) if cs != "" else ""), 19, INK))
		var parts := []
		if m.has("hour"): parts.append(SaveKeeper.hour_text(float(m.hour)))
		elif info.where.has("hour"): parts.append(SaveKeeper.hour_text(float(info.where.hour)))
		var play := int(float(m.get("play", 0.0)))
		if play > 0: parts.append("놀이 %s" % _dur(play))
		parts.append(_when(String(info.saved_at)))
		v.add_child(_lab("  ·  ".join(parts), 16, INK_SOFT))
	if n == 0 and mode == "save":
		v.add_child(_lab("고을에 들어설 때 · 사건이 나아갈 때 · 길 떠나기 전에 저절로 적힌다", 14, INK_SOFT))
	h.add_child(v)
	var i := _rows.size()
	row.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_sel = i; _refresh(); _act())
	_box.add_child(row)
	_rows.append({ n = n, ok = ok, row = row, name = name_l, filled = not info.is_empty() })

static func _dur(sec: int) -> String:
	var h := sec / 3600; var m := (sec % 3600) / 60
	return ("%d시간 %d분" % [h, m]) if h > 0 else ("%d분" % maxi(1, m))

static func _when(iso: String) -> String:
	# 2026-10-05T14:02:11 → 10월 5일 14:02
	var p := iso.split("T")
	if p.size() < 2: return iso
	var dd := p[0].split("-")
	if dd.size() < 3: return iso
	return "%d월 %d일 %s" % [int(dd[1]), int(dd[2]), p[1].substr(0, 5)]

func _refresh() -> void:
	for i in _rows.size():
		var rw: Dictionary = _rows[i]
		var on := i == _sel
		var sb: StyleBoxFlat = (rw.row as PanelContainer).get_theme_stylebox("panel").duplicate()
		sb.bg_color = Color(INK, 0.08) if on else Color(0, 0, 0, 0)
		sb.border_color = Color(SEAL, 0.9) if on else Color(INK, 0.25)
		sb.set_border_width_all(2 if on else 1)
		(rw.row as PanelContainer).add_theme_stylebox_override("panel", sb)
		(rw.row as PanelContainer).modulate.a = 1.0 if rw.ok else 0.55

func _switch(m: String) -> void:
	if m == mode: return
	mode = m
	_arm = -1
	_build()

func _act() -> void:
	var rw: Dictionary = _rows[_sel]
	if not rw.ok: return
	var n: int = rw.n
	if mode == "save":
		if rw.filled and _arm != _sel:
			_arm = _sel; _msg.text = "칸 %d에는 이미 기록이 있다 — 한 번 더 누르면 덮어쓴다." % n; return
		var ok: bool = keeper.save_to(n) if keeper != null else Progress.save_slot(n)
		_arm = -1
		_build()
		_msg.text = ("칸 %d에 기록을 남겼다." % n) if ok else "남기지 못했다."
	else:
		if keeper != null and _arm != _sel:
			_arm = _sel; _msg.text = "한 번 더 누르면 이 기록으로 돌아간다 — 남기지 않은 지금 진행은 사라진다."; return
		_arm = -1
		var ok := false
		if keeper != null: ok = keeper.load_from(n)
		elif on_load.is_valid(): ok = bool(on_load.call(n))
		if ok: _close(true)
		else: _msg.text = "불러오지 못했다."

func _close(loaded := false) -> void:
	if keeper != null and not loaded: get_tree().paused = _was_paused
	if on_close.is_valid(): on_close.call()
	queue_free()

func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo): return
	match ev.physical_keycode:
		KEY_UP, KEY_W: _sel = posmod(_sel - 1, _rows.size()); _arm = -1; _msg.text = ""; _refresh()
		KEY_DOWN, KEY_S: _sel = posmod(_sel + 1, _rows.size()); _arm = -1; _msg.text = ""; _refresh()
		KEY_TAB: _switch("load" if mode == "save" else "save")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E: _act()
		KEY_ESCAPE: _close()
		_: return
	get_viewport().set_input_as_handled()
