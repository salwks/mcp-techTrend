// 호랑이 AI 상태 기계 (DOM·three 없음). COMBAT.md §3 행동 규칙.
// 상태: prowl(배회) · stalk(다가감) · crouch(덮치기 예고) · pounce · land(빈틈) · swipeWind(앞발 예고) · swipe
//       roar · hit(움찔) · stagger(경직) · toBait · eat · territory(영역 끝에서 으르렁) · home(영역 가운데로)
//       retreat(물러남) · gone · dead
import { T } from './tuning.js';
import { fanHit, segmentHit, facing4, moveBody, turnToward, closestOnSeg } from './hitbox.js';

const G = T.tiger, F = T.feel;
const _o = { x: 0, z: 0 };
const _c = { x: 0, z: 0 };
const _tp = { vx: 0, vz: 1, d: 1 };

const INTERRUPTIBLE = new Set(['prowl', 'stalk', 'home', 'backoff']);

export class TigerAI {
  constructor(battle) {
    this.b = battle;
    this.pos = { x: 0, z: 0 };
    this.reset(0, 0);
  }

  reset(x, z) {
    this.pos.x = x; this.pos.z = z;
    this.y = 0; // 도약 높이
    this.hp = G.hp;
    this.state = 'prowl'; this.t = 0;
    this.hx = 0; this.hz = 1; this.dir = 'down';
    this.orbit = 1; this.orbitR = 7.5;
    this.decide = 1.5;
    this.roared = false; this.pendingRoar = false; this.enraged = false; this.fury = 0;
    this.poise = G.poise; this.poiseWait = 0;
    this.pounceHit = false; this.ps = { x: 0, z: 0 }; this.pe = { x: 0, z: 0 };
    this.bait = null; this.disturbed = false; this.eatLeft = 0;
    this.swipeHit = false; this.swipeChain = 0;
    this.teleH = null;
    this.anim = '';
    this.retreatDir = { x: 0, z: -1 };
    this.stats = { pounces: 0, pounceHits: 0, swipes: 0, swipeHits: 0, baits: 0, backHits: 0, blocks: 0, roar: false, dmg: {}, hitState: {} };
    this.said = {};
  }

  get alive() { return this.state !== 'dead'; }
  // 공격받을 수 있는가(도약 중엔 판정 없음)
  get targetable() { return this.state !== 'dead' && this.state !== 'gone' && this.state !== 'pounce'; }
  get tm() { return this.enraged ? G.enrageTime : 1; }   // 예고·빈틈 시간 배율
  get sm() { return this.enraged ? G.enrageSpeed : 1; }  // 이동 속도 배율

  // dur: 이 동작을 몇 초에 맞춰 재생할지(캐릭터 애니메이션 속도를 맞춘다)
  setAnim(name, restart = false, dur = 0) {
    if (name === this.anim && !restart) return;
    this.anim = name;
    this.b.env.anim('tiger', name, { restart, dur });
  }

  setHeading(x, z) {
    const l = Math.hypot(x, z);
    if (l < 1e-5) return;
    this.hx = x / l; this.hz = z / l;
    const d = facing4(this.hx, this.hz, this.dir, 0.55); // 호랑이는 옆모습을 우선
    if (d !== this.dir) { this.dir = d; this.b.env.face('tiger', d); }
  }

  turnTo(x, z, dt) {
    turnToward(this.hx, this.hz, x, z, G.turnRate * dt, _o);
    this.setHeading(_o.x, _o.z);
  }

  go(s) {
    if (this.teleH) { this.b.env.fxRemove(this.teleH); this.teleH = null; }
    // 떡을 먹지 못하고 다른 행동으로 넘어가면 떡을 놓아준다(다시 먹으러 올 수 있게)
    if ((this.state === 'toBait' || this.state === 'eat') && s !== 'eat' && this.bait) {
      if (!this.bait.gone) this.bait.claimed = false;
      this.bait = null;
    }
    this.state = s; this.t = 0;
  }

