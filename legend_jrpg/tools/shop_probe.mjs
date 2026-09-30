// 상점 화면을 단계별로 캡처(벨포트 도구점 NPC 대화부터). 실행: node tools/shop_probe.mjs
import { openGame } from './qa-lib.mjs';
const { page, errors, close, h } = await openGame();
await page.evaluate(async () => {
  const g = window.__game; const { GameState } = await import('/src/engine/state.js');
  const s = GameState.newGame(); s.addMember('mia', 5);
  for (const f of ['prologue_started', 'village_attacked', 'hero_awakened', 'elder_briefed', 'mia_joined', 'port_arrived']) s.setFlag(f);
  s.gold = 500; g.state = s; g.reset('field', { mapId: 'port', x: 24, y: 7, dir: 'up' });
});
await h.wait(1000); await h.spamUntil(() => h.fieldIdle(), { maxMs: 10000 });
await h.key('Enter'); await h.wait(250); await h.shot('probe_0_field_text');
await h.key('Enter'); await h.wait(60); await h.shot('probe_1_transition');
await h.wait(1200); await h.shot('probe_2_shop_greet');
await h.key('Enter'); await h.wait(100); await h.key('Enter'); await h.wait(500); await h.shot('probe_3_cmd');
await h.key('Enter'); await h.wait(500); await h.shot('probe_4_buylist');
await h.key('Enter'); await h.wait(500); await h.shot('probe_5_qty');
await h.key('Enter'); await h.wait(500); await h.shot('probe_6_bought');
await h.key('Enter'); await h.wait(500); await h.shot('probe_7_back');
for (let i = 0; i < 3; i++) { await h.key('Backspace'); await h.wait(300); }
await h.shot('probe_8_bye');
console.log(await h.stack(), errors);
await close();
