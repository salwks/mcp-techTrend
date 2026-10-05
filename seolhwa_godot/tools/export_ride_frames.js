// 자동 기승 프레임 굽기(scripts/region/horse_ride.gd, CHARACTER master CHR_ANI_002 말) — 웹 코드(seolhwa/src)는 고치지 않는다.
//  - ride_horse: 탈 말(안장·언치·굴레·고삐). 앞·옆·뒤 세 시점 × idle(4)·walk(8, 네 박 걸음)·run(6, 속보 — 대각 두 박).
//      말 그림은 tools/horse_art.js(장마다 한 윤곽으로 그린 말 — 조각을 돌리는 꼭두각시가 아님). 옆은 왼쪽을 본다(오른쪽은 엔진이 뒤집는다).
//      주변 말(frames_amb horse, 옆모습만)보다 1.3배 크다(사람 2.06m에 맞춘 탈 말 — 등 높이 약 1.75m).
//  - player: ride(말 위 — 무릎 굽혀 걸터앉아 두 손으로 고삐, 걸음 따라 들썩임: 앞·옆·뒤) · mount · dismount(옆, 오르기·내리기).
//      웹 굽기 엔진(frameCore.BakeBank, high)에 동작만 더한다. 엉덩이(안장 닿는 곳)가 발밑 원점 — 엔진이 안장 높이로 올린다.
// 결과: data/frames_ride.json + frames_ride_<kind>_<n>.png (data/는 git 제외 — 다른 맥에서는 다시 굽는다. 없으면 엔진은 주변 말 옆모습·앉기로 대신)
// 실행: python3 tools/web_export_server.py 8770 → http://localhost:8770/__tools/ride_bake.html
//   (헤드리스: "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" --headless=new --virtual-time-budget=120000 --dump-dom 그 주소 — 끝나면 <p id=st>done…)
import { SPECS, getRig } from '/src/chars/rigs.js';
import * as fc from '/src/chars/frameCore.js';
import * as HA from '/__tools/horse_art.js';

const { sin, cos, PI, max, min, abs } = Math;
const SWAP = { arm1: 'arm2', arm2: 'arm1', arm1_l: 'arm2_l', arm2_l: 'arm1_l', leg1: 'leg2', leg2: 'leg1', leg1_l: 'leg2_l', leg2_l: 'leg1_l' };
const toP = (F) => { const P = {}; for (const n in F) { const a = F[n]; P[n] = { r: a[0] || 0, x: a[1] || 0, y: a[2] || 0, sx: a[3] ?? 1, sy: a[4] ?? 1, a: a[5] ?? 1 }; } return P; };
const mirror = (P) => { const Q = {}; for (const n in P) { const p = P[n]; Q[SWAP[n] || n] = { r: -p.r, x: -p.x, y: p.y, sx: p.sx, sy: p.sy, a: p.a }; } return Q; };
const lerpF = (A, B, k) => { const O = {}; for (const n of new Set([...Object.keys(A), ...Object.keys(B)])) { const a = A[n] || [], b = B[n] || []; const L = Math.max(a.length, b.length, 1); O[n] = []; for (let j = 0; j < L; j++) { const d = j < 3 ? 0 : 1; const x = a[j] ?? d, y = b[j] ?? d; O[n].push(x + (y - x) * k); } } return O; };
const sm = (k) => k * k * (3 - 2 * k);

