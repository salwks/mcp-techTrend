// 건물과 소품 조립 함수. 모든 함수는 add(part, key, geo, outline) 콜백에 로컬 좌표 지오메트리를 넘긴다.
// 정면은 +z(카메라 쪽).
import * as THREE from 'three';
import { paint, xf, box, cyl, limb, lump, smoothstep, clamp, prep } from './util.js';

const WOOD = ['#6b5038', '#4d3826'];
const WOOD_L = ['#9a7852', '#7a5c3e'];
const MUD = ['#d2b98c', '#a88c62'];
const STONE = ['#a19b8f', '#77726a'];
const PLASTER = ['#ece4cf', '#d8ccb0'];
const DANCHEONG_R = ['#8a3e2e', '#6a2e22'];

// ---------- 곡선 기와지붕(처마 끝이 들린 팔작/우진각 느낌) ----------
export function curvedRoof({ hw, hd, eaveY, rise, lift, k = 1.8, thick = 0.22, nx = 36, nz = 20 }) {
  const H = (x, z) => {
    const ex = (hw - Math.abs(x)) * k, ez = hd - Math.abs(z);
    const e = Math.max(0, Math.min(ex, ez));
    const s = Math.min(1, e / hd);
    let y = eaveY + rise * (0.25 * s + 0.75 * s * s);
    const lx = Math.abs(x) / hw, lz = Math.abs(z) / hd;
    y += lift * Math.max(lx ** 3 * smoothstep(0.5, 1, lz), lz ** 3 * smoothstep(0.5, 1, lx));
    return y;
  };
  const isSide = (x, z) => (hw - Math.abs(x)) * k < hd - Math.abs(z);
  const P = [], U = [], Cc = [];
  const cTop = new THREE.Color('#d9d9d4'), cLow = new THREE.Color('#b9b8b2'), cBot = new THREE.Color('#3b2f26');
  const tmp = new THREE.Color();
  const X = (i) => -hw + (2 * hw * i) / nx, Z = (j) => -hd + (2 * hd * j) / nz;
  // 한 칸 = 기와 한 골: 칸마다 u 0..1(골 가로), v 0..1(기와 줄)
  function cell(x0, x1, z0, z1) {
    const side = isSide((x0 + x1) / 2, (z0 + z1) / 2);
    const pt = (x, z) => [x, H(x, z), z, side ? (z - z0) / (z1 - z0) : (x - x0) / (x1 - x0), side ? (x - x0) / (x1 - x0) : (z - z0) / (z1 - z0)];
    const a = pt(x0, z0), b = pt(x1, z0), c = pt(x0, z1), d = pt(x1, z1);
    for (const p of [a, c, b, b, c, d]) {
      P.push(p[0], p[1], p[2]); U.push(p[3], p[4]);
      tmp.copy(cLow).lerp(cTop, clamp((p[1] - eaveY) / rise, 0, 1));
      Cc.push(tmp.r, tmp.g, tmp.b);
    }
    for (const p of [a, b, c, b, d, c]) { P.push(p[0], p[1] - thick, p[2]); U.push(0.5, 0.5); Cc.push(cBot.r, cBot.g, cBot.b); }
  }
  for (let j = 0; j < nz; j++) for (let i = 0; i < nx; i++) cell(X(i), X(i + 1), Z(j), Z(j + 1));
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(P, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(U, 2));
  g.setAttribute('color', new THREE.Float32BufferAttribute(Cc, 3));
  g.computeVertexNormals();
  // 처마 끝 두께 띠 = 막새 줄(칸마다 둥근 막새 하나)
  const EP = [], EU = [], EC = [];
  const edge = [];
  for (let i = 0; i < nx; i++) { edge.push([X(i), -hd, X(i + 1), -hd]); edge.push([X(i + 1), hd, X(i), hd]); }
  for (let j = 0; j < nz; j++) { edge.push([-hw, Z(j + 1), -hw, Z(j)]); edge.push([hw, Z(j), hw, Z(j + 1)]); }
  for (const [xa, za, xb, zb] of edge) {
    const ya = H(xa, za), yb = H(xb, zb);
    const p1 = [xa, ya, za, 0, 1], p2 = [xb, yb, zb, 1, 1], p3 = [xa, ya - thick, za, 0, 0], p4 = [xb, yb - thick, zb, 1, 0];
    for (const p of [p1, p3, p2, p2, p3, p4]) { EP.push(p[0], p[1], p[2]); EU.push(p[3], p[4]); EC.push(1, 1, 1); }
  }
  const eg = new THREE.BufferGeometry();
  eg.setAttribute('position', new THREE.Float32BufferAttribute(EP, 3));
  eg.setAttribute('uv', new THREE.Float32BufferAttribute(EU, 2));
  eg.setAttribute('color', new THREE.Float32BufferAttribute(EC, 3));
  eg.computeVertexNormals();
  g.userData.edge = eg;
  g.userData.ridgeY = eaveY + rise;
  g.userData.ridgeHalf = Math.max(0, hw - hd / k);
  return g;
}

// 용마루 + 치켜든 끝
function ridgeCap(add, part, half, y, w = 0.36) {
  add(part, 'flat', paint(box(half * 2, 0.3, w, 0, y + 0.08, 0), '#3d3f42', '#2d2e30', 0.02), 0.03);
  for (const s of [-1, 1]) {
    add(part, 'flat', paint(xf(new THREE.BoxGeometry(0.5, 0.26, w * 0.9), s * (half + 0.12), y + 0.22, 0, 0, 0, s * 0.55), '#3d3f42', '#2d2e30', 0.02), 0.03);
  }
}

