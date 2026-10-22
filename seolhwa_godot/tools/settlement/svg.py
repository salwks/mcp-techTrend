"""Verification drawings (spec §5): 00-site, 01-program, 02-frame, combined.

North up (-z up), x right. Map units are world metres in the viewBox; strokes use
non-scaling widths. Every panel carries a north arrow, scale bar, legend, ledger and
confidence labels.
"""
from __future__ import annotations

import base64
import io
import math
from xml.sax.saxutils import escape

import numpy as np
from PIL import Image
from shapely.geometry import shape

from . import geometry as G

FONT = "Apple SD Gothic Neo, Noto Sans KR, Helvetica, sans-serif"
MAP_W = 820
SIDE_W = 360

CAT_COL = {"water": "#4a90d9", "drainage_reserve": "#7fb7e6", "protected": "#c0504d", "locks": "#7b3fa0",
           "civic_reserve": "#b5651d", "civic_forecourt": "#e8b27a", "primary_corridor": "#f08c00",
           "water_supply": "#1f6fb2", "flood_exclusion": "#5bc8d8", "unbuildable_slope": "#9c9c9c",
           "residential_gross": "#7cbf5a", "unusable_fragment": "#d6c36a"}
CAT_KO = {"water": "물", "drainage_reserve": "물길 예비", "protected": "보호지", "locks": "고정 장소",
          "civic_reserve": "관아·공공 터", "civic_forecourt": "앞마당·진입", "primary_corridor": "주 가로(7.2 m)",
          "water_supply": "우물·물터", "flood_exclusion": "범람 +3 제외", "unbuildable_slope": "급경사 제외",
          "residential_gross": "주거 가능지", "unusable_fragment": "자투리(쓸 수 없음)"}


def _f(v):
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def path_d(geom):
    if geom is None or geom.is_empty:
        return ""
    out = []
    polys = [geom] if geom.geom_type == "Polygon" else [g for g in getattr(geom, "geoms", []) if g.geom_type == "Polygon"]
    if geom.geom_type in ("LineString", "LinearRing"):
        cs = list(geom.coords)
        return "M" + " L".join(f"{_f(x)},{_f(z)}" for x, z in cs)
    if geom.geom_type == "MultiLineString":
        return " ".join(path_d(l) for l in geom.geoms)
    for p in polys:
        for ring in [p.exterior] + list(p.interiors):
            cs = list(ring.coords)
            out.append("M" + " L".join(f"{_f(x)},{_f(z)}" for x, z in cs) + " Z")
    return " ".join(out)


class View:
    def __init__(self, bounds):
        xmin, zmin, xmax, zmax = bounds
        self.xmin, self.zmin, self.w, self.h = xmin, zmin, xmax - xmin, zmax - zmin
        self.px = MAP_W / self.w
        self.H = int(round(self.h * self.px))

    def vb(self):
        return f"{_f(self.xmin)} {_f(self.zmin)} {_f(self.w)} {_f(self.h)}"


def view_for(plan_geom_bounds, margin_frac=0.25, min_margin=60):
    xmin, zmin, xmax, zmax = plan_geom_bounds
    m = max(min_margin, margin_frac * max(xmax - xmin, zmax - zmin))
    xmin, zmin, xmax, zmax = xmin - m, zmin - m, xmax + m, zmax + m
    # square-ish aspect limits
    w, h = xmax - xmin, zmax - zmin
    if h < 0.6 * w:
        c = (zmin + zmax) / 2
        zmin, zmax = c - 0.3 * w, c + 0.3 * w
    if h > 1.3 * w:
        c = (xmin + xmax) / 2
        xmin, xmax = c - h / 2.6, c + h / 2.6
    return View((xmin, zmin, xmax, zmax))


