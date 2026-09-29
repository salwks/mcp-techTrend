// 정면 시점 턴제 전투 씬 (battle-dev)
// params: { troop, canEscape=true, bg='plains', bgm } → finish('win' | 'lose' | 'escape')
import { Scene, WIDTH, HEIGHT } from '../engine/game.js';
import { sfx, playBgm } from '../engine/audio.js';
import { MessageWindow, ChoiceList, drawWindow, drawText, drawGauge, drawCursor, COLORS } from '../ui/window.js';
import { ITEMS } from '../data/items.js';
import { SKILLS } from '../data/skills.js';
import { TROOPS } from '../data/troops.js';
import { CHARACTERS } from '../data/characters.js';
import { BattleCore } from './core.js';
import { josa } from './formulas.js';
import { drawBackground, drawBgOverlay } from './backgrounds.js';
import { getSprite } from './enemySprites.js';

const BASELINE = 336;       // 적 발밑 y
const PANEL_Y = 372;
const PANEL_H = 100;
const PANEL_W = 150;
const CMD_Y = 204;
const ELEMENT_SFX = { fire: 'fire', ice: 'ice', thunder: 'thunder', holy: 'holy' };
const ELEMENT_COLOR = { fire: '#ff7a30', ice: '#80e0ff', thunder: '#ffe040', holy: '#fff6c0' };
const STATUS_TAG = { poison: ['독', '#b060ff'], sleep: ['잠', '#60a0ff'], stun: ['기절', '#ffb040'] };

export class BattleScene extends Scene {
  constructor(game, params) {
    super(game, params);
    this.opaque = true;
    const p = this.params;
    this.troop = typeof p.troop === 'string' ? TROOPS[p.troop] : p.troop;
    if (!this.troop) {
      console.warn('알 수 없는 troop', p.troop);
      this.troop = { enemies: ['slime'] };
    }
    this.bg = p.bg || 'plains';
    this.t = 0;
    this.lines = ['', ''];
    this.popups = [];
    this.fx = [];
    this.mode = 'intro';
    this.introT = 0;
    this.msg = new MessageWindow({ y: 8, h: 112 });
    this.lastCmd = {};
    this.lastSkill = {};
    this.lastItem = 0;
  }

  enter() {
    const state = this.game.state;
    this.core = new BattleCore(state, this.troop, { canEscape: this.params.canEscape !== false });
    this.canEscape = this.core.canEscape;
    this._layoutEnemies();
    for (const b of this.core.party) { b.panelShake = 0; b.panelFlash = 0; }
    playBgm(this.params.bgm || this.troop.bgm || (this.troop.boss ? 'boss' : 'battle'));
    sfx('encounter');
    this._main().catch((e) => { console.error(e); this._done('escape'); });
  }

  exit() {}

  // ------------------------------------------------------------------
  // 배치
  _layoutEnemies() {
    const es = this.core.enemies;
    // 보스는 2배, 일반 적은 폭 170px 정도까지 최대 3배로 확대
    const zooms = es.map((e) => { const w = getSprite(e.data.sprite, e.data.palette, 0).w; return Math.min(3, Math.max(2, (e.boss ? 200 : 170) / w)); });
    const widths = es.map((e, i) => getSprite(e.data.sprite, e.data.palette, 0).w * zooms[i]);
    const gap = 18;
    let total = widths.reduce((s, w) => s + w, 0) + gap * (es.length - 1);
    let scale = total > 612 ? 612 / total : 1;
    // 키 큰 보스는 윗부분이 메시지 창에 너무 가리지 않도록
    const maxH = Math.max(...es.map((e, i) => getSprite(e.data.sprite, e.data.palette, 0).h * zooms[i]));
    if (maxH * scale > BASELINE - 52) scale = (BASELINE - 52) / maxH;
    total *= scale;
    let x = (WIDTH - total) / 2;
    es.forEach((e, i) => {
      const w = widths[i] * scale;
      e.scale = scale * zooms[i] / 2;
      e.x = x + w / 2;
      e.y = BASELINE;
      e.flash = 0; e.dieT = -1; e.lunge = 0; e.shakeX = 0;
      e.phaseSeed = i * 1.7;
      x += w + gap * scale;
    });
  }

  _enemyRect(e) {
    const spr = getSprite(e.data.sprite, e.data.palette, 0);
    const w = spr.w * 2 * e.scale;
    const h = spr.h * 2 * e.scale;
    return { x: e.x - w / 2, y: e.y - h, w, h, cx: e.x, cy: e.y - h / 2 };
  }

  _panelRect(b) {
    const n = this.core.party.length;
    const gap = 6;
    const total = n * PANEL_W + (n - 1) * gap;
    const x = (WIDTH - total) / 2 + b.idx * (PANEL_W + gap);
    return { x, y: PANEL_Y, w: PANEL_W, h: PANEL_H, cx: x + PANEL_W / 2, cy: PANEL_Y + 30 };
  }

