// 공용 자세(사람 누구나): 앉기(sit) · 절(bow) · 꿇어앉기(kneel) — 관아·잔치·제사에 두루 쓴다(춘향 PART II 준비 2026-10-11).
// 웹 굽기 엔진(frameCore.BakeBank)에 붙이는 확장이다 — 웹 코드(seolhwa/src)는 고치지 않는다(hum_combat_light.js와 같은 방식).
//   installPoses(kind): 그 종류의 리그에 세 동작(+ 교의에 앉기 sit_chair — 원하는 종류만)을 더한다.
//   poseSpec(anim, spec): 그림 수를 고친다 — 가만히 있는 자세라 한 주기 2장(숨쉬기)만.
// 자세(그림 원점 = 발 사이 땅, 앞모습 기준 / 옆모습은 왼쪽을 본다):
//   sit   — 양반다리(방석·마루에 앉음): 엉덩이가 땅에서 한 뼘, 무릎이 앞으로, 손은 무릎 위. 치마·두루마기 자락은 땅에 퍼진다.
//   bow   — 선 채 허리를 깊이 굽힌 절(국궁): 두 손을 앞에 모으고 고개를 숙인다.
//   kneel — 꿇어앉기: 무릎을 꿇고 발뒤꿈치 위에 앉아 몸을 앞으로 숙이고 고개를 떨군다(관아 마당·출두 때 엎드림).
//   sit_chair — 교의(의자)에 앉기: 허벅지가 앞으로, 종아리는 아래로(변학도 대청 자리).
// Godot 쪽: data/frames_pose.json(굽기 세트 ?set=poses)이 모든 사람 종류에 이 클립을 더한다(SpriteChar.ensure_poses — 처음 쓸 때).
import { getRig } from '/src/chars/rigs.js';

export const POSE_ANIMS = {
  sit: { dur: 3.2, loop: true }, bow: { dur: 3.0, loop: true }, kneel: { dur: 3.4, loop: true }, sit_chair: { dur: 3.2, loop: true },
};
export const POSE_NAMES = ['sit', 'bow', 'kneel'];

const { sin, PI } = Math;
const SWAP = { arm1: 'arm2', arm2: 'arm1', arm1_l: 'arm2_l', arm2_l: 'arm1_l', leg1: 'leg2', leg2: 'leg1', leg1_l: 'leg2_l', leg2_l: 'leg1_l' };
const HIDDEN = /^(fx_|head_|bow[RD]$|item$|front[12]_up$)/;
const toP = (F) => {
  const P = {};
  for (const n in F) { const a = F[n]; P[n] = { r: a[0] || 0, x: a[1] || 0, y: a[2] || 0, sx: a[3] ?? 1, sy: a[4] ?? 1, a: a[5] ?? (HIDDEN.test(n) ? 0 : 1) }; }
  return P;
};
const mirror = (P) => {
  const Q = {};
  for (const n in P) { const p = P[n]; Q[SWAP[n] || n] = { r: -p.r, x: -p.x, y: p.y, sx: p.sx, sy: p.sy, a: p.a }; }
  return Q;
};
const HIDE = [0, 0, 0, 1, 1, 0];