def relief_image(A, view, faint=False):
    g = A.win
    sub, sl = g.sub(view.xmin, view.zmin, view.xmin + view.w, view.zmin + view.h)
    h = A.h[sl]
    if h.size == 0:
        return ""
    lo, hi = np.percentile(h, 1), np.percentile(h, 99)
    t = np.clip((h - lo) / max(hi - lo, 1e-6), 0, 1)
    dz, dx = np.gradient(h, g.cell)
    az, alt = math.radians(315), math.radians(45)
    slope = np.arctan(np.hypot(dx, dz))
    aspect = np.arctan2(-dx, dz)
    shade = np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect)
    shade = np.clip(shade, 0, 1)
    c0 = np.array([0.93, 0.95, 0.88])
    c1 = np.array([0.80, 0.74, 0.62])
    rgb = c0[None, None, :] * (1 - t[..., None]) + c1[None, None, :] * t[..., None]
    rgb = rgb * (0.70 + 0.30 * shade[..., None])
    if faint:
        rgb = 0.55 * rgb + 0.45
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB")
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=False)
    b64 = base64.b64encode(buf.getvalue()).decode()
    x0 = sub.x0 - g.cell / 2
    z0 = sub.z0 - g.cell / 2
    return (f'<image x="{_f(x0)}" y="{_f(z0)}" width="{_f(sub.nx * g.cell)}" height="{_f(sub.nz * g.cell)}" '
            f'preserveAspectRatio="none" image-rendering="optimizeQuality" href="data:image/png;base64,{b64}"/>')


def contours(A, view, step=5.0, index=25.0):
    g = A.win
    sub, sl = g.sub(view.xmin, view.zmin, view.xmin + view.w, view.zmin + view.h)
    h = A.h[sl]
    if h.shape[0] < 2 or h.shape[1] < 2:
        return ""
    xs = sub.xs()
    zs = sub.zs()
    lv0 = math.ceil(h.min() / step) * step
    paths_n, paths_i = [], []
    lev = lv0
    while lev <= h.max():
        a = h[:-1, :-1]; b = h[:-1, 1:]; c = h[1:, 1:]; d = h[1:, :-1]
        segs = []
        # edge crossing points: top (a-b), right (b-c), bottom (d-c), left (a-d)
        def cross(p, q):
            return ((p < lev) != (q < lev))
        def interp(p, q):
            with np.errstate(divide="ignore", invalid="ignore"):
                return np.clip((lev - p) / (q - p), 0, 1)
        J, I = np.mgrid[0:h.shape[0] - 1, 0:h.shape[1] - 1]
        X0 = xs[I]; Z0 = zs[J]
        cs = g.cell
        e = []
        m = cross(a, b); t = interp(a, b); e.append((m, X0 + t * cs, Z0))
        m = cross(b, c); t = interp(b, c); e.append((m, X0 + cs, Z0 + t * cs))
        m = cross(d, c); t = interp(d, c); e.append((m, X0 + t * cs, Z0 + cs))
        m = cross(a, d); t = interp(a, d); e.append((m, X0, Z0 + t * cs))
        cnt = sum(x[0].astype(int) for x in e)
        two = cnt == 2
        if two.any():
            pts = []
            for k in range(4):
                pts.append(e[k])
            # first and second crossing per cell
            got = np.zeros(two.shape, int)
            P1x = np.zeros(two.shape); P1z = np.zeros(two.shape); P2x = np.zeros(two.shape); P2z = np.zeros(two.shape)
            for m, X, Z in pts:
                sel1 = two & m & (got == 0)
                P1x[sel1] = X[sel1]; P1z[sel1] = Z[sel1]
                sel2 = two & m & (got == 1)
                P2x[sel2] = X[sel2]; P2z[sel2] = Z[sel2]
                got += (two & m).astype(int)
            w = np.nonzero(two)
            d_ = "".join(f"M{P1x[j, i]:.1f},{P1z[j, i]:.1f}L{P2x[j, i]:.1f},{P2z[j, i]:.1f}" for j, i in zip(*w))
            (paths_i if abs(lev % index) < 1e-6 else paths_n).append(d_)
        lev += step
    out = ""
    if paths_n:
        out += f'<path d="{"".join(paths_n)}" fill="none" stroke="#8a7a5c" stroke-opacity="0.45" stroke-width="0.6" vector-effect="non-scaling-stroke"/>'
    if paths_i:
        out += f'<path d="{"".join(paths_i)}" fill="none" stroke="#6b5a3a" stroke-opacity="0.7" stroke-width="1.1" vector-effect="non-scaling-stroke"/>'
    return out


