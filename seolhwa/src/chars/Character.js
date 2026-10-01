// 설화록 — 2D 컷아웃 캐릭터 (Spine식 3D 부위 리그)
//
// 구조
//  - 종류(kind)마다 모든 시점의 부위 그림을 한 번만 그려 아틀라스 텍스처 1장에 모은다(인스턴스 공유).
//  - 캐릭터 하나 = 부위마다 사각형 하나씩을 담은 동적 BufferGeometry 1개.
//    매 프레임 부위 변환(2D 아핀)으로 꼭짓점 위치만 갱신한다 → 텍스처 재업로드 0, 화면 주사율 그대로.
//  - 같은 지오메트리를 세 메시가 공유: 본체(조명 반응, 그림자 패스에선 해 쪽으로 돌림) / 한지빛 테두리(halo) / 가림 실루엣.
//  - 애니메이션: 키프레임(가감속) + 동작 사이 크로스페이드 + 스프링(옷자락·땋은 머리·꼬리의 뒤따름)
//    + 이동 속도에 맞춘 걸음 위상 + 가끔 눈 깜빡임.
import * as THREE from 'three';
import { getRig, strideOf } from './rigs.js';
import { makeCanvas, PAPER } from './painter.js';
import { COMBAT_HUMAN } from './anims.js';
import { FRAME_KINDS, frameBank, frameIndex, tickFrameBaking } from './frames.js';

const LEAN = THREE.MathUtils.degToRad(8); // 카메라 쪽으로 살짝 뒤로 젖힘(단축 보정)
const DZ = 0.0006;                         // 부위 사이 앞뒤 간격(m) — 작게 해야 층 사이 시차가 안 보인다
const MARGIN = 8;                          // 아틀라스에서 부위 둘레의 투명 여백(px) — halo가 번질 자리
const SIL_COLOR = new THREE.Color('#1b2130');
const HALO_INK = new THREE.Color('#1a1512');
const HALO_PAPER = new THREE.Color(PAPER);

// ---------------------------------------------------------------------------
// 종류별 공유 자원: 아틀라스, 재질
// ---------------------------------------------------------------------------
const _kindRes = new Map();

function buildAtlas(rig) {
  const imgs = new Set();
  for (const v of Object.values(rig.views)) for (const p of v.draw) imgs.add(p.img);
  const list = [...imgs].sort((a, b) => b.height - a.height);
  let area = 0;
  for (const im of list) area += (im.width + 2 * MARGIN) * (im.height + 2 * MARGIN);
  const W = Math.min(4096, Math.max(512, Math.ceil(Math.sqrt(area * 1.15) / 64) * 64));
  const rects = new Map();
  let x = 0, y = 0, rowH = 0;
  for (const im of list) {
    const w = im.width + 2 * MARGIN, h = im.height + 2 * MARGIN;
    if (x + w > W) { x = 0; y += rowH; rowH = 0; }
    rects.set(im, { x, y, w, h });
    x += w; rowH = Math.max(rowH, h);
  }
  const H = y + rowH;
  const cv = makeCanvas(W, H), g = cv.getContext('2d');
  for (const [im, r] of rects) g.drawImage(im, r.x + MARGIN, r.y + MARGIN);
  const tex = new THREE.CanvasTexture(cv);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.flipY = false;
  tex.anisotropy = 4;
  tex.generateMipmaps = true;
  tex.minFilter = THREE.LinearMipmapLinearFilter;
  // 시점별 사각형 UV(그리기 순서대로)
  const uvs = {};
  for (const [name, v] of Object.entries(rig.views)) {
    const a = new Float32Array(v.draw.length * 8);
    v.draw.forEach((p, k) => {
      const r = rects.get(p.img);
      const u0 = r.x / W, v0 = r.y / H, u1 = (r.x + r.w) / W, v1 = (r.y + r.h) / H;
      a.set([u0, v0, u1, v0, u0, v1, u1, v1], k * 8);
    });
    uvs[name] = a;
  }
  return { tex, W, H, uvs, bytes: W * H * 4 };
}

// 좌우 반전된 부위(뒷면으로 보임)도 앞면과 똑같이 빛을 받도록 법선 방향을 뒤집지 않는다
const NORMAL_FIX = '#include <normal_fragment_begin>\n\tnormal = normalize( vNormal );';

