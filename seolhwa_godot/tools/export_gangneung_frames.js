// 강릉 「고개에 남은 종소리」 프레임 굽기 — 웹 굽기 엔진(frameCore.BakeBank, high)을 그대로 쓰고, 웹 코드(seolhwa/src)는 고치지 않는다.
//  사람 종류는 SPECS에 실행 중에만 더하고, 새 동작(ritual·give·float·drift·head_turn)은 리그의 pose를 감싸 여기서 정의한다.
//  - wolsim(월심, CHR_MAIN_008 — 무당 베이스 고유변형): 흰 저고리·남치마·붉은 고름·흰 머릿수건 + 손방울(놋쇠 방울 묶음·오색 천)
//      idle·walk·talk + ritual(방울을 치켜들고 흔드는 도무) · give(부적 건네기, 1회)
//  - thief(덕보, CHR_HUM_026 하인/머슴 → 마을 사람 변형): 칙칙한 저고리·검은 배자·머리띠·지게
//      idle·walk·run·talk + cower(붙잡혀 움츠림 — 웹 이야기 동작)
//  - spirit_m(잔영, CHR_CRE_004 '일반 잔영' 계열 SPIRIT_BASE): 흰 두루마기·갓의 옛 차림. Godot 쪽(spirit_char.gd)이 옅은 먹빛으로 그린다.
//      float(still/float) · drift(slow_walk) · head_turn(고개 돌림, 1회). flicker·appear·disappear는 Godot 셰이더가 한다.
// 결과: data/frames_gangneung.json + frames_gangneung_<kind>_<n>.png (data/는 git 제외 — 다시 구워야 한다)
// 실행: python3 tools/web_export_server.py 8770 → 브라우저로 http://localhost:8770/__tools/gangneung_bake.html
import { SPECS, getRig } from '/src/chars/rigs.js';
import * as fc from '/src/chars/frameCore.js';
import { Painter } from '/src/chars/painter.js';

const PEOPLE = {
  wolsim: { base: 'villager_f', over: { coat: '#eee8da', skirt: '#3d5a8a', goreum: '#a8443c', cuff: '#a8443c', collar: '#a8443c', scarf: '#f3efe6',
    carry: null, lip: '#9a3a32', cheek: 0.22, build: 0.96 }, bell: true,
    anims: ['idle', 'walk', 'talk', 'ritual', 'give'] },
  thief: { base: 'villager_m', over: { coat: '#b9a782', pants: '#c4b592', vest: '#4f4840', collar: '#6a5a44', daenim: '#4f4840', band: '#d9cfb8',
    back: 'jige', patch: '#8a7a5a', stubble: true, cheek: 0.16, build: 1.02, shoe: '#a88a55', legwrap: '#e2dac6' },
    anims: ['idle', 'walk', 'run', 'talk', 'cower'] },
  spirit_m: { base: 'elder', over: { coat: '#e9e7df', pants: '#ece9e0', collar: '#cfcbc0', goreum: '#d6d2c6', hat: 'gat', hair: 'sangtu',
    beard: false, wrinkles: false, stoop: 0, staff: null, pipe: false, robeLen: 108, browColor: null, cheek: 0.0, build: 0.95, shoe: '#3a3431' },
    anims: ['float', 'drift', 'head_turn'] },
};
// 새 동작 길이(loop면 반복 주기)
const NEW_ANIMS = { ritual: { dur: 0.8, loop: true }, give: { dur: 1.0 }, float: { dur: 3.0, loop: true }, drift: { dur: 2.4, loop: true }, head_turn: { dur: 1.2 } };

const SWAP = { arm1: 'arm2', arm2: 'arm1', arm1_l: 'arm2_l', arm2_l: 'arm1_l', leg1: 'leg2', leg2: 'leg1', leg1_l: 'leg2_l', leg2_l: 'leg1_l' };
const toP = (F) => {
  const P = {};
  for (const n in F) { const a = F[n]; P[n] = { r: a[0] || 0, x: a[1] || 0, y: a[2] || 0, sx: a[3] ?? 1, sy: a[4] ?? 1, a: a[5] ?? 1 }; }
  return P;
};
const mirror = (P) => {
  const Q = {};
  for (const n in P) { const p = P[n]; Q[SWAP[n] || n] = { r: -p.r, x: -p.x, y: p.y, sx: p.sx, sy: p.sy, a: p.a }; }
  return Q;
};
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const smooth = (u) => u * u * (3 - 2 * u);
const { sin, abs, max, PI } = Math;

