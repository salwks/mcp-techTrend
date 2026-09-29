// 타일 픽셀아트 (이미지 파일 없이 fillRect로 그림) + 맵 정적 레이어 사전 렌더링
import { hash2, mulberry32 } from './util.js';

export const TILE = 32;

// 통행 가능 타일 (CONTRACTS §8)
const WALKABLE = new Set(['.', ',', 'F', 'S', '=', '_', 'K', 'B', 'D', 'X', 'C', '^']);
export function isWalkable(ch) { return WALKABLE.has(ch); }

// 애니메이션 타일: 프레임 수와 프레임당 시간(초)
const ANIM = { '~': { frames: 4, rate: 0.35 }, L: { frames: 4, rate: 0.3 }, F: { frames: 2, rate: 0.6 } };
export function isAnimated(ch) { return !!ANIM[ch]; }

// 배경이 투명한 "올려놓는" 타일: 이웃 바닥 타일을 먼저 깔고 그린다
const OVERLAY = new Set(['T', 't', 'f', 'w', 'P', 'A', 'c', 'M', '^']);
const DEFAULT_UNDER = { T: '.', t: 'X', f: '.', w: '.', P: '_', A: '_', c: '=', M: '.', '^': '_' };

// ---------------------------------------------------------------
// 그리기 도우미
// ---------------------------------------------------------------
function R(g, x, y, w, h, c) { g.fillStyle = c; g.fillRect(x, y, w, h); }

// 픽셀 원(가장자리가 또렷한)
function disc(g, cx, cy, rx, ry, c) {
  g.fillStyle = c;
  for (let dy = -ry; dy <= ry; dy++) {
    const k = 1 - (dy * dy) / ((ry + 0.5) * (ry + 0.5));
    if (k <= 0) continue;
    const hw = Math.round(rx * Math.sqrt(k));
    g.fillRect(cx - hw, cy + dy, hw * 2, 1);
  }
}

function speckle(g, rnd, n, colors, w = 1, h = 1) {
  for (let i = 0; i < n; i++) {
    R(g, Math.floor(rnd() * (32 - w)), Math.floor(rnd() * (32 - h)), w, h, colors[i % colors.length]);
  }
}

// ---------------------------------------------------------------
// 타일별 그리기 (g: 32x32 컨텍스트, v: 변형 번호, f: 프레임)
// ---------------------------------------------------------------
const GRASS = '#62b04c', GRASS_D = '#4d963c', GRASS_L = '#82c962';

function grass(g, v) {
  R(g, 0, 0, 32, 32, GRASS);
  const rnd = mulberry32(101 + v * 17);
  // 옅은 색 얼룩
  for (let i = 0; i < 5; i++) R(g, Math.floor(rnd() * 28), Math.floor(rnd() * 30), 3 + Math.floor(rnd() * 3), 1, '#5aa846');
  const tufts = v === 0 ? 4 : v === 1 ? 2 : 3;
  for (let i = 0; i < tufts; i++) {
    const x = 2 + Math.floor(rnd() * 26), y = 3 + Math.floor(rnd() * 25);
    R(g, x, y + 1, 1, 2, GRASS_D); R(g, x + 1, y, 1, 2, GRASS_D); R(g, x + 2, y + 1, 1, 2, GRASS_D);
    R(g, x + 1, y - 1, 1, 1, GRASS_L);
  }
  if (v === 2) { R(g, 6 + Math.floor(rnd() * 20), 6 + Math.floor(rnd() * 20), 1, 1, '#fff8c0'); }
  for (let i = 0; i < 3; i++) R(g, Math.floor(rnd() * 31), Math.floor(rnd() * 31), 1, 1, GRASS_L);
}

function dirt(g, v) {
  R(g, 0, 0, 32, 32, '#caa56b');
  const rnd = mulberry32(211 + v * 31);
  speckle(g, rnd, 14, ['#b8925a', '#d9b881', '#bf9a60']);
  for (let i = 0; i < 2 + v; i++) {
    const x = 2 + Math.floor(rnd() * 26), y = 2 + Math.floor(rnd() * 26);
    R(g, x, y, 3, 2, '#9c7a4a'); R(g, x, y, 2, 1, '#e3c898');
  }
}

