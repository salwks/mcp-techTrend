# 이야기 총괄 — 권역 장면(region_main) 위에서 사건 하나를 돌린다(웹 src/story/index.js + 코어 연결 대응).
#   - 사건 데이터(story/<사건>/<사건>_data.gd: 사건 장면 §44 필드 + 단계 목록, 인물·조사 대상·자리·싸움터·소품)와
#     사건 GDScript(story/<사건>/<사건>_case.gd: 기록책·결말·복잡한 연출)를 읽는다.
#   - 상태(story_state) 저장·불러오기(progress.gd), 명령 실행(story_runner), UI(story_ui), 전투(combat_view)
#   - 조사 안내: 가장 가까운 이야기 대상(인물·물건)을 E로. R: 사건 기록. 컷신·대화 중에는 플레이어 조작을 막는다.
#   - 소품: 조건(when)이 참일 때만 보이는 키트·데칼(단서·지역 변화). 인물: 조건·국면(phase)별 자리.
#   - 소문(story/rumors_data.gd): 결말(§7 CASE_*_OUTCOME)에 따라 달라지는 주변 대화 — 권역·노정 어디서나. 엿들은 소문도 기록책 '들음'.
#   - 고을 사람 말 걸기(scripts/story/ambient_talk.gd): 이야기 대상이 없을 때 가까운 주변 인물에게 E — 사건 없는 공간에서도.
#   - 이야기 인물 말 표시: 새로 할 말이 있는 인물(talk 항목 조건이 맞고 그 줄을 아직 안 들음 — talk_pending)은 머리 위 「…」(onboarding).
#     흔한 바탕 그림(마을 사람 등)을 쓰는 이야기 인물은 테두리에 옅은 붉은 먹빛(accent)을 더해 고을 사람과 섞이지 않게.
# region_main은 create_for()로 만들고 매 프레임 update(dt), blocks_move(), drives_player(), shake_offset()만 부른다.
extends Node

const StoryUI := preload("res://scripts/story/story_ui.gd")
const StoryState := preload("res://scripts/story/story_state.gd")
const StoryRunner := preload("res://scripts/story/story_runner.gd")
const CombatView := preload("res://scripts/combat/combat_view.gd")
const Progress := preload("res://scripts/region/progress.gd")
const Rumors := preload("res://story/rumors_data.gd")
const Skills := preload("res://scripts/story/skills.gd")

# 권역 → 사건
# 한 사건이 여러 공간(권역 + 노정)에 걸치면 같은 사건 id를 준다(진행은 하나). 데이터 항목의 "space"로 공간을 가른다(_filter_space)
const CASES := { "JL_NAMWON_UNBONG": "namwon", "GG_HANYANG": "hanyang", "GW_GANGNEUNG": "gangneung",
	"HH_HWANGJU": "hwangju", "HH_HWANGJU-JANGSANGOT": "hwangju", "GS_GYEONGJU": "gyeongju", "PA_PYEONGYANG": "pyongyang",
	"PA_PYEONGYANG-HG_HAMHEUNG": "hamhung", "HG_HAMHEUNG": "hamhung", "HG_HAMHEUNG-BUKCHEONG": "hamhung",
	"SEA_NAMHAE_JEJU": "jeju", "JJ_JEJU": "jeju" }
const KIND_FALLBACK := { story_girl = "child_girl", story_boy = "child_boy", ricecake_mother = "villager_f", farmwife = "villager_f",
	peddler = "villager_m", merchant = "villager_m", traveler = "villager_m", scholar = "elder",
	woochi = "villager_m", chaekkwae = "merchant", pojol = "official",
	wolsim = "shaman", thief = "villager_m", spirit_m = "elder",
	blind_elder = "elder", broker = "merchant", daughter = "villager_f", fisher = "boatman",
	smuggler = "villager_m", smuggler_b = "villager_m", lantern_wife = "villager_f", charcoal_man = "villager_m", spirit_f = "spirit_m",
	py_merchant_a = "merchant", py_merchant_b = "peddler", py_swindler = "smuggler", py_swindler_b = "smuggler_b", py_clerk = "official",
	yigyeom = "elder", courier = "villager_m", courier_b = "villager_m", courier_c = "villager_m", raider = "smuggler", raider_b = "smuggler_b",
	gwak = "elder", simbang = "shaman", jj_child = "child_girl", jj_man = "villager_m", jj_woman = "villager_f", jj_snake = "dog", jj_shade = "spirit_m" }
const BANK_FILES := ["frames_story.json", "frames_story_hanyang.json", "frames_gangneung.json", "frames_story_hwangju.json", "frames_gyeongju.json", "frames_pyongyang.json", "frames_story_hamhung.json", "frames_jeju.json", "frames_npc.json", "frames_amb.json"]

var main                # region_main
var ui
var S
var runner
var combat_view
var case_fn
var data := {}
var events := {}
var case_id := ""
var space_id := ""
var log_story := false
var log_combat := false
var test = null          # story_test(--storytest)
var actors := {}         # id → { spec, ch, pos, facing, scripted, shown, path, speed, end_anim, y_abs, name }
var props := {}          # id → { spec, node, shown, decal_ids }
var _props_root: Node3D
var _dirty := true
var _cut := false
var _target = null
var _trig_t := 0.0
var _started := false
var _rumor_seen := {}
var _rumor_t := 0.0
var _night_roar_t := 0.0
var _bank_src := {}
var passive := false     # --bench·--tour·--shot 등 시험 실행: 여는 장면·순간이동 없이 인물·소품만
var free_move := false   # 추격(scripts/story/chase.gd) 동안: 이야기가 돌고 있어도 플레이어가 움직인다
var title = null         # 시작 메뉴(scripts/story/title_menu.gd) — 열려 있는 동안 이야기를 멈춘다
var _where_t := 0.0
var _resumed := false
var onboard = null             # scripts/story/onboarding.gd
var _skills_msgs: Array = []   # 사건이 끝나 새로 익힌 행동(결말 카드 뒤 한 줄씩)
var _vign = null               # 길가 장면(scripts/story/vignettes.gd — v2.2 R0104 등, 사건 기록 없음)
var _rub = null                # 탁본(scripts/story/rubbing.gd — SKILL_RUBBING, 어느 공간에서나)
var ambient = null             # 고을 사람 말 걸기(scripts/story/ambient_talk.gd)
# 고을 사람(주변 인물)과 같은 바탕 그림 — 이걸 쓰는 이야기 인물에는 테두리 빛을 더한다
const GENERIC_KINDS := ["villager_m", "villager_f", "elder", "child_boy", "child_girl", "hunter", "innkeeper", "miller", "woodcutter",
	"scholar", "merchant", "peddler", "official", "monk", "bosal", "boatman", "haenyeo", "farmer", "farmwife", "herder", "raincape", "traveler", "shaman"]
