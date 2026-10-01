// 전투 HUD: 붓획 게이지(체력·기력), 호랑이 체력, 화살·떡, 상황 문구, 결말 화면
export class Hud {
  constructor(root) {
    const el = document.createElement('div');
    el.className = 'chud';
    el.hidden = true;
    el.innerHTML = `
      <div class="ch-me">
        <div class="ch-bar hp"><span class="ch-label">체력</span><i><b></b></i></div>
        <div class="ch-bar st"><span class="ch-label">기력</span><i><b></b></i></div>
        <div class="ch-ammo"><span class="ch-arrows"></span><span class="ch-bait"></span></div>
      </div>
      <div class="ch-foe" hidden><span class="ch-foe-name"></span><i><b></b><s></s></i></div>
      <div class="ch-say" aria-live="polite"></div>
      <div class="ch-keys">공격 J · 모아베기 J 길게 · 회피 K · 방어 L · 활 I · 떡 U</div>
      <div class="ch-result" hidden>
        <div class="ch-card">
          <div class="ch-kind"></div>
          <h2 class="ch-title"></h2>
          <p class="ch-text"></p>
          <button type="button" class="ch-retry">다시 하기</button>
        </div>
      </div>`;
    root.appendChild(el);
    this.el = el;
    const $ = (s) => el.querySelector(s);
    this.hpB = $('.hp b');
    this.stB = $('.st b');
    this.stBar = $('.st');
    this.arrows = $('.ch-arrows');
    this.bait = $('.ch-bait');
    this.foe = $('.ch-foe');
    this.foeName = $('.ch-foe-name');
    this.foeB = $('.ch-foe b');
    this.foeLag = $('.ch-foe s');
    this.sayEl = $('.ch-say');
    this.resEl = $('.ch-result');
    this.last = {};
    this.sayTimer = null;
    this.lagRatio = 1;
    this.foeRatio = 1;
  }

  combatMode(on) {
    this.el.hidden = !on;
    document.body.classList.toggle('in-combat', on);
  }

  setPlayer(hp, maxHp, st, maxSt) {
    const h = Math.max(0, hp / maxHp), s = Math.max(0, st / maxSt);
    if (h !== this.last.h) { this.hpB.style.transform = `scaleX(${h})`; this.last.h = h; }
    if (s !== this.last.s) { this.stB.style.transform = `scaleX(${s})`; this.stBar.classList.toggle('low', s < 0.25); this.last.s = s; }
  }

  setFoe(name, hp, maxHp) {
    if (!name) { this.foe.hidden = true; return; }
    this.foe.hidden = false;
    if (this.foeName.textContent !== name) this.foeName.textContent = name;
    const r = Math.max(0, hp / maxHp);
    if (r !== this.foeRatio) { this.foeB.style.transform = `scaleX(${r})`; this.foeRatio = r; }
  }

  // 피해 잔상(늦게 따라오는 막대)
  tick(dt) {
    if (this.foe.hidden) return;
    if (this.lagRatio > this.foeRatio) this.lagRatio = Math.max(this.foeRatio, this.lagRatio - dt * 0.35);
    else this.lagRatio = this.foeRatio;
    this.foeLag.style.transform = `scaleX(${this.lagRatio})`;
  }

  setAmmo({ arrows, bait }) {
    const a = `화살 ${arrows}`, b = `떡 ${bait}`;
    if (this.arrows.textContent !== a) this.arrows.textContent = a;
    if (this.bait.textContent !== b) this.bait.textContent = b;
  }

  say(text, ms = 2200) {
    this.sayEl.textContent = text;
    this.sayEl.classList.remove('show');
    void this.sayEl.offsetWidth;
    this.sayEl.classList.add('show');
    clearTimeout(this.sayTimer);
    this.sayTimer = setTimeout(() => this.sayEl.classList.remove('show'), ms);
  }

  result(kind, title, text) {
    const labels = { win: '처치', repelled: '물러나게 함', retreated: '물러남', escaped: '도망', lose: '패배' };
    this.resEl.querySelector('.ch-kind').textContent = labels[kind] || kind;
    this.resEl.querySelector('.ch-title').textContent = title;
    this.resEl.querySelector('.ch-text').textContent = text || '';
    this.resEl.dataset.kind = kind;
    this.resEl.hidden = false;
    const btn = this.resEl.querySelector('.ch-retry');
    btn.focus({ preventScroll: true });
    return new Promise((resolve) => {
      const done = () => {
        window.removeEventListener('keydown', key);
        btn.removeEventListener('click', done);
        this.resEl.hidden = true;
        resolve();
      };
      const key = (e) => { if (['Enter', 'Space', 'KeyJ', 'KeyE'].includes(e.code)) { e.preventDefault(); done(); } };
      btn.addEventListener('click', done);
      setTimeout(() => window.addEventListener('keydown', key), 600);
    });
  }

  get resultOpen() { return !this.resEl.hidden; }
}
