// 후처리 — 가벼운 자체 체인 (EffectComposer 미사용)
//   1) 장면 → rtScene (전체 해상도 × renderScale, HalfFloat, 레벨에 따라 MSAA)
//   2) 틸트시프트 흐림: rtScene → rtHalfA(가로 9탭) → rtHalfB(세로 9탭)   [1/2 해상도, 켜졌을 때만]
//   3) 블룸: rtScene → rtQA(밝은 부분 추출+다운샘플) → rtQB(가로) → rtQA(세로) [1/4 해상도, 켜졌을 때만]
//   4) 최종 1패스(화면): 선명/흐림 섞기 + 블룸 + 톤매핑(Neutral) + sRGB + 색보정 + 한지 + 비네트 + 먹선
import * as THREE from 'three';
import { createPaperTexture } from './paper.js';

const VERT = /* glsl */`
varying vec2 vUv;
void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }`;

// 9탭 가우시안(선형 보간 샘플) — 방향은 uStep
const BLUR_FRAG = /* glsl */`
uniform sampler2D tInput;
uniform vec2 uStep;
varying vec2 vUv;
void main() {
  vec3 c = texture2D(tInput, vUv).rgb * 0.227027;
  c += (texture2D(tInput, vUv + uStep * 1.0).rgb + texture2D(tInput, vUv - uStep * 1.0).rgb) * 0.1945946;
  c += (texture2D(tInput, vUv + uStep * 2.0).rgb + texture2D(tInput, vUv - uStep * 2.0).rgb) * 0.1216216;
  c += (texture2D(tInput, vUv + uStep * 3.0).rgb + texture2D(tInput, vUv - uStep * 3.0).rgb) * 0.054054;
  c += (texture2D(tInput, vUv + uStep * 4.0).rgb + texture2D(tInput, vUv - uStep * 4.0).rgb) * 0.016216;
  gl_FragColor = vec4(c, 1.0);
}`;

// 밝은 부분 추출 + 4탭 다운샘플(1/4)
const BRIGHT_FRAG = /* glsl */`
uniform sampler2D tInput;
uniform vec2 uTexel;     // 원본 텍셀
uniform float uThreshold;
varying vec2 vUv;
vec3 pick(vec2 o) {
  vec3 c = min(texture2D(tInput, vUv + o * uTexel).rgb, vec3(8.0));
  float l = max(c.r, max(c.g, c.b));
  float k = clamp((l - uThreshold) / 0.25, 0.0, 1.0);
  return c * k * k * max(l - uThreshold * 0.7, 0.0) / max(l, 1e-4);
}
void main() {
  vec3 c = pick(vec2(-1.0, -1.0)) + pick(vec2(1.0, -1.0)) + pick(vec2(-1.0, 1.0)) + pick(vec2(1.0, 1.0));
  gl_FragColor = vec4(c * 0.25, 1.0);
}`;

