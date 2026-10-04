// 자동 기승 프레임 굽기(scripts/region/horse_ride.gd, CHARACTER master CHR_ANI_002 말) — 웹 코드(seolhwa/src)는 고치지 않는다.
//  - ride_horse: 탈 말(안장·언치·굴레·고삐). 앞·옆·뒤 세 시점 × idle(4)·walk(6, 걸음)·run(6, 구보 — 몸이 앞뒤로 흔들림).
//      웹에 짐승 리그가 없어 npc_bake 짐승처럼 캔버스에 먹선·담채로 직접 그린다(옆은 왼쪽을 본다 — 오른쪽은 엔진이 뒤집는다).
//      주변 말(frames_amb horse, 옆모습만)보다 1.3배 크다(사람 2.06m에 맞춘 탈 말 — 등 높이 약 1.75m).
//  - player: ride(말 위 — 무릎 굽혀 걸터앉아 두 손으로 고삐, 걸음 따라 들썩임: 앞·옆·뒤) · mount · dismount(옆, 오르기·내리기).
//      웹 굽기 엔진(frameCore.BakeBank, high)에 동작만 더한다. 엉덩이(안장 닿는 곳)가 발밑 원점 — 엔진이 안장 높이로 올린다.
// 결과: data/frames_ride.json + frames_ride_<kind>_<n>.png (data/는 git 제외 — 다른 맥에서는 다시 굽는다. 없으면 엔진은 주변 말 옆모습·앉기로 대신)
// 실행: python3 tools/web_export_server.py 8770 → http://localhost:8770/__tools/ride_bake.html
//   (헤드리스: "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" --headless=new --virtual-time-budget=120000 --dump-dom 그 주소 — 끝나면 <p id=st>done…)
import { SPECS, getRig } from '/src/chars/rigs.js';
import * as fc from '/src/chars/frameCore.js';

const { sin, cos, PI, max, min, abs } = Math;
const SWAP = { arm1: 'arm2', arm2: 'arm1', arm1_l: 'arm2_l', arm2_l: 'arm1_l', leg1: 'leg2', leg2: 'leg1', leg1_l: 'leg2_l', leg2_l: 'leg1_l' };
const toP = (F) => { const P = {}; for (const n in F) { const a = F[n]; P[n] = { r: a[0] || 0, x: a[1] || 0, y: a[2] || 0, sx: a[3] ?? 1, sy: a[4] ?? 1, a: a[5] ?? 1 }; } return P; };
const mirror = (P) => { const Q = {}; for (const n in P) { const p = P[n]; Q[SWAP[n] || n] = { r: -p.r, x: -p.x, y: p.y, sx: p.sx, sy: p.sy, a: p.a }; } return Q; };
const lerpF = (A, B, k) => { const O = {}; for (const n of new Set([...Object.keys(A), ...Object.keys(B)])) { const a = A[n] || [], b = B[n] || []; const L = Math.max(a.length, b.length, 1); O[n] = []; for (let j = 0; j < L; j++) { const d = j < 3 ? 0 : 1; const x = a[j] ?? d, y = b[j] ?? d; O[n].push(x + (y - x) * k); } } return O; };
const sm = (k) => k * k * (3 - 2 * k);

