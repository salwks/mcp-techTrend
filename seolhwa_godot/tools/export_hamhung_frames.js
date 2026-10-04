// 함흥 「돌아오지 않는 전갈」(ACT 4, S6001~S6010) 프레임 굽기 — 웹 굽기 엔진(frameCore.BakeBank, high)을 그대로 쓰고 웹 코드(seolhwa/src)는 고치지 않는다.
//  사람 종류는 SPECS에 실행 중에만 더하고, 새 동작은 리그의 pose를 감싸 여기서 정의한다(경주 export_gyeongju_frames.js와 같은 꼴).
//  - yigyeom(이겸, CHR_MAIN_002 — 스승. 전직 말단 서리, 팔도를 떠도는 기록자): 노인 베이스. 바랜 잿빛 쪽빛 두루마기·짙은 깃,
//      낡은 검은 갓, 흰 머리·수염, 등에 책 보따리, 지팡이(앉거나 손을 쓸 때는 내려놓음), 먹 묻은 오른 소매.
//      idle·walk·talk·sit + 이 사건 동작 write(앉아 붓으로 적기) · burn(앉아 화로에 종이를 한 장씩 넣기 — 종이가 타 들어가 사라짐)
//      · read(서서 종이를 두 손으로 들고 살핌)
//  - courier(막동 — 첫째 전갈꾼, 역졸 차림: 벙거지·검은 쾌자 대신 짙은 쪽빛 저고리·붉은 띠·흰 행전): idle·walk·talk·sit·cower
//  - courier_b(갑술 — 둘째, 수레를 지키던 전갈꾼 — 같은 차림, 밤색 저고리): idle·walk·talk·sit·cower·tied
//  - courier_c(순돌 — 셋째, 가장 젊다 — 벙거지 없이 머리띠, 얇은 옷): idle·walk·talk·sit·cower
//  - raider(북청길 수레 도적 — 털 배자·누런 머리띠·몽둥이): idle·walk·run + HUM_COMBAT_LIGHT ready·swing·hit·fall·flee + tied
//  - raider_b(도적 둘째 — 개털 모자 없이 검은 두건, 장대): idle·walk·run + ready·thrust·hit·fall·flee
// 결과: data/frames_story_hamhung.json + frames_story_hamhung_<kind>_<n>.png (data/는 git 제외 — 새 맥에서 다시 굽는다)
// 실행: python3 tools/web_export_server.py 8770 → http://localhost:8770/__tools/hamhung_bake.html (?only=yigyeom 처럼 일부만)
//   헤드리스: Chromium 계열 --headless=new --virtual-time-budget=900000 --dump-dom 그 주소 → <p id=st>done…
import { SPECS, getRig } from '/src/chars/rigs.js';
import { Painter } from '/src/chars/painter.js';
import * as fc from '/src/chars/frameCore.js';
import { installHCL, hclSpec, attachHand } from '/__tools/hum_combat_light.js';

const PEOPLE = {
  yigyeom: { base: 'elder', over: { top: 'durumagi', coat: '#77808a', pants: '#cfc8b6', collar: '#353a40', goreum: '#353a40', sash: null,
    hat: 'gat', hatColor: '#26221f', hair: 'white', beard: true, wrinkles: true, stoop: 0.14, staff: 'cane', pipe: false,
    back: 'bundle', bundle: '#6e5a42', patch: '#9a9384', shoe: '#3a3431', robeLen: 100, browColor: '#8e897f', browW: 2.8, cheek: 0.1, build: 0.92, height: 1.62 },
    scribe: true,
    anims: ['idle', 'walk', 'talk', 'sit', 'write', 'burn', 'read'] },
  courier: { base: 'villager_m', over: { coat: '#3b4658', pants: '#d8d0bc', vest: '#262a33', collar: '#262a33', daenim: '#262a33', sash: '#a8443c',
    hat: 'beonggeoji', hatColor: '#2b2622', back: null, patch: '#e9e6de', legwrap: '#efeae0', stubble: true, cheek: 0.12, build: 1.02, shoe: '#5a4a38' },
    anims: ['idle', 'walk', 'talk', 'sit', 'cower'] },
  courier_b: { base: 'villager_m', over: { coat: '#6a5240', pants: '#d6cdb6', vest: '#3a2f27', collar: '#3a2f27', daenim: '#3a2f27', sash: '#a8443c',
    hat: 'beonggeoji', hatColor: '#2b2622', back: null, patch: null, legwrap: '#efeae0', stubble: true, cheek: 0.14, build: 1.12, shoe: '#5a4a38' },
    anims: ['idle', 'walk', 'talk', 'sit', 'cower', 'tied'] },
  courier_c: { base: 'villager_m', over: { coat: '#9aa3a8', pants: '#ddd6c6', vest: null, collar: '#4b5358', daenim: '#4b5358', sash: '#a8443c', band: '#e7e0cf',
    back: null, patch: '#c9c4b8', legwrap: '#efeae0', stubble: false, cheek: 0.26, build: 0.9, height: 1.6, shoe: '#a88a55' },
    anims: ['idle', 'walk', 'talk', 'sit', 'cower'] },
  raider: { base: 'villager_m', over: { coat: '#5e5244', pants: '#6e6556', vest: '#8a7458', fur: true, collar: '#3a3029', daenim: '#3a3029', band: '#b39a5a',
    back: null, patch: '#4a4036', legwrap: '#bdb39c', stubble: true, cheek: 0.1, build: 1.16, shoe: '#4a3f33' }, hcl: 'club',
    anims: ['idle', 'walk', 'run', 'ready', 'swing', 'hit', 'fall', 'flee', 'tied'] },
  raider_b: { base: 'villager_m', over: { coat: '#4a4a46', pants: '#5c5a52', vest: '#2c2b28', collar: '#2c2b28', daenim: '#2c2b28', band: '#1f1d1b',
    back: null, patch: '#6a665c', legwrap: '#b9b09a', stubble: true, cheek: 0.12, build: 1.06, shoe: '#4a3f33' }, hcl: 'pole',
    anims: ['idle', 'walk', 'run', 'ready', 'thrust', 'hit', 'fall', 'flee'] },
};

