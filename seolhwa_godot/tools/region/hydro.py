"""수계: 흐름 방향(D8)·누적 → 하천 나무(본류/지류) → 고증 이름·등급 → 수면 단조 감소 → 높이맵 깎기.
고증 제어선 = OSM 하천선(현대 위치, 이름 출처)을 DEM에 새겨(burn) 흐름이 그 길을 따르게 한다(계획서 §4: 고증이 계산을 이긴다).
직강화된 구간(평탄·직선)은 사행을 되살린다(가설)."""
import heapq, json, math, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
import common as C, places as P

F = 4                          # 수문 격자 = 4×2m = 8m(게임)
HC = C.CELL * F
REAL_CELL_M2 = (HC / C.K) ** 2
A_D = 1.2e6 / REAL_CELL_M2     # D급 이상: 집수면적 1.2km²(실제)
A_C = 8.0e6 / REAL_CELL_M2     # C급: 8km²
A_B = 80e6 / REAL_CELL_M2      # B급: 80km²
NB = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]

KNOWN = {  # 이름 → (등급 하한, 바깥 행선지) — 남원 기본값. 다른 권역은 설정 hydro.known {이름: {id, grade, flows_to}}
    "요천": ("B", "섬진강(권역 밖 서남, 남원 금지면에서 합류)"),
    "람천": ("C", "임천→엄천강→경호강→남강→낙동강(권역 밖 동쪽)"),
    "만수천": ("C", "람천"),
    "임천": ("B", "엄천강→경호강→남강→낙동강(권역 밖)"),
}
NAME_IDS = {"요천": "yocheon", "람천": "ramcheon", "만수천": "mansucheon", "임천": "imcheon"}
_HC = C.CFG.get("hydro", {})
if "known" in _HC:
    KNOWN = {n: (v["grade"], v["flows_to"]) for n, v in _HC["known"].items()}
    NAME_IDS = {n: v["id"] for n, v in _HC["known"].items()}
if "acc_km2" in _HC:
    A_D = _HC["acc_km2"]["D"] * 1e6 / REAL_CELL_M2; A_C = _HC["acc_km2"]["C"] * 1e6 / REAL_CELL_M2; A_B = _HC["acc_km2"]["B"] * 1e6 / REAL_CELL_M2
DEPTH_REAL = _HC.get("depth_real", {"B": 2.5, "C": 1.4, "D": 0.6})

def osm_lines():
    d = json.load(open(os.path.join(C.CACHE, "osm_rivers.json")))
    out = []
    for e in d["elements"]:
        g = e.get("geometry")
        if not g: continue
        lat = np.array([p["lat"] for p in g]); lon = np.array([p["lon"] for p in g])
        x, z = C.geo_to_game(lat, lon)
        out.append(dict(name=e["tags"].get("name"), x=x, z=z, kind=e["tags"].get("waterway")))
    return out

def priority_flood(h):
    """Barnes(2014) priority-flood + ε: 모든 칸이 가장자리로 흘러나가게."""
    Hh, Ww = h.shape
    filled = h.copy(); done = np.zeros(h.shape, bool); pq = []
    for j in range(Hh):
        for i in (0, Ww - 1):
            heapq.heappush(pq, (float(h[j, i]), j, i)); done[j, i] = True
    for i in range(1, Ww - 1):
        for j in (0, Hh - 1):
            heapq.heappush(pq, (float(h[j, i]), j, i)); done[j, i] = True
    eps = 1e-3
    while pq:
        v, j, i = heapq.heappop(pq)
        for dj, di in NB:
            nj, ni = j + dj, i + di
            if 0 <= nj < Hh and 0 <= ni < Ww and not done[nj, ni]:
                done[nj, ni] = True
                nv = filled[nj, ni]
                if nv <= v + eps:
                    nv = v + eps; filled[nj, ni] = nv
                heapq.heappush(pq, (float(nv), nj, ni))
    return filled

