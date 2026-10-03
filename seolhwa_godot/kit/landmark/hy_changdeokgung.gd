# 창덕궁 간략 배치형 — 돈화문(정면 5칸 중층 우진각, 1609 중건본 — 현존 가장 오래된 궁궐 정문) → 금천교(1411 돌다리) → 진선문 → 인정문 + 행각 → 인정전.
# 실제로는 돈화문에서 동쪽으로 꺾여 들어가는 축(ㄱ자)을 압축 배치로 살림. 대조전·후원 생략. 원점 = 가운데, 정면 +z. params: seed. pieces 반환
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func layout(params: Dictionary) -> Array:
	var seed: int = int(params.get("seed", 1))
	var gx := -46.0
	var p := [
		{ kit = "landmark/hy_palace_gate", params = { seed = seed, name = "돈화문", bays = [3.4, 3.8, 4.4, 3.8, 3.4], depth = 6.4, stories = 2 }, x = gx, z = 52.0, ry = 0.0, tag = "donhwamun" },
		{ kit = "landmark/ojakgyo", params = { seed = seed + 1, length = 13.0, width = 12.0, arches = 2 }, x = gx, z = 30.0, ry = 0.0, tag = "geumcheongyo" },
		{ kit = "landmark/hy_palace_gate", params = { seed = seed + 2, name = "진선문", bays = [3.2, 3.8, 3.2], depth = 5.0, stories = 1, roof = "paljak", H = 3.6 }, x = gx + 18.0, z = 18.0, ry = -PI / 2, tag = "jinseonmun" },
		{ kit = "landmark/hy_palace_gate", params = { seed = seed + 3, name = "인정문", bays = [3.6, 4.4, 3.6], depth = 5.6, stories = 1, roof = "paljak", H = 4.0 }, x = 0.0, z = 18.0, ry = 0.0, tag = "injeongmun" },
		{ kit = "landmark/hy_injeongjeon", params = { seed = seed + 4 }, x = 0.0, z = -14.0, ry = 0.0, tag = "injeongjeon" },
	]
	var hw := 26.0; var zs := 18.0
	for s in [-1, 1]:
		p.append({ kit = "landmark/hy_haenggak", params = { seed = seed + 10 + s, length = 18.0 }, x = s * (hw - 9.0), z = zs, ry = PI, tag = "haenggak_s%d" % s })
		for k in 2:
			p.append({ kit = "landmark/hy_haenggak", params = { seed = seed + 20 + k, length = 22.0 }, x = s * hw, z = zs - 12.0 - k * 22.5, ry = s * PI / 2, tag = "haenggak_%s%d" % ["e" if s > 0 else "w", k] })
	p.append({ kit = "landmark/hy_haenggak", params = { seed = seed + 30, length = 52.0 }, x = 0.0, z = -36.0, ry = 0.0, tag = "haenggak_n" })
	p.append_array(Co.wall_pieces([Vector2(-80.0, 52.0), Vector2(gx - 10.0, 52.0)], false, [], seed + 50, 3.2))
	p.append_array(Co.wall_pieces([Vector2(gx + 10.0, 52.0), Vector2(40.0, 52.0)], false, [], seed + 60, 3.2))
	return p

static func build(params: Dictionary) -> Dictionary:
	return Hub.composite("창덕궁", layout(params), Vector2(122.0, 100.0))
