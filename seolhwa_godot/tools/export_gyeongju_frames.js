// 경주 「세 번째 등불」 프레임 굽기 — 웹 굽기 엔진(frameCore.BakeBank, high)을 그대로 쓰고, 웹 코드(seolhwa/src)는 고치지 않는다.
//  사람 종류는 SPECS에 실행 중에만 더하고, 새 동작은 리그의 pose를 감싸 여기(와 hum_combat_light.js)서 정의한다.
//  - smuggler(밀수꾼, CHR_HUM_027 객주 일꾼/짐꾼 → 경비 변형): 짙은 먹빛 저고리·배자·붉은 머리띠·행전 + 몽둥이
//      idle·walk·run + HUM_COMBAT_LIGHT ready·swing·hit·fall·flee(tools/hum_combat_light.js) + tied(묶임 — 웹 이야기 동작)
//  - smuggler_b(밀수꾼 둘째, 같은 변형 — 뱃사람 차림): 누런 저고리·검은 머리띠 + 장대. idle·walk·run + ready·thrust·hit·fall·flee
//    (무기마다 쓰는 공격 하나만 굽는다 — 페이지를 아낀다. 둘 다 쓰는 weapon 'both' 종류면 swing·thrust를 같이)
//  - lantern_wife(치술령 아래 마을 아낙, CHR_HUM_010 아낙 변형): 수수한 무명옷·흰 머릿수건 + 손에 든 등롱. idle·walk·talk·cry
//  - charcoal_man(숯쟁이 — 사라진 남편, CHR_HUM_019 나무꾼 변형): 검댕 묻은 잿빛 저고리. idle·walk·talk·tied·sit
//  - spirit_f(세 번째 불빛 곁의 형체, CHR_CRE_004 '일반 잔영' 계열 SPIRIT_BASE — 여인 차림): 흰 옷·흰 쓰개. float·head_turn.
//      깜빡임·나타남·사라짐은 Godot 셰이더(spirit_char.gd)가 한다. 정체는 확정하지 않는다(§1.4).
// 결과: data/frames_gyeongju.json + frames_gyeongju_<kind>_<n>.png (data/는 git 제외 — 다시 구워야 한다)
// 실행: python3 tools/web_export_server.py 8770 → 브라우저로 http://localhost:8770/__tools/gyeongju_bake.html
//   (헤드리스: Chromium 계열 --headless=new --virtual-time-budget=120000 --dump-dom 그 주소 — 끝나면 <p id=st>done…)
import { SPECS, getRig } from '/src/chars/rigs.js';
import * as fc from '/src/chars/frameCore.js';
import { installHCL, hclSpec, lanternPart, attachHand } from '/__tools/hum_combat_light.js';

const PEOPLE = {
  smuggler: { base: 'villager_m', over: { coat: '#3f3c38', pants: '#5c574d', vest: '#262422', collar: '#262422', daenim: '#262422', band: '#8a3a30',
    back: null, patch: null, legwrap: '#d6cfbd', stubble: true, cheek: 0.12, build: 1.14, shoe: '#5a4a38' }, hcl: 'club',
    anims: ['idle', 'walk', 'run', 'ready', 'swing', 'hit', 'fall', 'flee', 'tied'] },
  smuggler_b: { base: 'villager_m', over: { coat: '#9a8a68', pants: '#7c705a', vest: null, collar: '#4a4036', daenim: '#4a4036', band: '#2b2622',
    back: null, patch: '#6f6150', legwrap: '#cfc6b0', stubble: true, cheek: 0.16, build: 1.06, shoe: '#5a4a38' }, hcl: 'pole',
    anims: ['idle', 'walk', 'run', 'ready', 'thrust', 'hit', 'fall', 'flee'] },
  lantern_wife: { base: 'villager_f', over: { coat: '#e2dccb', skirt: '#5e6a73', goreum: '#7a5a4c', cuff: '#7a5a4c', collar: '#7a5a4c', scarf: '#efe9da',
    carry: null, cheek: 0.2, build: 0.93 }, lantern: true,
    anims: ['idle', 'walk', 'talk', 'cry'] },
  charcoal_man: { base: 'villager_m', over: { coat: '#7a746a', pants: '#8e877a', vest: '#3b3733', collar: '#3b3733', daenim: '#3b3733', band: '#5a5148',
    back: null, patch: '#4b4640', stubble: true, cheek: 0.1, build: 1.04, shoe: '#4a3f33' },
    anims: ['idle', 'walk', 'talk', 'tied', 'sit'] },
  spirit_f: { base: 'villager_f', over: { coat: '#efece4', skirt: '#e8e5dc', goreum: '#d6d2c6', cuff: '#d6d2c6', collar: '#d6d2c6', scarf: '#f4f1ea',
    carry: null, cheek: 0.0, lip: '#b9aea0', build: 0.92 }, spirit: true,
    anims: ['float', 'head_turn'] },
};
const SPIRIT_ANIMS = { float: { dur: 3.2, loop: true }, head_turn: { dur: 1.3 } };
const SWAP = { arm1: 'arm2', arm2: 'arm1', arm1_l: 'arm2_l', arm2_l: 'arm1_l', leg1: 'leg2', leg2: 'leg1', leg1_l: 'leg2_l', leg2_l: 'leg1_l' };
const toP = (F) => { const P = {}; for (const n in F) { const a = F[n]; P[n] = { r: a[0] || 0, x: a[1] || 0, y: a[2] || 0, sx: a[3] ?? 1, sy: a[4] ?? 1, a: a[5] ?? 1 }; } return P; };
const mirror = (P) => { const Q = {}; for (const n in P) { const p = P[n]; Q[SWAP[n] || n] = { r: -p.r, x: -p.x, y: p.y, sx: p.sx, sy: p.sy, a: p.a }; } return Q; };
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const smooth = (u) => u * u * (3 - 2 * u);
const { sin, PI } = Math;

