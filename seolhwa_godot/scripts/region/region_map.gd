# 지도 — 조선 고지도풍(대동여지도·동여도 / 군현지도·도성도). M: 지금 고을의 도시 지도(L3), Tab: 도시 → 권역(L2) → 전국(L0) 차례로,
# 휠·+/-: 확대·축소, 드래그·방향키: 옮기기, Esc·M: 닫기. L: 오른쪽 판 쪽 넘김(닫힘 → 범례 → 사건·역참 → 닫힘). H: 역참(역마) — 역참 API(Travel.stations)가 있으면 오른쪽 판의 역참 목록,
# 없으면 역마 창(scripts/region/fast_travel.gd). 숫자 키: 역참 고르기(없으면 전국 지도 지나온 노정 건너뛰기).
#
# 바탕 그림은 오프라인(tools/region/render_joseon_map.py): region_data/<id>/map/l2.webp(권역), map/city_*.webp(고을),
#   region_data/nation_map.webp(전국). 그 위에 런타임이 그리는 것: 이름·기호(화면 크기 고정 + 겹침 솎기), 사건 표지(붉은 인),
#   할 말 있는 이야기 인물, 역참, 플레이어, 테두리·방위·10리 자, 오른쪽 판(제목·범례·현재 사건·역참).
# 글자 크기는 확대와 상관없이 늘 같다(UiFonts.MAP_* — 화면 픽셀, 기호 속 글자 '역'·'사'도 MAP_GLYPH 고정). 기호 그림도 화면 크기 고정(ICON_S).
#   고을 이름(MAP_HUB 26 · MAP_TOWN 24)은 그대로, 그 밖의 지도 글은 모두 고을 이름 크기(UiFonts.MAP_MIN 26) 이상 — 이름표·범례·판·아래 안내·10리 자·확인 상자·기호 속 글자까지.
#   바탕 그림(webp)에는 글자를 굽지 않는다 — 이름·범례·방위·10리 자는 모두 여기서 그린다.
#   겹치면 우선순위(지금 고을·권역 > 사건 > 거점 > 고을 > 역참 > 마을 > 이름난 곳 > 고개·물 > 건물)로 솎는다(이름표 둘레 _pad(우선순위) 띄움 —
#   낮은 이름일수록 더 넓게 비워야 들어간다: 글이 커진 만큼 작은 이름을 덜 쓴다).
#   시험: --maptexttest — 권역·고을·전국 지도를 최소·중간·최대 배율로 놓고 이름표 글 크기·높이가 같은지, 겹침이 없는지(MAPTEXTTEST PASS).
#
# 알고 있는 곳만 이름을 쓴다(scripts/region/discovery.gd, 보강서 §20): 고을·이름 있는 건물·사건 장소(map_places)·이름난 곳(lm:)·
#   고개(pass:)·전국 지도 권역과 거점. 산·물·길·성벽·집채(그림)는 늘 그린다. 단서·범인·해결 자리는 지도에 오르지 않는다.
#   세 단계(C65): UNKNOWN 없음 · KNOWN(앎 — 권역 상식·들음, 아직 안 가 봄) 옅은 먹 글 + 바랜 기호·점선 테 · VISITED(가 봄) 보통 먹.
#   권역에 들어서면(이 공간의 지도가 서고 첫 발견 셈 때) region_data/region_known.json의 대표 명소·공공시설을 KNOWN으로 적는다(_rk_keys).
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
const Waymarks := preload("res://scripts/region/waymarks.gd")
const RideNetRef := preload("res://scripts/region/ride_net.gd")
const RegionKnown := preload("res://scripts/region/region_known.gd")

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
const ICON_S := 1.6      # 지도 위 기호 크기(화면 고정 — 확대와 상관없음). 기호 속 글자(26)·범례에 맞춰 예전 1.25에서 키움
const LABEL_PAD := 3.0   # 이름표끼리 띄움(겹침 솎기) — 높은 이름. 낮은 이름은 _pad()가 더 띄운다
const HALO := 9          # 이름표 한지빛 테두리(먹 지도·집채 위에서 읽히게 — 예전 5)

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
const P_BUILDING := 8     # 낱낱 건물 이름(가까이 확대했을 때만 — 가장 먼저 솎인다)
# 확대 단계(권역·고을 지도): 글 크기는 그대로, 보이는 이름의 단계만 바뀐다(_tier())
#   1 늘: 고을·권역 이름(+ 사건 표지·할 말·깃발·지금 자리)
#   2 중간(TIER2_K 이상): 이름난 곳·관아·객사·광한루·나루·역참·고개·사건 장소·물 이름
#   3 가까이(TIER3_K 이상): 낱낱 건물(주막·성황당·물레방앗간·옥·정자·쉼터 …) — 배치 title·building_titles 이름, 가 봄/들음만
const TIER3_K := 1.6      # px/m — 10m 집채가 16px 넘게 보일 때(예전 1.1 — 글이 커진 만큼 늦게 연다)

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
var _rk_keys: Array = []       # 이 공간의 권역 상식 키(scripts/region/region_known.gd) — 들어서면 KNOWN
var rk_missing: Array = []     # 데이터에는 있는데 이 지도에 없는 상식 항목(시험이 본다)
var _twins: Array = []        # [[lm 키, bld 키]] 같은 곳의 두 이름
var _rk_rank := {}             # 상식 키 → 목록 차례(같은 우선순위끼리 솎을 때 앞 차례가 먼저 — 광한루가 오작교보다)
var _disc_t := 0.0
var on_discover: Callable = Callable()
# 이번 그림의 자리 차지(겹침 솎기) · 표지 맞춤
var _taken: Array = []
var placed: Array = []         # 이번 그림에 그린 이름표 [{text, size, rect}] · 기호 속 글자 크기(시험이 읽는다)
var glyph_sizes: Array = []
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
var _flags: Array = []         # 알게 된 길목 깃발 [{id, name, space, c(Vector2 — 이 공간일 때), ll}] (scripts/region/waymarks.gd)
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
	var tnames: Array = []
	for t in _towns: tnames.append(String(t[0]))
	var rk := RegionKnown.resolve(_space, tnames, _items, w.region)
	_rk_keys = rk.keys; rk_missing = rk.missing
	for i in _rk_keys.size(): _rk_rank[String(_rk_keys[i])] = i
	# 같은 곳의 두 이름(이름난 곳 lm: · 건물 bld: — 경복궁·광한루): 한쪽을 가 보면 다른 쪽도 가 봄(지도에 같은 이름 하나만 남으므로)
	for l in w.region.get("landmarks", []):
		if not l.has("x"): continue
		var lc := Vector2(float(l.x), float(l.z))
		var sn := Travel.short_name(String(l.get("name", "")))
		for it in _items:
			if String(it.name) == sn and (it.c as Vector2).distance_to(lc) < 300.0:
				_twins.append(["lm:" + String(l.get("id", l.get("name", ""))), Discovery.bld_key(it.name, it.c)])
	for m in (Travel as Script).get_script_method_list():
		if m.name == "stations": _st_api = true
		elif m.name == "warp_to_station": _st_warp = true
	MapLeads.cases.call_deferred()   # 사건 데이터를 미리 읽어 둔다(처음 지도 열기를 빠르게)
	var mn := get_parent()
	if mn != null and "args" in mn and mn.args.has("mapshots"): _mapshots.call_deferred(String(mn.args.mapshots))
	if mn != null and "args" in mn and mn.args.has("maptexttest"): _maptexttest.call_deferred()
	if mn != null and "args" in mn and mn.args.has("knowntest"): load("res://scripts/region/map_known_test.gd").run.call_deferred(self)   # --knowntest(C65 세 단계)
	if mn != null and "args" in mn and mn.args.has("knownshots"): load("res://scripts/region/map_known_test.gd").shots.call_deferred(self, String(mn.args.knownshots))

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
			if it.has("when"): continue   # 조건부 차림(F-11)은 지도에 그리지 않는다
			var kit := String(it.get("kit", ""))
			var params: Dictionary = it.get("params", {}) if it.get("params") is Dictionary else {}
			var c := Vector2(float(it.x), float(it.z)); var ry := float(it.get("ry", 0.0))
			var kind := map_kind(kit, params)
			if kind == "": continue
			var nm := item_name(it)
			if nm == "": continue   # 이름 없는 집채는 그림에만(오프라인)
			var fp := Vector2.ZERO
			var f0 = it.get("footprint")
			if f0 is Array and f0.size() >= 2: fp = Vector2(float(f0[0]), float(f0[1]))
			if fp == Vector2.ZERO: fp = loader._catalog_fp(kit, params)
			if fp == Vector2.ZERO: fp = Vector2(8, 6)
			# 이름난 곳(landmark 키트 — 관아·객사·광한루 …)은 2단계, 낱낱 건물(주막·성황당·방앗간·옥 …)은 3단계
			_items.append({ kind = kind, c = c, ry = ry, half = fp / 2.0, name = nm, tier = 2 if kit.begins_with("landmark/") else 3 })

# 지도에 이름을 얹을 배치 항목의 종류("" = 지도 이름 없음) — 권역 상식 시험(tools/region/region_known_test.gd)도 같은 셈을 쓴다
static func map_kind(kit: String, params: Dictionary) -> String:
	if kit.ends_with("_eupseong") or kit == "village/wall_run": return ""
	if kit == "landmark/gwanghallu_pond": return "water"
	if kit in ROOF_TILE or (kit.begins_with("landmark/") and not kit.ends_with("_wall")): return "tile"
	if kit in ROOF_THATCH: return "thatch"
	if kit in FIELD: return "field"
	if kit.begins_with("culture/"): return _culture_kind(kit, params)
	return ""

static func item_name(it: Dictionary) -> String:
	return String(it.get("title", BuildingTitles.NAMES.get(String(it.get("kit", "")), "")))

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
	_hint.add_theme_font_size_override("font_size", UiFonts.MAP_KEYS)
	_hint.add_theme_color_override("font_color", Color(1, 0.97, 0.9, 0.95))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

