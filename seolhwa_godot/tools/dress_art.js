// 춘향 PART II 차림 부속(먹선·한지·평면 채색 — 웹 rigs.js 그림 방식 그대로, 웹 코드는 고치지 않는다).
//   칼(枷) · 풀어 헤친 머리 · 파립(찢어진 갓) · 누더기 덧댐 · 마패(손에 든 소품) · 사모 · 단령 둥근 깃 · 흉배 · 각대 · 검은 수염 · 얹은머리 · 술병(시중)
// 부속은 리그의 부위로 붙는다(머리·몸통·손을 따라 움직임 — hum_combat_light.attachHand와 같은 방식).
// PART2: 굽기 세트 ?set=chunhyang_part2 의 종류(바탕 rig + 색 + 부속). export_story_frames.js가 ensurePart2 → installPoses → installDress 순서로 부른다.
import { SPECS, getRig } from '/src/chars/rigs.js';
import { Painter, shade, ellipsePts } from '/src/chars/painter.js';

const { sin, cos, PI } = Math;
export const PART2 = {
  // 성춘향(옥): 흰 무명 저고리·치마, 풀어 헤친 머리, 목에 칼
  chunhyang_prison: { base: 'villager_f', over: { coat: '#ebe6da', skirt: '#e2dccd', goreum: '#d6cfbe', cuff: '#ddd6c6', collar: '#d6cfbe', hair: null, ribbon: null,
    carry: null, scarf: null, build: 0.86, height: 1.55, cheek: 0.12, lip: '#9a5048', skin: '#ecd3b8' }, dress: ['loose_hair', 'cangue'],
    anims: ['idle', 'walk', 'talk', 'sit', 'kneel', 'bow'] },
  // 이몽룡(거지 차림): 바랜 도포에 덧댄 누더기, 파립, 흙빛 행전. 출두 때 마패를 든다(mapae)
  mongryong_beggar: { base: 'villager_m', over: { top: 'durumagi', coat: '#a69c86', pants: '#b3a78f', collar: '#6c6253', goreum: '#6c6253', vest: null, daenim: '#6c6253',
    back: null, patch: '#857660', hat: null, stubble: true, robeLen: 96, build: 0.95, height: 1.68, cheek: 0.1, shoe: '#5a4a38', legwrap: '#c9bfa8' },
    dress: ['parip', 'rags', 'mapae'], anims: ['idle', 'walk', 'run', 'talk', 'sit', 'bow', 'kneel', 'mapae'] },
  // 변학도: 홍단령 · 사모 · 흉배 · 각대, 검은 수염. sit = 교의에 앉음(대청), stand는 Godot에서 idle
  byeon: { base: 'villager_m', over: { top: 'durumagi', coat: '#8a2f37', pants: '#d9d2c0', collar: '#5e1f26', goreum: '#5e1f26', vest: null, daenim: null, sash: null,
    back: null, patch: null, hat: null, hair: 'sangtu', band: null, stubble: false, robeLen: 108, build: 1.16, height: 1.7, cheek: 0.2, shoe: '#2b2622', legwrap: null },
    dress: ['samo', 'dallyeong', 'black_beard'], chairSit: true, anims: ['idle', 'walk', 'talk', 'sit', 'bow', 'kneel', 'cower'] },
  // 기생(generic, 3색): 얹은머리 · 회장저고리 · 쪽빛/자줏빛/남빛 치마. serve = 술병을 들고 따름
  gisaeng: { base: 'villager_f', over: { coat: '#cfe6dc', skirt: '#2f4876', goreum: '#8c2f5c', cuff: '#8c2f5c', collar: '#8c2f5c', hair: null, carry: null, scarf: null,
    build: 0.86, height: 1.54, cheek: 0.34, lip: '#b8323a' }, dress: ['eonjeun', 'jug'], anims: ['idle', 'walk', 'talk', 'sit', 'bow', 'kneel', 'serve'] },
  gisaeng_b: { base: 'villager_f', over: { coat: '#f3d2cc', skirt: '#6e2a5c', goreum: '#2f4876', cuff: '#2f4876', collar: '#2f4876', hair: null, carry: null, scarf: null,
    build: 0.85, height: 1.52, cheek: 0.36, lip: '#b8323a' }, dress: ['eonjeun', 'jug'], anims: ['idle', 'walk', 'talk', 'sit', 'bow', 'kneel', 'serve'] },
  gisaeng_c: { base: 'villager_f', over: { coat: '#f1e7b8', skirt: '#3e6f6a', goreum: '#a3334a', cuff: '#a3334a', collar: '#a3334a', hair: null, carry: null, scarf: null,
    build: 0.88, height: 1.56, cheek: 0.32, lip: '#b8323a' }, dress: ['eonjeun', 'jug'], anims: ['idle', 'walk', 'talk', 'sit', 'bow', 'kneel', 'serve'] },
};
// 이 세트만의 동작(공용 자세 sit·bow·kneel은 pose_common.js)
export const DRESS_ANIMS = { serve: { dur: 2.4, loop: true }, mapae: { dur: 2.0, loop: true } };

