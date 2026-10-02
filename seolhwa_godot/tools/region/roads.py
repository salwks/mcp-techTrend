"""도로: 경사·하천 비용 최소경로(A*, 4m 격자). 고증 경유점(고을·고개·도강점)을 순서대로 잇는다(계획서 §4 P6~P8).
경사 비용은 실제 경사 그대로(K는 경사 보존). 하천은 지정 도강점 밖에서 비싸다 → 길이 도강점으로 모인다."""
import heapq, math
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
import common as C

G = C.LU_CELL      # 4m

def geo(lat, lon):
    x, z = C.geo_to_game(lat, lon); return float(x), float(z)

def river_masks(rivers, shape):
    """등급별 물 마스크(4m)."""
    out = {}
    for g in "BCD":
        im = Image.new("L", (shape[1], shape[0]), 0); d = ImageDraw.Draw(im)
        for r in rivers:
            if r["grade"] != g: continue
            p = np.array(r["points"]); i, j = C.xz_to_ij(p[:, 0], p[:, 1], G)
            d.line(list(zip(i.tolist(), j.tolist())), fill=255, width=max(1, int(round(r["width_m"] / G)) + 1))
        out[g] = np.asarray(im) > 0
    return out

def cost_field(y4, wmask, crossings_xz):
    """반환 (base, y4): base = 칸 기본 비용(옆경사 약하게 + 하천 벌점 − 계곡 선호), 진행 방향 경사 비용은 A*에서 계산."""
    gz, gx = np.gradient(y4, G)
    slope = np.hypot(gx, gz)                         # tan(경사) — 실제와 같음(K는 경사 보존)
    c = 1.0 + 4.0 * np.clip(slope - 0.25, 0, None) ** 2 * 10 + 300.0 * (slope > 1.0)
    pen = np.zeros_like(c)
    pen[wmask["D"]] = 6.0; pen[wmask["C"]] = 45.0; pen[wmask["B"]] = 250.0
    free = np.zeros(c.shape, bool)
    for x, z in crossings_xz:
        i, j = C.xz_to_ij(x, z, G); i, j = int(round(float(i))), int(round(float(j)))
        free[max(j - 6, 0):j + 7, max(i - 6, 0):i + 7] = True
    pen[free] = 0.0
    # 계곡 바닥·산기슭 선호(계곡→산기슭→고개): B·C 하천에서 12~120m(게임)는 20% 싸다
    near = ndimage.binary_dilation(wmask["B"] | wmask["C"], iterations=int(120 / G)) & ~ndimage.binary_dilation(wmask["B"] | wmask["C"], iterations=int(12 / G))
    c = np.where(near, c * 0.8, c)
    return (c + pen, y4), slope

NB = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]

def astar(cost, a, b):
    """cost = (칸 비용, 높이). 걸음 비용 = 거리·칸비용 + 진행 방향 경사(종단 구배) 벌점."""
    base, hgt = cost
    Hh, Ww = base.shape
    (ai, aj), (bi, bj) = a, b
    g = np.full(base.shape, np.inf); g[aj, ai] = 0
    came = -np.ones(base.shape, np.int64)
    pq = [(0.0, aj, ai)]
    cmin = float(base.min()) * 0.999
    closed = np.zeros(base.shape, bool)
    while pq:
        f, j, i = heapq.heappop(pq)
        if closed[j, i]: continue
        closed[j, i] = True
        if (j, i) == (bj, bi): break
        gj = g[j, i]; hj = hgt[j, i]
        for dj, di in NB:
            nj, ni = j + dj, i + di
            if not (0 <= nj < Hh and 0 <= ni < Ww) or closed[nj, ni]: continue
            L = 1.4142 if dj and di else 1.0
            gr = abs(hgt[nj, ni] - hj) / (L * G)                       # 종단 구배
            gc = 60.0 * gr * gr + (300.0 * (gr - 0.12) ** 2 if gr > 0.12 else 0) + (400.0 if gr > 0.5 else 0)
            ng = gj + L * (0.5 * (base[j, i] + base[nj, ni]) + gc)
            if ng < g[nj, ni]:
                g[nj, ni] = ng; came[nj, ni] = j * Ww + i
                heapq.heappush(pq, (ng + math.hypot(nj - bj, ni - bi) * cmin, nj, ni))
    path = []; cur = bj * Ww + bi
    while cur >= 0:
        j, i = divmod(int(cur), Ww); path.append((i, j))
        if (i, j) == (ai, aj): break
        cur = came[j, i]
    return path[::-1]