const ACCENT := Color("#e6b48c")   # 한지빛 테두리 대신 옅은 주홍 한지(아주 약하게)

# 사건 완료(v2.2 레벨 없음): CASE_<키>_COMPLETE를 세우고 숙련 해금표(skills.gd)를 훑는다
func _case_complete() -> Array:
	S.vars[Skills.complete_var(data.get("case", {}), case_id)] = true
	var got := Skills.unlock(S.vars)
	if not got.is_empty(): runner.log_line("skills", got)
	return got
var spirits = null       # 잔영·소리·경계·호신물(scripts/story/spirits.gd) — 사건마다
var sensing = null       # 감응 매듭·흔적의 결(scripts/story/sensing.gd) — 사건마다(매듭을 지닐 때만 그린다)

static func create_for(m) -> Node:
	var rid := String(m.world.region.get("region_id", ""))
	var d = load("res://scripts/story/story_director.gd").new()
	d.main = m
	d.space_id = rid
	d.case_id = CASES.get(rid, "")
	m.add_child(d)
	d._setup()
	return d

# ---- region_main이 부르는 것 ----
func blocks_move() -> bool:
	return (runner != null and runner.busy and not free_move) or (ui != null and (ui.modal or ui.journal_open)) or _cut or (title != null and title.active)

func drives_player() -> bool:
	return combat_view != null and combat_view.active

# 이 프레임 플레이어 이동을 이야기가 쥐고 있나(전투 중이거나 대화·컷신으로 막힘)
func owns_player() -> bool:
	return drives_player() or blocks_move()

func shake_offset() -> Vector3:
	return combat_view.shake_offset if combat_view != null else Vector3.ZERO

# combat_view가 쓰는 것
var world:
	get: return main.world
var player:
	get: return main.player
var player_pos:
	get: return main.player_pos
var cam:
	get: return main.cam
var rig:
	get: return main.rig
func scene_root() -> Node: return main.scene_vp
func set_player_pos(p: Vector3) -> void:
	main.player_pos = p
	main.player.position = p

# ---------------------------------------------------------------------------
# 준비
# ---------------------------------------------------------------------------
func _setup() -> void:
	name = "story"
	var args: Dictionary = main.args
	log_story = args.has("storylog") or args.has("storytest")
	log_combat = log_story
	if args.has("savefile"): Progress.use_path(String(args.savefile))
	elif args.has("storytest"): Progress.use_path("user://storytest_progress.json")
	_setup_input()
	ui = StoryUI.new()
	add_child(ui)
	ui.log_lines = log_story
	onboard = load("res://scripts/story/onboarding.gd").new(self)   # 처음 하는 사람 안내·먹점·Esc 메뉴(사건 없는 공간에서도)
	add_child(onboard)
	ambient = load("res://scripts/story/ambient_talk.gd").new(self)
	add_child(load("res://scripts/story/save_keeper.gd").new(self))   # 저장이 보이게: 자동 기록 도장·주막 쉬기·저장 칸(Esc)
	_props_root = Node3D.new(); _props_root.name = "story_props"
	main.scene_vp.add_child(_props_root)
	if case_id == "":
		_maybe_title()
		return   # 소문만(노정·다른 권역)
	var ddir := "res://story/%s/" % case_id
	data = load(ddir + case_id + "_data.gd").data()
	_filter_space()
	events = data.get("events", {})
	var test_path := ddir + case_id + "_test.gd"
	# 대본 시험이 앞 사건 저장을 꾸민다 — 시험 도중 다른 공간으로 넘어온 장면(같은 사건의 노정 등)이면 꾸미지 않고 이어 간다
	var arrived: bool = not main._pending.is_empty() and not bool(main._pending.get("newgame", false))
	if args.has("storytest") and FileAccess.file_exists(test_path):
		var ts: Script = load(test_path)
		if ts == null or not ts.can_instantiate():   # 시험 스크립트 해석 오류 — 시간 초과까지 멈춰 있지 말고 바로 FAIL
			print("STORYTEST FAIL %s 시험 스크립트를 불러오지 못함(%s)" % [String(args.storytest), test_path])
			main._quit.call_deferred(); return
		if not arrived: ts.prepare(self)
	# 앞 사건이 끝나야 서는 사건(case.requires {변수: 값}) — 아니면 소문만. 쉼표 목록 값(MAIN_MASTER_TRACE "HANYANG,GANGNEUNG")은 들어 있으면 맞음
	for k in data.get("case", {}).get("requires", {}):
		var have := str(Progress.get_var(k, ""))
		var want := str(data.case.requires[k])
		if have != want and not have.split(",").has(want):
			printerr("STORY case=%s 아직 아님(%s)" % [case_id, k])
			case_id = ""; data = {}; events = {}
			_maybe_title()
			return
	S = StoryState.new(case_id)
	runner = StoryRunner.new(self, S)
	case_fn = load(ddir + case_id + "_case.gd").new(self)
	runner.case_fn = case_fn
	combat_view = CombatView.new()
	combat_view.name = "combat"
	main.scene_vp.add_child(combat_view)
	combat_view.setup(self)
	SpriteChar.merge_bank("frames_story_skills.json", ["player"])   # v2.2 숙련 동작(shove·quick_throw, 작다) — 없으면 그냥 지나간다
	var fresh: bool = (args.has("newgame") or args.has("storytest")) and not arrived
	if fresh: S.clear_saved(data.get("case", {}).get("reset_vars", null))
	elif S.load_saved():
		printerr("STORY loaded case=%s phase=%s flags=%d clues=%d" % [case_id, S.phase, S.flags.size(), S.clues.size()])
	for a in data.get("actors", []): _make_actor(a)
	spirits = load("res://scripts/story/spirits.gd").new()
	add_child(spirits)
	spirits.setup(self)
	sensing = load("res://scripts/story/sensing.gd").new()
	add_child(sensing)
	sensing.setup(self)
	passive = not args.has("storytest") and (args.has("bench") or args.has("tour") or args.has("shot") or args.has("portaltest") or args.has("walkroute") or args.has("talktest"))
	if args.has("storytest"):
		test = load(test_path if FileAccess.file_exists(test_path) else "res://scripts/story/story_test.gd").new(self, String(args.storytest))
		add_child(test)
	_maybe_title()
	printerr("STORY ready case=%s phase=%s actors=%d props=%d events=%d" % [case_id, S.phase, actors.size(), data.get("props", []).size(), events.size()])

