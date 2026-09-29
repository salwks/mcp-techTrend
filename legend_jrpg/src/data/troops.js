// 적 그룹 데이터 (battle-dev). 형식은 docs/CONTRACTS.md §7.
// boss:true → 도주 불가, 보스 BGM. bgm 지정 시 그 BGM(전투 씬 params.bgm이 우선).
// quickEnd:true → 승리 팡파레/보상 메시지 없이 바로 끝남(연속 보스전 연출용)
export const TROOPS = {
  // ---------- 스토리 고정 ----------
  troop_tutorial: { enemies: ['slime', 'slime'] },
  boss_goblin_chief: { enemies: ['goblin_chief'], boss: true, bgm: 'boss' },
  troop_mia_rescue: { enemies: ['wolf', 'wolf'] },
  boss_treant: { enemies: ['treant'], boss: true, bgm: 'boss' },
  boss_sea_serpent: { enemies: ['sea_serpent'], boss: true, bgm: 'boss' },
  boss_lich: { enemies: ['skeleton', 'lich', 'skeleton'], boss: true, bgm: 'boss' },
  boss_black_dragon: { enemies: ['black_dragon'], boss: true, bgm: 'boss' },
  boss_general_vorg: { enemies: ['vorg'], boss: true, bgm: 'boss' },
  boss_demon_king: { enemies: ['demon_king'], boss: true, bgm: 'final_boss', quickEnd: true },
  boss_demon_king_true: { enemies: ['demon_king_true'], boss: true, bgm: 'final_boss' },

  // ---------- 숲 ----------
  troop_forest_1: { enemies: ['slime', 'slime'] },
  troop_forest_2: { enemies: ['wolf', 'slime'] },
  troop_forest_3: { enemies: ['goblin', 'slime'] },
  troop_forest_4: { enemies: ['mushroom', 'mushroom'] },
  troop_forest_5: { enemies: ['bee', 'bee'] },
  troop_forest_6: { enemies: ['wolf', 'wolf'] },
  troop_forest_7: { enemies: ['goblin', 'bee'] },
  troop_forest_8: { enemies: ['mushroom', 'goblin', 'slime'] },

  // ---------- 들판 ----------
  troop_plains_1: { enemies: ['red_slime', 'red_slime'] },
  troop_plains_2: { enemies: ['boar'] },
  troop_plains_3: { enemies: ['bird', 'bird'] },
  troop_plains_4: { enemies: ['goblin_warrior', 'goblin'] },
  troop_plains_5: { enemies: ['boar', 'red_slime'] },
  troop_plains_6: { enemies: ['wolf', 'wolf', 'wolf'] },

  // ---------- 해안 동굴 ----------
  troop_cave_1: { enemies: ['bat', 'bat', 'bat'] },
  troop_cave_2: { enemies: ['crab', 'jellyfish'] },
  troop_cave_3: { enemies: ['skeleton', 'skeleton'] },
  troop_cave_4: { enemies: ['sahuagin', 'jellyfish'] },
  troop_cave_5: { enemies: ['sahuagin', 'bat', 'bat'] },
  troop_cave_6: { enemies: ['crab', 'skeleton'] },

  // ---------- 별빛의 탑 ----------
  troop_tower_1: { enemies: ['gargoyle', 'gargoyle'] },
  troop_tower_2: { enemies: ['ghost', 'book'] },
  troop_tower_3: { enemies: ['skeleton_knight', 'ghost'] },
  troop_tower_4: { enemies: ['book', 'book', 'ghost'] },
  troop_tower_5: { enemies: ['golem'] },
  troop_tower_6: { enemies: ['golem', 'book'] },

  // ---------- 잿빛 황야 ----------
  troop_waste_1: { enemies: ['scorpion', 'scorpion'] },
  troop_waste_2: { enemies: ['salamander', 'ghoul'] },
  troop_waste_3: { enemies: ['wyvern'] },
  troop_waste_4: { enemies: ['ogre', 'ghoul'] },
  troop_waste_5: { enemies: ['ghoul', 'ghoul', 'scorpion'] },
  troop_waste_6: { enemies: ['wyvern', 'salamander'] },

  // ---------- 마왕성 ----------
  troop_castle_1: { enemies: ['dark_knight', 'dark_knight'] },
  troop_castle_2: { enemies: ['imp', 'imp', 'imp'] },
  troop_castle_3: { enemies: ['chimera'] },
  troop_castle_4: { enemies: ['living_armor', 'imp'] },
  troop_castle_5: { enemies: ['archdemon', 'imp'] },
  troop_castle_6: { enemies: ['dark_knight', 'chimera'] },
};
