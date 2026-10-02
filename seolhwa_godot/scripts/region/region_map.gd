# 지도 — M: 지금 고을의 도시 지도(건물·길·성벽·텃밭), Tab: 전체 지도로 전환, 휠·+/-: 확대·축소,
# 드래그·방향키: 옮기기, Esc·M: 닫기. 바탕은 고지도풍 그림(map.png), 그 위 길·건물은 벡터로 그려 확대해도 선명하다.
extends CanvasLayer

const PlaceTitle := preload("res://scripts/region/place_title.gd")
const BuildingTitles := preload("res://scripts/region/building_titles.gd")

# 지도에 그릴 건물 키트 → 지붕 색 종류
const ROOF_TILE := ["village/giwa", "village/jeongja"]
const ROOF_THATCH := ["village/choga", "village/house_compound", "village/jumak", "village/market_shop", "village/mulbang_a",
	"village/didil_bang_a", "village/oeyanggan", "village/heotgan", "village/dwitgan", "village/seonghwangdang", "village/daemun"]
const FIELD := ["nature/garden_plot", "village/teotbat"]
const MAX_K := 8.0   # 최대 확대: 1m = 8px

var world
var _meta := {}
var _tex: Texture2D
var _canvas: Control
var _font: SystemFont
var _hint: Label
var _items: Array = []   # {kind, c, ry, half, name}
var _walls: Array = []   # [[a, b] …] 성벽·담(게임 좌표 선분)
var _towns: Array = []   # [name, center, rect]
var _rivers_named: Array = []
var _player := Vector3.ZERO
var _facing := "down"
var _center := Vector2.ZERO   # 화면 가운데의 게임 좌표
var _k := 1.0                 # 화면 px / 게임 m
var _k_min := 0.1
var _drag := false
var mode := "city"

func setup(w, data_dir: String, loader = null) -> void:
	world = w
	var mp := data_dir.path_join("map.json")
	if not FileAccess.file_exists(mp): return
	_meta = JSON.parse_string(FileAccess.get_file_as_string(mp))
	var img := Image.load_from_file(ProjectSettings.globalize_path(data_dir.path_join(_meta.file)))
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	var groups := {}
	for s in w.region.get("settlements", []):
		var t: String = PlaceTitle.TITLES.get(String(s.get("id", "")), "")
		if t == "": continue
		var bb = s.get("bbox")
		var r: Rect2
		if bb is Array and bb.size() == 4: r = Rect2(Vector2(bb[0], bb[1]), Vector2(bb[2] - bb[0], bb[3] - bb[1]))
		else:
			var rad := float(s.get("radius_m", 40.0)); r = Rect2(Vector2(float(s.x) - rad, float(s.z) - rad), Vector2(rad * 2, rad * 2))
		groups[t] = (groups[t] as Rect2).merge(r) if groups.has(t) else r
	for t in groups: _towns.append([t, (groups[t] as Rect2).get_center(), groups[t]])
	for r in w.region.get("rivers", []):
		if String(r.get("grade", "D")) in ["S", "A", "B"] and String(r.get("name", "")) != "":
			var pts: Array = r.points; var m: Array = pts[pts.size() / 2]
			_rivers_named.append([String(r.name), Vector2(float(m[0]), float(m[1]))])
	if loader: _collect_items(loader)

func _collect_items(loader) -> void:
	for f in loader.files():
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		if not (d is Dictionary): continue
		for it in d.get("items", []):
			var kit := String(it.get("kit", ""))
			var params: Dictionary = it.get("params", {}) if it.get("params") is Dictionary else {}
			var c := Vector2(float(it.x), float(it.z)); var ry := float(it.get("ry", 0.0))
			if kit == "landmark/namwon_eupseong":
				var h := float(params.get("side", 186.0)) / 2.0
				var cs := [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]
				for i in 4: _walls.append([c + (cs[i] as Vector2).rotated(ry), c + (cs[(i + 1) % 4] as Vector2).rotated(ry)])
				continue
			if kit == "village/wall_run":
				var pts = params.get("points")
				if pts is Array:
					for i in pts.size() - 1:
						_walls.append([c + Vector2(float(pts[i][0]), float(pts[i][1])).rotated(ry), c + Vector2(float(pts[i + 1][0]), float(pts[i + 1][1])).rotated(ry)])
				continue
			var kind := ""
			if kit == "landmark/gwanghallu_pond": kind = "water"
			elif kit in ROOF_TILE or (kit.begins_with("landmark/") and not kit.ends_with("_wall")): kind = "tile"
			elif kit in ROOF_THATCH: kind = "thatch"
			elif kit in FIELD: kind = "field"
			elif kit == "village/jwapan": kind = "stall"
			else: continue
			if kit == "village/house_compound" and String(params.get("size", "")) == "large": kind = "tile"
			var fp := Vector2.ZERO
			var f0 = it.get("footprint")
			if f0 is Array and f0.size() >= 2: fp = Vector2(float(f0[0]), float(f0[1]))
			if fp == Vector2.ZERO: fp = loader._catalog_fp(kit, params)
			if fp == Vector2.ZERO: fp = Vector2(8, 6)
			_items.append({ kind = kind, c = c, ry = ry, half = fp / 2.0, name = BuildingTitles.NAMES.get(kit, "") })

