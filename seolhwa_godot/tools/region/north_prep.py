"""data-north 준비: 권역 하나(인자 <ID>)의 캐시를 build_region.py가 쓸 수 있게 다듬고 설정을 쓴다.
  1) DEM: 공용 dem.build(force) → 도시 건물 잡음 제거(저지대 grey opening, 실제 60m 창) → cache/<ID>/dem_alt.npy (원본은 dem_alt_raw.npy)
  2) 큰 강(한강·대동강 등): OSM 중심선(없으면 제어점)을 1870 추정 폭으로 띠 다각형 → osm_water.json에 이름 있는 natural=water로 넣음(설정 lakes가 읽음)
     강물 다각형(water=river)은 modern_fix가 건드리지 않으므로 그대로 두되, 다리(bridge=yes) 철도·도로는 osm_modern.json에서 뺌(강을 가로지르는 둑이 생기지 않게)
  3) OSM에 이름이 없거나 복개된 하천(만초천 등)은 제어점 선을 osm_rivers.json에 넣음(hydro가 새기고 이름 붙임)
  4) north_places_<xx>.py → regions/<ID>.json (build_region 설정 문법)
실행: python3 tools/region/north_prep.py <ID>   (north_dem.py·north_osm.py 뒤, build.py <ID> 앞)"""
import json, math, os, sys, importlib
import numpy as np
from scipy import ndimage
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import common as C

RID = C.REGION_ID
MOD = {"GG_HANYANG": "north_places_gg", "HH_HWANGJU": "north_places_hh", "PA_PYEONGYANG": "north_places_pa", "HG_HAMHEUNG": "north_places_hg"}[RID]
P = importlib.import_module(MOD)
CFG_PATH = os.path.join(HERE, "regions", RID + ".json")

def say(*a): print(f"[north_prep {RID}]", *a, flush=True)

def load(name):
    p = os.path.join(C.CACHE, name)
    return json.load(open(p)) if os.path.exists(p) else {"elements": []}

def save(name, d):
    json.dump(d, open(os.path.join(C.CACHE, name), "w"), ensure_ascii=False)

# ── 1) DEM
def prep_dem():
    import dem
    raw_p = os.path.join(C.CACHE, "dem_alt_raw.npy")
    if os.path.exists(raw_p): alt = np.load(raw_p)
    else:
        alt = dem.build(force=True); np.save(raw_p, alt)
    dn = getattr(P, "DENOISE", dict(win_real_m=60.0, full_below=40.0, none_above=90.0))
    k = max(3, int(round(dn["win_real_m"] * C.K / C.CELL)) | 1)
    opened = ndimage.grey_opening(alt, size=(k, k))
    opened = ndimage.gaussian_filter(opened, k / 4)
    lo = ndimage.gaussian_filter(alt, 3 * k)                  # 둘레 평균 고도로 저지대 판정(봉우리는 남김)
    w = np.clip((dn["none_above"] - lo) / (dn["none_above"] - dn["full_below"]), 0, 1)
    w = w * w * (3 - 2 * w)
    out = alt * (1 - w) + np.minimum(alt, opened) * w
    np.save(os.path.join(C.CACHE, "dem_alt.npy"), out.astype(np.float32))
    say("DEM 잡음 제거: 창", k, "칸, 평균 변화", round(float(np.abs(out - alt).mean()), 2), "m, 최대", round(float((alt - out).max()), 1), "m")
    return out

