// 전투 로직 코어 (DOM 비의존). BattleScene이 연출을 붙이고, 헤드리스 시뮬레이션도 이 코어를 그대로 쓴다.
// execute()/endRound()는 이벤트 배열을 돌려준다:
//   {t:'action', actor, text, anim?, element?, targets?, sfx?}  행동 선언(윗줄)
//   {t:'msg', text, sfx?}                                       결과 메시지(아랫줄)
//   {t:'dmg', target, amount, crit, text, weak?, resist?}      피해
//   {t:'heal', target, amount, mp?, text}                       회복
//   {t:'miss', target, text}  {t:'die', target, text}  {t:'revive', target, text}
//   {t:'phase', target, text}                                   보스 형태 변화
import { ITEMS } from '../data/items.js';
import { SKILLS, getSkill } from '../data/skills.js';
import { ENEMIES } from '../data/enemies.js';
import { TROOPS } from '../data/troops.js';
import { CHARACTERS } from '../data/characters.js';
import {
  physicalDamage, magicDamage, healAmount, elementMult, escapeChance, initiative,
  chance, pick, rand, josa, fmt, ELEMENT_NAMES,
} from './formulas.js';

const SUFFIX = 'ABCDEFGH';

export class Battler {
  constructor(o) {
    Object.assign(this, o);
    this.status = { poison: false, sleep: 0, stun: 0 };
    this.buffs = {};
    this.defending = false;
    this.taunt = 0;
    this.charged = false;
    this.phaseDone = [];
    this.permAtk = 1;
    this.permDef = 1;
  }
  get hp() { return this.member ? this.member.hp : this._hp; }
  set hp(v) {
    const n = Math.max(0, Math.min(this.maxHp, Math.round(v)));
    if (this.member) this.member.hp = n; else this._hp = n;
  }
  get mp() { return this.member ? this.member.mp : this._mp; }
  set mp(v) {
    const n = Math.max(0, Math.min(this.maxMp, Math.round(v)));
    if (this.member) this.member.mp = n; else this._mp = n;
  }
  get alive() { return this.hp > 0; }
  buffMult(stat) { const b = this.buffs[stat]; return b ? b.mult : 1; }
  get atk() { return this.baseAtk * this.buffMult('atk') * this.permAtk; }
  get def() { return this.baseDef * this.buffMult('def') * this.permDef; }
  get mag() { return this.baseMag * this.permAtk; }
  get spd() { return this.baseSpd; }
  get isParty() { return this.side === 'party'; }
  get incapacitated() { return this.status.sleep > 0 || this.status.stun > 0; }
}

export class BattleCore {
  constructor(state, troop, opts = {}) {
    this.state = state;
    this.troop = typeof troop === 'string' ? TROOPS[troop] : troop;
    if (!this.troop) throw new Error(`알 수 없는 troop: ${troop}`);
    this.troopId = typeof troop === 'string' ? troop : null;
    this.canEscape = opts.canEscape !== false && !this.troop.boss;
    this.escapeTries = 0;
    this.turn = 0;
    this.party = state.party.map((id, i) => this._makeMember(id, i));
    this.enemies = this._makeEnemies(this.troop.enemies);
  }

  _makeMember(id, idx) {
    const m = this.state.members[id];
    const st = this.state.getStats(id);
    const acc = m.equip.accessory && ITEMS[m.equip.accessory];
    const b = new Battler({
      side: 'party', id, idx, name: CHARACTERS[id].name, member: m,
      maxHp: st.maxHp, maxMp: st.maxMp, baseAtk: st.atk, baseDef: st.def, baseMag: st.mag, baseSpd: st.spd,
      guard: (acc && acc.guard) || [], weak: [], resist: [],
    });
    if (m.hp > st.maxHp) m.hp = st.maxHp;
    if (m.mp > st.maxMp) m.mp = st.maxMp;
    if (m.hp > 0 && (m.status || []).includes('poison')) b.status.poison = true;
    return b;
  }

