// 설화록 — 민화풍 캔버스 붓 도구 (먹선, 담채, 한지 결)
// 모든 도형은 점 목록으로 받아 부드러운 곡선(캣멀롬)으로 그리고,
// 담채(평면 색 + 얼룩 + 한지 결 + 번짐 테두리) 위에 굵기가 변하는 먹선을 긋는다.
// Painter는 부위(part) 하나를 임시 캔버스에 그린 뒤 그려진 영역만 잘라 돌려준다.

export const INK = '#1f1a17';
export const PAPER = '#f1e9d6';

function luminance(hex) {
  const n = parseInt(hex.slice(1), 16);
  return (0.299 * ((n >> 16) & 255) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255)) / 255;
}

// 채도를 낮춘 오방색과 옷감 색
export const PAL = {
  hanji: '#efe6d0',
  white: '#ebe4d2',
  ivory: '#e6dcc2',
  red: '#b0413e',
  redSoft: '#c0645a',
  blue: '#3d5a73',
  blueSoft: '#6f8797',
  yellow: '#c9a449',
  yellowSoft: '#dcc583',
  black: '#2f2a27',
  skin: '#ecd2ac',
  skinShade: '#d9b58c',
  hair: '#2c2724',
  straw: '#b99a62',
  bamboo: '#5a4a35',
  brown: '#7a5a3c',
  hemp: '#d8caa4',
  gray: '#9a958a',
};

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);

