# 처음 하는 사람 안내(seolhwa/docs/scenario/seolhwarok_ONBOARDING_UX_DESIGN_SUPPLEMENT_v1.0.md)
#   "플레이어가 무엇을 할 수 있는지는 숨기지 않는다. 무엇이 진실인지는 숨긴다." — 퀘스트 표시·숫자 체크리스트·긴 창 없음.
# 하는 일(story_director가 만들어 붙인다 — 사건이 없는 노정에서도):
#   1 처음 한 번 안내(§4·§6·§23): 이동(WASD — 움직이거나 4.5초면 사라짐) · 살펴보기·대화(손 닿는 거리 안내를 처음엔 크게) ·
#     기록책(R — 첫 조사 뒤) · 지도(M — 처음 들은 곳이 지도에 적힐 때) · 전투 회피(K)·막기(L) · 물건 쓰기.
#     progress.gd onboard에 ONBOARD_*_SEEN으로 남긴다(사건을 넘어 남는다, 새 게임이면 지워진다).
#   2 조사 대상 먹점(§13): 멀면 아무것도 없다 → 가까우면 엷은 먹점 → 손 닿는 거리면 'E 살펴보기'. 첫 20~30분(첫 사건 끝 전)엔 조금 강하게.
#     물건 데이터 highlight: "tutorial_high"(첫 사건 단서 — 단계 CASE_*_GUIDANCE_STAGE가 3 미만이면 다음 단서를 멀리서도) · "low" · "none".
#   3 첫 호랑이 조우(§16): 첫 '몸 낮춤 → 멈춤 → 돌진'에서만 짧은 느린 화면 + 'K 회피', 막기를 한 번도 안 썼으면 첫 앞발 때 'L 막기' 한 번.
#   4 설정(scripts/story/game_settings.gd): 상호작용 안내 항상/초반만/최소/끔 · 조사 도움 기본/자세히/최소 — 전투 난이도와 따로.
#   5 Esc: 잠시 멈춤 메뉴(scripts/story/options_menu.gd). 건너뛸 수 있는 장면(skippable) 중이면 Esc·Space·Enter가 건너뛰기.
#   6 정체 감지(§25, P2): 사건 진전(단서·규칙·국면)이 없이 오래 있으면 단계적으로 — 기록책 물음 강조 → 이미 본 단서를 잇는 한 줄.
extends Node

const Progress := preload("res://scripts/region/progress.gd")
const GameSettings := preload("res://scripts/story/game_settings.gd")
const EARLY_SEC := 25.0 * 60.0     # 초반 강조(첫 20~30분)

var d                      # story_director
var skippable := false     # 건너뛸 수 있는 연출 중(여는 장면·남원 전경)
var skip := false
var _hint_key := ""
var _hint_t := 0.0
var _hint_until: Callable = Callable()
var _queue: Array = []     # [[key, text, until, sec]]
var _move_from := Vector3.INF
var _mark_t := 0.0
var _save_t := 0.0
var _play := 0.0
var _slow := false
var _slow_prev := 1.0
var _slow_t0 := 0
var _guard_used := false
var _map_was_open := false
var _stall_t := 0.0
var _stall_sig := ""
var _stall_stage := 0
var stall_line := ""       # 정체 3단계에서 기록책 맨 위에 보일 한 줄(journal_book)
var menu = null
var last_marked: Array = []   # 시험 기록: 이번에 먹점을 찍은 대상 id

func _init(director) -> void:
	d = director
	name = "onboarding"

func _ready() -> void:
	_play = float(Progress.onboard("PLAY_TIME", 0.0))
	d.ui.on_journal_page = func(_id): seen_now("JOURNAL")
	process_mode = Node.PROCESS_MODE_ALWAYS

# ---- 설정·초반 ----
func guide() -> String: return GameSettings.guide()
func help() -> String: return GameSettings.help()

func early() -> bool:
	return _play < EARLY_SEC and not bool(Progress.get_var("CASE_NAMWON_COMPLETE", false)) and not (d.S != null and bool(d.S.vars.get("CASE_NAMWON_COMPLETE", false)))

# 먹점 세기: 0이면 그리지 않는다
func mark_level() -> float:
	match guide():
		"always": return 1.0
		"early": return 1.0 if early() else 0.62
		_: return 0.0

func hints_on() -> bool:
	return guide() != "off"

