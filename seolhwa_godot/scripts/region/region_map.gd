# 지도 — M: 지금 고을의 도시 지도(건물·길·성벽·텃밭), Tab: 도시 → 권역(전체) → 전국 지도 차례로 전환, 휠·+/-: 확대·축소,
# 드래그·방향키: 옮기기, Esc·M: 닫기.
# H: 역마 창(scripts/region/fast_travel.gd — 가 본 거점으로 빠른 이동)을 연다.
# 전국 지도 역마: 지금 권역에 닿은 지나온 노정(Progress)은 금빛으로 — 숫자 키나 선·도착 고을 클릭으로 고르고 Enter/Y로 건너뛴다. 바탕은 고지도풍 그림(map.png), 그 위 길·건물은 벡터로 그려 확대해도 선명하다.
# 알고 있는 곳만 이름을 쓴다(scripts/region/discovery.gd, 보강서 §20): 고을·이름 있는 건물·사건 장소(map_places)·전국 지도 권역과 거점.
#   지형·물·길·성벽·이름 없는 집채는 늘 그린다. 단서·범인·해결 자리는 지도에 오르지 않는다(사건 데이터 map_places에 넣지 않는다).
extends CanvasLayer

const PlaceTitle := preload("res://scripts/region/place_title.gd")
const Travel := preload("res://scripts/region/travel.gd")
const Progress := preload("res://scripts/region/progress.gd")
const BuildingTitles := preload("res://scripts/region/building_titles.gd")
const Discovery := preload("res://scripts/region/discovery.gd")

# 지도에 그릴 건물 키트 → 지붕 색 종류
const ROOF_TILE := ["village/giwa", "village/jeongja"]
const ROOF_THATCH := ["village/choga", "village/house_compound", "village/jumak", "village/market_shop", "village/mulbang_a",
	"village/didil_bang_a", "village/oeyanggan", "village/heotgan", "village/dwitgan", "village/seonghwangdang", "village/daemun"]
const FIELD := ["nature/garden_plot", "village/teotbat"]
# 문화권 가옥(kit/culture/**): 담·정낭·성벽은 빼고, 지붕 색은 params.roof 또는 키트 기본값으로
const CULTURE_SKIP := ["culture/tamna/doldam", "culture/tamna/jeongnang", "culture/gwanseo/city_wall"]
const CULTURE_TILE := ["culture/gwandong/banga", "culture/yeongnam/jongga", "culture/yeongnam/sadang", "culture/giho/hanok_city",
	"culture/gwanseo/pyeongyang_giwa"]
const CULTURE_TILE_DEFAULT := ["culture/chae", "culture/yeongnam/tteuljip", "culture/giho/giyeok"]   # roof 없으면 기와
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
var _sea_tex: Texture2D       # 바다 칸(world.sea_map, 토지이용 격자) — 바다색으로 물들여 그린다
var _sea_rect := Rect2()      # 그 그림의 게임 좌표 범위
var _lakes: Array = []        # [[이름, 윤곽 PackedVector2Array]]
var _springs: Array = []      # [[이름, Vector2]] 용천수
var _oreums: Array = []       # [[이름, Vector2, 반지름]]
var _wall_kits := {}          # 배치에서 성벽을 얻은 읍성 키트
var _player := Vector3.ZERO
var _facing := "down"
var _center := Vector2.ZERO   # 화면 가운데의 게임 좌표
var _k := 1.0                 # 화면 px / 게임 m
var _k_min := 0.1
var _drag := false
var mode := "city"
var _nk := 1.0                # 전국 지도: 화면 px / 경도 1도
var _ncenter := Vector2(127.5, 38.0)   # 전국 지도 가운데(경도, 위도)
var _nation := {}             # 전국 지도 자료(처음 열 때 만든다)
var _fast_opts: Array = []    # 전국 지도 역마 후보 [{route, name, ft, dest}] — 지금 권역에 닿은 지나온 노정
var _fast_sel := -1           # 고른 후보(확인 기다림)
var _press_at := Vector2.ZERO # 클릭/드래그 구분
var _space := ""              # 지금 공간 id(region_id)
var _story_places: Array = [] # 사건 데이터 map_places(자리를 풀어 둔 것) [{key, name, c, r, spec, bld}]
var _disc_t := 0.0
var on_discover: Callable = Callable()   # (이름, how) — 새로 알게 되면(이야기 쪽 '지도' 첫 안내)