// 벽에 구멍 뚫기: x0..x1 구간, 구멍 hx0..hx1 / hy0..hy1, 두께 t, z 위치
function holedWall(add, part, x0, x1, y0, y1, hx0, hx1, hy0, hy1, z, t, col, key = 'mud') {
  const pieces = [];
  if (hx0 > x0) pieces.push([x0, hx0, y0, y1]);
  if (x1 > hx1) pieces.push([hx1, x1, y0, y1]);
  if (hy0 > y0) pieces.push([hx0, hx1, y0, hy0]);
  if (y1 > hy1) pieces.push([hx0, hx1, hy1, y1]);
  for (const [a, b, c, d] of pieces) add(part, key, paint(box(b - a, d - c, t, (a + b) / 2, (c + d) / 2, z), col[0], col[1], 0.03), 0.02);
}
// 창호(한지 창살) + 문틀
function paperPanel(add, part, cx, cy, w, h, z, frame = true) {
  const g = new THREE.PlaneGeometry(w, h);
  add(part, 'paper', xf(g, cx, cy, z), 0);
  if (!frame) return;
  const f = 0.07;
  add(part, 'wood', paint(box(w + f * 2, f, 0.12, cx, cy + h / 2 + f / 2, z), ...WOOD), 0.012);
  add(part, 'wood', paint(box(w + f * 2, f, 0.12, cx, cy - h / 2 - f / 2, z), ...WOOD), 0.012);
  add(part, 'wood', paint(box(f, h, 0.12, cx - w / 2 - f / 2, cy, z), ...WOOD), 0.012);
  add(part, 'wood', paint(box(f, h, 0.12, cx + w / 2 + f / 2, cy, z), ...WOOD), 0.012);
}

// ---------- 초가집 ----------
// parts: base, body, front, roof, interior. o.open → 가운데 문이 열린 출입구(외딴집)
export function choga(add, o) {
  const W = o.w, D = o.d, F = 0.4, wallH = 1.85, rnd = o.rnd;
  const top = F + wallH, zf = D / 2, t = 0.16;
  // 기단
  add('base', 'stone', paint(box(W + 0.9, 0.55, D + 0.9, 0, F - 0.275, 0), ...STONE, 0.06, rnd), 0.03);
  for (let i = 0; i < 9; i++) {
    const s = lump(0.2 + rnd() * 0.08, 0, rnd, 0.3, 0.7);
    add('base', 'stone', paint(xf(s, -W / 2 - 0.2 + (W + 0.4) * (i / 8), 0.1 + rnd() * 0.1, D / 2 + 0.45), '#b0aa9e', '#8a857b', 0.05, rnd), 0.02);
  }
  // 기둥
  const px = [-W / 2, -W / 6, W / 6, W / 2];
  for (const x of px) {
    add('front', 'wood', paint(box(0.2, wallH + 0.05, 0.2, x, F + wallH / 2, zf), ...WOOD), 0.02);
    add('body', 'wood', paint(box(0.2, wallH, 0.2, x, F + wallH / 2, -zf), ...WOOD), 0.02);
  }
  for (const s of [-1, 1]) add('body', 'wood', paint(box(0.2, wallH, 0.2, s * W / 2, F + wallH / 2, 0), ...WOOD), 0.02);
  // 뒷벽, 옆벽
  add('body', 'mud', paint(box(W, wallH, t, 0, F + wallH / 2, -zf), ...MUD, 0.04, rnd), 0.02);
  for (const s of [-1, 1]) add('body', 'mud', paint(box(t, wallH, D, s * W / 2, F + wallH / 2, 0), ...MUD, 0.04, rnd), 0.02);
  // 앞벽 3칸: 왼쪽 창, 가운데 방문, 오른쪽 부엌문
  const bw = W / 3;
  holedWall(add, 'front', -W / 2, -W / 2 + bw, F, top, -W / 3 - 0.36, -W / 3 + 0.36, F + 0.85, F + 1.45, zf, t, MUD);
  paperPanel(add, 'front', -W / 3, F + 1.15, 0.72, 0.6, zf);
  holedWall(add, 'front', -bw / 2, bw / 2, F, top, -0.7, 0.7, F, F + 1.62, zf, t, MUD);
  if (o.open) {
    // 열린 여닫이 두 짝(바깥으로 젖혀짐)
    for (const s of [-1, 1]) {
      const g = new THREE.BoxGeometry(0.7, 1.6, 0.05);
      g.translate(-s * 0.35, 0, 0);
      xf(g, s * 0.7, F + 0.81, zf + 0.06, 0, s * 1.2, 0);
      add('front', 'paper', g, 0);
    }
    for (const s of [-1, 1]) add('front', 'wood', paint(box(0.08, 1.62, 0.2, s * 0.74, F + 0.81, zf), ...WOOD), 0.012);
    add('front', 'wood', paint(box(1.56, 0.1, 0.2, 0, F + 1.66, zf), ...WOOD), 0.012);
    add('front', 'wood', paint(box(1.4, 0.06, 0.2, 0, F + 0.03, zf), ...WOOD), 0.01);
  } else {
    paperPanel(add, 'front', -0.35, F + 0.82, 0.66, 1.58, zf);
    paperPanel(add, 'front', 0.35, F + 0.82, 0.66, 1.58, zf);
  }
  holedWall(add, 'front', bw / 2, W / 2, F, top, W / 3 - 0.45, W / 3 + 0.45, F, F + 1.6, zf, t, MUD);
  // 부엌 널문
  add('front', 'wood', paint(box(0.9, 1.6, 0.06, W / 3, F + 0.8, zf - 0.02), '#5a4432', '#3f2f22', 0.04, rnd), 0.012);
  // 도리(윗 가로재)
  add('front', 'wood', paint(box(W + 0.4, 0.18, 0.22, 0, top + 0.02, zf), ...WOOD), 0.02);
  add('body', 'wood', paint(box(W + 0.4, 0.18, 0.22, 0, top + 0.02, -zf), ...WOOD), 0.02);
  // 툇마루
  add('front', 'wood', paint(box(bw + 1.2, 0.1, 0.62, 0, F - 0.02, zf + 0.42), ...WOOD_L), 0.02);
  for (const s of [-1, 1]) add('front', 'wood', paint(box(0.12, 0.4, 0.12, s * (bw / 2 + 0.45), F - 0.24, zf + 0.62), ...WOOD), 0.01);
  // 댓돌
  add('base', 'stone', paint(box(0.9, 0.18, 0.5, 0, 0.05, zf + 0.95), '#b8b2a5', '#8e897f', 0.05, rnd), 0.02);
  // 굴뚝
  if (o.chimney !== false) {
    add('body', 'stone', paint(box(0.42, 1.5, 0.42, W / 2 + 0.55, 0.75 - 0.3, -zf + 0.4), '#9d8a6a', '#6f6452', 0.06, rnd), 0.025);
    add('body', 'flat', paint(box(0.56, 0.1, 0.56, W / 2 + 0.55, 1.2, -zf + 0.4), '#6f6452', '#6f6452'), 0.02);
  }
  // 초가 지붕: 납작한 타원 돔 + 두툼한 이엉 가장자리 + 용마름
  const th = 1.12, X = W / 2 + 0.75, Z = D / 2 + 0.8, Hh = 1.35 + (o.hump || 0);
  const Ry = Hh / (1 - Math.cos(th)), eave = top + 0.12;
  const dome = new THREE.SphereGeometry(1, 18, 7, 0, Math.PI * 2, 0, th);
  xf(dome, 0, eave - Ry * Math.cos(th), 0, 0, 0, 0, X / Math.sin(th), Ry, Z / Math.sin(th));
  add('roof', 'thatch', paint(dome, '#e0cc98', '#a18a5e', 0.05, rnd), 0.05);
  const lip = new THREE.CylinderGeometry(1, 1.02, 0.34, 18, 1);
  xf(lip, 0, eave - 0.15, 0, 0, 0, 0, X, 1, Z);
  add('roof', 'thatch', paint(lip, '#a69064', '#7d6a48', 0.04, rnd), 0.04);
  add('roof', 'thatch', paint(xf(new THREE.CylinderGeometry(0.17, 0.17, W * 0.42, 8), 0, eave + Hh - 0.08, 0, 0, 0, Math.PI / 2), '#b39d6c', '#8f7b52'), 0.03);
  // 지붕 위 박 넝쿨
  if (o.gourd) {
    const Rx = X / Math.sin(th), Rz = Z / Math.sin(th), cy = eave - Ry * Math.cos(th);
    for (const [ux, uz, gs] of [[-0.35, 0.35, 0.3], [0.1, 0.5, 0.36], [0.4, 0.2, 0.26]]) {
      const px = ux * X, pz = uz * Z;
      const py = cy + Ry * Math.sqrt(Math.max(0, 1 - (px / Rx) ** 2 - (pz / Rz) ** 2));
      add('roof', 'organic', paint(xf(new THREE.SphereGeometry(gs, 10, 6), px, py + gs * 0.55, pz, 0, 0, 0, 1, 0.8, 1), '#f1ecd6', '#c9c9a0'), 0.015);
      add('roof', 'leaf', paint(xf(lump(gs * 0.9, 0, rnd, 0.2, 0.35), px + 0.3, py + 0.08, pz - 0.2), '#7f9456', '#56663a'), 0.012);
    }
  }
  return { F, top, eave, W, D };
}

