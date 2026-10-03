# 숭례문(崇禮門, 남대문) — 1398년 준공, 1448년 개축, 1479년 중수. 육축 가운데 홍예 1 + 중층 문루(정면 5칸·측면 2칸, 우진각, 다포). 옹성 없음.
# 1870년에는 양옆으로 한양도성 성벽이 이어졌다(1907년 헐림). 현판은 세로(양녕대군 글씨 전함). 육축 너비·높이는 실측 근사(가설 포함).
# seongmun 감싸기. params: seed
extends RefCounted

const SM = preload("res://kit/landmark/seongmun.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	return SM.build(Hub.merged({ seed = 1, name = "숭례문", open = "none", lu = 2, lu_roof = "ujin", lu_bays = [3.4, 4.0, 4.6, 4.0, 3.4], lu_depth = 7.2, lu_H = 3.6,
		bracket = "dapo", width = 30.0, height = 6.2, depth = 10.0, aw = 5.0, spring = 3.4 }, params))