  say(key, text, ms = 1600, once = false) {
    if (once && this.said[key]) return;
    this.said[key] = (this.said[key] || 0) + 1;
    if (this.b.env.options.telegraph || once) this.b.env.say(text, ms);
  }

  // 영역 안으로 제한하며 이동
  moveIn(dx, dz, limit) {
    const a = this.b.arena;
    const nx = this.pos.x + dx - a.x, nz = this.pos.z + dz - a.z;
    const r = Math.hypot(nx, nz);
    if (limit && r > limit) {
      // 경계 밖으로 나가려 하면 접선 방향 성분만 남김
      const ux = nx / r, uz = nz / r, out = dx * ux + dz * uz;
      if (out > 0) { dx -= ux * out; dz -= uz * out; }
    }
    return moveBody(this.b.env, this.pos, dx, dz, G.radius);
  }

  // 플레이어 쪽 단위벡터와 거리. 매 프레임 새 객체를 만들지 않도록 공유 객체를 돌려준다(저장하지 말 것)
  toPlayer() {
    const p = this.b.player.pos;
    const vx = p.x - this.pos.x, vz = p.z - this.pos.z;
    const d = Math.hypot(vx, vz) || 1e-6;
    _tp.vx = vx / d; _tp.vz = vz / d; _tp.d = d;
    return _tp;
  }

