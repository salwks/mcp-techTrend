# 플레이어 전투 상태 기계(웹 combat/player.js 이식). 상태: free · attack · charge · heavy · dodge · guard · guardbreak ·
# bow · bowshot · throw · hit · down · getup · dead. 위치·방향은 Vector2(x, z).
extends RefCounted

const TU := preload("res://scripts/combat/ctuning.gd")
const HB := preload("res://scripts/combat/chit.gd")

var b   # CombatBattle
var pos := Vector2.ZERO
var hp := 100.0
var st := 100.0
var st_wait := 0.0
var state := "free"
var t := 0.0
var f := Vector2(0, -1)       # 마지막 이동 방향(단위)
var dir := "up"
var a := Vector2(0, -1)       # 지금 행동 방향(공격·활)
var combo := 0
var combo_gap := 9.0
var queued := false
var queued_heavy := false
var holding := false
var hold := 0.0
var tap := false
var charged_cue := false
var spec: Dictionary = {}
var hit_done := false
var dd := Vector2.ZERO
var dodge_buf := 0.0
var want_dodge := false
var bd := Vector2.ZERO
var draw := 0.0
var bow_auto := false
var arrows := 12
var bait := 3
var bait_thrown := false
var shot_pending := false
var shot_dmg := 0.0
var shot_full := false
var stun_t := 0.0
var k := Vector2.ZERO
var anim := ""
var moving := false
var damage_taken := 0.0
var ring_h = null

func _init(battle) -> void:
	b = battle
	reset(Vector2.ZERO)

static func P() -> Dictionary: return TU.T.player

func reset(p: Vector2) -> void:
	pos = p
	hp = P().hp; st = P().stamina; st_wait = 0.0
	state = "free"; t = 0.0
	f = Vector2(0, -1); dir = "up"; a = f
	combo = 0; combo_gap = 9.0; queued = false; queued_heavy = false
	holding = false; hold = 0.0; tap = false; charged_cue = false
	spec = {}; hit_done = false
	dd = Vector2.ZERO; dodge_buf = 0.0; want_dodge = false; bd = Vector2.ZERO
	draw = 0.0; arrows = int(P().bow.arrows); bait = int(P().throw.bait)
	stun_t = 0.0; k = Vector2.ZERO
	anim = ""; moving = false; damage_taken = 0.0; ring_h = null

var alive: bool:
	get: return state != "dead"

var invulnerable: bool:
	get:
		if state == "dodge": return t >= P().dodge.iStart and t <= P().dodge.iEnd
		return state == "down" or state == "getup" or state == "dead"

func set_anim(n: String, restart := false, dur := 0.0) -> void:
	if n == anim and not restart: return
	anim = n
	b.env.anim("player", n, restart, dur)

func face(v: Vector2) -> void:
	var d := HB.facing4(v.x, v.y, dir)
	if d != dir:
		dir = d; b.env.face("player", d)

func go(s: String) -> void:
	state = s; t = 0.0

func use_stamina(n: float) -> void:
	st = maxf(0.0, st - n); st_wait = P().staminaDelay

func move(d: Vector2) -> bool:
	return HB.move_body(b.env, self, d, P().radius)

func aim_dir(assist_deg: float, rng: float) -> void:
	a = f
	var tg = b.tiger
	if not b.env.options.aimAssist or tg == null or not tg.targetable: return
	var v: Vector2 = tg.pos - pos
	var d := v.length()
	if d < 1e-3 or d > rng: return
	if HB.angle_between(f, v / d) <= assist_deg: a = v / d

func update(dt: float, ctl) -> void:
	if st_wait > 0.0: st_wait -= dt
	else: st = minf(P().stamina, st + P().staminaRegen * dt * (0.5 if state == "guard" else 1.0))
	tap = false
	if ctl.pressed("attack"):
		holding = true; hold = 0.0; charged_cue = false
	if holding: hold += dt
	if ctl.released("attack") and holding:
		holding = false; tap = true
	combo_gap += dt
	t += dt
	if ctl.pressed("dodge"):
		dodge_buf = 0.25
		var l: float = ctl.move.length()
		bd = ctl.move / l if l > 0.1 else Vector2.ZERO
	elif dodge_buf > 0.0: dodge_buf -= dt
	want_dodge = dodge_buf > 0.0
	moving = false
	var mv: Vector2 = ctl.move
	var mlen := mv.length()
	if mlen > 0.1 and can_steer(): f = mv / mlen
	match state:
		"free": _upd_free(dt, ctl, mv, mlen)
		"attack", "heavy": _upd_attack(dt, ctl)
		"charge": _upd_charge(dt, ctl, mv, mlen)
		"dodge": _upd_dodge(dt)
		"guard": _upd_guard(dt, ctl, mv, mlen)
		"bow": _upd_bow(dt, ctl, mv, mlen)
		"bowshot":
			if shot_pending and t >= P().bow.releaseAt:
				shot_pending = false
				b.spawn_arrow(pos, a, shot_dmg, shot_full)
			if t >= P().bow.recover: to_free()
		"throw": _upd_throw()
		"guardbreak", "hit":
			_knock(dt)
			if t >= stun_t: to_free()
		"down":
			_knock(dt)
			if t >= P().down:
				go("getup"); set_anim("getup", true, P().getup)
		"getup":
			if t >= P().getup: to_free()
	if state != "attack" and state != "heavy" and ring_h != null:
		b.env.fx_remove(ring_h); ring_h = null