const FLOWER_COLORS = ['#ff6b8b', '#ffe066', '#ffffff', '#ff922b', '#da77f2'];
function flowers(g, v, f) {
  grass(g, 1);
  const rnd = mulberry32(307 + v * 13);
  for (let i = 0; i < 6; i++) {
    const bx = 3 + Math.floor(rnd() * 24), by = 4 + Math.floor(rnd() * 23);
    const col = FLOWER_COLORS[Math.floor(rnd() * FLOWER_COLORS.length)];
    const sway = f === 1 && i % 2 === 0 ? 1 : 0;
    R(g, bx + 1, by + 3, 1, 2, GRASS_D); // 줄기
    const x = bx + sway;
    R(g, x + 1, by, 1, 1, col); R(g, x, by + 1, 1, 1, col); R(g, x + 2, by + 1, 1, 1, col); R(g, x + 1, by + 2, 1, 1, col);
    R(g, x + 1, by + 1, 1, 1, col === '#ffe066' ? '#e8590c' : '#ffd43b');
  }
}

function sand(g, v) {
  R(g, 0, 0, 32, 32, '#e7d49b');
  const rnd = mulberry32(401 + v * 7);
  speckle(g, rnd, 18, ['#d6c083', '#f4e7bb', '#cdb676']);
  if (v === 1) { R(g, 8, 20, 6, 1, '#d6c083'); R(g, 14, 19, 5, 1, '#d6c083'); }
}

function woodFloor(g, v) {
  R(g, 0, 0, 32, 32, '#b9844f');
  const rnd = mulberry32(503 + v * 5);
  for (let row = 0; row < 4; row++) {
    const y = row * 8;
    R(g, 0, y + 7, 32, 1, '#86592f');
    R(g, 0, y, 32, 1, '#c99761');
    const seam = (row * 13 + v * 7) % 32;
    R(g, seam, y, 1, 7, '#86592f');
    for (let i = 0; i < 2; i++) R(g, Math.floor(rnd() * 26), y + 2 + Math.floor(rnd() * 4), 4 + Math.floor(rnd() * 4), 1, '#a8733f');
  }
}

function stoneFloor(g, v) {
  R(g, 0, 0, 32, 32, '#a3a6b0');
  for (const [ox, oy] of [[0, 0], [16, 0], [0, 16], [16, 16]]) {
    R(g, ox + 1, oy + 1, 14, 1, '#bcbfc8');
    R(g, ox + 1, oy + 1, 1, 14, '#b4b7c0');
    R(g, ox + 1, oy + 14, 14, 1, '#8f929c');
  }
  R(g, 0, 0, 32, 1, '#7d808a'); R(g, 0, 16, 32, 1, '#7d808a');
  R(g, 0, 0, 1, 32, '#7d808a'); R(g, 16, 0, 1, 32, '#7d808a');
  if (v === 1) { R(g, 20, 21, 3, 1, '#80838d'); R(g, 23, 22, 2, 1, '#80838d'); R(g, 25, 23, 1, 2, '#80838d'); }
  if (v === 2) { R(g, 5, 6, 2, 2, '#959882'); }
}

function carpet(g) {
  R(g, 0, 0, 32, 32, '#a52a3c');
  for (let y = 0; y < 32; y += 8) for (let x = 0; x < 32; x += 8) {
    R(g, x + 3, y + 2, 2, 1, '#8f1f30'); R(g, x + 2, y + 3, 4, 2, '#8f1f30'); R(g, x + 3, y + 5, 2, 1, '#8f1f30');
  }
  R(g, 0, 0, 32, 1, '#b8394b');
}

