# 바닷가 사건 소품(황주 「빈 배의 값」 등) — 이야기 총괄(story_director)이 조건이 맞을 때만 세운다. 원점 = 바닥 중심, 앞 = +z.
# PROP_MASTER: PRP_WAT_002(어선 — 부서진 잔해) PRP_WAT_003(노·닻·밧줄 더미) PRP_WAT_004(그물) PRP_RIT_004(제상·의식 그릇)
#   PRP_OFF_008(박규상 표식 — 운송장은 story/park_mark를 따로 얹는다). 새 대형 모델 없이 기본 도형을 짜 맞춘다.
# params.kind:
#   wreck      갯가에 밀려 올라온 장삿배 잔해(뱃전 판자·부러진 돛대·찢긴 돛·엎어진 궤짝)
#   coins      엽전 꾸러미(꿰미 셋)와 셈 쪽지 — 툇마루·소반 위(dy로 올린다)
#   rite_stone 벼랑 끝 옛 제의 바위(앞면이 닳은 새김 — 짚 인형·시루·배 모양) + 넓적한 제물 돌
#   straw      짚 인형을 태운 짚배(결말 A: 사람 대신 띄우는 옛 방식)
#   bundle     중개인의 보따리와 작은 문서 궤
#   ropes      그물 말리는 걸대 + 밧줄 사리(밧줄을 얻는 자리)
#   ribbon     바위틈에 걸린 붉은 댕기(결말 C)
#   bowl       정화수 한 그릇을 올린 작은 상(기다리는 집 — 결말 C)
#   floats     갯가에 밀려 올라온 표식(나무 찌 + 붉은 천) n개 — 물살 표식(scripts/story/drift.gd)이 닿은 자리
#   blanket    거적과 마른 옷가지(구조한 뒤 어부 집 앞)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

const PLANK := [0x7a6248, 0x4e3c2a]
const PLANK_W := [0x5e5446, 0x3a342a]   # 젖은 판자
const SAIL := [0xc8bea4, 0x9a907a]
const ROPE := [0xb39a68, 0x7d6a48]
const RED := [0xb8322a, 0x7a1e18]
const BRASS := [0x9a7a3a, 0x5e4a22]
const STRAW := [0xd6bf84, 0x9d8656]
const ROCK := [0x8e897e, 0x5e5a52]
const CLOTH := [0xe2dccb, 0xb8b09c]
const MAT := [0xa89466, 0x7a6a48]

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 11)))
	var kind := String(params.get("kind", "wreck"))
	var fp := Vector2(1.5, 1.5)
	match kind:
		"wreck": fp = _wreck(m)
		"coins": _coins(m)
		"rite_stone": fp = _rite_stone(m)
		"straw": _straw(m)
		"bundle": _bundle(m)
		"ropes": fp = _ropes(m)
		"ribbon": _ribbon(m)
		"bowl": _bowl(m)
		"floats": fp = _floats(m, int(params.get("n", 2)))
		"blanket": _blanket(m)
	return m.result("바닷가_" + kind, fp, false)

static func _wreck(m: C.M) -> Vector2:
	var R := m.rng
	# 뱃전 한쪽(휜 판자 다섯 줄)이 모래에 반쯤 묻혔다
	for i in 5:
		var g := Kit.box(4.2 - i * 0.35, 0.06, 0.32)
		Kit.xf(g, 0.2 * i, 0.12 + i * 0.22, -0.4 + i * 0.05, 0.55 + i * 0.06, 0.25, 0.08)
		m.add("p", "wood", C.PA(g, PLANK_W if i < 2 else PLANK, 0.06, R), 0.012)
	# 늑골 셋
	for k in 3:
		m.add("p", "wood", C.PA(Kit.xf(Kit.box(0.12, 1.3, 0.12), -1.2 + k * 1.1, 0.5, -0.7, 0.0, 0.25, 0.5), PLANK, 0.05, R), 0.01)
	# 부러진 돛대와 찢긴 돛
	m.add("p", "wood", C.PA(Kit.limb(Vector3(1.6, 0.1, 0.9), Vector3(-1.4, 0.35, 1.9), 0.12, 0.09, 6), PLANK), 0.012)
	var sail := Kit.box(1.6, 0.03, 1.1)
	Kit.xf(sail, -0.6, 0.12, 1.7, 0.08, 0.5, 0.06)
	m.add("p", "cloth", C.PA(sail, SAIL, 0.05, R), 0.006)
	# 엎어진 궤짝(뚜껑 열림)
	m.add("p", "wood", C.PA(Kit.xf(Kit.box(0.7, 0.45, 0.5), 2.2, 0.22, 0.6, 0.0, 0.6, 0.0), PLANK, 0.05, R), 0.01)
	m.add("p", "wood", C.PA(Kit.xf(Kit.box(0.72, 0.05, 0.5), 2.55, 0.05, 1.15, 0.0, 0.9, 0.0), PLANK_W), 0.006)
	# 밧줄 토막
	m.add("p", "cloth", C.PA(Kit.xf(C.torus(0.3, 0.035, 4, 14), 1.4, 0.05, -1.2, 0.0, 0.0, 0.0), ROPE), 0.004)
	m.box_c(-2.0, 2.6, -1.2, 0.6)
	return Vector2(5.5, 4.0)

