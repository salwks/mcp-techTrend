# 설정 · 잠시 멈춤 — 시작 메뉴의 '설정'과 놀이 중 Esc(scripts/story/onboarding.gd)가 연다.
#   상호작용 안내(항상/초반만/최소/끔) · 조사 도움(기본/자세히/최소) — 전투 난이도와 상관없다(보강서 §26). user://settings.json.
#   자동 기승 속도(보통/빠름) · 자동 감속(켬/끔) · 이동 카메라 흔들림(보통/약함/끔) — 이동수단 개선안 §31.
#   시점(3인칭/1인칭 — 놀이 중 0 키와 같은 값) · 마우스 감도(1인칭 둘러보기) · 깊이 흐림(보통/약함/끔 — 먼 곳만 조금 흐리게, 2026-10).
#   놀이 중(in_game)이면 화면을 멈추고(get_tree().paused) '계속하기'·'저장'·'불러오기'(scripts/story/save_menu.gd — 칸 셋 + 자동 기록)·'여행 방법'(기록책)도 보인다.
#   Esc를 누른 순간 화면을 작은 그림으로 잡아 둔다(저장 칸 그림).
# 모양: 글 크기는 UiFonts 표(제목 TITLE · 줄 BODY · 덧글 KEYS). 놀이 중에는 두 단 — 왼쪽 할 일(계속·저장·불러오기·여행 방법·닫기·끝내기), 오른쪽 설정.
# 조작: ↑↓·W·S 고르기 · ←→·A·D 바꾸기 · Enter·E·Space 실행 · Esc 닫기 · 클릭.
extends CanvasLayer

const GameSettings := preload("res://scripts/story/game_settings.gd")
const UiFonts := preload("res://scripts/ui_fonts.gd")
const Progress := preload("res://scripts/region/progress.gd")
const PAPER := Color("#efe6d2")
const INK := Color("#2b2622")
const INK_SOFT := Color("#5a5048")
const SEAL := Color("#a8443c")

var in_game := false
var on_help: Callable = Callable()
var on_close: Callable = Callable()
var _rows: Array = []      # [{id, label: Label, kind: "act"|"opt", key, values, names}]
var _sel := 0
var _font: Font
var _was_paused := false

func _init(game := false) -> void:
	in_game = game
	layer = 40
	name = "options_menu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(preload("res://scripts/hud_gate.gd").OVERLAY)   # 열린 동안 지명·안내 HUD를 감춘다

func _ready() -> void:
	_font = UiFonts.main()
	var keeper = _keeper()
	if keeper != null: keeper.thumb = keeper.grab()   # 메뉴가 그려지기 전 화면
	if in_game:
		_was_paused = get_tree().paused
		get_tree().paused = true
	var k: float = UiFonts.k(get_viewport().get_visible_rect().size, 0.8)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.45); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.97); sb.border_color = INK; sb.set_border_width_all(3)
	sb.border_color = Color(INK, 0.8); sb.set_border_width_all(2); sb.shadow_color = Color(0, 0, 0, 0.35); sb.shadow_size = 10
	sb.content_margin_left = 56 * k; sb.content_margin_right = 56 * k; sb.content_margin_top = 37 * k; sb.content_margin_bottom = 37 * k
	p.add_theme_stylebox_override("panel", sb)
	cc.add_child(p)
	# 글 크기는 UiFonts 표(제목 TITLE · 줄 BODY · 덧글 KEYS). 놀이 중에는 줄이 열다섯이라 두 단으로 — 왼쪽 할 일, 오른쪽 설정
	var outer := VBoxContainer.new(); outer.add_theme_constant_override("separation", int(14 * k))
	p.add_child(outer)
	var t := _lab("잠시 멈춤" if in_game else "설정", int(UiFonts.TITLE * k), INK); t.add_theme_font_override("font", UiFonts.classic()); outer.add_child(t)
	var r := ColorRect.new(); r.color = Color(INK, 0.7); r.custom_minimum_size = Vector2((1153 if in_game else 731) * k, 2); outer.add_child(r)
	var cols := HBoxContainer.new(); cols.add_theme_constant_override("separation", int(51 * k))
	outer.add_child(cols)
	var acts := VBoxContainer.new(); acts.add_theme_constant_override("separation", int(14 * k))
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", int(14 * k))
	if in_game:
		cols.add_child(acts)
		var vr := ColorRect.new(); vr.color = Color(INK, 0.25); vr.custom_minimum_size = Vector2(2, 0); cols.add_child(vr)
	cols.add_child(box)
	if in_game: _add(acts, k, { id = "resume", kind = "act", text = "계속하기" })
	if in_game and keeper != null:
		_add(acts, k, { id = "save", kind = "act", text = "저장" })
		_add(acts, k, { id = "load", kind = "act", text = "불러오기" })
	if in_game: _add(acts, k, { id = "howto", kind = "act", text = "여행 방법" })
	_add(box, k, { id = "guide", kind = "opt", key = "guide", values = GameSettings.GUIDE, names = GameSettings.GUIDE_LABEL, text = "상호작용 안내" })
	_add(box, k, { id = "help", kind = "opt", key = "help", values = GameSettings.HELP, names = GameSettings.HELP_LABEL, text = "조사 도움" })
	_add(box, k, { id = "ride_speed", kind = "opt", key = "ride_speed", values = GameSettings.RIDE_SPEED, names = GameSettings.RIDE_SPEED_LABEL, text = "자동 기승 속도" })
	_add(box, k, { id = "ride_slow", kind = "opt", key = "ride_slow", values = GameSettings.RIDE_SLOW, names = GameSettings.RIDE_SLOW_LABEL, text = "자동 감속" })
	_add(box, k, { id = "cam_shake", kind = "opt", key = "cam_shake", values = GameSettings.CAM_SHAKE, names = GameSettings.CAM_SHAKE_LABEL, text = "이동 카메라 흔들림" })
	_add(box, k, { id = "view", kind = "opt", key = "view", values = GameSettings.VIEW, names = GameSettings.VIEW_LABEL, text = "시점 (0 키)" })
	_add(box, k, { id = "mouse_sens", kind = "opt", key = "mouse_sens", values = GameSettings.MOUSE_SENS, names = GameSettings.MOUSE_SENS_LABEL, text = "마우스 감도 (1인칭)" })
	_add(box, k, { id = "dof", kind = "opt", key = "dof", values = GameSettings.DOF, names = GameSettings.DOF_LABEL, text = "깊이 흐림" })
	_add(box, k, { id = "vol_master", kind = "opt", key = "vol_master", values = GameSettings.VOLUME, names = GameSettings.VOLUME_LABEL, text = "소리 — 전체" })
	_add(box, k, { id = "vol_bgm", kind = "opt", key = "vol_bgm", values = GameSettings.VOLUME, names = GameSettings.VOLUME_LABEL, text = "소리 — 음악" })
	_add(box, k, { id = "vol_sfx", kind = "opt", key = "vol_sfx", values = GameSettings.VOLUME, names = GameSettings.VOLUME_LABEL, text = "소리 — 효과음" })
	_add(acts if in_game else box, k, { id = "close", kind = "act", text = "돌아가기" if not in_game else "닫기" })
	if in_game: _add(acts, k, { id = "quit", kind = "act", text = "게임 끝내기" })
	var note := _lab("조사 도움은 전투 난이도와 상관없다." + ("  ·  0 — 1인칭/3인칭 바꾸기" if in_game else ""), int(UiFonts.KEYS * k), INK_SOFT); outer.add_child(note)
	var keys := _lab("↑↓ 고르기 · ←→ 바꾸기 · Enter 실행 · Esc 닫기", int(UiFonts.KEYS * k), INK_SOFT); outer.add_child(keys)
	if not in_game: acts.free()   # 시작 메뉴 설정: 왼쪽 단을 쓰지 않는다(나무에 달지 않은 채 남기면 끝낼 때 샌다)
	_refresh()

