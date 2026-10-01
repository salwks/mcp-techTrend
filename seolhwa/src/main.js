// 설화록 비주얼 프로토타입 — 진입점
import * as THREE from 'three';
import { Input } from './core/input.js';
import { CameraRig } from './core/camera.js';
import { Occlusion } from './core/occlusion.js';
import { Actor, playerSpeed, findTalkTarget } from './core/actors.js';
import { Dialog, PlaceBanner } from './core/dialog.js';
import { Panel } from './core/panel.js';
import { Hud } from './core/hud.js';
import { blocked, inBox } from './core/motion.js';
import { fallbackWorld, fallbackCharacter, fallbackFX } from './core/fallback.js';

async function load(path, name) {
  try {
    return await import(path);
  } catch (err) {
    console.warn(`[설화록] ${name} 모듈을 불러오지 못해 임시 대체물을 씁니다.`, err);
    return null;
  }
}

const canvas = document.getElementById('view');
const hudRoot = document.getElementById('hud');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(30, 1, 0.5, 600);

const [worldMod, charMod, fxMod, combatMod, storyMod, uiMod] = await Promise.all([
  load('./world/index.js', 'world'),
  load('./chars/index.js', 'chars'),
  load('./fx/index.js', 'fx'),
  load('./combat/index.js', 'combat'),
  load('./story/index.js', 'story'),
  load('./ui/index.js', 'ui'),
]);

// 캐릭터 그림(컷아웃 부위·프레임 그림)을 미리 구워 첫 동작에서 멈칫하지 않게 한다
async function bakeCharacters() {
  if (!charMod) return;
  const veil = document.createElement('div');
  veil.className = 'loading';
  veil.innerHTML = '<div class="l-seal">설화록</div><div class="l-text">그림을 펼치는 중…</div>';
  hudRoot.appendChild(veil);
  const paint = () => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
  await paint();
  try {
    charMod.preloadCharacters?.();
    const txt = veil.querySelector('.l-text');
    if (charMod.prebakeFrames) {
      // 워커에서 굽고, 진행률만 표시 (화면이 멈추지 않음)
      await charMod.prebakeFrames((done, total) => {
        const pct = total ? Math.round((done / total) * 100) : 100;
        txt.textContent = `그림을 펼치는 중… ${pct}%`;
      });
    } else {
      for (const k of charMod.FRAME_KINDS || []) {
        txt.textContent = k === 'tiger' ? '호랑이를 그리는 중…' : '나그네를 그리는 중…';
        await paint();
        charMod.bakeAllFrames?.([k]);
      }
    }
  } catch (err) { console.error('[설화록] 캐릭터 그림 굽기 오류', err); }
  veil.classList.add('done');
  setTimeout(() => veil.remove(), 600);
}
await bakeCharacters();

let world;
try { world = worldMod ? worldMod.buildWorld(scene) : fallbackWorld(scene); }
catch (err) { console.error('[설화록] buildWorld 오류', err); world = fallbackWorld(scene); }
world.colliders ||= [];
world.npcs ||= [];

// 만들어진 모든 캐릭터를 기억해 그림 방식(프레임/컷아웃)을 한 번에 바꿀 수 있게 한다
const allChars = [];
let renderStyle = null; // null = 캐릭터 모듈 기본값
const makeChar = (kind) => {
  let c = null;
  try { if (charMod) c = charMod.createCharacter(kind); }
  catch (err) { console.error('[설화록] createCharacter 오류', kind, err); }
  if (!c) c = fallbackCharacter(kind);
  if (renderStyle && c.setRenderStyle) c.setRenderStyle(renderStyle);
  allChars.push(c);
  return c;
};
function setRenderStyle(style) {
  renderStyle = style;
  for (const c of allChars) if (c.setRenderStyle) c.setRenderStyle(style);
}

let fx;
try { fx = fxMod ? fxMod.createFX({ renderer, scene, camera, world }) : fallbackFX({ renderer, scene, camera, world }); }
catch (err) { console.error('[설화록] createFX 오류', err); fx = fallbackFX({ renderer, scene, camera, world }); }

// ---- 캐릭터 배치 ----
const player = new Actor(makeChar('player'), world, world.spawn.x, world.spawn.z, { facing: 'up' });
scene.add(player.char.object3d);
const npcs = world.npcs.map((n) => {
  const a = new Actor(makeChar(n.kind), world, n.x, n.z, { facing: n.facing, wander: n.wander, data: n });
  scene.add(a.char.object3d);
  return a;
});
const actors = [player, ...npcs];
// NPC가 서 있는 자리는 플레이어가 통과하지 못하게(충돌체로 추가하지 않고 actor 간 판정으로 처리)

