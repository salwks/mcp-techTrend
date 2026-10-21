# 소나무(적송) — 웹 vegetation.js pine 이식: 휘어진 붉은 줄기 + 납작한 우산 솔잎 뭉치(민화식)
# params: seed, s(크기 배율, 1), lod(0 기본 / 1 원거리)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")
const Khs := preload("res://kit/nature/khs_trees.gd")
const LEAF := [["#6c8256", "#2c3a2a"], ["#617a52", "#283728"], ["#77885a", "#334230"]]   # integ-mountain: 산 솔잎은 짙고 푸르스름하게

# 솔잎 뭉치: 납작한 타원체(윗면 밝고 아랫면 짙은 바림) + 위에 작은 덩이
static func needle_clump(b: Kit.Batch, r: Kit.Rng, cx: float, cy: float, cz: float, rad: float, col: Array, lod: int, s: float, sy := 0.34) -> void:
	var g := C.sphere(rad, 6 if lod else 8, 3)
	Kit.xf(g, cx, cy, cz, (r.next() - 0.5) * 0.12, r.next() * 3, (r.next() - 0.5) * 0.12, 1, sy, 0.78)
	b.add("needle", Kit.paint(g, C.c(col[0]), C.c(col[1]), 0.03, r), 0.0 if lod else 0.045 * s)
	if not lod and rad > 1.2 * s:
		var g2 := C.sphere(rad * 0.6, 6, 2)
		Kit.xf(g2, cx + (r.next() - 0.5) * rad * 0.4, cy + rad * 0.22, cz, 0, r.next() * 3, 0, 1, 0.34, 0.8)
		b.add("needle", Kit.paint(g2, C.c(col[0]), C.c(col[0]), 0.03, r), 0.035 * s)

# trees-khs: 배치한 소나무(나정 솔숲 등)는 국가유산청 곰솔 스캔 메시로 — 줄기 충돌 원은 예전과 같다(0.3 × s).
#   흩뿌리기는 이 build()를 쓰지 않는다(scatter.gd KHS_KINDS). params.proc = true 이면 예전 덩이 소나무
static func build(params: Dictionary) -> Dictionary:
	if Khs.available() and not params.get("proc", false) and int(params.get("lod", 0)) == 0:
		return _build_khs(params)
	return _build_proc(params)

static func _build_khs(params: Dictionary) -> Dictionary:
	Khs.init()
	var seed := int(params.get("seed", 1))
	var s := float(params.get("s", 1.0))
	var layer: int = [Khs.L_A, Khs.L_C, Khs.L_B, Khs.L_A][absi(seed) % 4]
	var h := (8.5 + float(absi(seed * 7) % 9) * 0.5) * s * (0.8 if layer == Khs.L_B else 1.0)
	var k := h / Khs.height(layer)
	var root := Node3D.new()
	root.name = "소나무"
	var ry := float(absi(seed * 13) % 360) * PI / 180.0
	for lod in 2:
		var mi := MeshInstance3D.new()
		mi.name = "lod%d" % lod
		mi.mesh = Khs.mesh(layer, lod, "st")
		mi.transform = Transform3D(Basis(Vector3.UP, ry).scaled(Vector3(k, k, k)), Vector3.ZERO)
		if lod == 0:
			mi.visibility_range_end = 32.0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mi.visibility_range_end = 80.0   # 그림자 전용(LOD1)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		root.add_child(mi)
	var far := MeshInstance3D.new()
	far.name = "lod1_far"
	far.mesh = Khs.mesh(layer, 1, "st")
	far.transform = (root.get_child(1) as MeshInstance3D).transform
	far.visibility_range_begin = 32.0
	far.visibility_range_end = 600.0
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(far)
	var ext := 5.0 * k
	return { node = root, mesh = far.mesh, colliders = [{ type = "circle", x = 0.0, z = 0.0, r = 0.3 * s }], lights = [], occluder = false,
		footprint = Vector2(ext * 2, ext * 2), anchors = {}, tris = 0, height = h }

static func _build_proc(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var s := float(params.get("s", 1.0))
	var lod := int(params.get("lod", 0))
	var b := Kit.Batch.new()
	# integ-mountain: 산 소나무는 키가 크고(6~11m) 모양이 여러 가지 — 곧게 자라 층층이 덩이가 달린 것(숲 속) / 휘어 우산처럼 퍼진 것(능선·숲 가)
	var upright := r.next() < 0.55
	var h := ((6.5 + r.next() * 4.5) if upright else (4.8 + r.next() * 3.4)) * s
	var pts := [Vector3(0, -0.3, 0)]
	var x := 0.0; var z := 0.0
	var lean := (r.next() - 0.5) * (0.5 if upright else 1.4) * s
	for i in range(1, 5):
		x += lean * 0.3 + (r.next() - 0.5) * 0.7 * s; z += (r.next() - 0.5) * 0.35 * s
		pts.append(Vector3(x, h * i / 4.0, z))
	for i in 4:
		b.add("bark", Kit.paint(C.limb_open(pts[i], pts[i + 1], (0.24 - i * 0.045) * s, (0.2 - i * 0.045) * s, 5 if lod else 6), C.c("#a8694a" if i >= 2 else "#86644f"), C.c("#5e4436"), 0.04, r), 0.0 if lod else 0.02 * s)
	var col: Array = C.pick(LEAF, r)
	var top: Vector3 = pts[4]
	var clumps := [[top.x, top.y + 0.15 * s, top.z, (1.5 if upright else 1.55) * s]]
	var nb := ((3 + int(r.next() * 2)) if lod else (6 + int(r.next() * 3))) if upright else ((1 + int(r.next() * 2)) if lod else (2 + int(r.next() * 2)))
	for i in nb:
		var t := (0.6 + 0.36 * (float(i) + r.next() * 0.6) / float(nb)) if upright else (0.5 + r.next() * 0.35)
		var bi := mini(3, int(t * 4))
		var from: Vector3 = (pts[bi] as Vector3).lerp(pts[bi + 1], t * 4 - bi)
		var a := r.next() * TAU
		var L := ((0.6 + r.next() * 0.9) * (1.3 - t * 0.6) if upright else (1.3 + r.next() * 1.1)) * s
		var tip := Vector3(from.x + cos(a) * L, from.y + 0.35 * s, from.z + sin(a) * L * 0.6)
		if not lod: b.add("bark", Kit.paint(C.limb_open(from, tip, 0.07 * s, 0.04 * s, 4), C.c("#9a6244"), C.c("#7a4e38"), 0.05, r), 0.0)
		clumps.append([tip.x, tip.y + 0.1 * s, tip.z, ((1.15 + r.next() * 0.5) if upright else (0.95 + r.next() * 0.5)) * s])
	var ext := 0.0
	for cl in clumps:
		needle_clump(b, r, cl[0], cl[1], cl[2], cl[3], col, lod, s, 0.68 if upright else 0.34)   # 곧은 소나무: 덩이가 두툼하게 겹쳐 한 수관으로
		ext = maxf(ext, maxf(absf(cl[0]), absf(cl[2])) + cl[3])
	return C.result(b, "소나무", [{ type = "circle", x = 0.0, z = 0.0, r = 0.3 * s }], Vector2(ext * 2, ext * 2), true, { height = h + 0.6 * s })
