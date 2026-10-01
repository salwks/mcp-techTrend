// 설화록 — 프레임 바이 프레임('frames') 렌더 스타일: 굽기(bake)
//
// 컷아웃은 단단한 부위가 관절에서 돌기 때문에 '관절 인형'처럼 보인다. 여기서는 같은 붓그림 부위를
// 매 그림마다 곡선을 따라 휘게 다시 그린다(띠 단위 워프).
//  - 팔·다리: 어깨→팔꿈치→손목 곡선을 따라 소매와 바지가 한 장으로 부드럽게 휜다
//  - 몸통: 엉덩이 기울기에서 가슴 기울기로 이어지는 곡선 척추를 따라 휜다
//  - 두루마기·치마: 아래로 갈수록 퍼지고(flare) 앞무릎 쪽으로 밀리고 뒤로 끌린다(drag)
//  - 호랑이: 척추가 휘고(웅크림 때 오목, 도약 때 쭉 늘어남, 살금 걸음 때 물결), 배가 처지고, 꼬리는 스플라인
//  - 빠른 칼질·앞발·도약에는 번짐(smear)과 갈필 줄, 그림마다 1px 남짓 선이 떨림(boil)
// 모든 그림은 아틀라스 페이지(1024²)에 구워 두고, 실행 중에는 UV만 바꾼다.
// 이 파일은 three·DOM 없이 돌아간다 → Web Worker(OffscreenCanvas)에서도, 메인 스레드에서도 같은 코드로 굽는다.
import { getRig, strideOf, frameLimb } from './rigs.js';
import { rng, INK, PAPER, makeCanvas } from './painter.js';

export const FRAME_KINDS = ['player', 'tiger'];

const PAGE = 1024;          // 페이지 텍스처 크기
const MARGIN = 5;           // halo가 번질 투명 여백
/** 해상도 단계: 화면상 1m(배율 적용 후)당 프레임 픽셀 */
export const TIERS = {
  high: { player: 116, tiger: 98, once: 0.78 },   // 데스크톱
  medium: { player: 80, tiger: 68, once: 0.85 },  // 휴대폰·작은 화면
};
// once: 1회성 동작(공격·도약·넘어짐 등 빠르게 지나가는 그림)은 이 배율로 조금 낮게 굽는다 — 움직임에 묻혀 안 보이고 메모리는 40% 절약 // 프레임 해상도: 화면상 1m(배율 적용 후)당 픽셀
const BODY_SPRINGS = {
  human: { skirt: [90, 10], braid: [55, 6], pack: [120, 12], head: [260, 26], arm1_l: [170, 16], arm2_l: [170, 16] },
  tiger: { tail0: [80, 9], tail1: [65, 7], tail2: [52, 5.5], tail3: [42, 4.5], head: [210, 22] },
};
const FAST_HUMAN = new Set(['attack1', 'attack2', 'attack3', 'heavy', 'dodge', 'bow_shoot']);
const FAST_ALL = new Set([...FAST_HUMAN, 'pounce', 'swipe', 'slip', 'climb_try']);
const PHASE_ANIMS = new Set(['walk', 'run', 'prowl', 'retreat']);
const INTRO = { charge: 0.18, guard: 0.18, bow_draw: 0.18, crouch: 0.2 };
const COMBAT_H = new Set(['attack1', 'attack2', 'attack3', 'charge', 'heavy', 'guard', 'dodge', 'bow_draw', 'bow_shoot', 'throw', 'hit', 'down', 'getup', 'dead']);

// ---------------------------------------------------------------------------
// 클립(동작 하나 × 시점 하나)의 표본 시각
// ---------------------------------------------------------------------------
/**
 * 동작별 그림 수/시각.
 *  - 기본은 초당 12장(on twos). 느린 동작(쓰러짐·일어남·비틀거림)은 8장.
 *  - 빠른 순간(칼이 닿는 구간, 도약 박차기, 앞발 내리치기)에만 초당 24장을 덧넣는다.
 *  - 걷기·뛰기는 한 주기 6장(살금 걸음은 예고 동작이라 8장), 숨쉬기 대기는 4~6장.
 */
const SLOW = new Set(['down', 'getup', 'dead', 'stagger', 'roar', 'eat']);
// 드물게 보이는 시점×동작은 옆모습으로 대신(메모리 절약)
export const VIEW_FALLBACK = {
  player: { back: new Set(['bow_draw', 'bow_shoot', 'throw', 'talk', 'down', 'getup', 'dead', 'hit']) },
  tiger: { back: new Set(['roar', 'eat', 'stagger', 'dead', 'hit', 'land', 'sniff', 'swipe']), front: new Set(['knock', 'climb_try', 'slip']) },
};
export function resolveView(kind, view, anim) {
  const f = VIEW_FALLBACK[kind];
  return f && f[view] && f[view].has(anim) ? 'side' : view;
}
const CONTACT = {
  attack1: [0.3, 0.66], attack2: [0.3, 0.68], attack3: [0.36, 0.72], heavy: [0.33, 0.72], dodge: [0.0, 0.25],
  pounce: [0.04, 0.2], swipe: [0.55, 0.82], bow_shoot: [0, 0.3], slip: [0.5, 0.7],
};
const LOOP_N = { idle: 4, talk: 4, charge: 4, guard: 3, bow_draw: 3, crouch: 4, eat: 4, knock: 10, sniff: 8 };
export function clipSpec(rig, anim) {
  const info = rig.anims[anim];
  if (!info) return null;
  const tiger = rig.type === 'tiger';
  if (PHASE_ANIMS.has(anim)) {
    const n = 6;
    return { kind: 'phase', n, times: [...Array(n).keys()].map((k) => k / n) };
  }
  if (info.loop) {
    const intro = INTRO[anim] || 0;
    const n = LOOP_N[anim] || 4;
    const step = info.dur / n;
    const times = [];
    if (intro) times.push(0, intro * 0.5);
    const loopStart = times.length;
    for (let k = 0; k < n; k++) times.push(intro + k * step);
    return { kind: 'loop', times, loopStart, intro, step, n, dur: info.dur, tBased: anim === 'idle' || anim === 'talk' };
  }
  const fps = SLOW.has(anim) ? 7 : 12;
  const set = new Set();
  for (let t = 0; t < info.dur - 1e-6; t += 1 / fps) set.add(+t.toFixed(4));
  const w = CONTACT[anim];
  if (w) for (let t = w[0] * info.dur; t <= w[1] * info.dur + 1e-6; t += 1 / 24) set.add(+t.toFixed(4));
  set.add(+info.dur.toFixed(4));
  const times = [...set].sort((a, b) => a - b).filter((t, i, arr) => i === 0 || t - arr[i - 1] > 0.02);
  return { kind: 'once', times, dur: info.dur };
}

