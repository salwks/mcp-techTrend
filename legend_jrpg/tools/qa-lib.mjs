// QA 공용 도우미: Playwright 로더, 정적 서버, 페이지 헬퍼.
import { spawn } from 'node:child_process';
import net from 'node:net';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const OUT = process.env.QA_OUT || path.join(ROOT, 'tools', 'out');
fs.mkdirSync(OUT, { recursive: true });

const FALLBACK_PW = [
  process.env.QA_PLAYWRIGHT,
  '/tmp/claude-0/-home-user-mcp-techTrend/ef5bc28e-18b7-5c47-bb12-d4e56baaa73d/scratchpad/qa/node_modules/playwright/index.mjs',
].filter(Boolean);

export async function loadPlaywright() {
  try { return await import('playwright'); } catch {}
  for (const p of FALLBACK_PW) {
    if (fs.existsSync(p)) return import(pathToFileURL(p).href);
  }
  console.error('Playwright를 찾을 수 없습니다. `npm i playwright` 하거나 QA_PLAYWRIGHT=<.../playwright/index.mjs> 를 지정하세요.');
  process.exit(2);
}

function freePort() {
  return new Promise((res) => { const s = net.createServer(); s.listen(0, () => { const p = s.address().port; s.close(() => res(p)); }); });
}

export async function startServer() {
  const port = await freePort();
  const proc = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], { cwd: ROOT, stdio: 'ignore' });
  for (let i = 0; i < 50; i++) {
    const ok = await new Promise((r) => { const c = net.connect(port, '127.0.0.1', () => { c.end(); r(true); }); c.on('error', () => r(false)); });
    if (ok) break;
    await new Promise((r) => setTimeout(r, 100));
  }
  return { url: `http://127.0.0.1:${port}/`, stop: () => proc.kill() };
}

const IGNORE = [/fonts\.googleapis|fonts\.gstatic/i, /favicon\.ico/i, /ERR_CERT/i];

export async function openGame({ headless = true } = {}) {
  const { chromium } = await loadPlaywright();
  const server = await startServer();
  const browser = await chromium.launch({ executablePath: process.env.QA_CHROMIUM || '/opt/pw-browsers/chromium', headless });
  const page = await browser.newPage({ viewport: { width: 800, height: 640 } });
  const errors = [];
  page.on('pageerror', (e) => errors.push('pageerror: ' + (e.stack || e.message)));
  page.on('console', (m) => {
    if (m.type() !== 'error' && m.type() !== 'warning') return;
    const t = m.text();
    if (IGNORE.some((r) => r.test(t) || r.test(m.location()?.url || ''))) return;
    errors.push(`console.${m.type()}: ${t}`);
  });
  page.on('requestfailed', (r) => { if (!IGNORE.some((x) => x.test(r.url()))) errors.push('requestfailed: ' + r.url()); });
  page.on('response', (r) => { if (r.status() >= 400 && !IGNORE.some((x) => x.test(r.url()))) errors.push(`http ${r.status()}: ${r.url()}`); });
  await page.goto(server.url);
  await page.waitForFunction(() => window.__game && window.__game.top, null, { timeout: 15000 });
  const close = async () => { await browser.close(); server.stop(); };
  return { page, browser, server, errors, close, h: helpers(page) };
}

export function helpers(page) {
  const h = {
    top: () => page.evaluate(() => window.__game.top?.constructor.name),
    stack: () => page.evaluate(() => window.__game.stack.map((s) => s.constructor.name)),
    flag: (f) => page.evaluate((f) => window.__game.state?.getFlag(f), f),
    mapPos: () => page.evaluate(() => { const f = window.__game.stack.find((s) => s.constructor.name === 'FieldScene'); return f ? { map: f.mapId, x: f.player.x, y: f.player.y } : null; }),
    key: async (k, hold = 60) => { await page.keyboard.down(k); await page.waitForTimeout(hold); await page.keyboard.up(k); await page.waitForTimeout(40); },
    wait: (ms) => page.waitForTimeout(ms),
    shot: async (name) => { const p = path.join(OUT, name + '.png'); await page.locator('canvas').first().screenshot({ path: p }); return p; },
    // 필드가 입력을 받을 수 있는 상태(메시지/이벤트 없음)인지
    fieldIdle: () => page.evaluate(() => { const t = window.__game.top; return t?.constructor.name === 'FieldScene' && !t.busy && !t.msg.active && !t.choice && !t.player.moving; }),
    // cond()가 참이 될 때까지 확인 키 연타. 전투에서는 확인=공격 선택
    spamUntil: async (cond, { maxMs = 120000, key = 'Enter', onTick } = {}) => {
      const t0 = Date.now();
      while (Date.now() - t0 < maxMs) {
        if (await cond()) return true;
        if (onTick) await onTick();
        await h.key(key, 40);
      }
      return false;
    },
    // 전투 중이면 모든 적 HP를 1로(명령 선택 중에 0으로 만들면 대상 선택이 불가능해지므로) + 방어 0 → 다음 공격으로 처치
    killEnemies: () => page.evaluate(() => { const b = window.__game.stack.find((s) => s.constructor.name === 'BattleScene'); if (!b?.core) return false; for (const e of b.core.enemies) if (e.hp > 0) { e.hp = 1; } return true; }),
    setupState: (fn, arg) => page.evaluate(fn, arg),
  };
  return h;
}
