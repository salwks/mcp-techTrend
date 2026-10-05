// 말 그림 한 곳 — 탈 말(export_ride_frames.js) · 마방 말(export_stable_frames.js) · 주변 말(export_npc_frames.js)이 같이 쓴다.
// 꼭두각시(몸통·다리 조각을 따로 그려 돌리기)가 아니라, 장마다 말 한 마리를 '한 윤곽'으로 그린다:
//   - 옆모습: 등선(기갑 → 등 → 허리 → 엉덩이 → 꼬리뿌리 → 궁둥이 → 넓적다리 뒤) · 배선(사타구니 → 배 → 앞가슴 → 어깨끝) · 목(갈기 선과
//     목 밑선)을 한 붓 윤곽으로 잇고, 머리는 머리뼈 꼴(이마 · 콧등 · 둥근 주둥이 · 큰 볼 · 턱 밑)을 한 덩이로 그린다.
//     다리는 관절 사슬(팔꿈치 · 앞팔 · 무릎 · 정강이 · 구절 · 발목 · 굽 / 뒤: 넓적다리 · 비절 · 정강이 · 구절 · 발목 · 굽)의 굵기 윤곽 —
//     굽은 땅을 디디고(디딘 다리 굽이 땅에 닿게 몸 높이를 맞춘다), 들린 다리는 무릎·비절이 꺾여 굽이 뒤집힌다.
//   - 앞모습 · 뒷모습: 정면 꼴로 따로 그린다(가슴 · 어깨 · 앞팔 근육 · 긴 얼굴 / 두 볼기 · 꼬리 · 비절). turn(−1~1)으로 몸이 조금 돌아
//     한쪽 옆구리가 보이고 머리가 그쪽으로 간다(마방 칸 말: 칸마다 좌우를 달리).
// 걸음은 실제 걸음새: walk = 네 박(왼뒤 → 왼앞 → 오른뒤 → 오른앞, 디딤 60%), trot(속보) = 대각 두 박(디딤 45%, 뜸 있음).
// 머리는 걸음마다 끄덕이고(walk), 속보에서는 덜 흔들린다. idle 묶음: 꼬리 휘두름 · 귀 돌림 · 머리 들기 · 한 발 쉬기.
// 길이 단위: 그림 m(기갑 높이 1.47), 발 중심 원점, 위 +y, 옆모습은 왼쪽(−x)을 본다(오른쪽은 엔진이 뒤집는다).
// pen: { g: CanvasRenderingContext2D, X(x), Y(y) } — 단위 → 캔버스 px.

const { sin, cos, PI, abs, max, min, atan2, hypot, sqrt } = Math;
export const INK = '#1f1a17';
const HOOF = '#2a221c';

export function shade(hex, k) {
  const n = parseInt(hex.slice(1), 16); let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  const t = k < 0 ? [30, 24, 18] : [246, 239, 223], a = abs(k);
  r += (t[0] - r) * a; g += (t[1] - g) * a; b += (t[2] - b) * a;
  return '#' + ((1 << 24) | ((r | 0) << 16) | ((g | 0) << 8) | (b | 0)).toString(16).slice(1);
}
const lerp = (a, b, t) => a + (b - a) * t;
const add = (p, q) => [p[0] + q[0], p[1] + q[1]];
const mul = (p, k) => [p[0] * k, p[1] * k];
const smooth = (t) => t * t * (3 - 2 * t);

// ---------------------------------------------------------------- 붓
function pxk(pen) { return pen.X(1) - pen.X(0); }
// 점들을 지나는 매끈한 닫힌(또는 열린) 곡선(가운데점 2차 곡선)
function curve(pen, pts, closed = true) {
  const g = pen.g, P = pts.map(([x, y]) => [pen.X(x), pen.Y(y)]), n = P.length;
  g.beginPath();
  if (!closed) {
    g.moveTo(P[0][0], P[0][1]);
    for (let i = 1; i < n - 1; i++) g.quadraticCurveTo(P[i][0], P[i][1], (P[i][0] + P[i + 1][0]) / 2, (P[i][1] + P[i + 1][1]) / 2);
    g.lineTo(P[n - 1][0], P[n - 1][1]);
    return;
  }
  const m = (i) => [(P[i % n][0] + P[(i + 1) % n][0]) / 2, (P[i % n][1] + P[(i + 1) % n][1]) / 2];
  const s = m(n - 1); g.moveTo(s[0], s[1]);
  for (let i = 0; i < n; i++) { const q = m(i); g.quadraticCurveTo(P[i][0], P[i][1], q[0], q[1]); }
  g.closePath();
}
// 담채 칠: 위 밝게 → 아래 어둡게(배·턱 밑 그늘)
function wash(pen, pts, col, dark = 0.3, light = 0.1) {
  const g = pen.g;
  let y0 = 1e9, y1 = -1e9; for (const p of pts) { y0 = min(y0, pen.Y(p[1])); y1 = max(y1, pen.Y(p[1])); }
  const gr = g.createLinearGradient(0, y0, 0, y1 + 0.01);
  gr.addColorStop(0, shade(col, light)); gr.addColorStop(0.5, col); gr.addColorStop(1, shade(col, -dark));
  curve(pen, pts, true); g.fillStyle = gr; g.fill();
}
function ink(pen, pts, w, closed = true, col = INK) {
  const g = pen.g; curve(pen, pts, closed);
  g.lineWidth = w; g.strokeStyle = col; g.lineJoin = 'round'; g.lineCap = 'round'; g.stroke();
}
// 붓 선: 가운데 굵고 끝이 가는 선(근육 결·주름)
function stroke(pen, pts, w, col = INK, alpha = 1) {
  const g = pen.g; g.save(); g.globalAlpha = alpha;
  const n = pts.length;
  for (let i = 0; i < n - 1; i++) {
    const t = (i + 0.5) / (n - 1), ww = w * (0.35 + 0.8 * sin(PI * t));
    g.beginPath(); g.moveTo(pen.X(pts[i][0]), pen.Y(pts[i][1])); g.lineTo(pen.X(pts[i + 1][0]), pen.Y(pts[i + 1][1]));
    g.lineWidth = ww; g.strokeStyle = col; g.lineCap = 'round'; g.stroke();
  }
  g.restore();
}
function fillPoly(pen, pts, col) { curve(pen, pts, true); pen.g.fillStyle = col; pen.g.fill(); }
function dot(pen, x, y, r, col = INK) { const g = pen.g; g.beginPath(); g.arc(pen.X(x), pen.Y(y), r, 0, 2 * PI); g.fillStyle = col; g.fill(); }
// 2차 베지어 위 점들
function bez(a, c, b, n = 8) { const o = []; for (let i = 0; i <= n; i++) { const t = i / n, u = 1 - t; o.push([u * u * a[0] + 2 * u * t * c[0] + t * t * b[0], u * u * a[1] + 2 * u * t * c[1] + t * t * b[1]]); } return o; }