func is_seen(k: String) -> bool:
	return bool(Progress.onboard("ONBOARD_%s_SEEN" % k, false))

func seen_now(k: String) -> void:
	if is_seen(k): return
	Progress.set_onboard("ONBOARD_%s_SEEN" % k, true)
	if d.log_story: printerr("ONBOARD seen %s" % k)
	if _hint_key == k: _end_hint()

# 처음 한 번 안내. until: 참이 되면 사라짐(없으면 sec초)
func once(key: String, text: String, until: Callable = Callable(), sec := 6.0) -> void:
	if is_seen(key) or not hints_on(): return
	if _hint_key == key: return
	for q in _queue:
		if q[0] == key: return
	_queue.append([key, text, until, sec])

func _end_hint() -> void:
	_hint_key = ""
	_hint_until = Callable()
	d.ui.hint_clear()

func _update_hints(dt: float) -> void:
	if _hint_key != "":
		_hint_t -= dt
		if _hint_t <= 0.0 or (_hint_until.is_valid() and _hint_until.call()):
			var k := _hint_key
			_end_hint()
			Progress.set_onboard("ONBOARD_%s_SEEN" % k, true)
		return
	if _queue.is_empty() or d.ui.modal or d.ui.journal_open or (d.runner != null and d.runner.busy and not d.free_move): return
	var q: Array = _queue.pop_front()
	if is_seen(String(q[0])): return
	_hint_key = String(q[0]); _hint_until = q[2]; _hint_t = float(q[3])
	d.ui.hint(String(q[1]))
	Progress.set_onboard("ONBOARD_%s_SEEN" % _hint_key, true, false)   # 보여 준 것으로(다시 불러와도 다시 안 뜬다) — 다음 저장 때 쓴다

# ---- 이야기 쪽에서 부르는 것 ----
const Discovery := preload("res://scripts/region/discovery.gd")

# 단계 명령(story_runner): discover · observe · onboard
func step(st: Dictionary) -> void:
	if st.has("discover"):
		var key := "place:" + String(st.discover)
		if Discovery.tell(d.space_id, key):
			d.runner.log_line("discover", st.discover)
			on_discover(String(st.discover), "told")
	elif st.has("observe"):
		observe(String(st.get("about", "")), String(st.observe))
	elif st.has("onboard"):
		seen_now(String(st.onboard))

# 기록책 관찰(§17·§21): 사건 진행(S.flags._obs)에 남긴다 — "패턴 해금" 같은 말은 쓰지 않는다
func observe(about: String, text: String) -> void:
	if d.S == null: return
	var obs: Array = d.S.flags.get("_obs", [])
	for o in obs:
		if String(o.get("text", "")) == text: return
	obs.append({ about = about, text = text })
	d.S.flags["_obs"] = obs
	d.runner.log_line("observe", text)
	d.ui.toast("기록 — " + text, "journal")
func on_interact(kind: String) -> void:
	if kind == "object":
		var first := not is_seen("INSPECT")
		seen_now("INSPECT")
		if first: once("JOURNAL", "R   기록책", func(): return d.ui.journal_open, 10.0)
	else:
		seen_now("TALK")

func on_discover(nm: String, how: String) -> void:
	if how == "told": once("MAP", "M   지도 — 들은 곳이 적혔다", func(): return _map_open(), 9.0)

func on_case_started() -> void:
	once("MAP", "M   지도", func(): return _map_open(), 8.0)

func _map_open() -> bool:
	var m = d.main.get("_map")
	return m != null and m.visible

# ---- 프레임 ----
func _process(delta: float) -> void:
	if get_tree().paused: return
	if d.main._loading or (d.title != null and d.title.active): return
	var dt := minf(delta, 0.1)
	_play += dt / maxf(Engine.time_scale, 0.01)
	_save_t += dt
	if _save_t > 30.0:
		_save_t = 0.0
		Progress.set_onboard("PLAY_TIME", snappedf(_play, 1.0), d.test == null)
	var mp = d.main.get("_map")
	if mp != null and not mp.on_discover.is_valid(): mp.on_discover = on_discover
	if _map_open():
		_map_was_open = true
		seen_now("MAP")
	_update_move(dt)
	_update_prompt_style()
	_update_hints(dt)
	_update_marks(dt)
	_update_combat()
	_update_stall(dt)