def P(d, fill="none", stroke="none", sw=1.0, op=1.0, dash=None, fop=None, extra=""):
    if not d:
        return ""
    s = f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" vector-effect="non-scaling-stroke"'
    if fop is not None:
        s += f' fill-opacity="{fop}"'
    if op != 1.0:
        s += f' opacity="{op}"'
    if dash:
        s += f' stroke-dasharray="{dash}"'
    s += f' fill-rule="evenodd" {extra}/>'
    return s


DEFS = """<defs>
<pattern id="hatchR" patternUnits="userSpaceOnUse" width="5" height="5" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="5" stroke="#c0504d" stroke-width="1.2"/></pattern>
<pattern id="hatchB" patternUnits="userSpaceOnUse" width="4" height="4" patternTransform="rotate(-45)"><line x1="0" y1="0" x2="0" y2="4" stroke="#3d7fc4" stroke-width="0.8"/></pattern>
<pattern id="hatchG" patternUnits="userSpaceOnUse" width="5" height="5" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="5" stroke="#777" stroke-width="0.8"/></pattern>
</defs>"""


def text(x, y, s, size=12, anchor="start", weight="normal", fill="#222"):
    return (f'<text x="{_f(x)}" y="{_f(y)}" font-family="{FONT}" font-size="{size}" text-anchor="{anchor}" '
            f'font-weight="{weight}" fill="{fill}">{escape(str(s))}</text>')


def north_and_scale(view, x=20, y=20):
    """North arrow + scale bar in panel pixel coordinates."""
    out = [f'<g transform="translate({x},{y})">',
           '<polygon points="12,0 20,26 12,20 4,26" fill="#222"/>', text(12, 40, "N", 12, "middle", "bold"), "</g>"]
    target = view.w / 4
    nice = [10, 20, 25, 50, 100, 200, 250, 500, 1000]
    L = max(n for n in nice if n <= max(target, 10))
    lp = L * view.px
    by = view.H - 24
    out.append(f'<g transform="translate(20,{by})"><rect x="0" y="0" width="{_f(lp / 2)}" height="6" fill="#222"/>'
               f'<rect x="{_f(lp / 2)}" y="0" width="{_f(lp / 2)}" height="6" fill="#fff" stroke="#222"/>'
               + text(0, -4, "0", 10) + text(lp, -4, f"{L} m", 10, "end") + "</g>")
    return "".join(out)


def legend(items, x, y):
    out = []
    for n, (kind, col, label) in enumerate(items):
        yy = y + n * 18
        if kind == "line":
            out.append(f'<line x1="{x}" y1="{yy}" x2="{x + 22}" y2="{yy}" stroke="{col}" stroke-width="3"/>')
        elif kind == "dash":
            out.append(f'<line x1="{x}" y1="{yy}" x2="{x + 22}" y2="{yy}" stroke="{col}" stroke-width="2" stroke-dasharray="4 3"/>')
        elif kind == "hatch":
            out.append(f'<rect x="{x}" y="{yy - 6}" width="22" height="12" fill="url(#{col})" stroke="#888" stroke-width="0.5"/>')
        else:
            out.append(f'<rect x="{x}" y="{yy - 6}" width="22" height="12" fill="{col}" fill-opacity="0.7" stroke="#555" stroke-width="0.5"/>')
        out.append(text(x + 30, yy + 4, label, 11))
    return "".join(out)


def _g(plan, gid):
    return shape(plan["geometry"][gid]) if gid else None


def _map_open(view, title):
    return (f'<svg x="0" y="0" width="{MAP_W}" height="{view.H}" viewBox="{view.vb()}">'
            f'<rect x="{_f(view.xmin)}" y="{_f(view.zmin)}" width="{_f(view.w)}" height="{_f(view.h)}" fill="#f6f4ee"/>')


def _doc(view, body, side, title):
    W = MAP_W + SIDE_W
    H = max(view.H, 760) + 40
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">' + DEFS +
            f'<rect width="{W}" height="{H}" fill="#ffffff"/>' + text(12, 26, title, 17, weight="bold") +
            f'<g transform="translate(0,40)">' + body + "</g>" +
            f'<g transform="translate({MAP_W + 14},40)">' + side + "</g></svg>")


def _water_layers(plan, A):
    return P(path_d(A.water_poly), fill="#4a90d9", fop=0.85)


