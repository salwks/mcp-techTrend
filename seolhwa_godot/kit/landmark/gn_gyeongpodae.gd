# 경포대(鏡浦臺) — 경포호 북쪽 언덕의 누정. 1326년 창건, 1508년 지금 자리로, 1745년(영조 21) 중수본이 1870년에 있었다.
# 정면 6칸·측면 5칸 팔작(기둥 48), 마루 안쪽 일부를 한 단 높인 우물마루(득월헌 자리), 낮은 누하. 칸 폭·높이는 사진 비례 가설.
# 정면 +z(호수 쪽은 남쪽으로 봄). params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var bays := [2.5, 2.7, 2.9, 2.9, 2.7, 2.5]
	var info := Hub.pavilion(b, r, { bays = bays, depth = 11.0, dbays = 5, F = 1.3, H = 3.2, roof = "paljak", ox = 2.0, oz = 2.0, rise = 3.8, lift = 0.85,
		bracket = "ikgong", col_r = 0.22, under = "stone", plinth = true, overhang = 0.5, rail_gaps = [["N", 0.0, 0.8]], roof_nx = 24, roof_nz = 16 }, rng)
	var W: float = info.W
	# 안쪽 높인 마루(뒤 가운데 2칸)
	b.add("wood", Co.pnt(Kit.box(5.8, 0.35, 4.4, 0, 1.3 + 0.17, -2.4), Co.WOOD_L, 0.03, rng), 0.015)
	Hub.plaque(b, 0, info.top - 0.45, 5.5 + 0.25, 2.4, 0.8)
	return {
		node = Co.node2("경포대", b, r), colliders = [{ type = "box", minX = -W / 2 - 1.0, maxX = W / 2 + 1.0, minZ = -6.5, maxZ = 6.5 }],
		lights = [{ x = 0.0, y = info.top - 0.3, z = 5.5, kind = "lantern" }], occluder = true, footprint = Vector2(W + 2.4, 14.0),
		anchors = { maru = Vector3(0, 1.3, 1.0), view = Vector3(0, 1.3, 5.0), stair = Vector3(0, 0, -8.5) },
		interior = { minX = -W / 2, maxX = W / 2, minZ = -5.5, maxZ = 5.5, floor_y = 1.3, camera = { pitch = 50, distance = 18 }, hide = [] },
	}