func can_steer() -> bool:
	return state in ["free", "charge", "bow", "guard"]

func to_free() -> void:
	go("free"); queued = false; set_anim("idle")

func _try_actions(ctl) -> bool:
	if want_dodge: return start_dodge(ctl)
	if ctl.held("guard") or ctl.pressed("guard"):
		go("guard"); set_anim("guard"); face_tiger(); return true
	if ctl.pressed("bow") and arrows > 0:
		go("bow"); draw = 0.0; set_anim("bow_draw", true)
		bow_auto = not ctl.has_held; return true
	if ctl.pressed("item") and bait > 0:
		go("throw"); bait_thrown = false; set_anim("throw", true, P().throw.dur); face(f); return true
	if tap:
		if hold >= P().heavy.chargeMin: return start_heavy()
		return start_attack(combo + 1 if combo_gap < 0.45 else 1)
	if holding and hold >= P().chargeStartAfter:
		go("charge"); set_anim("charge"); return true
	return false

func _upd_free(dt: float, ctl, mv: Vector2, mlen: float) -> void:
	if _try_actions(ctl): return
	if mlen > 0.1:
		var sp: float = (P().run if ctl.running() else P().walk) * minf(1.0, mlen)
		moving = move(mv * sp * dt / maxf(1.0, mlen))
		face(mv)
		set_anim(("run" if ctl.running() else "walk") if moving else "idle")
	else: set_anim("idle")

func start_attack(n: int) -> bool:
	if n > 3: n = 1
	if st <= 0.0: to_free(); return false
	var s: Dictionary = P().combo[n - 1]
	combo = n; spec = s; hit_done = false; queued = false
	use_stamina(P().attackCost)
	go("attack")
	aim_dir(P().aimAssistDeg, P().aimAssistRange)
	face(a)
	set_anim(s.anim, true, s.dur)
	_show_range(s)
	return true

func start_heavy() -> bool:
	var s: Dictionary = P().heavy
	combo = 0; spec = s; hit_done = false; queued = false
	use_stamina(P().heavyCost)
	go("heavy")
	aim_dir(P().aimAssistDeg, P().aimAssistRange + 0.5)
	face(a)
	set_anim(s.anim, true, s.dur)
	_show_range(s)
	return true

func _show_range(s: Dictionary) -> void:
	if not b.env.options.ranges: return
	if ring_h != null: b.env.fx_remove(ring_h)
	ring_h = b.env.fx("ring", pos.x, pos.y, { radius = s.r, duration = s.dur + 0.1 })

func _upd_attack(_dt: float, ctl) -> void:
	var s := spec
	if t < s.hitAt:
		var step: float = (s.lunge / s.hitAt) * _dt
		move(a * step)
	if not hit_done and t >= s.hitAt:
		hit_done = true
		b.player_strike(self, s, a, state == "heavy")
	if state == "attack" and tap and t >= P().comboQueueFrom:
		if hold >= P().heavy.chargeMin: queued_heavy = true
		else: queued = true
	var cancel_from: float = (s.hitAt + P().comboCancelAfter) if state == "heavy" else P().dodgeCancelFrom
	if want_dodge and t >= cancel_from and start_dodge(ctl): return
	if t >= s.hitAt + P().comboCancelAfter and ctl.held("guard"):
		queued = false; queued_heavy = false; go("guard"); set_anim("guard"); face_tiger(); return
	if t >= s.dur:
		combo_gap = 0.0
		if queued_heavy:
			queued_heavy = false; start_heavy(); return
		if queued and state == "attack" and combo < 3:
			start_attack(combo + 1); return
		if holding:
			go("charge"); set_anim("charge"); return
		if combo >= 3 or state == "heavy": combo_gap = 9.0
		to_free()

func _upd_charge(dt: float, ctl, mv: Vector2, mlen: float) -> void:
	if want_dodge and start_dodge(ctl):
		holding = false; return
	if mlen > 0.1:
		moving = move(mv * P().chargeMove * dt / maxf(1.0, mlen))
		face(mv)
	if not charged_cue and hold >= P().heavy.chargeMin:
		charged_cue = true
		b.env.flash("player", Color("#fff1c0"), 140)
	if tap or not holding:
		if hold >= P().heavy.chargeMin: start_heavy()
		else: start_attack(1)

func start_dodge(ctl) -> bool:
	if st <= 0.0: return false
	var mv: Vector2 = ctl.move
	var l := mv.length()
	if l > 0.1: dd = mv / l
	elif bd != Vector2.ZERO: dd = bd
	else: dd = f
	f = dd
	use_stamina(P().dodge.cost)
	dodge_buf = 0.0; want_dodge = false; bd = Vector2.ZERO
	queued = false; queued_heavy = false
	go("dodge")
	face(dd)
	set_anim("dodge", true, P().dodge.dur)
	b.env.fx("dust", pos.x, pos.y, { scale = 0.6 })
	return true

