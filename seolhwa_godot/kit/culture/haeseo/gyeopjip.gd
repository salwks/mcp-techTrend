# 해서 겹집 — 방이 앞뒤 두 줄로 붙은 깊은 一자(il) 또는 ㄱ자(giyeok) 초가. 툇마루 없이 벽이 바로 서고, 지붕이 넓고 두툼하다.
# 고증: 황해도 평야 민가는 一자·ㄱ자가 많고 서북으로 갈수록 겹집(양통집) 경향 — 부엌·외양간이 몸채 안. 깊이 6m 안팎은 가설.
# 위에서: 깊어서 정사각에 가까운 굵은 이엉 덩이(一자 홑집의 가는 띠와 구별).
# params: seed, plan("il"|"giyeok"), roof("thatch"|"giwa"), w(10.4)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 10.4)
	var hx := W / 2
	var giwa: bool = params.get("roof", "thatch") == "giwa"
	var wings := [{ name = "anchae", x0 = -hx, x1 = hx, z0 = -3.1, z1 = 3.1, face = "s", bays = "ckdds" if not giwa else "kdmdw", F = 0.35 if not giwa else 0.6, wall_h = 1.8 if not giwa else 2.2, maru = 0.0 if not giwa else 0.6, chimney = "tall" }]
	var fd := 0.0
	if params.get("plan", "il") == "giyeok":
		wings.append({ name = "wing", x0 = -hx, x1 = -hx + 3.4, z0 = 3.1, z1 = 6.6, face = "e", bays = "dc", F = wings[0].F, wall_h = wings[0].wall_h, wall = "plaster" if giwa else "mud" })
		fd = 3.5
	CC.house(m, wings, "giwa" if giwa else "thatch", { ov = 1.3 if giwa else 0.85 })
	return m.result("겹집", Vector2(W + 2.0, 6.2 + 2.0 + fd))
