"""WP4 drawings: 03-terrain (ridge network · catchments · landform · rock body), 04-water
(reaches · bed type · foam causes · crossings · stage states · cross-section), 05-routes (long
profiles with support / drainage contacts and divide crossings). Same conventions as svg.py."""
from __future__ import annotations

import math
from xml.sax.saxutils import escape

from shapely.geometry import shape

from .svg import (DEFS, FONT, MAP_W, SIDE_W, P, _doc, _f, _map_open, contours, legend, north_and_scale, path_d,
                  relief_image, text)

LF_COL = {"plain": "#f3efd2", "valley_floor": "#cfe8c4", "foot_slope": "#e6d9a8", "slope": "#e9dfcf", "ridge": "#b98a6b",
          "saddle": "#e0a050", "summit": "#8a5a3c", "water": "#4a90d9"}
LF_KO = {"plain": "평지", "valley_floor": "곡저", "foot_slope": "산록 완경사", "slope": "사면", "ridge": "능선 띠",
         "saddle": "안부", "summit": "봉우리", "water": "물"}
GR_COL = {"cliff": "#c0392b", "rock_exposure": "#7f8c8d", "talus": "#a0522d", "bar_gravel": "#e2c044", "alluvium": "#f6e7a1"}
GR_KO = {"cliff": "절벽 후보(높이장 밖 형상 필요)", "rock_exposure": "노출 암체 후보", "talus": "너덜(붕락물) 후보",
         "bar_gravel": "모래톱·자갈(지도)", "alluvium": "충적·퇴적 후보"}
BED_COL = {"bedrock": "#6c3483", "step_pool_boulder": "#b03a2e", "riffle_pool_gravel": "#1f77b4", "alluvial_sand_gravel": "#17a589"}
BED_KO = {"bedrock": "암반 하상", "step_pool_boulder": "계단·소(전석)", "riffle_pool_gravel": "여울·소(자갈)",
          "alluvial_sand_gravel": "충적(모래·자갈)"}
X_SYM = {"ford": "여울", "stepping_stones": "징검다리", "brush_bridge": "섶다리", "stone_bridge": "돌다리", "bridge": "다리",
         "ferry": "나루", "unknown": "?"}
MODE_KO = {"foot": "도보", "pack_horse": "짐말", "cart": "수레"}


def _g(layer, gid):
    return shape(layer["geometry"][gid]) if gid else None


def _checks_lines(layer):
    out = []
    for c in layer.get("checks", []):
        v = "통과" if c["pass"] is True else ("실패" if c["pass"] is False else "해당 없음")
        out.append(f"{c['id']}: {v}" + (" (불변)" if c["kind"] == "invariant" else ""))
    return out


