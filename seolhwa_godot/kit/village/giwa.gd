# 기와집(양반·향리 안채/사랑채) — 웹 buildings.js giwa() 이식.
# params: seed, w(9, 5칸), d(5.4), bays(5), plain(false: true면 단청 띠 대신 민가식 밤색 창방 — 민가 기와집)
# 앞(+z): 높은 돌 기단 + 3단 계단, 가운데 대청(열림), 양옆 방문, 끝칸 벽+창, 툇마루.
# 성능: 웹 지붕 격자 36×20은 먹선 포함 6천 삼각형을 넘어 24×12로 줄임(기와 골이 조금 굵어짐).
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var info := draw(m, params)
	return m.result("기와집", Vector2(info.W + 3.6, info.D + 3.4))

static func draw(m: C.M, o: Dictionary) -> Dictionary:
	var W: float = o.get("w", 9.0); var D: float = o.get("d", 5.4)
	var F := 0.75; var wallH := 2.3; var zf := D / 2; var t := 0.18; var top := F + wallH
	var R := m.rng
	var plain: bool = o.get("plain", false)
	var bays: int = o.get("bays", 5)
	var bw := W / bays
	var mid := bays / 2
	# 높은 돌 기단 + 장대석 줄 + 계단
	m.add("base", "stone", C.P(Kit.box(W + 1.2, F + 0.1, D + 1.2, 0, (F - 0.1) / 2, 0), 0xaaa498, 0x7b766c, 0.05, R), 0.03)
	var nst := int(round(W * 1.5))
	for i in nst: m.add("base", "stone", C.P(Kit.box(0.64, 0.3, 0.05, -W / 2 - 0.3 + i * (W + 0.6) / (nst - 1), 0.28 + (i % 2) * 0.3, D / 2 + 0.61), 0xb5afa2, 0x948f84, 0.06, R), 0)
	for s in 3: m.add("base", "stone", C.P(Kit.box(1.8, 0.25, 0.4, 0, 0.12 + s * 0.25, D / 2 + 1.2 - s * 0.35), 0xb8b2a5, 0x8e897f, 0.04, R), 0.02)
	# 둥근 기둥(앞), 뒤는 각기둥으로 단순화(무대 세트)
	var pil: Array = [0x6b5038, 0x4d3826] if plain else C.DANCHEONG_R
	for i in bays + 1:
		var x := -W / 2 + i * bw
		m.add("front", "flat", C.PA(Kit.cyl(0.14, 0.15, wallH, 8, x, F + wallH / 2, zf, 0, 0, 0, false), pil), 0.02)
		m.add("body", "flat", C.PA(Kit.box(0.24, wallH, 0.24, x, F + wallH / 2, -zf), pil), 0.02)
	m.add("body", "mud", C.PA(Kit.box(W, wallH, t, 0, F + wallH / 2, -zf), C.PLASTER, 0.03, R), 0.02)
	for s in [-1, 1]: m.add("body", "mud", C.PA(Kit.box(t, wallH, D, s * W / 2, F + wallH / 2, 0), C.PLASTER, 0.03, R), 0.02)
	for i in bays:
		var x0 := -W / 2 + i * bw; var x1 := x0 + bw; var cx := (x0 + x1) / 2
		if i == mid:
			m.add("front", "flat", C.P(Kit.box(bw, wallH, 0.05, cx, F + wallH / 2, zf - 1.4), 0x3e3128, 0x2c231c), 0)
			m.add("front", "flat", C.P(Kit.box(bw, 0.06, 1.4, cx, F + 0.03, zf - 0.7), 0xa07e56, 0x8a6a46), 0)
			m.add("front", "flat", C.P(Kit.box(bw, 0.35, t, cx, top - 0.17, zf), 0x7a5a3c, 0x5e442e), 0.015)
			# 대청 뒤 판문(어둠 속 희미한 널)
			m.add("front", "wood", C.P(Kit.box(bw * 0.7, 1.7, 0.04, cx, F + 1.0, zf - 1.36), 0x4a3a2c, 0x3a2d22), 0)
			continue
		if abs(i - mid) == 1:
			C.holed_wall(m, "front", x0, x1, F, top, cx - 0.62, cx + 0.62, F + 0.35, F + 2.0, zf, t, C.PLASTER)
			C.paper_panel(m, "front", cx - 0.31, F + 1.175, 0.6, 1.62, zf)
			C.paper_panel(m, "front", cx + 0.31, F + 1.175, 0.6, 1.62, zf)
			m.add("front", "wood", C.PA(Kit.box(bw, 0.34, 0.2, cx, F + 0.17, zf), C.WOOD_L), 0.012)
			m.light(cx, F + 1.2, zf + 0.2, "window")
		else:
			C.holed_wall(m, "front", x0, x1, F, top, cx - 0.42, cx + 0.42, F + 0.95, F + 1.65, zf, t, C.PLASTER)
			C.paper_panel(m, "front", cx, F + 1.3, 0.84, 0.7, zf)
			m.add("front", "wood", C.PA(Kit.box(bw, 0.5, 0.2, cx, F + 0.25, zf + 0.01), C.WOOD_L), 0.012)
			m.light(cx, F + 1.3, zf + 0.2, "window")
	# 창방 + 띠
	var beam: Array = [0x6b5038, 0x4d3826] if plain else [0x557d70, 0x3f6558]
	m.add("front", "flat", C.PA(Kit.box(W + 0.5, 0.24, 0.3, 0, top + 0.12, zf), beam, 0.02), 0.02)
	if not plain: m.add("front", "flat", C.P(Kit.box(W + 0.5, 0.08, 0.32, 0, top + 0.28, zf), 0xa3503a), 0.01)
	m.add("body", "flat", C.PA(Kit.box(W + 0.5, 0.3, 0.3, 0, top + 0.15, -zf), beam), 0.02)
	for s in [-1, 1]: m.add("body", "flat", C.PA(Kit.box(0.3, 0.3, D + 0.4, s * W / 2, top + 0.15, 0), beam), 0.02)
	# 툇마루
	m.add("front", "wood", C.PA(Kit.box(W - 0.2, 0.08, 0.7, 0, F - 0.02, zf + 0.35), C.WOOD_L), 0.015)
	# 지붕
	var eave := top + 0.55
	var nx: int = o.get("roof_nx", 24); var nz: int = o.get("roof_nz", 12)
	var r := C.curved_roof(W / 2 + 1.7, D / 2 + 1.55, eave, 2.4, 0.6, 1.9, 0.26, nx, nz)
	m.add("roof", "tile", r.roof, 0.05)
	m.add("roof", "makse", r.edge, 0)
	C.ridge_cap(m, "roof", r.ridge_half + 0.2, r.ridge_y)
	m.box_c(-W / 2 - 0.6, W / 2 + 0.6, -D / 2 - 0.6, D / 2 + 1.45)
	m.anchor("daecheong", Vector3(0, F, zf - 0.6))
	m.anchor("steps", Vector3(0, 0, zf + 1.7))
	m.anchor("maru", Vector3(-bw, F, zf + 0.35))
	return { F = F, top = top, eave = eave, W = W, D = D }