// 외딴집 실내(로컬 좌표, F = 마루 높이)
export function chogaInterior(add, W, D, F, rnd) {
  const iw = W - 0.2, id = D - 0.2;
  add('interior', 'flat', paint(box(iw, 0.04, id, 0, F + 0.0, 0), '#d8b36b', '#caa25a', 0.04, rnd), 0);
  // 장판 이음선
  for (let i = -2; i <= 2; i++) add('interior', 'flat', paint(box(0.02, 0.005, id, i * iw / 5.2, F + 0.025, 0), '#9c7a40'), 0);
  // 벽 안쪽 한지 도배
  add('interior', 'flat', paint(box(iw, 1.8, 0.02, 0, F + 0.92, -D / 2 + 0.1), '#efe5cc', '#ddd0b0', 0.02, rnd), 0);
  for (const s of [-1, 1]) add('interior', 'flat', paint(box(0.02, 1.8, id, s * (W / 2 - 0.1), F + 0.92, 0), '#efe5cc', '#ddd0b0', 0.02, rnd), 0);
  // 반닫이(궤)
  const cx = -W / 2 + 0.9, cz = -D / 2 + 0.55;
  add('interior', 'wood', paint(box(1.3, 0.75, 0.55, cx, F + 0.4, cz), '#5c3c26', '#43291a', 0.03, rnd), 0.02);
  for (const dx of [-0.4, 0, 0.4]) add('interior', 'flat', paint(box(0.12, 0.14, 0.02, cx + dx, F + 0.55, cz + 0.285), '#c9a348'), 0.005);
  add('interior', 'flat', paint(box(1.36, 0.05, 0.6, cx, F + 0.79, cz), '#4a2f1d'), 0.01);
  // 개어 둔 이불(오방색)
  const bc = ['#a8483a', '#3f5f7a', '#e2d8bf', '#c9a34a'];
  bc.forEach((c, i) => add('interior', 'flat', paint(box(1.0 - i * 0.04, 0.12, 0.6, cx, F + 0.88 + i * 0.12, cz), c, c, 0.03, rnd), 0.01));
  // 소반 + 그릇
  const tx = 0.75, tz = -1.05;
  add('interior', 'wood', paint(cyl(0.42, 0.42, 0.05, 12, tx, F + 0.32, tz), '#7a5234', '#6a4428'), 0.015);
  add('interior', 'wood', paint(cyl(0.34, 0.3, 0.26, 12, tx, F + 0.16, tz), '#5c3c26', '#43291a'), 0.01);
  add('interior', 'flat', paint(cyl(0.1, 0.07, 0.07, 10, tx - 0.12, F + 0.38, tz), '#e8e2d2', '#c8c0ac'), 0.006);
  add('interior', 'flat', paint(cyl(0.09, 0.06, 0.06, 10, tx + 0.15, F + 0.38, tz + 0.08), '#e8e2d2', '#c8c0ac'), 0.006);
  // 방석 두 장
  for (const [x, z] of [[tx - 0.75, tz + 0.15], [tx + 0.7, tz + 0.3]]) add('interior', 'flat', paint(box(0.55, 0.06, 0.55, x, F + 0.04, z), '#8a3e3a', '#6e302c', 0.03, rnd), 0.01);
  // 호롱불: 등잔대 + 등잔 + 불꽃
  const lx = W / 2 - 0.55, lz = -D / 2 + 0.55;
  add('interior', 'flat', paint(cyl(0.16, 0.2, 0.05, 8, lx, F + 0.03, lz), '#5a3f2a'), 0.01);
  add('interior', 'flat', paint(cyl(0.025, 0.03, 0.62, 6, lx, F + 0.34, lz), '#5a3f2a'), 0.008);
  add('interior', 'flat', paint(cyl(0.11, 0.06, 0.05, 8, lx, F + 0.67, lz), '#e0d6be', '#bfb49a'), 0.008);
  add('interior', 'glow', paint(xf(new THREE.ConeGeometry(0.03, 0.1, 6), lx, F + 0.75, lz), '#ffd27a', '#ff9a3a'), 0);
  // 벽 선반과 옹기 그릇
  add('interior', 'wood', paint(box(1.1, 0.05, 0.25, 0.9, F + 1.35, -D / 2 + 0.25), ...WOOD_L), 0.01);
  add('interior', 'onggi', paint(cyl(0.1, 0.12, 0.2, 10, 0.7, F + 1.48, -D / 2 + 0.25), '#6a4430', '#4a2e20'), 0.006);
  add('interior', 'onggi', paint(cyl(0.08, 0.1, 0.16, 10, 1.05, F + 1.46, -D / 2 + 0.25), '#6a4430', '#4a2e20'), 0.006);
  return {
    lamp: { x: lx, y: F + 0.8, z: lz },
    colliders: [
      { type: 'box', minX: cx - 0.7, maxX: cx + 0.7, minZ: cz - 0.35, maxZ: cz + 0.35 },
      { type: 'circle', x: tx, z: tz, r: 0.45 },
      { type: 'circle', x: lx, z: lz, r: 0.22 },
    ],
  };
}

