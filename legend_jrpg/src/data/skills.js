// 스킬 데이터 (battle-dev). 형식은 docs/CONTRACTS.md §7.
// kind 별 power 의미:
//   physical: 일반 공격 피해 배율(1.0 = 공격)       hits: 연속 타격 수
//   magic   : 기본 위력. 피해 = (power + mag*1.5 - 대상 mag*0.4) × 속성 배율
//   heal    : 회복량 = power + mag × (magRate ?? 1.5). power 9999 = 완전 회복
//   revive  : 부활 후 HP 비율 (0.5 = 최대 HP의 50%)
//   cure    : status 로 지정한 상태이상 해제 ('all' = 전부)
//   buff    : buff:{ stat:'atk'|'def', mult, turns } / taunt: 턴 수 (도발)
//   debuff  : status 를 chance 확률로 부여
// 대상: 'enemy' | 'allEnemies' | 'ally' | 'allAllies' | 'self' — 시전자 기준
export const SKILLS = {
  // ---------------- 렌 (용사) ----------------
  power_slash: { name: '파워 슬래시', desc: '힘을 실은 일격 (적 1체)', mp: 3, kind: 'physical', power: 1.6, target: 'enemy', field: false, sfx: 'crit' },
  holy_blade: { name: '홀리 블레이드', desc: '빛을 두른 참격 (적 1체·빛 속성)', mp: 6, kind: 'physical', power: 1.7, element: 'holy', target: 'enemy', field: false },
  brave_cry: { name: '브레이브 크라이', desc: '아군 전체의 공격력을 올린다 (4턴)', mp: 8, kind: 'buff', buff: { stat: 'atk', mult: 1.3, turns: 4 }, target: 'allAllies', field: false },
  star_blade: { name: '스타 블레이드', desc: '별빛의 검격 (적 전체·빛 속성)', mp: 16, kind: 'physical', power: 1.5, element: 'holy', target: 'allEnemies', field: false },

  // ---------------- 미아 (사제) ----------------
  heal: { name: '힐', desc: '아군 1명의 HP를 회복한다', mp: 3, kind: 'heal', power: 20, target: 'ally', field: true },
  cure: { name: '큐어', desc: '아군 1명의 독·수면·기절을 치료한다', mp: 2, kind: 'cure', status: 'all', target: 'ally', field: true },
  protect: { name: '프로텍트', desc: '아군 전체의 방어력을 올린다 (4턴)', mp: 5, kind: 'buff', buff: { stat: 'def', mult: 1.4, turns: 4 }, target: 'allAllies', field: false },
  heal_all: { name: '힐 올', desc: '아군 전체의 HP를 회복한다', mp: 9, kind: 'heal', power: 15, magRate: 1.0, target: 'allAllies', field: true },
  revive: { name: '리바이브', desc: '쓰러진 동료를 HP 절반으로 되살린다', mp: 12, kind: 'revive', power: 0.5, target: 'ally', field: true },
  holy_light: { name: '홀리 라이트', desc: '성스러운 빛 (적 전체·빛 속성)', mp: 10, kind: 'magic', power: 40, element: 'holy', target: 'allEnemies', field: false },
  full_heal: { name: '풀 힐', desc: '아군 1명의 HP를 완전히 회복하고 상태이상을 치료한다', mp: 16, kind: 'heal', power: 9999, cure: true, target: 'ally', field: true },

  // ---------------- 가렌 (기사) ----------------
  shield_bash: { name: '실드 배시', desc: '방패로 후려친다. 기절시키기도 한다', mp: 3, kind: 'physical', power: 1.3, status: 'stun', chance: 0.5, target: 'enemy', field: false },
  provoke: { name: '도발', desc: '3턴 동안 적의 공격을 자신에게 끌어들인다', mp: 2, kind: 'buff', taunt: 3, target: 'self', field: false },
  iron_wall: { name: '철벽', desc: '3턴 동안 자신의 방어력을 크게 올린다', mp: 5, kind: 'buff', buff: { stat: 'def', mult: 2.0, turns: 3 }, target: 'self', field: false },
  earth_splitter: { name: '대지 가르기', desc: '대지를 갈라 적 전체를 공격한다', mp: 10, kind: 'physical', power: 1.2, target: 'allEnemies', field: false },

  // ---------------- 셀라 (마법사) ----------------
  flame: { name: '플레임', desc: '불꽃 (적 1체·불 속성)', mp: 4, kind: 'magic', power: 35, element: 'fire', target: 'enemy', field: false },
  frost: { name: '프로스트', desc: '냉기 (적 1체·얼음 속성)', mp: 4, kind: 'magic', power: 35, element: 'ice', target: 'enemy', field: false },
  spark: { name: '스파크', desc: '전격 (적 1체·번개 속성)', mp: 4, kind: 'magic', power: 35, element: 'thunder', target: 'enemy', field: false },
  blaze: { name: '블레이즈', desc: '화염 폭풍 (적 전체·불 속성)', mp: 9, kind: 'magic', power: 45, element: 'fire', target: 'allEnemies', field: false },
  blizzard: { name: '블리자드', desc: '눈보라 (적 전체·얼음 속성)', mp: 14, kind: 'magic', power: 70, element: 'ice', target: 'allEnemies', field: false },
  thunderstorm: { name: '썬더스톰', desc: '뇌우 (적 전체·번개 속성)', mp: 20, kind: 'magic', power: 100, element: 'thunder', target: 'allEnemies', field: false },
  meteor: { name: '메테오', desc: '운석을 떨어뜨린다 (적 전체·무속성)', mp: 32, kind: 'magic', power: 170, target: 'allEnemies', field: false },
};