// ---------------------------------------------------------------------------
// 탄 사람(player) 자세
// ---------------------------------------------------------------------------
const RIDE_ANIMS = { ride: { dur: 0.56, loop: true }, mount: { dur: 0.75 }, dismount: { dur: 0.7 } };
function rideBase(side, S, bob, sway) {
  const k = S.hip / 80;
  if (side) return { root: [0.0, 0, S.hip - 4 * k - bob * k], torso: [-0.1 + sway * 0.05], head: [0.08 - sway * 0.04],
    leg2: [0.85], leg2_l: [-1.05], leg1: [0.78], leg1_l: [-1.0],
    arm2: [0.62], arm2_l: [0.95], arm1: [0.55], arm1_l: [1.0] };
  return { root: [0, 0, S.hip - 4 * k - bob * k], torso: [sway * 0.03], head: [-sway * 0.02],
    leg1: [0.55, 0, 0, 1, 0.95], leg1_l: [-0.5, 0, 0, 1, 0.9], leg2: [-0.55, 0, 0, 1, 0.95], leg2_l: [0.5, 0, 0, 1, 0.9],
    arm1: [0.14], arm1_l: [-0.85, 0, 0, 1, 0.8], arm2: [-0.14], arm2_l: [0.85, 0, 0, 1, 0.8] };
}
function ridePose(view, anim, t, at, rig) {
  if (!RIDE_ANIMS[anim]) return null;
  const S = rig.S, side = view === 'side', k = S.hip / 80;
  let F;
  if (anim === 'ride') {
    const u = ((t / RIDE_ANIMS.ride.dur) % 1 + 1) % 1;
    F = rideBase(side, S, 3.0 * abs(sin(u * PI * 2)), sin(u * PI * 2));
  } else {
    let u = Math.min(1, Math.max(0, at / RIDE_ANIMS[anim].dur));
    if (anim === 'dismount') u = 1 - u;
    const stand = side ? { arm2: [0.2], arm1: [0.15], leg2: [0.05], leg1: [-0.05] } : {};
    const reach = side
      ? { root: [0, 0, -4 * k], torso: [-0.25], head: [0.1], leg2: [-0.05], leg1: [1.6], leg1_l: [-1.6], arm2: [2.4], arm2_l: [0.3], arm1: [2.2], arm1_l: [0.2] }
      : { root: [0, 0, -4 * k], arm1: [2.6], arm2: [-2.6], leg1: [0.9], leg1_l: [-1.2] };
    const swing = side
      ? { root: [0, 0, S.hip * 0.55], torso: [-0.35], head: [0.15], leg2: [1.2], leg2_l: [-0.9], leg1: [0.6], leg1_l: [-1.0], arm2: [1.4], arm2_l: [0.6], arm1: [1.2], arm1_l: [0.6] }
      : { root: [0, 0, S.hip * 0.55], leg1: [0.6], leg1_l: [-0.5], leg2: [-0.9], leg2_l: [0.6], arm1: [0.5], arm2: [-0.5] };
    const end = rideBase(side, S, 0, 0);
    if (u < 0.4) F = lerpF(stand, reach, sm(u / 0.4));
    else if (u < 0.75) F = lerpF(reach, swing, sm((u - 0.4) / 0.35));
    else F = lerpF(swing, end, sm((u - 0.75) / 0.25));
  }
  F.staff = [0, 0, 0, 1, 1, 0];   // 지팡이는 안장에 꽂아 둔다(말 위에서는 안 보임)
  const P = toP(F);
  return view === 'back' ? mirror(P) : P;
}

// ---------------------------------------------------------------------------
// 말 그리기 — 길이 단위 m(1.3배 그린다), 발 중심 원점, 위가 +y, 옆모습 머리는 왼쪽(−x)
// ---------------------------------------------------------------------------
const PPM = 100, PAGE = 1024, MARGIN = 5, TW = 560, TH = 400, TOX = 280, TOY = 380, SC = 1.3;
const INKC = '#1f1a17';
const COAT = '#7a5236', DARK = '#2a221c', SADDLE = '#4a2e1e', CLOTH = '#8e3a2c', CLOTH2 = '#2f4a6a', METAL = '#b8a46a';

// 한 장 그릴 캔버스 — 발 중심 원점(TOX, TOY), 위 +y
class Pen {
  constructor() { this.cv = document.createElement('canvas'); this.cv.width = TW; this.cv.height = TH; this.g = this.cv.getContext('2d', { willReadFrequently: true }); }
  clear() { this.g.setTransform(1, 0, 0, 1, 0, 0); this.g.clearRect(0, 0, TW, TH); }
  X(x) { return TOX + x * PPM * SC; }
  Y(y) { return TOY - y * PPM * SC; }
}

