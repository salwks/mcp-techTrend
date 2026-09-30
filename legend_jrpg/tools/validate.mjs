// 데이터 참조 무결성 검사기 (qa-tester). 실행: node tools/validate.mjs  (오류가 있으면 exit 1)
// 게임 코드를 수정하지 않고 src/data/*.js 를 직접 import 해서 검사한다.
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';

globalThis.window ??= globalThis;
globalThis.localStorage ??= { getItem: () => null, setItem() {}, removeItem() {} };

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const imp = (p) => import(pathToFileURL(path.join(root, p)).href);

const { MAPS } = await imp('src/data/maps.js');
const { EVENTS } = await imp('src/data/events.js');
const { ITEMS } = await imp('src/data/items.js');
const skillsMod = await imp('src/data/skills.js');
const { SKILLS } = skillsMod;
const ENEMY_SKILLS = skillsMod.ENEMY_SKILLS || {};
const getSkill = skillsMod.getSkill || ((id) => SKILLS[id] || ENEMY_SKILLS[id]);
const { ENEMIES } = await imp('src/data/enemies.js');
const { TROOPS } = await imp('src/data/troops.js');
const { ENCOUNTERS } = await imp('src/data/encounters.js');
const { CHARACTERS } = await imp('src/data/characters.js');

const errors = [], warnings = [];
const err = (m) => errors.push(m);
const warn = (m) => warnings.push(m);

const WALK = new Set(['.', ',', 'F', 'S', '=', '_', 'K', 'B', 'D', 'X', 'C', '^']);
const BLOCK = new Set(['T', 't', '~', '#', 'H', 'R', 'M', 'W', 'L', 'P', 'A', 'c', 'b', 'f', 'w', ' ']);
const BGM = new Set(['title', 'village', 'town', 'field', 'forest', 'dungeon', 'tower', 'castle', 'battle', 'boss', 'final_boss', 'victory', 'sad', 'ending']);
const SFX = new Set(['cursor', 'confirm', 'cancel', 'buzzer', 'hit', 'crit', 'miss', 'magic', 'fire', 'ice', 'thunder', 'holy', 'heal', 'levelup', 'encounter', 'escape', 'chest', 'door', 'step', 'item', 'enemy_die', 'victory']);
const SPRITES = new Set(['ren', 'mia', 'garen', 'sela', 'elder', 'lina', 'villager_m', 'villager_f', 'child', 'merchant', 'innkeeper', 'blacksmith', 'soldier', 'priest', 'sailor', 'mage', 'old_man', 'cat', 'wolf', 'goblin', 'monster', 'lich', 'vorg', 'demon_king', 'save_crystal', 'sign', 'chest']);
// 전투 배경 키: src/battle/backgrounds.js 에서 읽는다
const bgSrc = fs.readFileSync(path.join(root, 'src/battle/backgrounds.js'), 'utf8');
const BG = new Set([...bgSrc.matchAll(/^  ([a-z_]+): \(c, rnd\)/gm)].map((m) => m[1]));
const CMDS = new Set(['text', 'choice', 'if', 'setFlag', 'join', 'battle', 'giveItem', 'takeItem', 'giveGold', 'equip', 'heal', 'inn', 'shop', 'teleport', 'wait', 'shake', 'flash', 'bgm', 'sfx', 'npcMove', 'playerMove', 'face', 'save', 'ending', 'fadeOut', 'fadeIn']);

const tileAt = (m, x, y) => (m.tiles[y] || '')[x];
function checkWalkTarget(where, mapId, x, y) {
  const m = MAPS[mapId];
  if (!m) return err(`${where}: 알 수 없는 맵 '${mapId}'`);
  if (!Number.isInteger(x) || !Number.isInteger(y)) return err(`${where}: 좌표가 정수가 아님 (${x},${y})`);
  if (y < 0 || y >= m.tiles.length || x < 0 || x >= m.tiles[0].length) return err(`${where}: ${mapId}(${x},${y}) 범위 밖`);
  const ch = tileAt(m, x, y);
  if (!WALK.has(ch)) err(`${where}: ${mapId}(${x},${y}) 통행 불가 타일 '${ch}'`);
  // 같은 칸에 NPC 가 서 있는지
  const npc = (m.npcs || []).find((n) => n.x === x && n.y === y && !n.showIf);
  if (npc) warn(`${where}: ${mapId}(${x},${y})에 NPC '${npc.id}'가 서 있음`);
}

