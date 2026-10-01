// 「산길의 실종」 데이터와 공용 판정(단서·습성·소지품·장소·해결 방법)

export const CASE_ID = 'sanggil';
export const CASE_TITLE = '산길의 실종';
export const SAVE_KEY = 'seolhwa_story_v1';

export const ITEMS = {
  tteok: '떡',
  oil: '참기름',
  torch: '횃불',
  old_rope: '낡은 동아줄',
  headscarf: '어미의 수건',
  jeogori: '찢어진 저고리',
  coins: '엽전',
};

export const CLUES = {
  rumor: { title: '떡장수 어미의 실종', text: '고개 너머 장에 떡을 팔러 간 외딴집 어미가 사흘째 돌아오지 않는다.' },
  kids_story: { title: '오누이의 말', text: '어머니는 새벽에 떡 광주리를 이고 고개를 넘었다. 해 지기 전에 온다 했다.' },
  voice_at_night: { title: '문밖의 목소리', text: '어젯밤 문밖에서 어머니 목소리가 순이를 불렀다. 목이 쉰 듯 이상했다.' },
  cakes: { title: '고갯길의 떡', text: '굽이마다 떡이 하나씩 흙에 떨어져 있다. 둘레의 흙은 큰 코가 킁킁댄 듯 파헤쳐졌다.' },
  torn_skirt: { title: '찢어진 치맛자락', text: '덤불에 걸린 무명 치맛자락. 날카로운 것에 길게 네 줄로 찢겼다.' },
  blood: { title: '마른 핏자국', text: '길가 돌에 검붉은 자국이 번져 있다. 사흘은 지난 빛이다.' },
  tracks: { title: '뒤섞인 발자국', text: '짚신 자국 곁에 손바닥보다 큰 짐승 발자국. 짚신 자국은 어느 굽이에서 끊긴다.' },
  basket: { title: '빈 떡 광주리와 수건', text: '서낭당 앞에 엎어진 광주리. 떡은 한 조각도 없다. 곁에 어미의 수건이 떨어져 있었다.' },
  flour_sack: { title: '찢긴 밀가루 자루', text: '방앗간 자루가 발톱에 갈라졌다. 가루는 먹지 않고 흩뜨리기만 했다.' },
  flour_prints: { title: '흰 발자국', text: '흰 가루를 밟은 큰 발자국이 숲으로 이어진다. 앞발 자국만 유난히 하얗다.' },
  mimic_witness: { title: '산에서 부르는 목소리', text: '밤마다 산에서 여자 목소리가 아이들 이름을 부른다. 사람 숨소리가 아니었다고 한다.' },
  claw_marks: { title: '고목의 발톱 자국', text: '외딴집 앞 고목, 사람 키를 훌쩍 넘는 곳에 깊은 발톱 자국. 매끈한 옹이 자리엔 미끄러진 자국뿐.' },
  territory: { title: '고갯길 동쪽 빈터', text: '뼈가 구르고 나무마다 발톱 자국. 어귀엔 타다 만 횃불 하나 — 누군가 불로 쫓아낸 흔적.' },
  rope: { title: '삭은 동아줄', text: '헛간 들보에 걸린 동아줄. 손으로 비틀자 푸석하게 끊어진다.' },
  first_sight: { title: '해질녘의 그것', text: '산길에서 그것을 보았다. 집채만 한 범. 눈이 등잔처럼 번뜩였다.' },
  elder_tale: { title: '최 영감의 옛이야기', text: '옛날에도 떡 바구니를 따라 내려온 범이 있었다. 불을 든 포수들이 고갯마루 빈터로 몰아붙였다고 한다.' },
};

export const RULES = {
  K_FOOD: { title: '먹이에 집착한다', text: '떡 냄새를 따라 고갯길을 내려왔다. 먹을 것이 보이면 그쪽으로 간다.' },
  K_MIMIC: { title: '사람 목소리를 흉내 낸다', text: '아는 사람 목소리로 이름을 부른다. 목소리만으론 믿을 수 없다.' },
  K_FLOUR: { title: '앞발을 희게 칠한다', text: '밀가루를 발라 사람 손인 척한다. 손을 보면 안다.' },
  K_CLIMB: { title: '나무를 탄다', text: '높은 가지까지 오른다. 다만 미끄러운 줄기는 오르지 못한다.' },
  K_TERRITORY: { title: '고갯마루 너머가 제 영역', text: '동쪽 빈터가 그 자리다. 영역 밖까지는 쫓지 않고, 불을 들이대면 제 자리로 물러난다.' },
};

