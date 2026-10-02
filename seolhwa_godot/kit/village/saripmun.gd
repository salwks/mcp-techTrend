# 사립문 — 싸리·잡목 가지를 엮은 문짝 + 문기둥 둘. 초가 마을 싸리울에 다는 문.
# params: seed, w(1.4), open(true: 문짝을 안으로 젖혀 둠)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var w: float = params.get("w", 1.4)
	draw(m, w, bool(params.get("open", true)))
	return m.result("사립문", Vector2(w + 0.4, 1.2), false)

static func draw(m: C.M, w := 1.4, open := true) -> void:
	var R := m.rng
	for s in [-1, 1]: m.add("p", "wood", C.P(Kit.cyl(0.07, 0.08, 1.55, 6, s * w / 2, 0.77, 0), 0x6b5038, 0x4d3826), 0.012)
	m.add("p", "wood", C.P(Kit.xf(Kit.cyl(0.04, 0.05, w + 0.3, 5), 0, 1.5, 0, 0, 0, PI / 2 + 0.04), 0x7a5c3e), 0.01)
	# 문짝: 테두리 + 비스듬히 엮은 가지
	var old := m.xform
	var ang := 1.2 if open else 0.0
	m.xform = old * Transform3D(Basis(Vector3.UP, ang), Vector3(-w / 2 + 0.08, 0, 0))
	var pw := w - 0.16; var ph := 1.2
	for y in [0.15, ph]: m.add("p", "wood", C.P(Kit.box(pw, 0.05, 0.05, pw / 2, y, 0), 0x6e5a44), 0.006)
	for x in [0.02, pw - 0.02]: m.add("p", "wood", C.P(Kit.box(0.05, ph - 0.1, 0.05, x, (ph + 0.15) / 2, 0), 0x6e5a44), 0.006)
	var parts := []
	for i in 11:
		var x := 0.06 + i * (pw - 0.12) / 10.0
		parts.append(Kit.xf(Kit.box(0.035, ph - 0.05, 0.035), x + (m.r() - 0.5) * 0.05, (ph + 0.12) / 2, (m.r() - 0.5) * 0.03, 0, 0, (m.r() - 0.5) * 0.1))
	# 엇걸이 가새
	parts.append(C.beam(Vector3(0.05, 0.2, 0.03), Vector3(pw - 0.05, ph - 0.05, 0.03), 0.04, 0.04))
	var g := Kit.merge(parts)
	m.add("p", "flat", C.P(g, 0x9c8462, 0x6e5a44, 0.08, R), 0)
	m.xform = old
	for s in [-1, 1]: m.circle(s * w / 2, 0, 0.12)
	m.anchor("gate_out", Vector3(0, 0, 0.8)); m.anchor("gate_in", Vector3(0, 0, -0.8))
