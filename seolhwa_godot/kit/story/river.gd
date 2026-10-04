# 강 나루·문서 사건 소품(평양 「강을 판 사내」 등) — 이야기 총괄(story_director)이 조건이 맞을 때만 세운다. 원점 = 바닥 중심, 앞 = +z.
# PROP_MASTER: PRP_OFF_001(문서) PRP_OFF_003(먹통) PRP_OFF_004(도장) PRP_MKT_004(곡물 가마니) PRP_HOME_009(등잔·등롱). 기본 도형만 짜 맞춘다.
# params.kind:
#   deeds       짐 궤짝 위에 펼친 문서 두 장(누런 장지 한 장·흰 종이 한 장 — 관인 붉은 점)
#   paper_line  강창 뒤 종이 말리는 줄(기둥 둘 + 줄 + 얇은 흰 종이 여러 장, 감영 문서 꼴로 오린 것도)
#   scrape_kit  멍석 위 긁개·먹통·종이 부스러기·포갠 옛 공문
#   lantern     난간 곁 종이 등롱(밤 불빛 — 부벽루)
#   notice      나루의 방(감영 고시) — 기둥 둘 + 판 + 붙인 종이(결말 뒤)
#   cargo       나루에 다시 쌓인 짐(소금 가마니 · timber면 통나무 묶음)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

const PAPER_Y := [0xe2d3ae, 0xc9b88e]
const PAPER_W := [0xf1ece0, 0xd8d0bc]
const SEAL := [0xa8443c, 0x7a2e28]
const INK := [0x2b2622, 0x1a1614]
const MAT := [0xa89466, 0x7a6a48]
const SACK := [0xcbb98e, 0x9d8a62]
const LOG := [0x8a6a48, 0x5e4630]
const LAMP := [0xf2e2b8, 0xd9b878]

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 13)))
	var kind := String(params.get("kind", "deeds"))
	var fp := Vector2(1.2, 1.2)
	match kind:
		"deeds": fp = _deeds(m)
		"paper_line": fp = _paper_line(m)
		"scrape_kit": _scrape_kit(m)
		"lantern": _lantern(m)
		"notice": fp = _notice(m)
		"cargo": fp = _cargo(m, bool(params.get("timber", false)))
	return m.result("나루_" + kind, fp, false)

static func _sheet(m: C.M, w: float, d: float, x: float, y: float, z: float, ry: float, cols: Array) -> void:
	m.add("p", "cloth", C.PA(Kit.xf(Kit.box(w, 0.004, d), x, y, z, 0.0, ry, 0.0), cols), 0.0015)

static func _deeds(m: C.M) -> Vector2:
	var R := m.rng
	m.add("p", "wood", C.PA(Kit.box(1.0, 0.62, 0.7, 0, 0.31, 0), C.WOOD, 0.05, R), 0.01)   # 짐 궤짝
	m.add("p", "wood", C.PA(Kit.box(1.04, 0.05, 0.74, 0, 0.645, 0), C.WOOD_L, 0.04, R), 0.006)
	_sheet(m, 0.36, 0.5, -0.22, 0.675, 0.0, 0.05, PAPER_Y)
	_sheet(m, 0.36, 0.5, 0.22, 0.675, 0.02, -0.04, PAPER_W)
	for x in [-0.27, 0.25]:   # 관인
		m.add("p", "cloth", C.PA(Kit.xf(Kit.box(0.06, 0.003, 0.06), x, 0.68, 0.16), SEAL), 0.0)
	for k in 4:   # 글줄(먹)
		m.add("p", "cloth", C.PA(Kit.xf(Kit.box(0.012, 0.002, 0.3), -0.12 - k * 0.06, 0.679, -0.05), INK), 0.0)
		m.add("p", "cloth", C.PA(Kit.xf(Kit.box(0.012, 0.002, 0.3), 0.32 - k * 0.06, 0.679, -0.03), INK), 0.0)
	return Vector2(1.2, 1.0)

static func _paper_line(m: C.M) -> Vector2:
	var R := m.rng
	for x in [-1.5, 1.5]:
		m.add("p", "wood", C.PA(Kit.cyl(0.05, 0.06, 1.8, 5, x, 0.9, 0.0), C.WOOD, 0.05, R), 0.008)
	m.add("p", "cloth", C.PA(Kit.xf(Kit.cyl(0.01, 0.01, 3.0, 4), 0, 1.72, 0, 0, 0, PI / 2), [0x8a7a5a, 0x6a5a40]), 0.0)
	for i in 7:
		var x := -1.25 + i * 0.42 + R.between(-0.04, 0.04)
		var w := 0.34 if i % 3 != 1 else 0.28
		var h := 0.46 if i % 3 != 1 else 0.38
		var g := Kit.box(w, h, 0.004)
		Kit.xf(g, x, 1.72 - h * 0.5, R.between(-0.02, 0.02), R.between(-0.05, 0.05), R.between(-0.2, 0.2), 0.0)
		m.add("p", "cloth", C.PA(g, PAPER_W, 0.04, R), 0.0015)
	m.box_c(-1.6, 1.6, -0.1, 0.1)
	return Vector2(3.4, 0.8)

