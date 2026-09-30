// 설화록 — 전투 애니메이션 (COMBAT.md §4.2)
// 키프레임: 각 부위 [r, x, y, sx, sy, a] (기본 자세 r0에 더하는 변화량; a=알파).
// 1회성은 u(0~1 진행도)로, 반복은 t(초)로 자세를 만든다.

const PI = Math.PI;
const { sin, cos, max, min, abs } = Math;
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const smooth = (k) => k * k * (3 - 2 * k);
const flip = (c) => (c < 0 ? -1 : 1) * max(0.3, abs(c));

/** 애니메이션 표: loop=true면 반복(dur은 한 주기 길이) */
export const HUMAN_ANIMS = {
  idle: { dur: 3.2, loop: true }, walk: { dur: 0.95, loop: true }, run: { dur: 0.6, loop: true }, talk: { dur: 1.1, loop: true },
  attack1: { dur: 0.32 }, attack2: { dur: 0.32 }, attack3: { dur: 0.45 },
  charge: { dur: 0.6, loop: true }, heavy: { dur: 0.6 }, guard: { dur: 1.2, loop: true },
  dodge: { dur: 0.45 }, bow_draw: { dur: 1.0, loop: true }, bow_shoot: { dur: 0.35 }, throw: { dur: 0.45 },
  hit: { dur: 0.35 }, down: { dur: 0.6 }, getup: { dur: 0.7 }, dead: { dur: 0.9 },
};
export const TIGER_ANIMS = {
  idle: { dur: 2.6, loop: true }, walk: { dur: 1.15, loop: true }, run: { dur: 0.7, loop: true },
  prowl: { dur: 1.5, loop: true }, crouch: { dur: 0.8, loop: true }, pounce: { dur: 0.6 }, land: { dur: 0.5 },
  swipe: { dur: 0.75 }, roar: { dur: 1.4 }, hit: { dur: 0.3 }, stagger: { dur: 0.8 }, eat: { dur: 1.0, loop: true }, dead: { dur: 1.0 },
};
export const COMBAT_HUMAN = new Set(['attack1', 'attack2', 'attack3', 'charge', 'heavy', 'guard', 'dodge', 'bow_draw', 'bow_shoot', 'throw', 'hit', 'down', 'getup', 'dead']);

// 기본값이 '숨김'인 부위(효과·교체용 이미지)
const HIDDEN = /^(fx_|head_|bow[RD]$|item$)/;

function kf(u, frames) {
  let i = 0;
  while (i < frames.length - 2 && u >= frames[i + 1][0]) i++;
  const [t0, A] = frames[i], [t1, B] = frames[min(i + 1, frames.length - 1)];
  const k = t1 > t0 ? smooth(clamp((u - t0) / (t1 - t0), 0, 1)) : 1;
  const P = {};
  const names = new Set([...Object.keys(A), ...Object.keys(B)]);
  for (const n of names) {
    const a = A[n], b = B[n], hid = HIDDEN.test(n);
    const g = (arr, j) => (arr && arr[j] != null ? arr[j] : j < 3 ? 0 : j < 5 ? 1 : hid ? 0 : 1);
    const v = (j) => g(a, j) + (g(b, j) - g(a, j)) * k;
    P[n] = { r: v(0), x: v(1), y: v(2), sx: v(3), sy: v(4), a: v(5) };
  }
  return P;
}
const add = (P, n, r = 0, x = 0, y = 0) => {
  const p = P[n] || (P[n] = { r: 0, x: 0, y: 0, sx: 1, sy: 1, a: HIDDEN.test(n) ? 0 : 1 });
  p.r += r; p.x += x; p.y += y;
};

// 뒷면 = 정면 자세의 좌우 반전 (팔다리 이름 교환, r·x 부호 반전, 비대칭 이미지는 sx 반전)
const SWAP = { arm1: 'arm2', arm2: 'arm1', arm1_l: 'arm2_l', arm2_l: 'arm1_l', leg1: 'leg2', leg2: 'leg1', leg1_l: 'leg2_l', leg2_l: 'leg1_l' };
function mirror(P) {
  const Q = {};
  for (const n in P) {
    const p = P[n];
    Q[SWAP[n] || n] = { r: -p.r, x: -p.x, y: p.y, sx: /^(fx_|bow)/.test(n) ? -p.sx : p.sx, sy: p.sy, a: p.a };
  }
  return Q;
}

// ---------------------------------------------------------------------------
// 사람
// ---------------------------------------------------------------------------
const STANCE = { leg2: [0.25], leg2_l: [-0.1], leg1: [-0.25], leg1_l: [-0.05] };
const LUNGE = { leg2: [0.5], leg2_l: [-0.25], leg1: [-0.45], leg1_l: [-0.15] };
const BIG = { leg2: [0.85], leg2_l: [-0.4], leg1: [-0.7], leg1_l: [-0.2] };
const FX = (n, r, x, y, sx, sy, a) => ({ [n]: [r, x, y, sx, sy, a] });