/** 실행 중 클립에서 그림 번호 고르기 */
export function frameIndex(spec, animTime, phase, t) {
  const T = spec.times;
  if (spec.kind === 'phase') return Math.floor((((phase % 1) + 1) % 1) * spec.n) % spec.n;
  if (spec.kind === 'loop') {
    const tt = spec.tBased ? t : animTime;
    if (!spec.tBased && tt < spec.intro) { let i = 0; while (i + 1 < spec.loopStart && T[i + 1] <= tt) i++; return i; }
    const lt = spec.tBased ? tt : tt - spec.intro;
    return spec.loopStart + (Math.floor(lt / spec.step) % spec.n + spec.n) % spec.n;
  }
  let i = 0;
  while (i + 1 < T.length && T[i + 1] <= animTime + 1e-6) i++;
  return i;
}

// ---------------------------------------------------------------------------
// 2D 아핀 도우미
// ---------------------------------------------------------------------------
const mul = (m, n) => [m[0] * n[0] + m[2] * n[1], m[1] * n[0] + m[3] * n[1], m[0] * n[2] + m[2] * n[3], m[1] * n[2] + m[3] * n[3], m[0] * n[4] + m[2] * n[5] + m[4], m[1] * n[4] + m[3] * n[5] + m[5]];
const trs = (x, y, r, sx = 1, sy = 1) => { const c = Math.cos(r), s = Math.sin(r); return [c * sx, s * sx, -s * sy, c * sy, x, y]; };
const ap = (m, x, y) => [m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5]];
const angOf = (m) => Math.atan2(m[1], m[0]);
const ID = [1, 0, 0, 1, 0, 0];

function computeMats(parts, P) {
  const M = {};
  for (const p of parts) {
    const ps = P[p.name];
    const r = p.r0 + (ps ? ps.r : 0);
    const x = p.at[0] + (ps ? ps.x : 0), y = p.at[1] + (ps ? ps.y : 0);
    const sx = ps ? ps.sx : 1, sy = ps ? ps.sy : 1;
    const parent = p.parent ? M[p.parent] : ID;
    if (p.abs) { const w = ap(parent, x, y); M[p.name] = trs(w[0], w[1], r, sx, sy); }
    else M[p.name] = mul(parent, trs(x, y, r, sx, sy));
  }
  return M;
}