func setup(w, data_dir: String, loader = null) -> void:
	world = w
	_space = String(w.region.get("region_id", ""))
	var mp := data_dir.path_join("map.json")
	if FileAccess.file_exists(mp):
		_meta = JSON.parse_string(FileAccess.get_file_as_string(mp))
		var img := Image.load_from_file(ProjectSettings.globalize_path(data_dir.path_join(_meta.file)))
		img.generate_mipmaps()
		_tex = ImageTexture.create_from_image(img)
	else:
		# 지도 그림(map.png)이 없는 공간(노정·새 권역): 높이맵 범위에 길·물·고을을 벡터로만 그린다
		_meta = { x0 = w.hx0, z0 = w.hz0, w = (w.hnx - 1) * w.hstep, h = (w.hnz - 1) * w.hstep, scale = 1.0 }
	var groups := {}
	var own := PlaceTitle.uses_own_titles(w.region)
	for s in w.region.get("settlements", []):
		var t: String = PlaceTitle.title_for(s, own)
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
	_collect_water(w)

# 바다·호수·용천수·오름·읍성 성벽(region.json) — map.png에 없거나 흐린 것을 벡터로 덧그린다
func _collect_water(w) -> void:
	if "sea_map" in w and w.sea_map != null:
		var img: Image = w.sea_map.duplicate()
		img.generate_mipmaps()
		_sea_tex = ImageTexture.create_from_image(img)
		_sea_rect = Rect2(Vector2(w.lx0 - w.lcell * 0.5, w.lz0 - w.lcell * 0.5), Vector2(w.lw, w.lh) * w.lcell)
	if "lakes" in w:
		for l in w.lakes:
			var poly: PackedVector2Array = l.poly
			_lakes.append([l.name, poly])
	for s in w.region.get("springs", []):
		if s.has("x"): _springs.append([String(s.get("name", "용천수")), Vector2(float(s.x), float(s.z))])
	for o in w.region.get("oreums", []):
		if o.has("x"): _oreums.append([String(o.get("name", "")), Vector2(float(o.x), float(o.z)), float(o.get("radius_m", 60.0))])
	# 성곽 꺾은선(region.json walls — 한양도성·평양성·함흥읍성): 늘 그린다(키트 성벽 조각은 지도 항목에서 빠지므로 겹치지 않는다)
	for wl in w.region.get("walls", []):
		var wp: Array = wl.get("points", [])
		for i in wp.size() - 1:
			_walls.append([Vector2(float(wp[i][0]), float(wp[i][1])), Vector2(float(wp[i + 1][0]), float(wp[i + 1][1]))])
		if bool(wl.get("closed", false)) and wp.size() > 2:
			_walls.append([Vector2(float(wp[-1][0]), float(wp[-1][1])), Vector2(float(wp[0][0]), float(wp[0][1]))])
	_sea_col = RIVER_COL if ("sea_is_river" in w and w.sea_is_river) else SEA_COL
	# 읍성: 배치가 성벽을 주지 않으면 랜드마크 size_m 사각형으로
	for l in w.region.get("landmarks", []):
		var kit := String(l.get("kit", ""))
		if not kit.ends_with("_eupseong") or _wall_kits.has(kit) or kit == "landmark/namwon_eupseong": continue
		var sz = l.get("size_m")
		if not (sz is Array and sz.size() >= 2): continue
		_add_rect_walls(Vector2(float(l.x), float(l.z)), deg_to_rad(float(l.get("ry", 0.0))), Vector2(float(sz[0]), float(sz[1])) / 2.0)

func _add_rect_walls(c: Vector2, ry: float, h: Vector2) -> void:
	var cs := [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]
	for i in 4: _walls.append([c + (cs[i] as Vector2).rotated(ry), c + (cs[(i + 1) % 4] as Vector2).rotated(ry)])

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
			if kit.ends_with("_eupseong"):   # 다른 고을 읍성(제주·경주 등): side 또는 size[w,d] 또는 footprint
				var hv := Vector2.ZERO
				if params.has("side"): hv = Vector2(float(params.side), float(params.side)) / 2.0
				elif params.get("size") is Array and params.size.size() >= 2: hv = Vector2(float(params.size[0]), float(params.size[1])) / 2.0
				elif it.get("footprint") is Array and it.footprint.size() >= 2: hv = Vector2(float(it.footprint[0]), float(it.footprint[1])) / 2.0
				if hv != Vector2.ZERO:
					_add_rect_walls(c, ry, hv); _wall_kits[kit] = true
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
			elif kit.begins_with("culture/"): kind = _culture_kind(kit, params)
			elif kit == "village/jwapan": kind = "stall"
			else: continue
			if kind == "": continue
			if kit == "village/house_compound" and String(params.get("size", "")) == "large": kind = "tile"
			var fp := Vector2.ZERO
			var f0 = it.get("footprint")
			if f0 is Array and f0.size() >= 2: fp = Vector2(float(f0[0]), float(f0[1]))
			if fp == Vector2.ZERO: fp = loader._catalog_fp(kit, params)
			if fp == Vector2.ZERO: fp = Vector2(8, 6)
			_items.append({ kind = kind, c = c, ry = ry, half = fp / 2.0, name = String(it.get("title", BuildingTitles.NAMES.get(kit, ""))) })

