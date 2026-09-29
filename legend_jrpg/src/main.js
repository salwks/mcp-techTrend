// 진입점: 씬 등록 후 타이틀 시작
import { Game } from './engine/game.js';
import { unlockAudio } from './engine/audio.js';
import { FieldScene } from './field/FieldScene.js';
import { BattleScene } from './battle/BattleScene.js';
import { TitleScene } from './ui/scenes/TitleScene.js';
import { MenuScene } from './ui/scenes/MenuScene.js';
import { ShopScene } from './ui/scenes/ShopScene.js';
import { SaveScene } from './ui/scenes/SaveScene.js';
import { GameOverScene } from './ui/scenes/GameOverScene.js';
import { EndingScene } from './ui/scenes/EndingScene.js';

const canvas = document.getElementById('screen');
const game = new Game(canvas);

game.register('title', (g, p) => new TitleScene(g, p));
game.register('field', (g, p) => new FieldScene(g, p));
game.register('battle', (g, p) => new BattleScene(g, p));
game.register('menu', (g, p) => new MenuScene(g, p));
game.register('shop', (g, p) => new ShopScene(g, p));
game.register('save', (g, p) => new SaveScene(g, p));
game.register('gameover', (g, p) => new GameOverScene(g, p));
game.register('ending', (g, p) => new EndingScene(g, p));

// 브라우저 정책상 첫 사용자 입력 이후에만 소리를 낼 수 있다
game.input.onFirstInput = () => unlockAudio();
window.addEventListener('pointerdown', () => unlockAudio(), { once: true });

// 모바일 가상 패드
document.querySelectorAll('[data-action]').forEach((btn) => {
  const action = btn.dataset.action;
  const id = btn.dataset.id || action;
  const on = (e) => { e.preventDefault(); btn.classList.add('on'); game.input.setVirtual(action, true, id); };
  const off = (e) => { e.preventDefault(); btn.classList.remove('on'); game.input.setVirtual(action, false, id); };
  btn.addEventListener('pointerdown', on);
  btn.addEventListener('pointerup', off);
  btn.addEventListener('pointercancel', off);
  btn.addEventListener('pointerleave', off);
  btn.addEventListener('contextmenu', (e) => e.preventDefault());
});

window.__game = game; // 디버그/QA용
game.reset('title');
game.start();