function haloMaterial(tex, W, H) {
  const m = new THREE.MeshLambertMaterial({ color: HALO_PAPER, map: tex, alphaTest: 0.5, side: THREE.DoubleSide, emissive: HALO_PAPER, emissiveIntensity: 0.3 });
  m.onBeforeCompile = (sh) => {
    sh.uniforms.uTexel = { value: new THREE.Vector2(1 / W, 1 / H) };
    sh.uniforms.uInk = { value: HALO_INK };
    sh.fragmentShader = sh.fragmentShader
      .replace('void main() {', 'uniform vec2 uTexel;\nuniform vec3 uInk;\nvoid main() {')
      .replace('#include <map_fragment>', `
        // 부위 알파를 두 반경으로 팽창: 안쪽 띠는 먹 테두리(겉 윤곽을 굵게), 바깥 띠는 한지빛 테두리
        // 반경은 '화면 픽셀' 기준으로도 최소 폭을 보장(멀리서 축소돼도 테두리가 끊기지 않게)
        vec2 px = fwidth(vMapUv);
        vec2 r1 = max(uTexel * 1.6, px * 0.9), r2 = max(uTexel * 3.6, px * 1.9);
        float a1 = 0.0, a2 = 0.0;
        for (int i = 0; i < 8; i++) {
          float ang = float(i) * 0.7853982;
          vec2 d = vec2(cos(ang), sin(ang));
          a1 = max(a1, texture2D(map, vMapUv + d * r1).a);
          a2 = max(a2, texture2D(map, vMapUv + d * r2).a);
        }
        float haloInk = step(0.5, a1);
        diffuseColor = vec4(mix(diffuse, uInk, haloInk), max(a1, a2));
      `)
      .replace('#include <emissivemap_fragment>', '#include <emissivemap_fragment>\n\ttotalEmissiveRadiance *= (1.0 - haloInk);')
      .replace('#include <normal_fragment_begin>', NORMAL_FIX);
    sh.vertexShader = sh.vertexShader.replace('#include <begin_vertex>', `#include <begin_vertex>\n\ttransformed.z = ${(-1.5 * DZ).toFixed(4)};`);
  };
  m.customProgramCacheKey = () => 'seolhwa-halo';
  return m;
}

function silhouetteMaterial(tex, frontZ) {
  const m = new THREE.MeshBasicMaterial({
    color: SIL_COLOR, map: tex, transparent: true, opacity: 0.42, alphaTest: 0.2,
    // depthWrite: 겹친 부위가 두 번 칠해져 얼룩지지 않게(같은 평면의 두 번째 조각은 GreaterDepth에서 탈락)
    depthWrite: true, depthFunc: THREE.GreaterDepth, side: THREE.DoubleSide, fog: false, toneMapped: false,
  });
  m.onBeforeCompile = (sh) => {
    sh.fragmentShader = sh.fragmentShader.replace('#include <map_fragment>', '#include <map_fragment>\n\tdiffuseColor.rgb = diffuse;');
    // 모든 부위를 맨 앞 평면으로 모아, 자기 부위끼리는 가리지 않게
    sh.vertexShader = sh.vertexShader.replace('#include <begin_vertex>', `#include <begin_vertex>\n\ttransformed.z = ${frontZ.toFixed(4)};`);
  };
  m.customProgramCacheKey = () => 'seolhwa-silhouette-' + frontZ.toFixed(3);
  return m;
}

// 그림자 패스에서만 판을 해 쪽으로 돌린다(본 화면에선 카메라를 향한 그대로).
// 모든 캐릭터가 같은 카메라·같은 해를 쓰므로 보정 회전 하나를 공유한다.
const SHADOW_FIX = { value: new THREE.Matrix3() };
function shadowFixed(m, key) {
  m.onBeforeCompile = (sh) => {
    sh.uniforms.uShadowFix = SHADOW_FIX;
    sh.vertexShader = sh.vertexShader
      .replace('void main() {', 'uniform mat3 uShadowFix;\nvoid main() {')
      .replace('#include <begin_vertex>', '#include <begin_vertex>\n\ttransformed = uShadowFix * transformed;');
  };
  m.customProgramCacheKey = () => 'seolhwa-shadowfix-' + key;
  return m;
}
const _m4 = new THREE.Matrix4(), _m4b = new THREE.Matrix4();
let _fixYaw = NaN, _fixSun = NaN;