# 문화권 키트의 지도 지붕 종류("" = 그리지 않음)
static func _culture_kind(kit: String, params: Dictionary) -> String:
	if kit in CULTURE_SKIP or kit.get_file().begins_with("_"): return ""
	var roof := String(params.get("roof", ""))
	if roof != "": return "tile" if roof.begins_with("giwa") else "thatch"
	if kit in CULTURE_TILE or kit in CULTURE_TILE_DEFAULT: return "tile"
	if kit.ends_with("/compound") and String(params.get("size", "")) == "large" and not kit.begins_with("culture/tamna"): return "tile"
	return "thatch"

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

func show_mode(m: String) -> void:
	if not visible: toggle()
	if m == "nation": _show_nation()
	elif m == "all": _show_all()

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
	_hint.text = { city = "도시 지도(L3)", all = "권역 지도(L2)", nation = "전국 지도(L0)" }.get(mode, "") + "   Tab 전환 · 휠/+- 확대·축소 · 드래그/방향키 이동 · H 역마(가 본 곳으로) · M/Esc 닫기\n가 보았거나 들어서 아는 곳만 이름이 적힌다"
	if mode == "nation" and not _fast_opts.is_empty():
		if _fast_sel >= 0: _hint.text = _fast_ride(_fast_opts[_fast_sel]) + " 타고 %s 가겠소?   Enter/Y 간다 · N/Esc 그만" % _fast_label(_fast_opts[_fast_sel])
		else: _hint.text += "\n역마(지나온 길 건너뛰기): 숫자 키 또는 금빛 길·고을 클릭"
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
	if kc == KEY_H and _fast_sel < 0:   # 역마 창(scripts/region/fast_travel.gd — 가 본 거점으로 빠른 이동)
		var m := get_parent()
		if m != null and m.has_method("open_fast_travel"):
			visible = false
			m.open_fast_travel()
			get_viewport().set_input_as_handled(); return
	if mode == "nation" and _fast_sel >= 0:   # 역마 확인
		match kc:
			KEY_ENTER, KEY_KP_ENTER, KEY_Y, KEY_SPACE: _fast_go()
			KEY_N, KEY_ESCAPE, KEY_BACKSPACE: _fast_sel = -1; _update_hint(); _canvas.queue_redraw()
			_: return
		get_viewport().set_input_as_handled(); return
	if mode == "nation" and kc >= KEY_1 and kc <= KEY_9 and kc - KEY_1 < _fast_opts.size():
		_fast_pick(kc - KEY_1); get_viewport().set_input_as_handled(); return
	match kc:
		KEY_ESCAPE: visible = false
		KEY_TAB:   # 도시 → 권역 전체 → 전국 → 도시
			_fast_sel = -1
			if mode == "city": _show_all()
			elif mode == "all": _show_nation()
			else:
				var t = _town_at(Vector2(_player.x, _player.z))
				if t == null: t = _nearest_town(_center)
				if t != null: _show_city(t)
				else: _show_all()
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
		elif e.button_index == MOUSE_BUTTON_LEFT:
			_drag = e.pressed
			if e.pressed: _press_at = e.position
			elif mode == "nation" and e.position.distance_to(_press_at) < 6.0 and not _fast_opts.is_empty():
				var i := _fast_hit(e.position)
				if i >= 0 and i == _fast_sel: _fast_go()   # 고른 것을 한 번 더 누르면 간다
				elif i >= 0: _fast_pick(i)
	elif e is InputEventMouseMotion and _drag:
		_pan(e.relative)
	elif e is InputEventMagnifyGesture:
		_zoom(e.factor, e.position)
	elif e is InputEventPanGesture:
		_pan(-e.delta * 8.0)

func _zoom(f: float, at: Vector2) -> void:
	if mode == "nation":
		var b := _n_to_geo(at)
		_nk = clampf(_nk * f, _n_fit() * 0.8, _n_fit() * 12.0)
		_ncenter += b - _n_to_geo(at)
		_canvas.queue_redraw(); return
	var before := _to_world(at)
	_k = clampf(_k * f, _k_min, MAX_K)
	_center += before - _to_world(at)
	mode = "all" if _k <= _k_min * 1.6 else "city"
	_update_hint(); _canvas.queue_redraw()

func _pan(d: Vector2) -> void:
	if mode == "nation":
		_ncenter -= Vector2(d.x, -d.y) / _nk; _canvas.queue_redraw(); return
	_center -= d / _k
	_canvas.queue_redraw()