/** 형체(SPIRIT_BASE 여인): 떠 있음(손을 모으고 먼 데를 봄) · 고개 돌림(1회) */
function spiritPose(view, anim, t, at, rig) {
  if (!SPIRIT_ANIMS[anim]) return null;
  const k = rig.S.hip / 80;
  const side = view === 'side';
  let F;
  if (anim === 'float') {
    const b = sin((t / 3.2) * PI * 2);
    F = side
      ? { root: [0, 0, -3 * k * (0.5 + 0.5 * b)], torso: [0.04], head: [-0.06 + 0.02 * b], arm2: [0.35], arm2_l: [0.7], arm1: [0.3], arm1_l: [0.7], skirt: [0.02 * b] }
      : { root: [0, 0, -3 * k * (0.5 + 0.5 * b)], head: [0.02 * b, 0, -1 * k], arm1: [0.35], arm1_l: [-0.9], arm2: [-0.35], arm2_l: [0.9], skirt: [0, 0, 0, 1 + 0.01 * b] };
  } else {
    const u = smooth(clamp(at / 1.0, 0, 1));
    F = side
      ? { torso: [0.04 - 0.04 * u], head: [-0.06 + 0.1 * u, -3 * k * u], arm2: [0.35], arm2_l: [0.7], arm1: [0.3], arm1_l: [0.7] }
      : { head: [0.14 * u, 2.5 * k * u, (-1 + 2.5 * u) * k, 1 - 0.06 * u], torso: [0.03 * u], arm1: [0.35], arm1_l: [-0.9], arm2: [-0.35], arm2_l: [0.9] };
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

export async function run(log) {
  const out = {};
  const only = new URLSearchParams(location.search).get('only');
  for (const kind in PEOPLE) {
    if (only && !only.split(',').includes(kind)) continue;
    const P = PEOPLE[kind];
    const sp = { ...SPECS[P.base] };
    for (const k in P.over) { if (P.over[k] === null) delete sp[k]; else sp[k] = P.over[k]; }
    SPECS[kind] = sp;
    fc.TIERS.high[kind] = fc.TIERS.high.player;
    let rig;
    if (P.hcl) rig = installHCL(kind, { weapon: P.hcl });
    else rig = getRig(kind);
    if (P.spirit) {
      rig.anims = { ...rig.anims, ...SPIRIT_ANIMS };
      const base = rig.pose;
      rig.pose = (view, anim, t, rg, at, st) => spiritPose(view, anim, t, at, rg) || base(view, anim, t, rg, at, st);
    }
    if (P.lantern) attachHand(rig, 'lantern', lanternPart(rig.S), 'lantern');
    const b = new fc.BakeBank(kind, 'high');
    const clips = {};
    for (const vw of ['front', 'side', 'back']) for (const a of P.anims) {
      const key = fc.clipKey(fc.resolveView(kind, vw, a), a, false, false);
      if (clips[key]) continue;
      const c = b.clip(key); if (!c) continue;
      c.spec = hclSpec(a, c.spec);
      let g = 0; while (!b.step(c) && g++ < 600);
      clips[key] = { spec: c.spec, frames: c.frames.map(meta) };
    }
    const pages = [];
    for (let i = 0; i < b.pages.length; i++) { const name = `frames_gyeongju_${kind}_${i}.png`; await put(name, await toPng(b.pages[i].cv)); pages.push(name); }
    out[kind] = { pages, clips };
    log('baked ' + kind + ' pages=' + pages.length + ' clips=' + Object.keys(clips).length);
  }
  await put(only ? `frames_gyeongju_${only.replace(/,/g, '_')}.json` : 'frames_gyeongju.json', JSON.stringify(out));
  log('done: ' + Object.keys(out).join(', '));
  console.log('[gyeongju bake] done', Object.keys(out));
}