  update(dt) {
    const b = this.b, env = b.env, pl = b.player;
    this.t += dt;
    if (this.fury > 0) this.fury -= dt;
    if (this.poiseWait > 0) this.poiseWait -= dt; else this.poise = Math.min(G.poise, this.poise + 10 * dt);
    const tp = this.toPlayer();
    const lim = b.arena.radius - 0.8;

    // 플레이어가 쓰러졌으면 배회만
    const playerDown = !pl.alive;

    // 영역 밖 → 쫓지 않음
    if (b.playerOutside && !['dead', 'retreat', 'gone', 'territory', 'home', 'pounce', 'land', 'swipe', 'swipeWind'].includes(this.state)) {
      this.go('territory');
      this.setHeading(tp.vx, tp.vz);
      this.setAnim('roar', true);
      this.say('territory', '호랑이가 영역 끝에서 으르렁거린다… 더는 쫓아오지 않는다.', 2400, true);
      env.fx('roar', this.pos.x, this.pos.z, { radius: 3 });
    }

    // 포효 대기 중이면 끊을 수 있는 순간에 포효
    if (this.pendingRoar && (INTERRUPTIBLE.has(this.state) || this.state === 'hit' || this.state === 'eat' || this.state === 'toBait') && !b.playerOutside) {
      this.pendingRoar = false;
      this.startRoar();
    }

    switch (this.state) {
      case 'prowl': {
        if (playerDown) { this.setAnim('idle'); break; }
        if (this.tryBait()) break;
        // 원을 그리며 거리 유지
        const tx = -tp.vz * this.orbit, tz = tp.vx * this.orbit;
        let rad = 0;
        if (tp.d < this.orbitR - 0.6) rad = -1; else if (tp.d > this.orbitR + 0.6) rad = 1;
        let mx = tx * 0.85 + tp.vx * rad * 0.7, mz = tz * 0.85 + tp.vz * rad * 0.7;
        const ml = Math.hypot(mx, mz) || 1;
        mx /= ml; mz /= ml;
        const sp = G.prowlSpeed * this.sm * (rad < 0 ? 1.3 : 1);
        // 영역 경계에 닿으면 도는 방향을 바꾼다
        const ex = this.pos.x + mx * 0.8 - b.arena.x, ez = this.pos.z + mz * 0.8 - b.arena.z;
        if (Math.hypot(ex, ez) > lim) { this.orbit *= -1; }
        if (!this.moveIn(mx * sp * dt, mz * sp * dt, lim)) this.orbit *= -1;
        this.turnTo(mx, mz, dt);
        this.setAnim('prowl');
        if (tp.d < 2.4) this.decide = Math.min(this.decide, 0.3);
        this.decide -= dt;
        if (this.decide <= 0) this.choose(tp);
        break;
      }
      case 'stalk': {
        if (playerDown) { this.toProwl(); break; }
        if (this.tryBait()) break;
        const sp = G.stalkSpeed * this.sm;
        this.moveIn(tp.vx * sp * dt, tp.vz * sp * dt, lim);
        this.turnTo(tp.vx, tp.vz, dt);
        this.setAnim('walk');
        if (tp.d <= G.swipeRange - 0.3) this.startSwipe(tp);
        else if (this.t > 0.6 && tp.d >= 5 && tp.d <= G.pounceMax - 1 && b.rand() < dt * G.stalkPounceRate) this.startCrouch(tp);
        else if (this.t > G.stalkTime) this.toProwl();
        break;
      }
      case 'crouch': {
        this.setAnim('crouch');
        if (this.t >= G.crouch * this.tm) this.startPounce();
        break;
      }
      case 'pounce': {
        const u = Math.min(1, this.t / (G.pounceTime / this.sm));
        const px = this.pos.x, pz = this.pos.z;
        const nx = this.ps.x + (this.pe.x - this.ps.x) * u, nz = this.ps.z + (this.pe.z - this.ps.z) * u;
        this.pos.x = nx; this.pos.z = nz;
        this.y = Math.sin(Math.PI * u) * G.pounceHeight;
        if (!this.pounceHit && pl.alive && u > 0.08) {
          const hx = nx + this.hx * G.bodyHalf, hz = nz + this.hz * G.bodyHalf;
          if (segmentHit(px - this.hx * G.bodyHalf, pz - this.hz * G.bodyHalf, hx, hz, G.pounceWidth * 0.5, pl.pos.x, pl.pos.z, T.player.radius)) {
            const r = pl.takeHit(G.pounceDmg, this.pos.x - this.hx * 2, this.pos.z - this.hz * 2, 'pounce');
            if (r !== 'miss') { this.pounceHit = true; if (r !== 'block' && r !== 'break') this.stats.pounceHits++; }
          }
        }
        if (u >= 1) {
          this.y = 0;
          this.go('land');
          this.setAnim('land', true, G.land * this.tm);
          env.fx('dust', this.pos.x, this.pos.z, { scale: 1.4 });
          env.shake(...F.shakePounce);
        }
        break;
      }
      case 'land': {
        if (this.t >= G.land * this.tm) this.toProwl(0.6);
        break;
      }
      case 'swipeWind': {
        if (this.t >= G.swipeWind * this.tm * (this.swipeChain ? 0.75 : 1)) {
          this.go('swipe'); this.swipeHit = false;
          this.stats.swipes++;
          env.fx('slash', this.pos.x, this.pos.z, { dir: { x: this.hx, z: this.hz }, radius: G.swipeR * 0.9, arc: G.swipeArc, height: 0.6, tiger: true });
        }
        break;
      }
      case 'swipe': {
        if (!this.swipeHit && this.t <= G.swipeActive && pl.alive) {
          if (fanHit(this.pos.x, this.pos.z, this.hx, this.hz, G.swipeR, G.swipeArc, pl.pos.x, pl.pos.z, T.player.radius)) {
            const r = pl.takeHit(G.swipeDmg, this.pos.x, this.pos.z, 'swipe');
            if (r !== 'miss') { this.swipeHit = true; if (r !== 'block' && r !== 'break') this.stats.swipeHits++; else this.stats.blocks++; }
          }
        }
        if (this.t >= G.swipeActive + G.swipeRecover * this.tm) {
          if (this.enraged && !this.swipeChain && tp.d < G.swipeR + 0.5 && b.rand() < G.doubleSwipe) {
            this.swipeChain = 1; this.startSwipe(tp, true);
          } else { this.swipeChain = 0; if (b.rand() < G.backoffAfterSwipe) this.startBackoff(); else this.toProwl(0.8); }
        }
        break;
      }
      case 'roar': {
        if (!this.roarBlast && this.t >= G.roarWind) {
          this.roarBlast = true;
          env.fx('roar', this.pos.x, this.pos.z, { radius: G.roarR });
          env.shake(...F.shakeRoar);
          if (tp.d <= G.roarR && pl.alive) pl.stun(G.roarStun);
          this.enraged = true; this.fury = G.furyTime;
          env.say('포효! 호랑이의 움직임이 빨라졌다.', 2000);
        }
        if (this.t >= G.roarWind + G.roarAfter) this.toProwl(0.4);
        break;
      }
      case 'backoff': {
        const u = this.t / G.backoffTime;
        const sp = (G.backoffDist / G.backoffTime) * 1.5 * Math.max(0, 1 - u);
        this.moveIn(this.bx * sp * dt, this.bz * sp * dt, lim);
        this.setHeading(tp.vx, tp.vz);
        this.setAnim('prowl');
        if (u >= 1) this.toProwl(1.0);
        break;
      }
      case 'hit': {
        if (this.t >= G.flinch) this.afterReact(tp);
        break;
      }
      case 'stagger': {
        if (this.t >= this.stunFor) this.afterReact(tp);
        break;
      }
      case 'toBait': {
        const bt = this.bait;
        if (!bt || bt.gone) { this.bait = null; this.toProwl(); break; }
        const vx = bt.x - this.pos.x, vz = bt.z - this.pos.z, d = Math.hypot(vx, vz);
        // 떡 앞에 머리가 오도록 몸 중심을 조금 뒤에 세운다
        if (d <= G.bodyHalf + 0.35 || this.t > 6) { this.startEat(); break; }
        const sp = G.baitSpeed;
        this.moveIn(vx / d * sp * dt, vz / d * sp * dt, b.arena.radius + 1);
        this.turnTo(vx, vz, dt * 2);
        this.setAnim('walk');
        break;
      }
      case 'eat': {
        this.setAnim('eat');
        this.eatLeft -= dt;
        if (this.eatLeft <= 0) {
          if (this.bait) { this.b.consumeBait(this.bait); this.bait = null; }
          if (this.disturbed) { this.disturbed = false; this.setHeading(tp.vx, tp.vz); this.startSwipe(tp); }
          else this.toProwl(0.8);
        }
        break;
      }
      case 'territory': {
        if (this.t >= 1.2) { this.go('home'); }
        if (!b.playerOutside && this.t >= 0.6) this.toProwl(0.8);
        break;
      }
      case 'home': {
        if (!b.playerOutside) { this.toProwl(0.8); break; }
        const vx = b.arena.x - this.pos.x, vz = b.arena.z - this.pos.z, d = Math.hypot(vx, vz);
        if (d > 1) { this.moveIn(vx / d * 2 * dt, vz / d * 2 * dt, lim); this.turnTo(vx, vz, dt); this.setAnim('walk'); }
        else { this.setHeading(tp.vx, tp.vz); this.setAnim('idle'); }
        break;
      }
      case 'retreat': {
        if (this.t < G.retreatPause) { this.setAnim('stagger'); break; }
        const sp = G.retreatSpeed;
        this.moveIn(this.retreatDir.x * sp * dt, this.retreatDir.z * sp * dt, 0);
        this.turnTo(this.retreatDir.x, this.retreatDir.z, dt);
        this.setAnim('walk');
        const a = b.arena;
        if (Math.hypot(this.pos.x - a.x, this.pos.z - a.z) > a.radius + 2 || this.t > 9) {
          this.go('gone');
          b.finish('repelled');
        }
        break;
      }
      case 'retreatStagger': {
        if (this.t >= G.retreatStagger) { this.state = 'retreat'; this.t = G.retreatPause; }
        break;
      }
      case 'gone': case 'dead': break;
    }

    // 몸끼리 겹치지 않게: 플레이어를 호랑이 몸통(선분) 밖으로 민다
    if (this.state !== 'pounce' && this.state !== 'gone' && this.state !== 'dead' && pl.alive) {
      closestOnSeg(this.pos.x - this.hx * G.bodyHalf, this.pos.z - this.hz * G.bodyHalf,
        this.pos.x + this.hx * G.bodyHalf, this.pos.z + this.hz * G.bodyHalf, pl.pos.x, pl.pos.z, _c);
      const dx = pl.pos.x - _c.x, dz = pl.pos.z - _c.z, d = Math.hypot(dx, dz), min = G.bodyR + T.player.radius;
      if (d < min) {
        const k = (min - d) / (d || 1);
        if (!pl.move(dx * k || 0.01, dz * k)) { /* 막히면 그대로 */ }
      }
    }
  }

