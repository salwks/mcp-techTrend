"""data-north 뒷손질(build.py <ID> · render.py <ID> 뒤): region.json·height.png·overview.png 보강.
  - 큰 강(S급): build_region의 '바다' 경로로 만든 물면을 강으로 표시(sea.kind="river"), 큰 강 나루(crossings_big)를 도로×물면 교차점에 기록
  - 큰 강을 건너는 길 밑이 물 위로 돋워지지 않게(나룻배 길) 물면 칸 높이를 강바닥으로 되돌림
  - 성곽 선(walls): 설정 north.walls(위경도 꺾은선) 또는 한양도성 OSM 선 → 게임 좌표, 길×성벽 교차가 문 근처인지 검사(QW-north)
  - overview.png·zoom에 성곽 선을 덧그림
  - 닫힌 성곽(도성·내성·읍성) 안 낮은 땅의 논·밭·풀밭을 마을 터(6)로(성 안은 시가지 — 논이 비쳐 보이지 않게). 물·길·숲(산)·바위는 그대로
실행: python3 tools/region/north_post.py <ID>
      python3 tools/region/north_post.py <ID> --town-only   (성 안 마을 터 칠하기만 — 이미 뒷손질한 데이터에 다시 돌릴 때)"""
import json, math, os, sys, importlib
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import common as C, export

RID = C.REGION_ID
CFG = C.CFG
MOD = {"GG_HANYANG": "north_places_gg", "HH_HWANGJU": "north_places_hh", "PA_PYEONGYANG": "north_places_pa", "HG_HAMHEUNG": "north_places_hg"}[RID]
P = importlib.import_module(MOD)
def say(*a): print(f"[north_post {RID}]", *a, flush=True)

def xz(lat, lon):
    x, z = C.geo_to_game(lat, lon); return [round(float(x), 1), round(float(z), 1)]

def seg_x(a, b):
    out = []
    a = np.asarray(a, float); b = np.asarray(b, float)
    for i in range(len(a) - 1):
        p, r = a[i], a[i + 1] - a[i]; q = b[:-1]; s = b[1:] - b[:-1]
        den = r[0] * s[:, 1] - r[1] * s[:, 0]; ok = np.abs(den) > 1e-9; qp = q - p
        t = np.where(ok, (qp[:, 0] * s[:, 1] - qp[:, 1] * s[:, 0]) / np.where(ok, den, 1), -1)
        u = np.where(ok, (qp[:, 0] * r[1] - qp[:, 1] * r[0]) / np.where(ok, den, 1), -1)
        for k in np.nonzero(ok & (t >= 0) & (t <= 1) & (u >= 0) & (u <= 1))[0]:
            out.append(tuple(p + t[k] * r))
    return out

def hanyang_wall():
    """OSM '한양도성' 선 점 + 기준점을 성 중심 둘레 각도로 정렬 → 고리(가설: 멸실 구간 직선)."""
    d = json.load(open(os.path.join(C.CACHE, "osm_walls.json")))
    pts = []
    for e in d["elements"]:
        t = e.get("tags", {})
        if "도성" not in (t.get("name") or ""): continue
        pts += [(p["lat"], p["lon"]) for p in e.get("geometry", [])]
    pts += [(la, lo) for _, la, lo in P.WALL_KEYPOINTS]
    g = np.array([xz(a, b) for a, b in pts]); g = np.unique(np.round(g / 4) * 4, axis=0)
    # 기준점 순서(시계 방향)로 구간을 나누고, 구간마다 두 기준점 사이 띠(폭 120m) 안 OSM 점을 진행 방향으로 정렬
    K_ = [np.array(xz(la, lo)) for _, la, lo in P.WALL_KEYPOINTS]
    out = []
    for k in range(len(K_)):
        A, B = K_[k], K_[(k + 1) % len(K_)]
        d = B - A; L = np.linalg.norm(d); u = d / L; n = np.array([-u[1], u[0]])
        t = (g - A) @ u; o = (g - A) @ n
        sel = (t > 0) & (t < L) & (np.abs(o) < max(60.0, 0.35 * L))
        seg = g[sel][np.argsort(t[sel])]
        out.append(A); out += list(seg)
    g = np.array(out)
    # 20m(게임) 간격으로 줄임
    out = [g[0]]
    for p in g[1:]:
        if math.hypot(p[0] - out[-1][0], p[1] - out[-1][1]) >= 20: out.append(p)
    out.append(out[0])
    return [[round(float(a), 1), round(float(b), 1)] for a, b in out]

