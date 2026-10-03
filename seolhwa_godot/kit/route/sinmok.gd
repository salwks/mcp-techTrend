# 신목(神木) — 들 가운데·길 갈림에 홀로 선 큰 당산나무. 줄기에 왼새끼 금줄 + 흰 종이 술, 밑동에 작은 돌 제단과 길손이 얹은 돌.
# 명세 §29(성황당·당집: 큰 나무·길 갈림), §23(귀신·도깨비 — 밤에 나무 밑). 나무는 kit/nature/big_tree를 그대로 쓰고 금줄·제단만 덧붙인다.
# params: seed, variant("zelkova"), altar(true), cloth(true: 오색 천 몇 가닥)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const BT := preload("res://kit/nature/big_tree.gd")

static func build(params: Dictionary) -> Dictionary:
	var variant := String(params.get("variant", "zelkova"))
	var seed := int(params.get("seed", 1))
	var info: Dictionary = BT.build({ seed = seed, variant = variant })
	var tr: float = float(BT.PRESET.get(variant, BT.PRESET.zelkova).trunk)
	var m := C.M.new(seed + 7)
	var R := m.rng
	# 금줄(밑동이 퍼지므로 1.3m 높이의 줄기 둘레) + 흰 종이 술
	var rr := tr * 0.86 + 0.06
	m.add("p", "flat", C.P(Kit.xf(C.torus(rr, 0.05, 4, 14), 0.0, 1.3, 0.0, PI / 2, 0, 0), 0xcdb57a, 0xa58d5c), 0.01)
	for i in 8:
		var a := i * TAU / 8
		m.add("p", "cloth", C.P(C.vplane(0.08, 0.24, cos(a) * (rr + 0.03), 1.16, sin(a) * (rr + 0.03), -a + PI / 2), 0xf2ecdc), 0)
	if bool(params.get("cloth", true)):
		var cols := [0xa8483a, 0x3f5f7a, 0xc9a34a, 0xe8e2d2, 0x5f7a4a]
		for i in 5:
			var g := C.vplane(0.11, 0.6 + m.r() * 0.3, 0, 0, 0)
			Kit.xf(g, -rr - 0.05 + i * 0.02, 1.0, 0.25 - i * 0.1, 0, PI / 2, (m.r() - 0.5) * 0.15)
			m.add("p", "cloth", C.P(g, cols[i], cols[i], 0.02), 0)
	if bool(params.get("altar", true)):
		m.add("p", "stone", C.P(Kit.box(0.9, 0.26, 0.5, 0, 0.13, tr + 0.9), 0xa8a295, 0x8a857b, 0.05, R), 0.015)
		m.add("p", "onggi", C.P(Kit.cyl(0.1, 0.07, 0.08, 10, -0.22, 0.3, tr + 0.9), 0xe8e2d2, 0xc8c0ac), 0.006)
		m.box_c(-0.45, 0.45, tr + 0.65, tr + 1.15)
		m.light(0.2, 0.5, tr + 0.9, "shrine")
	for i in 7:
		var a := PI * 0.2 + m.r() * PI * 0.6
		m.add("p", "stone", C.P(Kit.xf(Kit.lump(0.13 + m.r() * 0.08, 0, R, 0.3, 0.7), cos(a) * (tr + 0.5), 0.07, sin(a) * (tr + 0.5)), 0xb1ab9d, 0x7c776c, 0.08, R), 0)
	var extra := m.build_node("금줄")
	var node: Node3D = info.node
	node.add_child(extra)
	node.name = "신목"
	var cols2: Array = info.colliders.duplicate()
	cols2.append_array(m.colliders)
	return { node = node, colliders = cols2, lights = m.lights, occluder = true, footprint = info.footprint, anchors = { altar = Vector3(0, 0, tr + 1.6) } }