const S_CHARGE = { leg2: [0.4], leg2_l: [-0.35], leg1: [-0.45], leg1_l: [-0.2], arm2: [-0.9], arm2_l: [0.3], sword: [-0.5], arm1: [0.7], arm1_l: [0.5], torso: [-0.15], head: [0.12], root: [0, 0, 14] };
const F_CHARGE = { arm2: [-0.55], arm2_l: [-0.3], sword: [-0.5], arm1: [0.35], arm1_l: [-0.4], root: [0, 0, 12], leg1: [0.12, -3], leg2: [-0.12, 3], torso: [0, 0, 0, 1, 0.97], head: [0, 0, 3] };
const S_DRAWN = { ...STANCE, arm2: [1.5], arm2_l: [0], bowD: [0, 0, 0, 1, 1, 1], arm1: [1.35], arm1_l: [-3.0], torso: [0.02] };
const F_DRAWN = { arm2: [-1.5], arm2_l: [0], bowD: [0, 0, 0, -1, 1, 1], arm1: [-0.9], arm1_l: [-0.9], root: [0, 0, 4], torso: [-0.03] };
const DOWN_END = { root: [1.52, -10, 98], torso: [0.05], head: [0.15], arm2: [-2.6], arm2_l: [0.3], arm1: [-2.9], leg2: [-0.35], leg2_l: [0.7], leg1: [-0.1], leg1_l: [0.3] };