// ---- 이겸 동작 ----
const SCRIBE_ANIMS = { write: { dur: 2.4, loop: true }, burn: { dur: 3.2, loop: true }, read: { dur: 3.0, loop: true } };
const SWAP = { arm1: 'arm2', arm2: 'arm1', arm1_l: 'arm2_l', arm2_l: 'arm1_l', leg1: 'leg2', leg2: 'leg1', leg1_l: 'leg2_l', leg2_l: 'leg1_l' };
const mirror = (P) => { const Q = {}; for (const n in P) { const p = P[n]; Q[SWAP[n] || n] = { r: -p.r, x: -p.x, y: p.y, sx: p.sx, sy: p.sy, a: p.a }; } return Q; };
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const smooth = (u) => u * u * (3 - 2 * u);
const { sin, PI } = Math;
const HIDE = { r: 0, x: 0, y: 0, sx: 1, sy: 1, a: 0 };

// 부위 하나에 변화량을 얹는다(없으면 새로)
function add(P, n, r = 0, x = 0, y = 0, sx = 1, sy = 1, a = 1) {
  const p = P[n] || (P[n] = { r: 0, x: 0, y: 0, sx: 1, sy: 1, a: 1 });
  p.r += r; p.x += x; p.y += y; p.sx *= sx; p.sy *= sy; p.a = a;
}
function setp(P, n, r = 0, x = 0, y = 0, sx = 1, sy = 1, a = 1) { P[n] = { r, x, y, sx, sy, a }; }

