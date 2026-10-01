// 3단계 사건 「산길의 실종」 무대: 주막·방앗간·기름집·헛간·외딴집 앞 고목·단서 소품·지역 변화(setState)
import * as THREE from 'three';
import { rng, xf, paint, box, cyl, limb, lump } from './util.js';
import { choga, bigTree, torchPost, curvedRoof } from './buildings.js';
import { bush } from './vegetation.js';
import { INN, MILL, BARN, BIG_TREE, YARD, HOUSE, PATH, SEONANG, ARENA, ARENA_TRAIL, streamZ } from './layout.js';

// 바닥 자국 텍스처(사람 발, 짐승 발, 핏자국, 흰 가루 발자국)
let _decalTex = null;
function decalTexture() {
  if (_decalTex) return _decalTex;
  const c = document.createElement('canvas'); c.width = 256; c.height = 64;
  const x = c.getContext('2d');
  const r = rng(808);
  // 0: 사람 짚신 자국
  x.fillStyle = 'rgba(58,44,30,0.55)';
  x.beginPath(); x.ellipse(32, 24, 9, 17, 0, 0, 7); x.fill();
  x.beginPath(); x.ellipse(32, 46, 7, 9, 0, 0, 7); x.fill();
  // 1: 큰 짐승 발(볼록살 + 발가락 넷)
  const paw = (ox, col) => {
    x.fillStyle = col;
    x.beginPath(); x.ellipse(ox + 32, 40, 13, 11, 0, 0, 7); x.fill();
    for (const [dx, dy] of [[-15, 22], [-6, 15], [6, 15], [15, 22]]) { x.beginPath(); x.ellipse(ox + 32 + dx, dy, 5, 7, dx * 0.02, 0, 7); x.fill(); }
  };
  paw(64, 'rgba(50,36,24,0.6)');
  // 2: 핏자국
  for (let i = 0; i < 26; i++) {
    x.fillStyle = `rgba(${110 + r() * 30},${18 + r() * 12},${16 + r() * 8},${0.45 + r() * 0.4})`;
    const a = r() * 6.28, d = r() * r() * 26;
    x.beginPath(); x.ellipse(160 + Math.cos(a) * d, 32 + Math.sin(a) * d, 2 + r() * 7, 1.5 + r() * 5, a, 0, 7); x.fill();
  }
  // 3: 흰 가루 짐승 발
  paw(192, 'rgba(250,248,240,0.9)');
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  _decalTex = t;
  return t;
}
function decalMaterial() {
  return new THREE.MeshLambertMaterial({ map: decalTexture(), transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4 });
}
// 자국 메시: items [{x,z,rot,kind,s}] — 꼭짓점마다 지면 높이를 따라 붙인다
function decalMesh(name, items, ground) {
  const P = [], U = [], I = [];
  for (const it of items) {
    const s = it.s || 0.3, c = Math.cos(it.rot || 0), n = Math.sin(it.rot || 0);
    const b = P.length / 3;
    for (const [lx, lz, u, v] of [[-s / 2, -s, 0, 1], [s / 2, -s, 1, 1], [-s / 2, s, 0, 0], [s / 2, s, 1, 0]]) {
      const wx = it.x + lx * c - lz * n, wz = it.z + lx * n + lz * c;
      P.push(wx, ground(wx, wz) + 0.04, wz);
      U.push((it.kind + u) / 4, v);
    }
    I.push(b, b + 2, b + 1, b + 1, b + 2, b + 3);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(P, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(U, 2));
  g.setIndex(I);
  g.computeVertexNormals();
  const m = new THREE.Mesh(g, decalMaterial());
  m.name = name;
  m.receiveShadow = true;
  m.renderOrder = 1;
  return m;
}
// 떡 한 접시(잎 위 떡 몇 개)
function riceCakes(add, rnd, n = 3) {
  add('p', 'leaf', paint(xf(new THREE.CylinderGeometry(0.22, 0.24, 0.02, 8), 0, 0.02, 0), '#7f9456', '#5f7240'), 0.008);
  const cols = ['#f3eedf', '#e9b7c4', '#cfd8a8'];
  for (let i = 0; i < n; i++) {
    const g = new THREE.CylinderGeometry(0.06, 0.065, 0.05, 8);
    xf(g, (i - (n - 1) / 2) * 0.12 + (rnd() - 0.5) * 0.03, 0.05 + (i % 2) * 0.01, (rnd() - 0.5) * 0.08);
    add('p', 'organic', paint(g, cols[i % 3], cols[i % 3]), 0.006);
  }
}

export function buildStory(ctx) {
  const { root, ground, at, occGroup, circle, boxC, lights } = ctx;
  const anchors = {};
  const stateObjs = {};       // key → [Object3D]
  const clueObjs = {};        // anchor 이름 → [Object3D]
  const addState = (key, o) => { (stateObjs[key] ||= []).push(o); o.visible = false; return o; };
  const addClue = (name, o) => { (clueObjs[name] ||= []).push(o); return o; };
  const small = (name, x, z, fn, ry = 0) => occGroup(name, x, ground(x, z), z, fn, { occ: false, cast: false, ry });
  const torchLights = [];

  // ---------- 주막 ----------
  {
    const { x, z, w, d } = INN;
    const y = ground(x, z), rnd = rng(301);
    occGroup('주막', x, y, z, (add) => choga(add, { w, d, rnd, hump: 0.1 }));
    boxC(x - w / 2 - 0.45, x + w / 2 + 0.45, z - d / 2 - 0.45, z + d / 2 + 0.75);
    lights.push({ x, y: y + 1.25, z: z + d / 2 + 0.2, kind: 'window' });
    const a = at(x, y, z);
    // 평상
    a('p', 'wood', paint(box(2.2, 0.08, 1.3, -1.0, 0.45, d / 2 + 2.3), '#9a7852', '#7a5c3e'), 0.02);
    for (const [dx, dz] of [[-1, -0.55], [1, -0.55], [-1, 0.55], [1, 0.55]]) a('p', 'wood', paint(box(0.08, 0.45, 0.08, -1.0 + dx, 0.22, d / 2 + 2.3 + dz), '#6b5038'), 0.01);
    a('p', 'onggi', paint(cyl(0.12, 0.1, 0.08, 8, -1.4, 0.53, d / 2 + 2.2), '#e8e2d2', '#c8c0ac'), 0.006);
    a('p', 'onggi', paint(cyl(0.08, 0.06, 0.16, 8, -0.9, 0.57, d / 2 + 2.4), '#6e4a33', '#3e281c'), 0.006);
    boxC(x - 2.2, x + 0.2, z + d / 2 + 1.6, z + d / 2 + 3.0);
    // 술독 셋
    for (const [dx, dz, s] of [[-w / 2 - 0.8, d / 2 - 0.3, 1], [-w / 2 - 0.9, d / 2 + 0.6, 0.85], [-w / 2 - 1.6, d / 2 + 0.1, 0.9]]) {
      const pts = [[0, 0], [0.3, 0], [0.5, 0.2], [0.55, 0.5], [0.45, 0.8], [0.3, 0.9], [0, 0.9]].map(([p, q]) => new THREE.Vector2(p * s, q * s));
      a('p', 'onggi', paint(xf(new THREE.LatheGeometry(pts, 10), dx, 0, dz), '#6e4a33', '#3e281c', 0.04, rnd), 0.018);
      a('p', 'wood', paint(cyl(0.3 * s, 0.3 * s, 0.05, 10, dx, 0.92 * s, dz), '#8a6a46'), 0.01);
    }
    boxC(x - w / 2 - 2.2, x - w / 2 - 0.2, z + d / 2 - 0.9, z + d / 2 + 1.2);
    // 초롱 장대 + 주막 깃발
    const px = w / 2 + 0.6, pz = d / 2 + 1.2;
    a('p', 'wood', paint(cyl(0.05, 0.07, 3.2, 6, px, 1.6, pz), '#6b5038'), 0.012);
    a('p', 'wood', paint(box(0.8, 0.05, 0.05, px - 0.35, 3.0, pz), '#6b5038'), 0.008);
    a('p', 'cloth', paint(xf(new THREE.PlaneGeometry(0.5, 1.1), px - 0.45, 2.4, pz), '#f0ead8', '#e2dac2'), 0);
    a('p', 'lamp', paint(cyl(0.15, 0.13, 0.3, 8, px, 2.1, pz + 0.18), '#c0443a', '#a63a32'), 0.01);
    circle(x + px, z + pz, 0.2);
    lights.push({ x: x + px, y: y + 2.1, z: z + pz + 0.18, kind: 'lantern' });
    anchors.inn = { x: x + 2.8, z: z + d / 2 + 1.8 };
  }

  // ---------- 방앗간 + 물레방아 ----------
  let wheel;
  {
    const { x, z, w, d, pad } = MILL;
    const rnd = rng(311);
    occGroup('방앗간', x, pad, z, (add) => {
      choga(add, { w, d, rnd, hump: -0.15, chimney: false });
      // 찢어진 밀가루 자루(문 앞) + 쏟아진 가루
      add('p', 'cloth', paint(xf(new THREE.SphereGeometry(0.32, 8, 5), w / 2 - 0.7, 0.3, d / 2 + 1.0, 0, 0, 0.3, 1, 0.75, 0.8), '#e8e0c8', '#cfc4a6'), 0.012);
      add('p', 'cloth', paint(xf(new THREE.PlaneGeometry(0.35, 0.3), w / 2 - 0.45, 0.42, d / 2 + 1.22, -0.3, 0.6, 0.4), '#e8e0c8'), 0);
      add('p', 'organic', paint(xf(new THREE.CylinderGeometry(0.45, 0.6, 0.04, 9), w / 2 - 0.2, 0.03, d / 2 + 1.25), '#fbf8f0', '#f2eee2'), 0);
      // 디딜방아 맷돌
      add('p', 'stone', paint(cyl(0.45, 0.45, 0.25, 10, -w / 2 + 0.8, 0.12, d / 2 + 0.95), '#bdb7aa', '#8e897f'), 0.015);
      add('p', 'stone', paint(cyl(0.42, 0.42, 0.2, 10, -w / 2 + 0.8, 0.35, d / 2 + 0.95), '#c4beb1', '#9a958a'), 0.015);
      // 물길 홈통(뒤에서 바퀴 위로)
      add('p', 'wood', paint(xf(new THREE.BoxGeometry(0.5, 0.25, 5.4), -w / 2 - 1.1, 2.55, 0.3, -0.05, 0, 0), '#7a5c3e', '#5e442e'), 0.015);
      for (const zz of [-2.4, -0.6]) add('p', 'wood', paint(box(0.1, 2.5, 0.1, -w / 2 - 1.1, 1.25, zz), '#6b5038'), 0.01);
    });
    boxC(x - w / 2 - 0.45, x + w / 2 + 0.45, z - d / 2 - 0.45, z + d / 2 + 0.75);
    boxC(x - w / 2 - 1.9, x - w / 2 - 0.45, z - 3.0, z + 3.9);
    lights.push({ x, y: pad + 1.25, z: z + d / 2 + 0.2, kind: 'window' });
    // 물레방아(바퀴는 update에서 돈다)
    const wb = new (ctx.Batch)();
    const add = (p, k, g, o = 0.02) => wb.add(k, g, o);
    add('p', 'wood', paint(xf(new THREE.TorusGeometry(1.45, 0.07, 4, 20), 0, 0, 0.22), '#6b5038'), 0.012);
    add('p', 'wood', paint(xf(new THREE.TorusGeometry(1.45, 0.07, 4, 20), 0, 0, -0.22), '#6b5038'), 0.012);
    add('p', 'wood', paint(cyl(0.16, 0.16, 0.7, 8, 0, 0, 0, Math.PI / 2, 0, 0), '#4d3826'), 0.012);
    for (let i = 0; i < 12; i++) {
      const a = (i / 12) * Math.PI * 2;
      add('p', 'wood', paint(xf(new THREE.BoxGeometry(0.06, 1.4, 0.06), Math.cos(a) * 0.7, Math.sin(a) * 0.7, 0, 0, 0, a - Math.PI / 2), '#7a5c3e'), 0);
      add('p', 'wood', paint(xf(new THREE.BoxGeometry(0.35, 0.06, 0.5), Math.cos(a) * 1.5, Math.sin(a) * 1.5, 0, 0, 0, a), '#8a6a46', '#6b5038'), 0.01);
    }
    wheel = wb.build(ctx.make, null, { name: '물레방아', cast: true });
    const wx = x - w / 2 - 1.1, wz = z + 3.0;
    wheel.position.set(wx, pad + 0.85, wz);
    root.add(wheel);
    anchors.mill = { x: x + w / 2 + 1.0, z: z + d / 2 + 0.6 };
    // 흰 발자국: 방앗간 문앞에서 산길 쪽으로
    const items = [];
    const sx = x + w / 2 - 0.2, sz = z + d / 2 + 1.6, ex = -4.5, ez = -25.6;
    for (let i = 0; i < 12; i++) {
      const t = i / 11, px = sx + (ex - sx) * t, pz = sz + (ez - sz) * t + Math.sin(t * 6) * 0.3;
      const rot = Math.atan2(ex - sx, -(ez - sz)) + Math.PI;
      items.push({ x: px + (i % 2 ? 0.18 : -0.18), z: pz, rot, kind: 3, s: 0.2 });
    }
    const fm = decalMesh('흰 발자국', items, ground);
    root.add(fm);
    addClue('flour_prints', fm);
    anchors.flour_prints = { x: (sx + ex) / 2 + 0.6, z: (sz + ez) / 2 + 0.6 };
  }

  // ---------- 기름집(끝순이네 장독대 곁): 참기름 병 ----------
  {
    const x = -13.2, z = -3.9;
    const a = at(x, ground(x, z), z);
    a('p', 'wood', paint(box(0.7, 0.45, 0.5, 0, 0.22, 0), '#7a5c3e', '#5e442e'), 0.012);
    const pts = [[0, 0], [0.09, 0], [0.11, 0.1], [0.1, 0.2], [0.04, 0.28], [0.035, 0.34], [0, 0.34]].map(([p, q]) => new THREE.Vector2(p, q));
    a('p', 'onggi', paint(xf(new THREE.LatheGeometry(pts, 10), -0.15, 0.45, 0), '#c98a2e', '#8a5a1e'), 0.006);
    a('p', 'onggi', paint(xf(new THREE.LatheGeometry(pts, 10), 0.12, 0.45, 0.05, 0, 0, 0, 0.8), '#c98a2e', '#8a5a1e'), 0.006);
    a('p', 'wood', paint(box(0.06, 0.05, 0.06, -0.15, 0.81, 0), '#3f2f22'), 0);
    circle(x, z, 0.45);
    anchors.oil_shop = { x: x - 0.2, z: z + 1.0 };
  }

  // ---------- 헛간: 낡은 동아줄 ----------
  {
    const { x, z, w, d } = BARN;
    const y = ground(x, z), rnd = rng(321);
    occGroup('헛간', x, y, z, (add) => {
      for (const [px, pz] of [[-w / 2, -d / 2], [w / 2, -d / 2], [-w / 2, d / 2], [w / 2, d / 2]]) add('p', 'wood', paint(box(0.18, 2.4, 0.18, px, 1.2, pz), '#6b5038', '#4d3826'), 0.015);
      add('p', 'wood', paint(box(w, 2.2, 0.08, 0, 1.1, -d / 2), '#8a6a46', '#6b5038', 0.06, rnd), 0.015);
      for (const s of [-1, 1]) add('p', 'wood', paint(box(0.08, 2.2, d, s * w / 2, 1.1, 0), '#8a6a46', '#6b5038', 0.06, rnd), 0.015);
      // 외쪽 이엉지붕
      const rf = new THREE.BoxGeometry(w + 0.9, 0.3, d + 0.6);
      xf(rf, 0, 2.55, -0.25, 0.3, 0, 0);
      add('p', 'thatch', paint(rf, '#d8c48f', '#9d8656', 0.05, rnd), 0.035);
      // 동아줄 똬리(누렇게 삭은 줄) + 지게, 짚단
      for (let i = 0; i < 5; i++) add('p', 'thatch', paint(xf(new THREE.TorusGeometry(0.42 - i * 0.02, 0.05, 5, 16), -0.6, 0.06 + i * 0.09, 0.9, Math.PI / 2, 0, 0), '#9c8a62', '#7a6a48'), i === 4 ? 0.008 : 0);
      add('p', 'thatch', paint(xf(new THREE.TorusGeometry(0.3, 0.04, 4, 12), -0.1, 0.05, 0.6, Math.PI / 2 - 0.2, 0, 0.3), '#8a7a58'), 0);
      add('p', 'wood', paint(limb(new THREE.Vector3(1.2, 0, -0.9), new THREE.Vector3(1.0, 1.6, -1.2), 0.04, 0.03, 4), '#6b5038'), 0.008);
      add('p', 'wood', paint(limb(new THREE.Vector3(1.6, 0, -0.9), new THREE.Vector3(1.4, 1.6, -1.2), 0.04, 0.03, 4), '#6b5038'), 0.008);
      add('p', 'thatch', paint(xf(new THREE.CylinderGeometry(0.3, 0.35, 0.8, 8), 1.4, 0.4, 0.4, Math.PI / 2, 0.4, 0), '#d8c48f', '#b39d6c'), 0.012);
    });
    boxC(x - w / 2 - 0.15, x + w / 2 + 0.15, z - d / 2 - 0.15, z - d / 2 + 0.15);
    for (const s of [-1, 1]) boxC(x + s * w / 2 - 0.15, x + s * w / 2 + 0.15, z - d / 2, z + d / 2 + 0.1);
    circle(x - 0.6, z + 0.9, 0.5);
    anchors.barn = { x: x - 0.4, z: z + d / 2 + 1.0 };
  }

  // ---------- 외딴집 앞 큰 고목 ----------
  let oilMesh;
  const perches = [];
  {
    const { x, z } = BIG_TREE, y = ground(x, z);
    occGroup('외딴집 고목', x, y, z, (add) => {
      const rnd = rng(331);
      add('t', 'bark', paint(limb(new THREE.Vector3(0, -0.3, 0), new THREE.Vector3(0.2, 2.4, 0.1), 0.85, 0.7, 9), '#6a5a48', '#4a3e32', 0.05, rnd), 0.035);
      add('t', 'bark', paint(xf(new THREE.CylinderGeometry(0.9, 1.5, 0.6, 9), 0, 0.1, 0), '#5a4c3e', '#44392e'), 0.03);
      // 아이 둘이 앉을 만한 낮고 굵은 가지(동쪽=마당 쪽)
      const fork = new THREE.Vector3(0.2, 2.4, 0.1);
      const b1 = new THREE.Vector3(2.6, 2.9, 0.5), b2 = new THREE.Vector3(1.9, 3.5, -1.3);
      add('t', 'bark', paint(limb(fork, b1, 0.42, 0.24, 8), '#6a5a48', '#4a3e32', 0.05, rnd), 0.03);
      add('t', 'bark', paint(limb(fork, b2, 0.4, 0.22, 8), '#6a5a48', '#4a3e32', 0.05, rnd), 0.03);
      perches.push({ x: x + 1.9, y: y + 3.0, z: z + 0.4 }, { x: x + 1.4, y: y + 3.4, z: z - 0.9 });
      // 위로 뻗는 줄기들 + 넓은 수관
      bigTree((p, k, g, o) => add(p, k, g.translate(0.2, 1.6, 0.1), o), rnd, { h: 7.2, spread: 5.2, trunk: 0.6, branches: 4, leaf: [['#93a160', '#566238'], ['#a2a866', '#5f6c3e']] });
      // 높은 곳의 발톱 자국(남쪽 면, 2.0~2.8m)
      for (let i = 0; i < 4; i++) {
        const g = new THREE.BoxGeometry(0.06, 0.75, 0.05);
        xf(g, -0.3 + i * 0.13, 2.1 + i * 0.06, 0.78, 0, 0, 0.25);
        add('t', 'flat', paint(g, '#e8d4a6', '#cdb27f'), 0.01);
      }
    });
    circle(x, z, 0.95);
    anchors.big_tree = { x: x + 1.4, z: z + 1.6 };
    // 참기름 바른 밑동(번들거림) — state oil_on_tree
    const og = new THREE.CylinderGeometry(0.86, 0.95, 1.6, 12, 1, true);
    og.translate(0, 0.75, 0);
    oilMesh = new THREE.Mesh(og, new THREE.MeshStandardMaterial({ color: 0x8a5a22, roughness: 0.12, metalness: 0.2, transparent: true, opacity: 0.55, depthWrite: false }));
    oilMesh.position.set(x, y, z);
    oilMesh.name = '참기름 밑동';
    root.add(addState('oil_on_tree', oilMesh));
  }

  // ---------- 마당 횃불 둘(torch_lit) ----------
  for (const [tx, tz] of [[-17.6, -26.6], [-25.2, -21.6]]) {
    const y = ground(tx, tz);
    const post = small('마당 횃대', tx, tz, (add) => {
      add('p', 'wood', paint(cyl(0.06, 0.08, 1.8, 6, 0, 0.9, 0), '#6b5038', '#4d3826'), 0.012);
      add('p', 'flat', paint(xf(new THREE.ConeGeometry(0.2, 0.3, 6), 0, 1.9, 0, Math.PI, 0, 0), '#3d2e22'), 0.012);
    });
    void post;
    const flame = small('마당 횃불', tx, tz, (add) => add('p', 'glow', paint(xf(new THREE.ConeGeometry(0.13, 0.4, 6), 0, 2.15, 0), '#ffcf6a', '#ff7a2a'), 0));
    addState('torch_lit', flame);
    circle(tx, tz, 0.25);
    const L = { x: tx, y: y + 2.2, z: tz, kind: 'torch', enabled: false, state: 'torch_lit' };
    lights.push(L); torchLights.push(L);
  }

  // ---------- 유인용 떡(cake_bait) ----------
  {
    const bx = -13.5, bz = -28.4;
    const g = small('유인용 떡', bx, bz, (add) => riceCakes(add, rng(341), 3));
    addState('cake_bait', g);
    anchors.cake_bait = { x: bx, z: bz };
  }

  // ---------- 산길 단서 ----------
  const cakeSpots = [[6.0, -30.6, 'cake_1'], [14.6, -36.4, 'cake_2'], [-6.8, -48.6, 'cake_3']];
  cakeSpots.forEach(([cx, cz, name], i) => {
    const g = small(`떨어진 떡 ${i + 1}`, cx, cz, (add) => riceCakes(add, rng(350 + i), 1 + (i % 2)), i * 0.8);
    addClue(name, g);
    anchors[name] = { x: cx, z: cz };
  });
  {
    // 찢어진 치맛자락: 길가 덤불에 걸림
    const bx = 1.2, bz = -48.9;
    small('치맛자락 덤불', bx, bz, (add) => bush(add, rng(361), 0.9));
    const cl = small('찢어진 치맛자락', bx, bz, (add) => {
      add('p', 'cloth', paint(xf(new THREE.PlaneGeometry(0.5, 0.35, 2, 1), 0.1, 0.55, 0.35, -0.5, 0.3, 0.25), '#a2483e', '#7e3832'), 0);
      add('p', 'cloth', paint(xf(new THREE.PlaneGeometry(0.25, 0.4, 1, 1), -0.25, 0.45, 0.3, -0.3, -0.4, -0.3), '#a2483e', '#7e3832'), 0);
    });
    addClue('torn_skirt', cl);
    circle(bx, bz, 0.6);
    anchors.torn_skirt = { x: bx - 0.4, z: bz + 1.3 };
  }
  {
    const bl = decalMesh('핏자국', [{ x: -3.6, z: -53.8, rot: 0.4, kind: 2, s: 0.7 }, { x: -2.8, z: -54.6, rot: 1.6, kind: 2, s: 0.4 }, { x: -4.3, z: -53.2, rot: 2.2, kind: 2, s: 0.3 }], ground);
    root.add(bl);
    addClue('blood', bl);
    anchors.blood = { x: -3.4, z: -53.6 };
  }
  {
    // 사람 발자국과 큰 짐승 발자국이 섞인 길(P6 → P7)
    const [ax, az] = PATH[6], [bx, bz] = PATH[7];
    const items = [];
    const rot = Math.atan2(bx - ax, -(bz - az)) + Math.PI;
    for (let i = 0; i < 14; i++) {
      const t = (i + 0.5) / 14, px = ax + (bx - ax) * t, pz = az + (bz - az) * t;
      const nx = -(bz - az) / 9.2, nz = (bx - ax) / 9.2;
      items.push({ x: px + nx * (i % 2 ? 0.25 : -0.05), z: pz + nz * (i % 2 ? 0.25 : -0.05), rot, kind: 0, s: 0.16 });
      if (i % 2 === 0) items.push({ x: px - nx * 0.5, z: pz - nz * 0.5, rot: rot + 0.2, kind: 1, s: 0.26 });
    }
    const tm = decalMesh('뒤섞인 발자국', items, ground);
    root.add(tm);
    addClue('tracks', tm);
    anchors.tracks = { x: (ax + bx) / 2, z: (az + bz) / 2 };
  }
  {
    // 서낭당 앞 빈 떡 광주리 + 어미의 수건
    const C = SEONANG.cairn;
    const bx = C.x + 1.3, bz = C.z + 1.6;
    const bk = small('빈 떡 광주리', bx, bz, (add) => {
      const pts = [[0, 0], [0.22, 0], [0.3, 0.06], [0.34, 0.18], [0.32, 0.2], [0.28, 0.08], [0, 0.04]].map(([p, q]) => new THREE.Vector2(p, q));
      add('p', 'thatch', paint(new THREE.LatheGeometry(pts, 12), '#c8ad74', '#9a8050'), 0.012);
    }, 0.3);
    addClue('basket', bk);
    const sc = small('어미의 수건', C.x - 1.1, C.z + 1.7, (add) => {
      add('p', 'cloth', paint(xf(new THREE.PlaneGeometry(0.55, 0.32, 2, 1), 0, 0.04, 0, -Math.PI / 2 + 0.08, 0.4, 0), '#efe9d8', '#ddd5bf'), 0);
    });
    addClue('basket', sc);
    anchors.basket = { x: bx - 0.2, z: bz + 0.9 };
    anchors.headscarf = { x: C.x - 1.1, z: C.z + 2.4 };
  }

  // ---------- 지역 변화 ----------
  // 처치 후: 오색 깃발 줄, 포수의 가죽 말림틀
  {
    const cols = ['#a8483a', '#3f5f7a', '#c9a34a', '#e8e2d2', '#3a3632'];
    for (const [z0, x0, x1] of [[15.5, -3.2, 3.2], [3.6, -6, 6], [-0.2, -2.8, 2.8]]) {
      const g = small('잔치 깃발', 0, z0, (add) => {
        for (const px of [x0, x1]) add('p', 'wood', paint(cyl(0.05, 0.06, 3.4, 5, px, 1.7, 0), '#6b5038'), 0.01);
        add('p', 'flat', paint(cyl(0.01, 0.01, x1 - x0, 3, 0, 3.15, 0, 0, 0, Math.PI / 2), '#cdbf9a'), 0);
        const n = Math.round((x1 - x0) / 0.5);
        for (let i = 0; i < n; i++) {
          const px = x0 + (i + 0.5) * (x1 - x0) / n, sag = 0.35 * (1 - ((px - (x0 + x1) / 2) / ((x1 - x0) / 2)) ** 2);
          const tri = new THREE.BufferGeometry();
          tri.setAttribute('position', new THREE.Float32BufferAttribute([px - 0.17, 3.12 - sag, 0, px + 0.17, 3.12 - sag, 0, px, 2.75 - sag, 0], 3));
          add('p', 'cloth', paint(tri, cols[i % 5], cols[i % 5]), 0);
        }
      });
      g.position.y = ground(0, z0);
      addState('village_after_win', g);
    }
    const hide = small('호랑이 가죽 말림틀', -6.2, -9.0, (add) => {
      for (const s of [-1, 1]) add('p', 'wood', paint(xf(new THREE.CylinderGeometry(0.05, 0.06, 2.2, 5), s * 1.1, 1.0, 0, 0, 0, s * 0.08), '#6b5038'), 0.01);
      add('p', 'wood', paint(cyl(0.04, 0.04, 2.4, 5, 0, 2.0, 0, 0, 0, Math.PI / 2), '#6b5038'), 0.01);
      const hg = new THREE.PlaneGeometry(1.7, 1.4, 1, 1);
      xf(hg, 0, 1.25, 0.03);
      add('p', 'cloth', paint(hg, '#c98a3e', '#b0702e'), 0);
      for (let i = 0; i < 6; i++) add('p', 'cloth', paint(xf(new THREE.PlaneGeometry(0.08, 0.6), -0.65 + i * 0.26, 1.3, 0.04, 0, 0, 0.3 * (i % 2 ? 1 : -1)), '#2b2622'), 0);
    });
    addState('village_after_win', hide);
  }
  // 공통(처치·물러남): 산길 장꾼(지게·봇짐) 자리
  {
    const mx = -4.8, mz = -23.4;
    const g = small('장꾼 지게', mx, mz, (add) => {
      for (const s of [-1, 1]) add('p', 'wood', paint(limb(new THREE.Vector3(s * 0.25, 0, 0), new THREE.Vector3(s * 0.2, 1.4, -0.35), 0.04, 0.03, 4), '#6b5038'), 0.008);
      add('p', 'wood', paint(box(0.5, 0.05, 0.4, 0, 0.6, -0.1), '#7a5c3e'), 0.006);
      add('p', 'cloth', paint(xf(new THREE.SphereGeometry(0.32, 8, 5), 0, 0.95, -0.15, 0, 0, 0, 1, 0.85, 0.8), '#4f6a8a', '#3e5470'), 0.012);
      add('p', 'thatch', paint(xf(new THREE.CylinderGeometry(0.22, 0.25, 0.45, 8), 0.05, 1.35, -0.2), '#c8ad74', '#9a8050'), 0.01);
    }, 0.4);
    addState('village_after_win', g); addState('village_after_repel', g);
    anchors.merchant = { x: mx + 1.0, z: mz + 0.4 };
  }
  // 물러남: 서낭당 떡 공양
  {
    const C = SEONANG.cairn;
    const g = small('서낭당 떡 공양', C.x - 0.25, C.z + 1.45, (add) => {
      add('p', 'onggi', paint(cyl(0.2, 0.15, 0.05, 10, 0, 0.3, 0), '#e8e2d2', '#c8c0ac'), 0.006);
      for (let i = 0; i < 5; i++) add('p', 'organic', paint(xf(new THREE.CylinderGeometry(0.06, 0.065, 0.05, 8), (i % 3 - 1) * 0.11, 0.35 + Math.floor(i / 3) * 0.05, (Math.floor(i / 3) - 0.5) * 0.05), i % 2 ? '#e9b7c4' : '#f3eedf'), 0.004);
    });
    addState('village_after_repel', g);
  }

  // ---------- 고정 장소 ----------
  anchors.house_door = { x: HOUSE.x, z: HOUSE.z + HOUSE.d / 2 + 1.5 };
  anchors.house_yard = { x: YARD.x, z: YARD.z };
  anchors.village_gate = { x: 0, z: 23.4 };
  const ent = ARENA_TRAIL[ARENA_TRAIL.length - 1];
  anchors.territory_edge = { x: ent[0] - 0.8, z: ent[1] + 0.3 };
  anchors.tiger_first_seen = { x: 12.2, z: -36.9 };
  anchors.claw_tree = ctx.clawTreeSpot || { x: ARENA.x - 4, z: ARENA.z - 8 };

  const houseYard = {
    id: 'house_yard', name: '외딴집 마당', x: YARD.x, z: YARD.z, radius: YARD.r,
    tigerStart: { x: -17.2, z: -22.2 }, playerStart: { x: -21.4, z: -27.4 },
    camera: { pitch: 46, distance: 19, fov: 30 },
    perches,
  };

  const state = {};
  function setState(key, value) {
    state[key] = value;
    const on = !!value;
    if (key.startsWith('clue_taken_')) {
      const name = key.slice('clue_taken_'.length);
      for (const o of clueObjs[name] || []) o.visible = !on;
      return;
    }
    for (const o of stateObjs[key] || []) o.visible = on;
    // 같은 물체를 여러 키가 공유(장꾼): 어느 하나라도 켜져 있으면 보이게
    if (key === 'village_after_win' || key === 'village_after_repel') {
      for (const o of [...(stateObjs.village_after_win || []), ...(stateObjs.village_after_repel || [])]) {
        o.visible = (stateObjs.village_after_win.includes(o) && !!state.village_after_win) || ((stateObjs.village_after_repel || []).includes(o) && !!state.village_after_repel);
      }
    }
    if (key === 'torch_lit') for (const L of torchLights) L.enabled = on;
  }

  function update(dt, time) {
    if (wheel) wheel.rotation.z = -time * 0.9;
  }

  return { anchors, setState, getState: () => ({ ...state }), arena: houseYard, update, clueKeys: Object.keys(clueObjs) };
}
