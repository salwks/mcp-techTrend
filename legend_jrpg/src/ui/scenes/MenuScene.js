// 필드 메뉴: 아이템 / 스킬 / 장비 / 상태 / 저장 / 닫기
import { Scene } from '../../engine/game.js';
import { formatPlayTime } from '../../engine/state.js';
import { sfx } from '../../engine/audio.js';
import { ChoiceList, drawWindow, drawText, drawGauge, drawCursor, wrapText, COLORS } from '../window.js';
import { CHARACTERS } from '../../data/characters.js';
import * as Effects from '../../systems/effects.js';
import {
  Flow, SLOTS, SLOT_NAMES, STAT_LABELS, UP, DOWN,
  item, itemName, skill, skillName, charName, mapName, sortedInventory, previewStats, isLockedWeapon,
  drawFitText, statusTags, drawPortrait, josa,
} from './uiCommon.js';

const COMMANDS = ['아이템', '스킬', '장비', '상태', '저장', '닫기'];
const COMMAND_HELP = [
  '가지고 있는 아이템을 사용한다.',
  '동료의 스킬을 사용한다.',
  '동료의 장비를 바꾼다.',
  '동료의 자세한 상태를 본다.',
  '지금까지의 모험을 기록한다.',
  '메뉴를 닫는다.',
];
const EQUIP_STATS = ['maxHp', 'maxMp', 'atk', 'def', 'mag', 'spd'];

// 레이아웃
const PANEL = { x: 12, y: 12, w: 464, h: 372 };
const HELP = { x: 12, y: 392, w: 616, h: 76 };
const ROW_H = 88;

function effectCall(name, ...args) {
  const fn = Effects[name];
  if (typeof fn !== 'function') return null;
  try { return fn(...args); } catch (e) { console.error(e); return { ok: false, message: '사용할 수 없다.' }; }
}

export class MenuScene extends Scene {
  constructor(game, params) {
    super(game, params);
    this.opaque = false;
    this.t = 0;
    this.flow = new Flow();
    this.view = 'party';     // party | items | skills | equip | status
    this.help = '';
    this.partyCursor = -1;   // 동료 선택 중일 때 커서 위치
    this.cmd = new ChoiceList(COMMANDS, { x: 484, y: 12, w: 144 });
  }

  get state() { return this.game.state; }

  enter() {
    if (!this.state) { Promise.resolve().then(() => this.finish()); return; }
    this.run().catch((e) => { console.error(e); this.finish(); });
  }

  update(dt) {
    this.t += dt;
    this.flow.update(dt, this.game.input);
  }

  // ------------------------------------------------------------------
  // 흐름
  // ------------------------------------------------------------------
  async run() {
    while (!this._dead) {
      this.view = 'party';
      this.partyCursor = -1;
      this.help = null;
      const r = await this.flow.wait((input, dt) => {
        if (input.pressed('menu')) { sfx('cancel'); return -1; }
        const v = this.cmd.update(input, dt);
        return v === null ? undefined : v;
      });
      if (r === -1 || r === 5) { this.finish(); return; }
      if (r === 0) await this.itemMenu();
      else if (r === 1) await this.skillMenu();
      else if (r === 2) await this.equipMenu();
      else if (r === 3) await this.statusMenu();
      else if (r === 4) await this.game.runScene('save', { mode: 'save' });
    }
  }

  // 동료 선택. 결과: 파티 인덱스 | -1
  selectMember(help, start = 0) {
    const n = this.state.party.length;
    this.partyCursor = Math.max(0, Math.min(n - 1, start));
    this.help = help;
    return this.flow.wait((input) => {
      if (input.repeat('down')) { this.partyCursor = (this.partyCursor + 1) % n; sfx('cursor'); }
      if (input.repeat('up')) { this.partyCursor = (this.partyCursor - 1 + n) % n; sfx('cursor'); }
      if (input.pressed('confirm')) { sfx('confirm'); return this.partyCursor; }
      if (input.pressed('cancel') || input.pressed('menu')) { sfx('cancel'); return -1; }
      return undefined;
    }).then((r) => { if (r < 0) this.partyCursor = -1; return r; });
  }

  waitBack() {
    return this.flow.wait((input) => {
      if (input.pressed('cancel') || input.pressed('menu') || input.pressed('confirm')) { sfx('cancel'); return -1; }
      return undefined;
    });
  }

