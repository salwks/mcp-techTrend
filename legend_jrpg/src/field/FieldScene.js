// 필드(맵 이동) 씬: 맵 렌더링, 이동/충돌, NPC·상자·오브젝트 상호작용, 트리거/출구, 랜덤 인카운터, 이벤트 실행
import { Scene, WIDTH, HEIGHT } from '../engine/game.js';
import { GameState } from '../engine/state.js';
import { sfx, playBgm, stopBgm } from '../engine/audio.js';
import { MessageWindow, ChoiceList, drawText, FONT, COLORS } from '../ui/window.js';
import { MAPS, ENCOUNTERS, itemName } from './data.js';
import { TILE, isWalkable, buildMapLayer, drawAnimatedTiles, tileAt } from './tiles.js';
import { drawSprite, drawChest } from './sprites.js';
import { Interpreter } from './interpreter.js';
import { DIRS, PATH_DIRS, OPPOSITE, dirFromDelta, isVisible, inRect, josa } from './util.js';

const STEP_TIME = 0.16;   // 플레이어 한 칸 이동 시간(초)
const NPC_STEP_TIME = 0.3;
const GRACE_STEPS = 4;    // 맵 진입/전투 후 인카운터 유예 걸음 수
const DIR_KEYS = ['up', 'down', 'left', 'right'];

// ---------------------------------------------------------------
// 격자 이동 + 보간
// ---------------------------------------------------------------
class Mover {
  constructor(x, y, dir = 'down') {
    this.x = x; this.y = y; this.fx = x; this.fy = y;
    this.dir = dir;
    this.t = 1; this.dur = STEP_TIME;
    this.moving = false;
    this.steps = 0;
    this.onArrive = null;
  }
  place(x, y, dir) {
    this.x = this.fx = x; this.y = this.fy = y;
    if (dir) this.dir = dir;
    this.moving = false; this.t = 1;
  }
  moveTo(tx, ty, dur) {
    this.fx = this.x; this.fy = this.y;
    this.dir = dirFromDelta(tx - this.x, ty - this.y, this.dir);
    this.x = tx; this.y = ty;
    this.t = 0; this.dur = dur; this.moving = true;
    this.steps += 1;
  }
  // 이번 프레임에 도착했으면 true
  update(dt) {
    if (!this.moving) return false;
    this.t += dt / this.dur;
    if (this.t >= 1) {
      this.t = 1; this.moving = false;
      this.fx = this.x; this.fy = this.y;
      const cb = this.onArrive; this.onArrive = null;
      if (cb) cb();
      return true;
    }
    return false;
  }
  get px() { return (this.fx + (this.x - this.fx) * this.t) * TILE; }
  get py() { return (this.fy + (this.y - this.fy) * this.t) * TILE; }
  get pose() {
    if (!this.moving) return 0;
    if (this.t >= 0.5) return 0;
    return this.steps % 2 ? 1 : 2;
  }
  occupies(x, y) {
    return (this.x === x && this.y === y) || (this.moving && this.fx === x && this.fy === y);
  }
}

function fallbackMap(id) {
  const w = 20, h = 15;
  const tiles = [];
  for (let y = 0; y < h; y++) {
    let row = '';
    for (let x = 0; x < w; x++) row += x === 0 || y === 0 || x === w - 1 || y === h - 1 ? 'T' : (x + y * 3) % 17 === 0 ? 'F' : '.';
    tiles.push(row);
  }
  return { name: id ? `??? (${id})` : '???', bgm: 'field', tiles, npcs: [], triggers: [], exits: [], chests: [], objects: [] };
}

export class FieldScene extends Scene {
  constructor(game, params) {
    super(game, params);
    this.opaque = true;
    this.t = 0;
    this.msg = new MessageWindow();
    this.choice = null;
    this.interp = new Interpreter(this);
    this.busy = false;
    this.pendingEnter = null;
    this.menuQueued = false;
    this.lastDir = null;
    this.banner = null;
    this.bgm = null;
    this.grace = GRACE_STEPS;
    this.player = new Mover(0, 0, 'down');
    this.followers = [];
    this.npcs = [];
    this.scriptedMove = false;
    this.darkCanvas = null;
  }

  get state() { return this.game.state; }
  isDead() { return !!this._dead; }

