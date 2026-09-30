// 하늘/배경 — 카메라 고정 시점에서 주로 '지평선 아래'가 보이므로
// 먼 산 능선 여러 겹 + 운해(안개 바다)를 그려 넣은 수묵 산수풍 배경 + 위쪽 하늘 그라데이션.
// 풀스크린 쿼드를 far plane(깊이 1)에 그려 카메라 far 설정과 무관. 불투명 목록 맨 끝에 그려 early-z로 가려진 픽셀은 생략.
import * as THREE from 'three';

const vert = /* glsl */`
uniform mat4 uProjInv;
uniform mat4 uCamWorld;
varying vec3 vDir;
void main() {
  vec4 v = uProjInv * vec4(position.xy, 1.0, 1.0);
  v /= v.w;
  vDir = mat3(uCamWorld) * v.xyz;
  gl_Position = vec4(position.xy, 1.0, 1.0);
}`;

const frag = /* glsl */`
uniform vec3 uTop, uHor, uLow, uFog, uGlow, uInk;
uniform float uGlowI, uNight, uTime;
uniform vec3 uSunDir;   // 노을 방위
uniform vec3 uMoonDir;  // 그림 속 달 위치(연출용)
varying vec3 vDir;

float hash11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float hash21(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float noise1(float x) { float i = floor(x), f = fract(x); f = f*f*(3.0-2.0*f); return mix(hash11(i), hash11(i+1.0), f); }
float noise2(vec2 p) {
  vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
  return mix(mix(hash21(i), hash21(i+vec2(1,0)), f.x), mix(hash21(i+vec2(0,1)), hash21(i+vec2(1,1)), f.x), f.y);
}
float fbm2(vec2 p) { return noise2(p)*0.55 + noise2(p*2.03+7.1)*0.3 + noise2(p*4.1+3.7)*0.15; }
// 뾰족한 산 능선(1D)
float ridge(float x, float seed) {
  float n = 0.0, a = 0.6, f = 1.0;
  for (int i = 0; i < 3; i++) {
    float r = 1.0 - abs(noise1(x*f + seed)*2.0 - 1.0);
    n += r*r*a; a *= 0.45; f *= 2.3;
  }
  return n;
}

void main() {
  vec3 d = normalize(vDir);
  float e = d.y;
  float az = atan(d.x, -d.z); // 북쪽 0
  // --- 하늘(지평선 위): 물감을 겹친 듯한 부드러운 띠 ---
  float t = clamp(e / 0.55, 0.0, 1.0);
  float N = 5.0;
  float tb = (floor(t*N) + smoothstep(0.3, 0.7, fract(t*N))) / N;
  t = mix(t, tb, 0.55);
  vec3 sky = mix(uHor, uTop, pow(t, 0.75));
  // 노을/여명
  vec2 sxz = normalize(uSunDir.xz + 1e-4);
  float toward = max(dot(normalize(d.xz + 1e-4), sxz), 0.0);
  float glow = uGlowI * (0.35 + 0.65*pow(toward, 3.0)) * exp(-max(e, 0.0) * 5.0);
  sky = mix(sky, uGlow, clamp(glow, 0.0, 1.0));
  // 가로로 긴 구름결
  float cl = fbm2(vec2(az * 3.0 + uTime*0.004, e * 22.0));
  sky = mix(sky, mix(uHor, uGlow, 0.3*uGlowI) * 1.04, smoothstep(0.55, 0.8, cl) * 0.35 * smoothstep(0.0, 0.08, e) * (1.0 - t));
  // 별
  vec2 sc = vec2(az * 60.0, e * 60.0);
  float sh = hash21(floor(sc));
  float star = step(0.985, sh) * smoothstep(0.35, 0.0, length(fract(sc) - 0.5));
  star *= (0.6 + 0.4*sin(uTime*2.0 + sh*80.0));
  sky += vec3(0.9, 0.9, 1.0) * star * uNight * smoothstep(0.03, 0.2, e) * 0.9;
  // 달(연출용 원반 + 달무리)
  float md = dot(d, uMoonDir);
  float disc = smoothstep(0.99955, 0.99975, md);
  float halo = pow(max(md, 0.0), 300.0) * 0.5 + pow(max(md, 0.0), 30.0) * 0.12;
  vec3 moonCol = vec3(1.0, 0.95, 0.82);
  sky = mix(sky, moonCol * 1.6, disc * uNight);
  sky += moonCol * halo * uNight * 0.6;

  // --- 운해(지평선 아래 안개 바다) ---
  vec2 pp = d.xz / max(-e, 0.02);           // 아래 평면 투영
  float c1 = fbm2(pp * 0.9 + vec2(uTime*0.01, 0.0));
  float c2 = fbm2(pp * 2.3 - vec2(uTime*0.015, 0.0));
  float billow = smoothstep(0.35, 0.8, c1*0.7 + c2*0.3);
  vec3 sea = mix(uLow, uFog, 0.5);
  sea = mix(sea * 0.86 + uInk*0.06, mix(sea, uHor, 0.35) * 1.05, billow); // 구름 봉우리 밝게, 골은 먹빛
  sea = mix(sea, uFog, smoothstep(-0.02, -0.45, e) * 0.55);   // 가까울수록 안개색(월드와 이음매 없이)
  vec3 col = e > 0.0 ? sky : mix(uHor, sea, smoothstep(0.0, 0.05, -e));

  // --- 먼 산 능선 세 겹 (먼 것일수록 옅게) ---
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float base = 0.015 - fi * 0.075;
    float amp = 0.1 + fi * 0.035;
    float h = base + amp * (ridge(az * (3.2 + fi * 1.7), 11.0 + fi * 17.0) - 0.35);
    float inside = smoothstep(h + 0.0015, h - 0.0015, e);
    if (inside > 0.0) {
      vec3 mtn = mix(uHor, uInk, 0.26 + fi * 0.17);
      mtn = mix(mtn, uGlow, 0.18 * uGlowI * (1.0 - fi * 0.3));
      // 봉우리는 짙고 아래로 갈수록 안개(운해)에 녹는다
      float fade = smoothstep(h - 0.01, h - 0.09 - fi * 0.02, e);
      vec3 mist = mix(sea, uHor, 0.25);
      mtn *= 1.0 - 0.18 * smoothstep(h - 0.012, h - 0.001, e);    // 능선 먹선
      col = mix(col, mix(mtn, mist, fade * 0.9), inside);
    }
  }
  gl_FragColor = vec4(col, 1.0);
}`;

