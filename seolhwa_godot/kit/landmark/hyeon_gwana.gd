# 작은 현(縣) 관아 일곽 — 운봉현 같은 작은 고을용. 외삼문 → 마당 → 동헌(정면 5칸) + 동북쪽 담으로 나뉜 내아(一자, 날개 없음).
# 약 36×36m. 현 단위 관아는 내삼문을 생략하거나 작게 두는 경우가 많아 외삼문 하나로 둔 것은 가설(운봉현 관아 실측 기록 못 찾음).
# 원점 = 일곽 가운데 바닥, 정면(외삼문) +z. params: seed, width(36), depth(36), naesammun(false)
# 반환에 pieces(조각 목록) 포함.
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func layout(params: Dictionary) -> Array:
	var seed: int = int(params.get("seed", 1))
	var W: float = float(params.get("width", 36.0)); var D: float = float(params.get("depth", 36.0))
	var x0 := -W / 2; var x1 := W / 2; var z0 := -D / 2; var z1 := D / 2
	var p := []
	p.append({ kit = "landmark/samun", params = { seed = seed, kind = "inner" }, x = 0.0, z = z1, ry = 0.0, tag = "oesammun" })
	p.append({ kit = "landmark/dongheon", params = { seed = seed + 1, bays = 5, bay = 2.7, depth = 6.4 }, x = -6.0, z = -1.0, ry = 0.0, tag = "dongheon" })
	p.append({ kit = "landmark/naea", params = { seed = seed + 2, wing = false }, x = x1 - 8.6, z = z0 + 6.6, ry = 0.0, tag = "naea" })
	p.append_array(Co.wall_pieces([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)], true, [[0.0, z1, 4.3]], seed + 10, 2.2))
	# 내아 칸막이 담(ㄱ자: 세로 + 가로, 협문 틈)
	var px := x1 - 17.2; var pz := z0 + 13.0
	p.append_array(Co.wall_pieces([Vector2(px, z0), Vector2(px, pz), Vector2(x1, pz)], false, [[px + 8.6, pz, 0.9]], seed + 30, 1.9))
	if params.get("naesammun", false):
		p.append({ kit = "landmark/samun", params = { seed = seed + 3, kind = "inner" }, x = 0.0, z = z1 - 12.0, ry = 0.0, tag = "naesammun" })
	return p

static func build(params: Dictionary) -> Dictionary:
	var W: float = float(params.get("width", 36.0)); var D: float = float(params.get("depth", 36.0))
	var pieces := layout(params)
	var r := Co.assemble("현관아", pieces)
	r.occluder = true
	r.footprint = Vector2(W + 2, D + 6)
	r.pieces = pieces
	return r