const SIDE = {
  attack1: [
    [0, { ...STANCE, arm2: [2.2], arm2_l: [0.2], sword: [0.2], arm1: [0.3], root: [0, 0, 6], torso: [0.04] }],
    [0.28, { ...STANCE, arm2: [2.9], arm2_l: [0.15], sword: [0.1], arm1: [0.2], root: [0, 2, 6], torso: [0.08] }],
    [0.5, { ...LUNGE, arm2: [0.55], arm2_l: [0.1], sword: [0.25], arm1: [-0.4], root: [0, -10, 10], torso: [-0.2], head: [0.1], ...FX('fx_slash', 0, 0, 0, 1, 1, 1) }],
    [1, { ...LUNGE, arm2: [0.7], arm2_l: [0.2], sword: [0.3], arm1: [-0.3], root: [0, -10, 10], torso: [-0.15], head: [0.08], ...FX('fx_slash', 0, 0, 0, 1, 1, 0) }],
  ],
  attack2: [
    [0, { ...LUNGE, arm2: [0.7], arm2_l: [0.2], sword: [0.3], root: [0, -10, 10], torso: [-0.15] }],
    [0.3, { ...STANCE, arm2: [-0.6], arm2_l: [0.3], sword: [0.4], root: [0, -2, 8], torso: [0.02], arm1: [0.5], ...FX('fx_slash', 0, 0, 0, 1, -1, 0) }],
    [0.55, { ...LUNGE, arm2: [2.5], arm2_l: [0.2], sword: [0.1], root: [0, -12, 4], torso: [-0.05], head: [-0.1], arm1: [-0.5], ...FX('fx_slash', 0, 0, 0, 1, -1, 1) }],
    [1, { ...LUNGE, arm2: [2.4], arm2_l: [0.25], sword: [0.15], root: [0, -12, 6], torso: [-0.08], arm1: [-0.4], ...FX('fx_slash', 0, 0, 0, 1, -1, 0) }],
  ],
  attack3: [
    [0, { ...LUNGE, arm2: [2.4], arm2_l: [0.25], sword: [0.15], root: [0, -12, 6], torso: [-0.08] }],
    [0.35, { ...STANCE, arm2: [-0.5], arm2_l: [1.9], sword: [-0.3], root: [0, 8, 8], torso: [0.12], arm1: [0.8], arm1_l: [0.4] }],
    [0.55, { ...BIG, arm2: [1.45], arm2_l: [-0.1], sword: [0.05], root: [0, -18, 16], torso: [-0.3], head: [0.15], arm1: [-0.9], ...FX('fx_streak', 0, 0, 0, 1, 1, 1) }],
    [1, { ...BIG, arm2: [1.45], arm2_l: [-0.1], sword: [0.05], root: [0, -18, 16], torso: [-0.28], head: [0.12], arm1: [-0.8], ...FX('fx_streak', 0, 0, 0, 1, 1, 0) }],
  ],
  heavy: [
    [0, S_CHARGE],
    [0.35, { ...STANCE, arm2: [-3.3], arm2_l: [0.1], sword: [0], torso: [0.15], head: [-0.1], root: [0, 4, 0], arm1: [-2.8], ...FX('fx_slash', 0, 0, 0, 1.15, 1.15, 0) }],
    [0.55, { ...BIG, arm2: [-5.6], arm2_l: [0.1], sword: [0.2], torso: [-0.35], head: [0.2], root: [0, -20, 20], arm1: [-5.5], ...FX('fx_slash', 0, 0, 0, 1.15, 1.15, 1) }],
    [1, { ...BIG, arm2: [-5.5], arm2_l: [0.15], sword: [0.25], torso: [-0.3], head: [0.15], root: [0, -20, 18], arm1: [-5.4], ...FX('fx_slash', 0, 0, 0, 1.15, 1.15, 0) }],
  ],
  charge: S_CHARGE,
  guard: { ...STANCE, root: [0, 3, 10], torso: [0.05], arm2: [0.9], arm2_l: [1.0], sword: [0.9], arm1: [1.0], arm1_l: [0.9], head: [0.05] },
  bow_draw: S_DRAWN,
  bow_shoot: [
    [0, S_DRAWN],
    [0.2, { ...STANCE, arm2: [1.5], arm2_l: [0.05], bowR: [0, 0, 0, 1, 1, 1], arm1: [1.0], arm1_l: [-3.4], torso: [0.05], ...FX('fx_streak', 0, -60, 0, 0.8, 0.6, 1) }],
    [1, { ...STANCE, arm2: [1.3], arm2_l: [0.1], bowR: [0, 0, 0, 1, 1, 1], arm1: [0.4], arm1_l: [-1.0], ...FX('fx_streak', 0, -60, 0, 0.8, 0.6, 0) }],
  ],
  throw: [
    [0, { ...STANCE, arm2: [0.3], item: [0, 0, 0, 1, 1, 1] }],
    [0.4, { ...STANCE, arm2: [-2.3], arm2_l: [0.6], torso: [0.12], root: [0, 4, 4], arm1: [0.8], item: [0, 0, 0, 1, 1, 1] }],
    [0.6, { ...LUNGE, arm2: [2.2], arm2_l: [0.1], torso: [-0.15], root: [0, -6, 6], arm1: [-0.5], item: [0, 0, 0, 1, 1, 0] }],
    [1, { ...LUNGE, arm2: [1.6], arm2_l: [0.2], torso: [-0.1], root: [0, -6, 6], arm1: [-0.3] }],
  ],
  hit: [
    [0, {}],
    [0.25, { torso: [0.35], head: [0.35], root: [0.08, 12, 6], arm2: [-0.8], arm2_l: [0.6], arm1: [-1.0], arm1_l: [0.5], leg2: [0.35], leg1: [-0.15], sword: [0.3] }],
    [1, { torso: [0.12], head: [0.1], root: [0.03, 6, 3], arm2: [-0.2], arm1: [-0.3], leg2: [0.2], leg1: [-0.1] }],
  ],
  down: [
    [0, {}],
    [0.3, { root: [0.7, 6, 30], torso: [0.15], head: [0.3], arm2: [-2.0], arm1: [-2.4], leg2: [0.9], leg2_l: [-0.4], leg1: [0.5] }],
    [0.7, { ...DOWN_END, root: [1.5, -10, 96] }],
    [0.85, { ...DOWN_END, root: [1.5, -10, 90] }],
    [1, DOWN_END],
  ],
  getup: [
    [0, DOWN_END],
    [0.4, { root: [0.35, -4, 62], torso: [-0.5], head: [0.2], leg2: [1.4], leg2_l: [-2.2], leg1: [1.2], leg1_l: [-2.0], arm2: [0.6], arm1: [-0.4] }],
    [0.7, { root: [0, 0, 26], torso: [-0.25], leg2: [0.9], leg2_l: [-1.6], leg1: [-0.4], leg1_l: [-1.3], arm2: [0.5] }],
    [1, {}],
  ],
  dead: [
    [0, {}],
    [0.35, { root: [-0.25, 0, 16], head: [0.35], torso: [-0.1], leg2: [0.5], leg2_l: [-1.0], leg1: [0.35], leg1_l: [-1.0], arm2: [0.2], arm1: [0.3] }],
    [0.8, { root: [-1.52, 14, 98], head: [0.2], torso: [0.05], arm2: [-0.4], arm2_l: [0.2], arm1: [-0.2], leg2: [0.2], leg1: [-0.1] }],
    [1, { root: [-1.5, 14, 100], head: [0.2], torso: [0.05], arm2: [-0.4], arm2_l: [0.2], arm1: [-0.2], leg2: [0.2], leg1: [-0.1] }],
  ],
};

