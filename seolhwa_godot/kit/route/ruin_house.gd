# 폐가·빈 주막터 — 사람이 떠난 초가 터. 허물어진 흙벽 조각(들쭉날쭉한 윗면) + 기단 돌줄 + 홀로 선 기둥 + 내려앉은 썩은 이엉
# + 쓰러진 도리 + 깨진 독 + 잡풀. inn=true면 쓰러진 평상과 기울어진 용수 장대(주막 표시)까지 — '빈 주막터'.
# 명세 §23: 도깨비(폐가·주막·산길), 귀신(폐가). params: seed, w(6.4), d(4.4), inn(false)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = float(params.get("w", 6.4)); var D: float = float(params.get("d", 4.4))
	var inn := bool(params.get("inn", false))
	var R := m.rng
	var hz := D / 2; var hx := W / 2
	# 기단(무너진 돌줄)
	for side in 4:
		var n := 7 if side < 2 else 5
		for i in n:
			if m.r() < 0.18: continue
			var t := (i + 0.5) / n
			var x: float; var z: float
			if side == 0: x = -hx + t * W; z = hz + 0.3
			elif side == 1: x = -hx + t * W; z = -hz - 0.3
			elif side == 2: x = -hx - 0.3; z = -hz + t * D
			else: x = hx + 0.3; z = -hz + t * D
			m.add("p", "stone", C.P(Kit.xf(Kit.lump(0.26, 0, R, 0.3, 0.6), x, 0.1, z, 0, m.r() * 3, 0), 0xa29c8e, 0x77726a, 0.07, R), 0.012)
	m.add("p", "mud", C.P(Kit.box(W, 0.16, D, 0, 0.08, 0), 0x9a8a6a, 0x7c6e52, 0.06, R), 0.0)
	# 남은 흙벽 조각: 뒷벽 둘, 옆벽 하나(윗면이 들쭉날쭉)
	var segs := [[-hx + 0.3, -hz, hx * 0.2, -hz], [hx * 0.45, -hz, hx - 0.2, -hz], [-hx, -hz + 0.2, -hx, hz * 0.3]]
	for sg in segs:
		var a := Vector2(sg[0], sg[1]); var b := Vector2(sg[2], sg[3])
		var L := a.distance_to(b); var k := int(maxf(2.0, L / 0.7))
		for i in k:
			var t0 := float(i) / k
			var p := a.lerp(b, t0 + 0.5 / k)
			var hgt := 0.5 + m.r() * (1.4 if i % 3 != 0 else 0.5)
			var g := Kit.box(L / k + 0.02, hgt, 0.22, 0, hgt / 2, 0)
			Kit.xf(g, p.x, 0.12, p.y, 0, -atan2(b.y - a.y, b.x - a.x), (m.r() - 0.5) * 0.06)
			m.add("p", "mud", C.P(g, 0xb39a70, 0x8a7450, 0.07, R), 0.02)
		var mn := Vector2(minf(a.x, b.x), minf(a.y, b.y)); var mx := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
		m.box_c(mn.x - 0.15, mx.x + 0.15, mn.y - 0.15, mx.y + 0.15)
	# 홀로 선 기둥 둘(하나는 기움)
	m.add("p", "wood", C.P(Kit.xf(Kit.box(0.17, 2.1, 0.17), hx - 0.2, 1.17, hz - 0.1, 0, 0, 0.05), 0x5a4a3a, 0x3e3328, 0.05, R), 0.016)
	m.add("p", "wood", C.P(Kit.xf(Kit.box(0.17, 1.9, 0.17), -hx + 0.2, 1.0, hz - 0.1, 0.25, 0, -0.18), 0x5a4a3a, 0x3e3328, 0.05, R), 0.016)
	m.circle(hx - 0.2, hz - 0.1, 0.15); m.circle(-hx + 0.2, hz - 0.1, 0.15)
	# 내려앉은 이엉: 뒷벽 위에서 마당 쪽으로 기운 두툼한 판(검게 삭은 짚)
	var gt := Kit.Geo.new()
	var y_hi := 1.6; var y_lo := 0.25
	var A := Vector3(-hx * 0.8, y_hi, -hz + 0.1); var B := Vector3(hx * 0.6, y_hi - 0.3, -hz + 0.1)
	var Cc := Vector3(hx * 0.5, y_lo, hz * 0.2); var Dd := Vector3(-hx * 0.7, y_lo + 0.15, hz * 0.35)
	gt.quad(Dd, Cc, B, A, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	gt.quad(A, B, Cc + Vector3(0, -0.2, 0), Dd + Vector3(0, -0.2, 0))
	m.add("p", "thatch", C.P(gt, 0x8a7a58, 0x5e5240, 0.08, R), 0.035)
	m.add("p", "wood", C.P(C.beam(Vector3(-hx * 0.9, y_hi + 0.05, -hz + 0.25), Vector3(hx * 0.4, 0.2, hz + 0.6), 0.16, 0.16), 0x5a4a3a, 0x3e3328), 0.015)
	m.add("p", "wood", C.P(C.beam(Vector3(hx * 0.2, 0.1, hz * 0.6), Vector3(hx + 0.8, 0.14, -0.2), 0.14, 0.14), 0x5e4e3e, 0x40342a), 0.015)
	# 깨진 독, 사금파리
	m.add("p", "onggi", C.P(Kit.xf(C.onggi(0.32, 0.5), -hx * 0.4, 0.12, hz * 0.55, 0.0, 0, 0.5), C.ONGGI[0], C.ONGGI[1]), 0.012)
	for i in 4:
		m.add("p", "onggi", C.P(Kit.xf(Kit.box(0.18, 0.04, 0.12), -hx * 0.2 + m.r() * 0.8, 0.14, hz * 0.6 + m.r() * 0.6, 0, m.r() * 3, 0.3), C.ONGGI[0], C.ONGGI[1]), 0)
	# 잡풀·쑥대
	for i in 9:
		var x := (m.r() - 0.5) * W * 1.1; var z := (m.r() - 0.5) * D * 1.2
		m.add("p", "leaf", C.P(Kit.xf(Kit.lump(0.22 + m.r() * 0.25, 0, R, 0.45, 1.1), x, 0.18, z), 0x8f9658, 0x5c6238, 0.06, R), 0)
	if inn:
		# 쓰러진 평상 + 기운 용수 장대(주막 표시가 남은 자리)
		var pg := Kit.box(1.8, 0.1, 1.1)
		Kit.xf(pg, hx + 1.6, 0.35, hz + 0.9, 0.0, 0.3, 0.32)
		m.add("p", "wood", C.P(pg, 0x8a6e50, 0x5e4a36, 0.05, R), 0.014)
		m.add("p", "wood", C.P(Kit.xf(Kit.cyl(0.05, 0.06, 3.4, 5), hx + 0.6, 1.5, hz + 0.6, 0.0, 0, 0.42), 0x7d6650, 0x5a4838), 0.01)
		m.add("p", "thatch", C.P(Kit.xf(Kit.cyl(0.12, 0.2, 0.42, 6), hx + 1.3, 3.0, hz + 0.6, 0, 0, 0.42), 0xb59e6c, 0x8a764e), 0.01)
		m.box_c(hx + 0.9, hx + 2.4, hz + 0.4, hz + 1.4)
	m.anchor("yard", Vector3(0, 0, hz + 1.6))
	return m.result("빈 주막터" if inn else "폐가", Vector2(W + (3.0 if inn else 1.2), D + (2.4 if inn else 1.2)), false)
