# 치(雉) — 성벽 바깥으로 네모나게 내민 돌출부. 로컬: 성벽 바깥 면(z=0)에 붙어 +z로 depth만큼 나온다. 원점 = 붙는 면 가운데 바닥.
# 성벽 모듈(두께 중심 원점)에 붙일 때는 z = 성벽 두께/2 위치에 놓는다. 남원읍성 '옹성 16곳' 기록 가운데 문 옹성 4 외 나머지를 치·귀로 본 것은 가설.
# params: seed, width(8), depth(6), height(4.0)
extends RefCounted

const S = preload("res://kit/landmark/_seong.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var w: float = float(params.get("width", 8.0))
	var d: float = float(params.get("depth", 6.0))
	var h: float = float(params.get("height", S.H))
	var b := Kit.Batch.new()
	# 몸체: x 방향 상자(두께 d, 중심 z=d/2-0.4로 성벽에 조금 묻힘)
	var zc := d / 2 - 0.4
	S.body(b, rng, Vector2(-w / 2, zc), Vector2(w / 2, zc), Vector2(0, 1), d + 0.8, h)
	var zf := zc + (d + 0.8) / 2
	S.stone_face(b, rng, Vector2(-w / 2, zf), Vector2(w / 2, zf), 0.0, h, Vector2(0, 1), 0.35)
	S.stone_face(b, rng, Vector2(w / 2, zf), Vector2(w / 2, 0.0), 0.0, h, Vector2(1, 0), 0.0)
	S.stone_face(b, rng, Vector2(-w / 2, 0.0), Vector2(-w / 2, zf), 0.0, h, Vector2(-1, 0), 0.0)
	var p := S.PARA_T / 2
	S.parapet(b, rng, Vector2(-w / 2, zf - p), Vector2(w / 2, zf - p), h, Vector2(0, 1))
	S.parapet(b, rng, Vector2(w / 2 - p, zf - S.PARA_T), Vector2(w / 2 - p, 0.2), h, Vector2(1, 0))
	S.parapet(b, rng, Vector2(-w / 2 + p, 0.2), Vector2(-w / 2 + p, zf - S.PARA_T), h, Vector2(-1, 0))
	var node := b.build("치")
	return {
		node = node,
		colliders = [{ type = "box", minX = -w / 2, maxX = w / 2, minZ = -0.4, maxZ = zf + 0.35 }],
		lights = [], occluder = true, footprint = Vector2(w + 0.4, d + 0.4), anchors = { top = Vector3(0, h, d / 2) },
	}
