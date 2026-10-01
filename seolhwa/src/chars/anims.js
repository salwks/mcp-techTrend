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
  // 3단계(이야기): 오누이 동작
  cower: { dur: 0.8, loop: true }, cry: { dur: 1.0, loop: true }, climb: { dur: 1.2 }, perch: { dur: 2.4, loop: true }, hug: { dur: 2.0, loop: true },
};
export const TIGER_ANIMS = {
  idle: { dur: 2.6, loop: true }, walk: { dur: 1.15, loop: true }, run: { dur: 0.7, loop: true },
  prowl: { dur: 1.5, loop: true }, crouch: { dur: 0.8, loop: true }, pounce: { dur: 0.6 }, land: { dur: 0.5 },
  swipe: { dur: 0.75 }, roar: { dur: 1.4 }, hit: { dur: 0.3 }, stagger: { dur: 0.8 }, eat: { dur: 1.0, loop: true }, dead: { dur: 1.0 },
  // 3단계(이야기)
  knock: { dur: 1.2, loop: true }, climb_try: { dur: 1.4 }, slip: { dur: 1.8 }, sniff: { dur: 1.6, loop: true }, retreat: { dur: 0.8, loop: true },
};
/** climb 한 번에 몸이 올라가는 높이(m, 배율 적용 후). 끝나면 이야기 쪽에서 캐릭터를 그만큼 올리고 perch로. */
export const CLIMB_RISE_M = 1.4;
export const COMBAT_HUMAN = new Set(['attack1', 'attack2', 'attack3', 'charge', 'heavy', 'guard', 'dodge', 'bow_draw', 'bow_shoot', 'throw', 'hit', 'down', 'getup', 'dead']);

// 기본값이 '숨김'인 부위(효과·교체용 이미지)
const HIDDEN = /^(fx_|head_|bow[RD]$|item$|front[12]_up$)/;

