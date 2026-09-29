// 키보드 + 모바일 가상 패드 입력
const KEYMAP = {
  ArrowUp: 'up', KeyW: 'up',
  ArrowDown: 'down', KeyS: 'down',
  ArrowLeft: 'left', KeyA: 'left',
  ArrowRight: 'right', KeyD: 'right',
  KeyZ: 'confirm', Enter: 'confirm', Space: 'confirm',
  KeyX: 'cancel', Backspace: 'cancel',
  Escape: 'menu', KeyM: 'menu', KeyC: 'menu',
};

const ACTIONS = ['up', 'down', 'left', 'right', 'confirm', 'cancel', 'menu'];
const REPEAT_DELAY = 0.35;
const REPEAT_RATE = 0.1;

export class Input {
  constructor() {
    this.down = {};      // 현재 눌림
    this.justDown = {};  // 이번 프레임에 눌림
    this.holdTime = {};
    this.repeatFired = {};
    this.sources = {};   // action -> Set(source)
    this.onFirstInput = null;
    ACTIONS.forEach((a) => { this.sources[a] = new Set(); this.holdTime[a] = 0; });

    window.addEventListener('keydown', (e) => {
      const a = KEYMAP[e.code];
      if (!a) return;
      e.preventDefault();
      if (e.repeat) return;
      this._press(a, 'key:' + e.code);
    });
    window.addEventListener('keyup', (e) => {
      const a = KEYMAP[e.code];
      if (!a) return;
      this._release(a, 'key:' + e.code);
    });
    window.addEventListener('blur', () => {
      ACTIONS.forEach((a) => { this.sources[a].clear(); this.down[a] = false; });
    });
  }

  _press(action, source) {
    if (this.onFirstInput) { const f = this.onFirstInput; this.onFirstInput = null; f(); }
    const set = this.sources[action];
    if (set.size === 0) {
      this.justDown[action] = true;
      this.holdTime[action] = 0;
      this.repeatFired[action] = false;
    }
    set.add(source);
    this.down[action] = true;
  }

  _release(action, source) {
    const set = this.sources[action];
    set.delete(source);
    if (set.size === 0) this.down[action] = false;
  }

  // 가상 패드(DOM 버튼)에서 호출
  setVirtual(action, isDown, id = 'pad') {
    if (isDown) this._press(action, 'v:' + id);
    else this._release(action, 'v:' + id);
  }

  update(dt) {
    ACTIONS.forEach((a) => {
      this.repeatFired[a] = false;
      if (this.down[a]) {
        const before = this.holdTime[a];
        this.holdTime[a] += dt;
        if (before >= REPEAT_DELAY) {
          const n0 = Math.floor((before - REPEAT_DELAY) / REPEAT_RATE);
          const n1 = Math.floor((this.holdTime[a] - REPEAT_DELAY) / REPEAT_RATE);
          if (n1 > n0) this.repeatFired[a] = true;
        } else if (this.holdTime[a] >= REPEAT_DELAY) {
          this.repeatFired[a] = true;
        }
      }
    });
  }

  endFrame() {
    this.justDown = {};
  }

  pressed(a) { return !!this.justDown[a]; }
  held(a) { return !!this.down[a]; }
  repeat(a) { return !!this.justDown[a] || !!this.repeatFired[a]; }

  // 씬 전환 직후 입력이 새어 들어가지 않게 할 때 사용
  consume() { this.justDown = {}; }
}
