# 영동 해안 ㄱ자 초가 — 낮은 몸채 + 동쪽이 앞으로 꺾인 칸, 바닷바람에 잿빛으로 바랜 이엉을 새끼 그물로 얽고 처마에 돌을 매닮.
# 고증: 동해안 어촌(강릉·삼척·양양)은 바람이 세서 이엉을 새끼로 그물처럼 얽어 매었다. ㄱ자 꺾임·처마 돌은 가설로 단순화.
# 위에서: 잿빛 ㄱ 지붕 + 어두운 격자 줄 — 기호 ㄱ자(노란 이엉, 줄 없음)와 구별.
# params: seed, w(9.0)
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func build(params: Dictionary) -> Dictionary:
	var m := C.M.new(int(params.get("seed", 1)))
	var W: float = params.get("w", 9.0)
	var hx := W / 2
	CC.house(m, [
		{ name = "anchae", x0 = -hx, x1 = hx, z0 = -2.0, z1 = 2.0, face = "s", bays = "kdd", maru = 0.45, F = 0.3, wall_h = 1.7 },
		{ name = "wing", x0 = hx - 3.0, x1 = hx, z0 = 2.0, z1 = 5.2, face = "w", bays = "cw", F = 0.3, wall_h = 1.7 },
	], "thatch_sea", { ov = 0.75, rise_k = 0.42, rope = 0.85, rope_stones = true })
	return m.result("해안ㄱ자초가", Vector2(W + 1.6, 9.0))
