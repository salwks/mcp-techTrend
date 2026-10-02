"""권역 데이터 전체 빌드: DEM → 현대 흔적 제거 → 수계·깎기 → 도로(A*) → 고개·도강점 → 토지이용·마을 → region.json.
실행: python3 tools/region/build.py   (먼저 fetch_dem.py, osm_fetch.py — 캐시가 있으면 생략)"""
import json, math, os, sys, time
import numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw
import common as C, dem, modern_fix, hydro, roads as R, landuse as LU, export, places as P

T0 = time.time()
def say(*a): print(f"[{time.time() - T0:6.1f}s]", *a, flush=True)

def xz(lat, lon):
    x, z = C.geo_to_game(lat, lon); return round(float(x), 1), round(float(z), 1)

def nearest_on(points, x, z):
    p = np.asarray(points)[:, :2]; d = np.hypot(p[:, 0] - x, p[:, 1] - z); k = int(np.argmin(d))
    return float(p[k, 0]), float(p[k, 1]), float(d[k]), k

def seg_intersections(a, b):
    """두 폴리라인 교차점 목록 [(x,z,ia,ib)]."""
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
    """랜드마크·마을 바닥을 부드럽게 고른다(실제 고도 배열, 2m)."""
    for it in items:
        x, z, r = it
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

def road_grade(alt, roads, river_d, river_hw):
    """길 횡단면을 평평하게(종단은 매끈하게). 하천 위는 건드리지 않음."""
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