func _to_px(g: Vector2) -> Vector2:
	return (g - _center) * _k + _canvas.size / 2.0

func _to_world(p: Vector2) -> Vector2:
	return (p - _canvas.size / 2.0) / _k + _center

func update(pos: Vector3, facing: String) -> void:
	_player = pos; _facing = facing
	var now := Time.get_ticks_msec() / 1000.0
	if now - _disc_t > 0.4:
		_disc_t = now
		_update_discovery()
	if visible: _canvas.queue_redraw()

# ---- 알게 된 곳(가 봄·들음) ----
func _story():
	var m := get_parent()
	return m.story if m != null and "story" in m else null

# 사건 데이터 map_places — 사건이 바뀌거나 새 게임이면 다시 푼다
func _collect_story_places() -> void:
	_story_places = []
	var st = _story()
	if st == null or st.data.is_empty(): return
	for sp in st.data.get("map_places", []):
		var c: Vector2 = st.anchor(sp.get("at", [0, 0]))
		var e := { key = "place:" + String(sp.id), name = String(sp.get("name", "")), c = c, r = float(sp.get("radius", 18.0)), spec = sp, bld = "" }
		if bool(sp.get("building", false)):   # 그 자리 이름 있는 건물(주막 등)의 이름표를 쓴다
			var bd := 30.0
			for it in _items:
				if it.name != "" and (it.c as Vector2).distance_to(c) < bd: bd = (it.c as Vector2).distance_to(c); e.bld = Discovery.bld_key(it.name, it.c); e.name = it.name
		_story_places.append(e)

func _learn(key: String, told: bool, nm: String) -> void:
	var fresh: bool = Discovery.tell(_space, key) if told else Discovery.visit(_space, key)
	if fresh and on_discover.is_valid() and not Discovery.how(_space, key).is_empty(): on_discover.call(nm, "told" if told else "visited")

func _update_discovery() -> void:
	if _space == "": return
	var p := Vector2(_player.x, _player.z)
	if not Discovery.is_known(Discovery.NATION, "region:" + _space) and not world.is_route: Discovery.visit(Discovery.NATION, "region:" + _space)
	for t in _towns:
		if (t[2] as Rect2).grow(PlaceTitle.MARGIN).has_point(p):
			if not Discovery.is_known(_space, "town:" + String(t[0])):
				Discovery.visit(_space, "town:" + String(t[0]))
				Discovery.visit(Discovery.NATION, "sh:" + String(t[0]))
	for it in _items:
		if it.name == "": continue
		var q: Vector2 = (p - (it.c as Vector2)).rotated(-float(it.ry))
		var hf: Vector2 = it.half
		if absf(q.x) <= hf.x + 14.0 and absf(q.y) <= hf.y + 14.0:
			var k := Discovery.bld_key(it.name, it.c)
			if Discovery.how(_space, k) != "visited": _learn(k, false, it.name)
	var st = _story()
	if st != null and _story_places.size() != st.data.get("map_places", []).size(): _collect_story_places()
	for e in _story_places:
		var sp: Dictionary = e.spec
		var known := Discovery.is_known(_space, e.key)
		if p.distance_to(e.c) < e.r:
			if Discovery.how(_space, e.key) != "visited": _learn(e.key, false, e.name)
		elif not known:
			if bool(sp.get("start_known", false)): Discovery.know(_space, e.key)   # 처음부터 아는 곳(안내 없이)
			elif sp.has("known") and st != null and st.runner != null and st.runner.cond(sp.known): _learn(e.key, true, e.name)
		if e.bld != "" and Discovery.is_known(_space, e.key) and not Discovery.is_known(_space, e.bld):
			if Discovery.how(_space, e.key) == "visited": Discovery.visit(_space, e.bld)
			else: Discovery.tell(_space, e.bld)

# ---- 그리기 ----
func _draw_map() -> void:
	var cs := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, cs), Color(0.94, 0.91, 0.84))
	if mode == "nation":
		_draw_nation(); return
	var tl := _to_px(Vector2(float(_meta.x0), float(_meta.z0)))
	var sz := Vector2(float(_meta.w), float(_meta.h)) * float(_meta.scale) * _k
	if _tex: _canvas.draw_texture_rect(_tex, Rect2(tl, sz), false)
	else: _draw_vector_base(tl, sz)
	var view := Rect2(_to_world(Vector2.ZERO), cs / _k).grow(20.0)
	_draw_water(view)
	if _k > 0.6 or _tex == null:   # 도시 축척에서만 길·건물을 벡터로(지도 그림이 없으면 늘)
		for r in world.region.get("roads", []):
			var line := PackedVector2Array()
			for p in r.points: line.append(_to_px(Vector2(float(p[0]), float(p[1]))))
			if String(r.get("id", "")).contains("ferry"):   # 나룻배 뱃길: 물 위 점선
				for i in line.size() - 1: _canvas.draw_dashed_line(line[i], line[i + 1], Color(0.45, 0.32, 0.2), 2.0, 8.0)
				continue
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
				if it.name != "" and view.has_point(it.c) and Discovery.is_known(_space, Discovery.bld_key(it.name, it.c)):
					_text(it.name, _to_px(it.c) + Vector2(0, -(it.half as Vector2).y * _k - 10), 14, Color(0.1, 0.08, 0.07))
	_draw_story_places(view)
	for t in _towns:
		var r: Rect2 = t[2]
		if not Discovery.is_known(_space, "town:" + String(t[0])): continue
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

