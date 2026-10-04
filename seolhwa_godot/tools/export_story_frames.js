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
  await put(`frames_story_${set}.json`, JSON.stringify(out));
  log('done: ' + Object.keys(out).join(', '));
  console.log('[story bake] done', set, Object.keys(out));
}
