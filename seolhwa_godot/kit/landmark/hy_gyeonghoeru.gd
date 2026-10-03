# 경회루(慶會樓) — 경복궁 서쪽 네모 연못 속 누각. 1412년 창건, 임진왜란 소실(돌기둥만 남음) → 1867년 중건 → 1870년 새 건물.
# 정면 7칸·측면 5칸 팔작, 아래층 돌기둥 48개(바깥 네모 기둥·안 둥근 기둥), 위층 마루 + 계자난간. 섬 둘레 돌 축대, 동쪽 돌다리 셋.
# 연못(실제 약 128×113m)은 압축해 60×52m(가설). 정면 +z(남). params: seed, pond(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")
const S = preload("res://kit/landmark/_seong.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var bays := [4.4, 4.8, 5.0, 5.2, 5.0, 4.8, 4.4]
	var D := 23.0
	var island_h := 1.0
	var F := island_h + 4.4
	# 섬(돌 축대)
	var iw := 40.0; var idp := 31.0
	b.add("stone", Co.pnt(Kit.box(iw, island_h + 1.4, idp, 0, island_h / 2 - 0.7, 0), Co.SEONG, 0.04, rng), 0.03)
	for e in [[Vector2(-iw / 2, idp / 2), Vector2(iw / 2, idp / 2), Vector2(0, 1)], [Vector2(iw / 2, idp / 2), Vector2(iw / 2, -idp / 2), Vector2(1, 0)], [Vector2(-iw / 2, -idp / 2), Vector2(-iw / 2, idp / 2), Vector2(-1, 0)]]:
		S.stone_face(b, rng, e[0] + (e[2] as Vector2) * 0.02, e[1] + (e[2] as Vector2) * 0.02, -0.7, island_h, e[2], 0.0, 0.45)
	b.add("stone", Co.pnt(Kit.box(iw - 0.6, 0.06, idp - 0.6, 0, island_h + 0.02, 0), [0xc2bcae, 0xa8a294], 0.04, rng), 0.0)
	# 누각
	var colx := [-17.3]
	for w in bays: colx.append(colx[-1] + w)
	var sq := []; var rd := []
	for i in colx.size():
		for j in 6:
			var x: float = colx[i]; var z := -D / 2 + D * j / 5
			var outer := i == 0 or i == colx.size() - 1 or j == 0 or j == 5
			if outer: sq.append(Kit.box(0.8, 4.4, 0.8, x, island_h + 2.2, z))
			else: rd.append(Kit.cyl(0.4, 0.42, 4.4, 8, x, island_h + 2.2, z, 0, 0, 0, false))
	b.add("stone", Co.pnt(Kit.merge(sq), [0xc8c1b0, 0xa29b8a], 0.04, rng), 0.02)
	b.add("stone", Co.pnt(Kit.merge(rd), [0xc8c1b0, 0xa29b8a], 0.04, rng), 0.02)
	var info := Hub.pavilion(b, r, { bays = bays, depth = D, dbays = 5, F = F, H = 4.0, roof = "paljak", ox = 2.6, oz = 2.4, rise = 6.0, lift = 1.0,
		bracket = "ikgong", col_r = 0.3, under = "none", plinth = false, stair = false, overhang = 0.8, rail_gaps = [], roof_nx = 28, roof_nz = 18 }, rng)
	Hub.plaque(b, 0, info.top - 0.55, D / 2 + 0.35, 3.0, 1.0)
	var cols := [{ type = "box", minX = -iw / 2, maxX = iw / 2, minZ = -idp / 2, maxZ = idp / 2 }]
	var anchors := { upper = Vector3(0, F, 0), island = Vector3(0, island_h, idp / 2 - 2.0) }
	var out := { node = null, colliders = cols, lights = [{ x = 0.0, y = F + 2.0, z = D / 2 + 0.6, kind = "lantern" }], occluder = true, anchors = anchors }
	if params.get("pond", true):
		var pw := 60.0; var pd := 52.0
		var wl := -0.6
		var wg := Kit.Geo.new()
		wg.quad(Vector3(-pw / 2, wl, pd / 2), Vector3(pw / 2, wl, pd / 2), Vector3(pw / 2, wl, -pd / 2), Vector3(-pw / 2, wl, -pd / 2), Vector2(0, 0), Vector2(pw / 4, 0), Vector2(pw / 4, pd / 4), Vector2(0, pd / 4))
		b.add("water", Kit.paint(wg, Kit.hex(0x6f8e8c), Kit.hex(0x6f8e8c), 0.0), 0.0)
		b.add("flat", Co.pnt(Kit.box(pw, 0.1, pd, 0, -1.4, 0), [0x2e3a34]), 0.0)
		# 못 둘레 돌 호안(낮은 축대 띠)
		for e in [[Vector2(-pw / 2, pd / 2), Vector2(pw / 2, pd / 2)], [Vector2(pw / 2, -pd / 2), Vector2(-pw / 2, -pd / 2)], [Vector2(pw / 2, pd / 2), Vector2(pw / 2, -pd / 2)], [Vector2(-pw / 2, -pd / 2), Vector2(-pw / 2, pd / 2)]]:
			var a: Vector2 = e[0]; var c: Vector2 = e[1]
			var m := (a + c) / 2; var L := a.distance_to(c)
			var ax := absf(a.y - c.y) < 0.01
			b.add("stone", Co.pnt(Kit.box(L + 1.2 if ax else 1.2, 1.5, 1.2 if ax else L + 1.2, m.x, -0.75, m.y), Co.SEONG, 0.04, rng), 0.02)
		# 동쪽 돌다리 셋(섬 → 못가)
		for k in 3:
			var z := -9.0 + k * 9.0
			var bl := pw / 2 - iw / 2
			b.add("stone", Co.pnt(Kit.box(bl, 0.4, 3.2 if k == 1 else 2.4, iw / 2 + bl / 2, island_h - 0.1, z), [0xc8c1b0, 0xa29b8a], 0.04, rng), 0.02)
			for sx in [-1, 1]:
				Hub.stone_rail(b, rng, Vector2(iw / 2, z + sx * (1.5 if k == 1 else 1.1)), Vector2(pw / 2, z + sx * (1.5 if k == 1 else 1.1)), island_h + 0.1, 2.0, 0.7)
		var ol := PackedVector2Array([Vector2(-pw / 2, -pd / 2), Vector2(pw / 2, -pd / 2), Vector2(pw / 2, pd / 2), Vector2(-pw / 2, pd / 2)])
		out.water = { y = wl, outline = ol, kind = "pond", island = PackedVector2Array([Vector2(-iw / 2, -idp / 2), Vector2(iw / 2, -idp / 2), Vector2(iw / 2, idp / 2), Vector2(-iw / 2, idp / 2)]) }
		out.walk = []
		for k in 3:
			var z := -9.0 + k * 9.0
			var hw := 1.3 if k == 1 else 0.9
			out.walk.append({ axis = "x", minX = iw / 2 - 0.5, maxX = pw / 2 + 1.0, minZ = z - hw, maxZ = z + hw, x = [iw / 2 - 0.5, pw / 2 + 1.0], y = [island_h + 0.1, island_h + 0.1] })
		out.walk.append({ minX = -iw / 2 + 0.3, maxX = iw / 2 - 0.3, minZ = -idp / 2 + 0.3, maxZ = idp / 2 - 0.3, z = [-idp / 2 + 0.3, idp / 2 - 0.3], y = [island_h, island_h] })
		out.footprint = Vector2(pw + 2.4, pd + 2.4)
		anchors.east_bank = Vector3(pw / 2 + 2.0, 0, 0)
	else:
		out.footprint = Vector2(iw, idp)
	var n := Co.node2("경회루", b, r)
	out.node = n
	out.interior = { minX = -17.3, maxX = 17.3, minZ = -D / 2, maxZ = D / 2, floor_y = F, camera = { pitch = 52, distance = 24 }, hide = [n.get_node("roof")] }
	return out
