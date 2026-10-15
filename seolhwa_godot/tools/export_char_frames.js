// 인물 빌더 굽기: 자료(spec) 묶음 → 공유 아틀라스(2048²)에 촘촘히 담은 묶음(set) 하나.
//   data/chars/<set>.json  { format:'chars-1', set, px, pages:['chars/<set>_0.png',…], chars:{ id:{ role, template, sex, age, name, spec, clips } } }
//   clips는 SpriteChar 프레임 꼴 그대로(page = 이 묶음의 pages 번호). Godot scripts/char_bank.gd가 id로 찾는다.
// 묶음:
//   ?set=presets        기존 인물을 옮긴 프리셋(주모·방자·포졸·마을 사내) — 모든 동작, 116px/m(예전 high와 같음)
//   ?set=amb_JL …       권역 고을 사람 무리(char_builder.poolSpecs) — idle(2장)·walk·talk·sit·bow·kneel(+짐 있으면 carry), 72px/m(1080p 화면 크기)
//   ?set=amb_all        여덟 권역 무리를 차례로
//   ?set=custom&specs=… (편집기 「프레임 굽기」) — 편집기가 bakeSet()을 바로 부른다
// 실행: python3 tools/web_export_server.py 8770 → 앱 브라우저 창으로 http://localhost:8770/__tools/chars_bake.html?set=amb_all
import * as fc from '/src/chars/frameCore.js';
import { ANIMS, PRESETS, registerSpec, poolSpecs, REGIONS } from '/__tools/char_builder.js';

const ATLAS = 2048, MARGIN = 2;
export const AMB_ANIMS = ['idle', 'walk', 'talk', 'sit', 'bow', 'kneel'];
const VIEWS = ['front', 'side', 'back'];

async function put(name, data) {
  const r = await fetch('/export/' + name, { method: 'PUT', body: data });
  if (!r.ok) throw new Error('PUT ' + name + ' ' + r.status);
}
const toPng = (cv) => (cv.convertToBlob ? cv.convertToBlob({ type: 'image/png' }) : new Promise((r) => cv.toBlob(r, 'image/png')));

/** 줄(shelf) 아틀라스 — 여러 인물의 그림을 같은 페이지에 */
class Atlas {
  constructor() { this.pages = []; this.used = 0; }
  alloc(w, h) {
    w += MARGIN * 2; h += MARGIN * 2;
    const tryPage = (p) => {
      let best = null;
      for (const row of p.rows) if (row.h >= h && row.x + w <= ATLAS && (!best || row.h < best.h)) best = row;
      if (best && best.h <= h * 1.3) return best;
      if (p.nextY + h <= ATLAS) { const row = { y: p.nextY, h, x: 0 }; p.rows.push(row); p.nextY += h; return row; }
      return best;
    };
    let p = null, row = null;
    for (const pg of this.pages) { row = tryPage(pg); if (row) { p = pg; break; } }
    if (!row) {
      const cv = document.createElement('canvas'); cv.width = cv.height = ATLAS;
      p = { cv, g: cv.getContext('2d'), rows: [], nextY: 0, index: this.pages.length };
      this.pages.push(p); row = tryPage(p);
    }
    const r = { page: p, x: row.x + MARGIN, y: row.y + MARGIN };
    row.x += w; this.used += w * h;
    return r;
  }
}

