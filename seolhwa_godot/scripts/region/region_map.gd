# 지도 — 조선 고지도풍(대동여지도·동여도 / 군현지도·도성도). M: 지금 고을의 도시 지도(L3), Tab: 도시 → 권역(L2) → 전국(L0) 차례로,
# 휠·+/-: 확대·축소, 드래그·방향키: 옮기기, Esc·M: 닫기. H: 역참(역마) — 역참 API(Travel.stations)가 있으면 오른쪽 판의 역참 목록,
# 없으면 역마 창(scripts/region/fast_travel.gd). 숫자 키: 역참 고르기(없으면 전국 지도 지나온 노정 건너뛰기).
#
# 바탕 그림은 오프라인(tools/region/render_joseon_map.py): region_data/<id>/map/l2.webp(권역), map/city_*.webp(고을),
#   region_data/nation_map.webp(전국). 그 위에 런타임이 그리는 것: 이름·기호(화면 크기 고정 + 겹침 솎기), 사건 표지(붉은 인),
#   할 말 있는 이야기 인물, 역참, 플레이어, 테두리·방위·10리 자, 오른쪽 판(제목·범례·현재 사건·역참).
# 글자 크기는 확대와 상관없이 늘 같다. 겹치면 우선순위(지금 고을·권역 > 사건 > 거점 > 고을 > 역참 > 마을 > 이름난 곳 > 고개·물)로 솎는다.
#
# 알고 있는 곳만 이름을 쓴다(scripts/region/discovery.gd, 보강서 §20): 고을·이름 있는 건물·사건 장소(map_places)·이름난 곳(lm:)·
#   고개(pass:)·전국 지도 권역과 거점. 산·물·길·성벽·집채(그림)는 늘 그린다. 단서·범인·해결 자리는 지도에 오르지 않는다.
# 사건 표지(scripts/region/map_leads.gd): 사건 데이터 map_leads 중 플레이어가 들은·아는 행선지만. 표지에 마우스를 올리거나 누르면 사건 이름.
# 이야기 인물 할 말 표시: story_director.talk_pending(id)가 참인 인물(NPC 대화 담당 데이터 — 이 파일은 읽기만 한다).
extends CanvasLayer

const PlaceTitle := preload("res://scripts/region/place_title.gd")
const Travel := preload("res://scripts/region/travel.gd")
const Progress := preload("res://scripts/region/progress.gd")
const BuildingTitles := preload("res://scripts/region/building_titles.gd")
const Discovery := preload("res://scripts/region/discovery.gd")
const MapLeads := preload("res://scripts/region/map_leads.gd")
const UiFonts := preload("res://scripts/ui_fonts.gd")

# 지도 이름표에 쓸 건물 키트(이름이 있는 것) — 그림은 오프라인에 구웠다
const ROOF_TILE := ["village/giwa", "village/jeongja"]
const ROOF_THATCH := ["village/choga", "village/house_compound", "village/jumak", "village/market_shop", "village/mulbang_a",
	"village/didil_bang_a", "village/oeyanggan", "village/heotgan", "village/dwitgan", "village/seonghwangdang", "village/daemun"]
const FIELD := ["nature/garden_plot", "village/teotbat"]
const CULTURE_SKIP := ["culture/tamna/doldam", "culture/tamna/jeongnang", "culture/gwanseo/city_wall"]
const CULTURE_TILE := ["culture/gwandong/banga", "culture/yeongnam/jongga", "culture/yeongnam/sadang", "culture/giho/hanok_city",
	"culture/gwanseo/pyeongyang_giwa"]
const CULTURE_TILE_DEFAULT := ["culture/chae", "culture/yeongnam/tteuljip", "culture/giho/giyeok"]
const MAX_K := 6.0   # 최대 확대: 1m = 6px

# 먹·한지 색
const INK := Color(0.13, 0.11, 0.09)
const INK_SOFT := Color(0.33, 0.28, 0.23)
const PAPER := Color(0.95, 0.92, 0.84)
const PAPER_DARK := Color(0.90, 0.85, 0.74)
const SEAL := Color(0.70, 0.16, 0.11)
const WATER_INK := Color(0.22, 0.38, 0.47)
const ROAD_RED := Color(0.69, 0.23, 0.16)
const SEA_COL := Color(0.77, 0.84, 0.82)
const FAST_COL := Color(0.80, 0.58, 0.12)
# 우선순위(작을수록 먼저 자리를 얻는다)
const P_HERE := 0
const P_CASE := 1
const P_HUB := 2
const P_TOWN := 3
const P_STATION := 4
const P_VILLAGE := 5
const P_LANDMARK := 6
const P_MINOR := 7

var world
var _meta := {}
var _tex: Texture2D
var _cities: Array = []       # [{rect: Rect2, file, tex}] 고을 그림(늦게 읽는다)
var _ntex: Texture2D           # 전국 그림
var _nmeta := {}
var _canvas: Control
var _font: Font                # 본문·이름표(덕온공주체 — scripts/ui_fonts.gd)
var _font_t: Font              # 제목·고을·권역 이름(덕온공주체 Classic — scripts/ui_fonts.gd)
var _hint: Label
var _items: Array = []   # {kind, c, ry, half, name}
var _walls: Array = []
var _towns: Array = []   # [name, center, rect, type]
var _rivers_named: Array = []
var _lakes: Array = []
var _springs: Array = []
var _oreums: Array = []
var _player := Vector3.ZERO
var _facing := "down"
var _center := Vector2.ZERO
var _k := 1.0
var _k_min := 0.1
var _drag := false
var mode := "city"
var _nk := 1.0
var _ncenter := Vector2(127.5, 38.0)
var _nation := {}
var _fast_opts: Array = []
var _fast_sel := -1
var _press_at := Vector2.ZERO
var _space := ""
var _story_places: Array = []
var _disc_t := 0.0
var on_discover: Callable = Callable()
# 이번 그림의 자리 차지(겹침 솎기) · 표지 맞춤
var _taken: Array = []
var _hits: Array = []          # [{p, r, tip, lead}]
var _hover = null              # 마우스가 올라간 표지
var _pinned = null             # 누른 표지(설명 고정)
var _mouse := Vector2(-999, -999)
# 사건·역참(열 때·0.5초마다 다시 센다)
var _leads: Array = []
var _talks: Array = []         # [{p: Vector2, name}]
var _dyn_t := 0.0
var _st_api := false
var _st_warp := false
var _stations: Array = []      # 알게 된 역참 [{id, name, space, c(Vector2 또는 null), ll(Vector2 또는 null)}]
var _st_sel := -1
# 오른쪽 판
var _panel: PanelContainer
var _pbox: VBoxContainer
var _ptitle: Label
var _psub: Label
var _legend: Control
var _cases_box: VBoxContainer
var _st_box: VBoxContainer
var _st_head: Label

func setup(w, data_dir: String, loader = null) -> void:
	world = w
	_space = String(w.region.get("region_id", ""))
	var mp := data_dir.path_join("map.json")
	if FileAccess.file_exists(mp):
		_meta = JSON.parse_string(FileAccess.get_file_as_string(mp))
		_tex = _load_tex(data_dir.path_join(String(_meta.file)))
		for c in _meta.get("cities", []):
			_cities.append({ rect = Rect2(float(c.x0), float(c.z0), float(c.w) * float(c.scale), float(c.h) * float(c.scale)),
				file = data_dir.path_join(String(c.file)), tex = null, ids = c.get("ids", []) })
	else:
		_meta = { x0 = w.hx0, z0 = w.hz0, w = (w.hnx - 1) * w.hstep, h = (w.hnz - 1) * w.hstep, scale = 1.0 }
	var groups := {}
	var types := {}
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
		var ty := String(s.get("type", "마을"))
		if not types.has(t) or _type_rank(ty) < _type_rank(String(types[t])): types[t] = ty
	for t in groups: _towns.append([t, (groups[t] as Rect2).get_center(), groups[t], String(types.get(t, "마을"))])
	for r in w.region.get("rivers", []):
		if String(r.get("grade", "D")) in ["S", "A", "B"] and String(r.get("name", "")) != "":
			var pts: Array = r.points; var m: Array = pts[pts.size() / 2]
			_rivers_named.append([String(r.name), Vector2(float(m[0]), float(m[1]))])
	if loader: _collect_items(loader)
	_collect_water(w)
	for m in (Travel as Script).get_script_method_list():
		if m.name == "stations": _st_api = true
		elif m.name == "warp_to_station": _st_warp = true
	MapLeads.cases.call_deferred()   # 사건 데이터를 미리 읽어 둔다(처음 지도 열기를 빠르게)
	var mn := get_parent()
	if mn != null and "args" in mn and mn.args.has("mapshots"): _mapshots.call_deferred(String(mn.args.mapshots))