  _anchor(b) {
    if (b.isParty) { const r = this._panelRect(b); return { x: r.cx, y: r.y - 6 }; }
    const r = this._enemyRect(b);
    return { x: r.cx, y: r.cy };
  }

  // ------------------------------------------------------------------
  // 흐름
  async _main() {
    await this.game.wait(650);
    this.mode = 'busy';
    this.lines = [this.core.introText(), ''];
    await this._pause(1100);
    for (;;) {
      const cmd = await this._commandPhase();
      this.mode = 'busy';
      this.active = null;
      let order;
      if (cmd.escape) {
        this.lines = [`${this._leaderName()} 일행은 도망치려 했다!`, ''];
        sfx('escape');
        await this._pause(500);
        if (this.core.tryEscape()) {
          this.escaping = 0.001;
          this.lines = [`${this._leaderName()} 일행은 무사히 도망쳤다!`, ''];
          await this._pause(900);
          this.core.finalize();
          this._done('escape');
          return;
        }
        this._pushLine('그러나 앞을 가로막혔다!');
        sfx('buzzer');
        await this._pause(700);
        order = this.core.buildRound([]);
      } else {
        order = this.core.buildRound(cmd.actions);
      }
      for (const a of order) {
        const ev = this.core.execute(a);
        if (ev.length) await this._play(ev);
        if (this.core.outcome()) break;
      }
      if (!this.core.outcome()) {
        const ev = this.core.endRound();
        if (ev.length) await this._play(ev);
      }
      const out = this.core.outcome();
      if (out === 'win') { await this._victory(); return; }
      if (out === 'lose') { await this._defeat(); return; }
    }
  }

  _leaderName() {
    const lead = this.core.aliveParty()[0] || this.core.party[0];
    return lead.name;
  }

  _done(result) {
    if (this._finished) return;
    this._finished = true;
    this.finish(result);
  }

  async _victory() {
    await this._pause(400);
    this.core.finalize();
    const state = this.game.state;
    if (this.troop.quickEnd) {
      await this._pause(500);
      this._done('win');
      return;
    }
    const { exp, gold, drops } = this.core.rewards();
    playBgm('victory');
    this.lines = ['', ''];
    this.mode = 'result';
    state.gold += gold;
    let text = '전투에 승리했다!';
    if (exp > 0 || gold > 0) text += `\n경험치 ${exp} 포인트와 ${gold} 골드를 얻었다!`;
    await this.msg.show(text);
    for (const it of drops) {
      const item = ITEMS[it];
      if (!item) continue;
      state.addItem(it, 1);
      sfx('item');
      await this.msg.show(`적이 ${josa(item.name, '을')} 떨어뜨렸다!\n${josa(item.name, '을')} 손에 넣었다!`);
    }
    if (exp > 0) {
      for (const b of this.core.party) {
        if (!b.alive) continue;
        const ups = state.gainExp(b.id, exp);
        for (const up of ups) {
          sfx('levelup');
          b.maxHp = state.getStats(b.id).maxHp;
          b.maxMp = state.getStats(b.id).maxMp;
          b.panelFlash = 0.8;
          await this.msg.show(`${josa(b.name, '은')} ${josa(`레벨 ${up.level}`, '이')} 되었다!`);
          for (const sk of up.skills) {
            const s = SKILLS[sk];
            if (s) await this.msg.show(`${josa(b.name, '은')} ${josa(s.name, '을')} 배웠다!`);
          }
        }
      }
    }
    this._done('win');
  }

  async _defeat() {
    await this._pause(500);
    this.core.finalize();
    this.mode = 'result';
    this.lines = ['', ''];
    this.defeatFade = 0.001;
    await this.msg.show(`${this._leaderName()} 일행은 전멸했다…`);
    this._done('lose');
  }

  _pause(ms) {
    const fast = this.game.input.held('confirm');
    return this.game.wait(fast ? ms * 0.45 : ms);
  }

  _pushLine(text) {
    if (!this.lines[0]) this.lines = [text, ''];
    else if (!this.lines[1]) this.lines = [this.lines[0], text];
    else this.lines = [this.lines[1], text];
  }

