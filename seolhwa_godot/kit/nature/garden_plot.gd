# 텃밭(집 곁 채마밭) — 흙 바닥 위 이랑 여러 줄 + 이랑마다 작물(배추·고추·콩 등). 이랑은 x 방향, 정면 +z.
# 배치 에이전트가 직접 놓을 수 있다(계약서 §4). 걸어 들어갈 수 있게 충돌체 없음.
# params: seed, w(6, 이랑 길이 4~8), d(4, 4~8), crops(["cabbage","pepper","bean"] 이랑마다 돌아가며), spacing(0.7 포기 간격)
extends RefCounted
const C := preload("res://kit/nature/_common.gd")
const Crop := preload("res://kit/nature/crop.gd")
const Cover := preload("res://kit/nature/cover.gd")

static func build(params: Dictionary) -> Dictionary:
	var r := Kit.Rng.new(int(params.get("seed", 1)))
	var W := clampf(float(params.get("w", 6.0)), 3.0, 8.0)
	var D := clampf(float(params.get("d", 4.0)), 3.0, 8.0)
	var crops: Array = params.get("crops", ["cabbage", "pepper", "bean"])
	var sp := float(params.get("spacing", 0.7))
	var b := Kit.Batch.new()
	# 갈아엎은 흙 바닥(아주 얇게, 지형 위로 살짝)
	# 흙판: 아래로 0.6m 두껍게(비탈이나 울퉁불퉁한 지형에서 흙판 일부가 묻혀 이랑만 떠 보이지 않게)
	var soil := Kit.box(W + 0.3, 0.64, D + 0.3, 0, -0.29, 0)
	b.add("mud", Kit.paint(soil, C.c("#7a6244"), C.c("#6a5440"), 0.04, r), 0.0)
	var rows := maxi(2, int(D / 0.9))
	var o := Cover.Off.new()
	o.b = b
	var start := r.next() * crops.size()
	for i in rows:
		o.ox = 0.0; o.oz = -D / 2 + D * (i + 0.5) / rows; o.ry = 0.0
		var kind: String = crops[(int(start) + i) % crops.size()]
		# 예산(소품 ≤800): 포기 수를 모두 합쳐 36 안쪽으로
		var n := maxi(3, int(W / maxf(sp, W * rows / 36.0)))
		if kind == "millet" or kind == "barley": n = maxi(3, int(n * 0.6))
		Crop.draw(o, r, { kind = kind, len = W, n = n, ridge = true })
	return C.result(b, "텃밭", [], Vector2(W + 0.3, D + 0.3), false, { cast = false, anchors = { edge = Vector3(0, 0, D / 2 + 0.4) } })
