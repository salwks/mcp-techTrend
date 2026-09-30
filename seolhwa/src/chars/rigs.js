// 설화록 — 캐릭터 컷아웃 부위 정의(정면/뒷면/옆면) + 애니메이션 곡선
// 좌표: 픽셀, 발 중심이 원점, y는 아래가 +. 옆면은 왼쪽을 향한다(오른쪽은 좌우 반전).
// 각 부위는 피벗(관절)이 원점인 캔버스 이미지로 한 번만 그려진다.
import { Painter, PAL, INK, shade, mix, ellipsePts, limbPts, darkenCopy } from './painter.js';
import { HUMAN_ANIMS, TIGER_ANIMS, humanCombatPose, tigerCombatPose } from './anims.js';

const PI = Math.PI;
const { sin, cos, max, min, abs } = Math;

// ---------------------------------------------------------------------------
// 공용
// ---------------------------------------------------------------------------
let _painter = null;
const painter = () => (_painter || (_painter = new Painter(768)));

function hashStr(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}

/** 부위 하나를 그려 부위 목록에 추가 */
function part(list, name, parent, at, z, draw, opt = {}) {
  let img = null, ox = 0, oy = 0;
  if (draw) {
    const P = painter();
    P.begin(hashStr(name + (opt.seed || '')));
    P.lineScale = opt.ls || 1;
    P.tint = null;
    draw(P);
    ({ img, ox, oy } = P.end());
    if (opt.far) img = darkenCopy(img, 0.2);
  }
  const p = { name, parent, at, r0: opt.r0 || 0, z, img, ox, oy, abs: !!opt.abs, tag: opt.tag || null };
  list.push(p);
  return p;
}
/** 이미 그린 이미지를 재사용해 부위 추가 */
function reuse(list, src, name, parent, at, z, opt = {}) {
  const p = { name, parent, at, r0: opt.r0 || 0, z, img: opt.far ? darkenCopy(src.img, 0.2) : src.img, ox: src.ox, oy: src.oy, abs: !!opt.abs, tag: opt.tag || null };
  list.push(p);
  return p;
}
function finishView(parts) {
  parts.draw = parts.filter((p) => p.img).map((p, i) => ({ p, i })).sort((a, b) => a.p.z - b.p.z || a.i - b.i).map((e) => e.p);
  return parts;
}

// ---------------------------------------------------------------------------
// 사람
// ---------------------------------------------------------------------------
const ADULT = { hip: 132, torso: 96, neck: 8, headRX: 27, headRY: 31, shHalf: 29, waistHalf: 27, uArm: 50, lArm: 46, thigh: 60, shin: 72, legX: 12, ws: 1 };
const CHILD = { hip: 80, torso: 58, neck: 4, headRX: 24, headRY: 27, shHalf: 20, waistHalf: 18, uArm: 30, lArm: 30, thigh: 38, shin: 42, legX: 8, ws: 0.72 };

const headY = (S) => -(S.neck + S.headRY) - 4 * S.ws;

// ---- 얼굴 ----
function faceFront(p, cx, hy, S, sp) {
  const ws = S.ws, rx = S.headRX, ry = S.headRY;
  const ey = hy + ry * 0.14, ex = rx * 0.42;
  for (const s of [-1, 1]) {
    const x = cx + s * ex;
    // 눈썹: 가늘고 긴 붓선
    p.stroke([[x - s * 6 * ws, ey - 9 * ws], [x + s * 1 * ws, ey - 11.5 * ws], [x + s * 7.5 * ws, ey - 10 * ws]], { w: (sp.browW || 1.9) * ws, color: sp.browColor || INK });
    // 눈: 눈꼬리가 살짝 올라간 윗눈꺼풀 + 검은 눈동자
    p.stroke([[x - s * 5 * ws, ey + 0.8 * ws], [x + s * 0.5 * ws, ey - 2 * ws], [x + s * 6.5 * ws, ey - 1.2 * ws]], { w: 2.3 * ws, rough: 0.2 });
    p.dot(x + s * 0.6 * ws, ey + 1.1 * ws, 2.6 * ws);
    // 볼 연지
    p.blush(cx + s * rx * 0.6, hy + ry * 0.42, 8 * ws, PAL.red, sp.cheek == null ? 0.22 : sp.cheek);
  }
  // 코
  p.stroke([[cx + 1 * ws, ey + 3 * ws], [cx - 1.5 * ws, ey + 9.5 * ws], [cx + 2.5 * ws, ey + 10.5 * ws]], { w: 1.4 * ws, rough: 0.2 });
  // 입
  const my = hy + ry * 0.6;
  p.fill(ellipsePts(cx, my, 3.8 * ws, 1.9 * ws, 12), sp.lip || '#a8453c', { smooth: false });
  p.stroke([[cx - 4.2 * ws, my - 0.3], [cx, my + 0.4], [cx + 4.2 * ws, my - 0.3]], { w: 1.1 * ws, rough: 0.1 });
  if (sp.wrinkles) {
    p.stroke([[cx - 9 * ws, hy - ry * 0.42], [cx, hy - ry * 0.47], [cx + 9 * ws, hy - ry * 0.42]], { w: 1.1, color: shade(sp.skin || PAL.skin, -0.45) });
    p.stroke([[cx - 7 * ws, hy - ry * 0.32], [cx + 7 * ws, hy - ry * 0.32]], { w: 1.0, color: shade(sp.skin || PAL.skin, -0.45) });
  }
}

function faceSide(p, cx, hy, S, sp) {
  const ws = S.ws, rx = S.headRX, ry = S.headRY;
  const ey = hy + ry * 0.14, x = cx - rx * 0.5;
  p.stroke([[x + 6 * ws, ey - 9.5 * ws], [x - 1 * ws, ey - 11.5 * ws], [x - 6 * ws, ey - 9.5 * ws]], { w: (sp.browW || 1.9) * ws, color: sp.browColor || INK });
  p.stroke([[x + 4.5 * ws, ey + 0.6 * ws], [x, ey - 1.8 * ws], [x - 4.5 * ws, ey - 1.4 * ws]], { w: 2.3 * ws, rough: 0.2 });
  p.dot(x - 1.2 * ws, ey + 1.1 * ws, 2.5 * ws);
  p.blush(cx - rx * 0.28, hy + ry * 0.42, 8 * ws, PAL.red, sp.cheek == null ? 0.22 : sp.cheek);
  const my = hy + ry * 0.6;
  p.fill(ellipsePts(cx - rx * 0.76, my, 2.6 * ws, 1.7 * ws, 10), sp.lip || '#a8453c', { smooth: false });
  p.stroke([[cx - rx * 0.92, my], [cx - rx * 0.62, my + 0.5]], { w: 1.1 * ws, rough: 0.1 });
}

// ---- 머리카락 ----
function hairCapPts(cx, hy, rx, ry, hl, sideDown, fringe) {
  const pts = [];
  for (let i = 0; i <= 12; i++) {
    const a = PI - 0.25 + (i / 12) * (PI + 0.5);
    pts.push([cx + cos(a) * (rx + 2.5), hy + sin(a) * (ry + 3)]);
  }
  const sd = hy + ry * sideDown;
  pts.push([cx + rx * 0.86, sd]);
  if (fringe) {
    const n = 7;
    for (let i = 0; i <= n; i++) {
      const t = i / n, x = cx + rx * 0.8 - t * rx * 1.6;
      const y = hl + (i % 2 ? 5 : -1) + abs(t - 0.5) * 8;
      pts.push([x, y, 'c']);
    }
  } else {
    pts.push([cx + rx * 0.62, hl + 3], [cx, hl], [cx - rx * 0.62, hl + 3]);
  }
  pts.push([cx - rx * 0.86, sd]);
  return pts;
}

function hairStreaks(p, pts, col) {
  const c = shade(col, 0.28);
  for (const s of pts) p.stroke(s, { w: 1.1, color: c, rough: 0.3 });
}

// ---- 모자 ----
function satgat(p, cx, hy, S, sp, view) {
  const ws = S.ws, ry = S.headRY;
  const by = hy - ry * 0.3, W = 62 * ws, ay = by - 40 * ws;
  const col = sp.hatColor || '#5b4b37';
  if (view === 'side') {
    const path = p.poly([[cx + 5 * ws, ay, 'c'], [cx + W * 0.55, by - 17 * ws], [cx + W + 3, by - 1, 'c'], [cx + W * 0.4, by + 4 * ws], [cx - W * 0.45, by + 5 * ws], [cx - W - 3, by + 1, 'c'], [cx - W * 0.5, by - 16 * ws]], col, { w: 2.6, shadeDown: 0.3 });
    p.clip(path, () => {
      for (let i = -3; i <= 3; i++) p.stroke([[cx + 5 * ws, ay], [cx + i * W * 0.3, by + 4]], { w: 1, color: shade(col, 0.35), taper: false });
    });
    p.stroke([[cx - W * 0.9, by + 1], [cx, by + 3.5], [cx + W * 0.9, by]], { w: 1.2, color: shade(col, 0.4) });
    p.dot(cx + 5 * ws, ay + 1, 3 * ws);
    return;
  }
  const pts = [[cx, ay, 'c'], [cx + W * 0.5, by - 17 * ws], [cx + W + 2, by - 1 * ws, 'c'], [cx + W * 0.62, by + 6 * ws], [cx, by + 8.5 * ws], [cx - W * 0.62, by + 6 * ws], [cx - W - 2, by - 1 * ws, 'c'], [cx - W * 0.5, by - 17 * ws]];
  const path = p.poly(pts, col, { w: 2.7, shadeDown: 0.3 });
  p.clip(path, () => {
    // 대나무 살(방사선) + 테(동심 띠)
    for (let i = -6; i <= 6; i++) {
      const t = i / 6;
      p.stroke([[cx, ay], [cx + t * W * 1.02, by + (1 - t * t) * 8 * ws]], { w: 0.9, color: shade(col, 0.32), taper: false, rough: 0.2 });
    }
    for (const k of [0.45, 0.78]) {
      const yy = ay + (by - ay) * k;
      p.stroke([[cx - W * k * 1.02, yy + 2], [cx, yy + 6 * k * ws + 2], [cx + W * k * 1.02, yy + 2]], { w: 1.3, color: shade(col, -0.35), taper: false });
    }
  });
  p.stroke([[cx - W * 0.95, by], [cx, by + 7 * ws], [cx + W * 0.95, by]], { w: 1.1, color: shade(col, 0.45) });
  p.dot(cx, ay + 1, 3.2 * ws);
}

function gat(p, cx, hy, S, sp, view) {
  const ws = S.ws, ry = S.headRY, rx = S.headRX;
  const by = hy - ry * 0.52, col = '#302b28', brim = '#57514c';
  const side = view === 'side';
  const bry = side ? 3.5 : 8;
  const bpath = p.ellipse(cx, by, 56 * ws, bry * ws, brim, { w: 1.8, grain: 0.6 });
  p.clip(bpath, () => {
    for (const k of [0.45, 0.72]) p.stroke(ellipsePts(cx, by, 56 * k * ws, bry * k * ws, 24, 0, PI), { w: 0.8, color: shade(brim, 0.3), taper: false, smooth: false });
  });
  const top = by - 33 * ws;
  p.poly([[cx - 14 * ws, top, 'c'], [cx + 14 * ws, top, 'c'], [cx + 17 * ws, by, 'c'], [cx - 17 * ws, by, 'c']], col, { w: 2.2, smooth: false });
  p.stroke([[cx - 16.5 * ws, by - 4], [cx + 16.5 * ws, by - 4]], { w: 2.5, color: '#1d1917', taper: false });
  if (!side && view !== 'back') {
    // 갓끈(구슬)
    for (const s of [-1, 1]) {
      for (let i = 0; i < 10; i++) {
        const t = i / 9;
        const x = cx + s * (t < 0.6 ? rx + 3 : rx + 3 - ((t - 0.6) / 0.4) * rx * 0.75), y = by + 5 + t * (ry * 1.6 + 30);
        p.dot(x, y, 1.8, i % 2 ? '#7b5a3a' : '#2e2622');
      }
    }
  }
}

