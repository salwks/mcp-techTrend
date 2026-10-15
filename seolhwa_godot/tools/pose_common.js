// 공용 자세(사람 누구나): 앉기(sit) · 절(bow) · 꿇어앉기(kneel) — 관아·잔치·제사에 두루 쓴다(춘향 PART II 준비 2026-10-11).
// 웹 굽기 엔진(frameCore.BakeBank)에 붙이는 확장이다 — 웹 코드(seolhwa/src)는 고치지 않는다(hum_combat_light.js와 같은 방식).
//   installPoses(kind): 그 종류의 리그에 세 동작(+ 교의에 앉기 sit_chair — 원하는 종류만)을 더한다.
//   poseSpec(anim, spec): 그림 수를 고친다 — 가만히 있는 자세라 한 주기 2장(숨쉬기)만.
// 자세(그림 원점 = 발 사이 땅, 앞모습 기준 / 옆모습은 왼쪽을 본다):
//   sit   — 양반다리(방석·마루에 앉음): 엉덩이가 땅에서 한 뼘, 무릎이 앞으로, 손은 무릎 위. 치마·두루마기 자락은 땅에 퍼진다.
//   bow   — 선 채 허리를 깊이 굽힌 절(국궁): 두 손을 앞에 모으고 고개를 숙인다.
//   kneel — 꿇어앉기: 무릎을 꿇고 발뒤꿈치 위에 앉아 몸을 앞으로 숙이고 고개를 떨군다(관아 마당·출두 때 엎드림).
//   sit_chair — 교의(의자)에 앉기: 허벅지가 앞으로, 종아리는 아래로(변학도 대청 자리).
//   sit_seat — 평상·걸상·의자처럼 높은 자리에 앉기(sit_chair와 같은 자세, 빌더 이름)
//   sit(땅): sp.sitStyle === 'knee'(빌더 여자)면 한쪽 무릎을 세우고 다른 다리는 접어 앉는다(조선 여인 앉음새). 없으면 양반다리(예전 그대로)
//   sit_down·stand_up — 서기 ↔ 땅에 앉기 사이(한 번, 7장): 대기 자세와 sit 자세를 고르게 섞는다
//   jump — 웅크림(예비) → 박차기 → 공중(다리 접고 팔 위로) → 착지 눌림 → 서기(한 번, 10장). 앞·옆·뒤. 그림 lift가 높이를 알려 그림자가 옅어진다
// Godot 쪽: data/frames_pose.json(굽기 세트 ?set=poses)이 모든 사람 종류에 이 클립을 더한다(SpriteChar.ensure_poses — 처음 쓸 때).
import { getRig } from '/src/chars/rigs.js';