function kindResources(kind) {
  let r = _kindRes.get(kind);
  if (r) return r;
  const rig = getRig(kind);
  const atlas = buildAtlas(rig);
  const N = Math.max(...Object.values(rig.views).map((v) => v.draw.length));
  const frontZ = (N + 2) * DZ;
  r = {
    rig, atlas, N,
    halo: haloMaterial(atlas.tex, atlas.W, atlas.H),
    silhouette: silhouetteMaterial(atlas.tex, frontZ),
    depthMat: shadowFixed(new THREE.MeshDepthMaterial({ depthPacking: THREE.RGBADepthPacking, map: atlas.tex, alphaTest: 0.5, side: THREE.DoubleSide }), 'd'),
    distMat: shadowFixed(new THREE.MeshDistanceMaterial({ map: atlas.tex, alphaTest: 0.5, side: THREE.DoubleSide }), 'p'),
  };
  _kindRes.set(kind, r);
  return r;
}

/** 로딩 중에 미리 굽기 + 통계 */
export function bakeKind(kind) {
  const r = kindResources(kind);
  return { atlas: `${r.atlas.W}x${r.atlas.H}`, mb: +(r.atlas.bytes / 1048576).toFixed(1), quads: r.N };
}

// ---- 블롭 그림자 ----
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

const _v = new THREE.Vector3(), _v2 = new THREE.Vector3(), _sph = new THREE.Sphere(), _fr = new THREE.Frustum(), _pm = new THREE.Matrix4(), _pm2 = new THREE.Matrix4();
let _frCam = null;
const _frM = new THREE.Matrix4(), _frP = new THREE.Matrix4();

// 2D 아핀 [a,b,c,d,e,f]
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
const _loc = [0, 0, 0, 0, 0, 0];
const wrapPi = (a) => a - Math.PI * 2 * Math.round(a / (Math.PI * 2));
const easeIO = (k) => (k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2);

// 스프링(뒤따르는 움직임): k 강성, c 감쇠, drag 이동 속도에 끌리는 정도(rad per m/s)
const SPRINGS = {
  human: { skirt: [90, 10, 0.05], braid: [55, 6, 0.1], pack: [120, 12, 0.03], head: [260, 26, 0.004], arm1_l: [170, 16, 0.02], arm2_l: [170, 16, 0.02] },
  tiger: { tail0: [80, 9, 0.05], tail1: [65, 7, 0.07], tail2: [52, 5.5, 0.09], tail3: [42, 4.5, 0.11], head: [210, 22, 0.01] },
};
const COMBAT_NO_SLEEVE = new Set(['arm1_l', 'arm2_l']);

