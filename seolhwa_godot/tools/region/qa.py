"""자동 QA (계획서 §6 중 데이터로 가능한 것): H(높이맵 범위·형식), Q1, Q2, Q4(덤), Q5, Q6, Q8, Q10, Q11(덤), Q14, QR, QL, QW, QP(고을 성격표), QC(기후대).
실행: python3 tools/region/qa.py  → 표 출력 + region_data/<id>/qa.json"""
import json, math, os, re, sys
import numpy as np
from PIL import Image
from scipy import ndimage
import common as C, export, roads as RD

R = {}
def rec(code, ok, msg, **kw):
    R[code] = dict(ok=bool(ok), msg=msg, **kw)

def poly_dist(pts, x, z):
    p = np.asarray(pts)[:, :2]
    a, b = p[:-1], p[1:]; ab = b - a; L2 = (ab ** 2).sum(1) + 1e-12
    t = np.clip(((np.array([x, z]) - a) * ab).sum(1) / L2, 0, 1)
    q = a + ab * t[:, None]
    return float(np.hypot(q[:, 0] - x, q[:, 1] - z).min())

def resample(p, step):
    p = np.asarray(p, float); seg = np.hypot(*np.diff(p[:, :2], axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
    t = np.arange(0, s[-1] + 1e-6, step)
    return np.stack([np.interp(t, s, p[:, k]) for k in range(p.shape[1])], 1)

def outlet_labels(dirn):
    """D8 방향 → 각 칸의 출구 칸 번호(포인터 점프)."""
    Hh, Ww = dirn.shape
    NB = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
    dj = np.array([d[0] for d in NB]); di = np.array([d[1] for d in NB])
    jj, ii = np.mgrid[0:Hh, 0:Ww]
    tj = jj + dj[dirn]; ti = ii + di[dirn]
    out = (tj < 0) | (tj >= Hh) | (ti < 0) | (ti >= Ww)
    nxt = np.where(out, jj * Ww + ii, np.clip(tj, 0, Hh - 1) * Ww + np.clip(ti, 0, Ww - 1)).ravel()
    for _ in range(40):
        n2 = nxt[nxt]
        if np.array_equal(n2, nxt): break
        nxt = n2
    return nxt.reshape(Hh, Ww)

def main():
    reg = json.load(open(os.path.join(C.OUT, "region.json")))
    y, meta = export.read_height()
    hm = reg["height"]
    def hy(x, z):
        fi, fj = C.xz_to_ij(np.asarray(x), np.asarray(z)); return C.bilinear(y, fi, fj)
    im = Image.open(os.path.join(C.OUT, "height.png"))
    raw = np.asarray(im)
    with open(os.path.join(C.OUT, "height.png"), "rb") as f: hdr = f.read(32)
    bitdepth, ctype = hdr[24], hdr[25]                     # IHDR: 16비트 회색조 = (16, 0)
    sizes = {f: os.path.getsize(os.path.join(C.OUT, f)) for f in os.listdir(C.OUT)}
    total = sum(sizes.values())
    clip = float(((raw == 0) | (raw == 65535)).mean())
    lm = {l["id"]: l for l in reg["landmarks"]}
    y_nw = float(hy(lm["gwanghallu"]["x"], lm["gwanghallu"]["z"])); y_ub = float(hy(lm["unbong_gwana"]["x"], lm["unbong_gwana"]["z"]))
    gz, gx = np.gradient(y, hm["cell"]); sl = np.hypot(gx, gz)
    okH = (bitdepth == 16 and ctype == 0 and raw.shape == (hm["h"], hm["w"]) and hm["cell"] <= 2 and clip < 1e-4
           and 3 <= y_nw <= 25 and 100 <= y_ub <= 140 and total < 40e6 and np.isfinite(y).all()
           and abs(float(y.min()) - hm["y_min"]) < 2 and abs(float(y.max()) - hm["y_max"]) < 2)
    rec("H", okH, f"PNG {bitdepth}bit 회색조(type {ctype}) {raw.shape[1]}×{raw.shape[0]} cell {hm['cell']}m, y {hm['y_min']}…{hm['y_max']} (실제 {C.y_to_alt(hm['y_min']):.0f}…{C.y_to_alt(hm['y_max']):.0f}m), "
        f"클립 {clip:.1e}, 광한루 y={y_nw:.1f}(실제 {C.y_to_alt(y_nw):.0f}m), 운봉 관아 y={y_ub:.1f}(실제 {C.y_to_alt(y_ub):.0f}m), "
        f"경사 tan 중앙값 {np.median(sl):.2f}/99% {np.percentile(sl, 99):.2f}, region_data 합계 {total / 1e6:.1f}MB", sizes=sizes)

    rivers = reg["rivers"]; rid = {r["id"]: r for r in rivers}
    W2, H2 = -C.X0, -C.Z0
    # Q1
    bad = []
    for r in rivers:
        end = r["points"][-1]
        if r.get("parent"):
            if r["parent"] not in rid or r["flows_to"] != r["parent"]: bad.append((r["id"], "부모 없음")); continue
            d = poly_dist(rid[r["parent"]]["points"], end[0], end[1])
            if d > 15: bad.append((r["id"], f"합류점 {d:.0f}m 떨어짐"))
        else:
            edge = min(W2 - abs(end[0]), H2 - abs(end[1]))
            if edge > 30: bad.append((r["id"], f"가장자리 {edge:.0f}m 전에 끝남"))
            if "권역 밖" not in r["flows_to"] and r["flows_to"] not in ("섬진강",) and not any(k in r["flows_to"] for k in ("섬진강", "낙동강")):
                bad.append((r["id"], "출구 행선지 불명"))
    rec("Q1", not bad, f"하천 {len(rivers)}개 모두 상위 하천 또는 권역 밖(→섬진강/낙동강)에 닿음" if not bad else f"실패 {bad[:6]}", fails=bad)

    # Q2: 단조 감소 + 수로가 지형 안에 + 능선 넘지 않음(같은 출구 유역)
    mono_bad = []; inch = []; banks = []
    for r in rivers:
        ys = np.array([p[2] for p in r["points"]])
        if np.any(np.diff(ys) > 1e-3): mono_bad.append(r["id"])
        p = resample(r["points"], 4.0)
        t = hy(p[:, 0], p[:, 1])
        inch.append(float((t <= p[:, 2] + 0.05).mean()))
        tg = np.gradient(p[:, :2], axis=0); tg /= np.linalg.norm(tg, axis=1, keepdims=True) + 1e-9
        off = r["width_m"] / 2 + 3.0
        bk = [hy(p[:, 0] + sgn * -tg[:, 1] * off, p[:, 1] + sgn * tg[:, 0] * off) for sgn in (1, -1)]
        banks.append(float(((bk[0] >= p[:, 2] + 0.02) & (bk[1] >= p[:, 2] + 0.02)).mean()))
    dirn = np.load(os.path.join(C.CACHE, "basin_dirn.npy"))
    lab = outlet_labels(dirn)
    HC = C.CELL * 4
    def lab_at(x, z):
        i, j = C.xz_to_ij(np.asarray(x), np.asarray(z), HC)
        return lab[np.clip(np.round(j).astype(int), 0, lab.shape[0] - 1), np.clip(np.round(i).astype(int), 0, lab.shape[1] - 1)]
    def lab_class(L):
        j, i = np.divmod(L, lab.shape[1]); x, z = C.ij_to_xz(i, j, HC)
        return np.where((x < -1500) | ((z > 1500) & (x < 0)), "섬진", np.where(x > 1500, "낙동", "?"))
    cross_bad = []
    for r in rivers:
        p = resample(r["points"], 8.0)[:-3]
        if len(p) < 3: continue
        L = lab_at(p[:, 0], p[:, 1])
        mouth = L[-1]
        frac = float((L == mouth).mean())
        if frac < 0.97: cross_bad.append((r["id"], round(frac, 3)))
    yw = [q for q in reg["passes"] if q["id"] == "yeowonjae"][0]
    ring = [(yw["x"] + 200 * math.cos(a), yw["z"] + 200 * math.sin(a)) for a in np.linspace(0, 2 * np.pi, 72)]
    cls = set(lab_class(lab_at([q[0] for q in ring], [q[1] for q in ring])).tolist())
    unb = str(lab_class(lab_at(lm["unbong_gwana"]["x"], lm["unbong_gwana"]["z"])))
    nwn = str(lab_class(lab_at(lm["gwanghallu"]["x"], lm["gwanghallu"]["z"])))
    okQ2 = not mono_bad and not cross_bad and min(inch) > 0.9 and np.mean(banks) > 0.95 and {"섬진", "낙동"} <= cls and unb == "낙동" and nwn == "섬진"
    rec("Q2", okQ2, f"수면 단조감소 위반 {len(mono_bad)}개, 유역(출구) 넘는 하천 {len(cross_bad)}개, 수로 안 수면(지형≤수면) 최소 {min(inch):.2f}/평균 {np.mean(inch):.3f}, 양안 둑≥수면 평균 {np.mean(banks):.3f}(최소 {min(banks):.2f}); "
        f"여원재 둘레 유역 {sorted(cls)}, 운봉={unb}·남원={nwn} (운봉고원=낙동강 수계, 남원=섬진강 수계)", mono_bad=mono_bad, cross_bad=cross_bad)

    # Q4(덤): 논 경사·고도
    lu = np.asarray(Image.open(os.path.join(C.OUT, "landuse.png"))); lu_shape = lu.shape
    y4 = y[::2, ::2][:lu.shape[0], :lu.shape[1]]
    g4z, g4x = np.gradient(y4, C.LU_CELL); s4 = np.hypot(g4x, g4z)
    pad = lu == 2; fld = lu == 3
    p_steep = float((s4[pad] > 0.10).mean()); f_steep = float((s4[fld] > 0.30).mean())
    pad_alt = C.y_to_alt(y4[pad])
    rec("Q4", p_steep < 0.03 and f_steep < 0.03 and np.percentile(pad_alt, 99) < 700,
        f"논 {pad.mean() * 100:.1f}% (경사>10% 비율 {p_steep * 100:.1f}%, 실제 고도 99% {np.percentile(pad_alt, 99):.0f}m), 밭 {fld.mean() * 100:.1f}% (경사>30% {f_steep * 100:.1f}%)",
        landuse_share={str(k): round(float((lu == k).mean()), 4) for k in range(10)})

    roads = reg["roads"]; passes = reg["passes"]; crossings = reg["crossings"]
    # Q5: 도로가 대간(섬진/낙동 분수계) 또는 뚜렷한 능선을 넘는 곳 = passes
    import landuse as LUm
    wmq = RD.river_masks(rivers, lu_shape)
    _dr4 = ndimage.distance_transform_edt(~(wmq["B"] | wmq["C"] | wmq["D"])) * C.LU_CELL
    rdist4 = lambda x, z: C.bilinear(_dr4, *C.xz_to_ij(np.asarray(x), np.asarray(z), C.LU_CELL))
    q5_bad = []; n_div = 0
    for rd in roads:
        p = resample(rd["points"], 8.0)
        c = lab_class(lab_at(p[:, 0], p[:, 1]))
        for k in range(1, len(c)):
            if {c[k - 1], c[k]} == {"섬진", "낙동"}:
                n_div += 1
                d = min(math.hypot(q["x"] - p[k, 0], q["z"] - p[k, 1]) for q in passes)
                if d > 200: q5_bad.append((rd["id"], round(float(p[k, 0])), round(float(p[k, 1])), round(d)))
        for (px, pz, ph) in RD.profile_peaks(rd["points"], hy, prom_real=40.0, rdist=rdist4):
            d = min(math.hypot(q["x"] - px, q["z"] - pz) for q in passes)
            if d > 260: q5_bad.append((rd["id"], round(px), round(pz), round(d), "능선"))
    rec("Q5", not q5_bad, f"분수계(섬진↔낙동) 통과 {n_div}회·돌출 40m(실제)↑ 능선 모두 고개(passes {len(passes)}개) 200m 안" if not q5_bad else f"고개 없는 능선 통과 {q5_bad[:6]}", fails=q5_bad)

    # Q6: 도로×하천 교차 = crossings
    q6_bad = []; n_x = 0
    for rd in roads:
        for r in rivers:
            a = np.asarray(rd["points"]); b = np.asarray(r["points"])[:, :2]
            for i in range(len(a) - 1):
                p0, d0 = a[i], a[i + 1] - a[i]
                q0 = b[:-1]; e = b[1:] - b[:-1]
                den = d0[0] * e[:, 1] - d0[1] * e[:, 0]; ok = np.abs(den) > 1e-9
                qp = q0 - p0; dd = np.where(ok, den, 1)
                t = (qp[:, 0] * e[:, 1] - qp[:, 1] * e[:, 0]) / dd; u = (qp[:, 0] * d0[1] - qp[:, 1] * d0[0]) / dd
                for k in np.nonzero(ok & (t >= 0) & (t <= 1) & (u >= 0) & (u <= 1))[0]:
                    n_x += 1; x, z = p0 + t[k] * d0
                    if not any(c["river_id"] == r["id"] and math.hypot(c["x"] - x, c["z"] - z) < 25 for c in crossings):
                        q6_bad.append((rd["id"], r["id"], round(float(x)), round(float(z))))
    types = {}
    for c in crossings: types[c["type"]] = types.get(c["type"], 0) + 1
    big = [c for c in crossings if rid[c["river_id"]]["grade"] in ("S", "A", "B")]
    bridge_like = [c for c in big if "다리" in c["type"] and "징검" not in c["type"] and "섶" not in c["type"]]
    rec("Q6", not q6_bad, f"도로×하천 교차 {n_x}곳 모두 도강점 있음; 형식 {types}; B급 도강 {len(big)}곳: {[c['type'] for c in big]}" if not q6_bad else f"도강점 없는 교차 {q6_bad[:6]}", fails=q6_bad)
    rec("Q11", len(big) == 0 or len(bridge_like) / len(big) <= 0.5, f"B급 이상 도강점 중 고정 다리 {len(bridge_like)}/{len(big)}")

    # Q8: 장시 연결
    def connected(a, b, tol=15):
        pa = resample(a["points"], 4.0)
        return any(poly_dist(b["points"], x, z) < tol for x, z in pa[::3])
    n = len(roads); adj = {i: set() for i in range(n)}
    for i in range(n):
        for j in range(i + 1, n):
            if connected(roads[i], roads[j]): adj[i].add(j); adj[j].add(i)
    main = next(i for i, r in enumerate(roads) if r["id"] == "tongyeong_byeolro")
    comp = {main}; st = [main]
    while st:
        k = st.pop()
        for m in adj[k]:
            if m not in comp: comp.add(m); st.append(m)
    q8 = []
    for s in reg["settlements"]:
        if s["type"] != "장시": continue
        ds = [(poly_dist(r["points"], s["x"], s["z"]), i) for i, r in enumerate(roads)]
        d, i = min(ds)
        q8.append((s["id"], round(d), i in comp, d <= s["radius_m"] + 40))
    unconnected = [r["id"] for i, r in enumerate(roads) if i not in comp]
    rec("Q8", all(c and o for _, _, c, o in q8), f"장시 {[(a, f'{b}m') for a, b, _, _ in q8]} — 모두 간선망(통영별로와 연결된 길)에 붙음; 망에서 떨어진 길: {unconnected or '없음'}",
        markets=q8)

    # Q10: 현대 흔적
    txt_fields = []
    for key in ("rivers", "roads", "passes", "crossings", "settlements", "landmarks"):
        for o in reg[key]:
            txt_fields.append(f"{o.get('name', '')} {o.get('type', '')} {o.get('class', '')} {o.get('kit', '')}")
    banned = re.compile(r"댐|저수지|철도|고속도로|아스팔트|콘크리트|제방|직강|전봇대|시멘트|터널|역사관|주유소")
    hits = [t for t in txt_fields if banned.search(t)]
    rm = np.load(os.path.join(C.CACHE, "res_mask.npy"))
    a0 = np.load(os.path.join(C.CACHE, "dem_alt.npy"))
    g0z, g0x = np.gradient(a0, C.CELL / C.K); flat0 = (np.hypot(g0x, g0z) < 0.004)
    flat1 = sl < 0.004
    lab_r, nr = ndimage.label(rm)
    flat_after = []; flat_before = []
    for k in range(1, nr + 1):
        m = lab_r == k
        flat_before.append(float(flat0[m].mean())); flat_after.append(float(flat1[m].mean()))
    lakes_ok = (max(flat_after) if flat_after else 0) < 0.25
    mf = reg.get("modern_fixes", {})
    rec("Q10", not hits and lakes_ok,
        f"이름·유형 금지어 {len(hits)}건; 지운 저수지 {len(mf.get('reservoirs_removed', []))}곳 평탄면 비율 전 {np.mean(flat_before):.2f}→후 {np.mean(flat_after):.2f} (최대 {max(flat_after):.2f}); "
        f"선형 현대시설(고속도로·철도·국도 성토/절토) {sum(x['osm_ways'] for x in mf.get('linear_removed', []))} OSM way 덮음; 남긴 소류지 {len(mf.get('reservoirs_kept', []))}곳(1.5ha 미만 — 조선 제언 가능, DEM 흔적 없음)",
        hits=hits)

    # Q14: 산 → 마을 → 밭 → 논 → 하천
    rank = {0: 0, 9: 0, 7: 0, 6: 1, 4: 1.5, 3: 2, 2: 3, 1: 3.5, 8: 3.5, 5: 4}
    res = []
    for s in reg["settlements"]:
        if s["type"] not in ("마을", "읍성", "역"): continue
        hc0 = float(hy(s["x"], s["z"]))
        cands = []
        for r in rivers:
            p = resample(r["points"], 12.0)
            d = np.hypot(p[:, 0] - s["x"], p[:, 1] - s["z"])
            for k in np.argsort(d)[:40]:
                if d[k] < 1500: cands.append((float(d[k]), float(p[k, 0]), float(p[k, 1])))
        cands.sort()
        best = None
        for d, rx, rz in cands[:400]:
            tt = np.linspace(0, 1, max(4, int(d / 8)))
            hh = hy(s["x"] + (rx - s["x"]) * tt, s["z"] + (rz - s["z"]) * tt)
            if hh.max() <= hc0 + 3 * C.K * 3:          # 사이에 9m(실제) 넘는 둔덕 없음
                best = (d, rx, rz); break
        if best is None: res.append((s["id"], False, "막힘 없는 하천 없음")); continue
        d, rx, rz = best
        if d < 1: res.append((s["id"], True, "하천가")); continue
        ux, uz = (rx - s["x"]) / d, (rz - s["z"]) / d
        t = np.arange(0, d + 1, C.LU_CELL)
        xs, zs = s["x"] + ux * t, s["z"] + uz * t
        i, j = C.xz_to_ij(xs, zs, C.LU_CELL)
        seq = lu[np.clip(np.round(j).astype(int), 0, lu.shape[0] - 1), np.clip(np.round(i).astype(int), 0, lu.shape[1] - 1)]
        rk = np.array([rank[int(v)] for v in seq])
        rk_s = np.maximum.accumulate(rk)
        viol = float((rk_s - rk > 1.0).mean())                 # 하천 쪽으로 가다가 숲/산으로 되돌아가는 비율
        tb = np.arange(0, 160, C.LU_CELL)
        bi, bj = C.xz_to_ij(s["x"] - ux * tb, s["z"] - uz * tb, C.LU_CELL)
        back = lu[np.clip(np.round(bj).astype(int), 0, lu.shape[0] - 1), np.clip(np.round(bi).astype(int), 0, lu.shape[1] - 1)]
        hill = float(np.isin(back[len(back) // 3:], [0, 9, 3, 7, 6]).mean())
        hb = hy(s["x"] - ux * 150, s["z"] - uz * 150); hc = hy(s["x"], s["z"]); hr = hy(rx, rz)
        ok = viol < 0.2 and np.isin(seq[-4:], [5, 1, 8, 2, 4]).any() and hc >= hr - 0.5
        res.append((s["id"], bool(ok), f"위반 {viol:.2f}, 뒤(산쪽) 숲·밭 {hill:.2f}, 뒤-앞 고도차 {float(hb - hc):+.1f}"))
    npass = sum(1 for r in res if r[1])
    rec("Q14", npass >= 0.75 * len(res), f"마을 단면 {npass}/{len(res)} 통과 (기준 75%)", detail=res)

    # QR: 도강점(반경 10m) 밖에서 길이 물 칸(landuse 5)이나 하천 수면 아래를 지나지 않음
    import landuse as LUq
    drq, rsq, rhwq, _ = LUq.river_fields(rivers, y.shape, G=C.CELL)      # 2m 격자(빌드의 둑 보정과 같은 기준)
    qr_bad = []; n_s = 0
    for rd in roads:
        p = resample(rd["points"], 2.0)
        for x, z in p[:, :2]:
            if any(math.hypot(c["x"] - x, c["z"] - z) <= max(rid[c["river_id"]]["width_m"], 5.2) / 2 + 4.5 for c in crossings): continue
            n_s += 1
            i4, j4 = C.xz_to_ij(x, z, C.LU_CELL); i4 = int(round(float(i4))); j4 = int(round(float(j4)))
            wet = lu[j4, i4] == 5
            i4, j4 = C.xz_to_ij(x, z, C.CELL); i4 = int(round(float(i4))); j4 = int(round(float(j4)))
            low = False
            if drq[j4, i4] <= max(rhwq[j4, i4], 2.6) + 4:      # 물가 둑 띠(물길 반폭+4m)에서 수면보다 낮으면 실패
                low = float(hy(x, z)) < rsq[j4, i4] + 0.1
            if wet or low: qr_bad.append((rd["id"], round(float(x)), round(float(z)), "물칸" if wet else "수면아래"))
    rec("QR", not qr_bad, f"길 표본 {n_s}점(2m 간격, 도강점 반경 '하천 반폭+4.5m' 밖) 모두 물 칸 아님·수면+0.1 이상(목표 +0.3, 격자 차 허용)" if not qr_bad else f"{len(qr_bad)}점 실패 {qr_bad[:8]}", fails=qr_bad[:200])

    # QL: 길 중심선 표본(2m)의 95% 이상이 landuse 4 (도강점 반경 안의 물 칸은 제외)
    tot = 0; hit = 0; per = {}
    for rd in roads:
        p = resample(rd["points"], 2.0); t_ = h_ = 0
        for x, z in p[:, :2]:
            i4, j4 = C.xz_to_ij(x, z, C.LU_CELL); i4 = int(round(float(i4))); j4 = int(round(float(j4)))
            v = lu[j4, i4]
            if v == 5 and any(math.hypot(c["x"] - x, c["z"] - z) <= max(rid[c["river_id"]]["width_m"], 5.2) / 2 + 4.5 for c in crossings): continue
            t_ += 1; h_ += int(v == 4)
        per[rd["id"]] = round(h_ / max(t_, 1), 3); tot += t_; hit += h_
    rec("QL", hit / max(tot, 1) >= 0.95 and min(per.values()) >= 0.9, f"길 중심선 표본 {tot}점 중 landuse 4 비율 {hit / max(tot, 1):.3f} (길별 최소 {min(per.values()):.3f})", per_road=per)

    # QW(덤): 남원읍성 성벽(한 변 186m, 중심선 ±90.7m)을 넘는 길은 성문 통로(문 중심 9m 안)로만
    eup = lm["namwon_eupseong"]; cx, cz = eup["x"], eup["z"]; hz = 93.0 - 2.3
    gates = [(cx, cz + hz), (cx, cz - hz), (cx + hz, cz), (cx - hz, cz)]
    wall_bad = []
    for rd in roads:
        p = resample(rd["points"], 1.0)
        ins = (np.abs(p[:, 0] - cx) < hz) & (np.abs(p[:, 1] - cz) < hz)
        for k in np.nonzero(ins[1:] != ins[:-1])[0]:
            x, z = p[k + 1, 0], p[k + 1, 1]
            if min(math.hypot(x - gx, z - gz) for gx, gz in gates) > 9: wall_bad.append((rd["id"], round(float(x)), round(float(z))))
    rec("QW", not wall_bad, "읍성 성벽을 넘는 길은 모두 성문 통로" if not wall_bad else f"성문 아닌 곳에서 성벽 통과 {wall_bad[:6]}", fails=wall_bad)

    # QP: 고을 성격표(계약서 §9) — archetypes 있음, 마을 터가 있는 settlement·사찰·성황당 모두 profile(유형·기후대·signature)
    arch = reg.get("archetypes", {}); okc = {"south", "central", "north", "alpine", "coast"}
    lays = {"walled_grid", "round_cluster", "linear_street", "fan_from_ferry", "terraced", "few_roadside", "along_temple_road", "linear_shore", "olle_alleys"}
    qp_bad = []
    for s in reg["settlements"]:
        pf = s.get("profile")
        if not pf: qp_bad.append((s["id"], "profile 없음")); continue
        if pf.get("archetype") not in arch: qp_bad.append((s["id"], f"유형 {pf.get('archetype')}"))
        if pf.get("climate") not in okc: qp_bad.append((s["id"], f"기후대 {pf.get('climate')}"))
        if not pf.get("signature"): qp_bad.append((s["id"], "signature 없음"))
        lay = pf.get("layout", arch.get(pf.get("archetype"), {}).get("layout"))
        if lay not in lays: qp_bad.append((s["id"], f"짜임 {lay}"))
    cnt = {}
    for s in reg["settlements"]:
        a_ = s.get("profile", {}).get("archetype"); cnt[a_] = cnt.get(a_, 0) + 1
    rec("QP", len(arch) >= 9 and not qp_bad, f"archetypes {len(arch)}개, settlement {len(reg['settlements'])}곳 모두 profile — 유형별 {cnt}" if not qp_bad else f"실패 {qp_bad[:6]}", fails=qp_bad)

    # QC: 기후대 지도 — landuse와 같은 격자, 코드 0~4, 이 권역은 south + 해발 1,100m 이상 alpine만
    cm = reg.get("climate", {})
    cl = np.asarray(Image.open(os.path.join(C.OUT, cm.get("file", "climate.png"))))
    alt4 = C.y_to_alt(ndimage.uniform_filter(y[::2, ::2], 7))
    same = cl.shape == lu_shape and cm.get("cell") == reg["landuse"]["cell"] and cl.dtype == np.uint8
    codes = sorted(int(v) for v in np.unique(cl))
    mism = float(((cl == 3) != (alt4 >= 1100.0)).mean())
    rec("QC", same and set(codes) <= {0, 3} and mism < 0.001 and set(cm.get("codes", {}).values()) == okc,
        f"climate.png {cl.shape[1]}×{cl.shape[0]} 8bit(landuse와 같은 격자 {same}), 코드 {codes} — south {float((cl == 0).mean()):.3f}, alpine {float((cl == 3).mean()):.4f}(해발 1,100m↑ 불일치 {mism:.5f})")

    os.makedirs(C.OUT, exist_ok=True)
    json.dump(R, open(os.path.join(C.OUT, "qa.json"), "w"), ensure_ascii=False, indent=1, default=str)
    for k, v in R.items():
        print(f"{k:4s} {'PASS' if v['ok'] else 'FAIL'}  {v['msg']}")
    return R

if __name__ == "__main__":
    main()
