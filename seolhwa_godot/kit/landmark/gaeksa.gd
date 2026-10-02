# 객사 용성관(龍城館) — 전패(殿牌)를 모신 정당(가운데, 지붕이 한 단 높은 솟을지붕) + 좌우 익헌(사신 숙소, 온돌방+대청).
# 남원 용성관은 조선 객사 가운데 큰 편으로 전해지나 1597 정유재란 소실·중건 뒤 근대에 헐려(터만 남음) 치수 기록을 찾지 못했다.
# 비슷한 대형 객사인 나주 금성관(정당 정면 5칸·측면 4칸, 익헌 각 정면 4칸)을 본떠 정당 5칸으로 둔 것은 가설.
# params: seed, jeongdang_bays(5|3), wings(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var root := Node3D.new(); root.name = "객사_용성관"
	var nb: int = int(params.get("jeongdang_bays", 5))
	var jb := []
	for i in nb: jb.append(3.3 if i != nb / 2 else 3.8)
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var ji := Co.hall(b, r, {
		bays = jb, depth = 10.0, dbays = 4, F = 1.35, H = 4.6, fronts = ["hongsal", "door", "door", "door", "hongsal"] if nb == 5 else ["door", "door", "door"],
		roof = "paljak", ox = 2.1, oz = 1.9, rise = 4.4, lift = 0.8, bracket = "dapo", col_r = 0.26,
		steps = [0.0], step_w = 3.2, roof_nx = 24, roof_nz = 14,
	}, rng)
	# 현판(용성관)
	b.add("wood", Co.pnt(Kit.box(2.8, 0.9, 0.1, 0, ji.top - 0.55, 5.0 + 0.3), [0x3a2c22, 0x2c2018]), 0.012)
	b.add("flat", Co.pnt(Kit.box(2.3, 0.5, 0.04, 0, ji.top - 0.55, 5.0 + 0.36), [0xe8dcb8]), 0.0)
	var jn := Co.node2("정당", b, r)
	root.add_child(jn)
	var JW: float = ji.W
	var cols := [{ type = "box", minX = -JW / 2 - 0.75, maxX = JW / 2 + 0.75, minZ = -5.75, maxZ = 5.6 }]
	var lights := [{ x = 0.0, y = ji.top - 0.2, z = 5.6, kind = "lantern" }]
	var anchors := { jeongdang = Vector3(0, ji.F, 1.0), steps = Vector3(0, 0, 6.8), yard = Vector3(0, 0, 14.0) }
	var total_w := JW + 3.0
	var hide := [jn.get_node("roof")]
	if params.get("wings", true):
		for s in [-1, 1]:
			var wb := Kit.Batch.new(); var wr := Kit.Batch.new()
			var bays := [3.0, 3.0, 3.0, 3.0]
			var fr := ["open", "open", "door", "window"] if s > 0 else ["window", "door", "open", "open"]
			var wi := Co.hall(wb, wr, {
				bays = bays, depth = 8.0, dbays = 3, F = 1.0, H = 3.3, fronts = fr, roof = "paljak", ox = 1.7, oz = 1.6, rise = 2.5, lift = 0.6,
				bracket = "ikgong", col_r = 0.2, steps = [s * -3.0], step_w = 1.8, roof_nx = 18, roof_nz = 12,
			}, rng)
			var wn := Co.node2("익헌_" + ("동" if s > 0 else "서"), wb, wr)
			var wx: float = s * (JW / 2 + wi.W / 2 + 0.3)
			wn.position = Vector3(wx, 0, 0.6)
			root.add_child(wn)
			var WW: float = wi.W
			cols.append({ type = "box", minX = wx - WW / 2 - 0.75, maxX = wx + WW / 2 + 0.75, minZ = -4.15, maxZ = 5.35 })
			lights.append({ x = wx + s * 3.0, y = wi.F + 1.3, z = 4.7, kind = "window" })
			anchors["ikheon_" + ("east" if s > 0 else "west")] = Vector3(wx - s * 3.0, wi.F, 3.0)
			total_w = JW + 2 * WW + 4.0
			hide.append(wn.get_node("roof"))
	return {
		node = root, colliders = cols, lights = lights, occluder = true,
		footprint = Vector2(total_w + 2.0, 14.0), anchors = anchors,
		interior = { minX = -JW / 2, maxX = JW / 2, minZ = -5.0, maxZ = 5.0, floor_y = ji.F, camera = { pitch = 50, distance = 18 }, hide = hide },
	}