func _upd_dodge(dt: float) -> void:
	var D: Dictionary = P().dodge
	var u0 := maxf(0.0, (t - dt) / D.dur); var u1 := minf(1.0, t / D.dur)
	var e := func(u: float) -> float: return 1.0 - (1.0 - u) * (1.0 - u)
	var step: float = D.dist * (e.call(u1) - e.call(u0))
	move(dd * step)
	if t >= D.dur: to_free()

func _upd_guard(dt: float, ctl, mv: Vector2, mlen: float) -> void:
	if not ctl.held("guard"):
		to_free(); return
	if want_dodge and start_dodge(ctl): return
	set_anim("guard")
	face_tiger()
	if mlen > 0.1: moving = move(mv * P().guardMove * dt / maxf(1.0, mlen))

func face_tiger() -> void:
	var tg = b.tiger
	if tg == null or not tg.targetable: return
	var v: Vector2 = tg.pos - pos
	var d := maxf(v.length(), 1e-6)
	if d > 8.0: return
	f = v / d
	face(f)

func _upd_bow(dt: float, ctl, mv: Vector2, mlen: float) -> void:
	var B: Dictionary = P().bow
	draw += dt
	if want_dodge and start_dodge(ctl): return
	if mlen > 0.1: moving = move(mv * P().bowMove * dt / maxf(1.0, mlen))
	a = f
	var tg = b.tiger
	if tg != null and tg.targetable:
		var v: Vector2 = tg.pos - pos
		var d := maxf(v.length(), 1e-6)
		var lim: float = B.autoAimDeg if b.env.options.aimAssist else 12.0
		if d < B.range and HB.angle_between(f, v / d) <= lim: a = v / d
	face(a)
	var release: bool = draw >= B.autoDraw if bow_auto else (ctl.released("bow") or not ctl.held("bow"))
	if release:
		if draw >= B.minDraw:
			var full: bool = draw >= B.fullDraw
			arrows -= 1
			shot_dmg = B.fullDmg if full else B.dmg; shot_full = full; shot_pending = true
			go("bowshot")
			set_anim("bow_shoot", true)
		else: to_free()

func _upd_throw() -> void:
	var Th: Dictionary = P().throw
	if not bait_thrown and t >= Th.releaseAt:
		bait_thrown = true
		bait -= 1
		b.throw_bait(pos, f, Th.dist, Th.flight)
	if t >= Th.dur: to_free()

func _knock(dt: float) -> void:
	if k != Vector2.ZERO:
		var kk := minf(1.0, dt * 8.0)
		move(k * kk)
		k *= 1.0 - kk
		if absf(k.x) + absf(k.y) < 0.01: k = Vector2.ZERO

# 호랑이 공격을 받음. kind: swipe | pounce. 반환: miss | block | break | hit | down | dead
func take_hit(dmg: float, from: Vector2, kind: String) -> String:
	var env = b.env
	var F: Dictionary = TU.T.feel
	if not alive or invulnerable: return "miss"
	var v := from - pos
	v = v / maxf(v.length(), 1e-6)
	queued = false; queued_heavy = false; holding = false
	if state == "guard" and v.dot(f) > P().guard.frontDot:
		var dealt: float = dmg * (1.0 - P().guard.reduce)
		hp -= dealt; damage_taken += dealt
		st -= dmg * P().guard.staminaPerDmg; st_wait = P().staminaDelay
		env.fx("block", pos.x + v.x * 0.5, pos.y + v.y * 0.5, { dir = v })
		env.hit_stop(F.hitStopBlock)
		if kind == "pounce":
			k = -v * P().guard.pounceKnock; env.shake(F.shakeHurt[0], F.shakeHurt[1])
		if hp <= 0.0: return die()
		if st <= 0.0:
			st = 0.0
			go("guardbreak"); stun_t = P().guard.breakStun; set_anim("hit", true)
			env.say("방어가 무너졌다!", 1200)
			return "break"
		return "block"
	hp -= dmg; damage_taken += dmg
	env.flash("player", Color("#ffd0c0"), 140)
	env.fx("heavyHit" if kind == "pounce" else "hit", pos.x, pos.y, { dir = -v })
	if hp <= 0.0:
		env.hit_stop(F.hitStopPounce); env.shake(F.shakeHurt[0], F.shakeHurt[1]); return die()
	if kind == "pounce":
		env.hit_stop(F.hitStopPounce)
		env.shake(F.shakeHurt[0], F.shakeHurt[1])
		k = -v * P().knockback
		go("down"); set_anim("down", true)
		return "down"
	env.hit_stop(F.hitStopSwipe)
	k = -v * 0.6
	go("hit"); stun_t = P().hitStun; set_anim("hit", true)
	return "hit"

func stun(sec: float) -> bool:
	if not alive or invulnerable: return false
	if state == "guard": sec *= 0.4
	holding = false; queued = false
	go("hit"); stun_t = sec; set_anim("hit", true)
	return true

func die() -> String:
	hp = 0.0
	go("dead")
	set_anim("dead", true)
	return "dead"
