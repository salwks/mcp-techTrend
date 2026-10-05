// 권역 주변 인물·짐승(npc_ambient.gd) 프레임 굽기.
//  - 사람: 웹 rigs.js SPECS에 고을 사람 변형(선비·상인·보부상·관속·스님·보살·뱃사공·해녀·농부·목자·도롱이·나그네)을
//    실행 중에만 더하고(웹 코드는 그대로), 같은 굽기 엔진(frameCore.BakeBank, high)으로 대기·걷기(+일부 대화) 프레임을 굽는다.
//  - 짐승: 소·말·개·닭·갈매기는 웹에 리그가 없어 여기서 캔버스에 먹선·담채로 직접 그린다(옆모습만, 왼쪽을 본다).
// 결과: data/frames_amb.json + frames_<kind>_<n>.png (+ frames_animals_<n>.png). SpriteChar 프레임 형식과 같다.
// 실행: python3 tools/web_export_server.py 8770 → 브라우저로 http://localhost:8770/__tools/npc_bake.html
import { SPECS } from '/src/chars/rigs.js';
import * as fc from '/src/chars/frameCore.js';
import { PAL } from '/src/chars/painter.js';
import * as HA from '/__tools/horse_art.js';

const PEOPLE = {
  scholar: { base: 'elder', top: 'durumagi', coat: '#e6ebe6', pants: '#ece9e0', collar: '#cfd6cf', goreum: '#d6d2c6', hat: 'gat', hair: 'sangtu',
    beard: false, wrinkles: false, stoop: 0, staff: null, pipe: false, robeLen: 104, browColor: undefined, build: 0.96, cheek: 0.14, shoe: '#3a3431', talk: true },
  merchant: { base: 'villager_m', coat: '#d3c6a5', pants: '#d9ceb4', vest: '#4f4a52', collar: '#4f4a52', daenim: '#4f4a52', back: null, hat: 'gat', build: 1.08, talk: true },
  peddler: { base: 'villager_m', coat: '#cbbd98', pants: '#d0c3a2', vest: null, collar: '#a8956d', hat: 'satgat', hatColor: '#9a7f50', back: 'jige', legwrap: '#ece5d2', talk: true },
  official: { base: 'villager_m', top: 'durumagi', coat: '#3f5268', pants: '#d9d2c0', collar: '#2c3a4b', goreum: '#2c3a4b', sash: PAL.red, back: null, hat: 'beonggeoji',
    hatColor: '#2b2622', vest: null, legwrap: '#ece6d6', robeLen: 92, build: 1.08, stubble: true, talk: true },
  monk: { base: 'villager_m', top: 'durumagi', coat: '#8e8b84', pants: '#9a968e', collar: '#6f6c66', goreum: '#77746d', vest: null, daenim: '#77746d', back: 'bundle', bundle: '#6f6c66',
    hat: 'satgat', hatColor: '#a58b5a', hair: 'short', stubble: false, staff: 'staff', robeLen: 100, build: 1.0 },
  bosal: { base: 'villager_f', coat: '#c9c5bb', skirt: '#77736c', goreum: '#5d5a54', cuff: '#77736c', collar: '#77736c', carry: null, build: 0.98, wrinkles: true },
  boatman: { base: 'villager_m', coat: '#d8ccaa', pants: '#cdbf9b', vest: null, collar: '#a8956d', daenim: '#8a7a5a', back: null, hat: 'satgat', hatColor: '#9c8457',
    legwrap: '#e8e0cb', staff: 'staff', build: 1.1 },
  haenyeo: { base: 'villager_f', coat: '#efebe1', skirt: '#e4dfd2', goreum: '#d9d3c4', cuff: '#cfc8b8', collar: '#cfc8b8', scarf: '#f1ede4', carry: null, cheek: 0.3, build: 1.0 },
  farmer: { base: 'villager_m', coat: '#ddd0ac', pants: '#d6cba9', vest: null, collar: '#b9a782', daenim: '#9a8a6a', back: null, band: '#efe9da', legwrap: '#ebe4d1', build: 1.1 },
  farmwife: { base: 'villager_f', coat: '#e2d7bb', skirt: '#7d6a55', goreum: '#8e5a48', cuff: '#7d6a55', collar: '#7d6a55', scarf: '#ebe5d6', carry: null },
  herder: { base: 'villager_m', coat: '#8d7354', pants: '#bba987', vest: '#c4ad80', fur: true, collar: '#6f5a3e', daenim: '#6f5a3e', back: null, hat: 'beonggeoji', hatColor: '#4a3b2d', legwrap: '#e6dfcc', build: 1.1 },
  raincape: { base: 'villager_m', coat: '#cdbf9b', pants: '#d0c3a2', vest: '#a98d58', fur: true, vestSleeve: false, collar: '#8a7148', back: null, hat: 'satgat', hatColor: '#a88d58', build: 1.16 },
  traveler: { base: 'villager_m', top: 'durumagi', coat: '#b7bcb6', pants: '#d6d0c0', collar: '#8f968f', goreum: '#8f968f', vest: null, hat: 'gat', back: 'bundle', bundle: '#7a5a3c',
    staff: 'staff', legwrap: '#ece6d6', robeLen: 96, build: 1.02 },
  shaman: { base: 'villager_f', coat: '#e9dfc6', skirt: '#a8443c', goreum: '#3d5a73', cuff: '#3d5a73', collar: '#3d5a73', carry: null, build: 1.0, wrinkles: true },
};