  // ---------------------------------------------------------------
  // 씬 수명주기
  // ---------------------------------------------------------------
  enter() {
    if (!this.game.state) this.game.state = GameState.newGame();
    const st = this.game.state;
    const p = this.params || {};
    const mapId = p.mapId || st.map?.id || Object.keys(MAPS)[0] || 'village';
    let x = p.x, y = p.y, dir = p.dir;
    if (x == null || y == null) {
      if (st.map && st.map.id === mapId) { x = st.map.x; y = st.map.y; dir = dir || st.map.dir; }
    }
    this.loadMap(mapId, x, y, dir);
    this.lock(async () => {
      if (this.game.fade.alpha > 0) await this.game.fadeIn(400);
      this.showBanner();
      this.pendingEnter = this.map.onEnter || null;
    });
  }

  exit() {
    this.msg.active = false;
  }

  // ---------------------------------------------------------------
  // 맵 로딩
  // ---------------------------------------------------------------
  loadMap(id, x, y, dir) {
    let map = MAPS[id];
    if (!map || !Array.isArray(map.tiles) || !map.tiles.length) {
      console.warn(`[field] 맵을 찾을 수 없음: ${id} — 임시 맵을 사용합니다`);
      map = fallbackMap(id);
    }
    this.mapId = id;
    this.map = map;
    const width = Math.max(...map.tiles.map((r) => String(r).length));
    this.tiles = map.tiles.map((r) => String(r).padEnd(width, ' '));
    this.mapW = width;
    this.mapH = this.tiles.length;
    this.layer = buildMapLayer(this.tiles);

    this.npcs = (map.npcs || []).map((n) => ({
      def: n,
      id: n.id,
      mover: new Mover(n.x, n.y, n.dir || 'down'),
      home: { x: n.x, y: n.y },
      wanderT: 1 + Math.random() * 3,
      scripted: false,
    }));

    if (x == null || y == null || !this.inBounds(x, y)) {
      const s = map.start || this.findOpenTile();
      x = s.x; y = s.y;
    }
    this.player.place(x, y, dir || this.player.dir || 'down');
    this.resetFollowers();
    this.syncState();
    this.grace = GRACE_STEPS;
    this.setBgm(map.bgm || null);
  }

  findOpenTile() {
    const cx = Math.floor(this.mapW / 2), cy = Math.floor(this.mapH / 2);
    for (let r = 0; r < Math.max(this.mapW, this.mapH); r++) {
      for (let y = cy - r; y <= cy + r; y++) for (let x = cx - r; x <= cx + r; x++) {
        if (this.inBounds(x, y) && isWalkable(this.tile(x, y))) return { x, y };
      }
    }
    return { x: cx, y: cy };
  }

  syncState() {
    const st = this.state;
    if (st) st.map = { id: this.mapId, x: this.player.x, y: this.player.y, dir: this.player.dir };
  }

  showBanner() {
    if (this.map && this.map.name) this.banner = { text: this.map.name, t: 0 };
  }

  // ---------------------------------------------------------------
  // 파티(대열)
  // ---------------------------------------------------------------
  resetFollowers() {
    const party = this.state?.party || [];
    this.followers = party.slice(1, 4).map((id) => ({ id, mover: new Mover(this.player.x, this.player.y, this.player.dir) }));
  }

  refreshParty() {
    const party = this.state?.party || [];
    const old = new Map(this.followers.map((f) => [f.id, f]));
    const last = this.followers.length ? this.followers[this.followers.length - 1].mover : this.player;
    this.followers = party.slice(1, 4).map((id) => old.get(id) || { id, mover: new Mover(last.x, last.y, last.dir) });
  }

  leaderKey() { return this.state?.party?.[0] || 'ren'; }

  // ---------------------------------------------------------------
  // 타일 / 충돌
  // ---------------------------------------------------------------
  tile(x, y) { return tileAt(this.tiles, x, y); }
  inBounds(x, y) { return x >= 0 && y >= 0 && x < this.mapW && y < this.mapH; }

  visibleNpcs() { return this.npcs.filter((n) => isVisible(this.state, n.def)); }
  npcAt(x, y) { return this.npcs.find((n) => isVisible(this.state, n.def) && n.mover.occupies(x, y)) || null; }
  chestAt(x, y) { return (this.map.chests || []).find((c) => c.x === x && c.y === y && isVisible(this.state, c)) || null; }
  objectAt(x, y) { return (this.map.objects || []).find((o) => o.x === x && o.y === y && isVisible(this.state, o)) || null; }