def site_svg(plan, inp, A, view):
    s = plan["site"]["summary"]
    b = [_map_open(view, "site"), relief_image(A, view), contours(A, view)]
    b.append(P(path_d(A.farm_poly), fill="#a0743c", fop=0.35))
    b.append(P(path_d(A.house_poly), fill="#4caf50", fop=0.22))
    b.append(P(path_d(A.civic_poly), stroke="#2e7d32", sw=0.8, fill="none"))
    for k, col, op in ((5, "#bfeaf0", 0.55), (3, "#5bc8d8", 0.55), (1, "#1c9fb3", 0.6)):
        b.append(P(path_d(A.flood_polys[k]), fill=col, fop=op))
    b.append(P(path_d(A.drain_poly), fill="url(#hatchB)", stroke="#3d7fc4", sw=0.6))
    b.append(_water_layers(plan, A))
    b.append(P(path_d(A.protected_poly), fill="url(#hatchR)", stroke="#c0504d", sw=0.8))
    for r in inp.roads:
        b.append(P(path_d(r.line), stroke="#e07b00", sw=2.2))
    for c in A.existing_crossings:
        b.append(f'<circle cx="{c["xz"][0]}" cy="{c["xz"][1]}" r="{_f(4 / view.px)}" fill="#fff" stroke="#e07b00" stroke-width="1.5" vector-effect="non-scaling-stroke"/>')
    b.append(P(path_d(_g(plan, plan["territory"]["allowed"])), stroke="#333", sw=1.2, dash="2 3"))
    b.append(P(path_d(_g(plan, plan["territory"]["preferred"])), stroke="#000", sw=1.8, dash="8 4"))
    b.append(_axes(inp, plan, view))
    b.append("</svg>")
    b.append(north_and_scale(view))
    st = s["site_score"]
    side = [text(0, 14, "Layer 0 — 땅 읽기", 15, weight="bold"),
            legend([("rect", "#4caf50", "주거 가능(경사≤15°, 물·범람+3·물길·보호 제외)"),
                    ("line", "#2e7d32", "관아 가능 테두리(경사≤10°)"),
                    ("rect", "#1c9fb3", f"범람 화면 +1 m(원지형) = 게임 {inp.vertical_scale * 1:.2f} m"),
                    ("rect", "#5bc8d8", f"범람 화면 +3 m(점유 제외) = {inp.vertical_scale * 3:.2f} m"),
                    ("rect", "#bfeaf0", f"범람 화면 +5 m = {inp.vertical_scale * 5:.2f} m"),
                    ("hatch", "hatchB", "물길 예비(폭/2+3 m)"), ("rect", "#4a90d9", "물"),
                    ("hatch", "hatchR", "보호지(배정 밖 농지·이웃 마을)"), ("rect", "#a0743c", "농지(논·밭)"),
                    ("line", "#e07b00", "기존 길 / ○ 건널목"), ("dash", "#000", "배정(preferred)"),
                    ("dash", "#333", "허용(allowed)"), ("line", "#7b3fa0", "축(진산→안산, 주어진 값)")], 4, 44)]
    y = 44 + 13 * 18 + 10
    lines = [f"경사 중앙 {s['slope_deg']['median']}° / p90 {s['slope_deg']['p90']}°  기복 {s['relief_m']} m",
             f"범람 비율 +1/+3/+5: {s['frac_flood']['1']:.2f} / {s['frac_flood']['3']:.2f} / {s['frac_flood']['5']:.2f}",
             f"주거 가능 {s['frac_housing_buildable']:.2f} · 관아 가능 {s['frac_civic_buildable']:.2f}",
             f"물 접근 비용 중앙 {s['water_access_cost_m']['median']} m (목표 150, 한계 300)",
             f"길 접근 비용 중앙 {s['route_access_cost_m']['median']} m",
             f"농지 300/600 m: {s['farmland_within_m2']}  잠식 {s['farmland_displaced_m2']} m²",
             f"세로 배율 {inp.vertical_scale} (원지형 m → 게임 m)",
             f"터 점수 S_T = {st['S']}  {st['terms']}"]
    for n, l in enumerate(lines):
        side.append(text(0, y + n * 17, l, 11))
    y += len(lines) * 17 + 14
    side.append(text(0, y, "신뢰도: 범람은 정적 시나리오 화면(확률 아님) · 흐름 누적·일조·조망·진산 자동 판정은 보류", 10, fill="#a33"))
    y += 16
    for n, d in enumerate([d for d in plan["diagnostics"] if d["layer"] == "L0"][:10]):
        side.append(text(0, y + n * 15, f"[{d['severity']}] {d['code']}: {d['message'][:46]}", 10, fill="#555"))
    return _doc(view, "".join(b), "".join(side), f"{inp.name} ({inp.region}/{inp.id}) — 00 땅")


