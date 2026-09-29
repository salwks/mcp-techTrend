// 스텁 — battle-dev가 GDD §3의 전체 아이템 목록으로 교체한다. 형식은 docs/CONTRACTS.md §7.
export const ITEMS = {
  herb: { name: '약초', desc: 'HP를 30 회복한다', price: 8, type: 'consumable', effect: { kind: 'heal', amount: 30 }, target: 'ally', usable: 'both' },
  sealed_sword: { name: '봉인된 성검', desc: '녹슨 듯 빛을 잃은 성검', price: 0, type: 'weapon', bonus: { atk: 6 }, equipBy: ['ren'] },
  travel_clothes: { name: '여행자의 옷', desc: '튼튼한 천옷', price: 20, type: 'armor', bonus: { def: 3 } },
  oak_staff: { name: '떡갈나무 지팡이', desc: '', price: 60, type: 'weapon', bonus: { atk: 3, mag: 3 }, equipBy: ['mia'] },
  cloth_robe: { name: '천 로브', desc: '', price: 40, type: 'armor', bonus: { def: 3, mag: 1 }, equipBy: ['mia', 'sela', 'ren'] },
  iron_spear: { name: '철창', desc: '', price: 0, type: 'weapon', bonus: { atk: 14 }, equipBy: ['garen'] },
  chain_mail: { name: '사슬 갑옷', desc: '', price: 0, type: 'armor', bonus: { def: 12 }, equipBy: ['ren', 'garen'] },
  magic_rod: { name: '마도봉', desc: '', price: 0, type: 'weapon', bonus: { atk: 4, mag: 10 }, equipBy: ['sela'] },
  silk_robe: { name: '비단 로브', desc: '', price: 0, type: 'armor', bonus: { def: 8, mag: 4 }, equipBy: ['mia', 'sela', 'ren'] },
};