// ---------------------------------------------------------------- 걸음새
// 다리 하나의 (흔들기 a, 굽힘 f): 디딤 동안 앞(+)에서 뒤(−)로 곧게, 뜰 때 굽혀 앞으로
function limb(p, duty, A, F) {
  p = ((p % 1) + 1) % 1;
  if (p < duty) { const t = p / duty; return { a: lerp(A, -A, t), f: 0, stance: true }; }
  const t = (p - duty) / (1 - duty);
  return { a: lerp(-A, A, smooth(t)), f: F * sin(PI * t) ** 0.8, stance: false };
}
// anim: idle · walk · trot · eat · graze · (idle 변형) look · rest — f/n 장
// 반환: 몸·머리·다리·꼬리·귀 자세
export function horsePose(anim, f, n, o = {}) {
  const u = n > 0 ? f / n : 0, ph = u * 2 * PI;
  // o.stall: 칸 말 — 서 있을 때도 고개를 처마 아래로 낮게(앞모습에서 머리가 처마에 가려 목만 보이지 않게)
  const P = { bob: 0, rock: 0, head: 'up', hp: 0, chew: 0, tail: 0, tailLift: 0, ear: 0, legs: {}, rest: false, turn: o.turn || 0, sway: 0, low: !!o.stall };
  const still = (k) => ({ a: 0, f: 0, stance: true });
  for (const k of ['LF', 'RF', 'LH', 'RH']) P.legs[k] = still(k);
  if (anim === 'walk' || anim === 'trot' || anim === 'run') {
    const trot = anim !== 'walk';
    const duty = trot ? 0.46 : 0.62, A = trot ? 0.36 : 0.27, Ff = trot ? 1.0 : 0.75, Fh = trot ? 0.9 : 0.65;
    const off = trot ? { LH: 0, RF: 0.0, RH: 0.5, LF: 0.5 } : { LH: 0, LF: 0.25, RH: 0.5, RF: 0.75 };
    for (const k in off) P.legs[k] = limb(u + off[k] + (k.endsWith('F') && trot ? 0.04 : 0), duty, A * (k.endsWith('H') ? 0.92 : 1), k.endsWith('F') ? Ff : Fh);
    // 머리 끄덕임: 걸음은 앞발 디딜 때마다 내려감(한 바퀴에 둘), 속보는 작게
    P.hp = trot ? 0.03 * sin(ph * 2 + 0.6) : 0.07 * sin(ph * 2 + 1.2);
    P.bob = trot ? 0.045 * cos(ph * 2) : 0.012 * cos(ph * 2);
    P.rock = trot ? 0.0 : 0.015 * sin(ph * 2);
    P.tail = (trot ? 0.12 : 0.08) * sin(ph);
    P.tailLift = trot ? 0.25 : 0.05;
    P.sway = (trot ? 0.02 : 0.03) * sin(ph);
    P.ear = 0.15 * sin(ph);
  } else if (anim === 'eat' || anim === 'graze') {
    P.head = anim;
    P.chew = sin(ph * 2);
    P.hp = 0.02 * sin(ph * 2);
    P.tail = [0.05, 0.3, -0.2, 0.0][f % 4] * (f % 2 === 1 ? 1 : 0.5);
    P.ear = f === 2 ? 0.6 : 0;
    if (anim === 'graze' && f === n - 1) P.legs.LF = { a: 0.12, f: 0.12, stance: true };   // 앞발을 한 걸음 옮김
  } else {
    // idle: 꼬리 휘두름 · 귀 돌림 · 머리 들어 둘러봄 · 뒷발 하나 쉬기(굽 끝만 땅에)
    P.tail = [0.0, 0.42, -0.3, 0.08][f % 4];
    P.ear = [0, 0.7, 0.3, -0.4][f % 4];
    P.hp = [0, 0.02, 0.07, 0.04][f % 4];
    P.head = f === 2 ? 'look' : 'up';
    P.rest = f >= 2;
    if (P.rest) P.legs.RH = { a: -0.05, f: 0.35, stance: true, rest: true };
    P.bob = -0.004 * sin(ph);
  }
  return P;
}

