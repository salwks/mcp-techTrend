# 대문 — style: "tile"(평대문, 웹 기와집 대문 이식) | "soseul"(솟을대문 + 양옆 행랑 칸) | "thatch"(초가 대문).
# 원점 = 문 가운데 바닥, 문은 x축으로 놓인 담 줄 위. 담은 따로(todam/stone_wall) 문 양옆 x=±half 에서 잇는다.
# params: seed, style("tile"), open(true: 문짝을 안(-z)으로 열어 둠), lantern(style tile/soseul에서 초롱)
# 반환 anchors.wall_l / wall_r: 담이 붙을 자리(x)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var half := draw(m, params.get("style", "tile"), bool(params.get("open", true)), bool(params.get("lantern", true)))
	return m.result("대문", Vector2(half * 2 + 1.0, 2.4))

# 반환: 문채 반폭(담 잇는 자리)
static func draw(m: C.M, style := "tile", open := true, lantern := true) -> float:
	var R := m.rng
	var half := 1.25
	var post_h := 2.3 if style != "thatch" else 2.0
	if style == "soseul": post_h = 2.9
	for s in [-1, 1]:
		m.add("p", "wood", C.PA(Kit.box(0.22, post_h, 0.22, s * 1.0, post_h / 2, 0), C.WOOD), 0.02)
		m.add("p", "stone", C.PA(Kit.box(0.4, 0.2, 0.4, s * 1.0, 0.1, 0), C.STONE), 0.01)
	m.add("p", "wood", C.PA(Kit.box(2.3, 0.18, 0.26, 0, post_h, 0), C.WOOD), 0.02)
	m.add("p", "wood", C.PA(Kit.box(2.0, 0.1, 0.2, 0, 0.05, 0), C.WOOD), 0.01)
	# 문짝 두 짝
	for s in [-1, 1]:
		var g := Kit.box(0.9, post_h - 0.4, 0.06, -s * 0.45, 0, 0)
		if open: Kit.xf(g, s * 0.95, (post_h - 0.4) / 2 + 0.12, -0.08, 0, -s * 1.35, 0)
		else: Kit.xf(g, s * 0.95, (post_h - 0.4) / 2 + 0.12, -0.08)
		m.add("p", "wood", C.P(g, 0x5a4432, 0x3f2f22, 0.04, R), 0.01)
	match style:
		"tile":
			C.tile_roof(m, "p", 1.75, 0.95, post_h + 0.2, 0.75, 8, 4, 0.28, 2.6)
		"soseul":
			C.tile_roof(m, "p", 1.7, 1.1, post_h + 0.2, 0.8, 8, 4, 0.3, 2.6)
			# 양옆 행랑 칸(낮은 지붕): 흰 회벽 + 작은 창
			for s in [-1, 1]:
				var cx: float = s * 2.3
				m.add("p", "mud", C.PA(Kit.box(2.0, 2.0, 2.0, cx, 1.0, -0.6), C.PLASTER, 0.03, R), 0.02)
				m.add("p", "stone", C.PA(Kit.box(2.2, 0.3, 2.2, cx, 0.15, -0.6), C.STONE, 0.05, R), 0.015)
				for q in [-1, 1]: m.add("p", "wood", C.PA(Kit.box(0.18, 2.0, 0.18, cx + q * 1.0, 1.0, 0.42), C.WOOD), 0.015)
				C.paper_panel(m, "p", cx, 1.35, 0.6, 0.5, 0.42)
				m.light(cx, 1.35, 0.6, "window")
				var old := m.push(cx, 0, -0.6)
				C.tile_roof(m, "p", 1.35, 1.45, 2.2, 0.7, 6, 6, 0.2, 1.6)
				m.pop(old)
			half = 3.3
		"thatch":
			C.thatch_cap(m, "p", 1.6, 0.95, post_h + 0.15, 0.6, 12, 3)
			lantern = false
	if lantern:
		m.add("p", "lamp", C.P(Kit.cyl(0.15, 0.15, 0.3, 8, 1.3, 1.8, 0.25), 0xc0443a), 0.01)
		m.add("p", "flat", C.P(Kit.cyl(0.1, 0.1, 0.04, 8, 1.3, 1.97, 0.25), 0x2d2520), 0)
		m.light(1.3, 1.8, 0.25, "lantern")
	for s in [-1, 1]: m.circle(s * 1.0, 0, 0.22)
	if style == "soseul":
		for s in [-1, 1]: m.box_c(s * 2.3 - 1.1, s * 2.3 + 1.1, -1.7, 0.5)
	if not open: m.box_c(-0.95, 0.95, -0.12, 0.05)
	m.anchor("gate_out", Vector3(0, 0, 1.0)); m.anchor("gate_in", Vector3(0, 0, -1.2))
	m.anchor("wall_l", Vector3(-half, 0, 0)); m.anchor("wall_r", Vector3(half, 0, 0))
	return half
