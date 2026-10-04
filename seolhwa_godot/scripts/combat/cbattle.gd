# 전투 한 판의 논리(웹 combat/battle.js + projectiles.js 이식) — 플레이어·호랑이·화살·떡·결말.
# 장면·그림 없이 돌아간다: env(combat_view.gd)가 높이·충돌·그림·효과를 대 준다.
extends RefCounted

const TU := preload("res://scripts/combat/ctuning.gd")
const HB := preload("res://scripts/combat/chit.gd")
const CPlayer := preload("res://scripts/combat/cplayer.gd")
const CTiger := preload("res://scripts/combat/ctiger.gd")

var env
var player
var tiger
var arrows: Array = []
var baits: Array = []
var arena := { x = 0.0, z = 0.0, radius = 11.0 }
var outcome := ""
var pending := ""
var pending_t := 0.0
var time := 0.0
var outside_t := 0.0
var player_outside := false
var mods := {}
var allow_flee := true
var retreat_at = null
var focus = null       # Vector2 — 마당: 큰 나무
var retreat_to = null  # Vector2 — 영역 쪽
var stats := {}
var _rng := RandomNumberGenerator.new()

func _init(e) -> void:
	env = e
	player = CPlayer.new(self)
	tiger = CTiger.new(self)

func rand() -> float: return _rng.randf()

# opts: { mods, retreat_at, allow_flee, player_pos(Vector2), focus(Vector2), retreat_to(Vector2), seed }
func start(a: Dictionary, opts := {}) -> void:
	if opts.has("seed"): _rng.seed = int(opts.seed)
	else: _rng.randomize()
	clear_projectiles()
	arena = a
	mods = opts.get("mods", {})
	allow_flee = opts.get("allow_flee", true)
	retreat_at = opts.get("retreat_at", null)
	if retreat_at == null and mods.get("firstEncounter", false):
		retreat_at = { hpRatio = TU.T.tiger.firstRetreatHp, seconds = TU.T.tiger.firstRetreatTime }
	focus = opts.get("focus", null)
	retreat_to = opts.get("retreat_to", null)
	var c := Vector2(a.x, a.z)
	var pp: Vector2 = opts.get("player_pos", _v(a.get("player_start"), c + Vector2(0, a.radius * 0.5)))
	var ps := HB.nearest_free(env, pp, TU.T.player.radius)
	var ts := HB.nearest_free(env, _v(a.get("tiger_start"), c + Vector2(0, -a.radius * 0.4)), TU.T.tiger.radius + 0.1)
	player.reset(ps)
	tiger.reset(ts)
	var v := ts - ps
	v = v / maxf(v.length(), 1e-6)
	player.f = v
	player.dir = ""; player.face(v)
	tiger.dir = ""; tiger.set_heading(-v)
	player.set_anim("idle", true)
	tiger.set_anim("prowl", true)
	tiger.decide = 2.0
	tiger.apply_mods(mods)
	outcome = ""; pending = ""; pending_t = 0.0
	time = 0.0; outside_t = 0.0; player_outside = false
	stats = { arrow_hits = 0, hits = 0, damage = 0.0 }

static func _v(p, dflt: Vector2) -> Vector2:
	if p is Vector2: return p
	if p is Array and p.size() >= 2: return Vector2(float(p[0]), float(p[1]))
	if p is Dictionary: return Vector2(float(p.x), float(p.z))
	return dflt

func clear_projectiles() -> void:
	for x in arrows: env.remove_proj(x)
	for x in baits: env.remove_proj(x)
	arrows.clear(); baits.clear()

func finish(kind: String, delay := 0.6) -> void:
	if pending != "" or outcome != "": return
	pending = kind; pending_t = delay

func update(dt: float, ctl) -> void:
	if outcome != "": return
	time += dt
	var a := arena
	player.update(dt, ctl)
	var pd: float = (player.pos - Vector2(a.x, a.z)).length()
	player_outside = allow_flee and pd > a.radius + TU.T.tiger.leash and not tiger.retreating and tiger.alive
	if player_outside and pending == "":
		outside_t += dt
		if outside_t >= TU.T.tiger.escapeTime or pd > a.radius + TU.T.tiger.escapeFar: finish("escaped", 0.2)
	else: outside_t = 0.0
	tiger.update(dt)
	var i := arrows.size() - 1
	while i >= 0:
		if not _update_arrow(arrows[i], dt):
			env.remove_proj(arrows[i]); arrows.remove_at(i)
		i -= 1
	i = baits.size() - 1
	while i >= 0:
		if not _update_bait(baits[i], dt):
			env.remove_proj(baits[i]); baits.remove_at(i)
		i -= 1
	if not player.alive: finish("lose", 1.6)
	if pending != "":
		pending_t -= dt
		if pending_t <= 0.0: outcome = pending