function beonggeoji(p, cx, hy, S, sp, view) {
  const ws = S.ws, ry = S.headRY;
  const by = hy - ry * 0.3, col = sp.hatColor || '#3d322a';
  const side = view === 'side';
  p.poly([[cx - 38 * ws, by + 5 * ws], [cx - 28 * ws, by - 3 * ws], [cx + 28 * ws, by - 3 * ws], [cx + 38 * ws, by + 5 * ws], [cx + 20 * ws, by + (side ? 3 : 7) * ws], [cx - 20 * ws, by + (side ? 3 : 7) * ws]], shade(col, 0.08), { w: 2.2 });
  const dome = p.poly(ellipsePts(cx, by - 1, 26 * ws, 29 * ws, 20, PI, 2 * PI).concat([[cx + 26 * ws, by + 1, 'c'], [cx - 26 * ws, by + 1, 'c']]), col, { w: 2.4, smooth: false });
  p.clip(dome, () => p.stroke([[cx - 26 * ws, by - 6], [cx, by - 3], [cx + 26 * ws, by - 6]], { w: 3, color: PAL.red, taper: false }));
  // 꼭대기 붉은 술
  const ty = by - 30 * ws;
  p.stroke([[cx, ty], [cx + 7 * ws, ty - 8 * ws], [cx + 13 * ws, ty - 4 * ws]], { w: 3.4, color: PAL.red });
  p.stroke([[cx, ty], [cx - 5 * ws, ty - 9 * ws], [cx - 12 * ws, ty - 6 * ws]], { w: 3.0, color: PAL.redSoft });
  p.dot(cx, ty + 1, 3.3, '#c9a449');
}

// ---- 머리 부위 ----
function drawHead(p, view, S, sp) {
  const ws = S.ws, rx = S.headRX, ry = S.headRY, hy = headY(S);
  const skin = sp.skin || PAL.skin, hc = sp.hairColor || PAL.hair;
  const side = view === 'side', back = view === 'back';
  const cx = side ? 2 * ws : 0;
  const hair = sp.hair;

  // --- 머리 뒤쪽 것들 ---
  if (!side && !back && hair === 'jjok') {
    // 비녀 끝이 머리 양옆으로 비죽
    p.stroke([[cx - rx - 11 * ws, hy + ry * 0.55], [cx + rx + 11 * ws, hy + ry * 0.5]], { w: 3.2, color: '#b8973f', taper: false });
  }
  if (back && hair === 'jjok') {
    p.stroke([[cx - rx - 11 * ws, hy + ry * 0.55], [cx + rx + 11 * ws, hy + ry * 0.5]], { w: 3.2, color: '#b8973f', taper: false });
  }

  // 목
  p.poly([[cx - 7 * ws, 5], [cx + 7 * ws, 5], [cx + 6.5 * ws, hy + ry * 0.55], [cx - 6.5 * ws, hy + ry * 0.55]], side ? shade(skin, -0.08) : skin, { smooth: false, w: 1.7, blot: false });

  // 귀
  if (!side) for (const s of [-1, 1]) p.ellipse(cx + s * (rx - 1), hy + ry * 0.1, 5 * ws, 7.5 * ws, skin, { w: 1.7 });

  if (back) {
    // 뒤통수: 머리카락
    const col = hair === 'white' ? '#8f8a82' : hc;
    const path = p.ellipse(cx, hy - 1, rx + 2.5, ry + 2.5, col, { w: 2.3 });
    p.clip(path, () => {
      p.stroke([[cx, hy - ry], [cx - 1, hy + ry]], { w: 1.1, color: shade(col, 0.3) });
      hairStreaks(p, [[[cx - rx * 0.6, hy - ry * 0.5], [cx - rx * 0.7, hy + ry * 0.4]], [[cx + rx * 0.6, hy - ry * 0.5], [cx + rx * 0.65, hy + ry * 0.4]]], col);
    });
    if (hair === 'bowl') {
      // 뒷머리 끝을 들쭉날쭉하게
      const pts = [];
      for (let i = 0; i <= 8; i++) pts.push([cx - rx + (i / 8) * rx * 2, hy + ry * 0.75 + (i % 2 ? 6 : 0), 'c']);
      pts.push([cx + rx, hy + ry * 0.3], [cx - rx, hy + ry * 0.3]);
      p.poly(pts, hc, { w: 1.6, smooth: false });
    }
    if (hair === 'jjok') p.ellipse(cx, hy + ry * 0.6, 12 * ws, 9 * ws, hc, { w: 2.2 });
    if (hair === 'sangtu') {
      p.ellipse(cx, hy - ry - 5 * ws, 6.5 * ws, 7.5 * ws, hc, { w: 2 });
      bandBack(p, cx, hy, rx, ry, ws, sp);
    }
  } else if (side) {
    // 옆얼굴
    p.poly([
      [cx + rx * 0.2, hy - ry], [cx - rx * 0.6, hy - ry * 0.85], [cx - rx * 0.98, hy - ry * 0.25],
      [cx - rx * 1.02, hy + ry * 0.08], [cx - rx * 1.2, hy + ry * 0.26], [cx - rx * 0.98, hy + ry * 0.42],
      [cx - rx * 0.86, hy + ry * 0.78], [cx - rx * 0.4, hy + ry * 0.98], [cx + rx * 0.3, hy + ry * 0.85],
      [cx + rx * 0.9, hy + ry * 0.3], [cx + rx, hy - ry * 0.3], [cx + rx * 0.7, hy - ry * 0.85],
    ], skin, { w: 2.3 });
    // 뒤·윗머리
    const col = hair === 'white' ? '#9a958c' : hc;
    let hp;
    if (hair === 'bowl') {
      hp = [[cx - rx * 0.7, hy - ry * 0.35, 'c'], [cx - rx * 0.55, hy - ry * 0.9], [cx + rx * 0.2, hy - ry - 3], [cx + rx + 3, hy - ry * 0.3], [cx + rx + 2, hy + ry * 0.4], [cx + rx * 0.7, hy + ry * 0.75, 'c'], [cx + rx * 0.45, hy + ry * 0.5, 'c'], [cx + rx * 0.35, hy + ry * 0.6, 'c'], [cx + rx * 0.05, hy - ry * 0.15, 'c'], [cx - rx * 0.3, hy - ry * 0.25, 'c'], [cx - rx * 0.45, hy - ry * 0.15, 'c']];
    } else {
      const down = hair === 'jjok' || hair === 'braid' ? 0.72 : 0.55;
      hp = [[cx - rx * 0.62, hy - ry * 0.55, 'c'], [cx - rx * 0.5, hy - ry * 0.92], [cx + rx * 0.3, hy - ry - 3], [cx + rx + 3, hy - ry * 0.25], [cx + rx + 1, hy + ry * 0.35], [cx + rx * 0.6, hy + ry * down, 'c'], [cx + rx * 0.3, hy + ry * 0.3], [cx + rx * 0.1, hy - ry * 0.3], [cx - rx * 0.3, hy - ry * 0.52]];
    }
    const hpath = p.poly(hp, col, { w: 2.2 });
    p.clip(hpath, () => hairStreaks(p, [[[cx - rx * 0.3, hy - ry * 0.8], [cx + rx * 0.5, hy - ry * 0.6], [cx + rx * 0.8, hy]]], col));
    // 귀
    p.ellipse(cx + rx * 0.2, hy + ry * 0.12, 5 * ws, 7.5 * ws, skin, { w: 1.7 });
    p.stroke([[cx + rx * 0.22, hy + ry * 0.02], [cx + rx * 0.15, hy + ry * 0.18]], { w: 1, rough: 0.1 });
    if (hair === 'jjok') p.ellipse(cx + rx * 0.95, hy + ry * 0.6, 9 * ws, 8.5 * ws, hc, { w: 2.1 });
    if (hair === 'jjok') p.stroke([[cx + rx * 0.55, hy + ry * 0.62], [cx + rx * 1.45, hy + ry * 0.58]], { w: 3, color: '#b8973f', taper: false });
    if (hair === 'sangtu') {
      p.ellipse(cx + rx * 0.1, hy - ry - 5 * ws, 6.5 * ws, 7.5 * ws, hc, { w: 2 });
      bandSide(p, cx, hy, rx, ry, ws, sp);
    }
    faceSide(p, cx, hy, S, sp);
    if (sp.beard) beardSide(p, cx, hy, rx, ry, ws);
  } else {
    // 정면
    const face = p.ellipse(cx, hy, rx, ry, skin, { w: 2.4 });
    let hl = hy - ry * 0.46, sideDown = 0.1, fringe = false;
    if (hair === 'jjok' || hair === 'braid') sideDown = 0.3;
    if (hair === 'bowl') { hl = hy - ry * 0.28; fringe = true; sideDown = 0.2; }
    if (hair !== 'white') {
      const path = p.poly(hairCapPts(cx, hy, rx, ry, hl, sideDown, fringe), hc, { w: 2.2 });
      p.clip(path, () => {
        if (hair === 'jjok' || hair === 'braid') p.stroke([[cx, hy - ry - 4], [cx, hl + 1]], { w: 1.3, color: shade(hc, 0.35), taper: false });
        hairStreaks(p, [[[cx - rx * 0.2, hy - ry], [cx - rx * 0.7, hy - ry * 0.4], [cx - rx * 0.9, hy]], [[cx + rx * 0.2, hy - ry], [cx + rx * 0.7, hy - ry * 0.4], [cx + rx * 0.9, hy]]], hc);
      });
    } else {
      for (const s of [-1, 1]) p.poly([[cx + s * rx * 0.7, hy - ry * 0.62], [cx + s * (rx + 1.5), hy - ry * 0.35], [cx + s * (rx + 1), hy], [cx + s * rx * 0.88, hy - ry * 0.3]], '#d9d5cc', { w: 1.2, ink: '#77726a' });
    }
    if (sp.hat === 'satgat') {
      // 삿갓 챙 그늘
      p.clip(face, (g) => { g.fillStyle = 'rgba(70,45,30,0.24)'; g.fillRect(cx - rx - 2, hy - ry - 4, rx * 2 + 4, ry * 0.5); });
    }
    if (hair === 'sangtu') {
      p.ellipse(cx, hy - ry - 5 * ws, 6.5 * ws, 7.5 * ws, hc, { w: 2 });
      bandFront(p, cx, hy, rx, ry, hl, ws, sp);
    }
    faceFront(p, cx, hy, S, sp);
    if (sp.beard) beardFront(p, cx, hy, rx, ry, ws);
    if (sp.stubble) p.clip(face, (g) => { g.fillStyle = 'rgba(60,50,45,0.13)'; g.beginPath(); g.ellipse(cx, hy + ry * 0.75, rx * 0.7, ry * 0.35, 0, 0, 2 * PI); g.fill(); });
    if (hair === 'braid') braidFront(p, cx, hy, rx, ry, ws, sp);
    if (sp.hat === 'satgat') {
      // 턱끈
      for (const s of [-1, 1]) p.stroke([[cx + s * rx * 0.85, hy - ry * 0.3], [cx + s * rx * 0.75, hy + ry * 0.5], [cx + s * rx * 0.25, hy + ry + 2]], { w: 1.2, color: '#6b5a44' });
    }
  }

  if (sp.hat === 'satgat') satgat(p, cx, hy, S, sp, view);
  else if (sp.hat === 'gat') gat(p, cx, hy, S, sp, view);
  else if (sp.hat === 'beonggeoji') beonggeoji(p, cx, hy, S, sp, view);
}

function bandFront(p, cx, hy, rx, ry, hl, ws, sp) {
  const c = sp.band || '#f1ece0';
  p.poly([[cx - rx - 2.5, hy - ry * 0.34], [cx, hl - 7], [cx + rx + 2.5, hy - ry * 0.34], [cx + rx + 2.5, hy - ry * 0.12], [cx, hl + 2], [cx - rx - 2.5, hy - ry * 0.12]], c, { w: 1.8 });
  p.ellipse(cx + rx + 3, hy - ry * 0.24, 4.5, 4, c, { w: 1.6 });
  p.poly([[cx + rx + 4, hy - ry * 0.2], [cx + rx + 13, hy - ry * 0.05], [cx + rx + 10, hy + ry * 0.05]], c, { w: 1.5 });
}
function bandSide(p, cx, hy, rx, ry, ws, sp) {
  const c = sp.band || '#f1ece0';
  p.poly([[cx - rx * 0.62, hy - ry * 0.62], [cx + rx * 0.3, hy - ry * 0.68], [cx + rx + 2.5, hy - ry * 0.42], [cx + rx + 2.5, hy - ry * 0.18], [cx + rx * 0.3, hy - ry * 0.42], [cx - rx * 0.72, hy - ry * 0.38]], c, { w: 1.8 });
  p.ellipse(cx + rx + 2, hy - ry * 0.3, 4.5, 4, c, { w: 1.6 });
  p.poly([[cx + rx + 3, hy - ry * 0.25], [cx + rx + 12, hy + ry * 0.05], [cx + rx + 6, hy + ry * 0.1]], c, { w: 1.5 });
}
function bandBack(p, cx, hy, rx, ry, ws, sp) {
  const c = sp.band || '#f1ece0';
  p.poly([[cx - rx - 2.5, hy - ry * 0.4], [cx, hy - ry * 0.3], [cx + rx + 2.5, hy - ry * 0.4], [cx + rx + 2.5, hy - ry * 0.16], [cx, hy - ry * 0.06], [cx - rx - 2.5, hy - ry * 0.16]], c, { w: 1.8 });
  p.ellipse(cx, hy - ry * 0.18, 5, 4.5, c, { w: 1.6 });
  p.poly([[cx - 2, hy - ry * 0.1], [cx - 8, hy + ry * 0.45], [cx - 2, hy + ry * 0.4]], c, { w: 1.5 });
  p.poly([[cx + 2, hy - ry * 0.1], [cx + 9, hy + ry * 0.38], [cx + 3, hy + ry * 0.36]], c, { w: 1.5 });
}

