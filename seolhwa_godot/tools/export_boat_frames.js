// 배 타기 프레임 굽기(scripts/region/boat_ride.gd) — 웹 굽기 엔진(frameCore.BakeBank, high)을 그대로 쓰고 웹 코드(seolhwa/src)는 고치지 않는다.
//  - boatman_row: 뱃사공(npc_bake boatman 차림, 삿갓·행전) + 긴 노/삿대(손에 붙는 부위 'oar').
//      idle(노를 쥐고 섬) · row(고물에서 노 젓기 — 몸을 앞뒤로 실어 민다, 1.8초 고리) · pole(삿대로 강바닥 밀기 — 짚고 밀며 걸어 나갔다 거둠, 2.6초 고리)
//  - player: sit(배 갑판에 앉기 — 웹 이야기 동작 sit). SpriteChar.merge_bank("frames_boat.json")가 플레이어 은행에 더한다.
// 결과: data/frames_boat.json + frames_boat_<kind>_<n>.png (data/는 git 제외 — 다른 맥에서는 다시 굽는다. 없으면 엔진은 ambient boatman 대기·걷기로 대신)
// 실행: python3 tools/web_export_server.py 8770 → http://localhost:8770/__tools/boat_bake.html
//   (헤드리스: "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" --headless=new --virtual-time-budget=120000 --dump-dom 그 주소 — 끝나면 <p id=st>done…)
import { SPECS, getRig } from '/src/chars/rigs.js';
import * as fc from '/src/chars/frameCore.js';
import { weaponPart, attachHand, stripCombatParts } from '/__tools/hum_combat_light.js';

const BOATMAN = { base: 'villager_m', over: { coat: '#d8ccaa', pants: '#cdbf9b', vest: null, collar: '#a8956d', daenim: '#8a7a5a', back: null, hat: 'satgat', hatColor: '#9c8457',
  legwrap: '#e8e0cb', staff: null, build: 1.1 } };
const BOAT_ANIMS = { row: { dur: 1.8, loop: true }, pole: { dur: 2.6, loop: true } };
const LOOP_N = { row: 8, pole: 10 };

const SWAP = { arm1: 'arm2', arm2: 'arm1', arm1_l: 'arm2_l', arm2_l: 'arm1_l', leg1: 'leg2', leg2: 'leg1', leg1_l: 'leg2_l', leg2_l: 'leg1_l' };
const toP = (F) => { const P = {}; for (const n in F) { const a = F[n]; P[n] = { r: a[0] || 0, x: a[1] || 0, y: a[2] || 0, sx: a[3] ?? 1, sy: a[4] ?? 1, a: a[5] ?? 1 }; } return P; };
const mirror = (P) => { const Q = {}; for (const n in P) { const p = P[n]; Q[SWAP[n] || n] = { r: -p.r, x: -p.x, y: p.y, sx: p.sx, sy: p.sy, a: p.a }; } return Q; };
const lerpF = (A, B, k) => { const O = {}; for (const n of new Set([...Object.keys(A), ...Object.keys(B)])) { const a = A[n] || [], b = B[n] || []; const L = Math.max(a.length, b.length, 1); O[n] = []; for (let j = 0; j < L; j++) { const d = j < 3 ? 0 : 1; const x = a[j] ?? d, y = b[j] ?? d; O[n].push(x + (y - x) * k); } } return O; };
const { sin, cos, PI } = Math;

// 노 젓기: 다리를 앞뒤로 벌리고 서서, 두 손으로 쥔 노(손 아래로 길게 물속까지)를 몸을 실어 민다(앞)·당긴다(뒤)
const S_ROW_A = { leg2: [0.3], leg2_l: [-0.1], leg1: [-0.32], leg1_l: [-0.06], root: [0, 3, 5], torso: [0.06], head: [0.02],
  arm2: [0.45], arm2_l: [1.55], arm1: [0.35], arm1_l: [1.6], oar: [-2.5] };
const S_ROW_B = { leg2: [0.48], leg2_l: [-0.32], leg1: [-0.2], leg1_l: [-0.02], root: [0, -10, 10], torso: [-0.28], head: [0.2],
  arm2: [1.25], arm2_l: [0.45], arm1: [1.1], arm1_l: [0.55], oar: [-2.45] };
