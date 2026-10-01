// 사건 기록(책자) 보기 모델
import { CASE_ID, CASE_TITLE, CLUES, RULES, solutionState, cakesFound, OUTCOME_KIND } from './common.js';

const ROUTE_TEXT = {
  jumo: '주막 주모에게서 들었다. 고개 너머 장에 떡을 팔러 간 외딴집 어미가 사흘째 돌아오지 않는다고.',
  sundeok: '우물가 순덕 어멈의 수다 끝에 들었다. 떡 광주리를 이고 고개를 넘은 외딴집 어미가 사흘째 소식이 없다.',
  hunter: '포수 막쇠가 고갯길 굽이마다 떨어진 떡 이야기를 했다. 외딴집 어미가 사흘째 돌아오지 않는다.',
  kids: '숲가 외딴집에서 오누이를 만났다. 어머니가 떡을 팔러 고개를 넘은 지 사흘째라 한다.',
};

const OUTCOME_TEXT = {
  A_win: '밤, 어미의 저고리를 걸친 범이 외딴집 문을 두드렸다. 마당에서 맞서 싸워 범을 쓰러뜨렸다.',
  A_repel: '밤, 어미의 저고리를 걸친 범이 외딴집 문을 두드렸다. 마당에서 맞서 싸웠고, 범은 피를 흘리며 산으로 달아났다.',
  B_win: '밤, 범은 나무 위의 오누이를 노렸다. 참기름 바른 줄기에 미끄러져 나뒹군 범을, 마당에서 쓰러뜨렸다.',
  B_repel: '밤, 범은 나무 위의 오누이를 노렸다. 참기름 바른 줄기에 미끄러져 나뒹군 범은 결국 산으로 달아났다.',
  C: '밤, 아이들은 문을 열지 않았다. 떡 냄새를 좇은 범은 고갯길 동쪽 빈터 어귀에서 횃불을 보고 제 영역으로 돌아갔다. 피 한 방울 보지 않았다.',
};

const ENDING_EXTRA = {
  win: '고갯길에 다시 장꾼이 다닌다. 마을은 사흘 동안 잔치를 벌였다.',
  trap: '\'나무 위 오누이\' 이야기는 그해 겨울 내내 사랑방을 돌았다.',
  repel: '범은 살아 있다. 다만 다시는 사람을 해치지 않았다. 밤이면 멀리서 울음소리가 들리고, 서낭당엔 떡을 바치는 사람이 생겼다.',
};

export function summary(S) {
  const p = [];
  const route = S.state.flags.route;
  p.push(ROUTE_TEXT[route] || ROUTE_TEXT.jumo);
  if (route !== 'kids' && (S.state.talked.suni || S.state.talked.dori)) p.push('외딴집의 오누이는 문고리를 걸어 잠그고 어머니를 기다린다.');
  const cakes = cakesFound(S);
  if (cakes || S.hasClue('basket')) {
    p.push(S.hasClue('basket')
      ? `고갯길 굽이마다 떡이 떨어져 있었다(${cakes}/3). 그 끝, 서낭당 앞엔 빈 광주리와 어미의 수건.`
      : `고갯길 굽이마다 떡이 떨어져 있다(${cakes}/3). 길은 고갯마루 서낭당으로 이어진다.`);
  }
  if (S.hasClue('torn_skirt') || S.hasClue('blood') || S.hasClue('tracks')) {
    const bits = [];
    if (S.hasClue('torn_skirt')) bits.push('찢어진 치맛자락');
    if (S.hasClue('blood')) bits.push('마른 핏자국');
    let t = bits.length ? `${bits.join(', ')}.` : '';
    if (S.hasClue('tracks')) t += `${t ? ' ' : ''}사람 발자국은 어느 굽이에서 끊기고, 큰 짐승의 발자국만 이어진다.`;
    p.push(t);
  }
  if (S.is('first_encounter')) p.push('해질녘 산길에서 그것을 보았다. 범이다.');
  if (S.state.phase === 'night' && !S.state.outcome) p.push('밤이 되었다. 범은 오늘 밤 외딴집에 올 것이다. 문 앞에 숨기 전에 할 수 있는 일을 하자.');
  if (S.state.outcome) {
    p.push(OUTCOME_TEXT[S.state.outcome]);
    p.push('어미는 돌아오지 못했다. 찢어진 저고리를 받아 든 순이는 울지 않았다. 마을 사람들이 오누이를 거두었다.');
    p.push(ENDING_EXTRA[OUTCOME_KIND[S.state.outcome]]);
    p.push('보상: 엽전 닷 냥. 새 해결 수단 「짐승의 흔적 읽기」 — 다음 사건부터 발자국이 더 많은 것을 말해 줄 것이다.');
  }
  return p;
}

export function buildJournal(S) {
  if (!S.is('case_started')) return { cases: [] };
  const sol = solutionState(S);
  const clues = S.state.clues.map((id) => {
    const d = CLUES[id];
    if (!d) return { id, title: id, text: '' };
    if (id === 'cakes') return { id, title: d.title, text: `${d.text} (${cakesFound(S)}/3)` };
    return { id, title: d.title, text: d.text };
  });
  const rules = S.state.rules.map((id) => ({ id, title: RULES[id]?.title || id, text: RULES[id]?.text || '' }));
  const solved = !!S.state.outcome && (S.state.phase === 'morning' || S.state.phase === 'done');
  const solutions = ['A', 'B', 'C'].map((k) => {
    const s = sol[k];
    const chosen = solved && S.state.outcome.startsWith(k);
    return {
      id: k,
      title: s.title,
      available: s.available || chosen,
      text: chosen ? `${s.text} — 이 방법으로 끝냈다.` : s.text,
      hint: s.available ? undefined : s.hint,
      progress: s.progress,
    };
  });
  return {
    cases: [{
      id: CASE_ID,
      title: CASE_TITLE,
      status: solved ? 'solved' : 'active',
      summary: summary(S),
      clues,
      rules,
      solutions,
    }],
  };
}

export function endingData(S) {
  const o = S.state.outcome || 'A_win';
  const kind = OUTCOME_KIND[o] || 'win';
  const title = { win: '범을 쓰러뜨렸다', trap: '나무 위의 오누이', repel: '산으로 돌아간 범' }[kind];
  return {
    title,
    outcome: kind,
    paragraphs: [OUTCOME_TEXT[o], '어미는 돌아오지 못했다. 마을 사람들이 오누이를 거두었다.', ENDING_EXTRA[kind]],
    record: `「${CASE_TITLE}」 — 해결. 단서 ${S.state.clues.length}개, 알아낸 범의 버릇 ${S.state.rules.length}가지. 새 해결 수단 「짐승의 흔적 읽기」를 얻었다.`,
  };
}
