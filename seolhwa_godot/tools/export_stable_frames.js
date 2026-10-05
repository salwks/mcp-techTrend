// 역참·마방(scripts/region/station_life.gd) 프레임 굽기 — 웹 코드(seolhwa/src)는 고치지 않는다.
//  - stable_bay · stable_chestnut · stable_grey · stable_pony: 마방에 매인 말(안장 없음, 굴레만). 그림은 tools/horse_art.js —
//      장마다 말 한 마리를 한 윤곽으로 그린다(조각을 돌리는 꼭두각시가 아님). 옆은 왼쪽을 본다(오른쪽은 엔진이 뒤집는다). 탈 말과 같은 1.3배.
//      동작: side idle(꼬리 휘두름·귀 돌림·머리 들어 둘러봄·뒷발 쉬기) · eat(구유에 머리) · graze(땅 풀) · walk(네 박 8장)
//            front idle·eat / idleR·eatR(몸이 조금 돌아 머리가 좌·우 — 칸마다 번갈아) / back idle·eat(머리는 몸 뒤로 숨음).
//      제주 조랑말(stable_pony, 과하마): 짧고 굵은 다리, 큰 머리, 덥수룩한 갈기·앞머리, 누런 밤빛.
//  - mabu: 마부(역졸 차림 — 무명 저고리·잠방이·머리띠·행전). idle · walk(앞·옆·뒤) + brush(옆 — 솔질), feed(옆 — 건초를 구유에 붓기).
//      웹 굽기 엔진(frameCore.BakeBank, high)에 종류·동작만 더한다. 건초 짐은 엔진이 3D 짚단으로 안긴다.
// 결과: data/frames_stable.json + frames_stable_<kind>_<n>.png (data/는 git 제외 — 다른 맥에서는 다시 굽는다. 없으면 엔진은 탈 말·주변 말로 대신)
// 실행: python3 tools/web_export_server.py 8770 → http://localhost:8770/__tools/stable_bake.html
//   (헤드리스: "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" --headless=new --virtual-time-budget=120000 --dump-dom 그 주소 — 끝나면 <p id=st>done…)
import { SPECS, getRig } from '/src/chars/rigs.js';
import * as fc from '/src/chars/frameCore.js';
import * as HA from '/__tools/horse_art.js';

const { sin, cos, PI } = Math;

// ---------------------------------------------------------------------------
// 말 그리기 — 길이 단위: 그림 m(세상 크기 = × SC), 발 중심 원점, 위가 +y, 옆모습 머리는 왼쪽(−x)
// ---------------------------------------------------------------------------
const RES = 90, PAGE = 1024, MARGIN = 4;     // RES: 세상 1m당 픽셀(탈 말 100보다 조금 낮게 — 말이 여러 마리라 페이지를 아낀다)
const COATS = {
  stable_bay: { coat: '#7a5236', mane: '#2a221c', sc: 1.3 },
  stable_chestnut: { coat: '#9a5b2e', mane: '#5e321a', sc: 1.3, blaze: true },
  stable_grey: { coat: '#b0aaa0', mane: '#55514b', sc: 1.3, dapple: true },
  stable_pony: { coat: '#8c6a44', mane: '#2e241c', sc: 1.3 * 0.94, pony: true },   // 다리·몸 줄임은 horse_art가 pony로 한다
};
const HALTER = '#5a3020';

// 한 장 그릴 캔버스 — 발 중심 원점(TOX, TOY), 위 +y
class Pen {
  constructor(sc) {
    this.sc = sc;
    this.TW = Math.ceil(4.4 * sc * RES); this.TH = Math.ceil(3.4 * sc * RES);
    this.TOX = this.TW / 2; this.TOY = this.TH - 8 - Math.ceil(0.1 * sc * RES);
    this.cv = document.createElement('canvas'); this.cv.width = this.TW; this.cv.height = this.TH;
    this.g = this.cv.getContext('2d', { willReadFrequently: true });
  }
  clear() { this.g.setTransform(1, 0, 0, 1, 0, 0); this.g.clearRect(0, 0, this.TW, this.TH); }
  X(x) { return this.TOX + x * RES * this.sc; }
  Y(y) { return this.TOY - y * RES * this.sc; }
}

