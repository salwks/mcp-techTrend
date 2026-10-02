# 읍성 모서리 모듈 — 두 성벽이 만나는 네모 덩이. 로컬 바깥 면 = +x와 +z, 원점 = 모서리 덩이 중심 바닥.
# 남원읍성 네 귀는 각루가 있었는지 확인되지 않아(가설) 여장만 두른 네모 귀로 만든다. params: seed, size(=성벽 두께, 4.6), height
extends RefCounted

const S = preload("res://kit/landmark/_seong.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var t: float = float(params.get("size", S.T))
	var h: float = float(params.get("height", S.H))
	var e: float = t / 2
	var b := Kit.Batch.new()
	# 몸체: x 방향 상자 하나(두께 t, 길이 t) + 바깥 면 둘
	S.body(b, rng, Vector2(-e, 0), Vector2(e, 0), Vector2(0, 1), t, h)
	S.body(b, rng, Vector2(0, e), Vector2(0, -e), Vector2(1, 0), t, h)
	S.stone_face(b, rng, Vector2(-e, e), Vector2(e + 0.35, e), 0.0, h, Vector2(0, 1), 0.35)
	S.stone_face(b, rng, Vector2(e, e + 0.35), Vector2(e, -e), 0.0, h, Vector2(1, 0), 0.35)
	var pz := e - S.PARA_T / 2
	S.parapet(b, rng, Vector2(-e, pz), Vector2(pz + S.PARA_T / 2, pz), h, Vector2(0, 1))
	S.parapet(b, rng, Vector2(pz, pz - S.PARA_T / 2 - 0.02), Vector2(pz, -e), h, Vector2(1, 0))
	var node := b.build("성벽모서리")
	return {
		node = node,
		colliders = [{ type = "box", minX = -e, maxX = e + 0.35, minZ = -e, maxZ = e + 0.35 }],
		lights = [], occluder = true, footprint = Vector2(t + 0.4, t + 0.4), anchors = {},
	}
