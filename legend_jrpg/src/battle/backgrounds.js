// 전투 배경: 320×240 저해상도로 절차적으로 그려 캐시하고 2배로 확대한다.
// drawBackground(ctx, key) / drawBgOverlay(ctx, key, t) (움직이는 입자)
const W = 320;
const H = 240;
const HORIZON = 118;
const cache = new Map();

function lg(c, y0, y1, stops) {
  const g = c.createLinearGradient(0, y0, 0, y1);
  stops.forEach((s, i) => g.addColorStop(i / (stops.length - 1), s));
  return g;
}
function seeded(seed) {
  let s = seed;
  return () => { s = (s * 16807) % 2147483647; return (s - 1) / 2147483646; };
}
function tri(c, x, y, w, h, col) {
  c.fillStyle = col;
  c.beginPath(); c.moveTo(x, y); c.lineTo(x + w / 2, y - h); c.lineTo(x + w, y); c.closePath(); c.fill();
}
function circle(c, x, y, r, col) { c.fillStyle = col; c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); c.fill(); }
function mountains(c, rnd, base, amp, col, step = 24) {
  c.fillStyle = col;
  c.beginPath(); c.moveTo(0, base);
  for (let x = 0; x <= W + step; x += step) c.lineTo(x, base - amp * (0.4 + rnd() * 0.6));
  c.lineTo(W, HORIZON + 2); c.lineTo(0, HORIZON + 2); c.closePath(); c.fill();
}
function floor(c, top, bottom, lines) {
  c.fillStyle = lg(c, HORIZON, H, [top, bottom]);
  c.fillRect(0, HORIZON, W, H - HORIZON);
  if (lines) {
    c.strokeStyle = lines; c.lineWidth = 1;
    for (let i = 1; i < 8; i++) {
      const y = HORIZON + (i * i) * 2;
      c.beginPath(); c.moveTo(0, y + 0.5); c.lineTo(W, y + 0.5); c.stroke();
    }
    for (let i = -8; i <= 8; i++) {
      c.beginPath(); c.moveTo(W / 2 + i * 14, HORIZON); c.lineTo(W / 2 + i * 70, H); c.stroke();
    }
  }
}
function stars(c, rnd, n, maxY, col = '#fff') {
  for (let i = 0; i < n; i++) {
    c.fillStyle = col;
    c.globalAlpha = 0.4 + rnd() * 0.6;
    c.fillRect(Math.floor(rnd() * W), Math.floor(rnd() * maxY), 1, 1);
  }
  c.globalAlpha = 1;
}
function pillar(c, x, y0, y1, w, col, hi, dark) {
  c.fillStyle = col; c.fillRect(x, y0, w, y1 - y0);
  c.fillStyle = hi; c.fillRect(x + 2, y0, 2, y1 - y0);
  c.fillStyle = dark; c.fillRect(x + w - 3, y0, 3, y1 - y0);
  c.fillStyle = hi; c.fillRect(x - 3, y0, w + 6, 5); c.fillRect(x - 3, y1 - 5, w + 6, 5);
}
function bricks(c, x0, y0, x1, y1, col, mortar, bw = 16, bh = 8) {
  c.fillStyle = col; c.fillRect(x0, y0, x1 - x0, y1 - y0);
  c.fillStyle = mortar;
  for (let y = y0, r = 0; y < y1; y += bh, r++) {
    c.fillRect(x0, y, x1 - x0, 1);
    for (let x = x0 + (r % 2 ? bw / 2 : 0); x < x1; x += bw) c.fillRect(x, y, 1, bh);
  }
}