static func _coins(m: C.M) -> void:
	var R := m.rng
	m.add("p", "wood", C.PA(Kit.cyl(0.26, 0.26, 0.04, 12, 0, 0.02, 0), C.WOOD_L, 0.04, R), 0.006)   # 소반
	for s in 3:
		for k in 9:
			var a := k * 0.34 + s * 0.5
			var g := Kit.cyl(0.028, 0.028, 0.008, 8)
			Kit.xf(g, -0.12 + s * 0.12 + cos(a) * 0.05, 0.05 + k * 0.004, sin(a) * 0.07, PI / 2 * 0.9, a, 0)
			m.add("p", "smooth", C.PA(g, BRASS), 0.0)
	m.add("p", "cloth", C.PA(Kit.xf(Kit.box(0.12, 0.004, 0.2), 0.16, 0.06, 0.08, 0.0, 0.4, 0.0), [0xeee6d0, 0xd2c8ae]), 0.002)   # 셈 쪽지

static func _rite_stone(m: C.M) -> Vector2:
	var R := m.rng
	var g := Kit.lump(0.6, 1, R, 0.18, 1.6)
	Kit.xf(g, 0, 0.75, 0, 0.0, 0.2, 0.0, 1.0, 1.0, 0.55)
	m.add("p", "rock", C.PA(g, ROCK, 0.06, R), 0.02)
	# 닳은 새김(짚 인형·시루·배) — 얕은 홈
	for i in 4:
		m.add("p", "flat", C.PA(Kit.xf(Kit.box(0.05, 0.32 - i * 0.04, 0.02), -0.2 + i * 0.13, 0.85, 0.34, 0.0, 0.0, 0.2 * (i - 1.5)), [0x6a665c, 0x5a564e]), 0.0)
	m.add("p", "flat", C.PA(Kit.xf(Kit.box(0.42, 0.04, 0.02), 0.0, 1.12, 0.33, 0.0, 0.0, 0.0), [0x6a665c, 0x5a564e]), 0.0)
	# 넓적한 제물 돌
	m.add("p", "rock", C.PA(Kit.xf(Kit.cyl(0.55, 0.62, 0.22, 9), 0.1, 0.11, 0.9), ROCK, 0.05, R), 0.015)
	m.circle(0, 0, 0.6)
	return Vector2(1.6, 2.2)

static func _straw(m: C.M) -> void:
	var R := m.rng
	for i in 7:   # 짚단을 묶은 작은 배
		m.add("p", "thatch", C.PA(Kit.xf(Kit.cyl(0.07, 0.07, 1.2, 5), -0.3 + i * 0.1, 0.07, 0.0, PI / 2, 0, 0), STRAW, 0.06, R), 0.004)
	m.add("p", "thatch", C.PA(Kit.xf(Kit.lump(0.11, 0, R, 0.2, 1.0), 0, 0.42, 0.0), STRAW), 0.006)   # 머리
	m.add("p", "thatch", C.PA(Kit.xf(Kit.cyl(0.08, 0.1, 0.36, 6), 0, 0.22, 0.0), STRAW), 0.006)        # 몸
	m.add("p", "cloth", C.PA(Kit.xf(Kit.box(0.26, 0.05, 0.03), 0, 0.3, 0.06), RED), 0.003)           # 붉은 띠
	m.add("p", "onggi", C.P(Kit.xf(C.onggi(0.09, 0.12, 8), 0.4, 0.14, 0.0), 0xd8ccb0, 0xa89c80), 0.004)   # 쌀 한 그릇