  _makeEnemies(keys) {
    const counts = {};
    keys.forEach((k) => { counts[k] = (counts[k] || 0) + 1; });
    const seen = {};
    return keys.map((k, i) => {
      const d = ENEMIES[k];
      if (!d) throw new Error(`알 수 없는 적: ${k}`);
      seen[k] = (seen[k] || 0) + 1;
      const name = counts[k] > 1 ? d.name + SUFFIX[seen[k] - 1] : d.name;
      const b = new Battler({
        side: 'enemy', key: k, idx: i, name, baseName: d.name, data: d,
        maxHp: d.hp, maxMp: d.mp || 0, baseAtk: d.atk, baseDef: d.def, baseMag: d.mag || 0, baseSpd: d.spd,
        weak: d.weak || [], resist: d.resist || [], guard: d.immune || [],
        skills: d.skills || [], actions: d.actions || 1, boss: !!d.boss,
      });
      b.hp = d.hp;
      b.mp = d.mp || 0;
      return b;
    });
  }

  // ---------- 조회 ----------
  aliveParty() { return this.party.filter((b) => b.alive); }
  aliveEnemies() { return this.enemies.filter((b) => b.alive); }
  opponents(b) { return b.isParty ? this.aliveEnemies() : this.aliveParty(); }
  friends(b) { return b.isParty ? this.aliveParty() : this.aliveEnemies(); }
  outcome() {
    if (!this.aliveEnemies().length) return 'win';
    if (!this.aliveParty().length) return 'lose';
    return null;
  }
  canCommand(b) { return b.alive && !b.incapacitated; }

  introText() {
    const es = this.enemies;
    const boss = es.find((e) => e.boss);
    if (boss) return `${josa(boss.baseName, '이')} 나타났다!`;
    const names = [...new Set(es.map((e) => e.baseName))];
    if (names.length === 1) return es.length > 1 ? `${names[0]} ${es.length}마리가 나타났다!` : `${josa(names[0], '이')} 나타났다!`;
    return `${names.slice(0, -1).join(', ')}, ${josa(names[names.length - 1], '이')} 나타났다!`;
  }

  // ---------- 라운드 ----------
  // partyActions: [{actor, type:'attack'|'skill'|'item'|'defend'|'skip', skill?, item?, target?}]
  buildRound(partyActions) {
    this.turn += 1;
    const list = [];
    for (const a of partyActions) {
      if (!a.actor.alive) continue;
      if (a.type === 'defend') a.actor.defending = true; // 방어는 라운드 시작부터 적용
      list.push({ ...a, key: a.type === 'defend' ? 9999 : initiative(a.actor.spd) });
    }
    for (const b of this.party) {
      if (b.alive && b.incapacitated && !partyActions.some((a) => a.actor === b)) {
        list.push({ actor: b, type: 'skip', key: initiative(b.spd) });
      }
    }
    for (const e of this.aliveEnemies()) {
      for (let n = 0; n < e.actions; n++) {
        list.push({ actor: e, type: 'ai', key: initiative(e.spd) - n * (e.spd * 0.5 + 4) });
      }
    }
    list.sort((a, b) => b.key - a.key);
    return list;
  }

  execute(action) {
    const ev = [];
    const a = action.actor;
    if (!a.alive || this.outcome()) return ev;
    // 행동 불가
    if (a.status.stun > 0) {
      a.status.stun = 0;
      ev.push({ t: 'action', actor: a, text: `${josa(a.name, '은')} 기절해서 움직일 수 없다!` });
      return ev;
    }
    if (a.status.sleep > 0) {
      a.status.sleep -= 1;
      if (a.status.sleep <= 0) ev.push({ t: 'action', actor: a, text: `${josa(a.name, '은')} 눈을 떴다!` });
      else ev.push({ t: 'action', actor: a, text: `${josa(a.name, '은')} 잠들어 있다…` });
      return ev;
    }
    if (action.type === 'skip') return ev;
    let act = action;
    if (action.type === 'ai') act = this.enemyChoose(a);
    switch (act.type) {
      case 'attack': this._doAttack(a, act, ev); break;
      case 'skill': this._doSkill(a, act, ev); break;
      case 'item': this._doItem(a, act, ev); break;
      case 'defend':
        ev.push({ t: 'action', actor: a, text: `${josa(a.name, '은')} 몸을 굳게 지키고 있다.` });
        break;
      default: break;
    }
    this._checkPhases(ev);
    return ev;
  }