// ---------------------------------------------------------------------------
// 탄 사람(player) 자세
// ---------------------------------------------------------------------------
const RIDE_ANIMS = { ride: { dur: 0.56, loop: true }, mount: { dur: 0.75 }, dismount: { dur: 0.7 } };
function rideBase(side, S, bob, sway) {
  const k = S.hip / 80;
  if (side) return { root: [0.0, 0, S.hip - 4 * k - bob * k], torso: [-0.1 + sway * 0.05], head: [0.08 - sway * 0.04],
    leg2: [0.85], leg2_l: [-1.05], leg1: [0.78], leg1_l: [-1.0],
    arm2: [0.62], arm2_l: [0.95], arm1: [0.55], arm1_l: [1.0] };
  return { root: [0, 0, S.hip - 4 * k - bob * k], torso: [sway * 0.03], head: [-sway * 0.02],
    leg1: [0.55, 0, 0, 1, 0.95], leg1_l: [-0.5, 0, 0, 1, 0.9], leg2: [-0.55, 0, 0, 1, 0.95], leg2_l: [0.5, 0, 0, 1, 0.9],
    arm1: [0.14], arm1_l: [-0.85, 0, 0, 1, 0.8], arm2: [-0.14], arm2_l: [0.85, 0, 0, 1, 0.8] };
}
function ridePose(view, anim, t, at, rig) {
  if (!RIDE_ANIMS[anim]) return null;
  const S = rig.S, side = view === 'side', k = S.hip / 80;
  let F;
  if (anim === 'ride') {
    const u = ((t / RIDE_ANIMS.ride.dur) % 1 + 1) % 1;
    F = rideBase(side, S, 3.0 * abs(sin(u * PI * 2)), sin(u * PI * 2));
  } else {
    let u = Math.min(1, Math.max(0, at / RIDE_ANIMS[anim].dur));
    if (anim === 'dismount') u = 1 - u;
    const stand = side ? { arm2: [0.2], arm1: [0.15], leg2: [0.05], leg1: [-0.05] } : {};
    const reach = side
      ? { root: [0, 0, -4 * k], torso: [-0.25], head: [0.1], leg2: [-0.05], leg1: [1.6], leg1_l: [-1.6], arm2: [2.4], arm2_l: [0.3], arm1: [2.2], arm1_l: [0.2] }
      : { root: [0, 0, -4 * k], arm1: [2.6], arm2: [-2.6], leg1: [0.9], leg1_l: [-1.2] };
    const swing = side
      ? { root: [0, 0, S.hip * 0.55], torso: [-0.35], head: [0.15], leg2: [1.2], leg2_l: [-0.9], leg1: [0.6], leg1_l: [-1.0], arm2: [1.4], arm2_l: [0.6], arm1: [1.2], arm1_l: [0.6] }
      : { root: [0, 0, S.hip * 0.55], leg1: [0.6], leg1_l: [-0.5], leg2: [-0.9], leg2_l: [0.6], arm1: [0.5], arm2: [-0.5] };
    const end = rideBase(side, S, 0, 0);
    if (u < 0.4) F = lerpF(stand, reach, sm(u / 0.4));
    else if (u < 0.75) F = lerpF(reach, swing, sm((u - 0.4) / 0.35));
    else F = lerpF(swing, end, sm((u - 0.75) / 0.25));
  }
  F.staff = [0, 0, 0, 1, 1, 0];   // 지팡이는 안장에 꽂아 둔다(말 위에서는 안 보임)
  const P = toP(F);
  return view === 'back' ? mirror(P) : P;
}

// ---------------------------------------------------------------------------
// 말 그리기 — 길이 단위 m(1.3배 그린다), 발 중심 원점, 위가 +y, 옆모습 머리는 왼쪽(−x)
// ---------------------------------------------------------------------------
const PPM = 100, PAGE = 1024, MARGIN = 5, TW = 560, TH = 400, TOX = 280, TOY = 380, SC = 1.3;
const INKC = '#1f1a17';
const COAT = '#7a5236', DARK = '#2a221c', SADDLE = '#4a2e1e', CLOTH = '#8e3a2c', CLOTH2 = '#2f4a6a', METAL = '#b8a46a';

function shadeHex(hex, k) {
  const n = parseInt(hex.slice(1), 16); let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  const t = k < 0 ? [30, 24, 18] : [246, 239, 223], a = Math.abs(k);
  r += (t[0] - r) * a; g += (t[1] - g) * a; b += (t[2] - b) * a;
  return '#' + ((1 << 24) | ((r | 0) << 16) | ((g | 0) << 8) | (b | 0)).toString(16).slice(1);
}

