"""설정 기반 일반 권역 빌더(data-east): tools/region/regions/<id>.json 하나로
DEM → 바다·호수 → 현대 흔적 제거 → 수계·깎기 → 길(A*, 성문 통로) → 고개·도강점 → 토지이용·마을(용천수 취락) → 기후대 → region.json.
남원(JL_NAMWON_UNBONG)은 build.py의 전용 경로를 그대로 쓴다(결과 md5 같음).
실행: python3 tools/region/build.py <권역 id>   (먼저 fetch_dem.py <id>, osm_fetch.py <id>)

설정 참조 문법(roads.via, spawn, axes 등):
  "s:<settlement id>" · "l:<landmark id>" · "p:<pass id>" · "c:<crossing id>"(양안 수직 두 점으로 펼침)
  "g:<S|N|E|W>"(성문 바깥 출구) · "gc:<S|N|E|W>"(성문 통로 중심) · "e:dx,dz"(읍성 중심 기준 게임 m)
  [lat, lon](위경도) · {"x":…, "z":…}(게임 좌표)"""
import json, math, os, sys, time
import numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw
import common as C, dem, modern_fix, hydro, roads as R, landuse as LU, export, profiles as PF

CFG = C.CFG
T0 = time.time()
def say(*a): print(f"[{time.time() - T0:6.1f}s]", *a, flush=True)

def xz(lat, lon):
    x, z = C.geo_to_game(lat, lon); return round(float(x), 1), round(float(z), 1)

def seg_intersections(a, b):
    a = np.asarray(a)[:, :2]; b = np.asarray(b)[:, :2]; out = []
    for i in range(len(a) - 1):
        p, r = a[i], a[i + 1] - a[i]
        q = b[:-1]; s = b[1:] - b[:-1]
        den = r[0] * s[:, 1] - r[1] * s[:, 0]
        ok = np.abs(den) > 1e-9
        qp = q - p
        t = np.where(ok, (qp[:, 0] * s[:, 1] - qp[:, 1] * s[:, 0]) / np.where(ok, den, 1), -1)
        u = np.where(ok, (qp[:, 0] * r[1] - qp[:, 1] * r[0]) / np.where(ok, den, 1), -1)
        for k in np.nonzero(ok & (t >= 0) & (t <= 1) & (u >= 0) & (u <= 1))[0]:
            pt = p + t[k] * r; out.append((float(pt[0]), float(pt[1]), i, int(k)))
    return out

def flatten_pads(alt, items, keep=None):
    for x, z, r in items:
        i, j = C.xz_to_ij(x, z); rr = r / C.CELL; R2 = rr + 12 / C.CELL
        j0, j1 = int(max(j - R2 - 1, 0)), int(min(j + R2 + 2, alt.shape[0])); i0, i1 = int(max(i - R2 - 1, 0)), int(min(i + R2 + 2, alt.shape[1]))
        sub = alt[j0:j1, i0:i1]
        jj, ii = np.mgrid[j0:j1, i0:i1]; d = np.hypot(ii - i, jj - j)
        core = d <= rr
        if not core.any(): continue
        target = float(np.median(sub[core]))
        w = np.clip((R2 - d) / max(R2 - rr, 1), 0, 1); w = w * w * (3 - 2 * w)
        if keep is not None: w = w * (1 - keep[j0:j1, i0:i1])
        alt[j0:j1, i0:i1] = sub * (1 - w) + target * w

def flatten_rect(alt, cx, cz, hx, hz, margin=14.0, keep=None):
    """성곽 읍치 바닥을 직사각형으로 고르게(가장자리 margin m에 걸쳐 원래 땅으로)."""
    xs, zs = C.grid_xz()
    i0, i1 = int((cx - hx - margin - C.X0) / C.CELL), int((cx + hx + margin - C.X0) / C.CELL) + 2
    j0, j1 = int((cz - hz - margin - C.Z0) / C.CELL), int((cz + hz + margin - C.Z0) / C.CELL) + 2
    sub = alt[j0:j1, i0:i1]; X, Z = np.meshgrid(xs[i0:i1], zs[j0:j1])
    dx = np.maximum(np.abs(X - cx) - hx, 0); dz = np.maximum(np.abs(Z - cz) - hz, 0); d = np.hypot(dx, dz)
    core = d == 0
    # 성 안은 완만한 평면(중앙값 + 남북 기울기 일부 유지)으로
    target = float(np.median(sub[core]))
    w = np.clip(1 - d / margin, 0, 1); w = w * w * (3 - 2 * w)
    if keep is not None: w = w * (1 - keep[j0:j1, i0:i1])          # 성 안을 흐르는 내는 그대로
    alt[j0:j1, i0:i1] = sub * (1 - w) + (0.35 * sub + 0.65 * target) * w

