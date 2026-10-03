# 경주 석빙고(石氷庫) — 반월성 북쪽 안. 1738년 쌓고 1741년 지금 자리로 옮김(입구 이마돌 명문) → 1870년에 있었다.
# 길이 약 19m·너비 6m 반지하 돌방 위에 흙 봉분(잔디), 남쪽 입구(돌 문틀·계단), 지붕 위 환기 구멍 셋(돌 덮개).
# 봉분 높이·입구 비례는 가설. 정면(입구) +z. params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	var m := Kit.lump(1.0, 2, rng, 0.06, 1.0)
	Kit.xf(m, 0, -0.4, -1.0, 0, 0, 0, 5.0, 3.0, 11.0)
	for i in m.pos.size():
		if m.pos[i].y < -0.3: m.pos[i].y = -0.3
	b.add("organic", Co.pnt(m, Hub.GRASS, 0.06, rng), 0.04)
	# 입구: 돌 옹벽 + 문틀 + 어두운 구멍 + 내려가는 계단
	var fz := 9.6
	for s in [-1, 1]:
		b.add("stone", Co.pnt(Kit.xf(Kit.box(0.6, 2.4, 3.2), s * 1.6, 1.0, fz + 0.6, 0, s * 0.18), Co.SEONG, 0.04, rng), 0.025)
	b.add("stone", Co.pnt(Kit.box(2.8, 0.5, 0.7, 0, 2.15, fz - 0.6), [0xc2bba8, 0x9e9786], 0.04, rng), 0.02)
	b.add("flat", Co.pnt(Co.vplane(1.6, 1.9, 0, 0.95, fz - 0.24), [0x1c1916]), 0.0)
	for k in 3:
		b.add("stone", Co.pnt(Kit.box(1.8, 0.2, 0.5, 0, 0.1 - k * 0.2 + 0.2, fz + 1.4 - k * 0.5), Co.STONE_L, 0.04, rng), 0.012)
	# 환기 구멍 덮개돌 셋
	for k in 3:
		var z := -7.0 + k * 6.0
		var y := 3.0 - pow(absf(z + 1.0) / 11.0, 2) * 3.0 + 0.25
		b.add("stone", Co.pnt(Kit.box(0.9, 0.5, 0.9, 0, y, z), Co.SEONG, 0.04, rng), 0.02)
		b.add("stone", Co.pnt(Kit.box(1.3, 0.16, 1.3, 0, y + 0.33, z), [0xc2bba8, 0x9e9786], 0.04, rng), 0.02)
	return {
		node = b.build("석빙고"), colliders = [{ type = "box", minX = -4.0, maxX = 4.0, minZ = -11.0, maxZ = 9.0 }], lights = [], occluder = true,
		footprint = Vector2(9.4, 23.0), anchors = { entrance = Vector3(0, 0, fz + 2.0) },
	}
