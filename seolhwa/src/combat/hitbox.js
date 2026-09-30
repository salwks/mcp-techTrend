// xz 평면 판정 도구: 원·부채꼴·선분(캡슐). three.js 없이 순수 수학만 쓴다.
export const DEG = Math.PI / 180;

export function dist(ax, az, bx, bz) { return Math.hypot(bx - ax, bz - az); }

// 두 원이 겹치는가
export function circleHit(ax, az, ar, bx, bz, br) {
  const dx = bx - ax, dz = bz - az, rr = ar + br;
  return dx * dx + dz * dz < rr * rr;
}

// 부채꼴(원점 o, 방향 (dx,dz) 단위벡터, 반지름 r, 전체 각 arcDeg) vs 원(px,pz,pr)
export function fanHit(ox, oz, dx, dz, r, arcDeg, px, pz, pr) {
  const vx = px - ox, vz = pz - oz;
  const d = Math.hypot(vx, vz);
  if (d > r + pr) return false;
  if (d <= pr) return true; // 원점이 원 안
  const cos = (vx * dx + vz * dz) / d;
  const ang = Math.acos(Math.max(-1, Math.min(1, cos)));
  const pad = Math.asin(Math.min(1, pr / d)); // 원의 두께만큼 각을 넓힌다
  return ang <= arcDeg * DEG * 0.5 + pad;
}

// 점과 선분 사이 거리²
export function segDist2(ax, az, bx, bz, px, pz) {
  const ex = bx - ax, ez = bz - az;
  const l2 = ex * ex + ez * ez;
  let t = l2 > 1e-9 ? ((px - ax) * ex + (pz - az) * ez) / l2 : 0;
  t = t < 0 ? 0 : t > 1 ? 1 : t;
  const qx = ax + ex * t - px, qz = az + ez * t - pz;
  return qx * qx + qz * qz;
}

// 선분(두께 halfWidth) vs 원
export function segmentHit(ax, az, bx, bz, halfWidth, px, pz, pr) {
  const rr = halfWidth + pr;
  return segDist2(ax, az, bx, bz, px, pz) < rr * rr;
}

// 선분 위에서 점에 가장 가까운 점 (out에 기록)
export function closestOnSeg(ax, az, bx, bz, px, pz, out) {
  const ex = bx - ax, ez = bz - az;
  const l2 = ex * ex + ez * ez;
  let t = l2 > 1e-9 ? ((px - ax) * ex + (pz - az) * ez) / l2 : 0;
  t = t < 0 ? 0 : t > 1 ? 1 : t;
  out.x = ax + ex * t; out.z = az + ez * t;
  return out;
}

// 두 단위벡터 사이 각(도)
export function angleBetween(ax, az, bx, bz) {
  const c = ax * bx + az * bz;
  return Math.acos(Math.max(-1, Math.min(1, c))) / DEG;
}

// 방향 벡터를 최대 maxRad만큼 target 쪽으로 돌린다 (단위벡터 반환 out)
export function turnToward(hx, hz, tx, tz, maxRad, out) {
  const a = Math.atan2(hz, hx), b = Math.atan2(tz, tx);
  let d = b - a;
  while (d > Math.PI) d -= Math.PI * 2;
  while (d < -Math.PI) d += Math.PI * 2;
  const s = Math.max(-maxRad, Math.min(maxRad, d));
  out.x = Math.cos(a + s); out.z = Math.sin(a + s);
  return out;
}

// 8방향 이동 → 4방향 스프라이트 (motion.facingFrom과 같은 규칙)
export function facing4(dx, dz, prev, sideBias = 1.15) {
  if (!dx && !dz) return prev;
  if (Math.abs(dx) > Math.abs(dz) * sideBias) return dx > 0 ? 'right' : 'left';
  return dz > 0 ? 'down' : 'up';
}

// 결정적 난수 (시뮬레이션 재현용)
export function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a = (a + 0x6D2B79F5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// 충돌·경사를 고려한 이동 (motion.moveCircle과 같은 방식, env.blocked/heightAt 사용)
const MAX_SLOPE = 1.1;
function stepOk(env, fx, fz, tx, tz, r) {
  if (env.blocked(tx, tz, r)) return false;
  const d = Math.hypot(tx - fx, tz - fz) || 1e-6;
  return (env.heightAt(tx, tz) - env.heightAt(fx, fz)) / d <= MAX_SLOPE;
}
export function moveBody(env, pos, dx, dz, r) {
  if (!dx && !dz) return false;
  // 이미 충돌체에 겹쳐 있으면(시작 위치 등) 빠져나오는 이동은 허용
  if (env.blocked(pos.x, pos.z, r) && !env.blocked(pos.x + dx * 4, pos.z + dz * 4, r * 0.5)) { pos.x += dx; pos.z += dz; return true; }
  const tx = pos.x + dx, tz = pos.z + dz;
  if (stepOk(env, pos.x, pos.z, tx, tz, r)) { pos.x = tx; pos.z = tz; return true; }
  if (dx && stepOk(env, pos.x, pos.z, tx, pos.z, r)) { pos.x = tx; return true; }
  if (dz && stepOk(env, pos.x, pos.z, pos.x, tz, r)) { pos.z = tz; return true; }
  return false;
}

// (x,z) 근처에서 막히지 않은 가장 가까운 자리
export function nearestFree(env, x, z, r, out = { x, z }) {
  for (let rad = 0; rad < 6; rad += 0.35) {
    const n = rad === 0 ? 1 : Math.ceil(rad * 8);
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2;
      const px = x + Math.cos(a) * rad, pz = z + Math.sin(a) * rad;
      if (!env.blocked(px, pz, r)) { out.x = px; out.z = pz; return out; }
    }
  }
  out.x = x; out.z = z;
  return out;
}