# ---- 오른쪽 판: 쪽 넘김(L) — 0 닫힘(지도 넓게) · 1 범례 · 2 사건·역참. 글은 모두 MAP_PANEL(26) 이상 ----
#   글이 커져(26 이상) 범례·사건·역참이 한 판에 다 들어가지 않는다 — 줄이지 않고 쪽으로 나눈다. 넘치면 판 안에서 휠로 내린다.
#   지도 이름(남원 고을 · 남원 지도 · 조선 팔도)은 판이 아니라 지도 오른쪽 위 한지 판(_draw_title, NAME)에 늘 있다.
const PAGE_NAMES := ["", "범례", "사건 · 역참"]
static var page := 1          # 지도를 닫았다 열어도 쪽은 그대로(처음은 범례)
var _scroll: ScrollContainer
var _phead: Label
var _page_boxes: Array = []   # [null, 범례 쪽, 사건·역참 쪽]
var _pnote: Label

func _build_panel() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK; sb.set_border_width_all(3)
	sb.content_margin_left = 16; sb.content_margin_right = 14; sb.content_margin_top = 10; sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.35); sb.shadow_size = 6
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_pbox = VBoxContainer.new()
	_pbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pbox.add_theme_constant_override("separation", 6)
	_scroll.add_child(_pbox)
	_phead = _plabel("", UiFonts.MAP_PANEL, INK, _font_t)
	_pbox.add_child(_phead)
	_pbox.add_child(_rule())
	_page_boxes = [null]
	# 1 범례
	var lg := VBoxContainer.new()
	lg.add_theme_constant_override("separation", 8)
	_legend = Control.new()
	_legend.custom_minimum_size = Vector2(0, 0)
	_legend.draw.connect(_draw_legend)
	lg.add_child(_legend)
	lg.add_child(_rule())
	_pnote = _plabel("아는 곳만 이름이 적힌다 · 옅은 먹은 알지만 아직 안 가 본 곳", UiFonts.MAP_PANEL, INK_SOFT)
	lg.add_child(_pnote)
	_pbox.add_child(lg)
	_page_boxes.append(lg)
	# 2 사건·역참
	var cs := VBoxContainer.new()
	cs.add_theme_constant_override("separation", 6)
	cs.add_child(_plabel("현재 사건", UiFonts.MAP_PANEL, SEAL, _font_t))
	_cases_box = VBoxContainer.new()
	_cases_box.add_theme_constant_override("separation", 2)
	cs.add_child(_cases_box)
	cs.add_child(_rule())
	_st_head = _plabel("역참 (H · 숫자)", UiFonts.MAP_PANEL, INK, _font_t)
	cs.add_child(_st_head)
	_st_box = VBoxContainer.new()
	_st_box.add_theme_constant_override("separation", 2)
	cs.add_child(_st_box)
	_pbox.add_child(cs)
	_page_boxes.append(cs)

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
	r.custom_minimum_size = Vector2(0, 2)
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
	b.add_theme_font_size_override("font_size", UiFonts.MAP_PANEL)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", SEAL)
	b.add_theme_color_override("font_pressed_color", SEAL)
	b.pressed.connect(cb)
	return b

func set_page(p: int) -> void:
	page = posmod(p, PAGE_NAMES.size())
	if visible: _layout(); _after_view()

# 범례: 기호(ICON_S) + 짧은 이름(MAP_PANEL). 판 너비에 두 단이 들어가면 두 단, 아니면 한 단(판 안에서 내린다). 긴 뜻은 표지에 마우스를 올리면
const LEGEND := [["eup", "읍치"], ["market", "장터"], ["village", "마을"], ["station", "역참"], ["flag", "깃발"], ["ferry", "나루"],
	["pass", "고개"], ["temple", "절"], ["bongsu", "봉수"], ["case", "사건"], ["talk", "할 말"], ["road", "큰길"],
	["visited", "가 본 곳"], ["known", "아는 곳"]]
