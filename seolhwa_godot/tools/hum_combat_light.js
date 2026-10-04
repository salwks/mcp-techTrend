// HUM_COMBAT_LIGHT(CHARACTER_MASTER §7) — 사람 적 공통 전투 동작: ready · swing · thrust · hit · fall · flee.
// 웹 굽기 엔진(frameCore.BakeBank)에 사람 종류를 더할 때 installHCL(kind, opts)만 부르면 된다(웹 코드 seolhwa/src는 고치지 않는다).
//  - 동작 자세는 웹 anims.js의 칼 동작(attack1·attack3·guard·hit·dead) 꼴을 빌려 몽둥이·장대로 옮겼다.
//  - 무기는 손에 붙는 부위 'weapon'(태그 weapon — 늘 보인다): club(몽둥이, 내리치기) · pole(장대, 찌르기).
//  - 칼·활·떡(사람 공통 전투 부위)은 이 종류에서 뺀다(사람 적은 환도를 들지 않는다).
// Godot 쪽: scripts/combat/chuman.gd(상태 기계)가 이 이름으로 동작을 부른다. 판정 순간: swing 0.62, thrust 0.55(동작 길이 비율).
// 쓰는 곳: tools/export_gyeongju_frames.js(밀수꾼). 함흥·한양 최종장의 도적·경비도 같은 꼴로 굽는다:
//   import { installHCL, HCL_NAMES, hclSpec } from '/__tools/hum_combat_light.js';
//   installHCL('bandit', { weapon: 'club' }); 굽기 목록에 HCL_NAMES를 더하고, 클립마다 hclSpec(anim, c.spec)로 그림 수를 고친다.
import { SPECS, getRig } from '/src/chars/rigs.js';
import { Painter } from '/src/chars/painter.js';

export const HCL_ANIMS = {
  ready: { dur: 1.0, loop: true }, swing: { dur: 0.8 }, thrust: { dur: 0.85 },
  hit: { dur: 0.35 }, fall: { dur: 0.9 }, flee: { dur: 0.6, loop: true },
};
export const HCL_NAMES = Object.keys(HCL_ANIMS);

const { sin, cos, max, min, PI } = Math;
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const EASE = {
  io: (k) => (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2),
  out: (k) => 1 - Math.pow(1 - k, 3),
  snap: (k) => 1 - Math.pow(1 - k, 5),
  back: (k) => { const c = 1.9; return 1 + (c + 1) * Math.pow(k - 1, 3) + c * Math.pow(k - 1, 2); },
};
function kf(u, frames) {
  let i = 0;
  while (i < frames.length - 2 && u >= frames[i + 1][0]) i++;
  const [t0, A] = frames[i], [t1, B, ez] = frames[min(i + 1, frames.length - 1)];
  const k = t1 > t0 ? (EASE[ez] || EASE.io)(clamp((u - t0) / (t1 - t0), 0, 1)) : 1;
  const P = {};
  for (const n of new Set([...Object.keys(A), ...Object.keys(B)])) {
    const a = A[n], b = B[n];
    const g = (arr, j) => (arr && arr[j] != null ? arr[j] : j < 3 ? 0 : 1);
    const v = (j) => g(a, j) + (g(b, j) - g(a, j)) * k;
    P[n] = { r: v(0), x: v(1), y: v(2), sx: v(3), sy: v(4), a: v(5) };
  }
  return P;
}
const SWAP = { arm1: 'arm2', arm2: 'arm1', arm1_l: 'arm2_l', arm2_l: 'arm1_l', leg1: 'leg2', leg2: 'leg1', leg1_l: 'leg2_l', leg2_l: 'leg1_l' };
const mirror = (P) => {
  const Q = {};
  for (const n in P) { const p = P[n]; Q[SWAP[n] || n] = { r: -p.r, x: -p.x, y: p.y, sx: p.sx, sy: p.sy, a: p.a }; }
  return Q;
};