def fix_dirn(px, pz, sea):
    """QA 유역 검사용 흐름 방향(cache basin_dirn.npy, 8m): 큰 강 물면 칸은 중심선을 따라 하류 끝으로 흐르게(바다 경로라 방향이 없던 칸)."""
    p_ = os.path.join(C.CACHE, "basin_dirn.npy"); dirn = np.load(p_)
    HC = C.CELL * 4; Hh, Ww = dirn.shape
    NB = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
    seg = np.hypot(np.diff(px), np.diff(pz)); s_ = np.concatenate([[0], np.cumsum(seg)]); t = np.arange(0, s_[-1], HC / 3)
    ci = np.clip(np.round((np.interp(t, s_, px) - C.X0) / HC).astype(int), 0, Ww - 1); cj = np.clip(np.round((np.interp(t, s_, pz) - C.Z0) / HC).astype(int), 0, Hh - 1)
    chain = []
    for a, b in zip(cj, ci):
        if not chain or chain[-1] != (a, b): chain.append((a, b))
    onc = np.zeros(dirn.shape, bool)
    for k, (a, b) in enumerate(chain):
        onc[a, b] = True
        if k + 1 < len(chain):
            na, nb = chain[k + 1]; dj, di = int(np.sign(na - a)), int(np.sign(nb - b))
            if (dj, di) != (0, 0): dirn[a, b] = NB.index((dj, di))
        else:   # 마지막 칸: 가장 가까운 가장자리 밖으로
            dj = -1 if a == 0 else 1 if a == Hh - 1 else 0; di = -1 if b == 0 else 1 if b == Ww - 1 else 0
            if (dj, di) == (0, 0): di = 1
            dirn[a, b] = NB.index((dj, di))
    sea8 = sea[::4, ::4][:Hh, :Ww]
    from collections import deque
    seen = onc.copy(); dq = deque(chain)
    while dq:          # 중심선에서 물면 칸으로 너비 우선 — 각 칸은 부모(중심선 쪽)를 가리킴
        a, b = dq.popleft()
        for k, (dj, di) in enumerate(NB):
            na, nb_ = a + dj, b + di
            if 0 <= na < Hh and 0 <= nb_ < Ww and sea8[na, nb_] and not seen[na, nb_]:
                seen[na, nb_] = True; dirn[na, nb_] = NB.index((-dj, -di)); dq.append((na, nb_))
    np.save(p_, dirn)

FERRY = {r["id"] for r in P.ROADS if r.get("ferry")}

TOWN_FROM = (1, 2, 3)        # 풀밭·논·밭 → 마을 터(6). 숲(0, 백악·남산·인왕 기슭)·길(4)·물(5)·바위(7)·모래(8)·대숲(9)은 그대로
TOWN_MAX_SLOPE = 0.22        # tan — 성 안이라도 산기슭 비탈 밭은 남긴다