// ---------- 기와집 ----------
export function giwa(add, o) {
  const W = o.w, D = o.d, F = 0.75, wallH = 2.3, rnd = o.rnd, zf = D / 2, t = 0.18, top = F + wallH;
  // 높은 돌 기단 + 계단
  add('base', 'stone', paint(box(W + 1.2, F + 0.1, D + 1.2, 0, (F - 0.1) / 2, 0), '#aaa498', '#7b766c', 0.05, rnd), 0.03);
  for (let i = 0; i < 14; i++) add('base', 'stone', paint(box(0.64, 0.3, 0.05, -W / 2 - 0.3 + i * (W + 0.6) / 13, 0.28 + (i % 2) * 0.3, D / 2 + 0.61), '#b5afa2', '#948f84', 0.06, rnd), 0);
  for (let s = 0; s < 3; s++) add('base', 'stone', paint(box(1.8, 0.25, 0.4, 0, 0.12 + s * 0.25, D / 2 + 1.2 - s * 0.35), '#b8b2a5', '#8e897f', 0.04, rnd), 0.02);
  // 기둥(둥근)
  const bays = 5, bw = W / bays;
  for (let i = 0; i <= bays; i++) {
    const x = -W / 2 + i * bw;
    add('front', 'flat', paint(cyl(0.14, 0.15, wallH, 8, x, F + wallH / 2, zf), ...DANCHEONG_R), 0.02);
    add('body', 'flat', paint(cyl(0.14, 0.15, wallH, 8, x, F + wallH / 2, -zf), ...DANCHEONG_R), 0.02);
  }
  add('body', 'mud', paint(box(W, wallH, t, 0, F + wallH / 2, -zf), ...PLASTER, 0.03, rnd), 0.02);
  for (const s of [-1, 1]) add('body', 'mud', paint(box(t, wallH, D, s * W / 2, F + wallH / 2, 0), ...PLASTER, 0.03, rnd), 0.02);
  // 앞면 칸: 벽+창 / 방문 / 대청(열림) / 방문 / 벽+창
  for (let i = 0; i < bays; i++) {
    const x0 = -W / 2 + i * bw, x1 = x0 + bw, cx = (x0 + x1) / 2;
    if (i === 2) {
      // 대청: 안쪽 어둡게, 마루
      add('front', 'flat', paint(box(bw, wallH, 0.05, cx, F + wallH / 2, zf - 1.4), '#3e3128', '#2c231c'), 0);
      add('front', 'flat', paint(box(bw, 0.06, 1.4, cx, F + 0.03, zf - 0.7), '#a07e56', '#8a6a46'), 0);
      add('front', 'flat', paint(box(bw, 0.35, t, cx, top - 0.17, zf), '#7a5a3c', '#5e442e'), 0.015);
      continue;
    }
    if (i === 1 || i === 3) {
      holedWall(add, 'front', x0, x1, F, top, cx - 0.62, cx + 0.62, F + 0.35, F + 2.0, zf, t, PLASTER);
      paperPanel(add, 'front', cx - 0.31, F + 1.175, 0.6, 1.62, zf);
      paperPanel(add, 'front', cx + 0.31, F + 1.175, 0.6, 1.62, zf);
      add('front', 'wood', paint(box(bw, 0.34, 0.2, cx, F + 0.17, zf), ...WOOD_L), 0.012);
    } else {
      holedWall(add, 'front', x0, x1, F, top, cx - 0.42, cx + 0.42, F + 0.95, F + 1.65, zf, t, PLASTER);
      paperPanel(add, 'front', cx, F + 1.3, 0.84, 0.7, zf);
      add('front', 'wood', paint(box(bw, 0.5, 0.2, cx, F + 0.25, zf + 0.01), ...WOOD_L), 0.012);
    }
  }
  // 창방 + 단청 띠
  add('front', 'flat', paint(box(W + 0.5, 0.24, 0.3, 0, top + 0.12, zf), '#557d70', '#3f6558', 0.02), 0.02);
  add('front', 'flat', paint(box(W + 0.5, 0.08, 0.32, 0, top + 0.28, zf), '#a3503a', '#a3503a'), 0.01);
  add('body', 'flat', paint(box(W + 0.5, 0.3, 0.3, 0, top + 0.15, -zf), '#557d70', '#3f6558'), 0.02);
  for (const s of [-1, 1]) add('body', 'flat', paint(box(0.3, 0.3, D + 0.4, s * W / 2, top + 0.15, 0), '#557d70', '#3f6558'), 0.02);
  // 툇마루
  add('front', 'wood', paint(box(W - 0.2, 0.08, 0.7, 0, F - 0.02, zf + 0.35), ...WOOD_L), 0.015);
  // 지붕
  const eave = top + 0.55;
  const roof = curvedRoof({ hw: W / 2 + 1.7, hd: D / 2 + 1.55, eaveY: eave, rise: 2.4, lift: 0.6, k: 1.9, thick: 0.26 });
  add('roof', 'tile', roof, 0.05);
  add('roof', 'makse', roof.userData.edge, 0);
  ridgeCap(add, 'roof', roof.userData.ridgeHalf + 0.2, roof.userData.ridgeY);
  return { F, top, eave };
}