  // 배회 중 다음 행동 고르기
  choose(tp) {
    const b = this.b, r = b.rand();
    this.decide = (G.decideMin + b.rand() * (G.decideMax - G.decideMin)) * (this.enraged ? G.enrageDecide : 1);
    if (tp.d <= G.swipeRange) { if (r < 0.45) this.startSwipe(tp); else this.startBackoff(); return; }
    if (tp.d >= G.pounceMin && tp.d <= G.pounceMax && r < G.pounceChance) { this.startCrouch(tp); return; }
    if (r < 0.8) { this.go('stalk'); return; }
    this.orbit *= -1;
    this.orbitR = G.prowlMin + b.rand() * (G.prowlMax - G.prowlMin);
  }

  toProwl(decide = 1.2) {
    this.go('prowl');
    this.decide = decide * (this.enraged ? G.enrageDecide : 1) + this.b.rand() * 0.6;
    this.orbitR = G.prowlMin + this.b.rand() * (G.prowlMax - G.prowlMin);
    if (this.b.rand() < 0.35) this.orbit *= -1;
  }

  // 뒤로 훌쩍 물러나 거리를 벌린다
  startBackoff() {
    const tp = this.toPlayer();
    this.go('backoff');
    this.bx = -tp.vx; this.bz = -tp.vz;
    // 영역 끝이면 옆으로
    const a = this.b.arena;
    const ex = this.pos.x + this.bx * 2 - a.x, ez = this.pos.z + this.bz * 2 - a.z;
    if (Math.hypot(ex, ez) > a.radius - 1) { const o = this.orbit; this.bx = -tp.vz * o; this.bz = tp.vx * o; }
    this.setAnim('prowl', true);
  }