async function toPng(cv) {
  if (cv.convertToBlob) return await cv.convertToBlob({ type: 'image/png' });
  return await new Promise((r) => cv.toBlob(r, 'image/png'));
}
async function put(name, data) {
  const r = await fetch('/export/' + name, { method: 'PUT', body: data });
  if (!r.ok) throw new Error('PUT ' + name + ' ' + r.status);
}
const meta = (f) => ({ page: typeof f.page === 'number' ? f.page : f.page.index, u0: f.u0, u1: f.u1, v0: f.v0, v1: f.v1, x0: f.x0, x1: f.x1, y0: f.y0, y1: f.y1, lift: f.lift });

export async function run(log) {
  const out = {};
  // ---- 사람 ----
  for (const kind in PEOPLE) {
    const v = { ...PEOPLE[kind] };
    const base = SPECS[v.base];
    const talk = v.talk; delete v.talk; delete v.base;
    const sp = { ...base };
    for (const k in v) { if (v[k] === null || v[k] === undefined) delete sp[k]; else sp[k] = v[k]; }
    SPECS[kind] = sp;
    fc.TIERS.high[kind] = fc.TIERS.high.player;
    const b = new fc.BakeBank(kind, 'high');
    const clips = {};
    const anims = talk ? ['idle', 'walk', 'talk'] : ['idle', 'walk'];
    for (const vw of ['front', 'side', 'back']) for (const a of anims) {
      const key = fc.clipKey(fc.resolveView(kind, vw, a), a, false, false);
      if (clips[key]) continue;
      const c = b.clip(key); if (!c) continue;
      let g = 0; while (!b.step(c) && g++ < 400);
      clips[key] = { spec: c.spec, frames: c.frames.map(meta) };
    }
    const pages = [];
    for (let i = 0; i < b.pages.length; i++) { const name = `frames_${kind}_${i}.png`; await put(name, await toPng(b.pages[i].cv)); pages.push(name); }
    out[kind] = { pages, clips };
    log('baked ' + kind + ' pages=' + pages.length);
  }
  // ---- 짐승 ----
  const an = bakeAnimals();
  const apages = [];
  for (let i = 0; i < an.pages.length; i++) { const name = `frames_animals_${i}.png`; await put(name, await toPng(an.pages[i])); apages.push(name); }
  for (const k in an.kinds) out[k] = { pages: apages, clips: an.kinds[k] };
  await put('frames_amb.json', JSON.stringify(out));
  log('done: ' + Object.keys(out).join(', ') + ' animal pages=' + apages.length);
  console.log('[npc bake] done', Object.keys(out));
}

// ---------------------------------------------------------------------------
// 짐승 그리기 — 길이 단위 m(배율 적용 뒤 화면 크기), 발 중심 원점, 위가 +y, 머리는 왼쪽(-x)
// ---------------------------------------------------------------------------
const PPM = 100, PAGE = 1024, MARGIN = 5, TW = 420, TH = 300, TOX = 210, TOY = 280;
const INKC = '#1f1a17';
const sin = Math.sin, cos = Math.cos, PI = Math.PI;

function shadeHex(hex, k) {
  const n = parseInt(hex.slice(1), 16); let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  const t = k < 0 ? [30, 24, 18] : [246, 239, 223], a = Math.abs(k);
  r += (t[0] - r) * a; g += (t[1] - g) * a; b += (t[2] - b) * a;
  return '#' + ((1 << 24) | ((r | 0) << 16) | ((g | 0) << 8) | (b | 0)).toString(16).slice(1);
}

