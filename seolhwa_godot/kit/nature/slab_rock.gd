# 계곡 너럭바위 — 물가의 넓고 평평한 화강암 반석(사람이 올라앉는 바위). 걸어 올라설 수 있게 충돌체 없음(높이 0.3~0.6m).
# params: seed, w(4), d(2.6)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var W := float(params.get("w", 4.0)); var D := float(params.get("d", 2.6))
	var b := Kit.Batch.new()
	var g := Kit.lump(1.0, 1, r, 0.18, 1.0)
	var top := 0.35 + r.next() * 0.25
	for k in g.pos.size():
		var p := g.pos[k]
		var y := p.y * 0.5
		if y > 0.1: y = 0.1 + (y - 0.1) * 0.15
		y = maxf(y, -0.12)
		g.pos[k] = Vector3(p.x * W * 0.5, y / 0.175 * top, p.z * D * 0.5)
	Kit.xf(g, 0, 0.0, 0, (r.next() - 0.5) * 0.06, r.next() * 0.6 - 0.3, (r.next() - 0.5) * 0.06)
	b.add("rock", Kit.paint(g, C.c("#d2cbb9"), C.c("#6c675e"), 0.05, r), 0.035)
	# 곁에 작은 돌 하나
	var g2 := Kit.lump(0.45, 0, r, 0.3, 0.6)
	Kit.xf(g2, W * 0.45, 0.1, D * 0.35, 0, r.next() * 6, 0)
	b.add("rock", Kit.paint(g2, C.c("#b6b0a2"), C.c("#5f5b53"), 0.05, r), 0.025)
	return C.result(b, "너럭바위", [], Vector2(W + 0.8, D + 0.6), false, { height = top })
