// 밤 조명: world.lights → 가까운 최대 6개는 실제 PointLight(깜박임), 나머지는 발광 스프라이트(인스턴싱 1 드로콜).
// PointLight 개수는 항상 고정(셰이더 재컴파일 방지) — 낮에는 intensity 0.
import * as THREE from 'three';

// size = 번짐 반경(m, 월드 단위). shape 0=원, 1=둥근 사각(창호지 문)
const KIND = {
  lantern: { color: 0xffa855, glow: 0xffb866, intensity: 22, distance: 9, size: 0.8, flick: 0.07, core: 0.9, shape: 0 },
  torch:   { color: 0xff8a3c, glow: 0xff9a48, intensity: 22, distance: 10, size: 1.0, flick: 0.16, core: 1.0, shape: 0 },
  shrine:  { color: 0xff9060, glow: 0xffa868, intensity: 14, distance: 7, size: 0.42, flick: 0.12, core: 0.8, shape: 0 },
  window:  { color: 0xffc27a, glow: 0xffcf8a, intensity: 8, distance: 7, size: 1.15, flick: 0.02, core: 0.0, shape: 1 },
};

const vert = /* glsl */`
attribute vec3 iPos;
attribute vec3 iColor;
attribute vec3 iSize;   // x: 번짐 반경(m), y: 모양(0 원, 1 둥근 사각), z: 심지 밝기
attribute vec2 iAmt;    // x: 전체 밝기, y: 번짐 보강(실제 광원이 없을 때)
uniform float uMaxNdc;  // 화면 높이 대비 최대 반경(NDC)
varying vec2 vUv;
varying vec3 vColor;
varying vec2 vAmt;
varying float vShape;
varying float vCore;
void main() {
  vUv = uv;
  vCore = iSize.z;
  vColor = iColor;
  vAmt = iAmt;
  vShape = iSize.y;
  vec4 mv = modelViewMatrix * vec4(iPos, 1.0);
  float z = max(-mv.z, 0.1);
  float r = iSize.x * (1.0 + iAmt.y * 0.25);
  // 화면상 크기 상한: 가까운 카메라(실내)에서도 작게
  r = min(r, uMaxNdc * z / projectionMatrix[1][1]);
  mv.xyz += normalize(-mv.xyz) * min(0.25, r * 0.5); // 벽/돌에 파묻히지 않게
  mv.xy += position.xy * 2.0 * r * (iSize.y > 0.5 ? vec2(1.25, 0.85) : vec2(1.0));
  gl_Position = projectionMatrix * mv;
  // 카메라에 너무 가까우면 사라짐
  vAmt.x *= smoothstep(1.5, 3.0, z);
  if (vAmt.x <= 0.001) gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
}`;
const frag = /* glsl */`
uniform float uCore;
varying vec2 vUv;
varying vec3 vColor;
varying vec2 vAmt;
varying float vShape;
varying float vCore;
void main() {
  vec2 q = abs(vUv - 0.5) * 2.0;
  float r = vShape > 0.5 ? pow(pow(q.x, 4.0) + pow(q.y, 4.0), 0.25) : length(q);
  if (r > 1.0) discard;
  float core = exp(-r * r * 70.0) * uCore * vCore * (0.6 + 0.4 * vAmt.y);
  float halo = exp(-r * r * 4.0) * (1.0 - r) * (0.28 + vAmt.y * 0.2) * (vShape > 0.5 ? 2.4 : 1.0);
  gl_FragColor = vec4(vColor * (core + halo) * vAmt.x, 1.0);
}`;

