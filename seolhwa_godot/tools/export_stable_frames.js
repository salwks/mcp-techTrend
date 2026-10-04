// 역참·마방(scripts/region/station_life.gd) 프레임 굽기 — 웹 코드(seolhwa/src)는 고치지 않는다.
//  - stable_bay · stable_chestnut · stable_grey · stable_pony: 마방에 매인 말(안장 없음, 굴레·고삐만). 주변 말·탈 말처럼 웹에 짐승 리그가 없어
//      캔버스에 먹선·담채로 직접 그린다(옆은 왼쪽을 본다 — 오른쪽은 엔진이 뒤집는다). 탈 말(ride_horse)과 같은 1.3배 크기(등 1.87m).
//      동작: side idle(꼬리 휘두름·귀 까딱·한 발 옮김) · eat(구유에 머리를 박고 씹음) · graze(땅에 머리를 숙여 풀 뜯음) · walk(네 박)
//            front idle · eat(구유로 머리를 숙임) / back idle · eat(머리는 몸 뒤로 숨고 꼬리 휘두름). 앞·뒤 walk는 엔진이 옆으로 대신한다.
//      제주 조랑말(stable_pony, 과하마): 0.82배, 짧고 굵은 다리, 덥수룩한 갈기·앞머리, 누런 밤빛.
//  - mabu: 마부(역졸 차림 — 무명 저고리·잠방이·머리띠·행전). idle · walk(앞·옆·뒤) + brush(옆 — 솔질), feed(옆 — 건초를 구유에 붓기).
//      웹 굽기 엔진(frameCore.BakeBank, high)에 종류·동작만 더한다. 건초 짐은 엔진이 3D 짚단으로 안긴다.
// 결과: data/frames_stable.json + frames_stable_<kind>_<n>.png (data/는 git 제외 — 다른 맥에서는 다시 굽는다. 없으면 엔진은 탈 말·주변 말로 대신)
// 실행: python3 tools/web_export_server.py 8770 → http://localhost:8770/__tools/stable_bake.html
//   (헤드리스: "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" --headless=new --virtual-time-budget=120000 --dump-dom 그 주소 — 끝나면 <p id=st>done…)
import { SPECS, getRig } from '/src/chars/rigs.js';
import * as fc from '/src/chars/frameCore.js';

const { sin, cos, PI, max, abs, atan2, hypot } = Math;

// ---------------------------------------------------------------------------
// 말 그리기 — 길이 단위: 그림 m(세상 크기 = × SC), 발 중심 원점, 위가 +y, 옆모습 머리는 왼쪽(−x)
// ---------------------------------------------------------------------------
const RES = 90, PAGE = 1024, MARGIN = 4;     // RES: 세상 1m당 픽셀(탈 말 100보다 조금 낮게 — 말이 여러 마리라 페이지를 아낀다)
const INKC = '#1f1a17';
const COATS = {
  stable_bay: { coat: '#7a5236', mane: '#2a221c', sc: 1.3 },
  stable_chestnut: { coat: '#9a5b2e', mane: '#5e321a', sc: 1.3, blaze: true },
  stable_grey: { coat: '#b0aaa0', mane: '#55514b', sc: 1.3, dapple: true },
  stable_pony: { coat: '#8c6a44', mane: '#2e241c', sc: 1.3 * 0.82, pony: true },
};
const HALTER = '#5a3020', METAL = '#b8a46a', HOOF = '#2a221c';

function shadeHex(hex, k) {
  const n = parseInt(hex.slice(1), 16); let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  const t = k < 0 ? [30, 24, 18] : [246, 239, 223], a = Math.abs(k);
  r += (t[0] - r) * a; g += (t[1] - g) * a; b += (t[2] - b) * a;
  return '#' + ((1 << 24) | ((r | 0) << 16) | ((g | 0) << 8) | (b | 0)).toString(16).slice(1);
}