const FRONT = {
  attack1: [
    [0, { arm2: [-2.3], arm2_l: [-0.2], sword: [0], arm1: [0.3], root: [0, 2, 4] }],
    [0.28, { arm2: [-2.8], arm2_l: [-0.3], sword: [0], arm1: [0.4], torso: [-0.05], ...FX('fx_slash', 0.35, 20, 0, -1, 1, 0) }],
    [0.5, { arm2: [0.75], arm2_l: [0.35], sword: [0.3], arm1: [-0.2], torso: [0.08], root: [0, -4, 8], head: [0.05], ...FX('fx_slash', 0.35, 20, 0, -1, 1, 1) }],
    [1, { arm2: [0.7], arm2_l: [0.35], sword: [0.3], arm1: [-0.15], torso: [0.06], root: [0, -4, 8], head: [0.04], ...FX('fx_slash', 0.35, 20, 0, -1, 1, 0) }],
  ],
  attack2: [
    [0, { arm2: [0.7], arm2_l: [0.35], sword: [0.3], root: [0, -4, 8] }],
    [0.3, { arm2: [0.95], arm2_l: [0.5], sword: [0.4], torso: [0.06], root: [0, -2, 8], arm1: [-0.3], ...FX('fx_slash', -0.35, 20, 0, -1, -1, 0) }],
    [0.55, { arm2: [-2.4], arm2_l: [-0.2], sword: [0], torso: [-0.08], root: [0, 4, 2], arm1: [0.5], head: [-0.05], ...FX('fx_slash', -0.35, 20, 0, -1, -1, 1) }],
    [1, { arm2: [-2.3], arm2_l: [-0.2], sword: [0], torso: [-0.06], root: [0, 4, 3], arm1: [0.4], ...FX('fx_slash', -0.35, 20, 0, -1, -1, 0) }],
  ],
  attack3: [
    [0, { arm2: [-2.3], arm2_l: [-0.2], root: [0, 4, 3] }],
    [0.35, { arm2: [-1.3], arm2_l: [-1.6], sword: [0], torso: [-0.06], root: [0, 3, 4], arm1: [0.5] }],
    [0.55, { arm2: [-0.25, 0, 0, 1, 0.75], arm2_l: [0.05, 0, 0, 1, 0.6], sword: [0.1, 0, 0, 1, 0.4], root: [0, -2, 14], torso: [0, 0, 0, 1.04, 0.95], head: [0, 0, 4], arm1: [0.6], ...FX('fx_burst', 0, 34, 40, 1, 1, 1) }],
    [1, { arm2: [-0.25, 0, 0, 1, 0.75], arm2_l: [0.05, 0, 0, 1, 0.6], sword: [0.1, 0, 0, 1, 0.4], root: [0, -2, 14], torso: [0, 0, 0, 1.04, 0.95], head: [0, 0, 4], arm1: [0.5], ...FX('fx_burst', 0, 34, 40, 1.2, 1.2, 0) }],
  ],
  heavy: [
    [0, F_CHARGE],
    [0.35, { arm2: [-2.9], arm2_l: [-0.4], arm1: [2.9], arm1_l: [0.4], sword: [0], root: [0, 0, -6], torso: [0, 0, 0, 1, 1.03], ...FX('fx_slash', 0.9, 0, 0, 1.2, 1.2, 0) }],
    [0.55, { arm2: [-0.35, 0, 0, 1, 0.85], arm2_l: [0.6, 0, 0, 1, 0.7], arm1: [0.35, 0, 0, 1, 0.85], arm1_l: [-0.6, 0, 0, 1, 0.7], sword: [0, 0, 0, 1, 0.5], root: [0, 0, 18], torso: [0, 0, 0, 1.05, 0.93], head: [0, 0, 6], ...FX('fx_slash', 0.9, 0, 0, 1.2, 1.2, 1), ...FX('fx_burst', 0, 0, 60, 1.3, 1.3, 1) }],
    [1, { arm2: [-0.35, 0, 0, 1, 0.85], arm2_l: [0.6, 0, 0, 1, 0.7], arm1: [0.35, 0, 0, 1, 0.85], arm1_l: [-0.6, 0, 0, 1, 0.7], sword: [0, 0, 0, 1, 0.5], root: [0, 0, 16], torso: [0, 0, 0, 1.04, 0.94], head: [0, 0, 5], ...FX('fx_slash', 0.9, 0, 0, 1.2, 1.2, 0), ...FX('fx_burst', 0, 0, 60, 1.5, 1.5, 0) }],
  ],
  charge: F_CHARGE,
  // 칼을 가슴 앞에 가로로 들어 막음
  guard: { arm2: [-0.45], arm2_l: [-1.35], sword: [3.4], arm1: [0.45], arm1_l: [1.35], root: [0, 0, 8], leg1: [0.1], leg2: [-0.1], head: [0, 0, 3] },
  bow_draw: F_DRAWN,
  bow_shoot: [
    [0, F_DRAWN],
    [0.2, { arm2: [-1.5], arm2_l: [0.05], bowR: [0, 0, 0, -1, 1, 1], arm1: [0.4], arm1_l: [0.6], ...FX('fx_burst', 0, 96, -30, 0.6, 0.6, 1) }],
    [1, { arm2: [-1.3], arm2_l: [0.1], bowR: [0, 0, 0, -1, 1, 1], arm1: [0.2], arm1_l: [0.2], ...FX('fx_burst', 0, 96, -30, 0.8, 0.8, 0) }],
  ],
  throw: [
    [0, { arm2: [-0.3], item: [0, 0, 0, 1, 1, 1] }],
    [0.4, { arm2: [-2.7], arm2_l: [-0.5], torso: [-0.06], root: [0, 2, 2], item: [0, 0, 0, 1, 1, 1] }],
    [0.6, { arm2: [-0.4, 0, 0, 1, 0.8], arm2_l: [0.3, 0, 0, 1, 0.7], torso: [0.06], root: [0, -2, 6], item: [0, 0, 0, 1, 1, 0] }],
    [1, { arm2: [-0.5], arm2_l: [0.2], root: [0, -2, 4] }],
  ],
  hit: [
    [0, {}],
    [0.25, { torso: [0.1, 0, 0, 1, 0.94], head: [0.3, 0, 4], root: [0.06, 6, 4], arm2: [-0.9], arm2_l: [-0.5], arm1: [0.9], arm1_l: [0.5], leg2: [-0.15] }],
    [1, { torso: [0.03], head: [0.1], root: [0.02, 2, 2], arm2: [-0.2], arm1: [0.2] }],
  ],
};
FRONT.down = SIDE.down; FRONT.getup = SIDE.getup; FRONT.dead = SIDE.dead;