/** 인물 하나 굽고 아틀라스로 옮김 → clips(SpriteChar 꼴) */
function bakeChar(atlas, spec, anims, px, lean = false) {
  const id = registerSpec(spec);
  fc.TIERS.high[id] = px;
  const b = new fc.BakeBank(id, 'high');
  const moved = new Map();   // 원래 프레임 meta → 새 meta(같은 그림 재사용 유지)
  const clips = {};
  for (const a of anims) for (const v of VIEWS) {
    const key = fc.clipKey(v, a, false, false);
    const c = b.clip(key); if (!c) continue;
    if (lean && a === 'idle') {
      // 고을 사람: 대기 숨쉬기 2장(4장 대신 — 멀리서는 차이가 안 보이고 그림이 준다)
      const d = c.spec.dur;
      c.spec = { kind: 'loop', times: [0, d / 2], loopStart: 0, intro: 0, step: d / 2, n: 2, dur: d, tBased: true };
    }
    let g = 0; while (!b.step(c) && g++ < 600);
    clips[key] = { spec: c.spec, frames: c.frames.map((f) => {
      let m = moved.get(f);
      if (m) return m;
      const src = b.pages[typeof f.page === 'number' ? f.page : f.page.index].cv;
      // BakeBank 사각형(여백 포함, 1024 페이지)
      const sx = Math.round(f.u0 * 1024), sy = Math.round(f.v0 * 1024), sw = Math.round((f.u1 - f.u0) * 1024), sh = Math.round((f.v1 - f.v0) * 1024);
      const r = atlas.alloc(sw, sh);
      r.page.g.drawImage(src, sx, sy, sw, sh, r.x, r.y, sw, sh);
      m = { page: r.page.index, u0: r.x / ATLAS, v0: r.y / ATLAS, u1: (r.x + sw) / ATLAS, v1: (r.y + sh) / ATLAS, x0: f.x0, x1: f.x1, y0: f.y0, y1: f.y1, lift: f.lift };
      moved.set(f, m);
      return m;
    }) };
  }
  return { id, clips, frames: moved.size, ms: b.bakeMs };
}

const animsFor = (spec, base) => {
  const I = spec.items || {};
  const load = (I.handLoad && I.handLoad !== 'none') || (I.head && I.head !== 'none') || (I.back && I.back !== 'none');
  return load && !base.includes('carry') ? [...base, 'carry'] : base;
};
const strip = (s) => JSON.parse(JSON.stringify(s));

/** 자료 묶음 굽기 → data/chars/<set>.json + 페이지 */
export async function bakeSet(set, specs, { px = 72, anims = AMB_ANIMS, lean = false, log = () => {} } = {}) {
  const atlas = new Atlas();
  const chars = {};
  const t0 = performance.now();
  let nf = 0;
  for (const sp of specs) {
    const r = bakeChar(atlas, sp, animsFor(sp, anims), px, lean);
    nf += r.frames;
    chars[r.id] = { role: sp.role || sp.template, template: sp.template, sex: sp.body?.sex, age: sp.body?.age, name: sp.name || '', spec: strip(sp), clips: r.clips };
    log(`${set}: ${r.id} frames=${r.frames} pages=${atlas.pages.length}`);
    await new Promise((res) => { const ch = new MessageChannel(); ch.port1.onmessage = () => res(); ch.port2.postMessage(0); });   // 숨은 탭에서도 느려지지 않는 양보(setTimeout은 숨은 탭에서 1분에 한 번까지 늦춰진다)
  }
  const pages = [];
  for (const p of atlas.pages) { const name = `chars/${set}_${p.index}.png`; await put(name, await toPng(p.cv)); pages.push(name); }
  const out = { format: 'chars-1', set, px, pages, chars, stats: { chars: specs.length, frames: nf, pages: pages.length, fill: +(atlas.used / (pages.length * ATLAS * ATLAS)).toFixed(2), sec: Math.round((performance.now() - t0) / 1000) } };
  await put(`chars/${set}.json`, JSON.stringify(out));
  log(`${set} done: ${JSON.stringify(out.stats)}`);
  return out;
}

export async function run(log) {
  const q = new URLSearchParams(location.search);
  const set = q.get('set') || 'presets';
  const done = [];
  if (set === 'presets') done.push((await bakeSet('presets', Object.values(PRESETS).map((p) => structuredClone(p)), { px: 116, anims: ANIMS, log })).stats);
  else if (set === 'amb_all') {
    for (const reg of Object.keys(REGIONS)) done.push((await bakeSet('amb_' + reg, poolSpecs(reg), { log, lean: true })).stats);
  } else if (set.startsWith('amb_')) done.push((await bakeSet(set, poolSpecs(set.slice(4)), { log, lean: true })).stats);
  log('ALL DONE ' + JSON.stringify(done));
  console.log('[chars bake] done', done);
}
