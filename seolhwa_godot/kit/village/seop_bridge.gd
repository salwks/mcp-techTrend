# 섶다리 — Y자 통나무 다리발 + 멍에 + 장선 + 솔가지(섶) + 흙을 덮은 나무다리. 로컬 z가 다리 방향.
# 고증: 섶다리는 늦가을 물이 준 뒤 마을 사람들이 놓았다가 여름 장마에 떠내려가면 다시 놓는 임시 다리(영월·평창 등이
#   잘 알려졌으나 남부 산간 하천에도 있었다 — 가설: 람천 상류·만수천 같은 얕은 개울).
# 원점 = 다리 가운데, y=0 = 둑 높이, 다리발은 y=-1.2(강바닥)까지.
# params: seed, len(10), hw(0.8, 반폭), spans(4)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var L: float = params.get("len", 10.0); var hw: float = params.get("hw", 0.8); var sp: int = params.get("spans", 4)
	var R := m.rng
	var dy := func(z: float) -> float:
		var t := absf(z) / (L / 2)
		return 0.55 * (1.0 - smoothstep(0.7, 1.0, t)) + 0.05
	# 다리발: 사이마다 Y자 둘(양쪽) + 멍에
	for i in range(1, sp):
		var z := -L / 2 + i * L / sp
		var y: float = dy.call(z)
		for s in [-1, 1]:
			var foot := Vector3(s * (hw + 0.25), -1.2, z); var fork := Vector3(s * (hw - 0.05), y - 0.25, z)
			m.add("p", "bark", C.P(Kit.limb(foot, fork, 0.11, 0.09, 6), 0x7a6650, 0x4a3e32, 0.05, R), 0.015)
			for q in [-1, 1]: m.add("p", "bark", C.P(Kit.limb(fork, fork + Vector3(s * 0.05, 0.28, q * 0.12), 0.07, 0.05, 5), 0x7a6650), 0)
		m.add("p", "bark", C.P(Kit.cyl(0.09, 0.09, hw * 2 + 0.5, 6, 0, y - 0.18, z, 0, 0, PI / 2), 0x7a6650, 0x5a4c3e), 0.015)
	# 장선(통나무 셋) + 섶 + 흙: 구간마다 기울기
	var n := 10
	for k in n:
		var za := -L / 2 + L * k / n; var zb := -L / 2 + L * (k + 1) / n
		var ya: float = dy.call(za); var yb: float = dy.call(zb)
		var ang := atan2(yb - ya, zb - za); var zc := (za + zb) / 2; var yc := (ya + yb) / 2
		var seg := (zb - za) + 0.02
		for x in [-hw + 0.15, 0.0, hw - 0.15]:
			m.add("p", "bark", C.P(Kit.xf(Kit.cyl(0.08, 0.08, seg, 5), x, yc - 0.1, zc, PI / 2 - ang, 0, 0), 0x7a6650, 0x5a4c3e), 0)
		# 섶(솔가지) 층: 가장자리가 삐죽
		m.add("p", "needle", C.P(Kit.xf(Kit.box(hw * 2 + 0.35, 0.14, seg), 0, yc + 0.0, zc, -ang, 0, 0), 0x6e6c46, 0x4e4e34, 0.08, R), 0.02)
		# 흙(뗏장) 덮은 길
		m.add("p", "mud", C.P(Kit.xf(Kit.box(hw * 2 - 0.1, 0.06, seg), 0, yc + 0.09, zc, -ang, 0, 0), 0xa8946a, 0x8a7654, 0.05, R), 0)
	for s in [-1, 1]: m.box_c(minf(s * hw, s * (hw + 0.25)) - 0.05, maxf(s * hw, s * (hw + 0.25)) + 0.05, -L / 2 + 0.4, L / 2 - 0.4)
	m.anchor("north", Vector3(0, 0.1, -L / 2 - 0.5)); m.anchor("south", Vector3(0, 0.1, L / 2 + 0.5)); m.anchor("top", Vector3(0, 0.67, 0))
	var res := m.result("섶다리", Vector2(hw * 2 + 0.8, L + 0.4), false)
	res.deck = "y = 0.05 + 0.55·(1 − smoothstep(0.7, 1, |z|/(len/2))) + 0.12(흙 윗면)"
	return res