  endRound() {
    const ev = [];
    for (const b of [...this.party, ...this.enemies]) {
      if (!b.alive) continue;
      b.defending = false;
      if (b.status.poison && !this.outcome()) {
        const dmg = b.isParty ? Math.max(1, Math.floor(b.maxHp / 12)) : Math.min(60, Math.max(1, Math.floor(b.maxHp / 10)));
        const real = b.isParty ? Math.min(dmg, b.hp - 1) : dmg; // 파티는 독으로 쓰러지지 않는다
        if (real > 0) {
          b.hp -= real;
          ev.push({ t: 'dmg', target: b, amount: real, poison: true, text: `${josa(b.name, '은')} 독으로 ${real}의 데미지를 입었다!` });
          if (!b.alive) ev.push({ t: 'die', target: b, text: this._dieText(b) });
        }
      }
      for (const stat of Object.keys(b.buffs)) {
        const bf = b.buffs[stat];
        bf.turns -= 1;
        if (bf.turns <= 0) {
          delete b.buffs[stat];
          if (b.alive) ev.push({ t: 'msg', text: `${josa(b.name, '의')} ${stat === 'atk' ? '공격력' : '방어력'}이 원래대로 돌아왔다.` });
        }
      }
      if (b.taunt > 0) b.taunt -= 1;
    }
    this._checkPhases(ev);
    return ev;
  }

  tryEscape() {
    const avg = (arr) => arr.reduce((s, b) => s + b.spd, 0) / Math.max(1, arr.length);
    const ok = chance(escapeChance(avg(this.aliveParty()), avg(this.aliveEnemies()), this.escapeTries));
    if (!ok) this.escapeTries += 1;
    return ok;
  }

  rewards() {
    let exp = 0; let gold = 0; const drops = [];
    for (const e of this.enemies) {
      exp += e.data.exp || 0;
      gold += e.data.gold || 0;
      for (const d of e.data.drops || []) {
        if (chance(d.rate)) { drops.push(d.item); break; }
      }
    }
    return { exp, gold, drops };
  }

  // 전투 종료 시: 독만 멤버에 남기고, 쓰러진 멤버는 HP 0 유지
  finalize() {
    for (const b of this.party) {
      const m = b.member;
      m.status = (m.status || []).filter((s) => s !== 'poison' && s !== 'sleep' && s !== 'stun');
      if (b.alive && b.status.poison) m.status.push('poison');
      if (!b.alive) { m.hp = 0; m.status = []; }
    }
  }

  // ---------- 적 AI ----------
  enemyChoose(e) {
    const opts = [];
    const hpRatio = e.hp / e.maxHp;
    const allies = this.aliveEnemies();
    const foes = this.aliveParty();
    for (const s of e.skills) {
      if (s.hpBelow != null && hpRatio > s.hpBelow) continue;
      if (s.hpAbove != null && hpRatio <= s.hpAbove) continue;
      if (s.once && e.phaseDone.includes('once_' + s.id)) continue;
      if (s.id === 'attack') { opts.push({ id: 'attack', w: s.w }); continue; }
      const sk = getSkill(s.id);
      if (!sk) continue;
      if ((sk.mp || 0) > e.mp) continue;
      if (sk.kind === 'heal') {
        if (sk.target === 'self' && hpRatio > 0.6) continue;
        if (sk.target !== 'self' && !allies.some((x) => x.hp / x.maxHp < 0.5)) continue;
      }
      if (sk.kind === 'buff' && sk.buff && e.buffs[sk.buff.stat]) continue;
      if (sk.kind === 'charge' && e.charged) continue;
      if (sk.kind === 'debuff' && sk.status && foes.every((f) => this._hasStatus(f, sk.status) || f.guard.includes(sk.status))) continue;
      opts.push({ id: s.id, w: s.w, once: s.once });
    }
    if (!opts.some((o) => o.id === 'attack') && !e.data.noAttack) opts.push({ id: 'attack', w: e.data.attackW ?? 3 });
    // 힘을 모았다면 가장 강한 물리 공격
    if (e.charged) {
      let best = { id: 'attack', p: 1 };
      for (const o of opts) {
        const sk = getSkill(o.id);
        if (sk && sk.kind === 'physical' && (sk.power || 1) * (sk.hits || 1) > best.p) best = { id: o.id, p: (sk.power || 1) * (sk.hits || 1) };
      }
      return this._enemyAct(e, best.id);
    }
    const total = opts.reduce((s, o) => s + o.w, 0);
    let r = rand(0, total);
    let chosen = opts[opts.length - 1];
    for (const o of opts) { r -= o.w; if (r <= 0) { chosen = o; break; } }
    if (chosen.once) e.phaseDone.push('once_' + chosen.id);
    return this._enemyAct(e, chosen.id);
  }

