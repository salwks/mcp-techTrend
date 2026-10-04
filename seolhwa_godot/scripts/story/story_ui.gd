# 이야기 UI — 한지·먹 결(웹 src/ui 대응). 대화 상자, 조사 카드, 선택지, 자막, 위아래 먹 띠(레터박스), 알림 띠,
# 사건 기록 책자(R), 사건 종결 카드, 소지품 표시, 조사 안내, 전투 HUD(체력·기력 붓 게이지, 호랑이 체력, 화살·떡, 상황 문구).
# 비동기 API(await): say(이름, [줄]) · examine(제목, 글, 종류) · choice(물음, [{label, disabled, hint}]) → 번호 ·
#   caption(글, 초) · fade(검게?, 초) · ending(data) · center_text(글, 초 — 검은 화면 가운데) · title_card(글, 초, 크기) · book_page(줄, 초).
#   즉시: letterbox(on) · toast(글, 종류) · prompt(글) · items(목록) · journal_toggle(data) · hud_* ·
#   hint(글)/hint_clear() — 처음 한 번 안내(scripts/story/onboarding.gd) · set_marks([{p, a, r}]) — 조사 대상 먹점 ·
#   set_talk_marks([{p, a, s}]) — 새로 할 말이 있는 이야기 인물 머리 위 「…」 한지 말풍선.
# 기록책(R): 쪽(pages) — 여행 기록 · 사건 기록 · 여행 방법(scripts/story/journal_book.gd가 만든다). ←→·A·D·숫자·탭 클릭으로 넘긴다.
#   항목 꼬리표: ◆ 확인 · ◇ 들음 — 발언자 · △ 추정 (색만으로 가르지 않는다, 보강서 §22).
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
# 기록책 꼬리표(보강서 §22): 모양 + 낱말
const FACT_TAG := { fact = "◆ 확인", heard = "◇ 들음", guess = "△ 추정" }

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
var _hint: PanelContainer
var _hint_l: Label
var _hint_tw: Tween
var _marks: Control
var _mark_list: Array = []
var _talk_marks: Array = []
var _center: Label
var _title_l: Label
var _book: PanelContainer
var _book_box: VBoxContainer
var _jdata := {}
var _jpage := 0
var _jtabs: Array = []
var prompt_strong := false        # 처음 조사·대화 전: 안내 글을 조금 크게(onboarding)
var on_journal_page: Callable = Callable()   # (쪽 id) — 기록책을 열거나 넘길 때(onboarding)

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
	# 조사 대상 먹점(가까울 때만 — 멀면 아무 표시 없음)
	_marks = Control.new(); _marks.set_anchors_preset(Control.PRESET_FULL_RECT); _marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	_root.add_child(_marks)
	# 처음 한 번 안내(WASD 이동 등) — 한지 띠, 확인 버튼 없음
	_hint = _paper(0.9, 1, 14)
	_hint_l = _label(21, INK); _hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_child(_hint_l)
	_hint.modulate.a = 0.0
	_root.add_child(_hint)
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
	# 검은 화면 위 가운데 글(이겸의 세 문장) — 페이드보다 위
	_center = _label(30, Color(0.93, 0.9, 0.84)); _center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; _center.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center.modulate.a = 0.0
	_root.add_child(_center)
	# 기록책 한 장(여는 장면) · 가운데 큰 글(지명·제목)
	_book = _paper(0.98, 3, 40)
	_book_box = VBoxContainer.new(); _book_box.alignment = BoxContainer.ALIGNMENT_CENTER; _book_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_box.add_theme_constant_override("separation", 18)
	_book.add_child(_book_box)
	_book.visible = false
	_root.add_child(_book)
	_title_l = _label(64, Color(1, 1, 1), true); _title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_l.modulate.a = 0.0
	_root.add_child(_title_l)

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
	_place_hint()
	_center.position = Vector2(vs.x * 0.15, vs.y * 0.3); _center.size = Vector2(vs.x * 0.7, vs.y * 0.4)
	_title_l.position = Vector2(0, vs.y * 0.3); _title_l.size = Vector2(vs.x, vs.y * 0.3)
	var bw := minf(vs.x * 0.5, 520 * k)
	_book.custom_minimum_size = Vector2(bw, vs.y * 0.5); _book.size = Vector2(bw, vs.y * 0.5)
	_book.position = Vector2((vs.x - bw) / 2, vs.y * 0.22); _book.pivot_offset = Vector2(bw / 2, vs.y * 0.25)
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
		elif kc in [KEY_LEFT, KEY_A]: journal_page(_jpage - 1); get_viewport().set_input_as_handled()
		elif kc in [KEY_RIGHT, KEY_D]: journal_page(_jpage + 1); get_viewport().set_input_as_handled()
		elif kc >= KEY_1 and kc <= KEY_9 and kc - KEY_1 < _jdata.get("pages", []).size():
			journal_page(kc - KEY_1); get_viewport().set_input_as_handled()
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
	_prompt.text = ("E   " + text) if text != "" else ""
	var big := prompt_strong and text != ""
	_prompt.add_theme_font_size_override("font_size", int((27 if big else 22) * _k))

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
	# 예전 꼴({cases, empty})도 받는다 — 사건 기록 한 쪽으로
	if not data.has("pages"): data = { pages = [{ id = "case", tab = "사건 기록", blocks = _legacy_blocks(data) }] }
	_jdata = data
	_journal.visible = true
	journal_open = true
	journal_page(int(data.get("page", 0)))

