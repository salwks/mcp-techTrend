# 처음 하는 사람 안내(seolhwa/docs/scenario/seolhwarok_ONBOARDING_UX_DESIGN_SUPPLEMENT_v1.0.md)
#   "플레이어가 무엇을 할 수 있는지는 숨기지 않는다. 무엇이 진실인지는 숨긴다." — 퀘스트 표시·숫자 체크리스트·긴 창 없음.
# 하는 일(story_director가 만들어 붙인다 — 사건이 없는 노정에서도):
#   1 처음 한 번 안내(§4·§6·§23): 이동(WASD) · 살펴보기·대화(손 닿는 거리 안내를 처음엔 크게) ·
#     기록책(R — 첫 조사 뒤) · 지도(M — 처음 들은 곳이 지도에 적힐 때) · 전투 회피(K)·막기(L) · 물건 쓰기.
#     progress.gd onboard에 ONBOARD_*_SEEN으로 남긴다(사건을 넘어 남는다, 새 게임이면 지워진다).
#     핵심 안내(CORE — 남원 v3.2 §4 "핵심 튜토리얼은 시간으로 완료 처리하지 않는다"): 실제로 그 행동을 해야 SEEN.
#       시간이 다 돼도 사라지지 않는다. 다른 안내가 기다리면 제 시간(sec)만큼 보인 뒤 줄 뒤로 물러났다가 다시 뜬다.
#       기다리는 핵심 안내는 onboard.ONBOARD_PENDING {key: 글}에 남아 저장·이어 하기 뒤에도 다시 뜬다.
#     그 밖의 안내(정보 안내 — RIDE·KNOT 등): sec초 보이면 끝나고 SEEN. 대화·컷신·기록책 동안은 감췄다가 이어 보이며(그 시간은 세지 않는다),
#       다 보이기 전에 끊기면(장면이 바뀜 등) MIN_SHOWN초 넘게 보였을 때만 SEEN — 아니면 다음에 다시 뜬다.
#     새 핵심 안내 붙이기: CORE에 key를 넣고 once(key, 글[, until]) — 또는 hold(key, 글[, until]). 행동하는 곳에서 seen_now(key).
#   2 조사 대상 먹점(§13): 멀면 아무것도 없다 → 가까우면 엷은 먹점 → 손 닿는 거리면 'E 살펴보기'. 첫 20~30분(첫 사건 끝 전)엔 조금 강하게.
#     물건 데이터 highlight: "tutorial_high"(첫 사건 단서 — 단계 CASE_*_GUIDANCE_STAGE가 3 미만이면 다음 단서를 멀리서도) · "low" · "none".
#   3 첫 호랑이 조우(§16): 첫 '몸 낮춤 → 멈춤 → 돌진'에서만 짧은 느린 화면 + 'K 회피', 막기를 한 번도 안 썼으면 첫 앞발 때 'L 막기' 한 번.
#   4 설정(scripts/story/game_settings.gd): 상호작용 안내 항상/초반만/최소/끔 · 조사 도움 기본/자세히/최소 — 전투 난이도와 따로.
#   5 Esc: 잠시 멈춤 메뉴(scripts/story/options_menu.gd). 건너뛸 수 있는 장면(skippable) 중이면 Esc·Space·Enter가 건너뛰기.
#   7 이야기 인물 말 표시: 새로 할 말이 있는 이야기 인물(story_director.talk_pending) 머리 위에 「…」 한지 말풍선(살짝 오르내림).
#     28m 안·화면 안에서만, 들으면 사라지고 새 말이 생기면 다시. 안내 설정 끔이면 없음, 최소면 작게. 고을 사람(소문)에는 없다. 지도에는 그리지 않는다.
#   6 정체 감지(§25, P2): 사건 진전(단서·규칙·국면)이 없이 오래 있으면 단계적으로 — 기록책 물음 강조 → 이미 본 단서를 잇는 한 줄.
extends Node

const Progress := preload("res://scripts/region/progress.gd")
const GameSettings := preload("res://scripts/story/game_settings.gd")
const EARLY_SEC := 25.0 * 60.0     # 초반 강조(첫 20~30분)

