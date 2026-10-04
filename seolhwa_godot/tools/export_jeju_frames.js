// 제주 「굴에 남은 숨」(ACT 5, S7001~S7008) 프레임 굽기 — 웹 굽기 엔진(frameCore.BakeBank, high)을 그대로 쓰고 웹 코드(seolhwa/src)는 고치지 않는다.
//  사람(CHARACTER_MASTER v1.3, 제주 옷 CLO_JEJU — 감물 들인 갈옷):
//  - gwak(곽칠성, CHR_MAIN_004 — 늙은 전직 짐꾼, 고유): 노인 베이스. 바랜 갈옷 저고리·바지, 흰 머리띠, 흰 상투·수염, 등에 지게, 굽은 등.
//      idle·walk·talk·sit + give(물건 건네기 — 나무패)
//  - simbang(제주 심방, CHR_MAIN_012 — 무당 베이스 고유변형): 짙은 쪽빛 저고리·흰 치마·붉은 고름·흰 머릿수건, 손에 요령(놋 방울) — 강릉 월심과 다른 빛깔.
//      idle·walk·talk + ritual(요령을 흔드는 도무) · give(감응 매듭 건네기)
//  - jj_child(김녕 아이 — 아동 베이스, 갈옷): idle·walk·talk·cower·cry·hug
//  - jj_man / jj_woman(제주 마을 사람 — 갈옷): idle·walk·talk (+ 아낙 cry)
//  짐승(사람 리그가 아니라 이 파일에서 붓으로 그린다 — 옆모습만. 다른 시점은 Godot SpriteChar가 side로 대신한다):
//  - jj_snake(구렁이, CHR_CRE_008 — 실제 큰 뱀, 약 3.2m): idle(사린 채 혀 날름) · walk·run·flee(기어감) · ready(고개를 치켜 S자 — 예고) ·
//      thrust(물기 — 앞으로 뻗음) · hit(움찔) · fall(늘어짐 — 죽음) · coil(= idle)
//  - jj_shade(김녕 대형 구렁이 잔영, CHR_CRE_009 — 확대 변형, 약 11m): float · drift · head_turn (Godot spirit_char가 옅은 먹빛으로 그린다)
//  그림은 '비스듬히 내려다본 땅 위' 꼴: 세로는 땅 깊이(앞→뒤)를 줄여 그린 것 + 들어 올린 높이. 발밑(0,0) = 뱀 몸 가운데 땅.
// 결과: data/frames_jeju.json + frames_jeju_<kind>_<n>.png (data/는 git 제외 — 새 맥에서 다시 굽는다)
// 실행: python3 tools/web_export_server.py 8770 → http://localhost:8770/__tools/jeju_bake.html (?only=gwak 처럼 일부만)
//   헤드리스: "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" --headless=new --disable-gpu --virtual-time-budget=900000 --dump-dom 그 주소 → <p id=st>done…
import { SPECS, getRig } from '/src/chars/rigs.js';
import { Painter, makeCanvas, shade } from '/src/chars/painter.js';
import * as fc from '/src/chars/frameCore.js';

const PEOPLE = {
  gwak: { base: 'elder', over: { top: 'jeogori', coat: '#9c6c46', pants: '#a9875e', vest: null, collar: '#6a4a30', daenim: '#6a4a30', goreum: '#6a4a30',
    hat: null, band: '#e2d9c4', hair: 'white', beard: true, wrinkles: true, stoop: 0.24, staff: null, pipe: false, back: 'jige', patch: '#7a5636',
    legwrap: '#d9cfb8', shoe: '#8a6a44', browColor: '#8e897f', cheek: 0.1, build: 1.0, height: 1.6 },
    anims: ['idle', 'walk', 'talk', 'sit', 'give'] },
  simbang: { base: 'villager_f', over: { coat: '#2f4262', skirt: '#ece6d6', goreum: '#a8443c', cuff: '#a8443c', collar: '#ece6d6', scarf: '#f1ece2',
    carry: null, lip: '#8a3a32', cheek: 0.14, wrinkles: true, build: 1.0 }, bell: true,
    anims: ['idle', 'walk', 'talk', 'ritual', 'give'] },
  jj_child: { base: 'child_girl', over: { coat: '#b0703e', skirt: '#8e5c36', goreum: '#5a3a24', cuff: '#5a3a24', collar: '#5a3a24', ribbon: '#a8443c', cheek: 0.34 },
    anims: ['idle', 'walk', 'talk', 'cower', 'cry', 'hug'] },
  jj_man: { base: 'villager_m', over: { coat: '#a56a3c', pants: '#9c6c42', vest: null, collar: '#6a4428', daenim: '#6a4428', back: null, band: '#e0d6c0',
    patch: '#7a5232', stubble: true, cheek: 0.16, shoe: '#a88a55', legwrap: '#d9cfb8' },
    anims: ['idle', 'walk', 'talk'] },
  jj_woman: { base: 'villager_f', over: { coat: '#b07446', skirt: '#8a5a34', goreum: '#4a3424', cuff: '#4a3424', collar: '#4a3424', scarf: '#ece6d6', carry: null, cheek: 0.24 },
    anims: ['idle', 'walk', 'talk', 'cry'] },
};
const NEW_ANIMS = { ritual: { dur: 0.8, loop: true }, give: { dur: 1.0 } };