// ---------------------------------------------------------------------------
// 굽는 화가: 띠 워프 + 경계 추적
// ---------------------------------------------------------------------------
const TMP = 900, TOX = 450, TOY = 640;
class FramePainter {
  constructor() {
    this.cv = makeCanvas(TMP, TMP);
    this.g = this.cv.getContext('2d', { willReadFrequently: true });
  }
  begin(k, seed) {
    const g = this.g;
    g.setTransform(1, 0, 0, 1, 0, 0);
    g.clearRect(0, 0, TMP, TMP);
    this.k = k;
    this.base = [k, 0, 0, k, TOX, TOY];
    this.bb = [Infinity, Infinity, -Infinity, -Infinity];
    this.R = rng(seed);
    g.imageSmoothingEnabled = true;
  }
  _grow(m, x0, y0, x1, y1) {
    const b = this.bb;
    for (const [x, y] of [[x0, y0], [x1, y0], [x0, y1], [x1, y1]]) {
      const X = m[0] * x + m[2] * y + m[4], Y = m[1] * x + m[3] * y + m[5];
      if (X < b[0]) b[0] = X; if (Y < b[1]) b[1] = Y; if (X > b[2]) b[2] = X; if (Y > b[3]) b[3] = Y;
    }
  }
  /** 단단한 그림(머리, 소품): 포즈 행렬 m(포즈 px) */
  rigid(img, ox, oy, m, jitter = 0.6) {
    const j = jitter ? [(this.R() - 0.5) * jitter, (this.R() - 0.5) * jitter] : [0, 0];
    const f = mul(this.base, [m[0], m[1], m[2], m[3], m[4] + j[0], m[5] + j[1]]);
    this.g.setTransform(f[0], f[1], f[2], f[3], f[4], f[5]);
    this.g.drawImage(cpu(img), ox, oy);
    this._grow(f, ox, oy, ox + img.width, oy + img.height);
  }
  /**
   * 띠 워프: 이미지의 +y축을 path(s) 곡선에 실어 가로 띠마다 따로 놓는다.
   * path(s) → [x, y, r, sx] (포즈 px; r = 이미지 +y가 향할 회전)
   */
  warp(img, ox, oy, path, step = 5, jitter = 0.5) {
    const g = this.g, h = img.height, w = img.width;
    const jx = (this.R() - 0.5) * jitter, jy = (this.R() - 0.5) * jitter;
    for (let y = 0; y < h; y += step) {
      const sh = Math.min(step + 1.2, h - y);
      const s = oy + y;
      const [px, py, r, sx] = path(s + step * 0.5);
      const c = Math.cos(r), sn = Math.sin(r);
      // 띠 가운데가 곡선 위 점에 오게
      const m = [c * sx, sn * sx, -sn, c, px + jx + sn * step * 0.5, py + jy - c * step * 0.5];
      const f = mul(this.base, m);
      g.setTransform(f[0], f[1], f[2], f[3], f[4], f[5]);
      g.drawImage(img, 0, y, w, sh, ox, 0, w, sh);
      this._grow(f, ox, 0, ox + w, sh);
    }
  }
  /** 세로 띠 워프(호랑이 몸통처럼 옆으로 긴 그림): 이미지 x축을 따라 */
  warpX(img, ox, oy, colFn, step = 6) {
    const g = this.g, w = img.width, h = img.height;
    for (let x = 0; x < w; x += step) {
      const sw = Math.min(step + 1.2, w - x);
      const m = colFn(ox + x + step * 0.5); // 이 기둥 가운데 기준 행렬(포즈 px)
      const f = mul(this.base, m);
      g.setTransform(f[0], f[1], f[2], f[3], f[4], f[5]);
      g.drawImage(img, x, 0, sw, h, -step * 0.5, oy, sw, h);
      this._grow(f, -step * 0.5, oy, -step * 0.5 + sw, oy + h);
    }
  }
  /** 번짐: 빠른 칼끝·앞발이 지나간 자리(앞 위치 곡선 a[] → 지금 곡선 b[])를 종이색으로 메우고 갈필 줄 */
  smear(a, b, color = '#ece6d6', streaks = 4) {
    const g = this.g;
    const pts = [...a, ...b.slice().reverse()];
    const f = this.base;
    g.setTransform(f[0], f[1], f[2], f[3], f[4], f[5]);
    g.beginPath();
    g.moveTo(pts[0][0], pts[0][1]);
    for (const p of pts) g.lineTo(p[0], p[1]);
    g.closePath();
    g.fillStyle = color;
    g.fill();
    g.lineCap = 'round';
    for (let i = 0; i < streaks; i++) {
      const t = (i + 0.5) / streaks;
      const p0 = lerp2(a[0], a[a.length - 1], t), p1 = lerp2(b[0], b[b.length - 1], t);
      g.strokeStyle = INK;
      g.lineWidth = (i === streaks - 1 ? 2.6 : 1.1) / this.k * 0.8;
      g.beginPath();
      g.moveTo(p0[0], p0[1]);
      g.quadraticCurveTo((p0[0] + p1[0]) / 2 + (this.R() - 0.5) * 4, (p0[1] + p1[1]) / 2, p1[0], p1[1]);
      g.stroke();
    }
    for (const p of pts) this._grow(f, p[0], p[1], p[0], p[1]);
  }
  /** 갈필 속도선(호랑이 도약) */
  streaks(lines, w = 2) {
    const g = this.g, f = this.base;
    g.setTransform(f[0], f[1], f[2], f[3], f[4], f[5]);
    g.lineCap = 'round';
    for (const [p0, p1] of lines) {
      g.strokeStyle = INK;
      g.lineWidth = w;
      g.beginPath(); g.moveTo(p0[0], p0[1]); g.lineTo(p1[0], p1[1]); g.stroke();
      g.strokeStyle = PAPER;
      g.lineWidth = w * 0.35;
      g.beginPath(); g.moveTo(p0[0] + (p1[0] - p0[0]) * 0.4, p0[1] + 0.3); g.lineTo(p1[0], p1[1] + 0.3); g.stroke();
      this._grow(f, Math.min(p0[0], p1[0]) - w, Math.min(p0[1], p1[1]) - w, Math.max(p0[0], p1[0]) + w, Math.max(p0[1], p1[1]) + w);
    }
  }
  /** 가는 끈(삿갓 턱끈 끝자락) */
  line(pts, w, color = INK) {
    const g = this.g, f = this.base;
    g.setTransform(f[0], f[1], f[2], f[3], f[4], f[5]);
    g.strokeStyle = color; g.lineWidth = w; g.lineCap = 'round';
    g.beginPath(); g.moveTo(pts[0][0], pts[0][1]);
    for (let i = 1; i < pts.length; i++) g.lineTo(pts[i][0], pts[i][1]);
    g.stroke();
    for (const p of pts) this._grow(f, p[0] - w, p[1] - w, p[0] + w, p[1] + w);
  }
}
/** 그려진 픽셀(알파>0.4)만 감싸도록 경계를 줄인다 */
function tightBox(g, x0, y0, x1, y1) {
  const w = x1 - x0, h = y1 - y0;
  if (w <= 0 || h <= 0) return [x0, y0, x0 + 1, y0 + 1];
  g.setTransform(1, 0, 0, 1, 0, 0);
  const d = g.getImageData(x0, y0, w, h).data;
  let a = w, bb = h, c = -1, e = -1;
  for (let y = 0; y < h; y++) {
    const row = y * w * 4;
    for (let x = 0; x < w; x++) {
      if (d[row + x * 4 + 3] > 100) { if (x < a) a = x; if (x > c) c = x; if (y < bb) bb = y; e = y; }
    }
  }
  if (c < 0) return [x0, y0, x0 + 1, y0 + 1];
  return [x0 + a, y0 + bb, x0 + c + 1, y0 + e + 1];
}
const lerp2 = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];

// ---------------------------------------------------------------------------
// 곧게 이은 팔·다리·꼬리 그림(곡선 워프의 원본)
// ---------------------------------------------------------------------------
/** 굽기는 CPU 캔버스끼리(그리기마다 GPU↔CPU 왕복을 피함) */
const _cpu = new WeakMap();
function cpu(img) {
  let c = _cpu.get(img);
  if (!c) {
    c = makeCanvas(img.width, img.height);
    c.getContext('2d', { willReadFrequently: true }).drawImage(img, 0, 0);
    _cpu.set(img, c);
  }
  return c;
}
/** 세 점(시작·관절·끝)을 지나는 2차 곡선을 따라가는 경로. L1·L2: 이미지 기준 관절·끝 거리 */
function limbPath(A, B, C, L1, L2, sxv = 1) {
  const Q = [2 * B[0] - (A[0] + C[0]) / 2, 2 * B[1] - (A[1] + C[1]) / 2];
  const L = L1 + L2;
  const at = (t) => {
    const u = 1 - t;
    return [u * u * A[0] + 2 * u * t * Q[0] + t * t * C[0], u * u * A[1] + 2 * u * t * Q[1] + t * t * C[1]];
  };
  const tan = (t) => [2 * (1 - t) * (Q[0] - A[0]) + 2 * t * (C[0] - Q[0]), 2 * (1 - t) * (Q[1] - A[1]) + 2 * t * (C[1] - Q[1])];
  // 관절이 이미지에서 L1 지점에 오도록 s→t를 두 구간 선형으로
  const tOf = (s) => (s <= L1 ? 0.5 * s / L1 : 0.5 + 0.5 * (s - L1) / L2);
  return (s) => {
    let t = tOf(s), p, d;
    if (t < 0) { d = tan(0); const l = Math.hypot(d[0], d[1]) || 1; p = [A[0] + (d[0] / l) * s, A[1] + (d[1] / l) * s]; }
    else if (t > 1) { d = tan(1); const l = Math.hypot(d[0], d[1]) || 1; const ex = s - L; p = [C[0] + d[0] / l * ex, C[1] + d[1] / l * ex]; }
    else { p = at(t); d = tan(t); }
    return [p[0], p[1], Math.atan2(-d[0], d[1]), sxv];
  };
}