var d                      # story_director
var skippable := false     # 건너뛸 수 있는 연출 중(여는 장면·남원 전경)
var skip := false
var _hint_key := ""
var _hint_text := ""
var _hint_sec := 0.0       # 이만큼 보이면: 정보 안내는 끝, 핵심 안내는 기다리는 안내에 자리를 내줌
var _hint_shown := 0.0     # 실제로 보인 시간(감춘 동안은 세지 않는다)
var _hint_core := false
var _hint_hidden := false  # 대화·컷신·기록책 동안 잠시 감춤
var _hint_until: Callable = Callable()
var _queue: Array = []     # [[key, text, until, sec, core]]
# 핵심 안내 — 시간으로 끝나지 않고 행동해야 끝난다(§4·§26). MOVE 5m 걷기 → RUN 2초 달리기(track_move) · INSPECT·TALK(on_interact) ·
#   JOURNAL(사건 기록이 선 뒤 — on_case_started, 기록책을 열면) · MAP(들은 곳이 지도에 적힐 때 — on_discover, 지도를 열면).
const CORE := ["MOVE", "RUN", "INSPECT", "TALK", "JOURNAL", "MAP"]
const MIN_SHOWN := 2.5     # 정보 안내가 끊겼을 때 이만큼 보였으면 본 것으로
const PENDING := "ONBOARD_PENDING"
# v3.2 §4: 이동은 실제로 MOVE_M 넘게 걸어야, 달리기는 실제로 RUN_SEC 넘게 달려야 끝난다(순간이동·여는 장면은 세지 않는다)
const MOVE_M := 5.0
const RUN_SEC := 2.0
const JUMP_M := 3.0          # 한 프레임에 이보다 멀리 옮겨졌으면 순간이동(세지 않는다)
var _last_p := Vector3.INF
var moved_m := 0.0           # 시험 기록
var ran_sec := 0.0
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
var talk_marked: Array = []   # 시험 기록: 이번에 「…」를 띄운 이야기 인물 id
const TALK_MARK_R := 28.0
var _tm_t := 0.0
var _pend_t := 0.0
var _pending := {}            # 인물 id → 새로 할 말 있음(0.4초마다 다시 본다 — 조건식 평가를 프레임마다 하지 않게)

func _init(director) -> void:
	d = director
	name = "onboarding"

func _ready() -> void:
	_play = float(Progress.onboard("PLAY_TIME", 0.0))
	d.ui.on_journal_page = func(_id): seen_now("JOURNAL")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_restore_pending()

# 저장에 남은 기다리는 핵심 안내를 다시 줄에 세운다(이어 하기)
func _restore_pending() -> void:
	var pend = Progress.onboard(PENDING, {})
	if not (pend is Dictionary): return
	for k in pend.keys():
		if is_seen(String(k)): continue
		once(String(k), String(pend[k]), _until_for(String(k)))

# 다시 불러온 핵심 안내의 끝 조건(대개는 행동하는 곳에서 seen_now가 부른다 — 여기는 그 밖의 것만)
func _until_for(k: String) -> Callable:
	match k:
		"JOURNAL": return func(): return d.ui.journal_open
		"MAP": return func(): return _map_open()
	return Callable()

static func is_core(k: String) -> bool:
	return CORE.has(k)

# 기다리는 핵심 안내 기록(저장 때 함께 쓴다 — 바로 쓰지는 않는다)
func _set_pending(k: String, text: String) -> void:
	var pend = Progress.onboard(PENDING, {})
	if not (pend is Dictionary): pend = {}
	if text == "":
		if not pend.has(k): return
		pend.erase(k)
	else:
		if String(pend.get(k, "")) == text: return
		pend[k] = text
	Progress.set_onboard(PENDING, pend, false)

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

# 행동을 마쳤다(또는 안내를 다 보았다) — SEEN을 바로 저장하고, 떠 있거나 기다리던 안내를 거둔다
func seen_now(k: String) -> void:
	if _hint_key == k: _end_hint()
	_queue = _queue.filter(func(q): return String(q[0]) != k)
	if is_seen(k): return
	_set_pending(k, "")
	Progress.set_onboard("ONBOARD_%s_SEEN" % k, true)
	if d.log_story: printerr("ONBOARD seen %s" % k)

# 처음 한 번 안내. until: 참이 되면 끝(SEEN). core(기본 CORE에 있으면 참): 시간으로 끝나지 않는다 — 위 머리말
func once(key: String, text: String, until: Callable = Callable(), sec := 6.0, core = null) -> void:
	if is_seen(key) or not hints_on(): return
	var c: bool = is_core(key) if core == null else bool(core)
	if c: _set_pending(key, text)
	if _hint_key == key: return
	for q in _queue:
		if q[0] == key: return
	_queue.append([key, text, until, sec, c])

# 행동할 때까지 남는 안내(CORE에 없는 key도) — once(..., core = true)
func hold(key: String, text: String, until: Callable = Callable(), sec := 6.0) -> void:
	once(key, text, until, sec, true)

func hint_key() -> String: return _hint_key   # 시험용: 지금 떠 있는 안내