def d8(filled):
    Hh, Ww = filled.shape
    pad = np.pad(filled, 1, constant_values=-1e9)    # 가장자리 밖 = 바다처럼 낮음
    best = np.zeros(filled.shape); dirn = np.full(filled.shape, -1, int)
    for k, (dj, di) in enumerate(NB):
        nb = pad[1 + dj:1 + dj + Hh, 1 + di:1 + di + Ww]
        s = (filled - nb) / math.hypot(dj, di)
        upd = s > best
        best[upd] = s[upd]; dirn[upd] = k
    return dirn

def accumulate(filled, dirn):
    Hh, Ww = filled.shape
    acc = np.ones(filled.shape)
    order = np.argsort(-filled, axis=None)
    dj = np.array([d[0] for d in NB]); di = np.array([d[1] for d in NB])
    fj, fi = np.divmod(order, Ww)
    dk = dirn.ravel()[order]
    accf = acc.ravel()
    tj = fj + dj[dk]; ti = fi + di[dk]
    inside = (tj >= 0) & (tj < Hh) & (ti >= 0) & (ti < Ww)
    tgt = np.where(inside, tj * Ww + ti, -1)
    for s, t in zip(order.tolist(), tgt.tolist()):
        if t >= 0: accf[t] += accf[s]
    return acc

def build_tree(acc, dirn, sea=None):
    """가장자리 출구에서 거슬러 올라가며 본류(최대 누적 부모)를 잇는다 → 하천 목록(하류→상류 셀)."""
    Hh, Ww = acc.shape
    # 부모 목록
    dj = np.array([d[0] for d in NB]); di = np.array([d[1] for d in NB])
    jj, ii = np.nonzero((acc >= A_D) if sea is None else ((acc >= A_D) & ~sea))
    parents = {}
    for j, i in zip(jj.tolist(), ii.tolist()):
        k = dirn[j, i]
        tj, ti = j + dj[k], i + di[k]
        if 0 <= tj < Hh and 0 <= ti < Ww:
            parents.setdefault((tj, ti), []).append((j, i))
    outlets = []
    for j, i in zip(jj.tolist(), ii.tolist()):
        k = dirn[j, i]; tj, ti = j + dj[k], i + di[k]
        if not (0 <= tj < Hh and 0 <= ti < Ww) or (sea is not None and sea[tj, ti]):
            outlets.append((acc[j, i], (j, i)))
    outlets.sort(reverse=True)
    rivers = []
    stack = [(o, None, None) for _, o in outlets]
    while stack:
        start, parent_id, join_idx = stack.pop(0)
        cells = [start]; cur = start
        while True:
            ps = parents.get(cur, [])
            if not ps: break
            ps = sorted(ps, key=lambda c: -acc[c])
            for side in ps[1:]:
                stack.append((side, len(rivers), len(cells) - 1))
            cur = ps[0]; cells.append(cur)
        if len(cells) < 4: continue
        rivers.append(dict(cells=cells[::-1], parent=parent_id, join_cell=start, acc_mouth=float(acc[start])))
    return rivers

def chaikin(pts, n=2):
    for _ in range(n):
        q = 0.75 * pts[:-1] + 0.25 * pts[1:]; r = 0.25 * pts[:-1] + 0.75 * pts[1:]
        mid = np.empty((len(q) * 2, 2)); mid[0::2] = q; mid[1::2] = r
        pts = np.vstack([pts[:1], mid, pts[-1:]])
    return pts