const SWAP = { arm1: 'arm2', arm2: 'arm1', arm1_l: 'arm2_l', arm2_l: 'arm1_l', leg1: 'leg2', leg2: 'leg1', leg1_l: 'leg2_l', leg2_l: 'leg1_l' };
const toP = (F) => {
  const P = {};
  for (const n in F) { const a = F[n]; P[n] = { r: a[0] || 0, x: a[1] || 0, y: a[2] || 0, sx: a[3] ?? 1, sy: a[4] ?? 1, a: a[5] ?? 1 }; }
  return P;
};
const mirror = (P) => { const Q = {}; for (const n in P) { const p = P[n]; Q[SWAP[n] || n] = { r: -p.r, x: -p.x, y: p.y, sx: p.sx, sy: p.sy, a: p.a }; } return Q; };
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const smooth = (u) => u * u * (3 - 2 * u);
const { sin, cos, abs, PI, hypot, atan2 } = Math;

/** 심방 도무(ritual)·건네기(give) — 강릉 월심 동작과 같은 꼴 */
function storyPose(view, anim, t, at, rig) {
  if (!NEW_ANIMS[anim]) return null;
  const k = rig.S.hip / 80;
  const side = view === 'side';
  let F;
  if (anim === 'ritual') {
    const sh = sin((t / 0.4) * PI * 2), sw = sin((t / 0.8) * PI * 2);
    const bob = -3 * k * abs(sw);
    F = side
      ? { root: [0, 0, bob], torso: [-0.05 + 0.03 * sw], head: [-0.12], arm2: [2.55 + 0.18 * sh], arm2_l: [0.35 * sh], arm1: [0.55], arm1_l: [0.6], leg2: [0.08 * sw], leg1: [-0.08 * sw] }
      : { root: [0.03 * sw, 0, bob], torso: [0.04 * sw], head: [-0.05 * sw, 0, -1.5 * k], arm2: [-2.45 + 0.18 * sh], arm2_l: [0.3 * sh], arm1: [0.65], arm1_l: [0.45], leg1: [0.05 * sw], leg2: [0.05 * sw] };
  } else {
    const u = smooth(clamp(at / 0.7, 0, 1));
    F = side
      ? { torso: [-0.14 * u], head: [0.12 * u], arm2: [1.35 * u + 0.1], arm2_l: [0.15 * u], arm1: [1.2 * u], arm1_l: [0.3 * u] }
      : { torso: [0, 0, 0, 1, 1 - 0.02 * u], head: [0, 0, 2 * k * u], arm2: [-0.45 * u, 0, 0, 1, 1 - 0.15 * u], arm2_l: [-1.0 * u], arm1: [0.45 * u, 0, 0, 1, 1 - 0.15 * u], arm1_l: [1.0 * u] };
  }
  const P = toP(F);
  return view === 'back' ? mirror(P) : P;
}

