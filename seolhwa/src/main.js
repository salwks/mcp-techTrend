// 설화록 비주얼 프로토타입 — 진입점
import * as THREE from 'three';
import { Input } from './core/input.js';
import { CameraRig } from './core/camera.js';
import { Occlusion } from './core/occlusion.js';
import { Actor, playerSpeed, findTalkTarget } from './core/actors.js';
import { Dialog, PlaceBanner } from './core/dialog.js';
import { Panel } from './core/panel.js';
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
const hud = document.getElementById('hud');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(30, 1, 0.5, 600);

const [worldMod, charMod, fxMod] = await Promise.all([
  load('./world/index.js', 'world'),
  load('./chars/index.js', 'chars'),
  load('./fx/index.js', 'fx'),
]);

let world;
try { world = worldMod ? worldMod.buildWorld(scene) : fallbackWorld(scene); }
catch (err) { console.error('[설화록] buildWorld 오류', err); world = fallbackWorld(scene); }
world.colliders ||= [];
world.npcs ||= [];

const makeChar = (kind) => {
  try { if (charMod) return charMod.createCharacter(kind); }
  catch (err) { console.error('[설화록] createCharacter 오류', kind, err); }
  return fallbackCharacter(kind);
};

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
const input = new Input(hud);
const rig = new CameraRig(camera, world);
const occlusion = new Occlusion(camera, world);
const dialog = new Dialog(hud);
const banner = new PlaceBanner(hud);
const prompt = document.createElement('div');
prompt.className = 'prompt';
prompt.hidden = true;
hud.appendChild(prompt);

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

const panel = new Panel(hud, {
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
rig.update(0, player.pos, player.facing, null, true);

function frame() {
  const dt = Math.min(0.05, clock.getDelta());
  time += dt;

  if (input.pressed('panel')) panel.toggle();
  if (input.pressed('time')) { fx.setTime((Math.floor(fx.getTime() / 6) * 6 + 6) % 24); panel.syncTime(); }

  if (dialog.open) {
    if (input.pressed('act') || input.pressed('cancel')) dialog.advance();
    player.char.setAnim('idle');
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
  if (!prompt.hidden) prompt.textContent = `${talkTarget.data.name || ''} · 대화`;

  for (const n of npcs) {
    if (!n.talking && !dialog.open && Math.hypot(n.pos.x - player.pos.x, n.pos.z - player.pos.z) < 2.4) {
      n.faceToward(player.pos.x, player.pos.z);
      n.char.setAnim('idle');
    } else {
      n.updateWander(dt, actors);
    }
  }

  const interior = currentInterior();
  rig.update(dt, player.pos, player.facing, interior);
  banner.set(interior ? interior.name : rig.zoneName);
  occlusion.update(dt, player.pos, player.char.height, interior);
  dialog.update(dt);

  if (world.update) world.update(dt, time);
  for (const a of actors) a.char.update(dt, camera);
  focus.set(player.pos.x, player.pos.y, player.pos.z);
  fx.update(dt, focus);
  fx.render();

  input.endFrame();
  requestAnimationFrame(frame);
}

window.__seolhwa = { THREE, scene, camera, renderer, world, fx, player, npcs, rig, teleport, warps, panel };
requestAnimationFrame(frame);
document.body.classList.add('ready');
