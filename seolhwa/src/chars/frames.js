// 설화록 — 프레임 바이 프레임('frames') 스타일: 메인 스레드 쪽 저장소
//  - 굽기는 Web Worker(OffscreenCanvas)에서. 지원되지 않으면 메인 스레드에서 한 화면 프레임에 한 장씩.
//  - 해상도 단계: 데스크톱 'high' / 휴대폰·작은 화면 'medium' (frameCore.js TIERS)
//  - 로딩 때 전투·이야기에 꼭 필요한 동작을 먼저(criticalKeys), 나머지는 처음 쓰일 때 굽는다.
//  - 구워진 페이지는 텍스처로 올리고, 실행 중에는 UV만 바꾼다(Character._showFrame).
import * as THREE from 'three';
import { BakeBank, FRAME_KINDS, TIERS, clipKey, criticalKeys, resolveView, frameIndex, expandKeys, DISGUISE_ANIMS } from './frameCore.js';

export { FRAME_KINDS, frameIndex };
const DISG_SET = new Set(DISGUISE_ANIMS.map((a) => a.split(':')[0]));

/** 기기 단계 판정: 굵은 포인터(터치)나 작은 화면이면 'medium' */
export function detectTier() {
  try {
    const coarse = typeof matchMedia !== 'undefined' && matchMedia('(pointer: coarse)').matches;
    const small = typeof screen !== 'undefined' && Math.min(screen.width, screen.height) < 720;
    return coarse || small ? 'medium' : 'high';
  } catch { return 'high'; }
}
let _tier = null;
/** 굽기 시작 전에만 바꿀 수 있다 */
export function setFrameTier(t) { if (TIERS[t] && !_stores.size) _tier = t; return getFrameTier(); }
export function getFrameTier() { return _tier || (_tier = detectTier()); }

// ---------------------------------------------------------------------------
// 워커
// ---------------------------------------------------------------------------
let _worker = null, _workerState = 'none'; // none | starting | ready | failed
let _forceMain = false;
function startWorker() {
  if (_workerState !== 'none' || _forceMain) return;
  if (typeof Worker === 'undefined' || typeof OffscreenCanvas === 'undefined' || typeof createImageBitmap === 'undefined') { _workerState = 'failed'; return; }
  try {
    _worker = new Worker(new URL('./frameWorker.js', import.meta.url), { type: 'module' });
  } catch { _workerState = 'failed'; return; }
  _workerState = 'starting';
  _worker.onmessage = (e) => {
    const m = e.data;
    if (m.type === 'ready') { _workerState = 'ready'; for (const s of _stores.values()) s._flushToWorker(); }
    else if (m.type === 'fail') workerFailed(m.error);
    else if (m.type === 'clip') { const s = _stores.get(m.kind); if (s) s._onClip(m); }
  };
  _worker.onerror = (e) => workerFailed(e.message || 'worker error');
  _worker.postMessage({ type: 'init', tier: getFrameTier() });
}
function workerFailed(err) {
  if (_workerState === 'failed') return;
  console.warn('[chars] 프레임 굽기 워커를 쓸 수 없어 메인 스레드에서 굽습니다:', err);
  _workerState = 'failed';
  try { _worker && _worker.terminate(); } catch { /* */ }
  _worker = null;
  for (const s of _stores.values()) s._toMain();
}

// ---------------------------------------------------------------------------
// 종류별 저장소
// ---------------------------------------------------------------------------
const _stores = new Map();
export function frameStore(kind) {
  if (!FRAME_KINDS.includes(kind)) return null;
  let s = _stores.get(kind);
  if (!s) { s = new FrameStore(kind); _stores.set(kind, s); }
  return s;
}

function makePageTex(image) {
  const tex = new THREE.Texture(image);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.flipY = false;
  tex.generateMipmaps = false;
  tex.minFilter = THREE.LinearFilter;
  tex.magFilter = THREE.LinearFilter;
  tex.needsUpdate = true;
  return tex;
}

class FrameStore {
  constructor(kind) {
    this.kind = kind;
    this.tier = getFrameTier();
    this.pages = [];             // { tex, size, mats }
    this.clips = new Map();      // key → { spec, frames(페이지 객체 연결됨) }
    this.wanted = [];            // 아직 안 보낸 요청(워커 준비 전)
    this.sent = new Set();
    this.critical = criticalKeys(kind);
    this.criticalLeft = new Set(this.critical);
    this.stats = null;
    this.bank = null;            // 메인 스레드 굽기용
    this.mainQueue = [];
    startWorker();
    for (const k of this.critical) this._request(k, false);
  }

  /** 변장 장면 그림을 뒤에서 미리 굽기 시작 */
  prepareVariant(v) {
    if (this.kind !== 'tiger' || v !== 'disguised' || this._disgAsked) return;
    this._disgAsked = true;
    for (const k of expandKeys('tiger', DISGUISE_ANIMS)) this._request(k, false);
  }

  /** 준비된 클립이면 돌려주고, 아니면 앞쪽으로 요청 */
  get(view, anim, armed, variant) {
    if (this.kind !== 'player' || !(anim === 'idle' || anim === 'walk' || anim === 'run')) armed = false;
    // 변장 그림은 이야기 장면 동작만(DISGUISE_ANIMS). 싸움이 시작되면 이야기 쪽에서 setVariant('normal')로 벗긴다.
    const disg = this.kind === 'tiger' && variant === 'disguised' && DISG_SET.has(anim);
    const key = clipKey(resolveView(this.kind, view, anim), anim, armed, disg);
    const c = this.clips.get(key);
    if (c) return c;
    this._request(key, true);
    return null;
  }