/** 새 동작 자세(웹 anims.js humanStoryPose와 같은 꼴: 부위 [r, x, y, sx, sy, a]) */
function storyPose(view, anim, t, at, rig) {
  if (!NEW_ANIMS[anim]) return null;
  const k = rig.S.hip / 80;
  const side = view === 'side';
  let F;
  if (anim === 'ritual') {
    // 방울을 오른손에 치켜들고 흔든다. 무릎을 살짝 굽혔다 펴는 도무(제자리)
    const sh = sin((t / 0.4) * PI * 2), sw = sin((t / 0.8) * PI * 2);
    const bob = -3 * k * abs(sw);
    F = side
      ? { root: [0, 0, bob], torso: [-0.05 + 0.03 * sw], head: [-0.12], arm2: [2.55 + 0.18 * sh], arm2_l: [0.35 * sh], arm1: [0.55], arm1_l: [0.6], leg2: [0.08 * sw], leg1: [-0.08 * sw] }
      : { root: [0.03 * sw, 0, bob], torso: [0.04 * sw], head: [-0.05 * sw, 0, -1.5 * k], arm2: [-2.45 + 0.18 * sh], arm2_l: [0.3 * sh], arm1: [0.65], arm1_l: [0.45], leg1: [0.05 * sw], leg2: [0.05 * sw] };
  } else if (anim === 'give') {
    // 접은 부적을 두 손으로 내민다(1회, 끝 자세 유지)
    const u = smooth(clamp(at / 0.7, 0, 1));
    F = side
      ? { torso: [-0.14 * u], head: [0.12 * u], arm2: [1.35 * u + 0.1], arm2_l: [0.15 * u], arm1: [1.2 * u], arm1_l: [0.3 * u] }
      : { torso: [0, 0, 0, 1, 1 - 0.02 * u], head: [0, 0, 2 * k * u], arm2: [-0.45 * u, 0, 0, 1, 1 - 0.15 * u], arm2_l: [-1.0 * u], arm1: [0.45 * u, 0, 0, 1, 1 - 0.15 * u], arm1_l: [1.0 * u] };
  } else if (anim === 'float') {
    // 제자리에 떠 있음: 팔을 늘어뜨리고 고개를 숙였다. 아주 느린 오르내림
    const b = sin((t / 3.0) * PI * 2);
    F = side
      ? { root: [0, 0, -3 * k * (0.5 + 0.5 * b)], torso: [0.08], head: [0.22 + 0.03 * b], arm2: [0.12], arm2_l: [0.08], arm1: [0.06], arm1_l: [0.06], leg2: [0.03], leg1: [-0.03], skirt: [0.02 * b] }
      : { root: [0, 0, -3 * k * (0.5 + 0.5 * b)], head: [0.02 * b, 0, 3.5 * k], arm1: [0.1], arm1_l: [0.05], arm2: [-0.1], arm2_l: [-0.05], skirt: [0, 0, 0, 1 + 0.01 * b] };
  } else if (anim === 'drift') {
    // 느린 걸음: 발이 거의 안 떨어진다. 몸은 미끄러지듯
    const s = sin((t / 2.4) * PI * 2), b = sin((t / 1.2) * PI * 2);
    F = side
      ? { root: [0, 0, -2 * k * (0.5 + 0.5 * b)], torso: [0.1], head: [0.18], leg2: [0.2 * s], leg2_l: [-0.12 * max(0, s)], leg1: [-0.2 * s], leg1_l: [-0.12 * max(0, -s)], arm2: [0.1 - 0.06 * s], arm1: [0.06 + 0.06 * s], skirt: [0.06 * s] }
      : { root: [0.01 * s, 0, -2 * k * (0.5 + 0.5 * b)], head: [0, 0, 3 * k], leg1: [0.04 * s, 0, -2 * k * max(0, s)], leg2: [0.04 * s, 0, -2 * k * max(0, -s)], arm1: [0.1], arm2: [-0.1], skirt: [0.02 * s] };
  } else {
    // 고개 돌림(1회): 숙였던 고개를 들고 이쪽으로 돌린다
    const u = smooth(clamp(at / 0.9, 0, 1));
    F = side
      ? { torso: [0.08 - 0.06 * u], head: [0.22 - 0.42 * u, -3 * k * u], arm2: [0.12], arm1: [0.06] }
      : { head: [0.14 * u, 2.5 * k * u, (3.5 - 4.5 * u) * k, 1 - 0.06 * u], torso: [0.03 * u], arm1: [0.1], arm2: [-0.1] };
  }
  const P = toP(F);
  return view === 'back' ? mirror(P) : P;
}

