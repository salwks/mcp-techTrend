# 외양간 — 세 벽 흙벽 + 앞 가로대(살대) + 맞배 이엉 지붕 + 구유 + 깔짚 + 여물 짚단. 소는 캐릭터·동물 담당이 놓는다(anchor cow).
# params: seed, w(3.6), d(3.0)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 3.6); var D: float = params.get("d", 3.0)
	draw(m, W, D)
	return m.result("외양간", Vector2(W + 1.4, D + 1.2))

static func draw(m: C.M, W: float, D: float) -> void:
	var R := m.rng
	var sh := C.shed(m, W, D, 1.9, "three", 2, 0.9)
	var y0: float = sh.y0; var zf := D / 2
	# 깔짚
	m.add("p", "thatch", C.PA(Kit.box(W - 0.3, 0.06, D - 0.3, 0, y0 + 0.03, 0), C.STRAW, 0.05, R), 0)
	# 구유: 통나무 구유(뒤벽 앞)
	m.add("p", "wood", C.P(Kit.box(W * 0.6, 0.4, 0.5, 0, y0 + 0.35, -zf + 0.45), 0x6b5038, 0x4d3826, 0.04, R), 0.015)
	m.add("p", "flat", C.P(Kit.box(W * 0.6 - 0.12, 0.02, 0.32, 0, y0 + 0.56, -zf + 0.45), 0x3a2e22), 0)
	m.add("p", "thatch", C.PA(Kit.xf(Kit.lump(0.25, 0, R, 0.2, 0.5), 0.2, y0 + 0.56, -zf + 0.45, 0, 0, 0, 1.6, 1, 0.7), C.STRAW, 0.05, R), 0)
	for s in [-1, 1]: m.add("p", "wood", C.PA(Kit.box(0.12, 0.15, 0.4, s * W * 0.27, y0 + 0.08, -zf + 0.45), C.WOOD), 0)
	# 앞 가로대(살대) 두 줄 — 가운데 하나는 빼 둔 입구
	for y in [0.55, 1.05]:
		m.add("p", "wood", C.P(Kit.cyl(0.04, 0.04, W / 2 - 0.1, 5, -W / 4, y0 + y, zf + 0.1, 0, 0, PI / 2), 0x8a6a48), 0.01)
	m.add("p", "wood", C.P(Kit.xf(Kit.cyl(0.04, 0.04, W / 2 - 0.1, 5), W / 4 + 0.1, y0 + 0.3, zf + 0.3, 0, 0.35, 1.25), 0x8a6a48), 0.01)
	# 옆 여물 짚단
	for i in 3: m.add("p", "thatch", C.PA(Kit.cyl(0.1, 0.15, 0.85, 6, W / 2 + 0.35, 0.42, -0.6 + i * 0.32), C.STRAW, 0.05, R), 0.01)
	m.box_c(-W / 2 - 0.2, W / 2 + 0.2, -zf - 0.2, -zf + 0.1)
	m.box_c(-W / 2 - 0.2, -W / 2 + 0.1, -zf, zf)
	m.box_c(W / 2 - 0.1, W / 2 + 0.2, -zf, zf)
	m.box_c(-W / 2, 0, zf - 0.05, zf + 0.2)
	m.circle(W / 2 + 0.35, -0.3, 0.45)
	m.anchor("cow", Vector3(0, y0, 0.1))
	m.anchor("gate", Vector3(W / 4, 0, zf + 0.6))