# 알게 된 사건 장소: 작은 붉은 먹점 + 이름(건물 이름표를 쓰는 곳은 건물 쪽이 그린다). 들은 곳(told)은 점선 동그라미
func _draw_story_places(view: Rect2) -> void:
	if _k < 0.2: return
	for e in _story_places:
		if e.bld != "" or not Discovery.is_known(_space, e.key) or not view.grow(40).has_point(e.c): continue
		var p := _to_px(e.c)
		var told := Discovery.how(_space, e.key) == "told"
		if told: _canvas.draw_arc(p, 7.0, 0, TAU, 20, Color(0.55, 0.16, 0.1, 0.9), 1.6, true)
		else: _canvas.draw_circle(p, 5.0, Color(0.55, 0.16, 0.1, 0.9))
		_text(String(e.name) + (" (들음)" if told else ""), p + Vector2(0, -16), 15, Color(0.35, 0.1, 0.06))

func _text(s: String, at: Vector2, size: int, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := at + Vector2(-w / 2.0, size * 0.35)
	_canvas.draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.96, 0.93, 0.85, 0.9))
	_canvas.draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# ---- 바다·호수(먹선 물가)·용천수·오름 ----
const SEA_COL := Color(0.60, 0.71, 0.72, 0.92)
const RIVER_COL := Color(0.58, 0.69, 0.64, 0.92)   # 큰 강(sea.kind river) — 바다보다 조금 푸른 녹빛
var _sea_col := SEA_COL
const INK := Color(0.22, 0.24, 0.24)
func _draw_water(view: Rect2) -> void:
	if _sea_tex:
		var r := Rect2(_to_px(_sea_rect.position), _sea_rect.size * _k)
		# 물가 먹선: 조금 짙은 판을 1.5px씩 네 방향으로 밀어 깔고 그 위에 바다색
		for o in [Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5)]:
			_canvas.draw_texture_rect(_sea_tex, Rect2(r.position + o, r.size), false, Color(0.30, 0.36, 0.37, 0.8))
		_canvas.draw_texture_rect(_sea_tex, r, false, _sea_col)
	for l in _lakes:
		var px := PackedVector2Array()
		for q in l[1]: px.append(_to_px(q))
		if Geometry2D.triangulate_polygon(px).is_empty(): continue
		_canvas.draw_colored_polygon(px, Color(0.58, 0.70, 0.70))
		px.append(px[0])
		_canvas.draw_polyline(px, INK, 1.5, true)
		if _k < 1.4:
			var c := Vector2.ZERO
			for q in l[1]: c += q
			_text(l[0], _to_px(c / float(l[1].size())), 16, Color(0.2, 0.32, 0.38))
	if _k > 0.25:
		for o in _oreums:
			if not view.has_point(o[1]): continue
			var p := _to_px(o[1])
			var rr := maxf(5.0, float(o[2]) * _k * 0.5)
			_canvas.draw_arc(p, rr, PI * 1.05, PI * 1.95, 12, Color(0.35, 0.3, 0.24, 0.8), 1.5, true)
			if _k > 0.4: _text(o[0], p + Vector2(0, rr * 0.4 + 6), 12, Color(0.35, 0.28, 0.2))
	if _k > 0.5:
		for sp in _springs:
			if not view.has_point(sp[1]): continue
			var p := _to_px(sp[1])
			_canvas.draw_circle(p, 5.0, Color(0.35, 0.55, 0.65))
			_canvas.draw_arc(p, 5.0, 0, TAU, 16, INK, 1.2, true)
			if _k > 1.0: _text(sp[0], p + Vector2(0, -14), 13, Color(0.2, 0.32, 0.38))