class Pen {
  constructor(sc) {
    this.sc = sc;
    this.TW = Math.ceil(4.4 * sc * RES); this.TH = Math.ceil(3.3 * sc * RES);
    this.TOX = this.TW / 2; this.TOY = this.TH - 8;
    this.cv = document.createElement('canvas'); this.cv.width = this.TW; this.cv.height = this.TH;
    this.g = this.cv.getContext('2d', { willReadFrequently: true });
  }
  clear() { this.g.setTransform(1, 0, 0, 1, 0, 0); this.g.clearRect(0, 0, this.TW, this.TH); }
  X(x) { return this.TOX + x * RES * this.sc; }
  Y(y) { return this.TOY - y * RES * this.sc; }
  path(pts, closed = true) {
    const g = this.g, P = pts.map(([x, y]) => [this.X(x), this.Y(y)]);
    g.beginPath();
    if (!closed) { g.moveTo(P[0][0], P[0][1]); for (let i = 1; i < P.length - 1; i++) { const m = [(P[i][0] + P[i + 1][0]) / 2, (P[i][1] + P[i + 1][1]) / 2]; g.quadraticCurveTo(P[i][0], P[i][1], m[0], m[1]); } g.lineTo(P[P.length - 1][0], P[P.length - 1][1]); return; }
    const n = P.length, mid = (i) => [(P[i % n][0] + P[(i + 1) % n][0]) / 2, (P[i % n][1] + P[(i + 1) % n][1]) / 2];
    const s = mid(n - 1); g.moveTo(s[0], s[1]);
    for (let i = 0; i < n; i++) { const m = mid(i); g.quadraticCurveTo(P[i][0], P[i][1], m[0], m[1]); }
    g.closePath();
  }
  blob(pts, col, w = 2.0, shadeDown = 0.25) {
    const g = this.g; this.path(pts);
    let y0 = 1e9, y1 = -1e9; for (const p of pts) { y0 = Math.min(y0, this.Y(p[1])); y1 = Math.max(y1, this.Y(p[1])); }
    const gr = g.createLinearGradient(0, y0, 0, y1 + 0.01); gr.addColorStop(0, shadeHex(col, 0.12)); gr.addColorStop(1, shadeHex(col, -shadeDown));
    g.fillStyle = gr; g.fill();
    g.lineWidth = w; g.strokeStyle = INKC; g.lineJoin = 'round'; g.stroke();
  }
  ell(cx, cy, rx, ry, col, w = 2.0, shadeDown = 0.25) {
    const pts = []; for (let i = 0; i < 16; i++) { const a = i / 16 * 2 * PI; pts.push([cx + cos(a) * rx, cy + sin(a) * ry]); }
    this.blob(pts, col, w, shadeDown);
  }
  line(pts, col, w, ink = 1.8) {
    const g = this.g; g.lineCap = 'round'; g.lineJoin = 'round';
    if (ink > 0) { this.path(pts, false); g.lineWidth = w * RES * this.sc + ink * 2; g.strokeStyle = INKC; g.stroke(); }
    this.path(pts, false); g.lineWidth = w * RES * this.sc; g.strokeStyle = col; g.stroke();
  }
  stroke(pts, w = 1.1, col = INKC) { const g = this.g; this.path(pts, false); g.lineWidth = w; g.strokeStyle = col; g.lineCap = 'round'; g.stroke(); }
  dot(x, y, r, col = INKC) { const g = this.g; g.beginPath(); g.arc(this.X(x), this.Y(y), r, 0, 2 * PI); g.fillStyle = col; g.fill(); }
}