  blockedByThing(x, y) {
    return !!(this.npcAt(x, y) || this.chestAt(x, y) || this.objectAt(x, y));
  }

  canPlayerEnter(x, y) {
    return this.inBounds(x, y) && isWalkable(this.tile(x, y)) && !this.blockedByThing(x, y);
  }

  canNpcEnter(npc, x, y) {
    if (!this.inBounds(x, y) || !isWalkable(this.tile(x, y))) return false;
    if (this.player.occupies(x, y)) return false;
    if (this.followers.some((f) => f.mover.occupies(x, y))) return false;
    if (this.npcs.some((n) => n !== npc && isVisible(this.state, n.def) && n.mover.occupies(x, y))) return false;
    if (this.chestAt(x, y) || this.objectAt(x, y)) return false;
    if ((this.map.exits || []).some((e) => inRect(e, x, y))) return false;
    return true;
  }

  // ---------------------------------------------------------------
  // 잠금(이벤트 실행 중 입력 차단)
  // ---------------------------------------------------------------
  async lock(fn) {
    if (this.busy) return;
    this.busy = true;
    try {
      await fn();
      while (this.pendingEnter && !this.isDead()) {
        const ev = this.pendingEnter;
        this.pendingEnter = null;
        await this.interp.run(ev);
      }
    } catch (err) {
      console.error('[field] 이벤트 처리 중 오류', err);
    } finally {
      this.busy = false;
      this.game.input.consume();
    }
  }

  runEvent(ref) {
    return this.lock(() => this.interp.run(ref));
  }

  // ---------------------------------------------------------------
  // 메시지 / 선택지 (이벤트 실행기가 사용)
  // ---------------------------------------------------------------
  say(text, speaker = null) {
    if (this.isDead()) return new Promise(() => {});
    return this.msg.show(String(text), speaker);
  }

  ask(options, text, speaker) {
    const labels = (options || []).map((o) => String(o));
    if (!labels.length) return Promise.resolve(0);
    const ctx = this.game.ctx;
    ctx.save();
    ctx.font = FONT(18);
    const w = Math.max(140, Math.min(360, Math.max(...labels.map((l) => ctx.measureText(l).width)) + 64));
    ctx.restore();
    const list = new ChoiceList(labels, { w, cancelable: true });
    list.x = WIDTH - 16 - w;
    list.y = this.msg.y - list.height - (speaker ? 6 : 6);
    if (text) this.msg.show(String(text), speaker || null);
    return new Promise((resolve) => { this.choice = { list, resolve, n: labels.length, hasText: !!text }; });
  }

  // ---------------------------------------------------------------
  // 다른 씬 호출
  // ---------------------------------------------------------------
  async subScene(name, params) {
    let res;
    try {
      res = await this.game.runScene(name, params);
    } catch (err) {
      console.warn(`[field] 씬 실행 실패: ${name}`, err);
    }
    if (this.isDead()) return new Promise(() => {});
    this.game.input.consume();
    this.restoreBgm();
    if (this.game.fade.alpha > 0 && !this.game.fade.resolve) await this.game.fadeIn(250);
    return res;
  }

  async battle({ troop, canEscape = true, bg, bgm, random = false }) {
    if (random) { sfx('encounter'); this.game.flash('#ffffff', 180); await this.game.wait(260); }
    const params = { troop, canEscape, bg: bg || this.map.battleBg || 'plains' };
    if (bgm) params.bgm = bgm;
    let res;
    try {
      res = await this.game.runScene('battle', params);
    } catch (err) {
      console.warn('[field] 전투 씬 실행 실패 — 승리로 처리', err);
      res = 'win';
    }
    if (this.isDead()) return new Promise(() => {});
    this.game.input.consume();
    this.grace = GRACE_STEPS;
    if (res !== 'lose') {
      this.restoreBgm();
      if (this.game.fade.alpha > 0 && !this.game.fade.resolve) await this.game.fadeIn(300);
    }
    return res;
  }

  gameOver() {
    try { this.game.runScene('gameover'); } catch (err) { console.warn('[field] gameover 씬 없음', err); }
  }

  setBgm(key) {
    this.bgm = key || null;
    if (!key || key === 'none' || key === 'stop') stopBgm();
    else playBgm(key);
  }

