# 초가(초가삼간) — 웹 buildings.js choga()/chogaInterior() 이식.
# params: seed, w(6, 3칸 폭), d(4), hump(지붕 볼록, 없으면 seed로), gourd(박 넝쿨), open(가운데 방문 열림),
#         chimney(true), interior(false: true면 open + 실내 + part 노드 분리)
# 앞(+z): 왼쪽 방 창, 가운데 방문(두 짝), 오른쪽 부엌 널문, 툇마루, 댓돌. 굴뚝은 오른쪽 뒤.
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var seed := int(params.get("seed", 1))
	var inside := bool(params.get("interior", false))
	var m := C.M.new(seed, not inside)
	var o := params.duplicate()
	if not o.has("hump"): o.hump = (m.r() - 0.5) * 0.3
	if inside:
		o.open = true; o.dark_inside = false
	var info := draw(m, o)
	var W: float = info.W; var D: float = info.D
	var inn := interior(m, W, D, info.F) if inside else {}
	var res := m.result("초가", Vector2(W + 2.2, D + 2.4))
	if inside:
		var node: Node3D = res.node
		res.interior = { minX = -W / 2 + 0.1, maxX = W / 2 - 0.1, minZ = -D / 2 + 0.1, maxZ = D / 2 - 0.05,
			camera = { pitch = 50, distance = 9, fov = 30 }, hide = [node.get_node("roof"), node.get_node("front")] }
		res.lights.append({ x = inn.lamp.x, y = inn.lamp.y, z = inn.lamp.z, kind = "lantern" })
	return res

