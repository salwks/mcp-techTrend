// 재질과 캔버스 절차 텍스처. 거의 모든 물체가 하나의 아틀라스(붓질 텍스처 모음)를 쓰는 툰 재질 하나로 그려진다.
import * as THREE from 'three';
import { rng, REG, ATLAS_W, ATLAS_H } from './util.js';

export const INK = 0x2b2622;

function canvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  return c;
}

// 붓 한 획(끝이 가늘어지는 획)
function stroke(x, pts, width, color) {
  x.strokeStyle = color;
  x.lineCap = 'round';
  for (let i = 0; i < pts.length - 1; i++) {
    const t = i / (pts.length - 1);
    x.lineWidth = Math.max(0.4, width * Math.sin(Math.PI * (0.15 + 0.7 * t)));
    x.beginPath(); x.moveTo(pts[i][0], pts[i][1]); x.lineTo(pts[i + 1][0], pts[i + 1][1]); x.stroke();
  }
}

let _cache = null;
export function textures() {
  if (_cache) return _cache;
  const r = rng(7);
  const A = canvas(ATLAS_W, ATLAS_H), a = A.getContext('2d');
  const M = canvas(ATLAS_W, ATLAS_H), m = M.getContext('2d');
  m.fillStyle = '#000'; m.fillRect(0, 0, ATLAS_W, ATLAS_H);
  const region = (name, fn) => {
    const [x0, y0, x1, y1] = REG[name];
    a.save(); a.beginPath(); a.rect(x0, y0, x1 - x0, y1 - y0); a.clip(); a.translate(x0, y0);
    fn(a, x1 - x0, y1 - y0);
    a.restore();
  };
  const fibers = (x, w, h, n, col) => { for (let i = 0; i < n; i++) { x.fillStyle = col(r()); x.fillRect(r() * w, r() * h, 1 + r() * 5, 1 + r() * 2); } };

  // 흰 바탕(무늬 없는 물체) / 초롱(빛)
  region('white', (x, w, h) => { x.fillStyle = '#fff'; x.fillRect(0, 0, w, h); });
  region('lamp', (x, w, h) => { x.fillStyle = '#fff'; x.fillRect(0, 0, w, h); });

  // 창호지 + 띠살
  const latticeBars = (x, col) => {
    x.fillStyle = col;
    for (let i = 0; i <= 8; i++) x.fillRect(i * 16 - 2, 0, 4, 128);
    for (const y of [0, 20, 40, 88, 108, 124]) x.fillRect(0, y, 128, 4);
    x.fillRect(0, 60, 128, 8);
  };
  region('lattice', (x, w, h) => {
    x.fillStyle = '#f1e7cc'; x.fillRect(0, 0, w, h);
    fibers(x, w, h, 300, (v) => `rgba(160,130,90,${v * 0.07})`);
    latticeBars(x, '#5a4331');
  });
  {
    const [x0, y0] = REG.lattice;
    m.save(); m.translate(x0, y0); m.fillStyle = '#fff'; m.fillRect(0, 0, 128, 128); latticeBars(m, '#000'); m.restore();
    const L = REG.lamp; m.fillStyle = '#fff'; m.fillRect(L[0], L[1], L[2] - L[0], L[3] - L[1]);
  }

  // 초가 이엉: 비스듬한 짚 획 + 옅은 새끼줄
  region('thatch', (x, w, h) => {
    x.fillStyle = '#ece0bf'; x.fillRect(0, 0, w, h);
    for (let i = 0; i < 1700; i++) {
      const px = r() * w, py = r() * h, len = 5 + r() * 10, dx = (r() - 0.3) * 3;
      stroke(x, [[px, py], [px + dx * 0.5, py - len * 0.5], [px + dx, py - len]], 1.6, r() < 0.55 ? `rgba(140,110,62,${0.18 + r() * 0.25})` : `rgba(255,250,228,${0.25 + r() * 0.3})`);
    }
    x.fillStyle = 'rgba(105,84,52,0.35)';
    for (let i = 0; i < 24; i++) x.fillRect(Math.round(i * w / 24), 0, 1, h);
    for (const y of [40, 76, 104]) x.fillRect(0, y, w, 1);
  });

  // 기와 한 골(수키와 볼록 + 암키와 고랑 + 아래 겹침선)
  region('tile', (x, w, h) => {
    const g = x.createLinearGradient(0, 0, w, 0);
    g.addColorStop(0, '#5a5f63'); g.addColorStop(0.18, '#8e9396'); g.addColorStop(0.32, '#b9bcbc'); g.addColorStop(0.46, '#7d8285');
    g.addColorStop(0.5, '#3a3e41'); g.addColorStop(0.56, '#9ea2a3'); g.addColorStop(0.8, '#a9acac'); g.addColorStop(1, '#5a5f63');
    x.fillStyle = g; x.fillRect(0, 0, w, h);
    for (let y = 0; y < h; y += 32) { x.fillStyle = 'rgba(30,30,32,0.5)'; x.fillRect(0, y, w, 3); x.fillStyle = 'rgba(255,255,255,0.18)'; x.fillRect(0, y + 3, w, 2); }
    fibers(x, w, h, 80, (v) => `rgba(40,40,40,${v * 0.15})`);
  });
  // 막새(처마 끝 둥근 기와) 한 개
  region('makse', (x, w, h) => {
    x.fillStyle = '#4a4e52'; x.fillRect(0, 0, w, h);
    x.fillStyle = '#c9c7bd'; x.beginPath(); x.arc(w / 2, h * 0.55, w * 0.34, 0, 7); x.fill();
    x.strokeStyle = '#2b2622'; x.lineWidth = 6; x.stroke();
    x.lineWidth = 3; x.beginPath(); x.arc(w / 2, h * 0.55, w * 0.16, 0, 7); x.stroke();
  });

  // 바위: 피마준(삼 껍질 같은 세로 획) + 이끼 태점
  region('rock', (x, w, h) => {
    x.fillStyle = '#eeeae0'; x.fillRect(0, 0, w, h);
    for (let i = 0; i < 90; i++) {
      const px = r() * w, py = r() * h, len = 18 + r() * 40;
      const pts = [];
      for (let k = 0; k <= 5; k++) pts.push([px + Math.sin(k * 0.9 + i) * 3 + k * (r() - 0.5) * 2, py + (k / 5) * len]);
      stroke(x, pts, 1.2 + r() * 2.2, `rgba(60,58,54,${0.12 + r() * 0.3})`);
    }
    for (let i = 0; i < 10; i++) { const px = r() * w, py = r() * h; x.fillStyle = 'rgba(80,70,60,0.12)'; x.beginPath(); x.ellipse(px, py, 20 + r() * 20, 8 + r() * 8, r(), 0, 7); x.fill(); }
    for (let i = 0; i < 70; i++) { x.fillStyle = `rgba(52,70,40,${0.35 + r() * 0.4})`; x.beginPath(); x.arc(r() * w, r() * h * 0.5, 1 + r() * 2.2, 0, 7); x.fill(); }
  });
  // 돌(담·기단): 부벽준 느낌의 굵고 짧은 사선 획
  region('stone', (x, w, h) => {
    x.fillStyle = '#ece7dc'; x.fillRect(0, 0, w, h);
    for (let i = 0; i < 60; i++) {
      const px = r() * w, py = r() * h, len = 10 + r() * 20;
      stroke(x, [[px, py], [px + len * 0.6, py + len * 0.3], [px + len, py + len * 0.8]], 2 + r() * 4, `rgba(70,66,60,${0.08 + r() * 0.2})`);
    }
    for (let i = 0; i < 40; i++) { x.fillStyle = `rgba(52,70,40,${0.25 + r() * 0.3})`; x.beginPath(); x.arc(r() * w, r() * h, 1 + r() * 1.6, 0, 7); x.fill(); }
  });
  // 흙벽: 한지처럼 얼룩진 바탕 + 짚 부스러기
  region('mud', (x, w, h) => {
    x.fillStyle = '#f2ead6'; x.fillRect(0, 0, w, h);
    for (let i = 0; i < 40; i++) { x.fillStyle = `rgba(150,120,80,${r() * 0.12})`; x.beginPath(); x.ellipse(r() * w, r() * h, 6 + r() * 18, 4 + r() * 12, r() * 3, 0, 7); x.fill(); }
    for (let i = 0; i < 70; i++) { x.strokeStyle = `rgba(170,140,80,${0.3 + r() * 0.3})`; x.lineWidth = 1; const px = r() * w, py = r() * h; x.beginPath(); x.moveTo(px, py); x.lineTo(px + (r() - 0.5) * 8, py + (r() - 0.5) * 4); x.stroke(); }
    const g = x.createLinearGradient(0, 0, 0, h); g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, 'rgba(90,70,40,0.18)');
    x.fillStyle = g; x.fillRect(0, 0, w, h);
  });
  // 솔잎 뭉치: 옅은 바림 위에 부챗살 솔잎 획
  region('needle', (x, w, h) => {
    x.fillStyle = '#e6ecd8'; x.fillRect(0, 0, w, h);
    for (let i = 0; i < 70; i++) {
      const cx = r() * w, cy = r() * h, n = 7 + Math.floor(r() * 6), rad = 6 + r() * 9;
      for (let k = 0; k < n; k++) {
        const ang = -Math.PI * 0.95 + (k / n) * Math.PI * 0.9 + (r() - 0.5) * 0.2;
        x.strokeStyle = `rgba(30,48,30,${0.25 + r() * 0.35})`; x.lineWidth = 1;
        x.beginPath(); x.moveTo(cx, cy); x.lineTo(cx + Math.cos(ang) * rad, cy + Math.sin(ang) * rad); x.stroke();
      }
    }
  });
  // 활엽: 점엽법(둥근 먹점 덩이)
  region('leaf', (x, w, h) => {
    x.fillStyle = '#eef0dc'; x.fillRect(0, 0, w, h);
    for (let i = 0; i < 420; i++) { x.fillStyle = `rgba(40,56,30,${0.12 + r() * 0.3})`; x.beginPath(); x.ellipse(r() * w, r() * h, 2 + r() * 5, 1.5 + r() * 3, r() * 3, 0, 7); x.fill(); }
    for (let i = 0; i < 120; i++) { x.fillStyle = `rgba(255,255,235,${0.2 + r() * 0.3})`; x.beginPath(); x.arc(r() * w, r() * h, 1 + r() * 3, 0, 7); x.fill(); }
  });
  // 소나무 껍질: 거북등 비늘
  region('bark', (x, w, h) => {
    x.fillStyle = '#f0ddd0'; x.fillRect(0, 0, w, h);
    for (let y = 0; y < h; y += 10) for (let xx = (y / 10) % 2 * 8; xx < w; xx += 16) {
      x.strokeStyle = `rgba(60,34,24,${0.3 + r() * 0.3})`; x.lineWidth = 1.5;
      x.beginPath(); x.moveTo(xx, y); x.lineTo(xx + 7 + r() * 3, y + 2); x.lineTo(xx + 14, y); x.stroke();
    }
  });
  // 나무결
  region('wood', (x, w, h) => {
    x.fillStyle = '#efe2cf'; x.fillRect(0, 0, w, h);
    for (let i = 0; i < 40; i++) { const y = r() * h; stroke(x, [[0, y], [w * 0.3, y + (r() - 0.5) * 4], [w * 0.7, y + (r() - 0.5) * 4], [w, y]], 1 + r(), `rgba(90,60,35,${0.1 + r() * 0.2})`); }
  });
  region('cloth', (x, w, h) => { x.fillStyle = '#fff'; x.fillRect(0, 0, w, h); fibers(x, w, h, 200, (v) => `rgba(0,0,0,${v * 0.06})`); });

  // 장승 얼굴 두 장
  ['天下大將軍', '地下女將軍'].forEach((txt, idx) => region(idx ? 'face1' : 'face0', (x) => {
    x.fillStyle = '#e2d2b4'; x.fillRect(0, 0, 64, 256);
    for (let i = 0; i < 40; i++) { x.fillStyle = `rgba(90,70,45,${r() * 0.15})`; x.fillRect(r() * 64, r() * 256, 1 + r() * 2, 10 + r() * 30); }
    x.strokeStyle = '#1f1a16'; x.lineWidth = 4; x.fillStyle = '#f2ead8';
    x.beginPath(); x.moveTo(6, 30); x.quadraticCurveTo(18, 18, 28, 30); x.moveTo(36, 30); x.quadraticCurveTo(46, 18, 58, 30); x.stroke();
    for (const ex of [18, 46]) { x.beginPath(); x.arc(ex, 42, 9, 0, 7); x.fill(); x.stroke(); x.fillStyle = '#1f1a16'; x.beginPath(); x.arc(ex, 43, 4, 0, 7); x.fill(); x.fillStyle = '#f2ead8'; }
    x.beginPath(); x.moveTo(32, 48); x.lineTo(24, 72); x.lineTo(40, 72); x.closePath(); x.stroke();
    x.fillStyle = idx ? '#8a3b2b' : '#7a2a22'; x.fillRect(12, 80, 40, 16);
    x.fillStyle = '#f2ead8'; for (let t = 0; t < 5; t++) x.fillRect(14 + t * 8, 82, 5, 12);
    x.fillStyle = '#1f1a16'; x.font = 'bold 26px serif'; x.textAlign = 'center';
    [...txt].forEach((ch, i) => x.fillText(ch, 32, 128 + i * 27));
  }));

  const mk = (c) => {
    const t = new THREE.CanvasTexture(c);
    t.colorSpace = THREE.SRGBColorSpace;
    t.generateMipmaps = false; t.minFilter = THREE.LinearFilter; t.magFilter = THREE.LinearFilter;
    t.anisotropy = 4;
    return t;
  };
  const atlas = mk(A), mask = mk(M);
  mask.colorSpace = THREE.NoColorSpace;

  // 땅: 마른 붓 바림 + 태점(이끼 점) — 반복 텍스처, 버텍스 색에 곱해짐
  const G = canvas(256, 256), gx = G.getContext('2d');
  gx.fillStyle = '#f4f1e6'; gx.fillRect(0, 0, 256, 256);
  for (let i = 0; i < 160; i++) {
    const px = r() * 256, py = r() * 256, len = 20 + r() * 50;
    for (const o of [-256, 0, 256]) stroke(gx, [[px + o, py], [px + o + len * 0.5, py + (r() - 0.5) * 3], [px + o + len, py + (r() - 0.5) * 4]], 3 + r() * 7, r() < 0.6 ? `rgba(120,110,80,${0.04 + r() * 0.08})` : `rgba(255,255,245,${0.08 + r() * 0.12})`);
  }
  for (let i = 0; i < 90; i++) {
    const px = r() * 256, py = r() * 256, s = 0.8 + r() * 1.8;
    gx.fillStyle = `rgba(40,52,30,${0.2 + r() * 0.35})`;
    gx.beginPath(); gx.ellipse(px, py, s * 1.4, s, 0, 0, 7); gx.fill();
  }
  const ground = new THREE.CanvasTexture(G);
  ground.colorSpace = THREE.SRGBColorSpace; ground.wrapS = ground.wrapT = THREE.RepeatWrapping; ground.anisotropy = 4;

  // 물결(민화식)
  const wc = canvas(256, 256), wx = wc.getContext('2d');
  wx.fillStyle = '#9fb3ad'; wx.fillRect(0, 0, 256, 256);
  wx.lineCap = 'round';
  for (let row = 0; row < 12; row++) {
    const y0 = row * 22 + 6, off = (row % 2) * 20;
    for (let k = -1; k < 7; k++) {
      const x0 = k * 40 + off;
      wx.strokeStyle = row % 3 === 0 ? 'rgba(240,244,232,0.75)' : 'rgba(58,78,80,0.35)';
      wx.lineWidth = row % 3 === 0 ? 2 : 1.5;
      wx.beginPath(); wx.moveTo(x0, y0 + 6);
      wx.quadraticCurveTo(x0 + 10, y0 - 4, x0 + 20, y0 + 4);
      wx.quadraticCurveTo(x0 + 26, y0 + 8, x0 + 30, y0 + 2);
      wx.stroke();
    }
  }
  const water = new THREE.CanvasTexture(wc);
  water.colorSpace = THREE.SRGBColorSpace; water.wrapS = water.wrapT = THREE.RepeatWrapping;

  // 툰 명암 단계(붓 바림 3~4단)
  const gdata = new Uint8Array([105, 150, 196, 232, 255]);
  const gradient = new THREE.DataTexture(gdata, gdata.length, 1, THREE.RedFormat);
  gradient.minFilter = gradient.magFilter = THREE.LinearFilter;
  gradient.needsUpdate = true;

  _cache = { atlas, mask, ground, water, gradient };
  return _cache;
}

// 재질 공장: 'atlas'(거의 전부) / 'cloth'(양면 천). glowList에 넣은 재질은 setNight로 창호지·초롱이 빛난다.
export function makeMaterialFactory(glowList) {
  const T = textures();
  return function make(key) {
    if (key === 'cloth') return new THREE.MeshToonMaterial({ vertexColors: true, side: THREE.DoubleSide, gradientMap: T.gradient });
    const m = new THREE.MeshToonMaterial({
      vertexColors: true, map: T.atlas, gradientMap: T.gradient,
      emissive: 0xffb45a, emissiveMap: T.mask, emissiveIntensity: 0,
    });
    glowList.push(m);
    return m;
  };
}
export function terrainMaterial() {
  const T = textures();
  return new THREE.MeshToonMaterial({ vertexColors: true, map: T.ground, gradientMap: T.gradient });
}
export function inkMat() {
  return new THREE.MeshBasicMaterial({ color: INK, side: THREE.BackSide });
}