/** 요령(놋 방울 묶음) + 오색 천 */
function bellPart(S) {
  const P = new Painter(256);
  P.begin(17);
  const ws = S.ws;
  P.poly([[-2.2, -4], [2.2, -4], [2, 20 * ws], [-2, 20 * ws]], '#86653f', { w: 1.3, smooth: false });
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * PI * 2, x = cos(a) * 6 * ws, y = 26 * ws + sin(a) * 4 * ws;
    P.ellipse(x, y, 4.4 * ws, 4.8 * ws, '#c9a14a', { w: 1.2 });
  }
  const OB = ['#2f4262', '#a8443c', '#e8d24a', '#f2ede0', '#3f6a4a'];
  for (let i = 0; i < 5; i++) P.poly([[-6 + i * 3, 2 * ws], [-4 + i * 3, 2 * ws], [-10 + i * 5, 46 * ws], [-13 + i * 5, 45 * ws]], OB[i], { w: 0.9 });
  return P.end();
}

// ---------------------------------------------------------------------------
// 구렁이(옆모습 붓그림)
// ---------------------------------------------------------------------------
const SNAKES = {
  jj_snake: { L: 3.2, W: 0.2, ppm: 112, body: '#4b4630', back: '#2f2b1e', belly: '#c9b98a', band: '#232017', seed: 41, painter: 768,
    anims: { idle: [2.0, 6, true], coil: [2.0, 6, true], walk: [1.0, 8, true], run: [0.6, 8, true], flee: [0.6, 8, true],
      ready: [0.7, 5, false], thrust: [0.45, 5, false], hit: [0.35, 3, false], fall: [0.9, 4, false] } },
  jj_shade: { L: 11.0, W: 0.62, ppm: 44, body: '#8e8a7c', back: '#4a4740', belly: '#d8d2c0', band: '#3a3732', seed: 77, painter: 1024,
    anims: { float: [3.0, 6, true], drift: [2.4, 8, true], head_turn: [1.2, 4, false] } },
};
const DEPTH_K = 0.55;   // 땅 깊이 줄임(비스듬히 내려다봄)

// 등뼈: s(0 머리 → 1 꼬리)마다 [x, d(깊이, 뒤로 +), h(높이)] (미터, 머리는 왼쪽 −x)
function spine(sp, anim, t, at, dur) {
  const L = sp.L, N = 46, out = [];
  const u = clamp(at / dur, 0, 1);
  const slither = (T, amp) => {
    for (let i = 0; i <= N; i++) {
      const s = i / N;
      const x = -L * 0.5 + s * L;
      const d = amp * L * sin(2 * PI * (1.6 * s - t / T)) * (0.35 + 0.65 * smooth(clamp(s * 3, 0, 1)));
      const h = s < 0.08 ? (0.08 - s) * 0.9 * L * 0.12 : 0;
      out.push([x, d, h]);
    }
  };
  // 사림: 꼬리 쪽 몸을 소용돌이로 감고, 목을 세운다. neckH = 머리 높이(몸길이 비율), lean = 머리를 뒤로 젖힘(+) / 앞으로(−)
  const coiled = (neckH, lean, reach, bob) => {
    const R0 = L * 0.15, turns = 2.1, s0 = 0.3;
    for (let i = 0; i <= N; i++) {
      const s = i / N;
      if (s >= s0) {
        const q = (s - s0) / (1 - s0);
        const th = q * turns * 2 * PI + 0.4;
        const r = R0 * (1 - 0.62 * q);
        out.push([r * cos(th) + L * 0.04, r * sin(th) * 1.15, 0.035 * L * (1 - q) * 0.6]);
      } else {
        const q = s / s0;            // 0 머리 → 1 사린 몸과 만나는 곳
        const base = [R0 * cos(0.4) + L * 0.04, R0 * sin(0.4) * 1.15, 0.02 * L];
        const head = [-R0 * 0.6 - reach * L + lean * L * 0.12, -0.05 * L, neckH * L + bob];
        const k = smooth(1 - q);
        const sx = base[0] + (head[0] - base[0]) * k + sin(k * PI) * L * 0.07 * (lean > 0 ? 1 : 0.4);
        const sy = base[1] + (head[1] - base[1]) * k;
        const sh = base[2] + (head[2] - base[2]) * (k * k * (3 - 2 * k)) + sin(k * PI * 2) * L * 0.02 * (lean > 0 ? 1 : 0);
        out.push([sx, sy, sh]);
      }
    }
  };
  switch (anim) {
    case 'walk': case 'drift': slither(anim === 'drift' ? 2.4 : 1.0, 0.075); break;
    case 'run': case 'flee': slither(0.6, 0.09); break;
    case 'idle': case 'coil': case 'float': {
      const T = anim === 'float' ? 3.0 : 2.0;
      coiled(0.11, 0, 0, 0.012 * L * sin((t / T) * 2 * PI));
      break;
    }
    case 'ready': { const k = smooth(u); coiled(0.11 + 0.24 * k, 1.6 * k, -0.06 * k, 0); break; }
    case 'thrust': { const k = u < 0.55 ? smooth(u / 0.55) : 1 - 0.35 * smooth((u - 0.55) / 0.45); coiled(0.35 - 0.27 * k, 1.6 * (1 - k) - 0.3 * k, -0.06 + 0.5 * k, 0); break; }
    case 'hit': { const k = sin(u * PI); coiled(0.13 + 0.06 * k, 0.9 * k, -0.05 * k, 0); break; }
    case 'head_turn': { const k = smooth(u); coiled(0.11 + 0.08 * k, -0.4 * k, 0, 0); break; }
    case 'fall': {
      const k = smooth(u);
      for (let i = 0; i <= N; i++) {
        const s = i / N, x = -L * 0.5 + s * L;
        out.push([x, (1 - k) * 0.06 * L * sin(2 * PI * 1.6 * s) + k * 0.02 * L * sin(PI * s), 0]);
      }
      break;
    }
    default: coiled(0.11, 0, 0, 0);
  }
  return out;
}

