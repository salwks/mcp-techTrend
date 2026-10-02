# 여울 돌 — 물살에 닳은 둥근 돌 넷(젖어 짙은 색). 큰 두 개만 먹선(≤120 삼각형).
# params: seed, s(1)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

# draw(b, r, params): Batch(또는 add(key,g,outline)를 가진 것)에 그려 넣는다 — cover.gd가 여러 개를 한 메시로 합칠 때 쓴다
static func draw(b, r: Kit.Rng, params: Dictionary) -> void:
	var s := float(params.get("s", 1.0))
	for i in 4:
		var rad := (0.45 - i * 0.07 + r.next() * 0.1) * s
		var a := r.next() * TAU; var d := (0.0 if i == 0 else 0.5 + r.next() * 0.4) * s
		var g := Kit.lump(rad, 0, r, 0.18, 0.32 + r.next() * 0.12)
		Kit.xf(g, cos(a) * d, rad * 0.12, sin(a) * d * 0.8, 0, r.next() * 6, 0)
		b.add("rock", Kit.paint(g, C.c("#8f8c80" if i % 2 else "#9c978a"), C.c("#4c4a44"), 0.05, r), 0.02 if i < 2 else 0.0)

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	var s := float(params.get("s", 1.0))
	draw(b, r, params)
	return C.result(b, "여울돌", [], Vector2(2.0 * s, 1.6 * s), false, { cast = false })