/** 전투 애니메이션이면 자세를, 아니면 null */
export function humanCombatPose(view, anim, t, at, rig) {
  const info = HUMAN_ANIMS[anim];
  if (!info || !COMBAT_HUMAN.has(anim)) return null;
  const side = view === 'side';
  const tbl = side ? SIDE : FRONT;
  let P;
  if (anim === 'dodge') {
    const u = clamp(at / info.dur, 0, 1), b = sin(PI * u);
    if (side) {
      const f = (n, r) => [r * b];
      P = kf(0, [[0, {
        root: [-2 * PI * smooth(u), -6 * b, -34 * b], torso: f(0, -0.9), head: f(0, -0.3), skirt: f(0, 0.6),
        leg2: f(0, 1.5), leg2_l: f(0, -2.1), leg1: f(0, 1.3), leg1_l: f(0, -2.1),
        arm2: f(0, 1.1), arm2_l: f(0, 1.2), arm1: f(0, 1.1), arm1_l: f(0, 1.2), sword: [0.3],
      }]]);
    } else {
      // 종이 인형처럼 휙 뒤집히며 뛰어오름
      P = kf(0, [[0, {
        root: [0, 0, -30 * b, flip(cos(2 * PI * smooth(u))), 1 - 0.25 * b],
        arm2: [0.5 * b], arm2_l: [1.0 * b], arm1: [-0.5 * b], arm1_l: [-1.0 * b],
        leg1: [0, 0, -12 * b], leg2: [0, 0, -12 * b], leg1_l: [0, 0, 0, 1, 1 - 0.2 * b], leg2_l: [0, 0, 0, 1, 1 - 0.2 * b], head: [0, 0, 8 * b],
      }]]);
    }
  } else {
    const src = tbl[anim];
    if (Array.isArray(src)) {
      P = kf(clamp(at / info.dur, 0, 1), src);
    } else {
      // 반복 자세: 0.18초 동안 들어가며 잡음
      const u = clamp(at / 0.18, 0, 1);
      P = kf(u, [[0, anim.startsWith('bow') ? { bowR: [0, 0, 0, side ? 1 : -1, 1, 1] } : {}], [1, src]]);
      if (anim === 'charge') {
        // 힘을 모으며 부들부들
        add(P, 'root', 0, 1.6 * sin(t * 50), 0);
        add(P, 'torso', 0.012 * sin(t * 37));
        add(P, 'head', 0, 0.8 * sin(t * 43), 0);
      } else if (anim === 'guard') {
        add(P, 'root', 0, 0, 1.5 * sin(t * 3));
      } else if (anim === 'bow_draw') {
        add(P, side ? 'arm1_l' : 'arm1_l', 0.02 * sin(t * 30));
      }
    }
  }
  return view === 'back' ? mirror(P) : P;
}