static func _type_rank(t: String) -> int:
	return { "읍성": 0, "장시": 1, "역": 2, "원": 3, "주막": 3, "사찰": 4, "성황당": 5 }.get(t, 6)

static func _load_tex(path: String) -> Texture2D:
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(abs_path): return null
	var img := Image.load_from_file(abs_path)
	if img == null or img.is_empty(): return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _collect_water(w) -> void:
	if "lakes" in w:
		for l in w.lakes: _lakes.append([l.name, l.poly as PackedVector2Array])
	for s in w.region.get("springs", []):
		if s.has("x"): _springs.append([String(s.get("name", "용천수")), Vector2(float(s.x), float(s.z))])
	for o in w.region.get("oreums", []):
		if o.has("x"): _oreums.append([String(o.get("name", "")), Vector2(float(o.x), float(o.z)), float(o.get("radius_m", 60.0))])

func _collect_items(loader) -> void:
	for f in loader.files():
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		if not (d is Dictionary): continue
		for it in d.get("items", []):
			var kit := String(it.get("kit", ""))
			var params: Dictionary = it.get("params", {}) if it.get("params") is Dictionary else {}
			var c := Vector2(float(it.x), float(it.z)); var ry := float(it.get("ry", 0.0))
			if kit.ends_with("_eupseong") or kit == "village/wall_run": continue
			var kind := ""
			if kit == "landmark/gwanghallu_pond": kind = "water"
			elif kit in ROOF_TILE or (kit.begins_with("landmark/") and not kit.ends_with("_wall")): kind = "tile"
			elif kit in ROOF_THATCH: kind = "thatch"
			elif kit in FIELD: kind = "field"
			elif kit.begins_with("culture/"): kind = _culture_kind(kit, params)
			else: continue
			if kind == "": continue
			var nm := String(it.get("title", BuildingTitles.NAMES.get(kit, "")))
			if nm == "": continue   # 이름 없는 집채는 그림에만(오프라인)
			var fp := Vector2.ZERO
			var f0 = it.get("footprint")
			if f0 is Array and f0.size() >= 2: fp = Vector2(float(f0[0]), float(f0[1]))
			if fp == Vector2.ZERO: fp = loader._catalog_fp(kit, params)
			if fp == Vector2.ZERO: fp = Vector2(8, 6)
			_items.append({ kind = kind, c = c, ry = ry, half = fp / 2.0, name = nm })

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
	add_to_group(preload("res://scripts/hud_gate.gd").OVERLAY)   # 열린 동안 지명·안내 HUD를 감춘다
	_font = UiFonts.main()
	_font_t = UiFonts.classic()
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_canvas = Control.new()
	_canvas.clip_contents = true
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_on_input)
	add_child(_canvas)
	_build_panel()
	_hint = Label.new()
	_hint.add_theme_font_override("font", _font)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(1, 0.97, 0.9, 0.95))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

# ---- 오른쪽 판: 제목 곽·범례·현재 사건·역참 ----
func _build_panel() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK; sb.set_border_width_all(3)
	sb.content_margin_left = 14; sb.content_margin_right = 12; sb.content_margin_top = 12; sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.35); sb.shadow_size = 6
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(sc)
	_pbox = VBoxContainer.new()
	_pbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pbox.add_theme_constant_override("separation", 6)
	sc.add_child(_pbox)
	_ptitle = _plabel("", 27, INK, _font_t)
	_ptitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pbox.add_child(_ptitle)
	_psub = _plabel("", 13, INK_SOFT)
	_psub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pbox.add_child(_psub)
	_pbox.add_child(_rule())
	_pbox.add_child(_plabel("범례", 16, INK, _font_t))
	_legend = Control.new()
	_legend.custom_minimum_size = Vector2(0, 0)
	_legend.draw.connect(_draw_legend)
	_pbox.add_child(_legend)
	_pbox.add_child(_rule())
	_pbox.add_child(_plabel("현재 사건", 18, SEAL, _font_t))
	_cases_box = VBoxContainer.new()
	_cases_box.add_theme_constant_override("separation", 2)
	_pbox.add_child(_cases_box)
	_pbox.add_child(_rule())
	_st_head = _plabel("역참 (H · 숫자 키)", 18, INK, _font_t)
	_pbox.add_child(_st_head)
	_st_box = VBoxContainer.new()
	_st_box.add_theme_constant_override("separation", 2)
	_pbox.add_child(_st_box)

