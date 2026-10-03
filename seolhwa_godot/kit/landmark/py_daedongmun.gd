# 평양성 대동문(大同門) — 내성 동문, 대동강을 향함. 1635년 중건본(현존). 홍예 육축 + 중층 문루(정면 3칸·측면 3칸, 팔작). 1870년에 지금 모습.
# 옹성은 남아 있지 않다고 보고 뺌(가설). 강을 보는 동향 문: 배치 때 ry=+90°. seongmun 감싸기. params: seed
extends RefCounted

const SM = preload("res://kit/landmark/seongmun.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	return SM.build(Hub.merged({ seed = 1, name = "대동문", open = "none", lu = 2, lu_roof = "paljak", lu_bays = [3.8, 4.6, 3.8], lu_depth = 8.4, lu_H = 3.6,
		bracket = "dapo", width = 24.0, height = 5.6, depth = 10.0, aw = 4.6, spring = 3.0 }, params))