def _axes(inp, plan, view):
    out = []
    t = inp.territory["preferred"].centroid
    for ax in inp.axes:
        dx, dz = G.bearing_vec(ax["bearing"])
        L = view.w * 0.18
        x1, z1 = t.x - dx * L, t.y - dz * L
        x2, z2 = t.x + dx * L, t.y + dz * L
        out.append(f'<line x1="{_f(x1)}" y1="{_f(z1)}" x2="{_f(x2)}" y2="{_f(z2)}" stroke="#7b3fa0" stroke-width="2" stroke-dasharray="6 3" vector-effect="non-scaling-stroke"/>')
        out.append(f'<circle cx="{_f(x2)}" cy="{_f(z2)}" r="{_f(4 / view.px)}" fill="#7b3fa0"/>')
        fs = 11 / view.px
        out.append(f'<text x="{_f(x2)}" y="{_f(z2 - 6 / view.px)}" font-family="{FONT}" font-size="{_f(fs)}" fill="#7b3fa0">축 {ax["bearing"]:.0f}° ({escape(ax["confidence"])})</text>')
    return "".join(out)


def _ledger_geoms(extras):
    ev = extras.get("shown")
    if not ev or "ledger" not in ev:
        return None
    return ev["ledger"][1]


def program_svg(plan, inp, A, L1, extras, view):
    prog = plan["program"]
    b = [_map_open(view, "program"), relief_image(A, view, faint=True)]
    entries = _ledger_geoms(extras) or L1["entries"]
    for e in entries:
        col = CAT_COL.get(e["category"], "#999")
        b.append(P(path_d(e["geom"]), fill=col, fop=0.7, stroke="#fff", sw=0.3))
    ev = extras.get("shown")
    if ev:
        for n, p in enumerate(ev.get("placed", []) or []):
            b.append(P(path_d(p["rect"]), stroke="#5a2d0c", sw=1.2))
            c = p["rect"].centroid
            fs = 13 / view.px
            b.append(f'<text x="{_f(c.x)}" y="{_f(c.y + fs / 3)}" font-family="{FONT}" font-size="{_f(fs)}" text-anchor="middle" font-weight="bold" fill="#000">{n + 1}</text>')
        b.append(P(path_d(ev["poly"]), stroke="#000", sw=2.0))
    b.append(P(path_d(_g(plan, plan["territory"]["preferred"])), stroke="#000", sw=1.2, dash="8 4"))
    b.append("</svg>")
    b.append(north_and_scale(view))
    led = prog["area_ledger"]
    side = [text(0, 14, "Layer 1 — 수용력 먼저(땅 → 호수)", 15, weight="bold"),
            text(0, 34, f"기준: {prog.get('basis')} · 등급 {prog['profile_name']} ({prog['profile']})", 11)]
    y = 54
    tot = led["territory_m2"] or 1
    side.append(text(0, y, f"영역 {led['territory_m2']:,.0f} m² · 잔차 {led['residual_m2']} m² (≤0.1)", 11, weight="bold"))
    y += 8
    for c in led["categories"]:
        y += 17
        w = 200 * c["area_m2"] / tot
        side.append(f'<rect x="0" y="{y - 10}" width="{_f(max(w, 0.5))}" height="11" fill="{CAT_COL.get(c["category"], "#999")}"/>')
        side.append(text(206, y, f"{CAT_KO.get(c['category'], c['category'])} {c['area_m2']:,.0f}", 10))
    y += 22
    rs = led["residential_split"]
    side.append(text(0, y, f"주거지 = 필지 {rs['parcels_m2']:,.0f} + 골목 {rs['lanes_m2']:,.0f}(.12) + 텃밭·빈터 {rs['open_cultivated_m2']:,.0f}(.20)", 10))
    hh = prog["households"]
    y += 22
    side.append(text(0, y, f"표현 호수 {hh['represented']} 호 (계획 수용력 추정) · 인구 약 {hh['population_estimate']} 명", 12, weight="bold"))
    pa = hh["parcel_area_m2"]
    for c in ("elite", "specialist", "ordinary"):
        y += 16
        ko = {"elite": "양반·상층", "specialist": "중인·서리·장인", "ordinary": "평민·의존"}[c]
        side.append(text(8, y, f"{ko}: {hh['by_class'].get(c, 0)} 호 × {pa[c]:.0f} m²(×1.44 한 번)", 10))
    y += 16
    side.append(text(8, y, f"생업: {hh['livelihood']}"[:80], 9))
    y += 18
    side.append(text(0, y, f"최소 {prog['residential_minimum']} 호 · 역사 호수 {prog['historical_households']} · 비율 {prog['representation_ratio']}", 10))
    y += 20
    side.append(text(0, y, "관아·공공 터(번호 = 지도)", 12, weight="bold"))
    for n, i in enumerate([i for i in prog["institutions"] if i["inside_wall"] and i["variant"]]):
        y += 15
        e = i["envelope"]
        side.append(text(8, y, f"{n + 1}. {i['name']} [{i['variant']}] {e['width_m']:.0f}×{e['depth_m']:.0f} m = {e['area_m2']:,.0f} m²", 10))
    for i in prog["institutions"]:
        if not i["inside_wall"]:
            y += 15
            side.append(text(8, y, f"· {i['name']}: 성 밖(이 층에서 배치 보류)", 10, fill="#777"))
    y += 20
    ae = prog["allocation_estimate"]
    side.append(text(0, y, f"배정만으로 추정(L1 단독): {ae['households']} 호, 묶음 {ae['bundle'][:40]}", 10, fill="#555"))
    y += 18
    for d in [d for d in plan["diagnostics"] if d["layer"] in ("L1",) and d["severity"] != "info"][:4]:
        side.append(text(0, y, f"[{d['severity']}] {d['code']}: {d['message'][:50]}", 10, fill="#a33"))
        y += 15
    side.append(text(0, y + 6, "신뢰도: 필지 중앙값은 실측(×1.44), 관아 크기·비율은 잠정 규칙", 10, fill="#a33"))
    lg = [("rect", CAT_COL[k], CAT_KO[k]) for k in CAT_COL]
    side.append(legend(lg, 0, y + 30))
    return _doc(view, "".join(b), "".join(side), f"{inp.name} — 01 프로그램·장부")


