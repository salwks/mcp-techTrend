# 실상사 천왕문 — 정면 3칸·측면 2칸 맞배(가운데 칸 통로, 좌우 칸에 사천왕 — 홍살 너머 어둡게).
# 실상사는 일주문 대신 해탈교를 건너 천왕문으로 든다(검색 근거). 현 천왕문의 건립 연대·규모는 가설.
# params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var D := 5.0
	var info := Co.hall(b, r, {
		bays = [3.0, 3.4, 3.0], depth = D, dbays = 2, F = 0.45, H = 3.4, fronts = ["hongsal", "gate", "hongsal"],
		enclose = true, back = "none", sides = "board", floor = false, roof = "matbae", ox = 1.2, oz = 1.6, rise = 2.6, lift = 0.4,
		bracket = "ikgong", col_r = 0.2, steps = [0.0], step_w = 2.6, roof_nx = 14, roof_nz = 14,
	}, rng)
	var W: float = info.W
	# 사천왕 칸 안쪽 어둠 + 형상(붉고 푸른 덩이)
	for s in [-1, 1]:
		var cx: float = s * (3.4 / 2 + 1.5)
		b.add("flat", Co.pnt(Kit.box(2.8, 3.2, 0.05, cx, info.F + 1.6, -D / 2 + 0.2), Co.DARK), 0.0)
		for k in 2:
			var z := -0.6 if k == 0 else 1.0
			var col := [0x7a3a2e, 0x4a2a22] if (k + (1 if s > 0 else 0)) % 2 == 0 else [0x3e5a6a, 0x2a3a46]
			b.add("organic", Co.pnt(Kit.xf(Kit.lump(0.6, 1, rng, 0.12, 2.4), cx + (k - 0.5) * 1.2, info.F + 1.5, z - 0.4), col), 0.02)
	# 뒷벽: 가운데 통로 칸은 뚫고 좌우 칸만 판벽
	for s in [-1, 1]:
		b.add("wood", Co.pnt(Kit.box(3.0, 3.4, 0.2, s * (3.4 / 2 + 1.5), info.F + 1.7, -D / 2), Co.WOOD, 0.03, rng), 0.02)
	var node := Co.node2("천왕문", b, r)
	return {
		node = node,
		colliders = [{ type = "box", minX = -W / 2 - 0.5, maxX = -1.7, minZ = -D / 2 - 0.4, maxZ = D / 2 + 0.4 }, { type = "box", minX = 1.7, maxX = W / 2 + 0.5, minZ = -D / 2 - 0.4, maxZ = D / 2 + 0.4 }],
		lights = [{ x = -2.0, y = 2.6, z = D / 2 + 0.4, kind = "lantern" }, { x = 2.0, y = 2.6, z = D / 2 + 0.4, kind = "lantern" }],
		occluder = true, footprint = Vector2(info.roof_hw * 2, info.roof_hd * 2),
		anchors = { gate = Vector3(0, 0, 0), outside = Vector3(0, 0, D / 2 + 3.0), inside = Vector3(0, 0, -D / 2 - 2.5) },
	}