export function createSky(camera) {
  const uniforms = {
    uProjInv: { value: camera.projectionMatrixInverse },
    uCamWorld: { value: camera.matrixWorld },
    uTop: { value: new THREE.Color() },
    uHor: { value: new THREE.Color() },
    uLow: { value: new THREE.Color() },
    uFog: { value: new THREE.Color() },
    uGlow: { value: new THREE.Color() },
    uInk: { value: new THREE.Color(0x1a1e2a) },
    uGlowI: { value: 0 },
    uNight: { value: 0 },
    uTime: { value: 0 },
    uSunDir: { value: new THREE.Vector3(0, 0.3, 1) },
    uMoonDir: { value: new THREE.Vector3(0.45, 0.14, -1).normalize() },
  };
  const mat = new THREE.ShaderMaterial({
    uniforms, vertexShader: vert, fragmentShader: frag,
    depthWrite: false, depthTest: true, fog: false,
  });
  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), mat);
  mesh.name = 'fx-sky';
  mesh.frustumCulled = false;
  mesh.renderOrder = 100000; // 불투명 중 마지막 → 가려진 픽셀은 깊이 테스트로 스킵
  mesh.raycast = () => {};
  mesh.castShadow = false; mesh.receiveShadow = false;

  const _tmp = new THREE.Vector3();
  return {
    mesh, uniforms,
    apply(state, sunDir, time) {
      uniforms.uTop.value.copy(state.skyTop);
      uniforms.uHor.value.copy(state.skyHor);
      uniforms.uLow.value.copy(state.low);
      uniforms.uFog.value.copy(state.fog);
      uniforms.uGlow.value.copy(state.glow);
      uniforms.uGlowI.value = state.glowI;
      uniforms.uNight.value = state.night;
      uniforms.uTime.value = time;
      // 노을은 해가 지는 서쪽/뜨는 동쪽, 약간 북쪽으로 틀어 화면(북쪽)에서도 보이게
      _tmp.set(sunDir.x, 0, -0.6);
      uniforms.uSunDir.value.copy(_tmp);
    },
  };
}