func _lab(text: String, size: int, col: Color) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_override("font", _font); l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _add(box: VBoxContainer, k: float, spec: Dictionary) -> void:
	var l := _lab("", int(UiFonts.BODY * k), INK)
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	var i := _rows.size()
	l.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_sel = i
			if spec.kind == "opt": _change(1)
			else: _act())
	box.add_child(l)
	spec.label = l
	_rows.append(spec)

func _refresh() -> void:
	for i in _rows.size():
		var rw: Dictionary = _rows[i]
		var on := i == _sel
		var txt := String(rw.text)
		if rw.kind == "opt":
			var v := GameSettings.get_v(String(rw.key))
			txt = "%s   ◀ %s ▶" % [txt, String(rw.names.get(v, v))]
		(rw.label as Label).text = ("▸ " if on else "   ") + txt
		(rw.label as Label).add_theme_color_override("font_color", SEAL if on else INK)

func _change(dir: int) -> void:
	var rw: Dictionary = _rows[_sel]
	if rw.kind != "opt": return
	var vals: Array = rw.values
	var cur := vals.find(GameSettings.get_v(String(rw.key)))
	GameSettings.set_v(String(rw.key), String(vals[posmod(cur + dir, vals.size())]))
	if String(rw.key).begins_with("vol_"):
		preload("res://scripts/audio/sound.gd").apply_settings()
		preload("res://scripts/audio/sound.gd").play("ui_select")
	_refresh()

func _act() -> void:
	match String(_rows[_sel].id):
		"resume", "close": close()
		"quit":
			var rw: Dictionary = _rows[_sel]
			if not bool(rw.get("armed", false)):   # 한 번 더 눌러 확인
				rw.armed = true; rw.text = "한 번 더 — 기록하고 끝낸다"; _refresh(); return
			Progress.checkpoint("quit")
			get_tree().paused = false
			var m := get_tree().current_scene
			if m != null and m.has_method("_quit"): m._quit()
			else: get_tree().quit()
		"howto":
			close()
			if on_help.is_valid(): on_help.call()
		"save", "load":
			var keeper = _keeper()
			if keeper == null: return
			visible = false
			keeper.open_slots(String(_rows[_sel].id), func(): if is_instance_valid(self): visible = true)

func _keeper():
	var p := get_parent()
	return p.get_node_or_null("save_keeper") if p != null else null

func close() -> void:
	if in_game: get_tree().paused = _was_paused
	if on_close.is_valid(): on_close.call()
	queue_free()

func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo) or not visible: return
	match ev.physical_keycode:
		KEY_UP, KEY_W: _sel = posmod(_sel - 1, _rows.size()); _refresh()
		KEY_DOWN, KEY_S: _sel = posmod(_sel + 1, _rows.size()); _refresh()
		KEY_LEFT, KEY_A: _change(-1)
		KEY_RIGHT, KEY_D: _change(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
			if _rows[_sel].kind == "opt": _change(1)
			else: _act()
		KEY_ESCAPE: close()
		_: return
	get_viewport().set_input_as_handled()
