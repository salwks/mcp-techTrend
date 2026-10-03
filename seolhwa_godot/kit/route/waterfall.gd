# 폭포와 소(沼) — 바위 벼랑에서 떨어지는 물줄기 + 둥근 소(물면, 엔진이 땅을 파고 못으로 막음) + 둘레 바위·물보라.
# 용소·이무기(JG20)·선녀와 나무꾼(JG03)·박연폭포(GH20) 같은 용왕·수중 이야기 자리(명세 §23). 원점 = 소 가운데, 벼랑은 뒤(−z).
# params: seed, h(5.5 벼랑 높이), w(2.0 물줄기 폭), r(4.2 소 반지름), water_y(0.06)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func outline(params: Dictionary) -> PackedVector2Array:
	var r: float = float(params.get("r", 4.2))
	var out := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		var k := 1.0 + 0.08 * sin(a * 3.0 + float(params.get("seed", 1)))
		out.append(Vector2(cos(a) * r * k, sin(a) * r * 0.78 * k))
	return out

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var H: float = float(params.get("h", 5.5)); var Wf: float = float(params.get("w", 2.0))
	var r: float = float(params.get("r", 4.2)); var wy: float = float(params.get("water_y", 0.06))
	var R := m.rng
	var ol := outline(params)
	var zc := -r * 0.78 - 0.9   # 벼랑 앞면
	# 벼랑: 각진 바위 덩이를 층층이(앞면은 거의 수직, 위는 이끼 낀 녹빛)
	for row in 4:
		var y := row * H / 4.0
		for i in 5:
			var x := (i - 2) * 1.9 + (m.r() - 0.5) * 0.6
			if absf(x) < Wf * 0.45 and row < 3: x += signf(x + 0.01) * Wf * 0.5
			var s := 1.3 + m.r() * 0.6 - row * 0.12
			var g := Kit.lump(s, 0, R, 0.28, 1.0)
			Kit.xf(g, x, y + s * 0.6, zc - 0.8 - row * 0.35 - m.r() * 0.4, 0, m.r() * 3, 0, 1.2, 1.0, 0.8)
			var top := 0x8f8e7c if row < 3 else 0x7f8a5c
			m.add("p", "rock", C.P(g, top, 0x5e5a50, 0.06, R), 0.03)
	# 벼랑 마루 풀·나무 덩이
	for i in 3:
		m.add("p", "leaf", C.P(Kit.xf(Kit.lump(1.0 + m.r() * 0.6, 0, R, 0.2, 0.7), (i - 1) * 3.0, H + 0.6, zc - 2.0), 0x7f8a58, 0x4a5436, 0.05, R), 0.03)
	# 물줄기: 위에서 소로 떨어지는 두 겹 물막(water 키 반투명) + 흰 물보라
	for k in 2:
		var g := Kit.Geo.new()
		var w0 := Wf * (0.5 - k * 0.12); var w1 := Wf * (0.62 - k * 0.12)
		var z0 := zc + 0.15 + k * 0.12; var z1 := zc + 0.55 + k * 0.1
		g.quad(Vector3(-w1, wy + 0.1, z1), Vector3(w1, wy + 0.1, z1), Vector3(w0, H + 0.2, z0), Vector3(-w0, H + 0.2, z0), Vector2(0, 0), Vector2(1, 0), Vector2(1, 3), Vector2(0, 3))
		m.add("p", "water", Kit.paint(g, Color(0.92, 0.95, 0.97), Color(0.75, 0.85, 0.9), 0.0), 0)
	for i in 6:
		var a := (i - 2.5) * 0.35
		m.add("p", "flat", C.P(Kit.xf(Kit.lump(0.35 + m.r() * 0.25, 0, R, 0.3, 0.6), a * Wf, wy + 0.1, zc + 0.8 + m.r() * 0.4), 0xf4f2ea, 0xdcdcd0, 0.02, R), 0)
	# 소: 물면 + 어두운 바닥
	var gw := Kit.Geo.new(); var gb := Kit.Geo.new()
	for i in ol.size():
		var a := ol[i]; var b := ol[(i + 1) % ol.size()]
		gw.tri(Vector3(0, wy, 0), Vector3(b.x, wy, b.y), Vector3(a.x, wy, a.y), Vector2(0, 0), Vector2(b.x / 4, b.y / 4), Vector2(a.x / 4, a.y / 4))
		gb.tri(Vector3(0, wy - 0.7, 0), Vector3(b.x, wy - 0.25, b.y), Vector3(a.x, wy - 0.25, a.y))
	m.add("p", "flat", C.P(gb, 0x2e3e3a, 0x223230, 0.0), 0)
	m.add("p", "water", Kit.paint(gw, Color(0.55, 0.68, 0.66), Color(0.35, 0.5, 0.5), 0.0), 0)
	# 둘레 바위(앞은 낮고 드물게 — 카메라가 소를 보게)
	for i in ol.size():
		if m.r() < 0.35: continue
		var p := ol[i] * 1.08
		var big := p.y < 0.0
		var s := (0.5 + m.r() * 0.5) * (1.5 if big else 0.8)
		m.add("p", "rock", C.P(Kit.xf(Kit.lump(s, 0, R, 0.3, 0.7), p.x, s * 0.25, p.y, 0, m.r() * 3, 0), 0x9a978a, 0x6a675e, 0.06, R), 0.02)
		m.circle(p.x, p.y, s * 0.7)
	m.box_c(-5.5, 5.5, zc - 3.0, zc + 0.2)
	m.anchor("pool", Vector3(0, 0, r * 0.78 + 1.2))
	var res := m.result("폭포와 소", Vector2(maxf(2.0 * r + 3.0, 11.0), 2.0 * r * 0.78 + 5.0), false)
	res.water = { y = wy, outline = ol, kind = "pond" }
	return res
