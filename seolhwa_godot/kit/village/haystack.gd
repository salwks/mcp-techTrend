# 짚가리(볏짚 낟가리 + 주저리 + 새끼 띠) — 웹 buildings.js haystack() 이식.
# params: seed, s(크기 배율 1)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var s: float = params.get("s", 1.0)
	draw(m, s)
	m.circle(0, 0, 1.2 * s)
	return m.result("짚가리", Vector2(2.4 * s, 2.4 * s), false)

static func draw(m: C.M, s: float) -> void:
	var pts := []
	for q in [[0, 0], [1.05, 0], [1.15, 0.5], [1.0, 1.1], [0.62, 1.7], [0.2, 2.05], [0, 2.1]]: pts.append(Vector2(q[0] * s, q[1] * s))
	m.add("p", "thatch", C.PA(C.lathe(pts, 10), C.STRAW, 0.05, m.rng), 0.035)
	m.add("p", "thatch", C.P(Kit.cone(0.28 * s, 0.5 * s, 8, 0, 2.2 * s, 0), 0xb8a06a, 0x9d8656), 0.02)
	m.add("p", "flat", C.P(Kit.xf(C.torus(0.9 * s, 0.035, 4, 16), 0, 1.25 * s, 0, PI / 2, 0, 0), 0x6d5a3c), 0)
