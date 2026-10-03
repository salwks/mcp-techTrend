# 돈의문(敦義門, 서대문) — 1422년 지금 자리(새문), 1711년 개축. 홍예 1 + 단층 문루(정면 3칸·측면 2칸, 우진각). 1870년에 있었다(1915년 헐림).
# 옹성 없음(가설). 서쪽을 보는 문: 배치 때 ry = −90°. params: seed
extends RefCounted

const SM = preload("res://kit/landmark/seongmun.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	return SM.build(Hub.merged({ seed = 1, name = "돈의문", open = "none", lu = 1, lu_roof = "ujin", lu_bays = [3.4, 4.2, 3.4], lu_depth = 5.6, lu_H = 3.4,
		width = 20.0, height = 5.4, depth = 8.0, aw = 4.2, spring = 2.8 }, params))