// 다리 한 짝(옆): 붙은 자리, 길이, 흔들기 각 a(+는 앞=왼쪽), 발 들림 lift
function leg(pen, ax, ay, L, a, w, col, bendSign = 1, lift = 0) {
  const k = 0.18 + lift * 2.6;
  const kx = ax - sin(a) * L * 0.5, ky = ay - cos(a) * L * 0.5;
  const fx = kx - sin(a - bendSign * k) * L * 0.5, fy = Math.max(0.03, ky - cos(a - bendSign * k) * L * 0.5 + lift * 0.45);
  pen.line([[ax, ay + 0.05], [kx, ky]], col, w * 1.45);
  pen.line([[kx, ky], [fx, fy]], col, w * 0.85);
  pen.blob([[fx - 0.06, fy + 0.04], [fx + 0.05, fy + 0.04], [fx + 0.06, fy - 0.03], [fx - 0.07, fy - 0.03]], HOOF, 1.2, 0);
}
function legV(pen, x, top, L, w, col, lift) {
  const kneeY = top - L * 0.5 + lift * 0.25, footY = 0.03 + lift * 0.5;
  pen.line([[x, top], [x, kneeY]], col, w * 1.4);
  pen.line([[x, kneeY], [x, footY + 0.05]], col, w * 0.85);
  pen.blob([[x - 0.055, footY + 0.05], [x + 0.055, footY + 0.05], [x + 0.06, footY - 0.02], [x - 0.06, footY - 0.02]], HOOF, 1.1, 0);
}
const rot = (p, c, a) => { const dx = p[0] - c[0], dy = p[1] - c[1]; return [c[0] + dx * cos(a) - dy * sin(a), c[1] + dx * sin(a) + dy * cos(a)]; };

// 동작 상태: 다리 흔들기·꼬리·귀·머리 자리
//   head: 'up' | 'eat'(구유 높이 0.8m) | 'graze'(땅)
function pose(anim, f, n) {
  const u = f / n, ph = u * 2 * PI;
  const walk = anim === 'walk';
  const A = walk ? 0.34 : 0;
  const off = [0, PI, PI * 0.5, PI * 1.5];
  const sw = (i) => A * sin(ph + off[i]), lf = (i) => (A > 0 ? 0.06 * max(0, cos(ph + off[i])) : 0);
  let st = { ph, A, sw, lf, bob: walk ? 0.015 * abs(sin(ph * 2)) : 0.008 * sin(ph), head: 'up', chew: 0, tail: 0.1 * sin(ph), ear: 0, shift: 0 };
  if (anim === 'idle') {
    // 꼬리를 크게 한 번 휘두르고(파리 쫓기) 귀를 까딱, 마지막 장은 뒷발 하나를 살짝 옮김
    st.tail = [0.0, 0.32, -0.22, 0.05][f % 4];
    st.ear = f === 1 ? 1 : 0;
    st.shift = f === 3 ? 1 : 0;
  } else if (anim === 'eat') { st.head = 'eat'; st.chew = sin(ph * 2); st.tail = 0.18 * sin(ph + 1.0); }
  else if (anim === 'graze') { st.head = 'graze'; st.chew = sin(ph * 2); st.tail = 0.14 * sin(ph + 0.6); st.shift = f === n - 1 ? 1 : 0; }
  return st;
}

