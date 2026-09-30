// 밤 조명: world.lights → 가까운 최대 6개는 실제 PointLight(깜박임), 나머지는 발광 스프라이트(인스턴싱 1 드로콜).
// PointLight 개수는 항상 고정(셰이더 재컴파일 방지) — 낮에는 intensity 0.
import * as THREE from 'three';

const KIND = {
  lantern: { color: 0xffa855, glow: 0xffb866, intensity: 18, distance: 9, size: 2.2, flick: 0.07, core: 1.0 },
  torch:   { color: 0xff8a3c, glow: 0xff9a48, intensity: 22, distance: 10, size: 2.8, flick: 0.16, core: 1.2 },
  shrine:  { color: 0xff9060, glow: 0xffa070, intensity: 16, distance: 8, size: 1.5, flick: 0.1, core: 0.8 },
  window:  { color: 0xffc27a, glow: 0xffcf8a, intensity: 8, distance: 7, size: 1.1, flick: 0.02, core: 0.5 },
};

const vert = /* glsl */`
attribute vec3 iPos;
attribute vec3 iColor;
attribute float iSize;
attribute vec2 iAmt; // x: 전체 밝기, y: 번짐(실제 광원이 없을 때 더 크게)
varying vec2 vUv;
varying vec3 vColor;
varying vec2 vAmt;
void main() {
  vUv = uv;
  vColor = iColor;
  vAmt = iAmt;
  vec4 mv = modelViewMatrix * vec4(iPos, 1.0);
  mv.xyz += normalize(-mv.xyz) * 0.6;   // 벽에 파묻히지 않게 카메라 쪽으로
  mv.xy += position.xy * iSize * (1.0 + iAmt.y * 0.8);
  gl_Position = projectionMatrix * mv;
  if (iAmt.x <= 0.001) gl_Position = vec4(2.0, 2.0, 2.0, 1.0); // 꺼진 것은 클립
}`;
const frag = /* glsl */`
uniform float uCore;
varying vec2 vUv;
varying vec3 vColor;
varying vec2 vAmt;
void main() {
  float r = length(vUv - 0.5) * 2.0;
  if (r > 1.0) discard;
  float core = exp(-r * r * 45.0) * 1.8;
  float halo = exp(-r * r * 5.0) * (1.0 - r) * (0.35 + vAmt.y * 0.35);
  gl_FragColor = vec4(vColor * (core * uCore + halo) * vAmt.x, 1.0);
}`;