export function ensurePart2(kind) {
  const P = PART2[kind];
  const sp = { ...SPECS[P.base] };
  for (const k in P.over) { if (P.over[k] === null) delete sp[k]; else sp[k] = P.over[k]; }
  SPECS[kind] = sp;
  return sp;
}

const INKC = '#1f1a17';
const headY = (S) => -(S.neck + S.headRY) - 4 * S.ws;
function addPart(rig, view, part) {
  const parts = rig.views[view];
  parts.push({ r0: 0, abs: false, tag: null, flip: false, far: false, ...part });
  parts.draw = parts.filter((p) => p.img).map((p, i) => ({ p, i })).sort((a, b) => a.p.z - b.p.z || a.i - b.i).map((e) => e.p);
}
function paint(seed, fn, size = 768) {
  const P = new Painter(size);
  P.begin(seed);
  fn(P);
  return P.end();
}
const zOf = (rig, view, name) => (rig.views[view].find((p) => p.name === name) || { z: 0 }).z;

// ---------------------------------------------------------------------------
// 머리 부속(head 부위 좌표 — drawHead와 같은 hy·cx)
// ---------------------------------------------------------------------------
function looseHair(p, view, S, sp) {
  const ws = S.ws, rx = S.headRX, ry = S.headRY, hy = headY(S), hc = sp.hairColor || '#2a2420';
  const side = view === 'side', back = view === 'back';
  const cx = side ? 2 * ws : 0;
  const streak = (pts) => p.stroke(pts, { w: 1.1, color: shade(hc, 0.3), rough: 0.4 });
  if (side) {
    // 정수리 뒤에서 등 가운데까지 흘러내린 머리(끝이 들쭉날쭉)
    const path = p.poly([[cx - rx * 0.3, hy - ry - 2], [cx + rx * 0.6, hy - ry * 0.9], [cx + rx + 5, hy - ry * 0.2], [cx + rx + 9, hy + ry * 0.9],
      [cx + rx + 12, 40 * ws], [cx + rx + 10, 78 * ws, 'c'], [cx + rx + 2, 70 * ws], [cx + rx - 4, 84 * ws, 'c'], [cx + rx - 9, 66 * ws],
      [cx + rx * 0.45, 30 * ws], [cx + rx * 0.5, hy + ry * 0.5], [cx + rx * 0.15, hy - ry * 0.2]], hc, { w: 2.0, rough: 0.6 });
    p.clip(path, () => { streak([[cx + rx * 0.4, hy - ry * 0.6], [cx + rx + 4, hy + ry * 0.8], [cx + rx + 5, 60 * ws]]); streak([[cx + rx * 0.9, hy], [cx + rx + 1, 70 * ws]]); });
    return;
  }
  if (back) {
    const path = p.poly([[cx - rx - 3, hy - ry * 0.3], [cx - rx * 0.6, hy - ry - 3], [cx + rx * 0.6, hy - ry - 3], [cx + rx + 3, hy - ry * 0.3],
      [cx + rx + 6, 30 * ws], [cx + rx + 4, 82 * ws, 'c'], [cx + rx * 0.4, 74 * ws], [cx, 90 * ws, 'c'], [cx - rx * 0.45, 72 * ws], [cx - rx - 4, 84 * ws, 'c'],
      [cx - rx - 6, 30 * ws]], hc, { w: 2.1, rough: 0.6 });
    p.clip(path, () => { for (const s of [-0.6, -0.2, 0.25, 0.6]) streak([[cx + s * rx, hy - ry * 0.7], [cx + s * rx * 1.15, 75 * ws]]); });
    return;
  }
  // 앞: 얼굴 양옆으로 흘러내린 가는 머리 두 가닥(어깨 앞 가슴께까지, 끝이 갈라짐) — 얼굴·어깨는 가리지 않는다
  for (const s of [-1, 1]) {
    const x0 = cx + s * (rx - 1);
    const path = p.poly([[x0 - s * 2, hy - ry * 0.5], [x0 + s * 5, hy - ry * 0.1], [x0 + s * 6, hy + ry * 0.8], [x0 + s * 7, 20 * ws], [x0 + s * 5, 40 * ws, 'c'],
      [x0 + s * 1, 32 * ws], [x0 - s * 2, 44 * ws, 'c'], [x0 - s * 2, 22 * ws], [x0 - s * 1, hy + ry * 0.8], [x0 - s * 3, hy + ry * 0.1]], hc, { w: 1.7, rough: 0.6 });
    p.clip(path, () => streak([[x0 + s * 1, hy], [x0 + s * 2, 34 * ws]]));
  }
}

