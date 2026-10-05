"""조선 고지도풍 지도 그림(오프라인) — 대동여지도·동여도·해동지도(권역·전국)와 군현지도·도성도(고을) 방식.
런타임(scripts/region/region_map.gd)은 이 그림을 깔고 그 위에 이름·기호·사건 표지·플레이어만 그린다(글자는 화면 크기 고정).

  python3 tools/region/render_joseon_map.py JL_NAMWON_UNBONG     # 권역(L2) + 고을(L3) 그림
  python3 tools/region/render_joseon_map.py all                  # 여덟 권역 + 전국
  python3 tools/region/render_joseon_map.py nation               # 전국(L0) — 지형은 terrarium z7 DEM(캐시)에서

산출:
  region_data/<id>/map/l2.webp          권역 그림(한지·산줄기·물길 겹줄/외줄·바다 물결·붉은 길과 10리 눈금·테두리·제목 곽·방위·붉은 인장)
  region_data/<id>/map/city_<n>.webp    고을 그림(성벽·성문·기와/초가 지붕 그림·둘레 산·내·길·논밭 무늬)
  region_data/<id>/map.json             {file, x0, z0, scale, w, h, li_m(10리 게임 m), cities:[{file,x0,z0,scale,w,h,ids}], reserved:[[x0,z0,x1,z1]]}
  region_data/nation_map.webp, nation_map.json   {file, lon0, lat0, lon1, lat1, w, h}

산 그리기: DEM을 뒤집어 흐름 누적(물길 찾기와 같은 셈)을 하면 산등성이가 '물길'로 모인다 → 그 선을 따라 산봉우리 그림을
남쪽(앞)이 북쪽(뒤)을 덮게 겹쳐 세운다(바림 + 먹 윤곽). 음영(hillshade)은 쓰지 않는다.
"""
import heapq, json, math, os, sys, glob, hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
RD = os.path.join(ROOT, "region_data")
SS = 2                      # 그릴 때 2배로 그려 줄인다(가장자리 부드럽게)
FONT_PATHS = ["/System/Library/Fonts/Supplemental/AppleMyungjo.ttf", "/Library/Fonts/NanumMyeongjo.ttf"]

PAPER = (236, 225, 199)
INK = (46, 40, 34)
MTN_FILL = [(122, 150, 128), (108, 140, 126), (134, 160, 132), (116, 146, 140)]
MTN_DARK = (74, 104, 98)
WASH_GREEN = (150, 172, 140)
WATER = (178, 204, 206)
WATER_INK = (72, 112, 132)
SEA = (196, 214, 210)
ROAD_RED = (176, 58, 40)
ROAD_OCHRE = (186, 140, 84)
SEAL_RED = (178, 42, 32)
LI_KM = 4.2                 # 10리 ≈ 4.2km(실거리) — 게임에서는 권역 압축 K를 곱한다


def font(sz):
    for p in FONT_PATHS:
        if os.path.exists(p): return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def rng_for(*keys):
    h = hashlib.md5("|".join(map(str, keys)).encode()).hexdigest()
    return np.random.default_rng(int(h[:8], 16))


