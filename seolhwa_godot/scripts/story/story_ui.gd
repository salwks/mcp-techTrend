# 이야기 UI — 한지·먹 결(웹 src/ui 대응). 대화 상자, 조사 카드, 선택지, 자막, 위아래 먹 띠(레터박스), 알림 띠,
# 사건 기록 책자(R), 사건 종결 카드, 소지품 표시, 조사 안내, 전투 HUD(체력·기력 붓 게이지, 호랑이 체력, 화살·떡, 상황 문구).
# 비동기 API(await): say(이름, [줄]) · examine(제목, 글, 종류) · choice(물음, [{label, disabled, hint}]) → 번호 ·
#   caption(글, 초) · fade(검게?, 초) · ending(data). 즉시: letterbox(on) · toast(글, 종류) · prompt(글) · items(목록) ·
#   journal_toggle(data) · hud_*.
# 확인: E·Space·Enter·클릭 / 선택: ↑↓·W·S·숫자 / 기록: R / 닫기: Esc. 시험(auto)에서는 스스로 넘긴다.
extends CanvasLayer

signal _confirm
signal _picked(i: int)

const PAPER := Color("#efe6d2")
const PAPER_D := Color("#e2d6bb")
const INK := Color("#2b2622")
const INK_SOFT := Color("#5a5048")
const SEAL := Color("#a8443c")
const KIND_COL := { info = Color("#7a6e60"), clue = Color("#2b2622"), rule = Color("#a8443c"), journal = Color("#a8443c"), item = Color("#6b5a3a") }
const KIND_TAG := { clue = "단서", rule = "버릇", journal = "기록", item = "소지품" }

var auto := false                  # 시험: 대화·카드를 스스로 넘기고 선택은 auto_choice로
var auto_choice: Callable = Callable()   # (물음, [label]) → 번호
var log_lines := true              # 대사·선택을 표준 출력에 남긴다(시험 기록)
var modal := false
var journal_open := false
var _k := 1.0
var _font: SystemFont
var _root: Control
var _dialog: PanelContainer
var _dlg_name: Label
var _dlg_text: Label
var _dlg_hint: Label
var _caption: Label
var _lb_top: ColorRect
var _lb_bot: ColorRect
var _fade: ColorRect
var _toasts: VBoxContainer
var _card: PanelContainer
var _card_title: Label
var _card_tag: Label
var _card_text: Label
var _choice: PanelContainer
var _choice_prompt: Label
var _choice_list: VBoxContainer
var _choice_btns := []
var _choice_sel := 0
var _journal: PanelContainer
var _journal_body: VBoxContainer
var _ending: ColorRect
var _end_box: VBoxContainer
var _items: Label
var _prompt: Label
var _hud: Control
var _hp_bar: ProgressBar
var _st_bar: ProgressBar
var _foe_box: VBoxContainer
var _foe_name: Label
var _foe_bar: ProgressBar
var _ammo: Label
var _hud_say: Label
var _hud_say_t := 0.0
var _keys_hint: Label
var _cap_tween: Tween
var _waiting := ""                 # 지금 기다리는 것: say | card | choice | ending
var _typing := false
var _type_t := 0.0
var _type_full := ""
var _cooldown := 0.0

func _ready() -> void:
	layer = 8
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["AppleMyungjo", "Nanum Myeongjo", "NanumMyeongjo", "Batang", "Noto Serif CJK KR", "Apple SD Gothic Neo"])
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build()
	_resize()
	get_viewport().size_changed.connect(_resize)