# ---- 지도 그림이 없는 공간: 물·길·고을·포털을 벡터로 ----
func _draw_vector_base(tl: Vector2, sz: Vector2) -> void:
	_canvas.draw_rect(Rect2(tl, sz), Color(0.86, 0.85, 0.74))
	_canvas.draw_rect(Rect2(tl, sz), Color(0.3, 0.27, 0.22), false, 2.0)
	for r in world.region.get("rivers", []):
		var line := PackedVector2Array()
		for p in r.points: line.append(_to_px(Vector2(float(p[0]), float(p[1]))))
		_canvas.draw_polyline(line, Color(0.42, 0.58, 0.66), maxf(2.0, float(r.get("width_m", 6.0)) * _k), true)
	for r in world.region.get("roads", []):
		var line := PackedVector2Array()
		for p in r.points: line.append(_to_px(Vector2(float(p[0]), float(p[1]))))
		_canvas.draw_polyline(line, Color(0.62, 0.45, 0.3), maxf(2.0, float(r.get("width_m", 3.0)) * _k), true)
	for s in (world.region.get("stops", world.region.get("settlements", [])) if _towns.is_empty() else []):
		if s.has("x"): _text(String(s.get("name", "")), _to_px(Vector2(float(s.x), float(s.z))) + Vector2(0, -16), 16, Color(0.1, 0.08, 0.07))
	var main := get_parent()
	for pt in main.portals if "portals" in main else []:
		var c := _to_px(Vector2(pt.x, pt.z))
		_canvas.draw_circle(c, 7.0, Color(0.55, 0.12, 0.08))
		_text("→ " + String(pt.label), c + Vector2(0, 18), 15, Color(0.45, 0.1, 0.06))

# ---- 전국 지도: 한반도 윤곽(travel.gd PENINSULA) + 권역 자리(regions.json map_pos 또는 region.json 투영 기준점) + 노정 선 + 지금 자리 ----
func _n_fit() -> float:
	var b: Rect2 = Travel.OUTLINE_BOX
	return minf(_canvas.size.x / (b.size.x * cos(deg_to_rad(38.0))), _canvas.size.y / b.size.y) * 0.95

func _n_px(g: Vector2) -> Vector2:
	# 경도는 위도 38°의 cos로 줄여 모양을 맞춘다(간단 등장방형)
	return Vector2((g.x - _ncenter.x) * cos(deg_to_rad(38.0)), -(g.y - _ncenter.y)) * _nk + _canvas.size / 2.0

func _n_to_geo(p: Vector2) -> Vector2:
	var d := (p - _canvas.size / 2.0) / _nk
	return Vector2(_ncenter.x + d.x / cos(deg_to_rad(38.0)), _ncenter.y - d.y)

func _show_nation() -> void:
	mode = "nation"
	if _nation.is_empty():
		_nation = { regions = Travel.regions(), routes = Travel.routes(), strongholds = [] }
		var sj = JSON.parse_string(FileAccess.get_file_as_string("res://region_data/strongholds.json"))
		if sj is Dictionary: _nation.strongholds = sj.get("strongholds", [])
	_nk = _n_fit()
	_ncenter = Travel.OUTLINE_BOX.get_center()
	_collect_fast()
	_update_hint(); _canvas.queue_redraw()

# ---- 역마(지도에서 건너뛰기) ----
func _collect_fast() -> void:
	_fast_opts = []; _fast_sel = -1
	if world.is_route: return
	var here := String(world.region.get("region_id", ""))
	for r in _nation.routes:
		if not Progress.route_done(String(r.id)): continue
		var touches := false
		var ps = r.json.get("portals", {})
		if ps is Dictionary:
			for e in ps:
				if ps[e] is Dictionary and String(ps[e].get("region", "")) == here: touches = true
		if not touches: continue
		var ft := Travel.fast_target(String(r.id), here)
		if ft.is_empty(): continue
		var dest := String(ft.target) if ft.kind == "region" else ""
		if dest == "":   # 갈림길 너머 노정: 그 노정의 권역 쪽 끝
			for r2 in _nation.routes:
				if r2.id == ft.target: dest = String(r2.to if r2.to != "" else r2.from)
		_fast_opts.append({ route = String(r.id), name = String(r.get("short", r.name)), ft = ft, dest = dest })

# 강·바다 뱃길은 배, 뭍길은 역마
static func _fast_ride(o: Dictionary) -> String:
	var r := String(o.get("route", ""))
	return "배" if r.begins_with("RIVER_") or r.begins_with("SEA_") else "역마"

func _fast_label(o: Dictionary) -> String:
	return "%s까지 (%s)" % [String(o.ft.label), String(o.name)]

func _fast_pick(i: int) -> void:
	if i < 0 or i >= _fast_opts.size(): return
	_fast_sel = i
	_update_hint(); _canvas.queue_redraw()

