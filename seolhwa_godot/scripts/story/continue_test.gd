# 시작 메뉴에서 이어 하기 / 새 게임 → 말 걸기 시험(region_main --continuetest=continue|new — tools/run_story_tests.sh continue:*). 헤드리스로 돈다.
#   그냥 실행과 같은 길: 시작 메뉴가 떠 있는지 본 뒤 메뉴를 고른다(project.godot 첫 장면이 region.tscn이 아니면 알림 줄).
#   --continuefixture=<저장 json>  이야기를 세우기 전에 시험 저장 파일(--savefile)에 통째로 깐다(옛 저장 그대로 이어 하기).
#   메뉴를 닫고 이야기가 한가해지면(새 게임은 여는 장면 S0001을 자동으로 넘긴 뒤):
#     1 이야기 인물 곁 — E 대상이 그 인물이고, E 키(입력 이벤트)로 말이 열린다(S.talked가 는다).
#     2 고을 사람 곁 — E 대상이 고을 사람이고, E 키로 말 걸기가 된다(ambient.last가 바뀐다).
#   통과하면 "CONTTEST PASS", 아니면 "CONTTEST FAIL <까닭>".
extends RefCounted

const Progress := preload("res://scripts/region/progress.gd")
const GameSettings := preload("res://scripts/story/game_settings.gd")
const GAME_SCENE := "res://scenes/region.tscn"

var main
var d
var _fails: Array = []

func _init(m) -> void:
	main = m

# 이야기보다 먼저(region_main._ready): 시험 저장을 깐다
static func apply_fixture(args: Dictionary) -> void:
	if not args.has("continuefixture"): return
	if args.has("savefile"): Progress.use_path(String(args.savefile))
	var j = JSON.parse_string(FileAccess.get_file_as_string(String(args.continuefixture)))
	if not (j is Dictionary):
		print("CONTTEST fixture 읽기 실패 ", args.continuefixture); return
	var dd := Progress.data()
	dd.clear()
	dd.merge(j, true)
	Progress.save()
	print("CONTTEST fixture %s where=%s" % [args.continuefixture, JSON.stringify(dd.get("where", {}))])

func _fail(why: String) -> void:
	_fails.append(why)
	print("CONTTEST check FAIL ", why)

func _ok(cond: bool, why: String) -> void:
	if cond: print("CONTTEST check ok ", why)
	else: _fail(why)