def town_inside_walls(reg):
    """닫힌 성곽 고리 안 낮은 땅의 논·밭·풀밭을 마을 터(6)로 칠한다. 여러 번 돌려도 같다."""
    lu_p = os.path.join(C.OUT, "landuse.png"); lu = np.array(Image.open(lu_p))
    lp = reg["landuse"]; x0, z0, c = float(lp["x0"]), float(lp["z0"]), float(lp["cell"])
    y, _ = export.read_height()
    hp = reg["height"]; hc = float(hp["cell"])
    gz, gx = np.gradient(y, hc)
    sl = np.hypot(gx, gz)
    k = max(1, int(round(c / hc)))
    sl = sl[::k, ::k][:lu.shape[0], :lu.shape[1]]          # 높이 2m 격자 → 토지이용 4m 격자(같은 원점)
    total = 0
    for w in reg.get("walls", []):
        if not w.get("closed"): continue
        m = Image.new("L", (lu.shape[1], lu.shape[0]), 0)
        ImageDraw.Draw(m).polygon([((x - x0) / c, (z - z0) / c) for x, z in w["points"]], fill=1)
        m = ndimage.binary_erosion(np.array(m).astype(bool), iterations=2)   # 성벽 띠(대신 벽·여장)는 건드리지 않음
        sel = m & np.isin(lu & 127, TOWN_FROM) & (sl < TOWN_MAX_SLOPE)
        lu[sel] = (lu[sel] & 128) | 6
        total += int(sel.sum())
        say("성 안 마을 터", w["id"], int(sel.sum()), "칸")
    Image.fromarray(lu.astype(np.uint8), mode="L").save(lu_p, optimize=True)
    return total

