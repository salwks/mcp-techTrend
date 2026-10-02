# 갈대 — 웹 vegetation.js reeds 이식(가는 줄기 + 연한 이삭)
# params: seed, n(7)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

# draw(b, r, params): Batch(또는 add(key,g,outline)를 가진 것)에 그려 넣는다 — cover.gd가 여러 개를 한 메시로 합칠 때 쓴다
static func draw(b, r: Kit.Rng, params: Dictionary) -> void:
	var n := int(params.get("n", 7))
	for i in n:
		var h := 0.8 + r.next() * 0.7
		var px := (r.next() - 0.5) * 0.8; var pz := (r.next() - 0.5) * 0.5; var tx := (r.next() - 0.5) * 0.3; var tz := (r.next() - 0.5) * 0.3
		var g := C.cone(0.03, h, 3, true)
		Kit.xf(g, px, h / 2, pz, tx, 0, tz)
		b.add("flat", Kit.paint(g, C.c("#b9a878"), C.c("#6f7448"), 0.06, r), 0.0)
		if i % 2 == 0:
			var f := C.cone(0.05, 0.22, 4, true)
			Kit.xf(f, px + tz * h * 0.9, h + 0.05, pz - tx * h * 0.9, PI, 0, 0)
			b.add("flat", Kit.paint(f, C.c("#e2d6b4"), C.c("#c8b88e"), 0.05, r), 0.0)

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	draw(b, r, params)
	return C.result(b, "갈대", [], Vector2(1.0, 0.7), false, { cast = false })
