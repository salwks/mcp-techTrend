# 강릉 임영관 삼문(臨瀛館 三門, 국보) — 고려 말 객사 정문. 정면 3칸·측면 2칸 맞배, 주심포, 배흘림 기둥, 칸마다 판문.
# 솟을삼문과 달리 지붕 하나(평삼문). 1870년에도 지금 모습. 칸 폭·높이는 사진 비례 가설. params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var info := Co.hall(b, r, { bays = [3.0, 3.3, 3.0], depth = 5.0, dbays = 2, F = 0.5, H = 3.6, fronts = ["gate", "gate", "gate"], back = "none", sides = "none",
		floor = false, roof = "matbae", ox = 1.0, oz = 1.6, rise = 2.5, lift = 0.35, bracket = "ikgong", col_r = 0.24, base_margin = 0.6,
		steps = [0.0], step_w = 2.6, roof_nx = 14, roof_nz = 12 }, rng)
	# 배흘림 느낌: 기둥 가운데 굵은 띠
	var bg := []
	for x in [-4.65, -1.65, 1.65, 4.65]:
		for z in [2.5, -2.5]:
			bg.append(Kit.cyl(0.27, 0.27, 1.2, 6, x, 0.5 + 1.6, z, 0, 0, 0, false))
	b.add("flat", Co.pnt(Kit.merge(bg), Co.DAN_R, 0.0), 0.0)
	Hub.plaque(b, 0, info.top - 0.4, 2.5 + 0.25, 1.9, 0.62)
	var W: float = info.W
	return {
		node = Co.node2("임영관삼문", b, r), colliders = [
			{ type = "box", minX = -W / 2 - 0.3, maxX = -W / 2 + 0.6, minZ = -2.6, maxZ = 2.6 }, { type = "box", minX = W / 2 - 0.6, maxX = W / 2 + 0.3, minZ = -2.6, maxZ = 2.6 }],
		lights = [{ x = 0.0, y = info.top - 0.3, z = 2.9, kind = "lantern" }], occluder = true, footprint = Vector2(W + 1.2, 6.2),
		anchors = { outside = Vector3(0, 0, 5.0), inside = Vector3(0, 0, -4.5) },
	}
