// 설화록 FX — 시간대·하늘·조명·그림자·밤 등불·후처리 (CONTRACTS §4)
import * as THREE from 'three';
import { createTimeState, sampleTime, lightDirection, lampFactor } from './timeofday.js';
import { createSky } from './sky.js';
import { createLighting, patchFogChunks } from './lighting.js';
import { createNightLights } from './nightlights.js';
import { createPost } from './post.js';
import { createCombatFX } from './combat.js';

const HOURS_PER_SEC = 1 / 20; // 실제 20초 = 게임 1시간

// 품질 단계 (0 = 최고). 시각 손실이 적은 것부터 줄인다.
const LEVELS = [
  { scale: 1.0,  msaa: 4, bloom: true,  shadow: 2048, ext: 20, lights: 6, ink: true,  shadowEvery: 1 },
  { scale: 0.85, msaa: 0, bloom: true,  shadow: 2048, ext: 20, lights: 6, ink: true,  shadowEvery: 1 },
  { scale: 0.7,  msaa: 0, bloom: false, shadow: 1024, ext: 18, lights: 6, ink: true,  shadowEvery: 1 },
  { scale: 0.7,  msaa: 0, bloom: false, shadow: 1024, ext: 16, lights: 3, ink: false, shadowEvery: 1 },
  { scale: 0.55, msaa: 0, bloom: false, shadow: 512,  ext: 14, lights: 3, ink: false, shadowEvery: 2 },
];
const LOW_LEVEL = 3;

function isMobile() {
  try {
    const coarse = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
    return coarse || Math.min(window.innerWidth, window.innerHeight) < 600;
  } catch (e) { return false; }
}

export function createFX({ renderer, scene, camera, world }) {
  patchFogChunks(); // 첫 컴파일 전에 적용되어야 함

  const mobile = isMobile();
  const opts = { tiltShift: true, bloom: true, paper: true, fog: true, timeFlow: false, quality: mobile ? 'low' : 'high', autoQuality: true };
  let level = mobile ? 2 : 0;

  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.NeutralToneMapping;
  renderer.toneMappingExposure = 1.0;

  const state = createTimeState();
  const lighting = createLighting(scene, { shadowSize: LEVELS[level].shadow, shadowExtent: LEVELS[level].ext });
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

  // ---- 품질 단계 적용 ----
  let basePR = 1, curPR = 1, frameNo = 0;
  function applyLevel(n) {
    level = Math.max(0, Math.min(LEVELS.length - 1, n));
    const L = LEVELS[level];
    opts.quality = level <= 1 ? 'high' : 'low';
    lighting.setShadowSize(L.shadow);
    lighting.setShadowExtent(L.ext);
    post.setMSAA(L.msaa);
    post.setLevelCaps({ bloom: L.bloom, ink: L.ink });
    renderer.shadowMap.autoUpdate = L.shadowEvery === 1;
    renderer.shadowMap.needsUpdate = true;
    if (W && H) resize(W, H);
    gov.settle = 0;
  }

  function resize(w, h) {
    W = w; H = h;
    const dpr = (typeof window !== 'undefined' && window.devicePixelRatio) || 1;
    basePR = Math.min(dpr, 2);
    curPR = basePR * LEVELS[level].scale;
    renderer.setPixelRatio(curPR);
    renderer.setSize(w, h);
    if (camera.isPerspectiveCamera) { camera.aspect = w / h; camera.updateProjectionMatrix(); }
    post.setSize(w, h, curPR);
  }

  // ---- 자동 품질 조절기 ----
  // 실제 프레임 간격의 지수이동평균(약 1초). 시작 2초·단계 변경 직후 1.5초는 무시, 250ms 넘는 끊김 무시.
  // 36fps 미만 → 한 단계 내림. 55fps 초과가 4초 지속 → 한 단계 올림(방금 실패한 단계는 점점 길게 금지).
  const gov = { last: 0, ema: 16.7, show: 16.7, slowRun: 0, age: 0, settle: 0, good: 0, block: new Float64Array(LEVELS.length), backoff: new Float64Array(LEVELS.length).fill(15) };
  function governor(now) {
    if (!gov.last) { gov.last = now; return; }
    const d = now - gov.last; gov.last = now;
    if (d > 0 && d < 3000) gov.show += (d - gov.show) * (1 - Math.exp(-d / 1000)); // 표시용(끊김 포함)
    if (d <= 0) return;
    if (d > 250) {
      // 한 번의 끊김은 무시하되, 연속 5프레임 이상 느리면 진짜 느린 기기로 본다
      gov.age += d; gov.settle += d;
      if (++gov.slowRun >= 5 && opts.autoQuality && gov.age > 2000 && level < LEVELS.length - 1) { gov.slowRun = 0; gov.good = 0; applyLevel(level + 1); }
      return;
    }
    gov.slowRun = 0;
    gov.age += d; gov.settle += d;
    gov.ema += (d - gov.ema) * (1 - Math.exp(-d / 1000));
    if (!opts.autoQuality || gov.age < 2000 || gov.settle < 1500) return;
    const fps = 1000 / gov.ema;
    if (fps < 36 && level < LEVELS.length - 1) {
      gov.block[level] = now + gov.backoff[level] * 1000;   // 이 단계로 되돌아오는 것을 잠시 금지
      gov.backoff[level] = Math.min(gov.backoff[level] * 2, 240);
      gov.good = 0;
      applyLevel(level + 1);
    } else if (fps > 55 && level > 0) {
      gov.good += d;
      if (gov.good > 4000 && now > gov.block[level - 1]) { gov.good = 0; applyLevel(level - 1); }
    } else gov.good = 0;
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
      lamps.update(dt, clock, focus, lampFactor(hour), LEVELS[level].lights);
      combat.setNight(state.night);
      combat.update(dt);
    },
    render() {
      const now = performance.now();
      governor(now);
      frameNo++;
      if (LEVELS[level].shadowEvery > 1 && frameNo % LEVELS[level].shadowEvery === 0) renderer.shadowMap.needsUpdate = true;
      post.render();
    },
    getStats() {
      return { fps: 1000 / gov.show, frameMs: gov.show, level, pixelRatio: curPR, auto: opts.autoQuality, fill: post.fillCost() };
    },
    resize,
    setTime(h) { hour = ((Number(h) % 24) + 24) % 24; dirty = true; applyTime(); },
    getTime() { return hour; },
    setOption(name, value) {
      if (name === 'level') { opts.autoQuality = false; applyLevel(Number(value) | 0); return; }
      if (!(name in opts)) return;
      if (name === 'quality') { opts.autoQuality = false; applyLevel(value === 'low' ? LOW_LEVEL : 0); return; }
      if (name === 'autoQuality') { opts.autoQuality = !!value; gov.settle = 0; gov.good = 0; return; }
      opts[name] = !!value;
      dirty = true;
      applyTime();
    },
    getOptions() { return { ...opts, level }; },
    combat, // 전투 효과 (COMBAT §4.3): spawn(type, pos, opts) → { remove() }
    // 디버그/코어용 부가 정보
    get state() { return state; },
    get lightDirection() { return lightDir; },
  };

  applyLevel(level);
  applyTime();
  if (renderer.domElement) {
    const el = renderer.domElement;
    const w = el.clientWidth || (typeof window !== 'undefined' ? window.innerWidth : 1280);
    const h = el.clientHeight || (typeof window !== 'undefined' ? window.innerHeight : 720);
    resize(w, h);
  }
  return fx;
}