def main():
    reg = json.load(open(os.path.join(C.OUT, "region.json")))
    if "--town-only" in sys.argv:
        town_inside_walls(reg); return
    y, hm = export.read_height()
    sea = np.load(os.path.join(C.CACHE, "sea.npy")) if os.path.exists(os.path.join(C.CACHE, "sea.npy")) else None
    big = [r for r in P.RIVER_CONTROL.values() if r["grade"] == "S"]
    # ── 큰 강
    if sea is not None and sea.any() and big:
        reg["sea"]["kind"] = "river"
        reg["sea"]["note"] = ("바다가 아니라 큰 강(S급: " + "·".join(r["name"] for r in big) + ") 물면이다. 권역 안 수면 경사는 무시하고 y(해발 0m 기준 평면)로 그린다. "
                              "landuse 5(물) 중 하천선이 아닌 칸. 섬(하중도)은 뭍으로 남겼다. 바닥 해발 −1.5…−6m. 물결은 강물(느린 흐름)로.")
        reg["big_rivers"] = [dict(id=rid, name=r["name"], grade="S", flows_to=r["flows_to"], islands=[i[0] for i in r.get("islands", [])],
                                  confidence="추정", source=r.get("source", []), notes=r.get("notes", "")) for rid, r in P.RIVER_CONTROL.items() if r["grade"] == "S"]
        # 큰 강 중심선을 rivers에 S급으로 넣음(엔진·QA가 강으로 알게): 수면 = 물면 y, 폭 = 물면 넓이/길이
        reg["rivers"] = [r_ for r_ in reg["rivers"] if r_.get("spec_grade") != "S" and r_.get("grade") != "S"]
        for rid_, r in P.RIVER_CONTROL.items():
            if r["grade"] != "S": continue
            la = np.array([c[0] for c in r["ctrl"]]); lo = np.array([c[1] for c in r["ctrl"]])
            cx, cz = C.geo_to_game(la, lo); seg = np.hypot(np.diff(cx), np.diff(cz)); s_ = np.concatenate([[0], np.cumsum(seg)])
            t = np.arange(0, s_[-1], 8.0); px = np.interp(t, s_, cx); pz = np.interp(t, s_, cz)
            inside = (np.abs(px) <= -C.X0) & (np.abs(pz) <= -C.Z0)
            px, pz = px[inside], pz[inside]
            width = float(sea.sum() * C.CELL ** 2 / max(len(px) * 8.0, 1))
            # 중심선을 물면 가운데로 끌어당김(섬은 피해서 넓은 물길 쪽으로)
            Rr = int(max(width, 20) * 0.8 / C.CELL)
            for _ in range(4):
                for q in range(len(px)):
                    i0, j0 = int((px[q] - C.X0) / C.CELL), int((pz[q] - C.Z0) / C.CELL)
                    sub = sea[max(j0 - Rr, 0):j0 + Rr + 1, max(i0 - Rr, 0):i0 + Rr + 1]
                    if sub.sum() < 4: continue
                    jj, ii = np.nonzero(sub)
                    px[q] = C.X0 + (ii.mean() + max(i0 - Rr, 0)) * C.CELL; pz[q] = C.Z0 + (jj.mean() + max(j0 - Rr, 0)) * C.CELL
                px = ndimage.gaussian_filter1d(px, 3, mode="nearest"); pz = ndimage.gaussian_filter1d(pz, 3, mode="nearest")
            # 뭍(섬·모래톱) 위 점은 가장 가까운 물면 칸으로
            er2 = ndimage.binary_erosion(sea, iterations=3)
            _, (nj_, ni_) = ndimage.distance_transform_edt(~er2, return_indices=True)
            for q in range(len(px)):
                j_ = int(np.clip((pz[q] - C.Z0) / C.CELL, 0, sea.shape[0] - 1)); i_ = int(np.clip((px[q] - C.X0) / C.CELL, 0, sea.shape[1] - 1))
                if not er2[j_, i_]: px[q] = C.X0 + ni_[j_, i_] * C.CELL; pz[q] = C.Z0 + nj_[j_, i_] * C.CELL
            # 양 끝을 권역 가장자리까지 늘림
            def ext(p0, p1):
                d = np.array(p0) - np.array(p1); d /= np.linalg.norm(d) + 1e-9; q = np.array(p0, float)
                while abs(q[0]) < -C.X0 and abs(q[1]) < -C.Z0: q = q + d * 4.0
                return [float(np.clip(q[0], C.X0, -C.X0)), float(np.clip(q[1], C.Z0, -C.Z0))]
            a0 = ext((px[0], pz[0]), (px[3], pz[3])); a1 = ext((px[-1], pz[-1]), (px[-4], pz[-4]))
            px = np.concatenate([[a0[0]], px, [a1[0]]]); pz = np.concatenate([[a0[1]], pz, [a1[1]]])
            fix_dirn(px, pz, sea)
            sy = round(float(reg["sea"]["y"]), 2)
            reg["rivers"].insert(0, dict(id=rid_, name=r["name"], grade="B", spec_grade="S", render=False, water_body="sea", width_m=round(width, 1), points=[[round(float(a), 1), round(float(b), 1), sy] for a, b in zip(px, pz)],
                                         flows_to="권역 밖 — " + r["flows_to"], parent=None, source=r.get("source", []), confidence="추정",
                                         notes="S급 큰 강(명세 §7): 계약 등급 표기가 B까지라 grade=B·spec_grade=S. 물 모양은 landuse 5·sea 물면(섬 포함)이 정답 — 이 선은 중심 근사(폭은 평균), 엔진은 리본으로 그리지 말 것(render=false)."))
        floor_y = float(C.alt_to_y(-1.5))
        er = ndimage.binary_erosion(sea, iterations=2)
        nfix = int((er & (y > floor_y + 1e-3)).sum())
        y = np.where(er, np.minimum(y, floor_y), y)
        r_ = round(float(y.min()))
        if abs(float(y.min()) - r_) < 0.02: y = np.maximum(y, r_ + 0.02)          # export가 y_min을 한 칸 더 내리지 않게(QA H 허용 2m)
        hm2 = export.write_height(y.astype(np.float32))
        reg["height"].update(y_min=hm2["y_min"], y_max=hm2["y_max"])
        say("물면 칸 높이 되돌림", nfix)
        # 나루: 도로가 물면을 건너는 구간마다
        rid0 = next(rid for rid, r in P.RIVER_CONTROL.items() if r["grade"] == "S")
        cb = CFG.get("crossings_big", [])
        reg["crossings"] = [c for c in reg["crossings"] if c.get("by") != "north_post"]
        sea_at = lambda x, z: bool(sea[int(np.clip(round((z - C.Z0) / C.CELL), 0, sea.shape[0] - 1)), int(np.clip(round((x - C.X0) / C.CELL), 0, sea.shape[1] - 1))])
        for rd in reg["roads"]:
            p = np.asarray(rd["points"], float)
            seg = np.hypot(*np.diff(p, axis=0).T); s = np.concatenate([[0], np.cumsum(seg)])
            t = np.arange(0, s[-1], 2.0); xs = np.interp(t, s, p[:, 0]); zs = np.interp(t, s, p[:, 1])
            wet = np.array([sea_at(a, b) for a, b in zip(xs, zs)])
            lab, n = ndimage.label(wet)
            if rd["id"] in FERRY and n:
                lab = np.where(wet, 1, 0); lab[:np.nonzero(wet)[0][0]] = 0; lab[np.nonzero(wet)[0][-1] + 1:] = 0
                lab[np.nonzero(wet)[0][0]:np.nonzero(wet)[0][-1] + 1] = 1; n = 1
            for k in range(1, n + 1):
                idx = np.nonzero(lab == k)[0]
                if len(idx) * 2.0 < 20: continue
                mx, mz = xs[idx].mean(), zs[idx].mean()
                hit = seg_x(np.c_[xs[idx], zs[idx]], [q[:2] for q in reg["rivers"][0]["points"]]) if reg["rivers"] and reg["rivers"][0].get("spec_grade") == "S" else []
                if hit: mx, mz = hit[0]
                spec = min(cb, key=lambda c: math.hypot(xz(c["lat"], c["lon"])[0] - mx, xz(c["lat"], c["lon"])[1] - mz)) if cb else None
                if spec and math.hypot(xz(spec["lat"], spec["lon"])[0] - mx, xz(spec["lat"], spec["lon"])[1] - mz) < 400:
                    cid, name, conf, note = spec["id"], spec["name"], spec["confidence"], spec.get("notes", "")
                else:
                    cid, name, conf, note = f"naru_{rd['id'][:12]}_{k}", f"{big[0]['name']} 나루({rd['name'].split('(')[0]})", "가설", "자동: 큰 강 물면을 건너는 길 = 나룻배 길"
                if any(c["id"] == cid for c in reg["crossings"]): cid = f"{cid}_{k}"
                reg["crossings"].append(dict(id=cid, name=name, type="나루", river_id=rid0, road_id=rd["id"], x=round(float(mx), 1), z=round(float(mz), 1),
                                             span_m=round(len(idx) * 2.0, 1), ends=[[round(float(xs[idx[0]]), 1), round(float(zs[idx[0]]), 1)], [round(float(xs[idx[-1]]), 1), round(float(zs[idx[-1]]), 1)]],
                                             confidence=conf, notes=(note + " " if note else "") + f"물면 {len(idx) * 2.0:.0f}m(게임)를 나룻배로 건넘 — 길 점은 뱃길, 양 끝(ends)이 선착장.", by="north_post"))
                say("나루", cid, rd["id"], f"{len(idx) * 2.0:.0f}m")
                if rd["id"] in FERRY:     # 긴 뱃길: 중간 표지점(같은 나루) — 물 위 길 점 전부가 나루 반경 안에 들도록
                    wr = next((r_["width_m"] for r_ in reg["rivers"] if r_["id"] == rid0), 50.0) / 2 + 4.0
                    tt = np.arange(0, len(idx), max(1, int(wr * 1.4 / 2.0)))
                    for q, k2 in enumerate(tt):
                        reg["crossings"].append(dict(id=f"{cid}_route{q}", name=name + " 뱃길", type="나루", river_id=rid0, road_id=rd["id"], x=round(float(xs[idx[k2]]), 1), z=round(float(zs[idx[k2]]), 1),
                                                     confidence=conf, part_of=cid, notes="같은 나루의 뱃길 중간 표지점(엔진: 배는 part_of 나루 하나로 다룸)", by="north_post"))
        reg["transport"]["crossings"] = [c["name"] for c in reg["crossings"] if not c["id"].startswith("x_")]
    # ── 본류 이름 바로잡기: hydro가 권역 안 집수면적이 큰 지류를 본류로 이었을 때(성천강 상류 대부분이 권역 밖) 합류점 아래를 본류에 붙임
    R_ = {r["id"]: r for r in reg["rivers"]}
    for a_id, b_id in getattr(P, "TRUNK_FIX", []):
        A, B = R_.get(a_id), R_.get(b_id)
        if not A or not B or B.get("parent") != a_id: continue
        pa = np.asarray(A["points"]); jb = B["points"][-1]; k = int(np.argmin(np.hypot(pa[:, 0] - jb[0], pa[:, 1] - jb[1])))
        lower = A["points"][k + 1:]
        for r in reg["rivers"]:
            if r.get("parent") == a_id and r["id"] != b_id:
                d_ = np.hypot(pa[:, 0] - r["points"][-1][0], pa[:, 1] - r["points"][-1][1]); 
                if int(np.argmin(d_)) > k: r["parent"] = b_id; r["flows_to"] = b_id
        B["points"] = B["points"] + [q for q in lower if q[2] <= B["points"][-1][2]]
        B["parent"], B["flows_to"] = A["parent"], A["flows_to"]
        A["points"] = A["points"][:k + 1] + [B["points"][len(B["points"]) - len(lower) - 1]] if lower else A["points"]
        A["parent"], A["flows_to"] = b_id, b_id
        for c in reg["crossings"]:
            if c["river_id"] == a_id and int(np.argmin(np.hypot(pa[:, 0] - c["x"], pa[:, 1] - c["z"]))) > k: c["river_id"] = b_id
        if "catchment_km2" in A and "catchment_km2" in B: B["catchment_km2"] = A["catchment_km2"]
        say("본류 이름 바로잡음", b_id, "←", a_id, "합류점 아래", len(lower), "점")
    # ── 물길 바닥 보정: 하천 수면보다 높은 바닥 칸(길 둑·터 고르기에 눌린 곳)을 수면 아래로(QA Q2 '수로 안 수면')
    y, _ = export.read_height(); nlow = 0
    for r in reg["rivers"]:
        if r.get("spec_grade") == "S": continue
        p_ = np.asarray(r["points"], float); sg = np.hypot(*np.diff(p_[:, :2], axis=0).T); ss = np.concatenate([[0], np.cumsum(sg)]); tt = np.arange(0, ss[-1], 1.0)
        xs_, zs_, sv_ = (np.interp(tt, ss, p_[:, k]) for k in range(3))
        hw = max(r["width_m"] / 2, 2.6) * 0.6
        pr_ = np.asarray(r["points"], float); t_ = C.bilinear(y, *C.xz_to_ij(pr_[:, 0], pr_[:, 1]))
        if (t_ <= pr_[:, 2] + 0.05).mean() >= 0.97: continue          # 이미 물길 안이면 건드리지 않음
        for x_, z_, s_ in zip(xs_[::2], zs_[::2], sv_[::2]):
            if any(math.hypot(c["x"] - x_, c["z"] - z_) < 6 for c in reg["crossings"] if c["river_id"] == r["id"] and c.get("type") in ("돌다리", "섶다리")): continue
            i0, i1 = max(int((x_ - hw - C.X0) / C.CELL), 0), int((x_ + hw - C.X0) / C.CELL) + 2; j0, j1 = max(int((z_ - hw - C.Z0) / C.CELL), 0), int((z_ + hw - C.Z0) / C.CELL) + 2
            sub = y[j0:j1, i0:i1]; jj_, ii_ = np.mgrid[j0:j0 + sub.shape[0], i0:i0 + sub.shape[1]]
            dd_ = np.hypot(C.X0 + ii_ * C.CELL - x_, C.Z0 + jj_ * C.CELL - z_)
            m = (sub > s_ - 0.05) & (dd_ <= hw)
            if m.any(): nlow += int(m.sum()); sub[m] = s_ - 0.1
    if nlow:
        hm3 = export.write_height(y.astype(np.float32)); reg["height"].update(y_min=hm3["y_min"], y_max=hm3["y_max"]); say("물길 바닥 낮춤 칸", nlow)
    # ── 지정 도강점(이름 있는 다리)이 자동 건널목으로 잡혔으면 이름·형식을 옮겨 붙임
    have = {c["id"] for c in reg["crossings"]}
    for c in getattr(P, "CROSSINGS", []):
        if c["id"] in have or P.RIVER_CONTROL.get(c["river"], {}).get("grade") == "S": continue
        cx, cz = xz(c["lat"], c["lon"])
        cand = [k for k in reg["crossings"] if k["id"].startswith("x_") and math.hypot(k["x"] - cx, k["z"] - cz) < 70]
        if cand:
            k = min(cand, key=lambda k: math.hypot(k["x"] - cx, k["z"] - cz))
            k.update(id=c["id"], name=c["name"], type=c["type"], confidence=c["confidence"], notes=(c.get("notes", "") + " [자동 건널목에 이름 붙임]").strip())
            say("지정 도강점 이름 붙임", c["id"], k["road_id"], k["river_id"])
        else:
            reg.setdefault("build", {}).setdefault("warnings", []).append(f"지정 도강점 자리에 길×하천 교차 없음(랜드마크로만): {c['id']}")
    reg["build"]["warnings"] = [w for w in reg["build"].get("warnings", []) if not (w.startswith("지정 도강점을 길이 지나지 않음") and w.split(": ")[-1] in {k["id"] for k in reg["crossings"]})]
    # ── 성곽
    walls = []
    if RID == "GG_HANYANG":
        walls.append(dict(id="hanyang_doseong_wall", name="한양도성", points=hanyang_wall(), closed=True, height_m=[4.0, 7.0], kit="landmark/hanyang_wall",
                          gates=[g[0] for g in P.GATES] + ["ogansumun", "mokmyeok_bongsu"], confidence="추정",
                          source=["OSM '서울 한양도성' 선(현존·복원 구간) + 문·봉우리 기준점, 멸실 구간은 직선(가설)"],
                          notes="산 능선 성곽: 높이 평지 약 7m·산 4m(실물). 선은 성벽 중심. 길은 문(gates)으로만 드나든다."))
    for wid, w in getattr(P, "WALLS", {}).items():
        walls.append(dict(id=wid, name=w["name"], points=[xz(a, b) for a, b in w["latlon"]], closed=w.get("closed", False), height_m=w.get("height_m", [4.0, 6.0]),
                          kit=w.get("kit", "landmark/town_wall"), gates=w.get("gates", []), confidence=w.get("confidence", "가설"), source=w.get("source", []), notes=w.get("notes", "")))
    if walls:
        reg["walls"] = walls
        L = {l["id"]: l for l in reg["landmarks"]}
        bad = []
        for w in walls:
            gp = [(L[g]["x"], L[g]["z"]) for g in w["gates"] if g in L]
            for rd in reg["roads"]:
                if rd["class"] == "산길": continue          # 성곽길(성벽 위·암문)은 문 검사에서 뺌
                for (x, z) in seg_x(rd["points"], w["points"]):
                    d = min((math.hypot(x - a, z - b) for a, b in gp), default=1e9)
                    if d > 35: bad.append((w["id"], rd["id"], round(x), round(z), round(d)))
        reg.setdefault("build", {})["north_qw"] = dict(ok=not bad, wall_crossings_off_gate=bad[:30],
                                                        note="길×성벽 교차가 문(랜드마크) 35m(게임) 안인지(QW-north, 산길=성곽길 제외). 성벽 선이 근사라 문 둘레 여유를 둠")
        say("성곽", [(w["id"], len(w["points"])) for w in walls], "문 밖 교차", len(bad), bad[:8])
    # 기후대: 위도 띠 규칙(38°N 북쪽 = north)과 다르게 권역 기후대를 정한 경우(황주 = 중부) — 고산(3)·해안(4)은 그대로
    if getattr(P, "CLIMATE_BAND", None):
        code = {"south": 0, "central": 1, "north": 2}[P.CLIMATE_BAND]
        cp = os.path.join(C.OUT, "climate.png"); cl = np.array(Image.open(cp))
        cl[cl <= 2] = code; Image.fromarray(cl.astype(np.uint8), mode="L").save(cp, optimize=True)
        reg["climate"]["rule"]["lat_bands"] = f"권역 기후대 지정: {P.CLIMATE_BAND}(해서 문화권 — 위도 38.7°N이지만 중부로 둠, 계획서·총괄 지시)"
        say("기후대 지정", P.CLIMATE_BAND)
    # 뱃길이 지나는 모래섬 칸은 길(4)로
    lu_p = os.path.join(C.OUT, "landuse.png"); lu = np.array(Image.open(lu_p))
    for rd in reg["roads"]:
        if rd["id"] not in FERRY: continue
        p_ = np.asarray(rd["points"], float); sg = np.hypot(*np.diff(p_, axis=0).T); ss = np.concatenate([[0], np.cumsum(sg)]); tt = np.arange(0, ss[-1], 1.0)
        i_ = np.clip(np.round((np.interp(tt, ss, p_[:, 0]) - C.X0) / C.LU_CELL).astype(int), 0, lu.shape[1] - 1); j_ = np.clip(np.round((np.interp(tt, ss, p_[:, 1]) - C.Z0) / C.LU_CELL).astype(int), 0, lu.shape[0] - 1)
        land = lu[j_, i_] != 5; lu[j_[land], i_[land]] = 4
    Image.fromarray(lu.astype(np.uint8), mode="L").save(lu_p, optimize=True)
    if walls: town_inside_walls(reg)
    export.write_region(reg)
    # ── 그림 덧그리기
    shots = C.SHOTS
    for fn in os.listdir(shots) if os.path.isdir(shots) else []:
        if not fn.endswith(".png") or fn in ("landuse_map.png", "climate_map.png"): continue
        if not walls and fn != "overview.png": continue
        im = Image.open(os.path.join(shots, fn)).convert("RGB"); d = ImageDraw.Draw(im)
        if fn == "overview.png": S, ox, oy = 2, 0, 0
        else:
            z_ = CFG.get("zooms", {}).get(fn[:-4])
            if not z_: continue
            S = 1; ox = (z_[0] - C.X0) / C.CELL; oy = (z_[1] - C.Z0) / C.CELL
        for w in walls:
            pts = [((x - C.X0) / C.CELL / 1 - ox) / S if S == 1 else (x - C.X0) / C.CELL / S for x, _ in w["points"]]
            pzs = [((z - C.Z0) / C.CELL - oy) / S if S == 1 else (z - C.Z0) / C.CELL / S for _, z in w["points"]]
            d.line(list(zip(pts, pzs)), fill=(90, 60, 40), width=3 if S == 2 else 4)
        for c in reg["crossings"]:
            if c.get("type") == "나루" and c.get("ends"):
                (ax, az), (bx, bz) = c["ends"]
                f = (lambda x, z: ((x - C.X0) / C.CELL / S, (z - C.Z0) / C.CELL / S)) if S == 2 else (lambda x, z: ((x - C.X0) / C.CELL - ox, (z - C.Z0) / C.CELL - oy))
                d.line([f(ax, az), f(bx, bz)], fill=(255, 255, 255), width=2)
        im.save(os.path.join(shots, fn))
    say("완료")

if __name__ == "__main__":
    main()
