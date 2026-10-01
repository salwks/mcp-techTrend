// 설화록 전투 수치 — 한곳에서 조정한다 (COMBAT.md §3 초안 기반). 시간=초, 거리=m, 각도=도
export const T = {
  player: {
    hp: 100, stamina: 100,
    staminaDelay: 0.6, staminaRegen: 30,
    radius: 0.375,            // 실제 값은 캐릭터가 알려주는 radius로 덮어씀(applyScale)
    walk: 3.2, run: 5.0,
    chargeMove: 1.0, bowMove: 1.0, guardMove: 0.9,
    attackCost: 6, heavyCost: 16,
    // 3연타 콤보: dur=전체 시간, hitAt=판정 순간, r=사거리(몸 중심 기준), arc=부채꼴 각, lunge=앞으로 내딛는 거리
    combo: [
      { anim: 'attack1', dur: 0.32, hitAt: 0.147, dmg: 8, r: 2.1, arc: 110, lunge: 0.35, stop: 60 },
      { anim: 'attack2', dur: 0.32, hitAt: 0.154, dmg: 8, r: 2.1, arc: 110, lunge: 0.35, stop: 60 },
      { anim: 'attack3', dur: 0.45, hitAt: 0.234, dmg: 12, r: 2.3, arc: 150, lunge: 0.55, stop: 85 },
    ],
    comboQueueFrom: 0.06,     // 이 시점 이후 누른 공격은 다음 타로 이어짐
    comboCancelAfter: 0.05,   // 판정 후 이 시간이 지나면 방어(강공격은 회피도)로 끊을 수 있음
    dodgeCancelFrom: 0.06,    // 가벼운 베기는 이 시점부터 회피로 끊을 수 있음
    chargeStartAfter: 0.18,   // 이만큼 누르고 있으면 모으기 자세로
    heavy: { anim: 'heavy', chargeMin: 0.5, dur: 0.6, hitAt: 0.3, dmg: 24, r: 2.6, arc: 160, lunge: 0.7, stop: 115 },
    dodge: { dur: 0.45, dist: 3.5, iStart: 0.02, iEnd: 0.32, cost: 25 },
    guard: { reduce: 0.7, staminaPerDmg: 1.2, breakStun: 1.0, frontDot: -0.1, pounceKnock: 1.2 },
    bow: { arrows: 12, minDraw: 0.35, fullDraw: 0.9, dmg: 10, fullDmg: 13, speed: 24, range: 22, recover: 0.25, releaseAt: 0.07, autoAimDeg: 70, autoDraw: 0.6 },
    throw: { bait: 3, dur: 0.45, releaseAt: 0.27, dist: 5, flight: 0.55 },
    hitStun: 0.38, down: 1.1, getup: 0.55, knockback: 1.6,
    aimAssistDeg: 50, aimAssistRange: 4.5,
  },
  tiger: {
    hp: 430,
    radius: 0.7,              // 지형 충돌용
    bodyHalf: 0.8, bodyR: 0.55, // 몸통 = 머리~꼬리 선분(±bodyHalf) + 반지름
    turnRate: 6,
    prowlMin: 6, prowlMax: 9, prowlSpeed: 2.4,
    stalkSpeed: 3.4, stalkTime: 3.0,
    decideMin: 1.8, decideMax: 3.2,
    crouch: 0.8, pounceLen: 8, pounceTime: 0.5, pounceDmg: 30, pounceHeight: 1.3, pounceWidth: 1.7,
    pounceMin: 4.2, pounceMax: 9.8, land: 1.0, pounceChance: 0.7, stalkPounceRate: 1.6,
    backoffTime: 0.45, backoffDist: 4.0, backoffAfterSwipe: 0.8,
    // 캐릭터 애니메이션 타이밍: 앞발이 내려치는 비율, 도약 애니메이션의 공중 구간(비율)
    swipeStrikeFrac: 0.68, pounceAirFrom: 0.15, pounceAirTo: 0.85,
    swipeRange: 2.6, swipeWind: 0.4, swipeActive: 0.12, swipeRecover: 0.7, swipeDmg: 15, swipeR: 3.0, swipeArc: 110,
    roarAt: 0.5, roarWind: 0.7, roarAfter: 0.8, roarR: 5.5, roarStun: 1.0,
    enrageTime: 0.88, enrageSpeed: 1.2, enrageDecide: 0.65, furyTime: 10, doubleSwipe: 0.4,
    poise: 34, poiseRegenDelay: 2.0, flinch: 0.45, stagger: 0.9, counterChance: 0.5,
    baitSpeed: 4.0, eat: 3.5, eatAfterHit: 1.6, backAttackMul: 2,
    retreatAt: 0.2, retreatPause: 0.8, retreatSpeed: 3.4, retreatStagger: 0.6,
    leash: 1.0, escapeTime: 2.0, escapeFar: 5,
    deathDelay: 1.8,
    // 이야기 모드(STORY §3.5)
    firstSpeed: 1.15, firstDecide: 0.85, firstRetreatHp: 0.75, firstRetreatTime: 60, // 첫 조우: 25% 피해 또는 60초면 물러남
    retreatRoar: 1.1,          // 'retreated' 전에 포효하는 시간
    guardThreat: 5, guardForget: 3, treeStop: 2.4, // 마당: 플레이어가 위협하지 않으면 큰 나무 쪽으로
    getup: 0.6,               // 기절(stunned)에서 일어나는 시간
  },
  feel: {
    hitStopLight: 60, hitStopCombo3: 85, hitStopHeavy: 115, hitStopBack: 120,
    hitStopPounce: 120, hitStopSwipe: 80, hitStopBlock: 70,
    // shake power = 카메라 흔들림(m): 0.1 약함 … 0.5 큼
    shakePounce: [0.4, 320], shakeHeavy: [0.18, 180], shakeRoar: [0.5, 650], shakeHurt: [0.25, 220], shakeLight: [0.06, 90],
  },
};