  restoreBgm() {
    if (this.bgm && this.bgm !== 'none' && this.bgm !== 'stop') playBgm(this.bgm);
    else stopBgm();
  }

  // ---------------------------------------------------------------
  // 이동 연출 (이벤트용)
  // ---------------------------------------------------------------
  async teleport(mapId, x, y, dir, opts = {}) {
    if (opts.sound) sfx('door');
    await this.game.fadeOut(250);
    if (this.isDead()) return;
    this.msg.active = false;
    this.loadMap(mapId, x, y, dir);
    await this.game.fadeIn(250);
    this.showBanner();
    if (this.map.onEnter) this.pendingEnter = this.map.onEnter;
  }

  stepPlayer(dir, dur) {
    const d = DIRS[dir];
    const ox = this.player.x, oy = this.player.y;
    this.player.moveTo(ox + d.x, oy + d.y, dur);
    this.player.dir = dir;
    // 대열: 각 동료가 앞 사람의 이전 위치로
    let prev = { x: ox, y: oy };
    for (const f of this.followers) {
      const m = f.mover;
      const cur = { x: m.x, y: m.y };
      if (cur.x !== prev.x || cur.y !== prev.y) m.moveTo(prev.x, prev.y, dur);
      prev = cur;
    }
  }

  movePlayer(path, speed) {
    const dur = speed || STEP_TIME * 1.4;
    return (async () => {
      this.scriptedMove = true;
      try {
        for (const ch of String(path).toUpperCase()) {
          const dir = PATH_DIRS[ch];
          if (!dir) continue;
          if (this.isDead()) return;
          await new Promise((resolve) => {
            this.stepPlayer(dir, dur);
            this.player.onArrive = resolve;
          });
        }
      } finally {
        this.scriptedMove = false;
        this.syncState();
      }
    })();
  }

  async moveNpc(id, path, speed) {
    const npc = this.npcs.find((n) => n.id === id);
    if (!npc) { console.warn(`[field] npcMove: NPC 없음 ${id}`); return; }
    npc.scripted = true;
    const dur = speed || NPC_STEP_TIME * 0.8;
    for (const ch of String(path).toUpperCase()) {
      const dir = PATH_DIRS[ch];
      if (!dir) continue;
      if (this.isDead()) return;
      const d = DIRS[dir];
      await new Promise((resolve) => {
        npc.mover.moveTo(npc.mover.x + d.x, npc.mover.y + d.y, dur);
        npc.mover.onArrive = resolve;
      });
    }
    npc.home = { x: npc.mover.x, y: npc.mover.y };
    npc.scripted = false;
  }

  faceNpc(id, dir) {
    const npc = this.npcs.find((n) => n.id === id);
    if (!npc) return;
    if (dir === 'player') npc.mover.dir = dirFromDelta(this.player.x - npc.mover.x, this.player.y - npc.mover.y, npc.mover.dir);
    else if (dir) npc.mover.dir = dir;
  }

  // ---------------------------------------------------------------
  // 업데이트
  // ---------------------------------------------------------------
  update(dt) {
    this.t += dt;
    const input = this.game.input;
    if (this.banner) { this.banner.t += dt; if (this.banner.t > 3.2) this.banner = null; }

    // 엔티티 이동
    for (const n of this.npcs) {
      n.mover.update(dt);
      if (!this.busy && n.def.wander && !n.scripted && !n.mover.moving && isVisible(this.state, n.def)) this.wander(n, dt);
    }
    for (const f of this.followers) f.mover.update(dt);
    if (this.player.update(dt)) {
      this.syncState();
      if (!this.scriptedMove) this.onStepEnd();
    }

    // 선택지 / 메시지
    if (this.choice) {
      const c = this.choice;
      const m = this.msg;
      if (m.active && !(m.page >= m.pages.length - 1 && m.shown >= m._pageLength())) {
        m.update(dt, input);
      } else {
        m.t += dt;
        const r = c.list.update(input, dt);
        if (r !== null) {
          this.choice = null;
          m.active = false;
          m._resolve = null;
          c.resolve(r < 0 ? c.n - 1 : r);
        }
      }
      return;
    }
    if (this.msg.active) { this.msg.update(dt, input); return; }
    if (this.busy) return;

    // 메뉴
    if (input.pressed('menu')) this.menuQueued = true;
    if (this.player.moving) return;
    if (this.menuQueued) {
      this.menuQueued = false;
      sfx('confirm');
      this.lock(() => this.subScene('menu'));
      return;
    }
    if (input.pressed('confirm') && this.interact()) return;

    const dir = this.heldDir();
    if (dir) this.tryStep(dir);
  }

