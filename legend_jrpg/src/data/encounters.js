// 인카운터 테이블 (battle-dev). rate = 걸음당 조우 확률. 형식은 docs/CONTRACTS.md §7.
export const ENCOUNTERS = {
  forest: {
    rate: 0.06,
    troops: [
      { troop: 'troop_forest_1', weight: 3 }, { troop: 'troop_forest_2', weight: 3 },
      { troop: 'troop_forest_3', weight: 3 }, { troop: 'troop_forest_4', weight: 2 },
      { troop: 'troop_forest_5', weight: 2 }, { troop: 'troop_forest_6', weight: 2 },
      { troop: 'troop_forest_7', weight: 2 }, { troop: 'troop_forest_8', weight: 1 },
    ],
  },
  plains: {
    rate: 0.05,
    troops: [
      { troop: 'troop_plains_1', weight: 3 }, { troop: 'troop_plains_2', weight: 3 },
      { troop: 'troop_plains_3', weight: 2 }, { troop: 'troop_plains_4', weight: 2 },
      { troop: 'troop_plains_5', weight: 2 }, { troop: 'troop_plains_6', weight: 1 },
    ],
  },
  cave: {
    rate: 0.07,
    troops: [
      { troop: 'troop_cave_1', weight: 3 }, { troop: 'troop_cave_2', weight: 3 },
      { troop: 'troop_cave_3', weight: 3 }, { troop: 'troop_cave_4', weight: 2 },
      { troop: 'troop_cave_5', weight: 2 }, { troop: 'troop_cave_6', weight: 2 },
    ],
  },
  tower: {
    rate: 0.07,
    troops: [
      { troop: 'troop_tower_1', weight: 3 }, { troop: 'troop_tower_2', weight: 3 },
      { troop: 'troop_tower_3', weight: 3 }, { troop: 'troop_tower_4', weight: 2 },
      { troop: 'troop_tower_5', weight: 2 }, { troop: 'troop_tower_6', weight: 1 },
    ],
  },
  wasteland: {
    rate: 0.06,
    troops: [
      { troop: 'troop_waste_1', weight: 3 }, { troop: 'troop_waste_2', weight: 3 },
      { troop: 'troop_waste_3', weight: 3 }, { troop: 'troop_waste_4', weight: 2 },
      { troop: 'troop_waste_5', weight: 2 }, { troop: 'troop_waste_6', weight: 2 },
    ],
  },
  castle: {
    rate: 0.07,
    troops: [
      { troop: 'troop_castle_1', weight: 3 }, { troop: 'troop_castle_2', weight: 3 },
      { troop: 'troop_castle_3', weight: 2 }, { troop: 'troop_castle_4', weight: 2 },
      { troop: 'troop_castle_5', weight: 2 }, { troop: 'troop_castle_6', weight: 2 },
    ],
  },
};

// 가중치 추첨 헬퍼 (필드 담당이 써도 됨)
export function rollEncounter(key) {
  const t = ENCOUNTERS[key];
  if (!t) return null;
  const total = t.troops.reduce((s, x) => s + x.weight, 0);
  let r = Math.random() * total;
  for (const x of t.troops) { r -= x.weight; if (r <= 0) return x.troop; }
  return t.troops[t.troops.length - 1].troop;
}
