# 토담(흙돌담) — 흙에 막돌을 박아 쌓은 담 + 갓(이엉 또는 기와). 두 점 (ax,az)→(bx,bz).
# 고증: 조선 후기 남부 민가는 돌담·토석담이 흔하고, 담 위는 이엉을 얹거나(초가) 기와를 얹었다(양반가).
# params: seed, ax,az,bx,bz (없으면 len(5)), h(1.5), cap:"thatch"|"tile", tile_seg(0.4: 기와 갓 마디 길이)
# 삼각형: 약 40~60/m(돌담보다 싸서 집 묶음 둘레에 쓴다).
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const W := preload("res://kit/village/stone_wall.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = params.get("len", 5.0)
	var ax: float = params.get("ax", -L / 2); var az: float = params.get("az", 0.0)
	var bx: float = params.get("bx", L / 2); var bz: float = params.get("bz", 0.0)
	draw(m, ax, az, bx, bz, params.get("h", 1.5), params.get("cap", "thatch"), params.get("tile_seg", 0.4))
	return m.result("토담", Vector2(absf(bx - ax) + 0.8, absf(bz - az) + 0.8), true)

static func draw(m: C.M, ax: float, az: float, bx: float, bz: float, h := 1.5, cap := "thatch", tile_seg := 0.4) -> void:
	var len := Vector2(bx - ax, bz - az).length()
	var R := m.rng
	var old := m.xform
	m.xform = old * C.seg_xform(ax, az, bx, bz)
	var t := 0.45
	m.add("p", "mud", C.P(Kit.box(len, h, t, 0, h / 2, 0), 0xc9b08a, 0xa08866, 0.04, R), 0.03)
	# 박힌 막돌(앞면만, 두 줄 듬성듬성)
	var n := maxi(2, int(len / 0.75))
	for row in 2:
		for i in n:
			if m.r() < 0.25: continue
			var x := -len / 2 + (i + 0.5 + 0.35 * row) * len / n
			if x > len / 2 - 0.2: continue
			var g := Kit.lump(0.17 + m.r() * 0.06, 0, R, 0.3, 0.6)
			Kit.xf(g, x, 0.3 + row * 0.55, t / 2 - 0.02, 0, m.r() * 3, 0, 1.3, 1, 0.45)
			m.add("p", "stone", C.P(g, 0xb3ac9c, 0x8f887a, 0.08, R), 0)
	# 갓: 마디로 나눈 맞배 덮개(기와는 0.4m 마디 = 기와 골 한 줄씩)
	var segs := maxi(1, roundi(len / (tile_seg if cap == "tile" else 1.2)))
	var cw := t / 2 + 0.22
	var rh := 0.3 if cap == "tile" else 0.38
	var key := "tile" if cap == "tile" else "thatch"
	var g := Kit.Geo.new()
	for i in segs:
		var x0 := -len / 2 - 0.1 + (len + 0.2) * i / segs; var x1 := -len / 2 - 0.1 + (len + 0.2) * (i + 1) / segs
		for s in [-1, 1]:
			var a := Vector3(x0, h, s * cw); var b := Vector3(x1, h, s * cw); var c := Vector3(x1, h + rh, 0); var d := Vector3(x0, h + rh, 0)
			if s > 0: g.quad(a, b, c, d, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
			else: g.quad(b, a, d, c, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	for sx in [-1, 1]:
		var x: float = sx * (len / 2 + 0.1)
		var p0 := Vector3(x, h, -cw); var p1 := Vector3(x, h, cw); var p2 := Vector3(x, h + rh, 0)
		if sx > 0: g.tri(p0, p2, p1)
		else: g.tri(p0, p1, p2)
	if cap == "tile":
		m.add("p", key, C.P(g, 0xd9d9d4, 0xb9b8b2, 0.03, R), 0.03)
		m.add("p", "flat", C.P(Kit.box(len + 0.3, 0.12, 0.2, 0, h + rh, 0), 0x3d3f42), 0.02)
	else:
		m.add("p", key, C.PA(g, C.THATCH, 0.05, R), 0.03)
		m.add("p", "thatch", C.P(Kit.cyl(0.1, 0.1, len + 0.2, 6, 0, h + rh - 0.02, 0, 0, 0, PI / 2), 0xb39d6c, 0x8f7b52), 0.015)
	m.xform = old
	W.add_line_collider(m, ax, az, bx, bz, 0.3)
