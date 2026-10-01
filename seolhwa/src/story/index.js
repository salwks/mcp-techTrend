// 설화록 3단계 — 이야기 모듈 진입점 (STORY.md §3.1)
import { Engine, newState } from './engine.js';
import {
  CLUES, RULES, ITEMS, SAVE_KEY, anchor, arena, perches, pathClueCount,
} from './common.js';
import { OBJECTS, examineObject, makeScenes } from './case_sanggil.js';
import { talk } from './dialogue.js';
import { buildJournal, endingData } from './journal.js';

// 이야기에 꼭 필요한 마을 사람(월드에 없으면 직접 세운다)
const EXTRAS = [
  { id: 'jumo', kind: 'innkeeper', name: '주모', anchor: 'inn', off: { x: -1.4, z: 0.2 }, facing: 'down' },
  { id: 'miller', kind: 'miller', name: '방앗간 주인', anchor: 'mill', off: { x: 1.0, z: 0.2 }, facing: 'down' },
  { id: 'woodcutter', kind: 'woodcutter', name: '나무꾼', anchor: 'woodcutter', off: { x: 0, z: 0 }, facing: 'down' },
];
const NO_TALK = new Set(['tiger']);

function safe(fn) { try { return fn(); } catch (err) { console.warn('[story]', err); return null; } }