# 여러 공간에 걸친 사건: 항목에 "space"(공간 id 하나 또는 배열)가 있으면 그 공간에서만 쓴다
func _filter_space() -> void:
	for key in ["actors", "objects", "triggers", "props", "spirits", "rubbings", "map_places"]:
		if not (data.get(key) is Array): continue
		data[key] = data[key].filter(func(e): return not (e is Dictionary and e.has("space")) or \
			(e.space is Array and e.space.has(space_id)) or String(e.space) == space_id)

func _setup_input() -> void:
	for act in { interact = KEY_E, journal = KEY_R }:
		if not InputMap.has_action(act): InputMap.add_action(act)
	var ev := InputEventKey.new(); ev.physical_keycode = KEY_E
	if InputMap.action_get_events("interact").is_empty(): InputMap.action_add_event("interact", ev)
	var ev2 := InputEventKey.new(); ev2.physical_keycode = KEY_R
	if InputMap.action_get_events("journal").is_empty(): InputMap.action_add_event("journal", ev2)

# ---------------------------------------------------------------------------
# 프레임
# ---------------------------------------------------------------------------
func update(dt: float) -> void:
	if main._loading: return
	if title != null and title.active: return
	if not _resumed:
		_resumed = true
		if main._pending.has("resume_at"): teleport_to(main._pending.resume_at)   # 이어 하기로 다른 공간에서 넘어옴
	_save_where(dt)
	if _vign == null: _vign = load("res://scripts/story/vignettes.gd").new(self)
	_vign.update(dt)
	# 대본 시험: 싸움은 프레임마다 고정 걸음(시험 봇도 1/60초 걸음으로 판단한다) — 기계 부하·프레임 흔들림에 결과가 바뀌지 않게
	if combat_view != null: combat_view.update(Engine.time_scale / 60.0 if test != null and combat_view.active else dt)
	if _rub == null:
		_rub = load("res://scripts/story/rubbing.gd").new(); add_child(_rub); _rub.setup(self)
	if case_id == "":
		_update_rumors(dt)
		_rub.update(dt)
		if ui.modal or ui.journal_open or ambient.busy:
			ui.prompt(""); _target = null
		else: _update_target()
		return
	if not _started:
		_started = true
		_apply_world()
		var cs: Dictionary = data.get("case", {})
		var arrive_ok: bool = main._pending.is_empty() or bool(cs.get("start_on_arrival", false)) or bool(main._pending.get("newgame", false))
		if S.phase == "start" and arrive_ok and not passive:
			var se = cs.get("start_event", "S0001")
			if se is Dictionary: se = se.get(space_id, "")   # 공간마다 다른 첫 장면("" = 그 공간에서는 시작하지 않음)
			if String(se) == "": S.phase = "start"
			elif test == null: runner.run([{ "event": String(se) }])
		elif S.phase == "start":
			S.phase = "explore"
		if test != null: test.begin()
	if blocks_move() and not drives_player() and main.player.anim in ["walk", "run"]: main.player.set_anim("idle")
	_update_actors(dt)
	if _dirty: _refresh()
	_update_props()
	_update_rumors(dt)
	_update_ambient(dt)
	if spirits != null: spirits.update(dt)
	if sensing != null: sensing.update(dt)
	if runner.busy or ui.modal or combat_view.active or ambient.busy:
		ui.prompt("")
		_target = null
		return
	_trig_t -= dt
	if _trig_t <= 0.0:
		_trig_t = 0.2
		_check_triggers()
	_update_target()
	_rub.update(dt)

func _unhandled_input(ev: InputEvent) -> void:
	if main._loading or (title != null and title.active): return
	if not (ev is InputEventKey and ev.pressed and not ev.echo): return
	# 기록책(여행 기록·사건 기록·여행 방법)은 사건이 없는 노정에서도 연다
	if ev.is_action("journal") and not ui.modal and not (combat_view != null and combat_view.active) and (case_id == "" or _started):
		ui.journal_toggle(journal_data())
		get_viewport().set_input_as_handled()
		return
	# 고을 사람 말 걸기(사건이 없는 공간에서도)
	if ev.is_action("interact") and _target != null and String(_target.kind) == "ambient" and not ui.busy_input() \
			and not (runner != null and runner.busy) and not (combat_view != null and combat_view.active):
		get_viewport().set_input_as_handled()
		ambient.talk(int(_target.key))
		return
	if case_id == "" or not _started: return
	if ev.is_action("interact") and _target != null and not ui.busy_input() and not runner.busy and not combat_view.active:
		get_viewport().set_input_as_handled()
		interact(_target.id)

