# 세계 방위 줄(재기획 3단계 최소판 — 첫15 P02-C '월드에 방위 안내', 지도 v1.3 §04): 지도에서 정한 목적지(progress.waypoint)가
#   이 공간에 있으면 화면 위쪽 가운데에 한 줄 — "목적지 · 여원재 방면   동북동쪽 3.3km"(땅 방위 — 기본 시점은 화면 위가 북).
#   화살 글자는 쓰지 않는다(본문 글꼴에 없을 수 있다 — tools/font_coverage.gd).
#   대화·컷·기록책·큰 창(지도·문서·Esc — HudGate) 동안·시작 메뉴·걸으며 보는 제목 동안은 감춘다.
#   4단계: 다른 공간 목적지는 그쪽 길 끝을, [말로 이동] 뒤 말 타는 곳까지 걸어가는 중이면 그 자리를 가리킨다.
#   story_director가 만들어 붙인다(사건이 없는 공간에서도). 0.25초마다 글만 고친다.
extends CanvasLayer

const Progress := preload("res://scripts/region/progress.gd")
const UiFonts := preload("res://scripts/ui_fonts.gd")
const HudGate := preload("res://scripts/hud_gate.gd")
const WaypointPlan := preload("res://scripts/region/waypoint_plan.gd")
const INK := Color("#2b2622")
const PAPER := Color("#efe6d2")
const SEAL := Color("#a8443c")
const DIRS := ["북", "북북동", "북동", "동북동", "동", "동남동", "남동", "남남동", "남", "남남서", "남서", "서남서", "서", "서북서", "북서", "북북서"]

var d                 # story_director
var _box: PanelContainer
var _l: Label
var _t := 0.0
var text := ""        # 시험 기록: 지금 보이는 글("" = 감춤)

func _init(director) -> void:
	d = director
	layer = 6
	name = "waypoint_hud"
	add_to_group(HudGate.HIDE)

func _ready() -> void:
	_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER, 0.9); sb.border_color = SEAL; sb.set_border_width_all(2); sb.set_corner_radius_all(3)
	sb.content_margin_left = 18; sb.content_margin_right = 18; sb.content_margin_top = 6; sb.content_margin_bottom = 6
	_box.add_theme_stylebox_override("panel", sb)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_l = Label.new()
	_l.add_theme_font_override("font", UiFonts.main())
	_l.add_theme_color_override("font_color", INK)
	_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_l)
	add_child(_box)
	_box.visible = false

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0: return
	_t = 0.25
	var s := _line()
	text = s
	_box.visible = s != ""
	if s == "": return
	var vs := get_viewport().get_visible_rect().size
	var k := UiFonts.k(vs, 1.0)
	_l.add_theme_font_size_override("font_size", int(UiFonts.KEYS * k))
	_l.text = s
	_box.reset_size()
	_box.position = Vector2((vs.x - _box.size.x) * 0.5, vs.y * 0.035)

func _hidden() -> bool:
	if d == null or d.main == null or d.main._loading: return true
	if d.title != null and d.title.active: return true
	if d.talking or d._cut or d.get("hush_hints") == true: return true
	if d.ui != null and (d.ui.modal or d.ui.journal_open): return true
	if d.runner != null and d.runner.busy and not d.free_move: return true
	var m = d.main.get("_map")
	if m != null and m.visible: return true
	return false

func _line() -> String:
	var wp := Progress.waypoint()
	if wp.is_empty() or _hidden(): return ""
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var nm := String(wp.get("name", ""))
	# 다른 공간 목적지(재기획 4단계): 그쪽으로 이어진 길 끝을 가리킨다 — 넘어가면 다음 공간에서 다시 잇는다
	if String(wp.get("space", "")) != String(d.space_id):
		var ex := WaypointPlan.exit_for(String(d.space_id), String(wp.space))
		if ex.is_empty(): return "목적지 · %s (다른 고을 — 길을 모른다)" % nm
		return "목적지 · %s — %s %s" % [nm, String(ex.name), _bearing(ex.p - pp)]
	var tgt := Vector2(float(wp.x), float(wp.z))
	var v := tgt - pp
	if v.length() < 25.0: return "목적지 · %s  — 여기" % nm
	var line := "목적지 · %s   %s" % [nm, _bearing(v)]
	# [말로 이동]을 골랐는데 말 타는 곳이 멀어 걸어가는 중(horse_ride.intent)
	var hr = d.main.get("horse_ride")
	if hr != null and not hr.intent.is_empty() and not hr.mounted():
		var mv: Vector2 = (hr.intent.p as Vector2) - pp
		line = "말 타는 곳 · %s   %s   (목적지 · %s)" % [String(hr.intent.name), _bearing(mv) if mv.length() >= 20.0 else "여기 — E", nm]
	return line

# 땅 방위 + 거리: 북 = −z(기본 시점은 화면 위가 북) — "동북동쪽 3.2km"
static func _bearing(v: Vector2) -> String:
	var dist := v.length()
	var ang := atan2(v.x, -v.y)                       # 북에서 시계 방향
	var dir: String = DIRS[int(round(fposmod(ang, TAU) / TAU * 16.0)) % 16]
	var ds := ("%.1fkm" % (dist / 1000.0)) if dist >= 1000.0 else ("%dm" % int(round(dist / 10.0) * 10.0))
	return "%s쪽 %s" % [dir, ds]
