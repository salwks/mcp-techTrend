// 인물 빌더 그림 부속(먹선·한지·평면 채색 — 웹 rigs.js 그림 방식 그대로). 빌더 자료(char_builder.js)를 받아 그린다.
//   builderHead(p, view, S, sp): 얼굴(꼴·눈썹·눈·코·입·주름·점·수염) · 머리(상투·쪽·댕기·떠꺼머리·얹은머리·삭발·아이 머리) ·
//     쓰개(갓·정자관·패랭이·삿갓·벙거지·전립·사모·족두리·남바위·조바위·머릿수건·수건 띠) · 머리에 인 짐(광주리·물동이)
//   extraParts(rig): 장옷·쓰개치마 · 세조대 · 가사 · 괴나리봇짐 · 손에 든 짐(carry 동작)
//   handItem(kind): 지팡이·장죽·부채 등 손 소품(sp.staff 함수)
//   wearFx(sp): 해짐·흙때(부위 그림 위에 덧칠)
// 좌표는 rigs.drawHead와 같다: 머리 부위 원점 = 목 밑, hy = 얼굴 가운데, 옆모습은 왼쪽을 본다.
import { HUMAN_DRAW as H } from '/src/chars/rigs.js';
import { PAL, INK, shade, mix, ellipsePts, Painter } from '/src/chars/painter.js';

const { sin, cos, PI, abs, max, min } = Math;

// ---------------------------------------------------------------------------
// 얼굴
// ---------------------------------------------------------------------------
const JAW = { oval: 1.0, round: 1.06, long: 0.96, square: 1.14, heart: 0.84 };
/** 얼굴 윤곽(앞): 위 반은 타원, 아래 반은 턱 넓이(jaw)로 */
function faceOutline(cx, hy, rx, ry, shape) {
  const jaw = JAW[shape] || 1, pts = [];
  for (let i = 0; i < 28; i++) {
    const a = (i / 28) * PI * 2, sy = sin(a);
    let x = cos(a) * rx, y = sy * ry;
    if (sy > 0) {
      x *= 1 + (jaw - 1) * Math.pow(sy, 1.4) * 1.3;
      if (shape === 'square') y *= 0.97;
      if (shape === 'heart') y *= 1.03;
    }
    pts.push([cx + x, hy + y]);
  }
  return pts;
}

function brows(p, x, s, ey, ws, F, side) {
  const t = F.brows || 'thin', w = { thin: 1.9, thick: 3.1, sparse: 1.3, arched: 2.1, straight: 2.3, droop: 2.2 }[t] || 1.9;
  const col = F.browColor || INK, by = ey - (F.browY || 10) * ws;
  const a = s * (side ? -1 : 1);   // 옆: 앞쪽(-x)이 안쪽
  let pts;
  if (t === 'arched') pts = [[x - a * 6 * ws, by + 1 * ws], [x + a * 1 * ws, by - 3.5 * ws], [x + a * 7.5 * ws, by]];
  else if (t === 'straight') pts = [[x - a * 6.5 * ws, by - 0.5 * ws], [x + a * 1 * ws, by - 1.4 * ws], [x + a * 7.5 * ws, by - 1.2 * ws]];
  else if (t === 'droop') pts = [[x - a * 6 * ws, by - 2 * ws], [x + a * 1 * ws, by - 2 * ws], [x + a * 7.5 * ws, by + 2.2 * ws]];
  else pts = [[x - a * 6 * ws, by + 1 * ws], [x + a * 1 * ws, by - 1.5 * ws], [x + a * 7.5 * ws, by]];
  p.stroke(pts, { w: w * ws * (F.browW || 1), color: col, rough: t === 'sparse' ? 0.9 : 0.3 });
  if (t === 'thick') p.stroke([[x - a * 5 * ws, by], [x + a * 6 * ws, by - 0.6 * ws]], { w: 1.4 * ws, color: col });
}

function eye(p, x, s, ey, ws, F, sp, side) {
  const t = F.eyes || 'narrow', k = F.eyeSize || 1, a = s * (side ? -1 : 1);
  const lidC = shade(sp.skin || PAL.skin, -0.4);
  if (sp._blink || t === 'sleepy') {
    p.stroke([[x - a * 5 * ws * k, ey], [x + a * 0.5 * ws, ey + 1.6 * ws], [x + a * 6.5 * ws * k, ey + 0.2 * ws]], { w: 1.8 * ws, rough: 0.1 });
    if (t === 'sleepy' && !sp._blink) p.dot(x + a * 0.6 * ws, ey + 1.6 * ws, 1.5 * ws);
    return;
  }
  const tilt = t === 'upturned' ? -2.2 : t === 'droopy' ? 1.8 : 0;
  if (t === 'round') {
    p.stroke([[x - a * 5 * ws * k, ey + 1 * ws], [x + a * 0.5 * ws, ey - 2.6 * ws * k], [x + a * 6 * ws * k, ey]], { w: 2 * ws, rough: 0.15 });
    p.dot(x + a * 0.6 * ws, ey + 0.4 * ws, 2.5 * ws * k);
    p.stroke([[x - a * 3.5 * ws, ey + 3.2 * ws], [x + a * 4.5 * ws, ey + 2.8 * ws]], { w: 0.8 * ws, color: lidC, taper: true });
    return;
  }
  const sz = t === 'small' ? 0.8 : 1;
  p.stroke([[x - a * 5 * ws * k * sz, ey + 0.8 * ws], [x + a * 0.5 * ws, ey - 1.4 * ws * k], [x + a * 7 * ws * k * sz, ey - 1.6 * ws + tilt * ws]], { w: 2.1 * ws, rough: 0.2 });
  p.dot(x + a * 0.8 * ws, ey + 0.9 * ws, 2.1 * ws * k * sz);
  p.stroke([[x - a * 3 * ws, ey + 2.6 * ws], [x + a * 4 * ws, ey + 2.4 * ws + tilt * 0.5 * ws]], { w: 0.7 * ws, color: lidC, taper: true });
}

