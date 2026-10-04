# 전투 한 판을 장면에 잇는다(웹 combat/index.js 대응) — 전투 논리(cbattle)에 높이·충돌(권역 지형)·그림(SpriteChar)·
# 효과(combat_fx)·HUD(story_ui)·입력(키보드 또는 시험용 봇)을 대 준다. 전투 중에는 플레이어 이동을 이 노드가 맡는다.
#   start(arena, opts) → 끝나면 finished(result) 신호: win | repelled | retreated | escaped | lose
#   arena: { id, name, x, z, radius, player_start: Vector2, tiger_start: Vector2, camera: {pitch, distance, fov} }
#   opts:  { mods: {stunned, hpRatio, enraged, firstEncounter}, retreat_at: {hpRatio, seconds}, allow_flee, place_player(기본 false),
#            focus: Vector2(마당 큰 나무), retreat_to: Vector2, seed }
# 조작: J 베기(길게 누르면 모아 베기) · K 구르기 · L 막기(누름) · I 활(누르고 떼기) · U 떡 던지기 · WASD 이동 · Shift 달리기
extends Node3D

signal finished(result: String)

const TU := preload("res://scripts/combat/ctuning.gd")
const CBattle := preload("res://scripts/combat/cbattle.gd")
const CombatFx := preload("res://scripts/combat/combat_fx.gd")
const ACTIONS := ["attack", "dodge", "guard", "bow", "item"]
const KEYS := { c_attack = [KEY_J], c_dodge = [KEY_K], c_guard = [KEY_L], c_bow = [KEY_I], c_item = [KEY_U] }
const TIGER_NAME := "호랑이"

var host            # story_director(world, player, ui, cam, rig, set_player_pos)
var battle
var fxn             # CombatFx 노드
var tiger_ch: SpriteChar = null
var active := false
var ending := false
var result := ""
var options := { telegraph = true, ranges = false, aimAssist = true, hitStop = true }
var bot: Callable = Callable()     # 시험: () → { move: Vector2, held: {attack, dodge, guard, bow, item}, run }
var hitstop := 0.0
var shake_offset := Vector3.ZERO
var _shake_p := 0.0
var _shake_t := 0.0
var _shake_dur := 0.0
var _arena := {}
var _opts := {}
var _projs := []
var _last_hud := {}

class Ctl:
	var has_held := true
	var move := Vector2.ZERO
	var run := false
	var cur := {}
	var prev := {}
	func pressed(a: String) -> bool: return cur.get(a, false) and not prev.get(a, false)
	func held(a: String) -> bool: return cur.get(a, false)
	func released(a: String) -> bool: return prev.get(a, false) and not cur.get(a, false)
	func running() -> bool: return run

var ctl := Ctl.new()

func setup(h) -> void:
	host = h
	for act in KEYS:
		if not InputMap.has_action(act): InputMap.add_action(act)
		for k in KEYS[act]:
			var ev := InputEventKey.new(); ev.physical_keycode = k
			InputMap.action_add_event(act, ev)
	fxn = CombatFx.new()
	fxn.height_at = func(x, z): return host.world.height_at(x, z)
	add_child(fxn)
	battle = CBattle.new(self)

# ---- env (cbattle·cplayer·ctiger가 부른다) ----
func height_at(x: float, z: float) -> float: return host.world.height_at(x, z)
func blocked(x: float, z: float, r: float) -> bool: return host.world.blocked(x, z, r)
func rand() -> float: return battle.rand()

func anim(who: String, n: String, restart: bool, dur: float) -> void:
	var c: SpriteChar = host.player if who == "player" else tiger_ch
	if c == null: return
	var speed := 1.0
	if dur > 0.0:
		var d := c.anim_duration(n)
		if d > 0.0: speed = clampf(d / dur, 0.3, 3.0)
	c.play(n, restart, speed)

func face(who: String, d: String) -> void:
	var c: SpriteChar = host.player if who == "player" else tiger_ch
	if c != null and d != "": c.facing = d

func flash(who: String, col: Color, ms: float) -> void:
	var c: SpriteChar = host.player if who == "player" else tiger_ch
	if c != null: c.flash(col, ms)