function parip(p, view, S) {
  // 찢어진 갓: 챙 한쪽이 떨어져 나가고 모자 꼭대기가 찌그러졌다. 빛이 바랜 먹빛
  const ws = S.ws, ry = S.headRY, rx = S.headRX, hy = headY(S);
  const side = view === 'side';
  const cx = side ? 2 * ws : 0;
  const by = hy - ry * 0.52, col = '#47413c', brim = '#6a625a';
  const bry = side ? 3.5 : 8;
  // 챙: 타원에서 오른쪽 아래 한 조각이 떨어져 나간 꼴
  const pts = ellipsePts(cx, by, 54 * ws, bry * ws, 30, -PI * 0.92, PI * 0.38);
  pts.push([cx + 26 * ws, by + bry * 0.5 * ws], [cx + 34 * ws, by + bry * 0.1 * ws, 'c'], [cx + 40 * ws, by + bry * 0.8 * ws, 'c']);
  const bpath = p.poly(pts, brim, { w: 1.8, rough: 0.9 });
  p.clip(bpath, () => {
    for (const k of [0.45, 0.72]) p.stroke(ellipsePts(cx, by, 54 * k * ws, bry * k * ws, 24, 0, PI), { w: 0.8, color: shade(brim, 0.3), taper: false, smooth: false });
    p.stroke([[cx - 30 * ws, by - 2], [cx - 18 * ws, by + 3]], { w: 1.0, color: INKC, rough: 0.6 });
  });
  // 너덜한 챙 끝 실오리
  p.stroke([[cx + 40 * ws, by + 2], [cx + 44 * ws, by + 9 * ws]], { w: 0.9, color: brim, rough: 0.8 });
  // 모자(대우): 한쪽이 찌그러져 기울었다
  const top = by - 31 * ws;
  p.poly([[cx - 14 * ws, top + 2, 'c'], [cx + 3 * ws, top - 2], [cx + 15 * ws, top + 8 * ws, 'c'], [cx + 17 * ws, by, 'c'], [cx - 17 * ws, by, 'c']], col, { w: 2.2, rough: 0.7 });
  p.stroke([[cx - 6 * ws, top + 4], [cx + 2 * ws, top + 14 * ws], [cx - 3 * ws, top + 24 * ws]], { w: 1.2, color: '#d9cfb8', rough: 0.6 });
  p.stroke([[cx - 16.5 * ws, by - 4], [cx + 16.5 * ws, by - 4]], { w: 2.2, color: '#2a2522', taper: false });
}

