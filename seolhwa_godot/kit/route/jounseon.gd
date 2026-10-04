# 세곡선(稅穀船) — 강 조창(흥원창·가흥창)에서 세곡을 싣고 한양 경창(마포·서강)으로 내려가던 평저 강배(참선·늘배 계열, 가설).
# 넓적한 평저 선체 + 돛대 둘(돗자리 돛, 앞돛은 접음) + 가운데 섬(곡식 가마니) 무더기를 덮은 거적 + 뒤 키 + 뜸집.
# 원점 = 물 면(y=0) 배 가운데, 이물 = +z. params: seed, len(15.0), sail(true)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = float(params.get("len", 15.0)); var Bw := L * 0.27
	var R := m.rng
	var hl := L / 2; var hb := Bw / 2
	var sides := 8
	var top := []; var bot := []
	for i in sides + 1:
		var t := float(i) / sides
		var z := -hl + t * L
		var w := hb * (1.0 - 0.45 * pow(maxf(t - 0.6, 0.0) / 0.4, 1.7)) * (1.0 - 0.12 * pow(maxf(0.2 - t, 0.0) / 0.2, 2.0))
		var lift := 0.55 * pow(maxf(t - 0.65, 0.0) / 0.35, 2.0) + 0.25 * pow(maxf(0.15 - t, 0.0) / 0.15, 2.0)
		top.append(Vector3(w, 0.7 + lift, z)); bot.append(Vector3(w * 0.82, -0.5 + lift * 0.6, z))
	var hull := Kit.Geo.new()
	for s in [-1, 1]:
		for i in sides:
			var a: Vector3 = top[i]; var b: Vector3 = top[i + 1]; var c: Vector3 = bot[i + 1]; var d: Vector3 = bot[i]
			a.x *= s; b.x *= s; c.x *= s; d.x *= s
			if s > 0: hull.quad(d, c, b, a)
			else: hull.quad(a, b, c, d)
	for i in sides:
		var a: Vector3 = bot[i]; var b: Vector3 = bot[i + 1]
		hull.quad(Vector3(-a.x, a.y, a.z), Vector3(a.x, a.y, a.z), Vector3(b.x, b.y, b.z), Vector3(-b.x, b.y, b.z))
	m.add("p", "wood", C.P(hull, 0x6e5238, 0x46341f, 0.05, R), 0.035)
	m.add("p", "wood", C.P(Kit.box(Bw * 0.88, 0.07, L * 0.82, 0, 0.42, -L * 0.03), 0xa08460, 0x82664a, 0.04, R), 0.015)
	var ft: Vector3 = top[sides]; var bt: Vector3 = top[0]
	m.add("p", "wood", C.P(Kit.box(ft.x * 2.0 + 0.1, 0.7, 0.14, 0, ft.y - 0.3, hl), 0x5e4630, 0x3e2e20, 0.04, R), 0.02)
	m.add("p", "wood", C.P(Kit.box(bt.x * 2.0 + 0.1, 0.65, 0.14, 0, bt.y - 0.3, -hl), 0x5e4630, 0x3e2e20, 0.04, R), 0.02)
	# 섬 무더기(가운데) + 덮은 거적
	var rows := 4; var cols := 3
	for k in 2:
		for i in rows:
			for j in cols - k:
				var x := (j - (cols - k - 1) * 0.5) * 0.62
				var z := -L * 0.12 + i * 0.78
				m.add("p", "thatch", C.P(Kit.xf(Kit.cyl(0.3, 0.3, 0.74, 7), x, 0.75 + k * 0.5, z, PI / 2, 0, 0), 0xcdb582, 0xa08a5e, 0.05, R), 0.008)
	m.add("p", "thatch", C.PA(Kit.xf(Kit.box(1.5, 0.06, rows * 0.78 + 0.3, 0, 1.55, -L * 0.12 + (rows - 1) * 0.39), 0, 0, 0, 0, 0, 0), C.STRAW, 0.05, R), 0.012)
	# 뜸집(뒤)
	var tt := Kit.Geo.new()
	var hw := hb * 0.7; var hh := 1.1; var zz0 := -hl * 0.86; var zz1 := -hl * 0.45
	for k in 6:
		var a0 := PI * k / 6.0; var a1 := PI * (k + 1) / 6.0
		var p0 := Vector3(cos(a0) * hw, 0.45 + sin(a0) * hh, 0); var p1 := Vector3(cos(a1) * hw, 0.45 + sin(a1) * hh, 0)
		tt.quad(p0 + Vector3(0, 0, zz0), p1 + Vector3(0, 0, zz0), p1 + Vector3(0, 0, zz1), p0 + Vector3(0, 0, zz1))
	m.add("p", "thatch", C.PA(tt, C.THATCH, 0.05, R), 0.03)
	# 돛대 둘(뒤 돛대에 돛, 앞 돛대는 돛을 말아 둠)
	var masts := [[L * 0.12, L * 0.78, true], [L * 0.36, L * 0.55, false]]
	for mm in masts:
		var mz: float = mm[0]; var MH: float = mm[1]
		m.add("p", "wood", C.P(Kit.cyl(0.08, 0.13, MH, 6, 0, 0.4 + MH / 2, mz), 0x7d6650, 0x5a4838, 0.04, R), 0.014)
		if mm[2] and bool(params.get("sail", true)):
			var sw := L * 0.36; var sh := MH * 0.7; var y0 := 0.4 + MH * 0.22
			var zA := mz - sw * 0.55; var zB := mz + sw * 0.45
			var sail := Kit.Geo.new()
			sail.quad(Vector3(0.16, y0, zA), Vector3(0.16, y0, zB), Vector3(0.24, y0 + sh, zB - 0.1), Vector3(0.24, y0 + sh, zA + 0.05))
			sail.quad(Vector3(0.15, y0, zB), Vector3(0.15, y0, zA), Vector3(0.23, y0 + sh, zA + 0.05), Vector3(0.23, y0 + sh, zB - 0.1))
			m.add("p", "cloth", C.P(sail, 0xd2bf92, 0xab9468, 0.04, R), 0.02)
			for k in 7:
				m.add("p", "wood", C.P(Kit.box(0.05, 0.05, sw * 1.02, 0.21, y0 + sh * (k + 0.5) / 7.0, mz - sw * 0.05), 0x6e5a40), 0)
		elif not mm[2]:
			m.add("p", "cloth", C.P(Kit.xf(Kit.cyl(0.14, 0.14, L * 0.22, 6), 0.12, 0.4 + MH * 0.35, mz, PI / 2, 0, 0), 0xc7b386, 0x9c8760, 0.04, R), 0.01)
	m.add("p", "wood", C.P(Kit.xf(Kit.box(0.09, 1.9, 0.6), 0, 0.0, -hl - 0.4, 0.35, 0, 0), 0x5a4838, 0x3e3226), 0.012)
	m.anchor("boatman", Vector3(0, 0.45, -hl + 0.8))
	return m.result("세곡선", Vector2(Bw + 0.6, L + 1.0), false)