# ---------------------------------------------------------------------------
# 만들기
# ---------------------------------------------------------------------------
func _label(size: int, col := INK, outline := false) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _font)
	l.set_meta("base", size)
	l.add_theme_font_size_override("font_size", int(size * _k))
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.035))
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
		l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _paper(alpha := 0.96, border := 2, pad := 18) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, alpha)
	sb.border_color = INK
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.25); sb.shadow_size = 6; sb.shadow_offset = Vector2(2, 3)
	sb.content_margin_left = pad; sb.content_margin_right = pad; sb.content_margin_top = pad * 0.7; sb.content_margin_bottom = pad * 0.7
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _bar(col: Color, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.75); bg.border_color = INK; bg.set_border_width_all(2)
	bg.set_corner_radius_all(2)
	var fg := StyleBoxFlat.new(); fg.bg_color = col; fg.set_corner_radius_all(2)
	fg.skew = Vector2(-0.25, 0)   # 붓 획처럼 끝을 비스듬히
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func _build() -> void:
	# 위아래 먹 띠
	_lb_top = ColorRect.new(); _lb_top.color = Color(0.06, 0.05, 0.045); _lb_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lb_bot = ColorRect.new(); _lb_bot.color = Color(0.06, 0.05, 0.045); _lb_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_lb_top); _root.add_child(_lb_bot)
	# 자막
	_caption = _label(28, Color(1, 1, 1), true)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.modulate.a = 0.0
	_root.add_child(_caption)
	# 조사 안내
	_prompt = _label(22, Color(1, 1, 1), true)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_prompt)
	# 소지품
	_items = _label(18, Color(1, 1, 1), true)
	_items.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_items)
	# 알림 띠
	_toasts = VBoxContainer.new(); _toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	_root.add_child(_toasts)
	# 대화 상자
	_dialog = _paper(0.95)
	var dv := VBoxContainer.new(); dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg_name = _label(22, SEAL)
	_dlg_text = _label(26, INK)
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_hint = _label(16, INK_SOFT); _dlg_hint.text = "▸ E"
	_dlg_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dv.add_child(_dlg_name); dv.add_child(_dlg_text); dv.add_child(_dlg_hint)
	_dialog.add_child(dv)
	_dialog.visible = false
	_root.add_child(_dialog)
	# 선택지
	_choice = _paper(0.96)
	var cv := VBoxContainer.new(); cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_theme_constant_override("separation", 6)
	_choice_prompt = _label(20, INK_SOFT)
	_choice_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choice_list = VBoxContainer.new(); _choice_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_list.add_theme_constant_override("separation", 4)
	cv.add_child(_choice_prompt); cv.add_child(_choice_list)
	_choice.add_child(cv)
	_choice.visible = false
	_root.add_child(_choice)
	# 조사 카드
	_card = _paper(0.98, 3, 28)
	var kv := VBoxContainer.new(); kv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kv.add_theme_constant_override("separation", 10)
	var head := HBoxContainer.new(); head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_title = _label(32, INK); _card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_tag = _label(18, SEAL)
	head.add_child(_card_title); head.add_child(_card_tag)
	var rule := ColorRect.new(); rule.color = INK; rule.custom_minimum_size = Vector2(0, 2); rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_text = _label(23, INK); _card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ok := _label(17, INK_SOFT); ok.text = "확인  E"; ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kv.add_child(head); kv.add_child(rule); kv.add_child(_card_text); kv.add_child(ok)
	_card.add_child(kv)
	_card.visible = false
	_root.add_child(_card)
	# 사건 기록
	_journal = _paper(0.98, 3, 30)
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	_journal_body = VBoxContainer.new(); _journal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journal_body.add_theme_constant_override("separation", 8)
	sc.add_child(_journal_body)
	_journal.add_child(sc)
	_journal.visible = false
	_root.add_child(_journal)
	# 전투 HUD
	_hud = Control.new(); _hud.set_anchors_preset(Control.PRESET_FULL_RECT); _hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.visible = false
	_root.add_child(_hud)
	var pv := VBoxContainer.new(); pv.name = "pv"; pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_theme_constant_override("separation", 4)
	var pn := _label(18, Color(1, 1, 1), true); pn.text = "나그네"
	_hp_bar = _bar(Color("#9a3a2c"), 16)
	_st_bar = _bar(Color("#3a3430"), 9)
	pv.add_child(pn); pv.add_child(_hp_bar); pv.add_child(_st_bar)
	_hud.add_child(pv)
	_foe_box = VBoxContainer.new(); _foe_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foe_name = _label(22, Color(1, 1, 1), true); _foe_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_foe_bar = _bar(Color("#2b2622"), 12)
	_foe_box.add_child(_foe_name); _foe_box.add_child(_foe_bar)
	_hud.add_child(_foe_box)
	_ammo = _label(20, Color(1, 1, 1), true)
	_hud.add_child(_ammo)
	_hud_say = _label(26, Color(1, 1, 1), true); _hud_say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_child(_hud_say)
	_keys_hint = _label(16, Color(1, 1, 1, 0.85), true)
	_keys_hint.text = "J 베기(길게: 모아 베기) · K 구르기 · L 막기 · I 활 · U 떡 · Shift 달리기"
	_hud.add_child(_keys_hint)
	# 종결 카드
	_ending = ColorRect.new(); _ending.color = Color(PAPER.r, PAPER.g, PAPER.b, 0.97)
	_ending.set_anchors_preset(Control.PRESET_FULL_RECT); _ending.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_box = VBoxContainer.new(); _end_box.add_theme_constant_override("separation", 14)
	_end_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ending.add_child(_end_box)
	_ending.visible = false
	_root.add_child(_ending)
	# 페이드(맨 위)
	_fade = ColorRect.new(); _fade.color = Color(0, 0, 0, 0); _fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