  _request(key, front) {
    if (this.sent.has(key)) {
      if (front && _workerState === 'ready') _worker.postMessage({ type: 'bake', kind: this.kind, key, front: true });
      else if (front && this.bank) { const i = this.mainQueue.indexOf(key); if (i > 0) this.mainQueue.unshift(...this.mainQueue.splice(i, 1)); }
      return;
    }
    if (_workerState === 'ready') { this.sent.add(key); _worker.postMessage({ type: 'bake', kind: this.kind, key, front }); }
    else if (_workerState === 'failed' || _forceMain) { this.sent.add(key); this._mainEnqueue(key, front); }
    else if (front) this.wanted.unshift(key); else this.wanted.push(key);
  }
  _flushToWorker() {
    const w = this.wanted; this.wanted = [];
    for (const k of w) this._request(k, false);
  }
  _toMain() {
    // 워커가 못 끝낸 것은 메인 스레드로
    const pending = [...this.sent].filter((k) => !this.clips.has(k)).concat(this.wanted);
    this.wanted = [];
    for (const k of pending) { this.sent.add(k); this._mainEnqueue(k, false); }
  }

  // ---- 워커 결과 ----
  _onClip(m) {
    for (const pg of m.pages) {
      const old = this.pages[pg.index];
      if (!old) this.pages[pg.index] = { tex: makePageTex(pg.bitmap), size: pg.bitmap.width, mats: null };
      else {
        const prev = old.tex.image;
        old.tex.image = pg.bitmap;
        old.tex.needsUpdate = true;
        if (prev && prev.close) setTimeout(() => prev.close(), 1000);
      }
    }
    this._ready(m.key, m.spec, m.frames);
    this.stats = m.stats;
  }
  _ready(key, spec, frames) {
    this.clips.set(key, { spec, frames: frames.map((f) => ({ ...f, page: this.pages[f.page] })) });
    this.criticalLeft.delete(key);
  }

  // ---- 메인 스레드 굽기(대체 경로) ----
  _mainEnqueue(key, front) {
    if (!this.bank) this.bank = new BakeBank(this.kind, this.tier);
    if (front) this.mainQueue.unshift(key); else this.mainQueue.push(key);
  }
  /** 한 장 굽고, 클립이 끝나면 텍스처에 올린다 */
  _mainStep() {
    if (!this.mainQueue.length) return false;
    const key = this.mainQueue[0];
    const c = this.bank.clip(key);
    if (!c) { this.mainQueue.shift(); return true; }
    if (this.bank.step(c)) {
      this.mainQueue.shift();
      this.bank.pages.forEach((p, i) => {
        if (!this.pages[i]) this.pages[i] = { tex: makePageTex(p.cv), size: p.cv.width, mats: null };
        else this.pages[i].tex.needsUpdate = true;
      });
      this._ready(key, c.spec, c.frames);
      this.stats = this.bank.stats();
    }
    return true;
  }
}

/** 메인 스레드 대체 경로: 한 화면 프레임에 그림 한 장(대개 1~5ms) */
let _lastTick = 0;
export function tickFrameBaking() {
  if (_workerState !== 'failed' && !_forceMain) return;
  const now = performance.now();
  if (now - _lastTick < 6) return;
  _lastTick = now;
  for (const s of _stores.values()) if (s.bank && s._mainStep()) return;
}

/** 로딩 화면용: 꼭 필요한 동작이 다 구워지면 끝나는 Promise. onProgress(done, total) */
export function prebakeFrames(onProgress) {
  for (const k of FRAME_KINDS) frameStore(k);
  const total = () => [..._stores.values()].reduce((a, s) => a + s.critical.length, 0);
  const left = () => [..._stores.values()].reduce((a, s) => a + s.criticalLeft.size, 0);
  return new Promise((resolve) => {
    const poll = () => {
      tickFrameBaking();
      if (onProgress) onProgress(total() - left(), total());
      if (!left()) resolve(frameStats()); else setTimeout(poll, 30);
    };
    poll();
  });
}
export function frameBakeProgress() {
  let t = 0, l = 0;
  for (const s of _stores.values()) { t += s.critical.length; l += s.criticalLeft.size; }
  return { done: t - l, total: t };
}

/** 테스트용: 메인 스레드에서 지금 전부(꼭 필요한 것 + 나머지 전부) 굽는다 */
export function bakeAllFrames(kinds = FRAME_KINDS, all = true) {
  _forceMain = true;
  const out = {};
  for (const k of kinds) {
    const s = frameStore(k);
    const keys = new Set(s.critical);
    if (all) {
      for (const v of ['side', 'front', 'back']) for (const a of Object.keys(s.kind === 'player' ? HUMAN_LIST : TIGER_LIST)) keys.add(clipKey(resolveView(k, v, a), a, false, false));
      if (k === 'tiger') for (const key of expandKeys('tiger', DISGUISE_ANIMS)) keys.add(key);
    }
    for (const key of [...s.wanted]) keys.add(key);
    s.wanted = [];
    for (const key of keys) { if (!s.clips.has(key)) { s.sent.add(key); s._mainEnqueue(key, false); } }
    while (s.mainQueue.length) s._mainStep();
    out[k] = s.stats;
  }
  return out;
}
const HUMAN_LIST = { talk: 1 };
const TIGER_LIST = { run: 1 };

export function frameStats() {
  const out = { tier: getFrameTier(), worker: _workerState };
  for (const [k, s] of _stores) out[k] = s.stats;
  return out;
}