class Pen {
  constructor() { this.cv = document.createElement('canvas'); this.cv.width = TW; this.cv.height = TH; this.g = this.cv.getContext('2d', { willReadFrequently: true }); }
  clear() { this.g.setTransform(1, 0, 0, 1, 0, 0); this.g.clearRect(0, 0, TW, TH); }
  X(x) { return TOX + x * PPM * SC; }
  Y(y) { return TOY - y * PPM * SC; }
  path(pts, closed = true) {
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
  ell(cx, cy, rx, ry, col, w = 2.4, shadeDown = 0.25) {
    const pts = []; for (let i = 0; i < 16; i++) { const a = i / 16 * 2 * PI; pts.push([cx + cos(a) * rx, cy + sin(a) * ry]); }
    this.blob(pts, col, w, shadeDown);
  }
  line(pts, col, w, ink = 2.2) {
    const g = this.g; g.lineCap = 'round'; g.lineJoin = 'round';
    if (ink > 0) { this.path(pts, false); g.lineWidth = w * PPM * SC + ink * 2; g.strokeStyle = INKC; g.stroke(); }
    this.path(pts, false); g.lineWidth = w * PPM * SC; g.strokeStyle = col; g.stroke();
  }
  stroke(pts, w = 1.2, col = INKC) { const g = this.g; this.path(pts, false); g.lineWidth = w; g.strokeStyle = col; g.lineCap = 'round'; g.stroke(); }
  dot(x, y, r, col = INKC) { const g = this.g; g.beginPath(); g.arc(this.X(x), this.Y(y), r, 0, 2 * PI); g.fillStyle = col; g.fill(); }
}

// 다리 한 짝(옆): 붙은 자리(ax,ay), 길이 L, 흔들기 각 a(+는 앞=왼쪽), 발 들림 lift(무릎이 더 굽음)
function leg(pen, ax, ay, L, a, w, col, hoof, bendSign = 1, lift = 0) {
  const k = 0.18 + lift * 2.6;
  const kx = ax - sin(a) * L * 0.5, ky = ay - cos(a) * L * 0.5;
  const fx = kx - sin(a - bendSign * k) * L * 0.5, fy = Math.max(0.03, ky - cos(a - bendSign * k) * L * 0.5 + lift * 0.45);
  pen.line([[ax, ay + 0.05], [kx, ky]], col, w * 1.45);
  pen.line([[kx, ky], [fx, fy]], col, w * 0.85);
  if (hoof) pen.blob([[fx - 0.06, fy + 0.04], [fx + 0.05, fy + 0.04], [fx + 0.06, fy - 0.03], [fx - 0.07, fy - 0.03]], hoof, 1.4, 0);
}
// 다리 한 짝(앞·뒤 시점): 곧게 서고, 들리면 발굽이 올라오며 무릎이 앞으로 굽어 짧아진다
function legV(pen, x, top, L, w, col, lift, hoofCol = DARK) {
  const kneeY = top - L * 0.5 + lift * 0.25, footY = 0.03 + lift * 0.5;
  pen.line([[x, top], [x, kneeY]], col, w * 1.4);
  pen.line([[x, kneeY], [x, footY + 0.05]], col, w * 0.85);
  pen.blob([[x - 0.055, footY + 0.05], [x + 0.055, footY + 0.05], [x + 0.06, footY - 0.02], [x - 0.06, footY - 0.02]], hoofCol, 1.3, 0);
}

function gait(anim, f, n) {
  const ph = (anim === 'walk' || anim === 'run') ? (f / n) * 2 * PI : 0;
  const run = anim === 'run';
  const A = anim === 'walk' ? 0.34 : run ? 0.62 : 0;
  const br = anim === 'idle' ? sin((f / n) * 2 * PI) * 0.01 : 0;
  // 구보: 몸이 앞뒤로 흔들림(앞이 들릴 때 뒤가 내려감), 걸음: 살짝 위아래
  const rock = run ? 0.05 * sin(ph) : 0, bob = run ? 0.05 * abs(sin(ph)) : (anim === 'walk' ? 0.015 * abs(sin(ph * 2)) : br);
  // 다리 위상: 걸음 = 네 박, 구보 = 뒷다리 둘 → 앞다리 둘
  const off = run ? [0, 0.35, 1.9, 2.4] : [0, PI, PI * 0.5, PI * 1.5];   // [뒤 먼, 뒤 가까운, 앞 먼, 앞 가까운]
  const sw = (i) => A * sin(ph + off[i]), lf = (i) => (A > 0 ? (run ? 0.13 : 0.06) * max(0, cos(ph + off[i])) : 0);
  return { ph, run, A, rock, bob, sw, lf };
}

function drawSide(pen, anim, f, n) {
  const G = gait(anim, f, n);
  const col = COAT, far = shadeHex(col, -0.25);
  const by = G.bob, rk = G.rock;
  const yB = (x) => by + rk * (-x);   // 앞(−x)이 들리면 rk>0
  // 먼 다리
  leg(pen, 0.75, 0.92 + yB(0.75), 0.92, G.sw(0), 0.1, far, DARK, -1, G.lf(0));
  leg(pen, -0.45, 0.88 + yB(-0.45), 0.9, G.sw(2), 0.09, far, DARK, 1, G.lf(2));
  // 꼬리
  const tw = G.A > 0 ? 0.08 * sin(G.ph) : 0.1 * sin((f / n) * 2 * PI);
  const tl = G.run ? 0.25 : 0;
  pen.blob([[0.86, 1.34 + yB(0.86)], [1.05 + tw * 0.5 + tl, 1.15 + tl * 0.4], [1.08 + tw + tl * 1.4, 0.66 + tl * 0.9], [0.97 + tw + tl, 0.7 + tl * 0.8], [0.84, 1.12 + yB(0.84)]], DARK, 1.6);
  // 몸통
  pen.blob([[-0.6, 1.38 + yB(-0.6)], [-0.2, 1.44 + yB(-0.2)], [0.5, 1.38 + yB(0.5)], [0.92, 1.32 + yB(0.92)], [0.98, 1.06 + yB(0.98)], [0.8, 0.85 + yB(0.8)],
    [0.2, 0.79 + yB(0.2)], [-0.35, 0.81 + yB(-0.35)], [-0.66, 0.99 + yB(-0.66)], [-0.7, 1.22 + yB(-0.7)]], col);
  pen.stroke([[0.55, 1.25 + yB(0.55)], [0.7, 1.0 + yB(0.7)]], 1.0, shadeHex(col, -0.35));
  // 언치(안장 밑 천)·안장·등자
  pen.blob([[-0.34, 1.42 + yB(-0.34)], [0.3, 1.4 + yB(0.3)], [0.33, 1.08 + yB(0.33)], [-0.36, 1.1 + yB(-0.36)]], CLOTH, 1.8, 0.2);
  pen.stroke([[-0.32, 1.14 + yB(-0.32)], [0.3, 1.12 + yB(0.3)]], 2.0, METAL);
  pen.blob([[-0.3, 1.5 + yB(-0.3)], [-0.18, 1.46 + yB(-0.18)], [0.16, 1.46 + yB(0.16)], [0.28, 1.53 + yB(0.28)], [0.24, 1.4 + yB(0.24)], [-0.26, 1.4 + yB(-0.26)]], SADDLE, 1.8, 0.3);
  pen.stroke([[-0.02, 1.4 + yB(-0.02)], [-0.02, 0.95 + yB(-0.02)]], 1.4, DARK);
  pen.blob([[-0.07, 0.96 + yB(0)], [0.03, 0.96 + yB(0)], [0.03, 0.92 + yB(0)], [-0.07, 0.92 + yB(0)]], METAL, 1.2, 0);
  // 가까운 다리
  leg(pen, -0.55, 0.9 + yB(-0.55), 0.9, G.sw(3), 0.1, col, DARK, 1, G.lf(3));
  leg(pen, 0.66, 0.94 + yB(0.66), 0.92, G.sw(1), 0.11, shadeHex(col, -0.05), DARK, -1, G.lf(1));
  // 목·머리(구보면 앞으로 뻗고 끄덕임)
  const nod = G.run ? 0.06 * sin(G.ph + 0.8) : (G.A > 0 ? 0.02 * sin(G.ph * 2) : 0.015 * sin((f / n) * 2 * PI));
  const hx = G.run ? -1.12 : -1.02, hy = (G.run ? 1.62 : 1.72) + nod + yB(-1.0);
  pen.blob([[-0.38, 1.44 + yB(-0.38)], [-0.7, (hy + 1.42) / 2 + 0.12], [hx + 0.14, hy + 0.06], [hx + 0.02, hy - 0.12], [-0.85, (hy + 1.0) / 2 - 0.05], [-0.68, 1.04 + yB(-0.68)]], col);
  pen.line([[-0.36, 1.46 + yB(-0.36)], [-0.62, (hy + 1.42) / 2 + 0.14], [hx + 0.14, hy + 0.1]], DARK, 0.05, 1.2);
  const dx = -0.3, dy = -0.12;
  pen.blob([[hx + 0.12, hy + 0.08], [hx - 0.02, hy + 0.1], [hx + dx - 0.02, hy + dy + 0.02], [hx + dx + 0.02, hy + dy - 0.08], [hx + 0.08, hy - 0.1]], shadeHex(col, 0.04));
  pen.blob([[hx + 0.08, hy + 0.08], [hx + 0.14, hy + 0.24], [hx + 0.18, hy + 0.08]], col, 1.5);
  pen.dot(hx + 0.0, hy + 0.0, 2.4);
  // 굴레·고삐(입 → 안장 앞, 탄 사람 손)
  pen.stroke([[hx + 0.08, hy + 0.06], [hx + dx + 0.06, hy + dy - 0.02]], 1.6, '#5a3020');
  pen.stroke([[hx + 0.06, hy - 0.08], [hx + 0.1, hy + 0.08]], 1.6, '#5a3020');
  pen.stroke([[hx + dx + 0.06, hy + dy - 0.03], [-0.6, 1.62 + yB(-0.5)], [-0.32, 1.62 + yB(-0.3)]], 1.4, '#5a3020');
}

function drawFront(pen, anim, f, n) {
  const G = gait(anim, f, n);
  const col = COAT, far = shadeHex(col, -0.28);
  const by = G.bob + (G.run ? 0.03 * sin(G.ph) : 0);
  // 뒷다리(멀리 — 몸통 사이로 조금)
  legV(pen, -0.2, 0.95 + by, 0.86, 0.085, far, G.lf(0) * 0.6);
  legV(pen, 0.2, 0.95 + by, 0.86, 0.085, far, G.lf(1) * 0.6);
  // 몸통(가슴 쪽에서 본 통)
  pen.ell(0, 1.2 + by, 0.37, 0.3, shadeHex(col, -0.08));
  // 언치·안장(통 위)
  pen.blob([[-0.42, 1.4 + by], [0.42, 1.4 + by], [0.4, 1.1 + by], [0.3, 1.04 + by], [-0.3, 1.04 + by], [-0.4, 1.1 + by]], CLOTH, 1.8, 0.2);
  pen.blob([[-0.3, 1.52 + by], [0.3, 1.52 + by], [0.27, 1.4 + by], [-0.27, 1.4 + by]], SADDLE, 1.8, 0.3);
  pen.stroke([[-0.39, 1.36 + by], [-0.4, 0.9 + by]], 1.4, DARK); pen.stroke([[0.39, 1.36 + by], [0.4, 0.9 + by]], 1.4, DARK);
  pen.blob([[-0.45, 0.92 + by], [-0.35, 0.92 + by], [-0.35, 0.87 + by], [-0.45, 0.87 + by]], METAL, 1.2, 0);
  pen.blob([[0.35, 0.92 + by], [0.45, 0.92 + by], [0.45, 0.87 + by], [0.35, 0.87 + by]], METAL, 1.2, 0);
  // 가슴
  pen.ell(0, 1.08 + by, 0.25, 0.28, col);
  // 앞다리
  legV(pen, -0.14, 0.92 + by, 0.92, 0.1, col, G.lf(2));
  legV(pen, 0.14, 0.92 + by, 0.92, 0.1, shadeHex(col, -0.05), G.lf(3));
  // 목·머리(정면 — 길쭉하게 아래로 주둥이)
  const nod = G.run ? 0.05 * sin(G.ph + 0.8) : 0.015 * sin((f / n) * 2 * PI);
  const hy = 1.98 + nod + by;
  pen.blob([[-0.13, 1.28 + by], [0.13, 1.28 + by], [0.11, hy - 0.2], [-0.11, hy - 0.2]], col);
  pen.line([[0, 1.36 + by], [0, hy - 0.12]], DARK, 0.06, 1.2);   // 갈기(목 가운데로 보임)
  pen.blob([[-0.13, hy], [0.13, hy], [0.11, hy - 0.3], [0.08, hy - 0.52], [-0.08, hy - 0.52], [-0.11, hy - 0.3]], shadeHex(col, 0.05));
  pen.blob([[-0.12, hy - 0.02], [-0.16, hy + 0.14], [-0.06, hy + 0.02]], col, 1.5);   // 귀
  pen.blob([[0.12, hy - 0.02], [0.16, hy + 0.14], [0.06, hy + 0.02]], col, 1.5);
  pen.blob([[-0.03, hy - 0.04], [0.03, hy - 0.04], [0.02, hy - 0.42], [-0.02, hy - 0.42]], '#ece4d2', 1.0, 0);   // 흰 줄(코잔등)
  pen.blob([[-0.06, hy + 0.02], [0.06, hy + 0.02], [0.03, hy - 0.08], [-0.03, hy - 0.08]], DARK, 1.0, 0);     // 앞머리 털
  pen.dot(-0.105, hy - 0.14, 2.4); pen.dot(0.105, hy - 0.14, 2.4);
  pen.dot(-0.04, hy - 0.48, 1.8); pen.dot(0.04, hy - 0.48, 1.8);
  pen.stroke([[-0.11, hy - 0.3], [0.11, hy - 0.3]], 1.6, '#5a3020');   // 굴레
  pen.stroke([[-0.09, hy - 0.42], [-0.22, 1.5 + by]], 1.4, '#5a3020'); pen.stroke([[0.09, hy - 0.42], [0.22, 1.5 + by]], 1.4, '#5a3020');
}

function drawBack(pen, anim, f, n) {
  const G = gait(anim, f, n);
  const col = COAT, far = shadeHex(col, -0.28);
  const by = G.bob + (G.run ? 0.03 * sin(G.ph + PI) : 0);
  // 앞다리(멀리)
  legV(pen, -0.15, 0.95 + by, 0.86, 0.085, far, G.lf(2) * 0.6);
  legV(pen, 0.15, 0.95 + by, 0.86, 0.085, far, G.lf(3) * 0.6);
  // 목·머리 윗부분(멀리, 안장 너머로 귀)
  const nod = G.run ? 0.05 * sin(G.ph + 0.8) : 0.01 * sin((f / n) * 2 * PI);
  const hy = 1.95 + nod + by;
  pen.blob([[-0.12, 1.4 + by], [0.12, 1.4 + by], [0.1, hy - 0.08], [-0.1, hy - 0.08]], far);
  pen.blob([[-0.1, hy - 0.04], [-0.14, hy + 0.12], [-0.04, hy]], far, 1.5);
  pen.blob([[0.1, hy - 0.04], [0.14, hy + 0.12], [0.04, hy]], far, 1.5);
  pen.line([[0, 1.45 + by], [0, hy - 0.04]], DARK, 0.07, 1.2);
  // 몸통
  pen.ell(0, 1.22 + by, 0.37, 0.3, shadeHex(col, -0.05));
  pen.blob([[-0.42, 1.42 + by], [0.42, 1.42 + by], [0.4, 1.12 + by], [-0.4, 1.12 + by]], CLOTH, 1.8, 0.2);
  pen.blob([[-0.3, 1.54 + by], [0.3, 1.54 + by], [0.27, 1.42 + by], [-0.27, 1.42 + by]], SADDLE, 1.8, 0.3);
  // 엉덩이(두 둥치)
  pen.blob([[-0.38, 1.12 + by], [-0.34, 1.34 + by], [-0.1, 1.4 + by], [0, 1.33 + by], [0.1, 1.4 + by], [0.34, 1.34 + by], [0.38, 1.12 + by], [0.28, 0.92 + by], [0, 0.88 + by], [-0.28, 0.92 + by]], col);
  pen.stroke([[0, 1.32 + by], [0, 0.95 + by]], 1.2, shadeHex(col, -0.4));
  // 뒷다리(가까이)
  legV(pen, -0.21, 0.95 + by, 0.92, 0.11, col, G.lf(0));
  legV(pen, 0.21, 0.95 + by, 0.92, 0.11, shadeHex(col, -0.05), G.lf(1));
  // 꼬리
  const tw = G.A > 0 ? 0.08 * sin(G.ph) : 0.06 * sin((f / n) * 2 * PI);
  pen.blob([[-0.06, 1.36 + by], [0.06, 1.36 + by], [0.07 + tw, 0.95], [0.02 + tw * 1.4, 0.68], [-0.06 + tw * 1.2, 0.7], [-0.06 + tw * 0.5, 1.0]], DARK, 1.6);
}

const VIEWS = { side: drawSide, front: drawFront, back: drawBack };
const HORSE_ANIMS = { idle: 4, walk: 6, run: 6 };

function bakeHorse() {
  const pen = new Pen();
  const pages = [];
  let page = null, sx = 0, sy = 0, rowH = 0;
  const newPage = () => { page = document.createElement('canvas'); page.width = PAGE; page.height = PAGE; pages.push(page); sx = 0; sy = 0; rowH = 0; };
  newPage();
  const clips = {};
  for (const view in VIEWS) {
    for (const anim in HORSE_ANIMS) {
      const n = HORSE_ANIMS[anim], frames = [];
      for (let f = 0; f < n; f++) {
        pen.clear();
        VIEWS[view](pen, anim, f, n);
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
      const spec = anim === 'idle'
        ? { kind: 'loop', times: [...Array(n).keys()].map((k) => k * 0.8), loopStart: 0, intro: 0, step: 0.8, n, dur: n * 0.8, tBased: true }
        : { kind: 'phase', n, times: [...Array(n).keys()].map((k) => k / n) };
      clips[view + '|' + anim] = { spec, frames };
    }
  }
  return { pages, clips };
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
  // ---- 말 ----
  const hb = bakeHorse();
  const hp = [];
  for (let i = 0; i < hb.pages.length; i++) { const name = `frames_ride_horse_${i}.png`; await put(name, await toPng(hb.pages[i])); hp.push(name); }
  out.ride_horse = { pages: hp, clips: hb.clips };
  log('baked ride_horse pages=' + hp.length);
  // ---- 탄 사람 ----
  const rig = getRig('player');
  rig.anims = { ...rig.anims, ...RIDE_ANIMS };
  const base = rig.pose;
  rig.pose = (view, anim, t, rg, at, st) => ridePose(view, anim, t, at, rig) || base(view, anim, t, rg, at, st);
  const b = new fc.BakeBank('player', 'high');
  const clips = {};
  for (const vw of ['front', 'side', 'back']) for (const a of ['ride', 'mount', 'dismount']) {
    if (a !== 'ride' && vw !== 'side') continue;   // 오르기·내리기는 옆모습(앞·뒤는 엔진이 옆으로 대신)
    const key = fc.clipKey(vw, a, false, false);
    if (clips[key]) continue;
    const c = b.clip(key); if (!c) continue;
    if (a === 'ride') { const n = 6, step = RIDE_ANIMS.ride.dur / n; c.spec = { kind: 'loop', times: [...Array(n).keys()].map((k) => k * step), loopStart: 0, intro: 0, step, n, dur: RIDE_ANIMS.ride.dur, tBased: false }; }
    let g = 0; while (!b.step(c) && g++ < 600);
    clips[key] = { spec: c.spec, frames: c.frames.map(meta) };
  }
  const pp = [];
  for (let i = 0; i < b.pages.length; i++) { const name = `frames_ride_player_${i}.png`; await put(name, await toPng(b.pages[i].cv)); pp.push(name); }
  out.player = { pages: pp, clips };
  log('baked player ride pages=' + pp.length + ' clips=' + Object.keys(clips).join(','));
  await put('frames_ride.json', JSON.stringify(out));
  log('done: ' + Object.keys(out).join(', '));
  console.log('[ride bake] done', Object.keys(out));
}