const LEGEND_S := 2.0          # 범례 기호 크기(지도 위 ICON_S보다 크게 — 26px 글 곁에서 모양이 읽히게)
const LEGEND_ICON_W := 56.0   # 기호 칸(가장 큰 기호 — '사' 인·'역' 패 지름에 맞춤)
func legend_cols() -> int:
	var tw := 0.0
	for e in LEGEND: tw = maxf(tw, _font.get_string_size(String(e[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.MAP_PANEL).x)
	return 2 if _legend.size.x >= 2.0 * (LEGEND_ICON_W + tw + 12.0) else 1

func legend_row() -> float: return maxf(UiFonts.MAP_PANEL * 1.6, 10.0 * LEGEND_S * 2.0 + 6.0)

func _draw_legend() -> void:
	var cols := legend_cols()
	var colw := _legend.size.x / float(cols)
	var rows := ceili(LEGEND.size() / float(cols))
	var rh := legend_row()
	for i in LEGEND.size():
		var e: Array = LEGEND[i]
		var x := float(i / rows) * colw
		var y := rh * 0.5 + float(i % rows) * rh
		var ic := Vector2(x + LEGEND_ICON_W / 2.0, y)
		if e[0] == "road":
			_legend.draw_line(Vector2(x + 6, y), Vector2(x + LEGEND_ICON_W - 6, y), ROAD_RED, 2.8 * LEGEND_S)
			for tx in [0.3, 0.7]: _legend.draw_line(Vector2(x + LEGEND_ICON_W * tx, y - 4 * LEGEND_S), Vector2(x + LEGEND_ICON_W * tx, y + 4 * LEGEND_S), Color(0.45, 0.12, 0.08), 1.4 * LEGEND_S)
		elif e[0] == "visited": _icon(_legend, "landmark", ic, LEGEND_S)
		elif e[0] == "known": _icon_faint(_legend, "landmark", ic, LEGEND_S)   # 아는 곳(아직 안 가 봄): 바랜 기호·점선 테·옅은 글
		else: _icon(_legend, String(e[0]), ic, LEGEND_S)
		_legend.draw_string(_font, Vector2(x + LEGEND_ICON_W + 6, y + UiFonts.MAP_PANEL * 0.36), String(e[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.MAP_PANEL, _faint_col(INK) if e[0] == "known" else INK)
	var hgt := rows * rh + 4.0
	if absf(_legend.custom_minimum_size.y - hgt) > 0.5: _legend.custom_minimum_size = Vector2(0, hgt)

func _map_title() -> String:
	var rn := Travel.short_name(String(world.region.get("region_name", _space)))
	match mode:
		"nation": return "조선 팔도"
		"all": return rn + " 지도"
	var town = _town_at(_center)
	var known: bool = town != null and Discovery.is_known(_space, "town:" + String(town[0]))
	return (String(town[0]) if known else rn) + " 고을"

func _refresh_panel() -> void:
	_panel.visible = page > 0
	for i in range(1, _page_boxes.size()): (_page_boxes[i] as Control).visible = i == page
	_phead.text = "%s  (L)" % PAGE_NAMES[page] if page > 0 else ""
	for c in _cases_box.get_children(): c.queue_free()
	var by_case := {}
	for l in _leads:
		if not by_case.has(l.case): by_case[l.case] = []
		by_case[l.case].append(l)
	if by_case.is_empty(): _cases_box.add_child(_plabel("아직 쫓는 사건이 없다.", UiFonts.MAP_PANEL, INK_SOFT))
	for cid in by_case:
		var ls: Array = by_case[cid]
		_cases_box.add_child(_plabel("「%s」" % String(ls[0].title), UiFonts.MAP_PANEL, SEAL, _font_t))
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
		if _stations.is_empty(): _st_box.add_child(_plabel("가 본 역참이 아직 없다.", UiFonts.MAP_PANEL, INK_SOFT))
		for i in _stations.size():
			var s: Dictionary = _stations[i]
			var lab := "%d. %s" % [i + 1, String(s.name)]
			if s.space != _space: lab += " (" + _space_short(String(s.space)) + ")"
			if not bool(s.get("ok", true)) and String(s.get("why", "")) != "": lab += " — " + String(s.why)
			elif not bool(s.get("ok", true)): lab += " — 아직 못 감"
			if i == _st_sel: lab = "▶ " + lab
			var b := _pbutton(lab, SEAL if i == _st_sel else (INK if bool(s.get("ok", true)) else INK_SOFT), _station_click.bind(i))
			_st_box.add_child(b)
			if i == _st_sel and page == 2: _scroll.ensure_control_visible.call_deferred(b)

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
	if world.is_route and _tex == null: _show_nation(); return   # 노정에는 구운 권역 그림이 없다 — 전국 지도(노정 선·지금 자리)로 연다
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
	_center = Vector2(_player.x, _player.z)   # 채움 배율이라 한쪽이 넘친다 — 지금 자리를 가운데로(그림 끝에서는 _clamp_center가 당긴다)
	_after_view()

# 권역·고을 지도: 그림(권역 바탕) 밖이 테 안에 보이지 않게 가운데를 당긴다. 그림이 테보다 작은 쪽은 가운데 맞춤
func _clamp_center() -> void:
	if _meta.is_empty() or _k <= 0.0: return
	var half := _canvas.size / 2.0 / _k
	var x0 := float(_meta.x0); var z0 := float(_meta.z0)
	var x1 := x0 + float(_meta.w) * float(_meta.scale); var z1 := z0 + float(_meta.h) * float(_meta.scale)
	_center.x = (x0 + x1) / 2.0 if x1 - x0 <= half.x * 2.0 else clampf(_center.x, x0 + half.x, x1 - half.x)
	_center.y = (z0 + z1) / 2.0 if z1 - z0 <= half.y * 2.0 else clampf(_center.y, z0 + half.y, z1 - half.y)

# 도시 지도(L3)로 넘어가는 확대: 권역 그림이 제 해상도를 넘길 때(그 전에는 권역 지도)
func _city_k() -> float:
	if _tex == null: return _k_min * 1.6
	return maxf(_k_min * 1.6, 1.15 / float(_meta.scale))

# 2단계 문턱: 권역 최소 배율과 고을 지도 문턱 사이 — 글이 커져 고을 지도 쪽으로 늦췄다(예전 기하 평균 × 0.95 ≈ 0.5)
const TIER2_W := 0.62
func tier2_k() -> float:
	return pow(_k_min, 1.0 - TIER2_W) * pow(_city_k(), TIER2_W)

# 3단계 문턱: 고을 지도 문턱의 2배와 TIER3_K 가운데 큰 쪽(예전 1.5배 · 1.1)
func tier3_k() -> float:
	return minf(MAX_K * 0.8, maxf(TIER3_K, _city_k() * 2.0))

func _tier() -> int:
	if mode == "nation": return 1
	if _k >= tier3_k(): return 3
	return 2 if _k >= tier2_k() else 1

func _after_view() -> void:
	_update_hint(); _refresh_panel(); _canvas.queue_redraw()

func _update_hint() -> void:
	# 아래 안내는 한 줄(MAP_KEYS 26) — 조작만. 읽는 법(아는 곳만 이름 · 붉은 인)은 범례 쪽에 있다. 넓이가 모자라면 짧은 줄로
	var vs := get_viewport().get_visible_rect().size
	var tries: Array
	if mode == "nation" and not _fast_opts.is_empty() and _fast_sel < 0:
		tries = ["금빛 길 눌러 건너뛰기 · L 범례 · M 닫기", "금빛 길 눌러 건너뛰기 · M 닫기"]
	else:
		tries = ["Tab 지도 · 휠 확대 · L 범례 · H 역참 · M 닫기", "Tab 지도 · L 범례 · H 역참 · M 닫기", "Tab 지도 · L 범례 · M 닫기"]
	var line := ""
	for t in tries:
		line = String(t)
		if _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.MAP_KEYS).x <= vs.x - 32.0: break
	_hint.text = UiFonts.fit(_font, line, UiFonts.MAP_KEYS, vs.x - 32.0)
	_hint.reset_size()
	_hint.position = Vector2((vs.x - _hint.size.x) / 2.0, vs.y - _hint.size.y - 2)

func hint_h() -> float: return ceilf(UiFonts.MAP_KEYS * 1.4) + 4.0

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	# 오른쪽 판은 쪽(page)이 열렸을 때만 — 닫히면 지도가 판 자리까지 넓어진다. 판 너비는 26px 범례 두 단이 들어가게
	var pw := clampf(vs.x * 0.36, 330.0, 480.0) if page > 0 else 0.0
	_canvas.position = Vector2(vs.x * 0.015, vs.y * 0.015)
	_canvas.size = Vector2(vs.x * 0.97 - (pw + 10.0 if pw > 0.0 else 0.0), vs.y - _canvas.position.y - hint_h() - 4.0)
	_panel.position = Vector2(_canvas.position.x + _canvas.size.x + 10.0, _canvas.position.y)
	_panel.size = Vector2(pw, _canvas.size.y)
	_panel.custom_minimum_size = _panel.size
	_panel.visible = page > 0
	var world_w := float(_meta.w) * float(_meta.scale); var world_h := float(_meta.h) * float(_meta.scale)
	# 가장 작은 배율은 '채움'(cover): 권역 그림이 테 안을 다 덮는다 — 맞춤(contain)이면 가로로 긴 권역 위아래에 빈 한지 띠가 컸다.
	# 덮는 쪽으로 넘친 만큼은 끌어서 본다(_clamp_center가 그림 밖 빈 곳이 테 안에 들어오지 않게 막는다).
	_k_min = maxf(_canvas.size.x / world_w, _canvas.size.y / world_h)
	if mode != "nation" and _k < _k_min: _k = _k_min

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
	if kc == KEY_L: set_page(page + 1); get_viewport().set_input_as_handled(); return
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
	_flags = _collect_flags()
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

# 길목 깃발: 가 본 것만(progress.json travel_nodes — 역마 거점과 같은 '가 봄')
func _collect_flags() -> Array:
	var out := []
	var FT: Script = load("res://scripts/region/fast_travel.gd")
	for sp in RideNetRef.all_spaces():
		for f in Waymarks.flags_in(sp):
			if not Waymarks.known(sp, String(f.id)): continue
			out.append({ id = f.id, name = f.name, space = sp, c = f.p if sp == _space else null, ll = FT._ll(sp, f.p) })
	return out

# 깃발을 새로 알았을 때(horse_ride._flag_found)
func refresh_flags() -> void:
	_flags = _collect_flags()
	if _canvas != null: _canvas.queue_redraw()

func _station_pick(i: int) -> void:
	if i < 0 or i >= _stations.size(): return
	_st_sel = i
	var s: Dictionary = _stations[i]
	if s.c != null and s.space == _space and mode != "nation": _center = s.c
	if page != 2: page = 2; _layout()   # 역참 목록이 있는 쪽을 연다
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
			_hint.text = UiFonts.fit(_font, "%s(으)로는 아직 역마로 갈 수 없다 — %s" % [String(s.name), String(r.get("why", ""))], UiFonts.MAP_KEYS, get_viewport().get_visible_rect().size.x - 32.0)
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

# 권역 상식(KNOWN): 이 공간에 서 있으면 곧 적는다 — 이미 아는 키는 그대로(Discovery.grant). 옛 저장도 이 공간에 다시 들어서면 채워진다
func grant_region_known() -> int:
	if _space == "" or _rk_keys.is_empty(): return 0
	return Discovery.grant(_space, _rk_keys)

func _update_discovery() -> void:
	if _space == "": return
	grant_region_known()
	var p := Vector2(_player.x, _player.z)
	if not Discovery.is_known(Discovery.NATION, "region:" + _space) and not world.is_route: Discovery.visit(Discovery.NATION, "region:" + _space)
	# 가 봄(VISITED)은 KNOWN이어도 적는다 — 알던 곳에 실제로 들어서면 옅은 먹이 보통 먹이 된다
	for t in _towns:
		if (t[2] as Rect2).grow(PlaceTitle.MARGIN).has_point(p):
			if not Discovery.is_visited(_space, "town:" + String(t[0])):
				Discovery.visit(_space, "town:" + String(t[0]))
				Discovery.visit(Discovery.NATION, "sh:" + String(t[0]))
	# 이름난 곳(랜드마크)·고개·나루: 가까이 가 보면 이름이 적힌다
	for l in world.region.get("landmarks", []):
		if l.has("x") and p.distance_to(Vector2(float(l.x), float(l.z))) < 45.0:
			var k := "lm:" + String(l.get("id", l.get("name", "")))
			if not Discovery.is_visited(_space, k): Discovery.visit(_space, k)
	for ps in world.region.get("passes", []):
		if ps.has("x") and p.distance_to(Vector2(float(ps.x), float(ps.z))) < 70.0:
			var k := "pass:" + String(ps.get("id", ps.get("name", "")))
			if not Discovery.is_visited(_space, k): Discovery.visit(_space, k)
	for cr in world.region.get("crossings", []):
		var cn := String(cr.get("name", ""))
		if String(cr.get("type", "")) != "나루" or not cr.has("x") or cn.begins_with("무명"): continue
		if p.distance_to(Vector2(float(cr.x), float(cr.z))) < 40.0:
			var k := "town:" + Travel.short_name(cn)
			if not Discovery.is_visited(_space, k): Discovery.visit(_space, k)
	for it in _items:
		if it.name == "": continue
		var q: Vector2 = (p - (it.c as Vector2)).rotated(-float(it.ry))
		var hf: Vector2 = it.half
		if absf(q.x) <= hf.x + 14.0 and absf(q.y) <= hf.y + 14.0:
			var k := Discovery.bld_key(it.name, it.c)
			if Discovery.how(_space, k) != "visited": _learn(k, false, it.name)
	for tw in _twins:
		var a := Discovery.is_visited(_space, String(tw[0])); var b := Discovery.is_visited(_space, String(tw[1]))
		if a != b: Discovery.visit(_space, String(tw[1] if a else tw[0]))
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
	_taken = []; _hits = []; placed = []; glyph_sizes = []
	_canvas.draw_rect(Rect2(Vector2.ZERO, cs), PAPER_DARK)
	_taken.append(_compass_rect())   # 방위
	_taken.append(_title_rect())     # 지도 이름 판(오른쪽 위)
	_taken.append(Rect2(Vector2(6, cs.y - scale_bar_h() - 8), Vector2(300, scale_bar_h() + 4)))   # 10리 자
	if _st_sel >= 0 or (mode == "nation" and _fast_sel >= 0): _taken.append(_confirm_rect())   # 역마 확인 상자
	if mode == "nation":
		_draw_nation()
	else:
		_clamp_center()
		_draw_region()
	_draw_frame()
	_draw_title()
	_draw_confirm()
	_draw_tip()

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
	var tier := _tier()
	# 사건 표지(붉은 인) — 이 공간에 있는 것
	#   붉은 인이 커져(MAP_GLYPH '사') 가까운 표지끼리 포개진다 — 화면에서 인 하나 너비 안의 표지는 인 하나로 묶고(이름은 첫 것 + '외 n'), 설명에 모두 적는다
	var seal_d := _icon_r("case") * 2.0 + 6.0
	var groups: Array = []
	for l in _leads:
		if l.region != "" or l.space != _space or l.pos == null: continue
		var q := _to_px(l.pos)
		var g = null
		for e in groups:
			if (e.p as Vector2).distance_to(q) < seal_d: g = e; break
		if g == null: groups.append({ p = q, ls = [l] })
		else: g.ls.append(l)
	for e in groups:
		var l0: Dictionary = e.ls[0]
		var tips := PackedStringArray()
		for l in e.ls: tips.append(String(l.name))
		var nm := String(l0.name) + ("" if e.ls.size() == 1 else " 외 %d" % (e.ls.size() - 1))
		cands.append({ p = e.p, kind = "case", text = nm, prio = P_CASE, size = UiFonts.MAP_LABEL, col = SEAL, force = true,
			tip = "「%s」 %s" % [String(l0.title), " · ".join(tips)], lead = l0 })
	var tg: Array = []
	for t in _talks:
		var q := _to_px(t.p)
		var g = null
		for e in tg:
			if (e.p as Vector2).distance_to(q) < _icon_r("talk") * 2.0 + 4.0: g = e; break
		if g == null: tg.append({ p = q, names = [String(t.name)] })
		else: g.names.append(String(t.name))
	for e in tg:
		var q: Vector2 = e.p
		for c in cands:   # 붉은 인과 같은 자리면 인 오른쪽 위로 비켜 그린다
			if String(c.kind) == "case" and (c.p as Vector2).distance_to(q) < seal_d: q = (c.p as Vector2) + Vector2(_icon_r("case") + 6.0, -_icon_r("case") * 0.4); break
		cands.append({ p = q, kind = "talk", text = "", prio = P_CASE, size = UiFonts.MAP_LABEL, col = SEAL, force = true, tip = "%s — 할 말이 있다" % "·".join(PackedStringArray(e.names)) })
	# 고을·마을
	for t in _towns:
		var r: Rect2 = t[2]
		if not r.grow(200).intersects(view): continue
		var known := Discovery.is_known(_space, "town:" + String(t[0]))
		var faint := known and not Discovery.is_visited(_space, "town:" + String(t[0]))
		var ty := String(t[3])
		var kind: String = { "읍성": "eup", "장시": "market", "역": "station", "원": "inn", "주막": "inn", "사찰": "temple", "성황당": "shrine" }.get(ty, "village")
		var is_here: bool = here != null and here[0] == t[0]
		var pr := P_HERE if is_here else (P_HUB if ty == "읍성" else (P_TOWN if kind in ["market", "station", "inn", "temple"] else P_VILLAGE))
		var at: Vector2 = t[1]
		var fsz: int = UiFonts.MAP_HUB if ty == "읍성" else (UiFonts.MAP_TOWN if pr <= P_TOWN else UiFonts.MAP_LABEL)
		var is_city := fsz != UiFonts.MAP_LABEL   # 고을 이름(26·24 — 크기 그대로). 마을은 고을 이름이 아닌 글(MAP_LABEL)
		if city:   # 도시 축척: 고을 그림 위 이름만(기호 없이), 고을 위쪽 가장자리
			at = Vector2(r.get_center().x, r.position.y)
			cands.append({ p = _to_px(at) + Vector2(0, -8), kind = "", text = String(t[0]) if known else "", prio = pr, size = UiFonts.MAP_HUB if ty == "읍성" else UiFonts.MAP_TOWN, col = INK, title = true, plate = true, city = true, faint = faint })
		else:
			cands.append({ p = _to_px(at), kind = kind, text = String(t[0]) if known else "", prio = pr, size = fsz, col = INK, title = true, plate = ty == "읍성", city = is_city, faint = faint })
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
		var lk := "lm:" + String(l.get("id", l.get("name", "")))
		var known := Discovery.is_known(_space, lk)
		if city: kind = ""
		if not known and kind in ["landmark", ""]: continue
		cands.append({ p = _to_px(c), kind = kind, text = Travel.short_name(String(l.get("name", ""))) if known else "", prio = P_LANDMARK, size = UiFonts.MAP_LABEL, col = INK_SOFT, tier = 2,
			faint = known and not Discovery.is_visited(_space, lk), rk = _rk_rank.get(lk, 9999) })
	# 이름 있는 건물(배치 title · building_titles): 가 봄/들음만, 확대 단계가 닿을 때만(모르는 건물은 이름도 점도 없다 — 예전 규칙)
	for it in _items:
		if int(it.tier) > tier or not view.has_point(it.c): continue
		var bst := Discovery.state(_space, Discovery.bld_key(it.name, it.c))
		if bst == Discovery.UNKNOWN: continue
		cands.append({ p = _to_px(it.c) + Vector2(0, -(it.half as Vector2).y * _k), kind = "dot", text = String(it.name),
			prio = P_LANDMARK if int(it.tier) == 2 else P_BUILDING, size = UiFonts.MAP_LABEL, col = INK, tier = int(it.tier), faint = bst == Discovery.KNOWN,
			rk = _rk_rank.get(Discovery.bld_key(it.name, it.c), 9999) })
	for cr in world.region.get("crossings", []):
		if String(cr.get("type", "")) != "나루" or not cr.has("x"): continue
		var c := Vector2(float(cr.x), float(cr.z))
		if not view.has_point(c): continue
		var nm := String(cr.get("name", ""))
		var fst := Discovery.UNKNOWN if nm.begins_with("무명") else Discovery.state(_space, "town:" + Travel.short_name(nm))
		cands.append({ p = _to_px(c), kind = "ferry", text = Travel.short_name(nm) if fst != Discovery.UNKNOWN else "", prio = P_VILLAGE, size = UiFonts.MAP_MINOR, col = WATER_INK, tier = 2, faint = fst == Discovery.KNOWN })
	for ps in world.region.get("passes", []):
		if not ps.has("x"): continue
		var c := Vector2(float(ps.x), float(ps.z))
		if not view.has_point(c): continue
		var nm := String(ps.get("name", ""))
		var pst := Discovery.UNKNOWN if nm.begins_with("무명") else Discovery.state(_space, "pass:" + String(ps.get("id", nm)))
		cands.append({ p = _to_px(c), kind = "pass", text = Travel.short_name(nm) if pst != Discovery.UNKNOWN else "", prio = P_MINOR, size = UiFonts.MAP_MINOR, col = INK_SOFT, tier = 2, faint = pst == Discovery.KNOWN })
	# 사건 장소(map_places, 알게 된 것): 붉은 먹점
	for e in _story_places:
		if e.bld != "" or not Discovery.is_known(_space, e.key) or not view.grow(40).has_point(e.c): continue
		var told := Discovery.how(_space, e.key) == "told"
		var pk := not Discovery.is_visited(_space, e.key)   # KNOWN(들음·처음부터 앎) — 빈 동그라미 + 옅은 글
		cands.append({ p = _to_px(e.c), kind = "place_told" if pk else "place", text = String(e.name) + (" (들음)" if told else ""), prio = P_TOWN, size = UiFonts.MAP_LABEL, col = Color(0.42, 0.12, 0.07), tier = 2, faint = pk })
	# 길목 깃발(가 본 것 — 이름은 고을 이름과 겹치므로 그림만, 손을 대면 이름)
	for f in _flags:
		if f.c == null or not view.grow(40).has_point(f.c): continue
		# 고을 표지 바로 곁(오른쪽 위)에 늘 그린다 — 넓은 축척에서는 고을 기호와 같은 자리라 솎으면 사라진다
		cands.append({ p = _to_px(f.c) + Vector2(9, -9) * ICON_S, kind = "flag", text = "", prio = P_STATION, size = UiFonts.MAP_LABEL, col = INK, force = true, tip = "깃발 %s — 곁에서 E로 역마" % String(f.name) })
	# 역참
	for i in _stations.size():
		var s: Dictionary = _stations[i]
		if s.space != _space or s.c == null or not view.grow(40).has_point(s.c): continue
		cands.append({ p = _to_px(s.c), kind = "station", text = String(s.name), prio = P_STATION, size = UiFonts.MAP_LABEL, col = INK, station = i, tip = "역참 %s — 눌러 고르고, 한 번 더 누르면 간다" % String(s.name), tier = 2 })
	# 오름·용천수·호수·큰 물 이름
	if not city:
		for o in _oreums:
			if view.has_point(o[1]): cands.append({ p = _to_px(o[1]), kind = "", text = String(o[0]), prio = P_MINOR, size = UiFonts.MAP_MINOR, col = INK_SOFT, tier = 2 })
		for rn in _rivers_named:
			if view.has_point(rn[1]): cands.append({ p = _to_px(rn[1]), kind = "", text = String(rn[0]), prio = P_MINOR, size = UiFonts.MAP_MINOR, col = WATER_INK, tier = 2 })
		for l in _lakes:
			var c := Vector2.ZERO
			for q in l[1]: c += q
			c /= float(maxi(1, (l[1] as PackedVector2Array).size()))
			cands.append({ p = _to_px(c), kind = "", text = String(l[0]), prio = P_MINOR, size = UiFonts.MAP_MINOR, col = WATER_INK, tier = 2 })
	else:
		for sp in _springs:
			if view.has_point(sp[1]): cands.append({ p = _to_px(sp[1]), kind = "spring", text = String(sp[0]), prio = P_MINOR, size = UiFonts.MAP_MINOR, col = WATER_INK, tier = 2 })
	# 이 확대 단계보다 높은 단계의 이름은 글을 지운다(기호는 그대로 — 기호 없는 이름은 통째로 빠진다)
	for c in cands:
		if int(c.get("tier", 1)) > tier: c.text = ""
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

func scale_bar_h() -> float: return ceilf(UiFonts.MAP_KEYS * 1.3) + 8.0

func _draw_li_bar(L: float, lab: String) -> void:
	if L < 20.0 or L > 170.0: return
	var fs := UiFonts.MAP_KEYS
	var bh := scale_bar_h()
	var y := _canvas.size.y - 14.0 - bh / 2.0
	var x0 := 24.0
	var tw := _font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_canvas.draw_rect(Rect2(Vector2(x0 - 10, y - bh / 2.0), Vector2(L + tw + 34, bh)), Color(PAPER, 0.9))
	_canvas.draw_line(Vector2(x0, y), Vector2(x0 + L, y), ROAD_RED, 5.0)
	for t in [0.0, 0.5, 1.0]: _canvas.draw_line(Vector2(x0 + L * t, y - 9), Vector2(x0 + L * t, y + 9), Color(0.45, 0.12, 0.08), 2.5)
	_canvas.draw_string(_font, Vector2(x0 + L + 12, y + fs * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
	placed.append({ text = lab, size = fs, rect = Rect2(x0 + L + 12, y - fs * 0.6, tw, fs * 1.25), scale_bar = true })

# 테두리(겹선) + 방위(왼쪽 위): 기호 글자가 26px이라 네 방위를 다 쓰면 지도 한 귀를 덮는다 — 붉은 바늘 + '북' 한 자(고지도 방위표의 북 표시)
const COMPASS_R := 24.0
func _compass_rect() -> Rect2:
	var r := maxf(COMPASS_R, UiFonts.MAP_GLYPH * 0.72)
	return Rect2(Vector2(10, 10), Vector2(r * 2 + 16, r * 2 + 28))

func _draw_frame() -> void:
	var cs := _canvas.size
	_canvas.draw_rect(Rect2(Vector2(2, 2), cs - Vector2(4, 4)), INK, false, 4.0)
	_canvas.draw_rect(Rect2(Vector2(9, 9), cs - Vector2(18, 18)), Color(INK, 0.7), false, 1.2)
	var r := maxf(COMPASS_R, UiFonts.MAP_GLYPH * 0.72)
	var c := Vector2(18 + r, 30 + r)
	_canvas.draw_circle(c, r, Color(PAPER, 0.94))
	_canvas.draw_arc(c, r, 0, TAU, 40, INK, 2.4, true)
	_canvas.draw_arc(c, r - 5, 0, TAU, 40, Color(INK, 0.5), 1.2, true)
	_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r - 16), c + Vector2(7, -r + 2), c + Vector2(-7, -r + 2)]), SEAL)
	_glyph(_canvas, "북", c, SEAL)

# 지도 이름 판(오른쪽 위, NAME 30 · Classic — 예전 판 제목 크기) — 판(쪽)이 닫혀도 지금 보는 지도 이름이 늘 보인다
func _title_rect() -> Rect2:
	var t := _map_title()
	var w := _font_t.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.NAME).x + 28.0
	return Rect2(Vector2(_canvas.size.x - w - 14.0, 14.0), Vector2(w, UiFonts.NAME * 1.35))