func _ready() -> void:
	layer = 10
	visible = false
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["AppleMyungjo", "Nanum Myeongjo", "NanumMyeongjo", "Batang", "Noto Serif CJK KR", "Apple SD Gothic Neo"])
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_canvas = Control.new()
	_canvas.clip_contents = true
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_on_input)
	add_child(_canvas)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

# ---- 열기·전환 ----
func toggle() -> void:
	if _meta.is_empty(): return
	if visible: visible = false; return
	visible = true
	_layout()
	var town = _town_at(Vector2(_player.x, _player.z))
	if town != null: _show_city(town)
	else: _show_all()

func _town_at(p: Vector2):
	var best = null; var bd := INF
	for t in _towns:
		if (t[2] as Rect2).grow(120.0).has_point(p):
			var d := p.distance_to(t[1])
			if d < bd: bd = d; best = t
	return best

func _nearest_town(p: Vector2):
	var best = null; var bd := INF
	for t in _towns:
		var d := p.distance_to(t[1])
		if d < bd: bd = d; best = t
	return best

func _show_city(t) -> void:
	mode = "city"
	var r: Rect2 = (t[2] as Rect2).grow(40.0)
	var cs := _canvas.size
	_k = clampf(minf(cs.x / r.size.x, cs.y / r.size.y), _k_min, MAX_K)
	_center = r.get_center()
	_update_hint(); _canvas.queue_redraw()

func _show_all() -> void:
	mode = "all"
	_k = _k_min
	_center = Vector2(float(_meta.x0) + float(_meta.w) * float(_meta.scale) / 2.0, float(_meta.z0) + float(_meta.h) * float(_meta.scale) / 2.0)
	_update_hint(); _canvas.queue_redraw()

func _update_hint() -> void:
	_hint.text = ("도시 지도" if mode == "city" else "전체 지도") + "   Tab 전환 · 휠/+- 확대·축소 · 드래그/방향키 이동 · M/Esc 닫기"
	_hint.reset_size()
	var vs := get_viewport().get_visible_rect().size
	_hint.position = Vector2((vs.x - _hint.size.x) / 2.0, vs.y - _hint.size.y - 14)

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	_canvas.position = vs * 0.04
	_canvas.size = vs * Vector2(0.92, 0.86)
	var world_w := float(_meta.w) * float(_meta.scale); var world_h := float(_meta.h) * float(_meta.scale)
	_k_min = minf(_canvas.size.x / world_w, _canvas.size.y / world_h)

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo): return
	var kc: int = e.physical_keycode
	if kc == KEY_M: toggle(); get_viewport().set_input_as_handled(); return
	if not visible: return
	match kc:
		KEY_ESCAPE: visible = false
		KEY_TAB:
			if mode == "city": _show_all()
			else:
				var t = _town_at(Vector2(_player.x, _player.z))
				if t == null: t = _nearest_town(_center)
				if t != null: _show_city(t)
		KEY_EQUAL, KEY_KP_ADD: _zoom(1.25, _canvas.size / 2.0)
		KEY_MINUS, KEY_KP_SUBTRACT: _zoom(0.8, _canvas.size / 2.0)
		KEY_LEFT: _pan(Vector2(80, 0))
		KEY_RIGHT: _pan(Vector2(-80, 0))
		KEY_UP: _pan(Vector2(0, 80))
		KEY_DOWN: _pan(Vector2(0, -80))
		_: return
	get_viewport().set_input_as_handled()

func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed: _zoom(1.15, e.position)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed: _zoom(1.0 / 1.15, e.position)
		elif e.button_index == MOUSE_BUTTON_LEFT: _drag = e.pressed
	elif e is InputEventMouseMotion and _drag:
		_pan(e.relative)
	elif e is InputEventMagnifyGesture:
		_zoom(e.factor, e.position)
	elif e is InputEventPanGesture:
		_pan(-e.delta * 8.0)

