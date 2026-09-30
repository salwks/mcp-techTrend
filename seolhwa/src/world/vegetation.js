// 식생과 바위: 층층이 우산 모양 소나무(적송), 원뿔 전나무, 덤불, 바위, 갈대, 벼
import * as THREE from 'three';
import { paint, xf, limb, lump, hash2 } from './util.js';
const hash01 = (x, z) => hash2(Math.round(x * 50), Math.round(z * 50));

const PINE_LEAF = [['#7f9160', '#3f4c37'], ['#748a5a', '#394632'], ['#8a9866', '#46553c']];

// 한국 소나무: 휘어진 붉은 줄기 + 납작한 잎뭉치 여러 층
export function pine(add, rnd, s = 1, lod = 0) {
  const h = (4.5 + rnd() * 3) * s;
  const pts = [new THREE.Vector3(0, -0.3, 0)];
  let x = 0, z = 0;
  for (let i = 1; i <= 3; i++) {
    x += (rnd() - 0.5) * 0.9 * s; z += (rnd() - 0.5) * 0.4 * s;
    pts.push(new THREE.Vector3(x, (h * i) / 3, z));
  }
  for (let i = 0; i < 3; i++) {
    add('trunk', 'flat', paint(limb(pts[i], pts[i + 1], (0.22 - i * 0.05) * s, (0.17 - i * 0.05) * s, lod ? 5 : 6), '#a0603f', '#6b4a36', 0.05, rnd), lod ? 0 : 0.025 * s);
  }
  const col = PINE_LEAF[Math.floor(rnd() * PINE_LEAF.length)];
  const top = pts[3];
  const clumps = [[top.x, top.y + 0.2 * s, top.z, 1.5 * s]];
  const nb = lod ? 1 + Math.floor(rnd() * 2) : 2 + Math.floor(rnd() * 2);
  for (let i = 0; i < nb; i++) {
    const t = 0.45 + rnd() * 0.4;
    const bi = Math.min(2, Math.floor(t * 3));
    const from = pts[bi].clone().lerp(pts[bi + 1], t * 3 - bi);
    const a = rnd() * Math.PI * 2;
    const L = (1.2 + rnd() * 1.1) * s;
    const tip = new THREE.Vector3(from.x + Math.cos(a) * L, from.y + 0.4 * s, from.z + Math.sin(a) * L * 0.6);
    add('trunk', 'flat', paint(limb(from, tip, 0.07 * s, 0.04 * s, 4), '#8a5a3e', '#6b4a36'), 0);
    clumps.push([tip.x, tip.y + 0.1 * s, tip.z, (0.9 + rnd() * 0.5) * s]);
  }
  for (const [cx, cy, cz, r] of clumps) {
    // 납작한 솔잎 구름(민화식 층층 우산): 윗면이 밝고 아랫면이 어두운 원반
    const g = new THREE.CylinderGeometry(r * 0.62, r * 1.05, r * 0.34, lod ? 6 : 8, 1);
    const pos = g.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      const k = 1 + (hash01(pos.getX(i), pos.getZ(i)) - 0.5) * 0.3;
      pos.setXYZ(i, pos.getX(i) * k, pos.getY(i), pos.getZ(i) * k);
    }
    xf(g, cx, cy, cz, (rnd() - 0.5) * 0.15, rnd() * 3, (rnd() - 0.5) * 0.15, 1, 1, 0.8);
    add('leaf', 'flat', paint(g, col[0], col[1], 0.05, rnd), 0.05 * s);
    if (!lod && r > 1.3 * s) {
      const g2 = new THREE.CylinderGeometry(r * 0.55, r * 0.8, r * 0.3, 7, 1);
      xf(g2, cx + (rnd() - 0.5) * 0.3, cy + r * 0.3, cz, 0, rnd() * 3, 0, 1, 1, 0.8);
      add('leaf', 'flat', paint(g2, col[0], col[0], 0.04, rnd), 0.04 * s);
    }
  }
  return { h, r: 0.3 * s };
}

// 원뿔 전나무(뒷산 밀도용)
export function fir(add, rnd, s = 1, lod = 0) {
  const h = (5 + rnd() * 3) * s;
  add('trunk', 'flat', paint(limb(new THREE.Vector3(0, -0.3, 0), new THREE.Vector3(0, h * 0.4, 0), 0.18 * s, 0.12 * s, 5), '#7a5a42', '#5a4232'), lod ? 0 : 0.02 * s);
  const col = PINE_LEAF[Math.floor(rnd() * PINE_LEAF.length)];
  for (let i = 0; i < 3; i++) {
    const r = (1.5 - i * 0.38) * s, hh = (2.2 - i * 0.35) * s;
    const g = new THREE.ConeGeometry(r, hh, lod ? 5 : 7, 1, true);
    xf(g, 0, h * 0.3 + i * h * 0.22 + hh / 2, 0, 0, rnd() * 3, 0);
    add('leaf', 'flat', paint(g, col[0], col[1], 0.05, rnd), 0.05 * s);
  }
  return { h, r: 0.25 * s };
}

export function bush(add, rnd, s = 1) {
  const col = [['#8e9a60', '#55603c'], ['#9aa06a', '#626b42'], ['#7d8c58', '#4a5638']][Math.floor(rnd() * 3)];
  const n = 1 + Math.floor(rnd() * 2);
  for (let i = 0; i < n; i++) {
    const g = lump((0.5 + rnd() * 0.35) * s, 0, rnd, 0.3, 0.7);
    xf(g, (rnd() - 0.5) * 0.9 * s, 0.25 * s, (rnd() - 0.5) * 0.6 * s);
    add('p', 'flat', paint(g, col[0], col[1], 0.06, rnd), 0.03);
  }
}

export function rock(add, rnd, s = 1, mossy = true) {
  const g = lump(s, s > 1.3 ? 1 : 0, rnd, 0.3, 0.62 + rnd() * 0.25);
  xf(g, 0, s * 0.15, 0, 0, rnd() * 6, 0);
  add('p', 'flat', paint(g, mossy && rnd() < 0.5 ? '#9b9d82' : '#aaa496', '#6c685f', 0.08, rnd), 0.03 + s * 0.012);
}

export function reeds(add, rnd, n = 7) {
  for (let i = 0; i < n; i++) {
    const h = 0.8 + rnd() * 0.7;
    const g = new THREE.ConeGeometry(0.03, h, 3);
    xf(g, (rnd() - 0.5) * 0.8, h / 2, (rnd() - 0.5) * 0.5, (rnd() - 0.5) * 0.3, 0, (rnd() - 0.5) * 0.3);
    add('p', 'flat', paint(g, '#b9a878', '#6f7448', 0.06, rnd), 0);
  }
}

// 벼 포기 한 줄
export function riceTuft(add, rnd, x, y, z) {
  const g = new THREE.ConeGeometry(0.13, 0.5 + rnd() * 0.12, 4, 1, true);
  xf(g, x, y + 0.25, z, 0, rnd() * 2, 0);
  add('p', 'flat', paint(g, '#c7b75e', '#6f7f3e', 0.05, rnd), 0);
}
