// 플레이어와 NPC 이동·배회·대화 대상 찾기
import { moveCircle, facingFrom } from './motion.js';

const WALK = 2.2;
const RUN = 4.6;

export class Actor {
  constructor(char, world, x, z, opts = {}) {
    this.char = char;
    this.world = world;
    this.pos = { x, z, y: world.heightAt(x, z) };
    this.facing = opts.facing || 'down';
    this.home = { x, z };
    this.wander = opts.wander || 0;
    this.data = opts.data || null;
    this.goal = null;
    this.wait = 1 + Math.random() * 3;
    this.talking = false;
    char.setFacing(this.facing);
    char.setAnim('idle');
    this.sync();
  }

  sync() {
    this.pos.y = this.world.heightAt(this.pos.x, this.pos.z);
    this.char.object3d.position.set(this.pos.x, this.pos.y, this.pos.z);
  }

  face(dir) {
    if (dir && dir !== this.facing) { this.facing = dir; this.char.setFacing(dir); }
  }

  faceToward(x, z) {
    this.face(facingFrom(x - this.pos.x, z - this.pos.z, this.facing));
  }

  // 반환: 이동했는지
  step(dt, vx, vz, speed, others) {
    if (!vx && !vz) return false;
    const r = this.char.radius;
    const extra = (tx, tz) => others.some((o) => o !== this && Math.hypot(o.pos.x - tx, o.pos.z - tz) < r + o.char.radius - 0.05
      && Math.hypot(o.pos.x - tx, o.pos.z - tz) < Math.hypot(o.pos.x - this.pos.x, o.pos.z - this.pos.z));
    const moved = moveCircle(this.world, this.pos, vx * speed * dt, vz * speed * dt, r, extra);
    this.face(facingFrom(vx, vz, this.facing));
    this.sync();
    return moved;
  }

  updateWander(dt, others) {
    if (!this.wander || this.talking) { this.char.setAnim(this.talking ? 'talk' : 'idle'); return; }
    if (!this.goal) {
      this.wait -= dt;
      this.char.setAnim('idle');
      if (this.wait <= 0) {
        const a = Math.random() * Math.PI * 2, d = Math.random() * this.wander;
        this.goal = { x: this.home.x + Math.cos(a) * d, z: this.home.z + Math.sin(a) * d, t: 6 };
      }
      return;
    }
    const dx = this.goal.x - this.pos.x, dz = this.goal.z - this.pos.z;
    const len = Math.hypot(dx, dz);
    this.goal.t -= dt;
    if (len < 0.15 || this.goal.t <= 0) { this.goal = null; this.wait = 2 + Math.random() * 4; return; }
    const moved = this.step(dt, dx / len, dz / len, 1.1, others);
    if (!moved) { this.goal = null; this.wait = 1 + Math.random() * 2; }
    this.char.setAnim(moved ? 'walk' : 'idle');
  }
}

export function playerSpeed(running) { return running ? RUN : WALK; }

// 플레이어 앞의 대화 가능한 NPC
export function findTalkTarget(player, npcs) {
  let best = null, bestD = 2.2;
  const dir = { down: [0, 1], up: [0, -1], left: [-1, 0], right: [1, 0] }[player.facing];
  for (const n of npcs) {
    if (!n.data || !n.data.lines || !n.data.lines.length) continue;
    const dx = n.pos.x - player.pos.x, dz = n.pos.z - player.pos.z;
    const d = Math.hypot(dx, dz);
    const front = (dx * dir[0] + dz * dir[1]) / (d || 1);
    if (d < bestD && (front > 0.2 || d < 1.1)) { best = n; bestD = d; }
  }
  return best;
}
