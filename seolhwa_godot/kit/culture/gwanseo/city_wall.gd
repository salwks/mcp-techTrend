# 성읍 도시 담 둘레(평양·한양 골목) — 사괴석 아랫단 + 회벽 + 기와 갓, 사각 둘레 + 남쪽 평대문. 담 키트.
# params: seed, x0,x1,z0,z1(둘레, 없으면 ±8), gate_x(0: 남쪽 문 자리 x, null이면 문 없음), h(2.2), sides("nwes" 그릴 변)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var x0: float = params.get("x0", -8.0); var x1: float = params.get("x1", 8.0)
	var z0: float = params.get("z0", -8.0); var z1: float = params.get("z1", 8.0)
	var h: float = params.get("h", 2.2)
	var sides: String = params.get("sides", "nwes")
	if "n" in sides: CC.city_wall(m, x0, z0, x1, z0, h)
	if "w" in sides: CC.city_wall(m, x0, z0, x0, z1, h)
	if "e" in sides: CC.city_wall(m, x1, z0, x1, z1, h)
	if "s" in sides:
		if params.has("gate_x") and params.gate_x == null:
			CC.city_wall(m, x0, z1, x1, z1, h)
		else:
			var gx: float = params.get("gate_x", 0.0)
			CC.city_wall(m, x0, z1, gx - 1.25, z1, h)
			CC.city_wall(m, gx + 1.25, z1, x1, z1, h)
			var old := m.push(gx, 0, z1, 0)
			preload("res://kit/village/daemun.gd").draw(m, "tile", true, true)
			m.pop(old)
			m.anchor("gate", Vector3(gx, 0, z1 + 1.0))
	return m.result("도시담", Vector2(x1 - x0 + 1.0, z1 - z0 + 1.0), true)
