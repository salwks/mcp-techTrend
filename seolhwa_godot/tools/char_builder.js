// 인물 빌더(character builder) — 인물 = 자료(JSON). 같은 리그·같은 동작 묶음에 부위를 굽기 때 그림마다 얹어
// 먹선·한지 그림(frameCore.BakeBank)으로 굽는다. 실행 중 컷아웃 인형이 아니다.
//
//   자료 꼴(spec): { id, template, region, seed, role, body, face, hair, clothes, colors, headwear, items, wear, dirt }
//   generate({ template, region, seed, count }) → spec[]        같은 인자 → 같은 결과(시드 고정)
//   registerSpec(spec) → 리그 종류 id(SPECS에 올리고 부속·공용 자세를 단다)
//   PRESETS: 기존 인물을 빌더 자료로 옮긴 것(주모·방자·포졸·마을 사내)
//   ANIMS: 모든 인물이 같은 동작 묶음 — idle·walk·run·talk·sit·sit_seat·sit_down·stand_up·bow·kneel·carry·jump
// 미리 보기·편집: tools/character_builder.html · 굽기: tools/export_char_frames.js(chars_bake.html)
// 설계·사용법: seolhwa_godot/docs/reports/character-builder.md
import { SPECS, getRig, dropRig, HUMAN_DRAW as H } from '/src/chars/rigs.js';
import { mix } from '/src/chars/painter.js';
import { installPoses } from '/__tools/pose_common.js';
import { builderHead, extraParts, handItem, wearFx } from '/__tools/char_parts.js';

// sit = 땅에 앉기(사내 양반다리, 여인 한쪽 무릎 세움) · sit_seat = 평상·걸상·의자 · sit_down/stand_up = 앉고 일어나는 사이 · jump = 뛰어오르기(한 번)
// sit_talk·sit_work = 앉아서 부르기/매만지기·먹기(장꾼·주막 손님) · squat = 쪼그려 앉기
export const ANIMS = ['idle', 'walk', 'run', 'talk', 'sit', 'sit_seat', 'sit_down', 'stand_up', 'sit_talk', 'sit_work', 'squat', 'bow', 'kneel', 'carry', 'jump'];

// ---------------------------------------------------------------------------
// 고를 수 있는 값(편집기 드롭다운도 이것을 쓴다)
// ---------------------------------------------------------------------------
export const OPTIONS = {
  sex: ['m', 'f'],
  age: ['child', 'youth', 'adult', 'elder'],
  faceShape: ['oval', 'round', 'long', 'square', 'heart'],
  brows: ['thin', 'thick', 'arched', 'straight', 'droop', 'sparse'],
  eyes: ['narrow', 'round', 'droopy', 'upturned', 'sleepy', 'small'],
  nose: ['small', 'long', 'broad', 'hooked'],
  mouth: ['small', 'wide', 'thin', 'full', 'smile', 'frown'],
  mark: ['none', 'mole_cheek', 'mole_lip', 'mole_brow', 'pockmark', 'freckles', 'scar'],
  beard: ['none', 'stubble', 'goatee', 'full', 'long'],
  moustache: ['none', 'thin', 'full', 'droop'],
  hair: ['sangtu', 'jjok', 'daenggi', 'tteokgeo', 'eonjeun', 'shaved', 'bowl', 'short'],
  top: ['jeogori', 'short'],
  outer: ['none', 'durumagi', 'dopo', 'kwaeja', 'jangsam', 'jangot', 'sseugae'],
  vest: ['none', 'baeja', 'fur'],
  bottom: ['baji', 'chima'],
  sash: ['none', 'red', 'cord', 'gasa', 'belt'],
  shoes: ['jipsin', 'mituri', 'taesahye', 'kkotsin', 'beoseon'],
  headwear: ['none', 'gat', 'jeongjagwan', 'paeraengi', 'satgat', 'beonggeoji', 'jeollip', 'samo', 'jokduri', 'nambawi', 'jobawi', 'meorisugeon', 'band'],
  back: ['none', 'jige', 'bundle', 'gwanari'],
  load: ['straw', 'wood'],
  head: ['none', 'basket', 'jar'],
  hand: ['none', 'staff', 'cane', 'longpipe', 'fan', 'roundfan', 'ladle', 'axe', 'bell'],
  handLoad: ['none', 'basket', 'bojagi'],
};
export const LABEL = {
  sangtu: '상투', jjok: '쪽머리', daenggi: '댕기머리', tteokgeo: '떠꺼머리', eonjeun: '얹은머리', shaved: '삭발', bowl: '아이 머리', short: '짧은 머리',
  jeogori: '저고리', short_top: '짧은 저고리', durumagi: '두루마기', dopo: '도포', kwaeja: '쾌자', jangsam: '장삼', jangot: '장옷', sseugae: '쓰개치마',
  baeja: '배자', fur: '털배자', baji: '바지', chima: '치마', red: '붉은 띠', cord: '세조대', gasa: '가사', belt: '허리띠',
  jipsin: '짚신', mituri: '미투리', taesahye: '태사혜', kkotsin: '꽃신', beoseon: '버선',
  gat: '갓', jeongjagwan: '정자관', paeraengi: '패랭이', satgat: '삿갓', beonggeoji: '벙거지', jeollip: '전립', samo: '사모', jokduri: '족두리',
  nambawi: '남바위', jobawi: '조바위', meorisugeon: '머릿수건', band: '수건 띠',
  jige: '지게', bundle: '봇짐', gwanari: '괴나리봇짐', basket: '광주리', jar: '물동이', staff: '지팡이(긴)', cane: '지팡이', longpipe: '담뱃대(장죽)',
  fan: '부채(합죽선)', roundfan: '둥근 부채', ladle: '국자', axe: '도끼', bell: '방울', bojagi: '보자기',
};

// ---------------------------------------------------------------------------
// 물감(조선 염료 — 무명·삼베 바탕, 쪽·감·치자·홍화·소목·먹)
// ---------------------------------------------------------------------------
export const DYES = {
  // 바탕(염색 안 함) — 서민 옷의 대부분
  white: '#ece6d6', sosaek: '#e2d6b8', faded: '#d8ccb0', hemp: '#cfc29f', greige: '#c7bc9e',
  // 서민도 쓰던 물(값싼 염료)
  indigo_l: '#8fa3b0', indigo: '#46627b', indigo_d: '#2f4458', persimmon: '#a8714a', galot: '#9a6440', brown: '#7d6a55', ocher: '#c9a46a',
  gardenia: '#e2c46a', ash: '#8e8b84', charcoal: '#4b4a4c',
  // 양반·기생·혼례(비싼 물)
  jade: '#c6ded6', sky: '#bcd9cf', namsaek: '#2f4876', scarlet: '#c0392b', crimson: '#8a2f37', purple: '#6e2a5c', yellowgreen: '#b9cc8a',
  songhwa: '#ece0a0', pink: '#f0c8c0', teal: '#3e6f6a', black: '#2f3138', yellow: '#ecc95a', violet: '#7a4a8c',
};
const NATURAL = ['white', 'sosaek', 'faded', 'hemp', 'greige'];
const COMMON_DYE = ['indigo_l', 'indigo', 'persimmon', 'brown', 'ocher', 'ash', 'indigo_d'];
const ELITE = ['jade', 'sky', 'songhwa', 'pink', 'yellowgreen', 'white', 'sosaek'];
const ELITE_SKIRT = ['namsaek', 'scarlet', 'crimson', 'purple', 'teal', 'indigo', 'indigo_d', 'pink'];
const SKIN = ['#efd8b6', '#ecd2ac', '#e6c79e', '#e0bd92', '#d9b387', '#d1a77c', '#c99c70'];
const HAIR = ['#2c2724', '#231f1d', '#2f2620', '#38291f'];