function drawSide(pen, C, anim, f, n) {
  const G = pose(anim, f, n);
  const col = C.coat, far = shadeHex(col, -0.25), mane = C.mane;
  const pony = !!C.pony;
  const lg = pony ? 0.82 : 1.0, lw = pony ? 1.25 : 1.0;    // 조랑말: 짧고 굵은 다리
  const by = G.bob - (pony ? 0.16 : 0);
  const Y = (y) => y + by;
  // 먼 다리
  leg(pen, 0.75, Y(0.92), 0.92 * lg, G.sw(0), 0.1 * lw, far, -1, G.lf(0));
  leg(pen, -0.45, Y(0.88), 0.9 * lg, G.sw(2), 0.09 * lw, far, 1, G.lf(2));
  // 꼬리(휘두름)
  const tw = G.tail;
  pen.blob([[0.86, Y(1.34)], [1.05 + tw * 0.5, Y(1.15) + tw * 0.15], [1.08 + tw * 1.2, Y(0.66) + abs(tw) * 0.35], [0.97 + tw * 1.1, Y(0.7) + abs(tw) * 0.3], [0.84, Y(1.12)]], mane, 1.4);
  // 몸통
  pen.blob([[-0.6, Y(1.38)], [-0.2, Y(1.44)], [0.5, Y(1.38)], [0.92, Y(1.32)], [0.98, Y(1.06)], [0.8, Y(0.85)], [0.2, Y(0.79)], [-0.35, Y(0.81)], [-0.66, Y(0.99)], [-0.7, Y(1.22)]], col);
  pen.stroke([[0.55, Y(1.25)], [0.7, Y(1.0)]], 1.0, shadeHex(col, -0.35));
  if (C.dapple) for (const [x, y] of [[0.3, 1.2], [0.55, 1.12], [0.1, 1.05], [0.72, 1.22], [-0.1, 1.2]]) pen.dot(x, Y(y), 3.2, shadeHex(col, -0.18));
  // 가까운 다리(한 발 옮기는 장은 뒷발이 살짝 들림)
  leg(pen, -0.55, Y(0.9), 0.9 * lg, G.sw(3), 0.1 * lw, col, 1, G.lf(3));
  leg(pen, 0.66, Y(0.94), 0.92 * lg, G.sw(1) + (G.shift ? 0.12 : 0), 0.11 * lw, shadeHex(col, -0.05), -1, G.lf(1) + (G.shift ? 0.05 : 0));
  // 목·머리: 머리 자리(hx,hy = 정수리 쪽), 머리 기울기 ang(0 = 앞을 봄, +는 코가 아래로 — 왼쪽을 보는 머리를 반시계로)
  let hx, hy, ang;
  if (G.head === 'eat') { hx = -1.14; hy = 1.0 + 0.025 * G.chew; ang = 0.95 + 0.05 * G.chew; }
  else if (G.head === 'graze') { hx = -1.2; hy = 0.52 + 0.02 * G.chew; ang = 1.2 + 0.04 * G.chew; }
  else { hx = -1.02; hy = 1.72 + 0.012 * sin(G.ph); ang = 0; }
  if (pony) hy -= 0.12;
  hy += by;
  const pv = [hx + 0.1, hy];           // 머리 돌리는 중심(정수리 뒤)
  const R = (p) => rot(p, pv, ang);
  // 목: 어깨 → 머리 뒤
  const nt = R([hx + 0.14, hy + 0.06]), nb = R([hx + 0.02, hy - 0.12]);
  const mt = [(-0.38 + nt[0]) / 2, (Y(1.44) + nt[1]) / 2 + 0.12], mb = [(-0.68 + nb[0]) / 2 - 0.04, (Y(1.04) + nb[1]) / 2 - 0.05];
  pen.blob([[-0.38, Y(1.44)], mt, nt, nb, mb, [-0.68, Y(1.04)]], col);
  // 갈기(목 위 선) — 조랑말은 덥수룩하게
  pen.line([[-0.36, Y(1.46)], [mt[0] + 0.02, mt[1] + 0.03], [nt[0], nt[1] + 0.04]], mane, pony ? 0.085 : 0.05, 1.0);
  // 머리
  const dx = -0.3, dy = -0.12;
  pen.blob([R([hx + 0.12, hy + 0.08]), R([hx - 0.02, hy + 0.1]), R([hx + dx - 0.02, hy + dy + 0.02]), R([hx + dx + 0.02, hy + dy - 0.08]), R([hx + 0.08, hy - 0.1])], shadeHex(col, 0.04));
  if (C.blaze) pen.stroke([R([hx - 0.02, hy + 0.06]), R([hx + dx + 0.02, hy + dy - 0.01])], 2.6, '#ece4d2');
  // 귀(까딱: 뒤로 젖힘)
  const ea = G.ear ? 0.5 : 0;
  pen.blob([R([hx + 0.08, hy + 0.08]), rot(R([hx + 0.14, hy + 0.24]), R([hx + 0.12, hy + 0.08]), -ea), R([hx + 0.18, hy + 0.08])], col, 1.3);
  if (pony) pen.blob([R([hx + 0.06, hy + 0.1]), R([hx - 0.06, hy + 0.06]), R([hx + 0.0, hy - 0.04])], mane, 1.0, 0);   // 앞머리 털
  const eye = R([hx + 0.0, hy + 0.0]); pen.dot(eye[0], eye[1], 2.0);
  // 굴레(머리띠·코띠) + 매는 고삐(구유·말뚝 쪽으로 늘어짐)
  pen.stroke([R([hx + 0.08, hy + 0.06]), R([hx + dx + 0.06, hy + dy - 0.02])], 1.4, HALTER);
  pen.stroke([R([hx + 0.06, hy - 0.08]), R([hx + 0.1, hy + 0.08])], 1.4, HALTER);
  const mz = R([hx + dx + 0.06, hy + dy - 0.05]);
  if (G.head === 'up') pen.stroke([mz, [mz[0] + 0.04, mz[1] - 0.25], [mz[0] - 0.02, mz[1] - 0.5]], 1.2, HALTER);
}

