# 호랑이 AI 상태 기계(웹 combat/tiger.js 이식). 상태: prowl(배회) · stalk · crouch(덮치기 예고) · pounce · land(빈틈) ·
# swipeWind(앞발 예고) · swipe · roar · backoff · hit · stagger · toBait · eat · territory · home · toTree(마당) ·
# stunned(미끄러져 떨어짐) · getup · retreatRoar · retreat · retreatStagger · gone · dead
extends RefCounted

const TU := preload("res://scripts/combat/ctuning.gd")
const HB := preload("res://scripts/combat/chit.gd")
const INTERRUPTIBLE := ["prowl", "stalk", "home", "backoff", "toTree"]

var b
var pos := Vector2.ZERO
var y := 0.0
var hp := 430.0
var state := "prowl"
var t := 0.0
var h := Vector2(0, 1)      # 머리 방향(단위)
var dir := "down"
var orbit := 1.0
var orbit_r := 7.5
var decide := 1.5
var roared := false
var pending_roar := false
var enraged := false
var fury := 0.0
var poise := 34.0
var poise_wait := 0.0
var pounce_hit := false
var ps := Vector2.ZERO
var pe := Vector2.ZERO
var airborne := false
var bait = null
var disturbed := false
var eat_left := 0.0
var swipe_hit := false
var swipe_chain := 0
var tele_h = null
var anim := ""
var retreat_dir := Vector2(0, -1)
var speed_mul := 1.0
var decide_mul := 1.0
var since_hit := 99.0
var retreat_kind := "repelled"
var roar_blast := false
var stun_for := 0.0
var bx := Vector2.ZERO
var stats := {}
var said := {}
var first_pounce := false
var undying := false        # 이야기 모드(남원 v3): 쓰러지지 않는다 — 체력이 바닥 근처에서 멈추고 물러난다(시간을 버는 싸움)
const UNDYING_FLOOR := 0.12

func _init(battle) -> void:
	b = battle
	reset(Vector2.ZERO)

static func G() -> Dictionary: return TU.T.tiger
static func F() -> Dictionary: return TU.T.feel

func reset(p: Vector2) -> void:
	pos = p; y = 0.0
	hp = G().hp
	state = "prowl"; t = 0.0
	h = Vector2(0, 1); dir = "down"
	orbit = 1.0; orbit_r = 7.5; decide = 1.5
	roared = false; pending_roar = false; enraged = false; fury = 0.0
	poise = G().poise; poise_wait = 0.0
	pounce_hit = false; airborne = false
	bait = null; disturbed = false; eat_left = 0.0
	swipe_hit = false; swipe_chain = 0
	tele_h = null; anim = ""
	retreat_dir = Vector2(0, -1)
	speed_mul = 1.0; decide_mul = 1.0; since_hit = 99.0; retreat_kind = "repelled"
	stats = { pounces = 0, pounce_hits = 0, swipes = 0, swipe_hits = 0, baits = 0, back_hits = 0, blocks = 0, roar = false, dmg = {} }
	said = {}; first_pounce = false; undying = false

var alive: bool:
	get: return state != "dead"
var targetable: bool:
	get: return state != "dead" and state != "gone" and not (state == "pounce" and airborne)
var tm: float:
	get: return G().enrageTime if enraged else 1.0
var sm: float:
	get: return (G().enrageSpeed if enraged else 1.0) * speed_mul
var retreating: bool:
	get: return state in ["retreat", "retreatStagger", "retreatRoar", "gone"]

func set_anim(n: String, restart := false, dur := 0.0) -> void:
	if n == anim and not restart: return
	anim = n
	b.env.anim("tiger", n, restart, dur)

func set_heading(v: Vector2) -> void:
	var l := v.length()
	if l < 1e-5: return
	h = v / l
	var d := HB.facing4(h.x, h.y, dir, 0.55)
	if d != dir:
		dir = d; b.env.face("tiger", d)

