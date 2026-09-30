// 전투 효과 (COMBAT §4.3) — 먹/한지 스타일
// - 입자(먹물 번짐·물방울·붓 획 줄기·불꽃·흙먼지): 인스턴스 쿼드 1 드로콜, 고정 풀(할당 없음)
// - 메시 효과(베기 궤적·포효 고리·바닥 예고 lane/fan/ring): 타입별 메시 풀, 지형(world.heightAt) 따라 정점 배치
// 밤에는 먹선 가장자리에 호분(흰 안료) 테두리가 살아나 어두운 바닥에서도 읽힌다.
import * as THREE from 'three';

const NOISE = /* glsl */`
float h21(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float n2(vec2 p) {
  vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return n2(p) * 0.6 + n2(p * 2.1 + 5.3) * 0.28 + n2(p * 4.3 + 1.7) * 0.12; }
`;

const INK = new THREE.Color(0x17141a);
const SHU = new THREE.Color(0xc8452c);    // 주홍
const PALE = new THREE.Color(0xf2e8d2);   // 호분/한지
const SPARK = new THREE.Color(0xfff0c0);
const EARTH = new THREE.Color(0x9c8a68);

// ───────────────────────── 입자 ─────────────────────────
const P_VERT = /* glsl */`
attribute vec3 iPos;
attribute vec4 iA;   // size, rot, shape, seed
attribute vec4 iB;   // rgb, alpha
attribute vec4 iC;   // vel xyz, age01
uniform float uNight;
varying vec2 vUv;
varying vec4 vB;
varying vec4 vA;
varying float vAge;
void main() {
  vUv = uv; vB = iB; vA = iA; vAge = iC.w;
  vec4 mv = modelViewMatrix * vec4(iPos, 1.0);
  mv.xyz += normalize(-mv.xyz) * 0.6;            // 몸에 파묻히지 않게
  vec2 q = position.xy;
  float shape = iA.z;
  vec2 axis;
  float stretch = 1.0;
  if (shape > 0.5 && shape < 1.5 || shape > 2.5) { // 줄기/불꽃: 속도 방향으로 늘임
    vec3 vv = mat3(modelViewMatrix) * iC.xyz;
    float sp = length(vv.xy);
    axis = sp > 1e-4 ? vv.xy / sp : vec2(1.0, 0.0);
    stretch = 1.0 + min(sp * (shape > 2.5 ? 0.08 : 0.12), 4.0);
    q.x *= stretch;
  } else {
    axis = vec2(cos(iA.y), sin(iA.y));
  }
  vec2 r = vec2(q.x * axis.x - q.y * axis.y, q.x * axis.y + q.y * axis.x);
  mv.xy += r * iA.x;
  gl_Position = projectionMatrix * mv;
  if (iB.a <= 0.001) gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
}`;
const P_FRAG = /* glsl */`
uniform float uNight;
uniform vec3 uPale;
varying vec2 vUv;
varying vec4 vB;
varying vec4 vA;
varying float vAge;
${NOISE}
void main() {
  vec2 p = (vUv - 0.5) * 2.0;
  float r = length(p);
  float shape = vA.z, seed = vA.w;
  vec3 col = vB.rgb;
  float a = 0.0;
  if (shape < 0.5) {
    // 먹물 번짐: 들쭉날쭉한 가장자리, 가장자리가 더 짙게 고임, 시간이 갈수록 번짐
    float ang = atan(p.y, p.x);
    float edge = 0.72 + 0.2 * (fbm(vec2(ang * 1.6 + seed * 13.0, seed * 7.0)) - 0.5) * 2.0 + 0.12 * vAge;
    float soft = 0.04 + 0.12 * vAge;
    float body = smoothstep(edge, edge - soft, r);
    float grain = fbm(p * 5.0 + seed * 3.0);
    float pool = mix(0.7, 1.0, smoothstep(edge - 0.35, edge - 0.05, r));  // 가장자리 고임
    a = body * pool * (0.8 + 0.2 * grain);
    // 호분 테두리(밤에 강하게)
    float rim = smoothstep(edge - 0.02, edge + 0.06, r) * smoothstep(edge + 0.2, edge + 0.08, r);
    float rimA = rim * (0.15 + 0.6 * uNight);
    col = mix(uPale, col, a / max(a + rimA, 1e-3));
    a = max(a, rimA);
  } else if (shape < 1.5) {
    // 붓 획 줄기: 앞은 둥글고 뒤로 가늘어지며 갈필(마른 붓) 틈
    float x = p.x * 0.5 + 0.5;                   // 0 꼬리 → 1 머리
    float w = mix(0.15, 0.9, x) * (1.0 - smoothstep(0.85, 1.0, x));
    float body = smoothstep(w, w - 0.2, abs(p.y));
    float dry = smoothstep(0.25, 0.55, n2(vec2(x * 3.0 + seed * 9.0, p.y * 9.0)));
    a = body * mix(0.55, 1.0, dry) * smoothstep(0.0, 0.25, x);
    float rimA = smoothstep(w + 0.25, w, abs(p.y)) * (1.0 - body) * uNight * 0.6 * smoothstep(0.0, 0.3, x);
    col = mix(uPale, col, a / max(a + rimA, 1e-3));
    a = max(a, rimA);
  } else if (shape < 2.5) {
    // 흙먼지: 부드러운 뭉게
    float n = fbm(p * 2.2 + seed * 5.0 + vAge);
    a = smoothstep(1.0, 0.2, r + (n - 0.5) * 0.6) * 0.8;
  } else {
    // 불꽃: 밝은 심지
    float core = smoothstep(1.0, 0.0, length(p * vec2(1.0, 3.0)));
    a = core;
    col = mix(col, vec3(1.0), core * core * 0.6);
  }
  a *= vB.a;
  if (a < 0.01) discard;
  gl_FragColor = vec4(col, a);
}`;