func _draw_title() -> void:
	var t := _map_title()
	var r := _title_rect()
	_canvas.draw_rect(r, Color(PAPER, 0.95))
	_canvas.draw_rect(r, INK, false, 2.5)
	_canvas.draw_rect(r.grow(-5), Color(INK, 0.5), false, 1.0)
	_canvas.draw_string(_font_t, r.position + Vector2(14, UiFonts.NAME * 1.02), t, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.NAME, INK)
	placed.append({ text = t, size = UiFonts.NAME, rect = r, frame = true })

# 역마 확인 상자(위 가운데): 노정 건너뛰기(전국) · 역참 고르기 — 물음 + 키(모두 MAP_KEYS 26). 물음이 넓으면 띄어쓰기에서 두 줄로
func _confirm_msg() -> PackedStringArray:
	if _st_sel >= 0 and _st_sel < _stations.size():
		return PackedStringArray(["역마 타고 %s(으)로 가겠소?" % String(_stations[_st_sel].name), "Enter·Y 간다 · N·Esc 그만"])
	if mode == "nation" and _fast_sel >= 0 and _fast_sel < _fast_opts.size():
		return PackedStringArray([_fast_ride(_fast_opts[_fast_sel]) + " 타고 %s 가겠소?" % _fast_label(_fast_opts[_fast_sel]), "Enter·Y 간다 · N·Esc 그만"])
	return PackedStringArray()

