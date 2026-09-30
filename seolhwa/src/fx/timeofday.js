// 시간대 팔레트 — 키프레임 보간
// 모든 색은 sRGB hex로 적고 THREE.Color(선형)로 변환해 둔다.
// grade(lift/gamma/gain/sat)는 톤매핑 이후 sRGB 공간에서 쓰이므로 그대로 숫자.
import * as THREE from 'three';

// 키: h=시각
// sky*: 하늘, low: 지평선 아래 운해(안개 바다), fog: 안개색, dens: FogExp2 밀도
// sun: 해/달 빛, sunI: 세기, hemiS/hemiG/hemiI: 반구광
// glow: 지평선 노을/여명색, glowI
// lift/gamma/gain: 색보정(sRGB), sat: 채도, bloom/thr: 블룸 세기/문턱
// night: 0~1 (별·달·등불 스프라이트), dayMix: 해↔달 방향 섞기(1=해)
const RAW = [
  { h: 0.0, skyTop: 0x0b1230, skyHor: 0x27365e, low: 0x1f2c4c, fog: 0x1d2946, dens: 0.017,
    sun: 0x8fa8e0, sunI: 0.95, hemiS: 0x4a5f96, hemiG: 0x151a26, hemiI: 1.05,
    glow: 0x3a4a7a, glowI: 0.15,
    lift: [0.035, 0.045, 0.085], gamma: [1.16, 1.16, 1.1], gain: [0.9, 0.97, 1.12], sat: 0.72,
    bloom: 0.55, thr: 0.65, night: 1, dayMix: 0 },
  { h: 4.4, skyTop: 0x0d1534, skyHor: 0x2b3a62, low: 0x223050, fog: 0x202c4a, dens: 0.018,
    sun: 0x8fa8e0, sunI: 0.9, hemiS: 0x4a5f96, hemiG: 0x151a26, hemiI: 1.0,
    glow: 0x3a4a7a, glowI: 0.15,
    lift: [0.035, 0.045, 0.085], gamma: [1.16, 1.16, 1.1], gain: [0.9, 0.97, 1.12], sat: 0.72,
    bloom: 0.55, thr: 0.65, night: 1, dayMix: 0 },
  // 새벽: 서늘한 라벤더·옅은 복숭아빛, 짙은 산안개
  { h: 5.6, skyTop: 0x4a5684, skyHor: 0xd9b7ae, low: 0xb4b4c8, fog: 0xb0b2c6, dens: 0.022,
    sun: 0xf6c0a8, sunI: 1.5, hemiS: 0xa0a8cc, hemiG: 0x55525c, hemiI: 1.25,
    glow: 0xf2a88e, glowI: 0.55,
    lift: [0.035, 0.035, 0.06], gamma: [1.06, 1.05, 1.03], gain: [0.99, 0.97, 1.0], sat: 0.78,
    bloom: 0.35, thr: 0.8, night: 0.35, dayMix: 0.6 },
  { h: 7.0, skyTop: 0x7e9cc0, skyHor: 0xeed8c6, low: 0xd2ccd0, fog: 0xd2cacb, dens: 0.016,
    sun: 0xffd6b0, sunI: 2.5, hemiS: 0xb0bcdc, hemiG: 0x6e6258, hemiI: 1.15,
    glow: 0xf6c09a, glowI: 0.35,
    lift: [0.02, 0.02, 0.035], gamma: [1.04, 1.03, 1.02], gain: [1.03, 1.0, 0.98], sat: 0.88,
    bloom: 0.2, thr: 0.88, night: 0, dayMix: 1 },
  // 낮: 맑고 담백한 민화 하늘, 옅은 안개
  { h: 9.0, skyTop: 0x84a9c6, skyHor: 0xe9e4cf, low: 0xd5d8cc, fog: 0xd0d5cb, dens: 0.0085,
    sun: 0xfff6ea, sunI: 3.1, hemiS: 0xb8cce6, hemiG: 0x86785a, hemiI: 1.2,
    glow: 0xfff0d0, glowI: 0.1,
    lift: [0.012, 0.012, 0.02], gamma: [1.02, 1.02, 1.0], gain: [1.03, 1.02, 0.99], sat: 0.92,
    bloom: 0.14, thr: 0.92, night: 0, dayMix: 1 },
  { h: 15.6, skyTop: 0x84a9c6, skyHor: 0xece2c8, low: 0xd8d8c8, fog: 0xd3d4c6, dens: 0.009,
    sun: 0xfff6ea, sunI: 3.1, hemiS: 0xb8cce6, hemiG: 0x86785a, hemiI: 1.2,
    glow: 0xfff0d0, glowI: 0.12,
    lift: [0.012, 0.012, 0.02], gamma: [1.02, 1.02, 1.0], gain: [1.03, 1.02, 0.99], sat: 0.92,
    bloom: 0.14, thr: 0.92, night: 0, dayMix: 1 },
  // 해질녘: 호박색, 긴 그림자
  { h: 17.2, skyTop: 0x6d86ac, skyHor: 0xf2c98e, low: 0xdcb895, fog: 0xd4b69c, dens: 0.011,
    sun: 0xffca90, sunI: 3.1, hemiS: 0x9ca6d0, hemiG: 0x5e4c40, hemiI: 1.3,
    glow: 0xffa650, glowI: 0.55,
    lift: [0.03, 0.02, 0.03], gamma: [1.02, 1.0, 1.0], gain: [1.05, 0.99, 0.92], sat: 0.9,
    bloom: 0.28, thr: 0.84, night: 0, dayMix: 1 },
  { h: 18.3, skyTop: 0x4f5d8e, skyHor: 0xf09a58, low: 0xb8949a, fog: 0xba948c, dens: 0.013,
    sun: 0xffb474, sunI: 3.1, hemiS: 0x8a90cc, hemiG: 0x4c4044, hemiI: 1.45,
    glow: 0xff7a3a, glowI: 0.85,
    lift: [0.03, 0.025, 0.05], gamma: [1.08, 1.05, 1.05], gain: [1.05, 0.98, 0.93], sat: 0.92,
    bloom: 0.4, thr: 0.78, night: 0.15, dayMix: 0.9 },
  // 땅거미: 보랏빛 푸른 시간
  { h: 19.4, skyTop: 0x1f2a58, skyHor: 0x8a6a8a, low: 0x4c4f72, fog: 0x454a6c, dens: 0.016,
    sun: 0xa89ad0, sunI: 0.9, hemiS: 0x5d6394, hemiG: 0x1d1a26, hemiI: 1.0,
    glow: 0xc0708a, glowI: 0.45,
    lift: [0.04, 0.035, 0.07], gamma: [1.12, 1.1, 1.06], gain: [0.95, 0.95, 1.08], sat: 0.8,
    bloom: 0.65, thr: 0.66, night: 0.75, dayMix: 0.25 },
  { h: 20.6, skyTop: 0x0c1332, skyHor: 0x29386a, low: 0x223052, fog: 0x1f2b4a, dens: 0.017,
    sun: 0x8fa8e0, sunI: 0.95, hemiS: 0x4a5f96, hemiG: 0x151a26, hemiI: 1.05,
    glow: 0x3a4a7a, glowI: 0.15,
    lift: [0.035, 0.045, 0.085], gamma: [1.16, 1.16, 1.1], gain: [0.9, 0.97, 1.12], sat: 0.72,
    bloom: 0.55, thr: 0.65, night: 1, dayMix: 0 },
];

