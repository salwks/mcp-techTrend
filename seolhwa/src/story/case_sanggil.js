// 사건 「산길의 실종」 — 조사 대상(단서 소품)과 장면 스크립트
import {
  anchor, arena, perches, startCase, checkFood, cakesFound, cReady, warnLevel,
  OUTCOME_KIND, OUTCOME_WORLD, CASE_TITLE,
} from './common.js';

// ================= 조사 대상(물건) =================
// when(S): 지금 보이는가. label: 프롬프트 문구
export const OBJECTS = [
  { id: 'cake_1', label: '떨어진 떡 · 조사', when: (S) => !S.is('cake_1') },
  { id: 'cake_2', label: '떨어진 떡 · 조사', when: (S) => !S.is('cake_2') },
  { id: 'cake_3', label: '떨어진 떡 · 조사', when: (S) => !S.is('cake_3') },
  { id: 'torn_skirt', label: '덤불에 걸린 천 · 조사', when: (S) => !S.hasClue('torn_skirt') },
  { id: 'blood', label: '길가의 얼룩 · 조사', when: (S) => !S.hasClue('blood') },
  { id: 'tracks', label: '발자국 · 조사', when: (S) => !S.hasClue('tracks') },
  { id: 'basket', label: '서낭당 앞 광주리 · 조사', when: (S) => !S.hasClue('basket') },
  { id: 'flour_prints', label: '흰 발자국 · 조사', when: (S) => !S.hasClue('flour_prints') },
  { id: 'barn', label: '헛간 동아줄 · 조사', when: (S) => !S.hasClue('rope') },
  { id: 'oil_shop', label: '참기름 병 · 살펴보기', when: (S) => !S.has('oil') && !S.is('oil_on_tree') && !S.is('got_oil') && !S.is('looked_oil') },
  { id: 'big_tree', label: '큰 고목 · 조사', when: (S) => !S.hasClue('claw_marks') || (S.state.phase === 'night' && S.knows('K_CLIMB') && S.has('oil') && !S.is('oil_on_tree')), radius: 2.4,
    labelFn: (S) => (S.hasClue('claw_marks') ? '고목 밑동 · 참기름 바르기' : '큰 고목 · 조사') },
  { id: 'claw_tree', label: '발톱 자국 난 나무 · 조사', when: (S) => !S.hasClue('territory'), radius: 2.4 },
  { id: 'territory_edge', label: '빈터 어귀 · 조사', when: (S) => !S.hasClue('territory') },
  { id: 'cake_bait', label: '오솔길 어귀 · 떡 놓기', when: (S) => S.state.phase === 'night' && !S.is('bait_placed') && S.has('tteok') && !S.is('climax_started') },
  { id: 'yard_torch', label: '마당 횃대 · 불 붙이기', when: (S) => S.state.phase === 'night' && !S.is('torch_lit') && S.has('torch') && !S.is('climax_started') },
  { id: 'house_door', label: '외딴집 문 앞 · 숨어서 기다린다', when: (S) => S.state.phase === 'night' && !S.is('climax_started'), radius: 2.2 },
  { id: 'village_gate', label: '마을 어귀 · 길을 떠난다', when: (S) => S.state.phase === 'morning' && S.is('morning_done'), radius: 2.6 },
];

const CAKE_TEXT = {
  cake_1: '떡 하나가 길섶 흙에 반쯤 묻혀 있다. 둘레의 흙이 큰 코로 킁킁댄 듯 파헤쳐졌다.',
  cake_2: '굽이를 돌자 또 떡 하나. 한 귀퉁이에 짐승 이빨 자국이 났는데, 먹다 말고 버려 두었다.',
  cake_3: '세 번째 떡. 누군가 고개마다 하나씩 던져 주며 걸음을 재촉한 것 같다.',
};