  _enemyAct(e, id) {
    if (id === 'attack') return { type: 'attack', actor: e, target: this._pickFoe(e) };
    const sk = getSkill(id);
    let target = null;
    if (sk.target === 'enemy') target = this._pickFoe(e, sk.status);
    else if (sk.target === 'ally') target = this.aliveEnemies().sort((x, y) => x.hp / x.maxHp - y.hp / y.maxHp)[0];
    else if (sk.target === 'self') target = e;
    return { type: 'skill', actor: e, skill: id, target };
  }

  _pickFoe(e, status) {
    const foes = this.aliveParty();
    const taunter = foes.find((f) => f.taunt > 0);
    if (taunter && chance(0.9)) return taunter;
    let pool = foes;
    if (status) { const p = foes.filter((f) => !this._hasStatus(f, status)); if (p.length) pool = p; }
    return pick(pool);
  }

  _hasStatus(b, s) {
    if (s === 'poison') return b.status.poison;
    return b.status[s] > 0;
  }

  // ---------- 행동 처리 ----------
  _retarget(a, target, kind) {
    if (kind === 'foe') {
      if (target && target.alive && target.side !== a.side) return target;
      const pool = this.opponents(a);
      return pool.length ? pick(pool) : null;
    }
    if (kind === 'friend') {
      if (target && target.alive) return target;
      const pool = this.friends(a).sort((x, y) => x.hp / x.maxHp - y.hp / y.maxHp);
      return pool[0] || null;
    }
    return target;
  }

  _doAttack(a, act, ev) {
    const t = this._retarget(a, act.target, 'foe');
    ev.push({ t: 'action', actor: a, text: a.isParty ? `${josa(a.name, '의')} 공격!` : `${josa(a.name, '의')} 공격!`, anim: 'slash', targets: t ? [t] : [] });
    if (!t) return;
    let power = 1;
    if (a.charged) { power *= 2; a.charged = false; }
    this._physicalHit(a, t, power, null, ev);
  }

  _physicalHit(a, t, power, element, ev, sk) {
    const opts = {};
    if (!a.isParty) opts.critRate = a.boss ? 1 / 40 : 1 / 32; // 적의 통렬한 일격은 드물게
    const r = physicalDamage(a.atk, t.def, power, opts);
    if (r.miss) {
      ev.push({ t: 'miss', target: t, text: t.isParty ? `${josa(t.name, '은')} 재빨리 몸을 피했다!` : `미스! ${josa(t.name, '에게')} 데미지를 줄 수 없었다!` });
      return 0;
    }
    const mult = elementMult(t.weak, t.resist, element);
    let amount = Math.max(1, Math.round(r.amount * mult));
    if (t.defending) amount = Math.max(1, Math.round(amount / 2));
    if (r.crit) ev.push({ t: 'msg', text: a.isParty ? '회심의 일격!' : '통렬한 일격!', sfx: 'crit', crit: true });
    this._applyDamage(a, t, amount, ev, { crit: r.crit, weak: mult > 1, resist: mult < 1, physical: true });
    if (sk && sk.status && t.alive) this._inflict(t, sk.status, sk.chance ?? 1, ev, false);
    return amount;
  }

