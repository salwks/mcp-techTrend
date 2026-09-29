// 필드(메뉴)에서의 아이템 사용·마법 시전 (battle-dev). docs/CONTRACTS.md §7.
// 모든 함수는 { ok:boolean, message:string } 을 돌려준다. ok:false 면 아이템/MP를 소모하지 않는다.
import { ITEMS } from '../data/items.js';
import { SKILLS } from '../data/skills.js';
import { CHARACTERS } from '../data/characters.js';
import { healAmount, josa } from '../battle/formulas.js';

const nameOf = (id) => CHARACTERS[id]?.name || id;

export function canUseItemInField(itemId) {
  const it = ITEMS[itemId];
  return !!it && it.type === 'consumable' && (it.usable === 'both' || it.usable === 'field');
}

export function canCastInField(skillId) {
  const sk = SKILLS[skillId];
  return !!sk && sk.field === true;
}

function statusLabel(s) {
  return s === 'poison' ? '독' : s === 'sleep' ? '수면' : s === 'stun' ? '기절' : s;
}

// 효과 하나를 대상 1명에게 적용 → { changed, text }
function applyTo(state, id, eff) {
  const m = state.members[id];
  if (!m) return { changed: false, text: '' };
  const st = state.getStats(id);
  const name = nameOf(id);
  const alive = m.hp > 0;
  switch (eff.kind) {
    case 'heal': {
      if (!alive) return { changed: false, text: `${josa(name, '은')} 쓰러져 있어서 회복할 수 없다.` };
      const parts = [];
      let changed = false;
      const amt = Math.min(st.maxHp - m.hp, eff.amount);
      if (amt > 0) { m.hp += amt; parts.push(`HP가 ${amt}`); changed = true; }
      if (eff.mp) {
        const mp = Math.min(st.maxMp - m.mp, eff.mp);
        if (mp > 0) { m.mp += mp; parts.push(`MP가 ${mp}`); changed = true; }
      }
      if (eff.cure && m.status && m.status.length) { m.status = []; changed = true; parts.push('상태이상이'); }
      if (!changed) return { changed: false, text: `${josa(name, '은')} 이미 건강하다.` };
      return { changed: true, text: `${josa(name, '의')} ${parts.join(', ')} 회복되었다!` };
    }
    case 'mp': {
      if (!alive) return { changed: false, text: `${josa(name, '은')} 쓰러져 있다.` };
      const mp = Math.min(st.maxMp - m.mp, eff.amount);
      if (mp <= 0) return { changed: false, text: `${josa(name, '의')} MP는 이미 가득하다.` };
      m.mp += mp;
      return { changed: true, text: `${josa(name, '의')} MP가 ${mp} 회복되었다!` };
    }
    case 'cure': {
      if (!alive) return { changed: false, text: `${josa(name, '은')} 쓰러져 있다.` };
      const cur = m.status || [];
      const removed = eff.status === 'all' || !eff.status ? cur : cur.filter((s) => s === eff.status);
      if (!removed.length) return { changed: false, text: `${josa(name, '은')} 상태이상에 걸려 있지 않다.` };
      m.status = cur.filter((s) => !removed.includes(s));
      return { changed: true, text: `${josa(name, '의')} ${removed.map(statusLabel).join('·')} 상태가 나았다!` };
    }
    case 'revive': {
      if (alive) return { changed: false, text: `${josa(name, '은')} 쓰러져 있지 않다.` };
      const ratio = eff.amount <= 1 ? eff.amount : eff.amount / st.maxHp;
      m.hp = Math.max(1, Math.round(st.maxHp * ratio));
      m.status = [];
      return { changed: true, text: `${josa(name, '이')} 되살아났다!` };
    }
    default:
      return { changed: false, text: '지금은 사용할 수 없다.' };
  }
}

function applyAll(state, ids, eff) {
  const results = ids.map((id) => applyTo(state, id, eff));
  const ok = results.filter((r) => r.changed);
  if (!ok.length) return { ok: false, message: ids.length > 1 ? '아무도 효과를 받지 못했다.' : results[0].text };
  return { ok: true, message: ok.map((r) => r.text).join('\n') };
}

export function useItemInField(state, itemId, targetId) {
  const it = ITEMS[itemId];
  if (!it) return { ok: false, message: '알 수 없는 아이템이다.' };
  if (!canUseItemInField(itemId)) return { ok: false, message: `${josa(it.name, '은')} 여기서는 사용할 수 없다.` };
  if (state.itemCount(itemId) <= 0) return { ok: false, message: `${josa(it.name, '을')} 가지고 있지 않다.` };
  const eff = it.effect || {};
  const all = it.target === 'allAllies' || eff.kind === 'healAll';
  if (!all && (!targetId || !state.members[targetId])) return { ok: false, message: '대상을 선택해 주세요.' };
  const e = eff.kind === 'healAll' ? { ...eff, kind: 'heal' } : eff;
  const r = applyAll(state, all ? [...state.party] : [targetId], e);
  if (r.ok) state.removeItem(itemId, 1);
  return r;
}

export function castSkillInField(state, casterId, skillId, targetId) {
  const sk = SKILLS[skillId];
  const caster = state.members[casterId];
  if (!sk || !caster) return { ok: false, message: '사용할 수 없다.' };
  const cname = nameOf(casterId);
  if (!canCastInField(skillId)) return { ok: false, message: `${josa(sk.name, '은')} 전투 중에만 쓸 수 있다.` };
  if (caster.hp <= 0) return { ok: false, message: `${josa(cname, '은')} 쓰러져 있다.` };
  if (!state.knownSkills(casterId).includes(skillId)) return { ok: false, message: `${josa(cname, '은')} 그 마법을 모른다.` };
  if (caster.mp < sk.mp) return { ok: false, message: 'MP가 부족하다.' };
  const all = sk.target === 'allAllies';
  if (!all && (!targetId || !state.members[targetId])) return { ok: false, message: '대상을 선택해 주세요.' };
  const mag = state.getStats(casterId).mag;
  let eff;
  if (sk.kind === 'heal') eff = { kind: 'heal', amount: healAmount(sk.power, mag, sk.magRate), cure: !!sk.cure };
  else if (sk.kind === 'revive') eff = { kind: 'revive', amount: sk.power || 0.5 };
  else if (sk.kind === 'cure') eff = { kind: 'cure', status: sk.status || 'all' };
  else return { ok: false, message: '지금은 사용할 수 없다.' };
  const r = applyAll(state, all ? [...state.party] : [targetId], eff);
  if (r.ok) {
    caster.mp -= sk.mp;
    r.message = `${josa(cname, '은')} ${josa(sk.name, '을')} 외웠다!\n${r.message}`;
  }
  return r;
}