// 말 그림은 tools/horse_art.js(한 윤곽으로 그리는 말 — 꼭두각시 조각 그림을 걷어냄). 여기서는 털빛·굴레·동작 묶음만 정한다.
// front: 칸 말(구유를 보고 먹음) — 몸이 조금 돈 앞모습: idle·eat는 머리가 화면 왼쪽(turn −0.45), idleR·eatR는 오른쪽(+0.45).
//   엔진 station_life가 칸마다 번갈아 고른다. 앞·뒤 walk는 엔진이 옆으로 대신한다.
const HORSE_CLIPS = { side: { idle: 4, eat: 4, graze: 4, walk: 8 }, front: { idle: 4, eat: 4, idleR: 4, eatR: 4 }, back: { idle: 4, eat: 4 } };
const IDLE_STEP = { idle: 0.85, eat: 0.42, graze: 0.5, idleR: 0.85, eatR: 0.42 };

function bakeHorse(C) {
  const pen = new Pen(C.sc);
  const pages = [];
  let page = null, sx = 0, sy = 0, rowH = 0;
  const newPage = () => { page = document.createElement('canvas'); page.width = PAGE; page.height = PAGE; pages.push(page); sx = 0; sy = 0; rowH = 0; };
  newPage();
  const clips = {};
  for (const view in HORSE_CLIPS) {
    for (const anim in HORSE_CLIPS[view]) {
      const n = HORSE_CLIPS[view][anim], frames = [];
      for (let f = 0; f < n; f++) {
        pen.clear();
        const a = anim.replace(/R$/, ''), turn = view === 'front' ? (anim.endsWith('R') ? 0.45 : -0.45) : 0;
        HA.drawHorse(pen, view, C, HA.horsePose(a, f, n, { turn, stall: view === 'front' }), { halterCol: HALTER });
        const d = pen.g.getImageData(0, 0, pen.TW, pen.TH).data;
        let x0 = pen.TW, y0 = pen.TH, x1 = 0, y1 = 0;
        for (let y = 0; y < pen.TH; y++) for (let x = 0; x < pen.TW; x++) if (d[(y * pen.TW + x) * 4 + 3] > 8) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
        x1 += 1; y1 += 1;
        const w = x1 - x0 + MARGIN * 2, h = y1 - y0 + MARGIN * 2;
        if (sx + w > PAGE) { sx = 0; sy += rowH; rowH = 0; }
        if (sy + h > PAGE) newPage();
        page.getContext('2d').drawImage(pen.cv, x0, y0, x1 - x0, y1 - y0, sx + MARGIN, sy + MARGIN, x1 - x0, y1 - y0);
        frames.push({ page: pages.length - 1, u0: sx / PAGE, v0: sy / PAGE, u1: (sx + w) / PAGE, v1: (sy + h) / PAGE,
          x0: (x0 - MARGIN - pen.TOX) / RES, x1: (x1 + MARGIN - pen.TOX) / RES, y0: -(y1 + MARGIN - pen.TOY) / RES, y1: -(y0 - MARGIN - pen.TOY) / RES, lift: 0 });
        sx += w; rowH = Math.max(rowH, h);
      }
      const step = IDLE_STEP[anim];
      const spec = anim === 'walk'
        ? { kind: 'phase', n, times: [...Array(n).keys()].map((k) => k / n) }
        : { kind: 'loop', times: [...Array(n).keys()].map((k) => k * step), loopStart: 0, intro: 0, step, n, dur: n * step, tBased: true };
      clips[view + '|' + anim] = { spec, frames };
    }
  }
  return { pages, clips };
}

// ---------------------------------------------------------------------------
// 마부 — 웹 rigs의 villager_m 차림을 바꾸고 동작 둘(brush·feed)을 더한다
// ---------------------------------------------------------------------------
const MABU = { base: 'villager_m', coat: '#cdbb94', pants: '#d6c9a8', vest: '#6a5038', collar: '#8a7148', daenim: '#6a5038', back: null, band: '#efe9da',
  legwrap: '#ebe4d1', hat: null, build: 1.1, stubble: true };
