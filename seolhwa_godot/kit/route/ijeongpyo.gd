# 이정표(里程標) — 길가 거리 표지. 조선 후기 대로에는 10리·30리마다 흙더미 후(堠)와 장승을 세워 거리를 적었다.
# kind "stone": 돌 받침 + 위가 둥근 돌기둥(앞면 새김 띠 두 줄) / "post": 나무 기둥 + 기울인 글판(먹 글씨 줄) + 작은 흙 후(堠)
# params: seed, kind("stone"), h(1.6)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var kind := String(params.get("kind", "stone"))
	var H: float = float(params.get("h", 1.6))
	var R := m.rng
	if kind == "post":
		# 흙 후(堠): 낮은 흙더미 + 돌 몇 개, 그 옆 나무 기둥 글판
		m.add("p", "mud", C.P(Kit.xf(Kit.lump(0.9, 1, R, 0.2, 0.45), -0.9, 0.1, -0.2), 0xb39c74, 0x8c7652, 0.05, R), 0.02)
		for i in 4:
			var a := i * TAU / 4 + m.r()
			m.add("p", "stone", C.P(Kit.xf(Kit.lump(0.16, 0, R, 0.3, 0.7), -0.9 + cos(a) * 0.8, 0.08, -0.2 + sin(a) * 0.6), 0xa49e90, 0x7a756b, 0.06, R), 0.012)
		m.add("p", "wood", C.P(Kit.cyl(0.07, 0.09, H + 0.6, 6, 0.2, (H + 0.6) / 2, 0), 0x7d6650, 0x5a4838, 0.04, R), 0.012)
		var g := Kit.box(0.34, 1.1, 0.05, 0, 0, 0)
		Kit.xf(g, 0.2, H - 0.1, 0.1, -0.08, 0, 0)
		m.add("p", "wood", C.P(g, 0xcbb38c, 0xa88e68, 0.03, R), 0.01)
		for i in 2:
			var s := Kit.box(0.03, 0.8, 0.012)
			Kit.xf(s, 0.2 - 0.07 + i * 0.14, H - 0.12, 0.13, -0.08, 0, 0)
			m.add("p", "flat", C.P(s, 0x2b2622), 0)
		m.circle(0.2, 0, 0.18); m.circle(-0.9, -0.2, 0.75)
		m.anchor("sign", Vector3(0.2, 0, 0.6))
		return m.result("이정표", Vector2(2.4, 1.6), false)
	# 돌 이정표
	m.add("p", "stone", C.P(Kit.box(0.9, 0.22, 0.7, 0, 0.11, 0), 0x9c968a, 0x777267, 0.05, R), 0.015)
	var g2 := Kit.box(0.38, H, 0.28, 0, 0.22 + H / 2, 0)
	m.add("p", "stone", C.P(g2, 0xb4ae9f, 0x8a857a, 0.04, R), 0.015)
	m.add("p", "stone", C.P(Kit.xf(C.sphere(0.2, 6, 3, 0, TAU, 0, PI / 2), 0, 0.22 + H, 0, 0, 0, 0, 0.95, 0.55, 0.7), 0xb4ae9f, 0x9a9488, 0.03, R), 0.012)
	for i in 2:
		m.add("p", "flat", C.P(Kit.box(0.045, H * 0.72, 0.01, -0.07 + i * 0.14, 0.22 + H * 0.5, 0.145), 0x4a4640), 0)
	# 받침 둘레 돌 몇 개(길손이 얹은)
	for i in 3:
		var a := m.r() * TAU
		m.add("p", "stone", C.P(Kit.xf(Kit.lump(0.1, 0, R, 0.3, 0.7), cos(a) * 0.6, 0.06, sin(a) * 0.5), 0xa49e90, 0x7a756b, 0.06, R), 0)
	m.circle(0, 0, 0.4)
	m.anchor("front", Vector3(0, 0, 0.8))
	return m.result("이정표", Vector2(1.2, 1.0), false)
