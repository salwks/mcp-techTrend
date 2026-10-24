"""WP5 drawings: 03-districts (roles, household mixes, quotas, market approach, forecourts,
non-built regions, hamlets), 04-streets-water (hierarchy widths, junction ids, grades, crossings,
drain arrows, blocks), 05-parcels (numbered parcels, access strips, shared edges coloured by
geometry reason, locks, households). Same conventions as svg.py; Layer 0–2 hazards stay visible.
"""
from __future__ import annotations

import math
from xml.sax.saxutils import escape

from shapely.geometry import shape

from .svg import FONT, P, _doc, _f, _map_open, contours, legend, north_and_scale, path_d, relief_image, text

GCOL = {"market_trade": "#e15759", "clerical": "#b07aa1", "elite": "#4e79a7", "craft": "#f28e2b", "ordinary": "#8cd17d",
        "garden_open": "#c9e4a6"}
GKO = {"market_trade": "장시·가게", "clerical": "아전·중인", "elite": "양반·지주", "craft": "수공업", "ordinary": "서민(농·어·산)",
       "garden_open": "과원·채마"}
RCOL = {"hill": "#a39e93", "open_ground": "#e9e3c4", "watercourse": "#4a90d9", "field_protected": "#d9c38b",
        "lock": "#7b3fa0", "civic_reserve": "#b5651d", "market_plaza": "#d4a017", "civic_forecourt": "#e8b27a",
        "primary_street": "#f5a623", "well": "#1f6fb2", "garden_open": "#c9e4a6"}
HCOL = {"primary": "#b35900", "route": "#7f6a4a", "secondary": "#d9822b", "lane": "#e6b35a", "cul_de_sac": "#c94f7c", "gosat": "#9a7b4f"}
UCOL = {"residential": "#f2dcb3", "garden": "#cfe8b0", "hill": "#bdb8ad", "open_ground": "#ece6cc", "field": "#e3d29a",
        "residual_nonbuildable": "#dddddd", "residual_garden": "#e0ecd0"}
RSCOL = {"street_edge": "#b35900", "frontage_normal": "#2f6db3", "frontage_depth": "#7aa6d6", "town_wall": "#111111",
         "water_setback": "#2a7fbf", "civic_envelope": "#7a3d0c", "civic_forecourt": "#c08040", "program_plaza": "#c08040",
         "rear_access_demand": "#c94f7c", "easement": "#8e44ad", "rear_split": "#1b9e77", "lock_shape": "#7b3fa0", "hamlet_extent": "#5a8f29",
         "territory_edge": "#555555", "protected_field_edge": "#b8860b", "unclassified": "#ff00ff"}


def _g(L, gid):
    return shape(L["geometry"][gid]) if gid else None


def _base(view, A, plan, L):
    from .svg import _g as gp
    b = [_map_open(view, "layout"), relief_image(A, view, faint=True), contours(A, view)]
    b.append(P(path_d(A.flood_polys[A.stage_ex]), fill="#5bc8d8", fop=0.25))
    b.append(P(path_d(A.water_poly), fill="#4a90d9", fop=0.8))
    b.append(P(path_d(A.protected_poly), fill="url(#hatchR)", stroke="#c0504d", sw=0.5, op=0.7))
    fr = plan["frame"]
    if fr.get("wall"):
        b.append(P(path_d(gp(plan, fr["wall"]["ring"])), stroke="#111", sw=2.6))
    else:
        b.append(P(path_d(gp(plan, fr["territory"])), stroke="#8a6d3b", sw=1.2, dash="5 3"))
    return b


def _status_line(L):
    st = L["status"]
    col = "#1a7f37" if st == "complete" else ("#8a6d00" if st in ("incomplete", "diagnostic_only") else "#b42318")
    return st, col


