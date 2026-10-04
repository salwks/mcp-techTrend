# 짐승 상대 하나(사람 적 판에 섞어 쓴다 — cbattle은 humans 항목에 "creature"가 있으면 이것을 만든다). 처음 쓰는 곳: 제주 김녕사굴 구렁이(S7007 C).
# 사람 적(chuman.gd)과 같은 겉(id·pos·h·state·hp·receive_hit·update…)을 갖되 버릇이 다르다:
#   coil(사려 앉아 머리만 이쪽으로 — 다가오지 않는다. 멀어지면 조금씩 기어 따라온다) → wind(고개를 치켜 S자 — 땅에 물기 줄 예고) →
#   strike(머리를 앞으로 뻗어 문다) → recover(다시 사림) · hit(움찔) ·
#   retreat(체력이 retreat_at 아래면 바위틈 crevice로 기어 들어감) → lurk(틈 속 — 안 보이고 맞지 않는다, lurk초 뒤) → 틈에서 튀어나와 물기(wind부터) ·
#   down(죽음 — fall) · gone(쓰지 않음: 짐승은 달아나 사라지지 않는다 — 판이 끝나야 끝)
# spec: { id, creature: "snake", kind(그림 — jj_snake), name, hp, retreat_at(0~1), lurk(초), crevice: Vector2(틈 자리), pos, dmg, wind(배율), reach(m) }
# 동작 이름(그림): idle(사림) · walk(기어감) · ready(치켜듦) · thrust(물기) · hit · fall · flee(빨리 기어감)
extends RefCounted

const TU := preload("res://scripts/combat/ctuning.gd")
const HB := preload("res://scripts/combat/chit.gd")

const RADIUS := 0.5
const REACH := 2.6          # 물기가 닿는 거리(m)
const STRIKE_LEN := 2.9
const STRIKE_W := 0.7
const WIND := 0.75
const ACTIVE := 0.16
const RECOVER := 0.75
const DMG := 13.0
const CRAWL := 1.1
const FLEE := 2.6

var b
var id := "snake"
var name := "구렁이"
var kind := "jj_snake"
var spec := {}
var pos := Vector2.ZERO
var y := 0.0
var h := Vector2(-1, 0)
var dir := "left"
var hp := 110.0
var max_hp := 110.0
var state := "coil"
var t := 0.0
var cool := 1.0
var struck := false
var tele_h = null
var anim := ""
var push := Vector2.ZERO
var retreat_at := 0.3
var lurk_time := 3.0
var crevice = null
var retreated := 0
var dmg_mul := 1.0
var wind_mul := 1.0
var reach := REACH
var home := Vector2.ZERO
var stats := {}
var said := {}
var body_half := 0.9

func _init(battle, sp: Dictionary, _i: int) -> void:
	b = battle
	spec = sp
	id = String(sp.get("id", "snake"))
	name = String(sp.get("name", "구렁이"))
	kind = String(sp.get("kind", "jj_snake"))
	retreat_at = float(sp.get("retreat_at", 0.3))
	lurk_time = float(sp.get("lurk", 3.0))
	dmg_mul = float(sp.get("dmg", 1.0))
	wind_mul = float(sp.get("wind", 1.0))
	reach = float(sp.get("reach", REACH))
	var cv = sp.get("crevice")
	if cv is Vector2: crevice = cv
	elif cv is Array and cv.size() >= 2: crevice = Vector2(float(cv[0]), float(cv[1]))

func reset(p: Vector2) -> void:
	pos = p; home = p; y = 0.0
	max_hp = float(spec.get("hp", 110.0)); hp = max_hp
	state = "coil"; t = 0.0; cool = 1.2 + b.rand() * 0.6
	struck = false; tele_h = null; anim = ""; push = Vector2.ZERO; retreated = 0
	stats = { attacks = 0, hits = 0, blocked = 0, dmg_taken = 0.0, out = "", retreats = 0 }
	said = {}

var alive: bool:
	get: return state != "down" and state != "gone"
var active: bool:
	get: return state != "down" and state != "gone"
var targetable: bool:
	get: return state != "down" and state != "gone" and state != "lurk"
var retreating: bool:
	get: return state == "retreat" or state == "lurk"
var body_r: float:
	get: return 0.42

func set_anim(n: String, restart := false, dur := 0.0) -> void:
	if n == anim and not restart: return
	anim = n
	b.env.anim(id, n, restart, dur)

# 옆모습만 있다 — 왼쪽·오른쪽으로만 돌린다
func set_heading(v: Vector2) -> void:
	var l := v.length()
	if l < 1e-5: return
	h = v / l
	var d := "right" if h.x > 0.0 else "left"
	if absf(h.x) < 0.25: d = dir if dir in ["left", "right"] else "left"
	if d != dir:
		dir = d; b.env.face(id, d)

func go(s: String) -> void:
	if tele_h != null:
		b.env.fx_remove(tele_h); tele_h = null
	state = s; t = 0.0

func say(key: String, text: String, ms := 1300) -> void:
	if b.said_recently(key): return
	said[key] = true
	if b.env.options.telegraph: b.env.say(text, ms)

func to_player() -> Dictionary:
	var v: Vector2 = b.player.pos - pos
	var d := maxf(v.length(), 1e-6)
	return { v = v / d, d = d }

func move(d: Vector2) -> bool:
	return HB.move_body(b.env, self, d, RADIUS)