func journal_page(i: int) -> void:
	var pages: Array = _jdata.get("pages", [])
	if pages.is_empty(): return
	_jpage = clampi(i, 0, pages.size() - 1)
	for c in _journal_body.get_children(): c.queue_free()
	# 쪽 머리(탭): 클릭으로도 넘긴다
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", int(28 * _k))
	_jtabs = []
	for j in pages.size():
		var t := _label(24 if j == _jpage else 21, SEAL if j == _jpage else INK_SOFT)
		t.text = ("%d  %s" % [j + 1, String(pages[j].get("tab", ""))]) + ("  ▾" if j == _jpage else "")
		t.mouse_filter = Control.MOUSE_FILTER_STOP
		t.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: journal_page(j))
		tabs.add_child(t); _jtabs.append(t)
	_journal_body.add_child(tabs)
	var r := ColorRect.new(); r.color = INK; r.custom_minimum_size = Vector2(0, 2)
	_journal_body.add_child(r)
	for bl in pages[_jpage].get("blocks", []): _block(bl)
	var foot := _label(16, INK_SOFT); foot.text = "← → 쪽 넘기기 · R · Esc 닫기"; foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_journal_body.add_child(foot)
	if log_lines: printerr("JOURNAL page=%s %s" % [pages[_jpage].get("id", ""), _page_text(pages[_jpage])])
	if on_journal_page.is_valid(): on_journal_page.call(String(pages[_jpage].get("id", "")))

# 시험 기록용: 한 쪽을 한 줄 글로
func _page_text(pg: Dictionary) -> String:
	var parts := []
	for bl in pg.get("blocks", []):
		var t := String(bl.get("text", bl.get("title", "")))
		if bl.get("t") == "entry": t = "[%s%s] %s %s" % [FACT_TAG.get(String(bl.get("tag", "fact")), ""), (" — " + String(bl.by)) if String(bl.get("by", "")) != "" else "", String(bl.get("title", "")), String(bl.get("text", ""))]
		if t != "": parts.append(t)
	return " / ".join(parts)

# 블록: title · head · para(soft, size) · quote · entry(tag fact|heard|guess, by, title, text, strong) · case(title, status) · gap
func _block(bl: Dictionary) -> void:
	match String(bl.get("t", "para")):
		"title":
			var l := _label(36, INK); l.text = String(bl.text); _journal_body.add_child(l)
		"head":
			_head(String(bl.text))
		"case":
			var h := HBoxContainer.new()
			var ct := _label(28, INK); ct.text = "「%s」" % bl.title; ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var st := _label(19, SEAL); st.text = String(bl.get("status", ""))
			h.add_child(ct); h.add_child(st)
			_journal_body.add_child(h)
		"quote":
			_para("    " + String(bl.text), int(bl.get("size", 22)), SEAL)
		"gap":
			var g := Control.new(); g.custom_minimum_size = Vector2(0, 6 * _k); _journal_body.add_child(g)
		"entry":
			var row := HBoxContainer.new(); row.add_theme_constant_override("separation", int(10 * _k))
			var tag := String(bl.get("tag", "fact"))
			var tg := PanelContainer.new()
			var sb := StyleBoxFlat.new(); sb.bg_color = Color(0, 0, 0, 0); sb.border_color = INK if tag == "fact" else INK_SOFT
			sb.set_border_width_all(2 if tag == "fact" else 1)
			sb.content_margin_left = 6; sb.content_margin_right = 6; sb.content_margin_top = 1; sb.content_margin_bottom = 1
			tg.add_theme_stylebox_override("panel", sb)
			tg.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			var tl := _label(16, INK if tag == "fact" else INK_SOFT)
			tl.text = String(FACT_TAG.get(tag, "◆ 확인")) + ((" — " + String(bl.by)) if tag == "heard" and String(bl.get("by", "")) != "" else "")
			tg.add_child(tl)
			tg.custom_minimum_size = Vector2(150 * _k, 0)
			var col := VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 2)
			if String(bl.get("title", "")) != "":
				var t1 := _label(21, SEAL if bl.get("strong", false) else INK); t1.text = String(bl.title)
				t1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; t1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				col.add_child(t1)
			if String(bl.get("text", "")) != "":
				var t2 := _label(18 if String(bl.get("title", "")) != "" else 21, INK_SOFT if String(bl.get("title", "")) != "" else INK)
				t2.text = String(bl.text); t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; t2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				col.add_child(t2)
			row.add_child(tg); row.add_child(col)
			_journal_body.add_child(row)
		_:
			_para(String(bl.get("text", "")), int(bl.get("size", 21)), INK_SOFT if bl.get("soft", false) else INK)

