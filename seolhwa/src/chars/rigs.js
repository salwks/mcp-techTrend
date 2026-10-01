// 설화록 — 캐릭터 컷아웃 부위 정의(정면/뒷면/옆면) + 애니메이션 곡선
// 좌표: 픽셀, 발 중심이 원점, y는 아래가 +. 옆면은 왼쪽을 향한다(오른쪽은 좌우 반전).
// 각 부위는 피벗(관절)이 원점인 캔버스 이미지로 한 번만 그려진다.
import { Painter, PAL, INK, shade, mix, ellipsePts, limbPts, darkenCopy } from './painter.js';
import { HUMAN_ANIMS, TIGER_ANIMS, humanCombatPose, tigerCombatPose, humanStoryPose } from './anims.js';

const PI = Math.PI;
const { sin, cos, max, min, abs, pow } = Math;

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
  const p = { name, parent, at, r0: opt.r0 || 0, z, img: opt.far ? darkenCopy(src.img, 0.2) : src.img, ox: src.ox, oy: src.oy, abs: !!opt.abs, tag: opt.tag || null, flip: !!opt.flip, far: !!opt.far };
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
const ADULT = { hip: 134, torso: 98, neck: 8, headRX: 25.5, headRY: 29.5, shHalf: 29, waistHalf: 27, uArm: 50, lArm: 46, thigh: 60, shin: 72, legX: 12, ws: 1 };
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
    // 풍속화식 가늘고 긴 눈: 윗눈꺼풀 붓선 + 작은 눈동자 (눈 감으면 아래로 휜 선 하나)
    if (sp._blink) {
      p.stroke([[x - s * 5 * ws, ey], [x + s * 0.5 * ws, ey + 1.6 * ws], [x + s * 6.5 * ws, ey + 0.2 * ws]], { w: 1.8 * ws, rough: 0.1 });
    } else {
      p.stroke([[x - s * 5 * ws, ey + 0.8 * ws], [x + s * 0.5 * ws, ey - 1.4 * ws], [x + s * 7 * ws, ey - 1.6 * ws]], { w: 2.1 * ws, rough: 0.2 });
      p.dot(x + s * 0.8 * ws, ey + 0.9 * ws, 2.1 * ws);
      p.stroke([[x - s * 3 * ws, ey + 2.6 * ws], [x + s * 4 * ws, ey + 2.4 * ws]], { w: 0.7 * ws, color: shade(sp.skin || PAL.skin, -0.4), taper: true });
    }
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
  if (sp._blink) p.stroke([[x + 4.5 * ws, ey], [x, ey + 1.5 * ws], [x - 5 * ws, ey + 0.2 * ws]], { w: 1.8 * ws, rough: 0.1 });
  else {
    p.stroke([[x + 4.5 * ws, ey + 0.6 * ws], [x, ey - 1.4 * ws], [x - 5.5 * ws, ey - 1.6 * ws]], { w: 2.1 * ws, rough: 0.2 });
    p.dot(x - 1.4 * ws, ey + 0.9 * ws, 2 * ws);
  }
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
  const by = hy - ry * 0.3, W = 72 * ws, ay = by - 42 * ws;
  const col = sp.hatColor || '#5b4b37';
  if (view === 'side') {
    const path = p.poly([[cx + 5 * ws, ay, 'c'], [cx + W * 0.55, by - 17 * ws], [cx + W + 3, by - 1, 'c'], [cx + W * 0.4, by + 4 * ws], [cx - W * 0.45, by + 5 * ws], [cx - W - 3, by + 1, 'c'], [cx - W * 0.5, by - 16 * ws]], col, { w: 2.6, shadeDown: 0.3 });
    p.clip(path, () => {
      for (let i = -5; i <= 5; i++) p.stroke([[cx + 5 * ws, ay], [cx + i * W * 0.2, by + 4]], { w: 0.8, color: shade(col, 0.35), taper: false });
      for (let k = 0.25; k < 1; k += 0.14) p.stroke([[cx + 5 - W * k, ay + (by - ay) * k + 2], [cx + 5 + W * k, ay + (by - ay) * k]], { w: 0.7, color: shade(col, 0.28), taper: false, dry: true });
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
    // 대오리 엮음: 가는 동심 결 + 짙은 테 두 줄
    for (let k = 0.18; k < 1; k += 0.09) {
      const yy = ay + (by - ay) * k;
      p.stroke([[cx - W * k * 1.02, yy + 2], [cx, yy + 6 * k * ws + 2], [cx + W * k * 1.02, yy + 2]], { w: 0.7, color: shade(col, 0.22), taper: false, rough: 0.4 });
    }
    for (const k of [0.45, 0.8]) {
      const yy = ay + (by - ay) * k;
      p.stroke([[cx - W * k * 1.02, yy + 2], [cx, yy + 6 * k * ws + 2], [cx + W * k * 1.02, yy + 2]], { w: 1.5, color: shade(col, -0.4), taper: false });
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
    if (sp.pipe) drawPipe(p, cx - rx * 0.8, hy + ry * 0.62, -1, S);
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
    if (sp.pipe) drawPipe(p, cx + 3, hy + ry * 0.62, 1, S);
    if (sp.stubble) p.clip(face, (g) => { g.fillStyle = 'rgba(60,50,45,0.13)'; g.beginPath(); g.ellipse(cx, hy + ry * 0.75, rx * 0.7, ry * 0.35, 0, 0, 2 * PI); g.fill(); });
    if (hair === 'braid') braidFront(p, cx, hy, rx, ry, ws, sp);
    if (sp.hat === 'satgat') {
      // 턱끈
      for (const s of [-1, 1]) p.stroke([[cx + s * rx * 0.85, hy - ry * 0.3], [cx + s * rx * 0.75, hy + ry * 0.5], [cx + s * rx * 0.25, hy + ry + 2]], { w: 1.2, color: '#6b5a44' });
    }
  }

  if (sp.scarf) drawScarf(p, view, cx, hy, rx, ry, ws, sp.scarf);
  if (sp.carry === 'basket') drawBasket(p, cx, hy - ry - 3 * ws, S);
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
    if (sp.apron) {
      // 앞치마: 앞쪽 무릎 아래까지, 허리끈
      const ac = sp.apron, al = len * 0.7;
      if (back) {
        p.stroke([[-top - 2, 6 * ws], [top + 2, 6 * ws]], { w: 3.5 * ws, color: ac, taper: false });
        p.ellipse(0, 7 * ws, 6 * ws, 4 * ws, ac, { w: 1.4 });
        p.poly([[-2, 9 * ws], [-8 * ws, 26 * ws], [-2 * ws, 24 * ws]], ac, { w: 1.2 });
        p.poly([[2, 9 * ws], [8 * ws, 27 * ws], [3 * ws, 24 * ws]], ac, { w: 1.2 });
      } else if (side) {
        const ap = p.poly([[-top - 2, 4 * ws], [-2 * ws, 4 * ws], [-1 * ws, al], [-top - 10 * ws, al + 2]], ac, { w: 1.8 });
        p.clip(ap, () => p.stroke([[-top * 0.6, 10 * ws], [-top * 0.7, al]], { w: 0.9, color: shade(ac, -0.35) }));
      } else {
        const ap = p.poly([[-top + 2, 4 * ws], [top - 2, 4 * ws], [top + 3 * ws, al], [0, al + 3], [-top - 3 * ws, al]], ac, { w: 1.8 });
        p.clip(ap, () => { p.stroke([[-top * 0.3, 10 * ws], [-top * 0.35, al]], { w: 0.9, color: shade(ac, -0.35) }); p.stroke([[top * 0.35, 10 * ws], [top * 0.4, al]], { w: 0.9, color: shade(ac, -0.35) }); });
        p.stroke([[-top - 3, 5 * ws], [top + 3, 5 * ws]], { w: 3.5 * ws, color: shade(ac, -0.1), taper: false });
      }
    }
    return;
  }
  // 두루마기 아랫자락 (허리 아래)
  const len = sp.robeLen || 92;
  const col = sp.coat;
  let pts;
  // 안자락(속옷 단)이 겉자락 아래로 살짝 겹쳐 보이게
  const under = shade(sp.pants || col, -0.08);
  if (side) p.poly([[-20 * ws, len * 0.4], [24 * ws, len * 0.4], [31 * ws, len + 7 * ws, 'c'], [-24 * ws, len + 6 * ws, 'c']], under, { w: 1.8, blot: false });
  else p.poly([[-wa - 10, len * 0.5], [wa + 10, len * 0.5], [wa + 15, len + 7 * ws, 'c'], [-wa - 15, len + 7 * ws, 'c']], under, { w: 1.8, blot: false });
  if (side) pts = [[-22 * ws, -4], [21 * ws, -4], [27 * ws, len * 0.45], [37 * ws, len - 2, 'c'], [18 * ws, len + 1], [2, len + 3], [-27 * ws, len, 'c'], [-24 * ws, len * 0.5]];
  else pts = [[-wa - 4, -4], [wa + 4, -4], [wa + 11, len * 0.55], [wa + 19, len, 'c'], [wa * 0.4, len + 4], [0, len + 2], [-wa * 0.5, len + 5], [-wa - 19, len, 'c'], [-wa - 11, len * 0.55]];
  const path = p.poly(pts, col, { w: 2.4, shadeDown: 0.3 });
  p.clip(path, () => {
    const fold = shade(col, -0.42);
    if (side) {
      p.stroke([[-4, 0], [-9, len * 0.45], [-7, len * 0.8], [-12, len]], { w: 1.2, color: fold });
      p.stroke([[10, 4], [13, len * 0.5], [22, len]], { w: 1, color: fold });
      p.stroke([[3, len * 0.3], [6, len * 0.75], [4, len]], { w: 0.8, color: fold });
    } else if (back) {
      p.stroke([[0, 0], [0, len]], { w: 1.2, color: shade(col, -0.35), taper: false });
      p.stroke([[-wa * 0.7, 6], [-wa - 6, len]], { w: 1, color: shade(col, -0.28) });
      p.stroke([[wa * 0.7, 6], [wa + 6, len]], { w: 1, color: shade(col, -0.28) });
    } else {
      // 섶 겹침선
      p.stroke([[4, -2], [0, len * 0.5], [-5, len + 2]], { w: 1.6, color: shade(col, -0.5) });
      p.stroke([[-wa * 0.6, 6], [-wa * 0.8, len * 0.5], [-wa - 8, len]], { w: 1, color: fold });
      p.stroke([[wa * 0.7, 6], [wa * 0.9, len * 0.55], [wa + 9, len]], { w: 1, color: fold });
      p.stroke([[-wa * 0.2, len * 0.35], [-wa * 0.35, len * 0.95]], { w: 0.8, color: fold });
      p.stroke([[wa * 0.35, len * 0.4], [wa * 0.5, len * 0.97]], { w: 0.8, color: fold });
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
  // 배래: 손목은 좁고 아래로 둥글게 흘러내리는 넓은 소매
  // 배래: 팔꿈치에서 부드럽게 늘어졌다가 손목(수구)으로 둥글게 모이는 소매 — 바깥(+x)쪽이 흘러내림
  const path = p.poly([[-10.5 * ws, -3], [10.5 * ws, -3], [13 * ws, L * 0.42], [13.5 * ws, L - 12 * ws], [10 * ws, L - 3 * ws], [3 * ws, L], [-7 * ws, L - 1 * ws, 'c'], [-10 * ws, L - 8 * ws], [-11 * ws, L * 0.45]], sp.coat, { w: 2.2, shadeDown: 0.35 });
  p.clip(path, () => {
    if (sp.cuff) p.stroke([[-14 * ws, L - 5 * ws], [16 * ws, L - 6 * ws]], { w: 8 * ws, color: sp.cuff, taper: false });
    p.stroke([[-4 * ws, 3], [-2 * ws, L * 0.5], [1 * ws, L * 0.85]], { w: 0.9, color: shade(sp.coat, -0.42) });
    p.stroke([[5 * ws, L * 0.25], [9 * ws, L * 0.62], [8 * ws, L - 6 * ws]], { w: 0.8, color: shade(sp.coat, -0.42) });
  });
}

// ---- 다리 ----
function drawThigh(p, S, sp) {
  const ws = S.ws;
  const L = S.thigh + 6 * ws, pc = sp.pants || sp.coat;
  const path = p.poly([[-12 * ws, -4], [12 * ws, -4], [15 * ws, L * 0.45], [13 * ws, L - 2 * ws], [6 * ws, L + 4 * ws], [-6 * ws, L + 4 * ws], [-13 * ws, L - 2 * ws], [-15 * ws, L * 0.45]], pc, { w: 2.2 });
  p.clip(path, () => {
    p.stroke([[-6 * ws, L * 0.2], [-3 * ws, L * 0.8]], { w: 1, color: shade(pc, -0.3) }); p.stroke([[7 * ws, L * 0.5], [4 * ws, L * 0.95]], { w: 1, color: shade(pc, -0.3) });
    if (sp.patch) {
      // 기운 자국: 덧댄 천 + 바늘땀
      p.poly([[-2 * ws, L * 0.55], [11 * ws, L * 0.52], [12 * ws, L * 0.78], [-1 * ws, L * 0.8]], sp.patch, { w: 1.1, smooth: false, rough: 1 });
      for (let i = 0; i < 6; i++) p.dot(-1 * ws + i * 2.2 * ws, L * 0.555 - i * 0.006 * L, 0.6, INK);
    }
  });
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
  shinDetails(p, S, sp, view);
}
function shinDetails(p, S, sp, view) {
  const ws = S.ws, L = S.shin;
  const pc = sp.pants || '#e8e1ce';
  const sock = sp.sock || '#f3efe4';
  const shoe = sp.shoe || PAL.straw;
  const side = view === 'side';
  if (sp.legwrap) {
    const lw = p.poly([[-10 * ws, L * 0.3], [10 * ws, L * 0.3], [8 * ws, L - 9 * ws], [-8 * ws, L - 9 * ws]], sp.legwrap, { w: 1.8, smooth: false });
    p.clip(lw, () => { for (let i = 0; i < 5; i++) p.stroke([[-10 * ws, L * 0.34 + i * 8 * ws], [10 * ws, L * 0.3 + i * 8 * ws + 6]], { w: 0.9, color: shade(sp.legwrap, -0.35), taper: false }); });
    // 행전 끈
    p.stroke([[-6 * ws, L * 0.3 + 1], [-11 * ws, L * 0.3 + 8 * ws]], { w: 1.4, color: shade(sp.legwrap, -0.5) });
    p.stroke([[-4 * ws, L * 0.3 + 1], [-7 * ws, L * 0.3 + 10 * ws]], { w: 1.2, color: shade(sp.legwrap, -0.5) });
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


// ---- 마을 사람 소품 ----
/** 지게: 두 가닥 나무 + 가로대 + 위로 뻗은 가지 */
function drawJige(p, view, S, load = 'straw') {
  const ws = S.ws, wood = '#8a6a44', dk = shade(wood, -0.35);
  const bar = (a, b, w = 5) => { p.stroke([a, b], { w: w + 2.4, color: INK, taper: false, rough: 0.4 }); p.stroke([a, b], { w, color: wood, taper: false, rough: 0.2 }); };
  if (view === 'side') {
    // 뒤로 비스듬히 선 지게: 몸에서 뒤쪽(+x)으로
    bar([-4, -52 * ws], [20 * ws, 116 * ws], 6);
    bar([4, -60 * ws], [28 * ws, 112 * ws], 5);
    bar([-2, -8], [40 * ws, -26 * ws], 4);          // 가지
    bar([6, 20 * ws], [44 * ws, 4 * ws], 4);
    for (const y of [10, 50, 86]) bar([y * 0.13 * ws, y * ws], [(y * 0.14 + 8) * ws, y * ws], 3);
    if (load === 'wood') woodLoad(p, 20 * ws, 10 * ws, 26 * ws, 70 * ws, true);
    else p.poly([[4, 30 * ws], [34 * ws, 20 * ws], [36 * ws, 60 * ws], [12 * ws, 70 * ws]], '#b89a64', { w: 1.8 });   // 짚 짐
    return;
  }
  const back = view === 'back';
  // 두 다리가 위로 벌어지는 A자
  bar([-20 * ws, 118 * ws], [-12 * ws, -62 * ws], 6);
  bar([20 * ws, 118 * ws], [12 * ws, -62 * ws], 6);
  for (const y of [-40, 0, 40, 84]) bar([-(14 + y * 0.04) * ws, y * ws], [(14 + y * 0.04) * ws, y * ws], 3.5);
  if (back) {
    bar([-16 * ws, 30 * ws], [-34 * ws, 6 * ws], 4);
    bar([16 * ws, 30 * ws], [34 * ws, 6 * ws], 4);
    if (load === 'wood') { woodLoad(p, 0, -6 * ws, 34 * ws, 64 * ws, false); return; }
    // 짚단 짐
    const load = p.poly([[-26 * ws, -30 * ws], [26 * ws, -30 * ws], [30 * ws, 30 * ws], [-30 * ws, 30 * ws]], '#c4a86d', { w: 2.2 });
    p.clip(load, () => { for (let i = -5; i <= 5; i++) p.stroke([[i * 5 * ws, -30 * ws], [i * 5.6 * ws, 30 * ws]], { w: 0.8, color: shade('#c4a86d', -0.35), dry: true }); });
    p.stroke([[-30 * ws, 0], [30 * ws, 0]], { w: 2.5, color: '#6b5436', taper: false });
  }
}
/** 광주리(머리에 인 바구니)와 똬리 */
function drawBasket(p, cx, topY, S) {
  const ws = S.ws, c = '#b38f58';
  p.ellipse(cx, topY + 3 * ws, 12 * ws, 4 * ws, '#e8dfc8', { w: 1.4 });
  // 담긴 것: 무청과 고추
  p.poly([[cx - 20 * ws, topY - 10 * ws], [cx - 14 * ws, topY - 26 * ws], [cx - 6 * ws, topY - 12 * ws]], '#6f8a4a', { w: 1.5 });
  p.poly([[cx - 4 * ws, topY - 11 * ws], [cx + 4 * ws, topY - 30 * ws], [cx + 9 * ws, topY - 11 * ws]], '#7d9651', { w: 1.5 });
  for (let i = 0; i < 4; i++) p.ellipse(cx + (8 + i * 5) * ws, topY - 12 * ws - (i % 2) * 3, 3.6 * ws, 2.4 * ws, PAL.red, { w: 1.1 });
  const b = p.poly([[cx - 36 * ws, topY - 12 * ws], [cx + 36 * ws, topY - 12 * ws], [cx + 30 * ws, topY, 'c'], [cx - 30 * ws, topY, 'c']], c, { w: 2.2, smooth: false });
  p.clip(b, () => {
    for (let i = -8; i <= 8; i++) p.stroke([[cx + i * 4.5 * ws, topY - 12 * ws], [cx + i * 4 * ws, topY]], { w: 0.8, color: shade(c, -0.4), taper: false });
    p.stroke([[cx - 36 * ws, topY - 6 * ws], [cx + 36 * ws, topY - 6 * ws]], { w: 1, color: shade(c, -0.4), taper: false });
  });
  p.ellipse(cx, topY - 12 * ws, 36 * ws, 3.5 * ws, shade(c, 0.15), { w: 1.8 });
}
/** 곰방대(짧은 담뱃대) */
function drawPipe(p, x0, y0, dir, S) {
  const ws = S.ws;
  const x1 = x0 + dir * 26 * ws, y1 = y0 + 14 * ws;
  p.stroke([[x0, y0], [x1, y1]], { w: 4, color: INK, taper: false });
  p.stroke([[x0, y0], [x1, y1]], { w: 2, color: '#6d4a2c', taper: false, rough: 0 });
  p.poly([[x1 - 3 * ws, y1 - 7 * ws], [x1 + 4 * ws, y1 - 7 * ws], [x1 + 3 * ws, y1 + 2 * ws], [x1 - 2 * ws, y1 + 2 * ws]], '#a88b4a', { w: 1.4, smooth: false });
  // 연기 한 가닥
  p.stroke([[x1, y1 - 8 * ws], [x1 + dir * 3, y1 - 16 * ws], [x1 - dir * 2, y1 - 24 * ws], [x1 + dir * 2, y1 - 32 * ws]], { w: 1.1, color: '#b9b3a6' });
}

/** 지게에 얹은 장작 다발 */
function woodLoad(p, cx, cy, hw, h, side) {
  const bark = '#7a5634', cut = '#d9b98a';
  const n = side ? 4 : 6;
  for (let i = 0; i < n; i++) {
    const x = cx - hw + (i + 0.5) * (2 * hw / n);
    p.poly([[x - hw / n, cy], [x + hw / n, cy - 2], [x + hw / n - 1, cy + h], [x - hw / n + 1, cy + h + 2]], shade(bark, (i % 2) * 0.1), { w: 1.6, smooth: false });
    p.ellipse(x, cy, hw / n - 1, 3, cut, { w: 1.2 });
  }
  p.stroke([[cx - hw - 2, cy + h * 0.3], [cx + hw + 2, cy + h * 0.28]], { w: 2.4, color: '#6b5436', taper: false });
  p.stroke([[cx - hw - 2, cy + h * 0.75], [cx + hw + 2, cy + h * 0.73]], { w: 2.4, color: '#6b5436', taper: false });
}
/** 여인의 머릿수건 */
function drawScarf(p, view, cx, hy, rx, ry, ws, col) {
  const fold = shade(col, -0.35);
  if (view === 'side') {
    const path = p.poly([[cx - rx * 0.6, hy - ry * 0.5], [cx - rx * 0.3, hy - ry - 4], [cx + rx * 0.5, hy - ry - 3], [cx + rx + 4, hy - ry * 0.2], [cx + rx * 0.9, hy + ry * 0.3], [cx + rx * 0.2, hy - ry * 0.15]], col, { w: 2 });
    p.clip(path, () => p.stroke([[cx - rx * 0.2, hy - ry * 0.9], [cx + rx * 0.7, hy - ry * 0.2]], { w: 0.9, color: fold }));
    p.ellipse(cx + rx + 3, hy + ry * 0.05, 5 * ws, 4.5 * ws, col, { w: 1.6 });
    p.poly([[cx + rx + 4, hy + ry * 0.1], [cx + rx + 14, hy + ry * 0.55], [cx + rx + 6, hy + ry * 0.55]], col, { w: 1.4 });
    return;
  }
  if (view === 'back') {
    const path = p.ellipse(cx, hy - ry * 0.25, rx + 3, ry * 0.85, col, { w: 2 });
    p.clip(path, () => { p.stroke([[cx - rx, hy - ry * 0.2], [cx + rx, hy - ry * 0.25]], { w: 0.9, color: fold }); });
    p.ellipse(cx, hy + ry * 0.35, 6 * ws, 5 * ws, col, { w: 1.6 });
    p.poly([[cx - 2, hy + ry * 0.4], [cx - 9, hy + ry + 4], [cx - 2, hy + ry]], col, { w: 1.4 });
    p.poly([[cx + 2, hy + ry * 0.4], [cx + 10, hy + ry + 2], [cx + 3, hy + ry]], col, { w: 1.4 });
    return;
  }
  const path = p.poly([[cx - rx - 3, hy - ry * 0.05], [cx - rx * 0.8, hy - ry * 0.85], [cx, hy - ry - 5], [cx + rx * 0.8, hy - ry * 0.85], [cx + rx + 3, hy - ry * 0.05], [cx + rx * 0.7, hy - ry * 0.35], [cx, hy - ry * 0.48], [cx - rx * 0.7, hy - ry * 0.35]], col, { w: 2 });
  p.clip(path, () => {
    p.stroke([[cx - rx * 0.7, hy - ry * 0.6], [cx, hy - ry * 0.75], [cx + rx * 0.7, hy - ry * 0.6]], { w: 0.9, color: fold });
    p.stroke([[cx - rx * 0.4, hy - ry * 0.9], [cx + rx * 0.3, hy - ry * 0.95]], { w: 0.8, color: fold });
  });
}
/** 국자 */
function drawLadle(p, S) {
  const ws = S.ws;
  p.poly([[-1.8, -6], [1.8, -6], [1.6, 50 * ws], [-1.6, 50 * ws]], '#8a6a45', { w: 1.3, smooth: false });
  p.poly(ellipsePts(0, 56 * ws, 9 * ws, 7 * ws, 16, 0, PI).concat([[-9 * ws, 52 * ws], [9 * ws, 52 * ws]]), '#9b7a4e', { w: 1.6 });
}
/** 도끼 */
function drawAxe(p, S) {
  const ws = S.ws;
  p.poly([[-2.4, -10], [2.4, -10], [2.2, 74 * ws], [-2.2, 74 * ws]], '#86653f', { w: 1.5, smooth: false });
  p.poly([[-3, 58 * ws], [-22 * ws, 54 * ws], [-24 * ws, 72 * ws, 'c'], [-3, 70 * ws]], '#9aa19a', { w: 1.8 });
  p.stroke([[-22 * ws, 55 * ws], [-23 * ws, 71 * ws]], { w: 1.6, color: '#e8ece6' });
}
/** 밀가루 묻은 옷: 그림 위에(알파는 그대로) 흰 가루 얼룩 */
function dustFlour(img, seed) {
  const g = img.getContext('2d');
  const R = rngLocal(seed);
  g.save();
  g.globalCompositeOperation = 'source-atop';
  for (let i = 0; i < 18; i++) {
    const x = R() * img.width, y = R() * img.height, r = 2 + R() * 7;
    const gr = g.createRadialGradient(x, y, 0, x, y, r);
    gr.addColorStop(0, 'rgba(250,248,240,0.75)');
    gr.addColorStop(1, 'rgba(250,248,240,0)');
    g.fillStyle = gr;
    g.fillRect(x - r, y - r, r * 2, r * 2);
  }
  for (let i = 0; i < 40; i++) { g.fillStyle = 'rgba(255,253,245,0.8)'; g.fillRect(R() * img.width, R() * img.height, 1.2, 1.2); }
  g.restore();
}
function rngLocal(seed) { let s = seed >>> 0 || 1; return () => { s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; }; }

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
  // 칼자루 끝의 붉은 술(매듭 + 늘어진 술)
  p.ellipse(0, -14 * ws, 3.5 * ws, 3 * ws, PAL.red, { w: 1.3 });
  p.poly([[-2 * ws, -15 * ws], [2 * ws, -15 * ws], [7 * ws, -34 * ws], [3 * ws, -36 * ws, 'c'], [-1 * ws, -30 * ws]], PAL.red, { w: 1.4 });
  p.stroke([[4 * ws, -22 * ws], [6 * ws, -33 * ws]], { w: 0.8, color: shade(PAL.red, -0.5) });
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
  const ls = sp.child ? 0.82 : 1;
  const L = [];
  const side = view === 'side', back = view === 'back';
  part(L, 'root', null, [0, -S.hip], 0, null);
  part(L, 'torso', 'root', [0, 0], side ? 8 : 5, (p) => drawTorso(p, view, S, sp), { ls, seed: view });
  const skirtAt = sp.bottom === 'chima' ? [0, -T * 0.58 + 3 * ws] : [0, 0];
  const hasSkirt = sp.bottom === 'chima' || sp.top === 'durumagi';
  const headAt = [side ? -3 * ws : 0, -T + (side ? 5 : 2) * ws];
  part(L, 'head', 'torso', headAt, side ? 9 : 7, (p) => drawHead(p, view, S, sp), { ls, seed: view + 'h' });
  if (!back) part(L, 'head_blink', 'torso', headAt, side ? 9 : 7, (p) => drawHead(p, view, S, { ...sp, _blink: true }), { ls, seed: view + 'h', tag: 'alt' });

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
    reuse(L, up[0], 'arm1', 'torso', [-S.shHalf + 7 * ws, shY + 2 * ws], 6.1, { r0: 0.07, flip: true });
    reuse(L, lo[0], 'arm1_l', 'arm1', [0, S.uArm], 6.2, { r0: -0.03, flip: true });
    reuse(L, up[0], 'arm2', 'torso', [S.shHalf - 7 * ws, shY + 2 * ws], 6.1, { r0: -0.07 });
    reuse(L, lo[0], 'arm2_l', 'arm2', [0, S.uArm], 6.2, { r0: 0.03 });
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
  } else if (sp.back === 'jige') {
    if (back) part(L, 'pack', 'torso', [0, -T + 6 * ws], 9, (p) => drawJige(p, view, S, sp.load), { ls });
    else if (side) part(L, 'pack', 'torso', [15 * ws, -T + 12 * ws], 2, (p) => drawJige(p, view, S, sp.load), { ls });
    else part(L, 'pack', 'torso', [0, -T + 6 * ws], 0.5, (p) => drawJige(p, view, S, sp.load), { ls });
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
    const draw = sp.staff === 'ladle' ? (p) => drawLadle(p, S) : sp.staff === 'axe' ? (p) => drawAxe(p, S) : (p) => drawStaff(p, S, sp);
    part(L, 'staff', hand, [0, S.lArm + 2], side ? 10.95 : 6.15, draw, { abs: true, ls, tag: 'staff', r0: side && sp.staff === 'axe' ? 0.15 : 0 });
  }
  addCombatParts(L, view, S, sp, ls);
  if (sp.flour) {
    const done = new Set();
    for (const q of L) if (q.img && /^(torso|arm|leg|skirt)/.test(q.name) && !done.has(q.img)) { done.add(q.img); dustFlour(q.img, hashStr(view + q.name)); }
  }
  return finishView(L);
}


// ---------------------------------------------------------------------------
// 프레임 스타일용 '이음매 없는' 팔·다리·꼬리 (어깨~손, 엉덩이~발을 한 붓으로)
// ---------------------------------------------------------------------------
/** 모든 좌표를 (dx, dy)만큼 옮겨 그리는 화가 대리자 */
function offsetPainter(p, dx, dy) {
  const mv = (pts) => pts.map((q) => (q[2] ? [q[0] + dx, q[1] + dy, q[2]] : [q[0] + dx, q[1] + dy]));
  return {
    poly: (pts, f, o) => p.poly(mv(pts), f, o),
    stroke: (pts, o) => p.stroke(mv(pts), o),
    ellipse: (cx, cy, rx, ry, f, o) => p.ellipse(cx + dx, cy + dy, rx, ry, f, o),
    fill: (pts, c, o) => p.fill(mv(pts), c, o),
    dot: (x, y, r, c) => p.dot(x + dx, y + dy, r, c),
    clip: (path, fn) => p.clip(path, fn),
    blush: (x, y, r, c, a) => p.blush(x + dx, y + dy, r, c, a),
  };
}
function drawFullArm(p, S, sp) {
  const ws = S.ws, U = S.uArm, L = S.uArm + S.lArm, skin = sp.skin || PAL.skin;
  p.poly([[-5 * ws, L - 4 * ws], [5 * ws, L - 4 * ws], [6.5 * ws, L + 3 * ws], [3 * ws, L + 8 * ws], [-3 * ws, L + 8 * ws], [-6.5 * ws, L + 3 * ws]], skin, { w: 1.8 });
  // 어깨에서 손목까지 한 장의 소매: 위는 좁고, 팔꿈치 아래로 배래가 둥글게 흘러내림
  const path = p.poly([
    [-8.5 * ws, -2 * ws], [0, -7 * ws], [8.5 * ws, -2 * ws], [9.5 * ws, U * 0.7], [12 * ws, U + S.lArm * 0.25], [13.5 * ws, L - 12 * ws],
    [10 * ws, L - 3 * ws], [3 * ws, L], [-7 * ws, L - 1 * ws, 'c'], [-10 * ws, L - 8 * ws], [-10.5 * ws, U + S.lArm * 0.2], [-9 * ws, U * 0.6],
  ], sp.coat, { w: 2.2, shadeDown: 0.3 });
  p.clip(path, () => {
    if (sp.cuff) p.stroke([[-14 * ws, L - 5 * ws], [16 * ws, L - 6 * ws]], { w: 8 * ws, color: sp.cuff, taper: false });
    const fold = shade(sp.coat, -0.42);
    p.stroke([[-3 * ws, U * 0.2], [-1 * ws, U * 0.9], [-3 * ws, U + S.lArm * 0.6], [0, L - 6 * ws]], { w: 0.9, color: fold });
    p.stroke([[5 * ws, U * 0.75], [9 * ws, U + S.lArm * 0.4], [9 * ws, L - 6 * ws]], { w: 0.8, color: fold });
  });
}
function drawFullLeg(p, S, sp, view) {
  const ws = S.ws, T = S.thigh, L = S.thigh + S.shin, pc = sp.pants || sp.coat;
  // 엉덩이~발목 한 장의 바지: 허벅지는 넉넉하고 무릎 아래로 모여 대님에서 묶임
  const path = p.poly([
    [-12 * ws, -4], [12 * ws, -4], [15 * ws, T * 0.45], [14 * ws, T], [11 * ws, T + S.shin * 0.4], [7.5 * ws, L - 12 * ws],
    [-7.5 * ws, L - 12 * ws], [-11 * ws, T + S.shin * 0.4], [-14 * ws, T], [-15 * ws, T * 0.45],
  ], pc, { w: 2.2 });
  p.clip(path, () => {
    const fold = shade(pc, -0.3);
    p.stroke([[-6 * ws, T * 0.2], [-3 * ws, T * 0.85], [-1 * ws, T + S.shin * 0.5]], { w: 1, color: fold });
    p.stroke([[7 * ws, T * 0.5], [4 * ws, T + 4], [6 * ws, T + S.shin * 0.3]], { w: 1, color: fold });
    if (sp.patch) {
      p.poly([[-2 * ws, T * 0.55], [11 * ws, T * 0.52], [12 * ws, T * 0.78], [-1 * ws, T * 0.8]], sp.patch, { w: 1.1, smooth: false, rough: 1 });
    }
  });
  shinDetails(offsetPainter(p, 0, T), S, sp, view);
}
function drawFullTigerLeg(p, len, w0, w1, front, pawDir) {
  tigerLeg(p, len, w0, w1, 3, true, pawDir, front);
}
function drawFullTail(p, len) {
  const path = p.poly(limbPts(len, 20, 9), TIGER.body, { w: 2.6 });
  p.clip(path, (g) => {
    for (let i = 0; i < 5; i++) {
      const y = len * (0.12 + i * 0.16);
      p.stroke([[-14, y], [0, y + 7], [14, y + 1]], { w: 7, color: TIGER.stripe, dry: true });
    }
    g.fillStyle = TIGER.stripe; g.fillRect(-14, len * 0.86, 28, len);
  });
}

/**
 * 프레임 굽기용 이음매 없는 팔다리 그림. name: 'arm1'|'arm2'|'leg1'|'leg2'|'front1'|'front2'|'hind1'|'hind2'|'tail'
 * 돌려주는 값: { img, ox, oy, L1, L2 } — 피벗(어깨/엉덩이)이 원점, 이미지 +y 방향으로 뻗음
 */
const _fullCache = new Map();
export function frameLimb(rig, view, name) {
  const key = rig.kind + '|' + view + '|' + name;
  if (_fullCache.has(key)) return _fullCache.get(key);
  const parts = rig.views[view];
  const up = parts.find((q) => q.name === name);
  const far = !!(up && up.far);
  const P = painter();
  P.begin(hashStr(key));
  P.lineScale = rig.spec.child ? 0.82 : 1;
  P.tint = null;
  let L1 = 0, L2 = 0;
  if (rig.type === 'human') {
    const S = rig.S;
    if (name.startsWith('arm')) { drawFullArm(P, S, rig.spec); L1 = S.uArm; L2 = S.lArm; }
    else { drawFullLeg(P, S, rig.spec, view); L1 = S.thigh; L2 = S.shin; }
  } else if (name === 'tail') {
    drawFullTail(P, 160); L1 = 40; L2 = 120;
  } else {
    const lo = parts.find((q) => q.name === name + '_l');
    L1 = lo ? lo.at[1] : 60;
    const front = view !== 'side';
    const hind = name.startsWith('hind');
    if (view === 'side') {
      if (hind) { drawFullTigerLeg(P, L1 + 54, 56, 24, false, -1); L2 = 54; }
      else { drawFullTigerLeg(P, L1 + 52, 44, 26, false, -1); L2 = 52; }
    } else if (view === 'front') { drawFullTigerLeg(P, L1 + 44, 40, 28, true, 0); L2 = 44; }
    else { drawFullTigerLeg(P, L1 + 42, 40, 22, front, 0); L2 = 42; }
  }
  let { img, ox, oy } = P.end();
  if (far) img = darkenCopy(img, 0.2);
  const out = { img, ox, oy, L1, L2, flip: !!(up && up.flip) };
  _fullCache.set(key, out);
  return out;
}

// ---- 사람 애니메이션 ----
function humanPose(view, anim, t, rig, at = t, st = {}) {
  const SP = humanStoryPose(view, anim, t, at, rig);
  if (SP) return SP;
  const C = humanCombatPose(view, anim, t, at, rig);
  if (C) return C;
  const P = humanBasePose(view, anim, t, rig, st);
  if (st.armed) {
    // 칼을 든 채 걷기·대기: 칼끝이 앞쪽 아래를 향함
    const sw = P.sword || (P.sword = { r: 0, x: 0, y: 0, sx: 1, sy: 1 });
    sw.r += view === 'side' ? 0.6 : view === 'back' ? 0.35 : -0.35;
  }
  return P;
}

/** 걷기·뛰기 보폭(m, 한 주기=두 걸음). Character가 이동 속도로 위상을 진행시킨다. */
export function strideOf(rig, anim) {
  if (rig.type === 'tiger') return anim === 'run' ? 2.6 : anim === 'prowl' ? 0.9 : anim === 'retreat' ? 1.6 : 1.25;
  const legM = (rig.S.hip / rig.ppm) * rig.scale;
  const A = anim === 'run' ? RUN_A : WALK_A;
  const k = rig.spec.bottom === 'chima' ? 0.6 : 1;
  return 4 * legM * sin(A * k) * (anim === 'run' ? 1.35 : 1);
}
const WALK_A = 0.5, RUN_A = 0.78;

function humanBasePose(view, anim, t, rig, st = {}) {
  const sp = rig.spec, k = rig.S.ws;
  const P = {};
  const set = (n, r = 0, x = 0, y = 0, sx = 1, sy = 1) => (P[n] = { r, x, y, sx, sy });
  const stoop = sp.stoop || 0;
  const run = anim === 'run', walk = anim === 'walk' || run;
  // 위상: 이동 속도로 진행(없으면 시간)
  const cyc = st.phase != null ? st.phase : t / ((run ? 0.62 : 0.8) * (sp.child ? 0.82 : 1));
  const ph = cyc * PI * 2, s = sin(ph), c = cos(ph);
  const br = sin((t / 3.4) * PI * 2), br2 = sin((t / 3.4) * PI * 2 - 0.6);
  const side = view === 'side';
  const gestArmSide = sp.staff ? 'arm1' : 'arm2';
  const chimaK = sp.bottom === 'chima' ? 0.6 : 1;
  // 무게: 디딤(contact) 직후 가장 낮고(down), 두 다리가 스칠 때(pass) 지나 가장 높다(up)
  const down = cos(2 * (ph - PI / 2 - 0.35));
  const bob = (run ? 9 : 4.5) * k;

  if (side) {
    if (walk) {
      const A = (run ? RUN_A : WALK_A) * chimaK;
      const B = run ? 1.35 : 0.75;
      set('leg2', A * s + (run ? 0.1 : 0));
      set('leg2_l', -B * pow(max(0, c), 1.3) - 0.1 * max(0, -s));
      set('leg1', -A * s + (run ? 0.1 : 0));
      set('leg1_l', -B * pow(max(0, -c), 1.3) - 0.1 * max(0, s));
      // 팔은 다리 반대로, 반 박자 늦게, 앞으로 갈 때 팔꿈치가 굽음
      const as = sin(ph - 0.35);
      set('arm2', -0.75 * A * as);
      set('arm2_l', (run ? 1.1 : 0.15) + 0.35 * max(0, -as));
      set('arm1', 0.75 * A * as);
      set('arm1_l', (run ? 1.1 : 0.15) + 0.35 * max(0, as));
      set('root', 0.015 * down, 0, down * bob - (run ? 4 : 0) * k);
      set('torso', (run ? -0.2 : -0.05) - stoop + 0.02 * down);
      set('head', (run ? 0.12 : 0.03) + stoop * 0.7 - 0.02 * down);
      set('skirt', (sp.bottom === 'chima' ? 0.35 : 0.2) * A * sin(ph - 0.9) + (run ? -0.12 : -0.04), 0, 0, 1 + 0.08 * abs(s));
      set('braid', -(run ? 0.55 : 0.2) + 0.1 * down);
      set('pack', 0.05 * down);
      set('staff', 0.14 * s);
    } else {
      set('root', 0, 0, 0.6 * br * k);
      set('torso', -stoop, 0, 0, 1, 1 + 0.014 * br);
      set('head', stoop * 0.7 + 0.015 * br2, 0, -1.2 * br * k);
      set('arm1', 0.025 * br2); set('arm2', -0.025 * br2);
      set('arm1_l', 0.02 * br2); set('arm2_l', 0.02 * br2);
      set('skirt', 0, 0, 0, 1 + 0.012 * br);
      set('braid', 0.04 * sin(t * 1.3));
      set('staff', 0.05);
      if (anim === 'talk') {
        const g = sin(t * PI * 2 * 0.9);
        set('head', stoop * 0.7 + 0.05 * sin(t * PI * 2 * 1.7), 0, -1.2 * br * k);
        set(gestArmSide, 0.5 + 0.1 * g);
        set(gestArmSide + '_l', 0.9 + 0.25 * g);
      }
    }
    if (sp.carry === 'basket') { set('arm2', 2.75 + 0.03 * s); set('arm2_l', 0.4); }
  } else {
    const flip = view === 'back' ? -1 : 1;
    if (walk) {
      const lift = (run ? 10 : 6) * k * chimaK;
      const l1 = pow(max(0, s), 1.5) * lift, l2 = pow(max(0, -s), 1.5) * lift;
      set('leg1', 0.04 * s, 0, -l1, 1, 1);
      set('leg1_l', -0.05 * s, 0, 0, 1, 1 - 0.08 * max(0, s));
      set('leg2', 0.04 * s, 0, -l2, 1, 1);
      set('leg2_l', -0.05 * s, 0, 0, 1, 1 - 0.08 * max(0, -s));
      const as = run ? 0.28 : 0.14, sa = sin(ph - 0.35);
      set('arm1', as * 0.5 * sa + (run ? 0.18 : 0), 0, 0, 1, 1 - as * 0.7 * max(0, -sa * flip));
      set('arm2', as * 0.5 * sa - (run ? 0.18 : 0), 0, 0, 1, 1 - as * 0.7 * max(0, sa * flip));
      set('arm1_l', run ? -0.6 : -0.05 * sa); set('arm2_l', run ? 0.6 : -0.05 * sa);
      // 체중 이동: 디딘 발 쪽으로 엉덩이가 실린다
      set('root', 0.02 * s, 2.2 * s * k, down * bob * 0.8);
      set('torso', -0.025 * s, 0, 0, 1, (stoop ? 0.95 : 1) - 0.01 * down);
      set('head', 0.02 * s, 0, (stoop ? 6 : 0));
      set('skirt', 0.04 * sin(ph - 0.5), 0, 0, 1 + 0.04 * abs(s));
      set('braid', 0.08 * sin(ph - 0.8));
      set('pack', -0.03 * s);
      set('staff', 0.06 * s);
    } else {
      set('root', 0, 0, 0.5 * br * k);
      set('torso', 0, 0, 0, 1, (stoop ? 0.95 : 1) + 0.014 * br);
      set('head', 0.012 * sin(t * 0.7), 0, (stoop ? 6 : 0) - 1.2 * br * k);
      set('arm1', 0.025 * br2); set('arm2', -0.025 * br2);
      set('skirt', 0, 0, 0, 1 + 0.01 * br);
      set('braid', 0.03 * sin(t * 1.3));
      if (anim === 'talk') {
        const g = sin(t * PI * 2 * 0.9);
        set('head', 0.05 * sin(t * PI * 2 * 1.7), 0, (stoop ? 6 : 0) - 1.2 * br * k);
        set('arm1', 0.22 + 0.06 * g);
        set('arm1_l', -1.3 + 0.3 * g, 0, 0, 1, 0.85);
      }
    }
    if (sp.carry === 'basket') {
      const a = view === 'back' ? 'arm2' : 'arm1', sg = view === 'back' ? -1 : 1;
      set(a, sg * (2.6 + 0.02 * s)); set(a + '_l', sg * 0.75);
    }
  }
  return P;
}

// ---------------------------------------------------------------------------
// 호랑이 (민화 까치호랑이)
// ---------------------------------------------------------------------------
const TIGER = {
  body: '#cf9444',
  back: '#9f6a2c',
  belly: '#f1e6cc',
  stripe: '#17120f',
  eyeW: '#d9cf6a',
};

const rgbaHex = (h, a) => { const n = parseInt(h.slice(1), 16); return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`; };

function stripeClip(p, path, lines, w = 7) {
  p.clip(path, () => { for (const l of lines) p.stroke(l, { w, color: TIGER.stripe, dry: w > 5 }); });
}

/**
 * 호랑이 얼굴(정면을 노려봄): 넓은 광대와 볼 갈기, 짙은 테를 두른 둥근 눈, 붓으로 친 이마 무늬.
 * mode: 'normal' | 'roar' | 'dead'
 */
function tigerFace(p, cx, cy, sc = 1, turned = 0, mode = 'normal') {
  const roar = mode === 'roar', dead = mode === 'dead';
  const X = (x) => cx + x * sc, Y = (y) => cy + y * sc;
  const R = (x, y) => [X(x) + turned * (1 - abs(y) / 60) * 4, Y(y)];
  // 귀: 작고 뒤로 붙은 귀, 뒷면은 검고 가운데 흰 점
  for (const s of [-1, 1]) {
    p.poly([[X(s * 30), Y(-38)], [X(s * 44), Y(-58)], [X(s * 56), Y(-40)], [X(s * 50), Y(-30)]], TIGER.stripe, { w: 2.4 });
    p.ellipse(X(s * 45), Y(-44), 4 * sc, 4.5 * sc, TIGER.belly, { w: 0.8, blot: false });
  }
  // 얼굴 윤곽: 평평한 이마, 넓은 광대, 아래로 들쭉날쭉한 볼 갈기
  const ruff = roar ? 1.18 : 1;
  const head = [
    [X(0), Y(-44)], [X(24), Y(-42)], [X(44), Y(-30)], [X(58), Y(-8)],
    [X(66 * ruff), Y(8), 'c'], [X(58), Y(14)], [X(66 * ruff), Y(24), 'c'], [X(52), Y(28)], [X(56 * ruff), Y(40), 'c'], [X(36), Y(40)],
    [X(20), Y(52)], [X(0), Y(56)], [X(-20), Y(52)], [X(-36), Y(40)],
    [X(-56 * ruff), Y(40), 'c'], [X(-52), Y(28)], [X(-66 * ruff), Y(24), 'c'], [X(-58), Y(14)], [X(-66 * ruff), Y(8), 'c'],
    [X(-58), Y(-8)], [X(-44), Y(-30)], [X(-24), Y(-42)],
  ];
  const hp = p.poly(head, TIGER.body, { w: 3.2, shadeDown: 0.35 });
  p.clip(hp, () => {
    // 흰 털: 눈 위, 볼 아래, 턱
    for (const s of [-1, 1]) {
      p.poly([[X(s * 8), Y(-18)], [X(s * 26), Y(-26)], [X(s * 38), Y(-18)], [X(s * 24), Y(-14)]], TIGER.belly, { ink: false, grain: 0.7, blot: false });
      p.poly([[X(s * 30), Y(12)], [X(s * 70), Y(10)], [X(s * 70), Y(44)], [X(s * 26), Y(36)]], TIGER.belly, { ink: false, grain: 0.7 });
    }
    p.poly([[X(-22), Y(30)], [X(22), Y(30)], [X(22), Y(60)], [X(-22), Y(60)]], TIGER.belly, { ink: false, grain: 0.7 });
    // 이마 '王' 무늬와 뺨 줄무늬(붓끝이 빠지는 획)
    const L = (pts, w) => p.stroke(pts.map((q) => R(q[0], q[1])), { w: w * sc, color: TIGER.stripe, dry: true });
    L([[-16, -40], [-8, -34], [-14, -26]], 5); L([[16, -40], [8, -34], [14, -26]], 5);
    L([[-6, -44], [0, -36], [6, -44]], 4); L([[0, -32], [0, -22]], 4.5);
    L([[-22, -36], [-12, -30]], 3.5); L([[22, -36], [12, -30]], 3.5);
    for (const s of [-1, 1]) {
      L([[s * 64, -6], [s * 46, -4], [s * 40, 4]], 6);
      L([[s * 66, 14], [s * 52, 16], [s * 46, 24]], 5.5);
      L([[s * 50, -26], [s * 40, -18]], 4);
      L([[s * 60, 30], [s * 48, 34]], 4);
    }
  });
  // 볼 갈기 갈필 털
  const fr = [];
  for (let i = 0; i < 9; i++) {
    const t = i / 8, y = 6 + t * 36;
    for (const s of [-1, 1]) fr.push([X(s * (62 - t * 8) * ruff), Y(y), s, 0.35]);
  }
  p.fur(fr, (roar ? 16 : 11) * sc, TIGER.stripe, 1.1, 0.5);
  // 주둥이
  for (const s of [-1, 1]) p.ellipse(X(s * 12), Y(22), 15 * sc, 11 * sc, TIGER.belly, { w: 1.6, shadeDown: 0.2 });
  for (const s of [-1, 1]) for (let i = 0; i < 3; i++) p.dot(X(s * (7 + i * 5)), Y(19 + (i % 2) * 4), 1.2 * sc);
  // 코: 넓은 콧등 + 짙은 코
  p.stroke([[X(-6), Y(-14)], [X(-8), Y(4)]], { w: 1.2, color: shade(TIGER.body, -0.45) });
  p.stroke([[X(6), Y(-14)], [X(8), Y(4)]], { w: 1.2, color: shade(TIGER.body, -0.45) });
  p.poly([[X(-10), Y(6)], [X(10), Y(6)], [X(3), Y(14)], [X(0), Y(16), 'c'], [X(-3), Y(14)]], '#4a2a25', { w: 2 });
  if (roar) {
    p.poly([[X(-24), Y(26)], [X(0), Y(22)], [X(24), Y(26)], [X(20), Y(56)], [X(0), Y(66)], [X(-20), Y(56)]], '#5e1a18', { w: 3.2 });
    p.ellipse(X(0), Y(54), 11 * sc, 7 * sc, '#b8544b', { w: 1.2, ink: '#3a1010' });
    for (const s of [-1, 1]) {
      p.poly([[X(s * 11), Y(25)], [X(s * 20), Y(26)], [X(s * 15), Y(42), 'c']], '#fbf6e8', { w: 1.4, smooth: false });
      p.poly([[X(s * 10), Y(60)], [X(s * 18), Y(57)], [X(s * 14), Y(47), 'c']], '#fbf6e8', { w: 1.4, smooth: false });
    }
  } else if (dead) {
    p.stroke([[X(-14), Y(32)], [X(0), Y(30)], [X(14), Y(32)]], { w: 2 * sc });
    p.ellipse(X(5), Y(38), 4.5 * sc, 6.5 * sc, '#b8544b', { w: 1.2 });
  } else {
    // 굳게 다문 입(아래로 처진 선) + 송곳니 끝
    p.stroke([[X(0), Y(16)], [X(0), Y(26)]], { w: 1.6 * sc });
    p.stroke([[X(-22), Y(36)], [X(-10), Y(30)], [X(0), Y(28)], [X(10), Y(30)], [X(22), Y(36)]], { w: 2.4 * sc });
    for (const s of [-1, 1]) p.poly([[X(s * 7), Y(29)], [X(s * 11), Y(30)], [X(s * 9), Y(37), 'c']], '#fbf6e8', { w: 1.1, smooth: false });
  }
  // 눈
  for (const s of [-1, 1]) {
    const ex = X(s * 21), ey = Y(-6);
    if (dead) {
      p.stroke([[ex - 11 * sc, ey], [ex, ey + 4 * sc], [ex + 11 * sc, ey - 1 * sc]], { w: 3 * sc });
      continue;
    }
    // 눈썹 먹선(화나면 안쪽으로 내리꽂힘)
    if (roar) p.stroke([[X(s * 6), Y(-12)], [X(s * 22), Y(-22)], [X(s * 42), Y(-28)]], { w: 6 * sc, dry: true });
    else p.stroke([[X(s * 7), Y(-16)], [X(s * 24), Y(-22)], [X(s * 42), Y(-18)]], { w: 4.2 * sc, dry: true });
    // 아몬드처럼 치켜 올라간 눈 + 짙은 눈테
    const ew = 13 * sc, eh = (roar ? 8 : 10) * sc;
    const eye = [[ex - s * ew, ey + 2 * sc], [ex - s * 3 * sc, ey - eh], [ex + s * ew, ey - 5 * sc, 'c'], [ex + s * 2 * sc, ey + eh * 0.9]];
    p.poly(eye, TIGER.eyeW, { w: 3.6, grain: 0.35, shadeDown: 0.4 });
    p.dot(ex, ey - 1 * sc, (roar ? 2.4 : 3.4) * sc, '#0e0a08');
    p.dot(ex - 2 * sc, ey - 4 * sc, 1.2 * sc, '#fffbe8');
    // 눈꼬리에서 흘러내리는 검은 줄
    p.stroke([[ex + s * ew, ey - 4 * sc], [ex + s * (ew + 6 * sc), ey + 6 * sc], [ex + s * (ew + 4 * sc), ey + 16 * sc]], { w: 3 * sc });
  }
  // 수염: 가는 먹 털
  for (const s of [-1, 1]) {
    for (let i = 0; i < 4; i++) {
      const y0 = 18 + i * 4;
      const tip = roar ? [s * (84 + i * 4), -10 + i * 10] : dead ? [s * (60 + i * 4), 40 + i * 12] : [s * (82 + i * 5), 10 + i * 12];
      p.stroke([[X(s * 20), Y(y0)], [X(s * (48 + i * 4)), Y(y0 + (tip[1] - y0) * 0.4)], [X(tip[0]), Y(tip[1])]], { w: 0.75, color: '#241b16', rough: 0.2 });
    }
  }
  if (roar) {
    for (let i = 0; i < 3; i++) {
      const r = (74 + i * 16) * sc;
      p.stroke(ellipsePts(cx, cy + 36 * sc, r, r * 0.55, 20, PI * 0.2, PI * 0.8), { w: 4 - i, color: INK, dry: true });
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
  stripeClip(p, path, lines, 7);
  if (paw) {
    const px = front ? 0 : pawDir * 7;
    p.ellipse(px, len + 3, front ? w1 * 0.8 : w1 * 0.95, front ? w1 * 0.45 : w1 * 0.42, TIGER.body, { w: 2.5 });
    const tw = front ? w1 * 0.35 : w1 * 0.3;
    for (let i = -1; i <= 1; i++) p.stroke([[px + i * tw + (front ? 0 : pawDir * 4), len + 5], [px + i * tw + (front ? 0 : pawDir * 7), len + 10]], { w: 1.4 });
    // 발톱 끝
    for (let i = -1; i <= 1; i++) p.stroke([[px + i * tw * 1.1 + (front ? 0 : pawDir * 10), len + 9], [px + i * tw * 1.2 + (front ? 0 : pawDir * 14), len + 13]], { w: 1.6, color: '#efe6d0', taper: true });
  }
}

function tigerTailSeg(p, len, w0, w1, tip) {
  const path = p.poly(limbPts(len, w0, w1), TIGER.body, { w: 2.4 });
  p.clip(path, (g) => {
    p.stroke([[-w0, len * 0.28], [0, len * 0.36], [w0, len * 0.3]], { w: 7, color: TIGER.stripe, dry: true });
    p.stroke([[w0, len * 0.72], [0, len * 0.8], [-w0, len * 0.74]], { w: 6, color: TIGER.stripe, dry: true });
    if (tip) { g.fillStyle = TIGER.stripe; g.fillRect(-w0, len * 0.72, w0 * 2, len); }
  });
}


// ---- 호랑이 변장(어미 저고리 + 수건 + 밀가루 묻은 흰 앞발) ----
const DISG = { coat: '#e3cf98', goreum: '#a8473e', scarf: '#e8e1cd', flour: '#f6f3ea' };
function drawDisgCoat(p, view) {
  const c = DISG.coat, fold = shade(c, -0.4);
  if (view === 'side') {
    // 어깨에 걸친 저고리: 등 위로 넘어가고 빈 소매가 앞다리 쪽으로 늘어짐, 찢어진 단
    const path = p.poly([[-54, -36], [-20, -52], [30, -46], [56, -22], [52, 18], [34, 30, 'c'], [28, 20], [18, 34, 'c'], [6, 22], [-10, 36, 'c'], [-22, 24], [-40, 30], [-58, 6]], c, { w: 2.2, shadeDown: 0.3 });
    p.clip(path, () => {
      p.stroke([[-30, -44], [-10, 0], [-14, 26]], { w: 1, color: fold });
      p.stroke([[20, -40], [30, 0]], { w: 1, color: fold });
      p.stroke([[-54, -30], [-40, -10]], { w: 5, color: shade(c, -0.15), taper: false });
    });
    // 빈 소매
    p.poly([[-50, -2], [-34, 0], [-30, 56], [-44, 62], [-56, 50]], c, { w: 2 });
    p.stroke([[-48, 52], [-34, 54]], { w: 4, color: shade(c, 0.2), taper: false });
    // 고름
    p.poly([[-46, -14], [-52, 14], [-46, 14]], DISG.goreum, { w: 1.3 });
    p.poly([[-44, -14], [-38, 8], [-34, 6]], DISG.goreum, { w: 1.3 });
    return;
  }
  const back = view === 'back';
  const path = p.poly([[-64, -10], [-40, -34], [0, -40], [40, -34], [64, -10], [60, 30], [44, 44, 'c'], [30, 32], [12, 46, 'c'], [-6, 34], [-24, 46, 'c'], [-40, 34], [-60, 32]], c, { w: 2.2, shadeDown: 0.3 });
  p.clip(path, () => {
    p.stroke([[-30, -30], [-26, 30]], { w: 1, color: fold });
    p.stroke([[30, -30], [28, 30]], { w: 1, color: fold });
    if (!back) p.stroke([[-20, -38], [0, -20], [20, -38]], { w: 6, color: shade(c, -0.15), taper: false });
  });
  if (!back) {
    p.poly([[-4, -18], [-10, 12], [-4, 12]], DISG.goreum, { w: 1.3 });
    p.poly([[-2, -18], [6, 8], [10, 6]], DISG.goreum, { w: 1.3 });
  }
}
function drawDisgScarf(p, view, cx, top, w) {
  const c = DISG.scarf, fold = shade(c, -0.35);
  const path = p.poly([[cx - w, top + 22], [cx - w * 0.7, top + 4], [cx, top - 4], [cx + w * 0.7, top + 4], [cx + w, top + 22], [cx + w * 0.6, top + 14], [cx, top + 10], [cx - w * 0.6, top + 14]], c, { w: 2 });
  p.clip(path, () => p.stroke([[cx - w * 0.6, top + 9], [cx + w * 0.6, top + 9]], { w: 0.9, color: fold }));
  const kx = view === 'back' ? cx : cx + w * 0.9;
  p.ellipse(kx, top + 20, 6, 5, c, { w: 1.5 });
  p.poly([[kx + 2, top + 22], [kx + 12, top + 40], [kx + 4, top + 38]], c, { w: 1.3 });
}
function drawWhitePaw(p, x, y, rx, ry) {
  p.ellipse(x, y, rx, ry, DISG.flour, { w: 2.2, grain: 0.5 });
  for (let i = -1; i <= 1; i++) p.stroke([[x + i * rx * 0.35, y + ry * 0.2], [x + i * rx * 0.35, y + ry * 0.9]], { w: 1.2 });
  p.blush(x - rx * 0.3, y - ry * 0.6, rx * 0.8, '#f7f4ec', 0.8);
}
function addDisguise(L, view) {
  const o = { tag: 'disg' };
  if (view === 'side') {
    part(L, 'disg_coat', 'root', [-92, -58], 7, (p) => drawDisgCoat(p, view), o);
    part(L, 'disg_scarf', 'head', [0, 0], 8.6, (p) => drawDisgScarf(p, view, -26, -72, 48), o);
    part(L, 'disg_paw1', 'front1_l', [0, 0], 0.95, (p) => drawWhitePaw(p, -7, 55, 25, 11), o);
    part(L, 'disg_paw2', 'front2_l', [0, 0], 4.95, (p) => drawWhitePaw(p, -7, 55, 25, 11), o);
  } else if (view === 'front') {
    part(L, 'disg_coat', 'root', [0, -36], 3.5, (p) => drawDisgCoat(p, view), o);
    part(L, 'disg_scarf', 'head', [0, 0], 4.6, (p) => drawDisgScarf(p, view, 0, -66, 46), o);
    part(L, 'disg_paw1', 'front1_l', [0, 0], 2.15, (p) => drawWhitePaw(p, 0, 47, 22, 12), o);
    part(L, 'disg_paw2', 'front2_l', [0, 0], 2.15, (p) => drawWhitePaw(p, 0, 47, 22, 12), o);
  } else {
    part(L, 'disg_coat', 'root', [0, -30], 2.5, (p) => drawDisgCoat(p, view), o);
    part(L, 'disg_scarf', 'head', [0, 0], 0.6, (p) => drawDisgScarf(p, view, 0, -48, 46), o);
    part(L, 'disg_paw1', 'front1', [0, 0], 0.85, (p) => drawWhitePaw(p, 0, 55, 22, 11), o);
    part(L, 'disg_paw2', 'front2', [0, 0], 0.85, (p) => drawWhitePaw(p, 0, 55, 22, 11), o);
  }
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
      // 무거운 어깨, 깊은 가슴, 잘록한 허리, 단단한 엉덩이
      const pts = [[-168, -16], [-158, -62], [-118, -94], [-76, -80], [-30, -58], [30, -54], [96, -64], [150, -66], [184, -44], [198, -10], [188, 22], [162, 44], [126, 34], [84, 18], [20, 30], [-50, 54], [-112, 70], [-156, 46]];
      const path = p.poly(pts, TIGER.body, { w: 3.8, shadeDown: 0.25 });
      p.clip(path, () => {
        // 등줄기 농담: 등은 짙고 옆구리로 갈수록 옅게
        p.stroke([[-160, -64], [-118, -96], [-76, -82], [-30, -60], [30, -56], [96, -66], [150, -68], [186, -46]], { w: 34, color: rgbaHex(TIGER.back, 0.55), taper: false });
        p.stroke([[-150, -30], [-60, -20], [40, -18], [150, -24]], { w: 26, color: rgbaHex('#e6b565', 0.35), taper: false });
        // 배 쪽 흰 털
        p.poly([[-164, 22], [-108, 48], [-40, 32], [30, 16], [84, 6], [134, 20], [134, 90], [-164, 90]], TIGER.belly, { ink: false, grain: 0.7 });
        // 서예 획 같은 줄무늬: 등뼈에서 굵게 시작해 옆구리로 가늘게 빠지고, 몇 개는 둘로 갈라짐
        const R = (i) => ((i * 73) % 17) / 17;
        for (let i = 0; i < 13; i++) {
          const x = -134 + i * 25 + R(i) * 8;
          const top = -96 + abs(i - 2.5) * 3.2 + (i > 6 ? 6 : 0);
          const len = 62 + R(i + 3) * 34 - (i === 0 ? 20 : 0);
          const bend = (i % 2 ? 1 : -1) * 7;
          p.stroke([[x - 5, top], [x + bend, top + len * 0.35], [x - bend * 0.6, top + len * 0.7], [x + 6, top + len]], { w: 12 - (i % 3) * 1.5, color: TIGER.stripe, dry: true });
          if (i % 3 !== 1) p.stroke([[x + bend * 0.2, top + len * 0.4], [x + 12, top + len * 0.58], [x + 15, top + len * 0.85]], { w: 5.5, color: TIGER.stripe, dry: true });
        }
      });
      // 배와 가슴의 갈필 털
      const fr = [];
      for (let i = 0; i < 9; i++) { const t = i / 8; fr.push([-140 + t * 200 + (i % 2) * 6, 56 - t * 30, 0.25 - (i % 3) * 0.2, 1]); }
      for (let i = 0; i < 6; i++) fr.push([-166 + i * 2, -6 + i * 9, -1, 0.3]);
      p.fur(fr, 11, INK, 1.2, 0.7);
    });
    reuse(L, hu, 'hind2', 'root', [128, -6], 5, { r0: 0.28 });
    reuse(L, hl, 'hind2_l', 'hind2', [0, 60], 4.9, { r0: -0.5 });
    reuse(L, fu, 'front2', 'root', [-114, 4], 5, { r0: 0.05 });
    reuse(L, fl, 'front2_l', 'front2', [0, 58], 4.9, { r0: -0.05 });
    // 머리: 몸은 옆, 얼굴은 보는 이를 향해 (까치호랑이)
    part(L, 'head', 'root', [-140, -46], 8, (p) => tigerFace(p, -26, -24, 0.98, -3));
    part(L, 'head_roar', 'root', [-140, -46], 8, (p) => tigerFace(p, -26, -24, 0.98, -3, 'roar'), { tag: 'alt' });
    part(L, 'head_dead', 'root', [-140, -46], 8, (p) => tigerFace(p, -26, -24, 0.98, -3, 'dead'), { tag: 'alt' });
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
      const path = p.poly([[-48, -58], [0, -66], [48, -58], [76, -18], [70, 34], [36, 60], [-36, 60], [-70, 34], [-76, -18]], TIGER.body, { w: 3.6, shadeDown: 0.3 });
      p.clip(path, () => {
        p.ellipse(0, 22, 28, 40, TIGER.belly, { ink: false, grain: 0.6 });
        for (const s of [-1, 1]) for (let i = 0; i < 4; i++) p.stroke([[s * 70, -30 + i * 20], [s * 48, -24 + i * 20], [s * 34, -28 + i * 20]], { w: 7, color: TIGER.stripe });
      });
    });
    P.begin(52); tigerLeg(P, 52, 40, 30, 2); const fu = P.end();
    P.begin(53); tigerLeg(P, 44, 30, 28, 1, true, 0, true); const fl = P.end();
    reuse(L, fu, 'front1', 'root', [-34, 12], 2, { r0: 0.04 });
    reuse(L, fl, 'front1_l', 'front1', [0, 46], 1.9, { r0: -0.04 });
    reuse(L, fu, 'front2', 'root', [34, 12], 2, { r0: -0.04 });
    reuse(L, fl, 'front2_l', 'front2', [0, 46], 1.9, { r0: 0.04 });
    part(L, 'head', 'root', [0, -58], 4, (p) => tigerFace(p, 0, -20, 0.9, 0));
    part(L, 'head_roar', 'root', [0, -58], 4, (p) => tigerFace(p, 0, -20, 0.9, 0, 'roar'), { tag: 'alt' });
    part(L, 'head_dead', 'root', [0, -58], 4, (p) => tigerFace(p, 0, -20, 0.9, 0, 'dead'), { tag: 'alt' });
    part(L, 'fx_claw', 'root', [30, 50], 6, drawClaw, { tag: 'fx' });
  }
  addDisguise(L, view);
  part(L, 'fx_burst', 'root', [0, 20], 9.5, (p) => drawBurst(p, { ws: 1.6 }), { tag: 'fx' });
  return finishView(L);
}

function tigerPose(view, anim, t, rig, at = t, st = {}) {
  if (anim !== 'idle' && anim !== 'walk' && anim !== 'run' && anim !== 'retreat') {
    const C = tigerCombatPose(view, anim, t, at, st);
    if (C) return C;
  }
  const P = {};
  const set = (n, r = 0, x = 0, y = 0, sx = 1, sy = 1) => (P[n] = { r, x, y, sx, sy });
  const side = view === 'side';
  const br = sin((t / 2.6) * PI * 2);
  const retreat = anim === 'retreat';
  const walk = anim === 'walk' || anim === 'run' || retreat;
  const period = anim === 'run' ? 0.7 : retreat ? 0.8 : 1.15;
  const ph = (st.phase != null ? st.phase : t / period) * PI * 2, s = sin(ph), c = cos(ph);
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
    if (retreat) {
      // 물러남: 꼬리를 낮게 늘어뜨리고 고개를 숙인 채 종종걸음
      const tl = { tail0: 1.25, tail1: 0.15, tail2: -0.5, tail3: -0.6 };
      for (const n in tl) P[n].r = tl[n] + 0.08 * sin(t * 6 - n.charCodeAt(4));
      const hd = P.head || (P.head = { r: 0, x: 0, y: 0, sx: 1, sy: 1 });
      hd.y += side ? 12 : 10; hd.r += side ? 0.1 : 0;
    }
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
/** 월드 대비 캐릭터 확대(HD-2D식 가독성). 키·반지름도 이 배율이 곱해진 값으로 보고한다. */
export const CHAR_SCALE = 1.25;

export const SPECS = {
  player: {
    type: 'human', height: 1.65, radius: 0.3,
    top: 'durumagi', coat: '#ece5d3', pants: '#e4dccb', collar: '#d7ceb9', sash: PAL.red, goreum: '#d9d0bb',
    hat: 'satgat', hatColor: '#4f412f', hair: 'short', back: 'bundle', bundle: '#48637a', staff: 'staff', robeLen: 94, cheek: 0.16,
    legwrap: '#efe9da', daenim: '#48637a', build: 1.04,
  },
  villager_m: {
    type: 'human', height: 1.65, radius: 0.3,
    top: 'jeogori', coat: '#d8c9a3', pants: '#ddd3bb', vest: '#5f7688', collar: '#b9a782', daenim: '#5f7688', hair: 'sangtu', stubble: true, cheek: 0.2,
    back: 'jige', patch: '#b8a47c', build: 1.12, shoe: '#a88a55'
  },
  villager_f: {
    type: 'human', height: 1.6, radius: 0.3,
    top: 'short', bottom: 'chima', coat: '#e6d6a6', skirt: '#46627b', goreum: PAL.red, cuff: '#a8574d', collar: '#a8574d', hair: 'jjok', cheek: 0.26, lip: '#a8453c',
    carry: 'basket', build: 0.94,
  },
  elder: {
    type: 'human', height: 1.6, radius: 0.3,
    top: 'durumagi', coat: '#e9e7df', pants: '#ece9e0', collar: '#cfcbc0', goreum: '#d6d2c6', hat: 'gat', hair: 'white', beard: true, wrinkles: true,
    stoop: 0.26, staff: 'cane', shoe: '#3a3431', robeLen: 104, browColor: '#8e897f', browW: 2.6, cheek: 0.12, pipe: true, build: 0.9,
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
    hat: 'beonggeoji', hair: 'short', back: 'bow', stubble: true, cheek: 0.14, build: 1.14, patch: '#8a7452',
  },
  innkeeper: {
    type: 'human', height: 1.58, radius: 0.3,
    top: 'short', bottom: 'chima', coat: '#e4d9bd', skirt: '#8e5a48', goreum: '#5d7488', cuff: '#5d7488', collar: '#5d7488', hair: 'jjok', cheek: 0.24, lip: '#a04a3e',
    apron: '#efe9da', scarf: '#e9e2cf', staff: 'ladle', build: 1.14, wrinkles: true,
  },
  miller: {
    type: 'human', height: 1.66, radius: 0.3,
    top: 'jeogori', coat: '#e6dfcd', pants: '#e2dac6', collar: '#cfc6b0', daenim: '#b8ad94', hair: 'sangtu', band: '#f3efe6', stubble: true, cheek: 0.2,
    flour: true, build: 1.06, patch: '#cfc4a8',
  },
  woodcutter: {
    type: 'human', height: 1.7, radius: 0.3,
    top: 'jeogori', coat: '#9a7f5a', pants: '#c2b28d', vest: '#6c5a40', collar: '#6c5a40', legwrap: '#e6dfcc', daenim: '#6c5a40', hair: 'sangtu', band: '#d9cfb8',
    stubble: true, cheek: 0.16, back: 'jige', load: 'wood', staff: 'axe', build: 1.16, shoe: '#a88a55',
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
      kind, type: 'tiger', spec: sp, W: 640, H: 320, footX: 320, footY: 306, ppm: 160, scale: CHAR_SCALE,
      height: sp.height * CHAR_SCALE, radius: sp.radius * CHAR_SCALE, pose: tigerPose, anims: TIGER_ANIMS,
      views: { front: tigerView('front'), back: tigerView('back'), side: tigerView('side') },
    };
  } else {
    const B = sp.child ? CHILD : ADULT, b = sp.build || 1;
    const S = { ...B, shHalf: B.shHalf * b, waistHalf: B.waistHalf * b, legX: B.legX * (0.5 + b * 0.5) };
    // 키 보정: 기준 골격(성인 약 1.62m 상당) 대비 ppm 조정
    const basePx = sp.child ? 205 : 312;
    const ppm = basePx / (sp.height - (sp.stoop ? -0.04 : 0));
    // 넘어짐·베기 궤적이 들어가도록 넉넉한 판 (대부분 투명)
    const W = sp.child ? 256 : 384, H = sp.child ? 320 : 448;
    rig = {
      kind, type: 'human', spec: sp, S, W, H, footX: W / 2, footY: H - 10, ppm, scale: CHAR_SCALE,
      height: sp.height * CHAR_SCALE, radius: sp.radius * CHAR_SCALE, pose: humanPose, anims: HUMAN_ANIMS,
      views: { front: humanView('front', S, sp), back: humanView('back', S, sp), side: humanView('side', S, sp) },
    };
  }
  _rigs.set(kind, rig);
  return rig;
}
