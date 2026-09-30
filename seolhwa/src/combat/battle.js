// 전투 한 판의 논리(플레이어·호랑이·화살·떡·결말). DOM·three 없이 돌아가므로 노드 시뮬레이션에서도 쓴다.
import { T } from './tuning.js';
import { fanHit, mulberry32, nearestFree } from './hitbox.js';
import { PlayerCombat } from './player.js';
import { TigerAI } from './tiger.js';
import { makeArrow, updateArrow, makeBait, updateBait } from './projectiles.js';

const noop = () => {};
const xz = (p, x, z) => (p ? [p.x, p.z] : [x, z]);
export function makeEnv(partial = {}) {
  return {
    heightAt: () => 0,
    blocked: () => false,
    anim: noop, face: noop, flash: noop,
    fx: () => null, fxRemove: noop,
    say: noop, hitStop: noop, shake: noop,
    spawnProj: noop, removeProj: noop,
    options: { telegraph: true, ranges: false, aimAssist: true, hitStop: true },
    rand: Math.random,
    ...partial,
  };
}

export class Battle {
  constructor(env) {
    this.env = env;
    this.player = new PlayerCombat(this);
    this.tiger = new TigerAI(this);
    this.arrows = [];
    this.baits = [];
    this.arena = { x: 0, z: 0, radius: 11 };
    this.outcome = null;      // 확정된 결말(지연 후)
    this.pending = null; this.pendingT = 0;
    this.time = 0;
    this.outsideT = 0;
    this.playerOutside = false;
    this.stats = { arrowHits: 0, hits: 0, damage: 0 };
  }

  get rand() { return this.env.rand; }

  start(arena, seed) {
    if (seed !== undefined) this.env.rand = mulberry32(seed);
    this.clearProjectiles();
    this.arena = arena;
    // 시작 자리가 바위 등에 겹치면 가까운 빈자리로 옮긴다
    const ps = nearestFree(this.env, ...xz(arena.playerStart, arena.x, arena.z + arena.radius * 0.5), T.player.radius, {});
    const ts = nearestFree(this.env, ...xz(arena.tigerStart, arena.x, arena.z - arena.radius * 0.4), T.tiger.radius + 0.1, {});
    this.player.reset(ps.x, ps.z);
    this.tiger.reset(ts.x, ts.z);
    // 서로 마주보게
    const vx = ts.x - ps.x, vz = ts.z - ps.z, l = Math.hypot(vx, vz) || 1;
    this.player.fx = vx / l; this.player.fz = vz / l;
    this.player.dir = ''; this.player.face(this.player.fx, this.player.fz);
    this.tiger.dir = ''; this.tiger.setHeading(-vx, -vz);
    this.player.setAnim('idle', true);
    this.tiger.setAnim('prowl', true);
    this.tiger.decide = 2.0;
    this.outcome = null; this.pending = null; this.pendingT = 0;
    this.time = 0; this.outsideT = 0; this.playerOutside = false;
    this.stats = { arrowHits: 0, hits: 0, damage: 0 };
  }

  clearProjectiles() {
    for (const a of this.arrows) this.env.removeProj(a);
    for (const b of this.baits) this.env.removeProj(b);
    this.arrows.length = 0;
    this.baits.length = 0;
  }

  // 결말 예약(죽는 동작 등을 보여준 뒤 확정)
  finish(kind, delay = 0.6) {
    if (this.pending || this.outcome) return;
    this.pending = kind; this.pendingT = delay;
  }

  update(dt, ctl) {
    if (this.outcome) return;
    this.time += dt;
    const pl = this.player, tg = this.tiger, a = this.arena;

    pl.update(dt, ctl);

    // 영역 판정
    const pd = Math.hypot(pl.pos.x - a.x, pl.pos.z - a.z);
    this.playerOutside = pd > a.radius + T.tiger.leash && tg.state !== 'retreat' && tg.alive;
    if (this.playerOutside && !this.pending) {
      this.outsideT += dt;
      if (this.outsideT >= T.tiger.escapeTime || pd > a.radius + T.tiger.escapeFar) this.finish('escaped', 0.2);
    } else this.outsideT = 0;

    tg.update(dt);

    for (let i = this.arrows.length - 1; i >= 0; i--) {
      if (!updateArrow(this.arrows[i], dt, this)) { this.env.removeProj(this.arrows[i]); this.arrows.splice(i, 1); }
    }
    for (let i = this.baits.length - 1; i >= 0; i--) {
      if (!updateBait(this.baits[i], dt, this)) { this.env.removeProj(this.baits[i]); this.baits.splice(i, 1); }
    }

    if (!pl.alive) this.finish('lose', 1.6);
    if (this.pending) {
      this.pendingT -= dt;
      if (this.pendingT <= 0) this.outcome = this.pending;
    }
  }

  // 플레이어 근접 공격 판정
  playerStrike(pl, spec, dx, dz, heavy) {
    const env = this.env, tg = this.tiger;
    env.fx('slash', pl.pos.x, pl.pos.z, { dir: { x: dx, z: dz }, radius: spec.r, arc: spec.arc, heavy, flip: spec.anim === 'attack2' });
    if (!tg.targetable) return false;
    const bh = T.tiger.bodyHalf, br = T.tiger.bodyR;
    let hit = false;
    for (let i = -1; i <= 1 && !hit; i++) {
      hit = fanHit(pl.pos.x, pl.pos.z, dx, dz, spec.r, spec.arc, tg.pos.x + tg.hx * bh * i, tg.pos.z + tg.hz * bh * i, br);
    }
    if (!hit) return false;
    const dealt = tg.receiveHit(spec.dmg, { kind: 'melee', heavy, combo3: spec === T.player.combo[2], fromX: pl.pos.x, fromZ: pl.pos.z });
    this.stats.hits++; this.stats.damage += dealt;
    return true;
  }

  spawnArrow(x, z, dx, dz, dmg, full) {
    const a = makeArrow(x, z, dx, dz, dmg, full);
    this.arrows.push(a);
    this.env.spawnProj(a);
  }

  throwBait(x, z, dx, dz, dist, flight) {
    const b = makeBait(x, z, dx, dz, dist, flight, this.env);
    this.baits.push(b);
    this.env.spawnProj(b);
  }

  consumeBait(b) { b.gone = true; }
}
