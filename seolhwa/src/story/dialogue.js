// 마을 사람 대사 — 사건 진행(플래그)에 따라 바뀐다. 세계관 보충은 '더 묻는다' 선택지로.
import { startCase, canRest, warnLevel, CASE_TITLE } from './common.js';

const BYE = { id: 'bye', label: '그만 가 보겠소.' };

// 결과에 따른 다음 날 아침 대사
function after(S) {
  const o = S.state.outcome;
  if (!o) return null;
  return o === 'C' || o.endsWith('_repel') ? 'repel' : (o === 'B_win' ? 'trap' : 'win');
}

async function ask(S, prompt, opts) {
  return S.choice(prompt, [...opts, BYE]);
}

// ---------------- 주모 ----------------
async function jumo(S, scenes) {
  const N = '주모';
  const res = after(S);
  if (res) {
    const lines = {
      win: ['오늘은 술값 안 받소! 범 잡은 나그네한테서 무슨 돈을 받아.', '고갯길에 장꾼들이 다시 넘어오니 주막도 살 맛이 나오.'],
      trap: ['나무 위 오누이 얘기, 벌써 장터까지 다 퍼졌소.', '범이 참기름에 미끄러져 엉덩방아를 찧었다면서? 허허.'],
      repel: ['서낭당에 떡 한 접시 올리고 왔소. 범님도 배는 곯지 말라고.', '…밤이면 멀리서 우는 소리가 들려. 이제 무섭진 않구려.'],
    }[res];
    await S.say(N, lines);
    return;
  }
  if (S.state.phase === 'night') {
    await S.say(N, ['잠이 안 오시오? …나도 그 집 애들 생각에 영 잠이 안 와.']);
    if (S.knows('K_TERRITORY') && !S.has('torch') && !S.is('torch_lit')) {
      const c = await ask(S, '', [{ id: 'torch', label: '횃불 하나 빌릴 수 있겠소?' }]);
      if (c === 'torch') { await S.say(N, ['관솔 넉넉히 감았소. 불은 짐승이 꺼리지.']); S.give('torch'); }
    }
    return;
  }
  if (!S.is('case_started')) {
    await S.say(N, ['어서 오시오, 나그네 양반. 고개 넘어가는 길이오?', '넘을 거면 해 있을 때 넘으시오. 요새 고개가 수상해.']);
    const c = await ask(S, '', [{ id: 'why', label: '고개가 왜 수상하오?' }]);
    if (c !== 'why') return;
    await S.say(N, ['숲가 외딴집 돌이 어멈이 떡 광주리 이고 고개 너머 장에 갔는데,', '사흘째 소식이 없소. 그 집엔 어린 오누이 둘만 남았고.']);
    startCase(S, 'jumo');
    await S.say(N, ['관아에 알려 봐야 사람 하나 안 보낼 테고…', '누가 그 집 애들이라도 좀 들여다봐 주면 좋으련만.']);
    return;
  }
  await S.say(N, [S.is('first_encounter') ? '얼굴이 하얗구려. 산에서 뭘 보셨소?' : '그 집 애들은 좀 보고 오셨소?']);
  for (;;) {
    const rest = canRest(S);
    const c = await ask(S, '', [
      { id: 'more', label: '돌이 어멈은 어떤 사람이었소?', when: !S.is('jumo_more') },
      { id: 'tteok', label: '떡을 좀 얻을 수 있겠소?', when: S.knows('K_FOOD') && !S.is('jumo_tteok') },
      { id: 'torch', label: '횃불 하나 빌릴 수 있겠소?', when: S.knows('K_TERRITORY') && !S.has('torch') && !S.is('torch_lit') },
      { id: 'rest', label: '하룻밤 묵어 가겠소.', disabled: !rest, hint: rest ? undefined : '아직 알아볼 것이 남은 것 같다.' },
    ]);
    if (c === 'more') {
      S.flag('jumo_more');
      await S.say(N, ['떡 하나는 이 고을에서 제일이었지. 장 가는 길이면 고개마다 서낭님께 하나씩 떼어 놓고 갔소.', '…헌데 요 며칠, 떡 냄새 맡은 산짐승이 고갯길까지 내려온다는 말이 돌아.']);
    } else if (c === 'tteok') {
      S.flag('jumo_tteok');
      await S.say(N, ['짐승 꾀는 데 쓰려고? 별난 양반이네.', '어제 찐 거요. 냄새는 아주 고소하지.']);
      S.give('tteok', 2);
    } else if (c === 'torch') {
      await S.say(N, ['관솔 넉넉히 감았소. 불은 짐승이 꺼리지.']);
      S.give('torch');
    } else if (c === 'rest') {
      await scenes.rest();
      return;
    } else return;
  }
}