function hexToRgb(h) {
  const n = parseInt(h.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
function rgbToHex(r, g, b) {
  return '#' + ((1 << 24) | (Math.round(r) << 16) | (Math.round(g) << 8) | Math.round(b)).toString(16).slice(1);
}
export function mix(a, b, t) {
  const A = hexToRgb(a), B = hexToRgb(b);
  return rgbToHex(A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t, A[2] + (B[2] - A[2]) * t);
}
/** k<0: 먹 쪽으로 어둡게, k>0: 한지 쪽으로 밝게 */
export function shade(hex, k) {
  return k < 0 ? mix(hex, '#1e1812', -k) : mix(hex, '#f6efdf', k);
}
export function rgba(hex, a) {
  const [r, g, b] = hexToRgb(hex);
  return `rgba(${r},${g},${b},${a})`;
}

export function makeCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  return c;
}

/** 결정적 난수(xorshift) */
export function rng(seed) {
  let s = (seed * 2654435761) >>> 0 || 1;
  return () => {
    s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0;
    return s / 4294967296;
  };
}

// ---------- 한지 결 패턴 ----------
let _grain = null;
function grainCanvas() {
  if (_grain) return _grain;
  const N = 128, c = makeCanvas(N, N), g = c.getContext('2d');
  const img = g.createImageData(N, N), d = img.data, R = rng(7);
  for (let i = 0; i < N * N; i++) {
    const v = 238 + R() * 17;
    d[i * 4] = v; d[i * 4 + 1] = v - 2; d[i * 4 + 2] = v - 6; d[i * 4 + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  // 닥나무 섬유
  g.lineCap = 'round';
  for (let i = 0; i < 70; i++) {
    const x = R() * N, y = R() * N, a = R() * Math.PI, l = 3 + R() * 10;
    g.strokeStyle = `rgba(120,100,70,${0.10 + R() * 0.15})`;
    g.lineWidth = 0.6 + R() * 0.6;
    g.beginPath();
    g.moveTo(x, y);
    g.quadraticCurveTo(x + Math.cos(a) * l * 0.5 + R() * 2, y + Math.sin(a) * l * 0.5 + R() * 2, x + Math.cos(a) * l, y + Math.sin(a) * l);
    g.stroke();
  }
  _grain = c;
  return c;
}

// ---------- 곡선 ----------
/** 점 목록 → 촘촘한 점 목록. [x,y,'c'] 는 모서리(뾰족) 점. */
export function smoothPts(pts, closed, step = 3.5) {
  // 모서리 점은 복제해서 접선을 끊는다
  const P = [];
  for (const p of pts) { P.push(p); if (p[2] === 'c') P.push(p); }
  const n = P.length, out = [];
  if (n < 2) return P.slice();
  const get = (i) => (closed ? P[(i + n) % n] : P[clamp(i, 0, n - 1)]);
  const last = closed ? n : n - 1;
  for (let i = 0; i < last; i++) {
    const p0 = get(i - 1), p1 = get(i), p2 = get(i + 1), p3 = get(i + 2);
    const len = Math.hypot(p2[0] - p1[0], p2[1] - p1[1]);
    const seg = Math.max(1, Math.ceil(len / step));
    for (let s = 0; s < seg; s++) {
      const t = s / seg, t2 = t * t, t3 = t2 * t;
      const f = (k) => 0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2 + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3);
      out.push([f(0), f(1)]);
    }
  }
  if (!closed) out.push([P[n - 1][0], P[n - 1][1]]);
  return out;
}

export function ellipsePts(cx, cy, rx, ry, n = 24, a0 = 0, a1 = Math.PI * 2) {
  const pts = [];
  const full = Math.abs(a1 - a0 - Math.PI * 2) < 1e-6;
  const cnt = full ? n : n + 1;
  for (let i = 0; i < cnt; i++) {
    const a = a0 + (a1 - a0) * (i / n);
    pts.push([cx + Math.cos(a) * rx, cy + Math.sin(a) * ry]);
  }
  return pts;
}

/** (0,0)→(0,len) 캡슐(팔다리) */
export function limbPts(len, w0, w1, sq = 0.75) {
  const pts = [], r0 = w0 / 2, r1 = w1 / 2;
  for (let i = 0; i <= 6; i++) { const a = Math.PI + (i / 6) * Math.PI; pts.push([Math.cos(a) * r0, Math.sin(a) * r0 * sq]); }
  for (let i = 0; i <= 6; i++) { const a = (i / 6) * Math.PI; pts.push([Math.cos(a) * r1, len + Math.sin(a) * r1 * sq]); }
  return pts;
}

// ---------- 화가 ----------
export class Painter {
  constructor(size = 768) {
    this.size = size;
    this.cv = makeCanvas(size, size);
    this.g = this.cv.getContext('2d', { willReadFrequently: false });
    this.o = size / 2; // 원점(부위 피벗)이 캔버스 중앙
    this.R = rng(1);
    this.lineScale = 1;
    this.tint = null; // 먼 쪽 팔다리 등 전체 색 보정용 함수
  }

  begin(seed = 1) {
    const g = this.g;
    g.setTransform(1, 0, 0, 1, 0, 0);
    g.clearRect(0, 0, this.size, this.size);
    g.setTransform(1, 0, 0, 1, this.o, this.o);
    g.globalAlpha = 1;
    g.globalCompositeOperation = 'source-over';
    this.bb = [Infinity, Infinity, -Infinity, -Infinity];
    this.R = rng(seed);
  }

  _grow(pts, pad) {
    const b = this.bb;
    for (const p of pts) {
      if (p[0] - pad < b[0]) b[0] = p[0] - pad;
      if (p[1] - pad < b[1]) b[1] = p[1] - pad;
      if (p[0] + pad > b[2]) b[2] = p[0] + pad;
      if (p[1] + pad > b[3]) b[3] = p[1] + pad;
    }
  }

  /** 그려진 영역만 잘라 {img, ox, oy}(피벗 기준 왼쪽 위) 반환 */
  end() {
    const b = this.bb, o = this.o, S = this.size;
    if (!isFinite(b[0])) return { img: makeCanvas(1, 1), ox: 0, oy: 0 };
    const x0 = clamp(Math.floor(b[0] + o) - 2, 0, S), y0 = clamp(Math.floor(b[1] + o) - 2, 0, S);
    const x1 = clamp(Math.ceil(b[2] + o) + 2, 0, S), y1 = clamp(Math.ceil(b[3] + o) + 2, 0, S);
    const w = Math.max(1, x1 - x0), h = Math.max(1, y1 - y0);
    const c = makeCanvas(w, h);
    c.getContext('2d').drawImage(this.cv, x0, y0, w, h, 0, 0, w, h);
    return { img: c, ox: x0 - o, oy: y0 - o };
  }

  _path(pts, closed) {
    const p = new Path2D();
    p.moveTo(pts[0][0], pts[0][1]);
    for (let i = 1; i < pts.length; i++) p.lineTo(pts[i][0], pts[i][1]);
    if (closed) p.closePath();
    return p;
  }

  _jitter(pts, amt) {
    if (!amt) return pts;
    const R = this.R;
    return pts.map((p) => (p[2] === 'c' ? [p[0] + (R() - 0.5) * amt, p[1] + (R() - 0.5) * amt, 'c'] : [p[0] + (R() - 0.5) * amt, p[1] + (R() - 0.5) * amt]));
  }

  _col(c) { return this.tint ? this.tint(c) : c; }

  /**
   * 채색(담채): 한지 바탕 위에 반투명 안료를 두 번 겹쳐 올린다.
   * 농담(위는 옅게, 아래·가장자리는 짙게) + 번짐 얼룩 + 안료가 고인 가장자리 + 한지 섬유가 비치는 결.
   */
  _wash(path, pts, color, o) {
    const g = this.g, R = this.R;
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (const p of pts) { x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]); x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]); }
    const w = x1 - x0, h = y1 - y0;
    const dark = luminance(color) < 0.28;
    // 1) 한지 바탕(완전 불투명: alphaTest용)
    g.fillStyle = dark ? shade(color, 0.25) : PAPER;
    g.fill(path);
    g.save();
    g.clip(path);
    // 2) 안료 두 겹(살짝 어긋나게) — 종이가 비친다
    const k = o.pigment == null ? (dark ? 0.95 : 0.8) : o.pigment;
    g.globalAlpha = k * 0.75;
    g.fillStyle = color;
    g.fillRect(x0 - 2, y0 - 2, w + 4, h + 4);
    g.globalAlpha = k * 0.45;
    g.translate((R() - 0.5) * 3, (R() - 0.5) * 3);
    g.fill(path);
    g.setTransform(1, 0, 0, 1, this.o, this.o);
    g.globalAlpha = 1;
    // 3) 번짐 얼룩(물 자국)
    if (o.blot !== false) {
      const nb = 2 + Math.floor(R() * 3);
      for (let i = 0; i < nb; i++) {
        const cx = x0 + R() * w, cy = y0 + R() * h, r = Math.max(w, h) * (0.25 + R() * 0.45);
        const gr = g.createRadialGradient(cx, cy, r * 0.55, cx, cy, r);
        const dk = R() < 0.6;
        // 가장자리에 안료가 고인 둥근 물 자국
        gr.addColorStop(0, rgba(dk ? shade(color, -0.2) : shade(color, 0.45), 0.0));
        gr.addColorStop(0.85, rgba(dk ? shade(color, -0.3) : shade(color, 0.45), 0.16));
        gr.addColorStop(1, rgba(color, 0));
        g.fillStyle = gr;
        g.fillRect(x0 - 2, y0 - 2, w + 4, h + 4);
      }
    }
    // 4) 농담: 위는 옅게(빛), 아래는 짙게
    if (o.shadeDown !== 0) {
      const kd = o.shadeDown == null ? 0.3 : o.shadeDown;
      const gr = g.createLinearGradient(0, y0, 0, y1);
      gr.addColorStop(0, rgba(shade(color, 0.5), kd * 0.6));
      gr.addColorStop(0.5, rgba(color, 0));
      gr.addColorStop(1, rgba(shade(color, -0.45), kd));
      g.fillStyle = gr;
      g.fillRect(x0 - 2, y0 - 2, w + 4, h + 4);
    }
    // 5) 한지 결
    g.globalCompositeOperation = 'multiply';
    g.globalAlpha = o.grain == null ? 1 : o.grain;
    g.fillStyle = g.createPattern(grainCanvas(), 'repeat');
    g.fillRect(x0 - 2, y0 - 2, w + 4, h + 4);
    g.globalAlpha = 1;
    g.globalCompositeOperation = 'source-over';
    // 6) 가장자리에 고인 안료
    if (o.edge !== false) {
      g.strokeStyle = rgba(shade(color, -0.45), 0.3);
      g.lineWidth = 7 * this.lineScale;
      g.stroke(path);
      g.strokeStyle = rgba(shade(color, -0.55), 0.28);
      g.lineWidth = 2.4 * this.lineScale;
      g.stroke(path);
    }
    g.restore();
  }

  /**
   * 붓 먹선: 붓 방향(비스듬한 붓끝)에 따른 굵기 + 필압 흔들림 + 끝 가늘어짐.
   * dry: 끝부분에 갈필(마른 붓 자국) — 종이색 가는 결을 겹친다.
   */
  _ink(pts, closed, w, color, taper, dry) {
    const g = this.g, R = this.R;
    const n = pts.length;
    if (n < 2) return;
    let total = 0;
    const acc = [0];
    const segs = closed ? n : n - 1;
    for (let i = 0; i < segs; i++) {
      const a = pts[i], b = pts[(i + 1) % n];
      total += Math.hypot(b[0] - a[0], b[1] - a[1]);
      acc.push(total);
    }
    const ph1 = R() * 6.28, ph2 = R() * 6.28, f1 = 0.07 + R() * 0.05, f2 = 0.02 + R() * 0.02;
    const brush = -0.75; // 붓끝 각도
    // 닫힌 선: 한두 군데 붓을 살짝 드는 곳
    const lifts = closed ? [R() * total, R() * total] : [];
    g.strokeStyle = color;
    g.lineCap = 'round';
    const widths = [];
    for (let i = 0; i < segs; i++) {
      const a = pts[i], b = pts[(i + 1) % n];
      const s = acc[i];
      const th = Math.atan2(b[1] - a[1], b[0] - a[0]);
      let k = (0.62 + 0.5 * Math.abs(Math.sin(th - brush))) * (0.85 + 0.2 * Math.sin(s * f1 + ph1) + 0.12 * Math.sin(s * f2 + ph2));
      for (const L of lifts) { const d = Math.abs(s - L); if (d < 10) k *= 0.45 + 0.055 * d; }
      if (taper && !closed) {
        const t = s / (total || 1);
        // 들어가는 붓(짧게 굵어짐) → 빠지는 붓(길게 가늘어짐)
        k *= Math.pow(clamp(Math.min(t / 0.12, (1 - t) / 0.35), 0, 1), 0.7) * 0.8 + 0.2;
      }
      const lw = Math.max(0.45, w * k);
      widths.push(lw);
      g.lineWidth = lw;
      g.beginPath();
      g.moveTo(a[0], a[1]);
      g.lineTo(b[0], b[1]);
      g.stroke();
    }
    if (dry && total > 20) {
      // 갈필: 굵은 선 끝 35%에 종이색 가는 결 두세 줄
      g.save();
      g.strokeStyle = rgba(PAPER, 0.75);
      g.lineCap = 'butt';
      const lines = 2 + Math.floor(R() * 2);
      for (let l = 0; l < lines; l++) {
        const off = (R() - 0.5) * 0.7;
        const startT = 0.55 + R() * 0.2;
        g.lineWidth = 0.6 + R() * 0.6;
        g.beginPath();
        let started = false;
        for (let i = 0; i < segs; i++) {
          if (acc[i] / total < startT) continue;
          const a = pts[i], b = pts[(i + 1) % n];
          const nx = -(b[1] - a[1]), ny = b[0] - a[0], nl = Math.hypot(nx, ny) || 1;
          const o2 = off * widths[i];
          const x = a[0] + (nx / nl) * o2, y = a[1] + (ny / nl) * o2;
          if (!started) { g.moveTo(x, y); started = true; } else g.lineTo(x, y);
        }
        g.stroke();
      }
      g.restore();
    }
  }

  /**
   * 닫힌 도형: 담채 + 먹선
   * o: { ink:false|color, w, smooth, rough, grain, edge, blot, shadeDown }
   */
  poly(pts, fill, o = {}) {
    const rough = o.rough == null ? 0.8 : o.rough;
    let P = this._jitter(pts, rough);
    P = o.smooth === false ? P.map((p) => [p[0], p[1]]) : smoothPts(P, true);
    const w = (o.w == null ? 2.3 : o.w) * this.lineScale;
    this._grow(P, w);
    const path = this._path(P, true);
    if (fill) this._wash(path, P, this._col(fill), o);
    if (o.ink !== false) this._ink(P, true, w, o.ink || INK, false);
    return path;
  }

  ellipse(cx, cy, rx, ry, fill, o = {}) {
    return this.poly(ellipsePts(cx, cy, rx, ry, Math.max(14, Math.round((rx + ry) * 0.6))), fill, { smooth: false, ...o });
  }

  /** 열린 붓선 */
  stroke(pts, o = {}) {
    const rough = o.rough == null ? 0.5 : o.rough;
    let P = this._jitter(pts, rough);
    P = o.smooth === false ? P : smoothPts(P, false, 2.5);
    const w = (o.w == null ? 2 : o.w) * this.lineScale;
    this._grow(P, w);
    this._ink(P, false, w, o.color ? this._col(o.color) : INK, o.taper !== false, o.dry);
  }

  /** 먹선 없는 평면 채움(볼 연지, 눈동자 등) */
  fill(pts, color, o = {}) {
    const P = o.smooth === false ? pts : smoothPts(pts, true);
    this._grow(P, 1);
    const g = this.g;
    g.save();
    if (o.alpha != null) g.globalAlpha = o.alpha;
    g.fillStyle = this._col(color);
    g.fill(this._path(P, true));
    g.restore();
  }

  dot(x, y, r, color = INK) {
    const g = this.g;
    this._grow([[x, y]], r);
    g.fillStyle = color;
    g.beginPath();
    g.arc(x, y, r, 0, Math.PI * 2);
    g.fill();
  }

  /** 갈필 털 뭉치: 윤곽 점들에서 바깥(nx,ny 방향)으로 짧은 붓질 */
  fur(pts, len, color = INK, w = 1.3, spread = 0.5) {
    const R = this.R;
    for (const p of pts) {
      const a = Math.atan2(p[3], p[2]) + (R() - 0.5) * spread;
      const L = len * (0.6 + R() * 0.6);
      this.stroke([[p[0], p[1]], [p[0] + Math.cos(a) * L * 0.55 + (R() - 0.5) * 2, p[1] + Math.sin(a) * L * 0.55], [p[0] + Math.cos(a) * L, p[1] + Math.sin(a) * L]], { w, color, rough: 0.2 });
    }
  }

  /** 볼 연지처럼 번지는 둥근 색 (반드시 불투명한 면 위에) */
  blush(x, y, r, color, a = 0.35) {
    const g = this.g;
    const gr = g.createRadialGradient(x, y, 0, x, y, r);
    gr.addColorStop(0, rgba(color, a));
    gr.addColorStop(1, rgba(color, 0));
    g.fillStyle = gr;
    g.fillRect(x - r, y - r, r * 2, r * 2);
  }

  /** 도형 안쪽으로만 그리기(줄무늬, 무늬) */
  clip(path, fn) {
    const g = this.g;
    g.save();
    g.clip(path);
    fn(g);
    g.restore();
  }
}

/** 이미 그려진 부위 이미지를 어둡게(먼 쪽 팔다리) 복사 */
export function darkenCopy(img, amount = 0.2, color = '#2a2230') {
  const c = makeCanvas(img.width, img.height), g = c.getContext('2d');
  g.drawImage(img, 0, 0);
  g.globalCompositeOperation = 'source-atop';
  g.fillStyle = rgba(color, amount);
  g.fillRect(0, 0, c.width, c.height);
  return c;
}