// 월드가 아직 장소를 주지 않을 때 쓰는 좌표(layout.js 기준)
export const ANCHOR_FALLBACK = {
  inn: { x: -6, z: 23.6 },
  mill: { x: -8.5, z: -20.5 },
  flour_prints: { x: -9.2, z: -19.8 },
  oil_shop: { x: -15.2, z: -2.7 },
  barn: { x: 23.2, z: 11 },
  big_tree: { x: -24.8, z: -24 },
  claw_tree: { x: 24.5, z: -52 },
  house_door: { x: -22, z: -28.3 },
  house_yard: { x: -22, z: -25 },
  cake_1: { x: 6, z: -30.6 },
  cake_2: { x: 14.6, z: -36.4 },
  cake_3: { x: -6.8, z: -48.6 },
  torn_skirt: { x: 0.8, z: -47.6 },
  blood: { x: -3.4, z: -53.6 },
  tracks: { x: 2.5, z: -61 },
  basket: { x: 5.7, z: -70.1 },
  headscarf: { x: 3.5, z: -70.5 },
  cake_bait: { x: -13.5, z: -28.4 },
  territory_edge: { x: 20.7, z: -41.5 },
  village_gate: { x: 0, z: 23.4 },
  tiger_first_seen: { x: 12.2, z: -36.9 },
  // 월드 목록에 없는 이야기 전용 자리
  yard_torch: { x: -17.6, z: -25.4 },
  hide_spot: { x: -16.6, z: -29.2 },
  tiger_from: { x: -31, z: -31.5 },
  kid_night_suni: { x: -23.3, z: -27.4 },
  kid_night_dori: { x: -20.7, z: -27.4 },
  kid_inside: { x: -22, z: -31.6 },
  kid_morning_suni: { x: -1.6, z: 9.8 },
  kid_morning_dori: { x: -0.6, z: 10.4 },
  morning_player: { x: -1.2, z: 12.4 },
  woodcutter: { x: 2.4, z: -22.2 },
  wake_spot: { x: -1.2, z: -8.4 },
};

// 마당 싸움터(world.arenas에 'house_yard'가 아직 없을 때)
export const HOUSE_YARD_FALLBACK = {
  id: 'house_yard', name: '외딴집 마당', x: -22, z: -25, radius: 7.5,
  tigerStart: { x: -17.2, z: -22.2 }, playerStart: { x: -21.4, z: -27.4 },
  camera: { pitch: 46, distance: 19, fov: 30 },
};
export const TERRITORY_FALLBACK = {
  id: 'territory', name: '호랑이의 영역', x: 28.5, z: -44, radius: 11,
  playerStart: { x: 21.8, z: -42.4 }, tigerStart: { x: 34, z: -45.2 },
  camera: { pitch: 48, distance: 23, fov: 30 },
};

export function anchor(S, name) {
  const a = S.ctx.world?.anchors?.[name];
  if (a && Number.isFinite(a.x) && Number.isFinite(a.z)) return a;
  return ANCHOR_FALLBACK[name] || { x: 0, z: 0 };
}

export function arena(S, id) {
  const list = S.ctx.world?.arenas || [];
  const found = list.find((a) => a && (a.id === id));
  if (found) return found;
  if (id === 'territory') return list.find((a) => a && a.name === '호랑이의 영역') || list[0] || TERRITORY_FALLBACK;
  if (id === 'house_yard') return S.ctx.world?.houseYard || HOUSE_YARD_FALLBACK;
  return null;
}

export function perches(S) {
  const a = arena(S, 'house_yard');
  if (a && Array.isArray(a.perches) && a.perches.length >= 2) return a.perches;
  const t = anchor(S, 'big_tree');
  const h = S.ctx.world?.heightAt ? S.ctx.world.heightAt(t.x, t.z) : 1.8;
  return [{ x: t.x + 0.5, y: h + 3.0, z: t.z - 1.2 }, { x: t.x, y: h + 3.4, z: t.z - 2.5 }];
}

