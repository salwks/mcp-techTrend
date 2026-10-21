# 벼랑 조각 — 지리산 화강암 벼랑: 세로 절리로 갈라진 각진 바위 기둥들(부벽준 느낌), 위는 비스듬히 깎이고 밑에 굴러떨어진 돌.
# 정면(+z)이 내리막(카메라 쪽). 폭 w(x)·높이 h·두께 d.
# params: seed, w(6), h(6), d(3), form(없으면 seed로 고름)
#   integ-mountain: 한 가지 세로 기둥만이 아니라 다섯 꼴 — columns 세로 절리 기둥 · slabs 층진 화강암 판(판상 절리) ·
#   dome 둥글게 닳은 화강암 덩이(박리 — 껍질처럼 벗겨진 겹) · overhang 위 판이 앞으로 튀어나온 처마 바위 · ridge 암릉(톱니진 바위 마루)
#   겉면 무늬는 재질(사진 스캔 화강암 세 축 투영 — materials.gd)이 맡는다.
extends RefCounted
const C := preload("res://kit/nature/_common.gd")
const FORMS := ["columns", "slabs", "dome", "overhang", "ridge"]

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var W := float(params.get("w", 6.0)); var H := float(params.get("h", 6.0)); var D := float(params.get("d", 3.0))
	var form := String(params.get("form", FORMS[absi(int(params.get("seed", 1))) % FORMS.size()]))
	if form != "columns": return _build_form(form, r, W, H, D)
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

# 둥글고 모난 판(불규칙 다각형, 반시계)
static func _blob_poly(r: Kit.Rng, cx: float, cz: float, rx: float, rz: float, sides: int, jag := 0.25) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i in sides:
		var a := TAU * i / sides + r.next() * 0.35
		var k := 1.0 - jag * 0.5 + r.next() * jag
		poly.append(Vector2(cx + sin(a) * rx * k, cz - cos(a) * rz * k))
	if not Geometry2D.is_polygon_clockwise(poly): poly.reverse()
	return poly

static func _slab(b: Kit.Batch, r: Kit.Rng, poly: PackedVector2Array, y0: float, th: float, bevel: float, top: String, bot: String) -> void:
	var g := Kit.extrude(poly, th, y0)
	# 윗면 가장자리를 둥글게 깎는다(물에 닳은 화강암 판) — 윗면 꼭짓점을 가운데 쪽으로 조금
	var cen := Vector2.ZERO
	for q in poly: cen += q
	cen /= poly.size()
	for k in g.pos.size():
		var p := g.pos[k]
		if p.y > y0 + th - 0.01:
			var q := Vector2(p.x, p.z)
			q = cen + (q - cen) * (1.0 - bevel)
			p = Vector3(q.x, p.y, q.y)
		g.pos[k] = p
	var g2 := b.add("rock", Kit.paint(g, C.c(top), C.c(bot), 0.06, r), 0.035)
	Kit.face_normals(g2)

