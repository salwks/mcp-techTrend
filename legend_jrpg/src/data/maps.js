// 맵 데이터 (world-designer 소유) — 형식은 docs/CONTRACTS.md §8 참고
// 새 게임 시작 위치: village (10,10) — 렌의 집 앞. 오프닝은 village.onEnter(evt_village_enter)에서 시작.
// 상자 열림 플래그: chest_<mapId>_<id>
export const MAPS = {
  village: {
    name: "루멘 마을", bgm: 'village', battleBg: 'village', encounter: null, dark: false,
    // 32x24
    tiles: [
      'TTTTTTTTTTTTTTT,,TTTTTTTTTTTTTTT', // 0
      'TT.............,,.............TT', // 1
      'T...T..........,,...FF.........T', // 2
      'T........F.....,,..........T...T', // 3
      'T....F.........,,..RRRRRRR.....T', // 4
      'T..............,,..RRRRRRR.....T', // 5
      'T......RRRRRR..,,..RRRRRRR.....T', // 6
      'T......RRRRRR..,,..HHHDHHH...T.T', // 7
      'T.T....RRRRRR..,,.....,........T', // 8
      'T......HHHDHH..,,.....,..FF....T', // 9
      'T.........,....,,.....,........T', // 10
      'T..,,,,,,,,,,,,,,,,,,,,,,,,,,,,,', // 11
      'T..............,,..............T', // 12
      'T.TRRRRRRR.....,,...RRRRRRR..T.T', // 13
      'T..H=====H.....,,...H=====H.T..T', // 14
      'T..HHcccHH.....,,...HHcccHH....T', // 15
      'T....,,,,,,,,,,,,,,,,,,,,,,,...T', // 16
      'T..............,,..............T', // 17
      'T.fffff......w.,,.........~~~..T', // 18
      'T.FFFFF........,,..F.F...~~~~~.T', // 19
      'T..FFF.........,,.........~~~T.T', // 20
      'T............TT...TT...........T', // 21
      'TT............................TT', // 22
      'TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT', // 23
    ],
    npcs: [
      {id: "lina", x: 12, y: 10, sprite: "lina", name: "리나", dir: "left", event: "evt_lina"},
      {id: "elder", x: 22, y: 8, sprite: "elder", name: "오웬 장로", dir: "down", event: "evt_elder"},
      {id: "innkeeper", x: 6, y: 14, sprite: "innkeeper", name: "여관 주인", dir: "down", event: "evt_village_inn"},
      {id: "merchant", x: 23, y: 14, sprite: "merchant", name: "도구점 주인", dir: "down", event: "evt_village_shop"},
      {id: "farmer", x: 27, y: 10, sprite: "villager_m", name: "농부 톰", dir: "down", event: "evt_village_farmer"},
      {id: "wife", x: 24, y: 21, sprite: "villager_f", name: "마을 아주머니", dir: "up", wander: true, event: "evt_village_wife"},
      {id: "kid", x: 7, y: 20, sprite: "child", name: "꼬마 핀", dir: "down", wander: true, event: "evt_village_kid"},
      {id: "grandpa", x: 3, y: 5, sprite: "old_man", name: "할아버지", dir: "right", event: "evt_village_grandpa"},
      {id: "watch", x: 17, y: 2, sprite: "soldier", name: "자경단원", dir: "down", event: "evt_village_watch"},
      {id: "cat", x: 12, y: 18, sprite: "cat", name: "고양이", dir: "down", wander: true, lines: ["냐아옹~","(고양이가 렌의 다리에 몸을 비비고 있다.)"]},
    ],
    triggers: [],
    exits: [
      {x: 15, y: 0, w: 2, h: 1, to: "shrine", tx: 9, ty: 14, dir: "up"},
      {x: 31, y: 11, w: 1, h: 1, to: "forest", tx: 1, ty: 12, dir: "right"},
    ],
    chests: [
      {id: "c1", x: 1, y: 3, item: "herb", count: 2},
    ],
    objects: [
      {x: 18, y: 10, sprite: "save_crystal", event: "evt_save_crystal"},
      {x: 14, y: 1, sprite: "sign", lines: ["↑ 북쪽: 루멘 사당\n마을의 수호신과 오래된 검이 모셔져 있다."]},
      {x: 30, y: 10, sprite: "sign", lines: ["→ 동쪽: 속삭임의 숲\n숲을 지나면 항구도시 벨포트."]},
      {x: 4, y: 12, sprite: "sign", lines: ["「해바라기 여관」\n하룻밤 10G. 따뜻한 수프 포함!"]},
      {x: 25, y: 12, sprite: "sign", lines: ["「루멘 도구점」\n약초부터 옷가지까지."]},
    ],
    onEnter: 'evt_village_enter',
  },
  shrine: {
    name: "루멘 사당", bgm: 'sad', battleBg: 'shrine', encounter: null, dark: false,
    // 20x16
    tiles: [
      '####################', // 0
      '#__bb____AA____bb__#', // 1
      '#________KK________#', // 2
      '#_P______KK______P_#', // 3
      '#________KK________#', // 4
      '#_P______KK______P_#', // 5
      '#________KK________#', // 6
      '#_P______KK______P_#', // 7
      '#________KK________#', // 8
      '#_P______KK______P_#', // 9
      '#________KK________#', // 10
      '#_P______KK______P_#', // 11
      '#________KK________#', // 12
      '#________KK________#', // 13
      '#________KK________#', // 14
      '#########KK#########', // 15
    ],
    npcs: [
      {id: "goblin_chief", x: 3, y: 13, sprite: "goblin", name: "고블린 대장", dir: "right",showIf: "village_attacked",hideIf: "hero_awakened", lines: ["크르르...!"]},
      {id: "keeper", x: 5, y: 7, sprite: "priest", name: "사당지기", dir: "down",showIf: "elder_briefed", event: "evt_shrine_keeper"},
    ],
    triggers: [],
    exits: [
      {x: 9, y: 15, w: 2, h: 1, to: "village", tx: 15, ty: 1, dir: "down"},
    ],
    chests: [
      {id: "c1", x: 1, y: 13, item: "potion", count: 2},
    ],
    objects: [
      {x: 12, y: 2, sprite: "sign", lines: ["「빛을 이을 자, 붉은 달 아래 검을 들리라」\n——제단에 새겨진 오래된 글귀"]},
    ],
    onEnter: 'evt_shrine_enter',
  },
  forest: {
    name: "속삭임의 숲", bgm: 'forest', battleBg: 'forest', encounter: 'forest', dark: false,
    // 36x24
    tiles: [
      'TTTTTTTTTTTTTTTTTTTTTTTTTT~TTTTTTTTT', // 0
      'TTTTTTTTTTTTT.........TTTT~TTTTT...T', // 1
      'TTTTTTTTTTTTT..FF.....TTTT~TTTTT...T', // 2
      'TTTTTTTTT...T.........,,,,B,,,,,...T', // 3
      'TTTTTTTTT.,.,.............B.....TTTT', // 4
      'TTTTTTTTT.,.T.F.......TTTT~TTT.,.TTT', // 5
      'TTTTTTTTT.,.T......FF.TTTT~TTT.,.TTT', // 6
      'TTTTTTTTT.,.T.........TTTT~TTT.,.TTT', // 7
      'TTTTTTTTT.,.TTTTTTTTTTTTTT~TTT.,.TTT', // 8
      'TTTTTTTTT.,.TTTTTTTTTTTTTT~TTT.,.TTT', // 9
      'TTTTTTTTT.,.TTTTTTTTTTTTTT~TTT.,.TTT', // 10
      '..........,.TTTTTTTTTTTTTT........TT', // 11
      ',,,,,,,,,,,.........TTTTTT........TT', // 12
      '...........TTTTTT...TTTTTT...T....TT', // 13
      'TTT...TTTTTTTTTTT...TTTTTT........,,', // 14
      'TTT...TTTTTTTTTTT...TTTTTT........TT', // 15
      'TTT...TTTTTTTT~~~BBB~~~~TT.FF...T.TT', // 16
      'TTT...TTTTTTTTTTT...TTTTTT........TT', // 17
      'TTT...TTTTTTTTTTT...TTTTTTTTTTTTTTTT', // 18
      'T.......TTTTTTTTT...TTTTTTTTTTTTTTTT', // 19
      'T.......TTTTTTTT.....TTTTTTTTTTTTTTT', // 20
      'T.......TTTTTTTT.....TTTTTTTTTTTTTTT', // 21
      'TTTTTTTTTTTTTTTTFF...TTTTTTTTTTTTTTT', // 22
      'TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT', // 23
    ],
    npcs: [
      {id: "mia", x: 18, y: 4, sprite: "mia", name: "미아", dir: "left",hideIf: "mia_joined", event: "evt_mia_rescue"},
      {id: "wolf1", x: 17, y: 3, sprite: "wolf", name: "늑대", dir: "right",hideIf: "mia_rescued", lines: ["그르르르...!"]},
      {id: "wolf2", x: 19, y: 3, sprite: "wolf", name: "늑대", dir: "left",hideIf: "mia_rescued", lines: ["그르르르...!"]},
      {id: "wolf3", x: 17, y: 5, sprite: "wolf", name: "늑대", dir: "right",hideIf: "mia_rescued", lines: ["크르릉!"]},
      {id: "hermit", x: 6, y: 20, sprite: "old_man", name: "숲의 은자", dir: "left", event: "evt_forest_hermit"},
      {id: "treant", x: 34, y: 14, sprite: "monster", name: "트렌트", dir: "left",hideIf: "treant_defeated", event: "evt_treant"},
    ],
    triggers: [
      {x: 12, y: 4, w: 1, h: 1, event: "evt_mia_rescue",hideIf: "mia_joined"},
      {x: 33, y: 14, w: 1, h: 1, event: "evt_treant",hideIf: "treant_defeated"},
    ],
    exits: [
      {x: 0, y: 11, w: 1, h: 3, to: "village", tx: 30, ty: 11, dir: "left"},
      {x: 35, y: 14, w: 1, h: 1, to: "port", tx: 1, ty: 12, dir: "right"},
    ],
    chests: [
      {id: "c1", x: 2, y: 20, item: "antidote", count: 2},
      {id: "c2", x: 19, y: 22, item: "leather_armor", count: 1},
      {id: "c3", x: 34, y: 1, item: "ether", count: 1},
      {id: "c4", x: 14, y: 1, item: "herb", count: 3},
      {id: "c5", x: 33, y: 17, item: "potion", count: 2},
      {id: "c6", x: 16, y: 21, gold: 80},
    ],
    objects: [
      {x: 8, y: 11, sprite: "sign", lines: ["속삭임의 숲\n→ 동쪽으로 계속 가면 항구도시 벨포트"]},
      {x: 28, y: 12, sprite: "save_crystal", event: "evt_heal_crystal"},
    ],
    onEnter: null,
  },
  port: {
    name: "항구도시 벨포트", bgm: 'town', battleBg: 'plains', encounter: null, dark: false,
    // 34x26
    tiles: [
      'TTTTTTTTTTTTTTTT,TTTTTTTTTTTTTTTTM', // 0
      'Tfffffffffffffff_ffffffffffffffffM', // 1
      'T...............__...........MMMMM', // 2
      'T..RRRRRRRR.FFF.__...RRRRRRR.MMMMM', // 3
      'T..RRRRRRRR.....__...RRRRRRR.MMMMM', // 4
      'T..RRRRRRRR.....__...H=====H.MMMMM', // 5
      'T..HHHDHHHH.....__...HHcccHH.MMMMM', // 6
      'T.....,.........__,,,,,,,,,,,,,,,,', // 7
      'T.....,.........__...........MMMMM', // 8
      'T.T...,.....w...__...........MMMMM', // 9
      'T.....,.........__........FF.MMMMM', // 10
      'T.....,.........__...........MMMMM', // 11
      '_________________________________M', // 12
      'T...............__...............M', // 13
      'T..RRRRRRR......__...RRRRRRR.....M', // 14
      'T..H=====H......__...H=====H.....M', // 15
      'T..HHcccHH......__...HHcccHH.....M', // 16
      'TT...........T..__............T..M', // 17
      'T...............__...............M', // 18
      'TSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSM', // 19
      '~~~~~~~~==~~~~~~~~~~~~~~==~~~~~~~~', // 20
      '~~~~~~~~==~~~~~~~~~~~~~~==~~~~~~~~', // 21
      '~~~~~~~~==~~~~~~~~~~~~~~==~~~~~~~~', // 22
      '~~~~~~~~==~~~~~~~~~~~~~~==~~~~~~~~', // 23
      '~~~~~~~~~~~~~~~~~~~~~~~~==~~~~~~~~', // 24
      '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~', // 25
    ],
    npcs: [
      {id: "gate_guard", x: 16, y: 1, sprite: "soldier", name: "북문 경비병", dir: "down",hideIf: "sword_awakened", event: "evt_port_gate_guard"},
      {id: "gate_guard2", x: 15, y: 2, sprite: "soldier", name: "경비병", dir: "down", event: "evt_port_guard2"},
      {id: "cave_guard", x: 31, y: 7, sprite: "soldier", name: "해안 경비병", dir: "left",hideIf: "garen_joined", event: "evt_cave_guard"},
      {id: "garen", x: 25, y: 23, sprite: "garen", name: "고독한 기사", dir: "down",hideIf: "garen_joined", event: "evt_garen"},
      {id: "item_shop", x: 24, y: 5, sprite: "merchant", name: "도구점 주인", dir: "down", event: "evt_port_item_shop"},
      {id: "arms_shop", x: 6, y: 15, sprite: "merchant", name: "무기점 주인", dir: "down", event: "evt_port_arms_shop"},
      {id: "dorman", x: 24, y: 15, sprite: "blacksmith", name: "도르만", dir: "down", event: "evt_dorman"},
      {id: "sailor1", x: 9, y: 23, sprite: "sailor", name: "늙은 선원", dir: "down", event: "evt_port_sailor1"},
      {id: "sailor2", x: 20, y: 18, sprite: "sailor", name: "젊은 선원", dir: "down", wander: true, event: "evt_port_sailor2"},
      {id: "lady", x: 13, y: 10, sprite: "villager_f", name: "생선 가게 아주머니", dir: "down", event: "evt_port_lady"},
      {id: "kid", x: 20, y: 10, sprite: "child", name: "항구 꼬마", dir: "down", wander: true, event: "evt_port_kid"},
      {id: "priest", x: 27, y: 13, sprite: "priest", name: "순례 사제", dir: "left", event: "evt_port_priest"},
      {id: "cat", x: 10, y: 18, sprite: "cat", name: "항구 고양이", dir: "down", wander: true, lines: ["냐~앙. (생선 냄새가 난다.)"]},
    ],
    triggers: [],
    exits: [
      {x: 16, y: 0, w: 1, h: 1, to: "plains", tx: 15, ty: 20, dir: "up"},
      {x: 0, y: 12, w: 1, h: 1, to: "forest", tx: 33, ty: 14, dir: "left"},
      {x: 33, y: 7, w: 1, h: 1, to: "cave", tx: 1, ty: 4, dir: "right"},
      {x: 6, y: 6, w: 1, h: 1, to: "port_inn", tx: 6, ty: 8, dir: "up"},
    ],
    chests: [
      {id: "c1", x: 1, y: 18, item: "phoenix_feather", count: 1},
    ],
    objects: [
      {x: 19, y: 11, sprite: "save_crystal", event: "evt_save_crystal"},
      {x: 18, y: 2, sprite: "sign", lines: ["↑ 북문 — 별빛 평원\n(영주의 명으로 봉쇄 중)"]},
      {x: 28, y: 6, sprite: "sign", lines: ["→ 해안 동굴\n위험! 관계자 외 출입 금지"]},
      {x: 7, y: 7, sprite: "sign", lines: ["여관 「갈매기 둥지」"]},
      {x: 27, y: 17, sprite: "sign", lines: ["도르만 대장간\n「두드리면 뭐든 된다」"]},
    ],
    onEnter: 'evt_port_enter',
  },
  port_inn: {
    name: "여관 「갈매기 둥지」", bgm: 'town', battleBg: 'plains', encounter: null, dark: false,
    // 14x10
    tiles: [
      'HHHHHHHHHHHHHH', // 0
      'Hbbb=======bbH', // 1
      'H============H', // 2
      'Hcccc===cc===H', // 3
      'H============H', // 4
      'H============H', // 5
      'H=======cc===H', // 6
      'H============H', // 7
      'H============H', // 8
      'HHHHHHDHHHHHHH', // 9
    ],
    npcs: [
      {id: "innkeeper", x: 2, y: 2, sprite: "innkeeper", name: "여관 주인", dir: "down", event: "evt_port_inn"},
      {id: "drunk", x: 10, y: 3, sprite: "sailor", name: "술 취한 선원", dir: "left", event: "evt_port_drunk"},
      {id: "mage", x: 10, y: 6, sprite: "mage", name: "떠돌이 마법사", dir: "left", event: "evt_port_mage"},
      {id: "oldman", x: 12, y: 7, sprite: "old_man", name: "은퇴한 선장", dir: "left", event: "evt_port_captain"},
    ],
    triggers: [],
    exits: [
      {x: 6, y: 9, w: 1, h: 1, to: "port", tx: 6, ty: 7, dir: "down"},
    ],
    chests: [],
    objects: [],
    onEnter: null,
  },
  cave: {
    name: "해안 동굴", bgm: 'dungeon', battleBg: 'cave', encounter: 'cave', dark: true,
    // 34x26
    tiles: [
      '##################################', // 0
      '#############################CCCC#', // 1
      '#CCCCCC########CCCCCC########CCCC#', // 2
      '#CCCCCC########CCCCCCCCCCCCCCCCCC#', // 3
      'CCCCCCCCCCCCCCCCCCCCC########CCCC#', // 4
      '#CCCCCC########CCCCCC########CCCC#', // 5
      '#CCCCCC########CCCCCC#############', // 6
      '###############CCCCCC#############', // 7
      '#################C################', // 8
      '#################C################', // 9
      '#################C##########CCCCC#', // 10
      '#################C##########CCCCC#', // 11
      '#################C##########CCCCC#', // 12
      '#################C##########CCCCC#', // 13
      '############CCCCCCCCCCCC####CCCCC#', // 14
      '####CCCCCCCCCC~~CCCCCCCC####CCCCC#', // 15
      '##CCCCC#####CC~~CCCC~~CCCCCCCCCCC#', // 16
      '##CCCCC#####CCCCCCCCCCCC######C###', // 17
      '##CCCCC###################CCCCCCC#', // 18
      '##CCC~C###################CCCCCCC#', // 19
      '##CCC~C###################CCCCCCC#', // 20
      '##CCCCC###################CCCCCCC#', // 21
      '##CCCCC###################~~~~~~~#', // 22
      '##########################~~~~~~~#', // 23
      '##################################', // 24
      '##################################', // 25
    ],
    npcs: [
      {id: "lost_sailor", x: 16, y: 6, sprite: "sailor", name: "길 잃은 선원", dir: "right", event: "evt_cave_sailor"},
      {id: "serpent", x: 29, y: 20, sprite: "monster", name: "바다뱀", dir: "up",hideIf: "serpent_defeated", event: "evt_serpent"},
    ],
    triggers: [
      {x: 30, y: 17, w: 1, h: 1, event: "evt_serpent",hideIf: "serpent_defeated"},
    ],
    exits: [
      {x: 0, y: 4, w: 1, h: 1, to: "port", tx: 32, ty: 7, dir: "left"},
    ],
    chests: [
      {id: "c1", x: 19, y: 2, item: "potion", count: 3},
      {id: "c2", x: 32, y: 1, item: "phoenix_feather", count: 1},
      {id: "c3", x: 2, y: 22, item: "power_ring", count: 1},
      {id: "c4", x: 6, y: 16, item: "ether", count: 2},
      {id: "c5", x: 32, y: 15, item: "antidote", count: 3},
      {id: "c6", x: 32, y: 19, item: "guard_ring", count: 1},
      {id: "c7", x: 23, y: 14, gold: 300},
    ],
    objects: [
      {x: 30, y: 11, sprite: "save_crystal", event: "evt_heal_crystal"},
    ],
    onEnter: 'evt_cave_enter',
  },
  plains: {
    name: "별빛 평원", bgm: 'field', battleBg: 'plains', encounter: 'plains', dark: false,
    // 30x22
    tiles: [
      'TTTTTT,TTTTTTTTTTTTTTTTTTTTTTM', // 0
      'TMMMMP,P............~.....MMMM', // 1
      'TMMMM.,.............~.....MMMM', // 2
      'TMMMM.,...TT........~.....MMMM', // 3
      'TMMMM.,...TT.....TT.~.....MMMM', // 4
      'T.....,.............~.....MMMM', // 5
      'T.....,.............~.....MMMM', // 6
      'T.....,.............~.....MMMM', // 7
      'T.....,.............~.....MMMM', // 8
      'T.....,.............~.....MMMM', // 9
      'T.....,,,,,,,,,,,,,,B,,,,,,,,,', // 10
      'T..............,....~.....MMMM', // 11
      'T..............,....~.....MMMM', // 12
      'T..............,....~.....MMMM', // 13
      'T.......FFFF...,....~.....MMMM', // 14
      'T.......FFFF...,....~.FFF.MMMM', // 15
      'T.TT...........,....~.FFF.MMMM', // 16
      'T..............,....~.....MMMM', // 17
      'T..............,....~.....MMMM', // 18
      'T..............,....~.....MMMM', // 19
      'T..............,....~.....MMMM', // 20
      'TTTTTTTTTTTTTTT,TTTTTTTTTTTTTM', // 21
    ],
    npcs: [
      {id: "post_guard", x: 27, y: 10, sprite: "soldier", name: "초소 병사", dir: "left",hideIf: "tower_cleared", event: "evt_plains_guard"},
      {id: "post_guard2", x: 24, y: 9, sprite: "soldier", name: "초소 병사", dir: "down",showIf: "tower_cleared", event: "evt_plains_guard2"},
      {id: "traveler", x: 12, y: 11, sprite: "old_man", name: "방랑 시인", dir: "down", event: "evt_plains_traveler"},
    ],
    triggers: [],
    exits: [
      {x: 15, y: 21, w: 1, h: 1, to: "port", tx: 16, ty: 2, dir: "down"},
      {x: 6, y: 0, w: 1, h: 1, to: "tower", tx: 10, ty: 16, dir: "up"},
      {x: 29, y: 10, w: 1, h: 1, to: "wasteland", tx: 1, ty: 12, dir: "right"},
    ],
    chests: [
      {id: "c1", x: 2, y: 19, item: "potion", count: 3},
      {id: "c2", x: 24, y: 2, item: "ether", count: 2},
      {id: "c3", x: 24, y: 19, item: "star_rod", count: 1},
    ],
    objects: [
      {x: 7, y: 2, sprite: "sign", lines: ["↑ 별빛의 탑\n「별을 우러르는 자에게 길이 열리리」"]},
      {x: 16, y: 19, sprite: "sign", lines: ["↓ 항구도시 벨포트\n→ 동쪽 초소 / 잿빛 황야"]},
    ],
    onEnter: 'evt_plains_enter',
  },
  tower: {
    name: "별빛의 탑 1층", bgm: 'tower', battleBg: 'tower', encounter: 'tower', dark: false,
    // 22x18
    tiles: [
      '######################', // 0
      '#bbb_______________^_#', // 1
      '#____________________#', // 2
      '#_______######_______#', // 3
      '#_ccc________#_______#', // 4
      '#____________#_______#', // 5
      '#____________#_______#', // 6
      '#____P__________P____#', // 7
      '#____________________#', // 8
      '#_________KK_________#', // 9
      '#_________KK_________#', // 10
      '#_________KK_________#', // 11
      '#____P____KK____P____#', // 12
      '#_________KK_________#', // 13
      '#_________KK_________#', // 14
      '#_________KK_________#', // 15
      '#_________KK_________#', // 16
      '##########KK##########', // 17
    ],
    npcs: [
      {id: "tower_merchant", x: 3, y: 3, sprite: "merchant", name: "떠돌이 상인", dir: "down", event: "evt_tower_shop"},
      {id: "scholar", x: 8, y: 12, sprite: "mage", name: "별 연구가", dir: "right", event: "evt_tower_scholar"},
    ],
    triggers: [],
    exits: [
      {x: 10, y: 17, w: 2, h: 1, to: "plains", tx: 6, ty: 1, dir: "down"},
      {x: 19, y: 1, w: 1, h: 1, to: "tower_2f", tx: 19, ty: 2, dir: "down"},
    ],
    chests: [
      {id: "c1", x: 1, y: 15, item: "phoenix_feather", count: 1},
      {id: "c2", x: 20, y: 15, item: "hi_potion", count: 2},
      {id: "c3", x: 12, y: 4, item: "silk_robe", count: 1},
    ],
    objects: [
      {x: 14, y: 14, sprite: "save_crystal", event: "evt_heal_crystal"},
    ],
    onEnter: 'evt_tower_enter',
  },
  tower_2f: {
    name: "별빛의 탑 2층", bgm: 'tower', battleBg: 'tower', encounter: 'tower', dark: false,
    // 22x18
    tiles: [
      '######################', // 0
      '#_^_______##_______^_#', // 1
      '#_________##_________#', // 2
      '#__#########___####__#', // 3
      '#__#########_________#', // 4
      '#__#########___####__#', // 5
      '#__###__________###__#', // 6
      '#__###__________###__#', // 7
      '#__###__P____P__###__#', // 8
      '#__###__________###__#', // 9
      '#__###__________###__#', // 10
      '#__#######__#######__#', // 11
      '#__#######__#######__#', // 12
      '#__#######__#######__#', // 13
      '#____________________#', // 14
      '#____________________#', // 15
      '######################', // 16
      '######################', // 17
    ],
    npcs: [
      {id: "sela", x: 6, y: 15, sprite: "sela", name: "보라색 로브의 소녀", dir: "right",hideIf: "sela_met", event: "evt_sela_meet"},
    ],
    triggers: [
      {x: 8, y: 14, w: 1, h: 2, event: "evt_sela_meet",hideIf: "sela_met"},
    ],
    exits: [
      {x: 19, y: 1, w: 1, h: 1, to: "tower", tx: 19, ty: 2, dir: "down"},
      {x: 2, y: 1, w: 1, h: 1, to: "tower_top", tx: 10, ty: 14, dir: "up"},
    ],
    chests: [
      {id: "c1", x: 7, y: 7, item: "hi_ether", count: 1},
      {id: "c2", x: 14, y: 10, item: "magic_earring", count: 1},
      {id: "c3", x: 12, y: 3, item: "hi_potion", count: 2},
      {id: "c4", x: 1, y: 13, gold: 500},
    ],
    objects: [],
    onEnter: null,
  },
  tower_top: {
    name: "별빛의 탑 정상", bgm: 'tower', battleBg: 'tower', encounter: null, dark: false,
    // 20x16
    tiles: [
      '####################', // 0
      '#________AA________#', // 1
      '#________KK________#', // 2
      '#__P_____KK_____P__#', // 3
      '#________KK________#', // 4
      '#________KK________#', // 5
      '#________KK________#', // 6
      '#________KK________#', // 7
      '#__P_____KK_____P__#', // 8
      '#________KK________#', // 9
      '#________KK________#', // 10
      '#________KK________#', // 11
      '#__P_____KK_____P__#', // 12
      '#________KK________#', // 13
      '#________KK________#', // 14
      '##########^#########', // 15
    ],
    npcs: [
      {id: "lich", x: 10, y: 4, sprite: "lich", name: "네크로스", dir: "down",hideIf: "lich_defeated", event: "evt_lich"},
      {id: "sela", x: 7, y: 6, sprite: "sela", name: "셀라", dir: "up",showIf: "sela_met",hideIf: "sela_joined", event: "evt_lich"},
    ],
    triggers: [
      {x: 1, y: 9, w: 18, h: 1, event: "evt_lich",hideIf: "lich_defeated"},
    ],
    exits: [
      {x: 10, y: 15, w: 1, h: 1, to: "tower_2f", tx: 2, ty: 2, dir: "down"},
    ],
    chests: [],
    objects: [
      {x: 13, y: 12, sprite: "save_crystal", event: "evt_heal_crystal"},
      {x: 9, y: 1, sprite: "sign", event: "evt_star_altar"},
    ],
    onEnter: null,
  },
  wasteland: {
    name: "잿빛 황야", bgm: 'field', battleBg: 'wasteland', encounter: 'wasteland', dark: false,
    // 36x24
    tiles: [
      'MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM', // 0
      'MXXXXXXXXXfXMXXXXXXXXXXXMXXXXMXXXXMM', // 1
      'MX,RR,,RR,fXMXXXXXXXXXXXMXXXXMXXXXMM', // 2
      'MX,,,,,,,,fXMXXXXXXXXtXXMXLLXMXXXXMM', // 3
      'MX,,,,,,,,fXMXtXXXXXXXXXMXLLXMXXXXMM', // 4
      'MX,,,,,,,,fXMXXXXXXXXXXXMXXXXMXXXXMM', // 5
      'MX,,,,,,,,fXMXXXXXXXXXXXMXXXXMXXXXMM', // 6
      'MX,,,,,,,,fXMXXXXXXXXXXXMXXtXMXXXXMM', // 7
      'Mfffff,ffffXMXXXLLLLLXXXMXXXXMXXXXMM', // 8
      'MXXXXX,XXXXXMXXXLLLLLXXXMXXXXMXXXXMM', // 9
      'MXtXXX,XXtXXMXXXLLLLLXXXMXXXXMXXXXMM', // 10
      'MXXXXX,XXXXXXXXXLLLLLXXXMXXXXXXXXXMM', // 11
      ',,,,,,,,,,,,XXXXLLLLLXXXMXXXXXXXXX,,', // 12
      'MXXXXXXXXXXXXXXXLLLLLXXXMXXXXXXXXXMM', // 13
      'MXXXXXXXXXXXMXXXLLLLLXXXMXXXXMXXXXMM', // 14
      'MXXXXXXXXXXXMXXXLLLLLXXXMXtXXMXXXXMM', // 15
      'MXXtXXXXXXXXMXXXXXXXXXXXMXXXXMXXXXMM', // 16
      'MXXXXXXXXXXXMXXXXXXXXXXXMXXXXMXXXXMM', // 17
      'MXXXXXXXXXXXMLLLXXXXXXXXXXXXXMXLLXMM', // 18
      'MXXXXXXtXXXXMLLLXXXXXXXXXXXXXMXLLXMM', // 19
      'MXXXXXXXXXXXMXXXXXtXXXXXMXXXXMXXXXMM', // 20
      'MXXXXXXXXXXXMXXXXXXXXXXXMXXXXMXtXXMM', // 21
      'MXXXXXXXXXXXMXXXXXXXXXXXMXXXXMXXXXMM', // 22
      'MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM', // 23
    ],
    npcs: [
      {id: "camp_inn", x: 3, y: 3, sprite: "innkeeper", name: "캠프 관리인", dir: "down", event: "evt_camp_inn"},
      {id: "camp_shop", x: 8, y: 3, sprite: "merchant", name: "캠프 상인", dir: "down", event: "evt_camp_shop"},
      {id: "refugee_soldier", x: 3, y: 6, sprite: "soldier", name: "부상당한 병사", dir: "right", event: "evt_camp_soldier"},
      {id: "refugee_f", x: 8, y: 6, sprite: "villager_f", name: "피난민 여인", dir: "left", event: "evt_camp_refugee"},
      {id: "refugee_kid", x: 5, y: 5, sprite: "child", name: "피난민 아이", dir: "down", wander: true, event: "evt_camp_kid"},
      {id: "dragon", x: 34, y: 12, sprite: "monster", name: "흑룡", dir: "left",hideIf: "black_dragon_defeated", event: "evt_black_dragon"},
    ],
    triggers: [
      {x: 6, y: 8, w: 1, h: 1, event: "evt_camp_banter",hideIf: "camp_banter"},
      {x: 33, y: 12, w: 1, h: 1, event: "evt_black_dragon",hideIf: "black_dragon_defeated"},
    ],
    exits: [
      {x: 0, y: 12, w: 1, h: 1, to: "plains", tx: 28, ty: 10, dir: "left"},
      {x: 35, y: 12, w: 1, h: 1, to: "castle", tx: 15, ty: 26, dir: "up"},
    ],
    chests: [
      {id: "c1", x: 23, y: 2, item: "silver_mail", count: 1},
      {id: "c2", x: 28, y: 2, item: "hi_ether", count: 2},
      {id: "c3", x: 14, y: 21, item: "speed_boots", count: 1},
      {id: "c4", x: 2, y: 21, item: "fire_bomb", count: 3},
      {id: "c5", x: 27, y: 21, item: "hi_potion", count: 3},
      {id: "c6", x: 22, y: 12, item: "panacea", count: 2},
    ],
    objects: [
      {x: 6, y: 3, sprite: "save_crystal", event: "evt_save_crystal"},
      {x: 31, y: 9, sprite: "save_crystal", event: "evt_heal_crystal"},
      {x: 7, y: 9, sprite: "sign", lines: ["황야 피난민 캠프\n「지친 자여, 불가에서 쉬어 가라」"]},
    ],
    onEnter: 'evt_wasteland_enter',
  },
  castle: {
    name: "마왕성", bgm: 'castle', battleBg: 'castle', encounter: 'castle', dark: false,
    // 32x28
    tiles: [
      'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW', // 0
      'WWWWWWWWWWWWWWW^WWWWWWWWWWWWWWWW', // 1
      'WWWWWWWWWWWWWWWKWWWWWWWWWWWWWWWW', // 2
      'WW_______WWW___KK___WWW_______WW', // 3
      'WW_______WWW___KK_____________WW', // 4
      'WW_______WWW_P_KK_P_WWW_______WW', // 5
      'WW__LLL__WWW___KK___WWW_______WW', // 6
      'WW__LLL__WWW___KK___WWW__LLL__WW', // 7
      'WW_______WWW_P_KK_P_WWW__LLL__WW', // 8
      'WW_______WWW___KK___WWW_______WW', // 9
      'WW_______WWW___KK___WWW_______WW', // 10
      'WW_______WWWWWWWWWWWWWW_______WW', // 11
      'WWW____________KK____________WWW', // 12
      'WWW____P_______KK_______P____WWW', // 13
      'WWW____________KK____________WWW', // 14
      'WWWWWWWWWWWWWWWKKWWWWWWWWWWWWWWW', // 15
      'WWWWWWWWWWWWWWWKKWWWWWWWWWWWWWWW', // 16
      'WWWWWWWWWWWWWWWKKWWWWWWWWWWWWWWW', // 17
      'WWWWWWWWWWWWWWWKKWWWWWWWWWWWWWWW', // 18
      'WWWWWWWWWWWWWWWKKWWWWWWWWWWWWWWW', // 19
      'WWWWWWWWWWWWWWWDDWWWWWWWWWWWWWWW', // 20
      'WWWWWWWWWW_____KK_____WWWWWWWWWW', // 21
      'WWWWWWWWWW_P___KK___P_WWWWWWWWWW', // 22
      'WWWWWWWWWW_____KK_____WWWWWWWWWW', // 23
      'WWWWWWWWWW_____KK_____WWWWWWWWWW', // 24
      'WWWWWWWWWW_P___KK___P_WWWWWWWWWW', // 25
      'WWWWWWWWWW_____KK_____WWWWWWWWWW', // 26
      'WWWWWWWWWWWWWWWKKWWWWWWWWWWWWWWW', // 27
    ],
    npcs: [
      {id: "castle_merchant", x: 12, y: 23, sprite: "merchant", name: "수상한 상인", dir: "right", event: "evt_castle_shop"},
      {id: "ghost_knight", x: 5, y: 10, sprite: "soldier", name: "떠도는 기사의 혼", dir: "down", event: "evt_castle_ghost"},
      {id: "vorg", x: 15, y: 2, sprite: "vorg", name: "보르그", dir: "down",hideIf: "vorg_defeated", event: "evt_vorg"},
    ],
    triggers: [
      {x: 15, y: 3, w: 1, h: 1, event: "evt_vorg",hideIf: "vorg_defeated"},
    ],
    exits: [
      {x: 15, y: 27, w: 2, h: 1, to: "wasteland", tx: 33, ty: 12, dir: "left"},
      {x: 15, y: 1, w: 1, h: 1, to: "throne", tx: 9, ty: 13, dir: "up"},
    ],
    chests: [
      {id: "c1", x: 3, y: 4, item: "elixir", count: 1},
      {id: "c2", x: 8, y: 11, item: "phoenix_feather", count: 2},
      {id: "c3", x: 29, y: 4, item: "hi_ether", count: 3},
      {id: "c4", x: 24, y: 10, item: "angel_charm", count: 1},
      {id: "c5", x: 28, y: 14, item: "elixir", count: 1},
    ],
    objects: [
      {x: 19, y: 23, sprite: "save_crystal", event: "evt_heal_crystal"},
      {x: 17, y: 9, sprite: "save_crystal", event: "evt_heal_crystal"},
    ],
    onEnter: 'evt_castle_enter',
  },
  throne: {
    name: "마왕의 옥좌", bgm: 'final_boss', battleBg: 'throne', encounter: null, dark: false,
    // 20x16
    tiles: [
      'WWWWWWWWWWWWWWWWWWWW', // 0
      'W__________________W', // 1
      'W________KK________W', // 2
      'W___P____KK____P___W', // 3
      'W________KK________W', // 4
      'WLL______KK______LLW', // 5
      'WLL_P____KK____P_LLW', // 6
      'WLL______KK______LLW', // 7
      'WLL______KK______LLW', // 8
      'WLL_P____KK____P_LLW', // 9
      'WLL______KK______LLW', // 10
      'W________KK________W', // 11
      'W___P____KK____P___W', // 12
      'W________KK________W', // 13
      'W________KK________W', // 14
      'WWWWWWWWWKKWWWWWWWWW', // 15
    ],
    npcs: [
      {id: "demon_king", x: 9, y: 3, sprite: "demon_king", name: "자르가스", dir: "down",hideIf: "demon_king_defeated", event: "evt_demon_king"},
    ],
    triggers: [
      {x: 3, y: 7, w: 14, h: 1, event: "evt_demon_king",hideIf: "demon_king_defeated"},
    ],
    exits: [
      {x: 9, y: 15, w: 2, h: 1, to: "castle", tx: 15, ty: 3, dir: "down"},
    ],
    chests: [],
    objects: [
      {x: 6, y: 13, sprite: "save_crystal", event: "evt_heal_crystal"},
    ],
    onEnter: 'evt_throne_enter',
  },
};
