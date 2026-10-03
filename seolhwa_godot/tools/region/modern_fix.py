"""현대 지형 흔적 제거(명세서 §33 금지 8, 계획서 §4.1).
- 저수지·댐 호수: OSM natural=water/water=reservoir(+landuse=reservoir) 다각형 중 1.5ha 이상 → 수면 평탄면과 둑을 지우고
  둘레 산사면에서 조화 보간한 뒤 가운데를 V자로 낮춰 옛 골짜기를 되살린다(하천 단계가 물길을 다시 판다).
- 고속도로·철도·국도 성토/절토: OSM motorway/trunk/rail(폐선 포함)/24번 국도(황산로) 따라 띠를 조화 보간으로 덮는다
  (터널 구간 제외 — 지표에 흔적 없음).
- 남겨 두는 것: 광한루원 연지(조선 정원 못), 1.5ha 미만 방죽·소류지(조선 후기 제언일 수 있음 → 보고서에 목록)."""
import json, os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage, sparse
from scipy.sparse.linalg import spsolve
import common as C

KEEP_NAMES = set(C.CFG.get("modern_keep_names", ["연지"]))
MIN_AREA_REAL_M2 = C.CFG.get("modern_min_reservoir_m2", 15000.0)
PRIMARY_NAMES = tuple(C.CFG.get("modern_primary_names", ["황산로"]))

def _poly_px(geom):
    lat = np.array([p["lat"] for p in geom]); lon = np.array([p["lon"] for p in geom])
    x, z = C.geo_to_game(lat, lon)
    i, j = C.xz_to_ij(x, z)
    return list(zip(i.tolist(), j.tolist())), x, z

def _area(x, z):
    return 0.5 * abs(np.dot(x, np.roll(z, 1)) - np.dot(z, np.roll(x, 1)))

def harmonic_fill(a, mask):
    """mask 영역을 경계값으로 라플라스 방정식 풀이(연결 성분별)."""
    out = a.copy()
    lab, n = ndimage.label(mask)
    for k, sl in enumerate(ndimage.find_objects(lab), 1):
        j0, j1 = max(sl[0].start - 1, 0), min(sl[0].stop + 1, a.shape[0])
        i0, i1 = max(sl[1].start - 1, 0), min(sl[1].stop + 1, a.shape[1])
        m = lab[j0:j1, i0:i1] == k
        sub = out[j0:j1, i0:i1]
        idx = -np.ones(m.shape, int); idx[m] = np.arange(m.sum())
        N = int(m.sum()); rows = []; cols = []; vals = []; b = np.zeros(N)
        jj, ii = np.nonzero(m)
        diag = np.zeros(N)
        for dj, di in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nj, ni = jj + dj, ii + di
            ok = (nj >= 0) & (nj < m.shape[0]) & (ni >= 0) & (ni < m.shape[1])
            diag += ok
            nj2, ni2 = nj[ok], ni[ok]; src = idx[jj[ok], ii[ok]]
            inner = m[nj2, ni2]
            rows += src[inner].tolist(); cols += idx[nj2[inner], ni2[inner]].tolist(); vals += [-1.0] * int(inner.sum())
            np.add.at(b, src[~inner], sub[nj2[~inner], ni2[~inner]])
        A = sparse.csr_matrix((vals + diag.tolist(), (rows + list(range(N)), cols + list(range(N)))), shape=(N, N))
        sub[m] = spsolve(A.tocsc(), b)
    return out

