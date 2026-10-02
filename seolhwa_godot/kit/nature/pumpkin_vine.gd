# 호박 넝쿨 — 울타리·담 밑을 따라 땅을 기는 넓은 잎 + 호박 한둘(누런 늙은호박/푸른 애호박).
# params: seed, len(2.6) — x 방향으로 뻗음
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var L := float(params.get("len", 2.6))
	var b := Kit.Batch.new()
	# 덩굴 줄기
	var v := Kit.cyl(0.02, 0.02, L, 3, 0, 0.05, 0, 0, 0, PI / 2, false)
	b.add("flat", Kit.paint(v, C.c("#6f8044"), C.c("#5a6a38"), 0.03, r), 0.0)
	# 넓은 잎(납작 덩이)
	for i in 6:
		var x := -L / 2 + L * (i + 0.5) / 6 + (r.next() - 0.5) * 0.2
		var g := C.sphere(0.24 + r.next() * 0.08, 6, 2)
		Kit.xf(g, x, 0.1, (r.next() - 0.5) * 0.4, 0, r.next() * 3, 0, 1.1, 0.4, 1.0)
		b.add("leaf", Kit.paint(g, C.c("#8ea25a"), C.c("#56683a"), 0.05, r), 0.015)
	# 호박
	var cols := [["#d8913c", "#b06a28"], ["#b9b058", "#7e8040"]]
	for i in 1 + int(r.next() * 2):
		var c: Array = C.pick(cols, r)
		var g := C.sphere(0.2 + r.next() * 0.06, 7, 3)
		Kit.xf(g, (r.next() - 0.5) * L * 0.7, 0.13, 0.25 + r.next() * 0.15, 0, r.next() * 3, 0, 1.15, 0.75, 1.15)
		b.add("organic", Kit.paint(g, C.c(c[0]), C.c(c[1]), 0.03, r), 0.02)
	return C.result(b, "호박넝쿨", [], Vector2(L, 1.0), false, { cast = false })
