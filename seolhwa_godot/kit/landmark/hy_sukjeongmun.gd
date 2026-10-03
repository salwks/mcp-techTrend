# 숙정문(肅靖門, 북대문) — 북악 동쪽 능선의 북문. 풍수상 음기를 막는다 하여 평소 닫아 둠(가뭄 때만 열었다는 기록). 조선 후기에는 문루가 없는 암문 모양 홍예문이었다
# (지금 문루는 1976년 복원) → 1870년 기준 문루 없이 육축 + 여장, 문은 닫힘. params: seed, doors("closed")
extends RefCounted

const SM = preload("res://kit/landmark/seongmun.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	return SM.build(Hub.merged({ seed = 1, name = "숙정문", open = "none", lu = 0, doors = "closed", width = 14.0, height = 5.4, depth = 7.0, aw = 3.6, spring = 2.6 }, params))