def districts_svg(L, plan, inp, A, view):
    D = L["districts"]
    b = _base(view, A, plan, L)
    for r in D["regions"]:
        col = RCOL.get(r["kind"], "#ddd")
        b.append(P(path_d(_g(L, r["geometry"])), fill=col, fop=0.55 if r["kind"] not in ("watercourse",) else 0.35))
    for d in D["districts"]:
        b.append(P(path_d(_g(L, d["geometry"])), fill=GCOL[d["group"]], fop=0.7, stroke="#333", sw=0.5))
    for h in D["extramural"].get("hamlets", []):
        b.append(P(path_d(_g(L, h["geometry"])), fill="#8cd17d", fop=0.6, stroke="#2d6a1f", sw=1.2, dash="3 2"))
    mk = D.get("market") or {}
    og = mk.get("outside_gate") or {}
    if og.get("geometry"):
        b.append(P(path_d(_g(L, og["geometry"])), stroke="#d62728" if og.get("feasible") else "#999", sw=1.4, dash="4 3"))
    fs = 10 / view.px
    for d in D["districts"]:
        if d["households"] <= 0:
            continue
        x, z = d["xz"]
        b.append(f'<text x="{_f(x)}" y="{_f(z)}" font-family="{FONT}" font-size="{_f(fs)}" text-anchor="middle" fill="#111">{d["households"]}</text>')
    g0 = D.get("main_gate")
    if g0:
        s = 8 / view.px
        x, z = g0["xz"]
        b.append(f'<circle cx="{_f(x)}" cy="{_f(z)}" r="{_f(s)}" fill="none" stroke="#d62728" stroke-width="2.5" vector-effect="non-scaling-stroke"/>')
    b.append("</svg>")
    b.append(north_and_scale(view))
    st, col = _status_line(L)
    side = [text(0, 14, "Layer 3 — 구역(역할·가구 혼합)과 비건축 영역", 15, weight="bold"),
            text(0, 34, f"layout: {st} · plan {plan['status']}", 12, weight="bold", fill=col)]
    y = 56
    tot = {}
    for d in D["districts"]:
        tot.setdefault(d["group"], [0, 0.0])
        tot[d["group"]][0] += d["households"]
        tot[d["group"]][1] += d["area_m2"]
    lines = [f"구역 {len(D['districts'])} · 영역 {len(D['regions'])} · 가구 {len(L['households'])}"]
    for g, (n, a) in sorted(tot.items()):
        lines.append(f"  {GKO[g]}: {n}가구 · {a:,.0f} m²")
    p4 = D["pub04"]
    lines.append(f"성안 비건축(PUB-04): {', '.join(p4['non_built_kinds']) or '없음'}")
    for k, v in p4["area_m2"].items():
        lines.append(f"  {k}: {v:,.0f} m²")
    if g0:
        lines.append(f"주 문: {g0['id']} (수요 {g0['demand']}, 접근 {g0['access_m']:.0f} m)")
    if mk:
        lines.append(f"장터: {mk.get('selected')} · 성문 밖 변형 {'가능' if og.get('feasible') else ('불가' if og.get('evaluated') else '평가 안 함')}"
                     + (" (적용)" if og.get("applied") else " (미적용)"))
    ex = D["extramural"]
    if ex.get("applies"):
        lines.append(f"성 밖 마을: {len(ex['hamlets'])}곳 · {ex['moved']}가구 이동 · 남음 {ex.get('unplaced', 0)}")
    else:
        lines.append(f"성 밖 마을: 해당 없음 ({ex.get('reason', '')[:34]})")
    for a in D["allocation"]:
        lines.append(f"  {a['component']}: 칸 {a['cells']} · 허용오차 안 {a['within_tolerance']}")
    for l in lines[:30]:
        side.append(text(0, y, l[:62], 10))
        y += 15
    items = [("rect", GCOL[g], GKO[g]) for g in GCOL] + [("rect", RCOL[k], k) for k in
                                                          ("hill", "open_ground", "watercourse", "field_protected", "civic_reserve",
                                                           "market_plaza", "civic_forecourt", "primary_street", "well", "lock")]
    items += [("dash", "#d62728", "성문 밖 장터 변형(평가)"), ("dash", "#2d6a1f", "성 밖 마을(논 가장자리)")]
    side.append(legend(items, 0, y + 12))
    side.append(text(0, y + 12 + len(items) * 18 + 8, "구역 경계는 계획 표지 — 길·담이 아님. 숫자 = 구역 가구 수", 10, fill="#a33"))
    return _doc(view, "".join(b), "".join(side), f"{inp.name} — 03 구역")


