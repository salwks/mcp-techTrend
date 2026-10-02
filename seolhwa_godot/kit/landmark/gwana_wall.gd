# 관아·객사·사찰 담장 직선 모듈 — 아래 막돌, 위 회벽, 꼭대기 기와(맞배 단면). 로컬 x축 방향 length m, 원점 = 가운데 바닥.
# params: seed, length(12), height(2.2), thick(0.5)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var L: float = float(params.get("length", 12.0))
	var h: float = float(params.get("height", 2.2))
	var th: float = float(params.get("thick", 0.5))
	var b := Kit.Batch.new()
	Co.tile_wall(b, -L / 2, 0, L / 2, 0, h, rng, th)
	return {
		node = b.build("담장"), colliders = [Co.wall_collider(-L / 2, 0, L / 2, 0, th + 0.1)], lights = [],
		occluder = h > 1.9, footprint = Vector2(L, th + 0.6), anchors = {},
	}
