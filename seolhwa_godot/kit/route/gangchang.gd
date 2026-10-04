# 강창(江倉) — 강 포구의 곳간: 돌 기단 + 마루 들어 올린 바닥(습기 막이) + 널벽(판벽)·큰 널문 + 맞배지붕(roof: giwa 관 조창 / choga 객주 곳간).
# 앞(+z)에 섬(곡식 가마니) 몇과 지게. 명세 §26(포구 = 창고·객주·상인), CC-02 목계진(창고), 흥원창·가흥창(조창).
# params: seed, w(9.0), d(4.6), roof("giwa"|"choga"), sacks(true)
extends RefCounted
const C := preload("res://kit/village/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = float(params.get("w", 9.0)); var D: float = float(params.get("d", 4.6))
	var R := m.rng
	var hx := W / 2; var hz := D / 2
	# 돌 기단
	m.add("p", "stone", C.PA(Kit.box(W + 0.6, 0.5, D + 0.6, 0, 0.25, 0), C.STONE, 0.05, R), 0.02)
	var y0 := 0.5; var H := 2.3
	# 기둥(앞뒤 칸마다)
	var bays := maxi(2, int(W / 2.6))
	for i in bays + 1:
		var x := -hx + i * W / bays
		for sz in [-1, 1]:
			m.add("p", "wood", C.PA(Kit.box(0.2, H, 0.2, x, y0 + H / 2, sz * hz), C.WOOD), 0.018)
	# 판벽(세로 널) 사방, 앞 가운데 두 칸은 널문(조금 어둡게)
	for sz in [-1, 1]:
		for i in bays:
			var x := -hx + (i + 0.5) * W / bays
			var door: bool = sz > 0 and absi(i * 2 + 1 - bays) <= 1
			var col := [0x6a5038, 0x4a3828] if door else [0x8e7454, 0x6e5a40]
			m.add("p", "wood", C.PA(Kit.box(W / bays - 0.22, H - 0.1, 0.08, x, y0 + H / 2, sz * (hz - 0.02)), col, 0.05, R), 0.012)
			if door:
				m.add("p", "wood", C.P(Kit.box(0.06, H - 0.3, 0.1, x, y0 + H / 2, sz * hz + 0.05), 0x3a2c20), 0)
	for sx in [-1, 1]:
		m.add("p", "wood", C.PA(Kit.box(0.08, H - 0.1, D - 0.22, sx * (hx - 0.02), y0 + H / 2, 0), [0x8e7454, 0x6e5a40], 0.05, R), 0.012)
	# 바닥 아래 환기 구멍 띠(들어 올린 마루)
	m.add("p", "flat", C.P(Kit.box(W - 0.4, 0.14, 0.04, 0, y0 + 0.1, hz + 0.1), 0x2e2620), 0)
	for sz in [-1, 1]:
		m.add("p", "wood", C.PA(Kit.box(W + 0.3, 0.18, 0.24, 0, y0 + H + 0.06, sz * hz), C.WOOD), 0.018)
	var eave := y0 + H + 0.14
	if String(params.get("roof", "giwa")) == "giwa":
		C.tile_roof(m, "p", hx + 0.8, hz + 0.9, eave, 1.3, 10, 4, 0.18, 2.4)
	else:
		C.thatch_gable(m, "p", W + 1.0, D + 1.2, eave, 1.1)
	if bool(params.get("sacks", true)):
		for i in 4:
			var x := -hx * 0.7 + i * 0.66
			m.add("p", "thatch", C.P(Kit.xf(Kit.cyl(0.27, 0.27, 0.7, 7), x, 0.27, hz + 1.0, 0, 0, PI / 2), 0xcdb582, 0xa08a5e, 0.05, R), 0.008)
		m.add("p", "thatch", C.P(Kit.xf(Kit.cyl(0.27, 0.27, 0.7, 7), -hx * 0.7 + 0.33, 0.72, hz + 1.0, 0, 0, PI / 2), 0xcdb582, 0xa08a5e, 0.05, R), 0.008)
		m.box_c(-hx * 0.7 - 0.4, -hx * 0.7 + 2.4, hz + 0.7, hz + 1.3)
	m.box_c(-hx - 0.3, hx + 0.3, -hz - 0.3, hz + 0.3)
	m.anchor("front", Vector3(0, 0, hz + 1.8))
	return m.result("강창", Vector2(W + 1.8, D + 2.6))
