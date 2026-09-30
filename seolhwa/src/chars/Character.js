// 설화록 — 2D 컷아웃 캐릭터를 3D 공간에 세우는 판(billboard)
// - 부위 이미지를 매 틱(약 12fps) 캔버스 한 장에 합성 → CanvasTexture
// - 조명 반응(Lambert + alphaTest), 발밑 블롭 그림자, 해를 향한 그림자 투사판, 가림 실루엣
import * as THREE from 'three';
import { getRig } from './rigs.js';
import { makeCanvas } from './painter.js';

const FPS = 12;
const LEAN = THREE.MathUtils.degToRad(8); // 카메라 쪽으로 살짝 뒤로 젖힘(단축 보정)
const SIL_COLOR = new THREE.Color('#1b2130');

// ---- 공유 자원 ----
let _blobTex = null;
function blobTexture() {
  if (_blobTex) return _blobTex;
  const c = makeCanvas(64, 64), g = c.getContext('2d');
  const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32);
  gr.addColorStop(0, 'rgba(255,255,255,1)');
  gr.addColorStop(0.45, 'rgba(255,255,255,0.8)');
  gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr;
  g.fillRect(0, 0, 64, 64);
  _blobTex = new THREE.CanvasTexture(c);
  return _blobTex;
}
let _blobGeo = null;
const blobGeometry = () => _blobGeo || (_blobGeo = new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2));

// 해(그림자 방향광) 찾기: 장면별로 1초에 한 번만 순회
const _sunCache = new WeakMap();
function findSun(scene, now) {
  let e = _sunCache.get(scene);
  if (e && now - e.t < 1000) return e.light;
  let best = null;
  scene.traverseVisible((o) => {
    if (o.isDirectionalLight && o.castShadow && (!best || o.intensity > best.intensity)) best = o;
  });
  _sunCache.set(scene, { t: now, light: best });
  return best;
}

// 실루엣: 맵의 알파만 쓰고 색은 먹색 평면
function makeSilhouetteMaterial(map) {
  const m = new THREE.MeshBasicMaterial({
    color: SIL_COLOR, map, transparent: true, opacity: 0.42, alphaTest: 0.2,
    depthWrite: false, depthFunc: THREE.GreaterDepth, side: THREE.DoubleSide, fog: false, toneMapped: false,
  });
  m.onBeforeCompile = (sh) => {
    sh.fragmentShader = sh.fragmentShader.replace('#include <map_fragment>', '#include <map_fragment>\n\tdiffuseColor.rgb = diffuse;');
  };
  m.customProgramCacheKey = () => 'seolhwa-silhouette';
  return m;
}

const _v = new THREE.Vector3(), _v2 = new THREE.Vector3(), _sph = new THREE.Sphere(), _fr = new THREE.Frustum(), _pm = new THREE.Matrix4();

// 2D 아핀 행렬 [a,b,c,d,e,f]
function mul(m, n, out) {
  const a = m[0] * n[0] + m[2] * n[1], b = m[1] * n[0] + m[3] * n[1];
  const c = m[0] * n[2] + m[2] * n[3], d = m[1] * n[2] + m[3] * n[3];
  const e = m[0] * n[4] + m[2] * n[5] + m[4], f = m[1] * n[4] + m[3] * n[5] + m[5];
  out[0] = a; out[1] = b; out[2] = c; out[3] = d; out[4] = e; out[5] = f;
  return out;
}
function trs(x, y, r, sx, sy, out) {
  const c = Math.cos(r), s = Math.sin(r);
  out[0] = c * sx; out[1] = s * sx; out[2] = -s * sy; out[3] = c * sy; out[4] = x; out[5] = y;
  return out;
}
const ID = [1, 0, 0, 1, 0, 0];
const _loc = [0, 0, 0, 0, 0, 0], _fin = [0, 0, 0, 0, 0, 0];

