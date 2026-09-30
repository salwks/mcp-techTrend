// 설화록 — 캐릭터 모듈 진입점 (CONTRACTS §3, COMBAT §4.2)
import { Character, bakeKind } from './Character.js';
import { CHAR_SCALE } from './rigs.js';

export { CHAR_SCALE };
export const KINDS = ['player', 'villager_m', 'villager_f', 'elder', 'child_boy', 'child_girl', 'hunter', 'tiger'];

/** 종류별 캐릭터 생성. 부위 그림·아틀라스는 종류별로 한 번만 굽고 모든 인스턴스가 공유한다. */
export function createCharacter(kind) {
  if (!KINDS.includes(kind)) {
    console.warn('[chars] unknown kind', kind, '→ villager_m');
    kind = 'villager_m';
  }
  return new Character(kind);
}

/** (선택) 로딩 중 미리 굽기. 종류별 아틀라스 크기·메모리를 돌려준다. */
export function preloadCharacters(kinds = KINDS) {
  const out = {};
  for (const k of kinds) out[k] = bakeKind(k);
  return out;
}
