// 스모크 테스트: 타이틀 → 새 게임 → 오프닝(장로 브리핑까지) → 메뉴 → 저장 → 새로고침 → 이어하기
// 실행: node tools/smoke.mjs   (QA_OUT=스크린샷 폴더)
import { openGame } from './qa-lib.mjs';

const { page, errors, close, h } = await openGame();
const fails = [];
const check = (ok, msg) => { console.log((ok ? 'PASS ' : 'FAIL ') + msg); if (!ok) fails.push(msg); };

try {
  await h.wait(800);
  check((await h.top()) === 'TitleScene', '타이틀 씬 표시');
  await h.shot('smoke_01_title');
  await page.evaluate(() => { for (let i = 1; i <= 3; i++) localStorage.removeItem?.call(localStorage, 'x'); });
  await h.key('Enter'); await h.wait(400); // 인트로 넘김
  await page.evaluate(() => { const t = window.__game.top; if (t.list) t.list.index = 0; });
  await h.key('Enter'); // 새로운 모험
  await h.wait(1800);
  check((await h.stack()).includes('FieldScene'), '새 게임 → 필드 진입');

  let sawBattle = 0;
  const ok = await h.spamUntil(async () => (await h.flag('elder_briefed')) && (await h.fieldIdle()), {
    maxMs: 240000,
    onTick: async () => {
      const top = await h.top();
      if (top === 'BattleScene' && sawBattle++ % 40 === 0) await h.shot('smoke_02_battle_' + sawBattle);
      if (top === 'GameOverScene') throw new Error('오프닝 도중 게임오버');
    },
  });
  check(ok, '오프닝 완료 (elder_briefed) — 확인 연타/공격만으로 진행');
  check(await h.flag('hero_awakened'), 'hero_awakened 플래그');
  const eq = await page.evaluate(() => window.__game.state.members.ren.equip.weapon);
  check(eq === 'sealed_sword', 'ren 무기 sealed_sword (' + eq + ')');
  await h.shot('smoke_03_after_briefing');
  const pos = await h.mapPos();
  console.log('  위치', JSON.stringify(pos), 'gold', await page.evaluate(() => window.__game.state.gold));

  // 메뉴 열기 → 각 하위 메뉴 진입/복귀
  await h.key('Escape'); await h.wait(500);
  check((await h.top()) === 'MenuScene', '메뉴 열림');
  await h.shot('smoke_04_menu');
  for (let i = 0; i < 4; i++) {
    await h.key('Enter'); await h.wait(300);
    await h.key('Enter'); await h.wait(300); // 멤버 선택 등
    await h.shot(`smoke_05_submenu_${i}`);
    for (let k = 0; k < 8; k++) {
      const atRoot = await page.evaluate(() => { const m = window.__game.top; return m.constructor.name !== 'MenuScene' || (m.view === 'party' && m.partyCursor === -1 && !m.flow?.msg?.active); });
      if (atRoot) break;
      await h.key('Backspace'); await h.wait(200);
    }
    const top = await h.top();
    if (top !== 'MenuScene') { check(false, `하위메뉴 ${i} 후 메뉴로 복귀 (top=${top})`); await h.key('Escape'); await h.wait(300); }
    await h.key('ArrowDown'); await h.wait(150);
  }
  // 저장 (커서는 '저장'(4)에 위치)
  await h.key('Enter'); await h.wait(500);
  check((await h.top()) === 'SaveScene', '저장 씬 열림');
  await h.key('Enter'); await h.wait(400); // 슬롯 1
  await h.shot('smoke_06_saved');
  await h.spamUntil(async () => (await h.top()) !== 'SaveScene', { maxMs: 5000 });
  const saved = await page.evaluate(() => Object.keys(localStorage).filter((k) => localStorage.getItem(k)?.includes('elder_briefed')));
  check(saved.length > 0, '저장 데이터가 localStorage에 기록됨 ' + JSON.stringify(saved));
  for (let k = 0; k < 3 && (await h.top()) !== 'FieldScene'; k++) { await h.key('Escape'); await h.wait(300); }
  check((await h.top()) === 'FieldScene', '메뉴 닫고 필드 복귀');

  // 새로고침 → 이어하기
  await page.reload();
  await page.waitForFunction(() => window.__game?.top);
  await h.wait(800);
  await h.key('Enter'); await h.wait(400); // 인트로 넘김
  const idx = await page.evaluate(() => { const t = window.__game.top; if (t.list) t.list.index = 1; return t.list?.items?.[1]; });
  console.log('  이어하기 항목', JSON.stringify(idx));
  await h.key('Enter'); await h.wait(600);
  check((await h.top()) === 'SaveScene', '이어하기 → 불러오기 씬');
  await h.shot('smoke_07_load');
  await h.key('Enter'); await h.wait(1500);
  const p2 = await h.mapPos();
  check((await h.top()) === 'FieldScene' && p2 && p2.map === pos.map && p2.x === pos.x && p2.y === pos.y, `로드 후 필드 복원 ${JSON.stringify(p2)}`);
  check(await h.flag('elder_briefed'), '로드 후 플래그 유지');
  await h.shot('smoke_08_loaded');
} catch (e) {
  check(false, '예외: ' + e.message);
  await h.shot('smoke_99_exception').catch(() => {});
}
check(errors.length === 0, '페이지 오류 없음');
for (const e of errors) console.log('  ' + e);
await close();
console.log(fails.length ? `\n실패 ${fails.length}건` : '\n모두 통과');
process.exit(fails.length ? 1 : 0);
