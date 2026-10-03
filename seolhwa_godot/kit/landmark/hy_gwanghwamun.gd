# 광화문(光化門) — 경복궁 정문. 1395년 창건, 임진왜란 소실 뒤 270여 년 폐허 → 1865~1868년 흥선대원군 중건 → 1870년에는 막 다시 세운 새 문.
# 석축(육축)에 홍예 셋(가운데 조금 큼), 위에 중층 문루(정면 3칸·측면 2칸, 우진각) + 여장. 앞 양쪽에 해태(해치) 돌상 둘(haetae).
# 석축 너비·높이는 실측 근사(약 34×6m — 가설 포함). params: seed, haetae(true)
extends RefCounted

const SM = preload("res://kit/landmark/seongmun.gd")
const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var info := SM.build(Hub.merged({ seed = 1, name = "광화문", open = "none", lu = 2, lu_roof = "ujin", lu_bays = [4.4, 5.4, 4.4], lu_depth = 7.6, lu_H = 3.8,
		bracket = "dapo", width = 32.0, height = 6.0, depth = 12.0, aw = 4.2, spring = 3.0, arch_x = [-7.0, 0.0, 7.0] }, params))
	if params.get("haetae", true):
		var rng := Kit.Rng.new(int(params.get("seed", 1)) + 9)
		var b := Kit.Batch.new()
		for sx in [-1, 1]:
			var x: float = sx * 11.0; var z := 15.0
			b.add("stone", Co.pnt(Kit.box(1.6, 0.9, 2.4, x, 0.45, z), Co.STONE_L, 0.04, rng), 0.02)
			var g := []
			var bd := Kit.lump(1.0, 1, rng, 0.08, 1.0); Kit.xf(bd, x, 1.5, z - 0.1, 0, 0, 0, 0.55, 0.65, 0.9); g.append(bd)
			var hd := Kit.lump(1.0, 1, rng, 0.08, 1.0); Kit.xf(hd, x, 2.35, z + 0.55, 0, 0, 0, 0.45, 0.45, 0.45); g.append(hd)
			for fx in [-1, 1]:
				g.append(Kit.box(0.22, 0.8, 0.22, x + fx * 0.32, 1.25, z + 0.6))
			b.add("stone", Co.pnt(Kit.merge(g), [0xc8c1b0, 0x9e9786], 0.05, rng), 0.02)
			info.colliders.append({ type = "box", minX = x - 0.9, maxX = x + 0.9, minZ = z - 1.3, maxZ = z + 1.3 })
		(info.node as Node3D).add_child(b.build("해태"))
		info.anchors.haetae_w = Vector3(-11, 0, 15); info.anchors.haetae_e = Vector3(11, 0, 15)
		info.footprint = Vector2(34.0, 34.0)
	return info