func _end_hint() -> void:
	_hint_key = ""
	_hint_text = ""
	_hint_until = Callable()
	_hint_hidden = false
	d.ui.hint_clear()

# 떠 있는 안내를 SEEN 없이 내리고 줄 뒤로(핵심 안내가 자리를 내줄 때 · 전투 안내가 끼어들 때)
func _park_hint() -> void:
	if _hint_key == "": return
	var q := [_hint_key, _hint_text, _hint_until, _hint_sec, _hint_core]
	var shown := _hint_shown
	var k := _hint_key
	_end_hint()
	if not q[4] and shown >= MIN_SHOWN:   # 정보 안내는 넉넉히 보였으면 본 것으로
		seen_now(k); return
	_queue.append(q)

# 새 안내를 띄우지 않을 때(예전과 같다): 대화·기록책·이야기 진행 중(추격처럼 플레이어가 움직이는 때는 빼고)
func _hint_blocked() -> bool:
	return d.ui.modal or d.ui.journal_open or (d.runner != null and d.runner.busy and not d.free_move)

func _in_combat() -> bool:
	return d.combat_view != null and d.combat_view.active

# 떠 있는 안내를 잠시 감출 때: 대화창·기록책·컷신. 전투 중에는 건드리지 않는다(전투 안내 K·L이 같은 자리를 쓴다)
func _hint_hide() -> bool:
	return not _in_combat() and (d.ui.modal or d.ui.journal_open or d._cut)

func _update_hints(dt: float) -> void:
	if _hint_key != "":
		if _hint_until.is_valid() and _hint_until.call():
			seen_now(_hint_key); return
		if _hint_hide():
			if not _hint_hidden: _hint_hidden = true; d.ui.hint_clear()
			return
		if _hint_hidden:
			if _in_combat(): return   # 감춘 채로 전투가 시작됐다 — 끝난 뒤 다시
			_hint_hidden = false; d.ui.hint(_hint_text)
		_hint_shown += dt
		if _hint_shown < _hint_sec: return
		if not _hint_core: seen_now(_hint_key)                                # 정보 안내: 제 시간 다 보였다
		elif not _queue.is_empty() and not _hint_blocked(): _park_hint()     # 핵심 안내: 기다리는 안내에 잠시 자리를 내주고 다시 뜬다
		return
	if _queue.is_empty() or _hint_blocked(): return
	var q: Array = _queue.pop_front()
	if is_seen(String(q[0])): return
	_hint_key = String(q[0]); _hint_text = String(q[1]); _hint_until = q[2]; _hint_sec = float(q[3]); _hint_core = bool(q[4])
	_hint_shown = 0.0; _hint_hidden = false
	d.ui.hint(_hint_text)

# 장면이 닫힐 때: 넉넉히 보인 정보 안내는 본 것으로(아니면 다음에 다시). 핵심 안내는 ONBOARD_PENDING으로 남아 있다
func _exit_tree() -> void:
	if _hint_key != "" and not _hint_core and _hint_shown >= MIN_SHOWN and not is_seen(_hint_key):
		Progress.set_onboard("ONBOARD_%s_SEEN" % _hint_key, true, false)

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
# 기록책 안내(R)는 첫 조사 뒤가 아니라 사건 기록이 선 뒤(v3.2 §9 — on_case_started)
func on_interact(kind: String) -> void:
	if kind == "object": seen_now("INSPECT")
	else: seen_now("TALK")

func on_discover(nm: String, how: String) -> void:
	if how == "told": once("MAP", "M   지도 — 들은 곳이 적혔다", func(): return _map_open(), 9.0)

# 사건 기록이 섰다 → R 기록책(핵심 — 실제로 열어야 끝난다). 지도(M)는 들은 곳이 지도에 적힐 때(on_discover)
func on_case_started() -> void:
	once("JOURNAL", "R   기록책 — 새 사건이 적혔다", func(): return d.ui.journal_open, 8.0)

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
	_update_talk_marks(dt)
	_update_combat()
	_update_stall(dt)

var _ctl_t := 0.0
func _update_move(dt: float) -> void:
	if is_seen("MOVE") and is_seen("RUN"): return
	# 조작이 돌아오고 잠시 뒤(여는 장면 순간이동이 끝난 다음)부터 잰다
	if d.blocks_move() or d.drives_player() or not (d.case_id == "" or d._started) or (d.runner != null and d.runner.busy):
		_ctl_t = 0.0; _last_p = Vector3.INF; return
	_ctl_t += dt
	if _ctl_t < 0.5: return
	var p: Vector3 = d.main.player_pos
	if _last_p == Vector3.INF:
		_last_p = p
		if not is_seen("MOVE"): once("MOVE", "W A S D   이동", Callable(), 4.5)
		return
	var step := Vector2(p.x - _last_p.x, p.z - _last_p.z).length()
	_last_p = p
	track_move(step, String(d.main.player.anim) == "run", dt)

