// 이야기 프레임 굽기(「산길의 실종」 등, CHARACTER_MASTER Vertical Slice) — 웹 굽기 엔진(frameCore.BakeBank, high)을 그대로 쓴다.
//  - story_girl·story_boy: 남원 누이·아우(CHR_MAIN_009·010) — 대기·걷기·대화 + 울기(cry)·나무 오르기(climb)·나무 위(perch)·웅크림(cower)·안기(hug)
//  - ricecake_mother: 떡장수 어머니(CHR_MAIN_011, 아낙 변형 + 떡 광주리·머리 수건) — 대기·걷기·대화
//  - tiger: 이야기 동작(knock·sniff·climb_try·slip) + 변장(어미 저고리·수건·흰 앞발, 클립 키 ':d')
// 결과: data/frames_story.json + frames_story_<kind>_<n>.png. Godot SpriteChar.merge_bank("frames_story.json")가 읽는다
//   (tiger는 frames.json의 호랑이 은행에 클립을 더하고, 나머지는 새 종류).
// 실행: python3 tools/web_export_server.py 8770 → 브라우저로 http://localhost:8770/__tools/story_bake.html
//   ?set=hanyang 이면 ACT 1 한양 인물만 data/frames_story_hanyang.json + frames_story_<kind>_<n>.png 로(남원 파일은 그대로):
//   - woochi: 우치(CHR_MAIN_003, 가벼운 몸 — 짙은 쪽빛 저고리·머리띠, 짐 없음) 대기·걷기·뛰기·대화·오르기(climb)·웅크림(crouch)
//   - chaekkwae: 책쾌(CHR_MAIN_007, 상인 베이스 변형 — 갓·책 보따리) 대기·걷기·대화·앉기(sit)·묶임(tied)
//   - pojol: 포졸(CHR_HUM_016, 벙거지·검은 쾌자·붉은 띠·육모 방망이 대신 긴 막대) 대기·걷기·뛰기·대화
import { SPECS } from '/src/chars/rigs.js';
import * as fc from '/src/chars/frameCore.js';

const PEOPLE = {
  story_girl: { base: 'child_girl', over: {}, anims: ['idle', 'walk', 'talk', 'cry', 'climb', 'perch', 'cower', 'hug'] },
  story_boy: { base: 'child_boy', over: {}, anims: ['idle', 'walk', 'talk', 'cry', 'climb', 'perch', 'cower', 'hug'] },
  ricecake_mother: { base: 'villager_f', over: { coat: '#e2d7bb', skirt: '#46627b', goreum: '#8e5a48', cuff: '#7d6a55', collar: '#7d6a55', scarf: '#efe9da', carry: 'basket', build: 0.95 },
    anims: ['idle', 'walk', 'talk'] },
};
const SETS = {
  hanyang: {
    woochi: { base: 'villager_m', over: { coat: '#3e4655', pants: '#4b505b', vest: null, collar: '#262b33', daenim: '#262b33', back: null, hat: null, band: '#2b2622',
      stubble: false, legwrap: '#d8d2c2', shoe: '#4a3f33', patch: null, build: 0.9, cheek: 0.12 },
      anims: ['idle', 'walk', 'run', 'talk', 'climb', 'crouch'] },
    chaekkwae: { base: 'villager_m', over: { coat: '#d3c6a5', pants: '#d9ceb4', vest: '#4f4a52', collar: '#4f4a52', daenim: '#4f4a52', back: 'bundle', bundle: '#6b4f3a',
      hat: 'gat', stubble: true, build: 1.0, cheek: 0.16 },
      anims: ['idle', 'walk', 'talk', 'sit', 'tied'] },
    pojol: { base: 'villager_m', over: { top: 'durumagi', coat: '#2f3138', pants: '#d9d2c0', collar: '#1f2026', goreum: '#1f2026', sash: '#a8443c', back: null,
      hat: 'beonggeoji', hatColor: '#2b2622', vest: null, legwrap: '#ece6d6', robeLen: 84, build: 1.08, stubble: true, staff: 'staff' },
      anims: ['idle', 'walk', 'run', 'talk'] },
  },
};