function beardFront(p, cx, hy, rx, ry, ws) {
  const c = '#efece4';
  p.poly([[cx - rx * 0.62, hy + ry * 0.38], [cx - rx * 0.5, hy + ry * 0.95], [cx - 6, hy + ry + 26], [cx, hy + ry + 38, 'c'], [cx + 6, hy + ry + 26], [cx + rx * 0.5, hy + ry * 0.95], [cx + rx * 0.62, hy + ry * 0.38], [cx + 5, hy + ry * 0.72], [cx - 5, hy + ry * 0.72]], c, { w: 1.7, ink: '#6f6a62' });
  for (const s of [-1, 1]) {
    p.stroke([[cx + s * 1, hy + ry * 0.5], [cx + s * 8, hy + ry * 0.55], [cx + s * 13, hy + ry * 0.8]], { w: 2.4, color: '#dcd8cf' });
    p.stroke([[cx + s * 3, hy + ry * 0.95], [cx + s * 2, hy + ry + 22]], { w: 0.9, color: '#8e897f' });
  }
  p.fill(ellipsePts(cx, hy + ry * 0.62, 3.2, 1.6, 10), '#9a4a40', { smooth: false });
}
function beardSide(p, cx, hy, rx, ry, ws) {
  const c = '#efece4';
  p.poly([[cx - rx * 0.85, hy + ry * 0.62], [cx - rx * 0.95, hy + ry + 12], [cx - rx * 0.7, hy + ry + 34, 'c'], [cx - rx * 0.2, hy + ry + 8], [cx + rx * 0.3, hy + ry * 0.55], [cx - rx * 0.2, hy + ry * 0.7]], c, { w: 1.7, ink: '#6f6a62' });
  p.stroke([[cx - rx * 0.8, hy + ry * 0.52], [cx - rx * 1.05, hy + ry * 0.7]], { w: 2.4, color: '#dcd8cf' });
}

function braidFront(p, cx, hy, rx, ry, ws, sp) {
  // 한쪽 어깨로 넘긴 댕기머리
  const hc = sp.hairColor || PAL.hair;
  const x0 = cx + rx * 0.75, y0 = hy + ry * 0.55;
  for (let i = 0; i < 5; i++) p.ellipse(x0 + i * 1.1, y0 + i * 8 * ws + 6, 5.2 * ws, 5.8 * ws, hc, { w: 1.5 });
  const ry2 = y0 + 5 * 8 * ws + 4;
  const rib = sp.ribbon || '#7d3a55';
  p.poly([[x0 - 5, ry2], [x0 + 7, ry2], [x0 + 9, ry2 + 18 * ws], [x0 + 3, ry2 + 14 * ws], [x0 - 3, ry2 + 19 * ws]], rib, { w: 1.6 });
}

// ---- 몸통 ----
function drawTorso(p, view, S, sp) {
  const ws = S.ws, T = S.torso, sh = S.shHalf, wa = S.waistHalf;
  const short = sp.top === 'short';
  const hem = short ? -T * 0.58 : 8 * ws;
  const coat = sp.coat;
  const side = view === 'side', back = view === 'back';

  if (side) {
    const bx = 2 * ws;
    const pts = short
      ? [[bx - 11 * ws, -T - 2], [bx - 20 * ws, -T + 12 * ws], [bx - 23 * ws, hem + 2], [bx + 19 * ws, hem - 1], [bx + 20 * ws, -T + 12 * ws], [bx + 10 * ws, -T - 3]]
      : [[bx - 11 * ws, -T - 2], [bx - 20 * ws, -T + 12 * ws], [bx - 23 * ws, -T * 0.45], [bx - 22 * ws, hem, 'c'], [bx + 21 * ws, hem, 'c'], [bx + 20 * ws, -T * 0.45], [bx + 20 * ws, -T + 12 * ws], [bx + 10 * ws, -T - 3]];
    const path = p.poly(pts, coat, { w: 2.4 });
    p.clip(path, () => {
      // 깃과 동정
      p.stroke([[bx - 8 * ws, -T - 2], [bx - 16 * ws, -T + 16 * ws], [bx - 22 * ws, -T + 34 * ws]], { w: 6 * ws, color: sp.collar || shade(coat, -0.15), taper: false });
      p.stroke([[bx - 7 * ws, -T - 3], [bx - 12 * ws, -T + 9 * ws]], { w: 3.5 * ws, color: '#f5f0e4', taper: false });
      if (sp.vest) vestSide(p, bx, T, hem, ws, sp);
    });
    if (sp.sash) sashSide(p, bx, ws, sp);
    if (!short) goreumSide(p, bx - 20 * ws, -T + 38 * ws, ws, sp.goreum || shade(coat, -0.12), 0.8);
    else goreumSide(p, bx - 21 * ws, -T + 30 * ws, ws, sp.goreum || PAL.red, 1.1);
    if (sp.back === 'bundle') p.stroke([[bx - 10 * ws, -T + 2], [bx - 16 * ws, -T + 30 * ws]], { w: 3.6, color: shade(sp.bundle || PAL.blue, 0.1), taper: false });
    if (sp.back === 'bow') p.stroke([[bx + 8 * ws, -T + 2], [bx - 17 * ws, -T * 0.35]], { w: 3.4, color: '#6a4a2e', taper: false });
    return;
  }

  const fl = short ? 0 : 4 * ws;
  const pts = [[-sh * 0.4, -T - 2], [-sh + 4 * ws, -T + 3], [-sh - 1, -T + 16 * ws], [-sh - 1, -T * 0.55], [-wa - 1 - fl * 0.5, -T * 0.15], [-wa - 1 - fl, hem, 'c'], [0, hem + (short ? 3 : 0)], [wa + 1 + fl, hem, 'c'], [wa + 1 + fl * 0.5, -T * 0.15], [sh + 1, -T * 0.55], [sh + 1, -T + 16 * ws], [sh - 4 * ws, -T + 3], [sh * 0.4, -T - 2]];
  const path = p.poly(pts, coat, { w: 2.4 });
  p.clip(path, () => {
    if (back) {
      p.stroke([[0, -T + 4], [0, hem]], { w: 1.2, color: shade(coat, -0.35), taper: false });
      p.stroke([[-sh * 0.45, -T], [0, -T + 5], [sh * 0.45, -T]], { w: 5 * ws, color: sp.collar || shade(coat, -0.15), taper: false });
      if (sp.vest) vestBack(p, T, hem, sh, wa, ws, sp);
    } else {
      // 속옷 V
      p.fill([[-sh * 0.42, -T - 3], [sh * 0.42, -T - 3], [-3 * ws, -T + 24 * ws]], '#f3eee2', { smooth: false });
      if (sp.vest) vestFront(p, T, hem, sh, wa, ws, sp);
      // 깃: 보는 쪽 오른쪽 목에서 왼쪽 가슴으로 (착용자 왼섶이 위)
      const kc = sp.collar || shade(coat, -0.15);
      p.poly([[sh * 0.42, -T - 3], [sh * 0.42 + 7 * ws, -T - 1], [-4 * ws, -T + 33 * ws], [-12 * ws, -T + 29 * ws]], kc, { w: 1.5, smooth: false, rough: 0.2 });
      p.stroke([[sh * 0.42 + 2 * ws, -T - 2], [-2 * ws, -T + 23 * ws]], { w: 2.6 * ws, color: '#f7f2e7', taper: false });
      p.poly([[-sh * 0.42, -T - 3], [-sh * 0.42 + 6 * ws, -T - 3], [-3 * ws, -T + 12 * ws], [-8 * ws, -T + 14 * ws]], kc, { w: 1.4, smooth: false, rough: 0.2 });
      // 옷 주름
      p.stroke([[-sh + 5 * ws, -T * 0.5], [-wa + 6 * ws, hem - 4 * ws]], { w: 1, color: shade(coat, -0.3) });
      p.stroke([[sh - 6 * ws, -T * 0.55], [wa - 5 * ws, hem - 6 * ws]], { w: 1, color: shade(coat, -0.3) });
    }
    if (sp.back === 'bundle' && !back) {
      // 보따리 매듭: 양 어깨에서 가슴으로
      const bc = sp.bundle || PAL.blue;
      p.stroke([[-sh + 3, -T + 2], [-4 * ws, -T + 40 * ws]], { w: 5 * ws, color: bc, taper: false });
      p.stroke([[sh - 3, -T + 2], [4 * ws, -T + 40 * ws]], { w: 5 * ws, color: bc, taper: false });
    }
    if (sp.back === 'bow' && !back) p.stroke([[sh - 2, -T + 2], [-wa + 2, -T * 0.15]], { w: 4.5 * ws, color: '#6a4a2e', taper: false });
  });
  if (!back) {
    if (sp.back === 'bundle') {
      const bc = sp.bundle || PAL.blue;
      p.ellipse(0, -T + 42 * ws, 6 * ws, 5 * ws, bc, { w: 1.7 });
      p.poly([[-2, -T + 44 * ws], [-9 * ws, -T + 55 * ws], [-2 * ws, -T + 52 * ws]], bc, { w: 1.4 });
      p.poly([[2, -T + 44 * ws], [8 * ws, -T + 56 * ws], [3 * ws, -T + 52 * ws]], bc, { w: 1.4 });
    }
    if (sp.sash) sashFront(p, wa, ws, sp);
    if (short) goreumFront(p, -9 * ws, -T + 30 * ws, ws, sp.goreum || PAL.red, 1.25);
    else goreumFront(p, -9 * ws, -T + 33 * ws, ws, sp.goreum || shade(coat, -0.12), 0.8);
  } else if (sp.sash) {
    p.poly([[-wa - 1, -6 * ws], [wa + 1, -6 * ws], [wa + 1, 0], [-wa - 1, 0]], sp.sash, { w: 1.6, smooth: false });
  }
}

function goreumFront(p, x, y, ws, col, len) {
  p.poly([[x + 1, y - 1], [x - 6 * ws, y + 26 * ws * len], [x - 1 * ws, y + 27 * ws * len], [x + 3, y + 2]], col, { w: 1.5, rough: 0.3 });
  p.poly([[x + 2, y - 1], [x + 5 * ws, y + 19 * ws * len], [x + 9 * ws, y + 17 * ws * len], [x + 4, y]], col, { w: 1.5, rough: 0.3 });
  p.ellipse(x + 1, y, 5 * ws, 3.8 * ws, col, { w: 1.6 });
}
function goreumSide(p, x, y, ws, col, len) {
  p.poly([[x, y], [x - 5 * ws, y + 24 * ws * len], [x - 1 * ws, y + 25 * ws * len], [x + 3, y + 2]], col, { w: 1.5, rough: 0.3 });
  p.ellipse(x, y, 4 * ws, 3.5 * ws, col, { w: 1.5 });
}
function sashFront(p, wa, ws, sp) {
  p.poly([[-wa - 1, -7 * ws], [wa + 1, -7 * ws], [wa + 1, -1], [-wa - 1, -1]], sp.sash, { w: 1.6, smooth: false });
  p.ellipse(wa * 0.55, -4 * ws, 4.5 * ws, 4 * ws, sp.sash, { w: 1.5 });
  p.stroke([[wa * 0.55, 0], [wa * 0.5, 30 * ws]], { w: 2.4 * ws, color: sp.sash, taper: false });
  p.stroke([[wa * 0.6, 0], [wa * 0.72, 26 * ws]], { w: 2.4 * ws, color: sp.sash, taper: false });
  p.poly([[wa * 0.5 - 3, 29 * ws], [wa * 0.5 + 3, 29 * ws], [wa * 0.5 + 2, 38 * ws], [wa * 0.5 - 2, 38 * ws]], shade(sp.sash, -0.1), { w: 1.2, smooth: false });
}
function sashSide(p, bx, ws, sp) {
  p.poly([[bx - 22 * ws, -7 * ws], [bx + 21 * ws, -7 * ws], [bx + 21 * ws, -1], [bx - 22 * ws, -1]], sp.sash, { w: 1.6, smooth: false });
  p.stroke([[bx - 19 * ws, -2], [bx - 21 * ws, 28 * ws]], { w: 2.4 * ws, color: sp.sash, taper: false });
}
function vestFront(p, T, hem, sh, wa, ws, sp) {
  const vc = sp.vest;
  for (const s of [-1, 1]) {
    const path = p.poly([[s * sh * 0.5, -T - 1], [s * (sh + 3), -T + 6], [s * (wa + 3), hem + 2], [s * 5 * ws, hem + 2], [s * 4 * ws, -T + 30 * ws]], vc, { w: 1.8 });
    if (sp.fur) p.clip(path, () => { for (let i = 0; i < 7; i++) p.dot(s * (8 + (i * 7) % 20) * ws, -T + 12 + i * 12 * ws, 2.2, shade(vc, -0.45)); });
  }
}
function vestBack(p, T, hem, sh, wa, ws, sp) {
  const path = p.poly([[-sh * 0.5, -T], [sh * 0.5, -T], [sh + 3, -T + 6], [wa + 3, hem + 2], [-wa - 3, hem + 2], [-sh - 3, -T + 6]], sp.vest, { w: 1.8 });
  if (sp.fur) p.clip(path, () => { for (let i = 0; i < 12; i++) p.dot(((i * 13) % 40 - 20) * ws, -T + 10 + i * 8 * ws, 2.2, shade(sp.vest, -0.45)); });
}
function vestSide(p, bx, T, hem, ws, sp) {
  const path = p.poly([[bx - 12 * ws, -T + 4], [bx + 17 * ws, -T], [bx + 19 * ws, hem + 2], [bx - 16 * ws, hem + 2], [bx - 17 * ws, -T + 30 * ws]], sp.vest, { w: 1.8 });
  if (sp.fur) p.clip(path, () => { for (let i = 0; i < 8; i++) p.dot(bx + ((i * 11) % 30 - 14) * ws, -T + 10 + i * 11 * ws, 2.2, shade(sp.vest, -0.45)); });
}

