// 엔딩: 에필로그 → 스태프 롤 → THE END
import { Scene, WIDTH, HEIGHT } from '../../engine/game.js';
import { formatPlayTime } from '../../engine/state.js';
import { playBgm, sfx } from '../../engine/audio.js';
import { drawText, wrapText, FONT, COLORS } from '../window.js';
import { charName, josa, makeStars, drawStars, drawRedMoon, drawMountains } from './uiCommon.js';

const PAGES = [
  '마왕 자르가스가 쓰러지던 순간,\n하늘을 물들이던 붉은 달은\n조용히 빛을 잃고 사라졌다.',
  '길고 길었던 밤이 끝나고,\n대지에는 다시 아침이 찾아왔다.',
  `${josa(charName('mia'), '은', '는')} 신전으로 돌아가 사제가 되었다.\n오늘도 상처 입은 이들의 곁에서\n따스한 빛으로 기도를 올린다.`,
  `누명을 벗은 ${josa(charName('garen'), '은', '는')} 기사단으로 돌아갔다.\n다시는 누구도 잃지 않겠다는 맹세와 함께,\n그의 창은 이제 백성을 지킨다.`,
  `${josa(charName('sela'), '은', '는')} 스승이 남긴 별빛의 탑을 이었다.\n탑 꼭대기의 등불은\n밤마다 새로운 마법사들을 부른다.`,
  `그리고 ${josa(charName('ren'), '은', '는')} 루멘 마을로 돌아왔다.\n리나와 오웬 장로, 그리고 마을 사람들이\n환한 얼굴로 그를 맞이했다.`,
  '빛의 계승자의 이야기는\n노래가 되어 오래도록 전해졌다.',
];

const CREDITS = [
  ['title', '빛의 계승자'],
  ['sub', 'The Heir of Light'],
  ['gap'], ['gap'],
  ['role', '기획 / 총괄'], ['name', 'Orchestrator'], ['gap'],
  ['role', '필드'], ['name', 'field-dev'], ['gap'],
  ['role', '시나리오'], ['name', 'world-designer'], ['gap'],
  ['role', '전투'], ['name', 'battle-dev'], ['gap'],
  ['role', 'UI'], ['name', 'ui-dev'], ['gap'],
  ['role', '사운드'], ['name', 'sound-dev'], ['gap'],
  ['role', 'QA'], ['name', 'qa-tester'], ['gap'], ['gap'],
  ['role', '출연'],
  ['name', `${charName('ren')} · ${charName('mia')} · ${charName('garen')} · ${charName('sela')}`], ['gap'], ['gap'],
  ['sub', 'Made with a team of Claude agents'], ['gap'], ['gap'],
  ['name', 'Thank you for playing!'],
];
const LINE_H = { title: 48, sub: 32, role: 26, name: 34, gap: 20 };

export class EndingScene extends Scene {
  constructor(game, params) {
    super(game, params);
    this.opaque = true;
    this.t = 0;
    this.phase = 'pages'; // pages | credits | end
    this.page = 0;
    this.pageT = 0;
    this.scroll = 0;
    this.endT = 0;
    this.busy = false;
    this.stars = makeStars(150, 29, 320);
    this.creditsH = CREDITS.reduce((a, [k]) => a + LINE_H[k], 0);
    this._measure = document.createElement('canvas').getContext('2d');
  }

  enter() {
    playBgm('ending');
    this.game.fadeIn(1200);
  }

  // 0 = 밤, 1 = 새벽
  get dawn() {
    if (this.phase !== 'pages') return 1;
    if (this.page === 0) return 0;
    return Math.min(1, (this.page - 1 + Math.min(1, this.pageT / 2)) / 2);
  }

  update(dt) {
    this.t += dt;
    if (this.busy) return;
    const input = this.game.input;
    if (this.phase === 'pages') {
      this.pageT += dt;
      if (this.pageT > 0.8 && input.pressed('confirm')) {
        sfx('cursor');
        this._nextPage();
      }
    } else if (this.phase === 'credits') {
      const fast = input.held('confirm') ? 4 : 1;
      this.scroll += dt * 38 * fast;
      if (this.scroll > this.creditsH + HEIGHT) { this.phase = 'end'; this.endT = 0; }
    } else if (this.phase === 'end') {
      this.endT += dt;
      if (this.endT > 1.5 && input.pressed('confirm')) {
        sfx('confirm');
        this._toTitle();
      }
    }
  }

  async _nextPage() {
    this.busy = true;
    await this.game.fadeOut(350);
    if (this._dead) return;
    if (this.page < PAGES.length - 1) this.page += 1;
    else { this.phase = 'credits'; this.scroll = 0; }
    this.pageT = 0;
    this.game.fadeIn(350);
    this.busy = false;
  }

  async _toTitle() {
    this.busy = true;
    await this.game.fadeOut(1000);
    this.game.reset('title');
    this.game.fadeIn(800);
  }

