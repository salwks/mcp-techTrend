# 돌무더기(서낭당 누석단) + 작은 제단 + 촛불 — 웹 buildings.js cairn() 이식.
# params: seed, altar(true: 앞 제단·촛불·정화수 그릇)
# 성능: 웹(돌 28개, 모두 먹선)은 ~1,100 삼각형 → 돌 20개, 맨 아랫단만 먹선(~700).
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	draw(m, bool(params.get("altar", true)))
	return m.result("돌무더기", Vector2(2.8, 3.4), false)

static func draw(m: C.M, altar := true) -> void:
	var R := m.rng
	# 속을 채우는 큰 덩이(위에서 보면 고리처럼 비지 않게)
	m.add("p", "stone", C.P(Kit.xf(Kit.lump(0.95, 0, R, 0.25, 0.8), 0, 0.45, 0), 0x9d978a, 0x77726a, 0.08, R), 0)
	for l in 5:
		var Rr := 1.25 * (1 - l / 5.2); var n := maxi(1, roundi(7 - l * 1.6))
		for i in n:
			var a := float(i) / n * TAU + l * 0.7 + m.r() * 0.3
			var g := Kit.lump(0.3 - l * 0.02 + m.r() * 0.06, 0, R, 0.35, 0.7)
			Kit.xf(g, cos(a) * Rr, 0.15 + l * 0.32, sin(a) * Rr, 0, m.r() * 3, 0)
			m.add("p", "stone", C.P(g, 0xb1ab9d, 0x7c776c, 0.1, R), 0.025 if l < 1 else 0.0)
	m.add("p", "stone", C.P(Kit.xf(Kit.lump(0.28, 0, R, 0.3, 1.2), 0, 1.75, 0), 0xbdb7aa, 0x8e897f), 0.025)
	m.circle(0, 0, 1.4)
	if altar:
		m.add("p", "stone", C.P(Kit.box(0.9, 0.28, 0.5, 0, 0.14, 1.45), 0xa8a295, 0x8a857b, 0.05, R), 0.015)
		m.add("p", "flat", C.P(Kit.cyl(0.04, 0.045, 0.16, 6, 0.15, 0.36, 1.45), 0xefe6d0), 0.006)
		m.add("p", "glow", C.P(Kit.cone(0.03, 0.09, 6, 0.15, 0.49, 1.45), 0xffd27a, 0xff9a3a), 0)
		m.add("p", "onggi", C.P(Kit.cyl(0.1, 0.07, 0.08, 10, -0.2, 0.32, 1.45), 0xe8e2d2, 0xc8c0ac), 0.006)
		m.box_c(-0.5, 0.5, 1.15, 1.75)
		m.light(0.15, 0.55, 1.45, "shrine")
		m.anchor("altar", Vector3(0, 0, 2.2))