  // ---- 아이템 ----
  async itemMenu() {
    const list = new ChoiceList([], { x: PANEL.x, y: PANEL.y, w: PANEL.w, rowH: 30, visibleRows: 11 });
    this.itemList = list;
    while (!this._dead) {
      this.view = 'items';
      this.partyCursor = -1;
      const ids = sortedInventory(this.state);
      this.itemIds = ids;
      list.setItems(ids.map((id) => ({
        label: itemName(id),
        right: '×' + this.state.itemCount(id),
        disabled: !this.canUseItem(id),
      })));
      if (!ids.length) {
        this.help = '아이템이 없다.';
        await this.waitBack();
        return;
      }
      const i = await this.flow.choose(list, (k) => { this.help = item(ids[k])?.desc || ''; });
      if (i < 0) return;
      await this.useItem(ids[i]);
    }
  }

  canUseItem(id) {
    const it = item(id);
    if (!it || it.type !== 'consumable') return false;
    const r = effectCall('canUseItemInField', id);
    if (r === null) return it.usable === 'both' || it.usable === 'field';
    return !!r;
  }

  async useItem(id) {
    const it = item(id) || {};
    const name = itemName(id);
    if (it.target === 'allAllies' || it.target === 'allEnemies' || it.target === 'enemy' || it.effect?.kind === 'healAll') {
      await this.applyItem(id, null);
      return;
    }
    let cur = 0;
    while (this.state.itemCount(id) > 0) {
      this.view = 'party';
      const mi = await this.selectMember(`${name}(×${this.state.itemCount(id)}) — 누구에게 사용하시겠습니까?`, cur);
      if (mi < 0) return;
      cur = mi;
      await this.applyItem(id, this.state.party[mi]);
    }
    this.partyCursor = -1;
  }

  async applyItem(id, targetId) {
    const res = effectCall('useItemInField', this.state, id, targetId) || { ok: false, message: '지금은 사용할 수 없다.' };
    sfx(res.ok ? 'heal' : 'buzzer');
    await this.flow.say(res.message || (res.ok ? '사용했다.' : '효과가 없었다.'));
  }

  // ---- 스킬 ----
  async skillMenu() {
    let cur = 0;
    while (!this._dead) {
      this.view = 'party';
      const mi = await this.selectMember('누구의 스킬을 사용하시겠습니까?', cur);
      if (mi < 0) return;
      cur = mi;
      await this.skillList(this.state.party[mi]);
    }
  }

  async skillList(cid) {
    const list = new ChoiceList([], { x: PANEL.x, y: PANEL.y + 56, w: PANEL.w, rowH: 30, visibleRows: 9 });
    this.skillListUI = list;
    this.skillCaster = cid;
    while (!this._dead) {
      this.view = 'skills';
      this.partyCursor = -1;
      const m = this.state.members[cid];
      const ids = this.state.knownSkills(cid);
      this.skillIds = ids;
      list.setItems(ids.map((sid) => {
        const sk = skill(sid);
        const cost = sk?.mp || 0;
        const usable = !!sk && this.canCast(sid) && m.hp > 0 && m.mp >= cost;
        return { label: skillName(sid), right: `${cost} MP`, disabled: !usable };
      }));
      if (!ids.length) {
        this.help = `${charName(cid)}은(는) 아직 스킬을 익히지 못했다.`;
        await this.waitBack();
        return;
      }
      const i = await this.flow.choose(list, (k) => {
        const sk = skill(ids[k]);
        let d = sk?.desc || '';
        if (sk && !this.canCast(ids[k])) d += ' (전투 전용)';
        this.help = d;
      });
      if (i < 0) return;
      await this.castSkill(cid, ids[i]);
    }
  }

  canCast(sid) {
    const r = effectCall('canCastInField', sid);
    if (r === null) return !!skill(sid)?.field;
    return !!r;
  }

  async castSkill(cid, sid) {
    const sk = skill(sid) || {};
    const m = this.state.members[cid];
    if (sk.target === 'ally') {
      let cur = 0;
      while ((m.mp >= (sk.mp || 0)) && m.hp > 0) {
        this.view = 'party';
        const mi = await this.selectMember(`${skillName(sid)} (${sk.mp || 0} MP) — 누구에게? [${charName(cid)} MP ${m.mp}]`, cur);
        if (mi < 0) return;
        cur = mi;
        await this.applySkill(cid, sid, this.state.party[mi]);
      }
      this.partyCursor = -1;
      return;
    }
    await this.applySkill(cid, sid, sk.target === 'self' ? cid : null);
  }

