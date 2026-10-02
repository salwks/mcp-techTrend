# 밭 작물 한 줄(두둑 + 포기). kind: bean(콩) / millet(조) / barley(보리) / cabbage(배추 — 연둣빛 포기) / pepper(고추 — 짙은 포기 + 붉은 열매)
# params: seed, kind("bean"), len(2.4), n(5, 포기 수), ridge(true), rows(1, 1.3m 간격 여러 줄) — 줄은 x 방향
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

# draw(b, r, params): Batch(또는 add(key,g,outline)를 가진 것)에 그린다 — garden_plot이 이랑마다 쓴다
static func draw(b, r: Kit.Rng, params: Dictionary) -> void:
	var kind := str(params.get("kind", "bean"))
	var L := float(params.get("len", 2.4))
	var n := int(params.get("n", 5))
	if bool(params.get("ridge", true)):
		# 고랑 두둑(낮은 흙 둔덕)
		var ridge := Kit.cyl(0.18, 0.28, 0.14, 4, 0, 0.03, 0, 0, PI / 4, 0)
		Kit.xf(ridge, 0, 0, 0, 0, 0, 0, L * 2.6, 1, 1)
		b.add("mud", Kit.paint(ridge, C.c("#b09868"), C.c("#7a6648"), 0.03, r), 0.0)
	for i in n:
		var x := -L / 2 + L * (i + 0.5) / n + (r.next() - 0.5) * 0.1
		match kind:
			"bean":
				var g := C.sphere(0.2 + r.next() * 0.06, 5, 3)
				Kit.xf(g, x, 0.22, 0, 0, r.next() * 3, 0, 1, 0.7, 1)
				b.add("leaf", Kit.paint(g, C.c("#93a25e"), C.c("#56663a"), 0.05, r), 0.0)
			"cabbage":
				# 배추: 둥글게 오므린 연둣빛 포기(겉잎 짙고 속 밝게)
				var g := C.sphere(0.2 + r.next() * 0.04, 6, 3)
				Kit.xf(g, x, 0.2, 0, 0, r.next() * 3, 0, 1, 0.9, 1)
				b.add("leaf", Kit.paint(g, C.c("#c6cf94"), C.c("#6f8a4a"), 0.05, r), 0.0)
			"pepper":
				# 고추: 짙은 잎 포기 + 붉은 고추 둘
				var g := C.sphere(0.17 + r.next() * 0.04, 5, 2)
				Kit.xf(g, x, 0.32, 0, 0, r.next() * 3, 0, 1, 1.3, 1)
				b.add("leaf", Kit.paint(g, C.c("#6f8a48"), C.c("#46582e"), 0.05, r), 0.0)
				for k in 2:
					var p := C.cone(0.05, 0.16, 3, true)
					Kit.xf(p, x + (r.next() - 0.5) * 0.25, 0.22 + r.next() * 0.12, (r.next() - 0.5) * 0.25, PI, 0, 0)
					b.add("organic", Kit.paint(p, C.c("#c8442e"), C.c("#a0301e"), 0.03, r), 0.0)
			_:
				var head := "#cdb86a" if kind == "barley" else "#c8a85a"
				for k in 3:
					var h := 0.55 + r.next() * 0.25
					var g := C.cone(0.035, h, 3, true)
					Kit.xf(g, x + (r.next() - 0.5) * 0.12, h / 2, (r.next() - 0.5) * 0.1, (r.next() - 0.5) * 0.4, 0, (r.next() - 0.5) * 0.4)
					b.add("flat", Kit.paint(g, C.c("#9aa45e"), C.c("#647040"), 0.05, r), 0.0)
				var f := C.cone(0.05, 0.22, 4, true)
				var bend := 0.0 if kind == "barley" else 0.9
				Kit.xf(f, x + bend * 0.08, 0.72, 0, 0, 0, PI - bend if bend > 0 else 0.0)
				b.add("flat", Kit.paint(f, C.c(head), C.c(head), 0.04, r), 0.0)

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	# rows>1: 1.3m 간격(z)으로 여러 줄을 한 메시로 — 흩뿌리기 인스턴스 수를 줄인다
	var rows := int(params.get("rows", 1))
	if rows <= 1:
		draw(b, r, params)
	else:
		var Cover := load("res://kit/nature/cover.gd")
		var o = Cover.Off.new()
		o.b = b
		for q in rows:
			o.ox = 0.0; o.oz = (q - (rows - 1) * 0.5) * 1.3; o.ry = 0.0
			draw(o, r, params)
	return C.result(b, "밭작물", [], Vector2(float(params.get("len", 2.4)), 0.6 + 1.3 * (int(params.get("rows", 1)) - 1)), false, { cast = false })
