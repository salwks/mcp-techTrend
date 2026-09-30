// 설화록 전투 수치 — 한곳에서 조정한다 (COMBAT.md §3 초안 기반). 시간=초, 거리=m, 각도=도
export const T = {
  player: {
    hp: 100, stamina: 100,
    staminaDelay: 0.6, staminaRegen: 30,
    radius: 0.35,
    walk: 3.2, run: 5.0,
    chargeMove: 1.0, bowMove: 1.0, guardMove: 0.9,
    attackCost: 6, heavyCost: 16,
    // 3연타 콤보: dur=전체 시간, hitAt=판정 순간, r=사거리(몸 중심 기준), arc=부채꼴 각, lunge=앞으로 내딛는 거리
    combo: [
      { anim: 'attack1', dur: 0.36, hitAt: 0.12, dmg: 8, r: 2.1, arc: 110, lunge: 0.35, stop: 60 },
      { anim: 'attack2', dur: 0.36, hitAt: 0.12, dmg: 8, r: 2.1, arc: 110, lunge: 0.35, stop: 60 },
      { anim: 'attack3', dur: 0.52, hitAt: 0.18, dmg: 12, r: 2.3, arc: 150, lunge: 0.55, stop: 85 },
    ],
    comboQueueFrom: 0.06,     // 이 시점 이후 누른 공격은 다음 타로 이어짐
    comboCancelAfter: 0.05,   // 판정 후 이 시간이 지나면 회피로 끊을 수 있음
    chargeStartAfter: 0.18,   // 이만큼 누르고 있으면 모으기 자세로
    heavy: { anim: 'heavy', chargeMin: 0.5, dur: 0.6, hitAt: 0.2, dmg: 24, r: 2.6, arc: 160, lunge: 0.7, stop: 115 },
    dodge: { dur: 0.45, dist: 3.5, iStart: 0.02, iEnd: 0.32, cost: 25 },
    guard: { reduce: 0.7, staminaPerDmg: 1.2, breakStun: 1.0, frontDot: -0.1, pounceKnock: 1.2 },
    bow: { arrows: 12, minDraw: 0.35, fullDraw: 0.9, dmg: 10, fullDmg: 13, speed: 24, range: 22, recover: 0.25, autoAimDeg: 70, autoDraw: 0.6 },
    throw: { bait: 3, dur: 0.45, releaseAt: 0.2, dist: 5, flight: 0.55 },
    hitStun: 0.38, down: 1.1, getup: 0.55, knockback: 1.6,
    aimAssistDeg: 50, aimAssistRange: 4.5,
  },
  tiger: {
    hp: 320,
    radius: 0.7,              // 지형 충돌용
    bodyHalf: 0.8, bodyR: 0.55, // 몸통 = 머리~꼬리 선분(±bodyHalf) + 반지름
    turnRate: 6,
    prowlMin: 6, prowlMax: 9, prowlSpeed: 2.4,
    stalkSpeed: 3.4, stalkTime: 3.0,
    decideMin: 1.4, decideMax: 2.8,
    crouch: 0.8, pounceLen: 8, pounceTime: 0.5, pounceDmg: 30, pounceHeight: 1.3, pounceWidth: 1.7,
    pounceMin: 4.2, pounceMax: 9.8, land: 1.0,
    swipeRange: 2.6, swipeWind: 0.4, swipeActive: 0.12, swipeRecover: 0.55, swipeDmg: 15, swipeR: 3.0, swipeArc: 110,
    roarAt: 0.5, roarWind: 0.7, roarAfter: 0.8, roarR: 5.5, roarStun: 1.0,
    enrageTime: 0.8, enrageSpeed: 1.2, enrageDecide: 0.65, furyTime: 10, doubleSwipe: 0.4,
    poise: 26, poiseRegenDelay: 2.0, flinch: 0.45, stagger: 0.9, counterChance: 0.5,
    baitSpeed: 4.0, eat: 3.5, eatAfterHit: 1.1, backAttackMul: 2,
    retreatAt: 0.2, retreatPause: 0.8, retreatSpeed: 3.4, retreatStagger: 0.6,
    leash: 1.0, escapeTime: 2.0, escapeFar: 5,
    deathDelay: 1.8,
  },
  feel: {
    hitStopLight: 60, hitStopCombo3: 85, hitStopHeavy: 115, hitStopBack: 120,
    hitStopPounce: 120, hitStopSwipe: 80, hitStopBlock: 70,
    // shake power = 카메라 흔들림(m): 0.1 약함 … 0.5 큼
    shakePounce: [0.4, 320], shakeHeavy: [0.18, 180], shakeRoar: [0.5, 650], shakeHurt: [0.25, 220], shakeLight: [0.06, 90],
  },
};