function createParticles(scene, N) {
  const base = new THREE.PlaneGeometry(1, 1);
  const g = new THREE.InstancedBufferGeometry();
  g.index = base.index;
  g.setAttribute('position', base.getAttribute('position'));
  g.setAttribute('uv', base.getAttribute('uv'));
  const aPos = new THREE.InstancedBufferAttribute(new Float32Array(N * 3), 3);
  const aA = new THREE.InstancedBufferAttribute(new Float32Array(N * 4), 4);
  const aB = new THREE.InstancedBufferAttribute(new Float32Array(N * 4), 4);
  const aC = new THREE.InstancedBufferAttribute(new Float32Array(N * 4), 4);
  for (const a of [aPos, aA, aB, aC]) a.setUsage(THREE.DynamicDrawUsage);
  g.setAttribute('iPos', aPos); g.setAttribute('iA', aA); g.setAttribute('iB', aB); g.setAttribute('iC', aC);
  g.instanceCount = N;
  const mat = new THREE.ShaderMaterial({
    uniforms: { uNight: { value: 0 }, uPale: { value: PALE.clone() } },
    vertexShader: P_VERT, fragmentShader: P_FRAG,
    transparent: true, depthWrite: false, fog: false,
  });
  const mesh = new THREE.Mesh(g, mat);
  mesh.name = 'fx-combat-particles';
  mesh.frustumCulled = false;
  mesh.renderOrder = 30;
  mesh.raycast = () => {};
  scene.add(mesh);

  // 시뮬레이션 상태 (SoA)
  const px = new Float32Array(N), py = new Float32Array(N), pz = new Float32Array(N);
  const vx = new Float32Array(N), vy = new Float32Array(N), vz = new Float32Array(N);
  const age = new Float32Array(N), life = new Float32Array(N);
  const s0 = new Float32Array(N), s1 = new Float32Array(N), rot = new Float32Array(N), spin = new Float32Array(N);
  const shape = new Float32Array(N), seed = new Float32Array(N), grav = new Float32Array(N), drag = new Float32Array(N);
  const cr = new Float32Array(N), cg = new Float32Array(N), cb = new Float32Array(N), a0 = new Float32Array(N);
  const owner = new Int32Array(N), floorY = new Float32Array(N);
  let cursor = 0;
  let alive = 0;

  function emit(id, x, y, z, ux, uy, uz, lf, size0, size1, shp, color, alpha, gravity, dragK, fy) {
    // 빈 슬롯 찾기(없으면 가장 오래된 쪽을 덮어씀)
    let i = -1;
    for (let k = 0; k < N; k++) { const j = (cursor + k) % N; if (life[j] <= 0) { i = j; break; } }
    if (i < 0) i = cursor;
    cursor = (i + 1) % N;
    px[i] = x; py[i] = y; pz[i] = z; vx[i] = ux; vy[i] = uy; vz[i] = uz;
    age[i] = 0; life[i] = lf; s0[i] = size0; s1[i] = size1; shape[i] = shp;
    rot[i] = Math.random() * 6.283; spin[i] = (Math.random() - 0.5) * 1.5; seed[i] = Math.random();
    grav[i] = gravity; drag[i] = dragK; cr[i] = color.r; cg[i] = color.g; cb[i] = color.b; a0[i] = alpha;
    owner[i] = id; floorY[i] = fy;
    alive++;
  }

  function kill(id) { for (let i = 0; i < N; i++) if (owner[i] === id) life[i] = 0; }
  function killAll() { life.fill(0); }

  function update(dt) {
    const P = aPos.array, A = aA.array, B = aB.array, C = aC.array;
    let any = false;
    for (let i = 0; i < N; i++) {
      if (life[i] <= 0) { if (B[i * 4 + 3] !== 0) { B[i * 4 + 3] = 0; any = true; } continue; }
      any = true;
      age[i] += dt;
      const t = age[i] / life[i];
      if (t >= 1) { life[i] = 0; B[i * 4 + 3] = 0; continue; }
      const d = Math.exp(-drag[i] * dt);
      vx[i] *= d; vz[i] *= d; vy[i] = vy[i] * d - grav[i] * dt;
      px[i] += vx[i] * dt; py[i] += vy[i] * dt; pz[i] += vz[i] * dt;
      if (py[i] < floorY[i]) { py[i] = floorY[i]; vy[i] = 0; vx[i] *= 0.5; vz[i] *= 0.5; }
      rot[i] += spin[i] * dt;
      const e = 1 - (1 - t) * (1 - t);            // ease-out 크기
      P[i * 3] = px[i]; P[i * 3 + 1] = py[i]; P[i * 3 + 2] = pz[i];
      A[i * 4] = s0[i] + (s1[i] - s0[i]) * e; A[i * 4 + 1] = rot[i]; A[i * 4 + 2] = shape[i]; A[i * 4 + 3] = seed[i];
      const fadeIn = Math.min(1, age[i] / 0.04);
      const fadeOut = 1 - THREE.MathUtils.smoothstep(t, 0.55, 1.0);
      B[i * 4] = cr[i]; B[i * 4 + 1] = cg[i]; B[i * 4 + 2] = cb[i]; B[i * 4 + 3] = a0[i] * fadeIn * fadeOut;
      C[i * 4] = vx[i]; C[i * 4 + 1] = vy[i]; C[i * 4 + 2] = vz[i]; C[i * 4 + 3] = t;
    }
    if (any) { aPos.needsUpdate = aA.needsUpdate = aB.needsUpdate = aC.needsUpdate = true; }
  }

  return { mesh, mat, emit, kill, killAll, update };
}