function samo(p, view, S) {
  // 사모: 검은 사모 몸 + 뒤가 높은 둥근 산 + 양옆 날개(뿔)
  const ws = S.ws, ry = S.headRY, rx = S.headRX, hy = headY(S);
  const side = view === 'side';
  const cx = side ? 2 * ws : 0;
  const by = hy - ry * 0.38, col = '#1f1c1b', hi = '#3a3532';
  if (side) {
    // 옆(왼쪽을 봄): 낮은 앞 산 + 뒤(+x)에 솟은 둥근 뒷산, 날개는 뒷산 곁의 납작한 타원
    p.ellipse(cx + rx * 0.95, by - 24 * ws, 6 * ws, 11 * ws, col, { w: 1.8 });
    p.poly([[cx + rx * 0.1, by - 18 * ws, 'c'], [cx + rx * 0.25, by - 40 * ws, 'c'], [cx + rx * 0.9, by - 40 * ws, 'c'], [cx + rx * 1.0, by - 16 * ws, 'c']], col, { w: 2.0 });
    p.poly([[cx - rx - 2, by, 'c'], [cx - rx - 1, by - 16 * ws, 'c'], [cx + rx * 0.4, by - 21 * ws, 'c'], [cx + rx + 3, by - 14 * ws, 'c'], [cx + rx + 3, by, 'c']], col, { w: 2.2 });
    p.stroke([[cx - rx - 2, by - 3], [cx + rx + 3, by - 3]], { w: 2.4, color: hi, taper: false });
    return;
  }
  // 앞·뒤: 날개 둘(옆으로 뻗은 둥근 판), 가운데 낮은 앞 산, 뒤의 높은 산
  for (const s of [-1, 1]) {
    p.poly([[cx + s * 14 * ws, by - 24 * ws], [cx + s * 46 * ws, by - 30 * ws, 'c'], [cx + s * 50 * ws, by - 22 * ws, 'c'], [cx + s * 16 * ws, by - 16 * ws]], col, { w: 1.8 });
    p.stroke([[cx + s * 20 * ws, by - 23 * ws], [cx + s * 44 * ws, by - 26 * ws]], { w: 1.0, color: hi, taper: false });
  }
  p.poly([[cx - 16 * ws, by - 20 * ws, 'c'], [cx - 12 * ws, by - 44 * ws, 'c'], [cx + 12 * ws, by - 44 * ws, 'c'], [cx + 16 * ws, by - 20 * ws, 'c']], col, { w: 2.0 });
  p.poly([[cx - rx - 2, by, 'c'], [cx - rx, by - 18 * ws, 'c'], [cx + rx, by - 18 * ws, 'c'], [cx + rx + 2, by, 'c']], col, { w: 2.2 });
  p.stroke([[cx - rx - 1, by - 4], [cx + rx + 1, by - 4]], { w: 2.4, color: hi, taper: false });
}

function blackBeard(p, view, S) {
  const ws = S.ws, rx = S.headRX, ry = S.headRY, hy = headY(S);
  const side = view === 'side', c = '#1d1916';
  if (view === 'back') return;
  const cx = side ? 2 * ws : 0;
  if (side) {
    p.stroke([[cx - rx * 1.02, hy + ry * 0.52], [cx - rx * 0.7, hy + ry * 0.6], [cx - rx * 0.45, hy + ry * 0.72]], { w: 2.2, color: c });
    p.poly([[cx - rx * 0.86, hy + ry * 0.86], [cx - rx * 0.98, hy + ry + 16 * ws, 'c'], [cx - rx * 0.62, hy + ry * 0.92]], c, { w: 1.2, ink: c });
    return;
  }
  for (const s of [-1, 1]) p.stroke([[cx + s * 2, hy + ry * 0.52], [cx + s * 9 * ws, hy + ry * 0.56], [cx + s * 15 * ws, hy + ry * 0.7]], { w: 2.0, color: c });
  p.poly([[cx - 5 * ws, hy + ry * 0.86], [cx, hy + ry + 18 * ws, 'c'], [cx + 5 * ws, hy + ry * 0.86]], c, { w: 1.2, ink: c });
}

function eonjeun(p, view, S) {
  // 얹은머리: 머리 위에 두른 굵은 땋은 타래(가체) + 떨잠
  const ws = S.ws, rx = S.headRX, ry = S.headRY, hy = headY(S), hc = '#241e1b';
  const side = view === 'side';
  const cx = side ? 2 * ws : 0;
  const y = hy - ry * 0.74, W = side ? rx + 6 : rx + 11, H = 10 * ws;
  // 굵은 땋은 타래를 머리 위에 둥글게 감음: 뒤 줄(위) + 앞 줄(아래) 매듭 고리
  p.ellipse(cx + (side ? 3 * ws : 0), y - 2, W, H + 3 * ws, shade(hc, -0.1), { w: 2.0 });
  for (const [row, yy, n] of [[0, y - H * 0.55, 7], [1, y + H * 0.45, 8]]) {
    for (let i = 0; i < n; i++) {
      const t = (i + 0.5) / n, x = cx + (side ? 3 * ws : 0) + (t - 0.5) * 2 * W * (row ? 0.98 : 0.86);
      const yc = yy + (row ? 1.5 : -1.5) * Math.abs(t - 0.5) * 6 * ws;
      p.ellipse(x, yc, (row ? 6.2 : 5.6) * ws, (row ? 6 : 5.4) * ws, hc, { w: 1.4 });
      p.stroke([[x - 3 * ws, yc - 2 * ws], [x + 3 * ws, yc + 2 * ws]], { w: 0.9, color: shade(hc, 0.35), taper: false });
    }
  }
  if (!side) {
    p.dot(cx + W * 0.5, y - H * 0.8, 3.2 * ws, '#c9a449');
    p.dot(cx - W * 0.55, y - H * 0.6, 2.6 * ws, '#b8322a');
  }
}

