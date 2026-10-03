# 강릉 객사 임영관(臨瀛館) 일곽 — 삼문(gn_imyeong_samun) → 마당 → 정당 전대청(3칸) + 동대청·서헌(익헌). 고려 936년 창건, 조선 후기까지 객사.
# 1870년에 일곽이 서 있었다(일제강점기 학교로 쓰이며 헐리고 삼문만 남음 → 2006 복원). 정당·익헌 규모는 복원 건물 비례 가설.
# 원점 = 일곽 가운데, 정면 +z. params: seed. pieces 반환
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func layout(params: Dictionary) -> Array:
	var seed: int = int(params.get("seed", 1))
	var hw := 26.0; var hd := 20.0
	var p := [
		{ kit = "landmark/gn_imyeong_samun", params = { seed = seed }, x = 0.0, z = hd, ry = 0.0, tag = "samun" },
		{ kit = "landmark/gaeksa", params = { seed = seed + 1, name = "임영관", jeongdang_bays = 3, wing_bays = 4 }, x = 0.0, z = -8.0, ry = 0.0, tag = "gaeksa" },
	]
	p.append_array(Co.wall_pieces([Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)], true, [[0.0, hd, 5.4]], seed + 10, 2.2))
	return p

static func build(params: Dictionary) -> Dictionary:
	return Hub.composite("임영관", layout(params), Vector2(54.0, 46.0))
