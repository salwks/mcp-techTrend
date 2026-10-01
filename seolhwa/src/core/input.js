// 키보드 + 모바일 가상 조이스틱. 이동은 카메라 기준(화면 위 = 북쪽 -z)
const KEYS = {
  ArrowUp: 'up', KeyW: 'up', ArrowDown: 'down', KeyS: 'down',
  ArrowLeft: 'left', KeyA: 'left', ArrowRight: 'right', KeyD: 'right',
  ShiftLeft: 'run', ShiftRight: 'run',
  KeyE: 'act', Space: 'act', Enter: 'act', KeyZ: 'act',
  Tab: 'panel', KeyN: 'time', Escape: 'cancel', KeyX: 'cancel',
  KeyJ: 'attack', KeyK: 'dodge', KeyL: 'guard', KeyI: 'bow', KeyU: 'item', KeyR: 'journal',
};

export class Input {
  constructor(root) {
    this.down = new Set();
    this.pressedSet = new Set();
    this.releasedSet = new Set();
    this.stick = { x: 0, y: 0, active: false };
    this.runToggle = false;
    window.addEventListener('keydown', (e) => {
      if (e.target.closest && e.target.closest('input, select, textarea, button')) return;
      const a = KEYS[e.code];
      if (!a) return;
      e.preventDefault();
      if (!e.repeat) this.pressedSet.add(a);
      this.down.add(a);
    });
    window.addEventListener('keyup', (e) => {
      const a = KEYS[e.code];
      if (a && this.down.has(a)) { this.down.delete(a); this.releasedSet.add(a); }
    });
    window.addEventListener('blur', () => { for (const a of this.down) this.releasedSet.add(a); this.down.clear(); });
    this._buildTouch(root);
  }

  _buildTouch(root) {
    const pad = document.createElement('div');
    pad.className = 'touch';
    pad.innerHTML = `
      <div class="stick-zone"><div class="stick-base"><div class="stick-knob"></div></div></div>
      <div class="touch-btns">
        <button class="tbtn" data-a="run" aria-label="달리기">달리기</button>
        <button class="tbtn big" data-a="act" aria-label="조사">조사</button>
      </div>
      <div class="combat-btns">
        <button class="tbtn" data-hold="bow" aria-label="활">활</button>
        <button class="tbtn" data-hold="item" aria-label="떡 던지기">떡</button>
        <button class="tbtn" data-hold="guard" aria-label="방어">방어</button>
        <button class="tbtn" data-hold="dodge" aria-label="회피">회피</button>
        <button class="tbtn big" data-hold="attack" aria-label="공격">공격</button>
      </div>`;
    root.appendChild(pad);
    const zone = pad.querySelector('.stick-zone');
    const base = pad.querySelector('.stick-base');
    const knob = pad.querySelector('.stick-knob');
    let pid = null, cx = 0, cy = 0;
    const R = 46;
    const move = (e) => {
      let dx = e.clientX - cx, dy = e.clientY - cy;
      const len = Math.hypot(dx, dy);
      if (len > R) { dx *= R / len; dy *= R / len; }
      knob.style.transform = `translate(${dx}px, ${dy}px)`;
      this.stick.x = dx / R;
      this.stick.y = dy / R;
    };
    zone.addEventListener('pointerdown', (e) => {
      pid = e.pointerId;
      zone.setPointerCapture(pid);
      const r = base.getBoundingClientRect();
      cx = r.left + r.width / 2; cy = r.top + r.height / 2;
      this.stick.active = true;
      move(e);
    });
    zone.addEventListener('pointermove', (e) => { if (e.pointerId === pid) move(e); });
    const end = (e) => {
      if (e.pointerId !== pid) return;
      pid = null;
      this.stick = { x: 0, y: 0, active: false };
      knob.style.transform = '';
    };
    zone.addEventListener('pointerup', end);
    zone.addEventListener('pointercancel', end);
    pad.querySelectorAll('[data-hold]').forEach((b) => {
      const a = b.dataset.hold;
      const on = (e) => { e.preventDefault(); b.setPointerCapture?.(e.pointerId); b.classList.add('on'); this.pressedSet.add(a); this.down.add(a); };
      const off = (e) => { e.preventDefault(); if (!b.classList.contains('on')) return; b.classList.remove('on'); this.down.delete(a); this.releasedSet.add(a); };
      b.addEventListener('pointerdown', on);
      b.addEventListener('pointerup', off);
      b.addEventListener('pointercancel', off);
      b.addEventListener('contextmenu', (e) => e.preventDefault());
    });
    this.pad = pad;
    pad.querySelectorAll('[data-a]').forEach((b) => {
      b.addEventListener('pointerdown', (e) => {
        e.preventDefault();
        const a = b.dataset.a;
        if (a === 'run') { this.runToggle = !this.runToggle; b.classList.toggle('on', this.runToggle); }
        else this.pressedSet.add(a);
      });
    });
  }

  // 이동 벡터 (x: 동+, z: 남+) 길이 0~1
  moveVector() {
    let x = 0, z = 0;
    if (this.down.has('left')) x -= 1;
    if (this.down.has('right')) x += 1;
    if (this.down.has('up')) z -= 1;
    if (this.down.has('down')) z += 1;
    if (x || z) { const l = Math.hypot(x, z); return { x: x / l, z: z / l }; }
    if (this.stick.active) {
      const l = Math.hypot(this.stick.x, this.stick.y);
      if (l > 0.15) return { x: this.stick.x, z: this.stick.y, mag: Math.min(1, l) };
    }
    return { x: 0, z: 0 };
  }

  running() {
    return this.down.has('run') || this.runToggle || (this.stick.active && Math.hypot(this.stick.x, this.stick.y) > 0.95);
  }

  pressed(a) { return this.pressedSet.has(a); }
  held(a) { return this.down.has(a); }
  released(a) { return this.releasedSet.has(a); }
  setCombat(on) { this.pad.classList.toggle('in-combat', on); }
  endFrame() { this.pressedSet.clear(); this.releasedSet.clear(); }
}
