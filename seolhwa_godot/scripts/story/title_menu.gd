# 시작 메뉴 — 새 게임 / 이어 하기(--newgame 없이 시험할 수 있게). story_director가 그냥 실행했을 때만 띄운다.
#   새 게임: 저장(user://progress.json)을 비우고 남원 S0001부터. 남원에 있으면 그 자리에서, 아니면 남원으로 넘어간다.
#   이어 하기: 가장 새 기록(자동 기록 · 칸 1~3 가운데 남긴 때가 늦은 것 — progress.latest_slot)을 지금 진행으로 놓고 그 자리(progress.where)로.
#     다른 공간이면 그 공간으로 넘어간다(Travel 예약 + resume_at). 버튼 아래 그 기록의 고을 · 사건 · 시각을 작게 보인다.
#   불러오기: 칸을 골라(scripts/story/save_menu.gd) 그 기록으로.
#   설정: 상호작용 안내·조사 도움(scripts/story/options_menu.gd — 놀이 중 Esc와 같은 창).
# 바탕: 움직이는 배경(scripts/ui/title_wallpaper.gd — 강 물결·안개·선비 족자·소나무 바람·꽃잎·학). 그림 속에 「설화록」 로고(오른쪽 위)가
#   있으므로 제목을 따로 그리지 않는다. 메뉴가 닫히면(queue_free) 바탕도 함께 풀린다.
# 메뉴 자리(2026-10-13 세 후보 비교 — docs/reports/resolution-1080-title-art.md): 아래 물 띠에 가로 한 줄(LAYOUT "row").
#   로고(오른쪽 위)·선비와 족자(왼쪽)·학·마을(가운데~오른쪽)을 가리지 않고 잔잔한 물 위를 비워 둔다. 글 뒤에 옅은 한지 번짐(물빛 위에서 먹 글이 읽히게).
#   고른 항목: 붉은 글 · 붓 밑줄 · 앞의 붉은 도장. 마우스를 올리면 그 항목이 골라진다.
#   시험·촬영: --titlelayout=water|row|panel(후보 비교), --titletest=new|continue|shot[:찍을 파일.png].
# 열려 있는 동안 story_director.blocks_move()가 참이라 플레이어·이야기가 멈춘다. ↑↓·W·S·1~4·Enter·E·클릭.
extends CanvasLayer

const Progress := preload("res://scripts/region/progress.gd")
const Travel := preload("res://scripts/region/travel.gd")
const UiFonts := preload("res://scripts/ui_fonts.gd")
const SaveKeeper := preload("res://scripts/story/save_keeper.gd")
const TitleWallpaper := preload("res://scripts/ui/title_wallpaper.gd")
const PAPER := Color("#efe6d2")
const INK := Color("#2b2622")
const SEAL := Color("#a8443c")
const NAMWON := "JL_NAMWON_UNBONG"
const NAMWON_START := [-2952.0, 184.0]
# 후보 자리(바탕 캔버스 0~1 좌표 — 덮기로 잘려도 그림의 같은 곳을 따라간다)
#   water: 오른쪽 아래 물 위 세로 줄(오른쪽 맞춤) · row: 아래 물 띠 가로 한 줄 · panel: 오른쪽 아래 한지 판 안 세로 줄
const LAYOUT_DEFAULT := "row"

var d
var active := true
var _sel := 0
var _btns: Array = []
var _can_continue := false
var _root: Control
var _opts = null   # 열린 설정 창
var _wp: TitleWallpaper
var _box: BoxContainer
var _fx: Control
var _sub: Label = null
var _keys: Label
var _layout := LAYOUT_DEFAULT

func _init(director) -> void:
	d = director
	layer = 30
	name = "title_menu"
	add_to_group(preload("res://scripts/hud_gate.gd").OVERLAY)

