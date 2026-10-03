# 수표교(水標橋) — 1420년(세종 2) 청계천에 놓은 돌다리(길이 약 27.5m·너비 약 7.5m). 2단 돌기둥 교각(물 흐름 쪽 마름모꼴 위 네모 기둥) 위 멍에돌·청판석, 돌난간.
# 1441년 다리 옆에 수표(水標: 눈금 새긴 돌기둥, 물 높이 재기)를 세움 → 1870년에 다리와 수표(1760년대 새로 세운 돌 수표)가 있었다.
# (다리는 1959년 장충단으로 옮겨짐.) 로컬 z가 건너는 방향, 원점 = 개천 바닥 가운데. params: seed, length(27.5), width(7.5), deck(3.0), supyo(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var L: float = float(params.get("length", 27.5)); var Wd: float = float(params.get("width", 7.5)); var Y: float = float(params.get("deck", 3.0))
	var b := Kit.Batch.new()
	var piers := []
	var nz := 8
	for j in nz:
		var z := -L / 2 + L * (j + 0.5) / nz
		for i in 4:
			var x := -Wd / 2 + 0.7 + (Wd - 1.4) * i / 3
			# 아래 마름모 기둥(물살 가르는 모서리) + 위 네모 기둥
			piers.append(Kit.box(0.6, 1.2, 0.6, x, 0.6, z, PI / 4))
			piers.append(Kit.box(0.5, Y - 1.8, 0.5, x, 1.2 + (Y - 1.8) / 2, z))
		piers.append(Kit.box(Wd, 0.4, 0.7, 0, Y - 0.6 + 0.2, z))
	b.add("stone", Co.pnt(Kit.merge(piers), [0xb8b2a2, 0x8e887a], 0.05, rng), 0.025)
	b.add("stone", Co.pnt(Kit.box(Wd, 0.3, L, 0, Y - 0.25, 0), [0xc4beb0, 0xa29c8e], 0.04, rng), 0.03)
	for s in [-1, 1]:
		Hub.stone_rail(b, rng, Vector2(s * (Wd / 2 - 0.2), -L / 2), Vector2(s * (Wd / 2 - 0.2), L / 2), Y - 0.1, 2.3, 0.75)
	var cols := [{ type = "box", minX = -Wd / 2 - 0.2, maxX = -Wd / 2 + 0.3, minZ = -L / 2, maxZ = L / 2 }, { type = "box", minX = Wd / 2 - 0.3, maxX = Wd / 2 + 0.2, minZ = -L / 2, maxZ = L / 2 }]
	var anchors := { north_end = Vector3(0, Y, -L / 2), south_end = Vector3(0, Y, L / 2), middle = Vector3(0, Y, 0) }
	if params.get("supyo", true):
		# 수표석: 네모 돌기둥(눈금 띠) + 연꽃 머릿돌 + 받침, 다리 서쪽 옆 개천 속
		var sx := -Wd / 2 - 2.6
		var g := [Kit.box(1.0, 0.4, 1.0, sx, 0.2, 2.0), Kit.box(0.28, 3.0, 0.28, sx, 1.9, 2.0), Kit.cyl(0.08, 0.3, 0.35, 8, sx, 3.55, 2.0)]
		b.add("stone", Co.pnt(Kit.merge(g), [0xc8c2b4, 0x9e9888], 0.04, rng), 0.015)
		var ticks := []
		for k in 10:
			ticks.append(Co.vplane(0.2, 0.025, sx, 0.6 + k * 0.28, 2.0 + 0.145))
		b.add("flat", Co.pnt(Kit.merge(ticks), [0x3a342c]), 0.0)
		cols.append({ type = "circle", x = sx, z = 2.0, r = 0.6 })
		anchors.supyo = Vector3(sx, 0, 3.2)
	return {
		node = b.build("수표교"), colliders = cols, lights = [], occluder = false, footprint = Vector2(Wd + 6.0, L),
		anchors = anchors, walk = [{ minX = -Wd / 2 + 0.4, maxX = Wd / 2 - 0.4, minZ = -L / 2 - 0.6, maxZ = L / 2 + 0.6, z = [-L / 2 - 0.6, L / 2 + 0.6], y = [Y + 0.05, Y + 0.05] }],
	}
