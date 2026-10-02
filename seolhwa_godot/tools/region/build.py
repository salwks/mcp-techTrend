"""권역 데이터 전체 빌드: DEM → 현대 흔적 제거 → 수계·깎기 → 도로(A*) → 고개·도강점 → 토지이용·마을 → region.json.
실행: python3 tools/region/build.py   (먼저 fetch_dem.py, osm_fetch.py — 캐시가 있으면 생략)"""
import json, math, os, sys, time
import numpy as np
from scipy import ndimage
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

    # 2m 격자 하천 거리
    surf2 = np.zeros(alt2.shape, bool); hw2 = np.zeros(alt2.shape)
    for r in rivers:
        p = np.array(r["points"]); seg = np.hypot(*np.diff(p[:, :2], axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
        t = np.arange(0, s[-1], 1.0); x = np.interp(t, s, p[:, 0]); z = np.interp(t, s, p[:, 1])
        i, j = C.xz_to_ij(x, z); i = np.clip(np.round(i).astype(int), 0, alt2.shape[1] - 1); j = np.clip(np.round(j).astype(int), 0, alt2.shape[0] - 1)
        surf2[j, i] = True; hw2[j, i] = np.maximum(hw2[j, i], r["width_m"] / 2)
    d2, (nj, ni) = ndimage.distance_transform_edt(~surf2, return_indices=True)
    d2 = d2 * C.CELL; HW2 = hw2[nj, ni]
    river_keep = np.clip(1 - (d2 - HW2 - 3) / 8.0, 0, 1)
    # 확정이 아닌 마을 자리를 사람이 살 만한 땅(완경사·골 바닥 가까이·물가 아님)으로 최대 250m(게임) 옮김
    yy = C.alt_to_y(alt2); gz_, gx_ = np.gradient(ndimage.uniform_filter(yy, 5), C.CELL); slp = np.hypot(gx_, gz_)
    for s_ in sets:
        if s_["confidence"] == "확정" or s_["type"] in ("성황당", "읍성", "사찰") or s_["id"].startswith("namwon"): continue
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
        dict(id="ramcheon_unbong_ford", name="람천 운봉 동쪽 징검다리", type="징검다리", river_id="ramcheon", road_id="tongyeong_byeolro",
             pos=on_river("ramcheon", 35.4470, 127.5400), confidence="가설", notes="고원 위 람천은 폭이 좁고 얕다."),
        dict(id="haetal_bridge", name="실상사 앞 해탈교 자리", type="섶다리", river_id="ramcheon", road_id="inwol_banseon_road",
             pos=on_river("ramcheon", 35.4163, 127.6355), confidence="추정",
             notes="OSM 'Haetal Bridge'(현대 다리) 자리 — 1870년 다리 형식은 가설(섶다리/외나무다리)."),
    ]
    cross_xz = [c["pos"] for c in designated]
    PASS_YW = xz(35.4470, 127.5013)

    # ── 도로
    say("도로 A*")
    y4 = C.alt_to_y(alt2[::2, ::2])
    wm = R.river_masks(rivers, y4.shape)
    cost, slope4 = R.cost_field(y4, wm, cross_xz)
    eg = L["namwon_east_gate"]; sg = L["namwon_south_gate"]; ng = L["namwon_north_gate"]; wg = L["namwon_west_gate"]
    D = {c["id"]: c["pos"] for c in designated}
    road_defs = [
        dict(id="tongyeong_byeolro", name="통영별로(남원→여원재→운봉→인월→함양)", cls="대로", width=5.0,
             wps=[(eg["x"], eg["z"]), (eg["x"] + 20, eg["z"]), D["yocheon_east_ford"], (S["ibaek"]["x"], S["ibaek"]["z"]), (S["yeowon_jumak"]["x"], S["yeowon_jumak"]["z"]), PASS_YW,
                  (S["unbong_eup"]["x"], S["unbong_eup"]["z"]), D["ramcheon_unbong_ford"], (S["bijeon"]["x"], S["bijeon"]["z"]),
                  (S["inwol_yeok"]["x"], S["inwol_yeok"]["z"]), xz(35.4700, 127.6597)],
             source=["신경준 『도로고』 통영별로(전주–남원–운봉–함양–…–통영) 노선 체계(지식 기반, 원문 대조 필요)", "여원치: 한국민족문화대백과 E0067255"],
             confidence="추정", notes="경로 세부는 A*(경사·하천 비용). 경유 순서(남원→여원재→운봉→황산 앞→인월→함양)만 고증."),
        dict(id="inwol_banseon_road", name="인월–실상사–산내–반선 길", cls="지선", width=3.5,
             wps=[(S["inwol_yeok"]["x"], S["inwol_yeok"]["z"]), D["haetal_bridge"], (L["silsangsa"]["x"], L["silsangsa"]["z"] + 70),
                  (S["sannae"]["x"], S["sannae"]["z"]), (S["banseon"]["x"], S["banseon"]["z"])],
             source=["실상사·산내·반선 위치(OSM)", "만수천 계곡을 따르는 길(지형 필연, 가설)"], confidence="가설", notes=""),
        dict(id="namwon_gurye_road", name="남원 남문–광한루–요천 나루–구례 방면 길", cls="지선", width=3.5,
             wps=[(sg["x"], sg["z"] + 8), (L["gwanghallu"]["x"] + 40, L["gwanghallu"]["z"] - 15), D["yocheon_south_naru"], xz(35.3545, 127.4000)],
             source=["광한루가 남문 밖 요천가에 있음(OSM 위치)"], confidence="가설", notes="권역 밖 구례 방면 노선은 노정 담당이 이어 받음."),
        dict(id="namwon_north_road", name="남원 북문–전주 방면 길(통영별로 북쪽)", cls="대로", width=5.0,
             wps=[(ng["x"], ng["z"] - 8), (S["namwon_hyanggyo"]["x"] + 30, S["namwon_hyanggyo"]["z"] + 10), xz(35.4805, 127.3720)],
             source=["통영별로는 전주–임실–오수–남원으로 내려옴(지식 기반)"], confidence="가설", notes="북쪽 권역 경계는 노정(남원→전주) 포털."),
        dict(id="namwon_eup_street", name="남원 읍내 남북길(북문–남문)", cls="마을길", width=4.0,
             wps=[(ng["x"], ng["z"] + 6), (sg["x"], sg["z"] - 6)], source=["방형 읍성 십자가로 일반형"], confidence="가설", notes="읍성 안 십자로(남북)."),
        dict(id="namwon_eup_street_ew", name="남원 읍내 동서길(서문–동문)", cls="마을길", width=4.0,
             wps=[(wg["x"] + 6, wg["z"]), (eg["x"] - 6, eg["z"])], source=["방형 읍성 십자가로 일반형"], confidence="가설", notes="읍성 안 십자로(동서)."),
        dict(id="namwon_market_lane", name="남문 밖 장터길", cls="마을길", width=3.0,
             wps=[(sg["x"], sg["z"] + 8), (S["namwon_jang"]["x"], S["namwon_jang"]["z"]), (wg["x"] - 6, wg["z"])], source=["가설"], confidence="가설", notes=""),
        dict(id="unbong_eup_street", name="운봉 읍내길(관아–장터–큰길)", cls="마을길", width=3.0,
             wps=[(L["unbong_gwana"]["x"], L["unbong_gwana"]["z"] + 20), (S["unbong_jang"]["x"], S["unbong_jang"]["z"]), (S["unbong_eup"]["x"] - 40, S["unbong_eup"]["z"] + 30)],
             source=["가설"], confidence="가설", notes="읍치 안길. 통영별로에 붙음."),
        dict(id="baemsagol_trail", name="반선–뱀사골 산길", cls="산길", width=1.5,
             wps=[(S["banseon"]["x"], S["banseon"]["z"]), xz(35.3560, 127.5880)], source=["뱀사골(OSM 계곡선)"], confidence="가설", notes="화개재 방면 계곡 길."),
    ]
    roads = []
    for rd in road_defs:
        pts = R.route(cost, rd["wps"])
        roads.append(dict(id=rd["id"], name=rd["name"], **{"class": rd["cls"]}, width_m=rd["width"],
                          points=[[round(float(p[0]), 1), round(float(p[1]), 1)] for p in pts],
                          confidence=rd["confidence"], source=rd["source"], notes=rd["notes"]))
        say("road", rd["id"], len(pts))

    # ── 도강점: 도로×하천 교차 전부
    crossings = []
    for rd in roads:
        for r in rivers:
            for (x, z, ia, ib) in seg_intersections(rd["points"], r["points"]):
                des = None
                for c in designated:
                    if c["river_id"] == r["id"] and math.hypot(c["pos"][0] - x, c["pos"][1] - z) < 40:
                        des = c
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
    for rd in roads:
        for (px, pz, ph) in R.profile_peaks(rd["points"], hy2, prom_real=35.0):
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
    # 랜드마크 바닥: 건물 = 마을 터(6), 광한루·오작교 둘레 = 풀밭 정원(1)
    jj4, ii4 = np.mgrid[0:lu.shape[0], 0:lu.shape[1]]; xs4, zs4 = C.ij_to_xz(ii4, jj4, C.LU_CELL)
    for l in lms:
        if not l.get("size_m") or l["id"] == "namwon_eupseong": continue
        hx, hz = l["size_m"][0] / 2 + 4, l["size_m"][1] / 2 + 4
        if l["id"] in ("gwanghallu", "ojakgyo"): hx, hz = 45, 30
        m = (np.abs(xs4 - l["x"]) <= hx) & (np.abs(zs4 - l["z"]) <= hz) & (lu != LU.WATER)
        lu[m] = LU.GRASS if l["id"] in ("gwanghallu", "ojakgyo") else LU.VILLAGE
    # 마을 바닥 살짝 고르기
    flatten_alt = (y2 / C.K + C.Y_BASE_ALT)
    flatten_pads(flatten_alt, [(x, z, 22) for x, z in autos], river_keep)
    y2 = C.alt_to_y(flatten_alt)

    # ── 쓰기
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
