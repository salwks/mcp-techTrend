# 함흥읍성 성문 — 함경도 감영이 있던 함흥부 읍성(반룡산 기슭~성천강 사이 석성). 남문 주변에 만세교로 이어지는 길. 1870년에 성벽·문이 있었다고 봄.
# 문 이름·문루 모양은 기록 확인 못 함 → 북부 감영 읍성답게 중층 문루(정면 3칸, 팔작) + 앞 반원 옹성(front)으로 둔 가설. params: seed, name, open, lu
extends RefCounted

const SM = preload("res://kit/landmark/seongmun.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	return SM.build(Hub.merged({ seed = 1, name = "함흥남문", open = "front", radius = 12.0, lu = 2, lu_roof = "paljak", lu_bays = [3.6, 4.2, 3.6], lu_depth = 6.0, lu_H = 3.4,
		width = 20.0, height = 5.4, depth = 8.0, aw = 4.0, spring = 2.8 }, params))