const COLOR_KEYS = ['skyTop', 'skyHor', 'low', 'fog', 'sun', 'hemiS', 'hemiG', 'glow'];
const NUM_KEYS = ['dens', 'sunI', 'hemiI', 'glowI', 'sat', 'bloom', 'thr', 'night', 'dayMix'];
const VEC_KEYS = ['lift', 'gamma', 'gain'];

const KEYS = RAW.map((k) => {
  const o = { h: k.h };
  for (const c of COLOR_KEYS) o[c] = new THREE.Color(k[c]);
  for (const n of NUM_KEYS) o[n] = k[n];
  for (const v of VEC_KEYS) o[v] = new THREE.Vector3(...k[v]);
  return o;
});

export function createTimeState() {
  const o = {};
  for (const c of COLOR_KEYS) o[c] = new THREE.Color();
  for (const n of NUM_KEYS) o[n] = 0;
  for (const v of VEC_KEYS) o[v] = new THREE.Vector3();
  return o;
}

function smooth(t) { return t * t * (3 - 2 * t); }

// hour(0~24) → out 상태 (할당 없음)
export function sampleTime(hour, out) {
  const h = ((hour % 24) + 24) % 24;
  const n = KEYS.length;
  let a = KEYS[n - 1], b = KEYS[0], span, t;
  // 마지막 키 → 24+첫 키 구간
  let found = false;
  for (let i = 0; i < n - 1; i++) {
    if (h >= KEYS[i].h && h < KEYS[i + 1].h) { a = KEYS[i]; b = KEYS[i + 1]; found = true; break; }
  }
  if (found) { span = b.h - a.h; t = (h - a.h) / span; }
  else {
    a = KEYS[n - 1]; b = KEYS[0];
    span = 24 - a.h + b.h;
    t = (h >= a.h ? h - a.h : h + 24 - a.h) / span;
  }
  t = smooth(t);
  for (const c of COLOR_KEYS) out[c].copy(a[c]).lerp(b[c], t);
  for (const k of NUM_KEYS) out[k] = a[k] + (b[k] - a[k]) * t;
  for (const v of VEC_KEYS) out[v].copy(a[v]).lerp(b[v], t);
  return out;
}

// 해/달의 방향(빛이 오는 쪽, 단위벡터). 남쪽(+z) 성분을 항상 두어 그림자가 카메라 반대(북쪽)로 떨어지게.
function arc(theta, maxElev, south, out) {
  const s = Math.sin(theta);
  const x = Math.cos(theta);             // 6시 동(+x) → 18시 서(-x)
  const y = Math.max(0.3, s * maxElev); // 너무 낮으면 그림자가 끝없이 길어짐
  const z = south + Math.max(0, s) * 0.55;
  return out.set(x * 0.9, y, z).normalize();
}

const _sun = new THREE.Vector3();
const _moon = new THREE.Vector3();
export function lightDirection(hour, dayMix, out) {
  const h = ((hour % 24) + 24) % 24;
  arc(((h - 6) / 12) * Math.PI, 1.05, 0.45, _sun);
  const hm = h < 12 ? h + 24 : h;        // 달: 18시 동쪽 → 6시 서쪽
  arc(((hm - 18) / 12) * Math.PI, 0.85, 0.6, _moon);
  return out.copy(_moon).lerp(_sun, dayMix).normalize();
}

// 밤 조명 켜짐 정도 (18.5~19.5에 켜지고 5~6시에 꺼짐)
export function lampFactor(hour) {
  const h = ((hour % 24) + 24) % 24;
  const on = THREE.MathUtils.smoothstep(h, 18.5, 19.5);
  const off = 1 - THREE.MathUtils.smoothstep(h, 5.0, 6.0);
  return h >= 12 ? on : off;
}