function bridge(g, v) {
  // v0: 세로로 건너는 다리, v1: 가로로 건너는 다리
  R(g, 0, 0, 32, 32, '#3b78d0');
  g.save();
  if (v === 1) { g.translate(32, 0); g.rotate(Math.PI / 2); }
  R(g, 3, 0, 26, 32, '#a8753f');
  for (let y = 0; y < 32; y += 6) { R(g, 3, y + 5, 26, 1, '#7a4f28'); R(g, 3, y, 26, 1, '#c28d55'); }
  R(g, 0, 0, 4, 32, '#6b4423'); R(g, 28, 0, 4, 32, '#6b4423');
  R(g, 1, 0, 1, 32, '#8b5a2b'); R(g, 29, 0, 1, 32, '#8b5a2b');
  for (let y = 4; y < 32; y += 14) { R(g, 0, y, 4, 3, '#4a2e17'); R(g, 28, y, 4, 3, '#4a2e17'); }
  g.restore();
}

function door(g) {
  R(g, 0, 0, 32, 32, '#5a3a1e');
  R(g, 4, 4, 24, 28, '#8b5a2b');
  R(g, 6, 2, 20, 2, '#8b5a2b'); R(g, 9, 1, 14, 1, '#8b5a2b');
  for (let x = 4; x < 28; x += 6) R(g, x + 5, 4, 1, 28, '#6b4423');
  R(g, 4, 10, 24, 2, '#4a2e17'); R(g, 4, 24, 24, 2, '#4a2e17');
  R(g, 22, 17, 3, 3, '#ffd43b'); R(g, 22, 17, 1, 1, '#fff3bf');
  R(g, 0, 30, 32, 2, '#3a2412');
}

function waste(g, v) {
  R(g, 0, 0, 32, 32, '#8b7d69');
  const rnd = mulberry32(601 + v * 11);
  speckle(g, rnd, 12, ['#7a6d5b', '#9d8f7b', '#6f6353']);
  // 균열
  let x = 4 + Math.floor(rnd() * 20), y = 4 + Math.floor(rnd() * 10);
  for (let i = 0; i < 9; i++) {
    R(g, x, y, 1, 1, '#5b503f');
    x += Math.floor(rnd() * 3) - 1; y += 1 + Math.floor(rnd() * 2);
    if (x < 0 || x > 31 || y > 31) break;
  }
  if (v === 2) { R(g, 20, 8, 4, 3, '#6f6353'); R(g, 20, 8, 3, 1, '#a89a86'); }
}

function caveFloor(g, v) {
  R(g, 0, 0, 32, 32, '#4f4655');
  const rnd = mulberry32(701 + v * 19);
  speckle(g, rnd, 16, ['#5e5566', '#433b49', '#665d6e']);
  for (let i = 0; i < 2; i++) {
    const x = 3 + Math.floor(rnd() * 24), y = 3 + Math.floor(rnd() * 24);
    R(g, x, y, 4, 3, '#3a3340'); R(g, x, y, 3, 1, '#72697a');
  }
}

function stairs(g) {
  for (let i = 0; i < 4; i++) {
    const y = i * 8;
    const shade = 180 - i * 18;
    R(g, 2, y, 28, 5, `rgb(${shade},${shade},${shade + 8})`);
    R(g, 2, y + 5, 28, 3, `rgb(${shade - 60},${shade - 60},${shade - 50})`);
  }
  R(g, 0, 0, 2, 32, '#5a5a66'); R(g, 30, 0, 2, 32, '#5a5a66');
}

function tree(g, v) {
  // 그림자 + 줄기 + 둥근 수관
  disc(g, 16, 28, 11, 3, 'rgba(0,0,0,0.25)');
  R(g, 13, 20, 6, 10, '#6b4423'); R(g, 13, 20, 2, 10, '#8b5a2b'); R(g, 11, 28, 10, 2, '#5a3a1e');
  disc(g, 16, 12, 14, 11, '#2d6e2f');
  disc(g, 15, 11, 12, 9, '#3c8f3b');
  disc(g, 12, 8, 7, 5, '#52aa47');
  disc(g, 11, 7, 3, 2, '#79c75f');
  const rnd = mulberry32(801 + v);
  for (let i = 0; i < 5; i++) R(g, 6 + Math.floor(rnd() * 20), 6 + Math.floor(rnd() * 12), 2, 1, '#2d6e2f');
  if (v === 1) { R(g, 20, 13, 2, 2, '#e03131'); R(g, 9, 15, 2, 2, '#e03131'); R(g, 17, 6, 2, 2, '#e03131'); }
}