export class Character {
  constructor(kind) {
    const res = kindResources(kind);
    const rig = res.rig;
    this.kind = kind;
    this.rig = rig;
    this.res = res;
    this.height = rig.height;
    this.radius = rig.radius;
    this.facing = 'down';
    this.anim = 'idle';
    this.mode = '4dir';
    this.t = Math.random() * 10;
    this.animTime = 0;
    this.animSpeed = 1;
    this.armed = false;
    this.phase = Math.random();
    this._moveSpeed = null;
    this._measured = 0;
    this._lastPos = null;
    this._flash = null;
    this._blend = null;
    this._springs = {};
    this._springCfg = SPRINGS[rig.type];
    this._blinkIn = 1 + Math.random() * 3;
    this._blinkLeft = 0;
    this._view = null;
    this._mats = {};
    this.texture = res.atlas.tex; // (공유) 호환용

    // --- 동적 지오메트리 ---
    const N = res.N;
    this._ppm = rig.ppm / rig.scale;
    const geo = new THREE.BufferGeometry();
    this._pos = new Float32Array(N * 12);
    const posAttr = new THREE.BufferAttribute(this._pos, 3);
    posAttr.setUsage(THREE.DynamicDrawUsage);
    geo.setAttribute('position', posAttr);
    const uvAttr = new THREE.BufferAttribute(new Float32Array(N * 8), 2);
    uvAttr.setUsage(THREE.DynamicDrawUsage);
    geo.setAttribute('uv', uvAttr);
    // 법선을 위로 기울여 해가 높을 때 지면처럼 밝게
    const nv = new THREE.Vector3(0, 0.55, 1).normalize();
    const nrm = new Float32Array(N * 12);
    for (let i = 0; i < N * 4; i++) nrm.set([nv.x, nv.y, nv.z], i * 3);
    geo.setAttribute('normal', new THREE.BufferAttribute(nrm, 3));
    const idx = [];
    for (let k = 0; k < N; k++) { const o = k * 4; idx.push(o, o + 2, o + 1, o + 1, o + 2, o + 3); }
    geo.setIndex(idx);
    const hM = Math.max(rig.W, rig.H) / this._ppm;
    geo.boundingSphere = new THREE.Sphere(new THREE.Vector3(0, hM * 0.35, 0), hM * 0.75);
    geo.boundingBox = new THREE.Box3(new THREE.Vector3(-hM, -0.2, -hM), new THREE.Vector3(hM, hM, hM));
    this.geometry = geo;

    this.material = new THREE.MeshLambertMaterial({ map: res.atlas.tex, alphaTest: 0.5, transparent: false, side: THREE.DoubleSide });
    this.material.onBeforeCompile = (sh) => { sh.fragmentShader = sh.fragmentShader.replace('#include <normal_fragment_begin>', NORMAL_FIX); };
    this.material.customProgramCacheKey = () => 'seolhwa-sprite';

    this.object3d = new THREE.Group();
    this.object3d.name = 'char:' + kind;
    this.billboard = new THREE.Group();
    this.object3d.add(this.billboard);

    this.sprite = new THREE.Mesh(geo, this.material);
    this.halo = new THREE.Mesh(geo, res.halo);
    this.silhouette = new THREE.Mesh(geo, res.silhouette);
    this.silhouette.renderOrder = 999;
    this.billboard.add(this.halo, this.sprite, this.silhouette);

    // 실제 그림자: 본체가 그림자 패스에서만 해 쪽으로 돌아간 모양으로 그려진다(추가 그리기 호출 없음)
    this.sprite.castShadow = true;
    this.sprite.customDepthMaterial = res.depthMat;
    this.sprite.customDistanceMaterial = res.distMat;

    // 발밑 블롭 그림자
    this.blob = new THREE.Mesh(blobGeometry(), new THREE.MeshBasicMaterial({
      map: blobTexture(), color: '#2a2018', transparent: true, opacity: 0.5, depthWrite: false,
      polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2,
    }));
    this.blob.position.y = 0.025;
    this.blob.renderOrder = 1;
    this.object3d.add(this.blob);
    const sc = rig.scale;
    this._blobBase = rig.type === 'tiger' ? [2.4 * sc, 0.85 * sc] : [rig.radius * 2.4, rig.radius * 1.35];

    this.object3d.userData.character = this;
    this._silOn = true;
    this._frameOn = false;
    this._bank = FRAME_KINDS.includes(kind) ? frameBank(kind) : null;
    this.renderStyle = this._bank ? 'frames' : 'cutout';
    this._pose(0);
    this._write();
  }

  // ---- 공개 API ----
  setFacing(dir) {
    if (dir === this.facing || !['down', 'up', 'left', 'right'].includes(dir)) return;
    this.facing = dir;
  }
  /** setAnim(name, { restart=false, speed=1 }) */
  setAnim(name, opts = {}) {
    this.animSpeed = opts.speed == null ? 1 : opts.speed;
    if (name === this.anim && !opts.restart) return;
    const into = this._info(name);
    // 동작 사이 크로스페이드(공격으로 들어갈 땐 아주 짧게 — 반응성 유지)
    const from = {};
    if (this._P) for (const n in this._P) { const p = this._P[n]; from[n] = { r: p.r, x: p.x, y: p.y, sx: p.sx, sy: p.sy, a: p.a }; }
    this._blend = { from, t: 0, dur: into && !into.loop ? 0.05 : 0.13 };
    this.anim = name;
    this.animTime = 0;
    if (this.rig.type === 'human') {
      if (COMBAT_HUMAN.has(name)) this.armed = true;
      else if (name === 'talk') this.armed = false;
    }
  }
  setArmed(on) { this.armed = !!on; }
  setMode(mode) { if (mode === 'front' || mode === '4dir') this.mode = mode; }
  setSilhouette(on) {
    this._silOn = !!on;
    this.silhouette.visible = this._silOn && !this._frameOn;
    if (this.fSil) this.fSil.visible = this._silOn && !!this._frameOn;
  }
  /** 실제 이동 속도(m/s)를 알려주면 걸음 주기가 발 미끄러짐 없이 맞춰진다. null이면 위치 변화로 추정. */
  setMoveSpeed(mps) { this._moveSpeed = mps == null ? null : Math.max(0, mps); }
  _info(name = this.anim) { return this.rig.anims[this._animName(name)] || null; }
  animDuration(name = this.anim) { const i = this._info(name); return i ? i.dur : 0; }
  get animDone() { const i = this._info(); return !!i && !i.loop && this.animTime >= i.dur; }
  flash(color = '#ffffff', ms = 120) {
    this._flash = { color: new THREE.Color(color), t: 0, dur: Math.max(1, ms) / 1000 };
    for (const m of this._mats4()) { m.emissive.copy(this._flash.color); m.emissiveIntensity = 1; }
  }
  _mats4() { return this.fMat ? [this.material, this.fMat] : [this.material]; }