def terrain_svg(layer, plan, inp, A, view):
    T = layer["terrain"]
    b = [_map_open(view, "terrain"), relief_image(A, view, faint=True), contours(A, view)]
    for p in T["patches"]:
        if p["kind"] == "landform" and p["landform"] in LF_COL:
            b.append(P(path_d(_g(layer, p["original"])), fill=LF_COL[p["landform"]], fop=0.55))
    for c in T["catchments"]:
        b.append(P(path_d(_g(layer, c["geometry"])), stroke="#3d7fc4", sw=0.7, dash="3 3", op=0.8))
    for p in T["patches"]:
        if p["kind"] == "ground":
            cl = p["rock_body"]["class"]
            b.append(P(path_d(_g(layer, p["original"])), fill=GR_COL[cl], fop=0.85 if cl in ("cliff", "rock_exposure") else 0.65))
    b.append(P(path_d(A.water_poly), fill="#4a90d9", fop=0.85))
    for r in T["ridges"]:
        g = _g(layer, r["line"])
        if r["kind"] == "main":
            b.append(P(path_d(g), stroke="#7b241c", sw=3.0))
        elif r["kind"] == "spur":
            b.append(P(path_d(g), stroke="#a04000", sw=1.6))
        else:
            b.append(P(path_d(g), stroke="#888", sw=0.8, dash="1 3"))
    for rt in inp.roads:
        b.append(P(path_d(rt.line), stroke="#e07b00", sw=1.6, op=0.8))
    rr = 6 / view.px
    for s in T["saddles"]:
        x, z = s["xz"]
        col = "#d35400" if s["derived"] else "#2e86c1"
        b.append(f'<polygon points="{_f(x - rr)},{_f(z + rr)} {_f(x + rr)},{_f(z + rr)} {_f(x)},{_f(z - rr)}" fill="{col}" stroke="#000" stroke-width="0.8" vector-effect="non-scaling-stroke"/>')
        if s["mapped_pass"]:
            b.append(f'<text x="{_f(x + rr * 1.4)}" y="{_f(z)}" font-family="{FONT}" font-size="{_f(11 / view.px)}" fill="#1b4f72">{escape(str(s["mapped_pass"].get("name")))}</text>')
    for s in T["summits"]:
        x, z = s["xz"]
        b.append(f'<circle cx="{_f(x)}" cy="{_f(z)}" r="{_f(3.5 / view.px)}" fill="#5d4037" stroke="#fff" stroke-width="0.8" vector-effect="non-scaling-stroke"/>')
    from .svg import _g as _gp
    b.append(P(path_d(_gp(plan, plan["territory"]["preferred"])), stroke="#000", sw=1.6, dash="8 4"))
    b.append("</svg>")
    b.append(north_and_scale(view))
    sm = T["summary"]
    side = [text(0, 14, "WP4 — 지형: 능선망·유역·지형 위치·암체", 15, weight="bold")]
    items = [("line", "#7b241c", "주 능선(다른 유출구 사이 분수계)"), ("line", "#a04000", "지능선(같은 수계 안의 형제 유역 사이)"),
             ("dash", "#888", "평탄 분수계(기복 없음 — 능선 아님)"), ("dash", "#3d7fc4", "유역 경계(분석 격자 8 m)"),
             ("rect", "#d35400", "안부(계산) / 파랑=지도 고개만"), ("rect", "#5d4037", "봉우리")]
    items += [("rect", LF_COL[k], f"지형 위치: {LF_KO[k]}") for k in ("plain", "valley_floor", "foot_slope", "slope", "ridge", "saddle")]
    items += [("rect", GR_COL[k], GR_KO[k]) for k in ("cliff", "rock_exposure", "talus", "bar_gravel", "alluvium")]
    side.append(legend(items, 4, 40))
    y = 40 + len(items) * 18 + 8
    rk = (T["patches"][0]["rock_type"] if T["patches"] else {}) or {}
    lines = [f"유역 {sm['catchments']} · 능선 주 {sm['ridges']['main']} / 지 {sm['ridges']['spur']} / 평탄 {sm['ridges']['flat_divide']}",
             f"안부 {sm['saddles']} (지도 고개 일치 {sm['mapped_passes_matched']}, 불일치 {sm['mapped_passes_unmatched']}) · 봉우리 {sm['summits']}",
             f"내부 오목(채우지 않은 유역 끝) {sm['internal_sinks']}",
             "지면(m²): " + ", ".join(f"{k} {v:.0f}" for k, v in sm["ground_area_m2"].items() if v and k != "soil_mantled"),
             f"암종 기록: {rk.get('candidates') or '없음'} [{rk.get('grade', 'U')}/{rk.get('status', 'unknown')}]",
             "  → 형태 분류 입력이 아님(GEO-01): 경사·볼록·지도 바위 분류·HAND·붕락 경로로 분류",
             f"서식(관리 유형) 패치 {len(layer['habitats'])}: " + ", ".join(
                 f"{k} {sum(1 for h in layer['habitats'] if h['management'] == k)}" for k in sorted({h['management'] for h in layer['habitats']})),
             "  숲 관리 유형은 unknown(WP10) — 경작·마당만 토지 이용에서 옴"]
    for n, l in enumerate(lines):
        side.append(text(0, y + n * 16, l, 11))
    y += len(lines) * 16 + 10
    side.append(text(0, y, "검사(데이터 수준, 화면 판정 아님)", 12, weight="bold"))
    for n, l in enumerate(_checks_lines(layer)):
        side.append(text(0, y + 16 + n * 15, l, 11))
    y += 16 + len(_checks_lines(layer)) * 15 + 8
    side.append(text(0, y, "시험값: 능선 TPI 2 m·안부 상승 4 m·곡저 HAND 4 m·절벽 50° 등(rules terrain.*, ground.*)", 10, fill="#a33"))
    return _doc(view, "".join(b), "".join(side), f"{inp.name} ({inp.region}/{inp.id}) — 03 지형")