// 고을(권역 앞 두 글자) — 물빛·쓰개·피부 쪽 치우침
export const REGIONS = {
  JL: { name: '전라(남원)', dye: 1.0, natural: 0.62, skin: 0.5 },
  GG: { name: '경기(한양)', dye: 1.25, natural: 0.55, skin: 0.35, elite: 1.6 },
  GS: { name: '경상(경주)', dye: 0.9, natural: 0.66, skin: 0.55 },
  GW: { name: '강원(강릉)', dye: 0.8, natural: 0.7, skin: 0.5, hemp: true },
  HH: { name: '황해(황주)', dye: 0.9, natural: 0.68, skin: 0.45, north: 0.3 },
  PA: { name: '평안(평양)', dye: 1.1, natural: 0.6, skin: 0.4, north: 0.45, eonjeun: 0.5 },
  HG: { name: '함경(함흥)', dye: 0.8, natural: 0.66, skin: 0.6, north: 0.7, fur: 0.4, eonjeun: 0.45 },
  JJ: { name: '제주', dye: 0.7, natural: 0.4, skin: 0.75, galot: 0.6 },
};

// ---------------------------------------------------------------------------
// 시드 난수
// ---------------------------------------------------------------------------
function hash32(str) { let h = 2166136261; for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
export function makeRng(key) {
  let a = hash32(String(key)) || 1;
  const R = () => { a |= 0; a = (a + 0x6d2b79f5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  R.range = (lo, hi) => lo + (hi - lo) * R();
  R.chance = (p) => R() < p;
  R.pick = (arr) => arr[Math.floor(R() * arr.length) % arr.length];
  /** 무게 있는 고르기: {값: 무게} */
  R.w = (tbl) => { let tot = 0; for (const k in tbl) tot += tbl[k]; let x = R() * tot; for (const k in tbl) { x -= tbl[k]; if (x <= 0) return k; } return Object.keys(tbl)[0]; };
  return R;
}
const r2 = (v) => Math.round(v * 100) / 100;

// ---------------------------------------------------------------------------
// 신분·직업 틀(template) — 무작위 범위
//   각 틀은 (R, reg) → spec 일부. 몸·얼굴·물감은 공통 규칙(아래 fill)으로 채운다.
// ---------------------------------------------------------------------------
const dye = (R, reg, cls) => {
  // cls: 'common' | 'elite' — 서민은 바탕(무명·삼베) 쪽으로 치우친다
  if (cls === 'elite') return DYES[R.pick(ELITE)];
  if (reg.galot && R.chance(reg.galot)) return DYES[R.chance(0.7) ? 'galot' : 'persimmon'];
  if (R.chance(reg.natural)) return DYES[reg.hemp && R.chance(0.4) ? 'hemp' : R.pick(NATURAL)];
  return DYES[R.pick(COMMON_DYE)];
};
const pants = (R, reg) => DYES[R.chance(0.8) ? R.pick(NATURAL) : R.pick(['indigo_l', 'ash', 'hemp'])];
const accent = (R) => DYES[R.pick(['indigo', 'indigo_d', 'brown', 'charcoal', 'persimmon'])];

export const TEMPLATES = {
  yangban_m: { label: '양반(남)', sex: 'm', age: { adult: 6, elder: 3 }, build: [0.92, 1.14], height: [1.62, 1.75], f: (R, reg, s) => {
    s.clothes = { top: 'jeogori', outer: R.chance(0.65) ? 'dopo' : 'durumagi', bottom: 'baji', sash: 'cord', shoes: 'taesahye', legwrap: false };
    s.colors = { coat: DYES[R.pick(['white', 'jade', 'sky', 'white', 'songhwa'])], cord: DYES[R.pick(['scarlet', 'namsaek', 'purple', 'black'])] };
    s.headwear = R.chance(0.85) ? 'gat' : 'jeongjagwan';
    s.items = { hand: R.w({ none: 4, fan: 3, longpipe: 2, cane: s.body.age === 'elder' ? 3 : 0 }) };
    s.face.beard = R.w({ none: 1, goatee: 3, full: 2, long: s.body.age === 'elder' ? 3 : 1 }); s.face.moustache = R.w({ thin: 2, full: 2, droop: 1 });
    s.wear = r2(R.range(0, 0.12)); s.dirt = r2(R.range(0, 0.08)); s.band = 'manggeon';
  } },
  yangban_f: { label: '양반(여)', sex: 'f', age: { youth: 2, adult: 5, elder: 2 }, build: [0.84, 1.0], height: [1.48, 1.6], f: (R, reg, s) => {
    s.clothes = { top: 'short', outer: R.chance(0.45) ? 'jangot' : 'none', bottom: 'chima', shoes: 'kkotsin' };
    s.colors = { coat: DYES[R.pick(['songhwa', 'jade', 'pink', 'yellowgreen', 'white', 'yellow'])], skirt: DYES[R.pick(ELITE_SKIRT)], cloak: DYES[R.pick(['teal', 'namsaek', 'yellowgreen', 'jade'])] };
    s.colors.goreum = DYES[R.pick(['crimson', 'purple', 'namsaek', 'scarlet'])]; s.colors.cuff = R.chance(0.6) ? s.colors.goreum : null; s.colors.collar = s.colors.goreum;
    s.hair = { style: reg.eonjeun && R.chance(reg.eonjeun) ? 'eonjeun' : 'jjok' };
    s.headwear = reg.north && R.chance(reg.north * 0.6) ? 'jobawi' : 'none';
    s.wear = r2(R.range(0, 0.1)); s.dirt = r2(R.range(0, 0.06));
  } },
  seonbi: { label: '선비', sex: 'm', age: { youth: 3, adult: 5 }, build: [0.86, 1.02], height: [1.6, 1.74], f: (R, reg, s) => {
    s.clothes = { top: 'jeogori', outer: R.chance(0.5) ? 'dopo' : 'durumagi', bottom: 'baji', sash: R.chance(0.6) ? 'cord' : 'none', shoes: R.pick(['taesahye', 'mituri']) };
    s.colors = { coat: DYES[R.pick(['white', 'white', 'jade', 'sky', 'sosaek'])], cord: DYES[R.pick(['namsaek', 'black', 'scarlet'])] };
    s.headwear = s.body.age === 'youth' && R.chance(0.3) ? 'none' : 'gat';
    if (s.body.age === 'youth' && s.headwear === 'none') s.hair = { style: 'tteokgeo' };
    s.items = { hand: R.w({ none: 3, fan: 3 }), back: R.chance(0.15) ? 'gwanari' : 'none' };
    s.face.beard = s.body.age === 'youth' ? 'none' : R.w({ none: 3, goatee: 2 }); s.face.moustache = s.body.age === 'youth' ? 'none' : R.w({ none: 2, thin: 3 });
    s.wear = r2(R.range(0.05, 0.35)); s.dirt = r2(R.range(0, 0.15)); s.band = 'manggeon';
  } },
  jungin: { label: '중인', sex: 'm', age: { adult: 6, elder: 1 }, build: [0.95, 1.12], height: [1.6, 1.72], f: (R, reg, s) => {
    s.clothes = { top: 'jeogori', outer: 'durumagi', bottom: 'baji', vest: R.chance(0.3) ? 'baeja' : 'none', shoes: 'mituri' };
    s.colors = { coat: DYES[R.pick(['indigo_l', 'ash', 'sosaek', 'sky', 'faded'])], vest: accent(R) };
    s.headwear = 'gat'; s.gatBrim = R.range(46, 54);
    s.items = { hand: R.w({ none: 4, fan: 1, longpipe: 1 }), back: R.chance(0.2) ? 'bundle' : 'none' };
    s.face.beard = R.w({ none: 2, goatee: 2, full: 1 }); s.face.moustache = R.w({ none: 1, thin: 2, full: 1 });
    s.wear = r2(R.range(0.05, 0.3)); s.dirt = r2(R.range(0, 0.15)); s.band = 'manggeon';
  } },
  ajeon: { label: '아전(서리)', sex: 'm', age: { adult: 6, elder: 1 }, build: [0.95, 1.12], height: [1.6, 1.72], f: (R, reg, s) => {
    s.clothes = { top: 'jeogori', outer: 'durumagi', bottom: 'baji', sash: R.chance(0.5) ? 'belt' : 'none', shoes: 'mituri', legwrap: R.chance(0.4) };
    s.colors = { coat: DYES[R.pick(['indigo', 'namsaek', 'indigo_d', 'ash', 'black'])], sash: DYES[R.pick(['indigo_d', 'black', 'crimson'])] };
    s.headwear = R.chance(0.6) ? 'gat' : 'beonggeoji'; s.gatBrim = 46;
    s.face.beard = R.w({ none: 1, goatee: 2, full: 1 }); s.face.moustache = R.w({ thin: 2, full: 1 });
    s.wear = r2(R.range(0.05, 0.3)); s.dirt = r2(R.range(0, 0.2)); s.band = 'manggeon';
  } },
  pojol: { label: '포졸·사령', sex: 'm', age: { youth: 1, adult: 6 }, build: [1.0, 1.18], height: [1.62, 1.76], f: (R, reg, s) => {
    s.clothes = { top: 'jeogori', outer: 'kwaeja', bottom: 'baji', sash: 'red', shoes: 'mituri', legwrap: true };
    s.colors = { coat: DYES[R.pick(['black', 'indigo_d', 'charcoal', 'namsaek'])], inner: DYES[R.pick(['white', 'sosaek', 'indigo_l'])], sash: DYES[R.pick(['scarlet', 'crimson'])] };
    s.headwear = R.chance(0.7) ? 'beonggeoji' : 'jeollip'; s.hatColor = R.pick(['#2b2622', '#3a3028', '#2e2a33']);
    s.items = { hand: R.chance(0.8) ? 'staff' : 'none' };
    s.face.beard = R.w({ none: 2, stubble: 3, full: 1 }); s.face.moustache = R.w({ none: 2, full: 1, droop: 1 });
    s.wear = r2(R.range(0.1, 0.4)); s.dirt = r2(R.range(0.05, 0.3));
  } },
  farmer: { label: '농부', sex: 'm', age: { youth: 2, adult: 6, elder: 1 }, build: [0.98, 1.2], height: [1.56, 1.72], f: (R, reg, s) => {
    s.clothes = { top: 'jeogori', outer: 'none', bottom: 'baji', vest: R.chance(reg.fur || 0) ? 'fur' : R.chance(0.3) ? 'baeja' : 'none', shoes: 'jipsin', legwrap: R.chance(0.6) };
    s.colors = { coat: dye(R, reg, 'common'), pants: pants(R, reg), vest: accent(R) };
    s.headwear = R.w({ band: 5, paeraengi: 2, satgat: 1, none: 2, nambawi: reg.north ? reg.north * 2 : 0 });
    s.items = { back: R.chance(0.35) ? 'jige' : 'none', load: R.pick(['straw', 'wood']), hand: R.chance(0.1) ? 'axe' : 'none' };
    s.face.beard = R.w({ none: 2, stubble: 4, goatee: 1, full: 1 }); s.face.moustache = R.w({ none: 3, thin: 1, droop: 1 });
    s.wear = r2(R.range(0.3, 0.85)); s.dirt = r2(R.range(0.25, 0.75));
  } },
  jangkkun: { label: '장꾼(상인)', sex: 'm', age: { youth: 1, adult: 6, elder: 1 }, build: [0.96, 1.16], height: [1.58, 1.72], f: (R, reg, s) => {
    s.clothes = { top: 'jeogori', outer: R.chance(0.25) ? 'durumagi' : 'none', bottom: 'baji', vest: R.chance(0.6) ? 'baeja' : 'none', shoes: R.pick(['jipsin', 'mituri']), legwrap: R.chance(0.5) };
    s.colors = { coat: dye(R, reg, 'common'), pants: pants(R, reg), vest: accent(R) };
    s.headwear = R.w({ gat: 3, paeraengi: 2, satgat: 2, band: 2 });
    s.items = { back: R.w({ none: 3, bundle: 2, jige: 2 }), hand: R.chance(0.15) ? 'longpipe' : 'none', handLoad: R.chance(0.35) ? 'bojagi' : 'none' };
    s.face.beard = R.w({ none: 2, stubble: 2, goatee: 2, full: 1 }); s.face.moustache = R.w({ none: 2, thin: 2, full: 1 });
    s.wear = r2(R.range(0.15, 0.6)); s.dirt = r2(R.range(0.1, 0.45)); s.band = s.headwear === 'gat' ? 'manggeon' : 'cloth';
  } },
  bobusang: { label: '보부상', sex: 'm', age: { adult: 6, elder: 1 }, build: [1.0, 1.18], height: [1.58, 1.72], f: (R, reg, s) => {
    s.clothes = { top: 'jeogori', bottom: 'baji', vest: R.chance(0.3) ? 'baeja' : 'none', shoes: 'jipsin', legwrap: true };
    s.colors = { coat: dye(R, reg, 'common'), pants: pants(R, reg), vest: accent(R) };
    s.headwear = 'paeraengi'; s.hatColor = R.pick(['#b89a5e', '#a88d58', '#c4a86d']);
    s.items = { back: R.chance(0.7) ? 'jige' : 'bundle', load: R.pick(['straw', 'wood']), hand: R.chance(0.5) ? 'staff' : 'none' };
    s.face.beard = R.w({ stubble: 3, goatee: 1, full: 1 }); s.wear = r2(R.range(0.3, 0.7)); s.dirt = r2(R.range(0.25, 0.6));
  } },
  traveler: { label: '나그네', sex: 'm', age: { youth: 1, adult: 5, elder: 2 }, build: [0.92, 1.12], height: [1.6, 1.74], f: (R, reg, s) => {
    s.clothes = { top: 'jeogori', outer: 'durumagi', bottom: 'baji', shoes: R.pick(['jipsin', 'mituri']), legwrap: true };
    s.colors = { coat: DYES[R.pick(['ash', 'faded', 'sosaek', 'indigo_l', 'greige'])], bundle: DYES[R.pick(['brown', 'indigo', 'persimmon', 'indigo_d'])] };
    s.headwear = R.w({ gat: 3, satgat: 2, paeraengi: 1 });
    s.items = { back: R.chance(0.7) ? 'gwanari' : 'bundle', hand: R.chance(0.6) ? 'staff' : 'none' };
    s.face.beard = R.w({ none: 1, stubble: 2, goatee: 2, full: 1 }); s.face.moustache = R.w({ none: 1, thin: 2 });
    s.wear = r2(R.range(0.2, 0.6)); s.dirt = r2(R.range(0.3, 0.7)); s.band = s.headwear === 'gat' ? 'manggeon' : 'cloth';
  } },
  boatman: { label: '뱃사공', sex: 'm', age: { adult: 5, elder: 2 }, build: [1.0, 1.18], height: [1.58, 1.72], f: (R, reg, s) => {
    s.clothes = { top: 'jeogori', bottom: 'baji', shoes: 'jipsin', legwrap: R.chance(0.4) };
    s.colors = { coat: dye(R, reg, 'common'), pants: pants(R, reg) };
    s.headwear = R.w({ satgat: 3, band: 3, none: 1 }); s.items = { hand: R.chance(0.6) ? 'staff' : 'none' };
    s.face.beard = R.w({ stubble: 3, full: 2, goatee: 1 }); s.wear = r2(R.range(0.3, 0.7)); s.dirt = r2(R.range(0.2, 0.5));
    s.face.skinBias = 0.35;
  } },
  jumo: { label: '주모', sex: 'f', age: { adult: 6, elder: 2 }, build: [1.0, 1.2], height: [1.5, 1.6], f: (R, reg, s) => {
    s.clothes = { top: 'short', bottom: 'chima', apron: R.chance(0.7), shoes: 'jipsin' };
    s.colors = { coat: dye(R, reg, 'common'), skirt: DYES[R.pick(['brown', 'indigo', 'persimmon', 'indigo_d', 'ash'])], goreum: accent(R) };
    s.colors.cuff = s.colors.goreum; s.colors.collar = s.colors.goreum;
    s.headwear = R.chance(0.55) ? 'meorisugeon' : 'none'; s.items = { hand: R.chance(0.45) ? 'ladle' : 'none', handLoad: R.chance(0.3) ? 'basket' : 'none' };
    s.face.wrinkles = R.pick([0, 1, 1, 2]); s.wear = r2(R.range(0.15, 0.5)); s.dirt = r2(R.range(0.1, 0.35));
  } },
  ajimae: { label: '아낙(상민 여)', sex: 'f', age: { youth: 2, adult: 6, elder: 1 }, build: [0.86, 1.08], height: [1.46, 1.6], f: (R, reg, s) => {
    s.clothes = { top: 'short', bottom: 'chima', apron: R.chance(0.15), shoes: 'jipsin', outer: R.chance(0.08) ? 'sseugae' : 'none' };
    s.colors = { coat: dye(R, reg, 'common'), skirt: DYES[R.pick(['indigo', 'brown', 'indigo_l', 'ash', 'indigo_d', 'persimmon', 'faded'])], goreum: accent(R), cloak: DYES[R.pick(['indigo_l', 'white', 'jade'])] };
    if (R.chance(0.5)) { s.colors.cuff = s.colors.goreum; s.colors.collar = s.colors.goreum; }
    s.hair = { style: s.body.age === 'youth' && R.chance(0.6) ? 'daenggi' : reg.eonjeun && R.chance(reg.eonjeun) ? 'eonjeun' : 'jjok' };
    s.headwear = R.w({ none: 4, meorisugeon: 3, jobawi: reg.north ? reg.north * 2 : 0 });
    s.items = { head: R.w({ none: 5, basket: 2, jar: 2 }), handLoad: R.chance(0.3) ? R.pick(['basket', 'bojagi']) : 'none' };
    s.wear = r2(R.range(0.15, 0.6)); s.dirt = r2(R.range(0.1, 0.45));
  } },
  haenyeo: { label: '해녀', sex: 'f', age: { youth: 1, adult: 5, elder: 2 }, build: [0.95, 1.12], height: [1.46, 1.58], f: (R, reg, s) => {
    s.clothes = { top: 'short', bottom: 'chima', shoes: 'jipsin' };
    s.colors = { coat: DYES[R.pick(['white', 'sosaek'])], skirt: DYES[R.pick(['white', 'faded', 'galot'])], goreum: DYES.faded };
    s.headwear = 'meorisugeon'; s.colors.scarf = DYES.white; s.items = { handLoad: R.chance(0.4) ? 'basket' : 'none', head: R.chance(0.15) ? 'basket' : 'none' };
    s.face.skinBias = 0.5; s.wear = r2(R.range(0.2, 0.5)); s.dirt = r2(R.range(0.05, 0.25));
  } },
  cheonmin: { label: '천민(노비·백정)', sex: 'm', age: { youth: 2, adult: 5, elder: 1 }, build: [0.9, 1.16], height: [1.54, 1.7], f: (R, reg, s) => {
    s.clothes = { top: 'jeogori', bottom: 'baji', shoes: R.pick(['jipsin', 'jipsin', 'beoseon']), legwrap: R.chance(0.3) };
    s.colors = { coat: DYES[R.pick(['hemp', 'greige', 'faded', 'brown'])], pants: DYES[R.pick(['hemp', 'greige', 'faded'])] };
    s.headwear = R.w({ paeraengi: 3, band: 2, none: 2 }); s.hatColor = '#8f7848';
    if (s.body.age === 'youth' || R.chance(0.25)) s.hair = { style: 'tteokgeo' };
    s.items = { back: R.chance(0.3) ? 'jige' : 'none', load: 'wood' };
    s.face.beard = R.w({ none: 2, stubble: 3, full: 1 }); s.wear = r2(R.range(0.55, 1)); s.dirt = r2(R.range(0.45, 0.9));
  } },
  monk: { label: '승려', sex: 'm', age: { youth: 1, adult: 5, elder: 2 }, build: [0.9, 1.1], height: [1.6, 1.72], f: (R, reg, s) => {
    s.clothes = { top: 'jeogori', outer: 'jangsam', bottom: 'baji', sash: R.chance(0.55) ? 'gasa' : 'none', shoes: 'jipsin', legwrap: true };
    s.colors = { coat: DYES[R.pick(['ash', 'ash', 'charcoal', 'greige'])], gasa: DYES[R.pick(['crimson', 'persimmon', 'brown'])] };
    s.hair = { style: 'shaved' }; s.headwear = R.chance(0.4) ? 'satgat' : 'none';
    s.items = { hand: R.chance(0.45) ? 'staff' : 'none', back: R.chance(0.35) ? 'bundle' : 'none' };
    s.colors.bundle = DYES.ash; s.face.beard = 'none'; s.face.moustache = 'none'; s.wear = r2(R.range(0.1, 0.45)); s.dirt = r2(R.range(0.05, 0.3));
  } },
  mudang: { label: '무당', sex: 'f', age: { adult: 5, elder: 3 }, build: [0.92, 1.14], height: [1.48, 1.6], f: (R, reg, s) => {
    s.clothes = { top: 'short', bottom: 'chima', outer: R.chance(0.5) ? 'kwaeja' : 'none', shoes: 'jipsin' };
    s.colors = { coat: DYES[R.pick(['white', 'yellow', 'songhwa'])], skirt: DYES[R.pick(['scarlet', 'crimson', 'namsaek'])], inner: DYES[R.pick(['yellow', 'white'])], goreum: DYES[R.pick(['namsaek', 'scarlet'])] };
    s.colors.cuff = s.colors.goreum; s.colors.collar = s.colors.goreum;
    if (s.clothes.outer === 'kwaeja') s.colors.coat = DYES[R.pick(['namsaek', 'scarlet', 'teal'])];
    s.headwear = R.w({ none: 3, jeollip: 1, meorisugeon: 1 }); s.items = { hand: R.pick(['fan', 'bell', 'roundfan']) };
    s.face.wrinkles = R.pick([0, 1, 2]); s.wear = r2(R.range(0.1, 0.4)); s.dirt = r2(R.range(0, 0.2));
  } },
  gisaeng: { label: '기생', sex: 'f', age: { youth: 4, adult: 3 }, build: [0.82, 0.94], height: [1.48, 1.58], f: (R, reg, s) => {
    s.clothes = { top: 'short', bottom: 'chima', outer: R.chance(0.3) ? 'jangot' : 'none', shoes: 'kkotsin' };
    s.colors = { coat: DYES[R.pick(['jade', 'pink', 'songhwa', 'sky', 'yellow'])], skirt: DYES[R.pick(ELITE_SKIRT)], goreum: DYES[R.pick(['crimson', 'purple', 'namsaek'])], cloak: DYES[R.pick(['teal', 'yellowgreen', 'purple'])] };
    s.colors.cuff = s.colors.goreum; s.colors.collar = s.colors.goreum;
    s.hair = { style: 'eonjeun' }; s.headwear = R.chance(0.15) ? 'jokduri' : 'none'; s.items = { hand: R.chance(0.35) ? 'roundfan' : 'none' };
    s.face.cheek = r2(R.range(0.3, 0.4)); s.face.lip = '#b8323a'; s.wear = r2(R.range(0, 0.1)); s.dirt = 0;
  } },
  child: { label: '아이', sex: null, age: { child: 1 }, build: [0.9, 1.1], height: [0.98, 1.2], f: (R, reg, s) => {
    const m = s.body.sex === 'm';
    s.clothes = { top: m ? 'jeogori' : 'short', bottom: m ? 'baji' : 'chima', shoes: R.pick(['jipsin', 'jipsin', 'beoseon']), vest: m && R.chance(0.35) ? 'baeja' : 'none' };
    s.colors = { coat: R.chance(0.2) ? DYES[R.pick(['gardenia', 'pink', 'yellowgreen'])] : dye(R, reg, 'common'), pants: DYES[R.pick(['ocher', 'faded', 'sosaek', 'indigo_l'])],
      skirt: DYES[R.pick(['scarlet', 'indigo', 'brown', 'indigo_l', 'persimmon'])], vest: DYES[R.pick(['crimson', 'indigo', 'brown'])], goreum: DYES[R.pick(['purple', 'scarlet', 'indigo'])],
      ribbon: DYES[R.pick(['crimson', 'purple', 'scarlet'])] };
    s.hair = { style: m ? R.w({ bowl: 3, tteokgeo: 1, short: 2 }) : 'daenggi' };
    s.headwear = 'none'; s.face.cheek = r2(R.range(0.3, 0.42)); s.wear = r2(R.range(0.1, 0.6)); s.dirt = r2(R.range(0.1, 0.6));
  } },
  elder_m: { label: '노인(남)', sex: 'm', age: { elder: 1 }, build: [0.84, 1.02], height: [1.52, 1.66], f: (R, reg, s) => {
    s.clothes = { top: 'jeogori', outer: R.chance(0.6) ? 'durumagi' : 'none', bottom: 'baji', shoes: R.pick(['jipsin', 'mituri']), legwrap: R.chance(0.3) };
    s.colors = { coat: DYES[R.pick(['white', 'sosaek', 'faded', 'ash'])], pants: DYES[R.pick(NATURAL)] };
    s.headwear = R.w({ gat: 3, none: 2, band: 1, nambawi: reg.north ? 2 : 0.3 });
    s.items = { hand: R.w({ cane: 5, none: 2, longpipe: 1 }) }; s.pipe = R.chance(0.25);
    s.face.beard = R.w({ long: 4, goatee: 2, full: 1 }); s.face.moustache = R.w({ full: 2, droop: 2, thin: 1 });
    s.wear = r2(R.range(0.1, 0.5)); s.dirt = r2(R.range(0, 0.3)); s.band = s.headwear === 'gat' ? 'manggeon' : 'cloth';
  } },
  elder_f: { label: '노인(여)', sex: 'f', age: { elder: 1 }, build: [0.84, 1.04], height: [1.4, 1.54], f: (R, reg, s) => {
    s.clothes = { top: 'short', bottom: 'chima', shoes: 'jipsin' };
    s.colors = { coat: DYES[R.pick(['white', 'sosaek', 'faded'])], skirt: DYES[R.pick(['ash', 'indigo_d', 'brown', 'charcoal'])], goreum: DYES[R.pick(['indigo_d', 'brown'])] };
    s.headwear = R.w({ none: 3, meorisugeon: 2, jobawi: reg.north ? 2 : 0.3 }); s.items = { hand: R.chance(0.5) ? 'cane' : 'none', head: R.chance(0.1) ? 'basket' : 'none' };
    s.wear = r2(R.range(0.15, 0.5)); s.dirt = r2(R.range(0.05, 0.3));
  } },
};

// ---------------------------------------------------------------------------
// 공통 채우기(몸·얼굴·머리)
// ---------------------------------------------------------------------------
function fill(R, reg, tpl, opt) {
  const T = TEMPLATES[tpl];
  const sex = T.sex || (R.chance(0.5) ? 'm' : 'f');
  const age = R.w(T.age);
  const s = { template: tpl, region: opt.region || 'JL', seed: opt.seed, role: opt.role || tpl };
  const height = r2(R.range(...T.height) - (age === 'elder' ? 0.03 : 0));
  s.body = { sex, age, build: r2(R.range(...T.build)), height, stoop: age === 'elder' ? r2(R.range(0.1, 0.3)) : r2(R.chance(0.12) ? R.range(0.03, 0.1) : 0),
    head: r2(R.range(0.94, 1.07)), legs: r2(R.range(0.95, 1.04)) };
  const skinI = Math.max(0, Math.min(SKIN.length - 1, Math.round(R.range(0, 4.2) + (reg.skin - 0.5) * 3)));
  s.face = {
    shape: R.pick(OPTIONS.faceShape), brows: R.pick(OPTIONS.brows), eyes: R.w({ narrow: 4, round: 1, droopy: 2, upturned: 2, sleepy: 1, small: 2 }),
    eyeSize: r2(R.range(0.88, 1.12)), eyeGap: r2(R.range(0.38, 0.46)), nose: R.w({ small: 4, long: 2, broad: 2, hooked: 1 }),
    mouth: R.w({ small: 4, wide: 2, thin: 2, full: 1, smile: 1, frown: 1 }), wrinkles: age === 'elder' ? R.pick([2, 3, 3]) : age === 'adult' ? R.pick([0, 0, 1, 1, 2]) : 0,
    mark: R.w({ none: 7, mole_cheek: 1, mole_lip: 0.6, mole_brow: 0.5, pockmark: 0.8, freckles: 0.6, scar: sex === 'm' ? 0.4 : 0 }),
    beard: 'none', moustache: 'none', skin: SKIN[skinI], cheek: r2(sex === 'f' ? R.range(0.18, 0.32) : R.range(0.1, 0.22)),
    browW: r2(R.range(0.85, 1.2)), mouthY: r2(R.range(0.57, 0.64)),
  };
  const gray = age === 'elder' ? R.pick(['#d9d5cc', '#b9b4aa', '#8a857c', '#cfcac0']) : null;
  s.hair = { style: sex === 'm' ? (age === 'youth' && R.chance(0.35) ? 'tteokgeo' : 'sangtu') : (age === 'youth' && R.chance(0.6) ? 'daenggi' : 'jjok'), color: gray || R.pick(HAIR) };
  s.colors = {}; s.items = {}; s.headwear = 'none';
  T.f(R, reg, s);
  // 혼인 전 머리(떠꺼머리·댕기)에는 갓·관을 쓰지 않는다
  if (['tteokgeo', 'daenggi'].includes(s.hair.style) && ['gat', 'jeongjagwan', 'samo', 'jokduri'].includes(s.headwear)) s.headwear = 'none';
  if (s.face.skinBias) { const i = Math.min(SKIN.length - 1, skinI + Math.round(s.face.skinBias * 3)); s.face.skin = SKIN[i]; delete s.face.skinBias; }
  if (gray && !s.face.beardColor) s.face.beardColor = gray;
  s.hair.color = s.hair.color || gray || R.pick(HAIR);
  // 물감 바래기(해짐)
  return s;
}

export function generate({ template = 'farmer', region = 'JL', seed = 1, count = 1, idPrefix = null }) {
  const reg = REGIONS[(region || 'JL').slice(0, 2)] || REGIONS.JL;
  const out = [];
  for (let i = 0; i < count; i++) {
    const R = makeRng(`${template}|${region}|${seed}|${i}`);
    const s = fill(R, reg, template, { region: region.slice(0, 2), seed: `${seed}.${i}` });
    s.id = (idPrefix || `${region.slice(0, 2).toLowerCase()}_${template}_${seed}`) + '_' + i;
    out.push(s);
  }
  return out;
}

// ---------------------------------------------------------------------------
// 자료 → 리그 차림(SPECS)
// ---------------------------------------------------------------------------
const lerp = (a, b, t) => a + (b - a) * t;
function skeleton(body) {
  const A = H.ADULT, C = H.CHILD, age = body.age || 'adult';
  let B;
  if (age === 'child') B = { ...C };
  else if (age === 'youth') { B = {}; for (const k in A) B[k] = lerp(C[k], A[k], 0.8); }
  else B = { ...A };
  const b = body.build || 1, hd = body.head || 1, lg = body.legs || 1;
  const S = { ...B, shHalf: B.shHalf * b, waistHalf: B.waistHalf * b, legX: B.legX * (0.5 + b * 0.5) };
  if (hd !== 1) { S.headRX = B.headRX * hd; S.headRY = B.headRY * hd; }
  if (lg !== 1) { S.hip = B.hip * lg; S.thigh = B.thigh * lg; S.shin = B.shin * lg; }
  return S;
}
const SHAPE_HEAD = { oval: [1, 1], round: [1.05, 0.97], long: [0.95, 1.05], square: [1.03, 0.99], heart: [0.98, 1.01] };
const SHOE = { jipsin: '#b99a62', mituri: '#9a8460', taesahye: '#2b2622', kkotsin: '#6e2a5c', beoseon: '#f3efe4' };

/** 빌더 자료 → rigs SPECS 꼴 */
export function compile(spec) {
  const b = spec.body || {}, F = { ...(spec.face || {}) }, C = spec.clothes || {}, K = spec.colors || {}, I = spec.items || {};
  const child = b.age === 'child', female = b.sex === 'f';
  const wear = spec.wear || 0;
  const fade = (c) => (c && wear > 0.05 ? mix(c, '#e6dec8', Math.min(0.35, wear * 0.3)) : c);
  const S = skeleton(b);
  const sh = SHAPE_HEAD[F.shape] || [1, 1];
  S.headRX *= sh[0]; S.headRY *= sh[1];
  const outer = C.outer || 'none';
  const robe = ['durumagi', 'dopo', 'kwaeja', 'jangsam'].includes(outer);
  const coat = fade(K.coat || (female ? '#e6d6a6' : '#d8c9a3'));
  const sp = {
    type: 'human', child, height: b.height || (child ? 1.1 : female ? 1.56 : 1.66), radius: child ? 0.25 : 0.3, S,
    stoop: b.stoop || 0, build: b.build || 1,
    top: robe ? 'durumagi' : C.top === 'short' ? 'short' : 'jeogori',
    coat, collar: K.collar ? fade(K.collar) : undefined, goreum: K.goreum, cuff: K.cuff || undefined,
    pants: fade(K.pants || (robe ? '#e4dccb' : '#ddd3bb')),
    skin: F.skin, lip: F.lip || (female ? '#a8453c' : '#9c4a40'), cheek: F.cheek, face: F,
    hairStyle: spec.hair?.style || 'sangtu', hairColor: spec.hair?.color,
    headwear: spec.headwear || 'none', hatColor: spec.hatColor, gatBrim: spec.gatBrim, scarf: K.scarf,
    shoe: SHOE[C.shoes] || SHOE.jipsin, sock: '#f3efe4',
    drawHead: builderHead,
    sitStyle: female ? 'knee' : undefined,   // 땅에 앉기: 여인은 한쪽 무릎을 세운다(pose_common)
  };
  if (C.bottom === 'chima') { sp.bottom = 'chima'; sp.skirt = fade(K.skirt || '#46627b'); }
  if (robe) sp.robeLen = outer === 'jangsam' || outer === 'dopo' ? 104 : outer === 'kwaeja' ? 92 : 98;
  if (robe && C.robeLen) sp.robeLen = C.robeLen;
  if (outer === 'dopo') sp.sleeveW = 1.45;
  if (outer === 'jangsam') sp.sleeveW = 1.5;
  if (outer === 'kwaeja') { sp.armCoat = fade(K.inner || '#ece6d6'); sp.collar = sp.collar || sp.armCoat; }
  if (outer === 'jangot' || outer === 'sseugae') { sp.cloak = outer; sp.cloakColor = fade(K.cloak || (outer === 'jangot' ? '#4f6b52' : '#8fa3b0')); }
  if (C.vest === 'baeja' || C.vest === 'fur') { sp.vest = fade(K.vest || '#5f7688'); if (C.vest === 'fur') { sp.fur = true; sp.vest = K.vest || '#b98a4e'; } }
  if (C.apron) sp.apron = '#efe9da';
  if (C.sash === 'red') sp.sash = K.sash || '#a8443c';
  else if (C.sash === 'belt') sp.sash = K.sash || '#3a3436';
  else if (C.sash === 'cord') sp.cord = K.cord || '#8a2f37';
  else if (C.sash === 'gasa') sp.gasa = K.gasa || '#8a2f37';
  if (C.legwrap) { sp.legwrap = '#ece6d6'; sp.daenim = K.daenim || accentFor(K); }
  else if (!female || C.bottom !== 'chima') sp.daenim = K.daenim || accentFor(K);
  // 머리
  const hs = sp.hairStyle;
  if (hs === 'daenggi' || hs === 'tteokgeo') { sp.hair = 'braid'; sp.ribbon = K.ribbon || (hs === 'tteokgeo' ? '#2a2420' : '#8a2f37'); }
  if (hs === 'sangtu') {
    const bandKind = spec.band || (sp.headwear === 'band' ? 'cloth' : ['gat', 'jeongjagwan', 'samo'].includes(sp.headwear) ? 'manggeon' : 'cloth');
    if (sp.headwear === 'band' || bandKind === 'cloth') sp.band = K.band || '#efe9da';
    if (bandKind === 'manggeon') sp.band = '#2a2622';
    if (bandKind === 'none') delete sp.band;
  }
  // 소품
  if (I.back === 'jige') { sp.back = 'jige'; sp.load = I.load || 'straw'; }
  else if (I.back === 'bundle' || I.back === 'gwanari') { sp.back = 'bundle'; sp.bundle = K.bundle || '#6b4f3a'; if (I.back === 'gwanari') sp.bundleScale = 0.66; }
  if (I.head === 'basket' || I.head === 'jar') sp.carry = I.head;
  if (I.hand && I.hand !== 'none') { sp.staff = handItem(I.hand); sp.handSmall = ['fan', 'roundfan', 'longpipe', 'ladle', 'bell'].includes(I.hand); }
  if (I.handLoad && I.handLoad !== 'none') { sp.handLoad = I.handLoad; sp.bundle = sp.bundle || K.bundle || '#6b4f3a'; }
  if (spec.pipe) sp.pipe = true;
  if (K.patch) sp.patch = K.patch;
  else if (wear > 0.35 && !female) sp.patch = mix(sp.pants, '#8a7452', 0.35);
  sp.dirt = spec.dirt || 0;
  wearFx(sp, hashSeed(spec.id || 'x'));
  return sp;
}
function accentFor(K) { return K.vest || K.goreum || '#7d6a55'; }
function hashSeed(s) { let h = 7; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0; return h; }

/** 자료를 리그 종류로 올린다(같은 id면 새로 — 편집기에서 바꿀 때) → id */
export function registerSpec(spec) {
  const id = spec.id || 'builder_tmp';
  dropRig(id);
  SPECS[id] = compile(spec);
  const rig = getRig(id);
  extraParts(rig);
  rig._poses = false;
  installPoses(id);
  return id;
}

// ---------------------------------------------------------------------------
// 기존 인물을 빌더 자료로(같은 사람으로 읽히게 — 색·키·체형·차림을 웹 SPECS·굽기 표에서 그대로)
// ---------------------------------------------------------------------------
const plainFace = (o = {}) => ({ shape: 'oval', brows: 'thin', eyes: 'narrow', nose: 'small', mouth: 'small', wrinkles: 0, mark: 'none', beard: 'none', moustache: 'none', ...o });
export const PRESETS = {
  jumo: { id: 'p_jumo', name: '주모(innkeeper)', template: 'jumo', role: 'innkeeper',
    body: { sex: 'f', age: 'adult', build: 1.14, height: 1.58 },
    face: plainFace({ wrinkles: 1, cheek: 0.24, lip: '#a04a3e' }), hair: { style: 'jjok' },
    clothes: { top: 'short', bottom: 'chima', apron: true, shoes: 'jipsin' },
    colors: { coat: '#e4d9bd', skirt: '#8e5a48', goreum: '#5d7488', cuff: '#5d7488', collar: '#5d7488', scarf: '#e9e2cf' },
    headwear: 'meorisugeon', items: { hand: 'ladle' }, wear: 0, dirt: 0 },
  bangja: { id: 'p_bangja', name: '방자(bangja)', template: 'cheonmin', role: 'bangja',
    body: { sex: 'm', age: 'adult', build: 1.0, height: 1.6 },
    face: plainFace({ cheek: 0.36 }), hair: { style: 'sangtu' },
    clothes: { top: 'jeogori', bottom: 'baji', shoes: 'jipsin', legwrap: true },
    colors: { coat: '#d8c38c', pants: '#e2d8bf', collar: '#8a6e48', daenim: '#8a6e48' },
    headwear: 'beonggeoji', hatColor: '#3a3028', band: 'none', items: {}, wear: 0, dirt: 0 },
  pojol: { id: 'p_pojol', name: '포졸(pojol)', template: 'pojol', role: 'pojol',
    body: { sex: 'm', age: 'adult', build: 1.08, height: 1.65 },
    face: plainFace({ beard: 'stubble', cheek: 0.2 }), hair: { style: 'sangtu' },
    clothes: { top: 'jeogori', outer: 'durumagi', bottom: 'baji', sash: 'red', shoes: 'jipsin', legwrap: true, robeLen: 84 },
    colors: { coat: '#2f3138', pants: '#d9d2c0', collar: '#1f2026', goreum: '#1f2026', sash: '#a8443c' },
    headwear: 'beonggeoji', hatColor: '#2b2622', band: 'none', items: { hand: 'staff' }, wear: 0, dirt: 0 },
  villager: { id: 'p_villager', name: '마을 사내(villager_m)', template: 'farmer', role: 'villager_m',
    body: { sex: 'm', age: 'adult', build: 1.12, height: 1.65 },
    face: plainFace({ beard: 'stubble', cheek: 0.2 }), hair: { style: 'sangtu' },
    clothes: { top: 'jeogori', bottom: 'baji', vest: 'baeja', shoes: 'jipsin' },
    colors: { coat: '#d8c9a3', pants: '#ddd3bb', vest: '#5f7688', collar: '#b9a782', daenim: '#5f7688', patch: '#b8a47c' },
    headwear: 'band', items: { back: 'jige', load: 'straw' }, wear: 0, dirt: 0 },
};
// 방자: 예전 리그(villager_m)의 바지 덧댐 색을 그대로
PRESETS.bangja.colors.patch = '#bfa878';

/** 'jumo' → 프리셋, 'farmer#12' → generate 하나, 'farmer#12@GG' → 고을 지정 */
export function specFromToken(tok) {
  if (PRESETS[tok]) return structuredClone(PRESETS[tok]);
  const m = /^([a-z_]+)#(\d+)(?:@([A-Z]{2}))?$/.exec(tok);
  if (!m) throw new Error('builder token? ' + tok);
  return generate({ template: m[1], region: m[3] || 'JL', seed: +m[2], count: 1 })[0];
}

// ---------------------------------------------------------------------------
// 고을 사람 무리(step 3): 권역마다 이 구성으로 시드를 돌린다 — 역할(npc_ambient 종류) → 틀
// ---------------------------------------------------------------------------
export const ROLE_TEMPLATE = {
  villager_m: 'farmer', farmer: 'farmer', villager_f: 'ajimae', farmwife: 'ajimae', merchant: 'jangkkun', peddler: 'bobusang', traveler: 'traveler',
  scholar: 'seonbi', official: 'ajeon', pojol: 'pojol', innkeeper: 'jumo', monk: 'monk', elder: 'elder_m', elder_f: 'elder_f',
  child_boy: 'child', child_girl: 'child', boatman: 'boatman', haenyeo: 'haenyeo', shaman: 'mudang', yangban: 'yangban_m', yangban_f: 'yangban_f',
  gisaeng: 'gisaeng', jungin: 'jungin', cheonmin: 'cheonmin',
};
// 권역 무리 구성(역할: 수) — 합 40 이하(공간당 고유 인물 상한)
export const POOL = {
  base: { farmer: 5, farmwife: 5, merchant: 4, villager_m: 3, villager_f: 3, elder: 2, elder_f: 2, child_boy: 2, child_girl: 2, scholar: 2, official: 2,
    peddler: 2, traveler: 2, innkeeper: 1, monk: 1, cheonmin: 1, yangban: 1, boatman: 1 },
  GG: { farmer: -2, farmwife: -1, scholar: 1, yangban: 1, yangban_f: 1, jungin: 1, official: 1, pojol: 1, gisaeng: 1, merchant: 1 },
  JJ: { farmwife: -2, haenyeo: 3, boatman: 1, scholar: -1, yangban: -1, merchant: -1, shaman: 1 },
  PA: { gisaeng: 1, merchant: 1, farmer: -1, boatman: 1 },
  HH: { boatman: 1 }, GS: { yangban: 1 }, GW: { boatman: 1 }, HG: { cheonmin: 1 }, JL: { gisaeng: 1, pojol: 1, farmer: -1 },
};
export const POOL_CAP = 36;
export function poolPlan(region) {
  const plan = { ...POOL.base };
  for (const [k, v] of Object.entries(POOL[region] || {})) plan[k] = Math.max(0, (plan[k] || 0) + v);
  // 상한: 공간당 고유 인물 POOL_CAP — 넘으면 가장 많은 역할부터 하나씩 덜어 낸다
  let tot = Object.values(plan).reduce((a, b) => a + b, 0);
  while (tot > POOL_CAP) { const k = Object.keys(plan).sort((a, b) => plan[b] - plan[a] || (a < b ? -1 : 1))[0]; plan[k]--; tot--; }
  return plan;
}
/** 권역 무리 자료: 역할마다 시드 하나씩 */
export function poolSpecs(region) {
  const out = [];
  for (const [role, n] of Object.entries(poolPlan(region))) {
    for (let i = 0; i < n; i++) {
      const tpl = ROLE_TEMPLATE[role];
      const R = makeRng(`pool|${region}|${role}|${i}`);
      const sp = fill(R, REGIONS[region] || REGIONS.JL, tpl, { region, seed: `${role}.${i}`, role });
      if (role === 'child_boy') { sp.body.sex = 'm'; }
      if (role === 'child_girl') { sp.body.sex = 'f'; }
      if (role === 'child_boy' || role === 'child_girl') { const R2 = makeRng(`pool2|${region}|${role}|${i}`); TEMPLATES.child.f(R2, REGIONS[region] || REGIONS.JL, sp); }
      sp.id = `${region.toLowerCase()}_${role}_${i}`;
      sp.role = role;
      out.push(sp);
    }
  }
  return out;
}