# ── 2)·3) 하천
def ctrl_line(ctrl, name, step_real=40.0):
    """제어점 위경도 → 중심선. 같은 이름의 OSM 하천선이 있으면 그 점들을 제어선 따라 순서 매겨 씀."""
    la = np.array([c[0] for c in ctrl]); lo = np.array([c[1] for c in ctrl])
    cx, cz = C.geo_to_game(la, lo); cp = np.stack([cx, cz], 1)
    seg = np.hypot(*np.diff(cp, axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
    t = np.arange(0, s[-1], step_real * C.K)
    base = np.stack([np.interp(t, s, cp[:, 0]), np.interp(t, s, cp[:, 1])], 1)
    osm = load("osm_rivers.json")
    pts = []
    for e in osm["elements"]:
        if e.get("tags", {}).get("name") != name or not e.get("geometry") or e.get("_north"): continue
        g = e["geometry"]; x, z = C.geo_to_game(np.array([p["lat"] for p in g]), np.array([p["lon"] for p in g]))
        pts += list(zip(x.tolist(), z.tolist()))
    if len(pts) > 20:
        pts = np.asarray(pts)
        d = np.hypot(pts[:, None, 0] - base[None, :, 0], pts[:, None, 1] - base[None, :, 1])
        k = d.argmin(1); near = d.min(1) < 600 * C.K
        if near.sum() > 20:
            # 제어선 칸마다 OSM 점 평균(없으면 제어선)
            out = base.copy()
            for i in range(len(base)):
                m = near & (np.abs(k - i) <= 1)
                if m.any(): out[i] = pts[m].mean(0)
            out[:, 0] = ndimage.gaussian_filter1d(out[:, 0], 2, mode="nearest"); out[:, 1] = ndimage.gaussian_filter1d(out[:, 1], 2, mode="nearest")
            return out, "osm"
    return base, "ctrl"

def band_polygon(line, half):
    t = np.gradient(line, axis=0); t /= np.linalg.norm(t, axis=1, keepdims=True) + 1e-9
    n = np.stack([-t[:, 1], t[:, 0]], 1)
    # 가장자리 밖까지 늘림
    ext0 = line[0] - t[0] * 400; ext1 = line[-1] + t[-1] * 400
    L = np.vstack([ext0, line, ext1]); N = np.vstack([n[0], n, n[-1]])
    poly = np.vstack([L + N * half, (L - N * half)[::-1]])
    return poly

def big_river_mask(raw, r):
    """S급 큰 강: 원 DEM의 물면(평탄 저지대, 해발 ≤ water_alt_max)에서 강 중심 제어선에 닿는 덩어리. 섬(능라도·노들섬 등)은 구멍으로 남김."""
    sm = ndimage.gaussian_filter(raw, 1.5)
    low = sm <= r["water_alt_max"]
    la = np.array([c[0] for c in r["ctrl"]]); lo = np.array([c[1] for c in r["ctrl"]])
    cx, cz = C.geo_to_game(la, lo); seg = np.hypot(np.diff(cx), np.diff(cz)); s_ = np.concatenate([[0], np.cumsum(seg)])
    t = np.arange(0, s_[-1], C.CELL); fi, fj = C.xz_to_ij(np.interp(t, s_, cx), np.interp(t, s_, cz))
    ok = (fi >= 0) & (fi < raw.shape[1]) & (fj >= 0) & (fj < raw.shape[0])
    seed = np.zeros(raw.shape, bool); seed[fj[ok].astype(int), fi[ok].astype(int)] = True
    seed = ndimage.binary_dilation(seed, iterations=int(150 * C.K / C.CELL)) & low
    lab, n = ndimage.label(low); keep = np.unique(lab[seed]); keep = keep[keep > 0]
    m = np.isin(lab, keep)
    it = max(1, int(round(25 * C.K / C.CELL)))
    m = ndimage.binary_opening(m, iterations=it); m = ndimage.binary_closing(m, iterations=it)
    # 작은 구멍(모래톱·잡음) 메우고 큰 섬은 남김
    holes = ndimage.binary_fill_holes(m) & ~m
    hl, hn = ndimage.label(holes); sizes = ndimage.sum(holes, hl, range(1, hn + 1)) * (C.CELL / C.K) ** 2
    small = np.isin(hl, [k + 1 for k, a_ in enumerate(sizes) if a_ < r.get("island_min_real_m2", 60000)])
    m |= small
    lab, n = ndimage.label(m); sz = ndimage.sum(m, lab, range(1, n + 1))
    m = np.isin(lab, [k + 1 for k, a_ in enumerate(sz) if a_ * (C.CELL / C.K) ** 2 > 2e5])
    # 권역 가장자리까지 잇기: 가장자리 400m(게임) 띠에서는 제어선을 물면 평균 폭으로 칠함(물이 권역 밖으로 나가게)
    from PIL import Image, ImageDraw
    hw = float(m.sum() * C.CELL ** 2 / max(s_[-1], 1.0)) / 2                     # 평균 반폭(게임 m)
    im = Image.new("L", (raw.shape[1], raw.shape[0]), 0)
    ei, ej = C.xz_to_ij(cx, cz)
    d0 = np.array([ei[1] - ei[0], ej[1] - ej[0]]); d0 /= np.linalg.norm(d0); d1 = np.array([ei[-1] - ei[-2], ej[-1] - ej[-2]]); d1 /= np.linalg.norm(d1)
    pts = [(ei[0] - d0[0] * 300, ej[0] - d0[1] * 300)] + list(zip(ei.tolist(), ej.tolist())) + [(ei[-1] + d1[0] * 300, ej[-1] + d1[1] * 300)]
    ImageDraw.Draw(im).line(pts, fill=255, width=max(4, int(2 * hw / C.CELL)))
    band = np.asarray(im) > 0
    jj, ii = np.mgrid[0:raw.shape[0], 0:raw.shape[1]]
    edge = np.minimum(np.minimum(ii, raw.shape[1] - 1 - ii), np.minimum(jj, raw.shape[0] - 1 - jj)) * C.CELL < 400
    gap = ~ndimage.binary_dilation(m, iterations=max(2, int(1.5 * hw / C.CELL)))
    m |= band & (edge | gap)
    m = ndimage.binary_closing(m, iterations=3)
    # 하중도(섬): 섬 둘레 물길을 보장하고 섬은 뭍으로 [name, lat, lon, 길이·폭(실제 m), 방향(도, 북=0 시계)]
    isl = np.zeros(raw.shape, bool)
    if r.get("islands"):
        X, Z = C.ij_to_xz(*np.meshgrid(np.arange(raw.shape[1]), np.arange(raw.shape[0])))
        for nm, la_, lo_, L_, W_, ang in r["islands"]:
            ix, iz = C.geo_to_game(la_, lo_); a = math.radians(ang)
            u = (X - ix) * math.sin(a) - (Z - iz) * math.cos(a); v = (X - ix) * math.cos(a) + (Z - iz) * math.sin(a)
            a_, b_ = L_ * C.K / 2, W_ * C.K / 2; ch = r.get("island_channel_real_m", 160) * C.K
            m |= (u / (a_ + ch)) ** 2 + (v / (b_ + ch)) ** 2 <= 1
            isl |= (u / a_) ** 2 + (v / b_) ** 2 <= 1
        m &= ~isl
    k = 10                                                   # 모폴로지가 깎은 가장자리 칸을 안쪽 값으로 채움
    m[:, :k] |= m[:, k:k + 1]; m[:, -k:] |= m[:, -k - 1:-k]; m[:k, :] |= m[k:k + 1, :]; m[-k:, :] |= m[-k - 1:-k, :]
    return m

def prep_rivers(alt):
    raw = np.load(os.path.join(C.CACHE, "dem_alt_raw.npy"))
    rivers_osm = load("osm_rivers.json"); modern = load("osm_modern.json")
    rivers_osm["elements"] = [e for e in rivers_osm["elements"] if not e.get("_north")]
    nb = len(modern["elements"])
    modern["elements"] = [e for e in modern["elements"] if e.get("tags", {}).get("bridge") in (None, "no")]
    say("osm_modern 다리 제외", nb - len(modern["elements"]))
    big = np.zeros(alt.shape, bool); big_names = []; carved_lines = []
    LINES = {}
    for rid, r in P.RIVER_CONTROL.items():
        if r["grade"] == "S":
            m = big_river_mask(raw, r); big |= m; big_names.append(r["name"])
            if r.get("islands"):     # 섬 땅은 물면보다 조금 높게(실제 해발 3~6m 모래섬)
                X_, Z_ = C.ij_to_xz(*np.meshgrid(np.arange(raw.shape[1]), np.arange(raw.shape[0])))
                for nm, la_, lo_, L_, W_, ang in r["islands"]:
                    ix, iz = C.geo_to_game(la_, lo_); a = math.radians(ang)
                    u = (X_ - ix) * math.sin(a) - (Z_ - iz) * math.cos(a); v = (X_ - ix) * math.cos(a) + (Z_ - iz) * math.sin(a)
                    e = np.sqrt((u / (L_ * C.K / 2)) ** 2 + (v / (W_ * C.K / 2)) ** 2)
                    alt[:] = np.where(e <= 1, np.maximum(alt, 2.0 + 4.0 * np.clip(1 - e, 0, 1) ** 0.5), alt)
            say("큰 강", r["name"], "물면", round(float(m.mean()) * 100, 1), "%")
            continue
        LINES[rid] = None
    # 하천선: 큰 강부터(부모 먼저) — 지류 끝은 부모 선에 닿게 이음(새긴 골이 합류점에서 끊기지 않게)
    def _calc(rid, r):
            line, src = ctrl_line(r["ctrl"], (r.get("osm_names") or [r["name"].split("(")[0]])[0])
            # 권역 가장자리 근처에서 끝나면 바깥으로 300m 늘림(새긴 물길이 가장자리에서 막히지 않게)
            def _near_edge(p): return min(-C.X0 - abs(p[0]), -C.Z0 - abs(p[1])) < 120
            if _near_edge(line[-1]):      # 권역 밖으로 나가는 강: 가장자리 너머까지
                d_ = line[-1] - line[-3]; d_ /= np.linalg.norm(d_) + 1e-9; q_ = line[-1].copy(); ext = []
                while abs(q_[0]) < -C.X0 + 100 and abs(q_[1]) < -C.Z0 + 100: q_ = q_ + d_ * 20; ext.append(q_.copy())
                if ext: line = np.vstack([line] + ext)
            if _near_edge(line[0]):
                d_ = line[0] - line[2]; d_ /= np.linalg.norm(d_) + 1e-9; line = np.vstack([line[0] + d_ * 300, line])
            return line, src
    for rid in list(LINES):
        LINES[rid] = _calc(rid, P.RIVER_CONTROL[rid])
    order = sorted(LINES, key=lambda k: "SABCD".index(P.RIVER_CONTROL[k]["grade"]))
    for rid in order:
        r = P.RIVER_CONTROL[rid]; line, src = LINES[rid]
        par = next((q for q in LINES if q != rid and P.RIVER_CONTROL[q]["name"].split("(")[0] in r["flows_to"]), None)
        if par is not None:
            pl = LINES[par][0]; dd = np.hypot(pl[:, 0] - line[-1, 0], pl[:, 1] - line[-1, 1]); k = int(np.argmin(dd))
            if dd[k] > 1.0: line = np.vstack([line, pl[k]]); LINES[rid] = (line, src)
        aliases = set(r.get("osm_names", []))
        rivers_osm["elements"] = [e for e in rivers_osm["elements"] if e.get("tags", {}).get("name") not in aliases]
        lat, lon = C.game_to_geo(line[:, 0], line[:, 1])
        rivers_osm["elements"].append(dict(type="way", id=-(100 + len(rivers_osm["elements"])), _north=True, tags=dict(waterway="river", name=r["name"].split("(")[0]),
                                           geometry=[dict(lat=float(a), lon=float(b)) for a, b in zip(lat, lon)]))
        say("하천선", r["name"], src)
        if r.get("carve"):      # 도시 DEM(건물 높이 섞임)에서 물길이 막히지 않게: 선을 따라 하류로 단조 감소하는 골을 팜
            seg = np.hypot(*np.diff(line, axis=0).T); s_ = np.concatenate([[0], np.cumsum(seg)]); t = np.arange(0, s_[-1], C.CELL)
            lx = np.interp(t, s_, line[:, 0]); lz = np.interp(t, s_, line[:, 1]); fi, fj = C.xz_to_ij(lx, lz)
            ok = (fi >= 0) & (fi < alt.shape[1] - 1) & (fj >= 0) & (fj < alt.shape[0] - 1)
            prof = ndimage.gaussian_filter1d(C.bilinear(alt, fi, fj), 10) - 1.5
            prof = np.minimum.accumulate(prof)
            mask = np.zeros(alt.shape, bool); pv = np.full(alt.shape, np.nan)
            ii = np.round(fi[ok]).astype(int); jj = np.round(fj[ok]).astype(int); mask[jj, ii] = True; pv[jj, ii] = prof[ok]
            d, (nj, ni) = ndimage.distance_transform_edt(~mask, return_indices=True); d = d * C.CELL
            tgt = pv[nj, ni] + np.maximum(d - 6.0, 0) * 0.12 / C.K * C.K       # 바닥 폭 12m, 둑 경사 12%
            w = d < r.get("carve_half_m", 50.0)
            alt[w] = np.minimum(alt[w], tgt[w])
            carved_lines.append(np.c_[lx, lz])
            say("  골 파기", r["name"], "수면 해발", round(float(prof[ok][0]), 1), "→", round(float(prof[ok][-1]), 1))
    if carved_lines:     # 판 골을 따라가는 현대 도로·철도는 modern_fix가 메우면 골이 막히므로 뺌
        from scipy.spatial import cKDTree
        tr = cKDTree(np.vstack(carved_lines)); nb_ = len(modern["elements"]); keep = []
        for e in modern["elements"]:
            g = e.get("geometry") or []
            if not g: keep.append(e); continue
            x_, z_ = C.geo_to_game(np.array([p["lat"] for p in g]), np.array([p["lon"] for p in g]))
            dd, _ = tr.query(np.c_[x_, z_])
            if (dd < 60).mean() < 0.3: keep.append(e)
        modern["elements"] = keep; say("판 골 따라가는 현대 선 제외", nb_ - len(keep))
    np.save(os.path.join(C.CACHE, "dem_alt.npy"), alt.astype(np.float32))
    if big.any():
        alt = np.where(big, np.minimum(alt, -3.0), np.maximum(alt, 0.8)).astype(np.float32)
        np.save(os.path.join(C.CACHE, "dem_alt.npy"), alt); np.save(os.path.join(C.CACHE, "north_bigriver.npy"), big)
    save("osm_rivers.json", rivers_osm); save("osm_modern.json", modern)
    return big_names

def ferry_ends():
    """나룻배 뱃길(ferry 길): 두 점 사이 큰 강 물면을 건너는 선 — 양 끝을 물가 뭍 6m(게임)로 맞춤."""
    p_ = os.path.join(C.CACHE, "north_bigriver.npy")
    big = np.load(p_) if os.path.exists(p_) else None
    out = {}
    for r in P.ROADS:
        if not r.get("ferry"): continue
        a = np.array(C.geo_to_game(*r["via"][0]), float); b = np.array(C.geo_to_game(*r["via"][-1]), float)
        if big is None: out[r["id"]] = [r["via"][0], r["via"][-1]]; continue
        L = np.linalg.norm(b - a); u = (b - a) / L; t = np.arange(0, L, 1.0)
        pts = a[None] + t[:, None] * u[None]
        i = np.clip(np.round((pts[:, 0] - C.X0) / C.CELL).astype(int), 0, big.shape[1] - 1); j = np.clip(np.round((pts[:, 1] - C.Z0) / C.CELL).astype(int), 0, big.shape[0] - 1)
        wet = big[j, i]; w = np.nonzero(wet)[0]
        if not len(w): out[r["id"]] = [r["via"][0], r["via"][-1]]; say("뱃길 물면 없음", r["id"]); continue
        p0 = a + u * max(t[w[0]] - 6, 0); p1 = a + u * min(t[w[-1]] + 6, L)
        out[r["id"]] = [tuple(float(v) for v in C.game_to_geo(*p0)), tuple(float(v) for v in C.game_to_geo(*p1))]
        say("뱃길", r["id"], f"물 {t[w[-1]] - t[w[0]]:.0f}m(게임)")
    return out

# ── 4) 설정
def ll(p): return [round(p[0], 6), round(p[1], 6)]

def write_cfg(lakes):
    base = json.load(open(CFG_PATH))
    keep = {k: base[k] for k in ("id", "name", "builder", "province", "culture", "climate", "lat0", "lon0", "K", "y_base_alt", "cell", "x0", "z0", "fetch_bbox", "osm_bbox") if k in base}
    cfg = dict(keep)
    cfg["builder"] = "build_region.py (data-north 설정: north_prep.py가 north_places_*.py에서 씀)"
    cfg["meta"] = P.META
    cfg["crossings_big"] = [c for c in P.CROSSINGS if P.RIVER_CONTROL.get(c["river"], {}).get("grade") == "S"]
    cfg["landmarks"] = [dict({k: v for k, v in l.items() if k in ("id", "name", "kit", "lat", "lon", "ry", "confidence", "source", "notes", "size_m", "nopad", "road_ok", "lu")}) for l in P.LANDMARKS]
    sets = []
    for s in P.SETTLEMENTS:
        d = {k: v for k, v in s.items() if k in ("id", "name", "type", "lat", "lon", "radius_m", "size", "notes", "confidence", "source", "snap", "shape", "area_target", "min_z", "max_z")}
        if s["id"] in P.PROFILES: d["profile"] = P.PROFILES[s["id"]]
        sets.append(d)
    cfg["settlements"] = sets
    cfg["passes"] = [dict(id=q["id"], name=q["name"], lat=q["lat"], lon=q["lon"], confidence=q["confidence"], source=q.get("source", []), notes=q.get("notes", "")) for q in P.PASSES]
    cfg["crossings"] = [dict(id=c["id"], name=c["name"], type=c["type"], river_id=c["river"], **({"road_id": c["road"]} if c.get("road") else {}),
                             lat=c["lat"], lon=c["lon"], confidence=c["confidence"], notes=c.get("notes", "")) for c in P.CROSSINGS
                        if P.RIVER_CONTROL.get(c["river"], {}).get("grade") != "S"]
    roads = []
    FE = ferry_ends()
    for r in P.ROADS:
        if "fixed" in r:
            roads.append(dict(id=r["id"], name=r["name"], **{"class": r["cls"]}, width=r["width_m"], confidence=r.get("confidence", "가설"),
                              source=r.get("source", ["성문 통로를 잇는 성안 길(원칙)"]), notes=r.get("notes", ""), fixed=[ll(v) if isinstance(v, tuple) else v for v in r["fixed"]]))
            continue
        via = [ll(v) if isinstance(v, tuple) else v for v in r["via"]]
        if r.get("ferry"): via = [ll(FE[r["id"]][0]), ll(FE[r["id"]][1])]; r = dict(r, astar=False)
        if r.get("from_ferry"):
            fid, k = r["from_ferry"]; via = [ll(FE[fid][k])] + via; r = dict(r, branch_of=None, _nobranch=True)
        if r.get("to_ferry"):
            fid, k = r["to_ferry"]; via = via + [ll(FE[fid][k])]
        d = dict(id=r["id"], name=r["name"], **{"class": r["cls"]}, width=r["width_m"], confidence=r.get("confidence", "가설"),
                 source=r.get("source", ["경유점: 고증 위치(문·나루·장터) + 그 사이 A*(지형)"]), notes=r.get("notes", ""))
        if r.get("astar") is False: d["fixed"] = via
        else:
            d["via"] = via
            if r.get("branch_of"): d["branch_of"] = r["branch_of"]
            elif roads and isinstance(via[0], list) and not r.get("_nobranch"):     # 앞 길의 꼭짓점 60m(게임) 안에서 시작하면 그 길의 갈래로(간선망 잇기)
                x0_, z0_ = C.geo_to_game(*via[0]); best = None
                for q in roads:
                    for v in (q.get("fixed") or q.get("via")):
                        if not isinstance(v, list): continue
                        xq, zq = C.geo_to_game(*v); dd = math.hypot(float(xq - x0_), float(zq - z0_))
                        if dd < 60 and (best is None or dd < best[0]): best = (dd, q["id"])
                if best: d["branch_of"] = best[1]
        roads.append(d)
    cfg["roads"] = roads
    cfg["main_road"] = P.MAIN_ROAD
    cfg["naru_rivers"] = [rid for rid, r in P.RIVER_CONTROL.items() if r["grade"] in ("S", "B")]
    cfg["north"] = {}
    cfg["hydro"] = dict(known={r["name"].split("(")[0]: dict(id=rid, grade=r["grade"], flows_to=r["flows_to"]) for rid, r in P.RIVER_CONTROL.items() if r["grade"] != "S"},
                        **getattr(P, "HYDRO_EXTRA", {}))
    if lakes:   # 큰 강 = build_region의 '바다' 경로(해발 0 물면): 원 DEM 물면을 해발 −3m로 내려 둠
        cfg["coast"] = True; cfg["sea_cut_alt"] = 0.0; cfg["sea_floor_alt"] = -6.0
        cfg["hydro"]["sea_name"] = "·".join(lakes)
        cfg["climate_rule"] = dict(coast_km=0.0)
        cfg.setdefault("landuse_rules", {}).update(coast_profile_m=0.0, beach_w=10.0)
    cfg["axes"] = [dict(town=a["town"], center=ll(a["center"]), jinsan=dict(name=a["jinsan"][0], lat=a["jinsan"][1], lon=a["jinsan"][2], confidence=a["jinsan"][3], source=a.get("source", [])),
                        ansan=dict(name=a["ansan"][0], lat=a["ansan"][1], lon=a["ansan"][2], confidence=a["ansan"][3], source=a.get("source", [])), note=a.get("note", "")) for a in P.AXES]
    cfg["spawn"] = dict(ref=ll((P.SPAWN["lat"], P.SPAWN["lon"])), note=P.SPAWN["note"])
    cfg["entry"] = dict(zip(("x", "z"), [round(float(v), 1) for v in C.geo_to_game(P.SPAWN["lat"], P.SPAWN["lon"])]), note=P.SPAWN["note"])
    FE_ = ferry_ends()
    def portal_ref(p):    # 길 끝(권역 가장자리 쪽) 점 — ferry 연결 길이면 그 끝
        if p.get("ref") and not isinstance(p["ref"][0], str): return ll(tuple(p["ref"]))
        r = next(r for r in P.ROADS if r["id"] == p["road"])
        return ll(r["via"][-1]) if not r.get("to_ferry") else ll(FE_[r["to_ferry"][0]][r["to_ferry"][1]])
    cfg["portals"] = [dict(id=p["id"], name=p.get("name") or ("→ " + p["note"].split("(")[0].strip()), to="route:" + p["to_route"], to_route=p["to_route"], road=p["road"],
                           note=p["note"] + " (노정 데이터는 아직 없음 — 엔진은 '길이 아직 닦이지 않았다' 알림)", ref=portal_ref(p)) for p in P.PORTALS]
    for k in ("springs", "eupseong", "n_auto", "climate_rule", "climate_codes_expected", "zooms", "qa_alt"):
        if hasattr(P, k.upper()): cfg[k] = getattr(P, k.upper())
    if hasattr(P, "LANDUSE_RULES"): cfg["landuse_rules"] = {**P.LANDUSE_RULES, **cfg.get("landuse_rules", {})}
    cfg["north"] = dict(walls=getattr(P, "WALLS", {}), gates=[g[0] for g in getattr(P, "GATES", [])], note="north_post.py가 region.json에 walls(성곽 선)·portals 보강")
    json.dump(cfg, open(CFG_PATH, "w"), ensure_ascii=False, indent=1)
    say("설정", CFG_PATH, "landmarks", len(cfg["landmarks"]), "settlements", len(sets), "roads", len(roads), "lakes", len(lakes))

if __name__ == "__main__":
    alt = prep_dem() if "--nodem" not in sys.argv else np.load(os.path.join(C.CACHE, "dem_alt.npy"))
    lakes = prep_rivers(alt)
    write_cfg(lakes)
