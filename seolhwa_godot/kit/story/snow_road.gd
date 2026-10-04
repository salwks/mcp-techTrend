# 눈길 사건 소품(함흥 「돌아오지 않는 전갈」·R05 평양→함흥 노정) — 이야기 총괄(story_director)이 조건이 맞을 때만 세운다. 원점 = 바닥 중심, 앞 = +z.
# PROP_MASTER: PRP_ROAD_001(짐수레) PRP_ROAD_003(짚신·봇짐) PRP_MKT_004(곡물 가마니) PRP_ROAD_006(말) — 새 대형 모델 없이 기본 도형을 짜 맞춘다.
# params.kind:
#   horse    눈 속에 쓰러진 짐말(옆으로 누움, 길마만 남고 짐은 벗겨 감) + 반쯤 덮은 눈 둔덕
#   cart     엎어진 짐수레(바퀴 하나 빠짐) + 터진 가마니 둘·흩어진 곡식 + 끊긴 끌채 끈
#   luggage  눈에 반쯤 묻힌 봇짐(끈 한 가닥이 눈 위로) — dug=true면 파낸 뒤(봇짐이 위에, 눈 무더기 곁에)
#   pouch    길 위의 전갈 주머니(가죽 통 + 붉은 끈 — 감영 인이 찍힌 덮개)
#   fire     눈 위 작은 모닥불(돌 둘레·장작·불빛) — 서낭당 돌담 밑 쉼 자리
#   mound    눈 둔덕(무언가 덮인 자리 — 파 볼 수 있다)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

const HIDE := [0x6a5442, 0x4a3a2c]
const HIDE_D := [0x4a3a2c, 0x30261c]
const MANE := [0x2b2420, 0x1c1714]
const SNOW := [0xf4f2ec, 0xd8d6d0]
const SACK := [0xc9b88a, 0x9c8a60]
const RICE := [0xe8e2cc, 0xc8c0a4]
const LEATHER := [0x6e4a2e, 0x4a3020]
const RED := [0xa8443c, 0x7a2a24]
const CLOTH := [0x5d6a78, 0x3e4854]
const ROCK := [0x8e897e, 0x5e5a52]
const FIRE := [0xffb050, 0xe06a28]

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 6001)))
	var kind := String(params.get("kind", "horse"))
	var fp := Vector2(1.5, 1.5)
	match kind:
		"horse": fp = _horse(m)
		"cart": fp = _cart(m)
		"luggage": _luggage(m, bool(params.get("dug", false)))
		"pouch": _pouch(m)
		"fire": _fire(m)
		"mound": _mound(m, float(params.get("r", 0.7)))
	return m.result("눈길_" + kind, fp, false)

