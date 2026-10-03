# 연광정(練光亭) — 평양 대동강가 덕바위 위 정자. 1670년 중건본. 두 정자(남쪽 큰 채 정면 3칸·측면 3칸 + 북쪽 작은 채 정면 3칸·측면 2칸)를 비스듬히 잇댄 모양, 팔작.
# 강가 바위 축대 위(높이 2m — 가설). 현판 '천하제일강산'. 정면 +z = 강 쪽(배치 때 강을 보게 돌림). params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")
const S = preload("res://kit/landmark/_seong.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var base := 2.0
	# 축대(바위 + 돌 쌓기)
	b.add("stone", Co.pnt(Kit.box(26.0, base + 1.0, 16.0, 1.5, base / 2 - 0.5, -1.0), Co.SEONG, 0.04, rng), 0.03)
	S.stone_face(b, rng, Vector2(-11.5, 7.02), Vector2(14.5, 7.02), -0.5, base, Vector2(0, 1), 0.2, 0.5)
	for k in 5:
		Hub.rock(b, rng, rng.between(-12, 15), 7.5 + rng.next() * 1.5, rng.between(1.2, 2.2), rng.between(0.8, 1.6), rng.between(1.0, 1.8), [0xa8a294, 0x6e695f], 1, 0.35, rng.next() * 3.0)
	var i1 := Hub.pavilion(b, r, { bays = [3.2, 3.6, 3.2], depth = 9.6, dbays = 3, F = base + 0.8, H = 3.4, roof = "paljak", ox = 1.9, oz = 1.8, rise = 3.2, lift = 0.8,
		bracket = "ikgong", col_r = 0.22, cx = -2.5, cz = 0.0, under = "stone", plinth = false, stair = false, rail_gaps = [["E", 0.0, 4.0]], roof_nx = 18, roof_nz = 14 }, rng)
	var i2 := Hub.pavilion(b, r, { bays = [3.0, 3.2, 3.0], depth = 6.4, dbays = 2, F = base + 0.8, H = 3.1, roof = "paljak", ox = 1.7, oz = 1.6, rise = 2.7, lift = 0.75,
		bracket = "ikgong", col_r = 0.2, cx = 7.6, cz = -2.4, under = "stone", plinth = false, stair = false, rail_gaps = [["W", 0.0, 3.0]], roof_nx = 16, roof_nz = 12 }, rng)
	Hub.plaque(b, -2.5, (i1.top as float) - 0.45, 4.8 + 0.3, 3.0, 0.8)
	# 뒤 돌계단(축대 오르기)
	for k in 6:
		b.add("stone", Co.pnt(Kit.box(2.4, base * (k + 1) / 6.0, 0.4, -2.5, base * (k + 1) / 12.0, -9.0 - (5 - k) * 0.4 + 0.2), Co.STONE_L, 0.04, rng), 0.012)
	return {
		node = Co.node2("연광정", b, r), colliders = [{ type = "box", minX = -11.5, maxX = 14.5, minZ = -9.0, maxZ = 7.0 }], lights = [{ x = -2.5, y = base + 3.5, z = 5.2, kind = "lantern" }],
		occluder = true, footprint = Vector2(28.0, 20.0), anchors = { maru = Vector3(-2.5, base + 0.8, 0.0), river_view = Vector3(-2.5, base + 0.8, 4.0), stair = Vector3(-2.5, 0, -12.0) },
		interior = { minX = -7.5, maxX = 11.6, minZ = -5.6, maxZ = 4.8, floor_y = base + 0.8, camera = { pitch = 50, distance = 18 }, hide = [] },
	}