func _fast_go() -> void:
	if _fast_sel < 0: return
	var o: Dictionary = _fast_opts[_fast_sel]
	var ft: Dictionary = o.ft.duplicate()
	ft.id = "fast_map_" + String(o.route); ft.fast = true
	ft.label = "%s (%s)" % [String(o.ft.label), _fast_ride(o)]
	_fast_sel = -1
	visible = false
	print("MAP fast_travel route=%s -> %s %s" % [o.route, ft.kind, ft.target])
	var main := get_parent()
	if main.has_method("map_fast_travel"): main.map_fast_travel(ft)

# 전국 지도 클릭: 역마 후보 노정 선(12px) 또는 도착 고을 점(18px) 근처면 그 후보
func _fast_hit(at: Vector2) -> int:
	var best := -1; var bd := INF
	for i in _fast_opts.size():
		var o: Dictionary = _fast_opts[i]
		var ll = _region_ll(String(o.dest))
		if ll != null:
			var d := at.distance_to(_n_px(ll))
			if d < 18.0 and d < bd: bd = d; best = i
		for r in _nation.routes:
			if r.id != o.route: continue
			var line := _route_line(r)
			for k in line.size() - 1:
				var q := Geometry2D.get_closest_point_to_segment(at, _n_px(line[k]), _n_px(line[k + 1]))
				var d2 := at.distance_to(q)
				if d2 < 12.0 and d2 < bd: bd = d2; best = i
	return best

func _region_ll(id: String) -> Variant:
	for r in _nation.regions:
		if String(r.get("id", "")) == id: return r.lonlat
	return null