func _ready() -> void:
	_can_continue = Progress.has_save() or Progress.latest_slot() > 0
	_sel = 1 if _can_continue else 0
	if d.main.args.has("titlelayout"): _layout = String(d.main.args.titlelayout)
	var font := UiFonts.main()
	_root = ColorRect.new()
	_root.color = Color("#cfd6d0")   # 바탕 그림이 덮는다(그림을 못 읽을 때만 보이는 옅은 물빛)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_wp = TitleWallpaper.new()
	_root.add_child(_wp)
	var k: float = UiFonts.k(get_viewport().get_visible_rect().size, 1.0)
	_fx = Control.new(); _fx.set_anchors_preset(Control.PRESET_FULL_RECT); _fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	_root.add_child(_fx)
	_box = HBoxContainer.new() if _layout == "row" else VBoxContainer.new()
	_box.add_theme_constant_override("separation", int((36 if _layout == "row" else 0) * k))
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(_box)
	var latest := Progress.latest_slot()
	var info := Progress.slot_info(maxi(latest, 0)) if latest >= 0 else {}
	for i in 5:
		var b := Button.new()
		b.text = ["새 게임", "이어 하기", "불러오기", "설정", "그만하기"][i]
		b.disabled = (i == 1 or i == 2) and not _can_continue
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT if _layout == "water" else (HORIZONTAL_ALIGNMENT_CENTER if _layout == "row" else HORIZONTAL_ALIGNMENT_LEFT)
		b.add_theme_font_override("font", UiFonts.classic()); b.add_theme_font_size_override("font_size", int((UiFonts.NAME if _layout == "row" else UiFonts.HEAD) * k))   # 가로 줄은 NAME(물 띠 안에 다섯이 들게)
		b.add_theme_color_override("font_color", INK); b.add_theme_color_override("font_hover_color", SEAL)
		b.add_theme_color_override("font_pressed_color", SEAL); b.add_theme_color_override("font_focus_color", SEAL)
		b.add_theme_color_override("font_disabled_color", Color(INK.r, INK.g, INK.b, 0.34))
		b.add_theme_color_override("font_outline_color", Color(PAPER, 0.85)); b.add_theme_constant_override("outline_size", int(8 * k))
		b.pressed.connect(_pick.bind(i))
		b.mouse_entered.connect(_hover.bind(i))
		_box.add_child(b)
		_btns.append(b)
		if i == 1 and not info.is_empty():
			var m: Dictionary = info.meta
			var parts := []
			var place := String(m.get("place", info.where.get("space", "")))
			if place != "": parts.append(place)
			if String(m.get("case", "")) != "": parts.append("「%s」" % String(m.case))
			if m.has("hour"): parts.append(SaveKeeper.hour_text(float(m.hour)))
			_sub = Label.new(); _sub.text = "  ·  ".join(parts)
			_sub.add_theme_font_override("font", font); _sub.add_theme_font_size_override("font_size", int(UiFonts.DETAIL * k))
			_sub.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.78))
			_sub.add_theme_color_override("font_outline_color", Color(PAPER, 0.85)); _sub.add_theme_constant_override("outline_size", int(6 * k))
			_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if _layout == "row": _root.add_child(_sub)
			else:
				_sub.horizontal_alignment = b.alignment
				_box.add_child(_sub)
	_keys = Label.new(); _keys.text = ("←→" if _layout == "row" else "↑↓") + " 고르기 · Enter 정하기"
	_keys.add_theme_font_override("font", font); _keys.add_theme_font_size_override("font_size", int(UiFonts.KEYS * k))
	_keys.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.72))
	_keys.add_theme_color_override("font_outline_color", Color(PAPER, 0.85)); _keys.add_theme_constant_override("outline_size", int(6 * k))
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_keys)
	_root.resized.connect(_place)
	_box.sort_children.connect(_fx.queue_redraw)
	_place.call_deferred()
	_hilite()
	if d.main.args.has("titletest"): _self_test.call_deferred(String(d.main.args.titletest))