  async applySkill(cid, sid, targetId) {
    const res = effectCall('castSkillInField', this.state, cid, sid, targetId) || { ok: false, message: '지금은 사용할 수 없다.' };
    sfx(res.ok ? 'heal' : 'buzzer');
    await this.flow.say(res.message || (res.ok ? '스킬을 사용했다.' : '효과가 없었다.'));
  }

  // ---- 장비 ----
  async equipMenu() {
    let cur = 0;
    while (!this._dead) {
      this.view = 'party';
      const mi = await this.selectMember('누구의 장비를 바꾸시겠습니까?', cur);
      if (mi < 0) return;
      this.eqMember = mi;
      await this.equipScreen();
      cur = this.eqMember;
    }
  }

  async equipScreen() {
    const slotList = new ChoiceList([], { x: PANEL.x, y: PANEL.y + 42, w: PANEL.w, rowH: 32, window: false });
    this.eqSlotList = slotList;
    const refresh = () => {
      const cid = this.state.party[this.eqMember];
      const eq = this.state.members[cid].equip;
      slotList.setItems(SLOTS.map((s) => ({
        label: SLOT_NAMES[s],
        right: (eq[s] ? itemName(eq[s]) : '— 없음 —') + (s === 'weapon' && isLockedWeapon(this.state, cid) ? ' [고정]' : ''),
      })));
    };
    while (!this._dead) {
      this.view = 'equip';
      this.partyCursor = -1;
      this.eqCands = null;
      this.eqPreview = null;
      refresh();
      const slotHelp = () => {
        const cid = this.state.party[this.eqMember];
        const cur = this.state.members[cid].equip[SLOTS[slotList.index]];
        this.help = cur ? (item(cur)?.desc || '') : '◀ ▶ 동료 전환';
      };
      slotHelp();
      let last = slotList.index;
      const r = await this.flow.wait((input, dt) => {
        const n = this.state.party.length;
        if (n > 1 && (input.repeat('left') || input.repeat('right'))) {
          this.eqMember = (this.eqMember + (input.repeat('right') ? 1 : -1) + n) % n;
          sfx('cursor');
          refresh();
          slotHelp();
        }
        const v = slotList.update(input, dt);
        if (slotList.index !== last) { last = slotList.index; slotHelp(); }
        if (v === null && input.pressed('menu')) { sfx('cancel'); return -1; }
        return v === null ? undefined : v;
      });
      if (r < 0) return;
      await this.chooseEquip(SLOTS[r]);
    }
  }

  async chooseEquip(slot) {
    const cid = this.state.party[this.eqMember];
    const m = this.state.members[cid];
    if (slot === 'weapon' && isLockedWeapon(this.state, cid)) {
      sfx('buzzer');
      await this.flow.say('성검은 뺄 수 없다.');
      return;
    }
    const ids = sortedInventory(this.state).filter((id) => this.state.slotOf(id) === slot && this.state.canEquip(cid, id));
    const cands = ids.map((id) => ({ id, label: itemName(id), right: '×' + this.state.itemCount(id) }));
    if (m.equip[slot]) cands.push({ id: null, label: '(해제)' });
    if (!cands.length) {
      sfx('buzzer');
      await this.flow.say(`${SLOT_NAMES[slot]}에 장비할 수 있는 것이 없다.`);
      return;
    }
    const list = new ChoiceList(cands, { x: 244, y: 176, w: 232, rowH: 30, visibleRows: 6, size: 16 });
    this.eqCands = list;
    const i = await this.flow.choose(list, (k) => {
      const c = cands[k];
      this.eqPreview = previewStats(this.state, cid, slot, c.id);
      this.help = c.id ? (item(c.id)?.desc || '') : `${josa(SLOT_NAMES[slot], '을', '를')} 해제한다.`;
    });
    this.eqCands = null;
    this.eqPreview = null;
    if (i < 0) return;
    const c = cands[i];
    const ok = c.id ? this.state.equip(cid, c.id) : this.state.unequip(cid, slot);
    if (ok) sfx('item');
    else { sfx('buzzer'); await this.flow.say('장비할 수 없다.'); }
  }