const FINAL_FRAG = /* glsl */`
uniform sampler2D tScene, tBlur, tBloom, tPaper;
uniform vec2 uTexel, uPaperScale;
uniform float uAspect, uFocusY, uBand, uRange, uTopBias, uBottomBias;
uniform float uTilt, uBloom, uExposure;
uniform float uSat, uPaper, uVignette, uInk, uNight;
uniform vec3 uLift, uGamma, uGain, uTint;
varying vec2 vUv;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
vec3 neutralTM(vec3 color) {
  const float S = 0.76; const float D = 0.15;
  color *= uExposure;
  float x = min(color.r, min(color.g, color.b));
  float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
  color -= offset;
  float peak = max(color.r, max(color.g, color.b));
  if (peak < S) return color;
  float d = 1.0 - S;
  float np = 1.0 - d * d / (peak + d - S);
  color *= np / peak;
  float g = 1.0 - 1.0 / (D * (peak - np) + 1.0);
  return mix(color, vec3(np), g);
}
vec3 toSRGB(vec3 c) {
  c = max(c, vec3(0.0));
  return mix(pow(c, vec3(0.41666)) * 1.055 - 0.055, c * 12.92, vec3(lessThanEqual(c, vec3(0.0031308))));
}
void main() {
  vec3 c = texture2D(tScene, vUv).rgb;
  float amt = 0.0;
  if (uTilt > 0.5) {
    float dy = vUv.y - uFocusY;
    amt = smoothstep(0.0, uRange, abs(dy) - uBand) * (dy > 0.0 ? uTopBias : uBottomBias);
    c = mix(c, texture2D(tBlur, vUv).rgb, amt);
  }
  // 먹선: 선명한 영역에서만 (흐린 곳은 생략)
  if (uInk > 0.0 && amt < 0.6) {
    float l = sqrt(luma(texture2D(tScene, vUv - vec2(uTexel.x, 0.0)).rgb));
    float r = sqrt(luma(texture2D(tScene, vUv + vec2(uTexel.x, 0.0)).rgb));
    float d = sqrt(luma(texture2D(tScene, vUv - vec2(0.0, uTexel.y)).rgb));
    float u = sqrt(luma(texture2D(tScene, vUv + vec2(0.0, uTexel.y)).rgb));
    float e = length(vec2(r - l, u - d));
    c *= 1.0 - uInk * 0.35 * smoothstep(0.06, 0.28, e) * (1.0 - amt / 0.6);
  }
  if (uBloom > 0.0) c += texture2D(tBloom, vUv).rgb * uBloom;
  c = toSRGB(neutralTM(c));
  // 색보정 (sRGB)
  c = uGain * (c + uLift * (1.0 - c));
  c = pow(max(c, vec3(0.0)), 1.0 / uGamma);
  float L = luma(c);
  c = mix(vec3(L), c, uSat);
  float sh = (1.0 - L) * (1.0 - L);
  c *= mix(vec3(1.0), vec3(0.93, 0.97, 1.07), sh * 0.6);
  c *= mix(vec3(1.0), vec3(1.03, 1.0, 0.96), smoothstep(0.5, 1.0, L) * 0.5);
  // 한지
  vec3 p = texture2D(tPaper, gl_FragCoord.xy * uPaperScale).rgb;
  c = mix(c, c * uTint, uPaper * 0.6);
  c *= 1.0 + uPaper * ((p.r - 0.5) * (0.16 + 0.12 * L) + (p.g - 0.5) * 0.08);
  c = mix(c, uTint * 0.97, uPaper * 0.1 * smoothstep(0.75, 1.0, L));
  // 비네트
  vec2 q = (vUv - 0.5) * vec2(uAspect, 1.0);
  float v = smoothstep(0.35 + 0.5 * uAspect, 0.25, length(q) * 0.9);
  vec3 vc = mix(vec3(0.16, 0.12, 0.09), vec3(0.05, 0.06, 0.1), uNight);
  c = mix(c, c * vc * 2.2, (1.0 - v) * uVignette * 0.55);
  // 밴딩 방지 디더
  c += (p.b - 0.5) * (1.5 / 255.0);
  gl_FragColor = vec4(c, 1.0);
}`;

function rt(w, h, samples = 0, depth = false) {
  const t = new THREE.WebGLRenderTarget(w, h, {
    type: THREE.HalfFloatType, depthBuffer: depth, samples,
    minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter,
  });
  t.texture.generateMipmaps = false;
  return t;
}

