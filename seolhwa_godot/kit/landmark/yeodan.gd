# 여단(厲壇) — 제사 받지 못하는 떠도는 혼(여귀)에게 봄·가을·겨울 제사하는 고을 북쪽 제단(조선 주현 공통, 참고).
# 낮은 네모 토단 + 앞 계단 + 낮은 흙돌담 + 홍살문 + 성황 신위 모시는 작은 돌상. 치수 가설. params: seed
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new()
	var hw := 9.0
	b.add("mud", Co.pnt(Kit.box(5.0, 0.6, 5.0, 0, 0.3, -1.0), [0xb09a76, 0x947e5c], 0.04, rng), 0.025)
	b.add("stone", Co.pnt(Kit.box(5.2, 0.25, 5.2, 0, 0.12, -1.0), Co.STONE, 0.05, rng), 0.0)
	for k in 2:
		var sh := 0.6 * (k + 1) / 2.0
		b.add("stone", Co.pnt(Kit.box(1.4, sh, 0.35, 0, sh / 2, 1.5 + 0.18 + (1 - k) * 0.35), Co.STONE_L, 0.04, rng), 0.012)
	b.add("stone", Co.pnt(Kit.box(1.0, 0.45, 0.5, 0, 0.82, -2.6), [0x9d978a, 0x847e72], 0.03, rng), 0.015)
	# 둘레 잡초·돌(버려진 느낌)
	for i in 8:
		var a := TAU * i / 8 + rng.next() * 0.4
		var g := Kit.lump(rng.between(0.25, 0.45), 0, rng, 0.35, 0.6)
		Kit.xf(g, cos(a) * 6.5, 0.15, -1.0 + sin(a) * 6.0)
		b.add("rock", Co.pnt(g, [0xb1ab9d, 0x7c776c], 0.08, rng), 0.02)
	var cols := [{ type = "box", minX = -2.6, maxX = 2.6, minZ = -3.6, maxZ = 1.6 }]
	cols.append_array(Co.low_wall_loop(b, [Vector2(-hw, -hw), Vector2(hw, -hw), Vector2(hw, hw), Vector2(-hw, hw)], [[0.0, hw, 2.2]], 1.1, rng, 0.5))
	Co.hongsal_gate(b, 0.0, hw, 4.0, 5.0)
	return {
		node = b.build("여단"), colliders = cols, lights = [], occluder = false,
		footprint = Vector2(hw * 2 + 1, hw * 2 + 1), anchors = { altar = Vector3(0, 0.6, -1.0), gate = Vector3(0, 0, hw), outside = Vector3(0, 0, hw + 3.0) },
	}
