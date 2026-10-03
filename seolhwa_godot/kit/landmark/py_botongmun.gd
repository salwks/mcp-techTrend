# 평양성 보통문(普通門) — 중성 서문, 의주로 가는 길. 1473년 중건(현존 — 평양에서 가장 오래된 목조 건물 축). 홍예 육축 + 단층 문루(정면 3칸·측면 2칸, 팔작).
# 서향 문: 배치 때 ry=−90°. seongmun 감싸기. params: seed
extends RefCounted

const SM = preload("res://kit/landmark/seongmun.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	return SM.build(Hub.merged({ seed = 1, name = "보통문", open = "none", lu = 1, lu_roof = "paljak", lu_bays = [3.8, 4.6, 3.8], lu_depth = 6.4, lu_H = 3.6,
		bracket = "dapo", width = 20.0, height = 5.4, depth = 9.0, aw = 4.2, spring = 2.9 }, params))
