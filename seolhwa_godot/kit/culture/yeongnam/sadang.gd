# 사당(가묘) — 종가 뒤 높은 곳의 3칸 맞배 기와 + 낮은 기와 토담 + 작은 일각문(앞 담 가운데). 종가 조각.
# 고증: 『가례』에 따라 정침 동쪽 뒤에 사당을 둔다(영남 종가 대부분). 3칸 맞배·단청 없음·앞 툇칸. 담 안쪽 마당 좁게.
# params: seed, wall(true)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var w := { name = "sadang", x0 = -3.3, x1 = 3.3, z0 = -2.6, z1 = 0.9, face = "s", bays = "ddd", F = 0.95, wall_h = 2.1, wall = "plaster", maru = 0.0, gable = true }
	CC.house(m, [w], "giwa", { ov = 1.0, rise_k = 0.62 })
	if params.get("wall", true):
		var TD := preload("res://kit/village/todam.gd")
		var x0 := -5.2; var x1 := 5.2; var z0 := -4.4; var z1 := 4.6
		TD.draw(m, x0, z0, x1, z0, 1.5, "tile", 0.5)
		TD.draw(m, x0, z0, x0, z1, 1.5, "tile", 0.5)
		TD.draw(m, x1, z0, x1, z1, 1.5, "tile", 0.5)
		TD.draw(m, x0, z1, -1.1, z1, 1.5, "tile", 0.5)
		TD.draw(m, 1.1, z1, x1, z1, 1.5, "tile", 0.5)
		var old := m.push(0, 0, z1, 0)
		preload("res://kit/village/daemun.gd").draw(m, "tile", false, false)
		m.pop(old)
		m.anchor("gate", Vector3(0, 0, z1 + 1.0))
	return m.result("사당", Vector2(11.2, 10.0))
