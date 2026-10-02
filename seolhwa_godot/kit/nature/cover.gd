# 땅덮개 조각(흩뿌리기 전용 합성 모델) — 풀·들꽃·자갈·여울돌·갈대·작은 돌을 지름 ~4m 한 메시로 합친다.
# 종류마다 MultiMesh 하나씩이면 그리기 호출이 너무 많아져서, 토지이용별 덮개 한 종류로 묶는다.
# kind: yard(마을 터 — 짧은 풀·들꽃) / meadow(풀밭) / forest(숲 바닥) / alpine(고원 — 억새·원추리) / riverside(물가 — 갈대) / sandbar(모래톱 — 자갈) / rocky(바위터 — 마른 풀·돌)
# params: seed, kind("meadow"), r(2.0 퍼짐 반지름)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")
const Grass := preload("res://kit/nature/grass.gd")
const Flowers := preload("res://kit/nature/flowers.gd")
const Gravel := preload("res://kit/nature/gravel.gd")
const Stones := preload("res://kit/nature/stream_stones.gd")
const Reeds := preload("res://kit/nature/reeds.gd")
const Rock := preload("res://kit/nature/rock.gd")

# add(key, g, outline)를 받아 g를 (ox,oz)로 옮기고 ry만큼 돌려 실제 Batch에 넘긴다
class Off:
	var b: Kit.Batch
	var ox := 0.0
	var oz := 0.0
	var ry := 0.0
	func add(key: String, g: Kit.Geo, outline := 0.03) -> Kit.Geo:
		Kit.xf(g, ox, 0, oz, 0, ry, 0)
		return b.add(key, g, outline)

const RECIPE := {
	meadow = [["grass", { kind = "meadow", n = 7 }], ["grass", { kind = "dry", n = 6 }], ["grass", { kind = "meadow", n = 6 }], ["flowers", {}], ["grass", { kind = "meadow", n = 5 }],
		["grass", { kind = "dry", n = 5 }], ["grass", { kind = "meadow", n = 6 }], ["flowers", {}], ["grass", { kind = "meadow", n = 5 }]],
	forest = [["grass", { kind = "forest", n = 7 }], ["grass", { kind = "forest", n = 6 }], ["rock", { s = 0.32 }], ["grass", { kind = "forest", n = 5 }],
		["grass", { kind = "forest", n = 6 }], ["grass", { kind = "dry", n = 4 }]],
	alpine = [["grass", { kind = "eoksae", n = 6 }], ["grass", { kind = "dry", n = 6 }], ["flowers", { color = "#e39a4a" }], ["grass", { kind = "meadow", n = 6 }],
		["grass", { kind = "eoksae", n = 5 }], ["grass", { kind = "dry", n = 5 }], ["flowers", { color = "#e39a4a" }]],
	riverside = [["reeds", { n = 6 }], ["grass", { kind = "meadow", n = 6 }], ["reeds", { n = 5 }], ["reeds", { n = 6 }], ["grass", { kind = "meadow", n = 5 }], ["reeds", { n = 5 }]],
	sandbar = [["gravel", { spread = 1.2 }], ["gravel", { spread = 1.0 }], ["grass", { kind = "dry", n = 4 }], ["gravel", { spread = 1.3 }]],
	yard = [["grass", { kind = "short", n = 6 }], ["flowers", {}], ["grass", { kind = "short", n = 6 }], ["grass", { kind = "short", n = 5 }],
		["flowers", {}], ["grass", { kind = "short", n = 6 }], ["grass", { kind = "meadow", n = 4 }]],
	rocky = [["grass", { kind = "dry", n = 6 }], ["rock", { s = 0.38, mossy = false }], ["grass", { kind = "dry", n = 5 }], ["rock", { s = 0.28 }],
		["grass", { kind = "dry", n = 5 }], ["grass", { kind = "meadow", n = 5 }]],
}
const FLOWER_COLS := ["#f2e6a0", "#e8e2f0", "#f2e6a0", "#d8c4e6"]

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var kind := str(params.get("kind", "meadow"))
	var R := float(params.get("r", 2.0))
	var b := Kit.Batch.new()
	var o := Off.new()
	o.b = b
	var items: Array = RECIPE.get(kind, RECIPE.meadow)
	for i in items.size():
		var it: Array = items[i]
		var p: Dictionary = (it[1] as Dictionary).duplicate()
		var a := TAU * i / items.size() + r.next() * 0.8
		var d := R * (0.3 + r.next() * 0.7) if i > 0 else R * 0.15
		o.ox = cos(a) * d; o.oz = sin(a) * d; o.ry = r.next() * TAU
		match it[0]:
			"grass": Grass.draw(o, r, p)
			"flowers":
				if not p.has("color"): p.color = C.pick(FLOWER_COLS, r)
				Flowers.draw(o, r, p)
			"gravel": Gravel.draw(o, r, p)
			"stones": Stones.draw(o, r, p)
			"reeds": Reeds.draw(o, r, p)
			"rock": Rock.draw(o, r, p)
	return C.result(b, "땅덮개", [], Vector2(R * 2, R * 2), false, { cast = false })
