# 평양 도시 기와집 — 깊은 一자(겹집 경향) 또는 ㄱ자 기와, 처마를 아주 넓게 뽑고(눈·햇볕) 지붕이 높고 어둡다. 길가에 붙은 대문간 칸.
# 고증: 평양·의주 등 서북 성읍의 기와집은 처마가 깊고 지붕 물매가 급하며 겹집 평면이 많다(근대 사진 기준, 1870년은 가설).
#   기와 빛은 남부보다 짙게(가설: 겨울 그을음·이끼).
# 위에서: 짙은 회색의 넓고 두꺼운 지붕 한 덩이 — 서울·영남의 밝은 기와 고리·ㄱ과 구별.
# params: seed, plan("il"|"giyeok"), w(13.2)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 13.2)
	var hx := W / 2
	var wings := [{ name = "anchae", x0 = -hx, x1 = hx, z0 = -3.0, z1 = 3.0, face = "s", bays = "gwdmdw", F = 0.6, wall_h = 2.3, maru = 0.8, chimney = "tall" }]
	var fd := 0.0
	if params.get("plan", "il") == "giyeok":
		wings[0].bays = "wdmdw"
		wings.append({ name = "wing", x0 = hx - 3.6, x1 = hx, z0 = 3.0, z1 = 7.4, face = "w", bays = "gd", F = 0.6, wall_h = 2.3, wall = "plaster" })
		fd = 4.4
	CC.house(m, wings, "giwa_dark", { ov = 2.1, rise_k = 0.62, lift = 0.35 })
	return m.result("평양기와집", Vector2(W + 4.4, 6.0 + 4.4 + fd))