# m에 초가 한 채를 그리고 충돌체·조명·앵커를 등록. o: w,d,hump,gourd,open,chimney
static func draw(m: C.M, o: Dictionary) -> Dictionary:
	var W: float = o.get("w", 6.0); var D: float = o.get("d", 4.0)
	var F := 0.4; var wallH := 1.85
	var top := F + wallH; var zf := D / 2; var t := 0.16
	var R := m.rng
	# 기단
	m.add("base", "stone", C.PA(Kit.box(W + 0.9, 0.55, D + 0.9, 0, F - 0.275, 0), C.STONE, 0.06, R), 0.03)
	for i in 9:
		var s := Kit.lump(0.2 + m.r() * 0.08, 0, R, 0.3, 0.7)
		m.add("base", "stone", C.P(Kit.xf(s, -W / 2 - 0.2 + (W + 0.4) * (i / 8.0), 0.1 + m.r() * 0.1, D / 2 + 0.45), 0xb0aa9e, 0x8a857b, 0.05, R), 0.02)
	# 기둥
	for x in [-W / 2, -W / 6, W / 6, W / 2]:
		m.add("front", "wood", C.PA(Kit.box(0.2, wallH + 0.05, 0.2, x, F + wallH / 2, zf), C.WOOD), 0.02)
		m.add("body", "wood", C.PA(Kit.box(0.2, wallH, 0.2, x, F + wallH / 2, -zf), C.WOOD), 0.02)
	for s in [-1, 1]: m.add("body", "wood", C.PA(Kit.box(0.2, wallH, 0.2, s * W / 2, F + wallH / 2, 0), C.WOOD), 0.02)
	# 뒷벽, 옆벽
	m.add("body", "mud", C.PA(Kit.box(W, wallH, t, 0, F + wallH / 2, -zf), C.MUD, 0.04, R), 0.02)
	for s in [-1, 1]: m.add("body", "mud", C.PA(Kit.box(t, wallH, D, s * W / 2, F + wallH / 2, 0), C.MUD, 0.04, R), 0.02)
	# 앞벽 3칸
	var bw := W / 3
	C.holed_wall(m, "front", -W / 2, -W / 2 + bw, F, top, -W / 3 - 0.36, -W / 3 + 0.36, F + 0.85, F + 1.45, zf, t, C.MUD)
	C.paper_panel(m, "front", -W / 3, F + 1.15, 0.72, 0.6, zf)
	C.holed_wall(m, "front", -bw / 2, bw / 2, F, top, -0.7, 0.7, F, F + 1.62, zf, t, C.MUD)
	if o.get("open", false):
		for s in [-1, 1]:
			var g := Kit.box(0.7, 1.6, 0.05, -s * 0.35, 0, 0)
			Kit.xf(g, s * 0.7, F + 0.81, zf + 0.06, 0, s * 1.2, 0)
			m.add("front", "paper", g, 0)
		for s in [-1, 1]: m.add("front", "wood", C.PA(Kit.box(0.08, 1.62, 0.2, s * 0.74, F + 0.81, zf), C.WOOD), 0.012)
		m.add("front", "wood", C.PA(Kit.box(1.56, 0.1, 0.2, 0, F + 1.66, zf), C.WOOD), 0.012)
		m.add("front", "wood", C.PA(Kit.box(1.4, 0.06, 0.2, 0, F + 0.03, zf), C.WOOD), 0.01)
		if o.get("dark_inside", true):
			# 실내가 없으면 열린 문 안쪽을 어두운 방으로 막음(장판 + 안벽)
			m.add("body", "flat", C.P(Kit.box(1.6, 1.7, 0.04, 0, F + 0.85, zf - 1.2), 0x4a3c2e, 0x2e251c), 0)
			m.add("body", "flat", C.P(Kit.box(1.6, 0.03, 1.2, 0, F + 0.02, zf - 0.6), 0xb8955a, 0x9a7a48), 0)
	else:
		C.paper_panel(m, "front", -0.35, F + 0.82, 0.66, 1.58, zf)
		C.paper_panel(m, "front", 0.35, F + 0.82, 0.66, 1.58, zf)
	C.holed_wall(m, "front", bw / 2, W / 2, F, top, W / 3 - 0.45, W / 3 + 0.45, F, F + 1.6, zf, t, C.MUD)
	# 부엌 널문
	m.add("front", "wood", C.P(Kit.box(0.9, 1.6, 0.06, W / 3, F + 0.8, zf - 0.02), 0x5a4432, 0x3f2f22, 0.04, R), 0.012)
	# 도리
	m.add("front", "wood", C.PA(Kit.box(W + 0.4, 0.18, 0.22, 0, top + 0.02, zf), C.WOOD), 0.02)
	m.add("body", "wood", C.PA(Kit.box(W + 0.4, 0.18, 0.22, 0, top + 0.02, -zf), C.WOOD), 0.02)
	# 툇마루
	m.add("front", "wood", C.PA(Kit.box(bw + 1.2, 0.1, 0.62, 0, F - 0.02, zf + 0.42), C.WOOD_L), 0.02)
	for s in [-1, 1]: m.add("front", "wood", C.PA(Kit.box(0.12, 0.4, 0.12, s * (bw / 2 + 0.45), F - 0.24, zf + 0.62), C.WOOD), 0.01)
	# 댓돌
	m.add("base", "stone", C.P(Kit.box(0.9, 0.18, 0.5, 0, 0.05, zf + 0.95), 0xb8b2a5, 0x8e897f, 0.05, R), 0.02)
	# 굴뚝
	if o.get("chimney", true):
		m.add("body", "stone", C.P(Kit.box(0.42, 1.5, 0.42, W / 2 + 0.55, 0.75 - 0.3, -zf + 0.4), 0x9d8a6a, 0x6f6452, 0.06, R), 0.025)
		m.add("body", "flat", C.P(Kit.box(0.56, 0.1, 0.56, W / 2 + 0.55, 1.2, -zf + 0.4), 0x6f6452), 0.02)
		m.circle(W / 2 + 0.55, -zf + 0.4, 0.4)
	# 초가 지붕
	var th := 1.12; var X := W / 2 + 0.75; var Z := D / 2 + 0.8; var Hh: float = 1.35 + float(o.get("hump", 0.0))
	var Ry := Hh / (1 - cos(th)); var eave := top + 0.12
	var dome := C.sphere(1, 15, 6, 0, TAU, 0, th)
	Kit.xf(dome, 0, eave - Ry * cos(th), 0, 0, 0, 0, X / sin(th), Ry, Z / sin(th))
	m.add("roof", "thatch", C.PA(dome, C.THATCH, 0.05, R), 0.05)
	var lip := Kit.cyl(1, 1.02, 0.34, 18)
	Kit.xf(lip, 0, eave - 0.15, 0, 0, 0, 0, X, 1, Z)
	m.add("roof", "thatch", C.PA(lip, C.THATCH_LIP, 0.04, R), 0.04)
	m.add("roof", "thatch", C.P(Kit.cyl(0.17, 0.17, W * 0.42, 8, 0, eave + Hh - 0.08, 0, 0, 0, PI / 2), 0xb39d6c, 0x8f7b52), 0.03)
	if o.get("gourd", false):
		var Rx := X / sin(th); var Rz := Z / sin(th); var cy := eave - Ry * cos(th)
		for q in [[-0.35, 0.35, 0.3], [0.1, 0.5, 0.36], [0.4, 0.2, 0.26]]:
			var px: float = q[0] * X; var pz: float = q[1] * Z; var gs: float = q[2]
			var py := cy + Ry * sqrt(maxf(0, 1 - pow(px / Rx, 2) - pow(pz / Rz, 2)))
			m.add("roof", "organic", C.P(Kit.xf(C.sphere(gs, 8, 5), px, py + gs * 0.55, pz, 0, 0, 0, 1, 0.8, 1), 0xf1ecd6, 0xc9c9a0), 0.015)
			m.add("roof", "leaf", C.P(Kit.xf(Kit.lump(gs * 0.9, 0, R, 0.2, 0.35), px + 0.3, py + 0.08, pz - 0.2), 0x7f9456, 0x56663a), 0.012)
	# 충돌·조명·앵커(웹 index.js와 같은 값)
	if o.get("open", false):
		var tt := 0.12
		m.box_c(-W / 2 - 0.1, W / 2 + 0.1, -D / 2 - 0.45, -D / 2 + tt)
		m.box_c(-W / 2 - 0.45, -W / 2 + tt, -D / 2, D / 2)
		m.box_c(W / 2 - tt, W / 2 + 0.45, -D / 2, D / 2)
		m.box_c(-W / 2 - 0.45, -0.72, D / 2 - tt, D / 2 + 0.75)
		m.box_c(0.72, W / 2 + 0.45, D / 2 - tt, D / 2 + 0.75)
	else:
		m.box_c(-W / 2 - 0.45, W / 2 + 0.45, -D / 2 - 0.45, D / 2 + 0.75)
	m.light(-W / 3, F + 1.15, zf + 0.2, "window")
	m.light(0, F + 0.95, zf + 0.2, "window")
	m.anchor("door", Vector3(0, 0, zf + 1.3))
	m.anchor("maru", Vector3(0, F, zf + 0.42))
	m.anchor("kitchen", Vector3(W / 3, 0, zf + 0.5))
	return { F = F, top = top, eave = eave, W = W, D = D }

