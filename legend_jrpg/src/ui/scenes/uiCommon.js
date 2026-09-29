// UI 씬 공용 도우미 (ui-dev 소유)
import { MessageWindow, drawText, FONT, COLORS } from '../window.js';
import { ITEMS } from '../../data/items.js';
import { CHARACTERS } from '../../data/characters.js';
import * as SkillsMod from '../../data/skills.js';
import * as MapsMod from '../../data/maps.js';

export const SLOTS = ['weapon', 'armor', 'accessory'];
export const SLOT_NAMES = { weapon: '무기', armor: '방어구', accessory: '장신구' };
export const STAT_LABELS = { maxHp: '최대HP', maxMp: '최대MP', atk: '공격력', def: '방어력', mag: '마력', spd: '민첩' };
export const STAT_SHORT = { maxHp: 'HP', maxMp: 'MP', atk: '공', def: '방', mag: '마', spd: '민' };
export const UP = '#7dffa0';
export const DOWN = '#ff7b7b';
const TYPE_ORDER = { consumable: 0, weapon: 1, armor: 2, accessory: 3, key: 4 };

export function skillsTable() { return (SkillsMod && SkillsMod.SKILLS) || {}; }
export function mapsTable() { return (MapsMod && MapsMod.MAPS) || {}; }

export function item(id) { return (id && ITEMS[id]) || null; }
export function itemName(id) { return item(id)?.name || String(id ?? ''); }
export function skill(id) { return skillsTable()[id] || null; }
export function skillName(id) { return skill(id)?.name || String(id); }
export function charName(id) { return CHARACTERS[id]?.name || String(id); }
export function mapName(state) {
  const id = state?.map?.id;
  if (!id) return '';
  return mapsTable()[id]?.name || id;
}

// 이름의 받침에 맞는 조사: josa('회복약','을','를') → '회복약을'
export function josa(word, a, b) {
  const s = String(word);
  const c = s.charCodeAt(s.length - 1);
  if (c >= 0xac00 && c <= 0xd7a3) return s + (((c - 0xac00) % 28) ? a : b);
  return s + a + '(' + b + ')';
}

// 인벤토리 정렬: 종류 → 데이터 정의 순서
export function sortedInventory(state) {
  const keys = Object.keys(ITEMS);
  return Object.keys(state.inventory || {})
    .filter((id) => (state.inventory[id] || 0) > 0)
    .sort((a, b) => {
      const ta = TYPE_ORDER[item(a)?.type] ?? 9;
      const tb = TYPE_ORDER[item(b)?.type] ?? 9;
      if (ta !== tb) return ta - tb;
      const ia = keys.indexOf(a), ib = keys.indexOf(b);
      return (ia < 0 ? 999 : ia) - (ib < 0 ? 999 : ib);
    });
}

// 장비를 바꿨을 때의 능력치 (상태를 바꾸지 않음)
export function previewStats(state, memberId, slot, itemId) {
  const m = state.members[memberId];
  const prev = m.equip[slot];
  m.equip[slot] = itemId;
  let st;
  try { st = state.getStats(memberId); } finally { m.equip[slot] = prev; }
  return st;
}

// 렌의 성검(가격 0 무기)은 해제/교체 불가
export function isLockedWeapon(state, memberId) {
  if (memberId !== 'ren') return false;
  const it = item(state.members[memberId]?.equip?.weapon);
  return !!it && it.type === 'weapon' && (it.price || 0) === 0;
}

// 주어진 폭에 맞게 글자 크기를 줄여서 그린다
export function drawFitText(ctx, text, x, y, maxW, opts = {}) {
  let size = opts.size || 18;
  ctx.save();
  ctx.font = FONT(size, opts.bold);
  while (size > 10 && ctx.measureText(String(text)).width > maxW) {
    size -= 1;
    ctx.font = FONT(size, opts.bold);
  }
  ctx.restore();
  drawText(ctx, text, x, y, { ...opts, size });
}

export function statusTags(m) {
  const tags = [];
  if (!m) return tags;
  if (m.hp <= 0) tags.push({ text: '전투불능', color: DOWN });
  if ((m.status || []).includes('poison')) tags.push({ text: '독', color: '#c77dff' });
  return tags;
}

// 초상화 대용: 캐릭터 색 사각형 + 이름 첫 글자
export function drawPortrait(ctx, id, x, y, size = 56, dead = false) {
  const c = CHARACTERS[id]?.color || '#888';
  ctx.save();
  const g = ctx.createLinearGradient(x, y, x, y + size);
  g.addColorStop(0, dead ? '#555' : c);
  g.addColorStop(1, dead ? '#222' : shade(c, -0.55));
  ctx.fillStyle = g;
  ctx.fillRect(x, y, size, size);
  ctx.strokeStyle = 'rgba(255,255,255,0.7)';
  ctx.lineWidth = 2;
  ctx.strokeRect(x + 1, y + 1, size - 2, size - 2);
  ctx.restore();
  drawText(ctx, charName(id).slice(0, 1), x + size / 2, y + size / 2 - size * 0.27, {
    size: Math.round(size * 0.5), bold: true, align: 'center', color: dead ? '#aaa' : '#fff',
  });
}