static func _scrape_kit(m: C.M) -> void:
	var R := m.rng
	m.add("p", "thatch", C.PA(Kit.box(1.3, 0.03, 0.9, 0, 0.015, 0), MAT, 0.06, R), 0.004)   # 멍석
	for k in 4:   # 포갠 옛 공문
		_sheet(m, 0.34, 0.46, -0.3 + k * 0.012, 0.035 + k * 0.006, -0.05 + k * 0.01, 0.1 * k, PAPER_Y if k % 2 == 0 else PAPER_W)
	m.add("p", "smooth", C.PA(Kit.xf(Kit.box(0.24, 0.012, 0.04), 0.2, 0.04, 0.15, 0, 0.6, 0), [0x9a9a96, 0x5e5e5a]), 0.0)   # 긁개 날
	m.add("p", "wood", C.PA(Kit.xf(Kit.box(0.1, 0.03, 0.04), 0.06, 0.045, 0.24, 0, 0.6, 0), C.WOOD), 0.0)
	m.add("p", "onggi", C.P(Kit.xf(C.onggi(0.07, 0.08, 8), 0.38, 0.03, -0.18), 0x2b2622, 0x1a1614), 0.004)   # 먹통
	for i in 9:   # 종이 부스러기
		m.add("p", "cloth", C.PA(Kit.xf(Kit.box(R.between(0.03, 0.07), 0.003, R.between(0.02, 0.05)), R.between(-0.5, 0.5), 0.035, R.between(-0.35, 0.35), 0, R.between(0, 3), 0), PAPER_W), 0.0)

static func _lantern(m: C.M) -> void:
	m.add("p", "wood", C.PA(Kit.cyl(0.025, 0.03, 0.9, 5, 0, 0.45, 0), C.WOOD), 0.004)
	m.add("p", "wood", C.PA(Kit.xf(Kit.box(0.28, 0.02, 0.02), 0.1, 0.9, 0), C.WOOD), 0.003)
	m.add("p", "cloth", C.PA(Kit.xf(Kit.cyl(0.11, 0.11, 0.26, 8), 0.22, 0.72, 0), LAMP), 0.004)
	m.add("p", "wood", C.PA(Kit.xf(Kit.cyl(0.12, 0.12, 0.02, 8), 0.22, 0.86, 0), C.WOOD), 0.002)
	m.light(0.22, 0.72, 0.0, "lantern")

static func _notice(m: C.M) -> Vector2:
	var R := m.rng
	for x in [-0.8, 0.8]:
		m.add("p", "wood", C.PA(Kit.cyl(0.06, 0.07, 2.0, 5, x, 1.0, 0.0), C.WOOD, 0.05, R), 0.008)
	m.add("p", "wood", C.PA(Kit.box(1.8, 0.9, 0.06, 0, 1.45, 0), C.WOOD_L, 0.05, R), 0.008)
	m.add("p", "wood", C.PA(Kit.box(2.0, 0.08, 0.2, 0, 1.94, 0), C.WOOD), 0.006)   # 비 가림
	m.add("p", "cloth", C.PA(Kit.box(0.9, 0.62, 0.01, -0.1, 1.45, 0.036), PAPER_Y, 0.03, R), 0.0015)
	for k in 6:
		m.add("p", "cloth", C.PA(Kit.box(0.02, 0.44, 0.004, 0.22 - k * 0.11, 1.48, 0.043), INK), 0.0)
	m.add("p", "cloth", C.PA(Kit.box(0.12, 0.12, 0.004, -0.42, 1.24, 0.043), SEAL), 0.0)
	m.box_c(-0.9, 0.9, -0.1, 0.1)
	return Vector2(2.2, 0.6)

static func _cargo(m: C.M, timber: bool) -> Vector2:
	var R := m.rng
	if timber:
		for i in 6:
			m.add("p", "wood", C.PA(Kit.xf(Kit.cyl(0.14, 0.14, 2.6, 7), 0, 0.14 + (i / 3) * 0.26, -0.3 + (i % 3) * 0.29 + (i / 3) * 0.14, PI / 2, 0, PI / 2), LOG, 0.05, R), 0.008)
		m.add("p", "cloth", C.PA(Kit.xf(C.torus(0.36, 0.02, 4, 12), 0.9, 0.3, 0.0, 0, PI / 2, 0), [0xb39a68, 0x7d6a48]), 0.0)
		m.box_c(-1.3, 1.3, -0.5, 0.5)
		return Vector2(2.8, 1.2)
	for i in 5:
		var x := -0.5 + (i % 3) * 0.5
		var y := 0.2 + (i / 3) * 0.36
		m.add("p", "cloth", C.P(Kit.xf(Kit.lump(0.26, 1, R, 0.15, 0.7), x + (i / 3) * 0.25, y, R.between(-0.1, 0.1)), 0xcbb98e, 0x9d8a62, 0.05, R), 0.008)
	m.box_c(-0.8, 0.8, -0.4, 0.4)
	return Vector2(1.8, 1.0)
