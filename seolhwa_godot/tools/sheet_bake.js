// 확인용 그림판(동작 표): 종류 여럿 × 시점 × 동작을 굽기 엔진(frameCore.BakeBank)으로 구워 한 장에 늘어놓고 data/_sheets/<name>.png 로 보낸다.
// 실행: python3 tools/web_export_server.py 8770 → http://localhost:8770/__tools/sheet_bake.html?kinds=villager_m,mongryong&anims=walk,run&views=front,back,side&name=arm_after
//   kinds: 웹 SPECS·굽기 표(kind_specs.ensureSpec)에 있는 사람 종류. 인물 빌더 인물은 builder:<preset> 또는 builder:<template>#<seed>.
import * as fc from '/src/chars/frameCore.js';
import { ensureSpec } from '/__tools/kind_specs.js';
import { installPoses } from '/__tools/pose_common.js';

export async function bakeKindFrames(kind, keys, px = 116) {
  fc.TIERS.high[kind] = px;
  const b = new fc.BakeBank(kind, 'high');
  const out = {};
  for (const key of keys) {
    const c = b.clip(key); if (!c) continue;
    let g = 0; while (!b.step(c) && g++ < 600);
    out[key] = c.frames;
  }
  return { bank: b, clips: out };
}

/** 프레임 목록을 캔버스에 줄지어 그림: rows = [{label, frames, bank}] */
export function drawSheet(rows, cell = [150, 250], px = 116) {
  const ncol = Math.max(...rows.map((r) => r.frames.length), 1);
  const cv = document.createElement('canvas');
  cv.width = cell[0] * ncol + 120; cv.height = cell[1] * rows.length;
  const g = cv.getContext('2d');
  g.fillStyle = '#ece6d6'; g.fillRect(0, 0, cv.width, cv.height);
  g.font = '14px sans-serif';
  rows.forEach((r, ri) => {
    g.fillStyle = '#5a4a3a'; g.fillText(r.label, 6, ri * cell[1] + 18);
    g.strokeStyle = 'rgba(90,74,58,0.25)'; g.beginPath(); g.moveTo(0, (ri + 1) * cell[1] - 12); g.lineTo(cv.width, (ri + 1) * cell[1] - 12); g.stroke();
    r.frames.forEach((f, i) => {
      const pg = r.bank.pages[typeof f.page === 'number' ? f.page : f.page.index].cv;
      const sx = f.u0 * 1024, sy = f.v0 * 1024, sw = (f.u1 - f.u0) * 1024, sh = (f.v1 - f.v0) * 1024;
      const k = sw / ((f.x1 - f.x0) * px);   // 이 그림의 1m당 px / 기준
      const dw = sw / k, dh = sh / k;
      const ox = 120 + i * cell[0] + cell[0] / 2 + f.x0 * px, oy = (ri + 1) * cell[1] - 12 - f.y1 * px;
      g.drawImage(pg, sx, sy, sw, sh, ox, oy, dw, dh);
    });
  });
  return cv;
}

export async function put(name, data) {
  const r = await fetch('/export/' + name, { method: 'PUT', body: data });
  if (!r.ok) throw new Error('PUT ' + name + ' ' + r.status);
}
export const toPng = (cv) => new Promise((r) => cv.toBlob(r, 'image/png'));

export async function run(log) {
  const q = new URLSearchParams(location.search);
  const kinds = (q.get('kinds') || 'villager_m').split(',');
  const anims = (q.get('anims') || 'walk').split(',');
  const views = (q.get('views') || 'front,back,side').split(',');
  const name = q.get('name') || 'sheet';
  const px = +(q.get('px') || 90);
  const rows = [];
  for (const kind of kinds) {
    let k = kind;
    if (kind.startsWith('builder:')) {
      const B = await import('/__tools/char_builder.js');
      k = B.registerSpec(B.specFromToken(kind.slice(8)));
    } else if (!ensureSpec(kind)) { log('unknown ' + kind); continue; }
    installPoses(k);
    const keys = [];
    for (const a of anims) for (const v of views) keys.push(fc.clipKey(v, a, false, false));
    const { bank, clips } = await bakeKindFrames(k, keys, px);
    for (const key of keys) if (clips[key]) rows.push({ label: kind.replace('builder:', '') + ' ' + key, frames: clips[key], bank });
    log('baked ' + kind);
  }
  const cv = drawSheet(rows, [Math.round(px * 1.35), Math.round(px * 2.6)], px);
  document.body.appendChild(cv);
  await put(`_sheets/${name}.png`, await toPng(cv));
  log('done ' + name);
}