  draw(ctx) {
    const d = this.dawn;
    // 밤 → 새벽 하늘
    const lerp = (a, b) => Math.round(a + (b - a) * d);
    const sky = ctx.createLinearGradient(0, 0, 0, HEIGHT);
    sky.addColorStop(0, `rgb(${lerp(3, 40)},${lerp(4, 60)},${lerp(12, 120)})`);
    sky.addColorStop(0.55, `rgb(${lerp(18, 170)},${lerp(12, 110)},${lerp(42, 150)})`);
    sky.addColorStop(0.8, `rgb(${lerp(58, 255)},${lerp(20, 180)},${lerp(48, 120)})`);
    sky.addColorStop(1, `rgb(${lerp(26, 255)},${lerp(10, 220)},${lerp(20, 160)})`);
    ctx.fillStyle = sky;
    ctx.fillRect(0, 0, WIDTH, HEIGHT);
    drawStars(ctx, this.stars, this.t, 1 - d);
    if (this.phase === 'pages' && this.page === 0) {
      drawRedMoon(ctx, 510, 100, 46, this.t, Math.max(0, 1 - this.pageT / 3));
    }
    // 떠오르는 해
    if (d > 0) {
      ctx.save();
      const sy = 420 - d * 70;
      const sun = ctx.createRadialGradient(320, sy, 10, 320, sy, 220);
      sun.addColorStop(0, `rgba(255,250,220,${0.9 * d})`);
      sun.addColorStop(0.2, `rgba(255,220,150,${0.5 * d})`);
      sun.addColorStop(1, 'rgba(255,200,120,0)');
      ctx.fillStyle = sun;
      ctx.fillRect(0, 0, WIDTH, HEIGHT);
      ctx.restore();
    }
    drawMountains(ctx, 380, `rgb(${lerp(28, 70)},${lerp(15, 50)},${lerp(37, 80)})`, 13, 60, 48);
    drawMountains(ctx, 420, `rgb(${lerp(14, 38)},${lerp(8, 30)},${lerp(20, 44)})`, 31, 30, 32);

    if (this.phase === 'pages') this._drawPage(ctx);
    else if (this.phase === 'credits') this._drawCredits(ctx);
    else this._drawEnd(ctx);
  }

  _drawPage(ctx) {
    const a = Math.min(1, this.pageT / 1.2);
    ctx.save();
    ctx.globalAlpha = a;
    ctx.fillStyle = 'rgba(0,0,10,0.35)';
    ctx.fillRect(0, 130, WIDTH, 170);
    const lines = [];
    for (const raw of PAGES[this.page].split('\n')) lines.push(...wrapText(this._measure, raw, 560, 21));
    const y0 = 215 - (lines.length * 34) / 2;
    lines.forEach((l, i) => drawText(ctx, l, WIDTH / 2, y0 + i * 34, { size: 21, align: 'center', color: '#fffaf0' }));
    ctx.restore();
    if (this.pageT > 1.2 && Math.floor(this.t * 2.5) % 2 === 0) {
      drawText(ctx, '▼', WIDTH / 2, 312, { size: 14, align: 'center', color: COLORS.accent });
    }
    drawText(ctx, `${this.page + 1} / ${PAGES.length}`, WIDTH - 20, HEIGHT - 26, { size: 12, align: 'right', color: 'rgba(255,255,255,0.6)' });
  }

  _drawCredits(ctx) {
    ctx.fillStyle = 'rgba(0,0,10,0.3)';
    ctx.fillRect(0, 0, WIDTH, HEIGHT);
    let y = HEIGHT - this.scroll;
    for (const [kind, text] of CREDITS) {
      const h = LINE_H[kind];
      if (text && y > -60 && y < HEIGHT + 10) {
        // 위아래 가장자리에서 흐려진다
        const edge = Math.min(1, Math.min(y, HEIGHT - y) / 60);
        ctx.save();
        ctx.globalAlpha = Math.max(0, edge);
        if (kind === 'title') {
          drawText(ctx, text, WIDTH / 2, y, { size: 36, bold: true, align: 'center', color: COLORS.accent });
        } else if (kind === 'sub') {
          ctx.font = 'italic 19px Georgia, serif';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'top';
          ctx.fillStyle = '#e8e0ff';
          ctx.fillText(text, WIDTH / 2, y);
        } else if (kind === 'role') {
          drawText(ctx, text, WIDTH / 2, y, { size: 15, align: 'center', color: '#ffe3a0' });
        } else {
          drawText(ctx, text, WIDTH / 2, y, { size: 22, bold: true, align: 'center' });
        }
        ctx.restore();
      }
      y += h;
    }
  }

  _drawEnd(ctx) {
    const a = Math.min(1, this.endT / 1.5);
    ctx.save();
    ctx.globalAlpha = a;
    ctx.fillStyle = 'rgba(0,0,10,0.35)';
    ctx.fillRect(0, 0, WIDTH, HEIGHT);
    ctx.font = 'bold 60px Georgia, "Times New Roman", serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.shadowColor = 'rgba(255,214,90,0.8)';
    ctx.shadowBlur = 20;
    ctx.fillStyle = '#fff4c8';
    ctx.fillText('THE END', WIDTH / 2, 190);
    ctx.shadowBlur = 0;
    ctx.font = FONT(18);
    ctx.fillStyle = '#ffffff';
    const pt = this.game.state ? formatPlayTime(this.game.state.playTime) : '-';
    ctx.fillText(`플레이 시간  ${pt}`, WIDTH / 2, 262);
    const lead = this.game.state?.members?.[this.game.state.party?.[0]];
    if (lead) ctx.fillText(`${charName(lead.id)}  Lv ${lead.level}`, WIDTH / 2, 292);
    ctx.restore();
    if (this.endT > 1.5 && Math.floor(this.t * 2) % 2 === 0) {
      drawText(ctx, '확인 버튼으로 타이틀로', WIDTH / 2, 372, { size: 15, align: 'center', color: COLORS.accent });
    }
  }
}
