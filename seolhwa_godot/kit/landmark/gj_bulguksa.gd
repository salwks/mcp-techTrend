# 불국사 경내 배치형(1870 무렵 퇴락한 모습) — 석축·청운교백운교·자하문(gj_bulguksa_seokchuk, 대지 높이 6m 포함) → 마당의 석가탑(서, 상륜은 노반만)·
# 다보탑(동) → 대웅전. 회랑은 초석만. 거리는 게임 압축(실제보다 좁힘, 가설). 원점 = 경내 가운데 바닥(석축 앞 땅 높이), 정면 +z.
# params: seed. pieces 반환(조각마다 예산 안). 탑·대웅전 조각은 y=6(대지 위)
extends RefCounted

const Hub = preload("res://kit/landmark/_hub.gd")

static func layout(params: Dictionary) -> Array:
	var seed: int = int(params.get("seed", 1))
	var H := 6.0
	var fz := 26.0
	return [
		{ kit = "landmark/gj_bulguksa_seokchuk", params = { seed = seed, width = 64.0, depth = 52.0, height = H }, x = 0.0, z = fz, ry = 0.0, tag = "seokchuk" },
		{ kit = "landmark/seoktap", params = { seed = seed + 1, height = 8.2, sangryun = "nobang" }, x = -9.0, z = 4.0, y = H, ry = 0.0, tag = "seokgatap" },
		{ kit = "landmark/gj_dabotap", params = { seed = seed + 2 }, x = 9.0, z = 4.0, y = H, ry = 0.0, tag = "dabotap" },
		{ kit = "landmark/gj_daeungjeon", params = { seed = seed + 3, fade = true }, x = 0.0, z = -12.0, y = H, ry = 0.0, tag = "daeungjeon" },
		{ kit = "landmark/seokdeung", params = { seed = seed + 4 }, x = 0.0, z = 0.0, y = H, ry = 0.0, tag = "seokdeung" },
	]

static func build(params: Dictionary) -> Dictionary:
	var p := layout(params)
	return Hub.composite("불국사", p, Vector2(66.0, 62.0))
