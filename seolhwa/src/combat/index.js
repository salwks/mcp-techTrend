// 설화록 2단계 — 전투 모듈 (COMBAT.md §4.1). 플레이어 대 호랑이 한 마리.
// 논리(battle/player/tiger/projectiles/hitbox/tuning)는 three·DOM 없이 돌아가고, 여기서 장면·FX·HUD·입력에 잇는다.
import * as THREE from 'three';
import { Battle, makeEnv } from './battle.js';
import { T, syncTimings, applyScale } from './tuning.js';
import { makeArrowMesh, makeBaitMesh } from './meshes.js';

const ACTIONS = ['attack', 'dodge', 'guard', 'bow', 'item'];
const BODY_FX = new Set(['hit', 'heavyHit', 'block']);
const TIGER_NAME = '호랑이';

const RESULT_TEXT = {
  win: ['호랑이를 쓰러뜨렸다', '산이 조용해졌다. 오늘 밤 마을 사람들은 편히 잠들 것이다.'],
  repelled: ['호랑이는 산속으로 물러났다', '죽이지 않고 물리쳤다. 하지만 밤이 되면 산 너머에서 그 울음소리가 여전히 들려올 것이다.'],
  escaped: ['호랑이의 영역에서 벗어났다', '호랑이는 영역 끝에서 으르렁거릴 뿐, 더는 쫓아오지 않았다.'],
  retreated: ['호랑이가 물러갔다', '호랑이는 "내 영역에서 나가라"는 듯 포효하고 산으로 돌아갔다. 그 정체만은 똑똑히 보았다.'],
  lose: ['정신이 아득해진다…', '마지막으로 본 것은 먹빛 줄무늬와 번뜩이는 눈이었다.'],
};

// 캐릭터 호출은 모두 방어적으로(다른 모듈이 작업 중일 수 있음)
function safe(fn) { try { return fn(); } catch (err) { if (!safe.warned) { safe.warned = true; console.warn('[combat]', err); } return null; } }

