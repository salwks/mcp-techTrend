// 평양 「강을 판 사내」 프레임 굽기 — 웹 굽기 엔진(frameCore.BakeBank, high)을 그대로 쓰고, 웹 코드(seolhwa/src)는 고치지 않는다.
//  - py_merchant_a(한 객주 — 소금배 객주, 상인 CHR_HUM_002 변형): 갓, 누런 밤색 두루마기, 짐 없음. idle·walk·talk
//  - py_merchant_b(윤 상인 — 뗏목 목재상, 상인 변형): 머리띠, 잿빛 쪽색 저고리·조끼, 행전. idle·walk·talk
//  - py_swindler(흉 있는 사내 — 우치 이름을 빌린 사기꾼, 짐꾼 CHR_HUM_027 → 사람 적 변형): 키 크고 짙은 갈색 저고리·검은 배자 + 몽둥이
//      idle·walk·run·talk + HUM_COMBAT_LIGHT ready·swing·hit·fall·flee(tools/hum_combat_light.js) + tied(묶임)
//  - py_swindler_b(작은 사내 — 같은 변형): 작달막, 바랜 쪽빛 저고리·흰 머리띠 + 몽둥이. 같은 동작
//  - py_clerk(평양 서리 — 관원 변형): 옥색 두루마기·검은 갓·붓 주머니 없이 수수하게. idle·walk·talk
// 결과: data/frames_pyongyang.json + frames_pyongyang_<kind>_<n>.png (data/는 git 제외 — 다시 구워야 한다)
// 실행: python3 tools/web_export_server.py 8770 → 브라우저로 http://localhost:8770/__tools/pyongyang_bake.html
//   (헤드리스: Chromium 계열 --headless=new --virtual-time-budget=120000 --dump-dom 그 주소 — 끝나면 <p id=st>done…)
import { SPECS, getRig } from '/src/chars/rigs.js';
import * as fc from '/src/chars/frameCore.js';
import { installHCL, hclSpec } from '/__tools/hum_combat_light.js';

const PEOPLE = {
  py_merchant_a: { base: 'villager_m', over: { top: 'durumagi', coat: '#8a6a44', pants: '#d8cdb2', collar: '#4e3a26', goreum: '#4e3a26', vest: null, daenim: '#4e3a26',
    back: null, patch: null, hat: 'gat', stubble: true, robeLen: 96, build: 1.12, cheek: 0.2, shoe: '#3a3431' },
    anims: ['idle', 'walk', 'talk'] },
  py_merchant_b: { base: 'villager_m', over: { coat: '#5e6a78', pants: '#c9c0aa', vest: '#3b3a3a', collar: '#2e3540', daenim: '#2e3540', band: '#d8d0bc',
    back: null, patch: null, legwrap: '#e2dccb', stubble: true, build: 1.04, cheek: 0.16, shoe: '#5a4a38' },
    anims: ['idle', 'walk', 'talk'] },
  py_swindler: { base: 'villager_m', over: { coat: '#5a4636', pants: '#6a5e4e', vest: '#24201c', collar: '#24201c', daenim: '#24201c', band: null,
    back: null, patch: '#3e3228', legwrap: '#d0c8b4', stubble: true, cheek: 0.08, build: 1.18, height: 1.76, shoe: '#4a3f33' }, hcl: 'club',
    anims: ['idle', 'walk', 'run', 'talk', 'ready', 'swing', 'hit', 'fall', 'flee', 'tied'] },
  py_swindler_b: { base: 'villager_m', over: { coat: '#7c8a94', pants: '#a8a090', vest: null, collar: '#4a5258', daenim: '#4a5258', band: '#e7e0cf',
    back: null, patch: '#5e6a70', legwrap: '#d8d2c2', stubble: false, cheek: 0.22, build: 0.92, height: 1.5, shoe: '#5a4a38' }, hcl: 'club',
    anims: ['idle', 'walk', 'run', 'talk', 'ready', 'swing', 'hit', 'fall', 'flee', 'tied'] },
  py_clerk: { base: 'villager_m', over: { top: 'durumagi', coat: '#b9cbc4', pants: '#e2dccb', collar: '#5e7470', goreum: '#5e7470', vest: null, daenim: '#5e7470',
    back: null, patch: null, hat: 'gat', stubble: false, robeLen: 100, build: 0.94, cheek: 0.12, shoe: '#2b2622' },
    anims: ['idle', 'walk', 'talk'] },
};

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
    else getRig(kind);
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
    for (let i = 0; i < b.pages.length; i++) { const name = `frames_pyongyang_${kind}_${i}.png`; await put(name, await toPng(b.pages[i].cv)); pages.push(name); }
    out[kind] = { pages, clips };
    log('baked ' + kind + ' pages=' + pages.length + ' clips=' + Object.keys(clips).length);
  }
  await put(only ? `frames_pyongyang_${only.replace(/,/g, '_')}.json` : 'frames_pyongyang.json', JSON.stringify(out));
  log('done: ' + Object.keys(out).join(', '));
  console.log('[pyongyang bake] done', Object.keys(out));
}
