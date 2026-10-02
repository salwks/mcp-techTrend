# 헛간 — 앞이 트인 초가 맞배 헛간 + 볏단·지게·소쿠리·농기구.
# params: seed, w(4.0), d(2.8), walls("three"|"back")
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const PR := preload("res://kit/village/props.gd")
const JG := preload("res://kit/village/jige.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 4.0); var D: float = params.get("d", 2.8)
	draw(m, W, D, params.get("walls", "three"))
	return m.result("헛간", Vector2(W + 1.0, D + 1.2))

static func draw(m: C.M, W: float, D: float, walls := "three") -> void:
	var R := m.rng
	var sh := C.shed(m, W, D, 1.9, walls, 2, 0.9)
	var y0: float = sh.y0; var zf := D / 2
	var old := m.push(-W / 4, y0, -zf + 0.6)
	PR.byeotdan(m)
	m.pop(old)
	old = m.push(W / 4 + 0.2, y0, -zf + 0.35, 0)
	JG.draw(m, true)
	m.pop(old)
	old = m.push(W / 2 - 0.5, y0, 0.3)
	PR.soguri(m, "veg")
	m.pop(old)
	# 쇠스랑·괭이 기대 놓기
	for i in 2:
		var x := -W / 2 + 0.3 + i * 0.25
		m.add("p", "wood", C.P(Kit.xf(Kit.cyl(0.025, 0.025, 1.5, 4), x, y0 + 0.72, -zf + 0.2, -0.2, 0, 0.05), 0x9a7852), 0.006)
		m.add("p", "flat", C.P(Kit.xf(Kit.box(0.2, 0.05, 0.14), x, y0 + 1.45, -zf + 0.05, -0.2, 0, 0), 0x3a3633), 0.006)
	m.box_c(-W / 2 - 0.2, W / 2 + 0.2, -zf - 0.2, -zf + 0.1)
	if walls == "three":
		m.box_c(-W / 2 - 0.2, -W / 2 + 0.1, -zf, zf)
		m.box_c(W / 2 - 0.1, W / 2 + 0.2, -zf, zf)
	m.box_c(-W / 2 + 0.2, W / 2 - 0.2, -zf, -zf + 1.0)
	for q in [[-1], [0], [1]]: m.circle(q[0] * W / 2, zf, 0.15)
	m.anchor("front", Vector3(0, 0, zf + 0.6))
