// 설화록 이야기 엔진 — 상태(flags·clues·rules·items) + 작은 비동기 연출 명령 집합.
// three·DOM 없이 돌아간다(ctx가 주는 것만 쓴다). 모든 선택적 호출은 방어적으로.

const DIRS = ['down', 'up', 'left', 'right'];

export function facingFrom(dx, dz, cur = 'down') {
  if (Math.abs(dx) < 1e-4 && Math.abs(dz) < 1e-4) return cur;
  if (Math.abs(dx) > Math.abs(dz) * 1.05) return dx > 0 ? 'right' : 'left';
  return dz > 0 ? 'down' : 'up';
}

function safe(fn, fallback = null) {
  try { return fn(); } catch (err) { console.warn('[story]', err); return fallback; }
}

/** 이야기가 직접 만든 캐릭터(주모·변장 호랑이 등)를 코어 Actor와 비슷하게 감싼다 */
export class SimpleActor {
  constructor(char, world, x, z, facing = 'down', data = null) {
    this.char = char;
    this.world = world;
    this.pos = { x, z, y: 0 };
    this.facing = facing;
    this.data = data;
    this.yAbs = null;
    this.scripted = true;
    this.spawned = true;
    safe(() => char.setFacing?.(facing));
    safe(() => char.setAnim?.('idle'));
    this.sync();
  }
  sync() {
    this.pos.y = this.yAbs != null ? this.yAbs : (this.world && this.world.heightAt ? safe(() => this.world.heightAt(this.pos.x, this.pos.z), 0) : 0);
    const o = this.char && this.char.object3d;
    if (o && o.position) o.position.set(this.pos.x, this.pos.y, this.pos.z);
  }
  face(dir) { if (dir && DIRS.includes(dir)) { this.facing = dir; safe(() => this.char.setFacing?.(dir)); } }
  faceToward(x, z) { this.face(facingFrom(x - this.pos.x, z - this.pos.z, this.facing)); }
}

export function newState() {
  return {
    v: 1,
    phase: 'start',      // start → explore → night → morning → done
    flags: {},
    clues: [],           // 찾은 순서
    rules: [],           // K_* 지식
    items: {},
    time: 10,
    outcome: null,       // A_win | A_repel | B_win | B_repel | C
    talked: {},          // npc id → 대화 횟수
    world: {},           // setWorldState 기록(불러오기 때 다시 적용)
  };
}

export class Engine {
  constructor(ctx, defs = {}) {
    this.ctx = ctx;
    this.defs = defs;          // { clues, rules, items }
    this.state = newState();
    this.busyCount = 0;
    this.movers = [];
    this.spawned = {};         // id → SimpleActor
    this.timeTarget = null;
    this.onChange = null;      // 저장·기록 갱신 알림
    this.trace = [];           // 테스트·디버그용 연출 기록
    this.letterboxOn = false;
    this.cutsceneDepth = 0;
    this.instant = !!ctx.__instant;
  }

  get busy() { return this.busyCount > 0; }

  log(kind, data) {
    this.trace.push([kind, data]);
    if (this.trace.length > 4000) this.trace.splice(0, 1000);
  }

  // ---- 실행기 ----
  async run(fn) {
    this.busyCount++;
    try { return await fn(this); }
    catch (err) { console.error('[story] 스크립트 오류', err); this.log('error', String(err && err.stack || err)); return null; }
    finally {
      this.busyCount = Math.max(0, this.busyCount - 1);
      if (!this.busy) {
        if (this.letterboxOn) this.letterbox(false);
        this.changed();
      }
    }
  }

  changed() { if (this.onChange) safe(() => this.onChange()); }