// ---------------------------------------------------------------------------
// 몸통 부속(torso 좌표: 엉덩이 0, 목 −T)
// ---------------------------------------------------------------------------
function cangue(p, view, S) {
  // 칼(枷): 긴 널빤지 두 쪽을 맞춘 목 칼 — 쇠띠 둘, 먹 글씨 자국
  const ws = S.ws, T = S.torso, wood = '#8f6c45';
  if (view === 'side') {
    const a = 0.42, L = 128 * ws;
    const dx = -sin(a) * L, dy = cos(a) * L;
    const x0 = -8 * ws, y0 = -T - 8 * ws;
    const path = p.poly([[x0 - 4, y0 - 2], [x0 + 6, y0 + 2], [x0 + dx + 6, y0 + dy + 2], [x0 + dx - 4, y0 + dy - 2]], wood, { w: 2.0, smooth: false, rough: 0.4 });
    p.clip(path, () => p.stroke([[x0 + 1, y0], [x0 + dx + 1, y0 + dy]], { w: 0.9, color: shade(wood, -0.35), taper: false }));
    for (const k of [0.12, 0.6]) p.stroke([[x0 - 5 + dx * k, y0 + dy * k - 1], [x0 + 7 + dx * k, y0 + dy * k + 2]], { w: 2.6, color: '#3d3a36', taper: false });
    return;
  }
  if (view === 'back') {
    // 뒤: 목 양옆으로 널빤지 윗단만 보인다
    p.poly([[-26 * ws, -T - 10 * ws], [26 * ws, -T - 10 * ws], [26 * ws, -T + 2 * ws], [-26 * ws, -T + 2 * ws]], wood, { w: 1.8, smooth: false, rough: 0.4 });
    return;
  }
  const top = -T - 9 * ws, bot = 22 * ws, hw = 22 * ws, hw2 = 18 * ws;
  const path = p.poly([[-hw, top], [hw, top], [hw2, bot], [-hw2, bot]], wood, { w: 2.2, smooth: false, rough: 0.4 });
  p.clip(path, () => {
    p.stroke([[0, top], [0, bot]], { w: 1.1, color: shade(wood, -0.4), taper: false });
    for (const x of [-12, 9]) p.stroke([[x * ws, top + 20], [x * ws + 2, bot - 6]], { w: 0.8, color: shade(wood, -0.25), rough: 0.5 });
    for (const k of [0.16, 0.7]) { const y = top + (bot - top) * k; p.stroke([[-hw - 2, y], [hw + 2, y]], { w: 3.0, color: '#3d3a36', taper: false }); }
    // 먹 글씨 자국(죄목)
    for (let i = 0; i < 3; i++) p.stroke([[-6 * ws, top + 38 * ws + i * 13 * ws], [-1 * ws, top + 44 * ws + i * 13 * ws]], { w: 2.2, color: '#2a2420' });
  });
  // 목 구멍 테
  p.ellipse(0, top + 3 * ws, 9 * ws, 4 * ws, shade(wood, -0.45), { w: 1.2 });
}