function drawFront(pen, C, anim, f, n) {
  const G = pose(anim, f, n);
  const col = C.coat, far = shadeHex(col, -0.28), mane = C.mane, pony = !!C.pony;
  const lg = pony ? 0.82 : 1.0, lw = pony ? 1.25 : 1.0;
  const by = G.bob - (pony ? 0.16 : 0);
  legV(pen, -0.2, 0.95 * lg + by, 0.86 * lg, 0.085 * lw, far, 0);
  legV(pen, 0.2, 0.95 * lg + by, 0.86 * lg, 0.085 * lw, far, G.shift ? 0.05 : 0);
  pen.ell(0, 1.2 + by, 0.37, 0.3, shadeHex(col, -0.08));
  pen.ell(0, 1.08 + by, 0.25, 0.28, col);
  legV(pen, -0.14, 0.92 * lg + by, 0.92 * lg, 0.1 * lw, col, 0);
  legV(pen, 0.14, 0.92 * lg + by, 0.92 * lg, 0.1 * lw, shadeHex(col, -0.05), 0);
  // 목·머리 — 먹을 때는 머리를 숙여(짧아 보임) 가슴 앞 구유 높이로
  const eat = G.head === 'eat';
  const hy = (eat ? 1.18 + 0.025 * G.chew : 1.98 + 0.015 * sin(G.ph)) + by - (pony ? 0.12 : 0);
  const hl = eat ? 0.4 : 0.52;   // 보이는 머리 길이(숙이면 앞으로 짧아짐)
  if (!eat) {
    pen.blob([[-0.13, 1.28 + by], [0.13, 1.28 + by], [0.11, hy - 0.2], [-0.11, hy - 0.2]], col);
    pen.line([[0, 1.36 + by], [0, hy - 0.12]], mane, pony ? 0.09 : 0.06, 1.0);
  } else {
    // 숙인 목: 가슴 위에서 앞으로 굽어 내려옴(목 윗면이 보임)
    pen.blob([[-0.14, 1.46 + by], [0.14, 1.46 + by], [0.12, hy + 0.02], [-0.12, hy + 0.02]], shadeHex(col, 0.05));
    pen.line([[0, 1.5 + by], [0, hy + 0.06]], mane, pony ? 0.09 : 0.06, 1.0);
  }
  const ew = G.ear ? 0.05 : 0;
  pen.blob([[-0.12, hy - 0.02], [-0.16 - ew, hy + 0.14 - ew], [-0.06, hy + 0.02]], col, 1.3);
  pen.blob([[0.12, hy - 0.02], [0.16, hy + 0.14], [0.06, hy + 0.02]], col, 1.3);
  pen.blob([[-0.13, hy], [0.13, hy], [0.11, hy - hl * 0.58], [0.08, hy - hl], [-0.08, hy - hl], [-0.11, hy - hl * 0.58]], shadeHex(col, 0.05));
  if (C.blaze || !pony) pen.blob([[-0.03, hy - 0.04], [0.03, hy - 0.04], [0.02, hy - hl * 0.8], [-0.02, hy - hl * 0.8]], '#ece4d2', 0.9, 0);
  pen.blob([[-0.06, hy + 0.02], [0.06, hy + 0.02], [0.03, hy - 0.08 - (pony ? 0.06 : 0)], [-0.03, hy - 0.08 - (pony ? 0.06 : 0)]], mane, 0.9, 0);
  if (!eat || G.chew < 0.6) { pen.dot(-0.105, hy - 0.14, 2.0); pen.dot(0.105, hy - 0.14, 2.0); }   // 씹을 때 눈을 감았다 뜸
  pen.dot(-0.04, hy - hl + 0.04, 1.6); pen.dot(0.04, hy - hl + 0.04, 1.6);
  pen.stroke([[-0.11, hy - hl * 0.58], [0.11, hy - hl * 0.58]], 1.4, HALTER);
  pen.stroke([[-0.09, hy - hl * 0.8], [0.09, hy - hl * 0.8]], 1.4, HALTER);
}

