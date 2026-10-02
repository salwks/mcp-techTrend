# 마당 소품 묶음(footprint 3~6m) — 마당·집 곁을 채우는 생활 소품 무리. set으로 고른다.
#   manure_coop 거름더미(두엄) + 쇠스랑 + 닭장(다리 달린 둥우리 + 횃대 사다리) + 짚둥우리
#   jars        장독 모음(돌 위 독·항아리 여럿 + 소래기 + 물동이) — 장독대 없이 땅에 놓은
#   work        작업 마당: 멍석(곡식 널기) + 절구 + 맷돌 + 키 + 소쿠리
#   woodpile    나뭇가리 모퉁이: 장작 + 지게(나뭇짐) + 볏단 + 모탕(장작 패는 받침)과 도끼
# params: seed, set("manure_coop")
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const PR := preload("res://kit/village/props.gd")
const J := preload("res://kit/village/jangdok.gd")
const FW := preload("res://kit/village/firewood.gd")
const JG := preload("res://kit/village/jige.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var set: String = params.get("set", "manure_coop")
	var fp := Vector2(4, 3)
	match set:
		"jars": fp = jars(m)
		"work": fp = work(m)
		"woodpile": fp = woodpile(m)
		_: fp = manure_coop(m)
	return m.result("마당소품_" + set, fp, false)

static func manure_coop(m: C.M) -> Vector2:
	var R := m.rng
	# 거름더미: 낮은 흙더미 + 짚 섞임
	m.add("p", "organic", C.P(Kit.xf(Kit.lump(0.9, 1, R, 0.2, 0.42), -1.0, 0.05, 0.2, 0, 0, 0, 1.3, 1, 1), 0x6a5238, 0x4e3c2a, 0.06, R), 0.02)
	for i in 5: m.add("p", "thatch", C.PA(Kit.xf(Kit.box(0.5, 0.03, 0.08), -1.0 + (m.r() - 0.5) * 1.4, 0.32 + m.r() * 0.08, 0.2 + (m.r() - 0.5) * 0.8, 0, m.r() * 3, 0), C.STRAW, 0.05, R), 0)
	# 쇠스랑 꽂아 둠
	m.add("p", "wood", C.P(Kit.xf(Kit.cyl(0.025, 0.025, 1.4, 4), -0.5, 0.8, 0.0, 0.2, 0, 0.3), 0x9a7852), 0.006)
	m.add("p", "flat", C.P(Kit.xf(Kit.box(0.25, 0.12, 0.04), -0.72, 0.15, -0.12, 0.2, 0, 0.3), 0x3a3633), 0)
	# 닭장: 다리 넷 위 상자 + 초가 덮개 + 사다리
	var cx := 1.2; var cz := -0.2
	for q in [[-1, -1], [1, -1], [-1, 1], [1, 1]]: m.add("p", "wood", C.PA(Kit.box(0.07, 0.6, 0.07, cx + q[0] * 0.5, 0.3, cz + q[1] * 0.4), C.WOOD), 0)
	m.add("p", "wood", C.PA(Kit.box(1.1, 0.7, 0.9, cx, 0.95, cz), C.WOOD_L, 0.05, R), 0.015)
	m.add("p", "flat", C.P(Kit.box(0.3, 0.3, 0.02, cx, 0.95, cz + 0.46), 0x2e251c), 0)
	var o2 := m.push(cx, 0, cz)
	C.thatch_cap(m, "p", 0.75, 0.62, 1.32, 0.4, 8, 2)
	m.pop(o2)
	m.add("p", "wood", C.P(C.beam(Vector3(cx, 0.65, cz + 0.45), Vector3(cx + 0.1, 0, cz + 1.2), 0.18, 0.03), 0x9a7852), 0)
	# 짚둥우리(알 낳는 둥지) 하나 처마 밑
	m.add("p", "thatch", C.PA(Kit.xf(C.sphere(0.18, 6, 3, 0, TAU, PI / 2, PI / 2), -0.1, 1.0, -1.0, PI, 0, 0), C.STRAW, 0.05, R), 0.008)
	m.circle(-1.0, 0.2, 1.0); m.box_c(cx - 0.6, cx + 0.6, cz - 0.5, cz + 0.5)
	m.anchor("chickens", Vector3(0.6, 0, 1.2))
	return Vector2(4.4, 3.0)

static func jars(m: C.M) -> Vector2:
	var R := m.rng
	var spots := [[-1.2, -0.4, 0.42], [-0.3, -0.6, 0.36], [0.6, -0.5, 0.3], [-0.8, 0.5, 0.28], [0.2, 0.4, 0.24], [1.1, 0.3, 0.2]]
	for s in spots:
		m.add("p", "stone", C.PA(Kit.xf(Kit.lump(s[2] + 0.12, 0, R, 0.2, 0.3), s[0], 0.02, s[1]), C.STONE), 0)
		J.jar(m, "p", s[0], 0.08, s[1], s[2], s[2] * 2.2)
	# 소래기(넓은 뚜껑) 엎어 둔 것 + 물동이
	m.add("p", "onggi", C.PA(Kit.cyl(0.38, 0.22, 0.12, 10, 1.4, 0.06, -0.6), C.ONGGI), 0.012)
	m.add("p", "onggi", C.P(C.lathe([Vector2(0, 0), Vector2(0.16, 0), Vector2(0.24, 0.18), Vector2(0.18, 0.32), Vector2(0.2, 0.36), Vector2(0, 0.34)], 8), 0x8a6040, 0x5e3e28), 0.012)
	m.box_c(-1.6, 1.6, -1.0, 0.8)
	return Vector2(3.6, 2.2)

static func work(m: C.M) -> Vector2:
	var old := m.push(-0.6, 0, 0)
	PR.meongseok(m)
	m.pop(old)
	old = m.push(1.8, 0, -0.6)
	PR.jeolgu(m)
	m.pop(old)
	old = m.push(1.7, 0, 0.7)
	PR.maetdol(m)
	m.pop(old)
	# 키(곡식 까부르는 키): 앞이 넓은 삽 모양 대 바구니
	var g := Kit.Geo.new()
	g.quad(Vector3(-0.35, 0, 0.3), Vector3(0.35, 0, 0.3), Vector3(0.25, 0.12, -0.3), Vector3(-0.25, 0.12, -0.3))
	Kit.xf(g, -0.6, 0.06, 1.25, 0, 0.4, 0)
	m.add("p", "cloth", C.P(g, 0xc8ad6e, 0x9a8050), 0.008)
	old = m.push(0.6, 0, 1.2)
	PR.soguri(m, "grain")
	m.pop(old)
	m.anchor("worker", Vector3(-0.6, 0, 1.0))
	return Vector2(4.6, 3.0)

static func woodpile(m: C.M) -> Vector2:
	var R := m.rng
	var old := m.push(-0.6, 0, -0.6)
	FW.row(m, 2.4, 4, true)
	m.pop(old)
	old = m.push(1.4, 0, -0.6)
	JG.draw(m, false, "wood")
	m.pop(old)
	old = m.push(-0.9, 0, 0.9)
	PR.byeotdan(m)
	m.pop(old)
	# 모탕 + 도끼
	m.add("p", "wood", C.P(Kit.cyl(0.25, 0.28, 0.4, 8, 1.0, 0.2, 0.8), 0x9a7852, 0x6b5038), 0.012)
	m.add("p", "wood", C.P(Kit.xf(Kit.cyl(0.025, 0.025, 0.7, 4), 1.05, 0.55, 0.8, 0, 0, 0.9), 0x8a6a48), 0.006)
	m.add("p", "flat", C.P(Kit.xf(Kit.box(0.16, 0.12, 0.04), 0.82, 0.42, 0.8, 0, 0, 0.9), 0x3a3633), 0)
	for i in 4: m.add("p", "wood", C.P(Kit.xf(Kit.box(0.12, 0.08, 0.45), 1.3 + (m.r() - 0.5) * 0.5, 0.04, 1.2 + (m.r() - 0.5) * 0.4, 0, m.r() * 3, 0), 0xb08e62, 0x8a6a48), 0)
	m.circle(1.0, 0.8, 0.3)
	m.anchor("chopper", Vector3(1.0, 0, 1.4))
	return Vector2(4.6, 3.2)
