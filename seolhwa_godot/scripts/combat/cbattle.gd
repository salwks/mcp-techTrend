# 전투 한 판의 논리(웹 combat/battle.js + projectiles.js 이식) — 플레이어·호랑이·화살·떡·결말.
# 장면·그림 없이 돌아간다: env(combat_view.gd)가 높이·충돌·그림·효과를 대 준다.
# 상대(foes): 호랑이 한 마리(mode "tiger", 남원) 또는 사람 적 여럿(mode "human" — scripts/combat/chuman.gd, opts.humans).
#   플레이어 조준·베기·화살은 foes를 고루 본다(nearest_foe·aim_foe). 사람 적은 한 번에 한 명만 덤빈다(claim·release).
extends RefCounted

const TU := preload("res://scripts/combat/ctuning.gd")
const HB := preload("res://scripts/combat/chit.gd")
const CPlayer := preload("res://scripts/combat/cplayer.gd")
const CTiger := preload("res://scripts/combat/ctiger.gd")
const CHuman := preload("res://scripts/combat/chuman.gd")
const CCreature := preload("res://scripts/combat/ccreature.gd")   # 짐승 상대(humans 항목에 "creature" — 제주 구렁이)

var env
var player
var tiger
var mode := "tiger"      # tiger | human
var foes: Array = []     # 이번 판의 상대(tiger 모드면 [tiger])
var token := ""          # 사람 적: 지금 덤비는 적 id(공격 차례)
var token_t := 0.0       # 앞 사람이 덤빈 뒤 지난 초
var flee_to = null       # Vector2 — 사람 적이 달아나는 쪽(없으면 플레이어 반대쪽)
var _said_t := {}
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

# 끝낼 때(combat_view가 트리에서 빠질 때): 판 ↔ 플레이어·범·사람 적이 서로 잡고 있는 고리를 끊는다(RefCounted 누수)
func dispose() -> void:
	for o in [player, tiger] + foes:
		if o != null: o.b = null
	player = null; tiger = null; foes = []
	arrows.clear(); baits.clear()
	env = null

# opts: { mods, retreat_at, allow_flee, player_pos(Vector2), focus(Vector2), retreat_to(Vector2), seed,
#         humans: [{ id, kind, name, weapon, hp, flee_at, pos: Vector2 }] (있으면 사람 적 판), flee_to: Vector2 }
func start(a: Dictionary, opts := {}) -> void:
	if opts.has("seed"): _rng.seed = int(opts.seed)
	else: _rng.randomize()
	clear_projectiles()
	arena = a
	if opts.has("humans"):
		_start_humans(a, opts)
		return
	mode = "tiger"
	foes = [tiger]
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

func _start_humans(a: Dictionary, opts: Dictionary) -> void:
	mode = "human"
	mods = opts.get("mods", {})
	allow_flee = opts.get("allow_flee", true)
	retreat_at = null; focus = null; retreat_to = null
	flee_to = opts.get("flee_to", null)
	token = ""; token_t = 9.0; _said_t = {}
	var c := Vector2(a.x, a.z)
	var pp: Vector2 = opts.get("player_pos", _v(a.get("player_start"), c + Vector2(0, a.radius * 0.5)))
	player.reset(HB.nearest_free(env, pp, TU.T.player.radius))
	foes = []
	var hs: Array = opts.humans
	for i in hs.size():
		var hu = (CCreature if String(hs[i].get("creature", "")) != "" else CHuman).new(self, hs[i], i)
		var hp0: Vector2 = _v(hs[i].get("pos"), c + Vector2(cos(i * 2.1), sin(i * 2.1)) * 4.0)
		hu.reset(HB.nearest_free(env, hp0, TU.T.human.radius + 0.05) if String(hs[i].get("creature", "")) == "" else hp0)
		hu.apply_mods(mods)
		foes.append(hu)
	var v: Vector2 = foes[0].pos - player.pos
	v = v / maxf(v.length(), 1e-6)
	player.f = v
	player.dir = ""; player.face(v)
	player.set_anim("idle", true)
	for hu in foes:
		hu.dir = ""; hu.set_heading(player.pos - hu.pos)
		hu.set_anim("ready", true)
	outcome = ""; pending = ""; pending_t = 0.0
	time = 0.0; outside_t = 0.0; player_outside = false
	stats = { arrow_hits = 0, hits = 0, damage = 0.0, down = 0, fled = 0 }

