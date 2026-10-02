# 실상사 보광전(普光殿) — 주불전. 정면 3칸·측면 2칸, 다포계 맞배지붕(검색 근거). 조선 후기 중건 건물.
# 칸 폭·높이·꽃살문 대신 띠살 분합문은 가설. params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var D := 7.2
	var info := Co.hall(b, r, {
		bays = [3.6, 4.4, 3.6], depth = D, dbays = 2, F = 1.0, H = 3.8, fronts = ["door", "door", "door"],
		roof = "matbae", ox = 1.5, oz = 2.0, rise = 3.6, lift = 0.5, bracket = "dapo", col_r = 0.24,
		steps = [0.0], step_w = 2.6, roof_nx = 16, roof_nz = 16, side_window = false,
	}, rng)
	b.add("wood", Co.pnt(Kit.box(2.2, 0.75, 0.08, 0, info.top + 0.35, D / 2 + 0.45), [0x3a2c22, 0x2c2018]), 0.012)
	b.add("flat", Co.pnt(Kit.box(1.8, 0.42, 0.04, 0, info.top + 0.35, D / 2 + 0.5), [0xd8c690]), 0.0)
	var node := Co.node2("보광전", b, r)
	var bx: float = info.base[0] / 2; var bz: float = info.base[1] / 2
	return {
		node = node, colliders = [{ type = "box", minX = -bx, maxX = bx, minZ = -bz, maxZ = bz }],
		lights = [{ x = 0.0, y = info.F + 1.5, z = D / 2 + 0.1, kind = "window" }],
		occluder = true, footprint = Vector2(info.roof_hw * 2, info.roof_hd * 2),
		anchors = { door = Vector3(0, info.F, D / 2 + 0.3), yard = Vector3(0, 0, bz + 4.0) },
		interior = { minX = -info.W / 2, maxX = info.W / 2, minZ = -D / 2, maxZ = D / 2, floor_y = info.F, camera = { pitch = 50, distance = 14 }, hide = [node.get_node("roof")] },
	}