func turn_to(v: Vector2, dt: float) -> void:
	set_heading(HB.turn_toward(h, v, G().turnRate * dt))

func go(s: String) -> void:
	if tele_h != null:
		b.env.fx_remove(tele_h); tele_h = null
	if (state == "toBait" or state == "eat") and s != "eat" and bait != null:
		if not bait.gone: bait.claimed = false
		bait = null
	state = s; t = 0.0

func say(key: String, text: String, ms := 1600, once := false) -> void:
	if once and said.has(key): return
	said[key] = int(said.get(key, 0)) + 1
	if b.env.options.telegraph or once: b.env.say(text, ms)

# 받아밀기(플레이어 숙련): 막힌 앞발 뒤 짧게 밀려나며 움찔(거리 확보). dir = 범 → 플레이어(그 반대로 밀린다)
var push := Vector2.ZERO
func shoved(dir: Vector2, dist: float) -> void:
	if not targetable or state in ["dead", "gone", "stunned", "roar", "territory"]: return
	push = -dir.normalized() * dist if dir.length() > 0.0 else Vector2.ZERO
	go("hit"); set_anim("hit", true, G().flinch)

func move_in(d: Vector2, limit: float) -> bool:
	var a: Dictionary = b.arena
	var n := pos + d - Vector2(a.x, a.z)
	var r := n.length()
	if limit > 0.0 and r > limit:
		var u := n / r
		var out := d.dot(u)
		if out > 0.0: d -= u * out
	return HB.move_body(b.env, self, d, G().radius)

# 플레이어 쪽 단위벡터와 거리
func to_player() -> Dictionary:
	var v: Vector2 = b.player.pos - pos
	var d := maxf(v.length(), 1e-6)
	return { v = v / d, d = d }

