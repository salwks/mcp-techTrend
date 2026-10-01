// 지형: 높이장(격자) + heightAt(렌더 면과 같은 삼각형 보간) + 지형 메시·개울·논물·원경 산
import * as THREE from 'three';
import { clamp, lerp, smoothstep, fbm, vnoise, rng } from './util.js';
import { terrainMaterial } from './materials.js';
import { MILL, YARD, PATH, BRANCH, ARENA, ARENA_TRAIL, PASS, HOUSE, BRIDGE, PADDIES, LANES, WATER_Y, streamZ } from './layout.js';

export const GRID = { x0: -60, x1: 60, z0: -90, z1: 44, s: 1.0 };

// ---- 형상(길·터) ----
function segShapes(pts, r0, r1) {
  const out = [];
  for (let i = 0; i < pts.length - 1; i++) {
    const [ax, az, ah] = pts[i], [bx, bz, bh] = pts[i + 1];
    out.push({ t: 'seg', ax, az, ah, bx, bz, bh, r0, r1 });
  }
  return out;
}
const SHAPES = [
  ...segShapes(PATH, 1.7, 5.5),
  ...segShapes(BRANCH, 1.6, 5),
  ...segShapes(ARENA_TRAIL, 1.5, 5),
  { t: 'circ', x: ARENA.x, z: ARENA.z, r: ARENA.r - 0.5, h: ARENA.h, r1: ARENA.r + 5, wob: 0.3 },
  { t: 'circ', x: PASS.x, z: PASS.z, r: PASS.r, h: PASS.h, r1: 12 },
  { t: 'rect', minX: HOUSE.x - 4.6, maxX: HOUSE.x + 4.6, minZ: HOUSE.z - 3.8, maxZ: HOUSE.z + 3.6, h: HOUSE.pad, r0: 0, r1: 5 },
  ...PADDIES.map((p) => ({ t: 'rect', ...p, r0: 0, r1: 0.55 })),
  { t: 'rect', minX: YARD.x - 5, maxX: YARD.x + 5.5, minZ: -28.6, maxZ: -22.2, h: YARD.pad, r0: 0, r1: 3.5 },
  { t: 'rect', minX: MILL.x - 3.4, maxX: MILL.x + 3, minZ: MILL.z - 2.4, maxZ: MILL.z + 1.9, h: MILL.pad, r0: 0, r1: 3 },
];

function segInfo(s, x, z) {
  const dx = s.bx - s.ax, dz = s.bz - s.az;
  const l2 = dx * dx + dz * dz;
  const t = clamp(((x - s.ax) * dx + (z - s.az) * dz) / l2, 0, 1);
  const px = s.ax + dx * t, pz = s.az + dz * t;
  return { d: Math.hypot(x - px, z - pz), h: lerp(s.ah, s.bh, t) };
}
function rectDist(r, x, z) {
  const dx = Math.max(r.minX - x, 0, x - r.maxX), dz = Math.max(r.minZ - z, 0, z - r.maxZ);
  return Math.hypot(dx, dz);
}

// 길 중심선까지 거리(색칠·나무 배치용)
export function pathDist(x, z) {
  let d = 1e9;
  for (const s of SHAPES) if (s.t === 'seg') d = Math.min(d, segInfo(s, x, z).d);
  return d;
}
export function inPaddy(x, z, m = 0) {
  return PADDIES.find((p) => x > p.minX - m && x < p.maxX + m && z > p.minZ - m && z < p.maxZ + m) || null;
}
export function laneMask(x, z) {
  let k = 0;
  for (const l of LANES) k = Math.max(k, 1 - smoothstep(0, 0.9, rectDist(l, x, z)));
  return k;
}