// ---- 시스템 ----
const input = new Input(hudRoot);
const rig = new CameraRig(camera, world);
const occlusion = new Occlusion(camera, world);
const dialog = new Dialog(hudRoot);
const banner = new PlaceBanner(hudRoot);
const prompt = document.createElement('div');
prompt.className = 'prompt';
prompt.hidden = true;
hudRoot.appendChild(prompt);

let spriteMode = '4dir';
let silhouette = true;

function nearestFree(x, z, r) {
  for (let rad = 0; rad < 12; rad += 0.5) {
    for (let a = 0; a < Math.PI * 2; a += Math.PI / 8) {
      const px = x + Math.cos(a) * rad, pz = z + Math.sin(a) * rad;
      if (!blocked(world, px, pz, r)) return { x: px, z: pz };
      if (rad === 0) break;
    }
  }
  return { x, z };
}

function warps() {
  const list = [{ name: '시작 지점', x: world.spawn.x, z: world.spawn.z }];
  const seen = new Set(list.map((w) => w.name));
  for (const zn of [...(world.cameraZones || []), ...(world.interiors || [])]) {
    if (!zn.name || seen.has(zn.name)) continue;
    seen.add(zn.name);
    list.push({ name: zn.name, x: (zn.minX + zn.maxX) / 2, z: (zn.minZ + zn.maxZ) / 2 });
  }
  return list;
}

function teleport(w) {
  const p = nearestFree(w.x, w.z, player.char.radius);
  player.pos.x = p.x;
  player.pos.z = p.z;
  player.sync();
  rig.update(0, player.pos, player.facing, currentInterior(), true);
}

const panel = new Panel(hudRoot, {
  getTime: () => fx.getTime(),
  setTime: (t) => fx.setTime(t),
  getOptions: () => fx.getOptions(),
  setOption: (k, v) => fx.setOption(k, v),
  setSpriteMode: (m) => { spriteMode = m; actors.forEach((a) => a.char.setMode(m)); },
  setSilhouette: (on) => { silhouette = on; actors.forEach((a) => a.char.setSilhouette(on)); },
  setOccluderFade: (on) => { occlusion.enabled = on; },
  setCameraZones: (on) => { rig.mode = on ? 'zones' : 'fixed'; },
  warps,
  warp: teleport,
});

// 0(낮) ~ 1(밤): 18.5~19.5시에 켜지고 5~6.5시에 꺼진다
function nightFactor(h) {
  const s = (a, b, x) => Math.min(1, Math.max(0, (x - a) / (b - a)));
  return h >= 12 ? s(18.5, 19.5, h) : 1 - s(5, 6.5, h);
}

// ---- 전투 ----
const hud = new Hud(hudRoot);
let hitStopLeft = 0;
let combat = null;
let arenaCooldown = 0;
const npcTiger = npcs.find((n) => n.data && (n.data.id === 'tiger' || n.data.kind === 'tiger'));
if (combatMod && world.arenas && world.arenas.length) {
  try {
    combat = combatMod.createCombat({
      scene, world, camera, fx, hud, input, player, makeChar,
      hitStop: (ms) => { if (combatOpts.hitStop !== false) hitStopLeft = Math.max(hitStopLeft, ms / 1000); },
      shake: (power, ms) => rig.shake(power, ms),
      blocked: (x, z, r) => blocked(world, x, z, r),
    });
  } catch (err) { console.error('[설화록] createCombat 오류', err); combat = null; }
}
const combatOpts = combat ? { ...(combat.options || {}) } : {};
if (charMod && charMod.FRAME_KINDS && charMod.FRAME_KINDS.length) {
  panel.addSection('캐릭터 그림 방식 (주인공·호랑이)', [
    { label: '프레임 · 손그림', onClick: () => setRenderStyle('frames') },
    { label: '컷아웃 · 관절', onClick: () => setRenderStyle('cutout') },
  ]);
}
if (combat) {
  const opt = (id, label) => ({ id, label, checked: combatOpts[id] !== false, onChange: (v) => { combatOpts[id] = v; combat.setOption(id, v); } });
  panel.addSection('호랑이 전투', [
    opt('telegraph', '공격 예고 표시(바닥·문구)'),
    opt('ranges', '내 공격 범위 표시'),
    opt('aimAssist', '조준 보정'),
    opt('hitStop', '타격 멈춤(히트스톱)'),
    { label: '싸움터로 이동', onClick: () => { const a = world.arenas[0]; teleport({ x: a.playerStart.x, z: a.playerStart.z + 6 }); } },
  ]);
}
let combatArena = null;
let inCombatUI = false;
if (combat) {
  const origStart = combat.start.bind(combat);
  combat.start = (arena, opts) => { combatArena = arena; return origStart(arena, opts); };
}
function arenaAllowed(arena) {
  if (story && story.allowArena) { try { return !!story.allowArena(arena); } catch { return false; } }
  return arena === world.arenas[0];
}
function updateCombat(dt) {
  if (!combat) return false;
  arenaCooldown = Math.max(0, arenaCooldown - dt);
  if (!combat.active && arenaCooldown <= 0 && !hud.resultOpen && !dialog.open && !(story && story.busy) && !(ui && ui.isModal)) {
    for (const arena of world.arenas) {
      const inside = Math.hypot(player.pos.x - arena.x, player.pos.z - arena.z) < arena.radius - 1;
      if (inside && arenaAllowed(arena)) { combat.start(arena); break; }
    }
  }
  if (combat.active) {
    if (!inCombatUI) {
      inCombatUI = true;
      hud.combatMode(true);
      input.setCombat(true);
      rig.override = (combatArena && combatArena.camera) || null;
      if (npcTiger) npcTiger.char.object3d.visible = false;
    }
    try { combat.update(dt); } catch (err) { console.error('[설화록] combat.update 오류', err); combat.active = false; }
    hud.tick(dt);
    if (!combat.active) arenaCooldown = 1.5;
    return true;
  }
  if (inCombatUI && !hud.resultOpen) {
    inCombatUI = false;
    hud.combatMode(false);
    input.setCombat(false);
    rig.override = null;
    if (npcTiger && !(story && story.hideIdleTiger)) npcTiger.char.object3d.visible = true;
  }
  return hud.resultOpen;
}