// ?set=hwangju: ACT 2C 황주 「빈 배의 값」 → frames_story_hwangju.json
//   - blind_elder: 눈먼 노인(노인-남 CHR_HUM_022 변형 — 갓 없이 흰 상투, 바랜 무명, 지팡이) 대기·걷기·대화·앉기(sit)
//   - broker: 탁 중개인(상인 CHR_HUM_002 변형 — 갓, 짙은 밤색 두루마기, 짐 없음) 대기·걷기·뛰기·대화·묶임(tied)
//   - daughter: 연이(아낙 CHR_HUM_010 → 젊은 처녀 변형 — 땋은 머리에 붉은 댕기, 흰 저고리·쪽빛 치마, 광주리 없음) 대기·걷기·대화·앉기·웅크림·안기
//   - fisher: 어부(CHR_HUM_018 — 머리띠, 걷어 올린 바지, 긴 장대) 대기·걷기·대화
SETS.hwangju = {
  blind_elder: { base: 'elder', over: { hat: null, hair: 'white', coat: '#d9d3c2', pants: '#ddd6c4', collar: '#b9b09c', goreum: '#c3baa6', pipe: false,
    stoop: 0.32, staff: 'cane', patch: '#c8bea6', build: 0.86 },
    anims: ['idle', 'walk', 'talk', 'sit'] },
  broker: { base: 'villager_m', over: { top: 'durumagi', coat: '#5b4a3c', pants: '#d6ccb4', collar: '#3a2e26', goreum: '#3a2e26', vest: null, daenim: '#3a2e26',
    back: null, patch: null, hat: 'gat', stubble: true, robeLen: 96, build: 1.06, cheek: 0.14, shoe: '#3a3431' },
    anims: ['idle', 'walk', 'run', 'talk', 'tied'] },
  daughter: { base: 'villager_f', over: { coat: '#efe9da', skirt: '#3f5a74', goreum: '#9c3b3b', cuff: '#efe9da', collar: '#d8d0bc', hair: 'braid', ribbon: '#b8322a',
    carry: null, build: 0.86, height: 1.52, cheek: 0.3 },
    anims: ['idle', 'walk', 'talk', 'sit', 'cower', 'hug'] },
  fisher: { base: 'villager_m', over: { coat: '#c2b796', pants: '#d4c9ad', vest: null, collar: '#8c7a5a', daenim: null, back: null, band: '#e7e0cf',
    legwrap: null, staff: 'staff', patch: '#a8987a', build: 1.1, cheek: 0.18, shoe: '#a88a55' },
    anims: ['idle', 'walk', 'talk'] },
};

// ?set=skills: v2.2 전투 숙련 동작(받아밀기 shove·빠른 투척 quick_throw)을 플레이어 은행에 더할 클립으로 → frames_story_skills.json
SETS.skills = { player: { base: 'player', over: {}, armed: true, anims: ['shove', 'quick_throw'] } };   // 칼 든 클립(':a') — 전투 중 SpriteChar.armed가 먼저 찾는다

// ?set=namwon_rope: 남원 동아줄 절정 — 범이 썩은 줄에 매달려 오르는 모습(rope_climb 3장 반복)·끊어져 뒤집히는 자세(fall_flip 2장).
//   옆모습만 굽는다(frameCore VIEW_FALLBACK). → frames_story_namwon_rope.json(호랑이 은행에 더할 클립 — namwon_case.load_tiger_story)
//   누이·아우(story_girl·story_boy): 하늘 줄을 붙잡고 손을 번갈아 끌어올림(rope_up 3장 반복, 앞·옆·뒤) — 남원 굽기와 같은 몸(PEOPLE).
//   그림 이름은 frames_story_namwon_rope_<kind>_<n>.png(남원 본 굽기의 frames_story_story_girl_*.png를 덮어쓰지 않게)
SETS.namwon_rope = {
  tiger: { tiger: true, anims: ['rope_climb', 'fall_flip'] },
  story_girl: { base: 'child_girl', over: {}, anims: ['rope_up'] },
  story_boy: { base: 'child_boy', over: {}, anims: ['rope_up'] },
};

