# 주막 — 길가 초가(방문 열림) + 앞마당 평상(소반·술사발) + 한데부뚜막 가마솥 + 용수 장대 + 술독.
# 고증: 조선 후기 주막은 길가 초가에 부엌·봉놋방, 마당 평상, 장대 끝 용수(술 거르는 대바구니)나 '酒' 등으로 표시
#   (김홍도·신윤복 풍속화 '주막'). 흰 천 한 폭은 가설(멀리서 알아보게).
# params: seed, w(7.2), d(4.4), flag(true), yard_side(1: 부뚜막 쪽 +x)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const H := preload("res://kit/village/choga.gd")
const PR := preload("res://kit/village/props.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 7.2); var D: float = params.get("d", 4.4)
	var o := { w = W, d = D, open = true, hump = (m.r() - 0.5) * 0.2, gourd = m.r() < 0.4 }
	H.draw(m, o)
	var zf := D / 2
	# 평상 + 소반 + 사발·술병
	var old := m.push(-W / 2 + 1.2, 0, zf + 2.1, 0.05)
	PR.pyeongsang(m, 2.1, 1.3)
	m.add("p", "wood", C.P(Kit.cyl(0.3, 0.3, 0.04, 10, 0.2, 0.62, 0), 0x7a5234, 0x6a4428), 0.01)
	m.add("p", "wood", C.P(Kit.cyl(0.22, 0.2, 0.14, 8, 0.2, 0.53, 0, 0, 0, 0, false), 0x5c3c26), 0)
	m.add("p", "flat", C.P(Kit.cyl(0.08, 0.05, 0.06, 8, 0.1, 0.67, 0.05), 0xe8e2d2, 0xc8c0ac), 0.005)
	m.add("p", "flat", C.P(Kit.cyl(0.08, 0.05, 0.06, 8, 0.32, 0.67, -0.06), 0xe8e2d2, 0xc8c0ac), 0.005)
	var bottle := C.lathe([Vector2(0, 0), Vector2(0.08, 0), Vector2(0.1, 0.1), Vector2(0.04, 0.2), Vector2(0.03, 0.26), Vector2(0, 0.26)], 6)
	m.add("p", "onggi", Kit.xf(C.P(bottle, 0xd8d0bc, 0xb8b09c, 0.03), 0.3, 0.64, 0.12), 0.005)
	m.pop(old)
	m.anchor("guest_seat", Vector3(-W / 2 + 1.2, 0.5, zf + 2.1))
	# 한데부뚜막(부엌 앞)
	old = m.push(W / 3 + 0.6, 0, zf + 1.8, -0.2)
	PR.gamasot(m)
	m.pop(old)
	m.anchor("jumo", Vector3(W / 3 + 0.6, 0, zf + 2.9))
	# 용수 장대(길 쪽 모서리)
	if params.get("flag", true):
		old = m.push(W / 2 + 1.5, 0, zf + 2.6)
		PR.yongsu(m, true)
		m.pop(old)
	# 술독(부엌 옆)
	old = m.push(W / 2 + 1.25, 0, -0.2)
	PR.dok(m, 3)
	m.pop(old)
	# 마당 짚더미 대신 장작 몇 개
	for i in 5: m.add("p", "wood", C.P(Kit.cyl(0.08, 0.08, 1.0, 6, -W / 2 - 0.9, 0.1 + (i / 3) * 0.16, -0.3 + (i % 3) * 0.19, PI / 2, 0, 0), 0x9a7852, 0x6b5038, 0.06, m.rng), 0.01)
	m.circle(-W / 2 - 0.9, -0.1, 0.6)
	return m.result("주막", Vector2(W + 4.0, D + 5.2))
