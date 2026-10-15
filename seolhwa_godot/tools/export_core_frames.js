// 기본 굽기(export_from_web.js의 프레임 부분만 — 월드·glb는 건드리지 않음): 공용 리그 고침(팔 흔들기 등) 뒤 다시 굽기.
//   frames.json: player는 지금 파일의 클립 목록(키) 그대로 다시 굽는다(웹 게임이 구운 목록 — 전투·칼 든 클립 포함). tiger는 그대로 둔다(리그 고침과 무관).
//   frames_npc.json: 마을 사람 9종 idle·walk·talk(export_from_web과 같음).
// 실행: python3 tools/web_export_server.py 8770 → http://localhost:8770/__tools/core_bake.html (예전 파일은 /__data/로 읽는다)
import * as fc from '/src/chars/frameCore.js';

const toPng = (cv) => (cv.convertToBlob ? cv.convertToBlob({ type: 'image/png' }) : new Promise((r) => cv.toBlob(r, 'image/png')));
const put = async (name, body) => { const r = await fetch('/export/' + name, { method: 'PUT', body }); if (!r.ok) throw new Error('PUT ' + name); };
const meta = (f) => ({ page: typeof f.page === 'number' ? f.page : f.page.index, u0: f.u0, u1: f.u1, v0: f.v0, v1: f.v1, x0: f.x0, x1: f.x1, y0: f.y0, y1: f.y1, lift: f.lift });
const yieldNow = () => new Promise((res) => { const ch = new MessageChannel(); ch.port1.onmessage = () => res(); ch.port2.postMessage(0); });

async function bakeKeys(kind, keys, prefix, tier = 'high') {
  const b = new fc.BakeBank(kind, tier);
  const clips = {};
  for (const key of keys) {
    if (clips[key]) continue;
    const c = b.clip(key); if (!c) continue;
    let g = 0; while (!b.step(c) && g++ < 600);
    clips[key] = { spec: c.spec, frames: c.frames.map(meta) };
    await yieldNow();
  }
  const pages = [];
  for (let i = 0; i < b.pages.length; i++) { const name = `${prefix}_${i}.png`; await put(name, await toPng(b.pages[i].cv)); pages.push(name); }
  return { pages, clips };
}

export async function run(log) {
  const old = await (await fetch('/__data/frames.json')).json();
  const out = { tiger: old.tiger };
  out.player = await bakeKeys('player', Object.keys(old.player.clips), 'frames_player');
  log('player clips=' + Object.keys(out.player.clips).length + ' pages=' + out.player.pages.length);
  // 예전 파일이 더 많은 페이지를 썼으면 남은 그림은 쓰이지 않는다(이름이 겹치지 않게 json이 가리키는 것만 쓴다)
  await put('frames.json', JSON.stringify(out));
  const kinds = ['villager_m', 'villager_f', 'elder', 'child_boy', 'child_girl', 'hunter', 'innkeeper', 'miller', 'woodcutter'];
  for (const k of kinds) fc.TIERS.high[k] = fc.TIERS.high.player;
  const npc = {};
  for (const kind of kinds) {
    const keys = [];
    for (const v of ['front', 'side', 'back']) for (const a of ['idle', 'walk', 'talk']) keys.push(fc.clipKey(fc.resolveView(kind, v, a), a, false, false));
    npc[kind] = await bakeKeys(kind, keys, `frames_${kind}`);
    log('npc ' + kind);
  }
  await put('frames_npc.json', JSON.stringify(npc));
  log('done core');
  console.log('[core bake] done');
}
