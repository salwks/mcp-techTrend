# 서북 초가 — 낮고 넓은 겹집 초가(평안도). 벽이 낮고(1.6m) 지붕 물매가 완만해 넓적한 방석처럼 보인다. 외양간·부엌이 몸채 안.
# 고증: 평안도 평야 민가는 겹집이 우세하고, 바람·추위로 벽이 낮고 지붕이 낮다. 수치는 가설.
# 위에서: 납작하고 넓은 잿빛 이엉 판 + 가로로 동여맨 새끼 띠(바람막이, 가설) + 처마 밖에 따로 선 높은 굴뚝.
# params: seed, w(12.0)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 12.0)
	CC.house(m, [{ name = "anchae", x0 = -W / 2, x1 = W / 2, z0 = -3.2, z1 = 3.2, face = "s", bays = "ckdsd", F = 0.25, wall_h = 1.6, chimney = "tall" }], "thatch_nw", { ov = 1.0, rise_k = 0.32, k = 1.0, rope = 1.1, rope_dir = "x" })
	return m.result("서북초가", Vector2(W + 2.4, 8.8))
