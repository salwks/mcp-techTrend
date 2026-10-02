# 밭 작물 한 줄(고랑 위 포기 다섯). kind: bean(콩 — 낮고 둥근 잎덩이) / millet(조 — 가는 잎 + 숙인 이삭) / barley(보리 — 곧은 잎, 누른 이삭)
# params: seed, kind("bean"), len(2.4) — 줄은 x 방향
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var kind := str(params.get("kind", "bean"))
	var L := float(params.get("len", 2.4))
	var b := Kit.Batch.new()
	# 고랑 두둑(낮은 흙 둔덕)
	var ridge := Kit.cyl(0.18, 0.28, 0.14, 4, 0, 0.03, 0, 0, PI / 4, 0)
	Kit.xf(ridge, 0, 0, 0, 0, 0, 0, L * 2.6, 1, 1)
	b.add("mud", Kit.paint(ridge, C.c("#a08a62"), C.c("#7a6648"), 0.03, r), 0.0)
	for i in 5:
		var x := -L / 2 + L * (i + 0.5) / 5 + (r.next() - 0.5) * 0.1
		if kind == "bean":
			var g := C.sphere(0.2 + r.next() * 0.06, 5, 3)
			Kit.xf(g, x, 0.22, 0, 0, r.next() * 3, 0, 1, 0.7, 1)
			b.add("leaf", Kit.paint(g, C.c("#93a25e"), C.c("#56663a"), 0.05, r), 0.0)
		else:
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
	return C.result(b, "밭작물", [], Vector2(L, 0.6), false, { cast = false })
