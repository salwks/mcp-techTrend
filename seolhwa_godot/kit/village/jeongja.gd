# 정자(모정·누정) — 웹 buildings.js jeongja() 이식. 사방 트인 마루 + 계자난간 + 사모 기와지붕 + 청사초롱.
# params: seed, s(3.4, 한 변), plain(false: true면 단청 없는 마을 모정 — 밤색 기둥, 초롱 없음)
# 성능: 웹 지붕 격자 28×28 → 16×16.
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var s: float = params.get("s", 3.4)
	draw(m, params)
	return m.result("정자", Vector2(s + 2.6, s + 2.6))

static func draw(m: C.M, o: Dictionary) -> Dictionary:
	var s: float = o.get("s", 3.4); var h := s / 2; var F := 0.95; var R := m.rng
	var plain: bool = o.get("plain", false)
	for q in [[-h, -h], [h, -h], [-h, h], [h, h], [0, h], [0, -h], [-h, 0], [h, 0]]:
		m.add("base", "stone", C.PA(Kit.cyl(0.2, 0.26, 0.35, 6, q[0], 0.12, q[1]), C.STONE, 0.05, R), 0.015)
	m.add("base", "wood", C.PA(Kit.box(s + 0.3, 0.16, s + 0.3, 0, F - 0.08, 0), C.WOOD_L, 0.04, R), 0.02)
	var pil: Array = C.WOOD if plain else C.DANCHEONG_R
	for q in [[-h, -h], [h, -h], [-h, h], [h, h]]:
		m.add("body", "flat", C.PA(Kit.cyl(0.12, 0.13, 3.3, 8, q[0], 1.65, q[1], 0, 0, 0, false), pil), 0.02)
	for q in [[0, -h, s, 0.06], [-h, 0, 0.06, s], [h, 0, 0.06, s], [-h / 2 - 0.45, h, h - 0.5, 0.06], [h / 2 + 0.45, h, h - 0.5, 0.06]]:
		m.add("body", "wood", C.PA(Kit.box(q[2], 0.07, q[3], q[0], F + 0.55, q[1]), C.WOOD), 0.01)
		m.add("body", "wood", C.PA(Kit.box(q[2], 0.05, q[3], q[0], F + 0.2, q[1]), C.WOOD), 0.01)
	m.add("base", "stone", C.P(Kit.box(0.9, 0.3, 0.5, 0, 0.15, h + 0.5), 0xb8b2a5, 0x8e897f), 0.02)
	var beam: Array = C.WOOD if plain else [0x557d70, 0x3f6558]
	m.add("body", "flat", C.PA(Kit.box(s + 0.3, 0.22, 0.26, 0, 3.3, h), beam), 0.015)
	m.add("body", "flat", C.PA(Kit.box(s + 0.3, 0.22, 0.26, 0, 3.3, -h), beam), 0.015)
	var r := C.curved_roof(h + 1.25, h + 1.25, 3.55, 1.7, 0.5, 1, 0.22, 16, 16)
	m.add("roof", "tile", r.roof, 0.045)
	m.add("roof", "makse", r.edge, 0)
	m.add("roof", "flat", C.P(Kit.cyl(0.12, 0.2, 0.5, 8, 0, r.ridge_y + 0.2, 0), 0x3d3f42, 0x2d2e30), 0.02)
	var lz := h + 0.25
	if not plain:
		m.add("body", "flat", C.P(Kit.cyl(0.01, 0.01, 0.5, 4, 0, 3.05, lz), 0x2d2520), 0)
		m.add("body", "lamp", C.P(Kit.cyl(0.17, 0.17, 0.25, 8, 0, 2.66, lz), 0xc0443a), 0.012)
		m.add("body", "lamp", C.P(Kit.cyl(0.17, 0.17, 0.14, 8, 0, 2.47, lz), 0x3c5f86), 0.012)
		m.add("body", "flat", C.P(Kit.cyl(0.12, 0.12, 0.04, 8, 0, 2.81, lz), 0x2d2520), 0.006)
		m.light(0, 2.6, lz, "lantern")
	for q in [[-h, -h], [h, -h], [-h, h], [h, h]]: m.circle(q[0], q[1], 0.25)
	m.box_c(-h - 0.15, h + 0.15, -h - 0.15, -h + 0.1)
	m.box_c(-h - 0.15, -h + 0.1, -h, h)
	m.box_c(h - 0.1, h + 0.15, -h, h)
	m.anchor("floor", Vector3(0, F, 0))
	m.anchor("step", Vector3(0, 0, h + 0.9))
	return {}