static func _build_form(form: String, r: Kit.Rng, W: float, H: float, D: float) -> Dictionary:
	var b := Kit.Batch.new()
	var cols := []
	match form:
		"slabs":
			# 판상 절리: 두께 0.6~1.6m 판이 3~7겹, 겹마다 앞뒤로 어긋나고 한두 겹은 앞으로 내밀었다
			var y := -0.5
			var n := 0
			var rx := W * 0.5; var rz := D * 0.55
			while y < H - 0.4 and n < 9:
				var th := minf(H - y, (0.6 + r.next() * 1.0) * maxf(H / 6.0, 0.7))
				rx = clampf(rx * (0.82 + r.next() * 0.22), W * 0.22, W * 0.55)
				rz = clampf(rz * (0.85 + r.next() * 0.25), D * 0.25, D * 0.7)
				var ox := (r.next() - 0.5) * W * 0.15; var oz := (r.next() - 0.35) * D * 0.25
				_slab(b, r, _blob_poly(r, ox, oz, rx, rz, 7 + int(r.next() * 3), 0.3), y, th + 0.02, 0.06 + r.next() * 0.08, "#c4beb0", "#7a746a")
				y += th; n += 1
			cols.append({ type = "circle", x = 0.0, z = 0.0, r = minf(W, D) * 0.45 })
			cols.append({ type = "circle", x = -W * 0.28, z = 0.0, r = minf(W, D) * 0.35 })
			cols.append({ type = "circle", x = W * 0.28, z = 0.0, r = minf(W, D) * 0.35 })
		"dome":
			# 둥근 화강암 덩이: 큰 덩이 하나(눌린 위·묻힌 밑) + 옆 작은 덩이 + 겉에 벗겨진 껍질 한 겹(박리)
			var g := Kit.lump(1.0, 2, r, 0.12, 1.0)
			Kit.xf(g, 0, H * 0.42, 0, 0, r.next() * TAU, 0, W * 0.55, H * 0.62, D * 0.75)
			b.add("rock", Kit.paint(g, C.c("#c8c2b4"), C.c("#757066"), 0.05, r), 0.04)
			var sh := Kit.lump(1.0, 1, r, 0.1, 1.0)
			Kit.xf(sh, W * 0.12, H * 0.62, D * 0.18, -0.3, r.next() * TAU, 0.2, W * 0.42, H * 0.22, D * 0.5)
			b.add("rock", Kit.paint(sh, C.c("#d2ccbe"), C.c("#8d877b"), 0.05, r), 0.03)
			for i in 2:
				var s2 := 0.3 + r.next() * 0.25
				var g2 := Kit.lump(1.0, 1, r, 0.18, 1.0)
				Kit.xf(g2, (i * 2 - 1) * W * (0.42 + r.next() * 0.1), H * s2 * 0.35, (r.next() - 0.3) * D * 0.4, 0, r.next() * TAU, 0, W * s2 * 0.6, H * s2, D * s2 * 0.9)
				b.add("rock", Kit.paint(g2, C.c("#bfb9aa"), C.c("#6c675e"), 0.05, r), 0.03)
			cols.append({ type = "circle", x = 0.0, z = 0.0, r = minf(W, D) * 0.5 })
			cols.append({ type = "circle", x = -W * 0.35, z = 0.0, r = minf(W, D) * 0.3 })
			cols.append({ type = "circle", x = W * 0.35, z = 0.0, r = minf(W, D) * 0.3 })
		"overhang":
			# 처마 바위: 밑동 두세 덩이 위에 두꺼운 판이 앞(+z)으로 1~2m 튀어나왔다(밑은 그늘진 바위 그늘)
			var bh := H * (0.55 + r.next() * 0.15)
			var x := -W * 0.45
			while x < W * 0.4:
				var cw := W * (0.25 + r.next() * 0.15)
				_slab(b, r, _blob_poly(r, x + cw * 0.5, -D * 0.1, cw * 0.55, D * 0.42, 6, 0.3), -0.5, bh + 0.5, 0.08, "#b8b1a2", "#6a645b")
				x += cw * 0.9
			var cap := _blob_poly(r, 0.0, D * 0.25, W * 0.58, D * 0.75, 9, 0.25)
			_slab(b, r, cap, bh - 0.05, H - bh, 0.12, "#cbc5b6", "#5f5a52")
			cols.append({ type = "circle", x = 0.0, z = -D * 0.1, r = minf(W, D) * 0.42 })
			cols.append({ type = "circle", x = -W * 0.3, z = -D * 0.1, r = minf(W, D) * 0.32 })
			cols.append({ type = "circle", x = W * 0.3, z = -D * 0.1, r = minf(W, D) * 0.32 })
		_:
			# 암릉: 마루를 따라(x) 모난 바위 덩이 4~7개가 높낮이를 두고 늘어선 톱니 — 덩이마다 기울기 다름
			var n := 4 + int(r.next() * 4)
			for i in n:
				var t := (float(i) + 0.5) / n - 0.5
				var hh := H * (0.45 + r.next() * 0.55) * (1.0 - absf(t) * 0.6)
				var bw := W / n * (0.9 + r.next() * 0.5)
				var g := Kit.lump(1.0, 1, r, 0.28, 1.0)
				Kit.xf(g, t * W, hh * 0.45, (r.next() - 0.5) * D * 0.3, (r.next() - 0.5) * 0.4, r.next() * TAU, (r.next() - 0.5) * 0.5, bw * 0.62, hh * 0.6, D * (0.35 + r.next() * 0.2))
				var g2 := b.add("rock", Kit.paint(g, C.c("#c2bcad"), C.c("#6e695f"), 0.06, r), 0.035)
				Kit.face_normals(g2)
				cols.append({ type = "circle", x = t * W, z = 0.0, r = minf(bw, D) * 0.5 })
	# 발치에 굴러떨어진 돌
	for i in 2 + int(r.next() * 3):
		var s := 0.3 + r.next() * 0.5
		var g := Kit.lump(s, 0, r, 0.3, 0.7)
		Kit.xf(g, (r.next() - 0.5) * W * 0.9, s * 0.25, D * 0.5 + 0.3 + r.next() * 0.9, 0, r.next() * 6, 0)
		b.add("rock", Kit.paint(g, C.c("#b8b2a2"), C.c("#66615a"), 0.05, r), 0.025)
	return C.result(b, "벼랑", cols, Vector2(W + 0.6, D + 1.6), true, { height = H })
