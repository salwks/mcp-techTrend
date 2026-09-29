// 공용 UI: 창, 텍스트, 게이지, 커서, 메시지창, 선택지
import { WIDTH, HEIGHT } from '../engine/game.js';
import { sfx } from '../engine/audio.js';

export const COLORS = {
  text: '#ffffff',
  dim: '#8a93b8',
  disabled: '#6b7080',
  accent: '#ffd65a',
  hp: '#5ee07a',
  hpLow: '#ff6464',
  mp: '#5ab4ff',
  exp: '#ffb347',
  damage: '#ffffff',
  heal: '#7dffa0',
  windowTop: '#26357a',
  windowBottom: '#101a45',
  border: '#e8ecff',
  borderShadow: '#0a0f2a',
};

export const FONT_FAMILY = '"Noto Sans KR", "Apple SD Gothic Neo", "Malgun Gothic", sans-serif';

export function FONT(size = 18, bold = false) {
  return `${bold ? 'bold ' : ''}${size}px ${FONT_FAMILY}`;
}

export function drawWindow(ctx, x, y, w, h, opts = {}) {
  const alpha = opts.alpha ?? 0.94;
  ctx.save();
  ctx.globalAlpha = alpha;
  const g = ctx.createLinearGradient(0, y, 0, y + h);
  g.addColorStop(0, opts.top || COLORS.windowTop);
  g.addColorStop(1, opts.bottom || COLORS.windowBottom);
  ctx.fillStyle = g;
  roundRect(ctx, x, y, w, h, 6);
  ctx.fill();
  ctx.globalAlpha = 1;
  ctx.lineWidth = 3;
  ctx.strokeStyle = COLORS.borderShadow;
  roundRect(ctx, x + 1.5, y + 1.5, w - 3, h - 3, 5);
  ctx.stroke();
  ctx.lineWidth = 2;
  ctx.strokeStyle = COLORS.border;
  roundRect(ctx, x + 3, y + 3, w - 6, h - 6, 4);
  ctx.stroke();
  ctx.restore();
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

export function drawText(ctx, text, x, y, opts = {}) {
  const size = opts.size || 18;
  ctx.save();
  ctx.font = FONT(size, opts.bold);
  ctx.textAlign = opts.align || 'left';
  ctx.textBaseline = 'top';
  if (opts.shadow !== false) {
    ctx.fillStyle = 'rgba(0,0,0,0.7)';
    ctx.fillText(String(text), x + 1, y + 1);
  }
  ctx.fillStyle = opts.color || COLORS.text;
  ctx.fillText(String(text), x, y);
  ctx.restore();
}

// 한국어는 글자 단위, 공백이 있으면 단어 단위로 줄바꿈
export function wrapText(ctx, text, maxW, size = 18) {
  ctx.save();
  ctx.font = FONT(size);
  const lines = [];
  for (const para of String(text).split('\n')) {
    let line = '';
    const tokens = para.split(/(\s+)/);
    for (const tok of tokens) {
      if (!tok) continue;
      const trial = line + tok;
      if (ctx.measureText(trial).width <= maxW) { line = trial; continue; }
      if (line.trim()) { lines.push(line.trimEnd()); line = ''; }
      if (/^\s+$/.test(tok)) continue;
      // 토큰 자체가 너무 길면 글자 단위로 자른다
      for (const ch of tok) {
        if (ctx.measureText(line + ch).width > maxW && line) { lines.push(line); line = ''; }
        line += ch;
      }
    }
    lines.push(line);
  }
  ctx.restore();
  return lines;
}

export function drawGauge(ctx, x, y, w, h, ratio, color) {
  const r = Math.max(0, Math.min(1, ratio || 0));
  ctx.fillStyle = '#0b0f24';
  ctx.fillRect(x, y, w, h);
  ctx.fillStyle = color;
  ctx.fillRect(x + 1, y + 1, Math.round((w - 2) * r), h - 2);
  ctx.strokeStyle = 'rgba(255,255,255,0.35)';
  ctx.lineWidth = 1;
  ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
}

// 오른쪽을 가리키는 커서(삼각형). t: 시간(초) — 살짝 흔들린다
export function drawCursor(ctx, x, y, t = 0) {
  const dx = Math.round(Math.sin(t * 8) * 2);
  ctx.save();
  ctx.fillStyle = COLORS.accent;
  ctx.strokeStyle = '#000';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(x + dx, y);
  ctx.lineTo(x + dx + 10, y + 7);
  ctx.lineTo(x + dx, y + 14);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.restore();
}

// ---------------------------------------------------------------
// 메시지창: await msg.show(text, speaker)
// ---------------------------------------------------------------
const MSG_LINES = 3;
const MSG_SIZE = 20;

export class MessageWindow {
  constructor(opts = {}) {
    this.x = opts.x ?? 16;
    this.h = opts.h ?? 124;
    this.y = opts.y ?? HEIGHT - this.h - 12;
    this.w = opts.w ?? WIDTH - 32;
    this.speed = opts.speed ?? 45; // 초당 글자 수
    this.active = false;
    this.pages = [];
    this.page = 0;
    this.shown = 0;
    this.speaker = null;
    this.t = 0;
    this._resolve = null;
    this._measure = document.createElement('canvas').getContext('2d');
  }

  show(text, speaker = null) {
    const lines = wrapText(this._measure, text, this.w - 48, MSG_SIZE);
    this.pages = [];
    for (let i = 0; i < lines.length; i += MSG_LINES) this.pages.push(lines.slice(i, i + MSG_LINES));
    if (!this.pages.length) this.pages = [['']];
    this.page = 0;
    this.shown = 0;
    this.speaker = speaker;
    this.active = true;
    return new Promise((resolve) => { this._resolve = resolve; });
  }

  _pageLength() {
    return this.pages[this.page].join('').length;
  }

  update(dt, input) {
    if (!this.active) return;
    this.t += dt;
    const len = this._pageLength();
    if (this.shown < len) {
      this.shown = Math.min(len, this.shown + this.speed * dt);
      if (input.pressed('confirm') || input.pressed('cancel')) this.shown = len;
      return;
    }
    if (input.pressed('confirm') || input.pressed('cancel')) {
      if (this.page < this.pages.length - 1) {
        this.page += 1;
        this.shown = 0;
        sfx('cursor');
      } else {
        this.active = false;
        const r = this._resolve;
        this._resolve = null;
        if (r) r();
      }
    }
  }

  draw(ctx) {
    if (!this.active) return;
    drawWindow(ctx, this.x, this.y, this.w, this.h);
    if (this.speaker) {
      ctx.save();
      ctx.font = FONT(16, true);
      const sw = ctx.measureText(this.speaker).width + 24;
      ctx.restore();
      drawWindow(ctx, this.x + 8, this.y - 30, sw, 34);
      drawText(ctx, this.speaker, this.x + 20, this.y - 22, { size: 16, bold: true, color: COLORS.accent });
    }
    let remain = Math.floor(this.shown);
    const lines = this.pages[this.page];
    for (let i = 0; i < lines.length; i++) {
      const s = lines[i].slice(0, Math.max(0, remain));
      remain -= lines[i].length;
      drawText(ctx, s, this.x + 24, this.y + 18 + i * 30, { size: MSG_SIZE });
    }
    if (this.shown >= this._pageLength() && Math.floor(this.t * 3) % 2 === 0) {
      const cx = this.x + this.w - 26;
      const cy = this.y + this.h - 22;
      ctx.fillStyle = COLORS.accent;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(cx + 12, cy);
      ctx.lineTo(cx + 6, cy + 8);
      ctx.closePath();
      ctx.fill();
    }
  }
}

// ---------------------------------------------------------------
// 선택 목록: update(input) → 인덱스 | -1(취소) | null
// ---------------------------------------------------------------
export class ChoiceList {
  constructor(items, opts = {}) {
    this.items = items.map((it) => (typeof it === 'string' ? { label: it } : it));
    this.x = opts.x ?? 0;
    this.y = opts.y ?? 0;
    this.w = opts.w ?? 200;
    this.cols = opts.cols ?? 1;
    this.rowH = opts.rowH ?? 32;
    this.size = opts.size ?? 18;
    this.visibleRows = opts.visibleRows ?? null; // 스크롤
    this.cancelable = opts.cancelable ?? true;
    this.window = opts.window ?? true;
    this.index = opts.index ?? 0;
    this.scroll = 0;
    this.t = 0;
  }

  get rows() { return Math.ceil(this.items.length / this.cols); }
  get height() {
    const rows = this.visibleRows ? Math.min(this.visibleRows, this.rows) : this.rows;
    return rows * this.rowH + 24;
  }
  get current() { return this.items[this.index]; }

  setItems(items) {
    this.items = items.map((it) => (typeof it === 'string' ? { label: it } : it));
    this.index = Math.min(this.index, Math.max(0, this.items.length - 1));
  }

  update(input, dt = 1 / 60) {
    this.t += dt;
    const n = this.items.length;
    if (!n) {
      if (this.cancelable && input.pressed('cancel')) { sfx('cancel'); return -1; }
      return null;
    }
    const prev = this.index;
    if (this.cols === 1) {
      if (input.repeat('down')) this.index = (this.index + 1) % n;
      if (input.repeat('up')) this.index = (this.index - 1 + n) % n;
    } else {
      if (input.repeat('down') && this.index + this.cols < n) this.index += this.cols;
      if (input.repeat('up') && this.index - this.cols >= 0) this.index -= this.cols;
    }
    if (this.cols > 1) {
      if (input.repeat('right') && this.index % this.cols < this.cols - 1 && this.index + 1 < n) this.index += 1;
      if (input.repeat('left') && this.index % this.cols > 0) this.index -= 1;
    }
    if (prev !== this.index) sfx('cursor');
    if (this.visibleRows) {
      const row = Math.floor(this.index / this.cols);
      if (row < this.scroll) this.scroll = row;
      if (row >= this.scroll + this.visibleRows) this.scroll = row - this.visibleRows + 1;
    }
    if (input.pressed('confirm')) {
      if (this.items[this.index].disabled) { sfx('buzzer'); return null; }
      sfx('confirm');
      return this.index;
    }
    if (this.cancelable && input.pressed('cancel')) { sfx('cancel'); return -1; }
    return null;
  }

  draw(ctx, active = true) {
    if (this.window) drawWindow(ctx, this.x, this.y, this.w, this.height);
    const colW = (this.w - 24) / this.cols;
    const first = this.scroll * this.cols;
    const last = this.visibleRows ? Math.min(this.items.length, first + this.visibleRows * this.cols) : this.items.length;
    for (let i = first; i < last; i++) {
      const it = this.items[i];
      const r = Math.floor(i / this.cols) - this.scroll;
      const c = i % this.cols;
      const ix = this.x + 12 + c * colW;
      const iy = this.y + 12 + r * this.rowH;
      const color = it.disabled ? COLORS.disabled : (it.color || COLORS.text);
      drawText(ctx, it.label, ix + 22, iy + (this.rowH - this.size) / 2 - 1, { size: this.size, color });
      if (it.right != null) {
        drawText(ctx, it.right, ix + colW - 8, iy + (this.rowH - this.size) / 2 - 1, { size: this.size, color, align: 'right' });
      }
      if (i === this.index) {
        if (active) drawCursor(ctx, ix + 4, iy + this.rowH / 2 - 7, this.t);
        else drawCursor(ctx, ix + 4, iy + this.rowH / 2 - 7, 0);
      }
    }
    if (this.visibleRows) {
      ctx.fillStyle = COLORS.accent;
      if (this.scroll > 0) drawText(ctx, '▲', this.x + this.w - 22, this.y + 4, { size: 12 });
      if (last < this.items.length) drawText(ctx, '▼', this.x + this.w - 22, this.y + this.height - 18, { size: 12 });
    }
  }
}