  // ---- 상태 ----
  async statusMenu() {
    this.view = 'status';
    this.statusIndex = 0;
    const n = this.state.party.length;
    await this.flow.wait((input) => {
      if (input.repeat('right') || input.repeat('down')) { this.statusIndex = (this.statusIndex + 1) % n; if (n > 1) sfx('cursor'); }
      if (input.repeat('left') || input.repeat('up')) { this.statusIndex = (this.statusIndex - 1 + n) % n; if (n > 1) sfx('cursor'); }
      if (input.pressed('cancel') || input.pressed('menu') || input.pressed('confirm')) { sfx('cancel'); return -1; }
      return undefined;
    });
  }

  // ------------------------------------------------------------------
  // 그리기
  // ------------------------------------------------------------------
  draw(ctx) {
    if (!this.state) return;
    ctx.fillStyle = 'rgba(0,0,10,0.45)';
    ctx.fillRect(0, 0, 640, 480);

    if (this.view === 'status') {
      this.drawStatus(ctx);
      this.flow.msg.draw(ctx);
      return;
    }

    // 오른쪽 열
    const topActive = this.flow.isWaiting() && this.view === 'party' && this.partyCursor < 0 && this.help == null;
    this.cmd.draw(ctx, topActive);
    this.drawInfo(ctx);

    // 왼쪽 패널
    if (this.view === 'items') this.drawItems(ctx);
    else if (this.view === 'skills') this.drawSkills(ctx);
    else if (this.view === 'equip') this.drawEquip(ctx);
    else this.drawParty(ctx);

    // 도움말 (메시지 표시 중에는 가린다)
    if (!this.flow.msg.active) {
      drawWindow(ctx, HELP.x, HELP.y, HELP.w, HELP.h);
      const help = this.help == null ? COMMAND_HELP[this.cmd.index] : this.help;
      const lines = wrapText(ctx, help || '', HELP.w - 40, 17).slice(0, 2);
      lines.forEach((l, i) => drawText(ctx, l, HELP.x + 20, HELP.y + 16 + i * 24, { size: 17 }));
    }

    this.flow.msg.draw(ctx);
  }

  drawInfo(ctx) {
    drawWindow(ctx, 484, 236, 144, 88);
    drawText(ctx, '소지금', 498, 248, { size: 14, color: COLORS.dim });
    drawFitText(ctx, `${this.state.gold} G`, 614, 266, 116, { size: 18, align: 'right', color: COLORS.accent });
    drawText(ctx, '플레이 시간', 498, 290, { size: 14, color: COLORS.dim });
    drawText(ctx, formatPlayTime(this.state.playTime), 614, 288, { size: 16, align: 'right' });
    drawWindow(ctx, 484, 332, 144, 52);
    const name = mapName(this.state) || '???';
    ctx.save();
    drawFitText(ctx, name, 556, 348, 120, { size: 16, align: 'center' });
    ctx.restore();
  }

  drawParty(ctx) {
    const { x, y, w, h } = PANEL;
    drawWindow(ctx, x, y, w, h);
    this.state.party.forEach((id, i) => {
      const m = this.state.members[id];
      if (!m) return;
      const st = this.state.getStats(id);
      const y0 = y + 14 + i * ROW_H;
      const dead = m.hp <= 0;
      drawPortrait(ctx, id, x + 30, y0 + 6, 58, dead);
      drawText(ctx, charName(id), x + 104, y0 + 2, { size: 20, bold: true, color: dead ? DOWN : COLORS.text });
      drawText(ctx, CHARACTERS[id]?.role || '', x + 170, y0 + 5, { size: 15, color: COLORS.dim });
      let tx = x + 230;
      for (const tag of statusTags(m)) {
        drawText(ctx, tag.text, tx, y0 + 5, { size: 15, bold: true, color: tag.color });
        tx += tag.text.length * 15 + 12;
      }
      drawText(ctx, `Lv ${m.level}`, x + w - 22, y0 + 4, { size: 17, align: 'right', color: COLORS.accent });
      this.drawBar(ctx, 'HP', m.hp, st.maxHp, x + 104, y0 + 32, m.hp / st.maxHp < 0.25 ? COLORS.hpLow : COLORS.hp);
      this.drawBar(ctx, 'MP', m.mp, st.maxMp, x + 104, y0 + 56, COLORS.mp);
      if (i === this.partyCursor) drawCursor(ctx, x + 10, y0 + 28, this.t);
    });
  }

