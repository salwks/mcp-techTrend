# 권역 지도 — M 키로 열고 닫는다(Esc로도 닫힘). 고지도풍 그림(region_data/…/map.png) 위에 지명과 내 위치.
extends CanvasLayer

const PlaceTitle := preload("res://scripts/region/place_title.gd")

var world   # RegionWorld
var _meta := {}
var _panel: Control
var _tex: TextureRect
var _me: Control
var _names: Array = []   # [Label, Vector2(게임 x,z)]
var _font: SystemFont
var _player := Vector3.ZERO
var _facing := "down"

func setup(w, data_dir: String) -> void:
	world = w
	var mj = JSON.parse_string(FileAccess.get_file_as_string(data_dir.path_join("map.json")) if FileAccess.file_exists(data_dir.path_join("map.json")) else "null")
	if not (mj is Dictionary): return
	_meta = mj
	var img := Image.load_from_file(ProjectSettings.globalize_path(data_dir.path_join(mj.file)))
	img.generate_mipmaps()
	_tex.texture = ImageTexture.create_from_image(img)
	# 지명: 지명 표시와 같은 묶음(남원·운봉 …)의 중심
	var centers := {}
	for s in w.region.get("settlements", []):
		var t: String = PlaceTitle.TITLES.get(String(s.get("id", "")), "")
		if t == "": continue
		if not centers.has(t): centers[t] = []
		centers[t].append(Vector2(float(s.x), float(s.z)))
	for t in centers:
		var c := Vector2.ZERO
		for p in centers[t]: c += p
		_add_name(t, c / centers[t].size(), 22)
	for p in w.region.get("passes", []):
		var n := String(p.get("name", ""))
		if n.contains("여원"): continue # 지명 '여원재'와 겹침
		if n.begins_with("무명") or n == "": continue
		_add_name(n, Vector2(float(p.x), float(p.z)), 15)
	for r in w.region.get("rivers", []):
		if String(r.get("grade", "D")) in ["S", "A", "B"] and r.has("name") and String(r.name) != "":
			var pts: Array = r.points
			var m: Array = pts[pts.size() / 2]
			_add_name(String(r.name), Vector2(float(m[0]), float(m[1])), 15, Color(0.25, 0.38, 0.45))
	_panel.move_child(_me, -1) # 내 위치 표시는 글자 위에

func _add_name(text: String, at: Vector2, size: int, col := Color(0.12, 0.1, 0.08)) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.96, 0.93, 0.85, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(l)
	_names.append([l, at])

func _ready() -> void:
	layer = 10
	visible = false
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["AppleMyungjo", "Nanum Myeongjo", "NanumMyeongjo", "Batang", "Noto Serif CJK KR", "Apple SD Gothic Neo"])
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_tex = TextureRect.new()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_tex)
	_me = Control.new()
	_me.draw.connect(_draw_me)
	_me.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_me)
	var hint := Label.new()
	hint.text = "M · Esc 닫기"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	add_child(hint)

func toggle() -> void:
	visible = not visible and not _meta.is_empty()
	if visible: _layout()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_M:
		toggle(); get_viewport().set_input_as_handled(); return
	if visible and e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()

# 그림을 화면 92% 안에 비율 유지로
func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var aw := float(_meta.w); var ah := float(_meta.h)
	var k := minf(vs.x * 0.92 / aw, vs.y * 0.86 / ah)
	var size := Vector2(aw, ah) * k
	_panel.position = (vs - size) / 2.0
	_panel.size = size
	_tex.size = size
	_me.size = size
	for e in _names:
		var l: Label = e[0]
		l.reset_size()
		l.position = _to_px(e[1]) - l.size / 2.0
	_me.queue_redraw()

func _to_px(g: Vector2) -> Vector2:
	var k := _panel.size.x / float(_meta.w)
	return Vector2((g.x - float(_meta.x0)) / float(_meta.scale), (g.y - float(_meta.z0)) / float(_meta.scale)) * k

func update(pos: Vector3, facing: String) -> void:
	_player = pos; _facing = facing
	if visible: _me.queue_redraw()

func _draw_me() -> void:
	var p := _to_px(Vector2(_player.x, _player.z))
	var d: Vector2 = { up = Vector2(0, -1), down = Vector2(0, 1), left = Vector2(-1, 0), right = Vector2(1, 0) }.get(_facing, Vector2(0, 1))
	var side := Vector2(-d.y, d.x)
	var tri := PackedVector2Array([p + d * 13.0, p - d * 7.0 + side * 8.0, p - d * 7.0 - side * 8.0])
	_me.draw_circle(p, 15.0, Color(0.75, 0.15, 0.1, 0.25))
	_me.draw_colored_polygon(tri, Color(0.75, 0.15, 0.1))
	_me.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(1, 1, 1), 2.0)
