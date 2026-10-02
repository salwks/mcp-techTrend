# 장승(천하대장군·지하여장군) — 웹 buildings.js jangseung() 이식. 얼굴은 아틀라스 face0/face1.
# params: seed, female(false: 지하여장군)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	draw(m, bool(params.get("female", false)))
	m.circle(0, 0, 0.5)
	m.anchor("front", Vector3(0, 0, 0.9))
	return m.result("여장군" if params.get("female", false) else "대장군", Vector2(1.2, 1.2), false)

static func draw(m: C.M, female: bool) -> void:
	var R := m.rng
	m.add("p", "wood", C.P(Kit.cyl(0.2, 0.26, 2.7, 8, 0, 1.3, 0), 0x9a8466, 0x6d5c46, 0.05, R), 0.025)
	m.add("p", "face1" if female else "face0", C.vplane(0.4, 1.9, 0, 1.45, 0.24), 0)
	if not female:
		m.add("p", "flat", C.P(Kit.cyl(0.2, 0.24, 0.45, 8, 0, 2.85, 0), 0x2e2a26, 0x26221f), 0.02)
		m.add("p", "flat", C.P(Kit.cyl(0.42, 0.42, 0.05, 10, 0, 2.66, 0), 0x2e2a26), 0.015)
	else:
		m.add("p", "flat", C.P(Kit.cyl(0.18, 0.22, 0.3, 8, 0, 2.78, 0), 0x4d6a78, 0x3e5864), 0.02)
	for i in 6: m.add("p", "stone", C.PA(Kit.xf(Kit.lump(0.22, 0, R, 0.3, 0.6), cos(i) * 0.45, 0.08, sin(i) * 0.45), C.STONE), 0.015)
