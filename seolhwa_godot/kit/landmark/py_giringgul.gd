# 기린굴(麒麟窟) 입구 — 평양 모란봉 부벽루 아래 바위 굴. 동명왕(주몽)이 기린마를 기르고 그 말을 타고 굴로 들어가 조천석(朝天石)으로 하늘에 올랐다는 전설.
# 『신증동국여지승람』 평양 고적. 입구 앞 바위에 '麒麟窟' 각자 자리(1870 무렵 각자 유무는 가설), 앞 강가 쪽 조천석(납작 바위). params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	var c := [0xb0aa9c, 0x6e695f]
	var fz := Hub.cave_mouth(b, rng, 2.6, 2.6, c, Vector3(12, 6, 9))
	# 각자 판(굴 옆 바위 면)
	b.add("stone", Co.pnt(Kit.box(1.1, 1.6, 0.2, 3.4, 1.6, fz + 0.05), [0xc4beb0, 0x9e9888], 0.04, rng), 0.012)
	for k in 3:
		b.add("flat", Co.pnt(Co.vplane(0.24, 0.32, 3.4, 2.1 - k * 0.45, fz + 0.16), [0x4a443c]), 0.0)
	# 조천석(납작 바위, 앞)
	var g := Kit.lump(1.0, 1, rng, 0.15, 1.0); Kit.xf(g, -3.0, 0.25, fz + 4.0, 0, 0.4, 0, 1.6, 0.45, 1.1)
	b.add("rock", Co.pnt(g, c, 0.06, rng), 0.03)
	for k in 6:
		var a := rng.between(0, PI)
		Hub.rock(b, rng, cos(a) * rng.between(4.5, 6.5), fz + 0.4 + sin(a) * rng.between(0.5, 1.6) - 0.8, rng.between(0.4, 0.9), rng.between(0.3, 0.6), rng.between(0.4, 0.8), c, 0, 0.35, a)
	return {
		node = b.build("기린굴"), colliders = [{ type = "box", minX = -6.0, maxX = -1.4, minZ = -9.0, maxZ = fz }, { type = "box", minX = 1.4, maxX = 6.0, minZ = -9.0, maxZ = fz },
			{ type = "circle", x = -3.0, z = fz + 4.0, r = 1.4 }],
		lights = [], occluder = true, footprint = Vector2(13.0, 14.0), anchors = { mouth = Vector3(0, 0, fz + 1.0), inside = Vector3(0, 0, fz - 2.0), jocheonseok = Vector3(-3.0, 0.5, fz + 4.0) },
	}
