// 공용 도우미: 수학, 잡음, 지오메트리 준비·색칠·병합, 먹선(뒤집은 헐) 생성
import * as THREE from 'three';

export const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
export const lerp = (a, b, t) => a + (b - a) * t;
export function smoothstep(a, b, x) {
  const t = clamp((x - a) / (b - a), 0, 1);
  return t * t * (3 - 2 * t);
}

export function hash2(x, z) {
  const h = Math.sin(x * 127.1 + z * 311.7) * 43758.5453123;
  return h - Math.floor(h);
}
export function vnoise(x, z) {
  const xi = Math.floor(x), zi = Math.floor(z);
  const xf = x - xi, zf = z - zi;
  const u = xf * xf * (3 - 2 * xf), v = zf * zf * (3 - 2 * zf);
  const a = hash2(xi, zi), b = hash2(xi + 1, zi), c = hash2(xi, zi + 1), d = hash2(xi + 1, zi + 1);
  return lerp(lerp(a, b, u), lerp(c, d, u), v) * 2 - 1;
}
export function fbm(x, z, oct = 4) {
  let s = 0, a = 0.5, f = 1;
  for (let i = 0; i < oct; i++) { s += a * vnoise(x * f + i * 17.3, z * f - i * 9.1); f *= 2.03; a *= 0.5; }
  return s;
}
export function rng(seed) {
  let t = seed >>> 0;
  return function () {
    t = (t + 0x6d2b79f5) >>> 0;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r;
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

// 지오메트리를 비인덱스 + position/normal/uv/color 네 속성으로 통일
export function prep(geo) {
  let g = geo.index ? geo.toNonIndexed() : geo;
  const n = g.attributes.position.count;
  if (!g.attributes.normal) g.computeVertexNormals();
  if (!g.attributes.uv) g.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(n * 2), 2));
  if (!g.attributes.color) g.setAttribute('color', new THREE.BufferAttribute(new Float32Array(n * 3).fill(1), 3));
  for (const k of Object.keys(g.attributes)) if (!['position', 'normal', 'uv', 'color'].includes(k)) g.deleteAttribute(k);
  return g;
}

const _c1 = new THREE.Color(), _c2 = new THREE.Color();
// 세로 그라데이션(아래 bottom → 위 top) + 면마다 약간의 얼룩
export function paint(g, top, bottom = top, jitter = 0.05, rnd = Math.random) {
  g = prep(g);
  const pos = g.attributes.position, col = g.attributes.color;
  g.computeBoundingBox();
  const y0 = g.boundingBox.min.y, hy = (g.boundingBox.max.y - y0) || 1;
  _c1.set(top); _c2.set(bottom);
  for (let i = 0; i < pos.count; i += 3) {
    const j = (rnd() - 0.5) * jitter;
    for (let k = 0; k < 3 && i + k < pos.count; k++) {
      const t = (pos.getY(i + k) - y0) / hy;
      col.setXYZ(i + k,
        Math.max(0, lerp(_c2.r, _c1.r, t) + j),
        Math.max(0, lerp(_c2.g, _c1.g, t) + j),
        Math.max(0, lerp(_c2.b, _c1.b, t) + j * 0.8));
    }
  }
  col.needsUpdate = true;
  return g;
}

const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _e = new THREE.Euler(), _v = new THREE.Vector3(), _s = new THREE.Vector3();
export function xf(g, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0, sx = 1, sy = sx, sz = sx) {
  _e.set(rx, ry, rz, 'YXZ');
  _q.setFromEuler(_e);
  _m.compose(_v.set(x, y, z), _q, _s.set(sx, sy, sz));
  g.applyMatrix4(_m);
  return g;
}
export function applyM(g, m) { g.applyMatrix4(m); return g; }

// 병합: prep된 지오메트리들
export function merge(list) {
  let n = 0;
  for (const g of list) n += g.attributes.position.count;
  const P = new Float32Array(n * 3), N = new Float32Array(n * 3), U = new Float32Array(n * 2), C = new Float32Array(n * 3);
  let o = 0;
  for (const g of list) {
    const c = g.attributes.position.count;
    P.set(g.attributes.position.array, o * 3);
    N.set(g.attributes.normal.array, o * 3);
    U.set(g.attributes.uv.array, o * 2);
    C.set(g.attributes.color.array, o * 3);
    o += c;
  }
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.BufferAttribute(P, 3));
  out.setAttribute('normal', new THREE.BufferAttribute(N, 3));
  out.setAttribute('uv', new THREE.BufferAttribute(U, 2));
  out.setAttribute('color', new THREE.BufferAttribute(C, 3));
  out.computeBoundingSphere();
  return out;
}
export function mergePos(list) {
  let n = 0;
  for (const g of list) n += g.attributes.position.count;
  const P = new Float32Array(n * 3);
  let o = 0;
  for (const g of list) { P.set(g.attributes.position.array, o); o += g.attributes.position.array.length; }
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.BufferAttribute(P, 3));
  out.computeBoundingSphere();
  return out;
}