def _section_drawing(reach, states, x0, y0, w, h):
    rep = reach["cross_section"]["representative"]
    offs, ty = rep["offsets_m"], rep["terrain_y"]
    if not offs:
        return ""
    sy = rep["surface_y"]
    ch = rep["channel"]
    d = ch["depth_m"]["value"]
    hw = ch["width_m"] / 2
    bw = ch["bed_width_m"] / 2
    lv = [sy + s["offset"] for s in states]
    ymin = min(min(ty), sy - d) - 0.5
    ymax = max(max(ty), max(lv)) + 0.5
    xmin, xmax = offs[0], offs[-1]

    def X(o):
        return x0 + (o - xmin) / (xmax - xmin) * w

    def Y(v):
        return y0 + h - (v - ymin) / (ymax - ymin) * h
    out = [f'<rect x="{x0}" y="{y0}" width="{w}" height="{h}" fill="#fafafa" stroke="#bbb"/>']
    pts = " ".join(f"{_f(X(o))},{_f(Y(v))}" for o, v in zip(offs, ty))
    out.append(f'<polyline points="{pts}" fill="none" stroke="#6b5a3a" stroke-width="1.4"/>')
    chan = [(-hw, sy), (-bw, sy - d), (bw, sy - d), (hw, sy)]
    out.append('<polyline points="' + " ".join(f"{_f(X(o))},{_f(Y(v))}" for o, v in chan) + '" fill="none" stroke="#1f3a93" stroke-width="1.2" stroke-dasharray="3 2"/>')
    cols = ["#d6eaf8", "#5dade2", "#2e86c1", "#1b4f72", "#0b2a45"]
    for k, (s, l) in enumerate(zip(states, lv)):
        col = cols[min(k, len(cols) - 1)]
        out.append(f'<line x1="{_f(X(xmin))}" y1="{_f(Y(l))}" x2="{_f(X(xmax))}" y2="{_f(Y(l))}" stroke="{col}" stroke-width="1" stroke-dasharray="5 3"/>')
        out.append(text(x0 + w + 4, Y(l) + 4, f"{s['name']} {s['offset']:+g}", 9))
    out.append(text(x0, y0 + h + 14, f"대표 단면 {reach['meta']['stable_id'].split(':')[-2]}:{reach['meta']['stable_id'].split(':')[-1]} "
                    f"@{rep['chainage']} m — 갈색=지형(높이 자료), 파랑 점선=설계 수로(깊이 {d} m 시험값)", 9))
    return "".join(out)


