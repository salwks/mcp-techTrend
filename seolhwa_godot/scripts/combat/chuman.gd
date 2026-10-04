# 사람 적 하나의 상태 기계(밀수꾼·도적·경비 — 경주 S3005에서 처음 쓰고 함흥·한양 최종장이 같이 쓴다).
# 동작은 HUM_COMBAT_LIGHT(CHARACTER_MASTER §7): ready · swing · thrust · hit · fall · flee (+ 기본 idle·walk·run).
# 상태: ready(거리를 두고 맴돔) · approach(공격 차례를 얻어 다가감) · wind(예고 — 땅에 부채꼴/줄, 치켜듦) · strike · recover ·
#       hit(움찔) · stagger(크게 비틀) · flee(체력이 적으면 등을 돌려 달아남) · down(쓰러짐 — 죽이지 않는다) · gone(달아나 사라짐)
# 무리: 한 번에 한 명만 덤빈다(cbattle.claim/release — 공격 차례). 나머지는 hold 거리에서 맴돌며 기다린다.
# 위치·방향은 Vector2(x, z). 그림·효과는 env(combat_view)가 맡는다 — who = id.
# spec(사건 데이터 arenas.<id>.humans[]): { id, kind, name, weapon: "club"(내리치기) | "pole"(찌르기) | "both",
#   hp, flee_at(0~1, 0이면 끝까지 버팀), at·offset(자리), dmg(배율), wind(배율 — 클수록 느린 예고) }
extends RefCounted

const TU := preload("res://scripts/combat/ctuning.gd")
const HB := preload("res://scripts/combat/chit.gd")

var b
var id := "foe0"
var name := "밀수꾼"
var kind := "smuggler"
var weapon := "club"
var spec := {}
var pos := Vector2.ZERO
var y := 0.0
var h := Vector2(0, 1)
var dir := "down"
var hp := 60.0
var max_hp := 60.0
var state := "ready"
var t := 0.0
var decide := 1.0
var orbit := 1.0
var hold_r := 3.8
var poise := 14.0
var poise_wait := 0.0
var struck := false
var atk := "swing"
var tele_h = null
var anim := ""
var push := Vector2.ZERO
var flee_dir := Vector2.ZERO
var flee_at := 0.3
var dmg_mul := 1.0
var wind_mul := 1.0
var stats := {}
var said := {}
var body_half := 0.0

func _init(battle, sp: Dictionary, i: int) -> void:
	b = battle
	spec = sp
	id = String(sp.get("id", "foe%d" % i))
	name = String(sp.get("name", "밀수꾼"))
	kind = String(sp.get("kind", "smuggler"))
	weapon = String(sp.get("weapon", "club"))
	flee_at = float(sp.get("flee_at", G().fleeAt))
	dmg_mul = float(sp.get("dmg", 1.0))
	wind_mul = float(sp.get("wind", 1.0))
	orbit = 1.0 if i % 2 == 0 else -1.0

static func G() -> Dictionary: return TU.T.human
static func F() -> Dictionary: return TU.T.feel

func reset(p: Vector2) -> void:
	pos = p; y = 0.0
	max_hp = float(spec.get("hp", G().hp)); hp = max_hp
	state = "ready"; t = 0.0
	decide = 0.6 + b.rand() * 1.2
	hold_r = G().holdMin + b.rand() * (G().holdMax - G().holdMin)
	poise = G().poise; poise_wait = 0.0
	struck = false; tele_h = null; anim = ""; push = Vector2.ZERO
	stats = { attacks = 0, hits = 0, blocked = 0, dmg_taken = 0.0, out = "" }
	said = {}

var alive: bool:
	get: return state != "down" and state != "gone"
var active: bool:            # 아직 싸움에 남아 있나(쓰러지거나 달아나 사라지지 않음)
	get: return state != "down" and state != "gone"
var targetable: bool:
	get: return state != "down" and state != "gone"
var retreating: bool:
	get: return state == "flee" or state == "gone"
var body_r: float:
	get: return float(G().bodyR)

func set_anim(n: String, restart := false, dur := 0.0) -> void:
	if n == anim and not restart: return
	anim = n
	b.env.anim(id, n, restart, dur)

func set_heading(v: Vector2) -> void:
	var l := v.length()
	if l < 1e-5: return
	h = v / l
	var d := HB.facing4(h.x, h.y, dir, 1.0)
	if d != dir:
		dir = d; b.env.face(id, d)

func turn_to(v: Vector2, dt: float) -> void:
	set_heading(HB.turn_toward(h, v, G().turnRate * dt))

func go(s: String) -> void:
	if tele_h != null:
		b.env.fx_remove(tele_h); tele_h = null
	state = s; t = 0.0

func say(key: String, text: String, ms := 1300, once := false) -> void:
	if once and said.has(key): return
	if b.said_recently(key): return
	said[key] = true
	if b.env.options.telegraph or once: b.env.say(text, ms)