  startCrouch(tp) {
    const env = this.b.env;
    this.go('crouch');
    this.setHeading(tp.vx, tp.vz);
    this.setAnim('crouch', true);
    this.stats.pounces++;
    if (env.options.telegraph) {
      this.teleH = env.fx('lane', this.pos.x, this.pos.z, { dir: { x: this.hx, z: this.hz }, length: G.pounceLen + G.bodyHalf, width: G.pounceWidth, duration: G.crouch * this.tm });
      this.say('crouch', '호랑이가 몸을 낮춘다…', 1100);
    }
  }

  startPounce() {
    const b = this.b, a = b.arena;
    this.go('pounce');
    this.pounceHit = false;
    this.ps.x = this.pos.x; this.ps.z = this.pos.z;
    // 도약 경로: 장애물·영역 끝(+1m)에서 멈춘다
    let len = 0;
    const step = 0.25;
    while (len < G.pounceLen) {
      const nx = this.pos.x + this.hx * (len + step), nz = this.pos.z + this.hz * (len + step);
      if (b.env.blocked(nx, nz, G.radius)) break;
      if (Math.hypot(nx - a.x, nz - a.z) > a.radius + 1) break;
      len += step;
    }
    this.pe.x = this.pos.x + this.hx * len; this.pe.z = this.pos.z + this.hz * len;
    this.setAnim('pounce', true, (G.pounceTime / this.sm) / G.pounceAirFrac);
    b.env.fx('dust', this.pos.x, this.pos.z, { scale: 0.9 });
  }