const STANCE = { leg2: [0.25], leg2_l: [-0.1], leg1: [-0.25], leg1_l: [-0.05] };
const LUNGE = { leg2: [0.5], leg2_l: [-0.25], leg1: [-0.45], leg1_l: [-0.15] };
const BIG = { leg2: [0.85], leg2_l: [-0.4], leg1: [-0.7], leg1_l: [-0.2] };
// 겨눔(ready): 무기를 어깨 앞에 비스듬히 — 웹 guard 꼴
const S_READY = { ...STANCE, root: [0, 3, 10], torso: [0.08], arm2: [1.15], arm2_l: [1.25], weapon: [0.55], arm1: [0.8], arm1_l: [1.1], head: [0.05] };
const F_READY = { arm2: [-0.55], arm2_l: [-1.2], weapon: [2.6], arm1: [0.5], arm1_l: [1.2], root: [0, 0, 8], leg1: [0.1], leg2: [-0.1], head: [0, 0, 3] };
const S_READY_P = { ...STANCE, root: [0, 4, 10], torso: [0.06], arm2: [0.2], arm2_l: [1.6], weapon: [-0.15], arm1: [0.9], arm1_l: [0.6], head: [0.04] };
const F_READY_P = { arm2: [-0.3], arm2_l: [-1.0], weapon: [1.9], arm1: [0.6], arm1_l: [1.0], root: [0, 0, 8], leg1: [0.1], leg2: [-0.1], head: [0, 0, 3] };
const DEAD_END = { root: [-1.5, 14, 100], head: [0.2], torso: [0.05], arm2: [-0.4], arm2_l: [0.2], arm1: [-0.2], leg2: [0.2], leg1: [-0.1], weapon: [0.9] };