func update(dt: float) -> void:
	var env = b.env
	var pl = b.player
	var a: Dictionary = b.arena
	if push != Vector2.ZERO:
		var kk := minf(1.0, dt * 9.0)
		move_in(push * kk, float(a.get("radius", 10.0)))
		push *= 1.0 - kk
		if push.length() < 0.02: push = Vector2.ZERO
	t += dt
	if fury > 0.0: fury -= dt
	if poise_wait > 0.0: poise_wait -= dt
	else: poise = minf(G().poise, poise + 10.0 * dt)
	var tp := to_player()
	var lim: float = a.radius - 0.8 + (0.0 if b.allow_flee else 6.0)
	var player_down: bool = not pl.alive

	if b.player_outside and not state in ["dead", "retreat", "gone", "territory", "home", "pounce", "land", "swipe", "swipeWind", "retreatRoar", "retreatStagger"]:
		go("territory")
		set_heading(tp.v)
		set_anim("roar", true)
		say("territory", "호랑이가 영역 끝에서 으르렁거린다… 더는 쫓아오지 않는다.", 2400, true)
		env.fx("roar", pos.x, pos.y, { radius = 3.0 })

	since_hit += dt
	var ra = b.retreat_at
	if ra != null and alive and not retreating and not (state == "pounce" and airborne) and state != "stunned":
		if (ra.has("hpRatio") and hp <= G().hp * float(ra.hpRatio)) or (ra.has("seconds") and b.time >= float(ra.seconds)):
			start_retreat("retreated")

	if pending_roar and (state in INTERRUPTIBLE or state in ["hit", "eat", "toBait"]) and not b.player_outside:
		pending_roar = false
		start_roar()

	match state:
		"prowl":
			if player_down:
				set_anim("idle")
			elif first_pounce:
				# 첫 조우(S0005): 가까이 붙은 플레이어에게도 앞발을 쓰기 전에, 약 5m로 물러났다가
				# 몸 낮춤(예고) → 멈춤 → 돌진을 한 번 보인다(구르기 안내가 이 예고에 뜬다)
				if tp.d < FIRST_BACK - 0.4:
					var away: Vector2 = -tp.v
					if not move_in(away * G().prowlSpeed * 1.3 * sm * dt, lim):
						move_in(Vector2(-tp.v.y, tp.v.x) * orbit * G().prowlSpeed * dt, lim)
					set_heading(tp.v)
					set_anim("prowl")
					if t > 3.0:   # 물러설 자리가 없으면 그 자리에서
						first_pounce = false
						start_crouch(tp)
				else:
					set_heading(tp.v)
					set_anim("prowl")
					decide -= dt
					if decide <= 0.0:
						first_pounce = false
						start_crouch(tp)
			elif _try_bait(): pass
			elif _wants_tree(tp): go("toTree")
			else:
				var tv := Vector2(-tp.v.y, tp.v.x) * orbit
				var rad := 0.0
				if tp.d < orbit_r - 0.6: rad = -1.0
				elif tp.d > orbit_r + 0.6: rad = 1.0
				var m: Vector2 = tv * 0.85 + tp.v * rad * 0.7
				m = m / maxf(m.length(), 1e-6)
				var sp: float = G().prowlSpeed * sm * (1.3 if rad < 0.0 else 1.0)
				var e: Vector2 = pos + m * 0.8 - Vector2(a.x, a.z)
				if e.length() > lim: orbit *= -1.0
				if not move_in(m * sp * dt, lim): orbit *= -1.0
				turn_to(m, dt)
				set_anim("prowl")
				if tp.d < 2.4: decide = minf(decide, 0.3)
				decide -= dt
				if decide <= 0.0: _choose(tp)
		"stalk":
			if player_down: to_prowl()
			elif _try_bait(): pass
			else:
				var sp: float = G().stalkSpeed * sm
				move_in(tp.v * sp * dt, lim)
				turn_to(tp.v, dt)
				set_anim("walk")
				if tp.d <= G().swipeRange - 0.3: start_swipe(tp)
				elif t > 0.6 and tp.d >= 5.0 and tp.d <= G().pounceMax - 1.0 and b.rand() < dt * G().stalkPounceRate: start_crouch(tp)
				elif t > G().stalkTime: to_prowl()
		"crouch":
			set_anim("crouch")
			if t >= G().crouch * tm: start_pounce()
		"pounce":
			var air: float = G().pounceTime / sm
			var lead: float = air / (G().pounceAirTo - G().pounceAirFrom) * G().pounceAirFrom
			if t >= lead:
				airborne = true
				var u := minf(1.0, (t - lead) / air)
				var prev := pos
				pos = ps.lerp(pe, u)
				y = sin(PI * u) * G().pounceHeight
				if not pounce_hit and pl.alive and u > 0.08:
					var hd: Vector2 = pos + h * G().bodyHalf
					if HB.segment_hit(prev - h * G().bodyHalf, hd, G().pounceWidth * 0.5, pl.pos, TU.T.player.radius):
						var r: String = pl.take_hit(G().pounceDmg, pos - h * 2.0, "pounce")
						if r != "miss":
							pounce_hit = true
							if r != "block" and r != "break": stats.pounce_hits += 1
				if u >= 1.0:
					y = 0.0; airborne = false
					go("land")
					set_anim("land", true, G().land * tm)
					env.fx("dust", pos.x, pos.y, { scale = 1.4 })
					env.shake(F().shakePounce[0], F().shakePounce[1])
		"land":
			if t >= G().land * tm: to_prowl(0.6)
		"swipeWind":
			if t >= G().swipeWind * tm * (0.75 if swipe_chain else 1.0):
				go("swipe"); swipe_hit = false
				stats.swipes += 1
				env.fx("slash", pos.x, pos.y, { dir = h, radius = G().swipeR * 0.9, arc = G().swipeArc, height = 0.6, tiger = true })
		"swipe":
			if not swipe_hit and t <= G().swipeActive and pl.alive:
				if HB.fan_hit(pos, h, G().swipeR, G().swipeArc, pl.pos, TU.T.player.radius):
					var r: String = pl.take_hit(G().swipeDmg, pos, "swipe")
					if r != "miss":
						swipe_hit = true
						if r != "block" and r != "break": stats.swipe_hits += 1
						else: stats.blocks += 1
			if t >= G().swipeActive + G().swipeRecover * tm:
				if enraged and swipe_chain == 0 and tp.d < G().swipeR + 0.5 and b.rand() < G().doubleSwipe:
					swipe_chain = 1; start_swipe(tp, true)
				else:
					swipe_chain = 0
					if b.rand() < G().backoffAfterSwipe: start_backoff()
					else: to_prowl(0.8)
		"roar":
			if not roar_blast and t >= G().roarWind:
				roar_blast = true
				env.fx("roar", pos.x, pos.y, { radius = G().roarR })
				env.shake(F().shakeRoar[0], F().shakeRoar[1])
				if tp.d <= G().roarR and pl.alive: pl.stun(G().roarStun)
				enraged = true; fury = G().furyTime
				env.say("포효! 호랑이의 움직임이 빨라졌다.", 2000)
			if t >= G().roarWind + G().roarAfter: to_prowl(0.4)
		"backoff":
			var u: float = t / G().backoffTime
			var sp: float = (G().backoffDist / G().backoffTime) * 1.5 * maxf(0.0, 1.0 - u)
			move_in(bx * sp * dt, lim)
			set_heading(tp.v)
			set_anim("prowl")
			if u >= 1.0: to_prowl(1.0)
		"hit":
			if t >= G().flinch: _after_react(tp)
		"stagger":
			if t >= stun_for: _after_react(tp)
		"toBait":
			var bt = bait
			if bt == null or bt.gone:
				bait = null; to_prowl()
			else:
				var v := Vector2(bt.x, bt.z) - pos
				var d := v.length()
				if d <= G().bodyHalf + 0.35 or t > 6.0: start_eat()
				else:
					move_in(v / d * G().baitSpeed * dt, a.radius + 1.0)
					turn_to(v, dt * 2.0)
					set_anim("walk")
		"eat":
			set_anim("eat")
			eat_left -= dt
			if eat_left <= 0.0:
				if bait != null:
					b.consume_bait(bait); bait = null
				if disturbed:
					disturbed = false; set_heading(tp.v); start_swipe(tp)
				else: to_prowl(0.8)
		"territory":
			if t >= 1.2: go("home")
			if not b.player_outside and t >= 0.6: to_prowl(0.8)
		"home":
			if not b.player_outside: to_prowl(0.8)
			else:
				var v := Vector2(a.x, a.z) - pos
				var d := v.length()
				if d > 1.0:
					move_in(v / d * 2.0 * dt, lim); turn_to(v, dt); set_anim("walk")
				else:
					set_heading(tp.v); set_anim("idle")
		"toTree":
			if player_down or not _wants_tree(tp): to_prowl(0.5)
			elif _try_bait(): pass
			else:
				var fc: Vector2 = b.focus
				var v := fc - pos
				var d := maxf(v.length(), 1e-6)
				if d > G().treeStop:
					var sp: float = G().prowlSpeed * sm
					if not move_in(v / d * sp * dt, a.radius + 2.0):
						turn_to(v, dt); set_anim("climb_try")
					else:
						turn_to(v, dt); set_anim("prowl")
				else:
					turn_to(v, dt); set_anim("climb_try")
		"stunned":
			if t >= stun_for:
				go("getup"); set_anim("stagger", true, G().getup)
		"getup":
			if t >= G().getup: to_prowl(0.6)
		"retreatRoar":
			if not roar_blast and t >= G().retreatRoar * 0.45:
				roar_blast = true
				env.fx("roar", pos.x, pos.y, { radius = 4.0 })
				env.shake(F().shakeRoar[0], F().shakeRoar[1])
			if t >= G().retreatRoar:
				state = "retreat"; t = G().retreatPause
		"retreat":
			if t < G().retreatPause: set_anim("stagger")
			else:
				move_in(retreat_dir * G().retreatSpeed * dt, 0.0)
				turn_to(retreat_dir, dt)
				set_anim("walk")
				if (pos - Vector2(a.x, a.z)).length() > a.radius + 2.0 or t > 9.0:
					go("gone")
					b.finish(retreat_kind)
		"retreatStagger":
			if t >= G().retreatStagger:
				state = "retreat"; t = G().retreatPause

	# 몸끼리 겹치지 않게: 플레이어를 호랑이 몸통(선분) 밖으로 민다
	if state != "pounce" and state != "gone" and state != "dead" and pl.alive:
		var c := HB.closest_on_seg(pos - h * G().bodyHalf, pos + h * G().bodyHalf, pl.pos)
		var dv: Vector2 = pl.pos - c
		var d := dv.length()
		var mn: float = G().bodyR + TU.T.player.radius
		if d < mn:
			var kk := (mn - d) / maxf(d, 1e-6)
			var push := dv * kk
			if push == Vector2.ZERO: push = Vector2(0.01, 0)
			pl.move(push)