// 자연 지형
function hNat(x, z) {
  let h = fbm(x * 0.07, z * 0.07) * 0.14;
  const t = Math.max(0, (-19 - z) / 51);
  h += 14 * Math.pow(t, 1.15);
  h += fbm(x * 0.06 + 10, z * 0.06 - 4, 4) * 2.4 * smoothstep(0, 0.3, t);
  // 좌우 산자락(마을을 감싸고, 산에서는 더 높게)
  const cx = z < -40 ? 8 * Math.min(1, (-40 - z) / 30) : 0;
  const side = smoothstep(25, 47, Math.abs(x - cx));
  h += side * side * (11 + 18 * Math.min(t, 1.3)) * (0.8 + 0.5 * fbm(x * 0.05, z * 0.05 + 7, 3));
  // 고갯마루: 좌우로 봉우리가 솟은 안부
  const sad = smoothstep(-56, -68, z);
  h += sad * Math.pow(Math.max(0, Math.abs(x - 8) - 7), 1.5) * 0.3;
  // 고개 너머는 골짜기로 내려간다(원경이 보이도록)
  const beyond = smoothstep(-73, -86, z);
  h -= beyond * 9 * (1 - smoothstep(10, 30, Math.abs(x - 8)));
  // 남쪽 가장자리 낮은 언덕
  h += smoothstep(31, 44, z) * 2.2 * (0.7 + 0.6 * vnoise(x * 0.1, 3));
  return h;
}

function hRaw(x, z) {
  let h = hNat(x, z);
  let keep = 1, num = 0, den = 0;
  for (const s of SHAPES) {
    let d, hp, r0, r1;
    if (s.t === 'seg') { const i = segInfo(s, x, z); d = i.d; hp = i.h; r0 = s.r0; r1 = s.r1; }
    else if (s.t === 'circ') { d = Math.hypot(x - s.x, z - s.z); hp = s.h + (s.wob ? s.wob * vnoise(x * 0.18, z * 0.18) : 0); r0 = s.r; r1 = s.r1; }
    else { d = rectDist(s, x, z); hp = s.h; r0 = s.r0; r1 = s.r1; }
    if (d >= r1) continue;
    const k = 1 - smoothstep(r0, r1, d);
    keep *= 1 - k; num += hp * k; den += k;
  }
  if (den > 0) h = lerp(h, num / den, 1 - keep);
  // 개울 파기
  const dz = Math.abs(z - streamZ(x));
  const sk = 1 - smoothstep(1.9, 4.3, dz);
  h = lerp(h, -1.45 + 0.15 * vnoise(x * 0.4, 1), sk);
  return h;
}

// ---- 높이 격자 ----
export function buildHeights() {
  const { x0, x1, z0, z1, s } = GRID;
  const nx = Math.round((x1 - x0) / s) + 1, nz = Math.round((z1 - z0) / s) + 1;
  const H = new Float32Array(nx * nz);
  for (let j = 0; j < nz; j++) for (let i = 0; i < nx; i++) H[j * nx + i] = hRaw(x0 + i * s, z0 + j * s);
  function ground(x, z) {
    let fx = (clamp(x, x0, x1 - 1e-4) - x0) / s, fz = (clamp(z, z0, z1 - 1e-4) - z0) / s;
    const i = Math.floor(fx), j = Math.floor(fz);
    fx -= i; fz -= j;
    const a = H[j * nx + i], b = H[j * nx + i + 1], c = H[(j + 1) * nx + i], d = H[(j + 1) * nx + i + 1];
    // 삼각형 (a,c,b) / (b,c,d) — 메시와 같은 대각선
    if (fx + fz <= 1) return a + (b - a) * fx + (c - a) * fz;
    return d + (c - d) * (1 - fx) + (b - d) * (1 - fz);
  }
  return { H, nx, nz, ground };
}

export function bridgeDeck(z) {
  const t = (z - (BRIDGE.z0 + BRIDGE.z1) / 2) / ((BRIDGE.z1 - BRIDGE.z0) / 2);
  return 0.1 + 0.55 * (1 - t * t);
}