function rags(p, view, S, sp) {
  // 누더기: 몸통에 덧댄 헝겊과 해진 자리
  const ws = S.ws, T = S.torso, pc = sp.patch || '#857660';
  if (view === 'side') {
    p.poly([[-6 * ws, -T + 40 * ws], [10 * ws, -T + 38 * ws], [12 * ws, -T + 60 * ws], [-5 * ws, -T + 62 * ws]], pc, { w: 1.2, smooth: false, rough: 1 });
    p.stroke([[-14 * ws, -T + 70 * ws], [-6 * ws, -T + 78 * ws], [-12 * ws, -T + 86 * ws]], { w: 1.2, color: INKC, rough: 0.8 });
    return;
  }
  const sx = view === 'back' ? -1 : 1;
  p.poly([[sx * -20 * ws, -T + 46 * ws], [sx * -6 * ws, -T + 44 * ws], [sx * -5 * ws, -T + 64 * ws], [sx * -19 * ws, -T + 66 * ws]], pc, { w: 1.2, smooth: false, rough: 1 });
  p.poly([[sx * 8 * ws, -T + 70 * ws], [sx * 20 * ws, -T + 68 * ws], [sx * 21 * ws, -T + 84 * ws], [sx * 9 * ws, -T + 86 * ws]], shade(pc, -0.12), { w: 1.2, smooth: false, rough: 1 });
  for (const y of [52, 76]) p.stroke([[sx * -18 * ws, -T + y * ws], [sx * -8 * ws, -T + (y + 1) * ws]], { w: 0.7, color: '#d9cfb8', taper: false, dry: true });
  p.stroke([[sx * 14 * ws, -T + 22 * ws], [sx * 18 * ws, -T + 34 * ws], [sx * 13 * ws, -T + 40 * ws]], { w: 1.2, color: INKC, rough: 0.8 });
}

function dallyeong(p, view, S, sp) {
  // 단령: 둥근 깃(곧은 깃 위를 덮음) + 흉배(앞·뒤) — 각대는 따로(belt)
  const ws = S.ws, T = S.torso, sh = S.shHalf, coat = sp.coat, kc = shade(coat, -0.32);
  const badge = (x0, x1, y0, y1) => {
    const path = p.poly([[x0, y0], [x1, y0], [x1, y1], [x0, y1]], '#253a68', { w: 1.6, smooth: false });
    p.clip(path, () => {
      const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, w = x1 - x0;
      // 학 한 마리(흰 몸·검은 목) + 금빛 구름
      p.ellipse(cx, cy, w * 0.22, w * 0.12, '#efe9da', { w: 0.9 });
      p.stroke([[cx - w * 0.15, cy - 1], [cx - w * 0.3, cy - w * 0.25]], { w: 1.6, color: '#1f1a17' });
      p.stroke([[cx + w * 0.05, cy - 2], [cx + w * 0.38, cy - w * 0.2]], { w: 1.4, color: '#efe9da' });
      for (const [dx, dy] of [[-0.3, 0.3], [0.25, 0.32], [0.3, -0.3]]) p.stroke([[cx + dx * w - 4, cy + dy * w], [cx + dx * w + 4, cy + dy * w - 2]], { w: 1.8, color: '#c9a449' });
    });
  };
  if (view === 'side') {
    const bx = 2 * ws;
    p.poly([[bx - 12 * ws, -T - 3], [bx + 2 * ws, -T - 4], [bx + 4 * ws, -T + 4 * ws], [bx - 14 * ws, -T + 10 * ws]], kc, { w: 1.5 });
    p.poly([[bx - 23 * ws, -T + 30 * ws], [bx - 19 * ws, -T + 30 * ws], [bx - 19 * ws, -T + 56 * ws], [bx - 24 * ws, -T + 56 * ws]], '#253a68', { w: 1.2, smooth: false });
    return;
  }
  if (view === 'front') {
    // 곧은 깃(V)을 옷빛으로 덮고 둥근 깃
    p.fill([[-sh * 0.5, -T - 3], [sh * 0.5 + 6 * ws, -T - 3], [sh * 0.3, -T + 36 * ws], [-sh * 0.35, -T + 36 * ws]], coat, { smooth: false });
    const ring = p.ellipse(0, -T + 2 * ws, 17 * ws, 11 * ws, kc, { w: 1.7 });
    p.ellipse(0, -T + 1 * ws, 10 * ws, 6 * ws, '#f3eee2', { w: 1.2 });
    badge(-14 * ws, 14 * ws, -T + 30 * ws, -T + 58 * ws);
    return;
  }
  p.stroke([[-sh * 0.45, -T], [0, -T + 4], [sh * 0.45, -T]], { w: 6 * ws, color: kc, taper: false });
  badge(-14 * ws, 14 * ws, -T + 30 * ws, -T + 58 * ws);
}

