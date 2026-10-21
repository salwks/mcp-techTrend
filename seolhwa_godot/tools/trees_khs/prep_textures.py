# trees-khs 텍스처 준비(1단계, numpy·PIL) — 원본 PNG/JPG → assets/trees/_work/*.mip (RGBA8 밉 사슬, 알파 덮임 보존)
#   python3 -I tools/trees_khs/prep_textures.py [leaf|oak|imp|all]
#   leaf : 곰솔 잎 BCA 2K(국가유산청) — 밉마다 알파 0.5 문턱 덮임을 0단계와 같게(먼 수관이 성겨지지 않게)
#   oak  : 참나무 잎 뭉치 아틀라스 2K — ambientCG LeafSet016(CC0) 잎 6장을 잔가지에 붙여 뭉치 카드 4종(2×2 칸)
#   imp  : 임포스터 낱장(build.gd가 그린 _work/imp_*.png) → 4방향 번짐 + 밉
# .mip 형식: b"MIP1" w h levels(uint32) + 0..levels-1 단계 RGBA8 이어 붙임(Godot Image FORMAT_RGBA8 밉 배치와 같음)
import sys, os, struct, math, random
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
KHS = os.path.join(ROOT, 'assets/trees/khs_gomsol/src/gomsol_textures')
CC0 = os.path.join(ROOT, 'assets/trees/src_cc0')
WORK = os.path.join(ROOT, 'assets/trees/_work')
os.makedirs(WORK, exist_ok=True)
if not os.path.exists(os.path.join(WORK, '.gdignore')): open(os.path.join(WORK, '.gdignore'), 'w').close()

def s2l(c): return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
def l2s(c): return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(np.maximum(c, 0), 1 / 2.4) - 0.055)

def coverage(a, th=0.5): return float((a > th).mean())

def fit_alpha(a, target, th=0.5):
    # 알파 배율 k를 찾아 (a·k > th) 덮임이 target이 되게(이분법)
    lo, hi = 0.25, 8.0
    for _ in range(20):
        k = (lo + hi) / 2
        if coverage(np.clip(a * k, 0, 1), th) < target: lo = k
        else: hi = k
    return np.clip(a * (lo + hi) / 2, 0, 1)

def dilate(rgb, a, iters=12):
    # 투명 부분 색을 이웃 불투명 색으로 번지게(밉·쌍선형에서 테두리 검은 띠 막기)
    rgb = rgb.copy(); m = (a > 0.02).astype(np.float32)
    for _ in range(iters):
        acc = np.zeros_like(rgb); w = np.zeros_like(m)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            acc += np.roll(np.roll(rgb * m[..., None], dy, 0), dx, 1); w += np.roll(np.roll(m, dy, 0), dx, 1)
        fill = (m == 0) & (w > 0)
        rgb[fill] = acc[fill] / w[fill][..., None]; m = np.maximum(m, fill.astype(np.float32))
    if (m == 0).any() and (m > 0).any(): rgb[m == 0] = rgb[m > 0].mean(0)
    return rgb

def mip_chain(rgba, keep_cov=True, srgb=True):
    # rgba: float 0..1(정사각 2의 거듭제곱). 색은 (sRGB면 선형으로) 알파 곱으로 줄이고, 알파 덮임은 0단계에 맞춘다
    h, w, _ = rgba.shape
    lin = s2l(rgba[..., :3]) if srgb else rgba[..., :3]
    a = rgba[..., 3]
    cov0 = coverage(a)
    levels = [rgba]
    cur_pm, cur_a = lin * a[..., None], a
    while w > 1:
        w //= 2; h //= 2
        cur_pm = cur_pm.reshape(h, 2, w, 2, 3).mean((1, 3))
        cur_a = cur_a.reshape(h, 2, w, 2).mean((1, 3))
        rgb = cur_pm / np.maximum(cur_a[..., None], 1e-4)
        if w >= 8: rgb = dilate(rgb, cur_a, 4)
        aa = fit_alpha(cur_a, cov0) if (keep_cov and w >= 4) else cur_a
        rgb = np.clip(rgb, 0, 1)
        levels.append(np.concatenate([l2s(rgb) if srgb else rgb, aa[..., None]], -1))
    return levels