func journal_data() -> Dictionary:
	return load("res://scripts/story/journal_book.gd").build(self)

func on_story_idle() -> void:
	_dirty = true
	if _cut: cutscene(false)
	S.time = main.hour
	save()

func on_event(id: String, ev: Dictionary) -> void:
	if log_story: printerr("EVENT %s 「%s」 %s" % [id, ev.get("RECORD_TITLE", ""), ev.get("TRIGGER", "")])

func on_phase() -> void:
	if S.phase == "done": _skills_msgs.append_array(_case_complete())
	for id in actors:
		var a: Dictionary = actors[id]
		if not a.scripted: _place_home(a)
	_dirty = true

func mark_dirty() -> void: _dirty = true

func save() -> void:
	if S == null or (test != null and not main.args.has("storysave")): return
	S.save()
	_save_where(INF)

# 이어 하기 자리(progress.gd where): 어느 공간 어디에 있었나 — 10초마다·저장할 때
func _save_where(dt: float) -> void:
	_where_t -= dt
	if _where_t > 0.0 or test != null or passive or main._loading: return
	_where_t = 10.0
	var w = main.world
	var wp: Vector2 = main.where_outside() if main.has_method("where_outside") else Vector2(main.player_pos.x, main.player_pos.z)   # 실내 공간 안이면 그 입구 밖
	Progress.set_where({ space = space_id, kind = "route" if w.is_route else "region", x = snappedf(wp.x, 0.1),
		z = snappedf(wp.y, 0.1), hour = snappedf(main.hour, 0.1) })

# 시작 메뉴(새 게임 / 이어 하기): 그냥 실행했을 때만(시험·넘어온 장면·--newgame·--continue·--notitle 아님)
func _maybe_title() -> void:
	var args: Dictionary = main.args
	for k in ["storytest", "bench", "tour", "shot", "portaltest", "walkroute", "newgame", "continue", "notitle", "refset", "warp", "talktest"]:
		if args.has(k): return
	if not main._pending.is_empty(): return
	title = load("res://scripts/story/title_menu.gd").new(self)
	add_child(title)

func outcome_var() -> String:
	return String(data.get("case", {}).get("outcome_var", "CASE_NAMWON_OUTCOME"))

func wait(sec: float) -> void:
	if ui.auto and not ui.auto_real: sec = minf(sec, 0.05)
	await get_tree().create_timer(sec, true, false, true).timeout

# ---------------------------------------------------------------------------
# 상태 바꾸기(알림 포함)
# ---------------------------------------------------------------------------
func learn_clue(id: String, quiet := false) -> void:
	if S.has_clue(id): return
	S.clues.append(id)
	runner.log_line("clue", id)
	var c: Dictionary = data.get("clues", {}).get(id, {})
	if not quiet and not c.is_empty(): ui.toast("단서 — " + String(c.title), "clue")
	_dirty = true
	if case_fn.has_method("on_clue"): case_fn.on_clue(id)

func learn_rule(id: String, quiet := false) -> void:
	if S.knows(id): return
	S.rules.append(id)
	runner.log_line("rule", id)
	var c: Dictionary = data.get("rules", {}).get(id, {})
	if not quiet and not c.is_empty(): ui.toast("%s — %s" % [String(data.get("case", {}).get("rule_label", "범의 버릇")), String(c.title)], "rule")
	_dirty = true

func item_label(id: String) -> String:
	return String(data.get("items", {}).get(id, id))

func give(id: String, nn := 1, quiet := false) -> void:
	S.items[id] = S.count(id) + nn
	runner.log_line("give", [id, nn])
	if not quiet: ui.toast(("%s %d개를 얻었다" % [item_label(id), nn]) if nn > 1 else ("%s을(를) 얻었다" % item_label(id)), "item")
	_sync_items()
	_dirty = true

func take(id: String, nn := 1) -> void:
	S.items[id] = maxi(0, S.count(id) - nn)
	if S.items[id] == 0: S.items.erase(id)
	runner.log_line("take", [id, nn])
	_sync_items()
	_dirty = true

func _sync_items() -> void:
	var list := []
	var hidden: Array = data.get("hidden_items", [])
	for id in S.items:
		if S.items[id] > 0 and not hidden.has(id): list.append({ label = item_label(id), count = S.items[id] })
	ui.items(list)

func journal_note(t: String) -> void:
	S.notes.append(t)
	ui.toast("기록 — " + t, "journal")

func world_state(k: String, v) -> void:
	S.world[k] = v
	runner.log_line("world", [k, v])
	_dirty = true

func set_hour(h: float) -> void:
	main.hour = fposmod(h, 24.0)
	main._apply_time()
	S.time = main.hour

func set_weather(k: String) -> void:
	var wthr = main.weather
	if wthr == null: return
	if k == "" or k == "release":
		if wthr.has_method("release"): wthr.release(2.0)
	elif wthr.has_method("force"): wthr.force(k, -1.0, 0.0)
	else: wthr.forced = k; wthr.kind = k

func cutscene(on: bool) -> void:
	_cut = on
	ui.letterbox(on)

# 소리 자리(소리 체계는 아직 없다): 연출이 소리 낼 순간마다 부른다. 지금은 신호만 낸다 — 소리 작업이 sfx_cue에 붙어 채운다.
#   남원 동아줄: rope_creak(줄 삐걱) · rope_snap(줄 끊김) · fall_impact(수수밭에 떨어짐) · wind(바람)
signal sfx_cue(id: String)
func sfx(id: String) -> void:
	sfx_cue.emit(id)

# 화면 흔들림 설정(놀이 설정 cam_shake)이 꺼져 있나 — 꺼져 있으면 큰 충격은 암전으로 대신한다
func shake_enabled() -> bool:
	return load("res://scripts/story/game_settings.gd").get_v("cam_shake") != "off"