function faceFront(p, cx, hy, S, sp) {
  const F = sp.face || {}, ws = S.ws, rx = S.headRX, ry = S.headRY;
  const ey = hy + ry * 0.14, ex = rx * (F.eyeGap || 0.42);
  const skinD = shade(sp.skin || PAL.skin, -0.45);
  for (const s of [-1, 1]) {
    const x = cx + s * ex;
    brows(p, x, s, ey, ws, F, false);
    eye(p, x, s, ey, ws, F, sp, false);
    p.blush(cx + s * rx * 0.6, hy + ry * 0.42, 8 * ws, PAL.red, sp.cheek == null ? 0.22 : sp.cheek);
  }
  // 코
  const nose = F.nose || 'small';
  if (nose === 'long') p.stroke([[cx + 1 * ws, ey + 2 * ws], [cx - 1.5 * ws, ey + 12 * ws], [cx + 2.5 * ws, ey + 13 * ws]], { w: 1.5 * ws, rough: 0.2 });
  else if (nose === 'broad') {
    p.stroke([[cx + 1 * ws, ey + 3 * ws], [cx - 0.5 * ws, ey + 9 * ws]], { w: 1.3 * ws, rough: 0.2 });
    p.stroke([[cx - 5 * ws, ey + 9 * ws], [cx - 2.5 * ws, ey + 11.5 * ws], [cx, ey + 10.5 * ws], [cx + 2.5 * ws, ey + 11.5 * ws], [cx + 5 * ws, ey + 9 * ws]], { w: 1.4 * ws, rough: 0.2 });
  } else if (nose === 'hooked') p.stroke([[cx + 1 * ws, ey + 2 * ws], [cx + 2 * ws, ey + 6 * ws], [cx - 2 * ws, ey + 11 * ws], [cx + 2.5 * ws, ey + 11.5 * ws]], { w: 1.5 * ws, rough: 0.2 });
  else p.stroke([[cx + 1 * ws, ey + 3 * ws], [cx - 1.5 * ws, ey + 9.5 * ws], [cx + 2.5 * ws, ey + 10.5 * ws]], { w: 1.4 * ws, rough: 0.2 });
  // 입
  const my = hy + ry * (F.mouthY || 0.6), m = F.mouth || 'small', lip = sp.lip || '#a8453c';
  const mw = { small: 3.8, wide: 5.6, thin: 4.2, full: 4.4, smile: 4.6, frown: 4.2 }[m] || 3.8;
  const mh = { small: 1.9, wide: 1.6, thin: 0.9, full: 2.6, smile: 1.5, frown: 1.4 }[m] || 1.9;
  const cy = m === 'smile' ? -1.6 : m === 'frown' ? 1.6 : -0.3;
  p.fill(ellipsePts(cx, my, mw * ws, mh * ws, 12), lip, { smooth: false });
  p.stroke([[cx - (mw + 0.4) * ws, my + cy * ws], [cx, my + 0.4 + (m === 'smile' ? 0.6 : 0) * ws], [cx + (mw + 0.4) * ws, my + cy * ws]], { w: 1.1 * ws, rough: 0.1 });
  // 주름
  const wr = F.wrinkles || 0;
  if (wr >= 1) {
    p.stroke([[cx - 9 * ws, hy - ry * 0.42], [cx, hy - ry * 0.47], [cx + 9 * ws, hy - ry * 0.42]], { w: 1.1, color: skinD });
    p.stroke([[cx - 7 * ws, hy - ry * 0.32], [cx + 7 * ws, hy - ry * 0.32]], { w: 1.0, color: skinD });
  }
  if (wr >= 2) for (const s of [-1, 1]) {
    p.stroke([[cx + s * 5 * ws, ey + 9 * ws], [cx + s * 7.5 * ws, my - 1 * ws], [cx + s * 6.5 * ws, my + 3 * ws]], { w: 1.0, color: skinD });
    p.stroke([[cx + s * (ex + 8 * ws), ey - 1 * ws], [cx + s * (ex + 11 * ws), ey + 1 * ws]], { w: 0.9, color: skinD });
  }
  if (wr >= 3) for (const s of [-1, 1]) {
    p.stroke([[cx + s * (ex - 4 * ws), ey + 5 * ws], [cx + s * (ex + 4 * ws), ey + 5.5 * ws]], { w: 0.9, color: skinD });
    p.stroke([[cx + s * (mw + 1.5) * ws, my + 1 * ws], [cx + s * (mw + 3) * ws, my + 5 * ws]], { w: 0.9, color: skinD });
  }
  marks(p, cx, hy, rx, ry, ws, F, false, sp);
}

function faceSide(p, cx, hy, S, sp) {
  const F = sp.face || {}, ws = S.ws, rx = S.headRX, ry = S.headRY;
  const ey = hy + ry * 0.14, x = cx - rx * 0.5;
  brows(p, x, 1, ey, ws, F, true);
  eye(p, x - 1.4 * ws, 1, ey, ws * 0.92, F, sp, true);
  p.blush(cx - rx * 0.28, hy + ry * 0.42, 8 * ws, PAL.red, sp.cheek == null ? 0.22 : sp.cheek);
  const my = hy + ry * (F.mouthY || 0.6), m = F.mouth || 'small';
  const mw = m === 'wide' ? 3.4 : m === 'full' ? 3 : 2.6, mh = m === 'thin' ? 0.9 : m === 'full' ? 2.3 : 1.7;
  p.fill(ellipsePts(cx - rx * 0.76, my, mw * ws, mh * ws, 10), sp.lip || '#a8453c', { smooth: false });
  const cy = m === 'smile' ? -1.2 : m === 'frown' ? 1.2 : 0;
  p.stroke([[cx - rx * 0.92, my], [cx - rx * 0.62, my + 0.5 + cy * ws]], { w: 1.1 * ws, rough: 0.1 });
  const wr = F.wrinkles || 0, skinD = shade(sp.skin || PAL.skin, -0.45);
  if (wr >= 1) p.stroke([[cx - rx * 0.85, hy - ry * 0.42], [cx - rx * 0.2, hy - ry * 0.46]], { w: 1.0, color: skinD });
  if (wr >= 2) p.stroke([[cx - rx * 0.6, ey + 8 * ws], [cx - rx * 0.62, my + 3 * ws]], { w: 1.0, color: skinD });
  if (wr >= 2) p.stroke([[x - 9 * ws, ey - 1 * ws], [x - 12 * ws, ey + 1.5 * ws]], { w: 0.9, color: skinD });
  marks(p, cx - rx * 0.35, hy, rx * 0.6, ry, ws, F, true, sp);
}

function marks(p, cx, hy, rx, ry, ws, F, side, sp) {
  const mk = F.mark || 'none', ink = '#3a2a22';
  if (mk === 'mole_cheek') p.dot(cx + (side ? -0.1 : 0.45) * rx, hy + ry * 0.32, 1.6 * ws, ink);
  else if (mk === 'mole_lip') p.dot(cx + (side ? -0.55 : 0.22) * rx, hy + ry * 0.5, 1.4 * ws, ink);
  else if (mk === 'mole_brow') p.dot(cx + (side ? -0.2 : -0.5) * rx, hy - ry * 0.05, 1.5 * ws, ink);
  else if (mk === 'pockmark' || mk === 'freckles') {
    const c = mk === 'pockmark' ? shade(sp.skin || PAL.skin, -0.25) : '#a07850';
    for (let i = 0; i < 9; i++) {
      const s = i % 2 ? 1 : -1, a = (i * 2.399) % (PI * 2);
      p.dot(cx + (side ? -0.2 : s * 0.5) * rx + cos(a) * 4 * ws, hy + ry * 0.3 + sin(a) * 4 * ws, (mk === 'pockmark' ? 1.1 : 0.9) * ws, c);
    }
  } else if (mk === 'scar') p.stroke([[cx + (side ? -0.5 : -0.62) * rx, hy - ry * 0.25], [cx + (side ? -0.3 : -0.3) * rx, hy + ry * 0.18]], { w: 1.4 * ws, color: shade(sp.skin || PAL.skin, 0.25), rough: 0.1 });
}