// ---------------- 순덕 어멈 ----------------
async function sundeok(S) {
  const N = '순덕 어멈';
  const res = after(S);
  if (res) {
    await S.say(N, {
      win: ['오늘 저녁엔 떡 찌고 잔치해요! 우리 순덕이도 오누이랑 같이 먹이고.', '애들은 걱정 마세요. 우리 집 밥상에 숟가락 둘 더 놓으면 되지.'],
      trap: ['돌이가 나무 위에서 범 엉덩방아 찧는 걸 다 봤대요. 하루 종일 그 얘기예요.', '애들은 우리 집에서 지내기로 했어요.'],
      repel: ['서낭당에 떡 올리는 게 새 풍습이 됐어요. 저도 아침에 한 접시 올렸어요.', '애들은 우리 집에서 지내요. 순이가 벌써 물을 길어 오더라니까요.'],
    }[res]);
    return;
  }
  if (S.state.phase === 'night') { await S.say(N, ['어머, 이 밤중에… 그 집에 가시려고요? 조심하세요, 제발.']); return; }
  if (!S.is('case_started')) {
    await S.say(N, ['아이고, 나그네 양반, 들으셨어요? 숲가 외딴집 돌이 어멈이요,', '떡 광주리 이고 고개 넘어간 게 사흘 전인데 아직도 안 와요.', '그 집 오누이만 덩그러니… 아이고, 불쌍해서 어째.']);
    startCase(S, 'sundeok');
  } else {
    await S.say(N, ['그 집 애들 보셨어요? 아이고, 순이 그것이 얼마나 야무진지.']);
  }
  for (;;) {
    const c = await ask(S, '', [
      { id: 'kids', label: '그 집 아이들은 어떻소?', when: !S.is('sd_kids') },
      { id: 'well', label: '우물물에서 비린내가 난다고?', when: !S.is('sd_well') },
    ]);
    if (c === 'kids') {
      S.flag('sd_kids');
      await S.say(N, ['누이 순이가 열한 살인데 어른 못지않아요. 동생 돌이는 겁이 많고.', '어제 가 보니 문고리를 꼭 걸어 잠갔더라고요. 밤마다 누가 문을 두드린대요.']);
    } else if (c === 'well') {
      S.flag('sd_well');
      await S.say(N, ['몰라요, 산짐승이 개울까지 내려와 물을 먹고 간다나 봐요.', '막쇠 포수가 그러던데, 발자국이 솥뚜껑만 하대요.']);
    } else return;
  }
}

