# 돌장승(석장승) — 화강암 한 덩이를 깎은 마을·절 어귀 수호 장승.
# 고증 참고: 실상사 해탈교 앞 석장승(1725년 세움, 남원 산내, 현재 3기). 둥근 벙거지 모양 모자, 툭 불거진 왕방울 눈, 주먹코,
#   꽉 다문 입 밖으로 나온 송곳니, 몸통 앞면에 이름 새김(옹호금사·금호법신 등). 높이 2.5~3m 안팎.
#   새김 글씨는 아틀라스에 없어 앞면의 얕게 판 세로 띠로만 나타냈다(가설적 단순화). 모자 모양·높이는 variant로 바꾼다.
# params: seed, variant(0: 벙거지 / 1: 높은 관 / 2: 민머리 상투), h(2.6)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

const GR := [0xbab4a6, 0x8a857a]

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	draw(m, int(params.get("variant", int(params.get("seed", 1)) % 3)), float(params.get("h", 2.6)))
	m.circle(0, 0, 0.45)
	m.anchor("front", Vector3(0, 0, 1.0))
	return m.result("돌장승", Vector2(1.2, 1.2), false)

static func draw(m: C.M, variant: int, H: float) -> void:
	var R := m.rng
	var lean := (m.r() - 0.5) * 0.05
	var old := m.xform
	m.xform = old * Transform3D(Basis(Vector3.RIGHT, lean), Vector3.ZERO)
	# 몸통: 아래가 굵고 앞뒤가 얇은 기둥(납작 팔각)
	var body := Kit.cyl(0.3, 0.36, H * 0.72, 8, 0, H * 0.36, 0)
	Kit.xf(body, 0, 0, 0, 0, 0, 0, 1, 1, 0.8)
	m.add("p", "stone", C.PA(body, GR, 0.06, R), 0.025)
	# 머리: 둥근 덩이
	var hy := H * 0.8
	m.add("p", "stone", C.PA(Kit.xf(Kit.lump(0.36, 1, R, 0.08, 1.15), 0, hy, 0.02, 0, 0, 0, 1, 1, 0.85), GR, 0.05, R), 0.025)
	var fz := 0.31   # 얼굴 앞면 z
	# 왕방울 눈 + 눈두덩
	for s in [-1, 1]:
		m.add("p", "stone", C.P(Kit.xf(C.sphere(0.085, 6, 4), s * 0.13, hy + 0.05, fz), 0xd2ccbe, 0xb4ae9f), 0)
		m.add("p", "flat", C.P(Kit.xf(C.sphere(0.04, 5, 3), s * 0.13, hy + 0.05, fz + 0.07), 0x3a3632), 0)
		m.add("p", "stone", C.P(Kit.xf(Kit.box(0.2, 0.05, 0.08), s * 0.13, hy + 0.16, fz - 0.02, 0, 0, s * -0.25), 0xa8a294), 0)
	# 주먹코
	m.add("p", "stone", C.P(Kit.xf(Kit.lump(0.08, 0, R, 0.15, 1.0), 0, hy - 0.07, fz + 0.03, 0, 0, 0, 1.1, 1, 1.0), 0xc4beb0, 0xa8a294), 0.01)
	# 입 + 송곳니
	m.add("p", "flat", C.P(Kit.box(0.22, 0.04, 0.03, 0, hy - 0.2, fz - 0.02), 0x4a4540), 0)
	for s in [-1, 1]: m.add("p", "stone", C.P(Kit.xf(Kit.cone(0.025, 0.09, 4), s * 0.07, hy - 0.15, fz, 0, 0, 0), 0xe0dccf), 0.004)
	# 앞면 새김 띠(이름 자리)
	m.add("p", "flat", C.P(Kit.box(0.16, H * 0.42, 0.02, 0, H * 0.33, 0.285), 0x8e897d, 0x7a756a), 0)
	for i in 4: m.add("p", "flat", C.P(Kit.box(0.1, 0.06, 0.012, 0, H * 0.16 + i * H * 0.09, 0.298), 0x5e5a52), 0)
	# 모자
	var top := hy + 0.33
	match variant:
		0:
			m.add("p", "stone", C.PA(Kit.cyl(0.42, 0.44, 0.07, 10, 0, top - 0.06, 0), GR), 0.015)
			m.add("p", "stone", C.PA(Kit.xf(C.sphere(0.3, 8, 3, 0, TAU, 0, PI / 2), 0, top - 0.04, 0), GR, 0.04, R), 0.015)
		1:
			m.add("p", "stone", C.PA(Kit.cyl(0.38, 0.4, 0.06, 10, 0, top - 0.06, 0), GR), 0.015)
			m.add("p", "stone", C.PA(Kit.cyl(0.2, 0.26, 0.45, 8, 0, top + 0.18, 0), GR, 0.04, R), 0.015)
		_:
			m.add("p", "stone", C.PA(Kit.xf(Kit.lump(0.11, 0, R, 0.1, 1.2), 0, top + 0.02, -0.05), GR), 0.01)
	m.xform = old
	# 받침돌
	for i in 5: m.add("p", "stone", C.PA(Kit.xf(Kit.lump(0.2, 0, R, 0.3, 0.55), cos(i * 1.3) * 0.48, 0.06, sin(i * 1.3) * 0.42), C.STONE), 0)