function deadTree(g, v) {
  disc(g, 16, 29, 9, 2, 'rgba(0,0,0,0.25)');
  const c = '#6e5a48', d = '#4f3f31';
  R(g, 14, 10, 4, 20, c); R(g, 16, 10, 2, 20, d);
  R(g, 8, 12, 6, 2, c); R(g, 7, 8, 2, 5, c);
  R(g, 18, 15, 7, 2, c); R(g, 24, 10, 2, 6, c);
  R(g, 12, 4, 2, 7, c); R(g, 17, 3, 2, 8, d);
  if (v === 1) { R(g, 4, 6, 4, 2, c); R(g, 25, 7, 3, 1, c); }
}

function water(g, v, f) {
  R(g, 0, 0, 32, 32, '#3a78d0');
  R(g, 4, 6, 10, 5, '#336cc0'); R(g, 18, 20, 11, 6, '#336cc0'); R(g, 20, 4, 6, 3, '#4282d8');
  const off = f * 2;
  const waves = [[3, 8], [17, 14], [8, 22], [22, 27], [26, 5]];
  for (const [wx, wy] of waves) {
    const x = (wx + off) % 32;
    R(g, x, wy, 5, 1, '#8cc0f5'); R(g, (x + 1) % 32, wy - 1, 3, 1, '#b5d8fb');
  }
  if (f === (v % 4)) R(g, 12, 16, 1, 1, '#ffffff');
}

function wallFace(g, base, mortar, hi, lo) {
  R(g, 0, 0, 32, 32, mortar);
  for (let row = 0; row < 4; row++) {
    const y = row * 8;
    const shift = row % 2 ? 8 : 0;
    for (let x = -16 + shift; x < 32; x += 16) {
      R(g, x + 1, y + 1, 14, 6, base);
      R(g, x + 1, y + 1, 14, 1, hi);
      R(g, x + 1, y + 6, 14, 1, lo);
    }
  }
}

function stoneWall(g, v) {
  if (v === 1) { // 윗면
    R(g, 0, 0, 32, 32, '#5c5d69');
    R(g, 2, 2, 28, 28, '#666774');
    R(g, 6, 8, 6, 1, '#555663'); R(g, 18, 20, 7, 1, '#555663'); R(g, 20, 6, 1, 5, '#727380');
    return;
  }
  wallFace(g, '#8f909b', '#6a6b76', '#aaabb5', '#7a7b86');
  if (v === 2) { R(g, 18, 11, 1, 3, '#5b8f3c'); R(g, 17, 13, 3, 2, '#5b8f3c'); }
}

function castleWall(g, v) {
  if (v === 1) {
    R(g, 0, 0, 32, 32, '#211729');
    R(g, 2, 2, 28, 28, '#2a1e35');
    R(g, 8, 10, 8, 1, '#1a1221');
    return;
  }
  wallFace(g, '#3d2b4f', '#22172d', '#553d6c', '#2f213e');
  if (v === 2) { R(g, 12, 9, 1, 4, '#e03131'); R(g, 13, 12, 1, 5, '#e03131'); R(g, 12, 16, 1, 3, '#ff6b6b'); }
}

function woodWall(g, v) {
  R(g, 0, 0, 32, 32, '#9c6b3d');
  for (let x = 0; x < 32; x += 8) { R(g, x, 0, 1, 32, '#6e4724'); R(g, x + 1, 0, 1, 32, '#b07d4b'); }
  R(g, 0, 0, 32, 3, '#5a3a1e'); R(g, 0, 29, 32, 3, '#5a3a1e');
  if (v === 1) { // 창문
    R(g, 7, 8, 18, 15, '#5a3a1e');
    R(g, 9, 10, 14, 11, '#9fd3ff');
    R(g, 9, 10, 14, 3, '#c9e8ff');
    R(g, 15, 10, 2, 11, '#5a3a1e'); R(g, 9, 15, 14, 1, '#5a3a1e');
    R(g, 6, 23, 20, 2, '#6e4724');
    R(g, 8, 21, 3, 2, '#e64980'); R(g, 20, 21, 3, 2, '#fcc419');
  }
}