// ---------------------------------------------------------------- 옆모습
// 기본 윤곽점(기갑 높이 1.47). 다리 붙는 자리·길이
const SIDE = {
  withers: [-0.48, 1.47], back: [[-0.28, 1.405], [0.0, 1.38], [0.26, 1.395]], croup: [[0.5, 1.445], [0.68, 1.43]], tailhead: [0.8, 1.37],
  buttock: [0.885, 1.23], thigh: [[0.87, 1.06], [0.79, 0.92]], stifle: [[0.6, 0.86], [0.5, 0.9]], flank: [0.38, 0.94],
  belly: [[0.2, 0.83], [-0.08, 0.79]], girth: [-0.34, 0.8], elbow: [-0.52, 0.84], chest: [[-0.7, 0.9], [-0.81, 1.0]], shoulderPt: [-0.85, 1.13],
  fore: { top: [-0.6, 1.0], L: [0.42, 0.29, 0.13, 0.08] },
  hind: { top: [0.68, 1.04], L: [0.42, 0.38, 0.13, 0.08] },
};
// 다리 사슬 → [관절점], 굵기
function legChain(top, kind, a, fl, s, rest) {
  const D = (t) => [-sin(t), -cos(t)];   // t+: 앞(왼쪽)으로
  const L = (kind === 'fore' ? SIDE.fore.L : SIDE.hind.L).map((v) => v * s);
  let pts = [top];
  if (kind === 'fore') {
    const t1 = a + 0.04 + fl * 0.35, t2 = a - fl * 1.75, t3 = t2 + 0.62 - fl * 0.9;
    const knee = add(top, mul(D(t1), L[0])), fet = add(knee, mul(D(t2), L[1])), cor = add(fet, mul(D(t3), L[2])), toe = add(cor, mul(D(t3 + 0.25), L[3]));
    pts = [top, knee, fet, cor, toe];
  } else {
    const t1 = a - 0.55 - fl * 0.25 - (rest ? 0.1 : 0), t2 = a + 0.1 + fl * 1.15 + (rest ? 0.35 : 0), t3 = t2 + 0.6 - fl * 0.7 - (rest ? 0.9 : 0);
    const hock = add(top, mul(D(t1), L[0])), fet = add(hock, mul(D(t2), L[1])), cor = add(fet, mul(D(t3), L[2])), toe = add(cor, mul(D(t3 + (rest ? -0.6 : 0.25)), L[3]));
    pts = [top, hock, fet, cor, toe];
  }
  return pts;
}
// 사슬을 굵기 윤곽으로(앞쪽 변 · 뒤쪽 변). W: 관절마다 반폭
function legOutline(pts, W, bumps) {
  const left = [], right = [];
  const N = pts.length;
  for (let i = 0; i < N; i++) {
    const a = pts[max(0, i - 1)], b = pts[min(N - 1, i + 1)];
    let dx = b[0] - a[0], dy = b[1] - a[1]; const l = hypot(dx, dy) || 1; dx /= l; dy /= l;
    const nx = -dy, ny = dx;   // 왼쪽 법선
    const w = W[i], bf = bumps ? bumps[i] || [0, 0] : [0, 0];
    left.push([pts[i][0] + nx * (w + bf[0]), pts[i][1] + ny * (w + bf[0])]);
    right.push([pts[i][0] - nx * (w + bf[1]), pts[i][1] - ny * (w + bf[1])]);
    // 관절 사이 가운데 점(살 곡선)
    if (i < N - 1) {
      const m = [(pts[i][0] + pts[i + 1][0]) / 2, (pts[i][1] + pts[i + 1][1]) / 2];
      let ex = pts[i + 1][0] - pts[i][0], ey = pts[i + 1][1] - pts[i][1]; const el = hypot(ex, ey) || 1; ex /= el; ey /= el;
      const mw = (W[i] + W[i + 1]) / 2 * (i === 0 ? 1.0 : 0.88);
      left.push([m[0] - ey * mw, m[1] + ex * mw]); right.push([m[0] + ey * mw, m[1] - ex * mw]);
    }
  }
  return { left, right };
}
function drawLeg(pen, top, kind, st, col, s, w0, wpx, far) {
  const pts = legChain(top, kind, st.a, st.f, s, st.rest);
  const k = s * w0;
  // 반폭: 위(근육) → 무릎/비절 → 정강이 → 구절 → 발목 → 굽
  const W = kind === 'fore' ? [0.125, 0.066, 0.052, 0.043, 0.056].map((v) => v * k) : [0.13, 0.064, 0.05, 0.043, 0.056].map((v) => v * k);
  // 앞쪽(+) 변 볼록: 앞팔 근육 · 무릎 · 구절 / 뒤: 비절 끝(뒤로 뾰족)
  const bumps = kind === 'fore' ? [[0.02 * k, 0], [0.008 * k, 0.006 * k], [0, 0.012 * k], [0, 0], [0, 0]] : [[0, 0.01 * k], [0, 0.03 * k], [0, 0.012 * k], [0, 0], [0, 0]];
  const { left, right } = legOutline(pts.slice(0, 4), W.slice(0, 4), bumps);
  const body = [...left, ...right.reverse()];
  wash(pen, body, col, 0.18, 0.04);
  // 먹: 위 끝(몸에 묻힌 쪽)은 긋지 않는다 — 두 옆 변만
  ink(pen, left.slice(1), wpx, false); ink(pen, right.slice(0, -1), wpx, false);
  // 굽
  const cor = pts[3], toe = pts[4];
  let dx = toe[0] - cor[0], dy = toe[1] - cor[1]; const l = hypot(dx, dy) || 1; dx /= l; dy /= l;
  const nx = -dy, ny = dx, hw = 0.05 * k, hb = 0.062 * k;
  const hoof = [[cor[0] + nx * hw, cor[1] + ny * hw], [toe[0] + nx * hb + dx * 0.01, toe[1] + ny * hb + dy * 0.01], [toe[0] - nx * hb * 0.8, toe[1] - ny * hb * 0.8], [cor[0] - nx * hw, cor[1] - ny * hw]];
  pen.g.beginPath(); hoof.forEach((p, i) => { const X = pen.X(p[0]), Y = pen.Y(p[1]); if (i) pen.g.lineTo(X, Y); else pen.g.moveTo(X, Y); }); pen.g.closePath();
  pen.g.fillStyle = far ? shade(HOOF, -0.1) : HOOF; pen.g.fill(); pen.g.lineWidth = wpx * 0.8; pen.g.strokeStyle = INK; pen.g.stroke();
  // 구절 뒤 털·무릎 앞 주름
  stroke(pen, [add(pts[1], [0.01 * k, 0]), add(pts[1], [0.035 * k, -0.02 * k])], wpx * 0.7, shade(col, -0.45), 0.8);
  return pts;
}
function toeY(top, kind, st, s) { const p = legChain(top, kind, st.a, st.f, s, st.rest); return min(p[4][1], p[3][1] - 0.05 * s); }

// 머리(옆): 머리 축 각 phi(아래로 +), 정수리 P. 머리뼈 한 덩이 + 귀 + 눈 + 콧구멍
function headSide(P, phi, s) {
  const u = [-cos(phi), -sin(phi)], v = [-sin(phi), cos(phi)];
  const L = (a, b) => [P[0] + (u[0] * a + v[0] * b) * s, P[1] + (u[1] * a + v[1] * b) * s];
  return {
    L,
    shape: [L(0.0, 0.02), L(0.1, 0.05), L(0.28, 0.03), L(0.44, -0.01), L(0.55, -0.04), L(0.615, -0.1), L(0.6, -0.165), L(0.55, -0.2), L(0.47, -0.2),
      L(0.36, -0.185), L(0.24, -0.25), L(0.1, -0.25), L(0.02, -0.18), L(-0.02, -0.08)],
    throat: L(0.02, -0.17), jawBack: L(0.06, -0.23),
  };
}

