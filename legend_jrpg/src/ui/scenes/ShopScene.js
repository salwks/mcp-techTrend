// 상점: 사기 / 팔기 / 나가기   params: { items:[itemId...], title? }
import { Scene } from '../../engine/game.js';
import { sfx } from '../../engine/audio.js';
import { ChoiceList, drawWindow, drawText, wrapText, COLORS } from '../window.js';
import {
  Flow, SLOT_NAMES, STAT_SHORT, UP, DOWN,
  item, itemName, charName, sortedInventory, previewStats, josa, drawFitText,
} from './uiCommon.js';

const LIST = { x: 12, y: 68, w: 400 };
const INFO = { x: 420, y: 68, w: 208, h: 264 };
const DESC = { x: 12, y: 340, w: 616, h: 60 };
const SPEAKER = '상인';

function sellPrice(id) {
  const it = item(id);
  if (!it || it.type === 'key' || !(it.price > 0)) return 0;
  return Math.floor(it.price / 2);
}

export class ShopScene extends Scene {
  constructor(game, params) {
    super(game, params);
    this.opaque = false;
    this.t = 0;
    this.flow = new Flow();
    this.view = 'greet'; // greet | cmd | buy | sell
    this.title = this.params.title || '상점';
    this.goods = (this.params.items || []).filter((id) => id);
    this.cur = null;     // 현재 커서가 가리키는 아이템
    this.qty = null;     // 수량 선택 { n, max, price, mode }
    this.cmd = new ChoiceList(['사기', '팔기', '나가기'], { x: LIST.x, y: LIST.y, w: 160 });
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

  async run() {
    await this.flow.say('어서 오세요! 좋은 물건 많이 있습니다.\n천천히 둘러보세요.', SPEAKER);
    while (!this._dead) {
      this.view = 'cmd';
      this.cur = null;
      const i = await this.flow.choose(this.cmd);
      if (i === 0) await this.buy();
      else if (i === 1) await this.sell();
      else {
        this.view = 'greet';
        await this.flow.say('감사합니다! 또 들러 주세요.', SPEAKER);
        this.finish();
        return;
      }
    }
  }

  // ---- 사기 ----
  async buy() {
    const ids = this.goods;
    const list = new ChoiceList(ids.map((id) => ({
      label: itemName(id),
      right: item(id) ? `${item(id).price} G` : '—',
      disabled: !item(id),
    })), { x: LIST.x, y: LIST.y, w: LIST.w, rowH: 30, visibleRows: 8 });
    this.list = list;
    this.view = 'buy';
    if (!ids.length) {
      await this.flow.say('죄송합니다. 지금은 팔 물건이 없네요.', SPEAKER);
      return;
    }
    while (!this._dead) {
      this.view = 'buy';
      const i = await this.flow.choose(list, (k) => { this.cur = ids[k]; });
      if (i < 0) return;
      const id = ids[i];
      const it = item(id);
      const price = it.price || 0;
      const owned = this.state.itemCount(id);
      const room = 99 - owned;
      const afford = price > 0 ? Math.floor(this.state.gold / price) : room;
      const max = Math.min(room, afford);
      if (room <= 0) { sfx('buzzer'); await this.flow.say('더 이상 가질 수 없는 것 같네요.', SPEAKER); continue; }
      if (max <= 0) { sfx('buzzer'); await this.flow.say('골드가 모자라는군요.', SPEAKER); continue; }
      const n = await this.chooseQty('buy', id, max, price);
      if (n <= 0) continue;
      this.state.gold -= n * price;
      this.state.addItem(id, n);
      sfx('item');
      await this.flow.say(`${josa(itemName(id), '을', '를')} ${n}개 샀다.\n감사합니다!`, SPEAKER);
    }
  }

  // ---- 팔기 ----
  async sell() {
    const list = new ChoiceList([], { x: LIST.x, y: LIST.y, w: LIST.w, rowH: 30, visibleRows: 8 });
    this.list = list;
    while (!this._dead) {
      this.view = 'sell';
      const ids = sortedInventory(this.state);
      this.sellIds = ids;
      list.setItems(ids.map((id) => {
        const p = sellPrice(id);
        return { label: `${itemName(id)} ×${this.state.itemCount(id)}`, right: p > 0 ? `${p} G` : '팔 수 없음', disabled: p <= 0 };
      }));
      if (!ids.length) {
        this.cur = null;
        await this.flow.say('팔 수 있는 물건이 없으시군요.', SPEAKER);
        return;
      }
      const i = await this.flow.choose(list, (k) => { this.cur = ids[k]; });
      if (i < 0) return;
      const id = ids[i];
      const p = sellPrice(id);
      const n = await this.chooseQty('sell', id, this.state.itemCount(id), p);
      if (n <= 0) continue;
      this.state.removeItem(id, n);
      this.state.gold += n * p;
      sfx('item');
      await this.flow.say(`${josa(itemName(id), '을', '를')} ${n}개 팔아 ${n * p} G를 받았다.`, SPEAKER);
    }
  }

  // 수량 선택: ◀▶ ±1, ▲▼ ±10. 결과: 개수 | -1
  chooseQty(mode, id, max, price) {
    this.qty = { mode, id, n: 1, max, price };
    return this.flow.wait((input) => {
      const q = this.qty;
      const prev = q.n;
      if (input.repeat('right')) q.n += 1;
      if (input.repeat('left')) q.n -= 1;
      if (input.repeat('up')) q.n += 10;
      if (input.repeat('down')) q.n -= 10;
      if (q.n > q.max) q.n = prev === q.max && (input.repeat('right')) ? 1 : q.max;
      if (q.n < 1) q.n = prev === 1 && (input.repeat('left')) ? q.max : 1;
      if (q.n !== prev) sfx('cursor');
      if (input.pressed('confirm')) { sfx('confirm'); return q.n; }
      if (input.pressed('cancel') || input.pressed('menu')) { sfx('cancel'); return -1; }
      return undefined;
    }).then((r) => { this.qty = null; return r; });
  }

  // ---- 그리기 ----
  draw(ctx) {
    if (!this.state) return;
    ctx.fillStyle = 'rgba(0,0,10,0.3)';
    ctx.fillRect(0, 0, 640, 480);

    // 머리
    drawWindow(ctx, 12, 12, 400, 48);
    drawFitText(ctx, this.title, 32, 25, 360, { size: 19, bold: true, color: COLORS.accent });
    drawWindow(ctx, 420, 12, 208, 48);
    drawText(ctx, '소지금', 436, 27, { size: 14, color: COLORS.dim });
    drawFitText(ctx, `${this.state.gold} G`, 612, 24, 130, { size: 19, align: 'right', bold: true });

    const waiting = this.flow.isWaiting() && !this.qty;
    if (this.view === 'cmd') {
      this.cmd.draw(ctx, waiting);
    } else if (this.view === 'buy' || this.view === 'sell') {
      this.list.draw(ctx, waiting);
      this.drawInfo(ctx);
      drawWindow(ctx, DESC.x, DESC.y, DESC.w, DESC.h);
      const d = this.cur ? (item(this.cur)?.desc || '') : '';
      wrapText(ctx, d, DESC.w - 40, 16).slice(0, 2).forEach((l, i) => drawText(ctx, l, DESC.x + 20, DESC.y + 10 + i * 22, { size: 16 }));
      if (this.qty) this.drawQty(ctx);
    }
    this.flow.msg.draw(ctx);
  }

  drawInfo(ctx) {
    const { x, y, w, h } = INFO;
    drawWindow(ctx, x, y, w, h);
    const id = this.cur;
    if (!id) return;
    const it = item(id);
    drawText(ctx, '가지고 있는 수', x + 16, y + 14, { size: 14, color: COLORS.dim });
    drawText(ctx, `${this.state.itemCount(id)}`, x + w - 16, y + 12, { size: 17, align: 'right' });
    if (!it) return;
    const slot = this.state.slotOf(id);
    if (!slot) {
      const t = { consumable: '소비 아이템', key: '중요한 물건' }[it.type] || '';
      drawText(ctx, t, x + 16, y + 44, { size: 14, color: COLORS.dim });
      return;
    }
    drawText(ctx, `${SLOT_NAMES[slot]} — 장비 가능`, x + 16, y + 44, { size: 14, color: COLORS.dim });
    this.state.party.forEach((cid, i) => {
      const ry = y + 72 + i * 44;
      const m = this.state.members[cid];
      if (!m) return;
      const can = this.state.canEquip(cid, id);
      drawText(ctx, charName(cid), x + 16, ry, { size: 16, bold: true, color: can ? COLORS.text : COLORS.disabled });
      if (!can) { drawText(ctx, '장비 불가', x + w - 16, ry, { size: 14, align: 'right', color: COLORS.disabled }); return; }
      if (m.equip[slot] === id) { drawText(ctx, 'E 장비 중', x + w - 16, ry, { size: 14, align: 'right', color: COLORS.accent }); return; }
      const cur = this.state.getStats(cid);
      const pv = previewStats(this.state, cid, slot, id);
      const diffs = ['atk', 'def', 'mag', 'spd', 'maxHp', 'maxMp']
        .map((k) => ({ k, d: pv[k] - cur[k] }))
        .filter((e) => e.d !== 0)
        .slice(0, 3);
      if (!diffs.length) { drawText(ctx, '변화 없음', x + w - 16, ry, { size: 14, align: 'right', color: COLORS.dim }); return; }
      // 두 번째 줄에 수치 변화
      let dx = x + 26;
      for (const e of diffs) {
        const s = `${STAT_SHORT[e.k]}${e.d > 0 ? '+' : ''}${e.d}${e.d > 0 ? '▲' : '▼'}`;
        drawText(ctx, s, dx, ry + 20, { size: 14, color: e.d > 0 ? UP : DOWN });
        ctx.save();
        ctx.font = '14px sans-serif';
        dx += Math.max(52, ctx.measureText(s).width + 10);
        ctx.restore();
      }
      const sum = diffs.reduce((a, e) => a + e.d, 0);
      drawText(ctx, sum > 0 ? '▲' : sum < 0 ? '▼' : '=', x + w - 16, ry, { size: 15, align: 'right', color: sum > 0 ? UP : sum < 0 ? DOWN : COLORS.dim });
    });
  }

  drawQty(ctx) {
    const q = this.qty;
    const x = 110, y = 150, w = 300, h = 132;
    drawWindow(ctx, x, y, w, h);
    drawFitText(ctx, itemName(q.id), x + 20, y + 16, 180, { size: 18, bold: true });
    drawText(ctx, q.mode === 'buy' ? '사기' : '팔기', x + w - 20, y + 18, { size: 15, align: 'right', color: COLORS.dim });
    const blink = Math.floor(this.t * 3) % 2 === 0;
    drawText(ctx, '◀', x + 40, y + 52, { size: 16, color: blink ? COLORS.accent : COLORS.dim });
    drawText(ctx, `× ${q.n}`, x + 110, y + 48, { size: 24, bold: true, align: 'center' });
    drawText(ctx, '▶', x + 170, y + 52, { size: 16, color: blink ? COLORS.accent : COLORS.dim });
    drawText(ctx, `${q.n * q.price} G`, x + w - 20, y + 52, { size: 19, align: 'right', color: COLORS.accent });
    drawText(ctx, `◀▶ ±1   ▲▼ ±10   (최대 ${q.max})`, x + w / 2, y + 98, { size: 13, align: 'center', color: COLORS.dim });
  }
}
