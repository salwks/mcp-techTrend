# 경복궁(1865~1868 중건, 1870년 새 궁궐) 간략 배치형 — 광화문 → 흥례문 → 근정문 + 행각 → 근정전(2단 월대) / 서쪽 경회루 연못.
# 실제 남북 약 700m를 크게 압축(광화문~근정전 약 110m), 침전·동궁·후원은 뺌(게임 구역 압축 가설). 원점 = 궁 가운데, 정면 +z.
# 궁장(담)은 gwana_wall 조각. params: seed. pieces 반환
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func layout(params: Dictionary) -> Array:
	var seed: int = int(params.get("seed", 1))
	var p := [
		{ kit = "landmark/hy_gwanghwamun", params = { seed = seed }, x = 0.0, z = 78.0, ry = 0.0, tag = "gwanghwamun" },
		{ kit = "landmark/hy_palace_gate", params = { seed = seed + 1, name = "흥례문", bays = [3.8, 4.6, 3.8], depth = 6.0, stories = 2 }, x = 0.0, z = 46.0, ry = 0.0, tag = "heungnyemun" },
		{ kit = "landmark/hy_palace_gate", params = { seed = seed + 2, name = "근정문", bays = [3.8, 4.6, 3.8], depth = 6.0, stories = 2 }, x = 0.0, z = 22.0, ry = 0.0, tag = "geunjeongmun" },
		{ kit = "landmark/hy_geunjeongjeon", params = { seed = seed + 3 }, x = 0.0, z = -14.0, ry = 0.0, tag = "geunjeongjeon" },
		{ kit = "landmark/hy_gyeonghoeru", params = { seed = seed + 4 }, x = -72.0, z = -12.0, ry = 0.0, tag = "gyeonghoeru" },
	]
	# 근정전 마당 행각(남·동·서) — 근정문 양옆
	var hw := 32.0; var zs := 22.0; var zn := -40.0
	for s in [-1, 1]:
		p.append({ kit = "landmark/hy_haenggak", params = { seed = seed + 10 + s, length = 24.0 }, x = s * (hw - 13.0), z = zs, ry = PI, tag = "haenggak_s%d" % s })
		for k in 3:
			p.append({ kit = "landmark/hy_haenggak", params = { seed = seed + 20 + k, length = 20.0 }, x = s * hw, z = zs - 11.0 - k * 20.5, ry = s * PI / 2, tag = "haenggak_%s%d" % ["e" if s > 0 else "w", k] })
	p.append({ kit = "landmark/hy_haenggak", params = { seed = seed + 30, length = 64.0 }, x = 0.0, z = zn - 2.0, ry = 0.0, tag = "haenggak_n" })
	# 궁장(남쪽 앞 담 — 광화문 양옆, 동·서 일부)
	p.append_array(Co.wall_pieces([Vector2(-110.0, 78.0), Vector2(-17.0, 78.0)], false, [], seed + 50, 3.2))
	p.append_array(Co.wall_pieces([Vector2(17.0, 78.0), Vector2(60.0, 78.0)], false, [], seed + 60, 3.2))
	p.append_array(Co.wall_pieces([Vector2(-110.0, 78.0), Vector2(-110.0, -50.0)], false, [], seed + 70, 3.2))
	p.append_array(Co.wall_pieces([Vector2(60.0, 78.0), Vector2(60.0, -50.0)], false, [], seed + 80, 3.2))
	return p

static func build(params: Dictionary) -> Dictionary:
	return Hub.composite("경복궁", layout(params), Vector2(172.0, 140.0))