static func _bundle(m: C.M) -> void:
	var R := m.rng
	m.add("p", "cloth", C.P(Kit.xf(Kit.lump(0.32, 1, R, 0.25, 0.7), 0, 0.22, 0), 0x5a4e44, 0x3a322a, 0.05, R), 0.012)
	m.add("p", "cloth", C.PA(Kit.xf(Kit.box(0.14, 0.12, 0.08), 0.0, 0.46, 0.0, 0.0, 0.5, 0.0), [0x5a4e44, 0x3a322a]), 0.006)   # 매듭
	m.add("p", "wood", C.PA(Kit.box(0.38, 0.18, 0.26, 0.55, 0.09, 0.15, 0.3), C.WOOD, 0.05, R), 0.008)   # 문서 궤
	m.add("p", "smooth", C.PA(Kit.box(0.06, 0.04, 0.02, 0.55, 0.15, 0.29, 0.3), BRASS), 0.0)

static func _ropes(m: C.M) -> Vector2:
	var R := m.rng
	for x in [-1.1, 1.1]:   # 걸대
		m.add("p", "wood", C.PA(Kit.cyl(0.05, 0.06, 1.7, 5, x, 0.85, 0.0), C.WOOD, 0.05, R), 0.008)
	m.add("p", "wood", C.PA(Kit.xf(Kit.cyl(0.04, 0.04, 2.4, 5), 0, 1.65, 0, 0, 0, PI / 2), C.WOOD), 0.006)
	var net := Kit.box(2.1, 1.2, 0.03)
	Kit.xf(net, 0, 1.05, 0.02)
	m.add("p", "cloth", C.PA(net, [0x7a705a, 0x5a5242], 0.08, R), 0.004)
	for k in 3:   # 밧줄 사리
		m.add("p", "cloth", C.PA(Kit.xf(C.torus(0.32 - k * 0.05, 0.05, 4, 14), 0.6, 0.06 + k * 0.08, 0.6), ROPE), 0.004)
	m.box_c(-1.2, 1.2, -0.15, 0.2)
	return Vector2(2.8, 1.8)

static func _ribbon(m: C.M) -> void:
	var R := m.rng
	m.add("p", "rock", C.PA(Kit.xf(Kit.lump(0.4, 1, R, 0.3, 0.6), 0, 0.15, 0), ROCK, 0.06, R), 0.012)
	var g := Kit.box(0.05, 0.6, 0.008)
	Kit.xf(g, 0.18, 0.22, 0.3, 1.2, 0.3, 0.4)
	m.add("p", "cloth", C.PA(g, RED), 0.002)
	m.add("p", "cloth", C.PA(Kit.xf(Kit.box(0.05, 0.35, 0.008), 0.32, 0.06, 0.45, 1.5, -0.2, 0.0), RED), 0.002)

static func _bowl(m: C.M) -> void:
	m.add("p", "wood", C.PA(Kit.cyl(0.24, 0.24, 0.04, 10, 0, 0.3, 0), C.WOOD_L), 0.006)
	for k in 4:
		var a := k * PI / 2 + PI / 4
		m.add("p", "wood", C.PA(Kit.cyl(0.02, 0.02, 0.28, 4, cos(a) * 0.17, 0.14, sin(a) * 0.17), C.WOOD), 0.003)
	m.add("p", "onggi", C.P(Kit.xf(C.onggi(0.08, 0.07, 10), 0, 0.33, 0), 0xf0ece2, 0xc8c2b4), 0.004)

static func _floats(m: C.M, n: int) -> Vector2:
	var R := m.rng
	for i in n:
		var x := -0.6 + i * 0.7 + R.between(-0.1, 0.1)
		var z := R.between(-0.3, 0.3)
		var a := R.between(0, PI)
		m.add("p", "wood", C.PA(Kit.xf(Kit.cyl(0.1, 0.1, 0.7, 8), x, 0.09, z, PI / 2, a, 0), PLANK), 0.008)
		m.add("p", "wood", C.PA(Kit.xf(Kit.cyl(0.015, 0.02, 0.55, 4), x + 0.05, 0.12, z + 0.2, 1.3, a, 0), C.WOOD), 0.0)
		m.add("p", "cloth", C.PA(Kit.xf(Kit.box(0.3, 0.008, 0.2), x + 0.1, 0.14, z + 0.45, 0.2, a, 0.1), RED), 0.002)
	return Vector2(maxf(1.4, n * 0.8), 1.2)

static func _blanket(m: C.M) -> void:
	var R := m.rng
	m.add("p", "thatch", C.PA(Kit.box(1.4, 0.04, 0.9, 0, 0.02, 0), MAT, 0.06, R), 0.004)
	m.add("p", "cloth", C.P(Kit.xf(Kit.lump(0.3, 1, R, 0.2, 0.4), 0.3, 0.1, -0.1), 0xe2dccb, 0xb8b09c, 0.05, R), 0.006)
