# 성황당(서낭당) — 돌무더기(누석단) + 신목(단순화한 느티·당산나무) + 금줄 + 오색 천 + (선택) 작은 당집.
# 고증: 고갯마루·마을 어귀의 서낭당은 돌무더기와 신목이 짝을 이루고, 신목 줄기에 왼새끼 금줄과 흰 종이·오색 천을 맨다.
#   지리산 자락 마을(산내·운봉)은 당산나무 + 당집(작은 초가·기와 사당)을 함께 두기도 했다(가설: dangjip 옵션).
# 신목은 kit-nature의 큰 나무로 바꿔 놓을 수 있게 tree=false 옵션과 anchors.tree(나무 자리)를 준다.
# params: seed, tree(true), dangjip(false)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CA := preload("res://kit/village/cairn.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var R := m.rng
	var old := m.push(0.9, 0, 0.4)
	CA.draw(m, true)
	m.pop(old)
	var tx := -1.6; var tz := -0.8
	m.anchor("tree", Vector3(tx, 0, tz))
	if params.get("tree", true):
		sacred_tree(m, tx, tz)
	else:
		# 나무 없이 금줄 두를 자리 표시만
		m.circle(tx, tz, 0.6)
	if params.get("dangjip", false):
		old = m.push(2.9, 0, -1.9, -0.3)
		m.add("p", "stone", C.PA(Kit.box(2.2, 0.3, 1.8, 0, 0.15, 0), C.STONE, 0.05, R), 0.02)
		m.add("p", "mud", C.PA(Kit.box(1.8, 1.5, 1.4, 0, 1.05, 0), C.MUD, 0.04, R), 0.02)
		m.add("p", "wood", C.P(Kit.box(0.7, 1.2, 0.05, 0, 0.95, 0.71), 0x5a4432, 0x3f2f22), 0.01)
		C.tile_roof(m, "p", 1.5, 1.25, 1.85, 0.8, 8, 6, 0.25, 1.5)
		m.box_c(-1.1, 1.1, -0.9, 0.9)
		m.pop(old)
	return m.result("성황당", Vector2(7.5 if params.get("dangjip", false) else 5.5, 4.6))

# 신목: 굵은 줄기 + 가지 셋 + 잎 덩이 넷 + 금줄 + 오색 천
static func sacred_tree(m: C.M, tx: float, tz: float) -> void:
	var R := m.rng
	var base := Vector3(tx, -0.2, tz); var fork := Vector3(tx + 0.1, 2.4, tz)
	m.add("p", "bark", C.P(Kit.limb(base, fork, 0.48, 0.36, 8), 0x6a5a48, 0x4a3e32, 0.05, R), 0.03)
	m.add("p", "bark", C.P(Kit.cyl(0.45, 0.75, 0.45, 8, tx, 0.05, tz), 0x5a4c3e, 0x44392e), 0.03)
	var tips := []
	for i in 3:
		var a := i * TAU / 3 + 0.4
		var tip := Vector3(tx + cos(a) * 2.0, 4.6 + m.r() * 0.6, tz + sin(a) * 1.0)
		m.add("p", "bark", C.P(Kit.limb(fork, tip, 0.26, 0.1, 6), 0x6a5a48, 0x4a3e32, 0.05, R), 0.02)
		tips.append(tip)
	var blobs := [[tx, 5.6, tz, 2.0]]
	for t in tips: blobs.append([t.x, t.y + 0.3, t.z, 1.5])
	for b in blobs:
		m.add("p", "leaf", C.P(Kit.xf(Kit.lump(b[3], 1, R, 0.16, 0.72), b[0], b[1], b[2]), 0x7f8a58, 0x4a5436, 0.04, R), 0.04)
	# 금줄(왼새끼) + 흰 종이 술
	m.add("p", "flat", C.P(Kit.xf(C.torus(0.47, 0.05, 4, 12), tx + 0.02, 1.2, tz, PI / 2, 0, 0), 0xcdb57a, 0xa58d5c), 0.01)
	for i in 6:
		var a := i * TAU / 6
		m.add("p", "cloth", C.P(C.vplane(0.08, 0.22, tx + cos(a) * 0.5, 1.06, tz + sin(a) * 0.5, -a + PI / 2), 0xf2ecdc), 0)
	# 낮은 가지에 오색 천
	var la := Vector3(tx + 0.2, 2.1, tz + 0.1); var lb := Vector3(tx + 2.2, 2.6, tz + 0.9)
	m.add("p", "bark", C.P(Kit.limb(la, lb, 0.13, 0.05, 6), 0x6a5a48, 0x4a3e32), 0.02)
	var cols := [0xa8483a, 0x3f5f7a, 0xc9a34a, 0xe8e2d2, 0x5f7a4a, 0xb0584a, 0xdcd4bc]
	for i in 7:
		var t := 0.25 + i * 0.1
		var p := la.lerp(lb, t)
		var g := C.vplane(0.12, 0.7 + m.r() * 0.3, 0, 0, 0)
		Kit.xf(g, p.x, p.y - 0.42, p.z, 0, -0.4, (m.r() - 0.5) * 0.15)
		m.add("p", "cloth", C.P(g, cols[i], cols[i], 0.02), 0)
	m.circle(tx, tz, 0.6)
	m.light(tx + 0.5, 1.4, tz + 0.5, "shrine")