function beardDraw(p, view, cx, hy, rx, ry, ws, F, hc) {
  const b = F.beard || 'none', mu = F.moustache || 'none';
  const col = F.beardColor || hc, dk = shade(col, 0.3);
  const side = view === 'side';
  if (b === 'stubble') {
    p.blush(cx - (side ? rx * 0.5 : 0), hy + ry * 0.78, rx * 0.75, '#3c322d', 0.18);
  } else if (b === 'goatee') {
    // 염소수염: 턱 끝에서 아래로 가늘게
    const x0 = side ? cx - rx * 0.7 : cx;
    p.poly([[x0 - 4 * ws, hy + ry * 0.86], [x0 + 4 * ws, hy + ry * 0.86], [x0 + 2 * ws, hy + ry + 7 * ws], [x0 - 0.5 * ws, hy + ry + 12 * ws, 'c'], [x0 - 2.5 * ws, hy + ry + 6 * ws]], col, { w: 1.4, ink: shade(col, -0.4) });
  } else if (b === 'full' || b === 'long') {
    const L = b === 'long' ? 34 : 14;
    if (side) {
      p.poly([[cx - rx * 0.85, hy + ry * 0.55], [cx - rx * 0.98, hy + ry + 6 * ws], [cx - rx * 0.75, hy + ry + L * ws, 'c'], [cx - rx * 0.1, hy + ry + 4 * ws], [cx + rx * 0.35, hy + ry * 0.45], [cx - rx * 0.15, hy + ry * 0.62]], col, { w: 1.6, ink: shade(col, -0.45) });
    } else {
      p.poly([[cx - rx * 0.86, hy + ry * 0.25], [cx - rx * 0.7, hy + ry * 0.92], [cx - 7 * ws, hy + ry + L * 0.7 * ws], [cx, hy + ry + L * ws, 'c'], [cx + 7 * ws, hy + ry + L * 0.7 * ws], [cx + rx * 0.7, hy + ry * 0.92], [cx + rx * 0.86, hy + ry * 0.25],
        [cx + rx * 0.5, hy + ry * 0.7], [cx + 5 * ws, hy + ry * 0.74], [cx - 5 * ws, hy + ry * 0.74], [cx - rx * 0.5, hy + ry * 0.7]], col, { w: 1.6, ink: shade(col, -0.45) });
      for (const s of [-1, 1]) p.stroke([[cx + s * 3 * ws, hy + ry * 0.95], [cx + s * 2 * ws, hy + ry + L * 0.6 * ws]], { w: 0.9, color: dk });
      p.fill(ellipsePts(cx, hy + ry * 0.62, 3.2 * ws, 1.6 * ws, 10), '#9a4a40', { smooth: false });
    }
  }
  if (mu !== 'none' || b === 'full' || b === 'long') {
    const kind = mu === 'none' ? 'full' : mu;
    const w = kind === 'thin' ? 1.4 : kind === 'full' ? 2.6 : 2.2;
    if (side) {
      p.stroke([[cx - rx * 0.62, hy + ry * 0.5], [cx - rx * 0.95, hy + ry * 0.55], [cx - rx * 1.02, hy + ry * (kind === 'droop' ? 0.85 : 0.62)]], { w: w * ws, color: col });
    } else for (const s of [-1, 1]) {
      const drop = kind === 'droop' ? 0.9 : 0.62;
      p.stroke([[cx + s * 1 * ws, hy + ry * 0.5], [cx + s * 7 * ws, hy + ry * 0.53], [cx + s * 11 * ws, hy + ry * drop]], { w: w * ws, color: col });
    }
  }
}

// ---------------------------------------------------------------------------
// 쓰개
// ---------------------------------------------------------------------------
function gatP(p, cx, hy, S, view, o) {
  // 갓(검은 말총)·패랭이(대오리, 짚빛): 챙 넓이 br, 대우 높이 ch, 색
  const ws = S.ws, ry = S.headRY;
  const by = hy - ry * (o.lift || 0.52), side = view === 'side';
  const bry = (side ? 3.5 : 8) * ws, br = (o.brim || 56) * ws;
  const bpath = p.ellipse(cx, by, br, bry, o.brimColor, { w: 1.8, grain: 0.6 });
  p.clip(bpath, () => { for (const k of [0.45, 0.72]) p.stroke(ellipsePts(cx, by, br * k, bry * k, 24, 0, PI), { w: 0.8, color: shade(o.brimColor, 0.3), taper: false, smooth: false }); });
  const top = by - (o.crown || 33) * ws, tw = (o.topW || 14) * ws, bw = (o.botW || 17) * ws;
  if (o.round) p.poly([[cx - bw, by, 'c'], [cx - tw, top + 5 * ws], [cx, top], [cx + tw, top + 5 * ws], [cx + bw, by, 'c']], o.color, { w: 2.2 });
  else p.poly([[cx - tw, top, 'c'], [cx + tw, top, 'c'], [cx + bw, by, 'c'], [cx - bw, by, 'c']], o.color, { w: 2.2, smooth: false });
  p.stroke([[cx - bw + 0.5, by - 4], [cx + bw - 0.5, by - 4]], { w: 2.5 * ws, color: o.band || '#1d1917', taper: false });
  if (o.beads && view === 'front') {
    for (const s of [-1, 1]) for (let i = 0; i < 10; i++) {
      const t = i / 9, rx = S.headRX;
      p.dot(cx + s * (t < 0.6 ? rx + 3 : rx + 3 - ((t - 0.6) / 0.4) * rx * 0.75), by + 5 + t * (ry * 1.6 + 30), 1.8, i % 2 ? '#7b5a3a' : '#2e2622');
    }
  } else if (o.strings && view === 'front') {
    for (const s of [-1, 1]) p.stroke([[cx + s * (S.headRX + 2), by + 2], [cx + s * S.headRX * 0.8, hy + ry * 0.6], [cx + s * S.headRX * 0.3, hy + ry + 3]], { w: 1.3, color: shade(o.color, -0.3) });
  }
}

function jeongjagwan(p, cx, hy, S, view) {
  // 정자관: 말총으로 짠 두세 층 산(山) 모양 관 — 위가 톱니처럼
  const ws = S.ws, ry = S.headRY, rx = S.headRX, col = '#2b2724', side = view === 'side';
  const by = hy - ry * 0.45, w0 = (side ? rx * 0.95 : rx + 3), h1 = 15 * ws, h2 = 12 * ws;
  const zig = (y, w, h) => {
    const pts = [[cx - w, y, 'c']], n = 4;
    for (let i = 0; i <= n; i++) pts.push([cx - w + (2 * w * i) / n, y - (i % 2 ? h * 0.62 : h), 'c']);
    pts.push([cx + w, y, 'c']);
    return pts;
  };
  p.poly(zig(by, w0, h1), col, { w: 2, smooth: false });
  p.poly(zig(by - h1 * 0.6, w0 * 0.72, h2), shade(col, 0.08), { w: 1.8, smooth: false });
  p.poly(zig(by - h1 * 0.6 - h2 * 0.6, w0 * 0.45, h2 * 0.8), shade(col, 0.14), { w: 1.6, smooth: false });
  p.stroke([[cx - w0, by - 2], [cx + w0, by - 2]], { w: 2.4 * ws, color: '#171412', taper: false });
}

