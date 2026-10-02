# 텃밭 — 싸리울(lite)로 두른 집 곁 채소밭: 두둑 줄 + 배추·무·고추·파 포기 + 울에 올린 호박 넝쿨 + 앞쪽 드나드는 틈.
# 고증: 조선 후기 남부 민가 텃밭 채소는 조선배추·무·파·마늘·고추(17세기 이후 보급)·호박. 텃밭은 싸리·수수깡 울로 닭·짐승을 막았다.
# params: seed, w(4.5), d(3.2), rows(4), fence(true), gourd(true)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const FE := preload("res://kit/village/fence.gd")

const CROPS := {
	cabbage = [0x9aae62, 0x6a7e40, 0.2, 0.55],   # 배추: 둥글고 넓게
	radish = [0x7f9a4e, 0x5a7038, 0.15, 0.75],   # 무: 잎이 위로
	pepper = [0x5f7a3e, 0x40562a, 0.13, 1.1],    # 고추: 키 큰 포기(붉은 열매 점)
	scallion = [0x8aa65a, 0x5e7a3a, 0.08, 1.8],  # 파: 가늘고 길게
}

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var w: float = params.get("w", 4.5); var d: float = params.get("d", 3.2); var rows: int = params.get("rows", 4)
	var R := m.rng
	m.add("p", "mud", C.P(Kit.box(w - 0.2, 0.04, d - 0.2, 0, 0.02, 0), 0x8a7454, 0x7a6448, 0.04, R), 0)
	var kinds := CROPS.keys()
	for r in rows:
		var z := -d / 2 + 0.45 + r * (d - 0.9) / maxf(rows - 1, 1)
		m.add("p", "mud", C.P(Kit.box(w - 0.6, 0.14, 0.38, 0, 0.07, z), 0x9a8462, 0x7a6448, 0.05, R), 0)
		var k: String = kinds[(r + int(params.get("seed", 1))) % kinds.size()]
		var c: Array = CROPS[k]
		var n := int((w - 0.8) / 0.55)
		for i in n:
			var x := -w / 2 + 0.55 + i * (w - 1.1) / maxf(n - 1, 1)
			var g := Kit.lump(c[2], 0, R, 0.3, c[3])
			Kit.xf(g, x + (m.r() - 0.5) * 0.06, 0.14 + c[2] * c[3] * 0.8, z)
			m.add("p", "leaf", C.P(g, c[0], c[1], 0.06, R), 0)
			if k == "pepper" and i % 2 == 0:
				m.add("p", "organic", C.P(Kit.box(0.05, 0.1, 0.05, x + 0.06, 0.3, z + 0.08), 0xb0402e), 0)
	if params.get("fence", true):
		var hw := w / 2; var hd := d / 2
		FE.draw(m, -hw, -hd, hw, -hd, 1.0, true)
		FE.draw(m, -hw, -hd, -hw, hd, 1.0, true)
		FE.draw(m, hw, -hd, hw, hd, 1.0, true)
		FE.draw(m, -hw, hd, -0.5, hd, 1.0, true)
		FE.draw(m, 0.5, hd, hw, hd, 1.0, true)
		if params.get("gourd", true):
			for i in 4:
				var x := hw - 0.3 - i * 0.45
				m.add("p", "leaf", C.P(Kit.xf(Kit.lump(0.22, 0, R, 0.25, 0.5), x, 1.0, -hd), 0x7f9456, 0x56663a, 0.05, R), 0.01)
			m.add("p", "organic", C.P(Kit.xf(C.sphere(0.17, 6, 4), hw - 0.7, 0.85, -hd + 0.12, 0, 0, 0, 1, 0.8, 1), 0xd89a3a, 0xb0782a), 0.01)
	m.anchor("gap", Vector3(0, 0, d / 2 + 0.5))
	return m.result("텃밭", Vector2(w + 0.3, d + 0.3), false)