function drawBack(pen, C, anim, f, n) {
  const G = pose(anim, f, n);
  const col = C.coat, far = shadeHex(col, -0.28), mane = C.mane, pony = !!C.pony;
  const lg = pony ? 0.82 : 1.0, lw = pony ? 1.25 : 1.0;
  const by = G.bob - (pony ? 0.16 : 0);
  legV(pen, -0.15, 0.95 * lg + by, 0.86 * lg, 0.085 * lw, far, 0);
  legV(pen, 0.15, 0.95 * lg + by, 0.86 * lg, 0.085 * lw, far, 0);
  if (G.head === 'up') {
    const hy = 1.95 + 0.01 * sin(G.ph) + by - (pony ? 0.12 : 0);
    pen.blob([[-0.12, 1.4 + by], [0.12, 1.4 + by], [0.1, hy - 0.08], [-0.1, hy - 0.08]], far);
    pen.blob([[-0.1, hy - 0.04], [-0.14, hy + 0.12], [-0.04, hy]], far, 1.3);
    pen.blob([[0.1, hy - 0.04], [0.14 + (G.ear ? 0.05 : 0), hy + 0.12 - (G.ear ? 0.05 : 0)], [0.04, hy]], far, 1.3);
    pen.line([[0, 1.45 + by], [0, hy - 0.04]], mane, 0.07, 1.0);
  }
  pen.ell(0, 1.22 + by, 0.37, 0.3, shadeHex(col, -0.05));
  pen.blob([[-0.38, 1.12 + by], [-0.34, 1.34 + by], [-0.1, 1.4 + by], [0, 1.33 + by], [0.1, 1.4 + by], [0.34, 1.34 + by], [0.38, 1.12 + by], [0.28, 0.92 + by], [0, 0.88 + by], [-0.28, 0.92 + by]], col);
  pen.stroke([[0, 1.32 + by], [0, 0.95 + by]], 1.1, shadeHex(col, -0.4));
  legV(pen, -0.21, 0.95 * lg + by, 0.92 * lg, 0.11 * lw, col, G.shift ? 0.05 : 0);
  legV(pen, 0.21, 0.95 * lg + by, 0.92 * lg, 0.11 * lw, shadeHex(col, -0.05), 0);
  const tw = G.tail * 0.8;
  pen.blob([[-0.06, 1.36 + by], [0.06, 1.36 + by], [0.07 + tw, 0.95 + by], [0.02 + tw * 1.4, 0.68 + by + abs(tw) * 0.3], [-0.06 + tw * 1.2, 0.7 + by + abs(tw) * 0.3], [-0.06 + tw * 0.5, 1.0 + by]], mane, 1.4);
}

const VIEWS = { side: drawSide, front: drawFront, back: drawBack };
// 시점별 동작 · 장 수
const HORSE_CLIPS = { side: { idle: 4, eat: 4, graze: 4, walk: 6 }, front: { idle: 3, eat: 4 }, back: { idle: 3, eat: 3 } };
const IDLE_STEP = { idle: 0.9, eat: 0.45, graze: 0.55 };