// ---------------- 포수 막쇠 ----------------
async function hunter(S) {
  const N = '포수 막쇠';
  const res = after(S);
  if (res) {
    await S.say(N, {
      win: ['그 가죽 말이오… 나한테 넘기면 섭섭잖게 쳐 주리다.', '…농이오. 그래도 아까운 건 아까운 거요.'],
      trap: ['기름 바른 나무라. 사십 년 범을 쫓았어도 그런 꾀는 처음 보오.', '가죽은 내가 손질해 두리다.'],
      repel: ['살려 보냈다고? …허. 그놈이 다시 내려오면 그땐 내가 쏘겠소.', '그래도 그놈 빈터 쪽으로는 이제 아무도 안 가오. 그거면 됐지.'],
    }[res]);
    return;
  }
  if (S.is('woke_by_hunter') && !S.is('hunter_after_wake')) {
    S.flag('hunter_after_wake');
    await S.say(N, ['몸은 좀 어떻소. 고갯길에 쓰러져 있길래 업어 왔소.', '봤구려. 그놈이오. 몸집이 집채만 하지.']);
  }
  if (S.state.phase === 'night') {
    await S.say(N, ['오늘 밤이오? …나도 멀리서 총 들고 지켜보리다. 두 발뿐이지만.']);
    S.flag('hunter_watch');
    if (S.knows('K_TERRITORY') && !S.has('torch') && !S.is('torch_lit')) { await S.say(N, ['이거 가져가시오. 관솔 횃불이오.']); S.give('torch'); }
    return;
  }
  if (!S.is('case_started')) {
    await S.say(N, ['…고갯길에 떡이 떨어져 있더이다. 굽이마다 하나씩.', '외딴집 어미 것이겠지. 사흘째 안 돌아온다니.']);
    startCase(S, 'hunter');
  } else {
    await S.say(N, [S.is('first_encounter') ? '그놈 눈을 보고도 살아 왔으면 운이 좋은 거요.' : '산에 오를 거면 해 있을 때 오르시오.']);
  }
  for (;;) {
    const c = await ask(S, '', [
      { id: 'voice', label: '산에서 무슨 소리를 들었소?', when: !S.is('hm_voice') },
      { id: 'where', label: '그 짐승은 어디에 사오?', when: !S.is('hm_where') },
      { id: 'torch', label: '횃불을 얻을 수 있겠소?', when: S.knows('K_TERRITORY') && !S.has('torch') && !S.is('torch_lit') },
      { id: 'kill', label: '그놈을 잡을 수 있겠소?', when: !S.is('hm_kill') },
    ]);
    if (c === 'voice') {
      S.flag('hm_voice');
      await S.say(N, ['그저께 밤, 고개 아래서 망을 보는데 여자 목소리가 아이들 이름을 부릅디다.', '\'돌아, 순아, 엄마 왔다.\' …숨소리가 사람 것이 아니었소. 목이 너무 깊었지.']);
      S.learnClue('mimic_witness');
      S.learnRule('K_MIMIC');
    } else if (c === 'where') {
      S.flag('hm_where');
      await S.say(N, ['고갯길 동쪽 숲속 빈터. 뼈가 구르고 나무마다 발톱 자국이오.', '그놈은 제 빈터 밖까지는 잘 안 쫓소. 그리고 불을 꺼리지.']);
      S.learnRule('K_TERRITORY');
    } else if (c === 'torch') {
      await S.say(N, ['관솔 횃불이오. 아껴 쓰시오.']);
      S.give('torch');
    } else if (c === 'kill') {
      S.flag('hm_kill');
      S.flag('hunter_watch');
      await S.say(N, ['총알이 두 발 남았소. 두 발로 그놈을 잡느니 내가 먼저 잡아먹히지.', '…밤에 그 집에 간다면, 나도 멀리서 지켜보리다.']);
    } else return;
  }
}

// ---------------- 오누이 ----------------
async function kidsIntro(S, who) {
  if (who === 'dori') {
    await S.say('돌이', ['누, 누구야? …엄마 아니지?', '엄마가 떡 팔러 고개 넘어갔는데 안 와. 사흘 밤 잤어.']);
  } else {
    await S.say('순이', ['…누구세요? 어머니 아는 분이에요?', '어머니가 떡 팔러 가셨어요… 고개를 넘어서. 사흘째예요.']);
  }
  startCase(S, 'kids');
  S.learnClue('kids_story', true);
}