// ---- 사건 진행 판정 ----
export const PATH_CLUES = ['cakes', 'torn_skirt', 'blood', 'tracks', 'basket'];
export function cakesFound(S) { return ['cake_1', 'cake_2', 'cake_3'].filter((k) => S.is(k)).length; }
export function pathClueCount(S) { return PATH_CLUES.filter((c) => S.hasClue(c)).length; }

export function startCase(S, route) {
  if (S.is('case_started')) return false;
  S.flag('case_started');
  S.flag('route', route);
  S.learnClue(route === 'kids' ? 'kids_story' : 'rumor', true);
  S.toast(`새 사건 — 「${CASE_TITLE}」`, 'journal');
  return true;
}

// 먹이 집착: 빈 광주리 + 떡 하나 이상, 또는 떡 셋을 모두 봤을 때
export function checkFood(S) {
  if (S.knows('K_FOOD')) return false;
  const n = cakesFound(S);
  if ((S.hasClue('basket') && n >= 1) || n >= 3) return S.learnRule('K_FOOD');
  return false;
}

export function canRest(S) {
  return S.is('case_started') && (S.is('first_encounter') || S.state.clues.length >= 5);
}

export function warnLevel(S) {
  if (!S.knows('K_MIMIC')) return 0;
  return S.knows('K_FLOUR') ? 2 : 1;
}

// 해결 방법 판정 — available: 지금 시도해 볼 만한가, needs: 진행 표시
export function solutionState(S) {
  const k = (id) => S.knows(id);
  const hasTorch = S.has('torch') || S.is('torch_lit');
  const hasBait = S.has('tteok') || S.is('bait_placed');
  const hasOil = S.has('oil') || S.is('oil_on_tree');
  const B = [k('K_CLIMB'), hasOil];
  const C = [k('K_MIMIC') && k('K_FLOUR'), k('K_FOOD') && hasBait, k('K_TERRITORY') && hasTorch];
  const cPieces = ['K_MIMIC', 'K_FLOUR', 'K_FOOD', 'K_TERRITORY'].filter(k).length;
  return {
    A: {
      id: 'A', title: '맞서 싸운다', available: true,
      text: '마당에서 정면으로 맞선다. 준비가 없으면 힘겨운 싸움이 된다.',
    },
    B: {
      id: 'B', title: B[0] ? '미끄러운 나무' : '???', available: B.every(Boolean),
      text: '아이들을 큰 나무 위로 피신시키고, 밑동에 참기름을 바른다. 오르다 미끄러진 범은 한동안 일어서지 못한다.',
      hint: B[0] ? '범은 나무를 탄다. 줄기를 미끄럽게 할 무언가가 있다면…'
        : hasOil ? '기름병이 손에 있다. 쓸 데가 있을까…' : '범이 어디까지 오를 수 있는지 아직 모른다.',
      progress: B.filter(Boolean).length / B.length,
    },
    C: {
      id: 'C', title: cPieces >= 2 ? '피를 보지 않고 돌려보낸다' : '???', available: C.every(Boolean),
      text: '아이들에게 손을 보여 달라 하라 이르고, 떡으로 영역 쪽까지 꾀어 낸 뒤 횃불로 몰아낸다.',
      hint: cPieces === 0 ? '범의 버릇을 더 알면 싸우지 않아도 될지 모른다.'
        : `범의 버릇 조각이 맞춰지고 있다 (${cPieces}/4)` + (cPieces === 4 ? (hasBait ? (hasTorch ? '' : ' — 불이 필요하다.') : ' — 꾈 것이 필요하다.') : ''),
      progress: C.filter(Boolean).length / C.length,
    },
  };
}

// 밤의 준비가 C를 완성했는가(실행 단계)
export function cReady(S) {
  return S.is('hand_test') && S.is('bait_placed') && S.knows('K_TERRITORY') && (S.has('torch') || S.is('torch_lit'));
}

export const OUTCOME_KIND = { A_win: 'win', B_win: 'trap', A_repel: 'repel', B_repel: 'trap', C: 'repel' };
export const OUTCOME_WORLD = { A_win: 'village_after_win', B_win: 'village_after_win', A_repel: 'village_after_repel', B_repel: 'village_after_repel', C: 'village_after_repel' };
