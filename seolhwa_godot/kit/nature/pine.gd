# 소나무(적송) — 웹 vegetation.js pine 이식: 휘어진 붉은 줄기 + 납작한 우산 솔잎 뭉치(민화식)
# params: seed, s(크기 배율, 1), lod(0 기본 / 1 원거리)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")
const LEAF := [["#7d9160", "#34432f"], ["#708a5a", "#2f3e2c"], ["#8a9866", "#3d4c35"]]

# 솔잎 뭉치: 납작한 타원체(윗면 밝고 아랫면 짙은 바림) + 위에 작은 덩이
static func needle_clump(b: Kit.Batch, r: Kit.Rng, cx: float, cy: float, cz: float, rad: float, col: Array, lod: int, s: float) -> void:
	var g := C.sphere(rad, 6 if lod else 8, 3)
	Kit.xf(g, cx, cy, cz, (r.next() - 0.5) * 0.12, r.next() * 3, (r.next() - 0.5) * 0.12, 1, 0.34, 0.78)
	b.add("needle", Kit.paint(g, C.c(col[0]), C.c(col[1]), 0.03, r), 0.0 if lod else 0.045 * s)
	if not lod and rad > 1.2 * s:
		var g2 := C.sphere(rad * 0.6, 6, 2)
		Kit.xf(g2, cx + (r.next() - 0.5) * rad * 0.4, cy + rad * 0.22, cz, 0, r.next() * 3, 0, 1, 0.34, 0.8)
		b.add("needle", Kit.paint(g2, C.c(col[0]), C.c(col[0]), 0.03, r), 0.035 * s)

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var s := float(params.get("s", 1.0))
	var lod := int(params.get("lod", 0))
	var b := Kit.Batch.new()
	var h := (4.5 + r.next() * 3) * s
	var pts := [Vector3(0, -0.3, 0)]
	var x := 0.0; var z := 0.0
	var lean := (r.next() - 0.5) * 1.4 * s
	for i in range(1, 5):
		x += lean * 0.3 + (r.next() - 0.5) * 0.7 * s; z += (r.next() - 0.5) * 0.35 * s
		pts.append(Vector3(x, h * i / 4.0, z))
	for i in 4:
		b.add("bark", Kit.paint(C.limb_open(pts[i], pts[i + 1], (0.24 - i * 0.045) * s, (0.2 - i * 0.045) * s, 5 if lod else 6), C.c("#b8744c"), C.c("#7a4e38"), 0.04, r), 0.0 if lod else 0.02 * s)
	var col: Array = C.pick(LEAF, r)
	var top: Vector3 = pts[4]
	var clumps := [[top.x, top.y + 0.15 * s, top.z, 1.55 * s]]
	var nb := (1 + int(r.next() * 2)) if lod else (2 + int(r.next() * 2))
	for i in nb:
		var t := 0.5 + r.next() * 0.35
		var bi := mini(3, int(t * 4))
		var from: Vector3 = (pts[bi] as Vector3).lerp(pts[bi + 1], t * 4 - bi)
		var a := r.next() * TAU
		var L := (1.3 + r.next() * 1.1) * s
		var tip := Vector3(from.x + cos(a) * L, from.y + 0.35 * s, from.z + sin(a) * L * 0.6)
		if not lod: b.add("bark", Kit.paint(C.limb_open(from, tip, 0.07 * s, 0.04 * s, 4), C.c("#9a6244"), C.c("#7a4e38"), 0.05, r), 0.0)
		clumps.append([tip.x, tip.y + 0.1 * s, tip.z, (0.95 + r.next() * 0.5) * s])
	var ext := 0.0
	for cl in clumps:
		needle_clump(b, r, cl[0], cl[1], cl[2], cl[3], col, lod, s)
		ext = maxf(ext, maxf(absf(cl[0]), absf(cl[2])) + cl[3])
	return C.result(b, "소나무", [{ type = "circle", x = 0.0, z = 0.0, r = 0.3 * s }], Vector2(ext * 2, ext * 2), true, { height = h + 0.6 * s })
