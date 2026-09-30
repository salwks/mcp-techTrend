// 스토리 진행 테스트: 각 보스 직전 상태를 만들고 트리거로 걸어 들어가 전투를 해결한다.
// 실행: node tools/story.mjs [bossName...]   (QA_OUT=스크린샷 폴더, QA_REAL=treant,sea_serpent 실제 입력으로 싸울 보스)
import { openGame } from './qa-lib.mjs';
import { ROOT } from './qa-lib.mjs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const { MAPS } = await import(pathToFileURL(path.join(ROOT, 'src/data/maps.js')).href);
const WALK = new Set(['.', ',', 'F', 'S', '=', '_', 'K', 'B', 'D', 'X', 'C', '^']);
const REAL = new Set((process.env.QA_REAL ?? 'treant,sea_serpent').split(',').filter(Boolean));

const ORDER = ['prologue_started', 'village_attacked', 'hero_awakened', 'elder_briefed', 'mia_rescued', 'mia_joined', 'treant_defeated',
  'port_arrived', 'garen_joined', 'cave_entered', 'serpent_defeated', 'sword_awakened', 'plains_arrived', 'tower_arrived', 'sela_met',
  'lich_defeated', 'sela_joined', 'tower_cleared', 'wasteland_arrived', 'camp_banter', 'black_dragon_defeated', 'castle_arrived',
  'vorg_defeated', 'throne_arrived', 'demon_king_defeated', 'game_clear'];
const upTo = (f) => ORDER.slice(0, ORDER.indexOf(f) + 1);

const G = { weapon: 'sealed_sword', gear: {} };
const BOSSES = [
  { name: 'treant', map: 'forest', trig: [33, 14], flags: upTo('mia_joined'), party: { ren: 5, mia: 5 }, sword: 'sealed_sword',
    gear: { ren: ['leather_armor'] }, done: 'treant_defeated' },
  { name: 'sea_serpent', map: 'cave', trig: [30, 17], flags: upTo('cave_entered'), party: { ren: 9, mia: 9, garen: 9 }, sword: 'sealed_sword',
    gear: { ren: ['chain_mail', 'power_ring'], mia: ['silver_staff', 'silk_robe'], garen: ['steel_spear', 'guard_ring'] }, done: 'sword_awakened',
    expect: { members: ['ren', 'mia', 'garen'], renWeapon: 'awakened_sword', map: 'port', hiddenNpc: ['port', 'gate_guard'] } },
  { name: 'lich', map: 'tower_top', trig: [9, 9], flags: upTo('sela_met'), party: { ren: 13, mia: 13, garen: 13 }, sword: 'awakened_sword',
    gear: { ren: ['silver_mail'], mia: ['sage_robe'], garen: ['silver_mail'] }, done: 'tower_cleared',
    expect: { members: ['ren', 'mia', 'garen', 'sela'], renWeapon: 'holy_sword', map: 'plains', hiddenNpc: ['plains', 'post_guard'] } },
  { name: 'black_dragon', map: 'wasteland', trig: [33, 12], flags: upTo('camp_banter'), party: { ren: 16, mia: 16, garen: 16, sela: 16 }, sword: 'holy_sword',
    gear: {}, done: 'black_dragon_defeated' },
  { name: 'general_vorg', map: 'castle', trig: [15, 3], flags: upTo('castle_arrived'), party: { ren: 19, mia: 19, garen: 19, sela: 19 }, sword: 'holy_sword',
    gear: { ren: ['mithril_mail'], garen: ['dragon_spear', 'mithril_mail'], sela: ['archmage_rod'], mia: ['saint_staff'] }, done: 'vorg_defeated' },
  { name: 'demon_king', map: 'throne', trig: [9, 7], flags: upTo('throne_arrived'), party: { ren: 22, mia: 22, garen: 22, sela: 22 }, sword: 'holy_sword',
    gear: { ren: ['mithril_mail', 'angel_charm'], garen: ['dragon_spear', 'mithril_mail'], sela: ['archmage_rod', 'sage_robe'], mia: ['saint_staff', 'sage_robe'] },
    done: 'game_clear', ending: true },
];

// 트리거 칸에 인접한 통행 가능 칸(트리거 밖)을 찾는다
function approach(mapId, [tx, ty]) {
  const m = MAPS[mapId];
  const trigCells = new Set();
  for (const t of m.triggers || []) for (let dy = 0; dy < (t.h || 1); dy++) for (let dx = 0; dx < (t.w || 1); dx++) trigCells.add(`${t.x + dx},${t.y + dy}`);
  const occupied = new Set((m.npcs || []).map((n) => `${n.x},${n.y}`));
  const dirs = [[0, 1, 'ArrowUp'], [-1, 0, 'ArrowRight'], [1, 0, 'ArrowLeft'], [0, -1, 'ArrowDown']];
  for (const [dx, dy, key] of dirs) {
    const x = tx + dx, y = ty + dy;
    if (WALK.has(m.tiles[y]?.[x]) && !trigCells.has(`${x},${y}`) && !occupied.has(`${x},${y}`)) return { x, y, key };
  }
  throw new Error('접근 칸 없음 ' + mapId);
}