// ───────────────────────── 메시 효과 ─────────────────────────
// 공통 uniform: uColor(주 색), uEdge(먹선), uPale, uNight, uProg(채움 0~1), uAlpha, uTime, uSeed, uArc(각 범위 비율)
const M_VERT = /* glsl */`
varying vec2 vUv;
void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`;

const TELEGRAPH_FRAG = /* glsl */`
uniform vec3 uColor, uEdge, uPale;
uniform float uNight, uProg, uAlpha, uTime, uSeed, uMode; // mode 0 lane, 1 fan, 2 ring
varying vec2 vUv;
${NOISE}
void main() {
  float u = vUv.x, v = vUv.y;                     // lane/fan: u=가로(0~1), v=진행(0~1). ring: u=둘레, v=띠 폭
  float a = 0.0;
  vec3 col = uColor;
  if (uMode < 1.5) {
    // 먹물 워시: 가장자리 붓 떨림, 옅은 바탕 + 진행에 따라 짙게 차오름
    float wob = (fbm(vec2(v * 6.0 + uSeed * 10.0, uSeed)) - 0.5) * 0.12;
    float side = min(u, 1.0 - u) + wob;
    float inside = smoothstep(0.0, 0.05, side);
    float grain = fbm(vec2(u * 5.0, v * 11.0) + uSeed * 4.0);
    float streak = n2(vec2(u * 14.0 + uSeed * 3.0, v * 2.5));   // 붓결(진행 방향)
    float base = 0.1 + 0.14 * grain * streak;
    float fillEdge = uProg + (grain - 0.5) * 0.06;
    float filled = smoothstep(fillEdge + 0.01, fillEdge - 0.03, v);
    a = mix(base, 0.38 + 0.3 * grain * (0.6 + 0.4 * streak), filled);
    // 차오르는 앞머리 붓선
    float head = smoothstep(0.05, 0.0, abs(v - fillEdge)) * step(uProg, 0.999);
    // 양쪽 먹선 테두리 (갈필)
    float edgeLine = smoothstep(0.1, 0.02, side) * (0.55 + 0.45 * smoothstep(0.3, 0.6, n2(vec2(v * 20.0, u * 3.0 + uSeed * 7.0))));
    // 끝(도착점) 먹선
    float tip = uMode < 0.5 ? smoothstep(0.93, 0.99, v) * smoothstep(1.0, 0.985, v) : 0.0;
    col = mix(col, uEdge, clamp(edgeLine + tip, 0.0, 1.0) * (1.0 - uNight * 0.6));
    col = mix(col, uPale, (edgeLine + head) * uNight * 0.55);
    a = max(a, max(edgeLine, tip) * 0.85);
    a = max(a, head * 0.9);
    a *= inside;
    // 시작점 쪽은 옅게 사라지도록
    a *= uMode < 0.5 ? smoothstep(0.0, 0.08, v) : 1.0;
  } else {
    // 사거리 고리: 붓으로 원을 그어 나가는 획(갈필), 진행 = 그려진 둘레
    float band = 1.0 - abs(v - 0.5) * 2.0;
    float wob = (n2(vec2(u * 30.0, uSeed * 5.0)) - 0.5) * 0.5;
    float stroke = smoothstep(0.1, 0.45, band + wob * 0.4);
    float dry = smoothstep(0.2, 0.5, n2(vec2(u * 60.0, v * 6.0 + uSeed * 3.0)));
    float drawn = smoothstep(uProg + 0.002, uProg - 0.01, u);
    a = stroke * mix(0.45, 0.85, dry) * drawn;
    col = mix(uColor, uEdge, 0.35 * (1.0 - uNight));
    col = mix(col, uPale, uNight * 0.35);
  }
  a *= uAlpha;
  if (a < 0.01) discard;
  gl_FragColor = vec4(col, a);
}`;