  drawBar(ctx, label, v, max, x, y, color) {
    drawText(ctx, label, x, y - 2, { size: 14, bold: true, color: COLORS.dim });
    drawGauge(ctx, x + 30, y + 3, 200, 10, max > 0 ? v / max : 0, color);
    drawText(ctx, `${v} / ${max}`, x + 338, y - 3, { size: 16, align: 'right' });
  }

  drawItems(ctx) {
    const list = this.itemList;
    list.draw(ctx, this.flow.isWaiting());
    if (!list.items.length) {
      drawText(ctx, '아이템이 없다', PANEL.x + PANEL.w / 2, PANEL.y + 20, { size: 18, align: 'center', color: COLORS.dim });
    }
  }

  drawSkills(ctx) {
    const cid = this.skillCaster;
    const m = this.state.members[cid];
    const st = this.state.getStats(cid);
    drawWindow(ctx, PANEL.x, PANEL.y, PANEL.w, 50);
    drawText(ctx, charName(cid), PANEL.x + 20, PANEL.y + 13, { size: 19, bold: true });
    drawText(ctx, `MP  ${m.mp} / ${st.maxMp}`, PANEL.x + PANEL.w - 20, PANEL.y + 14, { size: 17, align: 'right', color: COLORS.mp });
    const list = this.skillListUI;
    list.draw(ctx, this.flow.isWaiting());
    if (!list.items.length) {
      drawText(ctx, '익힌 스킬이 없다', PANEL.x + PANEL.w / 2, PANEL.y + 76, { size: 18, align: 'center', color: COLORS.dim });
    }
  }

  drawEquip(ctx) {
    const cid = this.state.party[this.eqMember];
    const m = this.state.members[cid];
    const { x, y, w } = PANEL;
    // 슬롯 창
    drawWindow(ctx, x, y, w, 156);
    drawText(ctx, charName(cid), x + 20, y + 14, { size: 19, bold: true });
    drawText(ctx, `${CHARACTERS[cid]?.role || ''}  Lv ${m.level}`, x + 76, y + 17, { size: 15, color: COLORS.dim });
    if (this.state.party.length > 1) drawText(ctx, '◀ ▶', x + w - 20, y + 16, { size: 14, align: 'right', color: COLORS.dim });
    this.eqSlotList.draw(ctx, this.flow.isWaiting() && !this.eqCands);

    // 능력치 창
    drawWindow(ctx, x, 176, 224, 208);
    const cur = this.state.getStats(cid);
    const pv = this.eqPreview;
    EQUIP_STATS.forEach((k, i) => {
      const ry = 190 + i * 30;
      drawText(ctx, STAT_LABELS[k], x + 16, ry, { size: 15, color: COLORS.dim });
      drawText(ctx, String(cur[k]), x + 136, ry, { size: 16, align: 'right' });
      if (pv) {
        const d = pv[k] - cur[k];
        const color = d > 0 ? UP : d < 0 ? DOWN : COLORS.text;
        drawText(ctx, '→', x + 146, ry, { size: 15, color: COLORS.dim });
        drawText(ctx, String(pv[k]), x + 206, ry, { size: 16, align: 'right', color, bold: d !== 0 });
      }
    });

    // 후보 창
    if (this.eqCands) this.eqCands.draw(ctx, this.flow.isWaiting());
    else {
      drawWindow(ctx, 244, 176, 232, 208);
      drawText(ctx, '장비를 고르세요', 360, 268, { size: 15, align: 'center', color: COLORS.dim });
    }
  }

