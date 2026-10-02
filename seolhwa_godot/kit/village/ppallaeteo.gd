# 빨래터 — 냇가 넓적한 빨랫돌 줄 + 빨랫방망이 + 빨래 광주리 + (선택) 얕은 물 판.
# 기본 방향: 물이 -z(북) 쪽, 빨래하는 사람은 돌 뒤(+z)에 앉아 북쪽을 본다(anchors washer0..). 배치에서 ry로 돌릴 수 있다.
# params: seed, n(3), water(true: 미리보기·간이 배치용 물 판)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const PR := preload("res://kit/village/props.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var n: int = params.get("n", 3)
	var R := m.rng
	var w := n * 1.3
	for i in n:
		var x := -w / 2 + 0.65 + i * 1.3 + (m.r() - 0.5) * 0.15
		var g := Kit.lump(0.5, 0, R, 0.15, 0.3)
		Kit.xf(g, x, 0.08, -0.2, -0.12, m.r() * 0.6, 0, 1.2, 1, 0.9)
		m.add("p", "stone", C.P(g, 0xbdb7aa, 0x8a857b, 0.06, R), 0.02)
		m.anchor("washer%d" % i, Vector3(x, 0, 0.55))
		# 방망이
		m.add("p", "wood", C.P(Kit.xf(Kit.box(0.08, 0.05, 0.42), x + 0.35, 0.24, -0.05, 0, 0.5, 0), 0xb08e62, 0x8a6a48), 0.006)
		# 젖은 빨래 한 장
		m.add("p", "cloth", C.P(Kit.xf(Kit.box(0.5, 0.03, 0.35), x - 0.1, 0.24, -0.25, -0.1, 0.2, 0), 0xf0ead8, 0xd8d0bc), 0.006)
	# 받침 자갈
	for i in n * 3:
		m.add("p", "stone", C.PA(Kit.xf(Kit.lump(0.15 + m.r() * 0.08, 0, R, 0.3, 0.5), -w / 2 + m.r() * w, 0.02, -0.7 + m.r() * 0.5), C.STONE), 0)
	var old := m.push(w / 2 + 0.2, 0, 0.75)
	PR.soguri(m, "cloth")
	m.pop(old)
	if params.get("water", true):
		m.add("p", "smooth", C.P(Kit.box(w + 1.6, 0.02, 1.8, 0, -0.04, -1.3), 0x7d9ea4, 0x6a8a90), 0)
	m.anchor("basket", Vector3(w / 2 + 0.2, 0, 0.75))
	return m.result("빨래터", Vector2(w + 1.0, 2.6), false)
