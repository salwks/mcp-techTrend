# 장작더미 — 쪼갠 장작을 우물 정(井)자로 엇갈려 쌓거나(stack) 처마 밑 벽에 길게 쌓음(row).
# params: seed, style:"row"|"stack", len(1.6), rows(4), cover(false: 이엉 덮개)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = params.get("len", 1.6); var rows: int = params.get("rows", 4)
	if params.get("style", "row") == "stack": stack(m, rows + 2)
	else: row(m, L, rows, bool(params.get("cover", false)))
	return m.result("장작더미", Vector2(L + 0.3, 1.2), false)

static func row(m: C.M, L := 1.6, rows := 4, cover := false) -> void:
	var R := m.rng
	var n := maxi(2, int(L / 0.22))
	for r in rows:
		for i in n - (r % 2):
			var x := -L / 2 + (i + 0.5 + (r % 2) * 0.5) * L / n
			var cc := [0xb08e62, 0x8a6a48] if m.r() < 0.6 else [0x9a7852, 0x6b5038]
			m.add("p", "wood", C.PA(Kit.cyl(0.1, 0.1, 0.9, 5, x, 0.1 + r * 0.18, 0, PI / 2, (m.r() - 0.5) * 0.15, 0), cc, 0.06, R), 0.008 if r == rows - 1 else 0.0)
	# 위에 이엉 한 장 덮개(cover)
	if cover: m.add("p", "thatch", C.PA(Kit.box(L + 0.2, 0.08, 1.0, 0, 0.1 + rows * 0.18 + 0.02, 0), C.STRAW, 0.05, R), 0.015)
	m.box_c(-L / 2 - 0.1, L / 2 + 0.1, -0.5, 0.5)

static func stack(m: C.M, layers := 6) -> void:
	var R := m.rng
	for l in layers:
		for i in 3:
			var o := -0.3 + i * 0.3
			var g := Kit.cyl(0.08, 0.08, 1.0, 5, 0, 0, 0, PI / 2, 0, 0)
			if l % 2 == 0: Kit.xf(g, o, 0.08 + l * 0.15, 0)
			else: Kit.xf(g, 0, 0.08 + l * 0.15, o, 0, PI / 2, 0)
			m.add("p", "wood", C.P(g, 0xa88a62, 0x7a5c3e, 0.06, R), 0.008)
	m.circle(0, 0, 0.6)