# ---- 상대 고르기(플레이어 조준·막기 방향) ----
func nearest_foe(p: Vector2, max_d := INF):
	var best = null; var bd := max_d
	for fo in foes:
		if not fo.targetable: continue
		var d: float = (fo.pos - p).length()
		if d <= bd: bd = d; best = fo
	return best

# f 방향 deg 안, rng 안에서 가장 곧은(각도 + 거리) 상대
func aim_foe(p: Vector2, f: Vector2, rng: float, deg: float):
	var best = null; var bs := INF
	for fo in foes:
		if not fo.targetable: continue
		var v: Vector2 = fo.pos - p
		var d := v.length()
		if d < 1e-3 or d > rng: continue
		var ang := HB.angle_between(f, v / d)
		if ang > deg: continue
		var sc := ang + d * 4.0
		if sc < bs: bs = sc; best = fo
	return best

# ---- 사람 적: 공격 차례 ----
func claim(fo) -> bool:
	if token != "" and token != fo.id: return false
	if token == "" and token_t < TU.T.human.tokenGap: return false
	token = fo.id
	return true

func release(fo) -> void:
	if token == fo.id:
		token = ""; token_t = 0.0

# 여럿이 같은 예고 문구를 한꺼번에 띄우지 않게(2.5초 안에 같은 key면 참)
func said_recently(key: String) -> bool:
	if time - float(_said_t.get(key, -99.0)) < 2.5: return true
	_said_t[key] = time
	return false

# 사람 적이 쓰러지거나 달아나 사라졌다
func on_foe_out(fo, how: String) -> void:
	if how == "down": stats.down = int(stats.get("down", 0)) + 1
	elif how == "fled": stats.fled = int(stats.get("fled", 0)) + 1
	if env.has_method("on_foe_out"): env.on_foe_out(fo, how)

func active_foes() -> int:
	var n := 0
	for fo in foes:
		if fo.active: n += 1
	return n

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
	if mode == "human":
		_update_humans(dt)
		return
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

func _update_humans(dt: float) -> void:
	var a := arena
	token_t += dt
	var pd: float = (player.pos - Vector2(a.x, a.z)).length()
	player_outside = allow_flee and pd > a.radius + TU.T.tiger.leash
	if player_outside and pending == "":
		outside_t += dt
		if outside_t >= TU.T.tiger.escapeTime * 1.5 or pd > a.radius + TU.T.tiger.escapeFar * 1.6: finish("escaped", 0.2)
	else: outside_t = 0.0
	for fo in foes: fo.update(dt)
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
	elif active_foes() == 0: finish("win", 1.0)
	if pending != "":
		pending_t -= dt
		if pending_t <= 0.0: outcome = pending

func player_strike(pl, spec: Dictionary, d: Vector2, heavy: bool) -> bool:
	env.fx("slash", pl.pos.x, pl.pos.y, { dir = d, radius = spec.r, arc = spec.arc, heavy = heavy, flip = spec.anim == "attack2" })
	var any := false
	for fo in foes:
		if not fo.targetable: continue
		var bh: float = TU.T.tiger.bodyHalf if fo == tiger else fo.body_half
		var br: float = TU.T.tiger.bodyR if fo == tiger else fo.body_r
		var hit := false
		for k in [-1, 0, 1]:
			if HB.fan_hit(pl.pos, d, spec.r, spec.arc, fo.pos + fo.h * bh * k, br):
				hit = true; break
		if not hit: continue
		var dealt: float = fo.receive_hit(spec.dmg, { kind = "melee", heavy = heavy, combo3 = spec.anim == "attack3", from = pl.pos })
		stats.hits += 1; stats.damage += dealt
		any = true
	return any

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
	for fo in foes:
		if not fo.targetable: continue
		var bh: float = TU.T.tiger.bodyHalf if fo == tiger else fo.body_half
		var br: float = TU.T.tiger.bodyR if fo == tiger else fo.body_r
		var A: Vector2 = fo.pos - fo.h * bh
		var B: Vector2 = fo.pos + fo.h * bh
		for i in 5:
			var c := A.lerp(B, i / 4.0)
			if HB.segment_hit(Vector2(ar.px, ar.pz), Vector2(ar.x, ar.z), 0.05, c, br + 0.1):
				fo.receive_hit(ar.dmg, { kind = "arrow", from = Vector2(ar.px, ar.pz) })
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