// 말은 tools/horse_art.js(한 윤곽으로 그리는 말 — 예전 막대 다리·조각 몸통 꼭두각시를 걷어냄). 여기서는 안장·언치·등자·고삐만 덧그린다.
const RCOAT = { coat: COAT, mane: DARK, blaze: true };
const quad = (pen, pts, col, w, dark = 0.2) => { HA.wash(pen, pts, col, dark, 0.1); HA.ink(pen, pts, w); };
const TACK = {
  side: { halterCol: '#5a3020', reins: [[-0.62, 1.66], [-0.34, 1.62]], rideHead: true,
    saddle: (pen, B, w) => {
      quad(pen, [B([-0.34, 1.43]), B([0.3, 1.42]), B([0.33, 1.08]), B([-0.36, 1.1])], CLOTH, w);                       // 언치
      HA.stroke(pen, [B([-0.32, 1.14]), B([0.3, 1.12])], w * 1.4, METAL);
      quad(pen, [B([-0.3, 1.52]), B([-0.18, 1.47]), B([0.16, 1.47]), B([0.28, 1.54]), B([0.24, 1.41]), B([-0.26, 1.41])], SADDLE, w, 0.3);   // 안장(앞뒤 가리)
      HA.stroke(pen, [B([-0.02, 1.42]), B([-0.02, 0.97])], w * 0.9, DARK);                                                     // 등자 끈
      quad(pen, [B([-0.07, 0.98]), B([0.03, 0.98]), B([0.03, 0.93]), B([-0.07, 0.93])], METAL, w * 0.8, 0);
      HA.stroke(pen, [B([-0.3, 1.0]), B([0.1, 0.98])], w * 1.1, '#5a3020');                                                     // 뱃대끈
    } },
  front: { halterCol: '#5a3020', reinsFront: true,
    saddleFront: (pen, X, Y, w, bw) => {
      quad(pen, [[X(-bw - 0.06, 0.4), Y(1.42)], [X(bw + 0.06, 0.4), Y(1.42)], [X(bw + 0.04, 0.4), Y(1.08)], [X(-bw - 0.04, 0.4), Y(1.08)]], CLOTH, w);
      quad(pen, [[X(-0.28, 0.5), Y(1.55)], [X(0.28, 0.5), Y(1.55)], [X(0.25, 0.5), Y(1.42)], [X(-0.25, 0.5), Y(1.42)]], SADDLE, w, 0.3);
      for (const sg of [-1, 1]) { HA.stroke(pen, [[X(sg * (bw + 0.04), 0.4), Y(1.36)], [X(sg * (bw + 0.05), 0.4), Y(0.95)]], w * 0.9, DARK);
        quad(pen, [[X(sg * (bw + 0.05), 0.4) - 0.04, Y(0.97)], [X(sg * (bw + 0.05), 0.4) + 0.04, Y(0.97)], [X(sg * (bw + 0.05), 0.4) + 0.04, Y(0.92)], [X(sg * (bw + 0.05), 0.4) - 0.04, Y(0.92)]], METAL, w * 0.8, 0); }
    } },
  back: { halterCol: '#5a3020',
    saddleBack: (pen, X, Y, w, bw) => {
      quad(pen, [[X(-bw - 0.06, 0.6), Y(1.44)], [X(bw + 0.06, 0.6), Y(1.44)], [X(bw + 0.04, 0.6), Y(1.1)], [X(-bw - 0.04, 0.6), Y(1.1)]], CLOTH, w);
      quad(pen, [[X(-0.28, 0.6), Y(1.57)], [X(0.28, 0.6), Y(1.57)], [X(0.25, 0.6), Y(1.44)], [X(-0.25, 0.6), Y(1.44)]], SADDLE, w, 0.3);
      for (const sg of [-1, 1]) HA.stroke(pen, [[X(sg * (bw + 0.04), 0.6), Y(1.38)], [X(sg * (bw + 0.05), 0.6), Y(0.96)]], w * 0.9, DARK);
    } },
};
// 탈 말 동작: idle(4 — 꼬리·귀·머리 들기·발 쉬기) · walk(8, 네 박 걸음) · run(6, 속보 — 대각 두 박, 뜸)
const HORSE_ANIMS = { idle: 4, walk: 8, run: 6 };
const VIEWS = ['side', 'front', 'back'];