# 외딴집 실내(웹 chogaInterior). part "interior"
static func interior(m: C.M, W: float, D: float, F: float) -> Dictionary:
	var R := m.rng
	var iw := W - 0.2; var id := D - 0.2
	m.add("interior", "flat", C.P(Kit.box(iw, 0.04, id, 0, F, 0), 0xd8b36b, 0xcaa25a, 0.04, R), 0)
	for i in range(-2, 3): m.add("interior", "flat", C.P(Kit.box(0.02, 0.005, id, i * iw / 5.2, F + 0.025, 0), 0x9c7a40), 0)
	m.add("interior", "flat", C.P(Kit.box(iw, 1.8, 0.02, 0, F + 0.92, -D / 2 + 0.1), 0xefe5cc, 0xddd0b0, 0.02, R), 0)
	for s in [-1, 1]: m.add("interior", "flat", C.P(Kit.box(0.02, 1.8, id, s * (W / 2 - 0.1), F + 0.92, 0), 0xefe5cc, 0xddd0b0, 0.02, R), 0)
	var cx := -W / 2 + 0.9; var cz := -D / 2 + 0.55
	m.add("interior", "wood", C.P(Kit.box(1.3, 0.75, 0.55, cx, F + 0.4, cz), 0x5c3c26, 0x43291a, 0.03, R), 0.02)
	for dx in [-0.4, 0, 0.4]: m.add("interior", "flat", C.P(Kit.box(0.12, 0.14, 0.02, cx + dx, F + 0.55, cz + 0.285), 0xc9a348), 0.005)
	m.add("interior", "flat", C.P(Kit.box(1.36, 0.05, 0.6, cx, F + 0.79, cz), 0x4a2f1d), 0.01)
	var bc := [0xa8483a, 0x3f5f7a, 0xe2d8bf, 0xc9a34a]
	for i in bc.size(): m.add("interior", "flat", C.P(Kit.box(1.0 - i * 0.04, 0.12, 0.6, cx, F + 0.88 + i * 0.12, cz), bc[i], bc[i], 0.03, R), 0.01)
	var tx := 0.75; var tz := -1.05
	m.add("interior", "wood", C.P(Kit.cyl(0.42, 0.42, 0.05, 12, tx, F + 0.32, tz), 0x7a5234, 0x6a4428), 0.015)
	m.add("interior", "wood", C.P(Kit.cyl(0.34, 0.3, 0.26, 12, tx, F + 0.16, tz), 0x5c3c26, 0x43291a), 0.01)
	m.add("interior", "flat", C.P(Kit.cyl(0.1, 0.07, 0.07, 10, tx - 0.12, F + 0.38, tz), 0xe8e2d2, 0xc8c0ac), 0.006)
	m.add("interior", "flat", C.P(Kit.cyl(0.09, 0.06, 0.06, 10, tx + 0.15, F + 0.38, tz + 0.08), 0xe8e2d2, 0xc8c0ac), 0.006)
	for q in [[tx - 0.75, tz + 0.15], [tx + 0.7, tz + 0.3]]: m.add("interior", "flat", C.P(Kit.box(0.55, 0.06, 0.55, q[0], F + 0.04, q[1]), 0x8a3e3a, 0x6e302c, 0.03, R), 0.01)
	var lx := W / 2 - 0.55; var lz := -D / 2 + 0.55
	m.add("interior", "flat", C.P(Kit.cyl(0.16, 0.2, 0.05, 8, lx, F + 0.03, lz), 0x5a3f2a), 0.01)
	m.add("interior", "flat", C.P(Kit.cyl(0.025, 0.03, 0.62, 6, lx, F + 0.34, lz), 0x5a3f2a), 0.008)
	m.add("interior", "flat", C.P(Kit.cyl(0.11, 0.06, 0.05, 8, lx, F + 0.67, lz), 0xe0d6be, 0xbfb49a), 0.008)
	m.add("interior", "glow", C.P(Kit.cone(0.03, 0.1, 6, lx, F + 0.75, lz), 0xffd27a, 0xff9a3a), 0)
	m.add("interior", "wood", C.PA(Kit.box(1.1, 0.05, 0.25, 0.9, F + 1.35, -D / 2 + 0.25), C.WOOD_L), 0.01)
	m.add("interior", "onggi", C.P(Kit.cyl(0.1, 0.12, 0.2, 10, 0.7, F + 1.48, -D / 2 + 0.25), 0x6a4430, 0x4a2e20), 0.006)
	m.add("interior", "onggi", C.P(Kit.cyl(0.08, 0.1, 0.16, 10, 1.05, F + 1.46, -D / 2 + 0.25), 0x6a4430, 0x4a2e20), 0.006)
	m.box_c(cx - 0.7, cx + 0.7, cz - 0.35, cz + 0.35)
	m.circle(tx, tz, 0.45)
	m.circle(lx, lz, 0.22)
	return { lamp = { x = lx, y = F + 0.8, z = lz } }