const SIDE = {
  // 몽둥이 내리치기: 크게 치켜듦(예고) → 0.62 내리침 → 뒤따름
  swing: [
    [0, S_READY],
    [0.5, { ...STANCE, arm2: [3.15], arm2_l: [0.3], weapon: [0.3], arm1: [0.4], root: [0, 6, 7], torso: [0.16], head: [-0.08] }, 'out'],
    [0.62, { ...LUNGE, arm2: [0.35], arm2_l: [0.05], weapon: [0.15], arm1: [-0.5], root: [0, -12, 12], torso: [-0.28], head: [0.14] }, 'snap'],
    [0.78, { ...LUNGE, arm2: [0.1], arm2_l: [0.2], weapon: [0.55], arm1: [-0.55], root: [0, -13, 13], torso: [-0.3], head: [0.15] }, 'out'],
    [1, { ...STANCE, arm2: [0.7], arm2_l: [0.6], weapon: [0.45], arm1: [0.2], root: [0, -4, 10], torso: [-0.08], head: [0.06] }, 'io'],
  ],
  // 장대 찌르기: 허리로 당김(예고) → 0.55 찌름 → 거둠
  thrust: [
    [0, S_READY_P],
    [0.42, { ...STANCE, arm2: [-0.6], arm2_l: [1.95], weapon: [-0.3], root: [0, 10, 12, 1.03, 0.97], torso: [0.18], arm1: [0.85], arm1_l: [0.45] }, 'out'],
    [0.55, { ...BIG, arm2: [1.5], arm2_l: [-0.12], weapon: [0.05], root: [0, -22, 16, 1.02, 0.98], torso: [-0.34], head: [0.18], arm1: [1.2], arm1_l: [0.2] }, 'snap'],
    [0.72, { ...BIG, arm2: [1.5], arm2_l: [-0.1], weapon: [0.05], root: [0, -24, 17], torso: [-0.36], head: [0.2], arm1: [1.25], arm1_l: [0.2] }, 'out'],
    [1, { ...S_READY_P }, 'io'],
  ],
  hit: [
    [0, S_READY],
    [0.22, { torso: [0.4], head: [0.42], root: [0.08, 12, 6, 0.96, 1.03], arm2: [-0.6], arm2_l: [0.6], arm1: [-1.05], arm1_l: [0.5], leg2: [0.35], leg1: [-0.15], weapon: [0.4] }, 'snap'],
    [1, { torso: [0.12], head: [0.1], root: [0.03, 6, 3], arm2: [0.4], arm2_l: [0.8], arm1: [-0.3], leg2: [0.2], leg1: [-0.1], weapon: [0.5] }, 'back'],
  ],
  fall: [
    [0, {}],
    [0.3, { root: [-0.3, 0, 18], head: [0.4], torso: [-0.12], leg2: [0.5], leg2_l: [-1.0], leg1: [0.35], leg1_l: [-1.0], arm2: [0.6], arm1: [0.4], weapon: [0.8] }],
    [0.75, { ...DEAD_END, root: [-1.52, 14, 96] }],
    [0.88, { ...DEAD_END, root: [-1.5, 14, 101] }],
    [1, DEAD_END],
  ],
};
const FRONT = {
  swing: [
    [0, F_READY],
    [0.5, { arm2: [-2.9], arm2_l: [-0.3], weapon: [0.1], arm1: [0.45], torso: [-0.06], root: [0, 3, 4], head: [0, 0, -2] }, 'out'],
    [0.62, { arm2: [0.7], arm2_l: [0.4], weapon: [0.35], arm1: [-0.25], torso: [0.1], root: [0, -4, 10], head: [0.06, 0, 3] }, 'snap'],
    [0.8, { arm2: [0.85], arm2_l: [0.4], weapon: [0.45], arm1: [-0.2], torso: [0.08], root: [0, -4, 10], head: [0.05, 0, 3] }, 'out'],
    [1, F_READY, 'io'],
  ],
  thrust: [
    [0, F_READY_P],
    [0.42, { arm2: [-1.3], arm2_l: [-1.6], weapon: [0], torso: [-0.06], root: [0, 3, 4], arm1: [0.5] }, 'out'],
    [0.55, { arm2: [-0.25, 0, 0, 1, 0.75], arm2_l: [0.05, 0, 0, 1, 0.6], weapon: [0.1, 0, 0, 1, 0.45], root: [0, -2, 14], torso: [0, 0, 0, 1.04, 0.95], head: [0, 0, 4], arm1: [0.6] }, 'snap'],
    [0.72, { arm2: [-0.25, 0, 0, 1, 0.75], arm2_l: [0.05, 0, 0, 1, 0.6], weapon: [0.1, 0, 0, 1, 0.45], root: [0, -2, 14], torso: [0, 0, 0, 1.04, 0.95], head: [0, 0, 4], arm1: [0.5] }, 'out'],
    [1, F_READY_P, 'io'],
  ],
  hit: [
    [0, F_READY],
    [0.25, { torso: [0.1, 0, 0, 1, 0.94], head: [0.3, 0, 4], root: [0.06, 6, 4], arm2: [-0.9], arm2_l: [-0.5], arm1: [0.9], arm1_l: [0.5], leg2: [-0.15], weapon: [0.4] }],
    [1, { torso: [0.03], head: [0.1], root: [0.02, 2, 2], arm2: [-0.3], arm2_l: [-0.6], arm1: [0.3], weapon: [1.2] }],
  ],
};
FRONT.fall = SIDE.fall;

/** 사람 적 동작 자세(웹 rig.pose 꼴) — 아니면 null. base: 원래 rig.pose(달아남은 뛰기 위에 얹는다) */
export function hclPose(view, anim, t, at, rig, base, weapon) {
  const info = HCL_ANIMS[anim];
  if (!info) return null;
  const side = view === 'side';
  let P;
  if (anim === 'flee') {
    // 달아남: 뛰기 + 고개를 뒤로 돌려 보고, 무기 든 팔을 휘저음
    P = base(view, 'run', t, rig, at, { phase: t / info.dur });
    const s = sin((t / info.dur) * PI * 2);
    const add = (n, r = 0, x = 0, y = 0) => { const p = P[n] || (P[n] = { r: 0, x: 0, y: 0, sx: 1, sy: 1 }); p.r += r; p.x += x; p.y += y; };
    if (side) { add('head', -0.35); add('torso', -0.08); add('arm2', 0.5 + 0.3 * s); add('weapon', 0.4); }
    else { add('head', 0.12 * s, 0, 2); add('arm2', -0.5 - 0.2 * s); add('weapon', 0.5); }
    return P;
  }
  const src = (side ? SIDE : FRONT)[anim] || (anim === 'ready' ? null : SIDE[anim]);
  if (anim === 'ready') {
    const pole = weapon === 'pole';
    const R = side ? (pole ? S_READY_P : S_READY) : (pole ? F_READY_P : F_READY);
    P = kf(clamp(at / 0.18, 0, 1), [[0, {}], [1, R]]);
    const b = sin(t * PI * 2 / info.dur);
    const p = P.root || (P.root = { r: 0, x: 0, y: 0, sx: 1, sy: 1 });
    p.y += 1.6 * b;
    if (P.weapon) P.weapon.r += 0.04 * b;
  } else {
    P = kf(clamp(at / info.dur, 0, 1), src);
  }
  return view === 'back' ? mirror(P) : P;
}

