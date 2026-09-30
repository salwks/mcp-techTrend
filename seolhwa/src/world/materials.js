// 재질과 캔버스 절차 텍스처(창살 한지, 초가 이엉, 기와, 물결, 장승 얼굴)
import * as THREE from 'three';
import { rng } from './util.js';

export const INK = 0x2b2622;

function canvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  return c;
}
function tex(c, repeat = true) {
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.anisotropy = 4;
  return t;
}

let _cache = null;
export function textures() {
  if (_cache) return _cache;
  const r = rng(7);

  // 창호지 + 띠살 창살
  const lc = canvas(128, 128), lx = lc.getContext('2d');
  lx.fillStyle = '#efe4c8'; lx.fillRect(0, 0, 128, 128);
  for (let i = 0; i < 300; i++) { lx.fillStyle = `rgba(160,130,90,${r() * 0.06})`; lx.fillRect(r() * 128, r() * 128, 2 + r() * 6, 1 + r() * 3); }
  lx.fillStyle = '#5a4331';
  for (let i = 0; i <= 8; i++) lx.fillRect(i * 16 - 2, 0, 4, 128);
  for (const y of [0, 20, 40, 88, 108, 124]) lx.fillRect(0, y, 128, 4);
  lx.fillRect(0, 60, 128, 8);
  const lattice = tex(lc, false);

  // 초가 이엉 + 새끼줄 그물
  const tc = canvas(256, 128), tx = tc.getContext('2d');
  tx.fillStyle = '#e6d8b4'; tx.fillRect(0, 0, 256, 128);
  for (let i = 0; i < 1400; i++) {
    const v = r();
    tx.strokeStyle = v < 0.5 ? `rgba(150,120,70,${0.15 + r() * 0.2})` : `rgba(255,248,220,${0.2 + r() * 0.3})`;
    tx.lineWidth = 1;
    const x = r() * 256, y = r() * 128;
    tx.beginPath(); tx.moveTo(x, y); tx.lineTo(x + (r() - 0.5) * 3, y - 6 - r() * 8); tx.stroke();
  }
  tx.fillStyle = 'rgba(92,72,45,0.85)';
  for (let i = 0; i < 16; i++) tx.fillRect(i * 16, 0, 2, 128);
  for (const y of [34, 70, 100]) tx.fillRect(0, y, 256, 2);
  const thatch = tex(tc);

  // 기와: 세로 골 줄무늬
  const gc = canvas(64, 64), gx = gc.getContext('2d');
  const grd = gx.createLinearGradient(0, 0, 64, 0);
  grd.addColorStop(0, '#6d7275'); grd.addColorStop(0.45, '#9ca0a0'); grd.addColorStop(0.55, '#8a8f90'); grd.addColorStop(1, '#4c5154');
  gx.fillStyle = grd; gx.fillRect(0, 0, 64, 64);
  gx.fillStyle = '#2e3134'; gx.fillRect(0, 0, 4, 64);
  for (let y = 0; y < 64; y += 16) { gx.fillStyle = 'rgba(40,40,40,0.25)'; gx.fillRect(0, y, 64, 2); }
  const tile = tex(gc);

  // 물결(민화식 먹선 물결)
  const wc = canvas(256, 256), wx = wc.getContext('2d');
  wx.fillStyle = '#9fb3ad'; wx.fillRect(0, 0, 256, 256);
  wx.lineCap = 'round';
  for (let row = 0; row < 12; row++) {
    const y0 = row * 22 + 6;
    const off = (row % 2) * 20;
    for (let k = -1; k < 7; k++) {
      const x0 = k * 40 + off;
      wx.strokeStyle = row % 3 === 0 ? 'rgba(240,244,232,0.75)' : 'rgba(58,78,80,0.35)';
      wx.lineWidth = row % 3 === 0 ? 2 : 1.5;
      wx.beginPath();
      wx.moveTo(x0, y0 + 6);
      wx.quadraticCurveTo(x0 + 10, y0 - 4, x0 + 20, y0 + 4);
      wx.quadraticCurveTo(x0 + 26, y0 + 8, x0 + 30, y0 + 2);
      wx.stroke();
    }
  }
  const water = tex(wc);

  // 장승 얼굴 두 장
  const faces = ['天下大將軍', '地下女將軍'].map((txt, idx) => {
    const c = canvas(64, 256), x = c.getContext('2d');
    x.fillStyle = '#b9a07a'; x.fillRect(0, 0, 64, 256);
    for (let i = 0; i < 40; i++) { x.fillStyle = `rgba(90,70,45,${r() * 0.15})`; x.fillRect(r() * 64, r() * 256, 1 + r() * 2, 10 + r() * 30); }
    // 눈썹, 왕방울 눈, 코, 이빨
    x.strokeStyle = '#1f1a16'; x.lineWidth = 4; x.fillStyle = '#f2ead8';
    x.beginPath(); x.moveTo(6, 30); x.quadraticCurveTo(18, 18, 28, 30); x.moveTo(36, 30); x.quadraticCurveTo(46, 18, 58, 30); x.stroke();
    for (const ex of [18, 46]) { x.beginPath(); x.arc(ex, 42, 9, 0, 7); x.fill(); x.stroke(); x.fillStyle = '#1f1a16'; x.beginPath(); x.arc(ex, 43, 4, 0, 7); x.fill(); x.fillStyle = '#f2ead8'; }
    x.beginPath(); x.moveTo(32, 48); x.lineTo(24, 72); x.lineTo(40, 72); x.closePath(); x.stroke();
    x.fillStyle = idx ? '#8a3b2b' : '#7a2a22'; x.fillRect(12, 80, 40, 16);
    x.fillStyle = '#f2ead8'; for (let t = 0; t < 5; t++) x.fillRect(14 + t * 8, 82, 5, 12);
    x.fillStyle = '#1f1a16'; x.font = 'bold 26px serif'; x.textAlign = 'center';
    [...txt].forEach((ch, i) => x.fillText(ch, 32, 128 + i * 27));
    return tex(c, false);
  });

  _cache = { lattice, thatch, tile, water, faces };
  return _cache;
}