// ---- 치마 / 두루마기 아랫자락 ----
function drawSkirt(p, view, S, sp) {
  const ws = S.ws, T = S.torso, wa = S.waistHalf, sh = S.shHalf;
  const side = view === 'side', back = view === 'back';
  if (sp.bottom === 'chima') {
    const len = S.hip + T * 0.58 - 6 * ws;
    const col = sp.skirt;
    const top = side ? 21 * ws : sh - 3 * ws;
    const bot = side ? 33 * ws : sh + 16 * ws;
    let pts;
    if (side) pts = [[-top, 0], [top, 0], [top + 8 * ws, len * 0.5], [bot + 6 * ws, len, 'c'], [bot * 0.2, len + 3], [-bot + 4 * ws, len, 'c'], [-top - 6 * ws, len * 0.5]];
    else pts = [[-top, 0], [top, 0], [top + 7 * ws, len * 0.45], [bot, len, 'c'], [bot * 0.5, len + 3], [0, len + 1], [-bot * 0.5, len + 3], [-bot, len, 'c'], [-top - 7 * ws, len * 0.45]];
    const path = p.poly(pts, col, { w: 2.4, shadeDown: 0.28 });
    p.clip(path, () => {
      // 말기(가슴띠)
      p.stroke([[-top - 4, 3 * ws], [top + 4, 3 * ws]], { w: 6 * ws, color: '#f3eee2', taper: false });
      const n = side ? 4 : 6;
      for (let i = 0; i < n; i++) {
        const t = (i + 0.5) / n - 0.5;
        p.stroke([[t * top * 1.8, 8 * ws], [t * top * 2 + 1, len * 0.5], [t * bot * 2, len]], { w: 1.1, color: shade(col, -0.4) });
      }
      if (!side && !back) p.stroke([[top * 0.4, 6 * ws], [top * 0.55, len]], { w: 1.4, color: shade(col, -0.45) });
    });
    return;
  }
  // 두루마기 아랫자락 (허리 아래)
  const len = sp.robeLen || 92;
  const col = sp.coat;
  let pts;
  if (side) pts = [[-22 * ws, -4], [21 * ws, -4], [26 * ws, len * 0.5], [33 * ws, len, 'c'], [5, len + 2], [-27 * ws, len, 'c'], [-24 * ws, len * 0.5]];
  else pts = [[-wa - 4, -4], [wa + 4, -4], [wa + 11, len * 0.55], [wa + 18, len, 'c'], [0, len + 3], [-wa - 18, len, 'c'], [-wa - 11, len * 0.55]];
  const path = p.poly(pts, col, { w: 2.4, shadeDown: 0.26 });
  p.clip(path, () => {
    if (side) {
      p.stroke([[-4, 0], [-8, len * 0.5], [-10, len]], { w: 1.2, color: shade(col, -0.35) });
      p.stroke([[10, 4], [14, len]], { w: 1, color: shade(col, -0.3) });
    } else if (back) {
      p.stroke([[0, 0], [0, len]], { w: 1.2, color: shade(col, -0.35), taper: false });
      p.stroke([[-wa * 0.7, 6], [-wa - 6, len]], { w: 1, color: shade(col, -0.28) });
      p.stroke([[wa * 0.7, 6], [wa + 6, len]], { w: 1, color: shade(col, -0.28) });
    } else {
      // 섶 겹침선
      p.stroke([[4, -2], [0, len * 0.5], [-5, len + 2]], { w: 1.6, color: shade(col, -0.5) });
      p.stroke([[-wa * 0.6, 6], [-wa - 6, len]], { w: 1, color: shade(col, -0.28) });
      p.stroke([[wa * 0.7, 6], [wa + 7, len]], { w: 1, color: shade(col, -0.28) });
    }
  });
}

// ---- 팔 ----
function drawUpperArm(p, S, sp) {
  const ws = S.ws;
  p.poly(limbPts(S.uArm + 4 * ws, 17 * ws, 18 * ws), sp.coat, { w: 2.2 });
  if (sp.vest && sp.vestSleeve) p.poly(limbPts(10 * ws, 19 * ws, 20 * ws), sp.vest, { w: 1.8 });
}
function drawLowerArm(p, S, sp) {
  const ws = S.ws, L = S.lArm, skin = sp.skin || PAL.skin;
  // 손
  p.poly([[-5 * ws, L - 4 * ws], [5 * ws, L - 4 * ws], [6.5 * ws, L + 3 * ws], [3 * ws, L + 8 * ws], [-3 * ws, L + 8 * ws], [-6.5 * ws, L + 3 * ws]], skin, { w: 1.8 });
  // 배래 곡선 소매
  const path = p.poly([[-10.5 * ws, -3], [10.5 * ws, -3], [12.5 * ws, L * 0.45], [14 * ws, L - 8 * ws], [11 * ws, L - 1 * ws, 'c'], [-9 * ws, L - 1 * ws, 'c'], [-12 * ws, L - 7 * ws], [-12 * ws, L * 0.45]], sp.coat, { w: 2.2 });
  p.clip(path, () => {
    if (sp.cuff) p.stroke([[-14 * ws, L - 5 * ws], [14 * ws, L - 5 * ws]], { w: 8 * ws, color: sp.cuff, taper: false });
    p.stroke([[-3 * ws, 4], [2 * ws, L * 0.6]], { w: 1, color: shade(sp.coat, -0.3) });
  });
}

// ---- 다리 ----
function drawThigh(p, S, sp) {
  const ws = S.ws;
  const L = S.thigh + 6 * ws, pc = sp.pants || sp.coat;
  const path = p.poly([[-12 * ws, -4], [12 * ws, -4], [15 * ws, L * 0.45], [13 * ws, L - 2 * ws], [6 * ws, L + 4 * ws], [-6 * ws, L + 4 * ws], [-13 * ws, L - 2 * ws], [-15 * ws, L * 0.45]], pc, { w: 2.2 });
  p.clip(path, () => { p.stroke([[-6 * ws, L * 0.2], [-3 * ws, L * 0.8]], { w: 1, color: shade(pc, -0.3) }); p.stroke([[7 * ws, L * 0.5], [4 * ws, L * 0.95]], { w: 1, color: shade(pc, -0.3) }); });
}
function drawShin(p, S, sp, view) {
  const ws = S.ws, L = S.shin;
  const pc = sp.pants || '#e8e1ce';
  const sock = sp.sock || '#f3efe4';
  const shoe = sp.shoe || PAL.straw;
  const side = view === 'side';
  // 바지 아랫단
  const path = p.poly(limbPts(L - 12 * ws, 23 * ws, 13 * ws), pc, { w: 2.2 });
  p.clip(path, () => p.stroke([[-2 * ws, 6], [1 * ws, L - 18 * ws]], { w: 1, color: shade(pc, -0.3) }));
  if (sp.legwrap) {
    const lw = p.poly([[-10 * ws, L * 0.3], [10 * ws, L * 0.3], [8 * ws, L - 9 * ws], [-8 * ws, L - 9 * ws]], sp.legwrap, { w: 1.8, smooth: false });
    p.clip(lw, () => { for (let i = 0; i < 5; i++) p.stroke([[-10 * ws, L * 0.34 + i * 8 * ws], [10 * ws, L * 0.3 + i * 8 * ws + 6]], { w: 0.9, color: shade(sp.legwrap, -0.35), taper: false }); });
  }
  // 대님
  p.poly([[-8 * ws, L - 15 * ws], [8 * ws, L - 15 * ws], [7.5 * ws, L - 10 * ws], [-7.5 * ws, L - 10 * ws]], sp.daenim || shade(pc, -0.2), { w: 1.5, smooth: false });
  if (side) {
    // 버선 + 짚신 (버선코가 앞쪽으로 들림)
    p.poly([[5 * ws, L - 12 * ws], [6 * ws, L - 2], [-9 * ws, L - 1], [-17 * ws, L - 4 * ws, 'c'], [-22 * ws, L - 9 * ws, 'c'], [-14 * ws, L - 8 * ws], [-4 * ws, L - 12 * ws]], sock, { w: 1.9 });
    p.poly([[8 * ws, L - 4 * ws], [8 * ws, L + 1], [-17 * ws, L + 1], [-19 * ws, L - 3 * ws], [-10 * ws, L - 5 * ws]], shoe, { w: 1.8 });
  } else {
    p.poly([[-7 * ws, L - 12 * ws], [7 * ws, L - 12 * ws], [8 * ws, L - 3 * ws], [0, L - 1], [-8 * ws, L - 3 * ws]], sock, { w: 1.9 });
    p.poly(ellipsePts(0, L - 1 * ws, 9.5 * ws, 4.5 * ws, 16, 0, PI).concat([[-9.5 * ws, L - 5 * ws], [9.5 * ws, L - 5 * ws]]), shoe, { w: 1.8 });
  }
}

// ---- 등짐 / 지팡이 ----
function drawBundle(p, view, S, sp) {
  const ws = S.ws, bc = sp.bundle || PAL.blue;
  if (view === 'side') {
    const path = p.poly([[0, -2], [14 * ws, 2], [22 * ws, 20 * ws], [20 * ws, 42 * ws], [6 * ws, 50 * ws], [-2, 44 * ws]], bc, { w: 2.3 });
    p.clip(path, () => { for (let i = 0; i < 4; i++) p.stroke([[2, 10 * ws + i * 10 * ws], [22 * ws, 6 * ws + i * 11 * ws]], { w: 1.1, color: shade(bc, 0.35) }); });
    p.poly([[4, -2], [12 * ws, -12 * ws], [15 * ws, -3], [10 * ws, 3]], bc, { w: 1.6 });
    return;
  }
  const path = p.poly([[-26 * ws, 6 * ws], [0, 0], [26 * ws, 6 * ws], [30 * ws, 30 * ws], [24 * ws, 52 * ws], [0, 56 * ws], [-24 * ws, 52 * ws], [-30 * ws, 30 * ws]], bc, { w: 2.5 });
  p.clip(path, () => {
    // 격자 무늬(보자기)
    for (let i = -3; i <= 3; i++) p.stroke([[i * 9 * ws - 12, 0], [i * 9 * ws + 12, 58 * ws]], { w: 1.1, color: shade(bc, 0.35), taper: false });
    p.stroke([[-30, 28 * ws], [30, 26 * ws]], { w: 1.1, color: shade(bc, 0.35), taper: false });
    p.stroke([[-18 * ws, 10 * ws], [0, 26 * ws], [18 * ws, 10 * ws]], { w: 1.4, color: shade(bc, -0.4) });
  });
  p.ellipse(0, 4 * ws, 7 * ws, 6 * ws, shade(bc, -0.05), { w: 1.8 });
  p.poly([[-3, 2], [-13 * ws, -9 * ws], [-6 * ws, -2]], bc, { w: 1.5 });
  p.poly([[3, 2], [13 * ws, -8 * ws], [6 * ws, -1]], bc, { w: 1.5 });
}