def streets_svg(L, plan, inp, A, view):
    S, W = L["streets"], L["water"]
    b = _base(view, A, plan, L)
    for blk in L["blocks"]:
        b.append(P(path_d(_g(L, blk["geometry"])), fill="#fbf7ea", fop=0.6, stroke="#bba", sw=0.4))
    for c in W["channels"]:
        g = c["effective_wet"]["geometry"]
        if g:
            b.append(P(path_d(_g(L, g)), fill="#2a7fbf", fop=0.5, stroke="#d62728" if c["width_disagreement"] else "#2a7fbf",
                       sw=1.2 if c["width_disagreement"] else 0.5, dash="3 2" if c["width_disagreement"] else None))
    for p in S["plazas"]:
        b.append(P(path_d(_g(L, p["geometry"])), fill="#e8b27a", fop=0.6))
    for l in sorted(S["links"], key=lambda l: ["gosat", "cul_de_sac", "lane", "secondary", "route", "primary"].index(l["hierarchy"])):
        g = _g(L, l["centerline"])
        w = max(1.0, l["width_m"] * view.px * 0.9)
        b.append(P(path_d(g), stroke=HCOL[l["hierarchy"]], sw=round(w, 2), op=0.85,
                   extra='stroke-linecap="round" stroke-linejoin="round"'))
    for d in W["drains"]:
        g = _g(L, d["geometry"])
        col = "#1f77b4" if d["outlet"]["kind"] not in ("none", "wall_outlet_needed") else "#d62728"
        b.append(P(path_d(g), stroke=col, sw=0.8, dash="2 2"))
        cs = list(g.coords)
        if len(cs) >= 2:
            (x0, z0), (x1, z1) = cs[-2], cs[-1]
            ang = math.atan2(z1 - z0, x1 - x0)
            s = 5 / view.px
            pts = [(x1, z1), (x1 - s * math.cos(ang - 0.45), z1 - s * math.sin(ang - 0.45)),
                   (x1 - s * math.cos(ang + 0.45), z1 - s * math.sin(ang + 0.45))]
            b.append(f'<polygon points="{" ".join(f"{_f(x)},{_f(z)}" for x, z in pts)}" fill="{col}"/>')
    for x in W["crossings"]:
        if not x.get("xz"):
            continue
        s = 5 / view.px
        X, Z = x["xz"]
        col = "#2ca02c" if x.get("structure_supported", True) else "#d62728"
        b.append(f'<rect x="{_f(X - s)}" y="{_f(Z - s)}" width="{_f(2 * s)}" height="{_f(2 * s)}" fill="#fff" stroke="{col}" stroke-width="2" vector-effect="non-scaling-stroke"/>')
    fs = 8 / view.px
    for n in S["nodes"]:
        if n["degree"] >= 3 or n["kind"] in ("gate", "route_entrance", "civic_entrance"):
            x, z = n["xz"]
            r = 2.6 / view.px
            b.append(f'<circle cx="{_f(x)}" cy="{_f(z)}" r="{_f(r)}" fill="#222"/>')
            if n["degree"] >= 3:
                b.append(f'<text x="{_f(x + r)}" y="{_f(z - r)}" font-family="{FONT}" font-size="{_f(fs)}" fill="#333">{escape(n["id"].split(":")[-1])}{n.get("junction_form") or ""}</text>')
    b.append("</svg>")
    b.append(north_and_scale(view))
    st, col = _status_line(L)
    side = [text(0, 14, "Layer 4 — 길 위계·물길·건널목·배수·블록", 15, weight="bold"),
            text(0, 34, f"layout: {st}", 12, weight="bold", fill=col)]
    y = 56
    hier = {}
    for l in S["links"]:
        h = hier.setdefault(l["hierarchy"], [0, 0.0, 0])
        h[0] += 1
        h[1] += l["length_m"]
        h[2] += 0 if l["modes"]["cart"]["passable"] else 1
    lines = []
    for h, (n, ln, nocart) in sorted(hier.items(), key=lambda kv: ["primary", "route", "secondary", "lane", "cul_de_sac", "gosat"].index(kv[0])):
        ws = sorted({l["width_m"] for l in S["links"] if l["hierarchy"] == h})
        lines.append(f"{h}: {n}개 · {ln:,.0f} m · 폭 {ws[0]:.2f}–{ws[-1]:.2f} m · 수레 불가 {nocart}")
    cyc = next((c["detail"]["network"] for c in L["checks"] if c["id"] == "V46" and c["detail"].get("network")), None)
    if cyc:
        lines.append(f"길망: 노드 {cyc['nodes']} · 링크 {cyc['links']} · 순환 {cyc['independent_loops']} ({cyc['form']})")
    m = L["metrics"]
    sp = m["secondary_spacing_m"]
    lines.append(f"지선 간격 중앙 {sp['median']} m (목표 {sp['target'][0]:.0f}–{sp['target'][1]:.0f}, 판정 {'함' if sp['judged'] else '표본 부족'})")
    cd = m["cul_de_sac_length_m"]
    lines.append(f"막다른 골목 {cd['n']}개 · 최장 {cd['max']} m (한도 {cd['limit']:.0f})")
    reasons = {}
    for l in S["links"]:
        for bd in l.get("bends", []):
            reasons[bd["reason"]] = reasons.get(bd["reason"], 0) + 1
    lines.append("굽음 이유: " + ", ".join(f"{k} {v}" for k, v in sorted(reasons.items())))
    dis = [c for c in W["channels"] if c["width_disagreement"]]
    lines.append(f"물길 {len(W['channels'])} · 파인 골/지도 폭 불일치 {len(dis)} (빨간 점선)")
    for c in W["channels"][:6]:
        lines.append(f"  {c['feature']}: 파인 골 {c['effective_wet']['width_m_median']} m / 지도 {c['mapped_width_m']['median']} m")
    xs = {}
    for x in W["crossings"]:
        xs[f"{x['origin']}:{x['class']}"] = xs.get(f"{x['origin']}:{x['class']}", 0) + 1
    lines.append("건널목: " + (", ".join(f"{k} {v}" for k, v in sorted(xs.items())) or "없음"))
    fords = [x for x in W["crossings"] if x.get("riffle_section")]
    if fords:
        lines.append(f"  여울 단면(≤0.4 m) {len(fords)}곳 — 소·흐름 구간은 설계 깊이 유지")
    dk = {}
    for d in W["drains"]:
        dk[d["outlet"]["kind"]] = dk.get(d["outlet"]["kind"], 0) + 1
    lines.append(f"배수 {len(W['drains'])}: " + ", ".join(f"{k} {v}" for k, v in sorted(dk.items())))
    lines.append(f"  경사 0.5% 미만(정지 계약 필요) {sum(1 for d in W['drains'] if not d['min_fall_ok'])}")
    lines.append(f"블록 {len(L['blocks'])} · 광장(프로그램만) {len(S['plazas'])}")
    for c in L["checks"]:
        if c["id"].startswith("L4"):
            lines.append(f"{c['id']}: {'통과' if c['pass'] else ('실패' if c['pass'] is False else '해당 없음')}")
    for l in lines[:34]:
        side.append(text(0, y, l[:64], 10))
        y += 15
    items = [("line", HCOL[h], h) for h in HCOL] + [("dash", "#1f77b4", "길 배수(화살표=흐름, 출구 있음)"),
                                                     ("dash", "#d62728", "배수 출구 없음/수구 필요"), ("rect", "#2a7fbf", "파인 골 젖은 폭(계획 기준)"),
                                                     ("rect", "#e8b27a", "프로그램 광장(앞마당·장터·우물)"), ("rect", "#fbf7ea", "블록")]
    side.append(legend(items, 0, y + 12))
    return _doc(view, "".join(b), "".join(side), f"{inp.name} — 04 길·물")


