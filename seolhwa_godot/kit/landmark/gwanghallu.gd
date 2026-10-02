# 광한루(廣寒樓) — 2층 누각. 본루 정면 5칸·측면 4칸, 팔작지붕, 익공계(용·거북 조각은 생략), 1626년 남원부사 신감 중건.
# 아래층은 장초석(긴 돌 주초) 위 누하주로 비우고, 위층은 우물마루 + 바깥으로 내민 마루(헌함) + 계자난간.
# 익루(동쪽, 정면 3칸·측면 2칸, 가운데 온돌방) 포함(iklu). 북쪽 월랑(계단)은 1881년 추가라 1870 기준 제외 → 뒤편 나무 계단으로 대신(가설).
# 칸 폭·높이는 사진 비례로 잡은 가설. params: seed, iklu(true), wollang(false: true면 북쪽 덮개 계단 간략형)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var b := Kit.Batch.new(); var roof := Kit.Batch.new()
	var bays := [2.9, 3.1, 3.4, 3.1, 2.9]
	var D := 10.0
	var F := 3.4          # 누마루 높이
	var info := Co.hall(b, roof, {
		bays = bays, depth = D, dbays = 4, F = F, H = 3.3, fronts = ["none", "none", "none", "none", "none"],
		enclose = false, back = "none", base = false, floor = false, roof = "paljak", ox = 2.3, oz = 2.2, rise = 3.8, lift = 0.85,
		bracket = "ikgong", col_r = 0.24, roof_nx = 26, roof_nz = 18,
	}, rng)
	var W: float = info.W
	# 낮은 돌 기단
	b.add("stone", Co.pnt(Kit.box(W + 3.2, 0.4, D + 3.2, 0, 0.15, 0), [0xaaa498, 0x7b766c], 0.05, rng), 0.03)
	# 누하주: 장초석(돌) + 나무 기둥 — 5×4칸 격자 전부
	var colx := [-W / 2]
	for w in bays: colx.append(colx[-1] + w)
	var stones := []; var posts := []
	for x in colx:
		for j in 5:
			var z := -D / 2 + D * j / 4
			stones.append(Kit.cyl(0.26, 0.32, 1.1, 8, x, 0.9, z, 0, 0, 0, false))
			posts.append(Kit.cyl(0.23, 0.24, F - 1.45, 6, x, 1.45 + (F - 1.45) / 2, z, 0, 0, 0, false))
	b.add("stone", Co.pnt(Kit.merge(stones), Co.STONE_L, 0.05, rng), 0.02)
	b.add("flat", Co.pnt(Kit.merge(posts), Co.DAN_R, 0.0), 0.02)
	# 마루 판 + 귀틀(헌함으로 0.9m 내밂)
	var ov := 0.9
	b.add("wood", Co.pnt(Kit.box(W + ov * 2, 0.22, D + ov * 2, 0, F - 0.11, 0), Co.WOOD_L, 0.03, rng), 0.02)
	b.add("flat", Co.pnt(Kit.box(W + ov * 2 + 0.1, 0.18, D + ov * 2 + 0.1, 0, F - 0.3, 0), Co.DAN_G, 0.0), 0.015)
	# 계자난간(바깥 둘레, 앞 가운데는 틔움 없음)
	var rg := []
	var hw := W / 2 + ov - 0.05; var hd := D / 2 + ov - 0.05
	for e in [[Vector2(-hw, hd), Vector2(hw, hd)], [Vector2(hw, -hd), Vector2(-hw, -hd)], [Vector2(hw, hd), Vector2(hw, -hd)], [Vector2(-hw, -hd), Vector2(-hw, hd)]]:
		var a: Vector2 = e[0]; var c: Vector2 = e[1]
		var L := a.distance_to(c); var m := (a + c) / 2
		var along_x := absf(a.y - c.y) < 0.01
		var sx := L if along_x else 0.08; var sz := 0.08 if along_x else L
		rg.append(Kit.box(sx, 0.08, sz, m.x, F + 0.85, m.y))
		rg.append(Kit.box(sx * (1 if along_x else 1.5), 0.14, sz * (1.5 if along_x else 1), m.x, F + 0.12, m.y))
		rg.append(Kit.box(sx, 0.05, sz, m.x, F + 0.45, m.y))
		var n := roundi(L / 0.9)
		for i in n + 1:
			var p := a.lerp(c, float(i) / n)
			rg.append(Kit.box(0.07, 0.75, 0.07, p.x, F + 0.47, p.y))
	b.add("wood", Co.pnt(Kit.merge(rg), [0x8a3e2e, 0x6a2e22], 0.0), 0.012)
	# 뒤쪽(북쪽) 가운데 칸: 분합문 달린 칸막이(안쪽 깊이감)
	for i in [1, 2, 3]:
		var x0: float = colx[i]; var x1: float = colx[i + 1]
		var cx := (x0 + x1) / 2
		Co.paper_panel(b, cx, F + 1.3, x1 - x0 - 0.5, 2.0, -D / 2 + 0.05, true)
	# 현판(광한루, 호남제일루)
	b.add("wood", Co.pnt(Kit.box(2.6, 0.85, 0.1, 0, info.top - 0.5, D / 2 + 0.35), [0x3a2c22, 0x2c2018]), 0.012)
	b.add("flat", Co.pnt(Kit.box(2.1, 0.46, 0.04, 0, info.top - 0.5, D / 2 + 0.41), [0xe8dcb8]), 0.0)
	# 오르는 나무 계단(뒤 동쪽 끝)
	var st := []
	var ns := 15
	for s in ns:
		var y := F * (s + 1) / ns
		st.append(Kit.box(1.3, 0.08, 0.32, W / 2 - 1.6, y - 0.04, -D / 2 - ov - 0.25 - (ns - 1 - s) * 0.28))
	var sl := -D / 2 - ov - 0.25 - (ns - 1) * 0.28 / 2
	for sx in [-1, 1]:
		st.append(Kit.xf(Kit.box(0.1, 0.25, ns * 0.3 + 0.4), W / 2 - 1.6 + sx * 0.68, F / 2, sl, atan2(F, ns * 0.28), 0, 0))
	b.add("wood", Co.pnt(Kit.merge(st), Co.WOOD_L, 0.03, rng), 0.012)
	var root := Node3D.new(); root.name = "광한루"
	var main := Co.node2("본루", b, roof)
	root.add_child(main)
	var cols := []
	for x in colx:
		for j in 5:
			cols.append({ type = "circle", x = x, z = -D / 2 + D * j / 4, r = 0.4 })
	var foot := Vector2(info.roof_hw * 2, info.roof_hd * 2)
	if params.get("iklu", true):
		var ib := Kit.Batch.new(); var ir := Kit.Batch.new()
		var ii := Co.hall(ib, ir, {
			bays = [2.6, 2.8, 2.6], depth = 5.4, dbays = 2, F = F, H = 2.9, fronts = ["none", "door", "none"], enclose = false, back = "wall", sides = "none",
			base = false, floor = true, roof = "paljak", ox = 1.6, oz = 1.5, rise = 2.4, lift = 0.6, bracket = "ikgong", col_r = 0.2, roof_nx = 18, roof_nz = 12,
		}, rng)
		var iw: float = ii.W
		# 가운데 온돌방 벽(옆)
		for sx in [-1, 1]:
			ib.add("mud", Co.pnt(Kit.box(0.15, 2.9, 5.4, sx * 1.4, F + 1.45, 0), Co.PLASTER, 0.03, rng), 0.02)
		var lp := []
		for x in [-iw / 2, -1.4, 1.4, iw / 2]:
			for z in [-2.7, 0.0, 2.7]:
				lp.append(Kit.cyl(0.21, 0.22, F, 6, x, F / 2, z, 0, 0, 0, false))
		ib.add("flat", Co.pnt(Kit.merge(lp), Co.DAN_R, 0.0), 0.02)
		var inode := Co.node2("익루", ib, ir)
		var ix: float = W / 2 + ov + iw / 2 + 0.2
		inode.position = Vector3(ix, 0, -D / 2 + 2.7 + 0.3)
		root.add_child(inode)
		foot.x += iw + 2.0
		cols.append({ type = "box", minX = ix - iw / 2, maxX = ix + iw / 2, minZ = -D / 2 + 0.3, maxZ = -D / 2 + 5.7 })
	return {
		node = root, colliders = cols,
		lights = [{ x = -4.0, y = F + 2.6, z = D / 2 + 0.8, kind = "lantern" }, { x = 4.0, y = F + 2.6, z = D / 2 + 0.8, kind = "lantern" }],
		occluder = true, footprint = foot,
		anchors = { upper_floor = Vector3(0, F, 0), front = Vector3(0, 0, D / 2 + 3.0), stair_foot = Vector3(W / 2 - 1.6, 0, -D / 2 - ov - 3.8), under = Vector3(0, 0, 0) },
		interior = { minX = -W / 2 - ov, maxX = W / 2 + ov, minZ = -D / 2 - ov, maxZ = D / 2 + ov, floor_y = F, camera = { pitch = 48, distance = 18 }, hide = [main.get_node("roof")] },
	}