function drawBow(p, view, S) {
  const ws = S.ws;
  const wood = '#7b5230';
  // 각궁: 대각선으로 멘 활 + 전통
  const bow = view === 'side'
    ? [[-6, -34], [6, -26], [12, 0], [10, 30], [2, 56], [-8, 62]]
    : [[-44, -30], [-40, -16], [-22, -2], [10, 22], [30, 40], [34, 54]];
  const str = view === 'side' ? [[-6, -34], [-8, 62]] : [[-44, -30], [34, 54]];
  p.stroke(str, { w: 1.1, color: '#cfc5ae', taper: false, smooth: false });
  p.stroke(bow, { w: 6.5 * ws, color: INK, taper: true });
  p.stroke(bow, { w: 3.6 * ws, color: wood, taper: true, rough: 0 });
  // 전통(화살통)
  const qx = view === 'side' ? 14 : 16, qy = -18;
  if (view !== 'front') {
    p.poly([[qx - 6, qy], [qx + 6, qy - 2], [qx + 9, qy + 40], [qx - 3, qy + 42]], '#8a6a45', { w: 1.8 });
    for (let i = 0; i < 3; i++) p.poly([[qx - 4 + i * 4, qy - 1], [qx - 6 + i * 4, qy - 14], [qx - 1 + i * 4, qy - 12], [qx + i * 4, qy - 1]], '#efe8d8', { w: 1.2 });
  } else {
    for (let i = 0; i < 3; i++) p.poly([[qx - 4 + i * 4, qy - 1], [qx - 6 + i * 4, qy - 14], [qx - 1 + i * 4, qy - 12], [qx + i * 4, qy - 1]], '#efe8d8', { w: 1.2 });
  }
}

function drawStaff(p, S, sp) {
  const ws = S.ws;
  const top = sp.staff === 'cane' ? -24 * ws : -54 * ws, bot = sp.staff === 'cane' ? 108 : 140;
  const c = sp.staff === 'cane' ? '#6d5236' : '#86653f';
  p.poly([[-2.6, top], [2.6, top], [2.2, bot], [-2.2, bot]], c, { w: 1.6, smooth: false, rough: 0.6 });
  for (const k of [0.2, 0.55, 0.8]) p.stroke([[-3.5, top + (bot - top) * k], [3.5, top + (bot - top) * k - 2]], { w: 1.4, taper: false });
  if (sp.staff === 'cane') {
    p.poly([[-3, top + 2], [-4, top - 8], [4, top - 12], [12, top - 8], [11, top - 2], [3, top - 5]], c, { w: 1.6 });
  } else {
    // 작은 호리병
    p.stroke([[2, top + 6], [8, top + 12]], { w: 1, taper: false });
    p.ellipse(9, top + 18, 4, 4, PAL.yellow, { w: 1.4 });
    p.ellipse(9, top + 27, 6, 6.5, PAL.yellow, { w: 1.5 });
  }
}

// ---- 전투 소품 ----
function drawSword(p, S) {
  const ws = S.ws;
  // 환도: 손잡이(붉은 끈) + 둥근 코등이 + 살짝 휜 외날
  p.poly([[-3.5 * ws, -12 * ws], [3.5 * ws, -12 * ws], [3.5 * ws, 12 * ws], [-3.5 * ws, 12 * ws]], '#7a2e2a', { w: 1.6, smooth: false });
  for (let i = 0; i < 4; i++) p.stroke([[-3.5 * ws, (-9 + i * 6) * ws], [3.5 * ws, (-6 + i * 6) * ws]], { w: 1, color: '#d9b36a', taper: false });
  p.ellipse(0, 14 * ws, 8 * ws, 3.2 * ws, '#b39245', { w: 1.6 });
  const L = 118 * ws;
  p.poly([[-3.4 * ws, 16 * ws], [3.2 * ws, 16 * ws], [5 * ws, L * 0.6], [3 * ws, L - 8 * ws], [-1 * ws, L + 4 * ws, 'c'], [-3.6 * ws, L * 0.6]], '#dfe3dc', { w: 2, grain: 0.3, shadeDown: 0.15 });
  p.stroke([[-0.5 * ws, 20 * ws], [0.8 * ws, L - 10 * ws]], { w: 1.1, color: '#8d968f' });
}
function drawHandBow(p, S, drawn) {
  const ws = S.ws, h = 74 * ws, b = drawn ? -20 * ws : -12 * ws, pull = drawn ? 82 * ws : 3 * ws;
  const bow = [[6 * ws, -h - 4], [0, -h + 6], [b, -h * 0.4], [b - 2, 0], [b, h * 0.4], [0, h - 6], [6 * ws, h + 4]];
  p.stroke(drawn ? [[4 * ws, -h + 2], [pull, 0], [4 * ws, h - 2]] : [[4 * ws, -h + 2], [pull, 0], [4 * ws, h - 2]], { w: 1.2, color: '#d8ceb6', taper: false, smooth: false });
  p.stroke(bow, { w: 7 * ws, color: INK });
  p.stroke(bow, { w: 4 * ws, color: '#7b5230', rough: 0 });
  p.poly([[b - 5, -7 * ws], [b + 5, -7 * ws], [b + 5, 7 * ws], [b - 5, 7 * ws]], '#c9a449', { w: 1.3, smooth: false });
  if (drawn) {
    // 시위에 건 화살
    p.stroke([[pull, 0], [b - 38 * ws, 0]], { w: 2.4 * ws, color: '#6b5236', taper: false });
    p.poly([[b - 46 * ws, 0, 'c'], [b - 34 * ws, -5 * ws], [b - 36 * ws, 0], [b - 34 * ws, 5 * ws]], '#9aa19a', { w: 1.3, smooth: false });
    p.poly([[pull - 2, 0], [pull - 16 * ws, -7 * ws], [pull - 10 * ws, 0], [pull - 16 * ws, 7 * ws]], '#efe8d8', { w: 1.1, smooth: false });
  }
}
function drawRiceCake(p, S) {
  const ws = S.ws;
  p.poly([[-9 * ws, -6 * ws], [9 * ws, -7 * ws], [10 * ws, 6 * ws], [-9 * ws, 7 * ws]], '#f6f1e6', { w: 2 });
  p.ellipse(0, 0, 3 * ws, 2.5 * ws, '#d87d86', { w: 0.8 });
}
/** 베기 궤적(먹 붓질 초승달) — 피벗은 어깨 */
function drawSlash(p, S) {
  const ws = S.ws, R = 122 * ws;
  const arc = ellipsePts(0, 0, R, R, 36, -1.6, -3.95);
  p.stroke(arc, { w: 17 * ws, color: INK });
  p.stroke(ellipsePts(0, 0, R - 3 * ws, R - 3 * ws, 30, -1.9, -3.7), { w: 5 * ws, color: '#f3efe3' });
  p.stroke(ellipsePts(0, 0, R - 20 * ws, R - 20 * ws, 24, -2.1, -3.5), { w: 4 * ws, color: INK });
}
function drawStreak(p, S) {
  const ws = S.ws;
  p.stroke([[-40 * ws, 0], [-150 * ws, -1], [-250 * ws, 0]], { w: 12 * ws, color: INK });
  p.stroke([[-60 * ws, 0], [-220 * ws, 0]], { w: 3.5 * ws, color: '#f3efe3' });
  p.stroke([[-50 * ws, -16 * ws], [-170 * ws, -14 * ws]], { w: 3 * ws, color: INK });
  p.stroke([[-50 * ws, 16 * ws], [-160 * ws, 15 * ws]], { w: 3 * ws, color: INK });
}
function drawBurst(p, S) {
  const ws = S.ws;
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * PI * 2 + (i % 2) * 0.12, r0 = 22 * ws, r1 = (i % 2 ? 52 : 70) * ws;
    p.stroke([[cos(a) * r0, sin(a) * r0], [cos(a) * r1, sin(a) * r1]], { w: (i % 2 ? 4 : 7) * ws, color: INK });
  }
}
function drawClaw(p) {
  // 앞발 할퀴기 자국 세 줄
  for (let i = 0; i < 3; i++) {
    const o = i * 16;
    p.stroke([[-30 + o, -70 + o * 0.3], [-12 + o, -20 + o * 0.2], [4 + o, 30], [10 + o, 58 - o * 0.3]], { w: 10, color: INK });
    p.stroke([[-24 + o, -60 + o * 0.3], [-9 + o, -18 + o * 0.2], [5 + o, 26]], { w: 3, color: '#f3efe3' });
  }
}

function addCombatParts(L, view, S, sp, ls) {
  const ws = S.ws, T = S.torso;
  const side = view === 'side', back = view === 'back';
  const hand = side ? 'arm2_l' : back ? 'arm1_l' : 'arm2_l';
  const handZ = side ? 10.95 : 6.15;
  part(L, 'sword', hand, [0, S.lArm + 2], handZ, (p) => drawSword(p, S), { ls, tag: 'sword' });
  part(L, 'bowR', hand, [0, S.lArm + 2], handZ + 0.02, (p) => drawHandBow(p, S, false), { ls, tag: 'alt', abs: true });
  part(L, 'bowD', hand, [0, S.lArm + 2], handZ + 0.02, (p) => drawHandBow(p, S, true), { ls, tag: 'alt', abs: true });
  part(L, 'item', hand, [0, S.lArm + 4], handZ + 0.1, (p) => drawRiceCake(p, S), { ls, tag: 'alt' });
  if (sp.back !== 'bow') {
    // 싸울 때 등에 멘 활
    if (back) part(L, 'pack2', 'torso', [0, -T + 30 * ws], 9.5, (p) => drawBow(p, view, S), { ls, tag: 'backbow' });
    else if (side) part(L, 'pack2', 'torso', [14 * ws, -T + 26 * ws], 1.5, (p) => drawBow(p, view, S), { ls, tag: 'backbow' });
    else part(L, 'pack2', 'torso', [0, -T + 30 * ws], 0.5, (p) => drawBow(p, view, S), { ls, tag: 'backbow' });
  }
  const sh = [0, -T + 10 * ws];
  part(L, 'fx_slash', 'torso', sh, 14, (p) => drawSlash(p, S), { ls, tag: 'fx' });
  part(L, 'fx_streak', 'torso', sh, 14, (p) => drawStreak(p, S), { ls, tag: 'fx' });
  part(L, 'fx_burst', 'torso', [0, -T * 0.4], 14, (p) => drawBurst(p, S), { ls, tag: 'fx' });
}

