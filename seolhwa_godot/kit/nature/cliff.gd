# 벼랑 조각 — 지리산 화강암 벼랑: 세로 절리로 갈라진 각진 바위 기둥들(부벽준 느낌), 위는 비스듬히 깎이고 밑에 굴러떨어진 돌.
# 정면(+z)이 내리막(카메라 쪽). 폭 w(x)·높이 h·두께 d.
# params: seed, w(6), h(6), d(3)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var W := float(params.get("w", 6.0)); var H := float(params.get("h", 6.0)); var D := float(params.get("d", 3.0))
	var b := Kit.Batch.new()
	var x := -W / 2
	var cols := []
	while x < W / 2 - 0.3:
		var cw := 1.3 + r.next() * 0.9
		cw = minf(cw, W / 2 - x)
		var cx := x + cw / 2
		var cz := (r.next() - 0.5) * D * 0.3
		var ch := H * (0.78 + r.next() * 0.22) * (1.0 - absf(cx) / W * 0.7)
		# 불규칙한 오각·육각 단면
		var sides := 5 + int(r.next() * 2)
		var poly := PackedVector2Array()
		for i in sides:
			var a := TAU * i / sides + r.next() * 0.4
			poly.append(Vector2(cx + sin(a) * cw * 0.62 * (0.85 + r.next() * 0.3), cz - cos(a) * D * 0.5 * (0.8 + r.next() * 0.3)))
		# 반시계 보장
		if not Geometry2D.is_polygon_clockwise(poly): poly.reverse()
		var parts := [[0.0, ch * (0.55 + r.next() * 0.2)], []]
		parts[1] = [parts[0][1], ch - parts[0][1]]
		for pi in 2:
			var y0: float = parts[pi][0]; var hh: float = parts[pi][1]
			var ybot := y0 - (0.4 if pi == 0 else 0.0)
			var g := Kit.extrude(poly, hh + (0.4 if pi == 0 else 0.0), ybot)
			var ytop := y0 + hh
			# 위로 갈수록 좁히고(경사), 윗면은 앞으로 비스듬히
			var cen := Vector3(cx, 0, cz)
			var shrink := 0.9 if pi == 0 else 0.8
			var tilt := (r.next() - 0.3) * 0.5
			for k in g.pos.size():
				var p := g.pos[k]
				if p.y > ytop - 0.01:
					var q := cen + (Vector3(p.x, 0, p.z) - cen) * shrink
					p = Vector3(q.x, p.y - (p.z - cz) * tilt, q.z)
				g.pos[k] = p
			if pi == 1: Kit.xf(g, (r.next() - 0.5) * 0.15, 0, (r.next() - 0.5) * 0.2)
			var g2 := b.add("rock", Kit.paint(g, C.c("#c6bfae" if pi == 1 else "#b4ad9c"), C.c("#6f695f" if pi == 0 else "#8e877a"), 0.07, r), 0.04)
			Kit.face_normals(g2) # 각진 면(부벽준) — rock 붓결은 유지
		cols.append({ type = "circle", x = cx, z = cz, r = cw * 0.6 })
		x += cw * (0.8 + r.next() * 0.1)
	# 벼랑 밑 굴러떨어진 돌
	for i in 3:
		var s := 0.35 + r.next() * 0.45
		var g := Kit.lump(s, 0, r, 0.3, 0.7)
		Kit.xf(g, (r.next() - 0.5) * W * 0.9, s * 0.25, D * 0.5 + 0.3 + r.next() * 0.8, 0, r.next() * 6, 0)
		b.add("rock", Kit.paint(g, C.c("#b8b2a2"), C.c("#66615a"), 0.05, r), 0.025)
	return C.result(b, "벼랑", cols, Vector2(W + 0.6, D + 1.6), true, { height = H })