// ---------------------------------------------------------------------------
// 호랑이
// ---------------------------------------------------------------------------
/** 머리 세 가지(평소/포효/쓰러짐)를 같은 변환으로 두고 하나만 보이게 */
const H = (r, x, y, mode = 'n') => ({
  head: [r, x, y, 1, 1, mode === 'n' ? 1 : 0],
  head_roar: [r, x, y, 1, 1, mode === 'roar' ? 1 : 0],
  head_dead: [r, x, y, 1, 1, mode === 'dead' ? 1 : 0],
});
const TAIL = (a, b, c, d) => ({ tail0: [a], tail1: [b], tail2: [c], tail3: [d] });
const STIFF = TAIL(0.98, 0.55, -1.05, -1.35); // 곧게 뻗은 꼬리

const T_CROUCH = { root: [-0.16, 3, 30], front1: [-0.55], front1_l: [0.95], front2: [-0.5], front2_l: [0.9], hind1: [0.3], hind1_l: [-0.5], hind2: [0.35], hind2_l: [-0.55], ...H(0.05, -8, 16), ...TAIL(0.55, 0.5, -0.7, -0.9) };
const TF_CROUCH = { root: [0, 0, 16, 1.04, 0.9], front1: [0.3], front1_l: [-0.35], front2: [-0.3], front2_l: [0.35], hind1: [0.1], hind2: [-0.1], ...H(0, 0, 14), ...TAIL(0.45, -0.2, -0.6, -0.9) };

