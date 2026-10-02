# 벼 포기 — 웹 vegetation.js riceTuft 이식. patch>1이면 0.85m 간격 patch×patch 포기를 한 메시로(흩뿌리기용)
# params: seed, patch(1), spacing(0.85)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var n := int(params.get("patch", 1))
	var sp := float(params.get("spacing", 0.85))
	var b := Kit.Batch.new()
	var off := (n - 1) * sp * 0.5
	for i in n:
		for j in n:
			var x := i * sp - off + (r.next() - 0.5) * 0.1
			var z := j * sp - off + (r.next() - 0.5) * 0.1
			var g := C.cone(0.13, 0.5 + r.next() * 0.12, 4, true)
			Kit.xf(g, x, 0.25, z, 0, r.next() * 2, 0)
			b.add("flat", Kit.paint(g, C.c("#cdbd62"), C.c("#6f7f3e"), 0.05, r), 0.0)
	return C.result(b, "벼포기", [], Vector2(n * sp, n * sp), false, { cast = false })
