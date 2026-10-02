# 모래톱 자갈 — 납작한 조약돌 8개(먹선 없음, 80 삼각형).
# params: seed, spread(1.4)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")
const TONES := [["#cfc8b6", "#9a9384"], ["#bdb6a6", "#8a8476"], ["#d8d0bc", "#a49c8a"], ["#a9a496", "#78736a"]]

# draw(b, r, params): Batch(또는 add(key,g,outline)를 가진 것)에 그려 넣는다 — cover.gd가 여러 개를 한 메시로 합칠 때 쓴다
static func draw(b, r: Kit.Rng, params: Dictionary) -> void:
	var sp := float(params.get("spread", 1.4))
	for i in 8:
		var rad := 0.07 + r.next() * 0.12
		var g := C.pebble(rad, rad * (0.35 + r.next() * 0.25), r)
		Kit.xf(g, (r.next() - 0.5) * sp, 0.0, (r.next() - 0.5) * sp * 0.8, 0, r.next() * 6, 0)
		var t: Array = C.pick(TONES, r)
		b.add("stone", Kit.paint(g, C.c(t[0]), C.c(t[1]), 0.04, r), 0.0)

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	draw(b, r, params)
	var sp := float(params.get("spread", 1.4))
	return C.result(b, "자갈", [], Vector2(sp, sp * 0.8), false, { cast = false })