func to_player() -> Dictionary:
	var v: Vector2 = b.player.pos - pos
	var d := maxf(v.length(), 1e-6)
	return { v = v / d, d = d }

func move(d: Vector2) -> bool:
	return HB.move_body(b.env, self, d, G().radius)

func move_in(d: Vector2, limit: float) -> bool:
	var a: Dictionary = b.arena
	var n := pos + d - Vector2(a.x, a.z)
	var r := n.length()
	if limit > 0.0 and r > limit:
		var u := n / r
		var o := d.dot(u)
		if o > 0.0: d -= u * o
	return move(d)

func _attack_kind(d: float) -> String:
	match weapon:
		"pole": return "thrust"
		"both": return "thrust" if d > G().engage + 0.4 and b.rand() < 0.7 else "swing"
	return "swing"

func _reach(k: String) -> float:
	return G().thrustRange if k == "thrust" else G().engage

func update(dt: float) -> void:
	var pl = b.player
	if push != Vector2.ZERO:
		var kk := minf(1.0, dt * 9.0)
		move(push * kk)
		push *= 1.0 - kk
		if push.length() < 0.02: push = Vector2.ZERO
	t += dt
	if poise_wait > 0.0: poise_wait -= dt
	else: poise = minf(G().poise, poise + 8.0 * dt)
	if state == "down" or state == "gone": return
	var tp := to_player()
	var lim: float = float(b.arena.radius) + 1.5
	match state:
		"ready":
			if not pl.alive:
				set_anim("ready"); return
			decide -= dt
			# 공격 차례: 아무도 안 쥐었고 앞 사람이 덤빈 지 tokenGap이 지났으면
			if decide <= 0.0 and b.claim(self):
				atk = _attack_kind(tp.d)
				go("approach"); return
			# 맴돌기: hold 거리를 지키며 옆으로
			var tv := Vector2(-tp.v.y, tp.v.x) * orbit
			var rad := 0.0
			if tp.d < hold_r - 0.5: rad = -1.0
			elif tp.d > hold_r + 0.5: rad = 1.0
			var m: Vector2 = tv * 0.6 + tp.v * rad
			var sp: float = G().orbitSpeed if rad == 0.0 else (G().run if tp.d > hold_r + 4.0 else G().walk)
			m = m / maxf(m.length(), 1e-6)
			if not move_in(m * sp * dt, lim): orbit *= -1.0
			set_heading(tp.v)
			set_anim("run" if sp >= G().run else ("walk" if rad != 0.0 else "ready"))
			if b.rand() < dt * 0.25: orbit *= -1.0
		"approach":
			if not pl.alive:
				b.release(self); go("ready"); return
			var reach := _reach(atk)
			if tp.d <= reach:
				start_wind(tp); return
			var spd: float = G().run if tp.d > 4.5 else G().walk * 1.25
			move_in(tp.v * spd * dt, lim)
			turn_to(tp.v, dt)
			set_anim("run" if spd >= G().run else "walk")
			if t > G().approachTime:
				b.release(self); go("ready"); decide = 0.8
		"wind":
			var wind: float = (G().thrustWind if atk == "thrust" else G().swingWind) * wind_mul
			if t < wind * G().aimLock: turn_to(tp.v, dt)
			if t >= wind:
				go("strike"); struck = false
				stats.attacks += 1
				if atk == "swing": b.env.fx("slash", pos.x, pos.y, { dir = h, radius = G().swingR * 0.9, arc = G().swingArc, height = 0.9 })
		"strike":
			var act: float = G().thrustActive if atk == "thrust" else G().swingActive
			var lunge: float = G().thrustLunge if atk == "thrust" else G().swingLunge
			if t <= act: move_in(h * (lunge / act) * dt, lim)
			if not struck and t <= act and pl.alive:
				var hit := false
				if atk == "thrust":
					hit = HB.segment_hit(pos, pos + h * G().thrustLen, G().thrustWidth * 0.5, pl.pos, TU.T.player.radius)
				else:
					hit = HB.fan_hit(pos, h, G().swingR, G().swingArc, pl.pos, TU.T.player.radius)
				if hit:
					var dmg: float = (G().thrustDmg if atk == "thrust" else G().swingDmg) * dmg_mul
					var r: String = pl.take_hit(dmg, pos, "swipe", self)
					if r != "miss":
						struck = true
						if r == "block" or r == "break": stats.blocked += 1
						else: stats.hits += 1
			if t >= act:
				go("recover")
		"recover":
			if t > 0.25: set_heading(tp.v)
			if t >=(G().thrustRecover if atk == "thrust" else G().swingRecover):
				b.release(self)
				go("ready")
				decide = G().decideMin + b.rand() * (G().decideMax - G().decideMin)
				hold_r = G().holdMin + b.rand() * (G().holdMax - G().holdMin)
				if b.rand() < 0.5: orbit *= -1.0
		"hit":
			if t >= G().flinch: _to_ready(0.5)
		"stagger":
			if t >= G().stagger: _to_ready(0.4)
		"flee":
			var a: Dictionary = b.arena
			var far: float = float(a.radius) + G().fleeFar
			if not move(flee_dir * G().fleeSpeed * dt):
				flee_dir = flee_dir.rotated(0.9 * (1.0 if orbit > 0.0 else -1.0))
			set_heading(flee_dir)
			set_anim("flee")
			if (pos - Vector2(a.x, a.z)).length() > far or t > G().fleeTime:
				go("gone")
				stats.out = "fled"
				b.on_foe_out(self, "fled")
	# 몸끼리 겹치지 않게(다른 적·플레이어)
	if state != "flee":
		for o in b.foes:
			if o == self or not o.active: continue
			var dv: Vector2 = pos - o.pos
			var dd := dv.length()
			if dd < 1.0 and dd > 1e-4: move(dv / dd * (1.0 - dd) * 0.5)
	if pl.alive:
		var dv2: Vector2 = pl.pos - pos
		var d2 := dv2.length()
		var mn: float = G().radius + TU.T.player.radius
		if d2 < mn and d2 > 1e-4: pl.move(dv2 / d2 * (mn - d2))