  startSwipe(tp, chain = false) {
    const env = this.b.env;
    this.go('swipeWind');
    this.setHeading(tp.vx, tp.vz);
    // 앞발 치기 애니메이션의 '내려치는 순간'(swipeStrikeFrac)이 예고 끝과 맞도록 속도를 맞춘다
    this.setAnim('swipe', true, (G.swipeWind * this.tm * (chain ? 0.75 : 1)) / G.swipeStrikeFrac);
    if (env.options.telegraph) {
      this.teleH = env.fx('fan', this.pos.x, this.pos.z, { dir: { x: this.hx, z: this.hz }, radius: G.swipeR, arc: G.swipeArc, duration: G.swipeWind * this.tm * (chain ? 0.75 : 1) });
      if (!chain) this.say('swipe', '호랑이가 앞발을 든다!', 900);
    }
  }

  startRoar() {
    this.go('roar');
    this.roared = true; this.roarBlast = false;
    this.stats.roar = true;
    const tp = this.toPlayer();
    this.setHeading(tp.vx, tp.vz);
    this.setAnim('roar', true, G.roarWind + G.roarAfter);
    this.b.env.say('호랑이가 크게 숨을 들이쉰다…', 1300);
  }

  startEat() {
    this.go('eat');
    this.eatLeft = G.eat;
    this.disturbed = false;
    if (this.bait) this.setHeading(this.bait.x - this.pos.x, this.bait.z - this.pos.z);
    this.setAnim('eat', true);
    this.stats.baits++;
    this.b.env.say('호랑이가 떡에 정신이 팔렸다. 뒤로 돌아가 기습하자!', 2200);
  }

  // 땅에 떨어진 떡이 있으면 먹으러 간다(분노 중이 아닐 때)
  tryBait() {
    if (this.fury > 0 || this.b.playerOutside) return false;
    const a = this.b.arena;
    for (const bt of this.b.baits) {
      if (!bt.landed || bt.gone || bt.claimed) continue;
      if (Math.hypot(bt.x - a.x, bt.z - a.z) > a.radius + 0.5) continue;
      bt.claimed = true;
      this.bait = bt;
      this.go('toBait');
      this.say('bait', '호랑이가 떡 냄새를 맡았다.', 1400);
      return true;
    }
    return false;
  }

  afterReact(tp) {
    if (this.b.playerOutside) { this.go('home'); return; }
    // 맞은 뒤: 가까우면 반격, 아니면 거리 벌리기
    const r = this.b.rand();
    if (tp.d <= G.swipeRange && r < 0.5) this.startSwipe(tp);
    else if (tp.d <= G.swipeRange + 1 && r < 0.8) this.startBackoff();
    else this.toProwl(0.6);
  }

  // 플레이어가 보는 방향 기준 뒤쪽에서 맞았는가
  isBehind(fromX, fromZ) {
    const vx = fromX - this.pos.x, vz = fromZ - this.pos.z, d = Math.hypot(vx, vz) || 1;
    return (vx * this.hx + vz * this.hz) / d < -0.2;
  }