function gakdae(p, view, S) {
  // 각대: 허리에서 떠 있는 뻣뻣한 띠(검은 바탕 + 금 장식판)
  const ws = S.ws, wa = S.waistHalf, belt = '#1f1c1b', gold = '#c9a449';
  if (view === 'side') {
    const bx = 2 * ws;
    p.poly([[bx - 28 * ws, -6 * ws], [bx + 24 * ws, -12 * ws], [bx + 24 * ws, -5 * ws], [bx - 28 * ws, 1 * ws]], belt, { w: 1.6, smooth: false });
    for (let i = 0; i < 5; i++) { const t = (i + 0.5) / 5; p.dot(bx - 28 * ws + t * 52 * ws, -3 * ws - t * 6 * ws, 2.2 * ws, gold); }
    return;
  }
  const hw = wa + 9 * ws;
  p.poly([[-hw, -10 * ws], [hw, -10 * ws], [hw - 2 * ws, -3 * ws], [0, 2 * ws], [-hw + 2 * ws, -3 * ws]], belt, { w: 1.7, smooth: false });
  for (let i = 0; i < 7; i++) { const t = (i + 0.5) / 7, x = -hw + t * hw * 2; p.poly([[x - 3 * ws, -8 * ws], [x + 3 * ws, -8 * ws], [x + 3 * ws, -3 * ws], [x - 3 * ws, -3 * ws]], gold, { w: 0.8, smooth: false }); }
}

// ---------------------------------------------------------------------------
// 손 소품
// ---------------------------------------------------------------------------
function mapaePart(S) {
  // 마패: 둥근 놋쇠 패(말 그림) + 끈
  const ws = S.ws;
  return paint(41, (p) => {
    p.stroke([[0, -2], [0, 6 * ws]], { w: 1.3, color: '#5a3020', taper: false });
    const path = p.ellipse(0, 18 * ws, 12 * ws, 12 * ws, '#d1ab52', { w: 1.8 });
    p.clip(path, () => {
      p.ellipse(0, 18 * ws, 8.5 * ws, 8.5 * ws, '#e6c574', { w: 0.8 });
      for (const dx of [-4, 0, 4]) { p.stroke([[dx * ws - 2, 15 * ws], [dx * ws + 2, 15 * ws], [dx * ws + 3, 20 * ws]], { w: 1.3, color: '#5a4320' }); }
    });
    p.ellipse(0, 6 * ws, 2.5 * ws, 2.5 * ws, '#5a3020', { w: 0.8 });
  }, 128);
}
function jugPart(S) {
  // 술병(백자 호리병)
  const ws = S.ws;
  return paint(43, (p) => {
    p.ellipse(0, 4 * ws, 3.2 * ws, 3 * ws, '#ece6d8', { w: 1.2 });
    p.poly([[-2.6 * ws, 6 * ws], [2.6 * ws, 6 * ws], [4 * ws, 11 * ws], [9 * ws, 18 * ws, 'c'], [0, 26 * ws, 'c'], [-9 * ws, 18 * ws, 'c'], [-4 * ws, 11 * ws]], '#ece6d8', { w: 1.6 });
    p.stroke([[-6 * ws, 17 * ws], [6 * ws, 17 * ws]], { w: 1.1, color: '#4a6a9a', taper: false });
  }, 128);
}
function attachHand(rig, name, img, tag) {
  for (const v of ['front', 'side', 'back']) {
    const hand = v === 'back' ? 'arm1_l' : 'arm2_l';
    addPart(rig, v, { name, parent: hand, at: [0, rig.S.lArm + 2], z: v === 'side' ? 11.05 : 6.25, img: img.img, ox: img.ox, oy: img.oy, abs: true, tag });
  }
}

