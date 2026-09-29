// 필드가 쓰는 데이터 모듈을 안전하게 불러온다.
// 다른 담당의 파일이 아직 없거나 오류가 있어도 게임 전체가 멈추지 않도록 동적 import + 폴백.
import { CHARACTERS } from '../data/characters.js';

async function tryImport(path, name) {
  try {
    const mod = await import(path);
    const v = mod[name];
    if (v && typeof v === 'object') return v;
    console.warn(`[field] ${path}에 ${name} export가 없습니다`);
  } catch (err) {
    console.warn(`[field] ${path} 불러오기 실패 — 빈 데이터로 진행합니다`, err);
  }
  return {};
}

export const MAPS = await tryImport('../data/maps.js', 'MAPS');
export const EVENTS = await tryImport('../data/events.js', 'EVENTS');
export const ENCOUNTERS = await tryImport('../data/encounters.js', 'ENCOUNTERS');
export const ITEMS = await tryImport('../data/items.js', 'ITEMS');
export { CHARACTERS };

export function itemName(id) {
  return (ITEMS[id] && ITEMS[id].name) || id;
}

export function charName(id) {
  return (CHARACTERS[id] && CHARACTERS[id].name) || id;
}
