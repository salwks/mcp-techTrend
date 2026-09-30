// 시각 점검: 모든 맵 스크린샷 + 벨포트 NPC 상점 + 여관 + 메뉴.
// 실행: node tools/visual.mjs   (QA_OUT=스크린샷 폴더)
import { openGame, ROOT } from './qa-lib.mjs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const { MAPS } = await import(pathToFileURL(path.join(ROOT, 'src/data/maps.js')).href);
const WALK = new Set(['.', ',', 'F', 'S', '=', '_', 'K', 'B', 'D', 'X', 'C', '^']);
const FLAGS = ['prologue_started', 'village_attacked', 'hero_awakened', 'elder_briefed', 'port_arrived', 'cave_entered', 'plains_arrived',
  'tower_arrived', 'wasteland_arrived', 'castle_arrived', 'throne_arrived'];

function centerTile(m) {
  const H = m.tiles.length, W = m.tiles[0].length;
  const occ = new Set((m.npcs || []).map((n) => `${n.x},${n.y}`));
  const trig = new Set();
  for (const t of m.triggers || []) for (let dy = 0; dy < (t.h || 1); dy++) for (let dx = 0; dx < (t.w || 1); dx++) trig.add(`${t.x + dx},${t.y + dy}`);
  for (const e of m.exits || []) for (let dy = 0; dy < (e.h || 1); dy++) for (let dx = 0; dx < (e.w || 1); dx++) trig.add(`${e.x + dx},${e.y + dy}`);
  let best = null, bd = 1e9;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (!WALK.has(m.tiles[y][x]) || occ.has(`${x},${y}`) || trig.has(`${x},${y}`)) continue;
    const d = (x - W / 2) ** 2 + (y - H / 2) ** 2;
    if (d < bd) { bd = d; best = { x, y }; }
  }
  return best;
}

const { page, errors, close, h } = await openGame();
async function setup(mapId, x, y, dir = 'down') {
  await page.evaluate(({ mapId, x, y, dir, FLAGS }) => {
    const g = window.__game;
    const GS = g.state?.constructor;
    return (GS ? Promise.resolve(GS) : import('/src/engine/state.js').then((m) => m.GameState)).then((GS) => {
      const s = GS.newGame();
      for (const id of ['mia', 'garen', 'sela']) s.addMember(id, 12);
      for (const f of FLAGS) s.setFlag(f);
      s.gold = 3000; s.addItem('potion', 3);
      g.state = s;
      g.reset('field', { mapId, x, y, dir });
    });
  }, { mapId, x, y, dir, FLAGS });
  await h.wait(900);
  await h.spamUntil(() => h.fieldIdle(), { maxMs: 20000 });
  await h.wait(300);
}

for (const id of Object.keys(MAPS)) {
  const p = centerTile(MAPS[id]);
  await setup(id, p.x, p.y);
  const pos = await h.mapPos();
  const f = await h.shot(`map_${id}`);
  console.log(`map ${id} @${JSON.stringify(pos)} → ${f}`);
}

// 벨포트 도구점: 카운터 너머 NPC(24,5)에게 (24,7)에서 위를 보고 말 걸기
await setup('port', 24, 7, 'up');
await h.key('ArrowUp', 30); await h.wait(200);
const shopOk = await h.spamUntil(async () => (await h.top()) === 'ShopScene', { maxMs: 10000 });
await h.wait(600);
console.log('shop opened via NPC:', shopOk, await h.stack());
console.log('field msg active behind shop:', await page.evaluate(() => { const f = window.__game.stack.find((s) => s.constructor.name === 'FieldScene'); return { msgActive: f.msg.active, shopOpaque: window.__game.top.opaque }; }));
console.log(await h.shot('shop_port_item'));
// 구매 목록 진입
await h.key('Enter'); await h.wait(400); console.log(await h.shot('shop_port_item_buy'));
for (let i = 0; i < 6 && (await h.top()) === 'ShopScene'; i++) { await h.key('Backspace'); await h.wait(250); }
await h.spamUntil(() => h.fieldIdle(), { maxMs: 8000 });
console.log(await h.shot('shop_port_after_close'));

// 여관
await setup('port_inn', 2, 4, 'up');
await h.key('ArrowUp', 30); await h.wait(200);
await h.key('Enter'); await h.wait(600);
for (let i = 0; i < 8; i++) { if (await page.evaluate(() => !!window.__game.top.choice)) break; await h.key('Enter'); await h.wait(300); }
console.log(await h.shot('inn_choice'));
await h.key('Enter'); await h.wait(300); await h.key('Enter'); await h.wait(1200);
console.log(await h.shot('inn_after'));
await h.spamUntil(() => h.fieldIdle(), { maxMs: 10000 });

// 메뉴 (4인 파티)
await h.key('Escape'); await h.wait(500);
console.log(await h.shot('menu_party4'));
await h.key('Escape'); await h.wait(300);

console.log('errors:', errors);
await close();