# 쓰러진 짐말: 몸통(누운 통) + 목·머리 + 네 다리(뻗음) + 길마(나무 안장틀) + 덮인 눈
static func _horse(m: C.M) -> Vector2:
	var R := m.rng
	var body := Kit.lump(0.62, 1, R, 0.08, 0.72)
	Kit.xf(body, 0, 0.42, 0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.9)
	m.add("p", "cloth", C.PA(body, HIDE, 0.05, R), 0.02)
	# 목·머리(땅에 떨군)
	m.add("p", "cloth", C.PA(Kit.limb(Vector3(0, 0.55, 1.0), Vector3(0.15, 0.3, 1.75), 0.24, 0.17, 7), HIDE), 0.015)
	var head := Kit.lump(0.2, 0, R, 0.1, 1.0)
	Kit.xf(head, 0.25, 0.2, 2.05, 0.0, 0.3, 0.0, 1.0, 0.8, 1.9)
	m.add("p", "cloth", C.PA(head, HIDE_D, 0.05, R), 0.012)
	m.add("p", "cloth", C.PA(Kit.limb(Vector3(-0.05, 0.75, 1.0), Vector3(0.05, 0.62, 1.55), 0.05, 0.04, 5), MANE), 0.006)
	# 다리 넷(옆으로 뻗음)
	for i in 4:
		var z := -0.75 + (i % 2) * 0.25 + (1.1 if i >= 2 else 0.0)
		var a := Vector3(0.35, 0.3 + (i % 2) * 0.12, z)
		m.add("p", "cloth", C.PA(Kit.limb(a, a + Vector3(0.95, -0.18, 0.12 * (i - 1.5)), 0.08, 0.05, 5), HIDE_D), 0.008)
	# 꼬리
	m.add("p", "cloth", C.PA(Kit.limb(Vector3(0, 0.45, -1.15), Vector3(0.2, 0.12, -1.6), 0.06, 0.03, 5), MANE), 0.004)
	# 길마(빈 나무틀) — 짐은 벗겨 갔다
	for s in [-1, 1]:
		m.add("p", "wood", C.PA(Kit.xf(Kit.box(0.08, 0.5, 0.08), -0.1, 0.92, 0.15 * s, 0.0, 0.0, 0.5), C.WOOD), 0.006)
	m.add("p", "wood", C.PA(Kit.xf(Kit.box(0.5, 0.06, 0.5), -0.25, 1.05, 0.0, 0.0, 0.0, 0.5), C.WOOD), 0.006)
	# 덮인 눈(몸통 위·옆 둔덕)
	for i in 4:
		var g := Kit.lump(0.4 + R.between(0, 0.2), 0, R, 0.2, 0.35)
		Kit.xf(g, -0.45 + R.between(-0.1, 0.1), 0.1, -1.0 + i * 0.7)
		m.add("p", "cloth", C.PA(g, SNOW, 0.03, R), 0.0)
	m.circle(0, 0, 0.9)
	return Vector2(2.8, 4.0)

# 엎어진 짐수레
static func _cart(m: C.M) -> Vector2:
	var R := m.rng
	var old := m.push(0, 0, 0, 0.0)
	# 바닥판(옆으로 누움)
	m.add("p", "wood", C.PA(Kit.xf(Kit.box(1.3, 0.08, 2.4), 0.0, 0.66, 0.0, 0.0, 0.0, 1.25), C.WOOD_L, 0.05, R), 0.012)
	for s in [-1, 1]:   # 옆널
		m.add("p", "wood", C.PA(Kit.xf(Kit.box(0.06, 0.4, 2.4), -0.15 + 0.35 * s, 0.45 + 0.25 * s, 0.0, 0.0, 0.0, 1.25), C.WOOD, 0.05, R), 0.01)
	# 바퀴 하나는 축에, 하나는 빠져 눈에
	m.add("p", "wood", C.PA(Kit.xf(C.torus(0.55, 0.06, 5, 14), 0.55, 1.05, 0.6, 0.0, 0.0, 1.25 + PI / 2), C.WOOD), 0.008)
	m.add("p", "wood", C.PA(Kit.xf(C.torus(0.55, 0.06, 5, 14), -1.4, 0.07, 1.6, PI / 2, 0.0, 0.0), C.WOOD), 0.008)
	m.add("p", "wood", C.PA(Kit.xf(Kit.cyl(0.05, 0.05, 1.3, 5), 0.3, 0.9, 0.6, 0.0, 0.0, 1.25 + PI / 2), C.WOOD), 0.004)
	# 끌채 둘(한쪽 끈 끊김)
	for s in [-1, 1]:
		m.add("p", "wood", C.PA(Kit.limb(Vector3(-0.2 + 0.25 * s, 0.4, 1.2), Vector3(-0.4 + 0.3 * s, 0.08, 2.9), 0.05, 0.04, 5), C.WOOD), 0.004)
	m.add("p", "cloth", C.PA(Kit.limb(Vector3(-0.1, 0.1, 2.9), Vector3(0.5, 0.03, 3.3), 0.02, 0.02, 4), [0xb39a68, 0x7d6a48]), 0.0)
	m.pop(old)
	# 터진 가마니 둘 + 흩어진 곡식
	for i in 2:
		var g := Kit.lump(0.38, 1, R, 0.15, 0.62)
		Kit.xf(g, -1.0 + i * 0.6, 0.22, -1.2 - i * 0.5, 0.0, R.between(0, PI), 0.3)
		m.add("p", "thatch", C.PA(g, SACK, 0.06, R), 0.01)
	for i in 6:
		var g2 := Kit.lump(0.16, 0, R, 0.3, 0.18)
		Kit.xf(g2, -1.3 + R.between(-0.4, 1.2), 0.02, -1.6 + R.between(-0.5, 0.8))
		m.add("p", "flat", C.PA(g2, RICE, 0.03, R), 0.0)
	m.box_c(-1.0, 1.2, -1.3, 1.3)
	return Vector2(4.0, 5.0)

