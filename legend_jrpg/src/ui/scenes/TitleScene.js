// 타이틀 화면: 붉은 달이 뜬 밤하늘, 성검과 마왕성의 실루엣
import { Scene, WIDTH, HEIGHT } from '../../engine/game.js';
import { GameState, hasAnySave } from '../../engine/state.js';
import { playBgm } from '../../engine/audio.js';
import { ChoiceList, drawText, FONT } from '../window.js';
import { Flow, makeStars, drawStars, drawRedMoon, drawMountains } from './uiCommon.js';

export class TitleScene extends Scene {
  constructor(game, params) {
    super(game, params);
    this.opaque = true;
    this.t = 0;
    this.flow = new Flow();
    this.stars = makeStars(170, 11, 300);
    this.motes = [];
    for (let i = 0; i < 26; i++) this.motes.push(this._mote(true));
    this.showMenu = false;
    this.busy = false;
  }

  _mote(initial) {
    return {
      x: 118 + (Math.random() - 0.5) * 70,
      y: initial ? 250 + Math.random() * 150 : 390 + Math.random() * 10,
      vy: 12 + Math.random() * 18,
      ph: Math.random() * 6.28,
      life: initial ? Math.random() : 0,
    };
  }

  enter() {
    playBgm('title');
    this.run();
  }

  async run() {
    // 인트로: 시간이 지나거나 아무 버튼이나 누르면 메뉴 표시
    await this.flow.wait((input) => {
      if (this.t > 1.6 || ['confirm', 'cancel', 'menu'].some((a) => input.pressed(a))) return true;
      return undefined;
    });
    this.showMenu = true;
    while (!this._dead) {
      const canLoad = hasAnySave();
      this.list = new ChoiceList(
        [{ label: '새로운 모험' }, { label: '이어하기', disabled: !canLoad }],
        { x: 220, y: 318, w: 200, cancelable: false, index: this.list ? this.list.index : (canLoad ? 1 : 0) },
      );
      const i = await this.flow.choose(this.list);
      if (i === 0) {
        this.busy = true;
        this.game.state = GameState.newGame();
        await this.game.fadeOut(700);
        this.game.reset('field', {});
        this.game.fadeIn(600);
        return;
      }
      if (i === 1) {
        const r = await this.game.runScene('save', { mode: 'load' });
        if (r === 'loaded' || this._dead) return;
      }
    }
  }

  update(dt) {
    this.t += dt;
    for (const m of this.motes) {
      m.y -= m.vy * dt;
      m.life += dt * 0.35;
      if (m.life >= 1 || m.y < 180) Object.assign(m, this._mote(false));
    }
    if (!this.busy) this.flow.update(dt, this.game.input);
  }