// ---------- 캐릭터 ----------
for (const [id, c] of Object.entries(CHARACTERS)) {
  for (const l of c.learnset || []) if (!SKILLS[l.skill]) err(`CHARACTERS.${id}.learnset: 스킬 '${l.skill}' 없음`);
  for (const [slot, it] of Object.entries(c.startEquip || {})) {
    if (it == null) continue;
    if (!ITEMS[it]) err(`CHARACTERS.${id}.startEquip.${slot}: 아이템 '${it}' 없음`);
    else if (ITEMS[it].type !== slot) err(`CHARACTERS.${id}.startEquip.${slot}: '${it}'의 type=${ITEMS[it].type}`);
    else if (ITEMS[it].equipBy && !ITEMS[it].equipBy.includes(id)) err(`CHARACTERS.${id}.startEquip: '${it}' 장착 불가(equipBy)`);
  }
}

// ---------- 아이템 ----------
for (const [id, it] of Object.entries(ITEMS)) {
  for (const who of it.equipBy || []) if (!CHARACTERS[who]) err(`ITEMS.${id}.equipBy: 알 수 없는 멤버 '${who}'`);
  if (it.type === 'consumable' && !it.effect) err(`ITEMS.${id}: consumable 인데 effect 없음`);
}

// ---------- 적 / 트룹 / 인카운터 ----------
for (const [id, e] of Object.entries(ENEMIES)) {
  for (const s of e.skills || []) {
    const sid = typeof s === 'string' ? s : s.id;
    if (sid !== 'attack' && !getSkill(sid)) err(`ENEMIES.${id}.skills: '${sid}' 해석 불가`);
  }
  for (const d of e.drops || []) if (!ITEMS[d.item]) err(`ENEMIES.${id}.drops: 아이템 '${d.item}' 없음`);
}
for (const [id, t] of Object.entries(TROOPS)) {
  if (!t.enemies?.length) err(`TROOPS.${id}: enemies 비어 있음`);
  for (const e of t.enemies || []) if (!ENEMIES[e]) err(`TROOPS.${id}: 적 '${e}' 없음`);
  if (t.bgm && !BGM.has(t.bgm)) err(`TROOPS.${id}.bgm: 알 수 없는 BGM '${t.bgm}'`);
}
for (const [id, enc] of Object.entries(ENCOUNTERS)) {
  if (!(enc.rate > 0 && enc.rate < 1)) warn(`ENCOUNTERS.${id}.rate 이상값 ${enc.rate}`);
  for (const t of enc.troops || []) if (!TROOPS[t.troop]) err(`ENCOUNTERS.${id}: 트룹 '${t.troop}' 없음`);
}

