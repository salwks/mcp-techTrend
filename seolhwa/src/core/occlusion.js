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
    this._dir = new THREE.Vector3();
    this._hits = new Set();
    this._list = [];
    this._frame = 0;
    // 정적인 가림 물체의 경계구를 한 번만 계산 (광선 검사 전 빠른 걸러내기)
    this.spheres = (world.occluders || []).map((o) => {
      o.updateWorldMatrix(true, true);
      const box = new THREE.Box3().setFromObject(o);
      const sph = new THREE.Sphere();
      box.getBoundingSphere(sph);
      return { o, sph };
    });
  }

  // 선분(a→b)과 구의 최단거리 판정
  _segHits(a, b, sph) {
    const abx = b.x - a.x, aby = b.y - a.y, abz = b.z - a.z;
    const len2 = abx * abx + aby * aby + abz * abz || 1e-6;
    let t = ((sph.center.x - a.x) * abx + (sph.center.y - a.y) * aby + (sph.center.z - a.z) * abz) / len2;
    t = Math.max(0, Math.min(1, t));
    const dx = a.x + abx * t - sph.center.x, dy = a.y + aby * t - sph.center.y, dz = a.z + abz * t - sph.center.z;
    return dx * dx + dy * dy + dz * dz <= sph.radius * sph.radius;
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

    // 광선 검사는 3프레임에 한 번(약 20Hz)만 — 반투명 전환은 매 프레임 부드럽게
    this._frame = (this._frame + 1) % 3;
    if (this._frame === 0) {
      for (const s of this.state.values()) s.target = 1;
      if (this.enabled && !interior) {
        const hits = this._hits;
        hits.clear();
        const cam = this.camera.position;
        this._tmp.set(playerPos.x, playerPos.y + playerHeight, playerPos.z);
        const list = this._list;
        list.length = 0;
        const foot = { x: playerPos.x, y: playerPos.y, z: playerPos.z };
        for (const e of this.spheres) {
          if (!e.o.visible) continue;
          if (this._segHits(cam, this._tmp, e.sph) || this._segHits(cam, foot, e.sph)) list.push(e.o);
        }
        if (list.length) {
          for (const h of [0.35, playerHeight * 0.6, playerHeight]) {
            this._tmp.set(playerPos.x, playerPos.y + h, playerPos.z);
            this._dir.copy(this._tmp).sub(cam);
            const dist = this._dir.length();
            this.ray.set(cam, this._dir.normalize());
            this.ray.far = dist - 0.4;
            for (const hit of this.ray.intersectObjects(list, true)) {
              const root = hit.object.userData.occRoot;
              if (root && root.visible) hits.add(root);
            }
          }
        }
        for (const r of hits) this._prepare(r).target = FADED;
      }
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
