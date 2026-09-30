// 고정 시점 카메라: yaw 고정(남→북), 구역·실내에 따라 pitch/거리/fov만 부드럽게 바뀐다
import * as THREE from 'three';
import { inBox } from './motion.js';

const DEFAULT = { pitch: 38, distance: 16, fov: 30, lookAhead: 1.2 };

export class CameraRig {
  constructor(camera, world) {
    this.camera = camera;
    this.world = world;
    this.cur = { ...DEFAULT };
    this.target = new THREE.Vector3();
    this.look = new THREE.Vector3();
    this.mode = 'zones'; // 'zones' | 'fixed'
    this.zoneName = null;
  }

  params(pos, interior) {
    if (this.mode === 'fixed') return DEFAULT;
    if (interior && interior.camera) return { ...DEFAULT, ...interior.camera, lookAhead: 0.3 };
    const zones = this.world.cameraZones || [];
    let zone = null;
    for (const z of zones) if (inBox(z, pos.x, pos.z)) zone = z; // 뒤쪽 우선
    this.zoneName = zone ? zone.name : null;
    return zone ? { ...DEFAULT, ...zone } : DEFAULT;
  }

  update(dt, pos, facing, interior, snap = false) {
    const p = this.params(pos, interior);
    const k = snap ? 1 : 1 - Math.exp(-dt * 2.2);
    for (const key of ['pitch', 'distance', 'fov', 'lookAhead']) {
      this.cur[key] += ((p[key] ?? DEFAULT[key]) - this.cur[key]) * k;
    }
    const ahead = { down: [0, 0.6], up: [0, -1], left: [-1, 0], right: [1, 0] }[facing] || [0, 0];
    const tx = pos.x + ahead[0] * this.cur.lookAhead;
    const tz = pos.z + ahead[1] * this.cur.lookAhead;
    const ty = pos.y + 0.9;
    const kf = snap ? 1 : 1 - Math.exp(-dt * 4);
    this.target.x += (tx - this.target.x) * kf;
    this.target.y += (ty - this.target.y) * kf;
    this.target.z += (tz - this.target.z) * kf;

    const pr = THREE.MathUtils.degToRad(this.cur.pitch);
    const d = this.cur.distance;
    this.camera.position.set(this.target.x, this.target.y + Math.sin(pr) * d, this.target.z + Math.cos(pr) * d);
    this.camera.lookAt(this.target);
    if (Math.abs(this.camera.fov - this.cur.fov) > 0.01) {
      this.camera.fov = this.cur.fov;
      this.camera.updateProjectionMatrix();
    }
  }
}