  heldDir() {
    const input = this.game.input;
    let tapped = null;
    for (const d of DIR_KEYS) if (input.pressed(d)) { this.lastDir = d; tapped = d; }
    if (tapped) return tapped; // 짧게 톡 눌러도 한 칸 이동
    if (this.lastDir && input.held(this.lastDir)) return this.lastDir;
    for (const d of DIR_KEYS) if (input.held(d)) { this.lastDir = d; return d; }
    return null;
  }

  tryStep(dir) {
    this.player.dir = dir;
    const d = DIRS[dir];
    const tx = this.player.x + d.x, ty = this.player.y + d.y;
    if (!this.canPlayerEnter(tx, ty)) return false;
    this.stepPlayer(dir, STEP_TIME);
    return true;
  }

  wander(n, dt) {
    n.wanderT -= dt;
    if (n.wanderT > 0) return;
    n.wanderT = 1.4 + Math.random() * 3;
    const dir = DIR_KEYS[Math.floor(Math.random() * 4)];
    const d = DIRS[dir];
    const tx = n.mover.x + d.x, ty = n.mover.y + d.y;
    if (Math.abs(tx - n.home.x) <= 2 && Math.abs(ty - n.home.y) <= 2 && this.canNpcEnter(n, tx, ty)) {
      n.mover.moveTo(tx, ty, NPC_STEP_TIME);
    } else {
      n.mover.dir = dir;
    }
  }

  onStepEnd() {
    const st = this.state;
    if (st) st.steps = (st.steps || 0) + 1;
    const { x, y } = this.player;
    const exit = (this.map.exits || []).find((e) => inRect(e, x, y) && isVisible(st, e));
    if (exit) {
      this.lock(() => this.teleport(exit.to, exit.tx, exit.ty, exit.dir || this.player.dir, { sound: true }));
      return;
    }
    const trig = (this.map.triggers || []).find((t) => inRect(t, x, y) && isVisible(st, t));
    if (trig && trig.event) {
      this.runEvent(trig.event);
      return;
    }
    this.checkEncounter();
  }

  checkEncounter() {
    const key = this.map.encounter;
    if (!key) return;
    const table = ENCOUNTERS[key];
    if (!table || !Array.isArray(table.troops) || !table.troops.length) return;
    if (this.grace > 0) { this.grace -= 1; return; }
    if (Math.random() >= (table.rate ?? 0.05)) return;
    const total = table.troops.reduce((s, t) => s + (t.weight ?? 1), 0);
    let roll = Math.random() * total;
    let pick = table.troops[0];
    for (const t of table.troops) { roll -= t.weight ?? 1; if (roll < 0) { pick = t; break; } }
    this.lock(async () => {
      const res = await this.battle({ troop: pick.troop, canEscape: true, random: true });
      if (res === 'lose') this.gameOver();
    });
  }

  // ---------------------------------------------------------------
  // 상호작용
  // ---------------------------------------------------------------
  interact() {
    const p = this.player;
    const d = DIRS[p.dir];
    const fx = p.x + d.x, fy = p.y + d.y;
    let npc = this.npcAt(fx, fy);
    if (!npc && this.tile(fx, fy) === 'c') npc = this.npcAt(fx + d.x, fy + d.y);
    if (npc) { this.talk(npc); return true; }
    const chest = this.chestAt(fx, fy);
    if (chest) { this.openChest(chest); return true; }
    const obj = this.objectAt(fx, fy);
    if (obj) return this.useObject(obj);
    return false;
  }

  talk(npc) {
    const def = npc.def;
    if (!npc.mover.moving) npc.mover.dir = OPPOSITE[this.player.dir];
    this.lock(async () => {
      if (def.event) await this.interp.run(def.event);
      else if (Array.isArray(def.lines)) {
        for (const line of def.lines) { await this.say(line, def.name || null); if (this.isDead()) return; }
      } else if (typeof def.lines === 'string') await this.say(def.lines, def.name || null);
    });
  }

  chestFlag(chest) { return `chest_${this.mapId}_${chest.id}`; }