export const POSE_ANIMS = {
  sit: { dur: 3.2, loop: true }, bow: { dur: 3.0, loop: true }, kneel: { dur: 3.4, loop: true }, sit_chair: { dur: 3.2, loop: true },
  // 인물 빌더(2026-10-15): 높은 자리(평상·걸상·의자)에 앉기 · 앉는 중/일어나는 중(한 번) · 뛰어오르기(한 번)
  sit_seat: { dur: 3.2, loop: true }, sit_down: { dur: 0.7 }, stand_up: { dur: 0.7 }, jump: { dur: 0.9 },
  // 앉아서 하는 일(장꾼·주막 손님): 앉아 손짓하며 부르기/말하기 · 앉아 물건 매만지기·먹기(손을 앞 아래로 뻗었다 가슴께로) · 쪼그려 앉기(관아 앞 기다림)
  sit_talk: { dur: 2.4, loop: true, n: 4 }, sit_work: { dur: 2.8, loop: true, n: 4 }, squat: { dur: 3.0, loop: true },
};
const ONCE_TIMES = { jump: [0, 0.14, 0.25, 0.33, 0.43, 0.53, 0.63, 0.72, 0.8, 0.9], sit_down: [0, 0.12, 0.24, 0.36, 0.48, 0.6, 0.7], stand_up: [0, 0.12, 0.24, 0.36, 0.48, 0.6, 0.7] };
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
  const act = anim === 'sit_talk' || anim === 'sit_work' ? anim : null;   // 앉은 자세 위에 팔을 덧씌움
  if (act) anim = 'sit';
  let F;
  if (anim === 'sit' && sp.sitStyle === 'knee') {
    // 여인 앉음새: 가까운(앞) 무릎을 세우고 먼 다리는 접어 깔고, 세운 무릎 위에 팔을 얹는다. 치마가 땅에 퍼진다
    const drop = S.hip - 17 * k;
    if (side) {
      F = { root: [0.02, 4 * k, drop], torso: [-0.1, 0, 0, 1, 1 + 0.012 * b], head: [0.06 + 0.02 * b],
        leg2: [1.0], leg2_l: [-2.25], leg1: [1.42], leg1_l: [-2.95],
        arm2: [0.75], arm2_l: [0.55], arm1: [0.4], arm1_l: [0.6],
        skirt: chima ? [0.42, -3 * k, -2 * k, 1.35, 0.46] : robe ? [0.45, -4 * k, -2 * k, 1.12, 0.46] : [0] };
    } else {
      // 앞: 세운 무릎(화면 오른쪽 다리)은 카메라 쪽으로 짧게 솟고, 왼쪽 다리는 접혀 옆으로
      F = { root: [0, 0, drop], torso: [0, 0, 0, 1, 1 + 0.012 * b], head: [0.03 + 0.02 * b],
        leg1: [1.2, 0, -6 * k, 1, 0.82], leg1_l: [-2.1, 0, 0, 1, 0.6], leg2: [-0.25, 0, -14 * k, 1, 0.42], leg2_l: [0.15, 0, 0, 1, 0.55],
        arm1: [0.18], arm1_l: [-0.5], arm2: [-0.12, 0, 0, 1, 0.85], arm2_l: [0.55, 0, 0, 1, 0.75],
        skirt: chima ? [0, 0, -4 * k, 1.7, 0.5] : robe ? [0, 0, -2 * k, 1.4, 0.55] : [0] };
      if (view === 'back') F = null;
    }
  } else if (anim === 'sit') {
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
  } else if (anim === 'squat') {
    // 쪼그려 앉기: 엉덩이가 발뒤꿈치 가까이, 무릎은 가슴 앞, 팔은 무릎 위
    const drop = S.hip - 34 * k;
    if (side) {
      F = { root: [0.05, 8 * k, drop], torso: [-0.38, 0, 0, 1, 1 + 0.01 * b], head: [0.25 + 0.02 * b],
        leg2: [1.95], leg2_l: [-2.55], leg1: [1.85], leg1_l: [-2.5], arm2: [0.95], arm2_l: [0.55], arm1: [0.85], arm1_l: [0.6],
        skirt: chima ? [0.5, -4 * k, -4 * k, 1.25, 0.5] : robe ? [0.6, -4 * k, -4 * k, 1.05, 0.5] : [0] };
    } else {
      F = { root: [0, 0, drop], torso: [0, 0, 0, 1, 0.9 + 0.01 * b], head: [0, 0, 5 * k],
        leg1: [0.4, 0, -4 * k, 1, 0.36], leg1_l: [-0.3, 0, 0, 1, 0.8], leg2: [-0.4, 0, -4 * k, 1, 0.36], leg2_l: [0.3, 0, 0, 1, 0.8],
        arm1: [-0.05, 0, 0, 1, 0.78], arm1_l: [-0.45, 0, 0, 1, 0.6], arm2: [0.05, 0, 0, 1, 0.78], arm2_l: [0.45, 0, 0, 1, 0.6],
        skirt: chima ? [0, 0, -4 * k, 1.6, 0.48] : robe ? [0, 0, -2 * k, 1.35, 0.52] : [0] };
      if (view === 'back') F = null;
    }
  } else if (anim === 'jump') {
    F = jumpPose(view, t, S, k, chima, robe);
  } else if (anim === 'sit_chair' || anim === 'sit_seat') {
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
      // sit_seat(빌더): 종아리는 허벅지의 짧아짐(0.38)을 물려받지 않게 되돌려 땅까지 보인다(sit_chair는 예전 그림 그대로)
      if (anim === 'sit_seat') { F.leg1_l = [-0.06, 0, 0, 1, 1 / 0.38]; F.leg2_l = [0.06, 0, 0, 1, 1 / 0.38]; }
      if (view === 'back') F = null;
    }
  }
  if (!F) {
    // 뒤는 앞 자세의 좌우 반전
    const front = posePose('front', act || anim, t, rig);
    return mirror(front);
  }
  if (act) {
    const u = (t / POSE_ANIMS[act].dur) * PI * 2, g = sin(u), g2 = sin(u * 2);
    if (act === 'sit_talk') {
      // 부르기·말하기: 한 손을 들어 손바닥을 보이고 고개를 끄덕인다. 부채·담뱃대·국자는 손에 보인다
      if (side) { F.arm2 = [0.55 + 0.15 * g]; F.arm2_l = [0.95 + 0.3 * g]; F.head = [0.08 + 0.06 * g2]; }
      else { F.arm1 = [0.28 + 0.08 * g]; F.arm1_l = [0.7 + 0.3 * g, 0, 0, 1, 0.8]; F.head = [0.04 * g2]; }
      if (sp.handSmall) F.staff = [0, 0, 0, 1, 1, 1];
    } else {
      // 매만지기·먹기: 몸을 앞으로 숙여 손을 앞 아래(물건·소반)로 뻗었다가 가슴께로 가져온다(두 손이 엇갈려)
      const w = 0.5 + 0.5 * g, w2 = 0.5 - 0.5 * g;
      if (side) {
        F.torso = [-0.16 - 0.1 * w, 0, 0, 1, 1]; F.head = [0.12 + 0.08 * w];
        F.arm2 = [0.7 + 0.5 * w]; F.arm2_l = [0.25 + 1.0 * w2]; F.arm1 = [0.6 + 0.4 * w2]; F.arm1_l = [0.3 + 0.8 * w];
      } else {
        F.torso = [0, 0, 0, 1, 0.95 - 0.04 * w]; F.head = [0, 0, 3 * k * w];
        F.arm1 = [-0.08, 0, 0, 1, 0.82 - 0.1 * w]; F.arm1_l = [-0.35 - 0.3 * w2, 0, 0, 1, 0.55 + 0.2 * w2];
        F.arm2 = [0.08, 0, 0, 1, 0.82 - 0.1 * w2]; F.arm2_l = [0.35 + 0.3 * w, 0, 0, 1, 0.55 + 0.2 * w];
      }
    }
  }
  return toP({ ...staff, ...F });
}