  _applyDamage(a, t, amount, ev, info = {}) {
    t.hp -= amount;
    let text;
    if (t.isParty) text = `${josa(t.name, '은')} ${amount}의 데미지를 입었다!`;
    else text = `${josa(t.name, '에게')} ${amount}의 데미지!`;
    if (info.weak) text = `효과가 굉장하다! ${text}`;
    else if (info.resist) text = `효과가 별로다… ${text}`;
    ev.push({ t: 'dmg', target: t, amount, crit: !!info.crit, weak: !!info.weak, resist: !!info.resist, text, bossHit: a.boss && t.isParty });
    if (t.status.sleep > 0 && t.alive && info.physical) {
      t.status.sleep = 0;
      ev.push({ t: 'msg', text: `${josa(t.name, '은')} 눈을 떴다!` });
    }
    if (!t.alive) this._kill(t, ev);
  }

  _kill(t, ev) {
    t.status = { poison: false, sleep: 0, stun: 0 };
    t.buffs = {};
    t.taunt = 0;
    t.charged = false;
    ev.push({ t: 'die', target: t, text: this._dieText(t) });
  }

  _dieText(t) {
    return t.isParty ? `${josa(t.name, '은')} 쓰러졌다!` : `${josa(t.name, '을')} 쓰러뜨렸다!`;
  }

  _inflict(t, status, p, ev, loud) {
    if (!t.alive) return false;
    if (t.guard.includes(status)) {
      if (loud) ev.push({ t: 'msg', text: `그러나 ${josa(t.name, '에게')}는 통하지 않았다!` });
      return false;
    }
    if (this._hasStatus(t, status)) { if (loud) ev.push({ t: 'msg', text: `${josa(t.name, '은')} 이미 ${status === 'poison' ? '독에 걸려' : status === 'sleep' ? '잠들어' : '기절해'} 있다.` }); return false; }
    if (!chance(p)) { if (loud) ev.push({ t: 'msg', text: `${josa(t.name, '은')} 아무렇지도 않았다.` }); return false; }
    if (status === 'poison') { t.status.poison = true; ev.push({ t: 'msg', text: `${josa(t.name, '은')} 독에 걸렸다!`, status: 'poison', target: t }); }
    if (status === 'sleep') { t.status.sleep = 2 + (chance(0.5) ? 1 : 0); ev.push({ t: 'msg', text: `${josa(t.name, '은')} 잠들어 버렸다!`, status: 'sleep', target: t }); }
    if (status === 'stun') { t.status.stun = 1; ev.push({ t: 'msg', text: `${josa(t.name, '은')} 기절했다!`, status: 'stun', target: t }); }
    return true;
  }

  _skillTargets(a, sk, target) {
    switch (sk.target) {
      case 'enemy': { const t = this._retarget(a, target, 'foe'); return t ? [t] : []; }
      case 'allEnemies': return this.opponents(a);
      case 'ally':
        if (sk.kind === 'revive') return target ? [target] : [];
        { const t = this._retarget(a, target, 'friend'); return t ? [t] : []; }
      case 'allAllies': return this.friends(a);
      case 'self': return [a];
      default: return [];
    }
  }