export function createCombat(ctx) {
  const { scene, world, camera, hud, input, player } = ctx;
  const fxRoot = ctx.fx;
  const options = { telegraph: true, ranges: false, aimAssist: true, hitStop: true };

  let tigerChar = null;
  let arena = null;
  let active = false;
  let result = null;
  let ending = false;
  let runId = 0;
  const handles = new Set();
  const lastHud = { hp: -1, st: -1, thp: -1, arrows: -1, bait: -1 };

  const heightAt = (x, z) => (world && world.heightAt ? world.heightAt(x, z) : 0);

  function charOf(who) { return who === 'player' ? player.char : tigerChar; }

  function setAnim(c, name, o) {
    if (!c) return;
    let speed = 1;
    if (o && o.dur > 0 && typeof c.animDuration === 'function') {
      const d = safe(() => c.animDuration(name));
      if (d > 0) speed = Math.min(3, Math.max(0.3, d / o.dur));
    }
    safe(() => c.setAnim(name, { restart: !!(o && o.restart), speed }));
  }

  function spawnFx(type, x, z, o) {
    const fc = fxRoot && fxRoot.combat;
    if (!fc || typeof fc.spawn !== 'function') return null;
    const opts = { ...o };
    if (o && o.dir) opts.dir = new THREE.Vector3(o.dir.x, 0, o.dir.z);
    if (o && o.arc) opts.arc = o.arc * Math.PI / 180; // 논리는 도(°), fx는 라디안
    const pos = new THREE.Vector3(x, heightAt(x, z) + (BODY_FX.has(type) ? 1.0 : 0), z);
    const h = safe(() => fc.spawn(type, pos, opts));
    if (h) handles.add(h);
    return h;
  }

  function removeFx(h) {
    if (!h) return;
    handles.delete(h);
    safe(() => h.remove && h.remove());
  }

  // ---- 화살·떡 메시 ----
  function spawnProj(p) {
    const m = p.kind === 'arrow' ? makeArrowMesh() : makeBaitMesh();
    p.view = m;
    if (p.kind === 'arrow') m.rotation.y = Math.atan2(p.dx, p.dz);
    syncProj(p);
    scene.add(m);
  }
  function removeProj(p) {
    if (p.view) { p.view.removeFromParent(); p.view = null; }
  }
  function syncProj(p) {
    const m = p.view;
    if (!m) return;
    m.position.set(p.x, heightAt(p.x, p.z) + p.y, p.z);
    if (p.kind === 'arrow' && p.stuck) m.rotation.x = 0.45; // 땅·바위에 꽂힘
    if (p.kind === 'bait' && !p.landed) m.rotation.y += 0.25;
  }

  const env = makeEnv({
    heightAt,
    blocked: (x, z, r) => (ctx.blocked ? ctx.blocked(x, z, r) : false),
    anim: (who, name, o) => setAnim(charOf(who), name, o),
    face: (who, dir) => {
      if (who === 'player') safe(() => player.face(dir));
      else if (tigerChar) safe(() => tigerChar.setFacing(dir));
    },
    flash: (who, color, ms) => { const c = charOf(who); if (c && c.flash) safe(() => c.flash(color, ms)); },
    fx: spawnFx,
    fxRemove: removeFx,
    say: (text, ms) => { if (hud && hud.say) safe(() => hud.say(text, ms)); },
    hitStop: (ms) => { if (options.hitStop !== false && ctx.hitStop) ctx.hitStop(ms); },
    shake: (p, ms) => { if (ctx.shake) ctx.shake(p, ms); },
    spawnProj, removeProj,
    options,
  });
  const battle = new Battle(env);

  // ---- 입력 어댑터: held/released가 없으면 눌림만으로 흉내 ----
  const prevHeld = Object.create(null);
  const curHeld = Object.create(null);
  const ctl = {
    hasHeld: typeof input.held === 'function',
    move: { x: 0, z: 0 },
    pressed: (a) => !!(input.pressed && input.pressed(a)),
    held: (a) => !!curHeld[a],
    released: (a) => {
      if (typeof input.released === 'function') return !!input.released(a) || (prevHeld[a] && !curHeld[a]);
      return ctl.hasHeld ? (prevHeld[a] && !curHeld[a]) : ctl.pressed(a);
    },
    running: () => !!(input.running && input.running()),
  };
  function readInput() {
    for (const a of ACTIONS) {
      prevHeld[a] = curHeld[a];
      curHeld[a] = ctl.hasHeld ? !!input.held(a) : false;
    }
    const mv = input.moveVector ? input.moveVector() : { x: 0, z: 0 };
    const k = mv.mag ?? 1;
    ctl.move.x = mv.x * k; ctl.move.z = mv.z * k;
  }

  function updateHud(force) {
    if (!hud) return;
    const pl = battle.player, tg = battle.tiger;
    const hp = Math.max(0, Math.round(pl.hp * 10) / 10), st = Math.round(pl.st);
    if (force || hp !== lastHud.hp || st !== lastHud.st) {
      lastHud.hp = hp; lastHud.st = st;
      safe(() => hud.setPlayer(hp, T.player.hp, st, T.player.stamina));
    }
    const thp = Math.max(0, Math.round(tg.hp));
    if (force || thp !== lastHud.thp) {
      lastHud.thp = thp;
      safe(() => hud.setFoe(TIGER_NAME, thp, T.tiger.hp));
    }
    if (force || pl.arrows !== lastHud.arrows || pl.bait !== lastHud.bait) {
      lastHud.arrows = pl.arrows; lastHud.bait = pl.bait;
      safe(() => hud.setAmmo({ arrows: pl.arrows, bait: pl.bait }));
    }
  }

  // 실제 지면 이동 속도를 캐릭터에 알려 걸음이 미끄러지지 않게
  const lastPos = { px: 0, pz: 0, tx: 0, tz: 0 };
  function reportSpeed(dt) {
    const pl = battle.player, tg = battle.tiger;
    if (dt > 1e-4) {
      const ps = Math.hypot(pl.pos.x - lastPos.px, pl.pos.z - lastPos.pz) / dt;
      const ts = Math.hypot(tg.pos.x - lastPos.tx, tg.pos.z - lastPos.tz) / dt;
      if (player.char.setMoveSpeed) safe(() => player.char.setMoveSpeed(Math.min(ps, 12)));
      if (tigerChar && tigerChar.setMoveSpeed) safe(() => tigerChar.setMoveSpeed(Math.min(ts, 20)));
    }
    lastPos.px = pl.pos.x; lastPos.pz = pl.pos.z; lastPos.tx = tg.pos.x; lastPos.tz = tg.pos.z;
  }

  function syncActors() {
    const pl = battle.player, tg = battle.tiger;
    player.pos.x = pl.pos.x; player.pos.z = pl.pos.z;
    player.sync();
    if (tigerChar) {
      tigerChar.object3d.position.set(tg.pos.x, heightAt(tg.pos.x, tg.pos.z) + tg.y, tg.pos.z);
      tigerChar.object3d.visible = tg.state !== 'gone';
    }
  }

  function clearScene() {
    battle.clearProjectiles();
    for (const h of handles) safe(() => h.remove && h.remove());
    handles.clear();
    if (fxRoot && fxRoot.combat && fxRoot.combat.clear) safe(() => fxRoot.combat.clear());
    if (tigerChar) {
      tigerChar.object3d.removeFromParent();
      if (tigerChar.dispose) safe(() => tigerChar.dispose());
      tigerChar = null;
    }
  }

  // 이번 싸움의 결과 알림(combat.finished 약속 + opts.onEnd)
  let finishedP = Promise.resolve(null), resolveFinished = null, runOpts = {};
  function endFight(kind) {
    const r = resolveFinished, cb = runOpts.onEnd;
    resolveFinished = null;
    if (r) r(kind);
    if (cb) safe(() => cb(kind));
  }

  async function showResult(kind) {
    const my = runId;
    if (runOpts.noResultCard) {
      // 이야기가 결말을 직접 보여준다: 카드 없이 끝냄. 호랑이 모습은 다음 start/reset까지 남겨 둔다
      active = false;
      safe(() => hud && hud.setFoe(null));
      if (player.char.setArmed) safe(() => player.char.setArmed(false));
      if (player.char.setMoveSpeed) safe(() => player.char.setMoveSpeed(null));
      endFight(kind);
      return;
    }
    const [title, text] = RESULT_TEXT[kind] || [kind, ''];
    if (hud && hud.result) {
      try { await hud.result(kind, title, text); } catch (err) { console.warn('[combat] hud.result', err); }
    } else {
      await new Promise((r) => setTimeout(r, 2500));
    }
    if (my === runId) { endFight(kind); combat.reset(); }
  }

  function findArena(a) {
    const list = world.arenas || [];
    if (typeof a === 'string') return list.find((x) => x.id === a || x.name === a) || null;
    return a || null;
  }

  const combat = {
    options,
    get active() { return active; },
    set active(v) { active = !!v; }, // 코어가 오류 시 false로 끈다
    get result() { return result; },
    get battle() { return battle; },   // 디버그·QA용
    get tiger() { return tigerChar; },
    get finished() { return finishedP; }, // 현재 싸움의 결과로 풀리는 약속(start마다 새로)

    // opts: { mods:{stunned, hpRatio, enraged, disguised, firstEncounter}, retreatAt:{hpRatio, seconds},
    //         allowFlee, noResultCard, onEnd(result), placePlayer(기본 true), focus:{x,z}, retreatTo:{x,z} }
    start(a, opts = {}) {
      if (active || tigerChar) this.reset();
      arena = findArena(a) || arena || (world.arenas && world.arenas[0]);
      if (!arena) { console.warn('[combat] arena 없음'); return finishedP; }
      runId++;
      runOpts = opts || {};
      finishedP = new Promise((r) => { resolveFinished = r; });
      const mods = runOpts.mods || {};
      result = null; ending = false;
      tigerChar = ctx.makeChar('tiger');
      scene.add(tigerChar.object3d);
      if (tigerChar.setMode && player.char.mode) safe(() => tigerChar.setMode(player.char.mode));
      // 캐릭터 애니메이션 길이·크기에 판정을 맞춘다(캐릭터 모듈이 바뀌어도 따라가게)
      const durOf = (name) => {
        const c = name === 'swipe' || name === 'pounce' ? tigerChar : player.char;
        return c && typeof c.animDuration === 'function' ? safe(() => c.animDuration(name)) || 0 : 0;
      };
      syncTimings(durOf);
      applyScale(player.char.radius || T.player.radius, tigerChar.radius || 1.0);
      const anchors = world.anchors || {};
      const territory = (world.arenas || []).find((x) => x.id === 'territory');
      battle.start(arena, null, {
        mods,
        retreatAt: runOpts.retreatAt,
        allowFlee: runOpts.allowFlee,
        playerPos: runOpts.placePlayer === false ? { x: player.pos.x, z: player.pos.z } : null,
        focus: runOpts.focus || (arena.id === 'house_yard' ? anchors.big_tree || null : null),
        retreatTo: runOpts.retreatTo || (arena.id !== 'territory' && territory ? { x: territory.x, z: territory.z } : null),
      });
      if (mods.disguised && tigerChar.setVariant) safe(() => tigerChar.setVariant('disguised'));
      lastPos.px = battle.player.pos.x; lastPos.pz = battle.player.pos.z;
      lastPos.tx = battle.tiger.pos.x; lastPos.tz = battle.tiger.pos.z;
      if (player.char.setArmed) safe(() => player.char.setArmed(true));
      syncActors();
      safe(() => tigerChar.update(0, camera));
      active = true;
      for (const k of ACTIONS) { prevHeld[k] = false; curHeld[k] = false; }
      updateHud(true);
      if (!mods.stunned) {
        env.say(mods.firstEncounter ? '숲 그늘에서 거대한 호랑이가 모습을 드러냈다!'
          : arena.id === 'house_yard' ? '호랑이가 마당으로 뛰어들었다! 아이들이 있는 나무를 노린다.'
            : '숲이 조용해졌다… 호랑이가 낮게 원을 그리며 다가온다.', 2600);
      }
      return finishedP;
    },

    reset() {
      runId++;
      if (resolveFinished) endFight(null); // 싸움 도중 취소
      clearScene();
      active = false;
      ending = false;
      if (hud && hud.setFoe) safe(() => hud.setFoe(null));
      if (player.char.setArmed) safe(() => player.char.setArmed(false));
      if (player.char.setMoveSpeed) safe(() => player.char.setMoveSpeed(null)); // 코어 이동으로 돌려줌
      safe(() => player.char.setAnim('idle', { restart: true }));
    },

    update(dt) {
      if (!active) return;
      readInput();
      if (!ending) {
        battle.update(dt, ctl);
        if (battle.outcome) {
          ending = true;
          result = battle.outcome;
          if (result === 'escaped' || result === 'repelled') safe(() => hud && hud.setFoe(null));
          showResult(result);
        }
      }
      reportSpeed(dt);
      syncActors();
      for (const p of battle.arrows) syncProj(p);
      for (const p of battle.baits) syncProj(p);
      if (tigerChar) safe(() => tigerChar.update(dt, camera));
      updateHud(false);
    },

    setOption(k, v) {
      if (!(k in options)) return;
      options[k] = !!v;
      if (k === 'telegraph' && !v) { /* 이미 떠 있는 예고는 스스로 사라진다 */ }
    },
  };
  return combat;
}
