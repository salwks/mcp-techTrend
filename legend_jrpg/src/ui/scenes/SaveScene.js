// 세이브/로드  params: { mode: 'save' | 'load' }
import { Scene } from '../../engine/game.js';
import { listSlots, saveSlot, loadSlot, formatPlayTime } from '../../engine/state.js';
import { sfx } from '../../engine/audio.js';
import { ChoiceList, drawWindow, drawText, drawCursor, COLORS } from '../window.js';
import { Flow, charName, mapName, formatDate, drawFitText, drawPortrait } from './uiCommon.js';

const SLOT_Y = 76;
const SLOT_H = 124;

export class SaveScene extends Scene {
  constructor(game, params) {
    super(game, params);
    this.opaque = false;
    this.t = 0;
    this.mode = this.params.mode === 'load' ? 'load' : 'save';
    this.flow = new Flow();
    this.cursor = 0;
    this.slots = listSlots();
    this.confirm = null;
    this.busy = false;
  }

  enter() {
    if (this.mode === 'save' && !this.game.state) { Promise.resolve().then(() => this.finish()); return; }
    // 로드 화면은 가장 최근 기록에 커서를 둔다
    let best = -1, bestAt = -1;
    this.slots.forEach((s, i) => { if (s.summary && (s.summary.savedAt || 0) > bestAt) { bestAt = s.summary.savedAt || 0; best = i; } });
    if (this.mode === 'load' && best >= 0) this.cursor = best;
    this.run().catch((e) => { console.error(e); this.finish(); });
  }

  update(dt) {
    this.t += dt;
    if (!this.busy) this.flow.update(dt, this.game.input);
  }

  async run() {
    while (!this._dead) {
      this.slots = listSlots();
      const n = this.slots.length;
      const i = await this.flow.wait((input) => {
        if (input.repeat('down')) { this.cursor = (this.cursor + 1) % n; sfx('cursor'); }
        if (input.repeat('up')) { this.cursor = (this.cursor - 1 + n) % n; sfx('cursor'); }
        if (input.pressed('confirm')) return this.cursor;
        if (input.pressed('cancel') || input.pressed('menu')) { sfx('cancel'); return -1; }
        return undefined;
      });
      if (i < 0) { this.finish(null); return; }
      const slot = this.slots[i];
      if (this.mode === 'save') {
        if (await this.doSave(slot)) { this.finish('saved'); return; }
      } else if (await this.doLoad(slot)) {
        return;
      }
    }
  }

  async doSave(slot) {
    sfx('confirm');
    if (slot.summary) {
      this.confirm = new ChoiceList(['덮어쓴다', '그만둔다'], { x: 400, y: SLOT_Y + (slot.slot - 1) * (SLOT_H + 4) + 20, w: 180, index: 1 });
      const c = await this.flow.choose(this.confirm);
      this.confirm = null;
      if (c !== 0) return false;
    }
    const st = this.game.state;
    const ok = saveSlot(slot.slot, st, mapName(st));
    this.slots = listSlots();
    if (ok) {
      sfx('item');
      await this.flow.say(`슬롯 ${slot.slot}에 모험을 기록했다.`);
      return true;
    }
    sfx('buzzer');
    await this.flow.say('기록에 실패했다… (브라우저 저장소를 사용할 수 없습니다)');
    return false;
  }

  async doLoad(slot) {
    if (!slot.summary) { sfx('buzzer'); return false; }
    const s = loadSlot(slot.slot);
    if (!s) {
      sfx('buzzer');
      await this.flow.say('기록을 불러오지 못했다.');
      return false;
    }
    sfx('confirm');
    this.busy = true;
    this.game.state = s;
    await this.game.fadeOut(500);
    // reset이 스택 전체(이 씬 포함)를 교체한다 — 결과 'loaded'는 필드 재시작으로 대체됨
    this.game.reset('field', {});
    this.game.fadeIn(500);
    return true;
  }

  draw(ctx) {
    ctx.fillStyle = 'rgba(0,0,12,0.6)';
    ctx.fillRect(0, 0, 640, 480);
    drawWindow(ctx, 12, 12, 616, 56);
    drawText(ctx, this.mode === 'save' ? '기록하기' : '불러오기', 32, 28, { size: 20, bold: true, color: COLORS.accent });
    drawText(ctx, this.mode === 'save' ? '어느 슬롯에 기록하시겠습니까?' : '어느 기록을 불러오시겠습니까?', 150, 30, { size: 17 });

    const active = this.flow.isWaiting() && !this.confirm && !this.busy;
    this.slots.forEach((s, i) => {
      const y = SLOT_Y + i * (SLOT_H + 4);
      drawWindow(ctx, 12, y, 616, SLOT_H);
      if (i === this.cursor) {
        ctx.save();
        ctx.fillStyle = 'rgba(255,214,90,0.08)';
        ctx.fillRect(18, y + 6, 604, SLOT_H - 12);
        ctx.restore();
        drawCursor(ctx, 22, y + 22, active ? this.t : 0);
      }
      drawText(ctx, `슬롯 ${s.slot}`, 42, y + 16, { size: 18, bold: true, color: COLORS.accent });
      const sm = s.summary;
      if (!sm) {
        drawText(ctx, '— 비어 있음 —', 320, y + SLOT_H / 2 - 10, { size: 18, align: 'center', color: COLORS.disabled });
        return;
      }
      drawText(ctx, formatDate(sm.savedAt), 606, y + 18, { size: 14, align: 'right', color: COLORS.dim });
      drawFitText(ctx, sm.mapName || sm.mapId || '', 130, y + 16, 300, { size: 18, bold: true });
      const party = sm.party || [];
      party.slice(0, 4).forEach((id, k) => drawPortrait(ctx, id, 42 + k * 46, y + 50, 38));
      drawText(ctx, party.map(charName).join(' · '), 236, y + 50, { size: 16 });
      drawText(ctx, `Lv ${sm.level ?? 1}`, 236, y + 80, { size: 16, color: COLORS.accent });
      drawText(ctx, `${sm.gold ?? 0} G`, 330, y + 80, { size: 16 });
      drawText(ctx, `플레이 시간 ${formatPlayTime(sm.playTime)}`, 606, y + 80, { size: 16, align: 'right' });
    });

    if (this.confirm) this.confirm.draw(ctx, this.flow.isWaiting());
    this.flow.msg.draw(ctx);
  }
}
