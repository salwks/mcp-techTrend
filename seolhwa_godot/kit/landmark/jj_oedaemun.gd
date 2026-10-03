# 제주목 관아 외대문(外大門, 진해루 鎭海樓) — 2층 누문, 정면 3칸·측면 2칸 팔작. 아래층 가운데 칸 판문(좌우 칸은 판벽), 위층 계자난간 마루.
# 1870년에 서 있었다(일제강점기 헐림 → 2002 복원). 칸 폭·높이는 복원 건물 비례 가설. 앞에 돌하르방 한 쌍(hareubang). params: seed, hareubang(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")
const DH = preload("res://kit/landmark/jj_dolhareubang.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var bays := [3.0, 3.6, 3.0]
	var lo := Co.hall(b, r, { bays = bays, depth = 5.2, dbays = 2, F = 0.4, H = 3.2, fronts = ["board", "gate", "board"], back = "none", sides = "board",
		floor = false, roof = "none", bracket = "none", col_r = 0.22, steps = [0.0], step_w = 2.8 }, rng)
	var F2: float = lo.top + 0.25
	var info := Hub.pavilion(b, r, { bays = bays, depth = 5.2, dbays = 2, F = F2, H = 2.8, roof = "paljak", ox = 1.7, oz = 1.6, rise = 2.6, lift = 0.7,
		bracket = "ikgong", col_r = 0.2, under = "none", plinth = false, stair = false, overhang = 0.5, rail_gaps = [], roof_nx = 20, roof_nz = 14 }, rng)
	Hub.plaque(b, 0, info.top - 0.4, 2.6 + 0.3, 1.9, 0.62)
	var W: float = info.W
	var root := Co.node2("외대문_진해루", b, r)
	var cols := [{ type = "box", minX = -W / 2 - 0.3, maxX = -1.8, minZ = -2.8, maxZ = 2.8 }, { type = "box", minX = 1.8, maxX = W / 2 + 0.3, minZ = -2.8, maxZ = 2.8 }]
	if params.get("hareubang", true):
		for sx in [-1, 1]:
			var d := DH.build({ seed = int(params.get("seed", 1)) + 7 + sx, hand = "right" if sx > 0 else "left" })
			var n: Node3D = d.node; n.position = Vector3(sx * 2.6, 0, 5.2); root.add_child(n)
			cols.append({ type = "circle", x = sx * 2.6, z = 5.2, r = 0.5 })
	return {
		node = root, colliders = cols, lights = [{ x = -2.2, y = 2.2, z = 3.0, kind = "torch" }, { x = 2.2, y = 2.2, z = 3.0, kind = "torch" }], occluder = true,
		footprint = Vector2(W + 1.6, 9.0), anchors = { outside = Vector3(0, 0, 6.5), inside = Vector3(0, 0, -4.5), upper = Vector3(0, F2, 0) },
	}