func shake(p: float, sec: float) -> void:
	if combat_view != null: combat_view.shake(p, sec * 1000.0)

func camera(spec) -> void:
	if spec == null or (spec is Dictionary and spec.is_empty()):
		main.rig.override = null; main.rig.focus = null; return
	if spec.has("focus"):
		if spec.focus == null: main.rig.focus = null
		else:
			var p := anchor(spec.focus)
			main.rig.focus = { x = p.x, z = p.y }
	var o := {}
	for kk in ["pitch", "distance", "fov"]:
		if spec.has(kk): o[kk] = float(spec[kk])
	main.rig.override = o if not o.is_empty() else null

# ---------------------------------------------------------------------------
# 자리
# ---------------------------------------------------------------------------
func anchor(at) -> Vector2:
	if at is Vector2: return at
	if at is Array and at.size() >= 2: return Vector2(float(at[0]), float(at[1]))
	if at is Dictionary:
		if at.has("x"): return Vector2(float(at.x), float(at.z))
		return anchor(at.get(S.phase, at.get("default", [0, 0])))
	var s := String(at)
	if s == "player": return Vector2(main.player_pos.x, main.player_pos.z)
	if actors.has(s): return Vector2(actors[s].pos.x, actors[s].pos.z)
	var an: Dictionary = data.get("anchors", {})
	if an.has(s): return anchor(an[s])
	push_warning("이야기: 모르는 자리 " + s)
	return Vector2(main.player_pos.x, main.player_pos.z)

func teleport_to(at, face := "") -> void:
	var p := anchor(at)
	main.teleport(p.x, p.y)
	if face != "": main.player.facing = face
	main.rig.update(0, main.player_pos, main.player.facing, null, true)

func arena(id: String) -> Dictionary:
	var a: Dictionary = data.get("arenas", {}).get(id, {}).duplicate(true)
	if a.is_empty(): return {}
	var c := anchor(a.get("at", [0, 0]))
	a.id = id; a.x = c.x; a.z = c.y
	if a.has("player_start"): a.player_start = anchor(a.player_start)
	if a.has("tiger_start"): a.tiger_start = anchor(a.tiger_start)
	if a.has("tiger_offset"): a.tiger_start = c + anchor(a.tiger_offset)   # 플레이어 자리 기준 싸움터(첫 조우)
	return a

# ---------------------------------------------------------------------------
# 인물
# ---------------------------------------------------------------------------
func _ensure_bank(kind: String) -> String:
	if SpriteChar._banks.has(kind): return kind
	if _bank_src.is_empty():
		for jf in BANK_FILES:
			var path: String = "res://data/" + jf
			if not FileAccess.file_exists(path): continue
			var all = JSON.parse_string(FileAccess.get_file_as_string(path))
			if all is Dictionary:
				for k in all:
					if not _bank_src.has(k): _bank_src[k] = all[k]
	if _bank_src.has(kind):
		var pages := []
		for p in _bank_src[kind].pages:
			var img := Image.load_from_file(ProjectSettings.globalize_path("res://data/" + p))
			if img == null or img.is_empty(): continue
			img.generate_mipmaps()
			pages.append(ImageTexture.create_from_image(img))
		SpriteChar._banks[kind] = { pages = pages, clips = _bank_src[kind].clips }
		return kind
	if KIND_FALLBACK.has(kind): return _ensure_bank(KIND_FALLBACK[kind])
	return "villager_m" if kind != "villager_m" else ""

func _make_actor(spec: Dictionary) -> Dictionary:
	var kind := _ensure_bank(String(spec.get("kind", "villager_m")))
	var ch := SpriteChar.new(kind)
	main.scene_vp.add_child(ch)
	ch.set_silhouette(false)
	ch._sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if spec.has("variant"): ch.variant = String(spec.variant)
	if GENERIC_KINDS.has(kind) and spec.get("accent", true) != false: ch.set_accent(ACCENT)   # 고을 사람과 같은 그림이면 테두리 빛
	var a := { id = String(spec.id), spec = spec, ch = ch, pos = Vector3.ZERO, facing = "down", scripted = false,
		shown = false, path = [], speed = 1.6, end_anim = "idle", y_abs = NAN, name = String(spec.get("name", "")), anim = "idle" }
	actors[a.id] = a
	_place_home(a)
	ch.visible = false
	return a

func _place_home(a: Dictionary) -> void:
	var at = a.spec.get("at")
	if at == null: return
	# 제자리는 이름 붙은 자리(anchors)를 먼저 본다 — 자리 이름이 인물 id와 같으면(주모 "jumo" 등) anchor()가 인물 자신의
	# 아직 안 정한 자리(0,0)를 돌려줘 세상 한가운데에 서 버렸다
	if at is Dictionary and not at.has("x"): at = at.get(S.phase, at.get("default", [0, 0]))
	if at is String and data.get("anchors", {}).has(at): at = data.anchors[at]
	var p := anchor(at)
	a.pos = Vector3(p.x, world.height_at(p.x, p.y), p.y)
	a.y_abs = NAN
	var fc = a.spec.get("facing", "down")
	if fc is Dictionary: fc = fc.get(S.phase, fc.get("default", "down"))
	a.facing = String(fc)
	var an = a.spec.get("anim", "idle")
	if an is Dictionary: an = an.get(S.phase, an.get("default", "idle"))
	a.anim = String(an)
	a.ch.play(a.anim, true)

func actor(id: String):
	return actors.get(id)

func spawn_actor(id: String, kind: String, at, facing: String, nm: String, variant: String) -> void:
	if actors.has(id): despawn_actor(id)
	var a := _make_actor({ id = id, kind = kind, at = at if at != null else "player", facing = facing, name = nm, variant = variant, spawned = true })
	a.scripted = true
	a.shown = true
	a.ch.visible = true
	_dirty = true

