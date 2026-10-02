# 바위 — 웹 vegetation.js rock 이식(피마준 붓결은 아틀라스 rock 영역). s<=1.2는 detail 0(작은 돌 ≤120 삼각형)
# params: seed, s(1), mossy(true)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

# draw(b, r, params): Batch(또는 add(key,g,outline)를 가진 것)에 그려 넣는다 — cover.gd가 여러 개를 한 메시로 합칠 때 쓴다
static func draw(b, r: Kit.Rng, params: Dictionary) -> void:
	var s := float(params.get("s", 1.0))
	var mossy := bool(params.get("mossy", true))
	var g := Kit.lump(s, 1 if s > 1.2 else 0, r, 0.3, 0.6 + r.next() * 0.25)
	Kit.xf(g, 0, s * 0.15, 0, 0, r.next() * 6, 0)
	var top := "#a4a58c" if mossy and r.next() < 0.5 else "#aba699"
	b.add("rock", Kit.paint(g, C.c(top), C.c("#5f5b53"), 0.05, r), 0.022 + s * 0.01)

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	var s := float(params.get("s", 1.0))
	draw(b, r, params)
	var cols := [{ type = "circle", x = 0.0, z = 0.0, r = s * 0.85 }] if s > 0.45 else []
	return C.result(b, "바위", cols, Vector2(2 * s, 2 * s), s > 1.4, { cast = s > 0.6 })