def water_svg(layer, plan, inp, A, view):
    Wt = layer["water"]
    b = [_map_open(view, "water"), relief_image(A, view, faint=True)]
    cols = {0.5: "#d6eaf8", 1.5: "#85c1e9", 3.0: "#e8f6f3"}
    for off in sorted(A.flood_polys, reverse=True):
        b.append(P(path_d(A.flood_polys[off]), fill=cols.get(off, "#eee"), fop=0.6))
    b.append(P(path_d(A.water_poly), fill="#4a90d9", fop=0.5))
    for r in Wt["reaches"]:
        g = _g(layer, r["plan"]["centerline"])
        b.append(P(path_d(g), stroke=BED_COL[r["bed_mix"]["type"]], sw=3.2))
        # foam-cause segments
        L = g.length
        s0 = r["long_profile"]["stations"][0]["chainage"]
        for sg in r["flow"]["segments"]:
            if not sg["foam"]:
                continue
            a, c = max(0.0, sg["chainage"][0] - s0), min(L, sg["chainage"][1] - s0)
            if c <= a:
                continue
            from shapely.ops import substring
            b.append(P(path_d(substring(g, a, c)), stroke="#fff", sw=2.0, dash="2 2"))
        # flow arrow at mid
        if L > 10:
            p1, p2 = g.interpolate(0.5 * L), g.interpolate(min(L, 0.5 * L + 6))
            ang = math.degrees(math.atan2(p2.y - p1.y, p2.x - p1.x))
            s = 7 / view.px
            b.append(f'<path d="M{_f(-s)},{_f(-s * 0.6)} L{_f(s)},0 L{_f(-s)},{_f(s * 0.6)} Z" transform="translate({_f(p1.x)},{_f(p1.y)}) rotate({_f(ang)})" fill="#000"/>')
    for rt in inp.roads:
        b.append(P(path_d(rt.line), stroke="#e07b00", sw=1.6, op=0.85))
    rr = 6 / view.px
    for c in Wt["crossings"]:
        x, z = c["xz"]
        b.append(f'<rect x="{_f(x - rr)}" y="{_f(z - rr)}" width="{_f(2 * rr)}" height="{_f(2 * rr)}" fill="#fff" stroke="#000" stroke-width="1.2" vector-effect="non-scaling-stroke"/>')
        b.append(f'<text x="{_f(x + rr * 1.5)}" y="{_f(z + rr)}" font-family="{FONT}" font-size="{_f(11 / view.px)}" fill="#000">{escape(X_SYM.get(c["class"], "?"))}</text>')
    for c in Wt["crossing_candidates"]:
        x, z = c["xz"]
        b.append(f'<path d="M{_f(x - rr)},{_f(z - rr)} L{_f(x + rr)},{_f(z + rr)} M{_f(x - rr)},{_f(z + rr)} L{_f(x + rr)},{_f(z - rr)}" stroke="#c0392b" stroke-width="2" vector-effect="non-scaling-stroke"/>')
    b.append("</svg>")
    b.append(north_and_scale(view))
    side = [text(0, 14, "WP4 — 물: 구간·하상·거품 원인·건널목·수위 상태", 15, weight="bold")]
    items = [("line", BED_COL[k], f"하상 유형: {BED_KO[k]}") for k in BED_COL]
    items += [("dash", "#999", "흰 점선 = 거품 원인 구간(낙차·급류·합류·장애물)만"),
              ("rect", "#fff", "□ 지도 건널목(종류 표기)"), ("line", "#c0392b", "× 지도에 없는 길–물 만남(후보, 적용 안 함)"),
              ("rect", "#d6eaf8", "증수(작은 물) +0.5"), ("rect", "#85c1e9", "증수(큰물) +1.5 — 점유 제외"), ("rect", "#e8f6f3", "범람 +3.0")]
    side.append(legend(items, 4, 40))
    y = 40 + len(items) * 18 + 6
    states = Wt["stage_states"]
    side.append(text(0, y, "상태별 영향(같은 값 = rules water.stage_states 하나)", 12, weight="bold"))
    y += 16
    hdr = ["상태", "젖은 폭 중앙", "마른 하상", "둑 넘음", "건널목 도보 불가", "길 끊김(도보)"]
    xs = [0, 74, 150, 210, 262, 330]
    for x, hh in zip(xs, hdr):
        side.append(text(x, y, hh, 10, weight="bold"))
    y += 14
    for k, st in enumerate(sorted(states, key=lambda s: s["offset"])):
        wet = [r["states"][k]["wetted_width_m"]["median"] for r in Wt["reaches"]]
        dry = [r["states"][k]["dry_bed_fraction"] for r in Wt["reaches"]]
        ov = [max(r["states"][k]["bank_overtopped_fraction"].values()) for r in Wt["reaches"]]
        imp = next(i for i in Wt["stage_impacts"] if i["key"] == st["key"])
        xno = sum(1 for v in imp["crossings"].values() if v is not None and not v["foot"])
        cut = sum(1 for r in imp["routes"] if r["modes"]["foot"] == "cut")
        vals = [f"{st['name']} {st['offset']:+g}", f"{(sorted(wet)[len(wet) // 2] if wet else 0):.1f} m",
                f"{(max(dry) if dry else 0):.2f}", f"{(max(ov) if ov else 0):.2f}", f"{xno}/{len(imp['crossings'])}", f"{cut}/{len(imp['routes'])}"]
        for x, v in zip(xs, vals):
            side.append(text(x, y, v, 10))
        y += 14
    y += 6
    for c in Wt["crossings"][:6]:
        if not c.get("states"):
            side.append(text(0, y, f"{c['source_id']} ({c['type_ko']}): 이 창의 물길과 대응 없음", 10, fill="#555"))
            y += 13
            continue
        row = " ".join(("●" if s["modes"]["foot"]["passable"] else "○") for s in c["states"])
        side.append(text(0, y, f"{c['source_id'][:26]} {c['type_ko']}→{X_SYM.get(c['class'])}  도보 {row}", 10))
        y += 13
    if Wt["reaches"]:
        longest = max(Wt["reaches"], key=lambda r: r["long_profile"]["length_m"])
        side.append(_section_drawing(longest, sorted(states, key=lambda s: s["offset"]), 0, y + 8, 250, 120))
        y += 150
    y += 8
    side.append(text(0, y, "하상 유형은 경사·골 폭 비·둑 옆 바위·지도 모래톱으로 분류(이름 아님), 혼합 비율은 unknown", 10, fill="#a33"))
    side.append(text(0, y + 14, "설계 수로 깊이·건널목 규칙(여울 깊이·다리 높이·나루 운휴)은 시험값", 10, fill="#a33"))
    return _doc(view, "".join(b), "".join(side), f"{inp.name} ({inp.region}/{inp.id}) — 04 물")