const TS = {
  pounce: [
    [0, T_CROUCH],
    [0.15, { root: [0.18, -8, -6], front1: [1.0], front1_l: [0.3], front2: [1.1], front2_l: [0.3], hind1: [-0.9], hind1_l: [0.3], hind2: [-1.0], hind2_l: [0.3], ...H(0.1, -8, 0), ...STIFF }],
    [0.5, { root: [0.08, -14, -42, 1.12, 0.94], front1: [1.35], front1_l: [0.25], front2: [1.45], front2_l: [0.3], hind1: [-1.1], hind1_l: [0.2], hind2: [-1.2], hind2_l: [0.2], ...H(0.12, -12, -2), ...STIFF }],
    [0.85, { root: [-0.08, -10, -12], front1: [0.7], front1_l: [-0.2], front2: [0.8], front2_l: [-0.2], hind1: [-0.6], hind2: [-0.7], ...H(0, -10, 4), ...STIFF }],
    [1, { root: [-0.05, -8, -2], front1: [0.5], front2: [0.55], hind1: [-0.4], hind2: [-0.45], ...H(0, -8, 4), ...TAIL(0.8, 0.4, -0.8, -1.0) }],
  ],
  land: [
    [0, { root: [-0.05, -8, -2], front1: [0.5], front2: [0.55], hind1: [-0.4], hind2: [-0.45], ...H(0, -8, 4), ...TAIL(0.8, 0.4, -0.8, -1.0) }],
    [0.3, { root: [0.1, -4, 18], front1: [-0.35], front1_l: [0.75], front2: [-0.3], front2_l: [0.7], hind1: [0.5], hind1_l: [-0.7], hind2: [0.55], hind2_l: [-0.75], ...H(0.1, -4, 12), ...TAIL(0.4, 0.2, -0.3, -0.3) }],
    [1, { root: [0, 0, 2], ...H(0, 0, 0), ...TAIL(0.1, 0, 0, 0) }],
  ],
  swipe: [
    [0, { ...H(0, 0, 0) }],
    [0.45, { root: [0.3, 12, -8], front2: [3.0], front2_l: [1.1], front1: [0.35], hind1: [-0.3], hind1_l: [0.2], hind2: [-0.3], hind2_l: [0.2], ...H(-0.25, 4, -10, 'roar'), ...TAIL(0.3, 0.3, -0.3, -0.4) }],
    [0.55, { root: [0.32, 12, -9], front2: [3.1], front2_l: [1.2], front1: [0.35], hind1: [-0.3], hind1_l: [0.2], hind2: [-0.3], hind2_l: [0.2], ...H(-0.27, 4, -11, 'roar'), ...TAIL(0.3, 0.3, -0.3, -0.4), fx_claw: [0, -20, 0, 1.6, 1.6, 0] }],
    [0.68, { root: [-0.08, -14, 6], front2: [0.35], front2_l: [-0.4], front1: [-0.1], ...H(0.12, -12, 8, 'roar'), ...TAIL(0.6, 0.3, -0.6, -0.8), fx_claw: [0, -20, 0, 1.6, 1.6, 1] }],
    [1, { root: [-0.05, -10, 4], front2: [0.4], front2_l: [-0.2], ...H(0.08, -8, 6), ...TAIL(0.4, 0.2, -0.3, -0.4), fx_claw: [0, -20, 0, 1.7, 1.7, 0] }],
  ],
  roar: [
    [0, { ...H(0, 0, 0) }],
    [0.18, { root: [0.1, 0, -4], front1: [-0.15], front2: [-0.2], hind1: [0.1], hind2: [0.1], ...H(-0.35, 6, -18, 'roar'), ...TAIL(-0.3, -0.2, 0.2, 0.3) }],
    [0.85, { root: [0.1, 0, -4], front1: [-0.15], front2: [-0.2], hind1: [0.1], hind2: [0.1], ...H(-0.3, 6, -16, 'roar'), ...TAIL(-0.3, -0.2, 0.2, 0.3) }],
    [1, { ...H(0, 0, 0) }],
  ],
  hit: [
    [0, { ...H(0, 0, 0) }],
    [0.3, { root: [-0.08, 12, 2], ...H(0.25, 8, -4), ...TAIL(0.5, 0.3, -0.4, -0.5) }],
    [1, { root: [-0.03, 5, 0], ...H(0.1, 4, 0) }],
  ],
  dead: [
    [0, { ...H(0, 0, 0) }],
    [0.4, { root: [0.05, 0, 30], front1: [-0.6], front1_l: [1.0], front2: [-0.6], front2_l: [1.0], hind1: [0.6], hind1_l: [-1.0], hind2: [0.6], hind2_l: [-1.0], ...H(0.2, 0, 20) }],
    [0.75, { root: [0, 0, 64], front1: [1.1], front1_l: [0.1], front2: [1.3], front2_l: [0], hind1: [-1.0], hind1_l: [0.3], hind2: [-1.1], hind2_l: [0.3], ...H(0.35, -6, 58, 'dead'), ...STIFF }],
    [1, { root: [0, 0, 64], front1: [1.1], front1_l: [0.1], front2: [1.3], front2_l: [0], hind1: [-1.0], hind1_l: [0.3], hind2: [-1.1], hind2_l: [0.3], ...H(0.35, -6, 58, 'dead'), ...STIFF }],
  ],
};
const TF = {
  pounce: [
    [0, TF_CROUCH],
    [0.2, { root: [0, 0, -10, 1.06, 1.06], front1: [0.6], front2: [-0.6], ...H(0, 0, -2) }],
    [0.5, { root: [0, 0, -34, 1.16, 1.16], front1: [1.0], front1_l: [-0.6], front2: [-1.0], front2_l: [0.6], ...H(0, 0, -6) }],
    [1, { root: [0, 0, -6, 1.05, 1.05], front1: [0.3], front2: [-0.3], ...H(0, 0, 0) }],
  ],
  land: [
    [0, { root: [0, 0, -6, 1.05, 1.05], front1: [0.3], front2: [-0.3], ...H(0, 0, 0) }],
    [0.3, { root: [0, 0, 14, 1.08, 0.85], front1: [0.35], front2: [-0.35], ...H(0, 0, 10) }],
    [1, { ...H(0, 0, 0) }],
  ],
  swipe: [
    [0, { ...H(0, 0, 0) }],
    [0.45, { root: [-0.1, -4, -6, 1.04, 1.04], front2: [-2.0, 14, -8, 1.3, 1.3], front2_l: [-1.0], ...H(0.1, -4, -6, 'roar') }],
    [0.55, { root: [-0.11, -4, -7, 1.04, 1.04], front2: [-2.1, 14, -9, 1.3, 1.3], front2_l: [-1.1], ...H(0.11, -4, -7, 'roar'), fx_claw: [0, 0, 0, 1.5, 1.5, 0] }],
    [0.68, { root: [0.06, 4, 6], front2: [-0.4, 0, 0, 1, 0.8], front2_l: [0.3], ...H(-0.05, 4, 6, 'roar'), fx_claw: [0, 0, 0, 1.5, 1.5, 1] }],
    [1, { root: [0.04, 2, 4], front2: [-0.3], ...H(0, 2, 4), fx_claw: [0, 0, 0, 1.6, 1.6, 0] }],
  ],
  roar: [
    [0, { ...H(0, 0, 0) }],
    [0.18, { root: [0, 0, -6, 1.04, 1.06], front1: [0.15], front2: [-0.15], ...H(0, 0, -14, 'roar') }],
    [0.85, { root: [0, 0, -6, 1.04, 1.06], front1: [0.15], front2: [-0.15], ...H(0, 0, -12, 'roar') }],
    [1, { ...H(0, 0, 0) }],
  ],
  hit: [
    [0, { ...H(0, 0, 0) }],
    [0.3, { root: [0.06, 6, 2, 1, 0.95], ...H(-0.2, 4, 0) }],
    [1, { root: [0.02, 2, 0], ...H(-0.05, 1, 0) }],
  ],
  dead: [
    [0, { ...H(0, 0, 0) }],
    [0.4, { root: [0, 0, 24, 1, 0.9], front1: [0.3], front2: [-0.3], ...H(0.1, 0, 16) }],
    [0.8, { root: [1.45, -10, 40], front1: [0.6], front2: [0.3], ...H(0.2, 0, 10, 'dead') }],
    [1, { root: [1.45, -10, 42], front1: [0.6], front2: [0.3], ...H(0.2, 0, 10, 'dead') }],
  ],
};