def smooth(pts, it=3):
    pts = np.asarray(pts, float)
    for _ in range(it):
        q = 0.75 * pts[:-1] + 0.25 * pts[1:]; r = 0.25 * pts[:-1] + 0.75 * pts[1:]
        mid = np.empty((len(q) * 2, 2)); mid[0::2] = q; mid[1::2] = r
        pts = np.vstack([pts[:1], mid, pts[-1:]])
    return pts

def simplify(pts, tol=1.5):
    """Douglas–Peucker."""
    pts = np.asarray(pts)
    if len(pts) < 3: return pts
    a, b = pts[0], pts[-1]; ab = b - a; L = np.hypot(*ab) + 1e-9
    d = np.abs(np.cross(ab, pts - a)) / L
    k = int(np.argmax(d))
    if d[k] > tol:
        return np.vstack([simplify(pts[:k + 1], tol)[:-1], simplify(pts[k:], tol)])
    return np.vstack([a, b])

def remove_loops(pts, tol=6.0, min_len=16.0):
    """경유점(물 한가운데 도강점 등)에 들렀다 되돌아 나오는 짧은 고리·되짚기를 잘라낸다."""
    pts = np.asarray(pts, float); out = []
    k = 0; n = len(pts)
    seg = np.concatenate([[0], np.cumsum(np.hypot(*np.diff(pts, axis=0).T))])
    while k < n:
        out.append(pts[k])
        ahead = np.nonzero((seg > seg[k] + min_len) & (seg < seg[k] + 400))[0]
        if len(ahead):
            d = np.hypot(pts[ahead, 0] - pts[k, 0], pts[ahead, 1] - pts[k, 1])
            close = ahead[d < tol]
            if len(close):
                k = int(close.max()) + 1; continue
        k += 1
    return np.asarray(out)

def route(cost, waypoints_xz):
    out = []
    for (x0, z0), (x1, z1) in zip(waypoints_xz[:-1], waypoints_xz[1:]):
        a = tuple(int(round(float(v))) for v in C.xz_to_ij(x0, z0, G))
        b = tuple(int(round(float(v))) for v in C.xz_to_ij(x1, z1, G))
        Hc, Wc = cost[0].shape
        a = (min(max(a[0], 0), Wc - 1), min(max(a[1], 0), Hc - 1))
        b = (min(max(b[0], 0), Wc - 1), min(max(b[1], 0), Hc - 1))
        p = astar(cost, a, b)
        xs, zs = C.ij_to_xz(np.array([q[0] for q in p], float), np.array([q[1] for q in p], float), G)
        seg = np.stack([xs, zs], 1)
        out.append(seg if not out else seg[1:])
    pts = np.vstack(out)
    pts = remove_loops(pts)
    pts = smooth(pts, 2)
    pts[:, 0] = ndimage.gaussian_filter1d(pts[:, 0], 3, mode="nearest"); pts[:, 1] = ndimage.gaussian_filter1d(pts[:, 1], 3, mode="nearest")
    return simplify(pts, 1.2)


