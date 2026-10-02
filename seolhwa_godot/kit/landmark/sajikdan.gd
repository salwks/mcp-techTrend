# 사직단(社稷壇) — 고을 서쪽에 두는 토지신(社)·곡식신(稷) 제단. 군현 사직단은 사·직을 한 단에 모시는 경우가 많다(『국조오례의』 주현 사직 — 참고).
# 네모 토단(돌 가장자리) + 사방 계단(사출폐) + 낮은 담(유) + 앞 홍살문 + (선택) 작은 재실. dual=true면 사단·직단 둘(동 사, 서 직).
# 치수는 가설(단 6m 안팎, 높이 0.9m, 담 24×24m). 홍살문은 카메라 쪽(+z, 남)에 둠(실제 사직단은 북쪽 신문이 정문 — 게임 편의상 남). 재실은 담 밖 서남쪽.
# jaesil=true면 재실이 담 밖 서남쪽(x −21.6까지)이라 footprint를 원점 대칭 44×25로 준다. params: seed, dual(false), jaesil(false)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func altar(b, rng: Kit.Rng, x: float, z: float, s: float, h: float) -> void:
	b.add("mud", Co.pnt(Kit.box(s, h, s, x, h / 2, z), [0xb8a27e, 0x9a8462], 0.03, rng), 0.025)
	# 돌 가장자리 띠
	for e in [[0, s / 2], [0, -s / 2], [s / 2, 0], [-s / 2, 0]]:
		var w := s + 0.2 if e[0] == 0 else 0.2
		var d := 0.2 if e[0] == 0 else s + 0.2
		b.add("stone", Co.pnt(Kit.box(w, h * 0.6, d, x + e[0], h * 0.3, z + e[1]), Co.STONE_L, 0.04, rng), 0.0)
	# 사방 계단(3단)
	for dir in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
		for k in 3:
			var sh := h * (k + 1) / 3.0
			var off := s / 2 + 0.2 + (2 - k) * 0.3
			var bw := 1.4
			var g := Kit.box(bw if dir.x == 0 else 0.3, sh, 0.3 if dir.x == 0 else bw, x + dir.x * off, sh / 2, z + dir.y * off)
			b.add("stone", Co.pnt(g, Co.STONE_L, 0.04, rng), 0.012)

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var hw := 12.0
	var cols := []
	if params.get("dual", false):
		altar(b, rng, 3.8, -1.0, 4.6, 0.8); altar(b, rng, -3.8, -1.0, 4.6, 0.8)
		cols.append({ type = "box", minX = 1.2, maxX = 6.4, minZ = -3.6, maxZ = 1.6 }); cols.append({ type = "box", minX = -6.4, maxX = -1.2, minZ = -3.6, maxZ = 1.6 })
	else:
		altar(b, rng, 0.0, -1.0, 6.0, 0.9)
		cols.append({ type = "box", minX = -3.2, maxX = 3.2, minZ = -4.2, maxZ = 2.2 })
	# 위패 놓는 자리(돌 상) — 단 북쪽 가운데
	b.add("stone", Co.pnt(Kit.box(1.2, 0.5, 0.6, 0, 1.15, -2.6), [0x9d978a, 0x847e72], 0.03, rng), 0.015)
	cols.append_array(Co.low_wall_loop(b, [Vector2(-hw, -hw), Vector2(hw, -hw), Vector2(hw, hw), Vector2(-hw, hw)], [[0.0, hw, 2.4]], 1.3, rng, 0.55))
	Co.hongsal_gate(b, 0.0, hw, 4.2, 5.4)
	var anchors := { altar = Vector3(0, 0.9, -1.0), gate = Vector3(0, 0, hw), outside = Vector3(0, 0, hw + 3.0) }
	if params.get("jaesil", false):
		var info := Co.hall(b, r, { bays = [2.4, 2.6, 2.4], depth = 4.0, dbays = 1, F = 0.5, H = 2.4, fronts = ["window", "door", "door"],
			roof = "matbae", ox = 1.0, oz = 1.2, rise = 1.8, bracket = "none", col_r = 0.13, col_color = Co.WOOD, band = Co.WOOD,
			cx = -hw - 5.2, cz = hw - 3.0, roof_nx = 10, roof_nz = 10, side_window = false }, rng)
		cols.append({ type = "box", minX = -hw - 9.6, maxX = -hw - 0.8, minZ = hw - 6.0, maxZ = hw })
		anchors.jaesil = Vector3(-hw - 5.2, 0, hw + 0.5)
	return {
		node = Co.node2("사직단", b, r), colliders = cols, lights = [], occluder = false,
		footprint = Vector2(44.0 if params.get("jaesil", false) else hw * 2 + 1, hw * 2 + 1), anchors = anchors,
	}