func despawn_actor(id: String) -> void:
	var a = actors.get(id)
	if a == null: return
	if a.spec.get("spawned", false):
		a.ch.queue_free(); actors.erase(id)
	else:
		a.scripted = true; a.shown = false; a.ch.visible = false; a.spec["_hidden"] = true
	_dirty = true

func show_actor(id: String, on: bool) -> void:
	var a = actors.get(id)
	if a == null: return
	a.spec.erase("_hidden")
	if not on: a.spec["_hidden"] = true
	a.scripted = true
	_dirty = true

func place_actor(id: String, at, y = null, facing := "") -> void:
	var a = actors.get(id)
	if a == null: return
	a.scripted = true
	a.spec.erase("_hidden")
	if at is String and at == "home":
		a.scripted = false; _place_home(a); _dirty = true; return
	var p := anchor(at)
	a.pos = Vector3(p.x, world.height_at(p.x, p.y), p.y)
	a.y_abs = (a.pos.y + float(y)) if y != null else NAN
	a.path = []
	if facing != "": a.facing = facing
	_dirty = true

func face_actor(id: String, dir, to) -> void:
	var a = actors.get(id) if id != "player" else null
	var d := String(dir) if dir != null else ""
	if to != null:
		var p := anchor(to)
		var from := Vector2(main.player_pos.x, main.player_pos.z) if id == "player" else Vector2(a.pos.x, a.pos.z)
		var v := p - from
		d = "right" if absf(v.x) > absf(v.y) * 1.05 and v.x > 0 else ("left" if absf(v.x) > absf(v.y) * 1.05 else ("down" if v.y > 0 else "up"))
	if d == "": return
	if id == "player": main.player.facing = d
	elif a != null: a.facing = d

func anim_actor(id: String, nm: String, restart := true) -> void:
	if id == "player":
		main.player.play(nm, restart); return
	var a = actors.get(id)
	if a == null: return
	a.anim = nm
	a.ch.play(nm, restart)

# 경로를 따라 걷게 하고 다 걸으면 돌아온다
func move_actor(id: String, to, speed: float, anim_nm: String, end_anim: String) -> void:
	var a = actors.get(id)
	if a == null: return
	var pts := []
	if to is Array and to.size() > 0 and not (to[0] is float or to[0] is int): pts = to
	else: pts = [to]
	a.scripted = true
	a.path = pts.map(func(q): return anchor(q))
	a.speed = speed if not ui.auto else speed * 8.0
	a.end_anim = end_anim
	a.anim = anim_nm
	a.ch.play(anim_nm)
	var g: int = runner.gen
	var guard := 0
	while not a.path.is_empty() and guard < 2000 and g == runner.gen:
		await get_tree().process_frame
		guard += 1
	if not a.path.is_empty(): a.path = []

func _update_actors(dt: float) -> void:
	var pp: Vector3 = main.player_pos
	for id in actors:
		var a: Dictionary = actors[id]
		var ch: SpriteChar = a.ch
		if not a.path.is_empty():
			var tgt: Vector2 = a.path[0]
			var v := tgt - Vector2(a.pos.x, a.pos.z)
			var l := v.length()
			var step: float = a.speed * dt
			if l <= step:
				a.pos = Vector3(tgt.x, world.height_at(tgt.x, tgt.y), tgt.y)
				a.path.pop_front()
				if a.path.is_empty():
					a.anim = a.end_anim; ch.play(a.end_anim, true)
			else:
				var q := Vector2(a.pos.x, a.pos.z) + v / l * step
				a.pos = Vector3(q.x, world.height_at(q.x, q.y), q.y)
			if l > 0.01:
				a.facing = "right" if absf(v.x) > absf(v.y) * 1.05 and v.x > 0 else ("left" if absf(v.x) > absf(v.y) * 1.05 else ("down" if v.y > 0 else "up"))
		if not a.shown: continue
		var d := Vector2(a.pos.x - pp.x, a.pos.z - pp.z).length()
		var near := d < 140.0
		if ch.visible != near: ch.visible = near
		if not near: continue
		ch.position = Vector3(a.pos.x, a.y_abs if not is_nan(a.y_abs) else world.height_at(a.pos.x, a.pos.z), a.pos.z)
		ch.facing = a.facing
		ch.update_char(dt, main.cam)

# ---------------------------------------------------------------------------
# 조건 다시 보기(인물 보이기·소품)
# ---------------------------------------------------------------------------
func _refresh() -> void:
	_dirty = false
	for id in actors:
		var a: Dictionary = actors[id]
		var on: bool = not a.spec.get("_hidden", false) and runner.cond(a.spec.get("when", true))
		if a.spec.get("spawned", false): on = not a.spec.get("_hidden", false)
		if on != a.shown:
			a.shown = on
			if not on: a.ch.visible = false
	for p in data.get("props", []):
		var id := String(p.id)
		if not props.has(id): props[id] = { spec = p, node = null, shown = false, decals = [] }
		var rec: Dictionary = props[id]
		rec.want = runner.cond(p.get("when", true))
	_sync_items()

func _update_props() -> void:
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	for id in props:
		var rec: Dictionary = props[id]
		var want: bool = rec.get("want", false)
		if want == rec.shown and (rec.node != null or not want or rec.spec.has("decal") or rec.spec.has("trail")): continue
		var p: Dictionary = rec.spec
		var at := anchor(p.get("at", [0, 0])) if p.has("at") else Vector2.ZERO
		if want and p.has("kit") and rec.node == null:
			if p.has("at") and pp.distance_to(at) > 260.0: continue
			rec.node = _build_prop(p, at)
		if p.has("decal") or p.has("trail"): _decal_prop(rec, want, at)
		if rec.node != null: rec.node.visible = want
		rec.shown = want