func _legacy_blocks(data: Dictionary) -> Array:
	var out := []
	var cases: Array = data.get("cases", [])
	if cases.is_empty(): out.append({ t = "para", text = String(data.get("empty", "아직 기록된 사건 없음")), soft = true })
	for cs in cases:
		out.append({ t = "case", title = cs.title, status = "해결" if cs.status == "solved" else "진행 중" })
		for p in cs.get("summary", []): out.append({ t = "para", text = String(p) })
		for c in cs.get("clues", []): out.append({ t = "entry", tag = "fact", title = c.title, text = c.get("text", "") })
	return out

func _head(t: String) -> void:
	var r := ColorRect.new(); r.color = Color(INK.r, INK.g, INK.b, 0.5); r.custom_minimum_size = Vector2(0, 1)
	_journal_body.add_child(r)
	var l := _label(23, SEAL); l.text = t
	_journal_body.add_child(l)

func _para(t: String, size: int, col: Color) -> void:
	var l := _label(size, col); l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journal_body.add_child(l)

func journal_close() -> void:
	_journal.visible = false
	journal_open = false
	_cooldown = 0.15

# ---------------------------------------------------------------------------
# 처음 한 번 안내 · 조사 먹점 · 여는 장면(검은 화면 글, 기록책 한 장, 큰 제목)
# ---------------------------------------------------------------------------
func hint(text: String) -> void:
	if log_lines: printerr("HINT ", text)
	_hint_l.text = text
	_hint.reset_size()
	_place_hint()
	if _hint_tw: _hint_tw.kill()
	_hint_tw = create_tween()
	_hint_tw.tween_property(_hint, "modulate:a", 1.0, 0.3)

func hint_clear() -> void:
	if _hint.modulate.a <= 0.01: return
	if _hint_tw: _hint_tw.kill()
	_hint_tw = create_tween()
	_hint_tw.tween_property(_hint, "modulate:a", 0.0, 0.4)

func hint_text() -> String:
	return _hint_l.text if _hint.modulate.a > 0.05 else ""

func _place_hint() -> void:
	if _hint == null: return
	var vs := get_viewport().get_visible_rect().size
	var sz := _hint.get_combined_minimum_size()
	_hint.size = sz
	_hint.position = Vector2((vs.x - sz.x) / 2, vs.y - 118 * _k - sz.y)

# [{p: Vector2(화면), a: 0~1, r: 반지름 배율}]
func set_marks(list: Array) -> void:
	if list.is_empty() and _mark_list.is_empty(): return
	_mark_list = list
	_marks.queue_redraw()

# [{p: Vector2(화면 — 말풍선 아래 끝), a: 0~1, s: 크기 배율}]
func set_talk_marks(list: Array) -> void:
	if list.is_empty() and _talk_marks.is_empty(): return
	_talk_marks = list
	_marks.queue_redraw()