# 한 프레임 이동을 센다(시험이 직접 부를 수 있다): step 이번 프레임 걸은 거리(m) · running 달리는 그림 · dt 게임 시간
#   MOVE: 걸은 거리를 더해 MOVE_M을 넘으면 끝 → 이어서 RUN 안내(이번 판에서 MOVE를 막 끝냈을 때만 — 오래된 저장에 갑자기 뜨지 않게)
#   RUN: 실제로 달린 시간을 더해 RUN_SEC를 넘으면 끝(안내가 없어도 달리면 끝)
func track_move(step: float, running: bool, dt: float) -> void:
	if step > JUMP_M or step <= 0.0001: return
	if not is_seen("MOVE"):
		moved_m += step
		if moved_m >= MOVE_M:
			seen_now("MOVE")
			if not is_seen("RUN"): once("RUN", "Shift   달리기", Callable(), 5.0)
		return
	if not is_seen("RUN") and running:
		ran_sec += dt
		if ran_sec >= RUN_SEC: seen_now("RUN")

# 처음 조사·대화 전에는 손 닿는 거리 안내를 조금 크게(+ 대화는 한 줄 안내)
func _update_prompt_style() -> void:
	var t = d._target
	var strong := false
	if t != null and hints_on():
		if t.kind == "object" and not is_seen("INSPECT"): strong = true
		elif t.kind in ["actor", "ambient"] and not is_seen("TALK"):
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
		elif _pending.get(t.id, false) and guide() != "off": continue   # 할 말 있는 인물은 「…」가 대신한다
		if hl == "none": continue
		var rng: float = near * (0.6 if hl == "low" else 1.0)
		var strength: float = lv
		if t.kind == "object" and t.spec.has("mark_r"):   # 대상이 정한 먹빛 거리·세기(길가 짚신: 4m, 아주 약하게 — v3.2 §5)
			rng = float(t.spec.mark_r); strength = lv * float(t.spec.get("mark_a", 1.0))
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
		_park_hint()   # 떠 있던 안내는 SEEN 없이 줄 뒤로
		_hint_key = "COMBAT_GUARD"; _hint_text = "L   막기 — 누르고 있기"; _hint_sec = 2.6; _hint_shown = 0.0
		_hint_core = false; _hint_hidden = false; _hint_until = Callable()
		d.ui.hint(_hint_text)

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

# ---- 이야기 인물 말 표시(「…」) ----
func _update_talk_marks(dt: float) -> void:
	_tm_t -= dt
	_pend_t -= dt
	if _tm_t > 0.0: return
	_tm_t = 0.033
	talk_marked = []
	var busy: bool = d.case_id == "" or d.S == null or not d._started or d.runner.busy or d.ui.modal or d.ui.journal_open \
		or (d.combat_view != null and d.combat_view.active) or d._cut or guide() == "off"
	if busy:
		d.ui.set_talk_marks([]); return
	if _pend_t <= 0.0:
		_pend_t = 0.4
		_pending.clear()
		for id in d.actors:
			if d.talk_pending(id): _pending[id] = true
	var cam: Camera3D = d.main.cam
	var sc: Vector2 = d.ui.get_viewport().get_visible_rect().size / Vector2(d.main.scene_vp.size)
	var pp := Vector2(d.main.player_pos.x, d.main.player_pos.z)
	var small := guide() == "minimal"
	var tt := Time.get_ticks_msec() / 1000.0
	var out := []
	for id in _pending:
		var a = d.actors.get(id)
		if a == null or not a.ch.visible: continue
		var dd: float = pp.distance_to(Vector2(a.pos.x, a.pos.z))
		if dd > TALK_MARK_R: continue
		var wp := Vector3(a.pos.x, (a.y_abs if not is_nan(a.y_abs) else d.world.height_at(a.pos.x, a.pos.z)) + 2.55, a.pos.z)
		if cam.is_position_behind(wp) or not cam.is_position_in_frustum(wp): continue
		var sp: Vector2 = cam.unproject_position(wp) * sc
		sp.y += sin(tt * 2.4 + float(hash(id) % 100)) * 3.0   # 살짝 오르내림
		var fade: float = 1.0 - smoothstep(TALK_MARK_R * 0.75, TALK_MARK_R, dd)
		out.append({ p = sp, a = fade, s = 0.72 if small else 1.0 })
		talk_marked.append(String(id))
	d.ui.set_talk_marks(out)