// ---- 애니메이션 타이밍·크기 맞추기 ----
// 각 동작에서 '칼이 닿는/손을 놓는' 순간의 비율(src/chars/anims.js 키프레임 기준)
export const STRIKE_FRAC = { attack1: 0.46, attack2: 0.48, attack3: 0.52, heavy: 0.5, bow_shoot: 0.2, throw: 0.6 };
export const DEFAULT_DUR = { attack1: 0.32, attack2: 0.32, attack3: 0.45, heavy: 0.6, dodge: 0.45, bow_shoot: 0.35, throw: 0.45, swipe: 0.75, pounce: 0.6 };

// durOf(name) → 캐릭터 애니메이션 길이(초). 전투 동작 길이를 그대로 맞추고, 판정 순간을 그림의 타격 순간에 둔다.
export function syncTimings(durOf) {
  const d = (n) => { const v = durOf ? durOf(n) : 0; return v > 0 ? v : DEFAULT_DUR[n]; };
  const P = T.player;
  for (const c of [...P.combo, P.heavy]) { c.dur = d(c.anim); c.hitAt = c.dur * STRIKE_FRAC[c.anim]; }
  const dd = d('dodge'), k = dd / P.dodge.dur;
  P.dodge.iStart *= k; P.dodge.iEnd *= k; P.dodge.dur = dd;
  P.bow.releaseAt = d('bow_shoot') * STRIKE_FRAC.bow_shoot;
  P.bow.recover = Math.max(P.bow.releaseAt + 0.1, d('bow_shoot') * 0.7);
  P.throw.dur = d('throw'); P.throw.releaseAt = P.throw.dur * STRIKE_FRAC.throw;
  T.anim = { swipe: d('swipe'), pounce: d('pounce') };
}

// 캐릭터 크기(CHAR_SCALE)에 맞춰 사거리·몸통·판정 크기를 조정. 반지름은 캐릭터가 알려주는 값을 쓴다.
const BASE = JSON.parse(JSON.stringify(T));
const RIG_R = { player: 0.3, tiger: 0.8 }; // 크기 1일 때의 반지름
export function applyScale(playerRadius = BASE.player.radius, tigerRadius = RIG_R.tiger) {
  const ps = playerRadius / RIG_R.player, ts = tigerRadius / RIG_R.tiger;
  const half = (s) => 1 + (s - 1) * 0.5; // 거리감(배회·도약 거리)은 절반만 키운다
  const P = T.player, BP = BASE.player, G = T.tiger, BG = BASE.tiger;
  P.radius = playerRadius;
  P.combo.forEach((c, i) => { c.r = BP.combo[i].r * ps; c.lunge = BP.combo[i].lunge * ps; });
  P.heavy.r = BP.heavy.r * ps; P.heavy.lunge = BP.heavy.lunge * ps;
  P.dodge.dist = BP.dodge.dist * half(ps);
  P.aimAssistRange = BP.aimAssistRange * ps;
  P.knockback = BP.knockback * half(ps);
  G.radius = BG.radius * ts; G.bodyHalf = BG.bodyHalf * ts; G.bodyR = BG.bodyR * ts;
  G.swipeR = BG.swipeR * half(ts); G.swipeRange = BG.swipeRange * half(ts);
  G.pounceWidth = BG.pounceWidth * ts; G.pounceHeight = BG.pounceHeight * ts;
  for (const k of ['pounceLen', 'pounceMin', 'pounceMax', 'prowlMin', 'prowlMax', 'backoffDist', 'roarR']) G[k] = BG[k] * half(ts);
  T.scale = { player: ps, tiger: ts };
}
syncTimings(null);
applyScale(0.375, 1.0); // 기본: CHAR_SCALE 1.25