# 한지 말풍선 + 붓 「…」: 둥근 종이, 엷은 먹 테, 아래로 짧은 꼬리, 가운데 먹점 셋
func _draw_talk_mark(p: Vector2, a: float, s: float) -> void:
	var k := _k * s
	var w := 30.0 * k; var h := 19.0 * k
	var c := p + Vector2(0, -h * 0.5 - 6.0 * k)
	var ink := Color(INK.r, INK.g, INK.b, 0.82 * a)
	var paper := Color(PAPER.r, PAPER.g, PAPER.b, 0.92 * a)
	var pts := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		pts.append(c + Vector2(cos(t) * w * 0.5, sin(t) * h * 0.5))
	_marks.draw_colored_polygon(PackedVector2Array([c + Vector2(-4 * k, h * 0.35), c + Vector2(3 * k, h * 0.4), p]), paper)
	_marks.draw_colored_polygon(pts, paper)
	pts.append(pts[0])
	_marks.draw_polyline(pts, ink, 1.6 * k, true)
	_marks.draw_line(c + Vector2(-4 * k, h * 0.45), p, ink, 1.4 * k, true)
	# 「 」 붓 꺾쇠와 먹점 셋
	var bx := w * 0.36; var by := h * 0.26
	_marks.draw_polyline(PackedVector2Array([c + Vector2(-bx + 3 * k, -by), c + Vector2(-bx, -by), c + Vector2(-bx, by * 0.4)]), ink, 1.4 * k, true)
	_marks.draw_polyline(PackedVector2Array([c + Vector2(bx - 3 * k, by), c + Vector2(bx, by), c + Vector2(bx, -by * 0.4)]), ink, 1.4 * k, true)
	for i in 3:
		_marks.draw_circle(c + Vector2((i - 1) * 5.0 * k, 1.0 * k), 1.7 * k, ink)

func _draw_marks() -> void:
	for m in _talk_marks: _draw_talk_mark(m.p, float(m.a), float(m.get("s", 1.0)))
	for m in _mark_list:
		var p: Vector2 = m.p
		var a: float = float(m.a)
		var r: float = 5.0 * _k * float(m.get("r", 1.0))
		_marks.draw_circle(p, r * 2.2, Color(PAPER.r, PAPER.g, PAPER.b, 0.35 * a))   # 한지 번짐
		_marks.draw_circle(p, r, Color(INK.r, INK.g, INK.b, 0.85 * a))                 # 먹점
		_marks.draw_arc(p, r * 1.9, 0, TAU, 20, Color(INK.r, INK.g, INK.b, 0.45 * a), 1.2 * _k, true)   # 엷은 먹선 테

func center_text(text: String, sec := 2.0) -> void:
	if log_lines: printerr("CENTER ", text)
	_center.text = text
	var tw := create_tween()
	tw.tween_property(_center, "modulate:a", 1.0, 0.05 if auto else 0.5)
	tw.tween_interval(0.05 if auto else maxf(0.3, sec - 1.0))
	tw.tween_property(_center, "modulate:a", 0.0, 0.05 if auto else 0.5)
	await tw.finished

func title_card(text: String, sec := 2.4, size := 64) -> void:
	if log_lines: printerr("TITLE ", text)
	preload("res://scripts/region/place_title.gd").note_story(text)   # 같은 지명이 곧 지명 표시로 겹쳐 뜨지 않게
	_title_l.text = text
	_title_l.add_theme_font_size_override("font_size", int(size * _k))
	var tw := create_tween()
	tw.tween_property(_title_l, "modulate:a", 1.0, 0.05 if auto else 0.6)
	tw.tween_interval(0.05 if auto else maxf(0.3, sec - 1.2))
	tw.tween_property(_title_l, "modulate:a", 0.0, 0.05 if auto else 0.6)
	await tw.finished

func title_card_stop() -> void:
	_title_l.modulate.a = 0.0
	_center.modulate.a = 0.0

# 기록책 마지막 장: 펼쳐 보이다가 덮는다(세로로 접히며 사라짐)
func book_page(lines: Array, sec := 2.6) -> void:
	if log_lines: printerr("BOOK ", " / ".join(lines))
	for c in _book_box.get_children(): c.queue_free()
	for i in lines.size():
		var l := _label(34 if i == 0 else 26, INK if i < lines.size() - 1 else INK_SOFT)
		l.text = String(lines[i]); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_book_box.add_child(l)
	_book.visible = true
	_book.scale = Vector2.ONE
	_book.modulate.a = 1.0
	await _wait(0.05 if auto else sec)

func book_close() -> void:
	if not _book.visible: return
	var tw := create_tween().set_parallel()
	tw.tween_property(_book, "scale:x", 0.02, 0.05 if auto else 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_book, "modulate:a", 0.0, 0.05 if auto else 0.5)
	await tw.finished
	_book.visible = false

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
