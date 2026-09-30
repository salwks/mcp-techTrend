// 플레이어 전투 상태 기계 (DOM·three 없음).
// 상태: free · attack · charge · heavy · dodge · guard · guardbreak · bow · bowshot · throw · hit · down · getup · dead
import { T } from './tuning.js';
import { DEG, facing4, moveBody, angleBetween } from './hitbox.js';

const P = T.player;
const ACTIONS = ['attack', 'dodge', 'guard', 'bow', 'item'];

export class PlayerCombat {
  constructor(battle) {
    this.b = battle;
    this.pos = { x: 0, z: 0 };
    this.reset(0, 0);
  }

  reset(x, z) {
    this.pos.x = x; this.pos.z = z;
    this.hp = P.hp; this.st = P.stamina; this.stWait = 0;
    this.state = 'free'; this.t = 0;
    this.fx = 0; this.fz = -1; this.dir = 'up';        // 마지막 이동 방향(단위벡터)과 스프라이트 방향
    this.ax = 0; this.az = -1;                          // 현재 행동의 방향(공격·활)
    this.combo = 0; this.comboGap = 9; this.queued = false;
    this.holding = false; this.hold = 0; this.tap = false; this.chargedCue = false;
    this.spec = null; this.hitDone = false;
    this.ddx = 0; this.ddz = 0; this.dodgeBuf = 0; this.wantDodge = false;
    this.draw = 0; this.arrows = P.bow.arrows; this.bait = P.throw.bait;
    this.stunT = 0; this.kx = 0; this.kz = 0;
    this.anim = ''; this.moving = false;
    this.damageTaken = 0;
    this.ringH = null;
  }

  get alive() { return this.state !== 'dead'; }
  get invulnerable() {
    if (this.state === 'dodge') return this.t >= P.dodge.iStart && this.t <= P.dodge.iEnd;
    return this.state === 'down' || this.state === 'getup' || this.state === 'dead';
  }

  setAnim(name, restart = false) {
    if (name === this.anim && !restart) return;
    this.anim = name;
    this.b.env.anim('player', name, { restart });
  }

  face(dx, dz) {
    const d = facing4(dx, dz, this.dir);
    if (d !== this.dir) { this.dir = d; this.b.env.face('player', d); }
  }

  go(state) { this.state = state; this.t = 0; }

  useStamina(n) { this.st = Math.max(0, this.st - n); this.stWait = P.staminaDelay; }

  move(dx, dz) { return moveBody(this.b.env, this.pos, dx, dz, P.radius); }

  // 공격 방향: 마지막 이동 방향 + (옵션) 조준 보정
  aimDir(assistDeg, range) {
    this.ax = this.fx; this.az = this.fz;
    const tg = this.b.tiger;
    if (!this.b.env.options.aimAssist || !tg || !tg.targetable) return;
    const vx = tg.pos.x - this.pos.x, vz = tg.pos.z - this.pos.z;
    const d = Math.hypot(vx, vz);
    if (d < 1e-3 || d > range) return;
    if (angleBetween(this.fx, this.fz, vx / d, vz / d) <= assistDeg) { this.ax = vx / d; this.az = vz / d; }
  }

  update(dt, ctl) {
    const b = this.b;
    // 기력 회복
    if (this.stWait > 0) this.stWait -= dt;
    else this.st = Math.min(P.stamina, this.st + P.staminaRegen * dt * (this.state === 'guard' ? 0.5 : 1));

    // 공격 버튼: 누름 시간을 재고, 짧게 떼면 '탭'
    this.tap = false;
    if (ctl.pressed('attack')) { this.holding = true; this.hold = 0; this.chargedCue = false; }
    if (this.holding) this.hold += dt;
    if (ctl.released('attack') && this.holding) {
      this.holding = false;
      this.tap = true; // 판정은 상태별로 hold를 보고 결정
    }
    this.comboGap += dt;
    this.t += dt;
    // 회피 입력 버퍼: 공격 중 등 바로 못 구를 때 잠깐 기억했다가 끊을 수 있는 순간에 구른다
    if (ctl.pressed('dodge')) {
      this.dodgeBuf = 0.25;
      const l = Math.hypot(ctl.move.x, ctl.move.z);
      if (l > 0.1) { this.bdx = ctl.move.x / l; this.bdz = ctl.move.z / l; } else { this.bdx = 0; this.bdz = 0; }
    } else if (this.dodgeBuf > 0) this.dodgeBuf -= dt;
    this.wantDodge = this.dodgeBuf > 0;
    this.moving = false;

    const mv = ctl.move;
    const mlen = Math.hypot(mv.x, mv.z);
    if (mlen > 0.1 && this.canSteer()) { this.fx = mv.x / mlen; this.fz = mv.z / mlen; }

    switch (this.state) {
      case 'free': this.updFree(dt, ctl, mv, mlen); break;
      case 'attack': case 'heavy': this.updAttack(dt, ctl); break;
      case 'charge': this.updCharge(dt, ctl, mv, mlen); break;
      case 'dodge': this.updDodge(dt); break;
      case 'guard': this.updGuard(dt, ctl, mv, mlen); break;
      case 'bow': this.updBow(dt, ctl, mv, mlen); break;
      case 'bowshot': if (this.t >= P.bow.recover) this.toFree(); break;
      case 'throw': this.updThrow(dt); break;
      case 'guardbreak': case 'hit':
        this.knock(dt);
        if (this.t >= this.stunT) this.toFree();
        break;
      case 'down':
        this.knock(dt);
        if (this.t >= P.down) { this.go('getup'); this.setAnim('getup', true); }
        break;
      case 'getup': if (this.t >= P.getup) this.toFree(); break;
      case 'dead': break;
    }
    if (this.state !== 'attack' && this.state !== 'heavy' && this.ringH) { b.env.fxRemove(this.ringH); this.ringH = null; }
  }

