# 곧게 선 소나무(층층 뭉치) — 웹 vegetation.js fir 이식(숲 밀도용 변종, 이름은 웹을 따름)
# params: seed, s, lod
extends RefCounted
const C := preload("res://kit/nature/_common.gd")
const Pine := preload("res://kit/nature/pine.gd")

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var s := float(params.get("s", 1.0))
	var lod := int(params.get("lod", 0))
	var b := Kit.Batch.new()
	var h := (5.5 + r.next() * 2.5) * s
	b.add("bark", Kit.paint(C.limb_open(Vector3(0, -0.3, 0), Vector3((r.next() - 0.5) * 0.4, h * 0.85, 0), 0.2 * s, 0.1 * s, 5), C.c("#a8694a"), C.c("#7a4e38"), 0.05, r), 0.0 if lod else 0.018 * s)
	var col: Array = C.pick(Pine.LEAF, r)
	var tiers := 2 + int(r.next() * 2)
	if not lod: tiers += 1
	for i in tiers:
		var rad := (1.5 - i * 0.3) * s * (0.8 + r.next() * 0.4)
		var side := (1 if i % 2 else -1) * (0.3 + r.next() * 0.5) * s
		# 웹은 lod=1로 그렸다(먹선 없음). 가까이선 먹선을 얇게 넣어 소나무와 어울리게
		var g := C.sphere(rad, 6 if lod else 7, 3)
		Kit.xf(g, side, h * (0.5 + i * 0.2), (r.next() - 0.5) * 0.4 * s, (r.next() - 0.5) * 0.12, r.next() * 3, (r.next() - 0.5) * 0.12, 1, 0.34, 0.78)
		b.add("needle", Kit.paint(g, C.c(col[0]), C.c(col[1]), 0.03, r), 0.0 if lod else 0.035 * s)
	return C.result(b, "곧은소나무", [{ type = "circle", x = 0.0, z = 0.0, r = 0.25 * s }], Vector2(3.4 * s, 3.4 * s), true, { height = h + 0.5 * s })
