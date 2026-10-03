# 나루 대기막 — 나룻배를 기다리는 길손이 비를 긋는 기둥 넷 초가 막(사방 트임) + 긴 나무 걸상 + 사공 부르는 징 걸이 + 짐 몇 개.
# 명세 §25(나루: 강 양쪽 길·선착장·뱃사공 거처·짐), §23(도깨비·물귀신 — 나루). params: seed, w(3.6), d(2.4)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = float(params.get("w", 3.6)); var D: float = float(params.get("d", 2.4))
	var R := m.rng
	var hx := W / 2; var hz := D / 2; var H := 1.9
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			m.add("p", "wood", C.PA(Kit.box(0.14, H, 0.14, sx * hx, H / 2, sz * hz), C.WOOD), 0.016)
			m.circle(sx * hx, sz * hz, 0.12)
	for sz in [-1, 1]:
		m.add("p", "wood", C.PA(Kit.box(W + 0.3, 0.13, 0.16, 0, H + 0.05, sz * hz), C.WOOD), 0.016)
	C.thatch_gable(m, "p", W + 0.8, D + 1.0, H + 0.12, 0.75)
	# 긴 걸상(뒤쪽) + 앞 걸상
	m.add("p", "wood", C.P(Kit.box(W * 0.85, 0.08, 0.38, 0, 0.45, -hz + 0.35), 0x9a7c58, 0x7a5e40, 0.04, R), 0.012)
	for sx in [-1, 1]:
		m.add("p", "wood", C.P(Kit.box(0.08, 0.42, 0.3, sx * W * 0.38, 0.21, -hz + 0.35), 0x7a5e40), 0.01)
	m.box_c(-W * 0.43, W * 0.43, -hz + 0.12, -hz + 0.58)
	# 징 걸이(사공 부르는 징)
	m.add("p", "wood", C.P(Kit.box(0.08, 1.5, 0.08, hx + 0.55, 0.75, hz - 0.2), 0x7a5e40), 0.01)
	m.add("p", "wood", C.P(Kit.box(0.5, 0.06, 0.06, hx + 0.35, 1.45, hz - 0.2), 0x7a5e40), 0.008)
	var gong := Kit.cyl(0.22, 0.22, 0.04, 12)
	Kit.xf(gong, hx + 0.22, 1.12, hz - 0.2, PI / 2, 0, 0)
	m.add("p", "flat", C.P(gong, 0xb08a48, 0x7a5c2e), 0.008)
	m.circle(hx + 0.55, hz - 0.2, 0.1)
	# 짐: 섬(가마니) 둘 + 봇짐
	for i in 2:
		m.add("p", "thatch", C.P(Kit.xf(Kit.cyl(0.26, 0.26, 0.7, 7), -hx * 0.4 + i * 0.6, 0.27, hz * 0.2, 0, 0, PI / 2), 0xcdb582, 0xa08a5e, 0.05, R), 0.01)
	m.add("p", "cloth", C.P(Kit.xf(Kit.lump(0.22, 0, R, 0.2, 0.8), hx * 0.5, 0.62, -hz + 0.35), 0xd8d0bc, 0xa8a090), 0.008)
	m.light(0, H - 0.2, 0, "lantern")
	m.anchor("bench", Vector3(0, 0, -hz + 0.9))
	return m.result("나루 대기막", Vector2(W + 1.6, D + 1.2), false)