function beonggeojiP(p, cx, hy, S, view, o) {
  // 벙거지·전립: 둥근 대우 + 챙(전립은 넓고 평평) + 꼭대기 붉은 술(전립은 공작 깃 대신 흰 상모)
  const ws = S.ws, ry = S.headRY, side = view === 'side';
  const by = hy - ry * 0.3, col = o.color || '#3d322a';
  const bw = (o.brim || 38) * ws;
  p.poly([[cx - bw, by + 5 * ws], [cx - bw * 0.74, by - 3 * ws], [cx + bw * 0.74, by - 3 * ws], [cx + bw, by + 5 * ws], [cx + bw * 0.52, by + (side ? 3 : 7) * ws], [cx - bw * 0.52, by + (side ? 3 : 7) * ws]], shade(col, 0.08), { w: 2.2 });
  const dome = p.poly(ellipsePts(cx, by - 1, 26 * ws, 29 * ws, 20, PI, 2 * PI).concat([[cx + 26 * ws, by + 1, 'c'], [cx - 26 * ws, by + 1, 'c']]), col, { w: 2.4, smooth: false });
  if (o.redBand !== false) p.clip(dome, () => p.stroke([[cx - 26 * ws, by - 6], [cx, by - 3], [cx + 26 * ws, by - 6]], { w: 3, color: o.bandColor || PAL.red, taper: false }));
  const ty = by - 30 * ws;
  if (o.plume) {
    p.stroke([[cx, ty], [cx + 4 * ws, ty - 14 * ws], [cx + 12 * ws, ty - 22 * ws]], { w: 4, color: '#efeadf' });
    p.stroke([[cx, ty], [cx - 3 * ws, ty - 12 * ws]], { w: 3, color: '#d8d2c4' });
  } else {
    p.stroke([[cx, ty], [cx + 7 * ws, ty - 8 * ws], [cx + 13 * ws, ty - 4 * ws]], { w: 3.4, color: PAL.red });
    p.stroke([[cx, ty], [cx - 5 * ws, ty - 9 * ws], [cx - 12 * ws, ty - 6 * ws]], { w: 3.0, color: PAL.redSoft });
  }
  p.dot(cx, ty + 1, 3.3, '#c9a449');
}

function samo(p, cx, hy, S, view) {
  // 사모: 둥근 뒷대우 + 양옆 날개(뿔)
  const ws = S.ws, ry = S.headRY, rx = S.headRX, col = '#26221f', side = view === 'side';
  const by = hy - ry * 0.4;
  if (side) {
    p.poly([[cx - rx * 0.8, by + 4], [cx - rx * 0.9, by - 10 * ws], [cx + rx * 0.2, by - 16 * ws], [cx + rx * 1.05, by - 4 * ws], [cx + rx * 1.05, by + 5]], col, { w: 2 });
    p.poly(ellipsePts(cx + rx * 0.35, by - 18 * ws, 13 * ws, 12 * ws, 16, PI, 2 * PI), shade(col, 0.1), { w: 1.8 });
    p.ellipse(cx + rx * 1.2, by - 6 * ws, 5 * ws, 10 * ws, shade(col, 0.15), { w: 1.6 });
    return;
  }
  p.poly([[cx - rx - 2, by + 4], [cx - rx, by - 10 * ws], [cx + rx, by - 10 * ws], [cx + rx + 2, by + 4]], col, { w: 2, smooth: false });
  p.poly(ellipsePts(cx, by - 10 * ws, rx * 0.7, 14 * ws, 16, PI, 2 * PI), shade(col, 0.1), { w: 1.8 });
  for (const s of [-1, 1]) p.poly([[cx + s * (rx - 2), by - 8 * ws], [cx + s * (rx + 26 * ws), by - 14 * ws], [cx + s * (rx + 30 * ws), by - 6 * ws], [cx + s * (rx - 2), by - 2 * ws]], shade(col, 0.18), { w: 1.6 });
}

function jokduri(p, cx, hy, S, view) {
  const ws = S.ws, ry = S.headRY, col = '#231f1d';
  const by = hy - ry - 4 * ws, w = (view === 'side' ? 9 : 11) * ws;
  p.poly([[cx - w, by + 2], [cx - w * 0.8, by - 12 * ws], [cx + w * 0.8, by - 12 * ws], [cx + w, by + 2]], col, { w: 1.6, smooth: false });
  for (let i = -1; i <= 1; i++) p.dot(cx + i * w * 0.55, by - 13 * ws, 1.8 * ws, i ? '#c9a449' : '#b0413e');
  p.dot(cx, by - 5 * ws, 1.6 * ws, '#6f9a86');
}

function winterCap(p, cx, hy, S, view, kind, col) {
  // 남바위(이마·귀·목덜미를 덮고 정수리는 트임, 가장자리 털) · 조바위(귀만 덮는 둥근 볼끼, 앞뒤 술·장식)
  const ws = S.ws, rx = S.headRX, ry = S.headRY, side = view === 'side', back = view === 'back';
  const fur = '#6b5238', top = hy - ry * 0.55, low = kind === 'nambawi' ? hy + ry * 0.75 : hy + ry * 0.35;
  if (side) {
    const path = p.poly([[cx - rx * 0.55, top], [cx + rx * 0.4, top - 4 * ws], [cx + rx + 4, hy - ry * 0.1], [cx + rx + 5, low + (kind === 'nambawi' ? 10 * ws : 0)], [cx + rx * 0.1, low], [cx - rx * 0.05, hy], [cx - rx * 0.5, hy - ry * 0.3]], col, { w: 2 });
    p.clip(path, () => p.stroke([[cx + rx * 0.2, top], [cx + rx * 0.6, low]], { w: 1, color: shade(col, 0.3) }));
    p.stroke([[cx - rx * 0.55, top], [cx - rx * 0.4, hy - ry * 0.25], [cx - rx * 0.05, hy + ry * 0.05], [cx + rx * 0.1, low]], { w: 4.5 * ws, color: fur, rough: 0.8 });
  } else if (back) {
    p.poly([[cx - rx - 4, top + 4], [cx, top - 2], [cx + rx + 4, top + 4], [cx + rx + 5, low + 8 * ws], [cx, low + 14 * ws], [cx - rx - 5, low + 8 * ws]], col, { w: 2 });
    if (kind === 'jobawi') { p.stroke([[cx, low + 8 * ws], [cx, low + 30 * ws]], { w: 3, color: '#b0413e' }); p.dot(cx, low + 6 * ws, 3 * ws, '#c9a449'); }
  } else {
    for (const s of [-1, 1]) {
      const path = p.poly([[cx + s * rx * 0.2, top - 3 * ws], [cx + s * (rx + 4), top + 2 * ws], [cx + s * (rx + 6), low], [cx + s * rx * 0.75, low + 4 * ws], [cx + s * rx * 0.78, hy - ry * 0.1], [cx + s * rx * 0.45, top + 5 * ws]], col, { w: 2 });
      p.clip(path, () => p.stroke([[cx + s * rx * 0.6, top], [cx + s * (rx + 2), low]], { w: 1, color: shade(col, 0.3) }));
      if (kind === 'nambawi') p.stroke([[cx + s * rx * 0.3, top + 3 * ws], [cx + s * rx * 0.85, hy - ry * 0.2], [cx + s * rx * 0.8, low + 2 * ws]], { w: 4.5 * ws, color: fur, rough: 0.8 });
    }
    p.stroke([[cx - rx * 0.3, top + 1 * ws], [cx + rx * 0.3, top + 1 * ws]], { w: 3 * ws, color: kind === 'nambawi' ? fur : col, taper: false });
    if (kind === 'jobawi') { p.dot(cx, top + 1 * ws, 3 * ws, '#c9a449'); p.stroke([[cx, top + 2 * ws], [cx - 2 * ws, top + 9 * ws]], { w: 2, color: '#b0413e' }); }
  }
}