# ---------------------------------------------------------------- 한지
def hanji(w, h, rng, edge=True):
    """한지 바탕: 얼룩·섬유·가장자리 바램(누렇게)."""
    base = np.empty((h, w, 3), np.float32); base[:] = PAPER
    lo = ndi.gaussian_filter(rng.standard_normal((h // 8 + 2, w // 8 + 2)).astype(np.float32), 3)
    lo = np.array(Image.fromarray(((lo - lo.min()) / (np.ptp(lo) + 1e-6) * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR), np.float32) / 255.0 - 0.5
    fine = ndi.gaussian_filter(rng.standard_normal((h, w)).astype(np.float32), 0.7)
    base += lo[..., None] * np.array([10, 9, 7]) + fine[..., None] * 3.0
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(int(w * h / 900)):   # 섬유
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        a = rng.uniform(0, math.pi); L = rng.uniform(4, 16)
        c = (255, 250, 236, 60) if rng.random() < 0.6 else (150, 130, 100, 30)
        d.line([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L)], fill=c, width=1)
    if edge:
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        dd = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
        m = np.clip(1.0 - dd / (min(w, h) * 0.08), 0, 1) ** 1.6
        m = m * (0.8 + 0.4 * (lo + 0.5))
        arr = np.asarray(img, np.float32)
        arr = arr * (1 - m[..., None] * 0.22) + np.array([150, 118, 70], np.float32) * m[..., None] * 0.22
        img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    return img


def overlay(img, layer, alpha=1.0):
    if alpha < 1.0:
        a = layer.getchannel("A").point(lambda v: int(v * alpha)); layer.putalpha(a)
    return Image.alpha_composite(img.convert("RGBA"), layer)


# ---------------------------------------------------------------- 붓질
def brush(d, pts, w, col, taper=True):
    """붓 선: 양끝이 가늘고 가운데가 굵다."""
    n = len(pts)
    if n < 2: return
    for i in range(n - 1):
        t = (i + 0.5) / (n - 1)
        ww = w * ((0.45 + 0.75 * math.sin(math.pi * t)) if taper else 1.0)
        d.line([pts[i], pts[i + 1]], fill=col, width=max(1, int(round(ww))))
        r = ww / 2.0
        if r > 1.2: d.ellipse([pts[i + 1][0] - r, pts[i + 1][1] - r, pts[i + 1][0] + r, pts[i + 1][1] + r], fill=col)


def chaikin(pts, n=2):
    for _ in range(n):
        if len(pts) < 3: return pts
        out = [pts[0]]
        for a, b in zip(pts[:-1], pts[1:]):
            out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
            out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
        out.append(pts[-1]); pts = out
    return pts


def resample(pts, step):
    """꺾은선을 같은 간격으로."""
    if len(pts) < 2: return list(pts)
    out = [pts[0]]; acc = 0.0
    for a, b in zip(pts[:-1], pts[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        while acc + L >= step and L > 0:
            t = (step - acc) / L
            a = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            out.append(a); L = math.hypot(b[0] - a[0], b[1] - a[1]); acc = 0.0
        acc += L
    return out


PEAK_KINDS = ("rock", "earth", "twin", "lean", "flat")


def peak_poly(x, y, hgt, wid, kind, rng, asym=0.0):
    """산봉우리 하나(밑변 열림, 왼쪽 밑 → 꼭대기 → 오른쪽 밑).
    kind: 'rock' 뾰족(석산, 오목한 옆선) · 'earth' 둥근(토산) · 'twin' 쌍봉 · 'lean' 한쪽 어깨가 긴 비탈 · 'flat' 둥근 등(평평한 마루).
    asym: −1~1 꼭대기를 옆으로 민다(어깨 길이가 다르게)."""
    sk = (rng.uniform(-0.12, 0.12) + asym * 0.22) * wid
    lw = wid / 2 * (1 + asym * 0.35); rw = wid / 2 * (1 - asym * 0.35)
    tx, ty = x + sk, y - hgt
    L, R = (tx - lw - sk * 0.3, y), (tx + rw - sk * 0.3, y)
    def side(a, b, up, n=9, concave=True, pw=0.8):
        """a → b 비탈. up: 오르막(밑→꼭대기), 아니면 내리막. 높이는 두 끝 y 사이를 오목/볼록하게 잇는다"""
        out = []
        for i in range(n):
            t = i / (n - 1)
            px = a[0] + (b[0] - a[0]) * t
            if up: f = t ** 0.75 if concave else math.sin(t * math.pi / 2) ** pw
            else: f = (t ** 1.33) if concave else (1 - math.cos(t * math.pi / 2)) ** 1.25
            out.append((px, a[1] + (b[1] - a[1]) * f))
        return out
    if kind == "rock":
        return side(L, (tx, ty), True) + side((tx, ty), R, False)[1:]
    if kind == "twin":   # 큰 봉우리 옆에 낮은 봉우리 하나(안장으로 이음)
        s2 = 1 if rng.random() < 0.5 else -1
        h2 = hgt * rng.uniform(0.55, 0.78)
        mx = tx + s2 * wid * 0.28; my = y - hgt * rng.uniform(0.38, 0.5)
        x2 = tx + s2 * wid * 0.48
        if s2 > 0:
            pts = side(L, (tx, ty), True, concave=False) + [(mx, my), (x2, y - h2)] + side((x2, y - h2), (R[0] + wid * 0.18, y), False, concave=False)[1:]
        else:
            pts = side((L[0] - wid * 0.18, y), (x2, y - h2), True, concave=False) + [(mx, my), (tx, ty)] + side((tx, ty), R, False, concave=False)[1:]
        return pts
    if kind == "lean":   # 한쪽은 가파르고 한쪽은 길게 흘러내림
        long_r = asym <= 0
        A = (L[0] - (0 if long_r else wid * 0.35), y); B = (R[0] + (wid * 0.35 if long_r else 0), y)
        return side(A, (tx, ty), True, concave=not long_r) + side((tx, ty), B, False, concave=long_r)[1:]
    if kind == "flat":   # 둥근 등: 꼭대기가 넓게 이어짐
        a = (tx - wid * 0.16, ty + hgt * 0.04); b = (tx + wid * 0.16, ty + hgt * 0.02)
        return side(L, a, True, concave=False, pw=0.6) + [(tx, ty)] + side(b, R, False, concave=False)
    return side(L, (tx, ty), True, concave=False) + side((tx, ty), R, False, concave=False)[1:]


def draw_peak(d, x, y, hgt, wid, rng, ss, kind=None, fill=None, ink=1.0, wash=None):
    """봉우리 하나: 청록 바탕 + 꼭대기 쪽 짙은 바림 + 준법 먹선 + 붓 윤곽. ink: 먹 굵기 배율(진하고 옅은 붓), wash: 꼭대기 바림 세기(0.7~0.92 — 작을수록 짙다)."""
    kind = kind or ("rock" if hgt > wid * 0.75 else "earth")
    asym = rng.uniform(-1, 1) * (0.25 if kind == "rock" else 0.7)
    poly = peak_poly(x, y, hgt, wid, kind, rng, asym)
    col = fill or MTN_FILL[int(rng.integers(len(MTN_FILL)))]
    jit = int(rng.integers(-10, 10))
    col = tuple(max(0, min(255, c + jit + int(rng.integers(-4, 5)))) for c in col)
    x0 = min(p[0] for p in poly); x1 = max(p[0] for p in poly)
    d.polygon(poly + [(x1, y + 1 * ss), (x0, y + 1 * ss)], fill=col)
    # 꼭대기 쪽 짙은 바림(먹 번짐) — 세기·넓이를 봉우리마다 달리
    ti = min(range(len(poly)), key=lambda i: poly[i][1]); top = poly[ti]
    k = wash if wash is not None else rng.uniform(0.72, 0.9)
    sc = rng.uniform(0.32, 0.55)
    inner = [(top[0] + (p[0] - top[0]) * sc, top[1] + (p[1] - top[1]) * sc) for p in poly]
    d.polygon(inner, fill=tuple(int(c * k) for c in col))
    if kind == "twin":   # 낮은 봉우리에도 옅은 바림
        lo = sorted(range(len(poly)), key=lambda i: poly[i][1])
        for i in lo[1:]:
            if abs(poly[i][0] - top[0]) > (x1 - x0) * 0.25:
                t2 = poly[i]
                d.polygon([(t2[0] + (p[0] - t2[0]) * sc * 0.6, t2[1] + (p[1] - t2[1]) * sc * 0.6) for p in poly], fill=tuple(int(c * (k + 0.05)) for c in col))
                break
    # 준법(皴法): 큰 봉우리일수록 여러 줄, 비스듬히(꼭대기에서 비탈 따라)
    nst = 0 if hgt < 7 * ss else int(rng.integers(1, 2 + min(4, int(hgt / (9 * ss)))))
    for _ in range(nst):
        t = rng.uniform(0.25, 0.75)
        side_ = 1 if rng.random() < 0.5 else -1
        sx = top[0] + side_ * rng.uniform(0.05, 0.3) * (x1 - x0)
        sy = top[1] + hgt * t * 0.55
        ln = hgt * rng.uniform(0.18, 0.38)
        brush(d, [(sx, sy), (sx + side_ * ln * rng.uniform(0.15, 0.5), sy + ln)], rng.uniform(0.7, 1.3) * ss * ink, (*MTN_DARK, 255))
    # 윤곽(밑변 없이): 굵기 배율 · 가끔 마른 붓(어깨 끝을 끊음)
    w = max(1.0, min(2.6, hgt / (10 * ss) + 0.8)) * ss * ink * rng.uniform(0.8, 1.2)
    if rng.random() < 0.3 and len(poly) > 8:
        a = int(rng.integers(0, 3)); b = len(poly) - int(rng.integers(0, 3))
        brush(d, poly[a:b], w, (*INK, 255))
    else:
        brush(d, poly, w, (*INK, 255))


# ---------------------------------------------------------------- 등성이(뒤집은 DEM 흐름 누적)
def ridge_lines(z, cell, min_acc, min_relief, relief_r, valid=None):
    """z: 높이(격자). 뒤집은 높이로 D8 흐름 → 누적이 큰 칸 = 등성이. 반환 [(꺾은선 [(i,j)…], 세기)…]."""
    H, W = z.shape
    zz = ndi.gaussian_filter(z, 1.0)
    relief = zz - ndi.minimum_filter(zz, size=int(relief_r / cell) * 2 + 1)
    order = np.argsort(zz, axis=None)              # 낮은 곳부터(뒤집으면 높은 곳부터 흐른다)
    flat = zz.ravel()
    recv = np.full(H * W, -1, np.int64)
    best = np.zeros(H * W, np.float32)
    for di, dj in [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]:
        dist = math.hypot(di, dj)
        sh = np.full((H, W), -np.inf, np.float32)
        ys = slice(max(0, -di), H - max(0, di)); yd = slice(max(0, di), H - max(0, -di))
        xs = slice(max(0, -dj), W - max(0, dj)); xd = slice(max(0, dj), W - max(0, -dj))
        sh[ys, xs] = zz[yd, xd]
        gain = ((sh - zz) / dist).ravel()
        idx = np.arange(H * W).reshape(H, W)
        nb = np.full((H, W), -1, np.int64); nb[ys, xs] = idx[yd, xd]
        nb = nb.ravel()
        m = gain > best
        best[m] = gain[m]; recv[m] = nb[m]
    acc = np.ones(H * W, np.float32)
    if valid is not None: acc[~valid.ravel()] = 0
    for c in order:                                # 낮은 칸 → 오르막 이웃으로 넘긴다
        r = recv[c]
        if r >= 0: acc[r] += acc[c]
    acc = acc.reshape(H, W)
    rid = (acc >= min_acc) & (relief >= min_relief)
    if valid is not None: rid &= valid
    rflat = rid.ravel()
    donors = np.zeros(H * W, np.int32)
    for c in np.flatnonzero(rflat):
        r = recv[c]
        if r >= 0 and rflat[r]: donors[r] += 1
    seen = np.zeros(H * W, bool)
    lines = []
    heads = [c for c in np.flatnonzero(rflat) if donors[c] == 0]
    heads.sort(key=lambda c: -flat[c])
    for h0 in heads:
        line = []; c = h0
        while c >= 0 and rflat[c]:
            line.append(c)
            if seen[c]: break
            seen[c] = True
            c = recv[c]
        if len(line) >= 3:
            pts = [(c % W, c // W) for c in line]
            strength = float(np.mean([relief.ravel()[c] for c in line]))
            lines.append((pts, strength))
    # 끝까지 못 간 등성이(머리 없이 남은 고리) 무시
    return lines, relief, acc


def peaks(z, cell, sep_m, min_relief, relief):
    mx = ndi.maximum_filter(z, size=int(sep_m / cell) * 2 + 1)
    m = (z >= mx - 1e-6) & (relief > min_relief)
    j, i = np.nonzero(m)
    return [(i[k], j[k]) for k in range(len(i))]


def paint_mountains(img, lines, relief, to_px, size_of, rng, ss, wash_alpha=0.55, wash_w=1.0, extra_peaks=(), spine=False):
    """등성이 꺾은선을 따라 바림 띠 + 먹 등줄기 + 겹친 봉우리. to_px(i,j)->(x,y) 그림 px(×ss), size_of(세기)->봉우리 높이 px(×ss).
    extra_peaks: 덧붙일 봉우리 후보(x, y, 높이, 모양) — 이미 선 봉우리와 겹치지 않는 것만 세운다."""
    W, H = img.size
    wash = Image.new("RGBA", img.size, (0, 0, 0, 0))
    wd = ImageDraw.Draw(wash)
    glyphs = []; spines = []
    grid = {}
    def free(x, y, sp):
        gk = (int(x // (24 * ss)), int(y // (24 * ss)))
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for (qx, qy) in grid.get((gk[0] + dx, gk[1] + dy), ()):
                    if (qx - x) ** 2 + ((qy - y) * 1.5) ** 2 < sp * sp: return False
        return True
    def put(x, y):
        grid.setdefault((int(x // (24 * ss)), int(y // (24 * ss))), []).append((x, y))
    for pts, s_ in sorted(lines, key=lambda t: -t[1]):
        P = chaikin([to_px(i, j) for i, j in pts], 2)
        hg = size_of(s_)
        if hg <= 0: continue
        brush(wd, P, hg * rng.uniform(1.4, 2.3) * wash_w, (*WASH_GREEN, int(rng.uniform(85, 165))), taper=True)   # 줄기마다 바림 넓이·농담
        if spine and hg > 14 * ss: spines.append((P, hg))
        # 한 줄기 = 무리: 높낮이가 물결치게(주봉 몇 + 낮은 자락), 간격·너비·모양·먹 굵기를 봉우리마다 달리. 가끔 앞쪽에 작은 앞산
        fine = resample(P, max(2.0, hg * 0.25))[1:]
        ph = rng.uniform(0, 2 * math.pi); fr = rng.uniform(0.18, 0.4)
        line_ink = rng.uniform(0.75, 1.3)        # 줄기마다 먹 농담
        k = int(rng.integers(0, 3))
        while k < len(fine):
            q = fine[k]
            wave = 0.62 + 0.55 * abs(math.sin(k * fr + ph))
            h = hg * wave * rng.uniform(0.85, 1.12)
            wd_ = h * rng.uniform(1.15, 2.0)
            x = q[0] + rng.uniform(-0.15, 0.15) * hg; y = q[1] + rng.uniform(-0.1, 0.1) * hg
            r = rng.random()
            kind = ("rock" if r < 0.55 else "lean" if r < 0.8 else "twin") if wave > 1.0 else \
                   ("earth" if r < 0.4 else "flat" if r < 0.6 else "lean" if r < 0.8 else "twin" if r < 0.9 else "rock")
            if kind == "rock": wd_ = h * rng.uniform(1.0, 1.4)
            put(x, y)
            glyphs.append((x, y, h, wd_, kind, line_ink * rng.uniform(0.85, 1.15)))
            if rng.random() < 0.3 and h > 8 * ss:   # 앞산(아래쪽, 작게)
                fx = x + rng.uniform(-0.6, 0.6) * wd_; fy = y + h * rng.uniform(0.3, 0.55)
                glyphs.append((fx, fy, h * rng.uniform(0.38, 0.6), h * rng.uniform(0.9, 1.4), "earth" if rng.random() < 0.7 else "flat", line_ink * 0.8))
            k += max(1, int(round(wd_ * rng.uniform(0.42, 0.72) / max(2.0, hg * 0.25))))
    for (x, y, hg, kind) in sorted(extra_peaks, key=lambda e: -e[2]):
        if not free(x, y, hg * 1.1): continue
        put(x, y)
        wd.ellipse([x - hg * 1.2, y - hg * 1.1, x + hg * 1.2, y + hg * 0.3], fill=(*WASH_GREEN, 130))
        glyphs.append((x, y, hg * rng.uniform(0.85, 1.15), hg * rng.uniform(1.2, 1.7), kind, rng.uniform(0.9, 1.2)))
    wash = wash.filter(ImageFilter.GaussianBlur(4 * ss))
    img = overlay(img, wash, wash_alpha)
    d = ImageDraw.Draw(img)
    for P, hg in spines: brush(d, P, max(1.5 * ss, hg * 0.12), (*MTN_DARK, 170))
    glyphs.sort(key=lambda g: g[1])
    for (x, y, hg, wd_, kind, ink) in glyphs:
        draw_peak(d, x, y, hg, wd_, rng, ss, kind=kind, ink=ink)
    return img



# ---------------------------------------------------------------- 산자분수령: 물길 유역의 경계 = 산줄기
def priority_flood(z, valid):
    """우선순위 범람(웅덩이 메움) D8 → receiver(낮은 쪽 이웃 칸 번호, 바깥으로 나가면 -1)와 처리 순서(낮은 칸 먼저)."""
    H, W = z.shape
    done = ~valid.copy()
    pq = []
    edge = np.zeros((H, W), bool); edge[0, :] = edge[-1, :] = edge[:, 0] = edge[:, -1] = True
    edge |= valid & ~ndi.binary_erosion(valid, iterations=1, border_value=0)
    for j, i in zip(*np.nonzero(edge & valid)):
        heapq.heappush(pq, (float(z[j, i]), int(j), int(i))); done[j, i] = True
    recv = -np.ones(H * W, np.int64); order = []
    NB = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
    zf = z.astype(np.float64).copy()
    while pq:
        h, j, i = heapq.heappop(pq)
        order.append(j * W + i)
        for dj, di in NB:
            jj, ii = j + dj, i + di
            if 0 <= jj < H and 0 <= ii < W and not done[jj, ii]:
                done[jj, ii] = True
                zf[jj, ii] = max(zf[jj, ii], h + 1e-4)
                recv[jj * W + ii] = j * W + i
                heapq.heappush(pq, (zf[jj, ii], jj, ii))
    return recv, order


def divide_points(z, valid, recv, order, stream_cells, relief, min_relief, levels):
    """유역 경계 칸 → [(i, j, 등급 0=큰 줄기…, relief)]. levels: 두 유역 중 작은 쪽 크기 기준(칸 수, 큰 것부터)."""
    H, W = z.shape
    N = H * W
    acc = np.ones(N, np.float64); acc[~valid.ravel()] = 0
    for c in reversed(order):
        r = recv[c]
        if r >= 0: acc[r] += acc[c]
    stream = acc >= stream_cells
    donors = np.zeros(N, np.int32)
    for c in np.flatnonzero(stream):
        r = recv[c]
        if r >= 0 and stream[r]: donors[r] += 1
    label = -np.ones(N, np.int64); size = []
    for c in order:                          # 낮은 칸(하류) 먼저
        r = recv[c]
        if stream[c]:
            if r >= 0 and stream[r] and donors[r] == 1: label[c] = label[r]
            else: label[c] = len(size); size.append(acc[c])
        elif r >= 0: label[c] = label[r]
        else: label[c] = len(size); size.append(acc[c])
    size = np.array(size + [0.0])
    L = label.reshape(H, W)
    imp = np.zeros((H, W))
    Lp = np.pad(L, 1, constant_values=-1)
    for dj, di in [(0, 1), (1, 0), (1, 1), (1, -1)]:
        bb = Lp[1 + dj:1 + dj + H, 1 + di:1 + di + W]
        diff = (L != bb) & (L >= 0) & (bb >= 0)
        imp = np.maximum(imp, np.minimum(size[L], size[bb]) * diff)
    imp *= (relief >= min_relief) & valid
    out = []
    for lv, th in enumerate(levels):
        hi = levels[lv - 1] if lv > 0 else np.inf
        j, i = np.nonzero((imp >= th) & (imp < hi))
        out += [(int(i[k]), int(j[k]), lv, float(relief[j[k], i[k]])) for k in range(len(i))]
    return out


# ---------------------------------------------------------------- 물결
def wave_layer(size, mask, ss, rng, col=(*WATER_INK, 120), spacing=22, river=False):
    """바다 물결 무늬(비늘 같은 둥근 물결 줄) — mask(L, 255=물) 안만."""
    W, H = size
    lay = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    sp = spacing * ss
    for row, y in enumerate(np.arange(sp * 0.5, H, sp * (1.4 if river else 0.75))):
        off = (row % 2) * sp * 0.5
        for x in np.arange(-sp + off, W + sp, sp * (2.2 if river else 1.0)):
            xx = x + rng.uniform(-0.15, 0.15) * sp; yy = y + rng.uniform(-0.1, 0.1) * sp
            if river:
                pts = [(xx + t * sp * 1.4, yy + math.sin(t * math.pi * 2) * sp * 0.08) for t in np.linspace(0, 1, 8)]
                d.line(pts, fill=col, width=max(1, ss))
            else:
                r = sp * 0.45
                d.arc([xx - r, yy - r * 0.6, xx + r, yy + r * 0.6], 200, 340, fill=col, width=max(1, ss))
    m = mask.filter(ImageFilter.MinFilter(5)) if mask.size == size else mask.resize(size)
    a = Image.fromarray((np.asarray(lay.getchannel("A"), np.float32) * (np.asarray(m, np.float32) / 255.0)).astype(np.uint8))
    lay.putalpha(a)
    return lay


def paint_water_mask(img, mask_big, fill, edge_col, ss, rng, waves=True, river=False):
    """물(바다·큰 강) 면: 바탕색 + 물가 먹선 + 물결."""
    m = mask_big.filter(ImageFilter.GaussianBlur(1.2 * ss)).point(lambda v: 255 if v > 127 else 0)
    fl = Image.new("RGBA", img.size, (*fill, 0)); fl.putalpha(m.point(lambda v: int(v * 0.92)))
    img = Image.alpha_composite(img, fl)
    if waves: img = Image.alpha_composite(img, wave_layer(img.size, m, ss, rng, river=river, spacing=16 if river else 20))
    edge = ImageChops_sub(m.filter(ImageFilter.MaxFilter(3)), m.filter(ImageFilter.MinFilter(3)))
    el = Image.new("RGBA", img.size, (*edge_col, 0)); el.putalpha(edge.point(lambda v: 200 if v > 60 else 0))
    return Image.alpha_composite(img, el)


def ImageChops_sub(a, b):
    from PIL import ImageChops
    return ImageChops.subtract(a, b)


def river_line(d, pts, width_px, double, ss):
    if len(pts) < 2: return
    P = chaikin(pts, 1)
    if double:
        w = max(width_px, 4.5 * ss)
        d.line(P, fill=(*WATER_INK, 255), width=int(w + 2.6 * ss), joint="curve")
        d.line(P, fill=(*WATER, 255), width=int(w), joint="curve")
    else:
        brush(d, P, max(1.4 * ss, width_px), (*WATER_INK, 230), taper=False)


def road_line(d, pts, w, col, ticks_every_px, ss, dashed=False):
    if len(pts) < 2: return
    if dashed:
        R = resample(pts, 5 * ss)
        for k in range(0, len(R) - 1, 2): d.line([R[k], R[k + 1]], fill=col, width=int(w))
        return
    d.line(pts, fill=col, width=int(w), joint="curve")
    if ticks_every_px and ticks_every_px > 6 * ss:
        R = resample(pts, ticks_every_px)
        for k in range(1, len(R)):
            a = R[k - 1]; b = R[k]
            dx, dy = b[0] - a[0], b[1] - a[1]; L = math.hypot(dx, dy) or 1
            nx, ny = -dy / L, dx / L
            t = 4.5 * ss
            d.line([(b[0] - nx * t, b[1] - ny * t), (b[0] + nx * t, b[1] + ny * t)], fill=(120, 30, 20, 255), width=max(1, int(1.3 * ss)))


def seal(d, cx, cy, sz, text, ss):
    """붉은 인장(네모, 흰 글씨)."""
    r = sz / 2
    d.rounded_rectangle([cx - r, cy - r, cx + r, cy + r], radius=sz * 0.08, fill=(*SEAL_RED, 235))
    d.rectangle([cx - r * 0.84, cy - r * 0.84, cx + r * 0.84, cy + r * 0.84], outline=(250, 236, 220, 220), width=max(1, int(sz * 0.04)))
    f = font(int(sz * 0.36))
    if len(text) <= 2:
        tw = d.textlength(text, font=f); d.text((cx - tw / 2, cy - sz * 0.22), text, font=f, fill=(250, 238, 224, 255))
    else:   # 2×2
        chars = list(text[:4])
        for k, ch in enumerate(chars):
            col_ = 1 - k // 2; row = k % 2
            x = cx - r * 0.42 + col_ * r * 0.84 * (1 if len(chars) > 2 else 0); y = cy - r * 0.62 + row * r * 0.8
            tw = d.textlength(ch, font=f); d.text((x - tw / 2 + (0 if len(chars) > 2 else r * 0.0), y), ch, font=f, fill=(250, 238, 224, 255))


def frame_and_cartouche(img, title, sub, ss, rng, compass=True):
    """테두리(겹선)·제목 곽(오른쪽 위, 세로쓰기 느낌)·방위·붉은 인장. 반환: 예약한 그림 px 상자들."""
    W, H = img.size
    d = ImageDraw.Draw(img)
    m = 7 * ss
    d.rectangle([m, m, W - 1 - m, H - 1 - m], outline=(*INK, 255), width=int(3.2 * ss))
    d.rectangle([m + 6 * ss, m + 6 * ss, W - 1 - m - 6 * ss, H - 1 - m - 6 * ss], outline=(*INK, 200), width=int(1.1 * ss))
    reserved = []
    # 제목 곽
    f = font(int(26 * ss)); fs = font(int(13 * ss))
    tw = d.textlength(title, font=f)
    sw = d.textlength(sub, font=fs) if sub else 0
    bw = max(tw, sw) + 40 * ss; bh = (26 + (22 if sub else 0) + 26) * ss
    x1 = W - 1 - m - 18 * ss; x0 = x1 - bw; y0 = m + 18 * ss; y1 = y0 + bh
    d.rectangle([x0, y0, x1, y1], fill=(242, 233, 210, 255), outline=(*INK, 255), width=int(2 * ss))
    d.rectangle([x0 + 4 * ss, y0 + 4 * ss, x1 - 4 * ss, y1 - 4 * ss], outline=(*INK, 160), width=max(1, ss))
    d.text((x0 + (bw - tw) / 2, y0 + 10 * ss), title, font=f, fill=(*INK, 255))
    if sub: d.text((x0 + (bw - sw) / 2, y0 + 44 * ss), sub, font=fs, fill=(90, 70, 52, 255))
    seal(d, x0 - 4 * ss, y1 + 2 * ss, 30 * ss, "설화", ss)
    reserved.append((x0 - 22 * ss, y0, x1, y1 + 20 * ss))
    if compass:   # 방위(왼쪽 위): 둥근 테 + 사방 글자
        cx, cy, r = m + 52 * ss, m + 52 * ss, 30 * ss
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(242, 233, 210, 230), outline=(*INK, 255), width=int(1.6 * ss))
        d.ellipse([cx - r * 0.2, cy - r * 0.2, cx + r * 0.2, cy + r * 0.2], fill=(*SEAL_RED, 255))
        fc = font(int(14 * ss))
        for ch, (dx, dy) in [("북", (0, -1)), ("남", (0, 1)), ("동", (1, 0)), ("서", (-1, 0))]:
            tw = d.textlength(ch, font=fc)
            d.text((cx + dx * r * 0.62 - tw / 2, cy + dy * r * 0.62 - 8 * ss), ch, font=fc, fill=(*(SEAL_RED if ch == "북" else INK), 255))
        reserved.append((cx - r - 4 * ss, cy - r - 4 * ss, cx + r + 4 * ss, cy + r + 4 * ss))
    return reserved


# ---------------------------------------------------------------- 권역 자료
def load_region(rid):
    d = os.path.join(RD, rid)
    reg = json.load(open(os.path.join(d, "region.json"), encoding="utf-8"))
    hm = reg["height"]
    h16 = np.array(Image.open(os.path.join(d, hm["file"])), dtype=np.float32)
    y = hm["y_min"] + h16 / 65535.0 * (hm["y_max"] - hm["y_min"])
    lu = None
    if reg.get("landuse") and os.path.exists(os.path.join(d, reg["landuse"]["file"])):
        lu = np.array(Image.open(os.path.join(d, reg["landuse"]["file"])))
        if lu.ndim == 3: lu = lu[..., 0]
    return reg, y, lu


def sea_mask_game(reg, y, lu):
    """landuse 물(5) 중 수면 높이 칸 → 열림(좁은 물길 제거). landuse 격자(4m) 불리언."""
    if lu is None or not reg.get("sea"): return None
    hm = reg["height"]; lc = reg["landuse"]["cell"]
    st = int(round(lc / hm["cell"]))
    yy = y[::st, ::st][:lu.shape[0], :lu.shape[1]]
    sy = float(reg["sea"].get("y", 0.0))
    m = (lu == 5) & (yy <= sy + 0.6)
    m = ndi.binary_opening(m, iterations=4)
    for l in reg.get("lakes", []) or []:
        pass
    return m


def placement_items(rid):
    out = []
    for f in sorted(glob.glob(os.path.join(RD, rid, "placement_*.json"))):
        try: d = json.load(open(f, encoding="utf-8"))
        except Exception: continue
        out += d.get("items", [])
    return out


_CAT = None
def catalog_fp(kit, params):
    global _CAT
    if _CAT is None:
        _CAT = {}
        for dd in ["village", "landmark", "nature", "route", "scenario"]:
            p = os.path.join(ROOT, "kit", dd, "catalog.json")
            if not os.path.exists(p): continue
            try: c = json.load(open(p, encoding="utf-8"))
            except Exception: continue
            for m in c.get("models", []):
                if isinstance(m, dict) and "name" in m: _CAT["%s/%s" % (dd, m["name"])] = m
    m = _CAT.get(kit)
    if not isinstance(m, dict): return None
    for v in m.get("variants", []):
        vp = v.get("params") if isinstance(v, dict) else None
        if not isinstance(vp, dict) or "footprint" not in v: continue
        ok = any(k != "seed" for k in vp) and all(k == "seed" or str(params.get(k)) == str(vp[k]) for k in vp)
        if ok: return v["footprint"]
    return m.get("footprint")


# region_map.gd와 같은 지붕 가르기
ROOF_TILE = ["village/giwa", "village/jeongja"]
ROOF_THATCH = ["village/choga", "village/house_compound", "village/jumak", "village/market_shop", "village/mulbang_a",
               "village/didil_bang_a", "village/oeyanggan", "village/heotgan", "village/dwitgan", "village/seonghwangdang", "village/daemun"]
FIELD = ["nature/garden_plot", "village/teotbat"]
CULTURE_SKIP = ["culture/tamna/doldam", "culture/tamna/jeongnang", "culture/gwanseo/city_wall"]
CULTURE_TILE = ["culture/gwandong/banga", "culture/yeongnam/jongga", "culture/yeongnam/sadang", "culture/giho/hanok_city", "culture/gwanseo/pyeongyang_giwa"]
CULTURE_TILE_DEFAULT = ["culture/chae", "culture/yeongnam/tteuljip", "culture/giho/giyeok"]
WALL_KITS = ["landmark/seong_wall", "landmark/gwana_wall", "landmark/jj_eupseong_wall", "landmark/seong_chi", "landmark/seong_corner"]


def item_kind(kit, params):
    if kit == "landmark/gwanghallu_pond": return "water"
    if kit in ROOF_TILE: return "tile"
    if kit.startswith("landmark/"):
        if "gate" in kit or "seongmun" in kit or kit.endswith("_mun") or "samun" in kit: return "gate"
        if kit.endswith("_wall") or kit in WALL_KITS or kit.endswith("_eupseong"): return ""
        return "hall"
    if kit in ROOF_THATCH:
        return "tile" if (kit == "village/house_compound" and str(params.get("size", "")) == "large") else "thatch"
    if kit in FIELD: return "field"
    if kit == "village/jwapan": return "stall"
    if kit in ("nature/big_tree", "nature/pine"): return "tree"
    if kit.startswith("culture/"):
        if kit in CULTURE_SKIP or kit.split("/")[-1].startswith("_"): return ""
        roof = str(params.get("roof", ""))
        if roof: return "tile" if roof.startswith("giwa") else "thatch"
        if kit in CULTURE_TILE or kit in CULTURE_TILE_DEFAULT: return "tile"
        if kit.endswith("/compound") and str(params.get("size", "")) == "large" and not kit.startswith("culture/tamna"): return "tile"
        return "thatch"
    return ""


def wall_segments(reg, items):
    segs = []
    for wl in reg.get("walls", []) or []:
        p = wl.get("points", [])
        for a, b in zip(p[:-1], p[1:]): segs.append(((a[0], a[1]), (b[0], b[1])))
        if wl.get("closed") and len(p) > 2: segs.append(((p[-1][0], p[-1][1]), (p[0][0], p[0][1])))
    def rect(c, ry, hx, hz):
        cs = [(-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz)]
        cr, sr = math.cos(ry), math.sin(ry)
        P = [(c[0] + x * cr - z * sr, c[1] + x * sr + z * cr) for x, z in cs]
        for i in range(4): segs.append((P[i], P[(i + 1) % 4]))
    have = set()
    for it in items:
        kit = it.get("kit", ""); params = it.get("params") if isinstance(it.get("params"), dict) else {}
        c = (float(it.get("x", 0)), float(it.get("z", 0))); ry = math.radians(0) + float(it.get("ry", 0.0))
        if kit == "landmark/namwon_eupseong":
            h = float(params.get("side", 186.0)) / 2; rect(c, ry, h, h); have.add(kit); continue
        if kit.endswith("_eupseong"):
            hv = None
            if "side" in params: hv = (float(params["side"]) / 2,) * 2
            elif isinstance(params.get("size"), list) and len(params["size"]) >= 2: hv = (float(params["size"][0]) / 2, float(params["size"][1]) / 2)
            elif isinstance(it.get("footprint"), list) and len(it["footprint"]) >= 2: hv = (float(it["footprint"][0]) / 2, float(it["footprint"][1]) / 2)
            if hv: rect(c, ry, *hv); have.add(kit)
            continue
        if kit == "village/wall_run":
            pts = params.get("points")
            if isinstance(pts, list):
                cr, sr = math.cos(ry), math.sin(ry)
                P = [(c[0] + p[0] * cr - p[1] * sr, c[1] + p[0] * sr + p[1] * cr) for p in pts]
                for a, b in zip(P[:-1], P[1:]): segs.append((a, b))
    for l in reg.get("landmarks", []):
        kit = l.get("kit", "")
        if not kit.endswith("_eupseong") or kit in have or kit == "landmark/namwon_eupseong": continue
        sz = l.get("size_m")
        if isinstance(sz, list) and len(sz) >= 2: rect((l["x"], l["z"]), math.radians(float(l.get("ry", 0))), sz[0] / 2, sz[1] / 2)
    return segs


# ---------------------------------------------------------------- 권역(L2)
def render_region(rid):
    reg, y, lu = load_region(rid)
    hm = reg["height"]
    x0, z0 = hm["x0"], hm["z0"]
    gw, gh = (hm["w"] - 1) * hm["cell"], (hm["h"] - 1) * hm["cell"]
    K = float(reg.get("projection", {}).get("K", 0.3))
    scale = 3.0 if max(gw, gh) < 9000 else 3.5           # 그림 1px = 게임 scale m
    W, H = int(gw / scale) + 1, int(gh / scale) + 1
    rng = rng_for(rid, "l2")
    img = hanji(W * SS, H * SS, rng).convert("RGBA")
    def px(x, z): return ((x - x0) / scale * SS, (z - z0) / scale * SS)

    # 논·밭 옅은 빛(들판)
    if lu is not None:
        lc = reg["landuse"]["cell"]
        fld = Image.fromarray(((lu == 2) * 255).astype(np.uint8)).resize((W * SS, H * SS), Image.BILINEAR).filter(ImageFilter.GaussianBlur(3 * SS))
        lay = Image.new("RGBA", img.size, (214, 206, 150, 0)); lay.putalpha(fld.point(lambda v: int(v * 0.35)))
        img = Image.alpha_composite(img, lay)

    # 바다 / 큰 강 면
    sm = sea_mask_game(reg, y, lu)
    sea_river = bool(reg.get("sea", {}).get("kind") == "river") if reg.get("sea") else False
    if sm is not None and sm.any():
        mk = Image.fromarray((sm * 255).astype(np.uint8)).resize((W * SS, H * SS), Image.BILINEAR)
        img = paint_water_mask(img, mk, WATER if sea_river else SEA, WATER_INK, SS, rng, river=sea_river)
    for l in reg.get("lakes", []) or []:
        P = [px(p[0], p[1]) for p in l.get("outline", [])]
        if len(P) > 2:
            d = ImageDraw.Draw(img); d.polygon(P, fill=(*WATER, 255), outline=(*WATER_INK, 255), width=int(1.5 * SS))

    # 산줄기
    cell = 16.0
    st = int(round(cell / hm["cell"]))
    z = y[::st, ::st].astype(np.float32)
    alt = z / K                                          # 실제 높이 비율로(압축 풀기)
    valid = None
    if sm is not None:
        sv = np.array(Image.fromarray(sm.astype(np.uint8) * 255).resize((z.shape[1], z.shape[0]), Image.NEAREST)) > 0
        valid = ~ndi.binary_dilation(sv, iterations=2)
    valid = np.ones_like(alt, bool) if valid is None else valid
    ppc = cell / scale * SS                               # 격자 1칸 = 그림 px
    def to_px(i, j): return (i * ppc, j * ppc)
    # 1) 등성이(뒤집은 흐름) — 가지 친 산줄기
    lines, relief, acc = ridge_lines(alt, cell / K, min_acc=36, min_relief=60, relief_r=900, valid=valid)
    def size_of(s): return 0 if s < 60 else min(30.0, 9.0 + (s - 60) * 0.05) * SS
    # 2) 유역 경계(산자분수령) 큰 줄기 — 등성이가 끊긴 자리를 잇는다
    zz = ndi.gaussian_filter(alt, 1.0)
    recv, order = priority_flood(zz, valid)
    ca = ((cell / K) / 1000.0) ** 2
    dv = divide_points(zz, valid, recv, order, 0.25 / ca, relief, 90, [12 / ca, 3 / ca])
    extra = []
    for (i, j, lv, r) in dv:
        extra.append((i * ppc, j * ppc, min(30.0, (16 if lv == 0 else 11) + r * 0.02) * SS, None))
    for o in reg.get("oreums", []) or []:   # 제주 오름: 둥근 봉우리(토산) 하나씩
        if "x" in o:
            ox, oz = px(o["x"], o["z"])
            extra.append((ox, oz, max(12.0, min(30.0, float(o.get("radius_m", 60.0)) / scale * 0.9)) * SS * 1.25, "earth"))
    img = paint_mountains(img, lines, relief, to_px, size_of, rng, SS, extra_peaks=extra, spine=True)

    # 물길: 큰 강(S/A/B·너비 12m↑) 겹줄, 내 외줄
    d = ImageDraw.Draw(img)
    for r in sorted(reg.get("rivers", []), key=lambda r: "SABCD".find(r.get("grade", "D")), reverse=True):
        P = [px(p[0], p[1]) for p in r.get("points", [])]
        g = r.get("grade", "D"); wm = float(r.get("width_m", 4.0))
        double = g in ("S", "A", "B") or wm >= 12
        river_line(d, P, max(5.5 * SS, wm / scale * SS) if double else {"C": 2.4, "D": 1.7}.get(g, 1.7) * SS, double, SS)
    # 길: 붉은 선 + 10리 눈금
    li_m = LI_KM * 1000 * K
    for r in reg.get("roads", []):
        P = [px(p[0], p[1]) for p in r.get("points", [])]
        cls = r.get("class", "")
        ferry = "ferry" in str(r.get("id", ""))
        w = {"대로": 4.2, "지선": 3.0}.get(cls, 1.8) * SS
        col = (*ROAD_RED, 255) if cls in ("대로", "지선") else (150, 84, 58, 230)
        road_line(d, P, w, col, (li_m / scale * SS) if cls in ("대로", "지선") else 0, SS, dashed=ferry)
    res = []   # 테두리·제목 곽·방위·인장은 런타임이 화면 크기로 그린다
    out = img.convert("RGB").resize((W, H), Image.LANCZOS)
    os.makedirs(os.path.join(RD, rid, "map"), exist_ok=True)
    fp = os.path.join(RD, rid, "map", "l2.webp")
    out.save(fp, "WEBP", quality=82, method=6)
    meta = {"file": "map/l2.webp", "x0": x0, "z0": z0, "scale": scale, "w": W, "h": H, "li_m": round(li_m, 1),
            "reserved": [[x0 + a / SS * scale, z0 + b / SS * scale, x0 + c / SS * scale, z0 + e / SS * scale] for a, b, c, e in res]}
    print(rid, "l2", W, H, os.path.getsize(fp) // 1024, "KB", "ridges", len(lines))
    return reg, y, lu, sm, meta


def short(n):
    for sep in ["·", " ", "(", "—"]:
        i = n.find(sep)
        if i > 0: n = n[:i]
    return n


# ---------------------------------------------------------------- 고을(L3)
def town_clusters(reg):
    rects = []
    for s in reg.get("settlements", []):
        bb = s.get("bbox")
        if isinstance(bb, list) and len(bb) == 4: r = [bb[0], bb[1], bb[2], bb[3]]
        else:
            rad = float(s.get("radius_m", 40.0)); r = [s["x"] - rad, s["z"] - rad, s["x"] + rad, s["z"] + rad]
        rects.append([r, [s["id"]]])
    g = 60.0
    changed = True
    while changed:
        changed = False
        for i in range(len(rects)):
            for j in range(i + 1, len(rects)):
                a, b = rects[i][0], rects[j][0]
                if a[0] - g < b[2] and b[0] - g < a[2] and a[1] - g < b[3] and b[1] - g < a[3]:
                    rects[i] = [[min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])], rects[i][1] + rects[j][1]]
                    rects.pop(j); changed = True; break
            if changed: break
    return rects


def draw_roof(d, x, y, w, kind, rng, ss):
    """기와(회청 기와골·처마 곡선) · 초가(둥근 볏짚) · 큰 집(hall) 지붕 그림 — 정면도(서 있는 그림)."""
    h = w * (0.42 if kind != "thatch" else 0.5)
    wall_h = w * 0.22
    # 벽(흰 회벽·기둥)
    d.rectangle([x - w * 0.38, y - wall_h, x + w * 0.38, y], fill=(232, 222, 196, 255), outline=(*INK, 255), width=max(1, int(0.8 * ss)))
    if w > 10 * ss:
        for k in range(1, 4):
            xx = x - w * 0.38 + k * w * 0.19
            d.line([(xx, y - wall_h), (xx, y)], fill=(110, 70, 44, 255), width=max(1, int(0.8 * ss)))
    if kind == "thatch":
        col = tuple(int(c + rng.integers(-10, 10)) for c in (198, 168, 106))
        d.chord([x - w * 0.52, y - wall_h - h * 1.6, x + w * 0.52, y - wall_h + h * 0.4], 180, 360, fill=col, outline=(*INK, 255), width=max(1, int(0.9 * ss)))
        d.line([(x - w * 0.2, y - wall_h - h * 0.5), (x + w * 0.2, y - wall_h - h * 0.55)], fill=(150, 116, 60, 255), width=max(1, int(0.8 * ss)))
    else:
        col = (94, 104, 114) if kind == "tile" else (84, 92, 104)
        top = y - wall_h - h
        eave = w * (0.58 if kind == "hall" else 0.52)
        pts = [(x - eave, y - wall_h - h * 0.05), (x - eave * 0.9, y - wall_h - h * 0.22), (x - w * 0.3, top + h * 0.18), (x - w * 0.24, top),
               (x + w * 0.24, top), (x + w * 0.3, top + h * 0.18), (x + eave * 0.9, y - wall_h - h * 0.22), (x + eave, y - wall_h - h * 0.05)]
        d.polygon(pts, fill=col, outline=(*INK, 255))
        d.line(pts, fill=(*INK, 255), width=max(1, int(1.0 * ss)))
        d.line([(x - w * 0.26, top), (x + w * 0.26, top)], fill=(30, 30, 34, 255), width=max(1, int(1.8 * ss)))   # 용마루
        for k in range(1, 6):   # 기와골
            xx = x - w * 0.36 + k * w * 0.12
            d.line([(xx, top + h * 0.15), (xx + (xx - x) * 0.25, y - wall_h - h * 0.12)], fill=(60, 68, 78, 255), width=max(1, ss))
        if kind == "hall":   # 단청 띠
            d.line([(x - w * 0.38, y - wall_h + 1.5 * ss), (x + w * 0.38, y - wall_h + 1.5 * ss)], fill=(160, 60, 44, 255), width=max(1, int(1.4 * ss)))


def draw_gate(d, x, y, w, ss):
    """성문: 홍예(아치) 석축 + 두 겹 문루 지붕."""
    d.rectangle([x - w * 0.5, y - w * 0.35, x + w * 0.5, y], fill=(170, 164, 150, 255), outline=(*INK, 255), width=max(1, ss))
    d.chord([x - w * 0.16, y - w * 0.3, x + w * 0.16, y + w * 0.05], 180, 360, fill=(60, 50, 40, 255))
    d.rectangle([x - w * 0.16, y - w * 0.13, x + w * 0.16, y], fill=(60, 50, 40, 255))
    draw_roof(d, x, y - w * 0.35, w * 0.9, "hall", np.random.default_rng(1), ss)


def draw_tree(d, x, y, s, rng, ss):
    d.line([(x, y), (x, y - s * 0.5)], fill=(90, 60, 40, 255), width=max(1, int(s * 0.12)))
    for k in range(3):
        r = s * (0.38 - k * 0.08); yy = y - s * (0.45 + k * 0.22)
        d.ellipse([x - r, yy - r * 0.6, x + r, yy + r * 0.6], fill=(84, 118, 82, 255), outline=(*INK, 200))


def wall_band(d, a, b, w, ss, out_dir=None):
    """성벽: 회색 석축 띠 + 바깥 여장(凸 가지런한 이빨)."""
    d.line([a, b], fill=(*INK, 255), width=int(w + 2 * ss))
    d.line([a, b], fill=(176, 170, 156, 255), width=int(w))
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    if L < 1: return
    ux, uy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    nx, ny = -uy, ux
    if out_dir is not None and nx * out_dir[0] + ny * out_dir[1] < 0: nx, ny = -nx, -ny
    step = w * 1.5; t = step * 0.5
    while t < L:
        cx, cy = a[0] + ux * t, a[1] + uy * t
        ox, oy = cx + nx * (w * 0.5), cy + ny * (w * 0.5)
        q = w * 0.38
        d.polygon([(ox - ux * q, oy - uy * q), (ox + ux * q, oy + uy * q), (ox + ux * q + nx * q * 1.4, oy + uy * q + ny * q * 1.4),
                   (ox - ux * q + nx * q * 1.4, oy - uy * q + ny * q * 1.4)], fill=(150, 144, 130, 255), outline=(*INK, 255))
        t += step


def render_city(rid, reg, y, lu, sm, rect, ids, idx, items, walls):
    hm = reg["height"]
    K = float(reg.get("projection", {}).get("K", 0.3))
    pad = 150.0
    gx0, gz0, gx1, gz1 = rect[0] - pad, rect[1] - pad, rect[2] + pad, rect[3] + pad
    gx0 = max(gx0, hm["x0"]); gz0 = max(gz0, hm["z0"])
    gx1 = min(gx1, hm["x0"] + (hm["w"] - 1) * hm["cell"]); gz1 = min(gz1, hm["z0"] + (hm["h"] - 1) * hm["cell"])
    span = max(gx1 - gx0, gz1 - gz0)
    s = max(0.5, span / 2400.0)                        # 1px = s m
    W, H = int((gx1 - gx0) / s) + 1, int((gz1 - gz0) / s) + 1
    rng = rng_for(rid, "city", idx)
    img = hanji(W * SS, H * SS, rng, edge=True).convert("RGBA")
    def px(x, z): return ((x - gx0) / s * SS, (z - gz0) / s * SS)
    # 지형 자르기
    c = hm["cell"]
    i0 = int((gx0 - hm["x0"]) / c); i1 = int((gx1 - hm["x0"]) / c) + 1
    j0 = int((gz0 - hm["z0"]) / c); j1 = int((gz1 - hm["z0"]) / c) + 1
    zc = (y[j0:j1, i0:i1] / K).astype(np.float32)
    # 논밭 무늬
    if lu is not None:
        lc = reg["landuse"]["cell"]
        li0, li1 = int((gx0 - hm["x0"]) / lc), int((gx1 - hm["x0"]) / lc) + 1
        lj0, lj1 = int((gz0 - hm["z0"]) / lc), int((gz1 - hm["z0"]) / lc) + 1
        lus = lu[lj0:lj1, li0:li1]
        for cls, col, pat in [(2, (206, 204, 146), "rows"), (3, (222, 204, 160), "dots")]:
            m = Image.fromarray(((lus == cls) * 255).astype(np.uint8)).resize((W * SS, H * SS), Image.BILINEAR).filter(ImageFilter.GaussianBlur(6 * SS)).point(lambda v: 255 if v > 110 else int(v * 1.6))
            lay = Image.new("RGBA", img.size, (*col, 0)); lay.putalpha(m.point(lambda v: int(v * 0.45)))
            pl = Image.new("RGBA", img.size, (0, 0, 0, 0)); pd = ImageDraw.Draw(pl)
            sp = 9 * SS
            if pat == "rows":
                for yy in np.arange(0, H * SS, sp): pd.line([(0, yy), (W * SS, yy + sp * 0.3)], fill=(120, 140, 80, 140), width=max(1, SS))
            else:
                for yy in np.arange(0, H * SS, sp):
                    for xx in np.arange((yy / sp % 2) * sp / 2, W * SS, sp): pd.point([(xx, yy)], fill=(130, 100, 60, 170))
            pa = np.asarray(pl.getchannel("A"), np.float32) * (np.asarray(m, np.float32) / 255.0)
            pl.putalpha(Image.fromarray(pa.astype(np.uint8)))
            img = Image.alpha_composite(Image.alpha_composite(img, lay), pl)
    # 물(바다·큰 강)
    if sm is not None:
        lc = reg["landuse"]["cell"]
        li0, li1 = int((gx0 - hm["x0"]) / lc), int((gx1 - hm["x0"]) / lc) + 1
        lj0, lj1 = int((gz0 - hm["z0"]) / lc), int((gz1 - hm["z0"]) / lc) + 1
        smc = sm[lj0:lj1, li0:li1]
        if smc.any():
            river = bool(reg.get("sea", {}).get("kind") == "river")
            mk = Image.fromarray((smc * 255).astype(np.uint8)).resize((W * SS, H * SS), Image.BILINEAR)
            img = paint_water_mask(img, mk, WATER if river else SEA, WATER_INK, SS, rng, river=river)
    # 둘레 산(둥근 산 그림, 고을 바깥 높은 땅)
    rel = zc - ndi.minimum_filter(ndi.gaussian_filter(zc, 2), size=max(3, int(500 / c)) | 1)
    core = (rect[0] - 20, rect[1] - 20, rect[2] + 20, rect[3] + 20)
    stepm = 28.0 * max(1.0, s / 0.7)
    glyphs = []
    for gz in np.arange(gz0 + stepm / 2, gz1, stepm):
        for gx in np.arange(gx0 + stepm / 2, gx1, stepm):
            jj = int((gz - gz0) / c); ii = int((gx - gx0) / c)
            if jj >= rel.shape[0] or ii >= rel.shape[1]: continue
            r = rel[jj, ii]
            if r < 45: continue
            if core[0] < gx < core[2] and core[1] < gz < core[3] and r < 120: continue
            if rng.random() < 0.15: continue
            hg = min(64.0, 12 + r * 0.09) * SS * max(0.7, 0.7 / s) * rng.uniform(0.75, 1.3)
            xx, yy = px(gx + rng.uniform(-0.55, 0.55) * stepm, gz + rng.uniform(-0.55, 0.55) * stepm)
            glyphs.append((xx, yy, hg))
    wash = Image.new("RGBA", img.size, (0, 0, 0, 0)); wd = ImageDraw.Draw(wash)
    for (xx, yy, hg) in glyphs: wd.ellipse([xx - hg, yy - hg * 0.9, xx + hg, yy + hg * 0.3], fill=(*WASH_GREEN, 160))
    img = overlay(img, wash.filter(ImageFilter.GaussianBlur(6 * SS)), 0.7)
    d = ImageDraw.Draw(img)
    glyphs.sort(key=lambda g: g[1])
    for (xx, yy, hg) in glyphs:
        draw_peak(d, xx, yy, hg, hg * rng.uniform(1.5, 1.9), rng, SS, kind="earth" if rng.random() < 0.65 else "rock")
    # 내
    for r in reg.get("rivers", []):
        P = [px(p[0], p[1]) for p in r.get("points", [])]
        if not P: continue
        g = r.get("grade", "D"); wm = float(r.get("width_m", 4.0))
        river_line(d, P, max(2.0 * SS, wm / s * SS), wm / s > 3.5, SS)
    # 길(붉은 대로·황토 길)
    for r in reg.get("roads", []):
        P = [px(p[0], p[1]) for p in r.get("points", [])]
        cls = r.get("class", ""); wm = float(r.get("width_m", 3.0))
        ferry = "ferry" in str(r.get("id", ""))
        col = (*ROAD_RED, 220) if cls == "대로" else (*ROAD_OCHRE, 235)
        road_line(d, P, max(2.0 * SS, wm / s * SS * 0.9), col, 0, SS, dashed=ferry)
    # 건물 그림(뒤→앞)
    bl = []
    for it in items:
        x, z = float(it.get("x", 0)), float(it.get("z", 0))
        if not (gx0 - 10 < x < gx1 + 10 and gz0 - 10 < z < gz1 + 10): continue
        kit = it.get("kit", ""); params = it.get("params") if isinstance(it.get("params"), dict) else {}
        k = item_kind(kit, params)
        if not k: continue
        fp = it.get("footprint") if isinstance(it.get("footprint"), list) else catalog_fp(kit, params)
        fw = max(float(fp[0]), float(fp[1])) if isinstance(fp, list) and len(fp) >= 2 else 8.0
        bl.append((z, x, k, fw, it.get("ry", 0.0), fp))
    # 성벽
    cen = ((rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2)
    ww = max(3.0 * SS, 4.5 / s * SS)
    for a, b in walls:
        if not ((gx0 - 50 < a[0] < gx1 + 50 and gz0 - 50 < a[1] < gz1 + 50) or (gx0 - 50 < b[0] < gx1 + 50 and gz0 - 50 < b[1] < gz1 + 50)): continue
        mid = ((a[0] + b[0]) / 2 - cen[0], (a[1] + b[1]) / 2 - cen[1])
        wall_band(d, px(*a), px(*b), ww, SS, out_dir=mid)
    bl.sort()
    for (z, x, k, fw, ry, fp) in bl:
        X, Y = px(x, z)
        if k == "field":
            if isinstance(fp, list) and len(fp) >= 2:
                hw, hh = float(fp[0]) / 2 / s * SS, float(fp[1]) / 2 / s * SS
                d.rectangle([X - hw, Y - hh, X + hw, Y + hh], fill=(170, 182, 112, 200))
                for t in np.linspace(-hh, hh, 5)[1:-1]: d.line([(X - hw, Y + t), (X + hw, Y + t)], fill=(110, 130, 70, 200), width=max(1, SS))
            continue
        if k == "water":
            hw = fw / 2 / s * SS; d.ellipse([X - hw, Y - hw * 0.6, X + hw, Y + hw * 0.6], fill=(*WATER, 255), outline=(*WATER_INK, 255), width=SS); continue
        if k == "stall":
            q = max(2.5 * SS, fw / 2 / s * SS * 0.8); d.rectangle([X - q, Y - q * 0.6, X + q, Y], fill=(226, 206, 160, 255), outline=(*INK, 200)); continue
        if k == "tree":
            draw_tree(d, X, Y, max(8 * SS, fw / s * SS), rng, SS); continue
        if k == "gate":
            draw_gate(d, X, Y, max(16 * SS, fw / s * SS * 0.9), SS); continue
        w = fw / s * SS * (0.85 if k != "hall" else 0.7)
        w = max(7 * SS, min(w, 70 * SS))
        draw_roof(d, X, Y, w, k, rng, SS)
    # 가장자리를 투명하게 풀어 권역 그림 위에 이어 붙는다(런타임이 L2 위에 겹쳐 그림)
    out = img.convert("RGB").resize((W, H), Image.LANCZOS).convert("RGBA")
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dd = np.minimum(np.minimum(xx, W - 1 - xx), np.minimum(yy, H - 1 - yy))
    fe = max(12.0, min(W, H) * 0.1)
    al = np.clip(dd / fe, 0, 1) ** 1.5
    al *= 1.0 + 0.4 * np.asarray(Image.fromarray((rng.random((H // 16 + 1, W // 16 + 1)) * 255).astype(np.uint8)).resize((W, H), Image.BILINEAR), np.float32) / 255.0
    out.putalpha(Image.fromarray((np.clip(al, 0, 1) * 255).astype(np.uint8)))
    fn = "map/city_%02d.webp" % idx
    out.save(os.path.join(RD, rid, fn), "WEBP", quality=80, method=6, alpha_quality=60)
    print("  city", idx, ids[:3], W, H, os.path.getsize(os.path.join(RD, rid, fn)) // 1024, "KB")
    return {"file": fn, "x0": gx0, "z0": gz0, "scale": s, "w": W, "h": H, "ids": ids,
            "core": [round(v, 1) for v in rect]}


def render_all_region(rid):
    reg, y, lu, sm, meta = render_region(rid)
    items = placement_items(rid)
    for l in reg.get("landmarks", []):   # 배치에 없는 랜드마크(성문 등)
        if "x" not in l: continue
        if any(it.get("kit") == l.get("kit") and abs(float(it.get("x", 0)) - l["x"]) < 12 and abs(float(it.get("z", 0)) - l["z"]) < 12 for it in items): continue
        items.append({"kit": l.get("kit", ""), "x": l["x"], "z": l["z"], "ry": math.radians(float(l.get("ry", 0))), "params": {}})
    walls = wall_segments(reg, items)
    cities = []
    for k, (rect, ids) in enumerate(town_clusters(reg)):
        cities.append(render_city(rid, reg, y, lu, sm, rect, ids, k, items, walls))
    meta["cities"] = cities
    for f in glob.glob(os.path.join(RD, rid, "map", "city_*.webp")):
        if os.path.basename(f) not in {os.path.basename(c["file"]) for c in cities}: os.remove(f)
    json.dump(meta, open(os.path.join(RD, rid, "map.json"), "w"), ensure_ascii=False)


# ---------------------------------------------------------------- 전국(L0)
NATION_BOX = (124.0, 33.0, 131.0, 43.0)   # travel.gd OUTLINE_BOX
COS38 = math.cos(math.radians(38.0))
# 백두대간(대략): 백두산 → 두류산 → 철령 → 금강산 → 설악 → 오대 → 태백 → 소백 → 속리 → 덕유 → 지리
BAEKDU = [(128.08, 42.0), (128.25, 41.55), (128.1, 41.05), (127.7, 40.65), (127.3, 40.3), (127.25, 39.9), (127.3, 39.45),
          (127.5, 38.95), (127.85, 38.75), (128.08, 38.62), (128.35, 38.25), (128.47, 38.12), (128.6, 37.8), (128.75, 37.45),
          (128.92, 37.1), (128.47, 36.95), (128.1, 36.8), (127.87, 36.54), (127.95, 36.2), (127.75, 35.86), (127.6, 35.55), (127.73, 35.34)]


def peninsula():
    import re
    src = open(os.path.join(ROOT, "scripts", "region", "travel.gd"), encoding="utf-8").read()
    a = src.index("const PENINSULA := [")
    b = src.index("\n]", a)
    return [(float(x), float(y)) for x, y in re.findall(r"\[\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\]", src[a:b])]


def terrarium(z, x, y):
    cd = os.path.join(HERE, "cache", "terrarium_z%d" % z); os.makedirs(cd, exist_ok=True)
    f = os.path.join(cd, "%d_%d.png" % (x, y))
    if not os.path.exists(f):
        import urllib.request
        urllib.request.urlretrieve("https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png" % (z, x, y), f)
    a = np.asarray(Image.open(f).convert("RGB"), np.float32)
    return a[..., 0] * 256 + a[..., 1] + a[..., 2] / 256 - 32768


def nation_dem(ppd):
    """경위도 등간격 격자(ppd px/도 위도) 높이 — terrarium z7(메르카토르)에서 다시 뜬다."""
    lon0, lat0, lon1, lat1 = NATION_BOX
    W = int((lon1 - lon0) * COS38 * ppd); H = int((lat1 - lat0) * ppd)
    zt = 7; n = 2 ** zt
    def tx(lon): return (lon + 180) / 360 * n
    def ty(lat): return (1 - math.log(math.tan(math.radians(lat)) + 1 / math.cos(math.radians(lat))) / math.pi) / 2 * n
    xs0, xs1 = int(tx(lon0)), int(tx(lon1)); ys0, ys1 = int(ty(lat1)), int(ty(lat0))
    mos = np.zeros(((ys1 - ys0 + 1) * 256, (xs1 - xs0 + 1) * 256), np.float32)
    for X in range(xs0, xs1 + 1):
        for Y in range(ys0, ys1 + 1):
            mos[(Y - ys0) * 256:(Y - ys0 + 1) * 256, (X - xs0) * 256:(X - xs0 + 1) * 256] = terrarium(zt, X, Y)
    lons = lon0 + (np.arange(W) + 0.5) / W * (lon1 - lon0)
    lats = lat1 - (np.arange(H) + 0.5) / H * (lat1 - lat0)
    fx = (np.array([tx(v) for v in lons]) - xs0) * 256
    fy = (np.array([ty(v) for v in lats]) - ys0) * 256
    FX, FY = np.meshgrid(fx, fy)
    return ndi.map_coordinates(mos, [FY - 0.5, FX - 0.5], order=1), W, H


# 전국 그림을 옆으로 넓혀 굽는 경도 범위 — 지도 테(가로 ≈ 세로)에 맞춰 OUTLINE_BOX(124~131) 양옆이 빈 바다 띠로 남지 않게.
# DEM(terrarium 캐시)은 124~131만 쓰고, 그 밖은 바다 + 이웃 땅(요동·연해주·일본 서쪽) 대강의 윤곽(옅은 이웃 땅 — 고증은 참고용)
NATION_BAKE_LON = (120.6, 134.4)


def _pad_foreign(lon, lat):
    """OUTLINE_BOX 밖 경도의 대강 뭍(이웃 나라). lon·lat: 2D 배열"""
    w = lon < 124.0; e = lon > 131.0
    liao = w & (lon >= 121.1) & (lat > 40.05 - np.maximum(0, 124.0 - lon) * 0.42)      # 요동 반도(끝 ≈ 121.2, 38.8)
    manchu = w & (lat > 40.9)
    bohai_w = w & (lon < 121.6) & (lat > 40.7)                                          # 요동만 서쪽 기슭
    maritime = e & (lat > 42.75 - (lon - 131.0) * 0.32)                                # 연해주
    honshu = e & (lat < 35.45 + (lon - 131.0) * 0.12) & (lat > 33.95 - (lon - 131.0) * 0.05)
    kyushu = e & (lon < 132.0) & (lat < 33.95) & (lat > 31.0)
    shikoku = e & (lon > 132.4) & (lat < 34.25) & (lat > 32.9)
    # 일본 쪽(honshu·kyushu·shikoku)은 자로 끊긴 이음매가 생겨 빼고, DEM 가장자리 이어 붙이기에 맡긴다
    return liao | manchu | bohai_w | maritime


def render_nation():
    ppd = 170
    dem, W, H = nation_dem(ppd)
    lon0, lat0, lon1, lat1 = NATION_BOX
    # 옆으로 넓히기: 붙인 열은 바다(-50), 이웃 땅 윤곽은 낮은 뭍(얕은 결)
    padL = int(round((lon0 - NATION_BAKE_LON[0]) * COS38 * ppd)); padR = int(round((NATION_BAKE_LON[1] - lon1) * COS38 * ppd))
    nl0 = lon0 - padL / (COS38 * ppd); nl1 = lon1 + padR / (COS38 * ppd)
    big = np.full((H, W + padL + padR), -50.0, np.float32)
    big[:, padL:padL + W] = dem
    W2 = W + padL + padR
    LON = nl0 + (np.arange(W2) + 0.5) / W2 * (nl1 - nl0)
    LAT = lat1 - (np.arange(H) + 0.5) / H * (lat1 - lat0)
    LO, LA = np.meshgrid(LON, LAT)
    pad = (LO < lon0) | (LO > lon1)
    # 윤곽이 자로 그은 듯하지 않게: 큰 굽이 + 잔 굽이(해안선처럼) — 경위도를 흔든 뒤 윤곽 식에 넣는다
    g = np.random.default_rng(7)
    def noise(sig, amp):
        n = ndi.gaussian_filter(g.normal(0, 1, LO.shape).astype(np.float32), sig); return n / (n.std() + 1e-6) * amp
    wx = noise(60, 0.35) + noise(14, 0.08); wy = noise(60, 0.3) + noise(14, 0.07)
    fl = _pad_foreign(LO + wx, LA + wy)
    # DEM 가장자리 열(경도 124·131)의 뭍/바다를 옆으로 이어 붙인다 — 이음매에서 땅이 자로 끊기지 않게(멀어질수록 대강의 윤곽으로)
    eW = ndi.binary_opening(dem[:, :3].max(1) > 0.5, iterations=3)[:, None]; eE = ndi.binary_opening(dem[:, -3:].max(1) > 0.5, iterations=3)[:, None]
    reach = 1.1 + noise(40, 0.45)
    fl |= ((LO < lon0) & eW & ((lon0 - LO) < reach)) | ((LO > lon1) & eE & ((LO - lon1) < reach))
    fl = ndi.binary_opening(fl, iterations=2)
    big[pad & fl] = 60.0
    dem, W, lon0, lon1 = big, W2, nl0, nl1
    def gpx(lon, lat): return ((lon - lon0) / (lon1 - lon0) * W * SS, (lat1 - lat) / (lat1 - lat0) * H * SS)
    rng = rng_for("nation")
    land = dem > 0.5
    land = ndi.binary_opening(land, iterations=1)
    # 조선 땅: PENINSULA 윤곽을 넓힌 안쪽 뭍(북쪽 경계는 윤곽 그대로) + 섬
    pen = Image.new("L", (W, H), 0)
    ImageDraw.Draw(pen).polygon([((p[0] - lon0) / (lon1 - lon0) * W, (lat1 - p[1]) / (lat1 - lat0) * H) for p in peninsula()], fill=255)
    pen = np.asarray(pen) > 0
    near = ndi.binary_dilation(pen, iterations=int(0.25 * ppd))
    north = np.zeros_like(pen)
    # 윤곽 북쪽 경계(압록·두만) 너머는 남의 땅: 위도 39.8 북쪽에서 윤곽 밖이면 이웃 나라
    lat_of_row = lat1 - (np.arange(H) + 0.5) / H * (lat1 - lat0)
    north[lat_of_row > 39.6, :] = True
    lon_of_col = lon0 + (np.arange(W) + 0.5) / W * (lon1 - lon0)
    japan = (lon_of_col[None, :] > 129.1) & (lat_of_row[:, None] < 34.8)
    outside = ((lon_of_col < NATION_BOX[0]) | (lon_of_col > NATION_BOX[2]))[None, :]   # 옆으로 넓힌 열은 모두 이웃 땅
    joseon = land & (pen | ~north) & ~japan & ~outside   # 북위 39.6° 남쪽은 섬까지 모두(제주·울릉), 북쪽은 윤곽 안만
    foreign = land & ~joseon
    img = Image.new("RGBA", (W * SS, H * SS), (*SEA, 255))
    # 바다 물결
    seamask = Image.fromarray((~land * 255).astype(np.uint8)).resize(img.size, Image.BILINEAR)
    img = Image.alpha_composite(img, wave_layer(img.size, seamask, SS, rng, spacing=18))
    # 뭍(한지)
    paper = hanji(W * SS, H * SS, rng, edge=False).convert("RGBA")
    jm = Image.fromarray((joseon * 255).astype(np.uint8)).resize(img.size, Image.BILINEAR).filter(ImageFilter.GaussianBlur(1.0 * SS)).point(lambda v: 255 if v > 127 else 0)
    fm = Image.fromarray((foreign * 255).astype(np.uint8)).resize(img.size, Image.BILINEAR).filter(ImageFilter.GaussianBlur(1.0 * SS)).point(lambda v: 255 if v > 127 else 0)
    img.paste(paper, (0, 0), jm)
    fl = Image.new("RGBA", img.size, (222, 214, 196, 255)); img.paste(fl, (0, 0), fm)
    for m, col in [(jm, (*INK, 230)), (fm, (130, 120, 104, 160))]:
        edge = ImageChops_sub(m.filter(ImageFilter.MaxFilter(3)), m.filter(ImageFilter.MinFilter(3)))
        el = Image.new("RGBA", img.size, col); el.putalpha(edge.point(lambda v: col[3] if v > 60 else 0))
        img = Image.alpha_composite(img, el)
    # 큰 강(흐름 누적 — 뭍 안)
    cell_km = 111.0 / ppd
    zz = np.where(land, dem, -50).astype(np.float32)
    border = ndi.binary_dilation(joseon, iterations=int(0.12 * ppd))
    rivers = flow_rivers(zz, land & (joseon | (border & foreign)), min_cells=int(900 / cell_km ** 2))
    d = ImageDraw.Draw(img)
    for pts, a in rivers:
        area = a * cell_km ** 2
        P = chaikin([(i * SS + SS / 2, j * SS + SS / 2) for i, j in pts], 2)
        double = area > 6000
        river_line(d, P, (2.2 + min(4.0, area / 6000)) * SS if double else (1.0 + area / 4000) * SS, double, SS)
    # 산줄기(조선 땅만)
    valid = joseon
    lines, relief, acc = ridge_lines(dem.astype(np.float32), cell_km * 1000, min_acc=14, min_relief=260, relief_r=25000, valid=valid)
    def to_px(i, j): return (i * SS + SS / 2, j * SS + SS / 2)
    def size_of(s): return 0 if s < 260 else min(17.0, 7.0 + (s - 260) * 0.006) * SS
    spine = Image.new("RGBA", img.size, (0, 0, 0, 0)); sd = ImageDraw.Draw(spine)
    SP = chaikin([gpx(*p) for p in BAEKDU], 3)
    brush(sd, SP, 14 * SS, (*WASH_GREEN, 200))
    img = overlay(img, spine.filter(ImageFilter.GaussianBlur(5 * SS)), 0.8)
    extra = []
    for q in resample(SP, 10 * SS)[1:]:   # 백두대간 등뼈: 굵은 봉우리 띠
        extra.append((q[0] + rng.uniform(-2, 2) * SS, q[1] + 4 * SS, rng.uniform(14, 19) * SS, "rock"))
    img = paint_mountains(img, lines, relief, to_px, size_of, rng, SS, wash_alpha=0.45, extra_peaks=extra)
    d = ImageDraw.Draw(img)
    brush(d, SP, 2.4 * SS, (*INK, 150))
    # 백두산(천지) 표시
    bx, by = gpx(128.08, 42.0)
    d.ellipse([bx - 6 * SS, by - 4 * SS - 18 * SS, bx + 6 * SS, by + 4 * SS - 18 * SS], fill=(*WATER, 255), outline=(*WATER_INK, 255), width=SS)
    res = []   # 제목 곽·방위는 런타임(화면 크기 고정)
    out = img.convert("RGB").resize((W, H), Image.LANCZOS)
    out.save(os.path.join(RD, "nation_map.webp"), "WEBP", quality=82, method=6)
    meta = {"file": "nation_map.webp", "lon0": lon0, "lat0": lat0, "lon1": lon1, "lat1": lat1, "w": W, "h": H,
            "reserved": [[lon0 + a / SS / W * (lon1 - lon0), lat1 - b / SS / H * (lat1 - lat0), lon0 + c / SS / W * (lon1 - lon0), lat1 - e / SS / H * (lat1 - lat0)] for a, b, c, e in res]}
    json.dump(meta, open(os.path.join(RD, "nation_map.json"), "w"), ensure_ascii=False)
    print("nation", W, H, os.path.getsize(os.path.join(RD, "nation_map.webp")) // 1024, "KB ridges", len(lines), "rivers", len(rivers))


def flow_rivers(z, valid, min_cells):
    """D8 흐름(우선순위 범람으로 웅덩이 메움) → 누적 큰 칸을 이은 꺾은선."""
    H, W = z.shape
    filled = z.copy(); done = np.zeros((H, W), bool); pq = []
    for j in range(H):
        for i in range(W):
            if not valid[j, i] or i in (0, W - 1) or j in (0, H - 1) or not (valid[max(0, j - 1):j + 2, max(0, i - 1):i + 2].all()):
                if valid[j, i]: heapq.heappush(pq, (float(z[j, i]), j, i)); done[j, i] = True
    order = []
    recv = -np.ones((H, W), np.int64)
    NB = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
    while pq:
        h, j, i = heapq.heappop(pq)
        order.append(j * W + i)
        for dj, di in NB:
            jj, ii = j + dj, i + di
            if 0 <= jj < H and 0 <= ii < W and valid[jj, ii] and not done[jj, ii]:
                done[jj, ii] = True
                filled[jj, ii] = max(z[jj, ii], h + 1e-3)
                recv[jj, ii] = j * W + i
                heapq.heappush(pq, (float(filled[jj, ii]), jj, ii))
    acc = np.ones(H * W, np.float32); rf = recv.ravel()
    for c in reversed(order):
        r = rf[c]
        if r >= 0: acc[r] += acc[c]
    big = acc >= min_cells
    donors = np.zeros(H * W, np.int32)
    for c in np.flatnonzero(big):
        if rf[c] >= 0 and big[rf[c]]: donors[rf[c]] += 1
    seen = np.zeros(H * W, bool); out = []
    for h0 in [c for c in np.flatnonzero(big) if donors[c] == 0]:
        line = []; c = h0
        while c >= 0 and big[c]:
            line.append(c)
            if seen[c]: break
            seen[c] = True; c = rf[c]
        if c >= 0 and not big[c]: line.append(c)
        if len(line) > 3: out.append(([(k % W, k // W) for k in line], float(acc[line[-2]])))
    # 하류(누적이 큰) 구간이 먼저 그려지면 굵기가 덮인다 — 작은 것부터
    out.sort(key=lambda t: t[1])
    return out


if __name__ == "__main__":
    args = sys.argv[1:] or ["JL_NAMWON_UNBONG"]
    if args == ["all"]:
        args = sorted(os.path.basename(os.path.dirname(p)) for p in glob.glob(os.path.join(RD, "*", "region.json"))) + ["nation"]
    for a in args:
        if a == "nation": render_nation()
        else: render_all_region(a)
