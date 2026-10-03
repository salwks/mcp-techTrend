# 함흥본궁 정전 — 태조 이성계가 왕위에 오르기 전 살던 집 자리(함흥 운전리)에 세운 본궁의 정전. 태조와 4대조 위패를 모심(1870년 제향 중, 고종 때 중수 기록).
# 정면 5칸·측면 3칸 팔작, 앞 낮은 월대(돌난간 없음). 치수는 일제강점기 사진 비례 가설. params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	Hub.woldae(b, rng, 26.0, 18.0, 0.9, 0.0, 0.0, false, [0.0])
	var info := Co.hall(b, r, { bays = [3.4, 3.8, 4.2, 3.8, 3.4], depth = 10.2, dbays = 3, F = 1.0 + 0.9, H = 4.4, fronts = ["wall", "door", "door", "door", "wall"],
		roof = "paljak", ox = 2.0, oz = 1.9, rise = 3.8, lift = 0.8, bracket = "dapo", col_r = 0.26, cz = -2.4, steps = [0.0], step_w = 2.6, roof_nx = 22, roof_nz = 14 }, rng)
	Hub.plaque(b, 0, info.top - 0.5, -2.4 + 5.1 + 0.3, 2.4, 0.8)
	var W: float = info.W
	var n := Co.node2("본궁정전", b, r)
	return {
		node = n, colliders = [{ type = "box", minX = -W / 2 - 0.8, maxX = W / 2 + 0.8, minZ = -8.4, maxZ = 3.6 }], lights = [{ x = 0.0, y = 3.6, z = 3.2, kind = "shrine" }], occluder = true,
		footprint = Vector2(27.0, 19.0), anchors = { woldae = Vector3(0, 0.9, 5.0), front = Vector3(0, 0, 10.5) },
		interior = { minX = -W / 2, maxX = W / 2, minZ = -7.5, maxZ = 2.7, floor_y = 1.9, camera = { pitch = 50, distance = 18 }, hide = [n.get_node("roof")] },
	}
