// 필드 공용 유틸: 한국어 조사, 결정적 난수, 방향, 조건 검사

// ---- 한국어 조사 ----
// 숫자로 끝나는 단어의 받침 여부(영,일,이,삼,사,오,육,칠,팔,구)
const DIGIT_JONG = [true, true, false, true, false, false, true, true, true, false];
const DIGIT_RIEUL = [false, true, false, false, false, false, false, true, true, false];

function finalInfo(word) {
  const s = String(word || '').replace(/[\s)\]"'!?.…]+$/, '');
  if (!s) return null;
  const code = s.charCodeAt(s.length - 1);
  if (code >= 0xac00 && code <= 0xd7a3) {
    const jong = (code - 0xac00) % 28;
    return { has: jong !== 0, rieul: jong === 8 };
  }
  if (code >= 48 && code <= 57) return { has: DIGIT_JONG[code - 48], rieul: DIGIT_RIEUL[code - 48] };
  return null;
}

// josa('미아', '이/가') → '미아가', josa('렌', '이/가') → '렌이'
// 지원: 이/가, 을/를, 은/는, 과/와, 아/야, 이/(없음) (예: '이다'), 으로/로
export function josa(word, pair) {
  const [withJong, withoutJong] = pair.split('/');
  const info = finalInfo(word);
  if (!info) return `${word}${withJong}(${withoutJong})`;
  if (withJong === '으로') return word + (info.has && !info.rieul ? '으로' : '로');
  return word + (info.has ? withJong : withoutJong);
}

// ---- 결정적 난수 ----
export function hash2(x, y, seed = 0) {
  let h = (x * 374761393 + y * 668265263 + seed * 2147483647) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

export function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---- 방향 ----
export const DIRS = {
  up: { x: 0, y: -1 },
  down: { x: 0, y: 1 },
  left: { x: -1, y: 0 },
  right: { x: 1, y: 0 },
};
export const PATH_DIRS = { U: 'up', D: 'down', L: 'left', R: 'right' };
export const OPPOSITE = { up: 'down', down: 'up', left: 'right', right: 'left' };

export function dirFromDelta(dx, dy, fallback = 'down') {
  if (dx === 0 && dy === 0) return fallback;
  if (Math.abs(dx) >= Math.abs(dy)) return dx > 0 ? 'right' : 'left';
  return dy > 0 ? 'down' : 'up';
}

// ---- 조건 (showIf / hideIf) ----
// 플래그 이름 앞에 '!'를 붙이면 부정(확장 문법)
export function flagTrue(state, name) {
  if (!name) return false;
  if (name[0] === '!') return !flagTrue(state, name.slice(1));
  return !!(state && state.getFlag(name));
}

export function isVisible(state, e) {
  if (!e) return false;
  if (e.showIf && !flagTrue(state, e.showIf)) return false;
  if (e.hideIf && flagTrue(state, e.hideIf)) return false;
  return true;
}

export function inRect(e, x, y) {
  const w = e.w || 1;
  const h = e.h || 1;
  return x >= e.x && x < e.x + w && y >= e.y && y < e.y + h;
}
