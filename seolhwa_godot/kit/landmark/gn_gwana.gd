# 강릉대도호부 관아 일곽 — 외삼문(솟을) → 마당 → 칠사당(gn_chilsadang, 1867 중건) + 동북쪽 내아. 강릉대도호부 관아(사적)는 객사 임영관 서쪽에 붙어 있었다.
# 동헌·내아·문 배치는 현 관아 복원 배치를 단순화한 가설. 원점 = 일곽 가운데, 정면 +z. params: seed. pieces 반환
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func layout(params: Dictionary) -> Array:
	var seed: int = int(params.get("seed", 1))
	var hw := 22.0; var hd := 20.0
	var p := [
		{ kit = "landmark/samun", params = { seed = seed, kind = "outer" }, x = 0.0, z = hd, ry = 0.0, tag = "oesammun" },
		{ kit = "landmark/gn_chilsadang", params = { seed = seed + 1 }, x = -2.0, z = -2.0, ry = 0.0, tag = "chilsadang" },
		{ kit = "landmark/naea", params = { seed = seed + 2, wing = false }, x = 12.0, z = -12.0, ry = 0.0, tag = "naea" },
	]
	p.append_array(Co.wall_pieces([Vector2(-hw, -hd), Vector2(hw, -hd), Vector2(hw, hd), Vector2(-hw, hd)], true, [[0.0, hd, 4.6]], seed + 10, 2.2))
	p.append_array(Co.wall_pieces([Vector2(3.0, -hd), Vector2(3.0, -5.0), Vector2(hw, -5.0)], false, [[12.0, -5.0, 0.9]], seed + 30, 1.9))
	return p

static func build(params: Dictionary) -> Dictionary:
	return Hub.composite("강릉관아", layout(params), Vector2(46.0, 46.0))