def resample(pts, step):
    seg = np.hypot(*np.diff(pts, axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
    if s[-1] < step: return pts
    t = np.arange(0, s[-1], step); t = np.append(t, s[-1])
    return np.stack([np.interp(t, s, pts[:, 0]), np.interp(t, s, pts[:, 1])], 1)

def remeander(pts, slope, width, rng):
    """직강·직선 구간(평탄, 굴곡도<1.04)에 사인 사행 복원(가설). 반환: pts, 바뀐 구간 길이."""
    n = len(pts)
    if n < 20: return pts, 0.0
    seg = np.hypot(*np.diff(pts, axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
    win = 40
    straight = np.zeros(n, bool)
    for k in range(n):
        a, b = max(0, k - win), min(n - 1, k + win)
        chord = np.hypot(*(pts[b] - pts[a])); path = s[b] - s[a]
        straight[k] = path > 0 and path / max(chord, 1e-6) < 1.04 and slope[k] < 0.006
    straight = ndimage.binary_opening(straight, iterations=8)
    if not straight.any(): return pts, 0.0
    tang = np.gradient(pts, axis=0); tang /= np.linalg.norm(tang, axis=1, keepdims=True) + 1e-9
    nrm = np.stack([-tang[:, 1], tang[:, 0]], 1)
    lam = max(10 * width, 60.0); amp = max(1.2 * width, 6.0)
    taper = ndimage.gaussian_filter1d(straight.astype(float), 6)
    phase = rng.uniform(0, 2 * np.pi)
    off = amp * taper * np.sin(2 * np.pi * s / lam + phase + 0.6 * np.sin(2 * np.pi * s / (3.1 * lam)))
    return pts + nrm * off[:, None], float(seg[straight[:-1]].sum())

def run(alt_fixed, sea=None):
    """alt_fixed: 2m 격자 실제 고도(현대 흔적 제거 후). sea: 2m 바다 마스크(있으면 바다 칸 = 출구). 반환 (rivers 목록, 깎인 alt, 로그)"""
    Hh, Ww = (alt_fixed.shape[0] - 1) // F + 1, (alt_fixed.shape[1] - 1) // F + 1
    coarse = alt_fixed[::F, ::F][:Hh, :Ww].astype(np.float64)
    coarse = ndimage.grey_erosion(coarse, size=3) * 0.5 + coarse * 0.5   # 계곡 바닥 쪽으로
    # OSM 하천 새기기
    lines = osm_lines()
    burn = Image.new("L", (Ww, Hh), 0); db = ImageDraw.Draw(burn)
    for L in lines:
        i, j = C.xz_to_ij(L["x"], L["z"], HC)
        db.line(list(zip(i.tolist(), j.tolist())), fill=255 if L["kind"] == "river" or L["name"] in KNOWN else 160, width=2)
    bm = np.asarray(burn)
    h = coarse - np.where(bm == 255, 25.0, np.where(bm > 0, 12.0, 0.0))
    sea_c = None
    if sea is not None:
        sea_c = ndimage.binary_erosion(sea[::F, ::F][:Hh, :Ww], iterations=1)
        h = np.where(sea_c, -1e4, h)                      # 바다 = 출구
    filled = priority_flood(h)
    dirn = d8(filled); acc = accumulate(filled, dirn)
    tree = build_tree(acc, dirn, sea_c)
    # 이름 붙이기: OSM 선 근처 비율
    name_px = {}
    for L in lines:
        if not L["name"]: continue
        i, j = C.xz_to_ij(L["x"], L["z"], HC)
        im = Image.new("L", (Ww, Hh), 0); ImageDraw.Draw(im).line(list(zip(i.tolist(), j.tolist())), fill=255, width=1)
        m = ndimage.binary_dilation(np.asarray(im) > 0, iterations=5)
        name_px[L["name"]] = name_px.get(L["name"], np.zeros_like(m)) | m
    rng = np.random.default_rng(7)
    rivers = []; log = {"remeandered": []}
    for k, r in enumerate(tree):
        cj = np.array([c[0] for c in r["cells"]]); ci = np.array([c[1] for c in r["cells"]])
        best, frac = None, 0.0
        for nm, m in name_px.items():
            f = m[cj, ci].mean()
            if f > frac: best, frac = nm, f
        name = best if frac >= 0.35 else None
        a = r["acc_mouth"]
        grade = "B" if a >= A_B else "C" if a >= A_C else "D"
        r.update(name=name, name_frac=float(frac), grade=grade)
    # 같은 이름이 여러 조각이면 가장 큰 것만 이름 유지(나머지는 '<이름> 지류')
    seen = {}
    for k, r in sorted(enumerate(tree), key=lambda kr: -kr[1]["acc_mouth"]):
        if r["name"]:
            if r["name"] in seen: r["name"] = None
            else: seen[r["name"]] = k
    for r in tree:
        if r["name"] in KNOWN and "BCD".index(KNOWN[r["name"]][0]) < "BCD".index(r["grade"]):
            r["grade"] = KNOWN[r["name"]][0]
    ids = {}
    for k, r in enumerate(tree):
        ids[k] = NAME_IDS.get(r["name"], f"r{k:03d}")
    gw = _HC.get("width_game", {"B": 15.0, "C": 7.0, "D": 2.5})           # 수면 폭(게임 m)
    for k, r in enumerate(tree):
        cj = np.array([c[0] for c in r["cells"]], float); ci = np.array([c[1] for c in r["cells"]], float)
        x, z = C.ij_to_xz(ci, cj, HC)
        pts = np.stack([x, z], 1)
        if r["parent"] is not None:     # 합류점까지 잇기
            pj, pi = r["join_cell"]; px, pz = C.ij_to_xz(pi, pj, HC)
            pts = np.vstack([pts, [[px, pz]]])
        pts = resample(chaikin(pts, 3), 4.0)
        pts[:, 0] = ndimage.gaussian_filter1d(pts[:, 0], 2, mode="nearest")
        pts[:, 1] = ndimage.gaussian_filter1d(pts[:, 1], 2, mode="nearest")
        a = r["acc_mouth"]
        width = gw[r["grade"]] * (1.0 if r["grade"] != "C" else float(np.clip(0.7 + 0.3 * math.log10(a / A_C + 1) * 2, 0.8, 1.4)))
        # 경사(실제) 추정 → 사행 복원
        fi, fj = C.xz_to_ij(pts[:, 0], pts[:, 1])
        ground = C.bilinear(alt_fixed, fi, fj)
        ds = np.maximum(np.hypot(*np.gradient(pts, axis=0).T), 1e-3) / C.K
        slope = np.abs(np.gradient(ndimage.gaussian_filter1d(ground, 10))) / ds
        if r["grade"] in ("B", "C"):
            pts2, L = remeander(pts, slope, width, rng)
            if L > 0:
                log["remeandered"].append(dict(river=ids[k], name=r["name"], length_game_m=round(L)))
                if r["parent"] is not None: pts2[-1] = pts[-1]
                pts = resample(pts2, 4.0)
        r.update(pts=pts, width=width, id=ids[k])
    # 지류 끝점 → 부모(사행·평활 후) 선 위 가장 가까운 점으로 이음(큰 강부터)
    for k in sorted(range(len(tree)), key=lambda k: -tree[k]["acc_mouth"]):
        r = tree[k]
        if r["parent"] is None: continue
        pp = resample(tree[r["parent"]]["pts"], 1.0)
        d = np.hypot(pp[:, 0] - r["pts"][-1, 0], pp[:, 1] - r["pts"][-1, 1]); q = pp[int(np.argmin(d))]
        pts = r["pts"]
        # 마지막 몇 점을 부드럽게 끌어당김
        n = min(len(pts), 6); w = np.linspace(0, 1, n) ** 2
        pts[-n:] = pts[-n:] + (q - pts[-1]) * w[:, None]
        r["pts"] = pts
    # 수면: 하상 = 경로 주변 최저 → 하류로 누적 최솟값. 본류 먼저(큰 집수) → 지류는 합류 수면 이상.
    lowmap = ndimage.grey_erosion(alt_fixed, size=5)
    order = sorted(range(len(tree)), key=lambda k: -tree[k]["acc_mouth"])
    surf_of = {}
    for k in order:
        r = tree[k]; pts = r["pts"]
        fi, fj = C.xz_to_ij(pts[:, 0], pts[:, 1])
        g = C.bilinear(lowmap, fi, fj)
        g = ndimage.gaussian_filter1d(g, 2, mode="nearest")
        s = np.minimum.accumulate(g)
        if r["parent"] is not None and r["parent"] in surf_of:
            ppts, ps = surf_of[r["parent"]]
            d = np.hypot(ppts[:, 0] - pts[-1, 0], ppts[:, 1] - pts[-1, 1])
            floor = float(ps[int(np.argmin(d))])
            s = np.maximum(s, floor + 0.0)
        # 최소 경사(실제 0.05%)로 평탄 구간 없애기 — 상류에서 하류로 단조 감소
        seg = np.concatenate([[0], np.hypot(*np.diff(pts, axis=0).T)]) / C.K
        minslope = 0.0005
        for t in range(1, len(s)):
            s[t] = min(s[t], s[t - 1] - minslope * seg[t])
        if r["parent"] is not None and r["parent"] in surf_of:
            s = np.maximum(s, floor)            # 단조 감소 유지(비증가 수열과 상수의 max)
        if sea is not None:
            s = np.maximum(s, _HC.get("sea_level_alt", 0.0) + 0.05)     # 하구 수면은 바다 수면 위(단조 유지)
        surf_of[k] = (pts, s)
        r["surf_alt"] = s
    # 깎기 (2m 격자, 실제 고도로 계산)
    carved = alt_fixed.astype(np.float64).copy()
    Hf, Wf = carved.shape
    cl_surf = np.full(carved.shape, np.nan); cl_hw = np.zeros(carved.shape); cl_dep = np.zeros(carved.shape)
    depth_real = DEPTH_REAL
    for k in sorted(range(len(tree)), key=lambda k: tree[k]["acc_mouth"]):   # 큰 강이 나중에 덮음
        r = tree[k]
        P0 = r["pts"]; s0 = np.concatenate([[0], np.cumsum(np.hypot(*np.diff(P0, axis=0).T))])
        t1 = np.arange(0, s0[-1], 0.5)
        pts = np.stack([np.interp(t1, s0, P0[:, 0]), np.interp(t1, s0, P0[:, 1])], 1)
        s = np.interp(t1, s0, r["surf_alt"])                          # 호 길이로 보간(점 번호 아님)
        fi, fj = C.xz_to_ij(pts[:, 0], pts[:, 1])
        ii = np.clip(np.round(fi).astype(int), 0, Wf - 1); jj = np.clip(np.round(fj).astype(int), 0, Hf - 1)
        if _HC.get("taper"):     # 명세 v0.3 §5: 상류는 좁게 — 점마다 그 자리 집수면적의 등급 폭(강 폭 이하)
            ci_, cj_ = C.xz_to_ij(P0[:, 0], P0[:, 1], HC)
            a_loc = acc[np.clip(np.round(cj_).astype(int), 0, acc.shape[0] - 1), np.clip(np.round(ci_).astype(int), 0, acc.shape[1] - 1)]
            a_loc = np.maximum.accumulate(ndimage.maximum_filter1d(a_loc, 9))
            w_loc = np.minimum(np.where(a_loc >= A_B, gw["B"], np.where(a_loc >= A_C, gw["C"], gw["D"])), r["width"])
            r["w_pts"] = w_loc
            hw_ = np.maximum(np.interp(t1, s0, w_loc) / 2, 2.6) / C.K
        else:
            hw_ = max(r["width"] / 2, 2.6) / C.K
        cl_surf[jj, ii] = s; cl_hw[jj, ii] = hw_; cl_dep[jj, ii] = depth_real[r["grade"]]
    has = ~np.isnan(cl_surf)
    dist, (nj, ni) = ndimage.distance_transform_edt(~has, return_indices=True)
    d_real = dist * C.CELL / C.K
    S = cl_surf[nj, ni]; HW = cl_hw[nj, ni]; DEP = cl_dep[nj, ni]
    bed = S - DEP * np.clip(1 - (d_real / np.maximum(HW, 1e-3)) ** 2, 0, 1)
    inside = d_real <= HW
    bank_top = S + 0.8 + np.maximum(d_real - HW, 0) * 0.8
    newh = np.where(inside, np.minimum(carved, bed), np.minimum(carved, bank_top))
    w = np.clip(1 - (d_real - HW - 30) / 30.0, 0, 1); w = w * w * (3 - 2 * w)
    newh = carved * (1 - w) + newh * w
    near = (~inside) & (d_real <= HW + 6 / C.K)
    newh = np.where(near, np.maximum(newh, S + 0.4), newh)          # 물이 넘치지 않게(낮은 둔덕)
    carved = newh
    if sea is not None:
        sea_d = ndimage.distance_transform_edt(~sea) * C.CELL
        def sea_at(p):
            i, j = C.xz_to_ij(p[0], p[1]); return C.bilinear(sea_d, i, j) <= 30.0
    out = []
    for k, r in enumerate(tree):
        pts = r["pts"]; s = r["surf_alt"]
        step = 2                                                     # 약 8m 간격으로 내보냄
        idx = list(range(0, len(pts), step))
        if idx[-1] != len(pts) - 1: idx.append(len(pts) - 1)
        name = r["name"]
        if r["parent"] is None:
            flows_to = KNOWN.get(name, (None, None))[1] or "권역 밖(가장자리 유출)"
            if sea is not None and sea_at(pts[-1]):
                flows_to = _HC.get("sea_name", "바다")
            elif name is None and "edge_flows" in _HC:
                ex, ez = pts[-1]
                flows_to = next(e["label"] for e in _HC["edge_flows"] if eval(e["cond"], {"x": ex, "z": ez}))
            elif name is None:
                # 어느 수계로 나가는지 출구 위치로 판정
                ex = pts[-1, 0]
                flows_to = "권역 밖 — 요천/섬진강 수계" if ex < 0 else "권역 밖 — 람천/낙동강 수계"
        else:
            flows_to = tree[r["parent"]]["id"]
        label = name or (f"{tree[r['parent']]['name'] or tree[r['parent']]['id']} 지류" if r["parent"] is not None else "무명 내")
        out.append(dict(id=r["id"], name=label, grade=r["grade"], width_m=round(r["width"], 1),
                        points=[[round(float(pts[t, 0]), 1), round(float(pts[t, 1]), 1), round(float(C.alt_to_y(s[t])), 2)] for t in idx],
                        flows_to=flows_to, parent=None if r["parent"] is None else tree[r["parent"]]["id"],
                        catchment_km2=round(r["acc_mouth"] * REAL_CELL_M2 / 1e6, 1),
                        **({"widths": [round(float(r["w_pts"][t]), 1) for t in idx]} if "w_pts" in r else {}),
                        source=("OSM 하천선(이름·위치) + DEM 흐름 누적" if name else "DEM 흐름 누적(D8)"),
                        confidence=("추정" if name else "가설")))
    log["counts"] = {g: sum(1 for r in out if r["grade"] == g) for g in "BCD"}
    log["acc_thresholds_km2"] = dict(D=1.2, C=8, B=80)
    return out, carved.astype(np.float32), dict(log, filled=filled, acc=acc, dirn=dirn)

if __name__ == "__main__":
    import time
    t = time.time()
    a = np.load(os.path.join(C.CACHE, "alt_fixed.npy"))
    rv, carved, log = run(a)
    print(time.time() - t, log["counts"], log["remeandered"])
    for r in rv:
        if r["grade"] != "D" or r["name"] and "지류" not in r["name"]:
            print(r["id"], r["name"], r["grade"], r["catchment_km2"], r["flows_to"], len(r["points"]), r["points"][0][2], r["points"][-1][2])
    np.save(os.path.join(C.CACHE, "alt_carved.npy"), carved)
    json.dump(rv, open(os.path.join(C.CACHE, "rivers.json"), "w"), ensure_ascii=False)
    np.save(os.path.join(C.CACHE, "acc.npy"), log["acc"])
