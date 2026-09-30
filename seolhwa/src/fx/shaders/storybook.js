// 이야기책/한지 패스 (OutputPass 이후, sRGB 공간)
// 먹선 가장자리(휘도 에지) → 색보정(lift/gamma/gain·채도, 시간대별) → 한지 섬유 질감 → 비네트
export const StorybookShader = {
  name: 'StorybookShader',
  uniforms: {
    tDiffuse: { value: null },
    tPaper: { value: null },
    uTexel: { value: [1 / 1024, 1 / 1024] },
    uPaperScale: { value: [1 / 512, 1 / 512] }, // gl_FragCoord → 종이 uv
    uAspect: { value: 1.6 },
    uLift: { value: null },
    uGamma: { value: null },
    uGain: { value: null },
    uSat: { value: 0.85 },
    uPaper: { value: 1.0 },      // 한지 질감 세기(옵션)
    uVignette: { value: 1.0 },
    uInk: { value: 1.0 },
    uTint: { value: [1.0, 0.985, 0.955] }, // 한지 크림색
    uNight: { value: 0 },
  },
  vertexShader: /* glsl */`
varying vec2 vUv;
void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
  fragmentShader: /* glsl */`
uniform sampler2D tDiffuse, tPaper;
uniform vec2 uTexel, uPaperScale;
uniform float uAspect, uSat, uPaper, uVignette, uInk, uNight;
uniform vec3 uLift, uGamma, uGain, uTint;
varying vec2 vUv;
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
void main() {
  vec3 c = texture2D(tDiffuse, vUv).rgb;
  // 먹선: 휘도 기울기가 큰 곳을 살짝 어둡게
  if (uInk > 0.0) {
    float l = luma(texture2D(tDiffuse, vUv - vec2(uTexel.x, 0.0)).rgb);
    float r = luma(texture2D(tDiffuse, vUv + vec2(uTexel.x, 0.0)).rgb);
    float d = luma(texture2D(tDiffuse, vUv - vec2(0.0, uTexel.y)).rgb);
    float u = luma(texture2D(tDiffuse, vUv + vec2(0.0, uTexel.y)).rgb);
    float e = length(vec2(r - l, u - d));
    c *= 1.0 - uInk * 0.35 * smoothstep(0.06, 0.28, e);
  }
  // 색보정
  c = uGain * (c + uLift * (1.0 - c));
  c = pow(max(c, vec3(0.0)), 1.0 / uGamma);
  float L = luma(c);
  c = mix(vec3(L), c, uSat);
  // 민화식 분할 톤: 그늘은 푸른 먹빛, 밝은 곳은 따뜻하게
  float sh = (1.0 - L) * (1.0 - L);
  c *= mix(vec3(1.0), vec3(0.93, 0.97, 1.07), sh * 0.6);
  c *= mix(vec3(1.0), vec3(1.03, 1.0, 0.96), smoothstep(0.5, 1.0, L) * 0.5);
  // 한지: 크림색 바탕 + 섬유(밝은 곳에서 더 보이게)
  vec2 pc = gl_FragCoord.xy * uPaperScale;
  vec3 p = texture2D(tPaper, pc).rgb;
  float fib = (p.r - 0.5);
  float mott = (p.g - 0.5);
  vec3 tinted = c * uTint;
  c = mix(c, tinted, uPaper * 0.6);
  c *= 1.0 + uPaper * (fib * (0.16 + 0.12 * L) + mott * 0.08);
  // 아주 밝은 곳은 종이색으로 살짝 눌러 '인쇄된' 느낌
  c = mix(c, uTint * 0.97, uPaper * 0.1 * smoothstep(0.75, 1.0, L));
  // 비네트(먹빛 갈색)
  vec2 q = (vUv - 0.5) * vec2(uAspect, 1.0);
  float v = smoothstep(0.35 + 0.5 * uAspect, 0.25, length(q) * 0.9);
  vec3 vc = mix(vec3(0.16, 0.12, 0.09), vec3(0.05, 0.06, 0.1), uNight);
  c = mix(c, c * vc * 2.2, (1.0 - v) * uVignette * 0.55);
  gl_FragColor = vec4(c, 1.0);
}`,
};