const FIRST_BACK := 5.0

func _choose(tp: Dictionary) -> void:
	var r: float = b.rand()
	decide = (G().decideMin + b.rand() * (G().decideMax - G().decideMin)) * (G().enrageDecide if enraged else 1.0) * decide_mul
	if first_pounce and tp.d >= 3.0:
		first_pounce = false
		start_crouch(tp); return
	if tp.d <= G().swipeRange:
		if r < 0.45: start_swipe(tp)
		else: start_backoff()
		return
	if tp.d >= G().pounceMin and tp.d <= G().pounceMax and r < G().pounceChance:
		start_crouch(tp); return
	if r < 0.8:
		go("stalk"); return
	orbit *= -1.0
	orbit_r = G().prowlMin + b.rand() * (G().prowlMax - G().prowlMin)

func to_prowl(dec := 1.2) -> void:
	go("prowl")
	decide = dec * (G().enrageDecide if enraged else 1.0) + b.rand() * 0.6
	orbit_r = G().prowlMin + b.rand() * (G().prowlMax - G().prowlMin)
	if b.rand() < 0.35: orbit *= -1.0

# 이야기 모드 설정(시작 시 한 번)
func apply_mods(m: Dictionary) -> void:
	if m.has("hpRatio") and m.hpRatio != null: hp = maxf(1.0, G().hp * float(m.hpRatio))
	if m.get("enraged", false):
		enraged = true; roared = true
	if m.get("undying", false): undying = true
	if m.get("firstEncounter", false):
		speed_mul = G().firstSpeed; decide_mul = G().firstDecide; roared = true
		first_pounce = true   # 첫 조우(S0005): 먼저 몸을 낮추고 한 차례 돌진한다
	if float(m.get("stunned", 0.0)) > 0.0:
		go("stunned"); stun_for = float(m.stunned); y = 0.0
		set_anim("slip", true)
		b.env.say("호랑이가 미끄러져 떨어졌다! 지금이 기회다.", 2200)