func player_strike(pl, spec: Dictionary, d: Vector2, heavy: bool) -> bool:
	env.fx("slash", pl.pos.x, pl.pos.y, { dir = d, radius = spec.r, arc = spec.arc, heavy = heavy, flip = spec.anim == "attack2" })
	if not tiger.targetable: return false
	var bh: float = TU.T.tiger.bodyHalf; var br: float = TU.T.tiger.bodyR
	var hit := false
	for k in [-1, 0, 1]:
		if HB.fan_hit(pl.pos, d, spec.r, spec.arc, tiger.pos + tiger.h * bh * k, br):
			hit = true; break
	if not hit: return false
	var dealt: float = tiger.receive_hit(spec.dmg, { kind = "melee", heavy = heavy, combo3 = spec.anim == "attack3", from = pl.pos })
	stats.hits += 1; stats.damage += dealt
	return true

# ---- 화살 ----
func spawn_arrow(p: Vector2, d: Vector2, dmg: float, full: bool) -> void:
	var ar := { kind = "arrow", x = p.x + d.x * 0.5, z = p.y + d.y * 0.5, px = p.x, pz = p.y, y = 1.15,
		dx = d.x, dz = d.y, speed = TU.T.player.bow.speed, travelled = 0.0, dmg = dmg, full = full,
		stuck = false, stuck_t = 0.0, gone = false, view = null }
	arrows.append(ar)
	env.spawn_proj(ar)

func _update_arrow(ar: Dictionary, dt: float) -> bool:
	if ar.stuck:
		ar.stuck_t += dt
		return ar.stuck_t < 2.5
	var step: float = ar.speed * dt
	ar.px = ar.x; ar.pz = ar.z
	ar.x += ar.dx * step; ar.z += ar.dz * step
	ar.travelled += step
	ar.y = 1.15 - maxf(0.0, ar.travelled - TU.T.player.bow.range * 0.6) * 0.12
	if tiger.targetable:
		var bh: float = TU.T.tiger.bodyHalf
		var A: Vector2 = tiger.pos - tiger.h * bh
		var B: Vector2 = tiger.pos + tiger.h * bh
		for i in 5:
			var c := A.lerp(B, i / 4.0)
			if HB.segment_hit(Vector2(ar.px, ar.pz), Vector2(ar.x, ar.z), 0.05, c, TU.T.tiger.bodyR + 0.1):
				tiger.receive_hit(ar.dmg, { kind = "arrow", from = Vector2(ar.px, ar.pz) })
				env.fx("hit", c.x, c.y, { scale = 0.6, dir = Vector2(ar.dx, ar.dz) })
				stats.arrow_hits += 1
				return false
	if env.blocked(ar.x, ar.z, 0.05) or ar.y <= 0.05 or ar.travelled >= TU.T.player.bow.range:
		ar.stuck = true
		ar.y = maxf(0.15, ar.y)
	return true

# ---- 떡 ----
func throw_bait(p: Vector2, d: Vector2, distance: float, flight: float) -> void:
	var l := 0.0
	while l < distance:
		var n := p + d * (l + 0.25)
		if env.blocked(n.x, n.y, 0.15): break
		l += 0.25
	var bt := { kind = "bait", sx = p.x + d.x * 0.3, sz = p.y + d.y * 0.3, tx = p.x + d.x * l, tz = p.y + d.y * l,
		x = p.x + d.x * 0.3, z = p.y + d.y * 0.3, y = 1.1, t = 0.0, flight = flight,
		landed = false, claimed = false, gone = false, view = null }
	baits.append(bt)
	env.spawn_proj(bt)

func _update_bait(bt: Dictionary, dt: float) -> bool:
	if bt.landed: return not bt.gone
	bt.t += dt
	var u := minf(1.0, bt.t / bt.flight)
	bt.x = lerpf(bt.sx, bt.tx, u); bt.z = lerpf(bt.sz, bt.tz, u)
	bt.y = 1.1 * (1.0 - u) + sin(PI * u) * 1.4 + 0.08
	if u >= 1.0:
		bt.landed = true; bt.y = 0.08
		env.fx("dust", bt.x, bt.z, { scale = 0.35 })
	return true

func consume_bait(bt: Dictionary) -> void:
	bt.gone = true