/** 클립 그림 수 고치기: 내리치기·찌르기는 맞는 순간을 촘촘히, 달아남은 한 주기 8장 */
export function hclSpec(anim, spec) {
  const info = HCL_ANIMS[anim];
  if (!info) return spec;
  if (anim === 'flee') {
    const n = 8, step = info.dur / n;
    return { kind: 'loop', times: [...Array(n).keys()].map((k) => k * step), loopStart: 0, intro: 0, step, n, dur: info.dur, tBased: false };
  }
  if (anim === 'swing' || anim === 'thrust') {
    const w = anim === 'swing' ? [0.45, 0.82] : [0.38, 0.75];
    const set = new Set(spec.times);
    for (let t = w[0] * info.dur; t <= w[1] * info.dur + 1e-6; t += 1 / 24) set.add(+t.toFixed(4));
    const times = [...set].sort((a, b) => a - b).filter((t, i, arr) => i === 0 || t - arr[i - 1] > 0.02);
    return { ...spec, times };
  }
  return spec;
}

/** 무기 그림: 손(+y가 손에서 멀어지는 쪽). club 몽둥이(끝이 굵음) · pole 장대(손 뒤로도 조금) */
export function weaponPart(S, weapon, carry = false) {
  const P = new Painter(weapon === 'pole' ? 640 : 256);
  P.begin(11);
  const ws = S.ws;
  if (weapon === 'pole') {
    // 싸울 때는 손에서 앞으로 길게, 들고 다닐 때(carry)는 지팡이처럼 손 위아래로
    const top = (carry ? -112 : -46) * ws, bot = (carry ? 122 : 188) * ws;
    P.poly([[-2.8, top], [2.8, top], [2.4, bot], [-2.4, bot]], '#8a6a42', { w: 1.6, smooth: false, rough: 0.5 });
    for (const k of [0.15, 0.5, 0.82]) P.stroke([[-3.6, top + (bot - top) * k], [3.6, top + (bot - top) * k - 2]], { w: 1.2, taper: false });
    // 끝에 감은 쇠고리
    P.poly([[-3.4, bot - 10 * ws], [3.4, bot - 10 * ws], [3.2, bot + 2], [-3.2, bot + 2]], '#5d5850', { w: 1.3, smooth: false });
  } else {
    const L = 78 * ws;
    P.poly([[-3, -8 * ws], [3, -8 * ws], [4.2, L * 0.45], [7.5, L], [0, L + 6 * ws, 'c'], [-7.5, L], [-4.2, L * 0.45]], '#6f5233', { w: 1.7, rough: 0.8 });
    // 손잡이에 감은 새끼
    for (let i = 0; i < 3; i++) P.stroke([[-3.4, (-4 + i * 5) * ws], [3.4, (-2 + i * 5) * ws]], { w: 1.1, color: '#c8b48a', taper: false });
    P.stroke([[-2, L * 0.6], [-4, L * 0.9]], { w: 1.0, color: '#4a3622', taper: false });
  }
  return P.end();
}

