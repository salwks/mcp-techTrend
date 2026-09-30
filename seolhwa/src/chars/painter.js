// 설화록 — 민화풍 캔버스 붓 도구 (먹선, 담채, 한지 결)
// 모든 도형은 점 목록으로 받아 부드러운 곡선(캣멀롬)으로 그리고,
// 담채(평면 색 + 얼룩 + 한지 결 + 번짐 테두리) 위에 굵기가 변하는 먹선을 긋는다.
// Painter는 부위(part) 하나를 임시 캔버스에 그린 뒤 그려진 영역만 잘라 돌려준다.

export const INK = '#29231f';

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

  /** 담채: 평면 색 + 옅은 얼룩 + 아래쪽 그늘 + 한지 결 + 번짐 테두리 */
  _wash(path, pts, color, o) {
    const g = this.g, R = this.R;
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (const p of pts) { x0 = Math.min(x0, p[0]); y0 = Math.min(y0, p[1]); x1 = Math.max(x1, p[0]); y1 = Math.max(y1, p[1]); }
    const w = x1 - x0, h = y1 - y0;
    g.fillStyle = color;
    g.fill(path);
    g.save();
    g.clip(path);
    if (o.blot !== false) {
      const nb = 2 + Math.floor(R() * 2);
      for (let i = 0; i < nb; i++) {
        const cx = x0 + R() * w, cy = y0 + R() * h, r = Math.max(w, h) * (0.3 + R() * 0.4);
        const gr = g.createRadialGradient(cx, cy, 0, cx, cy, r);
        const dark = R() < 0.55;
        gr.addColorStop(0, rgba(dark ? shade(color, -0.35) : shade(color, 0.5), 0.13));
        gr.addColorStop(1, rgba(color, 0));
        g.fillStyle = gr;
        g.fillRect(x0 - 2, y0 - 2, w + 4, h + 4);
      }
    }
    if (o.shadeDown !== 0) {
      const k = o.shadeDown == null ? 0.22 : o.shadeDown;
      const gr = g.createLinearGradient(0, y0, 0, y1);
      gr.addColorStop(0, rgba(shade(color, 0.3), k * 0.5));
      gr.addColorStop(0.55, rgba(color, 0));
      gr.addColorStop(1, rgba(shade(color, -0.4), k));
      g.fillStyle = gr;
      g.fillRect(x0 - 2, y0 - 2, w + 4, h + 4);
    }
    g.globalCompositeOperation = 'multiply';
    g.globalAlpha = o.grain == null ? 0.9 : o.grain;
    const pat = g.createPattern(grainCanvas(), 'repeat');
    g.fillStyle = pat;
    g.fillRect(x0 - 2, y0 - 2, w + 4, h + 4);
    g.globalAlpha = 1;
    g.globalCompositeOperation = 'source-over';
    if (o.edge !== false) {
      g.strokeStyle = rgba(shade(color, -0.4), 0.35);
      g.lineWidth = 5 * this.lineScale;
      g.stroke(path);
    }
    g.restore();
  }

  /** 굵기가 변하는 붓 먹선 */
  _ink(pts, closed, w, color, taper) {
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
    const ph1 = R() * 6.28, ph2 = R() * 6.28, f1 = 0.09 + R() * 0.05, f2 = 0.025 + R() * 0.02;
    g.strokeStyle = color;
    g.lineCap = 'round';
    for (let i = 0; i < segs; i++) {
      const a = pts[i], b = pts[(i + 1) % n];
      const s = acc[i];
      let k = 0.78 + 0.22 * Math.sin(s * f1 + ph1) + 0.14 * Math.sin(s * f2 + ph2);
      if (taper && !closed) {
        const t = s / (total || 1);
        k *= Math.pow(clamp(Math.min(t / 0.2, (1 - t) / 0.25), 0, 1), 0.6) * 0.75 + 0.25;
      }
      g.lineWidth = Math.max(0.5, w * k);
      g.beginPath();
      g.moveTo(a[0], a[1]);
      g.lineTo(b[0], b[1]);
      g.stroke();
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
    this._ink(P, false, w, o.color ? this._col(o.color) : INK, o.taper !== false);
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