/** 점 목록(관절 사슬)을 지나는 캣멀롬 스플라인 경로 — 꼬리 */
function chainPath(pts, lens) {
  const cum = [0];
  for (const l of lens) cum.push(cum[cum.length - 1] + l);
  const n = pts.length;
  const P = (i) => pts[Math.max(0, Math.min(n - 1, i))];
  return (s) => {
    let i = 0;
    while (i < n - 2 && s > cum[i + 1]) i++;
    const seg = Math.max(1e-3, cum[i + 1] - cum[i]);
    const t = Math.max(-0.5, Math.min(1.5, (s - cum[i]) / seg));
    const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2);
    const f = (k, tt) => 0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * tt + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * tt * tt + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * tt * tt * tt);
    const df = (k, tt) => 0.5 * ((-p0[k] + p2[k]) + 2 * (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * tt + 3 * (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * tt * tt);
    const x = f(0, t), y = f(1, t), dx = df(0, t), dy = df(1, t);
    return [x, y, Math.atan2(-dx, dy), 1];
  };
}

// ---------------------------------------------------------------------------
// 종류별 프레임 은행
// ---------------------------------------------------------------------------

export const clipKey = (view, anim, armed, disg) => `${view}|${anim}${armed ? ':a' : ''}${disg ? ':d' : ''}`;

/** 로딩 중에 미리 굽는 동작(전투 + 이야기에 꼭 필요한 것). 나머지는 처음 쓰일 때 */
export function criticalKeys(kind) {
  const views = ['side', 'front', 'back'];
  const list = kind === 'player'
    ? ['idle', 'walk', 'run', 'idle:a', 'walk:a', 'run:a', 'attack1', 'attack2', 'attack3', 'dodge', 'guard', 'charge', 'heavy', 'hit', 'down', 'getup', 'dead', 'bow_draw', 'bow_shoot', 'throw']
    : ['idle', 'walk', 'prowl', 'crouch', 'pounce', 'land', 'swipe', 'roar', 'hit', 'stagger', 'eat', 'dead', 'retreat'];
  return expandKeys(kind, list);
}
/** 변장 장면(밤 외딴집)에 쓰는 것: setVariant('disguised') 때 뒤에서 굽는다 */
export const DISGUISE_ANIMS = ['idle:d', 'walk:d', 'knock:d', 'sniff:d', 'climb_try:d', 'slip:d', 'retreat:d', 'eat:d'];
export function expandKeys(kind, list) {
  const views = ['side', 'front', 'back'];
  const out = [];
  for (const a of list) for (const v of views) {
    const [anim] = a.split(':');
    const k = resolveView(kind, v, anim) + '|' + a;
    if (!out.includes(k)) out.push(k);
  }
  return out;
}

export class BakeBank {
  constructor(kind, tier = 'high') {
    this.tier = tier;
    this.kind = kind;
    this.rig = getRig(kind);
    this.human = this.rig.type === 'human';
    this.ppmS = this.rig.ppm / this.rig.scale;      // 포즈 px → (배율 적용) m
    this.fppm = TIERS[tier][kind];
    this.k = this.fppm / this.ppmS;                 // 포즈 px → 프레임 px
    this.sigs = new Map();      // 같은 그림 재사용(정지·반복 구간)
    this.pages = [];
    this.clips = new Map();     // key → {spec, frames[], done}
    this.queue = [];
    this.bakeMs = 0;
    this.frameCount = 0;
    this.limbCache = new Map();
    this.fp = null;
  }

  /** 클립 만들기(아직 안 구움) */
  clip(key) {
    let c = this.clips.get(key);
    if (c) return c;
    const [view, rest] = key.split('|');
    const [anim, ...flags] = rest.split(':');
    const spec = clipSpec(this.rig, anim);
    if (!spec) return null;
    c = { key, view, anim, armed: flags.includes('a'), variant: flags.includes('d') ? 'disguised' : 'normal', spec, frames: [], done: false };
    this.clips.set(key, c);
    return c;
  }
  /** 한 장 굽기(메인 스레드 조각 굽기용). 끝나면 true */
  step(c) {
    const t0 = performance.now();
    if (!c.done) this._bakeNext(c);
    this.bakeMs += performance.now() - t0;
    return c.done;
  }
  /** 클립 전체 굽기 → { frames, touched(페이지 번호들) } */
  bakeClip(key) {
    const c = this.clip(key);
    if (!c) return null;
    const before = new Set();
    const t0 = performance.now();
    this._touched = new Set();
    while (!c.done) this._bakeNext(c);
    this.bakeMs += performance.now() - t0;
    return { key, spec: c.spec, frames: c.frames, touched: [...this._touched] };
  }
  stats() {
    return { tier: this.tier, pxPerM: this.fppm, frames: this.frameCount, unique: this.uniqueCount || 0, pages: this.pages.length, mb: +(this.pages.length * PAGE * PAGE * 4 / 1048576).toFixed(1), bakeMs: Math.round(this.bakeMs), fill: +((this.usedPx || 0) / Math.max(1, this.pages.length * PAGE * PAGE)).toFixed(2) };
  }

