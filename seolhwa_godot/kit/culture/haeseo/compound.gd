# 해서 집 한 채 프리셋 — 마당 가운데 원점, 대문 +z.
#   small : 一자 겹집 초가 + 짚가리 + 장독 + 싸리울(높게) + 사립문
#   medium: 一자 겹집 초가(넓게) + 헛간 + 뒷간 + 장독 + 높은 바자울 + 사립문
#   large : 넓은 一자 겹집 기와 + 초가 곳간채 + 기와 토담 + 평대문
# params: seed, size, roof("thatch"|"giwa"), merged
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func footprint(params: Dictionary) -> Vector2:
	match params.get("size", "small"):
		"medium": return Vector2(19, 18)
		"large": return Vector2(22, 22)
	return Vector2(16, 15)

static func entries(params: Dictionary) -> Array:
	var s0 := int(params.get("seed", 1)) * 10
	var L := []
	match params.get("size", "small"):
		"large":
			L.append(CC.e("anchae", "culture/haeseo/gyeopjip", { seed = s0 + 1, plan = "il", w = 13.0, roof = params.get("roof", "giwa") }, -1.0, -5.2))
			L.append(CC.e("gotgan", "culture/chae", { seed = s0 + 2, l = 7.0, d = 3.2, bays = "bkc", roof = "thatch", F = 0.3, wall_h = 1.8 }, 7.4, 3.4, -PI / 2))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 3, w = 3.0, d = 2.0 }, -7.6, 3.6))
			CC.enclose(L, s0 + 20, -10.6, 10.6, -10.8, 10.4, 1.25, "village/todam", { h = 1.6, cap = "tile", tile_seg = 0.5 })
			L.append(CC.e("gate", "village/daemun", { seed = s0 + 8, style = "tile", open = true }, 0, 10.4))
		"medium":
			L.append(CC.e("anchae", "culture/haeseo/gyeopjip", { seed = s0 + 1, plan = "il", w = 11.6, roof = params.get("roof", "thatch") }, -0.4, -4.4))
			L.append(CC.e("heotgan", "village/heotgan", { seed = s0 + 2, w = 3.4, d = 2.6, walls = "three" }, 7.2, 1.8, -PI / 2))
			L.append(CC.e("dwitgan", "village/dwitgan", { seed = s0 + 3, s = 1.4 }, -7.8, 7.0, PI / 2))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 4, w = 2.4, d = 1.8, n = [2, 2, 1] }, 6.6, -6.6))
			CC.enclose(L, s0 + 20, -9.1, 9.1, -8.6, 8.6, 0.8, "village/fence", { h = 1.7, lite = true })
			L.append(CC.e("gate", "village/saripmun", { seed = s0 + 8, w = 1.4, open = true }, 0, 8.6))
		_:
			L.append(CC.e("anchae", "culture/haeseo/gyeopjip", { seed = s0 + 1, roof = params.get("roof", "thatch") }, 0, -3.2))
			L.append(CC.e("haystack", "village/haystack", { seed = s0 + 2 }, 5.4, 3.0))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 3, w = 2.2, d = 1.6, n = [2, 1, 1] }, -5.4, 2.6))
			CC.enclose(L, s0 + 20, -7.5, 7.5, -7.2, 7.2, 0.75, "village/fence", { h = 1.5, lite = true })
			L.append(CC.e("gate", "village/saripmun", { seed = s0 + 8, w = 1.4, open = true }, 0, 7.2))
	return L

static func layout(params: Dictionary) -> Array:
	return entries(params)

static func build(params: Dictionary) -> Dictionary:
	var fp := footprint(params)
	var res := CC.compound(entries(params), "해서집_" + str(params.get("size", "small")), fp, params, "culture/haeseo/compound")
	res.yard = { minX = -fp.x / 2 + 1, maxX = fp.x / 2 - 1, minZ = -fp.y / 2 + 1, maxZ = fp.y / 2 - 1 }
	return res