export function drawSide(pen, C, P, T = {}) {
  const k = pxk(pen), s = C.pony ? 0.86 : 1.0, legS = C.pony ? 0.82 : 1.0, w0 = C.pony ? 1.22 : 1.0;
  const col = C.coat, far = shade(col, -0.3), mane = C.mane;
  const wpx = max(1.4, k * 0.016);
  // 다리 붙는 자리(몸 기준) — 몸 높이는 디딘 굽이 땅에 닿게 맞춘다
  const tops = { LF: SIDE.fore.top, RF: [SIDE.fore.top[0] + 0.03, SIDE.fore.top[1]], LH: SIDE.hind.top, RH: [SIDE.hind.top[0] - 0.03, SIDE.hind.top[1]] };
  const legLen = (x) => x;
  // 몸 좌표 변환: 조랑말은 다리가 짧다 → 몸을 내린다. rock: 앞이 들림
  const drop = (1 - legS) * 0.95;
  let lowest = 1e9;
  for (const key in P.legs) { const st = P.legs[key]; if (!st.stance || st.rest) continue; lowest = min(lowest, toeY([tops[key][0], tops[key][1] - drop], key.endsWith('F') ? 'fore' : 'hind', st, legS)); }
  const by = (lowest < 1e8 ? -lowest + 0.01 : 0) + P.bob * 0.3;
  const B = (p) => [p[0] * (C.pony ? 0.94 : 1), p[1] - drop + by + P.rock * (-p[0])];
  // 먼 쪽 다리(왼쪽이 화면 쪽 — 오른쪽 다리가 멀다)
  drawLeg(pen, B(tops.RH), 'hind', P.legs.RH, far, legS, w0, wpx, true);
  drawLeg(pen, B(tops.RF), 'fore', P.legs.RF, far, legS, w0, wpx, true);
  // 가까운 쪽 다리도 몸보다 먼저 — 위 끝(앞팔·넓적다리 근육)이 몸 윤곽 안으로 묻혀 이음매가 안 보이게
  drawLeg(pen, B(tops.LH), 'hind', P.legs.LH, shade(col, -0.04), legS, w0, wpx, false);
  drawLeg(pen, B(tops.LF), 'fore', P.legs.LF, shade(col, 0.02), legS, w0, wpx, false);
  // 머리 자리
  const W = B(SIDE.withers), SP = B(SIDE.shoulderPt);
  let poll, phi;
  if (P.head === 'eat') { poll = [-1.14, 0.98 + 0.02 * P.chew]; phi = 1.3; }
  else if (P.head === 'graze') { poll = [-1.06, 0.55 + 0.015 * P.chew]; phi = 1.5; }
  else if (P.head === 'look') { poll = [-1.1, 1.98]; phi = 0.72; }
  else { poll = [-1.2, 1.9 + P.hp]; phi = 0.88 + P.hp * 1.2; }
  if (T.rideHead) { poll = [-1.16, 1.8 + P.hp]; phi = 0.95 + P.hp; }
  poll = [poll[0] * (C.pony ? 0.9 : 1), poll[1] - drop * (P.head === 'graze' ? 0.4 : 0.9) + by * 0.5];
  if (C.pony) poll[1] -= 0.05;
  const H = headSide(poll, phi, s * (C.pony ? 1.22 : 1.16));
  // 꼬리(몸 뒤로 늘어진 숱 — 흔들림)
  const th = B(SIDE.tailhead), tw = P.tail, tl = P.tailLift;
  const tailPts = [add(th, [-0.03, 0.03]), add(th, [0.12 + tl * 0.25, -0.02 + tl * 0.06]), [th[0] + 0.2 + tw * 0.25 + tl * 0.3, th[1] - 0.32 + tl * 0.1],
    [th[0] + 0.2 + tw * 0.6 + tl * 0.35, th[1] - 0.7 + tl * 0.25], [th[0] + 0.12 + tw * 0.7 + tl * 0.3, th[1] - 0.82 + tl * 0.3],
    [th[0] + 0.06 + tw * 0.55 + tl * 0.2, th[1] - 0.66 + tl * 0.25], [th[0] + 0.07 + tw * 0.2, th[1] - 0.3], add(th, [0.0, -0.1])];
  wash(pen, tailPts, mane, 0.25, 0.05); ink(pen, tailPts, wpx);
  stroke(pen, [tailPts[2], tailPts[4]], wpx * 0.7, shade(mane, 0.25), 0.6);
  // 몸 + 목: 한 윤곽
  const crestC = [lerp(W[0], poll[0], 0.55) + 0.06, max(W[1], poll[1]) + 0.13 - (P.head === 'graze' ? 0.05 : 0)];
  const crest = bez(W, crestC, add(poll, [0.04, 0.01]), 7).reverse();   // 정수리 → 기갑(아래에서 거꾸로 쓴다)
  const thr = H.throat;
  const undC = [lerp(SP[0], thr[0], 0.5) - 0.06, lerp(SP[1], thr[1], 0.5) - 0.07];
  const under = bez(SP, undC, thr, 7);
  const body = [W, ...SIDE.back.map(B), ...SIDE.croup.map(B), B(SIDE.tailhead), B(SIDE.buttock), ...SIDE.thigh.map(B), ...SIDE.stifle.map(B), B(SIDE.flank),
    ...SIDE.belly.map(B), B(SIDE.girth), B(SIDE.elbow), ...SIDE.chest.map(B), ...under, ...crest.slice(0, -1)];
  // 칠 + 갈기 + 먹
  wash(pen, body, col, 0.3, 0.12);
  // 등 볕(밝은 붓)·배 그늘
  stroke(pen, [B([-0.3, 1.36]), B([0.1, 1.34]), B([0.5, 1.39])], k * 0.06, shade(col, 0.22), 0.45);
  ink(pen, body, wpx * 1.05);
  // 근육 결: 어깨선 · 팔꿈치 · 넓적다리(엉덩이 끝 → 무릎 주름) · 갈비 한두 줄
  stroke(pen, [add(W, [0.0, -0.04]), B([-0.6, 1.22]), B([-0.7, 1.06])], wpx * 0.9, shade(col, -0.45), 0.85);
  stroke(pen, [B([0.5, 1.32]), B([0.62, 1.12]), B([0.6, 0.95])], wpx * 0.9, shade(col, -0.45), 0.85);
  stroke(pen, [B([-0.18, 1.12]), B([-0.1, 0.98])], wpx * 0.6, shade(col, -0.35), 0.5);
  stroke(pen, [B([0.36, 1.33]), B([0.42, 1.36])], wpx * 0.8, shade(col, -0.4), 0.7);   // 엉덩이뼈
  if (C.dapple) for (const [x, y] of [[0.2, 1.2], [0.45, 1.16], [0.0, 1.08], [0.66, 1.26], [-0.2, 1.2], [0.3, 1.0], [0.55, 1.03]]) { const q = B([x, y]); dot(pen, q[0], q[1], k * 0.022, shade(col, -0.16)); }
  // 갈기: 목 윗선 따라 숱(아래 가장자리 들쭉날쭉)
  const crestTop = bez(add(W, [0.02, 0.02]), add(crestC, [0, 0.03]), add(poll, [0.05, 0.03]), 9);
  const manePts = [...crestTop];
  const mw = C.pony ? 0.11 : 0.075;
  for (let i = crestTop.length - 1; i >= 0; i--) {
    const t = i / (crestTop.length - 1), q = crestTop[i];
    const dir = i > 0 ? [q[0] - crestTop[i - 1][0], q[1] - crestTop[i - 1][1]] : [crestTop[1][0] - q[0], crestTop[1][1] - q[1]];
    const l = hypot(dir[0], dir[1]) || 1; const nrm = [dir[1] / l, -dir[0] / l];   // 아래쪽(목 안쪽)
    const jag = (i % 2 ? 1.0 : 0.6) * mw * (0.6 + 0.6 * sin(PI * t));
    manePts.push([q[0] + nrm[0] * jag, q[1] + nrm[1] * jag]);
  }
  wash(pen, manePts, mane, 0.2, 0.06); ink(pen, manePts, wpx * 0.8);
  // 가까운 쪽 다리(위 끝은 몸에 묻힘)
  // 넓적다리 앞 둥근 결(가까운 뒷다리를 몸에 잇는다) · 팔꿈치 주름
  stroke(pen, [B([0.55, 1.05]), B([0.62, 0.92]), B([0.7, 0.86])], wpx * 0.8, shade(col, -0.4), 0.8);
  stroke(pen, [B([-0.5, 0.95]), B([-0.46, 0.86])], wpx * 0.7, shade(col, -0.4), 0.7);
  if (C.socks) for (const key of ['LF', 'LH']) { /* 흰 발목은 다리 색으로 충분 — 자리만 */ }
  // 머리: 한 덩이 + 볼 근육 + 귀 + 눈 + 콧구멍 + 입
  wash(pen, H.shape, shade(col, 0.04), 0.22, 0.12);
  ink(pen, H.shape, wpx);
  const cheek = [H.L(0.08, -0.12), H.L(0.18, -0.08), H.L(0.28, -0.16), H.L(0.2, -0.235)];
  stroke(pen, cheek, wpx * 0.8, shade(col, -0.4), 0.8);
  // 귀 둘(먼 귀 먼저) — ear: 돌림(+ 뒤로 젖힘)
  for (const [off, c2] of [[0.03, far], [-0.02, col]]) {
    const ea = P.ear * (off > 0 ? 0.6 : 1);
    const b0 = H.L(0.02 + off, 0.03), tip = H.L(-0.06 - ea * 0.06 + off, 0.15 - ea * 0.04), b1 = H.L(0.09 + off, 0.04);
    const ear = [b0, add(lerp2(b0, tip, 0.6), [-0.01, 0.0]), tip, add(lerp2(b1, tip, 0.6), [0.01, 0.0]), b1];
    wash(pen, ear, c2, 0.1, 0.05); ink(pen, ear, wpx * 0.85);
  }
  // 앞머리 털(조랑말은 덥수룩)
  const fl = [H.L(0.0, 0.03), H.L(0.12, 0.02), H.L(C.pony ? 0.24 : 0.17, -0.05), H.L(0.1, -0.02)];
  wash(pen, fl, mane, 0.1, 0.05); ink(pen, fl, wpx * 0.6);
  if (C.blaze) fillPoly(pen, [H.L(0.15, 0.025), H.L(0.45, -0.005), H.L(0.5, -0.04), H.L(0.2, -0.0)], '#efe7d6');
  const eyeOpen = !(P.head === 'eat' || P.head === 'graze') || P.chew < 0.6;
  const e = H.L(0.15, -0.045);
  if (eyeOpen) { dot(pen, e[0], e[1], k * 0.018); dot(pen, e[0] - 0.004, e[1] + 0.004, k * 0.006, '#e9e2d0'); }
  else stroke(pen, [H.L(0.13, -0.04), H.L(0.17, -0.05)], wpx * 0.8);
  stroke(pen, [H.L(0.12, -0.02), H.L(0.17, -0.015)], wpx * 0.6, INK, 0.7);   // 눈두덩
  const ns = H.L(0.56, -0.1); dot(pen, ns[0], ns[1], k * 0.014, shade(col, -0.6));
  stroke(pen, [H.L(0.6, -0.16), H.L(0.53, -0.17)], wpx * 0.7);   // 입술 선
  // 굴레(머리띠 · 코띠 · 볼띠) + 고삐
  if (T.halter !== false) {
    const hc = T.halterCol || '#5a3020';
    stroke(pen, [H.L(0.02, 0.0), H.L(0.06, -0.12), H.L(0.12, -0.24)], wpx * 1.1, hc);
    stroke(pen, [H.L(0.44, 0.0), H.L(0.44, -0.1), H.L(0.42, -0.2)], wpx * 1.1, hc);
    stroke(pen, [H.L(0.06, -0.12), H.L(0.44, -0.1)], wpx * 1.0, hc);
    if (T.reins) stroke(pen, [H.L(0.47, -0.17), ...T.reins.map(B)], wpx * 0.9, hc);
    else if (P.head === 'up' || P.head === 'look') stroke(pen, [H.L(0.43, -0.19), add(H.L(0.43, -0.19), [0.04, -0.25]), add(H.L(0.43, -0.19), [-0.02, -0.5])], wpx * 0.8, hc);
  }
  if (T.saddle) T.saddle(pen, B, wpx);
  return { B, poll };
}
const lerp2 = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t)];

