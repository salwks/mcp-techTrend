// 한지 두루마리 느낌의 대화창 (HTML 오버레이)
export class Dialog {
  constructor(root) {
    this.el = document.createElement('div');
    this.el.className = 'dialog';
    this.el.hidden = true;
    this.el.innerHTML = '<div class="d-name"></div><div class="d-text"></div><div class="d-next">▼</div>';
    root.appendChild(this.el);
    this.nameEl = this.el.querySelector('.d-name');
    this.textEl = this.el.querySelector('.d-text');
    this.lines = [];
    this.i = 0;
    this.shown = 0;
    this.onClose = null;
    this.el.addEventListener('pointerdown', (e) => { e.preventDefault(); this.advance(); });
  }

  get open() { return !this.el.hidden; }

  show(name, lines, onClose) {
    this.lines = lines;
    this.i = 0;
    this.shown = 0;
    this.onClose = onClose;
    this.nameEl.textContent = name || '';
    this.nameEl.hidden = !name;
    this.el.hidden = false;
    this._render();
  }

  _render() {
    const line = this.lines[this.i] || '';
    this.textEl.textContent = line.slice(0, Math.floor(this.shown));
    this.el.classList.toggle('done', this.shown >= line.length);
  }

  update(dt) {
    if (!this.open) return;
    const line = this.lines[this.i] || '';
    if (this.shown < line.length) { this.shown = Math.min(line.length, this.shown + dt * 32); this._render(); }
  }

  advance() {
    if (!this.open) return;
    const line = this.lines[this.i] || '';
    if (this.shown < line.length) { this.shown = line.length; this._render(); return; }
    this.i += 1;
    this.shown = 0;
    if (this.i >= this.lines.length) {
      this.el.hidden = true;
      const cb = this.onClose;
      this.onClose = null;
      if (cb) cb();
      return;
    }
    this._render();
  }
}

// 구역 이름 표시 (잠깐 떴다 사라짐)
export class PlaceBanner {
  constructor(root) {
    this.el = document.createElement('div');
    this.el.className = 'place';
    root.appendChild(this.el);
    this.last = null;
    this.timer = 0;
  }
  set(name) {
    if (!name || name === this.last) return;
    this.last = name;
    this.el.textContent = name;
    this.el.classList.remove('show');
    void this.el.offsetWidth;
    this.el.classList.add('show');
  }
}
