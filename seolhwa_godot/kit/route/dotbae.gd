# 돛배(제주 뱃길 배) — 조선 후기 남해·제주를 오간 평저 돛배(덕판배 계열, 가설): 넓적한 뱃전 + 앞 덕판 + 돛대 하나에 대나무 살 댄 돗자리 돛
# + 뒤 키 + 가운데 낮은 뜸집(짚 덮개) + 노 한 자루. 원점 = 갑판 가운데(물 면 위 0), 이물(앞) = +z. 걷는 면은 엔진(뱃길)이 깐다.
# params: seed, len(9.0), sail(true: 돛 펼침)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = float(params.get("len", 9.0)); var Bw := L * 0.3
	var R := m.rng
	var hl := L / 2; var hb := Bw / 2
	# 선체: 바닥판 + 양 뱃전(앞으로 좁아지고 들림) + 앞 덕판 + 뒤 판
	var sides := 8
	var top := []; var bot := []
	for i in sides + 1:
		var t := float(i) / sides
		var z := -hl + t * L
		var w := hb * (1.0 - 0.55 * pow(maxf(t - 0.55, 0.0) / 0.45, 1.6)) * (1.0 - 0.15 * pow(maxf(0.25 - t, 0.0) / 0.25, 2.0))
		var lift := 0.45 * pow(maxf(t - 0.6, 0.0) / 0.4, 2.0) + 0.2 * pow(maxf(0.2 - t, 0.0) / 0.2, 2.0)
		top.append(Vector3(w, 0.55 + lift, z)); bot.append(Vector3(w * 0.78, -0.45 + lift * 0.6, z))
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
	m.add("p", "wood", C.P(hull, 0x7a5c40, 0x4e3a28, 0.05, R), 0.035)
	# 갑판(물 면 위 0.32 — 엔진 걷기 면 높이와 맞춤)
	m.add("p", "wood", C.P(Kit.box(Bw * 0.85, 0.06, L * 0.8, 0, 0.3, -L * 0.04), 0xa88a62, 0x8a6e4c, 0.04, R), 0.015)
	var ft: Vector3 = top[sides]; var bt: Vector3 = top[0]
	m.add("p", "wood", C.P(Kit.box(ft.x * 2.0 + 0.1, 0.6, 0.12, 0, ft.y - 0.25, hl), 0x6e5238, 0x4e3a28, 0.04, R), 0.02)
	m.add("p", "wood", C.P(Kit.box(bt.x * 2.0 + 0.1, 0.55, 0.12, 0, bt.y - 0.25, -hl), 0x6e5238, 0x4e3a28, 0.04, R), 0.02)
	# 뱃전 위 테(가로대 셋)
	for k in 3:
		var z := -hl * 0.6 + k * hl * 0.55
		m.add("p", "wood", C.P(Kit.box(Bw * 0.9, 0.1, 0.12, 0, 0.58, z), 0x6e5238), 0.012)
	# 뜸집(가운데 뒤 — 짚 덮개 반원)
	var tt := Kit.Geo.new()
	var hw := hb * 0.75; var hh := 1.05; var zz0 := -hl * 0.75; var zz1 := -hl * 0.18
	for k in 6:
		var a0 := PI * k / 6.0; var a1 := PI * (k + 1) / 6.0
		var p0 := Vector3(cos(a0) * hw, 0.33 + sin(a0) * hh, 0); var p1 := Vector3(cos(a1) * hw, 0.33 + sin(a1) * hh, 0)
		tt.quad(p0 + Vector3(0, 0, zz0), p1 + Vector3(0, 0, zz0), p1 + Vector3(0, 0, zz1), p0 + Vector3(0, 0, zz1))
	m.add("p", "thatch", C.PA(tt, C.THATCH, 0.05, R), 0.03)
	# 돛대 + 활대 + 돛(대나무 살 돗자리 돛, 살마다 가로줄)
	var mast_z := hl * 0.18; var MH := L * 0.82
	m.add("p", "wood", C.P(Kit.cyl(0.07, 0.11, MH, 6, 0, 0.3 + MH / 2, mast_z), 0x7d6650, 0x5a4838, 0.04, R), 0.014)
	if bool(params.get("sail", true)):
		var sw := L * 0.42; var sh := MH * 0.72; var y0 := 0.3 + MH * 0.2
		var sail := Kit.Geo.new()
		# 돛은 배 길이 방향(z)으로 펼쳐 옆(카메라 남쪽)에서 넓게 보이게
		var zA := mast_z - sw * 0.55; var zB := mast_z + sw * 0.45
		sail.quad(Vector3(0.15, y0, zA), Vector3(0.15, y0, zB), Vector3(0.22, y0 + sh, zB - 0.1), Vector3(0.22, y0 + sh, zA + 0.05))
		sail.quad(Vector3(0.14, y0, zB), Vector3(0.14, y0, zA), Vector3(0.21, y0 + sh, zA + 0.05), Vector3(0.21, y0 + sh, zB - 0.1))
		m.add("p", "cloth", C.P(sail, 0xd9c79c, 0xb59e70, 0.04, R), 0.02)
		for k in 6:
			var y := y0 + sh * (k + 0.5) / 6.0
			m.add("p", "wood", C.P(Kit.box(0.05, 0.05, sw * 1.02, 0.2, y, mast_z - sw * 0.05), 0x6e5a40), 0)
		m.add("p", "wood", C.P(Kit.box(0.08, 0.08, sw * 1.1, 0.2, y0 + sh + 0.05, mast_z - sw * 0.05), 0x5a4838), 0.008)
	# 키(뒤) + 노
	m.add("p", "wood", C.P(Kit.xf(Kit.box(0.08, 1.6, 0.5), 0, 0.0, -hl - 0.35, 0.35, 0, 0), 0x5a4838, 0x3e3226), 0.012)
	m.add("p", "wood", C.P(C.beam(Vector3(hb * 0.7, 0.7, -hl * 0.3), Vector3(hb + 1.6, -0.2, -hl * 0.5), 0.07, 0.07), 0x8a6e50), 0.008)
	# 짐(섬 몇 개 — 미역·전복 대신 쌀·무명을 실어 가는 길)
	for k in 3:
		m.add("p", "thatch", C.P(Kit.xf(Kit.cyl(0.24, 0.24, 0.65, 7), -hb * 0.35 + k * 0.32, 0.55, hl * 0.45, 0, 0, PI / 2), 0xcdb582, 0xa08a5e, 0.05, R), 0.008)
	return m.result("돛배", Vector2(Bw + 0.6, L + 0.8), false)
