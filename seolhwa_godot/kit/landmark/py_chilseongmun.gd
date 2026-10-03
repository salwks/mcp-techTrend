# 평양성 칠성문(七星門) — 내성 북문(모란봉 쪽). 1711년 중건. 작은 홍예 육축 + 단층 문루(정면 1칸·측면 1칸, 팔작 — 가설). 북향이라 카메라엔 안쪽(뒤)이 보임 → 배치 때 ry=π 권장.
# seongmun 감싸기. params: seed
extends RefCounted

const SM = preload("res://kit/landmark/seongmun.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	return SM.build(Hub.merged({ seed = 1, name = "칠성문", open = "none", lu = 1, lu_roof = "paljak", lu_bays = [4.0], lu_depth = 4.0, lu_H = 3.0,
		width = 12.0, height = 4.8, depth = 7.0, aw = 3.4, spring = 2.4 }, params))
