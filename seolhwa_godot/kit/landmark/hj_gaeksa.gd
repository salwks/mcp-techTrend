# 황주 객사 제안관(齊安館) — 황주목 객사(황주의 옛 이름 제안). 의주대로 사신 길의 큰 객사라 정당 5칸·익헌 각 5칸으로 둠(규모 가설). gaeksa 감싸기.
# params: seed, jeongdang_bays(5), wing_bays(5)
extends RefCounted

const G = preload("res://kit/landmark/gaeksa.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	return G.build(Hub.merged({ seed = 1, name = "제안관", jeongdang_bays = 5, wing_bays = 5 }, params))