  // ---- 상태 ----
  is(k) { return !!this.state.flags[k]; }
  flag(k, v = true) { this.state.flags[k] = v; this.log('flag', [k, v]); }
  count(item) { return this.state.items[item] | 0; }
  has(item, n = 1) { return this.count(item) >= n; }
  give(item, n = 1, quiet = false) {
    this.state.items[item] = this.count(item) + n;
    this.log('give', [item, n]);
    const label = this.defs.items?.[item] || item;
    if (!quiet) this.toast(n > 1 ? `${label} ${n}개를 얻었다` : `${label}을(를) 얻었다`, 'info');
    this.syncItems();
  }
  take(item, n = 1) {
    this.state.items[item] = Math.max(0, this.count(item) - n);
    if (!this.state.items[item]) delete this.state.items[item];
    this.log('take', [item, n]);
    this.syncItems();
  }
  syncItems() {
    const list = Object.entries(this.state.items)
      .filter(([, n]) => n > 0)
      .map(([id, count]) => ({ id, label: this.defs.items?.[id] || id, count }));
    safe(() => this.ctx.ui?.items?.(list));
  }
  hasClue(id) { return this.state.clues.includes(id); }
  knows(id) { return this.state.rules.includes(id); }
  knowsAll(...ids) { return ids.every((k) => this.knows(k)); }

  learnClue(id, quiet = false) {
    if (this.hasClue(id)) return false;
    this.state.clues.push(id);
    this.log('clue', id);
    const d = this.defs.clues?.[id];
    if (!quiet && d) this.toast(`단서 — ${d.title}`, 'clue');
    this.advanceTime(0.3);
    return true;
  }
  learnRule(id, quiet = false) {
    if (this.knows(id)) return false;
    this.state.rules.push(id);
    this.log('rule', id);
    const d = this.defs.rules?.[id];
    if (!quiet && d) this.toast(`호랑이의 습성 — ${d.title}`, 'rule');
    return true;
  }
  journalNote(text) {
    this.log('journal', text);
    this.toast(text || '사건 기록이 갱신되었다', 'journal');
  }

  // ---- 표현 ----
  toast(text, kind = 'info') {
    this.log('toast', [text, kind]);
    if (this.ctx.ui?.toast) safe(() => this.ctx.ui.toast(text, kind));
    else safe(() => this.ctx.hud?.say?.(text, 2200));
  }
  async say(name, lines) {
    const arr = Array.isArray(lines) ? lines.filter(Boolean) : [lines];
    if (!arr.length) return;
    this.log('say', [name, arr]);
    if (this.ctx.say) { try { await this.ctx.say(name, arr); } catch (err) { console.warn('[story] say', err); } }
  }
  /** options: [{ id, label, hint?, disabled?, when? }] — when===false면 숨김. 고른 id를 돌려준다 */
  async choice(prompt, options) {
    const vis = options.filter((o) => o && o.when !== false);
    if (!vis.length) return null;
    this.log('choice', [prompt, vis.map((o) => o.label)]);
    let idx = -1;
    if (this.ctx.ui?.choice) {
      try { idx = await this.ctx.ui.choice(prompt, vis.map((o) => ({ label: o.label, disabled: !!o.disabled, hint: o.hint }))); }
      catch (err) { console.warn('[story] choice', err); }
    }
    if (!(idx >= 0 && idx < vis.length) || vis[idx].disabled) {
      if (!this.ctx.ui?.choice && prompt) await this.say('', [prompt]);
      idx = vis.findIndex((o) => !o.disabled);
    }
    const picked = vis[idx];
    this.log('picked', picked && picked.id);
    return picked ? picked.id : null;
  }
  async examine(title, text, kind = 'clue') {
    this.log('examine', [title, text]);
    if (this.ctx.ui?.examine) { try { await this.ctx.ui.examine({ title, text, kind }); return; } catch (err) { console.warn('[story] examine', err); } }
    await this.say(title, Array.isArray(text) ? text : [text]);
  }
  async caption(text, ms = 3000) {
    this.log('caption', text);
    if (this.ctx.ui?.caption) { try { await this.ctx.ui.caption(text, ms); return; } catch (err) { console.warn('[story] caption', err); } }
    safe(() => this.ctx.hud?.say?.(text, ms));
    await this.wait(ms);
  }
  letterbox(on) {
    this.letterboxOn = !!on;
    this.log('letterbox', !!on);
    return safe(() => this.ctx.ui?.letterbox?.(!!on));
  }
  async wait(ms) {
    if (this.instant || !ms) { await Promise.resolve(); return; }
    if (this.ctx.wait) { try { await this.ctx.wait(ms); return; } catch { /* fallthrough */ } }
    await new Promise((r) => setTimeout(r, ms));
  }
  async fade(ms, toBlack) {
    this.log('fade', toBlack);
    if (this.ctx.fade) { try { await this.ctx.fade(ms, toBlack); return; } catch (err) { console.warn('[story] fade', err); } }
    await this.wait(ms);
  }
  setTime(h) {
    this.state.time = h;
    this.timeTarget = null;
    this.log('time', h);
    safe(() => this.ctx.setTime?.(h));
  }
  /** 시간을 부드럽게 흘린다(update에서) */
  advanceTime(dh, cap = 16.8) {
    const base = this.timeTarget ?? this.state.time;
    const to = Math.min(cap, base + dh);
    if (to <= base) return;
    this.timeTarget = to;
  }
  setWorldState(k, v) {
    this.state.world[k] = v;
    this.log('world', [k, v]);
    safe(() => this.ctx.setWorldState?.(k, v));
  }