def apply(alt):
    alt = alt.astype(np.float64).copy()
    log = {"reservoirs_removed": [], "reservoirs_kept": [], "linear_removed": []}
    W, H = alt.shape[1], alt.shape[0]
    # ── 저수지
    water = json.load(open(os.path.join(C.CACHE, "osm_water.json")))
    res_mask = Image.new("L", (W, H), 0); dr = ImageDraw.Draw(res_mask)
    depth_img = np.zeros((H, W))
    dam_mask = Image.new("L", (W, H), 0); dd = ImageDraw.Draw(dam_mask)
    for e in water["elements"]:
        t = e.get("tags", {})
        if t.get("waterway") == "dam" and e.get("geometry"):
            pts, _, _ = _poly_px(e["geometry"]); dd.line(pts, fill=255, width=8)
            continue
        if not (t.get("water") == "reservoir" or t.get("landuse") == "reservoir"):
            continue
        g = e.get("geometry")
        if not g or len(g) < 3: continue
        pts, x, z = _poly_px(g)
        area_real = _area(x, z) / C.K ** 2
        lat = float(np.mean([p["lat"] for p in g])); lon = float(np.mean([p["lon"] for p in g]))
        rec = dict(name=t.get("name") or "(무명 저수지)", lat=round(lat, 5), lon=round(lon, 5),
                   x=round(float(x.mean()), 1), z=round(float(z.mean()), 1), area_ha=round(area_real / 1e4, 2))
        if rec["name"] in KEEP_NAMES or area_real < MIN_AREA_REAL_M2:
            log["reservoirs_kept"].append(rec); continue
        if not (0 <= x.mean() - C.X0 <= W * C.CELL and 0 <= z.mean() - C.Z0 <= H * C.CELL):
            continue
        dr.polygon(pts, fill=255)
        log["reservoirs_removed"].append(rec)
    m = np.asarray(res_mask) > 0
    m_d = ndimage.binary_dilation(m, iterations=5) | (ndimage.binary_dilation(np.asarray(dam_mask) > 0, iterations=3) & ndimage.binary_dilation(m, iterations=25))
    filled = harmonic_fill(alt, m_d)
    # 가운데를 V자로 낮춤: 깊이(실제 m) = clip(0.08·등가지름, 3, 14)
    lab, n = ndimage.label(m_d)
    dist = ndimage.distance_transform_edt(m_d) * C.CELL / C.K      # 실제 m
    for k in range(1, n + 1):
        mk = lab == k
        area_real = mk.sum() * (C.CELL / C.K) ** 2
        depth = float(np.clip(0.08 * 2 * np.sqrt(area_real / np.pi), 3, 14))
        dmax = dist[mk].max()
        filled[mk] -= depth * (dist[mk] / dmax) ** 0.8
    for rec in log["reservoirs_removed"]:
        i, j = C.xz_to_ij(rec["x"], rec["z"]); i = int(np.clip(i, 0, W - 1)); j = int(np.clip(j, 0, H - 1))
        rec["dem_surface_alt_m"] = round(float(alt[j, i]), 1); rec["restored_alt_m"] = round(float(filled[j, i]), 1)
    alt = filled
    # ── 선형 현대 시설
    mp = os.path.join(C.CACHE, "osm_modern.json")
    modern = json.load(open(mp)) if os.path.exists(mp) else {"elements": []}
    if not os.path.exists(mp): log["warning"] = "osm_modern.json 없음 — 선형 현대 시설 제거 생략"
    lin = Image.new("L", (W, H), 0); dl = ImageDraw.Draw(lin)
    counts = {}
    for e in modern["elements"]:
        t = e.get("tags", {}); g = e.get("geometry")
        if not g or t.get("tunnel") in ("yes", "building_passage"): continue
        hw, rw = t.get("highway"), t.get("railway")
        if hw == "motorway": wr = 45
        elif rw in ("rail", "abandoned", "disused"): wr = 30
        elif hw == "trunk" or (hw == "primary" and t.get("name") in PRIMARY_NAMES): wr = 24
        else: continue
        pts, _, _ = _poly_px(g)
        dl.line(pts, fill=255, width=max(3, int(round(wr * C.K / C.CELL))))
        key = f"{hw or 'railway:' + rw} {t.get('name') or ''}".strip()
        counts[key] = counts.get(key, 0) + 1
    lm = np.asarray(lin) > 0
    alt = harmonic_fill(alt, lm & ~ndimage.binary_dilation(m_d, iterations=2))
    log["linear_removed"] = [dict(feature=k, osm_ways=v) for k, v in sorted(counts.items())]
    log["masked_px"] = dict(reservoir=int(m_d.sum()), linear=int(lm.sum()))
    return alt.astype(np.float32), log, m_d

if __name__ == "__main__":
    import dem, time
    t = time.time()
    a, log, _ = apply(dem.build())
    np.save(os.path.join(C.CACHE, "alt_fixed.npy"), a)
    json.dump(log, open(os.path.join(C.CACHE, "modern_fix_log.json"), "w"), ensure_ascii=False, indent=1)
    print(time.time() - t, len(log["reservoirs_removed"]), len(log["reservoirs_kept"]), log["linear_removed"], log["masked_px"])