  // ------------------------------------------------------------------
  // 이벤트 재생
  async _play(events) {
    for (const ev of events) {
      switch (ev.t) {
        case 'action': {
          this.lines = [ev.text, ''];
          const a = ev.actor;
          if (a && !a.isParty) { a.lunge = 0.35; }
          if (a && a.isParty) { a.panelFlash = 0.3; }
          if (ev.anim) this._playAnim(ev);
          await this._pause(ev.anim ? 480 : 620);
          break;
        }
        case 'msg':
          this._pushLine(ev.text);
          if (ev.sfx) sfx(ev.sfx);
          if (ev.crit) this.game.shake(250, 5);
          if (ev.status && ev.target) this._spawnFx(ev.target, 'status', null);
          await this._pause(ev.crit ? 380 : 620);
          break;
        case 'dmg': {
          const tgt = ev.target;
          this._pushLine(ev.text);
          const an = this._anchor(tgt);
          if (tgt.isParty) {
            tgt.panelShake = 0.35;
            sfx(ev.crit ? 'crit' : 'hit');
            const big = ev.bossHit || ev.crit || ev.amount >= tgt.maxHp * 0.3;
            this.game.shake(big ? 320 : 160, big ? 8 : 3);
            if (big) this.game.flash('rgba(255,40,40,0.35)', 160);
            this._popup(an.x, an.y - 8, String(ev.amount), ev.poison ? '#d090ff' : '#ffffff', ev.crit);
          } else {
            tgt.flash = 0.3;
            tgt.shakeX = 0.3;
            sfx(ev.poison ? 'hit' : ev.crit ? 'crit' : 'hit');
            if (ev.crit || (tgt.boss && ev.amount > 0 && ev.weak)) this.game.shake(260, 6);
            this._popup(an.x, an.y - 20, String(ev.amount), ev.weak ? '#ffd040' : ev.resist ? '#a0a8c0' : '#ffffff', ev.crit);
          }
          await this._pause(560);
          break;
        }
        case 'miss': {
          const an = this._anchor(ev.target);
          sfx('miss');
          this._popup(an.x, an.y - 16, 'MISS', '#c0c8e0', false);
          this._pushLine(ev.text);
          await this._pause(520);
          break;
        }
        case 'heal': {
          const an = this._anchor(ev.target);
          this._popup(an.x, an.y - 16, String(ev.amount), ev.mp ? '#80c8ff' : COLORS.heal, false);
          if (ev.target.isParty) ev.target.panelFlash = 0.4;
          this._pushLine(ev.text);
          await this._pause(520);
          break;
        }
        case 'die': {
          const tgt = ev.target;
          this._pushLine(ev.text);
          if (tgt.isParty) {
            sfx('hit');
            this.game.flash('rgba(200,0,0,0.4)', 250);
            await this._pause(700);
          } else {
            tgt.dieT = 0;
            sfx('enemy_die');
            await this._pause(tgt.boss ? 1400 : 650);
          }
          break;
        }
        case 'revive':
          sfx('heal');
          this._spawnFx(ev.target, 'heal', 'holy');
          ev.target.panelFlash = 0.8;
          this._pushLine(ev.text);
          await this._pause(700);
          break;
        case 'phase':
          sfx('thunder');
          this.game.flash('rgba(255,0,40,0.55)', 400);
          this.game.shake(700, 9);
          ev.target.flash = 0.6;
          this._pushLine(ev.text);
          await this._pause(1300);
          break;
        default: break;
      }
    }
  }

  _playAnim(ev) {
    const targets = ev.targets || [];
    const a = ev.actor;
    if (ev.anim === 'slash') {
      if (a && !a.isParty && !ev.enemySkill) sfx('hit');
      for (const t of targets) this._spawnFx(t, 'slash', ev.element);
      if (ev.element) sfx(ELEMENT_SFX[ev.element] || 'magic');
    } else if (ev.anim === 'magic') {
      sfx(ELEMENT_SFX[ev.element] || 'magic');
      for (const t of targets) this._spawnFx(t, 'magic', ev.element || (a && !a.isParty ? 'dark' : null));
      if (targets.length > 1 && targets[0] && targets[0].isParty) this.game.shake(300, 4);
    } else if (ev.anim === 'heal') {
      sfx('heal');
      for (const t of targets) this._spawnFx(t, 'heal', null);
    } else if (ev.anim === 'buff') {
      sfx('magic');
      for (const t of targets) this._spawnFx(t, 'buff', null);
    }
  }

  _popup(x, y, text, color, big) {
    this.popups.push({ x, y, text, color, big, t: 0 });
  }

  _spawnFx(target, kind, element) {
    const an = this._anchor(target);
    const parts = [];
    const n = kind === 'slash' ? 0 : 14;
    for (let i = 0; i < n; i++) {
      parts.push({ dx: (Math.random() - 0.5) * 70, dy: (Math.random() - 0.5) * 50, vy: -20 - Math.random() * 50, s: 2 + Math.random() * 3, d: Math.random() * 0.2 });
    }
    this.fx.push({ kind, element, x: an.x, y: an.y, t: 0, life: kind === 'slash' ? 0.3 : 0.7, parts });
  }

  // ------------------------------------------------------------------
  // 명령 입력
  _commandPhase() {
    return new Promise((resolve) => {
      this.cmdResolve = resolve;
      this.cmdMembers = this.core.party.filter((b) => this.core.canCommand(b));
      this.cmdIdx = 0;
      this.actions = [];
      this.reserved = {};
      if (!this.cmdMembers.length) { resolve({ actions: [] }); return; }
      this._openCommand();
    });
  }