// 가감속 곡선: 구간이 끝나는 키프레임에 붙인다 ([t, 자세, 곡선])
const EASE = {
  io: (k) => (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2),
  in: (k) => k * k * k,
  out: (k) => 1 - Math.pow(1 - k, 3),
  snap: (k) => 1 - Math.pow(1 - k, 5),              // 번개처럼 빠르게 들어가 멈춤(베기)
  back: (k) => { const c = 1.9; return 1 + (c + 1) * Math.pow(k - 1, 3) + c * Math.pow(k - 1, 2); }, // 살짝 지나쳤다 돌아옴
  lin: (k) => k,
};
function kf(u, frames) {
  let i = 0;
  while (i < frames.length - 2 && u >= frames[i + 1][0]) i++;
  const [t0, A] = frames[i], [t1, B, ez] = frames[min(i + 1, frames.length - 1)];
  const k = t1 > t0 ? (EASE[ez] || EASE.io)(clamp((u - t0) / (t1 - t0), 0, 1)) : 1;
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
    // 예비 동작: 칼을 뒤로 더 끌어올리며 몸을 젖힘
    [0.3, { ...STANCE, arm2: [3.05], arm2_l: [0.25], sword: [0.25], arm1: [0.35], root: [0, 4, 8], torso: [0.12], head: [-0.05] }, 'out'],
    // 베기: 순식간에
    [0.46, { ...LUNGE, arm2: [0.4], arm2_l: [0.05], sword: [0.1], arm1: [-0.5], root: [0, -12, 11], torso: [-0.24], head: [0.12], skirt: [0.25], ...FX('fx_slash', 0, 0, 0, 1, 1, 1) }, 'snap'],
    // 뒤따름: 칼끝이 더 흘러가고 손목이 따라감
    [0.64, { ...LUNGE, arm2: [0.15], arm2_l: [0.2], sword: [0.5], arm1: [-0.55], root: [0, -13, 12], torso: [-0.27], head: [0.14], ...FX('fx_slash', 0, 0, 0, 1.05, 1.05, 1) }, 'out'],
    [1, { ...LUNGE, arm2: [0.6], arm2_l: [0.2], sword: [0.3], arm1: [-0.3], root: [0, -10, 10], torso: [-0.15], head: [0.08], ...FX('fx_slash', 0, 0, 0, 1.05, 1.05, 0) }, 'io'],
  ],
  attack2: [
    [0, { ...LUNGE, arm2: [0.7], arm2_l: [0.2], sword: [0.3], root: [0, -10, 10], torso: [-0.15] }],
    [0.3, { ...STANCE, arm2: [-0.75], arm2_l: [0.35], sword: [0.5], root: [0, 0, 11], torso: [0.06], arm1: [0.55], ...FX('fx_slash', 0, 0, 0, 1, -1, 0) }, 'out'],
    [0.48, { ...LUNGE, arm2: [2.6], arm2_l: [0.15], sword: [0.05], root: [0, -13, 3], torso: [-0.06], head: [-0.12], arm1: [-0.55], ...FX('fx_slash', 0, 0, 0, 1, -1, 1) }, 'snap'],
    [0.66, { ...LUNGE, arm2: [2.85], arm2_l: [0.05], sword: [-0.25], root: [0, -14, 2], torso: [-0.02], head: [-0.14], arm1: [-0.6], ...FX('fx_slash', 0, 0, 0, 1.05, -1.05, 1) }, 'out'],
    [1, { ...LUNGE, arm2: [2.4], arm2_l: [0.25], sword: [0.15], root: [0, -12, 6], torso: [-0.08], arm1: [-0.4], ...FX('fx_slash', 0, 0, 0, 1, -1, 0) }, 'io'],
  ],
  attack3: [
    [0, { ...LUNGE, arm2: [2.4], arm2_l: [0.25], sword: [0.15], root: [0, -12, 6], torso: [-0.08] }],
    // 칼을 허리로 당겨 몸을 웅크림(찌르기 예비)
    [0.38, { ...STANCE, arm2: [-0.55], arm2_l: [1.95], sword: [-0.3], root: [0, 10, 12, 1.03, 0.97], torso: [0.16], arm1: [0.85], arm1_l: [0.45] }, 'out'],
    [0.52, { ...BIG, arm2: [1.5], arm2_l: [-0.12], sword: [0.05], root: [0, -22, 16, 1.02, 0.98], torso: [-0.34], head: [0.18], arm1: [-1.0], skirt: [0.35], ...FX('fx_streak', 0, 0, 0, 1.1, 1, 1) }, 'snap'],
    [0.7, { ...BIG, arm2: [1.5], arm2_l: [-0.1], sword: [0.05], root: [0, -24, 17], torso: [-0.36], head: [0.2], arm1: [-1.05], ...FX('fx_streak', 0, -10, 0, 1.2, 1, 1) }, 'out'],
    [1, { ...BIG, arm2: [1.45], arm2_l: [-0.1], sword: [0.05], root: [0, -18, 16], torso: [-0.28], head: [0.12], arm1: [-0.8], ...FX('fx_streak', 0, 0, 0, 1, 1, 0) }, 'io'],
  ],
  heavy: [
    [0, S_CHARGE],
    // 크게 들어올림(느리게, 무게가 실림)
    [0.35, { ...STANCE, arm2: [-3.35], arm2_l: [0.1], sword: [0], torso: [0.18], head: [-0.12], root: [0, 6, -2, 0.97, 1.04], arm1: [-2.85], ...FX('fx_slash', 0, 0, 0, 1.2, 1.2, 0) }, 'out'],
    // 내리찍기
    [0.5, { ...BIG, arm2: [-5.65], arm2_l: [0.05], sword: [0.15], torso: [-0.38], head: [0.22], root: [0, -22, 22, 1.04, 0.95], arm1: [-5.55], skirt: [0.4], ...FX('fx_slash', 0, 0, 0, 1.2, 1.2, 1) }, 'snap'],
    [0.7, { ...BIG, arm2: [-5.85], arm2_l: [0.25], sword: [0.45], torso: [-0.42], head: [0.25], root: [0, -23, 24, 1.03, 0.96], arm1: [-5.7], ...FX('fx_slash', 0, 0, 0, 1.25, 1.25, 1) }, 'out'],
    [1, { ...BIG, arm2: [-5.5], arm2_l: [0.15], sword: [0.25], torso: [-0.3], head: [0.15], root: [0, -20, 18], arm1: [-5.4], ...FX('fx_slash', 0, 0, 0, 1.2, 1.2, 0) }, 'io'],
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
    [0.22, { torso: [0.38], head: [0.4], root: [0.08, 12, 6, 0.96, 1.03], arm2: [-0.85], arm2_l: [0.6], arm1: [-1.05], arm1_l: [0.5], leg2: [0.35], leg1: [-0.15], sword: [0.3], skirt: [-0.3] }, 'snap'],
    [1, { torso: [0.12], head: [0.1], root: [0.03, 6, 3], arm2: [-0.2], arm1: [-0.3], leg2: [0.2], leg1: [-0.1] }, 'back'],
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
      // 도움닫기 때 눌렸다가(squash) 굴며 늘어나고(stretch) 착지에서 다시 눌림
      const sq = 1 - 0.16 * Math.exp(-(((u - 0.04) / 0.07) ** 2)) - 0.14 * Math.exp(-(((u - 0.96) / 0.07) ** 2));
      P = kf(0, [[0, {
        root: [-2 * PI * EASE.io(u), -6 * b, -34 * b + (1 - sq) * 40, 2 - sq, sq + 0.06 * b], torso: f(0, -0.9), head: f(0, -0.3), skirt: f(0, 0.6),
        leg2: f(0, 1.5), leg2_l: f(0, -2.1), leg1: f(0, 1.3), leg1_l: f(0, -2.1),
        arm2: f(0, 1.1), arm2_l: f(0, 1.2), arm1: f(0, 1.1), arm1_l: f(0, 1.2), sword: [0.3],
      }]]);
    } else {
      // 종이 인형처럼 휙 뒤집히며 뛰어오름
      P = kf(0, [[0, {
        root: [0, 0, -30 * b, flip(cos(2 * PI * EASE.io(u))), (1 - 0.25 * b) * (1 - 0.14 * Math.exp(-(((u - 0.04) / 0.07) ** 2)) - 0.12 * Math.exp(-(((u - 0.96) / 0.07) ** 2)))],
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
    // 도약 직전: 더 낮게 눌림(예비 동작)
    [0.08, { ...T_CROUCH, root: [-0.18, 6, 34, 1.06, 0.9] }, 'out'],
    // 박차고 오름: 몸이 쭉 늘어남 — 여기(15%)부터 공중
    [0.15, { root: [0.2, -10, -8, 1.1, 0.92], front1: [1.0], front1_l: [0.3], front2: [1.1], front2_l: [0.3], hind1: [-0.95], hind1_l: [0.3], hind2: [-1.05], hind2_l: [0.3], ...H(0.1, -8, 0), ...STIFF }, 'snap'],
    [0.5, { root: [0.08, -16, -44, 1.14, 0.93], front1: [1.35], front1_l: [0.25], front2: [1.45], front2_l: [0.3], hind1: [-1.15], hind1_l: [0.2], hind2: [-1.25], hind2_l: [0.2], ...H(0.12, -12, -2), ...STIFF }, 'out'],
    // 내려오며 앞발을 뻗음 — 85%에 착지
    [0.85, { root: [-0.1, -10, -10, 1.05, 0.97], front1: [0.75], front1_l: [-0.25], front2: [0.85], front2_l: [-0.25], hind1: [-0.6], hind2: [-0.7], ...H(0, -10, 4), ...STIFF }, 'in'],
    [1, { root: [-0.05, -8, 6, 1.06, 0.88], front1: [0.5], front2: [0.55], hind1: [-0.4], hind2: [-0.45], ...H(0.04, -8, 8), ...TAIL(0.8, 0.4, -0.8, -1.0) }, 'snap'],
  ],
  land: [
    [0, { root: [-0.05, -8, -2], front1: [0.5], front2: [0.55], hind1: [-0.4], hind2: [-0.45], ...H(0, -8, 4), ...TAIL(0.8, 0.4, -0.8, -1.0) }],
    [0.28, { root: [0.1, -4, 18, 1.08, 0.86], front1: [-0.35], front1_l: [0.75], front2: [-0.3], front2_l: [0.7], hind1: [0.5], hind1_l: [-0.7], hind2: [0.55], hind2_l: [-0.75], ...H(0.12, -4, 14), ...TAIL(0.4, 0.2, -0.3, -0.3) }, 'snap'],
    [1, { root: [0, 0, 2], ...H(0, 0, 0), ...TAIL(0.1, 0, 0, 0) }, 'back'],
  ],
  swipe: [
    [0, { ...H(0, 0, 0) }],
    [0.45, { root: [0.3, 12, -8, 0.97, 1.04], front2: [3.0], front2_l: [1.1], front1: [0.35], hind1: [-0.3], hind1_l: [0.2], hind2: [-0.3], hind2_l: [0.2], ...H(-0.25, 4, -10, 'roar'), ...TAIL(0.3, 0.3, -0.3, -0.4) }],
    [0.55, { root: [0.32, 12, -9], front2: [3.1], front2_l: [1.2], front1: [0.35], hind1: [-0.3], hind1_l: [0.2], hind2: [-0.3], hind2_l: [0.2], ...H(-0.27, 4, -11, 'roar'), ...TAIL(0.3, 0.3, -0.3, -0.4), fx_claw: [0, -20, 0, 1.6, 1.6, 0] }],
    [0.68, { root: [-0.08, -14, 6, 1.05, 0.95], front2: [0.35], front2_l: [-0.4], front1: [-0.1], ...H(0.12, -12, 8, 'roar'), ...TAIL(0.6, 0.3, -0.6, -0.8), fx_claw: [0, -20, 0, 1.6, 1.6, 1] }, 'snap'],
    [0.8, { root: [-0.11, -17, 8, 1.03, 0.97], front2: [0.1], front2_l: [-0.5], front1: [-0.15], ...H(0.15, -14, 10, 'roar'), ...TAIL(0.7, 0.35, -0.7, -0.9), fx_claw: [0, -20, 0, 1.7, 1.7, 1] }, 'out'],
    [1, { root: [-0.05, -10, 4], front2: [0.4], front2_l: [-0.2], ...H(0.08, -8, 6), ...TAIL(0.4, 0.2, -0.3, -0.4), fx_claw: [0, -20, 0, 1.7, 1.7, 0] }, 'io'],
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
  const SP = tigerStoryPose(view, anim, t, at);
  if (SP) return SP;
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


// ---------------------------------------------------------------------------
// 3단계(이야기) 동작 — 오누이
// ---------------------------------------------------------------------------
export const STORY_HUMAN = new Set(['cower', 'cry', 'climb', 'perch', 'hug']);
export function humanStoryPose(view, anim, t, at, rig) {
  if (!STORY_HUMAN.has(anim)) return null;
  const S = rig.S, k = S.hip / 80;
  const side = view === 'side';
  const tr = sin(t * 38) * 0.8 * k, sob = sin(t * 14);
  let F;
  if (anim === 'cower') {
    F = side
      ? { root: [0, tr, 46 * k], torso: [-0.55], head: [0.3, 0, 3 * k], leg2: [1.5], leg2_l: [-2.3], leg1: [1.35], leg1_l: [-2.25], arm2: [1.15], arm2_l: [1.25], arm1: [1.0], arm1_l: [1.2] }
      : { root: [0, tr, 30 * k, 1.08, 0.82], leg1: [0.35, -2 * k, 0, 1, 0.6], leg1_l: [-0.5, 0, 0, 1, 0.7], leg2: [-0.35, 2 * k, 0, 1, 0.6], leg2_l: [0.5, 0, 0, 1, 0.7], arm1: [2.3], arm1_l: [2.55], arm2: [-2.3], arm2_l: [-2.55], head: [0, 0, 8 * k] };
  } else if (anim === 'cry') {
    F = side
      ? { torso: [-0.1, 0, 0, 1, 1 + 0.02 * sob], head: [0.25 + 0.04 * sob, 0, 1.2 * sob * k], arm2: [1.9], arm2_l: [1.8], arm1: [1.7], arm1_l: [1.9] }
      : { torso: [0, 0, 0, 1, 1 + 0.025 * sob], head: [0.04 * sin(t * 3), 0, (4 + 1.2 * sob) * k], arm1: [0.35], arm1_l: [-2.8], arm2: [-0.35], arm2_l: [2.8] };
  } else if (anim === 'climb') {
    const u = clamp(at / 1.2, 0, 1), c = sin(PI * 4 * u);
    const rise = (CLIMB_RISE_M * rig.ppm) / rig.scale;
    const up = -rise * EASE.io(u) - 3 * k * abs(c);
    F = side
      ? { root: [0, -6 * k, up], torso: [-0.25], head: [-0.2], arm2: [2.75 + 0.35 * c], arm2_l: [0.3 - 0.3 * c], arm1: [2.75 - 0.35 * c], arm1_l: [0.3 + 0.3 * c], leg2: [1.1 + 0.5 * c], leg2_l: [-1.7 - 0.2 * c], leg1: [1.1 - 0.5 * c], leg1_l: [-1.7 + 0.2 * c] }
      : { root: [0, 0, up], arm1: [2.8 + 0.3 * c], arm1_l: [0.3], arm2: [-2.8 + 0.3 * c], arm2_l: [-0.3], leg1: [0.1, 0, -10 * k * max(0, c)], leg2: [-0.1, 0, -10 * k * max(0, -c)], head: [0, 0, -2 * k] };
  } else if (anim === 'perch') {
    const sw = sin(t * 2.6), sw2 = sin(t * 2.6 + 1.5);
    F = side
      ? { root: [0.05, 0, (S.hip - 4 * k)], torso: [0.04], leg2: [1.45], leg2_l: [-1.45 + 0.25 * sw], leg1: [1.4], leg1_l: [-1.4 + 0.25 * sw2], arm2: [-0.25], arm2_l: [0.1], arm1: [-0.2], head: [0.06 * sin(t * 0.5)] }
      : { root: [0, 0, (S.hip - 4 * k)], leg1: [0, 0, -S.thigh * 0.95], leg1_l: [0.12 * sw], leg2: [0, 0, -S.thigh * 0.95], leg2_l: [0.12 * sw2], arm1: [0.45], arm1_l: [-0.2], arm2: [-0.45], arm2_l: [0.2], head: [0.05 * sin(t * 0.5)] };
  } else {
    const sway = sin(t * 1.6);
    F = side
      ? { root: [0.02 * sway, 0, 0.8 * sin(t * 3.2) * k], torso: [-0.12 + 0.03 * sway], head: [0.18], arm2: [1.35], arm2_l: [0.95], arm1: [1.25], arm1_l: [1.05] }
      : { root: [0.02 * sway, 0, 0.8 * sin(t * 3.2) * k], head: [0.12], arm1: [-0.35, 0, 0, 1, 0.75], arm1_l: [-1.25], arm2: [0.35, 0, 0, 1, 0.75], arm2_l: [1.25] };
  }
  const P = kf(0, [[0, F]]);
  return view === 'back' ? mirror(P) : P;
}

// ---------------------------------------------------------------------------
// 3단계(이야기) 동작 — 호랑이
// ---------------------------------------------------------------------------
export function tigerStoryPose(view, anim, t, at) {
  const side = view === 'side', back = view === 'back';
  if (anim === 'knock') {
    const kn = Math.pow(max(0, sin((t / 0.6) * PI * 2)), 3);
    if (side) return kf(0, [[0, {
      root: [0.95, -84, -106], hind1: [-1.1], hind1_l: [0.4], hind2: [-1.05], hind2_l: [0.4],
      front1: [0.9], front1_l: [0.6], front2: [1.55 + 0.35 * kn], front2_l: [-0.5 + 0.45 * kn],
      ...H(-0.85, 0, 0), ...TAIL(1.2, 0.1, -0.2, -0.3),
    }]]);
    if (back) return kf(0, [[0, { root: [0, 0, -55, 1, 1.35], front1_up: [-0.15 * kn, 0, -8 * kn, 1, 1, 1], front2_up: [0.05, 0, 0, 1, 1, 1], ...H(0, 0, -34), tail0: [-2.9], tail1: [0.3], tail2: [0.1], tail3: [0.1] }]]);
    return kf(0, [[0, { root: [0, 0, -50, 1, 1.3], front1: [2.6], front1_l: [-0.6], front2: [-2.6 - 0.3 * kn], front2_l: [0.6], hind1: [0.1], hind2: [-0.1], ...H(0, 0, -26), ...TAIL(0.9, 0.3, 0, 0) }]]);
  }
  if (anim === 'sniff') {
    const tw = sin(t * 9);
    if (side) return kf(0, [[0, { root: [-0.05, 0, 10], front1: [-0.15], front1_l: [0.3], front2: [-0.1], front2_l: [0.25], ...H(-0.2 + 0.06 * sin(t * 2.2), -12 + 8 * sin(t * 1.3), 52 + 3 * tw), ...TAIL(0.4 + 0.1 * sin(t * 1.5), 0.2, -0.3, -0.3) }]]);
    return kf(0, [[0, { root: [0, 0, 8, 1, 0.95], ...H(0.1 * sin(t * 1.3), 10 * sin(t * 1.3), (back ? 20 : 46) + 2 * tw) }]]);
  }
  const u = (d) => clamp(at / d, 0, 1);
  if (anim === 'climb_try') {
    const REAR = { hind1: [-1.25], hind1_l: [0.45], hind2: [-1.2], hind2_l: [0.45], ...H(-1.0, 0, 0), ...TAIL(1.3, 0.2, -0.2, -0.3) };
    if (side) return kf(u(1.4), [
      [0, {}],
      [0.22, { ...REAR, root: [1.15, -90, -125], front1: [1.6], front1_l: [0.3], front2: [1.9], front2_l: [0.2] }, 'out'],
      [0.4, { ...REAR, root: [1.18, -92, -132], front1: [1.4], front1_l: [0.4], front2: [2.5], front2_l: [-0.4] }, 'snap'],
      [0.58, { ...REAR, root: [1.18, -92, -138], front1: [2.5], front1_l: [-0.4], front2: [1.5], front2_l: [0.4] }, 'snap'],
      [0.76, { ...REAR, root: [1.2, -92, -141], front1: [1.5], front1_l: [0.4], front2: [2.6], front2_l: [-0.5] }, 'snap'],
      [0.9, { ...REAR, root: [1.15, -90, -126], front1: [1.9], front1_l: [0.1], front2: [2.0], front2_l: [0.1] }, 'in'],
      [1, { ...REAR, root: [1.14, -90, -122], front1: [1.8], front1_l: [0.2], front2: [1.9], front2_l: [0.2] }, 'out'],
    ]);
    const a = (x) => (back ? { front1_up: [x - 2.5, 0, -6 * (x - 2.2), 1, 1, 1], front2_up: [-(x - 2.5), 0, 6 * (x - 2.6), 1, 1, 1] } : { front1: [x], front1_l: [-0.5], front2: [-x - 0.2], front2_l: [0.5] });
    return kf(u(1.4), [
      [0, {}],
      [0.22, { root: [0, 0, -70, 1, 1.4], ...a(2.3), ...H(0, 0, back ? -35 : -25) }, 'out'],
      [0.4, { root: [0, 0, -76, 1, 1.42], ...a(2.8), ...H(0, 0, back ? -37 : -27) }, 'snap'],
      [0.58, { root: [0, 0, -80, 1, 1.43], ...a(2.2), ...H(0, 0, back ? -38 : -28) }, 'snap'],
      [0.76, { root: [0, 0, -82, 1, 1.44], ...a(2.9), ...H(0, 0, back ? -39 : -29) }, 'snap'],
      [1, { root: [0, 0, -70, 1, 1.38], ...a(2.4), ...H(0, 0, back ? -35 : -25) }, 'in'],
    ]);
  }
  if (anim === 'slip') {
    if (side) {
      const HIGH = { root: [1.2, -90, -150], hind1: [-1.3], hind1_l: [0.5], hind2: [-1.25], hind2_l: [0.5], front1: [2.0], front1_l: [0.2], front2: [2.4], front2_l: [-0.2], ...H(-1.05, 0, 0), ...TAIL(1.3, 0.2, -0.2, -0.3) };
      const BACK = (sy, y) => ({ root: [3.14, -10, y, 1 / sy, sy], front1: [0.9], front1_l: [0.6], front2: [1.3], front2_l: [0.4], hind1: [-0.4], hind2: [0.3], ...H(-2.5, 0, 0, 'dead'), ...TAIL(0.4, 0.3, -0.2, -0.3) });
      return kf(u(1.8), [
        [0, HIGH],
        // 미끄러지기 시작: 앞발이 허둥지둥, 눈이 휘둥그레
        [0.18, { ...HIGH, root: [1.25, -90, -140], front1: [2.6], front2: [2.9], hind1: [-1.0], ...H(-1.1, 0, -4, 'roar') }, 'out'],
        [0.32, { ...HIGH, root: [1.35, -80, -100], front1: [3.1], front2: [2.4], hind1: [-0.6], hind2: [-0.9], ...H(-1.2, 0, -6, 'roar') }, 'in'],
        // 뒤로 넘어가며
        [0.48, { root: [2.3, -40, -60], front1: [1.0], front2: [2.0], hind1: [0.4], hind2: [-0.6], ...H(-1.4, 0, 0, 'roar'), ...TAIL(-0.5, 0.4, 0.3, 0.3) }, 'in'],
        // 쿵! 등으로 떨어짐(납작)
        [0.58, { ...BACK(0.82, 32), fx_burst: [0, 0, 70, 1.5, 1.2, 1] }, 'in'],
        [0.66, { ...BACK(1.06, 6), fx_burst: [0, 0, 70, 1.8, 1.4, 1] }, 'out'],
        [0.76, { ...BACK(0.97, 20), fx_burst: [0, 0, 70, 2, 1.5, 0] }, 'io'],
        [1, { ...BACK(1, 16), front1: [0.6], front2: [0.9], hind1: [-0.3], hind2: [0.1] }, 'io'],
      ]);
    }
    const HIGH = { root: [0, 0, -80, 1, 1.42], front1: [2.4], front2: [-2.6], ...H(0, 0, back ? -38 : -28) };
    return kf(u(1.8), [
      [0, HIGH],
      [0.3, { ...HIGH, root: [0.15, 0, -50, 1, 1.3], ...H(0, 0, back ? -30 : -22, 'roar') }, 'in'],
      [0.48, { root: [1.6, 0, -10], front1: [1.2], front2: [-1.6], ...H(0, 0, 0, 'roar') }, 'in'],
      [0.58, { root: [3.14, 0, 40, 1.15, 0.8], front1: [0.6], front2: [-0.6], ...H(0, 0, 0, 'dead'), fx_burst: [0, 0, 60, 1.5, 1.2, 1] }, 'in'],
      [0.66, { root: [3.14, 0, 28, 0.95, 1.05], front1: [0.8], front2: [-0.8], ...H(0, 0, 0, 'dead'), fx_burst: [0, 0, 60, 1.8, 1.4, 1] }, 'out'],
      [1, { root: [3.14, 0, 36], front1: [0.5], front2: [-0.5], ...H(0, 0, 0, 'dead') }, 'io'],
    ]);
  }
  return null;
}
