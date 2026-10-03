# 관덕정(觀德亭, 보물) — 제주목 관아 앞 활쏘기·열무 정자. 1448년(세종 30) 창건, 여러 번 중수(1690·1882 등). 정면 5칸·측면 4칸 팔작, 사방 트임,
# 낮은 기단. 지금 처마는 1924년 일제가 잘라 짧아진 것 → 1870년 기준 처마를 길게(ox 2.6). 앞에 돌하르방 한 쌍(관아 앞 — 위치 가설).
# 칸 폭·높이는 사진 비례 가설. params: seed, hareubang(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")
const DH = preload("res://kit/landmark/jj_dolhareubang.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var bays := [3.4, 3.7, 4.0, 3.7, 3.4]
	var info := Hub.pavilion(b, r, { bays = bays, depth = 12.6, dbays = 4, F = 0.75, H = 4.4, roof = "paljak", ox = 2.7, oz = 2.6, rise = 4.6, lift = 0.75,
		bracket = "ikgong", col_r = 0.28, under = "none", plinth = false, rail = false, stair = false, roof_nx = 26, roof_nz = 16, overhang = 0.0 }, rng)
	var W: float = info.W
	Co.platform(b, W + 1.6, 12.6 + 1.6, 0.75, rng, 0.0, [0.0], 3.0)
	Hub.plaque(b, 0, info.top - 0.5, 6.3 + 0.3, 2.6, 0.85)
	var root := Co.node2("관덕정", b, r)
	var cols := []
	for x in [-W / 2, -W / 2 + 3.4, -W / 2 + 7.1, W / 2 - 7.1, W / 2 - 3.4, W / 2]:
		for z in [-6.3, 6.3]: cols.append({ type = "circle", x = x, z = z, r = 0.4 })
	if params.get("hareubang", true):
		for sx in [-1, 1]:
			var d := DH.build({ seed = int(params.get("seed", 1)) + 5 + sx, hand = "right" if sx > 0 else "left" })
			var n: Node3D = d.node
			n.position = Vector3(sx * 3.2, 0, 10.4)
			root.add_child(n)
			cols.append({ type = "circle", x = sx * 3.2, z = 10.4, r = 0.5 })
	return {
		node = root, colliders = cols, lights = [{ x = 0.0, y = info.top - 0.3, z = 6.5, kind = "lantern" }], occluder = true,
		footprint = Vector2(W + 6.0, 24.0), anchors = { maru = Vector3(0, 0.75, 0), front = Vector3(0, 0, 12.5) },
		interior = { minX = -W / 2, maxX = W / 2, minZ = -6.3, maxZ = 6.3, floor_y = 0.75, camera = { pitch = 50, distance = 20 }, hide = [root.get_node("roof")] },
	}
