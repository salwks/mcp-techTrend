# 심청 도화동(桃花洞) 표지 — 「심청전」의 고향 '황주 도화동'(소설 속 지명). 1870년에 실제 사당·비가 있었다는 근거는 못 찾음 → 게임용 표지:
# 마을 어귀 큰 바위에 '桃花洞' 새김 자리 + 앞 제단돌 + 복숭아나무 둘(꽃). 모두 가설. params: seed, trees(true)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	Hub.rock(b, rng, 0, -0.6, 2.2, 1.7, 1.4, [0xb8b2a4, 0x7e786c], 1, 0.18, 0.1)
	# 새긴 면(평평한 판 + 글자 자리 세로 줄 셋)
	b.add("stone", Co.pnt(Kit.box(1.5, 1.4, 0.3, 0, 1.2, 0.55), [0xc4beb0, 0x9e9888], 0.04, rng), 0.015)
	for k in 3:
		b.add("flat", Co.pnt(Co.vplane(0.22, 0.32, 0, 1.65 - k * 0.42, 0.71), [0x4a443c]), 0.0)
	b.add("stone", Co.pnt(Kit.box(1.1, 0.35, 0.6, 0, 0.17, 1.5), [0xb0aa9c, 0x8a8478], 0.05, rng), 0.02)
	var cols := [{ type = "circle", x = 0.0, z = -0.4, r = 2.0 }, { type = "box", minX = -0.55, maxX = 0.55, minZ = 1.2, maxZ = 1.8 }]
	if params.get("trees", true):
		for sx in [-1, 1]:
			var x: float = sx * 3.4
			b.add("bark", Co.pnt(Kit.limb(Vector3(x, 0, 0.4), Vector3(x + sx * 0.3, 1.6, 0.3), 0.14, 0.09, 5), [0x6a4a3a, 0x4e3628]), 0.015)
			for k in 3:
				var g := Kit.lump(rng.between(0.6, 0.85), 1, rng, 0.3, 0.75)
				Kit.xf(g, x + sx * 0.3 + rng.between(-0.6, 0.6), 2.0 + rng.next() * 0.5, 0.3 + rng.between(-0.5, 0.5))
				b.add("leaf", Kit.paint(g, Kit.hex(0xf0c8c8), Kit.hex(0xd89aa0), 0.08, rng), 0.02)
			cols.append({ type = "circle", x = x, z = 0.4, r = 0.3 })
	return { node = b.build("도화동표지"), colliders = cols, lights = [], occluder = false, footprint = Vector2(9.0, 5.0), anchors = { front = Vector3(0, 0, 2.6) } }