function roof(g, v) {
  const base = v === 1 ? '#3f6fb5' : '#b5463b';
  const dark = v === 1 ? '#2c4f85' : '#86302a';
  const hi = v === 1 ? '#5a8ad0' : '#cf5c4e';
  R(g, 0, 0, 32, 32, base);
  for (let row = 0; row < 4; row++) {
    const y = row * 8;
    R(g, 0, y + 7, 32, 1, dark);
    R(g, 0, y, 32, 1, hi);
    const shift = row % 2 ? 4 : 0;
    for (let x = shift; x < 32; x += 8) { R(g, x, y + 1, 1, 6, dark); R(g, x + 1, y + 5, 6, 2, dark); R(g, x + 1, y + 5, 6, 1, base); }
  }
}

function mountain(g, v) {
  const body = '#8d8073', dark = '#6a5e53', light = '#ab9d8e';
  // 삼각형 바위
  for (let y = 4; y < 31; y++) {
    const hw = Math.floor((y - 3) * 0.58) + 2;
    const cx = 16 + (v === 1 ? -2 : 0);
    R(g, cx - hw, y, hw * 2, 1, body);
    R(g, cx, y, hw, 1, dark);
    R(g, cx - hw, y, Math.max(1, Math.floor(hw / 3)), 1, light);
  }
  R(g, 13 + (v === 1 ? -2 : 0), 4, 6, 3, '#e9ecef');
  R(g, 14 + (v === 1 ? -2 : 0), 3, 3, 1, '#f8f9fa');
  R(g, 6, 30, 22, 2, 'rgba(0,0,0,0.2)');
}

function lava(g, v, f) {
  R(g, 0, 0, 32, 32, '#d9480f');
  R(g, 2, 3, 12, 6, '#8a1c0a'); R(g, 18, 18, 10, 5, '#8a1c0a'); R(g, 4, 22, 6, 4, '#a61e0d');
  const shift = f * 3;
  R(g, (6 + shift) % 28, 13, 7, 3, '#f76707'); R(g, (20 + shift) % 28, 8, 6, 2, '#f76707');
  R(g, (10 + shift * 2) % 28, 26, 8, 2, '#fd7e14');
  const b = [[8, 16], [22, 12], [14, 24], [26, 26]][(f + v) % 4];
  R(g, b[0], b[1], 3, 3, '#ffd43b'); R(g, b[0] + 1, b[1] - 1, 1, 1, '#fff3bf');
}

function pillar(g) {
  disc(g, 16, 29, 12, 3, 'rgba(0,0,0,0.3)');
  R(g, 9, 5, 14, 23, '#d8d4cc');
  R(g, 9, 5, 3, 23, '#f1ede5'); R(g, 19, 5, 4, 23, '#b3aea5');
  R(g, 14, 6, 1, 21, '#c4bfb6'); R(g, 17, 6, 1, 21, '#c4bfb6');
  R(g, 6, 1, 20, 5, '#e6e2da'); R(g, 6, 5, 20, 1, '#a39e95');
  R(g, 6, 27, 20, 4, '#c4bfb6'); R(g, 6, 27, 20, 1, '#e6e2da');
}

function altar(g) {
  disc(g, 16, 29, 14, 3, 'rgba(0,0,0,0.3)');
  R(g, 3, 10, 26, 19, '#9d97a8'); R(g, 3, 10, 26, 6, '#cbc5d6'); R(g, 3, 16, 26, 1, '#7d778a');
  R(g, 8, 16, 16, 11, '#5f3dc4'); R(g, 8, 16, 16, 1, '#ffd43b'); R(g, 8, 26, 16, 1, '#ffd43b');
  R(g, 14, 19, 4, 5, '#ffd43b'); R(g, 13, 20, 6, 2, '#ffd43b');
  R(g, 5, 5, 3, 6, '#f8f9fa'); R(g, 6, 3, 1, 2, '#ffa94d'); R(g, 24, 5, 3, 6, '#f8f9fa'); R(g, 25, 3, 1, 2, '#ffa94d');
}