export function createStory(ctx) {
  const S = new Engine(ctx, { clues: CLUES, rules: RULES, items: ITEMS });
  const npcs = ctx.npcs || {};

  // 처음 자리 기억(다시 하기용)
  const home = {};
  for (const id in npcs) {
    const a = npcs[id];
    if (a && a.pos) home[id] = { x: a.pos.x, z: a.pos.z, facing: a.facing };
  }

  // ---- 보조 배우 ----
  function ensureExtras() {
    for (const e of EXTRAS) {
      if (npcs[e.id]) continue;
      const byKind = Object.keys(npcs).find((k) => npcs[k]?.data?.kind === e.kind);
      if (byKind) { S.alias[e.id] = byKind; continue; }
      if (S.spawned[e.id]) continue;
      const p = anchor(S, e.anchor);
      S.spawn(e.id, e.kind, { x: p.x + e.off.x, z: p.z + e.off.z }, e.facing, { id: e.id, kind: e.kind, name: e.name });
    }
  }
  function ensureMerchant() {
    if (S.spawned.merchant) return;
    const m = ctx.world?.anchors?.merchant;
    if (!m) return;
    S.spawn('merchant', 'villager_m', { x: m.x + 0.6, z: m.z + 0.2 }, 'down', { id: 'merchant', kind: 'villager_m', name: '장꾼' });
  }

  // ---- 오누이 자리 ----
  const KIDS = ['suni', 'dori'];
  function setVisible(id, on) {
    const a = S.actor(id);
    if (a?.char?.object3d) a.char.object3d.visible = on;
  }
  function placeKids(climax = false, fled = false) {
    const ph = S.state.phase;
    const inTree = S.is('kids_in_tree') || fled || S.is('kids_fled_to_tree');
    KIDS.forEach((id, i) => {
      const a = S.actor(id);
      if (!a) return;
      setVisible(id, true);
      if (ph === 'morning' || ph === 'done') {
        S.place(id, anchor(S, `kid_morning_${id}`));
        a.scripted = false;
        S.face(id, 'down');
        S.anim(id, 'idle');
      } else if (ph === 'night' && inTree) {
        const p = perches(S)[i] || perches(S)[0];
        S.place(id, p);
        a.scripted = true;
        S.anim(id, 'perch');
        S.face(id, 'down');
      } else if (ph === 'night' && climax) {
        S.place(id, anchor(S, 'kid_inside'));
        a.scripted = true;
        setVisible(id, false);
      } else if (ph === 'night') {
        S.place(id, anchor(S, `kid_night_${id}`));
        a.scripted = false;
        S.anim(id, 'idle');
      } else {
        const h = home[id];
        if (h) S.place(id, h);
        a.scripted = false;
        if (h?.facing) S.face(id, h.facing);
        S.anim(id, 'idle');
      }
    });
  }
  function hideKids(on) {
    if (S.is('kids_in_tree') || S.is('kids_fled_to_tree')) return;
    KIDS.forEach((id) => setVisible(id, !on));
  }

  // ---- 결말 카드 ----
  async function showEnding() {
    const d = endingData(S);
    story.lastEnding = { ...d, state: JSON.parse(JSON.stringify(S.state)) };
    S.log('ending', d.outcome);
    let r = null;
    if (ctx.ui?.ending) {
      try { r = await ctx.ui.ending(d); } catch (err) { console.warn('[story] ending', err); }
    } else {
      await S.say(d.title, [...d.paragraphs, d.record]);
      r = 'restart';
    }
    S.log('endingClosed', r);
    restart();
  }

  const api = { placeKids, hideKids, ensureMerchant, showEnding };
  const scenes = makeScenes(S, api);

  // ---- 조사 대상 목록(프레임마다 불림 → 캐시) ----
  let targets = [];
  let npcTargets = [];
  let dirty = true;
  let rebuildT = 0;
  function rebuild() {
    dirty = false;
    rebuildT = 0;
    const list = [];
    npcTargets = [];
    const ids = new Set([...Object.keys(npcs), ...Object.keys(S.spawned), ...EXTRAS.map((e) => e.id)]);
    for (const id of ids) {
      if (NO_TALK.has(id) || id.startsWith('tiger')) continue;
      if (S.alias[id] === undefined && EXTRAS.some((e) => S.alias[e.id] === id)) continue; // 별칭 원본은 한 번만
      const a = S.actor(id);
      if (!a || !a.pos) continue;
      if (a.char?.object3d && a.char.object3d.visible === false) continue;
      const name = a.data?.name || EXTRAS.find((e) => e.id === id)?.name || id;
      const t = { id, x: a.pos.x, z: a.pos.z, radius: 2.0, label: `${name} · 대화`, kind: 'npc', actor: a };
      list.push(t);
      npcTargets.push(t);
    }
    for (const o of OBJECTS) {
      let on = false;
      try { on = o.when(S); } catch { on = false; }
      if (!on) continue;
      const p = anchor(S, o.id === 'yard_torch' ? 'yard_torch' : o.id);
      list.push({ id: o.id, x: p.x, z: p.z, radius: o.radius || 1.8, label: o.labelFn ? o.labelFn(S) : o.label, kind: o.id === 'house_door' || o.id === 'village_gate' || o.id === 'cake_bait' || o.id === 'yard_torch' ? 'object' : 'clue' });
    }
    targets = list;
  }

  async function interact(id) {
    if (S.busy) return;
    await S.run(async () => {
      if (OBJECTS.some((o) => o.id === id)) await examineObject(S, id, scenes);
      else await talk(S, id, scenes);
    });
    dirty = true;
  }

  // ---- 저장 ----
  function save() {
    const data = JSON.parse(JSON.stringify(S.state));
    try { globalThis.localStorage?.setItem(SAVE_KEY, JSON.stringify(data)); } catch { /* 저장 불가 */ }
    return data;
  }
  function clearSave() { try { globalThis.localStorage?.removeItem(SAVE_KEY); } catch { /* */ } }
  function applyWorld() {
    for (const [k, v] of Object.entries(S.state.world)) safe(() => ctx.setWorldState?.(k, v));
    const ph = S.state.phase;
    S.setTime(ph === 'night' ? 22 : (ph === 'morning' || ph === 'done') ? 8 : (S.state.time || 10));
    placeKids();
    if (S.state.outcome) ensureMerchant();
    S.syncItems();
    dirty = true;
  }
  function load(data) {
    let d = data;
    if (!d) { try { d = JSON.parse(globalThis.localStorage?.getItem(SAVE_KEY) || 'null'); } catch { d = null; } }
    if (!d || d.v !== 1 || !d.flags) return false;
    // 절정 도중 저장은 밤 준비 상태로 되돌린다
    const st = { ...newState(), ...d };
    if (st.flags.climax_started && !st.outcome) st.flags.climax_started = false;
    S.state = st;
    started = true;
    applyWorld();
    return true;
  }
  S.onChange = () => { dirty = true; if (!S.busy && S.state.phase !== 'start') save(); };

  function restart() {
    S.gen++;
    S.busyCount = 0;
    S.movers.length = 0;
    safe(() => { if (ctx.combat?.active || ctx.combat?.tiger) ctx.combat.reset?.(); });
    for (const k of Object.keys(S.state.world)) safe(() => ctx.setWorldState?.(k, false));
    for (const id of Object.keys(S.spawned)) S.despawn(id);
    for (const id in home) {
      const a = npcs[id];
      if (!a) continue;
      S.place(id, home[id]);
      a.scripted = false;
      if (a.char?.object3d) a.char.object3d.visible = id !== 'tiger' ? true : false;
      if (home[id].facing) S.face(id, home[id].facing);
      S.anim(id, 'idle');
    }
    S.state = newState();
    S.timeTarget = null;
    S.cameraOverride(null);
    S.cameraFocus(null);
    S.letterbox(false);
    S.syncItems();
    clearSave();
    ensureExtras();
    started = false;
    dirty = true;
    S.log('restart', S.gen);
  }

  // ---- 프레임 ----
  let started = false;
  function dist(a, p) { return Math.hypot(a.x - p.x, a.z - p.z); }
  function hideTiger() {
    const t = npcs.tiger;
    if (t?.char?.object3d) t.char.object3d.visible = false;
  }

  function update(dt) {
    S.update(dt);
    hideTiger();
    rebuildT += dt;
    if (rebuildT > 0.5) dirty = true;
    if (!started) {
      started = true;
      ensureExtras();
      safe(() => ctx.fx?.setOption?.('timeFlow', false));
      if (S.state.phase === 'start' && ctx.autoLoad !== false && load()) {
        S.toast('지난 이야기를 이어서 한다', 'journal');
        return;
      }
      if (S.state.phase === 'start') {
        S.state.phase = 'explore';
        S.setTime(10);
        S.run(() => scenes.intro());
      }
      return;
    }
    if (S.busy || ctx.ui?.isModal || ctx.combat?.active) return;
    const p = ctx.player?.pos;
    if (!p) return;
    const ph = S.state.phase;
    if (ph === 'explore' && S.is('case_started') && !S.is('first_encounter')) {
      const ter = arena(S, 'territory');
      const seen = anchor(S, 'tiger_first_seen');
      const inTerritory = ter && dist(p, ter) < ter.radius - 1;
      if (inTerritory || (dist(p, seen) < 6 && (pathClueCount(S) >= 3 || S.hasClue('basket')))) {
        S.run(() => scenes.firstEncounter()).then(() => { dirty = true; });
        return;
      }
    }
    if (ph === 'night' && !S.is('night_arrived') && dist(p, anchor(S, 'house_door')) < 13) {
      S.run(() => scenes.nightArrive());
    }
  }

  const story = {
    get busy() { return S.busy; },
    hideIdleTiger: true,
    lastEnding: null,
    update,
    interactTargets() {
      if (dirty) rebuild();
      for (const t of npcTargets) { t.x = t.actor.pos.x; t.z = t.actor.pos.z; }
      return S.busy ? [] : targets;
    },
    interact,
    allowArena() { return false; },
    journal() { return buildJournal(S); },
    save,
    load,
    restart,
    // 디버그·QA
    get state() { return S.state; },
    get engine() { return S; },
    scenes,
  };
  return story;
}