func _wait_until(f: Callable, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < sec * 1000.0:
		if f.call(): return true
		await main._wait_frames(1)
	return f.call()

func _press_e() -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		ev.keycode = KEY_E
		ev.pressed = down
		Input.parse_input_event(ev)
		await main._wait_frames(2)

func run(spec: String) -> void:
	GameSettings.test_override = { guide = "early", help = "normal" }
	# 그냥 실행(godot --path .)이 여는 장면 — 게임 장면이 아니면 시작 메뉴·이야기 없이 걷기만 된다(알림만, 판정에는 넣지 않는다)
	var ms := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	if ms != GAME_SCENE: print("CONTTEST note 첫 장면이 %s — 게임은 godot --path . %s 로 연다" % [ms, GAME_SCENE])
	await main._wait_frames(10)
	await _wait_until(func(): return not main._loading, 120.0)
	d = main.story
	if d == null or d.S == null:
		_finish("이야기 없음"); return
	await _wait_until(func(): return d.title != null and d.title.active, 10.0)
	_ok(d.title != null and d.title.active, "시작 메뉴가 떠 있음")
	if d.title == null or not d.title.active:
		_finish(""); return
	d.ui.auto = true
	print("CONTTEST pick %s phase=%s seen=%s" % [spec, d.S.phase, d.S.seen.keys()])
	d.title._pick(0 if spec == "new" else 1)
	# 메뉴가 닫히고, 이야기가 시작되고(새 게임은 여는 장면), 조작이 풀릴 때까지
	await _wait_until(func(): return d.title == null or not is_instance_valid(d.title) or not d.title.active, 10.0)
	await main._wait_frames(30)
	var idle := func(): return d._started and not d.blocks_move() and not d.runner.busy and not d.combat_view.active
	_ok(await _wait_until(idle, 120.0), "이야기 한가함 started=%s busy=%s modal=%s cut=%s" % [d._started, d.runner.busy, d.ui.modal, d._cut])
	_ok(d.S.phase != "start", "phase=" + String(d.S.phase))
	print("CONTTEST state phase=%s seen=%s talked=%s" % [d.S.phase, d.S.seen.keys(), d.S.talked])
	await _story_actor()
	await _ambient()
	_finish("")

# 1 이야기 인물: 말할 거리가 있는 인물(가까운 순) 곁으로 가서 E — 140m 밖 인물은 안 그리므로 보임은 따지지 않는다
func _story_actor() -> void:
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var tgt = null; var bd := INF
	# 인물이 제자리에 섰나 — 자리 이름이 인물 id와 같으면 (0,0)에 서던 일(주모·손님·포수·방앗간 주인)
	var stray: Array = []
	for id in d.actors:
		var a: Dictionary = d.actors[id]
		if a.shown and Vector2(a.pos.x, a.pos.z).length() < 1.0: stray.append(id)
	_ok(stray.is_empty(), "인물이 제자리(세상 한가운데에 선 인물 %s)" % [stray])
	for id in d.actors:
		var a: Dictionary = d.actors[id]
		if not a.shown or a.spec.get("talk") == null: continue
		if not a.spec.talk.any(func(t): return d.runner.cond(t.get("when", true))): continue
		var ap := Vector2(a.pos.x, a.pos.z)
		if ap.distance_to(pp) < bd: bd = ap.distance_to(pp); tgt = { id = String(id), p = ap, label = String(a.name) }
	if tgt == null:
		_fail("말 걸 이야기 인물이 없음"); return
	var id := String(tgt.id)
	var p: Vector2 = tgt.p + Vector2(0.8, 0.0)
	main.teleport(p.x, p.y)
	var near := func(): return d._target != null and String(d._target.get("id", "")) == id
	_ok(await _wait_until(near, 3.0), "E 대상 = 이야기 인물 %s (안내 '%s')" % [id, String(tgt.label)])
	var n0 := int(d.S.talked.get(id, 0))
	await _press_e()
	var opened := func(): return int(d.S.talked.get(id, 0)) > n0
	_ok(await _wait_until(opened, 3.0), "E로 %s와 말이 열림" % id)
	await _wait_until(func(): return not d.runner.busy and not d.ui.modal, 60.0)

# 2 고을 사람: 이야기 인물에서 떨어진 고을 사람 곁으로 가서 E
func _ambient() -> void:
	var npc = main.npcs_amb
	if npc == null:
		_fail("고을 사람 없음"); return
	var targets: Array = d._targets()
	var pp := Vector2(main.player_pos.x, main.player_pos.z)
	var keys: Array = npc.agents.keys().filter(func(k):
		var ag: Dictionary = npc.agents[k]
		if ag.animal or String(ag.mode) == "gull": return false
		var ap := Vector2(ag.pos.x, ag.pos.z)
		return not targets.any(func(t): return ap.distance_to(t.p) < float(t.r) + 3.0))
	keys.sort_custom(func(a, b): return Vector2(npc.agents[a].pos.x, npc.agents[a].pos.z).distance_to(pp) < Vector2(npc.agents[b].pos.x, npc.agents[b].pos.z).distance_to(pp))
	var tried := 0
	for key in keys:
		if not npc.agents.has(key): continue
		var ag: Dictionary = npc.agents[key]
		tried += 1
		if tried > 12: break
		main.teleport(ag.pos.x + 0.9, ag.pos.z)
		var amb := func(): return d._target != null and String(d._target.kind) == "ambient" and not d.ui.busy_input() \
			and not d.runner.busy and not d.blocks_move()
		if not await _wait_until(amb, 2.0): continue
		var before: Dictionary = d.ambient.last.duplicate()
		var label := String(d._target.label)
		await _press_e()
		var talked := func(): return d.ambient.busy or d.ambient.last != before
		var ok: bool = await _wait_until(talked, 3.0)
		if not ok: print("CONTTEST state target=%s busy_input=%s runner=%s modal=%s amb_busy=%s" % [d._target, d.ui.busy_input(), d.runner.busy, d.ui.modal, d.ambient.busy])
		_ok(ok, "E로 고을 사람과 말 걸기(%s)" % label)
		await _wait_until(func(): return not d.ambient.busy, 20.0)
		return
	_fail("E 대상이 되는 고을 사람을 못 찾음(시도 %d)" % tried)

func _finish(why: String) -> void:
	if why != "": _fails.append(why)
	if _fails.is_empty(): print("CONTTEST PASS")
	else: print("CONTTEST FAIL ", "; ".join(_fails))
	main._quit()
