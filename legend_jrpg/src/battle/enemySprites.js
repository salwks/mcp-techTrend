// 적 그래픽: 캔버스 도형으로 저해상도(½ 크기) 스프라이트를 그려 캐시하고, 2배로 확대해 도트 느낌을 낸다.
// getSprite(key, palette, frame, white) → { canvas, w, h }  (w/h는 저해상도 픽셀, 화면에는 ×2)
const OUT = '#1b1024';
const cache = new Map();

// ---------- 그리기 도우미 ----------
function el(c, x, y, rx, ry, fill, stroke = OUT, lw = 1) {
  c.beginPath();
  c.ellipse(x, y, Math.max(0.5, rx), Math.max(0.5, ry), 0, 0, Math.PI * 2);
  if (fill) { c.fillStyle = fill; c.fill(); }
  if (stroke) { c.strokeStyle = stroke; c.lineWidth = lw; c.stroke(); }
}
function poly(c, pts, fill, stroke = OUT, lw = 1) {
  c.beginPath();
  c.moveTo(pts[0], pts[1]);
  for (let i = 2; i < pts.length; i += 2) c.lineTo(pts[i], pts[i + 1]);
  c.closePath();
  if (fill) { c.fillStyle = fill; c.fill(); }
  if (stroke) { c.strokeStyle = stroke; c.lineWidth = lw; c.stroke(); }
}
function rect(c, x, y, w, h, fill, stroke = OUT) {
  c.fillStyle = fill;
  c.fillRect(x, y, w, h);
  if (stroke) { c.strokeStyle = stroke; c.lineWidth = 1; c.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1); }
}
function line(c, pts, color, lw = 1) {
  c.beginPath();
  c.moveTo(pts[0], pts[1]);
  for (let i = 2; i < pts.length; i += 2) c.lineTo(pts[i], pts[i + 1]);
  c.strokeStyle = color; c.lineWidth = lw; c.lineCap = 'round'; c.stroke();
}
function px(c, x, y, color, w = 1, h = 1) { c.fillStyle = color; c.fillRect(x, y, w, h); }
function eye(c, x, y, r, iris = '#000', white = '#fff') {
  el(c, x, y, r, r, white, OUT);
  el(c, x + r * 0.2, y + r * 0.1, r * 0.5, r * 0.55, iris, null);
  px(c, Math.round(x - r * 0.3), Math.round(y - r * 0.5), '#fff');
}
function glowEye(c, x, y, r, color) {
  c.save();
  c.shadowColor = color; c.shadowBlur = 4;
  el(c, x, y, r, r * 0.8, color, null);
  c.restore();
  px(c, Math.round(x), Math.round(y - r * 0.4), '#fff');
}
function grad(c, x0, y0, x1, y1, stops) {
  const g = c.createLinearGradient(x0, y0, x1, y1);
  stops.forEach((s, i) => g.addColorStop(i / (stops.length - 1), s));
  return g;
}
function wing(c, x, y, dir, span, drop, color, stroke = OUT, ribs = 3) {
  // 박쥐형 날개. dir: -1 왼쪽, 1 오른쪽
  const pts = [x, y, x + dir * span * 0.45, y - drop, x + dir * span, y - drop * 0.6];
  for (let i = ribs; i >= 1; i--) {
    const k = i / ribs;
    pts.push(x + dir * span * k * 0.95, y + drop * 0.35 + (i % 2) * 2);
    if (i > 1) pts.push(x + dir * span * (k - 0.5 / ribs), y + drop * 0.1);
  }
  pts.push(x, y + drop * 0.3);
  poly(c, pts, color, stroke);
  for (let i = 1; i <= ribs; i++) line(c, [x, y, x + dir * span * (i / ribs) * 0.95, y + drop * 0.35], 'rgba(0,0,0,0.35)');
}

// ---------- 팔레트 ----------
const PAL = {
  slime: { base: { a: '#4aa3ff', b: '#2a6fd6', h: '#bfe6ff' }, red: { a: '#ff6a5a', b: '#c8322c', h: '#ffd0c4' } },
  goblin: { base: { skin: '#6cbf4a', dark: '#3f8a2c', cloth: '#8a5a32', club: '#9b6b3c' }, warrior: { skin: '#c9784a', dark: '#8f4a28', cloth: '#555c6e', club: '#b8bec8' } },
  skeleton: { base: { bone: '#ece6d2', shade: '#b3a98c', metal: '#8d97a8', cloth: '#6b4a3a' }, knight: { bone: '#ddd6c0', shade: '#a39a80', metal: '#3d4658', cloth: '#6a1f2e' } },
  dark_knight: { base: { armor: '#3a3450', hi: '#6a6490', trim: '#b89a4a', eye: '#ff4040', cape: '#6a1a2a' }, armor: { armor: '#5c7a7e', hi: '#9cc3c4', trim: '#d8d0a0', eye: '#5affd0', cape: '#2a3a5a' } },
};
function pal(key, name) {
  const p = PAL[key];
  if (!p) return {};
  return p[name] || p.base;
}