  // ---- 페이지 채우기 ----
  _alloc(w, h) {
    w += MARGIN * 2; h += MARGIN * 2;
    // 여러 줄(shelf) 중 높이가 맞고 자리가 남는 줄에 넣는다(최적 맞춤). 없으면 새 줄, 그래도 없으면 새 페이지.
    const tryPage = (p) => {
      let best = null;
      for (const row of p.rows) {
        if (row.h >= h && row.x + w <= PAGE && (!best || row.h < best.h)) best = row;
      }
      if (best && best.h <= h * 1.35) return best;
      if (p.nextY + h <= PAGE) { const row = { y: p.nextY, h, x: 0 }; p.rows.push(row); p.nextY += h; return row; }
      return best;
    };
    let p = null, row = null;
    for (const pg of this.pages) { row = tryPage(pg); if (row) { p = pg; break; } }
    if (!row) {
      const cv = makeCanvas(PAGE, PAGE);
      p = { cv, g: cv.getContext('2d', { willReadFrequently: true }), rows: [], nextY: 0, index: this.pages.length };
      this.pages.push(p);
      row = tryPage(p);
    }
    const r = { page: p, x: row.x, y: row.y, w, h };
    row.x += w;
    this.usedPx = (this.usedPx || 0) + w * h;
    return r;
  }

  // ---- 클립 굽기 ----
  _bakeNext(c) {
    if (!c.sim) c.sim = this._simulate(c);
    const i = c.frames.length;
    const s = c.sim[i];
    const fr = this._drawFrame(c, s, i);
    c.frames.push(fr);
    this.frameCount++;
    if (c.frames.length >= c.sim.length) { c.done = true; c.sim = null; }
  }

  /** 클립 전체 자세(스프링 뒤따름 포함)를 미리 계산 */
  _simulate(c) {
    const rig = this.rig, spec = c.spec, anim = c.anim;
    const springs = BODY_SPRINGS[rig.type];
    const st = {};
    const out = [];
    const poseAt = (time, phase) => rig.pose(c.view, anim, time, rig, Math.min(time, rig.anims[anim].dur), { armed: c.armed, phase });
    const dtOf = (i) => (i === 0 ? 0 : (spec.kind === 'phase' ? this._cycleTime(anim) / spec.n : spec.times[i] - spec.times[i - 1]));
    const springStep = (P, dt) => {
      for (const n in springs) {
        if (COMBAT_H.has(anim) && (n === 'arm1_l' || n === 'arm2_l')) continue;
        const [K, C] = springs[n];
        const p = P[n] || (P[n] = { r: 0, x: 0, y: 0, sx: 1, sy: 1 });
        let s = st[n];
        if (!s) s = st[n] = { x: p.r, v: 0 };
        const steps = Math.ceil(dt / (1 / 60));
        for (let k = 0; k < steps; k++) { const h = dt / steps; s.v += (K * (p.r - s.x) - C * s.v) * h; s.x += s.v * h; }
        p.r = s.x;
      }
    };
    const n = spec.times.length;
    // 반복 동작은 한 바퀴 미리 돌려 스프링을 길들인다
    const warm = spec.kind === 'once' ? 0 : n;
    for (let j = 0; j < warm + n; j++) {
      const i = j % n;
      const time = spec.kind === 'phase' ? (j * this._cycleTime(anim)) / n : spec.times[i];
      const phase = spec.kind === 'phase' ? spec.times[i] : undefined;
      const P = poseAt(time, phase);
      springStep(P, j === 0 ? 0 : spec.kind === 'once' ? dtOf(i) : Math.max(1 / 60, dtOf(i) || spec.step || 1 / 12));
      if (j >= warm) {
        // 번짐용: 직전 순간(1/30초 전) 자세
        const tPrev = spec.kind === 'phase' ? time - 1 / 30 : Math.max(0, time - 1 / 30);
        const Pp = poseAt(tPrev, phase != null ? phase - (1 / 30) / this._cycleTime(anim) : undefined);
        out.push({ P, Pp, time, phase });
      }
    }
    return out;
  }
  _cycleTime(anim) {
    const sp = this.rig.type === 'tiger' ? (anim === 'run' ? 5 : anim === 'prowl' ? 1.1 : 1.7) : anim === 'run' ? 4.6 : 2.2;
    return strideOf(this.rig, anim) / sp;
  }

  /** 이음매 없는 팔다리(좌우 반전이 필요한 부위는 뒤집은 사본) */
  _limb(view, name) {
    const key = view + '|' + name;
    let e = this.limbCache.get(key);
    if (!e) {
      const f = frameLimb(this.rig, view, name);
      let img = cpu(f.img), ox = f.ox;
      if (f.flip) {
        const c = makeCanvas(img.width, img.height);
        const g = c.getContext('2d', { willReadFrequently: true });
        g.translate(img.width, 0); g.scale(-1, 1); g.drawImage(img, 0, 0);
        img = c; ox = -(f.ox + f.img.width);
      }
      e = { img, ox, oy: f.oy, L1: f.L1, L2: f.L2 };
      this.limbCache.set(key, e);
    }
    return e;
  }
  _tail(view, parts) {
    const key = view + '|tail';
    let e = this.limbCache.get(key);
    if (!e) {
      const f = frameLimb(this.rig, view, 'tail');
      const lens = ['tail1', 'tail2', 'tail3'].map((n) => parts.find((p) => p.name === n).at[1]);
      lens.push(160 - lens.reduce((a, b) => a + b, 0));
      e = { img: cpu(f.img), ox: f.ox, oy: f.oy, lens };
      this.limbCache.set(key, e);
    }
    return e;
  }