// 걸을 수 있는 높이(다리 상판, 외딴집 마루 포함)
export function makeHeightAt(ground) {
  const hx0 = HOUSE.x - HOUSE.w / 2, hx1 = HOUSE.x + HOUSE.w / 2;
  const hz0 = HOUSE.z - HOUSE.d / 2, hz1 = HOUSE.z + HOUSE.d / 2;
  const floor = HOUSE.pad + HOUSE.F;
  return function heightAt(x, z) {
    const ax = Math.abs(x - BRIDGE.x);
    if (ax <= BRIDGE.hw + 0.3 && z >= BRIDGE.z0 && z <= BRIDGE.z1) {
      const g = ground(x, z);
      // 끝단 0.9m와 가장자리 0.3m는 지면과 이어지도록 섞는다(계단 없이 오르내림)
      const e = Math.min(z - BRIDGE.z0, BRIDGE.z1 - z);
      const k = smoothstep(0, 0.9, e) * (1 - smoothstep(BRIDGE.hw, BRIDGE.hw + 0.3, ax));
      return lerp(g, Math.max(bridgeDeck(z), g), k);
    }
    if (x >= hx0 && x <= hx1 && z >= hz0 && z <= hz1) return floor;
    if (x >= HOUSE.x - 1.1 && x <= HOUSE.x + 1.1 && z > hz1 && z < hz1 + 1.3) {
      return lerp(floor, ground(x, z), (z - hz1) / 1.3);
    }
    return ground(x, z);
  };
}