class Pen {
  constructor() { this.cv = document.createElement('canvas'); this.cv.width = TW; this.cv.height = TH; this.g = this.cv.getContext('2d', { willReadFrequently: true }); }
  clear() { this.g.setTransform(1, 0, 0, 1, 0, 0); this.g.clearRect(0, 0, TW, TH); }
  X(x) { return TOX + x * PPM; }
  Y(y) { return TOY - y * PPM; }
  path(pts, closed = true) {
    // 점 목록(m) → 부드러운 닫힌 곡선(중점 이차 곡선)
    const g = this.g, P = pts.map(([x, y]) => [this.X(x), this.Y(y)]);
    g.beginPath();
    if (!closed) { g.moveTo(P[0][0], P[0][1]); for (let i = 1; i < P.length - 1; i++) { const m = [(P[i][0] + P[i + 1][0]) / 2, (P[i][1] + P[i + 1][1]) / 2]; g.quadraticCurveTo(P[i][0], P[i][1], m[0], m[1]); } g.lineTo(P[P.length - 1][0], P[P.length - 1][1]); return; }
    const n = P.length, mid = (i) => [(P[i % n][0] + P[(i + 1) % n][0]) / 2, (P[i % n][1] + P[(i + 1) % n][1]) / 2];
    const s = mid(n - 1); g.moveTo(s[0], s[1]);
    for (let i = 0; i < n; i++) { const m = mid(i); g.quadraticCurveTo(P[i][0], P[i][1], m[0], m[1]); }
    g.closePath();
  }
  blob(pts, col, w = 2.4, shadeDown = 0.25) {
    const g = this.g; this.path(pts);
    let y0 = 1e9, y1 = -1e9; for (const p of pts) { y0 = Math.min(y0, this.Y(p[1])); y1 = Math.max(y1, this.Y(p[1])); }
    const gr = g.createLinearGradient(0, y0, 0, y1); gr.addColorStop(0, shadeHex(col, 0.12)); gr.addColorStop(1, shadeHex(col, -shadeDown));
    g.fillStyle = gr; g.fill();
    g.lineWidth = w; g.strokeStyle = INKC; g.lineJoin = 'round'; g.stroke();
  }
  line(pts, col, w, ink = 2.2) {
    const g = this.g; g.lineCap = 'round'; g.lineJoin = 'round';
    if (ink > 0) { this.path(pts, false); g.lineWidth = w * PPM + ink * 2; g.strokeStyle = INKC; g.stroke(); }
    this.path(pts, false); g.lineWidth = w * PPM; g.strokeStyle = col; g.stroke();
  }
  stroke(pts, w = 1.2, col = INKC) { const g = this.g; this.path(pts, false); g.lineWidth = w; g.strokeStyle = col; g.lineCap = 'round'; g.stroke(); }
  dot(x, y, r, col = INKC) { const g = this.g; g.beginPath(); g.arc(this.X(x), this.Y(y), r, 0, 2 * PI); g.fillStyle = col; g.fill(); }
}

// 다리 한 짝: 붙은 자리(ax,ay), 길이 L, 흔들기 각 a(+는 앞=왼쪽), 무릎 굽힘 k, 발 들림 lift
function leg(pen, ax, ay, L, a, w, col, hoof, bendSign = 1, lift = 0) {
  const k = 0.18 + lift * 2.2;
  const kx = ax - sin(a) * L * 0.5, ky = ay - cos(a) * L * 0.5;
  const fx = kx - sin(a - bendSign * k) * L * 0.5, fy = Math.max(0.03, ky - cos(a - bendSign * k) * L * 0.5 + lift * 0.4);
  // 넓적다리(굵게) → 정강이(가늘게): 두 토막을 굵기를 바꿔 긋는다
  pen.line([[ax, ay + 0.05], [kx, ky]], col, w * 1.45);
  pen.line([[kx, ky], [fx, fy]], col, w * 0.85);
  if (hoof) pen.blob([[fx - 0.06, fy + 0.04], [fx + 0.05, fy + 0.04], [fx + 0.06, fy - 0.03], [fx - 0.07, fy - 0.03]], hoof, 1.4, 0);
}