func _resize() -> void:
	var vs := get_viewport().get_visible_rect().size
	_k = clampf(vs.y / 768.0, 0.8, 2.4)
	var k := _k
	for l in _root.find_children("*", "Label", true, false):
		if not l.has_meta("base"): continue
		l.add_theme_font_size_override("font_size", int(float(l.get_meta("base")) * k))
	var lbh := vs.y * 0.09
	_lb_top.position = Vector2(0, -lbh if _lb_top.get_meta("on", false) == false else 0.0); _lb_top.size = Vector2(vs.x, lbh)
	_lb_bot.position = Vector2(0, vs.y if _lb_bot.get_meta("on", false) == false else vs.y - lbh); _lb_bot.size = Vector2(vs.x, lbh)
	var w := minf(vs.x * 0.82, 980.0 * k)
	_dialog.position = Vector2((vs.x - w) / 2, vs.y - 220 * k); _dialog.size = Vector2(w, 170 * k); _dialog.custom_minimum_size = Vector2(w, 150 * k)
	_caption.position = Vector2(vs.x * 0.1, vs.y * 0.74); _caption.size = Vector2(vs.x * 0.8, 120 * k)
	_prompt.position = Vector2(0, vs.y - 60 * k); _prompt.size = Vector2(vs.x, 40 * k)
	_items.position = Vector2(vs.x - 520 * k, vs.y - 44 * k); _items.size = Vector2(500 * k, 36 * k)
	_toasts.position = Vector2(24 * k, 70 * k); _toasts.size = Vector2(560 * k, 300 * k)
	var cw := minf(vs.x * 0.7, 640 * k)
	_choice.position = Vector2((vs.x - cw) / 2, vs.y * 0.5); _choice.custom_minimum_size = Vector2(cw, 0); _choice.size = Vector2(cw, 0)
	var kw := minf(vs.x * 0.8, 620 * k)
	_card.custom_minimum_size = Vector2(kw, 0); _card.size = Vector2(kw, 0)
	_card.position = Vector2((vs.x - kw) / 2, vs.y * 0.22)
	_journal.position = Vector2(vs.x * 0.1, vs.y * 0.07); _journal.size = Vector2(vs.x * 0.8, vs.y * 0.86)
	(_journal.get_child(0) as Control).custom_minimum_size = Vector2(vs.x * 0.8 - 70 * k, vs.y * 0.86 - 50 * k)
	_end_box.position = Vector2(vs.x * 0.2, vs.y * 0.16); _end_box.size = Vector2(vs.x * 0.6, vs.y * 0.7)
	var pv: Control = _hud.get_node("pv")
	pv.position = Vector2(24 * k, 20 * k); pv.size = Vector2(300 * k, 60 * k)
	_hp_bar.custom_minimum_size = Vector2(280 * k, 16 * k); _st_bar.custom_minimum_size = Vector2(280 * k, 9 * k)
	_foe_box.position = Vector2(vs.x * 0.3, 18 * k); _foe_box.size = Vector2(vs.x * 0.4, 50 * k)
	_ammo.position = Vector2(24 * k, vs.y - 50 * k); _ammo.size = Vector2(400 * k, 36 * k)
	_hud_say.position = Vector2(vs.x * 0.15, vs.y * 0.62); _hud_say.size = Vector2(vs.x * 0.7, 80 * k)
	_keys_hint.position = Vector2(vs.x * 0.3, vs.y - 32 * k); _keys_hint.size = Vector2(vs.x * 0.68, 28 * k)
	_keys_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