// 먹선용 부푼 껍질: 같은 위치의 꼭짓점은 면 법선 평균 방향으로 t만큼 밀어낸다(틈 없는 헐)
export function inflate(g, t) {
  const pos = g.attributes.position, n = pos.count;
  const acc = new Map(), keys = new Array(n);
  const a = new THREE.Vector3(), b = new THREE.Vector3(), c = new THREE.Vector3(), fn = new THREE.Vector3();
  for (let i = 0; i + 2 < n; i += 3) {
    a.fromBufferAttribute(pos, i); b.fromBufferAttribute(pos, i + 1); c.fromBufferAttribute(pos, i + 2);
    fn.subVectors(c, b).cross(a.clone().sub(b));
    const len = fn.length();
    if (len > 1e-12) fn.divideScalar(len); // 면적 대신 균등 가중(얇은 면에서도 안정)
    for (let k = 0; k < 3; k++) {
      const x = pos.getX(i + k), y = pos.getY(i + k), z = pos.getZ(i + k);
      const key = `${Math.round(x * 500)},${Math.round(y * 500)},${Math.round(z * 500)}`;
      keys[i + k] = key;
      let v = acc.get(key);
      if (!v) { v = new THREE.Vector3(); acc.set(key, v); }
      v.add(fn);
    }
  }
  const P = new Float32Array(n * 3);
  for (let i = 0; i < n; i++) {
    const v = acc.get(keys[i]);
    const l = v.length() || 1;
    P[i * 3] = pos.getX(i) + (v.x / l) * t;
    P[i * 3 + 1] = pos.getY(i) + (v.y / l) * t;
    P[i * 3 + 2] = pos.getZ(i) + (v.z / l) * t;
  }
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.BufferAttribute(P, 3));
  return out;
}

// 재질 키별로 모아 한 번에 병합하는 묶음. outline>0이면 먹선 껍질도 모은다.
export class Batch {
  constructor() { this.parts = new Map(); this.lines = []; }
  add(key, geo, outline = 0.03) {
    const g = prep(geo);
    if (!this.parts.has(key)) this.parts.set(key, []);
    this.parts.get(key).push(g);
    if (outline > 0) this.lines.push(inflate(g, outline));
    return g;
  }
  get empty() { return this.parts.size === 0; }
  // makeMat(key) → Material (새 인스턴스), ink → 먹선 재질
  build(makeMat, ink, { cast = true, receive = true, name = '' } = {}) {
    const grp = new THREE.Group();
    grp.name = name;
    for (const [key, list] of this.parts) {
      const m = new THREE.Mesh(merge(list), makeMat(key));
      m.castShadow = cast && key !== 'water' && key !== 'glow';
      m.receiveShadow = receive;
      m.name = `${name}:${key}`;
      grp.add(m);
    }
    if (this.lines.length && ink) {
      const o = new THREE.Mesh(mergePos(this.lines), ink);
      o.name = `${name}:ink`;
      o.castShadow = false; o.receiveShadow = false;
      grp.add(o);
    }
    return grp;
  }
}

// 박스를 원하는 위치에 (가장 흔히 쓰임): 중심 x,y,z, 크기 w,h,d
export function box(w, h, d, x = 0, y = 0, z = 0, ry = 0) {
  return xf(new THREE.BoxGeometry(w, h, d), x, y, z, 0, ry, 0);
}
export function cyl(rt, rb, h, seg, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0) {
  return xf(new THREE.CylinderGeometry(rt, rb, h, seg, 1), x, y, z, rx, ry, rz);
}
// 두 점 사이 원기둥(가지·줄기)
export function limb(a, b, r0, r1, seg = 6) {
  const d = new THREE.Vector3().subVectors(b, a);
  const len = d.length();
  const g = new THREE.CylinderGeometry(r1, r0, len, seg, 1);
  g.translate(0, len / 2, 0);
  const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), d.normalize());
  g.applyQuaternion(q);
  g.translate(a.x, a.y, a.z);
  return g;
}
// 울퉁불퉁한 덩어리(바위·잎뭉치)
export function lump(r, detail, rnd, rough = 0.25, sy = 1) {
  const g = prep(new THREE.IcosahedronGeometry(r, detail));
  const pos = g.attributes.position;
  const seed = rnd() * 100;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
    const k = 1 + rough * (hash2(Math.round(x * 97) + seed, Math.round(z * 97) + Math.round(y * 53) * 7) - 0.5) * 2;
    pos.setXYZ(i, x * k, y * k * sy, z * k);
  }
  g.computeVertexNormals();
  return g;
}