// ---------------------------------------------------------------------------
// 머리(얼굴 + 머리카락 + 쓰개)
// ---------------------------------------------------------------------------
const HAIR_TAIL = new Set(['daenggi', 'tteokgeo']);   // 등 뒤 땋은 꼬리(리그 'braid' 부위)

export function builderHead(p, view, S, sp) {
  const ws = S.ws, rx = S.headRX, ry = S.headRY, hy = H.headY(S);
  const F = sp.face || {}, skin = sp.skin || PAL.skin, hc = sp.hairColor || PAL.hair;
  const side = view === 'side', back = view === 'back', cx = side ? 2 * ws : 0;
  const hair = sp.hairStyle || 'sangtu', hat = sp.headwear || 'none';
  const cover = sp.cloak;   // 장옷·쓰개치마가 머리를 덮음(이때 쓰개는 안 그림)

  // 비녀(쪽)
  if (!side && hair === 'jjok') p.stroke([[cx - rx - 11 * ws, hy + ry * 0.55], [cx + rx + 11 * ws, hy + ry * 0.5]], { w: 3.2, color: sp.binyeo || '#b8973f', taper: false });
  // 목
  p.poly([[cx - 7 * ws, 5], [cx + 7 * ws, 5], [cx + 6.5 * ws, hy + ry * 0.55], [cx - 6.5 * ws, hy + ry * 0.55]], side ? shade(skin, -0.08) : skin, { smooth: false, w: 1.7, blot: false });
  if (!side) for (const s of [-1, 1]) p.ellipse(cx + s * (rx - 1), hy + ry * 0.1, 5 * ws, 7.5 * ws, skin, { w: 1.7 });

  const shaved = hair === 'shaved';
  if (back) {
    if (shaved) {
      const sc = p.ellipse(cx, hy - 1, rx + 1, ry + 1, skin, { w: 2.2 });
      p.clip(sc, (g) => { g.fillStyle = 'rgba(70,80,90,0.22)'; g.fillRect(cx - rx - 2, hy - ry - 2, rx * 2 + 4, ry * 1.3); });
    } else {
      const path = p.ellipse(cx, hy - 1, rx + 2.5, ry + 2.5, hc, { w: 2.3 });
      p.clip(path, () => {
        p.stroke([[cx, hy - ry], [cx - 1, hy + ry]], { w: 1.1, color: shade(hc, 0.3) });
        H.hairStreaks(p, [[[cx - rx * 0.6, hy - ry * 0.5], [cx - rx * 0.7, hy + ry * 0.4]], [[cx + rx * 0.6, hy - ry * 0.5], [cx + rx * 0.65, hy + ry * 0.4]]], hc);
      });
      if (hair === 'bowl' || hair === 'short') {
        const pts = [];
        for (let i = 0; i <= 8; i++) pts.push([cx - rx + (i / 8) * rx * 2, hy + ry * 0.75 + (i % 2 ? 6 : 0), 'c']);
        pts.push([cx + rx, hy + ry * 0.3], [cx - rx, hy + ry * 0.3]);
        p.poly(pts, hc, { w: 1.6, smooth: false });
      }
      if (hair === 'jjok') { p.ellipse(cx, hy + ry * 0.6, 12 * ws, 9 * ws, hc, { w: 2.2 }); p.stroke([[cx - rx - 11 * ws, hy + ry * 0.55], [cx + rx + 11 * ws, hy + ry * 0.5]], { w: 3.2, color: sp.binyeo || '#b8973f', taper: false }); }
      if (hair === 'eonjeun') eonjeun(p, cx, hy, rx, ry, ws, hc, view);
      if (hair === 'sangtu') { p.ellipse(cx, hy - ry - 5 * ws, 6.5 * ws, 7.5 * ws, hc, { w: 2 }); if (sp.band) H.bandBack(p, cx, hy, rx, ry, ws, sp); }
    }
  } else if (side) {
    const nose = F.nose === 'long' ? 1.26 : F.nose === 'hooked' ? 1.24 : F.nose === 'broad' ? 1.18 : 1.2;
    const jaw = JAW[F.shape] || 1;
    p.poly([
      [cx + rx * 0.2, hy - ry], [cx - rx * 0.6, hy - ry * 0.85], [cx - rx * 0.98, hy - ry * 0.25],
      [cx - rx * 1.02, hy + ry * 0.08], [cx - rx * nose, hy + ry * 0.26], [cx - rx * 0.98, hy + ry * 0.42],
      [cx - rx * (0.86 * (0.85 + 0.15 * jaw)), hy + ry * 0.78], [cx - rx * 0.4 * jaw, hy + ry * 0.98], [cx + rx * 0.3 * jaw, hy + ry * 0.85],
      [cx + rx * 0.9, hy + ry * 0.3], [cx + rx, hy - ry * 0.3], [cx + rx * 0.7, hy - ry * 0.85],
    ], skin, { w: 2.3 });
    if (shaved) {
      p.blush(cx + rx * 0.1, hy - ry * 0.55, rx * 0.9, '#46505a', 0.2);
    } else {
      let hp;
      if (hair === 'bowl' || hair === 'short') {
        hp = [[cx - rx * 0.7, hy - ry * 0.35, 'c'], [cx - rx * 0.55, hy - ry * 0.9], [cx + rx * 0.2, hy - ry - 3], [cx + rx + 3, hy - ry * 0.3], [cx + rx + 2, hy + ry * 0.4], [cx + rx * 0.7, hy + ry * 0.75, 'c'], [cx + rx * 0.45, hy + ry * 0.5, 'c'], [cx + rx * 0.35, hy + ry * 0.6, 'c'], [cx + rx * 0.05, hy - ry * 0.15, 'c'], [cx - rx * 0.3, hy - ry * 0.25, 'c'], [cx - rx * 0.45, hy - ry * 0.15, 'c']];
      } else {
        const down = hair === 'jjok' || HAIR_TAIL.has(hair) || hair === 'eonjeun' ? 0.72 : 0.55;
        hp = [[cx - rx * 0.62, hy - ry * 0.55, 'c'], [cx - rx * 0.5, hy - ry * 0.92], [cx + rx * 0.3, hy - ry - 3], [cx + rx + 3, hy - ry * 0.25], [cx + rx + 1, hy + ry * 0.35], [cx + rx * 0.6, hy + ry * down, 'c'], [cx + rx * 0.3, hy + ry * 0.3], [cx + rx * 0.1, hy - ry * 0.3], [cx - rx * 0.3, hy - ry * 0.52]];
      }
      const hpath = p.poly(hp, hc, { w: 2.2 });
      p.clip(hpath, () => H.hairStreaks(p, [[[cx - rx * 0.3, hy - ry * 0.8], [cx + rx * 0.5, hy - ry * 0.6], [cx + rx * 0.8, hy]]], hc));
    }
    p.ellipse(cx + rx * 0.2, hy + ry * 0.12, 5 * ws, 7.5 * ws, skin, { w: 1.7 });
    p.stroke([[cx + rx * 0.22, hy + ry * 0.02], [cx + rx * 0.15, hy + ry * 0.18]], { w: 1, rough: 0.1 });
    if (hair === 'jjok') { p.ellipse(cx + rx * 0.95, hy + ry * 0.6, 9 * ws, 8.5 * ws, hc, { w: 2.1 }); p.stroke([[cx + rx * 0.55, hy + ry * 0.62], [cx + rx * 1.45, hy + ry * 0.58]], { w: 3, color: sp.binyeo || '#b8973f', taper: false }); }
    if (hair === 'eonjeun') eonjeun(p, cx, hy, rx, ry, ws, hc, view);
    if (hair === 'sangtu') { p.ellipse(cx + rx * 0.1, hy - ry - 5 * ws, 6.5 * ws, 7.5 * ws, hc, { w: 2 }); if (sp.band) H.bandSide(p, cx, hy, rx, ry, ws, sp); }
    faceSide(p, cx, hy, S, sp);
    beardDraw(p, view, cx, hy, rx, ry, ws, F, hc);
    if (sp.pipe) H.drawPipe(p, cx - rx * 0.8, hy + ry * 0.62, -1, S);
  } else {
    const face = p.poly(faceOutline(cx, hy, rx, ry, F.shape), skin, { w: 2.4, smooth: false });
    let hl = hy - ry * 0.46, sideDown = 0.1, fringe = false;
    if (hair === 'jjok' || HAIR_TAIL.has(hair) || hair === 'eonjeun') sideDown = 0.3;
    if (hair === 'bowl' || hair === 'short') { hl = hy - ry * (hair === 'short' ? 0.36 : 0.28); fringe = true; sideDown = 0.2; }
    if (shaved) {
      p.clip(face, (g) => { g.fillStyle = 'rgba(70,80,90,0.2)'; g.fillRect(cx - rx - 2, hy - ry - 2, rx * 2 + 4, ry * 0.55); });
    } else {
      const path = p.poly(H.hairCapPts(cx, hy, rx, ry, hl, sideDown, fringe), hc, { w: 2.2 });
      p.clip(path, () => {
        if (sideDown >= 0.3) p.stroke([[cx, hy - ry - 4], [cx, hl + 1]], { w: 1.3, color: shade(hc, 0.35), taper: false });
        H.hairStreaks(p, [[[cx - rx * 0.2, hy - ry], [cx - rx * 0.7, hy - ry * 0.4], [cx - rx * 0.9, hy]], [[cx + rx * 0.2, hy - ry], [cx + rx * 0.7, hy - ry * 0.4], [cx + rx * 0.9, hy]]], hc);
      });
    }
    if (hat === 'satgat') p.clip(face, (g) => { g.fillStyle = 'rgba(70,45,30,0.24)'; g.fillRect(cx - rx - 2, hy - ry - 4, rx * 2 + 4, ry * 0.5); });
    if (hair === 'sangtu') { p.ellipse(cx, hy - ry - 5 * ws, 6.5 * ws, 7.5 * ws, hc, { w: 2 }); if (sp.band) H.bandFront(p, cx, hy, rx, ry, hl, ws, sp); }
    if (hair === 'eonjeun') eonjeun(p, cx, hy, rx, ry, ws, hc, view);
    faceFront(p, cx, hy, S, sp);
    beardDraw(p, view, cx, hy, rx, ry, ws, F, hc);
    if (sp.pipe) H.drawPipe(p, cx + 3, hy + ry * 0.62, 1, S);
    if (hair === 'daenggi') H.braidFront(p, cx, hy, rx, ry, ws, sp);
    if (hat === 'satgat') for (const s of [-1, 1]) p.stroke([[cx + s * rx * 0.85, hy - ry * 0.3], [cx + s * rx * 0.75, hy + ry * 0.5], [cx + s * rx * 0.25, hy + ry + 2]], { w: 1.2, color: '#6b5a44' });
  }

  // 쓰개
  if (!cover) {
    const hcol = sp.hatColor;
    if (hat === 'meorisugeon') H.drawScarf(p, view, cx, hy, rx, ry, ws, sp.scarf || '#ebe5d6');
    else if (hat === 'satgat') H.satgat(p, cx, hy, S, sp, view);
    else if (hat === 'gat') gatP(p, cx, hy, S, view, { color: hcol || '#302b28', brimColor: shade(hcol || '#302b28', 0.18), brim: sp.gatBrim || 56, crown: 33, beads: true });
    else if (hat === 'paeraengi') gatP(p, cx, hy, S, view, { color: hcol || '#b89a5e', brimColor: shade(hcol || '#b89a5e', -0.06), brim: 40, crown: 24, topW: 12, botW: 16, round: true, band: '#6b5436', lift: 0.5, strings: true });
    else if (hat === 'beonggeoji') beonggeojiP(p, cx, hy, S, view, { color: hcol || '#3d322a' });
    else if (hat === 'jeollip') beonggeojiP(p, cx, hy, S, view, { color: hcol || '#2b2622', brim: 50, plume: true, bandColor: '#3d5a73' });
    else if (hat === 'jeongjagwan') jeongjagwan(p, cx, hy, S, view);
    else if (hat === 'samo') samo(p, cx, hy, S, view);
    else if (hat === 'jokduri') jokduri(p, cx, hy, S, view);
    else if (hat === 'nambawi' || hat === 'jobawi') winterCap(p, cx, hy, S, view, hat, hcol || (hat === 'nambawi' ? '#2e2a33' : '#5a2f4a'));
  }
  // 머리에 인 짐
  if (sp.carry === 'basket') H.drawBasket(p, cx, hy - ry - 3 * ws, S);
  else if (sp.carry === 'jar') waterJar(p, cx, hy - ry - 3 * ws, S);
}