async function kidsNight(S, who, scenes) {
  const warned = warnLevel(S);
  if (who === 'dori') await S.say('돌이', ['아저씨… 밤에 또 그 목소리 오면 어떡해?']);
  else await S.say('순이', ['오늘 밤에도 올까요… 그 목소리.']);
  for (;;) {
    const c = await S.choice('', [
      { id: 'warn', label: warned ? '목소리에 속지 말라 이른다' : '아무에게도 문 열지 말라 이른다', when: !S.is('kids_warned') && !(warned === 0 && S.is('warn_tried')) },
      { id: 'tree', label: '큰 나무 위로 피신시킨다', when: !S.is('kids_in_tree') },
      { id: 'house', label: '집 안으로 들여보낸다', when: S.is('kids_in_tree') },
      { id: 'bye', label: '문 걸고 기다려라.' },
    ]);
    if (c === 'warn') {
      if (warned === 0) {
        await S.say('순이', ['네… 그런데 어머니 목소리면요?', '어머니가 추운 데 서 계시면… 어떡해요?']);
        S.flag('warn_tried');
        S.toast('아이들을 설득할 말이 부족하다. 그 목소리의 정체를 더 알아야 한다.', 'info');
      } else {
        S.flag('kids_warned');
        const lines = ['어머니 목소리로 불러도 열지 마라. 그건 어머니가 아니다.'];
        if (warned === 2) { lines.push('정 모르겠거든 손을 보여 달라 해라. 허옇고 털 난 손이면 절대 열지 마라.'); S.flag('hand_test'); }
        await S.say('나그네', lines);
        await S.say('순이', warned === 2 ? ['…손을 보여 달라고 할게요. 돌이야, 문고리 잡지 마.'] : ['…알았어요. 안 열게요.']);
        S.journalNote('아이들에게 단단히 일렀다');
      }
    } else if (c === 'tree') {
      await scenes.kidsToTree(true);
    } else if (c === 'house') {
      await scenes.kidsToTree(false);
    } else return;
  }
}

async function kids(S, who, scenes) {
  const name = who === 'dori' ? '돌이' : '순이';
  const res = after(S);
  if (res) {
    await S.say(name, who === 'dori'
      ? (res === 'trap' ? ['나 나무 위에서 다 봤다! 범이 미끄덩 떨어졌어!'] : ['아저씨, 순덕이네 집 밥 맛있어. 근데… 엄마 밥이 더 맛있어.'])
      : ['고맙습니다. …어머니 저고리는 제가 기워 둘 거예요.']);
    return;
  }
  if (S.state.phase === 'night') return kidsNight(S, who, scenes);
  if (!S.is('case_started')) return kidsIntro(S, who);
  if (who === 'dori') {
    await S.say('돌이', [S.is('first_encounter') ? '아저씨 산에 갔다 왔어? 엄마 봤어?' : '엄마 언제 와? 아저씨가 찾아 줄 거야?']);
    return;
  }
  await S.say('순이', ['…어머니 소식, 들으셨어요?']);
  for (;;) {
    const c = await S.choice('', [
      { id: 'when', label: '어머니는 언제 떠나셨니?', when: !S.is('sn_when') },
      { id: 'night', label: '밤에 별일은 없었니?', when: !S.is('sn_night') },
      { id: 'tree', label: '집 앞 큰 나무 말인데…', when: !S.is('sn_tree') },
      { id: 'bye', label: '문 꼭 걸고 있거라.' },
    ]);
    if (c === 'when') {
      S.flag('sn_when');
      await S.say('순이', ['사흘 전 새벽에요. 떡 광주리를 이고, 해 지기 전엔 온다고 하셨어요.', '고개마다 서낭님께 떡을 하나씩 놓고 가신댔어요.']);
    } else if (c === 'night') {
      S.flag('sn_night');
      await S.say('순이', ['어젯밤에… 문밖에서 어머니 목소리가 났어요. \'순아, 문 열어라.\'', '그런데 목이 쉬어 있었어요. 감기 드셨다고… 문은 안 열었어요.']);
      S.learnClue('voice_at_night');
    } else if (c === 'tree') {
      S.flag('sn_tree');
      await S.say('순이', ['어머니가 무서운 일 있으면 저 나무에 올라가 있으라 하셨어요.', '그런데 오늘 아침에 보니 껍질이 높은 데까지 긁혀 있었어요.']);
    } else return;
  }
}