// ---- 사람 조립 ----
function humanView(view, S, sp) {
  const ws = S.ws, T = S.torso;
  const ls = S === CHILD ? 0.82 : 1;
  const L = [];
  const side = view === 'side', back = view === 'back';
  part(L, 'root', null, [0, -S.hip], 0, null);
  part(L, 'torso', 'root', [0, 0], side ? 8 : 5, (p) => drawTorso(p, view, S, sp), { ls, seed: view });
  const skirtAt = sp.bottom === 'chima' ? [0, -T * 0.58 + 3 * ws] : [0, 0];
  const hasSkirt = sp.bottom === 'chima' || sp.top === 'durumagi';
  part(L, 'head', 'torso', [side ? -3 * ws : 0, -T + (side ? 5 : 2) * ws], side ? 9 : 7, (p) => drawHead(p, view, S, sp), { ls, seed: view + 'h' });

  // 팔 (정면/뒷면: arm1=화면 왼쪽, arm2=화면 오른쪽 / 옆면: arm1=먼 팔, arm2=가까운 팔)
  const up = [], lo = [];
  const P = painter();
  P.begin(11); P.lineScale = ls; P.tint = null; drawUpperArm(P, S, sp); up.push(P.end());
  P.begin(12); drawLowerArm(P, S, sp); lo.push(P.end());
  const shY = -T + 7 * ws;
  if (side) {
    reuse(L, up[0], 'arm1', 'torso', [6 * ws, shY], 0.9, { far: true, r0: 0.1 });
    reuse(L, lo[0], 'arm1_l', 'arm1', [0, S.uArm], 1, { far: true, r0: 0.15 });
    reuse(L, up[0], 'arm2', 'torso', [0, shY], 10.9, { r0: 0.06 });
    reuse(L, lo[0], 'arm2_l', 'arm2', [0, S.uArm], 11, { r0: 0.12 });
  } else {
    reuse(L, up[0], 'arm1', 'torso', [-S.shHalf + 5 * ws, shY], 6.1, { r0: 0.14 });
    reuse(L, lo[0], 'arm1_l', 'arm1', [0, S.uArm], 6.2, { r0: -0.08 });
    reuse(L, up[0], 'arm2', 'torso', [S.shHalf - 5 * ws, shY], 6.1, { r0: -0.14 });
    reuse(L, lo[0], 'arm2_l', 'arm2', [0, S.uArm], 6.2, { r0: 0.08 });
  }

  // 다리
  P.begin(21); drawThigh(P, S, sp); const th = P.end();
  P.begin(22); drawShin(P, S, sp, view); const sn = P.end();
  if (side) {
    reuse(L, th, 'leg1', 'root', [4 * ws, -2], 3, { far: true });
    reuse(L, sn, 'leg1_l', 'leg1', [0, S.thigh], 2.9, { far: true });
    reuse(L, th, 'leg2', 'root', [-3 * ws, -2], 5);
    reuse(L, sn, 'leg2_l', 'leg2', [0, S.thigh], 4.9);
  } else {
    reuse(L, th, 'leg1', 'root', [-S.legX, -2], 2);
    reuse(L, sn, 'leg1_l', 'leg1', [0, S.thigh], 1);
    reuse(L, th, 'leg2', 'root', [S.legX, -2], 2);
    reuse(L, sn, 'leg2_l', 'leg2', [0, S.thigh], 1);
  }
  if (hasSkirt) part(L, 'skirt', 'root', skirtAt, side ? 7 : 3, (p) => drawSkirt(p, view, S, sp), { ls, seed: view + 's' });

  // 등짐
  if (sp.back === 'bundle') {
    if (back) part(L, 'pack', 'torso', [0, -T + 6 * ws], 9, (p) => drawBundle(p, view, S, sp), { ls });
    else if (side) part(L, 'pack', 'torso', [17 * ws, -T + 8 * ws], 2, (p) => drawBundle(p, view, S, sp), { ls });
  } else if (sp.back === 'bow') {
    if (back) part(L, 'pack', 'torso', [0, -T + 34], 9, (p) => drawBow(p, view, S), { ls, tag: 'backbow' });
    else if (side) part(L, 'pack', 'torso', [18 * ws, -T + 30], 2, (p) => drawBow(p, view, S), { ls, tag: 'backbow' });
    else part(L, 'pack', 'torso', [0, -T + 34], 0.5, (p) => drawBow(p, view, S), { ls, tag: 'backbow' });
  }
  // 땋은 머리(옆·뒤에서 흔들림)
  if (sp.hair === 'braid' && view !== 'front') {
    const hy = headY(S);
    part(L, 'braid', 'head', side ? [S.headRX * 0.75, hy + S.headRY * 0.55] : [0, hy + S.headRY * 0.6], side ? 8.5 : 8, (p) => {
      const hc = sp.hairColor || PAL.hair;
      for (let i = 0; i < 6; i++) p.ellipse(0, i * 8 * ws + 2, 5.4 * ws, 6 * ws, hc, { w: 1.5 });
      const y = 6 * 8 * ws;
      p.poly([[-6, y - 2], [6, y - 2], [9, y + 20 * ws], [2, y + 15 * ws], [-5, y + 21 * ws]], sp.ribbon || '#7d3a55', { w: 1.6 });
    }, { ls });
  }
  // 지팡이
  if (sp.staff) {
    const hand = side ? 'arm2_l' : back ? 'arm1_l' : 'arm2_l';
    part(L, 'staff', hand, [0, S.lArm + 2], side ? 10.95 : 6.15, (p) => drawStaff(p, S, sp), { abs: true, ls, tag: 'staff' });
  }
  addCombatParts(L, view, S, sp, ls);
  return finishView(L);
}

// ---- 사람 애니메이션 ----
function humanPose(view, anim, t, rig, at = t, st = {}) {
  const C = humanCombatPose(view, anim, t, at, rig);
  if (C) return C;
  const P = humanBasePose(view, anim, t, rig);
  if (st.armed) {
    // 칼을 든 채 걷기·대기: 칼끝이 앞쪽 아래를 향함
    const sw = P.sword || (P.sword = { r: 0, x: 0, y: 0, sx: 1, sy: 1 });
    sw.r += view === 'side' ? 0.6 : view === 'back' ? 0.35 : -0.35;
  }
  return P;
}

function humanBasePose(view, anim, t, rig) {
  const sp = rig.spec, k = rig.S.ws;
  const P = {};
  const set = (n, r = 0, x = 0, y = 0, sx = 1, sy = 1) => (P[n] = { r, x, y, sx, sy });
  const stoop = sp.stoop || 0;
  const run = anim === 'run', walk = anim === 'walk' || run;
  const period = (run ? 0.6 : 0.95) * (sp.child ? 0.82 : 1) * (stoop ? 1.2 : 1);
  const ph = (t / period) * PI * 2, s = sin(ph), c = cos(ph);
  const br = sin((t / 3.2) * PI * 2);
  const side = view === 'side';
  const gestArmSide = sp.staff ? 'arm1' : 'arm2';

  if (side) {
    if (walk) {
      const A = (run ? 0.72 : 0.42) * (sp.bottom === 'chima' ? 0.6 : 1);
      set('leg2', A * s);
      set('leg2_l', -(run ? 1.2 : 0.55) * max(0, c));
      set('leg1', -A * s);
      set('leg1_l', -(run ? 1.2 : 0.55) * max(0, -c));
      set('arm2', -0.7 * A * s, 0, 0);
      set('arm2_l', (run ? 0.9 : 0.12) + 0.2 * max(0, -s));
      set('arm1', 0.7 * A * s);
      set('arm1_l', (run ? 0.9 : 0.12) + 0.2 * max(0, s));
      set('root', 0, 0, -(1 - abs(s)) * (run ? 7 : 4) * k);
      set('torso', (run ? -0.16 : -0.04) - stoop);
      set('head', (run ? 0.1 : 0.02) + stoop * 0.7 + 0.02 * sin(ph * 2));
      set('skirt', (sp.bottom === 'chima' ? 0.4 : 0.22) * A * sin(ph - 0.7) - (run ? 0.06 : 0), 0, 0, 1 + 0.1 * abs(s));
      set('braid', -(run ? 0.55 : 0.2) + 0.12 * sin(ph * 2 - 1));
      set('pack', 0.04 * sin(ph * 2 - 0.8));
      set('staff', 0.12 * s);
    } else {
      set('torso', -stoop, 0, 0, 1, 1 + 0.013 * br);
      set('head', stoop * 0.7, 0, -1.2 * br * k);
      set('arm1', 0.02 * br); set('arm2', -0.02 * br);
      set('skirt', 0, 0, 0, 1 + 0.01 * br);
      set('braid', 0.04 * sin(t * 1.3));
      set('staff', 0.05);
      if (anim === 'talk') {
        const g = sin(t * PI * 2 * 0.9);
        set('head', stoop * 0.7 + 0.05 * sin(t * PI * 2 * 1.7), 0, -1.2 * br * k);
        set(gestArmSide, 0.5 + 0.1 * g);
        set(gestArmSide + '_l', 0.9 + 0.25 * g);
      }
    }
  } else {
    const flip = view === 'back' ? -1 : 1;
    if (walk) {
      const lift = (run ? 9 : 5) * k;
      const l1 = max(0, s) * lift, l2 = max(0, -s) * lift;
      set('leg1', 0.05 * s, 0, -l1, 1, 1);
      set('leg1_l', -0.04 * s, 0, 0, 1, 1 - 0.06 * max(0, s));
      set('leg2', 0.05 * s, 0, -l2, 1, 1);
      set('leg2_l', -0.04 * s, 0, 0, 1, 1 - 0.06 * max(0, -s));
      const as = run ? 0.25 : 0.12;
      set('arm1', as * 0.5 * s + (run ? 0.15 : 0), 0, 0, 1, 1 - as * 0.6 * max(0, -s * flip));
      set('arm2', as * 0.5 * s - (run ? 0.15 : 0), 0, 0, 1, 1 - as * 0.6 * max(0, s * flip));
      set('arm1_l', run ? -0.5 : 0); set('arm2_l', run ? 0.5 : 0);
      set('root', 0, 1.5 * s * k, -(1 - abs(s)) * (run ? 6 : 3.5) * k);
      set('torso', 0.02 * s, 0, 0, 1, stoop ? 0.95 : 1);
      set('head', -0.03 * s, 0, stoop ? 6 : 0);
      set('skirt', 0.035 * s, 0, 0, 1 + 0.035 * abs(s));
      set('braid', 0.07 * s);
      set('pack', -0.03 * s);
      set('staff', 0.06 * s);
    } else {
      set('torso', 0, 0, 0, 1, (stoop ? 0.95 : 1) + 0.013 * br);
      set('head', 0.01 * sin(t * 0.7), 0, (stoop ? 6 : 0) - 1.2 * br * k);
      set('arm1', 0.02 * br); set('arm2', -0.02 * br);
      set('skirt', 0, 0, 0, 1 + 0.008 * br);
      set('braid', 0.03 * sin(t * 1.3));
      if (anim === 'talk') {
        const g = sin(t * PI * 2 * 0.9);
        set('head', 0.05 * sin(t * PI * 2 * 1.7), 0, (stoop ? 6 : 0) - 1.2 * br * k);
        set('arm1', 0.22 + 0.06 * g);
        set('arm1_l', -1.3 + 0.3 * g, 0, 0, 1, 0.85);
      }
    }
  }
  return P;
}

// ---------------------------------------------------------------------------
// 호랑이 (민화 까치호랑이)
// ---------------------------------------------------------------------------
const TIGER = {
  body: '#d6a24e',
  belly: '#f0e4c8',
  stripe: '#231c17',
  eyeW: '#f3e7b5',
};

function stripeClip(p, path, lines, w = 7) {
  p.clip(path, () => { for (const l of lines) p.stroke(l, { w, color: TIGER.stripe }); });
}

