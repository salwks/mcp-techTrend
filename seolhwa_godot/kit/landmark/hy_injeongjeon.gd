# 창덕궁 인정전(仁政殿) — 1804년(순조 4) 화재 뒤 1805년 중건본이 1870년에 있었다. 2단 월대 위 중층 팔작, 정면 5칸·측면 4칸 다포(겉은 2층, 안은 통층).
# 근정전보다 작다(정면 약 25m). 월대 크기는 압축 가설. hy_jeongjeon 감싸기. params: seed
extends RefCounted

const J = preload("res://kit/landmark/hy_jeongjeon.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	return J.build(Hub.merged({ seed = 1, name = "인정전", bays = [4.4, 5.0, 5.6, 5.0, 4.4], depth = 15.6, dbays = 4, H = 5.6,
		up_inset_x = 0, up_inset_z = 1, woldae = [[36.0, 30.0, 1.0], [30.0, 23.0, 1.0]], plaque_w = 3.0 }, params))