/** write: 앉아 무릎 위 종이에 붓으로 적는다(붓 끝이 짧게 오간다, 이따금 붓을 들어 생각) */
/** burn: 앉아 화로 쪽으로 종이 한 장을 내밀어 불에 넣는다 — 종이가 오그라들며 사라지고, 손을 거둬 다음 장을 집는다 */
/** read: 서서 종이를 가슴께로 들어 내려다본다(이따금 종이를 가까이) */
function scribePose(view, anim, t, at, rig, base) {
  const info = SCRIBE_ANIMS[anim];
  if (!info) return null;
  const k = rig.S.hip / 80;
  const side = view === 'side';
  const u = (t % info.dur) / info.dur;
  let P;
  const seat = (Q) => {   // 앉으면 두루마기 자락이 무릎 위로 덮인다(서 있을 때 길이 그대로면 땅 밑으로 늘어진다)
    if (side) setp(Q, 'skirt', 1.42, -2 * k, 0, 1.0, 0.72);
    else setp(Q, 'skirt', 0, 0, 0, 1.22, 0.26);
  };
  if (anim === 'read') {
    P = base(view === 'back' ? 'front' : view, 'idle', t, rig, at, {});
    const b = sin(u * PI * 2);
    if (side) {
      setp(P, 'arm2', 1.15 + 0.05 * b); setp(P, 'arm2_l', 1.35); setp(P, 'arm1', 0.95 + 0.04 * b); setp(P, 'arm1_l', 1.55);
      add(P, 'head', 0.26 + 0.03 * b); add(P, 'torso', -0.06);
    } else {
      setp(P, 'arm2', -0.55, 0, 0, 1, 0.9); setp(P, 'arm2_l', 1.95); setp(P, 'arm1', 0.55, 0, 0, 1, 0.9); setp(P, 'arm1_l', -1.95);
      add(P, 'head', 0.02 * b, 0, 3 * k);
    }
    setp(P, 'paper', 0.04 * b, 0, -26 * k);
  } else {
    P = base(view === 'back' ? 'front' : view, 'sit', t, rig, at, {});
    seat(P);
    if (anim === 'write') {
      const stroke = sin(t * 9.0) * (u < 0.7 ? 1 : 0.15), lift = u >= 0.7 ? smooth(clamp((u - 0.7) / 0.1, 0, 1)) * (1 - smooth(clamp((u - 0.9) / 0.1, 0, 1))) : 0;
      if (side) {
        add(P, 'torso', -0.2); add(P, 'head', 0.3 - 0.12 * lift);
        setp(P, 'arm2', 0.85 + 0.05 * stroke + 0.35 * lift); setp(P, 'arm2_l', 0.85 - 0.2 * lift); setp(P, 'arm1', 0.65); setp(P, 'arm1_l', 0.95);
      } else {
        add(P, 'head', 0, 0, (4 - 2 * lift) * k);
        setp(P, 'arm2', -0.25 + 0.05 * stroke - 0.25 * lift); setp(P, 'arm2_l', 1.05 + 0.3 * lift); setp(P, 'arm1', 0.3); setp(P, 'arm1_l', -1.0);
      }
      setp(P, 'brush', 0.15 * stroke);
      setp(P, 'lap_paper');
    } else {
      // burn: 0~0.3 내밂, 0.3~0.72 쥔 채 불붙음(종이 오그라듦), 0.72~0.9 거둠, 0.9~1 다음 장
      const reach = smooth(clamp(u / 0.3, 0, 1)) * (1 - smooth(clamp((u - 0.72) / 0.18, 0, 1)));
      const burn = clamp((u - 0.32) / 0.4, 0, 1);
      const next = smooth(clamp((u - 0.9) / 0.1, 0, 1));
      if (side) {
        add(P, 'torso', -0.08 - 0.14 * reach); add(P, 'head', 0.16 + 0.08 * reach);
        setp(P, 'arm2', 0.55 + 0.7 * reach); setp(P, 'arm2_l', 0.6 - 0.45 * reach); setp(P, 'arm1', 0.45 + 0.25 * next); setp(P, 'arm1_l', 0.75);
      } else {
        add(P, 'head', 0, 0, (2 + 2 * reach) * k);
        setp(P, 'arm2', -0.2 - 0.25 * reach, 0, 0, 1, 1 - 0.25 * reach); setp(P, 'arm2_l', 0.7 - 0.4 * reach); setp(P, 'arm1', 0.2 + 0.2 * next); setp(P, 'arm1_l', -0.7);
      }
      const shown = u < 0.72 ? 1 - burn : next;
      setp(P, 'paper', 0.1 * burn, 0, 0, 1 - 0.35 * burn, 1 - 0.7 * burn, shown > 0.02 ? clamp(shown * 1.4, 0, 1) : 0);
      setp(P, 'ember', 0, 0, 0, 1, 1, burn > 0.05 && burn < 0.98 ? 1 : 0);
      setp(P, 'lap_paper');
    }
  }
  P.staff = { ...HIDE };
  return view === 'back' ? mirror(P) : P;
}

/** 이겸 동작 그림 수: 태우기 한 주기 12장(종이가 오그라드는 것이 보이게), 적기 6장, 읽기 4장 */
function scribeSpec(anim) {
  const info = SCRIBE_ANIMS[anim], n = { burn: 12, write: 6, read: 4 }[anim], step = info.dur / n;
  return { kind: 'loop', times: [...Array(n).keys()].map((k) => k * step), loopStart: 0, intro: 0, step, n, dur: info.dur, tBased: false };
}