var _ctl_t := 0.0
func _update_move(dt: float) -> void:
	if is_seen("MOVE") or _hint_key == "MOVE": return
	# 조작이 돌아오고 잠시 뒤(여는 장면 순간이동이 끝난 다음)부터 잰다
	if d.blocks_move() or d.drives_player() or not (d.case_id == "" or d._started) or (d.runner != null and d.runner.busy):
		_ctl_t = 0.0; _move_from = Vector3.INF; return
	_ctl_t += dt
	if _ctl_t < 0.5: return
	var p: Vector3 = d.main.player_pos
	if _move_from == Vector3.INF:
		_move_from = p
		once("MOVE", "W A S D   이동", func(): return Vector2(d.main.player_pos.x - _move_from.x, d.main.player_pos.z - _move_from.z).length() > 0.6, 4.5)

# 처음 조사·대화 전에는 손 닿는 거리 안내를 조금 크게(+ 대화는 한 줄 안내)
func _update_prompt_style() -> void:
	var t = d._target
	var strong := false
	if t != null and hints_on():
		if t.kind == "object" and not is_seen("INSPECT"): strong = true
		elif t.kind == "actor" and not is_seen("TALK"):
			strong = true
			once("TALK", "사람에게 다가가 E — 말을 건다", func(): return is_seen("TALK"), 8.0)
	d.ui.prompt_strong = strong

# ---- 조사 대상 먹점 ----
func _update_marks(dt: float) -> void:
	_mark_t -= dt
	if _mark_t > 0.0: return
	_mark_t = 0.06
	var lv := mark_level()
	var busy: bool = d.case_id == "" or d.runner == null or d.runner.busy or d.ui.modal or d.ui.journal_open or (d.combat_view != null and d.combat_view.active) or d._cut
	if lv <= 0.0 or busy:
		d.ui.set_marks([]); last_marked = []; return
	var cam: Camera3D = d.main.cam
	var vp_size: Vector2 = Vector2(d.main.scene_vp.size)
	var ui_size: Vector2 = d.ui.get_viewport().get_visible_rect().size
	var sc := ui_size / vp_size
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var help_k: float = { detailed = 1.4, minimal = 0.6 }.get(help(), 1.0)
	var near: float = (11.0 if lv >= 1.0 else 7.5) * help_k
	var stage := guidance_stage()
	var next_id := _next_guided(pp) if stage < 3 and help() != "minimal" else ""
	var out := []
	last_marked = []
	for t in d._targets():
		var hl := "normal"
		if t.kind == "object": hl = String(t.spec.get("highlight", "normal"))
		if hl == "none": continue
		var rng: float = near * (0.6 if hl == "low" else 1.0)
		var strength: float = lv
		if t.id == next_id:
			rng = maxf(rng, 30.0 if stage <= 1 else 20.0)   # 첫 단서 뒤 다음 단서: 강하게 → 약하게(§14)
			strength = maxf(lv, 0.9 if stage <= 1 else 0.7)
		var dd: float = pp.distance_to(t.p)
		if dd > rng: continue
		var a: float = strength * (1.0 - smoothstep(rng * 0.7, rng, dd))
		if dd < float(t.r): a *= 0.45   # 손 닿는 거리 — 글 안내가 대신한다
		var wp := Vector3(t.p.x, d.world.height_at(t.p.x, t.p.y) + (2.15 if t.kind == "actor" else 0.55), t.p.y)
		if cam.is_position_behind(wp): continue
		var sp: Vector2 = cam.unproject_position(wp) * sc
		out.append({ p = sp, a = a, r = 0.9 if t.kind == "actor" else 1.0 })
		last_marked.append(String(t.id))
	d.ui.set_marks(out)

# 첫 사건 단서 안내 단계(§14·§28) — 사건 데이터 case.guidance_flag(없으면 3: 일반 조사)
func guidance_stage() -> int:
	if d.S == null: return 3
	var k := String(d.data.get("case", {}).get("guidance_flag", ""))
	if k == "": return 3
	return int(d.S.flags.get(k, 0))

# 아직 안 본 tutorial_high 대상 가운데 가장 가까운 것
func _next_guided(pp: Vector2) -> String:
	var best := ""; var bd := INF
	for o in d.data.get("objects", []):
		if String(o.get("highlight", "")) != "tutorial_high" or not d.runner.cond(o.get("when", true)): continue
		var dd: float = pp.distance_to(d.anchor(o.at))
		if dd < bd: bd = dd; best = String(o.id)
	return best