/** 들고 다니는 등롱(손에 매달림): 짧은 끈 + 한지 등롱. 밤 불빛은 Godot 쪽이 따로 켠다 */
export function lanternPart(S) {
  const P = new Painter(256);
  P.begin(13);
  const ws = S.ws;
  P.stroke([[0, -2], [0, 12 * ws]], { w: 1.4, color: '#3a2f25', taper: false });
  P.poly([[-7 * ws, 12 * ws], [7 * ws, 12 * ws], [6 * ws, 16 * ws], [-6 * ws, 16 * ws]], '#4a3a2a', { w: 1.2, smooth: false });
  P.ellipse(0, 30 * ws, 12 * ws, 15 * ws, '#f2d68a', { w: 1.5 });
  P.ellipse(0, 30 * ws, 6 * ws, 11 * ws, '#ffe9a8', { w: 0.6 });
  for (const k of [-0.55, 0, 0.55]) P.stroke([[-12 * ws * 0.95, 30 * ws + k * 14 * ws], [12 * ws * 0.95, 30 * ws + k * 14 * ws]], { w: 0.9, color: '#a8874a', taper: false });
  P.poly([[-7 * ws, 44 * ws], [7 * ws, 44 * ws], [6 * ws, 48 * ws], [-6 * ws, 48 * ws]], '#4a3a2a', { w: 1.2, smooth: false });
  return P.end();
}

/** 손 부위에 그림을 붙인다(태그 tag — 늘 보임). abs면 손 각도와 상관없이 곧게(매달린 등롱·지팡이), 아니면 손을 따라 돈다(무기) */
export function attachHand(rig, name, img, tag, abs = true) {
  for (const v of ['front', 'side', 'back']) {
    const parts = rig.views[v];
    const hand = v === 'back' ? 'arm1_l' : 'arm2_l';
    parts.push({ name, parent: hand, at: [0, rig.S.lArm + 2], r0: 0, z: v === 'side' ? 10.95 : 6.15, img: img.img, ox: img.ox, oy: img.oy, abs, tag });
    parts.draw = parts.filter((p) => p.img).map((p, i) => ({ p, i })).sort((a, b) => a.p.z - b.p.z || a.i - b.i).map((e) => e.p);
  }
}

/** 사람 공통 전투 부위(환도·활·떡·등에 멘 활)를 뺀다 */
export function stripCombatParts(rig) {
  for (const v of ['front', 'side', 'back']) {
    const parts = rig.views[v];
    for (let i = parts.length - 1; i >= 0; i--) if (['sword', 'alt', 'backbow'].includes(parts[i].tag)) parts.splice(i, 1);
    parts.draw = parts.filter((p) => p.img).map((p, i) => ({ p, i })).sort((a, b) => a.p.z - b.p.z || a.i - b.i).map((e) => e.p);
  }
}

/** kind(SPECS에 이미 있는 사람 종류)에 사람 적 동작과 무기를 단다. opts: { weapon: 'club' | 'pole' } */
export function installHCL(kind, opts = {}) {
  const weapon = opts.weapon || 'club';
  const rig = getRig(kind);
  rig.anims = { ...rig.anims, ...HCL_ANIMS };
  const base = rig.pose;
  const hide = { r: 0, x: 0, y: 0, sx: 1, sy: 1, a: 0 };
  rig.pose = (view, anim, t, rg, at, st) => {
    const fight = !!HCL_ANIMS[anim] && anim !== 'flee';
    const P = hclPose(view, anim, t, at, rg, base, weapon) || base(view, anim, t, rg, at, st);
    // 장대: 싸울 때는 손을 따라 도는 'weapon', 걷거나 서 있을 때는 지팡이처럼 곧은 'weapon_carry'
    if (weapon === 'pole') { if (fight) P.weapon_carry = { ...hide }; else P.weapon = { ...hide }; }
    // 묶이거나 앉으면 무기는 없다(빼앗김)
    if (anim === 'tied' || anim === 'sit' || anim === 'cower') { P.weapon = { ...hide }; P.weapon_carry = { ...hide }; }
    return P;
  };
  stripCombatParts(rig);
  attachHand(rig, 'weapon', weaponPart(rig.S, weapon), 'weapon', false);
  if (weapon === 'pole') attachHand(rig, 'weapon_carry', weaponPart(rig.S, weapon, true), 'weapon', true);
  return rig;
}
