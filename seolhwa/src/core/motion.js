// 충돌·높이 처리. 원형 캐릭터 vs 원/상자 충돌체, 가파른 경사는 오를 수 없음
const MAX_SLOPE = 1.1; // 수평 1m당 오를 수 있는 높이

export function blocked(world, x, z, r, ignore) {
  for (const c of world.colliders) {
    if (c === ignore) continue;
    if (c.type === 'circle') {
      const dx = x - c.x, dz = z - c.z, rr = r + c.r;
      if (dx * dx + dz * dz < rr * rr) return true;
    } else if (c.type === 'box') {
      const nx = Math.max(c.minX, Math.min(x, c.maxX));
      const nz = Math.max(c.minZ, Math.min(z, c.maxZ));
      const dx = x - nx, dz = z - nz;
      if (dx * dx + dz * dz < r * r) return true;
    }
  }
  return false;
}

function stepOk(world, fx, fz, tx, tz, r, extra) {
  if (blocked(world, tx, tz, r)) return false;
  if (extra && extra(tx, tz)) return false;
  const dist = Math.hypot(tx - fx, tz - fz) || 1e-6;
  const rise = world.heightAt(tx, tz) - world.heightAt(fx, fz);
  return rise / dist <= MAX_SLOPE;
}

// 이동 시도: 막히면 축별로 미끄러지듯 이동. 반환값: 실제 이동했는지
export function moveCircle(world, pos, dx, dz, r, extra) {
  const tx = pos.x + dx, tz = pos.z + dz;
  if (stepOk(world, pos.x, pos.z, tx, tz, r, extra)) { pos.x = tx; pos.z = tz; return true; }
  if (dx && stepOk(world, pos.x, pos.z, tx, pos.z, r, extra)) { pos.x = tx; return true; }
  if (dz && stepOk(world, pos.x, pos.z, pos.x, tz, r, extra)) { pos.z = tz; return true; }
  return false;
}

export function facingFrom(dx, dz, prev) {
  if (!dx && !dz) return prev;
  if (Math.abs(dx) > Math.abs(dz) * 1.15) return dx > 0 ? 'right' : 'left';
  return dz > 0 ? 'down' : 'up';
}

export function inBox(b, x, z) {
  return x >= b.minX && x <= b.maxX && z >= b.minZ && z <= b.maxZ;
}