// ---------- 정자 ----------
export function jeongja(add, o) {
  const s = o.s, h = s / 2, F = 0.95, rnd = o.rnd;
  for (const [x, z] of [[-h, -h], [h, -h], [-h, h], [h, h], [0, h], [0, -h], [-h, 0], [h, 0]]) {
    add('base', 'stone', paint(cyl(0.2, 0.26, 0.35, 6, x, 0.12, z), ...STONE, 0.05, rnd), 0.015);
  }
  add('base', 'wood', paint(box(s + 0.3, 0.16, s + 0.3, 0, F - 0.08, 0), ...WOOD_L, 0.04, rnd), 0.02);
  for (const [x, z] of [[-h, -h], [h, -h], [-h, h], [h, h]]) {
    add('body', 'flat', paint(cyl(0.12, 0.13, 3.3, 8, x, 1.65, z), ...DANCHEONG_R), 0.02);
  }
  // 계자난간
  for (const [x, z, w, d] of [[0, -h, s, 0.06], [-h, 0, 0.06, s], [h, 0, 0.06, s], [-h / 2 - 0.45, h, h - 0.5, 0.06], [h / 2 + 0.45, h, h - 0.5, 0.06]]) {
    add('body', 'wood', paint(box(w, 0.07, d, x, F + 0.55, z), ...WOOD), 0.01);
    add('body', 'wood', paint(box(w, 0.05, d, x, F + 0.2, z), ...WOOD), 0.01);
  }
  // 오르는 디딤돌
  add('base', 'stone', paint(box(0.9, 0.3, 0.5, 0, 0.15, h + 0.5), '#b8b2a5', '#8e897f'), 0.02);
  add('body', 'flat', paint(box(s + 0.3, 0.22, 0.26, 0, 3.3, h), '#557d70', '#3f6558'), 0.015);
  add('body', 'flat', paint(box(s + 0.3, 0.22, 0.26, 0, 3.3, -h), '#557d70', '#3f6558'), 0.015);
  const roof = curvedRoof({ hw: h + 1.25, hd: h + 1.25, eaveY: 3.55, rise: 1.7, lift: 0.5, k: 1, thick: 0.22, nx: 28, nz: 28 });
  add('roof', 'tile', roof, 0.045);
  add('roof', 'makse', roof.userData.edge, 0);
  add('roof', 'flat', paint(cyl(0.12, 0.2, 0.5, 8, 0, roof.userData.ridgeY + 0.2, 0), '#3d3f42', '#2d2e30'), 0.02);
  // 청사초롱
  const lz = h + 0.25;
  add('body', 'flat', paint(cyl(0.01, 0.01, 0.5, 4, 0, 3.05, lz), '#2d2520'), 0);
  add('body', 'lamp', paint(cyl(0.17, 0.17, 0.25, 8, 0, 2.66, lz), '#c0443a', '#c0443a'), 0.012);
  add('body', 'lamp', paint(cyl(0.17, 0.17, 0.14, 8, 0, 2.47, lz), '#3c5f86', '#3c5f86'), 0.012);
  add('body', 'flat', paint(cyl(0.12, 0.12, 0.04, 8, 0, 2.81, lz), '#2d2520'), 0.006);
  return { lamp: { x: 0, y: 2.6, z: lz } };
}