  update(dt, camera) {
    this.t += dt;
    const info = this._info();
    this.animTime += dt * this.animSpeed;
    if (info && !info.loop && this.animTime > info.dur) this.animTime = info.dur;
    if (this._flash) {
      const f = this._flash;
      f.t += dt;
      const k = Math.max(0, 1 - f.t / f.dur);
      for (const m of this._mats4()) {
        m.emissiveIntensity = k * k;
        if (k <= 0) { m.emissive.setRGB(0, 0, 0); m.emissiveIntensity = 1; }
      }
      if (k <= 0) this._flash = null;
    }
    this._measure(dt);
    this._advancePhase(dt);
    if (camera) this._orient(camera);
    const visible = !camera || this._inView(camera);
    // 프레임 스타일: 구워 둔 그림이 있으면 그것을, 아직이면 컷아웃으로 잠시 대신
    if (this._bank) tickFrameBaking(2);
    const useFrames = this.renderStyle === 'frames' && this._bank && this._showFrame(visible);
    this._setStyleVisible(useFrames);
    if (useFrames) return;
    this._pose(dt);
    if (visible) this._write();
  }

  /** 'frames'(프레임 바이 프레임) | 'cutout'(컷아웃 리그). 프레임이 없는 종류는 'frames'를 무시. */
  setRenderStyle(style) {
    if (style !== 'frames' && style !== 'cutout') return;
    this.renderStyle = style === 'frames' && !this._bank ? 'cutout' : style;
  }

  _advancePhase(dt) {
    const rig = this.rig, anim = this._animName(this.anim);
    if (anim === 'walk' || anim === 'run' || anim === 'prowl' || anim === 'retreat') {
      const def = rig.type === 'tiger' ? (anim === 'run' ? 5 : anim === 'prowl' ? 1.1 : anim === 'retreat' ? 3.4 : 1.7) : anim === 'run' ? 4.6 : 2.2;
      let sp = this._moveSpeed != null ? this._moveSpeed : this._measured > 0.3 ? this._measured : def;
      sp = Math.max(sp, def * 0.35);
      this.phase += (dt * sp) / strideOf(rig, anim);
    }
  }

  _setStyleVisible(frames) {
    if (this._frameOn === frames) return;
    this._frameOn = frames;
    this.sprite.visible = this.halo.visible = !frames;
    this.silhouette.visible = !frames && this._silOn;
    if (this.fSprite) {
      this.fSprite.visible = this.fHalo.visible = frames;
      this.fSil.visible = frames && this._silOn;
    }
  }

  _buildFrameMeshes() {
    const geo = new THREE.BufferGeometry();
    const pos = new THREE.BufferAttribute(new Float32Array(12), 3); pos.setUsage(THREE.DynamicDrawUsage);
    const uv = new THREE.BufferAttribute(new Float32Array(8), 2); uv.setUsage(THREE.DynamicDrawUsage);
    const nv = new THREE.Vector3(0, 0.55, 1).normalize();
    geo.setAttribute('position', pos);
    geo.setAttribute('uv', uv);
    geo.setAttribute('normal', new THREE.BufferAttribute(new Float32Array([nv.x, nv.y, nv.z, nv.x, nv.y, nv.z, nv.x, nv.y, nv.z, nv.x, nv.y, nv.z]), 3));
    geo.setIndex([0, 2, 1, 1, 2, 3]);
    geo.boundingSphere = this.geometry.boundingSphere.clone();
    this.fGeo = geo;
    this.fMat = new THREE.MeshLambertMaterial({ alphaTest: 0.5, side: THREE.DoubleSide });
    this.fMat.onBeforeCompile = this.material.onBeforeCompile;
    this.fMat.customProgramCacheKey = this.material.customProgramCacheKey;
    this.fSprite = new THREE.Mesh(geo, this.fMat);
    this.fSprite.castShadow = true;
    this.fHalo = new THREE.Mesh(geo, this.res.halo);
    this.fSil = new THREE.Mesh(geo, this.res.silhouette);
    this.fSil.renderOrder = 999;
    this.fSprite.visible = this.fHalo.visible = this.fSil.visible = false;
    this.billboard.add(this.fHalo, this.fSprite, this.fSil);
  }