function eonjeun(p, cx, hy, rx, ry, ws, hc, view) {
  // 얹은머리: 땋은 머리를 정수리에 둘러 얹음 — 이마 위로 두툼한 땋은 띠
  const y = hy - ry * 0.78, w = view === 'side' ? rx * 0.95 : rx + 4, h = 9 * ws;
  const path = p.poly(ellipsePts(view === 'side' ? cx + rx * 0.15 : cx, y, w, h, 18), hc, { w: 2 });
  p.clip(path, () => { for (let i = -4; i <= 4; i++) p.stroke([[cx + i * w * 0.22 - 3, y - h], [cx + i * w * 0.22 + 3, y + h]], { w: 1.1, color: shade(hc, 0.35) }); });
}

function waterJar(p, cx, topY, S) {
  // 물동이: 똬리 위 옹기 동이
  const ws = S.ws, c = '#8a5a3a';
  p.ellipse(cx, topY + 3 * ws, 12 * ws, 4 * ws, '#d8c9a3', { w: 1.4 });
  const body = p.poly([[cx - 16 * ws, topY - 2 * ws], [cx - 26 * ws, topY - 18 * ws, 'c'], [cx - 20 * ws, topY - 32 * ws], [cx - 13 * ws, topY - 36 * ws], [cx + 13 * ws, topY - 36 * ws], [cx + 20 * ws, topY - 32 * ws], [cx + 26 * ws, topY - 18 * ws, 'c'], [cx + 16 * ws, topY - 2 * ws]], c, { w: 2.2, shadeDown: 0.35 });
  p.clip(body, () => p.stroke([[cx - 24 * ws, topY - 20 * ws], [cx + 24 * ws, topY - 20 * ws]], { w: 1.2, color: shade(c, 0.3) }));
  for (const s of [-1, 1]) p.ellipse(cx + s * 25 * ws, topY - 22 * ws, 3 * ws, 4 * ws, c, { w: 1.3 });
  p.ellipse(cx, topY - 36 * ws, 13 * ws, 3 * ws, shade(c, -0.3), { w: 1.5 });
}