// ---------- 느티나무 / 노거수 ----------
export function bigTree(add, rnd, o = {}) {
  const hgt = o.h || 7.5, spread = o.spread || 4.2;
  const tr = o.trunk || 0.5;
  const base = new THREE.Vector3(0, -0.2, 0);
  const fork = new THREE.Vector3((rnd() - 0.5) * 0.6, hgt * 0.38, (rnd() - 0.5) * 0.3);
  add('trunk', 'bark', paint(limb(base, fork, tr, tr * 0.72, 8), '#6a5a48', '#4a3e32', 0.05, rnd), 0.03);
  add('trunk', 'bark', paint(xf(new THREE.CylinderGeometry(tr * 0.9, tr * 1.6, 0.5, 8), 0, 0.05, 0), '#5a4c3e', '#44392e'), 0.03);
  const tips = [];
  const nb = o.branches || 4;
  for (let i = 0; i < nb; i++) {
    const a = (i / nb) * Math.PI * 2 + rnd() * 0.6;
    const tip = new THREE.Vector3(Math.cos(a) * spread * (0.5 + rnd() * 0.3), hgt * (0.7 + rnd() * 0.2), Math.sin(a) * spread * 0.5 * (0.5 + rnd() * 0.3));
    add('trunk', 'bark', paint(limb(fork, tip, tr * 0.6, tr * 0.22, 6), '#6a5a48', '#4a3e32', 0.05, rnd), 0.025);
    tips.push(tip);
  }
  if (o.bare) return { tips };
  const cols = o.leaf || [['#a2ab66', '#5f6c3e'], ['#94a05e', '#566238']];
  const blobs = [[0, hgt * 0.95, 0, spread * 0.55], ...tips.map((t) => [t.x, t.y + 0.4, t.z, spread * (0.38 + rnd() * 0.12)])];
  for (let i = 0; i < 3; i++) blobs.push([(rnd() - 0.5) * spread * 1.2, hgt * (0.65 + rnd() * 0.25), (rnd() - 0.5) * spread * 0.6, spread * 0.35]);
  for (const [x, y, z, r] of blobs) {
    const c = cols[Math.floor(rnd() * cols.length)];
    add('leaf', 'leaf', paint(xf(lump(r, 1, rnd, 0.16, o.willow ? 0.6 : 0.72), x, y, z), c[0], c[1], 0.04, rnd), 0.045);
    // 감: 수관 겉면에 주황 열매
    if (o.fruit) for (let k = 0; k < 5; k++) {
      const th = rnd() * Math.PI * 2, ph = 0.3 + rnd() * 1.1;
      add('leaf', 'organic', paint(xf(new THREE.SphereGeometry(0.12, 5, 3), x + Math.cos(th) * Math.sin(ph) * r * 0.95, y + Math.cos(ph) * r * 0.7, z + Math.sin(th) * Math.sin(ph) * r * 0.95), '#e8782e', '#c85a22'), 0);
    }
    // 버들: 늘어진 가지
    if (o.willow) for (let k = 0; k < 9; k++) {
      const th = rnd() * Math.PI * 2, len = 1.6 + rnd() * 1.8;
      const gx = x + Math.cos(th) * r * 0.85, gz = z + Math.sin(th) * r * 0.85;
      const g = new THREE.CylinderGeometry(0.1, 0.02, len, 4, 1, true);
      xf(g, gx, y - len / 2, gz, (rnd() - 0.5) * 0.15, 0, (rnd() - 0.5) * 0.15);
      add('leaf', 'leaf', paint(g, c[0], c[1], 0.03, rnd), 0);
    }
  }
  return { tips };
}

// ---------- 소품 ----------
export function well(add, rnd) {
  add('p', 'stone', paint(cyl(0.82, 0.9, 0.8, 8, 0, 0.35, 0), '#a8a295', '#7b766c', 0.08, rnd), 0.025);
  add('p', 'stone', paint(cyl(0.9, 0.9, 0.1, 8, 0, 0.8, 0), '#bdb7aa', '#a8a295'), 0.02);
  add('p', 'smooth', paint(cyl(0.64, 0.64, 0.02, 12, 0, 0.62, 0), '#2e3a3c', '#2e3a3c'), 0);
  for (const s of [-1, 1]) add('p', 'wood', paint(box(0.12, 1.9, 0.12, s * 0.95, 0.95, 0), ...WOOD), 0.015);
  add('p', 'wood', paint(box(2.2, 0.12, 0.14, 0, 1.9, 0), ...WOOD), 0.015);
  add('p', 'flat', paint(cyl(0.02, 0.02, 0.8, 4, 0.2, 1.45, 0), '#b8a57c'), 0);
  add('p', 'wood', paint(cyl(0.16, 0.13, 0.22, 8, 0.2, 1.0, 0), '#7a5c3e', '#5e442e'), 0.012);
  // 두레박 하나는 턱에
  add('p', 'wood', paint(cyl(0.15, 0.12, 0.2, 8, -0.55, 0.95, 0.5), '#7a5c3e', '#5e442e'), 0.012);
}

function onggiGeo(r, h) {
  const pts = [[0, 0], [0.55, 0], [0.8, 0.18], [1, 0.48], [0.92, 0.75], [0.62, 0.92], [0.58, 1.0], [0, 1.0]].map(([a, b]) => new THREE.Vector2(a * r, b * h));
  return new THREE.LatheGeometry(pts, 12);
}
export function jangdok(add, rnd, w, d) {
  add('p', 'stone', paint(box(w, 0.4, d, 0, 0.15, 0), '#b0aa9e', '#827d73', 0.06, rnd), 0.025);
  for (let i = 0; i < 12; i++) {
    const t = i / 11, sx = (i % 2) * 2 - 1;
    add('p', 'stone', paint(xf(lump(0.22, 0, rnd, 0.3, 0.7), -w / 2 + w * t, 0.2, d / 2 + 0.02), '#bbb5a8', '#8e897f', 0.05, rnd), 0.015);
    void sx;
  }
  const rows = [[-d / 2 + 0.5, 0.42, 0.95, 4], [0.05, 0.36, 0.78, 4], [d / 2 - 0.45, 0.26, 0.55, 5]];
  for (const [z, r, h, n] of rows) {
    for (let i = 0; i < n; i++) {
      const x = -w / 2 + 0.45 + (w - 0.9) * (n === 1 ? 0.5 : i / (n - 1)) + (rnd() - 0.5) * 0.1;
      const rr = r * (0.85 + rnd() * 0.25), hh = h * (0.85 + rnd() * 0.25);
      add('p', 'onggi', paint(xf(onggiGeo(rr, hh), x, 0.35, z), '#6e4a33', '#3e281c', 0.05, rnd), 0.02);
      add('p', 'onggi', paint(xf(new THREE.CylinderGeometry(rr * 0.66, rr * 0.7, 0.08, 12), x, 0.35 + hh + 0.03, z), '#6a4630', '#553826'), 0.012);
      add('p', 'onggi', paint(xf(new THREE.SphereGeometry(rr * 0.2, 8, 4, 0, Math.PI * 2, 0, Math.PI / 2), x, 0.35 + hh + 0.06, z), '#6a4630'), 0.008);
    }
  }
}

