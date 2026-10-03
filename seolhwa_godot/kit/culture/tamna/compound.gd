# 탐라 집 한 채 프리셋 — 안거리(북, 남향) + 밖거리(동쪽, 서향) 두거리집 + 현무암 집담 + 굽은 올레(돌담 골목) + 어귀 정낭
#   + 돗통시(돌담 둘러친 뒷간) + 우영밭(텃밭) + 물항(항아리). 원점 = 바닥 중심, 올레 어귀(정낭)가 +z 끝.
#   size small: 안거리 하나(외거리집) / medium: 두거리집(기본) / large: 두거리 + 모커리(서쪽 작은 채)
# 고증: 제주 민가는 안거리·밖거리가 마당을 사이에 두고 마주 보거나 ㄱ으로 놓이고, 길에서 집까지 굽은 올레로 들어가며 어귀에 정낭.
#   돗통시는 돼지우리 겸 뒷간(돌담 원형). 밖거리를 동쪽에 서향으로 둔 것은 카메라(남쪽 고정) 때문의 게임성 선택.
# params: seed, size, across(정낭 걸친 수 0~3, 기본 seed로), merged
# 앵커: gate_gate(올레 어귀 바깥), an_house_sangbang, bak_house_sangbang …
extends RefCounted
const C := preload("res://kit/village/_common.gd")
const CC := preload("res://kit/culture/_cc.gd")

static func footprint(_p: Dictionary) -> Vector2:
	return Vector2(19, 22)

static func entries(params: Dictionary) -> Array:
	var seed := int(params.get("seed", 1))
	var s0 := seed * 10
	var size: String = params.get("size", "medium")
	var L := []
	L.append(CC.e("an", "culture/tamna/stone_house", { seed = s0 + 1, kind = "an" }, -1.2, -7.4))
	if size != "small":
		L.append(CC.e("bak", "culture/tamna/stone_house", { seed = s0 + 2, kind = "bak" }, 5.6, -0.8, -PI / 2))
	if size == "large":
		L.append(CC.e("mokeori", "culture/chae", { seed = s0 + 3, l = 4.6, d = 3.4, bays = "kb", roof = "tti", wall = "basalt", F = 0.2, wall_h = 1.6, ov = 0.5, k = 1.0, rope = 0.55, rise_k = 0.42 }, -6.6, -1.6, PI / 2))
	else:
		L.append(CC.e("uyeong", "village/teotbat", { seed = s0 + 3, w = 3.4, d = 2.6, rows = 3, gourd = false }, -6.0, -1.8))
	L.append(CC.e("tongsi", "culture/tamna/doldam", { seed = s0 + 4, points = [[-8.6, 1.6], [-6.4, 1.6], [-6.0, 2.6], [-6.4, 3.4], [-8.6, 3.4]], h = 1.1 }, 0, 0))
	L.append(CC.e("mulhang", "village/props", { seed = s0 + 5, kind = "dok" }, 2.6, -4.2))
	# 집담(마당 둘레): 남쪽은 올레 자리(x -2.6..-0.4)를 비움
	var wall := { h = 1.35, lite = true }
	var segs := [["wall_n", [[-9.2, -10.6], [9.2, -10.6]]], ["wall_w", [[-9.2, -10.6], [-9.2, 3.6]]], ["wall_e", [[9.2, -10.6], [9.2, 3.6]]],
		["wall_sw", [[-9.2, 3.6], [-2.6, 3.6]]], ["wall_se", [[-0.4, 3.6], [9.2, 3.6]]],
		["olle_w", [[-2.6, 3.6], [-3.2, 6.6], [-2.0, 10.4]]], ["olle_e", [[-0.4, 3.6], [-1.0, 6.6], [0.2, 10.4]]]]
	var i := 0
	for sg in segs:
		var p := wall.duplicate(); p.seed = s0 + 20 + i; p.points = sg[1]
		L.append(CC.e(sg[0], "culture/tamna/doldam", p, 0, 0))
		i += 1
	var across: int = params.get("across", seed % 4)
	L.append(CC.e("gate", "culture/tamna/jeongnang", { seed = s0 + 8, w = 2.2, across = across }, -0.9, 10.4, -0.25))
	return L

static func layout(params: Dictionary) -> Array:
	return entries(params)

static func build(params: Dictionary) -> Dictionary:
	var fp := footprint(params)
	var res := CC.compound(entries(params), "탐라집_" + str(params.get("size", "medium")), fp, params, "culture/tamna/compound")
	res.yard = { minX = -8.2, maxX = 8.2, minZ = -9.6, maxZ = 2.6 }
	return res
