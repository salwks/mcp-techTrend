# 시작 메뉴 — 새 게임 / 이어 하기(--newgame 없이 시험할 수 있게). story_director가 그냥 실행했을 때만 띄운다.
#   새 게임: 저장(user://progress.json)을 비우고 남원 S0001부터. 남원에 있으면 그 자리에서, 아니면 남원으로 넘어간다.
#   이어 하기: 저장된 자리(progress.where)로. 다른 공간이면 그 공간으로 넘어간다(Travel 예약 + resume_at).
# 열려 있는 동안 story_director.blocks_move()가 참이라 플레이어·이야기가 멈춘다. ↑↓·W·S·1·2·Enter·E·클릭.
extends CanvasLayer

const Progress := preload("res://scripts/region/progress.gd")
const Travel := preload("res://scripts/region/travel.gd")
const PAPER := Color("#efe6d2")
const INK := Color("#2b2622")
const SEAL := Color("#a8443c")
const NAMWON := "JL_NAMWON_UNBONG"
const NAMWON_START := [-2952.0, 184.0]

var d
var active := true
var _sel := 0
var _btns: Array = []
var _can_continue := false
var _root: Control

func _init(director) -> void:
	d = director
	layer = 30
	name = "title_menu"

func _ready() -> void:
	_can_continue = Progress.has_save()
	_sel = 1 if _can_continue else 0
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["AppleMyungjo", "Nanum Myeongjo", "NanumMyeongjo", "Batang", "Noto Serif CJK KR", "Apple SD Gothic Neo"])
	_root = ColorRect.new()
	_root.color = Color(PAPER.r, PAPER.g, PAPER.b, 0.94)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var k: float = maxf(1.0, get_viewport().get_visible_rect().size.y / 768.0)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(cc)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(14 * k))
	cc.add_child(box)
	var t := Label.new(); t.text = "설화록"
	t.add_theme_font_override("font", font); t.add_theme_font_size_override("font_size", int(72 * k))
	t.add_theme_color_override("font_color", INK); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var sub := Label.new(); sub.text = "이름 없는 나그네의 사건 기록"
	sub.add_theme_font_override("font", font); sub.add_theme_font_size_override("font_size", int(22 * k))
	sub.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.7)); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 30 * k); box.add_child(gap)
	for i in 2:
		var b := Button.new()
		b.text = ["새 게임", "이어 하기"][i]
		b.disabled = i == 1 and not _can_continue
		b.flat = true
		b.add_theme_font_override("font", font); b.add_theme_font_size_override("font_size", int(32 * k))
		b.add_theme_color_override("font_color", INK); b.add_theme_color_override("font_hover_color", SEAL)
		b.add_theme_color_override("font_disabled_color", Color(INK.r, INK.g, INK.b, 0.3))
		b.pressed.connect(_pick.bind(i))
		box.add_child(b)
		_btns.append(b)
	_hilite()
	if d.main.args.has("titletest"): _self_test.call_deferred(String(d.main.args.titletest))

# 시험: --titletest=new|continue[:찍을 파일.png] — 불러오기가 끝나면 화면을 찍고 그 메뉴를 고른다
func _self_test(spec: String) -> void:
	var p := spec.split(":", true, 1)
	while d.main._loading: await get_tree().process_frame
	for i in 30: await get_tree().process_frame
	if p.size() > 1:
		get_viewport().get_texture().get_image().save_png(d.main._abs(p[1]))
	printerr("TITLE can_continue=%s pick=%s where=%s" % [_can_continue, p[0], JSON.stringify(Progress.where())])
	_pick(0 if p[0] == "new" else 1)

func _hilite() -> void:
	for i in _btns.size():
		_btns[i].add_theme_color_override("font_color", SEAL if i == _sel else INK)

func _unhandled_input(ev: InputEvent) -> void:
	if not active or not (ev is InputEventKey and ev.pressed and not ev.echo): return
	match ev.physical_keycode:
		KEY_UP, KEY_W, KEY_DOWN, KEY_S:
			_sel = 1 - _sel
			if _btns[_sel].disabled: _sel = 1 - _sel
			_hilite()
		KEY_1: _pick(0)
		KEY_2: _pick(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E: _pick(_sel)
	get_viewport().set_input_as_handled()

func _pick(i: int) -> void:
	if not active or _btns[i].disabled: return
	if i == 0: _new_game()
	else: _continue()

func _close() -> void:
	active = false
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)

func _new_game() -> void:
	Progress.reset_all()
	var w = d.main.world
	if w.get("props") != null and w.props.has_method("reset_all"): w.props.reset_all()
	if d.space_id == NAMWON and d.S != null:
		d.S.reset()
		d.on_phase()
		d._started = false   # 다음 프레임에 S0001(여는 화면)
		_close()
		return
	_go(NAMWON, "region", NAMWON_START, { newgame = true, hour = 9.5, title = "남원" })

func _continue() -> void:
	var wh := Progress.where()
	if wh.is_empty() or String(wh.get("space", "")) == d.space_id:
		if not wh.is_empty():
			d.teleport_to([float(wh.x), float(wh.z)])
			d.set_hour(float(wh.get("hour", d.main.hour)))
		_close()
		return
	_go(String(wh.space), String(wh.get("kind", "region")), [float(wh.x), float(wh.z)],
		{ resume_at = [float(wh.x), float(wh.z)], hour = float(wh.get("hour", 10.0)), title = "" })

# 다른 공간으로(region_main._travel과 같은 예약 + 장면 다시 열기)
func _go(space: String, kind: String, at: Array, extra: Dictionary) -> void:
	var dir: String = Travel.find_route_dir(space) if kind == "route" else Travel.region_dir(space)
	if dir == "":
		_close(); return
	var nxt := { kind = kind, id = space, dir = dir, at = Vector2(float(at[0]), float(at[1])), hour = float(extra.get("hour", 10.0)),
		via = "title", title = String(extra.get("title", "")) }
	nxt.merge(extra, true)
	active = false
	Travel.set_pending(nxt)
	d.main._leave.call_deferred()