func update(dt: float) -> void:
	var pl = b.player
	if push != Vector2.ZERO:
		var kk := minf(1.0, dt * 9.0)
		move(push * kk)
		push *= 1.0 - kk
		if push.length() < 0.02: push = Vector2.ZERO
	t += dt
	if state == "down" or state == "gone": return
	var tp := to_player()
	match state:
		"coil":
			set_anim("idle")
			if not pl.alive: return
			set_heading(tp.v)
			cool -= dt
			if tp.d <= reach and cool <= 0.0 and b.claim(self):
				start_wind(tp); return
			# 지키는 자리에서 너무 멀어지지 않게, 플레이어가 멀면 조금씩 기어 따라온다
			if tp.d > reach + 2.5 and (pos + tp.v * 0.5 - home).length() < 4.5:
				move(tp.v * CRAWL * dt)
				set_anim("walk")
		"wind":
			var wind := WIND * wind_mul
			if t < wind * 0.6: set_heading(tp.v)
			if t >= wind:
				go("strike"); struck = false
				set_anim("thrust", true)
				stats.attacks += 1
		"strike":
			if t <= ACTIVE: move(h * (1.0 / ACTIVE) * dt)
			if not struck and t <= ACTIVE and pl.alive:
				if HB.segment_hit(pos, pos + h * STRIKE_LEN, STRIKE_W * 0.5, pl.pos, TU.T.player.radius):
					var r: String = pl.take_hit(DMG * dmg_mul, pos, "swipe", self)
					if r != "miss":
						struck = true
						if r == "block" or r == "break": stats.blocked += 1
						else: stats.hits += 1
			if t >= ACTIVE: go("recover"); set_anim("idle", true)
		"recover":
			if t >= RECOVER:
				b.release(self)
				go("coil")
				cool = 0.6 + b.rand() * 0.9
		"hit":
			if t >= 0.35:
				b.release(self); go("coil"); cool = 0.4 + b.rand() * 0.5
		"retreat":
			var to: Vector2 = crevice if crevice != null else home
			var v: Vector2 = to - pos
			if v.length() < 0.6:
				go("lurk")
				say("lurk", "%s이(가) 바위틈으로 스며들었다." % name, 1500)
				return
			var ok := move(v.normalized() * FLEE * dt)
			if not ok: pos += v.normalized() * FLEE * dt   # 틈 쪽 바위에 걸려도 비집고 든다
			set_heading(v)
			set_anim("flee")
		"lurk":
			if t >= lurk_time:
				# 틈에서 튀어나와 문다 — 플레이어가 틈 앞에 있으면 바로, 아니면 틈 앞에 사린다
				home = pos
				go("coil"); cool = 0.0
				set_heading(tp.v)
				if tp.d <= reach + 0.8 and b.claim(self): start_wind(tp)
				else: say("out", "%s이(가) 틈에서 다시 머리를 내민다." % name, 1300)

func start_wind(tp: Dictionary) -> void:
	go("wind")
	set_heading(tp.v)
	var wind := WIND * wind_mul
	set_anim("ready", true, wind)
	if b.env.options.telegraph:
		tele_h = b.env.fx("lane", pos.x, pos.y, { dir = h, length = STRIKE_LEN, width = STRIKE_W, duration = wind })
	say("wind", "%s이(가) 고개를 치켜든다!" % name, 900)

func start_retreat() -> void:
	b.release(self)
	retreated += 1
	stats.retreats = retreated
	go("retreat")
	say("retreat", "%s이(가) 몸을 돌려 바위틈 쪽으로 기어간다!" % name, 1500)

func shoved(d: Vector2, dist: float) -> void:
	if not targetable: return
	push = -d.normalized() * dist if d.length() > 0.0 else Vector2.ZERO
	b.release(self)
	go("hit"); set_anim("hit", true, 0.35)

func apply_mods(m: Dictionary) -> void:
	if m.has("hpRatio") and m.hpRatio != null: hp = maxf(1.0, max_hp * float(m.hpRatio))

func receive_hit(dmg: float, opts: Dictionary) -> float:
	var env = b.env
	if not targetable: return 0.0
	hp -= dmg
	stats.dmg_taken += dmg
	env.flash(id, Color(1, 1, 1), 110)
	var heavy: bool = opts.get("heavy", false)
	env.fx("heavyHit" if heavy else "hit", pos.x, pos.y, { scale = 0.7 })
	if opts.kind == "melee":
		env.hit_stop(TU.T.feel.hitStopHeavy if heavy else TU.T.feel.hitStopLight)
		var sh: Array = TU.T.feel.shakeHeavy if heavy else TU.T.feel.shakeLight
		env.shake(sh[0], sh[1])
	var from: Vector2 = opts.get("from", b.player.pos)
	var away: Vector2 = (pos - from)
	away = away / maxf(away.length(), 1e-6)
	if hp <= 0.0:
		hp = 0.0
		b.release(self)
		go("down")
		set_anim("fall", true)
		stats.out = "down"
		b.on_foe_out(self, "down")
		return dmg
	if state == "retreat":
		return dmg
	# 처음 한 번 크게 다치면 바위틈으로 물러난다(retreat_at). 두 번째부터는 사려 버틴다
	if retreated == 0 and retreat_at > 0.0 and hp <= max_hp * retreat_at and crevice != null:
		start_retreat()
		return dmg
	push = away * (0.5 if heavy else 0.25)
	if state in ["coil", "recover"] or heavy:
		b.release(self)
		go("hit"); set_anim("hit", true, 0.35)
	return dmg
