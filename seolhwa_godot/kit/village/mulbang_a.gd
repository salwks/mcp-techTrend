# 물레방앗간 — 흙벽 초가 맞배 방앗간(남쪽 박공에 문) + 박공 앞에 윗물레(홈통으로 물을 위에서 받는 상사식) 물레바퀴.
# 고증: 조선 후기 산간 계곡 마을(운봉·산내)의 물레방아는 개울에서 끌어온 봇도랑 물을 나무 홈통으로 바퀴 위에 떨어뜨리는
#   방식이 흔했다. 바퀴 지름 3m 안팎(가설: 3.2m). 방아는 집 안에서 굴대로 공이 둘을 번갈아 들어 올린다(안은 생략, 문간 어둡게).
# params: seed, w(3.6), d(4.4), wheel_r(1.6)
# 물: 동쪽 벽을 따라 홈통이 북→남으로 물을 끌어와 바퀴 위에 떨어뜨리고, 바퀴 밑 도랑(y=0.02)으로 남쪽으로 빠진다.
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 3.6); var D: float = params.get("d", 4.4); var WR: float = params.get("wheel_r", 1.6)
	var R := m.rng
	var zf := D / 2; var y0 := 0.18; var wallH := 2.0; var top := y0 + wallH
	# 몸체: 용마루가 남북(z)으로 가는 맞배 — 박공면(남쪽)에 문과 물레바퀴를 둬 카메라에서 바퀴가 정면으로 보이게
	m.add("p", "mud", C.P(Kit.box(W + 0.4, 0.18, D + 0.4, 0, 0.09, 0), 0xb9a27a, 0x9a845e, 0.04, R), 0.02)
	for q in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		m.add("p", "wood", C.PA(Kit.box(0.18, wallH, 0.18, q[0] * W / 2, y0 + wallH / 2, q[1] * zf), C.WOOD), 0.018)
	m.add("p", "mud", C.PA(Kit.box(W, wallH, 0.14, 0, y0 + wallH / 2, -zf), C.MUD, 0.04, R), 0.02)
	for sx in [-1, 1]: m.add("p", "mud", C.PA(Kit.box(0.14, wallH, D, sx * W / 2, y0 + wallH / 2, 0), C.MUD, 0.04, R), 0.02)
	var dx := -0.75
	C.holed_wall(m, "p", -W / 2, W / 2, y0, top, dx - 0.45, dx + 0.45, y0, y0 + 1.7, zf, 0.14, C.MUD)
	C.dark_door(m, dx, y0, 0.9, 1.7, zf)
	m.add("p", "wood", C.P(Kit.xf(Kit.box(0.45, 1.6, 0.05), dx - 0.68, y0 + 0.8, zf + 0.2, 0, 1.0, 0), 0x5a4432, 0x3f2f22), 0.01)
	for sx in [-1, 1]: m.add("p", "wood", C.PA(Kit.box(0.15, 0.15, D + 0.3, sx * W / 2, top + 0.05, 0), C.WOOD), 0.018)
	var old := m.push(0, 0, 0, PI / 2)
	C.thatch_gable(m, "p", D + 0.9, W + 1.1, top + 0.12, 1.1)
	m.pop(old)
	# 물레바퀴(굴대 z방향, 남쪽 박공 앞)
	var cx := W / 2 - 0.1; var cy := WR - 0.25; var cz := zf + 0.55
	for s in [-1, 1]:
		var zz: float = cz + s * 0.3
		m.add("p", "wood", C.P(Kit.xf(C.torus(WR, 0.07, 4, 16), cx, cy, zz), 0x7a5c3e, 0x5a4432, 0.04, R), 0.015)
		for k in 4:
			var a := k * PI / 4
			var dir := Vector3(cos(a), sin(a), 0) * WR
			m.add("p", "wood", C.P(C.beam(Vector3(cx, cy, zz) - dir, Vector3(cx, cy, zz) + dir, 0.07, 0.07), 0x6b5038), 0)
	for k in 16:
		var a := k * TAU / 16
		m.add("p", "wood", C.P(Kit.xf(Kit.box(0.36, 0.05, 0.66), cx + cos(a) * (WR - 0.12), cy + sin(a) * (WR - 0.12), cz, 0, 0, a), 0x8a6a48, 0x6b5038, 0.05, R), 0)
	m.add("p", "wood", C.P(Kit.cyl(0.12, 0.12, 1.2, 8, cx, cy, cz - 0.35, PI / 2, 0, 0), 0x5a4432), 0.012)
	m.add("p", "wood", C.PA(Kit.box(0.2, cy + 0.2, 0.2, cx, (cy + 0.2) / 2, cz + 0.5), C.WOOD), 0.015)
	# 홈통: 동쪽 벽을 따라 뒤(-z)에서 바퀴 꼭대기로
	var hx := W / 2 + 0.55
	var ty := cy + WR + 0.35
	var z0 := -zf - 1.2; var z1 := cz - 0.15
	var tx := (hx + cx) / 2
	m.add("p", "wood", C.P(C.beam(Vector3(hx, ty, z0), Vector3(hx, ty, zf - 0.3), 0.4, 0.06), 0x7a5c3e, 0x5e442e), 0.012)
	m.add("p", "wood", C.P(C.beam(Vector3(hx, ty, zf - 0.3), Vector3(cx + 0.25, ty - 0.1, z1), 0.4, 0.06), 0x7a5c3e, 0x5e442e), 0.012)
	for s in [-1, 1]: m.add("p", "wood", C.P(Kit.box(0.05, 0.2, zf - 0.3 - z0, hx + s * 0.2, ty + 0.1, (z0 + zf - 0.3) / 2), 0x7a5c3e, 0x5e442e), 0.01)
	for zz in [z0 + 0.3, 0.0]: m.add("p", "wood", C.PA(Kit.box(0.12, ty, 0.12, hx + 0.3, ty / 2, zz), C.WOOD), 0.012)
	m.add("p", "smooth", C.P(Kit.box(0.3, 0.03, zf - 0.3 - z0, hx, ty + 0.05, (z0 + zf - 0.3) / 2), 0xa8c4c8, 0x8fb0b6), 0)
	m.add("p", "smooth", C.P(Kit.xf(Kit.box(0.26, 0.45, 0.06), cx + 0.15, ty - 0.25, z1 + 0.05, 0, 0, 0.3), 0xd0e2e2, 0xa8c4c8), 0)
	# 바퀴 아래 도랑 물(동서로 흘러 나감)
	m.add("p", "smooth", C.P(Kit.box(1.1, 0.03, 3.0, cx + 0.3, 0.02, cz + 0.6), 0x7d9ea4, 0x6a8a90), 0)
	for i in 6:
		var s: float = -1.0 if i % 2 == 0 else 1.0
		m.add("p", "stone", C.PA(Kit.xf(Kit.lump(0.22, 0, R, 0.3, 0.6), cx + 0.3 + s * 0.65, 0.06, cz - 0.6 + (i / 2) * 1.0), C.STONE), 0)
	m.box_c(-W / 2 - 0.2, W / 2 + 0.2, -zf - 0.2, zf + 0.2)
	m.box_c(cx - WR - 0.1, cx + WR + 0.1, cz - 0.45, cz + 0.6)
	m.box_c(hx - 0.2, hx + 0.4, z0, zf)
	m.light(dx, y0 + 1.3, zf + 0.2, "window")
	m.anchor("door", Vector3(dx, 0, zf + 0.9))
	return m.result("물레방앗간", Vector2(W + WR + 1.2, D + 3.0))