const PAINT = {
  village: (c, rnd) => {
    // 붉은 달이 뜬 밤의 마을
    c.fillStyle = lg(c, 0, HORIZON, ['#12081e', '#3a1430', '#7a2a2a']); c.fillRect(0, 0, W, HORIZON);
    stars(c, rnd, 50, 80);
    c.save(); c.shadowColor = '#ff3030'; c.shadowBlur = 20; circle(c, 250, 34, 16, '#e0303a'); c.restore();
    circle(c, 245, 30, 4, 'rgba(255,160,160,0.35)');
    mountains(c, rnd, 100, 22, '#2a1426');
    // 집들
    for (const [x, w, h] of [[10, 44, 30], [70, 38, 26], [180, 50, 34], [256, 44, 28]]) {
      const y = HORIZON + 4;
      c.fillStyle = '#3a2830'; c.fillRect(x, y - h, w, h);
      tri(c, x - 4, y - h, w + 8, 16, '#5a1e22');
      c.fillStyle = rnd() > 0.3 ? '#ffb040' : '#301818'; c.fillRect(x + 8, y - h + 8, 7, 7);
      c.fillStyle = '#ffb040'; c.fillRect(x + w - 16, y - h + 8, 7, 7);
    }
    c.fillStyle = 'rgba(255,90,30,0.25)'; c.fillRect(0, 70, W, HORIZON - 70);
    floor(c, '#3a4a2a', '#1a2414');
    c.fillStyle = '#6a5a3a';
    c.beginPath(); c.moveTo(140, HORIZON); c.lineTo(180, HORIZON); c.lineTo(250, H); c.lineTo(70, H); c.closePath(); c.fill();
    for (let i = 0; i < 60; i++) { c.fillStyle = rnd() > 0.5 ? '#4a5a34' : '#2a3a1e'; c.fillRect(rnd() * W, HORIZON + rnd() * (H - HORIZON), 2, 1); }
  },
  shrine: (c, rnd) => {
    bricks(c, 0, 0, W, HORIZON + 10, '#3a3a4a', '#26263a', 20, 10);
    c.fillStyle = 'rgba(0,0,0,0.35)'; c.fillRect(0, 0, W, HORIZON + 10);
    // 제단과 빛
    c.fillStyle = lg(c, 0, HORIZON, ['rgba(255,240,180,0)', 'rgba(255,240,180,0.35)']);
    c.beginPath(); c.moveTo(145, 0); c.lineTo(175, 0); c.lineTo(200, HORIZON); c.lineTo(120, HORIZON); c.closePath(); c.fill();
    c.fillStyle = '#6a6070'; c.fillRect(130, HORIZON - 22, 60, 22);
    c.fillStyle = '#8a8090'; c.fillRect(126, HORIZON - 26, 68, 6);
    for (const x of [30, 90, 220, 280]) pillar(c, x - 8, 10, HORIZON + 6, 16, '#5a5a6a', '#7a7a8a', '#3a3a4a');
    for (const x of [60, 250]) { c.fillStyle = '#c8a060'; c.fillRect(x, HORIZON - 12, 3, 10); circle(c, x + 1.5, HORIZON - 15, 3, '#ffd060'); }
    floor(c, '#4a4658', '#1e1c28', 'rgba(0,0,0,0.25)');
    c.fillStyle = '#6a1a2a'; c.beginPath(); c.moveTo(150, HORIZON); c.lineTo(170, HORIZON); c.lineTo(210, H); c.lineTo(110, H); c.closePath(); c.fill();
  },
  forest: (c, rnd) => {
    c.fillStyle = lg(c, 0, HORIZON, ['#0e2a1a', '#1e4a2a', '#3a6a3a']); c.fillRect(0, 0, W, HORIZON);
    // 먼 나무
    for (let i = 0; i < 18; i++) { const x = rnd() * W; tri(c, x - 14, HORIZON, 28, 50 + rnd() * 30, '#1a3a22'); }
    // 빛줄기
    c.fillStyle = 'rgba(220,255,180,0.08)';
    for (const x of [60, 150, 230]) { c.beginPath(); c.moveTo(x, 0); c.lineTo(x + 18, 0); c.lineTo(x + 60, HORIZON + 40); c.lineTo(x + 30, HORIZON + 40); c.closePath(); c.fill(); }
    // 큰 줄기
    for (const [x, w] of [[4, 22], [52, 14], [262, 18], [296, 26]]) {
      c.fillStyle = '#3a2a1a'; c.fillRect(x, 0, w, HORIZON + 14);
      c.fillStyle = '#5a4028'; c.fillRect(x + 3, 0, 3, HORIZON + 14);
    }
    c.fillStyle = '#16361e'; c.fillRect(0, 0, W, 16);
    for (let i = 0; i < 30; i++) circle(c, rnd() * W, 10 + rnd() * 14, 8 + rnd() * 10, rnd() > 0.5 ? '#1e4a26' : '#2a5a2e');
    floor(c, '#3a6a30', '#1a3a18');
    for (let i = 0; i < 120; i++) { c.fillStyle = ['#4a7a3a', '#2a5a26', '#6a9a4a'][Math.floor(rnd() * 3)]; c.fillRect(rnd() * W, HORIZON + rnd() * (H - HORIZON), 1, 2); }
    for (let i = 0; i < 8; i++) circle(c, rnd() * W, HORIZON + 20 + rnd() * 100, 1.5, ['#ff80a0', '#ffe060', '#fff'][i % 3]);
  },
  plains: (c, rnd) => {
    c.fillStyle = lg(c, 0, HORIZON, ['#4a8ae0', '#8ac0f0', '#d0ecff']); c.fillRect(0, 0, W, HORIZON);
    for (let i = 0; i < 6; i++) {
      const x = rnd() * W, y = 14 + rnd() * 50;
      for (let k = 0; k < 4; k++) circle(c, x + k * 8, y + (k % 2) * 3, 7 + rnd() * 4, 'rgba(255,255,255,0.9)');
    }
    mountains(c, rnd, 96, 34, '#7a9ac8', 30);
    mountains(c, rnd, 108, 16, '#5a8a5a', 20);
    floor(c, '#6ab04a', '#3a7a2a');
    c.fillStyle = '#b89a6a';
    c.beginPath(); c.moveTo(150, HORIZON); c.lineTo(166, HORIZON); c.lineTo(200, H); c.lineTo(110, H); c.closePath(); c.fill();
    for (let i = 0; i < 140; i++) { c.fillStyle = rnd() > 0.5 ? '#7ac05a' : '#4a902e'; c.fillRect(rnd() * W, HORIZON + rnd() * (H - HORIZON), 1, 2); }
  },
  cave: (c, rnd) => {
    c.fillStyle = lg(c, 0, HORIZON, ['#0a0e16', '#1a2230', '#243040']); c.fillRect(0, 0, W, HORIZON);
    // 종유석
    for (let i = 0; i < 22; i++) { const x = rnd() * W; const h = 10 + rnd() * 40; c.fillStyle = rnd() > 0.5 ? '#2a3444' : '#1e2836'; c.beginPath(); c.moveTo(x - 6, 0); c.lineTo(x, h); c.lineTo(x + 6, 0); c.closePath(); c.fill(); }
    // 바위벽
    c.fillStyle = '#1a2230';
    c.beginPath(); c.moveTo(0, 30); c.lineTo(40, 60); c.lineTo(30, HORIZON); c.lineTo(0, HORIZON); c.fill();
    c.beginPath(); c.moveTo(W, 26); c.lineTo(W - 50, 70); c.lineTo(W - 34, HORIZON); c.lineTo(W, HORIZON); c.fill();
    // 수정
    for (const [x, y] of [[60, HORIZON - 4], [270, HORIZON - 2], [240, HORIZON - 8]]) {
      c.fillStyle = '#4ad0e0'; c.beginPath(); c.moveTo(x, y); c.lineTo(x + 3, y - 14); c.lineTo(x + 6, y); c.fill();
      c.fillStyle = '#a0f0ff'; c.fillRect(x + 2, y - 10, 1, 6);
    }
    floor(c, '#2a3440', '#10161e');
    // 물웅덩이
    c.fillStyle = 'rgba(60,140,200,0.45)';
    c.beginPath(); c.ellipse(70, 206, 50, 10, 0, 0, Math.PI * 2); c.fill();
    c.beginPath(); c.ellipse(260, 190, 40, 8, 0, 0, Math.PI * 2); c.fill();
    for (let i = 0; i < 50; i++) { c.fillStyle = '#3a4656'; c.fillRect(rnd() * W, HORIZON + rnd() * (H - HORIZON), 2, 1); }
  },
  tower: (c, rnd) => {
    bricks(c, 0, 0, W, HORIZON + 10, '#3a3060', '#262048', 24, 10);
    // 별이 보이는 아치 창
    for (const x of [40, 140, 240]) {
      c.fillStyle = '#0a0a24';
      c.beginPath(); c.moveTo(x, 90); c.lineTo(x, 40); c.arc(x + 20, 40, 20, Math.PI, 0); c.lineTo(x + 40, 90); c.closePath(); c.fill();
      for (let i = 0; i < 10; i++) { c.fillStyle = '#fff'; c.fillRect(x + 4 + rnd() * 32, 26 + rnd() * 60, 1, 1); }
      c.fillStyle = '#ffe890'; c.fillRect(x + 8 + rnd() * 20, 40 + rnd() * 30, 2, 2);
      c.strokeStyle = '#8a80c0'; c.lineWidth = 2;
      c.beginPath(); c.moveTo(x, 90); c.lineTo(x, 40); c.arc(x + 20, 40, 20, Math.PI, 0); c.lineTo(x + 40, 90); c.stroke();
    }
    floor(c, '#4a4078', '#1a1636', 'rgba(160,140,255,0.15)');
    // 마법진
    c.strokeStyle = 'rgba(150,200,255,0.5)'; c.lineWidth = 1;
    c.beginPath(); c.ellipse(160, 186, 110, 30, 0, 0, Math.PI * 2); c.stroke();
    c.beginPath(); c.ellipse(160, 186, 84, 22, 0, 0, Math.PI * 2); c.stroke();
    for (let i = 0; i < 6; i++) {
      const a = i / 6 * Math.PI * 2; const b = (i + 2) / 6 * Math.PI * 2;
      c.beginPath(); c.moveTo(160 + Math.cos(a) * 84, 186 + Math.sin(a) * 22); c.lineTo(160 + Math.cos(b) * 84, 186 + Math.sin(b) * 22); c.stroke();
    }
  },
  wasteland: (c, rnd) => {
    c.fillStyle = lg(c, 0, HORIZON, ['#4a3a3a', '#8a6048', '#c09060']); c.fillRect(0, 0, W, HORIZON);
    c.save(); c.shadowColor = '#ff4020'; c.shadowBlur = 14; circle(c, 60, 30, 12, '#c83a30'); c.restore();
    mountains(c, rnd, 98, 30, '#5a4040', 26);
    mountains(c, rnd, 110, 14, '#6a5040', 18);
    floor(c, '#8a7050', '#4a3a2a');
    // 갈라진 땅
    c.strokeStyle = '#3a2a1a'; c.lineWidth = 1;
    for (let i = 0; i < 14; i++) {
      let x = rnd() * W, y = HORIZON + 10 + rnd() * 110;
      c.beginPath(); c.moveTo(x, y);
      for (let k = 0; k < 4; k++) { x += (rnd() - 0.5) * 20; y += rnd() * 6; c.lineTo(x, y); }
      c.stroke();
    }
    // 마른 나무
    for (const [x, s] of [[24, 1], [290, 0.8], [250, 0.6]]) {
      c.strokeStyle = '#2a1e18'; c.lineWidth = 3 * s;
      c.beginPath(); c.moveTo(x, HORIZON + 20); c.lineTo(x, HORIZON - 30 * s); c.stroke();
      c.lineWidth = 1.5 * s;
      c.beginPath(); c.moveTo(x, HORIZON - 10 * s); c.lineTo(x - 12 * s, HORIZON - 26 * s); c.moveTo(x, HORIZON - 18 * s); c.lineTo(x + 10 * s, HORIZON - 34 * s); c.stroke();
    }
    for (let i = 0; i < 40; i++) { c.fillStyle = '#6a5438'; c.fillRect(rnd() * W, HORIZON + rnd() * (H - HORIZON), 3, 2); }
  },
  castle: (c, rnd) => {
    bricks(c, 0, 0, W, HORIZON + 10, '#2a2034', '#16101e', 22, 11);
    // 붉은 깃발
    for (const x of [70, 230]) {
      c.fillStyle = '#7a1020'; c.fillRect(x, 16, 24, 60);
      c.beginPath(); c.moveTo(x, 76); c.lineTo(x + 12, 68); c.lineTo(x + 24, 76); c.fillStyle = '#2a2034'; c.fill();
      c.fillStyle = '#c8a040'; c.fillRect(x, 16, 24, 3);
      c.fillStyle = '#1a0a10'; c.beginPath(); c.arc(x + 12, 40, 6, 0, Math.PI * 2); c.fill();
    }
    for (const x of [20, 150, 290]) pillar(c, x - 8, 0, HORIZON + 8, 18, '#3a2e48', '#54466a', '#1e1628');
    for (const x of [44, 186, 270]) { c.fillStyle = '#5a4030'; c.fillRect(x, 60, 4, 10); circle(c, x + 2, 56, 4, '#ff8a30'); }
    floor(c, '#3a2e44', '#120c18');
    // 체크 무늬 바닥
    for (let r = 0; r < 10; r++) {
      const y0 = HORIZON + r * r * 1.3, y1 = HORIZON + (r + 1) * (r + 1) * 1.3;
      for (let k = -10; k < 10; k++) {
        if ((r + k) % 2 === 0) continue;
        const f = (y) => (y - HORIZON) / (H - HORIZON);
        const xa0 = 160 + k * (20 + 60 * f(y0)), xb0 = 160 + (k + 1) * (20 + 60 * f(y0));
        const xa1 = 160 + k * (20 + 60 * f(y1)), xb1 = 160 + (k + 1) * (20 + 60 * f(y1));
        c.fillStyle = 'rgba(0,0,0,0.3)';
        c.beginPath(); c.moveTo(xa0, y0); c.lineTo(xb0, y0); c.lineTo(xb1, y1); c.lineTo(xa1, y1); c.closePath(); c.fill();
      }
    }
  },
  throne: (c, rnd) => {
    c.fillStyle = lg(c, 0, HORIZON, ['#0a0008', '#2a0614', '#4a0a1a']); c.fillRect(0, 0, W, HORIZON);
    // 거대한 창과 붉은 달
    c.fillStyle = '#12000a';
    c.beginPath(); c.moveTo(120, HORIZON); c.lineTo(120, 40); c.arc(160, 40, 40, Math.PI, 0); c.lineTo(200, HORIZON); c.closePath(); c.fill();
    c.save(); c.shadowColor = '#ff2030'; c.shadowBlur = 24; circle(c, 160, 44, 22, '#d01828'); c.restore();
    circle(c, 154, 38, 6, 'rgba(255,140,140,0.3)');
    c.strokeStyle = '#6a3040'; c.lineWidth = 3;
    c.beginPath(); c.moveTo(120, HORIZON); c.lineTo(120, 40); c.arc(160, 40, 40, Math.PI, 0); c.lineTo(200, HORIZON); c.stroke();
    for (const x of [30, 80, 240, 290]) pillar(c, x - 9, 0, HORIZON + 8, 18, '#2a1020', '#4a1e34', '#12060e');
    floor(c, '#2a0a18', '#08020a', 'rgba(255,40,60,0.1)');
    c.fillStyle = '#6a0a1a';
    c.beginPath(); c.moveTo(146, HORIZON); c.lineTo(174, HORIZON); c.lineTo(230, H); c.lineTo(90, H); c.closePath(); c.fill();
    c.fillStyle = '#c8a040';
    c.fillRect(0, 0, 0, 0);
    c.beginPath(); c.moveTo(146, HORIZON); c.lineTo(148, HORIZON); c.lineTo(94, H); c.lineTo(90, H); c.closePath(); c.fill();
    c.beginPath(); c.moveTo(172, HORIZON); c.lineTo(174, HORIZON); c.lineTo(230, H); c.lineTo(226, H); c.closePath(); c.fill();
  },
};