// ---- 이야기·UI ----
let ui = null;
try { ui = uiMod ? uiMod.createUI(hudRoot) : null; } catch (err) { console.error('[설화록] createUI 오류', err); ui = null; }
const fadeEl = document.createElement('div');
fadeEl.className = 'fade';
hudRoot.appendChild(fadeEl);
const waitMs = (ms) => new Promise((r) => setTimeout(r, ms));
const npcById = {};
for (const n of npcs) if (n.data && n.data.id) npcById[n.data.id] = n;
let story = null;
if (storyMod) {
  try {
    story = storyMod.createStory({
      scene, world, camera, rig, fx, hud, ui, input, combat, player, npcs: npcById, makeChar,
      say: (name, lines) => new Promise((resolve) => dialog.show(name, Array.isArray(lines) ? lines : [lines], resolve)),
      setTime: (h) => { fx.setTime(h); panel.syncTime(); },
      getTime: () => fx.getTime(),
      fade: (ms = 600, toBlack = true) => new Promise((resolve) => {
        fadeEl.style.transitionDuration = `${ms}ms`;
        fadeEl.classList.toggle('on', toBlack);
        setTimeout(resolve, ms);
      }),
      teleport: (p) => teleport(p),
      wait: waitMs,
      setWorldState: (k, v) => { try { world.setState?.(k, v); } catch (err) { console.error('[설화록] setState 오류', k, err); } },
    });
  } catch (err) { console.error('[설화록] createStory 오류', err); story = null; }
}
if (story && ui && ui.setJournalProvider) ui.setJournalProvider(() => story.journal());
if (story) {
  panel.addSection('사건', [
    { label: '사건 처음부터', onClick: () => { try { story.restart(); } catch (err) { console.error(err); } } },
    { label: '사건 기록 열기 (R)', onClick: () => ui && ui.journalToggle(() => story.journal()) },
  ]);
}

// 조사·대화 대상: 이야기 모듈이 있으면 그쪽 목록, 없으면 NPC 대화
function findStoryTarget() {
  let list;
  try { list = story.interactTargets() || []; } catch { return null; }
  const dir = { down: [0, 1], up: [0, -1], left: [-1, 0], right: [1, 0] }[player.facing];
  let best = null, bestScore = Infinity;
  for (const t of list) {
    const dx = t.x - player.pos.x, dz = t.z - player.pos.z;
    const d = Math.hypot(dx, dz);
    const r = t.radius ?? 1.8;
    if (d > r) continue;
    const front = (dx * dir[0] + dz * dir[1]) / (d || 1);
    const score = d - front * 0.6;
    if (score < bestScore) { best = t; bestScore = score; }
  }
  return best;
}

function currentInterior() {
  return (world.interiors || []).find((i) => inBox(i, player.pos.x, player.pos.z)) || null;
}

function resize() {
  const w = canvas.clientWidth, h = canvas.clientHeight;
  camera.aspect = w / Math.max(1, h);
  camera.updateProjectionMatrix();
  fx.resize(w, h);
}
new ResizeObserver(resize).observe(canvas);
resize();

// ---- 루프 ----
const focus = new THREE.Vector3();
const clock = new THREE.Clock();
let time = 0;
let talkTarget = null;
let fpsAcc = 0, fpsFrames = 0;
rig.update(0, player.pos, player.facing, null, true);

