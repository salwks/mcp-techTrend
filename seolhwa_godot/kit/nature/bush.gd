# 덤불 — 웹 vegetation.js bush 이식. flowers=true면 진달래 꽃송이 점
# params: seed, s(1), flowers(false)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var s := float(params.get("s", 1.0))
	var fl := bool(params.get("flowers", false))
	var b := Kit.Batch.new()
	var col: Array = ["#8f9a60", "#55603c"] if fl else C.pick([["#8e9a60", "#55603c"], ["#9aa06a", "#626b42"], ["#7d8c58", "#4a5638"]], r)
	var n := 1 + int(r.next() * 2)
	for i in n:
		var g := C.sphere((0.5 + r.next() * 0.3) * s, 7, 3)
		Kit.xf(g, (r.next() - 0.5) * 0.8 * s, 0.22 * s, (r.next() - 0.5) * 0.5 * s, 0, r.next() * 3, 0, 1, 0.62, 0.85)
		b.add("leaf", Kit.paint(g, C.c(col[0]), C.c(col[1]), 0.04, r), 0.025)
	if fl:
		for i in 5:
			var g := C.sphere(0.09 * s, 5, 3)
			Kit.xf(g, (r.next() - 0.5) * 0.9 * s, (0.35 + r.next() * 0.2) * s, (r.next() - 0.5) * 0.6 * s)
			b.add("organic", Kit.paint(g, C.c("#e79ab2"), C.c("#c97890"), 0.05, r), 0.0)
	return C.result(b, "덤불", [], Vector2(1.6 * s, 1.2 * s), false)