const SLASH_FRAG = /* glsl */`
uniform vec3 uColor, uPale;
uniform float uNight, uHead, uTail, uAlpha, uSeed;
varying vec2 vUv;
${NOISE}
void main() {
  float u = vUv.x, v = vUv.y;      // u: 궤적 진행, v: 안쪽(0) → 바깥(1)
  if (u > uHead || u < uTail) discard;
  float span = max(uHead - uTail, 1e-3);
  float k = (u - uTail) / span;      // 0 꼬리 → 1 머리
  // 붓 획: 머리 쪽이 굵고 꼬리로 갈수록 바깥쪽만 남아 가늘어짐
  float w = mix(0.12, 0.95, pow(k, 0.7));
  float d = 1.0 - v;                 // 바깥 가장자리 기준
  float body = smoothstep(w, w - 0.12, d) * smoothstep(0.0, 0.06, v);
  float dry = smoothstep(0.3, 0.6, n2(vec2(u * 8.0 + uSeed * 9.0, v * 26.0)));
  float a = body * mix(0.35, 1.0, dry) * smoothstep(0.0, 0.25, k);
  a *= 1.0 - smoothstep(0.97, 1.0, k) * 0.3;
  vec3 col = mix(uColor, uPale, uNight * 0.85);
  a *= uAlpha;
  if (a < 0.01) discard;
  gl_FragColor = vec4(col, a);
}`;

const ROAR_FRAG = /* glsl */`
uniform vec3 uColor, uPale;
uniform float uNight, uAlpha, uSeed, uThick;
varying vec2 vUv;
${NOISE}
void main() {
  float u = vUv.x, v = vUv.y;
  float band = 1.0 - abs(v - 0.5) * 2.0;
  float wob = n2(vec2(u * 40.0, uSeed * 7.0));
  float body = smoothstep(1.0 - uThick, 1.0 - uThick + 0.25, band + (wob - 0.5) * 0.5);
  float dry = smoothstep(0.25, 0.6, n2(vec2(u * 90.0, v * 4.0 + uSeed)));
  float a = body * mix(0.4, 1.0, dry);
  vec3 col = mix(uColor, uPale, uNight * 0.8);
  a *= uAlpha;
  if (a < 0.01) discard;
  gl_FragColor = vec4(col, a);
}`;