def main():
    say("DEM")
    alt0 = dem.build()
    alt0 = ndimage.gaussian_filter(alt0, 1.0)            # SRTM 반점 잡음 완화(실제 ~7m)
    say("현대 흔적 제거")
    alt1, mlog, res_mask = modern_fix.apply(alt0)
    say("수계")
    rivers, alt2, hlog = hydro.run(alt1)
    acc, dirn = hlog.pop("acc"), hlog.pop("dirn"); hlog.pop("filled")
    riv = {r["id"]: r for r in rivers}
    say("rivers", hlog["counts"])

    # ── 고증 위치
    lms = []
    for l in P.LANDMARKS:
        x, z = xz(l["lat"], l["lon"])
        lms.append(dict(id=l["id"], name=l["name"], kit=l["kit"], x=x, z=z, ry=l["ry"], confidence=l["confidence"],
                        source=l["source"], notes=l["notes"], size_m=l.get("size_m"), lat=round(l["lat"], 5), lon=round(l["lon"], 5)))
    sets = []
    for s in P.SETTLEMENTS:
        x, z = xz(s["lat"], s["lon"])
        sets.append(dict(id=s["id"], name=s["name"], type=s["type"], x=x, z=z, radius_m=s["radius_m"], size=s["size"],
                         notes=s["notes"], confidence=s["confidence"], source=s["source"], lat=round(s["lat"], 5), lon=round(s["lon"], 5)))
    S = {s["id"]: s for s in sets}; L = {l["id"]: l for l in lms}
    # 3단계: 배치 에이전트 자리로 옮김(신뢰도는 그대로)
    OVR = {"yongseonggwan": (-3227.8, 205.0, "T자형 가로: 남문에서 올라온 남북길 끝 정면(성 중심축)에 객사를 둠(담 약 72×40m). 원 좌표(용성초 터)보다 동쪽 약 40m — 게임성 우선"),
           "namwon_hyanggyo": (-3247.3, -97.8, "원 좌표가 광치천에 걸리고, 3단계 북쪽 길이 지나가 placement-namwon 배치 자리(서쪽)로 옮김")}
    for oid, (ox, oz, why) in OVR.items():
        for o in (L.get(oid), S.get(oid)):
            if o is None: continue
            o["x"], o["z"] = ox, oz; o["notes"] = (o["notes"] + " " if o["notes"] else "") + f"[3단계 위치 조정: {why}]"
    sets.append(dict(id="inwol_south_village", name="인월 람천 남쪽 마을", type="마을", x=2758.0, z=-1365.0, radius_m=44.0, size="S",
                     notes="placement-east 섶다리(ea_iw_seop_bridge_01) 남쪽 기슭의 작은 마을(약 6,000m²). 인월장으로 섶다리 건너 다님.",
                     confidence="가설", source=["placement-east 보고서 §8-3 섶다리 자리", "입지 규칙(남쪽 기슭, 장터 맞은편)"], nosnap=True, min_z=-1392.0))
    S["inwol_south_village"] = sets[-1]
    S["namwon_eup"]["core"] = [L["namwon_eupseong"]["x"] - 93, L["namwon_eupseong"]["z"] - 93, L["namwon_eupseong"]["x"] + 93, L["namwon_eupseong"]["z"] + 93]

    # 2m 격자 하천 거리
    surf2 = np.zeros(alt2.shape, bool); hw2 = np.zeros(alt2.shape); sv2 = np.zeros(alt2.shape)
    for r in rivers:
        p = np.array(r["points"]); seg = np.hypot(*np.diff(p[:, :2], axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
        t = np.arange(0, s[-1], 1.0); x = np.interp(t, s, p[:, 0]); z = np.interp(t, s, p[:, 1])
        i, j = C.xz_to_ij(x, z); i = np.clip(np.round(i).astype(int), 0, alt2.shape[1] - 1); j = np.clip(np.round(j).astype(int), 0, alt2.shape[0] - 1)
        surf2[j, i] = True; hw2[j, i] = np.maximum(hw2[j, i], r["width_m"] / 2)
        sv2[j, i] = np.interp(t, s, p[:, 2])
    d2, (nj, ni) = ndimage.distance_transform_edt(~surf2, return_indices=True)
    d2 = d2 * C.CELL; HW2 = hw2[nj, ni]; SV2 = sv2[nj, ni]
    river_keep = np.clip(1 - (d2 - HW2 - 3) / 8.0, 0, 1)
    # 확정이 아닌 마을 자리를 사람이 살 만한 땅(완경사·골 바닥 가까이·물가 아님)으로 최대 250m(게임) 옮김
    yy = C.alt_to_y(alt2); gz_, gx_ = np.gradient(ndimage.uniform_filter(yy, 5), C.CELL); slp = np.hypot(gx_, gz_)
    for s_ in sets:
        if s_["confidence"] == "확정" or s_["type"] in ("성황당", "읍성", "사찰") or s_["id"].startswith("namwon") or s_.get("nosnap"): continue
        i, j = [int(round(float(v))) for v in C.xz_to_ij(s_["x"], s_["z"])]; R_ = 125
        j0, j1, i0, i1 = max(j - R_, 0), min(j + R_ + 1, yy.shape[0]), max(i - R_, 0), min(i + R_ + 1, yy.shape[1])
        jj, ii = np.mgrid[j0:j1, i0:i1]; dd = np.hypot(ii - i, jj - j) * C.CELL
        sub = yy[j0:j1, i0:i1]; low = np.percentile(sub, 5)
        sc = 10 * slp[j0:j1, i0:i1] + dd / 250 + np.clip((sub - low) / (30 * C.K), 0, 3)
        sc[(d2[j0:j1, i0:i1] < HW2[j0:j1, i0:i1] + 12) | (dd > 250)] = 99
        k = np.unravel_index(np.argmin(sc), sc.shape); nx, nz = C.ij_to_xz(ii[k], jj[k])
        moved = math.hypot(nx - s_["x"], nz - s_["z"])
        if moved > 20:
            s_["notes"] = (s_["notes"] + " " if s_["notes"] else "") + f"[입지 보정: 원 좌표에서 {moved:.0f}m(게임) 옮김 — 완경사 골 바닥]"
            s_["x"], s_["z"] = round(float(nx), 1), round(float(nz), 1)
    # 바닥 고르기(실제 고도)
    pads = [(l["x"], l["z"], 0.5 * max(l["size_m"]) * 0.9) for l in lms if l.get("size_m") and l["id"] != "namwon_eupseong" and max(l["size_m"]) < 130]
    pads.append((L["namwon_eupseong"]["x"], L["namwon_eupseong"]["z"], 85))
    flatten_pads(alt2, pads, river_keep)

    # ── 도강점(고증·가설) — 하천선 위 가장 가까운 점
    def on_river(rid, lat, lon):
        x, z = xz(lat, lon); px, pz, d, k = nearest_on(riv[rid]["points"], x, z); return px, pz
    designated = [
        dict(id="yocheon_east_ford", name="요천 동쪽 건널목(남원→운봉 길)", type="섶다리", river_id="yocheon", road_id="tongyeong_byeolro",
             pos=on_river("yocheon", 35.4135, 127.3975), confidence="가설",
             notes="겨울~봄에 놓는 섶다리, 큰물 지면 걷어내고 여울로 건넘(가설). 요천은 모래 바닥 얕은 내."),
        dict(id="yocheon_south_naru", name="요천 광한루 앞 나루", type="나루", river_id="yocheon", road_id="namwon_gurye_road",
             pos=on_river("yocheon", 35.4010, 127.3840), confidence="가설",
             notes="광한루 남쪽, 구례·곡성 방면 길. 큰물 때 배로 건넘(가설)."),
        dict(id="ramcheon_unbong_ford", name="람천 운봉 서쪽 건널목", type="섶다리", river_id="ramcheon", road_id="tongyeong_byeolro",
             pos=on_river("ramcheon", 35.4395, 127.5262), confidence="가설",
             notes="여원재에서 내려와 읍치로 드는 자리(람천이 읍치 서·북쪽을 감아 돎). 고원 위 람천은 얕다 — 섶다리/징검다리(가설)."),
        dict(id="haetal_bridge", name="실상사 앞 해탈교 자리", type="섶다리", river_id="ramcheon", road_id="haetal_lane",
             pos=on_river("ramcheon", 35.4163, 127.6355), confidence="추정",
             notes="OSM 'Haetal Bridge'(현대 다리) 자리 — 1870년 다리 형식은 가설(섶다리/외나무다리)."),
    ]
    IW_SEOP = dict(c=(2766.2, -1405.9), n=(2770.2, -1418.5), s=(2762.2, -1393.3))
    designated.append(dict(id="inwol_south_seopdari", name="인월 람천 섶다리(남쪽 마을)", type="섶다리", river_id="ramcheon", road_id="inwol_south_lane",
                           pos=IW_SEOP["c"], confidence="가설",
                           notes="placement-east ea_iw_seop_bridge_01 자리(중심 2766.2,−1405.9, ry −0.306, 길이 18.5m, 북 끝 2770.2,−1418.5·남 끝 2762.2,−1393.3). 장꾼이 오가는 섶다리(가설)."))
    cross_xz = [c["pos"] for c in designated]
    PASS_YW = xz(35.4470, 127.5013)

    # ── 도로
    say("도로 A*")
    y4 = C.alt_to_y(alt2[::2, ::2])
    wm = R.river_masks(rivers, y4.shape)
    cost, slope4 = R.cost_field(y4, wm, cross_xz)
    eg = L["namwon_east_gate"]; sg = L["namwon_south_gate"]; ng = L["namwon_north_gate"]; wg = L["namwon_west_gate"]
    D = {c["id"]: c["pos"] for c in designated}
    # 랜드마크 경내(실상사 등)는 길이 가로지르지 않게 비싸게
    base_c = cost[0].copy()
    xs4_, zs4_ = C.ij_to_xz(*np.meshgrid(np.arange(base_c.shape[1]), np.arange(base_c.shape[0])), C.LU_CELL)
    for l_ in lms:
        if not l_.get("size_m") or l_["id"] in ("namwon_eupseong", "ojakgyo", "gwanghallu") or max(l_["size_m"]) < 30: continue
        m_ = (np.abs(xs4_ - l_["x"]) <= l_["size_m"][0] / 2 + 4) & (np.abs(zs4_ - l_["z"]) <= l_["size_m"][1] / 2 + 4)
        base_c[m_] += 60.0
    cost = (base_c, cost[1])
    # ── 남원읍성 성문 통로(kit/landmark/namwon_eupseong.gd·seongmun.gd 기하): 성문 중심 = 성벽 중심선(중심에서 90.7m),
    #    옹성 반지름 11, 열린 쪽 S=정면(남), N=서, E=남, W=북(세계 방위). 길은 문 → 옹성 마당 → 옹성 출구로만 드나든다.
    CXe, CZe = L["namwon_eupseong"]["x"], L["namwon_eupseong"]["z"]
    GZC = 93.0 - 4.6 / 2
    def gate_path(side):
        ry = {"S": 0.0, "E": math.pi / 2, "N": math.pi, "W": -math.pi / 2}[side]
        opn = {"S": "front", "N": "west", "E": "south", "W": "north"}[side]
        lpx = {"S": "east", "E": "north", "N": "west", "W": "south"}[side]
        def w(lx, lz):   # 변 로컬(+z 바깥, 원점 성 중심) → 세계
            lz = lz + GZC
            return (round(CXe + lx * math.cos(ry) + lz * math.sin(ry), 1), round(CZe - lx * math.sin(ry) + lz * math.cos(ry), 1))
        zo, Rg = 5.6 / 2 - 0.5, 11.0
        if opn == "front":
            out = [w(0, -6), w(0, 0), w(0, zo + Rg * 0.5), w(0, zo + Rg + 3.0), w(0, zo + Rg + 9.0)]
        else:
            sx_ = 1.0 if opn == lpx else -1.0
            out = [w(0, -6), w(0, 0), w(0, zo + Rg * 0.5), w(sx_ * 6.5, zo + 3.0), w(sx_ * 11.9, zo + 1.5), w(sx_ * 18.0, zo + 1.5)]
        return out                                   # [성 안, 문 통로, 옹성 마당, …, 옹성 밖]
    GP = {k: gate_path(k) for k in "SNEW"}
    gate_center = {k: GP[k][1] for k in "SNEW"}

    def bank_waypoints(rid, a, b, spacing=30.0, extra=4.0, side_ref=None):
        """하천 rid를 따라 a→b 사이 물가(벼룻길) 경유점: 반폭+extra만큼 떨어진 양안 중 덜 높은 쪽(DP, 건너기 벌점)."""
        rp = np.asarray(riv[rid]["points"])
        ka = int(np.argmin(np.hypot(rp[:, 0] - a[0], rp[:, 1] - a[1]))); kb = int(np.argmin(np.hypot(rp[:, 0] - b[0], rp[:, 1] - b[1])))
        lo_, hi_ = sorted((ka, kb))
        seg = rp[lo_:hi_ + 1]
        if len(seg) < 4: return []
        L_ = np.concatenate([[0], np.cumsum(np.hypot(*np.diff(seg[:, :2], axis=0).T))])
        ts = np.arange(spacing / 2, L_[-1] - spacing / 3, spacing)
        if len(ts) == 0: return []
        px_ = np.interp(ts, L_, seg[:, 0]); pz_ = np.interp(ts, L_, seg[:, 1]); sy = np.interp(ts, L_, seg[:, 2])
        tg = np.stack([np.interp(ts + 2, L_, seg[:, 0]) - np.interp(ts - 2, L_, seg[:, 0]), np.interp(ts + 2, L_, seg[:, 1]) - np.interp(ts - 2, L_, seg[:, 1])], 1)
        tg /= np.linalg.norm(tg, axis=1, keepdims=True) + 1e-9
        nrm = np.stack([-tg[:, 1], tg[:, 0]], 1)
        off = riv[rid]["width_m"] / 2 + extra
        cand = []
        for sgn in (1, -1):
            qx = px_ + sgn * nrm[:, 0] * off; qz = pz_ + sgn * nrm[:, 1] * off
            hgt = np.maximum.reduce([C.bilinear(y2a, *C.xz_to_ij(px_ + sgn * nrm[:, 0] * o, pz_ + sgn * nrm[:, 1] * o)) for o in (off, off + 3)]) - sy
            cand.append((qx, qz, hgt))
        n = len(ts); INF = 1e9; SW = 80.0
        end_side = None
        if side_ref is not None:      # 끝(기준점 쪽 끝) 칸만 기준점이 있는 기슭으로 고정, 중간은 덜 높은 쪽(DP)
            te = n - 1 if ka <= kb else 0
            end_side = 0 if np.dot(np.asarray(side_ref) - np.array([px_[te], pz_[te]]), nrm[te]) >= 0 else 1
        dp = np.full((n, 2), INF); bk = np.zeros((n, 2), int)
        dp[0] = [cand[0][2][0], cand[1][2][0]]
        for t in range(1, n):
            for s_ in range(2):
                c0 = dp[t - 1, s_]; c1 = dp[t - 1, 1 - s_] + SW
                bk[t, s_] = s_ if c0 <= c1 else 1 - s_
                dp[t, s_] = min(c0, c1) + max(cand[s_][2][t], 0) ** 1.5
        side = [int(np.argmin(dp[-1])) if end_side is None or ka > kb else end_side]
        for t in range(n - 1, 0, -1): side.append(bk[t, side[-1]])
        side = side[::-1]
        wp = [(float(cand[sd][0][t]), float(cand[sd][1][t])) for t, sd in enumerate(side)]
        return wp if ka <= kb else wp[::-1]

    y2a = C.alt_to_y(alt2)
    sil_front = (L["silsangsa"]["x"], L["silsangsa"]["z"] + 70)
    MS_MOUTH = tuple(riv["mansucheon"]["points"][-1][:2])
    def _ht():
        rp = np.asarray(riv["ramcheon"]["points"]); pos = np.asarray(D_pos_haetal)
        k = int(np.argmin(np.hypot(rp[:, 0] - pos[0], rp[:, 1] - pos[1])))
        t = rp[min(k + 2, len(rp) - 1), :2] - rp[max(k - 2, 0), :2]; t = t / (np.linalg.norm(t) + 1e-9); n = np.array([-t[1], t[0]])
        sl_ = L["silsangsa"]; toward = np.array([sl_["x"], sl_["z"]]) - pos
        sgn = 1.0 if np.dot(toward, n) >= 0 else -1.0
        off = riv["ramcheon"]["width_m"] / 2
        return tuple(pos + n * sgn * (off + 25)), tuple(pos - n * sgn * (off + 30))
    D_pos_haetal = [c["pos"] for c in designated if c["id"] == "haetal_bridge"][0]
    HT_NEAR, HT_FAR = _ht()
    road_defs = [
        dict(id="tongyeong_byeolro", name="통영별로(남원→여원재→운봉→인월→함양)", cls="대로", width=5.0, prefix=GP["E"][1:],
             wps=[GP["E"][-1], (GP["E"][-1][0] + 8, GP["E"][-1][1] + 10), D["yocheon_east_ford"], (S["ibaek"]["x"], S["ibaek"]["z"]), (S["yeowon_jumak"]["x"], S["yeowon_jumak"]["z"]), PASS_YW,
                  D["ramcheon_unbong_ford"], (S["unbong_eup"]["x"] - 25, S["unbong_eup"]["z"] - 45), (S["bijeon"]["x"], S["bijeon"]["z"]),
                  (S["inwol_yeok"]["x"], S["inwol_yeok"]["z"]), xz(35.4700, 127.6597)],
             source=["신경준 『도로고』 통영별로(전주–남원–운봉–함양–…–통영) 노선 체계(지식 기반, 원문 대조 필요)", "여원치: 한국민족문화대백과 E0067255"],
             confidence="추정", notes="동문(향일루) 옹성 남쪽 출구로 나감. 경유 순서(남원→여원재→람천 건너 운봉 읍치 북쪽 큰길→황산 앞→인월→함양)만 고증, 세부는 A*."),
        dict(id="inwol_banseon_road", name="인월–산내–반선 길(람천·만수천 물가)", cls="지선", width=3.5,
             wps=[(S["inwol_yeok"]["x"], S["inwol_yeok"]["z"])] + bank_waypoints("ramcheon", (S["inwol_yeok"]["x"], S["inwol_yeok"]["z"]), MS_MOUTH, side_ref=(MS_MOUTH[0] - 60, MS_MOUTH[1] + 90))
                 + bank_waypoints("mansucheon", MS_MOUTH, (S["sannae"]["x"], S["sannae"]["z"]))
                 + [(S["sannae"]["x"], S["sannae"]["z"])] + bank_waypoints("mansucheon", (S["sannae"]["x"], S["sannae"]["z"]), (S["banseon"]["x"], S["banseon"]["z"]))
                 + [(S["banseon"]["x"], S["banseon"]["z"])],
             source=["실상사·산내·반선 위치(OSM)", "람천·만수천 물가를 따르는 벼룻길(지형 필연, 가설)"], confidence="가설",
             notes="물가 경유점(하천 반폭+5m)으로 계곡을 따르게 함. 람천은 인월 아래에서 한 번 건너 실상사 쪽(서·남안)을 따라 내려감. 실상사 정면은 지선, 해탈교는 절 동쪽에서 람천 건너편으로 가는 마을길."),
        dict(id="silsangsa_lane", name="실상사 길", cls="마을길", width=3.0, branch_of="inwol_banseon_road",
             wps=bank_waypoints("ramcheon", MS_MOUTH, (L["silsangsa"]["x"], L["silsangsa"]["z"]), side_ref=sil_front) + [sil_front],
             source=["OSM 실상사 위치"], confidence="추정", notes="큰길에서 갈라져 실상사 남쪽 정면에 닿음(경내는 비켜 감)."),
        dict(id="haetal_lane", name="해탈교 길(실상사 동쪽 → 람천 건너)", cls="마을길", width=2.5, branch_of="inwol_banseon_road",
             wps=[HT_NEAR, D["haetal_bridge"], HT_FAR],
             source=["OSM 'Haetal Bridge' 위치"], confidence="추정", notes="실상사 동쪽에서 해탈교 자리로 람천을 건너 동안 들로. 다리 형식은 가설(섶다리)."),
        dict(id="namwon_gurye_road", name="남원 남문–광한루–요천 나루–구례 방면 길", cls="지선", width=3.5, prefix=GP["S"][1:],
             wps=[GP["S"][-1], (L["gwanghallu"]["x"] + 40, L["gwanghallu"]["z"] - 15), D["yocheon_south_naru"], xz(35.3545, 127.4000)],
             source=["광한루가 남문 밖 요천가에 있음(OSM 위치)"], confidence="가설", notes="남문(완월루) 옹성 정면 출구로 나감. 권역 밖 구례 방면은 노정 담당."),
        dict(id="namwon_north_road", name="남원 북문–전주 방면 길(통영별로 북쪽)", cls="대로", width=5.0, prefix=GP["N"][1:],
             wps=[GP["N"][-1], (S["namwon_hyanggyo"]["x"] + 30, S["namwon_hyanggyo"]["z"] + 10), xz(35.4805, 127.3720)],
             source=["통영별로는 전주–임실–오수–남원으로 내려옴(지식 기반)"], confidence="가설", notes="북문(공신루) 옹성 서쪽 출구로 나감. 북쪽 경계는 노정(남원→전주) 포털."),
        dict(id="namwon_eup_street", name="남원 읍내 남북길(남문–네거리–객사 삼문 앞)", cls="마을길", width=4.0, fixed=[gate_center["S"], (CXe, 238.0)],
             source=["조선 읍성 T자형 가로(남문→객사 정면) 일반형"], confidence="가설", notes="남문 통로에서 올라와 동서길 네거리를 지나 객사 삼문 앞(z≈238)에서 끝남(T자)."),
        dict(id="namwon_north_gate_street", name="남원 북문길(북문–객사 담 동쪽–동서길)", cls="마을길", width=4.0,
             fixed=[gate_center["N"], (CXe, 176.0), (CXe + 42.0, 176.0), (CXe + 42.0, CZe)],
             source=["조선 읍성 T자형 가로 일반형"], confidence="가설", notes="북문 통로에서 내려와 객사 담(72×40m, z 185~225) 북쪽을 지나 동쪽으로 돌아 동서길에 붙음."),
        dict(id="namwon_eup_street_ew", name="남원 읍내 동서길(서문–동문)", cls="마을길", width=4.0, fixed=[gate_center["W"], gate_center["E"]],
             source=["방형 읍성 십자가로 일반형"], confidence="가설", notes="성 안 동서길. 양끝은 성문 통로."),
        dict(id="namwon_market_lane", name="남문 밖 장터길(성 밖으로 돌아 서문)", cls="마을길", width=3.0,
             fixed=[GP["S"][-2], (CXe - 4, CZe + GZC + 24), (CXe - 40, CZe + GZC + 28), (S["namwon_jang"]["x"], S["namwon_jang"]["z"]),
                    (CXe - 112, CZe + 112), (CXe - 114, CZe + 40), (CXe - 112, GP["W"][-1][1] - 4), GP["W"][-1], GP["W"][-2]],
             source=["가설"], confidence="가설", notes="남문 옹성 출구 → 장터 → 서벽 바깥(성벽에서 약 20m) → 서문 옹성 북쪽 출구. 성벽을 넘지 않음."),
        dict(id="namwon_west_gate_lane", name="서문 통로", cls="마을길", width=3.0, fixed=GP["W"][1:-1],
             source=["가설"], confidence="가설", notes="서문 → 옹성 마당 → 북쪽 출구."),
        dict(id="unbong_eup_street", name="운봉 읍치 지선(큰길–관아–장터)", cls="마을길", width=3.0, branch_of="tongyeong_byeolro",
             wps=[(L["unbong_gwana"]["x"], L["unbong_gwana"]["z"] + 20), (S["unbong_jang"]["x"], S["unbong_jang"]["z"])],
             source=["가설"], confidence="가설", notes="통영별로에서 갈라져 읍치로 들어가는 지선(되돌아 나오지 않게 대로와 분리)."),
        dict(id="inwol_south_lane", name="인월 장터–람천 섶다리–남쪽 마을 길", cls="마을길", width=3.0,
             source=["placement-east 섶다리 자리"], confidence="가설", notes="인월장 → 섶다리(북 끝→남 끝, 고정) → 남쪽 마을 → 인월–산내 물가길 합류."),
        dict(id="baemsagol_trail", name="반선–뱀사골 산길", cls="산길", width=1.5,
             wps=[(S["banseon"]["x"], S["banseon"]["z"]), xz(35.3560, 127.5880)], source=["뱀사골(OSM 계곡선)"], confidence="가설", notes="화개재 방면 계곡 길."),
    ]
    # 지정 도강점 경유점 → 하천에 수직인 양안 두 점(가까운 쪽 먼저)으로 바꿔 길이 물길을 따라 걷지 않고 곧게 건너게
    des_by_pos = {tuple(c["pos"]): c for c in designated}
    def ford_pair(pos, prev):
        c_ = des_by_pos[tuple(pos)]; rp = np.asarray(riv[c_["river_id"]]["points"])
        k = int(np.argmin(np.hypot(rp[:, 0] - pos[0], rp[:, 1] - pos[1])))
        t = rp[min(k + 2, len(rp) - 1), :2] - rp[max(k - 2, 0), :2]; t = t / (np.linalg.norm(t) + 1e-9)
        n = np.array([-t[1], t[0]]); off = riv[c_["river_id"]]["width_m"] / 2 + 7.0
        a_, b_ = tuple(np.asarray(pos) + n * off), tuple(np.asarray(pos) - n * off)
        if prev is not None and math.hypot(b_[0] - prev[0], b_[1] - prev[1]) < math.hypot(a_[0] - prev[0], a_[1] - prev[1]):
            a_, b_ = b_, a_
        return [a_, tuple(pos), b_]
    for rd in road_defs:
        if rd.get("wps"):
            out_ = []
            for w_ in rd["wps"]:
                if tuple(w_) in des_by_pos:
                    out_ += ford_pair(w_, out_[-1] if out_ else None)
                else:
                    out_.append(w_)
            rd["wps"] = out_
    RI = R.river_index(rivers)
    roads = []
    for rd in road_defs:
        if rd["id"] == "inwol_south_lane":
            p1 = R.route(cost, [(S["inwol_jang"]["x"], S["inwol_jang"]["z"]), IW_SEOP["n"]])
            mainr = np.asarray(next(r for r in roads if r["id"] == "inwol_banseon_road")["points"])
            vx, vz = S["inwol_south_village"]["x"], S["inwol_south_village"]["z"]
            dm = np.hypot(mainr[:, 0] - vx, mainr[:, 1] - vz); km = int(np.argmin(dm))
            p2 = R.route(cost, [IW_SEOP["s"], (vx, vz), tuple(mainr[km])])
            pts = np.vstack([p1, [IW_SEOP["c"]], p2])
        elif rd.get("fixed"):
            pts = np.asarray(rd["fixed"], float)
        else:
            wps = rd["wps"]
            if rd.get("branch_of"):
                main = np.asarray(next(r for r in roads if r["id"] == rd["branch_of"])["points"])
                d_ = np.hypot(main[:, 0] - wps[0][0], main[:, 1] - wps[0][1]); d_[d_ < 25] = 1e9; k_ = int(np.argmin(d_))
                wps = [tuple(main[k_])] + list(wps)
            pts = R.route(cost, wps)
            pts, nch = R.fix_water_runs(pts, RI)
            pts = R.remove_loops(pts)
            if nch: say("  물길 따라 걷던", nch, "m 고침", rd["id"])
            if rd.get("prefix"):
                pts = np.vstack([np.asarray(rd["prefix"][:-1], float), pts])
        roads.append(dict(id=rd["id"], name=rd["name"], **{"class": rd["cls"]}, width_m=rd["width"],
                          points=[[round(float(p[0]), 1), round(float(p[1]), 1)] for p in pts],
                          confidence=rd["confidence"], source=rd["source"], notes=rd["notes"]))
        say("road", rd["id"], len(pts))
    # ── 읍치 공간 구성(진산–읍치–안산 축, 제향 시설: 사직단 서·여단 북·성황사 진산 기슭) + 오솔길
    gzs, gxs = np.gradient(y2a, C.CELL); slope2 = np.hypot(gxs, gzs)
    rdmask = np.zeros(y2a.shape, bool)
    for r_ in roads:
        p_ = np.asarray(r_["points"]); sg_ = np.hypot(*np.diff(p_, axis=0).T); ss_ = np.concatenate([[0], np.cumsum(sg_)])
        tt_ = np.arange(0, ss_[-1] + 1e-6, 1.0)
        i_, j_ = C.xz_to_ij(np.interp(tt_, ss_, p_[:, 0]), np.interp(tt_, ss_, p_[:, 1]))
        rdmask[np.clip(np.round(j_).astype(int), 0, rdmask.shape[0] - 1), np.clip(np.round(i_).astype(int), 0, rdmask.shape[1] - 1)] = True
    d_rd = ndimage.distance_transform_edt(~rdmask) * C.CELL
    def site(cx, cz, ang_deg, rmin, rmax, max_slope=0.2, spread=40.0, prefer="flat"):
        """방향(ang: 0=남 +z, 90=동 +x, 180=북, 270=서)·거리 범위 안에서 평탄·물/길 피한 자리."""
        R_ = int(rmax / C.CELL) + 2
        i0_, j0_ = [int(v) for v in C.xz_to_ij(cx, cz)]
        sl = (slice(max(j0_ - R_, 0), j0_ + R_), slice(max(i0_ - R_, 0), i0_ + R_))
        jj_, ii_ = np.mgrid[sl]; xx_, zz_ = C.ij_to_xz(ii_, jj_)
        dx_, dz_ = xx_ - cx, zz_ - cz; dist_ = np.hypot(dx_, dz_)
        ang_ = (np.degrees(np.arctan2(dx_, dz_)) + 360) % 360
        dang = np.abs((ang_ - ang_deg + 180) % 360 - 180)
        ok = (dist_ >= rmin) & (dist_ <= rmax) & (dang <= spread) & (slope2[sl] <= max_slope) & (d2[sl] > HW2[sl] + 15) & (d_rd[sl] > 10)
        sc = np.abs(dist_ - (rmin + rmax) / 2) / 60 + dang / 30 + slope2[sl] * 6
        if prefer == "high": sc = sc - (y2a[sl] - y2a[j0_, i0_]) / 4
        sc[~ok] = 1e9
        k_ = np.unravel_index(np.argmin(sc), sc.shape)
        if sc[k_] >= 1e9: return None
        return round(float(xx_[k_]), 1), round(float(zz_[k_]), 1)
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
    axes = []; new_lm = []
    NW_C = (L["namwon_eupseong"]["x"], L["namwon_eupseong"]["z"]); UB_C = (S["unbong_eup"]["x"], S["unbong_eup"]["z"])
    jin_nw = xz(35.4300083, 127.3523639)                       # 교룡산 봉우리(OSM natural=peak)
    an_nw = peak(NW_C[0], NW_C[1], 0, 250, 750, 35)            # 남쪽 요천 건너 낮은 산(이름 미상)
    jin_ub = peak(UB_C[0], UB_C[1], 180, 250, 900, 45)
    an_ub = peak(UB_C[0], UB_C[1], 0, 200, 800, 45)
    for town, (jn, jnn, jconf, jsrc), (an, ann) in [
            ("남원부 읍성", (jin_nw, "교룡산", "추정", ["교룡산: 남원 진산(전북일보 등 공개 해설) + OSM 봉우리 35.43001,127.35236"]), (an_nw, "남쪽 안산(이름 미상)")),
            ("운봉현 읍치", (jin_ub, "운봉 진산(이름 미상)", "가설", ["원칙: 읍치 북쪽 뒷산 — DEM 북쪽 최고점(문헌 미확인)"]), (an_ub, "운봉 안산(이름 미상)"))]:
        c_ = NW_C if town.startswith("남원") else UB_C
        dx_, dz_ = an[0] - jn[0], an[1] - jn[1]
        axes.append(dict(town=town, center=dict(x=c_[0], z=c_[1]),
                         jinsan=dict(name=jnn, x=jn[0], z=jn[1], confidence=jconf, source=jsrc),
                         ansan=dict(name=ann, x=an[0], z=an[1], confidence="가설", source=["원칙: 읍치 남쪽 앞산 — DEM 남쪽 봉우리(문헌 미확인)"]),
                         axis_ry=round(math.atan2(dx_, dz_), 3),
                         note="axis_ry: 진산→안산 방향을 로컬 +z(정면)로 두는 Godot ry(라디안). 고증 참고용 — 게임성 우선."))
    def add_fac(fid, name, kit, pos, conf, src, note, size):
        if pos is None: return
        new_lm.append(dict(id=fid, name=name, kit=kit, x=pos[0], z=pos[1], ry=0, confidence=conf, source=src, notes=note, size_m=size))
    # 남원: 사직단 — 용정마을에 사직단(전북일보) → 용정동(35.4331,127.3823) 쪽, 성 북쪽 산기슭. 성황사 — '성황단길'(OSM, 성 서쪽) 근처
    yj = xz(35.4331024, 127.3823458)
    add_fac("namwon_sajikdan", "남원부 사직단", "landmark/sajikdan", site(yj[0], yj[1] + 60, 180, 0, 160, 0.2, 180), "추정",
            ["전북일보: 용정마을에 (남원향교와 연관된) 사직단", "OSM 용정동 35.4331,127.3823"], "원칙(성 서쪽)과 달리 문헌·지명이 성 북쪽 용정동을 가리켜 그쪽에 둠. 단(壇)·담장 약 20×20m.", [20, 20])
    add_fac("namwon_yeodan", "남원부 여단", "landmark/yeodan", site(NW_C[0], NW_C[1] - 93, 180, 60, 180, 0.2, 40), "가설",
            ["원칙: 읍성 북쪽 교외(문헌 미확인)"], "여제단. 약 14×14m.", [14, 14])
    sh = xz(35.40931, 127.36959)
    add_fac("namwon_seonghwangsa", "남원 성황사(성황단)", "landmark/seonghwangsa", site(sh[0], sh[1], 270, 0, 120, 0.35, 180, "high"), "추정",
            ["OSM 도로명 '성황단길'(35.40931,127.36959) — 성 서쪽 산기슭", "원칙: 진산(교룡산) 쪽 기슭"], "성황당 사당 약 10×8m + 마당. 지명 근거로 성 서쪽.", [16, 14])
    # 운봉: 원칙대로
    add_fac("unbong_sajikdan", "운봉현 사직단", "landmark/sajikdan", site(UB_C[0], UB_C[1], 270, 60, 180, 0.2, 45), "가설", ["원칙: 읍치 서쪽(문헌 미확인)"], "약 20×20m.", [20, 20])
    add_fac("unbong_yeodan", "운봉현 여단", "landmark/yeodan", site(UB_C[0], UB_C[1], 180, 60, 180, 0.2, 45), "가설", ["원칙: 읍치 북쪽(문헌 미확인)"], "약 14×14m.", [14, 14])
    add_fac("unbong_seonghwangsa", "운봉 성황사", "landmark/seonghwangsa", site(UB_C[0], UB_C[1], (math.degrees(math.atan2(jin_ub[0] - UB_C[0], jin_ub[1] - UB_C[1])) + 360) % 360, 80, 150, 0.25, 35, "high"), "가설",
            ["원칙: 진산 기슭(문헌 미확인)"], "진산에서 읍치 쪽으로 내려온 완경사 기슭(읍치에서 80~150m). 약 16×14m.", [16, 14])
    lms.extend(new_lm); L.update({l_["id"]: l_ for l_ in new_lm})
    # 오솔길(산길): 가장 가까운 길에서 시설 앞(남쪽 10m)까지
    for l_ in new_lm:
        tgt = (l_["x"], l_["z"] + l_["size_m"][1] / 2 + 6)
        best = None
        for r_ in roads:
            if r_["class"] == "산길": continue
            p_ = np.asarray(r_["points"]); d_ = np.hypot(p_[:, 0] - tgt[0], p_[:, 1] - tgt[1]); k_ = int(np.argmin(d_))
            if best is None or d_[k_] < best[0]: best = (d_[k_], tuple(p_[k_]), r_["id"])
        pts = R.route(cost, [best[1], tgt]); pts, _ = R.fix_water_runs(pts, RI); pts = R.remove_loops(pts)
        roads.append(dict(id=f"path_{l_['id']}", name=f"{l_['name']} 오솔길", **{"class": "산길"}, width_m=1.5,
                          points=[[round(float(q[0]), 1), round(float(q[1]), 1)] for q in pts], confidence=l_["confidence"],
                          source=["제향 시설 진입로(가설)"], notes=f"{best[2]}에서 갈라짐."))
        say("fac", l_["id"], l_["x"], l_["z"], "path", len(pts))

    # ── 도강점: 도로×하천 교차 전부
    crossings = []
    hits = []
    for rd in roads:
        for r in rivers:
            for (x, z, ia, ib) in seg_intersections(rd["points"], r["points"]):
                des = None
                for c in designated:
                    if c["river_id"] == r["id"] and c["road_id"] == rd["id"] and math.hypot(c["pos"][0] - x, c["pos"][1] - z) < 40:
                        des = c
                hits.append((rd, r, x, z, des))
    hits.sort(key=lambda h_: h_[4] is None)          # 지정 도강점을 먼저 기록
    for rd, r, x, z, des in hits:
        if True:
            if True:
                near_c = [c for c in crossings if c["river_id"] == r["id"] and math.hypot(c["x"] - x, c["z"] - z) < 12]
                if near_c:
                    if near_c[0]["road_id"] != rd["id"]:
                        near_c[0].setdefault("shared_roads", []).append(rd["id"])
                    continue
                if des and any(c["id"] == des["id"] for c in crossings):
                    n_same = sum(1 for c in crossings if c["id"].startswith(des["id"]))
                    crossings.append(dict(id=f"{des['id']}_{n_same + 1}", name=des["name"] + f" ({n_same + 1})", type=des["type"], river_id=r["id"], road_id=rd["id"],
                                          x=round(x, 1), z=round(z, 1), confidence=des["confidence"], notes="같은 건널목 근처에서 굽이를 한 번 더 건넘"))
                    continue
                if des:
                    crossings.append(dict(id=des["id"], name=des["name"], type=des["type"], river_id=r["id"], road_id=rd["id"],
                                          x=round(x, 1), z=round(z, 1), confidence=des["confidence"], notes=des["notes"]))
                else:
                    typ = {"B": "나루" if r["id"] == "yocheon" else "섶다리", "C": "징검다리", "D": "여울"}[r["grade"]]
                    if r["grade"] == "D" and rd["class"] == "대로": typ = "돌다리"
                    crossings.append(dict(id=f"x_{rd['id'][:10]}_{r['id']}_{len(crossings)}", name=f"{r['name']} 건널목", type=typ,
                                          river_id=r["id"], road_id=rd["id"], x=round(x, 1), z=round(z, 1), confidence="가설",
                                          notes="자동: 등급별 기본 형식(B=요천 나루·그 밖 섶다리, C=징검다리, D=여울/대로는 돌다리) — 가설"))
    # 지정했으나 길이 안 지나간 도강점 경고
    missing = [c["id"] for c in designated if not any(x["id"] == c["id"] for x in crossings)]

    # ── 길 바닥 고르기 (하천 피해서)
    say("길 바닥")
    y2 = C.alt_to_y(alt2).astype(np.float64)
    y2 = road_grade(y2, roads, d2, HW2)

    # ── 고개: 지정 + 도로 고도 단면의 뚜렷한 고점(돌출 ≥ 25m 실제)
    passes = [dict(id="yeowonjae", name="여원재(여원치)", x=PASS_YW[0], z=PASS_YW[1], y=None, confidence="확정",
                   source=P.PASSES[0]["source"], notes="백두대간 — 서쪽 요천(섬진강)·동쪽 람천(낙동강) 분수계")]
    hy2 = lambda x, z: C.bilinear(y2, *C.xz_to_ij(np.asarray(x), np.asarray(z)))
    _dr4 = ndimage.distance_transform_edt(~(wm["B"] | wm["C"] | wm["D"])) * C.LU_CELL
    rdist4 = lambda x, z: C.bilinear(_dr4, *C.xz_to_ij(np.asarray(x), np.asarray(z), C.LU_CELL))
    for rd in roads:
        for (px, pz, ph) in R.profile_peaks(rd["points"], hy2, prom_real=35.0, rdist=rdist4):
            near = [q for q in passes if math.hypot(q["x"] - px, q["z"] - pz) < 260]
            if near:
                q = near[0]
                continue
            passes.append(dict(id=f"pass_{rd['id'][:12]}_{len(passes)}", name="무명 고개", x=round(px, 1), z=round(pz, 1), y=None,
                               confidence="가설", source=["도로 고도 단면의 안장(자동)"], notes=f"{rd['name']} 위"))
    for q in passes:
        fi, fj = C.xz_to_ij(q["x"], q["z"]); q["y"] = round(float(C.bilinear(y2, fi, fj)), 2)

    # ── 토지이용 + 자동 마을
    say("토지이용")
    y4 = y2[::2, ::2]
    lu, autos, info = LU.classify(y4, rivers, roads, sets)
    for n, (x, z) in enumerate(autos):
        sets.append(dict(id=f"auto_village_{n:02d}", name=f"들마을 후보 {n + 1}", type="마을", x=round(x, 1), z=round(z, 1), radius_m=32, size="S",
                         notes="입지 규칙(산기슭·남향·아래 논) 자동 후보", confidence="가설",
                         source=["명세서 §24 산→마을→밭→논→하천 입지 규칙(자동)"]))
    say("autos", len(autos))
    for s_ in sets:
        sh = info["shapes"].get(s_["id"])
        if sh:
            s_["area_m2"] = sh["area_m2"]; s_["extent_m"] = sh["extent_m"]; s_["bbox"] = sh["bbox"]
            s_["radius_m"] = round(math.sqrt(sh["area_m2"] / math.pi), 1)
    # 랜드마크 바닥: 건물 = 마을 터(6), 광한루·오작교 둘레 = 풀밭 정원(1)
    jj4, ii4 = np.mgrid[0:lu.shape[0], 0:lu.shape[1]]; xs4, zs4 = C.ij_to_xz(ii4, jj4, C.LU_CELL)
    for l in lms:
        if not l.get("size_m") or l["id"] == "namwon_eupseong": continue
        hx, hz = l["size_m"][0] / 2 + 4, l["size_m"][1] / 2 + 4
        if l["id"] in ("gwanghallu", "ojakgyo"): hx, hz = 45, 30
        m = (np.abs(xs4 - l["x"]) <= hx) & (np.abs(zs4 - l["z"]) <= hz) & (lu != LU.WATER)
        lu[m] = LU.GRASS if l["id"] in ("gwanghallu", "ojakgyo") else LU.VILLAGE
    for s_ in sets:
        if s_["id"].startswith("auto_village") and s_["id"] in info["shapes"]:
            sh = info["shapes"][s_["id"]]; s_["area_m2"] = sh["area_m2"]; s_["extent_m"] = sh["extent_m"]; s_["bbox"] = sh["bbox"]
            s_["radius_m"] = round(math.sqrt(sh["area_m2"] / math.pi), 1)
    # 마을 바닥 살짝 고르기
    flatten_alt = (y2 / C.K + C.Y_BASE_ALT)
    flatten_pads(flatten_alt, [(x, z, 22) for x, z in autos], river_keep)
    y2 = C.alt_to_y(flatten_alt)

    # ── 쓰기
    # ── 길이 도강점 밖에서 물 칸·수면 아래를 지나지 않게(QR): 길 칸을 수면+0.3 이상 둑으로 돋우고 landuse 4로
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
    rm2 = road_mask(C.CELL); rm2w = road_mask(C.CELL, 4.0); cz2 = cross_zone(C.CELL, 8.0)
    near_r = d2 <= HW2 + 12.0
    SVm = SV2
    fix = rm2w & ~cz2 & near_r & (d2 > HW2) & (y2 < SVm + 0.35)        # 물길 안은 돋우지 않음(물을 막지 않게)
    n_fix = int((rm2 & ~cz2 & near_r & (d2 > HW2) & (y2 < SVm + 0.35)).sum())
    y2 = np.where(fix, SVm + 0.35, y2)
    y2 = np.where(ndimage.binary_dilation(fix, iterations=2) & ~fix, ndimage.uniform_filter(y2, 3), y2)
    # 마무리: QA(QR)와 같은 기준(2m 최근접 중심선 수면)으로 길 표본마다 한 번 더 확인해 둑 위로
    drq, rsq, rhwq, _ = LU.river_fields(rivers, y2.shape, G=C.CELL)
    rmap = {r_["id"]: r_ for r_ in rivers}; n_last = 0
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
    say("길 둑 마무리", n_last, "칸")
    rm4 = road_mask(C.LU_CELL, 8.0); cz4 = cross_zone(C.LU_CELL, 8.0)
    n_lu = int((rm4 & ~cz4 & (lu == LU.WATER)).sum())
    lu[rm4 & ~cz4 & (lu == LU.WATER)] = LU.ROAD
    # 길 칸 빈틈없이(QL): 중심선 0.5m 표본 → 4m 격자 거리장, 칸 중심이 width/2 + 칸 반대각(2.83m) 안이면 길.
    #  도강점 구간의 물 칸(5)은 그대로(건너는 자리는 물로 남김).
    cl4 = np.zeros(lu.shape, bool); hw4 = np.zeros(lu.shape)
    for r_ in roads:
        p_ = np.asarray(r_["points"], float); sg_ = np.hypot(*np.diff(p_, axis=0).T); ss_ = np.concatenate([[0], np.cumsum(sg_)])
        tt_ = np.arange(0, ss_[-1] + 1e-6, 0.5)
        i_, j_ = C.xz_to_ij(np.interp(tt_, ss_, p_[:, 0]), np.interp(tt_, ss_, p_[:, 1]), C.LU_CELL)
        i_ = np.clip(np.round(i_).astype(int), 0, lu.shape[1] - 1); j_ = np.clip(np.round(j_).astype(int), 0, lu.shape[0] - 1)
        cl4[j_, i_] = True; hw4[j_, i_] = np.maximum(hw4[j_, i_], r_["width_m"] / 2)
    dl4, (nj4, ni4) = ndimage.distance_transform_edt(~cl4, return_indices=True)
    road4 = dl4 * C.LU_CELL <= hw4[nj4, ni4] + C.LU_CELL * 0.71
    keep_w = cz4 & (lu == LU.WATER)
    n_road = int((road4 & ~keep_w & (lu != LU.ROAD)).sum())
    lu[road4 & ~keep_w] = LU.ROAD
    say("길 칸 채움", n_road, "칸(4m) 새로 4")
    say("길 둑 보정", n_fix, "칸(2m) 돋움,", n_lu, "칸(4m) 물→길")
    hm = export.write_height(y2.astype(np.float32))
    lum = export.write_landuse(lu)
    sx, sz = L["namwon_south_gate"]["x"], L["namwon_south_gate"]["z"] + 25
    for l in lms:
        fi, fj = C.xz_to_ij(l["x"], l["z"]); l["y"] = round(float(C.bilinear(y2, fi, fj)), 2)
    reg = dict(
        region_id=C.REGION_ID, region_name="남원·운봉·지리산 서부", parent_province="전라도", level=2,
        main_river="요천", connected_river=["섬진강(권역 밖)", "람천→임천→남강→낙동강(권역 밖)"],
        watershed_divide="백두대간(여원재–고남산–수정봉 선): 서쪽 요천·섬진강 / 동쪽 운봉고원 람천·낙동강",
        main_mountain=["지리산(서북 사면: 바래봉·덕두산·만복대·정령치)", "백두대간 주능선(고남산·여원재·수정봉)"],
        settlement_type="도호부 읍성 + 고원 현 읍치 + 역·장 + 산촌·평지 사찰",
        landmark=[l["name"] for l in lms],
        transport=dict(roads=[r["name"] for r in roads if r["class"] in ("대로", "지선")], crossings=[c["name"] for c in crossings if not c["id"].startswith("x_")]),
        economy=["논농사(요천 들·운봉 고원)", "밭농사", "장시(남원·운봉·인월)", "산간 임산물"],
        forbidden=["현대 제방", "직강 하천", "댐·저수지 호수", "고속도로·국도 성토", "철도", "현대 남원 시가지"],
        status="초안(에이전트 생성 — 역사지리 검수 전)",
        sources=["AWS Terrain Tiles terrarium z13 (SRTM 등 공개 DEM 합성; Mapzen/AWS Open Data)",
                 "OpenStreetMap(© OSM contributors, ODbL) — 하천선·지명 위치·현대 시설(제거용) 참고",
                 "위키백과 '남원읍성'", "한국민족문화대백과(E0012066 남원용성초등학교, E0067255 여원치 마애불)",
                 "한국관광공사 '황산대첩비지'", "대동여지도 해당 첩(디지타이징 대기)", "읍지(용성지 등, 검수 필요)"],
        projection=dict(lat0=C.LAT0, lon0=C.LON0, K=C.K, y_base_alt=C.Y_BASE_ALT,
                        formula="x=(lon-lon0)*cos(lat0)*111320*K, z=-(lat-lat0)*110574*K, y=(alt-60)*K"),
        axes=axes,
        height=hm, landuse=lum, rivers=rivers, roads=roads, passes=passes,
        crossings=crossings, settlements=sets, landmarks=lms,
        spawn=dict(x=sx, z=sz, note=P.SPAWN_NOTE),
        modern_fixes=mlog, hydro=dict(remeandered=hlog["remeandered"], counts=hlog["counts"], acc_thresholds_km2=hlog["acc_thresholds_km2"]),
        build=dict(tool="tools/region/build.py", warnings=[f"지정 도강점을 길이 지나지 않음: {m}" for m in missing]),
    )
    export.write_region(reg)
    np.save(os.path.join(C.CACHE, "basin_dirn.npy"), dirn)
    np.save(os.path.join(C.CACHE, "alt_fixed.npy"), alt1); np.save(os.path.join(C.CACHE, "res_mask.npy"), res_mask)
    say("done", hm["y_min"], hm["y_max"], "missing", missing)

if __name__ == "__main__":
    main()
