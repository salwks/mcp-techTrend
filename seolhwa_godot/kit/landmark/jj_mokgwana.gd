# 제주목 관아 일곽(간략 배치형) — 외대문(진해루, 돌하르방) → 중대문(솟을삼문) → 홍화각(弘化閣, 1435 창건 목사 집무 — 정면 5칸 팔작) + 연희각(延曦閣, 정면 5칸)
# + 현무암 돌담. 1870년에 서 있었고 1910년대 이후 헐림(1990년대 발굴·2002 복원). 관덕정은 외대문 앞 남쪽(jj_gwandeokjeong 따로).
# 건물 칸수·배치 거리는 복원 배치를 압축한 가설. 원점 = 일곽 가운데, 정면 +z. params: seed. pieces 반환
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func layout(params: Dictionary) -> Array:
	var seed: int = int(params.get("seed", 1))
	var hw := 24.0; var hd := 26.0
	var p := [
		{ kit = "landmark/jj_oedaemun", params = { seed = seed }, x = 0.0, z = hd, ry = 0.0, tag = "oedaemun" },
		{ kit = "landmark/samun", params = { seed = seed + 1, kind = "inner" }, x = 0.0, z = 8.0, ry = 0.0, tag = "jungdaemun" },
		{ kit = "landmark/dongheon", params = { seed = seed + 2, bays = 5, bay = 3.2, depth = 8.0 }, x = -6.0, z = -10.0, ry = 0.0, tag = "honghwagak" },
		{ kit = "landmark/dongheon", params = { seed = seed + 3, bays = 5, bay = 2.8, depth = 7.0, hyeonpan = false }, x = 12.0, z = -14.0, ry = 0.0, tag = "yeonhuigak" },
		{ kit = "landmark/jj_basalt_wall", params = { seed = seed + 9, w = hw * 2, d = hd * 2, gates = [[0.0, hd, 2.6], [0.0, 8.0, 0.0]] }, x = 0.0, z = 0.0, ry = 0.0, tag = "dam" },
		{ kit = "landmark/jj_basalt_wall", params = { seed = seed + 10, w = hw * 2, d = 0.0, line = [[-hw, 8.0], [hw, 8.0]], gates = [[0.0, 8.0, 2.4]] }, x = 0.0, z = 0.0, ry = 0.0, tag = "dam_in" },
	]
	return p

static func build(params: Dictionary) -> Dictionary:
	return Hub.composite("제주목관아", layout(params), Vector2(50.0, 62.0))