def road_grade(alt, roads, river_d, river_hw):
    Hh, Ww = alt.shape
    prof = np.full(alt.shape, np.nan); hwm = np.zeros(alt.shape)
    for r in roads:
        p = np.asarray(r["points"])
        seg = np.hypot(*np.diff(p, axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
        t = np.arange(0, s[-1], 1.0)
        x = np.interp(t, s, p[:, 0]); z = np.interp(t, s, p[:, 1])
        fi, fj = C.xz_to_ij(x, z)
        g = ndimage.gaussian_filter1d(C.bilinear(alt, fi, fj), 6 / C.K, mode="nearest")
        i = np.clip(np.round(fi).astype(int), 0, Ww - 1); j = np.clip(np.round(fj).astype(int), 0, Hh - 1)
        prof[j, i] = g; hwm[j, i] = r["width_m"] / 2
    has = ~np.isnan(prof)
    d, (nj, ni) = ndimage.distance_transform_edt(~has, return_indices=True)
    d = d * C.CELL; P_ = prof[nj, ni]; HW = hwm[nj, ni]
    w = np.clip(1 - (d - HW - 0.5) / 4.0, 0, 1); w = w * w * (3 - 2 * w)
    w[(river_d <= river_hw + 3)] = 0
    return alt * (1 - w) + P_ * w

def poly_mask(polys, shape, cell):
    im = Image.new("L", (shape[1], shape[0]), 0); d = ImageDraw.Draw(im)
    for pl in polys:
        i, j = C.xz_to_ij(np.asarray([p[0] for p in pl]), np.asarray([p[1] for p in pl]), cell)
        if len(pl) >= 3: d.polygon(list(zip(i.tolist(), j.tolist())), fill=255)
    return np.asarray(im) > 0

# ── 바다·호수
def sea_and_lakes(alt0):
    """바다: 해발 ≤ sea_level 칸 중 지도 가장자리에 닿은 덩어리(호수 다각형 제외). 호수: 설정 lakes 이름의 OSM natural=water 다각형."""
    lakes = []
    keep = CFG.get("lakes", [])
    if keep:
        water = json.load(open(os.path.join(C.CACHE, "osm_water.json")))
        for e in water["elements"]:
            nm = e.get("tags", {}).get("name")
            spec = next((l for l in keep if l["osm_name"] == nm), None)
            if not spec: continue
            rings = []
            if e.get("geometry"): rings = [e["geometry"]]
            for m in e.get("members", []):
                if m.get("role") == "outer" and m.get("geometry"): rings.append(m["geometry"])
            for g in rings:
                x, z = C.geo_to_game(np.array([p["lat"] for p in g]), np.array([p["lon"] for p in g]))
                lakes.append(dict(spec, outline=[[round(float(a), 1), round(float(b), 1)] for a, b in zip(x, z)]))
    lake_m = poly_mask([l["outline"] for l in lakes], alt0.shape, C.CELL) if lakes else np.zeros(alt0.shape, bool)
    if not CFG.get("coast"):
        return np.zeros(alt0.shape, bool), lake_m, lakes
    low = (ndimage.gaussian_filter(alt0, 1.5) <= CFG.get("sea_cut_alt", 0.5)) & ~ndimage.binary_dilation(lake_m, iterations=6)
    lab, n = ndimage.label(low)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    sizes = ndimage.sum(np.ones_like(low), lab, range(1, n + 1))
    keepl = [k for k in edge if k > 0 and sizes[k - 1] > 20000]
    sea = np.isin(lab, keepl)
    sea = ndimage.binary_closing(ndimage.binary_opening(sea, iterations=2), iterations=3) & (ndimage.gaussian_filter(alt0, 1.5) <= 2.0)
    return sea, lake_m, lakes

class Ref:
    """설정 참조 → 게임 좌표."""
    def __init__(self):
        self.S, self.L, self.P, self.D, self.gate, self.eup = {}, {}, {}, {}, {}, None
    def __call__(self, r):
        if isinstance(r, dict): return (float(r["x"]), float(r["z"]))
        if isinstance(r, (list, tuple)): return xz(r[0], r[1])
        k, v = r.split(":", 1)
        if k == "s": return (self.S[v]["x"], self.S[v]["z"])
        if k == "l": return (self.L[v]["x"], self.L[v]["z"])
        if k == "p": return (self.P[v]["x"], self.P[v]["z"])
        if k == "c": return tuple(self.D[v]["pos"])
        if k == "g": return self.gate[v][-1]
        if k == "gc": return self.gate[v][1]
        if k == "e":
            dx, dz = [float(t) for t in v.split(",")]; return (round(self.eup[0] + dx, 1), round(self.eup[1] + dz, 1))
        raise KeyError(r)

def main():
    say("DEM", C.REGION_ID)
    alt0 = dem.build()
    sea, lake_m, lakes = sea_and_lakes(alt0)
    alt0 = ndimage.gaussian_filter(alt0, 1.0)
    if sea.any():
        sf = CFG.get("sea_floor_alt", -20.0)
        alt0 = np.where(sea, np.clip(np.minimum(alt0, -1.5), sf, None), np.maximum(alt0, 0.6))   # 뭍은 바다 수면 위
    if lake_m.any():
        for l in lakes:
            m_ = poly_mask([l["outline"]], alt0.shape, C.CELL)
            alt0[m_] = np.minimum(alt0[m_], l["surface_alt"] - 1.2 - 1.5 * ndimage.distance_transform_edt(m_)[m_].clip(0, 30) / 30)
    oreums = oreum_boost(alt0, sea) if CFG.get("oreum") else []
    np.save(os.path.join(C.CACHE, "sea.npy"), sea)
    say("sea", round(float(sea.mean()), 3), "lakes", len(lakes))
    say("현대 흔적 제거")
    alt1, mlog, res_mask = modern_fix.apply(alt0)
    alt1 = np.where(sea, alt0, alt1)
    say("수계")
    rivers, alt2, hlog = hydro.run(alt1, sea if sea.any() else None)
    acc, dirn = hlog.pop("acc"), hlog.pop("dirn"); hlog.pop("filled")
    alt2 = np.where(sea, np.minimum(alt2, alt1), alt2)
    if sea.any():   # 바닷가를 따라 기는 짧은 물길(해안 저지 격자 흔적)은 뺀다 — 자식 없는 이름 없는 내만
        sdist = ndimage.distance_transform_edt(~sea) * C.CELL
        parents_ = {r["parent"] for r in rivers if r.get("parent")}
        drop = []
        for r in rivers:
            p_ = np.asarray(r["points"]); near = C.bilinear(sdist, *C.xz_to_ij(p_[:, 0], p_[:, 1])) < 60
            if r["id"] not in parents_ and r["id"].startswith("r") and near.mean() > 0.4: drop.append(r["id"])
        rivers = [r for r in rivers if r["id"] not in drop]
        hlog["counts"] = {g: sum(1 for r in rivers if r["grade"] == g) for g in "BCD"}; hlog["dropped_coastal"] = drop
        say("바닷가 기는 물길 뺌", len(drop))
    for r in rivers: r["reaches"] = river_reaches(r, rivers)
    riv = {r["id"]: r for r in rivers}
    say("rivers", hlog["counts"], [r["id"] for r in rivers if not r["id"].startswith("r")])

    ref = Ref()
    # ── 고증 위치
    lms = []
    for l in CFG.get("landmarks", []):
        x, z = (l["xz"] if l.get("xz") else xz(l["lat"], l["lon"]))
        d = dict(id=l["id"], name=l["name"], kit=l["kit"], x=x, z=z, ry=l.get("ry", 0), confidence=l["confidence"],
                 source=l.get("source", []), notes=l.get("notes", ""), size_m=l.get("size_m"))
        if "lat" in l: d.update(lat=round(l["lat"], 5), lon=round(l["lon"], 5))
        lms.append(d)
    L = ref.L = {l["id"]: l for l in lms}
    sets = []
    for s in CFG.get("settlements", []):
        x, z = (s["xz"] if s.get("xz") else xz(s["lat"], s["lon"]))
        d = dict(id=s["id"], name=s["name"], type=s["type"], x=x, z=z, radius_m=s.get("radius_m", 40), size=s.get("size", "S"),
                 notes=s.get("notes", ""), confidence=s["confidence"], source=s.get("source", []))
        if "lat" in s: d.update(lat=round(s["lat"], 5), lon=round(s["lon"], 5))
        for k_ in ("area_target", "min_z", "max_z"):
            if k_ in s: d[k_] = s[k_]
        d["_snap"] = s.get("snap", 0); d["_shape"] = s.get("shape"); d["_profile"] = s.get("profile")
        sets.append(d)
    S = ref.S = {s["id"]: s for s in sets}
    ec = CFG.get("eupseong")
    if ec:
        E = L[ec["landmark"]]; ref.eup = (E["x"], E["z"])
        hx_, hz_ = ec.get("half_x", ec["half"]), ec["half"]
        S[ec["settlement"]]["core"] = [E["x"] - hx_, E["z"] - hz_, E["x"] + hx_, E["z"] + hz_]
        S[ec["settlement"]]["core_max"] = ec.get("core_max", 100.0)

    # 2m 하천 거리
    surf2 = np.zeros(alt2.shape, bool); hw2 = np.zeros(alt2.shape); sv2 = np.zeros(alt2.shape)
    for r in rivers:
        p = np.array(r["points"]); seg = np.hypot(*np.diff(p[:, :2], axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
        t = np.arange(0, s[-1], 1.0); x = np.interp(t, s, p[:, 0]); z = np.interp(t, s, p[:, 1])
        i, j = C.xz_to_ij(x, z); i = np.clip(np.round(i).astype(int), 0, alt2.shape[1] - 1); j = np.clip(np.round(j).astype(int), 0, alt2.shape[0] - 1)
        surf2[j, i] = True; hw2[j, i] = np.maximum(hw2[j, i], r["width_m"] / 2)
        sv2[j, i] = np.interp(t, s, p[:, 2])
    if not surf2.any(): surf2[0, 0] = True
    d2, (nj, ni) = ndimage.distance_transform_edt(~surf2, return_indices=True)
    d2 = d2 * C.CELL; HW2 = hw2[nj, ni]; SV2 = sv2[nj, ni]
    river_keep = np.clip(1 - (d2 - HW2 - 3) / 8.0, 0, 1)
    sea_d2 = ndimage.distance_transform_edt(~sea) * C.CELL if sea.any() else np.full(alt2.shape, 1e9)
    wet2 = sea | lake_m
    # 마을 자리 보정(설정 snap m 안에서 완경사·골 바닥·물가 아님)
    yy = C.alt_to_y(alt2); gz_, gx_ = np.gradient(ndimage.uniform_filter(yy, 5), C.CELL); slp = np.hypot(gx_, gz_)
    for s_ in sets:
        R_ = int(s_.pop("_snap") / C.CELL)
        if R_ <= 0: continue
        i, j = [int(round(float(v))) for v in C.xz_to_ij(s_["x"], s_["z"])]
        j0, j1, i0, i1 = max(j - R_, 0), min(j + R_ + 1, yy.shape[0]), max(i - R_, 0), min(i + R_ + 1, yy.shape[1])
        jj, ii = np.mgrid[j0:j1, i0:i1]; dd = np.hypot(ii - i, jj - j) * C.CELL
        sub = yy[j0:j1, i0:i1]; low = np.percentile(sub, 5)
        sc = 10 * slp[j0:j1, i0:i1] + dd / (R_ * C.CELL) + np.clip((sub - low) / (30 * C.K), 0, 3)
        sc[(d2[j0:j1, i0:i1] < HW2[j0:j1, i0:i1] + 12) | (dd > R_ * C.CELL) | (sea_d2[j0:j1, i0:i1] < 25) | lake_m[j0:j1, i0:i1]] = 99
        k = np.unravel_index(np.argmin(sc), sc.shape); nx, nz = C.ij_to_xz(ii[k], jj[k])
        moved = math.hypot(nx - s_["x"], nz - s_["z"])
        if moved > 20 and sc[k] < 99:
            s_["notes"] = (s_["notes"] + " " if s_["notes"] else "") + f"[입지 보정: 원 좌표에서 {moved:.0f}m(게임) 옮김 — 완경사·물가 아님]"
            s_["x"], s_["z"] = round(float(nx), 1), round(float(nz), 1)
    pads = [(l["x"], l["z"], 0.5 * max(l["size_m"]) * 0.9) for l in lms if l.get("size_m") and max(l["size_m"]) < 130 and not l.get("nopad")
            and not (ec and l["id"] == ec["landmark"]) and not CFG_L(l["id"]).get("nopad")]
    flatten_pads(alt2, pads, river_keep)
    if ec: flatten_rect(alt2, E["x"], E["z"], hx_, hz_, keep=river_keep)
    alt2 = np.where(sea, np.minimum(alt2, -1.5), alt2)

    # ── 고개(지정)
    passes = []
    for q in CFG.get("passes", []):
        x, z = xz(q["lat"], q["lon"]) if "lat" in q else tuple(q["xz"])
        passes.append(dict(id=q["id"], name=q["name"], x=x, z=z, y=None, confidence=q["confidence"], source=q.get("source", []), notes=q.get("notes", "")))
    ref.P = {q["id"]: q for q in passes}
    # ── 도강점(지정) — 하천선 위 가장 가까운 점
    designated = []
    for c in CFG.get("crossings", []):
        if c["river_id"] not in riv: say("  지정 도강점 하천 없음", c["id"], c["river_id"]); continue
        x, z = xz(c["lat"], c["lon"]); p = np.asarray(riv[c["river_id"]]["points"])[:, :2]
        k = int(np.argmin(np.hypot(p[:, 0] - x, p[:, 1] - z)))
        designated.append(dict(c, pos=(float(p[k, 0]), float(p[k, 1]))))
    ref.D = {c["id"]: c for c in designated}
    # ── 성문 통로(정사각 성벽: 문 중심 = 변 중앙, 통로 = 성 안 6m → 문 → 바깥 14m)
    if ec:
        def gpath(side):
            ux, uz = {"S": (0, 1), "N": (0, -1), "E": (1, 0), "W": (-1, 0)}[side]
            h = hz_ if side in "SN" else hx_
            gc = (E["x"] + ux * (h - 2.3), E["z"] + uz * (h - 2.3))
            return [(round(gc[0] - ux * 8, 1), round(gc[1] - uz * 8, 1)), (round(gc[0], 1), round(gc[1], 1)), (round(gc[0] + ux * 14, 1), round(gc[1] + uz * 14, 1))]
        ref.gate = {g: gpath(g) for g in ec.get("gates", "SNEW")}

    # ── 도로
    say("도로 A*")
    y4 = C.alt_to_y(alt2[::2, ::2])
    wm = R.river_masks(rivers, y4.shape)
    cost, slope4 = R.cost_field(y4, wm, [c["pos"] for c in designated])
    base_c = cost[0].copy()
    xs4_, zs4_ = C.ij_to_xz(*np.meshgrid(np.arange(base_c.shape[1]), np.arange(base_c.shape[0])), C.LU_CELL)
    wet4 = wet2[::2, ::2][:base_c.shape[0], :base_c.shape[1]]
    base_c[wet4] += 5000.0
    base_c[ndimage.binary_dilation(wet4, iterations=2) & ~wet4] += 8.0           # 물가 바로 옆은 조금 비싸게(파도·갯바위)
    for l_ in lms:
        if not l_.get("size_m") or max(l_["size_m"]) < 30 or (ec and l_["id"] == ec["landmark"]) or CFG_L(l_["id"]).get("road_ok"): continue
        m_ = (np.abs(xs4_ - l_["x"]) <= l_["size_m"][0] / 2 + 4) & (np.abs(zs4_ - l_["z"]) <= l_["size_m"][1] / 2 + 4)
        base_c[m_] += 60.0
    if ec:   # 성벽: 문 밖에서는 못 지나감
        on_wall = (np.abs(np.maximum(np.abs(xs4_ - E["x"]) - hx_, np.abs(zs4_ - E["z"]) - hz_)) <= 6)
        for g in ref.gate.values():
            on_wall &= np.hypot(xs4_ - g[1][0], zs4_ - g[1][1]) > 10
        base_c[on_wall] += 3000.0
    cost = (base_c, cost[1])
    def ford_pair(cid, prev):
        c_ = ref.D[cid]; rp = np.asarray(riv[c_["river_id"]]["points"]); pos = np.asarray(c_["pos"])
        k = int(np.argmin(np.hypot(rp[:, 0] - pos[0], rp[:, 1] - pos[1])))
        t = rp[min(k + 2, len(rp) - 1), :2] - rp[max(k - 2, 0), :2]; t = t / (np.linalg.norm(t) + 1e-9)
        n = np.array([-t[1], t[0]]); off = riv[c_["river_id"]]["width_m"] / 2 + 7.0
        a_, b_ = tuple(pos + n * off), tuple(pos - n * off)
        if prev is not None and math.hypot(b_[0] - prev[0], b_[1] - prev[1]) < math.hypot(a_[0] - prev[0], a_[1] - prev[1]): a_, b_ = b_, a_
        return [a_, tuple(pos), b_]
    RI = R.river_index(rivers) if rivers else None
    roads = []
    for rd in CFG.get("roads", []):
        if rd.get("fixed"):
            pts = np.asarray([ref(v) for v in rd["fixed"]], float)
        else:
            wps = []
            for v in rd["via"]:
                if isinstance(v, str) and v.startswith("c:"): wps += ford_pair(v[2:], wps[-1] if wps else None)
                else: wps.append(ref(v))
            prefix = None
            if isinstance(rd["via"][0], str) and rd["via"][0].startswith("g:"):
                prefix = ref.gate[rd["via"][0][2:]]
            if rd.get("branch_of"):
                main = np.asarray(next(r for r in roads if r["id"] == rd["branch_of"])["points"])
                d_ = np.hypot(main[:, 0] - wps[0][0], main[:, 1] - wps[0][1]); d_[d_ < 25] = 1e9; k_ = int(np.argmin(d_))
                wps = [tuple(main[k_])] + list(wps)
            pts = R.route(cost, wps)
            if RI is not None:
                pts, nch = R.fix_water_runs(pts, RI)
                if nch: say("  물길 따라 걷던", nch, "m 고침", rd["id"])
            pts = R.remove_loops(pts)
            if prefix: pts = np.vstack([np.asarray(prefix[:-1], float), pts])
            if rd.get("suffix_gate"):
                pts = np.vstack([pts, np.asarray(ref.gate[rd["suffix_gate"]][::-1][1:], float)])
        roads.append(dict(id=rd["id"], name=rd["name"], **{"class": rd["class"]}, width_m=rd["width"],
                          points=[[round(float(p[0]), 1), round(float(p[1]), 1)] for p in pts],
                          confidence=rd["confidence"], source=rd.get("source", []), notes=rd.get("notes", "")))
        say("road", rd["id"], len(pts))

    # ── 도강점: 도로×하천 교차 전부
    crossings = []; hits = []
    naru = set(CFG.get("naru_rivers", []))
    for rd in roads:
        for r in rivers:
            for (x, z, ia, ib) in seg_intersections(rd["points"], r["points"]):
                des = None
                for c in designated:
                    if c["river_id"] == r["id"] and c.get("road_id", rd["id"]) == rd["id"] and math.hypot(c["pos"][0] - x, c["pos"][1] - z) < 40: des = c
                hits.append((rd, r, x, z, des))
    hits.sort(key=lambda h_: h_[4] is None)
    for rd, r, x, z, des in hits:
        near_c = [c for c in crossings if c["river_id"] == r["id"] and math.hypot(c["x"] - x, c["z"] - z) < 12]
        if near_c:
            if near_c[0]["road_id"] != rd["id"]: near_c[0].setdefault("shared_roads", []).append(rd["id"])
            continue
        if des and any(c["id"] == des["id"] for c in crossings):
            n_same = sum(1 for c in crossings if c["id"].startswith(des["id"]))
            crossings.append(dict(id=f"{des['id']}_{n_same + 1}", name=des["name"] + f" ({n_same + 1})", type=des["type"], river_id=r["id"], road_id=rd["id"],
                                  x=round(x, 1), z=round(z, 1), confidence=des["confidence"], notes="같은 건널목 근처에서 굽이를 한 번 더 건넘"))
        elif des:
            crossings.append(dict(id=des["id"], name=des["name"], type=des["type"], river_id=r["id"], road_id=rd["id"],
                                  x=round(x, 1), z=round(z, 1), confidence=des["confidence"], notes=des.get("notes", "")))
        else:
            typ = {"S": "나루", "A": "나루", "B": "나루" if r["id"] in naru else "섶다리", "C": "징검다리", "D": "여울"}[r["grade"]]
            if r["grade"] == "D" and rd["class"] == "대로": typ = "돌다리"
            if CFG.get("dry_streams") and r["grade"] in "CD": typ = "돌다리" if rd["class"] in ("대로", "지선") else "징검다리"
            crossings.append(dict(id=f"x_{rd['id'][:10]}_{r['id']}_{len(crossings)}", name=f"{r['name']} 건널목", type=typ,
                                  river_id=r["id"], road_id=rd["id"], x=round(x, 1), z=round(z, 1), confidence="가설",
                                  notes="자동: 등급별 기본 형식(B=나루/섶다리, C=징검다리, D=여울/대로는 돌다리" + (", 건천은 돌다리·징검다리" if CFG.get("dry_streams") else "") + ") — 가설"))
    missing = [c["id"] for c in designated if not any(x["id"] == c["id"] for x in crossings)]

    say("길 바닥")
    y2 = C.alt_to_y(alt2).astype(np.float64)
    y2 = road_grade(y2, roads, d2, HW2)
    y2 = np.where(sea, np.minimum(y2, C.alt_to_y(-1.5)), y2)

    # ── 고개: 지정 + 도로 단면 고점
    hy2 = lambda x, z: C.bilinear(y2, *C.xz_to_ij(np.asarray(x), np.asarray(z)))
    _dr4 = ndimage.distance_transform_edt(~(wm["B"] | wm["C"] | wm["D"] | wet4)) * C.LU_CELL
    rdist4 = lambda x, z: C.bilinear(_dr4, *C.xz_to_ij(np.asarray(x), np.asarray(z), C.LU_CELL))
    for rd in roads:
        for (px, pz, ph) in R.profile_peaks(rd["points"], hy2, prom_real=35.0, rdist=rdist4):
            if any(math.hypot(q["x"] - px, q["z"] - pz) < 260 for q in passes): continue
            passes.append(dict(id=f"pass_{rd['id'][:12]}_{len(passes)}", name="무명 고개", x=round(px, 1), z=round(pz, 1), y=None,
                               confidence="가설", source=["도로 고도 단면의 안장(자동)"], notes=f"{rd['name']} 위"))
    for q in passes:
        q["y"] = round(float(hy2(q["x"], q["z"])), 2)

    # ── 토지이용 + 마을
    say("토지이용")
    y4 = y2[::2, ::2]
    sea4 = sea[::2, ::2]; lake4 = lake_m[::2, ::2]; wet4 = sea4 | lake4
    sea_d4 = ndimage.distance_transform_edt(~sea4) * C.LU_CELL if sea4.any() else np.full(y4.shape, 1e9)
    for s_ in sets:
        shp = s_.pop("_shape", None)
        if shp:
            s_["_shape"] = dict(shp)
            if shp.get("toward"): s_["_shape"]["toward"] = ref(shp["toward"])
    lr = CFG.get("landuse_rules", {})
    avoid4 = wet4 | (sea_d4 < lr.get("shore_gap", 10.0))
    n_auto = CFG.get("n_auto", 8)
    lu, autos, info = LU.classify(y4, rivers, roads, sets, n_auto=0 if lr.get("auto_mode") == "spring" else n_auto, avoid=avoid4, auto_gap=lr.get("auto_gap", 450.0))
    for s_ in sets: s_.pop("_shape", None)
    springs = []
    if lr.get("auto_mode") == "spring":
        # 용천수 취락(탐라): 해안 띠(바다에서 40~320m, 해발 40m 아래, 완경사)에서 샘 자리를 골라 간격 두고 마을 후보
        gz4, gx4 = np.gradient(y4, C.LU_CELL); sl4 = np.hypot(gx4, gz4)
        alt4 = C.y_to_alt(y4)
        band = (sea_d4 > 40) & (sea_d4 < lr.get("spring_band", 320.0)) & (alt4 < 40) & (ndimage.uniform_filter(sl4, 5) < 0.12) & ~lake4
        nz_ = LU.hash01(*np.meshgrid(np.arange(y4.shape[1]) // 5, np.arange(y4.shape[0]) // 5), 11)
        score = np.where(band, 1.0 - sea_d4 / 400.0 + 0.4 * nz_ - ndimage.uniform_filter(sl4, 5) * 3, -9)
        taken = [(s["x"], s["z"]) for s in sets]
        xs4, zs4 = C.ij_to_xz(*np.meshgrid(np.arange(y4.shape[1]), np.arange(y4.shape[0])), C.LU_CELL)
        for idx in np.argsort(-score, axis=None)[:400000]:
            if score.flat[idx] < 0 or len(autos) >= n_auto: break
            x, z = float(xs4.flat[idx]), float(zs4.flat[idx])
            if abs(x) > -C.X0 - 120 or abs(z) > -C.Z0 - 100: continue
            if all(math.hypot(x - a, z - b) > lr.get("auto_gap", 650.0) for a, b in taken):
                taken.append((x, z)); autos.append((x, z))
    # 명세 v0.3 §36 Q7: 마을이 B·C급 하천 범람지(수면 위 실제 2.5m 미만)에 있으면 150m(게임) 안 마른 땅으로 옮기고 다시 칠한다
    drf, rsf, _, rgf = LU.river_fields(rivers, y4.shape) if rivers else (None,) * 4
    moved_any = False
    gz4m, gx4m = np.gradient(y4, C.LU_CELL); sl4m = ndimage.uniform_filter(np.hypot(gx4m, gz4m), 3)
    def dry_fix(o):
        nonlocal moved_any
        if drf is None or o["type"] in ("성황당", "사찰", "읍성"): return
        i_, j_ = [int(round(float(v))) for v in C.xz_to_ij(o["x"], o["z"], C.LU_CELL)]
        hand_ = lambda jj_, ii_: (y4[jj_, ii_] - rsf[jj_, ii_]) / C.K
        bad_ = lambda jj_, ii_: (drf[jj_, ii_] < 150) & (rgf[jj_, ii_] >= 2) & (hand_(jj_, ii_) < 4.0)
        if not bad_(j_, i_): return
        R_ = int(150 / C.LU_CELL)
        jj_, ii_ = np.mgrid[max(j_ - R_, 0):min(j_ + R_ + 1, y4.shape[0]), max(i_ - R_, 0):min(i_ + R_ + 1, y4.shape[1])]
        ok_ = ~bad_(jj_, ii_) & (sl4m[jj_, ii_] < 0.15) & ~avoid4[jj_, ii_] & (drf[jj_, ii_] > 12)
        if not ok_.any(): return
        dd_ = np.where(ok_, np.hypot(jj_ - j_, ii_ - i_), 1e9); k_ = np.unravel_index(np.argmin(dd_), dd_.shape)
        nx_, nz_ = C.ij_to_xz(ii_[k_], jj_[k_], C.LU_CELL)
        o["notes"] = (o.get("notes", "") + " " if o.get("notes") else "") + f"[범람지 피함: 하천 수면 위 실제 2.5m 넘는 곳으로 {dd_[k_] * C.LU_CELL:.0f}m(게임) 옮김]"
        o["x"], o["z"] = round(float(nx_), 1), round(float(nz_), 1); moved_any = True
    for s_ in sets: dry_fix(s_)
    autos_d = [dict(id=f"auto_village_{n:02d}", name="", type="마을", x=x, z=z, size="S", area_target=4500.0) for n, (x, z) in enumerate(autos)]
    for a_ in autos_d: dry_fix(a_)
    autos = [(a_["x"], a_["z"]) for a_ in autos_d]
    if lr.get("auto_mode") == "spring" or moved_any:
        for s_ in sets:
            shp = next((q.get("shape") for q in CFG.get("settlements", []) if q["id"] == s_["id"]), None)
            if shp: s_["_shape"] = dict(shp, **({"toward": ref(shp["toward"])} if shp.get("toward") else {}))
        lu, _, info = LU.classify(y4, rivers, roads, sets + autos_d, n_auto=0, avoid=avoid4)
        for s_ in sets: s_.pop("_shape", None)
    for n, (x, z) in enumerate(autos):
        sets.append(dict(id=f"auto_village_{n:02d}", name=(f"용천수 마을 후보 {n + 1}" if lr.get("auto_mode") == "spring" else f"들마을 후보 {n + 1}"), type="마을",
                         x=round(x, 1), z=round(z, 1), radius_m=32, size="S",
                         notes=("용천수 취락 규칙(해안 띠·저지대·완경사, 샘 자리 둘레) 자동 후보" if lr.get("auto_mode") == "spring" else "입지 규칙(산기슭·남향·아래 논) 자동 후보"),
                         confidence="가설", source=["명세서 §24 입지 규칙(자동)" + (" — 탐라 용천수 취락" if lr.get("auto_mode") == "spring" else "")]))
    for s_ in sets:
        sh = info["shapes"].get(s_["id"])
        if sh:
            s_["area_m2"] = sh["area_m2"]; s_["extent_m"] = sh["extent_m"]; s_["bbox"] = sh["bbox"]
            s_["radius_m"] = round(math.sqrt(sh["area_m2"] / math.pi), 1)
    # 용천수: 설정 springs + 해안 마을마다 가장 가까운 해안선 안쪽 25m(게임)
    if sea.any():
        coast = sea4 & ~ndimage.binary_erosion(sea4)
        cj, ci = np.nonzero(coast); cx_, cz_ = C.ij_to_xz(ci, cj, C.LU_CELL)
        for s_ in sets:
            want = lr.get("auto_mode") == "spring" and (s_["id"].startswith("auto_village") or (s_.get("_profile") or {}).get("archetype") in ("island", "coast"))
            if not want or not len(cx_): continue
            d_ = np.hypot(cx_ - s_["x"], cz_ - s_["z"]); k = int(np.argmin(d_))
            if d_[k] > 600: continue
            ux, uz = (s_["x"] - cx_[k]) / (d_[k] + 1e-9), (s_["z"] - cz_[k]) / (d_[k] + 1e-9)
            px, pz = cx_[k] + ux * 25, cz_[k] + uz * 25
            springs.append(dict(id=f"spring_{s_['id']}", name=f"{s_['name'].split('(')[0].strip()} 용천수", x=round(float(px), 1), z=round(float(pz), 1),
                                settlement=s_["id"], confidence="가설", notes="해안 용천수(산물) — 마을 공동 물터·빨래터. 바다에서 25m(게임) 안쪽 가장 가까운 해안"))
    for sp in CFG.get("springs", []):
        x, z = xz(sp["lat"], sp["lon"])
        springs.append(dict(id=sp["id"], name=sp["name"], x=x, z=z, settlement=sp.get("settlement"), confidence=sp["confidence"], notes=sp.get("notes", ""), source=sp.get("source", [])))
    # 토지이용 지역 규칙
    gz4, gx4 = np.gradient(y4, C.LU_CELL); sl4 = np.hypot(gx4, gz4); alt4 = C.y_to_alt(y4)
    nz4 = LU.hash01(*np.meshgrid(np.arange(y4.shape[1]) // 6, np.arange(y4.shape[0]) // 6), 5)
    if lr.get("no_paddy"):
        lu[lu == LU.PADDY] = LU.FIELD          # 논 대신 밭(탐라: 물 빠짐이 빠른 화산회토)
    if lr.get("field_alt"):                     # 해안 저지대 완경사 숲 → 돌담 밭
        lo_, hi_ = lr["field_alt"]
        lu[(lu == LU.FOREST) & (alt4 >= lo_) & (alt4 < hi_) & (sl4 < 0.10) & (nz4 < 0.85)] = LU.FIELD
    if lr.get("grass_alt"):                     # 중산간 목장(초지)
        lo_, hi_ = lr["grass_alt"]
        lu[(lu == LU.FOREST) & (alt4 >= lo_) & (alt4 < hi_) & (sl4 < 0.18) & (nz4 < 0.8)] = LU.GRASS
    if sea4.any():
        shore = ~wet4 & (sea_d4 <= lr.get("beach_w", 12.0)) & (sl4 < 0.25)
        if lr.get("rocky_coast"):
            lu[shore & (nz4 < 0.75)] = LU.ROCK; lu[shore & (nz4 >= 0.75)] = LU.SAND
        else:
            lu[shore & (sl4 < 0.12)] = LU.SAND; lu[shore & (sl4 >= 0.12)] = LU.ROCK
        for b in lr.get("sand_beaches", []):     # 이름난 모래 해변 [lat, lon, 반경 게임 m]
            bx, bz = xz(b[0], b[1]); xs4, zs4 = C.ij_to_xz(*np.meshgrid(np.arange(y4.shape[1]), np.arange(y4.shape[0])), C.LU_CELL)
            lu[~wet4 & (sea_d4 <= 40) & (np.hypot(xs4 - bx, zs4 - bz) < b[2])] = LU.SAND
    lu[wet4] = LU.WATER
    # 랜드마크 바닥
    jj4, ii4 = np.mgrid[0:lu.shape[0], 0:lu.shape[1]]; xs4, zs4 = C.ij_to_xz(ii4, jj4, C.LU_CELL)
    for l in lms:
        if not l.get("size_m") or (ec and l["id"] == ec["landmark"]): continue
        cls_ = {"grass": LU.GRASS, "forest": LU.FOREST, "village": LU.VILLAGE, "road": LU.ROAD, "keep": None}[CFG_L(l["id"]).get("lu", "village")]
        if cls_ is None: continue
        hx, hz = l["size_m"][0] / 2 + 4, l["size_m"][1] / 2 + 4
        m = (np.abs(xs4 - l["x"]) <= hx) & (np.abs(zs4 - l["z"]) <= hz) & (lu != LU.WATER)
        lu[m] = cls_
    flatten_alt = C.y_to_alt(y2)
    # 자동 마을 바닥 고르기는 하지 않는다(배치 로더 flatten이 함 — 범람지 쪽으로 내려앉지 않게)
    y2 = np.where(sea, y2, C.alt_to_y(flatten_alt))

    # ── 길 둑·길 칸(QR·QL) — build.py와 같은 규칙
    def road_mask(cell, extra=0.0):
        Hm, Wm = int(round(-2 * C.Z0 / cell)) + 1, int(round(-2 * C.X0 / cell)) + 1
        im_ = Image.new("L", (Wm, Hm), 0); dd_ = ImageDraw.Draw(im_)
        for r_ in roads:
            p_ = np.asarray(r_["points"]); i_, j_ = C.xz_to_ij(p_[:, 0], p_[:, 1], cell)
            dd_.line(list(zip(i_.tolist(), j_.tolist())), fill=255, width=max(1, int(round((r_["width_m"] + extra) / cell))))
        return np.asarray(im_) > 0
    def cross_zone(cell, rad=10.0):
        Hm, Wm = int(round(-2 * C.Z0 / cell)) + 1, int(round(-2 * C.X0 / cell)) + 1
        im_ = Image.new("L", (Wm, Hm), 0); dd_ = ImageDraw.Draw(im_)
        for c_ in crossings:
            i_, j_ = C.xz_to_ij(c_["x"], c_["z"], cell); rr_ = rad / cell
            dd_.ellipse([i_ - rr_, j_ - rr_, i_ + rr_, j_ + rr_], fill=255)
        return np.asarray(im_) > 0
    n_fix = n_last = 0
    if rivers:
        rm2w = road_mask(C.CELL, 4.0); cz2 = cross_zone(C.CELL, 8.0)
        near_r = d2 <= HW2 + 12.0
        fix = rm2w & ~cz2 & near_r & (d2 > HW2) & (y2 < SV2 + 0.35)
        n_fix = int(fix.sum())
        y2 = np.where(fix, SV2 + 0.35, y2)
        y2 = np.where(ndimage.binary_dilation(fix, iterations=2) & ~fix, ndimage.uniform_filter(y2, 3), y2)
        drq, rsq, rhwq, _ = LU.river_fields(rivers, y2.shape, G=C.CELL)
        rmap = {r_["id"]: r_ for r_ in rivers}
        for r_ in roads:
            p_ = np.asarray(r_["points"], float); sg_ = np.hypot(*np.diff(p_, axis=0).T); ss_ = np.concatenate([[0], np.cumsum(sg_)])
            tt_ = np.arange(0, ss_[-1] + 1e-6, 1.0)
            for x_, z_ in zip(np.interp(tt_, ss_, p_[:, 0]), np.interp(tt_, ss_, p_[:, 1])):
                if any(math.hypot(c_["x"] - x_, c_["z"] - z_) <= max(rmap[c_["river_id"]]["width_m"], 5.2) / 2 + 4.0 for c_ in crossings): continue
                i_, j_ = C.xz_to_ij(x_, z_); i_ = int(round(float(i_))); j_ = int(round(float(j_)))
                if drq[j_, i_] > max(rhwq[j_, i_], 2.6) + 5: continue
                need = rsq[j_, i_] + 0.35
                sl_ = (slice(max(j_ - 1, 0), j_ + 2), slice(max(i_ - 1, 0), i_ + 2))
                blk = y2[sl_]; inch = d2[sl_] <= HW2[sl_]
                upd = (blk < need) & ~inch
                if upd.any(): blk[upd] = need; n_last += int(upd.sum())
    # 길이 바닷가 칸에 닿으면 바다 수면 위로
    rm2 = road_mask(C.CELL, 2.0)
    low_rd = rm2 & (y2 < C.alt_to_y(0.6))
    y2 = np.where(low_rd, C.alt_to_y(0.6), y2)
    cz4 = cross_zone(C.LU_CELL, 4.0)
    cl4 = np.zeros(lu.shape, bool); hw4 = np.zeros(lu.shape)
    for r_ in roads:
        p_ = np.asarray(r_["points"], float); sg_ = np.hypot(*np.diff(p_, axis=0).T); ss_ = np.concatenate([[0], np.cumsum(sg_)])
        tt_ = np.arange(0, ss_[-1] + 1e-6, 0.5)
        i_, j_ = C.xz_to_ij(np.interp(tt_, ss_, p_[:, 0]), np.interp(tt_, ss_, p_[:, 1]), C.LU_CELL)
        i_ = np.clip(np.round(i_).astype(int), 0, lu.shape[1] - 1); j_ = np.clip(np.round(j_).astype(int), 0, lu.shape[0] - 1)
        cl4[j_, i_] = True; hw4[j_, i_] = np.maximum(hw4[j_, i_], r_["width_m"] / 2)
    dl4, (nj4, ni4) = ndimage.distance_transform_edt(~cl4, return_indices=True)
    road4 = dl4 * C.LU_CELL <= hw4[nj4, ni4] + C.LU_CELL * 0.71
    keep_w = (cz4 & (lu == LU.WATER)) | wet4
    lu[road4 & ~keep_w] = LU.ROAD
    say("길 둑", n_fix, n_last, "바닷가 길 돋움", int(low_rd.sum()))

    # ── 호수 마무리(엔진 5단계 요청 1·2): 윤곽 안은 호수 바닥으로 누르고(하천 둑 지움), 윤곽 바로 바깥(60m) 호수면보다 낮은 들·풀 칸은 호수면 +0.25 위로
    for l in lakes:
        m_ = poly_mask([l["outline"]], y2.shape, C.CELL); ly = float(C.alt_to_y(l["surface_alt"]))
        dpt = ndimage.distance_transform_edt(m_) * C.CELL
        bed = ly - C.K * (0.8 + 1.5 * np.clip(dpt / 30.0, 0, 1))
        y2 = np.where(m_, np.minimum(y2, bed), y2)
        lu2m = np.repeat(np.repeat(lu, 2, 0), 2, 1)[:y2.shape[0], :y2.shape[1]]
        ring = ndimage.binary_dilation(m_, iterations=int(60 / C.CELL)) & ~m_ & ~sea & np.isin(lu2m, [LU.GRASS, LU.PADDY, LU.FIELD, LU.SAND, LU.FOREST])
        lowr = ring & (y2 < ly + 0.25)
        y2 = np.where(lowr, ly + 0.25, y2)
        say("호수", l["name"], "바닥 누름", int(m_.sum()), "칸, 둘레 낮은 칸 돋움", int(lowr.sum()))
    hm = export.write_height(y2.astype(np.float32))
    lum = export.write_landuse(lu)
    coast_km = (sea_d4 / C.K / 1000.0) if sea4.any() else None
    cl4c, cl_meta = PF.climate_grid(y2[::2, ::2], coast_km)
    clm = export.write_climate(cl4c, PF.CLIMATE_CODES, cl_meta)
    say("climate", {PF.CLIMATE_NAMES[k]: int((cl4c == k).sum()) for k in np.unique(cl4c)})
    gz4_, gx4_ = np.gradient(y2[::2, ::2], C.LU_CELL); sl4_ = np.hypot(gx4_, gz4_)
    for s_ in sets:
        i_, j_ = [int(round(float(v))) for v in C.xz_to_ij(s_["x"], s_["z"], C.LU_CELL)]
        pf = s_.pop("_profile", None)
        if pf: s_["profile"] = dict(pf)
        elif s_["id"].startswith("auto_village"):
            p_ = PF.auto_profile(y2[::2, ::2], sl4_, s_["x"], s_["z"], int(cl4c[j_, i_]))
            if sea4.any() and sea_d4[j_, i_] < lr.get("coast_profile_m", 300.0):
                arch = "island" if CFG.get("culture") == "탐라" else "coast"
                p_ = dict(archetype=arch, climate="coast", signature=lr.get("coast_signature", "갯가 낮은 초가와 그물 말리는 돌담"),
                          trades=lr.get("coast_trades", ["고기잡이", "밭농사"]), notes=f"자동: 바다에서 {sea_d4[j_, i_]:.0f}m(게임) — 해안 마을")
            s_["profile"] = p_
    for l in lms:
        l["y"] = round(float(hy_final(y2, l["x"], l["z"])), 2)
    for sp in springs: sp["y"] = round(float(hy_final(y2, sp["x"], sp["z"])), 2)
    for q in passes: q["y"] = round(float(hy_final(y2, q["x"], q["z"])), 2)
    # 읍치 축(진산·안산)
    axes = []
    y2a = y2
    def peak(cx, cz, ang_deg, rmin, rmax, spread=40.0):
        R_ = int(rmax / C.CELL) + 2
        i0_, j0_ = [int(v) for v in C.xz_to_ij(cx, cz)]
        sl = (slice(max(j0_ - R_, 0), j0_ + R_), slice(max(i0_ - R_, 0), i0_ + R_))
        jj_, ii_ = np.mgrid[sl]; xx_, zz_ = C.ij_to_xz(ii_, jj_)
        dx_, dz_ = xx_ - cx, zz_ - cz; dist_ = np.hypot(dx_, dz_)
        dang = np.abs(((np.degrees(np.arctan2(dx_, dz_)) + 360) % 360 - ang_deg + 180) % 360 - 180)
        h_ = np.where((dist_ >= rmin) & (dist_ <= rmax) & (dang <= spread), y2a[sl], -1e9)
        k_ = np.unravel_index(np.argmax(h_), h_.shape)
        return round(float(xx_[k_]), 1), round(float(zz_[k_]), 1)
    for ax in CFG.get("axes", []):
        c_ = ref(ax["center"]); out = dict(town=ax["town"], center=dict(x=c_[0], z=c_[1]))
        for key in ("jinsan", "ansan"):
            a = ax[key]
            if "lat" in a: p_ = xz(a["lat"], a["lon"])
            else: p_ = peak(c_[0], c_[1], *a["search"])
            out[key] = dict(name=a["name"], x=p_[0], z=p_[1], y=round(float(hy_final(y2, *p_)), 1), confidence=a["confidence"], source=a.get("source", []))
        out["axis_ry"] = round(math.atan2(out["ansan"]["x"] - out["jinsan"]["x"], out["ansan"]["z"] - out["jinsan"]["z"]), 3)
        out["note"] = "axis_ry: 진산→안산 방향을 로컬 +z(정면)로 두는 Godot ry(라디안). 고증 참고용 — 게임성 우선." + (" " + ax["note"] if ax.get("note") else "")
        axes.append(out)
    sp = CFG["spawn"]; sx, sz = ref(sp["ref"]); sx, sz = sx + sp.get("dx", 0), sz + sp.get("dz", 0)
    meta = CFG["meta"]
    reg = dict(
        region_id=C.REGION_ID, region_name=CFG["name"], parent_province=meta["parent_province"], level=2,
        culture=CFG["culture"], main_river=meta["main_river"], connected_river=meta["connected_river"],
        watershed_divide=meta["watershed_divide"], main_mountain=meta["main_mountain"], settlement_type=meta["settlement_type"],
        landmark=[l["name"] for l in lms],
        transport=dict(roads=[r["name"] for r in roads if r["class"] in ("대로", "지선")], crossings=[c["name"] for c in crossings if not c["id"].startswith("x_")]),
        economy=meta["economy"], forbidden=meta["forbidden"],
        status="초안(에이전트 생성 — 역사지리 검수 전)",
        sources=["AWS Terrain Tiles terrarium z13 (SRTM 등 공개 DEM 합성; Mapzen/AWS Open Data)",
                 "OpenStreetMap(© OSM contributors, ODbL) — 하천선·해안·지명 위치·현대 시설(제거용) 참고"] + meta.get("sources", []),
        projection=dict(lat0=C.LAT0, lon0=C.LON0, K=C.K, y_base_alt=C.Y_BASE_ALT,
                        formula=f"x=(lon-lon0)*cos(lat0)*111320*K, z=-(lat-lat0)*110574*K, y=(alt-{C.Y_BASE_ALT:g})*K"),
        axes=axes, archetypes=PF.ARCHETYPES, climate=clm,
        height=hm, landuse=lum, rivers=rivers, roads=roads, passes=passes,
        crossings=crossings, settlements=sets, landmarks=lms,
        spawn=dict(x=round(sx, 1), z=round(sz, 1), note=sp.get("note", "")),
        modern_fixes=mlog, hydro=dict(remeandered=hlog["remeandered"], counts=hlog["counts"], acc_thresholds_km2=hlog["acc_thresholds_km2"]),
        build=dict(tool=f"tools/region/build.py {C.REGION_ID} (build_region.py, 설정 tools/region/regions/{C.REGION_ID}.json)",
                   warnings=[f"지정 도강점을 길이 지나지 않음: {m}" for m in missing]),
    )
    if CFG.get("dry_streams"):          # 탐라 건천: 비 올 때만 흐름(엔진은 마른 돌 바닥으로 그림)
        for r in rivers: r["dry"] = True; r["flow"] = "intermittent"
    if sea.any():                        # 하구: 마지막 점(과 그 위 모든 점) 수면 ≥ sea.y + 0.05 (단조 감소 유지)
        sy_ = float(C.alt_to_y(0.0)) + 0.05
        for r in rivers:
            for p_ in r["points"]: p_[2] = round(max(p_[2], sy_), 2)
    if sea.any():
        reg["sea"] = dict(y=round(float(C.alt_to_y(0.0)), 2), name=CFG["hydro"].get("sea_name", "바다"),
                          note="바다 수면 y(해발 0m). landuse 5(물) 중 하천·호수가 아닌 칸이 바다. 바닥은 해발 −1.5…" + f"{CFG.get('sea_floor_alt', -20):g}m로 잘랐다. 물 메시는 이 높이의 평면으로.",
                          share=round(float(sea.mean()), 4))
    if lakes:
        reg["lakes"] = [dict(id=l["id"], name=l["name"], y=round(float(C.alt_to_y(l["surface_alt"])), 2), outline=l["outline"][::max(1, len(l["outline"]) // 160)],
                             confidence=l.get("confidence", "추정"), notes=l.get("notes", "")) for l in lakes]
    if springs: reg["springs"] = springs
    if oreums:
        for o in oreums: o["y"] = round(float(hy_final(y2, o["x"], o["z"])), 2)
        reg["oreums"] = oreums
    if CFG.get("portals"): reg["portals"] = [dict(p, **dict(zip(("x", "z"), ref(p["ref"])))) for p in CFG["portals"]]
    for p_ in reg.get("portals", []): p_.pop("ref", None)
    export.write_region(reg)
    np.save(os.path.join(C.CACHE, "basin_dirn.npy"), dirn)
    np.save(os.path.join(C.CACHE, "alt_fixed.npy"), alt1); np.save(os.path.join(C.CACHE, "res_mask.npy"), res_mask)
    say("done", hm["y_min"], hm["y_max"], "missing", missing, "settlements", len(sets), "landmarks", len(lms))

def river_reaches(r, rivers):
    """명세 v0.3 §5: 발원 → 상류 → 중류 → 하류. 점 번호 구간 [{reach, from, to}] (상류→하류).
    기울기(실제와 같음, 200m 창): >3% 상류, 0.6~3% 중류, <0.6% 하류. 지류가 없는 내의 첫 15%(길이)는 발원."""
    p = np.asarray(r["points"], float)
    if len(p) < 3: return [dict(reach="상류", **{"from": 0, "to": len(p) - 1})]
    s = np.concatenate([[0], np.cumsum(np.hypot(*np.diff(p[:, :2], axis=0).T))])
    win = 200.0 * C.K
    sl = np.zeros(len(p))
    for k in range(len(p)):
        a_ = np.searchsorted(s, s[k] - win / 2); b_ = min(np.searchsorted(s, s[k] + win / 2), len(p) - 1)
        sl[k] = (p[a_, 2] - p[b_, 2]) / max(s[b_] - s[a_], 1e-6)
    lab = np.where(sl > 0.03, 0, np.where(sl > 0.006, 1, 2))
    lab = np.maximum.accumulate(lab)                               # 상류→하류로만 바뀜(되돌아가지 않게)
    names = ["상류", "중류", "하류"]
    leaf = not any(q.get("parent") == r["id"] for q in rivers)
    out = []
    if leaf and r["grade"] == "D":
        k0 = int(np.searchsorted(s, 0.15 * s[-1]))
        if k0 > 0: out.append({"reach": "발원", "from": 0, "to": k0}); lab[:k0] = -1
    for v in (0, 1, 2):
        idx = np.nonzero(lab == v)[0]
        if len(idx): out.append({"reach": names[v], "from": int(idx[0]), "to": int(idx[-1])})
    wf = {"발원": 0.3, "상류": 0.5, "중류": 0.8, "하류": 1.0}
    for o in out:   # 구간별 수면 폭(명세 §5: 상류 좁고 하류 넓게) — 집수면적 폭(widths)이 있으면 그 구간 최대값
        o["width_m"] = round(max(r["widths"][o["from"]:o["to"] + 1]), 1) if r.get("widths") else round(max(r["width_m"] * wf[o["reach"]], 1.0), 1)
    return out

def oreum_boost(alt, sea):
    """명세 v0.3 §21-I JJ-02: 오름은 무작위 언덕이 아니라 뚜렷한 실루엣 — OSM 오름 봉우리 둘레의 국지 기복을 키우고(×gain) 목록을 낸다."""
    oc = CFG["oreum"]
    names = json.load(open(os.path.join(C.HERE, "cache", "east", oc["names_file"])))
    base = ndimage.gaussian_filter(alt, oc.get("sigma_real", 160.0) * C.K / C.CELL)
    det = alt - base
    gain = oc.get("gain", 1.4); rr = oc.get("radius_real", 450.0) * C.K / C.CELL
    out = []; mask = np.zeros(alt.shape)
    seen = []
    for e in names:
        nm = e.get("name") or ""
        if e.get("kind") != "natural=peak" or not any(k in nm for k in ("오름", "봉", "악")): continue
        x, z = C.geo_to_game(e["lat"], e["lon"]); x, z = float(x), float(z)
        if abs(x) > -C.X0 - 50 or abs(z) > -C.Z0 - 50 or any(math.hypot(x - a, z - b) < 40 for a, b in seen): continue
        seen.append((x, z))
        i, j = C.xz_to_ij(x, z); R2 = int(rr * 1.6)
        j0, j1, i0, i1 = max(int(j) - R2, 0), min(int(j) + R2 + 1, alt.shape[0]), max(int(i) - R2, 0), min(int(i) + R2 + 1, alt.shape[1])
        jj, ii = np.mgrid[j0:j1, i0:i1]; d = np.hypot(ii - i, jj - j)
        w = np.clip(1.6 - d / rr, 0, 1)
        mask[j0:j1, i0:i1] = np.maximum(mask[j0:j1, i0:i1], w)
        sub = det[j0:j1, i0:i1]; pos = (sub > 2.0) & (d <= rr * 1.2)
        rad = math.sqrt(pos.sum() / math.pi) * C.CELL if pos.any() else 0.0
        hreal = float(sub[d <= rr * 0.3].max()) if (d <= rr * 0.3).any() else 0.0
        out.append(dict(id=f"oreum_{len(out):02d}", name=nm, x=round(x, 1), z=round(z, 1), radius_m=round(rad, 1), relief_real_m=round(hreal * gain, 1),
                        confidence="추정", source=["OpenStreetMap natural=peak(오름 이름)"], notes="오름 실루엣 강조(국지 기복 ×%.2f)" % gain))
    alt += np.where(sea, 0, np.clip(det, 0, None) * (gain - 1) * mask)
    say("오름", len(out), "개 실루엣 강조")
    return out

def hy_final(y2, x, z):
    return C.bilinear(y2, *C.xz_to_ij(np.asarray(x), np.asarray(z)))

def CFG_L(lid):
    return next((l for l in CFG.get("landmarks", []) if l["id"] == lid), {})

if __name__ == "__main__":
    main()