function width(sp, s) {
  // 머리(넓적) → 목(가늘게) → 몸통(가장 굵게) → 꼬리(뾰족)
  const W = sp.W;
  if (s < 0.035) return W * (0.75 + 0.25 * (s / 0.035));
  if (s < 0.08) return W * (1.0 - 0.3 * ((s - 0.035) / 0.045));
  if (s < 0.35) return W * (0.7 + 0.45 * ((s - 0.08) / 0.27));
  return W * (1.15 - 1.05 * Math.pow((s - 0.35) / 0.65, 1.4));
}

function drawSnake(P, sp, anim, t, at, dur, dead) {
  const ppm = sp.ppm;
  const pts = spine(sp, anim, t, at, dur);
  const N = pts.length - 1;
  const proj = (p) => [p[0] * ppm, -(p[2] + p[1] * DEPTH_K) * ppm];
  const C = pts.map(proj);
  // 조각(뒤 → 앞): 깊이 d가 큰(먼) 조각부터
  const chunks = [];
  const CH = 6;
  for (let a = 0; a < N; a += CH) {
    const b = Math.min(N, a + CH + 1);
    let dsum = 0, hsum = 0;
    for (let i = a; i < b; i++) { dsum += pts[i][1]; hsum += pts[i][2]; }
    chunks.push({ a, b, depth: dsum / (b - a) - hsum / (b - a) * 0.6 });
  }
  chunks.sort((x, y) => y.depth - x.depth);
  const nrm = (i) => {
    const p0 = C[Math.max(0, i - 1)], p1 = C[Math.min(N, i + 1)];
    const dx = p1[0] - p0[0], dy = p1[1] - p0[1], l = hypot(dx, dy) || 1;
    return [-dy / l, dx / l];
  };
  for (const ch of chunks) {
    const L = [], R = [];
    for (let i = ch.a; i < ch.b; i++) {
      const s = i / N, w = width(sp, s) * ppm * 0.5, n = nrm(i);
      L.push([C[i][0] + n[0] * w, C[i][1] + n[1] * w]);
      R.push([C[i][0] - n[0] * w, C[i][1] - n[1] * w]);
    }
    const poly = L.concat(R.reverse());
    P.poly(poly, dead ? shade(sp.body, 0.12) : sp.body, { w: 1.6 * (ppm / 112) + 0.6, rough: 0.4, shadeDown: 0.45 });
    // 등 무늬(짙은 마름모 띠)·배 빛
    for (let i = ch.a; i < ch.b; i += 2) {
      const s = i / N, w = width(sp, s) * ppm * 0.5, n = nrm(i);
      if (s < 0.06) continue;
      const c = C[i];
      P.fill([[c[0] + n[0] * w * 0.85, c[1] + n[1] * w * 0.85], [c[0] + n[0] * w * 0.15 + 2, c[1] + n[1] * w * 0.15], [c[0] - n[0] * w * 0.2, c[1] - n[1] * w * 0.2], [c[0] + n[0] * w * 0.15 - 2, c[1] + n[1] * w * 0.15]],
        (i / 2) % 2 ? sp.band : sp.back, { alpha: 0.55 });
      P.fill([[c[0] - n[0] * w * 0.55, c[1] - n[1] * w * 0.55], [c[0] - n[0] * w * 0.92, c[1] - n[1] * w * 0.92], [c[0] - n[0] * w * 0.92 + 2, c[1] - n[1] * w * 0.92 + 1]], sp.belly, { alpha: dead ? 0.8 : 0.45 });
    }
  }
  // 머리: 앞쪽(첫 점) 넓적한 머리 + 눈 + (가만히 있을 때) 혀 날름
  const h0 = C[0], h1 = C[3];
  const ang = atan2(h0[1] - h1[1], h0[0] - h1[0]);
  const hw = sp.W * ppm * 0.6, hl = sp.W * ppm * 1.25;
  const rot = (x, y) => [h0[0] + x * cos(ang) - y * sin(ang), h0[1] + x * sin(ang) + y * cos(ang)];
  const head = [rot(hl * 0.55, 0), rot(hl * 0.25, -hw * 0.95), rot(-hl * 0.45, -hw), rot(-hl * 0.6, 0), rot(-hl * 0.45, hw), rot(hl * 0.25, hw * 0.95)];
  P.poly(head, shade(sp.body, -0.08), { w: 1.6 * (ppm / 112) + 0.6, rough: 0.3 });
  const eye = rot(hl * 0.12, -hw * 0.42);
  if (!dead) { P.dot(eye[0], eye[1], Math.max(1.4, hw * 0.2), '#d8b84a'); P.dot(eye[0], eye[1], Math.max(0.8, hw * 0.1), '#14110e'); }
  else P.stroke([rot(hl * 0.02, -hw * 0.42), rot(hl * 0.22, -hw * 0.42)], { w: 1.2, taper: false });
  const flick = !dead && (anim === 'idle' || anim === 'coil' || anim === 'float' || anim === 'ready') && (sin(t * 9.0) > 0.55);
  if (flick || anim === 'thrust') {
    const tl = hl * (anim === 'thrust' ? 0.9 : 0.75);
    const a = rot(hl * 0.55, 0), b = rot(hl * 0.55 + tl, 0);
    P.stroke([a, b], { w: Math.max(1.0, hw * 0.12), color: '#a8443c', taper: false });
    P.stroke([b, rot(hl * 0.55 + tl * 1.25, -hw * 0.25)], { w: Math.max(0.8, hw * 0.1), color: '#a8443c', taper: false });
    P.stroke([b, rot(hl * 0.55 + tl * 1.25, hw * 0.25)], { w: Math.max(0.8, hw * 0.1), color: '#a8443c', taper: false });
  }
  if (anim === 'thrust') {   // 벌린 입
    P.stroke([rot(hl * 0.5, hw * 0.1), rot(hl * 0.95, hw * 0.7)], { w: 1.4, taper: false });
  }
}