// 적 전용 기술. text 의 {a}=사용자 이름, {a은}/{a이}/{a을} 등은 조사 자동 처리.
// 대상은 시전자(적) 기준: 'enemy' = 파티원 1명, 'allEnemies' = 파티 전체, 'self'/'ally' = 적 자신/동료
export const ENEMY_SKILLS = {
  bite: { name: '물어뜯기', text: '{a은} 날카로운 이빨로 물어뜯었다!', kind: 'physical', power: 1.35, target: 'enemy' },
  tackle: { name: '몸통박치기', text: '{a은} 몸통박치기를 했다!', kind: 'physical', power: 1.2, target: 'enemy' },
  heavy_blow: { name: '강타', text: '{a은} 힘껏 내리쳤다!', kind: 'physical', power: 1.6, target: 'enemy' },
  double_slash: { name: '연속 베기', text: '{a은} 연속으로 베어 왔다!', kind: 'physical', power: 0.75, hits: 2, target: 'enemy' },
  tail_sweep: { name: '꼬리 휘두르기', text: '{a은} 꼬리를 크게 휘둘렀다!', kind: 'physical', power: 0.8, target: 'allEnemies' },
  poison_sting: { name: '독침', text: '{a은} 독침을 찔렀다!', kind: 'physical', power: 1.0, status: 'poison', chance: 0.5, target: 'enemy' },
  poison_spore: { name: '독 포자', text: '{a은} 독 포자를 흩뿌렸다!', kind: 'debuff', status: 'poison', chance: 0.45, target: 'allEnemies' },
  sleep_powder: { name: '잠의 가루', text: '{a은} 반짝이는 가루를 뿌렸다!', kind: 'debuff', status: 'sleep', chance: 0.4, target: 'allEnemies' },
  sleep_song: { name: '잠의 노래', text: '{a은} 기묘한 노래를 불렀다…', kind: 'debuff', status: 'sleep', chance: 0.55, target: 'enemy' },
  terror_roar: { name: '공포의 포효', text: '{a은} 땅을 울리는 포효를 질렀다!', kind: 'debuff', status: 'stun', chance: 0.3, target: 'allEnemies' },
  howl: { name: '울부짖기', text: '{a은} 울부짖으며 기세를 올렸다!', kind: 'buff', buff: { stat: 'atk', mult: 1.3, turns: 3 }, target: 'self' },
  harden: { name: '단단해지기', text: '{a은} 몸을 단단하게 굳혔다!', kind: 'buff', buff: { stat: 'def', mult: 1.5, turns: 3 }, target: 'self' },
  charge: { name: '힘 모으기', text: '{a은} 힘을 모으고 있다…!', kind: 'charge', target: 'self' },
  idle: { name: '멍하니', text: '{a은} 멍하니 상황을 살피고 있다.', kind: 'idle', target: 'self' },
  ember: { name: '불씨', text: '{a은} 불씨를 뿜었다!', kind: 'magic', power: 18, element: 'fire', target: 'enemy' },
  water_gun: { name: '물대포', text: '{a은} 물대포를 쏘았다!', kind: 'magic', power: 30, target: 'enemy' },
  tidal_wave: { name: '해일', text: '{a은} 거대한 파도를 일으켰다!', kind: 'magic', power: 32, target: 'allEnemies' },
  bolt_e: { name: '전격', text: '{a은} 번개를 떨어뜨렸다!', kind: 'magic', power: 45, element: 'thunder', target: 'enemy' },
  frost_e: { name: '냉기', text: '{a은} 얼음 파편을 날렸다!', kind: 'magic', power: 55, element: 'ice', target: 'enemy' },
  fire_breath: { name: '화염 숨결', text: '{a은} 불길을 내뿜었다!', kind: 'magic', power: 45, element: 'fire', target: 'allEnemies' },
  ice_breath: { name: '얼음 숨결', text: '{a은} 얼어붙는 숨결을 내뿜었다!', kind: 'magic', power: 60, element: 'ice', target: 'allEnemies' },
  dragon_breath: { name: '흑염의 숨결', text: '{a은} 검은 화염을 토해냈다!', kind: 'magic', power: 95, element: 'fire', target: 'allEnemies' },
  dark_bolt: { name: '다크 볼트', text: '{a은} 어둠의 화살을 쏘았다!', kind: 'magic', power: 50, target: 'enemy' },
  dark_nova: { name: '다크 노바', text: '{a은} 어둠의 파동을 퍼뜨렸다!', kind: 'magic', power: 45, target: 'allEnemies' },
  drain: { name: '흡혈', text: '{a은} 생명력을 빨아들였다!', kind: 'magic', power: 40, drain: true, target: 'enemy' },
  heal_e: { name: '회복 주문', text: '{a은} 회복 주문을 외웠다!', kind: 'heal', power: 60, target: 'ally' },
  regen: { name: '재생', text: '{a은} 상처를 재생시켰다!', kind: 'heal', power: 120, target: 'self' },
  war_cry: { name: '함성', text: '{a은} 전장을 뒤흔드는 함성을 질렀다!', kind: 'buff', buff: { stat: 'atk', mult: 1.4, turns: 3 }, target: 'self' },
  dark_flare: { name: '다크 플레어', text: '{a은} 암흑의 불꽃을 터뜨렸다!', kind: 'magic', power: 95, target: 'allEnemies' },
  hellfire: { name: '헬파이어', text: '{a은} 지옥의 업화를 불러냈다!', kind: 'magic', power: 120, element: 'fire', target: 'allEnemies' },
  doom_slash: { name: '파멸의 일격', text: '{a은} 파멸의 검을 내리쳤다!', kind: 'physical', power: 1.9, target: 'enemy' },
  abyss_gaze: { name: '심연의 눈', text: '{a의} 눈이 붉게 빛났다…!', kind: 'debuff', status: 'sleep', chance: 0.35, target: 'allEnemies' },
};

export function getSkill(id) {
  return SKILLS[id] || ENEMY_SKILLS[id] || null;
}