export class Character {
  constructor(kind) {
    const rig = getRig(kind);
    this.kind = kind;
    this.rig = rig;
    this.height = rig.height;
    this.radius = rig.radius;
    this.facing = 'down';
    this.anim = 'idle';
    this.mode = '4dir';
    this.t = Math.random() * 10; // 인스턴스마다 위상 다르게
    this._acc = 0;
    this._dirty = true;
    this._drawnOnce = false;
    this._mats = {};

    // 캔버스 텍스처
    this.canvas = makeCanvas(rig.W, rig.H);
    this.ctx = this.canvas.getContext('2d');
    const tex = new THREE.CanvasTexture(this.canvas);
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.anisotropy = 4;
    this.texture = tex;

    // 판 지오메트리: 발 중심이 원점
    const w = rig.W / rig.ppm, h = rig.H / rig.ppm;
    const geo = new THREE.PlaneGeometry(w, h);
    geo.translate((rig.W / 2 - rig.footX) / rig.ppm, (rig.footY - rig.H / 2) / rig.ppm, 0);
    // 법선을 위쪽으로 기울여 해가 높을 때 지면처럼 밝게(캐릭터가 뒤에서 오는 빛에 새까매지지 않게)
    const n = geo.attributes.normal;
    const nv = new THREE.Vector3(0, 0.55, 1).normalize();
    for (let i = 0; i < n.count; i++) n.setXYZ(i, nv.x, nv.y, nv.z);
    this.geometry = geo;

    this.material = new THREE.MeshLambertMaterial({ map: tex, alphaTest: 0.5, transparent: false, side: THREE.DoubleSide });

    this.object3d = new THREE.Group();
    this.object3d.name = 'char:' + kind;
    this.billboard = new THREE.Group();
    this.object3d.add(this.billboard);

    this.sprite = new THREE.Mesh(geo, this.material);
    this.sprite.castShadow = false;
    this.sprite.receiveShadow = false;
    this.sprite.frustumCulled = false;
    this.billboard.add(this.sprite);

    this.silhouette = new THREE.Mesh(geo, makeSilhouetteMaterial(tex));
    this.silhouette.renderOrder = 999;
    this.silhouette.frustumCulled = false;
    this.billboard.add(this.silhouette);

    // 그림자 투사판: 화면에는 안 보이고(colorWrite false) 그림자 패스에서만 실루엣을 던진다. 해를 향해 돈다.
    // 주의: three는 그림자 패스에서 본 머티리얼의 map/alphaTest를 custom 머티리얼에 덮어쓰므로 여기에도 map+alphaTest를 준다
    const casterMat = new THREE.MeshBasicMaterial({ map: tex, alphaTest: 0.5, colorWrite: false, depthWrite: false, side: THREE.DoubleSide });
    this.caster = new THREE.Mesh(geo, casterMat);
    this.caster.castShadow = true;
    this.caster.receiveShadow = false;
    this.caster.frustumCulled = false;
    this.caster.customDepthMaterial = new THREE.MeshDepthMaterial({ depthPacking: THREE.RGBADepthPacking, map: tex, alphaTest: 0.5, side: THREE.DoubleSide });
    this.caster.customDistanceMaterial = new THREE.MeshDistanceMaterial({ map: tex, alphaTest: 0.5, side: THREE.DoubleSide });
    this.object3d.add(this.caster);

    // 발밑 블롭 그림자
    this.blob = new THREE.Mesh(blobGeometry(), new THREE.MeshBasicMaterial({
      map: blobTexture(), color: '#2a2018', transparent: true, opacity: 0.5, depthWrite: false,
      polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2,
    }));
    this.blob.position.y = 0.025;
    this.blob.renderOrder = 1;
    this.object3d.add(this.blob);
    this._blobBase = rig.type === 'tiger' ? [2.4, 0.85] : [rig.radius * 2.4, rig.radius * 1.35];
    this._applyBlob(0);

    this.object3d.userData.character = this;
    this._draw();
  }

  // ---- 공개 API ----
  setFacing(dir) {
    if (dir === this.facing || !['down', 'up', 'left', 'right'].includes(dir)) return;
    this.facing = dir;
    this._dirty = true;
  }
  setAnim(name) {
    if (name === this.anim) return;
    this.anim = name;
    this._dirty = true;
  }
  setMode(mode) {
    if (mode !== 'front' && mode !== '4dir') return;
    if (mode === this.mode) return;
    this.mode = mode;
    this._dirty = true;
  }
  setSilhouette(on) { this.silhouette.visible = !!on; }

  update(dt, camera) {
    this.t += dt;
    this._acc += dt;
    if (camera) this._orient(camera);
    if (this._dirty || this._acc >= 1 / FPS) {
      if (!this._drawnOnce || !camera || this._inView(camera)) {
        this._draw();
        this._acc %= 1 / FPS;
        this._dirty = false;
      }
    }
  }