// ---------------- 방앗간 주인 ----------------
async function miller(S) {
  const N = '방앗간 주인';
  if (after(S)) { await S.say(N, ['자루 찢던 놈이 사라지니 살 것 같소. 물레방아도 신이 나서 도는구려.']); return; }
  if (!S.is('case_started')) { await S.say(N, ['밀가루 자루를 또 찢어 놨어! 쥐새끼 짓이 아니오, 이건.']); return; }
  await S.say(N, ['밀가루 자루를 또 찢어 놨소. 보시오, 발톱에 쩍 갈라졌잖소.']);
  S.learnClue('flour_sack');
  const c = await ask(S, '', [{ id: 'why', label: '짐승이 밀가루를 왜 탐내겠소?', when: !S.knows('K_FLOUR') }]);
  if (c === 'why') {
    await S.say(N, ['그러게 말이오. 먹지도 않고 발에 처바르기만 하고 갔소.', '흰 발자국이 숲가 외딴집 쪽으로 나 있더란 말이오. 사람 손 흉내라도 내려는지…']);
    S.learnRule('K_FLOUR');
  }
}

// ---------------- 나무꾼 ----------------
async function woodcutter(S) {
  const N = '나무꾼';
  if (after(S)) { await S.say(N, ['이제 해거름에도 나무하러 갈 수 있겠소. 뒤에서 누가 불러도 말이오.']); return; }
  if (!S.is('case_started')) { await S.say(N, ['요새 산에 나무하러 가기가 겁나오. 해 떨어지면 안 가오.']); return; }
  await S.say(N, ['어제 해거름에 나무 지고 내려오는데, 뒤에서 \'돌아, 순아\' 부르는 소리가 났소.', '돌이 어멈 목소리였지. 그 어멈은 사흘 전에 떠났는데.', '돌아보지 않고 냅다 뛰었소. 지금도 등골이 서늘해.']);
  S.learnClue('mimic_witness');
  S.learnRule('K_MIMIC');
}

// ---------------- 그 밖의 마을 사람 ----------------
async function elder(S) {
  const N = '최 영감';
  const res = after(S);
  if (res) { await S.say(N, [res === 'repel' ? '죽이지 않고 돌려보냈다… 산이 사람을 봐준 게 아니라, 자네가 산을 봐준 게지.' : '고을이 자네한테 큰 빚을 졌네.']); return; }
  if (!S.is('case_started')) { await S.say(N, ['고갯마루 서낭당에 돌 하나 얹고 가게. 요즘은 그냥 지나가면 탈이 난다네.', '밤중에 산에서 누가 이름을 부르거든, 절대 대답하지 말게.']); return; }
  await S.say(N, ['떡장수 어멈 말인가. 고개 서낭당에 떡을 바치던 착한 사람이지.']);
  const c = await ask(S, '', [{ id: 'old', label: '옛날 이야기를 더 들려주시오.', when: !S.hasClue('elder_tale') }]);
  if (c === 'old') {
    await S.say(N, ['내 어릴 적에도 이런 가을이 있었네. 범 하나가 떡 바구니만 보면 따라 내려왔지.', '포수들이 불을 들고 고갯마루 빈터까지 몰아붙이니, 다시는 마을로 내려오지 않았어.', '…죽이지 않고도 끝낼 수 있는 일이 있다네.']);
    S.learnClue('elder_tale');
  }
}