export function drawBackground(ctx, key) {
  const k = PAINT[key] ? key : 'plains';
  let cv = cache.get(k);
  if (!cv) {
    cv = document.createElement('canvas');
    cv.width = W; cv.height = H;
    const c = cv.getContext('2d');
    PAINT[k](c, seeded(k.length * 7919 + k.charCodeAt(0) * 31));
    // 아래쪽 어둡게 (창 가독성)
    c.fillStyle = lg(c, H - 80, H, ['rgba(0,0,0,0)', 'rgba(0,0,0,0.45)']);
    c.fillRect(0, H - 80, W, 80);
    cache.set(k, cv);
  }
  ctx.save();
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(cv, 0, 0, W * 2, H * 2);
  ctx.restore();
}

// 배경별 움직이는 입자(불티, 반딧불, 먼지, 반짝임…)
const OVERLAY = {
  village: { n: 18, color: '#ff9040', vy: -18, size: 2, sway: 10 },
  forest: { n: 14, color: '#d0ff80', vy: -4, size: 2, sway: 16, blink: true },
  cave: { n: 10, color: '#80d0ff', vy: 30, size: 2, sway: 0 },
  tower: { n: 20, color: '#c0d0ff', vy: -8, size: 2, sway: 6, blink: true },
  wasteland: { n: 26, color: 'rgba(220,180,130,0.6)', vx: 60, vy: 4, size: 2, sway: 4 },
  castle: { n: 12, color: '#ff6040', vy: -14, size: 2, sway: 8 },
  throne: { n: 24, color: '#ff3050', vy: -20, size: 2, sway: 12, blink: true },
  shrine: { n: 10, color: '#ffe8a0', vy: -6, size: 2, sway: 6, blink: true },
};

export function drawBgOverlay(ctx, key, t) {
  const o = OVERLAY[key];
  if (!o) return;
  ctx.save();
  for (let i = 0; i < o.n; i++) {
    const seed = i * 97.13;
    const bx = (seed * 13.7) % 640;
    const by = (seed * 7.3) % 360;
    let x = bx + (o.vx || 0) * t + Math.sin(t * 1.3 + i) * o.sway;
    let y = by + o.vy * t;
    x = ((x % 640) + 640) % 640;
    y = ((y % 360) + 360) % 360;
    ctx.globalAlpha = o.blink ? 0.3 + 0.7 * Math.abs(Math.sin(t * 2 + i)) : 0.8;
    ctx.fillStyle = o.color;
    ctx.fillRect(Math.round(x), Math.round(y), o.size, o.size);
  }
  ctx.restore();
}