func _wants_tree(tp: Dictionary) -> bool:
	return b.focus != null and tp.d > G().guardThreat and since_hit > G().guardForget and not b.player_outside

func start_backoff() -> void:
	var tp := to_player()
	go("backoff")
	bx = -tp.v
	var a: Dictionary = b.arena
	var e := pos + bx * 2.0 - Vector2(a.x, a.z)
	if e.length() > a.radius - 1.0: bx = Vector2(-tp.v.y, tp.v.x) * orbit
	set_anim("prowl", true)

func start_crouch(tp: Dictionary) -> void:
	var env = b.env
	go("crouch")
	set_heading(tp.v)
	set_anim("crouch", true)
	stats.pounces += 1
	if env.options.telegraph:
		tele_h = env.fx("lane", pos.x, pos.y, { dir = h, length = G().pounceLen + G().bodyHalf, width = G().pounceWidth, duration = G().crouch * tm })
		say("crouch", "호랑이가 몸을 낮춘다…", 1100)

func start_pounce() -> void:
	var a: Dictionary = b.arena
	go("pounce")
	pounce_hit = false
	ps = pos
	var l := 0.0
	var step := 0.25
	while l < G().pounceLen:
		var n := pos + h * (l + step)
		if b.env.blocked(n.x, n.y, G().radius): break
		if (n - Vector2(a.x, a.z)).length() > a.radius + 1.0: break
		l += step
	pe = pos + h * l
	airborne = false
	set_anim("pounce", true, (G().pounceTime / sm) / (G().pounceAirTo - G().pounceAirFrom))
	b.env.fx("dust", pos.x, pos.y, { scale = 0.9 })

