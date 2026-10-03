# 광통교(廣通橋, 대광통교) — 운종가에서 남대문으로 가는 큰길이 청계천을 건너던 돌다리. 1410년(태종 10) 신덕왕후 정릉의 병풍석·돌을 옮겨 돌다리로 놓음
# (다리 옆면에 거꾸로 박힌 구름·당초무늬 병풍석). 길이 약 12m·너비 약 15m, 교각(돌기둥) 위에 멍에돌·청판석, 양옆 돌난간. 1870년에 그대로.
# 로컬 z가 건너는 방향(남북), 원점 = 다리 가운데 개천 바닥. 상판 높이 = 축대 높이(deck 3.0). params: seed, length(12+축대 사이 맞춤 16), width(15), deck(3.0)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var L: float = float(params.get("length", 16.0)); var Wd: float = float(params.get("width", 15.0)); var Y: float = float(params.get("deck", 3.0))
	var b := Kit.Batch.new()
	# 교각: 다리 방향으로 3줄(z), 줄마다 돌기둥 5개(x)
	var piers := []
	var nz := 3
	for j in nz:
		var z := -L / 2 + L * (j + 1) / (nz + 1)
		for i in 5:
			var x := -Wd / 2 + 1.0 + (Wd - 2.0) * i / 4
			piers.append(Kit.box(0.6, Y - 0.6, 0.6, x, (Y - 0.6) / 2, z))
		piers.append(Kit.box(Wd, 0.45, 0.8, 0, Y - 0.6 + 0.2, z))   # 멍에돌
	b.add("stone", Co.pnt(Kit.merge(piers), [0xb8b2a2, 0x8e887a], 0.05, rng), 0.025)
	# 청판석 상판
	b.add("stone", Co.pnt(Kit.box(Wd, 0.35, L + 1.0, 0, Y - 0.17, 0), [0xc4beb0, 0xa29c8e], 0.04, rng), 0.03)
	# 옆면 병풍석(무늬판 — 거꾸로 박힌 정릉 병풍석)
	for s in [-1, 1]:
		var pg := []
		for k in 4:
			var z := -L / 2 + L * (k + 0.5) / 4
			var q := Co.vplane(L / 4 - 0.3, 0.55, 0, 0, 0)
			Kit.xf(q, s * (Wd / 2 + 0.02), Y - 0.3, z, 0, s * PI / 2)
			pg.append(q)
		b.add("stone", Co.pnt(Kit.merge(pg), [0x9e9888, 0x7c7666], 0.08, rng), 0.0)
		Hub.stone_rail(b, rng, Vector2(s * (Wd / 2 - 0.2), -L / 2 - 0.5), Vector2(s * (Wd / 2 - 0.2), L / 2 + 0.5), Y, 2.0, 0.7)
	return {
		node = b.build("광통교"), colliders = [{ type = "box", minX = -Wd / 2 - 0.2, maxX = -Wd / 2 + 0.3, minZ = -L / 2, maxZ = L / 2 }, { type = "box", minX = Wd / 2 - 0.3, maxX = Wd / 2 + 0.2, minZ = -L / 2, maxZ = L / 2 }],
		lights = [], occluder = false, footprint = Vector2(Wd + 0.6, L + 1.0),
		anchors = { north_end = Vector3(0, Y, -L / 2), south_end = Vector3(0, Y, L / 2), middle = Vector3(0, Y, 0) },
		walk = [{ minX = -Wd / 2 + 0.4, maxX = Wd / 2 - 0.4, minZ = -L / 2 - 0.6, maxZ = L / 2 + 0.6, z = [-L / 2 - 0.6, L / 2 + 0.6], y = [Y, Y] }],
	}
