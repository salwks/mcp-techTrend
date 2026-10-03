# 기호 초가 ㄱ자 — 몸채 3칸 + 서쪽에서 앞으로 꺾인 부엌·외양간 칸. 중부 평야 소농가.
# 고증: 경기 민가 'ㄱ자 초가'(곱은자집) — 부엌이 꺾인 칸에 있고 안방이 귀. 마루는 좁은 툇마루.
# params: seed, w(9.0)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 9.0)
	var hx := W / 2
	CC.house(m, [
		{ name = "anchae", x0 = -hx, x1 = hx, z0 = -2.0, z1 = 2.0, face = "s", bays = "ddw", maru = 0.5, chimney = "low" },
		{ name = "wing", x0 = -hx, x1 = -hx + 3.1, z0 = 2.0, z1 = 5.6, face = "e", bays = "kc" },
	], "thatch", { ov = 0.8 })
	return m.result("ㄱ자초가", Vector2(W + 1.8, 9.4))