// 뛰어오르기: u(0~1) 구간 — 웅크림 0~0.3 · 박차기 0.3~0.4 · 공중 0.4~0.78 · 착지 눌림 0.78~0.88 · 서기
function jumpPose(view, t, S, k, chima, robe) {
  const u = Math.min(1, Math.max(0, t / POSE_ANIMS.jump.dur));
  const sm = (a, b, x) => { const v = Math.min(1, Math.max(0, (x - a) / (b - a))); return v * v * (3 - 2 * v); };
  const crouch = sm(0, 0.28, u) * (1 - sm(0.3, 0.4, u));                 // 예비 웅크림
  const land = sm(0.76, 0.81, u) * (1 - sm(0.82, 1, u)) * 0.75;          // 착지 눌림
  const q = Math.max(crouch, land);
  const air = u > 0.38 && u < 0.79 ? sin(PI * (u - 0.38) / 0.41) : 0;    // 공중 높이(0~1)
  const H = 40 * k * air;                                                // 위로(px) — 그림 높이 약 0.45m(배율 적용)
  const tuck = air * (chima || robe ? 0.35 : 0.9);   // 긴 옷(치마·두루마기)은 무릎을 덜 접는다 — 자락이 앞으로 크게 밀려 둥근 판처럼 보이지 않게
  // 팔(앞뒤): 웅크릴 때 뒤로, 박찰 때 앞·위로 크게, 공중에서 내려오고, 착지 때 앞으로 받침
  const armA = -0.75 * crouch + 2.3 * sm(0.3, 0.45, u) * (1 - sm(0.5, 0.8, u)) + 0.6 * sm(0.5, 0.8, u) * (1 - sm(0.85, 1, u)) + 0.35 * land;
  if (view === 'side') {
    return { root: [0.03 * q, 0, 18 * k * q - H], torso: [-0.42 * q - 0.08 * air], head: [0.18 * q - 0.1 * air],
      leg2: [0.95 * q + 0.75 * tuck], leg2_l: [-1.7 * q - 1.3 * tuck], leg1: [0.85 * q + 0.5 * tuck - 0.1 * air], leg1_l: [-1.6 * q - 1.0 * tuck],
      arm2: [armA], arm2_l: [0.25 + 0.2 * air - 0.35 * crouch], arm1: [armA * 0.92 - 0.05], arm1_l: [0.3 + 0.2 * air - 0.4 * crouch],
      skirt: [chima || robe ? -0.12 * q - 0.1 * air : 0, 0, 0, 1 + 0.08 * air, 1 - 0.1 * air] };
  }
  // 앞: 무릎을 굽히면 다리가 짧아지고(카메라 쪽으로 접힘) 조금 벌어진다. 팔은 웅크릴 때 뒤(짧게)로, 공중에서 양옆 위로
  const up = Math.max(0, armA);
  return { root: [0, 0, 18 * k * q - H], torso: [0, 0, 0, 1, 1 - 0.12 * q], head: [0, 0, 4 * k * q],
    leg1: [0.16 * q + 0.1 * tuck, 0, -4 * k * tuck, 1, 1 - 0.32 * q - 0.3 * tuck], leg1_l: [-0.1 * q, 0, 0, 1, 1 - 0.25 * q - 0.3 * tuck],
    leg2: [-0.16 * q - 0.1 * tuck, 0, -4 * k * tuck, 1, 1 - 0.32 * q - 0.3 * tuck], leg2_l: [0.1 * q, 0, 0, 1, 1 - 0.25 * q - 0.3 * tuck],
    arm1: [0.12 * crouch + 0.95 * up, 0, 0, 1, 1 - 0.12 * crouch - 0.15 * up], arm1_l: [0.25 * up], arm2: [-0.12 * crouch - 0.95 * up, 0, 0, 1, 1 - 0.12 * crouch - 0.15 * up], arm2_l: [-0.25 * up],
    skirt: [0, 0, 0, 1 + 0.15 * air, 1 - 0.08 * air] };
}