function drawOx(pen, anim, f, n) {
  const col = '#a8743f', far = shadeHex(col, -0.25), legc = shadeHex(col, -0.1);
  const ph = anim === 'walk' ? (f / n) * 2 * PI : 0;
  const A = anim === 'walk' ? 0.32 : 0, br = anim === 'walk' ? 0 : sin((f / n) * 2 * PI) * 0.012;
  const sw = (o) => A * sin(ph + o), lf = (o) => anim === 'walk' ? 0.05 * Math.max(0, cos(ph + o)) : 0;
  // 먼 다리
  leg(pen, -0.5, 0.95, 0.95, sw(PI), 0.13, far, '#3a2e25', 1, lf(PI));
  leg(pen, 0.92, 1.0, 1.0, sw(0), 0.14, far, '#3a2e25', -1, lf(0));
  // 꼬리
  const tw = anim === 'walk' ? 0.06 * sin(ph) : 0.12 * sin((f / n) * 2 * PI);
  pen.line([[1.08, 1.45], [1.18 + tw * 0.5, 1.05], [1.15 + tw, 0.72]], shadeHex(col, -0.15), 0.035, 1.2);
  pen.blob([[1.1 + tw, 0.8], [1.2 + tw, 0.62], [1.1 + tw, 0.58], [1.06 + tw, 0.72]], '#3a2e25', 1.4);
  // 몸통
  const by = br;
  pen.blob([[-0.72, 1.52 + by], [-0.35, 1.64 + by], [0.4, 1.56 + by], [1.05, 1.52 + by], [1.18, 1.2], [1.02, 0.86], [0.5, 0.72], [-0.2, 0.68], [-0.62, 0.76], [-0.88, 1.05], [-0.9, 1.35 + by]], col);
  pen.stroke([[-0.4, 0.95], [0.1, 0.88], [0.6, 0.92]], 1.2, shadeHex(col, -0.4));
  pen.stroke([[0.55, 1.45], [0.75, 1.15]], 1.0, shadeHex(col, -0.35));
  // 가까운 다리
  leg(pen, -0.62, 0.98, 0.98, sw(0), 0.15, legc, '#3a2e25', 1, lf(0));
  leg(pen, 0.82, 1.02, 1.02, sw(PI), 0.16, legc, '#3a2e25', -1, lf(PI));
  // 목·머리 (eat: 고개 숙여 풀 뜯기)
  const eat = anim === 'eat', chew = eat ? 0.02 * sin((f / n) * 4 * PI) : 0;
  const hx = eat ? -1.18 : -1.2, hy = eat ? 0.42 + chew : 1.18 + 0.01 * sin(ph * 2);
  pen.blob([[-0.6, 1.55], [-0.95, (hy + 1.5) / 2 + 0.1], [hx + 0.05, hy + 0.2], [hx - 0.08, hy + 0.05], [hx + 0.02, hy - 0.12], [-0.8, (hy + 0.9) / 2], [-0.7, 0.95]], col);
  const H = (pts) => pts.map(([x, y]) => [hx + x * 1.35, hy + y * 1.35]);
  pen.blob(H([[0.12, 0.2], [-0.15, 0.12], [-0.3, -0.08], [-0.26, -0.22], [-0.05, -0.2], [0.14, -0.02]]), shadeHex(col, 0.05));
  pen.blob(H([[-0.32, -0.06], [-0.36, -0.2], [-0.22, -0.26], [-0.18, -0.1]]), '#6a5040', 1.6);
  pen.line(H([[0.06, 0.2], [0.02, 0.34], [-0.08, 0.38]]), '#d9caa0', 0.05, 1.4);  // 뿔
  pen.blob(H([[0.1, 0.12], [0.3, 0.2], [0.26, 0.08]]), shadeHex(col, -0.1), 1.6); // 귀
  pen.dot(hx - 0.1, hy + 0.05, 2.8);
}

// 주변 말(들에 매인 말): tools/horse_art.js — 장마다 한 윤곽으로 그린 말(예전 막대 다리 꼭두각시를 걷어냄). eat = 땅 풀 뜯기
function drawHorse(pen, anim, f, n) {
  HA.drawHorse(pen, 'side', { coat: '#7a5236', mane: '#2a221c', blaze: true }, HA.horsePose(anim === 'eat' ? 'graze' : anim, f, n), {});
}