// ---- 페이지 채우기(줄 단위) ----
const PAGE = 2048, MARGIN = 3;
class Pages {
  constructor() { this.pages = []; }
  alloc(w, h) {
    w += MARGIN * 2; h += MARGIN * 2;
    for (let pi = 0; pi < this.pages.length; pi++) {
      const p = this.pages[pi];
      for (const row of p.rows) if (row.h >= h && row.x + w <= PAGE) { const r = { page: pi, x: row.x + MARGIN, y: row.y + MARGIN }; row.x += w; return r; }
      if (p.y + h <= PAGE) { const row = { y: p.y, h, x: w }; p.rows.push(row); p.y += h; return { page: pi, x: MARGIN, y: row.y + MARGIN }; }
    }
    const cv = makeCanvas(PAGE, PAGE);
    this.pages.push({ cv, rows: [], y: 0 });
    return this.alloc(w - MARGIN * 2, h - MARGIN * 2);
  }
}

function bakeSnake(kind) {
  const sp = SNAKES[kind];
  const P = new Painter(sp.painter);
  const pg = new Pages();
  const clips = {};
  let seed = sp.seed;
  for (const anim in sp.anims) {
    const [dur, n, loop] = sp.anims[anim];
    const step = dur / n;
    const frames = [];
    const times = [];
    for (let k = 0; k < n; k++) {
      const t = loop ? k * step : (k / Math.max(1, n - 1)) * dur;
      times.push(loop ? k * step : (k / n) * dur);
      P.begin(seed++);
      drawSnake(P, sp, anim, t, t, dur, anim === 'fall');
      const im = P.end();
      const w = im.img.width, h = im.img.height;
      const a = pg.alloc(w, h);
      pg.pages[a.page].cv.getContext('2d').drawImage(im.img, a.x, a.y);
      frames.push({ page: a.page, u0: a.x / PAGE, u1: (a.x + w) / PAGE, v0: a.y / PAGE, v1: (a.y + h) / PAGE,
        x0: im.ox / sp.ppm, x1: (im.ox + w) / sp.ppm, y0: -(im.oy + h) / sp.ppm, y1: -im.oy / sp.ppm, lift: 0 });
    }
    const spec = loop ? { kind: 'loop', times, loopStart: 0, intro: 0, step, n, dur, tBased: false } : { kind: 'once', times, dur };
    clips['side|' + anim] = { spec, frames };
  }
  return { pages: pg.pages.map((p) => p.cv), clips };
}