def write_mip(path, levels):
    h, w, _ = levels[0].shape
    with open(path, 'wb') as f:
        f.write(b'MIP1' + struct.pack('<III', w, h, len(levels)))
        for L in levels: f.write((np.clip(L, 0, 1) * 255 + 0.5).astype(np.uint8).tobytes())
    print('wrote', os.path.relpath(path, ROOT), w, h, len(levels), 'cov0=%.3f' % coverage(levels[0][..., 3]))

def load_rgba(p):
    return np.asarray(Image.open(p).convert('RGBA'), np.float32) / 255.0

# ------------------------------------------------------------------ 곰솔 잎
def do_leaf():
    a = load_rgba(os.path.join(KHS, 'gomsol_leaf_bca_2048.png'))
    a[..., :3] = dilate(a[..., :3], a[..., 3], 16)
    write_mip(os.path.join(WORK, 'gomsol_leaf_bca.mip'), mip_chain(a))

# ------------------------------------------------------------------ 참나무 잎 뭉치
LEAF_BOX = [(71, 936, 93, 539), (96, 873, 691, 1217), (122, 871, 1349, 1913), (1146, 1934, 73, 653), (1163, 1935, 1413, 1882), (1170, 1915, 780, 1283)]

def do_oak():
    col = np.asarray(Image.open(os.path.join(CC0, 'LeafSet016/LeafSet016_2K-JPG_Color.jpg')).convert('RGB'), np.float32) / 255.0
    op = np.asarray(Image.open(os.path.join(CC0, 'LeafSet016/LeafSet016_2K-JPG_Opacity.jpg')).convert('L'), np.float32) / 255.0
    leaves = []
    for y0, y1, x0, x1 in LEAF_BOX:
        rgba = np.concatenate([col[y0:y1, x0:x1], op[y0:y1, x0:x1, None]], -1)
        leaves.append(Image.fromarray((rgba * 255).astype(np.uint8), 'RGBA'))   # 잎자루가 아래(+y)
    S = 2048; C = S // 2
    atlas = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    rnd = random.Random(7)
    from PIL import ImageDraw, ImageEnhance
    for cell in range(4):
        cx0, cy0 = (cell % 2) * C, (cell // 2) * C
        card = Image.new('RGBA', (C, C), (0, 0, 0, 0))
        dr = ImageDraw.Draw(card)
        # 잔가지: 카드 아래 가운데에서 위로 갈래(카드 = 가지 끝 잎 뭉치, 아래가 가지 쪽)
        base = (C * 0.5, C * 0.9)
        twigs = []
        n_tw = 3 + cell % 2
        for t in range(n_tw):
            ang = math.radians(-90 + (t - (n_tw - 1) / 2) * (24 + rnd.uniform(-6, 6)))
            L = C * rnd.uniform(0.5, 0.62)
            mid = (base[0] + math.cos(ang) * L * 0.45, base[1] + math.sin(ang) * L * 0.45)
            tip = (base[0] + math.cos(ang) * L, base[1] + math.sin(ang) * L)
            twigs.append((base, mid, tip, ang))
            dr.line([base, mid, tip], fill=(88, 72, 52, 255), width=int(C * 0.008))
        # 잎: 잔가지 끝에 돌려나기(참나무 잎은 가지 끝에 모여 남) + 가지 따라 몇 장
        items = []
        for (b, m, tip, ang) in twigs:
            for k in range(rnd.randint(9, 12)):
                t = rnd.uniform(0.85, 1.0) if k < 5 else rnd.uniform(0.3, 0.85)
                px = b[0] + (tip[0] - b[0]) * t; py = b[1] + (tip[1] - b[1]) * t
                rot = math.degrees(ang) + 90 + rnd.uniform(-60, 60) + ((k % 5) - 2) * 32
                sc = rnd.uniform(0.2, 0.27) * (0.85 if t < 0.85 else 1.0)
                items.append((rnd.random(), px, py, rot, sc, rnd.randrange(6), t))
        items.sort()
        for _, px, py, rot, sc, li, t in items:
            lf = leaves[li]
            w, h = lf.size
            lf2 = lf.resize((max(4, int(w * sc)), max(4, int(h * sc))), Image.LANCZOS)
            # 잎 하나하나 밝기·초록 차이(햇잎·그늘잎) — 바탕은 봄 잎이라 여름 잎처럼 조금 짙게
            arr = np.asarray(lf2, np.float32) / 255.0
            g = rnd.uniform(0.62, 0.92)
            arr[..., 0] *= g * rnd.uniform(0.82, 0.95); arr[..., 1] *= g; arr[..., 2] *= g * rnd.uniform(0.75, 0.95)
            lf2 = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), 'RGBA')
            # 잎자루(아래 가운데)를 원점으로 돌려 붙인다
            pad = max(lf2.size) * 2
            canvas = Image.new('RGBA', (pad, pad), (0, 0, 0, 0))
            canvas.paste(lf2, (pad // 2 - lf2.size[0] // 2, pad // 2 - lf2.size[1]), lf2)
            canvas = canvas.rotate(-rot, resample=Image.BICUBIC, center=(pad // 2, pad // 2))
            card.alpha_composite(canvas, (int(px - pad // 2), int(py - pad // 2))) if 0 <= int(px - pad // 2) and int(px - pad // 2) + pad <= C and 0 <= int(py - pad // 2) and int(py - pad // 2) + pad <= C else _paste_clip(card, canvas, int(px - pad // 2), int(py - pad // 2))
        atlas.paste(card, (cx0, cy0))
    a = np.asarray(atlas, np.float32) / 255.0
    a[..., 3] = np.where(a[..., 3] > 0.5, 1.0, a[..., 3] * 0.6)
    a[..., :3] = dilate(a[..., :3], a[..., 3], 24)
    Image.fromarray((a * 255).astype(np.uint8), 'RGBA').save(os.path.join(WORK, 'oak_leaf_atlas_preview.png'))
    write_mip(os.path.join(WORK, 'oak_leaf_bca.mip'), mip_chain(a))
    # 참나무 껍질(ambientCG Bark012, CC0): 1K 바탕색·법선(GL)·거칠기 → build.gd가 압축
    for tag, f in (('bc', 'Bark012_2K-PNG_Color.png'), ('nrm', 'Bark012_2K-PNG_NormalGL.png'), ('rough', 'Bark012_2K-PNG_Roughness.png'), ('ao', 'Bark012_2K-PNG_AmbientOcclusion.png')):
        Image.open(os.path.join(CC0, 'Bark012', f)).convert('RGB').resize((1024, 1024), Image.LANCZOS).save(os.path.join(WORK, 'oak_bark_%s_1k.png' % tag))
    print('oak bark 1k written')

def _paste_clip(dst, src, x, y):
    W, H = dst.size; w, h = src.size
    sx0, sy0 = max(0, -x), max(0, -y); sx1, sy1 = min(w, W - x), min(h, H - y)
    if sx1 <= sx0 or sy1 <= sy0: return
    dst.alpha_composite(src.crop((sx0, sy0, sx1, sy1)), (x + sx0, y + sy0))

# ------------------------------------------------------------------ 임포스터
def do_imp():
    for f in sorted(os.listdir(WORK)):
        if not (f.startswith('imp_') and f.endswith('_alb.png')): continue
        a = load_rgba(os.path.join(WORK, f))
        a[..., :3] = dilate(a[..., :3], a[..., 3], 16)
        write_mip(os.path.join(WORK, f.replace('.png', '.mip')), mip_chain(a)[1:])   # 굽기 2048 → 층 1024(밉 1단계부터)
        n = load_rgba(os.path.join(WORK, f.replace('_alb', '_nrm')))
        n[..., :3] = dilate(n[..., :3], a[..., 3], 16)
        n[..., 3] = a[..., 3]
        write_mip(os.path.join(WORK, f.replace('_alb.png', '_nrm.mip')), mip_chain(n, keep_cov=False, srgb=False)[1:])

if __name__ == '__main__':
    what = sys.argv[1] if len(sys.argv) > 1 else 'all'
    if what in ('leaf', 'all'): do_leaf()
    if what in ('oak', 'all'): do_oak()
    if what in ('imp', 'all'): do_imp()