  _openCommand() {
    const b = this.cmdMembers[this.cmdIdx];
    this.active = b;
    this.mode = 'cmd';
    this.lines = [`${josa(b.name, '은')} 어떻게 할까?`, ''];
    const items = [
      { label: '공격' },
      { label: '스킬', disabled: !this.game.state.knownSkills(b.id).length },
      { label: '아이템' },
      { label: '방어' },
      { label: '도주', disabled: !this.canEscape },
    ];
    this.cmdList = new ChoiceList(items, { x: 12, y: CMD_Y, w: 128, rowH: 28, cancelable: true, index: this.lastCmd[b.id] || 0 });
    this.subList = null;
    this.target = null;
  }

  _commit(action) {
    const b = this.cmdMembers[this.cmdIdx];
    action.actor = b;
    this.actions.push(action);
    if (action.type === 'item') this.reserved[action.item] = (this.reserved[action.item] || 0) + 1;
    this.cmdIdx += 1;
    if (this.cmdIdx >= this.cmdMembers.length) {
      this.mode = 'busy';
      this.active = null;
      this.cmdList = null; this.subList = null; this.target = null;
      const r = this.cmdResolve; this.cmdResolve = null;
      r({ actions: this.actions });
    } else {
      this._openCommand();
    }
  }

  _back() {
    if (this.cmdIdx <= 0) return;
    this.cmdIdx -= 1;
    const a = this.actions.pop();
    if (a && a.type === 'item') this.reserved[a.item] -= 1;
    this._openCommand();
  }

  _skillList(b) {
    const ids = this.game.state.knownSkills(b.id);
    this.skillIds = ids;
    const items = ids.map((id) => {
      const s = SKILLS[id];
      return { label: s.name, right: `${s.mp}`, disabled: s.mp > b.mp };
    });
    this.subList = new ChoiceList(items, { x: 146, y: CMD_Y, w: 300, rowH: 28, visibleRows: 5, cancelable: true, index: Math.min(this.lastSkill[b.id] || 0, Math.max(0, items.length - 1)) });
    this.mode = 'skill';
  }

  _itemList() {
    const inv = this.game.state.inventory;
    this.itemIds = Object.keys(inv).filter((id) => {
      const it = ITEMS[id];
      return it && it.type === 'consumable' && (it.usable === 'both' || it.usable === 'battle') && inv[id] - (this.reserved[id] || 0) > 0;
    });
    const items = this.itemIds.map((id) => ({ label: ITEMS[id].name, right: `×${inv[id] - (this.reserved[id] || 0)}` }));
    this.subList = new ChoiceList(items, { x: 146, y: CMD_Y, w: 300, rowH: 28, visibleRows: 5, cancelable: true, index: Math.min(this.lastItem, Math.max(0, items.length - 1)) });
    this.mode = 'item';
  }

  // kind: 'enemy' | 'allEnemies' | 'ally' | 'allAllies' | 'self' ; filter: 'alive' | 'dead'
  _chooseTarget(kind, filter, onPick, onCancel) {
    const b = this.cmdMembers[this.cmdIdx];
    if (kind === 'self') { onPick(b); return; }
    let pool;
    if (kind === 'enemy' || kind === 'allEnemies') pool = this.core.aliveEnemies();
    else pool = this.core.party.filter((p) => (filter === 'dead' ? !p.alive : p.alive));
    if (!pool.length) { sfx('buzzer'); return; }
    let index = 0;
    if (kind === 'ally') { const me = pool.indexOf(b); if (me >= 0) index = me; }
    this.target = { kind, pool, index, all: kind === 'allEnemies' || kind === 'allAllies', onPick, onCancel, prevMode: this.mode };
    this.mode = 'target';
  }

  _onCommand(idx) {
    const b = this.cmdMembers[this.cmdIdx];
    this.lastCmd[b.id] = idx;
    switch (idx) {
      case 0:
        this._chooseTarget('enemy', 'alive', (t) => this._commit({ type: 'attack', target: t }), () => { this.mode = 'cmd'; });
        break;
      case 1: this._skillList(b); break;
      case 2: this._itemList(); break;
      case 3: this._commit({ type: 'defend' }); break;
      case 4: {
        this.mode = 'busy';
        this.active = null;
        this.cmdList = null;
        const r = this.cmdResolve; this.cmdResolve = null;
        r({ escape: true });
        break;
      }
      default: break;
    }
  }

  _onSkill(idx) {
    const b = this.cmdMembers[this.cmdIdx];
    const id = this.skillIds[idx];
    const s = SKILLS[id];
    this.lastSkill[b.id] = idx;
    const kind = s.target;
    const filter = s.kind === 'revive' ? 'dead' : 'alive';
    this._chooseTarget(kind, filter, (t) => this._commit({ type: 'skill', skill: id, target: t }), () => { this.mode = 'skill'; });
  }