// 재질 공장: 키 → 새 재질 인스턴스. glowList에 창호지 재질을 모아 밤에 빛나게 한다.
export function makeMaterialFactory(glowList) {
  const T = textures();
  return function make(key) {
    switch (key) {
      case 'flat': return new THREE.MeshLambertMaterial({ vertexColors: true, flatShading: true });
      case 'smooth': return new THREE.MeshLambertMaterial({ vertexColors: true });
      case 'thatch': return new THREE.MeshLambertMaterial({ vertexColors: true, map: T.thatch });
      case 'tile': return new THREE.MeshLambertMaterial({ vertexColors: true, map: T.tile });
      case 'onggi': return new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.35, metalness: 0.05 });
      case 'paper': {
        const m = new THREE.MeshLambertMaterial({ vertexColors: true, map: T.lattice, emissive: 0xffb45a, emissiveMap: T.lattice, emissiveIntensity: 0 });
        glowList.push(m);
        return m;
      }
      case 'lamp': {
        const m = new THREE.MeshLambertMaterial({ vertexColors: true, emissive: 0xffa04a, emissiveIntensity: 0 });
        glowList.push(m);
        return m;
      }
      case 'glow': return new THREE.MeshBasicMaterial({ vertexColors: true, toneMapped: false });
      case 'face0': return new THREE.MeshLambertMaterial({ vertexColors: true, map: T.faces[0] });
      case 'face1': return new THREE.MeshLambertMaterial({ vertexColors: true, map: T.faces[1] });
      case 'cloth': return new THREE.MeshLambertMaterial({ vertexColors: true, side: THREE.DoubleSide });
      default: return new THREE.MeshLambertMaterial({ vertexColors: true, flatShading: true });
    }
  };
}
export function inkMat() {
  return new THREE.MeshBasicMaterial({ color: INK, side: THREE.BackSide });
}
