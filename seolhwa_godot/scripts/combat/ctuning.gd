# 전투 수치 — 웹 seolhwa/src/combat/tuning.js 이식(값 그대로). 시간=초, 거리=m, 각도=도.
# 한곳에서 조정한다. sync_timings(dur_of)는 캐릭터 그림 길이에 판정 순간을 맞추고,
# apply_scale(플레이어 반지름, 호랑이 반지름)은 캐릭터 크기에 사거리·몸통을 맞춘다(웹과 같은 규칙).
extends RefCounted

static var T: Dictionary = _base()
static var BASE: Dictionary = _base()

static func _base() -> Dictionary:
	return {
		player = {
			hp = 100.0, stamina = 100.0,
			staminaDelay = 0.6, staminaRegen = 30.0,
			radius = 0.375,
			walk = 3.2, run = 5.0,
			chargeMove = 1.0, bowMove = 1.0, guardMove = 0.9,
			attackCost = 6.0, heavyCost = 16.0,
			combo = [
				{ anim = "attack1", dur = 0.32, hitAt = 0.147, dmg = 8.0, r = 2.1, arc = 110.0, lunge = 0.35, stop = 60 },
				{ anim = "attack2", dur = 0.32, hitAt = 0.154, dmg = 8.0, r = 2.1, arc = 110.0, lunge = 0.35, stop = 60 },
				{ anim = "attack3", dur = 0.45, hitAt = 0.234, dmg = 12.0, r = 2.3, arc = 150.0, lunge = 0.55, stop = 85 },
			],
			comboQueueFrom = 0.06, comboCancelAfter = 0.05, dodgeCancelFrom = 0.06, chargeStartAfter = 0.18,
			heavy = { anim = "heavy", chargeMin = 0.5, dur = 0.6, hitAt = 0.3, dmg = 24.0, r = 2.6, arc = 160.0, lunge = 0.7, stop = 115 },
			dodge = { dur = 0.45, dist = 3.5, iStart = 0.02, iEnd = 0.32, cost = 25.0 },
			guard = { reduce = 0.7, staminaPerDmg = 1.2, breakStun = 1.0, frontDot = -0.1, pounceKnock = 1.2 },
			bow = { arrows = 12, minDraw = 0.35, fullDraw = 0.9, dmg = 10.0, fullDmg = 13.0, speed = 24.0, range = 22.0, recover = 0.25, releaseAt = 0.07, autoAimDeg = 70.0, autoDraw = 0.6 },
			throw = { bait = 3, dur = 0.45, releaseAt = 0.27, dist = 5.0, flight = 0.55 },
			hitStun = 0.38, down = 1.1, getup = 0.55, knockback = 1.6,
			aimAssistDeg = 50.0, aimAssistRange = 4.5,
		},
		tiger = {
			hp = 430.0,
			radius = 0.7, bodyHalf = 0.8, bodyR = 0.55,
			turnRate = 6.0,
			prowlMin = 6.0, prowlMax = 9.0, prowlSpeed = 2.4,
			stalkSpeed = 3.4, stalkTime = 3.0,
			decideMin = 1.8, decideMax = 3.2,
			crouch = 0.8, pounceLen = 8.0, pounceTime = 0.5, pounceDmg = 30.0, pounceHeight = 1.3, pounceWidth = 1.7,
			pounceMin = 4.2, pounceMax = 9.8, land = 1.0, pounceChance = 0.7, stalkPounceRate = 1.6,
			backoffTime = 0.45, backoffDist = 4.0, backoffAfterSwipe = 0.8,
			swipeStrikeFrac = 0.68, pounceAirFrom = 0.15, pounceAirTo = 0.85,
			swipeRange = 2.6, swipeWind = 0.4, swipeActive = 0.12, swipeRecover = 0.7, swipeDmg = 15.0, swipeR = 3.0, swipeArc = 110.0,
			roarAt = 0.5, roarWind = 0.7, roarAfter = 0.8, roarR = 5.5, roarStun = 1.0,
			enrageTime = 0.88, enrageSpeed = 1.2, enrageDecide = 0.65, furyTime = 10.0, doubleSwipe = 0.4,
			poise = 34.0, poiseRegenDelay = 2.0, flinch = 0.45, stagger = 0.9, counterChance = 0.5,
			baitSpeed = 4.0, eat = 3.5, eatAfterHit = 1.6, backAttackMul = 2.0,
			retreatAt = 0.2, retreatPause = 0.8, retreatSpeed = 3.4, retreatStagger = 0.6,
			leash = 1.0, escapeTime = 2.0, escapeFar = 5.0,
			deathDelay = 1.8,
			firstSpeed = 1.15, firstDecide = 0.85, firstRetreatHp = 0.75, firstRetreatTime = 60.0,
			retreatRoar = 1.1,
			guardThreat = 5.0, guardForget = 3.0, treeStop = 2.4,
			getup = 0.6,
		},
		feel = {
			hitStopLight = 60, hitStopCombo3 = 85, hitStopHeavy = 115, hitStopBack = 120,
			hitStopPounce = 120, hitStopSwipe = 80, hitStopBlock = 70,
			shakePounce = [0.4, 320], shakeHeavy = [0.18, 180], shakeRoar = [0.5, 650], shakeHurt = [0.25, 220], shakeLight = [0.06, 90],
		},
		anim = { swipe = 0.75, pounce = 0.6 },
	}

