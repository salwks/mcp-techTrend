# 징검다리 — 개울을 건너는 넓적한 디딤돌 줄. 로컬 z가 건너는 방향, 물 면 y=0, 돌 윗면 y≈0.15.
# params: seed, len(6), step(0.75)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = params.get("len", 6.0); var st: float = params.get("step", 0.75)
	var R := m.rng
	var n := maxi(2, roundi(L / st) + 1)
	for i in n:
		var z := -L / 2 + i * L / (n - 1)
		var x := (m.r() - 0.5) * 0.25
		var g := Kit.lump(0.34 + m.r() * 0.08, 0, R, 0.2, 0.42)
		Kit.xf(g, x, 0.0, z, 0, m.r() * 3, 0, 1.2, 1, 1)
		m.add("p", "stone", C.P(g, 0xb8b2a5, 0x77726a, 0.08, R), 0.02)
		m.anchor("s%d" % i, Vector3(x, 0.15, z))
	m.anchor("north", Vector3(0, 0, -L / 2 - 0.6)); m.anchor("south", Vector3(0, 0, L / 2 + 0.6))
	var res := m.result("징검다리", Vector2(1.2, L + 0.8), false)
	res.walk = "디딤돌 위로 걸어 건넌다(충돌체 없음). 물 깊이는 지형 담당이 얕게"
	return res
