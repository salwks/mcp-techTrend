# 공용 도구 시험용 견본: 돌 기단 위 흙벽 집 + 초가 지붕 느낌 + 바위 + 나무 한 그루
extends RefCounted

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 7)))
	var b := Kit.Batch.new()
	b.add("stone", Kit.paint(Kit.box(5.2, 0.4, 3.8, 0, 0.2, 0), Kit.hex(0xcfc6b4), Kit.hex(0x9a907e), 0.06, r))
	b.add("mud", Kit.paint(Kit.box(4.6, 1.8, 3.2, 0, 1.3, 0), Kit.hex(0xefe4c8), Kit.hex(0xc9b48c), 0.04, r))
	b.add("paper", Kit.box(0.9, 1.1, 0.05, -1.0, 1.35, 1.62))
	var roof := Kit.lump(1.0, 2, r, 0.08, 0.45)
	Kit.xf(roof, 0, 2.3, 0, 0, 0, 0, 3.2, 1.6, 2.4)
	b.add("thatch", Kit.paint(roof, Kit.hex(0xe2d2a4), Kit.hex(0xb79c66), 0.05, r))
	b.add("rock", Kit.paint(Kit.xf(Kit.lump(0.7, 1, r, 0.3), 3.6, 0.4, 1.2), Kit.hex(0xd8d4c8), Kit.hex(0x8e8a80), 0.08, r))
	b.add("bark", Kit.paint(Kit.limb(Vector3(-3.6, 0, -0.5), Vector3(-3.4, 3.0, -0.6), 0.22, 0.12), Kit.hex(0x8a5a3c)))
	b.add("needle", Kit.paint(Kit.xf(Kit.lump(1.3, 1, r, 0.25, 0.7), -3.4, 3.6, -0.6), Kit.hex(0x6f8a4a), Kit.hex(0x3e5a32), 0.08, r))
	var node := b.build("견본")
	return { node = node, colliders = [{ type = "box", minX = -2.6, maxX = 2.6, minZ = -1.9, maxZ = 1.9 }], lights = [{ x = -1.0, y = 1.35, z = 1.7, kind = "window" }] }