# ---------------------------------------------------------------------------
# 입력
# ---------------------------------------------------------------------------
func _input(ev: InputEvent) -> void:
	var key: bool = ev is InputEventKey and ev.pressed and not ev.echo
	var click: bool = ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT
	if not (key or click): return
	var kc: int = ev.physical_keycode if key else 0
	if journal_open:
		if kc in [KEY_R, KEY_ESCAPE, KEY_E]:
			journal_close(); get_viewport().set_input_as_handled()
		return
	if _waiting == "": return
	if _waiting == "choice":
		if kc in [KEY_UP, KEY_W]: _move_sel(-1)
		elif kc in [KEY_DOWN, KEY_S]: _move_sel(1)
		elif kc >= KEY_1 and kc <= KEY_9 and kc - KEY_1 < _choice_btns.size(): _pick(kc - KEY_1)
		elif kc in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]: _pick(_choice_sel)
		get_viewport().set_input_as_handled()
		return
	if click or kc in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		if _waiting == "say" and _typing:
			_typing = false; _dlg_text.visible_ratio = 1.0
			return
		_confirm.emit()

func _process(dt: float) -> void:
	if _cooldown > 0.0: _cooldown -= dt
	if _typing:
		_type_t += dt
		var n := int(_type_t * 45.0)
		if n >= _type_full.length():
			_typing = false; _dlg_text.visible_ratio = 1.0
		else: _dlg_text.visible_characters = n
	if _hud_say_t > 0.0:
		_hud_say_t -= dt
		_hud_say.modulate.a = clampf(_hud_say_t / 0.4, 0.0, 1.0)
	for t in _toasts.get_children():
		var left: float = float(t.get_meta("t", 0.0)) - dt
		t.set_meta("t", left)
		t.modulate.a = clampf(left / 0.6, 0.0, 1.0)
		if left <= 0.0: t.queue_free()

# 다른 입력(조사 E 등)이 방금 대화를 닫은 키를 다시 쓰지 않게
func busy_input() -> bool:
	return modal or journal_open or _cooldown > 0.0

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

# ---------------------------------------------------------------------------
# 대화·카드·선택
# ---------------------------------------------------------------------------
func say(who: String, lines) -> void:
	if lines is String: lines = [lines]
	modal = true
	_dialog.visible = true
	_dlg_name.text = who
	_dlg_name.visible = who != ""
	for line in lines:
		if log_lines: printerr("SAY %s: %s" % [who, line])
		_dlg_text.text = line
		_type_full = line
		_dlg_text.visible_characters = 0
		_typing = true; _type_t = 0.0
		_waiting = "say"
		if auto: await _wait(0.03)
		else: await _confirm
		_typing = false
	_waiting = ""
	_dialog.visible = false
	modal = false
	_cooldown = 0.15

func examine(title: String, text, kind := "clue") -> void:
	if text is Array: text = "\n".join(text)
	if log_lines: printerr("EXAMINE %s: %s" % [title, String(text).replace("\n", " / ")])
	modal = true
	_card_title.text = title
	_card_tag.text = KIND_TAG.get(kind, "")
	_card_text.text = text
	_card.visible = true
	_card.size = Vector2(_card.custom_minimum_size.x, 0)
	_waiting = "card"
	if auto: await _wait(0.03)
	else: await _confirm
	_waiting = ""
	_card.visible = false
	modal = false
	_cooldown = 0.15

# options: [{label, disabled, hint}] → 고른 번호
func choice(prompt: String, options: Array) -> int:
	modal = true
	_choice_prompt.text = prompt
	_choice_prompt.visible = prompt != ""
	for c in _choice_list.get_children(): c.queue_free()
	_choice_btns.clear()
	var first := -1
	for i in options.size():
		var o: Dictionary = options[i]
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, o.label] + (("  — " + String(o.hint)) if o.get("disabled", false) and o.get("hint", "") != "" else "")
		b.disabled = o.get("disabled", false)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", int(22 * _k))
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0) if st in ["normal", "disabled"] else Color(INK.r, INK.g, INK.b, 0.12)
			sb.content_margin_left = 10; sb.content_margin_top = 4; sb.content_margin_bottom = 4
			if st == "focus": sb.draw_center = false
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", SEAL)
		b.add_theme_color_override("font_disabled_color", Color(INK.r, INK.g, INK.b, 0.4))
		b.pressed.connect(_pick.bind(i))
		_choice_list.add_child(b)
		_choice_btns.append(b)
		if first < 0 and not b.disabled: first = i
	_choice_sel = maxi(first, 0)
	_choice.visible = true
	_choice.size = Vector2(_choice.custom_minimum_size.x, 0)
	var vs := get_viewport().get_visible_rect().size
	_choice.position.y = vs.y * 0.62 - 30.0 * _k * options.size()
	_hilite()
	_waiting = "choice"
	var idx := -1
	if auto:
		await _wait(0.03)
		var labels := options.map(func(o): return String(o.label) if not o.get("disabled", false) else "")
		idx = auto_choice.call(prompt, labels) if auto_choice.is_valid() else first
		if idx < 0 or idx >= options.size() or options[idx].get("disabled", false): idx = first
	else:
		idx = await _picked
	_waiting = ""
	_choice.visible = false
	modal = false
	_cooldown = 0.15
	if log_lines: printerr("CHOICE [%s] → %s" % [prompt, options[idx].label if idx >= 0 else "-"])
	return idx

