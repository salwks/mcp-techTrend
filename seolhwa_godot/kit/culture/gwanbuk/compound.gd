# 관북 집 한 채 프리셋 — 마당 가운데 원점, 대문 +z. 田자 겹집 하나가 거의 모든 살림을 품어 마당 부속채가 적다.
#   small : 田자 겹집(작게) + 큰 장작 井자 더미 둘 + 짚가리 + 높은 바자울 + 사립문
#   medium: 田자 겹집 + 헛간 + 뒷간 + 장독 + 장작 + 바자울
#   large : 田자 겹집(크게) + 一자 곳간채(두꺼운 이엉) + 장독 + 이엉 토담 + 초가 대문
# params: seed, size, merged
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func footprint(params: Dictionary) -> Vector2:
	match params.get("size", "small"):
		"medium": return Vector2(20, 19)
		"large": return Vector2(24, 22)
	return Vector2(18, 17)

static func entries(params: Dictionary) -> Array:
	var s0 := int(params.get("seed", 1)) * 10
	var L := []
	match params.get("size", "small"):
		"large":
			L.append(CC.e("house", "culture/gwanbuk/jeonja", { seed = s0 + 1, w = 13.2, d = 10.0 }, -1.4, -4.4))
			L.append(CC.e("gotgan", "culture/chae", { seed = s0 + 2, l = 8.0, d = 3.6, bays = "bkcb", roof = "thatch_old", F = 0.3, wall_h = 1.8, k = 1.0 }, 8.6, 3.6, -PI / 2))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 3, w = 3.0, d = 2.0 }, -9.0, 6.4))
			CC.enclose(L, s0 + 20, -11.6, 11.6, -10.6, 10.6, 1.25, "village/todam", { h = 1.6, cap = "thatch" })
			L.append(CC.e("gate", "village/daemun", { seed = s0 + 8, style = "thatch", open = true, lantern = false }, 0, 10.6))
		"medium":
			L.append(CC.e("house", "culture/gwanbuk/jeonja", { seed = s0 + 1 }, -0.8, -3.6))
			L.append(CC.e("heotgan", "village/heotgan", { seed = s0 + 2, w = 3.4, d = 2.6, walls = "three" }, 7.6, 4.2, -PI / 2))
			L.append(CC.e("dwitgan", "village/dwitgan", { seed = s0 + 3, s = 1.4 }, -8.0, 7.4, PI / 2))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 4, w = 2.4, d = 1.8, n = [2, 2, 1] }, -6.4, 3.6))
			L.append(CC.e("firewood", "village/firewood", { seed = s0 + 5, style = "stack" }, 6.6, 0.0))
			CC.enclose(L, s0 + 20, -9.6, 9.6, -9.2, 9.2, 0.8, "village/fence", { h = 1.7, lite = true })
			L.append(CC.e("gate", "village/saripmun", { seed = s0 + 8, w = 1.4, open = true }, 0, 9.2))
		_:
			L.append(CC.e("house", "culture/gwanbuk/jeonja", { seed = s0 + 1, w = 10.4, d = 8.8 }, -0.6, -3.2))
			L.append(CC.e("firewood_a", "village/firewood", { seed = s0 + 2, style = "stack" }, 6.6, 3.4))
			L.append(CC.e("firewood_b", "village/firewood", { seed = s0 + 3, style = "stack" }, 6.6, 5.6))
			L.append(CC.e("haystack", "village/haystack", { seed = s0 + 4 }, -6.4, 4.4))
			CC.enclose(L, s0 + 20, -8.6, 8.6, -8.2, 8.2, 0.75, "village/fence", { h = 1.7, lite = true })
			L.append(CC.e("gate", "village/saripmun", { seed = s0 + 8, w = 1.4, open = true }, 0, 8.2))
	return L

static func layout(params: Dictionary) -> Array:
	return entries(params)

static func build(params: Dictionary) -> Dictionary:
	var fp := footprint(params)
	var res := CC.compound(entries(params), "관북집_" + str(params.get("size", "small")), fp, params, "culture/gwanbuk/compound")
	res.yard = { minX = -fp.x / 2 + 1, maxX = fp.x / 2 - 1, minZ = -fp.y / 2 + 1, maxZ = fp.y / 2 - 1 }
	return res
