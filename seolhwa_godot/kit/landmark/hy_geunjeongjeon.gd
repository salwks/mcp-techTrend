# 경복궁 근정전(勤政殿) — 1867년(고종 4) 중건 → 1870년에 새 건물. 2단 월대(상·하월대, 돌난간·12지신·삼도 계단) 위 중층 팔작, 정면 5칸·측면 5칸 다포.
# 실측 정면 약 30m·측면 21m, 높이 약 23m(월대 포함). 위층은 측면 한 칸씩 들어감(up_inset_z 1). 월대 크기는 압축(실제 하월대 약 50×60m → 46×40m, 가설).
# hy_jeongjeon 감싸기. params: seed
extends RefCounted

const J = preload("res://kit/landmark/hy_jeongjeon.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	return J.build(Hub.merged({ seed = 1, name = "근정전", bays = [5.0, 5.8, 6.6, 5.8, 5.0], depth = 20.0, dbays = 5, H = 6.2,
		up_inset_x = 0, up_inset_z = 1, woldae = [[46.0, 40.0, 1.3], [38.0, 31.0, 1.3]], plaque_w = 3.4 }, params))