export function shade(hex, k) {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex);
  if (!m) return hex;
  const n = parseInt(m[1], 16);
  const f = (v) => Math.max(0, Math.min(255, Math.round(k < 0 ? v * (1 + k) : v + (255 - v) * k)));
  const r = f(n >> 16), g = f((n >> 8) & 255), b = f(n & 255);
  return `rgb(${r},${g},${b})`;
}

export function formatDate(ms) {
  if (!ms) return '';
  const d = new Date(ms);
  const p = (v) => String(v).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

// ---------------------------------------------------------------
// 비동기 UI 흐름: 씬의 update에서 flow.update(dt, input)를 호출한다.
//   await flow.choose(list)       → 인덱스 | -1
//   await flow.wait(step)         → step(input, dt)이 undefined가 아닌 값을 돌려줄 때까지
//   await flow.say(text, speaker) → 메시지
// ---------------------------------------------------------------
export class Flow {
  constructor(msgOpts) {
    this.msg = new MessageWindow(msgOpts);
    this.pending = null;
  }
  wait(step) {
    return new Promise((res) => { this.pending = { step, res }; });
  }
  choose(list, onMove) {
    let last = list.index;
    if (onMove) onMove(list.index);
    return this.wait((input, dt) => {
      const r = list.update(input, dt);
      if (list.index !== last) { last = list.index; if (onMove) onMove(last); }
      return r === null ? undefined : r;
    });
  }
  say(text, speaker) { return this.msg.show(text, speaker); }
  get busy() { return this.msg.active; }
  update(dt, input) {
    if (this.msg.active) { this.msg.update(dt, input); return; }
    const p = this.pending;
    if (!p) return;
    const r = p.step(input, dt);
    if (r !== undefined) { this.pending = null; p.res(r); }
  }
  isWaiting(step) { return !this.msg.active && this.pending && (!step || this.pending.step === step); }
}

// ---------------------------------------------------------------
// 밤하늘 연출 도우미 (타이틀/엔딩)
// ---------------------------------------------------------------
export function makeStars(n, seed = 7, maxY = 330) {
  let s = seed;
  const rnd = () => { s = (s * 16807) % 2147483647; return (s - 1) / 2147483646; };
  const stars = [];
  for (let i = 0; i < n; i++) {
    stars.push({ x: rnd() * 640, y: rnd() * maxY, r: rnd() < 0.12 ? 1.6 : rnd() < 0.5 ? 1 : 0.6, p: rnd() * 6.28, sp: 1 + rnd() * 2.5 });
  }
  return stars;
}

export function drawStars(ctx, stars, t, alpha = 1) {
  ctx.save();
  for (const st of stars) {
    const a = alpha * (0.45 + 0.55 * (0.5 + 0.5 * Math.sin(t * st.sp + st.p)));
    ctx.globalAlpha = a;
    ctx.fillStyle = st.r > 1.2 ? '#fff6d8' : '#dfe6ff';
    ctx.fillRect(st.x, st.y, st.r * 1.6, st.r * 1.6);
    if (st.r > 1.2 && a > 0.8) {
      ctx.globalAlpha = a * 0.4;
      ctx.fillRect(st.x - 2, st.y + 0.8, 5.6, 0.8);
      ctx.fillRect(st.x + 0.8, st.y - 2, 0.8, 5.6);
    }
  }
  ctx.restore();
}

export function drawRedMoon(ctx, x, y, r, t, alpha = 1) {
  if (alpha <= 0) return;
  ctx.save();
  ctx.globalAlpha = alpha;
  const glow = ctx.createRadialGradient(x, y, r * 0.8, x, y, r * 3);
  glow.addColorStop(0, `rgba(255,70,60,${0.35 + 0.05 * Math.sin(t * 1.3)})`);
  glow.addColorStop(1, 'rgba(255,40,40,0)');
  ctx.fillStyle = glow;
  ctx.fillRect(x - r * 3, y - r * 3, r * 6, r * 6);
  const body = ctx.createRadialGradient(x - r * 0.35, y - r * 0.35, r * 0.1, x, y, r);
  body.addColorStop(0, '#ff8a70');
  body.addColorStop(0.6, '#d0302a');
  body.addColorStop(1, '#6e0c14');
  ctx.fillStyle = body;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = 'rgba(90,10,20,0.35)';
  for (const [dx, dy, cr] of [[-0.3, -0.1, 0.18], [0.25, 0.3, 0.12], [0.35, -0.35, 0.09], [-0.1, 0.45, 0.08]]) {
    ctx.beginPath();
    ctx.arc(x + dx * r, y + dy * r, cr * r, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

// 겹겹의 산 실루엣
export function drawMountains(ctx, baseY, color, seed, amp = 60, step = 40) {
  let s = seed;
  const rnd = () => { s = (s * 16807) % 2147483647; return (s - 1) / 2147483646; };
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(0, 480);
  ctx.lineTo(0, baseY - rnd() * amp);
  for (let x = step; x <= 640 + step; x += step) ctx.lineTo(x, baseY - rnd() * amp);
  ctx.lineTo(640, 480);
  ctx.closePath();
  ctx.fill();
}

export { COLORS };
