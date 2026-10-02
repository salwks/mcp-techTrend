# 싸리 울타리(바자울) — 웹 buildings.js fence() 이식. 두 점 (ax,az)→(bx,bz).
# params: seed, ax,az,bx,bz (없으면 len(4) 길이로 x축, 원점 중심), h(1.15), lite(false: true면 살을 톱니 판 하나로, 먹선 생략 — 집 묶음·긴 구간용, ~35/m)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const W := preload("res://kit/village/stone_wall.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = params.get("len", 4.0)
	var ax: float = params.get("ax", -L / 2); var az: float = params.get("az", 0.0)
	var bx: float = params.get("bx", L / 2); var bz: float = params.get("bz", 0.0)
	draw(m, ax, az, bx, bz, params.get("h", 1.15), bool(params.get("lite", false)))
	return m.result("싸리울", Vector2(absf(bx - ax) + 0.3, absf(bz - az) + 0.3), false)

static func draw(m: C.M, ax: float, az: float, bx: float, bz: float, h := 1.15, lite := false) -> void:
	var len := Vector2(bx - ax, bz - az).length()
	var R := m.rng
	var old := m.xform
	m.xform = old * C.seg_xform(ax, az, bx, bz, false)
	var np := maxi(1, roundi(len / 1.6))
	for i in np + 1: m.add("p", "wood", C.PA(Kit.cyl(0.05, 0.06, h + 0.15, 5, float(i) / np * len, (h + 0.15) / 2, 0), C.WOOD), 0.0 if lite else 0.012)
	var ns := roundi(len / (0.2 if lite else 0.11))
	if lite:
		# 톱니 윗변을 가진 앞·뒤 판(살 하나 = 앞뒤 삼각 4개)
		var g := Kit.Geo.new()
		for i in ns:
			var xa := float(i) * len / ns; var xb := float(i + 1) * len / ns; var xm := (xa + xb) / 2
			var hh := h * (0.85 + m.r() * 0.2)
			for zz in [0.015, -0.015]:
				var a := Vector3(xa, 0, zz); var b := Vector3(xb, 0, zz); var c := Vector3(xb, h * 0.8, zz); var d := Vector3(xa, h * 0.8, zz); var t := Vector3(xm, hh, zz)
				if zz > 0:
					g.quad(a, b, c, d, Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.8), Vector2(0, 0.8)); g.tri(d, c, t)
				else:
					g.quad(b, a, d, c, Vector2(1, 0), Vector2(0, 0), Vector2(0, 0.8), Vector2(1, 0.8)); g.tri(c, d, t)
		m.add("p", "flat", C.P(g, 0x9c8462, 0x6e5a44, 0.08, R), 0)
		ns = 0
	for i in ns:
		var x := (i + 0.5) * (len / ns); var hh := h * (0.85 + m.r() * 0.2)
		var g := Kit.xf(Kit.box(0.035, hh, 0.035), x, hh / 2, (m.r() - 0.5) * 0.05, (m.r() - 0.5) * 0.08, 0, (m.r() - 0.5) * 0.12)
		m.add("p", "flat", C.P(g, 0x9c8462, 0x6e5a44, 0.08, R), 0)
	for y in [0.35, 0.8]: m.add("p", "flat", C.P(Kit.box(len, 0.05, 0.08, len / 2, y * h, 0.03), 0x5e4a36), 0.0 if lite else 0.008)
	m.xform = old
	W.add_line_collider(m, ax, az, bx, bz, 0.12)