  _onItem(idx) {
    const id = this.itemIds[idx];
    const it = ITEMS[id];
    this.lastItem = idx;
    const filter = it.effect && it.effect.kind === 'revive' ? 'dead' : 'alive';
    this._chooseTarget(it.target || 'ally', filter, (t) => this._commit({ type: 'item', item: id, target: t }), () => { this.mode = 'item'; });
  }

  // ------------------------------------------------------------------
  update(dt) {
    this.t += dt;
    this.introT += dt;
    const input = this.game.input;
    // 연출 타이머
    for (const e of this.core.enemies) {
      if (e.flash > 0) e.flash -= dt;
      if (e.lunge > 0) e.lunge -= dt;
      if (e.shakeX > 0) e.shakeX -= dt;
      if (e.dieT >= 0 && e.dieT < 1) e.dieT = Math.min(1, e.dieT + dt / (e.boss ? 1.4 : 0.6));
    }
    for (const b of this.core.party) {
      if (b.panelShake > 0) b.panelShake -= dt;
      if (b.panelFlash > 0) b.panelFlash -= dt;
    }
    this.popups = this.popups.filter((p) => (p.t += dt) < 1.0);
    this.fx = this.fx.filter((f) => (f.t += dt) < f.life);
    if (this.escaping) this.escaping += dt;
    if (this.defeatFade) this.defeatFade = Math.min(1, this.defeatFade + dt);

    if (this.msg.active) { this.msg.update(dt, input); return; }

    switch (this.mode) {
      case 'cmd': {
        const r = this.cmdList.update(input, dt);
        if (r === -1) this._back();
        else if (r != null) this._onCommand(r);
        break;
      }
      case 'skill': {
        const r = this.subList.update(input, dt);
        const s = SKILLS[this.skillIds[this.subList.index]];
        if (s) this.lines = [s.desc, `소비 MP ${s.mp}`];
        if (r === -1) { this.mode = 'cmd'; this.subList = null; this.lines = [`${josa(this.active.name, '은')} 어떻게 할까?`, '']; }
        else if (r != null) this._onSkill(r);
        break;
      }
      case 'item': {
        const r = this.subList.update(input, dt);
        const it = ITEMS[this.itemIds[this.subList.index]];
        this.lines = it ? [it.desc, ''] : ['사용할 수 있는 아이템이 없다.', ''];
        if (r === -1) { this.mode = 'cmd'; this.subList = null; this.lines = [`${josa(this.active.name, '은')} 어떻게 할까?`, '']; }
        else if (r != null) this._onItem(r);
        break;
      }
      case 'target': this._updateTarget(input); break;
      default: break;
    }
  }

  _updateTarget(input) {
    const tg = this.target;
    const n = tg.pool.length;
    if (!tg.all) {
      const prev = tg.index;
      if (input.repeat('right') || input.repeat('down')) tg.index = (tg.index + 1) % n;
      if (input.repeat('left') || input.repeat('up')) tg.index = (tg.index - 1 + n) % n;
      if (prev !== tg.index) sfx('cursor');
    }
    const cur = tg.pool[tg.index];
    this.lines = [tg.all ? (tg.kind === 'allEnemies' ? '적 전체' : '아군 전체') : cur.name, ''];
    if (input.pressed('confirm')) {
      sfx('confirm');
      this.target = null;
      tg.onPick(tg.all ? null : cur);
    } else if (input.pressed('cancel')) {
      sfx('cancel');
      this.target = null;
      tg.onCancel();
      if (this.mode === 'cmd' && this.active) this.lines = [`${josa(this.active.name, '은')} 어떻게 할까?`, ''];
    }
  }

  // ------------------------------------------------------------------
  // 그리기
  draw(ctx) {
    drawBackground(ctx, this.bg);
    drawBgOverlay(ctx, this.bg, this.t);
    this._drawEnemies(ctx);
    this._drawFx(ctx);
    this._drawPopups(ctx, false);
    if (this.mode !== 'intro' && !this.msg.active && (this.lines[0] || this.lines[1])) this._drawLog(ctx);
    this._drawParty(ctx);
    this._drawPopups(ctx, true);
    this._drawMenus(ctx);
    this.msg.draw(ctx);
    if (this.escaping) {
      ctx.fillStyle = `rgba(0,0,0,${Math.min(0.7, this.escaping)})`;
      ctx.fillRect(0, 0, WIDTH, HEIGHT);
    }
    if (this.defeatFade) {
      ctx.fillStyle = `rgba(40,0,0,${this.defeatFade * 0.55})`;
      ctx.fillRect(0, 0, WIDTH, HEIGHT);
      this.msg.draw(ctx);
    }
    this._drawIntro(ctx);
  }