/** 자세 하나(view: front·side·back). 숨쉬기 b(−1~1)만 움직인다 */
export function posePose(view, anim, t, rig) {
  const S = rig.S, sp = rig.spec, k = S.hip / 80, side = view === 'side';
  const chima = sp.bottom === 'chima', robe = sp.top === 'durumagi' || chima;
  const b = sin((t / POSE_ANIMS[anim].dur) * PI * 2);
  const staff = { staff: HIDE };
  let F;
  if (anim === 'sit') {
    // 엉덩이 높이 ≈ 땅 위 한 뼘(방석) — root를 hip에서 그만큼 내린다
    const drop = S.hip - 17 * k;
    if (side) {
      F = { root: [0.02, 4 * k, drop], torso: [-0.06, 0, 0, 1, 1 + 0.012 * b], head: [0.05 + 0.02 * b],
        // 무릎이 앞으로 거의 수평, 종아리는 땅을 따라 뒤로 접혀 엉덩이 밑으로(양반다리 옆모습)
        leg2: [1.45], leg2_l: [-3.02], leg1: [1.36], leg1_l: [-2.95],
        arm2: [0.62], arm2_l: [0.42], arm1: [0.5], arm1_l: [0.5],
        skirt: chima ? [0.5, -4 * k, -2 * k, 1.3, 0.38] : robe ? [0.5, -4 * k, -2 * k, 1.12, 0.4] : [0] };
    } else {
      // 앞: 허벅지가 양옆으로 벌어지고 종아리가 앞에서 엇갈린다(짧게 보임)
      F = { root: [0, 0, drop], torso: [0, 0, 0, 1, 1 + 0.012 * b], head: [0.02 * b],
        leg1: [1.15, 0, -6 * k, 1, 0.85], leg1_l: [-2.05, 0, 0, 1, 0.62], leg2: [-1.15, 0, -6 * k, 1, 0.85], leg2_l: [2.05, 0, 0, 1, 0.62],
        arm1: [0.22], arm1_l: [-0.62], arm2: [-0.22], arm2_l: [0.62],
        skirt: chima ? [0, 0, -4 * k, 1.75, 0.42] : robe ? [0, 0, -2 * k, 1.45, 0.5] : [0] };
      if (view === 'back') F = null;
    }
  } else if (anim === 'kneel') {
    // 무릎을 꿇고 발뒤꿈치 위에 앉음 — 엉덩이 높이 ≈ 종아리 두께 + 발
    const drop = S.hip - 30 * k;
    if (side) {
      F = { root: [0.04, 6 * k, drop], torso: [-0.34, 0, 0, 1, 1 + 0.01 * b], head: [-0.22 + 0.02 * b],
        leg2: [1.38], leg2_l: [-2.92], leg1: [1.32], leg1_l: [-2.86],
        arm2: [0.95], arm2_l: [0.35], arm1: [0.85], arm1_l: [0.45],
        skirt: chima ? [0.45, -6 * k, 0, 1.2, 0.42] : robe ? [0.6, -4 * k, -2 * k, 1.05, 0.44] : [0] };
    } else {
      // 앞: 무릎만 짧게(몸 쪽으로 접힌 허벅지), 종아리는 몸 뒤에 숨는다. 몸통은 앞으로 숙여 짧아 보이고 고개를 떨군다
      F = { root: [0, 0, drop + 2 * k], torso: [0, 0, 0, 1, 0.86 + 0.01 * b], head: [0, 0, 7 * k, 1, 0.96],
        leg1: [0.22, -2 * k, -15 * k, 1.3, 0.3], leg1_l: HIDE, leg2: [-0.22, 2 * k, -15 * k, 1.3, 0.3], leg2_l: HIDE,
        arm1: [0.12], arm1_l: [-0.45], arm2: [-0.12], arm2_l: [0.45],
        skirt: chima ? [0, 0, -2 * k, 1.5, 0.4] : robe ? [0, 0, 0, 1.3, 0.45] : [0] };
      if (view === 'back') {
        // 뒤: 엉덩이 밑으로 발바닥이 보인다(종아리를 짧게 몸 쪽으로)
        F.leg1 = [0.1, 0, -12 * k, 1, 0.3]; F.leg1_l = [-0.05, 0, 0, 1, 0.22]; F.leg2 = [-0.1, 0, -12 * k, 1, 0.3]; F.leg2_l = [0.05, 0, 0, 1, 0.22];
        F.head = [0, 0, 12 * k, 1, 0.9];
      }
    }
  } else if (anim === 'bow') {
    if (side) {
      // 허리를 깊이(약 45°) 굽히고 엉덩이를 뒤로. 팔은 몸에서 아래로 늘어뜨려 두 손을 무릎 앞에 모은다
      F = { root: [0, 7 * k, 3 * k], torso: [-0.78, 0, 0, 1, 1 + 0.01 * b], head: [-0.32 + 0.02 * b],
        leg2: [-0.06], leg2_l: [0.04], leg1: [0.0], leg1_l: [0.02],
        arm2: [1.05], arm2_l: [0.32], arm1: [0.95], arm1_l: [0.38], skirt: [0.12] };
    } else {
      // 앞: 몸통이 보는 쪽으로 기울어 짧아지고 머리가 가슴께로 내려온다. 두 손을 앞에 모음
      F = { root: [0, 0, 4 * k], torso: [0, 0, 0, 1.04, 0.64 + 0.01 * b], head: [0, 0, 27 * k, 1, 0.86],
        arm1: [-0.16, 0, 0, 1, 0.8], arm1_l: [-0.5], arm2: [0.16, 0, 0, 1, 0.8], arm2_l: [0.5] };
      if (view === 'back') { F.head = [0, 0, 30 * k, 1, 0.8]; F.torso = [0, 0, 0, 1.04, 0.66 + 0.01 * b]; }
    }
  } else if (anim === 'sit_chair') {
    // 교의: 엉덩이 높이 ≈ 종아리 길이 — 허벅지가 앞으로 수평, 종아리는 아래로
    const drop = S.hip - S.shin - 6 * k;
    if (side) {
      F = { root: [0.03, 6 * k, drop], torso: [0.04, 0, 0, 1, 1 + 0.01 * b], head: [0.04 + 0.02 * b],
        leg2: [1.5], leg2_l: [-1.42], leg1: [1.45], leg1_l: [-1.4],
        arm2: [0.55], arm2_l: [0.75], arm1: [0.45], arm1_l: [0.8],
        skirt: robe ? [0.5, -4 * k, 0, 1.0, 0.66] : [0] };
    } else {
      F = { root: [0, 0, drop], torso: [0, 0, 0, 1, 1 + 0.01 * b], head: [0.02 * b],
        leg1: [0.18, 0, -S.thigh * 0.62, 1, 0.38], leg1_l: [-0.12], leg2: [-0.18, 0, -S.thigh * 0.62, 1, 0.38], leg2_l: [0.12],
        arm1: [0.18], arm1_l: [-0.7], arm2: [-0.18], arm2_l: [0.7],
        skirt: robe ? [0, 0, -2 * k, 1.25, 0.72] : [0] };
      if (view === 'back') F = null;
    }
  }
  if (!F) {
    // 뒤는 앞 자세의 좌우 반전
    const front = posePose('front', anim, t, rig);
    return mirror(front);
  }
  return toP({ ...staff, ...F });
}

/** 그림 수: 가만히 있는 자세라 한 주기 2장(숨쉬기) */
export function poseSpec(anim, spec) {
  const info = POSE_ANIMS[anim];
  if (!info) return spec;
  const n = 2, step = info.dur / n;
  return { kind: 'loop', times: [0, step], loopStart: 0, intro: 0, step, n, dur: info.dur, tBased: false };
}

/** kind(SPECS에 이미 있는 사람 종류)에 공용 자세를 단다. 이미 그 이름의 동작이 있는 리그(예: 웹 sit)는 덮어쓴다 */
export function installPoses(kind) {
  const rig = getRig(kind);
  if (rig._poses) return rig;
  rig._poses = true;
  rig.anims = { ...rig.anims, ...POSE_ANIMS };
  const base = rig.pose;
  rig.pose = (view, anim, t, rg, at, st) => (POSE_ANIMS[anim] ? posePose(view, anim, t, rg) : base(view, anim, t, rg, at, st));
  return rig;
}
