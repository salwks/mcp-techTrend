# 역참 길가 문 앞 — 말 매는 가로대(말뚝 둘 + 가로대) + 들통 + 현판 기둥(驛 — 글씨는 station_life.gd가 Label3D로) + 역 깃발(노란 바탕 붉은 테).
# 마방(kit/station/mabang.gd)과 따로 놓는다: 큰길이 마방 어느 쪽으로 지나도 길가(도착·말 타는 자리 곁)에 서게. 늘 ry = 0(정면 +z = 카메라 쪽).
# params: seed, hub(false: 깃대 높게)
# 앵커(plan()과 같은 값): rail(가로대 가운데), wait(안장 얹은 말 — 가로대 앞, 옆모습으로 서쪽을 봄), brush(말 머리 앞 마부 — 동쪽을 봄),
#   sign(현판 글씨 자리), flag(깃발 글씨 자리)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func plan(params: Dictionary) -> Dictionary:
	return {
		rail = Vector3(0, 0, 0),
		wait = Vector3(0.25, 0, 0.85),
		brush = Vector3(-2.15, 0, 1.0),
		sign = Vector3(3.6, 2.05, 0.05),
		flag = Vector3(-3.4, 5.0, -0.2),
	}

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var p := plan(params)
	var hub := bool(params.get("hub", false))
	# 가로대
	for s in [-1, 1]:
		m.add("p", "wood", C.PA(Kit.cyl(0.09, 0.1, 1.25, 6, s * 1.7, 0.62, 0), C.WOOD), 0.012)
		m.circle(s * 1.7, 0, 0.15)
	m.add("p", "wood", C.P(Kit.cyl(0.055, 0.055, 3.7, 6, 0, 1.1, 0, 0, 0, PI / 2), 0x8a6a48, 0x6e5238), 0.01)
	# 들통·여물 바가지
	m.add("p", "wood", C.P(Kit.cyl(0.24, 0.2, 0.4, 8, 2.3, 0.2, -0.3), 0x7a5c3e, 0x5a4430, 0.04), 0.01)
	m.add("p", "flat", C.P(Kit.cyl(0.21, 0.21, 0.02, 8, 2.3, 0.39, -0.3), 0x4a5a5e), 0)
	m.circle(2.3, -0.3, 0.28)
	# 현판 기둥
	var sg: Vector3 = p.sign
	for q in [-1, 1]:
		m.add("p", "wood", C.PA(Kit.box(0.14, 2.6, 0.14, sg.x + q * 0.95, 1.3, sg.z - 0.1), C.WOOD), 0.012)
		m.circle(sg.x + q * 0.95, sg.z - 0.1, 0.12)
	m.add("p", "wood", C.P(Kit.box(1.8, 0.62, 0.08, sg.x, sg.y, sg.z - 0.06), 0x3e2e22, 0x2e2219, 0.02), 0.015)
	m.add("p", "wood", C.PA(Kit.box(2.2, 0.12, 0.2, sg.x, 2.62, sg.z - 0.1), C.WOOD), 0.012)
	# 역 깃발(장대 + 세 조각으로 살짝 굽은 깃발 + 붉은 테)
	var f: Vector3 = p.flag
	var px := f.x - 0.6; var pz := f.z
	var H := 6.8 if hub else 6.0
	m.add("p", "wood", C.P(Kit.cyl(0.07, 0.1, H, 6, px, H / 2, pz), 0x7a5c3e, 0x5a4430, 0.03), 0.012)
	m.add("p", "stone", C.P(Kit.box(0.6, 0.35, 0.6, px, 0.17, pz), 0x9d978b, 0x77726a, 0.05), 0.015)
	m.circle(px, pz, 0.35)
	m.add("p", "wood", C.P(Kit.box(1.5, 0.06, 0.06, px + 0.7, H - 0.25, pz), 0x6a5038), 0.008)
	var fy := H - 0.3
	for k in 3:
		var y0 := fy - k * 0.72; var y1 := y0 - 0.72
		m.add("p", "cloth", C.P(Kit.box(1.3, y0 - y1, 0.03, px + 0.75, (y0 + y1) / 2, pz + 0.08 * sin(float(k) * 1.4)), 0xd8b44a, 0xc29a36, 0.03), 0.012)
	for k in [0.06, 1.38]:
		m.add("p", "cloth", C.P(Kit.box(0.1, 2.16, 0.04, px + k + 0.1, fy - 1.08, pz), 0xa8443c, 0x8a3530), 0)
	m.add("p", "cloth", C.P(Kit.box(1.36, 0.1, 0.04, px + 0.75, fy - 2.16, pz), 0xa8443c, 0x8a3530), 0)
	for k in plan(params): m.anchor(k, p[k])
	return m.result("역참 문 앞", Vector2(9.0, 2.4), false)