  dispose() {
    this.texture.dispose();
    this.geometry.dispose();
    this.material.dispose();
    this.silhouette.material.dispose();
    this.caster.material.dispose();
    this.caster.customDepthMaterial.dispose();
    this.caster.customDistanceMaterial.dispose();
    this.blob.material.dispose();
  }

  // ---- 내부 ----
  _view() {
    if (this.mode === 'front') return ['front', this.facing === 'right'];
    switch (this.facing) {
      case 'up': return ['back', false];
      case 'left': return ['side', false];
      case 'right': return ['side', true];
      default: return ['front', false];
    }
  }

  _anim() {
    const a = this.anim;
    if (this.rig.type === 'tiger') return a === 'talk' ? 'idle' : a;
    return a === 'crouch' || a === 'pounce' ? 'idle' : a;
  }

  _orient(camera) {
    camera.getWorldDirection(_v);
    if (Math.abs(_v.x) + Math.abs(_v.z) > 1e-4) {
      const yaw = Math.atan2(-_v.x, -_v.z);
      this.billboard.rotation.set(-LEAN, yaw, 0, 'YXZ');
    }
    // 그림자 투사판은 해 쪽을 향한다
    let root = this.object3d;
    while (root.parent) root = root.parent;
    const sun = root.isScene ? findSun(root, performance.now()) : null;
    if (sun) {
      sun.getWorldPosition(_v);
      sun.target.getWorldPosition(_v2);
      _v.sub(_v2);
      if (Math.abs(_v.x) + Math.abs(_v.z) > 1e-4) this.caster.rotation.set(0, Math.atan2(_v.x, _v.z), 0);
    } else {
      this.caster.rotation.set(0, this.billboard.rotation.y, 0);
    }
  }

  _inView(camera) {
    _pm.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);
    _fr.setFromProjectionMatrix(_pm);
    this.object3d.getWorldPosition(_sph.center);
    _sph.center.y += this.rig.H / this.rig.ppm * 0.4;
    _sph.radius = Math.max(this.rig.W, this.rig.H) / this.rig.ppm * 0.6;
    return _fr.intersectsSphere(_sph);
  }

  _applyBlob(lift) {
    const [a, b] = this._blobBase;
    const k = Math.max(0.45, 1 - lift * 0.9);
    const sideways = this.rig.type === 'tiger' && (this.facing === 'up' || this.facing === 'down');
    this.blob.scale.set((sideways ? b * 1.1 : a) * k, 1, (sideways ? a * 0.5 : b) * k);
    this.blob.material.opacity = 0.5 * (0.5 + 0.5 * k);
  }

  _draw() {
    const rig = this.rig, g = this.ctx;
    const [view, mirror] = this._view();
    const parts = rig.views[view];
    const pose = rig.pose(view, this._anim(), this.t, rig);
    const M = this._mats;
    for (const p of parts) {
      const ps = pose[p.name];
      const r = p.r0 + (ps ? ps.r : 0);
      const x = p.at[0] + (ps ? ps.x : 0), y = p.at[1] + (ps ? ps.y : 0);
      const sx = ps ? ps.sx : 1, sy = ps ? ps.sy : 1;
      const parent = p.parent ? M[p.parent] : ID;
      const m = M[p.name] || (M[p.name] = [0, 0, 0, 0, 0, 0]);
      if (p.abs) {
        const wx = parent[0] * x + parent[2] * y + parent[4], wy = parent[1] * x + parent[3] * y + parent[5];
        trs(wx, wy, r, 1, 1, m);
      } else {
        mul(parent, trs(x, y, r, sx, sy, _loc), m);
      }
    }
    g.setTransform(1, 0, 0, 1, 0, 0);
    g.clearRect(0, 0, rig.W, rig.H);
    const base = mirror ? [-1, 0, 0, 1, rig.footX, rig.footY] : [1, 0, 0, 1, rig.footX, rig.footY];
    for (const p of parts.draw) {
      mul(base, M[p.name], _fin);
      g.setTransform(_fin[0], _fin[1], _fin[2], _fin[3], _fin[4], _fin[5]);
      g.drawImage(p.img, p.ox, p.oy);
    }
    g.setTransform(1, 0, 0, 1, 0, 0);
    this.texture.needsUpdate = true;
    this._drawnOnce = true;
    const rootY = pose.root ? pose.root.y : 0;
    this._applyBlob(Math.max(0, -rootY) / rig.ppm);
  }
}