func _wrap(t: String, fs: int, maxw: float) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for w in t.split(" "):
		var nx := w if cur == "" else cur + " " + w
		if cur != "" and _font.get_string_size(nx, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw: out.append(cur); cur = w
		else: cur = nx
	if cur != "": out.append(cur)
	for i in out.size(): out[i] = UiFonts.fit(_font, out[i], fs, maxw)
	return out

func _confirm_lines() -> PackedStringArray:
	var m := _confirm_msg()
	if m.is_empty(): return m
	var lines := _wrap(m[0], UiFonts.MAP_KEYS, _canvas.size.x - 120.0)
	lines.append(m[1])
	return lines

func _confirm_rect() -> Rect2:
	var ls := _confirm_lines()
	if ls.is_empty(): return Rect2()
	var w := 0.0
	for l in ls: w = maxf(w, _font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.MAP_KEYS).x)
	w = minf(_canvas.size.x - 80.0, w + 44.0)
	var r := Rect2(Vector2((_canvas.size.x - w) / 2.0, 16.0), Vector2(w, ls.size() * UiFonts.MAP_KEYS * 1.3 + 24.0))
	var cr := _compass_rect(); var tr := _title_rect()
	if r.intersects(cr) or r.intersects(tr): r.position.y = maxf(cr.end.y, tr.end.y) + 8.0   # 방위·지도 이름 판 아래로
	return r

func _draw_confirm() -> void:
	var ls := _confirm_lines()
	if ls.is_empty(): return
	var box := _confirm_rect()
	_canvas.draw_rect(box, Color(PAPER, 0.97))
	_canvas.draw_rect(box, INK, false, 2.5)
	var fs := UiFonts.MAP_KEYS
	for i in ls.size():
		var last := i == ls.size() - 1
		_canvas.draw_string(_font, box.position + Vector2(22, 12 + fs * (0.98 + 1.3 * i)), ls[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK_SOFT if last else INK)
		placed.append({ text = ls[i], size = fs, rect = Rect2(box.position + Vector2(22, 12 + fs * 1.3 * i), Vector2(box.size.x - 44, fs * 1.3)), frame = true })

# 표지 설명(마우스 올림·누름)
func _draw_tip() -> void:
	var h = _hover if _hover != null else _pinned
	if h == null or not h.has("tip"): return
	var fs := UiFonts.MAP_KEYS
	var s := UiFonts.fit(_font, String(h.tip), fs, _canvas.size.x - 48)
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28
	var at: Vector2 = h.p if h.p != Vector2.ZERO else Vector2(_canvas.size.x / 2, 90)
	var box := Rect2(at + Vector2(-w / 2, -fs * 1.3 - 60), Vector2(w, fs * 1.3 + 16))
	box.position.x = clampf(box.position.x, 12, _canvas.size.x - w - 12)
	box.position.y = clampf(box.position.y, 12, _canvas.size.y - box.size.y - 12)
	_canvas.draw_rect(box, Color(PAPER, 0.97))
	_canvas.draw_rect(box, SEAL, false, 2.5)
	_canvas.draw_string(_font, box.position + Vector2(14, 8 + fs * 0.98), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.35, 0.08, 0.05))

# ---- 겹침 솎기: 우선순위대로 기호 + 이름(오른쪽·위·아래·왼쪽 중 빈 자리). force는 기호를 늘 그리고 이름은 빈 자리에만 ----
#   글이 커진 만큼 낮은 이름일수록 둘레를 더 비워야 들어간다(_pad) — 작은 이름을 덜 써서 지도가 글 벽이 되지 않게.
static func _pad(prio: int) -> float:
	if prio <= P_TOWN: return LABEL_PAD
	if prio <= P_VILLAGE: return LABEL_PAD + 5.0
	return LABEL_PAD + 10.0

func _place_all(cands: Array) -> void:
	# 우선순위 → (같으면) 권역 상식 목록 차례(rk) → 들어온 차례. sort_custom은 안정 정렬이 아니라 차례를 함께 센다
	for i in cands.size(): cands[i].ord = i
	cands.sort_custom(func(a, b):
		if int(a.prio) != int(b.prio): return int(a.prio) < int(b.prio)
		if int(a.get("rk", 9999)) != int(b.get("rk", 9999)): return int(a.get("rk", 9999)) < int(b.get("rk", 9999))
		return int(a.ord) < int(b.ord))
	var cs := Rect2(Vector2.ZERO, _canvas.size)
	# 늘 그리는 기호(사건 인·할 말·깃발)의 자리를 먼저 잡는다 — 뒤에 놓일 이름표가 그 위에 얹히지 않게
	#   깃발은 '무른' 자리: 이름표는 피하지만 고을 기호(P_TOWN까지)는 깃발에 막히지 않는다(깃발은 고을 곁에 서므로 막으면 고을이 통째로 빠졌다)
	var soft: Array = []
	for c in cands:
		if bool(c.get("force", false)) and String(c.kind) != "" and cs.grow(-4).has_point(c.p):
			var fr := _icon_r(String(c.kind))
			var fr_rect := Rect2((c.p as Vector2) - Vector2(fr, fr), Vector2(fr, fr) * 2)
			if String(c.kind) == "flag": soft.append(fr_rect)
			else: _taken.append(fr_rect)
	for c in cands:
		var p: Vector2 = c.p
		if not cs.grow(-4).has_point(p): continue
		var kind := String(c.kind)
		var ir := _icon_r(kind)
		var irect := Rect2(p - Vector2(ir, ir), Vector2(ir, ir) * 2)
		var force := bool(c.get("force", false))
		var faint := bool(c.get("faint", false))   # KNOWN(앎 · 안 가 봄): 옅은 먹 글 + 바랜 기호
		# 기호 자리가 막히면 빠진다 — 다만 지금 고을·거점(P_HUB까지)은 기호를 빼고 이름만이라도 둘레 빈 자리에(사건 인·지금 자리 표시에 가려 이름이 없어지지 않게)
		var icon_ok := kind == "" or force or not (_collides(irect) if int(c.prio) <= P_TOWN else _collides(irect) or _hits_any(irect, soft))
		if not icon_ok and int(c.prio) > P_HUB: continue
		var text := String(c.text)
		var lrect := Rect2()
		var has_label := false
		if text != "":
			var f: Font = _font_t if bool(c.get("title", false)) else _font
			var sz := int(c.size)
			var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
			var lw := ts.x + 12.0; var lh := sz * 1.25
			var pad := _pad(int(c.prio))
			var spots: Array
			if kind == "": spots = [p + Vector2(-lw / 2, -lh / 2), p + Vector2(-lw / 2, -lh - 4), p + Vector2(-lw / 2, 6)]
			else:   # 기호 둘레(pad만큼 더 띄움 — 제 기호 자리와 부딪지 않게): 오른쪽·위·아래·왼쪽, 높은 이름(사건·거점·고을)은 네 귀도
				var g := ir + pad + 2.0
				spots = [p + Vector2(g, -lh / 2), p + Vector2(-lw / 2, -g - lh), p + Vector2(-lw / 2, g), p + Vector2(-g - lw, -lh / 2)]
				if int(c.prio) <= P_TOWN:
					var d := g * 0.7
					spots += [p + Vector2(d, -d - lh), p + Vector2(-d - lw, -d - lh), p + Vector2(d, d), p + Vector2(-d - lw, d)]
				if int(c.prio) <= P_HUB:   # 그래도 없으면 한 걸음 더 멀리(가린 것 너머)
					var g2 := g + lh
					spots += [p + Vector2(g2, -lh / 2), p + Vector2(-lw / 2, -g2 - lh), p + Vector2(-lw / 2, g2), p + Vector2(-g2 - lw, -lh / 2)]
			for sp in spots:
				var rr := Rect2(sp, Vector2(lw, lh))
				if cs.grow(-8).encloses(rr) and not _collides(rr.grow(pad)) and not _hits_any(rr.grow(pad), soft): lrect = rr; has_label = true; break
			for q in placed:   # 같은 이름이 곁에 이미 있으면(권역 이름난 곳 = 건물 이름) 한 번만
				if has_label and String(q.text) == text and (q.rect as Rect2).get_center().distance_to(lrect.get_center()) < 320.0: has_label = false
			if not has_label and kind == "": continue
			# 낮은 이름(마을 아래)은 이름을 못 얹으면 기호도 빼서 지도를 비운다(사건·할 말·깃발 같은 force 기호는 그대로)
			if not has_label and not force and int(c.prio) >= P_LANDMARK and kind in ["dot", "landmark", "spring"]: continue
			if has_label:
				_taken.append(lrect)
				_draw_label(text, lrect, f, sz, _faint_col(c.col) if faint else c.col, bool(c.get("plate", false)), faint)
				placed.append({ text = text, size = sz, rect = lrect, tier = int(c.get("tier", 1)), city = bool(c.get("city", false)), faint = faint })
		if kind != "" and icon_ok:
			if not force: _taken.append(irect)
			if faint: _icon_faint(_canvas, kind, p, ICON_S)
			else: _icon(_canvas, kind, p, ICON_S)
		if c.has("tip") or c.has("lead"):
			var hit := { p = p, r = maxf(14.0 * ICON_S, ir), tip = String(c.get("tip", text)) }
			if c.has("lead"): hit.lead = c.lead
			if c.has("station"): hit.station = c.station
			_hits.append(hit)

