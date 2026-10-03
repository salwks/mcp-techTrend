# 정낭 — 올레 어귀의 정주석(구멍 셋 뚫린 돌기둥) 둘 + 걸쳐 놓는 나무 정낭 셋. 걸친 수로 집에 사람이 있는지 알린다.
# 고증: 정낭 0개 걸침 = 집에 있음, 1개 = 잠깐 나감, 2개 = 저녁에 돌아옴, 3개 = 멀리 감(제주 민속). 대문 없이 소·말만 막는 표시.
# params: seed, w(2.4: 기둥 사이), across(1: 걸친 정낭 수 0~3)
# 앵커: gate(바깥), gate_in. 충돌체는 기둥만(정낭은 표시라 지나갈 수 있게 — 게임성)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var w: float = params.get("w", 2.4)
	var n: int = clampi(int(params.get("across", 1)), 0, 3)
	var R := m.rng
	var hy := [0.45, 0.78, 1.1]
	for s in [-1, 1]:
		var x: float = s * w / 2
		m.add("p", "stone", C.PA(Kit.box(0.34, 1.35, 0.3, x, 0.67, 0), CC.BASALT_L, 0.06, R), 0.02)
		for y in hy: m.add("p", "flat", C.P(Kit.box(0.14, 0.12, 0.32, x - s * 0.02, y, 0), 0x1e1a17), 0)
		m.circle(x, 0, 0.25)
	for i in 3:
		var pole := Kit.cyl(0.055, 0.06, w + 0.6, 6, 0, 0, 0, 0, 0, PI / 2)
		if i < n:
			Kit.xf(pole, 0, hy[i], 0)
		else:
			# 걸치지 않은 정낭: 오른쪽 기둥 옆 땅에 눕혀 둠
			Kit.xf(pole, w / 2 + 0.45 + i * 0.16, 0.07, 0, 0, PI / 2, 0)
		m.add("p", "wood", C.PA(pole, [0x8a7458, 0x6a5640], 0.04, R), 0.012)
	m.anchor("gate", Vector3(0, 0, 1.2)); m.anchor("gate_in", Vector3(0, 0, -1.2))
	return m.result("정낭", Vector2(w + 1.2, 1.0), false)
