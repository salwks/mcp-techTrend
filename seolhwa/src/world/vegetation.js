// 식생과 바위: 민화식 소나무(휘어진 붉은 줄기 + 납작한 우산 솔잎 뭉치), 덤불, 진달래, 바위(피마준), 갈대, 벼
import * as THREE from 'three';
import { paint, xf, limb, lump } from './util.js';

const PINE_LEAF = [['#7d9160', '#34432f'], ['#708a5a', '#2f3e2c'], ['#8a9866', '#3d4c35']];

// 솔잎 뭉치: 납작한 타원체(윗면 밝고 아랫면 짙은 바림) + 위에 작은 덩이
function needleClump(add, rnd, cx, cy, cz, r, col, lod, s) {
  const g = new THREE.SphereGeometry(r, lod ? 6 : 8, 3);
  xf(g, cx, cy, cz, (rnd() - 0.5) * 0.12, rnd() * 3, (rnd() - 0.5) * 0.12, 1, 0.34, 0.78);
  add('leaf', 'needle', paint(g, col[0], col[1], 0.03, rnd), lod ? 0 : 0.045 * s);
  if (!lod && r > 1.2 * s) {
    const g2 = new THREE.SphereGeometry(r * 0.6, 6, 2);
    xf(g2, cx + (rnd() - 0.5) * r * 0.4, cy + r * 0.22, cz, 0, rnd() * 3, 0, 1, 0.34, 0.8);
    add('leaf', 'needle', paint(g2, col[0], col[0], 0.03, rnd), 0.035 * s);
  }
}

// 한국 소나무(적송)
export function pine(add, rnd, s = 1, lod = 0) {
  const h = (4.5 + rnd() * 3) * s;
  const pts = [new THREE.Vector3(0, -0.3, 0)];
  let x = 0, z = 0;
  const lean = (rnd() - 0.5) * 1.4 * s;
  for (let i = 1; i <= 4; i++) {
    x += lean * 0.3 + (rnd() - 0.5) * 0.7 * s; z += (rnd() - 0.5) * 0.35 * s;
    pts.push(new THREE.Vector3(x, (h * i) / 4, z));
  }
  for (let i = 0; i < 4; i++) {
    add('trunk', 'bark', paint(limb(pts[i], pts[i + 1], (0.24 - i * 0.045) * s, (0.2 - i * 0.045) * s, lod ? 5 : 6), '#b8744c', '#7a4e38', 0.04, rnd), lod ? 0 : 0.02 * s);
  }
  const col = PINE_LEAF[Math.floor(rnd() * PINE_LEAF.length)];
  const top = pts[4];
  const clumps = [[top.x, top.y + 0.15 * s, top.z, 1.55 * s]];
  const nb = lod ? 1 + Math.floor(rnd() * 2) : 2 + Math.floor(rnd() * 2);
  for (let i = 0; i < nb; i++) {
    const t = 0.5 + rnd() * 0.35;
    const bi = Math.min(3, Math.floor(t * 4));
    const from = pts[bi].clone().lerp(pts[bi + 1], t * 4 - bi);
    const a = rnd() * Math.PI * 2;
    const L = (1.3 + rnd() * 1.1) * s;
    const tip = new THREE.Vector3(from.x + Math.cos(a) * L, from.y + 0.35 * s, from.z + Math.sin(a) * L * 0.6);
    if (!lod) add('trunk', 'bark', paint(limb(from, tip, 0.07 * s, 0.04 * s, 4), '#9a6244', '#7a4e38'), 0);
    clumps.push([tip.x, tip.y + 0.1 * s, tip.z, (0.95 + rnd() * 0.5) * s]);
  }
  for (const [cx, cy, cz, r] of clumps) needleClump(add, rnd, cx, cy, cz, r, col, lod, s);
  return { h, r: 0.3 * s };
}

