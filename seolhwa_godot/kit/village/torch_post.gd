# 횃대(마을 어귀 화톳불 기둥) — 웹 buildings.js torchPost() 이식. 불꽃은 glow(밤에 빛남).
# params: seed
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var R := m.rng
	m.add("p", "wood", C.PA(Kit.cyl(0.06, 0.08, 1.8, 6, 0, 0.9, 0), C.WOOD), 0.012)
	m.add("p", "flat", C.P(Kit.xf(Kit.cone(0.2, 0.3, 6), 0, 1.9, 0, PI, 0, 0), 0x3d2e22), 0.012)
	m.add("p", "glow", C.P(Kit.cone(0.12, 0.34, 6, 0, 2.15, 0), 0xffcf6a, 0xff7a2a), 0)
	for i in 4: m.add("p", "stone", C.PA(Kit.xf(Kit.lump(0.16, 0, R, 0.3, 0.6), cos(i * 1.6) * 0.25, 0.05, sin(i * 1.6) * 0.25), C.STONE), 0.01)
	m.circle(0, 0, 0.3)
	m.light(0, 2.2, 0, "torch")
	return m.result("횃대", Vector2(0.7, 0.7), false)