  drawStatus(ctx) {
    const id = this.state.party[this.statusIndex] || this.state.party[0];
    const m = this.state.members[id];
    if (!m) return;
    const st = this.state.getStats(id);
    drawWindow(ctx, 12, 12, 616, 456, { alpha: 1 });
    const dead = m.hp <= 0;
    drawPortrait(ctx, id, 36, 36, 80, dead);
    drawText(ctx, charName(id), 136, 36, { size: 28, bold: true });
    drawText(ctx, CHARACTERS[id]?.role || '', 136, 74, { size: 17, color: COLORS.dim });
    let tx = 200;
    for (const tag of statusTags(m)) {
      drawText(ctx, tag.text, tx, 74, { size: 16, bold: true, color: tag.color });
      tx += tag.text.length * 16 + 12;
    }
    drawText(ctx, `Lv ${m.level}`, 136, 98, { size: 18, bold: true, color: COLORS.accent });
    drawText(ctx, `${this.statusIndex + 1} / ${this.state.party.length}`, 604, 36, { size: 15, align: 'right', color: COLORS.dim });

    // HP/MP/EXP
    const bx = 330;
    this.drawBarWide(ctx, 'HP', m.hp, st.maxHp, bx, 64, m.hp / st.maxHp < 0.25 ? COLORS.hpLow : COLORS.hp);
    this.drawBarWide(ctx, 'MP', m.mp, st.maxMp, bx, 92, COLORS.mp);
    const next = this.state.expToNext(id);
    drawText(ctx, 'EXP', 36, 132, { size: 15, bold: true, color: COLORS.dim });
    drawText(ctx, String(m.exp), 250, 131, { size: 17, align: 'right' });
    drawText(ctx, '다음 레벨까지', 330, 132, { size: 15, bold: true, color: COLORS.dim });
    drawText(ctx, next > 0 ? String(next) : 'MAX', 604, 131, { size: 17, align: 'right', color: COLORS.exp });
    const lvBase = this.state.expForLevel(m.level);
    const lvNext = this.state.expForLevel(m.level + 1);
    drawGauge(ctx, 36, 156, 568, 8, next > 0 ? (m.exp - lvBase) / Math.max(1, lvNext - lvBase) : 1, COLORS.exp);

    // 구분선
    ctx.fillStyle = 'rgba(232,236,255,0.25)';
    ctx.fillRect(32, 176, 576, 1);

    // 능력치
    drawText(ctx, '능력치', 36, 186, { size: 15, bold: true, color: COLORS.accent });
    ['atk', 'def', 'mag', 'spd'].forEach((k, i) => {
      const ry = 212 + i * 26;
      drawText(ctx, STAT_LABELS[k], 44, ry, { size: 16, color: COLORS.dim });
      drawText(ctx, String(st[k]), 230, ry, { size: 17, align: 'right' });
    });

    // 장비
    drawText(ctx, '장비', 270, 186, { size: 15, bold: true, color: COLORS.accent });
    SLOTS.forEach((s, i) => {
      const ry = 212 + i * 26;
      drawText(ctx, SLOT_NAMES[s], 278, ry, { size: 16, color: COLORS.dim });
      const eq = m.equip[s];
      drawFitText(ctx, eq ? itemName(eq) : '— 없음 —', 350, ry, 250, { size: 17, color: eq ? COLORS.text : COLORS.disabled });
    });

    ctx.fillStyle = 'rgba(232,236,255,0.25)';
    ctx.fillRect(32, 324, 576, 1);

    // 스킬
    drawText(ctx, '스킬', 36, 334, { size: 15, bold: true, color: COLORS.accent });
    const skills = this.state.knownSkills(id);
    if (!skills.length) drawText(ctx, '— 없음 —', 44, 360, { size: 16, color: COLORS.disabled });
    skills.forEach((sid, i) => {
      const col = i % 2, row = Math.floor(i / 2);
      const sx = 44 + col * 290, sy = 358 + row * 24;
      if (row > 3) return;
      drawFitText(ctx, skillName(sid), sx, sy, 190, { size: 16 });
      drawText(ctx, `${skill(sid)?.mp ?? 0} MP`, sx + 256, sy, { size: 15, align: 'right', color: COLORS.mp });
    });

    if (this.state.party.length > 1) {
      drawText(ctx, '◀ ▶ 동료 전환', 604, 446, { size: 13, align: 'right', color: COLORS.dim });
    }
  }

  drawBarWide(ctx, label, v, max, x, y, color) {
    drawText(ctx, label, x, y - 2, { size: 15, bold: true, color: COLORS.dim });
    drawGauge(ctx, x + 32, y + 4, 140, 10, max > 0 ? v / max : 0, color);
    drawText(ctx, `${v}/${max}`, 604, y - 3, { size: 17, align: 'right' });
  }
}