// ---------------------------------------------------------------------------
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
  const only = new URLSearchParams(location.search).get('only');
  const want = (k) => !only || only.split(',').includes(k);
  for (const kind in PEOPLE) {
    if (!want(kind)) continue;
    const P = PEOPLE[kind];
    const sp = { ...SPECS[P.base] };
    for (const k in P.over) { if (P.over[k] === null) delete sp[k]; else sp[k] = P.over[k]; }
    SPECS[kind] = sp;
    fc.TIERS.high[kind] = fc.TIERS.high.player;
    const rig = getRig(kind);
    rig.anims = { ...rig.anims, ...NEW_ANIMS };
    const base = rig.pose;
    rig.pose = (view, anim, t, rg, at, st) => storyPose(view, anim, t, at, rg) || base(view, anim, t, rg, at, st);
    if (P.bell) {
      const img = bellPart(rig.S);
      for (const v of ['front', 'side', 'back']) {
        const parts = rig.views[v];
        const hand = v === 'back' ? 'arm1_l' : 'arm2_l';
        parts.push({ name: 'bell', parent: hand, at: [0, rig.S.lArm + 2], r0: 0, z: v === 'side' ? 10.95 : 6.15, img: img.img, ox: img.ox, oy: img.oy, abs: true, tag: 'staff' });
        parts.draw = parts.filter((p) => p.img).map((p, i) => ({ p, i })).sort((a, b) => a.p.z - b.p.z || a.i - b.i).map((e) => e.p);
      }
    }
    const b = new fc.BakeBank(kind, 'high');
    const clips = {};
    for (const vw of ['front', 'side', 'back']) for (const a of P.anims) {
      const key = fc.clipKey(fc.resolveView(kind, vw, a), a, false, false);
      if (clips[key]) continue;
      const c = b.clip(key); if (!c) continue;
      let g = 0; while (!b.step(c) && g++ < 600);
      clips[key] = { spec: c.spec, frames: c.frames.map(meta) };
    }
    const pages = [];
    for (let i = 0; i < b.pages.length; i++) { const name = `frames_jeju_${kind}_${i}.png`; await put(name, await toPng(b.pages[i].cv)); pages.push(name); }
    out[kind] = { pages, clips };
    log('baked ' + kind + ' pages=' + pages.length + ' clips=' + Object.keys(clips).length);
  }
  for (const kind in SNAKES) {
    if (!want(kind)) continue;
    const r = bakeSnake(kind);
    const pages = [];
    for (let i = 0; i < r.pages.length; i++) { const name = `frames_jeju_${kind}_${i}.png`; await put(name, await toPng(r.pages[i])); pages.push(name); }
    out[kind] = { pages, clips: r.clips };
    log('baked ' + kind + ' pages=' + pages.length + ' clips=' + Object.keys(r.clips).length);
  }
  await put(only ? `frames_jeju_${only.replace(/,/g, '_')}.json` : 'frames_jeju.json', JSON.stringify(out));
  log('done: ' + Object.keys(out).join(', '));
  console.log('[jeju bake] done', Object.keys(out));
}