export function haystack(add, rnd, s = 1) {
  const pts = [[0, 0], [1.05, 0], [1.15, 0.5], [1.0, 1.1], [0.62, 1.7], [0.2, 2.05], [0, 2.1]].map(([a, b]) => new THREE.Vector2(a * s, b * s));
  add('p', 'thatch', paint(new THREE.LatheGeometry(pts, 10), '#dcc78e', '#9d8656', 0.05, rnd), 0.035);
  add('p', 'thatch', paint(xf(new THREE.ConeGeometry(0.28 * s, 0.5 * s, 8), 0, 2.2 * s, 0), '#b8a06a', '#9d8656'), 0.02);
  add('p', 'flat', paint(xf(new THREE.TorusGeometry(0.9 * s, 0.035, 4, 16), 0, 1.25 * s, 0, Math.PI / 2, 0, 0), '#6d5a3c'), 0);
}

export function jangseung(add, rnd, female) {
  add('p', 'wood', paint(cyl(0.2, 0.26, 2.7, 8, 0, 1.3, 0), '#9a8466', '#6d5c46', 0.05, rnd), 0.025);
  add('p', female ? 'face1' : 'face0', xf(new THREE.PlaneGeometry(0.4, 1.9), 0, 1.45, 0.24), 0);
  if (!female) {
    add('p', 'flat', paint(cyl(0.2, 0.24, 0.45, 8, 0, 2.85, 0), '#2e2a26', '#26221f'), 0.02);
    add('p', 'flat', paint(cyl(0.42, 0.42, 0.05, 10, 0, 2.66, 0), '#2e2a26'), 0.015);
  } else {
    add('p', 'flat', paint(cyl(0.18, 0.22, 0.3, 8, 0, 2.78, 0), '#4d6a78', '#3e5864'), 0.02);
  }
  for (let i = 0; i < 6; i++) add('p', 'stone', paint(xf(lump(0.22, 0, rnd, 0.3, 0.6), Math.cos(i) * 0.45, 0.08, Math.sin(i) * 0.45), ...STONE), 0.015);
}

export function torchPost(add, rnd) {
  add('p', 'wood', paint(cyl(0.06, 0.08, 1.8, 6, 0, 0.9, 0), ...WOOD), 0.012);
  add('p', 'flat', paint(xf(new THREE.ConeGeometry(0.2, 0.3, 6), 0, 1.9, 0, Math.PI, 0, 0), '#3d2e22'), 0.012);
  add('p', 'glow', paint(xf(new THREE.ConeGeometry(0.12, 0.34, 6), 0, 2.15, 0), '#ffcf6a', '#ff7a2a'), 0);
  for (let i = 0; i < 4; i++) add('p', 'stone', paint(xf(lump(0.16, 0, rnd, 0.3, 0.6), Math.cos(i * 1.6) * 0.25, 0.05, Math.sin(i * 1.6) * 0.25), ...STONE), 0.01);
}

// 돌담: (ax,az)→(bx,bz)
export function stoneWall(add, rnd, ax, az, bx, bz, h = 1.3) {
  const len = Math.hypot(bx - ax, bz - az), ang = Math.atan2(bz - az, bx - ax);
  const m = new THREE.Matrix4().makeRotationY(-ang).setPosition((ax + bx) / 2, 0, (az + bz) / 2);
  const put = (g) => g.applyMatrix4(m);
  add('p', 'stone', put(paint(box(len, h, 0.55, 0, h / 2 - 0.05, 0), '#a39a86', '#857c6a', 0.05, rnd)), 0.03);
  const n = Math.max(2, Math.round(len / 0.5));
  for (let row = 0; row < 2; row++) for (let i = 0; i < n; i++) {
    const x = -len / 2 + (i + 0.5 + (row % 2) * 0.4) * (len / n) - 0.1;
    if (x > len / 2 - 0.15) continue;
    for (const side of [1]) {
      const r = 0.22 + rnd() * 0.08;
      const g = lump(r, 0, rnd, 0.35, 0.7);
      xf(g, x, 0.3 + row * 0.5 * (h / 1.3) + (rnd() - 0.5) * 0.06, side * 0.26, 0, rnd() * 3, 0, 1.15, 1.2, 0.55);
      add('p', 'stone', put(paint(g, '#bdb6a6', '#8f887a', 0.08, rnd)), 0.02);
    }
  }
  const nt = Math.max(2, Math.round(len / 0.7));
  for (let i = 0; i < nt; i++) {
    const x = -len / 2 + (i + 0.5) * (len / nt);
    const g = lump(0.38, 0, rnd, 0.3, 0.5);
    xf(g, x, h + 0.02, 0, 0, rnd() * 3, 0);
    add('p', 'stone', put(paint(g, '#b3ac9c', '#90897b', 0.08, rnd)), 0.02);
  }
  return { len, ang };
}