function tigerFace(p, cx, cy, sc = 1, turned = 0, mode = 'normal') {
  // 크고 둥근 머리, 볼 털, 부리부리한 눈
  const R = (x, y) => [cx + x * sc + turned * (1 - abs(y) / 60) * 4, cy + y * sc];
  // 귀
  for (const s of [-1, 1]) {
    p.ellipse(cx + s * 40 * sc, cy - 40 * sc, 15 * sc, 14 * sc, TIGER.body, { w: 2.6 });
    p.ellipse(cx + s * 40 * sc, cy - 38 * sc, 8 * sc, 7 * sc, '#3a2a22', { w: 1.4 });
  }
  const head = [];
  const n = 26;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * PI * 2;
    let r = 1;
    // 아래쪽 볼 털 들쭉날쭉
    const tuft = sin(a) > 0.1 && abs(cos(a)) > 0.45 ? (i % 2 ? (mode === 'roar' ? 1.22 : 1.1) : 0.98) : 1;
    r *= tuft;
    head.push([cx + cos(a) * 56 * sc * r, cy + sin(a) * 46 * sc * r + (sin(a) > 0 ? 4 * sc : 0), tuft !== 1 ? 'c' : undefined].filter((v) => v !== undefined));
  }
  const hp = p.poly(head, TIGER.body, { w: 3, shadeDown: 0.25 });
  // 얼굴 줄무늬
  stripeClip(p, hp, [
    [R(-12, -40), R(-6, -30), R(-12, -22)], [R(0, -44), R(0, -28)], [R(12, -40), R(6, -30), R(12, -22)],
    [R(-56, -10), R(-40, -8), R(-34, 0)], [R(56, -10), R(40, -8), R(34, 0)],
    [R(-58, 8), R(-44, 10), R(-40, 18)], [R(58, 8), R(44, 10), R(40, 18)],
    [R(-38, -34), R(-30, -22)], [R(38, -34), R(30, -22)],
  ], 5.5 * sc);
  // 흰 주둥이 볼
  for (const s of [-1, 1]) p.ellipse(cx + s * 13 * sc, cy + 20 * sc, 17 * sc, 13 * sc, TIGER.belly, { w: 2 });
  p.ellipse(cx, cy + 34 * sc, 12 * sc, 7 * sc, TIGER.belly, { w: 1.8 });
  const roar = mode === 'roar', dead = mode === 'dead';
  // 수염 점
  for (const s of [-1, 1]) for (let i = 0; i < 3; i++) p.dot(cx + s * (8 + i * 6) * sc, cy + (18 + (i % 2) * 5) * sc, 1.4 * sc);
  // 코
  p.poly([[cx - 9 * sc, cy + 5 * sc], [cx + 9 * sc, cy + 5 * sc], [cx, cy + 14 * sc, 'c']], '#4a302a', { w: 2 });
  if (roar) {
    // 쩍 벌린 입 + 위아래 송곳니 + 혀
    p.poly([[cx - 22 * sc, cy + 24 * sc], [cx, cy + 20 * sc], [cx + 22 * sc, cy + 24 * sc], [cx + 18 * sc, cy + 52 * sc], [cx, cy + 62 * sc], [cx - 18 * sc, cy + 52 * sc]], '#6e1f1c', { w: 3 });
    p.ellipse(cx, cy + 50 * sc, 11 * sc, 7 * sc, '#c0584f', { w: 1.4, ink: '#4a1512' });
    for (const s of [-1, 1]) {
      p.poly([[cx + s * 10 * sc, cy + 23 * sc], [cx + s * 18 * sc, cy + 24 * sc], [cx + s * 13 * sc, cy + 38 * sc, 'c']], '#fbf6e8', { w: 1.4, smooth: false });
      p.poly([[cx + s * 9 * sc, cy + 56 * sc], [cx + s * 16 * sc, cy + 53 * sc], [cx + s * 13 * sc, cy + 44 * sc, 'c']], '#fbf6e8', { w: 1.4, smooth: false });
    }
  } else if (dead) {
    p.stroke([[cx - 14 * sc, cy + 32 * sc], [cx, cy + 30 * sc], [cx + 14 * sc, cy + 32 * sc]], { w: 2.2 * sc });
    p.ellipse(cx + 5 * sc, cy + 38 * sc, 5 * sc, 7 * sc, '#c0584f', { w: 1.4 });
  } else {
    // 입(송곳니 살짝)
    p.stroke([[cx - 18 * sc, cy + 30 * sc], [cx - 6 * sc, cy + 34 * sc], [cx, cy + 30 * sc], [cx + 6 * sc, cy + 34 * sc], [cx + 18 * sc, cy + 30 * sc]], { w: 2.2 * sc });
    for (const s of [-1, 1]) p.poly([[cx + s * 5 * sc, cy + 33 * sc], [cx + s * 10 * sc, cy + 32 * sc], [cx + s * 7 * sc, cy + 40 * sc, 'c']], '#fbf6e8', { w: 1.3, smooth: false });
  }
  for (const s of [-1, 1]) {
    const ex = cx + s * 21 * sc, ey = cy - 6 * sc;
    if (dead) {
      // 감은 눈
      p.stroke([[cx + s * 10 * sc, cy - 20 * sc], [cx + s * 22 * sc, cy - 22 * sc], [cx + s * 34 * sc, cy - 18 * sc]], { w: 3 * sc, color: '#6b4a2c' });
      p.stroke([[ex - 11 * sc, ey - 2 * sc], [ex, ey + 5 * sc], [ex + 11 * sc, ey - 2 * sc]], { w: 3 * sc });
      continue;
    }
    // 눈썹: 포효 땐 안쪽으로 치켜 내린 성난 눈썹
    if (roar) p.stroke([[cx + s * 6 * sc, cy - 12 * sc], [cx + s * 22 * sc, cy - 22 * sc], [cx + s * 42 * sc, cy - 30 * sc]], { w: 6 * sc });
    else p.stroke([[cx + s * 8 * sc, cy - 16 * sc], [cx + s * 22 * sc, cy - 24 * sc], [cx + s * 38 * sc, cy - 18 * sc]], { w: 4.5 * sc });
    // 눈: 둥근 황금빛 눈 + 사팔뜨기 같은 검은 동자
    p.ellipse(ex, ey, 13 * sc, 12 * sc, TIGER.eyeW, { w: 3.2, grain: 0.4 });
    p.ellipse(ex, ey, 8 * sc, 8 * sc, '#c98a2c', { w: 1.2, grain: 0.3, blot: false });
    p.dot(cx + s * (roar ? 21 : 18) * sc, cy - (roar ? 5 : 7) * sc, (roar ? 3 : 5) * sc, '#15100d');
    if (!roar) p.dot(cx + s * 16 * sc, cy - 9.5 * sc, 1.7 * sc, '#fff8e8');
  }
  // 긴 수염 (포효 땐 위로 뻗침)
  for (const s of [-1, 1]) {
    for (let i = 0; i < 3; i++) {
      if (roar) p.stroke([[cx + s * 22 * sc, cy + (18 + i * 5) * sc], [cx + s * (54 + i * 6) * sc, cy + (0 + i * 6) * sc], [cx + s * (82 + i * 4) * sc, cy + (-16 + i * 12) * sc]], { w: 1.6, color: '#2b221c' });
      else if (dead) p.stroke([[cx + s * 22 * sc, cy + (18 + i * 5) * sc], [cx + s * (46 + i * 6) * sc, cy + (26 + i * 10) * sc], [cx + s * (62 + i * 4) * sc, cy + (40 + i * 14) * sc]], { w: 1.2, color: '#3b3029' });
      else p.stroke([[cx + s * 22 * sc, cy + (18 + i * 5) * sc], [cx + s * (50 + i * 6) * sc, cy + (12 + i * 10) * sc], [cx + s * (72 + i * 4) * sc, cy + (14 + i * 14) * sc]], { w: 1.2, color: '#3b3029' });
    }
  }
  if (roar) {
    // 포효의 기운: 입 앞 먹선 물결
    for (let i = 0; i < 3; i++) {
      const r = (70 + i * 16) * sc;
      p.stroke(ellipsePts(cx, cy + 34 * sc, r, r * 0.55, 20, PI * 0.2, PI * 0.8), { w: 4 - i, color: INK });
    }
  }
}

function tigerLeg(p, len, w0, w1, stripes = 3, paw = false, pawDir = -1, front = false) {
  const path = p.poly(limbPts(len, w0, w1), TIGER.body, { w: 2.6 });
  const lines = [];
  for (let i = 0; i < stripes; i++) {
    const y = len * (0.22 + i * 0.24);
    lines.push([[-w0 / 2 - 2, y], [-w0 * 0.1, y + 4], [w0 * 0.05, y + 1]]);
    lines.push([[w0 / 2 + 2, y + 8], [w0 * 0.15, y + 11]]);
  }
  stripeClip(p, path, lines, 5);
  if (paw) {
    const px = front ? 0 : pawDir * 7;
    p.ellipse(px, len + 3, front ? w1 * 0.8 : w1 * 0.95, front ? w1 * 0.45 : w1 * 0.42, TIGER.body, { w: 2.5 });
    const tw = front ? w1 * 0.35 : w1 * 0.3;
    for (let i = -1; i <= 1; i++) p.stroke([[px + i * tw + (front ? 0 : pawDir * 4), len + 5], [px + i * tw + (front ? 0 : pawDir * 7), len + 10]], { w: 1.4 });
  }
}

function tigerTailSeg(p, len, w0, w1, tip) {
  const path = p.poly(limbPts(len, w0, w1), TIGER.body, { w: 2.4 });
  p.clip(path, (g) => {
    p.stroke([[-w0, len * 0.3], [w0, len * 0.4]], { w: 5, color: TIGER.stripe });
    p.stroke([[-w0, len * 0.75], [w0, len * 0.82]], { w: 5, color: TIGER.stripe });
    if (tip) { g.fillStyle = TIGER.stripe; g.fillRect(-w0, len * 0.72, w0 * 2, len); }
  });
}

function tigerView(view) {
  const L = [];
  const side = view === 'side', back = view === 'back';
  if (side) {
    part(L, 'root', null, [0, -110], 0, null);
    // 꼬리: 엉덩이에서 위로 S자로 말려 올라감
    const segs = [[-2.55, 20, 17], [-0.55, 17, 14], [1.05, 14, 12], [1.35, 12, 10]];
    let parent = 'root', at = [170, -34];
    segs.forEach(([r0, w0, w1], i) => {
      const n = 'tail' + i;
      part(L, n, parent, at, 0.1 + i * 0.01, (p) => tigerTailSeg(p, 42, w0, w1, i === 3), { r0 });
      parent = n; at = [0, 40];
    });
    const P = painter();
    P.begin(31); P.lineScale = 1; P.tint = null; tigerLeg(P, 62, 44, 30, 2); const fu = P.end();
    P.begin(32); tigerLeg(P, 52, 31, 26, 1, true, -1); const fl = P.end();
    P.begin(33); tigerLeg(P, 64, 56, 30, 2); const hu = P.end();
    P.begin(34); tigerLeg(P, 54, 29, 24, 1, true, -1); const hl = P.end();
    reuse(L, hu, 'hind1', 'root', [136, -12], 1, { far: true, r0: 0.28 });
    reuse(L, hl, 'hind1_l', 'hind1', [0, 60], 0.9, { far: true, r0: -0.5 });
    reuse(L, fu, 'front1', 'root', [-100, 0], 1, { far: true, r0: 0.05 });
    reuse(L, fl, 'front1_l', 'front1', [0, 58], 0.9, { far: true, r0: -0.05 });
    part(L, 'body', 'root', [0, 0], 3, (p) => {
      const pts = [[-164, -12], [-150, -58], [-104, -82], [-56, -62], [-6, -52], [60, -56], [120, -68], [166, -54], [190, -20], [186, 18], [162, 42], [124, 32], [80, 20], [20, 32], [-50, 50], [-110, 62], [-154, 38]];
      const path = p.poly(pts, TIGER.body, { w: 3.4, shadeDown: 0.3 });
      p.clip(path, () => {
        // 등줄기 짙은 주황
        p.stroke([[-148, -62], [-104, -84], [-56, -64], [-6, -54], [60, -58], [120, -70], [172, -50]], { w: 18, color: shade(TIGER.body, -0.12), taper: false });
        // 배 쪽 흰 털
        p.poly([[-158, 20], [-104, 42], [-40, 30], [30, 18], [80, 10], [130, 22], [130, 80], [-158, 80]], TIGER.belly, { ink: false, grain: 0.6 });
        p.stroke([[-158, 20], [-104, 42], [-40, 30], [30, 18], [80, 10], [130, 22]], { w: 1.6, color: shade(TIGER.body, -0.3) });
        // 불꽃 같은 줄무늬: 등에서 내려오며 가늘어지고 끝이 갈라짐
        const R = (i) => ((i * 73) % 17) / 17;
        for (let i = 0; i < 12; i++) {
          const x = -122 + i * 25 + R(i) * 6;
          const top = -76 + abs(i - 5.5) * 1.2;
          const len = 52 + R(i + 3) * 28;
          const bend = (i % 2 ? 1 : -1) * 6;
          p.stroke([[x - 4, top], [x + bend, top + len * 0.35], [x - bend * 0.5, top + len * 0.7], [x + 4, top + len]], { w: 9 - (i % 3), color: TIGER.stripe });
          if (i % 3 !== 1) p.stroke([[x + bend * 0.2, top + len * 0.45], [x + 10, top + len * 0.6], [x + 13, top + len * 0.85]], { w: 4.5, color: TIGER.stripe });
        }
        // 가슴 흰 털 들쭉날쭉
        p.stroke([[-150, -6], [-142, 4], [-150, 12], [-140, 20], [-146, 28]], { w: 2, color: shade(TIGER.body, -0.4) });
      });
    });
    reuse(L, hu, 'hind2', 'root', [128, -6], 5, { r0: 0.28 });
    reuse(L, hl, 'hind2_l', 'hind2', [0, 60], 4.9, { r0: -0.5 });
    reuse(L, fu, 'front2', 'root', [-114, 4], 5, { r0: 0.05 });
    reuse(L, fl, 'front2_l', 'front2', [0, 58], 4.9, { r0: -0.05 });
    // 머리: 몸은 옆, 얼굴은 보는 이를 향해 (까치호랑이)
    part(L, 'head', 'root', [-134, -40], 8, (p) => tigerFace(p, -26, -26, 1.1, -3));
    part(L, 'head_roar', 'root', [-134, -40], 8, (p) => tigerFace(p, -26, -26, 1.1, -3, 'roar'), { tag: 'alt' });
    part(L, 'head_dead', 'root', [-134, -40], 8, (p) => tigerFace(p, -26, -26, 1.1, -3, 'dead'), { tag: 'alt' });
    part(L, 'fx_claw', 'root', [-215, 40], 9, drawClaw, { tag: 'fx' });
  } else if (back) {
    part(L, 'root', null, [0, -100], 0, null);
    part(L, 'head', 'root', [0, -48], 0.5, (p) => {
      for (const s of [-1, 1]) p.ellipse(s * 34, -34, 13, 12, TIGER.body, { w: 2.6 });
      const hp = p.ellipse(0, -8, 48, 36, TIGER.body, { w: 3 });
      stripeClip(p, hp, [[[-20, -44], [-14, -30], [-20, -16]], [[0, -46], [0, -26]], [[20, -44], [14, -30], [20, -16]], [[-48, -10], [-30, -8]], [[48, -10], [30, -8]]], 6);
    });
    const P = painter();
    P.begin(41); P.lineScale = 1; P.tint = null; tigerLeg(P, 52, 30, 26, 2, true, 0, true); const fl = P.end();
    reuse(L, fl, 'front1', 'root', [-34, 44], 0.8, { far: true, r0: 0.08 });
    reuse(L, fl, 'front2', 'root', [34, 44], 0.8, { far: true, r0: -0.08 });
    part(L, 'body', 'root', [0, 0], 2, (p) => {
      const path = p.poly([[-44, -40], [0, -48], [44, -40], [64, 0], [58, 40], [30, 62], [-30, 62], [-58, 40], [-64, 0]], TIGER.body, { w: 3.2, shadeDown: 0.3 });
      const lines = [];
      for (let i = 0; i < 5; i++) {
        const y = -34 + i * 20;
        lines.push([[-70, y], [-44, y + 6], [-26, y + 2]]);
        lines.push([[70, y], [44, y + 6], [26, y + 2]]);
      }
      lines.push([[0, -48], [2, -30], [-2, -14]]);
      stripeClip(p, path, lines, 7);
    });
    P.begin(42); tigerLeg(P, 62, 40, 26, 2); const hu = P.end();
    P.begin(43); tigerLeg(P, 42, 26, 22, 1, true, 0, true); const hl = P.end();
    reuse(L, hu, 'hind1', 'root', [-36, 24], 3, { r0: 0.1 });
    reuse(L, hl, 'hind1_l', 'hind1', [0, 58], 2.9, { r0: -0.1 });
    reuse(L, hu, 'hind2', 'root', [36, 24], 3, { r0: -0.1 });
    reuse(L, hl, 'hind2_l', 'hind2', [0, 58], 2.9, { r0: 0.1 });
    const segs = [[PI + 0.25, 18, 15], [-0.5, 15, 13], [0.9, 13, 11], [1.0, 11, 9]];
    let parent = 'root', at = [4, -10];
    segs.forEach(([r0, w0, w1], i) => {
      const n = 'tail' + i;
      part(L, n, parent, at, 6 + i * 0.01, (p) => tigerTailSeg(p, 40, w0, w1, i === 3), { r0 });
      parent = n; at = [0, 38];
    });
  } else {
    // 정면
    part(L, 'root', null, [0, -95], 0, null);
    const segs = [[PI - 0.5, 16, 14], [0.2, 14, 12], [0.6, 12, 10], [0.9, 10, 9]];
    let parent = 'root', at = [44, -10];
    segs.forEach(([r0, w0, w1], i) => {
      const n = 'tail' + i;
      part(L, n, parent, at, 0.1 + i * 0.01, (p) => tigerTailSeg(p, 38, w0, w1, i === 3), { r0 });
      parent = n; at = [0, 36];
    });
    const P = painter();
    P.begin(51); P.lineScale = 1; P.tint = null; tigerLeg(P, 40, 34, 26, 1, true, 0, true); const hl = P.end();
    reuse(L, hl, 'hind1', 'root', [-52, 50], 0.5, { far: true, r0: 0.1 });
    reuse(L, hl, 'hind2', 'root', [52, 50], 0.5, { far: true, r0: -0.1 });
    part(L, 'body', 'root', [0, 0], 1, (p) => {
      const path = p.poly([[-40, -46], [40, -46], [62, -10], [58, 34], [30, 56], [-30, 56], [-58, 34], [-62, -10]], TIGER.body, { w: 3.2, shadeDown: 0.3 });
      p.clip(path, () => {
        p.ellipse(0, 22, 28, 40, TIGER.belly, { ink: false, grain: 0.6 });
        for (const s of [-1, 1]) for (let i = 0; i < 4; i++) p.stroke([[s * 70, -30 + i * 20], [s * 48, -24 + i * 20], [s * 34, -28 + i * 20]], { w: 7, color: TIGER.stripe });
      });
    });
    P.begin(52); tigerLeg(P, 50, 32, 26, 2); const fu = P.end();
    P.begin(53); tigerLeg(P, 44, 26, 24, 1, true, 0, true); const fl = P.end();
    reuse(L, fu, 'front1', 'root', [-28, 14], 2, { r0: 0.04 });
    reuse(L, fl, 'front1_l', 'front1', [0, 46], 1.9, { r0: -0.04 });
    reuse(L, fu, 'front2', 'root', [28, 14], 2, { r0: -0.04 });
    reuse(L, fl, 'front2_l', 'front2', [0, 46], 1.9, { r0: 0.04 });
    part(L, 'head', 'root', [0, -42], 4, (p) => tigerFace(p, 0, -22, 1.0, 0));
    part(L, 'head_roar', 'root', [0, -42], 4, (p) => tigerFace(p, 0, -22, 1.0, 0, 'roar'), { tag: 'alt' });
    part(L, 'head_dead', 'root', [0, -42], 4, (p) => tigerFace(p, 0, -22, 1.0, 0, 'dead'), { tag: 'alt' });
    part(L, 'fx_claw', 'root', [30, 50], 6, drawClaw, { tag: 'fx' });
  }
  return finishView(L);
}