function bakeHorse() {
  const pen = new Pen();
  const pages = [];
  let page = null, sx = 0, sy = 0, rowH = 0;
  const newPage = () => { page = document.createElement('canvas'); page.width = PAGE; page.height = PAGE; pages.push(page); sx = 0; sy = 0; rowH = 0; };
  newPage();
  const clips = {};
  for (const view of VIEWS) {
    for (const anim in HORSE_ANIMS) {
      const n = HORSE_ANIMS[anim], frames = [];
      for (let f = 0; f < n; f++) {
        pen.clear();
        HA.drawHorse(pen, view, RCOAT, HA.horsePose(anim === 'run' ? 'trot' : anim, f, n), TACK[view]);
        const d = pen.g.getImageData(0, 0, TW, TH).data;
        let x0 = TW, y0 = TH, x1 = 0, y1 = 0;
        for (let y = 0; y < TH; y++) for (let x = 0; x < TW; x++) if (d[(y * TW + x) * 4 + 3] > 8) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
        x1 += 1; y1 += 1;
        const w = x1 - x0 + MARGIN * 2, h = y1 - y0 + MARGIN * 2;
        if (sx + w > PAGE) { sx = 0; sy += rowH; rowH = 0; }
        if (sy + h > PAGE) newPage();
        page.getContext('2d').drawImage(pen.cv, x0, y0, x1 - x0, y1 - y0, sx + MARGIN, sy + MARGIN, x1 - x0, y1 - y0);
        frames.push({ page: pages.length - 1, u0: sx / PAGE, v0: sy / PAGE, u1: (sx + w) / PAGE, v1: (sy + h) / PAGE,
          x0: (x0 - MARGIN - TOX) / PPM, x1: (x1 + MARGIN - TOX) / PPM, y0: -(y1 + MARGIN - TOY) / PPM, y1: -(y0 - MARGIN - TOY) / PPM, lift: 0 });
        sx += w; rowH = Math.max(rowH, h);
      }
      const spec = anim === 'idle'
        ? { kind: 'loop', times: [...Array(n).keys()].map((k) => k * 0.8), loopStart: 0, intro: 0, step: 0.8, n, dur: n * 0.8, tBased: true }
        : { kind: 'phase', n, times: [...Array(n).keys()].map((k) => k / n) };
      clips[view + '|' + anim] = { spec, frames };
    }
  }
  return { pages, clips };
}

// ---------------------------------------------------------------------------
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
  // ---- 말 ----
  const hb = bakeHorse();
  const hp = [];
  for (let i = 0; i < hb.pages.length; i++) { const name = `frames_ride_horse_${i}.png`; await put(name, await toPng(hb.pages[i])); hp.push(name); }
  out.ride_horse = { pages: hp, clips: hb.clips };
  log('baked ride_horse pages=' + hp.length);
  // ---- 탄 사람 ----
  const rig = getRig('player');
  rig.anims = { ...rig.anims, ...RIDE_ANIMS };
  const base = rig.pose;
  rig.pose = (view, anim, t, rg, at, st) => ridePose(view, anim, t, at, rig) || base(view, anim, t, rg, at, st);
  const b = new fc.BakeBank('player', 'high');
  const clips = {};
  for (const vw of ['front', 'side', 'back']) for (const a of ['ride', 'mount', 'dismount']) {
    if (a !== 'ride' && vw !== 'side') continue;   // 오르기·내리기는 옆모습(앞·뒤는 엔진이 옆으로 대신)
    const key = fc.clipKey(vw, a, false, false);
    if (clips[key]) continue;
    const c = b.clip(key); if (!c) continue;
    if (a === 'ride') { const n = 6, step = RIDE_ANIMS.ride.dur / n; c.spec = { kind: 'loop', times: [...Array(n).keys()].map((k) => k * step), loopStart: 0, intro: 0, step, n, dur: RIDE_ANIMS.ride.dur, tBased: false }; }
    let g = 0; while (!b.step(c) && g++ < 600);
    clips[key] = { spec: c.spec, frames: c.frames.map(meta) };
  }
  const pp = [];
  for (let i = 0; i < b.pages.length; i++) { const name = `frames_ride_player_${i}.png`; await put(name, await toPng(b.pages[i].cv)); pp.push(name); }
  out.player = { pages: pp, clips };
  log('baked player ride pages=' + pp.length + ' clips=' + Object.keys(clips).join(','));
  await put('frames_ride.json', JSON.stringify(out));
  log('done: ' + Object.keys(out).join(', '));
  console.log('[ride bake] done', Object.keys(out));
}
