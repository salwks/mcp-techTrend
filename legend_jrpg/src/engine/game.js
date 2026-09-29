// 게임 루프, 씬 스택, 화면 연출(페이드/플래시/흔들림)
import { Input } from './input.js';

export const WIDTH = 640;
export const HEIGHT = 480;

export class Scene {
  constructor(game, params) {
    this.game = game;
    this.params = params || {};
    this.opaque = true;
  }
  enter() {}
  exit() {}
  update(dt) {}
  draw(ctx) {}
  finish(result) {
    this.game._finish(this, result);
  }
}

export class Game {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.input = new Input();
    this.state = null;
    this.time = 0;
    this.stack = [];
    this.factories = {};
    this.timers = [];
    this.fade = { alpha: 0, from: 0, to: 0, t: 0, dur: 0, resolve: null };
    this.flashFx = null;
    this.shakeFx = null;
    this.pixelRatio = 1;
    this._last = 0;
    this._resize();
    window.addEventListener('resize', () => this._resize());
  }

  _resize() {
    const ratio = Math.min(window.devicePixelRatio || 1, 2);
    this.pixelRatio = ratio;
    this.canvas.width = WIDTH * ratio;
    this.canvas.height = HEIGHT * ratio;
  }

  register(name, factory) {
    this.factories[name] = factory;
  }

  _create(name, params) {
    const factory = this.factories[name];
    if (!factory) throw new Error(`등록되지 않은 씬: ${name}`);
    return factory(this, params || {});
  }

  runScene(name, params) {
    return new Promise((resolve) => {
      const scene = this._create(name, params);
      scene._resolve = resolve;
      this.stack.push(scene);
      scene.enter();
    });
  }

  reset(name, params) {
    for (let i = this.stack.length - 1; i >= 0; i--) {
      const s = this.stack[i];
      s._resolve = null; // 버려진 씬의 Promise는 resolve하지 않는다
      s._dead = true;
      s.exit();
    }
    this.stack = [];
    const scene = this._create(name, params);
    this.stack.push(scene);
    scene.enter();
    return scene;
  }

  _finish(scene, result) {
    const idx = this.stack.indexOf(scene);
    if (idx < 0) return;
    this.stack.splice(idx, 1);
    scene._dead = true;
    scene.exit();
    const resolve = scene._resolve;
    scene._resolve = null;
    if (resolve) resolve(result);
  }

  get top() {
    return this.stack[this.stack.length - 1] || null;
  }

  wait(ms) {
    return new Promise((resolve) => this.timers.push({ at: this.time + ms / 1000, resolve }));
  }

  _fadeTo(to, ms) {
    return new Promise((resolve) => {
      if (this.fade.resolve) this.fade.resolve();
      this.fade = { alpha: this.fade.alpha, from: this.fade.alpha, to, t: 0, dur: Math.max(ms, 1) / 1000, resolve };
    });
  }
  fadeOut(ms = 300) { return this._fadeTo(1, ms); }
  fadeIn(ms = 300) { return this._fadeTo(0, ms); }

  flash(color = '#fff', ms = 200) {
    this.flashFx = { color, t: 0, dur: ms / 1000 };
  }
  shake(ms = 300, power = 6) {
    this.shakeFx = { t: 0, dur: ms / 1000, power };
  }

  start() {
    const loop = (now) => {
      const dt = Math.min(0.05, this._last ? (now - this._last) / 1000 : 0);
      this._last = now;
      try {
        this._tick(dt);
      } catch (err) {
        console.error(err);
      }
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  }

  _tick(dt) {
    this.time += dt;
    this.input.update(dt);

    // 타이머
    if (this.timers.length) {
      const due = this.timers.filter((t) => t.at <= this.time);
      this.timers = this.timers.filter((t) => t.at > this.time);
      due.forEach((t) => t.resolve());
    }

    // 페이드
    const f = this.fade;
    if (f.alpha !== f.to || f.resolve) {
      f.t += dt;
      const k = Math.min(1, f.t / f.dur);
      f.alpha = f.from + (f.to - f.from) * k;
      if (k >= 1 && f.resolve) {
        const r = f.resolve;
        f.resolve = null;
        r();
      }
    }

    const top = this.top;
    if (top) top.update(dt);
    if (this.state) this.state.playTime += dt;

    this._draw(dt);
    this.input.endFrame();
  }

  _draw(dt) {
    const ctx = this.ctx;
    ctx.setTransform(this.pixelRatio, 0, 0, this.pixelRatio, 0, 0);
    ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = '#000';
    ctx.fillRect(0, 0, WIDTH, HEIGHT);

    ctx.save();
    if (this.shakeFx) {
      const s = this.shakeFx;
      s.t += dt;
      if (s.t >= s.dur) this.shakeFx = null;
      else {
        const p = s.power * (1 - s.t / s.dur);
        ctx.translate(Math.round((Math.random() * 2 - 1) * p), Math.round((Math.random() * 2 - 1) * p));
      }
    }
    let start = 0;
    for (let i = this.stack.length - 1; i >= 0; i--) {
      if (this.stack[i].opaque) { start = i; break; }
    }
    for (let i = start; i < this.stack.length; i++) {
      ctx.save();
      this.stack[i].draw(ctx);
      ctx.restore();
    }
    ctx.restore();

    if (this.flashFx) {
      const fl = this.flashFx;
      fl.t += dt;
      if (fl.t >= fl.dur) this.flashFx = null;
      else {
        ctx.globalAlpha = 1 - fl.t / fl.dur;
        ctx.fillStyle = fl.color;
        ctx.fillRect(0, 0, WIDTH, HEIGHT);
        ctx.globalAlpha = 1;
      }
    }
    if (this.fade.alpha > 0) {
      ctx.globalAlpha = this.fade.alpha;
      ctx.fillStyle = '#000';
      ctx.fillRect(0, 0, WIDTH, HEIGHT);
      ctx.globalAlpha = 1;
    }
  }
}