  draw(ctx) {
    const t = this.t;
    // 하늘
    const sky = ctx.createLinearGradient(0, 0, 0, HEIGHT);
    sky.addColorStop(0, '#03040c');
    sky.addColorStop(0.45, '#120c2a');
    sky.addColorStop(0.72, '#3a1430');
    sky.addColorStop(1, '#1a0a14');
    ctx.fillStyle = sky;
    ctx.fillRect(0, 0, WIDTH, HEIGHT);
    drawStars(ctx, this.stars, t);

    // 붉은 달 + 흘러가는 구름
    drawRedMoon(ctx, 520, 104, 50, t);
    ctx.save();
    for (let i = 0; i < 4; i++) {
      const cx = ((t * (6 + i * 3) + i * 190) % 900) - 130;
      const cy = 70 + i * 34;
      ctx.fillStyle = `rgba(20,8,24,${0.55 - i * 0.08})`;
      ctx.beginPath();
      ctx.ellipse(cx, cy, 90 - i * 8, 9 + i, 0, 0, Math.PI * 2);
      ctx.ellipse(cx + 40, cy - 5, 50, 7, 0, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();

    // 산 실루엣
    drawMountains(ctx, 330, '#1c0f25', 5, 70, 48);
    this._drawCastle(ctx, 505, 322);
    drawMountains(ctx, 375, '#110816', 23, 40, 36);

    // 전경 언덕 + 성검
    ctx.fillStyle = '#07040a';
    ctx.beginPath();
    ctx.moveTo(0, HEIGHT);
    ctx.lineTo(0, 400);
    ctx.quadraticCurveTo(110, 360, 240, 412);
    ctx.quadraticCurveTo(420, 460, 640, 430);
    ctx.lineTo(640, HEIGHT);
    ctx.closePath();
    ctx.fill();
    this._drawSword(ctx, 118, 392, t);

    // 빛 입자
    ctx.save();
    for (const m of this.motes) {
      const a = Math.sin(m.life * Math.PI) * 0.9;
      ctx.globalAlpha = Math.max(0, a);
      ctx.fillStyle = '#ffe9a0';
      ctx.fillRect(m.x + Math.sin(t * 2 + m.ph) * 6, m.y, 2, 2);
    }
    ctx.restore();

    // 타이틀 로고
    const intro = Math.min(1, t / 1.4);
    ctx.save();
    ctx.globalAlpha = intro;
    ctx.font = FONT(64, true);
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    const ty = 150 - (1 - intro) * 14;
    ctx.shadowColor = 'rgba(255,200,90,0.8)';
    ctx.shadowBlur = 18 + Math.sin(t * 2) * 6;
    const g = ctx.createLinearGradient(0, ty - 34, 0, ty + 34);
    g.addColorStop(0, '#fff8d8');
    g.addColorStop(0.5, '#ffd65a');
    g.addColorStop(1, '#c47a1a');
    ctx.fillStyle = g;
    ctx.fillText('빛의 계승자', WIDTH / 2, ty);
    ctx.shadowBlur = 0;
    ctx.lineWidth = 1.5;
    ctx.strokeStyle = 'rgba(80,30,0,0.8)';
    ctx.strokeText('빛의 계승자', WIDTH / 2, ty);
    // 장식선
    ctx.fillStyle = 'rgba(255,214,90,0.7)';
    ctx.fillRect(WIDTH / 2 - 150, ty + 44, 110, 1);
    ctx.fillRect(WIDTH / 2 + 40, ty + 44, 110, 1);
    ctx.beginPath();
    ctx.moveTo(WIDTH / 2, ty + 38);
    ctx.lineTo(WIDTH / 2 + 6, ty + 44.5);
    ctx.lineTo(WIDTH / 2, ty + 51);
    ctx.lineTo(WIDTH / 2 - 6, ty + 44.5);
    ctx.fill();
    ctx.font = 'italic 20px Georgia, "Times New Roman", serif';
    ctx.fillStyle = '#e8d8ff';
    ctx.shadowColor = 'rgba(0,0,0,0.8)';
    ctx.shadowBlur = 4;
    ctx.fillText('T h e   H e i r   o f   L i g h t', WIDTH / 2, ty + 72);
    ctx.restore();

    if (this.showMenu && this.list) {
      this.list.draw(ctx, !this.busy);
    } else if (t > 0.8) {
      const a = 0.5 + 0.5 * Math.sin(t * 4);
      ctx.save();
      ctx.globalAlpha = a;
      drawText(ctx, 'PRESS START', WIDTH / 2, 350, { size: 18, bold: true, align: 'center', color: '#ffe9a0' });
      ctx.restore();
    }
    drawText(ctx, '© 2026 Team of Claude Agents', WIDTH / 2, 456, { size: 12, align: 'center', color: '#8a7a9a' });
  }

  _drawCastle(ctx, cx, base) {
    ctx.save();
    ctx.fillStyle = '#12091a';
    const towers = [[-70, 60, 14], [-40, 88, 18], [0, 128, 24], [40, 96, 18], [72, 62, 14]];
    ctx.fillRect(cx - 80, base - 44, 160, 44);
    for (const [dx, h, w] of towers) {
      ctx.fillRect(cx + dx - w / 2, base - h, w, h);
      ctx.beginPath();
      ctx.moveTo(cx + dx - w / 2 - 3, base - h);
      ctx.lineTo(cx + dx, base - h - w * 1.3);
      ctx.lineTo(cx + dx + w / 2 + 3, base - h);
      ctx.fill();
    }
    // 흉벽
    for (let x = cx - 80; x < cx + 80; x += 10) ctx.fillRect(x, base - 50, 5, 6);
    // 붉게 빛나는 창
    const flick = 0.6 + 0.4 * Math.sin(this.t * 3.1);
    ctx.fillStyle = `rgba(255,70,50,${0.55 * flick + 0.2})`;
    for (const [dx, dy] of [[0, 90], [0, 70], [-40, 60], [40, 66], [-70, 40], [72, 40], [-20, 26], [22, 26]]) {
      ctx.fillRect(cx + dx - 1.5, base - dy, 3, 5);
    }
    ctx.restore();
  }

  _drawSword(ctx, x, groundY, t) {
    ctx.save();
    // 후광
    const pulse = 0.5 + 0.5 * Math.sin(t * 1.7);
    const halo = ctx.createRadialGradient(x, groundY - 90, 4, x, groundY - 90, 90);
    halo.addColorStop(0, `rgba(255,236,160,${0.28 + 0.14 * pulse})`);
    halo.addColorStop(1, 'rgba(255,236,160,0)');
    ctx.fillStyle = halo;
    ctx.fillRect(x - 100, groundY - 190, 200, 200);
    // 칼날(땅에 박힘)
    ctx.fillStyle = '#0c0810';
    ctx.beginPath();
    ctx.moveTo(x - 6, groundY - 118);
    ctx.lineTo(x + 6, groundY - 118);
    ctx.lineTo(x + 5, groundY - 4);
    ctx.lineTo(x, groundY + 6);
    ctx.lineTo(x - 5, groundY - 4);
    ctx.closePath();
    ctx.fill();
    // 코등이, 손잡이, 폼멜
    ctx.fillRect(x - 26, groundY - 126, 52, 8);
    ctx.fillRect(x - 3.5, groundY - 156, 7, 30);
    ctx.beginPath();
    ctx.arc(x, groundY - 160, 6, 0, Math.PI * 2);
    ctx.fill();
    // 윤곽 빛
    ctx.strokeStyle = `rgba(255,220,130,${0.35 + 0.35 * pulse})`;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x + 6, groundY - 118);
    ctx.lineTo(x + 5, groundY - 4);
    ctx.moveTo(x - 26, groundY - 126);
    ctx.lineTo(x + 26, groundY - 126);
    ctx.stroke();
    // 반짝임
    const sp = (t * 0.6) % 3;
    if (sp < 0.6) {
      const k = Math.sin((sp / 0.6) * Math.PI);
      const sy = groundY - 118 + (sp / 0.6) * 100;
      ctx.fillStyle = `rgba(255,255,230,${k})`;
      ctx.fillRect(x - 10 * k, sy, 20 * k, 1.5);
      ctx.fillRect(x - 0.75, sy - 10 * k, 1.5, 20 * k);
    }
    // 보석
    ctx.fillStyle = `rgba(120,200,255,${0.6 + 0.4 * pulse})`;
    ctx.beginPath();
    ctx.arc(x, groundY - 122, 2.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
}

