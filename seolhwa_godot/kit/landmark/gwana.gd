# 남원부 관아 일곽 배치 도우미 — 외삼문 → 내삼문 → 동헌(정면 남향), 동북쪽에 담으로 나뉜 내아.
# 남원 관아는 현재 터만 남아 배치는 조선 후기 읍치 관아 일반형(외삼문·내삼문·동헌 일직선, 내아 곁채)을 따른 가설.
# 원점 = 일곽 가운데 바닥, 정면(외삼문) +z. params: seed, width(60), depth(72)
# 반환에 pieces(조각 목록)를 함께 준다(지형 엔진이 조각별로 놓을 수 있게).
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func layout(params: Dictionary) -> Array:
	var seed: int = int(params.get("seed", 1))
	var W: float = float(params.get("width", 60.0)); var D: float = float(params.get("depth", 72.0))
	var x0 := -W / 2; var x1 := W / 2; var z0 := -D / 2; var z1 := D / 2
	var zi := z1 - 22.0     # 내삼문 담 줄
	var p := []
	p.append({ kit = "landmark/samun", params = { seed = seed, kind = "outer" }, x = 0.0, z = z1, ry = 0.0, tag = "oesammun" })
	p.append({ kit = "landmark/samun", params = { seed = seed + 1, kind = "inner" }, x = 0.0, z = zi, ry = 0.0, tag = "naesammun" })
	p.append({ kit = "landmark/dongheon", params = { seed = seed + 2 }, x = -8.0, z = zi - 20.0, ry = 0.0, tag = "dongheon" })
	var nx := x1 - 12.0; var nz := z0 + 11.0
	p.append({ kit = "landmark/naea", params = { seed = seed + 3 }, x = nx, z = nz, ry = 0.0, tag = "naea" })
	# 바깥 담(외삼문 틈), 내삼문 담(가로), 내아 칸막이 담(협문 틈)
	p.append_array(Co.wall_pieces([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)], true, [[0.0, z1, 4.8]], seed + 10, 2.4))
	p.append_array(Co.wall_pieces([Vector2(x0, zi), Vector2(x1, zi)], false, [[0.0, zi, 4.2]], seed + 40, 2.2))
	var px := x1 - 23.0
	p.append_array(Co.wall_pieces([Vector2(px, zi), Vector2(px, z0)], false, [[px, zi - 14.0, 0.9]], seed + 60, 2.0))
	return p

static func build(params: Dictionary) -> Dictionary:
	var W: float = float(params.get("width", 60.0)); var D: float = float(params.get("depth", 72.0))
	var pieces := layout(params)
	var r := Co.assemble("남원관아", pieces)
	r.occluder = true
	r.footprint = Vector2(W + 2, D + 6)
	r.pieces = pieces
	return r