# 자리: 바탕 캔버스 좌표(0~1)를 화면으로 옮겨 놓는다(창 비율이 바뀌어도 그림의 같은 물 위)
func _place() -> void:
	if _wp == null: return
	_wp.fit()
	var k: float = UiFonts.k(get_viewport().get_visible_rect().size, 1.0)
	_box.reset_size()
	var bs := _box.get_combined_minimum_size()
	var kh := _keys.get_combined_minimum_size()
	match _layout:
		"row":
			var c := _wp.to_screen(Vector2(0.748, 0.9))
			_box.size = bs; _box.position = Vector2(c.x - bs.x * 0.5, c.y - bs.y * 0.5)
			if _sub != null:
				_sub.reset_size()
				var b1: Rect2 = Rect2(_box.position + _btns[1].position, _btns[1].size)
				_sub.position = Vector2(b1.get_center().x - _sub.size.x * 0.5, b1.end.y + 2 * k)
			_keys.position = Vector2(_box.position.x + bs.x - kh.x, _wp.to_screen(Vector2(0, 0.975)).y - kh.y)
		"panel":
			var a := _wp.to_screen(Vector2(0.70, 0.60))
			_box.size = bs; _box.position = a
			_keys.position = Vector2(a.x, a.y + bs.y + 12 * k)
		_:   # water: 오른쪽 아래 물 위, 오른쪽 맞춤(로고 오른쪽 끝과 같은 세로 줄)
			var r := _wp.to_screen(Vector2(0.905, 0.625))
			_box.size = bs; _box.position = Vector2(r.x - bs.x, r.y)
			_keys.position = Vector2(r.x - kh.x, minf(r.y + bs.y + 14 * k, get_viewport().get_visible_rect().size.y - kh.y - 10 * k))
	_keys.size = kh
	_fx.queue_redraw()

# 글 뒤 옅은 한지 번짐 · (panel) 한지 판 · 고른 줄: 붓 밑줄 + 붉은 도장
func _draw_fx() -> void:
	if _box == null or _btns.is_empty(): return
	var k: float = UiFonts.k(_fx.size, 1.0)
	var r := Rect2(_box.position, _box.size)
	if _keys != null: r = r.merge(Rect2(_keys.position, _keys.size))
	if _layout == "panel":
		var pr := r.grow_individual(40 * k, 30 * k, 40 * k, 26 * k)
		_fx.draw_rect(pr, Color(PAPER, 0.84))
		_fx.draw_rect(pr, Color(INK, 0.55), false, 2.0 * k)
		_fx.draw_rect(pr.grow(-7 * k), Color(INK, 0.25), false, 1.0 * k)
	else:
		# 가장자리로 사라지는 타원 번짐 몇 겹
		var c := r.get_center(); var hs := r.size * 0.5 + Vector2(90, 60) * k
		for i in 6:
			var t := float(i) / 6.0
			_ellipse(c, hs * (1.0 - t * 0.45), Color(PAPER, 0.10 + t * 0.05))
	var b: Button = _btns[_sel]
	var br := Rect2(_box.position + b.position, b.size)
	var f := UiFonts.classic()
	var fs := b.get_theme_font_size("font_size")
	var tw := f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0 := br.position.x + (br.size.x - tw) * (1.0 if b.alignment == HORIZONTAL_ALIGNMENT_RIGHT else (0.5 if b.alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0))
	if b.alignment == HORIZONTAL_ALIGNMENT_RIGHT: x0 -= 8 * k   # Button 안쪽 여백
	elif b.alignment == HORIZONTAL_ALIGNMENT_LEFT: x0 += 8 * k
	var y := br.end.y - 7.0 * k
	# 붓 밑줄: 앞이 굵고 끝이 가늘게 빠지는 먹 한 획
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var u := float(i) / n
		pts.append(Vector2(x0 - 6 * k + (tw + 14 * k) * u, y + sin(u * PI) * -3.0 * k + u * 2.0 * k))
	for i in n:
		var u := float(i) / n
		_fx.draw_line(pts[i], pts[i + 1], Color(INK, 0.8), lerpf(5.5, 1.4, u) * k, true)
	# 붉은 도장(글 앞) — 가로 줄은 앞 항목과 붙어 버려 밑줄·붉은 글만
	if _layout == "row": return
	var s := 18.0 * k
	var sc := Vector2(x0 - 22 * k, br.get_center().y)
	_fx.draw_rect(Rect2(sc - Vector2(s, s) * 0.5, Vector2(s, s)), Color(SEAL, 0.92))
	_fx.draw_rect(Rect2(sc - Vector2(s, s) * 0.32, Vector2(s, s) * 0.64), Color(PAPER, 0.55), false, 1.4 * k)

func _ellipse(c: Vector2, hs: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * hs.x, sin(a) * hs.y))
	_fx.draw_colored_polygon(pts, col)