func fx(type: String, x: float, z: float, o: Dictionary) -> Dictionary:
	return fxn.spawn(type, x, z, o)

func fx_remove(h) -> void: fxn.remove(h)

func say(text: String, ms: float) -> void:
	if host.ui: host.ui.hud_say(text, ms / 1000.0)
	if host.log_combat: printerr("COMBAT say ", text)

func hit_stop(ms: float) -> void:
	if options.hitStop: hitstop = maxf(hitstop, ms / 1000.0)

func shake(p: float, ms: float) -> void:
	if p >= _shake_p * maxf(0.0, _shake_t / maxf(_shake_dur, 0.001)):
		_shake_p = p; _shake_t = ms / 1000.0; _shake_dur = _shake_t

func spawn_proj(p: Dictionary) -> void:
	var m: Node3D = CombatFx.make_arrow_mesh() if p.kind == "arrow" else CombatFx.make_bait_mesh()
	add_child(m)
	p.view = m
	if p.kind == "arrow": m.rotation.y = atan2(p.dx, p.dz)
	_sync_proj(p)

func remove_proj(p: Dictionary) -> void:
	if p.view != null and is_instance_valid(p.view): p.view.queue_free()
	p.view = null

func _sync_proj(p: Dictionary) -> void:
	var m = p.view
	if m == null or not is_instance_valid(m): return
	m.global_position = Vector3(p.x, height_at(p.x, p.z) + p.y, p.z)
	if p.kind == "arrow" and p.stuck: m.rotation.x = 0.45
	if p.kind == "bait" and not p.landed: m.rotation.y += 0.25

# ---- 시작·끝 ----
func start(arena: Dictionary, opts := {}) -> void:
	if active or tiger_ch != null: reset()
	_arena = arena; _opts = opts
	result = ""; ending = false; hitstop = 0.0
	tiger_ch = SpriteChar.new("tiger")
	host.scene_root().add_child(tiger_ch)
	tiger_ch._sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if opts.get("mods", {}).get("disguised", false): tiger_ch.variant = "disguised"
	var pl: SpriteChar = host.player
	TU.sync_timings(func(n: String) -> float:
		var c: SpriteChar = tiger_ch if n in ["swipe", "pounce"] else pl
		return c.anim_duration(n))
	TU.apply_scale(0.375, 1.0)
	var c := Vector2(arena.x, arena.z)
	var bo := { mods = opts.get("mods", {}), allow_flee = opts.get("allow_flee", true) }
	if opts.has("retreat_at"): bo.retreat_at = opts.retreat_at
	if not opts.get("place_player", false): bo.player_pos = Vector2(host.player_pos.x, host.player_pos.z)
	if opts.has("focus"): bo.focus = opts.focus
	if opts.has("retreat_to"): bo.retreat_to = opts.retreat_to
	if opts.has("seed"): bo.seed = opts.seed
	battle.start(arena, bo)
	pl.armed = true
	active = true
	ctl.cur = {}; ctl.prev = {}
	_last_hud = {}
	if host.ui: host.ui.combat_mode(true)
	_update_hud(true)
	if host.rig: host.rig.override = arena.get("camera", { pitch = 46.0, distance = 19.0, fov = 30.0 })
	_sync_actors(0.0)
	var mods: Dictionary = opts.get("mods", {})
	if float(mods.get("stunned", 0.0)) <= 0.0:
		say("숲 그늘에서 거대한 호랑이가 모습을 드러냈다!" if mods.get("firstEncounter", false)
			else ("호랑이가 마당으로 뛰어들었다! 아이들이 있는 나무를 노린다." if arena.get("id", "") == "house_yard"
			else "숲이 조용해졌다… 호랑이가 낮게 원을 그리며 다가온다."), 2600)
	printerr("COMBAT start arena=%s mods=%s" % [arena.get("id", "?"), JSON.stringify(mods)])

