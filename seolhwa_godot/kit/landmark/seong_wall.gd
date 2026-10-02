# 읍성 성벽 직선 구간 모듈 — 로컬 x축 방향으로 length m, 바깥(성 밖) +z, 원점 = 구간 가운데 바닥(성벽 두께 중심).
# 판석 협축 석벽(높이 4m, 윗너비 4.6m 가설) + 바깥 여장(타 3.2m, 타구, 총안 3). 땅속으로 1.2m 더 내려 경사지에 놓아도 뜨지 않는다.
# params: seed, length(기본 20), height(4.0), thick(4.6), parapet(true)
extends RefCounted

const S = preload("res://kit/landmark/_seong.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var L: float = float(params.get("length", 20.0))
	var h: float = float(params.get("height", S.H))
	var t: float = float(params.get("thick", S.T))
	var b := Kit.Batch.new()
	S.wall_run(b, rng, -L / 2, L / 2, 0.0, h, t, params.get("parapet", true))
	var node := b.build("성벽")
	return {
		node = node,
		colliders = [{ type = "box", minX = -L / 2, maxX = L / 2, minZ = -t / 2 - 0.1, maxZ = t / 2 + 0.35 }],
		lights = [],
		occluder = true,
		footprint = Vector2(L, t + 0.5),
		anchors = { walk = Vector3(0, h, 0), outside = Vector3(0, 0, t / 2 + 2.0), inside = Vector3(0, 0, -t / 2 - 2.0) },
	}