static func _luggage(m: C.M, dug: bool) -> void:
	var R := m.rng
	if not dug:
		_mound(m, 0.75)
		# 눈 위로 삐져나온 멜빵 한 가닥과 보따리 귀퉁이
		m.add("p", "cloth", C.PA(Kit.limb(Vector3(0.2, 0.3, 0.1), Vector3(0.65, 0.04, 0.45), 0.03, 0.025, 4), [0x8a6a42, 0x5a4428]), 0.002)
		m.add("p", "cloth", C.PA(Kit.xf(Kit.lump(0.16, 0, R, 0.2, 0.6), -0.25, 0.35, 0.15), CLOTH, 0.05, R), 0.004)
		return
	_mound(m, 0.55)
	var old := m.push(0.75, 0, 0.2, 0.4)
	m.add("p", "cloth", C.P(Kit.xf(Kit.lump(0.3, 1, R, 0.25, 0.75), 0, 0.22, 0), 0x5d6a78, 0x3e4854, 0.05, R), 0.012)
	m.add("p", "cloth", C.PA(Kit.xf(Kit.box(0.14, 0.12, 0.08), 0.0, 0.46, 0.0, 0.0, 0.5, 0.0), CLOTH), 0.006)
	m.add("p", "cloth", C.PA(Kit.limb(Vector3(0.1, 0.4, 0.1), Vector3(0.45, 0.04, 0.35), 0.03, 0.025, 4), [0x8a6a42, 0x5a4428]), 0.002)
	m.pop(old)

static func _pouch(m: C.M) -> void:
	var R := m.rng
	m.add("p", "cloth", C.PA(Kit.xf(Kit.cyl(0.07, 0.07, 0.42, 9), 0, 0.07, 0, PI / 2, 0.5, 0), LEATHER, 0.04, R), 0.006)
	m.add("p", "cloth", C.PA(Kit.xf(Kit.cyl(0.075, 0.075, 0.06, 9), 0.1, 0.07, 0.17, PI / 2, 0.5, 0), RED), 0.003)
	m.add("p", "cloth", C.PA(Kit.limb(Vector3(-0.1, 0.08, -0.15), Vector3(-0.45, 0.02, 0.1), 0.012, 0.012, 4), RED), 0.0)
	# 덮개에 찍힌 인(붉은 네모)
	m.add("p", "flat", C.PA(Kit.xf(Kit.box(0.06, 0.004, 0.06), 0.02, 0.145, -0.02, 0.0, 0.5, 0.0), [0xb8322a, 0x8a1e18]), 0.0)
	_mound(m, 0.3)

static func _fire(m: C.M) -> void:
	var R := m.rng
	for i in 7:
		var a := i * TAU / 7
		m.add("p", "stone", C.PA(Kit.xf(Kit.lump(0.11, 0, R, 0.3, 0.7), cos(a) * 0.4, 0.06, sin(a) * 0.4), ROCK, 0.05, R), 0.01)
	for i in 4:
		var a := i * TAU / 4 + 0.3
		m.add("p", "wood", C.PA(Kit.limb(Vector3(cos(a) * 0.32, 0.03, sin(a) * 0.32), Vector3(0, 0.22, 0), 0.04, 0.03, 5), C.WOOD), 0.004)
	m.add("p", "smooth", C.PA(Kit.xf(Kit.cone(0.16, 0.38, 7), 0, 0.12, 0), FIRE), 0.0)
	m.light(0, 0.5, 0, "torch")

static func _mound(m: C.M, r: float) -> void:
	var R := m.rng
	var g := Kit.lump(r, 1, R, 0.18, 0.42)
	Kit.xf(g, 0, 0.05, 0)
	m.add("p", "cloth", C.PA(g, SNOW, 0.03, R), 0.0)