function frame() {
  const rawDt = Math.min(0.05, clock.getDelta());
  let dt = rawDt;
  if (hitStopLeft > 0) { hitStopLeft -= rawDt; dt = rawDt * 0.04; }
  time += dt;

  if (input.pressed('panel')) panel.toggle();
  if (input.pressed('time')) { fx.setTime((Math.floor(fx.getTime() / 6) * 6 + 6) % 24); panel.syncTime(); }

  if (input.pressed('journal') && ui && story && !dialog.open) ui.journalToggle(() => story.journal());
  if (story) { try { story.update(dt); } catch (err) { console.error('[설화록] story.update 오류', err); } }
  const fighting = updateCombat(dt);
  const modal = ui && ui.isModal;
  if (fighting) {
    talkTarget = null;
  } else if (dialog.open) {
    if (input.pressed('act') || input.pressed('cancel')) dialog.advance();
    if (!(story && story.busy)) player.char.setAnim('idle');
  } else if (modal || (story && story.busy)) {
    talkTarget = null;
    if (!(story && story.busy)) player.char.setAnim('idle');
  } else if (story) {
    const mv = input.moveVector();
    const speed = playerSpeed(input.running()) * (mv.mag ?? 1);
    const moved = player.step(dt, mv.x, mv.z, speed, actors);
    player.char.setAnim(moved ? (input.running() ? 'run' : 'walk') : 'idle');
    talkTarget = findStoryTarget();
    if (talkTarget && input.pressed('act')) {
      const t = talkTarget;
      const n = npcById[t.id];
      if (n) { n.faceToward(player.pos.x, player.pos.z); n.talking = true; }
      player.faceToward(t.x, t.z);
      Promise.resolve(story.interact(t.id)).catch((err) => console.error('[설화록] interact 오류', err))
        .finally(() => { if (n) n.talking = false; });
    }
  } else {
    const mv = input.moveVector();
    const speed = playerSpeed(input.running()) * (mv.mag ?? 1);
    const moved = player.step(dt, mv.x, mv.z, speed, actors);
    player.char.setAnim(moved ? (input.running() ? 'run' : 'walk') : 'idle');

    talkTarget = findTalkTarget(player, npcs);
    if (talkTarget && input.pressed('act')) {
      const n = talkTarget;
      n.talking = true;
      n.faceToward(player.pos.x, player.pos.z);
      player.faceToward(n.pos.x, n.pos.z);
      dialog.show(n.data.name, n.data.lines, () => { n.talking = false; });
    }
  }
  prompt.hidden = !(talkTarget && !dialog.open);
  if (!prompt.hidden) {
    const label = talkTarget.data ? `${talkTarget.data.name || ''} · 대화` : (talkTarget.label || '조사');
    if (prompt.textContent !== label) prompt.textContent = label;
  }

  for (const n of npcs) {
    if (n.scripted) continue; // 이야기가 직접 움직이는 중
    if (!n.talking && !dialog.open && Math.hypot(n.pos.x - player.pos.x, n.pos.z - player.pos.z) < 2.4) {
      n.faceToward(player.pos.x, player.pos.z);
      n.char.setAnim('idle');
    } else {
      n.updateWander(dt, actors);
    }
  }

  const interior = currentInterior();
  rig.update(rawDt, player.pos, player.facing, interior);
  banner.set(interior ? interior.name : rig.zoneName);
  occlusion.update(dt, player.pos, player.char.height, interior);
  dialog.update(dt);

  if (world.setNight) world.setNight(nightFactor(fx.getTime()));
  if (world.update) world.update(dt, time);
  for (const a of actors) a.char.update(dt, camera);
  focus.set(player.pos.x, player.pos.y, player.pos.z);
  fx.update(dt, focus);
  fx.render();

  // 성능 측정 (fx가 통계를 주면 그것을, 아니면 코어가 직접)
  fpsAcc += rawDt; fpsFrames += 1;
  if (fpsAcc >= 0.5) {
    const st = fx.getStats ? fx.getStats() : null;
    panel.setStats(st && st.fps ? st : { fps: fpsFrames / fpsAcc, frameMs: (fpsAcc / fpsFrames) * 1000 });
    fpsAcc = 0; fpsFrames = 0;
  }

  input.endFrame();
  requestAnimationFrame(frame);
}

window.__seolhwa = { THREE, scene, camera, renderer, world, fx, player, npcs, rig, teleport, warps, panel, get combat() { return combat; }, get story() { return story; }, get ui() { return ui; }, hud, input, setRenderStyle, allChars, npcById, dialog };
requestAnimationFrame(frame);
document.body.classList.add('ready');