  _drawIntro(ctx) {
    const k = this.introT / 0.6;
    if (k >= 1) return;
    // 가로 띠가 번갈아 열리는 인카운터 연출
    const bands = 12;
    const bh = HEIGHT / bands;
    ctx.fillStyle = '#000';
    for (let i = 0; i < bands; i++) {
      const w = WIDTH * Math.max(0, 1 - k * 1.25 + (i % 2) * 0.1);
      if (i % 2) ctx.fillRect(0, i * bh, w, bh + 1);
      else ctx.fillRect(WIDTH - w, i * bh, w, bh + 1);
    }
    if (k < 0.25) { ctx.fillStyle = `rgba(255,255,255,${0.6 - k * 2.4})`; ctx.fillRect(0, 0, WIDTH, HEIGHT); }
  }

  _drawEnemies(ctx) {
    const tg = this.mode === 'target' ? this.target : null;
    const targeted = new Set();
    if (tg && (tg.kind === 'enemy' || tg.kind === 'allEnemies')) {
      if (tg.all) tg.pool.forEach((e) => targeted.add(e)); else targeted.add(tg.pool[tg.index]);
    }
    for (const e of this.core.enemies) {
      if (!e.alive && e.dieT < 0) e.dieT = 1; // 안전장치
      if (e.dieT >= 1) continue;
      const frame = Math.floor(this.t * 2.2 + e.phaseSeed) % 2;
      const spr = getSprite(e.data.sprite, e.data.palette, frame);
      const w = spr.w * 2 * e.scale;
      const h = spr.h * 2 * e.scale;
      const bobAmp = e.boss ? 3 : 2;
      const bob = e.dieT >= 0 ? 0 : Math.round(Math.sin(this.t * (e.boss ? 1.6 : 2.6) + e.phaseSeed) * bobAmp);
      let sx = e.x - w / 2;
      let sy = e.y - h + bob;
      let lw = w; let lh = h;
      if (e.lunge > 0) {
        const k = Math.sin((e.lunge / 0.35) * Math.PI) * 0.07;
        lw = w * (1 + k); lh = h * (1 + k);
        sx = e.x - lw / 2; sy = e.y - lh + bob + h * k * 0.3;
      }
      if (e.shakeX > 0) sx += Math.round(Math.sin(e.shakeX * 60) * 4);
      // 그림자
      ctx.fillStyle = 'rgba(0,0,0,0.35)';
      ctx.beginPath();
      ctx.ellipse(e.x, e.y + 2, w * 0.36, Math.max(4, w * 0.06), 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.save();
      ctx.imageSmoothingEnabled = false;
      if (e.dieT >= 0) {
        // 흩어지며 사라짐
        const k = e.dieT;
        const rows = spr.canvas.height;
        ctx.globalAlpha = Math.max(0, 1 - k);
        for (let r = 0; r < rows; r += 1) {
          const off = Math.sin(r * 1.7 + k * 10) * k * 26 * ((r % 2) ? 1 : -1);
          ctx.drawImage(spr.canvas, 0, r, spr.canvas.width, 1, sx + off, sy + r * (lh / rows) - k * 10, lw, lh / rows + 0.5);
        }
        ctx.globalAlpha = Math.max(0, 0.7 - k) ;
        ctx.globalCompositeOperation = 'lighter';
        const wspr = getSprite(e.data.sprite, e.data.palette, frame, true);
        ctx.drawImage(wspr.canvas, sx, sy - k * 10, lw, lh);
      } else {
        ctx.drawImage(spr.canvas, sx, sy, lw, lh);
        const blink = e.flash > 0 && Math.floor(e.flash * 20) % 2 === 0;
        const tgtBlink = targeted.has(e) && Math.floor(this.t * 6) % 2 === 0;
        if (blink || tgtBlink) {
          ctx.globalAlpha = blink ? 0.9 : 0.35;
          const wspr = getSprite(e.data.sprite, e.data.palette, frame, true);
          ctx.drawImage(wspr.canvas, sx, sy, lw, lh);
        }
      }
      ctx.restore();
      if (e.alive) {
        // 이름표
        const show = targeted.has(e) || this.mode === 'cmd' || this.mode === 'skill' || this.mode === 'item' || this.mode === 'target';
        if (show) drawText(ctx, e.name, e.x, e.y + 8, { size: 13, align: 'center', color: targeted.has(e) ? COLORS.accent : '#e8ecff', bold: targeted.has(e) });
        if (targeted.has(e)) {
          const ay = e.y - h - 14 + Math.round(Math.sin(this.t * 8) * 3);
          ctx.fillStyle = COLORS.accent;
          ctx.strokeStyle = '#000';
          ctx.beginPath(); ctx.moveTo(e.x - 8, ay); ctx.lineTo(e.x + 8, ay); ctx.lineTo(e.x, ay + 10); ctx.closePath();
          ctx.fill(); ctx.stroke();
        }
      }
    }
  }

  _drawFx(ctx) {
    for (const f of this.fx) {
      const k = f.t / f.life;
      ctx.save();
      if (f.kind === 'slash') {
        ctx.strokeStyle = f.element ? ELEMENT_COLOR[f.element] || '#fff' : '#ffffff';
        ctx.lineWidth = 4 * (1 - k) + 1;
        ctx.globalAlpha = 1 - k;
        for (let i = -1; i <= 1; i++) {
          ctx.beginPath();
          ctx.moveTo(f.x - 34 + i * 10, f.y - 34 + k * 10);
          ctx.lineTo(f.x + 34 + i * 10, f.y + 34 * Math.min(1, k * 3) - 20);
          ctx.stroke();
        }
      } else if (f.kind === 'magic') {
        const col = f.element === 'dark' || !f.element ? '#c070ff' : ELEMENT_COLOR[f.element];
        ctx.globalAlpha = 1 - k;
        if (f.element === 'thunder') {
          ctx.strokeStyle = col; ctx.lineWidth = 3;
          ctx.beginPath();
          let x = f.x; let y = f.y - 120;
          ctx.moveTo(x, y);
          for (let i = 0; i < 6; i++) { x += (Math.sin(i * 7 + f.t * 40) * 14); y += 22; ctx.lineTo(x, y); }
          ctx.stroke();
        }
        ctx.strokeStyle = col; ctx.lineWidth = 3;
        ctx.beginPath(); ctx.ellipse(f.x, f.y, 10 + k * 60, 6 + k * 30, 0, 0, Math.PI * 2); ctx.stroke();
        for (const p of f.parts) {
          const pk = Math.max(0, k - p.d);
          ctx.fillStyle = col;
          const s = p.s * (1 - pk);
          if (f.element === 'ice') ctx.fillRect(f.x + p.dx * pk * 1.4 - s, f.y + p.dy * pk * 1.4 - s, s * 2, s * 3);
          else ctx.fillRect(f.x + p.dx * pk, f.y + p.dy * 0.3 + p.vy * pk, s, s);
        }
      } else if (f.kind === 'heal' || f.kind === 'buff' || f.kind === 'status') {
        const col = f.kind === 'heal' ? '#90ffb0' : f.kind === 'buff' ? '#ffe070' : '#c080ff';
        ctx.globalAlpha = 1 - k;
        for (const p of f.parts) {
          const pk = Math.max(0, k - p.d);
          ctx.fillStyle = col;
          const x = f.x + p.dx * 0.8;
          const y = f.y + 20 + p.vy * pk * 1.2;
          if (f.kind === 'buff') {
            ctx.beginPath(); ctx.moveTo(x, y - 5); ctx.lineTo(x + 4, y); ctx.lineTo(x - 4, y); ctx.closePath(); ctx.fill();
          } else {
            ctx.fillRect(x - 1, y - 3, 2, 6); ctx.fillRect(x - 3, y - 1, 6, 2);
          }
        }
      }
      ctx.restore();
    }
  }

  _drawPopups(ctx, partyLayer) {
    for (const p of this.popups) {
      if ((p.y > PANEL_Y - 40) !== partyLayer) continue;
      const k = p.t;
      const jump = k < 0.3 ? Math.sin((k / 0.3) * Math.PI) * 14 : 0;
      const alpha = k > 0.75 ? (1 - k) / 0.25 : 1;
      ctx.save();
      ctx.globalAlpha = Math.max(0, alpha);
      const size = p.big ? 30 : 24;
      ctx.font = `bold ${size}px "Noto Sans KR", sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.lineWidth = 4;
      ctx.strokeStyle = '#000';
      ctx.strokeText(p.text, p.x, p.y - jump - k * 8);
      ctx.fillStyle = p.color;
      ctx.fillText(p.text, p.x, p.y - jump - k * 8);
      ctx.restore();
    }
  }

  _drawLog(ctx) {
    drawWindow(ctx, 16, 8, WIDTH - 32, this.lines[1] ? 72 : 46);
    if (this.lines[0]) drawText(ctx, this.lines[0], 36, 20, { size: 19 });
    if (this.lines[1]) drawText(ctx, this.lines[1], 36, 48, { size: 19 });
  }

  _drawParty(ctx) {
    const tg = this.mode === 'target' ? this.target : null;
    for (const b of this.core.party) {
      const r = this._panelRect(b);
      let x = r.x; let y = r.y;
      const isActive = this.active === b && (this.mode === 'cmd' || this.mode === 'skill' || this.mode === 'item' || this.mode === 'target');
      if (isActive) y -= 8;
      if (b.panelShake > 0) { x += Math.round(Math.sin(b.panelShake * 70) * 4); y += Math.round(Math.cos(b.panelShake * 50) * 2); }
      const dead = !b.alive;
      drawWindow(ctx, x, y, r.w, r.h, dead ? { top: '#4a1620', bottom: '#240810' } : isActive ? { top: '#3a4aa0', bottom: '#18246a' } : {});
      if (b.panelFlash > 0) {
        ctx.fillStyle = `rgba(255,255,255,${Math.min(0.35, b.panelFlash)})`;
        ctx.fillRect(x + 4, y + 4, r.w - 8, r.h - 8);
      }
      if (isActive) {
        ctx.strokeStyle = COLORS.accent; ctx.lineWidth = 2;
        ctx.strokeRect(x + 1, y + 1, r.w - 2, r.h - 2);
      }
      const nameColor = dead ? COLORS.hpLow : (CHARACTERS[b.id] && isActive ? COLORS.accent : COLORS.text);
      drawText(ctx, b.name, x + 12, y + 9, { size: 16, bold: true, color: nameColor });
      drawText(ctx, `Lv${b.member.level}`, x + r.w - 12, y + 11, { size: 13, align: 'right', color: COLORS.dim });
      const hpRatio = b.hp / b.maxHp;
      const hpCol = dead ? COLORS.hpLow : hpRatio < 0.25 ? '#ffb040' : COLORS.text;
      drawText(ctx, 'HP', x + 12, y + 33, { size: 13, color: COLORS.dim });
      drawText(ctx, `${b.hp}/${b.maxHp}`, x + r.w - 12, y + 31, { size: 16, align: 'right', color: hpCol, bold: true });
      drawGauge(ctx, x + 12, y + 51, r.w - 24, 6, hpRatio, hpRatio < 0.25 ? COLORS.hpLow : COLORS.hp);
      drawText(ctx, 'MP', x + 12, y + 61, { size: 13, color: COLORS.dim });
      drawText(ctx, `${b.mp}/${b.maxMp}`, x + r.w - 12, y + 59, { size: 16, align: 'right', color: dead ? COLORS.disabled : COLORS.text });
      drawGauge(ctx, x + 12, y + 79, r.w - 24, 6, b.maxMp ? b.mp / b.maxMp : 0, COLORS.mp);
      // 상태 태그
      const tags = [];
      if (b.status.poison) tags.push(STATUS_TAG.poison);
      if (b.status.sleep > 0) tags.push(STATUS_TAG.sleep);
      if (b.status.stun > 0) tags.push(STATUS_TAG.stun);
      if (b.buffs.atk) tags.push(['공↑', '#ff8060']);
      if (b.buffs.def) tags.push(['방↑', '#60c0ff']);
      if (b.taunt > 0) tags.push(['도발', '#ffd040']);
      if (b.defending) tags.push(['방어', '#a0b0d0']);
      let tx = x + 8;
      for (const [label, col] of tags) {
        ctx.font = 'bold 11px "Noto Sans KR", sans-serif';
        const tw = ctx.measureText(label).width + 8;
        ctx.fillStyle = col; ctx.fillRect(tx, y - 9, tw, 15);
        ctx.strokeStyle = '#000'; ctx.lineWidth = 1; ctx.strokeRect(tx + 0.5, y - 8.5, tw - 1, 14);
        drawText(ctx, label, tx + 4, y - 8, { size: 11, bold: true, color: '#000', shadow: false });
        tx += tw + 3;
      }
      // 아군 대상 커서
      if (tg && (tg.kind === 'ally' || tg.kind === 'allAllies') && (tg.all ? tg.pool.includes(b) : tg.pool[tg.index] === b)) {
        const ay = y - 22 + Math.round(Math.sin(this.t * 8) * 3);
        ctx.fillStyle = COLORS.accent; ctx.strokeStyle = '#000';
        ctx.beginPath(); ctx.moveTo(r.cx - 8, ay); ctx.lineTo(r.cx + 8, ay); ctx.lineTo(r.cx, ay + 10); ctx.closePath();
        ctx.fill(); ctx.stroke();
        if (Math.floor(this.t * 6) % 2 === 0) { ctx.strokeStyle = COLORS.accent; ctx.lineWidth = 2; ctx.strokeRect(x + 1, y + 1, r.w - 2, r.h - 2); }
      }
    }
  }

  _drawMenus(ctx) {
    if (this.msg.active) return;
    const m = this.mode;
    const inTarget = m === 'target';
    const under = inTarget ? this.target.prevMode : m;
    if (this.cmdList && (m === 'cmd' || m === 'skill' || m === 'item' || inTarget)) {
      this.cmdList.draw(ctx, m === 'cmd');
    }
    if (this.subList && (m === 'skill' || m === 'item' || (inTarget && (under === 'skill' || under === 'item')))) {
      this.subList.draw(ctx, m === 'skill' || m === 'item');
      if (!this.subList.items.length) drawText(ctx, '(없음)', this.subList.x + 34, this.subList.y + 16, { size: 16, color: COLORS.disabled });
    }
  }
}
