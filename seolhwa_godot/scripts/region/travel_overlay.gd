# 이동 연출 위 공용 덧층(region_main이 붙인다):
#   · 건너뛰기 단추 "Space 건너뛰기"(누르거나 Space) — 자동 기승(horse_ride.skip)·배(boat_ride.skip)가 건너뛸 수 있을 때만.
#     역마 창(지도 위 길 연출)은 창이 멈춤 중이라 제 안에 같은 단추를 그린다(fast_travel.gd). 노정 건너뛰기(포털 H·전국 지도)는 곧장 불러오기라 연출이 없다.
#   · 개발 표시 "개발: 전국 이동 열림"(scripts/region/dev_travel.gd)
extends CanvasLayer

const DevTravel := preload("res://scripts/region/dev_travel.gd")
const UiFonts := preload("res://scripts/ui_fonts.gd")
const PAPER := Color("#efe6d2")
const INK := Color("#2b2622")
const SEAL := Color("#a8443c")

var main
var what := ""          # "" · horse · boat — 지금 건너뛸 수 있는 것
var _btn: Button
var _dev: Label
var _k := 1.0

func _init(m) -> void:
	main = m
	name = "travel_overlay"
	layer = 30

func _ready() -> void:
	var f: Font = UiFonts.main()
	_k = UiFonts.k(get_viewport().get_visible_rect().size, 1.0)
	_btn = Button.new()
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.text = "Space  건너뛰기"
	_btn.add_theme_font_override("font", f)
	_btn.add_theme_font_size_override("font_size", int(UiFonts.BODY * _k))
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(PAPER, 0.95) if st == "normal" else Color(1.0, 0.95, 0.82)
		sb.border_color = INK if st == "normal" else SEAL
		sb.set_border_width_all(3)
		sb.content_margin_left = 25; sb.content_margin_right = 25; sb.content_margin_top = 8; sb.content_margin_bottom = 8
		_btn.add_theme_stylebox_override(st, sb)
	_btn.add_theme_color_override("font_color", INK)
	_btn.add_theme_color_override("font_hover_color", SEAL)
	_btn.pressed.connect(skip)
	_btn.visible = false
	add_child(_btn)
	_dev = Label.new()
	_dev.text = "개발: 전국 이동 열림"
	_dev.add_theme_font_override("font", f)
	_dev.add_theme_font_size_override("font_size", int(UiFonts.DETAIL * _k))
	_dev.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	_dev.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_dev.add_theme_constant_override("outline_size", 8)
	_dev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dev.visible = false
	add_child(_dev)

func _process(_dt: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	_dev.visible = DevTravel.on
	if _dev.visible:
		_dev.reset_size()
		_dev.position = Vector2(vs.x - _dev.size.x - 25.0 * _k, 104 * _k)   # 오른쪽 위, 지도 이름 판 아래(왼쪽 위 HUD·지명과 겹치지 않게)
	var w := ""
	if main._loading or main._leaving: w = ""
	elif main.horse_ride != null and main.horse_ride.can_skip(): w = "horse"
	elif main.boats != null and main.boats.can_skip(): w = "boat"
	what = w
	_btn.visible = w != ""
	if _btn.visible:
		_btn.reset_size()
		_btn.position = Vector2(vs.x - _btn.size.x - 25.0 * _k, vs.y - _btn.size.y - 211 * _k)
		if Input.is_action_just_pressed("boat_skip"): skip()

func skip() -> void:
	match what:
		"horse": main.horse_ride.skip()
		"boat": main.boats.skip()
	what = ""
	_btn.visible = false
