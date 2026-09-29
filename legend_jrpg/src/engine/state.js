// 게임 진행 상태 + 세이브/로드
import { CHARACTERS } from '../data/characters.js';
import { ITEMS } from '../data/items.js';

export const MAX_LEVEL = 30;
export const SAVE_SLOTS = 3;
const SAVE_KEY = 'legend_jrpg_save_';
const STAT_KEYS = ['maxHp', 'maxMp', 'atk', 'def', 'mag', 'spd'];

export function expForLevel(level) {
  const n = level - 1;
  return 10 * n * n + 10 * n;
}

export class GameState {
  constructor() {
    this.party = [];
    this.members = {};
    this.inventory = {};
    this.gold = 0;
    this.flags = {};
    this.map = { id: 'village', x: 10, y: 10, dir: 'down' };
    this.playTime = 0;
    this.steps = 0;
  }

  static newGame() {
    const s = new GameState();
    s.addMember('ren', 1);
    s.gold = 50;
    s.addItem('herb', 3);
    return s;
  }

  // ---- 파티 ----
  addMember(id, level = 1) {
    const def = CHARACTERS[id];
    if (!def) throw new Error(`알 수 없는 캐릭터: ${id}`);
    if (this.party.includes(id)) return this.members[id];
    const lv = Math.max(1, Math.min(MAX_LEVEL, level));
    const m = {
      id,
      level: lv,
      exp: expForLevel(lv),
      hp: 1,
      mp: 0,
      equip: { weapon: null, armor: null, accessory: null, ...def.startEquip },
      status: [],
    };
    this.members[id] = m;
    this.party.push(id);
    const st = this.getStats(id);
    m.hp = st.maxHp;
    m.mp = st.maxMp;
    return m;
  }

  hasMember(id) { return this.party.includes(id); }
  member(id) { return this.members[id]; }
  partyMembers() { return this.party.map((id) => this.members[id]); }
  aliveMembers() { return this.partyMembers().filter((m) => m.hp > 0); }
  isAlive(id) { return (this.members[id]?.hp || 0) > 0; }

  baseStats(id) {
    const def = CHARACTERS[id];
    const lv = this.members[id].level;
    const f = (k) => Math.floor(def.base[k] + def.growth[k] * (lv - 1));
    return { maxHp: f('hp'), maxMp: f('mp'), atk: f('atk'), def: f('def'), mag: f('mag'), spd: f('spd') };
  }

  getStats(id) {
    const st = this.baseStats(id);
    const eq = this.members[id].equip;
    for (const slot of ['weapon', 'armor', 'accessory']) {
      const item = eq[slot] && ITEMS[eq[slot]];
      if (!item || !item.bonus) continue;
      for (const k of STAT_KEYS) st[k] += item.bonus[k] || 0;
    }
    for (const k of STAT_KEYS) st[k] = Math.max(k === 'maxMp' ? 0 : 1, st[k]);
    return st;
  }

  // HP/MP가 최대치를 넘지 않게 정리 (장비 변경 후 등)
  clamp(id) {
    const m = this.members[id];
    const st = this.getStats(id);
    m.hp = Math.min(m.hp, st.maxHp);
    m.mp = Math.min(m.mp, st.maxMp);
  }

  knownSkills(id) {
    const lv = this.members[id].level;
    return CHARACTERS[id].learnset.filter((l) => l.level <= lv).map((l) => l.skill);
  }

  expForLevel(level) { return expForLevel(level); }
  expToNext(id) {
    const m = this.members[id];
    if (m.level >= MAX_LEVEL) return 0;
    return expForLevel(m.level + 1) - m.exp;
  }

  // 레벨업 시 늘어난 최대치만큼 HP/MP도 함께 증가
  gainExp(id, amount) {
    const m = this.members[id];
    const ups = [];
    m.exp += Math.max(0, Math.floor(amount));
    while (m.level < MAX_LEVEL && m.exp >= expForLevel(m.level + 1)) {
      const before = this.getStats(id);
      const known = new Set(this.knownSkills(id));
      m.level += 1;
      const after = this.getStats(id);
      if (m.hp > 0) {
        m.hp += after.maxHp - before.maxHp;
        m.mp += after.maxMp - before.maxMp;
      }
      ups.push({ level: m.level, skills: this.knownSkills(id).filter((s) => !known.has(s)) });
    }
    return ups;
  }

  fullHeal() {
    for (const id of this.party) {
      const st = this.getStats(id);
      const m = this.members[id];
      m.hp = st.maxHp;
      m.mp = st.maxMp;
      m.status = [];
    }
  }

