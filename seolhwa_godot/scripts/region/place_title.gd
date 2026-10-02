# 지명 표시 — 마을에 들어서거나 게임이 켜질 때 화면 중앙 상단에 지명(예: 남원)이 떠올랐다 사라진다.
# 지명 구역은 region.json settlements를 짧은 이름으로 묶어 만든다(bbox 또는 반지름 + 여유).
extends CanvasLayer

const MARGIN := 40.0      # 마을 터 바깥 여유(m) — 이 안에 들어서면 지명을 띄운다
const EXIT_EXTRA := 40.0  # 나갈 때는 더 멀리 가야 나간 것으로(경계에서 깜박이지 않게)
const FADE_IN := 0.9
const HOLD := 2.4
const FADE_OUT := 1.2

# settlement id → 표시 이름(없으면 표시하지 않음 — 들마을 후보 등)
const TITLES := {
	namwon_eup = "남원", namwon_jang = "남원", namwon_hyanggyo = "남원",
	ibaek = "이백", yeowon_jumak = "여원재", yeowon_seonghwang = "여원재",
	unbong_eup = "운봉", unbong_jang = "운봉", bijeon = "황산",
	inwol_yeok = "인월", inwol_jang = "인월", sannae = "산내",
	silsangsa_temple = "실상사", banseon = "반선",
}

var areas := {}   # 이름 → [Rect2…]
var current := ""
var _label: Label
var _rule: ColorRect
var _t := -1.0

func setup(region: Dictionary) -> void:
	for s in region.get("settlements", []):
		var title: String = TITLES.get(String(s.get("id", "")), "")
		if title == "": continue
		var r: Rect2
		var bb = s.get("bbox")
		if bb is Array and bb.size() == 4:
			r = Rect2(Vector2(bb[0], bb[1]), Vector2(bb[2] - bb[0], bb[3] - bb[1]))
		else:
			var rad := float(s.get("radius_m", 40.0))
			r = Rect2(Vector2(float(s.x) - rad, float(s.z) - rad), Vector2(rad * 2.0, rad * 2.0))
		if not areas.has(title): areas[title] = []
		areas[title].append(r)

func _ready() -> void:
	layer = 5
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position.y = 0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["AppleMyungjo", "Nanum Myeongjo", "NanumMyeongjo", "Batang", "Noto Serif CJK KR", "Apple SD Gothic Neo"])
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 46)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.035, 1.0))
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	_label.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(_label)
	_rule = ColorRect.new() # 이름 아래 가는 선(흰 선 + 검은 테두리 느낌)
	_rule.color = Color(1, 1, 1)
	_rule.custom_minimum_size = Vector2(120, 2)
	_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rule_bg := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.04, 0.035); sb.content_margin_left = 1; sb.content_margin_right = 1; sb.content_margin_top = 1; sb.content_margin_bottom = 1
	rule_bg.add_theme_stylebox_override("panel", sb)
	rule_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule_bg.add_child(_rule)
	box.add_child(rule_bg)
	_resize()
	get_viewport().size_changed.connect(_resize)
	_set_alpha(0.0)

func _resize() -> void:
	var vs := get_viewport().get_visible_rect().size
	var box: Control = _label.get_parent()
	box.size.x = vs.x
	box.position = Vector2(0, vs.y * 0.08)
	_label.add_theme_font_size_override("font_size", int(clampf(vs.y * 0.06, 28.0, 72.0)))

func _set_alpha(a: float) -> void:
	_label.modulate.a = a
	(_rule.get_parent() as Control).modulate.a = a * 0.9

func _inside(title: String, p: Vector2, extra: float) -> bool:
	for r in areas.get(title, []):
		if (r as Rect2).grow(MARGIN + extra).has_point(p): return true
	return false

func show_title(title: String) -> void:
	_label.text = title
	_rule.custom_minimum_size.x = maxf(120.0, title.length() * 52.0)
	_t = 0.0

# 매 프레임: 플레이어 위치(x, z)
func update(dt: float, pos: Vector3) -> void:
	var p := Vector2(pos.x, pos.z)
	if current != "" and not _inside(current, p, EXIT_EXTRA): current = ""
	if current == "":
		for title in areas:
			if _inside(title, p, 0.0):
				current = title
				show_title(title)
				break
	if _t < 0.0: return
	_t += dt
	var a := 0.0
	if _t < FADE_IN: a = smoothstep(0.0, 1.0, _t / FADE_IN)
	elif _t < FADE_IN + HOLD: a = 1.0
	elif _t < FADE_IN + HOLD + FADE_OUT: a = 1.0 - smoothstep(0.0, 1.0, (_t - FADE_IN - HOLD) / FADE_OUT)
	else: _t = -1.0
	_set_alpha(a)