function counter(g) {
  R(g, 0, 6, 32, 22, '#7a4f28');
  R(g, 0, 6, 32, 10, '#b27b44'); R(g, 0, 6, 32, 2, '#cf9a60'); R(g, 0, 15, 32, 1, '#5a3a1e');
  for (let x = 3; x < 32; x += 10) R(g, x, 18, 6, 8, '#6b4423');
  R(g, 0, 28, 32, 2, 'rgba(0,0,0,0.25)');
}

const BOOK = ['#c92a2a', '#1971c2', '#2f9e44', '#e8a33d', '#862e9c', '#495057', '#d9480f'];
function bookshelf(g, v) {
  R(g, 0, 0, 32, 32, '#5a3a1e');
  R(g, 2, 2, 28, 28, '#3b2513');
  const rnd = mulberry32(901 + v);
  for (let row = 0; row < 3; row++) {
    const y = 3 + row * 9;
    let x = 3;
    while (x < 28) {
      const w = 2 + Math.floor(rnd() * 2);
      const h = 5 + Math.floor(rnd() * 3);
      R(g, x, y + 8 - h, w, h, BOOK[Math.floor(rnd() * BOOK.length)]);
      R(g, x, y + 8 - h, w, 1, 'rgba(255,255,255,0.3)');
      x += w + (rnd() < 0.15 ? 2 : 0);
    }
    R(g, 2, y + 8, 28, 2, '#7a4f28');
  }
}

function fence(g, v) {
  const c = '#b07d4b', d = '#6e4724', l = '#d2a06a';
  if (v === 1) { // 세로
    R(g, 14, 0, 4, 32, d); R(g, 14, 0, 2, 32, c);
    R(g, 12, 4, 8, 6, d); R(g, 12, 4, 8, 2, l); R(g, 12, 20, 8, 6, d); R(g, 12, 20, 8, 2, l);
    return;
  }
  R(g, 0, 10, 32, 3, c); R(g, 0, 10, 32, 1, l); R(g, 0, 19, 32, 3, c); R(g, 0, 21, 32, 1, d);
  for (const x of [3, 19]) { R(g, x, 5, 5, 22, c); R(g, x, 5, 5, 2, l); R(g, x + 4, 5, 1, 22, d); R(g, x, 26, 5, 2, 'rgba(0,0,0,0.25)'); }
}

function well(g) {
  disc(g, 16, 19, 14, 11, 'rgba(0,0,0,0.25)');
  disc(g, 16, 17, 13, 11, '#8e8e98');
  disc(g, 16, 16, 12, 10, '#a9a9b3');
  disc(g, 16, 17, 8, 6, '#1d3557');
  disc(g, 15, 16, 3, 2, '#3a78d0');
  R(g, 4, 16, 2, 2, '#77777f'); R(g, 26, 16, 2, 2, '#77777f'); R(g, 15, 6, 2, 2, '#77777f');
  R(g, 2, 2, 3, 20, '#6b4423'); R(g, 27, 2, 3, 20, '#6b4423'); R(g, 2, 2, 28, 3, '#8b5a2b');
  R(g, 15, 5, 2, 7, '#ced4da');
}

function voidTile(g) { R(g, 0, 0, 32, 32, '#000'); }

const PAINTERS = {
  '.': [grass, 3], ',': [dirt, 2], F: [flowers, 2], S: [sand, 2], '=': [woodFloor, 2], _: [stoneFloor, 3],
  K: [carpet, 1], B: [bridge, 2], D: [door, 1], X: [waste, 3], C: [caveFloor, 2], '^': [stairs, 1],
  T: [tree, 2], t: [deadTree, 2], '~': [water, 4], '#': [stoneWall, 3], H: [woodWall, 2], R: [roof, 2],
  M: [mountain, 2], W: [castleWall, 3], L: [lava, 2], P: [pillar, 1], A: [altar, 1], c: [counter, 1],
  b: [bookshelf, 3], f: [fence, 2], w: [well, 1], ' ': [voidTile, 1],
};

