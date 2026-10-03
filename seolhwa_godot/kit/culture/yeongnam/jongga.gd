# 영남 종가 — ㅁ자 기와 뜰집(몸채) + 동북쪽 뒤 사당(담·일각문) + 앞 행랑채(대문간) + 기와 토담. 배치형(pieces/layout).
# 고증: 안동·경주 양동·하회 종택 짜임 — 몸채 ㅁ자, 사당은 정침 동쪽 뒤 높은 곳, 앞에 행랑채·대문. 별당·정자는 생략.
# params: seed, merged(false), lod는 없음(몸채 조각이 각각 예산 안)
# 성능: 조각별 — 뜰집 ≈6,000, 사당 ≈4,000, 행랑채 ≈2,600, 토담 토막 각 1,000~2,000
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

const X0 := -13.0; const X1 := 13.0; const Z0 := -21.0; const Z1 := 13.5

static func footprint(_p: Dictionary) -> Vector2: return Vector2(X1 - X0 + 1.0, Z1 - Z0 + 1.5)

static func entries(params: Dictionary) -> Array:
	var s0 := int(params.get("seed", 1)) * 10
	var L := []
	L.append(CC.e("momchae", "culture/yeongnam/tteuljip", { seed = s0 + 1, roof = "giwa" }, 0, -2.5))
	L.append(CC.e("sadang", "culture/yeongnam/sadang", { seed = s0 + 2 }, 7.0, -15.6))
	L.append(CC.e("haengrang", "culture/chae", { seed = s0 + 3, l = 15.0, d = 3.2, bays = "bcbgbc", roof = "giwa", F = 0.35, wall_h = 2.0, wall = "plaster" }, 0, Z1 - 1.6))
	L.append(CC.e("jangdok", "village/jangdok", { seed = s0 + 4, w = 3.2, d = 2.2 }, -8.0, -13.0))
	L.append(CC.e("gotgan", "culture/chae", { seed = s0 + 5, l = 6.0, d = 3.0, bays = "bkb", roof = "giwa", F = 0.4, wall_h = 1.9, gable = true }, -10.5, 3.5, PI / 2))
	CC.enclose(L, s0 + 20, X0, X1, Z0, Z1 - 1.6, 7.5, "village/todam", { h = 1.6, cap = "tile", tile_seg = 0.5 })
	return L

static func layout(params: Dictionary) -> Array:
	return entries(params)

static func build(params: Dictionary) -> Dictionary:
	var res := CC.compound(entries(params), "종가", footprint(params), params, "culture/yeongnam/jongga")
	res.yard = { minX = X0 + 1, maxX = X1 - 1, minZ = Z0 + 1, maxZ = Z1 - 2 }
	return res