func _plabel(t: String, sz: int, col: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f if f != null else _font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(INK, 0.55)
	r.custom_minimum_size = Vector2(0, 1.5)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _pbutton(t: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", SEAL)
	b.add_theme_color_override("font_pressed_color", SEAL)
	b.pressed.connect(cb)
	return b

const LEGEND := [["eup", "읍치(성곽 고을)"], ["market", "장터 고을"], ["village", "마을"], ["station", "역참·마방"], ["ferry", "나루(진)"],
	["pass", "고개"], ["temple", "절"], ["bongsu", "봉수"], ["case", "사건 — 들은 행선지"], ["talk", "할 말이 있는 사람"], ["road", "큰길(눈금 10리)"]]
func _draw_legend() -> void:
	var y := 10.0
	for e in LEGEND:
		if e[0] == "road":
			_legend.draw_line(Vector2(4, y), Vector2(26, y), ROAD_RED, 3.0)
			for x in [9.0, 20.0]: _legend.draw_line(Vector2(x, y - 4), Vector2(x, y + 4), Color(0.45, 0.12, 0.08), 1.5)
		else: _icon(_legend, String(e[0]), Vector2(15, y), 0.85)
		_legend.draw_string(_font, Vector2(34, y + 5), String(e[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
		y += 21.0
	_legend.custom_minimum_size = Vector2(0, y - 6)

func _refresh_panel() -> void:
	var town = _town_at(_center) if mode == "city" else null
	var rn := Travel.short_name(String(world.region.get("region_name", _space)))
	match mode:
		"nation": _ptitle.text = "조선 팔도"; _psub.text = "전국 지도 · 산줄기와 물길"
		"all": _ptitle.text = rn + " 지도"; _psub.text = "%s · 권역 지도" % String(world.region.get("parent_province", ""))
		_:
			var known: bool = town != null and Discovery.is_known(_space, "town:" + String(town[0]))
			_ptitle.text = (String(town[0]) if known else rn) + " 고을"; _psub.text = "도시 지도 · 군현지도 방식"
	for c in _cases_box.get_children(): c.queue_free()
	var by_case := {}
	for l in _leads:
		if not by_case.has(l.case): by_case[l.case] = []
		by_case[l.case].append(l)
	if by_case.is_empty(): _cases_box.add_child(_plabel("아직 쫓는 사건이 없다.", 13, INK_SOFT))
	for cid in by_case:
		var ls: Array = by_case[cid]
		_cases_box.add_child(_plabel("「%s」" % String(ls[0].title), 15, SEAL, _font_t))
		for l in ls:
			var lead: Dictionary = l
			var where := ""
			if lead.region != "": where = " → " + _region_short(String(lead.region))
			elif lead.space != _space: where = " (" + _space_short(String(lead.space)) + ")"
			_cases_box.add_child(_pbutton(("· 거점: " if lead.hub else "· ") + String(lead.name) + where, INK, _focus_lead.bind(lead)))
	for c in _st_box.get_children(): c.queue_free()
	var st_on := _st_on()
	_st_head.visible = st_on
	_st_box.visible = st_on
	if st_on:
		if _stations.is_empty(): _st_box.add_child(_plabel("가 본 역참이 아직 없다.", 13, INK_SOFT))
		for i in _stations.size():
			var s: Dictionary = _stations[i]
			var lab := "%d. %s" % [i + 1, String(s.name)]
			if s.space != _space: lab += " (" + _space_short(String(s.space)) + ")"
			if not bool(s.get("ok", true)) and String(s.get("why", "")) != "": lab += " — " + String(s.why)
			elif not bool(s.get("ok", true)): lab += " — 아직 못 감"
			if i == _st_sel: lab = "▶ " + lab + " — 한 번 더 누르면 간다"
			_st_box.add_child(_pbutton(lab, SEAL if i == _st_sel else (INK if bool(s.get("ok", true)) else INK_SOFT), _station_click.bind(i)))
	else:
		_pbox.get_child(_pbox.get_child_count() - 1).visible = false

func _region_short(id: String) -> String:
	var r := Travel.region_info(id)
	return String(r.get("short", id)) if not r.is_empty() else id

func _space_short(id: String) -> String:
	var r := Travel.region_info(id)
	if not r.is_empty(): return String(r.get("short", id))
	for rt in Travel.routes():
		if String(rt.id) == id: return String(rt.get("short", rt.get("name", id)))
	return id

# ---- 열기·전환 ----
func toggle() -> void:
	if _meta.is_empty(): return
	if visible: visible = false; return
	visible = true
	_layout()
	_refresh_dynamic()
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
	var r: Rect2 = (t[2] as Rect2).grow(60.0)
	var cs := _canvas.size
	_k = clampf(minf(cs.x / r.size.x, cs.y / r.size.y), _city_k(), MAX_K)
	_center = r.get_center()
	_after_view()

func _show_all() -> void:
	mode = "all"
	_k = _k_min
	_center = Vector2(float(_meta.x0) + float(_meta.w) * float(_meta.scale) / 2.0, float(_meta.z0) + float(_meta.h) * float(_meta.scale) / 2.0)
	_after_view()

# 도시 지도(L3)로 넘어가는 확대: 권역 그림이 제 해상도를 넘길 때(그 전에는 권역 지도)
func _city_k() -> float:
	if _tex == null: return _k_min * 1.6
	return maxf(_k_min * 1.6, 1.15 / float(_meta.scale))

func _after_view() -> void:
	_update_hint(); _refresh_panel(); _canvas.queue_redraw()

func _update_hint() -> void:
	_hint.text = { city = "도시 지도(L3)", all = "권역 지도(L2)", nation = "전국 지도(L0)" }.get(mode, "") + "   Tab 전환 · 휠/+- 확대·축소 · 드래그/방향키 이동 · H 역참 · M/Esc 닫기\n가 보았거나 들어서 아는 곳만 이름이 적힌다 · 붉은 인은 들은 행선지(사건)"
	if _st_sel >= 0 and _st_sel < _stations.size():
		_hint.text = "역마 타고 %s(으)로 가겠소?   Enter/Y 간다 · N/Esc 그만" % String(_stations[_st_sel].name)
	elif mode == "nation" and not _fast_opts.is_empty():
		if _fast_sel >= 0: _hint.text = _fast_ride(_fast_opts[_fast_sel]) + " 타고 %s 가겠소?   Enter/Y 간다 · N/Esc 그만" % _fast_label(_fast_opts[_fast_sel])
		else: _hint.text += "\n지나온 길 건너뛰기: 금빛 길·고을 클릭" + ("" if _st_on() else " 또는 숫자 키")
	_hint.reset_size()
	var vs := get_viewport().get_visible_rect().size
	_hint.position = Vector2((vs.x - _hint.size.x) / 2.0, vs.y - _hint.size.y - 10)

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var pw := clampf(vs.x * 0.22, 210.0, 300.0)
	_canvas.position = Vector2(vs.x * 0.025, vs.y * 0.035)
	_canvas.size = Vector2(vs.x * 0.95 - pw - 10.0, vs.y * 0.86)
	_panel.position = Vector2(_canvas.position.x + _canvas.size.x + 10.0, _canvas.position.y)
	_panel.size = Vector2(pw, _canvas.size.y)
	_panel.custom_minimum_size = _panel.size
	var world_w := float(_meta.w) * float(_meta.scale); var world_h := float(_meta.h) * float(_meta.scale)
	_k_min = minf(_canvas.size.x / world_w, _canvas.size.y / world_h)

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo): return
	var kc: int = e.physical_keycode
	if kc == KEY_M: toggle(); get_viewport().set_input_as_handled(); return
	if not visible: return
	if _st_sel >= 0:   # 역참 확인
		match kc:
			KEY_ENTER, KEY_KP_ENTER, KEY_Y, KEY_SPACE: _station_go()
			KEY_N, KEY_ESCAPE, KEY_BACKSPACE: _st_sel = -1; _after_view()
			_: return
		get_viewport().set_input_as_handled(); return
	if kc == KEY_H and _fast_sel < 0:
		if _st_on() and not _stations.is_empty():   # 역참 목록(오른쪽 판) — 숫자 키·클릭으로 고른다
			_station_pick(0)
			get_viewport().set_input_as_handled(); return
		var m := get_parent()   # 역참 API가 아직 없으면 역마 창(가 본 거점)
		if m != null and m.has_method("open_fast_travel"):
			visible = false
			m.open_fast_travel()
			get_viewport().set_input_as_handled(); return
	if mode == "nation" and _fast_sel >= 0:
		match kc:
			KEY_ENTER, KEY_KP_ENTER, KEY_Y, KEY_SPACE: _fast_go()
			KEY_N, KEY_ESCAPE, KEY_BACKSPACE: _fast_sel = -1; _update_hint(); _canvas.queue_redraw()
			_: return
		get_viewport().set_input_as_handled(); return
	if kc >= KEY_1 and kc <= KEY_9:
		var i := kc - KEY_1
		if _st_on() and i < _stations.size(): _station_pick(i); get_viewport().set_input_as_handled(); return
		if not _st_on() and mode == "nation" and i < _fast_opts.size(): _fast_pick(i); get_viewport().set_input_as_handled(); return
	match kc:
		KEY_ESCAPE:
			if _pinned != null: _pinned = null; _canvas.queue_redraw()
			else: visible = false
		KEY_TAB:
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
			elif e.position.distance_to(_press_at) < 6.0:
				var h = _hit(e.position)
				if h != null:
					if h.has("station") and _st_on():
						if int(h.station) == _st_sel: _station_go()
						else: _station_pick(int(h.station))
					else: _pinned = h; _canvas.queue_redraw()
					return
				_pinned = null
				if mode == "nation" and not _fast_opts.is_empty():
					var i := _fast_hit(e.position)
					if i >= 0 and i == _fast_sel: _fast_go()
					elif i >= 0: _fast_pick(i)
				_canvas.queue_redraw()
	elif e is InputEventMouseMotion:
		_mouse = e.position
		if _drag: _pan(e.relative)
		else:
			var h = _hit(e.position)
			if h != _hover: _hover = h; _canvas.queue_redraw()
	elif e is InputEventMagnifyGesture:
		_zoom(e.factor, e.position)
	elif e is InputEventPanGesture:
		_pan(-e.delta * 8.0)

func _hit(p: Vector2):
	var best = null; var bd := INF
	for h in _hits:
		var d := p.distance_to(h.p)
		if d < float(h.r) and d < bd: bd = d; best = h
	return best

func _zoom(f: float, at: Vector2) -> void:
	if mode == "nation":
		var b := _n_to_geo(at)
		_nk = clampf(_nk * f, _n_fit() * 0.8, _n_fit() * 12.0)
		_ncenter += b - _n_to_geo(at)
		_canvas.queue_redraw(); return
	var before := _to_world(at)
	_k = clampf(_k * f, _k_min, MAX_K)
	_center += before - _to_world(at)
	var m0 := mode
	mode = "all" if _k < _city_k() else "city"
	if m0 != mode: _refresh_panel()
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
	if visible:
		if now - _dyn_t > 0.5: _refresh_dynamic()
		_canvas.queue_redraw()

# ---- 사건 표지·할 말 있는 인물·역참(열 때와 0.5초마다) ----
func _refresh_dynamic() -> void:
	_dyn_t = Time.get_ticks_msec() / 1000.0
	var st = _story()
	var nl: Array = MapLeads.visible(st if st != null and st.runner != null else null)
	var changed := nl.size() != _leads.size()
	_leads = nl
	_talks = []
	if st != null and st.has_method("talk_pending") and st.runner != null:
		for id in st.actors:
			if st.talk_pending(String(id)):
				var a: Dictionary = st.actors[id]
				_talks.append({ p = Vector2(a.pos.x, a.pos.z), name = String(a.get("name", "")) })
	var ns := _collect_stations()
	if ns.size() != _stations.size(): changed = true
	_stations = ns
	if changed and visible: _refresh_panel()

# 역참(역참 담당: Travel.stations() — 없으면 region_data/stations.json을 바로 읽는다) → 알게 된 것만.
#   항목: id, name, space, pos[x,z](또는 x,z), lonlat[lon,lat](또는 lon,lat), node·discover_key(travel_nodes/<공간>/<거점> — 가 보면 적힘)
#   알게 됨: Travel.station_known(id)가 있으면 그것, 없으면 progress.json travel_nodes(역마 거점 발견)
var _st_file = null
func _st_on() -> bool:
	return _st_api or not _station_list().is_empty()

func _station_list() -> Array:
	if _st_api:
		var tr: Object = Travel
		var l = tr.call("stations")
		if l is Array: return l
	if _st_file == null:
		_st_file = []
		if FileAccess.file_exists("res://region_data/stations.json"):
			var j = JSON.parse_string(FileAccess.get_file_as_string("res://region_data/stations.json"))
			if j is Dictionary and j.get("stations") is Array: _st_file = j.stations
			elif j is Array: _st_file = j
	return _st_file

func _collect_stations() -> Array:
	var out: Array = []
	var list := _station_list()
	if list.is_empty(): return out
	var has_known := false
	for m in (Travel as Script).get_script_method_list():
		if m.name == "station_known": has_known = true
	var tn = Progress.data().get("travel_nodes", {})
	for s in list:
		if not (s is Dictionary): continue
		var id := String(s.get("id", ""))
		var sp := String(s.get("space", s.get("region", "")))
		var c = null
		if s.get("yard") is Array and s.yard.size() >= 2: c = Vector2(float(s.yard[0]), float(s.yard[1]))   # 길가 도착 자리
		elif s.get("pos") is Array and s.pos.size() >= 2: c = Vector2(float(s.pos[0]), float(s.pos[1]))
		elif s.has("x") and s.has("z"): c = Vector2(float(s.x), float(s.z))
		var known := false
		if has_known:
			var tr: Object = Travel
			known = bool(tr.call("station_known", id))
		elif s.has("known") or s.has("discovered"): known = bool(s.get("known", s.get("discovered", false)))
		else:
			var node := String(s.get("node", ""))
			var dk := String(s.get("discover_key", ""))
			if dk.begins_with("travel_nodes/"):
				var parts := dk.split("/")
				if parts.size() >= 3: sp = parts[1] if sp == "" else sp; node = parts[2]
			known = tn is Dictionary and tn.get(sp) is Dictionary and (tn[sp] as Dictionary).has(node)
		if not known: continue
		var ll = null
		if s.get("lonlat") is Array and s.lonlat.size() >= 2: ll = Vector2(float(s.lonlat[0]), float(s.lonlat[1]))
		elif s.has("lon") and s.has("lat"): ll = Vector2(float(s.lon), float(s.lat))
		elif c != null and sp == _space and not world.is_route: ll = Travel.local_to_lonlat(world.region, c.x, c.y)
		out.append({ id = id, name = String(s.get("name", id)), space = sp, c = c, ll = ll, ok = bool(s.get("ok", true)), why = String(s.get("why", "")) })
	return out

func _station_pick(i: int) -> void:
	if i < 0 or i >= _stations.size(): return
	_st_sel = i
	var s: Dictionary = _stations[i]
	if s.c != null and s.space == _space and mode != "nation": _center = s.c
	_after_view()

func _station_click(i: int) -> void:
	if i == _st_sel: _station_go()
	else: _station_pick(i)

func _station_go() -> void:
	if _st_sel < 0 or _st_sel >= _stations.size(): return
	var s: Dictionary = _stations[_st_sel]
	_st_sel = -1
	visible = false
	print("MAP station_warp ", s.id)
	var m := get_parent()
	if m != null and m.has_method("warp_to_station"): m.warp_to_station(String(s.id))
	elif _st_warp:
		var tr: Object = Travel
		var r = tr.call("warp_to_station", String(s.id))
		if r is Dictionary and not bool(r.get("ok", true)):   # 못 가는 역(처음 가는 길 등): 지도를 다시 열고 까닭을 적는다
			visible = true
			_after_view()
			_hint.text = "%s(으)로는 아직 역마로 갈 수 없다 — %s" % [String(s.name), String(r.get("why", ""))]
	elif m != null and m.has_method("open_fast_travel"): m.open_fast_travel()   # 역참 이동 API 전: 역마 창

# 사건 하나를 고르면 그 표지로 지도를 옮긴다(다른 공간이면 전국 지도의 그 권역으로)
func _focus_lead(l: Dictionary) -> void:
	_pinned = { tip = "「%s」 %s" % [String(l.title), String(l.name)], lead = l, p = Vector2.ZERO, r = 0.0 }
	if l.region == "" and l.space == _space and l.pos != null:
		var p: Vector2 = l.pos
		if mode == "nation" or _k < _city_k(): mode = "city"; _k = maxf(_city_k() * 1.5, minf(_k, 1.5))
		_center = p
		_after_view(); return
	var ll = _lead_ll(l)
	if mode != "nation": _show_nation()
	if ll != null: _ncenter = ll; _nk = maxf(_nk, _n_fit() * 2.0)
	_after_view()

# ---- 알게 된 곳(가 봄·들음) ----
func _story():
	var m := get_parent()
	return m.story if m != null and "story" in m else null

func _collect_story_places() -> void:
	_story_places = []
	var st = _story()
	if st == null or st.data.is_empty(): return
	for sp in st.data.get("map_places", []):
		var c: Vector2 = st.anchor(sp.get("at", [0, 0]))
		var e := { key = "place:" + String(sp.id), name = String(sp.get("name", "")), c = c, r = float(sp.get("radius", 18.0)), spec = sp, bld = "" }
		if bool(sp.get("building", false)):
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
	# 이름난 곳(랜드마크)·고개: 가까이 가 보면 이름이 적힌다
	for l in world.region.get("landmarks", []):
		if l.has("x") and p.distance_to(Vector2(float(l.x), float(l.z))) < 45.0:
			var k := "lm:" + String(l.get("id", l.get("name", "")))
			if not Discovery.is_known(_space, k): Discovery.visit(_space, k)
	for ps in world.region.get("passes", []):
		if ps.has("x") and p.distance_to(Vector2(float(ps.x), float(ps.z))) < 70.0:
			var k := "pass:" + String(ps.get("id", ps.get("name", "")))
			if not Discovery.is_known(_space, k): Discovery.visit(_space, k)
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
			if bool(sp.get("start_known", false)): Discovery.know(_space, e.key)
			elif sp.has("known") and st != null and st.runner != null and st.runner.cond(sp.known): _learn(e.key, true, e.name)
		if e.bld != "" and Discovery.is_known(_space, e.key) and not Discovery.is_known(_space, e.bld):
			if Discovery.how(_space, e.key) == "visited": Discovery.visit(_space, e.bld)
			else: Discovery.tell(_space, e.bld)

# ====================================================================================
# 그리기
# ====================================================================================
func _draw_map() -> void:
	var cs := _canvas.size
	_taken = []; _hits = []
	_canvas.draw_rect(Rect2(Vector2.ZERO, cs), PAPER_DARK)
	_taken.append(Rect2(Vector2(6, 6), Vector2(72, 72)))   # 방위
	_taken.append(Rect2(Vector2(6, cs.y - 40), Vector2(170, 36)))   # 10리 자
	if mode == "nation":
		_draw_nation()
	else:
		_draw_region()
	_draw_tip()
	_draw_frame()

func _draw_region() -> void:
	var cs := _canvas.size
	var tl := _to_px(Vector2(float(_meta.x0), float(_meta.z0)))
	var sz := Vector2(float(_meta.w), float(_meta.h)) * float(_meta.scale) * _k
	if _tex: _canvas.draw_texture_rect(_tex, Rect2(tl, sz), false)
	else: _draw_vector_base(tl, sz)
	var view := Rect2(_to_world(Vector2.ZERO), cs / _k)
	# 고을 그림(L3): 도시 축척에서 보이는 것만(늦게 읽는다). 가장자리는 옅게 이어 붙인다
	if mode == "city":
		# 권역 그림을 제 크기보다 크게 늘리면 흐려진다 — 한지빛으로 덮어 옅게(고을 그림이 그 위에 선명하게)
		var mag := _k * float(_meta.scale)
		if _tex != null and mag > 1.4: _canvas.draw_rect(Rect2(Vector2.ZERO, cs), Color(PAPER, clampf((mag - 1.4) / 2.5, 0.0, 0.8)))
		var a := 1.0
		for c in _cities:
			if not (c.rect as Rect2).intersects(view): continue
			if c.tex == null: c.tex = _load_tex(String(c.file))
			if c.tex != null: _canvas.draw_texture_rect(c.tex, Rect2(_to_px((c.rect as Rect2).position), (c.rect as Rect2).size * _k), false, Color(1, 1, 1, a))
	if _tex == null: _draw_water(view)
	# 겹침 솎기 후보
	var cands: Array = []
	var ppos := Vector2(_player.x, _player.z)
	_taken.append(Rect2(_to_px(ppos) - Vector2(16, 16), Vector2(32, 32)))
	var here = _town_at(ppos)
	var city := mode == "city"
	# 사건 표지(붉은 인) — 이 공간에 있는 것
	for l in _leads:
		if l.region != "" or l.space != _space or l.pos == null: continue
		cands.append({ p = _to_px(l.pos), kind = "case", text = String(l.name), prio = P_CASE, size = 15, col = SEAL, force = true,
			tip = "「%s」 %s" % [String(l.title), String(l.name)], lead = l })
	for t in _talks:
		cands.append({ p = _to_px(t.p), kind = "talk", text = "", prio = P_CASE, size = 13, col = SEAL, force = true, tip = "%s — 할 말이 있다" % String(t.name) })
	# 고을·마을
	for t in _towns:
		var r: Rect2 = t[2]
		if not r.grow(200).intersects(view): continue
		var known := Discovery.is_known(_space, "town:" + String(t[0]))
		var ty := String(t[3])
		var kind: String = { "읍성": "eup", "장시": "market", "역": "station", "원": "inn", "주막": "inn", "사찰": "temple", "성황당": "shrine" }.get(ty, "village")
		var is_here: bool = here != null and here[0] == t[0]
		var pr := P_HERE if is_here else (P_HUB if ty == "읍성" else (P_TOWN if kind in ["market", "station", "inn", "temple"] else P_VILLAGE))
		var at: Vector2 = t[1]
		var fsz := 22 if ty == "읍성" else (18 if pr <= P_TOWN else 15)
		if city:   # 도시 축척: 고을 그림 위 이름만(기호 없이), 고을 위쪽 가장자리
			at = Vector2(r.get_center().x, r.position.y)
			cands.append({ p = _to_px(at) + Vector2(0, -6), kind = "", text = String(t[0]) if known else "", prio = pr, size = fsz + 4, col = INK, title = true, plate = true })
		else:
			cands.append({ p = _to_px(at), kind = kind, text = String(t[0]) if known else "", prio = pr, size = fsz, col = INK, title = true, plate = ty == "읍성" })
	# 이름난 곳·나루·고개·봉수·절(권역 축척) / 이름 있는 건물(도시 축척)
	for l in world.region.get("landmarks", []):
		if not l.has("x"): continue
		var c := Vector2(float(l.x), float(l.z))
		if not view.grow(40).has_point(c): continue
		var kit := String(l.get("kit", ""))
		var kind := "landmark"
		if kit.contains("bongsu"): kind = "bongsu"
		elif kit.contains("temple") or kit.contains("sa") and (kit.contains("silsangsa") or kit.contains("bulguksa") or kit.contains("bunhwangsa") or kit.contains("seokguram")): kind = "temple"
		elif kit.contains("gate") or kit.contains("_wall") or kit.ends_with("eupseong"): continue
		var known := Discovery.is_known(_space, "lm:" + String(l.get("id", l.get("name", ""))))
		if city: kind = ""
		if not known and kind in ["landmark", ""]: continue
		cands.append({ p = _to_px(c), kind = kind, text = Travel.short_name(String(l.get("name", ""))) if known else "", prio = P_LANDMARK, size = 13, col = INK_SOFT })
	if city:
		for it in _items:
			if not view.has_point(it.c) or not Discovery.is_known(_space, Discovery.bld_key(it.name, it.c)): continue
			cands.append({ p = _to_px(it.c) + Vector2(0, -(it.half as Vector2).y * _k), kind = "dot", text = String(it.name), prio = P_LANDMARK, size = 13, col = INK })
	for cr in world.region.get("crossings", []):
		if String(cr.get("type", "")) != "나루" or not cr.has("x"): continue
		var c := Vector2(float(cr.x), float(cr.z))
		if not view.has_point(c): continue
		var nm := String(cr.get("name", ""))
		cands.append({ p = _to_px(c), kind = "ferry", text = Travel.short_name(nm) if not nm.begins_with("무명") and Discovery.is_known(_space, "town:" + Travel.short_name(nm)) else "", prio = P_VILLAGE, size = 13, col = WATER_INK })
	for ps in world.region.get("passes", []):
		if not ps.has("x"): continue
		var c := Vector2(float(ps.x), float(ps.z))
		if not view.has_point(c): continue
		var nm := String(ps.get("name", ""))
		var known := not nm.begins_with("무명") and Discovery.is_known(_space, "pass:" + String(ps.get("id", nm)))
		cands.append({ p = _to_px(c), kind = "pass", text = Travel.short_name(nm) if known else "", prio = P_MINOR, size = 13, col = INK_SOFT })
	# 사건 장소(map_places, 알게 된 것): 붉은 먹점
	for e in _story_places:
		if e.bld != "" or not Discovery.is_known(_space, e.key) or not view.grow(40).has_point(e.c): continue
		var told := Discovery.how(_space, e.key) == "told"
		cands.append({ p = _to_px(e.c), kind = "place_told" if told else "place", text = String(e.name) + (" (들음)" if told else ""), prio = P_TOWN, size = 14, col = Color(0.42, 0.12, 0.07) })
	# 역참
	for i in _stations.size():
		var s: Dictionary = _stations[i]
		if s.space != _space or s.c == null or not view.grow(40).has_point(s.c): continue
		cands.append({ p = _to_px(s.c), kind = "station", text = String(s.name), prio = P_STATION, size = 14, col = INK, station = i, tip = "역참 %s — 눌러 고르고, 한 번 더 누르면 간다" % String(s.name) })
	# 오름·용천수·호수·큰 물 이름
	if not city:
		for o in _oreums:
			if view.has_point(o[1]): cands.append({ p = _to_px(o[1]), kind = "", text = String(o[0]), prio = P_MINOR, size = 12, col = INK_SOFT })
		for rn in _rivers_named:
			if view.has_point(rn[1]): cands.append({ p = _to_px(rn[1]), kind = "", text = String(rn[0]), prio = P_MINOR, size = 13, col = WATER_INK })
		for l in _lakes:
			var c := Vector2.ZERO
			for q in l[1]: c += q
			c /= float(maxi(1, (l[1] as PackedVector2Array).size()))
			cands.append({ p = _to_px(c), kind = "", text = String(l[0]), prio = P_MINOR, size = 14, col = WATER_INK })
	else:
		for sp in _springs:
			if view.has_point(sp[1]): cands.append({ p = _to_px(sp[1]), kind = "spring", text = String(sp[0]), prio = P_MINOR, size = 12, col = WATER_INK })
	_place_all(cands)
	_draw_player()
	_draw_scale_bar(float(_meta.get("li_m", 1260.0)) * _k)

func _draw_player() -> void:
	var p := _to_px(Vector2(_player.x, _player.z))
	var d: Vector2 = { up = Vector2(0, -1), down = Vector2(0, 1), left = Vector2(-1, 0), right = Vector2(1, 0) }.get(_facing, Vector2(0, 1))
	var side := Vector2(-d.y, d.x)
	var tri := PackedVector2Array([p + d * 13.0, p - d * 7.0 + side * 8.0, p - d * 7.0 - side * 8.0])
	_canvas.draw_circle(p, 15.0, Color(0.75, 0.15, 0.1, 0.22))
	_canvas.draw_colored_polygon(tri, SEAL)
	_canvas.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(1, 0.97, 0.9), 2.0)

# 10리 자(권역 압축 K를 곱한 게임 거리) — 왼쪽 아래
func _draw_scale_bar(px_len: float) -> void:
	var per_li := px_len / 10.0
	for li in [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000]:
		if per_li * li >= 40.0:
			_draw_li_bar(per_li * li, "%d리" % li); return

func _draw_li_bar(L: float, lab: String) -> void:
	if L < 20.0 or L > 170.0: return
	var y := _canvas.size.y - 22.0
	var x0 := 18.0
	_canvas.draw_rect(Rect2(Vector2(x0 - 6, y - 16), Vector2(L + 60, 30)), Color(PAPER, 0.85))
	_canvas.draw_line(Vector2(x0, y), Vector2(x0 + L, y), ROAD_RED, 3.0)
	for t in [0.0, 0.5, 1.0]: _canvas.draw_line(Vector2(x0 + L * t, y - 5), Vector2(x0 + L * t, y + 5), Color(0.45, 0.12, 0.08), 1.5)
	_canvas.draw_string(_font, Vector2(x0 + L + 8, y + 5), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)

# 테두리(겹선) + 방위(왼쪽 위)
func _draw_frame() -> void:
	var cs := _canvas.size
	_canvas.draw_rect(Rect2(Vector2(2, 2), cs - Vector2(4, 4)), INK, false, 4.0)
	_canvas.draw_rect(Rect2(Vector2(9, 9), cs - Vector2(18, 18)), Color(INK, 0.7), false, 1.2)
	var c := Vector2(42, 42); var r := 26.0
	_canvas.draw_circle(c, r, Color(PAPER, 0.92))
	_canvas.draw_arc(c, r, 0, TAU, 40, INK, 1.6, true)
	_canvas.draw_arc(c, r - 4, 0, TAU, 40, Color(INK, 0.5), 1.0, true)
	_canvas.draw_circle(c, 4.5, SEAL)
	for e in [["북", Vector2(0, -1), SEAL], ["남", Vector2(0, 1), INK], ["동", Vector2(1, 0), INK], ["서", Vector2(-1, 0), INK]]:
		var w := _font.get_string_size(String(e[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		_canvas.draw_string(_font, c + (e[1] as Vector2) * (r - 11) + Vector2(-w / 2, 5), String(e[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, e[2])

# 표지 설명(마우스 올림·누름)
func _draw_tip() -> void:
	var h = _hover if _hover != null else _pinned
	if h == null or not h.has("tip"): return
	var s := String(h.tip)
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 22
	var at: Vector2 = h.p if h.p != Vector2.ZERO else Vector2(_canvas.size.x / 2, 60)
	var box := Rect2(at + Vector2(-w / 2, -50), Vector2(w, 30))
	box.position.x = clampf(box.position.x, 12, _canvas.size.x - w - 12)
	box.position.y = clampf(box.position.y, 12, _canvas.size.y - 42)
	_canvas.draw_rect(box, Color(PAPER, 0.97))
	_canvas.draw_rect(box, SEAL, false, 2.0)
	_canvas.draw_string(_font, box.position + Vector2(11, 21), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.35, 0.08, 0.05))

# ---- 겹침 솎기: 우선순위대로 기호 + 이름(오른쪽·위·아래·왼쪽 중 빈 자리). force는 기호를 늘 그리고 이름은 빈 자리에만 ----
func _place_all(cands: Array) -> void:
	cands.sort_custom(func(a, b): return int(a.prio) < int(b.prio))
	var cs := Rect2(Vector2.ZERO, _canvas.size)
	for c in cands:
		var p: Vector2 = c.p
		if not cs.grow(-4).has_point(p): continue
		var kind := String(c.kind)
		var ir := 0.0 if kind == "" else (11.0 if kind in ["case", "eup"] else 8.0)
		var irect := Rect2(p - Vector2(ir, ir), Vector2(ir, ir) * 2)
		var force := bool(c.get("force", false))
		if kind != "" and not force and _collides(irect): continue
		var text := String(c.text)
		var lrect := Rect2()
		var has_label := false
		if text != "":
			var f: Font = _font_t if bool(c.get("title", false)) else _font
			var sz := int(c.size)
			var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
			var lw := ts.x + 8.0; var lh := sz * 1.25
			var spots: Array
			if kind == "": spots = [p + Vector2(-lw / 2, -lh / 2), p + Vector2(-lw / 2, -lh - 2), p + Vector2(-lw / 2, 4)]
			else: spots = [p + Vector2(ir + 3, -lh / 2), p + Vector2(-lw / 2, -ir - lh - 1), p + Vector2(-lw / 2, ir + 1), p + Vector2(-ir - 3 - lw, -lh / 2)]
			for sp in spots:
				var rr := Rect2(sp, Vector2(lw, lh))
				if cs.encloses(rr) and not _collides(rr): lrect = rr; has_label = true; break
			if not has_label and kind == "": continue
			if has_label:
				_taken.append(lrect)
				_draw_label(text, lrect, f, sz, c.col, bool(c.get("plate", false)))
		if kind != "":
			_taken.append(irect)
			_icon(_canvas, kind, p, 1.0)
		if c.has("tip") or c.has("lead"):
			var hit := { p = p, r = 14.0, tip = String(c.get("tip", text)) }
			if c.has("lead"): hit.lead = c.lead
			if c.has("station"): hit.station = c.station
			_hits.append(hit)

func _collides(r: Rect2) -> bool:
	for t in _taken:
		if (t as Rect2).intersects(r): return true
	return false

# 이름표: 먹 글씨 + 한지빛 테두리(작은 글) · 고을(읍치)은 한지 판에 먹 테
func _draw_label(s: String, r: Rect2, f: Font, sz: int, col: Color, plate: bool) -> void:
	var base := r.position + Vector2(4, sz * 0.98)
	if plate:
		_canvas.draw_rect(r.grow(1), Color(PAPER, 0.93))
		_canvas.draw_rect(r.grow(1), Color(INK, 0.85), false, 1.2)
	else:
		_canvas.draw_string_outline(f, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 5, Color(PAPER, 0.92))
	_canvas.draw_string(f, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

# ---- 기호(화면 크기 고정) ----
func _icon(ci: CanvasItem, kind: String, p: Vector2, s: float) -> void:
	match kind:
		"eup":   # 읍치: 여장 두른 네모 성 + 붉은 점
			var h := 8.0 * s
			ci.draw_rect(Rect2(p - Vector2(h, h), Vector2(h, h) * 2), PAPER)
			ci.draw_rect(Rect2(p - Vector2(h, h), Vector2(h, h) * 2), INK, false, 2.0 * s)
			for i in 4:
				for j in [-1.0, 0.0, 1.0]:
					var dvec := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][i] as Vector2
					var q: Vector2 = p + dvec * (h + 1.5 * s) + Vector2(-dvec.y, dvec.x) * j * h * 0.6
					ci.draw_rect(Rect2(q - Vector2(1.6, 1.6) * s, Vector2(3.2, 3.2) * s), INK)
			ci.draw_circle(p, 3.2 * s, SEAL)
		"hub":   # 전국 지도 권역 거점: 두 겹 둥근 성
			ci.draw_circle(p, 9.0 * s, PAPER)
			ci.draw_arc(p, 9.0 * s, 0, TAU, 28, INK, 2.2 * s, true)
			ci.draw_arc(p, 5.5 * s, 0, TAU, 20, INK, 1.2 * s, true)
			ci.draw_circle(p, 2.6 * s, SEAL)
		"hub_here":
			ci.draw_circle(p, 10.0 * s, PAPER)
			ci.draw_arc(p, 10.0 * s, 0, TAU, 28, SEAL, 2.6 * s, true)
			ci.draw_circle(p, 4.5 * s, SEAL)
		"market":
			ci.draw_circle(p, 6.0 * s, PAPER)
			ci.draw_arc(p, 6.0 * s, 0, TAU, 20, INK, 1.8 * s, true)
			ci.draw_circle(p, 2.2 * s, INK)
		"village":
			ci.draw_circle(p, 4.2 * s, PAPER)
			ci.draw_arc(p, 4.2 * s, 0, TAU, 16, INK, 1.4 * s, true)
		"stronghold":
			ci.draw_rect(Rect2(p - Vector2(3.5, 3.5) * s, Vector2(7, 7) * s), PAPER)
			ci.draw_rect(Rect2(p - Vector2(3.5, 3.5) * s, Vector2(7, 7) * s), INK, false, 1.3 * s)
		"inn":   # 원·주막: 작은 초가 지붕
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 2) * s, p + Vector2(0, -5) * s, p + Vector2(6, 2) * s]), Color(0.78, 0.64, 0.40))
			ci.draw_polyline(PackedVector2Array([p + Vector2(-6, 2) * s, p + Vector2(0, -5) * s, p + Vector2(6, 2) * s]), INK, 1.3 * s)
			ci.draw_rect(Rect2(p + Vector2(-4, 2) * s, Vector2(8, 4) * s), INK, false, 1.2 * s)
		"station":   # 역참·마방: 붉은 테 둥근 패에 '역'
			ci.draw_circle(p, 8.0 * s, PAPER)
			ci.draw_arc(p, 8.0 * s, 0, TAU, 24, SEAL, 2.0 * s, true)
			var w := _font.get_string_size("역", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * s)).x
			ci.draw_string(_font, p + Vector2(-w / 2, 4 * s), "역", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * s), SEAL)
		"ferry":   # 나루: 배
			var hull := PackedVector2Array([p + Vector2(-7, 0) * s, p + Vector2(7, 0) * s, p + Vector2(4, 4) * s, p + Vector2(-4, 4) * s])
			ci.draw_colored_polygon(hull, Color(0.55, 0.40, 0.26))
			ci.draw_polyline(PackedVector2Array([hull[0], hull[1], hull[2], hull[3], hull[0]]), INK, 1.2 * s)
			ci.draw_line(p + Vector2(0, 0) * s, p + Vector2(0, -8) * s, INK, 1.3 * s)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(1, -8) * s, p + Vector2(6, -2) * s, p + Vector2(1, -2) * s]), PAPER)
		"pass":   # 고개: 겹 산 모양 꺾쇠
			ci.draw_polyline(PackedVector2Array([p + Vector2(-7, 4) * s, p + Vector2(0, -5) * s, p + Vector2(7, 4) * s]), INK, 2.0 * s)
			ci.draw_line(p + Vector2(-3, 4) * s, p + Vector2(3, 4) * s, ROAD_RED, 2.0 * s)
		"temple":   # 절: 기와 지붕 + 卍 대신 작은 탑 점
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 1) * s, p + Vector2(-4, -4) * s, p + Vector2(4, -4) * s, p + Vector2(8, 1) * s]), Color(0.37, 0.41, 0.45))
			ci.draw_polyline(PackedVector2Array([p + Vector2(-8, 1) * s, p + Vector2(-4, -4) * s, p + Vector2(4, -4) * s, p + Vector2(8, 1) * s]), INK, 1.3 * s)
			ci.draw_rect(Rect2(p + Vector2(-4.5, 1) * s, Vector2(9, 4) * s), Color(0.62, 0.22, 0.15))
		"shrine":   # 성황당: 신목
			ci.draw_line(p + Vector2(0, 5) * s, p + Vector2(0, -1) * s, Color(0.4, 0.27, 0.17), 2.0 * s)
			ci.draw_circle(p + Vector2(0, -3) * s, 5.0 * s, Color(0.33, 0.47, 0.33))
			ci.draw_arc(p + Vector2(0, -3) * s, 5.0 * s, 0, TAU, 16, INK, 1.1 * s, true)
		"bongsu":   # 봉수: 연기 오르는 돌 무지
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 4) * s, p + Vector2(5, 4) * s, p + Vector2(3, -1) * s, p + Vector2(-3, -1) * s]), Color(0.6, 0.57, 0.5))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-2, -1) * s, p + Vector2(0, -8) * s, p + Vector2(2, -1) * s]), SEAL)
		"landmark":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5) * s, p + Vector2(5, 0) * s, p + Vector2(0, 5) * s, p + Vector2(-5, 0) * s]), PAPER)
			ci.draw_polyline(PackedVector2Array([p + Vector2(0, -5) * s, p + Vector2(5, 0) * s, p + Vector2(0, 5) * s, p + Vector2(-5, 0) * s, p + Vector2(0, -5) * s]), INK, 1.3 * s)
		"spring":
			ci.draw_circle(p, 4.0 * s, Color(0.45, 0.62, 0.70))
			ci.draw_arc(p, 4.0 * s, 0, TAU, 14, INK, 1.1 * s, true)
		"place":
			ci.draw_circle(p, 4.5 * s, Color(0.55, 0.16, 0.1, 0.9))
		"place_told":
			ci.draw_arc(p, 6.0 * s, 0, TAU, 20, Color(0.55, 0.16, 0.1, 0.9), 1.6 * s, true)
		"dot":
			ci.draw_circle(p, 2.0 * s, INK)
		"case":   # 사건: 붓으로 찍은 붉은 인(조금 기운 네모, 흰 테, '사')
			var r := 10.0 * s
			var rot := -0.12
			var pts := PackedVector2Array()
			for i in 12:
				var a := TAU * (i + 0.5) / 12.0
				var rr := r * (1.0 / maxf(absf(cos(a)), absf(sin(a)))) * (0.9 + 0.08 * sin(i * 2.3))
				pts.append(p + Vector2(cos(a), sin(a)).rotated(rot) * minf(rr, r * 1.3))
			ci.draw_colored_polygon(pts, Color(SEAL, 0.95))
			var inner := PackedVector2Array()
			for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]: inner.append(p + (q * r * 0.7).rotated(rot))
			ci.draw_polyline(inner, Color(1, 0.94, 0.86, 0.9), 1.2 * s)
			var w := _font.get_string_size("사", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * s)).x
			ci.draw_string(_font, p + Vector2(-w / 2, 4.5 * s), "사", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * s), Color(1, 0.95, 0.88))
		"talk":   # 할 말 있는 사람: 작은 붉은 둥근 인에 「…」
			ci.draw_circle(p + Vector2(0, -12) * s, 7.0 * s, Color(SEAL, 0.92))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-2, -6) * s, p + Vector2(2, -6) * s, p + Vector2(0, -1) * s]), Color(SEAL, 0.92))
			for i in 3: ci.draw_circle(p + Vector2(-3.5 + i * 3.5, -12) * s, 1.1 * s, Color(1, 0.95, 0.88))