/** 손방울: 짧은 손잡이 + 놋쇠 방울 일곱 + 오색 천(손 끝에 매달림, +y가 손에서 멀어지는 쪽) */
function bellPart(S) {
  const P = new Painter(256);
  P.begin(7);
  const ws = S.ws;
  P.poly([[-2.2, -4], [2.2, -4], [2, 22 * ws], [-2, 22 * ws]], '#86653f', { w: 1.3, smooth: false });
  for (let i = 0; i < 7; i++) {
    const a = (i / 7) * PI * 2, x = Math.cos(a) * 7 * ws, y = 28 * ws + Math.sin(a) * 4 * ws + (i % 2) * 3 * ws;
    P.ellipse(x, y, 4.2 * ws, 4.6 * ws, '#d0aa50', { w: 1.2 });
  }
  const OB = ['#3d5a8a', '#a8443c', '#e8d24a', '#f2ede0', '#2b2622'];
  for (let i = 0; i < 5; i++) P.poly([[-6 + i * 3, 2 * ws], [-4 + i * 3, 2 * ws], [-10 + i * 5, 52 * ws], [-13 + i * 5, 51 * ws]], OB[i], { w: 0.9 });
  return P.end();
}

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
  for (const kind in PEOPLE) {
    const P = PEOPLE[kind];
    const sp = { ...SPECS[P.base] };
    for (const k in P.over) { if (P.over[k] === null) delete sp[k]; else sp[k] = P.over[k]; }
    SPECS[kind] = sp;
    fc.TIERS.high[kind] = fc.TIERS.high.player;
    const rig = getRig(kind);
    rig.anims = { ...rig.anims, ...NEW_ANIMS };
    const base = rig.pose;
    rig.pose = (view, anim, t, rg, at, st) => storyPose(view, anim, t, at, rg) || base(view, anim, t, rg, at, st);
    if (P.bell) {
      const img = bellPart(rig.S);
      for (const v of ['front', 'side', 'back']) {
        const parts = rig.views[v];
        const hand = v === 'back' ? 'arm1_l' : 'arm2_l';
        parts.push({ name: 'bell', parent: hand, at: [0, rig.S.lArm + 2], r0: 0, z: v === 'side' ? 10.95 : 6.15, img: img.img, ox: img.ox, oy: img.oy, abs: true, tag: 'staff' });
        parts.draw = parts.filter((p) => p.img).map((p, i) => ({ p, i })).sort((a, b) => a.p.z - b.p.z || a.i - b.i).map((e) => e.p);
      }
    }
    const b = new fc.BakeBank(kind, 'high');
    const clips = {};
    for (const vw of ['front', 'side', 'back']) for (const a of P.anims) {
      const key = fc.clipKey(fc.resolveView(kind, vw, a), a, false, false);
      if (clips[key]) continue;
      const c = b.clip(key); if (!c) continue;
      let g = 0; while (!b.step(c) && g++ < 600);
      clips[key] = { spec: c.spec, frames: c.frames.map(meta) };
    }
    const pages = [];
    for (let i = 0; i < b.pages.length; i++) { const name = `frames_gangneung_${kind}_${i}.png`; await put(name, await toPng(b.pages[i].cv)); pages.push(name); }
    out[kind] = { pages, clips };
    log('baked ' + kind + ' pages=' + pages.length + ' clips=' + Object.keys(clips).length);
  }
  await put('frames_gangneung.json', JSON.stringify(out));
  log('done: ' + Object.keys(out).join(', '));
  console.log('[gangneung bake] done', Object.keys(out));
}
