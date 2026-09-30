// 화살·떡 (논리만). 메시는 env.spawnProj/removeProj를 통해 index.js(meshes.js)가 붙인다.
import { T } from './tuning.js';
import { segmentHit } from './hitbox.js';

const G = T.tiger;

export function makeArrow(x, z, dx, dz, dmg, full) {
  return {
    kind: 'arrow', x: x + dx * 0.5, z: z + dz * 0.5, px: x, pz: z, y: 1.15,
    dx, dz, speed: T.player.bow.speed, travelled: 0, dmg, full,
    stuck: false, stuckT: 0, gone: false, view: null,
  };
}

// 반환: 계속 살아있는지
export function updateArrow(a, dt, battle) {
  if (a.stuck) {
    a.stuckT += dt;
    return a.stuckT < 2.5;
  }
  const step = a.speed * dt;
  a.px = a.x; a.pz = a.z;
  a.x += a.dx * step; a.z += a.dz * step;
  a.travelled += step;
  // 멀리 갈수록 살짝 떨어진다
  a.y = 1.15 - Math.max(0, a.travelled - T.player.bow.range * 0.6) * 0.12;
  const tg = battle.tiger;
  if (tg.targetable) {
    const bh = G.bodyHalf;
    const ax = tg.pos.x - tg.hx * bh, az = tg.pos.z - tg.hz * bh, bx = tg.pos.x + tg.hx * bh, bz = tg.pos.z + tg.hz * bh;
    // 화살 경로(선분) vs 호랑이 몸통(선분): 몸통 위 몇 점을 원으로 검사
    for (let i = 0; i <= 4; i++) {
      const u = i / 4, cx = ax + (bx - ax) * u, cz = az + (bz - az) * u;
      if (segmentHit(a.px, a.pz, a.x, a.z, 0.05, cx, cz, G.bodyR + 0.1)) {
        tg.receiveHit(a.dmg, { kind: 'arrow', fromX: a.px, fromZ: a.pz });
        battle.env.fx('hit', cx, cz, { scale: 0.6, dir: { x: a.dx, z: a.dz } });
        battle.stats.arrowHits++;
        return false;
      }
    }
  }
  if (battle.env.blocked(a.x, a.z, 0.05) || a.y <= 0.05 || a.travelled >= T.player.bow.range) {
    a.stuck = true;
    a.y = Math.max(0.15, a.y);
    return true;
  }
  return true;
}

export function makeBait(x, z, dx, dz, distance, flight, env) {
  // 가는 길에 막히면 그 앞에 떨어진다
  let d = 0;
  while (d < distance) {
    const nx = x + dx * (d + 0.25), nz = z + dz * (d + 0.25);
    if (env.blocked(nx, nz, 0.15)) break;
    d += 0.25;
  }
  return {
    kind: 'bait', sx: x + dx * 0.3, sz: z + dz * 0.3, tx: x + dx * d, tz: z + dz * d,
    x: x + dx * 0.3, z: z + dz * 0.3, y: 1.1, t: 0, flight,
    landed: false, claimed: false, gone: false, view: null,
  };
}

export function updateBait(bt, dt, battle) {
  if (bt.landed) return !bt.gone;
  bt.t += dt;
  const u = Math.min(1, bt.t / bt.flight);
  bt.x = bt.sx + (bt.tx - bt.sx) * u;
  bt.z = bt.sz + (bt.tz - bt.sz) * u;
  bt.y = 1.1 * (1 - u) + Math.sin(Math.PI * u) * 1.4 + 0.08;
  if (u >= 1) {
    bt.landed = true; bt.y = 0.08;
    battle.env.fx('dust', bt.x, bt.z, { scale: 0.35 });
  }
  return true;
}