# 각 동작에서 '칼이 닿는/손을 놓는' 순간의 비율(웹 anims.js 키프레임 기준)
const STRIKE_FRAC := { attack1 = 0.46, attack2 = 0.48, attack3 = 0.52, heavy = 0.5, bow_shoot = 0.2, throw = 0.6 }
const DEFAULT_DUR := { attack1 = 0.32, attack2 = 0.32, attack3 = 0.45, heavy = 0.6, dodge = 0.45, bow_shoot = 0.35, throw = 0.45, swipe = 0.75, pounce = 0.6 }

# dur_of(name) → 캐릭터 그림 길이(초, 0이면 기본값). 동작 길이를 맞추고 판정 순간을 그림의 타격 순간에 둔다.
static func sync_timings(dur_of: Callable) -> void:
	var d := func(n: String) -> float:
		var v: float = dur_of.call(n) if dur_of.is_valid() else 0.0
		return v if v > 0.0 else float(DEFAULT_DUR[n])
	var P: Dictionary = T.player
	var B: Dictionary = BASE.player
	for c in P.combo + [P.heavy]:
		c.dur = d.call(c.anim); c.hitAt = c.dur * float(STRIKE_FRAC[c.anim])
	var dd: float = d.call("dodge")
	var k: float = dd / float(B.dodge.dur)
	P.dodge.iStart = float(B.dodge.iStart) * k; P.dodge.iEnd = float(B.dodge.iEnd) * k; P.dodge.dur = dd
	P.bow.releaseAt = d.call("bow_shoot") * float(STRIKE_FRAC.bow_shoot)
	P.bow.recover = maxf(P.bow.releaseAt + 0.1, d.call("bow_shoot") * 0.7)
	P.throw.dur = d.call("throw"); P.throw.releaseAt = P.throw.dur * float(STRIKE_FRAC.throw)
	T.anim = { swipe = d.call("swipe"), pounce = d.call("pounce") }

const RIG_R := { player = 0.3, tiger = 0.8 }

static func apply_scale(player_radius: float, tiger_radius: float) -> void:
	var ps: float = player_radius / float(RIG_R.player)
	var ts: float = tiger_radius / float(RIG_R.tiger)
	var half := func(s: float) -> float: return 1.0 + (s - 1.0) * 0.5
	var P: Dictionary = T.player; var BP: Dictionary = BASE.player
	var G: Dictionary = T.tiger; var BG: Dictionary = BASE.tiger
	P.radius = player_radius
	for i in P.combo.size():
		P.combo[i].r = float(BP.combo[i].r) * ps; P.combo[i].lunge = float(BP.combo[i].lunge) * ps
	P.heavy.r = float(BP.heavy.r) * ps; P.heavy.lunge = float(BP.heavy.lunge) * ps
	P.dodge.dist = float(BP.dodge.dist) * half.call(ps)
	P.aimAssistRange = float(BP.aimAssistRange) * ps
	P.knockback = float(BP.knockback) * half.call(ps)
	G.radius = float(BG.radius) * ts; G.bodyHalf = float(BG.bodyHalf) * ts; G.bodyR = float(BG.bodyR) * ts
	G.swipeR = float(BG.swipeR) * half.call(ts); G.swipeRange = float(BG.swipeRange) * half.call(ts)
	G.pounceWidth = float(BG.pounceWidth) * ts; G.pounceHeight = float(BG.pounceHeight) * ts
	for k in ["pounceLen", "pounceMin", "pounceMax", "prowlMin", "prowlMax", "backoffDist", "roarR"]:
		G[k] = float(BG[k]) * half.call(ts)
	T.scale = { player = ps, tiger = ts }