// ---------- 이벤트 ----------
const referencedEvents = new Set();
function refEvent(where, id) {
  if (!id) return;
  referencedEvents.add(id);
  if (!EVENTS[id]) err(`${where}: 이벤트 '${id}' 없음`);
}
function walkCmds(where, cmds) {
  if (cmds == null) return;
  if (!Array.isArray(cmds)) return err(`${where}: 명령 목록이 배열이 아님`);
  cmds.forEach((c, i) => {
    const w = `${where}[${i}]`;
    if (!c || typeof c !== 'object') return err(`${w}: 잘못된 명령 ${JSON.stringify(c)}`);
    if (!CMDS.has(c.cmd)) err(`${w}: 알 수 없는 cmd '${c.cmd}'`);
    switch (c.cmd) {
      case 'text': if (typeof c.text !== 'string') err(`${w}: text 없음`); break;
      case 'choice':
        if (!c.options?.length) err(`${w}: options 없음`);
        if ((c.branches || []).length > (c.options || []).length) warn(`${w}: branches가 options보다 많음`);
        (c.branches || []).forEach((b, j) => walkCmds(`${w}.branches[${j}]`, b));
        break;
      case 'if':
        if (!c.flag && !c.member && !c.item) err(`${w}: 조건(flag/member/item) 없음`);
        if (c.member && !CHARACTERS[c.member]) err(`${w}: 멤버 '${c.member}' 없음`);
        if (c.item && !ITEMS[c.item]) err(`${w}: 아이템 '${c.item}' 없음`);
        walkCmds(`${w}.then`, c.then); walkCmds(`${w}.else`, c.else);
        break;
      case 'setFlag': if (!c.flag) err(`${w}: flag 없음`); break;
      case 'join':
        if (!CHARACTERS[c.member]) err(`${w}: 멤버 '${c.member}' 없음`);
        break;
      case 'battle':
        if (!TROOPS[c.troop]) err(`${w}: 트룹 '${c.troop}' 없음`);
        if (c.bgm && !BGM.has(c.bgm)) err(`${w}: BGM '${c.bgm}' 없음`);
        if (c.bg && !BG.has(c.bg)) err(`${w}: 전투 배경 '${c.bg}' 없음`);
        walkCmds(`${w}.onWin`, c.onWin); walkCmds(`${w}.onLose`, c.onLose);
        break;
      case 'giveItem': case 'takeItem':
        if (!ITEMS[c.item]) err(`${w}: 아이템 '${c.item}' 없음`); break;
      case 'giveGold': if (typeof c.amount !== 'number') err(`${w}: amount 없음`); break;
      case 'equip': {
        if (!CHARACTERS[c.member]) err(`${w}: 멤버 '${c.member}' 없음`);
        const it = ITEMS[c.item];
        if (!it) err(`${w}: 아이템 '${c.item}' 없음`);
        else if (it.equipBy && !it.equipBy.includes(c.member)) err(`${w}: ${c.member}는 '${c.item}' 장착 불가`);
        break;
      }
      case 'inn': if (!(c.price >= 0)) err(`${w}: price 없음`); break;
      case 'shop':
        if (!c.items?.length) err(`${w}: 상점 items 비어 있음`);
        for (const it of c.items || []) {
          if (!ITEMS[it]) err(`${w}: 상점 아이템 '${it}' 없음`);
          else if (!(ITEMS[it].price > 0)) err(`${w}: 상점 아이템 '${it}' price=${ITEMS[it].price}`);
        }
        break;
      case 'teleport': checkWalkTarget(w + ' teleport', c.map, c.x, c.y); break;
      case 'bgm': if (!BGM.has(c.key)) err(`${w}: BGM '${c.key}' 없음`); break;
      case 'sfx': if (!SFX.has(c.name)) err(`${w}: SFX '${c.name}' 없음`); break;
      case 'npcMove': if (!c.npc) err(`${w}: npc 없음`); if (c.path && !/^[UDLR]*$/.test(c.path)) err(`${w}: path '${c.path}' 형식 오류`); break;
      case 'playerMove': if (c.path && !/^[UDLR]*$/.test(c.path)) err(`${w}: path '${c.path}' 형식 오류`); break;
    }
  });
}
for (const [id, cmds] of Object.entries(EVENTS)) walkCmds(`EVENTS.${id}`, cmds);