  _sig(c, s) {
    const q = (v) => Math.round(v * 200) / 200;
    let out = c.view + c.variant + (c.armed ? 'a' : '') + c.anim.length;
    for (const P of [s.P, FAST_ALL.has(c.anim) ? s.Pp : null]) {
      if (!P) continue;
      for (const n of Object.keys(P).sort()) { const p = P[n]; out += n + q(p.r) + ',' + q(p.x) + ',' + q(p.y) + ',' + q(p.sx) + ',' + q(p.sy) + ',' + (p.a == null ? 1 : q(p.a)) + ';'; }
    }
    return out;
  }
  _drawFrame(c, s, idx) {
    const cs = c.spec.kind === 'once' ? TIERS[this.tier].once : 1;
    this.kc = this.k * cs; this.fppmc = this.fppm * cs;
    const sig = this._sig(c, s) + '@' + cs;
    const dup = this.sigs.get(sig);
    if (dup) return dup;   // 같은 그림은 한 번만(정지·반복 구간, 시작·끝 자세)
    this.uniqueCount = (this.uniqueCount || 0) + 1;
    if (!this.fp) this.fp = new FramePainter();
    const fp = this.fp;
    fp.begin(this.kc, (idx + 1) * 7919 + c.key.length * 131);
    if (this.human) this._drawHuman(fp, c, s);
    else this._drawTiger(fp, c, s);
    // 그린 영역 잘라 페이지에 싣기
    const b = fp.bb;
    let x0 = Math.max(0, Math.floor(b[0]) - 1), y0 = Math.max(0, Math.floor(b[1]) - 1);
    let x1 = Math.min(TMP, Math.ceil(b[2]) + 1), y1 = Math.min(TMP, Math.ceil(b[3]) + 1);
    [x0, y0, x1, y1] = tightBox(fp.g, x0, y0, x1, y1);
    const w = Math.max(1, x1 - x0), h = Math.max(1, y1 - y0);
    const r = this._alloc(w, h);
    r.page.g.drawImage(fp.cv, x0, y0, w, h, r.x + MARGIN, r.y + MARGIN, w, h);
    if (this._touched) this._touched.add(r.page.index);
    const inv = 1 / this.fppmc;
    // 사각형(여백 포함) — 발 중심 기준 m, y는 위가 +
    const fx0 = (x0 - MARGIN - TOX) * inv, fx1 = (x1 + MARGIN - TOX) * inv;
    const fy0 = -(y1 + MARGIN - TOY) * inv, fy1 = -(y0 - MARGIN - TOY) * inv;
    const P = s.P;
    const meta = {
      page: r.page.index,
      u0: r.x / PAGE, v0: r.y / PAGE, u1: (r.x + r.w) / PAGE, v1: (r.y + r.h) / PAGE,
      x0: fx0, x1: fx1, y0: fy0, y1: fy1,
      lift: Math.max(0, -(P.root ? P.root.y : 0)) / this.ppmS,
    };
    this.sigs.set(sig, meta);
    return meta;
  }

