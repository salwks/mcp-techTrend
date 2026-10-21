# 토담(흙돌담) — 흙에 막돌을 박아 쌓은 담 + 갓(이엉 또는 기와). 두 점 (ax,az)→(bx,bz).
# 고증: 조선 후기 남부 민가는 돌담·토석담이 흔하고, 담 위는 이엉을 얹거나(초가) 기와를 얹었다(양반가).
# params: seed, ax,az,bx,bz (없으면 len(5)), h(1.5), cap:"thatch"|"tile", tile_seg(0.4: 기와 갓 마디 길이)
#         open_a·open_b(false): 그 끝 면을 그리지 않는다 — T자로 다른 담 옆면에 맞댄 끝(건물 빌더 묶음이 씀)
#         cap "none": 갓 없음(폐가 — 갓이 다 빠진 흙담)
#         miter_a·miter_b(0 | ±1): 직각 모서리 끝을 45° 맞춤(끝점 = 두 담 가운데 줄 교점, 부호 = 다른 담이 뻗는 쪽의 로컬 z) — 두 담의 바깥 면·갓이
#           모서리 선 하나에서 만난다(끝 면·먹선이 바깥 면에 줄로 남지 않고, 모서리 덩이를 따로 두지 않는다)
# 삼각형: 약 40~60/m(돌담보다 싸서 집 묶음 둘레에 쓴다).
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const W := preload("res://kit/village/stone_wall.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = params.get("len", 5.0)
	var ax: float = params.get("ax", -L / 2); var az: float = params.get("az", 0.0)
	var bx: float = params.get("bx", L / 2); var bz: float = params.get("bz", 0.0)
	draw(m, ax, az, bx, bz, params.get("h", 1.5), params.get("cap", "thatch"), params.get("tile_seg", 0.4), bool(params.get("open_a", false)), bool(params.get("open_b", false)), float(params.get("miter_a", 0.0)), float(params.get("miter_b", 0.0)))
	return m.result("토담", Vector2(absf(bx - ax) + 0.8, absf(bz - az) + 0.8), true)

static func draw(m: C.M, ax: float, az: float, bx: float, bz: float, h := 1.5, cap := "thatch", tile_seg := 0.4, open_a := false, open_b := false, miter_a := 0.0, miter_b := 0.0) -> void:
	var len := Vector2(bx - ax, bz - az).length()
	var R := m.rng
	var old := m.xform
	m.xform = old * C.seg_xform(ax, az, bx, bz)
	var t := 0.45
	var body := Kit.box(len, h, t, 0, h / 2, 0)
	if miter_a != 0.0 or miter_b != 0.0: body = _miter_box(len, h, t, miter_a, miter_b)
	elif open_a or open_b: body = _open_ends(body, len / 2, open_a, open_b)
	# 끝 x(z): 맞춤 끝이면 z에 따라 비스듬히(바깥 쪽은 늘고 안쪽은 줄어 두 담이 45° 선에서 만남)
	var xa_at := func(z: float) -> float: return -len / 2 + miter_a * z
	var xb_at := func(z: float) -> float: return len / 2 - miter_b * z
	m.add("p", "mud", C.P(body, 0xc9b08a, 0xa08866, 0.04, R), 0.03)
	# 박힌 막돌(앞면만, 두 줄 듬성듬성)
	var n := maxi(2, int(len / 0.75))
	for row in 2:
		for i in n:
			if m.r() < 0.35: continue
			# fix-1017: 고른 두 줄의 같은 크기 밝은 점(물방울 무늬처럼 보임) 대신 — 자리·높이를 흩고 크기를 달리, 흙에 반쯤 묻힌 빛깔
			var x := -len / 2 + (i + 0.5 + 0.35 * row + (m.r() - 0.5) * 0.5) * len / n
			if absf(x) > len / 2 - 0.2: continue
			var rr := 0.1 + m.r() * m.r() * 0.16
			var g := Kit.lump(rr, 0, R, 0.3, 0.6)
			Kit.xf(g, x, 0.25 + row * 0.55 + (m.r() - 0.5) * 0.22, t / 2 - 0.035, 0, m.r() * 3, 0, 1.2 + m.r() * 0.5, 0.8 + m.r() * 0.3, 0.4)
			m.add("p", "stone", C.P(g, 0xa59c88, 0x857c6a, 0.1, R), 0)
	# 갓: 마디로 나눈 맞배 덮개(기와는 0.4m 마디 = 기와 골 한 줄씩)
	var segs := maxi(1, roundi(len / (tile_seg if cap == "tile" else 1.2)))
	var cw := t / 2 + 0.22
	var rh := 0.3 if cap == "tile" else 0.38
	var key := "tile" if cap == "tile" else "thatch"
	var g := Kit.Geo.new()
	var ea := 0.0 if miter_a != 0.0 else 0.1; var eb := 0.0 if miter_b != 0.0 else 0.1   # 맞춤 끝은 갓도 모서리 선까지(내밀지 않음)
	for i in segs:
		var x0 := -len / 2 - ea + (len + ea + eb) * i / segs; var x1 := -len / 2 - ea + (len + ea + eb) * (i + 1) / segs
		for s in [-1, 1]:
			var x0s := x0; var x1s := x1
			if i == 0 and miter_a != 0.0: x0s = xa_at.call(s * cw)
			if i == segs - 1 and miter_b != 0.0: x1s = xb_at.call(s * cw)
			var a := Vector3(x0s, h, s * cw); var b := Vector3(x1s, h, s * cw); var c := Vector3(x1, h + rh, 0); var d := Vector3(x0, h + rh, 0)
			if s > 0: g.quad(a, b, c, d, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
			else: g.quad(b, a, d, c, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	for sx in [-1, 1]:
		if (sx < 0 and miter_a != 0.0) or (sx > 0 and miter_b != 0.0): continue   # 맞춤 끝은 박공 세모 없음(이웃 담 갓이 이어 받음)
		var x: float = sx * (len / 2 + 0.1)
		var p0 := Vector3(x, h, -cw); var p1 := Vector3(x, h, cw); var p2 := Vector3(x, h + rh, 0)
		if sx > 0: g.tri(p0, p2, p1)
		else: g.tri(p0, p1, p2)
	if cap == "none":
		# 갓이 빠진 흙담: 윗면이 둥글게 녹아 낮아진 흙 띠(갓 대신)
		m.add("p", "mud", C.P(Kit.xf(Kit.cyl(t * 0.5, t * 0.5, len, 6, 0, 0, 0, 0, 0, PI / 2), 0, h - 0.02, 0, 0, 0, 0, 1.0, 0.45, 1.0), 0xbfa47e, 0xa08866, 0.05, R), 0.02)
	elif cap == "tile":
		m.add("p", key, C.P(g, 0xd9d9d4, 0xb9b8b2, 0.03, R), 0.03)
		var rl := len + (0.15 if miter_a == 0.0 else 0.0) + (0.15 if miter_b == 0.0 else 0.0)
		var rx := ((0.15 if miter_b == 0.0 else 0.0) - (0.15 if miter_a == 0.0 else 0.0)) / 2
		m.add("p", "flat", C.P(Kit.box(rl, 0.12, 0.2, rx, h + rh, 0), 0x3d3f42), 0.02)
	else:
		m.add("p", key, C.PA(g, C.THATCH, 0.05, R), 0.03)
		m.add("p", "thatch", C.P(Kit.cyl(0.1, 0.1, len + ea + eb, 6, (eb - ea) / 2, h + rh - 0.02, 0, 0, 0, PI / 2), 0xb39d6c, 0x8f7b52), 0.015)
	m.xform = old
	W.add_line_collider(m, ax, az, bx, bz, 0.3)

# 상자에서 끝 면(x = ±hx) 삼각형을 뺀다(맞댄 끝)
static func _open_ends(g: Kit.Geo, hx: float, a: bool, b: bool) -> Kit.Geo:
	var out := Kit.Geo.new()
	for i in range(0, g.pos.size(), 3):
		var xs := [g.pos[i].x, g.pos[i + 1].x, g.pos[i + 2].x]
		if a and absf(xs[0] + hx) < 1e-4 and absf(xs[1] + hx) < 1e-4 and absf(xs[2] + hx) < 1e-4: continue
		if b and absf(xs[0] - hx) < 1e-4 and absf(xs[1] - hx) < 1e-4 and absf(xs[2] - hx) < 1e-4: continue
		for k in 3:
			out.pos.append(g.pos[i + k]); out.uv.append(g.uv[i + k]); out.col.append(g.col[i + k] if g.col.size() > i + k else Color.WHITE)
			if g.nrm.size() > i + k: out.nrm.append(g.nrm[i + k])
	return out

# 끝을 45°로 맞춘 담 몸(8 꼭짓점 상자): 끝 x(z) = ∓len/2 ± miter·z. 면마다 UV 0~1(Kit.box와 같음)
static func _miter_box(L: float, h: float, t: float, ma: float, mb: float) -> Kit.Geo:
	var g := Kit.Geo.new()
	var hz := t / 2
	var xa := func(z: float) -> float: return -L / 2 + ma * z
	var xb := func(z: float) -> float: return L / 2 - mb * z
	var P := [Vector3(xa.call(-hz), 0, -hz), Vector3(xb.call(-hz), 0, -hz), Vector3(xb.call(-hz), h, -hz), Vector3(xa.call(-hz), h, -hz),
		Vector3(xa.call(hz), 0, hz), Vector3(xb.call(hz), 0, hz), Vector3(xb.call(hz), h, hz), Vector3(xa.call(hz), h, hz)]
	g.quad(P[4], P[5], P[6], P[7]) # +z
	g.quad(P[1], P[0], P[3], P[2]) # -z
	g.quad(P[5], P[1], P[2], P[6]) # +x 끝
	g.quad(P[0], P[4], P[7], P[3]) # -x 끝
	g.quad(P[7], P[6], P[2], P[3]) # 위
	g.quad(P[0], P[1], P[5], P[4]) # 밑
	return g