export function createPost(renderer, scene, camera) {
  const quadCam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  const quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2));
  quad.frustumCulled = false;
  const mk = (frag, uniforms) => new THREE.ShaderMaterial({ uniforms, vertexShader: VERT, fragmentShader: frag, depthTest: false, depthWrite: false });

  const blurMat = mk(BLUR_FRAG, { tInput: { value: null }, uStep: { value: new THREE.Vector2() } });
  const brightMat = mk(BRIGHT_FRAG, { tInput: { value: null }, uTexel: { value: new THREE.Vector2() }, uThreshold: { value: 0.8 } });
  const paper = createPaperTexture(512);
  const U = {
    tScene: { value: null }, tBlur: { value: null }, tBloom: { value: null }, tPaper: { value: paper },
    uTexel: { value: new THREE.Vector2() }, uPaperScale: { value: new THREE.Vector2(1 / 512, 1 / 512) },
    uAspect: { value: 1.6 }, uFocusY: { value: 0.45 }, uBand: { value: 0.07 }, uRange: { value: 0.32 },
    uTopBias: { value: 1.0 }, uBottomBias: { value: 0.75 },
    uTilt: { value: 1 }, uBloom: { value: 0 }, uExposure: { value: 1 },
    uSat: { value: 0.85 }, uPaper: { value: 1 }, uVignette: { value: 1 }, uInk: { value: 1 }, uNight: { value: 0 },
    uLift: { value: new THREE.Vector3() }, uGamma: { value: new THREE.Vector3(1, 1, 1) }, uGain: { value: new THREE.Vector3(1, 1, 1) },
    uTint: { value: new THREE.Vector3(1.0, 0.985, 0.955) },
  };
  const finalMat = mk(FINAL_FRAG, U);

  const rtScene = rt(4, 4, 4, true);
  const rtHalfA = rt(2, 2), rtHalfB = rt(2, 2);
  const rtQA = rt(1, 1), rtQB = rt(1, 1);

  let tiltOn = true, bloomOn = true, bloomAllowed = true, inkAllowed = true, paperOpt = true;
  let rw = 4, rh = 4;
  let blurSigmaPx = 6; // 전체 해상도 기준 흐림 반경

  function pass(mat, target) {
    quad.material = mat;
    renderer.setRenderTarget(target);
    renderer.render(quad, quadCam);
  }

  function setSize(w, h, pr) {
    rw = Math.max(1, Math.floor(w * pr)); rh = Math.max(1, Math.floor(h * pr));
    rtScene.setSize(rw, rh);
    const hw = Math.max(1, Math.ceil(rw / 2)), hh = Math.max(1, Math.ceil(rh / 2));
    rtHalfA.setSize(hw, hh); rtHalfB.setSize(hw, hh);
    const qw = Math.max(1, Math.ceil(rw / 4)), qh = Math.max(1, Math.ceil(rh / 4));
    rtQA.setSize(qw, qh); rtQB.setSize(qw, qh);
    U.uTexel.value.set(1 / rw, 1 / rh);
    const ps = 1 / (512 * Math.max(1, pr * 0.75));
    U.uPaperScale.value.set(ps, ps);
    U.uAspect.value = w / h;
    brightMat.uniforms.uTexel.value.set(1 / rw, 1 / rh);
    blurSigmaPx = rh * 0.0042; // 1080p에서 약 4.5px
  }

  function setMSAA(n) {
    if (rtScene.samples !== n) { rtScene.samples = n; rtScene.dispose(); }
  }

  return {
    setSize, setMSAA,
    setFocusY(y) { U.uFocusY.value = y; },
    setLevelCaps({ bloom, ink }) { bloomAllowed = bloom; inkAllowed = ink; U.uInk.value = paperOpt && inkAllowed ? 1 : 0; },
    apply(state, opts) {
      U.uLift.value.copy(state.lift); U.uGamma.value.copy(state.gamma); U.uGain.value.copy(state.gain);
      U.uSat.value = state.sat; U.uNight.value = state.night;
      paperOpt = !!opts.paper;
      const p = paperOpt ? 1 : 0;
      U.uPaper.value = p; U.uVignette.value = p; U.uInk.value = p && inkAllowed ? 1 : 0;
      brightMat.uniforms.uThreshold.value = state.thr;
      U.uBloom.value = state.bloom * 0.45;
      bloomOn = !!opts.bloom;
      tiltOn = !!opts.tiltShift;
    },
    render() {
      const prevTarget = renderer.getRenderTarget();
      renderer.setRenderTarget(rtScene);
      renderer.render(scene, camera);
      const bloom = bloomOn && bloomAllowed && U.uBloom.value > 0.001;
      if (tiltOn) {
        // 절반 해상도에서 1 스텝 = 반해상도 텍셀 × 거리
        const step = (blurSigmaPx / 2) * 0.75;
        blurMat.uniforms.tInput.value = rtScene.texture;
        blurMat.uniforms.uStep.value.set(step / rtHalfA.width, 0);
        pass(blurMat, rtHalfA);
        blurMat.uniforms.tInput.value = rtHalfA.texture;
        blurMat.uniforms.uStep.value.set(0, step / rtHalfA.height);
        pass(blurMat, rtHalfB);
      }
      if (bloom) {
        brightMat.uniforms.tInput.value = rtScene.texture;
        pass(brightMat, rtQA);
        blurMat.uniforms.tInput.value = rtQA.texture;
        blurMat.uniforms.uStep.value.set(1.5 / rtQA.width, 0);
        pass(blurMat, rtQB);
        blurMat.uniforms.tInput.value = rtQB.texture;
        blurMat.uniforms.uStep.value.set(0, 1.5 / rtQA.height);
        pass(blurMat, rtQA);
      }
      U.tScene.value = rtScene.texture;
      U.tBlur.value = rtHalfB.texture;
      U.tBloom.value = rtQA.texture;
      U.uTilt.value = tiltOn ? 1 : 0;
      const b = U.uBloom.value;
      if (!bloom) U.uBloom.value = 0;
      pass(finalMat, prevTarget);
      U.uBloom.value = b;
    },
    // 통계용: 전체 해상도 기준 채움 비용(패스 수 환산)
    fillCost() {
      let f = 1; // 최종
      if (tiltOn) f += 0.25 * 2;
      if (bloomOn && bloomAllowed) f += 0.0625 * 3;
      return f;
    },
  };
}