// 싸리 울타리
export function fence(add, rnd, ax, az, bx, bz, h = 1.15) {
  const len = Math.hypot(bx - ax, bz - az), ang = Math.atan2(bz - az, bx - ax);
  const m = new THREE.Matrix4().makeRotationY(-ang).setPosition(ax, 0, az);
  const put = (g) => g.applyMatrix4(m);
  const np = Math.max(1, Math.round(len / 1.6));
  for (let i = 0; i <= np; i++) add('p', 'wood', put(paint(cyl(0.05, 0.06, h + 0.15, 5, (i / np) * len, (h + 0.15) / 2, 0), ...WOOD)), 0.012);
  const ns = Math.round(len / 0.11);
  const pos = [];
  for (let i = 0; i < ns; i++) {
    const x = (i + 0.5) * (len / ns), hh = h * (0.85 + rnd() * 0.2);
    pos.push(xf(new THREE.BoxGeometry(0.035, hh, 0.035), x, hh / 2, (rnd() - 0.5) * 0.05, (rnd() - 0.5) * 0.08, 0, (rnd() - 0.5) * 0.12));
  }
  for (const g of pos) add('p', 'flat', put(paint(g, '#9c8462', '#6e5a44', 0.08, rnd)), 0);
  for (const y of [0.35, 0.8]) add('p', 'flat', put(paint(box(len, 0.05, 0.08, len / 2, y * h, 0.03), '#5e4a36')), 0.008);
  return { len };
}

// 돌다리(홍예): 로컬 z축이 다리 방향. deck(z)는 상판 높이 함수
export function stoneBridge(add, rnd, z0, z1, hw, deck) {
  const n = 14;
  for (let i = 0; i < n; i++) {
    const za = z0 + (z1 - z0) * i / n, zb = z0 + (z1 - z0) * (i + 1) / n;
    const ya = deck(za), yb = deck(zb), zc = (za + zb) / 2;
    const ang = Math.atan2(yb - ya, zb - za);
    const g = new THREE.BoxGeometry(hw * 2, 0.28, (zb - za) + 0.03);
    xf(g, (rnd() - 0.5) * 0.02, (ya + yb) / 2 - 0.14, zc, -ang, 0, 0);
    add('p', 'stone', paint(g, '#b9b3a6', '#99938a', 0.08, rnd), 0.02);
    for (const s of [-1, 1]) {
      const c = new THREE.BoxGeometry(0.26, 0.32, (zb - za) + 0.02);
      xf(c, s * (hw - 0.05), (ya + yb) / 2 + 0.12, zc, -ang, 0, 0);
      add('p', 'stone', paint(c, '#a8a295', '#8a857b', 0.06, rnd), 0.02);
    }
  }
  // 아치 몸체
  const zc = (z0 + z1) / 2, ar = 2.1;
  const sh = new THREE.Shape();
  const pts = [];
  pts.push([z0 - 0.2, -1.7]);
  for (let i = 0; i <= 16; i++) { const z = z0 + (z1 - z0) * i / 16; pts.push([z, deck(z) - 0.27]); }
  pts.push([z1 + 0.2, -1.7]);
  pts.push([zc + ar, -1.7]);
  for (let i = 1; i < 12; i++) { const a = (i / 12) * Math.PI; pts.push([zc + Math.cos(a) * ar, -1.7 + Math.sin(a) * ar * 0.95]); }
  pts.push([zc - ar, -1.7]);
  sh.moveTo(-pts[0][0], pts[0][1]);
  for (let i = 1; i < pts.length; i++) sh.lineTo(-pts[i][0], pts[i][1]);
  const eg = new THREE.ExtrudeGeometry(sh, { depth: hw * 2 - 0.2, bevelEnabled: false });
  eg.rotateY(Math.PI / 2);
  eg.translate(-(hw - 0.1), 0, 0);
  add('p', 'stone', paint(eg, '#a9a397', '#6f6b62', 0.06, rnd), 0.03);
  // 홍예석 줄눈 느낌: 아치 둘레 돌
  for (let i = 0; i <= 10; i++) {
    const a = (i / 10) * Math.PI;
    for (const s of [-1, 1]) {
      const g = box(0.08, 0.34, 0.5, s * (hw - 0.06), -1.7 + Math.sin(a) * (ar * 0.95 + 0.18), zc + Math.cos(a) * (ar + 0.18));
      add('p', 'stone', paint(g, '#c4beb0', '#a39d90'), 0);
    }
  }
}

// 서낭당 돌무더기 + 제단 + 촛불
export function cairn(add, rnd) {
  for (let l = 0; l < 5; l++) {
    const R = 1.25 * (1 - l / 5.2), n = Math.max(1, Math.round(9 - l * 1.8));
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2 + l * 0.7 + rnd() * 0.3;
      const g = lump(0.3 - l * 0.02 + rnd() * 0.06, 0, rnd, 0.35, 0.7);
      xf(g, Math.cos(a) * R, 0.15 + l * 0.32, Math.sin(a) * R, 0, rnd() * 3, 0);
      add('p', 'stone', paint(g, '#b1ab9d', '#7c776c', 0.1, rnd), 0.025);
    }
  }
  add('p', 'stone', paint(xf(lump(0.28, 0, rnd, 0.3, 1.2), 0, 1.75, 0), '#bdb7aa', '#8e897f'), 0.025);
  add('p', 'stone', paint(box(0.9, 0.28, 0.5, 0, 0.14, 1.45), '#a8a295', '#8a857b', 0.05, rnd), 0.02);
  add('p', 'flat', paint(cyl(0.04, 0.045, 0.16, 6, 0.15, 0.36, 1.45), '#efe6d0'), 0.006);
  add('p', 'glow', paint(xf(new THREE.ConeGeometry(0.03, 0.09, 6), 0.15, 0.49, 1.45), '#ffd27a', '#ff9a3a'), 0);
  add('p', 'onggi', paint(cyl(0.1, 0.07, 0.08, 10, -0.2, 0.32, 1.45), '#e8e2d2', '#c8c0ac'), 0.006);
  return { candle: { x: 0.15, y: 0.55, z: 1.45 } };
}

export { prep };