export function createNightLights(scene, lights) {
  const list = (lights || []).map((l, i) => {
    const k = KIND[l.kind] || KIND.lantern;
    const en = l.enabled !== false;
    // src를 보관해 enabled를 매 프레임 다시 읽는다(world.setState로 런타임에 켜짐). state 조명은 낮에도 약하게 보임.
    return { x: l.x, y: l.y, z: l.z, k, phase: i * 1.731 + (l.x * 0.37 + l.z * 0.11), d2: 0, slot: -1, src: l, on: en ? 1 : 0, was: en, flare: 0, dayMin: l.state ? 0.5 : 0, f: 0 };
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
    const pos = new Float32Array(N * 3), col = new Float32Array(N * 3), size = new Float32Array(N * 3), amt = new Float32Array(N * 2);
    const c = new THREE.Color();
    list.forEach((l, i) => {
      pos[i * 3] = l.x; pos[i * 3 + 1] = l.y; pos[i * 3 + 2] = l.z;
      c.set(l.k.glow).multiplyScalar(0.9);
      col[i * 3] = c.r; col[i * 3 + 1] = c.g; col[i * 3 + 2] = c.b;
      size[i * 3] = l.k.size; size[i * 3 + 1] = l.k.shape; size[i * 3 + 2] = l.k.core;
    });
    g.setAttribute('iPos', new THREE.InstancedBufferAttribute(pos, 3));
    g.setAttribute('iColor', new THREE.InstancedBufferAttribute(col, 3));
    g.setAttribute('iSize', new THREE.InstancedBufferAttribute(size, 3));
    amtAttr = new THREE.InstancedBufferAttribute(amt, 2);
    amtAttr.setUsage(THREE.DynamicDrawUsage);
    g.setAttribute('iAmt', amtAttr);
    g.instanceCount = N;
    const m = new THREE.ShaderMaterial({
      uniforms: { uCore: { value: 1 }, uMaxNdc: { value: 0.07 } },
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
  const lastFocus = new THREE.Vector3(1e9, 0, 1e9);

  function flick(l, t) {
    const p = l.phase;
    return 1 + l.k.flick * (Math.sin(t * 11.3 + p) * 0.5 + Math.sin(t * 23.7 + p * 2.1) * 0.3 + Math.sin(t * 5.1 + p * 3.3) * 0.4);
  }

  return {
    mesh,
    update(dt, t, focus, lamp, maxReal) {
      if (!N) { for (const s of slots) s.light.intensity = 0; return; }
      
      // 켜짐 상태 갱신 + 점화 플레어
      for (let i = 0; i < N; i++) {
        const l = list[i];
        const en = l.src.enabled !== false;
        if (en && !l.was) { l.flare = 1; reselect = 0; }   // 방금 켜짐 → 확 타오름
        else if (!en && l.was) reselect = 0;
        l.was = en;
        l.on = Math.max(0, Math.min(1, l.on + (en ? 4 : -3) * dt));
        l.flare = Math.max(0, l.flare - dt * 1.2);
        // 실제 세기 배율: 밤 정도(state 조명은 낮에도 약하게) × 켜짐 × 플레어
        l.f = Math.max(lamp, en ? l.dayMin : 0) * l.on * (1 + l.flare * 1.6);
      }
      // 순간이동(워프) 감지: 슬롯을 즉시 비우고 재선택
      const jx = focus.x - lastFocus.x, jz = focus.z - lastFocus.z;
      if (jx * jx + jz * jz > 64) {
        for (const sl of slots) { if (sl.idx >= 0) list[sl.idx].slot = -1; sl.idx = -1; sl.w = 0; }
        reselect = 0;
      }
      lastFocus.copy(focus);
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
        let cnt = 0;
        for (let i = 0; i < N && cnt < lim; i++) {
          const l = list[order[i]];
          if (l.d2 >= 30 * 30) break;
          if (!l.was) continue;          // 꺼진 조명은 실제 광원 후보에서 제외
          want[order[i]] = 1; cnt++;
        }
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
        if (slot.idx >= 0 && list[slot.idx].f > 0.001) {
          const l = list[slot.idx];
          L.position.set(l.x, l.y, l.z);
          L.color.set(l.k.color);
          L.distance = l.k.distance;
          L.intensity = l.k.intensity * l.f * slot.w * flick(l, t);
        } else L.intensity = 0;
      }
      // 스프라이트
      const a = amtAttr.array;
      let anyOn = false;
      for (let i = 0; i < N; i++) {
        const l = list[i];
        const real = l.slot >= 0 ? slots[l.slot].w : 0;
        if (l.f > 0.001) anyOn = true;
        a[i * 2] = l.f * (0.85 + 0.15 * flick(l, t + 0.3)) * (1 + l.flare * 0.8);
        a[i * 2 + 1] = 1 - real;
      }
      amtAttr.needsUpdate = true;
      mesh.visible = anyOn;   // 켜진 것이 없으면(낮) 드로콜 없음
    },
  };
}