// ---- 지형 메시 ----
const C = (h) => new THREE.Color(h);
const COL = {
  grass: C('#9da66b'), grass2: C('#86985c'), dry: C('#b5ab76'),
  forest: C('#6e7a4e'), forest2: C('#56633f'),
  lane: C('#c9ab78'), path: C('#b69a68'),
  rock: C('#8e8676'), cliff: C('#6a655b'),
  bank: C('#a89d84'), bed: C('#5d5f53'), paddy: C('#7c6a4b'),
  high: C('#8d937c'),
};
export function buildTerrainMesh(hg) {
  const { x0, z0, s } = GRID;
  const { H, nx, nz } = hg;
  const pos = new Float32Array(nx * nz * 3), col = new Float32Array(nx * nz * 3), uv = new Float32Array(nx * nz * 2);
  const c = new THREE.Color(), t2 = new THREE.Color();
  for (let j = 0; j < nz; j++) for (let i = 0; i < nx; i++) {
    const k = j * nx + i, x = x0 + i * s, z = z0 + j * s, h = H[k];
    pos[k * 3] = x; pos[k * 3 + 1] = h; pos[k * 3 + 2] = z;
    uv[k * 2] = x / 7; uv[k * 2 + 1] = z / 7;
    const hl = H[j * nx + Math.max(0, i - 1)], hr = H[j * nx + Math.min(nx - 1, i + 1)];
    const hd = H[Math.max(0, j - 1) * nx + i], hu = H[Math.min(nz - 1, j + 1) * nx + i];
    const slope = Math.hypot(hr - hl, hu - hd) / (2 * s);
    const n1 = fbm(x * 0.15, z * 0.15, 3), n2 = vnoise(x * 0.6, z * 0.6);
    const mtn = smoothstep(-18, -26, z) + smoothstep(24, 34, Math.abs(x)) * 0.8;
    // 바탕: 들판 ↔ 산
    c.copy(COL.grass).lerp(COL.grass2, clamp(0.5 + n1, 0, 1));
    c.lerp(COL.dry, clamp(n2 * 0.4, 0, 0.35));
    t2.copy(COL.forest).lerp(COL.forest2, clamp(0.5 + n1 * 1.2, 0, 1));
    c.lerp(t2, clamp(mtn, 0, 1));
    // 붓질 같은 얼룩
    const br = fbm(x * 0.35 + z * 0.12, z * 0.5, 2);
    c.lerp(COL.forest2, clamp(br - 0.15, 0, 0.3) * (0.4 + mtn));
    c.lerp(COL.dry, clamp(-br - 0.2, 0, 0.25));
    // 높은 곳은 조금 차갑고 옅게(대기원근)
    c.lerp(COL.high, smoothstep(10, 30, h) * 0.5);
    // 길
    const pd = pathDist(x, z);
    c.lerp(COL.path, (1 - smoothstep(1.0, 2.2, pd + n2 * 0.4)) * 0.85);
    c.lerp(COL.lane, laneMask(x + n2 * 0.5, z - n2 * 0.4) * 0.7 * (0.8 + n2 * 0.2));
    // 경사 → 흙·바위·절벽
    c.lerp(COL.path, smoothstep(0.3, 0.6, slope) * 0.3);
    c.lerp(COL.rock, smoothstep(0.55, 1.0, slope) * 0.8);
    c.lerp(COL.cliff, smoothstep(1.1, 1.9, slope) * 0.9);
    // 개울 둑과 바닥
    const dzs = Math.abs(z - streamZ(x));
    c.lerp(COL.bank, 1 - smoothstep(3.2, 4.8, dzs));
    c.lerp(COL.bed, 1 - smoothstep(1.6, 2.8, dzs));
    if (inPaddy(x, z, -0.3)) c.lerp(COL.paddy, 0.9);
    // 호랑이의 영역: 짓밟혀 마른 풀밭
    const da = Math.hypot(x - ARENA.x, z - ARENA.z);
    c.lerp(COL.dry, (1 - smoothstep(ARENA.r - 3, ARENA.r + 1, da)) * clamp(0.45 + n2 * 0.3, 0, 0.7));
    col[k * 3] = c.r; col[k * 3 + 1] = c.g; col[k * 3 + 2] = c.b;
  }
  const idx = [];
  for (let j = 0; j < nz - 1; j++) for (let i = 0; i < nx - 1; i++) {
    const a = j * nx + i, b = a + 1, cc = a + nx, d = cc + 1;
    idx.push(a, cc, b, b, cc, d);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  g.setAttribute('color', new THREE.BufferAttribute(col, 3));
  g.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
  g.setIndex(idx);
  g.computeVertexNormals();
  const m = new THREE.Mesh(g, terrainMaterial());
  m.receiveShadow = true;
  m.name = 'terrain';
  return m;
}

// ---- 개울 물 ----
export function buildStream(tex) {
  const x0 = -62, x1 = 62, n = 124, w = 3.4;
  const pos = [], uv = [], idx = [];
  for (let i = 0; i <= n; i++) {
    const x = x0 + (x1 - x0) * i / n, zc = streamZ(x);
    for (let k = 0; k < 2; k++) {
      pos.push(x, WATER_Y, zc + (k ? w : -w));
      uv.push(x / 7, k);
    }
    if (i < n) { const a = i * 2; idx.push(a, a + 1, a + 2, a + 2, a + 1, a + 3); }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  g.setIndex(idx);
  g.computeVertexNormals();
  const t = tex.clone();
  t.needsUpdate = true;
  t.repeat.set(1, 1);
  const mat = new THREE.MeshStandardMaterial({ map: t, color: 0xb4cac8, roughness: 0.25, metalness: 0.0, transparent: true, opacity: 0.88 });
  const m = new THREE.Mesh(g, mat);
  m.receiveShadow = true;
  m.name = 'stream';
  return { mesh: m, tex: t };
}

// ---- 원경: 산수화처럼 겹친 능선 ----
export function buildBackdrop() {
  const grp = new THREE.Group();
  grp.name = 'backdrop';
  const layers = [
    { z: -96, base: 7, amp: 9, top: '#46534b', bot: '#a9ae9a', seed: 1, f: 0.045 },
    { z: -125, base: 1, amp: 12, top: '#5f6b63', bot: '#c3c4b0', seed: 2, f: 0.035 },
    { z: -165, base: -6, amp: 16, top: '#7c847e', bot: '#d5d2c0', seed: 3, f: 0.026 },
    { z: -220, base: -14, amp: 24, top: '#9da19a', bot: '#e0dccc', seed: 4, f: 0.018 },
  ];
  const RP = [], RC = [], RI = [];
  for (const L of layers) {
    const ct = new THREE.Color(L.top), cb = new THREE.Color(L.bot), cm = new THREE.Color(L.bot).lerp(ct, 0.35);
    const n = 150, xa = -220, xb = 240, base = RP.length / 3;
    for (let i = 0; i <= n; i++) {
      const x = xa + (xb - xa) * i / n;
      // 둥글고 뾰족한 봉우리(진경산수)
      let r = fbm(x * L.f + L.seed * 13, L.seed * 3.1, 4);
      r = Math.pow(clamp(0.5 + r, 0, 1.2), 1.6);
      const peak = Math.pow(Math.abs(Math.sin(x * L.f * 1.7 + L.seed)), 6);
      const top = L.base + L.amp * (r + peak * 0.45);
      const zz = L.z + Math.sin(x * 0.05 + L.seed) * 6;
      // 능선 바로 아래 짙은 먹 → 중턱 옅어짐 → 산발치 안개
      RP.push(x, top, zz, x, top - L.amp * 0.35 - 3, zz + 2, x, -12, zz + 8);
      const ink = 0.85 + 0.3 * vnoise(x * 0.3, L.seed);
      RC.push(ct.r * ink, ct.g * ink, ct.b * ink, cm.r, cm.g, cm.b, cb.r, cb.g, cb.b);
      if (i < n) {
        const a0 = base + i * 3;
        RI.push(a0, a0 + 1, a0 + 3, a0 + 3, a0 + 1, a0 + 4, a0 + 1, a0 + 2, a0 + 4, a0 + 4, a0 + 2, a0 + 5);
      }
    }
  }
  {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(RP, 3));
    g.setAttribute('color', new THREE.Float32BufferAttribute(RC, 3));
    g.setIndex(RI);
    const m = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ vertexColors: true, fog: true, side: THREE.DoubleSide }));
    m.name = 'ridges';
    grp.add(m);
  }
  // 능선 사이·골짜기 안개띠(한 메시)
  const cc = document.createElement('canvas'); cc.width = 256; cc.height = 64;
  const x = cc.getContext('2d');
  const r = rng(99);
  for (let i = 0; i < 16; i++) {
    const gx = 30 + r() * 196, gy = 32 + (r() - 0.5) * 12, rad = 14 + r() * 20;
    const gr = x.createRadialGradient(gx, gy, 0, gx, gy, rad);
    gr.addColorStop(0, 'rgba(246,242,230,0.32)'); gr.addColorStop(1, 'rgba(246,242,230,0)');
    x.fillStyle = gr; x.fillRect(0, 0, 256, 64);
  }
  const ct = new THREE.CanvasTexture(cc); ct.colorSpace = THREE.SRGBColorSpace;
  const MP = [], MU = [], MI = [];
  for (const [cx, y, z, w, hh] of [[10, 4, -110, 260, 12], [10, -1, -145, 300, 16], [10, -6, -192, 360, 20], [8, 8, -88, 50, 7], [-46, 10, -45, 30, 6], [50, 9, -30, 30, 6], [-50, 6, 5, 30, 5]]) {
    const b0 = MP.length / 3;
    MP.push(cx - w / 2, y - hh / 2, z, cx + w / 2, y - hh / 2, z, cx - w / 2, y + hh / 2, z, cx + w / 2, y + hh / 2, z);
    MU.push(0, 0, 1, 0, 0, 1, 1, 1);
    MI.push(b0, b0 + 1, b0 + 2, b0 + 2, b0 + 1, b0 + 3);
  }
  const mg = new THREE.BufferGeometry();
  mg.setAttribute('position', new THREE.Float32BufferAttribute(MP, 3));
  mg.setAttribute('uv', new THREE.Float32BufferAttribute(MU, 2));
  mg.setIndex(MI);
  const mm = new THREE.Mesh(mg, new THREE.MeshBasicMaterial({ map: ct, transparent: true, depthWrite: false, fog: true }));
  mm.name = 'mist-bands';
  grp.add(mm);
  return grp;
}