/** 두 자세 섞기(sit_down·stand_up): a → b, w(0~1) */
function blend(a, b, w) {
  const out = {};
  const D = { r: 0, x: 0, y: 0, sx: 1, sy: 1, a: 1 };
  for (const n of new Set([...Object.keys(a), ...Object.keys(b)])) {
    const p = a[n] || { ...D, a: b[n].a }, q = b[n] || { ...D, a: p.a };
    out[n] = { r: p.r + (q.r - p.r) * w, x: p.x + (q.x - p.x) * w, y: p.y + (q.y - p.y) * w, sx: p.sx + (q.sx - p.sx) * w, sy: p.sy + (q.sy - p.sy) * w, a: w < 0.5 ? (p.a ?? 1) : (q.a ?? 1) };
  }
  return out;
}

/** 그림 수: 가만히 있는 자세라 한 주기 2장(숨쉬기). 한 번 동작(jump·sit_down·stand_up)은 정한 시각들 */
export function poseSpec(anim, spec) {
  const info = POSE_ANIMS[anim];
  if (!info) return spec;
  if (!info.loop) { const times = ONCE_TIMES[anim]; return { kind: 'once', times, dur: info.dur }; }
  if (info.n) { const st = info.dur / info.n; return { kind: 'loop', times: [...Array(info.n).keys()].map((i) => i * st), loopStart: 0, intro: 0, step: st, n: info.n, dur: info.dur, tBased: false }; }
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
  rig.pose = (view, anim, t, rg, at, st) => {
    if (anim === 'sit_down' || anim === 'stand_up') {
      const u = Math.min(1, Math.max(0, t / POSE_ANIMS[anim].dur)), e = u * u * (3 - 2 * u);
      const stand = base(view, 'idle', 0, rg, 0, {}), sit = posePose(view, 'sit', 0, rg);
      return blend(stand, sit, anim === 'sit_down' ? e : 1 - e);
    }
    return POSE_ANIMS[anim] ? posePose(view, anim, t, rg) : base(view, anim, t, rg, at, st);
  };
  return rig;
}