  canSteer() {
    return this.state === 'free' || this.state === 'charge' || this.state === 'bow' || this.state === 'guard';
  }

  toFree() { this.go('free'); this.queued = false; this.setAnim('idle'); }

  // 공통 행동 시작(자유 상태에서)
  tryActions(ctl) {
    if (this.wantDodge) return this.startDodge(ctl);
    if (ctl.held('guard') || ctl.pressed('guard')) { this.go('guard'); this.setAnim('guard'); this.faceTiger(); return true; }
    if (ctl.pressed('bow') && this.arrows > 0) {
      this.go('bow'); this.draw = 0; this.setAnim('bow_draw', true);
      this.bowAuto = !ctl.hasHeld; return true;
    }
    if (ctl.pressed('item') && this.bait > 0) { this.go('throw'); this.baitThrown = false; this.setAnim('throw', true); this.face(this.fx, this.fz); return true; }
    if (this.tap) {
      if (this.hold >= P.heavy.chargeMin) return this.startHeavy();
      return this.startAttack(this.comboGap < 0.45 ? this.combo + 1 : 1);
    }
    if (this.holding && this.hold >= P.chargeStartAfter) { this.go('charge'); this.setAnim('charge'); return true; }
    return false;
  }

  updFree(dt, ctl, mv, mlen) {
    if (this.tryActions(ctl)) return;
    if (mlen > 0.1) {
      const sp = (ctl.running() ? P.run : P.walk) * Math.min(1, mlen);
      this.moving = this.move(mv.x * sp * dt / Math.max(1, mlen), mv.z * sp * dt / Math.max(1, mlen));
      this.face(mv.x, mv.z);
      this.setAnim(this.moving ? (ctl.running() ? 'run' : 'walk') : 'idle');
    } else this.setAnim('idle');
  }

  startAttack(n) {
    if (n > 3) n = 1;
    if (this.st <= 0) { this.toFree(); return false; }
    const spec = P.combo[n - 1];
    this.combo = n; this.spec = spec; this.hitDone = false; this.queued = false;
    this.useStamina(P.attackCost);
    this.go('attack');
    this.aimDir(P.aimAssistDeg, P.aimAssistRange);
    this.face(this.ax, this.az);
    this.setAnim(spec.anim, true);
    this.showRange(spec);
    return true;
  }

  startHeavy() {
    const spec = P.heavy;
    this.combo = 0; this.spec = spec; this.hitDone = false; this.queued = false;
    this.useStamina(P.heavyCost);
    this.go('heavy');
    this.aimDir(P.aimAssistDeg, P.aimAssistRange + 0.5);
    this.face(this.ax, this.az);
    this.setAnim(spec.anim, true);
    this.showRange(spec);
    return true;
  }

  showRange(spec) {
    const env = this.b.env;
    if (!env.options.ranges) return;
    if (this.ringH) env.fxRemove(this.ringH);
    this.ringH = env.fx('ring', this.pos.x, this.pos.z, { radius: spec.r, duration: spec.dur + 0.1 });
  }

