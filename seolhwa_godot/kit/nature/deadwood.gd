# 고사목 — 지리산 능선(노고단·반야봉 일대)의 하얗게 바랜 구상나무 고사목. kind: standing(선 채 마른 나무) / snag(부러진 그루터기)
# params: seed, kind("standing"), s(1), lod
extends RefCounted
const C := preload("res://kit/nature/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var s := float(params.get("s", 1.0))
	var lod := int(params.get("lod", 0))
	var snag := str(params.get("kind", "standing")) == "snag"
	var b := Kit.Batch.new()
	var ol := 0.0 if lod else 1.0
	var top := "#d8d2c4"; var bot := "#8e877a"
	var h := (2.2 if snag else 6.0 + r.next() * 2.0) * s
	var p0 := Vector3(0, -0.3, 0)
	var p1 := Vector3((r.next() - 0.5) * 0.3 * s, h * 0.55, 0)
	var p2 := Vector3(p1.x + (r.next() - 0.5) * 0.5 * s, h, (r.next() - 0.5) * 0.2 * s)
	b.add("bark", Kit.paint(Kit.limb(p0, p1, 0.24 * s, 0.18 * s, 5 if lod else 6), C.c(top), C.c(bot), 0.05, r), 0.02 * s * ol)
	b.add("bark", Kit.paint(Kit.limb(p1, p2, 0.18 * s, 0.05 * s if not snag else 0.15 * s, 5 if lod else 6), C.c(top), C.c(bot), 0.05, r), 0.018 * s * ol)
	# 마른 가지: 위로 휘거나 부러져 짧은 것
	var nb := 0 if snag else (3 if lod else 7)
	for i in nb:
		var t := 0.4 + r.next() * 0.55
		var from := p0.lerp(p1, t * 2) if t < 0.5 else p1.lerp(p2, (t - 0.5) * 2)
		var a := r.next() * TAU
		var L := (0.5 + r.next() * 1.3) * s * (1.2 - t * 0.6)
		var tip := from + Vector3(cos(a) * L, L * (0.2 + r.next() * 0.6), sin(a) * L * 0.6)
		b.add("bark", Kit.paint(Kit.limb(from, tip, 0.06 * s, 0.02 * s, 3 if lod else 4), C.c(top), C.c(bot), 0.05, r), 0.012 * s * ol)
	# 밑동 둘레 이끼 낀 뿌리
	if not lod:
		b.add("rock", Kit.paint(Kit.xf(Kit.lump(0.4 * s, 0, r, 0.3, 0.4), 0, 0, 0), C.c("#8f9468"), C.c("#5d5c4a"), 0.05, r), 0.02)
	return C.result(b, "고사목", [{ type = "circle", x = 0.0, z = 0.0, r = 0.28 * s }], Vector2(2.4 * s, 2.4 * s), not snag, { height = h })
