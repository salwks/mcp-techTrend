// 설화록 — 프레임 굽기 워커(OffscreenCanvas). 메인 스레드(로딩 화면·게임)를 막지 않는다.
// 받는 메시지: {type:'init', tier} / {type:'bake', kind, key, front}
// 보내는 메시지: {type:'ready'} / {type:'clip', kind, key, spec, frames, pages:[{index, bitmap}], stats} / {type:'fail', error}
import { BakeBank } from './frameCore.js';

let tier = 'high';
const banks = {};
const queue = [];
const queued = new Set();
let busy = false;

self.onmessage = (e) => {
  const m = e.data;
  if (m.type === 'init') {
    tier = m.tier || 'high';
    try {
      const ok = typeof OffscreenCanvas !== 'undefined' && new OffscreenCanvas(1, 1).getContext('2d');
      if (!ok) throw new Error('OffscreenCanvas 2D unsupported');
      self.postMessage({ type: 'ready' });
    } catch (err) {
      self.postMessage({ type: 'fail', error: String(err) });
    }
    return;
  }
  if (m.type === 'bake') {
    const id = m.kind + '#' + m.key;
    if (queued.has(id)) {
      if (m.front) { const i = queue.findIndex((q) => q.id === id); if (i > 0) queue.unshift(...queue.splice(i, 1)); }
      return;
    }
    queued.add(id);
    const job = { id, kind: m.kind, key: m.key };
    if (m.front) queue.unshift(job); else queue.push(job);
    pump();
  }
};

async function pump() {
  if (busy) return;
  busy = true;
  try {
    while (queue.length) {
      const job = queue.shift();
      const bank = banks[job.kind] || (banks[job.kind] = new BakeBank(job.kind, tier));
      const res = bank.bakeClip(job.key);
      if (!res) continue;
      const pages = [];
      for (const i of res.touched) pages.push({ index: i, bitmap: await createImageBitmap(bank.pages[i].cv) });
      self.postMessage({ type: 'clip', kind: job.kind, key: job.key, spec: res.spec, frames: res.frames, pages, stats: bank.stats() }, pages.map((p) => p.bitmap));
      await new Promise((r) => setTimeout(r, 0)); // 우선순위 요청이 끼어들 틈
    }
  } catch (err) {
    self.postMessage({ type: 'fail', error: String(err && err.stack || err) });
  }
  busy = false;
}