def parcels_svg(L, plan, inp, A, view):
    b = _base(view, A, plan, L)
    faces = {f["id"]: f for f in L["subdivision"]["faces"]}
    for f in L["subdivision"]["faces"]:
        if f["kind"] in ("street", "cul_de_sac", "lane"):
            b.append(P(path_d(_g(L, f["geometry"])), fill="#f3d9a4", fop=0.9))
        elif f["kind"] == "plaza":
            b.append(P(path_d(_g(L, f["geometry"])), fill="#e8b27a", fop=0.8))
        elif f["kind"] == "civic":
            b.append(P(path_d(_g(L, f["geometry"])), fill="#b5651d", fop=0.6))
        elif f["kind"] == "water":
            b.append(P(path_d(_g(L, f["geometry"])), fill="#4a90d9", fop=0.45))
        elif f["kind"] == "lock":
            b.append(P(path_d(_g(L, f["geometry"])), fill="#7b3fa0", fop=0.9))
        elif f["kind"] == "easement":
            b.append(P(path_d(_g(L, f["geometry"])), fill="#8e44ad", fop=0.5))
    for p in L["parcels"]:
        g = _g(L, p["zones"]["lot"])
        b.append(P(path_d(g), fill=UCOL.get(p["use"], "#eee"), fop=0.85))
        if p["zones"].get("rear_garden"):
            b.append(P(path_d(_g(L, p["zones"]["rear_garden"])), fill="#cfe8b0", fop=0.6))
    for e in L["subdivision"]["edges"]:
        base = e["geometry_reason"].split(":")[0]
        col = RSCOL.get(base, "#ff00ff")
        sw = 1.4 if e["purpose"] in ("party_boundary", "street_frontage") else 0.8
        if e["level_change"]:
            sw = 2.2
        b.append(P(path_d(_g(L, e["geometry"])), stroke=col, sw=sw))
    fs = 7 / view.px
    n = 0
    for p in L["parcels"]:
        if p["use"] != "residential":
            continue
        n += 1
        x, z = p["xz"]
        b.append(f'<text x="{_f(x)}" y="{_f(z + fs / 3)}" font-family="{FONT}" font-size="{_f(fs)}" text-anchor="middle" fill="#222">{n}</text>')
    b.append("</svg>")
    b.append(north_and_scale(view))
    st, col = _status_line(L)
    side = [text(0, 14, "Layer 5 — 필지(공유 변)·접근·경계 이유", 15, weight="bold"),
            text(0, 34, f"layout: {st}", 12, weight="bold", fill=col)]
    y = 56
    m = L["metrics"]
    uses = L["summary"]["parcels_by_use"]
    lines = [f"필지: " + ", ".join(f"{k} {v}" for k, v in uses.items()),
             f"가구 {m['households']['programmed']} · 필지에 앉은 가구 {m['households']['on_parcels']}",
             f"밀도 {m['density_households_per_ha']} 호/ha(틀 면적 기준)",
             f"경계 변 {len(L['subdivision']['edges'])} · 면 {len(L['subdivision']['faces'])} · 막다른 골목·샛길 추가 {len(L['streets']['access_revisions'])}",
             f"통행권(easement) {len(L['easements'])}"]
    for role, s in m["parcels_by_role"].items():
        f, a = s["frontage"], s["area"]
        lines.append(f"{role} n={s['n']}: 앞너비 중앙 {f.get('median')} (목표 {f.get('target_range')}) · 넓이 중앙 {a.get('median')} (목표 {a.get('target_range')})")
    lc = sum(1 for e in L["subdivision"]["edges"] if e["level_change"])
    lines.append(f"단차 0.6 m 넘는 변 {lc} (굵은 선, 옹벽 선택지 추가)")
    rs = {}
    for e in L["subdivision"]["edges"]:
        k = e["geometry_reason"].split(":")[0]
        rs[k] = rs.get(k, 0) + 1
    lines.append("변 이유: " + ", ".join(f"{k} {v}" for k, v in sorted(rs.items())))
    for c in L["checks"]:
        if c["id"] in ("WP5.layer", "L5.twin_edges", "L5.access", "L5.households_once", "L5.locks", "V28", "V43", "V46", "V48", "V49", "V70", "V33.data", "PUB-04"):
            v = "통과" if c["pass"] else ("실패" if c["pass"] is False else "해당 없음")
            lines.append(f"{c['id']}: {v}")
    for r in L["revision_requests"][:6]:
        lines.append(f"요청 {r['reason']}: {r['request'][:40]}")
    for l in lines[:40]:
        side.append(text(0, y, l[:66], 10))
        y += 15
    items = [("rect", UCOL[k], k) for k in ("residential", "garden", "hill", "open_ground", "field", "residual_nonbuildable")]
    items += [("line", RSCOL[k], k) for k in ("street_edge", "frontage_normal", "frontage_depth", "rear_access_demand", "easement",
                                               "civic_envelope", "water_setback", "town_wall", "lock_shape")]
    side.append(legend(items, 0, y + 12))
    return _doc(view, "".join(b), "".join(side), f"{inp.name} — 05 필지")