func reset() -> void:
	battle.clear_projectiles()
	fxn.clear()
	if tiger_ch != null:
		tiger_ch.queue_free(); tiger_ch = null
	active = false; ending = false
	if host.ui:
		host.ui.hud_foe("", 0, 0)
		host.ui.combat_mode(false)
	host.player.armed = false
	host.player.play("idle", true)
	if host.rig: host.rig.override = null; host.rig.focus = null
	shake_offset = Vector3.ZERO; _shake_t = 0.0

func _read_input() -> void:
	ctl.prev = ctl.cur.duplicate()
	var cur := {}
	if bot.is_valid():
		var o: Dictionary = bot.call()
		ctl.move = o.get("move", Vector2.ZERO)
		ctl.run = o.get("run", false)
		var hd: Dictionary = o.get("held", {})
		for a in ACTIONS: cur[a] = bool(hd.get(a, false))
	else:
		ctl.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		ctl.run = Input.is_action_pressed("run")
		for a in ACTIONS: cur[a] = Input.is_action_pressed("c_" + a)
	ctl.cur = cur

func update(dt: float) -> void:
	fxn.update(dt)
	_update_shake(dt)
	if not active:
		if tiger_ch != null: tiger_ch.update_char(dt, host.cam)
		return
	if hitstop > 0.0:
		hitstop -= dt
		return
	_read_input()
	if not ending:
		battle.update(dt, ctl)
		if battle.outcome != "":
			ending = true
			result = battle.outcome
			printerr("COMBAT end result=%s tiger_hp=%.0f player_hp=%.0f t=%.1fs stats=%s tiger=%s" % [result, battle.tiger.hp, battle.player.hp, battle.time,
				JSON.stringify(battle.stats), JSON.stringify(battle.tiger.stats)])
			_finish.call_deferred()
	_sync_actors(dt)
	for p in battle.arrows: _sync_proj(p)
	for p in battle.baits: _sync_proj(p)
	_update_hud(false)

func _finish() -> void:
	active = false
	if host.ui:
		host.ui.hud_foe("", 0, 0)
		host.ui.combat_mode(false)
	host.player.armed = false
	host.player.anim_speed = 1.0
	if host.rig: host.rig.override = null; host.rig.focus = null
	finished.emit(result)

func _sync_actors(dt: float) -> void:
	var pl = battle.player; var tg = battle.tiger
	var p := Vector3(pl.pos.x, height_at(pl.pos.x, pl.pos.y), pl.pos.y)
	host.set_player_pos(p)
	if tiger_ch != null:
		tiger_ch.position = Vector3(tg.pos.x, height_at(tg.pos.x, tg.pos.y) + tg.y, tg.pos.y)
		tiger_ch.visible = tg.state != "gone"
		tiger_ch.update_char(dt, host.cam)
		# 카메라: 플레이어 쪽에 두되 호랑이를 같이 담도록 조금 끌어당긴다
		if host.rig and tg.state != "gone":
			var mid := p.lerp(tiger_ch.position, 0.35)
			host.rig.focus = { x = mid.x, z = mid.z, y = p.y }

func _update_shake(dt: float) -> void:
	if _shake_t > 0.0:
		_shake_t -= dt
		var k := maxf(0.0, _shake_t / maxf(_shake_dur, 0.001))
		var a := _shake_p * k
		shake_offset = Vector3(randf_range(-a, a), randf_range(-a, a) * 0.6, randf_range(-a, a) * 0.4)
	else:
		shake_offset = Vector3.ZERO; _shake_p = 0.0

func _update_hud(force: bool) -> void:
	if host.ui == null: return
	var pl = battle.player; var tg = battle.tiger
	var cur := { hp = roundf(pl.hp), st = roundf(pl.st), thp = roundf(maxf(0.0, tg.hp)), arrows = pl.arrows, bait = pl.bait, gone = tg.retreating }
	if not force and cur == _last_hud: return
	_last_hud = cur
	host.ui.hud_player(pl.hp, TU.T.player.hp, pl.st, TU.T.player.stamina)
	if tg.retreating or result in ["escaped", "repelled"]: host.ui.hud_foe("", 0, 0)
	else: host.ui.hud_foe(TIGER_NAME, maxf(0.0, tg.hp), TU.T.tiger.hp)
	host.ui.hud_ammo(pl.arrows, pl.bait)
