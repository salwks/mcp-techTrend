# 객사 용성관(龍城館) — 전패(殿牌)를 모신 정당(가운데, 지붕이 한 단 높은 솟을지붕) + 좌우 익헌(사신 숙소, 온돌방+대청).
# 디지털남원문화대전 「용성관지」: 691년 처음 세움(휼민관), 1620 최여립 중건, 1680~1690 정동설·정협 때 정당 완성 → 1870년에 서 있었다.
# 6·25 때 폭격으로 소실, 지금은 용성초등학교 안에 길이 약 70m 돌 기단·도깨비 얼굴 새긴 소맷돌 돌계단·석물 29점이 남음.
# → 전체 길이(정당+좌우 익헌 기단)를 약 64~70m로 맞췄다(확정: 전체 길이 / 가설: 칸 수·칸 폭·높이 — 나주 금성관 비례).
# params: seed, jeongdang_bays(5|3), wing_bays(6), wings(true), name("용성관": 노드 이름·현판 — 다른 고을 객사로 쓸 때)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var root := Node3D.new(); root.name = "객사_" + str(params.get("name", "용성관"))
	var nb: int = int(params.get("jeongdang_bays", 5))
	var jb := []
	for i in nb: jb.append(4.0 if i != nb / 2 else 4.4)
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var ji := Co.hall(b, r, {
		bays = jb, depth = 10.0, dbays = 4, F = 1.35, H = 4.6, fronts = ["hongsal", "door", "door", "door", "hongsal"] if nb == 5 else ["door", "door", "door"],
		roof = "paljak", ox = 2.1, oz = 1.9, rise = 4.4, lift = 0.8, bracket = "dapo", col_r = 0.26,
		steps = [0.0], step_w = 3.2, roof_nx = 22, roof_nz = 12,
	}, rng)
	# 정당 앞 돌계단 소맷돌(도깨비 얼굴 새김 — 끝에 어두운 얼굴판)
	for sx in [-1, 1]:
		var sm := Kit.box(0.4, 0.45, 2.4)
		Kit.xf(sm, sx * 1.8, ji.F * 0.55, 5.75 + 1.05, atan2(ji.F, 2.4), 0, 0)
		b.add("stone", Co.pnt(sm, Co.STONE_L, 0.04, rng), 0.02)
		b.add("stone", Co.pnt(Kit.box(0.42, 0.5, 0.3, sx * 1.8, 0.25, 5.75 + 2.3), [0xc4beb0, 0xa29c8e], 0.04, rng), 0.015)
		b.add("flat", Co.pnt(Co.vplane(0.26, 0.26, sx * 1.8, 0.27, 5.75 + 2.46), [0x6a645a]), 0.0)
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
			var nw: int = int(params.get("wing_bays", 6))
			var bays := []
			for k in nw: bays.append(3.4)
			var fr := []
			for k in nw: fr.append("open" if k < 2 else ("door" if k < nw - 1 else "window"))
			if s < 0: fr.reverse()
			var wi := Co.hall(wb, wr, {
				bays = bays, depth = 8.0, dbays = 3, F = 1.0, H = 3.3, fronts = fr, roof = "paljak", ox = 1.7, oz = 1.6, rise = 2.5, lift = 0.6,
				bracket = "ikgong", col_r = 0.2, steps = [s * -3.4], step_w = 1.8, roof_nx = 16, roof_nz = 10,
			}, rng)
			var wn := Co.node2("익헌_" + ("동" if s > 0 else "서"), wb, wr)
			var wx: float = s * (JW / 2 + wi.W / 2 + 0.3)
			wn.position = Vector3(wx, 0, 0.6)
			root.add_child(wn)
			var WW: float = wi.W
			cols.append({ type = "box", minX = wx - WW / 2 - 0.75, maxX = wx + WW / 2 + 0.75, minZ = -4.15, maxZ = 5.35 })
			lights.append({ x = wx + s * 5.0, y = wi.F + 1.3, z = 4.7, kind = "window" })
			anchors["ikheon_" + ("east" if s > 0 else "west")] = Vector3(wx - s * 3.0, wi.F, 3.0)
			total_w = JW + 2 * WW + 4.0
			hide.append(wn.get_node("roof"))
	return {
		node = root, colliders = cols, lights = lights, occluder = true,
		footprint = Vector2(total_w + 2.0, 14.0), anchors = anchors,
		interior = { minX = -JW / 2, maxX = JW / 2, minZ = -5.0, maxZ = 5.0, floor_y = ji.F, camera = { pitch = 50, distance = 18 }, hide = hide },
	}