func _zoom(f: float, at: Vector2) -> void:
	var before := _to_world(at)
	_k = clampf(_k * f, _k_min, MAX_K)
	_center += before - _to_world(at)
	mode = "all" if _k <= _k_min * 1.6 else "city"
	_update_hint(); _canvas.queue_redraw()

func _pan(d: Vector2) -> void:
	_center -= d / _k
	_canvas.queue_redraw()

func _to_px(g: Vector2) -> Vector2:
	return (g - _center) * _k + _canvas.size / 2.0

func _to_world(p: Vector2) -> Vector2:
	return (p - _canvas.size / 2.0) / _k + _center

func update(pos: Vector3, facing: String) -> void:
	_player = pos; _facing = facing
	if visible: _canvas.queue_redraw()

# ---- 그리기 ----
func _draw_map() -> void:
	var cs := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, cs), Color(0.94, 0.91, 0.84))
	var tl := _to_px(Vector2(float(_meta.x0), float(_meta.z0)))
	var sz := Vector2(float(_meta.w), float(_meta.h)) * float(_meta.scale) * _k
	_canvas.draw_texture_rect(_tex, Rect2(tl, sz), false)
	var view := Rect2(_to_world(Vector2.ZERO), cs / _k).grow(20.0)
	if _k > 0.6:   # 도시 축척에서만 길·건물을 벡터로
		for r in world.region.get("roads", []):
			var line := PackedVector2Array()
			for p in r.points: line.append(_to_px(Vector2(float(p[0]), float(p[1]))))
			_canvas.draw_polyline(line, Color(0.80, 0.70, 0.52), maxf(1.5, float(r.get("width_m", 3.0)) * _k), true)
		for it in _items:
			var c: Vector2 = it.c
			if not view.has_point(c): continue
			var hf: Vector2 = it.half
			var poly := PackedVector2Array()
			for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				poly.append(_to_px(c + (hf * s).rotated(float(it.ry))))
			var col: Color = { tile = Color(0.42, 0.45, 0.48), thatch = Color(0.74, 0.62, 0.40), field = Color(0.55, 0.62, 0.38, 0.8), stall = Color(0.85, 0.80, 0.68), water = Color(0.45, 0.6, 0.65, 0.9) }[it.kind]
			_canvas.draw_colored_polygon(poly, col)
			if it.kind != "field" and it.kind != "water":
				poly.append(poly[0])
				_canvas.draw_polyline(poly, Color(0.17, 0.15, 0.13), 1.0)
		for w in _walls:
			var a: Vector2 = w[0]; var b: Vector2 = w[1]
			if not (view.has_point(a) or view.has_point(b)): continue
			_canvas.draw_line(_to_px(a), _to_px(b), Color(0.25, 0.22, 0.2), maxf(1.5, 1.2 * _k))
		if _k > 0.9:
			for it in _items:
				if it.name != "" and view.has_point(it.c):
					_text(it.name, _to_px(it.c) + Vector2(0, -(it.half as Vector2).y * _k - 10), 14, Color(0.1, 0.08, 0.07))
	for t in _towns:
		var r: Rect2 = t[2]
		if _k > 1.4:
			if r.grow(60).intersects(view): _text(t[0], _to_px(Vector2(r.get_center().x, r.position.y)) + Vector2(0, -18), 26, Color(0.1, 0.08, 0.07))
		else: _text(t[0], _to_px(t[1]), 20, Color(0.1, 0.08, 0.07))
	if _k < 1.4:
		for rn in _rivers_named: _text(rn[0], _to_px(rn[1]), 14, Color(0.25, 0.38, 0.45))
	var p := _to_px(Vector2(_player.x, _player.z))
	var d: Vector2 = { up = Vector2(0, -1), down = Vector2(0, 1), left = Vector2(-1, 0), right = Vector2(1, 0) }.get(_facing, Vector2(0, 1))
	var side := Vector2(-d.y, d.x)
	var tri := PackedVector2Array([p + d * 13.0, p - d * 7.0 + side * 8.0, p - d * 7.0 - side * 8.0])
	_canvas.draw_circle(p, 15.0, Color(0.75, 0.15, 0.1, 0.25))
	_canvas.draw_colored_polygon(tri, Color(0.75, 0.15, 0.1))
	_canvas.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(1, 1, 1), 2.0)
	_canvas.draw_rect(Rect2(Vector2.ZERO, cs), Color(0.17, 0.15, 0.13), false, 3.0)

func _text(s: String, at: Vector2, size: int, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := at + Vector2(-w / 2.0, size * 0.35)
	_canvas.draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.96, 0.93, 0.85, 0.9))
	_canvas.draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