function drawDog(pen, anim, f, n) {
  const col = '#c8a066', far = shadeHex(col, -0.25);
  const ph = anim === 'walk' ? (f / n) * 2 * PI : 0;
  const A = anim === 'walk' ? 0.45 : 0;
  const sw = (o) => A * sin(ph + o), lf = (o) => anim === 'walk' ? 0.03 * Math.max(0, cos(ph + o)) : 0;
  leg(pen, -0.22, 0.36, 0.36, sw(PI), 0.055, far, null, 1, lf(PI));
  leg(pen, 0.26, 0.38, 0.38, sw(0), 0.06, far, null, -1, lf(0));
  const tw = anim === 'walk' ? 0.03 * sin(ph * 2) : 0.05 * sin((f / n) * 4 * PI);
  pen.line([[0.33, 0.56], [0.46, 0.7 + tw], [0.38, 0.8 + tw]], col, 0.05, 1.4);
  pen.blob([[-0.3, 0.6], [0.0, 0.62], [0.36, 0.6], [0.4, 0.45], [0.3, 0.34], [-0.1, 0.33], [-0.32, 0.4]], col, 2.0);
  leg(pen, -0.26, 0.38, 0.38, sw(0), 0.06, col, null, 1, lf(0));
  leg(pen, 0.22, 0.4, 0.4, sw(PI), 0.065, shadeHex(col, -0.05), null, -1, lf(PI));
  const eat = anim === 'eat';
  const hx = eat ? -0.42 : -0.4, hy = eat ? 0.2 + 0.02 * sin((f / n) * 6 * PI) : 0.74 + 0.01 * sin(ph * 2);
  pen.blob([[-0.2, 0.62], [hx + 0.08, hy + 0.08], [hx + 0.06, hy - 0.08], [-0.28, 0.42]], col, 2.0);
  pen.blob([[hx + 0.1, hy + 0.08], [hx - 0.06, hy + 0.08], [hx - 0.18, hy - 0.02], [hx - 0.16, hy - 0.08], [hx + 0.08, hy - 0.08]], shadeHex(col, 0.05), 2.0);
  pen.blob([[hx + 0.02, hy + 0.06], [hx + 0.06, hy + 0.2], [hx + 0.12, hy + 0.06]], shadeHex(col, -0.15), 1.5);
  pen.dot(hx - 0.17, hy - 0.04, 2.4);
  pen.dot(hx - 0.04, hy + 0.02, 2.0);
}

function drawChicken(pen, anim, f, n, hen = true) {
  const col = hen ? '#a5683a' : '#b5562e', tail = '#2f2a24';
  const ph = (f / n) * 2 * PI;
  const walk = anim === 'walk', eat = anim === 'eat';
  const bob = walk ? 0.02 * Math.abs(sin(ph)) : 0;
  // 다리
  const s1 = walk ? 0.08 * sin(ph) : 0;
  pen.stroke([[0.02, 0.17], [0.02 + s1, 0.0]], 2.4, '#c9a040');
  pen.stroke([[-0.04, 0.17], [-0.04 - s1, 0.0]], 2.4, '#b8903a');
  // 꼬리 깃
  pen.blob([[0.12, 0.3 + bob], [0.24, 0.48 + bob], [0.28, 0.42 + bob], [0.22, 0.26 + bob]], tail, 1.6);
  pen.blob([[-0.18, 0.3 + bob], [-0.05, 0.4 + bob], [0.14, 0.38 + bob], [0.2, 0.26 + bob], [0.08, 0.15 + bob], [-0.12, 0.17 + bob]], col, 2.0);
  pen.stroke([[-0.04, 0.32 + bob], [0.1, 0.26 + bob]], 1.0, shadeHex(col, -0.4));
  const peck = eat ? (Math.floor(f) % 2 === 0) : false;
  const hx = peck ? -0.24 : -0.17, hy = peck ? 0.08 : 0.47 + bob;
  pen.blob([[-0.12, 0.36 + bob], [hx + 0.02, hy + 0.04], [hx - 0.04, hy - 0.04], [-0.16, 0.26 + bob]], col, 1.8);
  pen.blob([[hx + 0.05, hy + 0.04], [hx - 0.02, hy + 0.06], [hx - 0.06, hy], [hx, hy - 0.04], [hx + 0.05, hy - 0.02]], col, 1.6);
  pen.blob([[hx + 0.02, hy + 0.05], [hx - 0.01, hy + 0.1], [hx - 0.04, hy + 0.05]], '#c0392b', 1.2);  // 볏
  pen.blob([[hx - 0.06, hy + 0.01], [hx - 0.11, hy - 0.01], [hx - 0.06, hy - 0.02]], '#d9a640', 1.0);   // 부리
  pen.dot(hx - 0.02, hy + 0.01, 1.4);
}

