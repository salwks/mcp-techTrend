# 관동 집 한 채 프리셋 — 마당 가운데 원점, 대문 +z.
#   small : 산간 조합 — 너와집(ㄱ자) + 귀틀집(억새, 곳간·외양) + 통나무 굴뚝 + 막돌 돌담 + 사립문 + 장작(산촌 화전민)
#           (비탈 집터면 배치에서 village/stone_terrace를 앞에 따로 놓는다)
#   medium: 영동 해안 ㄱ자 초가(그물 이엉) + 헛간 + 돌담 + 사립문
#   large : 강릉 반가(一자 기와 안채 + 긴 행랑채) + 기와 토담 + 장독
# params: seed, size, merged
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func footprint(params: Dictionary) -> Vector2:
	match params.get("size", "small"):
		"medium": return Vector2(16, 15)
		"large": return Vector2(26, 22)
	return Vector2(18, 15)

static func entries(params: Dictionary) -> Array:
	var s0 := int(params.get("seed", 1)) * 10
	var L := []
	match params.get("size", "small"):
		"large":
			L.append(CC.e("house", "culture/gwandong/banga", { seed = s0 + 1 }, 0, -1.5))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 2, w = 3.0, d = 2.0 }, 10.0, -8.6))
			CC.enclose(L, s0 + 20, -13.0, 13.0, -10.5, 7.1, 0.0, "village/todam", { h = 1.6, cap = "tile", tile_seg = 0.5 }, ["wall_sw", "wall_se"])
		"medium":
			L.append(CC.e("anchae", "culture/gwandong/haean", { seed = s0 + 1 }, -0.8, -3.6))
			L.append(CC.e("heotgan", "village/heotgan", { seed = s0 + 2, w = 3.2, d = 2.4, walls = "three" }, -5.4, 2.8, PI / 2))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 3, w = 2.2, d = 1.6, n = [2, 1, 1] }, 5.6, -6.2))
			CC.enclose(L, s0 + 20, -7.5, 7.5, -7.2, 7.2, 0.75, "village/stone_wall", { lite = true, sparse = true, h = 1.2 })
			L.append(CC.e("gate", "village/saripmun", { seed = s0 + 8, w = 1.4, open = true }, 0, 7.2))
		_:
			L.append(CC.e("anchae", "village/neowa_house", { seed = s0 + 1, plan = "giyeok" }, -2.0, -3.2))
			L.append(CC.e("gotgan", "village/guitul_house", { seed = s0 + 2, w = 4.6, d = 3.4 }, 5.8, 0.8, -PI / 2))
			L.append(CC.e("firewood", "village/firewood", { seed = s0 + 3, style = "stack" }, -7.0, 2.4))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 4, w = 2.0, d = 1.6, n = [2, 1, 1] }, 5.4, -5.6))
			CC.enclose(L, s0 + 20, -8.5, 8.5, -7.2, 7.2, 0.8, "village/stone_wall", { lite = true, sparse = true, h = 1.0 })
			L.append(CC.e("gate", "village/saripmun", { seed = s0 + 8, w = 1.4, open = true }, 0, 7.2))
	return L

static func layout(params: Dictionary) -> Array:
	return entries(params)

static func build(params: Dictionary) -> Dictionary:
	var fp := footprint(params)
	var res := CC.compound(entries(params), "관동집_" + str(params.get("size", "small")), fp, params, "culture/gwandong/compound")
	res.yard = { minX = -fp.x / 2 + 1, maxX = fp.x / 2 - 1, minZ = -fp.y / 2 + 1, maxZ = fp.y / 2 - 1 }
	return res
