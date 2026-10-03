# 흥인지문(興仁之門, 동대문) — 1398년 준공, 1869년(고종 6) 새로 지음 → 1870년에는 막 다시 지은 새 문. 홍예 1 + 중층 문루(정면 5칸·측면 2칸, 우진각) + 반원 옹성.
# 동쪽을 보는 문: 배치 때 ry = +90°(정면 +z가 동쪽). 옹성은 북쪽으로 열림 → 로컬 open="east"(ry=+90°일 때 북). params: seed, open
extends RefCounted

const SM = preload("res://kit/landmark/seongmun.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	return SM.build(Hub.merged({ seed = 1, name = "흥인지문", open = "east", radius = 14.0, lu = 2, lu_roof = "ujin", lu_bays = [3.2, 3.8, 4.2, 3.8, 3.2], lu_depth = 6.6, lu_H = 3.4,
		bracket = "dapo", width = 26.0, height = 5.6, depth = 9.0, aw = 4.6, spring = 3.0 }, params))