# 전국 지도: 화면에서 인 하나 너비 안에 겹친 사건 인(다른 사건)은 하나로 — 이름은 첫 것 + '외 n', 설명에 모두
func _merge_cases(cands: Array) -> Array:
	var cr := _icon_r("case") * 2.0 + 6.0
	var out: Array = []
	var seals: Array = []
	for c in cands:
		if String(c.kind) != "case": out.append(c); continue
		var g = null
		for e in seals:
			if (e.p as Vector2).distance_to(c.p) < cr: g = e; break
		if g == null:
			var e: Dictionary = c.duplicate()
			e.n = 1; e.first = String(c.text)
			seals.append(e); out.append(e)
		else:
			g.n += 1
			g.text = "%s 외 %d" % [g.first, g.n - 1]
			g.tip = String(g.tip) + " · " + String(c.tip)
	return out

func _collides(r: Rect2) -> bool:
	for t in _taken:
		if (t as Rect2).intersects(r): return true
	return false

static func _hits_any(r: Rect2, rects: Array) -> bool:
	for t in rects:
		if (t as Rect2).intersects(r): return true
	return false

# 이름표: 먹 글씨 + 두꺼운 한지빛 테두리(HALO — 먹 산줄기·물길 위에서도 읽힌다) · 고을(읍치)은 한지 판에 먹 테
func _draw_label(s: String, r: Rect2, f: Font, sz: int, col: Color, plate: bool, faint := false) -> void:
	var base := r.position + Vector2(6, sz * 0.98)
	if plate:
		_canvas.draw_rect(r.grow(1), Color(PAPER, 0.94))
		if faint: _dashed_rect(_canvas, r.grow(1), Color(INK, 0.5), 2.0)
		else: _canvas.draw_rect(r.grow(1), Color(INK, 0.85), false, 2.0)
	else:
		_canvas.draw_rect(r.grow(-2), Color(PAPER, 0.5))   # 옅은 한지 바탕 — 집채·산줄기가 글자 사이로 비치지 않게
		_canvas.draw_string_outline(f, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, HALO, Color(PAPER, 0.97))
	_canvas.draw_string(f, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

# KNOWN(앎 · 안 가 봄)의 먹: 한지 쪽으로 바랜 먹(글은 그대로 읽힌다 — 크기·글꼴은 같다)
const FAINT_MIX := 0.45
static func _faint_col(c: Color) -> Color:
	return c.lerp(PAPER, FAINT_MIX)

# KNOWN 기호: 같은 기호를 한지빛으로 바래게 덮고 점선 테를 두른다(빈·옅은 기호)
func _icon_faint(ci: CanvasItem, kind: String, p: Vector2, s: float) -> void:
	_icon(ci, kind, p, s)
	var r := maxf(_icon_r(kind), 5.0 * s)
	ci.draw_circle(p, r * 0.95, Color(PAPER, 0.58))
	_dashed_arc(ci, p, r + 1.5, Color(INK_SOFT, 0.85), 1.4 * s)

static func _dashed_arc(ci: CanvasItem, p: Vector2, r: float, col: Color, w: float) -> void:
	var n := 12
	for i in n:
		var a0 := TAU * float(i) / n
		ci.draw_arc(p, r, a0, a0 + TAU / n * 0.55, 6, col, w, true)

static func _dashed_rect(ci: CanvasItem, r: Rect2, col: Color, w: float) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = pts[i]; var b: Vector2 = pts[i + 1]
		var L := a.distance_to(b); var d := (b - a) / maxf(L, 0.001)
		var t := 0.0
		while t < L:
			ci.draw_line(a + d * t, a + d * minf(t + 8.0, L), col, w)
			t += 13.0

# 기호 반지름(화면 픽셀) — 겹침 솎기·이름표 자리. 글자가 든 기호('역' 패·'사' 인)는 MAP_GLYPH 글자가 들어가는 크기
func _icon_r(kind: String) -> float:
	match kind:
		"": return 0.0
		"station": return UiFonts.MAP_GLYPH * 0.74 + 2.0
		"case": return UiFonts.MAP_GLYPH * 0.72 * 1.15
		"eup", "hub", "hub_here": return 11.0 * ICON_S
		"dot": return 4.0 * ICON_S
		"talk": return 9.0 * ICON_S
	return 8.0 * ICON_S

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
		"flag":   # 길목 깃발: 장대 + 쪽빛 깃발(붉은 테)
			ci.draw_line(p + Vector2(-3, 7) * s, p + Vector2(-3, -8) * s, Color(0.36, 0.26, 0.17), 1.8 * s)
			var fl := PackedVector2Array([p + Vector2(-3, -8) * s, p + Vector2(6, -7) * s, p + Vector2(5, -1) * s, p + Vector2(-3, -2) * s])
			ci.draw_colored_polygon(fl, Color(0.20, 0.28, 0.43))
			ci.draw_polyline(PackedVector2Array([fl[0], fl[1], fl[2], fl[3]]), SEAL, 1.2 * s)
			ci.draw_line(p + Vector2(-6, 7) * s, p + Vector2(0, 7) * s, INK, 1.6 * s)
		"station":   # 역참·마방: 붉은 테 둥근 패에 '역'
			var rs := maxf(8.0 * s, UiFonts.MAP_GLYPH * 0.74)   # 글자(MAP_GLYPH 고정)가 들어가는 둥근 패
			ci.draw_circle(p, rs, PAPER)
			ci.draw_arc(p, rs, 0, TAU, 24, SEAL, 2.0 * s, true)
			_glyph(ci, "역", p, SEAL)
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
			var r := maxf(10.0 * s, UiFonts.MAP_GLYPH * 0.72)   # 글자(MAP_GLYPH)가 들어가는 인
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
			_glyph(ci, "사", p, Color(1, 0.95, 0.88))
		"talk":   # 할 말 있는 사람: 작은 붉은 둥근 인에 「…」
			ci.draw_circle(p + Vector2(0, -3) * s, 6.5 * s, Color(SEAL, 0.92))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-2.2, 2.5) * s, p + Vector2(2.2, 2.5) * s, p + Vector2(0, 8) * s]), Color(SEAL, 0.92))
			for i in 3: ci.draw_circle(p + Vector2(-3.2 + i * 3.2, -3) * s, 1.0 * s, Color(1, 0.95, 0.88))