  _doSkill(a, act, ev) {
    const sk = getSkill(act.skill);
    const cost = sk.mp || 0;
    const isEnemySkill = !SKILLS[act.skill] || !a.isParty;
    let line;
    if (sk.text && !a.isParty) line = fmt(sk.text, a.name);
    else if (sk.kind === 'physical') line = `${josa(a.name, '의')} ${sk.name}!`;
    else line = `${josa(a.name, '은')} ${josa(sk.name, '을')} 외웠다!`;
    if (a.mp < cost) {
      ev.push({ t: 'action', actor: a, text: line });
      ev.push({ t: 'msg', text: '그러나 MP가 부족하다!', sfx: 'buzzer' });
      return;
    }
    a.mp -= cost;
    const targets = this._skillTargets(a, sk, act.target);
    const anim = sk.kind === 'physical' ? 'slash' : (sk.kind === 'magic' ? 'magic' : (sk.kind === 'heal' || sk.kind === 'revive' || sk.kind === 'cure') ? 'heal' : 'buff');
    ev.push({ t: 'action', actor: a, text: line, anim, element: sk.element, targets, skill: act.skill, enemySkill: isEnemySkill });

    switch (sk.kind) {
      case 'physical': {
        let power = sk.power || 1;
        if (a.charged) { power *= 2; a.charged = false; }
        for (const t of targets) {
          for (let h = 0; h < (sk.hits || 1); h++) {
            if (!t.alive) break;
            this._physicalHit(a, t, power, sk.element, ev, sk);
          }
        }
        break;
      }
      case 'magic': {
        for (const t of targets) {
          if (!t.alive) continue;
          const mult = elementMult(t.weak, t.resist, sk.element);
          let amount = Math.round(magicDamage(sk.power, a.mag, t.mag) * mult);
          if (t.defending) amount = Math.max(1, Math.round(amount / 2));
          this._applyDamage(a, t, amount, ev, { weak: mult > 1, resist: mult < 1 });
          if (sk.drain && a.alive) {
            const h = Math.round(amount / 2);
            a.hp += h;
            ev.push({ t: 'heal', target: a, amount: h, text: `${josa(a.name, '은')} HP를 ${h} 빨아들였다!` });
          }
          if (sk.status && t.alive) this._inflict(t, sk.status, sk.chance ?? 1, ev, false);
        }
        break;
      }
      case 'heal': {
        for (const t of targets) {
          if (!t.alive) { ev.push({ t: 'msg', text: '그러나 아무 일도 일어나지 않았다.' }); continue; }
          const amt = Math.min(t.maxHp - t.hp, healAmount(sk.power, a.mag, sk.magRate));
          t.hp += amt;
          ev.push({ t: 'heal', target: t, amount: amt, text: `${josa(t.name, '의')} HP가 ${amt} 회복되었다!` });
          if (sk.cure) this._cure(t, 'all', ev, true);
        }
        break;
      }
      case 'revive': {
        const t = targets[0];
        if (!t || t.alive) { ev.push({ t: 'msg', text: '그러나 아무 일도 일어나지 않았다.' }); break; }
        this._revive(t, sk.power || 0.5, ev);
        break;
      }
      case 'cure': {
        for (const t of targets) this._cure(t, sk.status || 'all', ev, false);
        break;
      }
      case 'buff': {
        if (sk.taunt) {
          a.taunt = sk.taunt;
          ev.push({ t: 'msg', text: `적의 시선이 ${josa(a.name, '에게')} 쏠렸다!` });
        }
        if (sk.buff) {
          const statName = sk.buff.stat === 'atk' ? '공격력' : '방어력';
          for (const t of targets) t.buffs[sk.buff.stat] = { mult: sk.buff.mult, turns: sk.buff.turns };
          const who = targets.length > 1 ? (a.isParty ? '아군 모두' : '적 모두') : targets[0].name;
          ev.push({ t: 'msg', text: `${josa(who, '의')} ${statName}이 올랐다!`, buff: true, targets });
        }
        break;
      }
      case 'debuff': {
        for (const t of targets) this._inflict(t, sk.status, sk.chance ?? 1, ev, true);
        break;
      }
      case 'charge': a.charged = true; break;
      default: break;
    }
  }

  _cure(t, which, ev, quiet) {
    if (!t.alive) { if (!quiet) ev.push({ t: 'msg', text: '그러나 아무 일도 일어나지 않았다.' }); return false; }
    const had = t.status.poison || (which === 'all' && (t.status.sleep > 0 || t.status.stun > 0));
    if (which === 'poison' || which === 'all') t.status.poison = false;
    if (which === 'all') { t.status.sleep = 0; t.status.stun = 0; }
    if (had) ev.push({ t: 'msg', text: `${josa(t.name, '의')} 상태이상이 나았다!`, cure: true, target: t });
    else if (!quiet) ev.push({ t: 'msg', text: '그러나 아무 일도 일어나지 않았다.' });
    return had;
  }

