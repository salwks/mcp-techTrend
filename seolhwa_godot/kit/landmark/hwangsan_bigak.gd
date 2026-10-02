# 황산대첩비(荒山大捷碑)와 비각 — 1380년 이성계의 황산 전투 승리를 기려 1577년(선조 10) 운봉 화수리에 세운 비(김귀영 글, 송인 글씨).
# 1945년 일제가 폭파 → 1963·1973 복원(파비각은 1973년이라 1870 기준 제외). 1870년 무렵 모습: 귀부(거북 받침) + 비신 + 이수(용 머리돌) + 비각.
# 비각 규모(정면 3칸·측면 2칸, 팔작, 사방 홍살)와 비 치수(비신 높이 약 3m)는 가설. params: seed, wall(true: 낮은 돌담 + 앞 협문)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var D := 5.2
	var info := Co.hall(b, r, {
		bays = [2.3, 3.0, 2.3], depth = D, dbays = 2, F = 0.6, H = 3.6, fronts = ["hongsal", "hongsal", "hongsal"],
		enclose = true, back = "hongsal", sides = "hongsal", floor = false, roof = "paljak", ox = 1.4, oz = 1.4, rise = 2.5, lift = 0.6,
		bracket = "ikgong", col_r = 0.18, steps = [0.0], step_w = 1.6, roof_nx = 18, roof_nz = 14,
	}, rng)
	var F: float = info.F
	# 박석 바닥
	b.add("stone", Co.pnt(Kit.box(info.W - 0.2, 0.05, D - 0.2, 0, F + 0.02, 0), [0xb0aa9c, 0x9d978a], 0.04, rng), 0.0)
	# 귀부: 거북 몸(납작한 덩이) + 머리 + 등 위 비좌
	var tort := Kit.lump(1.0, 1, rng, 0.08, 0.42)
	Kit.xf(tort, 0, F + 0.35, 0, 0, 0, 0, 1.15, 1.0, 1.45)
	b.add("stone", Co.pnt(tort, [0x8f8a80, 0x6a665e], 0.05, rng), 0.025)
	var head := Kit.lump(0.32, 1, rng, 0.1, 0.8)
	Kit.xf(head, 0, F + 0.45, 1.75, 0.3, 0, 0, 1.0, 1.0, 1.4)
	b.add("stone", Co.pnt(head, [0x8f8a80, 0x6a665e], 0.05, rng), 0.02)
	for s in [-1, 1]:
		for zz in [-0.8, 0.8]:
			b.add("stone", Co.pnt(Kit.xf(Kit.lump(0.25, 0, rng, 0.2, 0.7), s * 1.0, F + 0.15, zz), [0x8a857b, 0x6a665e], 0.05, rng), 0.015)
	b.add("stone", Co.pnt(Kit.box(1.5, 0.22, 0.65, 0, F + 0.78, 0), [0x8f8a80, 0x76716a], 0.03, rng), 0.015)
	# 비신(검은 빛 오석 느낌은 1963 복원이므로 1870엔 화강암 회색 — 가설) + 이수
	var bh := 3.0
	b.add("stone", Co.pnt(Kit.box(1.2, bh, 0.36, 0, F + 0.89 + bh / 2, 0), [0xcac4b8, 0xa8a296], 0.03, rng), 0.025)
	# 글씨 자리(어두운 줄 몇 개)
	var lines := []
	for i in 7:
		lines.append(Co.vplane(0.05, bh * 0.75, -0.42 + i * 0.14, F + 0.89 + bh * 0.48, 0.185))
	b.add("flat", Co.pnt(Kit.merge(lines), [0x5a554e]), 0.0)
	var isu := Kit.lump(0.75, 1, rng, 0.1, 0.55)
	Kit.xf(isu, 0, F + 0.89 + bh + 0.32, 0, 0, 0, 0, 1.05, 1.0, 0.42)
	b.add("stone", Co.pnt(isu, [0x9d978a, 0x7c766b], 0.05, rng), 0.025)
	b.add("stone", Co.pnt(Kit.box(1.36, 0.2, 0.44, 0, F + 0.89 + bh + 0.08, 0), [0x9d978a, 0x7c766b], 0.04, rng), 0.015)
	var root := Node3D.new(); root.name = "황산대첩비각"
	root.add_child(Co.node2("비각", b, r))
	var cols := [{ type = "box", minX = -info.W / 2 - 0.5, maxX = info.W / 2 + 0.5, minZ = -D / 2 - 0.5, maxZ = D / 2 + 0.5 }]
	var foot := Vector2(info.roof_hw * 2, info.roof_hd * 2)
	if params.get("wall", true):
		var wb := Kit.Batch.new()
		var hw := 9.0; var hd := 7.5
		var gap := 1.4
		var pts := [[-hw, hd, -gap, hd], [gap, hd, hw, hd], [hw, hd, hw, -hd], [hw, -hd, -hw, -hd], [-hw, -hd, -hw, hd]]
		for p in pts:
			Co.tile_wall(wb, p[0], p[1], p[2], p[3], 1.6, rng, 0.45)
			cols.append(Co.wall_collider(p[0], p[1], p[2], p[3], 0.55))
		root.add_child(wb.build("담"))
		foot = Vector2(hw * 2 + 1, hd * 2 + 1)
	return {
		node = root, colliders = cols, lights = [{ x = 0.0, y = 3.0, z = D / 2 + 0.6, kind = "lantern" }],
		occluder = true, footprint = foot,
		anchors = { front = Vector3(0, 0, D / 2 + 2.0), gate = Vector3(0, 0, 7.5), stele = Vector3(0, F, 0) },
	}
