// 게임 오버: 붉게 어두워지는 화면과 선택지
import { Scene, WIDTH, HEIGHT } from '../../engine/game.js';
import { hasAnySave } from '../../engine/state.js';
import { playBgm } from '../../engine/audio.js';
import { ChoiceList, FONT } from '../window.js';
import { Flow } from './uiCommon.js';

export class GameOverScene extends Scene {
  constructor(game, params) {
    super(game, params);
    this.opaque = true;
    this.t = 0;
    this.flow = new Flow();
    this.list = null;
    this.busy = false;
    this.embers = [];
    for (let i = 0; i < 40; i++) this.embers.push({ x: Math.random() * WIDTH, y: Math.random() * HEIGHT, v: 8 + Math.random() * 20, p: Math.random() * 6 });
  }

  enter() {
    playBgm('sad');
    this.game.fadeIn(400);
    this.run().catch((e) => console.error(e));
  }

  update(dt) {
    this.t += dt;
    for (const e of this.embers) {
      e.y -= e.v * dt;
      if (e.y < -4) { e.y = HEIGHT + 4; e.x = Math.random() * WIDTH; }
    }
    if (!this.busy) this.flow.update(dt, this.game.input);
  }

  async run() {
    await this.flow.wait((input) => (this.t > 2.2 || (this.t > 0.6 && input.pressed('confirm')) ? true : undefined));
    if (this.t < 2.2) this.t = 2.2;
    while (!this._dead) {
      const canLoad = hasAnySave();
      this.list = new ChoiceList([
        { label: '마지막 기록에서 다시 하기', disabled: !canLoad },
        { label: '타이틀로' },
      ], { x: 180, y: 300, w: 280, cancelable: false, index: canLoad ? 0 : 1 });
      const i = await this.flow.choose(this.list);
      if (i === 0) {
        const r = await this.game.runScene('save', { mode: 'load' });
        if (r === 'loaded' || this._dead) return;
      } else if (i === 1) {
        this.busy = true;
        await this.game.fadeOut(600);
        this.game.state = null;
        this.game.reset('title');
        this.game.fadeIn(600);
        return;
      }
    }
  }

  draw(ctx) {
    const k = Math.min(1, this.t / 2);
    const g = ctx.createRadialGradient(WIDTH / 2, HEIGHT / 2, 40, WIDTH / 2, HEIGHT / 2, 420);
    g.addColorStop(0, `rgb(${Math.round(70 * k)},0,${Math.round(8 * k)})`);
    g.addColorStop(1, `rgb(${Math.round(18 * k)},0,0)`);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, WIDTH, HEIGHT);

    ctx.save();
    for (const e of this.embers) {
      ctx.globalAlpha = k * (0.25 + 0.25 * Math.sin(this.t * 2 + e.p));
      ctx.fillStyle = '#ff5a3a';
      ctx.fillRect(e.x, e.y, 2, 2);
    }
    ctx.restore();

    const a = Math.max(0, Math.min(1, (this.t - 0.6) / 1.2));
    ctx.save();
    ctx.globalAlpha = a;
    ctx.font = FONT(44, true);
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.shadowColor = 'rgba(255,40,40,0.9)';
    ctx.shadowBlur = 20;
    ctx.fillStyle = '#ffdede';
    ctx.fillText('전멸했다…', WIDTH / 2, 190 + (1 - a) * 10);
    ctx.shadowBlur = 0;
    ctx.font = FONT(16);
    ctx.fillStyle = 'rgba(255,200,200,0.7)';
    ctx.fillText('빛은 아직 꺼지지 않았다.', WIDTH / 2, 244);
    ctx.restore();

    if (this.list) this.list.draw(ctx, !this.busy);
  }
}
