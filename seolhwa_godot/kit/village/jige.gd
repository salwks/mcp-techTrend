# 지게 + 지게작대기 (+ 선택: 바소쿠리, 나뭇짐). 서 있는 지게(작대기로 받침).
# params: seed, load:"none"|"basket"|"wood"
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	draw(m, false, params.get("load", "basket"))
	m.circle(0, 0, 0.45)
	return m.result("지게", Vector2(0.9, 1.1), false)

# lean=true면 벽에 기대 놓음(작대기 없이, 뒤로 기움 → 벽은 -z)
static func draw(m: C.M, lean := false, load := "none") -> void:
	var tilt := -0.28 if lean else 0.22
	var old := m.xform
	m.xform = old * Transform3D(Basis(Vector3.RIGHT, tilt), Vector3.ZERO)
	var col := [0x9a7852, 0x6b5038]
	# 두 다리(위로 좁아짐) + 가지(새고자리)
	for s in [-1, 1]:
		m.add("p", "wood", C.PA(C.beam(Vector3(s * 0.32, 0, 0), Vector3(s * 0.2, 1.55, 0), 0.06, 0.07), col), 0.008)
		m.add("p", "wood", C.PA(C.beam(Vector3(s * 0.29, 0.55, 0), Vector3(s * 0.33, 0.85, 0.42), 0.05, 0.05), col), 0.006)
	for y in [0.35, 0.75, 1.15, 1.45]:
		var hw: float = 0.32 - y * 0.08
		m.add("p", "wood", C.P(Kit.box(hw * 2, 0.04, 0.04, 0, y, 0), 0x7a5c3e), 0)
	# 등태(짚)
	m.add("p", "thatch", C.PA(Kit.box(0.4, 0.35, 0.06, 0, 1.0, -0.06), C.STRAW, 0.04, m.rng), 0.006)
	match load:
		"basket":
			# 바소쿠리: 안팎이 있는 얕은 대바구니(지게 가지 위)
			var g := C.lathe([Vector2(0, 0), Vector2(0.3, 0.02), Vector2(0.44, 0.3), Vector2(0.4, 0.31), Vector2(0.27, 0.07), Vector2(0, 0.06)], 8)
			m.add("p", "thatch", C.P(Kit.xf(g, 0, 0.75, 0.32, -0.25, 0, 0, 1, 1, 0.75), 0xc8ad6e, 0x9a8050), 0.01)
		"wood":
			for i in 5: m.add("p", "wood", C.P(Kit.cyl(0.05, 0.05, 1.0, 5, -0.2 + i * 0.1, 1.05 + (i % 2) * 0.08, 0.3, 0, 0, 0), 0x8a6a48, 0x5e442e), 0.006)
	m.xform = old
	if not lean:
		m.add("p", "wood", C.P(C.beam(Vector3(0, 0, -0.55), Vector3(0, 1.15, -0.02), 0.04, 0.04), 0x7a5c3e), 0.006)