# 기호 속 글자 — 기호 크기(s)와 상관없이 MAP_GLYPH(화면 픽셀) 그대로, 가운데 맞춤
func _glyph(ci: CanvasItem, ch: String, p: Vector2, col: Color) -> void:
	var gs := UiFonts.MAP_GLYPH
	var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
	ci.draw_string(_font, p + Vector2(-w / 2, gs * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, col)
	if ci == _canvas: glyph_sizes.append(gs)

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
		_canvas.draw_circle(c, 8.0, SEAL)
		_taken.append(Rect2(c - Vector2(9, 9), Vector2(18, 18)))
		var s := "→ " + String(pt.label)
		var f := _font
		var fs := UiFonts.MAP_LABEL
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8
		var r := Rect2(c + Vector2(-w / 2, 12), Vector2(w, fs * 1.25))
		if not _collides(r.grow(LABEL_PAD)):
			_taken.append(r); _draw_label(s, r, f, fs, Color(0.45, 0.1, 0.06), false)
			placed.append({ text = s, size = fs, rect = r })

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
		_flags = _collect_flags()
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
		var c := _n_px(ll) + Vector2(16, 12) * ICON_S
		var rr := 9.0 * ICON_S if _st_on() else maxf(14.0, UiFonts.MAP_GLYPH * 0.7)   # 번호(MAP_GLYPH)가 들어가는 금빛 패(역참 쪽이면 번호 없음)
		_canvas.draw_circle(c, rr, INK)
		_canvas.draw_circle(c, rr - 2.0, FAST_COL if not sel else Color(0.95, 0.45, 0.1))
		if not _st_on(): _glyph(_canvas, str(i + 1), c, INK)
		_taken.append(Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2))

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
			cands.append({ p = _polyline_at(px, 0.5), kind = "", text = nm, prio = P_MINOR + (0 if on else 1), size = UiFonts.MAP_MINOR, col = Color(0.42, 0.18, 0.12) })
	_draw_fast()
	# 사건 표지(권역별로 하나 — 사건 이름)
	var seen_pos := {}
	for l in _leads:
		var ll = _lead_ll(l)
		if ll == null: continue
		var key := "%s@%s" % [l.case, str((ll as Vector2).snapped(Vector2(0.05, 0.05)))]
		if seen_pos.has(key): continue
		seen_pos[key] = true
		var p := _n_px(ll) + Vector2(18, -18) * ICON_S
		cands.append({ p = p, kind = "case", text = String(l.title), prio = P_CASE, size = UiFonts.MAP_LABEL, col = SEAL, force = true,
			tip = "「%s」 %s" % [String(l.title), String(l.name)], lead = l })
	# 권역 거점
	for r in _nation.regions:
		if r.lonlat == null: continue
		var on: bool = String(r.get("id", "")) == here_id
		var known: bool = on or Discovery.region_known(String(r.get("id", "")))
		cands.append({ p = _n_px(r.lonlat), kind = "hub_here" if on else "hub", text = String(r.get("short", r.get("name", ""))) if known else "",
			prio = P_HERE if on else P_HUB, size = UiFonts.MAP_HUB, col = INK, title = true, plate = true, force = true, city = true })
	# 거점 88곳(지도에만 있는 곳 포함): 작은 네모, 가 본 이름만
	for s in _nation.get("strongholds", []):
		if String(s.get("status", "")) == "region": continue
		var nm := String(s.name)
		cands.append({ p = _n_px(Vector2(float(s.lon), float(s.lat))), kind = "stronghold", text = nm if Discovery.is_known(Discovery.NATION, "sh:" + nm) else "",
			prio = P_VILLAGE, size = UiFonts.MAP_MINOR, col = INK_SOFT })
	# 길목 깃발(가 본 것)
	for f in _flags:
		if f.ll == null: continue
		cands.append({ p = _n_px(f.ll), kind = "flag", text = "", prio = P_STATION, size = UiFonts.MAP_LABEL, col = INK, tip = "깃발 %s" % String(f.name) })
	# 역참
	for i in _stations.size():
		var s: Dictionary = _stations[i]
		if s.ll == null: continue
		cands.append({ p = _n_px(s.ll), kind = "station", text = String(s.name), prio = P_STATION, size = UiFonts.MAP_LABEL, col = INK, station = i,
			tip = "역참 %s — 눌러 고르고, 한 번 더 누르면 간다" % String(s.name) })
	var here = _here_ll()
	_place_all(_merge_cases(cands))
	if here != null:
		var p := _n_px(here)
		_canvas.draw_circle(p, 14.0, Color(0.75, 0.15, 0.1, 0.25))
		_canvas.draw_circle(p, 6.0, SEAL)
		_canvas.draw_arc(p, 9.0, 0, TAU, 24, Color(1, 0.97, 0.9), 2.0)
	# 10리 자(전국: 1° 위도 ≈ 110km ≈ 262리)
	_draw_scale_bar(_nk * (4.2 / 110.574))

# ---- 시험: --mapshots=폴더 [--mapzooms] [--mapknow] — 불러오기가 끝나면 도시·권역·전국 지도를 찍고(창 그림) 여는 시간을 적는다 ----
#   --mapzooms: 권역 최소·중간·최대(고을 지도 바로 앞) · 고을 · 고을 최대 · 전국 · 전국 최대 · 역참/노정 확인 상자
#   --mapknow:  시험 저장에 이 공간의 고을·이름난 곳·고개·건물과 전국 권역·거점을 모두 '가 봄'으로 적는다(이름표 겹침 확인)
func know_all() -> void:
	for t in _towns: Discovery.visit(_space, "town:" + String(t[0])); Discovery.visit(Discovery.NATION, "sh:" + String(t[0]))
	for l in world.region.get("landmarks", []): Discovery.visit(_space, "lm:" + String(l.get("id", l.get("name", ""))))
	for ps in world.region.get("passes", []): Discovery.visit(_space, "pass:" + String(ps.get("id", ps.get("name", ""))))
	for it in _items: Discovery.visit(_space, Discovery.bld_key(it.name, it.c))
	for r in Travel.regions(): Discovery.visit(Discovery.NATION, "region:" + String(r.get("id", "")))
	# 역마 거점(역참·깃발 '가 봄' — progress.json travel_nodes): 이 공간과 한양
	var HR: Script = load("res://scripts/region/horse_ride.gd")
	for sp in [_space, "GG_HANYANG"]:
		for n in RideNetRef.read(sp).get("nodes", []):
			if bool(n.get("fast", false)): HR.discover(sp, String(n.id))
	_refresh_dynamic()
	var sj = JSON.parse_string(FileAccess.get_file_as_string("res://region_data/strongholds.json"))
	if sj is Dictionary:
		for s in sj.get("strongholds", []): Discovery.visit(Discovery.NATION, "sh:" + String(s.name))

# ---- 시험: --maptexttest — 이름표 글 크기가 확대와 상관없는지 · 확대 단계(건물 이름) · 겹침 없음 → MAPTEXTTEST PASS/FAIL ----
func _redraw_wait() -> void:
	_canvas.queue_redraw()
	for i in 3: await get_tree().process_frame

func _set_view(mname: String, kk: float, at = null) -> void:
	if mname == "nation":
		if mode != "nation": _show_nation()
		_nk = kk
	else:
		mode = "all"; _k = kk
		mode = "all" if _k < _city_k() else "city"
		if at != null: _center = at
	_after_view()

