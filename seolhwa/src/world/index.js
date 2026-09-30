// 설화록 — 월드(조선 산골 마을 디오라마). 계약: docs/CONTRACTS.md §2
import * as THREE from 'three';
import { Batch, rng, xf, paint, box, cyl, limb, lump, smoothstep, fbm } from './util.js';
import { makeMaterialFactory, inkMat, textures } from './materials.js';
import {
  PATH, BRANCH, ARENA, ARENA_TRAIL, PASS, HOUSE, BRIDGE, PADDIES, CHOGA, GIWA, JEONGJA, ZELKOVA, WELL, JANGDOK, SEONANG, WATER_Y, streamZ,
} from './layout.js';
import { GRID, buildHeights, makeHeightAt, buildTerrainMesh, buildStream, buildBackdrop, bridgeDeck, pathDist, inPaddy } from './terrain.js';
import {
  choga, chogaInterior, giwa, jeongja, bigTree, well, jangdok, haystack, jangseung, torchPost, stoneWall, fence, stoneBridge, cairn, curvedRoof,
} from './buildings.js';
import { pine, fir, bush, rock, reeds, riceTuft } from './vegetation.js';

export function buildWorld(scene) {
  const root = new THREE.Group();
  root.name = 'world';
  scene.add(root);

  const glowMats = [];
  const make = makeMaterialFactory(glowMats);
  const T = textures();
  const hg = buildHeights();
  const ground = hg.ground;
  const heightAt = makeHeightAt(ground);

  const colliders = [], occluders = [], lights = [], labels = [];
  const circle = (x, z, r) => colliders.push({ type: 'circle', x, z, r });
  const boxC = (minX, maxX, minZ, maxZ) => colliders.push({ type: 'box', minX, maxX, minZ, maxZ });

  // ---- 지형·물·원경 ----
  root.add(buildTerrainMesh(hg));
  const stream = buildStream(T.water);
  root.add(stream.mesh);
  root.add(buildBackdrop());

  // 정적 묶음(한 번에 병합)
  const stat = new Batch();
  const sharedInk = inkMat();
  const at = (x, y, z, ry = 0) => {
    const m = new THREE.Matrix4().makeRotationY(ry).setPosition(x, y, z);
    return (part, key, geo, outline = 0.03) => stat.add(key, geo.applyMatrix4(m), outline);
  };
  // 가림 물체: 자기 재질을 가진 그룹
  function occGroup(name, x, y, z, fn, { occ = true, ry = 0 } = {}) {
    const b = new Batch();
    fn((part, key, geo, outline = 0.03) => b.add(key, geo, outline));
    const g = b.build(make, inkMat(), { name });
    g.position.set(x, y, z);
    g.rotation.y = ry;
    root.add(g);
    if (occ) occluders.push(g);
    return g;
  }

  // ---- 초가집들 ----
  for (const c of CHOGA) {
    const y = ground(c.x, c.z);
    const rnd = rng(c.seed);
    occGroup('초가', c.x, y, c.z, (add) => choga(add, { w: c.w, d: c.d, rnd, hump: (rnd() - 0.5) * 0.3 }));
    boxC(c.x - c.w / 2 - 0.45, c.x + c.w / 2 + 0.45, c.z - c.d / 2 - 0.45, c.z + c.d / 2 + 0.75);
    circle(c.x + c.w / 2 + 0.55, c.z - c.d / 2 + 0.4, 0.4);
    lights.push({ x: c.x, y: y + 1.25, z: c.z + c.d / 2 + 0.2, kind: 'window' });
  }

  // ---- 기와집 + 돌담 + 대문 ----
  {
    const y = ground(GIWA.x, GIWA.z), rnd = rng(21);
    occGroup('기와집', GIWA.x, y, GIWA.z, (add) => giwa(add, { w: GIWA.w, d: GIWA.d, rnd }));
    boxC(GIWA.x - GIWA.w / 2 - 0.6, GIWA.x + GIWA.w / 2 + 0.6, GIWA.z - GIWA.d / 2 - 0.6, GIWA.z + GIWA.d / 2 + 1.45);
    lights.push({ x: GIWA.x - 1.8, y: y + 2.0, z: GIWA.z + GIWA.d / 2 + 0.2, kind: 'window' });
    lights.push({ x: GIWA.x + 1.8, y: y + 2.0, z: GIWA.z + GIWA.d / 2 + 0.2, kind: 'window' });
    const wz = -1.2;
    const walls = [[3.4, wz, 7.9, wz], [10.1, wz, 14.6, wz], [3.4, -10.2, 3.4, wz], [14.6, -10.2, 14.6, wz]];
    for (const [ax, az, bx, bz] of walls) {
      occGroup('돌담', 0, 0, 0, (add) => stoneWall(add, rng(Math.round(ax * 10 + az)), ax, az, bx, bz));
      boxC(Math.min(ax, bx) - 0.3, Math.max(ax, bx) + 0.3, Math.min(az, bz) - 0.3, Math.max(az, bz) + 0.3);
    }
    // 대문: 기둥 둘 + 작은 기와지붕 + 초롱
    occGroup('대문', GIWA.x, 0, wz, (add) => {
      for (const s of [-1, 1]) add('p', 'flat', paint(box(0.22, 2.3, 0.22, s * 1.0, 1.15, 0), '#6b5038', '#4d3826'), 0.02);
      add('p', 'flat', paint(box(2.3, 0.18, 0.26, 0, 2.3, 0), '#6b5038', '#4d3826'), 0.02);
      const r = curvedRoof({ hw: 1.75, hd: 0.95, eaveY: 2.5, rise: 0.75, lift: 0.28, k: 2.6, thick: 0.16, nx: 16, nz: 8 });
      add('p', 'tile', r, 0.035);
      add('p', 'flat', paint(box(r.userData.ridgeHalf * 2 + 0.3, 0.16, 0.22, 0, r.userData.ridgeY + 0.05, 0), '#3d3f42'), 0.02);
      for (const s of [-1, 1]) add('p', 'flat', paint(box(0.9, 1.9, 0.06, s * 0.5, 1.05, -0.35), '#5a4432', '#3f2f22'), 0.01);
      add('p', 'lamp', paint(cyl(0.15, 0.15, 0.3, 8, 1.3, 1.8, 0.25), '#c0443a'), 0.01);
    });
    lights.push({ x: GIWA.x + 1.3, y: 1.8, z: wz + 0.25, kind: 'lantern' });
  }

  // 마을 북쪽 돌담(개울 쪽)
  for (const [ax, az, bx, bz] of [[-26, -10.6, -14, -10.6], [-12.5, -10.6, -3.5, -10.6], [17, -10.2, 27, -10.2]]) {
    occGroup('돌담', 0, 0, 0, (add) => stoneWall(add, rng(Math.round(ax * 7)), ax, az, bx, bz, 1.15));
    boxC(Math.min(ax, bx) - 0.3, Math.max(ax, bx) + 0.3, az - 0.35, az + 0.35);
  }

  // ---- 정자 + 느티나무 ----
  {
    const y = ground(JEONGJA.x, JEONGJA.z), s = JEONGJA.s;
    let lamp;
    occGroup('정자', JEONGJA.x, y, JEONGJA.z, (add) => { lamp = jeongja(add, { s, rnd: rng(31) }).lamp; });
    boxC(JEONGJA.x - s / 2 - 0.3, JEONGJA.x + s / 2 + 0.3, JEONGJA.z - s / 2 - 0.3, JEONGJA.z + s / 2 + 0.75);
    lights.push({ x: JEONGJA.x + lamp.x, y: y + lamp.y, z: JEONGJA.z + lamp.z, kind: 'lantern' });
    occGroup('느티나무', ZELKOVA.x, ground(ZELKOVA.x, ZELKOVA.z), ZELKOVA.z, (add) => bigTree(add, rng(41), { h: 7.2, spread: 4.6, trunk: 0.55, branches: 5 }));
    circle(ZELKOVA.x, ZELKOVA.z, 0.75);
    // 나무 아래 평상
    const pa = at(ZELKOVA.x - 1.2, ground(ZELKOVA.x, ZELKOVA.z + 2), ZELKOVA.z + 2.2);
    pa('p', 'flat', paint(box(2.0, 0.08, 1.2, 0, 0.45, 0), '#9a7852', '#7a5c3e'), 0.02);
    for (const [dx, dz] of [[-0.9, -0.5], [0.9, -0.5], [-0.9, 0.5], [0.9, 0.5]]) pa('p', 'flat', paint(box(0.08, 0.45, 0.08, dx, 0.22, dz), '#6b5038'), 0.01);
    boxC(ZELKOVA.x - 2.3, ZELKOVA.x - 0.1, ZELKOVA.z + 1.5, ZELKOVA.z + 2.9);
  }

  // ---- 우물, 장독대 ----
  well(at(WELL.x, ground(WELL.x, WELL.z), WELL.z), rng(51));
  circle(WELL.x, WELL.z, 1.1);
  jangdok(at(JANGDOK.x, ground(JANGDOK.x, JANGDOK.z), JANGDOK.z), rng(52), JANGDOK.w, JANGDOK.d);
  boxC(JANGDOK.x - JANGDOK.w / 2, JANGDOK.x + JANGDOK.w / 2, JANGDOK.z - JANGDOK.d / 2, JANGDOK.z + JANGDOK.d / 2);

  // ---- 싸리 울타리 ----
  for (const [ax, az, bx, bz] of [[-21.5, 13.6, -18, 13.6], [-16, 13.6, -12.5, 13.6], [11.5, 13.6, 14, 13.6], [16, 13.6, 18.7, 13.6], [18.7, 13.6, 18.7, 6.5], [-21.5, 13.6, -21.5, 7]]) {
    fence(at(0, 0, 0), rng(Math.round(ax * 13 + az)), ax, az, bx, bz);
    boxC(Math.min(ax, bx) - 0.12, Math.max(ax, bx) + 0.12, Math.min(az, bz) - 0.12, Math.max(az, bz) + 0.12);
  }

  // ---- 마을 어귀: 장승, 횃불 ----
  for (const [x, f] of [[-2.4, false], [2.4, true]]) {
    jangseung(at(x, ground(x, 25), 25), rng(61 + x), f);
    circle(x, 25, 0.5);
  }
  for (const x of [-3.9, 3.9]) {
    const y = ground(x, 25.6);
    torchPost(at(x, y, 25.6), rng(71 + x));
    circle(x, 25.6, 0.3);
    lights.push({ x, y: y + 2.2, z: 25.6, kind: 'torch' });
  }

  // ---- 짚가리, 허수아비 ----
  for (const [x, z, s] of [[-12.5, 16, 1], [-22.3, 22, 0.9], [17, 26.5, 1.05], [-26.5, -5, 0.85]]) {
    haystack(at(x, ground(x, z), z, x), rng(81 + x), s);
    circle(x, z, 1.2 * s);
  }
  {
    const x = 29.5, z = 16.2, a = at(x, ground(x, z), z);
    a('p', 'flat', paint(cyl(0.04, 0.05, 1.9, 5, 0, 0.95, 0), '#6b5038'), 0.01);
    a('p', 'flat', paint(box(1.5, 0.06, 0.06, 0, 1.45, 0), '#6b5038'), 0.01);
    a('p', 'flat', paint(box(0.6, 0.7, 0.25, 0, 1.25, 0), '#8a8472', '#6e6858', 0.05), 0.015);
    a('p', 'thatch', paint(xf(new THREE.ConeGeometry(0.45, 0.35, 10), 0, 1.95, 0), '#cdb57a', '#9d8656'), 0.015);
    a('p', 'thatch', paint(xf(new THREE.SphereGeometry(0.17, 8, 6), 0, 1.72, 0), '#d8c48f'), 0.01);
  }

  // ---- 논: 물, 논둑, 벼 ----
  {
    const pos = [], idx = [];
    let n = 0;
    const rnd = rng(91);
    const ra = at(0, 0, 0);
    for (const p of PADDIES) {
      const y = p.h + 0.07, m = 0.3;
      pos.push(p.minX + m, y, p.minZ + m, p.maxX - m, y, p.minZ + m, p.minX + m, y, p.maxZ - m, p.maxX - m, y, p.maxZ - m);
      idx.push(n, n + 2, n + 1, n + 1, n + 2, n + 3);
      n += 4;
      const w = p.maxX - p.minX, d = p.maxZ - p.minZ, cx = (p.minX + p.maxX) / 2, cz = (p.minZ + p.maxZ) / 2;
      for (const [bw, bd, bx, bz] of [[w, 0.36, cx, p.minZ + 0.18], [w, 0.36, cx, p.maxZ - 0.18], [0.36, d, p.minX + 0.18, cz], [0.36, d, p.maxX - 0.18, cz]]) {
        ra('p', 'flat', paint(box(bw, 0.3, bd, bx, p.h + 0.08, bz), '#9ea266', '#7c7550', 0.05, rnd), 0);
      }
      for (let x = p.minX + 0.75; x < p.maxX - 0.5; x += 0.7) for (let z = p.minZ + 0.75; z < p.maxZ - 0.5; z += 0.75) {
        riceTuft(ra, rnd, x + (rnd() - 0.5) * 0.1, p.h, z + (rnd() - 0.5) * 0.1);
      }
      boxC(p.minX + 0.15, p.maxX - 0.15, p.minZ + 0.15, p.maxZ - 0.15);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setIndex(idx);
    g.computeVertexNormals();
    const wm = new THREE.Mesh(g, new THREE.MeshStandardMaterial({ color: 0x93aaa4, roughness: 0.15, metalness: 0.05, transparent: true, opacity: 0.8 }));
    wm.receiveShadow = true;
    wm.name = 'paddy-water';
    root.add(wm);
  }

  // ---- 돌다리 ----
  stoneBridge(at(BRIDGE.x, 0, 0), rng(101), BRIDGE.z0, BRIDGE.z1, BRIDGE.hw, bridgeDeck);
  for (const s of [-1, 1]) boxC(BRIDGE.x + s * BRIDGE.hw - 0.15, BRIDGE.x + s * BRIDGE.hw + 0.15, BRIDGE.z0 + 0.15, BRIDGE.z1 - 0.15);

  // ---- 외딴 초가(들어갈 수 있는 집) ----
  let interior;
  {
    const hx = HOUSE.x, hz = HOUSE.z, y = HOUSE.pad, rnd = rng(111);
    const parts = { base: new Batch(), body: new Batch(), front: new Batch(), roof: new Batch(), interior: new Batch() };
    const add = (part, key, geo, outline = 0.03) => parts[part].add(key, geo, outline);
    const info = choga(add, { w: HOUSE.w, d: HOUSE.d, rnd, open: true, hump: 0.1 });
    const inn = chogaInterior(add, HOUSE.w, HOUSE.d, info.F, rnd);
    const mk = (b, name) => { const g = b.build(make, inkMat(), { name }); g.position.set(hx, y, hz); root.add(g); return g; };
    const gRest = mk(parts.base, '외딴집-기단');
    const gBody = mk(parts.body, '외딴집-벽');
    const gFront = mk(parts.front, '외딴집-앞벽');
    const gRoof = mk(parts.roof, '외딴집-지붕');
    const gIn = mk(parts.interior, '외딴집-실내');
    void gRest; void gIn;
    occluders.push(gRoof, gFront, gBody);
    const W = HOUSE.w, D = HOUSE.d, t = 0.12;
    const x0 = hx - W / 2, x1 = hx + W / 2, z0 = hz - D / 2, z1 = hz + D / 2;
    boxC(x0 - 0.1, x1 + 0.1, z0 - 0.45, z0 + t);          // 뒷벽+기단
    boxC(x0 - 0.45, x0 + t, z0, z1);                       // 서벽
    boxC(x1 - t, x1 + 0.45, z0, z1);                       // 동벽
    boxC(x0 - 0.45, hx - 0.72, z1 - t, z1 + 0.75);         // 앞벽 왼쪽 + 툇마루
    boxC(hx + 0.72, x1 + 0.45, z1 - t, z1 + 0.75);         // 앞벽 오른쪽
    circle(x1 + 0.55, z0 + 0.4, 0.4);                      // 굴뚝
    for (const c of inn.colliders) {
      if (c.type === 'circle') colliders.push({ type: 'circle', x: hx + c.x, z: hz + c.z, r: c.r });
      else boxC(hx + c.minX, hx + c.maxX, hz + c.minZ, hz + c.maxZ);
    }
    lights.push({ x: hx + inn.lamp.x, y: y + inn.lamp.y, z: hz + inn.lamp.z, kind: 'lantern' });
    lights.push({ x: hx, y: y + 1.3, z: z1 + 0.3, kind: 'window' });
    interior = {
      name: '외딴 초가 안', minX: x0 + 0.1, maxX: x1 - 0.1, minZ: z0 + 0.1, maxZ: z1 - 0.05,
      hide: [gRoof, gFront], camera: { pitch: 50, distance: 9, fov: 30 },
    };
    // 집 곁 장작더미, 작은 장독
    const a = at(hx - W / 2 - 0.9, ground(hx - W / 2 - 0.9, hz + 0.5), hz + 0.5);
    for (let i = 0; i < 9; i++) a('p', 'flat', paint(xf(new THREE.CylinderGeometry(0.09, 0.09, 1.1, 6), 0, 0.12 + Math.floor(i / 3) * 0.17, -0.4 + (i % 3) * 0.2 + (Math.floor(i / 3) % 2) * 0.08, Math.PI / 2, 0, 0), '#9a7852', '#6b5038', 0.06, rnd), 0.01);
    circle(hx - W / 2 - 0.9, hz + 0.5, 0.7);
  }

  // ---- 서낭당(고갯마루) ----
  let ribbons;
  {
    const { cairn: C, tree: TR } = SEONANG;
    const cy = ground(C.x, C.z);
    const cinfo = cairn(at(C.x, cy, C.z), rng(121));
    circle(C.x, C.z, 1.4);
    boxC(C.x - 0.5, C.x + 0.5, C.z + 1.15, C.z + 1.75);
    lights.push({ x: C.x + cinfo.candle.x, y: cy + cinfo.candle.y, z: C.z + cinfo.candle.z, kind: 'shrine' });
    const ty = ground(TR.x, TR.z);
    const rnd = rng(131);
    occGroup('서낭나무', TR.x, ty, TR.z, (add) => {
      bigTree(add, rnd, { h: 6.2, spread: 3.6, trunk: 0.45, branches: 3, leaf: [['#7f8a58', '#4a5436'], ['#8a8e5c', '#525a3a']] });
      // 금줄 두른 줄기
      add('p', 'flat', paint(xf(new THREE.TorusGeometry(0.5, 0.05, 5, 14), 0, 1.3, 0, Math.PI / 2, 0, 0), '#cdb57a', '#a58d5c'), 0.01);
      // 천을 매단 낮은 가지
      add('p', 'flat', paint(limb(new THREE.Vector3(0, 2.2, 0), new THREE.Vector3(2.7, 2.7, 1.0), 0.14, 0.06, 6), '#6a5a48', '#4a3e32'), 0.02);
    });
    circle(TR.x, TR.z, 0.65);
    // 오색 천 리본(흔들림)
    const cols = ['#a8483a', '#3f5f7a', '#c9a34a', '#e8e2d2', '#3a3632', '#5f7a4a', '#b0584a', '#dcd4bc'].map((c) => new THREE.Color(c));
    const A = new THREE.Vector3(TR.x + 0.4, ty + 2.27, TR.z + 0.15), B = new THREE.Vector3(TR.x + 2.6, ty + 2.68, TR.z + 0.96);
    const rows = 7, list = [];
    const pos = [], col = [], idx = [];
    let v = 0;
    const r2 = rng(141);
    for (let i = 0; i < 14; i++) {
      const p = A.clone().lerp(B, (i + 0.5) / 14);
      const L = 0.9 + r2() * 0.8, w = 0.13 + r2() * 0.06, c = cols[i % cols.length];
      const ang = r2() * Math.PI;
      const dx = Math.cos(ang) * w / 2, dz = Math.sin(ang) * w / 2;
      for (let r = 0; r <= rows; r++) {
        const yy = p.y - 0.03 - (L * r) / rows;
        pos.push(p.x - dx, yy, p.z - dz, p.x + dx, yy, p.z + dz);
        col.push(c.r, c.g, c.b, c.r * 0.85, c.g * 0.85, c.b * 0.85);
        if (r < rows) { const a0 = v + r * 2; idx.push(a0, a0 + 2, a0 + 1, a0 + 1, a0 + 2, a0 + 3); }
      }
      list.push({ start: v, L, phase: r2() * 6.28, amp: 0.12 + r2() * 0.1 });
      v += (rows + 1) * 2;
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
    g.setIndex(idx);
    g.computeVertexNormals();
    const m = new THREE.Mesh(g, make('cloth'));
    m.castShadow = true;
    m.name = 'ribbons';
    m.frustumCulled = false;
    root.add(m);
    ribbons = { geo: g, base: Float32Array.from(pos), list, rows };
  }

  // ---- 나무·바위·덤불 배치 ----
  // 배경 묶음은 구역별로 나눠 절두체 컬링이 먹게 한다
  const bgChunks = new Map();
  const bgAt = (x, y, z, ry = 0) => {
    const mtx = new THREE.Matrix4().makeRotationY(ry).setPosition(x, y, z);
    const key = `${Math.floor((x + 60) / 40)}:${Math.floor((z + 90) / 22)}`;
    if (!bgChunks.has(key)) bgChunks.set(key, new Batch());
    const b = bgChunks.get(key);
    return (part, k, geo, outline = 0.03) => b.add(k, geo.applyMatrix4(mtx), outline);
  };
  const inBounds = (x, z) => x > -44 && x < 44 && z > -79 && z < 29;
  const hxr = { minX: HOUSE.x - 5.5, maxX: HOUSE.x + 5.5, minZ: HOUSE.z - 4.5, maxZ: HOUSE.z + 5.5 };
  const nearHouse = (x, z, m = 0) => x > hxr.minX - m && x < hxr.maxX + m && z > hxr.minZ - m && z < hxr.maxZ + m;
  // 걷는 곳 표본점(카메라 쪽 나무 솎기용): 산길·오솔길·외딴집·고갯마루
  const walkPts = [];
  for (const line of [PATH, BRANCH, ARENA_TRAIL]) for (let i = 0; i < line.length - 1; i++) {
    const [ax, az] = line[i], [bx, bz] = line[i + 1];
    const n = Math.ceil(Math.hypot(bx - ax, bz - az));
    for (let k = 0; k < n; k++) walkPts.push([ax + (bx - ax) * k / n, az + (bz - az) * k / n]);
  }
  walkPts.push([ARENA.x, ARENA.z], [ARENA.x - 6, ARENA.z + 2], [ARENA.x + 6, ARENA.z + 2], [HOUSE.x, HOUSE.z + 3], [HOUSE.x - 3, HOUSE.z + 3], [HOUSE.x + 3, HOUSE.z + 3], [PASS.x, PASS.z], [PASS.x - 4, PASS.z], [PASS.x + 4, PASS.z]);
  const camSide = (x, z) => walkPts.some(([wx, wz]) => z - wz > 0 && z - wz < 10 && Math.abs(x - wx) < 4.5);
  const trng = rng(2024);
  let treeCount = 0, occTrees = 0;
  const STEP = 3.3;
  for (let z = GRID.z0 + 2; z < GRID.z1 - 2; z += STEP) {
    for (let x = GRID.x0 + 2; x < GRID.x1 - 2; x += STEP) {
      const px = x + (trng() - 0.5) * STEP * 0.9, pz = z + (trng() - 0.5) * STEP * 0.9;
      const r = trng();
      const dzs = Math.abs(pz - streamZ(px));
      if (dzs < 5.2) continue;
      if (pathDist(px, pz) < 3.4) continue;
      if (inPaddy(px, pz, 1.2)) continue;
      if (nearHouse(px, pz)) continue;
      if (Math.hypot(px - ARENA.x, pz - ARENA.z) < ARENA.r + 2.5) continue;
      if (Math.hypot(px - PASS.x, pz - PASS.z) < 8.5) continue;
      if (Math.hypot(px - SEONANG.tree.x, pz - SEONANG.tree.z) < 3) continue;
      const village = pz > -13 && Math.abs(px) < 28;
      if (village || pz > 30.5 || Math.abs(px) > 55) continue;
      const dp = Math.hypot(px - PASS.x, pz - PASS.z);
      if (dp < 14 && pz > PASS.z - 5) continue;
      // 고개 너머 시야 틔우기
      if (pz < PASS.z - 3 && Math.abs(px - PASS.x) < 9 + (PASS.z - pz) * 0.5) continue;
      if (camSide(px, pz) && r > 0.15) continue;
      let p = 0.8;
      if (pz > -13) p = Math.abs(px) > 34 || pz > 30 ? 0.75 : 0.3;
      if (pz <= -13 && pz > -22) p = Math.abs(px) > 8 ? 0.45 : 0;
      if (pz < -84) p = 0.6;
      if (r > p) continue;
      const y = ground(px, pz);
      const inside = inBounds(px, pz);
      const near = inside && (pathDist(px, pz) < 9 || nearHouse(px, pz, 5) || (pz > -24 && pz < 31));
      const conifer = trng() < (pz < -40 ? 0.35 : 0.2);
      const s = 0.85 + trng() * 0.45;
      const seed = Math.floor(trng() * 1e9);
      if (near) {
        occGroup('소나무', px, y, pz, (add) => (conifer ? fir : pine)(add, rng(seed), s));
        occTrees++;
      } else {
        if ((Math.abs(px) > 46 || pz < -82) && trng() < 0.45) continue;
        (conifer ? fir : pine)(bgAt(px, y, pz, trng() * 6), rng(seed), s, 1);
      }
      if (inside) circle(px, pz, 0.35 * s);
      treeCount++;
    }
  }
  // 마을 가장자리 몇 그루(감나무 느낌의 활엽수)
  for (const [x, z, s] of [[-27, -11, 0.7], [27.5, -8, 0.75], [-14, 24, 0.6], [24, 3, 0.62], [-30, 25, 0.7]]) {
    occGroup('활엽수', x, ground(x, z), z, (add) => bigTree(add, rng(Math.round(x * z)), { h: 6 * s + 1.5, spread: 3.4 * s + 0.6, trunk: 0.32, branches: 3, leaf: [['#a8a468', '#6a6a3e'], ['#b59c5a', '#7a6a3e']] }));
    circle(x, z, 0.4);
  }

  // 바위: 산길 가장자리, 비탈, 개울가
  const rr = rng(777);
  for (let i = 0; i < 260; i++) {
    const px = -50 + rr() * 100, pz = -86 + rr() * 118;
    const pd = pathDist(px, pz), dzs = Math.abs(pz - streamZ(px));
    const slope = Math.abs(ground(px + 0.5, pz) - ground(px - 0.5, pz)) + Math.abs(ground(px, pz + 0.5) - ground(px, pz - 0.5));
    let s;
    if (dzs > 2.2 && dzs < 4.5 && Math.abs(px) > 2.5) s = 0.35 + rr() * 0.4;
    else if (pz < -21 && pd > 2.6 && pd < 6) s = 0.4 + rr() * 0.8;
    else if (pz < -21 && slope > 0.9 && pd > 3) s = 0.8 + rr() * 1.3;
    else continue;
    if (inPaddy(px, pz, 1) || nearHouse(px, pz) || Math.hypot(px - PASS.x, pz - PASS.z) < 5.6 || Math.hypot(px - ARENA.x, pz - ARENA.z) < ARENA.r + 1) continue;
    if (pz > -13 && Math.abs(px) < 28) continue;
    if (Math.abs(px) < 3 && pz > -22 && pz < -10) continue;
    const y = ground(px, pz);
    rock(bgAt(px, y - s * 0.15, pz), rr, s);
    if (inBounds(px, pz) && s > 0.45) circle(px, pz, s * 0.85);
  }
  // 고갯마루 주변 큰 바위 몇 개(무대 장식)
  for (const [x, z, s] of [[14.5, -67, 1.3], [0.5, -67.5, 1.0], [13, -74.5, 1.6], [-2, -71, 1.4]]) {
    rock(bgAt(x, ground(x, z) - 0.2, z), rng(Math.round(x * 31 - z)), s, false);
    circle(x, z, s * 0.9);
  }
  // 덤불·갈대: 개울가, 담 밑, 산길 가
  const br = rng(333);
  for (let i = 0; i < 160; i++) {
    const px = -44 + br() * 88, pz = -78 + br() * 106;
    const dzs = Math.abs(pz - streamZ(px));
    const pd = pathDist(px, pz);
    const y = ground(px, pz);
    if (dzs > 2.0 && dzs < 3.6 && Math.abs(px) > 3) { reeds(bgAt(px, y, pz), br, 6); continue; }
    if (inPaddy(px, pz, 1) || nearHouse(px, pz)) continue;
    if (pz > -13 && Math.abs(px) < 27 && !(Math.abs(pz + 10.5) < 1.2)) continue;
    if (pd < 2.4 || Math.hypot(px - PASS.x, pz - PASS.z) < 5.5 || Math.hypot(px - ARENA.x, pz - ARENA.z) < ARENA.r + 0.5) continue;
    if (Math.abs(px) < 3 && pz > -22 && pz < -10) continue;
    bush(bgAt(px, y, pz), br, 0.8 + br() * 0.5);
  }
  // 풀포기(먹선 없음, 값싼 삼각뿔 셋)
  const gr = rng(555);
  for (let i = 0; i < 750; i++) {
    const px = -46 + gr() * 92, pz = -84 + gr() * 116;
    if (inPaddy(px, pz, 0.6) || nearHouse(px, pz, -1.5)) continue;
    if (Math.abs(pz - streamZ(px)) < 2.6) continue;
    if (pathDist(px, pz) < 1.3) continue;
    if (pz > -13 && pz < 30 && Math.abs(px) < 27 && gr() < 0.55) continue;
    const y = ground(px, pz), a = bgAt(px, y, pz, gr() * 6);
    const tone = gr() < 0.5 ? ['#a9ad6c', '#6d7a44'] : ['#bfb27a', '#7f7a4a'];
    for (let k = 0; k < 2; k++) {
      const h = 0.25 + gr() * 0.3;
      const g = new THREE.ConeGeometry(0.06, h, 3, 1, true);
      xf(g, (gr() - 0.5) * 0.3, h / 2, (gr() - 0.5) * 0.2, (gr() - 0.5) * 0.6, 0, (gr() - 0.5) * 0.6);
      a('p', 'flat', paint(g, tone[0], tone[1], 0.05, gr), 0);
    }
  }
  // 산길 가장자리 덤불 더
  for (let i = 0; i < 90; i++) {
    const w = walkPts[Math.floor(br() * walkPts.length)];
    const ang = br() * Math.PI * 2, rad = 2.6 + br() * 3.5;
    const px = w[0] + Math.cos(ang) * rad, pz = w[1] + Math.sin(ang) * rad;
    if (pathDist(px, pz) < 2.4 || nearHouse(px, pz) || Math.hypot(px - PASS.x, pz - PASS.z) < 5.5 || Math.hypot(px - ARENA.x, pz - ARENA.z) < ARENA.r + 0.5) continue;
    bush(bgAt(px, ground(px, pz), pz), br, 0.6 + br() * 0.5);
  }
  // 마을 안 소소한 덤불(담 밑, 집 곁)
  for (const [x, z] of [[-4, -9.6], [-25, -9.8], [19, -9.3], [-11, 12.4], [12, 12.4], [4.5, -3], [-24, 12], [22, 5]]) bush(at(x, ground(x, z), z), rng(Math.round(x * 17 + z)), 0.8);

  // ---- 호랑이의 영역(숲속 빈터) ----
  let arena;
  {
    const A = ARENA, ar = rng(4242);
    const rimTree = (ang, rad, kind, claw) => {
      const x = A.x + Math.cos(ang) * rad, z = A.z + Math.sin(ang) * rad, y = ground(x, z);
      occGroup(claw ? '발톱자국 나무' : '빈터 소나무', x, y, z, (add) => {
        if (kind === 'fir') fir(add, rng(Math.floor(ar() * 1e9)), 1.1);
        else pine(add, rng(Math.floor(ar() * 1e9)), 1.15);
        if (claw) {
          // 줄기에 할퀸 자국 세 줄(껍질이 벗겨진 밝은 속살 + 먹빛 테)
          const face = Math.atan2(A.z - z, A.x - x);
          for (let i = 0; i < 3; i++) {
            const g = new THREE.BoxGeometry(0.05, 0.85, 0.04);
            xf(g, 0, 1.55 + i * 0.05, 0, 0, 0, 0.35);
            g.translate((i - 1) * 0.1, 0, 0.2);
            g.rotateY(Math.PI / 2 - face);
            add('p', 'flat', paint(g, '#e2cfa4', '#c9b27f'), 0.012);
          }
        }
      });
      circle(x, z, 0.4);
    };
    // 가장자리 나무(남쪽 한 그루는 가림 검증용)
    const trees = [[-2.6, 11.2, 'pine'], [-1.9, 11.8, 'fir'], [-1.2, 11.0, 'pine', true], [-0.4, 12.0, 'fir'], [0.35, 11.4, 'pine'], [1.05, 11.8, 'pine'], [1.6, 10.8, 'pine'], [2.35, 11.6, 'fir']];
    for (const [a, rad, kind, claw] of trees) rimTree(a, rad, kind, claw);
    // 엄폐용 바위(가장자리 안쪽)
    for (const [a, rad, sz] of [[-2.2, 7.8, 1.3], [-0.5, 8.4, 1.1], [0.8, 7.9, 1.5], [2.0, 8.3, 1.0], [-2.9, 9.0, 0.9]]) {
      const x = A.x + Math.cos(a) * rad, z = A.z + Math.sin(a) * rad;
      rock(at(x, ground(x, z) - 0.2, z), rng(Math.floor(ar() * 1e9)), sz, false);
      circle(x, z, sz * 0.85);
    }
    // 뼈와 흩어진 짚
    for (let i = 0; i < 9; i++) {
      const a = ar() * 6.28, rad = 2 + ar() * 7, x = A.x + Math.cos(a) * rad, z = A.z + Math.sin(a) * rad;
      const put = at(x, ground(x, z), z, ar() * 6.28);
      if (i < 5) {
        put('p', 'flat', paint(xf(new THREE.CylinderGeometry(0.035, 0.03, 0.45 + ar() * 0.3, 5), 0, 0.04, 0, 0, 0, Math.PI / 2), '#e8e0cc', '#cfc5ad'), 0.008);
        put('p', 'flat', paint(xf(new THREE.SphereGeometry(0.06, 5, 3), 0.22, 0.05, 0), '#e8e0cc'), 0);
        put('p', 'flat', paint(xf(new THREE.SphereGeometry(0.06, 5, 3), -0.22, 0.05, 0), '#e8e0cc'), 0);
        if (i === 0) put('p', 'flat', paint(xf(new THREE.SphereGeometry(0.16, 7, 5), 0.5, 0.1, 0.3, 0, 0, 0, 1, 0.8, 1.25), '#ece4d0', '#c8bea6'), 0.01);
      } else {
        for (let k = 0; k < 6; k++) {
          const g = new THREE.CylinderGeometry(0.012, 0.012, 0.5 + ar() * 0.4, 3);
          xf(g, (ar() - 0.5) * 0.8, 0.03, (ar() - 0.5) * 0.8, Math.PI / 2, ar() * 6, 0);
          put('p', 'flat', paint(g, '#d6c17e', '#b39d62'), 0);
        }
      }
    }
    // 밤 가독성: 버려진 포수의 초롱(남서) + 꺼져 가는 횃불(북동)
    {
      const x = A.x + Math.cos(2.5) * 10.3, z = A.z + Math.sin(2.5) * 10.3, y = ground(x, z);
      const put = at(x, y, z, 0.3);
      put('p', 'flat', paint(cyl(0.06, 0.08, 2.3, 6, 0, 1.1, 0, 0, 0, 0.08), '#6b5038', '#4d3826'), 0.012);
      put('p', 'flat', paint(box(0.9, 0.07, 0.07, 0.4, 2.15, 0), '#6b5038'), 0.01);
      put('p', 'flat', paint(cyl(0.008, 0.008, 0.3, 3, 0.75, 1.98, 0), '#2d2520'), 0);
      put('p', 'lamp', paint(cyl(0.14, 0.12, 0.3, 8, 0.75, 1.7, 0), '#d8c49a', '#c9a86a'), 0.012);
      put('p', 'flat', paint(cyl(0.1, 0.1, 0.04, 8, 0.75, 1.87, 0), '#2d2520'), 0.006);
      put('p', 'glow', paint(xf(new THREE.ConeGeometry(0.04, 0.1, 6), 0.75, 1.68, 0), '#ffd27a', '#ff9a3a'), 0);
      for (let i = 0; i < 4; i++) put('p', 'flat', paint(xf(lump(0.16, 0, ar, 0.3, 0.6), Math.cos(i * 1.6) * 0.25, 0.05, Math.sin(i * 1.6) * 0.25), '#a19b8f', '#77726a'), 0.01);
      circle(x, z, 0.3);
      const c = Math.cos(0.3), sn = Math.sin(0.3);
      lights.push({ x: x + 0.75 * c, y: y + 1.72, z: z - 0.75 * sn, kind: 'lantern' });
    }
    {
      const x = A.x + Math.cos(-0.8) * 10.2, z = A.z + Math.sin(-0.8) * 10.2, y = ground(x, z);
      torchPost(at(x, y - 0.35, z, 0.5), ar);
      circle(x, z, 0.3);
      lights.push({ x, y: y + 1.8, z, kind: 'torch' });
    }
    const ent = ARENA_TRAIL[ARENA_TRAIL.length - 1];
    arena = {
      name: '호랑이의 영역', x: A.x, z: A.z, radius: A.r,
      playerStart: { x: ent[0] + 0.3, z: ent[1] - 0.6 }, tigerStart: { x: A.x + 6.5, z: A.z - 2.8 },
      camera: { pitch: 48, distance: 26, fov: 30 },
    };
    labels.push({ x: A.x, y: A.h + 3, z: A.z, text: '호랑이의 영역' });
  }

  // 정적 묶음 올리기
  const statG = stat.build(make, sharedInk, { name: '마을 소품' });
  root.add(statG);
  const bgInk = inkMat();
  for (const b of bgChunks.values()) root.add(b.build(make, bgInk, { name: '숲' }));

  // ---- 가파른 비탈·물 충돌(격자 → 상자 병합) ----
  {
    const S = 1.0, x0 = -44, x1 = 44, z0 = -79, z1 = 29;
    const nx = Math.round((x1 - x0) / S), nz = Math.round((z1 - z0) / S);
    const blockedCell = (i, j) => {
      const cx = x0 + (i + 0.5) * S, cz = z0 + (j + 0.5) * S;
      if (Math.abs(cx - BRIDGE.x) < BRIDGE.hw + 0.2 && cz > BRIDGE.z0 - 0.5 && cz < BRIDGE.z1 + 0.5) return false;
      if (nearHouse(cx, cz, -1)) return false;
      const h = ground(cx, cz);
      if (h < WATER_Y + 0.12) return true; // 물
      if (pathDist(cx, cz) < 2.3 || Math.hypot(cx - PASS.x, cz - PASS.z) < PASS.r + 1) return false;
      let mx = 0;
      for (const [ax, az] of [[0.5, 0], [0, 0.5], [0.35, 0.35], [0.35, -0.35]]) {
        mx = Math.max(mx, Math.abs(ground(cx + ax, cz + az) - ground(cx - ax, cz - az)) / (2 * Math.hypot(ax, az)));
      }
      return mx > 1.0;
    };
    let runsPrev = new Map();
    const done = [];
    for (let j = 0; j < nz; j++) {
      const runs = new Map();
      let i = 0;
      while (i < nx) {
        if (!blockedCell(i, j)) { i++; continue; }
        let k = i;
        while (k < nx && blockedCell(k, j)) k++;
        const key = `${i}:${k}`;
        const prev = runsPrev.get(key);
        if (prev) { prev.maxZ = z0 + (j + 1) * S; runs.set(key, prev); }
        else { const b = { type: 'box', minX: x0 + i * S, maxX: x0 + k * S, minZ: z0 + j * S, maxZ: z0 + (j + 1) * S }; runs.set(key, b); done.push(b); }
        i = k;
      }
      runsPrev = runs;
    }
    // 조금 안쪽으로 줄여 가장자리에서 걸리지 않게
    for (const b of done) { b.minX += 0.1; b.maxX -= 0.1; b.minZ += 0.1; b.maxZ -= 0.1; colliders.push(b); }
  }
  // 월드 경계
  boxC(-200, -44, -300, 300); boxC(44, 200, -300, 300); boxC(-200, 200, -300, -79); boxC(-200, 200, 29, 300);

  // ---- NPC ----
  const npcs = [
    { id: 'elder_choi', kind: 'elder', x: 5.0, z: 18.7, facing: 'down', wander: false, name: '최 영감',
      lines: ['고갯마루 서낭당에 돌 하나 얹고 가게. 요즘은 그냥 지나가면 탈이 난다네.', '밤중에 산에서 누가 이름을 부르거든, 절대 대답하지 말게.', '내 젊을 적에도 이런 가을이 한 번 있었지…'] },
    { id: 'sundeok_mom', kind: 'villager_f', x: -3.3, z: 9.4, facing: 'left', wander: 1.2, name: '순덕 어멈',
      lines: ['건넛마을 떡장수 아낙이 장에 간다더니 사흘째 소식이 없대요.', '요 며칠 우물물에서 비린내가 나요. 별일이지.'] },
    { id: 'kim_seobang', kind: 'villager_m', x: 9.0, z: 0.4, facing: 'down', wander: false, name: '김 서방',
      lines: ['대감마님이 해 떨어지면 고갯길을 막으라 하셨소.', '어젯밤 윗집 소가 외양간에서 감쪽같이 사라졌지 뭐요.'] },
    { id: 'hunter_makswe', kind: 'hunter', x: -2.3, z: -9.7, facing: 'up', wander: 1.5, name: '포수 막쇠',
      lines: ['산짐승 발자국이 개울가까지 내려왔더군. 내 손바닥보다 커.', '고개에선 뒤에서 누가 불러도 돌아보지 마시오.', '총알이 몇 발 안 남았는데, 장에 간 놈은 아직이오.'] },
    { id: 'kkeutsun', kind: 'villager_f', x: -15.0, z: -3.7, facing: 'down', wander: 0.8, name: '끝순이',
      lines: ['장독 뚜껑이 밤마다 열려 있어요. 누가 들여다보는 것처럼.', '숲가 외딴집 아이들 어미가 아직도 안 돌아왔다지 뭐예요.'] },
    { id: 'hwang_seobang', kind: 'villager_m', x: 17.6, z: 16.6, facing: 'right', wander: 1.0, name: '황 서방',
      lines: ['올해 벼는 잘 여물었는데, 허수아비가 자꾸 산 쪽을 보고 서 있어.', '해 질 녘 논두렁에 모르는 여인네가 서 있더라고. 부르니까 없어졌어.'] },
    { id: 'gaettong', kind: 'child_boy', x: 4.3, z: 22.4, facing: 'down', wander: 2.0, name: '개똥이',
      lines: ['장승 할아버지 눈이 밤에 움직인대!', '형들이 그러는데 고개에 엄청 큰 고양이가 산대. 진짜 커!'] },
    { id: 'dori', kind: 'child_boy', x: -19.7, z: -27.6, facing: 'down', wander: false, name: '돌이',
      lines: ['어머니가 고개 너머 잔칫집에 일하러 가셨어요. 해 지기 전엔 오신댔는데…', '밤에 누가 문을 두드려도 열어 주지 말랬어요.'] },
    { id: 'suni', kind: 'child_girl', x: -24.3, z: -27.8, facing: 'right', wander: false, name: '순이',
      lines: ['어젯밤 문밖에서 어머니 목소리가 났는데… 목소리가 좀 이상했어요.', '오빠가 문고리를 꼭 잡고 있으래요.'] },
    { id: 'tiger', kind: 'tiger', x: 11.2, z: -70.6, facing: 'left', wander: 0, name: '???', lines: [] },
  ];

  // ---- 카메라 구역(뒤쪽 우선) ----
  const cameraZones = [
    { name: '느티나무 마을', minX: -45, maxX: 45, minZ: -13, maxZ: 30, pitch: 40, distance: 22, fov: 30 },
    { name: '개울 돌다리', minX: -12, maxX: 12, minZ: -22, maxZ: -11, pitch: 42, distance: 19 },
    { name: '솔숲 산길', minX: -35, maxX: 45, minZ: -63, maxZ: -22, pitch: 48, distance: 20 },
    { name: '숲가 외딴 초가', minX: -30, maxX: -14, minZ: -38, maxZ: -24, pitch: 44, distance: 14 },
    { name: '호랑이의 영역', minX: ARENA.x - ARENA.r - 2, maxX: Math.min(44, ARENA.x + ARENA.r + 2), minZ: ARENA.z - ARENA.r - 2, maxZ: ARENA.z + ARENA.r + 2, pitch: 48, distance: 26, fov: 30 },
    { name: '고갯마루 서낭당', minX: -8, maxX: 24, minZ: -80, maxZ: -63, pitch: 27, distance: 22, fov: 34 },
  ];

  labels.push(
    { x: 0, y: 3, z: 6, text: '느티나무 마을' }, { x: 0, y: 2, z: -16, text: '돌다리' },
    { x: 7, y: 5, z: -32, text: '솔숲 산길' }, { x: PASS.x, y: PASS.h + 3, z: PASS.z, text: '고갯마루 서낭당' },
    { x: HOUSE.x, y: HOUSE.pad + 4, z: HOUSE.z, text: '외딴 초가' },
  );

  // ---- 애니메이션 ----
  const tmp = ribbons.geo.attributes.position;
  function update(dt, time) {
    stream.tex.offset.x = -time * 0.045;
    stream.tex.offset.y = Math.sin(time * 0.6) * 0.01;
    const B = ribbons.base, P = tmp.array;
    const gust = 0.6 + 0.4 * Math.sin(time * 0.37) * Math.sin(time * 0.91 + 1);
    for (const rb of ribbons.list) {
      for (let r = 1; r <= ribbons.rows; r++) {
        const f = r / ribbons.rows;
        const sw = rb.amp * gust * f * f;
        const ox = Math.sin(time * 2.1 + rb.phase + f * 2.2) * sw;
        const oz = Math.cos(time * 1.7 + rb.phase * 1.3 + f * 1.8) * sw * 0.7 + sw * 0.6;
        for (let s = 0; s < 2; s++) {
          const vi = (rb.start + r * 2 + s) * 3;
          P[vi] = B[vi] + ox;
          P[vi + 1] = B[vi + 1] + Math.abs(ox) * 0.25 * f;
          P[vi + 2] = B[vi + 2] + oz;
        }
      }
    }
    tmp.needsUpdate = true;
  }
  // 밤 정도(0~1)에 따라 창호지·초롱을 밝힌다(fx에서 호출하면 좋음)
  function setNight(k) {
    for (const m of glowMats) m.emissiveIntensity = k * (m.map ? 0.9 : 1.4);
  }

  const world = {
    heightAt, colliders, spawn: { x: 0, z: 6 }, npcs, cameraZones, interiors: [interior], arenas: [arena], occluders, lights, labels, update,
    setNight, glowMaterials: glowMats, root,
    stats: { trees: treeCount, occTrees },
  };
  return world;
}
