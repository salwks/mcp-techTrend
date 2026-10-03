# 을밀대(乙密臺) — 평양 모란봉 을밀봉 위 대. 6세기 고구려 평양성 북장대 터의 높은 축대(약 11m) 위에 1714년 세운 정자(정면 3칸·측면 2칸 팔작, 사방 트임).
# 축대 높이는 게임용으로 낮춤(6.5m, 가설). 뒤(북)에 돌계단. 정면 +z. params: seed, height(6.5)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")
const S = preload("res://kit/landmark/_seong.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var H: float = float(params.get("height", 6.5))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var tw := 14.0; var td := 11.0
	var bat := 1.2
	# 축대(퇴물림, 네 면 면석)
	var g := Kit.Geo.new()
	var lo := [Vector2(-tw / 2 - bat, td / 2 + bat), Vector2(tw / 2 + bat, td / 2 + bat), Vector2(tw / 2 + bat, -td / 2 - bat), Vector2(-tw / 2 - bat, -td / 2 - bat)]
	var hi := [Vector2(-tw / 2, td / 2), Vector2(tw / 2, td / 2), Vector2(tw / 2, -td / 2), Vector2(-tw / 2, -td / 2)]
	for i in 4:
		var j := (i + 1) % 4
		var mid: Vector2 = ((lo[i] as Vector2) + (lo[j] as Vector2)) / 2
		Co.Roof.quad_facing(g, Vector3(lo[i].x, -0.6, lo[i].y), Vector3(lo[j].x, -0.6, lo[j].y), Vector3(hi[j].x, H, hi[j].y), Vector3(hi[i].x, H, hi[i].y), Vector3(mid.x, 0, mid.y))
	Co.Roof.quad_facing(g, Vector3(hi[0].x, H, hi[0].y), Vector3(hi[1].x, H, hi[1].y), Vector3(hi[2].x, H, hi[2].y), Vector3(hi[3].x, H, hi[3].y), Vector3.UP)
	b.add("stone", Co.pnt(g, Co.SEONG, 0.04, rng), 0.035)
	S.stone_face(b, rng, Vector2(-tw / 2 + 0.3, td / 2 + 0.02), Vector2(tw / 2 - 0.3, td / 2 + 0.02), 0.0, H - 0.1, Vector2(0, 1), bat, 0.6)
	var info := Hub.pavilion(b, r, { bays = [3.2, 3.6, 3.2], depth = 6.4, dbays = 2, F = H + 0.6, H = 3.2, roof = "paljak", ox = 1.8, oz = 1.7, rise = 2.8, lift = 0.8,
		bracket = "ikgong", col_r = 0.22, under = "stone", plinth = false, stair = false, overhang = 0.3, rail_gaps = [["N", 0.0, 0.8]], roof_nx = 18, roof_nz = 12 }, rng)
	b.add("stone", Co.pnt(Kit.box(tw - 0.4, 0.6, td - 0.4, 0, H + 0.3, 0), [0xb8b2a2, 0x948e80], 0.04, rng), 0.02)
	Hub.plaque(b, 0, info.top - 0.4, 3.2 + 0.3, 2.0, 0.65)
	# 뒤 돌계단(북쪽, 축대 비탈 따라)
	var ns := 16
	for k in ns:
		var t := float(k + 1) / ns
		b.add("stone", Co.pnt(Kit.box(2.2, H * t, 0.5, -tw / 2 + 2.0, H * t / 2, -td / 2 - bat * (1.0 - t) - 0.3 - (ns - 1 - k) * 0.45), Co.STONE_L, 0.04, rng), 0.0)
	return {
		node = Co.node2("을밀대", b, r), colliders = [{ type = "box", minX = -tw / 2 - bat, maxX = tw / 2 + bat, minZ = -td / 2 - bat, maxZ = td / 2 + bat }],
		lights = [{ x = 0.0, y = H + 3.5, z = 3.4, kind = "lantern" }], occluder = true, footprint = Vector2(tw + bat * 2 + 1.0, td + bat * 2 + 8.0),
		anchors = { top = Vector3(0, H + 0.6, 0), foot = Vector3(0, 0, td / 2 + bat + 2.0), stair_foot = Vector3(-tw / 2 + 2.0, 0, -td / 2 - bat - 8.0) },
	}