  // 피격. opts: { heavy, kind:'melee'|'arrow', fromX, fromZ, combo3 }
  receiveHit(dmg, opts) {
    const b = this.b, env = b.env;
    if (!this.targetable) return 0;
    let back = false;
    if (this.state === 'eat' && opts.kind === 'melee' && this.isBehind(opts.fromX, opts.fromZ)) {
      back = true; dmg *= G.backAttackMul; this.stats.backHits++;
    }
    this.hp -= dmg;
    const src = back ? 'back' : opts.kind === 'arrow' ? 'arrow' : opts.heavy ? 'heavy' : 'light';
    this.stats.dmg[src] = (this.stats.dmg[src] || 0) + dmg;
    this.stats.hitState[this.state] = (this.stats.hitState[this.state] || 0) + 1;
    env.flash('tiger', back ? '#ffe0a0' : '#ffffff', 120);
    const hx = this.pos.x, hz = this.pos.z;
    if (back) {
      env.fx('heavyHit', hx, hz, {});
      env.hitStop(F.hitStopBack);
      env.shake(...F.shakeHeavy);
      if (this.stats.backHits === 1 || this.stats.backHits % 3 === 0) env.say('기습! 피해 두 배', 1000);
    } else {
      env.fx(opts.heavy ? 'heavyHit' : 'hit', hx, hz, {});
      if (opts.kind === 'melee') {
        env.hitStop(opts.heavy ? F.hitStopHeavy : opts.combo3 ? F.hitStopCombo3 : F.hitStopLight);
        env.shake(...(opts.heavy ? F.shakeHeavy : F.shakeLight));
      }
    }

    if (this.hp <= 0) {
      this.hp = 0;
      this.go('dead');
      this.y = 0;
      this.setAnim('dead', true);
      env.shake(...F.shakeHeavy);
      b.finish('win', G.deathDelay);
      return dmg;
    }
    if (this.state === 'retreat' || this.state === 'retreatStagger') {
      if (opts.heavy) { this.state = 'retreatStagger'; this.t = 0; this.setAnim('stagger', true); }
      return dmg;
    }
    if (this.hp <= G.hp * G.retreatAt) { this.startRetreat(); return dmg; }
    if (!this.roared && this.hp <= G.hp * G.roarAt) this.pendingRoar = true;

    const tp = this.toPlayer();
    const s = this.state;
    if (s === 'eat') {
      if (back) {
        if (!this.disturbed) { this.disturbed = true; this.eatLeft = Math.min(this.eatLeft, G.eatAfterHit); }
      } else {
        // 앞에서 치면 떡을 삼키고 곧바로 반격
        if (this.bait) { this.b.consumeBait(this.bait); this.bait = null; }
        this.startSwipe(tp);
      }
      return dmg;
    }
    if (s === 'roar' || s === 'territory') return dmg;

    this.poise -= dmg; this.poiseWait = G.poiseRegenDelay;
    if (opts.heavy && s !== 'swipe') {
      // 강공격: 예고 동작까지 끊고 경직
      this.go('stagger'); this.stunFor = G.stagger; this.setAnim('stagger', true, G.stagger); this.poise = G.poise;
      return dmg;
    }
    if (this.poise <= 0 && (INTERRUPTIBLE.has(s) || s === 'land' || s === 'toBait' || s === 'hit')) {
      this.go('hit'); this.setAnim('hit', true, G.flinch); this.poise = G.poise;
      return dmg;
    }
    if (INTERRUPTIBLE.has(s)) {
      if (opts.kind === 'melee' && tp.d <= G.swipeRange + 0.3 && b.rand() < G.counterChance) this.startSwipe(tp);
      else this.decide = Math.min(this.decide, 0.5);
    }
    if (s === 'toBait' && opts.kind === 'melee') {
      if (this.bait) { this.bait.claimed = false; this.bait = null; }
      this.startSwipe(tp);
    }
    return dmg;
  }

  startRetreat() {
    const b = this.b, a = b.arena, pl = b.player;
    this.go('retreat');
    this.pendingRoar = false;
    if (this.bait) { this.bait.claimed = false; this.bait = null; }
    this.setAnim('stagger', true);
    // 플레이어 반대쪽, 산(북쪽 -z)으로 치우쳐 물러난다
    let vx = this.pos.x - pl.pos.x, vz = this.pos.z - pl.pos.z;
    const l = Math.hypot(vx, vz) || 1;
    vx = vx / l; vz = vz / l - 0.8;
    const l2 = Math.hypot(vx, vz) || 1;
    this.retreatDir.x = vx / l2; this.retreatDir.z = vz / l2;
    void a;
    b.env.say('호랑이가 비틀거리며 물러난다… 몰아붙이면 쓰러뜨릴 수도 있다.', 2600);
  }
}
