// 설화록 — 캐릭터 모듈 진입점 (CONTRACTS §3)
import { Character } from './Character.js';
import { getRig } from './rigs.js';

export const KINDS = ['player', 'villager_m', 'villager_f', 'elder', 'child_boy', 'child_girl', 'hunter', 'tiger'];

/** 종류별 캐릭터 생성. 부위 이미지는 종류별로 한 번만 그려 공유한다. */
export function createCharacter(kind) {
  if (!KINDS.includes(kind)) {
    console.warn('[chars] unknown kind', kind, '→ villager_m');
    kind = 'villager_m';
  }
  return new Character(kind);
}

/** (선택) 로딩 화면 등에서 미리 부위 이미지를 그려둔다 */
export function preloadCharacters(kinds = KINDS) {
  for (const k of kinds) getRig(k);
}
