# 솟대 — 긴 장대 끝에 나무 새(오리)를 올린 마을 수호 표지. 마을 어귀·당산 곁에 여럿 세운다.
# params: seed, n(3), h(4.2)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var n: int = params.get("n", 3); var H: float = params.get("h", 4.2)
	for i in n:
		var x := (i - (n - 1) / 2.0) * 0.7 + (m.r() - 0.5) * 0.15
		var z := (m.r() - 0.5) * 0.4
		var h := H * (0.8 + m.r() * 0.3)
		pole(m, x, z, h, m.r() * TAU * 0.25 - 0.4)
	return m.result("솟대", Vector2(n * 0.7 + 0.6, 1.0), false)

static func pole(m: C.M, x: float, z: float, h: float, yaw: float) -> void:
	var R := m.rng
	m.add("p", "wood", C.P(Kit.xf(Kit.cyl(0.04, 0.07, h, 5), x, h / 2, z, (m.r() - 0.5) * 0.04, 0, (m.r() - 0.5) * 0.04), 0x9a8466, 0x6d5c46, 0.04, R), 0.01)
	var old := m.push(x, h, z, yaw)
	# 오리: 몸통 + 목 + 머리 + 부리
	m.add("p", "wood", C.P(Kit.xf(Kit.lump(0.16, 0, R, 0.1, 1.0), 0, 0.08, 0, 0, 0, 0, 0.8, 0.55, 1.7), 0xb09a78, 0x8a7458), 0.012)
	m.add("p", "wood", C.P(C.beam(Vector3(0, 0.1, 0.2), Vector3(0, 0.3, 0.3), 0.06, 0.06), 0xb09a78), 0.008)
	m.add("p", "wood", C.P(Kit.xf(Kit.lump(0.07, 0, R, 0.1, 1.0), 0, 0.33, 0.32, 0, 0, 0, 1, 1, 1.3), 0xb09a78), 0.008)
	m.add("p", "flat", C.P(Kit.xf(Kit.cone(0.03, 0.12, 4), 0, 0.33, 0.42, PI / 2, 0, 0), 0x6d5c46), 0)
	m.pop(old)
	m.circle(x, z, 0.12)