function bakeHorse(C) {
  const pen = new Pen(C.sc);
  const pages = [];
  let page = null, sx = 0, sy = 0, rowH = 0;
  const newPage = () => { page = document.createElement('canvas'); page.width = PAGE; page.height = PAGE; pages.push(page); sx = 0; sy = 0; rowH = 0; };
  newPage();
  const clips = {};
  for (const view in HORSE_CLIPS) {
    for (const anim in HORSE_CLIPS[view]) {
      const n = HORSE_CLIPS[view][anim], frames = [];
      for (let f = 0; f < n; f++) {
        pen.clear();
        VIEWS[view](pen, C, anim, f, n);
        const d = pen.g.getImageData(0, 0, pen.TW, pen.TH).data;
        let x0 = pen.TW, y0 = pen.TH, x1 = 0, y1 = 0;
        for (let y = 0; y < pen.TH; y++) for (let x = 0; x < pen.TW; x++) if (d[(y * pen.TW + x) * 4 + 3] > 8) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
        x1 += 1; y1 += 1;
        const w = x1 - x0 + MARGIN * 2, h = y1 - y0 + MARGIN * 2;
        if (sx + w > PAGE) { sx = 0; sy += rowH; rowH = 0; }
        if (sy + h > PAGE) newPage();
        page.getContext('2d').drawImage(pen.cv, x0, y0, x1 - x0, y1 - y0, sx + MARGIN, sy + MARGIN, x1 - x0, y1 - y0);
        frames.push({ page: pages.length - 1, u0: sx / PAGE, v0: sy / PAGE, u1: (sx + w) / PAGE, v1: (sy + h) / PAGE,
          x0: (x0 - MARGIN - pen.TOX) / RES, x1: (x1 + MARGIN - pen.TOX) / RES, y0: -(y1 + MARGIN - pen.TOY) / RES, y1: -(y0 - MARGIN - pen.TOY) / RES, lift: 0 });
        sx += w; rowH = Math.max(rowH, h);
      }
      const step = IDLE_STEP[anim];
      const spec = anim === 'walk'
        ? { kind: 'phase', n, times: [...Array(n).keys()].map((k) => k / n) }
        : { kind: 'loop', times: [...Array(n).keys()].map((k) => k * step), loopStart: 0, intro: 0, step, n, dur: n * step, tBased: true };
      clips[view + '|' + anim] = { spec, frames };
    }
  }
  return { pages, clips };
}

// ---------------------------------------------------------------------------
// 마부 — 웹 rigs의 villager_m 차림을 바꾸고 동작 둘(brush·feed)을 더한다
// ---------------------------------------------------------------------------
const MABU = { base: 'villager_m', coat: '#cdbb94', pants: '#d6c9a8', vest: '#6a5038', collar: '#8a7148', daenim: '#6a5038', back: null, band: '#efe9da',
  legwrap: '#ebe4d1', hat: null, build: 1.1, stubble: true };
const MABU_ANIMS = { brush: { dur: 1.2, loop: true }, feed: { dur: 1.6, loop: true } };
const toP = (F) => { const P = {}; for (const n in F) { const a = F[n]; P[n] = { r: a[0] || 0, x: a[1] || 0, y: a[2] || 0, sx: a[3] ?? 1, sy: a[4] ?? 1, a: a[5] ?? 1 }; } return P; };
function mabuPose(view, anim, t, rig) {
  if (!MABU_ANIMS[anim] || view !== 'side') return null;
  const S = rig.S, k = S.hip / 80;
  const u = ((t / MABU_ANIMS[anim].dur) % 1 + 1) % 1, ph = u * 2 * PI;
  if (anim === 'brush') {
    // 말 옆구리를 솔로 쓸어내림: 앞팔을 어깨 높이로 뻗어 위→아래로, 몸이 따라 살짝 기욺
    const s = sin(ph);
    return toP({ root: [0, 0, -1.5 * k], torso: [-0.12 - 0.05 * s], head: [0.05],
      arm2: [1.35 + 0.35 * s], arm2_l: [0.35 - 0.15 * s], arm1: [0.7 + 0.2 * s], arm1_l: [0.9],
      leg2: [0.16], leg2_l: [-0.12], leg1: [-0.18], leg1_l: [-0.05] });
  }
  // feed: 두 팔에 안은 건초를 구유 쪽으로 내밀었다 거둠
  const s = 0.5 - 0.5 * cos(ph);
  return toP({ root: [0, 0, -3 * k * s], torso: [-0.1 - 0.35 * s], head: [0.05 + 0.15 * s],
    arm2: [0.9 + 0.5 * s], arm2_l: [1.1 - 0.5 * s], arm1: [0.8 + 0.45 * s], arm1_l: [1.1 - 0.45 * s],
    leg2: [0.12], leg2_l: [-0.1], leg1: [-0.14], leg1_l: [-0.05] });
}