def profile_peaks(points, hy, step=8.0, win=60, prom_real=40.0, rdist=None):
    """도로 고도 단면의 뚜렷한 고점: 양쪽 win칸(step m) 안에서 prom_real(실제 m) 이상 내려가는 곳. → [(x,z,y)]"""
    p = np.asarray(points, float); seg = np.hypot(*np.diff(p, axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
    t = np.arange(0, s[-1] + 1e-6, step); x = np.interp(t, s, p[:, 0]); z = np.interp(t, s, p[:, 1])
    h = ndimage.gaussian_filter1d(hy(x, z), 2)
    out = []
    for k in range(1, len(h) - 1):
        if h[k] >= h[k - 1] and h[k] >= h[k + 1]:
            lo = min(h[max(0, k - win):k].min(), h[k + 1:k + win + 1].min())
            if h[k] - lo >= prom_real * C.K:
                # 안장 검사: 길에 수직으로 양옆 30~90m 안에 봉우리 쪽(10m 실제 이상 높음)이 둘 다 있어야 고개(능선 넘기).
                # 한쪽이 물가로 떨어지면 산줄기 끝(코)을 도는 벼룻길 오르내림 → 고개가 아님.
                k0, k1 = max(k - 2, 0), min(k + 2, len(x) - 1)
                tx, tz = x[k1] - x[k0], z[k1] - z[k0]; nn = math.hypot(tx, tz) + 1e-9; nx, nz = -tz / nn, tx / nn
                sides = []
                for sg in (1, -1):
                    o = np.arange(6.0, 91.0, 6.0)
                    px_, pz_ = x[k] + sg * nx * o, z[k] + sg * nz * o
                    hh = hy(px_, pz_)
                    if rdist is not None:      # 높아지기 전에 물을 만나면 그쪽은 '물가로 떨어지는 쪽'
                        rd_ = rdist(px_, pz_); wet = np.nonzero(rd_ < 4.0)[0]; up = np.nonzero(hh > h[k] + 3 * C.K)[0]
                        if len(wet) and (not len(up) or wet[0] < up[0]):
                            sides.append(-1e9); continue
                    sides.append(float(hh.max()))
                if min(sides) - h[k] >= 10 * C.K:
                    out.append((float(x[k]), float(z[k]), float(h[k])))
    return out


def river_index(rivers, step=2.0):
    """하천 중심선 조밀 표본: 좌표, 단위 법선, 반폭, 하천 번호 + KD 트리."""
    from scipy.spatial import cKDTree
    P, N, HWs, IDs = [], [], [], []
    for k, r in enumerate(rivers):
        p = np.asarray(r["points"], float)[:, :2]
        seg = np.hypot(*np.diff(p, axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
        t = np.arange(0, s[-1] + 1e-6, step)
        x = np.interp(t, s, p[:, 0]); z = np.interp(t, s, p[:, 1])
        tx = np.gradient(x); tz = np.gradient(z); nn = np.hypot(tx, tz) + 1e-9
        P.append(np.stack([x, z], 1)); N.append(np.stack([-tz / nn, tx / nn], 1))
        HWs.append(np.full(len(t), max(r["width_m"] / 2, 2.6))); IDs.append(np.full(len(t), k))
    P = np.vstack(P); N = np.vstack(N); HWs = np.concatenate(HWs); IDs = np.concatenate(IDs)
    return dict(P=P, N=N, HW=HWs, ID=IDs, tree=cKDTree(P))

def fix_water_runs(points, RI, margin=1.5, bank=3.5):
    """길이 물길 안(반폭+margin)을 따라 걷는 구간을 고친다.
    같은 쪽으로 들어갔다 나오면 그 둑으로 밀어내고, 건너가면 구간 한가운데에서 수직으로 곧게 건너게 한다."""
    p = np.asarray(points, float)
    seg = np.hypot(*np.diff(p, axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
    t = np.arange(0, s[-1] + 1e-6, 1.0)
    q = np.stack([np.interp(t, s, p[:, 0]), np.interp(t, s, p[:, 1])], 1)
    d, k = RI["tree"].query(q)
    inside = d <= RI["HW"][k] + margin
    if not inside.any(): return p, 0
    out = []; i = 0; n = len(q); changed = 0
    while i < n:
        if not inside[i]:
            out.append(q[i]); i += 1; continue
        j = i
        while j + 1 < n and inside[j + 1]: j += 1
        kk = k[(i + j) // 2]; c = RI["P"][kk]; nrm = RI["N"][kk]; hw = RI["HW"][kk]
        a = q[max(i - 1, 0)]; b = q[min(j + 1, n - 1)]
        sa = np.sign(np.dot(a - c, nrm)) or 1.0; sb = np.sign(np.dot(b - c, nrm)) or 1.0
        run = q[i:j + 1]
        dd, kr = RI["tree"].query(run)
        off = RI["HW"][kr] + bank
        if sa == sb or j - i < 3:          # 같은 쪽: 둑으로 밀어냄
            out.extend(RI["P"][kr] + RI["N"][kr] * (sa * off)[:, None]); changed += len(run)
        else:                              # 건넘: 한가운데서 수직으로
            m = (i + j) // 2; km = k[m]
            cm, nm, hm = RI["P"][km], RI["N"][km], RI["HW"][km] + bank
            h1 = (j - i) // 2
            out.extend(RI["P"][kr[:h1]] + RI["N"][kr[:h1]] * (sa * off[:h1])[:, None])
            out.append(cm + nm * sa * hm); out.append(cm); out.append(cm - nm * sa * hm)
            out.extend(RI["P"][kr[h1:]] + RI["N"][kr[h1:]] * (sb * off[h1:])[:, None])
            changed += len(run)
        i = j + 1
    out = np.asarray(out)
    return simplify(out, 0.6), changed
