# 광한루원 연못 — 은하수를 본뜬 동서로 긴 못 + 삼신산 섬 셋(봉래·방장·영주) + 오작교(남북으로 가로지름).
# 1582년 정철이 삼신산을 조성(검색 근거). 못 크기·섬 위치는 현재 광한루원 항공사진 비례로 잡은 가설.
# 원점 = 못 가운데, 물면 높이 y = water_y(기본 0.08, 지형 엔진은 이 자리 땅을 물면보다 낮게 파 둔다).
# 광한루 본루는 따로(gwanghallu.gd) — anchors.gwanghallu 자리(못 북서쪽 둑)에 놓는다.
# 물면은 Kit "water" 키(반투명) + 0.7m 아래 어두운 못 바닥. params: seed, width(110), depth(46), bridge(true), water_y(0.08)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Roof = preload("res://kit/landmark/_roof.gd")

static func outline(W: float, D: float, n: int, seed: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		# 둥근 직사각형(초타원) + 잔물결
		var cx := cos(a); var sz := sin(a)
		var e := 4.0
		var rx := W / 2 * pow(absf(cx), 2.0 / e) * signf(cx)
		var rz := D / 2 * pow(absf(sz), 2.0 / e) * signf(sz)
		var k := 1.0 + Kit.vnoise(cos(a) * 2.3 + seed, sin(a) * 2.3) * 0.05
		p.append(Vector2(rx * k, rz * k))
	return p

static func build(params: Dictionary) -> Dictionary:
	var seed: int = int(params.get("seed", 1))
	var rng := Kit.Rng.new(seed)
	var W: float = float(params.get("width", 110.0))
	var D: float = float(params.get("depth", 46.0))
	var wy: float = float(params.get("water_y", 0.08))
	var b := Kit.Batch.new()
	var n := 56
	var ol := outline(W, D, n, seed)
	# 못 바닥(어두운 진흙, 반투명 물 아래로 비침): 물면보다 0.7m 아래
	var bed := Kit.Geo.new()
	var by := wy - 0.7
	for i in n:
		var a := ol[i]; var c := ol[(i + 1) % n]
		Roof.tri_facing(bed, Vector3(0, by - 0.4, 0), Vector3(a.x, by, a.y), Vector3(c.x, by, c.y), Vector3.UP)
	b.add("flat", Co.pnt(bed, [0x4a5244, 0x3a4236], 0.03, rng), 0.0)
	# 물면: Kit 'water' 키(반투명 물결, UV 1 = 4m). 가운데 짙고 가장자리 옅게(버텍스 색)
	var g := Kit.Geo.new()
	var cdeep := Kit.hex(0x8aa4a2); var cedge := Kit.hex(0xe2ece8)
	var uvs := func(p: Vector3) -> Vector2: return Vector2(p.x / 4.0, p.z / 4.0)
	for i in n:
		var a := ol[i]; var c := ol[(i + 1) % n]
		var A := Vector3(a.x, wy, a.y); var C := Vector3(c.x, wy, c.y)
		var Am := Vector3(a.x * 0.55, wy, a.y * 0.55); var Cm := Vector3(c.x * 0.55, wy, c.y * 0.55)
		var O := Vector3(0, wy, 0)
		var base := g.size()
		Roof.quad_facing(g, Am, Cm, C, A, Vector3.UP, uvs.call(Am), uvs.call(Cm), uvs.call(C), uvs.call(A))
		Roof.tri_facing(g, O, Am, Cm, Vector3.UP, uvs.call(O), uvs.call(Am), uvs.call(Cm))
		for q in range(base, g.size()):
			var rr := Vector2(g.pos[q].x, g.pos[q].z).length() / (Vector2(a.x, a.y).length() + 0.01)
			g.col[q] = cdeep.lerp(cedge, clampf((rr - 0.4) / 0.6, 0, 1))
	b.add("water", g, 0.0)
	# 호안: 낮은 막돌 띠(바깥으로 기울어진 띠 면) + 군데군데 큰 돌
	var bank := Kit.Geo.new()
	for i in n:
		var a := ol[i]; var c := ol[(i + 1) % n]
		var na := a.normalized(); var nc := c.normalized()
		var A0 := Vector3(a.x, wy - 0.8, a.y); var C0 := Vector3(c.x, wy - 0.8, c.y)
		var A1 := Vector3(a.x + na.x * 0.5, 0.35, a.y + na.y * 0.5); var C1 := Vector3(c.x + nc.x * 0.5, 0.35, c.y + nc.y * 0.5)
		var inward := -Vector3((na.x + nc.x) / 2, 0, (na.y + nc.y) / 2)
		Roof.quad_facing(bank, A0, C0, C1, A1, inward + Vector3(0, 0.6, 0))
		var A2 := Vector3(a.x + na.x * 1.4, 0.05, a.y + na.y * 1.4); var C2 := Vector3(c.x + nc.x * 1.4, 0.05, c.y + nc.y * 1.4)
		Roof.quad_facing(bank, A1, C1, C2, A2, Vector3.UP)
	b.add("stone", Co.pnt(bank, [0xb2ab9c, 0x7f796d], 0.06, rng), 0.0)
	var rocks := []
	for i in range(0, n, 2):
		var a := ol[i]; var na := a.normalized()
		var rk := Kit.lump(rng.between(0.35, 0.6), 0, rng, 0.35, 0.6)
		Kit.xf(rk, a.x + na.x * 0.3, 0.25, a.y + na.y * 0.3, 0, rng.next() * 3.0)
		rocks.append(rk)
	b.add("rock", Co.pnt(Kit.merge(rocks), [0xc0b9aa, 0x8d877b], 0.08, rng), 0.025)
	# 삼신산 섬 셋(동쪽 절반에 나란히)
	var isl := [[W * 0.1, -D * 0.1, 7.5, "봉래"], [W * 0.26, D * 0.12, 6.5, "방장"], [W * 0.40, -D * 0.06, 7.0, "영주"]]
	var anchors := {}
	var cols := []
	for it in isl:
		var x: float = it[0]; var z: float = it[1]; var r: float = it[2]
		var mound := Kit.lump(r, 1, rng, 0.12, 0.22)
		Kit.xf(mound, x, wy + 0.1, z)
		b.add("organic", Co.pnt(mound, [0x8a9a5a, 0x6b7448], 0.06, rng), 0.03)
		var rim := []
		for k in 10:
			var a := TAU * k / 10 + rng.next() * 0.3
			var rk := Kit.lump(rng.between(0.35, 0.55), 0, rng, 0.35, 0.6)
			Kit.xf(rk, x + cos(a) * r * 0.95, wy + 0.15, z + sin(a) * r * 0.95, 0, rng.next() * 3.0)
			rim.append(rk)
		b.add("rock", Co.pnt(Kit.merge(rim), [0xc0b9aa, 0x8d877b], 0.08, rng), 0.02)
		for k in 4:
			var a := TAU * k / 4 + rng.next()
			var rr := 0.0 if k == 0 else r * 0.5
			Co.small_tree(b, x + cos(a) * rr, z + sin(a) * rr, rng.between(5.5, 8.5) * (1.2 if k == 0 else 0.85), rng, "needle" if k % 2 == 0 else "leaf")
		anchors["island_" + str(it[3])] = Vector3(x, wy + 1.0, z)
		cols.append({ type = "circle", x = x, z = z, r = r })
	var root := Node3D.new(); root.name = "광한루원_연못"
	root.add_child(b.build("못"))
	var bx := -W * 0.18
	var walks := []
	if params.get("bridge", true):
		var br: Dictionary = load("res://kit/landmark/ojakgyo.gd").build({ seed = seed + 5 })
		var bn: Node3D = br.node
		bn.position = Vector3(bx, wy, 0)
		root.add_child(bn)
		for c in br.colliders:
			cols.append({ type = "box", minX = c.minX + bx, maxX = c.maxX + bx, minZ = c.minZ, maxZ = c.maxZ })
		for w in br.walk:
			var ww: Dictionary = w.duplicate(true)
			ww.minX += bx; ww.maxX += bx
			for i in ww.y.size(): ww.y[i] += wy
			walks.append(ww)
		anchors.ojakgyo_north = Vector3(bx, wy + 0.35, -28.5); anchors.ojakgyo_south = Vector3(bx, wy + 0.35, 28.5); anchors.ojakgyo_mid = Vector3(bx, wy + 2.1, 0)
	anchors.gwanghallu = Vector3(-W * 0.32, 0, -D / 2 - 12.0)
	return {
		node = root, colliders = cols, lights = [], occluder = false,
		footprint = Vector2(W + 3, maxf(D + 3, 58.0)), anchors = anchors,
		water = { y = wy, outline = ol, kind = "pond" },
		walk = walks,
	}
