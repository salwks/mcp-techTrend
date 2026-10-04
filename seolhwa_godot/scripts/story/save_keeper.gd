# 저장이 눈에 보이게 — story_director가 하나 만든다(사건 없는 공간에서도).
#   · progress.meta_fn: 저장할 때 칸 목록에 보일 것(지금 고을 · 사건 · 게임 안 시각 · 놀이 시간)을 적는다
#   · progress.on_checkpoint: 자동 기록(고을에 들어섬 · 사건이 나아감 · 길 떠나기 전) → story_ui 붓 도장 '기록을 남겼다' + 자동 칸 작은 그림
#   · 주막(건물 이름에 '주막')에 들어서면 오른쪽 아래 [F] 쉬며 기록을 정리한다 → 저장 + 쉬어 가기(시각 건너뛰기)
#   · open_slots(mode) — 저장 · 불러오기 창(scripts/story/save_menu.gd). load_slot(n) — 칸을 지금 진행으로 덮고 그 자리로(장면 다시 열기)
# 시험: --savetest  칸 1에 저장 → 진행을 바꿈 → 칸 1 불러오기 → 되돌아왔나(SAVETEST PASS/FAIL), --saveshot=폴더 저장 창·기록책 화면
extends Node

const Progress := preload("res://scripts/region/progress.gd")
const Travel := preload("res://scripts/region/travel.gd")
const JournalBook := preload("res://scripts/story/journal_book.gd")
const SIJIN := ["자시", "축시", "인시", "묘시", "진시", "사시", "오시", "미시", "신시", "유시", "술시", "해시"]

var d
var thumb: Image = null          # Esc를 누른 순간의 화면(손 저장 칸 그림)
var _inn := false
var _auto_thumb_t := -100000
var _resting := false
var _test = null

func _init(director) -> void:
	d = director
	name = "save_keeper"
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	Progress.meta_fn = meta
	Progress.on_checkpoint = _on_checkpoint
	var args: Dictionary = d.main.args
	if args.has("uifixture") or args.has("uifull"): load("res://scripts/story/ui_test.gd").apply_fixture(args)
	if args.has("savetest"):
		_test = load("res://scripts/story/ui_test.gd").new(self); _test.savetest.call_deferred()
	elif args.has("uishots"):
		_test = load("res://scripts/story/ui_test.gd").new(self); _test.uishots.call_deferred(String(args.uishots))

static func sijin(h: float) -> String:
	return SIJIN[int(floor(fposmod(h + 1.0, 24.0) / 2.0)) % 12]

static func hour_text(h: float) -> String:
	var hh := int(fposmod(h, 24.0))
	var part := "새벽" if hh < 5 else "아침" if hh < 9 else "낮" if hh < 17 else "저녁" if hh < 20 else "밤"
	return "%s(%s)" % [sijin(h), part]

func meta() -> Dictionary:
	var place := Progress.place_now
	if place == "" and d.main.has_method("_space_title"): place = String(d.main._space_title())
	var case_t := ""
	if String(d.case_id) != "" and d.S != null and d.get("_started"):
		case_t = JournalBook._case_title(String(d.case_id)) + (" · 해결" if d.S.phase == "done" else "")
	return { place = place, case = case_t, hour = snappedf(float(d.main.hour), 0.1), play = float(Progress.onboard("PLAY_TIME", 0.0)), space = String(d.space_id) }

func _headless() -> bool:
	return DisplayServer.get_name() == "headless"

# 화면을 작은 그림으로(칸 목록용 256×144)
func grab() -> Image:
	if _headless(): return null
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.is_empty(): return null
	img.resize(256, 144, Image.INTERPOLATE_BILINEAR)
	return img

func _on_checkpoint(reason: String) -> void:
	if d.ui == null or not is_instance_valid(d.ui): return
	if d.main._loading: return
	d.ui.save_stamp()
	var now := Time.get_ticks_msec()
	if now - _auto_thumb_t > 30000:
		_auto_thumb_t = now
		var img := grab()
		if img != null: img.save_png(Progress.thumb_path(0))