# ---- 지도 그림이 없는 공간(노정): 물·길·고을·포털을 벡터로 ----
func _draw_vector_base(tl: Vector2, sz: Vector2) -> void:
	_canvas.draw_rect(Rect2(tl, sz), PAPER)
	for r in world.region.get("rivers", []):
		var line := PackedVector2Array()
		for p in r.points: line.append(_to_px(Vector2(float(p[0]), float(p[1]))))
		var wv := maxf(2.0, float(r.get("width_m", 6.0)) * _k)
		_canvas.draw_polyline(line, WATER_INK, wv + 2.0, true)
		_canvas.draw_polyline(line, Color(0.70, 0.80, 0.81), wv, true)
	for r in world.region.get("roads", []):
		var line := PackedVector2Array()
		for p in r.points: line.append(_to_px(Vector2(float(p[0]), float(p[1]))))
		_canvas.draw_polyline(line, ROAD_RED, maxf(2.0, float(r.get("width_m", 3.0)) * _k * 0.6), true)
	var main := get_parent()
	for pt in main.portals if "portals" in main else []:
		var c := _to_px(Vector2(pt.x, pt.z))
		_canvas.draw_circle(c, 7.0, SEAL)
		_taken.append(Rect2(c - Vector2(8, 8), Vector2(16, 16)))
		var s := "→ " + String(pt.label)
		var f := _font
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 8
		var r := Rect2(c + Vector2(-w / 2, 10), Vector2(w, 19))
		if not _collides(r): _taken.append(r); _draw_label(s, r, f, 15, Color(0.45, 0.1, 0.06), false)

