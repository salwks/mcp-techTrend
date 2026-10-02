# 디딜방앗간 — 뒷벽만 있는 트인 초가 헛간 + 디딜방아(Y자 방아채, 볼씨 기둥, 공이, 돌확).
# 고증: 디딜방아는 두 사람이 Y자 갈래 끝을 밟아 공이를 들었다 놓는 방아. 마을 공동 방앗간 헛간에 두었다.
# params: seed, w(4.0), d(3.0)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 4.0); var D: float = params.get("d", 3.0)
	var R := m.rng
	var sh := C.shed(m, W, D, 1.9, "back", 2, 0.9)
	var y0: float = sh.y0
	# 방아채: 머리(-x) → 갈래(+x 쪽 둘)
	var head := Vector3(-1.25, y0 + 0.55, 0.15); var fork := Vector3(0.45, y0 + 0.42, 0.15)
	m.add("p", "wood", C.P(C.beam(head, fork, 0.16, 0.16), 0x8a6a48, 0x6b5038), 0.015)
	for s in [-1, 1]:
		m.add("p", "wood", C.P(C.beam(fork, Vector3(1.55, y0 + 0.28, 0.15 + s * 0.32), 0.12, 0.12), 0x8a6a48, 0x6b5038), 0.012)
	# 볼씨(받침 기둥) + 굴대
	for s in [-1, 1]: m.add("p", "wood", C.PA(Kit.box(0.12, 0.6, 0.12, 0.25, y0 + 0.3, 0.15 + s * 0.2), C.WOOD), 0.01)
	m.add("p", "wood", C.P(Kit.cyl(0.04, 0.04, 0.5, 5, 0.25, y0 + 0.5, 0.15, PI / 2, 0, 0), 0x4d3826), 0)
	# 공이 + 돌확
	m.add("p", "wood", C.P(Kit.cyl(0.08, 0.1, 0.65, 6, head.x, head.y - 0.2, head.z), 0x7a5c3e, 0x5e442e), 0.01)
	m.add("p", "stone", C.P(Kit.cyl(0.32, 0.38, 0.3, 8, head.x, y0 + 0.05, head.z), 0xa8a295, 0x7b766c, 0.06, R), 0.015)
	m.add("p", "smooth", C.P(Kit.cyl(0.2, 0.2, 0.02, 8, head.x, y0 + 0.2, head.z), 0x5a4a38), 0)
	# 곡식 자루, 키(체)
	m.add("p", "cloth", C.P(Kit.xf(Kit.lump(0.32, 0, R, 0.15, 1.3), -W / 2 + 0.5, y0 + 0.4, -D / 2 + 0.5), 0xd8ccb0, 0xb8aa8c), 0.012)
	m.add("p", "thatch", C.P(Kit.xf(Kit.cyl(0.35, 0.3, 0.06, 8), W / 2 - 0.5, y0 + 0.6, -D / 2 + 0.2, 1.3, 0, 0), 0xc8ad6e, 0x9a8050), 0.008)
	for q in [[-1, -1], [1, -1], [-1, 1], [0, 1], [1, 1], [0, -1]]: m.circle(q[0] * W / 2, q[1] * D / 2, 0.15)
	m.box_c(-W / 2 - 0.2, W / 2 + 0.2, -D / 2 - 0.2, -D / 2 + 0.1)
	m.circle(head.x, head.z, 0.4)
	m.anchor("treader", Vector3(1.6, y0, 0.15))
	m.anchor("feeder", Vector3(head.x - 0.1, y0, head.z + 0.6))
	return m.result("디딜방앗간", Vector2(W + 1.0, D + 1.2))