# ---- 첫 호랑이 조우(§16) ----
func _update_combat() -> void:
	var cv = d.combat_view
	if cv == null or not cv.active or cv.battle == null:
		if _slow: _end_slow()
		return
	var b = cv.battle
	if String(b.get("mode")) == "human" or b.tiger == null: return
	var pl = b.player; var tg = b.tiger
	if pl.state == "guard":
		_guard_used = true
		Progress.set_onboard("ONBOARD_GUARD_USED", true, false)
	var first: bool = bool(cv._opts.get("mods", {}).get("firstEncounter", false))
	if first and not _slow and tg.state == "crouch" and not is_seen("COMBAT_DODGE") and hints_on():
		Progress.set_onboard("ONBOARD_COMBAT_DODGE_SEEN", true)
		_slow = true
		_slow_prev = Engine.time_scale
		_slow_t0 = Time.get_ticks_msec()
		Engine.time_scale = _slow_prev * 0.3
		d.ui.hint("K   회피")
		if d.log_story: printerr("ONBOARD combat dodge slow-motion")
	if _slow:
		var real := (Time.get_ticks_msec() - _slow_t0) / 1000.0
		if pl.state == "dodge" or (tg.state != "crouch" and tg.state != "pounce") or real > 3.2 or (tg.state == "pounce" and tg.t > 0.12):
			_end_slow()
	var dist: float = (tg.pos - pl.pos).length()
	if tg.state == "swipeWind" and dist < 4.5 and not _guard_used and not bool(Progress.onboard("ONBOARD_GUARD_USED", false)) \
			and not is_seen("COMBAT_GUARD") and hints_on():
		Progress.set_onboard("ONBOARD_COMBAT_GUARD_SEEN", true)
		_hint_key = "COMBAT_GUARD"; _hint_t = 2.6; _hint_until = Callable()
		d.ui.hint("L   막기 — 누르고 있기")

func _end_slow() -> void:
	_slow = false
	Engine.time_scale = _slow_prev
	d.ui.hint_clear()

# ---- 정체 감지(§25, P2) — 강제 지도 표시·정답 없음 ----
func _update_stall(dt: float) -> void:
	if d.S == null or d.case_id == "" or help() == "minimal": return
	var S = d.S
	if not bool(S.flags.get("case_started", false)) or S.phase in ["done", "morning"]: _stall_t = 0.0; return
	var sig := "%s|%d|%d|%d" % [S.phase, S.clues.size(), S.rules.size(), S.flags.size()]
	if sig != _stall_sig:
		_stall_sig = sig; _stall_t = 0.0; _stall_stage = 0; stall_line = ""
		return
	if d.runner.busy or d.combat_view.active: return
	_stall_t += dt / maxf(Engine.time_scale, 0.01)
	var step := 240.0 if help() == "normal" else 150.0   # 4분(자세히 2분 반)마다 한 단계
	if _stall_t < step * (_stall_stage + 1): return
	_stall_stage += 1
	if d.case_fn.has_method("stall_hint"):
		var h: String = String(d.case_fn.stall_hint(_stall_stage))
		if h == "": return
		if d.log_story: printerr("ONBOARD stall stage=%d %s" % [_stall_stage, h])
		if _stall_stage == 1: stall_line = h   # 기록책 물음 강조
		else: d.ui.caption(h, 3.2)

# ---- Esc: 멈춤 메뉴 · 건너뛰기 ----
func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo): return
	var kc: int = ev.physical_keycode
	if skippable and kc in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		skip = true
		get_viewport().set_input_as_handled()
		return
	if kc != KEY_ESCAPE or get_tree().paused: return
	if d.main._loading or (d.title != null and d.title.active) or d.ui.journal_open or d.ui.modal: return
	if _map_was_open:   # 지도가 방금 Esc로 닫혔다
		_map_was_open = _map_open()
		return
	get_viewport().set_input_as_handled()
	open_menu()

func open_menu() -> void:
	if menu != null and is_instance_valid(menu): return
	menu = load("res://scripts/story/options_menu.gd").new(true)
	menu.on_help = func(): d.ui.journal_show(load("res://scripts/story/journal_book.gd").build(d, 2))
	d.add_child(menu)

func _physics_process(_dt: float) -> void:
	if not _map_open(): _map_was_open = false