/** 손에 든 종이 한 장(먹 글씨 줄) */
function paperPart(S) {
  const P = new Painter(256);
  P.begin(21);
  const ws = S.ws;
  P.poly([[-9 * ws, 6 * ws], [9 * ws, 4 * ws], [10 * ws, 30 * ws], [-8 * ws, 32 * ws]], '#efe8d6', { w: 1.2, smooth: false, rough: 0.6 });
  for (let i = 0; i < 4; i++) P.stroke([[(-5 + i * 3.2) * ws, 9 * ws], [(-5.4 + i * 3.2) * ws, 27 * ws]], { w: 0.8, color: '#3a332d', taper: false });
  return P.end();
}
/** 타는 종이 끝의 불씨(종이가 화로에 닿을 때만) */
function emberPart(S) {
  const P = new Painter(256);
  P.begin(22);
  const ws = S.ws;
  P.ellipse(0, 30 * ws, 7 * ws, 6 * ws, '#e8873a', { w: 0.6 });
  P.ellipse(0, 28 * ws, 4 * ws, 4 * ws, '#ffd27a', { w: 0.3 });
  return P.end();
}
/** 붓(손을 따라 돈다) */
function brushPart(S) {
  const P = new Painter(256);
  P.begin(23);
  const ws = S.ws;
  P.poly([[-1.6, -14 * ws], [1.6, -14 * ws], [1.4, 16 * ws], [-1.4, 16 * ws]], '#6b4a2e', { w: 1.0, smooth: false });
  P.poly([[-2.2, 16 * ws], [2.2, 16 * ws], [0, 26 * ws, 'c']], '#1f1a17', { w: 0.8 });
  return P.end();
}
/** 무릎 위 종이(적는 동안·태우는 동안 — 몸 앞, 손과 따로) */
function lapPaperPart(S) {
  const P = new Painter(256);
  P.begin(24);
  const ws = S.ws;
  P.poly([[-14 * ws, -3 * ws], [14 * ws, -4 * ws], [15 * ws, 4 * ws], [-13 * ws, 5 * ws]], '#ebe3cf', { w: 1.1, smooth: false, rough: 0.5 });
  for (let i = 0; i < 5; i++) P.stroke([[(-10 + i * 5) * ws, -2 * ws], [(-10.5 + i * 5) * ws, 3 * ws]], { w: 0.7, color: '#4a423a', taper: false });
  return P.end();
}

/** 이겸: 종이·붓·불씨를 손에, 무릎 종이를 몸 앞에 붙이고 동작을 감싼다(앉기·서기 기본 동작에서는 숨김) */
function installScribe(kind) {
  const rig = getRig(kind);
  rig.anims = { ...rig.anims, ...SCRIBE_ANIMS };
  const base = rig.pose;
  rig.pose = (view, anim, t, rg, at, st) => {
    const P = scribePose(view, anim, t, at, rg, base);
    if (P) return P;
    const Q = base(view, anim, t, rg, at, st);
    if (anim === 'sit') {
      Q.staff = { ...HIDE };
      if (view === 'side') setp(Q, 'skirt', 1.42, -2 * rg.S.hip / 80, 0, 1.0, 0.72);
      else setp(Q, 'skirt', 0, 0, 0, 1.22, 0.26);
    }
    return Q;
  };
  // 태그 'alt': 굽기 엔진이 그 프레임 자세에서 a > 0.5일 때만 그린다(손에 든 것은 그 동작에서만)
  attachHand(rig, 'paper', paperPart(rig.S), 'alt', true);
  attachHand(rig, 'ember', emberPart(rig.S), 'alt', true);
  attachHand(rig, 'brush', brushPart(rig.S), 'alt', false);
  // 무릎 종이: 몸통(root)에 붙여 무릎 높이에 — 앉은 자세에서 앞(옆모습은 앞쪽으로)
  const img = lapPaperPart(rig.S);
  for (const v of ['front', 'side', 'back']) {
    const parts = rig.views[v];
    if (v === 'back') continue;
    parts.push({ name: 'lap_paper', parent: 'root', at: v === 'side' ? [-20 * rig.S.ws, -4] : [0, -2], r0: 0, z: v === 'side' ? 10.9 : 6.1, img: img.img, ox: img.ox, oy: img.oy, abs: true, tag: 'alt' });
    parts.draw = parts.filter((p) => p.img).map((p, i) => ({ p, i })).sort((a, b) => a.p.z - b.p.z || a.i - b.i).map((e) => e.p);
  }
  return rig;
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
    if (P.hcl) installHCL(kind, { weapon: P.hcl });
    else if (P.scribe) installScribe(kind);
    else getRig(kind);
    const b = new fc.BakeBank(kind, 'high');
    const clips = {};
    for (const vw of ['front', 'side', 'back']) for (const a of P.anims) {
      const key = fc.clipKey(fc.resolveView(kind, vw, a), a, false, false);
      if (clips[key]) continue;
      const c = b.clip(key); if (!c) continue;
      c.spec = SCRIBE_ANIMS[a] && P.scribe ? scribeSpec(a) : hclSpec(a, c.spec);
      let g = 0; while (!b.step(c) && g++ < 600);
      clips[key] = { spec: c.spec, frames: c.frames.map(meta) };
    }
    const pages = [];
    for (let i = 0; i < b.pages.length; i++) { const name = `frames_story_hamhung_${kind}_${i}.png`; await put(name, await toPng(b.pages[i].cv)); pages.push(name); }
    out[kind] = { pages, clips };
    log('baked ' + kind + ' pages=' + pages.length + ' clips=' + Object.keys(clips).length);
  }
  await put(only ? `frames_story_hamhung_${only.replace(/,/g, '_')}.json` : 'frames_story_hamhung.json', JSON.stringify(out));
  log('done: ' + Object.keys(out).join(', '));
  console.log('[hamhung bake] done', Object.keys(out));
}
