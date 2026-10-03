# 함흥본궁 반송(盤松) — 태조 이성계가 손수 심었다는 소나무(옆으로 넓게 퍼진 반송) + 둘레 낮은 돌 테두리. 나무 모양은 웹 소나무 화풍의 간략형(본격 식생은 kit/nature).
# params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	b.add("bark", Co.pnt(Kit.limb(Vector3(0, 0, 0), Vector3(0.2, 1.6, 0), 0.4, 0.3, 7), [0x7a5038, 0x5a3a28]), 0.02)
	for k in 5:
		var a := TAU * k / 5 + 0.3
		var e := Vector3(cos(a) * 3.2, 2.4 + rng.next() * 0.6, sin(a) * 3.2)
		b.add("bark", Co.pnt(Kit.limb(Vector3(0.2, 1.5, 0), e, 0.22, 0.1, 5), [0x7a5038, 0x5a3a28]), 0.015)
		var g := Kit.lump(1.0, 1, rng, 0.3, 0.45); Kit.xf(g, e.x, e.y + 0.4, e.z, 0, 0, 0, 1.6, 1.0, 1.6)
		b.add("needle", Kit.paint(g, Kit.hex(0x5f7a42), Kit.hex(0x3a5030), 0.08, rng), 0.03)
	var top := Kit.lump(1.0, 1, rng, 0.3, 0.5); Kit.xf(top, 0.2, 3.4, 0, 0, 0, 0, 2.2, 1.0, 2.2)
	b.add("needle", Kit.paint(top, Kit.hex(0x6a8448), Kit.hex(0x3a5030), 0.08, rng), 0.03)
	var ring := []
	for i in 14:
		var a := TAU * i / 14
		ring.append(Kit.xf(Kit.box(0.7, 0.3, 0.35), cos(a) * 1.6, 0.15, sin(a) * 1.6, 0, -a + PI / 2))
	b.add("stone", Co.pnt(Kit.merge(ring), Co.STONE_L, 0.05, rng), 0.012)
	return { node = b.build("반송"), colliders = [{ type = "circle", x = 0.0, z = 0.0, r = 1.8 }], lights = [], occluder = false, footprint = Vector2(8.0, 8.0), anchors = { front = Vector3(0, 0, 2.6) } }