func _route_line(r: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var gl = r.json.get("geo_line")
	if gl is Array and gl.size() >= 2:
		for p in gl: out.append(Vector2(float(p[0]), float(p[1])))
		return out
	var a = _region_ll(r.from); var b = _region_ll(r.to)
	if a != null and b != null and a != b: out.append(a); out.append(b)
	return out

# 꺾은선 위 길이 비율 f 자리
static func _polyline_at(px: PackedVector2Array, f: float) -> Vector2:
	var total := 0.0
	for i in px.size() - 1: total += px[i].distance_to(px[i + 1])
	var want := total * f
	for i in px.size() - 1:
		var l := px[i].distance_to(px[i + 1])
		if want <= l: return px[i].lerp(px[i + 1], want / maxf(l, 1e-6))
		want -= l
	return px[px.size() - 1]

func _here_ll() -> Variant:
	if not world.is_route:
		var ll = Travel.local_to_lonlat(world.region, _player.x, _player.z)
		return ll if ll != null else _region_ll(String(world.region.get("region_id", "")))
	var rid := String(world.region.get("region_id", ""))
	for r in _nation.routes:
		if r.id != rid: continue
		var line := _route_line(r)
		if line.size() < 2: return null
		var t := Travel.route_progress(r.json, _player.x, _player.z)
		var total := 0.0
		for i in line.size() - 1: total += line[i].distance_to(line[i + 1])
		var want := t * total
		for i in line.size() - 1:
			var l := line[i].distance_to(line[i + 1])
			if want <= l: return line[i].lerp(line[i + 1], want / maxf(l, 1e-9))
			want -= l
		return line[line.size() - 1]
	return null

const FAST_COL := Color(0.80, 0.58, 0.12)
func _draw_fast() -> void:
	for i in _fast_opts.size():
		var o: Dictionary = _fast_opts[i]
		var sel := i == _fast_sel
		for r in _nation.routes:
			if r.id != o.route: continue
			var px := PackedVector2Array()
			for g in _route_line(r): px.append(_n_px(g))
			if px.size() >= 2: _canvas.draw_polyline(px, FAST_COL if not sel else Color(0.95, 0.45, 0.1), 7.0 if sel else 5.0, true)
		var ll = _region_ll(String(o.dest))
		if ll == null: continue
		var c := _n_px(ll) + Vector2(16, 12)
		_canvas.draw_circle(c, 11.0, Color(0.2, 0.17, 0.15))
		_canvas.draw_circle(c, 9.0, FAST_COL if not sel else Color(0.95, 0.45, 0.1))
		_text(str(i + 1), c + Vector2(0, -1), 14, Color(0.1, 0.08, 0.07))
	if _fast_sel >= 0:
		var msg := _fast_ride(_fast_opts[_fast_sel]) + " 타고 %s 가겠소?  Enter/Y · N/Esc" % _fast_label(_fast_opts[_fast_sel])
		var w := _font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 40.0
		var box := Rect2(Vector2((_canvas.size.x - w) / 2.0, 24), Vector2(w, 46))
		_canvas.draw_rect(box, Color(0.96, 0.93, 0.85, 0.95))
		_canvas.draw_rect(box, Color(0.17, 0.15, 0.13), false, 2.0)
		_text(msg, box.get_center(), 22, Color(0.1, 0.08, 0.07))

func _draw_nation() -> void:
	var cs := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, cs), Color(0.80, 0.84, 0.82))   # 바다
	var land := PackedVector2Array()
	for p in Travel.PENINSULA: land.append(_n_px(Vector2(p[0], p[1])))
	var tris := Geometry2D.triangulate_polygon(land)
	if not tris.is_empty(): _canvas.draw_colored_polygon(land, Color(0.93, 0.90, 0.81))
	land.append(land[0])
	_canvas.draw_polyline(land, Color(0.25, 0.22, 0.2), 2.0, true)
	var jj := PackedVector2Array()
	for p in Travel.jeju(): jj.append(_n_px(p))
	_canvas.draw_colored_polygon(jj, Color(0.93, 0.90, 0.81))
	_canvas.draw_polyline(jj, Color(0.25, 0.22, 0.2), 2.0, true)
	var here_id := String(world.region.get("region_id", ""))
	# 노정 이름: route.json `short`(없으면 이름 앞부분). 고을 점과 이미 쓴 이름에 겹치면 선을 따라 자리를 옮기고, 끝내 겹치면 안 쓴다
	var taken: Array = []   # Rect2
	for r in _nation.regions:
		if r.lonlat != null: taken.append(Rect2(_n_px(r.lonlat) - Vector2(40, 34), Vector2(80, 44)))
	for r in _nation.routes:
		var line := _route_line(r)
		if line.size() < 2: continue
		var px := PackedVector2Array()
		for g in line: px.append(_n_px(g))
		var on: bool = r.id == here_id
		_canvas.draw_polyline(px, Color(0.62, 0.2, 0.12) if on else Color(0.45, 0.35, 0.25), 4.0 if on else 2.5, true)
		var nm := String(r.get("short", r.name)) if not on else String(r.name)
		if not on and not Progress.route_done(String(r.id)) and not (Discovery.region_known(String(r.get("from", ""))) and Discovery.region_known(String(r.get("to", "")))): continue
		var w := _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 8.0
		for f in [0.5, 0.35, 0.65, 0.2, 0.8]:
			var at := _polyline_at(px, f) + Vector2(0, -14)
			var box := Rect2(at - Vector2(w / 2.0, 10), Vector2(w, 20))
			var hit := false
			for t in taken:
				if (t as Rect2).intersects(box): hit = true; break
			if hit and not on: continue
			taken.append(box)
			_text(nm, at, 14, Color(0.35, 0.22, 0.15))
			break
	# 명세서 §21 거점(지도에만 있는 곳 포함, region_data/strongholds.json): 작은 네모, 겹치지 않을 때만 이름
	for s in _nation.get("strongholds", []):
		var sp := _n_px(Vector2(float(s.lon), float(s.lat)))
		var built: bool = s.status != "map"
		_canvas.draw_rect(Rect2(sp - Vector2(3, 3), Vector2(6, 6)), Color(0.45, 0.35, 0.25) if built else Color(0.55, 0.5, 0.45))
		if s.status == "region": continue
		var sw := _font.get_string_size(String(s.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 6.0
		var sb := Rect2(sp + Vector2(-sw / 2.0, 4), Vector2(sw, 16))
		var hit := false
		for t in taken:
			if (t as Rect2).intersects(sb): hit = true; break
		if hit: continue
		taken.append(sb)
		if not Discovery.is_known(Discovery.NATION, "sh:" + String(s.name)): continue
		_text(String(s.name), sp + Vector2(0, 12), 12, Color(0.3, 0.26, 0.22) if built else Color(0.45, 0.4, 0.36))
	for r in _nation.regions:
		if r.lonlat == null: continue
		var c := _n_px(r.lonlat)
		var on: bool = String(r.get("id", "")) == here_id
		_canvas.draw_circle(c, 9.0 if on else 6.0, Color(0.2, 0.17, 0.15))
		_canvas.draw_circle(c, 6.0 if on else 4.0, Color(0.85, 0.3, 0.2) if on else Color(0.95, 0.92, 0.85))
		if on or Discovery.region_known(String(r.get("id", ""))):
			_text(String(r.get("short", r.get("name", ""))), c + Vector2(0, -20), 20, Color(0.1, 0.08, 0.07))
	_draw_fast()
	var here = _here_ll()
	if here != null:
		var p := _n_px(here)
		_canvas.draw_circle(p, 14.0, Color(0.75, 0.15, 0.1, 0.25))
		_canvas.draw_circle(p, 6.0, Color(0.75, 0.15, 0.1))
		_canvas.draw_arc(p, 9.0, 0, TAU, 24, Color(1, 1, 1), 2.0)
	_canvas.draw_rect(Rect2(Vector2.ZERO, cs), Color(0.17, 0.15, 0.13), false, 3.0)