  /** 지금 그림 한 장을 사각형에 싣는다. 준비 안 됐으면 false */
  _showFrame(visible) {
    const [view, mirror] = this._viewOf();
    const anim = this._animName(this.anim);
    const clip = this._bank.get(view, anim, this.armed);
    if (!clip) return false;
    const f = clip.frames[frameIndex(clip.spec, this.animTime, this.phase, this.t)];
    if (!f) return false;
    if (!this.fSprite) this._buildFrameMeshes();
    const pg = f.page;
    if (!pg.mats) {
      pg.mats = {
        halo: haloMaterial(pg.tex, pg.cv.width, pg.cv.height),
        sil: silhouetteMaterial(pg.tex, 0.02),
        depth: shadowFixed(new THREE.MeshDepthMaterial({ depthPacking: THREE.RGBADepthPacking, map: pg.tex, alphaTest: 0.5, side: THREE.DoubleSide }), 'd'),
        dist: shadowFixed(new THREE.MeshDistanceMaterial({ map: pg.tex, alphaTest: 0.5, side: THREE.DoubleSide }), 'p'),
      };
    }
    if (this._fPage !== pg) {
      this._fPage = pg;
      this.fMat.map = pg.tex;
      this.fMat.needsUpdate = !this._fMapped;
      this._fMapped = true;
      this.fHalo.material = pg.mats.halo;
      this.fSil.material = pg.mats.sil;
      this.fSprite.customDepthMaterial = pg.mats.depth;
      this.fSprite.customDistanceMaterial = pg.mats.dist;
    }
    if (visible && (this._fFrame !== f || this._fMirror !== mirror)) {
      this._fFrame = f; this._fMirror = mirror;
      const sg = mirror ? -1 : 1, p = this.fGeo.attributes.position.array, uv = this.fGeo.attributes.uv.array;
      p.set([sg * f.x0, f.y1, 0, sg * f.x1, f.y1, 0, sg * f.x0, f.y0, 0, sg * f.x1, f.y0, 0]);
      uv.set([f.u0, f.v0, f.u1, f.v0, f.u0, f.v1, f.u1, f.v1]);
      this.fGeo.attributes.position.needsUpdate = true;
      this.fGeo.attributes.uv.needsUpdate = true;
    }
    this._blobFromLift(f.lift);
    return true;
  }

  _blobFromLift(lift) {
    const rig = this.rig;
    const [a, b] = this._blobBase;
    const kk = Math.max(0.45, 1 - lift * 0.9);
    const sideways = rig.type === 'tiger' && (this.facing === 'up' || this.facing === 'down') && this.mode !== 'front';
    this.blob.scale.set((sideways ? b * 1.1 : a) * kk, 1, (sideways ? a * 0.5 : b) * kk);
    this.blob.material.opacity = 0.5 * (0.5 + 0.5 * kk);
  }

  dispose() {
    this.geometry.dispose();
    this.material.dispose();
    this.blob.material.dispose();
    this.object3d.removeFromParent();
  }

  // ---- 내부 ----
  _animName(a) {
    if (this.rig.anims[a]) return a;
    if (this.rig.type === 'tiger') return a === 'run' ? 'walk' : 'idle';
    return a === 'prowl' ? 'walk' : a === 'stagger' ? 'hit' : 'idle';
  }

  _viewOf() {
    if (this.mode === 'front') return ['front', this.facing === 'right'];
    switch (this.facing) {
      case 'up': return ['back', false];
      case 'left': return ['side', false];
      case 'right': return ['side', true];
      default: return ['front', false];
    }
  }

  _measure(dt) {
    const p = this.object3d.position;
    if (this._lastPos && dt > 0) {
      const dx = p.x - this._lastPos.x, dz = p.z - this._lastPos.z, d = Math.hypot(dx, dz);
      if (d < 3) {
        const v = Math.min(10, d / dt);
        this._measured += (v - this._measured) * Math.min(1, dt * 10);
        this._vel = this._vel || { x: 0, z: 0 };
        this._vel.x += (dx / dt - this._vel.x) * Math.min(1, dt * 8);
        this._vel.z += (dz / dt - this._vel.z) * Math.min(1, dt * 8);
      }
    }
    this._lastPos = this._lastPos || new THREE.Vector3();
    this._lastPos.copy(p);
  }