// 격자 지오메트리 (segU × segV), uv = (i/segU, j/segV). 위치는 CPU에서 직접 채운다.
function gridGeometry(segU, segV) {
  const nu = segU + 1, nv = segV + 1;
  const pos = new Float32Array(nu * nv * 3), uv = new Float32Array(nu * nv * 2);
  const idx = [];
  for (let j = 0; j < nv; j++) for (let i = 0; i < nu; i++) {
    const k = j * nu + i; uv[k * 2] = i / segU; uv[k * 2 + 1] = j / segV;
  }
  for (let j = 0; j < segV; j++) for (let i = 0; i < segU; i++) {
    const a = j * nu + i, b = a + 1, c = a + nu, d = c + 1;
    idx.push(a, c, b, b, c, d);
  }
  const g = new THREE.BufferGeometry();
  const pa = new THREE.BufferAttribute(pos, 3); pa.setUsage(THREE.DynamicDrawUsage);
  g.setAttribute('position', pa);
  g.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
  g.setIndex(idx);
  g.boundingSphere = new THREE.Sphere(new THREE.Vector3(), 1e5);
  return { g, nu, nv };
}

function makeMat(frag, extra) {
  return new THREE.ShaderMaterial({
    uniforms: Object.assign({
      uColor: { value: SHU.clone() }, uEdge: { value: INK.clone() }, uPale: { value: PALE.clone() },
      uNight: { value: 0 }, uAlpha: { value: 0 }, uSeed: { value: 0 },
    }, extra),
    vertexShader: M_VERT, fragmentShader: frag,
    transparent: true, depthWrite: false, fog: false, side: THREE.DoubleSide,
    polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -4,
  });
}