// ---------------------------------------------------------------- 앞모습(카메라를 봄)
// turn: −1~1 몸이 돌아(+는 머리가 화면 오른쪽, 왼 옆구리가 보임)
function legFront(pen, x, top, len, w, col, st, wpx, hoofW) {
  // 앞에서 본 다리: 무릎이 앞으로 굽으면 정강이가 짧아 보이고 굽이 들린다
  const fl = st.f, lift = fl * 0.22 + (st.stance ? 0 : 0.02);
  const knee = [x + fl * 0.01, top - len * 0.45 + fl * 0.03];
  const fet = [x, knee[1] - len * 0.42 * (1 - fl * 0.55)];
  const hoof = [x, max(0.0, fet[1] - len * 0.12) + lift * 0.2];
  const W = [w, w * 0.62, w * 0.5, w * 0.58];
  const pts = [[x, top], knee, fet, hoof];
  const L = [], R = [];
  pts.forEach((p, i) => { L.push([p[0] - W[i], p[1]]); R.push([p[0] + W[i], p[1]]); if (i < 3) { const m = lerp2(p, pts[i + 1], 0.5), mw = (W[i] + W[i + 1]) / 2 * 0.86; L.push([m[0] - mw, m[1]]); R.push([m[0] + mw, m[1]]); } });
  const sh = [...L, ...R.reverse()];
  wash(pen, sh, col, 0.15, 0.04); ink(pen, L, wpx, false); ink(pen, R.reverse(), wpx, false);
  // 무릎 둥근 결 · 굽
  stroke(pen, [[knee[0] - W[1] * 0.6, knee[1] + 0.005], [knee[0] + W[1] * 0.6, knee[1] + 0.005]], wpx * 0.6, shade(col, -0.4), 0.7);
  const hb = hoofW;
  const hp = [[hoof[0] - hb * 0.8, hoof[1] + 0.07], [hoof[0] + hb * 0.8, hoof[1] + 0.07], [hoof[0] + hb, hoof[1]], [hoof[0] - hb, hoof[1]]];
  pen.g.beginPath(); hp.forEach((p, i) => { const X = pen.X(p[0]), Y = pen.Y(p[1]); if (i) pen.g.lineTo(X, Y); else pen.g.moveTo(X, Y); }); pen.g.closePath();
  pen.g.fillStyle = HOOF; pen.g.fill(); pen.g.lineWidth = wpx * 0.8; pen.g.strokeStyle = INK; pen.g.stroke();
}
export function drawFront(pen, C, P, T = {}) {
  const k = pxk(pen), wpx = max(1.4, k * 0.016);
  const col = C.coat, far = shade(col, -0.3), mane = C.mane;
  const ls = C.pony ? 0.82 : 1.0, wd = C.pony ? 1.12 : 1.0;
  const tr = P.turn || 0, sw = P.sway || 0;
  const by = P.bob * 0.6 - (1 - ls) * 0.9;
  const Y = (y) => y + by;
  const X = (x, depth = 0) => x + tr * depth * 0.5 + sw * (1 - depth);   // depth: 0 앞(가슴) → 1 뒤(엉덩이)
  // 뒷다리(멀리, 몸통 아래 사이로)
  const rL = P.legs.LH, rR = P.legs.RH;
  legFront(pen, X(-0.13 * wd, 1), Y(0.95), 0.93 - (1 - ls) * 0.9, 0.062 * wd, far, rL, wpx, 0.05 * wd);
  legFront(pen, X(0.13 * wd, 1), Y(0.95), 0.93 - (1 - ls) * 0.9, 0.062 * wd, far, rR, wpx, 0.05 * wd);
  // 몸통: 가슴 뒤로 보이는 통(돌면 한 옆구리가 길게) + 엉덩이 꼭대기
  const bw = 0.3 * wd, bxs = tr * 0.2;
  const barrel = [[X(-bw, 0.3) + min(0, bxs), Y(1.18)], [X(-bw * 0.85, 0.6) + min(0, bxs), Y(1.4)], [X(0, 0.7), Y(1.44)], [X(bw * 0.85, 0.6) + max(0, bxs), Y(1.4)],
    [X(bw, 0.3) + max(0, bxs), Y(1.18)], [X(bw * 0.8, 0.3) + max(0, bxs) * 0.8, Y(0.9)], [X(0, 0.3), Y(0.84)], [X(-bw * 0.8, 0.3) + min(0, bxs) * 0.8, Y(0.9)]];
  wash(pen, barrel, shade(col, -0.06), 0.35, 0.1); ink(pen, barrel, wpx);
  if (abs(tr) > 0.1) stroke(pen, [[X(0, 0.8) + bxs * 0.6, Y(1.42)], [X(0, 0.8) + bxs * 1.1, Y(1.2)]], wpx * 0.8, shade(col, -0.4), 0.7);   // 엉덩이 쪽 결
  if (T.saddleFront) T.saddleFront(pen, X, Y, wpx, bw);
  // 앞다리
  legFront(pen, X(-0.15 * wd), Y(1.0), 0.98 - (1 - ls) * 0.9, 0.082 * wd, shade(col, -0.02), P.legs.RF, wpx, 0.06 * wd);
  legFront(pen, X(0.15 * wd), Y(1.0), 0.98 - (1 - ls) * 0.9, 0.082 * wd, shade(col, 0.02), P.legs.LF, wpx, 0.06 * wd);
  // 가슴·어깨(앞팔 근육 위 둥근 두 덩이 사이 홈)
  const ch = [[X(-0.3 * wd), Y(1.38)], [X(-0.33 * wd), Y(1.1)], [X(-0.22 * wd), Y(0.9)], [X(0, 0), Y(0.97)], [X(0.22 * wd), Y(0.9)], [X(0.33 * wd), Y(1.1)], [X(0.3 * wd), Y(1.38)], [X(0), Y(1.46)]];
  wash(pen, ch, col, 0.28, 0.12); ink(pen, ch, wpx);
  stroke(pen, [[X(0), Y(1.2)], [X(0), Y(0.98)]], wpx * 0.8, shade(col, -0.45), 0.8);
  stroke(pen, [[X(-0.18 * wd), Y(1.12)], [X(-0.13 * wd), Y(0.95)]], wpx * 0.6, shade(col, -0.4), 0.6);
  stroke(pen, [[X(0.18 * wd), Y(1.12)], [X(0.13 * wd), Y(0.95)]], wpx * 0.6, shade(col, -0.4), 0.6);
  // 목 + 머리: 고개 숙임(eat: 머리가 가슴 앞 아래, 얼굴이 짧아 보임) / 듦
  const hx = X(tr * 0.16 + sw * 0.5, 0);
  let top, len, chin;
  if (P.head === 'eat') { top = Y(1.12 + 0.02 * P.chew); len = 0.38; chin = top - len; }
  else if (P.head === 'graze') { top = Y(0.62); len = 0.3; chin = top - len; }
  else if (P.low) { top = Y(1.55 + P.hp * 0.8); len = 0.44; chin = top - len; }
  else { top = Y(2.0 + P.hp * 0.8 - (P.head === 'look' ? -0.04 : 0)); len = 0.5; chin = top - len; }
  if (C.pony) { top -= 0.06; chin -= 0.04; }
  const nb = P.head === 'eat' || P.head === 'graze';
  const neck = nb
    ? [[X(-0.17 * wd), Y(1.47)], [X(-0.15 * wd), Y(1.3)], [hx - 0.12, top + 0.02], [hx + 0.12, top + 0.02], [X(0.15 * wd), Y(1.3)], [X(0.17 * wd), Y(1.47)], [X(0), Y(1.5)]]
    : [[X(-0.2 * wd), Y(1.3)], [hx - 0.1, top - 0.24], [hx - 0.08, top - 0.05], [hx + 0.08, top - 0.05], [hx + 0.1, top - 0.24], [X(0.2 * wd), Y(1.3)]];
  wash(pen, neck, shade(col, nb ? 0.06 : 0.0), 0.2, 0.12); ink(pen, neck, wpx);
  if (nb) { // 숙인 목 윗면의 갈기
    const mn = [[X(0) - 0.04, Y(1.5)], [hx - 0.03, top + 0.06], [hx + 0.03, top + 0.06], [X(0) + 0.04, Y(1.5)]];
    wash(pen, mn, mane, 0.1, 0.05); ink(pen, mn, wpx * 0.7);
  }
  // 얼굴: 이마 넓고 콧등으로 좁아짐, 볼 · 주둥이
  const fw = (C.pony ? 0.15 : 0.13);
  const face = [[hx - fw, top], [hx - fw * 1.05, top - len * 0.3], [hx - fw * 0.62, top - len * 0.72], [hx - fw * 0.7, chin + 0.03], [hx, chin - 0.01],
    [hx + fw * 0.7, chin + 0.03], [hx + fw * 0.62, top - len * 0.72], [hx + fw * 1.05, top - len * 0.3], [hx + fw, top], [hx, top + 0.03]];
  // 귀(얼굴 뒤 — 먼저)
  for (const sgn of [-1, 1]) {
    const ea = P.ear * (sgn > 0 ? 1 : 0.5);
    const b0 = [hx + sgn * fw * 0.55, top + 0.01], b1 = [hx + sgn * fw * 1.05, top - 0.02], tip = [hx + sgn * (fw * 1.0 + ea * 0.06), top + 0.16 - ea * 0.04];
    const ear = [b0, lerp2(b0, tip, 0.6), tip, lerp2(b1, tip, 0.6), b1];
    if (nb) { // 숙이면 귀가 앞(카메라 쪽)으로 짧게
      ear[2] = [hx + sgn * fw * 1.2, top + 0.07]; }
    wash(pen, ear, sgn > 0 ? col : shade(col, -0.1), 0.1, 0.05); ink(pen, ear, wpx * 0.85);
  }
  wash(pen, face, shade(col, 0.05), 0.2, 0.12); ink(pen, face, wpx);
  if (C.blaze || !C.pony) fillPoly(pen, [[hx - 0.022, top - 0.06], [hx + 0.022, top - 0.06], [hx + 0.016, top - len * 0.8], [hx - 0.016, top - len * 0.8]], '#ece4d2');
  // 앞머리 털
  const fk = [[hx - 0.05, top + 0.02], [hx + 0.05, top + 0.02], [hx + 0.03, top - (C.pony ? 0.13 : 0.08)], [hx - 0.035, top - (C.pony ? 0.12 : 0.07)]];
  wash(pen, fk, mane, 0.1, 0.05); ink(pen, fk, wpx * 0.6);
  // 눈(얼굴 양옆 위) · 콧구멍
  const eyeOpen = !nb || P.chew < 0.6;
  for (const sgn of [-1, 1]) {
    const ex = hx + sgn * fw * 0.92, ey = top - len * 0.26;
    if (eyeOpen) dot(pen, ex, ey, k * 0.016); else stroke(pen, [[ex - 0.015, ey], [ex + 0.015, ey]], wpx * 0.8);
    dot(pen, hx + sgn * fw * 0.36, chin + 0.06, k * 0.012, shade(col, -0.6));
  }
  stroke(pen, [[hx - fw * 0.45, chin + 0.025], [hx + fw * 0.45, chin + 0.025]], wpx * 0.6, INK, 0.7);
  // 굴레
  if (T.halter !== false) {
    const hc = T.halterCol || '#5a3020';
    stroke(pen, [[hx - fw * 0.66, top - len * 0.7], [hx + fw * 0.66, top - len * 0.7]], wpx * 1.1, hc);
    stroke(pen, [[hx - fw * 0.95, top - 0.03], [hx - fw * 0.66, top - len * 0.7]], wpx * 1.0, hc);
    stroke(pen, [[hx + fw * 0.95, top - 0.03], [hx + fw * 0.66, top - len * 0.7]], wpx * 1.0, hc);
    if (T.reinsFront) stroke(pen, [[hx - fw * 0.6, top - len * 0.75], [X(-0.12), Y(1.45)]], wpx * 0.8, hc), stroke(pen, [[hx + fw * 0.6, top - len * 0.75], [X(0.12), Y(1.45)]], wpx * 0.8, hc);
  }
}