def routes_svg(layer, plan, inp, A):
    routes = plan["inputs"]["movement_livelihood"]["routes"]
    W = MAP_W + SIDE_W
    rows = max(1, min(6, len(routes)))
    rh = 170
    H = max(760, 60 + rows * (rh + 30) + 100) + 40
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">', DEFS,
           f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
           text(12, 26, f"{inp.name} ({inp.region}/{inp.id}) — 05 길 종단·지지·배수 접점", 17, weight="bold"),
           '<g transform="translate(0,40)">']
    if not routes:
        out.append(text(20, 30, "이 창에 주어진 길 없음", 13))
    lim = {m["mode"]: m["limit"] for m in (routes[0]["modes"] if routes else [])}
    for k, r in enumerate(routes[:rows]):
        y0 = 20 + k * (rh + 30)
        lp = r["long_profile"]
        ch, ys = lp.get("chainage") or [], lp.get("y") or []
        x0, w, h = 60, W - 120, rh - 40
        out.append(text(10, y0, f"{r['name']} ({r['class'] or '-'}) · {lp['length_m']} m · 오름 {lp.get('ascent_m')} m · 내림 {lp.get('descent_m')} m · "
                        f"지속 경사 {lp['sustained_grade_10m']:.3f} · " + " ".join(f"{MODE_KO[m['mode']]}{'○' if m['passable'] else '×'}" for m in r["modes"]), 12, weight="bold"))
        if len(ch) < 2:
            continue
        ymin, ymax = min(ys) - 1, max(ys) + 1
        if ymax - ymin < 4:
            ymax = ymin + 4

        def X(s):
            return x0 + s / max(ch[-1], 1e-6) * w

        def Y(v):
            return y0 + 14 + h - (v - ymin) / (ymax - ymin) * h
        out.append(f'<rect x="{x0}" y="{y0 + 14}" width="{w}" height="{h}" fill="#fbfaf6" stroke="#ccc"/>')
        for q in range(len(ch) - 1):
            g = abs(ys[q + 1] - ys[q]) / max(ch[q + 1] - ch[q], 1e-6)
            col = "#2e7d32" if g <= lim.get("cart", 0.1) else ("#f39c12" if g <= lim.get("pack_horse", 0.15) else ("#d35400" if g <= lim.get("foot", 0.25) else "#922b21"))
            out.append(f'<line x1="{_f(X(ch[q]))}" y1="{_f(Y(ys[q]))}" x2="{_f(X(ch[q + 1]))}" y2="{_f(Y(ys[q + 1]))}" stroke="{col}" stroke-width="2.2"/>')
        for sec in r["width_section"].get("sections") or []:
            a, c = sec["chainage"]
            yb = y0 + 14 + h + 4
            if sec["valley_side_support"] == "retaining_candidate":
                out.append(f'<rect x="{_f(X(a))}" y="{_f(yb)}" width="{_f(max(1, X(c) - X(a)))}" height="5" fill="#c0392b"/>')
            if sec["hill_side"] == "cut_face":
                out.append(f'<rect x="{_f(X(a))}" y="{_f(yb + 6)}" width="{_f(max(1, X(c) - X(a)))}" height="5" fill="#7f8c8d"/>')
            if sec["section"] != "flat":
                out.append(f'<rect x="{_f(X(a))}" y="{_f(yb + 12)}" width="{_f(max(1, X(c) - X(a)))}" height="3" fill="{"#e6b0aa" if sec["section"] == "steep_sidehill" else "#f5cba7"}"/>')
        for c in r["support_drainage"]:
            s = c["chainage"][0] if isinstance(c["chainage"], list) else c["chainage"]
            xx = X(s)
            if c["kind"] == "drainage_crossing":
                out.append(f'<path d="M{_f(xx - 4)},{_f(y0 + 16)} L{_f(xx + 4)},{_f(y0 + 16)} L{_f(xx)},{_f(y0 + 24)} Z" fill="#2e86c1"/>')
            elif c["kind"] in ("mapped_crossing", "unmapped_water_crossing"):
                col = "#000" if c["kind"] == "mapped_crossing" else "#c0392b"
                out.append(f'<rect x="{_f(xx - 4)}" y="{_f(y0 + 16)}" width="8" height="8" fill="{col}" transform="rotate(45 {_f(xx)} {_f(y0 + 20)})"/>')
            elif c["kind"] == "low_point":
                i_ = min(range(len(ch)), key=lambda q: abs(ch[q] - s))
                out.append(f'<circle cx="{_f(xx)}" cy="{_f(Y(ys[i_]))}" r="3.5" fill="#1b4f72"/>')
            elif c["kind"] == "wet_ground":
                a, e = c["chainage"]
                out.append(f'<rect x="{_f(X(a))}" y="{_f(y0 + 14)}" width="{_f(max(1, X(e) - X(a)))}" height="{h}" fill="#aed6f1" fill-opacity="0.35"/>')
        for dv in r.get("divide_crossings", []):
            xx = X(dv["chainage"])
            out.append(f'<line x1="{_f(xx)}" y1="{y0 + 14}" x2="{_f(xx)}" y2="{y0 + 14 + h}" stroke="#7b241c" stroke-width="1.5" stroke-dasharray="4 2"/>')
            out.append(text(xx + 3, y0 + 26, ("주 분수계" if dv["ridge_kind"] == "main" else "지능선") + (" · 안부" if dv["saddle"] else ""), 9, fill="#7b241c"))
        out.append(text(x0 - 6, Y(ymax) + 4, f"{ymax:.0f}", 9, anchor="end"))
        out.append(text(x0 - 6, Y(ymin) + 4, f"{ymin:.0f}", 9, anchor="end"))
    out.append("</g>")
    ly = H - 100
    out.append(legend([("line", "#2e7d32", "경사 ≤ 수레 한계"), ("line", "#f39c12", "≤ 짐말"), ("line", "#d35400", "≤ 도보"), ("line", "#922b21", "도보 한계 초과"),
                       ], 20, ly))
    out.append(legend([("rect", "#c0392b", "골쪽 지지 후보(강제 아님)"), ("rect", "#7f8c8d", "산쪽 절취면"), ("rect", "#2e86c1", "▼ 지도에 없는 배수선 횡단"),
                       ("rect", "#000", "◆ 지도 건널목 / 빨강 = 후보")], 320, ly))
    out.append(legend([("rect", "#1b4f72", "● 오목점(물 고임)"), ("rect", "#aed6f1", "젖은 땅(배수선 가까이)"), ("dash", "#7b241c", "분수계 통과")], 700, ly))
    out.append(text(20, H - 8, "수단 한계·지지/절취 기준·배수 면적은 시험값(rules routes.*, movement.mode_limits). 기존 길은 지우지 않고 기록만 한다.", 10, fill="#a33"))
    out.append("</svg>")
    return "".join(out)
