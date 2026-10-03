# 영남 초가 — 一자(il: 부엌·안방·대청·건넌방 4칸, 붉은 흙벽, 낮은 굴뚝) / ㄱ자(giyeok: 동쪽 칸이 앞으로 꺾여 사랑방·외양간).
# 고증: 경상 남부 평야는 一자 홑집 4칸이 흔하고(호남과 비슷하나 대청 마루가 넓음), 중·북부는 ㄱ자·튼ㅁ자. 흙벽 빛은 지역 흙 — 붉은 기는 가설.
# 위에서: 우진각 이엉(호남 둥근 초가보다 용마름이 길고 모가 남) + 앞마당 쪽 넓은 마루.
# params: seed, plan("il"|"giyeok"), w(9.6)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 9.6)
	var hx := W / 2
	var wings := [{ name = "anchae", x0 = -hx, x1 = hx, z0 = -2.1, z1 = 2.1, face = "s", bays = "kdmd", wall = "red", maru = 0.75, chimney = "low" }]
	var fd := 0.0
	if params.get("plan", "il") == "giyeok":
		wings[0].maru = 0.6
		wings.append({ name = "wing", x0 = hx - 3.3, x1 = hx, z0 = 2.1, z1 = 6.0, face = "w", bays = "cw", wall = "red", maru = 0.0 })
		fd = 3.9
	CC.house(m, wings, "thatch", { ov = 0.8 })
	return m.result("영남초가", Vector2(W + 1.8, 4.2 + 1.8 + fd + 0.8))