  // ---- 인벤토리 ----
  addItem(id, n = 1) {
    this.inventory[id] = (this.inventory[id] || 0) + n;
    if (this.inventory[id] > 99) this.inventory[id] = 99;
  }
  removeItem(id, n = 1) {
    if ((this.inventory[id] || 0) < n) return false;
    this.inventory[id] -= n;
    if (this.inventory[id] <= 0) delete this.inventory[id];
    return true;
  }
  itemCount(id) { return this.inventory[id] || 0; }

  // ---- 장비 ----
  slotOf(itemId) {
    const t = ITEMS[itemId]?.type;
    return t === 'weapon' || t === 'armor' || t === 'accessory' ? t : null;
  }
  canEquip(memberId, itemId) {
    const item = ITEMS[itemId];
    if (!item || !this.slotOf(itemId)) return false;
    return !item.equipBy || item.equipBy.includes(memberId);
  }
  // 가방에서 꺼내 장착, 이전 장비는 가방으로
  equip(memberId, itemId) {
    if (!this.canEquip(memberId, itemId) || !this.removeItem(itemId, 1)) return false;
    const slot = this.slotOf(itemId);
    const m = this.members[memberId];
    if (m.equip[slot]) this.addItem(m.equip[slot], 1);
    m.equip[slot] = itemId;
    this.clamp(memberId);
    return true;
  }
  unequip(memberId, slot) {
    const m = this.members[memberId];
    if (!m.equip[slot]) return false;
    this.addItem(m.equip[slot], 1);
    m.equip[slot] = null;
    this.clamp(memberId);
    return true;
  }
  // 이벤트 전용: 인벤토리와 무관하게 강제 장착 (기존 장비는 사라짐)
  forceEquip(memberId, itemId) {
    const slot = this.slotOf(itemId);
    if (!slot || !this.members[memberId]) return false;
    this.members[memberId].equip[slot] = itemId;
    this.clamp(memberId);
    return true;
  }

  // ---- 플래그 ----
  setFlag(k, v = true) { this.flags[k] = v; }
  getFlag(k) { return this.flags[k]; }

  // ---- 직렬화 ----
  serialize() {
    return JSON.parse(JSON.stringify({
      v: 1,
      party: this.party,
      members: this.members,
      inventory: this.inventory,
      gold: this.gold,
      flags: this.flags,
      map: this.map,
      playTime: this.playTime,
      steps: this.steps,
    }));
  }

  static deserialize(o) {
    const s = new GameState();
    s.party = o.party || [];
    s.members = o.members || {};
    s.inventory = o.inventory || {};
    s.gold = o.gold || 0;
    s.flags = o.flags || {};
    s.map = o.map || s.map;
    s.playTime = o.playTime || 0;
    s.steps = o.steps || 0;
    return s;
  }

  summary(mapName) {
    const leader = this.members[this.party[0]];
    return {
      level: leader ? leader.level : 1,
      party: [...this.party],
      mapId: this.map.id,
      mapName: mapName || this.map.id,
      playTime: Math.floor(this.playTime),
      gold: this.gold,
    };
  }
}

// ---- 세이브 슬롯 (localStorage) ----
export function saveSlot(n, state, mapName) {
  try {
    const data = { savedAt: Date.now(), summary: state.summary(mapName), state: state.serialize() };
    localStorage.setItem(SAVE_KEY + n, JSON.stringify(data));
    return true;
  } catch (e) {
    console.warn('세이브 실패', e);
    return false;
  }
}

export function loadSlot(n) {
  try {
    const raw = localStorage.getItem(SAVE_KEY + n);
    if (!raw) return null;
    return GameState.deserialize(JSON.parse(raw).state);
  } catch (e) {
    console.warn('로드 실패', e);
    return null;
  }
}

export function listSlots() {
  const out = [];
  for (let n = 1; n <= SAVE_SLOTS; n++) {
    let summary = null;
    try {
      const raw = localStorage.getItem(SAVE_KEY + n);
      if (raw) { const d = JSON.parse(raw); summary = { ...d.summary, savedAt: d.savedAt }; }
    } catch (e) { summary = null; }
    out.push({ slot: n, summary });
  }
  return out;
}

export function hasAnySave() {
  return listSlots().some((s) => s.summary);
}

export function formatPlayTime(sec) {
  const s = Math.floor(sec || 0);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  return `${h}:${String(m).padStart(2, '0')}`;
}
