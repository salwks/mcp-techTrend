# 대관령 국사성황당(國師城隍堂) — 대관령 마루 아래 숲. 범일국사(국사성황)를 모신 성황사 + 산신각, 강릉단오제 때 신목(단풍나무)을 베어 모셔 감.
# 1870년 건물 규모는 기록을 못 찾음 → 정면 1칸 맞배 성황사(지금 건물 비례) + 옆 작은 산신각 + 돌담 + 신목 자리(가설).
# params: seed, sanshingak(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	Co.hall(b, r, { bays = [3.4], depth = 3.2, dbays = 1, F = 0.5, H = 2.5, fronts = ["door"], roof = "matbae", ox = 0.8, oz = 1.1, rise = 1.8, lift = 0.3,
		bracket = "ikgong", col_r = 0.14, steps = [0.0], step_w = 1.4, roof_nx = 10, roof_nz = 10, side_window = false }, rng)
	var cols := [{ type = "box", minX = -2.4, maxX = 2.4, minZ = -2.3, maxZ = 2.6 }]
	var anchors := { shrine = Vector3(0, 0.5, 1.0), front = Vector3(0, 0, 4.0), tree = Vector3(-5.6, 0, 1.2) }
	if params.get("sanshingak", true):
		Co.hall(b, r, { bays = [2.2], depth = 2.2, dbays = 1, F = 0.4, H = 2.0, fronts = ["door"], roof = "matbae", ox = 0.6, oz = 0.9, rise = 1.3, lift = 0.25,
			bracket = "none", col_r = 0.12, cx = 5.2, cz = -1.0, steps = [0.0], step_w = 1.0, roof_nx = 8, roof_nz = 8, side_window = false, col_color = Co.WOOD, band = Co.WOOD }, rng)
		cols.append({ type = "box", minX = 3.7, maxX = 6.7, minZ = -2.6, maxZ = 0.8 })
		anchors.sanshingak = Vector3(5.2, 0, 1.8)
	# 돌담(앞 틈)
	cols.append_array(Co.low_wall_loop(b, [Vector2(-8.0, -4.0), Vector2(8.0, -4.0), Vector2(8.0, 5.0), Vector2(-8.0, 5.0)], [[0.0, 5.0, 1.4]], 1.2, rng, 0.6))
	# 신목(금줄 두른 밑동 + 굵은 줄기만 — 나무 몸은 kit/nature)
	b.add("bark", Co.pnt(Kit.limb(Vector3(-5.6, 0, 1.2), Vector3(-5.5, 3.2, 1.2), 0.45, 0.35, 7), [0x6e5440, 0x4e3a2c]), 0.02)
	b.add("cloth", Co.pnt(Kit.cyl(0.5, 0.5, 0.08, 10, -5.6, 1.4, 1.2), [0xe8e0c8]), 0.0)
	for k in 5:
		b.add("cloth", Co.pnt(Kit.box(0.08, 0.3, 0.02, -5.6 + cos(k * 1.3) * 0.5, 1.2, 1.2 + sin(k * 1.3) * 0.5), [0xf0ead8, 0xa3503a] if k % 2 == 0 else [0xe8e0c8]), 0.0)
	cols.append({ type = "circle", x = -5.6, z = 1.2, r = 0.6 })
	return { node = Co.node2("국사성황당", b, r), colliders = cols, lights = [{ x = 0.0, y = 1.4, z = 1.8, kind = "shrine" }], occluder = false, footprint = Vector2(17.0, 10.0), anchors = anchors }
