# 실상사 약사전(藥師殿) — 통일신라 철제여래좌상(높이 약 2.7m)을 모신 작은 불전. 정면 3칸.
# 측면 칸 수·지붕 형식은 확인 못 해 정면 3칸·측면 2칸 팔작으로 둔 가설. params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var D := 6.0
	var info := Co.hall(b, r, {
		bays = [2.8, 3.4, 2.8], depth = D, dbays = 2, F = 0.8, H = 3.3, fronts = ["door", "door", "door"],
		roof = "paljak", ox = 1.6, oz = 1.6, rise = 2.9, lift = 0.6, bracket = "ikgong", col_r = 0.2,
		steps = [0.0], step_w = 2.0, roof_nx = 20, roof_nz = 14, side_window = false,
	}, rng)
	# 철불(어둡게, 문 사이로 살짝)
	b.add("flat", Co.pnt(Kit.xf(Kit.lump(0.9, 1, rng, 0.08, 1.4), 0, info.F + 1.3, -0.8), [0x4a443e, 0x2e2a26]), 0.0)
	var node := Co.node2("약사전", b, r)
	var bx: float = info.base[0] / 2; var bz: float = info.base[1] / 2
	return {
		node = node, colliders = [{ type = "box", minX = -bx, maxX = bx, minZ = -bz, maxZ = bz }],
		lights = [{ x = 0.0, y = info.F + 1.5, z = D / 2 + 0.1, kind = "window" }],
		occluder = true, footprint = Vector2(info.roof_hw * 2, info.roof_hd * 2),
		anchors = { door = Vector3(0, info.F, D / 2 + 0.3), yard = Vector3(0, 0, bz + 3.0) },
	}