// ---------------------------------------------------------------------------
async function toPng(cv) {
  if (cv.convertToBlob) return await cv.convertToBlob({ type: 'image/png' });
  return await new Promise((r) => cv.toBlob(r, 'image/png'));
}
async function put(name, data) {
  const r = await fetch('/export/' + name, { method: 'PUT', body: data });
  if (!r.ok) throw new Error('PUT ' + name + ' ' + r.status);
}
const meta = (f) => ({ page: typeof f.page === 'number' ? f.page : f.page.index, u0: f.u0, u1: f.u1, v0: f.v0, v1: f.v1, x0: f.x0, x1: f.x1, y0: f.y0, y1: f.y1, lift: f.lift });

export async function run(log) {
  const out = {};
  for (const kind in COATS) {
    const hb = bakeHorse(COATS[kind]);
    const names = [];
    for (let i = 0; i < hb.pages.length; i++) { const name = `frames_stable_${kind}_${i}.png`; await put(name, await toPng(hb.pages[i])); names.push(name); }
    out[kind] = { pages: names, clips: hb.clips };
    log('baked ' + kind + ' pages=' + names.length);
  }
  // ---- 마부 ----
  const kind = 'mabu';
  const v = { ...MABU }; const base = SPECS[v.base]; delete v.base;
  const sp = { ...base };
  for (const k in v) { if (v[k] === null || v[k] === undefined) delete sp[k]; else sp[k] = v[k]; }
  SPECS[kind] = sp;
  fc.TIERS.high[kind] = fc.TIERS.high.player;
  const rig = getRig(kind);
  rig.anims = { ...rig.anims, ...MABU_ANIMS };
  const basePose = rig.pose;
  rig.pose = (view, anim, t, rg, at, st) => mabuPose(view, anim, t, rig) || basePose(view, anim, t, rg, at, st);
  const b = new fc.BakeBank(kind, 'high');
  const clips = {};
  for (const vw of ['front', 'side', 'back']) for (const a of ['idle', 'walk', 'brush', 'feed']) {
    if (MABU_ANIMS[a] && vw !== 'side') continue;
    const key = fc.clipKey(MABU_ANIMS[a] ? vw : fc.resolveView(kind, vw, a), a, false, false);
    if (clips[key]) continue;
    const c = b.clip(key); if (!c) continue;
    if (MABU_ANIMS[a]) { const n = 8, step = MABU_ANIMS[a].dur / n; c.spec = { kind: 'loop', times: [...Array(n).keys()].map((q) => q * step), loopStart: 0, intro: 0, step, n, dur: MABU_ANIMS[a].dur, tBased: false }; }
    let g = 0; while (!b.step(c) && g++ < 600);
    clips[key] = { spec: c.spec, frames: c.frames.map(meta) };
  }
  const pp = [];
  for (let i = 0; i < b.pages.length; i++) { const name = `frames_stable_mabu_${i}.png`; await put(name, await toPng(b.pages[i].cv)); pp.push(name); }
  out.mabu = { pages: pp, clips };
  log('baked mabu pages=' + pp.length + ' clips=' + Object.keys(clips).join(','));
  await put('frames_stable.json', JSON.stringify(out));
  log('done: ' + Object.keys(out).join(', '));
  console.log('[stable bake] done', Object.keys(out));
}
