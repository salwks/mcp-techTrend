# 구상나무(Abies koreana) — 지리산·한라산 고지대(해발 1,000m 위, 주로 1,300m 이상) 고유종. 층층이 처진 원뿔, 짙은 청록.
# params: seed, s(1), lod(0|1)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")
const COLS := [["#62806a", "#2a3e34"], ["#5a7862", "#283a30"], ["#6b866c", "#304434"]]

# 가장자리가 들쭉날쭉하고 끝이 처진 원뿔 한 층
static func tier(r: Kit.Rng, rad: float, h: float, y: float, seg: int) -> Kit.Geo:
	var g := Kit.Geo.new()
	var ring := []
	for i in seg:
		var a := TAU * i / seg + r.next() * 0.2
		var k := (1.0 if i % 2 == 0 else 0.72) * (0.9 + r.next() * 0.2)
		ring.append(Vector3(sin(a) * rad * k, y - (0.12 * rad if i % 2 == 0 else 0.0), cos(a) * rad * k))
	var tip := Vector3(0, y + h, 0)
	var under := Vector3(0, y + h * 0.15, 0)
	for i in seg:
		var a: Vector3 = ring[i]; var bb: Vector3 = ring[(i + 1) % seg]
		g.tri(a, bb, tip, Vector2(float(i) / seg, 0), Vector2(float(i + 1) / seg, 0), Vector2((i + 0.5) / seg, 1))
		g.tri(bb, a, under, Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.3))
	return g

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var s := float(params.get("s", 1.0))
	var lod := int(params.get("lod", 0))
	var b := Kit.Batch.new()
	var h := (6.0 + r.next() * 2.5) * s
	b.add("bark", Kit.paint(Kit.limb(Vector3(0, -0.3, 0), Vector3((r.next() - 0.5) * 0.2, h * 0.92, 0), 0.2 * s, 0.06 * s, 5), C.c("#7c6a5a"), C.c("#4e4238"), 0.05, r), 0.0 if lod else 0.018 * s)
	var col: Array = C.pick(COLS, r)
	var n := 4 if lod else 6
	for i in n:
		var t := float(i) / (n - 1)
		var rad := lerpf(1.55, 0.45, t) * s * (0.9 + r.next() * 0.2)
		var y := lerpf(0.18, 0.78, t) * h
		var g := tier(r, rad, lerpf(1.3, 1.1, t) * s + (0.6 * s if i == n - 1 else 0.0), y, 8 if lod else 10)
		Kit.xf(g, (r.next() - 0.5) * 0.12 * s, 0, (r.next() - 0.5) * 0.12 * s, 0, r.next() * 3, 0)
		b.add("needle", Kit.paint(g, C.c(col[0]), C.c(col[1]), 0.04, r), 0.0 if lod else 0.03 * s)
	return C.result(b, "구상나무", [{ type = "circle", x = 0.0, z = 0.0, r = 0.24 * s }], Vector2(3.2 * s, 3.2 * s), true, { height = h + 0.8 * s })