// ---------- 스프라이트 정의: [w, h, draw(c, w, h, p, f)] ----------
const DEFS = {
  slime: [32, 26, (c, w, h, p, f) => {
    const sq = f ? 1 : 0;
    el(c, 16, 25, 13, 2, 'rgba(0,0,0,0)', null);
    poly(c, [16, 2 + sq, 22, 9 + sq, 28, 15, 29, 21, 25, 25, 7, 25, 3, 21, 4, 15, 10, 9 + sq], p.a);
    poly(c, [16, 4 + sq, 11, 10 + sq, 7, 16, 8, 19, 12, 12], p.h, null);
    poly(c, [29, 21, 25, 25, 7, 25, 3, 21, 16, 23], p.b, null);
    eye(c, 12, 15, 2.6); eye(c, 20, 15, 2.6);
    line(c, [12, 20, 16, 22, 20, 20], OUT);
    px(c, 14, 21, '#ff5a7a', 4, 1);
  }],
  wolf: [48, 34, (c, w, h, p, f) => {
    const g = '#8a8f9e', d = '#5a5f70', l = '#c8ccd8';
    poly(c, [30, 18, 44, 14, 47, 8, 45, 20, 38, 22], d); // 꼬리
    el(c, 28, 20, 14, 8, g);
    rect(c, 18, 24, 4, 9, d); rect(c, 34, 24, 4, 9, d); rect(c, 23, 25, 4, 8, g); rect(c, 30, 25, 4, 8, g);
    el(c, 12, 15, 9, 8, g);
    poly(c, [5, 8, 7, 1, 11, 7], g); poly(c, [13, 7, 16, 0, 18, 8], g);
    poly(c, [2, 15, 0, 20, 8, 21, 10, 17], l);
    px(c, 0, 16, OUT, 2, 2);
    glowEye(c, 9, 13, 1.6, '#ffd040'); glowEye(c, 15, 13, 1.6, '#ffd040');
    poly(c, [3, 21, 4, 23, 5, 21], '#fff', null); poly(c, [7, 21, 8, 23, 9, 21], '#fff', null);
    el(c, 26, 22, 8, 3, l, null);
  }],
  goblin: [34, 40, (c, w, h, p, f) => {
    const arm = f ? 1 : 0;
    rect(c, 12, 30, 4, 9, p.dark); rect(c, 19, 30, 4, 9, p.dark);
    poly(c, [9, 20, 25, 20, 27, 33, 7, 33], p.cloth);
    el(c, 17, 22, 8, 7, p.skin);
    poly(c, [2, 10, 9, 13, 8, 17], p.skin); poly(c, [32, 10, 25, 13, 26, 17], p.skin);
    el(c, 17, 13, 8, 7, p.skin);
    eye(c, 14, 12, 2, '#c00'); eye(c, 20, 12, 2, '#c00');
    line(c, [13, 17, 17, 18, 21, 17], OUT);
    px(c, 14, 17, '#fff'); px(c, 20, 17, '#fff');
    line(c, [27, 22, 31, 14 - arm * 2], p.club, 3);
    el(c, 31, 11 - arm * 2, 3, 4, p.club);
    el(c, 7, 24, 2.5, 2.5, p.skin);
  }],
  mushroom: [30, 34, (c, w, h, p, f) => {
    rect(c, 10, 18, 11, 14, '#f0e6cc');
    el(c, 15, 32, 7, 2, '#d8caa8', null);
    poly(c, [2, 18, 5, 8, 15, 2, 25, 8, 28, 18], '#9a3fbf');
    el(c, 8, 12, 2, 2, '#f6e8ff', null); el(c, 16, 7, 3, 2, '#f6e8ff', null); el(c, 22, 13, 2, 2, '#f6e8ff', null);
    line(c, [2, 18, 28, 18], OUT);
    px(c, 12, 22, OUT, 2, 3); px(c, 17, 22, OUT, 2, 3);
    line(c, [12, 28, 15, 27 + (f ? 1 : 0), 18, 28], OUT);
  }],
  bee: [34, 30, (c, w, h, p, f) => {
    const wy = f ? -3 : 0;
    el(c, 13, 6 + wy, 7, 5, 'rgba(220,240,255,0.8)'); el(c, 22, 6 + wy, 7, 5, 'rgba(220,240,255,0.8)');
    el(c, 19, 17, 11, 8, '#ffcc30');
    rect(c, 14, 10, 3, 14, OUT, null); rect(c, 21, 10, 3, 14, OUT, null);
    poly(c, [29, 16, 34, 18, 29, 20], '#333');
    el(c, 7, 15, 6, 6, '#3a3030');
    glowEye(c, 5, 14, 1.6, '#ff3030'); glowEye(c, 9, 14, 1.6, '#ff3030');
    line(c, [5, 9, 3, 4], OUT); line(c, [9, 9, 10, 4], OUT);
  }],
  goblin_chief: [60, 66, (c, w, h, p, f) => {
    const skin = '#5aa83e', dark = '#34702a';
    rect(c, 20, 50, 7, 15, dark); rect(c, 33, 50, 7, 15, dark);
    poly(c, [12, 30, 48, 30, 52, 54, 8, 54], '#7a3a24');
    rect(c, 12, 44, 36, 5, '#3a2418');
    rect(c, 26, 44, 8, 5, '#ffcc40');
    el(c, 30, 32, 16, 12, skin);
    el(c, 30, 30, 10, 6, '#c9784a', null);
    poly(c, [2, 12, 14, 18, 12, 24], skin); poly(c, [58, 12, 46, 18, 48, 24], skin);
    el(c, 30, 20, 13, 11, skin);
    poly(c, [18, 12, 20, 2, 25, 9, 30, 0, 35, 9, 40, 2, 42, 12], '#ffcc40');
    px(c, 29, 5, '#ff4040', 3, 3);
    eye(c, 25, 19, 2.6, '#c00'); eye(c, 35, 19, 2.6, '#c00');
    line(c, [22, 15, 27, 17], OUT, 1.5); line(c, [38, 15, 33, 17], OUT, 1.5);
    poly(c, [23, 25, 37, 25, 34, 29, 26, 29], '#5a1a1a');
    poly(c, [25, 25, 26, 28, 27, 25], '#fff', null); poly(c, [33, 25, 34, 28, 35, 25], '#fff', null);
    const ax = f ? -1 : 0;
    line(c, [50, 40, 55, 8 + ax], '#7a5030', 3);
    poly(c, [52, 6 + ax, 60, 2 + ax, 60, 18 + ax, 54, 14 + ax], '#c0c6d0');
    el(c, 10, 38, 4, 4, skin);
  }],
  treant: [92, 104, (c, w, h, p, f) => {
    const bark = '#6b4a2e', dark = '#48301c', leaf = '#3f8a3a', leaf2 = '#2c6a2c';
    const sway = f ? 1 : -1;
    el(c, 46 + sway, 22, 36, 20, leaf2); el(c, 22 + sway, 30, 20, 14, leaf); el(c, 70 + sway, 30, 20, 14, leaf);
    el(c, 46 + sway, 14, 24, 13, leaf);
    for (const [x, y] of [[30, 20], [55, 12], [66, 28], [40, 32], [20, 34]]) el(c, x + sway, y, 3, 2, '#7ac860', null);
    poly(c, [30, 40, 62, 40, 66, 96, 26, 96], bark);
    line(c, [36, 48, 38, 90], dark); line(c, [56, 52, 55, 92], dark); line(c, [46, 60, 47, 94], dark);
    poly(c, [30, 50, 8, 36 + sway * 2, 4, 42 + sway * 2, 28, 60], bark);
    poly(c, [62, 50, 84, 36 - sway * 2, 88, 42 - sway * 2, 64, 60], bark);
    poly(c, [26, 92, 10, 103, 34, 98], dark); poly(c, [66, 92, 84, 103, 58, 98], dark); poly(c, [40, 96, 46, 103, 52, 96], dark);
    el(c, 38, 58, 5, 4, '#1a0e08'); el(c, 55, 58, 5, 4, '#1a0e08');
    glowEye(c, 38, 58, 2.2, '#ffd040'); glowEye(c, 55, 58, 2.2, '#ffd040');
    line(c, [32, 51, 42, 54], dark, 2); line(c, [61, 51, 51, 54], dark, 2);
    poly(c, [36, 70, 58, 70, 54, 80, 40, 80], '#1a0e08');
    for (let i = 0; i < 4; i++) poly(c, [39 + i * 5, 70, 41 + i * 5, 74, 43 + i * 5, 70], '#d8c8a0', null);
  }],
  boar: [50, 34, (c, w, h, p, f) => {
    const fur = '#8a5a3a', dark = '#5a3620';
    el(c, 30, 18, 17, 11, fur);
    poly(c, [22, 8, 26, 3, 30, 8, 34, 4, 38, 9], dark);
    rect(c, 20, 25, 5, 9, dark); rect(c, 38, 25, 5, 9, dark);
    el(c, 12, 19, 10, 8, fur);
    poly(c, [8, 11, 10, 5, 14, 11], fur);
    el(c, 4, 22, 4, 3.5, '#d89a80');
    px(c, 2, 21, OUT); px(c, 5, 21, OUT);
    poly(c, [7, 24, 4, 17, 9, 23], '#fff'); poly(c, [11, 25, 9, 18, 13, 24], '#fff');
    glowEye(c, 11, 15, 1.5, '#ff4030');
    line(c, [47, 16, 50, 12 + (f ? 2 : 0)], dark);
  }],
  bird: [42, 40, (c, w, h, p, f) => {
    const body = '#e8a040', dark = '#b06a20';
    const wy = f ? -6 : 0;
    poly(c, [22, 20, 40, 8 + wy, 38, 22], dark); poly(c, [18, 20, 2, 8 + wy, 4, 22], dark);
    el(c, 20, 24, 12, 11, body);
    el(c, 20, 28, 7, 6, '#ffe0a0', null);
    poly(c, [16, 17, 28, 20, 16, 23], '#ffd030');
    poly(c, [16, 20, 30, 21, 16, 23], '#d09020');
    eye(c, 15, 15, 2.5); eye(c, 23, 15, 2.5);
    line(c, [16, 34, 14, 39], '#d09020', 2); line(c, [24, 34, 26, 39], '#d09020', 2);
    poly(c, [18, 12, 20, 5, 23, 12], '#e84030');
  }],
  bat: [46, 28, (c, w, h, p, f) => {
    const m = '#4a3a6a';
    const d = f ? 8 : 2;
    wing(c, 18, 12, -1, 17, d, m); wing(c, 28, 12, 1, 17, d, m);
    el(c, 23, 14, 7, 7, '#3a2a50');
    poly(c, [17, 9, 18, 2, 21, 8], '#3a2a50'); poly(c, [29, 9, 28, 2, 25, 8], '#3a2a50');
    glowEye(c, 20, 13, 1.6, '#ff3050'); glowEye(c, 26, 13, 1.6, '#ff3050');
    poly(c, [21, 17, 22, 20, 23, 17], '#fff', null); poly(c, [24, 17, 25, 20, 26, 17], '#fff', null);
  }],
  crab: [52, 34, (c, w, h, p, f) => {
    const sh = '#c8503a', dk = '#8a2a20';
    const cl = f ? 2 : 0;
    for (let i = 0; i < 3; i++) { line(c, [16 - i * 3, 24, 8 - i * 3, 32], dk, 2); line(c, [36 + i * 3, 24, 44 + i * 3, 32], dk, 2); }
    el(c, 26, 20, 16, 10, sh);
    el(c, 26, 17, 10, 4, '#e8806a', null);
    line(c, [21, 12, 20, 6], dk, 2); line(c, [31, 12, 32, 6], dk, 2);
    eye(c, 20, 5, 2.2); eye(c, 32, 5, 2.2);
    el(c, 7, 12 - cl, 7, 6, sh); poly(c, [2, 8 - cl, 6, 12 - cl, 1, 14 - cl], '#2a1010');
    el(c, 45, 12 - cl, 7, 6, sh); poly(c, [50, 8 - cl, 46, 12 - cl, 51, 14 - cl], '#2a1010');
    line(c, [21, 24, 26, 26, 31, 24], dk);
  }],
  skeleton: [36, 52, (c, w, h, p, f) => {
    const knight = p.cloth === '#6a1f2e';
    line(c, [14, 36, 12, 50], p.bone, 2.5); line(c, [22, 36, 24, 50], p.bone, 2.5);
    if (knight) poly(c, [8, 20, 28, 20, 30, 38, 6, 38], p.metal);
    else {
      rect(c, 17, 20, 2, 16, p.bone, null);
      for (let i = 0; i < 4; i++) line(c, [11, 22 + i * 3, 25, 22 + i * 3], p.bone, 1.5);
      poly(c, [11, 34, 25, 34, 23, 38, 13, 38], p.cloth);
    }
    line(c, [9, 22, 5, 32], p.bone, 2); line(c, [27, 22, 30, 30], p.bone, 2);
    const sw = f ? 1 : 0;
    line(c, [30, 30, 34, 6 + sw], '#c8ccd8', 2); line(c, [27, 27, 33, 29], '#806030', 2);
    el(c, 6, 32, 6, 7, knight ? '#5a1a26' : p.metal);
    el(c, 18, 11, 8, 8, p.bone);
    rect(c, 13, 16, 10, 4, p.shade, null);
    el(c, 15, 11, 2.3, 2.6, '#000', null); el(c, 21, 11, 2.3, 2.6, '#000', null);
    glowEye(c, 15, 11, 1, knight ? '#ff4040' : '#ffd040'); glowEye(c, 21, 11, 1, knight ? '#ff4040' : '#ffd040');
    for (let i = 0; i < 4; i++) px(c, 14 + i * 2, 17, OUT, 1, 2);
    if (knight) {
      poly(c, [9, 9, 18, 1, 27, 9, 27, 12, 9, 12], p.metal);
      poly(c, [18, 1, 20, -3, 22, 2], '#c03040');
    }
  }],
  jellyfish: [36, 44, (c, w, h, p, f) => {
    const t = f ? 2 : -2;
    for (let i = 0; i < 5; i++) {
      const x = 8 + i * 5;
      line(c, [x, 18, x + t, 26, x - t, 34, x + t * 0.5, 42], 'rgba(200,120,255,0.9)', 2);
    }
    poly(c, [3, 20, 5, 8, 18, 2, 31, 8, 33, 20], 'rgba(190,110,250,0.9)');
    el(c, 13, 8, 4, 2, 'rgba(255,255,255,0.7)', null);
    eye(c, 13, 14, 2); eye(c, 23, 14, 2);
    line(c, [15, 18, 18, 19, 21, 18], OUT);
  }],
  sahuagin: [40, 54, (c, w, h, p, f) => {
    const sk = '#3a9a8a', dk = '#206a5e', bel = '#a8e0c0';
    rect(c, 13, 40, 5, 13, dk); rect(c, 22, 40, 5, 13, dk);
    el(c, 20, 32, 10, 11, sk); el(c, 20, 34, 6, 8, bel, null);
    poly(c, [20, 14, 28, 22, 20, 30, 12, 22], dk);
    el(c, 20, 14, 9, 9, sk);
    poly(c, [11, 10, 20, 0, 29, 10, 20, 7], '#e04a40');
    glowEye(c, 16, 13, 1.8, '#ffe040'); glowEye(c, 24, 13, 1.8, '#ffe040');
    poly(c, [14, 18, 26, 18, 24, 22, 16, 22], '#1a2a28');
    for (let i = 0; i < 4; i++) poly(c, [15 + i * 3, 18, 16 + i * 3, 20, 17 + i * 3, 18], '#fff', null);
    const tr = f ? 1 : 0;
    line(c, [33, 50, 34, 8 + tr], '#b08040', 2);
    poly(c, [30, 10 + tr, 31, 2 + tr, 32, 8 + tr, 34, 0 + tr, 36, 8 + tr, 37, 2 + tr, 38, 10 + tr], '#d0d6e0');
    el(c, 31, 30, 3, 3, sk);
  }],
  sea_serpent: [124, 116, (c, w, h, p, f) => {
    const sk = '#2a7a9a', dk = '#1a4a6a', bel = '#9ad8d0', fin = '#e0604a';
    const b = f ? 1 : 0;
    // 물결
    c.fillStyle = 'rgba(80,160,220,0.55)';
    c.fillRect(0, 100, 124, 16);
    // 몸통 고리
    el(c, 22, 96, 18, 12, sk); el(c, 102, 96, 18, 12, sk);
    el(c, 22, 92, 10, 4, bel, null); el(c, 102, 92, 10, 4, bel, null);
    poly(c, [8, 90, 14, 78, 20, 88, 26, 76, 32, 88], fin); poly(c, [92, 88, 98, 76, 104, 88, 110, 78, 116, 90], fin);
    // 목
    poly(c, [50, 110, 44, 70, 52, 40, 72, 36, 80, 70, 76, 110], sk);
    poly(c, [56, 108, 54, 72, 60, 46, 66, 46, 68, 72, 68, 108], bel, null);
    for (let i = 0; i < 6; i++) line(c, [55, 60 + i * 8, 69, 60 + i * 8], 'rgba(40,110,120,0.6)');
    // 등지느러미
    poly(c, [72, 40, 86, 34, 80, 48, 90, 50, 80, 62, 88, 68, 78, 76], fin);
    // 머리
    poly(c, [36, 26 + b, 50, 8 + b, 76, 6 + b, 88, 20 + b, 84, 36 + b, 60, 44 + b, 40, 40 + b], sk);
    poly(c, [36, 26 + b, 60, 30 + b, 84, 36 + b, 60, 44 + b, 40, 40 + b], dk);
    poly(c, [40, 30 + b, 80, 34 + b, 78, 36 + b, 42, 34 + b], '#3a0a1a', null);
    for (let i = 0; i < 7; i++) poly(c, [44 + i * 5, 30 + b, 46 + i * 5, 34 + b, 48 + i * 5, 30 + b], '#fff', null);
    poly(c, [50, 8 + b, 44, -2, 58, 6 + b], fin); poly(c, [68, 6 + b, 70, -4, 78, 8 + b], fin);
    el(c, 58, 18 + b, 5, 4, '#1a0a10'); el(c, 76, 18 + b, 5, 4, '#1a0a10');
    glowEye(c, 58, 18 + b, 3, '#ffe040'); glowEye(c, 76, 18 + b, 3, '#ffe040');
    line(c, [52, 12 + b, 62, 14 + b], dk, 2); line(c, [82, 12 + b, 72, 14 + b], dk, 2);
  }],
  gargoyle: [54, 54, (c, w, h, p, f) => {
    const st = '#8a8a96', dk = '#5a5a66', hi = '#b4b4c0';
    const d = f ? 4 : 0;
    wing(c, 18, 18, -1, 18, 10 + d, dk); wing(c, 36, 18, 1, 18, 10 + d, dk);
    el(c, 27, 34, 12, 12, st);
    el(c, 27, 36, 6, 7, hi, null);
    rect(c, 16, 44, 8, 9, st); rect(c, 30, 44, 8, 9, st);
    poly(c, [14, 52, 12, 54, 26, 54, 24, 52], dk); poly(c, [28, 52, 28, 54, 42, 54, 40, 52], dk);
    el(c, 27, 17, 9, 8, st);
    poly(c, [19, 12, 14, 2, 23, 10], hi); poly(c, [35, 12, 40, 2, 31, 10], hi);
    glowEye(c, 23, 16, 1.8, '#ff5030'); glowEye(c, 31, 16, 1.8, '#ff5030');
    poly(c, [22, 21, 32, 21, 30, 25, 24, 25], '#2a2a30');
    poly(c, [23, 21, 24, 24, 25, 21], '#fff', null); poly(c, [29, 21, 30, 24, 31, 21], '#fff', null);
  }],
  ghost: [38, 46, (c, w, h, p, f) => {
    const s = f ? 2 : 0;
    c.globalAlpha = 0.9;
    poly(c, [6, 22, 8, 8, 19, 2, 30, 8, 32, 22, 34, 34, 30, 40 - s, 26, 36, 22, 44 - s, 16, 38, 11, 43 + s, 8, 36, 3, 38], '#dfe6ff');
    c.globalAlpha = 1;
    el(c, 13, 9, 3, 2, '#fff', null);
    el(c, 14, 18, 3, 4, '#1a1030', null); el(c, 24, 18, 3, 4, '#1a1030', null);
    glowEye(c, 14, 18, 1.2, '#60c0ff'); glowEye(c, 24, 18, 1.2, '#60c0ff');
    el(c, 19, 27, 3, 4 + s, '#1a1030', null);
    line(c, [6, 24, 1, 28 + s], '#dfe6ff', 3); line(c, [32, 24, 37, 28 - s], '#dfe6ff', 3);
  }],
  book: [38, 34, (c, w, h, p, f) => {
    const fl = f ? 2 : 0;
    poly(c, [2, 10 - fl, 19, 14, 36, 10 - fl, 36, 30, 19, 32, 2, 30], '#6a2a8a');
    poly(c, [4, 8 - fl, 19, 12, 19, 29, 4, 26], '#f6eed8');
    poly(c, [34, 8 - fl, 19, 12, 19, 29, 34, 26], '#e8dcc0');
    for (let i = 0; i < 4; i++) { line(c, [7, 14 + i * 3, 16, 16 + i * 3], '#a09070'); line(c, [22, 16 + i * 3, 31, 14 + i * 3], '#a09070'); }
    el(c, 19, 20, 5, 4, '#fff');
    el(c, 19, 20, 2.5, 3, '#c02060', null);
    px(c, 18, 18, '#fff');
    for (const [x, y] of [[3, 4], [34, 3], [19, 1]]) px(c, x, y + fl, '#e0b0ff', 2, 2);
  }],
  golem: [62, 68, (c, w, h, p, f) => {
    const st = '#9a8a74', dk = '#6a5c4a', hi = '#c0b098', moss = '#6a9a4a';
    rect(c, 16, 50, 12, 17, dk); rect(c, 34, 50, 12, 17, dk);
    poly(c, [10, 22, 52, 22, 54, 52, 8, 52], st);
    line(c, [20, 30, 26, 40, 22, 48], dk); line(c, [42, 28, 38, 38], dk);
    el(c, 14, 24, 4, 2, moss, null); el(c, 46, 45, 3, 2, moss, null);
    const a = f ? 1 : 0;
    rect(c, 0, 24 + a, 10, 26, st); rect(c, 52, 24 + a, 10, 26, st);
    rect(c, 0, 46 + a, 11, 9, dk); rect(c, 51, 46 + a, 11, 9, dk);
    rect(c, 20, 6, 22, 18, st);
    rect(c, 22, 8, 18, 3, hi, null);
    rect(c, 24, 13, 14, 4, '#2a2018', null);
    glowEye(c, 27, 15, 1.8, '#40e0ff'); glowEye(c, 35, 15, 1.8, '#40e0ff');
    px(c, 30, 30, '#40e0ff', 3, 3);
  }],
  lich: [96, 112, (c, w, h, p, f) => {
    const robe = '#3a2458', dk = '#22123a', trim = '#c8a040', bone = '#e8e2cc';
    const fl = f ? 1 : 0;
    // 망토
    poly(c, [48, 26, 14, 50, 6, 108, 30, 100, 48, 110, 66, 100, 90, 108, 82, 50], dk);
    // 로브
    poly(c, [48, 30, 28, 44, 22, 104, 74, 104, 68, 44], robe);
    line(c, [48, 44, 48, 104], trim, 2);
    poly(c, [22, 104, 30, 96, 38, 104, 46, 96, 54, 104, 62, 96, 70, 104, 74, 104], dk, null);
    poly(c, [34, 40, 48, 54, 62, 40, 58, 36, 48, 44, 38, 36], trim);
    // 팔·지팡이
    line(c, [28, 50, 14, 62], robe, 6); el(c, 13, 63, 3, 3, bone);
    line(c, [80, 104, 82, 14], '#5a3a20', 3);
    el(c, 82, 12, 6, 6, '#50ffb0');
    c.save(); c.shadowColor = '#50ffb0'; c.shadowBlur = 8; el(c, 82, 12, 3 + fl, 3 + fl, '#d0fff0', null); c.restore();
    poly(c, [76, 16, 82, 4, 88, 16, 82, 12], trim);
    line(c, [68, 50, 80, 58], robe, 6); el(c, 80, 58, 3, 3, bone);
    // 해골 머리 + 두건
    poly(c, [30, 34, 36, 10, 48, 4, 60, 10, 66, 34, 58, 30, 38, 30], dk);
    el(c, 48, 22, 10, 11, bone);
    rect(c, 42, 28, 12, 6, '#c8c0a8', null);
    for (let i = 0; i < 5; i++) px(c, 43 + i * 2.4, 30, OUT, 1, 3);
    el(c, 44, 21, 3, 3.5, '#000', null); el(c, 52, 21, 3, 3.5, '#000', null);
    glowEye(c, 44, 21, 1.5 + fl * 0.3, '#60a0ff'); glowEye(c, 52, 21, 1.5 + fl * 0.3, '#60a0ff');
    poly(c, [47, 25, 48, 27, 49, 25], '#000', null);
    // 왕관
    poly(c, [38, 13, 40, 5, 43, 11, 48, 3, 53, 11, 56, 5, 58, 13], trim);
    px(c, 47, 7, '#ff3050', 2, 2);
  }],
  scorpion: [58, 38, (c, w, h, p, f) => {
    const sh = '#b0783a', dk = '#704a20';
    const t = f ? 2 : 0;
    for (let i = 0; i < 3; i++) { line(c, [22 + i * 5, 28, 16 + i * 5, 37], dk, 2); line(c, [30 + i * 5, 28, 36 + i * 5, 37], dk, 2); }
    // 꼬리
    line(c, [40, 26, 50, 22, 54, 12, 50, 4 + t, 44, 4 + t], sh, 4);
    poly(c, [44, 1 + t, 38, 5 + t, 44, 8 + t], '#e0e0a0');
    el(c, 30, 26, 14, 7, sh);
    for (let i = 0; i < 3; i++) line(c, [22 + i * 7, 20, 22 + i * 7, 32], dk);
    el(c, 14, 25, 7, 6, sh);
    glowEye(c, 11, 22, 1.4, '#ff3030'); glowEye(c, 16, 22, 1.4, '#ff3030');
    line(c, [9, 26, 3, 20], sh, 3); line(c, [11, 28, 5, 32], sh, 3);
    el(c, 3, 17, 4, 3, sh); el(c, 4, 33, 4, 3, sh);
    poly(c, [0, 14, 3, 17, 0, 19], '#2a1a0a', null);
  }],
  salamander: [60, 36, (c, w, h, p, f) => {
    const sk = '#e0582a', dk = '#a0301a', bel = '#ffc060';
    const fl = f ? 2 : 0;
    // 등의 불꽃
    for (let i = 0; i < 5; i++) {
      poly(c, [18 + i * 7, 16, 21 + i * 7, 4 - (i % 2 ? fl : -fl) + (i === 2 ? -3 : 0), 24 + i * 7, 16], i % 2 ? '#ffd040' : '#ff8a20', null);
    }
    line(c, [48, 22, 56, 18, 59, 10 + fl], sk, 4);
    el(c, 32, 22, 16, 7, sk);
    el(c, 32, 26, 12, 3, bel, null);
    rect(c, 20, 26, 4, 8, dk); rect(c, 40, 26, 4, 8, dk);
    el(c, 12, 20, 9, 6, sk);
    poly(c, [2, 20, 10, 18, 10, 24, 2, 23], sk);
    glowEye(c, 10, 17, 1.6, '#ffff60');
    line(c, [3, 22, 9, 22], OUT);
  }],
  wyvern: [66, 58, (c, w, h, p, f) => {
    const sk = '#4a8a5a', dk = '#2a5a3a', mem = '#7a4a6a';
    const d = f ? 8 : 0;
    wing(c, 26, 22, -1, 26, 14 + d, mem, OUT, 4); wing(c, 40, 22, 1, 26, 14 + d, mem, OUT, 4);
    line(c, [40, 44, 56, 50, 64, 44], sk, 4);
    poly(c, [62, 40, 66, 44, 62, 48], '#d0d0a0');
    el(c, 33, 36, 11, 10, sk);
    el(c, 33, 38, 6, 6, '#c8d8a0', null);
    rect(c, 25, 42, 5, 12, dk); rect(c, 36, 42, 5, 12, dk);
    line(c, [33, 28, 30, 16], sk, 6);
    el(c, 28, 12, 8, 6, sk);
    poly(c, [20, 12, 14, 16, 22, 17], sk);
    poly(c, [28, 7, 32, 0, 33, 8], '#d0d0a0');
    glowEye(c, 26, 10, 1.5, '#ffd040');
  }],
  ogre: [60, 74, (c, w, h, p, f) => {
    const sk = '#b09a6a', dk = '#806a44', cl = '#5a3a2a';
    rect(c, 18, 56, 10, 17, dk); rect(c, 32, 56, 10, 17, dk);
    poly(c, [14, 46, 46, 46, 48, 60, 12, 60], cl);
    el(c, 30, 38, 20, 16, sk);
    el(c, 30, 42, 12, 9, '#c8b488', null);
    el(c, 9, 40, 6, 12, sk); el(c, 51, 40, 6, 12, sk);
    const a = f ? 2 : 0;
    line(c, [54, 50, 58, 18 - a], '#6a4a2a', 4);
    el(c, 58, 14 - a, 5, 8, '#6a4a2a');
    for (let i = 0; i < 3; i++) px(c, 55 + i * 2, 10 + i * 3 - a, '#c8c8c8', 2, 2);
    el(c, 30, 17, 11, 10, sk);
    poly(c, [22, 10, 20, 2, 26, 8], '#e8e0c0'); poly(c, [38, 10, 40, 2, 34, 8], '#e8e0c0');
    eye(c, 26, 15, 2.4, '#800'); eye(c, 34, 15, 2.4, '#800');
    line(c, [22, 11, 28, 13], OUT, 1.5); line(c, [38, 11, 32, 13], OUT, 1.5);
    poly(c, [24, 21, 36, 21, 34, 25, 26, 25], '#3a1a1a');
    poly(c, [25, 25, 26, 20, 27, 25], '#fff', null); poly(c, [33, 25, 34, 20, 35, 25], '#fff', null);
  }],
  ghoul: [36, 50, (c, w, h, p, f) => {
    const sk = '#8ab87a', dk = '#5a7a4a', cl = '#5a4a5a';
    const s = f ? 1 : 0;
    rect(c, 12, 38, 5, 12, dk); rect(c, 20, 38, 5, 12, dk);
    poly(c, [8, 20, 28, 20, 30, 40, 26, 38, 22, 41, 16, 38, 12, 41, 6, 40], cl);
    line(c, [9, 23, 1, 30 + s], sk, 3); line(c, [27, 23, 35, 28 - s], sk, 3);
    el(c, 18, 12, 8, 9, sk);
    el(c, 15, 11, 2.5, 3, '#1a1a10', null); el(c, 21, 11, 2.5, 3, '#1a1a10', null);
    glowEye(c, 15, 11, 1, '#ff4020'); glowEye(c, 21, 11, 1, '#ff4020');
    poly(c, [14, 16, 22, 16, 21, 20, 15, 20], '#3a1a1a');
    px(c, 16, 16, '#e8e0c0'); px(c, 20, 16, '#e8e0c0');
    line(c, [11, 5, 13, 8], '#3a3a2a'); line(c, [24, 4, 23, 8], '#3a3a2a');
  }],
  black_dragon: [156, 134, (c, w, h, p, f) => {
    const sc = '#2a2436', dk = '#16121e', hi = '#4a4060', bel = '#6a4a3a', mem = '#3a1a2a';
    const d = f ? 6 : 0;
    // 날개
    wing(c, 58, 44, -1, 58, 30 + d, mem, OUT, 4);
    wing(c, 98, 44, 1, 58, 30 + d, mem, OUT, 4);
    line(c, [58, 44, 4, 16 - d], hi, 2); line(c, [98, 44, 152, 16 - d], hi, 2);
    // 꼬리
    poly(c, [100, 110, 132, 116, 150, 104, 154, 110, 136, 124, 98, 124], sc);
    poly(c, [150, 104, 156, 98, 154, 110], '#8a2a2a');
    // 몸통
    el(c, 78, 96, 34, 30, sc);
    el(c, 78, 102, 20, 22, bel);
    for (let i = 0; i < 5; i++) line(c, [62, 88 + i * 7, 94, 88 + i * 7], 'rgba(0,0,0,0.3)');
    // 다리
    poly(c, [48, 104, 40, 130, 60, 132, 62, 112], dk); poly(c, [108, 104, 116, 130, 96, 132, 94, 112], dk);
    for (let i = 0; i < 3; i++) { poly(c, [42 + i * 6, 130, 44 + i * 6, 134, 46 + i * 6, 130], '#e8e0c0', null); poly(c, [100 + i * 6, 130, 102 + i * 6, 134, 104 + i * 6, 130], '#e8e0c0', null); }
    // 목
    poly(c, [62, 76, 64, 46, 92, 46, 94, 76], sc);
    for (let i = 0; i < 4; i++) poly(c, [74 + (i % 2) * 4, 70 - i * 8, 78 + (i % 2) * 4, 62 - i * 8, 82 + (i % 2) * 4, 70 - i * 8], hi, null);
    // 머리
    poly(c, [52, 30, 62, 14, 94, 14, 104, 30, 98, 50, 58, 50], sc);
    poly(c, [58, 40, 98, 40, 94, 54, 62, 54], dk);
    poly(c, [62, 44, 94, 44, 90, 50, 66, 50], '#5a0a0a', null);
    for (let i = 0; i < 6; i++) poly(c, [64 + i * 5, 44, 66 + i * 5, 48, 68 + i * 5, 44], '#fff', null);
    c.save(); c.shadowColor = '#ff6020'; c.shadowBlur = 6; el(c, 78, 48, 6 + (f ? 1 : 0), 2, '#ff9030', null); c.restore();
    // 뿔
    poly(c, [60, 18, 42, 0, 66, 14], '#c8b890'); poly(c, [96, 18, 114, 0, 90, 14], '#c8b890');
    poly(c, [66, 14, 60, 6, 72, 12], '#a89870'); poly(c, [90, 14, 96, 6, 84, 12], '#a89870');
    el(c, 68, 28, 6, 4, '#1a0000'); el(c, 88, 28, 6, 4, '#1a0000');
    glowEye(c, 68, 28, 3, '#ff3020'); glowEye(c, 88, 28, 3, '#ff3020');
    line(c, [60, 22, 72, 25], hi, 2); line(c, [96, 22, 84, 25], hi, 2);
  }],
  dark_knight: [44, 62, (c, w, h, p, f) => {
    const s = f ? 1 : 0;
    poly(c, [8, 18, 36, 18, 40, 58, 4, 58], p.cape);
    rect(c, 13, 44, 7, 17, p.armor); rect(c, 24, 44, 7, 17, p.armor);
    poly(c, [10, 20, 34, 20, 32, 46, 12, 46], p.armor);
    poly(c, [14, 22, 30, 22, 28, 34, 16, 34], p.hi, null);
    line(c, [22, 22, 22, 44], p.trim);
    el(c, 9, 22, 6, 5, p.armor); el(c, 35, 22, 6, 5, p.armor);
    // 대검
    line(c, [38, 44, 40, 4 + s], '#c8d0e0', 3); line(c, [35, 40, 42, 40], p.trim, 2);
    // 방패
    poly(c, [0, 26, 12, 26, 12, 40, 6, 46, 0, 40], p.armor); px(c, 5, 31, p.trim, 3, 6);
    // 투구
    poly(c, [14, 6, 22, 0, 30, 6, 30, 18, 14, 18], p.armor);
    rect(c, 16, 10, 12, 3, '#0a0a10', null);
    glowEye(c, 19, 11, 1.2, p.eye); glowEye(c, 25, 11, 1.2, p.eye);
    poly(c, [22, 0, 20, -4, 30, -2, 26, 2], p.trim);
  }],
  imp: [36, 40, (c, w, h, p, f) => {
    const sk = '#d04040', dk = '#8a2020';
    const d = f ? 4 : 0;
    wing(c, 12, 16, -1, 12, 6 + d, '#5a1a3a'); wing(c, 24, 16, 1, 12, 6 + d, '#5a1a3a');
    line(c, [18, 30, 26, 36, 30, 32], dk, 1.5); poly(c, [30, 30, 33, 32, 30, 34], dk);
    el(c, 18, 24, 7, 8, sk);
    line(c, [14, 30, 13, 38], sk, 2.5); line(c, [22, 30, 23, 38], sk, 2.5);
    el(c, 18, 12, 7, 7, sk);
    poly(c, [12, 8, 9, 0, 15, 6], '#3a1a1a'); poly(c, [24, 8, 27, 0, 21, 6], '#3a1a1a');
    glowEye(c, 15, 11, 1.4, '#ffe040'); glowEye(c, 21, 11, 1.4, '#ffe040');
    line(c, [14, 15, 18, 17, 22, 15], OUT);
    line(c, [30, 38, 32, 6], '#4a3a3a', 1.5);
    line(c, [29, 8, 29, 4], '#c0c0c0'); line(c, [32, 6, 32, 1], '#c0c0c0'); line(c, [35, 8, 35, 4], '#c0c0c0'); line(c, [29, 8, 35, 8], '#c0c0c0');
  }],
  chimera: [72, 60, (c, w, h, p, f) => {
    const fur = '#c89a4a', dk = '#8a6420', mane = '#8a3a1a';
    const t = f ? 2 : 0;
    // 뱀 꼬리
    line(c, [56, 36, 66, 30, 68, 18, 62, 12 + t], '#4a8a3a', 4);
    el(c, 60, 10 + t, 4, 3, '#4a8a3a'); px(c, 58, 9 + t, '#ff3030');
    // 몸
    el(c, 42, 38, 22, 13, fur);
    rect(c, 26, 44, 7, 15, dk); rect(c, 52, 44, 7, 15, dk); rect(c, 34, 46, 6, 13, fur); rect(c, 46, 46, 6, 13, fur);
    // 염소 머리
    el(c, 46, 20, 6, 6, '#d8d0c0');
    poly(c, [44, 15, 48, 4, 50, 14], '#6a5a4a'); glowEye(c, 47, 20, 1.2, '#ff8030');
    // 사자 머리 + 갈기
    el(c, 20, 28, 16, 15, mane);
    for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2; poly(c, [20 + Math.cos(a) * 12, 28 + Math.sin(a) * 12, 20 + Math.cos(a + 0.3) * 19, 28 + Math.sin(a + 0.3) * 18, 20 + Math.cos(a + 0.6) * 12, 28 + Math.sin(a + 0.6) * 12], mane); }
    el(c, 20, 30, 10, 10, fur);
    glowEye(c, 16, 27, 1.6, '#ffe040'); glowEye(c, 24, 27, 1.6, '#ffe040');
    poly(c, [14, 34, 26, 34, 24, 38, 16, 38], '#5a1a1a');
    poly(c, [16, 34, 17, 37, 18, 34], '#fff', null); poly(c, [22, 34, 23, 37, 24, 34], '#fff', null);
    el(c, 20, 31, 2, 1.5, '#3a2a2a', null);
  }],
  archdemon: [76, 84, (c, w, h, p, f) => {
    const sk = '#6a2a4a', dk = '#3a1428', hi = '#9a4a6a';
    const d = f ? 6 : 0;
    wing(c, 26, 26, -1, 26, 16 + d, '#2a0a1a', OUT, 4); wing(c, 50, 26, 1, 26, 16 + d, '#2a0a1a', OUT, 4);
    rect(c, 26, 60, 9, 23, dk); rect(c, 41, 60, 9, 23, dk);
    poly(c, [22, 60, 30, 70, 36, 60, 40, 60, 46, 70, 54, 60], dk);
    el(c, 38, 44, 18, 18, sk);
    el(c, 38, 44, 10, 11, hi, null);
    line(c, [30, 40, 46, 40], dk); line(c, [31, 47, 45, 47], dk);
    el(c, 16, 42, 7, 13, sk); el(c, 60, 42, 7, 13, sk);
    for (let i = 0; i < 3; i++) { poly(c, [11 + i * 4, 54, 12 + i * 4, 60, 14 + i * 4, 54], '#e0d0c0', null); poly(c, [56 + i * 4, 54, 57 + i * 4, 60, 59 + i * 4, 54], '#e0d0c0', null); }
    el(c, 38, 20, 10, 10, sk);
    poly(c, [30, 14, 18, 2, 22, 0, 34, 11], '#d8c8a0'); poly(c, [46, 14, 58, 2, 54, 0, 42, 11], '#d8c8a0');
    glowEye(c, 34, 19, 1.8, '#ffe040'); glowEye(c, 42, 19, 1.8, '#ffe040');
    poly(c, [32, 25, 44, 25, 42, 28, 34, 28], '#1a0010');
    c.save(); c.shadowColor = '#c040ff'; c.shadowBlur = 6; el(c, 38, 36, 3, 3, '#e0a0ff', null); c.restore();
  }],
  vorg: [86, 104, (c, w, h, p, f) => {
    const ar = '#4a3a3a', hi = '#7a5a4a', trim = '#c8903a', cape = '#8a1a1a';
    const s = f ? 1 : 0;
    poly(c, [22, 24, 64, 24, 76, 100, 10, 100], cape);
    rect(c, 26, 70, 13, 30, ar); rect(c, 47, 70, 13, 30, ar);
    rect(c, 24, 94, 17, 8, '#2a2020'); rect(c, 45, 94, 17, 8, '#2a2020');
    poly(c, [22, 28, 64, 28, 60, 72, 26, 72], ar);
    poly(c, [28, 32, 58, 32, 54, 52, 32, 52], hi, null);
    line(c, [43, 32, 43, 70], trim, 2);
    rect(c, 24, 62, 38, 6, '#2a1a1a'); px(c, 39, 62, trim, 8, 6);
    // 어깨
    el(c, 20, 30, 11, 8, ar); el(c, 66, 30, 11, 8, ar);
    poly(c, [12, 26, 6, 14, 18, 24], trim); poly(c, [74, 26, 80, 14, 68, 24], trim);
    // 팔
    rect(c, 10, 36, 9, 26, ar); rect(c, 67, 36, 9, 26, ar);
    // 대검
    poly(c, [72, 60 + s, 80, 60 + s, 82, 2 + s, 76, -2 + s, 70, 2 + s], '#b0b8c8');
    line(c, [76, 4 + s, 76, 56 + s], '#e0e8f0');
    rect(c, 66, 58 + s, 20, 5, trim);
    rect(c, 73, 62 + s, 6, 10, '#3a2a1a');
    // 투구
    poly(c, [30, 8, 43, 0, 56, 8, 56, 28, 30, 28], ar);
    poly(c, [30, 10, 18, -2, 22, -4, 34, 6], '#d8c8a0'); poly(c, [56, 10, 68, -2, 64, -4, 52, 6], '#d8c8a0');
    rect(c, 34, 14, 18, 4, '#0a0808', null);
    glowEye(c, 38, 16, 1.6, '#ff3020'); glowEye(c, 48, 16, 1.6, '#ff3020');
    line(c, [43, 20, 43, 28], '#0a0808', 2);
    poly(c, [40, 0, 43, -4, 46, 0], trim);
  }],
  demon_king: [112, 124, (c, w, h, p, f) => {
    const robe = '#2a1438', dk = '#180a24', trim = '#d8a840', sk = '#7a6a9a', cape = '#6a0a1a';
    const fl = f ? 1 : 0;
    // 망토
    poly(c, [56, 30, 6, 60, 0, 122, 30, 112, 56, 124, 82, 112, 112, 122, 106, 60], cape);
    poly(c, [56, 30, 14, 58, 10, 70, 56, 44, 102, 70, 98, 58], '#8a1a2a');
    // 로브
    poly(c, [56, 36, 32, 50, 26, 118, 86, 118, 80, 50], robe);
    poly(c, [48, 50, 64, 50, 70, 118, 42, 118], dk, null);
    line(c, [44, 52, 40, 118], trim, 1.5); line(c, [68, 52, 72, 118], trim, 1.5);
    c.save(); c.shadowColor = '#ff2040'; c.shadowBlur = 8; el(c, 56, 60, 4, 5, '#ff4060'); c.restore();
    poly(c, [36, 44, 56, 56, 76, 44, 72, 38, 56, 48, 40, 38], trim);
    // 팔·손
    line(c, [32, 54, 14, 72], robe, 8); el(c, 13, 74, 4, 4, sk);
    c.save(); c.shadowColor = '#a040ff'; c.shadowBlur = 8; el(c, 12, 66 - fl, 5, 5, 'rgba(200,120,255,0.8)', null); c.restore();
    line(c, [80, 54, 98, 64], robe, 8); el(c, 99, 66, 4, 4, sk);
    line(c, [100, 118, 100, 20], '#3a2a3a', 3);
    poly(c, [94, 22, 100, 6, 106, 22, 100, 18], trim);
    el(c, 100, 26, 4, 4, '#ff2040');
    // 머리
    el(c, 56, 26, 11, 12, sk);
    poly(c, [45, 26, 44, 40, 56, 44, 68, 40, 67, 26], sk, null);
    poly(c, [46, 18, 26, 0, 30, -2, 50, 12], '#e0d0b0'); poly(c, [66, 18, 86, 0, 82, -2, 62, 12], '#e0d0b0');
    poly(c, [44, 16, 47, 6, 52, 13, 56, 4, 60, 13, 65, 6, 68, 16], trim);
    glowEye(c, 51, 26, 1.8 + fl * 0.3, '#ff2030'); glowEye(c, 61, 26, 1.8 + fl * 0.3, '#ff2030');
    line(c, [47, 22, 53, 24], OUT, 1.5); line(c, [65, 22, 59, 24], OUT, 1.5);
    line(c, [52, 34, 56, 35, 60, 34], OUT);
    // 수염처럼 늘어진 어둠
    poly(c, [48, 38, 56, 50, 64, 38], dk, null);
  }],
  demon_king_true: [164, 140, (c, w, h, p, f) => {
    const sk = '#3a1030', dk = '#1a0616', hi = '#6a2050', core = '#ff3050';
    const d = f ? 8 : 0;
    // 거대한 날개 4장
    wing(c, 60, 50, -1, 60, 36 + d, '#240818', OUT, 5); wing(c, 104, 50, 1, 60, 36 + d, '#240818', OUT, 5);
    wing(c, 62, 70, -1, 44, 18 - d * 0.5, '#3a0a24', OUT, 3); wing(c, 102, 70, 1, 44, 18 - d * 0.5, '#3a0a24', OUT, 3);
    // 촉수
    for (let i = 0; i < 4; i++) {
      const x = 50 + i * 21;
      line(c, [x, 110, x - 6 + (f ? 3 : -3), 124, x + 4, 138], sk, 6);
    }
    // 몸통
    el(c, 82, 88, 42, 36, sk);
    el(c, 82, 92, 28, 24, hi);
    // 갈비뼈 같은 무늬
    for (let i = 0; i < 4; i++) { line(c, [60, 78 + i * 8, 76, 84 + i * 8], dk, 2); line(c, [104, 78 + i * 8, 88, 84 + i * 8], dk, 2); }
    // 핵
    c.save(); c.shadowColor = core; c.shadowBlur = 12; el(c, 82, 90, 8 + (f ? 1 : 0), 10, core, OUT); c.restore();
    el(c, 82, 90, 3, 5, '#ffd0e0', null);
    // 팔
    poly(c, [44, 70, 16, 96, 12, 120, 24, 118, 30, 100, 50, 86], sk);
    poly(c, [120, 70, 148, 96, 152, 120, 140, 118, 134, 100, 114, 86], sk);
    for (let i = 0; i < 3; i++) { poly(c, [10 + i * 5, 118, 12 + i * 5, 126, 14 + i * 5, 118], '#e8d8c0', null); poly(c, [140 + i * 5, 118, 142 + i * 5, 126, 144 + i * 5, 118], '#e8d8c0', null); }
    // 머리
    poly(c, [62, 50, 66, 22, 82, 14, 98, 22, 102, 50, 82, 60], sk);
    poly(c, [66, 26, 40, 2, 34, 6, 60, 36], '#d8c8a0'); poly(c, [98, 26, 124, 2, 130, 6, 104, 36], '#d8c8a0');
    poly(c, [72, 18, 70, 4, 78, 14], '#d8c8a0'); poly(c, [92, 18, 94, 4, 86, 14], '#d8c8a0');
    // 눈 여러 개
    glowEye(c, 74, 34, 2.4, '#ff2030'); glowEye(c, 90, 34, 2.4, '#ff2030');
    glowEye(c, 82, 26, 2, '#ffd040');
    glowEye(c, 68, 42, 1.3, '#ff2030'); glowEye(c, 96, 42, 1.3, '#ff2030');
    poly(c, [70, 48, 94, 48, 90, 56, 74, 56], '#0a0008');
    for (let i = 0; i < 6; i++) poly(c, [72 + i * 4, 48, 74 + i * 4, 53, 76 + i * 4, 48], '#fff', null);
  }],
};