  openChest(chest) {
    const st = this.state;
    const flag = this.chestFlag(chest);
    this.lock(async () => {
      if (st.getFlag(flag)) { await this.say('상자는 비어 있다.'); return; }
      st.setFlag(flag, true);
      sfx('chest');
      if (chest.gold) {
        st.gold += chest.gold;
        await this.say(`보물상자를 열었다!\n${chest.gold} 골드를 손에 넣었다!`);
      } else if (chest.item) {
        const n = chest.count || 1;
        st.addItem(chest.item, n);
        const name = itemName(chest.item);
        await this.say(`보물상자를 열었다!\n${n > 1 ? `${name} ${n}개를` : josa(name, '을/를')} 손에 넣었다!`);
      } else {
        await this.say('보물상자를 열었다!\n…그러나 아무것도 들어 있지 않았다.');
      }
      if (chest.event) await this.interp.run(chest.event);
    });
  }

  useObject(obj) {
    if (obj.event) { this.runEvent(obj.event); return true; }
    const lines = Array.isArray(obj.lines) ? obj.lines : typeof obj.lines === 'string' ? [obj.lines] : null;
    if (lines) {
      this.lock(async () => { for (const l of lines) { await this.say(l, obj.name || null); if (this.isDead()) return; } });
      return true;
    }
    if (obj.sprite === 'save_crystal') {
      this.lock(async () => {
        sfx('heal');
        await this.say('빛의 결정이 따스하게 빛나고 있다.\n지금까지의 여정을 기록할 수 있을 것 같다.');
        await this.subScene('save', { mode: 'save' });
      });
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------
  // 그리기
  // ---------------------------------------------------------------
  camera() {
    const cx = this.player.px + TILE / 2, cy = this.player.py + TILE / 2;
    const mw = this.mapW * TILE, mh = this.mapH * TILE;
    const camX = mw <= WIDTH ? (mw - WIDTH) / 2 : Math.max(0, Math.min(mw - WIDTH, cx - WIDTH / 2));
    const camY = mh <= HEIGHT ? (mh - HEIGHT) / 2 : Math.max(0, Math.min(mh - HEIGHT, cy - HEIGHT / 2));
    return { camX: Math.round(camX), camY: Math.round(camY) };
  }

  draw(ctx) {
    if (!this.map) return;
    const { camX, camY } = this.camera();
    ctx.fillStyle = '#000';
    ctx.fillRect(0, 0, WIDTH, HEIGHT);
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(this.layer.canvas, -camX, -camY);
    drawAnimatedTiles(ctx, this.layer, camX, camY, WIDTH, HEIGHT, this.t);

    // 엔티티 (y 정렬)
    const ents = [];
    const onScreen = (px, py) => px > -48 && py > -48 && px < WIDTH + 16 && py < HEIGHT + 48;
    for (const c of this.map.chests || []) {
      if (!isVisible(this.state, c)) continue;
      const px = c.x * TILE - camX, py = c.y * TILE - camY;
      if (!onScreen(px, py)) continue;
      const open = !!this.state.getFlag(this.chestFlag(c));
      ents.push({ y: py, o: 0, draw: () => drawChest(ctx, open, px, py) });
    }
    for (const o of this.map.objects || []) {
      if (!isVisible(this.state, o)) continue;
      const px = o.x * TILE - camX, py = o.y * TILE - camY;
      if (!onScreen(px, py)) continue;
      if (o.sprite === 'chest') ents.push({ y: py, o: 0, draw: () => drawChest(ctx, !!(o.openIf && this.state.getFlag(o.openIf)), px, py) });
      else ents.push({ y: py, o: 0, draw: () => drawSprite(ctx, o.sprite || 'sign', o.dir || 'down', 0, px, py, this.t) });
    }
    for (const n of this.npcs) {
      if (!isVisible(this.state, n.def)) continue;
      const px = Math.round(n.mover.px - camX), py = Math.round(n.mover.py - camY);
      if (!onScreen(px, py)) continue;
      ents.push({ y: py, o: 1, draw: () => drawSprite(ctx, n.def.sprite || 'villager_m', n.mover.dir, n.mover.pose, px, py, this.t) });
    }
    this.followers.forEach((f, i) => {
      const px = Math.round(f.mover.px - camX), py = Math.round(f.mover.py - camY);
      ents.push({ y: py, o: 2 - (i + 1) * 0.1, draw: () => drawSprite(ctx, f.id, f.mover.dir, f.mover.pose, px, py, this.t) });
    });
    {
      const px = Math.round(this.player.px - camX), py = Math.round(this.player.py - camY);
      ents.push({ y: py, o: 3, draw: () => drawSprite(ctx, this.leaderKey(), this.player.dir, this.player.pose, px, py, this.t) });
    }
    ents.sort((a, b) => a.y - b.y || a.o - b.o);
    for (const e of ents) e.draw();

    if (this.map.dark) this.drawDarkness(ctx, camX, camY);
    this.drawBanner(ctx);

    if (this.choice) {
      if (this.msg.active) this.msg.draw(ctx);
      const m = this.msg;
      const ready = !m.active || (m.page >= m.pages.length - 1 && m.shown >= m._pageLength());
      if (ready) this.choice.list.draw(ctx);
    } else {
      this.msg.draw(ctx);
    }
  }

  drawDarkness(ctx, camX, camY) {
    if (!this.darkCanvas) {
      this.darkCanvas = document.createElement('canvas');
      this.darkCanvas.width = WIDTH; this.darkCanvas.height = HEIGHT;
    }
    const g = this.darkCanvas.getContext('2d');
    g.globalCompositeOperation = 'source-over';
    g.clearRect(0, 0, WIDTH, HEIGHT);
    g.fillStyle = 'rgba(4,2,12,0.86)';
    g.fillRect(0, 0, WIDTH, HEIGHT);
    g.globalCompositeOperation = 'destination-out';
    const light = (x, y, r, a = 1) => {
      const gr = g.createRadialGradient(x, y, r * 0.25, x, y, r);
      gr.addColorStop(0, `rgba(0,0,0,${a})`);
      gr.addColorStop(1, 'rgba(0,0,0,0)');
      g.fillStyle = gr;
      g.fillRect(x - r, y - r, r * 2, r * 2);
    };
    const flick = 1 + Math.sin(this.t * 7) * 0.02 + Math.sin(this.t * 13) * 0.015;
    light(this.player.px - camX + 16, this.player.py - camY + 16, 150 * flick);
    for (const o of this.map.objects || []) {
      if (o.sprite === 'save_crystal' && isVisible(this.state, o)) light(o.x * TILE - camX + 16, o.y * TILE - camY + 12, 70, 0.9);
    }
    let lavas = 0;
    for (const a of this.layer.animated) {
      if (a.ch !== 'L' || lavas > 40) continue;
      const px = a.x * TILE - camX, py = a.y * TILE - camY;
      if (px < -64 || py < -64 || px > WIDTH + 64 || py > HEIGHT + 64) continue;
      lavas += 1;
      light(px + 16, py + 16, 48, 0.7);
    }
    g.globalCompositeOperation = 'source-over';
    ctx.drawImage(this.darkCanvas, 0, 0);
  }

  drawBanner(ctx) {
    const b = this.banner;
    if (!b) return;
    const a = b.t < 0.35 ? b.t / 0.35 : b.t > 2.6 ? Math.max(0, (3.2 - b.t) / 0.6) : 1;
    ctx.save();
    ctx.globalAlpha = a;
    ctx.font = FONT(20, true);
    const w = Math.max(180, ctx.measureText(b.text).width + 64);
    const x = Math.round((WIDTH - w) / 2), y = 22;
    // drawWindow는 globalAlpha를 덮어쓰므로 페이드용으로 직접 그린다
    const grd = ctx.createLinearGradient(0, y, 0, y + 46);
    grd.addColorStop(0, COLORS.windowTop);
    grd.addColorStop(1, COLORS.windowBottom);
    ctx.globalAlpha = a * 0.92;
    ctx.fillStyle = grd;
    ctx.fillRect(x, y, w, 46);
    ctx.globalAlpha = a;
    ctx.strokeStyle = COLORS.border;
    ctx.lineWidth = 2;
    ctx.strokeRect(x + 3, y + 3, w - 6, 40);
    ctx.fillStyle = COLORS.accent;
    ctx.fillRect(x + 14, y + 22, 8, 2);
    ctx.fillRect(x + w - 22, y + 22, 8, 2);
    drawText(ctx, b.text, WIDTH / 2, y + 12, { size: 20, bold: true, align: 'center', color: COLORS.text });
    ctx.restore();
  }
}