  // ---- 사람 ----
  _drawHuman(fp, c, s) {
    const rig = this.rig, sp = rig.spec, S = rig.S, view = c.view;
    const parts = rig.views[view];
    const P = s.P, M = computeMats(parts, P), Mp = computeMats(parts, s.Pp);
    const anim = c.anim;
    const armed = c.armed || COMBAT_H.has(anim);
    const bowAnim = anim === 'bow_draw' || anim === 'bow_shoot';
    const vis = { staff: !armed, sword: armed && !bowAnim && anim !== 'throw', backbow: !bowAnim && (armed || sp.back === 'bow'), disg: false };
    const byName = Object.fromEntries(parts.map((p) => [p.name, p]));
    const skip = new Set(['arm1_l', 'arm2_l', 'leg1_l', 'leg2_l', 'head_blink']);
    const side = view === 'side';
    for (const p of parts.draw) {
      if (skip.has(p.name)) continue;
      const ps = P[p.name];
      if (p.tag === 'fx' || p.tag === 'alt') { if (!ps || !(ps.a > 0.5)) continue; }
      else if (p.tag && vis[p.tag] === false) continue;
      else if (ps && ps.a != null && ps.a < 0.5) continue;
      const m = M[p.name];
      if (p.name === 'arm1' || p.name === 'arm2' || p.name === 'leg1' || p.name === 'leg2') {
        const leg = p.name.startsWith('leg');
        const lo = byName[p.name + '_l'];
        const e = this._limb(view, p.name);
        const L2 = leg ? S.shin : S.lArm;
        const A = ap(m, 0, 0), B = ap(M[lo.name], 0, 0), C = ap(M[lo.name], 0, L2);
        fp.warp(e.img, e.ox, e.oy, limbPath(A, B, C, e.L1, e.L2), 6, 0.6);
        continue;
      }
      if (p.name === 'torso') {
        this._warpTorso(fp, { ...p, img: cpu(p.img) }, M, S);
        continue;
      }
      if (p.name === 'skirt') {
        this._warpSkirt(fp, { ...p, img: cpu(p.img) }, M, P, S, side);
        continue;
      }
      if (p.name === 'sword') {
        this._swordSmear(fp, M, Mp);
        fp.rigid(p.img, p.ox, p.oy, m, 0.3);
        continue;
      }
      if (p.name === 'head') {
        // 머리: 위아래로 빨리 움직이면 살짝 눌리고 늘어남
        const hy = ap(M.head, 0, 0)[1] - ap(Mp.head, 0, 0)[1];
        const q = Math.max(-0.07, Math.min(0.07, hy * 0.012));
        const sq = mul(m, trs(0, 0, 0, 1 + q * 0.6, 1 - q));
        fp.rigid(p.img, p.ox, p.oy, sq, 0.5);
        if (sp.hat === 'satgat' && view !== 'back') this._hatString(fp, M, Mp, S, side);
        continue;
      }
      fp.rigid(p.img, p.ox, p.oy, m, 0.6);
    }
  }
  _warpTorso(fp, p, M, S) {
    // 엉덩이(뿌리 기울기) → 목(몸통 기울기)으로 이어지는 3차 곡선 척추
    const T = S.torso;
    const mR = M.root, mT = M.torso;
    const H = ap(mT, 0, 0), N = ap(mT, 0, -T);
    const aR = angOf(mR), aT = angOf(mT);
    const sxT = Math.hypot(mT[0], mT[1]);
    const L = Math.hypot(N[0] - H[0], N[1] - H[1]);
    const u0 = [Math.sin(aR) * L, -Math.cos(aR) * L], u1 = [Math.sin(aT) * L, -Math.cos(aT) * L];
    const herm = (t) => {
      const t2 = t * t, t3 = t2 * t;
      const h00 = 2 * t3 - 3 * t2 + 1, h10 = t3 - 2 * t2 + t, h01 = -2 * t3 + 3 * t2, h11 = t3 - t2;
      const d00 = 6 * t2 - 6 * t, d10 = 3 * t2 - 4 * t + 1, d01 = -6 * t2 + 6 * t, d11 = 3 * t2 - 2 * t;
      return [
        [h00 * H[0] + h10 * u0[0] + h01 * N[0] + h11 * u1[0], h00 * H[1] + h10 * u0[1] + h01 * N[1] + h11 * u1[1]],
        [d00 * H[0] + d10 * u0[0] + d01 * N[0] + d11 * u1[0], d00 * H[1] + d10 * u0[1] + d01 * N[1] + d11 * u1[1]],
      ];
    };
    fp.warp(p.img, p.ox, p.oy, (y) => {
      const t = -y / T;
      if (t <= 0 || t >= 1) {
        const [pt, d] = herm(t <= 0 ? 0 : 1);
        const l = Math.hypot(d[0], d[1]) || 1, ex = t <= 0 ? -y : -y - T;
        const q = [pt[0] + (d[0] / l) * (t <= 0 ? ex : ex), pt[1] + (d[1] / l) * ex];
        return [q[0], q[1], Math.atan2(d[0], -d[1]), sxT];
      }
      const [pt, d] = herm(t);
      // 이미지 +y(아래)는 척추 진행 방향(위)의 반대
      return [pt[0], pt[1], Math.atan2(d[0], -d[1]), sxT];
    }, 6, 0.4);
  }
  _warpSkirt(fp, p, M, P, S, side) {
    const m = M.skirt;
    const len = p.oy + p.img.height;
    const kn1 = M.leg1_l ? ap(M.leg1_l, 0, 0) : null, kn2 = M.leg2_l ? ap(M.leg2_l, 0, 0) : null;
    const hip = ap(M.root, 0, 0);
    const spread = kn1 && kn2 ? Math.abs(kn1[0] - kn2[0]) : 0;
    // 앞으로 나간 무릎이 자락을 밀고(앞), 뒤로 끌림(스프링 각)이 끝단을 더 휘게
    const fwd = side && kn1 && kn2 ? (Math.min(kn1[0], kn2[0]) - hip[0]) : 0;
    const flare = 1 + Math.min(0.3, spread / 140);
    const drag = (P.skirt ? P.skirt.r : 0) * 30;
    const a = angOf(m);
    fp.warp(p.img, p.oy < 0 ? p.ox : p.ox, p.oy, (y) => {
      const f = Math.max(0, y / Math.max(1, len));
      const sh = (fwd * 0.22 * f) + drag * f * f;
      const q = ap(m, sh, y);
      return [q[0], q[1], a + drag * 0.002 * f, 1 + (flare - 1) * Math.pow(f, 1.5)];
    }, 7, 0.5);
  }
  _swordSmear(fp, M, Mp) {
    // 칼끝이 지나간 길: 칼날 끝 1/3만 엷게 메우고, 끝을 따라 붓끝이 빠지는 먹선 몇 가닥
    const L = 118 * this.rig.S.ws;
    const g0 = ap(M.sword, 0, L * 0.68), t0 = ap(M.sword, 0, L);
    const g1 = ap(Mp.sword, 0, L * 0.68), t1 = ap(Mp.sword, 0, L);
    if (Math.hypot(t0[0] - t1[0], t0[1] - t1[1]) < 26) return;
    fp.smear([g1, t1], [g0, t0], '#d9dcd5', 3);
  }
  _hatString(fp, M, Mp, S, side) {
    // 턱끈 끝자락이 머리 움직임을 늦게 따라 흔들림
    const hy = -(S.neck + S.headRY) - 4 * S.ws;
    const knot = ap(M.head, side ? -S.headRX * 0.3 : 0, hy + S.headRY + 2);
    const prev = ap(Mp.head, side ? -S.headRX * 0.3 : 0, hy + S.headRY + 2);
    const lagX = Math.max(-10, Math.min(10, (prev[0] - knot[0]) * 1.8));
    const lagY = Math.max(-4, Math.min(6, (prev[1] - knot[1]) * 1.2));
    for (const dx of [-2, 2]) fp.line([knot, [knot[0] + dx + lagX * 0.5, knot[1] + 7 + lagY * 0.5], [knot[0] + dx * 1.5 + lagX, knot[1] + 14 + lagY]], 1.2, '#5b4a35');
  }