// ---------------------------------------------------------------------------
// 덧부위(리그에 붙임)
// ---------------------------------------------------------------------------
function paint(seed, fn) { const P = new Painter(768); P.begin(seed); fn(P); return P.end(); }
function addPart(rig, view, part) {
  const parts = rig.views[view];
  parts.push({ r0: 0, abs: false, tag: null, flip: false, far: false, ...part });
  parts.draw = parts.filter((q) => q.img).map((q, i) => ({ p: q, i })).sort((a, b) => a.p.z - b.p.z || a.i - b.i).map((e) => e.p);
}
const zOf = (rig, view, name) => (rig.views[view].find((q) => q.name === name) || { z: 0 }).z;

/** 장옷·쓰개치마(머리부터 덮어 쓰는 겉옷) — 몸통에 붙고 팔 위에 그린다 */
function cloakPart(p, view, S, sp) {
  const ws = S.ws, T = S.torso, rx = S.headRX, ry = S.headRY;
  const col = sp.cloakColor || '#4f6b52', trim = sp.cloakTrim || '#efe9da';
  const hT = -T + 2 * ws + H.headY(S);       // 몸통 좌표의 얼굴 가운데
  const len = sp.cloak === 'sseugae' ? T * 0.55 : T * 0.95;   // 쓰개치마는 허리께, 장옷은 무릎 위
  const sh = S.shHalf + 6 * ws;
  if (view === 'back') {
    const path = p.poly([[0, hT - ry - 6 * ws], [rx + 6 * ws, hT - ry * 0.4], [sh, -T + 8 * ws], [sh + 8 * ws, len * 0.3], [sh + 10 * ws, len, 'c'], [-sh - 10 * ws, len, 'c'], [-sh - 8 * ws, len * 0.3], [-sh, -T + 8 * ws], [-rx - 6 * ws, hT - ry * 0.4]], col, { w: 2.3, shadeDown: 0.3 });
    p.clip(path, () => { p.stroke([[0, hT], [0, len]], { w: 1.1, color: shade(col, -0.35) }); for (const s of [-1, 1]) p.stroke([[s * sh * 0.5, -T * 0.6], [s * sh * 0.8, len]], { w: 1, color: shade(col, -0.35) }); });
    return;
  }
  if (view === 'side') {
    const fx = -rx * 0.55;
    const path = p.poly([[fx, hT - ry - 5 * ws], [rx * 0.6, hT - ry - 6 * ws], [rx + 8 * ws, hT - ry * 0.2], [24 * ws, -T + 12 * ws], [30 * ws, len, 'c'], [-22 * ws, len, 'c'], [-24 * ws, -T + 14 * ws], [fx - 4 * ws, hT + ry * 0.9], [fx - 2 * ws, hT - ry * 0.2]], col, { w: 2.3, shadeDown: 0.3 });
    p.clip(path, () => { p.stroke([[fx, hT - ry], [fx - 4 * ws, hT + ry], [-20 * ws, len]], { w: 4 * ws, color: trim }); p.stroke([[10 * ws, -T * 0.5], [14 * ws, len]], { w: 1, color: shade(col, -0.35) }); });
    return;
  }
  // 앞: 얼굴 둘레를 두르고 양쪽으로 흘러내린 두 자락(가운데는 손으로 여밈)
  for (const s of [-1, 1]) {
    const path = p.poly([[0, hT - ry - 7 * ws], [s * (rx + 7 * ws), hT - ry * 0.5], [s * sh, -T + 8 * ws], [s * (sh + 10 * ws), len, 'c'], [s * 5 * ws, len, 'c'], [s * 6 * ws, -T + 16 * ws], [s * (rx * 0.9), hT + ry * 0.8], [s * (rx * 0.92), hT - ry * 0.3], [s * rx * 0.3, hT - ry * 0.95]], col, { w: 2.3, shadeDown: 0.3 });
    p.clip(path, () => { p.stroke([[s * rx * 0.3, hT - ry * 0.95], [s * rx * 0.92, hT - ry * 0.2], [s * rx * 0.9, hT + ry * 0.8], [s * 6 * ws, -T + 16 * ws], [s * 6 * ws, len]], { w: 4 * ws, color: trim }); });
  }
  if (sp.cloak === 'jangot') { p.poly([[-3 * ws, -T + 22 * ws], [-8 * ws, -T + 46 * ws], [-2 * ws, -T + 46 * ws]], '#a8443c', { w: 1.3 }); p.poly([[3 * ws, -T + 22 * ws], [7 * ws, -T + 42 * ws], [2 * ws, -T + 42 * ws]], '#a8443c', { w: 1.3 }); }
  // 여민 손
  for (const s of [-1, 1]) p.ellipse(s * 4 * ws, -T + 20 * ws, 5 * ws, 4.5 * ws, sp.skin || PAL.skin, { w: 1.5 });
}

/** 세조대(도포 가슴 끈)·가사(스님 어깨 띠)·좁은 띠 */
function sashPart(p, view, S, sp) {
  const ws = S.ws, T = S.torso, wa = S.waistHalf, sh = S.shHalf;
  if (sp.cord) {
    const c = sp.cord, y = -T * 0.42;
    if (view === 'side') { p.stroke([[-24 * ws, y], [22 * ws, y + 2]], { w: 2.4 * ws, color: c, taper: false }); p.stroke([[-22 * ws, y], [-24 * ws, y + 40 * ws]], { w: 1.8 * ws, color: c }); p.ellipse(-24 * ws, y + 42 * ws, 2.6 * ws, 4 * ws, c, { w: 1 }); return; }
    p.stroke([[-sh, y - 2], [sh, y - 2]], { w: 2.4 * ws, color: c, taper: false });
    if (view === 'front') for (const s of [-1, 1]) { p.stroke([[s * 6 * ws, y], [s * 8 * ws, y + 44 * ws]], { w: 1.8 * ws, color: c }); p.ellipse(s * 8 * ws, y + 46 * ws, 2.6 * ws, 4.5 * ws, c, { w: 1 }); }
  }
  if (sp.gasa) {
    const c = sp.gasa;
    if (view === 'side') { p.poly([[-14 * ws, -T + 4], [6 * ws, -T + 2], [16 * ws, -T * 0.2], [4 * ws, -T * 0.05]], c, { w: 1.6 }); return; }
    const s = view === 'back' ? -1 : 1;
    const path = p.poly([[s * sh * 0.9, -T + 2], [s * (sh * 0.9 - 14 * ws), -T + 2], [-s * (wa + 2), -T * 0.12], [-s * (wa + 2), -T * 0.12 + 16 * ws]], c, { w: 1.8, smooth: false });
    p.clip(path, () => { for (let i = 0; i < 4; i++) p.stroke([[s * (sh - 30 * ws * i * 0.6), -T + 2 + i * 14 * ws], [s * (sh - 30 * ws * i * 0.6) - s * 8 * ws, -T + 14 * ws + i * 14 * ws]], { w: 0.9, color: shade(c, -0.35), taper: false }); });
  }
}