// 곧게 선 소나무(층층 뭉치) — 숲 밀도용 변종
export function fir(add, rnd, s = 1, lod = 0) {
  const h = (5.5 + rnd() * 2.5) * s;
  add('trunk', 'bark', paint(limb(new THREE.Vector3(0, -0.3, 0), new THREE.Vector3((rnd() - 0.5) * 0.4, h * 0.85, 0), 0.2 * s, 0.1 * s, 5), '#a8694a', '#7a4e38'), lod ? 0 : 0.018 * s);
  const col = PINE_LEAF[Math.floor(rnd() * PINE_LEAF.length)];
  const tiers = 2 + Math.floor(rnd() * 2);
  for (let i = 0; i < tiers; i++) {
    const r = (1.5 - i * 0.3) * s * (0.8 + rnd() * 0.4);
    const side = (i % 2 ? 1 : -1) * (0.3 + rnd() * 0.5) * s;
    needleClump(add, rnd, side, h * (0.5 + i * 0.22), (rnd() - 0.5) * 0.4 * s, r, col, 1, s);
  }
  return { h, r: 0.25 * s };
}

export function bush(add, rnd, s = 1, flowers = false) {
  const col = flowers ? ['#8f9a60', '#55603c'] : [['#8e9a60', '#55603c'], ['#9aa06a', '#626b42'], ['#7d8c58', '#4a5638']][Math.floor(rnd() * 3)];
  const n = 1 + Math.floor(rnd() * 2);
  for (let i = 0; i < n; i++) {
    const g = new THREE.SphereGeometry((0.5 + rnd() * 0.3) * s, 7, 3);
    xf(g, (rnd() - 0.5) * 0.8 * s, 0.22 * s, (rnd() - 0.5) * 0.5 * s, 0, rnd() * 3, 0, 1, 0.62, 0.85);
    add('p', 'leaf', paint(g, col[0], col[1], 0.04, rnd), 0.025);
  }
  // 진달래 꽃송이 점
  if (flowers) for (let i = 0; i < 5; i++) {
    const g = new THREE.SphereGeometry(0.09 * s, 5, 3);
    xf(g, (rnd() - 0.5) * 0.9 * s, (0.35 + rnd() * 0.2) * s, (rnd() - 0.5) * 0.6 * s);
    add('p', 'organic', paint(g, '#e79ab2', '#c97890'), 0);
  }
}

export function rock(add, rnd, s = 1, mossy = true) {
  const g = lump(s, s > 1.2 ? 1 : 0, rnd, 0.3, 0.6 + rnd() * 0.25);
  xf(g, 0, s * 0.15, 0, 0, rnd() * 6, 0);
  add('p', 'rock', paint(g, mossy && rnd() < 0.5 ? '#a4a58c' : '#aba699', '#5f5b53', 0.05, rnd), 0.022 + s * 0.01);
}

export function reeds(add, rnd, n = 7) {
  for (let i = 0; i < n; i++) {
    const h = 0.8 + rnd() * 0.7;
    const px = (rnd() - 0.5) * 0.8, pz = (rnd() - 0.5) * 0.5, tx = (rnd() - 0.5) * 0.3, tz = (rnd() - 0.5) * 0.3;
    const g = new THREE.ConeGeometry(0.03, h, 3);
    xf(g, px, h / 2, pz, tx, 0, tz);
    add('p', 'flat', paint(g, '#b9a878', '#6f7448', 0.06, rnd), 0);
    if (i % 2 === 0) {
      const f = new THREE.ConeGeometry(0.05, 0.22, 4);
      xf(f, px + tz * h * 0.9, h + 0.05, pz - tx * h * 0.9, Math.PI, 0, 0);
      add('p', 'flat', paint(f, '#e2d6b4', '#c8b88e'), 0);
    }
  }
}

// 들꽃 몇 송이(바닥에 흩어진 점)
export function flowers(add, rnd, color) {
  for (let i = 0; i < 4; i++) {
    const g = new THREE.SphereGeometry(0.06, 4, 2);
    xf(g, (rnd() - 0.5) * 0.7, 0.18 + rnd() * 0.1, (rnd() - 0.5) * 0.5);
    add('p', 'organic', paint(g, color, color), 0);
  }
}

// 벼 포기
export function riceTuft(add, rnd, x, y, z) {
  const g = new THREE.ConeGeometry(0.13, 0.5 + rnd() * 0.12, 4, 1, true);
  xf(g, x, y + 0.25, z, 0, rnd() * 2, 0);
  add('p', 'flat', paint(g, '#cdbd62', '#6f7f3e', 0.05, rnd), 0);
}
