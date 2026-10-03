# 부벽루(浮碧樓) — 평양 모란봉 동쪽 청류벽 위, 영명사 부속 누각. 1614년 중건본. 정면 5칸·측면 3칸 팔작, 사방 트인 마루, 낮은 돌 기단.
# 대동강을 내려다봄(정면 +z = 강 쪽). 치수는 사진 비례 가설. params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var info := Hub.pavilion(b, r, { bays = [3.2, 3.5, 3.8, 3.5, 3.2], depth = 9.6, dbays = 3, F = 1.0, H = 3.6, roof = "paljak", ox = 2.1, oz = 2.0, rise = 3.6, lift = 0.85,
		bracket = "ikgong", col_r = 0.24, under = "stone", plinth = true, overhang = 0.4, rail_gaps = [["N", 0.0, 0.8]], roof_nx = 22, roof_nz = 14 }, rng)
	var W: float = info.W
	Hub.plaque(b, 0, info.top - 0.45, 4.8 + 0.3, 2.4, 0.8)
	return {
		node = Co.node2("부벽루", b, r), colliders = [{ type = "box", minX = -W / 2 - 1.0, maxX = W / 2 + 1.0, minZ = -5.8, maxZ = 5.8 }],
		lights = [{ x = 0.0, y = info.top - 0.3, z = 5.0, kind = "lantern" }], occluder = true, footprint = Vector2(W + 2.4, 13.0),
		anchors = { maru = Vector3(0, 1.0, 0), river_view = Vector3(0, 1.0, 4.4), stair = Vector3(0, 0, -7.5) },
		interior = { minX = -W / 2, maxX = W / 2, minZ = -4.8, maxZ = 4.8, floor_y = 1.0, camera = { pitch = 50, distance = 18 }, hide = [] },
	}