export async function examineObject(S, id, scenes) {
  if (id.startsWith('cake_') && id !== 'cake_bait') {
    S.flag(id);
    await S.examine('떨어진 떡', CAKE_TEXT[id], 'clue');
    S.setWorldState(`clue_taken_${id}`, true);
    S.learnClue('cakes');
    S.give('tteok', 1);
    if (cakesFound(S) === 3) S.toast('떡 세 개. 고개마다 하나씩…', 'info');
    checkFood(S);
    return;
  }
  switch (id) {
    case 'torn_skirt':
      await S.examine('찢어진 치맛자락', '덤불에 무명 치맛자락이 걸려 있다. 날카로운 것에 네 줄로 길게 찢겼다. 쪽빛 물이 든 여인네 치마다.', 'clue');
      S.setWorldState('clue_taken_torn_skirt', true);
      S.learnClue('torn_skirt');
      return;
    case 'blood':
      await S.examine('마른 얼룩', '길가 돌에 검붉은 얼룩이 번져 있다. 사흘은 지난 빛이다. 둘레 풀이 한쪽으로 쓸려 누웠다.', 'clue');
      S.learnClue('blood');
      return;
    case 'tracks':
      await S.examine('뒤섞인 발자국', ['짚신 자국 곁에 손바닥보다 큰 둥근 발자국이 나란히 찍혀 있다.', '짚신 자국은 어느 굽이에서 뚝 끊기고, 큰 발자국만 산 위로 이어진다.'], 'clue');
      S.learnClue('tracks');
      return;
    case 'basket':
      await S.examine('빈 떡 광주리', ['서낭당 돌무더기 앞에 광주리가 엎어져 있다. 떡은 한 조각도 남지 않았다.', '곁에 무명 수건 하나. 떡 광주리를 일 때 머리에 받치던 것이다.'], 'clue');
      S.learnClue('basket');
      S.give('headscarf');
      if (!checkFood(S)) S.toast('떡은 다 어디로 갔을까. 길을 되짚어 보자.', 'info');
      return;
    case 'flour_prints':
      await S.examine('흰 발자국', ['방앗간 앞, 쏟아진 밀가루를 밟은 큰 발자국이 숲 쪽으로 이어진다.', '이상하다. 뒷발보다 앞발 자국이 유난히 하얗다. 일부러 앞발만 가루에 묻힌 것처럼.'], 'clue');
      S.learnClue('flour_prints');
      S.learnRule('K_FLOUR');
      return;
    case 'barn':
      await S.examine('낡은 동아줄', ['들보에 동아줄 한 타래가 걸려 있다. 손으로 비틀자 푸석하게 끊어진다.', '이 줄로는 아이 하나 매달기도 어렵겠다.'], 'clue');
      S.learnClue('rope');
      S.give('old_rope', 1, true);
      return;
    case 'oil_shop':
      S.flag('looked_oil');
      await S.examine('참기름 병', '끝순이네 부엌 선반에 참기름 병이 반들거린다. 고소한 냄새. 한 방울만 묻어도 손이 미끄럽다.', 'clue');
      return;
    case 'big_tree':
      if (!S.hasClue('claw_marks')) {
        await S.examine('고목의 발톱 자국', ['외딴집 앞 고목. 사람 키를 훌쩍 넘는 곳까지 껍질이 깊게 긁혀 있다.', '거친 껍질엔 발톱이 깊이 박혔는데, 매끈한 옹이 자리에선 미끄러진 자국뿐이다.'], 'clue');
        S.learnClue('claw_marks');
        S.learnRule('K_CLIMB');
        if (S.state.phase !== 'night' || !S.has('oil')) return;
      }
      return scenes.oilTree();
    case 'claw_tree':
    case 'territory_edge':
      await S.examine('고갯길 동쪽 빈터', ['빈터 어귀에 짐승 뼈가 구른다. 둘레 나무마다 발톱 자국.', '타다 만 횃불 하나가 떨어져 있다. 누군가 불을 들고 여기까지 몰아붙인 적이 있다.'], 'clue');
      S.learnClue('territory');
      S.learnRule('K_TERRITORY');
      return;
    case 'cake_bait':
      return scenes.placeBait();
    case 'yard_torch':
      return scenes.lightTorch();
    case 'house_door':
      return scenes.waitAtDoor();
    case 'village_gate':
      return scenes.depart();
    default:
  }
}

