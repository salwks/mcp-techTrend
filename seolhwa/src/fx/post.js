// 후처리 체인: Render → Bloom(HDR) → Output(톤매핑+sRGB) → TiltShift H/V → Storybook(색보정·한지·비네트·먹선)
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { TiltShiftShader } from './shaders/tiltshift.js';
import { StorybookShader } from './shaders/storybook.js';
import { createPaperTexture } from './paper.js';

export function createPost(renderer, scene, camera) {
  const composer = new EffectComposer(renderer);
  const renderPass = new RenderPass(scene, camera);
  const bloom = new UnrealBloomPass(new THREE.Vector2(256, 256), 0.2, 0.55, 0.85);
  const output = new OutputPass();
  const tiltH = new ShaderPass(TiltShiftShader);
  const tiltV = new ShaderPass(TiltShiftShader);
  const story = new ShaderPass(StorybookShader);

  tiltH.uniforms.uStep.value = new THREE.Vector2(1, 0);
  tiltV.uniforms.uStep.value = new THREE.Vector2(0, 1);
  const su = story.uniforms;
  su.tPaper.value = createPaperTexture(512);
  su.uTexel.value = new THREE.Vector2();
  su.uPaperScale.value = new THREE.Vector2(1 / 512, 1 / 512);
  su.uLift.value = new THREE.Vector3();
  su.uGamma.value = new THREE.Vector3(1, 1, 1);
  su.uGain.value = new THREE.Vector3(1, 1, 1);
  su.uTint.value = new THREE.Vector3(1.0, 0.985, 0.955);

  composer.addPass(renderPass);
  composer.addPass(bloom);
  composer.addPass(output);
  composer.addPass(tiltH);
  composer.addPass(tiltV);
  composer.addPass(story);

  let W = 1, H = 1, PR = 1;
  function setSize(w, h, pr) {
    W = w; H = h; PR = pr;
    composer.setPixelRatio(pr);
    composer.setSize(w, h);
    const rw = Math.max(1, Math.floor(w * pr)), rh = Math.max(1, Math.floor(h * pr));
    tiltH.uniforms.uStep.value.set(1 / rw, 0);
    tiltV.uniforms.uStep.value.set(0, 1 / rh);
    const maxR = rh * 0.0085;
    tiltH.uniforms.uMaxRadius.value = maxR;
    tiltV.uniforms.uMaxRadius.value = maxR;
    su.uTexel.value.set(1 / rw, 1 / rh);
    su.uPaperScale.value.set(1 / (512 * Math.max(1, pr * 0.75)), 1 / (512 * Math.max(1, pr * 0.75)));
    su.uAspect.value = w / h;
  }

  function setMSAA(n) {
    for (const rt of [composer.renderTarget1, composer.renderTarget2]) {
      if (rt.samples !== n) { rt.samples = n; rt.dispose(); }
    }
  }

  return {
    composer, bloom, tiltH, tiltV, story,
    setSize, setMSAA,
    setFocusY(y) { tiltH.uniforms.uFocusY.value = y; tiltV.uniforms.uFocusY.value = y; },
    apply(state, opts) {
      su.uLift.value.copy(state.lift);
      su.uGamma.value.copy(state.gamma);
      su.uGain.value.copy(state.gain);
      su.uSat.value = state.sat;
      su.uNight.value = state.night;
      const p = opts.paper ? 1 : 0;
      su.uPaper.value = p; su.uVignette.value = p; su.uInk.value = p;
      bloom.strength = state.bloom;
      bloom.threshold = state.thr;
      bloom.enabled = opts.bloom && opts.quality !== 'low';
      tiltH.enabled = tiltV.enabled = !!opts.tiltShift;
    },
    render(dt) { composer.render(dt); },
  };
}