export function tigerCombatPose(view, anim, t, at, st = {}) {
  const side = view === 'side';
  const info = TIGER_ANIMS[anim];
  if (!info) return null;
  const u = clamp(at / info.dur, 0, 1);
  if (anim === 'crouch') {
    const P = kf(clamp(at / 0.2, 0, 1), [[0, {}], [1, side ? T_CROUCH : TF_CROUCH]]);
    const q = sin(t * 7) * 0.5 + sin(t * 11) * 0.5;
    // 엉덩이 들썩 + 꼬리 끝만 파르르
    add(P, 'root', side ? 0.02 * q : 0, side ? 1.2 * q : 0, 0);
    add(P, 'tail3', 0.35 * sin(t * 10));
    return P;
  }
  if (anim === 'prowl') {
    const ph = (st.phase != null ? st.phase : t / info.dur) * PI * 2, s = sin(ph), c = cos(ph);
    if (side) {
      const A = 0.22;
      return kf(0, [[0, {
        front2: [-0.3 + A * s], front2_l: [0.5 - 0.5 * max(0, c)], front1: [-0.3 - A * s], front1_l: [0.5 - 0.5 * max(0, -c)],
        hind1: [0.25 + A * s], hind1_l: [-0.4 + 0.4 * max(0, c)], hind2: [0.25 - A * s], hind2_l: [-0.4 + 0.4 * max(0, -c)],
        root: [0.015 * s, 0, 16 - 2 * (1 - abs(s))], ...H(0.05, -10, 12 + sin(ph * 2)),
        ...TAIL(0.9, 0.1, -0.4, -0.3 + 0.3 * sin(t * 3)),
      }]]);
    }
    return kf(0, [[0, {
      front1: [0.04 * s, 0, -max(0, s) * 4], front2: [0.04 * s, 0, -max(0, -s) * 4], hind1: [0, 0, -max(0, -s) * 3], hind2: [0, 0, -max(0, s) * 3],
      root: [0.012 * s, 1.5 * s, 14, 1.03, 0.92], ...H(-0.02 * s, 0, 12 + sin(ph * 2)), ...TAIL(0.3, -0.1, -0.3, -0.2 + 0.3 * sin(t * 3)),
    }]]);
  }
  if (anim === 'eat') {
    const ch = sin(t * 9);
    if (side) return kf(0, [[0, { root: [-0.08, -4, 8], front2: [0.35], front2_l: [-0.1], front1: [-0.15], front1_l: [0.3], hind1: [0.1], hind2: [0.1], ...H(-0.2 + 0.06 * ch, -16, 70 + 3 * ch), ...TAIL(0.3 + 0.15 * sin(t * 1.2), 0.2, -0.2, -0.2 + 0.2 * sin(t * 1.5)) }]]);
    return kf(0, [[0, { root: [0, 0, 8, 1, 0.95], front1: [0.2], front2: [-0.2], ...H(0.04 * ch, 0, 52 + 3 * ch), ...TAIL(0.2 * sin(t * 1.2), 0, 0, 0) }]]);
  }
  if (anim === 'stagger') {
    const e = 1 - u;
    return kf(0, [[0, {
      root: [0.12 * sin(u * PI * 4) * e, 6 * sin(u * PI * 3) * e, 10 * e], front1: [-0.25 * e], front2: [0.2 * e], hind1: [0.25 * e], hind2: [-0.2 * e],
      ...H(0.25 * sin(u * PI * 3) * e, 0, 14 * e), ...TAIL(0.9 * e, 0.3 * e, -0.3 * e, -0.3 * e),
    }]]);
  }
  const src = (side ? TS : TF)[anim];
  if (!src) return null;
  const P = kf(u, src);
  if (anim === 'roar' && u > 0.15 && u < 0.85) {
    // 포효 중 머리 떨림
    for (const n of ['head', 'head_roar']) add(P, n, 0, 1.6 * sin(t * 60), 1.2 * sin(t * 47));
  }
  return P;
}
