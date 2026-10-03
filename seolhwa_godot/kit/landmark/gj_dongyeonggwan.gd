# 경주 객사 동경관(東京館) — 경주부 객사. 정당(전패) + 동·서 익헌. 1870년에 서 있었다(지금은 동경관 일부만 옮겨 남음).
# gaeksa 감싸기: 정당 3칸·익헌 각 4칸(가설 — 실측 기록 못 찾음). params: seed, jeongdang_bays(3), wing_bays(4)
extends RefCounted

const G = preload("res://kit/landmark/gaeksa.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var r := G.build(Hub.merged({ seed = 1, name = "동경관", jeongdang_bays = 3, wing_bays = 4 }, params))
	return r
