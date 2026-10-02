# 뒷간 — 작은 흙벽 초가(둥근 이엉) + 거적문 + 옆 잿더미. 집 뒤·옆 구석에 둔다.
# params: seed, s(1.5, 한 변)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var s: float = params.get("s", 1.5)
	draw(m, s)
	return m.result("뒷간", Vector2(s + 1.2, s + 1.0))

static func draw(m: C.M, s: float) -> void:
	var R := m.rng
	var h := 1.75; var hs := s / 2
	m.add("p", "stone", C.PA(Kit.box(s + 0.2, 0.2, s + 0.2, 0, 0.1, 0), C.STONE, 0.05, R), 0.015)
	m.add("p", "mud", C.PA(Kit.box(s, h, 0.12, 0, 0.2 + h / 2, -hs), C.MUD, 0.04, R), 0.02)
	for sx in [-1, 1]: m.add("p", "mud", C.PA(Kit.box(0.12, h, s, sx * hs, 0.2 + h / 2, 0), C.MUD, 0.04, R), 0.02)
	C.holed_wall(m, "p", -hs, hs, 0.2, 0.2 + h, -0.35, 0.35, 0.2, 1.65, hs, 0.12, C.MUD)
	C.dark_door(m, 0, 0.2, 0.7, 1.45, hs)
	# 거적문(반쯤 걷어 올림)
	m.add("p", "thatch", C.P(C.vplane(0.78, 0.95, 0, 1.2, hs + 0.08), 0xb8a070, 0x957f55, 0.04, R), 0.008)
	m.add("p", "thatch", C.P(Kit.cyl(0.07, 0.07, 0.8, 6, 0, 1.7, hs + 0.09, 0, 0, PI / 2), 0xa58d5c), 0.008)
	C.thatch_cap(m, "p", hs + 0.45, hs + 0.45, 0.2 + h + 0.1, 0.55, 10, 3)
	# 잿더미
	m.add("p", "organic", C.P(Kit.xf(Kit.lump(0.42, 0, R, 0.2, 0.45), hs + 0.55, 0.1, 0.1), 0x8a857b, 0x6e6a62), 0.012)
	m.box_c(-hs - 0.1, hs + 0.1, -hs - 0.1, hs + 0.05)
	m.circle(hs + 0.55, 0.1, 0.35)
	m.anchor("door", Vector3(0, 0, hs + 0.6))