/** 부속 붙이기(+ 이 세트 동작) — installPoses 뒤에 부른다 */
export function installDress(kind) {
  const P = PART2[kind];
  const rig = getRig(kind);
  if (rig._dress) return rig;
  rig._dress = true;
  const S = rig.S, sp = rig.spec, d = new Set(P.dress || []);
  for (const v of ['front', 'side', 'back']) {
    const side = v === 'side', back = v === 'back';
    const hz = zOf(rig, v, 'head'), tz = zOf(rig, v, 'torso');
    // 머리 부속은 머리 부위 자체를 부모로(고개 숙임을 따라감)
    const onHead = (name, z, fn) => { const im = paint(name.length * 31 + v.length, fn); addPart(rig, v, { name, parent: 'head', at: [0, 0], z, img: im.img, ox: im.ox, oy: im.oy }); };
    const onTorso = (name, z, fn) => { const im = paint(name.length * 17 + v.length, fn); addPart(rig, v, { name, parent: 'torso', at: [0, 0], z, img: im.img, ox: im.ox, oy: im.oy }); };
    if (d.has('loose_hair')) onHead('loose_hair', side ? tz + 0.6 : back ? hz + 0.05 : hz + 0.02, (p) => looseHair(p, v, S, sp));
    if (d.has('cangue')) onTorso('cangue', side ? tz + 0.5 : back ? tz - 0.1 : 6.3, (p) => cangue(p, v, S));
    if (d.has('parip')) onHead('parip', hz + 0.03, (p) => parip(p, v, S));
    if (d.has('samo')) onHead('samo', hz + 0.03, (p) => samo(p, v, S));
    if (d.has('black_beard')) onHead('black_beard', hz + 0.02, (p) => blackBeard(p, v, S));
    if (d.has('eonjeun')) onHead('eonjeun', hz + 0.03, (p) => eonjeun(p, v, S));
    if (d.has('rags')) onTorso('rags', tz + 0.02, (p) => rags(p, v, S, sp));
    if (d.has('dallyeong')) onTorso('dallyeong', tz + 0.02, (p) => dallyeong(p, v, S, sp));
    if (d.has('dallyeong')) onTorso('gakdae', side ? tz + 0.04 : 5.6, (p) => gakdae(p, v, S));
  }
  if (d.has('mapae')) attachHand(rig, 'mapae', mapaePart(S), 'alt');
  if (d.has('jug')) attachHand(rig, 'jug', jugPart(S), 'alt');
  // 동작: serve(술병 들고 따름) · mapae(마패를 들어 보임) · 변학도 sit = 교의에 앉음
  rig.anims = { ...rig.anims, ...DRESS_ANIMS };
  const base = rig.pose;
  rig.pose = (view, anim, t, rg, at, st) => {
    if (anim === 'sit' && P.chairSit) return base(view, 'sit_chair', t, rg, at, st);
    if (DRESS_ANIMS[anim]) return dressPose(view, anim, t, rg);
    return base(view, anim, t, rg, at, st);
  };
  return rig;
}

const SWAP = { arm1: 'arm2', arm2: 'arm1', arm1_l: 'arm2_l', arm2_l: 'arm1_l', leg1: 'leg2', leg2: 'leg1', leg1_l: 'leg2_l', leg2_l: 'leg1_l' };
function dressPose(view, anim, t, rig) {
  const side = view === 'side', k = rig.S.hip / 80;
  const ph = (t / DRESS_ANIMS[anim].dur) * PI * 2, s = sin(ph);
  let F;
  if (anim === 'serve') {
    // 두 손으로 술병을 받쳐 앞으로 — 따르듯 살짝 기울였다 세움
    F = side
      ? { torso: [-0.14 - 0.04 * s], head: [-0.12], arm2: [1.25 + 0.08 * s], arm2_l: [0.55], arm1: [1.05], arm1_l: [0.75], jug: [0, 0, 0, 1, 1, 1], root: [0, -2 * k, 1 * k] }
      : { arm1: [-0.32, 0, 0, 1, 0.85], arm1_l: [-1.05], arm2: [0.32, 0, 0, 1, 0.85], arm2_l: [1.05 + 0.06 * s], jug: [0, 0, 0, 1, 1, 1], head: [0, 0, 2 * k], torso: [0, 0, 0, 1, 0.98] };
  } else {
    // 마패를 들어 보임: 가까운 손을 앞 위로 높이
    F = side
      ? { torso: [0.06], head: [0.12], arm2: [2.45 + 0.04 * s], arm2_l: [0.25], arm1: [0.25], arm1_l: [0.4], mapae: [0, 0, 0, 1, 1, 1] }
      : { arm2: [-2.55 - 0.04 * s], arm2_l: [-0.25], arm1: [0.12], arm1_l: [-0.3], mapae: [0, 0, 0, 1, 1, 1], head: [0, 0, -1 * k] };
  }
  const P = {};
  for (const n in F) { const a = F[n]; P[n] = { r: a[0] || 0, x: a[1] || 0, y: a[2] || 0, sx: a[3] ?? 1, sy: a[4] ?? 1, a: a[5] ?? 1 }; }
  if (view !== 'back') return P;
  const Q = {};
  for (const n in P) { const p = P[n]; Q[SWAP[n] || n] = { r: -p.r, x: -p.x, y: p.y, sx: p.sx, sy: p.sy, a: p.a }; }
  return Q;
}
