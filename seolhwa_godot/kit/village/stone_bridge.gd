# 돌다리(홍예교, 무지개다리) — 웹 buildings.js stoneBridge() 이식. 로컬 z축이 다리 방향(남북으로 건넘),
# 물은 x축으로 흐른다. 원점 = 다리 가운데, y=0은 양쪽 둑 높이. 홍예 밑은 y=-1.7까지 내려간다(강바닥).
# params: seed, len(9.6), hw(1.3, 반폭), arch(0.55, 가운데 솟음)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = params.get("len", 9.6); var hw: float = params.get("hw", 1.3); var ar: float = params.get("arch", 0.55)
	draw(m, -L / 2, L / 2, hw, ar)
	for s in [-1, 1]: m.box_c(s * hw - 0.15, s * hw + 0.15, -L / 2 + 0.15, L / 2 - 0.15)
	m.anchor("north", Vector3(0, 0.1, -L / 2 - 0.5)); m.anchor("south", Vector3(0, 0.1, L / 2 + 0.5)); m.anchor("top", Vector3(0, 0.65, 0))
	var res := m.result("돌다리", Vector2(hw * 2 + 0.4, L + 0.4), false)
	res.walk = walk(L, hw, ar)
	return res

# 계약서 §8 걷기 면: 상판 윗면 = deck(z), 양 끝은 둑(y≈0.1)으로 0.3m 이어 붙임
static func walk(L: float, hw: float, ar: float) -> Array:
	var zs := []; var ys := []
	zs.append(-L / 2 - 0.3); ys.append(0.1)
	for i in 17:
		var z := -L / 2 + L * i / 16.0
		zs.append(z); ys.append(deck(z, -L / 2, L / 2, ar))
	zs.append(L / 2 + 0.3); ys.append(0.1)
	return [{ minX = -hw + 0.2, maxX = hw - 0.2, minZ = -L / 2 - 0.3, maxZ = L / 2 + 0.3, z = zs, y = ys }]

static func deck(z: float, z0: float, z1: float, ar: float) -> float:
	var t := (z - (z0 + z1) / 2) / ((z1 - z0) / 2)
	return 0.1 + ar * (1 - t * t)

static func draw(m: C.M, z0: float, z1: float, hw: float, ar: float) -> void:
	var R := m.rng
	var n := 14
	for i in n:
		var za := z0 + (z1 - z0) * i / n; var zb := z0 + (z1 - z0) * (i + 1) / n
		var ya := deck(za, z0, z1, ar); var yb := deck(zb, z0, z1, ar); var zc := (za + zb) / 2
		var ang := atan2(yb - ya, zb - za)
		m.add("p", "stone", C.P(Kit.xf(Kit.box(hw * 2, 0.28, (zb - za) + 0.03), (m.r() - 0.5) * 0.02, (ya + yb) / 2 - 0.14, zc, -ang, 0, 0), 0xb9b3a6, 0x99938a, 0.08, R), 0.02)
		for s in [-1, 1]:
			m.add("p", "stone", C.P(Kit.xf(Kit.box(0.26, 0.32, (zb - za) + 0.02), s * (hw - 0.05), (ya + yb) / 2 + 0.12, zc, -ang, 0, 0), 0xa8a295, 0x8a857b, 0.06, R), 0.02)
	# 아치 몸체: (z, y) 단면을 x로 밀어냄
	var zc := (z0 + z1) / 2; var rr := 2.1
	var pts := PackedVector2Array()
	pts.append(Vector2(z0 - 0.2, -1.7))
	for i in 17:
		var z := z0 + (z1 - z0) * i / 16.0
		pts.append(Vector2(z, deck(z, z0, z1, ar) - 0.27))
	pts.append(Vector2(z1 + 0.2, -1.7))
	pts.append(Vector2(zc + rr, -1.7))
	for i in range(1, 12):
		var a := float(i) / 12 * PI
		pts.append(Vector2(zc + cos(a) * rr, -1.7 + sin(a) * rr * 0.95))
	pts.append(Vector2(zc - rr, -1.7))
	# 단면 x(=z) → 밀어낸 뒤 축 바꾸기: (u, v, w) → (w - (hw-0.1), v, u)
	var eg := C.extrude_xy(pts, hw * 2 - 0.2)
	Kit.apply(eg, Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3(-(hw - 0.1), 0, 0)))
	m.add("p", "stone", C.P(eg, 0xa9a397, 0x6f6b62, 0.06, R), 0.03)
	for i in 11:
		var a := float(i) / 10 * PI
		for s in [-1, 1]:
			m.add("p", "stone", C.P(Kit.box(0.08, 0.34, 0.5, s * (hw - 0.06), -1.7 + sin(a) * (rr * 0.95 + 0.18), zc + cos(a) * (rr + 0.18)), 0xc4beb0, 0xa39d90), 0)
