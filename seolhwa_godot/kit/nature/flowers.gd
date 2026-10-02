# 들꽃 몇 송이 — 웹 vegetation.js flowers 이식. color: '#f2e6a0'(노랑) / '#e8e2f0'(흰) / '#e7a35a'(원추리 주황) 등
# params: seed, color, n(4)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

# draw(b, r, params): Batch(또는 add(key,g,outline)를 가진 것)에 그려 넣는다 — cover.gd가 여러 개를 한 메시로 합칠 때 쓴다
static func draw(b, r: Kit.Rng, params: Dictionary) -> void:
	var col := C.c(str(params.get("color", "#f2e6a0")))
	for i in int(params.get("n", 4)):
		var g := C.sphere(0.06, 4, 2)
		var px := (r.next() - 0.5) * 0.7; var py := 0.18 + r.next() * 0.1; var pz := (r.next() - 0.5) * 0.5
		Kit.xf(g, px, py, pz)
		b.add("organic", Kit.paint(g, col, col, 0.05, r), 0.0)
		# 꽃대(웹엔 없음 — 공중에 뜬 점처럼 보이지 않게 가는 줄기)
		var st := C.cone(0.012, py, 3, true)
		Kit.xf(st, px, py / 2, pz)
		b.add("flat", Kit.paint(st, C.c("#7f8a4c"), C.c("#5e6a3a"), 0.03, r), 0.0)

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	draw(b, r, params)
	return C.result(b, "들꽃", [], Vector2(0.8, 0.6), false, { cast = false })
