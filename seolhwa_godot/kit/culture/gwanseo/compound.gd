# 관서 집 한 채 프리셋 — 마당 가운데 원점, 대문 +z.
#   small : 서북 초가(낮고 넓은 겹집) + 짚가리 + 장독 + 싸리울(높게) + 사립문
#   medium: 서북 초가 + 헛간 + 뒷간 + 장작 + 이엉 토담 + 초가 대문
#   large : 평양 도시 기와집(ㄱ자, 넓은 처마) + 一자 곳간채 + 도시 담(사괴석·회벽, 길에 붙음)
# params: seed, size, merged
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func footprint(params: Dictionary) -> Vector2:
	match params.get("size", "small"):
		"medium": return Vector2(19, 17)
		"large": return Vector2(22, 22)
	return Vector2(17, 15)

static func entries(params: Dictionary) -> Array:
	var s0 := int(params.get("seed", 1)) * 10
	var L := []
	match params.get("size", "small"):
		"large":
			L.append(CC.e("anchae", "culture/gwanseo/pyeongyang_giwa", { seed = s0 + 1, plan = "giyeok" }, -1.0, -5.4))
			L.append(CC.e("gotgan", "culture/chae", { seed = s0 + 2, l = 7.0, d = 3.2, bays = "bkb", roof = "giwa_dark", F = 0.35, ov = 1.6, gable = true }, -6.6, 3.6, PI / 2))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 3, w = 3.0, d = 2.0 }, 7.0, -9.2))
			L.append(CC.e("walls", "culture/gwanseo/city_wall", { seed = s0 + 20, x0 = -10.8, x1 = 10.8, z0 = -10.8, z1 = 10.8, gate_x = 4.4 }, 0, 0))
		"medium":
			L.append(CC.e("anchae", "culture/gwanseo/choga", { seed = s0 + 1 }, 0, -4.0))
			L.append(CC.e("heotgan", "village/heotgan", { seed = s0 + 2, w = 3.4, d = 2.6, walls = "three" }, 7.2, 2.6, -PI / 2))
			L.append(CC.e("dwitgan", "village/dwitgan", { seed = s0 + 3, s = 1.4 }, -7.8, 6.4, PI / 2))
			L.append(CC.e("firewood", "village/firewood", { seed = s0 + 4, style = "row", len = 2.6, rows = 4 }, -7.6, 0.4, PI / 2))
			CC.enclose(L, s0 + 20, -9.1, 9.1, -8.0, 8.0, 1.25, "village/todam", { h = 1.5, cap = "thatch" })
			L.append(CC.e("gate", "village/daemun", { seed = s0 + 8, style = "thatch", open = true, lantern = false }, 0, 8.0))
		_:
			L.append(CC.e("anchae", "culture/gwanseo/choga", { seed = s0 + 1, w = 11.0 }, 0, -3.0))
			L.append(CC.e("haystack", "village/haystack", { seed = s0 + 2 }, 6.0, 3.2))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 3, w = 2.2, d = 1.6, n = [2, 1, 1] }, -6.0, 3.0))
			CC.enclose(L, s0 + 20, -8.0, 8.0, -7.2, 7.2, 0.75, "village/fence", { h = 1.5, lite = true })
			L.append(CC.e("gate", "village/saripmun", { seed = s0 + 8, w = 1.4, open = true }, 0, 7.2))
	return L

static func layout(params: Dictionary) -> Array:
	return entries(params)

static func build(params: Dictionary) -> Dictionary:
	var fp := footprint(params)
	var res := CC.compound(entries(params), "관서집_" + str(params.get("size", "small")), fp, params, "culture/gwanseo/compound")
	res.yard = { minX = -fp.x / 2 + 1, maxX = fp.x / 2 - 1, minZ = -fp.y / 2 + 1, maxZ = fp.y / 2 - 1 }
	return res