func _to_ready(dec: float) -> void:
	b.release(self)
	go("ready")
	decide = dec + b.rand() * 0.6

func start_wind(tp: Dictionary) -> void:
	go("wind")
	set_heading(tp.v)
	var wind: float = (G().thrustWind if atk == "thrust" else G().swingWind) * wind_mul
	var frac: float = float(G().strikeFrac.get(atk, 0.6))
	set_anim(atk, true, wind / frac)
	if b.env.options.telegraph:
		if atk == "thrust":
			tele_h = b.env.fx("lane", pos.x, pos.y, { dir = h, length = G().thrustLen, width = G().thrustWidth, duration = wind })
			say("thrust", "%s이(가) 장대를 겨눈다!" % name, 900)
		else:
			tele_h = b.env.fx("fan", pos.x, pos.y, { dir = h, radius = G().swingR, arc = G().swingArc, duration = wind })
			say("swing", "%s이(가) 몽둥이를 치켜든다!" % name, 900)

func start_flee() -> void:
	b.release(self)
	go("flee")
	var tp := to_player()
	flee_dir = -tp.v
	var to = b.flee_to
	if to != null:
		var dv: Vector2 = to - pos
		if dv.length() > 1.0: flee_dir = (dv.normalized() * 0.7 + flee_dir * 0.3).normalized()
	stats.out = "fleeing"
	say("flee", "%s이(가) 등을 돌려 달아난다!" % name, 1600)

# 받아밀기(플레이어 숙련): 막힌 공격 뒤 밀려나며 움찔
func shoved(d: Vector2, dist: float) -> void:
	if not targetable or state == "flee": return
	push = -d.normalized() * dist if d.length() > 0.0 else Vector2.ZERO
	b.release(self)
	go("hit"); set_anim("hit", true, G().flinch)

func apply_mods(m: Dictionary) -> void:
	if m.has("hpRatio") and m.hpRatio != null: hp = maxf(1.0, max_hp * float(m.hpRatio))

# 피격. opts: { heavy, kind: melee|arrow, from: Vector2, combo3 }
func receive_hit(dmg: float, opts: Dictionary) -> float:
	var env = b.env
	if not targetable: return 0.0
	hp -= dmg
	stats.dmg_taken += dmg
	env.flash(id, Color(1, 1, 1), 110)
	var heavy: bool = opts.get("heavy", false)
	env.fx("heavyHit" if heavy else "hit", pos.x, pos.y, { scale = 0.8 })
	if opts.kind == "melee":
		env.hit_stop(F().hitStopHeavy if heavy else (F().hitStopCombo3 if opts.get("combo3", false) else F().hitStopLight))
		var sh: Array = F().shakeHeavy if heavy else F().shakeLight
		env.shake(sh[0], sh[1])
	var from: Vector2 = opts.get("from", b.player.pos)
	var away: Vector2 = (pos - from)
	away = away / maxf(away.length(), 1e-6)
	if hp <= 0.0:
		hp = 0.0
		b.release(self)
		go("down")
		push = away * G().heavyKnock
		set_anim("fall", true)
		stats.out = "down"
		b.on_foe_out(self, "down")
		return dmg
	if state == "flee":
		push = away * G().knock
		return dmg
	if flee_at > 0.0 and hp <= max_hp * flee_at:
		push = away * G().knock
		start_flee()
		return dmg
	poise -= dmg; poise_wait = G().poiseRegenDelay
	if heavy:
		b.release(self)
		go("stagger"); set_anim("hit", true, G().stagger)
		push = away * G().heavyKnock; poise = G().poise
		return dmg
	push = away * G().knock
	if poise <= 0.0 or state in ["ready", "approach", "recover", "hit"]:
		b.release(self)
		go("hit"); set_anim("hit", true, G().flinch)
		if poise <= 0.0: poise = G().poise
	return dmg