// ---------- 맵 ----------
for (const [id, m] of Object.entries(MAPS)) {
  const W = m.tiles?.[0]?.length ?? 0;
  if (!m.tiles?.length) { err(`MAPS.${id}: tiles 없음`); continue; }
  m.tiles.forEach((row, y) => {
    if (row.length !== W) err(`MAPS.${id}: ${y}행 길이 ${row.length} ≠ ${W}`);
    for (const ch of row) if (!WALK.has(ch) && !BLOCK.has(ch)) err(`MAPS.${id}: ${y}행에 알 수 없는 타일 '${ch}'`);
  });
  if (m.bgm && !BGM.has(m.bgm)) err(`MAPS.${id}.bgm '${m.bgm}' 없음`);
  if (m.battleBg && !BG.has(m.battleBg)) err(`MAPS.${id}.battleBg '${m.battleBg}' 없음`);
  if (m.encounter && !ENCOUNTERS[m.encounter]) err(`MAPS.${id}.encounter '${m.encounter}' 없음`);
  refEvent(`MAPS.${id}.onEnter`, m.onEnter);
  const ids = new Set();
  for (const n of m.npcs || []) {
    const w = `MAPS.${id}.npcs.${n.id}`;
    if (ids.has(n.id)) err(`${w}: 중복 id`); ids.add(n.id);
    if (!SPRITES.has(n.sprite)) err(`${w}: 스프라이트 '${n.sprite}' 없음`);
    refEvent(w, n.event);
    if (!n.event && !n.lines?.length) warn(`${w}: event/lines 둘 다 없음`);
    const ch = tileAt(m, n.x, n.y);
    if (!WALK.has(ch)) warn(`${w}: (${n.x},${n.y}) 타일 '${ch}' 위에 서 있음`);
  }
  for (const [i, t] of (m.triggers || []).entries()) {
    refEvent(`MAPS.${id}.triggers[${i}]`, t.event);
    for (let dy = 0; dy < (t.h || 1); dy++) for (let dx = 0; dx < (t.w || 1); dx++) {
      const ch = tileAt(m, t.x + dx, t.y + dy);
      if (ch === undefined) err(`MAPS.${id}.triggers[${i}]: (${t.x + dx},${t.y + dy}) 범위 밖`);
    }
    if (![...Array(t.h || 1).keys()].some((dy) => [...Array(t.w || 1).keys()].some((dx) => WALK.has(tileAt(m, t.x + dx, t.y + dy)))))
      err(`MAPS.${id}.triggers[${i}] (${t.x},${t.y}): 밟을 수 있는 칸이 없음`);
  }
  for (const [i, e] of (m.exits || []).entries()) {
    const w = `MAPS.${id}.exits[${i}]`;
    if (!MAPS[e.to]) { err(`${w}: 목적지 맵 '${e.to}' 없음`); continue; }
    checkWalkTarget(w, e.to, e.tx, e.ty);
    const ch = tileAt(m, e.x, e.y);
    if (ch === undefined) err(`${w}: (${e.x},${e.y}) 범위 밖`);
    else if (!WALK.has(ch)) warn(`${w}: 출구 칸 (${e.x},${e.y}) 타일 '${ch}' 통행 불가`);
    // 도착 칸이 곧바로 다른 출구 위면 무한 왕복 위험
    const back = (MAPS[e.to].exits || []).find((x) => e.tx >= x.x && e.tx < x.x + (x.w || 1) && e.ty >= x.y && e.ty < x.y + (x.h || 1));
    if (back) warn(`${w}: 도착 칸 ${e.to}(${e.tx},${e.ty})이 다시 출구 위`);
  }
  for (const c of m.chests || []) {
    if (c.item && !ITEMS[c.item]) err(`MAPS.${id}.chests.${c.id}: 아이템 '${c.item}' 없음`);
    if (!c.item && !(c.gold > 0)) err(`MAPS.${id}.chests.${c.id}: 내용 없음`);
    if (!tileAt(m, c.x, c.y)) err(`MAPS.${id}.chests.${c.id}: 범위 밖`);
  }
  for (const [i, o] of (m.objects || []).entries()) {
    if (!SPRITES.has(o.sprite)) err(`MAPS.${id}.objects[${i}]: 스프라이트 '${o.sprite}' 없음`);
    refEvent(`MAPS.${id}.objects[${i}]`, o.event);
  }
}

// 이벤트 안에서 다른 이벤트를 참조하진 않으므로, 어디에서도 쓰이지 않는 이벤트는 경고
for (const id of Object.keys(EVENTS)) if (!referencedEvents.has(id)) warn(`EVENTS.${id}: 어디에서도 참조되지 않음`);

console.log(`맵 ${Object.keys(MAPS).length} · 이벤트 ${Object.keys(EVENTS).length} · 아이템 ${Object.keys(ITEMS).length} · 적 ${Object.keys(ENEMIES).length} · 트룹 ${Object.keys(TROOPS).length} · 전투배경 ${[...BG].join(',')}`);
for (const w of warnings) console.log('WARN  ' + w);
for (const e of errors) console.log('ERROR ' + e);
console.log(`\n결과: 오류 ${errors.length}, 경고 ${warnings.length}`);
process.exit(errors.length ? 1 : 0);
