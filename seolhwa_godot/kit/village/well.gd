# 우물(돌 우물 + 도르래 틀 + 두레박) — 웹 buildings.js well() 이식.
# params: seed, roof(false: true면 작은 이엉 우물 지붕 — 가설: 산간 마을 공동우물에 흔한 덮개)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	draw(m, params)
	return m.result("우물", Vector2(2.4, 2.0), false)

static func draw(m: C.M, o: Dictionary) -> void:
	var R := m.rng
	m.add("p", "stone", C.P(Kit.cyl(0.82, 0.9, 0.8, 8, 0, 0.35, 0), 0xa8a295, 0x7b766c, 0.08, R), 0.025)
	m.add("p", "stone", C.P(Kit.cyl(0.9, 0.9, 0.1, 8, 0, 0.8, 0), 0xbdb7aa, 0xa8a295), 0.02)
	m.add("p", "smooth", C.P(Kit.cyl(0.64, 0.64, 0.02, 12, 0, 0.62, 0), 0x2e3a3c), 0)
	for s in [-1, 1]: m.add("p", "wood", C.PA(Kit.box(0.12, 1.9, 0.12, s * 0.95, 0.95, 0), C.WOOD), 0.015)
	m.add("p", "wood", C.PA(Kit.box(2.2, 0.12, 0.14, 0, 1.9, 0), C.WOOD), 0.015)
	m.add("p", "flat", C.P(Kit.cyl(0.02, 0.02, 0.8, 4, 0.2, 1.45, 0), 0xb8a57c), 0)
	m.add("p", "wood", C.P(Kit.cyl(0.16, 0.13, 0.22, 8, 0.2, 1.0, 0), 0x7a5c3e, 0x5e442e), 0.012)
	m.add("p", "wood", C.P(Kit.cyl(0.15, 0.12, 0.2, 8, -0.55, 0.95, 0.5), 0x7a5c3e, 0x5e442e), 0.012)
	if o.get("roof", false):
		C.thatch_gable(m, "p", 2.6, 1.6, 2.0, 0.55)
	m.circle(0, 0, 1.1)
	m.anchor("draw", Vector3(0, 0, 1.25))
