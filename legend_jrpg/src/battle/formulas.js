// 전투 공식 (DOM 비의존 — 헤드리스 시뮬레이션에서도 사용)
export const ELEMENT_NAMES = { fire: '불', ice: '얼음', thunder: '번개', holy: '빛' };
export const STATUS_NAMES = { poison: '독', sleep: '수면', stun: '기절' };

export const CRIT_RATE = 1 / 16;
export const CRIT_MULT = 1.5;
export const MISS_RATE = 0.04;

let rng = Math.random;
export function setRandom(fn) { rng = fn || Math.random; }
export function random() { return rng(); }
export function rand(a, b) { return a + rng() * (b - a); }
export function chance(p) { return rng() < p; }
export function pick(arr) { return arr[Math.floor(rng() * arr.length)]; }

// 물리 피해: (공격력×2 − 방어력) × 편차. 방어력이 높아도 공격력의 20%는 들어간다.
export function physicalDamage(atk, def, power = 1, opts = {}) {
  if (!opts.noMiss && chance(opts.missRate ?? MISS_RATE)) return { amount: 0, miss: true, crit: false };
  const crit = !opts.noCrit && chance(opts.critRate ?? CRIT_RATE);
  const effDef = crit ? def * 0.5 : def; // 회심은 방어를 반쯤 무시
  let raw = Math.max(atk * 2 - effDef, atk * 0.4);
  raw *= power * rand(0.88, 1.12);
  if (crit) raw *= CRIT_MULT;
  return { amount: Math.max(1, Math.round(raw)), miss: false, crit };
}

// 마법 피해: power + mag×1.5 − 대상 mag×0.4
export function magicDamage(power, mag, targetMag) {
  const raw = Math.max(power + mag * 1.5 - targetMag * 0.4, power * 0.3);
  return Math.max(1, Math.round(raw * rand(0.92, 1.08)));
}

export function healAmount(power, mag, magRate = 1.5) {
  if (power >= 9999) return 9999;
  return Math.max(1, Math.round((power + mag * magRate) * rand(0.95, 1.05)));
}

// 속성 배율: 약점 ×1.5, 내성 ×0.5
export function elementMult(weak, resist, element) {
  if (!element) return 1;
  if (weak && weak.includes(element)) return 1.5;
  if (resist && resist.includes(element)) return 0.5;
  return 1;
}

// 도주 성공률: 파티 평균 민첩 vs 적 평균 민첩, 실패할수록 쉬워진다
export function escapeChance(partySpd, enemySpd, tries = 0) {
  const p = 0.55 + (partySpd - enemySpd) * 0.025 + tries * 0.15;
  return Math.max(0.2, Math.min(0.95, p));
}

// 행동 순서 키: 민첩 + 약간의 난수
export function initiative(spd) {
  return spd + rand(0, spd * 0.25 + 3);
}

// ---- 한국어 조사 ----
function hasBatchim(word) {
  const s = String(word);
  const ch = s[s.length - 1];
  if (!ch) return false;
  const code = ch.charCodeAt(0);
  if (code >= 0xac00 && code <= 0xd7a3) return (code - 0xac00) % 28 !== 0;
  if (/[0-9]/.test(ch)) return '013678'.includes(ch);
  if (/[a-zA-Z]/.test(ch)) return 'LMNRlmnr'.includes(ch);
  return false;
}
function hasRieul(word) {
  const s = String(word);
  const code = s.charCodeAt(s.length - 1);
  if (code >= 0xac00 && code <= 0xd7a3) return (code - 0xac00) % 28 === 8;
  return /[lLrR1780]$/.test(s);
}
const JOSA = {
  '은': ['은', '는'], '는': ['은', '는'], '이': ['이', '가'], '가': ['이', '가'],
  '을': ['을', '를'], '를': ['을', '를'], '과': ['과', '와'], '와': ['과', '와'],
  '으로': ['으로', '로'], '로': ['으로', '로'], '의': ['의', '의'], '에게': ['에게', '에게'],
};
export function josa(word, j) {
  const pair = JOSA[j];
  if (!pair) return word + j;
  if (j === '으로' || j === '로') return word + (hasBatchim(word) && !hasRieul(word) ? '으로' : '로');
  return word + (hasBatchim(word) ? pair[0] : pair[1]);
}

// "{a은} 공격했다" → "슬라임은 공격했다"
export function fmt(template, name) {
  return template.replace(/\{a(은|는|이|가|을|를|과|와|으로|로|의|에게)?\}/g, (_, j) => (j ? josa(name, j) : name));
}
