// 화살·떡 메시 (먹선 느낌의 단순한 모양). 지오메트리·머티리얼은 공유하고, 메시만 만들고 버린다.
import * as THREE from 'three';

let shared = null;
function res() {
  if (shared) return shared;
  const ink = new THREE.MeshBasicMaterial({ color: '#221c17' });
  const inkBack = new THREE.MeshBasicMaterial({ color: '#1a1511', side: THREE.BackSide });
  const shaft = new THREE.MeshLambertMaterial({ color: '#7a5a3a' });
  const feather = new THREE.MeshLambertMaterial({ color: '#a8432f', side: THREE.DoubleSide });
  const rice = new THREE.MeshLambertMaterial({ color: '#f1eadb' });
  const ricePink = new THREE.MeshLambertMaterial({ color: '#d99a92' });
  const riceGreen = new THREE.MeshLambertMaterial({ color: '#9cae7c' });
  // 화살: +z 방향이 촉
  const shaftGeo = new THREE.CylinderGeometry(0.012, 0.012, 0.78, 5).rotateX(Math.PI / 2);
  const headGeo = new THREE.ConeGeometry(0.03, 0.1, 5).rotateX(Math.PI / 2).translate(0, 0, 0.43);
  const fletchGeo = new THREE.PlaneGeometry(0.035, 0.14).translate(0, 0, -0.3);
  const lineGeo = new THREE.CylinderGeometry(0.02, 0.02, 0.8, 5).rotateX(Math.PI / 2); // 먹선 외곽(뒷면)
  // 떡: 납작한 원판 세 겹
  const cakeGeo = new THREE.CylinderGeometry(0.1, 0.105, 0.05, 12);
  const cakeLine = new THREE.CylinderGeometry(0.118, 0.123, 0.07, 12);
  shared = { ink, inkBack, shaft, feather, rice, ricePink, riceGreen, shaftGeo, headGeo, fletchGeo, lineGeo, cakeGeo, cakeLine };
  return shared;
}

export function makeArrowMesh() {
  const r = res();
  const g = new THREE.Group();
  g.name = 'combat:arrow';
  const outline = new THREE.Mesh(r.lineGeo, r.inkBack);
  const shaft = new THREE.Mesh(r.shaftGeo, r.shaft);
  const head = new THREE.Mesh(r.headGeo, r.ink);
  const f1 = new THREE.Mesh(r.fletchGeo, r.feather);
  const f2 = new THREE.Mesh(r.fletchGeo, r.feather);
  f1.rotation.z = 0; f2.rotation.z = Math.PI / 2;
  g.add(outline, shaft, head, f1, f2);
  g.traverse((o) => { if (o.isMesh) o.castShadow = true; });
  return g;
}

export function makeBaitMesh() {
  const r = res();
  const g = new THREE.Group();
  g.name = 'combat:bait';
  const mats = [r.riceGreen, r.rice, r.ricePink];
  for (let i = 0; i < 3; i++) {
    const m = new THREE.Mesh(r.cakeGeo, mats[i]);
    m.position.set((i - 1) * 0.015, 0.03 + i * 0.05, (i % 2) * 0.01);
    m.castShadow = true;
    const o = new THREE.Mesh(r.cakeLine, r.inkBack);
    o.position.copy(m.position);
    g.add(o, m);
  }
  return g;
}