func start_swipe(tp: Dictionary, chain := false) -> void:
	var env = b.env
	go("swipeWind")
	set_heading(tp.v)
	var wind: float = G().swipeWind * tm * (0.75 if chain else 1.0)
	set_anim("swipe", true, wind / G().swipeStrikeFrac)
	if env.options.telegraph:
		tele_h = env.fx("fan", pos.x, pos.y, { dir = h, radius = G().swipeR, arc = G().swipeArc, duration = wind })
		if not chain: say("swipe", "호랑이가 앞발을 든다!", 900)

func start_roar() -> void:
	go("roar")
	roared = true; roar_blast = false
	stats.roar = true
	set_heading(to_player().v)
	set_anim("roar", true, G().roarWind + G().roarAfter)
	b.env.say("호랑이가 크게 숨을 들이쉰다…", 1300)

func start_eat() -> void:
	go("eat")
	eat_left = G().eat
	disturbed = false
	if bait != null: set_heading(Vector2(bait.x, bait.z) - pos)
	set_anim("eat", true)
	stats.baits += 1
	b.env.say("호랑이가 떡에 정신이 팔렸다. 뒤로 돌아가 기습하자!", 2200)

func _try_bait() -> bool:
	if fury > 0.0 or b.player_outside: return false
	var a: Dictionary = b.arena
	for bt in b.baits:
		if not bt.landed or bt.gone or bt.claimed: continue
		if Vector2(bt.x - a.x, bt.z - a.z).length() > a.radius + 0.5: continue
		bt.claimed = true
		bait = bt
		go("toBait")
		say("bait", "호랑이가 떡 냄새를 맡았다.", 1400)
		return true
	return false

func _after_react(tp: Dictionary) -> void:
	if b.player_outside:
		go("home"); return
	if first_pounce:
		to_prowl(0.3); return
	var r: float = b.rand()
	if tp.d <= G().swipeRange and r < 0.5: start_swipe(tp)
	elif tp.d <= G().swipeRange + 1.0 and r < 0.8: start_backoff()
	else: to_prowl(0.6)

func is_behind(from: Vector2) -> bool:
	var v := from - pos
	var d := maxf(v.length(), 1e-6)
	return v.dot(h) / d < -0.2

