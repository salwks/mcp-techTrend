# 풀 무더기 — 세모뿔 풀잎 여럿(먹선 없음). kind: meadow(들풀) / dry(마른 풀빛) / forest(숲 바닥, 짙음) / eoksae(억새 — 고원·능선, 은빛 이삭)
# params: seed, kind("meadow"), n(10)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")
const TONE := { meadow = ["#a9ad6c", "#6d7a44"], dry = ["#bfb27a", "#7f7a4a"], forest = ["#8a9a5c", "#4c5a34"], eoksae = ["#c4bb8a", "#7a7c4c"] }

# draw(b, r, params): Batch(또는 add(key,g,outline)를 가진 것)에 그려 넣는다 — cover.gd가 여러 개를 한 메시로 합칠 때 쓴다
static func draw(b, r: Kit.Rng, params: Dictionary) -> void:
	var kind := str(params.get("kind", "meadow"))
	var tone: Array = TONE.get(kind, TONE.meadow)
	var tall := kind == "eoksae"
	var n := int(params.get("n", 8 if tall else 10))
	for i in n:
		var h := (0.9 + r.next() * 0.6) if tall else (0.25 + r.next() * 0.3)
		var px := (r.next() - 0.5) * (0.6 if tall else 0.45); var pz := (r.next() - 0.5) * 0.35
		var tx := (r.next() - 0.5) * (0.5 if tall else 0.7); var tz := (r.next() - 0.5) * 0.6
		var g := C.cone(0.04 if tall else 0.06, h, 3, true)
		Kit.xf(g, px, h / 2, pz, tz, r.next() * 3, tx)
		b.add("flat", Kit.paint(g, C.c(tone[0]), C.c(tone[1]), 0.05, r), 0.0)
		if tall and i % 2 == 0:
			var f := C.cone(0.07, 0.35, 3, true)
			Kit.xf(f, px - tx * h * 0.95, h + 0.05, pz + tz * h * 0.95, PI + tz, 0, tx * 0.5)
			b.add("flat", Kit.paint(f, C.c("#ece4cc"), C.c("#cfc3a2"), 0.04, r), 0.0)

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	draw(b, r, params)
	var tall := str(params.get("kind", "meadow")) == "eoksae"
	return C.result(b, "억새" if tall else "풀", [], Vector2(0.8, 0.6), false, { cast = false })
