# 불국사 대웅전 — 1765년(영조 41) 중창, 정면 5칸·측면 5칸 다포 팔작(현존 규모). 1870년 무렵 절 전체가 퇴락(회랑 무너짐)했으나
# 대웅전은 서 있었다 → 단청을 바랜 색으로(fade=true). 기단 높이·칸 폭은 사진 비례 가설. params: seed, fade(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var fade: bool = params.get("fade", true)
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var info := Co.hall(b, r, {
		bays = [3.0, 3.3, 3.8, 3.3, 3.0], depth = 13.5, dbays = 5, F = 1.3, H = 4.6, fronts = ["door", "door", "door", "door", "door"],
		roof = "paljak", ox = 2.2, oz = 2.0, rise = 5.2, lift = 0.85, bracket = "dapo", col_r = 0.27, steps = [0.0], step_w = 3.0,
		col_color = Hub.FADED_R if fade else Co.DAN_R, band = Hub.FADED_G if fade else Co.DAN_G, roof_nx = 22, roof_nz = 14,
	}, rng)
	Hub.plaque(b, 0, info.top - 0.6, 6.75 + 0.3, 2.4, 0.9)
	var n := Co.node2("대웅전", b, r)
	var W: float = info.W
	return {
		node = n, colliders = [{ type = "box", minX = -W / 2 - 0.75, maxX = W / 2 + 0.75, minZ = -7.5, maxZ = 7.6 }],
		lights = [{ x = 0.0, y = info.F + 1.4, z = 6.8, kind = "window" }], occluder = true, footprint = Vector2(W + 2, 16.5),
		anchors = { front = Vector3(0, 0, 9.5), inside = Vector3(0, info.F, 2.0) },
		interior = { minX = -W / 2, maxX = W / 2, minZ = -6.75, maxZ = 6.75, floor_y = info.F, camera = { pitch = 50, distance = 18 }, hide = [n.get_node("roof")] },
	}