func _build_prop(p: Dictionary, at: Vector2) -> Node3D:
	var path := "res://kit/%s.gd" % String(p.kit)
	if not FileAccess.file_exists(path): push_warning("이야기 소품 키트 없음: " + path); return null
	var info: Dictionary = load(path).build(p.get("params", {}))
	var n: Node3D = info.node
	_props_root.add_child(n)
	var y: float = world.height_at(at.x, at.y) + float(p.get("dy", 0.0))
	if p.has("y"): y = float(p.y)
	n.global_transform = Transform3D(Basis(Vector3.UP, float(p.get("ry", 0.0))), Vector3(at.x, y, at.y))
	for l in info.get("lights", []):
		var o := OmniLight3D.new()
		o.light_color = Color("#ff9a4a"); o.omni_range = 7.0; o.light_energy = 3.0; o.shadow_enabled = false
		o.position = Vector3(l.x, l.y, l.z)
		n.add_child(o)
	return n

# 데칼(world.decals — 사건용 세계 API가 있으면). 없으면 그냥 건너뛴다(키트 소품에 작은 모양이 따로 있다)
func _decal_prop(rec: Dictionary, want: bool, at: Vector2) -> void:
	var dc = world.get("decals")
	if dc == null: return
	if not want:
		for i in rec.decals: dc.remove(i)
		rec.decals = []
		return
	if not rec.decals.is_empty(): return
	var p: Dictionary = rec.spec
	if p.has("decal"):
		var sp: Dictionary = p.decal.duplicate()
		sp.id = "story_" + String(p.id); sp.x = at.x; sp.z = at.y; sp.group = "story"
		if sp.has("dy"):
			sp.y = world.height_at(at.x, at.y) + float(sp.dy); sp.erase("dy")
		rec.decals = [dc.add(sp)]
	else:
		var tr: Dictionary = p.trail
		var pts := []
		for q in tr.points:
			var v := anchor(q)
			pts.append([v.x, v.y])
		var opts := tr.duplicate(); opts.erase("points"); opts.erase("kind"); opts.group = "story"
		rec.decals = dc.trail("story_" + String(p.id), String(tr.kind), pts, opts)

func _apply_world() -> void:
	set_hour(S.time if S.phase != "start" else float(data.get("case", {}).get("start_hour", 10.0)))
	if case_fn.has_method("on_load"): case_fn.on_load()
	if S.phase == "done": _case_complete()   # 이 체계 전에 끝낸 저장도 해금(조용히)
	_dirty = true

# ---------------------------------------------------------------------------
# 조사·대화·자리 트리거
# ---------------------------------------------------------------------------
func _targets() -> Array:
	var out := []
	for id in actors:
		var a: Dictionary = actors[id]
		if not a.shown or not a.ch.visible or a.spec.get("talk") == null: continue
		var talk: Array = a.spec.talk
		var any := false
		for t in talk:
			if runner.cond(t.get("when", true)): any = true; break
		if not any: continue
		out.append({ id = id, kind = "actor", p = Vector2(a.pos.x, a.pos.z), r = float(a.spec.get("radius", 2.2)),
			label = "%s · %s" % [a.name, a.spec.get("verb", "대화")] })
	for o in data.get("objects", []):
		if not runner.cond(o.get("when", true)): continue
		var lab = o.get("label", "")
		if o.has("label_if") and runner.cond(o.label_if[0]): lab = o.label_if[1]
		out.append({ id = String(o.id), kind = "object", p = anchor(o.at), r = float(o.get("radius", 2.0)), label = String(lab), spec = o })
	return out

func _update_target() -> void:
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var best = null; var bd := INF
	if case_id != "" and _started:
		for t in _targets():
			var d: float = pp.distance_to(t.p)
			if d < t.r and d < bd: bd = d; best = t
	if best == null and ambient != null: best = ambient.target(pp)   # 이야기 대상이 먼저, 없으면 고을 사람
	_target = best
	ui.prompt(best.label if best != null else "")

func interact(id: String) -> void:
	if runner.busy: return
	var steps := []
	if actors.has(id):
		var a: Dictionary = actors[id]
		_talk_seen_now(a)
		S.talked[id] = int(S.talked.get(id, 0)) + 1
		for t in a.spec.get("talk", []):
			if runner.cond(t.get("when", true)):
				steps = t.get("steps", []); break
		face_actor(id, null, "player")
		face_actor("player", null, id)
	else:
		for o in data.get("objects", []):
			if String(o.id) == id:
				if not runner.cond(o.get("when", true)): return
				steps = o.get("steps", []); break
	runner.log_line("interact", id)
	if onboard != null: onboard.on_interact("actor" if actors.has(id) else "object")
	_target = null
	ui.prompt("")
	await runner.run(steps)
	if onboard != null: onboard._pend_t = 0.0   # 「…」 바로 다시 본다

func _check_triggers() -> void:
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	for t in data.get("triggers", []):
		var id := String(t.id)
		if t.get("once", true) and S.flags.has("_trig_" + id): continue
		if t.has("at") and pp.distance_to(anchor(t.at)) > float(t.get("radius", 8.0)): continue
		if not runner.cond(t.get("when", true)): continue
		if t.get("once", true): S.flags["_trig_" + id] = true
		runner.log_line("trigger", id)
		if t.has("ambient"):
			_overhear(t.ambient)   # 지나가며 엿듣는 주변대화 — 조작을 막지 않는다
			return
		var steps: Array = t.get("steps", [])
		if t.has("event"): steps = [{ "event": t.event }]
		runner.run(steps)
		return

