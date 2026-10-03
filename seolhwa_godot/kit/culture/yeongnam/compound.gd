# 영남 집 한 채 프리셋(village/house_compound 대응) — 마당 가운데가 원점, 대문 +z.
#   small : 영남 초가 一자 + 헛간 + 뒷간 + 장독 + 이엉 토담(낮게) + 사립문
#   medium: ㅁ자 초가 뜰집 + 장독 + 뒷간 + 짚가리 — ㅁ자 몸채가 곧 담이라 둘레 담 없음(경북 북부 민가)
#   large : 종가(ㅁ자 기와 뜰집 + 사당 + 행랑채 + 기와 토담)
# params: seed, size, roof(뜰집·초가 지붕 덮어쓰기 "giwa"|"choga"), merged
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func footprint(params: Dictionary) -> Vector2:
	match params.get("size", "small"):
		"medium": return Vector2(22, 22)
		"large": return preload("res://kit/culture/yeongnam/jongga.gd").footprint(params)
	return Vector2(16, 15)

static func entries(params: Dictionary) -> Array:
	var s0 := int(params.get("seed", 1)) * 10
	var L := []
	match params.get("size", "small"):
		"large":
			return preload("res://kit/culture/yeongnam/jongga.gd").entries(params)
		"medium":
			L.append(CC.e("momchae", "culture/yeongnam/tteuljip", { seed = s0 + 1, roof = params.get("roof", "choga") }, 0, -1.5))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 2, w = 2.6, d = 2.0, n = [3, 2, 1] }, 7.5, -8.5))
			L.append(CC.e("dwitgan", "village/dwitgan", { seed = s0 + 3, s = 1.4 }, -8.6, 7.0))
			L.append(CC.e("haystack", "village/haystack", { seed = s0 + 4 }, 8.4, 7.4))
			L.append(CC.e("firewood", "village/firewood", { seed = s0 + 5, style = "row", len = 2.6, rows = 4 }, -9.2, -3.0, PI / 2))
		_:
			var roof: String = params.get("roof", "choga")
			if roof == "giwa":
				L.append(CC.e("anchae", "culture/chae", { seed = s0 + 1, l = 10.0, d = 4.6, bays = "wdmmd", roof = "giwa", maru = 0.7, chimney = "low" }, 0, -3.2))
			else:
				L.append(CC.e("anchae", "culture/yeongnam/choga", { seed = s0 + 1, plan = "il" }, 0, -3.0))
			L.append(CC.e("heotgan", "village/heotgan", { seed = s0 + 2, w = 3.2, d = 2.4, walls = "three" }, 5.4, 2.6, -PI / 2))
			L.append(CC.e("dwitgan", "village/dwitgan", { seed = s0 + 3, s = 1.4 }, -6.0, 5.0, PI / 2))
			L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 4, w = 2.4, d = 1.8, n = [2, 2, 1] }, 5.2, -6.2))
			CC.enclose(L, s0 + 20, -7.5, 7.5, -7.2, 7.2, 0.8, "village/todam", { h = 1.3, cap = "thatch" })
			L.append(CC.e("gate", "village/saripmun", { seed = s0 + 8, w = 1.4, open = true }, 0, 7.2))
	return L

static func layout(params: Dictionary) -> Array:
	return entries(params)

static func build(params: Dictionary) -> Dictionary:
	var fp := footprint(params)
	var res := CC.compound(entries(params), "영남집_" + str(params.get("size", "small")), fp, params, "culture/yeongnam/compound")
	res.yard = { minX = -fp.x / 2 + 1, maxX = fp.x / 2 - 1, minZ = -fp.y / 2 + 1, maxZ = fp.y / 2 - 1 }
	return res