  updAttack(dt, ctl) {
    const s = this.spec;
    // 판정 전까지 앞으로 내딛기
    if (this.t < s.hitAt) {
      const step = (s.lunge / s.hitAt) * dt;
      this.move(this.ax * step, this.az * step);
    }
    if (!this.hitDone && this.t >= s.hitAt) {
      this.hitDone = true;
      this.b.playerStrike(this, s, this.ax, this.az, this.state === 'heavy');
    }
    if (this.state === 'attack' && this.tap && this.t >= P.comboQueueFrom) {
      if (this.hold >= P.heavy.chargeMin) this.queuedHeavy = true; else this.queued = true;
    }
    // 회피는 가벼운 베기를 언제든(휘두르기 직전까지 포함) 끊을 수 있고, 강공격은 판정 뒤에만 끊는다
    if (this.wantDodge && this.t >= (this.state === 'heavy' ? s.hitAt + P.comboCancelAfter : P.dodgeCancelFrom) && this.startDodge(ctl)) return;
    if (this.t >= s.hitAt + P.comboCancelAfter) {
      // 판정 뒤에는 방어로 끊을 수 있다
      if (ctl.held('guard')) { this.queued = false; this.queuedHeavy = false; this.go('guard'); this.setAnim('guard'); this.faceTiger(); return; }
    }
    if (this.t >= s.dur) {
      this.comboGap = 0;
      if (this.queuedHeavy) { this.queuedHeavy = false; this.startHeavy(); return; }
      if (this.queued && this.state === 'attack' && this.combo < 3) { this.startAttack(this.combo + 1); return; }
      if (this.holding) { this.go('charge'); this.setAnim('charge'); return; }
      if (this.combo >= 3 || this.state === 'heavy') this.comboGap = 9;
      this.toFree();
    }
  }

  updCharge(dt, ctl, mv, mlen) {
    if (this.wantDodge && this.startDodge(ctl)) { this.holding = false; return; }
    if (mlen > 0.1) {
      this.moving = this.move(mv.x * P.chargeMove * dt / Math.max(1, mlen), mv.z * P.chargeMove * dt / Math.max(1, mlen));
      this.face(mv.x, mv.z);
    }
    if (!this.chargedCue && this.hold >= P.heavy.chargeMin) {
      this.chargedCue = true;
      this.b.env.flash('player', '#fff1c0', 140);
    }
    if (this.tap || !this.holding) {
      if (this.hold >= P.heavy.chargeMin) this.startHeavy();
      else this.startAttack(1);
    }
  }

  startDodge(ctl) {
    if (this.st <= 0) return false;
    const mv = ctl.move, l = Math.hypot(mv.x, mv.z);
    if (l > 0.1) { this.ddx = mv.x / l; this.ddz = mv.z / l; }
    else if (this.bdx || this.bdz) { this.ddx = this.bdx; this.ddz = this.bdz; }
    else { this.ddx = this.fx; this.ddz = this.fz; }
    this.fx = this.ddx; this.fz = this.ddz;
    this.useStamina(P.dodge.cost);
    this.dodgeBuf = 0; this.wantDodge = false; this.bdx = 0; this.bdz = 0;
    this.queued = false; this.queuedHeavy = false;
    this.go('dodge');
    this.face(this.ddx, this.ddz);
    this.setAnim('dodge', true);
    this.b.env.fx('dust', this.pos.x, this.pos.z, { scale: 0.6 });
    return true;
  }

  updDodge(dt) {
    const D = P.dodge;
    const u0 = Math.max(0, (this.t - dt) / D.dur), u1 = Math.min(1, this.t / D.dur);
    const e = (u) => 1 - (1 - u) * (1 - u);
    const step = D.dist * (e(u1) - e(u0));
    this.move(this.ddx * step, this.ddz * step);
    if (this.t >= D.dur) this.toFree();
  }

  updGuard(dt, ctl, mv, mlen) {
    if (!ctl.held('guard')) { this.toFree(); return; }
    if (this.wantDodge && this.startDodge(ctl)) return;
    this.setAnim('guard');
    this.faceTiger();
    if (mlen > 0.1) {
      this.moving = this.move(mv.x * P.guardMove * dt / Math.max(1, mlen), mv.z * P.guardMove * dt / Math.max(1, mlen));
    }
  }

  // 방어 중에는 가까운 호랑이 쪽을 바라본다(고정 시점에서 방향 맞추기가 어려우므로)
  faceTiger() {
    const tg = this.b.tiger;
    if (!tg || !tg.targetable) return;
    const vx = tg.pos.x - this.pos.x, vz = tg.pos.z - this.pos.z, d = Math.hypot(vx, vz) || 1;
    if (d > 8) return;
    this.fx = vx / d; this.fz = vz / d;
    this.face(this.fx, this.fz);
  }