// ---------------------------------------------------------------
// 캐시
// ---------------------------------------------------------------
const cache = new Map();
function makeCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  return c;
}

export function tileCanvas(ch, v = 0, f = 0) {
  const p = PAINTERS[ch] || PAINTERS['.'];
  v = v % p[1];
  const key = `${ch}|${v}|${f}`;
  let c = cache.get(key);
  if (!c) {
    c = makeCanvas(TILE, TILE);
    const g = c.getContext('2d');
    try { p[0](g, v, f); } catch (e) { console.warn('[field] 타일 그리기 실패', ch, e); }
    cache.set(key, c);
  }
  return c;
}

// ---------------------------------------------------------------
// 맵 레이어
// ---------------------------------------------------------------
export function tileAt(tiles, x, y) {
  if (y < 0 || y >= tiles.length) return ' ';
  const row = tiles[y];
  if (x < 0 || x >= row.length) return ' ';
  return row[x];
}

const WALLISH = new Set(['#', 'W']);

// 문맥(이웃 타일)에 따른 변형 선택
function variantFor(tiles, ch, x, y) {
  const n = (dx, dy) => tileAt(tiles, x + dx, y + dy);
  const h = hash2(x, y, ch.charCodeAt(0));
  switch (ch) {
    case '#': case 'W': {
      const below = n(0, 1);
      if (WALLISH.has(below) || below === ' ' || below === 'R') return 1; // 윗면
      return h < 0.12 ? 2 : 0;
    }
    case 'H': return h < 0.3 && n(0, 1) !== 'D' ? 1 : 0;
    case 'B': {
      const l = n(-1, 0), r = n(1, 0);
      return (l === 'B' || isWalkable(l)) && (r === 'B' || isWalkable(r)) && !(n(0, -1) === 'B' || n(0, 1) === 'B') ? 1 : 0;
    }
    case 'f': return (n(0, -1) === 'f' || n(0, 1) === 'f') && n(-1, 0) !== 'f' && n(1, 0) !== 'f' ? 1 : 0;
    case 'R': return 0;
    case 'T': return h < 0.12 ? 1 : 0;
    default: return Math.floor(h * 8);
  }
}

function underlayFor(tiles, ch, x, y) {
  for (const [dx, dy] of [[0, 1], [-1, 0], [1, 0], [0, -1]]) {
    const c = tileAt(tiles, x + dx, y + dy);
    if (isWalkable(c) && c !== 'D' && c !== '^' && c !== 'B') return c === 'F' ? '.' : c;
  }
  return DEFAULT_UNDER[ch] || '.';
}

// 가장자리 장식(정적 레이어에 한 번만)
function drawEdges(g, tiles, ch, x, y, px, py) {
  const n = (dx, dy) => tileAt(tiles, x + dx, y + dy);
  if (ch === 'R') {
    if (n(0, 1) !== 'R') { R(g, px, py + 27, 32, 5, '#6a221e'); R(g, px, py + 27, 32, 1, '#4a1512'); }
    if (n(0, -1) !== 'R') { R(g, px, py, 32, 3, '#e07a68'); R(g, px, py + 3, 32, 1, '#86302a'); }
  } else if (ch === 'K') {
    if (n(-1, 0) !== 'K') R(g, px + 2, py, 2, 32, '#e0b040');
    if (n(1, 0) !== 'K') R(g, px + 28, py, 2, 32, '#e0b040');
    if (n(0, -1) !== 'K') R(g, px, py + 2, 32, 2, '#e0b040');
    if (n(0, 1) !== 'K') R(g, px, py + 28, 32, 2, '#e0b040');
  } else if (WALLISH.has(ch)) {
    const top = WALLISH.has(n(0, 1)) || n(0, 1) === ' ' || n(0, 1) === 'R';
    if (!top && WALLISH.has(n(0, -1))) { /* 벽면 위는 윗면 */ }
    if (!top) R(g, px, py + 31, 32, 1, 'rgba(0,0,0,0.35)');
    if (top) {
      if (!WALLISH.has(n(-1, 0)) && n(-1, 0) !== ' ') R(g, px, py, 2, 32, 'rgba(255,255,255,0.12)');
      if (!WALLISH.has(n(1, 0)) && n(1, 0) !== ' ') R(g, px + 30, py, 2, 32, 'rgba(0,0,0,0.3)');
    }
  } else if (isWalkable(ch)) {
    // 벽/지붕 아래 그림자
    const up = n(0, -1);
    if (WALLISH.has(up) || up === 'H' || up === 'b' || up === 'M') R(g, px, py, 32, 4, 'rgba(0,0,0,0.18)');
  }
}