  // ---- 배우 ----
  actor(id) {
    if (!id) return null;
    if (typeof id === 'object') return id;
    if (id === 'player') return this.ctx.player;
    return this.spawned[id] || this.ctx.npcs?.[id] || null;
  }
  spawn(id, kind, pos, facing = 'down', data = null) {
    if (this.spawned[id]) return this.spawned[id];
    let char = null;
    try { char = this.ctx.makeChar?.(kind); } catch (err) { console.warn('[story] makeChar', kind, err); }
    if (!char) char = { object3d: null, setFacing() {}, setAnim() {}, update() {} };
    if (char.object3d && this.ctx.scene?.add) safe(() => this.ctx.scene.add(char.object3d));
    const a = new SimpleActor(char, this.ctx.world, pos.x, pos.z, facing, data);
    this.spawned[id] = a;
    this.log('spawn', [id, kind]);
    return a;
  }
  despawn(id) {
    const a = this.spawned[id];
    if (!a) return;
    delete this.spawned[id];
    this.movers = this.movers.filter((m) => m.a !== a);
    safe(() => a.char.object3d?.removeFromParent?.());
    safe(() => a.char.dispose?.());
    this.log('despawn', id);
  }
  anim(who, name, opts) {
    const a = this.actor(who);
    if (!a || !a.char) return;
    this.log('anim', [a === this.ctx.player ? 'player' : (a.data?.id || '?'), name]);
    safe(() => a.char.setAnim?.(name, opts || {}));
  }
  /** 이야기가 붙잡은 NPC는 코어가 배회·돌아보기를 하지 않는다 */
  hold(who, on = true) { const a = this.actor(who); if (a) a.scripted = !!on || !!a.spawned; }
  face(who, dirOrPos) {
    const a = this.actor(who);
    if (!a) return;
    if (typeof dirOrPos === 'string') a.face?.(dirOrPos);
    else if (dirOrPos) {
      const p = dirOrPos.pos || dirOrPos;
      if (a.faceToward) a.faceToward(p.x, p.z);
      else a.face?.(facingFrom(p.x - a.pos.x, p.z - a.pos.z, a.facing));
    }
  }
  /** p.y가 있으면 그 높이(절대)에 띄운다(나무 위 등) */
  place(who, p) {
    const a = this.actor(who);
    if (!a || !p) return;
    a.pos.x = p.x; a.pos.z = p.z;
    if (a.home) { a.home.x = p.x; a.home.z = p.z; }
    a.yAbs = p.y != null ? p.y : null;
    safe(() => a.sync?.());
    this.lift(a);
  }
  lift(a) {
    if (a.yAbs == null) return;
    const o = a.char?.object3d;
    a.pos.y = a.yAbs;
    if (o?.position) o.position.y = a.yAbs;
  }
  teleportPlayer(p) {
    this.log('teleport', p);
    if (this.ctx.teleport) safe(() => this.ctx.teleport({ x: p.x, z: p.z }));
    else this.place('player', p);
    if (p.face) this.ctx.player?.face?.(p.face);
  }
  /** 경로를 따라 걷는다. path: [{x,z}...], speed m/s. 끝나면 resolve */
  moveActor(who, path, speed = 2.2, anim = 'walk', endAnim = 'idle') {
    const a = this.actor(who);
    if (!a || !path || !path.length) return Promise.resolve();
    this.movers = this.movers.filter((m) => { if (m.a === a) { m.resolve(); return false; } return true; });
    if (this.instant) {
      const last = path[path.length - 1];
      a.pos.x = last.x; a.pos.z = last.z; a.yAbs = null; safe(() => a.sync?.());
      if (endAnim) this.anim(a, endAnim);
      return Promise.resolve();
    }
    a.yAbs = null;
    let total = 0, px = a.pos.x, pz = a.pos.z;
    for (const p of path) { total += Math.hypot(p.x - px, p.z - pz); px = p.x; pz = p.z; }
    this.anim(a, anim);
    return new Promise((resolve) => {
      const m = { a, path: path.slice(), speed, endAnim, resolve, left: total / speed * 2 + 1.5 };
      this.movers.push(m);
    });
  }
  updateMovers(dt) {
    if (!this.movers.length) return;
    const done = [];
    for (const m of this.movers) {
      let step = m.speed * dt;
      m.left -= dt;
      while (step > 0 && m.path.length) {
        const t = m.path[0];
        const dx = t.x - m.a.pos.x, dz = t.z - m.a.pos.z, d = Math.hypot(dx, dz);
        if (d <= step) { m.a.pos.x = t.x; m.a.pos.z = t.z; m.path.shift(); step -= d; }
        else {
          m.a.pos.x += dx / d * step; m.a.pos.z += dz / d * step;
          m.a.face?.(facingFrom(dx, dz, m.a.facing));
          step = 0;
        }
      }
      if (m.left <= 0 && m.path.length) { const l = m.path[m.path.length - 1]; m.a.pos.x = l.x; m.a.pos.z = l.z; m.path.length = 0; }
      safe(() => m.a.sync?.());
      if (!m.path.length) done.push(m);
    }
    for (const m of done) {
      this.movers.splice(this.movers.indexOf(m), 1);
      if (m.endAnim) this.anim(m.a, m.endAnim);
      m.resolve();
    }
  }