func _draw_water(view: Rect2) -> void:
	for l in _lakes:
		var px := PackedVector2Array()
		for q in l[1]: px.append(_to_px(q))
		if Geometry2D.triangulate_polygon(px).is_empty(): continue
		_canvas.draw_colored_polygon(px, Color(0.70, 0.80, 0.81))
		px.append(px[0])
		_canvas.draw_polyline(px, WATER_INK, 1.5, true)

# ====================================================================================
# 전국 지도: 바탕(nation_map.webp — 산줄기·물길·바다) + 노정(붉은 길) + 권역 거점·거점 88곳 + 사건 인 + 역참 + 지금 자리
# ====================================================================================
func _n_fit() -> float:
	var b: Rect2 = Travel.OUTLINE_BOX
	return minf(_canvas.size.x / (b.size.x * cos(deg_to_rad(38.0))), _canvas.size.y / b.size.y) * 0.95

func _n_px(g: Vector2) -> Vector2:
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
		if FileAccess.file_exists("res://region_data/nation_map.json"):
			_nmeta = JSON.parse_string(FileAccess.get_file_as_string("res://region_data/nation_map.json"))
			_ntex = _load_tex("res://region_data/" + String(_nmeta.file))
		_stations = _collect_stations()
	_nk = _n_fit()
	_ncenter = Travel.OUTLINE_BOX.get_center()
	_collect_fast()
	_after_view()

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
		if dest == "":
			for r2 in _nation.routes:
				if r2.id == ft.target: dest = String(r2.to if r2.to != "" else r2.from)
		_fast_opts.append({ route = String(r.id), name = String(r.get("short", r.name)), ft = ft, dest = dest })

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
	var regs: Array = _nation.get("regions", Travel.regions())
	for r in regs:
		if String(r.get("id", "")) == id: return r.lonlat
	return null

