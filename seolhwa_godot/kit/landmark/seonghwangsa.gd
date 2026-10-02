# 성황사(城隍祠) — 고을 수호신(성황신)을 모신 작은 사당. 정면 1칸 맞배(가설), 낮은 담 + 앞 협문 틈 + 홍살문,
# 옆에 신목(당산나무) 자리 anchors.tree(나무는 kit/nature가 심는다; tree_stub=true면 금줄 두른 밑동만). params: seed, tree_stub(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var info := Co.hall(b, r, { bays = [3.0], depth = 2.8, dbays = 1, F = 0.6, H = 2.4, fronts = ["door"],
		roof = "matbae", ox = 0.9, oz = 1.1, rise = 1.6, lift = 0.3, bracket = "ikgong", col_r = 0.13, steps = [0.0], step_w = 1.2,
		roof_nx = 8, roof_nz = 10, side_window = false, cz = -2.0 }, rng)
	var hw := 7.0; var hd := 6.5
	var cols := [{ type = "box", minX = -2.3, maxX = 2.3, minZ = -4.2, maxZ = 0.2 }]
	cols.append_array(Co.low_wall_loop(b, [Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)], [[0.0, hd, 1.2]], 1.5, rng, 0.45))
	Co.hongsal_gate(b, 0.0, hd + 3.0, 3.6, 4.6)
	var tree := Vector3(hw + 3.5, 0, 1.0)
	if params.get("tree_stub", true):
		b.add("bark", Co.pnt(Kit.cyl(0.55, 0.7, 1.4, 8, tree.x, 0.7, tree.z), [0x7a5a40, 0x5a4230]), 0.02)
		# 금줄(새끼줄 + 흰 종이)
		b.add("thatch", Co.pnt(Kit.cyl(0.62, 0.62, 0.08, 10, tree.x, 1.1, tree.z), [0xd8c79a]), 0.0)
		for i in 6:
			var a := TAU * i / 6
			var q := Co.vplane(0.1, 0.25, 0, 0, 0); Kit.xf(q, tree.x + sin(a) * 0.64, 0.95, tree.z + cos(a) * 0.64, 0, a)
			b.add("cloth", Co.pnt(q, [0xf4efe2]), 0.0)
		cols.append({ type = "circle", x = tree.x, z = tree.z, r = 0.8 })
	return {
		node = Co.node2("성황사", b, r), colliders = cols,
		lights = [{ x = 0.0, y = info.F + 1.2, z = -0.5, kind = "shrine" }], occluder = false,
		footprint = Vector2(hw * 2 + 6, hd * 2 + 5), anchors = { shrine_door = Vector3(0, info.F, -0.5), gate = Vector3(0, 0, hd + 3.0), tree = tree, outside = Vector3(0, 0, hd + 5.0) },
	}