export function spriteSize(key) {
  const d = DEFS[key] || DEFS.slime;
  return { w: d[0], h: d[1] };
}

export function hasSprite(key) { return !!DEFS[key]; }

export function getSprite(key, palette, frame = 0, white = false) {
  const id = `${key}|${palette || ''}|${frame}|${white ? 1 : 0}`;
  if (cache.has(id)) return cache.get(id);
  const def = DEFS[key] || DEFS.slime;
  const [w, h, fn] = def;
  let out;
  if (white) {
    const src = getSprite(key, palette, frame, false);
    const cv = document.createElement('canvas');
    cv.width = src.canvas.width; cv.height = src.canvas.height;
    const c = cv.getContext('2d');
    c.drawImage(src.canvas, 0, 0);
    c.globalCompositeOperation = 'source-atop';
    c.fillStyle = '#ffffff';
    c.fillRect(0, 0, cv.width, cv.height);
    out = { canvas: cv, w: src.w, h: src.h };
  } else {
    const cv = document.createElement('canvas');
    cv.width = w; cv.height = h + 4;
    const c = cv.getContext('2d');
    c.translate(0, 4); // 위로 삐져나오는 뿔/장식 여유
    c.lineJoin = 'round';
    fn(c, w, h, pal(key, palette), frame);
    out = { canvas: cv, w, h: h + 4 };
  }
  cache.set(id, out);
  return out;
}