# 메뉴가 화면을 다 덮는 동안 뒤 3D 장면은 그리지 않는다(불러오기가 끝난 뒤 — 불러오기 중에는 region_main이 정한다). 닫히거나 풀리면 되돌린다
func _process(_dt: float) -> void:
	var vp: SubViewport = d.main.get("scene_vp")
	if vp == null or d.main._loading: return
	var want := SubViewport.UPDATE_DISABLED if active and _root.modulate.a > 0.99 else SubViewport.UPDATE_ALWAYS
	if vp.render_target_update_mode != want: vp.render_target_update_mode = want

func _exit_tree() -> void:
	var vp: SubViewport = d.main.get("scene_vp")
	if vp != null and is_instance_valid(vp) and not d.main._loading: vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _hover(i: int) -> void:
	if not active or _btns[i].disabled or i == _sel: return
	_sel = i
	_hilite()

# 시험: --titletest=new|continue|shot[:찍을 파일.png] — 불러오기가 끝나면 화면을 찍고 그 메뉴를 고른다(shot: 찍고 끝낸다)
func _self_test(spec: String) -> void:
	var p := spec.split(":", true, 1)
	while d.main._loading: await get_tree().process_frame
	for i in 30: await get_tree().process_frame
	if p.size() > 1:
		get_viewport().get_texture().get_image().save_png(d.main._abs(p[1]))
	if p[0] == "shot":
		printerr("TITLE shot ", p[1] if p.size() > 1 else "")
		d.main._quit(); return
	if p[0] == "frames":   # 움직임 확인: 1.5초마다 네 장(<파일>_0~3.png)
		for f in 4:
			for i in 90: await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(d.main._abs(p[1].get_basename() + "_%d.png" % f))
		printerr("TITLE frames %s fps=%.0f" % [p[1], Engine.get_frames_per_second()])
		d.main._quit(); return
	printerr("TITLE can_continue=%s pick=%s where=%s" % [_can_continue, p[0], JSON.stringify(Progress.where())])
	_pick(0 if p[0] == "new" else 1)

func _hilite() -> void:
	for i in _btns.size():
		_btns[i].add_theme_color_override("font_color", SEAL if i == _sel else INK)
	if _fx != null: _fx.queue_redraw()

func _unhandled_input(ev: InputEvent) -> void:
	if not active or not (ev is InputEventKey and ev.pressed and not ev.echo): return
	if _opts != null and is_instance_valid(_opts): return
	match ev.physical_keycode:
		KEY_UP, KEY_W, KEY_DOWN, KEY_S, KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D:
			var step := -1 if ev.physical_keycode in [KEY_UP, KEY_W, KEY_LEFT, KEY_A] else 1
			for _n in _btns.size():
				_sel = posmod(_sel + step, _btns.size())
				if not _btns[_sel].disabled: break
			_hilite()
		KEY_1: _pick(0)
		KEY_2: _pick(1)
		KEY_3: _pick(2)
		KEY_4: _pick(3)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E: _pick(_sel)
	get_viewport().set_input_as_handled()

func _pick(i: int) -> void:
	if not active or _btns[i].disabled: return
	if i == 0: _new_game()
	elif i == 1:
		var n := Progress.latest_slot()
		_continue(n > 0 and Progress.load_slot(n))
	elif i == 2:
		_opts = load("res://scripts/story/save_menu.gd").new("load", null)
		_opts.on_load = func(n: int) -> bool:
			if not Progress.load_slot(n): return false
			_continue(true)
			return true
		add_child(_opts)
	elif i == 4:
		if d.main.has_method("_quit"): d.main._quit()
		else: get_tree().quit()
	else:
		_opts = load("res://scripts/story/options_menu.gd").new(false)
		add_child(_opts)

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

# reload: 칸 기록을 방금 지금 진행으로 놓았다 — 같은 공간이라도 장면을 다시 열어 사건 상태를 새로 읽는다
func _continue(reload := false) -> void:
	var wh := Progress.where()
	if reload and not wh.is_empty():
		_go(String(wh.space), String(wh.get("kind", "region")), [float(wh.x), float(wh.z)],
			{ resume_at = [float(wh.x), float(wh.z)], hour = float(wh.get("hour", 10.0)), title = "", via = "load" })
		return
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
