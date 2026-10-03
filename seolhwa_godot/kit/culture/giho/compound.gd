# 기호 집 한 채 프리셋 — 마당 가운데 원점, 대문 +z.
#   small : 초가 ㄱ자 + 헛간 + 뒷간 + 장독 + 싸리울 + 사립문
#   medium: ㄱ자 안채(초가) + 사랑채 + 장독 + 이엉 토담 + 초가 대문
#   large : ㄱ자 안채(기와) + 사랑채 + 행랑채(대문간) + 곳간 + 기와 토담
#   city  : 한양 도시 한옥(ㄷ자 기본, 필지 = footprint) — 담 없음(집이 담)
# params: seed, size, roof("giwa"|"choga" 안채·사랑 덮어쓰기), shape(city용 "ㅁ"|"ㄷ"), merged
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func footprint(params: Dictionary) -> Vector2:
	match params.get("size", "small"):
		"medium": return Vector2(20, 21)
		"large": return Vector2(24, 26)
		"city": return Vector2(11.5, 14)
	return Vector2(16, 15)

static func entries(params: Dictionary) -> Array:
	var s0 := int(params.get("seed", 1)) * 10
	var L := []
	match params.get("size", "small"):
		"city":
			L.append(CC.e("house", "culture/giho/hanok_city", { seed = s0 + 1, shape = params.get("shape", "ㄷ") }, 0, 0))
		"large":
			L.append(CC.e("anchae", "culture/giho/giyeok", { seed = s0 + 1, roof = params.get("roof", "giwa") }, 0, -3.0))
			L.append(CC.e("haengrang", "culture/chae", { seed = s0 + 2, l = 12.0, d = 3.0, bays = "bbgbc", roof = params.get("roof", "giwa") if params.get("roof", "giwa") == "giwa" else "thatch", F = 0.3, wall_h = 1.95 }, -3.0, 10.4))
			L.append(CC.e("gotgan", "village/heotgan", { seed = s0 + 3, w = 4.0, d = 2.6, walls = "three" }, 9.6, -6.5, -PI / 2))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 4, w = 3.0, d = 2.0 }, 7.0, -10.8))
			CC.enclose(L, s0 + 20, -12.0, 12.0, -12.8, 11.9, 0.0, "village/todam", { h = 1.6, cap = "tile", tile_seg = 0.5 })
			for en in L:
				if en.tag == "wall_sw": en.params.bx = -9.0
				if en.tag == "wall_se": en.params.ax = 3.0
		"medium":
			L.append(CC.e("anchae", "culture/giho/giyeok", { seed = s0 + 1, roof = params.get("roof", "choga") }, 0, -1.6))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 2, w = 2.6, d = 2.0, n = [3, 2, 1] }, 6.5, -9.0))
			L.append(CC.e("dwitgan", "village/dwitgan", { seed = s0 + 3, s = 1.4 }, -8.4, 8.6, PI / 2))
			L.append(CC.e("firewood", "village/firewood", { seed = s0 + 4, style = "row", len = 2.4, rows = 4 }, 8.6, -2.0, -PI / 2))
			CC.enclose(L, s0 + 20, -9.6, 9.6, -10.2, 10.2, 1.25, "village/todam", { h = 1.5, cap = "thatch" })
			L.append(CC.e("gate", "village/daemun", { seed = s0 + 8, style = "thatch", open = true, lantern = false }, 0, 10.2))
		_:
			if params.get("roof", "choga") == "giwa":
				L.append(CC.e("anchae", "culture/giho/giyeok", { seed = s0 + 1, roof = "giwa", sarang = false }, 0, -0.6))
			else:
				L.append(CC.e("anchae", "culture/giho/choga_giyeok", { seed = s0 + 1 }, -0.6, -2.8))
			L.append(CC.e("heotgan", "village/heotgan", { seed = s0 + 2, w = 3.2, d = 2.4, walls = "three" }, 5.2, 2.4, -PI / 2))
			L.append(CC.e("dwitgan", "village/dwitgan", { seed = s0 + 3, s = 1.4 }, -6.0, 5.4, PI / 2))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 4, w = 2.4, d = 1.8, n = [2, 2, 1] }, 5.0, -5.8))
			CC.enclose(L, s0 + 20, -7.5, 7.5, -7.2, 7.2, 0.75, "village/fence", { lite = true })
			L.append(CC.e("gate", "village/saripmun", { seed = s0 + 8, w = 1.4, open = true }, 0, 7.2))
	return L

static func layout(params: Dictionary) -> Array:
	return entries(params)

static func build(params: Dictionary) -> Dictionary:
	var fp := footprint(params)
	var res := CC.compound(entries(params), "기호집_" + str(params.get("size", "small")), fp, params, "culture/giho/compound")
	res.yard = { minX = -fp.x / 2 + 1, maxX = fp.x / 2 - 1, minZ = -fp.y / 2 + 1, maxZ = fp.y / 2 - 1 }
	return res