def frame_svg(plan, inp, A, extras, view, F):
    fr = plan["frame"]
    b = [_map_open(view, "frame"), relief_image(A, view, faint=True), contours(A, view)]
    b.append(P(path_d(A.flood_polys[3]), fill="#5bc8d8", fop=0.35))
    b.append(P(path_d(A.drain_poly), fill="url(#hatchB)"))
    b.append(_water_layers(plan, A))
    b.append(P(path_d(A.protected_poly), fill="url(#hatchR)", stroke="#c0504d", sw=0.6))
    for r in inp.roads:
        b.append(P(path_d(r.line), stroke="#e07b00", sw=1.6, op=0.8))
    for a in plan["alternatives"][1:]:
        b.append(P(path_d(_g(plan, a["territory"])), stroke="#666", sw=0.8, dash="3 3", op=0.7))
    b.append(P(path_d(_g(plan, plan["territory"]["allowed"])), stroke="#333", sw=1.0, dash="2 3"))
    side = [text(0, 14, "Layer 2 — 틀(성곽·문·관아 터·주 가로)", 15, weight="bold")]
    st = plan["status"]
    side.append(text(0, 36, f"상태: {st}" + (f" ({plan['status_reason']})" if plan["status_reason"] else ""), 13,
                     weight="bold", fill="#1a7f37" if st == "valid" else "#b42318"))
    if fr is None:
        b.append("</svg>")
        b.append(north_and_scale(view))
        y = 60
        for d in plan["diagnostics"]:
            if d["layer"] == "L2":
                side.append(text(0, y, f"{d['code']}: {d['message'][:55]}", 10, fill="#b42318"))
                y += 15
                if d.get("data"):
                    side.append(text(8, y, str(d["data"])[:70], 9, fill="#555"))
                    y += 15
        return _doc(view, "".join(b), "".join(side), f"{inp.name} — 02 틀")
    poly = _g(plan, fr["territory"])
    b.append(P(path_d(poly), fill="#fff8e6", fop=0.45, stroke="#8a6d3b" if fr["wall"] is None else "none", sw=1.4,
               dash="5 3" if fr["wall"] is None else None))
    if fr.get("primary_corridors"):
        b.append(P(path_d(_g(plan, fr["primary_corridors"]["reservation"])), fill="#f5a623", fop=0.55))
        for l in fr["primary_corridors"]["links"]:
            b.append(P(path_d(_g(plan, l["centerline"])), stroke="#b35900", sw=1.2))
        for n in fr["primary_corridors"]["nodes"]:
            if n["kind"] == "junction":
                b.append(f'<circle cx="{n["xz"][0]}" cy="{n["xz"][1]}" r="{_f(3 / view.px)}" fill="#b35900"/>')
    for c in fr.get("connectors", []):
        b.append(P(path_d(_g(plan, c["path"])), stroke="#e07b00", sw=1.4, dash="4 3"))
    for r in fr.get("reroutes", []):
        b.append(P(path_d(_g(plan, r["path"])), stroke="#d62728", sw=1.6, dash="2 2"))
    for n, c in enumerate(fr["civic_reserves"]):
        b.append(P(path_d(_g(plan, c["forecourt"])), fill="#e8b27a", fop=0.8))
        b.append(P(path_d(_g(plan, c["envelope"])), fill="#b5651d", fop=0.75, stroke="#5a2d0c", sw=1.0))
        e = _g(plan, c["envelope"]).centroid
        fs = 13 / view.px
        b.append(f'<text x="{_f(e.x)}" y="{_f(e.y + fs / 3)}" font-family="{FONT}" font-size="{_f(fs)}" text-anchor="middle" font-weight="bold" fill="#fff">{n + 1}</text>')
    for w in fr["water_access"]:
        b.append(P(path_d(_g(plan, w["reservation"])), fill="#1f6fb2", fop=0.9))
    rejected = plan["status"] != "valid"
    if rejected:
        c = poly.centroid
        fs = 16 / view.px
        b.append(f'<text x="{_f(c.x)}" y="{_f(c.y)}" font-family="{FONT}" font-size="{_f(fs)}" text-anchor="middle" font-weight="bold" fill="#b42318">기각 후보(진단용) — 확정 아님</text>')
    if fr["wall"]:
        b.append(P(path_d(_g(plan, fr["wall"]["ring"])), stroke="#b42318" if rejected else "#111", sw=2.0 if rejected else 3.2,
                   dash="8 5" if rejected else None))
        for o in fr["openings"]:
            x, z = o["center"]
            if o["type"] == "gate":
                s = 7 / view.px
                b.append(f'<rect x="{_f(x - s)}" y="{_f(z - s)}" width="{_f(2 * s)}" height="{_f(2 * s)}" fill="#d62728" stroke="#fff" stroke-width="1" vector-effect="non-scaling-stroke"/>')
                fs = 12 / view.px
                b.append(f'<text x="{_f(x + 1.6 * s)}" y="{_f(z - 1.2 * s)}" font-family="{FONT}" font-size="{_f(fs)}" font-weight="bold" fill="#d62728">{o["id"].replace("gate-", "G")}</text>')
            else:
                s = 5 / view.px
                b.append(f'<circle cx="{_f(x)}" cy="{_f(z)}" r="{_f(s)}" fill="#1565c0" stroke="#fff" stroke-width="1" vector-effect="non-scaling-stroke"/>')
    else:
        for n in (fr.get("primary_corridors") or {}).get("nodes", []):
            if n["kind"] == "route_entrance":
                s = 6 / view.px
                b.append(f'<rect x="{_f(n["xz"][0] - s)}" y="{_f(n["xz"][1] - s)}" width="{_f(2 * s)}" height="{_f(2 * s)}" fill="#d62728"/>')
    for a in fr.get("approaches", []):
        s = 4 / view.px
        b.append(f'<circle cx="{a["xz"][0]}" cy="{a["xz"][1]}" r="{_f(s)}" fill="none" stroke="#e07b00" stroke-width="1.5" vector-effect="non-scaling-stroke"/>')
    b.append(_axes(inp, plan, view))
    b.append("</svg>")
    b.append(north_and_scale(view))
    y = 58
    obj = fr.get("objective") or {}
    lines = [f"가족: {fr['family']} · 면적 {fr['area_m2']:,.0f} m² · 대안 {len(plan['alternatives'])}개(회색 점선)",
             f"후보 생성 {plan['candidates']['generated']} · 평가 {plan['candidates']['evaluated']} · 기각 {plan['candidates']['rejections']}",
             f"목표 {obj.get('score')} = {obj.get('terms')}",
             f"호수 {fr.get('households')} · 묶음 {plan['program'].get('bundle', {}).get('name', '')[:42]}"]
    if fr["wall"]:
        gates = [o for o in fr["openings"] if o["type"] == "gate"]
        wps = [o for o in fr["openings"] if o["type"] == "water_passage"]
        lines.append(f"성 둘레 {fr['wall']['length_m']:.0f} m · 문 {len(gates)} · 수문/수구 {len(wps)} · 우회 {len(fr.get('reroutes', []))}")
        for o in fr["openings"]:
            lines.append(f"  {o['id']} {o['subtype']} s={o['chainage'][0]:.0f}–{o['chainage'][1]:.0f} {o.get('routes') or o.get('channel') or ''}")
    for l in (fr.get("primary_corridors") or {}).get("links", [])[:8]:
        lines.append(f"  {l['id']} {l['nodes'][0]}→{l['nodes'][1]} {l['length_m']:.0f} m 최대경사 {l['grade_max'] * 100:.1f}%")
    for w in fr["water_access"]:
        lines.append(f"물: {w['kind']} 비용 {w['walking_cost_m']} m · {w['uncertainty']}")
    for c in fr["civic_reserves"]:
        lines.append(f"  {c['order']}. {c['name']} [{c['variant']}] {c['bearing_deg']:.0f}° 기복 {c['relief_m']} m" + (" (축대 필요)" if c["terrace_required"] else ""))
    for l in lines[:34]:
        side.append(text(0, y, l[:70], 10))
        y += 15
    y += 6
    for c in fr["constraints"][:8]:
        side.append(text(0, y, f"[{c['severity']}] {c['code']}: {c['message'][:50]}", 10, fill="#b42318" if c["severity"] == "error" else "#8a6d00"))
        y += 15
    side.append(legend([("line", "#111", "성벽(닫힌 고리)"), ("rect", "#d62728", "문(G#) — 길 접근 묶음"),
                        ("rect", "#1565c0", "수문·수구(물길 교차)"), ("rect", "#b5651d", "관아·공공 터(번호)"),
                        ("rect", "#e8b27a", "앞마당·진입 여유"), ("rect", "#f5a623", "주 가로 7.2 m(≤10%)"),
                        ("dash", "#e07b00", "바깥 연결로"), ("dash", "#d62728", "길 우회(성 밖)"),
                        ("rect", "#1f6fb2", "물 확보 터"), ("rect", "#5bc8d8", "범람 +3 m 제외"),
                        ("dash", "#666", "다른 대안(2–8위)")], 0, y + 14))
    side.append(text(0, y + 14 + 11 * 18 + 8, "신뢰도: 규칙값 대부분 잠정(provisional) · 축은 region 주어진 값", 10, fill="#a33"))
    return _doc(view, "".join(b), "".join(side), f"{inp.name} — 02 틀")


def combined(svgs, title):
    """Three panels side by side in one SVG."""
    import re
    ws, hs, inner = [], [], []
    x = 0
    for s in svgs:
        m = re.match(r'<svg xmlns="http://www.w3.org/2000/svg" width="(\d+)" height="(\d+)"', s)
        w, h = int(m.group(1)), int(m.group(2))
        body = s[s.index(">") + 1:s.rindex("</svg>")]
        inner.append(f'<svg x="{x}" y="40" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>')
        x += w + 10
        hs.append(h)
    W, H = x, max(hs) + 40
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'<rect width="{W}" height="{H}" fill="#fff"/>' + text(12, 28, title, 20, weight="bold") + "".join(inner) + "</svg>")