  // ---- 호랑이 ----
  _drawTiger(fp, c, s) {
    const rig = this.rig, view = c.view, anim = c.anim;
    const parts = rig.views[view];
    const P = s.P, M = computeMats(parts, P), Mp = computeMats(parts, s.Pp);
    const byName = Object.fromEntries(parts.map((p) => [p.name, p]));
    const side = view === 'side';
    const u = c.spec.kind === 'once' ? s.time / c.spec.dur : 0;
    // 척추 휨: (+) 등이 솟음 / (−) 등이 꺼짐, ripple: 살금 걸음 물결, sag: 배 처짐
    let arch = 0, ripple = 0, sag = 0.02 * Math.sin((s.time / 2.6) * Math.PI * 2), stretch = 1;
    if (anim === 'crouch') { arch = -10; sag = 0.06; }
    else if (anim === 'prowl') { ripple = 4; arch = -4; sag = 0.03; }
    else if (anim === 'pounce') { const air = u > 0.15 && u < 0.85 ? Math.sin(((u - 0.15) / 0.7) * Math.PI) : 0; arch = u < 0.15 ? -12 : -8 * air; stretch = 1 + 0.08 * air; sag = -0.05 * air; }
    else if (anim === 'land') { arch = 8 * Math.sin(Math.min(1, u * 2) * Math.PI); sag = 0.08 * Math.sin(Math.min(1, u * 2) * Math.PI); }
    else if (anim === 'roar') arch = 6 * Math.sin(Math.min(1, u * 1.2) * Math.PI);
    else if (anim === 'swipe') arch = u < 0.6 ? 6 : -4;
    else if (anim === 'eat') { arch = 4; sag = 0.07; }
    else if (anim === 'walk' || anim === 'run') ripple = 2.5;
    const body = byName.body;
    const x0 = body.ox, x1 = body.ox + body.img.width;
    const ph = (s.phase || 0) * Math.PI * 2;
    const dyAt = (x) => {
      const n = (x - x0) / (x1 - x0);
      return -arch * Math.sin(Math.PI * n) + ripple * Math.sin(ph + n * 5);
    };
    const mR = M.root;
    // 다리·머리·꼬리 뿌리도 휜 등뼈를 따라 옮긴다
    const shiftUp = (name) => {
      const p = byName[name];
      if (!p || p.parent !== 'root' || !side) return;
      const dy = dyAt(p.at[0]) * (name.startsWith('head') ? 1 : 0.8);
      const off = [mR[2] * dy, mR[3] * dy];
      const ms = M[name];
      ms[4] += off[0]; ms[5] += off[1];
      // 자식 행렬도 다시
      for (const q of parts) if (q.parent === name) { const pm = M[name], ps = P[q.name]; const r = q.r0 + (ps ? ps.r : 0); M[q.name] = mul(pm, trs(q.at[0] + (ps ? ps.x : 0), q.at[1] + (ps ? ps.y : 0), r, ps ? ps.sx : 1, ps ? ps.sy : 1)); }
    };
    for (const n of ['front1', 'front2', 'hind1', 'hind2', 'head', 'head_roar', 'head_dead', 'tail0']) shiftUp(n);
    if (side && byName.tail0) {
      // 꼬리 사슬 다시 계산
      for (const n of ['tail1', 'tail2', 'tail3']) { const q = byName[n], ps = P[n]; M[n] = mul(M[q.parent], trs(q.at[0], q.at[1], q.r0 + (ps ? ps.r : 0))); }
    }
    const skip = new Set(['front1_l', 'front2_l', 'hind1_l', 'hind2_l', 'tail1', 'tail2', 'tail3']);
    let tailDrawn = false;
    for (const p of parts.draw) {
      if (skip.has(p.name)) continue;
      const ps = P[p.name];
      if (p.tag === 'fx' || p.tag === 'alt') { if (!ps || !(ps.a > 0.5)) continue; }
      else if (p.tag === 'disg' && c.variant !== 'disguised') continue;
      else if (ps && ps.a != null && ps.a < 0.5) continue;
      const m = M[p.name];
      if (p.name === 'body') {
        const aR = angOf(mR), sxR = Math.hypot(mR[0], mR[1]), syR = Math.hypot(mR[2], mR[3]);
        if (anim === 'pounce' && u > 0.15 && u < 0.85) {
          // 도약 속도선(엉덩이 뒤로)
          const tail = ap(mR, x1 + 6, -20), lines = [];
          for (let i = 0; i < 4; i++) lines.push([ap(mR, x1 - 20, -50 + i * 26), ap(mR, x1 + 60 + i * 12, -46 + i * 26)]);
          fp.streaks(lines, 2.4);
          void tail;
        }
        fp.warpX(cpu(p.img), p.ox, p.oy, (x) => {
          const dy = dyAt(x), dy2 = dyAt(x + 2) - dyAt(x - 2);
          const n = (x - x0) / (x1 - x0);
          const bell = Math.exp(-Math.pow((n - 0.45) / 0.22, 2));
          const syc = syR * (1 + sag * bell);
          const q = ap(mR, x * stretch, dy);
          const r = aR + Math.atan2(dy2, 4);
          const cc = Math.cos(r), sn = Math.sin(r);
          return [cc * sxR, sn * sxR, -sn * syc, cc * syc, q[0], q[1]];
        }, 8);
        continue;
      }
      if (/^(front|hind)[12]$/.test(p.name)) {
        const lo = byName[p.name + '_l'];
        if (!lo) { fp.rigid(p.img, p.ox, p.oy, m, 0.5); continue; }
        const e = this._limb(view, p.name);
        const L2 = e.L2;
        const A = ap(m, 0, 0), B = ap(M[lo.name], 0, 0), C = ap(M[lo.name], 0, L2);
        if (anim === 'swipe' && p.name === 'front2') {
          const Cp = ap(Mp[lo.name], 0, L2), Bp = ap(Mp[lo.name], 0, 0);
          if (Math.hypot(C[0] - Cp[0], C[1] - Cp[1]) > 22) fp.smear([Bp, Cp], [B, C], '#efe6d0', 3);
        }
        fp.warp(e.img, e.ox, e.oy, limbPath(A, B, C, e.L1, e.L2), 7, 0.6);
        continue;
      }
      if (p.name === 'tail0') {
        if (tailDrawn) continue;
        tailDrawn = true;
        const e = this._tail(view, parts);
        const pts = [ap(M.tail0, 0, 0), ap(M.tail1, 0, 0), ap(M.tail2, 0, 0), ap(M.tail3, 0, 0), ap(M.tail3, 0, e.lens[3])];
        fp.warp(e.img, e.ox, e.oy, chainPath(pts, e.lens), 7, 0.5);
        continue;
      }
      if (p.name.startsWith('head')) {
        const hy = ap(M[p.name], 0, 0)[1] - ap(Mp[p.name], 0, 0)[1];
        const q = Math.max(-0.08, Math.min(0.08, hy * 0.01));
        fp.rigid(p.img, p.ox, p.oy, mul(m, trs(0, 0, 0, 1 + q * 0.6, 1 - q)), 0.6);
        continue;
      }
      fp.rigid(p.img, p.ox, p.oy, m, 0.5);
    }
  }
}

