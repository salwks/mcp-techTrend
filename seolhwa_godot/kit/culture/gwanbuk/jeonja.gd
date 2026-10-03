# 관북 田자 겹집 — 방이 앞뒤 두 줄(田)로 붙고 부엌·정주간·외양간·방앗간까지 한 지붕 아래 든 넓고 깊은 집.
#   두꺼운 묵은 이엉(눈 무게·추위, 짙은 갈색)을 얹고, 창은 작고 적다. 굴뚝은 처마 밖에 따로 높이.
# 고증: 함경도 '田자형 겹집'(양통집) — 정주간(부엌과 방 사이 트인 온돌 마루)이 중심, 외양간이 부엌에 붙음(소에게 온기). 이엉 두께·새끼는 가설.
# 위에서: 정사각에 가까운 크고 두툼한 갈색 이엉 덩이 하나 — 다른 문화권의 가늘고 긴 一자·꺾인 지붕과 바로 구별.
# params: seed, w(11.6), d(9.6)
# 앵커: house_jeongju(정주간 앞), house_cow, house_kitchen, house_door
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 11.6); var D: float = params.get("d", 9.6)
	CC.house(m, [{ name = "house", x0 = -W / 2, x1 = W / 2, z0 = -D / 2, z1 = D / 2, face = "s", bays = "ckmsds", F = 0.3, wall_h = 1.8, chimney = "tall", chim_off = 1.7 }],
		"thatch_old", { ov = 0.8, k = 1.0, rise_k = 0.5 })
	if m.anchors.has("house_daecheong"):
		m.anchors["house_jeongju"] = m.anchors["house_daecheong"]; m.anchors.erase("house_daecheong")
	return m.result("田자집", Vector2(W + 3.5, D + 2.0))