func _move_sel(d: int) -> void:
	var n := _choice_btns.size()
	for i in n:
		_choice_sel = posmod(_choice_sel + d, n)
		if not _choice_btns[_choice_sel].disabled: break
	_hilite()

func _hilite() -> void:
	for i in _choice_btns.size():
		var b: Button = _choice_btns[i]
		b.add_theme_color_override("font_color", SEAL if i == _choice_sel else INK)

func _pick(i: int) -> void:
	if _waiting != "choice" or i < 0 or i >= _choice_btns.size() or _choice_btns[i].disabled: return
	_picked.emit(i)

# ---------------------------------------------------------------------------
# 자막·띠·페이드·알림
# ---------------------------------------------------------------------------
func caption(text: String, sec := 2.4) -> void:
	if log_lines: printerr("CAPTION ", text)
	_caption.text = text
	if _cap_tween: _cap_tween.kill()
	_cap_tween = create_tween()
	_cap_tween.tween_property(_caption, "modulate:a", 1.0, 0.35)
	var hold := maxf(0.4, sec - 0.7)
	if auto: hold = 0.05
	_cap_tween.tween_interval(hold)
	_cap_tween.tween_property(_caption, "modulate:a", 0.0, 0.35)
	await _wait((0.1 if auto else sec))

func letterbox(on: bool) -> void:
	var vs := get_viewport().get_visible_rect().size
	var lbh := vs.y * 0.09
	_lb_top.set_meta("on", on); _lb_bot.set_meta("on", on)
	var tw := create_tween().set_parallel()
	tw.tween_property(_lb_top, "position:y", 0.0 if on else -lbh, 0.45)
	tw.tween_property(_lb_bot, "position:y", vs.y - lbh if on else vs.y, 0.45)

func fade(to_black: bool, sec := 0.7) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0 if to_black else 0.0, 0.05 if auto else sec)
	await tw.finished