  _orient(camera) {
    camera.getWorldDirection(_v);
    if (Math.abs(_v.x) + Math.abs(_v.z) > 1e-4) {
      const yaw = Math.atan2(-_v.x, -_v.z);
      this.billboard.rotation.set(-LEAN, yaw, 0, 'YXZ');
    }
    let root = this.object3d;
    while (root.parent) root = root.parent;
    const sun = root.isScene ? findSun(root, performance.now()) : null;
    let sunYaw = this.billboard.rotation.y;
    if (sun) {
      sun.getWorldPosition(_v);
      sun.target.getWorldPosition(_v2);
      _v.sub(_v2);
      if (Math.abs(_v.x) + Math.abs(_v.z) > 1e-4) sunYaw = Math.atan2(_v.x, _v.z);
    }
    // 보정 = (빌보드 회전)^-1 · (해 쪽 yaw) — 모두 같은 값이므로 바뀔 때만
    const by = this.billboard.rotation.y;
    if (by !== _fixYaw || sunYaw !== _fixSun) {
      _fixYaw = by; _fixSun = sunYaw;
      _m4.makeRotationFromEuler(this.billboard.rotation).invert();
      _m4.multiply(_m4b.makeRotationY(sunYaw));
      SHADOW_FIX.value.setFromMatrix4(_m4);
    }
  }

  _inView(camera) {
    // 절두체는 카메라가 움직였을 때만 다시 계산(모든 캐릭터가 공유)
    if (_frCam !== camera || !_frM.equals(camera.matrixWorld) || !_frP.equals(camera.projectionMatrix)) {
      _frCam = camera; _frM.copy(camera.matrixWorld); _frP.copy(camera.projectionMatrix);
      _pm.multiplyMatrices(camera.projectionMatrix, _pm2.copy(camera.matrixWorld).invert());
      _fr.setFromProjectionMatrix(_pm);
    }
    this.object3d.getWorldPosition(_sph.center);
    _sph.center.y += this.height * 0.5;
    _sph.radius = this.height * 1.6 + 1;
    return _fr.intersectsSphere(_sph);
  }

  /** 자세 계산: 키프레임 → 크로스페이드 → 스프링 → 눈 깜빡임 */
  _pose(dt) {
    const rig = this.rig;
    const [view, mirror] = this._viewOf();
    const anim = this._animName(this.anim);
    const info = rig.anims[anim];
    const at = info && !info.loop ? Math.min(this.animTime, info.dur) : this.animTime;
    const P = rig.pose(view, anim, this.t, rig, at, { armed: this.armed, phase: this.phase });

    // 크로스페이드
    const B = this._blend;
    if (B) {
      B.t += dt;
      const k = easeIO(Math.min(1, B.t / B.dur));
      for (const n in B.from) {
        const f = B.from[n], p = P[n] || (P[n] = { r: 0, x: 0, y: 0, sx: 1, sy: 1, a: f.a });
        const fr = p.r + wrapPi(f.r - p.r);
        p.r = fr + (p.r - fr) * k; p.x = f.x + (p.x - f.x) * k; p.y = f.y + (p.y - f.y) * k;
        p.sx = f.sx + (p.sx - f.sx) * k; p.sy = f.sy + (p.sy - f.sy) * k;
      }
      if (B.t >= B.dur) this._blend = null;
    }

    // 스프링: 목표 각도를 늦게 따라가며 출렁임(옷자락·머리채·꼬리)
    if (view !== this._view) { this._springs = {}; this._view = view; }
    const vx = this._planeVel(mirror);
    const combat = COMBAT_HUMAN.has(anim);
    for (const n in this._springCfg) {
      if (combat && COMBAT_NO_SLEEVE.has(n)) continue;
      const [K, C, drag] = this._springCfg[n];
      const p = P[n] || (P[n] = { r: 0, x: 0, y: 0, sx: 1, sy: 1 });
      const target = p.r + drag * vx;
      let s = this._springs[n];
      if (!s) s = this._springs[n] = { x: target, v: 0 };
      if (dt > 0) {
        const h = Math.min(dt, 1 / 30), steps = Math.ceil(dt / h);
        for (let i = 0; i < steps; i++) { const a = K * (target - s.x) - C * s.v; s.v += a * h; s.x += s.v * h; }
      }
      p.r = s.x;
    }

    // 눈 깜빡임
    if (rig.type === 'human') {
      this._blinkIn -= dt;
      if (this._blinkIn <= 0) { this._blinkLeft = 0.13; this._blinkIn = 2.2 + Math.random() * 3.5; }
      if (this._blinkLeft > 0) {
        this._blinkLeft -= dt;
        if (view !== 'back' && anim !== 'dead') {
          const h = P.head || { r: 0, x: 0, y: 0, sx: 1, sy: 1 };
          P.head_blink = { ...h, a: 1 };
          P.head = { ...h, a: 0 };
        }
      }
    }
    this._P = P;
    this._mirror = mirror;
    this._curView = view;
  }