/** 손에 든 짐(carry 동작에서만 — 손잡이 바구니·보자기) */
function handLoad(p, S, sp) {
  const ws = S.ws, L = 6 * ws;
  if (sp.handLoad === 'bojagi') {
    const c = sp.bundle || '#6b4f3a';
    p.stroke([[0, L - 4 * ws], [0, L + 8 * ws]], { w: 2.5 * ws, color: c });
    p.poly([[-14 * ws, L + 8 * ws], [14 * ws, L + 8 * ws], [17 * ws, L + 30 * ws], [-17 * ws, L + 30 * ws]], c, { w: 2 });
    return;
  }
  // 대바구니
  const c = '#b38f58';
  p.stroke([[-12 * ws, L + 14 * ws], [-6 * ws, L - 4 * ws], [6 * ws, L - 4 * ws], [12 * ws, L + 14 * ws]], { w: 2.2 * ws, color: shade(c, -0.25), taper: false });
  const b = p.poly([[-17 * ws, L + 12 * ws], [17 * ws, L + 12 * ws], [13 * ws, L + 30 * ws, 'c'], [-13 * ws, L + 30 * ws, 'c']], c, { w: 2, smooth: false });
  p.clip(b, () => { for (let i = -4; i <= 4; i++) p.stroke([[i * 4 * ws, L + 12 * ws], [i * 3.4 * ws, L + 30 * ws]], { w: 0.8, color: shade(c, -0.4), taper: false }); });
  p.poly([[-10 * ws, L + 6 * ws], [-2 * ws, L + 2 * ws], [6 * ws, L + 7 * ws], [12 * ws, L + 12 * ws], [-14 * ws, L + 12 * ws]], sp.loadColor || '#7d9651', { w: 1.3 });
}

export function extraParts(rig) {
  const sp = rig.spec, S = rig.S;
  for (const v of ['front', 'side', 'back']) {
    const side = v === 'side', back = v === 'back';
    if (sp.cord || sp.gasa) {
      const im = paint(71 + v.length, (p) => sashPart(p, v, S, sp));
      addPart(rig, v, { name: 'b_sash', parent: 'torso', at: [0, 0], z: zOf(rig, v, 'torso') + 0.05, img: im.img, ox: im.ox, oy: im.oy });
    }
    if (sp.cloak) {
      const im = paint(83 + v.length, (p) => cloakPart(p, v, S, sp));
      addPart(rig, v, { name: 'b_cloak', parent: 'torso', at: [0, 0], z: side ? 11.5 : back ? 9.6 : 6.6, img: im.img, ox: im.ox, oy: im.oy });
    }
    if (sp.handLoad) {
      const hand = side ? 'arm2_l' : back ? 'arm1_l' : 'arm2_l';
      const im = paint(97 + v.length, (p) => handLoad(p, S, sp));
      addPart(rig, v, { name: 'hand_load', parent: hand, at: [0, S.lArm + 2], z: side ? 11.06 : 6.26, img: im.img, ox: im.ox, oy: im.oy, abs: true, tag: 'alt' });
    }
  }
}

// ---------------------------------------------------------------------------
// 손 소품(sp.staff 함수로 — rigs가 손에 붙인다)
// ---------------------------------------------------------------------------
export function handItem(kind) {
  if (kind === 'longpipe') return (p, S) => {
    // 장죽: 긴 담뱃대(대통은 아래, 물부리는 위)
    const ws = S.ws;
    p.stroke([[-2, -40 * ws], [3, 70 * ws]], { w: 4.2, color: INK, taper: false });
    p.stroke([[-2, -40 * ws], [3, 70 * ws]], { w: 2.4, color: '#6d4a2c', taper: false, rough: 0 });
    p.poly([[0, 66 * ws], [9 * ws, 66 * ws], [9 * ws, 74 * ws], [1, 74 * ws]], '#a88b4a', { w: 1.3, smooth: false });
    p.poly([[-4, -46 * ws], [0, -46 * ws], [0, -38 * ws], [-3, -38 * ws]], '#c9b98a', { w: 1, smooth: false });
  };
  if (kind === 'fan') return (p, S) => {
    // 합죽선(접은 부채) — 손에 쥐고 아래로
    const ws = S.ws;
    p.poly([[-3 * ws, -6 * ws], [3 * ws, -6 * ws], [5 * ws, 40 * ws], [-5 * ws, 40 * ws]], '#e8dcbc', { w: 1.6, smooth: false });
    p.stroke([[0, -6 * ws], [0, 40 * ws]], { w: 0.8, color: '#8a6a44', taper: false });
    p.stroke([[0, 40 * ws], [2 * ws, 52 * ws]], { w: 1.5, color: '#b0413e' });
  };
  if (kind === 'roundfan') return (p, S) => {
    const ws = S.ws;
    p.stroke([[0, -4 * ws], [0, 18 * ws]], { w: 2.4, color: '#6d4a2c', taper: false });
    p.ellipse(0, 30 * ws, 14 * ws, 14 * ws, '#c9584a', { w: 1.6 });
  };
  if (kind === 'bell') return (p, S) => {
    const ws = S.ws;
    p.stroke([[0, -2 * ws], [0, 14 * ws]], { w: 2.4, color: '#6d4a2c', taper: false });
    for (let i = 0; i < 5; i++) p.ellipse((i - 2) * 4 * ws, 18 * ws + (i % 2) * 4 * ws, 3.4 * ws, 3.4 * ws, '#c9a449', { w: 1.1 });
  };
  return kind;   // 'staff'·'cane'·'ladle'·'axe' — rigs 기본
}

// ---------------------------------------------------------------------------
// 해짐·흙때
// ---------------------------------------------------------------------------
function rngL(seed) { let s = seed >>> 0 || 1; return () => { s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; }; }
function smudge(img, seed, amount, yFrom, col) {
  if (amount <= 0.02) return;
  const g = img.getContext('2d'), R = rngL(seed);
  g.save(); g.globalCompositeOperation = 'source-atop';
  const n = Math.round(4 + amount * 22);
  for (let i = 0; i < n; i++) {
    const x = R() * img.width, y = img.height * (yFrom + R() * (1 - yFrom)), r = 3 + R() * 9;
    const gr = g.createRadialGradient(x, y, 0, x, y, r);
    gr.addColorStop(0, `rgba(${col},${0.12 + amount * 0.3})`); gr.addColorStop(1, `rgba(${col},0)`);
    g.fillStyle = gr; g.fillRect(x - r, y - r, r * 2, r * 2);
  }
  // 아랫단 흙빛
  const gr = g.createLinearGradient(0, img.height * 0.82, 0, img.height);
  gr.addColorStop(0, `rgba(${col},0)`); gr.addColorStop(1, `rgba(${col},${amount * 0.35})`);
  g.fillStyle = gr; g.fillRect(0, 0, img.width, img.height);
  g.restore();
}
const DIRT = '110,84,52';
export function wearFx(sp, seed) {
  const dirt = sp.dirt || 0;
  sp.partFx = (img, name, view) => {
    if (/^(torso|skirt)$/.test(name)) smudge(img, seed + name.length * 7 + view.length, dirt * 0.8, name === 'skirt' ? 0.45 : 0.55, DIRT);
  };
  sp.limbFx = (img, name, view) => {
    if (name.startsWith('leg')) smudge(img, seed + 13 + name.length + view.length, dirt, 0.5, DIRT);
    else if (name.startsWith('arm')) smudge(img, seed + 29 + view.length, dirt * 0.5, 0.7, DIRT);
  };
}