function drawGull(pen, anim, f, n) {
  const ph = (f / n) * 2 * PI, up = anim === 'walk' ? sin(ph) : 0.15;
  const y = 0.3;
  pen.blob([[-0.22, y + 0.02], [-0.05, y + 0.06], [0.22, y + 0.03], [0.26, y - 0.01], [0.0, y - 0.04], [-0.2, y - 0.02]], '#ece9e2', 1.6);
  pen.line([[-0.02, y + 0.03], [-0.18, y + 0.12 + up * 0.22], [-0.42, y + 0.06 + up * 0.36]], '#d7d6d0', 0.05, 1.3);
  pen.line([[0.04, y + 0.03], [0.22, y + 0.12 + up * 0.2], [0.44, y + 0.08 + up * 0.32]], '#c4c3bd', 0.05, 1.3);
  pen.dot(-0.26, y + 0.01, 1.6, '#d9a640');
}

const ANIMALS = {
  ox: { draw: drawOx, anims: { idle: 4, walk: 6, eat: 4 } },
  horse: { draw: drawHorse, anims: { idle: 4, walk: 8, eat: 4 } },
  dog: { draw: drawDog, anims: { idle: 4, walk: 6, eat: 4 } },
  hen: { draw: (p, a, f, n) => drawChicken(p, a, f, n, true), anims: { idle: 2, walk: 4, eat: 4 } },
  rooster: { draw: (p, a, f, n) => drawChicken(p, a, f, n, false), anims: { idle: 2, walk: 4, eat: 4 } },
  gull: { draw: drawGull, anims: { idle: 2, walk: 4 } },
};

function bakeAnimals() {
  const pen = new Pen();
  const pages = [];
  let page = null, sx = 0, sy = 0, rowH = 0;
  const newPage = () => { page = document.createElement('canvas'); page.width = PAGE; page.height = PAGE; pages.push(page); sx = 0; sy = 0; rowH = 0; };
  newPage();
  const kinds = {};
  for (const kind in ANIMALS) {
    const A = ANIMALS[kind], clips = {};
    for (const anim in A.anims) {
      const n = A.anims[anim], frames = [];
      for (let f = 0; f < n; f++) {
        pen.clear();
        A.draw(pen, anim, f, n);
        // 그린 영역
        const d = pen.g.getImageData(0, 0, TW, TH).data;
        let x0 = TW, y0 = TH, x1 = 0, y1 = 0;
        for (let y = 0; y < TH; y++) for (let x = 0; x < TW; x++) if (d[(y * TW + x) * 4 + 3] > 8) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
        x1 += 1; y1 += 1;
        const w = x1 - x0 + MARGIN * 2, h = y1 - y0 + MARGIN * 2;
        if (sx + w > PAGE) { sx = 0; sy += rowH; rowH = 0; }
        if (sy + h > PAGE) newPage();
        page.getContext('2d').drawImage(pen.cv, x0, y0, x1 - x0, y1 - y0, sx + MARGIN, sy + MARGIN, x1 - x0, y1 - y0);
        frames.push({ page: pages.length - 1, u0: sx / PAGE, v0: sy / PAGE, u1: (sx + w) / PAGE, v1: (sy + h) / PAGE,
          x0: (x0 - MARGIN - TOX) / PPM, x1: (x1 + MARGIN - TOX) / PPM, y0: -(y1 + MARGIN - TOY) / PPM, y1: -(y0 - MARGIN - TOY) / PPM, lift: 0 });
        sx += w; rowH = Math.max(rowH, h);
      }
      const spec = anim === 'walk' ? { kind: 'phase', n, times: [...Array(n).keys()].map((k) => k / n) }
        : { kind: 'loop', times: [...Array(n).keys()].map((k) => k * (anim === 'eat' ? 0.45 : 0.8)), loopStart: 0, intro: 0, step: anim === 'eat' ? 0.45 : 0.8, n, dur: n * (anim === 'eat' ? 0.45 : 0.8), tBased: true };
      clips['side|' + anim] = { spec, frames };
    }
    kinds[kind] = clips;
  }
  return { pages, kinds };
}
