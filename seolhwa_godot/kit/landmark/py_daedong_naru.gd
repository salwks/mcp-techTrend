# 대동강 나루 표지 — 평양 대동문 앞 강가 나루터. 물로 내려가는 돌계단 선창 + 나무 잔교 + 배 매는 말뚝 + 나루 표지 장대(깃발)·표지석.
# 『평양성도』의 대동문 앞 나루 모습을 단순화한 가설. 원점 = 강둑 가장자리 바닥, 정면 +z = 물 쪽(물면 y −1.2 가정). params: seed, pier(8)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	var wy := -1.2
	# 돌계단 선창(둑에서 물까지)
	for k in 6:
		var y := -0.2 * (k + 1)
		b.add("stone", Co.pnt(Kit.box(6.0, 0.4, 0.6, 0, y + 0.0, 0.3 + k * 0.6), Co.SEONG, 0.04, rng), 0.015)
	for s in [-1, 1]:
		b.add("stone", Co.pnt(Kit.box(1.0, 1.6, 4.2, s * 3.5, -0.6, 1.8), Co.SEONG, 0.04, rng), 0.02)
	# 나무 잔교
	var pl: float = float(params.get("pier", 8.0))
	var z0 := 3.8
	var pg := []; var dg := []
	var n := roundi(pl / 2.0)
	for i in n + 1:
		var z := z0 + pl * i / n
		for sx in [-1, 1]: pg.append(Kit.cyl(0.12, 0.13, 2.6, 6, sx * 1.0, wy - 0.6 + 1.3 - 0.4, z))

	b.add("wood", Co.pnt(Kit.merge(pg), [0x6a5038, 0x4a3828], 0.04, rng), 0.012)
	b.add("wood", Co.pnt(Kit.box(2.4, 0.12, pl + 0.4, 0, wy + 0.65, z0 + pl / 2), [0x9a7852, 0x7a5c3e], 0.04, rng), 0.012)
	# 배 매는 말뚝 + 밧줄 고리
	for p in [Vector2(-2.6, 3.2), Vector2(2.6, 3.2), Vector2(1.5, z0 + pl)]:
		b.add("wood", Co.pnt(Kit.cyl(0.14, 0.16, 1.4, 6, p.x, wy + 1.0 if p.y > 4 else 0.5 - 0.6, p.y), [0x5a4532], 0.04, rng), 0.012)
	# 나루 표지 장대 + 깃발 + 표지석
	b.add("wood", Co.pnt(Kit.cyl(0.08, 0.1, 6.0, 6, -4.4, 3.0, -1.0), [0x6a5038], 0.03, rng), 0.012)
	b.add("cloth", Co.pnt(Kit.box(0.04, 1.0, 1.4, -4.4, 5.3, -0.25), [0xe8e0c8, 0xa3503a]), 0.0)
	Hub.stele(b, rng, 4.6, -1.2, 1.1, 0.5, false, 0.0)
	return {
		node = b.build("대동강나루"), colliders = [{ type = "box", minX = -4.2, maxX = -2.9, minZ = 0.0, maxZ = 4.0 }, { type = "box", minX = 2.9, maxX = 4.2, minZ = 0.0, maxZ = 4.0 }, { type = "circle", x = 4.6, z = -1.2, r = 0.6 }],
		lights = [{ x = -4.4, y = 2.0, z = -0.8, kind = "torch" }], occluder = false, footprint = Vector2(10.0, z0 + pl + 3.0),
		anchors = { landing = Vector3(0, -1.0, 3.2), pier_end = Vector3(0, wy + 0.7, z0 + pl), sign = Vector3(-4.4, 0, 0.0) },
		walk = [{ minX = -2.9, maxX = 2.9, minZ = 0.0, maxZ = 3.8, z = [0.0, 3.8], y = [0.0, -1.2] }, { minX = -1.1, maxX = 1.1, minZ = 3.8, maxZ = z0 + pl, z = [3.8, z0 + pl], y = [wy + 0.71, wy + 0.71] }],
	}