# ---------------------------------------------------------------------------
# 전투·결말
# ---------------------------------------------------------------------------
func combat(arena_id: String, st: Dictionary) -> String:
	var a := arena(arena_id)
	if a.is_empty():
		push_warning("이야기: 없는 싸움터 " + arena_id); return "win"
	var opts := { mods = st.get("mods", {}).duplicate(), allow_flee = st.get("allow_flee", true), place_player = st.get("place_player", false) }
	if case_fn.has_method("combat_mods"): opts.mods = case_fn.combat_mods(arena_id, opts.mods)
	if st.has("retreat_at"): opts.retreat_at = st.retreat_at
	if a.has("focus"): opts.focus = anchor(a.focus)
	if a.has("retreat_to"): opts.retreat_to = anchor(a.retreat_to)
	if st.has("seed"): opts.seed = st.seed
	elif test != null: opts.seed = int(main.args.get("combatseed", "1870"))   # 대본 시험은 정해진 난수(--combatseed로 바꿈)
	if test != null: combat_view.bot = test.combat_bot
	ui.prompt("")
	combat_view.start(a, opts)
	# 떡 던지기는 가진 떡으로(최대 3개) — 던진 만큼 소지품에서 뺀다
	var tteok_id := String(data.get("combat_bait_item", "ITM_LIFE_001"))
	var bait0 := mini(3, S.count(tteok_id))
	combat_view.battle.player.bait = bait0
	combat_view.battle.player.skills = { guard_shove = bool(S.vars.get("SKILL_GUARD_SHOVE", false)) or main.args.has("allskills"),
		quick_throw = bool(S.vars.get("SKILL_QUICK_THROW", false)) or main.args.has("allskills") }   # --allskills: 시험용
	var res: String = await combat_view.finished
	var used: int = bait0 - int(combat_view.battle.player.bait)
	if used > 0: take(tteok_id, used)
	return res

func _overhear(lines: Array) -> void:
	for l in lines:
		await ui.caption("%s  “%s”" % [String(l[0]), String(l[1])], 2.2)

func end_combat() -> void:
	if combat_view != null: combat_view.reset()

func show_ending() -> void:
	var d: Dictionary = case_fn.ending_data() if case_fn.has_method("ending_data") else {}
	await ui.ending(d)
	for n in _skills_msgs: await ui.caption("새 행동을 익혔다 — " + String(n), 2.4)
	_skills_msgs.clear()

# ---------------------------------------------------------------------------
# 지역 변화(밤 울음소리 등)와 소문
# ---------------------------------------------------------------------------
func _update_ambient(dt: float) -> void:
	if case_fn != null and case_fn.has_method("ambient"): case_fn.ambient(dt)

func _update_rumors(dt: float) -> void:
	_rumor_t -= dt
	if _rumor_t > 0.0 or (runner != null and runner.busy) or ui.modal: return
	_rumor_t = 0.5
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var outcome_vals := Progress.vars()
	for r in Rumors.for_space(space_id, world.region):
		var id := String(r.id)
		if _rumor_seen.has(id): continue
		if pp.distance_to(r.p) > float(r.get("radius", 26.0)): continue
		var line: String = Rumors.pick(r, outcome_vals, S.vars if S != null else {})
		if line == "": continue
		_rumor_seen[id] = true
		printerr("RUMOR %s [%s] %s" % [id, r.get("speaker", ""), line])
		Progress.add_heard({ id = id, space = space_id, by = String(r.get("speaker", "")), text = line, place = "" })   # 엿들은 말도 '들음'(사실 아님)
		ui.caption("%s  “%s”" % [String(r.get("speaker", "")), line], 4.0)
		return

# ---------------------------------------------------------------------------
# 새로 할 말이 있는 이야기 인물(머리 위 「…」 — onboarding._update_talk_marks)
#   지금 고를 talk 항목(조건이 맞는 첫 항목)의 '서명'을 아직 안 들었으면 참. 서명 = 항목 번호 + 조건부 대사·if 결과 + 고를 수 있는 물음.
#   이미 말을 나눈 사람의 '늘(true)' 대사만 있는 항목(되풀이 잡담)과, 고를 물음이 다 떨어진 항목은 새 말이 아니다.
#   들은 서명은 S.seen._talk { 인물: [서명] } — 이 표시는 '할 말이 있다'일 뿐, 거짓말·정답을 뜻하지 않는다.
# ---------------------------------------------------------------------------
const SAY_KEYS := ["say", "lines", "when"]

func talk_sig(a: Dictionary) -> String:
	var talk = a.spec.get("talk")
	if not (talk is Array) or S == null: return ""
	var idx := -1
	for i in talk.size():
		if runner.cond(talk[i].get("when", true)): idx = i; break
	if idx < 0: return ""
	var ent: Dictionary = talk[idx]
	var steps: Array = ent.get("steps", [])
	var parts := [str(idx)]
	var say_only := true
	var has_choice := false
	var open_opts := 0
	for st in steps:
		if not (st is Dictionary): continue
		for k in st:
			if not SAY_KEYS.has(k): say_only = false
		if st.has("say") and st.has("when"): parts.append("s%d" % int(runner.cond(st.when)))
		if st.has("if"): parts.append("i%d" % int(runner.cond(st.get("if"))))
		if st.has("choice"):
			has_choice = true
			for o in st.get("options", []):
				if o.get("end", false): continue
				if o.has("when") and not runner.cond(o.when): continue
				open_opts += 1
				parts.append(String(o.get("label", "")))
	var w = ent.get("when", true)
	var always: bool = w is bool or String(w).strip_edges() == "true"
	if say_only and always and int(S.talked.get(String(a.id), 0)) > 0: return ""   # 되풀이 잡담
	if has_choice and open_opts == 0:
		var other := false
		for st in steps:
			if st is Dictionary and not st.has("choice") and not st.has("say"): other = true
		if not other: return ""   # 물을 것을 다 물었다
	return "|".join(parts)

func talk_pending(id: String) -> bool:
	var a = actors.get(id)
	if a == null or not a.shown or a.spec.get("talk") == null: return false
	var sig := talk_sig(a)
	if sig == "": return false
	var seen: Dictionary = S.seen.get("_talk", {})
	return not (seen.get(id, []) as Array).has(sig)

func _talk_seen_now(a: Dictionary) -> void:
	var sig := talk_sig(a)
	if sig == "": return
	var seen: Dictionary = S.seen.get("_talk", {})
	var l: Array = seen.get(String(a.id), [])
	if not l.has(sig): l.append(sig)
	seen[String(a.id)] = l
	S.seen["_talk"] = seen
