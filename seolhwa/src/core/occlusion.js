// 가림 처리: 카메라와 플레이어 사이의 큰 물체를 반투명하게, 실내에 들어가면 지붕·앞벽 숨김
import * as THREE from 'three';

const FADED = 0.28;

export class Occlusion {
  constructor(camera, world) {
    this.camera = camera;
    this.world = world;
    this.enabled = true;
    this.ray = new THREE.Raycaster();
    this.state = new Map(); // root -> { alpha, target, mats:[{mat, opacity, transparent, depthWrite}] }
    this.hidden = new Set();
    (world.occluders || []).forEach((o) => { o.userData.occRoot = o; o.traverse((c) => { c.userData.occRoot = o; }); });
    this._tmp = new THREE.Vector3();
  }

  _prepare(root) {
    let s = this.state.get(root);
    if (s) return s;
    const mats = [];
    root.traverse((m) => {
      if (!m.isMesh || !m.material) return;
      const list = Array.isArray(m.material) ? m.material : [m.material];
      const cloned = list.map((mat) => {
        if (!mat.userData.occOwned) { mat = mat.clone(); mat.userData.occOwned = true; }
        mats.push({ mat, opacity: mat.opacity, transparent: mat.transparent, depthWrite: mat.depthWrite });
        return mat;
      });
      m.material = Array.isArray(m.material) ? cloned : cloned[0];
    });
    s = { alpha: 1, target: 1, mats };
    this.state.set(root, s);
    return s;
  }

  update(dt, playerPos, playerHeight, interior) {
    // 실내: hide 목록 숨김
    const want = new Set(interior ? interior.hide || [] : []);
    for (const o of this.hidden) if (!want.has(o)) { o.visible = true; this.hidden.delete(o); }
    for (const o of want) if (!this.hidden.has(o)) { o.visible = false; this.hidden.add(o); }

    for (const s of this.state.values()) s.target = 1;
    if (this.enabled && !interior) {
      const hits = new Set();
      const occ = this.world.occluders || [];
      for (const h of [0.35, playerHeight * 0.6, playerHeight]) {
        this._tmp.set(playerPos.x, playerPos.y + h, playerPos.z);
        const dir = this._tmp.clone().sub(this.camera.position);
        const dist = dir.length();
        this.ray.set(this.camera.position, dir.normalize());
        this.ray.far = dist - 0.4;
        for (const hit of this.ray.intersectObjects(occ, true)) {
          const root = hit.object.userData.occRoot;
          if (root && root.visible) hits.add(root);
        }
      }
      for (const r of hits) this._prepare(r).target = FADED;
    }
    const k = 1 - Math.exp(-dt * 8);
    for (const s of this.state.values()) {
      if (Math.abs(s.alpha - s.target) < 0.002) continue;
      s.alpha += (s.target - s.alpha) * k;
      if (Math.abs(s.alpha - s.target) < 0.01) s.alpha = s.target;
      const faded = s.alpha < 0.999;
      for (const e of s.mats) {
        e.mat.transparent = faded ? true : e.transparent;
        e.mat.opacity = e.opacity * s.alpha;
        e.mat.depthWrite = faded ? false : e.depthWrite;
        e.mat.needsUpdate = true;
      }
    }
  }
}