export function createNightLights(scene, lights) {
  const list = (lights || []).map((l, i) => {
    const k = KIND[l.kind] || KIND.lantern;
    return { x: l.x, y: l.y, z: l.z, k, phase: i * 1.731 + (l.x * 0.37 + l.z * 0.11), d2: 0, slot: -1 };
  });
  const N = list.length;
  const MAX = 6;

  // PointLight 슬롯
  const slots = [];
  for (let i = 0; i < MAX; i++) {
    const p = new THREE.PointLight(0xffa855, 0, 9, 2);
    p.name = 'fx-lamp-' + i;
    p.castShadow = false;
    scene.add(p);
    slots.push({ light: p, idx: -1, w: 0 });
  }

  // 발광 스프라이트(인스턴스)
  let mesh = null, amtAttr = null;
  if (N > 0) {
    const base = new THREE.PlaneGeometry(1, 1);
    const g = new THREE.InstancedBufferGeometry();
    g.index = base.index;
    g.setAttribute('position', base.getAttribute('position'));
    g.setAttribute('uv', base.getAttribute('uv'));
    const pos = new Float32Array(N * 3), col = new Float32Array(N * 3), size = new Float32Array(N), amt = new Float32Array(N * 2);
    const c = new THREE.Color();
    list.forEach((l, i) => {
      pos[i * 3] = l.x; pos[i * 3 + 1] = l.y; pos[i * 3 + 2] = l.z;
      c.set(l.k.glow).multiplyScalar(l.k.core >= 1 ? 1.6 : 1.2);
      col[i * 3] = c.r; col[i * 3 + 1] = c.g; col[i * 3 + 2] = c.b;
      size[i] = l.k.size;
    });
    g.setAttribute('iPos', new THREE.InstancedBufferAttribute(pos, 3));
    g.setAttribute('iColor', new THREE.InstancedBufferAttribute(col, 3));
    g.setAttribute('iSize', new THREE.InstancedBufferAttribute(size, 1));
    amtAttr = new THREE.InstancedBufferAttribute(amt, 2);
    amtAttr.setUsage(THREE.DynamicDrawUsage);
    g.setAttribute('iAmt', amtAttr);
    g.instanceCount = N;
    const m = new THREE.ShaderMaterial({
      uniforms: { uCore: { value: 1 } },
      vertexShader: vert, fragmentShader: frag,
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, fog: false,
    });
    mesh = new THREE.Mesh(g, m);
    mesh.name = 'fx-lamp-glows';
    mesh.frustumCulled = false;
    mesh.renderOrder = 10;
    mesh.raycast = () => {};
    scene.add(mesh);
  }

  const order = new Int32Array(N);
  const want = new Uint8Array(N);
  let reselect = 0;

  function flick(l, t) {
    const p = l.phase;
    return 1 + l.k.flick * (Math.sin(t * 11.3 + p) * 0.5 + Math.sin(t * 23.7 + p * 2.1) * 0.3 + Math.sin(t * 5.1 + p * 3.3) * 0.4);
  }

  return {
    mesh,
    update(dt, t, focus, lamp, maxReal) {
      if (!N) { for (const s of slots) s.light.intensity = 0; return; }
      // 가까운 순 선택(0.25초마다)
      reselect -= dt;
      if (reselect <= 0) {
        reselect = 0.25;
        for (let i = 0; i < N; i++) {
          const l = list[i], dx = l.x - focus.x, dz = l.z - focus.z, dy = l.y - focus.y;
          l.d2 = dx * dx + dz * dz + dy * dy * 0.5;
          order[i] = i;
        }
        // 삽입 정렬(작은 N, 할당 없음)
        for (let i = 1; i < N; i++) {
          const v = order[i], d = list[v].d2; let j = i - 1;
          while (j >= 0 && list[order[j]].d2 > d) { order[j + 1] = order[j]; j--; }
          order[j + 1] = v;
        }
        want.fill(0);
        const lim = Math.min(maxReal, N);
        for (let i = 0; i < lim; i++) if (list[order[i]].d2 < 30 * 30) want[order[i]] = 1;
      }
      // 슬롯 갱신: 원치 않는 것은 페이드아웃 후 재배정
      const fade = Math.min(1, dt * 3);
      for (let s = 0; s < MAX; s++) {
        const slot = slots[s];
        const on = slot.idx >= 0 && want[slot.idx] && s < maxReal;
        slot.w += ((on ? 1 : 0) - slot.w) * fade;
        if (slot.idx >= 0 && !on && slot.w < 0.02) { list[slot.idx].slot = -1; slot.idx = -1; slot.w = 0; }
        if (slot.idx < 0 && s < maxReal) {
          for (let i = 0; i < N; i++) {
            const k = order[i];
            if (want[k] && list[k].slot < 0) { slot.idx = k; list[k].slot = s; slot.w = 0; break; }
          }
        }
        const L = slot.light;
        if (slot.idx >= 0 && lamp > 0.001) {
          const l = list[slot.idx];
          L.position.set(l.x, l.y, l.z);
          L.color.set(l.k.color);
          L.distance = l.k.distance;
          L.intensity = l.k.intensity * lamp * slot.w * flick(l, t);
        } else L.intensity = 0;
      }
      // 스프라이트
      const a = amtAttr.array;
      for (let i = 0; i < N; i++) {
        const l = list[i];
        const real = l.slot >= 0 ? slots[l.slot].w : 0;
        a[i * 2] = lamp * (0.85 + 0.15 * flick(l, t + 0.3));
        a[i * 2 + 1] = 1 - real;
      }
      amtAttr.needsUpdate = true;
    },
  };
}
