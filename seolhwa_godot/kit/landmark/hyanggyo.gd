# 향교(선택) — 남원향교 일곽 간략형. 평지 향교의 전묘후학(앞 대성전·뒤 명륜당) 배치 가설.
# 외삼문(솟을삼문) → 대성전(정면 3칸·측면 3칸 맞배, 앞 툇칸 개방) → 명륜당(정면 5칸 팔작, 가운데 대청) + 담장.
# 남원향교 각 건물의 실제 규모·배치는 확인 못 함(가설). 원점 = 일곽 가운데, 정면 +z. params: seed, width(40), depth(56)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var seed: int = int(params.get("seed", 1))
	var rng := Kit.Rng.new(seed)
	var W: float = float(params.get("width", 40.0)); var D: float = float(params.get("depth", 56.0))
	var pieces := [{ kit = "landmark/samun", params = { seed = seed, kind = "outer" }, x = 0.0, z = D / 2, ry = 0.0, tag = "oesammun" }]
	pieces.append_array(Co.wall_pieces([Vector2(-W / 2, -D / 2), Vector2(W / 2, -D / 2), Vector2(W / 2, D / 2), Vector2(-W / 2, D / 2)], true, [[0.0, D / 2, 4.8]], seed + 10, 2.0))
	var r := Co.assemble("향교", pieces)
	var root: Node3D = r.node
	# 대성전
	var b1 := Kit.Batch.new(); var r1 := Kit.Batch.new()
	var i1 := Co.hall(b1, r1, { bays = [3.2, 3.6, 3.2], depth = 8.4, dbays = 3, F = 0.9, H = 3.5, fronts = ["door", "door", "door"],
		roof = "matbae", ox = 1.4, oz = 1.8, rise = 3.6, bracket = "ikgong", col_r = 0.22, steps = [-3.4, 3.4], step_w = 1.4, roof_nx = 16, roof_nz = 16 }, rng)
	var n1 := Co.node2("대성전", b1, r1); n1.position = Vector3(0, 0, 4.0); root.add_child(n1)
	# 명륜당
	var b2 := Kit.Batch.new(); var r2 := Kit.Batch.new()
	var i2 := Co.hall(b2, r2, { bays = [2.7, 2.7, 3.0, 2.7, 2.7], depth = 6.0, dbays = 2, F = 0.8, H = 3.0, fronts = ["window", "door", "open", "door", "window"],
		roof = "paljak", ox = 1.7, oz = 1.6, rise = 2.8, bracket = "ikgong", col_r = 0.18, roof_nx = 22, roof_nz = 14 }, rng)
	var n2 := Co.node2("명륜당", b2, r2); n2.position = Vector3(0, 0, -D / 2 + 9.0); root.add_child(n2)
	r.colliders.append({ type = "box", minX = -i1.W / 2 - 0.75, maxX = i1.W / 2 + 0.75, minZ = 4.0 - 4.95, maxZ = 4.0 + 4.95 })
	r.colliders.append({ type = "box", minX = -i2.W / 2 - 0.75, maxX = i2.W / 2 + 0.75, minZ = -D / 2 + 9.0 - 3.75, maxZ = -D / 2 + 9.0 + 3.75 })
	r.anchors.daeseongjeon = Vector3(0, 0, 4.0 + 6.5)
	r.anchors.myeongnyundang = Vector3(0, i2.F, -D / 2 + 9.0)
	r.occluder = true
	r.footprint = Vector2(W + 2, D + 6)
	r.pieces = pieces
	return r
