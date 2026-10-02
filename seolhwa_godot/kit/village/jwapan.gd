# 장터 좌판 — 멍석 깔고 물건 늘어놓은 노점 + (선택) 흰 천 차일.
# 고증: 5일장(인월장·운봉장 등)의 장꾼은 멍석·좌판에 물건을 펴고 햇볕 가리개로 차일(遮日)을 쳤다.
# params: seed, w(2.2), d(1.8), goods:"onggi"|"cloth"|"grain"|"straw"|"fish"|"mixed", awning(true)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const S := preload("res://kit/village/market_shop.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var w: float = params.get("w", 2.2); var d: float = params.get("d", 1.8)
	var R := m.rng
	m.add("p", "thatch", C.P(Kit.box(w, 0.03, d, 0, 0.015, 0), 0xc8b07a, 0xb09868, 0.04, R), 0.008)
	# 낮은 널 좌판(앞쪽 반). 차일은 뒤쪽 반(장꾼 자리)만 덮어 위에서도 물건이 보인다
	m.add("p", "wood", C.PA(Kit.box(w - 0.3, 0.06, 0.6, 0, 0.3, 0.45), C.WOOD_L, 0.04, R), 0.012)
	for s in [-1, 1]: m.add("p", "wood", C.PA(Kit.box(0.08, 0.27, 0.5, s * (w / 2 - 0.25), 0.135, 0.45), C.WOOD), 0)
	S.goods(m, params.get("goods", "mixed"), w - 0.5, 0.33, 0.45)
	m.anchor("seller", Vector3(0, 0, -0.45))
	m.anchor("buyer", Vector3(0, 0, d / 2 + 0.6))
	if params.get("awning", true):
		var h := 1.9
		for q in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
			var hh := h if q[1] < 0 else h - 0.25
			var pz: float = -d / 2 if q[1] < 0 else 0.0
			m.add("p", "wood", C.P(Kit.cyl(0.03, 0.035, hh, 5, q[0] * w / 2, hh / 2, pz), 0x7a5c3e), 0.008)
		# 처진 천: 가운데가 조금 내려앉은 두 장
		var g := Kit.Geo.new()
		var p0 := Vector3(-w / 2, h, -d / 2); var p1 := Vector3(w / 2, h, -d / 2)
		var p2 := Vector3(w / 2, h - 0.25, 0.0); var p3 := Vector3(-w / 2, h - 0.25, 0.0)
		var mid0 := Vector3(0, h - 0.12, -d / 2); var mid1 := Vector3(0, h - 0.37, 0.0)
		g.quad(p3, mid1, mid0, p0, Vector2(0, 0), Vector2(0.5, 0), Vector2(0.5, 1), Vector2(0, 1))
		g.quad(mid1, p2, p1, mid0, Vector2(0.5, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0.5, 1))
		m.add("p", "cloth", C.P(g, 0xddd4be, 0xcfc4aa, 0.02, R), 0.01)
		for q in [[-1, -1], [1, -1], [-1, 1], [1, 1]]: m.circle(q[0] * w / 2, -d / 2 if q[1] < 0 else 0.0, 0.1)
	m.box_c(-w / 2 + 0.15, w / 2 - 0.15, 0.15, 0.75)
	return m.result("좌판", Vector2(w + 0.2, d + 0.2), false)
