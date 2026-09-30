// 틸트시프트(HD-2D) — 화면 세로 위치 기반 가변 반경 분리형 가우시안 블러.
// 초점 띠(플레이어 화면 Y) 안은 선명, 위(먼 곳)·아래(가까운 곳)로 갈수록 흐려진다.
export const TiltShiftShader = {
  name: 'TiltShiftShader',
  uniforms: {
    tDiffuse: { value: null },
    uStep: { value: [1, 0] },      // 방향 * 텍셀 크기 (vec2)
    uFocusY: { value: 0.45 },       // uv.y
    uBand: { value: 0.07 },         // 선명한 띠 반폭
    uRange: { value: 0.32 },        // 최대 블러까지의 거리
    uMaxRadius: { value: 8.0 },     // 픽셀(렌더 해상도 기준)
    uTopBias: { value: 1.0 },
    uBottomBias: { value: 0.75 },
  },
  vertexShader: /* glsl */`
varying vec2 vUv;
void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
  fragmentShader: /* glsl */`
uniform sampler2D tDiffuse;
uniform vec2 uStep;
uniform float uFocusY, uBand, uRange, uMaxRadius, uTopBias, uBottomBias;
varying vec2 vUv;
void main() {
  float dy = vUv.y - uFocusY;
  float amt = smoothstep(0.0, uRange, abs(dy) - uBand);
  amt *= dy > 0.0 ? uTopBias : uBottomBias;
  float radius = amt * uMaxRadius;
  vec4 c = texture2D(tDiffuse, vUv);
  if (radius < 0.35) { gl_FragColor = c; return; }
  // 13탭, 시그마 = 반경/2.5
  float s = radius / 6.0;
  vec4 sum = c * 0.1655;
  float ws = 0.1655;
  for (int i = 1; i <= 6; i++) {
    float fi = float(i);
    float w = exp(-fi * fi / 9.0) * 0.1655;
    vec2 o = uStep * fi * s;
    sum += (texture2D(tDiffuse, vUv + o) + texture2D(tDiffuse, vUv - o)) * w;
    ws += 2.0 * w;
  }
  gl_FragColor = sum / ws;
}`,
};