const TIGER_ANIMS = ['knock', 'sniff', 'climb_try', 'slip', ...fc.DISGUISE_ANIMS];

async function toPng(cv) {
  if (cv.convertToBlob) return await cv.convertToBlob({ type: 'image/png' });
  return await new Promise((r) => cv.toBlob(r, 'image/png'));
}
async function put(name, data) {
  const r = await fetch('/export/' + name, { method: 'PUT', body: data });
  if (!r.ok) throw new Error('PUT ' + name + ' ' + r.status);
}
const meta = (f) => ({ page: typeof f.page === 'number' ? f.page : f.page.index, u0: f.u0, u1: f.u1, v0: f.v0, v1: f.v1, x0: f.x0, x1: f.x1, y0: f.y0, y1: f.y1, lift: f.lift });

async function bakeBank(b, keys, prefix) {
  const clips = {};
  for (const key of keys) {
    if (clips[key]) continue;
    const c = b.clip(key); if (!c) continue;
    let g = 0; while (!b.step(c) && g++ < 600);
    clips[key] = { spec: c.spec, frames: c.frames.map(meta) };
  }
  const pages = [];
  for (let i = 0; i < b.pages.length; i++) { const name = `${prefix}_${i}.png`; await put(name, await toPng(b.pages[i].cv)); pages.push(name); }
  return { pages, clips };
}

export async function run(log) {
  const set = new URLSearchParams(location.search).get('set');
  if (set && SETS[set]) return runSet(set, log);
  const out = {};
  for (const kind in PEOPLE) {
    const P = PEOPLE[kind];
    const sp = { ...SPECS[P.base] };
    for (const k in P.over) { if (P.over[k] === null) delete sp[k]; else sp[k] = P.over[k]; }
    SPECS[kind] = sp;
    fc.TIERS.high[kind] = fc.TIERS.high.player;
    const b = new fc.BakeBank(kind, 'high');
    const keys = [];
    for (const vw of ['front', 'side', 'back']) for (const a of P.anims) keys.push(fc.clipKey(fc.resolveView(kind, vw, a), a, false, false));
    out[kind] = await bakeBank(b, keys, `frames_story_${kind}`);
    log('baked ' + kind + ' pages=' + out[kind].pages.length);
  }
  const tb = new fc.BakeBank('tiger', 'high');
  out.tiger = await bakeBank(tb, fc.expandKeys('tiger', TIGER_ANIMS), 'frames_story_tiger');
  log('baked tiger story pages=' + out.tiger.pages.length);
  await put('frames_story.json', JSON.stringify(out));
  log('done: ' + Object.keys(out).join(', '));
  console.log('[story bake] done', Object.keys(out));
}

// 사건별 묶음(?set=hanyang): data/frames_story_<set>.json
async function runSet(set, log) {
  const out = {};
  const people = SETS[set];
  for (const kind in people) {
    const P = people[kind];
    if (P.tiger) {
      out[kind] = await bakeBank(new fc.BakeBank('tiger', 'high'), fc.expandKeys('tiger', P.anims), `frames_story_${set}_${kind}`);
      log('baked ' + kind + ' pages=' + out[kind].pages.length);
      continue;
    }
    const sp = { ...SPECS[P.base] };
    for (const k in P.over) { if (P.over[k] === null) delete sp[k]; else sp[k] = P.over[k]; }
    SPECS[kind] = sp;
    fc.TIERS.high[kind] = fc.TIERS.high.player;
    const b = new fc.BakeBank(kind, 'high');
    const keys = [];
    for (const vw of ['front', 'side', 'back']) for (const a of P.anims) keys.push(fc.clipKey(fc.resolveView(kind, vw, a), a, !!P.armed, false));
    out[kind] = await bakeBank(b, keys, PEOPLE[kind] ? `frames_story_${set}_${kind}` : `frames_story_${kind}`);   // 남원 본 굽기와 같은 종류면 이름을 나눈다
    log('baked ' + kind + ' pages=' + out[kind].pages.length);
  }
  await put(`frames_story_${set}.json`, JSON.stringify(out));
  log('done: ' + Object.keys(out).join(', '));
  console.log('[story bake] done', set, Object.keys(out));
}