  updBow(dt, ctl, mv, mlen) {
    const B = P.bow;
    this.draw += dt;
    if (this.wantDodge && this.startDodge(ctl)) return;
    if (mlen > 0.1) this.moving = this.move(mv.x * P.bowMove * dt / Math.max(1, mlen), mv.z * P.bowMove * dt / Math.max(1, mlen));
    // 조준: 가장 가까운 대상(호랑이)으로 자동 보정
    this.ax = this.fx; this.az = this.fz;
    const tg = this.b.tiger;
    if (tg && tg.targetable) {
      const vx = tg.pos.x - this.pos.x, vz = tg.pos.z - this.pos.z, d = Math.hypot(vx, vz) || 1;
      const lim = this.b.env.options.aimAssist ? B.autoAimDeg : 12;
      if (d < B.range && angleBetween(this.fx, this.fz, vx / d, vz / d) <= lim) { this.ax = vx / d; this.az = vz / d; }
    }
    this.face(this.ax, this.az);
    const release = this.bowAuto ? this.draw >= B.autoDraw : ctl.released('bow') || !ctl.held('bow');
    if (release) {
      if (this.draw >= B.minDraw) {
        const full = this.draw >= B.fullDraw;
        this.arrows--;
        this.b.spawnArrow(this.pos.x, this.pos.z, this.ax, this.az, full ? B.fullDmg : B.dmg, full);
        this.go('bowshot');
        this.setAnim('bow_shoot', true);
      } else this.toFree();
    }
  }

  updThrow() {
    const Th = P.throw;
    if (!this.baitThrown && this.t >= Th.releaseAt) {
      this.baitThrown = true;
      this.bait--;
      this.b.throwBait(this.pos.x, this.pos.z, this.fx, this.fz, Th.dist, Th.flight);
    }
    if (this.t >= Th.dur) this.toFree();
  }

  knock(dt) {
    if (this.kx || this.kz) {
      const k = Math.min(1, dt * 8);
      this.move(this.kx * k, this.kz * k);
      this.kx *= 1 - k; this.kz *= 1 - k;
      if (Math.abs(this.kx) + Math.abs(this.kz) < 0.01) { this.kx = 0; this.kz = 0; }
    }
  }

  // 호랑이 공격을 받음. kind: 'swipe' | 'pounce'. 반환: 'miss' | 'block' | 'break' | 'hit' | 'down' | 'dead'
  takeHit(dmg, fromX, fromZ, kind) {
    const b = this.b, env = b.env, F = T.feel;
    if (!this.alive || this.invulnerable) return 'miss';
    let vx = fromX - this.pos.x, vz = fromZ - this.pos.z;
    const d = Math.hypot(vx, vz) || 1; vx /= d; vz /= d;
    this.queued = false; this.queuedHeavy = false; this.holding = false;
    if (this.state === 'guard' && vx * this.fx + vz * this.fz > P.guard.frontDot) {
      const dealt = dmg * (1 - P.guard.reduce);
      this.hp -= dealt; this.damageTaken += dealt;
      this.st -= dmg * P.guard.staminaPerDmg; this.stWait = P.staminaDelay;
      env.fx('block', this.pos.x + vx * 0.5, this.pos.z + vz * 0.5, { dir: { x: vx, z: vz } });
      env.hitStop(F.hitStopBlock);
      if (kind === 'pounce') { this.kx = -vx * P.guard.pounceKnock; this.kz = -vz * P.guard.pounceKnock; env.shake(...F.shakeHurt); }
      if (this.hp <= 0) return this.die();
      if (this.st <= 0) {
        this.st = 0;
        this.go('guardbreak'); this.stunT = P.guard.breakStun; this.setAnim('hit', true);
        env.say('방어가 무너졌다!', 1200);
        return 'break';
      }
      return 'block';
    }
    this.hp -= dmg; this.damageTaken += dmg;
    env.flash('player', '#ffd0c0', 140);
    env.fx(kind === 'pounce' ? 'heavyHit' : 'hit', this.pos.x, this.pos.z, { dir: { x: -vx, z: -vz } });
    if (this.hp <= 0) { env.hitStop(F.hitStopPounce); env.shake(...F.shakeHurt); return this.die(); }
    if (kind === 'pounce') {
      env.hitStop(F.hitStopPounce);
      env.shake(...F.shakeHurt);
      this.kx = -vx * P.knockback; this.kz = -vz * P.knockback;
      this.go('down'); this.setAnim('down', true);
      return 'down';
    }
    env.hitStop(F.hitStopSwipe);
    this.kx = -vx * 0.6; this.kz = -vz * 0.6;
    this.go('hit'); this.stunT = P.hitStun; this.setAnim('hit', true);
    return 'hit';
  }

  // 포효 경직
  stun(sec) {
    if (!this.alive || this.invulnerable) return false;
    if (this.state === 'guard') sec *= 0.4;
    this.holding = false; this.queued = false;
    this.go('hit'); this.stunT = sec; this.setAnim('hit', true);
    return true;
  }

  die() {
    this.hp = 0;
    this.go('dead');
    this.setAnim('dead', true);
    return 'dead';
  }
}

export { ACTIONS, DEG };