async function kim(S) {
  const N = '김 서방';
  if (after(S)) { await S.say(N, ['대감마님이 고갯길 막은 걸 풀라 하셨소. 장꾼들이 벌써 넘어오오.']); return; }
  if (!S.is('case_started')) { await S.say(N, ['대감마님이 해 떨어지면 고갯길을 막으라 하셨소.', '어젯밤 윗집 소가 외양간에서 감쪽같이 사라졌지 뭐요.']); return; }
  await S.say(N, ['외딴집 일 말이오? 대감마님은 관아에 알리라고만 하시니…', '아, 헛간에 동아줄이 있긴 한데 다 삭았을 거요. 쓸 데가 있으면 가져가시오.']);
}

async function kkeutsun(S) {
  const N = '끝순이';
  if (after(S)) { await S.say(N, ['참기름 값은 됐어요. 그 기름이 애들 목숨 값이 됐다면서요.']); return; }
  if (!S.is('case_started')) { await S.say(N, ['장독 뚜껑이 밤마다 열려 있어요. 누가 들여다보는 것처럼.', '숲가 외딴집 아이들 어미가 아직도 안 돌아왔다지 뭐예요.']); return; }
  await S.say(N, ['돌이 어멈 일 때문에 다니신다고요? 아이고, 고생이 많으세요.']);
  const c = await ask(S, '', [{ id: 'oil', label: '참기름을 좀 얻을 수 있겠소?', when: !S.has('oil') && !S.is('oil_on_tree') && !S.is('got_oil') }]);
  if (c === 'oil') {
    await S.say(N, ['참기름이요? 귀한 건데… 그 집 애들 일이라고요?', '그럼 가져가세요. 돌이 어멈한테 얻어먹은 떡이 몇 갠데요.']);
    S.flag('got_oil');
    S.give('oil');
  }
}

async function hwang(S) {
  const N = '황 서방';
  if (after(S)) { await S.say(N, ['허수아비가 이제야 논 쪽을 보고 서 있네. 허허.']); return; }
  if (!S.is('case_started')) { await S.say(N, ['올해 벼는 잘 여물었는데, 허수아비가 자꾸 산 쪽을 보고 서 있어.']); return; }
  await S.say(N, ['해 질 녘 논두렁에 여인네가 서 있더라고. 부르니까 없어졌어.', '돌이 어멈 저고리 같았는데… 아니, 내가 헛것을 봤겠지.']);
}

async function gaettong(S) {
  const N = '개똥이';
  const res = after(S);
  if (res) { await S.say(N, [res === 'repel' ? '큰 고양이 안 죽었대! 산에 가서 산대! 밤에 우는 거 들었어!' : '아저씨가 큰 고양이 이겼대! 진짜야? 나도 칼 줘!']); return; }
  if (S.is('first_encounter')) { await S.say(N, ['아저씨 봤어? 큰 고양이? 줄무늬 있어? 진짜 커?']); return; }
  await S.say(N, ['형들이 그러는데 고개에 엄청 큰 고양이가 산대. 진짜 커!', '돌이랑 순이는 이제 놀러도 안 나와.']);
}

async function merchant(S) {
  await S.say('장꾼', [S.state.outcome === 'C' || after(S) === 'repel' ? '서낭당에 떡 한 조각 놓고 넘어왔소. 요샌 다들 그런다더구먼.' : '고개가 다시 열렸다길래 사흘 길을 하루에 왔소!']);
}

const TABLE = {
  jumo, sundeok_mom: sundeok, hunter_makswe: hunter, miller, woodcutter,
  elder_choi: elder, kim_seobang: kim, kkeutsun, hwang_seobang: hwang, gaettong, merchant,
};

export async function talk(S, id, scenes) {
  S.state.talked[id] = (S.state.talked[id] || 0) + 1;
  if (id === 'suni' || id === 'dori') return kids(S, id, scenes);
  const fn = TABLE[id];
  if (fn) return fn(S, scenes);
  const npc = S.actor(id);
  const lines = npc?.data?.lines;
  if (lines && lines.length) await S.say(npc.data.name || '', lines.slice(0, 2));
}

export const DIALOGUE_IDS = Object.keys(TABLE).concat(['suni', 'dori']);
export { CASE_TITLE };