# ---- 주막: [F] 쉬며 기록을 정리한다 ----
func _busy() -> bool:
	return d.main._loading or d.ui.modal or d.ui.journal_open or (d.title != null and d.title.active) \
		or (d.runner != null and d.runner.busy) or (d.combat_view != null and d.combat_view.active) or d._cut or get_tree().paused

func _process(_dt: float) -> void:
	if d.ui == null: return
	var bt = d.main.get("_btitles")
	var at_inn := false
	if bt != null and int(bt.current) >= 0 and int(bt.current) < bt._areas.size():
		at_inn = String(bt._areas[bt.current].name).contains("주막")
	var show := at_inn and not _busy() and not _resting
	if show != _inn:
		_inn = show
		d.ui.key_hint("F", "쉬며 기록을 정리한다" if show else "")

func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo): return
	if ev.physical_keycode == KEY_F and _inn and not _busy():
		get_viewport().set_input_as_handled()
		rest()

func rest() -> void:
	_resting = true
	d.ui.key_hint("F", "")
	var h := float(d.main.hour)
	var opts := [
		{ label = "기록만 정리하고 일어선다" },
		{ label = "한 시진 쉬어 간다  (%s까지)" % sijin(h + 2.0) },
		{ label = "해 질 녘까지 쉰다", disabled = h >= 17.0 and h < 23.0, hint = "벌써 저물었다" },
		{ label = "하룻밤 묵고 아침에 떠난다" },
		{ label = "그만둔다" },
	]
	var i: int = await d.ui.choice("주막 — 쉬며 기록을 정리한다. 지금 %s." % hour_text(h), opts)
	if i == 4 or i < 0:
		_resting = false; return
	var to := h
	match i:
		1: to = h + 2.0
		2: to = 18.0
		3: to = 7.0 + (24.0 if h >= 7.0 else 0.0)
	if i > 0:
		await d.ui.fade(true, 0.6)
		_set_hour(to)
		await get_tree().create_timer(0.3).timeout
		await d.ui.fade(false, 0.6)
	Progress.save_slot(0, grab())
	Progress.checkpoint("inn")
	d.ui.toast("기록을 정리했다 — %s" % hour_text(float(d.main.hour)), "journal")
	_resting = false

func _set_hour(h: float) -> void:
	if d.S != null: d.set_hour(h)
	else:
		d.main.hour = fposmod(h, 24.0)
		d.main._apply_time()

# ---- 저장 · 불러오기 창 ----
func open_slots(mode: String, on_close: Callable = Callable()) -> Node:
	var m = load("res://scripts/story/save_menu.gd").new(mode, self)
	m.on_close = on_close
	d.add_child(m)
	return m

# 손 저장: 칸 n(1~3)
func save_to(n: int) -> bool:
	if d.S != null and d.get("_started"): d.S.time = d.main.hour
	if d.S != null and d.test == null: d.S.save()
	if d.test == null: d._save_where(INF)
	var ok := Progress.save_slot(n, thumb)
	if ok: d.ui.save_stamp()
	return ok

# 불러오기: 칸 n을 지금 진행으로 덮고 그 자리로 다시 연다
func load_from(n: int) -> bool:
	if not Progress.load_slot(n): return false
	get_tree().paused = false
	var wh := Progress.where()
	var space := String(wh.get("space", d.space_id))
	var kind := String(wh.get("kind", "region"))
	var dir: String = Travel.find_route_dir(space) if kind == "route" else Travel.region_dir(space)
	if dir == "": return false
	var at := Vector2(float(wh.get("x", d.main.player_pos.x)), float(wh.get("z", d.main.player_pos.z)))
	Travel.set_pending({ kind = kind, id = space, dir = dir, at = at, hour = float(wh.get("hour", d.main.hour)), via = "load",
		title = "", resume_at = [at.x, at.y] })
	d.main._leave.call_deferred()
	return true