  /** 카메라 평면에서의 좌우 이동 속도(자세 좌표계 기준, m/s) */
  _planeVel(mirror) {
    if (!this._vel) return 0;
    const yaw = this.billboard.rotation.y;
    const right = this._vel.x * Math.cos(yaw) - this._vel.z * Math.sin(yaw);
    // 캔버스 x는 오른쪽이 +, 좌우 반전이면 뒤집힘
    return mirror ? -right : right;
  }

  /** 부위 변환 → 꼭짓점 위치 */
  _write() {
    const rig = this.rig, P = this._P, view = this._curView, mirror = this._mirror;
    const parts = rig.views[view];
    const uvAttr = this.geometry.attributes.uv;
    if (this._uvView !== view) {
      uvAttr.array.fill(0);
      uvAttr.array.set(this.res.atlas.uvs[view]);
      uvAttr.needsUpdate = true;
      this._uvView = view;
    }
    const M = this._mats;
    for (const p of parts) {
      const ps = P[p.name];
      const r = p.r0 + (ps ? ps.r : 0);
      const x = p.at[0] + (ps ? ps.x : 0), y = p.at[1] + (ps ? ps.y : 0);
      const sx = ps ? ps.sx : 1, sy = ps ? ps.sy : 1;
      const parent = p.parent ? M[p.parent] : ID;
      const m = M[p.name] || (M[p.name] = [0, 0, 0, 0, 0, 0]);
      if (p.abs) {
        const wx = parent[0] * x + parent[2] * y + parent[4], wy = parent[1] * x + parent[3] * y + parent[5];
        trs(wx, wy, r, sx, sy, m);
      } else {
        mul(parent, trs(x, y, r, sx, sy, _loc), m);
      }
    }
    const anim = this._animName(this.anim);
    const bowAnim = anim === 'bow_draw' || anim === 'bow_shoot';
    const vis = {
      staff: !this.armed,
      sword: this.armed && !bowAnim && anim !== 'throw',
      backbow: !bowAnim && (this.armed || rig.spec.back === 'bow'),
    };
    const pos = this._pos, inv = 1 / this._ppm, sgn = mirror ? -1 : 1;
    const draw = parts.draw;
    for (let k = 0; k < this.res.N; k++) {
      const o = k * 12;
      const p = draw[k];
      let hide = !p;
      if (p) {
        const ps = P[p.name];
        if (p.tag === 'fx' || p.tag === 'alt') hide = !ps || !(ps.a > 0.5);
        else if (p.tag && vis[p.tag] === false) hide = true;
        else if (ps && ps.a != null && ps.a < 0.5) hide = true;
      }
      if (hide) { pos.fill(0, o, o + 12); continue; }
      const m = M[p.name];
      let x0 = p.ox - MARGIN, x1 = p.ox + p.img.width + MARGIN;
      if (p.flip) { x0 = -x0; x1 = -x1; }
      const y0 = p.oy - MARGIN, y1 = p.oy + p.img.height + MARGIN;
      const z = (k + 1) * DZ;
      // TL, TR, BL, BR
      pos[o] = sgn * (m[0] * x0 + m[2] * y0 + m[4]) * inv; pos[o + 1] = -(m[1] * x0 + m[3] * y0 + m[5]) * inv; pos[o + 2] = z;
      pos[o + 3] = sgn * (m[0] * x1 + m[2] * y0 + m[4]) * inv; pos[o + 4] = -(m[1] * x1 + m[3] * y0 + m[5]) * inv; pos[o + 5] = z;
      pos[o + 6] = sgn * (m[0] * x0 + m[2] * y1 + m[4]) * inv; pos[o + 7] = -(m[1] * x0 + m[3] * y1 + m[5]) * inv; pos[o + 8] = z;
      pos[o + 9] = sgn * (m[0] * x1 + m[2] * y1 + m[4]) * inv; pos[o + 10] = -(m[1] * x1 + m[3] * y1 + m[5]) * inv; pos[o + 11] = z;
    }
    this.geometry.attributes.position.needsUpdate = true;
    // 블롭: 몸이 뜨면 작고 옅게
    const rootY = P.root ? P.root.y : 0;
    this._blobFromLift(Math.max(0, -rootY) * inv);
  }
}