function tigerPose(view, anim, t, rig, at = t) {
  if (anim !== 'idle' && anim !== 'walk' && anim !== 'run') {
    const C = tigerCombatPose(view, anim, t, at);
    if (C) return C;
  }
  const P = {};
  const set = (n, r = 0, x = 0, y = 0, sx = 1, sy = 1) => (P[n] = { r, x, y, sx, sy });
  const side = view === 'side';
  const br = sin((t / 2.6) * PI * 2);
  const walk = anim === 'walk' || anim === 'run';
  const period = anim === 'run' ? 0.7 : 1.15;
  const ph = (t / period) * PI * 2, s = sin(ph), c = cos(ph);
  const tail = (amp, speed, base = 0) => { for (let i = 0; i < 4; i++) set('tail' + i, base + amp * sin(t * speed - i * 0.9) * (0.6 + i * 0.25)); };

  if (anim === 'crouch') {
    const q = sin(t * 7) * 0.5 + sin(t * 11) * 0.5;
    if (side) {
      set('root', -0.05 + 0.015 * q, 3, 22);
      set('front1', -0.55, 0, 0); set('front1_l', 0.95);
      set('front2', -0.5); set('front2_l', 0.9);
      set('hind1', 0.55); set('hind1_l', -0.85);
      set('hind2', 0.6); set('hind2_l', -0.9);
      set('head', 0.05, -8, 12);
      set('tail0', 0.55); set('tail1', 0.5); set('tail2', -0.7); set('tail3', -0.9 + 0.35 * sin(t * 10));
    } else {
      set('root', 0, 0, 16, 1.04, 0.9);
      set('front1', 0.3); set('front1_l', -0.35); set('front2', -0.3); set('front2_l', 0.35);
      set('hind1', 0.1); set('hind2', -0.1);
      set('head', 0.02 * q, 0, 14);
      set('tail0', 0.45); set('tail1', -0.2); set('tail2', -0.6); set('tail3', -0.9 + 0.35 * sin(t * 10));
    }
    return P;
  }
  if (anim === 'pounce') {
    const w = sin(t * 5) * 0.05;
    if (side) {
      set('root', 0.12 + w * 0.5, -14, -34, 1.1, 0.96);
      set('front1', 1.35 + w); set('front1_l', 0.25);
      set('front2', 1.2 + w); set('front2_l', 0.3);
      set('hind1', -1.0 - w); set('hind1_l', 0.1);
      set('hind2', -1.1 - w); set('hind2_l', 0.15);
      set('head', 0.12, -10, -2);
      set('tail0', 0.35); set('tail1', 0.55); set('tail2', -0.7); set('tail3', -0.9);
    } else {
      set('root', 0, 0, -26, 1.14, 1.14);
      set('front1', 1.0 + w); set('front1_l', -0.6); set('front2', -1.0 - w); set('front2_l', 0.6);
      set('head', 0, 0, -6);
      tail(0.05, 6);
    }
    return P;
  }
  if (walk) {
    const A = anim === 'run' ? 0.55 : 0.32;
    if (side) {
      // 대각선 보행: 가까운 앞다리 ↔ 먼 뒷다리가 같은 위상 (값은 기본 자세 r0에 더하는 변화량)
      set('front2', A * s); set('front2_l', -0.7 * max(0, c));
      set('hind1', A * s); set('hind1_l', 0.5 * max(0, c));
      set('front1', -A * s); set('front1_l', -0.7 * max(0, -c));
      set('hind2', -A * s); set('hind2_l', 0.5 * max(0, -c));
      set('root', 0.02 * s, 0, -(1 - abs(s)) * 4);
      set('head', 0.03 * sin(ph * 2), 0, 2 * sin(ph * 2));
    } else {
      const lift = 6;
      set('front1', 0.04 * s, 0, -max(0, s) * lift); set('front2', 0.04 * s, 0, -max(0, -s) * lift);
      set('hind1', 0, 0, -max(0, -s) * lift * 0.6); set('hind2', 0, 0, -max(0, s) * lift * 0.6);
      set('root', 0.015 * s, 2 * s, -(1 - abs(s)) * 3);
      set('head', -0.03 * s, 0, 1.5 * sin(ph * 2));
    }
    tail(0.1, 4);
    return P;
  }
  // idle
  set('root', 0, 0, 0, 1, 1 + 0.018 * br);
  set('head', 0.035 * sin(t * 0.8), 0, -1.5 * br);
  tail(0.16, 1.7);
  return P;
}

// ---------------------------------------------------------------------------
// 종류별 정의
// ---------------------------------------------------------------------------
export const SPECS = {
  player: {
    type: 'human', height: 1.65, radius: 0.3,
    top: 'durumagi', coat: '#ece5d3', pants: '#e4dccb', collar: '#d7ceb9', sash: PAL.red, goreum: '#d9d0bb',
    hat: 'satgat', hatColor: '#554633', hair: 'short', back: 'bundle', bundle: '#48637a', staff: 'staff', robeLen: 94, cheek: 0.18,
  },
  villager_m: {
    type: 'human', height: 1.65, radius: 0.3,
    top: 'jeogori', coat: '#dccfae', pants: '#e6decb', vest: '#5f7688', collar: '#c4b48f', daenim: '#5f7688', hair: 'sangtu', stubble: true, cheek: 0.2,
  },
  villager_f: {
    type: 'human', height: 1.6, radius: 0.3,
    top: 'short', bottom: 'chima', coat: '#ead9a4', skirt: '#46627b', goreum: PAL.red, cuff: '#b0584f', collar: '#b0584f', hair: 'jjok', cheek: 0.3, lip: '#b04438',
  },
  elder: {
    type: 'human', height: 1.6, radius: 0.3,
    top: 'durumagi', coat: '#e9e7df', pants: '#ece9e0', collar: '#cfcbc0', goreum: '#d6d2c6', hat: 'gat', hair: 'white', beard: true, wrinkles: true,
    stoop: 0.26, staff: 'cane', shoe: '#3a3431', robeLen: 104, browColor: '#8e897f', browW: 2.6, cheek: 0.14,
  },
  child_boy: {
    type: 'human', child: true, height: 1.1, radius: 0.25,
    top: 'jeogori', coat: '#eee7d6', pants: '#d9c485', vest: '#b0584a', collar: '#d9c485', daenim: '#b0584a', hair: 'bowl', cheek: 0.34,
  },
  child_girl: {
    type: 'human', child: true, height: 1.1, radius: 0.25,
    top: 'short', bottom: 'chima', coat: '#dfc265', skirt: '#b5473f', goreum: '#7d3a55', cuff: '#46627b', collar: '#46627b', hair: 'braid', ribbon: '#7d3a55', cheek: 0.38,
  },
  hunter: {
    type: 'human', height: 1.7, radius: 0.3,
    top: 'jeogori', coat: '#9d8664', pants: '#c7b894', vest: '#b98a4e', fur: true, collar: '#6f5a3e', legwrap: '#ede6d4', daenim: '#6f5a3e', sash: PAL.red,
    hat: 'beonggeoji', hair: 'short', back: 'bow', stubble: true, cheek: 0.16,
  },
  tiger: { type: 'tiger', height: 1.2, radius: 0.8 },
};

const _rigs = new Map();

/** 종류별 리그(부위 이미지)를 한 번만 만들어 모든 인스턴스가 공유 */
export function getRig(kind) {
  if (_rigs.has(kind)) return _rigs.get(kind);
  const sp = SPECS[kind];
  if (!sp) throw new Error('unknown character kind: ' + kind);
  let rig;
  if (sp.type === 'tiger') {
    rig = {
      kind, type: 'tiger', spec: sp, W: 640, H: 320, footX: 320, footY: 306, ppm: 160,
      height: sp.height, radius: sp.radius, pose: tigerPose, anims: TIGER_ANIMS,
      views: { front: tigerView('front'), back: tigerView('back'), side: tigerView('side') },
    };
  } else {
    const S = sp.child ? CHILD : ADULT;
    // 키 보정: 기준 골격(성인 약 1.62m 상당) 대비 ppm 조정
    const basePx = sp.child ? 205 : 312;
    const ppm = basePx / (sp.height - (sp.stoop ? -0.04 : 0));
    // 넘어짐·베기 궤적이 들어가도록 넉넉한 판 (대부분 투명)
    const W = sp.child ? 256 : 384, H = sp.child ? 320 : 448;
    rig = {
      kind, type: 'human', spec: sp, S, W, H, footX: W / 2, footY: H - 10, ppm,
      height: sp.height, radius: sp.radius, pose: humanPose, anims: HUMAN_ANIMS,
      views: { front: humanView('front', S, sp), back: humanView('back', S, sp), side: humanView('side', S, sp) },
    };
  }
  _rigs.set(kind, rig);
  return rig;
}
