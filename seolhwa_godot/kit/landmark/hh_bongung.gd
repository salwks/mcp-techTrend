# 함흥본궁(咸興本宮) 일곽 — 외삼문 → 마당(이성계가 심었다는 반송 자리) → 정전(hh_bongung_jeongjeon) + 동쪽 작은 이안청(위패 옮겨 모시는 집, 가설) + 담.
# 「함흥차사」 설화의 무대(태조가 머문 곳). 배치·거리는 가설. 원점 = 일곽 가운데, 정면 +z. params: seed. pieces 반환
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func layout(params: Dictionary) -> Array:
	var seed: int = int(params.get("seed", 1))
	var hw := 32.0; var hd := 24.0
	var p := [
		{ kit = "landmark/samun", params = { seed = seed, kind = "outer" }, x = 0.0, z = hd, ry = 0.0, tag = "oesammun" },
		{ kit = "landmark/samun", params = { seed = seed + 1, kind = "inner" }, x = 0.0, z = 6.0, ry = 0.0, tag = "naesammun" },
		{ kit = "landmark/hh_bongung_jeongjeon", params = { seed = seed + 2 }, x = 0.0, z = -10.0, ry = 0.0, tag = "jeongjeon" },
		{ kit = "landmark/seonghwangsa", params = { seed = seed + 3 }, x = 21.0, z = -10.0, ry = 0.0, tag = "ianjeong" },
		{ kit = "landmark/hh_bansong", params = { seed = seed + 4 }, x = -12.0, z = 14.0, ry = 0.0, tag = "bansong" },
	]
	p.append_array(Co.wall_pieces([Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)], true, [[0.0, hd, 4.6]], seed + 10, 2.4))
	p.append_array(Co.wall_pieces([Vector2(-hw, 6.0), Vector2(hw, 6.0)], false, [[0.0, 6.0, 4.0]], seed + 30, 2.0))
	return p

static func build(params: Dictionary) -> Dictionary:
	return Hub.composite("함흥본궁", layout(params), Vector2(66.0, 54.0))