# 피격. opts: { heavy, kind: melee|arrow, from: Vector2, combo3 }
func receive_hit(dmg: float, opts: Dictionary) -> float:
	var env = b.env
	if not targetable: return 0.0
	since_hit = 0.0
	var back := false
	if state == "eat" and opts.kind == "melee" and is_behind(opts.from):
		back = true; dmg *= G().backAttackMul; stats.back_hits += 1
	hp -= dmg
	if undying: hp = maxf(hp, G().hp * UNDYING_FLOOR)
	var src: String = "back" if back else ("arrow" if opts.kind == "arrow" else ("heavy" if opts.get("heavy", false) else "light"))
	stats.dmg[src] = float(stats.dmg.get(src, 0.0)) + dmg
	env.flash("tiger", Color("#ffe0a0") if back else Color(1, 1, 1), 120)
	if back:
		env.fx("heavyHit", pos.x, pos.y, {})
		env.hit_stop(F().hitStopBack)
		env.shake(F().shakeHeavy[0], F().shakeHeavy[1])
		if stats.back_hits == 1 or stats.back_hits % 3 == 0: env.say("기습! 피해 두 배", 1000)
	else:
		env.fx("heavyHit" if opts.get("heavy", false) else "hit", pos.x, pos.y, {})
		if opts.kind == "melee":
			env.hit_stop(F().hitStopHeavy if opts.get("heavy", false) else (F().hitStopCombo3 if opts.get("combo3", false) else F().hitStopLight))
			var sh: Array = F().shakeHeavy if opts.get("heavy", false) else F().shakeLight
			env.shake(sh[0], sh[1])
	if hp <= 0.0:
		hp = 0.0
		go("dead")
		y = 0.0
		set_anim("dead", true)
		env.shake(F().shakeHeavy[0], F().shakeHeavy[1])
		b.finish("win", G().deathDelay)
		return dmg
	if retreating:
		if opts.get("heavy", false) and state != "retreatRoar":
			state = "retreatStagger"; t = 0.0; set_anim("stagger", true)
		return dmg
	var ra = b.retreat_at
	if ra != null and ra.has("hpRatio") and hp <= G().hp * float(ra.hpRatio) and state != "stunned":
		start_retreat("retreated"); return dmg
	if hp <= G().hp * G().retreatAt and state != "stunned":
		start_retreat(); return dmg
	if state == "stunned" or state == "getup":
		if not roared and hp <= G().hp * G().roarAt: pending_roar = true
		return dmg
	if not roared and hp <= G().hp * G().roarAt: pending_roar = true
	var tp := to_player()
	var s := state
	if s == "eat":
		if back:
			if not disturbed:
				disturbed = true; eat_left = minf(eat_left, G().eatAfterHit)
		else:
			if bait != null:
				b.consume_bait(bait); bait = null
			start_swipe(tp)
		return dmg
	if s == "roar" or s == "territory": return dmg
	poise -= dmg; poise_wait = G().poiseRegenDelay
	if opts.get("heavy", false) and s != "swipe":
		go("stagger"); stun_for = G().stagger; set_anim("stagger", true, G().stagger); poise = G().poise
		return dmg
	if poise <= 0.0 and (s in INTERRUPTIBLE or s in ["land", "toBait", "hit"]):
		go("hit"); set_anim("hit", true, G().flinch); poise = G().poise
		return dmg
	if s in INTERRUPTIBLE:
		if opts.kind == "melee" and tp.d <= G().swipeRange + 0.3 and b.rand() < G().counterChance and not first_pounce: start_swipe(tp)
		else: decide = minf(decide, 0.5)
	if s == "toBait" and opts.kind == "melee":
		if bait != null:
			bait.claimed = false; bait = null
		start_swipe(tp)
	return dmg

func start_retreat(kind := "repelled") -> void:
	var pl = b.player
	retreat_kind = kind
	go("retreat")
	pending_roar = false
	if bait != null:
		bait.claimed = false; bait = null
	set_anim("stagger", true)
	var v: Vector2 = pos - pl.pos
	v = v / maxf(v.length(), 1e-6)
	v.y -= 0.8
	retreat_dir = v / maxf(v.length(), 1e-6)
	if kind == "retreated":
		var to = b.retreat_to
		if to != null:
			var dv: Vector2 = to - pos
			retreat_dir = dv / maxf(dv.length(), 1e-6)
		state = "retreatRoar"; t = 0.0; roar_blast = false
		set_heading(to_player().v)
		set_anim("roar", true, G().retreatRoar)
		b.env.say("호랑이가 크게 포효하고 한 걸음 물러선다… 상처는 깊지 않다." if undying else "호랑이가 \"내 영역에서 나가라\"는 듯 크게 포효하고 돌아선다…", 2600)
		return
	b.env.say("호랑이가 비틀거리며 물러난다… 그래도 쓰러지지는 않는다." if undying else "호랑이가 비틀거리며 물러난다… 몰아붙이면 쓰러뜨릴 수도 있다.", 2600)