const only = process.argv.slice(2);
const { page, errors, close, h } = await openGame();
const results = [];
const log = (s) => { console.log(s); results.push(s); };

for (const b of BOSSES) {
  if (only.length && !only.includes(b.name)) continue;
  const errBefore = errors.length;
  const ap = approach(b.map, b.trig);
  await page.evaluate(({ b, ap }) => {
    const g = window.__game;
    const GS = g.state ? g.state.constructor : null;
    return { GS: !!GS };
  }, { b, ap });
  // 상태 구성 (타이틀에서 시작했다면 먼저 새 게임 상태를 만든다)
  const setup = await page.evaluate(async ({ b, ap }) => {
    const g = window.__game;
    let GS = g.state?.constructor;
    if (!GS) { const mod = await import('/src/engine/state.js'); GS = mod.GameState; }
    const s = GS.newGame();
    for (const [id, lv] of Object.entries(b.party)) {
      if (id === 'ren') { s.members.ren = undefined; delete s.members.ren; s.party = []; }
      s.addMember(id, lv);
    }
    for (const f of b.flags) s.setFlag(f);
    s.gold = 5000;
    s.addItem('potion', 5); s.addItem('ether', 3);
    s.forceEquip ? s.forceEquip('ren', b.sword) : s.equip('ren', b.sword);
    for (const [id, items] of Object.entries(b.gear)) for (const it of items) { s.addItem(it); s.equip(id, it); }
    s.fullHeal();
    g.state = s;
    g.reset('field', { mapId: b.map, x: ap.x, y: ap.y, dir: 'up' });
    return { party: s.party, ren: s.members.ren.equip };
  }, { b, ap });
  await h.wait(900);
  // onEnter 등 이벤트가 있으면 먼저 넘긴다
  await h.spamUntil(() => h.fieldIdle(), { maxMs: 30000 });
  const pos = await h.mapPos();
  log(`\n== ${b.name}: party ${JSON.stringify(setup.party)} 시작 ${JSON.stringify(pos)} → ${ap.key}`);
  await h.key(ap.key, 200);
  await h.wait(500);
  const real = REAL.has(b.name);
  let battles = 0, lastTop = '', forcedAt = 0, gameover = false, shotBattle = false;
  const endCond = b.ending
    ? async () => (await h.top()) === 'TitleScene'
    : async () => (await h.flag(b.done)) && (await h.fieldIdle());
  const ok = await h.spamUntil(endCond, {
    maxMs: real ? 300000 : 120000,
    onTick: async () => {
      const top = await h.top();
      if (top !== lastTop) {
        if (top === 'BattleScene') { battles++; shotBattle = false; }
        if (top === 'EndingScene') { log('  EndingScene 도달'); await h.wait(1500); await h.shot(`story_${b.name}_ending`); }
        lastTop = top;
      }
      if (top === 'GameOverScene') { gameover = true; throw new Error('게임오버'); }
      if (top === 'BattleScene') {
        const mode = await page.evaluate(() => window.__game.top.mode);
        if (mode === 'cmd' && !shotBattle) { shotBattle = true; await h.shot(`story_${b.name}_battle${battles}`); }
        if (!real && mode === 'cmd' && Date.now() - forcedAt > 300) { forcedAt = Date.now(); await h.killEnemies(); }
      }
    },
  }).catch((e) => { log('  예외: ' + e.message); return false; });
  const st = await page.evaluate(() => { const s = window.__game.state; return s && { party: [...s.party], weapon: s.members.ren?.equip.weapon, lv: Object.fromEntries(s.party.map((id) => [id, s.members[id].level])), flags: Object.keys(s.flags).filter((k) => s.flags[k]) }; });
  const p = await h.mapPos();
  log(`  결과: ${ok ? 'OK' : 'FAIL'} (${real ? '실제 입력' : '강제 처치'}) 전투 ${battles}회, top=${await h.top()}, pos=${JSON.stringify(p)}, ren무기=${st?.weapon}, party=${JSON.stringify(st?.party)} lv=${JSON.stringify(st?.lv)}${gameover ? ' GAMEOVER' : ''}`);
  if (b.expect && ok) {
    const e = b.expect;
    const miss = e.members.filter((m) => !st.party.includes(m));
    log(`  합류 확인 ${miss.length ? 'FAIL 누락 ' + miss : 'OK'}; 성검 ${st.weapon === e.renWeapon ? 'OK' : 'FAIL ' + st.weapon}; 맵 ${p?.map === e.map ? 'OK' : 'FAIL ' + p?.map}`);
    const [mid, npc] = e.hiddenNpc;
    if (p?.map === mid) {
      const vis = await page.evaluate((npc) => { const f = window.__game.top; return f.visibleNpcs().some((n) => n.id === npc); }, npc);
      log(`  게이트 NPC '${npc}' ${vis ? 'FAIL 아직 보임' : 'OK 사라짐'}`);
    }
  }
  if (!b.ending) await h.shot(`story_${b.name}_after`);
  for (const e of errors.slice(errBefore)) log('  ERR ' + e);
}
await close();