// 애니메이션 타일의 가장자리 비트: 1=위,2=아래,4=왼쪽,8=오른쪽 (같은 종류가 아닐 때)
function edgeMask(tiles, ch, x, y) {
  const same = (c) => c === ch || (ch === '~' && (c === 'B' || c === ' ')) || (ch === 'L' && c === ' ');
  let m = 0;
  if (!same(tileAt(tiles, x, y - 1))) m |= 1;
  if (!same(tileAt(tiles, x, y + 1))) m |= 2;
  if (!same(tileAt(tiles, x - 1, y))) m |= 4;
  if (!same(tileAt(tiles, x + 1, y))) m |= 8;
  return m;
}

export function buildMapLayer(tiles) {
  const h = tiles.length;
  const w = h ? tiles[0].length : 0;
  const canvas = makeCanvas(Math.max(1, w * TILE), Math.max(1, h * TILE));
  const g = canvas.getContext('2d');
  g.imageSmoothingEnabled = false;
  const animated = [];
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const ch = tileAt(tiles, x, y);
      const px = x * TILE, py = y * TILE;
      const v = variantFor(tiles, ch, x, y);
      if (ANIM[ch]) {
        animated.push({ x, y, ch, v, mask: edgeMask(tiles, ch, x, y) });
        continue;
      }
      if (OVERLAY.has(ch)) {
        const u = underlayFor(tiles, ch, x, y);
        g.drawImage(tileCanvas(u, variantFor(tiles, u, x, y), 0), px, py);
      }
      g.drawImage(tileCanvas(ch, v, 0), px, py);
      drawEdges(g, tiles, ch, x, y, px, py);
    }
  }
  return { canvas, animated, w, h };
}

// 애니메이션 타일은 매 프레임 보이는 것만 그린다
export function drawAnimatedTiles(ctx, layer, camX, camY, viewW, viewH, t) {
  const x0 = Math.floor(camX / TILE) - 1, y0 = Math.floor(camY / TILE) - 1;
  const x1 = x0 + Math.ceil(viewW / TILE) + 2, y1 = y0 + Math.ceil(viewH / TILE) + 2;
  for (const a of layer.animated) {
    if (a.x < x0 || a.x > x1 || a.y < y0 || a.y > y1) continue;
    const an = ANIM[a.ch];
    const f = (Math.floor(t / an.rate) + a.x + a.y * 2) % an.frames;
    const px = a.x * TILE - camX, py = a.y * TILE - camY;
    ctx.drawImage(tileCanvas(a.ch, a.v, f), px, py);
    if (!a.mask) continue;
    if (a.ch === '~') {
      const foam = Math.sin(t * 2 + a.x + a.y) > 0 ? '#d0e8ff' : '#a9d0fb';
      if (a.mask & 1) { R(ctx, px, py, 32, 3, foam); R(ctx, px, py + 3, 32, 1, '#2a5fa8'); }
      if (a.mask & 2) R(ctx, px, py + 30, 32, 2, '#a9d0fb');
      if (a.mask & 4) R(ctx, px, py, 2, 32, '#a9d0fb');
      if (a.mask & 8) R(ctx, px + 30, py, 2, 32, '#a9d0fb');
    } else if (a.ch === 'L') {
      if (a.mask & 1) R(ctx, px, py, 32, 3, '#4a1a10');
      if (a.mask & 2) R(ctx, px, py + 29, 32, 3, '#4a1a10');
      if (a.mask & 4) R(ctx, px, py, 3, 32, '#4a1a10');
      if (a.mask & 8) R(ctx, px + 29, py, 3, 32, '#4a1a10');
    }
  }
}