// ================= 장면 =================
export function makeScenes(S, api) {
  const A = (n) => anchor(S, n);
  const sc = {};

  // ---- 도착 ----
  sc.intro = async () => {
    const g = A('village_gate');
    S.teleportPlayer({ x: g.x, z: g.z - 2.2, face: 'up' });
    await S.caption('고개 아래, 느티나무 마을.', 2600);
  };

  // ---- 첫 조우(해질녘) ----
  sc.firstEncounter = async () => {
    S.flag('first_encounter');
    S.letterbox(true);
    S.timeTarget = null;
    S.setTime(17.6);
    await S.caption('어느새 해가 고개 너머로 기울었다.', 2200);
    await S.caption('바람이 멎는다. 새소리도 그쳤다.', 2000);
    S.letterbox(false);
    const res = await S.combat(arena(S, 'territory'), {
      mods: { firstEncounter: true }, allowFlee: true, retreatAt: { hpRatio: 0.75, seconds: 60 }, fallbackResult: 'repelled', fade: true,
    });
    if (res === 'lose') await S.fade(600, true);
    S.learnClue('first_sight');
    if (res === 'lose') {
      await S.caption('먹빛 줄무늬. 번뜩이는 눈. 그리고 어둠.', 2200);
      S.endCombat();
      const w = A('wake_spot');
      S.teleportPlayer({ x: w.x, z: w.z, face: 'up' });
      S.setTime(19.5);
      S.flag('woke_by_hunter');
      await S.fade(800, false);
      await S.say('포수 막쇠', ['정신이 드시오? 고갯길에 쓰러져 있길래 업어 왔소.', '…봤구려. 그놈이오. 몸집이 집채만 하지.']);
      S.flag('hunter_after_wake');
    } else if (res === 'escaped') {
      S.endCombat();
      await S.caption('정신없이 산길로 빠져나왔다. 등 뒤에서 낮은 울음이 따라온다.', 2600);
    } else {
      if (res === 'win') S.flag('tiger_wounded');
      S.endCombat();
      await S.caption('범은 땅이 울리도록 포효하고, 고갯마루 너머로 사라졌다.', 2600);
    }
    S.setTime(Math.max(18.2, S.state.time));
    S.journalNote('사건 기록 — 범을 보았다');
    await S.caption('범이다. 사흘째 돌아오지 않는 어미, 그리고 숲가의 오누이…', 2600);
  };

  // ---- 주막에서 쉬기 → 밤 ----
  sc.rest = async () => {
    await S.say('주모', ['건넌방 비어 있소. 눈 좀 붙이시오.', '…오늘 밤 그 집 애들이 걱정이구먼.']);
    await S.fade(900, true);
    S.state.phase = 'night';
    S.setTime(22);
    const inn = A('inn');
    S.teleportPlayer({ x: inn.x, z: inn.z + 1.2, face: 'down' });
    api.placeKids();
    await S.wait(500);
    await S.fade(900, false);
    await S.caption('달이 떴다…', 2400);
    S.journalNote('밤이 되었다. 외딴집으로 가 보자');
  };

  sc.nightArrive = async () => {
    S.flag('night_arrived');
    await S.caption('창호지 너머로 등잔불이 가물거린다. 아직은 조용하다.', 2600);
    S.toast('준비를 마치면 문 앞에 숨어 기다리자.', 'info');
  };

  // ---- 밤의 준비 ----
  sc.kidsToTree = async (up) => {
    if (up) {
      await S.say('순이', ['나무 위요? …돌이야, 누나 손 꼭 잡아.']);
      S.flag('kids_in_tree', true);
      S.setWorldState('kids_in_tree', true);
      await api.kidsClimb();
      if (!S.is('oil_on_tree') && S.knows('K_CLIMB')) S.toast('범은 나무를 탄다. 이대로 괜찮을까…', 'info');
    } else {
      await S.say('순이', ['네. 문고리 걸고 있을게요.']);
      S.flag('kids_in_tree', false);
      S.setWorldState('kids_in_tree', false);
      api.placeKids();
    }
  };

  sc.oilTree = async () => {
    if (!S.has('oil')) return;
    const c = await S.choice('나무 밑동에 참기름을 바를까?', [
      { id: 'yes', label: '밑동에 참기름을 바른다' },
      { id: 'no', label: '그만둔다' },
    ]);
    if (c !== 'yes') return;
    S.anim('player', 'throw');
    await S.wait(500);
    S.take('oil');
    S.flag('oil_on_tree');
    S.setWorldState('oil_on_tree', true);
    await S.caption('밑동이 번들번들해졌다. 손바닥을 대자 주르륵 미끄러진다.', 2400);
  };

  sc.placeBait = async () => {
    if (!S.knows('K_FOOD')) {
      await S.examine('오솔길 어귀', '고갯길로 이어지는 오솔길 어귀다. 범이 무엇에 끌리는지 안다면 여기서 쓸 수 있을 텐데.', 'clue');
      return;
    }
    const c = await S.choice('떡을 고갯길 쪽으로 하나씩 놓아 둘까?', [
      { id: 'yes', label: '떡을 놓아 냄새 길을 만든다' },
      { id: 'no', label: '그만둔다' },
    ]);
    if (c !== 'yes') return;
    S.take('tteok', 1);
    S.flag('bait_placed');
    S.setWorldState('cake_bait', true);
    await S.caption('오솔길 어귀부터 고개 쪽으로, 떡을 띄엄띄엄 놓았다.', 2400);
  };

  sc.lightTorch = async () => {
    S.flag('torch_lit');
    S.setWorldState('torch_lit', true);
    await S.caption('횃대에 불을 옮겨 붙였다. 마당이 붉게 일렁인다.', 2200);
  };

  sc.waitAtDoor = async () => {
    const prep = [];
    if (S.is('kids_warned')) prep.push(S.is('hand_test') ? '아이들에게 손을 보라 일렀다' : '아이들에게 목소리에 속지 말라 일렀다');
    if (S.is('kids_in_tree')) prep.push('아이들은 나무 위에 있다');
    if (S.is('oil_on_tree')) prep.push('나무 밑동에 참기름');
    if (S.is('bait_placed')) prep.push('오솔길에 떡');
    if (S.is('torch_lit') || S.has('torch')) prep.push('횃불');
    const c = await S.choice(prep.length ? `준비: ${prep.join(' · ')}` : '아직 아무 준비도 하지 않았다.', [
      { id: 'wait', label: '숨어서 기다린다' },
      { id: 'not', label: '아직이다' },
    ]);
    if (c === 'wait') await sc.climax();
  };

  // ---- 절정: 문 두드리는 소리 ----
  sc.climax = async () => {
    S.flag('climax_started');
    S.letterbox(true);
    await S.fade(600, true);
    const door = A('house_door');
    const hide = A('hide_spot');
    S.teleportPlayer({ x: hide.x, z: hide.z, face: 'left' });
    api.placeKids(true);
    S.cameraOverride({ pitch: 40, distance: 19 });
    S.cameraFocus({ x: (door.x + hide.x) / 2, z: door.z + 0.5 });
    S.setTime(23.5);
    const from = A('tiger_from');
    const tiger = S.spawn('tiger_night', 'tiger', from, 'right', { id: 'tiger_night', name: '???' });
    try { tiger.char.setVariant?.('disguised'); } catch { /* 변형 미구현 */ }
    await S.wait(300);
    await S.fade(700, false);
    await S.caption('자정 무렵. 숲에서 무언가가 내려온다.', 2400);
    await S.moveActor(tiger, [{ x: door.x - 4.5, z: door.z + 0.6 }, { x: door.x - 0.6, z: door.z + 0.3 }], 1.5, 'walk', 'knock');
    S.face(tiger, 'up');
    S.anim(tiger, 'knock');
    await S.say('문밖의 목소리', ['얘들아, 엄마 왔다. 문 열어라.', '떡 팔고 오느라 늦었다. 어서 문 열어라.']);
    const go = await S.choice('', [
      { id: 'watch', label: '숨죽여 지켜본다' },
      { id: 'fight', label: '지금 뛰어나간다' },
    ]);
    if (go === 'fight') {
      await S.caption('나그네가 칼을 뽑아 들고 마당으로 뛰어들었다!', 2000);
      return sc.resolve('A', await sc.yardFight('A', {}));
    }
    if (S.is('kids_in_tree')) return sc.treeBranch(tiger);
    return sc.doorBranch(tiger);
  };

  // 아이들이 나무 위에 있을 때
  sc.treeBranch = async (tiger) => {
    await S.say('문밖의 목소리', ['…얘들아? 어디 갔느냐.']);
    S.anim(tiger, 'sniff');
    await S.wait(900);
    const t = A('big_tree');
    await S.moveActor(tiger, [{ x: t.x + 0.4, z: t.z - 0.3 }], 2.0, 'walk', 'idle');
    S.face(tiger, 'left');
    await S.say('돌이', ['누, 누나…']);
    await S.say('순이', ['쉿.']);
    await S.say('문밖의 목소리', ['거기 있었구나. 엄마가 올라가마.']);
    S.anim(tiger, 'climb_try');
    await S.wait(1300);
    if (S.is('oil_on_tree')) {
      await S.caption('번들거리는 줄기에 발톱이 주르륵 미끄러진다!', 1800);
      S.anim(tiger, 'slip');
      try { S.ctx.rig?.shake?.(0.5, 450); } catch { /* */ }
      await S.wait(900);
      await S.caption('범이 등을 땅에 찧고 나뒹군다. 지금이다!', 1800);
      return sc.resolve('B', await sc.yardFight('B', { stunned: 3, hpRatio: 0.75 }));
    }
    for (const k of ['suni', 'dori']) S.anim(k, 'cower');
    await S.say('순이', ['오지 마! 오지 마!']);
    await S.caption('범이 나무를 타고 오른다! 망설일 틈이 없다.', 2000);
    return sc.resolve('A', await sc.yardFight('A', {}));
  };

  // 아이들이 집 안에 있을 때
  sc.doorBranch = async (tiger) => {
    if (!S.is('kids_warned')) {
      await S.say('돌이', ['엄마다! 누나, 엄마 왔어!']);
      await S.say('순이', ['…엄마? 목소리가 왜 그래…?']);
      await S.caption('문고리가 덜컥 벗겨진다—', 1600);
      await S.caption('나그네가 먼저 마당으로 뛰어들었다. 아이들은 뒷문으로 빠져나가 큰 나무 위로 기어오른다.', 2800);
      S.flag('kids_fled_to_tree');
      await api.kidsClimb();
      return sc.resolve('A', await sc.yardFight('A', {}));
    }
    if (S.is('hand_test')) {
      await S.say('순이', ['우리 엄마면 손 좀 보여 주세요.']);
      await S.say('문밖의 목소리', ['…옜다.']);
      await S.caption('문틈으로 허연 손이 들이밀어진다. 밀가루가 푸슬푸슬 떨어진다.', 2400);
      await S.say('순이', ['우리 엄마 손은 일해서 거칠고 까매요!', '당신, 우리 엄마 아니지!']);
    } else {
      await S.say('순이', ['우리 엄마 목소리 아니야! 우리 엄마는 그렇게 안 불러!']);
      await S.say('문밖의 목소리', ['감기가 들어 그렇단다. 어서 열어라…']);
    }
    await S.caption('문밖이 조용해진다. 낮게, 목 깊은 데서 그르렁 소리.', 2200);
    if (!S.is('bait_placed')) {
      await S.caption('범이 어깨의 저고리를 털어 내고 문짝을 할퀸다!', 2000);
      return sc.resolve('A', await sc.yardFight('A', {}));
    }
    // 떡 냄새
    S.anim(tiger, 'sniff');
    await S.caption('바람결에 떡 냄새가 실려 온다. 범의 코가 오솔길 쪽으로 돌아간다.', 2400);
    const bait = A('cake_bait');
    await S.moveActor(tiger, [{ x: bait.x - 0.6, z: bait.z }], 2.4, 'walk', 'eat');
    S.anim(tiger, 'eat');
    if (!cReady(S)) {
      await S.caption('범이 떡에 정신이 팔렸다. 등이 무방비다!', 2000);
      const c = await S.choice('', [{ id: 'ambush', label: '뒤에서 덮친다' }]);
      void c;
      return sc.resolve('A', await sc.yardFight('A', { stunned: 1.5 }));
    }
    return sc.lure(tiger);
  };

  // C: 떡으로 꾀어 영역까지, 횃불로 몰아낸다
  sc.lure = async (tiger) => {
    await S.caption('떡 하나를 삼키고, 범은 다음 떡 냄새를 좇는다. 나그네는 횃불을 쥐고 뒤를 밟았다.', 2800);
    await S.fade(700, true);
    S.setWorldState('cake_bait', false);
    const edge = A('territory_edge');
    const ter = arena(S, 'territory');
    S.place(tiger, { x: edge.x + 1.2, z: edge.z - 0.6 });
    S.anim(tiger, 'eat');
    S.teleportPlayer({ x: edge.x - 4.2, z: edge.z + 2.2, face: 'right' });
    S.cameraFocus({ x: edge.x - 1.5, z: edge.z + 0.8 });
    if (!S.is('torch_lit')) S.flag('torch_carried');
    await S.wait(300);
    await S.fade(700, false);
    await S.caption('고갯길 동쪽, 빈터 어귀. 마지막 떡 앞에서 범이 고개를 든다.', 2400);
    S.face(tiger, 'left');
    S.anim(tiger, 'idle');
    const c = await S.choice('', [
      { id: 'torch', label: '횃불을 치켜든다' },
      { id: 'fight', label: '칼을 뽑는다' },
    ]);
    if (c === 'fight') {
      S.despawn('tiger_night');
      S.cameraFocus(null);
      S.cameraOverride(null);
      const res = await sc.fightLoop(ter, 'A', {}, { fade: true });
      return sc.resolve('A', res);
    }
    await S.caption('횃불이 타닥 튄다. 범이 귀를 젖히고 한 걸음, 또 한 걸음 물러선다.', 2600);
    S.anim(tiger, 'retreat');
    await S.moveActor(tiger, [{ x: ter.x + 2, z: ter.z - 2 }, { x: ter.x + 8, z: ter.z - 5 }], 2.6, 'retreat', 'idle');
    await S.caption('범은 한 번 돌아보더니, 제 빈터 깊숙이 사라졌다. 어깨에 걸쳤던 저고리가 덤불에 걸려 남았다.', 3000);
    S.despawn('tiger_night');
    return sc.resolve('C', 'repelled');
  };

  // 마당 싸움(패배 시 다시 일어선다)
  sc.yardFight = async (branch, mods, extra = {}) => {
    S.despawn('tiger_night');
    S.cameraFocus(null);
    S.cameraOverride(null);
    if (!S.is('kids_in_tree') && !S.is('kids_fled_to_tree')) api.hideKids(true);
    return sc.fightLoop(arena(S, 'house_yard'), branch, mods, { fade: true, ...extra });
  };

  sc.fightLoop = async (ar, branch, mods, extra = {}) => {
    let m = { ...mods };
    if (S.is('tiger_wounded')) m.hpRatio = Math.min(m.hpRatio ?? 1, 0.8);
    let losses = 0;
    for (let guard = 0; guard < 12; guard++) {
      const res = await S.combat(ar, { mods: m, allowFlee: false, fallbackResult: 'win', ...extra });
      if (res === 'win' || res === 'repelled') return res;
      S.endCombat();
      if (res === 'escaped') {
        await S.caption('아이들을 두고 물러설 수는 없다.', 2000);
        m = { ...m, stunned: 0 };
        continue;
      }
      losses++;
      S.flag('yard_losses', losses);
      await S.caption('눈앞이 캄캄해진다… 아이들의 울음소리가 귓가를 때린다.', 2400);
      m = { hpRatio: m.hpRatio ?? 1 };
      if (losses >= 2 || S.is('hunter_watch')) {
        await S.say('포수 막쇠', ['버티시오! 내가 한 방 먹였소!']);
        m.hpRatio = Math.min(m.hpRatio, 0.55);
        S.flag('hunter_helped');
      }
      await S.choice('', [{ id: 'up', label: '다시 일어선다' }]);
    }
    return 'win';
  };

  // ---- 결말 확정 → 다음 날 아침 ----
  sc.resolve = async (branch, res) => {
    const outcome = branch === 'C' ? 'C' : `${branch}_${res === 'repelled' ? 'repel' : 'win'}`;
    S.state.outcome = outcome;
    S.flag('resolved');
    S.cameraFocus(null);
    S.cameraOverride(null);
    S.endCombat();
    S.despawn('tiger_night');
    api.hideKids(false);
    if (branch !== 'C') {
      await S.caption(res === 'win'
        ? '범이 마지막 숨을 몰아쉬고 쓰러졌다. 어깨에 걸쳤던 저고리가 흙바닥에 떨어진다.'
        : '범이 피를 흘리며 산으로 달아난다. 마당엔 저고리 한 벌이 떨어져 남았다.', 3000);
      if (branch === 'B' || S.is('kids_in_tree') || S.is('kids_fled_to_tree')) await S.caption('나무 위에서 오누이가 떨며 내려다본다.', 2000);
    }
    S.give('jeogori', 1, true);
    await sc.morning();
  };

  sc.morning = async () => {
    const o = S.state.outcome;
    const kind = OUTCOME_KIND[o] || 'win';
    S.letterbox(true);
    await S.fade(1000, true);
    S.state.phase = 'morning';
    S.setTime(8);
    S.setWorldState(OUTCOME_WORLD[o] || 'village_after_win', true);
    S.setWorldState('torch_lit', false);
    S.setWorldState('kids_in_tree', false);
    S.flag('kids_in_tree', false);
    api.placeKids();
    api.ensureMerchant();
    const p = A('morning_player');
    S.teleportPlayer({ x: p.x, z: p.z, face: 'up' });
    await S.wait(400);
    await S.fade(1000, false);
    await S.caption('날이 밝았다.', 2000);
    S.take('jeogori');
    const scarf = S.has('headscarf');
    if (scarf) S.take('headscarf');
    await S.caption(scarf ? '나그네는 찢어진 저고리와 수건을 순이에게 건넸다.' : '나그네는 찢어진 저고리를 순이에게 건넸다.', 2200);
    await S.say('순이', ['…어머니 저고리예요.', '어머니는… 안 오시는 거죠?']);
    S.anim('dori', 'cry');
    await S.choice('', [
      { id: 'a', label: '고개 너머에서 이것만 찾았다.' },
      { id: 'b', label: '(말없이 고개를 끄덕인다)' },
    ]);
    S.anim('suni', 'hug');
    await S.caption('순이는 울지 않았다. 우는 동생의 등을 오래오래 쓸어 주었다.', 2800);
    await S.say('순덕 어멈', ['아이고, 이것들아… 이제 우리 집에서 같이 살자.', '밥 굶길 일은 없을 게다.']);
    await S.say('최 영감', ['고을이 자네한테 빚을 졌네. 약소하나마 받게.']);
    S.give('coins', 5, true);
    S.toast('엽전 닷 냥을 받았다', 'info');
    S.flag('skill_tracks');
    S.toast('새 해결 수단 — 짐승의 흔적 읽기', 'rule');
    await S.caption({
      win: '고갯길에 다시 장꾼이 다닌다. 포수 막쇠는 범 가죽을 두고 입맛을 다셨다.',
      trap: '\'나무 위 오누이\' 이야기는 그해 겨울 내내 사랑방을 돌았다.',
      repel: '범은 살아 있다. 다만 다시는 사람을 해치지 않았다. 서낭당엔 떡을 바치는 사람이 생겼다.',
    }[kind], 3000);
    S.flag('morning_done');
    S.journalNote(`사건 종결 — 「${CASE_TITLE}」`);
    S.letterbox(false);
    const c = await S.choice('', [
      { id: 'roam', label: '마을을 둘러본다' },
      { id: 'leave', label: '길을 떠난다' },
    ]);
    if (c === 'leave') await sc.depart(true);
    else S.toast('떠날 때는 마을 어귀로.', 'info');
  };

  sc.depart = async (sure = false) => {
    if (!sure) {
      const c = await S.choice('길을 떠날까?', [{ id: 'yes', label: '떠난다' }, { id: 'no', label: '조금 더 머문다' }]);
      if (c !== 'yes') return;
    }
    S.state.phase = 'done';
    await api.showEnding();
  };

  return sc;
}

export { warnLevel };
