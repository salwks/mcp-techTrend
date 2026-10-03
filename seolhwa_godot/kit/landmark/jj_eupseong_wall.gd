# 제주성(제주읍성) 성벽 직선 구간 — 검은 현무암 막쌓기 몸체(높이 3.6m·두께 3m, 가설) + 바깥 가장자리 낮은 돌 여장.
# landmark/seong_wall(판석 화강암)과 같은 규칙: 로컬 x축 방향 length m, 바깥(성 밖) +z, 원점 = 구간 가운데 바닥(몸체 두께 중심).
# 고증: 제주성은 현무암 석성(1870년 둘레 약 1.5km로 넓힌 상태, 1920년대 헐림). 여장 모양은 가설 — 육지 성의 타구 대신 둥근 돌 여장.
# params: seed, length(20), height(3.6), thick(3.0), parapet(true)
# 삼각형: 20m 약 2,400 (placement-east 배치 에이전트가 만듦)
extends RefCounted

const Co = preload("res://kit/landmark/_common.gd")
const Hub = preload("res://kit/landmark/_hub.gd")

static func build(params: Dictionary) -> Dictionary:
	var rng := Kit.Rng.new(int(params.get("seed", 1)))
	var L: float = float(params.get("length", 20.0))
	var h: float = float(params.get("height", 3.6))
	var t: float = float(params.get("thick", 3.0))
	var b := Kit.Batch.new()
	# 몸체: 땅속 1m까지 내려 경사에서도 뜨지 않게
	var sink := 1.0
	var body := Kit.box(L, h + sink, t)
	Kit.xf(body, 0, (h + sink) / 2 - sink, 0)
	b.add("stone", Co.pnt(body, [0x34312d, 0x24221f]), 0.03)
	# 겉면 돌(바깥 +z 면과 안쪽 −z 면) — 들쭉날쭉한 막돌
	var a := Vector2(-L / 2, t / 2 - 0.25); var c := Vector2(L / 2, t / 2 - 0.25)
	Hub.basalt_wall(b, rng, a, c, h, 0.55)
	Hub.basalt_wall(b, rng, Vector2(-L / 2, -t / 2 + 0.25), Vector2(L / 2, -t / 2 + 0.25), h * 0.92, 0.5)
	# 여장: 바깥 가장자리 위 낮은 돌담(타구 대신 1.2m마다 틈)
	if params.get("parapet", true):
		var x := -L / 2 + 0.2
		while x < L / 2 - 0.4:
			var w := minf(rng.between(2.4, 3.2), L / 2 - x)
			if w > 0.5:
				var g := Kit.box(w - 0.35, 0.95, 0.7)
				Kit.xf(g, x + w / 2, h + 0.47, t / 2 - 0.35)
				b.add("stone", Co.pnt(g, Hub.BASALT, 0.12, rng), 0.03)
			x += w
	var node := b.build("제주성벽")
	return {
		node = node,
		colliders = [{ type = "box", minX = -L / 2, maxX = L / 2, minZ = -t / 2 - 0.1, maxZ = t / 2 + 0.1 }],
		lights = [],
		occluder = true,
		footprint = Vector2(L, t + 0.4),
		anchors = { walk = Vector3(0, h, 0), outside = Vector3(0, 0, t / 2 + 2.0), inside = Vector3(0, 0, -t / 2 - 2.0) },
	}
