# 한양 도시 한옥(북촌용) — 좁은 필지를 꽉 채운 ㅁ자(문간채가 길에 붙음) 또는 ㄷ자(앞은 길에 붙은 화방벽 + 대문).
#   필지 사각형이 곧 바깥 경계: 남쪽(+z) 끝선 z = d/2가 길. 바깥벽은 사괴석 아랫단 + 회벽 + 높은 들창.
# 고증: 19세기 한양 북촌 반가·중인 집은 필지가 좁아 안채·사랑·문간이 붙어 ㄷ·ㅁ을 이룬다(1930년대 '도시형 한옥'보다 필지가 크고
#   사랑이 따로이나, 게임에선 골목 밀도를 위해 좁힘 — 가설). 대문은 필지 모서리 쪽.
# params: seed, shape("ㄷ"(기본)|"ㅁ" 또는 "d"|"m"), w(11.5: 필지 폭), d(14: 필지 깊이)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 11.5); var Dd: float = params.get("d", 14.0)
	var hx := W / 2; var z0 := -Dd / 2; var z1 := Dd / 2
	var shp: String = params.get("shape", "ㄷ")
	var mshape := shp in ["ㅁ", "m"]
	var wings := [
		{ name = "anchae", x0 = -hx, x1 = hx, z0 = z0, z1 = z0 + 4.2, face = "s", bays = "dmmd", F = 0.75, wall_h = 2.2, maru = 0.5 },
		{ name = "west", x0 = -hx, x1 = -hx + 3.0, z0 = z0 + 4.2, z1 = (z1 - 3.4) if mshape else z1, face = "e", bays = "kd" if mshape else "kdw", F = 0.5, wall_h = 2.1 },
		{ name = "east", x0 = hx - 3.0, x1 = hx, z0 = z0 + 4.2, z1 = (z1 - 3.4) if mshape else z1, face = "w", bays = "dm" if mshape else "wdm", F = 0.5, wall_h = 2.1 },
	]
	if mshape:
		wings.append({ name = "mungan", x0 = -hx, x1 = hx, z0 = z1 - 3.4, z1 = z1, face = "s", bays = "hghh", F = 0.3, wall_h = 2.2, wall = "urban", steps = false })
	CC.house(m, wings, "giwa", { ov = 1.0, rise_k = 0.6 })
	if not mshape:
		# 길에 붙은 화방벽 + 평대문
		CC.city_wall(m, -hx + 3.0, z1 - 0.25, -1.25, z1 - 0.25, 2.3)
		CC.city_wall(m, 1.25, z1 - 0.25, hx - 3.0, z1 - 0.25, 2.3)
		var old := m.push(0, 0, z1 - 0.25, 0)
		preload("res://kit/village/daemun.gd").draw(m, "tile", false, true)
		m.pop(old)
		m.anchor("gate", Vector3(0, 0, z1 + 1.0))
	return m.result("도시한옥", Vector2(W + 2.0, Dd + 2.0))