func toast(text: String, kind := "info") -> void:
	if log_lines: printerr("TOAST [%s] %s" % [kind, text])
	var p := _paper(0.93, 1, 12)
	var hb := HBoxContainer.new(); hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := ColorRect.new(); bar.color = KIND_COL.get(kind, INK); bar.custom_minimum_size = Vector2(5 * _k, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(19, INK); l.text = text
	hb.add_child(bar); hb.add_child(l)
	p.add_child(hb)
	p.set_meta("t", 3.6)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_toasts.add_child(p)
	var live := _toasts.get_children().filter(func(c): return not c.is_queued_for_deletion())
	for i in maxi(0, live.size() - 5): live[i].queue_free()

func prompt(text: String) -> void:
	_prompt.text = ("[E]  " + text) if text != "" else ""

func items(list: Array) -> void:
	var parts := []
	for it in list: parts.append(String(it.label) + (" ×%d" % it.count if int(it.count) > 1 else ""))
	_items.text = "  ·  ".join(parts)

# ---------------------------------------------------------------------------
# 사건 기록(R)
# ---------------------------------------------------------------------------
func journal_toggle(data: Dictionary) -> void:
	if journal_open: journal_close()
	else: journal_show(data)

func journal_show(data: Dictionary) -> void:
	for c in _journal_body.get_children(): c.queue_free()
	var title := _label(38, INK); title.text = "사건 기록"
	_journal_body.add_child(title)
	var cases: Array = data.get("cases", [])
	if cases.is_empty():
		var e := _label(22, INK_SOFT)
		e.text = String(data.get("empty", "마지막으로 적힌 곳: 남원. 아직 적힌 사건이 없다."))
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_journal_body.add_child(e)
	for cs in cases:
		var h := HBoxContainer.new()
		var ct := _label(30, INK); ct.text = "「%s」" % cs.title; ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st := _label(20, SEAL); st.text = "해결" if cs.status == "solved" else "진행 중"
		h.add_child(ct); h.add_child(st)
		_journal_body.add_child(h)
		for p in cs.get("summary", []): _para(String(p), 21, INK)
		_section("단서", cs.get("clues", []), INK)
		_section(String(cs.get("rules_title", "범의 버릇")), cs.get("rules", []), SEAL)
		var sols: Array = cs.get("solutions", [])
		if not sols.is_empty():
			_head("해결 방법")
			for s in sols:
				var line := "%s  %s" % ["●" if s.available else "○", s.title]
				_para(line, 21, INK if s.available else INK_SOFT)
				var txt: String = s.text if s.available else String(s.get("hint", ""))
				if txt != "": _para("    " + txt, 18, INK_SOFT)
		for n in cs.get("notes", []): _para("— " + String(n), 18, INK_SOFT)
	var foot := _label(16, INK_SOFT); foot.text = "R · Esc 닫기"; foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_journal_body.add_child(foot)
	_journal.visible = true
	journal_open = true

func _head(t: String) -> void:
	var r := ColorRect.new(); r.color = Color(INK.r, INK.g, INK.b, 0.5); r.custom_minimum_size = Vector2(0, 1)
	_journal_body.add_child(r)
	var l := _label(24, SEAL); l.text = t
	_journal_body.add_child(l)

func _para(t: String, size: int, col: Color) -> void:
	var l := _label(size, col); l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journal_body.add_child(l)

func _section(t: String, list: Array, col: Color) -> void:
	if list.is_empty(): return
	_head(t)
	for c in list:
		_para("· " + String(c.title), 21, col)
		if String(c.get("text", "")) != "": _para("    " + String(c.text), 18, INK_SOFT)

func journal_close() -> void:
	_journal.visible = false
	journal_open = false
	_cooldown = 0.15

# ---------------------------------------------------------------------------
# 사건 종결 카드
# ---------------------------------------------------------------------------
func ending(d: Dictionary) -> void:
	if log_lines: printerr("ENDING %s — %s" % [d.get("title", ""), d.get("record", "")])
	modal = true
	for c in _end_box.get_children(): c.queue_free()
	var case_l := _label(22, SEAL); case_l.text = "「%s」 — 사건 종결" % d.get("case_title", "")
	var t := _label(44, INK); t.text = d.get("title", "")
	_end_box.add_child(case_l); _end_box.add_child(t)
	var r := ColorRect.new(); r.color = INK; r.custom_minimum_size = Vector2(0, 2)
	_end_box.add_child(r)
	for p in d.get("paragraphs", []):
		var l := _label(23, INK); l.text = p; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_end_box.add_child(l)
	var rec := _label(19, INK_SOFT); rec.text = d.get("record", ""); rec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_box.add_child(rec)
	var ok := _label(18, SEAL); ok.text = "계속  E"; ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_end_box.add_child(ok)
	_ending.visible = true
	_ending.modulate.a = 0.0
	create_tween().tween_property(_ending, "modulate:a", 1.0, 0.6)
	_waiting = "ending"
	if auto: await _wait(1.2)
	else:
		await _wait(0.6)
		await _confirm
	_waiting = ""
	var tw := create_tween(); tw.tween_property(_ending, "modulate:a", 0.0, 0.5)
	await tw.finished
	_ending.visible = false
	modal = false
	_cooldown = 0.15

# ---------------------------------------------------------------------------
# 전투 HUD
# ---------------------------------------------------------------------------
func combat_mode(on: bool) -> void:
	_hud.visible = on
	_items.visible = not on
	if on: prompt("")

func hud_player(hp: float, mhp: float, st: float, mst: float) -> void:
	_hp_bar.max_value = mhp; _hp_bar.value = hp
	_st_bar.max_value = mst; _st_bar.value = st

func hud_foe(n: String, hp: float, mhp: float) -> void:
	_foe_box.visible = n != ""
	_foe_name.text = n
	if mhp > 0.0:
		_foe_bar.max_value = mhp; _foe_bar.value = hp

func hud_ammo(arrows: int, bait: int) -> void:
	_ammo.text = "화살 %d  ·  떡 %d" % [arrows, bait]

func hud_say(text: String, sec: float) -> void:
	_hud_say.text = text
	_hud_say_t = sec
	_hud_say.modulate.a = 1.0
