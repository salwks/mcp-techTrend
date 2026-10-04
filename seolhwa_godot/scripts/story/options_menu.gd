# 설정 · 잠시 멈춤 — 시작 메뉴의 '설정'과 놀이 중 Esc(scripts/story/onboarding.gd)가 연다.
#   상호작용 안내(항상/초반만/최소/끔) · 조사 도움(기본/자세히/최소) — 전투 난이도와 상관없다(보강서 §26). user://settings.json.
#   놀이 중(in_game)이면 화면을 멈추고(get_tree().paused) '계속하기'·'여행 방법'(기록책 3쪽)도 보인다.
# 조작: ↑↓·W·S 고르기 · ←→·A·D 바꾸기 · Enter·E·Space 실행 · Esc 닫기 · 클릭.
extends CanvasLayer

const GameSettings := preload("res://scripts/story/game_settings.gd")
const PAPER := Color("#efe6d2")
const INK := Color("#2b2622")
const INK_SOFT := Color("#5a5048")
const SEAL := Color("#a8443c")

var in_game := false
var on_help: Callable = Callable()
var on_close: Callable = Callable()
var _rows: Array = []      # [{id, label: Label, kind: "act"|"opt", key, values, names}]
var _sel := 0
var _font: SystemFont
var _was_paused := false

func _init(game := false) -> void:
	in_game = game
	layer = 40
	name = "options_menu"
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["AppleMyungjo", "Nanum Myeongjo", "NanumMyeongjo", "Batang", "Noto Serif CJK KR", "Apple SD Gothic Neo"])
	if in_game:
		_was_paused = get_tree().paused
		get_tree().paused = true
	var k: float = clampf(get_viewport().get_visible_rect().size.y / 768.0, 0.8, 2.4)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.45); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.97); sb.border_color = INK; sb.set_border_width_all(3)
	sb.content_margin_left = 40 * k; sb.content_margin_right = 40 * k; sb.content_margin_top = 26 * k; sb.content_margin_bottom = 26 * k
	p.add_theme_stylebox_override("panel", sb)
	cc.add_child(p)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", int(10 * k))
	p.add_child(box)
	var t := _lab("잠시 멈춤" if in_game else "설정", int(36 * k), INK); box.add_child(t)
	var r := ColorRect.new(); r.color = INK; r.custom_minimum_size = Vector2(420 * k, 2); box.add_child(r)
	if in_game: _add(box, k, { id = "resume", kind = "act", text = "계속하기" })
	_add(box, k, { id = "guide", kind = "opt", key = "guide", values = GameSettings.GUIDE, names = GameSettings.GUIDE_LABEL, text = "상호작용 안내" })
	_add(box, k, { id = "help", kind = "opt", key = "help", values = GameSettings.HELP, names = GameSettings.HELP_LABEL, text = "조사 도움" })
	if in_game: _add(box, k, { id = "howto", kind = "act", text = "여행 방법 (기록책)" })
	_add(box, k, { id = "close", kind = "act", text = "돌아가기" if not in_game else "닫기" })
	var note := _lab("조사 도움은 전투 난이도와 상관없다.", int(16 * k), INK_SOFT); box.add_child(note)
	var keys := _lab("↑↓ 고르기 · ←→ 바꾸기 · Enter 실행 · Esc 닫기", int(16 * k), INK_SOFT); box.add_child(keys)
	_refresh()

func _lab(text: String, size: int, col: Color) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_override("font", _font); l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _add(box: VBoxContainer, k: float, spec: Dictionary) -> void:
	var l := _lab("", int(26 * k), INK)
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	var i := _rows.size()
	l.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_sel = i
			if spec.kind == "opt": _change(1)
			else: _act())
	box.add_child(l)
	spec.label = l
	_rows.append(spec)

func _refresh() -> void:
	for i in _rows.size():
		var rw: Dictionary = _rows[i]
		var on := i == _sel
		var txt := String(rw.text)
		if rw.kind == "opt":
			var v := GameSettings.get_v(String(rw.key))
			txt = "%s     ◀ %s ▶" % [txt, String(rw.names.get(v, v))]
		(rw.label as Label).text = ("▸ " if on else "   ") + txt
		(rw.label as Label).add_theme_color_override("font_color", SEAL if on else INK)

func _change(dir: int) -> void:
	var rw: Dictionary = _rows[_sel]
	if rw.kind != "opt": return
	var vals: Array = rw.values
	var cur := vals.find(GameSettings.get_v(String(rw.key)))
	GameSettings.set_v(String(rw.key), String(vals[posmod(cur + dir, vals.size())]))
	_refresh()

func _act() -> void:
	match String(_rows[_sel].id):
		"resume", "close": close()
		"howto":
			close()
			if on_help.is_valid(): on_help.call()

func close() -> void:
	if in_game: get_tree().paused = _was_paused
	if on_close.is_valid(): on_close.call()
	queue_free()

func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo): return
	match ev.physical_keycode:
		KEY_UP, KEY_W: _sel = posmod(_sel - 1, _rows.size()); _refresh()
		KEY_DOWN, KEY_S: _sel = posmod(_sel + 1, _rows.size()); _refresh()
		KEY_LEFT, KEY_A: _change(-1)
		KEY_RIGHT, KEY_D: _change(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
			if _rows[_sel].kind == "opt": _change(1)
			else: _act()
		KEY_ESCAPE: close()
		_: return
	get_viewport().set_input_as_handled()
