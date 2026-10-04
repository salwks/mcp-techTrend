# 시작 메뉴 — 새 게임 / 이어 하기(--newgame 없이 시험할 수 있게). story_director가 그냥 실행했을 때만 띄운다.
#   새 게임: 저장(user://progress.json)을 비우고 남원 S0001부터. 남원에 있으면 그 자리에서, 아니면 남원으로 넘어간다.
#   이어 하기: 가장 새 기록(자동 기록 · 칸 1~3 가운데 남긴 때가 늦은 것 — progress.latest_slot)을 지금 진행으로 놓고 그 자리(progress.where)로.
#     다른 공간이면 그 공간으로 넘어간다(Travel 예약 + resume_at). 버튼 아래 그 기록의 고을 · 사건 · 시각을 작게 보인다.
#   불러오기: 칸을 골라(scripts/story/save_menu.gd) 그 기록으로.
# 모양: 한지 바탕, 오른쪽에 세로로 쓴 큰 제목 「설화록」(덕온공주체 Classic)과 붉은 도장, 왼쪽에 메뉴.
#   설정: 상호작용 안내·조사 도움(scripts/story/options_menu.gd — 놀이 중 Esc와 같은 창).
# 열려 있는 동안 story_director.blocks_move()가 참이라 플레이어·이야기가 멈춘다. ↑↓·W·S·1·2·Enter·E·클릭.
extends CanvasLayer

const Progress := preload("res://scripts/region/progress.gd")
const Travel := preload("res://scripts/region/travel.gd")
const UiFonts := preload("res://scripts/ui_fonts.gd")
const VText := preload("res://scripts/story/vtext.gd")
const JournalView := preload("res://scripts/story/journal_view.gd")
const SaveKeeper := preload("res://scripts/story/save_keeper.gd")
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
var _opts = null   # 열린 설정 창

func _init(director) -> void:
	d = director
	layer = 30
	name = "title_menu"

func _ready() -> void:
	_can_continue = Progress.has_save() or Progress.latest_slot() > 0
	_sel = 1 if _can_continue else 0
	var font := UiFonts.main()
	_root = ColorRect.new()
	_root.color = Color(PAPER.r, PAPER.g, PAPER.b, 0.97)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var deco := Control.new(); deco.set_anchors_preset(Control.PRESET_FULL_RECT); deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(_draw_deco.bind(deco))
	_root.add_child(deco)
	var k: float = maxf(1.0, get_viewport().get_visible_rect().size.y / 768.0)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	box.anchor_left = 0.16; box.anchor_right = 0.5; box.anchor_top = 0.5; box.anchor_bottom = 0.5
	box.offset_top = -170 * k; box.offset_bottom = 190 * k
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(10 * k))
	_root.add_child(box)
	var latest := Progress.latest_slot()
	var info := Progress.slot_info(maxi(latest, 0)) if latest >= 0 else {}
	for i in 4:
		var b := Button.new()
		b.text = ["새 게임", "이어 하기", "불러오기", "설정"][i]
		b.disabled = (i == 1 or i == 2) and not _can_continue
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UiFonts.classic()); b.add_theme_font_size_override("font_size", int(34 * k))
		b.add_theme_color_override("font_color", INK); b.add_theme_color_override("font_hover_color", SEAL)
		b.add_theme_color_override("font_focus_color", SEAL)
		b.add_theme_color_override("font_disabled_color", Color(INK.r, INK.g, INK.b, 0.3))
		b.pressed.connect(_pick.bind(i))
		box.add_child(b)
		_btns.append(b)
		if i == 1 and not info.is_empty():
			var m: Dictionary = info.meta
			var parts := []
			var place := String(m.get("place", info.where.get("space", "")))
			if place != "": parts.append(place)
			if String(m.get("case", "")) != "": parts.append("「%s」" % String(m.case))
			if m.has("hour"): parts.append(SaveKeeper.hour_text(float(m.hour)))
			var sub := Label.new(); sub.text = "      " + "  ·  ".join(parts)
			sub.add_theme_font_override("font", font); sub.add_theme_font_size_override("font_size", int(17 * k))
			sub.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.62))
			box.add_child(sub)
	var keys := Label.new(); keys.text = "↑↓ 고르기 · Enter 정하기"
	keys.add_theme_font_override("font", font); keys.add_theme_font_size_override("font_size", int(15 * k))
	keys.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.5))
	var g := Control.new(); g.custom_minimum_size = Vector2(0, 18 * k); box.add_child(g)
	box.add_child(keys)
	_hilite()
	if d.main.args.has("titletest"): _self_test.call_deferred(String(d.main.args.titletest))

# 오른쪽: 세로 제목 · 부제 · 도장, 한지 결과 바깥 테
func _draw_deco(c: Control) -> void:
	var vs := c.size
	var k: float = maxf(1.0, vs.y / 768.0)
	c.draw_texture_rect(JournalView._hanji_tex(), Rect2(Vector2.ZERO, vs), true, Color(1, 1, 1, 0.9))
	var fr := Rect2(vs * 0.05, vs * 0.9)
	c.draw_rect(fr, Color(INK, 0.75), false, 2.5 * k)
	c.draw_rect(fr.grow(-5 * k), Color(INK, 0.45), false, 1.0 * k)
	var x := vs.x * 0.72
	var fs := 96.0 * k
	var top := vs.y * 0.2
	var len := VText.column(c, UiFonts.classic(), Vector2(x, top), "설화록", fs, INK)
	VText.column(c, UiFonts.main(), Vector2(x - fs * 0.95, top + fs * 0.4), "이름 없는 나그네의 사건 기록", 22.0 * k, Color(INK, 0.7))
	# 붉은 도장(제목 아래)
	var s := 50.0 * k
	var sc := Vector2(x, top + len + s * 0.9)
	c.draw_rect(Rect2(sc - Vector2(s, s) * 0.5, Vector2(s, s)), Color(SEAL, 0.88))
	c.draw_rect(Rect2(sc - Vector2(s, s) * 0.42, Vector2(s, s) * 0.84), Color(PAPER, 0.5), false, 1.5 * k)
	VText.column(c, UiFonts.classic(), sc + Vector2(0, -s * 0.36), "기록", s * 0.34, Color(PAPER, 0.95))
	# 세로 괘선 몇 줄(옛 책 장 느낌)
	for i in 6:
		var lx := x - fs * 1.7 - i * 44.0 * k
		c.draw_line(Vector2(lx, vs.y * 0.12), Vector2(lx, vs.y * 0.88), Color(INK, 0.08), 1.0)

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
	if _opts != null and is_instance_valid(_opts): return
	match ev.physical_keycode:
		KEY_UP, KEY_W, KEY_DOWN, KEY_S:
			var step := -1 if ev.physical_keycode in [KEY_UP, KEY_W] else 1
			_sel = posmod(_sel + step, _btns.size())
			if _btns[_sel].disabled: _sel = posmod(_sel + step, _btns.size())
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