// ---------------------------------------------------------------- 뒷모습
export function drawBack(pen, C, P, T = {}) {
  const k = pxk(pen), wpx = max(1.4, k * 0.016);
  const col = C.coat, far = shade(col, -0.3), mane = C.mane;
  const ls = C.pony ? 0.82 : 1.0, wd = C.pony ? 1.12 : 1.0;
  const tr = P.turn || 0, sw = P.sway || 0;
  const by = P.bob * 0.6 - (1 - ls) * 0.9;
  const Y = (y) => y + by, X = (x, d = 0) => x - tr * d * 0.5 + sw * (1 - d);
  // 머리·목(멀리, 등 너머) — 숙이면 안 보인다
  if (P.head !== 'eat' && P.head !== 'graze') {
    const hy = Y(1.95 + P.hp * 0.8);
    const nk = [[X(-0.13, 1), Y(1.4)], [X(-0.09, 1), hy - 0.12], [X(0.09, 1), hy - 0.12], [X(0.13, 1), Y(1.4)]];
    wash(pen, nk, far, 0.1, 0.05); ink(pen, nk, wpx);
    for (const sgn of [-1, 1]) {
      const ea = P.ear * (sgn > 0 ? 1 : 0.4);
      const ear = [[X(sgn * 0.04, 1), hy - 0.08], [X(sgn * (0.1 + ea * 0.04), 1), hy + 0.1 - ea * 0.03], [X(sgn * 0.12, 1), hy - 0.1]];
      wash(pen, ear, far, 0.1, 0.05); ink(pen, ear, wpx * 0.85);
    }
    stroke(pen, [[X(0, 1), Y(1.42)], [X(0, 1), hy - 0.1]], k * 0.05, mane, 0.95);
  }
  // 앞다리(멀리, 사이로)
  legFront(pen, X(-0.13 * wd, 1), Y(0.96), 0.94 - (1 - ls) * 0.9, 0.062 * wd, far, P.legs.LF, wpx, 0.05 * wd);
  legFront(pen, X(0.13 * wd, 1), Y(0.96), 0.94 - (1 - ls) * 0.9, 0.062 * wd, far, P.legs.RF, wpx, 0.05 * wd);
  // 통(멀리 보이는 배) + 두 볼기
  const bw = 0.35 * wd;
  const barrel = [[X(-bw, 0.6), Y(1.15)], [X(-bw * 0.8, 0.7), Y(1.38)], [X(bw * 0.8, 0.7), Y(1.38)], [X(bw, 0.6), Y(1.15)], [X(bw * 0.7, 0.6), Y(0.88)], [X(-bw * 0.7, 0.6), Y(0.88)]];
  wash(pen, barrel, shade(col, -0.12), 0.3, 0.05); ink(pen, barrel, wpx);
  if (T.saddleBack) T.saddleBack(pen, X, Y, wpx, bw);
  // 뒷다리(가까이): 넓적다리 · 비절(뒤로 뾰족) · 정강이
  legFront(pen, X(-0.16 * wd), Y(1.02), 1.0 - (1 - ls) * 0.9, 0.085 * wd, shade(col, -0.04), P.legs.LH, wpx, 0.06 * wd);
  legFront(pen, X(0.16 * wd), Y(1.02), 1.0 - (1 - ls) * 0.9, 0.085 * wd, shade(col, 0.0), P.legs.RH, wpx, 0.06 * wd);
  for (const sgn of [-1, 1]) { const st = sgn < 0 ? P.legs.LH : P.legs.RH; const hy = Y(1.02) - 0.48 * ls * (1 - st.f * 0.2); dot(pen, X(sgn * 0.16 * wd), hy, k * 0.03, shade(col, -0.05)); stroke(pen, [[X(sgn * 0.16 * wd) - 0.03, hy], [X(sgn * 0.16 * wd) + 0.03, hy]], wpx * 0.6, INK, 0.7); }
  const rump = [[X(-0.36 * wd), Y(1.22)], [X(-0.32 * wd), Y(1.42)], [X(-0.12 * wd), Y(1.5)], [X(0), Y(1.46)], [X(0.12 * wd), Y(1.5)], [X(0.32 * wd), Y(1.42)], [X(0.36 * wd), Y(1.22)],
    [X(0.27 * wd), Y(0.96)], [X(0.08 * wd), Y(0.9)], [X(0), Y(0.96)], [X(-0.08 * wd), Y(0.9)], [X(-0.27 * wd), Y(0.96)]];
  wash(pen, rump, col, 0.32, 0.14); ink(pen, rump, wpx);
  stroke(pen, [[X(0), Y(1.44)], [X(0), Y(1.0)]], wpx * 0.9, shade(col, -0.45), 0.85);   // 두 볼기 사이 홈
  if (C.dapple) for (const [x, y] of [[-0.2, 1.3], [0.18, 1.25], [-0.1, 1.1], [0.24, 1.08]]) dot(pen, X(x * wd), Y(y), k * 0.022, shade(col, -0.16));
  // 꼬리(가운데, 휘두름)
  const tw = P.tail, tl = P.tailLift;
  const tail = [[X(-0.045), Y(1.47)], [X(0.045), Y(1.47)], [X(0.06 + tw * 0.4), Y(1.0 + tl * 0.2)], [X(0.04 + tw * 0.75), Y(0.6 + tl * 0.3)], [X(-0.06 + tw * 0.7), Y(0.58 + tl * 0.3)], [X(-0.06 + tw * 0.35), Y(1.0 + tl * 0.2)]];
  wash(pen, tail, mane, 0.25, 0.05); ink(pen, tail, wpx);
  stroke(pen, [[X(tw * 0.2), Y(1.2)], [X(tw * 0.6), Y(0.75)]], wpx * 0.6, shade(mane, 0.25), 0.6);
}

// 굽는 쪽(안장 등 덧그림)이 같은 붓을 쓰도록
export { wash, ink, stroke, dot, curve };

// ---------------------------------------------------------------- 한 장
export function drawHorse(pen, view, C, P, T = {}) {
  if (view === 'side') return drawSide(pen, C, P, T);
  if (view === 'front') return drawFront(pen, C, P, T);
  return drawBack(pen, C, P, T);
}