func _maptexttest() -> void:
	var m := get_parent()
	while m._loading: await get_tree().process_frame
	for i in 20: await get_tree().process_frame
	know_all()
	var fails := []
	if get_viewport().get_visible_rect().size.y < 700: get_tree().root.size = Vector2i(1024, 768)   # 헤드리스: 창 1024×768로 놓고 잰다
	await get_tree().process_frame
	print("MAPTEXT viewport ", get_viewport().get_visible_rect().size)
	page = 0   # 배율 시험은 판을 닫고(지도 넓이가 판에 따라 바뀐다). 판 쪽은 아래에서 따로
	toggle()
	var home = _town_at(Vector2(_player.x, _player.z))
	if home == null: home = _nearest_town(Vector2(_player.x, _player.z))
	var hc: Vector2 = home[1] if home != null else Vector2(_player.x, _player.z)
	var zooms := { all = [_k_min, minf(tier2_k() * 1.05, _city_k() * 0.9), _city_k() * 0.97], city = [_city_k(), tier3_k() * 1.05, MAX_K],
		nation = [_n_fit(), _n_fit() * 3.5, _n_fit() * 12.0] }
	var allowed := [UiFonts.MAP_LABEL, UiFonts.MAP_MINOR, UiFonts.MAP_KEYS]
	# 고을 이름은 그대로(26·24), 그 밖의 지도 글은 모두 고을 이름 크기(MAP_MIN = MAP_HUB) 이상
	if UiFonts.MAP_HUB != 26 or UiFonts.MAP_TOWN != 24: fails.append("고을 이름 크기가 바뀜 %d/%d" % [UiFonts.MAP_HUB, UiFonts.MAP_TOWN])
	if UiFonts.MAP_MIN < UiFonts.MAP_HUB: fails.append("MAP_MIN %d < 고을 이름 %d" % [UiFonts.MAP_MIN, UiFonts.MAP_HUB])
	for v in allowed + [UiFonts.MAP_GLYPH, UiFonts.MAP_PANEL]:
		if int(v) < UiFonts.MAP_MIN: fails.append("크기 표 %d < MAP_MIN %d" % [v, UiFonts.MAP_MIN])
	var report := []
	for mname in ["all", "city", "nation"]:
		var seen := {}
		for zi in 3:
			var kk: float = zooms[mname][zi]
			_set_view(mname, kk, hc)
			await _redraw_wait()
			var tag := "%s[%d] k=%.3f tier=%d" % [mname, zi, kk, _tier()]
			var n := 0
			for q in placed:
				var sz := int(q.size); var h := float((q.rect as Rect2).size.y)
				if bool(q.get("city", false)):
					if not sz in [UiFonts.MAP_HUB, UiFonts.MAP_TOWN]: fails.append("%s 고을 이름 크기 %d '%s'" % [tag, sz, q.text])
				elif bool(q.get("frame", false)):
					if sz < UiFonts.MAP_MIN: fails.append("%s 판·상자 글 %d '%s'" % [tag, sz, q.text])
				elif sz < UiFonts.MAP_MIN or not sz in allowed: fails.append("%s 글 크기 %d '%s'" % [tag, sz, q.text])
				var key := String(q.text)
				if seen.has(key) and (int(seen[key][0]) != sz or absf(float(seen[key][1]) - h) > 0.01):
					fails.append("%s '%s' 크기 %d/%.1f ≠ %s" % [tag, key, sz, h, seen[key]])
				seen[key] = [sz, h]
				if not bool(q.get("scale_bar", false)) and not bool(q.get("frame", false)): n += 1
				if not Rect2(Vector2.ZERO, _canvas.size).encloses((q.rect as Rect2).grow(-1.0)): fails.append("%s 지도 밖 '%s'" % [tag, q.text])
			for gsz in glyph_sizes:
				if int(gsz) != UiFonts.MAP_GLYPH or int(gsz) < UiFonts.MAP_MIN: fails.append("%s 기호 글자 %d" % [tag, gsz])
			if mname == "all" and zi == 0 and _tier() != 1: fails.append("%s 가장 멀리인데 단계 %d" % [tag, _tier()])
			if mname == "all" and zi == 1 and _tier() != 2: fails.append("%s 중간인데 단계 %d" % [tag, _tier()])
			for a in placed.size():
				for b in range(a + 1, placed.size()):
					if (placed[a].rect as Rect2).grow(-1.0).intersects((placed[b].rect as Rect2).grow(-1.0)):
						fails.append("%s 겹침 '%s'·'%s'" % [tag, placed[a].text, placed[b].text])
			var t3 := placed.filter(func(q): return int(q.get("tier", 1)) == 3).size()
			if n == 0 and zi < 2: fails.append("%s 이름표 없음" % tag)   # 최대 배율은 빈 땅일 수 있다
			if _tier() < 3 and t3 > 0: fails.append("%s 먼 배율인데 건물 이름 %d" % [tag, t3])
			report.append("%s labels=%d glyphs=%d buildings=%d" % [tag, n, glyph_sizes.size(), t3])
	# 건물 이름: 가까이(최대 배율, 그 건물 가운데)에서 보이고 멀리(권역 최소)에서는 없다 — 글 크기는 같다
	var bld := ""
	var bsize := -1
	for it in _items:
		if int(it.tier) != 3: continue
		_set_view("city", MAX_K, it.c)
		await _redraw_wait()
		for q in placed:
			if String(q.text) == String(it.name) and int(q.get("tier", 1)) == 3: bld = String(it.name); bsize = int(q.size)
		if bld != "":
			_set_view("all", _k_min, it.c)
			await _redraw_wait()
			for q in placed:
				if String(q.text) == bld: fails.append("멀리서도 건물 이름 '%s'" % bld)
			_set_view("city", tier3_k() * 1.05, it.c)
			await _redraw_wait()
			for q in placed:
				if String(q.text) == bld and int(q.size) != bsize: fails.append("건물 이름 크기 %d ≠ %d" % [q.size, bsize])
			break
	if bld == "": fails.append("가까이 확대해도 건물 이름이 하나도 없다")
	# 판(범례·사건·역참 쪽) · 아래 안내 · 역마 확인 상자 — 글 크기 MAP_MIN 이상, 1024×768 안, 서로 겹치지 않음
	var vr := get_viewport().get_visible_rect()
	if _hint.get_theme_font_size("font_size") < UiFonts.MAP_MIN: fails.append("아래 안내 글 %d" % _hint.get_theme_font_size("font_size"))
	if _font.get_string_size(_hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.MAP_KEYS).x > vr.size.x - 16.0 or _hint.text.contains("…"): fails.append("아래 안내가 한 줄에 안 들어감 '%s'" % _hint.text)
	for pg in [1, 2]:
		_set_view("all", _k_min, hc)
		set_page(pg)
		await _redraw_wait(); await _redraw_wait()
		var pr := Rect2(_panel.position, _panel.size)
		var cr := Rect2(_canvas.position, _canvas.size)
		var hr := Rect2(_hint.position, _hint.size)
		if not vr.encloses(pr) or not vr.encloses(cr) or not vr.encloses(hr): fails.append("쪽 %d 화면 밖 판%s 지도%s 안내%s" % [pg, pr, cr, hr])
		if pr.intersects(cr) or hr.intersects(cr.grow(-2)) or hr.intersects(pr.grow(-2)): fails.append("쪽 %d 판·지도·안내 겹침" % pg)
		var small := []
		for l in _panel.find_children("*", "Label", true, false) + _panel.find_children("*", "Button", true, false):
			if (l as Control).is_visible_in_tree() and (l as Control).get_theme_font_size("font_size") < UiFonts.MAP_MIN: small.append(String(l.text))
		if not small.is_empty(): fails.append("쪽 %d 작은 글 %s" % [pg, small])
		if pg == 1:
			var cols := legend_cols()
			var colw := _legend.size.x / float(cols)
			for e in LEGEND:
				if LEGEND_ICON_W + 6.0 + _font.get_string_size(String(e[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiFonts.MAP_PANEL).x > colw + 0.5: fails.append("범례 '%s' 칸 넘침" % e[1])
			print("MAPTEXT legend cols=%d width=%.0f rows=%.0f panel=%s" % [cols, _legend.size.x, _legend.size.y, pr])
	set_page(0)
	if not _stations.is_empty():
		_station_pick(0)
		await _redraw_wait()
		var box := _confirm_rect()
		if not Rect2(Vector2.ZERO, _canvas.size).encloses(box): fails.append("역참 확인 상자 밖 %s" % box)
		for q in placed:
			if bool(q.get("frame", false)) and int(q.size) < UiFonts.MAP_MIN: fails.append("확인 상자 글 %d" % q.size)
		_st_sel = -1
		set_page(0)
	for r in report: print("MAPTEXT ", r)
	print("MAPTEXT building '%s' size=%d tier2_k=%.3f tier3_k=%.3f city_k=%.3f k_min=%.3f" % [bld, bsize, tier2_k(), tier3_k(), _city_k(), _k_min])
	if fails.is_empty(): print("MAPTEXTTEST PASS zoom-invariant sizes, tiers, no overlap (%d views)" % report.size())
	else:
		for f in fails.slice(0, 30): print("MAPTEXT fail ", f)
		print("MAPTEXTTEST FAIL %d" % fails.size())
	m._quit()

func _mapshots(dir: String) -> void:
	var m := get_parent()
	while m._loading: await get_tree().process_frame
	for i in 30: await get_tree().process_frame
	var out: String = m._abs(dir)
	DirAccess.make_dir_recursive_absolute(out)
	var tag := _space + String(m.args.get("maptag", ""))
	if m.args.has("mapknow"): know_all()
	var shots := []
	var t0 := Time.get_ticks_usec()
	toggle()
	print("MAPSHOT open_ms=%.1f mode=%s" % [(Time.get_ticks_usec() - t0) / 1000.0, mode])
	var home = _town_at(Vector2(_player.x, _player.z))
	if home == null: home = _nearest_town(Vector2(_player.x, _player.z))
	for t in _towns:   # --mapcenter=고을 이름: 그 고을을 가운데로(빽빽한 도성 안 솎기 확인)
		if m.args.has("mapcenter") and String(t[0]) == String(m.args.mapcenter): home = t
	shots.append(["city", 1.0])
	if m.args.has("mapzooms"): shots += [["all_min", 10.0], ["all_mid", 11.0], ["all_max", 12.0], ["city_t3", 13.0], ["city_close", 14.0], ["city_max", 99.0]]
	shots.append(["all", -1.0]); shots.append(["nation", -2.0])
	if m.args.has("mapzooms"): shots += [["nation_max", 98.0], ["nation_legend", 95.0], ["nation_confirm", 97.0], ["station_confirm", 96.0], ["all_cases", 94.0]]
	for s in shots:
		if page != 0 and not s[1] in [95.0, 94.0, 96.0]: set_page(0)
		if s[1] == -1.0: show_mode("all")
		elif s[1] == -2.0:
			var t1 := Time.get_ticks_usec(); show_mode("nation")
			print("MAPSHOT nation_ms=%.1f" % ((Time.get_ticks_usec() - t1) / 1000.0))
		elif s[1] == 1.0 and mode != "city" and home != null: _show_city(home)
		elif s[1] in [10.0, 11.0, 12.0]:
			_show_all()
			var kk: float = { 10.0: _k_min, 11.0: minf(tier2_k() * 1.1, _city_k() * 0.9), 12.0: _city_k() * 0.97 }[s[1]]
			_zoom(kk / _k, _canvas.size / 2.0)
		elif s[1] == 13.0 or s[1] == 14.0:   # 3단계(건물 이름) 문턱 조금 위 · 더 가까이 — 고을 가운데
			_show_city(home)
			_k = minf(MAX_K, tier3_k() * (1.1 if s[1] == 13.0 else 1.6))
			_center = (home[2] as Rect2).get_center() if home != null else _center
			_zoom(1.0, _canvas.size / 2.0)
		elif s[1] == 99.0: _show_city(home); _zoom(10000.0, _canvas.size / 2.0)
		elif s[1] == 98.0: _zoom(10000.0, _canvas.size / 2.0)
		elif s[1] == 95.0: _show_nation(); set_page(1)
		elif s[1] == 94.0: _show_all(); set_page(2)
		elif s[1] == 97.0:
			_show_nation()
			if not _fast_opts.is_empty(): _fast_pick(0)
		elif s[1] == 96.0:
			_fast_sel = -1; _show_all()
			_refresh_dynamic()
			if not _stations.is_empty(): _station_pick(0)
		for i in 4: await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null:
			var f: String = out.path_join("%s_%s.png" % [tag, s[0]])
			img.save_png(f); print("MAPSHOT ", f, " mode=", mode, " k=", _k if mode != "nation" else _nk, " labels=", _taken.size(), " cases=", _leads.size())
			for q in placed:   # 이름표 자리(화면 픽셀) — 찍은 그림에서 글 높이를 잴 때
				var rr: Rect2 = q.rect
				print("MAPLABEL %s|%s|%d|%d|%d|%d|%d" % [s[0], q.text, q.size, roundi(rr.position.x + _canvas.position.x), roundi(rr.position.y + _canvas.position.y), roundi(rr.size.x), roundi(rr.size.y)])
	_st_sel = -1; _fast_sel = -1
	set_page(0)
	if m.args.has("mapzooms"): await _fast_shots(out, tag)
	if m.args.has("quit"): m._quit()

# 역마 창 작은 지도(같은 공간 · 다른 공간) — 가 본 거점을 모두 적고 이름표 겹침을 본다(MAPLABEL fast_*)
func _fast_shots(out: String, tag: String) -> void:
	var m := get_parent()
	visible = false
	var ft = load("res://scripts/region/fast_travel.gd").new(m)
	m.add_child(ft)
	for i in 6: await RenderingServer.frame_post_draw
	var picks := { local = -1, nation = -1 }
	var far := -1.0
	for i in ft.items.size():
		var it: Dictionary = ft.items[i]
		if it.same:
			var d := (it.at as Vector2).distance_to(Vector2(_player.x, _player.z))
			if d > far: far = d; picks.local = i
		elif picks.nation < 0: picks.nation = i
	for k in ["local", "nation"]:
		if int(picks[k]) < 0: continue
		ft.sel = int(picks[k])
		ft._canvas.queue_redraw()
		for i in 4: await RenderingServer.frame_post_draw
		var f: String = out.path_join("%s_fast_%s.png" % [tag, k])
		get_viewport().get_texture().get_image().save_png(f)
		print("MAPSHOT ", f)
		for q in ft.map_labels: print("MAPLABEL fast_%s|%s|%d|%d|%d|%d|%d" % [k, q.text, q.size, roundi(q.rect.position.x), roundi(q.rect.position.y), roundi(q.rect.size.x), roundi(q.rect.size.y)])
	ft.close()
	for i in 3: await RenderingServer.frame_post_draw
