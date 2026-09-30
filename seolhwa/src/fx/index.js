// 설화록 FX — 시간대·하늘·조명·그림자·밤 등불·후처리 (CONTRACTS §4)
import * as THREE from 'three';
import { createTimeState, sampleTime, lightDirection, lampFactor } from './timeofday.js';
import { createSky } from './sky.js';
import { createLighting, patchFogChunks } from './lighting.js';
import { createNightLights } from './nightlights.js';
import { createPost } from './post.js';
import { createCombatFX } from './combat.js';

const HOURS_PER_SEC = 1 / 20; // 실제 20초 = 게임 1시간

function defaultQuality() {
  try {
    const coarse = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
    return coarse || Math.min(window.innerWidth, window.innerHeight) < 600 ? 'low' : 'high';
  } catch (e) { return 'high'; }
}

export function createFX({ renderer, scene, camera, world }) {
  patchFogChunks(); // 첫 컴파일 전에 적용되어야 함

  const opts = { tiltShift: true, bloom: true, paper: true, fog: true, timeFlow: false, quality: defaultQuality() };

  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.NeutralToneMapping;
  renderer.toneMappingExposure = 1.0;

  const state = createTimeState();
  const lighting = createLighting(scene, { shadowSize: opts.quality === 'low' ? 1024 : 2048 });
  const sky = createSky(camera);
  scene.add(sky.mesh);
  scene.background = new THREE.Color();
  const lamps = createNightLights(scene, world && world.lights);
  const post = createPost(renderer, scene, camera);
  const combat = createCombatFX({ scene, world });

  let hour = 12;
  let clock = 0;
  let lastDt = 1 / 60;
  let W = 0, H = 0;
  const lightDir = new THREE.Vector3();
  const focus = new THREE.Vector3();
  const _proj = new THREE.Vector3();
  let focusY = 0.45;
  let dirty = true;

  function applyTime() {
    sampleTime(hour, state);
    lightDirection(hour, state.dayMix, lightDir);
    lighting.apply(state, lightDir, opts.fog);
    scene.background.copy(state.fog);
    sky.apply(state, lightDir, clock);
    post.apply(state, opts);
    dirty = false;
  }

  function applyQuality() {
    const low = opts.quality === 'low';
    lighting.setShadowSize(low ? 1024 : 2048);
    post.setMSAA(low ? 0 : 4);
    if (W && H) resize(W, H);
    dirty = true;
  }

  function resize(w, h) {
    W = w; H = h;
    const dpr = (typeof window !== 'undefined' && window.devicePixelRatio) || 1;
    const pr = opts.quality === 'low' ? Math.min(dpr, 1) * (dpr > 1.5 ? 0.9 : 1) : Math.min(dpr, 2);
    renderer.setPixelRatio(pr);
    renderer.setSize(w, h);
    if (camera.isPerspectiveCamera) { camera.aspect = w / h; camera.updateProjectionMatrix(); }
    post.setSize(w, h, pr);
  }

  const fx = {
    update(dt, f) {
      dt = dt > 0 ? Math.min(dt, 0.25) : 0;
      lastDt = dt;
      clock += dt;
      if (f) focus.copy(f);
      if (opts.timeFlow) { hour = (hour + dt * HOURS_PER_SEC) % 24; dirty = true; }
      if (dirty) applyTime();
      sky.uniforms.uTime.value = clock;
      lighting.follow(focus);
      // 틸트시프트 초점 띠 = 플레이어 몸 중앙의 화면 Y
      camera.updateMatrixWorld();
      _proj.set(focus.x, focus.y + 0.8, focus.z).project(camera);
      const y = THREE.MathUtils.clamp(_proj.y * 0.5 + 0.5, 0.15, 0.85);
      focusY += (y - focusY) * Math.min(1, dt * 6);
      post.setFocusY(focusY);
      lamps.update(dt, clock, focus, lampFactor(hour), opts.quality === 'low' ? 4 : 6);
      combat.setNight(state.night);
      combat.update(dt);
    },
    render() { post.render(lastDt); },
    resize,
    setTime(h) { hour = ((Number(h) % 24) + 24) % 24; dirty = true; applyTime(); },
    getTime() { return hour; },
    setOption(name, value) {
      if (!(name in opts)) return;
      if (name === 'quality') { opts.quality = value === 'low' ? 'low' : 'high'; applyQuality(); return; }
      opts[name] = !!value;
      dirty = true;
      applyTime();
    },
    getOptions() { return { ...opts }; },
    combat, // 전투 효과 (COMBAT §4.3): spawn(type, pos, opts) → { remove() }
    // 디버그/코어용 부가 정보
    get state() { return state; },
    get lightDirection() { return lightDir; },
  };

  if (opts.quality === 'low') post.setMSAA(0); else post.setMSAA(4);
  applyTime();
  if (renderer.domElement) {
    const el = renderer.domElement;
    const w = el.clientWidth || (typeof window !== 'undefined' ? window.innerWidth : 1280);
    const h = el.clientHeight || (typeof window !== 'undefined' ? window.innerHeight : 720);
    resize(w, h);
  }
  return fx;
}
