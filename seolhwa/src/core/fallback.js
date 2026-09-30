// 다른 담당 모듈이 아직 없거나 오류가 날 때 쓰는 최소 대체물 (개발용)
import * as THREE from 'three';

export function fallbackWorld(scene) {
  const g = new THREE.Mesh(new THREE.PlaneGeometry(90, 110), new THREE.MeshLambertMaterial({ color: 0x8a9a6a }));
  g.rotation.x = -Math.PI / 2;
  g.position.z = -25;
  g.receiveShadow = true;
  scene.add(g);
  const box = new THREE.Mesh(new THREE.BoxGeometry(4, 3, 4), new THREE.MeshLambertMaterial({ color: 0x9c8664 }));
  box.position.set(6, 1.5, -4);
  box.castShadow = box.receiveShadow = true;
  scene.add(box);
  return {
    heightAt: () => 0,
    colliders: [{ type: 'box', minX: 4, maxX: 8, minZ: -6, maxZ: -2 }],
    spawn: { x: 0, z: 4 },
    npcs: [{ id: 'n1', kind: 'villager_m', x: 3, z: 2, facing: 'left', wander: 2, name: '마을 사람', lines: ['(임시 월드입니다)'] }],
    cameraZones: [],
    interiors: [],
    occluders: [box],
    lights: [{ x: 6, y: 2, z: -1.8, kind: 'lantern' }],
  };
}

export function fallbackCharacter(kind) {
  const h = kind === 'tiger' ? 1.1 : kind.startsWith('child') ? 1.1 : 1.65;
  const w = kind === 'tiger' ? 2.6 : 0.7;
  const group = new THREE.Group();
  const mat = new THREE.MeshLambertMaterial({ color: kind === 'player' ? 0xf1ead8 : kind === 'tiger' ? 0xd08a3a : 0x7a8ca0, side: THREE.DoubleSide });
  const plane = new THREE.Mesh(new THREE.PlaneGeometry(w, h), mat);
  plane.position.y = h / 2;
  plane.castShadow = true;
  group.add(plane);
  return {
    object3d: group, height: h, radius: kind === 'tiger' ? 0.8 : 0.3,
    setFacing() {}, setAnim() {}, setMode() {}, setSilhouette() {},
    update(dt, camera) { plane.quaternion.copy(camera.quaternion); },
  };
}

export function fallbackFX({ renderer, scene, camera }) {
  renderer.shadowMap.enabled = true;
  scene.background = new THREE.Color(0xc9d6dc);
  const sun = new THREE.DirectionalLight(0xffffff, 2.2);
  sun.position.set(-10, 20, 12);
  sun.castShadow = true;
  scene.add(sun, sun.target, new THREE.HemisphereLight(0xdfe8f0, 0x5a5040, 1.2));
  let t = 12;
  return {
    update(dt, focus) { sun.target.position.copy(focus); sun.position.set(focus.x - 10, focus.y + 20, focus.z + 12); },
    render() { renderer.render(scene, camera); },
    resize(w, h) { renderer.setPixelRatio(Math.min(devicePixelRatio, 2)); renderer.setSize(w, h, false); },
    setTime(v) { t = v; }, getTime() { return t; },
    setOption() {}, getOptions() { return {}; },
  };
}