  // ---- 카메라 ----
  cameraOverride(params) {
    if (this.ctx.rig) this.ctx.rig.override = params || null;
    this.log('camera', params);
  }
  cameraFocus(pos) {
    this.log('focus', pos);
    if (this.ctx.cameraFocus) safe(() => this.ctx.cameraFocus(pos));
    else if (this.ctx.rig) this.ctx.rig.focus = pos || null;
  }

  // ---- 전투 ----
  /** → 'win' | 'repelled' | 'escaped' | 'lose' (retreated는 repelled로 맞춘다) */
  async combat(arena, opts = {}) {
    const c = this.ctx.combat;
    this.log('combat', [arena && (arena.id || arena.name), opts.mods]);
    if (!c || !c.start || !arena) {
      const r = opts.fallbackResult || 'win';
      this.log('combatResult', r);
      return r;
    }
    let res = null;
    try {
      const ret = c.start(arena, { noResultCard: true, ...opts });
      if (ret && typeof ret.then === 'function') res = await ret;
      else if (c.finished && typeof c.finished.then === 'function') res = await c.finished;
      else {
        while (c.active && !c.result) await new Promise((r) => setTimeout(r, 100));
        res = c.result;
      }
    } catch (err) {
      console.error('[story] 전투 오류', err);
      res = opts.fallbackResult || 'win';
    }
    if (res === 'retreated' || res === 'retreat') res = 'repelled';
    if (!res) res = 'escaped';
    this.log('combatResult', res);
    return res;
  }
  endCombat() { safe(() => { if (this.ctx.combat && !this.ctx.combat.active) this.ctx.combat.reset?.(); }); }

  // ---- 프레임 ----
  update(dt) {
    this.updateMovers(dt);
    if (this.timeTarget != null) {
      const cur = this.state.time;
      const next = Math.min(this.timeTarget, cur + dt * 0.25); // 1초에 15분
      this.state.time = next;
      safe(() => this.ctx.setTime?.(next));
      if (next >= this.timeTarget) this.timeTarget = null;
    }
    const cam = this.ctx.camera;
    for (const id in this.spawned) {
      const a = this.spawned[id];
      safe(() => a.char.update?.(dt, cam));
      this.lift(a);
    }
  }
}