# 공간(권역 또는 노정) → 경위도(노정은 선 가운데)
func _space_ll(id: String) -> Variant:
	var ll = _region_ll(id)
	if ll != null: return ll
	for r in _nation.get("routes", Travel.routes()):
		if String(r.id) == id:
			var line := _route_line(r)
			if line.size() >= 2:
				var px := PackedVector2Array()
				for g in line: px.append(g)
				return _polyline_at(px, 0.5)
	return null

func _lead_ll(l: Dictionary) -> Variant:
	if String(l.region) != "": return _region_ll(String(l.region))
	var sp := String(l.space)
	if l.pos != null:
		var rj = null
		if sp == _space and not world.is_route: rj = world.region
		if rj != null:
			var ll = Travel.local_to_lonlat(rj, (l.pos as Vector2).x, (l.pos as Vector2).y)
			if ll != null: return ll
	return _space_ll(sp)

func _route_line(r: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var gl = r.json.get("geo_line")
	if gl is Array and gl.size() >= 2:
		for p in gl: out.append(Vector2(float(p[0]), float(p[1])))
		return out
	var a = _region_ll(r.from); var b = _region_ll(r.to)
	if a != null and b != null and a != b: out.append(a); out.append(b)
	return out

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
		_canvas.draw_circle(c, 11.0, INK)
		_canvas.draw_circle(c, 9.0, FAST_COL if not sel else Color(0.95, 0.45, 0.1))
		if not _st_on():
			var w := _font.get_string_size(str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			_canvas.draw_string(_font, c + Vector2(-w / 2, 5), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
		_taken.append(Rect2(c - Vector2(11, 11), Vector2(22, 22)))

func _draw_nation() -> void:
	var cs := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, cs), SEA_COL)
	if _ntex != null:
		var tl := _n_px(Vector2(float(_nmeta.lon0), float(_nmeta.lat1)))
		var br := _n_px(Vector2(float(_nmeta.lon1), float(_nmeta.lat0)))
		_canvas.draw_texture_rect(_ntex, Rect2(tl, br - tl), false)
	else:
		var land := PackedVector2Array()
		for p in Travel.PENINSULA: land.append(_n_px(Vector2(p[0], p[1])))
		if not Geometry2D.triangulate_polygon(land).is_empty(): _canvas.draw_colored_polygon(land, PAPER)
		land.append(land[0])
		_canvas.draw_polyline(land, INK, 2.0, true)
		var jj := PackedVector2Array()
		for p in Travel.jeju(): jj.append(_n_px(p))
		_canvas.draw_colored_polygon(jj, PAPER)
	var here_id := String(world.region.get("region_id", ""))
	# 노정: 붉은 길(지나온 길 진하게, 모르는 길 옅은 점선)
	var cands: Array = []
	for r in _nation.routes:
		var line := _route_line(r)
		if line.size() < 2: continue
		var px := PackedVector2Array()
		for g in line: px.append(_n_px(g))
		var on: bool = r.id == here_id
		var done := Progress.route_done(String(r.id))
		var known: bool = on or done or (Discovery.region_known(String(r.get("from", ""))) and Discovery.region_known(String(r.get("to", ""))))
		var sea := String(r.id).begins_with("SEA_") or String(r.id).begins_with("RIVER_")
		if known and not sea: _canvas.draw_polyline(px, ROAD_RED if (on or done) else Color(ROAD_RED, 0.7), 3.5 if on else 2.4, true)
		else:
			for i in px.size() - 1: _canvas.draw_dashed_line(px[i], px[i + 1], WATER_INK if sea else Color(ROAD_RED, 0.5), 1.6, 6.0)
		if known:
			var nm := String(r.get("short", r.name)) if not on else String(r.name)
			cands.append({ p = _polyline_at(px, 0.5), kind = "", text = nm, prio = P_MINOR + (0 if on else 1), size = 12, col = Color(0.42, 0.18, 0.12) })
	_draw_fast()
	# 사건 표지(권역별로 하나 — 사건 이름)
	var seen_pos := {}
	for l in _leads:
		var ll = _lead_ll(l)
		if ll == null: continue
		var key := "%s@%s" % [l.case, str((ll as Vector2).snapped(Vector2(0.05, 0.05)))]
		if seen_pos.has(key): continue
		seen_pos[key] = true
		var p := _n_px(ll) + Vector2(18, -18)
		cands.append({ p = p, kind = "case", text = String(l.title), prio = P_CASE, size = 14, col = SEAL, force = true,
			tip = "「%s」 %s" % [String(l.title), String(l.name)], lead = l })
	# 권역 거점
	for r in _nation.regions:
		if r.lonlat == null: continue
		var on: bool = String(r.get("id", "")) == here_id
		var known: bool = on or Discovery.region_known(String(r.get("id", "")))
		cands.append({ p = _n_px(r.lonlat), kind = "hub_here" if on else "hub", text = String(r.get("short", r.get("name", ""))) if known else "",
			prio = P_HERE if on else P_HUB, size = 20, col = INK, title = true, plate = true, force = true })
	# 거점 88곳(지도에만 있는 곳 포함): 작은 네모, 가 본 이름만
	for s in _nation.get("strongholds", []):
		if String(s.get("status", "")) == "region": continue
		var nm := String(s.name)
		cands.append({ p = _n_px(Vector2(float(s.lon), float(s.lat))), kind = "stronghold", text = nm if Discovery.is_known(Discovery.NATION, "sh:" + nm) else "",
			prio = P_VILLAGE, size = 12, col = INK_SOFT })
	# 역참
	for i in _stations.size():
		var s: Dictionary = _stations[i]
		if s.ll == null: continue
		cands.append({ p = _n_px(s.ll), kind = "station", text = String(s.name), prio = P_STATION, size = 12, col = INK, station = i,
			tip = "역참 %s — 눌러 고르고, 한 번 더 누르면 간다" % String(s.name) })
	var here = _here_ll()
	_place_all(cands)
	if here != null:
		var p := _n_px(here)
		_canvas.draw_circle(p, 14.0, Color(0.75, 0.15, 0.1, 0.25))
		_canvas.draw_circle(p, 6.0, SEAL)
		_canvas.draw_arc(p, 9.0, 0, TAU, 24, Color(1, 0.97, 0.9), 2.0)
	if _fast_sel >= 0:
		var msg := _fast_ride(_fast_opts[_fast_sel]) + " 타고 %s 가겠소?  Enter/Y · N/Esc" % _fast_label(_fast_opts[_fast_sel])
		var w := _font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 40.0
		var box := Rect2(Vector2((_canvas.size.x - w) / 2.0, 24), Vector2(w, 42))
		_canvas.draw_rect(box, Color(PAPER, 0.96))
		_canvas.draw_rect(box, INK, false, 2.0)
		_canvas.draw_string(_font, box.position + Vector2(20, 28), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	# 10리 자(전국: 1° 위도 ≈ 110km ≈ 262리)
	_draw_scale_bar(_nk * (4.2 / 110.574))

# ---- 시험: --mapshots=폴더 [--mapzooms] — 불러오기가 끝나면 도시·권역·전국 지도를 찍고(창 그림) 여는 시간을 적는다 ----
func _mapshots(dir: String) -> void:
	var m := get_parent()
	while m._loading: await get_tree().process_frame
	for i in 30: await get_tree().process_frame
	var out: String = m._abs(dir)
	DirAccess.make_dir_recursive_absolute(out)
	var tag := _space + String(m.args.get("maptag", ""))
	var shots := []
	var t0 := Time.get_ticks_usec()
	toggle()
	print("MAPSHOT open_ms=%.1f mode=%s" % [(Time.get_ticks_usec() - t0) / 1000.0, mode])
	var home = _town_at(Vector2(_player.x, _player.z))
	if home == null: home = _nearest_town(Vector2(_player.x, _player.z))
	shots.append(["city", 1.0])
	if m.args.has("mapzooms"): shots += [["city_min", 0.0], ["city_mid", 0.5], ["city_max", 99.0]]
	shots.append(["all", -1.0]); shots.append(["nation", -2.0])
	if m.args.has("mapzooms"): shots.append(["nation_max", 98.0])
	for s in shots:
		if s[1] == -1.0: show_mode("all")
		elif s[1] == -2.0:
			var t1 := Time.get_ticks_usec(); show_mode("nation")
			print("MAPSHOT nation_ms=%.1f" % ((Time.get_ticks_usec() - t1) / 1000.0))
		elif s[1] == 1.0 and mode != "city" and home != null: _show_city(home)
		elif s[1] == 0.0: _show_city(home); _zoom(0.0001, _canvas.size / 2.0)
		elif s[1] == 0.5: _show_city(home); _k = sqrt(_city_k() * MAX_K); _zoom(1.0, _canvas.size / 2.0)
		elif s[1] == 99.0: _show_city(home); _zoom(10000.0, _canvas.size / 2.0)
		elif s[1] == 98.0: _zoom(10000.0, _canvas.size / 2.0)
		for i in 4: await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null:
			var f: String = out.path_join("%s_%s.png" % [tag, s[0]])
			img.save_png(f); print("MAPSHOT ", f, " k=", _k, " labels=", _taken.size(), " cases=", _leads.size())
	if m.args.has("quit"): m._quit()
