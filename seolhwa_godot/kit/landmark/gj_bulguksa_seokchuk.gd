# 불국사 앞 석축 + 청운교·백운교 + 자하문 + 범영루 — 경내 대지(높이 6m)를 함께 만든다(마당 윗면 = 걷기 면).
# 석축: 아래는 자연석 쌓기, 위는 가구식(기둥돌·면석) 2단. 청운교(아래 17단, 밑에 홍예)·백운교(위 16단) → 자하문(정면 3칸 팔작 문).
# 1870년 무렵 퇴락: 회랑은 무너져 초석만 남음(corridor_ruin), 다리 난간 일부 결실(가설), 단청 바램. 범영루는 18세기 중창본이 있었다고 보고 작게(가설).
# 원점 = 석축 정면 가운데 바닥(+z 남쪽이 다리 앞), 대지는 뒤(−z)로 depth m. params: seed, width(64), depth(52), height(6)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const S = preload("res://kit/landmark/_seong.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

# 계단 다리: 앞 끝 z0(바닥 y0) → 뒤 끝 z1(위 y1), 너비 w, 가운데 x. arch=true면 밑에 홍예
static func stair(b, rng: Kit.Rng, x: float, z0: float, y0: float, z1: float, y1: float, w: float, nsteps: int, arch: bool, rail_keep := 1.0) -> void:
	var run := z0 - z1
	var poly := PackedVector2Array()
	poly.append(Vector2(-run / 2, y0 - 0.3))
	if arch:
		var r := minf(1.3, (y1 - y0) * 0.33)
		poly.append(Vector2(-r, y0 - 0.3)); poly.append(Vector2(-r, y0 + 0.2))
		for k in range(1, 8):
			var a := PI - PI * k / 8
			poly.append(Vector2(cos(a) * r, y0 + 0.2 + sin(a) * r))
		poly.append(Vector2(r, y0 + 0.2)); poly.append(Vector2(r, y0 - 0.3))
	poly.append(Vector2(run / 2, y0 - 0.3)); poly.append(Vector2(run / 2, y1)); poly.append(Vector2(-run / 2 + 0.3, y0 + 0.1))
	var g := Co.extrude_xy(poly, w)
	Kit.xf(g, 0, 0, 0, 0, PI / 2)   # u(+x) → −z
	Kit.xf(g, x, 0, (z0 + z1) / 2)
	b.add("stone", Co.pnt(g, [0xc4bdac, 0x9c9585], 0.04, rng), 0.025)
	var sg := []
	for k in nsteps:
		var t := float(k + 1) / nsteps
		var zz := z0 - run * t; var yy := lerpf(y0, y1, t)
		sg.append(Kit.box(w - 0.5, 0.12, run / nsteps + 0.05, x, yy - 0.04, zz + run / nsteps / 2))
	b.add("stone", Co.pnt(Kit.merge(sg), [0xd2cbba, 0xb0a998], 0.03, rng), 0.0)
	# 양옆 돌난간(rail_keep 비율만 남음)
	for s in [-1, 1]:
		var a := Vector2(x + s * (w / 2 - 0.15), z0); var c := Vector2(x + s * (w / 2 - 0.15), z0 - run * rail_keep)
		var n := maxi(2, roundi(run * rail_keep / 1.6))
		var rg := []
		for i in n + 1:
			var t := float(i) / n * rail_keep
			rg.append(Kit.box(0.2, 1.0, 0.2, a.x, lerpf(y0, y1, t) + 0.45, z0 - run * t))
		var mid_t := rail_keep / 2
		var bar := Kit.box(0.12, 0.12, run * rail_keep / cos(atan2(y1 - y0, run)))
		Kit.xf(bar, a.x, lerpf(y0, y1, mid_t) + 0.9, z0 - run * mid_t, atan2(y1 - y0, run), 0, 0)
		rg.append(bar)
		b.add("stone", Co.pnt(Kit.merge(rg), [0xc8c2b4, 0xa49e90], 0.04, rng), 0.012)

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var Wt: float = float(params.get("width", 64.0)); var Dt: float = float(params.get("depth", 52.0)); var H: float = float(params.get("height", 6.0))
	var b := Kit.Batch.new(); var r := Kit.Batch.new()
	var h1 := H * 0.5
	var set := 4.0
	# 아래 단(자연석): z 0, 위 단(가구식): z −set
	b.add("stone", Co.pnt(Kit.box(Wt, h1 + 0.6, set + 0.2, 0, (h1 - 0.6) / 2, -set / 2), [0xa69f8e, 0x7c7666], 0.04, rng), 0.03)
	b.add("organic", Co.pnt(Kit.box(Wt, 0.08, set - 0.4, 0, h1 + 0.03, -set / 2 + 0.1), Hub.GRASS, 0.04, rng), 0.0)
	S.stone_face(b, rng, Vector2(-Wt / 2, 0.02), Vector2(Wt / 2, 0.02), 0.0, h1, Vector2(0, 1), 0.0, 0.45)
	b.add("stone", Co.pnt(Kit.box(Wt, H + 0.6, Dt - set, 0, (H - 0.6) / 2, -set - (Dt - set) / 2), [0xb4ad9c, 0x8a8474], 0.03, rng), 0.03)
	# 가구식 석축 면: 기둥돌(우주) + 면석 + 위 갑석
	var gz := -set + 0.03
	var nb := roundi(Wt / 2.6)
	var fg := []
	for i in nb + 1:
		var x := -Wt / 2 + Wt * i / nb
		fg.append(Kit.box(0.4, H - h1, 0.12, x, h1 + (H - h1) / 2, gz + 0.04))
	fg.append(Kit.box(Wt + 0.3, 0.3, 0.6, 0, H - 0.1, gz))
	fg.append(Kit.box(Wt + 0.2, 0.3, 0.3, 0, h1 + 0.12, gz + 0.1))
	b.add("stone", Co.pnt(Kit.merge(fg), [0xd0c9b8, 0xaca594], 0.04, rng), 0.015)
	for i in nb:
		var x := -Wt / 2 + Wt * (i + 0.5) / nb
		b.add("stone", Co.pnt(Co.vplane(Wt / nb - 0.5, H - h1 - 0.5, x, h1 + (H - h1) / 2, gz + 0.01), [0xc4bdac, 0xa49d8c], 0.05, rng), 0.0)
	# 마당 윗면(흙)
	b.add("mud", Co.pnt(Kit.box(Wt - 0.4, 0.06, Dt - set - 0.6, 0, H + 0.02, -set - (Dt - set) / 2 - 0.2), [0xb9b093, 0xa49a7c], 0.04, rng), 0.0)
	# 청운교(아래, 홍예) + 백운교(위)
	var sx := 0.0
	stair(b, rng, sx, 7.5, 0.0, 0.0, h1, 4.0, 17, true, 0.7)
	stair(b, rng, sx, -0.2, h1, -set - 0.2, H, 3.6, 16, false, 1.0)
	# 서쪽 연화교·칠보교(작게) — 안양문 쪽
	var wx := -Wt * 0.3
	stair(b, rng, wx, 5.0, 0.0, 0.0, h1, 2.4, 10, false, 0.5)
	stair(b, rng, wx, -0.2, h1, -set - 0.2, H, 2.2, 8, false, 0.6)
	# 자하문(紫霞門): 정면 3칸 팔작, 가운데 칸 문
	var gi := Co.hall(b, r, { bays = [2.6, 3.4, 2.6], depth = 4.6, dbays = 2, F = H + 0.4, H = 3.2, fronts = ["wall", "gate", "wall"], back = "none", sides = "wall",
		roof = "paljak", ox = 1.4, oz = 1.3, rise = 2.1, lift = 0.6, bracket = "ikgong", col_r = 0.2, cz = -set - 3.0, base = false,
		col_color = Hub.FADED_R, band = Hub.FADED_G, roof_nx = 16, roof_nz = 10, floor = false }, rng)
	b.add("stone", Co.pnt(Kit.box(10.0, 0.45, 6.4, 0, H + 0.2, -set - 3.0), Co.STONE_L, 0.04, rng), 0.02)
	# 범영루(동쪽 석축 끝 위, 돌기둥 받침 위 작은 누각 — 가설)
	var bx := Wt * 0.22
	b.add("stone", Co.pnt(Kit.box(2.2, H - h1, 2.2, bx, h1 + (H - h1) / 2, gz + 1.3), [0xc8c1b0, 0x9e9786], 0.04, rng), 0.02)
	var pi := Hub.pavilion(b, r, { bays = [3.0], depth = 3.0, dbays = 1, F = H + 0.5, H = 2.6, roof = "paljak", ox = 1.0, oz = 1.0, rise = 1.7, lift = 0.6,
		bracket = "ikgong", col_r = 0.15, cx = bx, cz = gz - 0.2, under = "none", plinth = false, stair = false, col_color = Hub.FADED_R, band = Hub.FADED_G, rail_gaps = [["N", 0.0, 0.6]], roof_nx = 12, roof_nz = 10 }, rng)
	# 무너진 회랑 초석 줄(대지 둘레)
	if params.get("corridor_ruin", true):
		var cg := []
		var hw := Wt / 2 - 2.0
		var zf := -set - 1.5; var zb := -Dt + 2.0
		var x := -hw
		while x <= hw:
			if absf(x) > 6.0 and absf(x - wx) > 2.0:
				cg.append(Kit.cyl(0.32, 0.38, 0.25, 6, x, H + 0.1, zf))
			cg.append(Kit.cyl(0.32, 0.38, 0.25, 6, x, H + 0.1, zb))
			x += 3.2
		var z := zf
		while z >= zb:
			cg.append(Kit.cyl(0.32, 0.38, 0.25, 6, -hw, H + 0.1, z)); cg.append(Kit.cyl(0.32, 0.38, 0.25, 6, hw, H + 0.1, z))
			z -= 3.2
		b.add("stone", Co.pnt(Kit.merge(cg), Co.STONE_L, 0.05, rng), 0.012)
	var cols := [
		{ type = "box", minX = -Wt / 2, maxX = sx - 2.0, minZ = -set - 0.3, maxZ = 0.3 }, { type = "box", minX = sx + 2.0, maxX = Wt / 2, minZ = -set - 0.3, maxZ = 0.3 },
		{ type = "box", minX = -5.0, maxX = -1.7, minZ = -set - 4.4, maxZ = -set - 1.6 }, { type = "box", minX = 1.7, maxX = 5.0, minZ = -set - 4.4, maxZ = -set - 1.6 },
	]
	# 걷기 면(§8): 청운교·백운교 경사 + 경내 마당(높이 H)
	var walk := [
		{ minX = sx - 1.6, maxX = sx + 1.6, minZ = -set - 0.2, maxZ = 7.5, z = [-set - 0.2, -0.2, 0.0, 7.5], y = [H, h1, h1, 0.0] },
		{ minX = -Wt / 2 + 0.5, maxX = Wt / 2 - 0.5, minZ = -Dt + 0.5, maxZ = -set - 0.2, z = [-Dt + 0.5, -set - 0.2], y = [H + 0.05, H + 0.05] },
	]
	return {
		node = Co.node2("불국사석축", b, r), colliders = cols, lights = [{ x = 0.0, y = H + 2.0, z = -set + 0.5, kind = "lantern" }], occluder = true,
		footprint = Vector2(Wt, Dt + 8.0), anchors = { stair_foot = Vector3(sx, 0, 9.0), jahamun = Vector3(0, H, -set - 6.5), yard = Vector3(0, H, -Dt * 0.5) },
		walk = walk, top_y = H,
	}
