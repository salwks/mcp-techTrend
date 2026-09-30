// 적 데이터 (battle-dev). 형식은 docs/CONTRACTS.md §7.
// skills: [{ id: 'attack' | SKILLS/ENEMY_SKILLS id, w: 가중치, hpBelow?, hpAbove?, once? }]
// actions: 라운드당 행동 수, immune: 걸리지 않는 상태이상, phases: HP 비율 이하에서 한 번 발동하는 변화
// sprite: 그래픽 키(src/battle/enemySprites.js), palette: 같은 그래픽의 색 변형
const BOSS_IMMUNE = ['sleep', 'stun', 'poison'];

export const ENEMIES = {
  // ================= 숲 / 프롤로그 (Lv1~5) =================
  slime: {
    name: '슬라임', hp: 18, mp: 0, atk: 9, def: 3, mag: 2, spd: 4, exp: 5, gold: 3,
    drops: [{ item: 'herb', rate: 0.15 }], skills: [{ id: 'attack', w: 4 }, { id: 'idle', w: 1 }],
    weak: [], resist: [], sprite: 'slime',
  },
  wolf: {
    name: '숲늑대', hp: 28, mp: 0, atk: 11, def: 4, mag: 0, spd: 11, exp: 8, gold: 4,
    drops: [{ item: 'herb', rate: 0.1 }], skills: [{ id: 'attack', w: 3 }, { id: 'bite', w: 1 }],
    weak: ['fire'], resist: [], sprite: 'wolf',
  },
  goblin: {
    name: '고블린', hp: 36, mp: 0, atk: 14, def: 6, mag: 0, spd: 7, exp: 10, gold: 9,
    drops: [{ item: 'herb', rate: 0.2 }], skills: [{ id: 'attack', w: 4 }, { id: 'heavy_blow', w: 1 }],
    weak: [], resist: [], sprite: 'goblin',
  },
  mushroom: {
    name: '독버섯', hp: 30, mp: 0, atk: 11, def: 5, mag: 6, spd: 5, exp: 9, gold: 6,
    drops: [{ item: 'antidote', rate: 0.25 }], skills: [{ id: 'attack', w: 3 }, { id: 'poison_spore', w: 2 }],
    weak: ['fire'], resist: [], sprite: 'mushroom',
  },
  bee: {
    name: '킬러비', hp: 22, mp: 0, atk: 13, def: 3, mag: 0, spd: 14, exp: 9, gold: 5,
    drops: [{ item: 'antidote', rate: 0.15 }], skills: [{ id: 'attack', w: 3 }, { id: 'poison_sting', w: 2 }],
    weak: ['ice'], resist: [], sprite: 'bee',
  },
  goblin_chief: {
    name: '고블린 두목', hp: 110, mp: 0, atk: 9, def: 6, mag: 0, spd: 6, exp: 16, gold: 40,
    drops: [{ item: 'potion', rate: 1 }], boss: true, immune: BOSS_IMMUNE,
    skills: [{ id: 'attack', w: 4 }, { id: 'charge', w: 1 }, { id: 'heavy_blow', w: 1 }],
    weak: [], resist: [], sprite: 'goblin_chief',
  },
  treant: {
    name: '고목의 정령 트렌트', hp: 440, mp: 0, atk: 15, def: 10, mag: 14, spd: 6, exp: 60, gold: 120,
    drops: [{ item: 'potion', rate: 1 }], boss: true, immune: BOSS_IMMUNE,
    skills: [{ id: 'attack', w: 4 }, { id: 'tail_sweep', w: 2 }, { id: 'poison_spore', w: 1 }, { id: 'regen', w: 1, hpBelow: 0.4 }],
    phases: [{ hpBelow: 0.4, text: '{a의} 가지가 붉게 물들었다!', atk: 1.1 }],
    weak: ['fire'], resist: ['ice'], sprite: 'treant',
  },

  // ================= 들판 (Lv4~8) =================
  red_slime: {
    name: '붉은 슬라임', hp: 40, mp: 10, atk: 18, def: 9, mag: 6, spd: 8, exp: 10, gold: 9,
    drops: [{ item: 'herb', rate: 0.2 }], skills: [{ id: 'attack', w: 3 }, { id: 'ember', w: 2 }],
    weak: ['ice'], resist: ['fire'], sprite: 'slime', palette: 'red',
  },
  boar: {
    name: '사나운 멧돼지', hp: 60, mp: 0, atk: 20, def: 11, mag: 0, spd: 9, exp: 13, gold: 11,
    drops: [{ item: 'herb', rate: 0.25 }], skills: [{ id: 'attack', w: 3 }, { id: 'tackle', w: 2 }],
    weak: ['fire'], resist: [], sprite: 'boar',
  },
  bird: {
    name: '큰부리새', hp: 42, mp: 0, atk: 18, def: 8, mag: 0, spd: 18, exp: 11, gold: 10,
    drops: [{ item: 'potion', rate: 0.1 }], skills: [{ id: 'attack', w: 3 }, { id: 'double_slash', w: 1 }],
    weak: ['thunder'], resist: [], sprite: 'bird',
  },
  goblin_warrior: {
    name: '고블린 전사', hp: 66, mp: 0, atk: 21, def: 14, mag: 0, spd: 8, exp: 15, gold: 18,
    drops: [{ item: 'potion', rate: 0.15 }], skills: [{ id: 'attack', w: 3 }, { id: 'heavy_blow', w: 1 }],
    weak: [], resist: [], sprite: 'goblin', palette: 'warrior',
  },

  // ================= 해안 동굴 (Lv6~9) =================
  bat: {
    name: '동굴박쥐', hp: 46, mp: 0, atk: 26, def: 10, mag: 0, spd: 20, exp: 11, gold: 9,
    drops: [{ item: 'herb', rate: 0.2 }], skills: [{ id: 'attack', w: 3 }, { id: 'bite', w: 1 }],
    weak: ['holy'], resist: [], sprite: 'bat',
  },
  crab: {
    name: '바위게', hp: 80, mp: 0, atk: 28, def: 32, mag: 0, spd: 6, exp: 17, gold: 16,
    drops: [{ item: 'potion', rate: 0.15 }], skills: [{ id: 'attack', w: 3 }, { id: 'harden', w: 1 }],
    weak: ['thunder'], resist: ['ice'], sprite: 'crab',
  },
  skeleton: {
    name: '해골병사', hp: 70, mp: 0, atk: 29, def: 18, mag: 0, spd: 10, exp: 16, gold: 15,
    drops: [{ item: 'antidote', rate: 0.2 }], skills: [{ id: 'attack', w: 3 }, { id: 'double_slash', w: 1 }],
    weak: ['holy', 'fire'], resist: ['ice'], immune: ['poison'], sprite: 'skeleton',
  },
  jellyfish: {
    name: '독해파리', hp: 55, mp: 0, atk: 24, def: 12, mag: 20, spd: 12, exp: 14, gold: 13,
    drops: [{ item: 'antidote', rate: 0.3 }], skills: [{ id: 'attack', w: 2 }, { id: 'poison_sting', w: 2 }],
    weak: ['thunder'], resist: ['fire'], sprite: 'jellyfish',
  },
  sahuagin: {
    name: '사하긴', hp: 84, mp: 20, atk: 30, def: 20, mag: 10, spd: 14, exp: 20, gold: 22,
    drops: [{ item: 'ether', rate: 0.1 }], skills: [{ id: 'attack', w: 3 }, { id: 'water_gun', w: 1 }],
    weak: ['thunder'], resist: [], sprite: 'sahuagin',
  },
  sea_serpent: {
    name: '바다뱀 레비아', hp: 1100, mp: 99, atk: 46, def: 28, mag: 8, spd: 14, exp: 150, gold: 400,
    drops: [{ item: 'ether', rate: 1 }], boss: true, immune: BOSS_IMMUNE, actions: 1,
    skills: [{ id: 'attack', w: 3 }, { id: 'bite', w: 2 }, { id: 'tidal_wave', w: 2 }, { id: 'tail_sweep', w: 1 }],
    phases: [{ hpBelow: 0.5, text: '{a은} 성난 물보라를 일으켰다!', actions: 2, atk: 0.85 }],
    weak: ['thunder'], resist: ['ice'], sprite: 'sea_serpent',
  },

  // ================= 별빛의 탑 (Lv9~13) =================
  gargoyle: {
    name: '가고일', hp: 180, mp: 0, atk: 38, def: 40, mag: 0, spd: 16, exp: 30, gold: 28,
    drops: [{ item: 'potion', rate: 0.2 }], skills: [{ id: 'attack', w: 3 }, { id: 'harden', w: 1 }, { id: 'double_slash', w: 1 }],
    weak: ['thunder'], resist: ['fire', 'ice'], sprite: 'gargoyle',
  },
  ghost: {
    name: '떠도는 망령', hp: 130, mp: 40, atk: 32, def: 20, mag: 18, spd: 18, exp: 28, gold: 24,
    drops: [{ item: 'ether', rate: 0.1 }], skills: [{ id: 'attack', w: 2 }, { id: 'dark_bolt', w: 2 }, { id: 'sleep_song', w: 1 }],
    weak: ['holy', 'fire'], resist: ['ice'], immune: ['poison'], sprite: 'ghost',
  },
  book: {
    name: '마도서', hp: 120, mp: 60, atk: 26, def: 26, mag: 22, spd: 15, exp: 30, gold: 34,
    drops: [{ item: 'ether', rate: 0.15 }], skills: [{ id: 'attack', w: 1 }, { id: 'frost_e', w: 2 }, { id: 'bolt_e', w: 2 }],
    weak: ['fire'], resist: ['thunder'], sprite: 'book',
  },
  skeleton_knight: {
    name: '해골기사', hp: 210, mp: 0, atk: 40, def: 38, mag: 0, spd: 13, exp: 36, gold: 34,
    drops: [{ item: 'hi_potion', rate: 0.08 }], skills: [{ id: 'attack', w: 3 }, { id: 'double_slash', w: 1 }],
    weak: ['holy', 'fire'], resist: ['ice'], immune: ['poison'], sprite: 'skeleton', palette: 'knight',
  },
  golem: {
    name: '스톤 골렘', hp: 340, mp: 0, atk: 44, def: 55, mag: 0, spd: 5, exp: 48, gold: 45,
    drops: [{ item: 'hi_potion', rate: 0.12 }], skills: [{ id: 'attack', w: 3 }, { id: 'heavy_blow', w: 1 }],
    weak: ['thunder'], resist: ['fire'], immune: ['poison', 'sleep'], sprite: 'golem',
  },
  lich: {
    name: '리치 네크로스', hp: 1500, mp: 999, atk: 40, def: 40, mag: 23, spd: 20, exp: 320, gold: 800,
    drops: [{ item: 'hi_ether', rate: 1 }], boss: true, immune: BOSS_IMMUNE, actions: 2,
    skills: [{ id: 'attack', w: 1 }, { id: 'dark_bolt', w: 3 }, { id: 'dark_nova', w: 2 }, { id: 'drain', w: 2 }, { id: 'sleep_song', w: 1 }],
    phases: [{ hpBelow: 0.4, text: '{a의} 눈구멍에 푸른 불꽃이 타올랐다!', atk: 1.15 }],
    weak: ['holy', 'fire'], resist: ['ice'], sprite: 'lich',
  },

  // ================= 잿빛 황야 (Lv12~16) =================
  scorpion: {
    name: '사막전갈', hp: 300, mp: 0, atk: 46, def: 52, mag: 0, spd: 14, exp: 40, gold: 40,
    drops: [{ item: 'antidote', rate: 0.3 }], skills: [{ id: 'attack', w: 3 }, { id: 'poison_sting', w: 2 }],
    weak: ['ice'], resist: ['fire'], sprite: 'scorpion',
  },
  salamander: {
    name: '샐러맨더', hp: 270, mp: 60, atk: 44, def: 40, mag: 24, spd: 18, exp: 42, gold: 44,
    drops: [{ item: 'fire_bomb', rate: 0.2 }], skills: [{ id: 'attack', w: 3 }, { id: 'fire_breath', w: 1 }],
    weak: ['ice'], resist: ['fire'], sprite: 'salamander',
  },
  wyvern: {
    name: '와이번', hp: 370, mp: 0, atk: 48, def: 46, mag: 0, spd: 28, exp: 48, gold: 52,
    drops: [{ item: 'hi_potion', rate: 0.15 }], skills: [{ id: 'attack', w: 3 }, { id: 'tail_sweep', w: 1 }],
    weak: ['thunder', 'ice'], resist: [], sprite: 'wyvern',
  },
  ogre: {
    name: '오우거', hp: 540, mp: 0, atk: 53, def: 44, mag: 0, spd: 9, exp: 56, gold: 60,
    drops: [{ item: 'hi_potion', rate: 0.2 }], skills: [{ id: 'attack', w: 3 }, { id: 'charge', w: 1 }, { id: 'heavy_blow', w: 1 }],
    weak: ['fire'], resist: [], sprite: 'ogre',
  },
  ghoul: {
    name: '구울', hp: 320, mp: 0, atk: 44, def: 32, mag: 0, spd: 12, exp: 38, gold: 36,
    drops: [{ item: 'panacea', rate: 0.15 }], skills: [{ id: 'attack', w: 3 }, { id: 'poison_sting', w: 1 }],
    weak: ['holy', 'fire'], resist: [], immune: ['poison'], sprite: 'ghoul',
  },
  black_dragon: {
    name: '흑룡 바르다크', hp: 4500, mp: 999, atk: 47, def: 58, mag: 22, spd: 24, exp: 520, gold: 1500,
    drops: [{ item: 'elixir', rate: 1 }], boss: true, immune: BOSS_IMMUNE, actions: 2,
    skills: [{ id: 'attack', w: 3 }, { id: 'bite', w: 2 }, { id: 'dragon_breath', w: 2 }, { id: 'tail_sweep', w: 2 }, { id: 'terror_roar', w: 1 }],
    phases: [{ hpBelow: 0.35, text: '{a은} 하늘을 찢는 포효를 질렀다! 비늘이 불타오른다!', atk: 1.15 }],
    weak: ['ice', 'holy'], resist: ['fire'], sprite: 'black_dragon',
  },

  // ================= 마왕성 (Lv16~22) =================
  dark_knight: {
    name: '암흑기사', hp: 600, mp: 0, atk: 57, def: 74, mag: 0, spd: 20, exp: 62, gold: 75,
    drops: [{ item: 'hi_potion', rate: 0.2 }], skills: [{ id: 'attack', w: 3 }, { id: 'double_slash', w: 1 }],
    weak: ['holy'], resist: ['ice'], sprite: 'dark_knight',
  },
  living_armor: {
    name: '리빙 아머', hp: 680, mp: 0, atk: 55, def: 96, mag: 0, spd: 12, exp: 66, gold: 80,
    drops: [{ item: 'hi_ether', rate: 0.1 }], skills: [{ id: 'attack', w: 3 }, { id: 'harden', w: 1 }],
    weak: ['thunder'], resist: ['fire', 'ice'], immune: ['poison', 'sleep'], sprite: 'dark_knight', palette: 'armor',
  },
  imp: {
    name: '소악마', hp: 340, mp: 80, atk: 44, def: 50, mag: 34, spd: 30, exp: 52, gold: 62,
    drops: [{ item: 'ether', rate: 0.2 }], skills: [{ id: 'attack', w: 2 }, { id: 'dark_bolt', w: 2 }, { id: 'sleep_song', w: 1 }],
    weak: ['holy'], resist: ['fire'], sprite: 'imp',
  },
  chimera: {
    name: '키메라', hp: 720, mp: 60, atk: 59, def: 64, mag: 30, spd: 22, exp: 76, gold: 90,
    drops: [{ item: 'hi_potion', rate: 0.2 }], skills: [{ id: 'attack', w: 3 }, { id: 'bite', w: 1 }, { id: 'fire_breath', w: 1 }],
    weak: ['ice'], resist: ['fire'], sprite: 'chimera',
  },
  archdemon: {
    name: '아크데몬', hp: 800, mp: 120, atk: 62, def: 70, mag: 36, spd: 20, exp: 96, gold: 110,
    drops: [{ item: 'elixir', rate: 0.05 }], skills: [{ id: 'attack', w: 3 }, { id: 'dark_nova', w: 1 }, { id: 'heavy_blow', w: 1 }],
    weak: ['holy'], resist: ['fire', 'thunder'], sprite: 'archdemon',
  },
  vorg: {
    name: '마장군 보르그', hp: 5500, mp: 999, atk: 69, def: 80, mag: 50, spd: 26, exp: 700, gold: 2000,
    drops: [{ item: 'elixir', rate: 1 }], boss: true, immune: BOSS_IMMUNE, actions: 2,
    skills: [{ id: 'attack', w: 4 }, { id: 'double_slash', w: 2 }, { id: 'heavy_blow', w: 2 }, { id: 'war_cry', w: 1 }, { id: 'terror_roar', w: 1 }, { id: 'charge', w: 1 }],
    phases: [{ hpBelow: 0.4, text: '{a은} 투구를 벗어 던졌다! "이제부터가 진짜다!"', atk: 1.15, def: 0.85 }],
    weak: ['holy'], resist: ['ice'], sprite: 'vorg',
  },
  demon_king: {
    name: '마왕 자르가스', hp: 5500, mp: 999, atk: 77, def: 82, mag: 36, spd: 30, exp: 0, gold: 0,
    drops: [], boss: true, immune: BOSS_IMMUNE, actions: 2,
    skills: [{ id: 'attack', w: 3 }, { id: 'dark_flare', w: 2 }, { id: 'dark_bolt', w: 2 }, { id: 'abyss_gaze', w: 1 }, { id: 'doom_slash', w: 1 }],
    phases: [{ hpBelow: 0.5, text: '{a은} 분노했다! 어둠의 힘이 폭주한다!', atk: 1.25, clearDebuffs: true }],
    weak: ['holy'], resist: ['fire', 'ice'], sprite: 'demon_king',
  },
  demon_king_true: {
    name: '진·마왕 자르가스', hp: 6000, mp: 999, atk: 58, def: 86, mag: 36, spd: 32, exp: 0, gold: 0,
    drops: [], boss: true, immune: BOSS_IMMUNE, actions: 2,
    skills: [{ id: 'attack', w: 3 }, { id: 'hellfire', w: 2 }, { id: 'doom_slash', w: 2 }, { id: 'dark_nova', w: 1 }, { id: 'charge', w: 1 }],
    phases: [
      { hpBelow: 0.5, text: '{a은} 울부짖었다! 붉은 달이 핏빛으로 타오른다!', atk: 1.2, skills: [{ id: 'attack', w: 3 }, { id: 'hellfire', w: 2 }, { id: 'doom_slash', w: 2 }, { id: 'dark_flare', w: 1 }] },
    ],
    weak: ['holy'], resist: ['fire', 'ice'], sprite: 'demon_king_true',
  },
};
