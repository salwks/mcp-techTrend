// 아이템 데이터 (battle-dev). 형식은 docs/CONTRACTS.md §7.
// effect.kind: heal(HP 회복, amount 9999=완전 회복, mp=동시 MP 회복), mp, cure(status: 'poison'|'all'),
//              revive(amount<=1 이면 최대 HP 비율), damage(element 속성 피해), healAll
export const ITEMS = {
  // ---------------- 소비 아이템 ----------------
  herb: { name: '약초', desc: 'HP를 30 회복한다', price: 8, type: 'consumable', effect: { kind: 'heal', amount: 30 }, target: 'ally', usable: 'both' },
  potion: { name: '회복약', desc: 'HP를 80 회복한다', price: 30, type: 'consumable', effect: { kind: 'heal', amount: 80 }, target: 'ally', usable: 'both' },
  hi_potion: { name: '하이포션', desc: 'HP를 250 회복한다', price: 110, type: 'consumable', effect: { kind: 'heal', amount: 250 }, target: 'ally', usable: 'both' },
  elixir: { name: '엘릭서', desc: 'HP와 MP를 모두 회복한다', price: 600, type: 'consumable', effect: { kind: 'heal', amount: 9999, mp: 9999 }, target: 'ally', usable: 'both' },
  ether: { name: '에테르', desc: 'MP를 30 회복한다', price: 90, type: 'consumable', effect: { kind: 'mp', amount: 30 }, target: 'ally', usable: 'both' },
  hi_ether: { name: '하이에테르', desc: 'MP를 80 회복한다', price: 260, type: 'consumable', effect: { kind: 'mp', amount: 80 }, target: 'ally', usable: 'both' },
  antidote: { name: '해독초', desc: '독을 치료한다', price: 10, type: 'consumable', effect: { kind: 'cure', status: 'poison' }, target: 'ally', usable: 'both' },
  panacea: { name: '만능약', desc: '모든 상태이상을 치료한다', price: 60, type: 'consumable', effect: { kind: 'cure', status: 'all' }, target: 'ally', usable: 'both' },
  phoenix_feather: { name: '불사조의 깃털', desc: '쓰러진 동료를 HP 절반으로 되살린다', price: 300, type: 'consumable', effect: { kind: 'revive', amount: 0.5 }, target: 'ally', usable: 'both' },
  fire_bomb: { name: '화염탄', desc: '적 전체에 불 속성 피해 약 80', price: 80, type: 'consumable', effect: { kind: 'damage', amount: 80, element: 'fire' }, target: 'allEnemies', usable: 'battle' },

  // ---------------- 무기: 렌 (이벤트 전용) ----------------
  sealed_sword: { name: '봉인된 성검', desc: '녹슨 듯 빛을 잃은 성검', price: 0, type: 'weapon', bonus: { atk: 6 }, equipBy: ['ren'] },
  awakened_sword: { name: '깨어난 성검', desc: '빛을 되찾기 시작한 성검', price: 0, type: 'weapon', bonus: { atk: 22, mag: 4 }, equipBy: ['ren'] },
  holy_sword: { name: '성검 루미나스', desc: '완전히 해방된 빛의 성검', price: 0, type: 'weapon', bonus: { atk: 40, mag: 10, spd: 4 }, equipBy: ['ren'] },

  // ---------------- 무기: 미아 ----------------
  oak_staff: { name: '떡갈나무 지팡이', desc: '가벼운 나무 지팡이', price: 60, type: 'weapon', bonus: { atk: 3, mag: 3 }, equipBy: ['mia'] },
  silver_staff: { name: '은의 지팡이', desc: '성스러운 은으로 만든 지팡이', price: 380, type: 'weapon', bonus: { atk: 6, mag: 9 }, equipBy: ['mia'] },
  saint_staff: { name: '성녀의 지팡이', desc: '성녀가 쓰던 지팡이. 최대 MP 증가', price: 2200, type: 'weapon', bonus: { atk: 10, mag: 20, maxMp: 15 }, equipBy: ['mia'] },

  // ---------------- 무기: 가렌 ----------------
  iron_spear: { name: '철창', desc: '기사단 표준 창', price: 150, type: 'weapon', bonus: { atk: 14 }, equipBy: ['garen'] },
  steel_spear: { name: '강철창', desc: '단단한 강철로 벼린 창', price: 850, type: 'weapon', bonus: { atk: 24 }, equipBy: ['garen'] },
  dragon_spear: { name: '용창 게이볼그', desc: '용의 비늘도 꿰뚫는 창', price: 2600, type: 'weapon', bonus: { atk: 42, def: 4 }, equipBy: ['garen'] },

  // ---------------- 무기: 셀라 ----------------
  magic_rod: { name: '마도봉', desc: '마력을 모으는 지팡이', price: 200, type: 'weapon', bonus: { atk: 4, mag: 10 }, equipBy: ['sela'] },
  star_rod: { name: '별의 지팡이', desc: '별빛이 깃든 마법 지팡이', price: 1100, type: 'weapon', bonus: { atk: 6, mag: 18 }, equipBy: ['sela'] },
  archmage_rod: { name: '대마도사의 지팡이', desc: '전설의 대마도사가 쓰던 지팡이', price: 2800, type: 'weapon', bonus: { atk: 8, mag: 32, maxMp: 20 }, equipBy: ['sela'] },

  // ---------------- 방어구 ----------------
  travel_clothes: { name: '여행자의 옷', desc: '튼튼한 천옷', price: 20, type: 'armor', bonus: { def: 3 } },
  leather_armor: { name: '가죽 갑옷', desc: '무두질한 가죽 갑옷', price: 90, type: 'armor', bonus: { def: 7 }, equipBy: ['ren', 'garen'] },
  chain_mail: { name: '사슬 갑옷', desc: '쇠사슬을 엮은 갑옷', price: 480, type: 'armor', bonus: { def: 14 }, equipBy: ['ren', 'garen'] },
  silver_mail: { name: '은빛 갑옷', desc: '가볍고 튼튼한 은 갑옷', price: 1100, type: 'armor', bonus: { def: 24 }, equipBy: ['ren', 'garen'] },
  mithril_mail: { name: '미스릴 갑옷', desc: '전설의 금속 미스릴 갑옷', price: 2500, type: 'armor', bonus: { def: 36, spd: 3 }, equipBy: ['ren', 'garen'] },
  cloth_robe: { name: '천 로브', desc: '마법사용 천 로브', price: 40, type: 'armor', bonus: { def: 3, mag: 1 }, equipBy: ['mia', 'sela', 'ren'] },
  silk_robe: { name: '비단 로브', desc: '마력이 깃든 비단 로브', price: 420, type: 'armor', bonus: { def: 8, mag: 4 }, equipBy: ['mia', 'sela', 'ren'] },
  sage_robe: { name: '현자의 로브', desc: '현자의 가호가 깃든 로브', price: 1000, type: 'armor', bonus: { def: 16, mag: 8, maxMp: 10 }, equipBy: ['mia', 'sela', 'ren'] },

  // ---------------- 장신구 ----------------
  power_ring: { name: '힘의 반지', desc: '공격력이 오른다', price: 600, type: 'accessory', bonus: { atk: 8 } },
  guard_ring: { name: '수호의 반지', desc: '방어력이 오른다', price: 600, type: 'accessory', bonus: { def: 8 } },
  speed_boots: { name: '질풍의 장화', desc: '민첩성이 크게 오른다', price: 900, type: 'accessory', bonus: { spd: 10 } },
  magic_earring: { name: '마력의 귀걸이', desc: '마력과 최대 MP가 오른다', price: 900, type: 'accessory', bonus: { mag: 10, maxMp: 15 } },
  angel_charm: { name: '천사의 부적', desc: '독·수면·기절을 막아 준다', price: 2000, type: 'accessory', bonus: { def: 10, maxHp: 30 }, guard: ['poison', 'sleep', 'stun'] },
};