const MABU_ANIMS = { brush: { dur: 1.2, loop: true }, feed: { dur: 1.6, loop: true } };
const toP = (F) => { const P = {}; for (const n in F) { const a = F[n]; P[n] = { r: a[0] || 0, x: a[1] || 0, y: a[2] || 0, sx: a[3] ?? 1, sy: a[4] ?? 1, a: a[5] ?? 1 }; } return P; };
function mabuPose(view, anim, t, rig) {
  if (!MABU_ANIMS[anim] || view !== 'side') return null;
  const S = rig.S, k = S.hip / 80;
  const u = ((t / MABU_ANIMS[anim].dur) % 1 + 1) % 1, ph = u * 2 * PI;
  if (anim === 'brush') {
    // 말 옆구리를 솔로 쓸어내림: 앞팔을 어깨 높이로 뻗어 위→아래로, 몸이 따라 살짝 기욺
    const s = sin(ph);
    return toP({ root: [0, 0, -1.5 * k], torso: [-0.12 - 0.05 * s], head: [0.05],
      arm2: [1.35 + 0.35 * s], arm2_l: [0.35 - 0.15 * s], arm1: [0.7 + 0.2 * s], arm1_l: [0.9],
      leg2: [0.16], leg2_l: [-0.12], leg1: [-0.18], leg1_l: [-0.05] });
  }
  // feed: 두 팔에 안은 건초를 구유 쪽으로 내밀었다 거둠
  const s = 0.5 - 0.5 * cos(ph);
  return toP({ root: [0, 0, -3 * k * s], torso: [-0.1 - 0.35 * s], head: [0.05 + 0.15 * s],
    arm2: [0.9 + 0.5 * s], arm2_l: [1.1 - 0.5 * s], arm1: [0.8 + 0.45 * s], arm1_l: [1.1 - 0.45 * s],
    leg2: [0.12], leg2_l: [-0.1], leg1: [-0.14], leg1_l: [-0.05] });
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
  for (const kind in COATS) {
    const hb = bakeHorse(COATS[kind]);
    const names = [];
    for (let i = 0; i < hb.pages.length; i++) { const name = `frames_stable_${kind}_${i}.png`; await put(name, await toPng(hb.pages[i])); names.push(name); }
    out[kind] = { pages: names, clips: hb.clips };
    log('baked ' + kind + ' pages=' + names.length);
  }
  // ---- 마부 ----
  const kind = 'mabu';
  const v = { ...MABU }; const base = SPECS[v.base]; delete v.base;
  const sp = { ...base };
  for (const k in v) { if (v[k] === null || v[k] === undefined) delete sp[k]; else sp[k] = v[k]; }
  SPECS[kind] = sp;
  fc.TIERS.high[kind] = fc.TIERS.high.player;
  const rig = getRig(kind);
  rig.anims = { ...rig.anims, ...MABU_ANIMS };
  const basePose = rig.pose;
  rig.pose = (view, anim, t, rg, at, st) => mabuPose(view, anim, t, rig) || basePose(view, anim, t, rg, at, st);
  const b = new fc.BakeBank(kind, 'high');
  const clips = {};
  for (const vw of ['front', 'side', 'back']) for (const a of ['idle', 'walk', 'brush', 'feed']) {
    if (MABU_ANIMS[a] && vw !== 'side') continue;
    const key = fc.clipKey(MABU_ANIMS[a] ? vw : fc.resolveView(kind, vw, a), a, false, false);
    if (clips[key]) continue;
    const c = b.clip(key); if (!c) continue;
    if (MABU_ANIMS[a]) { const n = 8, step = MABU_ANIMS[a].dur / n; c.spec = { kind: 'loop', times: [...Array(n).keys()].map((q) => q * step), loopStart: 0, intro: 0, step, n, dur: MABU_ANIMS[a].dur, tBased: false }; }
    let g = 0; while (!b.step(c) && g++ < 600);
    clips[key] = { spec: c.spec, frames: c.frames.map(meta) };
  }
  const pp = [];
  for (let i = 0; i < b.pages.length; i++) { const name = `frames_stable_mabu_${i}.png`; await put(name, await toPng(b.pages[i].cv)); pp.push(name); }
  out.mabu = { pages: pp, clips };
  log('baked mabu pages=' + pp.length + ' clips=' + Object.keys(clips).join(','));
  await put('frames_stable.json', JSON.stringify(out));
  log('done: ' + Object.keys(out).join(', '));
  console.log('[stable bake] done', Object.keys(out));
}