const F_ROW_A = { root: [0, 0, 6], arm2: [-0.5], arm2_l: [-0.9], arm1: [0.25], arm1_l: [-1.3], oar: [0.4], head: [0, 0, 1] };
const F_ROW_B = { root: [0.03, 3, 9], torso: [0.05], arm2: [-0.2], arm2_l: [-1.2], arm1: [0.55], arm1_l: [-1.0], oar: [0.6], head: [0.05, 0, 3] };
// 삿대: 앞으로 뻗어 짚음 → 몸을 실어 뒤로 밀며 손을 내림 → 들어 올려 앞으로 거둠
const S_POLE = [
  [0, { leg2: [0.3], leg2_l: [-0.1], leg1: [-0.25], leg1_l: [-0.05], root: [0, 0, 4], torso: [0.05], arm2: [1.9], arm2_l: [0.2], arm1: [1.6], arm1_l: [0.4], oar: [-1.75] }],
  [0.2, { leg2: [0.5], leg2_l: [-0.2], leg1: [-0.35], leg1_l: [-0.05], root: [0, -6, 8], torso: [-0.18], head: [0.1], arm2: [1.25], arm2_l: [0.25], arm1: [1.0], arm1_l: [0.45], oar: [-1.05] }],
  [0.6, { leg2: [0.65], leg2_l: [-0.35], leg1: [-0.5], leg1_l: [-0.1], root: [0, -14, 13], torso: [-0.42], head: [0.25], arm2: [0.35], arm2_l: [0.3], arm1: [0.15], arm1_l: [0.4], oar: [-0.2] }],
  [0.8, { leg2: [0.4], leg2_l: [-0.15], leg1: [-0.3], leg1_l: [-0.05], root: [0, -4, 7], torso: [-0.1], head: [0.08], arm2: [1.2], arm2_l: [0.9], arm1: [1.0], arm1_l: [1.0], oar: [-1.2] }],
  [1, null],
];
S_POLE[4][1] = S_POLE[0][1];
const F_POLE = [
  [0, { root: [0, 0, 4], arm2: [-1.4], arm2_l: [-0.9], arm1: [-0.2], arm1_l: [-1.4], oar: [0.7], head: [0, 0, -1] }],
  [0.6, { root: [0, 0, 11], torso: [0.06], arm2: [-0.2], arm2_l: [-1.1], arm1: [0.5], arm1_l: [-1.0], oar: [0.4], head: [0.05, 0, 4] }],
  [1, null],
];
F_POLE[2][1] = F_POLE[0][1];
const HIDE = { r: 0, x: 0, y: 0, sx: 1, sy: 1, a: 0 };

function keyed(frames, u) {
  let i = 0;
  while (i < frames.length - 2 && u >= frames[i + 1][0]) i++;
  const [t0, A] = frames[i], [t1, B] = frames[i + 1];
  const k = (u - t0) / Math.max(1e-6, t1 - t0);
  return lerpF(A, B, k * k * (3 - 2 * k));
}

function boatPose(view, anim, t) {
  const info = BOAT_ANIMS[anim];
  if (!info) return null;
  const side = view === 'side';
  const u = ((t / info.dur) % 1 + 1) % 1;
  let F;
  if (anim === 'row') {
    const k = 0.5 - 0.5 * cos(u * PI * 2);
    F = side ? lerpF(S_ROW_A, S_ROW_B, k) : lerpF(F_ROW_A, F_ROW_B, k);
  } else {
    F = keyed(side ? S_POLE : F_POLE, u);
  }
  const P = toP(F);
  return view === 'back' ? mirror(P) : P;
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

async function bake(kind, anims, prefix, fixSpec) {
  const b = new fc.BakeBank(kind, 'high');
  const clips = {};
  for (const vw of ['front', 'side', 'back']) for (const a of anims) {
    const key = fc.clipKey(fc.resolveView(kind, vw, a), a, false, false);
    if (clips[key]) continue;
    const c = b.clip(key); if (!c) continue;
    if (fixSpec) c.spec = fixSpec(a, c.spec);
    let g = 0; while (!b.step(c) && g++ < 600);
    clips[key] = { spec: c.spec, frames: c.frames.map(meta) };
  }
  const pages = [];
  for (let i = 0; i < b.pages.length; i++) { const name = `${prefix}_${i}.png`; await put(name, await toPng(b.pages[i].cv)); pages.push(name); }
  return { pages, clips };
}

export async function run(log) {
  const out = {};
  // ---- 뱃사공 ----
  const sp = { ...SPECS[BOATMAN.base] };
  for (const k in BOATMAN.over) { if (BOATMAN.over[k] === null) delete sp[k]; else sp[k] = BOATMAN.over[k]; }
  SPECS.boatman_row = sp;
  fc.TIERS.high.boatman_row = fc.TIERS.high.player;
  const rig = getRig('boatman_row');
  rig.anims = { ...rig.anims, ...BOAT_ANIMS };
  const base = rig.pose;
  rig.pose = (view, anim, t, rg, at, st) => {
    const P = boatPose(view, anim, t) || base(view, anim, t, rg, at, st);
    if (!BOAT_ANIMS[anim] && anim !== 'idle') P.oar = { ...HIDE };
    if (anim === 'idle') { P.oar = toP({ oar: [view === 'side' ? -2.6 : 2.9] }).oar; }
    return P;
  };
  stripCombatParts(rig);
  attachHand(rig, 'oar', weaponPart(rig.S, 'pole'), 'weapon', false);
  out.boatman_row = await bake('boatman_row', ['idle', 'row', 'pole'], 'frames_boat_boatman', (a, spec) => {
    if (!BOAT_ANIMS[a]) return spec;
    const n = LOOP_N[a], step = BOAT_ANIMS[a].dur / n;
    return { kind: 'loop', times: [...Array(n).keys()].map((k) => k * step), loopStart: 0, intro: 0, step, n, dur: BOAT_ANIMS[a].dur, tBased: true };
  });
  log('baked boatman_row pages=' + out.boatman_row.pages.length);
  // ---- 플레이어 앉기 ----
  out.player = await bake('player', ['sit'], 'frames_boat_player');
  log('baked player sit pages=' + out.player.pages.length);
  await put('frames_boat.json', JSON.stringify(out));
  log('done: ' + Object.keys(out).join(', '));
  console.log('[boat bake] done', Object.keys(out));
}