export function createCombatFX({ scene, world }) {
  const heightAt = (world && world.heightAt) ? world.heightAt.bind(world) : () => 0;
  const LIFT = 0.07;
  const parts = createParticles(scene, 480);
  let nextId = 1;
  let night = 0;

  // ---- 메시 풀 ----
  const pools = { lane: [], fan: [], ring: [], slash: [], roar: [] };
  function addPool(type, count, segU, segV, frag, extra, order) {
    for (let n = 0; n < count; n++) {
      const { g, nu, nv } = gridGeometry(segU, segV);
      const m = new THREE.Mesh(g, makeMat(frag, typeof extra === 'function' ? extra() : {}));
      m.name = 'fx-combat-' + type;
      m.frustumCulled = false; m.visible = false; m.renderOrder = order;
      m.raycast = () => {};
      scene.add(m);
      pools[type].push({ mesh: m, nu, nv, active: false, id: 0, age: 0, dur: 1, fadeOut: -1, o: {}, started: 0 });
    }
  }
  const tele = () => ({ uProg: { value: 0 }, uTime: { value: 0 }, uMode: { value: 0 } });
  addPool('lane', 4, 6, 32, TELEGRAPH_FRAG, tele, 5);
  addPool('fan', 4, 28, 10, TELEGRAPH_FRAG, tele, 5);
  addPool('ring', 4, 96, 1, TELEGRAPH_FRAG, tele, 5);
  addPool('slash', 8, 28, 2, SLASH_FRAG, () => ({ uHead: { value: 0 }, uTail: { value: 0 } }), 31);
  addPool('roar', 4, 96, 1, ROAR_FRAG, () => ({ uThick: { value: 0.8 } }), 6);

  const TYPES = Object.keys(pools);
  let clock = 0;
  function takeSlot(type) {
    const pool = pools[type];
    let best = pool[0];
    for (const s of pool) { if (!s.active) return s; if (s.started < best.started) best = s; }
    return best;
  }

  const _d = new THREE.Vector3();
  function flatDir(dir, out) {
    out.set(dir ? dir.x : 0, 0, dir ? dir.z : 1);
    if (out.lengthSq() < 1e-6) out.set(0, 0, 1);
    return out.normalize();
  }

  // 정점 채우기
  function fillLane(s, p, o) {
    flatDir(o.dir, _d);
    const L = o.length ?? 8, W = o.width ?? 1.6;
    const sx = -_d.z, sz = _d.x; // 옆 방향
    const pos = s.mesh.geometry.attributes.position.array;
    for (let j = 0; j < s.nv; j++) for (let i = 0; i < s.nu; i++) {
      const u = i / (s.nu - 1), v = j / (s.nv - 1);
      const x = p.x + _d.x * L * v + sx * (u - 0.5) * W;
      const z = p.z + _d.z * L * v + sz * (u - 0.5) * W;
      const k = (j * s.nu + i) * 3;
      pos[k] = x; pos[k + 1] = heightAt(x, z) + LIFT; pos[k + 2] = z;
    }
    s.mesh.geometry.attributes.position.needsUpdate = true;
  }
  function fillFan(s, p, o) {
    flatDir(o.dir, _d);
    const R = o.radius ?? 2.5, arc = o.arc ?? Math.PI * 0.6;
    const a0 = Math.atan2(_d.z, _d.x);
    const pos = s.mesh.geometry.attributes.position.array;
    for (let j = 0; j < s.nv; j++) for (let i = 0; i < s.nu; i++) {
      const u = i / (s.nu - 1), v = j / (s.nv - 1);
      const ang = a0 + (u - 0.5) * arc, r = Math.max(0.05, v) * R;
      const x = p.x + Math.cos(ang) * r, z = p.z + Math.sin(ang) * r;
      const k = (j * s.nu + i) * 3;
      pos[k] = x; pos[k + 1] = heightAt(x, z) + LIFT; pos[k + 2] = z;
    }
    s.mesh.geometry.attributes.position.needsUpdate = true;
  }
  function fillRing(s, p, R, band, follow, y0) {
    const pos = s.mesh.geometry.attributes.position.array;
    for (let j = 0; j < s.nv; j++) for (let i = 0; i < s.nu; i++) {
      const u = i / (s.nu - 1), v = j / (s.nv - 1);
      const ang = u * Math.PI * 2, r = Math.max(0.01, R - band * 0.5 + band * v);
      const x = p.x + Math.cos(ang) * r, z = p.z + Math.sin(ang) * r;
      const k = (j * s.nu + i) * 3;
      pos[k] = x; pos[k + 1] = (follow ? heightAt(x, z) + LIFT + 0.02 : y0); pos[k + 2] = z;
    }
    s.mesh.geometry.attributes.position.needsUpdate = true;
  }
  function fillSlash(s, p, o) {
    flatDir(o.dir, _d);
    const R = o.radius ?? 1.8, arc = o.arc ?? Math.PI * 0.75;
    const a0 = Math.atan2(_d.z, _d.x);
    const y = p.y + (o.height ?? 0.9);
    const flip = o.flip ? -1 : 1;
    const tilt = o.tilt ?? 0.35; // 휘두르는 면을 약간 기울여 위에서도 궤적이 읽히게
    const pos = s.mesh.geometry.attributes.position.array;
    for (let j = 0; j < s.nv; j++) for (let i = 0; i < s.nu; i++) {
      const u = i / (s.nu - 1), v = j / (s.nv - 1);
      const t = (u - 0.5) * flip;
      const ang = a0 + t * arc;
      const r = R * (0.55 + 0.45 * v);
      const k = (j * s.nu + i) * 3;
      pos[k] = p.x + Math.cos(ang) * r;
      pos[k + 1] = y + t * tilt * R * 0.6;
      pos[k + 2] = p.z + Math.sin(ang) * r;
    }
    s.mesh.geometry.attributes.position.needsUpdate = true;
  }

  function activate(type, p, o) {
    const s = takeSlot(type);
    s.active = true; s.id = nextId++; s.age = 0; s.fadeOut = -1; s.started = clock;
    s.px = p.x; s.py = p.y; s.pz = p.z;
    s.o = o;
    const U = s.mesh.material.uniforms;
    U.uSeed.value = Math.random();
    U.uAlpha.value = 0;
    s.mesh.visible = true;
    return s;
  }
  function handleFor(s) {
    const id = s.id;
    return { remove() { if (s.active && s.id === id && s.fadeOut < 0) s.fadeOut = 0; } };
  }

  // ---- 입자 버스트 ----
  const R = Math.random;
  function burstHit(id, p, o, heavy) {
    const fy = heightAt(p.x, p.z) + 0.03;
    const k = heavy ? 1.6 : 1;
    const dx = o.dir ? o.dir.x : 0, dz = o.dir ? o.dir.z : 0;
    // 중심 번짐 (2겹)
    parts.emit(id, p.x, p.y, p.z, 0, 0, 0, 0.6 * k, 0.7 * k, 1.5 * k, 0, INK, 0.95, 0, 0, -1e9);
    parts.emit(id, p.x + (R() - 0.5) * 0.3, p.y + (R() - 0.5) * 0.3, p.z, 0, 0, 0, 0.5 * k, 0.4 * k, 0.9 * k, 0, SHU, 0.85, 0, 0, -1e9);
    // 튀는 먹 방울
    const nd = heavy ? 18 : 10;
    for (let i = 0; i < nd; i++) {
      const a = R() * Math.PI * 2, sp = (2 + R() * 4) * k;
      const col = R() < 0.3 ? SHU : INK;
      parts.emit(id, p.x, p.y, p.z, Math.cos(a) * sp + dx * 2, 1.5 + R() * 3, Math.sin(a) * sp + dz * 2,
        0.45 + R() * 0.35, 0.14 + R() * 0.14, 0.26 + R() * 0.2, 0, col, 0.95, 9, 1.5, fy);
    }
    // 붓 획 줄기
    const ns = heavy ? 9 : 4;
    for (let i = 0; i < ns; i++) {
      const a = R() * Math.PI * 2, sp = (7 + R() * 6) * k;
      parts.emit(id, p.x, p.y, p.z, Math.cos(a) * sp + dx * 4, (R() - 0.3) * 4, Math.sin(a) * sp + dz * 4,
        heavy ? 0.35 : 0.24, 0.28 * k, 0.4 * k, 1, INK, 0.9, 2, 6, -1e9);
    }
    if (heavy) {
      // 크게 긋는 획 3개
      for (let i = 0; i < 3; i++) {
        const a = (i / 3) * Math.PI * 2 + R();
        parts.emit(id, p.x, p.y, p.z, Math.cos(a) * 16, (R() - 0.5) * 3, Math.sin(a) * 16, 0.4, 0.6, 0.85, 1, i === 0 ? SHU : INK, 0.95, 0, 7, -1e9);
      }
      // 발밑에 번지는 먹
      parts.emit(id, p.x, fy + 0.05, p.z, 0, 0, 0, 1.0, 0.5, 2.0, 0, INK, 0.5, 0, 0, -1e9);
    }
  }
  function burstBlock(id, p, o) {
    const dx = o.dir ? o.dir.x : 0, dz = o.dir ? o.dir.z : 0;
    parts.emit(id, p.x, p.y, p.z, 0, 0, 0, 0.22, 0.7, 1.5, 2, PALE, 0.85, 0, 0, -1e9);
    for (let i = 0; i < 14; i++) {
      const a = R() * Math.PI * 2, sp = 5 + R() * 7;
      parts.emit(id, p.x, p.y, p.z, Math.cos(a) * sp - dx * 3, 1 + R() * 4, Math.sin(a) * sp - dz * 3,
        0.2 + R() * 0.2, 0.12 + R() * 0.06, 0.06, 3, SPARK, 1, 12, 2, -1e9);
    }
  }
  const _earth = new THREE.Color();
  function burstDust(id, p, o) {
    const y = heightAt(p.x, p.z);
    const n = o.count ?? 8, k = o.scale ?? 1;
    _earth.copy(EARTH).lerp(PALE, night * 0.25);
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2 + R() * 0.6, sp = (1.2 + R() * 1.6) * k;
      parts.emit(id, p.x + Math.cos(a) * 0.3, y + 0.15 + R() * 0.2, p.z + Math.sin(a) * 0.3,
        Math.cos(a) * sp, 0.4 + R() * 0.6, Math.sin(a) * sp, 0.6 + R() * 0.4, 0.5 * k, (1.2 + R() * 0.6) * k, 2, _earth, 0.7, -0.3, 3, -1e9);
    }
  }

  const _p = new THREE.Vector3();
  const api = {
    spawn(type, pos, opts = {}) {
      const p = _p.copy(pos || _p.set(0, 0, 0));
      switch (type) {
        case 'hit': case 'heavyHit': case 'block': case 'dust': {
          const id = nextId++;
          if (type === 'hit') burstHit(id, p, opts, false);
          else if (type === 'heavyHit') burstHit(id, p, opts, true);
          else if (type === 'block') burstBlock(id, p, opts);
          else burstDust(id, p, opts);
          return { remove() { parts.kill(id); } };
        }
        case 'slash': {
          const s = activate('slash', p, opts); s.dur = opts.duration ?? 0.32; fillSlash(s, p, opts); return handleFor(s);
        }
        case 'roar': {
          const s = activate('roar', p, opts); s.dur = opts.duration ?? 0.9;
          s.ry = heightAt(p.x, p.z) + 0.25; s.maxR = opts.radius ?? 7;
          // 두 번째 고리는 살짝 늦게
          if (!opts._second) { const o2 = Object.assign({}, opts, { _second: true, delay: 0.18 }); api.spawn('roar', pos, o2); }
          s.delay = opts.delay ?? 0;
          s.mesh.material.uniforms.uColor.value.copy(INK);
          fillRing(s, p, 0.1, 0.1, false, s.ry);
          return handleFor(s);
        }
        case 'lane': case 'fan': case 'ring': {
          const s = activate(type, p, opts);
          s.dur = opts.duration ?? (type === 'ring' ? Infinity : 0.8);
          const U = s.mesh.material.uniforms;
          U.uMode.value = type === 'lane' ? 0 : type === 'fan' ? 1 : 2;
          U.uProg.value = 0;
          U.uColor.value.copy(opts.color ? _tmpC.set(opts.color) : SHU);
          if (type === 'lane') fillLane(s, p, opts);
          else if (type === 'fan') fillFan(s, p, opts);
          else fillRing(s, p, opts.radius ?? 3, opts.band ?? 0.3, true, 0);
          return handleFor(s);
        }
        default:
          return { remove() {} };
      }
    },
    update(dt) {
      clock += dt;
      parts.mat.uniforms.uNight.value = night;
      parts.update(dt);
      for (let ti = 0; ti < TYPES.length; ti++) {
        const type = TYPES[ti], pool = pools[type];
        for (let si = 0; si < pool.length; si++) {
          const s = pool[si];
          if (!s.active) continue;
          const U = s.mesh.material.uniforms;
          U.uNight.value = night;
          s.age += dt;
          if (s.fadeOut >= 0) s.fadeOut += dt;
          let alpha = 1;
          if (type === 'slash') {
            const t = s.age / s.dur;
            U.uHead.value = Math.min(1, t * 3.2);
            U.uTail.value = THREE.MathUtils.clamp((t - 0.25) * 1.4, 0, 1);
            if (t >= 1 || s.fadeOut > 0.05) { s.active = false; s.mesh.visible = false; continue; }
          } else if (type === 'roar') {
            const t = (s.age - s.delay) / s.dur;
            if (t < 0) { alpha = 0; }
            else {
              if (t >= 1 || s.fadeOut > 0.1) { s.active = false; s.mesh.visible = false; continue; }
              const e = 1 - Math.pow(1 - t, 2.2);
              _p.set(s.px, s.py, s.pz);
              fillRing(s, _p, 0.3 + e * s.maxR, 0.25 + 1.2 * (1 - t), false, s.ry);
              U.uThick.value = 0.9 - 0.5 * t;
              alpha = (1 - t * t) * (s.o._second ? 0.6 : 1);
            }
          } else {
            // 예고 표시: 채움 → 완료 시 짧게 번쩍 후 사라짐(링은 유지)
            const draw = type === 'ring' ? Math.min(1, s.age / 0.35) : THREE.MathUtils.clamp(s.age / s.dur, 0, 1);
            U.uProg.value = type === 'ring' ? draw : draw;
            alpha = Math.min(1, s.age / 0.08);
            if (type !== 'ring' && s.age > s.dur) {
              const k = (s.age - s.dur) / 0.25;
              alpha = 1 - k;
              if (k >= 1) { s.active = false; s.mesh.visible = false; continue; }
            }
            if (type === 'ring' && s.age > s.dur && s.fadeOut < 0) s.fadeOut = 0;
          }
          if (s.fadeOut >= 0) {
            alpha *= 1 - s.fadeOut / 0.2;
            if (s.fadeOut >= 0.2) { s.active = false; s.mesh.visible = false; continue; }
          }
          U.uAlpha.value = alpha;
        }
      }
    },
    setNight(n) { night = n; },
    clear() {
      for (const type in pools) for (const s of pools[type]) { s.active = false; s.mesh.visible = false; }
      parts.killAll();
    },
  };
  const _tmpC = new THREE.Color();
  return api;
}