  _revive(t, ratio, ev) {
    t.hp = Math.max(1, Math.round(t.maxHp * ratio));
    ev.push({ t: 'revive', target: t, text: `${josa(t.name, '이')} 되살아났다!` });
  }

  _doItem(a, act, ev) {
    const item = ITEMS[act.item];
    if (!item || !this.state.removeItem(act.item, 1)) {
      ev.push({ t: 'action', actor: a, text: `${josa(a.name, '은')} 도구를 찾았지만 없었다!` });
      return;
    }
    const e = item.effect;
    let targets = [];
    if (item.target === 'allEnemies') targets = this.opponents(a);
    else if (item.target === 'enemy') { const t = this._retarget(a, act.target, 'foe'); targets = t ? [t] : []; }
    else if (item.target === 'allAllies') targets = this.friends(a);
    else if (e.kind === 'revive') targets = act.target ? [act.target] : [];
    else { const t = this._retarget(a, act.target, 'friend'); targets = t ? [t] : []; }
    const anim = e.kind === 'damage' ? 'magic' : 'heal';
    ev.push({ t: 'action', actor: a, text: `${josa(a.name, '은')} ${josa(item.name, '을')} 사용했다!`, anim, element: e.element, targets, item: act.item });
    switch (e.kind) {
      case 'heal':
      case 'healAll':
        for (const t of targets) {
          if (!t.alive) { ev.push({ t: 'msg', text: '그러나 아무 일도 일어나지 않았다.' }); continue; }
          const amt = Math.min(t.maxHp - t.hp, e.amount);
          t.hp += amt;
          ev.push({ t: 'heal', target: t, amount: amt, text: `${josa(t.name, '의')} HP가 ${amt} 회복되었다!` });
          if (e.mp) {
            const m = Math.min(t.maxMp - t.mp, e.mp);
            t.mp += m;
            ev.push({ t: 'heal', target: t, amount: m, mp: true, text: `${josa(t.name, '의')} MP가 ${m} 회복되었다!` });
          }
        }
        break;
      case 'mp':
        for (const t of targets) {
          if (!t.alive) continue;
          const m = Math.min(t.maxMp - t.mp, e.amount);
          t.mp += m;
          ev.push({ t: 'heal', target: t, amount: m, mp: true, text: `${josa(t.name, '의')} MP가 ${m} 회복되었다!` });
        }
        break;
      case 'cure':
        for (const t of targets) this._cure(t, e.status || 'all', ev, false);
        break;
      case 'revive': {
        const t = targets[0];
        if (!t || t.alive) { ev.push({ t: 'msg', text: '그러나 아무 일도 일어나지 않았다.' }); break; }
        this._revive(t, e.amount <= 1 ? e.amount : e.amount / t.maxHp, ev);
        break;
      }
      case 'damage':
        for (const t of targets) {
          const mult = elementMult(t.weak, t.resist, e.element);
          const amount = Math.max(1, Math.round(e.amount * rand(0.9, 1.1) * mult));
          this._applyDamage(a, t, amount, ev, { weak: mult > 1, resist: mult < 1 });
        }
        break;
      default: break;
    }
  }

  // ---------- 보스 페이즈 ----------
  _checkPhases(ev) {
    for (const e of this.enemies) {
      if (!e.alive || !e.data.phases) continue;
      e.data.phases.forEach((ph, i) => {
        if (e.phaseDone.includes(i) || e.hp / e.maxHp > ph.hpBelow) return;
        e.phaseDone.push(i);
        if (ph.atk) e.permAtk *= ph.atk;
        if (ph.def) e.permDef *= ph.def;
        if (ph.actions) e.actions = ph.actions;
        if (ph.skills) e.skills = ph.skills;
        if (ph.clearDebuffs) { e.status = { poison: false, sleep: 0, stun: 0 }; }
        ev.push({ t: 'phase', target: e, text: fmt(ph.text || '{a은} 분노했다!', e.name) });
      });
    }
  }
}

export { ELEMENT_NAMES };
